extends StaticBody3D
## Soldier of the evacuation squad on the rooftop (scenes/npc/soldier.tscn). General Rex is one
## of them (node GeneralRex in azotea_final.tscn, with his officer cap).
## Nodes: Model (assets/npc/soldier.fbx, Sketchfab "Modern Soldier", rifle at the ready)
## · Muzzle (MuzzleFlash, MuzzleLight) · WeaponLight (SpotLight3D) · GunShot (3D sound)
## · AnimationPlayer: "idle" (breathing, loops) and "fire" (recoil + muzzle flash), made in the editor.
## general_rex_ambush.gd calls aim_at() and fire().

@export var turn_speed := 6.0

var target: Node3D = null
var aiming := false

@onready var _anim: AnimationPlayer = %AnimationPlayer
@onready var _weapon_light: SpotLight3D = %WeaponLight
@onready var _shot: AudioStreamPlayer3D = %GunShot


func _ready() -> void:
	_anim.play("idle")
	_anim.seek(randf() * _anim.current_animation_length)   # they don't all breathe in step


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var to := target.global_position - global_position
	if Vector2(to.x, to.z).length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), minf(1.0, turn_speed * delta))


## Turns to a player with the rifle up and the weapon light on.
func aim_at(node: Node3D) -> void:
	target = node
	aiming = true
	_weapon_light.visible = true


## One shot: the "fire" animation (recoil and muzzle flash) and the gunshot.
func fire() -> void:
	_anim.stop()
	_anim.play("fire")
	_anim.queue("idle")
	_shot.pitch_scale = randf_range(0.9, 1.05)
	_shot.play()
