extends Node3D
## PATIENT Z · Floor 3 · Lab Office (scenes/levels/sala_doctor.tscn): the room behind the
## Containment Core, opened when Patient Z dies.
##
## Everything is placed in the scene: WorldEnvironment, Office (floor, walls, ceiling and their
## collisions), Stairwell (L-shaped stairs up to the roof door: LowerFlight, MidLanding,
## UpperFlight, TopLanding, Railings), Lights, Furniture, Decor, EntranceDoor, Desenlace
## (DyingDoctor, RooftopDoor and the Logic node with piso_3_desenlace.gd), Player, Player2, HUD,
## DialogueUI, PauseMenu and SplitScreen.
## This script only brings the player from the Core and saves the game.

const Coop = preload("res://scripts/systems/coop.gd")

var floor_name := "Floor 3 · Lab Office"     # shown in the saved games list
var player: CharacterBody3D
var player2: CharacterBody3D


func _ready() -> void:
	add_to_group("level")
	player = $Player
	player2 = Coop.setup_players(self)
	# GameManager keeps the Floor 3 state (Patient Z is dead): no reset here.
	if not GameManager.carry_player.is_empty() and not SaveManager.pending_load:
		_bring(player, GameManager.carry_player)
		if player2 and not GameManager.carry_player2.is_empty():
			_bring(player2, GameManager.carry_player2)
		GameManager.carry_player = {}
		GameManager.carry_player2 = {}
		GameManager.notify("LAB OFFICE · Someone is breathing in the corner...")
		_autosave.call_deferred()
	SaveManager.apply_pending(self)


func _bring(p: CharacterBody3D, data: Dictionary) -> void:
	data["position"] = SaveManager.vec3_to_array(p.global_position)
	data["yaw"] = p.rotation.y
	p.load_save_data(data)


func get_save_data() -> Dictionary:
	return {}


func load_save_data(_data: Dictionary) -> void:
	pass


func _autosave() -> void:
	if SaveManager.is_loading or player == null or player.dead:
		return
	SaveManager.save_game.call_deferred(self, true)
