extends CharacterBody3D
## Player of Patient Z: movement, crouch/stealth noise, health, infection and interaction.
## Child nodes (see scenes/player/player.tscn):
##   Inventory (inventory.gd) · CameraRig (third_person_camera.gd) · WeaponController (weapon_controller.gd)

signal died

const Builder = preload("res://scripts/systems/level_builder.gd")
const PlayerModel = preload("res://scripts/player/player_model.gd")

const WALK_SPEED := 3.4
const RUN_SPEED := 6.0
const CROUCH_SPEED := 1.7
const INTERACT_DISTANCE := 2.6
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.1

# Noise radius (metres) for each movement type
const NOISE_RUN := 14.0
const NOISE_WALK := 6.0
const NOISE_CROUCH := 2.0
const NOISE_SHOT := 30.0

var max_health := 100.0
var health := 100.0
var infection := 0.0          # 0..100 %
var dead := false
var crouching := false
var running := false
var noise_radius := 0.0
var current_prompt := ""
var flashlight_on := false

# Read by the HUD
var bandages: int:
	get:
		return inventory.bandages
var current_weapon: String:
	get:
		return weapons.current_weapon

@onready var inventory: Node = $Inventory
@onready var camera_rig: Node3D = $CameraRig
@onready var weapons: Node = $WeaponController

var _noise_timer := 0.0
var _shot_noise := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _shape: CollisionShape3D
var _body_pivot: Node3D
var _model: Node3D
var _flashlight: SpotLight3D
var _flashlight_pivot: Node3D
var _hurt_player: AudioStreamPlayer


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4
	var start_yaw := rotation.y
	rotation = Vector3.ZERO
	_build_body()
	camera_rig.setup(self, STAND_HEIGHT - 0.2, start_yaw)
	weapons.setup(self, inventory, camera_rig, _body_pivot.get_node("Hand"))
	GameManager.alarm_started.connect(func(): set_flashlight(true))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if dead:
		if event is InputEventKey and event.pressed and event.physical_keycode == KEY_R:
			get_tree().reload_current_scene()
		return
	if event.is_action_pressed("px_pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if dead:
		return
	var busy := _dialogue_busy()
	_body_pivot.rotation.y = camera_rig.yaw
	_update_movement(delta, busy)
	_model.update_animation(Vector2(velocity.x, velocity.z).length(), running, crouching)
	_flashlight_pivot.rotation.x = camera_rig.pitch
	if not busy and Input.is_action_just_pressed("px_flashlight"):
		set_flashlight(not flashlight_on)
	_update_noise(delta)
	_update_status(delta, busy)
	weapons.update(delta, busy)
	_update_interaction(busy)


# --- Movement and stealth -------------------------------------------------

func _update_movement(delta: float, busy: bool) -> void:
	var input := Vector2.ZERO
	if not busy:
		input = Input.get_vector("px_left", "px_right", "px_forward", "px_back")
		if Input.is_action_just_pressed("px_crouch"):
			_set_crouch(not crouching)

	running = not busy and Input.is_action_pressed("px_sprint") and input.length() > 0.1
	if running and crouching:
		_set_crouch(false)

	var speed := CROUCH_SPEED if crouching else (RUN_SPEED if running else WALK_SPEED)
	var dir := (Basis(Vector3.UP, camera_rig.yaw) * Vector3(input.x, 0, input.y)).normalized()
	velocity.x = move_toward(velocity.x, dir.x * speed, speed * 10.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, speed * 10.0 * delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()


func _set_crouch(value: bool) -> void:
	crouching = value
	var h := CROUCH_HEIGHT if crouching else STAND_HEIGHT
	(_shape.shape as CapsuleShape3D).height = h
	_shape.position.y = h / 2.0
	_body_pivot.scale.y = h / STAND_HEIGHT
	camera_rig.set_height(h - 0.2)


func _update_noise(delta: float) -> void:
	var moving := Vector2(velocity.x, velocity.z).length() > 0.3
	var move_noise := 0.0
	if moving:
		move_noise = NOISE_CROUCH if crouching else (NOISE_RUN if running else NOISE_WALK)
	_shot_noise = move_toward(_shot_noise, 0.0, NOISE_SHOT * delta)
	noise_radius = max(move_noise, _shot_noise)

	_noise_timer -= delta
	if moving and _noise_timer <= 0.0:
		_noise_timer = 0.4
		NoiseManager.emit_noise(global_position, move_noise, self)


## Called by the weapon controller on every shot.
func register_shot() -> void:
	_shot_noise = NOISE_SHOT
	NoiseManager.emit_noise(global_position, NOISE_SHOT, self)


func stance_text() -> String:
	if crouching:
		return "CROUCHED"
	if running:
		return "RUNNING"
	return "STANDING"


# --- Health / infection ---------------------------------------------------

func _update_status(delta: float, busy: bool) -> void:
	if infection > 0.0:
		infection = min(100.0, infection + 0.35 * delta)
	if infection >= 100.0:
		_apply_damage(4.0 * delta)
	if not busy and Input.is_action_just_pressed("px_bandage"):
		use_bandage()


func take_hit(damage: float, infection_amount: float) -> void:
	if dead:
		return
	infection = min(100.0, infection + infection_amount)
	_apply_damage(damage)
	_hurt_player.play()
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.flash_damage()


func _apply_damage(amount: float) -> void:
	health = max(0.0, health - amount)
	if health <= 0.0 and not dead:
		dead = true
		current_prompt = ""
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_body_pivot.rotation.x = -PI / 2.0
		_body_pivot.position.y = 0.3
		died.emit()


func use_bandage() -> void:
	if infection <= 0.0 and health >= max_health:
		GameManager.notify("You don't need a bandage")
		return
	if not inventory.take_bandage():
		GameManager.notify("No bandages left")
		return
	infection = max(0.0, infection - 40.0)
	health = min(max_health, health + 25.0)
	GameManager.notify("Bandage used")


# --- Used by items (cabinets, pickups) and the HUD -------------------------

func add_bandages(amount: int) -> void:
	inventory.add_bandages(amount)


func add_ammo(id: String, amount: int) -> void:
	weapons.add_ammo(id, amount)


func give_weapon(id: String) -> void:
	weapons.give_weapon(id)


func has_weapon(id: String) -> bool:
	return inventory.has_weapon(id)


func weapon_text() -> String:
	return weapons.weapon_text()


# --- Interaction ----------------------------------------------------------

func _update_interaction(busy: bool) -> void:
	var focus: Node = null if busy else _find_focus()
	current_prompt = focus.get_prompt() if focus else ""
	if focus and Input.is_action_just_pressed(focus.interact_action()):
		focus.interact(self)


func _find_focus() -> Node:
	var forward: Vector3 = camera_rig.forward()
	forward.y = 0.0
	forward = forward.normalized()
	var best: Node = null
	var best_score := INF
	for node in get_tree().get_nodes_in_group("interactable"):
		var to: Vector3 = node.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist > INTERACT_DISTANCE or node.get_prompt() == "":
			continue
		var facing := forward.dot(to.normalized()) if dist > 0.01 else 1.0
		if facing < 0.3:
			continue
		var score := dist - facing
		if score < best_score:
			best_score = score
			best = node
	return best


func _dialogue_busy() -> bool:
	var dialogue := get_tree().get_first_node_in_group("dialogue_ui")
	return dialogue != null and dialogue.is_busy()


# --- Flashlight -----------------------------------------------------------

func set_flashlight(on: bool) -> void:
	flashlight_on = on
	_flashlight.visible = on


# --- Body -----------------------------------------------------------------

func _build_body() -> void:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = STAND_HEIGHT
	_shape = CollisionShape3D.new()
	_shape.shape = capsule
	_shape.position.y = STAND_HEIGHT / 2.0
	add_child(_shape)

	# Body pivot (turns with the camera) holding the 3D model loaded by code.
	_body_pivot = Node3D.new()
	_body_pivot.name = "Body"
	add_child(_body_pivot)
	_model = PlayerModel.new()
	_model.name = "PlayerModel"
	_body_pivot.add_child(_model)

	# Flashlight on the chest, aims up/down with the camera. [L] toggles it.
	_flashlight_pivot = Node3D.new()
	_flashlight_pivot.name = "FlashlightPivot"
	_flashlight_pivot.position = Vector3(0.15, 1.35, -0.25)
	_body_pivot.add_child(_flashlight_pivot)
	_flashlight = SpotLight3D.new()
	_flashlight.name = "Flashlight"
	_flashlight.light_color = Color(1.0, 0.96, 0.85)
	_flashlight.light_energy = 4.0
	_flashlight.spot_range = 18.0
	_flashlight.spot_angle = 28.0
	_flashlight.spot_attenuation = 0.8
	_flashlight.shadow_enabled = true
	_flashlight_pivot.add_child(_flashlight)
	set_flashlight(false)

	var hand := Node3D.new()
	hand.name = "Hand"
	hand.position = Vector3(0.3, 1.25, -0.25)
	_body_pivot.add_child(hand)

	_hurt_player = AudioStreamPlayer.new()
	_hurt_player.stream = Builder.noise_burst(0.15, 30.0, 0.5)
	_hurt_player.pitch_scale = 0.5
	_hurt_player.volume_db = -8.0
	add_child(_hurt_player)
