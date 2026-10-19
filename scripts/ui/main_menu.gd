extends Control
## Main menu. Builds its own UI, shows the background image and plays the menu music.
## If the image or the music file doesn't exist yet, the menu still works.

const GAME_SCENE := "res://main.tscn"
const BACKGROUND_IMAGE := "res://assets/img/menu.jpg"
const MUSIC := "res://assets/audio/Horror Game Menu Music 1 Redone.mp3"
const TITLE := "PATIENT Z"


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_menu()
	_play_music()


func _build_menu() -> void:
	if ResourceLoader.exists(BACKGROUND_IMAGE):
		var background := TextureRect.new()
		background.texture = load(BACKGROUND_IMAGE)
		background.set_anchors_preset(Control.PRESET_FULL_RECT)
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		add_child(background)
	else:
		var color := ColorRect.new()
		color.color = Color(0.05, 0.05, 0.08)
		color.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(color)

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 15)
	center.add_child(box)

	var title := Label.new()
	title.text = TITLE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(0.85, 0.1, 0.1))
	box.add_child(title)

	var play_button := Button.new()
	play_button.text = "Play"
	play_button.custom_minimum_size = Vector2(220, 50)
	play_button.pressed.connect(_on_play_button_pressed)
	box.add_child(play_button)

	var quit_button := Button.new()
	quit_button.text = "Quit"
	quit_button.custom_minimum_size = Vector2(220, 50)
	quit_button.pressed.connect(_on_quit_button_pressed)
	box.add_child(quit_button)

	play_button.grab_focus()


func _play_music() -> void:
	if not ResourceLoader.exists(MUSIC):
		return
	var stream: AudioStream = load(MUSIC)
	if stream == null:
		return
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	elif "loop" in stream:
		stream.loop = true  # mp3 / ogg
	var music := AudioStreamPlayer.new()
	music.stream = stream
	add_child(music)
	music.play()


func _on_play_button_pressed() -> void:
	if not ResourceLoader.exists(GAME_SCENE):
		push_error("Scene not found: " + GAME_SCENE)
		return
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_quit_button_pressed() -> void:
	get_tree().quit()
