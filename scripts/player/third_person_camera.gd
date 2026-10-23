extends Node3D
## Over-the-shoulder camera (CameraRig in scenes/player/player.tscn).
## Children: SpringArm3D → Camera3D. Rotates with the mouse.

const MOUSE_SENSITIVITY := 0.0025

var yaw := 0.0
var pitch := -0.15

@onready var camera: Camera3D = %Camera3D
@onready var _spring: SpringArm3D = %SpringArm3D


func setup(body: CollisionObject3D, start_yaw: float) -> void:
	yaw = start_yaw
	_spring.add_excluded_object(body.get_rid())   # the arm must not hit the player himself


func _unhandled_input(event: InputEvent) -> void:
	if get_parent().dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * MOUSE_SENSITIVITY
		pitch = clamp(pitch - event.relative.y * MOUSE_SENSITIVITY, -1.2, 0.9)


func _process(_delta: float) -> void:
	rotation.y = yaw
	_spring.rotation.x = pitch


func set_height(height: float) -> void:
	position.y = height


func add_recoil(amount: float) -> void:
	pitch = min(0.9, pitch + amount)


## Direction the camera looks at.
func forward() -> Vector3:
	return -camera.global_basis.z
