extends RefCounted
## Builds a random night map from 12 m blocks, like UFO's map blocks: fields,
## pastures, a farmhouse, a barn, woods, a road, the crashed UFO and the
## Kondor (dropship). Same seed = same map on every machine.

const BLOCK := 12.0
var N := 6                 # blocks per side: malá 5, střední 6, velká 8, obrovská 10
const SIZES := {"small": 5, "medium": 6, "large": 8, "huge": 10}
const SIZE_NAMES := {"small": "malá", "medium": "střední", "large": "velká", "huge": "obrovská"}
var terrain := "temperate"   # temperate / snow (loud steps, snowfall) / desert

var rng := RandomNumberGenerator.new()
var root: Node3D
var nav: NavigationRegion3D
var info := {
	"player_spawns": [], "alien_spawns": [], "waypoints": [], "cover": [],
	"evac": Vector3.ZERO, "ufo": Vector3.ZERO, "lights": [], "size": BLOCK * N,
	"elec_lights": [], "sounds": [], "barn": Vector3.ZERO, "house": Vector3.ZERO,
	"cows": [], "circle": Vector3.ZERO, "truck": Vector3.ZERO,
}
var _circle_done := false
var _truck_done := false

var biome := "farm"
var mtype := "crash"
var ufo_kind := "scout"

func build(parent: Node3D, map_seed: int, params := {}) -> Dictionary:
	rng.seed = map_seed
	biome = params.get("biome", "farm")
	mtype = params.get("type", "crash")
	N = int(SIZES.get(params.get("size", "medium"), 6))
	# which ship: given (air war, quick missions), else by mission type and map size
	ufo_kind = params.get("ufo", "")
	if not ufo_kind in ["scout", "raider", "harvester"]:
		match mtype:
			"crash": ufo_kind = "scout" if rng.randf() < 0.6 else "raider"
			"landed": ufo_kind = "harvester" if params.get("size", "") in ["large", "huge"] else "raider"
			_: ufo_kind = "raider"
	if ufo_kind == "harvester" and N < 8:
		N = 8          # a big ship needs room around it
	terrain = params.get("terrain", "temperate")
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
	nm.agent_radius = 0.45
	nm.agent_height = 1.6
	nm.agent_max_climb = 0.35
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav.navigation_mesh = nm
	parent.add_child(nav)
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
	var ux := rng.randi_range(N / 2 - 1, N / 2)
	var uz := rng.randi_range(N / 2 - 1, N / 2)
	for dx in 2:
		for dz in 2:
			grid[ux + dx][uz + dz] = "ufo"
	info["ufo"] = Vector3((ux + 1) * BLOCK, 0, (uz + 1) * BLOCK)
	var sx := rng.randi_range(0, N - 1)
	grid[sx][0] = "sky"
	var farm := ["house", "barn"]
	if biome == "town":
		farm = ["chapel", "house", "house", "house", "house", "house", "house", "barn", "house", "house"]
		for i in maxi(0, (N * N - 36) / 5):      # bigger towns: more houses
			farm.append("house" if i % 6 != 5 else "barn")
	elif biome == "forest":
		farm = ["house"] if rng.randf() < 0.6 else []
	for f in farm:
		for tries in 50:
			var x := rng.randi_range(0, N - 1)
			var z := rng.randi_range(1, N - 1)
			if grid[x][z] == "":
				grid[x][z] = f
				break
	for tries in 50:
		var rx := rng.randi_range(0, N - 1)
		var rz := rng.randi_range(1, N - 1)
		if grid[rx][rz] == "":
			grid[rx][rz] = "road"
			break
	var fill := ["field", "field", "pasture", "pasture", "forest", "forest", "road"]
	if biome == "forest":
		fill = ["forest", "forest", "forest", "forest", "forest", "pasture", "road"]
	elif biome == "town":
		fill = ["street", "street", "street", "pasture", "house", "road"]
	for x in N:
		for z in N:
			if grid[x][z] == "":
				grid[x][z] = fill[rng.randi() % fill.size()]

	for x in N:
		for z in N:
			var o := Vector3(x * BLOCK, 0, z * BLOCK)
			match grid[x][z]:
				"field": _field(o)
				"pasture": _pasture(o)
				"forest": _forest(o)
				"road": _road(o)
				"street": _street(o)
				"house": _house(o)
				"barn": _barn(o)
				"chapel": _chapel(o)
				"sky": _skyranger(o)
				"ufo":
					_ground(o, "grass")
					_grass(o, 700, "dry", 0.5, 1.1)
	if Game.autotest() != "": print("[MAP] tiles done")
	_ufo(Vector3((ux + 1) * BLOCK, 0, (uz + 1) * BLOCK))
	if Game.autotest() != "": print("[MAP] ufo done")
	_blood_trail()
	if Game.autotest() != "": print("[MAP] trail done")
	_borders()
	nav.bake_navigation_mesh(false)
	if Game.autotest() != "": print("[MAP] nav done")
	return info

# ---- primitives ----------------------------------------------------------------
func box(pos: Vector3, size: Vector3, material: Material, collide := true, rot_y := 0.0) -> Node3D:
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
func _prop(name: String, p: Vector3, yaw := 0.0, cover := true) -> Node3D:
	var n: Node3D = Game.model("v_" + name)
	root.add_child(n)
	n.position = p
	n.rotation.y = yaw
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
func _street(o: Vector3) -> void:
	_ground(o, "dirt")
	box(o + Vector3(BLOCK / 2, 0.01, BLOCK / 2), Vector3(5.0, 0.04, BLOCK), Game.color_mat(Color(0.1, 0.1, 0.11)), false)
	box(o + Vector3(BLOCK / 2, 0.02, BLOCK / 2), Vector3(0.15, 0.01, BLOCK), Game.color_mat(Color(0.6, 0.6, 0.5)), false)
	for sx in [-1, 1]:
		box(o + Vector3(BLOCK / 2 + sx * 3.4, 0.08, BLOCK / 2), Vector3(1.6, 0.16, BLOCK), Game.mat("plaster", 1.0), false)
	for z in [2.5, 9.5]:
		var lp := o + Vector3(BLOCK / 2 + (3.9 if z < 5 else -3.9), 0, z)
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
	# a parked car
	if rng.randf() < 0.6:
		var c := o + Vector3(BLOCK / 2 + 1.4, 0, rng.randf_range(3, 9))
		var car := _prop(["car_blue", "car_red", "car_beige"][rng.randi() % 3], c, PI if rng.randf() < 0.5 else 0.0)
		car.rotation.y += rng.randf_range(-0.15, 0.15)
	if not _stop_done and rng.randf() < 0.5:
		_stop_done = true
		_prop("bus_stop", o + Vector3(BLOCK / 2 - 4.6, 0, 6.0), -PI / 2)
	info["waypoints"].append(o + Vector3(BLOCK / 2, 0, BLOCK / 2))

func _road(o: Vector3) -> void:
	_ground(o, "grass")
	box(o + Vector3(BLOCK / 2, 0.01, BLOCK / 2), Vector3(3.5, 0.04, BLOCK), Game.mat("dirt", 0.5), false)
	for z in [2.0, 8.0]:
		_prop("pole", o + Vector3(BLOCK / 2 - 2.6, 0, z), PI / 2, false)
	if not _cross_done and rng.randf() < 0.6:
		_cross_done = true
		_prop("cross", o + Vector3(BLOCK / 2 + 3.0, 0, BLOCK / 2 + 3.5), PI / 2)
	if not _truck_done:
		_truck_done = true
		_truck(o + Vector3(BLOCK / 2 + 0.6, 0, BLOCK / 2))
	info["waypoints"].append(o + Vector3(BLOCK / 2, 0, BLOCK / 2))

## The farmer's pickup: engine dead, headlights still on, driver's door open,
## the radio hissing to nobody.
func _truck(p: Vector3) -> void:
	info["truck"] = p
	var paint := Game.color_mat(Color(0.35, 0.12, 0.10))
	var dark := Game.color_mat(Color(0.05, 0.05, 0.06))
	var glass := Game.color_mat(Color(0.1, 0.14, 0.16))
	box(p + Vector3(0, 0.8, 0), Vector3(1.9, 0.7, 4.6), paint)
	box(p + Vector3(0, 1.45, -0.4), Vector3(1.8, 0.65, 1.6), glass)
	box(p + Vector3(0, 1.8, -0.4), Vector3(1.85, 0.08, 1.7), paint, false)
	for wx in [-0.95, 0.95]:
		for wz in [-1.5, 1.5]:
			cyl(p + Vector3(wx, 0.38, wz), 0.38, 0.38, 0.3, dark, false, 8).rotation.z = PI / 2
	# open door
	var door := box(p + Vector3(-1.35, 1.1, -0.9), Vector3(0.08, 1.0, 1.1), paint, false, 0.9)
	door.position.x -= 0.2
	for hx in [-0.6, 0.6]:
		var lens := box(p + Vector3(hx, 0.95, -2.32), Vector3(0.3, 0.2, 0.05), Game.color_mat(Color(1.0, 0.95, 0.75), true), false)
		var sl := SpotLight3D.new()
		sl.light_color = Color(1.0, 0.93, 0.75)
		sl.light_energy = 2.5
		sl.spot_range = 22.0
		sl.spot_angle = 24.0
		sl.shadow_enabled = hx < 0
		root.add_child(sl)
		sl.position = p + Vector3(hx, 0.95, -2.4)
		sl.rotation.x = -0.08
		sl.set_meta("base", 2.5)
		sl.set_meta("lens", lens)
		info["elec_lights"].append(sl)
	info["sounds"].append({"name": "static", "pos": p + Vector3(0, 1.3, -0.5), "db": -14.0})
	_cover(p + Vector3(1.6, 0, 0.5)); _cover(p + Vector3(-1.8, 0, 1.5))

## Walls with openings: segments along an axis; gaps are [from, to] in metres.
func _wall(start: Vector3, length: float, along_x: bool, h: float, material: Material, gaps := []) -> void:
	var cuts := [0.0]
	for g in gaps:
		cuts.append(g[0]); cuts.append(g[1])
	cuts.append(length)
	for i in range(0, cuts.size(), 2):
		var a: float = cuts[i]
		var b: float = cuts[i + 1]
		if b - a < 0.05:
			continue
		var mid := (a + b) / 2
		var pos := start + (Vector3(mid, h / 2, 0) if along_x else Vector3(0, h / 2, mid))
		box(pos, Vector3(b - a, h, 0.25) if along_x else Vector3(0.25, h, b - a), material)
	# lintels above door/window gaps
	for g in gaps:
		var mid2: float = (g[0] + g[1]) / 2.0
		var top := 2.2
		var pos2 := start + (Vector3(mid2, (top + h) / 2, 0) if along_x else Vector3(0, (top + h) / 2, mid2))
		var w: float = g[1] - g[0]
		box(pos2, Vector3(w, h - top, 0.25) if along_x else Vector3(0.25, h - top, w), material)

func _house(o: Vector3) -> void:
	_ground(o, "grass")
	var c := o + Vector3(2, 0, 3)
	var w := 8.0
	var d := 6.0
	var h := 3.0
	var m := Game.mat("plaster")
	box(c + Vector3(w / 2, 0.05, d / 2), Vector3(w, 0.1, d), Game.mat("planks", 0.5), false)
	_wall(c, w, true, h, m, [[3.0, 4.2]])
	_wall(c + Vector3(0, 0, d), w, true, h, m, [[1.5, 2.7], [5.5, 6.5]])
	_wall(c, d, false, h, m, [[2.5, 3.5]])
	_wall(c + Vector3(w, 0, 0), d, false, h, m, [])
	_wall(c + Vector3(4, 0, 0), d, false, h, m, [[2.0, 3.2]])
	box(c + Vector3(w / 2, h + 0.05, d / 2), Vector3(w, 0.1, d), Game.mat("planks", 0.5), false)    # ceiling
	_prop("house_roof", c + Vector3(w / 2, h, d / 2), 0.0, false)
	# windows on the solid parts of the walls (front, back, right side)
	for wx in [1.4, 6.6]:
		_prop("window", c + Vector3(wx, 1.55, -0.13), 0.0, false)
	_prop("window", c + Vector3(4.1, 1.55, d + 0.13), PI, false)
	_prop("window", c + Vector3(w + 0.13, 1.55, 1.3), -PI / 2, false)
	_prop("window", c + Vector3(w + 0.13, 1.55, 4.7), -PI / 2, false)
	box(c + Vector3(6, 0.4, 3), Vector3(1.4, 0.8, 0.9), Game.mat("planks", 1.0))
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
	_wall(c, w, true, h, m, [[3.5, 6.5]])
	_wall(c + Vector3(0, 0, d), w, true, h, m, [[4.0, 5.2]])
	_wall(c, d, false, h, m, [])
	_wall(c + Vector3(w, 0, 0), d, false, h, m, [[3.0, 4.2]])
	box(c + Vector3(w / 2, h + 0.05, d / 2), Vector3(w, 0.1, d), Game.mat("planks", 0.5), false)
	var br := _prop("house_roof", c + Vector3(w / 2, h, d / 2), 0.0, false)
	br.scale = Vector3(w / 8.0, 1.2, d / 6.0)
	if rng.randf() < 0.6:
		_prop("tractor", c + Vector3(w + 1.2, 0, d / 2 + 1.0), rng.randf_range(-0.4, 0.4))
	for i in 3:
		box(c + Vector3(1.5 + i * 1.6, 0.6, d - 1.5), Vector3(1.4, 1.2, 1.4), Game.mat("hay", 1.0))
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
	var ship := Game.model("dropship")
	root.add_child(ship)
	ship.position = c
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
	for i in 4:
		info["player_spawns"].append(c + Vector3(-0.8 + (i % 2) * 1.6, 0.3, 1.5 + (i / 2) * 1.6))

func _ufo(center: Vector3) -> void:
	info["ufo"] = center
	var crashed := mtype == "crash"
	if crashed:
		# scorched crash furrow
		box(center + Vector3(0, 0.02, 7), Vector3(5, 0.04, 14), Game.mat("scorch"), false)
		cyl(center + Vector3(0, 0.02, 0), 8.5, 8.5, 0.05, Game.mat("scorch"), false, 12)
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
	var yaw := rng.randf_range(-0.5, 0.5)
	u.position = center + (Vector3(0, -0.28, 0) if crashed else Vector3.ZERO)
	u.rotation = Vector3(rng.randf_range(-0.05, 0.05) if crashed else 0.0, yaw, rng.randf_range(0.05, 0.09) * (1 if rng.randf() < 0.5 else -1) if crashed else 0.0)
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
	for i in 6:
		var a2 := rng.randf() * TAU
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
		box(p + Vector3(0, 0.02, 0), Vector3(sz, 0.02, sz * 1.6), m, false, atan2(dir.x, dir.z) + rng.randf_range(-0.3, 0.3))

func _borders() -> void:
	var s := BLOCK * N
	var m := Game.mat("leaves", 0.4)
	for p in [[Vector3(s / 2, 2, -0.5), Vector3(s, 4, 1)], [Vector3(s / 2, 2, s + 0.5), Vector3(s, 4, 1)],
			[Vector3(-0.5, 2, s / 2), Vector3(1, 4, s)], [Vector3(s + 0.5, 2, s / 2), Vector3(1, 4, s)]]:
		box(p[0], p[1], m)
