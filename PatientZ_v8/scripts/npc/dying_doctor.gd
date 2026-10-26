extends StaticBody3D
## Wounded doctor lying in the Containment Core of Floor 3 (scenes/npc/dying_doctor.tscn).
## Nodes: Model/Doctor (assets/npc/doctor.fbx lying on the floor) · BloodPool · Breath (3D sound)
## · Glow (dim light over him) · Key (the Rooftop Key next to his hand).
##
## States (piso_3_desenlace.gd changes them):
##   UNCONSCIOUS → Patient Z is alive: you can't talk to him yet.
##   DYING       → Patient Z is dead: "[E] to talk". He gives you the Rooftop Key and dies.
##   DEAD        → he is gone (also after loading a game where you already have the key).

signal key_given

const DialogueDB = preload("res://scripts/systems/dialogue_db.gd")
const CHARACTER_LAYER := 2        # blood decals don't stain him

enum State { UNCONSCIOUS, DYING, DEAD }

var state: int = State.UNCONSCIOUS

var _breath_time := 0.0

@onready var _model: Node3D = %Model
@onready var _breath: AudioStreamPlayer3D = %Breath
@onready var _glow: OmniLight3D = %Glow
@onready var _key: Node3D = %Key


func _ready() -> void:
	add_to_group("interactable")
	for mesh in _model.find_children("*", "MeshInstance3D", true, false):
		mesh.layers = CHARACTER_LAYER
	# He doesn't write on his clipboard any more: the animation stays still on its first frame.
	for anim_player: AnimationPlayer in _model.find_children("*", "AnimationPlayer", true, false):
		anim_player.stop()


func _process(delta: float) -> void:
	if state == State.DEAD:
		return
	# Weak breathing: the chest goes up and down and a groan now and then.
	_breath_time += delta
	_model.scale.y = 1.0 + 0.012 * sin(_breath_time * (2.2 if state == State.DYING else 1.4))
	if state == State.DYING and not _breath.playing and fmod(_breath_time, 4.5) < delta:
		_breath.play()


## Patient Z is dead: he can talk now.
func wake() -> void:
	if state == State.UNCONSCIOUS:
		state = State.DYING
		_glow.light_energy = 0.6


func get_prompt() -> String:
	return "[E] to talk" if state == State.DYING else ""


func interact_action() -> StringName:
	return &"px_talk"


func interact(_player: Node3D) -> void:
	var dialogue := get_tree().get_first_node_in_group("dialogue_ui")
	if dialogue == null or dialogue.is_busy() or state != State.DYING:
		return
	dialogue.show_dialogue(DialogueDB.DOCTOR_NAME, DialogueDB.DOCTOR_DYING, _on_dialogue_finished)


func _on_dialogue_finished() -> void:
	die()
	key_given.emit()


## His last breath: the key is gone from his hand, the light over him goes out.
func die(instant := false) -> void:
	state = State.DEAD
	remove_from_group("interactable")
	_key.visible = false
	_breath.stop()
	_model.scale.y = 1.0
	if instant:
		_glow.light_energy = 0.0
		return
	var tween := create_tween()
	tween.tween_property(_glow, "light_energy", 0.0, 2.5)
