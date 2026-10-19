extends StaticBody3D
## Medical cabinet that can be opened once with [F]. Front faces local +Z.

const Builder = preload("res://scripts/systems/level_builder.gd")

## "syringe", "bandage", "ammo_rifle", "ammo_shotgun" or "" (empty)
var contents := ""
var is_open := false

var _hinge: Node3D


func setup(item: String) -> void:
	contents = item
	add_to_group("interactable")

	var white := Builder.material(Color(0.88, 0.9, 0.92), 0.4, 0.2)
	var dark := Builder.material(Color(0.25, 0.27, 0.3), 0.6)
	Builder.box(self, Vector3(1.0, 1.9, 0.5), Vector3(0, 0.95, 0), white)
	Builder.box(self, Vector3(0.9, 1.75, 0.02), Vector3(0, 0.95, 0.24), dark)  # inside back
	Builder.box(self, Vector3(0.9, 0.03, 0.4), Vector3(0, 1.0, 0.03), white)    # shelf
	Builder.box(self, Vector3(0.9, 0.03, 0.4), Vector3(0, 1.45, 0.03), white)   # shelf

	if contents == "syringe":
		var glass := Builder.material(Color(0.7, 0.9, 1.0, 0.6), 0.1)
		var syringe := Builder.cylinder(self, 0.03, 0.25, Vector3(0.1, 1.08, 0.1), glass)
		syringe.rotation.z = PI / 2.0
	elif contents != "":
		var box_color := Color(0.85, 0.2, 0.2) if contents == "bandage" else Color(0.35, 0.4, 0.25)
		Builder.box(self, Vector3(0.3, 0.15, 0.2), Vector3(0.1, 1.1, 0.05), Builder.material(box_color))

	_hinge = Node3D.new()
	_hinge.position = Vector3(-0.5, 0, 0.27)
	add_child(_hinge)
	var door_mat := Builder.material(Color(0.8, 0.83, 0.86), 0.35, 0.3)
	Builder.box(_hinge, Vector3(1.0, 1.85, 0.04), Vector3(0.5, 0.95, 0), door_mat)
	Builder.box(_hinge, Vector3(0.04, 0.3, 0.05), Vector3(0.9, 1.0, 0.04), dark)  # handle

	Builder.box_collision(self, Vector3(1.0, 1.9, 0.5), Vector3(0, 0.95, 0))


func get_prompt() -> String:
	return "" if is_open else "[F] open"


func interact_action() -> StringName:
	return &"px_interact"


func interact(player: Node) -> void:
	if is_open:
		return
	is_open = true
	remove_from_group("interactable")
	var tween := create_tween()
	tween.tween_property(_hinge, "rotation:y", -1.9, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	match contents:
		"syringe":
			GameManager.add_syringe()
			GameManager.notify("Syringe found (%d/%d)" % [GameManager.syringes, GameManager.SYRINGES_NEEDED])
		"bandage":
			player.add_bandages(1)
			GameManager.notify("Bandage found")
		"ammo_rifle":
			player.add_ammo("rifle", 24)
		"ammo_shotgun":
			player.add_ammo("shotgun", 8)
		_:
			GameManager.notify("Empty...")
