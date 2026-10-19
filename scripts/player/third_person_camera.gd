extends Node3D
## Over-the-shoulder camera. Child of the player, rotates with the mouse.

const MOUSE_SENSITIVITY := 0.0025
const SHOULDER_OFFSET := Vector3(0.8, 0.1, 0)
const DISTANCE := 2.1

var yaw := 0.0
var pitch := -0.15
var camera: Camera3D

var _spring: SpringArm3D


func setup(body: CollisionObject3D, height: float, start_yaw: float) -> void:
	yaw = start_yaw
	position = Vector3(0, height, 0)
	_spring = SpringArm3D.new()
	_spring.position = SHOULDER_OFFSET
	_spring.spring_length = DISTANCE
	_spring.margin = 0.2
	_spring.collision_mask = 1
	var probe := SphereShape3D.new()
	probe.radius = 0.2
	_spring.shape = probe
	_spring.add_excluded_object(body.get_rid())
	add_child(_spring)
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.current = true
	_spring.add_child(camera)


func _unhandled_input(event: InputEvent) -> void:
	if get_parent().dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * MOUSE_SENSITIVITY
		pitch = clamp(pitch - event.relative.y * MOUSE_SENSITIVITY, -1.2, 0.9)


func _process(_delta: float) -> void:
	rotation.y = yaw
	if _spring:
		_spring.rotation.x = pitch


func set_height(height: float) -> void:
	position.y = height


func add_recoil(amount: float) -> void:
	pitch = min(0.9, pitch + amount)


## Direction the camera looks at.
func forward() -> Vector3:
	return -camera.global_basis.z
