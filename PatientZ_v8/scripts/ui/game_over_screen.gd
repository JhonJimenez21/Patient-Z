extends Control
## Game Over screen at the end of PATIENT Z (scenes/ui/game_over_screen.tscn).
## Layout in the scene: Background, Vignette, Content (YouDied, Thanks, Buttons) and Drone.
## Mouse only: the buttons don't take keyboard / gamepad focus. Their pressed() signals are
## connected in the scene (Node > Signals).
##   "Volver a jugar" → a new game from Floor 1 (same number of players)
##   "Salir del juego" → closes the game

const GAME_SCENE := "res://main.tscn"

@onready var _content: Control = %Content


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Everything fades in, one piece after the other.
	var tween := create_tween()
	var delay := 0.3
	for child in _content.get_children():
		child.modulate.a = 0.0
		tween.parallel().tween_property(child, "modulate:a", 1.0, 1.2).set_delay(delay)
		delay += 0.7


func _on_play_again_pressed() -> void:
	GameManager.next_floor_scene = ""
	GameManager.carry_player = {}
	GameManager.carry_player2 = {}
	GameManager.ending = ""
	SaveManager.start_new_game()
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()
