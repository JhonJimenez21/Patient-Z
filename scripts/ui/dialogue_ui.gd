extends CanvasLayer
## Dialogue box at the bottom of the screen with a typewriter effect.

const CHARS_PER_SECOND := 45.0

var active := false

var _panel: PanelContainer
var _name_label: Label
var _text_label: Label
var _hint_label: Label
var _lines: Array = []
var _index := 0
var _on_finish := Callable()
var _opened_at := 0
var _closed_at := -10000


func _ready() -> void:
	layer = 20
	add_to_group("dialogue_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_panel.visible = false


func show_dialogue(speaker: String, lines: Array, on_finish := Callable()) -> void:
	_lines = lines
	_index = 0
	_on_finish = on_finish
	_name_label.text = speaker
	active = true
	_opened_at = Time.get_ticks_msec()
	_panel.visible = true
	_show_line()


## True while the box is open or was closed a moment ago,
## so the key that closes it doesn't also start a new interaction.
func is_busy() -> bool:
	return active or Time.get_ticks_msec() - _closed_at < 300


func _process(delta: float) -> void:
	if active and _text_label.visible_ratio < 1.0:
		var total: int = max(_text_label.text.length(), 1)
		_text_label.visible_ratio = min(1.0, _text_label.visible_ratio + CHARS_PER_SECOND * delta / total)


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	# Ignore the same key press that opened the dialogue.
	if Time.get_ticks_msec() - _opened_at < 200:
		return
	var advance := event.is_action_pressed("px_talk") or event.is_action_pressed("px_interact")
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance = true
	if advance:
		get_viewport().set_input_as_handled()
		_advance()


func _advance() -> void:
	if _text_label.visible_ratio < 1.0:
		_text_label.visible_ratio = 1.0
		return
	_index += 1
	if _index < _lines.size():
		_show_line()
		return
	active = false
	_closed_at = Time.get_ticks_msec()
	_panel.visible = false
	if _on_finish.is_valid():
		_on_finish.call()


func _show_line() -> void:
	_text_label.text = _lines[_index]
	_text_label.visible_ratio = 0.0
	_hint_label.text = "[E] continue" if _index < _lines.size() - 1 else "[E] close"


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.18
	_panel.anchor_right = 0.82
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_top = -230
	_panel.offset_bottom = -110
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.07, 0.88)
	style.border_color = Color(0.4, 0.75, 0.85, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", style)
	root.add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)

	_name_label = Label.new()
	_name_label.add_theme_color_override("font_color", Color(0.45, 0.85, 0.95))
	_name_label.add_theme_font_size_override("font_size", 20)
	box.add_child(_name_label)

	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.add_theme_font_size_override("font_size", 19)
	box.add_child(_text_label)

	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	_hint_label.add_theme_font_size_override("font_size", 14)
	box.add_child(_hint_label)
