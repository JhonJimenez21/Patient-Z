extends CanvasLayer
## Player HUD (scenes/ui/hud.tscn). Reads the player every frame. [H] hides it.
## The layout (labels, health bar, crosshair, death screen) is edited in the scene;
## this script only fills in the texts.

var _player: Node = null
var _toast_time := 0.0
var _alarm := false

@onready var _root: Control = %Root
@onready var _health_label: Label = %HealthLabel
@onready var _health_bar: ProgressBar = %HealthBar
@onready var _infection_label: Label = %InfectionLabel
@onready var _kills_label: Label = %KillsLabel
@onready var _stance_label: Label = %StanceLabel
@onready var _weapon_label: Label = %WeaponLabel
@onready var _objective_label: Label = %ObjectiveLabel
@onready var _prompt_label: Label = %PromptLabel
@onready var _inventory_label: RichTextLabel = %InventoryLabel
@onready var _toast_label: Label = %ToastLabel
@onready var _flash: ColorRect = %Flash
@onready var _alarm_tint: ColorRect = %AlarmTint
@onready var _death_panel: Control = %DeathPanel
@onready var _died_label: Label = %DiedLabel


func _ready() -> void:
	add_to_group("hud")
	GameManager.message.connect(show_toast)
	GameManager.alarm_started.connect(_on_alarm_started)
	SaveManager.game_loaded.connect(_on_game_loaded)


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
		_alarm_tint.color.a = 0.03 + 0.03 * sin(Time.get_ticks_msec() / 1000.0 * 4.0)
	if p.dead and not _death_panel.visible:
		_died_label.text = "YOU DIED\n[R] Load last save" if SaveManager.has_save() else "YOU DIED\n[R] Restart"
	_death_panel.visible = p.dead


func _on_alarm_started() -> void:
	_alarm = true


func _on_game_loaded(_slot_id: String) -> void:
	_alarm = GameManager.phase >= GameManager.Phase.SURVIVE


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

