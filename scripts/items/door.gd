extends StaticBody3D
## Sliding lab door. "start" doors open after talking to the boss,
## "keycard" doors need the keycard.

signal opened(cell: Vector2i)

const Builder = preload("res://scripts/systems/level_builder.gd")

var cell := Vector2i.ZERO
var kind := "start"
var is_open := false

var _panel: Node3D
var _shape: CollisionShape3D
var _reader_mat: StandardMaterial3D
var _height := 3.2


func setup(door_cell: Vector2i, door_kind: String, along_x: bool, cell_size: float, height: float) -> void:
	cell = door_cell
	kind = door_kind
	_height = height
	add_to_group("interactable")

	var size := Vector3(cell_size, height, 0.25) if along_x else Vector3(0.25, height, cell_size)
	_panel = Node3D.new()
	add_child(_panel)
	var metal := Builder.material(Color(0.62, 0.66, 0.7), 0.35, 0.6)
	Builder.box(_panel, size, Vector3(0, height / 2.0, 0), metal)

	var stripe_color := Color(0.15, 0.55, 0.9) if kind == "start" else Color(0.9, 0.55, 0.1)
	var stripe := Builder.material(stripe_color, 0.5)
	var stripe_size := Vector3(size.x + 0.02, 0.18, size.z + 0.02)
	Builder.box(_panel, stripe_size, Vector3(0, 1.1, 0), stripe)

	# Card reader light (red = locked, green = can open)
	_reader_mat = Builder.material(Color.RED, 0.4, 0.0, Color.RED, 3.0)
	var reader_offset := Vector3(cell_size * 0.38, 1.3, 0.16) if along_x else Vector3(0.16, 1.3, cell_size * 0.38)
	Builder.box(self, Vector3(0.12, 0.18, 0.12), reader_offset, _reader_mat)
	Builder.box(self, Vector3(0.12, 0.18, 0.12), -reader_offset + Vector3(0, 2.6, 0), _reader_mat)

	_shape = Builder.box_collision(self, size, Vector3(0, height / 2.0, 0))


func _process(_delta: float) -> void:
	if is_open:
		return
	var color := Color.GREEN if _can_open() else Color.RED
	_reader_mat.albedo_color = color
	_reader_mat.emission = color


func get_prompt() -> String:
	if is_open:
		return ""
	if kind == "start":
		if GameManager.phase == GameManager.Phase.INTRO:
			return "Locked · Talk to your boss first"
		return "[F] Open"
	if not GameManager.has_keycard:
		return "[F] Locked · Keycard required"
	return "[F] to open the door"


func interact_action() -> StringName:
	return &"px_interact"


func interact(_player: Node) -> void:
	if is_open:
		return
	if not _can_open():
		if kind == "start":
			GameManager.notify("Talk to your boss first.")
		else:
			GameManager.notify("You need a keycard to open this door.")
		return
	open()


func open() -> void:
	is_open = true
	remove_from_group("interactable")
	_shape.set_deferred("disabled", true)
	_reader_mat.albedo_color = Color.GREEN
	_reader_mat.emission = Color.GREEN
	var tween := create_tween()
	tween.tween_property(_panel, "position:y", _height - 0.15, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	opened.emit(cell)


func _can_open() -> bool:
	if kind == "start":
		return GameManager.phase != GameManager.Phase.INTRO
	return GameManager.has_keycard
