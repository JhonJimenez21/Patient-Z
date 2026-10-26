extends StaticBody3D
## Heavy, rusty door that takes you to another scene (scenes/items/rooftop_door.tscn).
## Two of them in the game, set in the Inspector:
##   · Containment Core (Floor 3): lock = "final_boss", sign "LAB OFFICE" → sala_doctor.tscn
##   · top of the L-shaped stairs in the Lab Office: lock = "rooftop_key", sign "ROOF ACCESS"
##     → azotea_final.tscn
## With what it needs, [F] unlocks it, it swings open and you go through (target_scene).

const Config = preload("res://scripts/systems/level_config.gd")

@export_file("*.tscn") var target_scene := Config.ROOFTOP_SCENE
## "rooftop_key": needs the key the wounded doctor gives you · "final_boss": Patient Z must be dead
@export_enum("rooftop_key", "final_boss") var lock := "rooftop_key"
@export var sign_text := "ROOF ACCESS":
	set(value):
		sign_text = value
		if is_node_ready():
			%PlateText.text = value
@export var go_text := "[F] Unlock and go up to the rooftop"

var is_open := false

@onready var _leaf: Node3D = %Leaf
@onready var _lock_mat: StandardMaterial3D = %LockLight.material_override
@onready var _unlock_sound: AudioStreamPlayer3D = %UnlockSound


func _ready() -> void:
	add_to_group("interactable")
	%PlateText.text = sign_text


func _process(_delta: float) -> void:
	var color := Color.GREEN if can_open() else Color.RED
	_lock_mat.albedo_color = color
	_lock_mat.emission = color


func can_open() -> bool:
	return GameManager.final_boss_dead if lock == "final_boss" else GameManager.has_rooftop_key


func get_prompt() -> String:
	if is_open:
		return ""
	if can_open():
		return go_text
	if lock == "final_boss":
		return "[F] Locked · Kill Patient Z first"
	if GameManager.final_boss_dead:
		return "[F] Locked · The wounded doctor has the key"
	return "[F] Locked · Rooftop Key required"


func interact_action() -> StringName:
	return &"px_interact"


func interact(player: Node) -> void:
	if is_open:
		return
	if not can_open():
		GameManager.notify(get_prompt().trim_prefix("[F] ").replace("Locked · ", "Locked: ") + ".")
		return
	is_open = true
	_unlock_sound.play()
	var tween := create_tween()
	tween.tween_property(_leaf, "rotation:y", deg_to_rad(-100.0), 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(GameManager.go_to_floor.bind(target_scene, player))
