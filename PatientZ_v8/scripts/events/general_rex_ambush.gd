extends Area3D
## The betrayal on the rooftop (node AmbushEvent in scenes/levels/azotea_final.tscn).
##
## When a player walks into this Area3D (near the helicopter):
##   1. The players lose control, the HUD hides and AmbushCamera takes over.
##   2. General Rex and his soldiers turn and aim at the players (rifles cocking, weapon lights).
##   3. General Rex speaks (DialogueDB.REX_AMBUSH).
##   4. Rex gives the order and the squad fires: shots, the players' death scream, red flash.
##   5. Fade to black and change to the Game Over screen (game_over_scene).
## Every node is set in the Inspector.

const DialogueDB = preload("res://scripts/systems/dialogue_db.gd")

@export var general: Node3D                  ## General Rex (scenes/npc/soldier.tscn + officer cap)
@export var soldiers: Array[Node3D] = []     ## the rest of the squad
@export var ambush_camera: Camera3D
@export var cock_sound: AudioStreamPlayer3D  ## rifles cocking
@export var death_scream: AudioStreamPlayer  ## the player's scream when the bullets hit
@export var flash: ColorRect                 ## red flash of the shot (ScreenFade/Flash)
@export var fade: ColorRect                  ## black fade at the end (ScreenFade/Fade)
@export_file("*.tscn") var game_over_scene := "res://scenes/ui/game_over_screen.tscn"
@export var aim_time := 1.4                  ## seconds between aiming and Rex talking
@export var fire_delay := 0.8                ## seconds of silence after "Fire."
@export var fade_time := 2.5

var triggered := false

var _players: Array = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if triggered or not body.is_in_group("player") or body.dead:
		return
	triggered = true
	_run(body)


func _squad() -> Array:
	return [general] + soldiers


func _run(target: Node3D) -> void:
	_players = get_tree().get_nodes_in_group("player").filter(func(p): return not p.dead)
	for p in _players:
		p.cutscene = true
		p.velocity = Vector3.ZERO
		p.current_prompt = ""
	for hud in get_tree().get_nodes_in_group("hud"):
		hud.set_cinematic(true)
	_use_camera(target)

	# They raise their rifles at the players (Rex at the one who walked in).
	var squad := _squad()
	for i in squad.size():
		squad[i].aim_at(target if i == 0 else _players[i % _players.size()])
	cock_sound.play()
	await get_tree().create_timer(aim_time).timeout

	var dialogue := get_tree().get_first_node_in_group("dialogue_ui")
	dialogue.show_dialogue(DialogueDB.REX_NAME, DialogueDB.REX_AMBUSH, _open_fire)


func _open_fire() -> void:
	await get_tree().create_timer(fire_delay).timeout
	GameManager.start_ending("bad")
	# Rex fires first: the players are hit and scream. Then the rest of the squad.
	general.fire()
	for p in _players:
		p.take_hit(p.health + 1000.0, 0.0)
	death_scream.play()
	flash.color.a = 0.85
	create_tween().tween_property(flash, "color:a", 0.3, 0.6)
	await get_tree().create_timer(0.3).timeout
	for burst in 2:
		for s in soldiers + [general]:
			s.fire()
			await get_tree().create_timer(0.1).timeout
	# Fade to black, silence, Game Over screen.
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, fade_time)
	tween.parallel().tween_property(flash, "color:a", 0.0, fade_time)
	for node in get_tree().current_scene.find_children("*", "", true, false):
		if (node is AudioStreamPlayer or node is AudioStreamPlayer3D) and node != death_scream:
			tween.parallel().tween_property(node, "volume_db", -60.0, fade_time)
	tween.tween_interval(0.8)
	tween.tween_callback(get_tree().change_scene_to_file.bind(game_over_scene))


## AmbushCamera goes over the shoulder of the target player, looking at General Rex and the
## helicopter behind him, and pushes in slowly during the dialogue.
func _use_camera(target: Node3D) -> void:
	if ambush_camera == null:
		return
	var look := general.global_position + Vector3(0, 1.4, 0)
	var to_rex := general.global_position - target.global_position
	to_rex.y = 0.0
	to_rex = to_rex.normalized()
	var right := to_rex.cross(Vector3.UP).normalized()
	ambush_camera.global_position = target.global_position - to_rex * 2.6 + right * 0.9 + Vector3(0, 1.75, 0)
	ambush_camera.look_at(look, Vector3.UP)
	ambush_camera.make_current()
	var split := get_tree().get_first_node_in_group("split_screen")
	if split:
		split.cinematic_camera = ambush_camera
	var tween := create_tween()
	tween.tween_property(ambush_camera, "global_position", ambush_camera.global_position + to_rex * 1.6, 9.0).set_trans(Tween.TRANS_SINE)
