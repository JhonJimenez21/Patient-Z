extends StaticBody3D
## The boss of Floor 1. Gives the syringe task, then the keycard.

const Builder = preload("res://scripts/systems/level_builder.gd")

const DialogueDB = preload("res://scripts/systems/dialogue_db.gd")


func _ready() -> void:
	add_to_group("interactable")
	_build_body()
	Builder.box_collision(self, Vector3(0.7, 1.8, 0.5), Vector3(0, 0.9, 0))


func get_prompt() -> String:
	return "[E] to talk with your boss"


func interact_action() -> StringName:
	return &"px_talk"


func interact(player: Node3D) -> void:
	var dialogue := get_tree().get_first_node_in_group("dialogue_ui")
	if dialogue == null or dialogue.is_busy():
		return
	_face(player.global_position)

	match GameManager.phase:
		GameManager.Phase.INTRO:
			dialogue.show_dialogue(DialogueDB.BOSS_NAME, DialogueDB.BOSS_INTRO, _on_intro_finished)
		GameManager.Phase.COLLECT:
			if GameManager.has_all_syringes():
				GameManager.deliver_syringes()  # starts the alarm
				dialogue.show_dialogue(DialogueDB.BOSS_NAME, DialogueDB.BOSS_ALARM, GameManager.give_keycard)
			else:
				dialogue.show_dialogue(DialogueDB.BOSS_NAME, [
					DialogueDB.BOSS_MISSING_SYRINGES % [GameManager.syringes, GameManager.SYRINGES_NEEDED],
				])
		GameManager.Phase.SURVIVE:
			dialogue.show_dialogue(DialogueDB.BOSS_NAME, [DialogueDB.BOSS_SURVIVE])
		GameManager.Phase.CLEARED:
			dialogue.show_dialogue(DialogueDB.BOSS_NAME, [DialogueDB.BOSS_CLEARED])


func _on_intro_finished() -> void:
	GameManager.set_phase(GameManager.Phase.COLLECT)
	GameManager.notify("The first 4 rooms are now open")


func _face(target: Vector3) -> void:
	var flat := Vector3(target.x, global_position.y, target.z)
	if flat.distance_to(global_position) > 0.1:
		look_at(flat, Vector3.UP)
		rotate_y(PI)  # the model's front is +Z


func _build_body() -> void:
	var coat := Builder.material(Color(0.93, 0.94, 0.95), 0.8)
	var pants := Builder.material(Color(0.15, 0.17, 0.22), 0.8)
	var skin := Builder.material(Color(0.86, 0.68, 0.55), 0.7)
	var hair := Builder.material(Color(0.55, 0.55, 0.57), 0.9)
	var glass := Builder.material(Color(0.1, 0.1, 0.1), 0.3, 0.5)

	Builder.box(self, Vector3(0.18, 0.8, 0.2), Vector3(-0.12, 0.4, 0), pants)
	Builder.box(self, Vector3(0.18, 0.8, 0.2), Vector3(0.12, 0.4, 0), pants)
	Builder.box(self, Vector3(0.52, 0.75, 0.3), Vector3(0, 1.15, 0), coat)          # torso
	Builder.box(self, Vector3(0.56, 0.35, 0.32), Vector3(0, 0.75, 0), coat)          # coat tail
	Builder.box(self, Vector3(0.13, 0.7, 0.15), Vector3(-0.34, 1.15, 0), coat)       # arms
	Builder.box(self, Vector3(0.13, 0.7, 0.15), Vector3(0.34, 1.15, 0), coat)
	Builder.sphere(self, 0.15, Vector3(0, 1.68, 0), skin)                            # head
	Builder.box(self, Vector3(0.3, 0.08, 0.3), Vector3(0, 1.8, -0.02), hair)
	Builder.box(self, Vector3(0.24, 0.05, 0.02), Vector3(0, 1.7, 0.15), glass)       # glasses
	Builder.box(self, Vector3(0.1, 0.14, 0.02), Vector3(0.14, 1.3, 0.16), Builder.material(Color(0.2, 0.5, 0.9)))  # ID badge
