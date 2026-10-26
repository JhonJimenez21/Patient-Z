extends RefCounted
## Small helpers to build placeholder geometry by code.
## Usage: const Builder = preload("res://scripts/systems/level_builder.gd")


static func material(color: Color, roughness := 0.7, metallic := 0.0, emission := Color.BLACK, emission_energy := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	if emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = emission_energy
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


static func box(parent: Node, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(parent, mesh, pos, mat)


static func cylinder(parent: Node, radius: float, height: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	return _add(parent, mesh, pos, mat)


static func sphere(parent: Node, radius: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return _add(parent, mesh, pos, mat)


static func capsule(parent: Node, radius: float, height: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	return _add(parent, mesh, pos, mat)


static func box_collision(body: CollisionObject3D, size: Vector3, pos: Vector3) -> CollisionShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = pos
	body.add_child(col)
	return col


static func _add(parent: Node, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


## Short noise sound made by code (gunshots, hits). No audio file needed.
static func noise_burst(seconds: float, decay: float, volume: float) -> AudioStreamWAV:
	var rate := 22050
	var count := int(seconds * rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	var low := 0.0
	for i in count:
		var t := float(i) / rate
		low = lerp(low, randf_range(-1.0, 1.0), 0.35)
		var sample := clampf(low * volume * exp(-t * decay) * 1.6, -1.0, 1.0)
		data.encode_s16(i * 2, int(sample * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav


## Puts every mesh under node on a visual layer (2 = characters, so blood decals skip them).
static func set_visual_layer(node: Node, layer_bit: int) -> void:
	if node is VisualInstance3D:
		node.layers = layer_bit
	for child in node.get_children():
		set_visual_layer(child, layer_bit)
