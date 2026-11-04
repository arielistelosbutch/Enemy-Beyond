extends RefCounted
## Builds a random night map from 12 m blocks, like UFO's map blocks: fields,
## pastures, a farmhouse, a barn, woods, a road, the crashed UFO and the
## Kondor (dropship). Same seed = same map on every machine.

const BLOCK := 12.0
var N := 7                 # blocks per side: see SIZES
const SIZES := {"small": 8, "medium": 10, "large": 12, "huge": 15, "colossal": 18}
const SIZE_NAMES := {"small": "malá", "medium": "střední", "large": "velká", "huge": "obrovská", "colossal": "kolosální"}
var terrain := "temperate"   # temperate / snow (loud steps, snowfall) / desert

var rng := RandomNumberGenerator.new()
var root: Node3D
var nav: NavigationRegion3D
var info := {
	"player_spawns": [], "alien_spawns": [], "waypoints": [], "cover": [],
	"evac": Vector3.ZERO, "ufo": Vector3.ZERO, "lights": [], "surfaces": [], "size": BLOCK * N,
	"elec_lights": [], "sounds": [], "barn": Vector3.ZERO, "house": Vector3.ZERO,
	"windows": [], "roofs": [], "doors": [], "cows": [], "circle": Vector3.ZERO, "truck": Vector3.ZERO, "breakables": [], "landmarks": [], "vip_spots": [],
}
var us := 2                # how many blocks the ship takes on a side
var _circle_done := false
var _truck_done := false

var biome := "farm"
var mtype := "crash"
var ufo_kind := "scout"

var _t0 := 0
func build(parent: Node3D, map_seed: int, params := {}) -> Dictionary:
	_t0 = Time.get_ticks_msec()
	rng.seed = map_seed
	biome = params.get("biome", "farm")
	mtype = params.get("type", "crash")
	N = int(SIZES.get(params.get("size", "medium"), 7))
	# which ship: given (air war, quick missions), else by mission type and map size
	ufo_kind = params.get("ufo", "")
	if not ufo_kind in ["scout", "raider", "harvester", "battleship", "supply"]:
		match mtype:
			"crash": ufo_kind = "scout" if rng.randf() < 0.6 else "raider"
			"landed":
				ufo_kind = "harvester" if params.get("size", "") in ["large", "huge", "colossal"] else "raider"
				# later in the war the giants come down: a battleship or a supply ship
				if params.get("late", false) and params.get("size", "") in ["huge", "colossal"] and rng.randf() < 0.55:
					ufo_kind = "battleship" if rng.randf() < 0.5 else "supply"
			_: ufo_kind = "raider"
	if ufo_kind in ["battleship", "supply"] and N < 12:
		N = 12
	if ufo_kind == "harvester" and N < 8:
		N = 8          # a big ship needs room around it
	terrain = params.get("terrain", "temperate")
	if biome == "polar":
		terrain = "snow"
	info["size"] = BLOCK * N
	info["terrain"] = terrain
	if mtype == "mars":
		N = 8
		terrain = "mars"
		info["size"] = BLOCK * N
		info["terrain"] = "mars"
	nav = NavigationRegion3D.new()
	nav.name = "Nav"
	var nm := NavigationMesh.new()
	# fine enough that 1.2 m doorways and stairs stay open after the agent margin
	nm.agent_radius = 0.4
	nm.agent_height = 1.6
	nm.agent_max_climb = 0.4
	nm.agent_max_slope = 46.0
	nm.cell_size = 0.2
	nm.cell_height = 0.2
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 0xFFFFFFFF & ~(64 | 128)     # doors open, glass breaks: not walls for the paths
	nav.navigation_mesh = nm
	parent.add_child(nav)
	var nmap: RID = parent.get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(nmap, 0.2)
	NavigationServer3D.map_set_cell_height(nmap, 0.2)
	NavigationServer3D.map_set_link_connection_radius(nmap, 1.6)
	root = nav

	if mtype == "mars":
		_mars()
		_borders()
		nav.bake_navigation_mesh(false)
		return info
	# layout: UFO 2x2 somewhere in the middle, the Kondor at an edge block
	var grid := []
	for x in N:
		grid.append([])
		for z in N:
			grid[x].append("")
	us = 4 if ufo_kind in ["battleship", "supply"] else 2
	var ux := rng.randi_range(N / 2 - us / 2, N / 2 - us / 2 + 1)
	var uz := rng.randi_range(N / 2 - us / 2, N / 2 - us / 2 + 1)
	if biome == "base":
		uz = N - us           # they landed at the far end of the ravine
	for dx in us:
		for dz in us:
			grid[ux + dx][uz + dz] = "ufo"
	info["ufo"] = Vector3((ux + us / 2.0) * BLOCK, 0, (uz + us / 2.0) * BLOCK)
	var sx := rng.randi_range(0, N - 1)
	grid[sx][0] = "sky"
	_lay_roads(grid, ux, uz)
	# the landmarks of each kind of place first, then the fill around them
	var extra := maxi(0, (N * N - 49) / 12)     # bigger maps: more of everything
	var farm := ["house", "barn", "house2", "garden", "ruin" if rng.randf() < 0.5 else "orchard"]
	if rng.randf() < 0.5:
		farm.append("fuel")
	for i in extra:
		farm.append(["house", "house2", "garden", "orchard", "ruin"][i % 5])
	match biome:
		"town":
			farm = ["chapel", "fuel", "shop", "pub", "park", "parking", "house2", "house2", "house", "house", "house2", "barn", "garden", "ruin", "house2"]
			for i in maxi(0, (N * N - 49) / 5):      # bigger towns: more houses
				farm.append(["house", "house2", "garden", "shop", "ruin", "parking", "pub", "park"][i % 8])
		"polar":
			farm = ["icelake", "icelake", "icespires", "icespires", "polarhut", "rocks"]
			for i in extra:
				farm.append(["icelake", "icespires", "rocks"][i % 3])
		"forest":
			farm = ["stream", "rocks", "cabin" if rng.randf() < 0.7 else "ruin"]
			if rng.randf() < 0.5:
				farm.append("house")
			for i in extra:
				farm.append(["stream", "rocks", "ruin"][i % 3])
		"mountain":
			farm = ["cabin", "rocks", "rocks", "stream", "cabin" if rng.randf() < 0.5 else "ruin"]
			for i in extra:
				farm.append(["rocks", "cabin", "stream"][i % 3])
		"base":
			farm = ["hangar", "hangar", "barracks", "barracks", "radar", "house2", "sandbags", "sandbags", "containers", "tanks", "yard"]
			for i in extra:
				farm.append(["sandbags", "barracks", "yard"][i % 3])
		"desert":
			farm = ["ruin", "rocks", "rocks", "cabin" if rng.randf() < 0.6 else "ruin"]
			if rng.randf() < 0.5:
				farm.append("fuel")
			for i in extra:
				farm.append(["rocks", "ruin", "dunes"][i % 3])
		"industrial":
			farm = ["warehouse", "warehouse", "containers", "containers", "tanks", "yard", "yard", "fuel"]
			for i in maxi(0, (N * N - 49) / 6):
				farm.append(["warehouse", "containers", "yard", "tanks", "ruin"][i % 5])
	for f in farm:
		for tries in 50:
			var x := rng.randi_range(0, N - 1)
			var z := rng.randi_range(1, N - 1)
			if grid[x][z] == "":
				grid[x][z] = f
				break
	# the fill: only what belongs to this kind of place (no single road pieces - roads are lines)
	var fill := ["field", "field", "pasture", "pasture", "forest", "forest", "orchard", "garden", "meadow", "meadow", "meadow"]
	match biome:
		"forest": fill = ["forest", "forest", "forest", "forest", "forest", "rocks", "pasture", "stream", "meadow", "meadow"]
		"town": fill = ["garden", "house", "house2", "parking", "garden", "meadow", "house2"]
		"mountain": fill = ["forest", "forest", "rocks", "rocks", "pasture", "meadow", "meadow"]
		"industrial": fill = ["yard", "yard", "containers", "parking", "yard"]
		"base": fill = ["yard", "sandbags", "pasture", "rocks", "forest"]
		"polar": fill = ["pasture", "pasture", "icespires", "rocks", "icelake"]
		"desert": fill = ["dunes", "dunes", "dunes", "rocks"]
	if terrain == "desert":
		# sand: no fields, meadows, gardens or woods
		for i in fill.size():
			if fill[i] in ["field", "pasture", "forest", "orchard", "garden"]:
				fill[i] = "dunes"
	for x in N:
		for z in N:
			if grid[x][z] == "":
				grid[x][z] = fill[rng.randi() % fill.size()]

	for x in N:
		for z in N:
			var o := Vector3(x * BLOCK, 0, z * BLOCK)
			if grid[x][z] in ["house2", "ruin", "garden", "orchard", "stream", "rocks", "cabin", "warehouse", "containers", "tanks", "yard", "fuel", "hangar", "barracks", "radar", "sandbags", "shop", "pub", "park", "parking", "icelake", "icespires", "polarhut"]:
				info["landmarks"].append([grid[x][z], o])
			match grid[x][z]:
				"field": _field(o)
				"dunes": _dunes(o)
				"meadow": _meadow(o)
				"road_ns": _road(o, false)
				"road_ew": _road(o, true)
				"road_x": _road(o, false, true)
				"street_ns": _street(o, false)
				"street_ew": _street(o, true)
				"street_x": _street(o, false, true)
				"pasture": _pasture(o)
				"forest": _forest(o)
				"road": _road(o, false)
				"street": _street(o, false)
				"house": _house(o)
				"barn": _barn(o)
				"chapel": _chapel(o)
				"house2": _house2(o)
				"ruin": _ruin(o)
				"garden": _garden(o)
				"orchard": _orchard(o)
				"stream": _stream(o)
				"rocks": _rocks(o)
				"cabin": _cabin(o)
				"warehouse": _warehouse(o)
				"containers": _containers(o)
				"tanks": _tanks(o)
				"yard": _yard(o)
				"fuel": _fuel(o)
				"hangar": _hangar(o)
				"barracks": _barracks(o)
				"radar": _radar_tower(o)
				"sandbags": _sandbags(o)
				"shop": _shop(o)
				"pub": _pub(o)
				"park": _park(o)
				"parking": _parking(o)
				"icelake": _icelake(o)
				"icespires": _icespires(o)
				"polarhut": _polar_hut(o)
				"sky": _skyranger(o)
				"ufo":
					_ground(o, "concrete" if biome == "industrial" else "grass")
					if biome != "industrial" and biome != "base":
						_grass(o, 700, "dry", 0.5, 1.1)
	if Game.autotest() != "": print("[MAP] tiles done %d ms" % (Time.get_ticks_msec() - _t0))
	if us > 2:
		_big_ufo(Vector3((ux + us / 2.0) * BLOCK, 0, (uz + us / 2.0) * BLOCK))
	else:
		_ufo(Vector3((ux + 1) * BLOCK, 0, (uz + 1) * BLOCK))
	if Game.autotest() != "": print("[MAP] ufo done")
	_blood_trail()
	if Game.autotest() != "": print("[MAP] trail done")
	_borders()
	_clear_doors()
	nav.bake_navigation_mesh(false)
	if Game.autotest() != "": print("[MAP] nav done %d ms" % (Time.get_ticks_msec() - _t0))
	return info

# ---- primitives ----------------------------------------------------------------
func box(pos: Vector3, size: Vector3, material: Material, collide := true, rot_y := 0.0) -> Node3D:
	if material == Game.mat("roof", 1.0) and size.y < 0.2 and minf(size.x, size.z) >= 2.5 and rot_y == 0.0:
		# a flat roof: a perch for the flying ones
		var top := pos + Vector3(0, size.y / 2, 0)
		info["roofs"].append(top)
		if maxf(size.x, size.z) > 6.0:
			var ax := Vector3(size.x / 2 - 1.2, 0, 0) if size.x > size.z else Vector3(0, 0, size.z / 2 - 1.2)
			info["roofs"].append(top + ax)
			info["roofs"].append(top - ax)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	if material == Game.mat("wheat", 1.0):
		bm.subdivide_depth = int(size.z)
		bm.subdivide_width = int(size.x)
	mi.mesh = bm
	mi.material_override = material
	if collide:
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		sb.add_child(cs)
		sb.add_child(mi)
		root.add_child(sb)
		sb.position = pos
		sb.rotation.y = rot_y
		return sb
	root.add_child(mi)
	mi.position = pos
	mi.rotation.y = rot_y
	# a thin floor you walk on without colliding (road, path, floorboards): remember its sound
	if size.y <= 0.12 and pos.y < 0.4 and material.has_meta("tex") and size.x * size.z > 1.0:
		var sf: String = Game.TEX_SURFACE.get(String(material.get_meta("tex")), "")
		if sf != "":
			info["surfaces"].append([Transform3D(Basis(Vector3.UP, rot_y), pos), Vector2(size.x / 2, size.z / 2), sf, pos.y + 0.5])
	return mi

func cyl(pos: Vector3, r_top: float, r_bot: float, h: float, material: Material, collide := true, sides := 8) -> Node3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = sides
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = material
	if collide:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = max(r_top, r_bot)
		shape.height = h
		cs.shape = shape
		sb.add_child(cs)
		sb.add_child(mi)
		root.add_child(sb)
		sb.position = pos
		return sb
	root.add_child(mi)
	mi.position = pos
	return mi

func _ground(o: Vector3, tex: String) -> void:
	if terrain == "mars":
		tex = "mars"
	elif terrain == "snow" and tex in ["grass", "dirt", "hay"]:
		tex = "snow"
	elif terrain == "desert" and tex in ["grass", "dirt"]:
		tex = "sand"
	box(o + Vector3(BLOCK / 2, -0.25, BLOCK / 2), Vector3(BLOCK, 0.5, BLOCK), Game.mat(tex, 0.5))

# ---- grass: thousands of small blades that sway in the wind ----------------------------------
const GRASS_SHADER := preload("res://shaders/grass.gdshader")
static var _blade: ArrayMesh
static var _grass_mats := {}

static func _blade_mesh() -> ArrayMesh:
	if _blade:
		return _blade
	# a tapered blade: 2 quads + a tip, ~0.5 m tall (scaled per instance)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := [0.035, 0.026, 0.012]
	var y := [0.0, 0.22, 0.4]
	for i in 2:
		var a0 := Vector3(-w[i], y[i], 0); var b0 := Vector3(w[i], y[i], 0)
		var a1 := Vector3(-w[i + 1], y[i + 1], 0.02 * (i + 1)); var b1 := Vector3(w[i + 1], y[i + 1], 0.02 * (i + 1))
		for v in [a0, b0, b1, a0, b1, a1]:
			st.set_normal(Vector3.BACK)
			st.add_vertex(v)
	for v in [Vector3(-w[2], y[2], 0.04), Vector3(w[2], y[2], 0.04), Vector3(0, 0.5, 0.08)]:
		st.set_normal(Vector3.BACK)
		st.add_vertex(v)
	_blade = st.commit()
	return _blade

static func _grass_mat(kind: String) -> ShaderMaterial:
	if _grass_mats.has(kind):
		return _grass_mats[kind]
	var m := ShaderMaterial.new()
	m.shader = GRASS_SHADER
	match kind:
		"wheat":
			m.set_shader_parameter("root_color", Color(0.22, 0.18, 0.08))
			m.set_shader_parameter("tip_color", Color(0.62, 0.52, 0.26))
			m.set_shader_parameter("sway", 0.32)
		"dry":
			m.set_shader_parameter("root_color", Color(0.12, 0.13, 0.07))
			m.set_shader_parameter("tip_color", Color(0.36, 0.36, 0.2))
		_:
			pass
	_grass_mats[kind] = m
	return m

## Scatters blades over a block. `keep` filters positions (e.g. not on the road).
func _grass(o: Vector3, count: int, kind := "grass", min_h := 0.6, max_h := 1.3, keep := Callable()) -> void:
	if not Game.grass or terrain == "snow" or terrain == "mars":
		return
	if terrain == "desert":
		count = count / 5
		kind = "dry"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _blade_mesh()
	var xs: Array[Transform3D] = []
	var tries := 0
	while xs.size() < count and tries < count * 3:
		tries += 1
		var lp := Vector3(rng.randf() * BLOCK, 0, rng.randf() * BLOCK)
		if keep.is_valid() and not keep.call(lp):
			continue
		var sc := rng.randf_range(min_h, max_h)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1.0 + rng.randf() * 0.6, sc, 1.0))
		b = Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, 0.25)) * b
		xs.append(Transform3D(b, lp))
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
		mm.set_instance_custom_data(i, Color(rng.randf(), 0, 0, 0))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = _grass_mat(kind)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = o
	mi.custom_aabb = AABB(Vector3(-1, -1, -1), Vector3(BLOCK + 2, 3, BLOCK + 2))
	root.add_child(mi)

## A village prop (model with its own collision) at p, turned by yaw; adds a cover point.
## A wooden building's roof: when enough of the walls under it burn or break, it comes down.
func _wood_roof(n: Node3D, c: Vector3, w: float, d: float) -> void:
	if not info.has("wood_roofs"):
		info["wood_roofs"] = []
	info["wood_roofs"].append({"node": n, "rect": Rect2(c.x - 0.3, c.z - 0.3, w + 0.6, d + 0.6)})

var _cars: Array = []
## A parked car right in front of a door: towed away (the streets are laid before the houses).
func _clear_doors() -> void:
	for car in _cars:
		if not is_instance_valid(car):
			continue
		for dd in info["doors"]:
			var c: Vector3 = dd["c"]
			if Vector2(car.position.x - c.x, car.position.z - c.z).length() < 4.0:
				car.free()      # now, before the paths are baked
				break

func _prop(name: String, p: Vector3, yaw := 0.0, cover := true) -> Node3D:
	var n: Node3D = Game.model("v_" + name)
	root.add_child(n)
	n.position = p
	n.rotation.y = yaw
	if name.begins_with("car"):
		_cars.append(n)
	if name == "house_roof":
		# a pitched roof over the flat slab: the flier sits on the ridge instead (height found later)
		info["roofs"] = info["roofs"].filter(func(r): return Vector2(r.x - p.x, r.z - p.z).length() > 5.5 or absf(r.y - p.y) > 0.6)
		info["roofs"].append(p + Vector3(0, -100.0, 0))     # y < -50: "ask the ray"
	if cover:
		_cover(p + Vector3(sin(yaw + PI / 2), 0, cos(yaw + PI / 2)) * 1.3)
	return n

var _cross_done := false
var _stop_done := false

func _cover(p: Vector3) -> void:
	info["cover"].append(p)

func _jit(o: Vector3, margin := 1.5) -> Vector3:
	return o + Vector3(rng.randf_range(margin, BLOCK - margin), 0, rng.randf_range(margin, BLOCK - margin))

# ---- blocks ------------------------------------------------------------------------
func _field(o: Vector3) -> void:
	if terrain != "temperate":
		_pasture(o)      # no wheat under snow or in the desert
		return
	if rng.randf() < 0.45:
		_prop("scarecrow", o + Vector3(rng.randf_range(2, 10), 0, rng.randf_range(2, 10)), rng.randf() * TAU, false)
	elif rng.randf() < 0.3:
		_prop("tractor", o + Vector3(rng.randf_range(3, 9), 0, rng.randf_range(3, 9)), rng.randf() * TAU)
	_ground(o, "dirt")
	# a burnt crop circle: perfect geometry in the middle of a field
	var circle := not _circle_done and rng.randf() < 0.45
	var cc := o + Vector3(BLOCK / 2, 0, BLOCK / 2)
	if circle:
		_circle_done = true
		info["circle"] = cc
		cyl(cc + Vector3(0, 0.03, 0), 4.6, 4.6, 0.04, Game.mat("hay", 0.8), false, 24)
		cyl(cc + Vector3(0, 0.05, 0), 3.6, 3.6, 0.04, Game.mat("scorch"), false, 24)
		cyl(cc + Vector3(0, 0.07, 0), 2.8, 2.8, 0.04, Game.mat("hay", 0.8), false, 24)
		cyl(cc + Vector3(0, 0.09, 0), 0.6, 0.6, 0.04, Game.mat("scorch"), false, 12)
		for k in 3:
			var a := TAU * k / 3.0
			cyl(cc + Vector3(sin(a) * 4.0, 0.06, cos(a) * 4.0), 0.5, 0.5, 0.04, Game.mat("scorch"), false, 10)
		info["waypoints"].append(cc)
	# rows of wheat: knee-high, hide nothing but look the part
	for i in range(1, 12, 2):
		if not circle:
			box(o + Vector3(i, 0.35, BLOCK / 2), Vector3(0.8, 0.7, BLOCK - 1), Game.mat("wheat", 1.0), false)
			continue
		var zz := 0.5
		while zz < BLOCK - 0.5:
			var p := o + Vector3(i, 0.35, zz + 0.5)
			if Vector2(p.x - cc.x, p.z - cc.z).length() > 4.8:
				box(p, Vector3(0.8, 0.7, 1.0), Game.mat("wheat", 1.0), false)
			zz += 1.0
	# loose stalks over the rows (left out of the burnt circle)
	_grass(o, 1400, "wheat", 1.6, 2.4, func(lp: Vector3) -> bool:
		var on_row := fmod(lp.x, 2.0) > 0.45 and fmod(lp.x, 2.0) < 1.55
		return on_row and lp.x > 0.5 and lp.x < 11.5 and (not circle or Vector2(o.x + lp.x - cc.x, o.z + lp.z - cc.z).length() > 4.8))
	if rng.randf() < 0.6:
		_hay(_jit(o))
	info["waypoints"].append(o + Vector3(BLOCK / 2, 0, BLOCK / 2))

func _hay(p: Vector3) -> void:
	cyl(p + Vector3(0, 0.6, 0), 0.7, 0.7, 1.2, Game.mat("hay", 1.0), true, 10)
	_cover(p + Vector3(1.2, 0, 0)); _cover(p + Vector3(-1.2, 0, 0))

func _pasture(o: Vector3) -> void:
	if terrain == "desert":
		_dunes(o)      # no meadows, cows or trees in the sand
		return
	if biome == "polar":
		# open snow: a few stones, a snow drift
		_ground(o, "snow")
		for i in rng.randi_range(1, 3):
			var p := _jit(o, 1.5)
			var r := rng.randf_range(0.3, 0.8)
			cyl(p + Vector3(0, r * 0.3, 0), r * 0.6, r, r * 0.6, Game.mat("rock", 0.6), r > 0.5, 6)
		box(_jit(o, 3.0) + Vector3(0, 0.25, 0), Vector3(rng.randf_range(2, 4), 0.5, 1.2), Game.mat("snow", 0.5), true, rng.randf() * PI)
		info["waypoints"].append(o + Vector3(BLOCK / 2, 0, BLOCK / 2))
		return
	_ground(o, "grass")
	_grass(o, 1300)
	var side := rng.randi() % 4
	for i in 6:
		var p: Vector3
		match side:
			0: p = o + Vector3(1 + i * 2, 0.5, 0.5)
			1: p = o + Vector3(1 + i * 2, 0.5, BLOCK - 0.5)
			2: p = o + Vector3(0.5, 0.5, 1 + i * 2)
			_: p = o + Vector3(BLOCK - 0.5, 0.5, 1 + i * 2)
		box(p, Vector3(0.15, 1.0, 0.15), Game.mat("fence"))
		var horiz := side < 2
		box(p + Vector3(1 if horiz else 0, 0.1, 0 if horiz else 1), Vector3(2 if horiz else 0.08, 0.1, 0.08 if horiz else 2), Game.mat("fence"), false)
	for i in rng.randi_range(1, 3):
		_hay(_jit(o, 2.5))
	if rng.randf() < 0.6:
		_prop("trough", _jit(o, 2.5), rng.randf() * TAU)
	for i in rng.randi_range(0, 2):
		_cow(_jit(o, 2.5), rng.randf() < 0.75)
	info["waypoints"].append(o + Vector3(BLOCK / 2, 0, BLOCK / 2))

## Cows. Most of them dead - lying on their side, some of them cut open with
## surgical precision. Sometimes one stands, perfectly still, facing the UFO.
func _cow(p: Vector3, dead: bool) -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	holder.position = p
	info["cows"].append(p)
	holder.rotation.y = rng.randf() * TAU
	var hide := Game.color_mat(Color(0.75, 0.72, 0.68))
	var body := Game.model("cow")
	holder.add_child(body)
	if dead:
		body.rotation.z = PI / 2
		body.position = Vector3(0.98, 0.31, 0)
		if rng.randf() < 0.6:
			# the cut: a clean dark wound, no blood around it
			var cut := MeshInstance3D.new()
			var cm := BoxMesh.new()
			cm.size = Vector3(0.62, 0.05, 0.9)
			cut.mesh = cm
			cut.material_override = Game.color_mat(Color(0.25, 0.02, 0.03))
			body.add_child(cut)
			cut.position = Vector3(0, 1.36, 0.05)
		box(p + Vector3(0, 0.3, 0), Vector3(1.5, 0.6, 1.5), hide, true).visible = false
	else:
		holder.look_at(Vector3(info["ufo"].x, p.y, info["ufo"].z) if info["ufo"] != Vector3.ZERO else p + Vector3(0, 0, -1), Vector3.UP)
		box(p + Vector3(0, 0.8, 0), Vector3(0.8, 1.6, 0.8), hide, true).visible = false
	_cover(p + Vector3(1.3, 0, 0))

func _forest(o: Vector3) -> void:
	if terrain == "desert":
		_dunes(o)      # no meadows, cows or trees in the sand
		return
	_ground(o, "grass")
	for i in rng.randi_range(5, 9):
		var p := _jit(o, 1.0)
		var h := rng.randf_range(4.0, 7.0)
		cyl(p + Vector3(0, h / 2, 0), 0.18, 0.3, h, Game.mat("bark", 1.0), true, 6)
		var r := rng.randf_range(1.6, 2.4)
		cyl(p + Vector3(0, h * 0.62, 0), 0.0, r, h * 0.6, Game.mat("leaves", 0.6), false, 7)
		cyl(p + Vector3(0, h * 0.9, 0), 0.0, r * 0.7, h * 0.45, Game.mat("leaves", 0.6), false, 7)
		_cover(p + Vector3(0.7, 0, 0.7))
	_grass(o, 900, "dry", 0.5, 1.2)
	info["waypoints"].append(o + Vector3(BLOCK / 2, 0, BLOCK / 2))

## Town street: asphalt, a pavement, street lamps that die when they come close.
## Roads are laid as whole lines across the map (like the old game's road pieces): each piece knows
## which way it runs (ew = east-west) and a crossing has both.
func _lay_roads(grid: Array, ux: int, uz: int) -> void:
	var kind := "street" if biome in ["town", "industrial", "base"] else "road"
	var cols := 0
	var rows := 0
	match biome:
		"town": cols = 2 if N >= 9 else 1; rows = 1
		"industrial": cols = 1; rows = 1
		"base": cols = 1
		"polar": cols = 0
		"desert": cols = 1 if rng.randf() < 0.6 else 0
		_: cols = 1 if rng.randf() < 0.5 else 0; rows = 1 - cols if rng.randf() < 0.85 else 0
	var used_c := []
	for i in cols:
		for t in 20:
			var c := rng.randi_range(0, N - 1)
			if (c >= ux and c < ux + us) or c in used_c or (c - 1) in used_c or (c + 1) in used_c:
				continue
			used_c.append(c)
			for z in N:
				if grid[c][z] == "":
					grid[c][z] = kind + "_ns"
			break
	for i in rows:
		for t in 20:
			var r := rng.randi_range(1, N - 1)
			if r >= uz and r < uz + us:
				continue
			for x in N:
				if grid[x][r] == "":
					grid[x][r] = kind + "_ew"
				elif String(grid[x][r]).ends_with("_ns"):
					grid[x][r] = kind + "_x"
			break

## A point of a north-south road piece, turned for an east-west one.
func _rp(o: Vector3, lp: Vector3, ew: bool) -> Vector3:
	return o + (Vector3(lp.z, lp.y, BLOCK - lp.x) if ew else lp)

func _rs(sz: Vector3, ew: bool) -> Vector3:
	return Vector3(sz.z, sz.y, sz.x) if ew else sz

func _street(o: Vector3, ew := false, cross := false) -> void:
	_ground(o, "dirt")
	var asph := Game.color_mat(Color(0.1, 0.1, 0.11))
	for dir in ([false, true] if cross else [ew]):
		box(_rp(o, Vector3(BLOCK / 2, 0.01, BLOCK / 2), dir), _rs(Vector3(5.0, 0.04, BLOCK), dir), asph, false)
		if not cross:
			box(_rp(o, Vector3(BLOCK / 2, 0.04, BLOCK / 2), dir), _rs(Vector3(0.15, 0.01, BLOCK), dir), Game.color_mat(Color(0.6, 0.6, 0.5)), false)
	# pavements: along both sides, or the four corners at a crossing
	if cross:
		for cx in [1.2, BLOCK - 1.2]:
			for cz in [1.2, BLOCK - 1.2]:
				box(o + Vector3(cx, 0.08, cz), Vector3(2.4, 0.16, 2.4), Game.mat("plaster", 1.0), false)
	else:
		for sx in [-1, 1]:
			box(_rp(o, Vector3(BLOCK / 2 + sx * 3.4, 0.08, BLOCK / 2), ew), _rs(Vector3(1.6, 0.16, BLOCK), ew), Game.mat("plaster", 1.0), false)
	for z in ([2.5, 9.5] if not cross else [1.2]):
		var lp := _rp(o, Vector3(BLOCK / 2 + (3.9 if z < 5 else -3.9), 0, z), ew) if not cross else o + Vector3(1.2, 0, 1.2)
		cyl(lp + Vector3(0, 2.0, 0), 0.06, 0.08, 4.0, Game.color_mat(Color(0.15, 0.16, 0.17)), true, 6)
		var lens := box(lp + Vector3(0, 4.0, 0), Vector3(0.4, 0.1, 0.25), Game.color_mat(Color(1.0, 0.85, 0.55), true), false)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.75, 0.45)
		l.light_energy = 1.4
		l.omni_range = 9.0
		root.add_child(l)
		l.position = lp + Vector3(0, 3.8, 0)
		l.set_meta("base", 1.4)
		l.set_meta("lens", lens)
		info["elec_lights"].append(l)
	# a parked car, along the street
	if not cross and rng.randf() < 0.6:
		var c := _rp(o, Vector3(BLOCK / 2 + 1.4, 0, rng.randf_range(3, 9)), ew)
		var car := _prop(["car_blue", "car_red", "car_beige"][rng.randi() % 3], c, (PI if rng.randf() < 0.5 else 0.0) + (PI / 2 if ew else 0.0))
		car.rotation.y += rng.randf_range(-0.15, 0.15)
	if not cross and not _stop_done and rng.randf() < 0.5:
		_stop_done = true
		_prop("bus_stop", _rp(o, Vector3(BLOCK / 2 - 4.6, 0, 6.0), ew), -PI / 2 + (PI / 2 if ew else 0.0))
	info["waypoints"].append(o + Vector3(BLOCK / 2, 0, BLOCK / 2))

func _road(o: Vector3, ew := false, cross := false) -> void:
	_ground(o, "grass")
	for dir in ([false, true] if cross else [ew]):
		box(_rp(o, Vector3(BLOCK / 2, 0.01, BLOCK / 2), dir), _rs(Vector3(3.5, 0.04, BLOCK), dir), Game.mat("dirt", 0.5), false)
	if not cross:
		for z in [2.0, 8.0]:
			_prop("pole", _rp(o, Vector3(BLOCK / 2 - 2.6, 0, z), ew), PI / 2 + (PI / 2 if ew else 0.0), false)
		if not _cross_done and rng.randf() < 0.6:
			_cross_done = true
			_prop("cross", _rp(o, Vector3(BLOCK / 2 + 3.0, 0, BLOCK / 2 + 3.5), ew), PI / 2 + (PI / 2 if ew else 0.0))
	if not _truck_done and not cross:
		_truck_done = true
		_truck(_rp(o, Vector3(BLOCK / 2 + 0.6, 0, BLOCK / 2), ew), ew)
	info["waypoints"].append(o + Vector3(BLOCK / 2, 0, BLOCK / 2))

## Nothing much: open grass (snow, sand) - room to breathe, and nowhere to hide.
func _meadow(o: Vector3) -> void:
	if terrain == "desert":
		_dunes(o)
		return
	_ground(o, "grass")
	if terrain != "snow":
		_grass(o, rng.randi_range(250, 600), "grass", 0.5, 1.1)
	if rng.randf() < 0.25:
		var p := _jit(o, 2.0)
		cyl(p + Vector3(0, 0.3, 0), 0.4, 0.6, 0.6, Game.mat("rock", 0.5), true, 6)
	info["waypoints"].append(o + Vector3(BLOCK / 2, 0, BLOCK / 2))

## Desert: sand in long low dunes, a few stones, dry tufts, sometimes a bleached wreck.
func _dunes(o: Vector3) -> void:
	_ground(o, "sand")
	for i in rng.randi_range(2, 4):
		var p := _jit(o, 2.0)
		var d := box(p + Vector3(0, 0.15, 0), Vector3(rng.randf_range(3.0, 6.0), 0.6, rng.randf_range(1.5, 2.5)), Game.mat("sand", 0.5), true, rng.randf() * PI)
		d.rotation.z = rng.randf_range(-0.08, 0.08)
	for i in rng.randi_range(1, 3):
		var p2 := _jit(o, 1.0)
		var r := rng.randf_range(0.3, 0.9)
		cyl(p2 + Vector3(0, r * 0.4, 0), r * 0.6, r, r * 0.9, Game.mat("rock", 0.5), true, 6).rotation.y = rng.randf() * PI
	if rng.randf() < 0.15:
		_prop(["car_beige", "car_red"][rng.randi() % 2], _jit(o, 3.0), rng.randf() * TAU)
	_grass(o, 160, "dry", 0.3, 0.7)
	info["waypoints"].append(o + Vector3(BLOCK / 2, 0, BLOCK / 2))

## The farmer's pickup: engine dead, headlights still on, driver's door open,
## the radio hissing to nobody.
func _truck(p: Vector3, ew := false) -> void:
	info["truck"] = p
	var ry := PI / 2 if ew else 0.0
	var tp := func(v: Vector3) -> Vector3: return p + (Vector3(v.z, v.y, -v.x) if ew else v)
	var paint := Game.color_mat(Color(0.35, 0.12, 0.10))
	var dark := Game.color_mat(Color(0.05, 0.05, 0.06))
	var glass := Game.color_mat(Color(0.1, 0.14, 0.16))
	box(tp.call(Vector3(0, 0.8, 0)), Vector3(1.9, 0.7, 4.6), paint, true, ry)
	box(tp.call(Vector3(0, 1.45, -0.4)), Vector3(1.8, 0.65, 1.6), glass, true, ry)
	box(tp.call(Vector3(0, 1.8, -0.4)), Vector3(1.85, 0.08, 1.7), paint, false, ry)
	for wx in [-0.95, 0.95]:
		for wz in [-1.5, 1.5]:
			cyl(tp.call(Vector3(wx, 0.38, wz)), 0.38, 0.38, 0.3, dark, false, 8).rotation = Vector3(0, ry, PI / 2)
	# open door
	box(tp.call(Vector3(-1.55, 1.1, -0.9)), Vector3(0.08, 1.0, 1.1), paint, false, 0.9 + ry)
	for hx in [-0.6, 0.6]:
		var lens := box(tp.call(Vector3(hx, 0.95, -2.32)), Vector3(0.3, 0.2, 0.05), Game.color_mat(Color(1.0, 0.95, 0.75), true), false, ry)
		var sl := SpotLight3D.new()
		sl.light_color = Color(1.0, 0.93, 0.75)
		sl.light_energy = 2.5
		sl.spot_range = 22.0
		sl.spot_angle = 24.0
		sl.shadow_enabled = hx < 0
		root.add_child(sl)
		sl.position = tp.call(Vector3(hx, 0.95, -2.4))
		sl.rotation = Vector3(-0.08, ry, 0)
		sl.set_meta("base", 2.5)
		sl.set_meta("lens", lens)
		info["elec_lights"].append(sl)
	info["sounds"].append({"name": "static", "pos": tp.call(Vector3(0, 1.3, -0.5)), "db": -14.0})
	_cover(tp.call(Vector3(1.6, 0, 0.5))); _cover(tp.call(Vector3(-1.8, 0, 1.5)))

## Walls with openings: segments along an axis; gaps are [from, to] in metres.
## Gaps are [from, to] (a doorway) or [from, to, sill] (a window: wall below the sill).
## Returns the wall pieces (each can be broken - see _breakable).
func _wall(start: Vector3, length: float, along_x: bool, h: float, material: Material, gaps := [], kind := "") -> Array:
	var out := []
	# doorways at least 1.5 m: narrower ones close up in the navigation mesh (aliens and
	# the people you rescue could not get through)
	var g2 := []
	for g in gaps:
		var gg: Array = g.duplicate()
		if gg.size() == 2 and gg[1] - gg[0] < 1.5:
			var mid0: float = (gg[0] + gg[1]) / 2.0
			gg[0] = clampf(mid0 - 0.75, 0.3, length - 1.8)
			gg[1] = gg[0] + 1.5
		g2.append(gg)
	gaps = g2
	gaps.sort_custom(func(x, y): return x[0] < y[0])
	var cuts := [0.0]
	for g in gaps:
		cuts.append(g[0]); cuts.append(g[1])
	cuts.append(length)
	for i in range(0, cuts.size(), 2):
		var a: float = cuts[i]
		var b: float = cuts[i + 1]
		if b - a < 0.05:
			continue
		# breakable walls come in pieces about 2 m wide: a blast makes a hole, not a missing wall
		var pieces := maxi(1, ceili((b - a) / 2.2)) if kind != "" else 1
		var pw := (b - a) / pieces
		for k in pieces:
			var mid := a + pw * (k + 0.5)
			var pos := start + (Vector3(mid, h / 2, 0) if along_x else Vector3(0, h / 2, mid))
			out.append(box(pos, Vector3(pw, h, 0.25) if along_x else Vector3(0.25, h, pw), material))
	# doors in the doorways of houses (the mission hangs them after the paths are baked)
	if kind != "":
		for g in gaps:
			if g.size() == 2 and g[1] - g[0] <= 1.65 and rng.randf() < 0.8:
				var md: float = (g[0] + g[1]) / 2.0
				var dc: Vector3 = start + (Vector3(md, 0, 0) if along_x else Vector3(0, 0, md))
				var lim := float(info.get("size", BLOCK * N))
				if minf(minf(dc.x, dc.z), minf(lim - dc.x, lim - dc.z)) < 1.8:
					continue    # a door onto the map's edge would only open into the fence
				info["doors"].append({"c": start + (Vector3(md, 0, 0) if along_x else Vector3(0, 0, md)), "along_x": along_x,
					"w": float(g[1] - g[0]), "h": minf(2.15, h - 0.05), "open": rng.randf() < 0.3})
	# glass in the windows of houses: sight goes through, a shot or a stone breaks it
	if kind != "":
		for g in gaps:
			if g.size() > 2:
				var mg: float = (g[0] + g[1]) / 2.0
				var gw2: float = g[1] - g[0]
				var top := minf(2.0, h - 0.05)
				var gp := start + (Vector3(mg, (g[2] + top) / 2.0, 0) if along_x else Vector3(0, (g[2] + top) / 2.0, mg))
				if rng.randf() < 0.85:
					var pane := box(gp, Vector3(gw2, top - g[2], 0.04) if along_x else Vector3(0.04, top - g[2], gw2), _glass_mat())
					pane.collision_layer = 128
					_breakable(pane, "glass")
	# windows: firing positions for the aliens (both sides), and cover beside them
	for g in gaps:
		if g.size() > 2 and g[1] - g[0] >= 0.7:
			var midw: float = (g[0] + g[1]) / 2.0
			var cw := start + (Vector3(midw, 0, 0) if along_x else Vector3(0, 0, midw))
			var nrm := Vector3(0, 0, 1) if along_x else Vector3(1, 0, 0)
			var alongv := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
			info["windows"].append({"c": cw, "n": nrm, "sill": float(g[2]), "w": float(g[1] - g[0])})
			var off: float = (g[1] - g[0]) / 2.0 + 0.55
			for sd in [-1.0, 1.0]:
				_cover(cw + nrm * 0.55 * sd + alongv * off)
				_cover(cw + nrm * 0.55 * sd - alongv * off)
	# lintels above door/window gaps, sills below windows
	for g in gaps:
		var mid2: float = (g[0] + g[1]) / 2.0
		var w: float = g[1] - g[0]
		var sill: float = g[2] if g.size() > 2 else 0.0
		var top := 2.0 if sill > 0.0 else 2.2
		if h > top + 0.05:
			var pos2 := start + (Vector3(mid2, (top + h) / 2, 0) if along_x else Vector3(0, (top + h) / 2, mid2))
			out.append(box(pos2, Vector3(w, h - top, 0.25) if along_x else Vector3(0.25, h - top, w), material))
		if sill > 0.0:
			var pos3 := start + (Vector3(mid2, sill / 2, 0) if along_x else Vector3(0, sill / 2, mid2))
			out.append(box(pos3, Vector3(w, sill, 0.25) if along_x else Vector3(0.25, sill, w), material))
	if kind != "":
		for b in out:
			_breakable(b, kind)
	return out

static var _glass: StandardMaterial3D
func _glass_mat() -> Material:
	if _glass == null:
		_glass = StandardMaterial3D.new()
		_glass.albedo_color = Color(0.55, 0.7, 0.8, 0.22)
		_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glass.roughness = 0.05
		_glass.metallic_specular = 0.9
	return _glass

## Something that shots or blasts can break (see Mission.hit_breakable). The map is the same
## on every machine, so the index is the same too.
const BREAK_HP := {"wood": 70.0, "glass": 5.0, "brick": 140.0, "metal": 190.0, "crate": 45.0}
func _breakable(n: Node3D, kind: String) -> void:
	if not n is StaticBody3D:
		return
	n.set_meta("break", info["breakables"].size())
	n.set_meta("break_kind", kind)
	n.set_meta("hp", BREAK_HP.get(kind, 100.0))
	info["breakables"].append(n)

## A walkable slope (invisible) from @a a (bottom) to @a b (top), @a width wide.
func _ramp(a: Vector3, b: Vector3, width: float) -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	var d := b - a
	sh.size = Vector3(width, 0.12, d.length())
	cs.shape = sh
	sb.add_child(cs)
	root.add_child(sb)
	sb.position = (a + b) / 2 - Vector3(0, 0.06, 0)
	sb.look_at_from_position(sb.position, sb.position + d, Vector3.UP)

## Stairs: wooden steps you see and a slope you walk on.
func _stairs(a: Vector3, b: Vector3, width: float, mat: Material) -> void:
	_ramp(a, b, width)
	var d := b - a
	# the navigation mesh does not always take a steep narrow ramp: a link from the foot
	# to the top tells the aliens the way up (they still walk the ramp physically)
	var flat0 := Vector3(d.x, 0, d.z).normalized()
	var link := NavigationLink3D.new()
	link.bidirectional = true
	link.start_position = a - flat0 * 0.7 + Vector3(0, 0.05, 0)
	link.end_position = b + flat0 * 0.7 + Vector3(0, 0.05, 0)
	root.add_child(link)
	var steps := maxi(4, int(round(d.y / 0.2)))
	var flat := Vector3(d.x, 0, d.z)
	var yaw := atan2(flat.x, flat.z)
	for i in steps:
		var k := (i + 0.5) / steps
		var p := a + Vector3(flat.x * k, 0, flat.z * k)
		var top := d.y * (i + 1) / steps
		box(p + Vector3(0, top / 2, 0), Vector3(width, top, flat.length() / steps + 0.02), mat, false, yaw)

func _house(o: Vector3) -> void:
	_ground(o, "grass")
	var c := o + Vector3(2, 0, 3)
	var w := 8.0
	var d := 6.0
	var h := 3.0
	var m := Game.mat("plaster")
	box(c + Vector3(w / 2, 0.05, d / 2), Vector3(w, 0.1, d), Game.mat("planks", 0.5), false)
	_wall(c, w, true, h, m, [[3.0, 4.2], [0.9, 1.9, 0.9], [6.1, 7.1, 0.9]], "brick")
	_wall(c + Vector3(0, 0, d), w, true, h, m, [[1.5, 2.7], [5.5, 6.5, 0.9], [3.6, 4.6, 0.9]], "brick")
	_wall(c, d, false, h, m, [[2.5, 3.5]], "brick")
	_wall(c + Vector3(w, 0, 0), d, false, h, m, [[3.5, 4.5, 0.9]], "brick")
	_wall(c + Vector3(4.6, 0, 0), d, false, h, Game.mat("wallpaper", 1.0), [[2.0, 3.2]], "wood")
	box(c + Vector3(w / 2, h + 0.05, d / 2), Vector3(w, 0.1, d), Game.mat("planks", 0.5), false)    # ceiling
	_prop("house_roof", c + Vector3(w / 2, h, d / 2), 0.0, false)
	# the living room: sofa, the TV still on, a bookshelf, a rug; the kitchen across the wall
	_rug(c + Vector3(6.3, 0, 3.0), Vector2(2.4, 1.8), Color(0.5, 0.15, 0.12))
	box(c + Vector3(6.3, 0.25, 3.0), Vector3(1.0, 0.5, 0.6), Game.mat("planks", 1.0), false)
	_sofa(c + Vector3(6.3, 0, 4.9), 0.0, Color(0.55, 0.3, 0.35))
	_tv_unit(c + Vector3(6.3, 0, 0.45), PI)
	_bookshelf(c + Vector3(7.6, 0, 2.2), PI / 2)
	_kitchen(c + Vector3(0.45, 0, 4.4), false, 1.2)
	# the yard: a well, firewood, washing on the line or the hen house
	_prop("well", o + Vector3(1.0, 0, 10.9), rng.randf() * TAU)
	_prop("woodpile", o + Vector3(11.2, 0, 6.0), PI / 2)
	if rng.randf() < 0.5:
		_prop("laundry", o + Vector3(6.5, 0, 10.9), 0.0, false)
	else:
		_prop("coop", o + Vector3(6.5, 0, 10.8), PI)
	# the kitchen: table knocked over, a chair in the doorway, the lamp still on
	var t := box(c + Vector3(2.0, 0.45, 2.6), Vector3(1.6, 0.08, 1.0), Game.mat("planks", 1.0), false, 0.4)
	t.rotation.z = 1.35
	box(c + Vector3(3.6, 0.25, 0.6), Vector3(0.45, 0.5, 0.45), Game.mat("planks", 1.0), false, 0.7).rotation.x = 1.5
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.78, 0.5)
	lamp.light_energy = 1.1
	lamp.omni_range = 5.5
	lamp.shadow_enabled = true
	root.add_child(lamp)
	lamp.position = c + Vector3(2.0, 2.5, 3.0)
	lamp.set_meta("base", 1.1)
	info["elec_lights"].append(lamp)
	var bulb := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.08; sm.height = 0.16
	bulb.mesh = sm
	bulb.material_override = Game.color_mat(Color(1.0, 0.85, 0.6), true)
	root.add_child(bulb)
	bulb.position = lamp.position
	lamp.set_meta("lens", bulb)
	info["house"] = c + Vector3(3.6, 0, -1.5)
	# outside: an empty kennel and a snapped chain
	var k := c + Vector3(-1.2, 0, -1.6)
	box(k + Vector3(0, 0.45, 0), Vector3(0.9, 0.9, 1.1), Game.mat("planks", 1.0))
	box(k + Vector3(0, 0.25, -0.56), Vector3(0.4, 0.5, 0.02), Game.color_mat(Color(0.02, 0.02, 0.02)), false)
	box(k + Vector3(0.3, 0.03, -1.1), Vector3(0.04, 0.04, 0.9), Game.color_mat(Color(0.4, 0.4, 0.42)), false, 0.3)
	_cover(c + Vector3(3.6, 0, -1.0)); _cover(c + Vector3(1.0, 0, 1.0)); _cover(c + Vector3(6.5, 0, 4.5))
	info["waypoints"].append(c + Vector3(2, 0, 3))
	info["waypoints"].append(c + Vector3(6, 0, 1.5))
	info["vip_spots"].append(c + Vector3(6.5, 0.3, 5.0))

## The village green: the chapel, a lamp, the bus stop, a cross.
func _chapel(o: Vector3) -> void:
	_ground(o, "grass")
	_grass(o, 500)
	_prop("chapel", o + Vector3(BLOCK / 2, 0, BLOCK / 2 + 1.0), 0.0)
	_prop("cross", o + Vector3(2.0, 0, 2.5), 0.3)
	var lp := o + Vector3(BLOCK - 2.0, 0, 2.0)
	cyl(lp + Vector3(0, 2.0, 0), 0.06, 0.08, 4.0, Game.color_mat(Color(0.15, 0.16, 0.17)), true, 6)
	var lens := box(lp + Vector3(0, 4.0, 0), Vector3(0.4, 0.1, 0.25), Game.color_mat(Color(1.0, 0.85, 0.55), true), false)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.75, 0.45)
	l.light_energy = 1.4
	l.omni_range = 9.0
	root.add_child(l)
	l.position = lp + Vector3(0, 3.8, 0)
	l.set_meta("base", 1.4)
	l.set_meta("lens", lens)
	info["elec_lights"].append(l)
	# the bell rings by itself now and then
	info["sounds"].append({"name": "creak", "pos": o + Vector3(BLOCK / 2, 5.0, BLOCK / 2), "db": -16.0})
	info["waypoints"].append(o + Vector3(BLOCK / 2, 0, 2.0))

func _barn(o: Vector3) -> void:
	_ground(o, "dirt")
	var c := o + Vector3(1, 0, 2)
	var w := 10.0
	var d := 8.0
	var h := 4.5
	var m := Game.mat("barn")
	_wall(c, w, true, h, m, [[3.5, 6.5]], "wood")
	_wall(c + Vector3(0, 0, d), w, true, h, m, [[4.0, 5.2]], "wood")
	_wall(c, d, false, h, m, [], "wood")
	_wall(c + Vector3(w, 0, 0), d, false, h, m, [[3.0, 4.2]], "wood")
	var bceil := box(c + Vector3(w / 2, h + 0.05, d / 2), Vector3(w, 0.1, d), Game.mat("planks", 0.5), false)
	var br := _prop("house_roof", c + Vector3(w / 2, h, d / 2), 0.0, false)
	br.scale = Vector3(w / 8.0, 1.2, d / 6.0)
	_wood_roof(br, c, w, d)
	_wood_roof(bceil, c, w, d)
	if rng.randf() < 0.6:
		_prop("tractor", c + Vector3(w + 2.4, 0, d - 0.6), rng.randf_range(-0.3, 0.3))    # off the side door
	for i in 3:
		box(c + Vector3([1.2, 2.7, w - 1.3][i], 0.6, d - 1.5), Vector3(1.4, 1.2, 1.4), Game.mat("hay", 1.0))    # by the walls, not in the doorway
	_cover(c + Vector3(3.0, 0, d - 3.0)); _cover(c + Vector3(7.5, 0, 2.0))
	info["waypoints"].append(c + Vector3(w / 2, 0, d / 2))
	# a handheld radio on the floor - someone called for help from here
	var r := c + Vector3(6.5, 0, 5.0)
	box(r + Vector3(0, 0.08, 0), Vector3(0.12, 0.16, 0.06), Game.color_mat(Color(0.1, 0.1, 0.1)), false, 0.6)
	box(r + Vector3(0.03, 0.22, 0), Vector3(0.015, 0.14, 0.015), Game.color_mat(Color(0.1, 0.1, 0.1)), false)
	var led := OmniLight3D.new()
	led.light_color = Color(1.0, 0.2, 0.1)
	led.light_energy = 0.4
	led.omni_range = 1.2
	root.add_child(led)
	led.position = r + Vector3(0, 0.25, 0)
	info["sounds"].append({"name": "static", "pos": r + Vector3(0, 0.2, 0), "db": -18.0})
	info["barn"] = r

# ---- new tiles (0.23): two floors, ruins, gardens, creeks, industry, mountains, a fuel station ----
func _lamp(p: Vector3, energy := 1.1, rng_ := 5.5, col := Color(1.0, 0.78, 0.5)) -> void:
	var lamp := OmniLight3D.new()
	lamp.light_color = col
	lamp.light_energy = energy
	lamp.omni_range = rng_
	lamp.shadow_enabled = true
	root.add_child(lamp)
	lamp.position = p
	lamp.set_meta("base", energy)
	info["elec_lights"].append(lamp)
	var bulb := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.08; sm.height = 0.16
	bulb.mesh = sm
	bulb.material_override = Game.color_mat(Color(1.0, 0.85, 0.6), true)
	root.add_child(bulb)
	bulb.position = p
	lamp.set_meta("lens", bulb)

func _crate(p: Vector3, sz := 1.0, yaw := 0.0) -> void:
	sz = maxf(sz, 0.85)
	var b := box(p + Vector3(0, sz / 2, 0), Vector3(sz, sz, sz), Game.mat("planks", 1.0), true, yaw)
	_breakable(b, "crate")

func _hedge(a: Vector3, length: float, along_x: bool) -> void:
	var m := Game.mat("leaves", 0.5)
	var seg := 0.0
	while seg < length - 0.5:
		var l := minf(rng.randf_range(2.0, 4.0), length - seg)
		var mid := seg + l / 2
		var h := rng.randf_range(1.3, 1.8)
		var p := a + (Vector3(mid, h / 2, 0) if along_x else Vector3(0, h / 2, mid))
		box(p, Vector3(l, h, 0.9) if along_x else Vector3(0.9, h, l), m)
		seg += l + (rng.randf_range(0.9, 1.5) if rng.randf() < 0.35 else 0.0)    # gaps to slip through
		_cover(p + (Vector3(0, -h / 2, 1.0) if along_x else Vector3(1.0, -h / 2, 0)))

## Two floors: kitchen and living room below, bedrooms above; the stairs run along the
## right wall. Upstairs windows look far over the fields.
func _house2(o: Vector3) -> void:
	_ground(o, "grass")
	var c := o + Vector3(1.8, 0, 2.2)
	var w := 8.4
	var d := 8.0
	var h := 3.0
	var m := Game.mat("brick" if rng.randf() < 0.5 else "plaster", 0.5 if rng.randf() < 0.5 else 1.0)
	var fl := Game.mat("planks", 0.5)
	box(c + Vector3(w / 2, 0.05, d / 2), Vector3(w, 0.1, d), fl, false)
	# ground floor
	_wall(c, w, true, h, m, [[3.0, 4.2], [1.0, 2.0, 0.9], [5.6, 6.6, 0.9]], "brick")
	_wall(c + Vector3(0, 0, d), w, true, h, m, [[1.5, 2.6], [4.5, 5.5, 0.9]], "brick")
	_wall(c, d, false, h, m, [[2.5, 3.5, 0.9]], "brick")
	_wall(c + Vector3(w, 0, 0), d, false, h, m, [], "brick")
	_wall(c + Vector3(4.6, 0, 0), d, false, h, Game.mat("wallpaper", 1.0), [[2.0, 3.5]], "wood")
	# upper floor: slab with a stairwell along the right wall
	var sw := 1.95          # wide enough that the aliens find their way up too
	var z0 := 1.7
	var run := h / 0.62
	# (thick slabs: the navigation voxels lose floors thinner than a voxel)
	box(c + Vector3((w - sw) / 2, h - 0.05, d / 2), Vector3(w - sw, 0.3, d), fl)
	box(c + Vector3(w - sw / 2, h - 0.05, z0 / 2), Vector3(sw, 0.3, z0), fl)
	box(c + Vector3(w - sw / 2, h - 0.05, (z0 + run + d) / 2), Vector3(sw, 0.3, d - z0 - run), fl)
	_stairs(c + Vector3(w - sw / 2 - 0.1, 0.0, z0), c + Vector3(w - sw / 2 - 0.1, h + 0.1, z0 + run), sw - 0.2, Game.mat("planks", 1.0))
	box(c + Vector3(w - sw - 0.05, h + 0.55, z0 + run / 2), Vector3(0.08, 0.9, run), Game.mat("planks", 1.0), false)    # banister
	var up := c + Vector3(0, h, 0)
	_wall(up, w, true, h, m, [[1.0, 2.0, 0.9], [3.2, 4.2, 0.9], [5.6, 6.6, 0.9]], "brick")
	_wall(up + Vector3(0, 0, d), w, true, h, m, [[1.5, 2.5, 0.9], [4.5, 5.5, 0.9]], "brick")
	_wall(up, d, false, h, m, [[2.5, 3.5, 0.9]], "brick")
	_wall(up + Vector3(w, 0, 0), d, false, h, m, [[3.5, 4.5, 0.9]], "brick")
	_wall(up + Vector3(0, 0, 3.6), w - sw - 0.1, true, h, Game.mat("wallpaper", 1.0), [[2.0, 3.4]], "wood")
	box(c + Vector3(w / 2, 2 * h + 0.05, d / 2), Vector3(w, 0.1, d), fl, false)
	var rf := _prop("house_roof", c + Vector3(w / 2, 2 * h, d / 2), 0.0, false)
	rf.scale = Vector3(w / 8.0, 1.0, d / 6.0)
	# furniture: kitchen table, sofa, wardrobe and beds upstairs
	box(c + Vector3(2.0, 0.4, 2.2), Vector3(1.6, 0.8, 1.0), Game.mat("planks", 1.0))
	box(c + Vector3(6.4, 0.4, d - 1.0), Vector3(2.0, 0.8, 0.9), Game.color_mat(Color(0.32, 0.2, 0.16)))
	box(up + Vector3(0.6, 1.0, 1.8), Vector3(0.6, 2.0, 1.4), Game.mat("planks", 1.0))
	box(up + Vector3(2.4, 0.25, 1.2), Vector3(1.6, 0.5, 2.0), Game.color_mat(Color(0.5, 0.48, 0.42)), false)
	box(up + Vector3(3.0, 0.25, d - 1.4), Vector3(2.0, 0.5, 1.6), Game.color_mat(Color(0.45, 0.4, 0.45)), false)
	_lamp(c + Vector3(2.0, 2.5, 3.0))
	_lamp(up + Vector3(3.0, 2.5, 5.0), 0.8)
	_kitchen(c + Vector3(0.45, 0, 5.0), false, 2.0)
	_rug(c + Vector3(2.0, 0, 2.2), Vector2(2.6, 1.8), Color(0.25, 0.3, 0.5))
	_rug(up + Vector3(3.0, 0.0, 5.8), Vector2(2.0, 1.4), Color(0.5, 0.35, 0.2))
	_prop("woodpile", o + Vector3(11.2, 0, 6.0), PI / 2)
	_cover(c + Vector3(3.6, 0, -1.0)); _cover(c + Vector3(1.0, 0, 1.0)); _cover(up + Vector3(2.0, 0.1, 1.0)); _cover(up + Vector3(6.0, 0.1, 5.5))
	info["waypoints"].append(c + Vector3(2, 0, 3))
	info["waypoints"].append(up + Vector3(3, 0.1, 5.5))
	info["alien_spawns"].append(up + Vector3(2.0, 0.3, 5.5))
	info["vip_spots"].append(up + Vector3(1.5, 0.3, d - 1.2))
	if info["house"] == Vector3.ZERO:
		info["house"] = c + Vector3(3.6, 0, -1.5)

## A burnt-out house: broken walls of every height, rubble, no roof. Good cover, bad memories.
func _ruin(o: Vector3) -> void:
	_ground(o, "dirt")
	_grass(o, 400, "dry", 0.4, 1.0)
	var c := o + Vector3(2, 0, 2.5)
	var m := Game.mat("brick" if rng.randf() < 0.5 else "plaster", 1.0)
	var w := 8.0
	var d := 7.0
	for side in 4:
		var n := rng.randi_range(2, 4)
		var length := w if side < 2 else d
		for k in n:
			var a := length * k / n
			var l := length / n * rng.randf_range(0.5, 1.0)
			var hh := rng.randf_range(0.8, 2.8)
			if rng.randf() < 0.2:
				continue
			var st := c + (Vector3(a, 0, 0 if side == 0 else d) if side < 2 else Vector3(0 if side == 2 else w, 0, a))
			_wall(st, l, side < 2, hh, m, [], "brick")
	for i in 7:
		var p := c + Vector3(rng.randf_range(0.5, w - 0.5), 0, rng.randf_range(0.5, d - 0.5))
		var sz := Vector3(rng.randf_range(0.5, 1.4), rng.randf_range(0.3, 1.1), rng.randf_range(0.5, 1.2))
		box(p + Vector3(0, sz.y / 2, 0), sz, m, sz.y > 0.8, rng.randf() * PI)
	# a fallen roof beam
	var bm := box(c + Vector3(w / 2, 0.9, d / 2), Vector3(0.3, 0.3, 6.0), Game.mat("scorch", 1.0), true, rng.randf_range(-0.6, 0.6))
	bm.rotation.x = 0.28
	box(c + Vector3(w / 2, 0.03, d / 2), Vector3(w, 0.03, d), Game.mat("scorch", 0.6), false)
	# it still burns in places
	for f in rng.randi_range(1, 2):
		var fp := c + Vector3(rng.randf_range(1.0, w - 1.0), 0.2, rng.randf_range(1.0, d - 1.0))
		var fire := OmniLight3D.new()
		fire.light_color = Color(1.0, 0.45, 0.12)
		fire.light_energy = 1.8
		fire.omni_range = 5.0
		fire.set_meta("flicker", true)
		root.add_child(fire)
		fire.position = fp + Vector3(0, 0.5, 0)
		info["lights"].append(fire)
		var fl := CPUParticles3D.new()
		fl.amount = 24
		fl.lifetime = 0.9
		fl.direction = Vector3.UP
		fl.spread = 15.0
		fl.initial_velocity_min = 0.6
		fl.initial_velocity_max = 1.4
		fl.gravity = Vector3(0, 0.5, 0)
		fl.scale_amount_min = 0.6
		fl.scale_amount_max = 1.2
		var fq := QuadMesh.new()
		fq.size = Vector2(0.3, 0.4)
		var fmat := StandardMaterial3D.new()
		fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fmat.albedo_color = Color(1.0, 0.55, 0.15, 0.8)
		fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		fq.material = fmat
		fl.mesh = fq
		root.add_child(fl)
		fl.position = fp
		info["sounds"].append({"name": "fire", "pos": fp, "db": -16.0})
	if rng.randf() < 0.6:
		# a burnt-out car in front
		box(o + Vector3(rng.randf_range(3, 9), 0.6, 10.8), Vector3(4.2, 0.9, 1.8), Game.mat("scorch", 1.0), true, rng.randf_range(-0.3, 0.3))
	_cover(c + Vector3(1.0, 0, 1.0)); _cover(c + Vector3(w - 1.0, 0, d - 1.0)); _cover(c + Vector3(w / 2, 0, -0.8))
	info["vip_spots"].append(c + Vector3(1.2, 0.3, d - 1.2))
	info["waypoints"].append(c + Vector3(w / 2, 0, d / 2))

## A garden: shed, vegetable beds, a hedge and a picket fence.
func _garden(o: Vector3) -> void:
	if terrain == "desert":
		_dunes(o)      # no meadows, cows or trees in the sand
		return
	_ground(o, "grass")
	_grass(o, 500)
	var s := o + Vector3(1.0, 0, 1.0)
	var pl := Game.mat("planks", 1.0)
	_wall(s, 3.2, true, 2.3, pl, [[1.1, 2.0]], "wood")
	_wall(s + Vector3(0, 0, 2.6), 3.2, true, 2.3, pl, [], "wood")
	_wall(s, 2.6, false, 2.3, pl, [], "wood")
	_wall(s + Vector3(3.2, 0, 0), 2.6, false, 2.3, pl, [[0.8, 1.6, 1.0]], "wood")
	box(s + Vector3(1.6, 2.35, 1.3), Vector3(3.6, 0.1, 3.0), Game.mat("roof", 1.0), false)
	for i in 4:
		box(o + Vector3(6.0 + (i % 2) * 2.8, 0.15, 2.0 + (i / 2) * 3.0), Vector3(2.0, 0.3, 1.4), Game.mat("dirt", 1.0), false)
	_hedge(o + Vector3(0.6, 0, 9.8), 11.0, true)
	var f := Game.mat("fence", 1.0)
	for k in 5:
		if k == 2:
			continue
		var fb := box(o + Vector3(11.4, 0.45, 1.2 + k * 1.9), Vector3(0.08, 0.9, 1.8), f)
		_breakable(fb, "wood")
	_crate(o + Vector3(4.7, 0, 1.4), 0.8)
	_cover(s + Vector3(1.6, 0, -0.8)); _cover(o + Vector3(8.0, 0, 6.0))
	info["vip_spots"].append(s + Vector3(0.8, 0.3, 1.8))
	info["waypoints"].append(o + Vector3(7, 0, 6))

## Orchard: rows of low fruit trees, a ladder against one, crates of apples.
func _orchard(o: Vector3) -> void:
	if terrain == "desert":
		_dunes(o)      # no meadows, cows or trees in the sand
		return
	_ground(o, "grass")
	_grass(o, 700, "dry", 0.4, 0.9)
	for ix in 3:
		for iz in 3:
			var p := o + Vector3(2.2 + ix * 3.8 + rng.randf_range(-0.4, 0.4), 0, 2.2 + iz * 3.8 + rng.randf_range(-0.4, 0.4))
			var th := rng.randf_range(1.4, 1.9)
			cyl(p + Vector3(0, th / 2, 0), 0.12, 0.17, th, Game.mat("bark", 1.0), true, 6)
			var crown := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = rng.randf_range(1.2, 1.6); sm.height = sm.radius * 1.6
			sm.radial_segments = 8; sm.rings = 4
			crown.mesh = sm
			crown.material_override = Game.mat("leaves", 0.6)
			root.add_child(crown)
			crown.position = p + Vector3(0, th + sm.radius * 0.55, 0)
	for i in 3:
		_crate(_jit(o, 1.0), 0.6, rng.randf() * PI)
	if rng.randf() < 0.5:
		_hedge(o + Vector3(0.3, 0, 0.4), 11.4, true)
	info["waypoints"].append(o + Vector3(BLOCK / 2, 0, BLOCK / 2))

## A creek across the block: dark water, stones on the banks, reeds, a plank footbridge.
func _stream(o: Vector3) -> void:
	_ground(o, "grass")
	var along_x := rng.randf() < 0.5
	var mid := BLOCK / 2 + rng.randf_range(-1.5, 1.5)
	var wpos := o + (Vector3(BLOCK / 2, 0.035, mid) if along_x else Vector3(mid, 0.035, BLOCK / 2))
	box(wpos, Vector3(BLOCK, 0.02, 2.6) if along_x else Vector3(2.6, 0.02, BLOCK), Game.mat("water", 0.4, Color(0.02, 0.05, 0.06)), false)
	box(wpos - Vector3(0, 0.02, 0), Vector3(BLOCK, 0.02, 3.4) if along_x else Vector3(3.4, 0.02, BLOCK), Game.mat("dirt", 0.5), false)
	for i in 10:
		var t := rng.randf_range(0.5, BLOCK - 0.5)
		var side := 1.6 if rng.randf() < 0.5 else -1.6
		var p := o + (Vector3(t, 0, mid + side) if along_x else Vector3(mid + side, 0, t))
		var r := rng.randf_range(0.2, 0.6)
		cyl(p + Vector3(0, r * 0.4, 0), r * 0.6, r, r * 0.8, Game.mat("rock", 0.6), r > 0.4, 6)
	_grass(o, 900, "dry", 0.8, 1.6)
	# footbridge
	var bp := o + (Vector3(rng.randf_range(3, 9), 0.12, mid) if along_x else Vector3(mid, 0.12, rng.randf_range(3, 9)))
	box(bp, Vector3(1.4, 0.1, 4.2) if along_x else Vector3(4.2, 0.1, 1.4), Game.mat("planks", 1.0))
	for sd in [-0.7, 0.7]:
		box(bp + (Vector3(sd, 0.5, 0) if along_x else Vector3(0, 0.5, sd)), Vector3(0.06, 0.06, 4.2) if along_x else Vector3(4.2, 0.06, 0.06), Game.mat("planks", 1.0), false)
	info["sounds"].append({"name": "rain", "pos": wpos, "db": -26.0})
	info["waypoints"].append(bp)

## A cluster of boulders between the pines.
func _rocks(o: Vector3) -> void:
	_ground(o, "grass")
	for i in rng.randi_range(4, 7):
		var p := _jit(o, 1.2)
		var r := rng.randf_range(0.6, 1.8)
		var rk := cyl(p + Vector3(0, r * 0.45, 0), r * rng.randf_range(0.4, 0.8), r, r * rng.randf_range(0.8, 1.4), Game.mat("rock", 0.5), true, 6)
		rk.rotation.y = rng.randf() * PI
		_cover(p + Vector3(r + 0.6, 0, 0)); _cover(p + Vector3(-r - 0.6, 0, 0))
	for i in (0 if terrain == "desert" else rng.randi_range(2, 4)):
		var p2 := _jit(o, 1.0)
		var h := rng.randf_range(5.0, 8.0)
		cyl(p2 + Vector3(0, h / 2, 0), 0.15, 0.28, h, Game.mat("bark", 1.0), true, 6)
		cyl(p2 + Vector3(0, h * 0.55, 0), 0.0, 1.8, h * 0.7, Game.mat("leaves", 0.6), false, 7)
	_grass(o, 600, "dry", 0.4, 1.0)
	info["waypoints"].append(o + Vector3(BLOCK / 2, 0, BLOCK / 2))

## A mountain cabin: log walls, a porch, a sleeping loft up a ladder-steep stair.
func _cabin(o: Vector3) -> void:
	_ground(o, "grass")
	var c := o + Vector3(1.2, 0, 2.5)
	var w := 8.0
	var d := 7.0
	var h := 2.6
	var m := Game.mat("bark", 0.6)
	box(c + Vector3(w / 2, 0.05, d / 2), Vector3(w, 0.1, d), Game.mat("planks", 0.5), false)
	_wall(c, w, true, h, m, [[2.6, 4.0], [0.8, 1.7, 0.9], [5.0, 6.0, 0.9]], "wood")
	_wall(c + Vector3(0, 0, d), w, true, h, m, [[3.0, 4.0, 0.9]], "wood")
	_wall(c, d, false, h, m, [[2.5, 3.4, 0.9]], "wood")
	_wall(c + Vector3(w, 0, 0), d, false, h, m, [[1.0, 2.4]], "wood")
	# loft over the back half
	box(c + Vector3(w / 2, h - 0.05, d * 0.75), Vector3(w, 0.3, d / 2), Game.mat("planks", 0.5))
	# stairs along the loft edge, a landing at the top
	var run := (h + 0.1) / 0.62
	_stairs(c + Vector3(1.7, 0, d / 2 - 0.9), c + Vector3(1.7 + run, h + 0.1, d / 2 - 0.9), 1.7, Game.mat("planks", 1.0))
	box(c + Vector3((1.7 + run + w) / 2, h - 0.05, d / 2 - 0.9), Vector3(w - 1.7 - run, 0.3, 1.8), Game.mat("planks", 0.5))
	# a gable roof over the whole cabin (the loft sits under it) - it used to be a flat slab
	# on half-height walls at the back, hanging over the front half with nothing under it
	var up := c + Vector3(0, h, 0)
	var cr := _prop("house_roof", c + Vector3(w / 2, h, d / 2), 0.0, false)
	cr.scale = Vector3(w / 8.0, 1.0, d / 6.0)
	_wood_roof(cr, c, w, d)
	# porch
	box(c + Vector3(w / 2, 0.15, -1.0), Vector3(w, 0.1, 1.8), Game.mat("planks", 1.0))
	for px in [0.3, w - 0.3]:
		cyl(c + Vector3(px, 1.2, -1.8), 0.08, 0.08, 2.4, Game.mat("bark", 1.0), true, 6)
	box(c + Vector3(w / 2, 2.45, -1.0), Vector3(w + 0.4, 0.1, 2.2), Game.mat("roof", 1.0), false)
	box(c + Vector3(w - 1.0, 0.45, d - 1.0), Vector3(1.2, 0.9, 0.8), Game.mat("planks", 1.0))
	_lamp(c + Vector3(w / 2, 2.2, 2.0), 0.9)
	_prop("woodpile", c + Vector3(w + 1.2, 0, 2.0), PI / 2)
	_cover(c + Vector3(w / 2, 0, -2.4)); _cover(up + Vector3(3.0, 0.1, d * 0.75))
	info["waypoints"].append(c + Vector3(w / 2, 0, 2.0))
	info["waypoints"].append(up + Vector3(4.0, 0.1, d * 0.75))
	info["vip_spots"].append(up + Vector3(2.0, 0.3, d - 0.9))

## A warehouse: a tall hall of corrugated sheet, crates and shelves inside, a gallery along
## the back wall up a steel stair.
func _warehouse(o: Vector3) -> void:
	_ground(o, "concrete")
	var c := o + Vector3(0.5, 0, 1.5)
	var w := 11.0
	var d := 9.0
	var h := 6.0
	var m := Game.mat("corrugated", 0.5)
	_wall(c, w, true, h, m, [[3.5, 7.5], [9.0, 10.0]], "metal")
	_wall(c + Vector3(0, 0, d), w, true, h, m, [[1.0, 2.5]], "metal")
	_wall(c, d, false, h, m, [], "metal")      # (half a metre from the next block: a door here led into its wall)
	_wall(c + Vector3(w, 0, 0), d, false, h, m, [[5.0, 6.0, 1.6]], "metal")
	box(c + Vector3(w / 2, h + 0.05, d / 2), Vector3(w + 0.4, 0.1, d + 0.4), m, false)
	_trusses(c, w, d, h)
	# gallery at 3 m along the back wall
	var gy := 3.0
	var gd := 2.4
	box(c + Vector3(w / 2, gy - 0.09, d - gd / 2), Vector3(w - 0.3, 0.3, gd), Game.mat("metal", 0.5))
	box(c + Vector3(w / 2 - 1.0, gy + 0.55, d - gd), Vector3(w - 4.5, 1.0, 0.06), Game.mat("metal", 0.5))
	_stairs(c + Vector3(w - 1.1, 0, d - gd - 4.6), c + Vector3(w - 1.1, gy + 0.06, d - gd), 1.8, Game.mat("metal", 0.5))
	for ix in 3:
		cyl(c + Vector3(1.5 + ix * 4.0, gy / 2, d - gd), 0.1, 0.1, gy, Game.mat("metal", 0.5), true, 6)
	# crates, pallets, shelves
	# crates on the left, a clear lane from the big door to the stairs on the right
	for i in 6:
		var p := c + Vector3(rng.randf_range(2.3, 3.4), 0, rng.randf_range(1.8, d - gd - 0.8))    # clear of the side door
		_crate(p, rng.randf_range(0.8, 1.2), rng.randf() * 0.5)
		if rng.randf() < 0.4:
			_crate(p + Vector3(0, 1.0, 0), 0.8)
	for i in 3:
		_crate(c + Vector3(rng.randf_range(4.5, 7.5), 0, rng.randf_range(3.5, 5.5)), 0.9, rng.randf() * 0.5)
	box(c + Vector3(0.5, 1.4, 6.6), Vector3(0.7, 2.8, 3.2), Game.mat("metal", 0.5))    # the shelf beside the side door, not in it
	_crate(c + Vector3(0.7, gy + 0.06, d - 0.7), 0.8)
	for lx in [3.0, 8.0]:
		_lamp(c + Vector3(lx, h - 0.6, d / 2), 1.6, 9.0, Color(0.85, 0.9, 1.0))
	_cover(c + Vector3(5.5, 0, -1.0)); _cover(c + Vector3(3.0, 0, 3.0)); _cover(c + Vector3(7.5, 0, 4.0)); _cover(c + Vector3(5.0, gy + 0.06, d - 1.2))
	info["waypoints"].append(c + Vector3(w / 2, 0, 3.0))
	info["waypoints"].append(c + Vector3(3.0, gy + 0.06, d - 1.2))
	info["alien_spawns"].append(c + Vector3(6.0, gy + 0.3, d - 1.2))
	info["vip_spots"].append(c + Vector3(2.5, gy + 0.3, d - 0.9))

## Shipping containers in rows and stacks; one stands open.
func _containers(o: Vector3) -> void:
	_ground(o, "concrete")
	var cols := ["container_red", "container_blue", "container_green"]
	for i in 3:
		var p := o + Vector3(1.8 + i * 3.6, 0, rng.randf_range(2.0, 4.0))
		var m := Game.mat(cols[rng.randi() % 3], 0.5)
		if i == 1:
			# open one: you can walk in
			box(p + Vector3(-1.2, 1.3, 3.0), Vector3(0.1, 2.6, 6.0), m)
			box(p + Vector3(1.2, 1.3, 3.0), Vector3(0.1, 2.6, 6.0), m)
			box(p + Vector3(0, 2.55, 3.0), Vector3(2.5, 0.1, 6.0), m)
			box(p + Vector3(0, 1.3, 6.0), Vector3(2.5, 2.6, 0.1), m)
			box(p + Vector3(0, 0.05, 3.0), Vector3(2.4, 0.1, 6.0), Game.mat("planks", 1.0), false)
			box(p + Vector3(-1.6, 1.3, -0.3), Vector3(0.08, 2.5, 1.1), m, false, 0.6)
			_crate(p + Vector3(0.3, 0, 4.6), 0.9)
			info["waypoints"].append(p + Vector3(0, 0, 3.0))
		else:
			box(p + Vector3(0, 1.3, 3.0), Vector3(2.5, 2.6, 6.0), m)
			if rng.randf() < 0.6:
				box(p + Vector3(0, 3.9, 3.0 + rng.randf_range(-0.3, 0.3)), Vector3(2.5, 2.6, 6.0), Game.mat(cols[rng.randi() % 3], 0.5))
		_cover(p + Vector3(1.9, 0, 1.0)); _cover(p + Vector3(-1.9, 0, 5.0))
	for i in 5:
		var dp := _jit(o, 1.0)
		if dp.z > o.z + 9.0:
			cyl(dp + Vector3(0, 0.45, 0), 0.3, 0.3, 0.9, Game.color_mat(Color(0.2, 0.3, 0.45) if i % 2 else Color(0.45, 0.15, 0.1)), true, 8)
	info["waypoints"].append(o + Vector3(BLOCK / 2, 0, 10.0))

## Fuel tanks with a pump house and pipes.
func _tanks(o: Vector3) -> void:
	_ground(o, "concrete")
	for i in 2:
		var p := o + Vector3(3.2 + i * 5.6, 0, 4.0)
		cyl(p + Vector3(0, 3.0, 0), 2.1, 2.1, 6.0, Game.mat("metal", 0.4), true, 14)
		cyl(p + Vector3(0, 6.1, 0), 0.6, 2.1, 0.4, Game.mat("metal", 0.4), false, 14)
		box(p + Vector3(2.15, 3.0, 0), Vector3(0.1, 6.0, 0.4), Game.color_mat(Color(0.3, 0.3, 0.3)), false)   # ladder
		_cover(p + Vector3(0, 0, 2.8)); _cover(p + Vector3(0, 0, -2.8))
	box(o + Vector3(3.75, 0.6, 7.5), Vector3(6.5, 0.3, 0.3), Game.mat("metal", 0.5))    # the pipe ends at the pump house wall, the door stays free
	var ph := o + Vector3(7.0, 0, 8.5)
	_wall(ph, 3.4, true, 2.5, Game.mat("concrete", 0.5), [[1.2, 2.1]], "brick")
	_wall(ph + Vector3(0, 0, 2.8), 3.4, true, 2.5, Game.mat("concrete", 0.5), [], "brick")
	_wall(ph, 2.8, false, 2.5, Game.mat("concrete", 0.5), [], "brick")
	_wall(ph + Vector3(3.4, 0, 0), 2.8, false, 2.5, Game.mat("concrete", 0.5), [[1.0, 1.8, 1.0]], "brick")
	box(ph + Vector3(1.7, 2.55, 1.4), Vector3(3.8, 0.1, 3.2), Game.mat("corrugated", 0.5), false)
	_lamp(ph + Vector3(1.7, 2.2, 1.4), 0.8, 4.0, Color(0.85, 0.95, 1.0))
	info["waypoints"].append(o + Vector3(3.0, 0, 9.5))

## The yard: chain-link fence, pallets, a forklift, oil drums, an abandoned car.
func _yard(o: Vector3) -> void:
	_ground(o, "concrete")
	var f := Game.mat("fence", 1.0)
	for k in 6:
		if k == 2 or k == 3:
			continue
		var fb := box(o + Vector3(0.3, 1.0, 1.0 + k * 2.0), Vector3(0.05, 2.0, 2.0), Game.color_mat(Color(0.45, 0.47, 0.5)))
		_breakable(fb, "wood")
	for i in 4:
		var p := _jit(o, 2.0)
		box(p + Vector3(0, 0.1, 0), Vector3(1.2, 0.2, 1.0), f, false, rng.randf() * 0.4)
		if rng.randf() < 0.6:
			_crate(p + Vector3(0, 0.2, 0), 0.9)
	# forklift
	var fp := o + Vector3(rng.randf_range(4, 8), 0, rng.randf_range(4, 8))
	var yaw := rng.randf() * TAU
	box(fp + Vector3(0, 0.7, 0), Vector3(1.2, 1.0, 2.0), Game.color_mat(Color(0.75, 0.55, 0.1)), true, yaw)
	box(fp + Vector3(0, 1.7, 0.2), Vector3(1.1, 0.08, 1.2), Game.color_mat(Color(0.1, 0.1, 0.1)), false, yaw)
	_cover(fp + Vector3(1.5, 0, 0))
	for i in 4:
		var dp := _jit(o, 1.0)
		cyl(dp + Vector3(0, 0.45, 0), 0.3, 0.3, 0.9, Game.color_mat(Color(0.2, 0.3, 0.45) if i % 2 else Color(0.45, 0.15, 0.1)), true, 8)
	if rng.randf() < 0.6:
		_prop(["car_blue", "car_red", "car_beige"][rng.randi() % 3], _jit(o, 3.0), rng.randf() * TAU)
	_lamp(o + Vector3(BLOCK - 1.0, 4.0, 1.0), 1.3, 10.0, Color(1.0, 0.8, 0.5))
	cyl(o + Vector3(BLOCK - 1.0, 2.0, 1.0), 0.07, 0.09, 4.0, Game.color_mat(Color(0.15, 0.16, 0.17)), true, 6)
	info["waypoints"].append(o + Vector3(BLOCK / 2, 0, BLOCK / 2))

## A fuel station by the road: canopy, two pumps, a little shop with a glass front.
func _fuel(o: Vector3) -> void:
	_ground(o, "asphalt")
	var cp := o + Vector3(4.0, 0, 6.0)
	box(cp + Vector3(0, 4.2, 0), Vector3(7.0, 0.35, 5.0), Game.color_mat(Color(0.85, 0.85, 0.8)), false)
	box(cp + Vector3(0, 4.0, 2.52), Vector3(7.0, 0.3, 0.05), Game.color_mat(Color(0.8, 0.15, 0.1), true), false)
	for px in [-3.0, 3.0]:
		for pz in [-2.0, 2.0]:
			box(cp + Vector3(px, 2.0, pz), Vector3(0.3, 4.0, 0.3), Game.color_mat(Color(0.8, 0.8, 0.78)))
	for px2 in [-1.2, 1.2]:
		box(cp + Vector3(px2, 0.15, 0), Vector3(1.0, 0.3, 2.6), Game.mat("concrete", 0.5))
		box(cp + Vector3(px2, 1.0, 0), Vector3(0.6, 1.6, 0.4), Game.color_mat(Color(0.75, 0.12, 0.1)))
		_cover(cp + Vector3(px2, 0, 1.6))
	var lt := SpotLight3D.new()
	lt.light_color = Color(0.95, 0.97, 1.0)
	lt.light_energy = 2.0
	lt.spot_range = 7.0
	lt.spot_angle = 60.0
	root.add_child(lt)
	lt.position = cp + Vector3(0, 4.0, 0)
	lt.rotation.x = -PI / 2
	lt.set_meta("base", 2.0)
	lt.set_meta("lens", box(cp + Vector3(0, 4.0, 0), Vector3(2.0, 0.04, 0.3), Game.color_mat(Color(0.95, 0.97, 1.0), true), false))
	info["elec_lights"].append(lt)
	# the shop
	var s := o + Vector3(8.0, 0, 1.0)
	var m := Game.mat("plaster", 1.0)
	box(s + Vector3(1.8, 0.05, 2.0), Vector3(3.6, 0.1, 4.0), Game.mat("tiles", 0.5), false)
	_wall(s, 3.6, true, 3.0, m, [], "brick")
	_wall(s + Vector3(0, 0, 4.0), 3.6, true, 3.0, m, [], "brick")
	_wall(s, 4.0, false, 3.0, m, [[0.3, 1.3, 0.6], [1.8, 2.8]], "brick")    # the door clear of the canopy pillar
	_wall(s + Vector3(3.6, 0, 0), 4.0, false, 3.0, m, [], "brick")
	box(s + Vector3(1.8, 3.05, 2.0), Vector3(3.8, 0.1, 4.2), Game.mat("roof", 1.0), false)
	box(s + Vector3(1.4, 0.5, 1.2), Vector3(0.6, 1.0, 1.8), Game.mat("planks", 1.0))
	box(s + Vector3(2.2, 0.9, 3.65), Vector3(2.2, 1.8, 0.4), Game.mat("metal", 0.5))
	_lamp(s + Vector3(1.8, 2.7, 2.0), 0.9, 4.5, Color(0.9, 0.95, 1.0))
	_cover(s + Vector3(-1.0, 0, 3.8)); _cover(s + Vector3(1.4, 0, 2.4))
	info["vip_spots"].append(s + Vector3(2.6, 0.3, 0.8))
	info["waypoints"].append(cp)
	info["waypoints"].append(s + Vector3(2.6, 0, 1.6))

# ---- our base in the ravine (base defence missions) -------------------------------------------
## Steel roof trusses: a top and bottom chord with zig-zag struts, every few metres.
func _trusses(c: Vector3, w: float, d: float, h: float) -> void:
	var st := Game.color_mat(Color(0.18, 0.19, 0.21))
	var n := int(d / 2.5)
	for i in n:
		var z := (i + 0.5) * d / n
		box(c + Vector3(w / 2, h - 0.12, z), Vector3(w, 0.12, 0.12), st, false)
		box(c + Vector3(w / 2, h - 0.95, z), Vector3(w, 0.1, 0.1), st, false)
		var segs := int(w / 1.2)
		for k in segs:
			var x := (k + 0.5) * w / segs
			var strut := box(c + Vector3(x, h - 0.53, z), Vector3(0.08, 1.0, 0.08), st, false)
			strut.rotation.z = 0.75 if k % 2 == 0 else -0.75
	# skylights: pale strips of sky in the roof
	for i in 2:
		box(c + Vector3(w * (0.3 + i * 0.4), h - 0.02, d / 2), Vector3(1.2, 0.03, d * 0.7), Game.color_mat(Color(0.35, 0.4, 0.5), true), false)

## The hangar: a wide open gate, the Sokol on its stand, workbenches and fuel drums.
func _hangar(o: Vector3) -> void:
	_ground(o, "concrete")
	var c := o + Vector3(0.4, 0, 1.0)
	var w := 11.2
	var d := 10.0
	var h := 6.5
	var m := Game.mat("corrugated", 0.5)
	_wall(c, w, true, h, m, [[1.2, 10.0]], "metal")
	_wall(c + Vector3(0, 0, d), w, true, h, m, [[4.8, 6.4]], "metal")
	_wall(c, d, false, h, m, [[4.0, 5.4]], "metal")
	_wall(c + Vector3(w, 0, 0), d, false, h, m, [], "metal")
	box(c + Vector3(w / 2, h + 0.05, d / 2), Vector3(w + 0.4, 0.1, d + 0.4), m, false)
	box(c + Vector3(w / 2, 0.03, d / 2), Vector3(w - 0.4, 0.02, d - 0.4), Game.color_mat(Color(0.75, 0.62, 0.1)), false)   # stripes
	_trusses(c, w, d, h)
	var jet: Node3D = Game.model("sokol")
	root.add_child(jet)
	jet.position = c + Vector3(w / 2, 1.0, d / 2 + 0.5)
	jet.rotation.y = PI
	box(c + Vector3(w / 2, 0.5, d / 2 + 0.5), Vector3(2.2, 1.0, 5.5), Game.mat("metal", 0.5))   # the stand (cover)
	for i in 3:
		box(c + Vector3(1.0, 0.45, 2.5 + i * 2.4), Vector3(0.9, 0.9, 1.8), Game.mat("metal", 0.5))
	for i in 4:
		cyl(c + Vector3(w - 0.8, 0.45, 1.5 + i * 0.75), 0.3, 0.3, 0.9, Game.color_mat(Color(0.45, 0.15, 0.1)), true, 8)
	for lx in [3.0, 8.0]:
		_lamp(c + Vector3(lx, h - 0.6, d / 2), 1.6, 10.0, Color(0.85, 0.9, 1.0))
	_cover(c + Vector3(w / 2 + 1.6, 0, d / 2)); _cover(c + Vector3(w / 2 - 1.6, 0, d / 2)); _cover(c + Vector3(2.0, 0, 4.0))
	info["waypoints"].append(c + Vector3(w / 2, 0, 2.0))
	info["waypoints"].append(c + Vector3(3.0, 0, d - 1.5))

## Barracks: a long low building, bunks, lockers, a light left on.
func _barracks(o: Vector3) -> void:
	_ground(o, "concrete")
	var c := o + Vector3(0.8, 0, 3.0)
	var w := 10.4
	var d := 5.6
	var h := 3.0
	var m := Game.mat("concrete", 0.5)
	box(c + Vector3(w / 2, 0.05, d / 2), Vector3(w, 0.1, d), Game.mat("tiles", 0.5), false)
	_wall(c, w, true, h, m, [[1.0, 2.0, 0.9], [4.5, 5.9], [8.0, 9.0, 0.9]], "brick")
	_wall(c + Vector3(0, 0, d), w, true, h, m, [[1.5, 2.5, 0.9], [5.0, 6.0, 0.9], [8.0, 9.0, 0.9]], "brick")
	_wall(c, d, false, h, m, [[2.0, 3.4]], "brick")
	_wall(c + Vector3(w, 0, 0), d, false, h, m, [], "brick")
	box(c + Vector3(w / 2, h + 0.05, d / 2), Vector3(w + 0.3, 0.1, d + 0.3), Game.mat("roof", 1.0), false)
	for i in 4:
		box(c + Vector3(1.2 + i * 2.6, 0.6, d - 1.0), Vector3(0.9, 1.2, 1.9), Game.color_mat(Color(0.3, 0.33, 0.28)))
		box(c + Vector3(1.2 + i * 2.6, 0.9, 0.5), Vector3(0.8, 1.8, 0.45), Game.mat("metal", 0.5))
	_lamp(c + Vector3(w / 2, 2.7, d / 2), 0.9, 6.0, Color(0.9, 0.95, 1.0))
	_cover(c + Vector3(5.2, 0, -1.0)); _cover(c + Vector3(3.0, 0, 2.6))
	info["waypoints"].append(c + Vector3(w / 2, 0, d / 2))
	info["vip_spots"].append(c + Vector3(9.5, 0.3, d - 1.0))

## The radar: a steel lattice tower with the dish and a hut at its foot.
func _radar_tower(o: Vector3) -> void:
	_ground(o, "concrete")
	var b := o + Vector3(BLOCK / 2, 0, BLOCK / 2)
	var st := Game.color_mat(Color(0.35, 0.37, 0.4))
	for sx in [-1.2, 1.2]:
		for sz in [-1.2, 1.2]:
			box(b + Vector3(sx, 4.0, sz), Vector3(0.18, 8.0, 0.18), st)
	for k in 4:
		box(b + Vector3(0, 1.5 + k * 2.0, 0), Vector3(2.6, 0.1, 2.6), st, false)
	box(b + Vector3(0, 8.1, 0), Vector3(3.0, 0.2, 3.0), st)
	var dish := cyl(b + Vector3(0, 9.4, 0), 2.6, 0.5, 1.0, Game.color_mat(Color(0.85, 0.86, 0.88)), false, 16)
	dish.rotation.x = 0.6
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.1, 0.1)
	lamp.light_energy = 1.2
	lamp.omni_range = 4.0
	lamp.set_meta("flicker", true)
	root.add_child(lamp)
	lamp.position = b + Vector3(0, 10.2, 0)
	info["lights"].append(lamp)
	var hut := o + Vector3(1.0, 0, 1.0)
	_wall(hut, 3.0, true, 2.6, Game.mat("concrete", 0.5), [[1.0, 2.2]], "brick")
	_wall(hut + Vector3(0, 0, 2.6), 3.0, true, 2.6, Game.mat("concrete", 0.5), [], "brick")
	_wall(hut, 2.6, false, 2.6, Game.mat("concrete", 0.5), [], "brick")
	_wall(hut + Vector3(3.0, 0, 0), 2.6, false, 2.6, Game.mat("concrete", 0.5), [[1.0, 1.8, 1.0]], "brick")
	box(hut + Vector3(1.5, 2.65, 1.3), Vector3(3.4, 0.1, 3.0), Game.mat("corrugated", 0.5), false)
	box(hut + Vector3(1.5, 0.5, 2.0), Vector3(2.0, 1.0, 0.6), Game.mat("metal", 0.5))
	_cover(b + Vector3(2.2, 0, 0)); _cover(b + Vector3(-2.2, 0, 0))
	info["waypoints"].append(b + Vector3(0, 0, 3.0))

## Sandbags and a gun position at the edge of the base.
func _sandbags(o: Vector3) -> void:
	_ground(o, "dirt")
	var m := Game.color_mat(Color(0.5, 0.45, 0.32))
	for i in 3:
		var p := _jit(o, 2.0)
		var yaw := rng.randf() * TAU
		for k in 3:
			box(p + Vector3(0, 0.25 + k * 0.3, 0).rotated(Vector3.UP, 0), Vector3(3.0 - k * 0.4, 0.3, 0.6), m, true, yaw)
		_cover(p + Vector3(cos(yaw + PI / 2), 0, -sin(yaw + PI / 2)) * 1.0)
	_crate(_jit(o, 2.0), 0.9)
	info["waypoints"].append(o + Vector3(BLOCK / 2, 0, BLOCK / 2))

# ---- furniture (own pieces; boxes with a little detail) -----------------------------------------
func _sofa(p: Vector3, yaw: float, col: Color) -> void:
	var m := Game.color_mat(col)
	var b := Basis(Vector3.UP, yaw)
	box(p + b * Vector3(0, 0.25, 0), Vector3(2.0, 0.5, 0.9) if absf(sin(yaw)) < 0.5 else Vector3(0.9, 0.5, 2.0), m)
	box(p + b * Vector3(0, 0.6, 0.38), Vector3(2.0, 0.6, 0.18) if absf(sin(yaw)) < 0.5 else Vector3(0.18, 0.6, 2.0), m, false)
	for sx in [-0.95, 0.95]:
		box(p + b * Vector3(sx, 0.45, 0.0), Vector3(0.14, 0.4, 0.9) if absf(sin(yaw)) < 0.5 else Vector3(0.9, 0.4, 0.14), m, false)

func _tv_unit(p: Vector3, yaw: float) -> void:
	var wood := Game.mat("planks", 1.0)
	box(p + Vector3(0, 0.9, 0), Vector3(1.8, 1.8, 0.45), wood, true, yaw)
	var tv := box(p + Vector3(0, 1.0, 0) + Basis(Vector3.UP, yaw) * Vector3(0, 0, -0.24), Vector3(0.7, 0.5, 0.05), Game.color_mat(Color(0.05, 0.08, 0.1)), false, yaw)
	tv.set_meta("screen", true)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.5, 0.65, 1.0)
	glow.light_energy = 0.5
	glow.omni_range = 3.0
	glow.set_meta("flicker", true)
	root.add_child(glow)
	glow.position = p + Vector3(0, 1.0, 0) + Basis(Vector3.UP, yaw) * Vector3(0, 0, -0.6)
	info["lights"].append(glow)

func _bookshelf(p: Vector3, yaw: float) -> void:
	box(p + Vector3(0, 1.0, 0), Vector3(1.6, 2.0, 0.35), Game.mat("planks", 1.0), true, yaw)
	var cols := [Color(0.5, 0.15, 0.12), Color(0.15, 0.25, 0.45), Color(0.6, 0.55, 0.3), Color(0.2, 0.35, 0.2)]
	for k in 4:
		box(p + Vector3(0, 0.3 + k * 0.45, 0) + Basis(Vector3.UP, yaw) * Vector3(0, 0, -0.18), Vector3(1.4, 0.3, 0.02), Game.color_mat(cols[k]), false, yaw)

func _kitchen(p: Vector3, along_x: bool, length: float) -> void:
	# a counter along a wall, a stove, a tall fridge at its end
	var top := Game.color_mat(Color(0.75, 0.72, 0.65))
	var cab := Game.mat("planks", 1.0)
	var sz := Vector3(length, 0.9, 0.6) if along_x else Vector3(0.6, 0.9, length)
	box(p + Vector3(0, 0.45, 0), sz, cab)
	box(p + Vector3(0, 0.92, 0), sz + Vector3(0.04, -0.86, 0.04), top, false)
	var end := p + (Vector3(length / 2 + 0.4, 0, 0) if along_x else Vector3(0, 0, length / 2 + 0.4))
	box(end + Vector3(0, 0.95, 0), Vector3(0.7, 1.9, 0.65), Game.color_mat(Color(0.88, 0.88, 0.84)))     # fridge
	box(p + Vector3(0, 0.97, 0) + (Vector3(-length / 4, 0, 0) if along_x else Vector3(0, 0, -length / 4)), Vector3(0.5, 0.04, 0.5), Game.color_mat(Color(0.1, 0.1, 0.1)), false)

func _rug(p: Vector3, size: Vector2, col: Color) -> void:
	box(p + Vector3(0, 0.115, 0), Vector3(size.x, 0.01, size.y), Game.color_mat(col), false)

# ---- town: a shop, the pub, a park, a car park -----------------------------------------------
## The corner shop: a glass front, aisles of shelves, the till, a store room with a stair to the roof.
func _shop(o: Vector3) -> void:
	_ground(o, "concrete")
	var c := o + Vector3(0.6, 0, 1.5)
	var w := 10.8
	var d := 9.0
	var h := 3.4
	var m := Game.mat("plaster", 1.0)
	box(c + Vector3(w / 2, 0.05, d / 2), Vector3(w, 0.1, d), Game.mat("tiles", 0.5), false)
	_wall(c, w, true, h, m, [[0.6, 3.2, 0.5], [3.8, 5.4], [6.0, 9.6, 0.5]], "brick")
	_wall(c + Vector3(0, 0, d), w, true, h, m, [[8.6, 10.1]], "brick")
	_wall(c, d, false, h, m, [[1.5, 3.0, 1.0]], "brick")
	_wall(c + Vector3(w, 0, 0), d, false, h, m, [], "brick")
	_wall(c + Vector3(0, 0, 6.4), w - 2.4, true, h, m, [[3.6, 5.1]], "brick")      # store room behind
	# roof with a hole for the stair, a low parapet up there
	var rh := h + 0.1
	box(c + Vector3((w - 2.2) / 2, h - 0.05, d / 2), Vector3(w - 2.2, 0.3, d), Game.mat("concrete", 0.5))
	box(c + Vector3(w - 1.1, h - 0.05, 0.9), Vector3(2.2, 0.3, 1.8), Game.mat("concrete", 0.5))
	_stairs(c + Vector3(w - 1.1, 0, d - 0.4 - 5.6), c + Vector3(w - 1.1, rh, d - 0.4), 1.9, Game.mat("concrete", 0.5))
	for side in [[Vector3(w / 2, rh + 0.4, -0.05), Vector3(w, 0.8, 0.15)], [Vector3(w / 2, rh + 0.4, d + 0.05), Vector3(w, 0.8, 0.15)], [Vector3(-0.05, rh + 0.4, d / 2), Vector3(0.15, 0.8, d)]]:
		box(c + side[0], side[1], Game.mat("concrete", 0.5))
	# aisles
	var goods := [Color(0.8, 0.2, 0.15), Color(0.2, 0.5, 0.8), Color(0.9, 0.75, 0.2), Color(0.3, 0.6, 0.3)]
	for k in 3:
		var ax := c + Vector3(1.8 + k * 2.4, 0, 3.4)
		box(ax + Vector3(0, 0.8, 0), Vector3(0.7, 1.6, 3.2), Game.mat("metal", 0.5))
		for lv in 3:
			for sd in [-0.37, 0.37]:
				box(ax + Vector3(sd, 0.4 + lv * 0.5, 0), Vector3(0.02, 0.22, 3.0), Game.color_mat(goods[(k + lv) % 4]), false)
		_cover(ax + Vector3(0.9, 0, 0))
	box(c + Vector3(w - 2.0, 0.5, 1.2), Vector3(1.6, 1.0, 0.7), Game.mat("planks", 1.0))      # till
	for i in 3:
		_crate(c + Vector3(1.0 + i * 1.3, 0, 7.6), 0.9)
	_lamp(c + Vector3(3.0, h - 0.4, 3.0), 1.0, 7.0, Color(0.95, 0.98, 1.0))
	_lamp(c + Vector3(7.0, h - 0.4, 3.0), 1.0, 7.0, Color(0.95, 0.98, 1.0))
	info["waypoints"].append(c + Vector3(4.5, 0, 1.5))
	info["waypoints"].append(c + Vector3(3.0, 0, 7.6))
	info["waypoints"].append(c + Vector3(4.0, rh, 3.0))
	info["vip_spots"].append(c + Vector3(1.0, 0.3, 8.2))

## The pub: tables and chairs, the bar, a kitchen behind it, a beer garden with benches outside.
func _pub(o: Vector3) -> void:
	_ground(o, "grass")
	var c := o + Vector3(0.8, 0, 0.8)
	var w := 10.4
	var d := 7.4
	var h := 3.2
	var m := Game.mat("plaster", 0.5)
	box(c + Vector3(w / 2, 0.05, d / 2), Vector3(w, 0.1, d), Game.mat("planks", 0.5), false)
	_wall(c, w, true, h, m, [[0.8, 2.2, 0.9], [3.2, 4.7], [6.0, 7.5, 0.9]], "brick")
	_wall(c + Vector3(0, 0, d), w, true, h, m, [[1.5, 2.5, 0.9], [8.2, 9.7]], "brick")
	_wall(c, d, false, h, m, [[2.5, 4.0, 0.9]], "brick")
	_wall(c + Vector3(w, 0, 0), d, false, h, m, [[2.0, 3.5, 0.9]], "brick")
	_wall(c + Vector3(7.6, 0, 0), d, false, h, Game.mat("tiles", 0.5), [[4.6, 6.1]], "brick")    # kitchen
	box(c + Vector3(w / 2, h + 0.05, d / 2), Vector3(w + 0.3, 0.1, d + 0.3), Game.mat("roof", 1.0), false)
	var rf := _prop("house_roof", c + Vector3(w / 2, h, d / 2), 0.0, false)
	rf.scale = Vector3(w / 8.0, 0.9, d / 6.0)
	# the bar
	box(c + Vector3(6.6, 0.55, 3.2), Vector3(0.7, 1.1, 4.0), Game.mat("planks", 1.0))
	for k in 3:
		cyl(c + Vector3(7.25, 1.3, 1.6 + k * 0.5), 0.05, 0.05, 0.5, Game.color_mat(Color(0.75, 0.7, 0.6)), false, 6)
	# tables
	for ix in 2:
		for iz in 2:
			var tp := c + Vector3(1.6 + ix * 2.6, 0, 1.8 + iz * 2.8)
			box(tp + Vector3(0, 0.75, 0), Vector3(1.2, 0.06, 0.8), Game.mat("planks", 1.0), false)
			box(tp + Vector3(0, 0.38, 0), Vector3(0.12, 0.75, 0.12), Game.mat("planks", 1.0))
			for sx in [-0.8, 0.8]:
				box(tp + Vector3(sx, 0.45, 0), Vector3(0.4, 0.9, 0.4), Game.mat("planks", 1.0), false)
	_kitchen(c + Vector3(9.8, 0, 2.4), false, 2.6)
	# beer garden
	for i in 2:
		var bp := o + Vector3(2.5 + i * 5.0, 0, 10.4)
		box(bp + Vector3(0, 0.75, 0), Vector3(2.0, 0.06, 0.7), Game.mat("planks", 1.0))
		for sz in [-0.6, 0.6]:
			box(bp + Vector3(0, 0.45, sz), Vector3(2.0, 0.06, 0.3), Game.mat("planks", 1.0), false)
		cyl(bp + Vector3(0, 1.2, 0), 0.03, 0.03, 2.4, Game.color_mat(Color(0.8, 0.8, 0.8)), false, 6)
		cyl(bp + Vector3(0, 2.4, 0), 0.0, 1.4, 0.5, Game.color_mat(Color(0.75, 0.15, 0.12)), false, 8)
	_lamp(c + Vector3(3.5, 2.8, 3.5), 1.0, 6.5)
	_lamp(c + Vector3(9.0, 2.8, 3.0), 0.7, 4.0, Color(0.95, 0.98, 1.0))
	info["sounds"].append({"name": "static", "pos": c + Vector3(6.6, 1.4, 1.5), "db": -22.0})    # the radio behind the bar
	_cover(c + Vector3(6.0, 0, 3.2)); _cover(c + Vector3(1.6, 0, 1.0)); _cover(o + Vector3(2.5, 0, 11.4))
	info["waypoints"].append(c + Vector3(3.0, 0, 3.5))
	info["vip_spots"].append(c + Vector3(9.4, 0.3, 6.2))

## A town park: crossing paths, flower beds, trees, benches, an iron railing, a dry fountain.
func _park(o: Vector3) -> void:
	_ground(o, "grass")
	_grass(o, 500, "grass", 0.3, 0.6)
	box(o + Vector3(BLOCK / 2, 0.02, BLOCK / 2), Vector3(2.2, 0.03, BLOCK), Game.mat("dirt", 0.5), false)
	box(o + Vector3(BLOCK / 2, 0.025, BLOCK / 2), Vector3(BLOCK, 0.03, 2.2), Game.mat("dirt", 0.5), false)
	cyl(o + Vector3(BLOCK / 2, 0.35, BLOCK / 2), 1.6, 1.7, 0.7, Game.mat("concrete", 0.5), true, 12)
	cyl(o + Vector3(BLOCK / 2, 0.72, BLOCK / 2), 1.3, 1.3, 0.04, Game.mat("water", 0.4), false, 12)
	var flowers := [Color(0.85, 0.65, 0.1), Color(0.8, 0.2, 0.25), Color(0.75, 0.5, 0.85)]
	for q in 4:
		var qp := o + Vector3(3.0 if q % 2 == 0 else 9.0, 0, 3.0 if q < 2 else 9.0)
		box(qp + Vector3(0, 0.12, 0), Vector3(2.6, 0.24, 2.6), Game.mat("dirt", 1.0), false)
		box(qp + Vector3(0, 0.3, 0), Vector3(2.3, 0.12, 2.3), Game.color_mat(flowers[q % 3]), false)
		var tp := qp + Vector3(1.8 if q % 2 == 0 else -1.8, 0, -1.8 if q < 2 else 1.8)
		cyl(tp + Vector3(0, 0.9, 0), 0.1, 0.14, 1.8, Game.mat("bark", 1.0), true, 6)
		var crown := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.2; sm.height = 1.9; sm.radial_segments = 8; sm.rings = 4
		crown.mesh = sm
		crown.material_override = Game.mat("leaves", 0.6)
		root.add_child(crown)
		crown.position = tp + Vector3(0, 2.4, 0)
	for b in [[Vector3(4.6, 0, 6.0), PI / 2], [Vector3(7.4, 0, 6.0), -PI / 2]]:
		var bp: Vector3 = o + b[0]
		box(bp + Vector3(0, 0.45, 0), Vector3(1.6, 0.08, 0.45), Game.mat("planks", 1.0), false, b[1])
		box(bp + Vector3(0, 0.22, 0), Vector3(1.4, 0.44, 0.3), Game.color_mat(Color(0.15, 0.15, 0.15)), true, b[1])
	# railing along two sides, gaps at the paths
	var iron := Game.color_mat(Color(0.12, 0.12, 0.13))
	for side in 2:
		for k in 5:
			var t := 0.4 + k * 2.4
			if t > 4.5 and t < 7.5:
				continue
			var fp := o + (Vector3(t + 1.0, 0.6, 0.15) if side == 0 else Vector3(0.15, 0.6, t + 1.0))
			var fb := box(fp, Vector3(2.0, 1.2, 0.06) if side == 0 else Vector3(0.06, 1.2, 2.0), iron)
			_breakable(fb, "wood")
	_cover(o + Vector3(BLOCK / 2 + 2.2, 0, BLOCK / 2)); _cover(o + Vector3(BLOCK / 2 - 2.2, 0, BLOCK / 2))
	info["waypoints"].append(o + Vector3(BLOCK / 2, 0, 2.0))

## A car park: painted bays, two rows of cars, lamp posts, a ticket kiosk.
func _parking(o: Vector3) -> void:
	_ground(o, "asphalt")
	var line := Game.color_mat(Color(0.85, 0.85, 0.8))
	for row in [1.8, 10.2]:
		for k in 6:
			box(o + Vector3(0.6 + k * 2.2, 0.04, row), Vector3(0.1, 0.01, 3.4), line, false)
			if k < 5 and rng.randf() < 0.6:
				var cp := o + Vector3(1.7 + k * 2.2, 0, row)
				_prop(["car_blue", "car_red", "car_beige"][rng.randi() % 3], cp, (0.0 if row < 5 else PI) + rng.randf_range(-0.08, 0.08))
	for lp in [Vector3(1.0, 0, 6.0), Vector3(11.0, 0, 6.0)]:
		cyl(o + lp + Vector3(0, 2.5, 0), 0.07, 0.09, 5.0, Game.color_mat(Color(0.2, 0.2, 0.22)), true, 6)
		var lens := box(o + lp + Vector3(0, 5.0, 0), Vector3(0.6, 0.1, 0.3), Game.color_mat(Color(1.0, 0.9, 0.7), true), false)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.8, 0.55)
		l.light_energy = 1.5
		l.omni_range = 10.0
		root.add_child(l)
		l.position = o + lp + Vector3(0, 4.8, 0)
		l.set_meta("base", 1.5)
		l.set_meta("lens", lens)
		info["elec_lights"].append(l)
	box(o + Vector3(6.0, 1.1, 6.0), Vector3(1.4, 2.2, 1.4), Game.color_mat(Color(0.75, 0.75, 0.7)))
	info["waypoints"].append(o + Vector3(6.0, 0, 4.0))
	info["waypoints"].append(o + Vector3(6.0, 0, 8.0))

# ---- polar waste: frozen lakes, ice spires, buried rocks ---------------------------------------
func _icelake(o: Vector3) -> void:
	_ground(o, "snow")
	var c := o + Vector3(BLOCK / 2 + rng.randf_range(-1.5, 1.5), 0, BLOCK / 2 + rng.randf_range(-1.5, 1.5))
	var ice := Game.color_mat(Color(0.55, 0.7, 0.85))
	cyl(c + Vector3(0, 0.03, 0), 4.2, 4.2, 0.03, ice, false, 14)
	cyl(c + Vector3(2.5, 0.031, 1.2), 2.4, 2.4, 0.03, ice, false, 12)
	for k in 5:
		var a := rng.randf() * TAU
		box(c + Vector3(cos(a) * 1.5, 0.05, sin(a) * 1.5), Vector3(rng.randf_range(1.5, 3.0), 0.005, 0.04), Game.color_mat(Color(0.85, 0.92, 1.0)), false, rng.randf() * PI)
	for k in 6:
		var a2 := TAU * k / 6.0 + rng.randf_range(-0.3, 0.3)
		var p := c + Vector3(cos(a2) * 4.8, 0, sin(a2) * 4.8)
		var r := rng.randf_range(0.3, 0.7)
		cyl(p + Vector3(0, r * 0.4, 0), r * 0.5, r, r * 0.8, Game.mat("rock", 0.6), r > 0.5, 6)
	info["waypoints"].append(c + Vector3(5.5, 0, 0))

func _icespires(o: Vector3) -> void:
	_ground(o, "snow")
	var ice := Game.color_mat(Color(0.75, 0.85, 0.95))
	for i in rng.randi_range(3, 5):
		var p := _jit(o, 2.0)
		var hh := rng.randf_range(3.0, 7.0)
		var r := rng.randf_range(1.0, 2.0)
		var sp := cyl(p + Vector3(0, hh / 2, 0), 0.05, r, hh, ice, true, 7)
		sp.rotation.y = rng.randf() * PI
		_cover(p + Vector3(r + 0.7, 0, 0)); _cover(p + Vector3(-r - 0.7, 0, 0))
	for i in 3:
		var rp := _jit(o, 1.0)
		var rr := rng.randf_range(0.5, 1.2)
		cyl(rp + Vector3(0, rr * 0.35, 0), rr * 0.6, rr, rr * 0.7, Game.mat("rock", 0.6), true, 6)
	info["waypoints"].append(o + Vector3(BLOCK / 2, 0, BLOCK / 2))

## A research hut on the ice: someone was here before us.
func _polar_hut(o: Vector3) -> void:
	_ground(o, "snow")
	var c := o + Vector3(3.0, 0, 3.0)
	var m := Game.color_mat(Color(0.75, 0.25, 0.15))
	box(c + Vector3(3.0, 0.15, 2.5), Vector3(6.0, 0.3, 5.0), Game.mat("planks", 0.5))
	var up := c + Vector3(0, 0.3, 0)
	_wall(up, 6.0, true, 2.6, m, [[2.2, 3.7]], "metal")
	_wall(up + Vector3(0, 0, 5.0), 6.0, true, 2.6, m, [[1.0, 2.0, 0.9], [4.0, 5.0, 0.9]], "metal")
	_wall(up, 5.0, false, 2.6, m, [], "metal")
	_wall(up + Vector3(6.0, 0, 0), 5.0, false, 2.6, m, [[2.0, 3.0, 0.9]], "metal")
	box(c + Vector3(3.0, 3.0, 2.5), Vector3(6.4, 0.15, 5.4), Game.color_mat(Color(0.85, 0.85, 0.85)), false)
	box(up + Vector3(1.0, 0.5, 4.2), Vector3(1.6, 1.0, 0.7), Game.mat("metal", 0.5))
	cyl(c + Vector3(7.0, 2.5, 4.5), 0.05, 0.05, 5.0, Game.color_mat(Color(0.3, 0.3, 0.3)), false, 6)
	_lamp(up + Vector3(3.0, 2.3, 2.5), 0.8, 5.0, Color(0.95, 0.98, 1.0))
	info["waypoints"].append(up + Vector3(3.0, 0, 2.5))
	info["vip_spots"].append(up + Vector3(5.0, 0.3, 4.0))

## Hides the box meshes (the collision stays) when a real model replaces them.
func _hide_mesh(n: Node3D) -> void:
	if n is MeshInstance3D:
		n.visible = false
	for c in n.get_children():
		if c is MeshInstance3D:
			c.visible = false

func _skyranger(o: Vector3) -> void:
	_ground(o, "grass")
	var c := o + Vector3(BLOCK / 2, 0, 5.0)
	var m := Game.mat("skyranger", 0.5)
	# the team's ride: the Kondor, or before its research the old twin-rotor Čáp
	var heli := String(Net.mission_params.get("transport", "kondor")) == "heli"
	var ship := Game.model("heli" if heli else "dropship")
	root.add_child(ship)
	ship.position = c
	if heli:
		for rn in ["RotorF", "RotorR"]:
			var r: Node3D = ship.find_child(rn, true, false)
			if r:
				# idling blades: a slow, endless turn
				var tw := (Engine.get_main_loop() as SceneTree).create_tween().bind_node(r).set_loops()
				tw.tween_property(r, "rotation:y", TAU, 2.6 if rn == "RotorF" else 2.9).as_relative()
	var first := root.get_child_count()
	# fuselage pointing away from the map (nose at -z), ramp open towards +z
	box(c + Vector3(-1.6, 1.4, 0), Vector3(0.3, 2.8, 8), m)
	box(c + Vector3(1.6, 1.4, 0), Vector3(0.3, 2.8, 8), m)
	box(c + Vector3(0, 2.9, 0), Vector3(3.5, 0.3, 8), m)
	box(c + Vector3(0, 1.4, -4.0), Vector3(3.5, 2.8, 0.3), m)
	box(c + Vector3(0, 0.1, 0), Vector3(3.2, 0.2, 8), Game.mat("metal"), false)
	box(c + Vector3(-4.0, 2.0, -1.0), Vector3(5.0, 0.2, 3.0), m, false)
	box(c + Vector3(4.0, 2.0, -1.0), Vector3(5.0, 0.2, 3.0), m, false)
	var ramp := box(c + Vector3(0, 0.25, 5.0), Vector3(3.0, 0.15, 2.4), Game.mat("metal"), false)
	ramp.rotation.x = 0.18
	for i in range(first, root.get_child_count()):
		_hide_mesh(root.get_child(i))
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.85, 0.6)
	lamp.light_energy = 1.2
	lamp.omni_range = 7.0
	root.add_child(lamp)
	lamp.position = c + Vector3(0, 2.4, 1.0)
	info["evac"] = c + Vector3(0, 0, 1.0)
	info["door"] = c + Vector3(0, 0.15, 4.0)      # hinge of the rear ramp (closed until the prep is over)
	for i in 4:
		info["player_spawns"].append(c + Vector3(-0.8 + (i % 2) * 1.6, 0.3, 1.5 + (i / 2) * 1.6))

func _ufo(center: Vector3) -> void:
	info["ufo"] = center
	var crashed := mtype == "crash"
	if crashed:
		# scorched crash furrow
		box(center + Vector3(0, 0.03, 7), Vector3(5, 0.04, 14), Game.mat("scorch"), false)
		cyl(center + Vector3(0, 0.01, 0), 8.5, 8.5, 0.02, Game.mat("scorch"), false, 12)
		# plates torn off on the way down, stuck in the furrow
		for k in 4:
			var pz := rng.randf_range(10.0, 18.0)
			box(center + Vector3(rng.randf_range(-2.0, 2.0), 0.3, pz), Vector3(rng.randf_range(0.8, 1.6), 0.08, rng.randf_range(1.0, 2.0)), Game.mat("ufo_hull", 0.5), true, rng.randf() * PI).rotation.x = rng.randf_range(0.4, 0.9)
	else:
		# landed: pressed ground under a violet landing light
		cyl(center + Vector3(0, 0.02, 0), 6.5, 6.5, 0.04, Game.mat("hay", 0.8), false, 16)
		var down := SpotLight3D.new()
		down.light_color = Color(0.7, 0.5, 1.0)
		down.light_energy = 3.0
		down.spot_range = 8.0
		down.spot_angle = 50.0
		root.add_child(down)
		down.position = center + Vector3(0, 3.6, 0)
		down.rotation.x = -PI / 2
	# the ship itself: a detailed saucer you can walk into (scout / raider / harvester)
	var kind: String = ufo_kind
	var u: Node3D = Game.model("ufo_g_" + kind)
	root.add_child(u)
	for sb in u.find_children("*", "StaticBody3D", true, false):
		sb.set_meta("surf", "metal")
	var yaw := rng.randf_range(-0.5, 0.5)
	# the ship stands level (a tilted floor sank into the ground and the doorway with it);
	# the crash shows in the furrow, the scorch, torn plates and the flickering lights
	u.position = center
	u.rotation = Vector3(0.0, yaw, 0.0)
	var r: float = {"scout": 5.0, "raider": 7.0, "harvester": 10.0}[kind]
	var xf: Transform3D = u.transform
	for c in u.get_children():
		var nm := String(c.name)
		if nm.begins_with("Spawn_"):
			info["alien_spawns"].append(xf * c.position + Vector3(0, 0.2, 0))
		elif nm.begins_with("Way_"):
			info["waypoints"].append(xf * c.position)
		elif nm.begins_with("Light_"):
			var ul := OmniLight3D.new()
			ul.light_color = Color(0.65, 0.35, 1.0)
			ul.light_energy = 1.6
			ul.omni_range = 7.0
			ul.shadow_enabled = false
			root.add_child(ul)
			ul.position = xf * c.position
			if crashed:
				ul.set_meta("flicker", true)
				info["lights"].append(ul)
		elif nm == "Core":
			var cl := OmniLight3D.new()
			cl.light_color = Color(0.4, 1.0, 0.5)
			cl.light_energy = 1.4
			cl.omni_range = 5.0
			root.add_child(cl)
			cl.position = xf * c.position
	var door := xf * Vector3(0, 0, -(r + 2.6))
	# crashed: torn hull plates around; landed: their cargo pods stacked outside
	var hull := Game.mat("ufo_hull", 0.5) if crashed else Game.mat("ufo_wall", 0.5, Color(0.12, 0.05, 0.2))
	var door_a := atan2(door.x - center.x, door.z - center.z)
	for i in 6:
		var a2 := rng.randf() * TAU
		if absf(wrapf(a2 - door_a, -PI, PI)) < 0.6:
			a2 += PI * 0.5            # keep the way to the ramp clear
		var dist := rng.randf_range(r + 2.5, r + 6.0)
		var p2 := center + Vector3(sin(a2) * dist, 0.4, cos(a2) * dist)
		box(p2, Vector3(rng.randf_range(1.0, 2.2), 0.8, rng.randf_range(0.4, 1.0)), hull, true, rng.randf() * PI)
		_cover(p2 + Vector3(0.9, 0, 0.9))
	var fire := OmniLight3D.new()
	if not crashed:
		fire.visible = false
	fire.light_color = Color(1.0, 0.45, 0.15)
	fire.light_energy = 1.6
	fire.omni_range = 6.0
	fire.set_meta("flicker", true)
	root.add_child(fire)
	fire.position = center + Vector3(2.5, 0.8, r + 2.5)
	info["lights"].append(fire)
	info["ufo_door"] = door
	info["ufo_kind"] = kind
	info["waypoints"].append(door)
	for i in 6:
		var a4 := TAU * i / 6.0
		var wp := center + Vector3(sin(a4) * (r + 4.5), 0, cos(a4) * (r + 4.5))
		info["waypoints"].append(wp)
		info["alien_spawns"].append(wp + Vector3(0, 0.2, 0))

# ---- the giants: a ship of octagonal halls joined by short passages (late in the war) ----------
## Battleship: command bridge in the middle, power core, lab with tanks, quarters, cargo with cages and
## teleports. Supply ship: mostly cargo and specimen tanks. Shoot the power core and it blows.
const SEC_R := 6.5
const SEC_S := 15.0
func _big_ufo(center: Vector3) -> void:
	info["ufo"] = center
	info["ufo_kind"] = ufo_kind
	var plan: Dictionary
	if ufo_kind == "battleship":
		plan = {Vector2i(0, -1): "entry", Vector2i(0, 0): "command", Vector2i(-1, 0): "power", Vector2i(1, 0): "lab",
			Vector2i(0, 1): "quarters", Vector2i(-1, 1): "cargo", Vector2i(1, 1): "teleport", Vector2i(-1, -1): "quarters", Vector2i(1, -1): "cargo"}
	else:
		plan = {Vector2i(0, -1): "entry", Vector2i(0, 0): "cargo", Vector2i(-1, 0): "lab", Vector2i(1, 0): "cargo",
			Vector2i(0, 1): "power", Vector2i(-1, 1): "lab", Vector2i(1, 1): "teleport"}
	# the hull's shadow on the ground, scorched grass around
	cyl(center + Vector3(0, 0.01, 0), 28.0, 28.0, 0.02, Game.mat("scorch"), false, 24)
	for k in plan:
		var cp := center + Vector3(k.x * SEC_S, 0, k.y * SEC_S)
		var open := []
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if plan.has(k + d):
				open.append(d)
		if plan[k] == "entry":
			open.append(Vector2i(0, -1))       # the ramp out
		_section(cp, open, String(plan[k]))
		for d in open:
			if plan.has(k + d) and (d.x > 0 or d.y > 0):
				_passage(cp + Vector3(d.x, 0, d.y) * SEC_R, Vector3(d.x, 0, d.y))
	var door := center + Vector3(0, 0, -SEC_S - SEC_R - 1.5)
	info["ufo_door"] = door
	info["waypoints"].append(door)
	for i in 8:
		var a4 := TAU * i / 8.0
		info["waypoints"].append(center + Vector3(sin(a4), 0, cos(a4)) * 30.0)

func _section(c: Vector3, open: Array, role: String) -> void:
	var H2 := 4.5
	var wall := Game.mat("ufo_wall", 0.5)
	var side := 2.0 * SEC_R * tan(PI / 8.0)
	cyl(c + Vector3(0, 0.05, 0), SEC_R / cos(PI / 8.0), SEC_R / cos(PI / 8.0), 0.1, Game.mat("ufo_floor", 0.5), true, 8).rotation.y = PI / 8.0
	cyl(c + Vector3(0, H2 + 0.15, 0), SEC_R / cos(PI / 8.0) + 0.3, SEC_R / cos(PI / 8.0) + 0.3, 0.3, Game.mat("ufo_hull", 0.5), true, 8).rotation.y = PI / 8.0
	for k in 8:
		var ang := k * PI / 4.0           # side k faces this direction (0 = +x, 2 = +z ...)
		var nrm := Vector3(cos(ang), 0, sin(ang))
		var mid := c + nrm * SEC_R
		var yaw := -ang + PI / 2.0
		var gap := false
		for d in open:
			if Vector3(d.x, 0, d.y).dot(nrm) > 0.99:
				gap = true
		if gap:
			# two pieces either side of a 3 m opening, a lintel over it
			var tang := Vector3(-nrm.z, 0, nrm.x)
			for sd in [-1.0, 1.0]:
				box(mid + tang * sd * (side / 2.0 + 1.5) / 2.0 + Vector3(0, H2 / 2, 0), Vector3((side - 3.0) / 2.0, H2, 0.35), wall, true, yaw)
			box(mid + Vector3(0, H2 - 0.6, 0), Vector3(3.0, 1.2, 0.35), wall, true, yaw)
		else:
			box(mid + Vector3(0, H2 / 2, 0), Vector3(side + 0.1, H2, 0.35), wall, true, yaw)
		# a strip of violet light along the top of every wall
		box(mid - nrm * 0.2 + Vector3(0, H2 - 0.3, 0), Vector3(side * 0.8, 0.08, 0.05), Game.color_mat(Color(0.7, 0.4, 1.0), true), false, yaw)
	var l := OmniLight3D.new()
	l.light_color = Color(0.65, 0.4, 1.0) if role != "power" else Color(1.0, 0.55, 0.2)
	l.light_energy = 1.4
	l.omni_range = 10.0
	root.add_child(l)
	l.position = c + Vector3(0, H2 - 0.6, 0)
	info["waypoints"].append(c)
	info["alien_spawns"].append(c + Vector3(1.5, 0.2, 1.5))
	_cover(c + Vector3(SEC_R - 1.2, 0, 0)); _cover(c + Vector3(-SEC_R + 1.2, 0, 0)); _cover(c + Vector3(0, 0, SEC_R - 1.2))
	var pink := Game.color_mat(Color(0.85, 0.55, 0.85))
	var chair_c := Game.color_mat(Color(0.35, 0.5, 0.85))
	match role:
		"command":
			# a ring of consoles round the middle, chairs, green screens on the walls
			for k in 2:
				var tc := c + Vector3((k - 0.5) * 4.5, 0, 0)
				cyl(tc + Vector3(0, 0.5, 0), 1.0, 0.8, 1.0, pink, true, 8)
				box(tc + Vector3(0, 1.05, 0), Vector3(1.0, 0.04, 0.6), Game.color_mat(Color(0.3, 1.0, 0.5), true), false)
				for j in 4:
					var aa := j * TAU / 4.0 + PI / 4.0
					cyl(tc + Vector3(cos(aa), 0, sin(aa)) * 1.7 + Vector3(0, 0.4, 0), 0.32, 0.25, 0.8, chair_c, true, 8)
			for k in 4:
				var aa2 := PI * 1.25 + k * 0.5
				var sp := c + Vector3(cos(aa2), 0, sin(aa2)) * (SEC_R - 0.3) + Vector3(0, 2.0, 0)
				box(sp, Vector3(1.0, 0.7, 0.06), Game.color_mat(Color(0.2, 0.9, 0.4), true), false, -aa2 + PI / 2.0)
			_low_walls(c, [[Vector3(-3.2, 0, 3.0), Vector3(3.2, 0, 3.0)]])
		"power":
			# the core: a column of molten orange light on a dark plinth - and a bomb if you hit it
			cyl(c + Vector3(0, 0.4, 0), 1.6, 1.8, 0.8, Game.color_mat(Color(0.12, 0.1, 0.14)), true, 10)
			var core := cyl(c + Vector3(0, 2.2, 0), 0.7, 0.7, 2.8, Game.color_mat(Color(1.0, 0.55, 0.1), true), true, 10)
			_breakable(core, "metal")
			core.set_meta("hp", 260.0)
			core.set_meta("explode", [7.0, 140.0])
			var cl := OmniLight3D.new()
			cl.light_color = Color(1.0, 0.5, 0.1)
			cl.light_energy = 3.0
			cl.omni_range = 9.0
			root.add_child(cl)
			cl.position = c + Vector3(0, 2.2, 0)
			for k in 6:
				var aa3 := k * TAU / 6.0
				box(c + Vector3(cos(aa3), 0, sin(aa3)) * (SEC_R - 0.5) + Vector3(0, 1.6, 0), Vector3(0.12, 3.2, 1.2), Game.color_mat(Color(0.3, 0.2, 0.35)), false, -aa3 + PI / 2.0)
		"lab":
			# specimen tanks round the walls; an operating table with jointed arms in the middle
			for k in 7:
				var aa4 := PI * 0.6 + k * TAU / 9.0
				_tank(c + Vector3(cos(aa4), 0, sin(aa4)) * (SEC_R - 1.2))
			box(c + Vector3(0, 0.85, 0), Vector3(2.2, 0.12, 1.0), Game.color_mat(Color(0.9, 0.88, 0.92)), true)
			box(c + Vector3(0, 0.4, 0), Vector3(0.6, 0.8, 0.5), Game.color_mat(Color(0.5, 0.45, 0.55)), false)
			box(c + Vector3(0.1, 1.05, 0), Vector3(1.4, 0.25, 0.5), Game.color_mat(Color(0.55, 0.35, 0.25)), false)    # what lies on it
			for sd in [-1.0, 1.0]:
				box(c + Vector3(sd * 0.7, 2.4, 0.9), Vector3(0.08, 1.2, 0.08), Game.color_mat(Color(0.3, 0.4, 0.8)), false)
				box(c + Vector3(sd * 0.5, 1.8, 0.6), Vector3(0.06, 0.06, 0.7), Game.color_mat(Color(0.3, 0.4, 0.8)), false)
			box(c + Vector3(0, H2 - 0.1, 0.9), Vector3(1.8, 0.2, 0.2), Game.color_mat(Color(0.25, 0.25, 0.3)), false)
		"quarters":
			# violet glowing floor squares, chairs on them
			for x in 3:
				for z in 3:
					var fp := c + Vector3((x - 1) * 2.2, 0.11, (z - 1) * 2.2)
					box(fp, Vector3(2.0, 0.02, 2.0), Game.color_mat(Color(0.55, 0.2, 0.75), true) if (x + z) % 2 == 0 else Game.color_mat(Color(0.35, 0.15, 0.5)), false)
					if (x + z) % 2 == 1:
						cyl(fp + Vector3(0, 0.4, 0), 0.32, 0.25, 0.8, chair_c, true, 8)
		"cargo":
			# cages of bone spikes round the walls, crates of their stores, a red teleport square
			for k in 4:
				var aa5 := k * TAU / 4.0 + PI / 4.0
				_cage(c + Vector3(cos(aa5), 0, sin(aa5)) * (SEC_R - 2.0))
			box(c + Vector3(0, 0.12, 0), Vector3(2.0, 0.04, 2.0), Game.color_mat(Color(0.9, 0.12, 0.1), true), false)
			_low_walls(c, [[Vector3(-2.0, 0, -2.5), Vector3(2.0, 0, -2.5)]])
		"teleport":
			for k in 4:
				var tp := c + Vector3((k % 2 - 0.5) * 4.0, 0.12, (k / 2 - 0.5) * 4.0)
				box(tp, Vector3(1.8, 0.04, 1.8), Game.color_mat(Color(0.9, 0.12, 0.1), true), false)
			for k in 3:
				var aa6 := PI * 0.8 + k * 0.6
				_tank(c + Vector3(cos(aa6), 0, sin(aa6)) * (SEC_R - 1.2))
		"entry":
			# the ramp down to the ground on the south side
			box(c + Vector3(0, 0.05, -SEC_R - 1.2), Vector3(3.0, 0.1, 2.6), Game.mat("ufo_floor", 0.5))

## A short covered passage from one hall's doorway to the next (2 m, 3 m wide).
func _passage(a: Vector3, d: Vector3) -> void:
	var L := SEC_S - SEC_R * 2.0 + 0.4
	var c := a + d * (L / 2.0 - 0.2)
	var along_x := absf(d.x) > 0.5
	var wall := Game.mat("ufo_wall", 0.5)
	box(c + Vector3(0, 0.05, 0), Vector3(L, 0.1, 3.0) if along_x else Vector3(3.0, 0.1, L), Game.mat("ufo_floor", 0.5))
	box(c + Vector3(0, 3.5, 0), Vector3(L, 0.3, 3.6) if along_x else Vector3(3.6, 0.3, L), Game.mat("ufo_hull", 0.5))
	for sd in [-1.0, 1.0]:
		var off := Vector3(0, 0, sd * 1.65) if along_x else Vector3(sd * 1.65, 0, 0)
		box(c + off + Vector3(0, 1.7, 0), Vector3(L, 3.4, 0.3) if along_x else Vector3(0.3, 3.4, L), wall)

## A low partition (head-high to a grey, waist-high to us).
func _low_walls(c: Vector3, segs: Array) -> void:
	for sg in segs:
		var a: Vector3 = c + sg[0]
		var b: Vector3 = c + sg[1]
		var d := b - a
		box((a + b) / 2.0 + Vector3(0, 1.1, 0), Vector3(d.length(), 2.2, 0.25), Game.mat("ufo_wall", 0.5), true, atan2(d.x, d.z) - PI / 2.0)

## A specimen tank: glass, blue liquid, something floating in it.
func _tank(p: Vector3) -> void:
	cyl(p + Vector3(0, 0.15, 0), 0.6, 0.65, 0.3, Game.color_mat(Color(0.75, 0.72, 0.7)), true, 10)
	cyl(p + Vector3(0, 2.25, 0), 0.6, 0.6, 0.3, Game.color_mat(Color(0.75, 0.72, 0.7)), false, 10)
	var liquid := StandardMaterial3D.new()
	liquid.albedo_color = Color(0.3, 0.6, 1.0, 0.45)
	liquid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	liquid.emission_enabled = true
	liquid.emission = Color(0.1, 0.25, 0.5)
	cyl(p + Vector3(0, 1.2, 0), 0.55, 0.55, 1.8, liquid, true, 10)
	var what := rng.randi() % 3
	var col: Color = [Color(0.55, 0.2, 0.15), Color(0.85, 0.7, 0.6), Color(0.35, 0.25, 0.2)][what]
	box(p + Vector3(0, 1.2, 0), Vector3(0.35, 0.6 if what != 1 else 0.9, 0.3), Game.color_mat(col), false, rng.randf() * PI)

## A cage of curved bone spikes standing in a ring.
func _cage(p: Vector3) -> void:
	cyl(p + Vector3(0, 0.08, 0), 1.0, 1.0, 0.16, Game.color_mat(Color(0.3, 0.12, 0.1)), true, 10)
	for k in 9:
		var a := k * TAU / 9.0
		var sp := cyl(p + Vector3(cos(a), 0, sin(a)) * 0.9 + Vector3(0, 0.9, 0), 0.02, 0.07, 1.8, Game.color_mat(Color(0.75, 0.5, 0.3)), false, 5)
		sp.rotation = Vector3(sin(a) * 0.15, 0, -cos(a) * 0.15)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = 1.0
	cy.height = 2.0
	cs.shape = cy
	sb.add_child(cs)
	root.add_child(sb)
	sb.position = p + Vector3(0, 1.0, 0)

## The last mission: red rock, bone spires, the Velín sunk into a crater; the Kondor
## lands on the plain in front of its tunnel.
func _mars() -> void:
	var size: float = BLOCK * N
	for x in N:
		for z in N:
			box(Vector3(x * BLOCK + BLOCK / 2, -0.25, z * BLOCK + BLOCK / 2), Vector3(BLOCK, 0.5, BLOCK), Game.mat("mars", 0.5))
	var center := Vector3(size / 2, 0, size / 2 + 6.0)
	var hq: Node3D = Game.model("mars_hq")
	root.add_child(hq)
	hq.position = center
	hq.rotation.y = PI            # the tunnel faces the landing site (-Z)
	info["ufo"] = center
	info["pylons"] = []
	var xf: Transform3D = hq.transform
	for c in hq.get_children():
		var nm := String(c.name)
		var gp: Vector3 = xf * c.position
		if nm == "Brain":
			info["brain"] = gp
		elif nm.begins_with("Pylon_"):
			info["pylons"].append(gp)
		elif nm.begins_with("Spawn_"):
			info["alien_spawns"].append(gp + Vector3(0, 0.2, 0))
		elif nm.begins_with("Way_"):
			info["waypoints"].append(gp)
		elif nm.begins_with("Light_"):
			var l := OmniLight3D.new()
			l.light_color = Color(0.9, 0.35, 0.6)
			l.light_energy = 1.8
			l.omni_range = 11.0
			root.add_child(l)
			l.position = gp
	info["ufo_door"] = xf * Vector3(0, 0, -24.0)
	# the landing site
	_skyranger(Vector3(size / 2 - BLOCK / 2, 0, 0))
	# rocks and spires everywhere outside the crater
	for i in 46:
		var p := Vector3(rng.randf_range(2, size - 2), 0, rng.randf_range(2, size - 2))
		if p.distance_to(center) < 20.0 or p.distance_to(info["evac"]) < 8.0 or absf(p.x - size / 2) < 3.0 and p.z < center.z:
			continue
		if rng.randf() < 0.25:
			_prop_m("mars_spire", p, rng.randf() * TAU, rng.randf_range(0.7, 1.4))
		else:
			_prop_m("mars_rock%d" % (rng.randi() % 3), p, rng.randf() * TAU, rng.randf_range(0.6, 1.6))
			_cover(p + Vector3(1.6, 0, 0))
		if rng.randf() < 0.3:
			info["waypoints"].append(p + Vector3(2.5, 0, 0))
			info["alien_spawns"].append(p + Vector3(2.5, 0.2, 0))

func _prop_m(model: String, p: Vector3, yaw: float, sc: float) -> void:
	var n: Node3D = Game.model(model)
	root.add_child(n)
	n.position = p
	n.rotation.y = yaw
	n.scale = Vector3.ONE * sc

## A dark drag trail: from the farmhouse door towards the crash site. Ends
## halfway, in the middle of nowhere.
func _blood_trail() -> void:
	if info["house"] == Vector3.ZERO:
		return
	var a: Vector3 = info["house"]
	var b: Vector3 = info["ufo"]
	var dir := (b - a)
	dir.y = 0
	var steps := int(min(dir.length() * 0.55, 22.0) / 0.7)
	var m := Game.color_mat(Color(0.16, 0.01, 0.015))
	var side := Vector3(-dir.z, 0, dir.x).normalized()
	for i in steps:
		var p := a + dir.normalized() * (0.7 * i) + side * sin(i * 0.7) * 0.25
		var sz := rng.randf_range(0.25, 0.5) * (1.0 - float(i) / steps * 0.6)
		box(p + Vector3(0, 0.045, 0), Vector3(sz, 0.01, sz * 1.6), m, false, atan2(dir.x, dir.z) + rng.randf_range(-0.3, 0.3))

func _borders() -> void:
	var s := BLOCK * N
	var m := Game.mat("leaves", 0.4)
	if biome == "polar" or terrain == "snow":
		m = Game.mat("snow", 0.3)
	elif terrain == "mars":
		m = Game.mat("mars", 0.3)
	elif terrain == "desert":
		m = Game.mat("sand", 0.3)
	for p in [[Vector3(s / 2, 2, -0.5), Vector3(s, 4, 1)], [Vector3(s / 2, 2, s + 0.5), Vector3(s, 4, 1)],
			[Vector3(-0.5, 2, s / 2), Vector3(1, 4, s)], [Vector3(s + 0.5, 2, s / 2), Vector3(1, 4, s)]]:
		box(p[0], p[1], m)
