extends Node
## Weapons of the player: equip, shoot (raycast from the camera) and reload.

const Builder = preload("res://scripts/systems/level_builder.gd")

const WEAPONS := {
	"rifle": {
		"name": "M-9 Rifle", "mag_size": 24, "start_mag": 24, "start_reserve": 90,
		"damage": 34.0, "pellets": 1, "spread": 0.008, "fire_delay": 0.13,
		"automatic": true, "reload_time": 1.6, "recoil": 0.012,
	},
	"shotgun": {
		"name": "Shotgun", "mag_size": 6, "start_mag": 6, "start_reserve": 18,
		"damage": 18.0, "pellets": 8, "spread": 0.06, "fire_delay": 0.85,
		"automatic": false, "reload_time": 2.2, "recoil": 0.05,
	},
}

var current_weapon := ""

var _player: CharacterBody3D
var _inventory: Node
var _camera_rig: Node3D
var _fire_cooldown := 0.0
var _reload_timer := 0.0
var _gun_model: Node3D
var _muzzle_light: OmniLight3D
var _shot_player: AudioStreamPlayer


## hand: the node the gun is attached to (rotates with the body).
func setup(player: CharacterBody3D, inventory: Node, camera_rig: Node3D, hand: Node3D) -> void:
	_player = player
	_inventory = inventory
	_camera_rig = camera_rig
	_gun_model = Node3D.new()
	hand.add_child(_gun_model)
	_muzzle_light = OmniLight3D.new()
	_muzzle_light.light_color = Color(1.0, 0.8, 0.4)
	_muzzle_light.omni_range = 6.0
	_muzzle_light.light_energy = 0.0
	_muzzle_light.position = Vector3(0, 0, -0.9)
	hand.add_child(_muzzle_light)
	_shot_player = AudioStreamPlayer.new()
	_shot_player.stream = Builder.noise_burst(0.25, 18.0, 0.9)
	_shot_player.volume_db = -6.0
	add_child(_shot_player)


func give_weapon(id: String) -> void:
	_inventory.add_weapon(id, WEAPONS[id])
	GameManager.notify("%s picked up" % WEAPONS[id]["name"])
	equip(id)


func add_ammo(id: String, amount: int) -> void:
	_inventory.add_ammo(id, amount, WEAPONS[id]["name"])


func equip(id: String) -> void:
	current_weapon = id
	_reload_timer = 0.0
	for child in _gun_model.get_children():
		child.queue_free()
	var gun_mat := Builder.material(Color(0.1, 0.1, 0.11), 0.45, 0.6)
	var length := 0.75 if id == "rifle" else 0.85
	Builder.box(_gun_model, Vector3(0.08, 0.1, length), Vector3(0, 0, -length / 2.0), gun_mat)
	Builder.box(_gun_model, Vector3(0.06, 0.16, 0.08), Vector3(0, -0.1, -0.12), gun_mat)


func weapon_text() -> String:
	if current_weapon == "":
		return "Unarmed"
	var a: Dictionary = _inventory.ammo[current_weapon]
	var text := "%s  %d | %d" % [WEAPONS[current_weapon]["name"], a["mag"], a["reserve"]]
	if _reload_timer > 0.0:
		text += "  (reloading...)"
	return text


## Called by the player every physics frame.
func update(delta: float, busy: bool) -> void:
	_fire_cooldown -= delta
	_muzzle_light.light_energy = move_toward(_muzzle_light.light_energy, 0.0, delta * 40.0)
	if _reload_timer > 0.0:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_finish_reload()

	if busy:
		return
	if Input.is_action_just_pressed("px_weapon_1") and _inventory.has_weapon("rifle"):
		equip("rifle")
	if Input.is_action_just_pressed("px_weapon_2") and _inventory.has_weapon("shotgun"):
		equip("shotgun")
	if current_weapon == "":
		return
	if Input.is_action_just_pressed("px_reload"):
		_start_reload()

	var data: Dictionary = WEAPONS[current_weapon]
	var wants_fire := Input.is_action_pressed("px_shoot") if data["automatic"] else Input.is_action_just_pressed("px_shoot")
	if wants_fire and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and _fire_cooldown <= 0.0 and _reload_timer <= 0.0:
		if _inventory.ammo[current_weapon]["mag"] > 0:
			fire()
		else:
			_start_reload()


func fire() -> void:
	var data: Dictionary = WEAPONS[current_weapon]
	_fire_cooldown = data["fire_delay"]
	_inventory.ammo[current_weapon]["mag"] -= 1
	_player.register_shot()
	_muzzle_light.light_energy = 6.0
	_shot_player.pitch_scale = 1.0 if current_weapon == "rifle" else 0.7
	_shot_player.play()
	_camera_rig.add_recoil(data["recoil"])

	var camera: Camera3D = _camera_rig.camera
	var space := _player.get_world_3d().direct_space_state
	var origin := camera.global_position
	var forward := -camera.global_basis.z
	for i in data["pellets"]:
		var spread: float = data["spread"]
		var dir := (forward + camera.global_basis.x * randf_range(-spread, spread) + camera.global_basis.y * randf_range(-spread, spread)).normalized()
		var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * 80.0, 1 | 4, [_player.get_rid()])
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var flesh: bool = hit.collider.has_method("take_damage")
		if flesh:
			hit.collider.take_damage(data["damage"], hit.position)
		_spawn_impact(hit.position, flesh)


func _start_reload() -> void:
	if current_weapon == "" or _reload_timer > 0.0:
		return
	var a: Dictionary = _inventory.ammo[current_weapon]
	if a["reserve"] <= 0:
		GameManager.notify("No ammo left")
		return
	if a["mag"] >= WEAPONS[current_weapon]["mag_size"]:
		return
	_reload_timer = WEAPONS[current_weapon]["reload_time"]


func _finish_reload() -> void:
	var a: Dictionary = _inventory.ammo[current_weapon]
	var needed: int = WEAPONS[current_weapon]["mag_size"] - a["mag"]
	var taken: int = min(needed, a["reserve"])
	a["mag"] += taken
	a["reserve"] -= taken


func _spawn_impact(pos: Vector3, flesh: bool) -> void:
	var color := Color(0.6, 0.0, 0.0) if flesh else Color(1.0, 0.85, 0.5)
	var mat := Builder.material(color, 0.5, 0.0, color, 2.0)
	var spark := Builder.sphere(get_tree().current_scene, 0.05, pos, mat)
	var tween := spark.create_tween()
	tween.tween_property(spark, "scale", Vector3.ONE * 0.1, 0.25)
	tween.tween_callback(spark.queue_free)
