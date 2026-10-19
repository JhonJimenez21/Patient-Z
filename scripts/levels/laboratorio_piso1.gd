extends Node3D
## Patient Z · Piso 1 (Laboratorio Clandestino).
## Builds the whole floor from MAPA: walls, doors, lamps, NPCs, items and the infected.

const Config = preload("res://scripts/systems/level_config.gd")
const Builder = preload("res://scripts/systems/level_builder.gd")
const AlarmSystem = preload("res://scripts/systems/alarm_system.gd")
const DoorScript = preload("res://scripts/items/door.gd")
const CabinetScript = preload("res://scripts/items/cabinet.gd")
const StairsScript = preload("res://scripts/items/stairs.gd")
const StairsSign = preload("res://scripts/environment/stairs_sign.gd")
const BloodSpawner = preload("res://scripts/environment/blood_spawner.gd")
const HudScript = preload("res://scripts/ui/hud.gd")
const DialogueScript = preload("res://scripts/ui/dialogue_ui.gd")

const PlayerScene = preload("res://scenes/player/player.tscn")
const InfectadoScene = preload("res://scenes/enemies/infectado.tscn")
const JefeScene = preload("res://scenes/npc/jefe.tscn")
const PickupScene = preload("res://scenes/items/pickup.tscn")

const GUARD_ROOM_NAME := "SECURITY\nGUARD ROOM"

## Legend:
## # wall · . floor · D door · L lamp · P player · B boss · Z infected
## A M-9 rifle (its room is the Security Guard Room) · E shotgun · T containment breach
## X stairs to Floor 2 (locked)
const MAPA := [
	"###############################",
	"#......#......###......#......#",
	"#..L...#..L...###..L...#...L..#",
	"#......#......###......#......#",
	"#......#......###......#......#",
	"###D#######D#######D#######D###",
	"#.....L.......L.......L.......#",
	"#P............B...............#",
	"#.............................#",
	"####D##########X###############",
	"#......#..Z....L.....Z.#......#",
	"#..A.L.D....E.....Z....D..L.Z.#",
	"#......#....Z..........#......#",
	"####D###########D#######...T..#",
	"#..Z......Z...#........D.Z....#",
	"#.....L.......D...Z.L..#..Z...#",
	"#...Z...L..Z..#.Z......#......#",
	"#.........Z...#......Z.#...L..#",
	"###############################",
]

const NO_CELL := Vector2i(-1, -1)
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var astar := AStarGrid2D.new()
var player: CharacterBody3D
var blood: Node3D               # blood_spawner.gd, also used by the infected

var _env: Environment
var _lamp_mat: StandardMaterial3D
var _alarm: Node
var _zombie_spawns: Array[Vector2i] = []
var _breach_cell := NO_CELL
var _region_of := {}            # Vector2i -> region id
var _regions: Array = []        # region id -> Array of Vector2i
var _hall_region := -1
var _guard_region := -1
var _start_rooms: Array[int] = []
var _used_cells := {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 1337
	_validate_map()
	GameManager.reset_floor(Config.objetivo_bajas)
	GameManager.alarm_started.connect(_on_alarm_started)

	_build_environment()
	_alarm = AlarmSystem.new()
	_alarm.name = "AlarmSystem"
	_alarm.setup(_env, _lamp_mat)
	add_child(_alarm)
	_build_shell()
	_analyze_regions()
	_build_astar()
	_spawn_from_map()
	_decorate()
	_mark_guard_room()
	blood = BloodSpawner.new()
	blood.name = "Blood"
	add_child(blood)
	_spawn_room_blood()
	add_child(HudScript.new())
	add_child(DialogueScript.new())


# --- Map helpers ----------------------------------------------------------

func ch(cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= MAPA.size():
		return "#"
	var row: String = MAPA[cell.y]
	if cell.x < 0 or cell.x >= row.length():
		return "#"
	return row[cell.x]


func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * Config.CELL_SIZE, 0.0, cell.y * Config.CELL_SIZE)


func world_to_cell(pos: Vector3) -> Vector2i:
	return Vector2i(roundi(pos.x / Config.CELL_SIZE), roundi(pos.z / Config.CELL_SIZE))


func _all_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in MAPA.size():
		for x in (MAPA[y] as String).length():
			cells.append(Vector2i(x, y))
	return cells


func _find_char(c: String) -> Vector2i:
	for cell in _all_cells():
		if ch(cell) == c:
			return cell
	return NO_CELL


func _validate_map() -> bool:
	var ok := true
	if MAPA.size() != Config.ROWS:
		push_error("MAPA has %d rows, expected %d" % [MAPA.size(), Config.ROWS])
		ok = false
	var zombies := 0
	for y in MAPA.size():
		var row: String = MAPA[y]
		if row.length() != Config.COLS:
			push_error("MAPA row %d has %d characters, expected %d" % [y, row.length(), Config.COLS])
			ok = false
		zombies += row.count("Z")
	if zombies != Config.objetivo_bajas:
		push_error("MAPA has %d 'Z' but objetivo_bajas = %d (level_config.gd)" % [zombies, Config.objetivo_bajas])
		ok = false

	# Every non-wall cell must be reachable (doors and stairs count as passable).
	var open_cells: Array[Vector2i] = []
	for cell in _all_cells():
		if ch(cell) != "#":
			open_cells.append(cell)
	if not open_cells.is_empty():
		var seen := {open_cells[0]: true}
		var stack: Array[Vector2i] = [open_cells[0]]
		while not stack.is_empty():
			var cur: Vector2i = stack.pop_back()
			for d in DIRS:
				var n: Vector2i = cur + d
				if ch(n) != "#" and not seen.has(n):
					seen[n] = true
					stack.append(n)
		var unreachable := open_cells.filter(func(c): return not seen.has(c))
		if not unreachable.is_empty():
			push_error("MAPA has unreachable cells (x, y): %s" % [unreachable])
			ok = false

	if ok:
		print("[Piso 1] MAPA OK: %dx%d, %d infected" % [Config.COLS, MAPA.size(), zombies])
	return ok


# --- Regions, doors and pathfinding -----------------------------------------

## Splits the floor into rooms separated by doors/stairs. Doors that join the
## start hall with a room without infected, weapons or the breach are the
## "first 4 rooms" (open after talking to the boss); the rest need the keycard.
func _analyze_regions() -> void:
	for cell in _all_cells():
		if ch(cell) in "#DX" or _region_of.has(cell):
			continue
		var id := _regions.size()
		var cells: Array[Vector2i] = [cell]
		_region_of[cell] = id
		var stack: Array[Vector2i] = [cell]
		while not stack.is_empty():
			var cur: Vector2i = stack.pop_back()
			for d in DIRS:
				var n: Vector2i = cur + d
				if not (ch(n) in "#DX") and not _region_of.has(n):
					_region_of[n] = id
					cells.append(n)
					stack.append(n)
		_regions.append(cells)

	_hall_region = _region_of.get(_find_char("P"), -1)
	_guard_region = _region_of.get(_find_char("A"), -1)
	for cell in _all_cells():
		if ch(cell) == "D" and _door_kind(cell) == "start":
			for r in _door_regions(cell):
				if r != _hall_region and not _start_rooms.has(r):
					_start_rooms.append(r)
	if _start_rooms.size() != 4:
		push_warning("Expected 4 start rooms next to the hall, found %d" % _start_rooms.size())


func _door_regions(cell: Vector2i) -> Array[int]:
	var ids: Array[int] = []
	for d in DIRS:
		var r: int = _region_of.get(cell + d, -1)
		if r >= 0 and not ids.has(r):
			ids.append(r)
	return ids


func _door_kind(cell: Vector2i) -> String:
	var ids := _door_regions(cell)
	if ids.size() == 2 and ids.has(_hall_region):
		var other: int = ids[0] if ids[1] == _hall_region else ids[1]
		if _region_is_clean(other):
			return "start"
	return "keycard"


func _region_is_clean(id: int) -> bool:
	for cell in _regions[id]:
		if ch(cell) in "ZAET":
			return false
	return true


func _build_astar() -> void:
	astar.region = Rect2i(0, 0, Config.COLS, MAPA.size())
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for cell in _all_cells():
		if ch(cell) in "#DXT":
			astar.set_point_solid(cell, true)


## Used by the infected. Returns world points from one position to another.
func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var result := PackedVector3Array()
	var a := _nearest_open(world_to_cell(from))
	var b := _nearest_open(world_to_cell(to))
	if a == NO_CELL or b == NO_CELL:
		return result
	for id in astar.get_id_path(a, b, true):
		result.append(cell_to_world(id))
	return result


func _nearest_open(cell: Vector2i) -> Vector2i:
	if astar.is_in_boundsv(cell) and not astar.is_point_solid(cell):
		return cell
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var n: Vector2i = cell + d
		if astar.is_in_boundsv(n) and not astar.is_point_solid(n):
			return n
	return NO_CELL


func _on_door_opened(cell: Vector2i) -> void:
	astar.set_point_solid(cell, false)


# --- World building -------------------------------------------------------

func _build_environment() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.02, 0.02, 0.03)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Config.AMBIENT_NORMAL
	_env.ambient_light_energy = 0.45
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.glow_enabled = true
	_env.glow_intensity = 0.6
	_env.ssao_enabled = true
	var world_env := WorldEnvironment.new()
	world_env.environment = _env
	add_child(world_env)

	_lamp_mat = Builder.material(Config.LIGHT_NORMAL, 0.3, 0.0, Config.LIGHT_NORMAL, 3.0)


func _build_shell() -> void:
	var cs := Config.CELL_SIZE
	var h := Config.WALL_HEIGHT
	var size := Vector3(Config.COLS * cs, 0, MAPA.size() * cs)
	var center := Vector3((Config.COLS - 1) * cs / 2.0, 0, (MAPA.size() - 1) * cs / 2.0)

	var world := StaticBody3D.new()
	world.name = "World"
	add_child(world)

	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(size.x, size.z)
	var floor_mi := MeshInstance3D.new()
	floor_mi.mesh = floor_mesh
	floor_mi.material_override = _tile_material(Color(0.86, 0.88, 0.88), Color(0.5, 0.53, 0.55), 0.6)
	floor_mi.position = center
	world.add_child(floor_mi)
	Builder.box_collision(world, Vector3(size.x, 1.0, size.z), center + Vector3(0, -0.5, 0))

	var ceil_mesh := PlaneMesh.new()
	ceil_mesh.size = Vector2(size.x, size.z)
	ceil_mesh.flip_faces = true
	var ceil_mi := MeshInstance3D.new()
	ceil_mi.mesh = ceil_mesh
	ceil_mi.material_override = _tile_material(Color(0.62, 0.64, 0.66), Color(0.45, 0.46, 0.48), 1.2)
	ceil_mi.position = center + Vector3(0, h, 0)
	world.add_child(ceil_mi)

	# Walls: merge horizontal runs of "#" into one box each.
	var wall_mat := _tile_material(Color(0.8, 0.88, 0.86), Color(0.52, 0.6, 0.59), 0.4)
	for y in MAPA.size():
		var x := 0
		while x < Config.COLS:
			if ch(Vector2i(x, y)) != "#":
				x += 1
				continue
			var start := x
			while x < Config.COLS and ch(Vector2i(x, y)) == "#":
				x += 1
			var run := x - start
			var pos := Vector3((start + (run - 1) / 2.0) * cs, h / 2.0, y * cs)
			Builder.box(world, Vector3(run * cs, h, cs), pos, wall_mat)
			Builder.box_collision(world, Vector3(run * cs, h, cs), pos)


func _tile_material(base: Color, grout: Color, tile_size: float) -> StandardMaterial3D:
	var px := 64
	var img := Image.create_empty(px, px, true, Image.FORMAT_RGB8)
	img.fill(base)
	for i in px:
		for j in 2:
			img.set_pixel(i, j, grout)
			img.set_pixel(j, i, grout)
	img.generate_mipmaps()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE / tile_size
	mat.roughness = 0.35
	return mat


func _spawn_from_map() -> void:
	var boss_cell := _find_char("B")
	for cell in _all_cells():
		var pos := cell_to_world(cell)
		match ch(cell):
			"D":
				_spawn_door(cell)
			"L":
				_spawn_lamp(pos)
			"P":
				player = PlayerScene.instantiate()
				player.name = "Player"
				player.position = pos
				if boss_cell != NO_CELL:
					var to := cell_to_world(boss_cell) - pos
					player.rotation.y = atan2(-to.x, -to.z)
				add_child(player)
			"B":
				var boss: Node3D = JefeScene.instantiate()
				boss.name = "Boss"
				boss.position = pos
				Builder.set_visual_layer(boss, 2)
				var start := _find_char("P")
				if start != NO_CELL:
					var to := cell_to_world(start) - pos
					boss.rotation.y = atan2(to.x, to.z)
				add_child(boss)
			"Z":
				_zombie_spawns.append(cell)
			"A":
				_spawn_weapon(cell, "rifle")
			"E":
				_spawn_weapon(cell, "shotgun")
			"T":
				_breach_cell = cell
				_spawn_breach(pos)
			"X":
				var stairs := StairsScript.new()
				stairs.setup(_wall_along_x(cell), Config.CELL_SIZE, Config.WALL_HEIGHT)
				stairs.position = pos
				add_child(stairs)


func _wall_along_x(cell: Vector2i) -> bool:
	return ch(cell + Vector2i(-1, 0)) == "#" and ch(cell + Vector2i(1, 0)) == "#"


func _spawn_door(cell: Vector2i) -> void:
	var door := DoorScript.new()
	door.setup(cell, _door_kind(cell), _wall_along_x(cell), Config.CELL_SIZE, Config.WALL_HEIGHT)
	door.position = cell_to_world(cell)
	door.opened.connect(_on_door_opened)
	add_child(door)


func _spawn_lamp(pos: Vector3) -> void:
	var h := Config.WALL_HEIGHT
	Builder.box(self, Vector3(1.4, 0.06, 0.5), pos + Vector3(0, h - 0.03, 0), _lamp_mat)
	var light := OmniLight3D.new()
	light.position = pos + Vector3(0, h - 0.3, 0)
	light.light_color = Config.LIGHT_NORMAL
	light.light_energy = 1.8
	light.omni_range = 11.0
	light.shadow_enabled = true
	add_child(light)
	_alarm.register_lamp(light)


func _spawn_weapon(cell: Vector2i, id: String) -> void:
	var pickup: Node3D = PickupScene.instantiate()
	pickup.setup(id)
	pickup.position = cell_to_world(cell)
	add_child(pickup)
	_used_cells[cell] = true


func _spawn_breach(pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	add_child(body)
	var metal := Builder.material(Color(0.3, 0.32, 0.35), 0.4, 0.8)
	var glass := Builder.material(Color(0.6, 0.95, 0.9, 0.2), 0.05)
	var goo := Builder.material(Color(0.2, 0.9, 0.3), 0.2, 0.0, Color(0.2, 0.9, 0.3), 1.5)
	Builder.cylinder(body, 1.0, 0.3, Vector3(0, 0.15, 0), metal)
	Builder.cylinder(body, 1.0, 0.3, Vector3(0, Config.WALL_HEIGHT - 0.15, 0), metal)
	var tube := Builder.cylinder(body, 0.9, 1.2, Vector3(0, 2.3, 0), glass)  # only the top half survives
	tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Builder.cylinder(body, 1.5, 0.02, Vector3(0, 0.01, 0), goo)
	for i in 6:
		var shard := Builder.box(body, Vector3(0.3, 0.02, 0.15), Vector3(_rng.randf_range(-1.2, 1.2), 0.03, _rng.randf_range(-1.2, 1.2)), glass)
		shard.rotation.y = _rng.randf() * TAU
	var light := OmniLight3D.new()
	light.light_color = Color(0.3, 1.0, 0.4)
	light.light_energy = 1.5
	light.omni_range = 6.0
	light.position = Vector3(0, 1.0, 0)
	body.add_child(light)
	var sign := Label3D.new()
	sign.text = "CONTAINMENT BREACH"
	sign.modulate = Color(1, 0.25, 0.2)
	sign.font_size = 56
	sign.pixel_size = 0.005
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = Vector3(0, 2.9, 0)
	body.add_child(sign)
	var shape := CylinderShape3D.new()
	shape.radius = 1.0
	shape.height = Config.WALL_HEIGHT
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = Config.WALL_HEIGHT / 2.0
	body.add_child(col)


# --- Furniture ------------------------------------------------------------

func _decorate() -> void:
	# First 4 rooms: cabinets with the syringes, plus a desk and a fridge.
	var cabinet_spots: Array = []
	for room in _start_rooms:
		var spots := _wall_spots(_regions[room])
		var cabinets := 0
		for spot in spots:
			if cabinets < Config.CABINETS_PER_START_ROOM and _claim(spot["cell"]):
				cabinet_spots.append(spot)
				cabinets += 1
		var extras := ["desk", "fridge"]
		for spot in spots:
			if extras.is_empty():
				break
			if _claim(spot["cell"]):
				_place_furniture(extras.pop_front(), spot)

	if cabinet_spots.size() < Config.SYRINGES_NEEDED:
		push_error("Only %d cabinets fit in the start rooms, %d syringes are needed" % [cabinet_spots.size(), Config.SYRINGES_NEEDED])
	var contents: Array[String] = []
	for i in cabinet_spots.size():
		contents.append("syringe" if i < Config.SYRINGES_NEEDED else "bandage")
	_shuffle(contents)
	for i in cabinet_spots.size():
		var cabinet := CabinetScript.new()
		cabinet.setup(contents[i])
		_place_against_wall(cabinet, cabinet_spots[i], 0.5)

	# Security Guard Room: lockers, a gun rack, the CCTV desk and an ammo cabinet.
	if _guard_region >= 0:
		var guard_items := ["gun_rack", "locker", "locker", "security_desk"]
		for spot in _wall_spots(_regions[_guard_region]):
			if guard_items.is_empty():
				break
			if _claim(spot["cell"]):
				_place_furniture(guard_items.pop_front(), spot)
		for spot in _wall_spots(_regions[_guard_region]):
			if _claim(spot["cell"]):
				var ammo := CabinetScript.new()
				ammo.setup("ammo_rifle")
				_place_against_wall(ammo, spot, 0.5)
				break

	# Other keycard areas: lab tables and one supply cabinet each.
	var supplies := ["bandage", "ammo_shotgun", "bandage", "ammo_rifle", "bandage"]
	for id in _regions.size():
		if id == _hall_region or id == _guard_region or _start_rooms.has(id):
			continue
		var spots := _wall_spots(_regions[id])
		var tables: int = max(1, _regions[id].size() / 9)
		for spot in spots:
			if not supplies.is_empty() and _claim(spot["cell"]):
				var cabinet := CabinetScript.new()
				cabinet.setup(supplies.pop_front())
				_place_against_wall(cabinet, spot, 0.5)
				break
		for spot in spots:
			if tables <= 0:
				break
			if _claim(spot["cell"]):
				_place_furniture("lab_table" if tables % 2 == 0 else "desk", spot)
				tables -= 1


## Floor cells next to a wall, away from doors, stairs, the breach and spawns.
func _wall_spots(cells: Array) -> Array:
	var spots: Array = []
	for cell in cells:
		if ch(cell) != "." and ch(cell) != "L":
			continue
		var blocked := false
		for d in DIRS:
			if ch(cell + d) in "DXTPBAE":
				blocked = true
		if blocked:
			continue
		for d in DIRS:
			if ch(cell + d) == "#":
				spots.append({"cell": cell, "wall": d})
				break
	_shuffle(spots)
	return spots


func _claim(cell: Vector2i) -> bool:
	if _used_cells.has(cell):
		return false
	for d in DIRS:
		if _used_cells.has(cell + d):
			return false
	_used_cells[cell] = true
	return true


func _place_against_wall(node: Node3D, spot: Dictionary, depth: float) -> void:
	var wall: Vector2i = spot["wall"]
	var offset := Vector3(wall.x, 0, wall.y) * (Config.CELL_SIZE / 2.0 - depth / 2.0 - 0.02)
	node.position = cell_to_world(spot["cell"]) + offset
	node.rotation.y = atan2(-wall.x, -wall.y)  # front (+Z) faces the room
	add_child(node)


func _place_furniture(kind: String, spot: Dictionary) -> void:
	var body := StaticBody3D.new()
	var white := Builder.material(Color(0.9, 0.91, 0.92), 0.4, 0.1)
	var steel := Builder.material(Color(0.68, 0.7, 0.73), 0.3, 0.7)
	var dark := Builder.material(Color(0.15, 0.16, 0.18), 0.6)
	var depth := 0.7
	match kind:
		"desk":
			Builder.box(body, Vector3(1.5, 0.05, 0.7), Vector3(0, 0.76, 0), white)
			Builder.box(body, Vector3(0.45, 0.72, 0.65), Vector3(-0.5, 0.36, 0), white)
			Builder.box(body, Vector3(0.05, 0.72, 0.65), Vector3(0.7, 0.36, 0), white)
			Builder.box(body, Vector3(0.55, 0.35, 0.04), Vector3(0.1, 1.0, -0.2), dark)       # monitor
			var screen_mat := Builder.material(Color(0.2, 0.5, 0.6), 0.3, 0.0, Color(0.2, 0.6, 0.7), 1.2)
			Builder.box(body, Vector3(0.5, 0.3, 0.01), Vector3(0.1, 1.0, -0.177), screen_mat)
			Builder.box(body, Vector3(0.45, 0.05, 0.45), Vector3(0.1, 0.47, 0.65), dark)      # chair
			Builder.box(body, Vector3(0.45, 0.5, 0.05), Vector3(0.1, 0.75, 0.88), dark)
			Builder.box_collision(body, Vector3(1.5, 0.8, 0.7), Vector3(0, 0.4, 0))
		"fridge":
			depth = 0.75
			Builder.box(body, Vector3(0.9, 1.95, 0.75), Vector3(0, 0.975, 0), white)
			var glass := Builder.material(Color(0.6, 0.85, 1.0), 0.1, 0.0, Color(0.5, 0.8, 1.0), 0.8)
			Builder.box(body, Vector3(0.7, 1.2, 0.02), Vector3(0, 1.2, 0.38), glass)
			for y in [0.85, 1.25, 1.65]:
				Builder.box(body, Vector3(0.6, 0.12, 0.02), Vector3(0, y, 0.39), Builder.material(Color(0.8, 0.2, 0.2)))
			Builder.box_collision(body, Vector3(0.9, 1.95, 0.75), Vector3(0, 0.975, 0))
		"lab_table":
			depth = 0.9
			Builder.box(body, Vector3(1.9, 0.06, 0.9), Vector3(0, 0.9, 0), steel)
			Builder.box(body, Vector3(1.8, 0.82, 0.8), Vector3(0, 0.44, 0), white)
			var colors := [Color(0.3, 0.9, 0.4, 0.7), Color(0.9, 0.3, 0.3, 0.7), Color(0.3, 0.5, 0.95, 0.7)]
			for i in 4:
				var liquid := Builder.material(colors[i % colors.size()], 0.1)
				Builder.cylinder(body, 0.05, 0.22, Vector3(-0.6 + i * 0.35, 1.04, _rng.randf_range(-0.2, 0.2)), liquid)
			Builder.box(body, Vector3(0.4, 0.3, 0.3), Vector3(0.65, 1.08, 0), dark)          # microscope base
			Builder.box_collision(body, Vector3(1.9, 0.95, 0.9), Vector3(0, 0.47, 0))
		"locker":
			depth = 0.55
			var green := Builder.material(Color(0.22, 0.3, 0.26), 0.5, 0.5)
			for i in 3:
				var x := -0.6 + i * 0.6
				Builder.box(body, Vector3(0.58, 2.0, 0.55), Vector3(x, 1.0, 0), green)
				Builder.box(body, Vector3(0.3, 0.04, 0.01), Vector3(x, 1.75, 0.28), dark)   # vents
				Builder.box(body, Vector3(0.3, 0.04, 0.01), Vector3(x, 1.65, 0.28), dark)
				Builder.box(body, Vector3(0.04, 0.15, 0.03), Vector3(x + 0.2, 1.05, 0.29), steel)  # handle
			Builder.box_collision(body, Vector3(1.8, 2.0, 0.55), Vector3(0, 1.0, 0))
		"gun_rack":
			depth = 0.3
			var wood := Builder.material(Color(0.3, 0.2, 0.12), 0.8)
			var gun := Builder.material(Color(0.1, 0.1, 0.11), 0.4, 0.6)
			Builder.box(body, Vector3(2.0, 1.4, 0.06), Vector3(0, 1.4, -0.12), wood)
			for i in 4:
				var rifle := Builder.box(body, Vector3(0.07, 1.0, 0.06), Vector3(-0.75 + i * 0.5, 1.35, -0.05), gun)
				rifle.rotation.z = 0.08
			Builder.box(body, Vector3(2.0, 0.08, 0.25), Vector3(0, 0.85, 0.0), wood)   # shelf
			Builder.box_collision(body, Vector3(2.0, 1.5, 0.3), Vector3(0, 1.3, 0))
		"security_desk":
			depth = 0.8
			Builder.box(body, Vector3(2.0, 0.06, 0.8), Vector3(0, 0.78, 0), dark)
			Builder.box(body, Vector3(1.9, 0.74, 0.7), Vector3(0, 0.38, 0), steel)
			var cctv := Builder.material(Color(0.2, 0.35, 0.3), 0.3, 0.0, Color(0.3, 0.6, 0.5), 1.0)
			for i in 3:
				Builder.box(body, Vector3(0.55, 0.38, 0.06), Vector3(-0.62 + i * 0.62, 1.05, -0.25), dark)
				Builder.box(body, Vector3(0.5, 0.33, 0.01), Vector3(-0.62 + i * 0.62, 1.05, -0.215), cctv)
			Builder.box_collision(body, Vector3(2.0, 0.85, 0.8), Vector3(0, 0.42, 0))
	_place_against_wall(body, spot, depth)


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


# --- Alarm ----------------------------------------------------------------

func _on_alarm_started() -> void:
	_alarm.start()
	_spawn_infected()
	# Fresh blood in the hall when the emergency starts
	if _hall_region >= 0:
		blood.spawn_in_room(_regions[_hall_region], 6, cell_to_world, _wall_dir, Config.CELL_SIZE)
	GameManager.notify("ALARM · Patient Z has escaped!")


func _spawn_infected() -> void:
	var patient_cell := NO_CELL
	if _breach_cell != NO_CELL:
		var best := INF
		for cell in _zombie_spawns:
			var d := Vector2(cell - _breach_cell).length()
			if d < best:
				best = d
				patient_cell = cell
	for cell in _zombie_spawns:
		var zombie: CharacterBody3D = InfectadoScene.instantiate()
		zombie.setup(self, cell == patient_cell)
		zombie.position = cell_to_world(cell) + Vector3(_rng.randf_range(-0.5, 0.5), 0, _rng.randf_range(-0.5, 0.5))
		zombie.rotation.y = _rng.randf() * TAU
		add_child(zombie)


# --- Security Guard Room ----------------------------------------------------

## Sign next to the door that joins the hall with the Security Guard Room.
func _mark_guard_room() -> void:
	if _guard_region < 0:
		return
	for cell in _all_cells():
		if ch(cell) != "D":
			continue
		var ids := _door_regions(cell)
		if not (ids.has(_guard_region) and ids.has(_hall_region)):
			continue
		var to_hall := Vector2i.ZERO
		for d in DIRS:
			if _region_of.get(cell + d, -1) == _hall_region:
				to_hall = d
		var side := Vector2i(to_hall.y, to_hall.x)      # along the wall
		if ch(cell + side) != "#":
			side = -side
		var normal := Vector3(to_hall.x, 0, to_hall.y)
		var sign := StairsSign.new()
		sign.setup(GUARD_ROOM_NAME, 2.0, 0.75, Color(0.7, 0.9, 1.0))
		sign.position = cell_to_world(cell + side) + normal * (Config.CELL_SIZE / 2.0 + 0.04) + Vector3(0, 2.2, 0)
		sign.rotation.y = atan2(normal.x, normal.z)
		add_child(sign)


# --- Blood ------------------------------------------------------------------

## Random blood in every room where infected appear, plus around the breach.
func _spawn_room_blood() -> void:
	for id in _regions.size():
		var cells: Array = _regions[id]
		var infected := cells.filter(func(c): return ch(c) == "Z").size()
		var has_breach := cells.any(func(c): return ch(c) == "T")
		if infected == 0 and not has_breach:
			continue
		var amount := 4 + infected * 3 + (8 if has_breach else 0)
		blood.spawn_in_room(cells, amount, cell_to_world, _wall_dir, Config.CELL_SIZE)


## Direction of a wall next to the cell (Vector2i.ZERO if none).
func _wall_dir(cell: Vector2i) -> Vector2i:
	for d in DIRS:
		if ch(cell + d) == "#":
			return d
	return Vector2i.ZERO
