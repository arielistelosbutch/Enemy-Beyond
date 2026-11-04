extends "res://scripts/map_gen.gd"
## The team's own base, underground: the facilities from the base screen, each a 12 m room cut
## into the earth, joined by short corridors to every built neighbour (like the old game's base
## modules - a room has a doorway in the middle of each side, opened only towards a neighbour;
## the rest stays solid wall with earth behind it). The velín holds the lift up to the surface.
## Built the same on every machine from the campaign's base grid.

const H := 3.4            # room height
const IN := 1.0           # wall inset from the cell edge (the earth between two rooms)
const DOOR := [4.8, 7.2]  # doorway in the middle of a side

var cells: Array = []     # [{type, days}]
var gw := 6
var gh := 4

func build(parent: Node3D, map_seed: int, params := {}) -> Dictionary:
	_t0 = Time.get_ticks_msec()
	rng.seed = map_seed
	cells = params.get("base", [])
	gw = int(params.get("grid_w", 6))
	gh = int(params.get("grid_h", 4))
	if cells.is_empty():
		cells = [{"type": "velin", "days": 0.0}, {"type": "hangar", "days": 0.0}]
		for i in gw * gh - 2:
			cells.append({"type": "", "days": 0.0})
	terrain = "base"
	N = maxi(gw, gh)
	info["size"] = BLOCK * N
	info["terrain"] = "base"
	info["terminals"] = []
	info["home"] = true
	nav = NavigationRegion3D.new()
	nav.name = "Nav"
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.4
	nm.agent_height = 1.6
	nm.agent_max_climb = 0.4
	nm.cell_size = 0.2
	nm.cell_height = 0.2
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav.navigation_mesh = nm
	parent.add_child(nav)
	root = nav
	for i in cells.size():
		var c: Dictionary = cells[i]
		if String(c.get("type", "")) == "":
			continue
		_room(i % gw, i / gw, String(c["type"]), float(c.get("days", 0.0)) > 0.0, params)
	# the earth all around: one slab under everything, one over it (seen through the lift shaft)
	box(Vector3(gw * BLOCK / 2, -0.6, gh * BLOCK / 2), Vector3(gw * BLOCK + 4, 1.0, gh * BLOCK + 4), Game.mat("earth", 0.5))
	if info["player_spawns"].is_empty():
		info["player_spawns"].append(Vector3(6, 0.3, 6))
	info["evac"] = Vector3.ZERO
	info["ufo"] = Vector3.ZERO
	info["waypoints"] = info["cover"].duplicate()
	nav.bake_navigation_mesh(false)
	if Game.autotest() != "": print("[BASE] built %d ms" % (Time.get_ticks_msec() - _t0))
	return info

func _built(gx: int, gz: int) -> bool:
	if gx < 0 or gz < 0 or gx >= gw or gz >= gh:
		return false
	return String(cells[gz * gw + gx].get("type", "")) != ""

## One facility: floor, walls with doorways towards built neighbours, ceiling, lights, furniture.
func _room(gx: int, gz: int, kind: String, building: bool, params: Dictionary) -> void:
	var o := Vector3(gx * BLOCK, 0, gz * BLOCK)
	var a := o + Vector3(IN, 0, IN)                 # inner corner
	var w := BLOCK - IN * 2                        # 10 m inside
	var h := H if kind != "hangar" else 7.0
	var wall := Game.mat("base_wall", 0.5)
	var floor_tex := "hangar_floor" if kind == "hangar" else "base_floor"
	box(a + Vector3(w / 2, -0.05, w / 2), Vector3(w + 0.5, 0.1, w + 0.5), Game.mat(floor_tex, 0.5))
	# walls: a doorway towards each built neighbour (north = -z, south = +z, west = -x, east = +x)
	var n := _built(gx, gz - 1)
	var s := _built(gx, gz + 1)
	var we := _built(gx - 1, gz)
	var e := _built(gx + 1, gz)
	var gap := [[DOOR[0] - IN, DOOR[1] - IN]]
	_wall(a, w, true, h, wall, gap if n else [])
	_wall(a + Vector3(0, 0, w), w, true, h, wall, gap if s else [])
	_wall(a, w, false, h, wall, gap if we else [])
	_wall(a + Vector3(w, 0, 0), w, false, h, wall, gap if e else [])
	# ceiling (a hole over the lift), skirting light strips
	if kind == "velin":
		box(a + Vector3(w / 2 + 1.5, h + 0.1, w / 2), Vector3(w - 3.0, 0.2, w), Game.mat("base_wall", 0.5))
		box(a + Vector3(1.5, h + 0.1, w / 2 + 1.5), Vector3(3.0, 0.2, w - 3.0), Game.mat("base_wall", 0.5))
	else:
		box(a + Vector3(w / 2, h + 0.1, w / 2), Vector3(w, 0.2, w), Game.mat("base_wall", 0.5))
	# corridors to the east and south neighbours (each pair once)
	if e:
		_corridor(o + Vector3(BLOCK - IN, 0, BLOCK / 2), true)
	if s:
		_corridor(o + Vector3(BLOCK / 2, 0, BLOCK - IN), false)
	# light: panels in the ceiling
	var lc := Color(1.0, 0.93, 0.82) if not building else Color(1.0, 0.7, 0.4)
	for lp in ([Vector3(w * 0.3, 0, w * 0.5), Vector3(w * 0.7, 0, w * 0.5)] if kind != "hangar" else [Vector3(w * 0.25, 0, w * 0.25), Vector3(w * 0.75, 0, w * 0.25), Vector3(w * 0.25, 0, w * 0.75), Vector3(w * 0.75, 0, w * 0.75)]):
		var l := OmniLight3D.new()
		l.light_color = lc
		l.light_energy = 1.3 if not building else 0.6
		l.omni_range = 8.0 if kind != "hangar" else 11.0
		l.omni_attenuation = 1.2
		root.add_child(l)
		l.position = a + lp + Vector3(0, h - 0.4, 0)
		box(a + lp + Vector3(0, h - 0.02, 0), Vector3(1.6, 0.05, 0.5), Game.color_mat(lc, true), false)
	if building:
		_construction(a, w, h)
		return
	match kind:
		"velin": _velin(a, w, h)
		"hangar": _hangar_hall(a, w, h, String(params.get("transport", "heli")))
		"ubikace": _quarters(a, w)
		"laborator": _lab(a, w)
		"dilna": _workshop(a, w)
		"osetrovna": _infirmary(a, w)
		"radar": _radar_room(a, w, h)
		"cela": _containment(a, w, params.get("live", []))
		"sklad": _stores(a, w)
	_cover(a + Vector3(1.0, 0, 1.0)); _cover(a + Vector3(w - 1.0, 0, w - 1.0))

## A short corridor through the earth between two rooms (2.4 m wide, low ceiling, lamp strip).
func _corridor(mid: Vector3, along_x: bool) -> void:
	var L := IN * 2 + 0.3
	var wd := DOOR[1] - DOOR[0]
	var wall := Game.mat("base_wall", 0.5)
	var c := mid + (Vector3(L / 2 - 0.15, 0, 0) if along_x else Vector3(0, 0, L / 2 - 0.15))
	var sz := Vector3(L, 0.1, wd) if along_x else Vector3(wd, 0.1, L)
	box(c + Vector3(0, -0.05, 0), sz, Game.mat("base_floor", 0.5))
	box(c + Vector3(0, H - 0.6 + 0.1, 0), Vector3(sz.x, 0.2, sz.z), wall)
	for sd in [-1.0, 1.0]:
		var off := Vector3(0, 0, sd * (wd / 2 + 0.12)) if along_x else Vector3(sd * (wd / 2 + 0.12), 0, 0)
		box(c + off + Vector3(0, (H - 0.6) / 2, 0), Vector3(L, H - 0.6, 0.25) if along_x else Vector3(0.25, H - 0.6, L), wall)
	box(c + Vector3(0, H - 0.6 - 0.02, 0), Vector3(sz.x * 0.8, 0.04, 0.2) if along_x else Vector3(0.2, 0.04, sz.z * 0.8), Game.color_mat(Color(0.75, 0.6, 1.0), true), false)
	# the lintel down from the room's height to the corridor's
	for k in [0.0, L - 0.3]:
		var lp := mid + (Vector3(k, 0, 0) if along_x else Vector3(0, 0, k))
		box(lp + Vector3(0, H - 0.3, 0) + (Vector3(0.15, 0, 0) if along_x else Vector3(0, 0, 0.15)), Vector3(0.3, 0.6, wd) if along_x else Vector3(wd, 0.6, 0.3), wall)

# ---- furniture ----------------------------------------------------------------------------------
func _col(c: Color) -> Material:
	return Game.color_mat(c)

func _cabinet(p: Vector3, yaw: float, col: Color) -> void:
	box(p + Vector3(0, 1.0, 0), Vector3(0.9, 2.0, 0.6), _col(col), true, yaw)
	var f := Vector3(sin(yaw), 0, cos(yaw)) * 0.31
	box(p + f + Vector3(0, 1.0, 0), Vector3(0.04, 1.6, 0.02) if absf(sin(yaw)) < 0.5 else Vector3(0.02, 1.6, 0.04), _col(col.darkened(0.35)), false, 0.0)

func _desk(p: Vector3, yaw: float, screen := Color(0.3, 1.0, 0.5)) -> void:
	box(p + Vector3(0, 0.75, 0), Vector3(1.6, 0.06, 0.8), _col(Color(0.55, 0.57, 0.6)), true, yaw)
	for sx in [-0.7, 0.7]:
		box(p + Vector3(0, 0.37, 0) + Vector3(cos(yaw), 0, -sin(yaw)) * sx, Vector3(0.06, 0.74, 0.7), _col(Color(0.35, 0.36, 0.4)), false, yaw)
	var back := Vector3(-sin(yaw), 0, -cos(yaw)) * 0.2
	box(p + back + Vector3(0, 1.0, 0), Vector3(0.55, 0.42, 0.35), _col(Color(0.82, 0.8, 0.74)), false, yaw)
	box(p + back * 0.1 + Vector3(0, 1.02, 0) + Vector3(sin(yaw), 0, cos(yaw)) * 0.0, Vector3(0.44, 0.3, 0.02) if absf(sin(yaw)) < 0.5 else Vector3(0.02, 0.3, 0.44), Game.color_mat(screen, true), false, 0.0)
	_chair(p + Vector3(sin(yaw), 0, cos(yaw)) * 0.8, yaw + PI)

func _chair(p: Vector3, yaw: float, col := Color(0.3, 0.45, 0.8)) -> void:
	cyl(p + Vector3(0, 0.22, 0), 0.05, 0.25, 0.44, _col(Color(0.3, 0.3, 0.33)), false, 6)
	box(p + Vector3(0, 0.48, 0), Vector3(0.5, 0.1, 0.5), _col(col), false, yaw)
	box(p + Vector3(0, 0.8, 0) + Vector3(sin(yaw), 0, cos(yaw)) * -0.22, Vector3(0.5, 0.6, 0.08) if absf(sin(yaw)) < 0.5 else Vector3(0.08, 0.6, 0.5), _col(col), false, 0.0)

func _console(p: Vector3, yaw: float, screen := Color(0.3, 1.0, 0.5)) -> void:
	box(p + Vector3(0, 0.5, 0), Vector3(1.4, 1.0, 0.6), _col(Color(0.7, 0.68, 0.64)), true, yaw)
	var up := p + Vector3(0, 1.45, 0) + Vector3(-sin(yaw), 0, -cos(yaw)) * 0.2
	box(up, Vector3(1.3, 0.8, 0.12), _col(Color(0.5, 0.5, 0.52)), false, yaw)
	box(up + Vector3(sin(yaw), 0, cos(yaw)) * 0.07, Vector3(1.1, 0.6, 0.02) if absf(sin(yaw)) < 0.5 else Vector3(0.02, 0.6, 1.1), Game.color_mat(screen, true), false, 0.0)

func _barrel(p: Vector3) -> void:
	cyl(p + Vector3(0, 0.45, 0), 0.32, 0.32, 0.9, _col(Color(0.38, 0.28, 0.2)), true, 10)
	for y in [0.15, 0.75]:
		cyl(p + Vector3(0, y, 0), 0.335, 0.335, 0.05, _col(Color(0.2, 0.18, 0.17)), false, 10)

func _bunk(p: Vector3, along_x: bool) -> void:
	var yel := _col(Color(0.85, 0.68, 0.2))
	var blue := _col(Color(0.28, 0.48, 0.85))
	var L := 2.0
	var W := 0.9
	var size := Vector3(L, 0.15, W) if along_x else Vector3(W, 0.15, L)
	for y in [0.45, 1.45]:
		box(p + Vector3(0, y, 0), size, blue, y < 1.0)
		box(p + Vector3(0, y - 0.1, 0), size + Vector3(0.06, -0.08, 0.06), yel, false)
		var pil := p + (Vector3(-L / 2 + 0.3, y + 0.12, 0) if along_x else Vector3(0, y + 0.12, -L / 2 + 0.3))
		box(pil, Vector3(0.35, 0.1, 0.6) if along_x else Vector3(0.6, 0.1, 0.35), _col(Color(0.92, 0.92, 0.9)), false)
	for sx in [-1, 1]:
		for sz2 in [-1, 1]:
			var q := p + (Vector3(sx * (L / 2), 0.9, sz2 * (W / 2)) if along_x else Vector3(sx * (W / 2), 0.9, sz2 * (L / 2)))
			box(q, Vector3(0.06, 1.8, 0.06), yel, false)

func _shelf(p: Vector3, along_x: bool, rng_items := true) -> void:
	var L := 2.4
	var grey := _col(Color(0.45, 0.47, 0.52))
	for y in [0.1, 0.8, 1.5, 2.1]:
		box(p + Vector3(0, y, 0), Vector3(L, 0.05, 0.6) if along_x else Vector3(0.6, 0.05, L), grey, y < 0.2)
	for sx in [-1, 1]:
		box(p + (Vector3(sx * L / 2, 1.1, 0) if along_x else Vector3(0, 1.1, sx * L / 2)), Vector3(0.05, 2.2, 0.6) if along_x else Vector3(0.6, 2.2, 0.05), grey, false)
	if rng_items:
		for y in [0.1, 0.8, 1.5]:
			for k in 3:
				if rng.randf() < 0.75:
					var off := (k - 1) * 0.7 + rng.randf_range(-0.1, 0.1)
					var q := p + (Vector3(off, y + 0.2, 0) if along_x else Vector3(0, y + 0.2, off))
					var cc: Color = [Color(0.25, 0.3, 0.22), Color(0.6, 0.5, 0.3), Color(0.7, 0.25, 0.2), Color(0.3, 0.35, 0.45)][rng.randi() % 4]
					box(q, Vector3(0.5, 0.35, 0.45), _col(cc), false)

func _terminal(p: Vector3, yaw: float, kind: String, label: String, screen := Color(0.35, 0.8, 1.0)) -> void:
	_console(p, yaw, screen)
	info["terminals"].append({"pos": p + Vector3(sin(yaw), 0, cos(yaw)) * 0.7, "kind": kind, "label": label})
	var l := OmniLight3D.new()
	l.light_color = screen
	l.light_energy = 0.6
	l.omni_range = 2.5
	root.add_child(l)
	l.position = p + Vector3(0, 1.5, 0) + Vector3(sin(yaw), 0, cos(yaw)) * 0.4

# ---- the facilities ------------------------------------------------------------------------------
func _velin(a: Vector3, w: float, h: float) -> void:
	# the lift to the surface in the north-west corner: a platform, a frame of lamps, the shaft up
	var lp := a + Vector3(1.5, 0, 1.5)
	box(lp + Vector3(0, 0.05, 0), Vector3(2.6, 0.1, 2.6), _col(Color(0.35, 0.36, 0.4)))
	for k in 4:
		var ang := k * PI / 2
		box(lp + Vector3(cos(ang), 0.07, sin(ang)) * 1.25, Vector3(0.1 if k % 2 == 0 else 2.5, 0.02, 2.5 if k % 2 == 0 else 0.1), Game.color_mat(Color(1.0, 0.75, 0.2), true), false)
	for sx in [-1, 1]:
		box(lp + Vector3(sx * 1.4, h + 3.0, 0), Vector3(0.2, 6.0, 3.0), Game.mat("concrete", 0.5))
		box(lp + Vector3(0, h + 3.0, sx * 1.4), Vector3(3.0, 6.0, 0.2), Game.mat("concrete", 0.5))
	var shaft := OmniLight3D.new()
	shaft.light_color = Color(0.7, 0.8, 1.0)
	shaft.light_energy = 0.8
	shaft.omni_range = 5.0
	root.add_child(shaft)
	shaft.position = lp + Vector3(0, h + 2.0, 0)
	for i in 4:
		info["player_spawns"].append(lp + Vector3((i % 2) * 0.9 - 0.45, 0.3, (i / 2) * 0.9 - 0.45))
	info["spawn_yaw"] = PI * 0.75
	# the command table in the middle: a round console, chairs, the globe projected above it
	var c := a + Vector3(w * 0.55, 0, w * 0.55)
	cyl(c + Vector3(0, 0.45, 0), 1.3, 1.1, 0.9, _col(Color(0.62, 0.55, 0.7)), true, 12)
	cyl(c + Vector3(0, 0.92, 0), 1.25, 1.25, 0.04, Game.color_mat(Color(0.25, 0.5, 1.0), true), false, 12)
	var globe := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.45; sm.height = 0.9
	globe.mesh = sm
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = load("res://assets/textures/earth_day.png")
	gm.emission_enabled = true
	gm.emission_texture = gm.albedo_texture
	gm.emission_energy_multiplier = 0.6
	globe.material_override = gm
	root.add_child(globe)
	globe.position = c + Vector3(0, 1.6, 0)
	globe.set_meta("spin", 0.15)
	info.get_or_add("spinners", []).append(globe)
	for k in 6:
		var ang := k * TAU / 6.0
		_chair(c + Vector3(cos(ang), 0, sin(ang)) * 1.9, -ang + PI / 2 + PI)
	# wall consoles: the radar, the reports - and the main terminal (back to the globe)
	_terminal(a + Vector3(w * 0.55, 0, 0.45), 0.0, "globe", "Velín: globus, mise, nákupy a stavby")
	_console(a + Vector3(w - 0.45, 0, w * 0.35), -PI / 2)
	_console(a + Vector3(w - 0.45, 0, w * 0.7), -PI / 2, Color(1.0, 0.75, 0.3))
	_console(a + Vector3(w * 0.4, 0, w - 0.45), PI, Color(0.3, 0.8, 1.0))

func _hangar_hall(a: Vector3, w: float, h: float, transport: String) -> void:
	# yellow dashed lines, a landing square, barrels, the craft in the middle, a ramp up (shut)
	for k in 9:
		box(a + Vector3(1.2 + k * 1.0, 0.01, w * 0.5), Vector3(0.5, 0.02, 0.12), Game.color_mat(Color(0.9, 0.85, 0.75)), false)
		box(a + Vector3(w * 0.5, 0.01, 1.2 + k * 1.0), Vector3(0.12, 0.02, 0.5), Game.color_mat(Color(0.9, 0.85, 0.75)), false)
	var model := "heli" if transport != "kondor" else "dropship"
	var m: Node3D = Game.model(model)
	root.add_child(m)
	m.position = a + Vector3(w * 0.5, 0.0, w * 0.5)
	m.rotation.y = PI * 0.25
	var box_ := _aabb3(m)
	var k2 := minf(1.0, 8.0 / maxf(box_.size.x, box_.size.z))
	m.scale = Vector3.ONE * k2
	var ap: AnimationPlayer = m.find_child("AnimationPlayer", true, false)
	if ap:
		ap.stop()
	# its collision: a simple block (walk round it, not through)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(box_.size.x * k2 * 0.6, 2.0, box_.size.z * k2 * 0.6)
	cs.shape = bs
	sb.add_child(cs)
	root.add_child(sb)
	sb.position = m.position + Vector3(0, 1.0, 0)
	sb.rotation.y = m.rotation.y
	for p in [Vector3(0.8, 0, 0.8), Vector3(1.6, 0, 0.9), Vector3(0.9, 0, 1.7), Vector3(w - 0.8, 0, w - 0.9), Vector3(w - 1.7, 0, w - 0.8)]:
		_barrel(a + p)
	box(a + Vector3(w - 1.0, 1.0, 1.4), Vector3(1.4, 2.0, 2.2), _col(Color(0.2, 0.3, 0.75)))       # loader
	box(a + Vector3(w * 0.5, h - 0.05, w * 0.5), Vector3(w * 0.6, 0.1, w * 0.6), Game.mat("metal", 0.5), false)   # the roof hatch
	_cover(a + Vector3(1.5, 0, 2.5)); _cover(a + Vector3(w - 1.5, 0, w - 2.5))

func _quarters(a: Vector3, w: float) -> void:
	for row in 3:
		for k in 3:
			_bunk(a + Vector3(1.4 + k * 3.2, 0, 1.6 + row * 3.4), true)
	for k in 4:
		_cabinet(a + Vector3(w - 0.4, 0, 1.2 + k * 1.0), -PI / 2, Color(0.4, 0.42, 0.45))

func _lab(a: Vector3, w: float) -> void:
	_terminal(a + Vector3(w * 0.5, 0, 0.45), 0.0, "research", "Laboratoř: strom výzkumu", Color(0.4, 1.0, 0.6))
	_terminal(a + Vector3(0.45, 0, w * 0.5), PI / 2, "ency", "Encyklopedie", Color(0.6, 0.85, 1.0))
	for k in 3:
		_cabinet(a + Vector3(w - 0.4, 0, 1.0 + k * 1.0), -PI / 2, Color(0.3, 0.5, 0.85) if k != 1 else Color(0.2, 0.22, 0.25))
	_desk(a + Vector3(2.4, 0, w - 1.2), PI)
	_desk(a + Vector3(5.0, 0, w - 1.2), PI, Color(1.0, 0.8, 0.3))
	# the autopsy table: steel, a lamp over it, something under a sheet
	var t := a + Vector3(w * 0.6, 0, w * 0.55)
	box(t + Vector3(0, 0.85, 0), Vector3(2.2, 0.08, 1.0), _col(Color(0.75, 0.78, 0.82)))
	box(t + Vector3(0, 0.42, 0), Vector3(0.3, 0.84, 0.3), _col(Color(0.5, 0.52, 0.55)), false)
	box(t + Vector3(0, 1.0, 0), Vector3(1.6, 0.22, 0.6), _col(Color(0.88, 0.9, 0.92)), false)
	cyl(t + Vector3(0, 2.6, 0), 0.4, 0.2, 0.25, _col(Color(0.6, 0.62, 0.66)), false, 10)
	var l := SpotLight3D.new()
	l.light_energy = 2.0
	l.spot_range = 3.0
	l.spot_angle = 35.0
	root.add_child(l)
	l.position = t + Vector3(0, 2.5, 0)
	l.rotation.x = -PI / 2
	_shelf(a + Vector3(w - 2.2, 0, w - 0.5), true)

func _workshop(a: Vector3, w: float) -> void:
	# weapon racks, benches with tools, ammo crates
	var guns := ["rifle", "shotgun", "pistol", "sniper", "minigun"]
	for k in 5:
		var g: Node3D = Game.model(guns[k])
		root.add_child(g)
		g.position = a + Vector3(1.2 + k * 1.6, 1.5, 0.35)
		g.rotation = Vector3(0, PI / 2, PI / 2 * 0.0)
		g.rotation.z = PI / 2
	box(a + Vector3(w / 2, 1.5, 0.15), Vector3(w - 1.0, 1.6, 0.08), _col(Color(0.4, 0.38, 0.35)), false)
	for k in 2:
		var b := a + Vector3(2.5 + k * 4.5, 0, w * 0.55)
		box(b + Vector3(0, 0.9, 0), Vector3(2.6, 0.1, 1.1), _col(Color(0.5, 0.42, 0.32)))
		box(b + Vector3(0, 0.45, 0), Vector3(2.4, 0.9, 0.9), _col(Color(0.3, 0.31, 0.34)), false)
		box(b + Vector3(-0.6, 1.05, 0.1), Vector3(0.5, 0.2, 0.3), _col(Color(0.7, 0.2, 0.15)), false)
		box(b + Vector3(0.5, 1.0, -0.2), Vector3(0.8, 0.1, 0.25), _col(Color(0.25, 0.25, 0.27)), false)
	for k in 4:
		_crate(a + Vector3(1.0 + k * 1.1, 0, w - 0.9), 0.9)
	_cabinet(a + Vector3(w - 0.4, 0, w - 1.5), -PI / 2, Color(0.2, 0.22, 0.25))

func _infirmary(a: Vector3, w: float) -> void:
	for k in 4:
		var b := a + Vector3(1.6 + k * 2.3, 0, 1.6)
		box(b + Vector3(0, 0.55, 0), Vector3(1.0, 0.15, 2.1), _col(Color(0.92, 0.93, 0.95)))
		box(b + Vector3(0, 0.25, 0), Vector3(0.9, 0.5, 2.0), _col(Color(0.6, 0.62, 0.66)), false)
		box(b + Vector3(0, 0.66, -0.75), Vector3(0.7, 0.1, 0.35), _col(Color(1, 1, 1)), false)
		box(b + Vector3(1.0, 1.1, 0), Vector3(0.04, 2.2, 2.2), _col(Color(0.55, 0.75, 0.75)), false)    # curtain
	_cabinet(a + Vector3(w - 0.4, 0, w - 1.5), -PI / 2, Color(0.9, 0.9, 0.92))
	_cabinet(a + Vector3(w - 0.4, 0, w - 2.5), -PI / 2, Color(0.9, 0.9, 0.92))
	_desk(a + Vector3(2.0, 0, w - 1.0), PI)

func _radar_room(a: Vector3, w: float, h: float) -> void:
	# a big screen with the sweep, consoles in a row
	box(a + Vector3(w / 2, 1.8, 0.2), Vector3(5.0, 2.4, 0.1), _col(Color(0.15, 0.17, 0.2)), false)
	var scr := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0; cm.bottom_radius = 1.0; cm.height = 0.02
	scr.mesh = cm
	scr.material_override = Game.color_mat(Color(0.2, 0.9, 0.35), true)
	root.add_child(scr)
	scr.position = a + Vector3(w / 2, 1.8, 0.27)
	scr.rotation.x = PI / 2
	for k in 4:
		_console(a + Vector3(1.8 + k * 2.2, 0, 3.0), PI)
		_chair(a + Vector3(1.8 + k * 2.2, 0, 3.8), 0.0)

func _containment(a: Vector3, w: float, live: Array) -> void:
	# glass cells along the walls, a chair with straps in each - and whoever we brought home alive
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.4, 0.65, 1.0, 0.3)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.emission_enabled = true
	glass.emission = Color(0.1, 0.25, 0.5)
	var spots := [Vector3(1.6, 0, 1.6), Vector3(4.2, 0, 1.6), Vector3(6.8, 0, 1.6), Vector3(1.6, 0, w - 1.6), Vector3(4.2, 0, w - 1.6), Vector3(6.8, 0, w - 1.6)]
	for i in spots.size():
		var p: Vector3 = a + spots[i]
		box(p + Vector3(0, 1.2, 1.15 * (1 if spots[i].z < w / 2 else -1)), Vector3(2.4, 2.4, 0.05), glass, true)
		box(p + Vector3(1.2, 1.2, 0), Vector3(0.05, 2.4, 2.4), glass, true)
		box(p + Vector3(-1.2, 1.2, 0), Vector3(0.05, 2.4, 2.4), glass, true)
		box(p + Vector3(0, 2.42, 0), Vector3(2.4, 0.05, 2.4), _col(Color(0.5, 0.52, 0.6)), false)
		if i < live.size():
			var who: Node3D = Game.model(String(live[i]))
			root.add_child(who)
			who.position = p
			who.rotation.y = 0.0 if spots[i].z < w / 2 else PI
			var ap: AnimationPlayer = who.find_child("AnimationPlayer", true, false)
			if ap and ap.has_animation("idle"):
				ap.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
				ap.play("idle")
		else:
			_chair(p, 0.0 if spots[i].z < w / 2 else PI, Color(0.55, 0.3, 0.6))
	_terminal(a + Vector3(w - 0.45, 0, w / 2), -PI / 2, "ency", "Encyklopedie", Color(0.6, 0.85, 1.0))

func _stores(a: Vector3, w: float) -> void:
	for k in 3:
		_shelf(a + Vector3(2.0 + k * 3.0, 0, 2.5), true)
		_shelf(a + Vector3(2.0 + k * 3.0, 0, 6.0), true)
	for p in [Vector3(w - 1.0, 0, w - 1.0), Vector3(w - 1.8, 0, w - 1.0)]:
		_barrel(a + p)

## Still being built: bare walls, scaffolding, crates, a work lamp.
func _construction(a: Vector3, w: float, h: float) -> void:
	var pipe := _col(Color(0.7, 0.55, 0.2))
	for k in 3:
		var p := a + Vector3(1.5 + k * 3.5, 0, 0.8)
		for y in [0.0, 1.5]:
			box(p + Vector3(0, y + 1.5, 0), Vector3(3.0, 0.08, 0.8), _col(Color(0.5, 0.4, 0.3)), false)
		for sx in [-1.4, 1.4]:
			box(p + Vector3(sx, 1.5, 0), Vector3(0.06, 3.0, 0.06), pipe, false)
	for k in 5:
		_crate(a + Vector3(rng.randf_range(2, w - 2), 0, rng.randf_range(3, w - 2)), rng.randf_range(0.85, 1.1), rng.randf() * TAU)
	box(a + Vector3(w / 2, 0.01, w - 1.5), Vector3(4.0, 0.02, 0.3), Game.color_mat(Color(0.9, 0.75, 0.1)), false)

func _aabb3(n: Node3D) -> AABB:
	var box_ := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c
		var b: AABB = (n.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
		box_ = b if first else box_.merge(b)
		first = false
	return box_
