extends CanvasLayer
## Player HUD overlay. Reads the player every frame. [H] hides it.

const CONTROLS := "W A S D move · Shift run · C crouch · E talk · F interact · Click shoot · R reload · 1-2 weapons · 3 bandage · L flashlight · H hide UI"

var _player: Node = null
var _root: Control
var _health_label: Label
var _health_bar: ProgressBar
var _infection_label: Label
var _kills_label: Label
var _stance_label: Label
var _weapon_label: Label
var _objective_label: Label
var _prompt_label: Label
var _inventory_label: RichTextLabel
var _toast_label: Label
var _flash: ColorRect
var _alarm_tint: ColorRect
var _death_panel: Control
var _toast_time := 0.0
var _alarm := false


func _ready() -> void:
	layer = 10
	add_to_group("hud")
	_build()
	GameManager.message.connect(show_toast)
	GameManager.alarm_started.connect(func(): _alarm = true)


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return

	if Input.is_action_just_pressed("px_toggle_hud"):
		_root.visible = not _root.visible

	var p = _player
	_health_label.text = "HEALTH %d/%d" % [ceili(p.health), int(p.max_health)]
	_health_bar.max_value = p.max_health
	_health_bar.value = p.health

	var infection_text := "INFECTION %d%%" % int(p.infection)
	if p.infection > 0.0:
		infection_text += " · use BANDAGES (%d)" % p.bandages
	_infection_label.text = infection_text
	_infection_label.modulate = Color(0.6, 1.0, 0.4) if p.infection > 0.0 else Color(1, 1, 1, 0.7)

	_kills_label.text = "INFECTED %d / %d" % [GameManager.kills, GameManager.kill_target]
	_stance_label.text = "%s · noise %d m" % [p.stance_text(), roundi(p.noise_radius)]
	_weapon_label.text = p.weapon_text()
	_objective_label.text = "OBJECTIVE: " + GameManager.objective_text()
	_prompt_label.text = p.current_prompt
	_inventory_label.text = _inventory_text(p)

	_toast_time -= delta
	_toast_label.modulate.a = clamp(_toast_time, 0.0, 1.0)

	_flash.color.a = move_toward(_flash.color.a, 0.0, delta * 1.5)
	if _alarm:
		_alarm_tint.color.a = 0.06 + 0.05 * sin(Time.get_ticks_msec() / 1000.0 * 4.0)
	_death_panel.visible = p.dead


func show_toast(text: String) -> void:
	_toast_label.text = text
	_toast_time = 3.5


func flash_damage() -> void:
	_flash.color.a = 0.45


func _inventory_text(p) -> String:
	var parts: Array[String] = []
	parts.append(_slot("1 M-9 Rifle", p.has_weapon("rifle"), p.current_weapon == "rifle"))
	parts.append(_slot("2 Shotgun", p.has_weapon("shotgun"), p.current_weapon == "shotgun"))
	parts.append(_slot("3 Bandages x%d" % p.bandages, p.bandages > 0, false))
	if GameManager.phase == GameManager.Phase.COLLECT or GameManager.syringes > 0:
		parts.append(_slot("Syringes %d/%d" % [GameManager.syringes, GameManager.SYRINGES_NEEDED], GameManager.syringes > 0, false))
	if GameManager.has_keycard:
		parts.append(_slot("Keycard", true, false))
	return "[center]" + " ".join(parts) + "[/center]"


func _slot(text: String, owned: bool, selected: bool) -> String:
	var color := "#ffd75e" if selected else ("#ffffff" if owned else "#666666")
	return "[color=%s][%s][/color]" % [color, text]


func _label(parent: Node, size := 18, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(label)
	return label


func _build() -> void:
	# Effects layer (always visible, even with the HUD hidden)
	_alarm_tint = ColorRect.new()
	_alarm_tint.color = Color(1, 0, 0, 0)
	_alarm_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_alarm_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_alarm_tint)

	_flash = ColorRect.new()
	_flash.color = Color(0.8, 0, 0, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Top left: status
	var status := VBoxContainer.new()
	status.position = Vector2(20, 16)
	status.add_theme_constant_override("separation", 2)
	_root.add_child(status)
	_health_label = _label(status, 20)
	_health_bar = ProgressBar.new()
	_health_bar.custom_minimum_size = Vector2(260, 14)
	_health_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.1, 0.7)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.12, 0.1)
	_health_bar.add_theme_stylebox_override("background", bg)
	_health_bar.add_theme_stylebox_override("fill", fill)
	status.add_child(_health_bar)
	_infection_label = _label(status, 17)
	_kills_label = _label(status, 17, Color(1.0, 0.55, 0.45))
	_stance_label = _label(status, 17, Color(0.8, 0.85, 0.9))
	_weapon_label = _label(status, 19, Color(1.0, 0.85, 0.4))

	# Top right: objective
	_objective_label = _label(_root, 17, Color(0.6, 0.9, 1.0))
	_objective_label.anchor_left = 1.0
	_objective_label.anchor_right = 1.0
	_objective_label.offset_left = -560
	_objective_label.offset_right = -20
	_objective_label.offset_top = 16
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Center: crosshair
	var crosshair := ColorRect.new()
	crosshair.color = Color(1, 1, 1, 0.9)
	crosshair.size = Vector2(4, 4)
	crosshair.anchor_left = 0.5
	crosshair.anchor_top = 0.5
	crosshair.anchor_right = 0.5
	crosshair.anchor_bottom = 0.5
	crosshair.offset_left = -2
	crosshair.offset_top = -2
	crosshair.offset_right = 2
	crosshair.offset_bottom = 2
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(crosshair)

	# Toast messages (upper center)
	_toast_label = _label(_root, 22, Color(1, 1, 0.85))
	_toast_label.anchor_left = 0.0
	_toast_label.anchor_right = 1.0
	_toast_label.offset_top = 90
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Interaction prompt (below crosshair)
	_prompt_label = _label(_root, 22)
	_prompt_label.anchor_left = 0.0
	_prompt_label.anchor_right = 1.0
	_prompt_label.anchor_top = 0.5
	_prompt_label.anchor_bottom = 0.5
	_prompt_label.offset_top = 60
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Bottom: quick inventory + controls
	_inventory_label = RichTextLabel.new()
	_inventory_label.bbcode_enabled = true
	_inventory_label.fit_content = true
	_inventory_label.scroll_active = false
	_inventory_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inventory_label.add_theme_font_size_override("normal_font_size", 18)
	_inventory_label.anchor_left = 0.0
	_inventory_label.anchor_right = 1.0
	_inventory_label.anchor_top = 1.0
	_inventory_label.anchor_bottom = 1.0
	_inventory_label.offset_top = -70
	_inventory_label.offset_bottom = -40
	_root.add_child(_inventory_label)

	var controls := _label(_root, 14, Color(1, 1, 1, 0.55))
	controls.text = CONTROLS
	controls.anchor_left = 0.0
	controls.anchor_right = 1.0
	controls.anchor_top = 1.0
	controls.anchor_bottom = 1.0
	controls.offset_top = -32
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Death screen
	_death_panel = ColorRect.new()
	_death_panel.color = Color(0.25, 0, 0, 0.75)
	_death_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_panel.visible = false
	add_child(_death_panel)
	var died := _label(_death_panel, 56, Color(1, 0.2, 0.2))
	died.text = "YOU DIED\n[R] Restart"
	died.set_anchors_preset(Control.PRESET_FULL_RECT)
	died.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	died.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
