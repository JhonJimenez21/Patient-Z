extends Node3D
## Military evacuation helicopter on the rooftop (scenes/vehicles/helicopter.tscn).
## Model: assets/vehicles/huey_helicopter.fbx (Bell UH-1 "Huey"). Its AnimationPlayer has the
## "Rotation" animation (main and tail rotor); this script loops it fast like an idling engine.
## Other nodes: Lights (position lights, strobe, beacon, Searchlight, CabinLight), Hull (collision)
## and Engine (3D sound, loops).

@export var rotor_speed := 2.5        ## speed of the "Rotation" animation
@export var strobe_period := 1.2
@export var beacon_period := 0.9

var _time := 0.0

@onready var _strobe: MeshInstance3D = %Strobe
@onready var _strobe_light: OmniLight3D = %StrobeLight
@onready var _beacon: MeshInstance3D = %Beacon
@onready var _beacon_light: OmniLight3D = %BeaconLight


func _ready() -> void:
	for anim_player: AnimationPlayer in %Model.find_children("*", "AnimationPlayer", true, false):
		if anim_player.has_animation("Rotation"):
			anim_player.get_animation("Rotation").loop_mode = Animation.LOOP_LINEAR
			anim_player.play("Rotation", -1, rotor_speed)


func _process(delta: float) -> void:
	_time += delta
	var strobe_on := fmod(_time, strobe_period) < 0.07
	_strobe.visible = strobe_on
	_strobe_light.light_energy = 3.0 if strobe_on else 0.0
	var beacon := maxf(0.0, sin(_time * TAU / beacon_period))
	_beacon.visible = beacon > 0.2
	_beacon_light.light_energy = beacon * 1.5
