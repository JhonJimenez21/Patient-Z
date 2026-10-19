extends StaticBody3D
## Weapon lying on a table. Built on top of a lab table.

const Builder = preload("res://scripts/systems/level_builder.gd")

var weapon_id := "rifle"
var _gun_meshes: Array[Node3D] = []


func setup(id: String) -> void:
	weapon_id = id
	add_to_group("interactable")

	# Table
	var steel := Builder.material(Color(0.7, 0.72, 0.75), 0.3, 0.7)
	Builder.box(self, Vector3(1.6, 0.06, 0.8), Vector3(0, 0.9, 0), steel)
	for x in [-0.72, 0.72]:
		for z in [-0.32, 0.32]:
			Builder.box(self, Vector3(0.05, 0.9, 0.05), Vector3(x, 0.45, z), steel)
	Builder.box_collision(self, Vector3(1.6, 0.95, 0.8), Vector3(0, 0.47, 0))

	# Weapon
	var gun_mat := Builder.material(Color(0.12, 0.12, 0.13), 0.45, 0.6)
	if weapon_id == "rifle":
		_gun_meshes.append(Builder.box(self, Vector3(0.75, 0.09, 0.07), Vector3(0, 0.98, 0), gun_mat))
		_gun_meshes.append(Builder.box(self, Vector3(0.08, 0.16, 0.05), Vector3(0.05, 0.92, 0.12), gun_mat))
		_gun_meshes.append(Builder.box(self, Vector3(0.22, 0.1, 0.06), Vector3(-0.42, 0.97, 0), gun_mat))
	else:
		var wood := Builder.material(Color(0.4, 0.25, 0.12), 0.7)
		_gun_meshes.append(Builder.box(self, Vector3(0.8, 0.07, 0.07), Vector3(0.05, 0.98, 0), gun_mat))
		_gun_meshes.append(Builder.box(self, Vector3(0.3, 0.1, 0.08), Vector3(-0.45, 0.97, 0), wood))


func get_prompt() -> String:
	return "[F] Take the gun" if weapon_id == "rifle" else "[F] Take the shotgun"


func interact_action() -> StringName:
	return &"px_interact"


func interact(player: Node) -> void:
	player.give_weapon(weapon_id)
	if weapon_id == "rifle":
		GameManager.has_rifle = true
	remove_from_group("interactable")
	for mesh in _gun_meshes:
		mesh.queue_free()
	_gun_meshes.clear()
