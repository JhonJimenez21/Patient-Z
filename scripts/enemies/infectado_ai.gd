extends CharacterBody3D
## Infected scientist. Hears noise, sees the player, follows grid paths through open doors.

const Builder = preload("res://scripts/systems/level_builder.gd")
const Config = preload("res://scripts/systems/level_config.gd")

enum State { IDLE, INVESTIGATE, CHASE, DEAD }

static var _groan_stream: AudioStreamWAV

var level: Node = null          # floor script, provides find_path()
var is_patient_z := false
var health := Config.ZOMBIE_HEALTH
var state := State.IDLE

var walk_speed := 1.1
var chase_speed := 3.0
var sight_range := 14.0
var attack_range := 1.5
var attack_damage := 12.0
var attack_infection := 9.0
var attack_cooldown := 1.3

var _player: Node3D = null
var _home := Vector3.ZERO
var _target := Vector3.ZERO
var _path: PackedVector3Array = PackedVector3Array()
var _path_index := 0
var _repath_timer := 0.0
var _attack_timer := 0.0
var _lose_timer := 0.0
var _wander_timer := 0.0
var _wander_target := Vector3.ZERO
var _anim_time := 0.0
var _groan_timer := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

var _visual: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _shape: CollisionShape3D
var _skin_mat: StandardMaterial3D
var _groan: AudioStreamPlayer3D


func setup(level_node: Node, patient_z: bool) -> void:
	level = level_node
	is_patient_z = patient_z
	if is_patient_z:
		health = Config.PATIENT_Z_HEALTH
		chase_speed = 3.6
		attack_damage = 20.0
		attack_infection = 15.0
		sight_range = 18.0


func _ready() -> void:
	add_to_group("infected")
	collision_layer = 4
	collision_mask = 1 | 2
	_build()
	_home = global_position
	_wander_target = _home
	_anim_time = randf() * 10.0
	_wander_timer = randf_range(1.0, 4.0)
	NoiseManager.noise_emitted.connect(_on_noise)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")

	_attack_timer -= delta
	var player_alive: bool = _player != null and not _player.dead

	if player_alive and _can_see_player():
		state = State.CHASE
		_target = _player.global_position
		_lose_timer = 5.0
	elif state == State.CHASE:
		_lose_timer -= delta
		if not player_alive or _lose_timer <= 0.0:
			state = State.INVESTIGATE

	var move := Vector3.ZERO
	match state:
		State.IDLE:
			move = _wander(delta)
		State.INVESTIGATE:
			move = _follow_path(_target, walk_speed * 1.8, delta)
			if _flat_distance(_target) < 1.2:
				state = State.IDLE
				_home = global_position
				_wander_target = _home
		State.CHASE:
			move = _chase(delta)

	velocity.x = move.x
	velocity.z = move.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta
	move_and_slide()

	var flat_vel := Vector2(velocity.x, velocity.z)
	if flat_vel.length() > 0.2:
		rotation.y = lerp_angle(rotation.y, atan2(-velocity.x, -velocity.z), 8.0 * delta)
	_animate(delta, flat_vel.length())
	_update_groan(delta)


func _chase(delta: float) -> Vector3:
	var dist := _flat_distance(_player.global_position)
	if dist <= attack_range:
		_face(_player.global_position, delta)
		if _attack_timer <= 0.0:
			_attack_timer = attack_cooldown
			_attack()
		return Vector3.ZERO
	if dist < 3.5 and _has_line_of_sight():
		return _direction_to(_player.global_position) * chase_speed
	return _follow_path(_target, chase_speed, delta)


func _wander(delta: float) -> Vector3:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = randf_range(3.0, 6.0)
		_wander_target = _home + Vector3(randf_range(-2.0, 2.0), 0, randf_range(-2.0, 2.0))
	if _flat_distance(_wander_target) < 0.4:
		return Vector3.ZERO
	return _direction_to(_wander_target) * walk_speed * 0.6


func _follow_path(target: Vector3, speed: float, delta: float) -> Vector3:
	_repath_timer -= delta
	if _repath_timer <= 0.0 and level:
		_repath_timer = 0.5
		_path = level.find_path(global_position, target)
		_path_index = 1 if _path.size() > 1 else 0
	while _path_index < _path.size() and _flat_distance(_path[_path_index]) < 0.6:
		_path_index += 1
	if _path_index < _path.size():
		return _direction_to(_path[_path_index]) * speed
	if _flat_distance(target) > 0.5:
		return _direction_to(target) * speed
	return Vector3.ZERO


func _attack() -> void:
	_lunge()
	if _flat_distance(_player.global_position) <= attack_range + 0.3:
		_player.take_hit(attack_damage, attack_infection)


func _can_see_player() -> bool:
	var max_range := sight_range * (0.45 if _player.crouching else 1.0)
	var to := _player.global_position - global_position
	var dist := to.length()
	if dist > max_range:
		return false
	if dist > 3.0:
		var forward := -global_basis.z
		if forward.dot(to.normalized()) < -0.1:
			return false
	return _has_line_of_sight()


func _has_line_of_sight() -> bool:
	var eye := global_position + Vector3.UP * 1.6
	var chest := _player.global_position + Vector3.UP * 1.1
	var query := PhysicsRayQueryParameters3D.create(eye, chest, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _on_noise(pos: Vector3, radius: float, source: Node) -> void:
	if state == State.DEAD or state == State.CHASE:
		return
	if global_position.distance_to(pos) <= radius:
		state = State.INVESTIGATE
		_target = pos
		_repath_timer = 0.0
		if source and source.is_in_group("player") and global_position.distance_to(pos) < radius * 0.4:
			state = State.CHASE
			_lose_timer = 4.0


func take_damage(amount: float, _hit_position: Vector3) -> void:
	if state == State.DEAD:
		return
	health -= amount
	_skin_mat.emission_enabled = true
	_skin_mat.emission = Color(0.8, 0, 0)
	_skin_mat.emission_energy_multiplier = 1.5
	get_tree().create_timer(0.08).timeout.connect(func(): _skin_mat.emission_enabled = false)
	if _player and state != State.CHASE:
		state = State.CHASE
		_target = _player.global_position
		_lose_timer = 6.0
		_repath_timer = 0.0
	if level and level.blood:
		level.blood.hit_splash(global_position)
	if health <= 0.0:
		_die()


func _die() -> void:
	state = State.DEAD
	remove_from_group("infected")
	_shape.set_deferred("disabled", true)
	velocity = Vector3.ZERO
	var tween := create_tween()
	tween.tween_property(_visual, "rotation:x", PI / 2.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_visual, "position:y", 0.25, 0.5)
	if level and level.blood:
		level.blood.pool(global_position)
	if is_patient_z:
		GameManager.notify("Patient Z eliminated!")
	GameManager.register_kill()


# --- Helpers --------------------------------------------------------------

func _flat_distance(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()


func _direction_to(point: Vector3) -> Vector3:
	var dir := point - global_position
	dir.y = 0.0
	return dir.normalized() if dir.length() > 0.01 else Vector3.ZERO


func _face(point: Vector3, delta: float) -> void:
	var dir := _direction_to(point)
	if dir != Vector3.ZERO:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 10.0 * delta)


func _animate(delta: float, speed: float) -> void:
	_anim_time += delta * (2.0 + speed * 2.0)
	var sway := sin(_anim_time) * (0.1 + speed * 0.05)
	_visual.rotation.z = sway * 0.5
	_arm_l.rotation.x = -1.4 + sin(_anim_time * 1.3) * 0.15
	_arm_r.rotation.x = -1.4 + cos(_anim_time * 1.1) * 0.15


func _lunge() -> void:
	var tween := create_tween()
	tween.tween_property(_visual, "position:z", -0.35, 0.12)
	tween.tween_property(_visual, "position:z", 0.0, 0.25)


func _update_groan(delta: float) -> void:
	_groan_timer -= delta
	if _groan_timer <= 0.0:
		_groan_timer = randf_range(4.0, 9.0) if state != State.CHASE else randf_range(2.0, 4.0)
		_groan.pitch_scale = randf_range(0.35, 0.5) * (0.8 if is_patient_z else 1.0)
		_groan.play()


func _build() -> void:
	var scale_factor := 1.3 if is_patient_z else 1.0
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35 * scale_factor
	capsule.height = 1.8 * scale_factor
	_shape = CollisionShape3D.new()
	_shape.shape = capsule
	_shape.position.y = capsule.height / 2.0
	add_child(_shape)

	_visual = Node3D.new()
	_visual.scale = Vector3.ONE * scale_factor
	add_child(_visual)

	var cloth_color := Color(0.55, 0.65, 0.75) if is_patient_z else Color(0.85, 0.86, 0.84)
	var cloth := Builder.material(cloth_color, 0.9)
	var pants := Builder.material(Color(0.2, 0.22, 0.25), 0.9)
	_skin_mat = Builder.material(Color(0.45, 0.55, 0.42) if not is_patient_z else Color(0.4, 0.42, 0.45), 0.8)
	var blood := Builder.material(Color(0.35, 0.0, 0.0), 0.6)
	var eyes := Builder.material(Color(1, 0.1, 0.05), 0.3, 0.0, Color(1, 0.1, 0.05), 4.0)

	Builder.box(_visual, Vector3(0.18, 0.85, 0.2), Vector3(-0.12, 0.42, 0), pants)
	Builder.box(_visual, Vector3(0.18, 0.85, 0.2), Vector3(0.12, 0.42, 0), pants)
	Builder.box(_visual, Vector3(0.52, 0.75, 0.3), Vector3(0, 1.18, 0), cloth)
	Builder.box(_visual, Vector3(0.25, 0.2, 0.02), Vector3(0.08, 1.05, -0.16), blood)
	Builder.box(_visual, Vector3(0.12, 0.3, 0.02), Vector3(-0.15, 1.35, -0.16), blood)
	var head := Builder.sphere(_visual, 0.16, Vector3(0, 1.72, -0.04), _skin_mat)
	head.rotation.x = 0.3
	Builder.box(_visual, Vector3(0.05, 0.03, 0.02), Vector3(-0.06, 1.75, -0.19), eyes)
	Builder.box(_visual, Vector3(0.05, 0.03, 0.02), Vector3(0.06, 1.75, -0.19), eyes)

	_arm_l = Node3D.new()
	_arm_l.position = Vector3(-0.34, 1.48, 0)
	_visual.add_child(_arm_l)
	Builder.box(_arm_l, Vector3(0.12, 0.65, 0.13), Vector3(0, -0.32, 0), cloth)
	Builder.box(_arm_l, Vector3(0.1, 0.14, 0.1), Vector3(0, -0.7, 0), _skin_mat)
	_arm_r = Node3D.new()
	_arm_r.position = Vector3(0.34, 1.48, 0)
	_visual.add_child(_arm_r)
	Builder.box(_arm_r, Vector3(0.12, 0.65, 0.13), Vector3(0, -0.32, 0), cloth)
	Builder.box(_arm_r, Vector3(0.1, 0.14, 0.1), Vector3(0, -0.7, 0), _skin_mat)

	Builder.set_visual_layer(_visual, 2)   # blood decals don't stain the infected

	if _groan_stream == null:
		_groan_stream = _make_groan()
	_groan = AudioStreamPlayer3D.new()
	_groan.stream = _groan_stream
	_groan.unit_size = 4.0
	_groan.max_distance = 25.0
	_groan.position.y = 1.6
	add_child(_groan)


static func _make_groan() -> AudioStreamWAV:
	var rate := 22050
	var count := int(0.9 * rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in count:
		var t := float(i) / rate
		var freq := 110.0 + 25.0 * sin(t * 7.0)
		phase += freq / rate
		var env := sin(PI * t / 0.9)
		var sample := (sin(TAU * phase) * 0.6 + sin(TAU * phase * 2.02) * 0.25 + randf_range(-0.15, 0.15)) * env * 0.7
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav
