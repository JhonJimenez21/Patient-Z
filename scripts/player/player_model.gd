extends Node3D
## Loads the player's 3D model (FBX/GLB/TSCN) by code and drives its animation.
## Child of the player body. If the model file is missing, a simple placeholder is built.
##
## The Mixamo "Walking.fbx" faces +Z and walks in place; the game uses -Z as forward,
## so the model is turned 180°.

const Builder = preload("res://scripts/systems/level_builder.gd")

const MODEL_PATH := "res://assets/player/Walking.fbx"
const MODEL_HEIGHT := 1.8          # the model is scaled to this height (metres)
const MODEL_YAW := PI              # rotation so the model looks along -Z
const WALK_ANIM_SPEED := 1.0       # animation speed at walking speed
const RUN_ANIM_SPEED := 1.6
const CROUCH_ANIM_SPEED := 0.6

## Visual layer 2: blood decals (layer 1) don't stain the characters.
const CHARACTER_LAYER := 2

var model: Node3D
var anim_player: AnimationPlayer
var skeleton: Skeleton3D
var walk_animation := ""


func _ready() -> void:
	if ResourceLoader.exists(MODEL_PATH):
		_load_model()
	else:
		push_warning("Player model not found at %s, using placeholder." % MODEL_PATH)
		_build_placeholder()
	_set_layers(self)


func _load_model() -> void:
	var scene: PackedScene = load(MODEL_PATH)
	model = scene.instantiate()
	model.name = "Model"
	add_child(model)
	model.rotation.y = MODEL_YAW

	# Remove helper nodes exported by the FBX (lights, cameras).
	for n in model.find_children("*", "Light3D", true, false):
		n.queue_free()
	for n in model.find_children("*", "Camera3D", true, false):
		n.queue_free()
	var lights := model.find_child("Lights", true, false)
	if lights:
		lights.queue_free()

	var players := model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		anim_player = players[0]
		var names := anim_player.get_animation_list()
		if not names.is_empty():
			walk_animation = names[0]
			anim_player.get_animation(walk_animation).loop_mode = Animation.LOOP_LINEAR
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		skeleton = skeletons[0]

	_fit_height()
	set_moving(0.0)


## Scales the model so it is MODEL_HEIGHT tall with its feet on the ground.
func _fit_height() -> void:
	var box := _model_aabb()
	if box.size.y <= 0.01:
		return
	var factor := MODEL_HEIGHT / box.size.y
	model.scale *= factor
	box = _model_aabb()
	model.position.y -= box.position.y


func _model_aabb() -> AABB:
	var result := AABB()
	var first := true
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


## speed_scale 0 = standing still (pose frozen on the first frame).
func set_moving(speed_scale: float) -> void:
	if anim_player == null or walk_animation == "":
		return
	if speed_scale <= 0.01:
		if anim_player.is_playing():
			anim_player.pause()
		if anim_player.current_animation == "":
			anim_player.play(walk_animation)
			anim_player.seek(0.0, true)
			anim_player.pause()
		return
	anim_player.speed_scale = speed_scale
	if not anim_player.is_playing():
		anim_player.play(walk_animation)


func update_animation(horizontal_speed: float, running: bool, crouching: bool) -> void:
	if horizontal_speed < 0.3:
		set_moving(0.0)
	elif crouching:
		set_moving(CROUCH_ANIM_SPEED)
	elif running:
		set_moving(RUN_ANIM_SPEED)
	else:
		set_moving(WALK_ANIM_SPEED)


func _set_layers(node: Node) -> void:
	if node is VisualInstance3D:
		node.layers = CHARACTER_LAYER
	for child in node.get_children():
		_set_layers(child)


## Used only when the model file is missing.
func _build_placeholder() -> void:
	var uniform := Builder.material(Color(0.2, 0.35, 0.45), 0.8)
	var skin := Builder.material(Color(0.8, 0.62, 0.5), 0.7)
	var dark := Builder.material(Color(0.12, 0.12, 0.14), 0.8)
	Builder.box(self, Vector3(0.18, 0.85, 0.2), Vector3(-0.12, 0.42, 0), dark)
	Builder.box(self, Vector3(0.18, 0.85, 0.2), Vector3(0.12, 0.42, 0), dark)
	Builder.box(self, Vector3(0.5, 0.7, 0.28), Vector3(0, 1.2, 0), uniform)
	Builder.box(self, Vector3(0.13, 0.65, 0.14), Vector3(-0.33, 1.18, 0), uniform)
	Builder.box(self, Vector3(0.13, 0.65, 0.14), Vector3(0.33, 1.18, -0.1), uniform)
	Builder.sphere(self, 0.15, Vector3(0, 1.72, 0), skin)
