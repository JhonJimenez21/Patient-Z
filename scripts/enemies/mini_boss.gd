extends "res://scripts/enemies/infectado_ai.gd"
## Floor 2 mini-boss "The Brute" (scenes/enemies/mini_boss.tscn), in the penultimate room.
## Uses the infected AI (paths, sight, hearing, room activation) with its own rules:
##   · very tough: rifle bullets only do RIFLE_FACTOR of their damage
##   · weak to the shotgun at close range (SHOTGUN_FACTOR within SHOTGUN_RANGE metres)
##   · every hit takes HIT_DAMAGE of the player's 100 HP
##   · its death is not one of the 35 infected: it opens the room with the stairs to Floor 3

const MAX_HEALTH := 1600.0
const HIT_DAMAGE := 40.0
const RIFLE_FACTOR := 0.6
const SHOTGUN_FACTOR := 2.5
const SHOTGUN_RANGE := 6.0
const TINT := Color(1.0, 0.55, 0.5)       # reddish skin


func _ready() -> void:
	super._ready()
	health = MAX_HEALTH
	chase_speed = 3.4
	walk_speed = 1.3
	attack_damage = HIT_DAMAGE
	attack_infection = 10.0
	attack_range = 2.2
	attack_cooldown = 1.6
	sight_range = 22.0
	%PatientZGlow.visible = true             # red glow of the boss
	_tint_model()


func take_damage(amount: float, hit_position: Vector3) -> void:
	if state == State.DEAD:
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	var factor := RIFLE_FACTOR
	if _player and _player.weapons.current_weapon == "shotgun":
		factor = SHOTGUN_FACTOR if _flat_distance(_player.global_position) <= SHOTGUN_RANGE else 1.0
	super.take_damage(amount * factor, hit_position)


func _on_killed() -> void:
	GameManager.register_miniboss_kill()


## Darker, reddish copy of the model's materials (the hit flash uses the overlay, not these).
func _tint_model() -> void:
	for mesh: MeshInstance3D in _meshes:
		for i in mesh.mesh.get_surface_count():
			var mat := mesh.get_active_material(i)
			if mat is StandardMaterial3D:
				var copy: StandardMaterial3D = mat.duplicate()
				copy.albedo_color = copy.albedo_color * TINT
				mesh.set_surface_override_material(i, copy)


## Health shown on the HUD (0-1).
func health_ratio() -> float:
	return clampf(health / MAX_HEALTH, 0.0, 1.0)
