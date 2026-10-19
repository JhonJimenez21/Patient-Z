extends Node
## Game scene opened by the main menu (GAME_SCENE = "res://main.tscn").
## It contains Floor 1 as a child (scenes/levels/laboratorio_piso1.tscn).
## [Esc] frees the mouse; [Esc] + [M] goes back to the main menu.

const MENU_SCENE := "res://scenes/ui/MainMenu.tscn"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_M \
			and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		get_tree().change_scene_to_file(MENU_SCENE)
