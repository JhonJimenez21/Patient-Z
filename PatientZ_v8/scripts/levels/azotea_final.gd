extends Node3D
## PATIENT Z · Rooftop (the end) — scenes/levels/azotea_final.tscn
##
## Everything is placed in the scene: WorldEnvironment (night sky, low fog), Moon and Lightning
## lights, Roof (textured slab, parapets, building below), RoofAccess (the stair hut you come out
## of), Helipad, Helicopter (scenes/vehicles/helicopter.tscn, the Huey), Soldiers (GeneralRex and
## his squad, scenes/npc/soldier.tscn), EmergencyLights (red / blue beacons), Props, Floodlights,
## City (far buildings), Rain (GPUParticles3D), Ambience (rain, wind, thunder), AmbushEvent
## (general_rex_ambush.gd + Area3D), ScreenFade, Player, Player2, HUD, DialogueUI, PauseMenu and
## SplitScreen.
## This script only adds the logic: brings the player from Floor 3, the lightning, and saving.

const Coop = preload("res://scripts/systems/coop.gd")

const LIGHTNING_MIN := 9.0          # seconds between lightning flashes
const LIGHTNING_MAX := 20.0

var floor_name := "Rooftop · Evacuation"     # shown in the saved games list
var player: CharacterBody3D
var player2: CharacterBody3D

var _next_lightning := 6.0

@onready var _lightning: DirectionalLight3D = $Lightning
@onready var _thunder: AudioStreamPlayer = $Ambience/Thunder


func _ready() -> void:
	add_to_group("level")
	player = $Player
	player2 = Coop.setup_players(self)
	GameManager.reset_floor(0, 4)
	GameManager.set_phase(GameManager.Phase.CLEARED)

	# State brought from Floor 3 (health, weapons, ammo, bandages, flashlight)
	if not GameManager.carry_player.is_empty() and not SaveManager.pending_load:
		_bring(player, GameManager.carry_player)
		if player2 and not GameManager.carry_player2.is_empty():
			_bring(player2, GameManager.carry_player2)
		GameManager.carry_player = {}
		GameManager.carry_player2 = {}
		GameManager.notify("ROOFTOP · The evacuation helicopter is waiting.")
		_autosave.call_deferred()

	SaveManager.apply_pending(self)


## Keeps the player where the scene puts it (in front of the roof access door).
func _bring(p: CharacterBody3D, data: Dictionary) -> void:
	data["position"] = SaveManager.vec3_to_array(p.global_position)
	data["yaw"] = p.rotation.y
	p.load_save_data(data)


func _process(delta: float) -> void:
	_next_lightning -= delta
	if _next_lightning <= 0.0:
		_next_lightning = randf_range(LIGHTNING_MIN, LIGHTNING_MAX)
		_flash_lightning()


## Two quick flashes of the Lightning light, then the thunder a moment later.
func _flash_lightning() -> void:
	var tween := create_tween()
	for energy in [2.2, 0.2, 1.6, 0.0]:
		tween.tween_property(_lightning, "light_energy", energy, 0.06)
	tween.tween_interval(randf_range(0.4, 1.4))
	tween.tween_callback(_thunder.play)


# --- Save / load ------------------------------------------------------------------------

func get_save_data() -> Dictionary:
	return {}


func load_save_data(_data: Dictionary) -> void:
	pass


func _autosave() -> void:
	if SaveManager.is_loading or player == null or player.dead or GameManager.ending != "":
		return
	SaveManager.save_game.call_deferred(self, true)
