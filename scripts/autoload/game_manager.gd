extends Node
## Global game state for Patient Z. Register as autoload "GameManager".

signal phase_changed(phase: int)
signal syringes_changed(count: int)
signal kills_changed(kills: int, target: int)
signal alarm_started
signal keycard_obtained
signal rifle_obtained
signal message(text: String)
signal miniboss_killed

const MAIN_SCENE := "res://main.tscn"

enum Phase { INTRO, COLLECT, SURVIVE, CLEARED }

const SYRINGES_NEEDED := 5

var phase: int = Phase.INTRO
var syringes := 0
var has_keycard := false
var kills := 0
var kill_target := 0
var has_rifle := false
var floor_number := 1          # 1 = Underground Lab · 2 = Containment Spiral
var miniboss_dead := false     # Floor 2

## Floor change: the next floor that main.tscn must open, and the player's state to bring along
## (health, infection, weapons, ammo, bandages, flashlight).
var next_floor_scene := ""
var carry_player := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input_actions()


## [F11] switches between full screen and a window (full screen is set in Project Settings:
## Display > Window > Size > Mode = Fullscreen).
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("px_fullscreen"):
		var full := DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)


## Called by each floor when it loads.
func reset_floor(target_kills: int, number := 1) -> void:
	floor_number = number
	miniboss_dead = false
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
	if floor_number == 1 and phase == Phase.SURVIVE and kills >= kill_target:
		set_phase(Phase.CLEARED)
		notify("Floor cleared! The stairs to Floor 2 are unlocked.")
	elif floor_number == 2 and kills == kill_target:
		notify("All infected rooms cleared! The containment door is open.")


## Floor 2: the mini-boss is dead, the room with the stairs to Floor 3 opens.
func register_miniboss_kill() -> void:
	miniboss_dead = true
	miniboss_killed.emit()
	set_phase(Phase.CLEARED)
	notify("The Brute is dead! The stairs to Floor 3 are open.")


## Goes to another floor keeping the player's state (called by the stairs).
func go_to_floor(scene_path: String, player: Node) -> void:
	if player:
		carry_player = player.get_save_data()
	next_floor_scene = scene_path
	get_tree().change_scene_to_file(MAIN_SCENE)


func set_has_rifle() -> void:
	if has_rifle:
		return
	has_rifle = true
	rifle_obtained.emit()


## --- Save / load (used by SaveManager → progress.json) ---

func get_save_data() -> Dictionary:
	return {
		"phase": phase,
		"syringes": syringes,
		"has_keycard": has_keycard,
		"kills": kills,
		"kill_target": kill_target,
		"has_rifle": has_rifle,
		"floor_number": floor_number,
		"miniboss_dead": miniboss_dead,
	}


func load_save_data(data: Dictionary) -> void:
	phase = int(data.get("phase", Phase.INTRO))
	syringes = int(data.get("syringes", 0))
	has_keycard = bool(data.get("has_keycard", false))
	kills = int(data.get("kills", 0))
	kill_target = int(data.get("kill_target", kill_target))
	has_rifle = bool(data.get("has_rifle", false))
	floor_number = int(data.get("floor_number", floor_number))
	miniboss_dead = bool(data.get("miniboss_dead", false))
	phase_changed.emit(phase)
	syringes_changed.emit(syringes)
	kills_changed.emit(kills, kill_target)


func can_use_stairs() -> bool:
	if floor_number == 2:
		return miniboss_dead
	return phase == Phase.CLEARED


func objective_text() -> String:
	if floor_number == 2:
		if miniboss_dead:
			return "FLOOR 2: Take the stairs to Floor 3"
		if kills >= kill_target:
			return "FLOOR 2: Kill the Brute in the containment room"
		return "FLOOR 2: Clear the infected rooms and reach Patient Z's zone (%d / %d Infected)" % [kills, kill_target]
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
	_add_keys("px_holster", [KEY_Q])
	_add_keys("px_toggle_hud", [KEY_H])
	_add_keys("px_flashlight", [KEY_L])
	_add_keys("px_pause", [KEY_ESCAPE])
	_add_keys("px_fullscreen", [KEY_F11])
	if not InputMap.has_action("px_shoot"):
		InputMap.add_action("px_shoot")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("px_shoot", click)
	if not InputMap.has_action("px_aim"):
		InputMap.add_action("px_aim")
		var right_click := InputEventMouseButton.new()
		right_click.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("px_aim", right_click)


func _add_keys(action: StringName, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)
