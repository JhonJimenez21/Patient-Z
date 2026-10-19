extends StaticBody3D
## Locked gate with the stairs to Floor 2. Opens when the floor is cleared.

const Builder = preload("res://scripts/systems/level_builder.gd")
const Config = preload("res://scripts/systems/level_config.gd")
const StairsSign = preload("res://scripts/environment/stairs_sign.gd")

var _light_mat: StandardMaterial3D


func setup(along_x: bool, cell_size: float, height: float) -> void:
	add_to_group("interactable")
	var size := Vector3(cell_size, height, 0.3) if along_x else Vector3(0.3, height, cell_size)
	var gate := Builder.material(Color(0.2, 0.22, 0.25), 0.5, 0.7)
	Builder.box(self, size, Vector3(0, height / 2.0, 0), gate)

	var yellow := Builder.material(Color(0.95, 0.75, 0.1), 0.6)
	var bar := Vector3(size.x + 0.02, 0.15, size.z + 0.02)
	for y in [0.4, 0.8, 1.2]:
		Builder.box(self, bar, Vector3(0, y, 0), yellow)

	_light_mat = Builder.material(Color.RED, 0.4, 0.0, Color.RED, 4.0)
	Builder.box(self, Vector3(size.x + 0.04, 0.1, size.z + 0.04), Vector3(0, height - 0.3, 0), _light_mat)

	# "STAIRS" signs fixed on both faces of the gate (no floating text).
	var face := (size.z if along_x else size.x) / 2.0 + 0.04
	for side in [1.0, -1.0]:
		var sign := StairsSign.new()
		sign.setup("STAIRS", min(cell_size * 0.7, 2.0), 0.5)
		var normal := Vector3(0, 0, side) if along_x else Vector3(side, 0, 0)
		sign.position = normal * face + Vector3(0, height - 0.85, 0)
		sign.rotation.y = atan2(normal.x, normal.z)   # front (+Z) faces outwards
		add_child(sign)

	Builder.box_collision(self, size, Vector3(0, height / 2.0, 0))


func _process(_delta: float) -> void:
	var color := Color.GREEN if GameManager.can_use_stairs() else Color.RED
	_light_mat.albedo_color = color
	_light_mat.emission = color


func get_prompt() -> String:
	if GameManager.can_use_stairs():
		return "[F] Go to Floor 2"
	return "[F] Locked · Eliminate the infected (%d/%d)" % [GameManager.kills, GameManager.kill_target]


func interact_action() -> StringName:
	return &"px_interact"


func interact(_player: Node) -> void:
	if not GameManager.can_use_stairs():
		if GameManager.phase == GameManager.Phase.SURVIVE:
			GameManager.notify("The stairs are locked. Eliminate all the infected first.")
		else:
			GameManager.notify("The stairs are locked.")
		return
	if ResourceLoader.exists(Config.FLOOR_2_SCENE):
		get_tree().change_scene_to_file(Config.FLOOR_2_SCENE)
	else:
		GameManager.notify("Floor 2 is not built yet (%s)" % Config.FLOOR_2_SCENE)
