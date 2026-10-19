extends Node3D
## Physical sign fixed on a wall or door: a backing plate plus a Label3D.
## The label is NOT a billboard and keeps the depth test on, so walls and
## models hide it correctly (it never shows through them).
## The front of the sign faces local +Z.
##
## Used for "STAIRS" above the Floor 2 gate and for the Security Guard Room door.

const Builder = preload("res://scripts/systems/level_builder.gd")

var text := "STAIRS"
var width := 1.6
var height := 0.45
var text_color := Color(1.0, 0.92, 0.6)
var plate_color := Color(0.08, 0.1, 0.12)
var glow := true


func setup(sign_text: String, sign_width := 1.6, sign_height := 0.45, color := Color(1.0, 0.92, 0.6)) -> void:
	text = sign_text
	width = sign_width
	height = sign_height
	text_color = color


func _ready() -> void:
	# Backing plate (a real mesh on the wall)
	var plate := Builder.material(plate_color, 0.6, 0.3)
	Builder.box(self, Vector3(width, height, 0.05), Vector3.ZERO, plate)
	var frame := Builder.material(text_color.darkened(0.4), 0.5, 0.5)
	Builder.box(self, Vector3(width + 0.06, 0.03, 0.06), Vector3(0, height / 2.0, 0), frame)
	Builder.box(self, Vector3(width + 0.06, 0.03, 0.06), Vector3(0, -height / 2.0, 0), frame)

	var label := Label3D.new()
	label.text = text
	label.font_size = 96
	label.outline_size = 12
	label.modulate = text_color
	label.outline_modulate = Color(0, 0, 0, 1)
	# Fit the text inside the plate (supports several lines with "\n")
	var lines := text.split("\n")
	var longest := 1
	for line in lines:
		longest = max(longest, line.length())
	label.pixel_size = min(height * 0.62 / (96.0 * lines.size()), width * 0.85 / (96.0 * 0.62 * longest))
	label.position = Vector3(0, 0, 0.03)          # just in front of the plate
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.no_depth_test = false                    # walls hide the text
	label.double_sided = false                     # not readable from behind the wall
	label.fixed_size = false
	label.shaded = false
	if glow:
		label.modulate = text_color * 1.4
	add_child(label)
