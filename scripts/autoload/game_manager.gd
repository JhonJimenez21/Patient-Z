extends Node
## Global game state for Patient Z. Register as autoload "GameManager".

signal phase_changed(phase: int)
signal syringes_changed(count: int)
signal kills_changed(kills: int, target: int)
signal alarm_started
signal keycard_obtained
signal message(text: String)

enum Phase { INTRO, COLLECT, SURVIVE, CLEARED }

const SYRINGES_NEEDED := 5

var phase: int = Phase.INTRO
var syringes := 0
var has_keycard := false
var kills := 0
var kill_target := 0
var has_rifle := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input_actions()


## Called by each floor when it loads.
func reset_floor(target_kills: int) -> void:
	phase = Phase.INTRO
	syringes = 0
	has_keycard = false
	kills = 0
	kill_target = target_kills
	has_rifle = false
	phase_changed.emit(phase)
	syringes_changed.emit(syringes)
	kills_changed.emit(kills, kill_target)


func set_phase(new_phase: int) -> void:
	phase = new_phase
	phase_changed.emit(phase)


func add_syringe() -> void:
	syringes += 1
	syringes_changed.emit(syringes)


func has_all_syringes() -> bool:
	return syringes >= SYRINGES_NEEDED


## Boss takes the syringes and the emergency starts.
func deliver_syringes() -> void:
	syringes = 0
	syringes_changed.emit(syringes)
	set_phase(Phase.SURVIVE)
	alarm_started.emit()


func give_keycard() -> void:
	has_keycard = true
	keycard_obtained.emit()
	notify("Keycard obtained")


func register_kill() -> void:
	kills += 1
	kills_changed.emit(kills, kill_target)
	if phase == Phase.SURVIVE and kills >= kill_target:
		set_phase(Phase.CLEARED)
		notify("Floor cleared! The stairs to Floor 2 are unlocked.")


func can_use_stairs() -> bool:
	return phase == Phase.CLEARED


func objective_text() -> String:
	match phase:
		Phase.INTRO:
			return "Talk to your boss"
		Phase.COLLECT:
			if has_all_syringes():
				return "Bring the syringes to your boss"
			return "Find syringes in the first 4 rooms (%d/%d)" % [syringes, SYRINGES_NEEDED]
		Phase.SURVIVE:
			if not has_rifle:
				return "Get the rifle in the Security Guard Room"
			return "SURVIVE · Eliminate the infected (%d/%d)" % [kills, kill_target]
		Phase.CLEARED:
			return "Take the stairs to Floor 2"
	return ""


func notify(text: String) -> void:
	message.emit(text)


func _setup_input_actions() -> void:
	# Actions are created by code so the project settings don't need editing.
	# The px_ prefix avoids clashing with actions that already exist.
	_add_keys("px_forward", [KEY_W, KEY_UP])
	_add_keys("px_back", [KEY_S, KEY_DOWN])
	_add_keys("px_left", [KEY_A, KEY_LEFT])
	_add_keys("px_right", [KEY_D, KEY_RIGHT])
	_add_keys("px_sprint", [KEY_SHIFT])
	_add_keys("px_crouch", [KEY_C, KEY_CTRL])
	_add_keys("px_talk", [KEY_E])
	_add_keys("px_interact", [KEY_F])
	_add_keys("px_reload", [KEY_R])
	_add_keys("px_weapon_1", [KEY_1])
	_add_keys("px_weapon_2", [KEY_2])
	_add_keys("px_bandage", [KEY_3])
	_add_keys("px_toggle_hud", [KEY_H])
	_add_keys("px_flashlight", [KEY_L])
	_add_keys("px_pause", [KEY_ESCAPE])
	if not InputMap.has_action("px_shoot"):
		InputMap.add_action("px_shoot")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("px_shoot", click)


func _add_keys(action: StringName, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)
