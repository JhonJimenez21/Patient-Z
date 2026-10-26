extends Node
## End of Floor 3 (node "Desenlace/Logic" in scenes/levels/sala_doctor.tscn, the Lab Office behind
## the Containment Core).
##
## 1. Patient Z is dead → the wounded doctor in the corner can talk.
## 2. [E] to talk with him → he tells you about the experiments, gives you the Rooftop Key and dies.
## 3. Up the L-shaped stairs, the roof door (rooftop_door.gd) opens with the key → azotea_final.tscn.
## Set the two nodes in the Inspector.

const DialogueDB = preload("res://scripts/systems/dialogue_db.gd")

@export var doctor: Node3D           ## scenes/npc/dying_doctor.tscn
@export var rooftop_door: Node3D     ## scenes/items/rooftop_door.tscn at the top of the stairs


func _ready() -> void:
	doctor.key_given.connect(_on_key_given)
	GameManager.final_boss_killed.connect(_refresh)
	SaveManager.game_loaded.connect(func(_slot_id): _refresh())
	_refresh()


## Puts the doctor in the right state (arriving from the Core or loading a game).
func _refresh() -> void:
	if GameManager.doctor_dead or GameManager.has_rooftop_key:
		if doctor.state != doctor.State.DEAD:
			doctor.die(true)
	elif GameManager.final_boss_dead:
		doctor.wake()


func _on_key_given() -> void:
	GameManager.give_rooftop_key()
	GameManager.notify("He's gone... Take the stairs up to the roof door.")
	var level := get_tree().get_first_node_in_group("level")
	if level and level.has_method("_autosave"):
		level._autosave()
