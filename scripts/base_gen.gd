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
var attack := false       # they are coming: the fuses are out, only the red emergency lamps blink
var blips: Array = []     # [lat, lon] of what the radar sees (red dots on the globe screens)
var _globe_tex: Texture2D
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
	info["alarm_red"] = []
	info["alarm_orange"] = []
	info["entries"] = []
	info["spinners"] = []
	info["passages"] = []
	attack = bool(params.get("attack", false))
	blips = params.get("blips", [])
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
	box(Vector3(gw * BLOCK / 2, -0.6, gh * BLOCK / 2 - BLOCK / 2), Vector3(gw * BLOCK + 4, 1.0, gh * BLOCK + BLOCK + 4), Game.mat("earth", 0.5))    # (the hangar reaches one block north)
	if attack:
		# the team wakes in the quarters (or wherever the velín put them)
		for i in cells.size():
			if String(cells[i].get("type", "")) == "ubikace" and float(cells[i].get("days", 0.0)) <= 0.0:
				var o := Vector3((i % gw) * BLOCK + IN, 0, (i / gw) * BLOCK + IN)
				info["player_spawns"] = [o + Vector3(4.4, 0.3, 2.8), o + Vector3(7.6, 0.3, 2.8), o + Vector3(6.0, 0.3, 4.2), o + Vector3(6.0, 0.3, 7.8)]
				info["spawn_yaw"] = PI
				break
		info["alien_spawns"] = info["entries"].duplicate()
	if info["player_spawns"].is_empty():
		info["player_spawns"].append(Vector3(6, 0.3, 6))
	info["evac"] = Vector3.ZERO
	info["ufo"] = Vector3.ZERO
	info["waypoints"] = info["cover"].duplicate()
	if not params.get("no_nav", false):        # (the base screen's top-down picture needs no paths)
		nav.bake_navigation_mesh(false)
	if Game.autotest() != "": print("[BASE] built %d ms" % (Time.get_ticks_msec() - _t0))
	return info

func _built(gx: int, gz: int) -> bool:
	if gx < 0 or gz < 0 or gx >= gw or gz >= gh:
		return false
	return String(cells[gz * gw + gx].get("type", "")) != ""

func _ready(gx: int, gz: int) -> bool:
	return _built(gx, gz) and float(cells[gz * gw + gx].get("days", 0.0)) <= 0.0

## One facility: floor, walls with doorways towards built neighbours, ceiling, lights, furniture.
func _room(gx: int, gz: int, kind: String, building: bool, params: Dictionary) -> void:
	var o := Vector3(gx * BLOCK, 0, gz * BLOCK)
	var a := o + Vector3(IN, 0, IN)                 # inner corner
	var w := BLOCK - IN * 2                        # 10 m inside
	if kind == "hangar" and gz == 0 and not building:
		_big_hangar(gx, params)
		return
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
	var dm := (DOOR[0] + DOOR[1]) / 2.0 - IN
	if not building:
		if n and _ready(gx, gz - 1): info["passages"].append({"c": a + Vector3(dm, 0, 0), "n": Vector3(0, 0, 1)})
		if s and _ready(gx, gz + 1): info["passages"].append({"c": a + Vector3(dm, 0, w), "n": Vector3(0, 0, -1)})
		if we and _ready(gx - 1, gz): info["passages"].append({"c": a + Vector3(0, 0, dm), "n": Vector3(1, 0, 0)})
		if e and _ready(gx + 1, gz): info["passages"].append({"c": a + Vector3(w, 0, dm), "n": Vector3(-1, 0, 0)})
	# ceiling (a hole over the lift), skirting light strips
	if kind == "velin":
		box(a + Vector3(w / 2 + 1.5, h + 0.1, w / 2), Vector3(w - 3.0, 0.2, w), Game.mat("base_wall", 0.5))
		box(a + Vector3(1.5, h + 0.1, w / 2 + 1.5), Vector3(3.0, 0.2, w - 3.0), Game.mat("base_wall", 0.5))
	else:
		box(a + Vector3(w / 2, h + 0.1, w / 2), Vector3(w, 0.2, w), Game.mat("base_wall", 0.5))
	# corridors to the east and south neighbours (each pair once)
	if e:
		_corridor(o + Vector3(BLOCK - IN, 0, BLOCK / 2), true)
		if not building and _ready(gx + 1, gz): _blast_door(o + Vector3(BLOCK, 0, BLOCK / 2), false)
	if s:
		_corridor(o + Vector3(BLOCK / 2, 0, BLOCK - IN), false)
		if not building and _ready(gx, gz + 1): _blast_door(o + Vector3(BLOCK / 2, 0, BLOCK), true)
	# light: panels in the ceiling
	var lc := Color(1.0, 0.93, 0.82) if not building else Color(1.0, 0.7, 0.4)
	for lp in ([Vector3(w * 0.3, 0, w * 0.5), Vector3(w * 0.7, 0, w * 0.5)] if kind != "hangar" else [Vector3(w * 0.25, 0, w * 0.25), Vector3(w * 0.75, 0, w * 0.25), Vector3(w * 0.25, 0, w * 0.75), Vector3(w * 0.75, 0, w * 0.75)]):
		var l := OmniLight3D.new()
		l.light_color = lc
		l.light_energy = (1.3 if not building else 0.6) if not attack else 0.0
		l.omni_range = 8.0 if kind != "hangar" else 11.0
		l.omni_attenuation = 1.2
		root.add_child(l)
		l.position = a + lp + Vector3(0, h - 0.4, 0)
		box(a + lp + Vector3(0, h - 0.02, 0), Vector3(1.6, 0.05, 0.5), Game.color_mat(lc, true) if not attack else _col(Color(0.25, 0.24, 0.22)), false)
	_alarms(a, w, h)
	_cables(a, w, h, kind)
	if building:
		_construction(a, w, h)
		# every way in is shut: a steel door half across, the tape, the sign; nobody gets past
		var mid := (DOOR[0] + DOOR[1]) / 2.0 - IN
		if n: _blockade(a + Vector3(mid, 0, 0), true, 1.0)
		if s: _blockade(a + Vector3(mid, 0, w), true, -1.0)
		if we: _blockade(a + Vector3(0, 0, mid), false, 1.0)
		if e: _blockade(a + Vector3(w, 0, mid), false, -1.0)
		_workers(a, w)
		info["sounds"].append({"name": "base_repair", "pos": a + Vector3(w / 2, 1.5, w / 2), "db": -8.0})
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
		"strelnice": _range(a, w)
		"silo": _silo(a, w)
		"laser_vez": _tower_room(a, w, Color(0.75, 0.35, 1.0))
		"plazma_vez": _tower_room(a, w, Color(0.35, 1.0, 0.45))
		"maskovani": _cloak_core(a, w)
		"psi_gen": _psi_shield(a, w)
	_cover(a + Vector3(1.0, 0, 1.0)); _cover(a + Vector3(w - 1.0, 0, w - 1.0))

## 0.60: a steel blast door in the middle of a corridor between two working rooms (E shuts and
## opens it, it slides into the wall; the mission hangs it like the house doors, see mission._hang_doors).
## Open in peace, so the walk round the base is as before; the defenders shut them themselves.
func _blast_door(c: Vector3, along_x: bool) -> void:
	info["doors"].append({"c": c, "along_x": along_x, "w": DOOR[1] - DOOR[0], "h": H - 0.6, "open": true, "kind": "blast"})

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

## The hangar: a hall twice as deep as a room (it reaches north under the hill, out of the grid)
## and 10 m high, so the transport stands in it at its real size.
func _big_hangar(gx: int, params: Dictionary) -> void:
	var gz := 0
	var a := Vector3(gx * BLOCK + IN, 0, -BLOCK + IN)      # north-west inner corner
	var w := BLOCK - IN * 2                                # 10 m wide
	var dd := BLOCK * 2 - IN * 2                           # 22 m deep
	var h := 10.0
	var wall := Game.mat("base_wall", 0.5)
	box(a + Vector3(w / 2, -0.05, dd / 2), Vector3(w + 0.5, 0.1, dd + 0.5), Game.mat("hangar_floor", 0.5))
	var s := _built(gx, gz + 1)
	var we := _built(gx - 1, gz)
	var e := _built(gx + 1, gz)
	# doors to the neighbours: in the south half (the part inside the grid)
	var side_gap := [[BLOCK + DOOR[0] - IN, BLOCK + DOOR[1] - IN]]
	_wall(a, w, true, h, wall, [])
	_wall(a + Vector3(0, 0, dd), w, true, h, wall, [[DOOR[0] - IN, DOOR[1] - IN]] if s else [])
	_wall(a, dd, false, h, wall, side_gap if we else [])
	_wall(a + Vector3(w, 0, 0), dd, false, h, wall, side_gap if e else [])
	box(a + Vector3(w / 2, h + 0.1, dd / 2), Vector3(w, 0.2, dd), wall)
	# the low doorways need a lintel down to the corridors' height
	var dm := (DOOR[0] + DOOR[1]) / 2.0 - IN
	if s:
		box(a + Vector3(dm, (h + H) / 2.0, dd), Vector3(DOOR[1] - DOOR[0], h - H, 0.25), wall)
		if _ready(gx, gz + 1): info["passages"].append({"c": a + Vector3(dm, 0, dd), "n": Vector3(0, 0, -1)})
	for sd in [[we, 0.0, Vector3(1, 0, 0), gx - 1], [e, w, Vector3(-1, 0, 0), gx + 1]]:
		if sd[0]:
			box(a + Vector3(sd[1], (h + H) / 2.0, BLOCK + dm), Vector3(0.25, h - H, DOOR[1] - DOOR[0]), wall)
			if _ready(sd[3], gz): info["passages"].append({"c": a + Vector3(sd[1], 0, BLOCK + dm), "n": sd[2]})
	if e:
		_corridor(Vector3(gx * BLOCK, 0, 0) + Vector3(BLOCK - IN, 0, BLOCK / 2), true)
		if _ready(gx + 1, gz): _blast_door(Vector3(gx * BLOCK, 0, 0) + Vector3(BLOCK, 0, BLOCK / 2), false)
	if s:
		_corridor(Vector3(gx * BLOCK, 0, 0) + Vector3(BLOCK / 2, 0, BLOCK - IN), false)
		if _ready(gx, gz + 1): _blast_door(Vector3(gx * BLOCK, 0, 0) + Vector3(BLOCK / 2, 0, BLOCK), true)
	# floodlights in rows
	for lz in [0.2, 0.5, 0.8]:
		for lx in [0.3, 0.7]:
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.95, 0.85)
			l.light_energy = 1.6 if not attack else 0.0
			l.omni_range = 11.0
			l.omni_attenuation = 1.1
			root.add_child(l)
			l.position = a + Vector3(w * lx, h - 0.6, dd * lz)
			box(a + Vector3(w * lx, h - 0.03, dd * lz), Vector3(1.8, 0.06, 0.6), Game.color_mat(Color(1.0, 0.95, 0.85), true) if not attack else _col(Color(0.25, 0.24, 0.22)), false)
	_alarms(a, w, h)
	_alarms(a + Vector3(0, 0, BLOCK), w, h)
	_cables(a + Vector3(0, 0, BLOCK), w, h, "hangar")
	# the floor: yellow centre line, a landing square, the lift platform under the roof hatch
	for k in 18:
		box(a + Vector3(w * 0.5, 0.01, 1.5 + k * 1.1), Vector3(0.12, 0.02, 0.55), Game.color_mat(Color(0.9, 0.8, 0.2)), false)
	for sx in [-1, 1]:
		box(a + Vector3(w * 0.5 + sx * 3.6, 0.01, dd / 2), Vector3(0.12, 0.02, dd - 3.0), Game.color_mat(Color(0.9, 0.85, 0.75)), false)
	box(a + Vector3(w * 0.5, h - 0.05, dd * 0.45), Vector3(w * 0.7, 0.1, dd * 0.6), Game.mat("metal", 0.5), false)   # the roof hatch
	# the transport at full size, nose to the north
	var transport := String(params.get("transport", "heli"))
	var model := "heli" if transport != "kondor" else "dropship"
	var m: Node3D = Game.model(model)
	root.add_child(m)
	m.position = a + Vector3(w * 0.5, 0.0, dd * 0.47)
	m.rotation.y = 0.0
	# parked: the rotor blades folded along the body (as on a real carrier deck)
	for rn in ["RotorF", "RotorR", "PropL", "PropR"]:
		var r: Node3D = m.find_child(rn, true, false)
		if r == null:
			continue
		var best_a := 0.0
		var best_w := INF
		for k in 8:
			r.rotation.y = k * PI / 8.0
			var wx := _aabb3(m).size.x
			if wx < best_w:
				best_w = wx
				best_a = r.rotation.y
		r.rotation.y = best_a
	var bb := _aabb3(m)
	var fit := minf(1.0, minf((w - 0.6) / maxf(bb.size.x, 0.1), (dd - 3.0) / maxf(bb.size.z, 0.1)))
	m.scale = Vector3.ONE * fit
	var ap: AnimationPlayer = m.find_child("AnimationPlayer", true, false)
	if ap:
		ap.stop()
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(bb.size.x * fit * 0.55, 2.4, bb.size.z * fit * 0.8)
	cs.shape = bs
	sb.add_child(cs)
	root.add_child(sb)
	sb.position = m.position + Vector3(0, 1.2, 0)
	if Game.autotest() != "": print("[BASE] hangar transport %s size %s fit %.2f" % [model, str(bb.size), fit])
	# around it: barrels, a fuel cart, the loader, tool carts, cover
	for p in [Vector3(0.8, 0, 1.0), Vector3(1.6, 0, 1.1), Vector3(0.9, 0, 2.0), Vector3(w - 0.8, 0, dd - 1.0), Vector3(w - 1.7, 0, dd - 0.9)]:
		_barrel(a + p)
	box(a + Vector3(w - 1.0, 1.0, 2.5), Vector3(1.4, 2.0, 2.2), _col(Color(0.2, 0.3, 0.75)))       # loader
	_cabinet(a + Vector3(0.4, 0, dd - 3.0), PI / 2, Color(0.55, 0.45, 0.15))
	_cabinet(a + Vector3(0.4, 0, dd - 4.0), PI / 2, Color(0.55, 0.45, 0.15))
	info["entries"].append(a + Vector3(2.0, 0.3, 2.0))
	_cover(a + Vector3(1.5, 0, 4.5)); _cover(a + Vector3(w - 1.5, 0, dd - 4.5)); _cover(a + Vector3(1.5, 0, dd - 6.0))

# ---- furniture ----------------------------------------------------------------------------------
func _col(c: Color) -> Material:
	return Game.color_mat(c)

## 0.56: the furniture is modelled (tools/blender/base_props.py); the old blocks stay as the hidden colliders.
## A prop's front is -Z, a thing's front here is +Z at yaw 0: turned by yaw + PI.
func _bp(name: String, p: Vector3, yaw: float) -> Node3D:
	return _prop(name, p, yaw + PI, false)

func _cabinet(p: Vector3, yaw: float, col: Color) -> void:
	box(p + Vector3(0, 1.0, 0), Vector3(0.9, 2.0, 0.6), _col(col), true, yaw).visible = false
	var paint := "grey"
	if col.r > 0.8:
		paint = "white"
	elif col.b > 0.7:
		paint = "blue"
	elif col.r < 0.25:
		paint = "dark"
	_bp("bp_locker_" + paint, p, yaw)

func _desk(p: Vector3, yaw: float, screen := Color(0.3, 1.0, 0.5)) -> void:
	box(p + Vector3(0, 0.75, 0), Vector3(1.6, 0.06, 0.8), _col(Color(0.55, 0.57, 0.6)), true, yaw).visible = false
	_bp("bp_desk", p, yaw)
	var back := Vector3(-sin(yaw), 0, -cos(yaw)) * 0.2
	box(p + back + Vector3(0, 1.02, 0) + Vector3(sin(yaw), 0, cos(yaw)) * 0.19, Vector3(0.44, 0.3, 0.02) if absf(sin(yaw)) < 0.5 else Vector3(0.02, 0.3, 0.44), Game.color_mat(screen, true), false, 0.0)
	_chair(p + Vector3(sin(yaw), 0, cos(yaw)) * 0.8, yaw + PI)

func _chair(p: Vector3, yaw: float, _col_unused := Color(0.3, 0.45, 0.8)) -> void:
	_bp("bp_chair", p, yaw)

func _console(p: Vector3, yaw: float, screen := Color(0.3, 1.0, 0.5)) -> void:
	box(p + Vector3(0, 0.5, 0), Vector3(1.4, 1.0, 0.6), _col(Color(0.7, 0.68, 0.64)), true, yaw).visible = false
	_bp("bp_console", p, yaw)
	var up := p + Vector3(0, 1.45, 0) + Vector3(-sin(yaw), 0, -cos(yaw)) * 0.2
	box(up + Vector3(sin(yaw), 0, cos(yaw)) * 0.075, Vector3(1.1, 0.6, 0.02) if absf(sin(yaw)) < 0.5 else Vector3(0.02, 0.6, 1.1), Game.color_mat(screen, true), false, 0.0)

func _barrel(p: Vector3) -> void:
	_prop("drum_blue" if rng.randf() < 0.6 else "drum_red", p, rng.randf() * TAU, false)

func _bunk(p: Vector3, along_x: bool) -> void:
	var yel := _col(Color(0.85, 0.68, 0.2))
	var blue := _col(Color(0.28, 0.48, 0.85))
	var L := 2.0
	var W := 0.9
	var size := Vector3(L, 0.15, W) if along_x else Vector3(W, 0.15, L)
	box(p + Vector3(0, 0.45, 0), size, blue, true).visible = false
	_prop("bp_bunk", p, 0.0 if along_x else -PI / 2, false)

func _shelf(p: Vector3, along_x: bool, rng_items := true) -> void:
	var L := 2.4
	var grey := _col(Color(0.45, 0.47, 0.52))
	box(p + Vector3(0, 0.1, 0), Vector3(L, 0.05, 0.6) if along_x else Vector3(0.6, 0.05, L), grey, true).visible = false
	_prop("bp_rack", p, 0.0 if along_x else -PI / 2, false)
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
	info["entries"].append(lp + Vector3(0, 0.3, 0))
	info["spawn_yaw"] = PI * 0.75
	# the command table in the middle: a round console, chairs, the globe projected above it
	var c := a + Vector3(w * 0.55, 0, w * 0.55)
	cyl(c + Vector3(0, 0.45, 0), 1.3, 1.1, 0.9, _col(Color(0.62, 0.55, 0.7)), true, 12).visible = false
	_prop("bp_command_table", c, 0.0, false)
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
	# (the middle of every wall is a doorway - all of it sits in the corners)
	_terminal(a + Vector3(w * 0.76, 0, 0.45), 0.0, "globe", "Velín: globus, mise, nákupy a stavby")
	_monitor_wall(a + Vector3(w - 0.08, 0, 1.6), -PI / 2, 1, 2.5)
	_monitor_wall(a + Vector3(w - 0.08, 0, w - 1.6), -PI / 2, 1, 2.5)
	_console(a + Vector3(w - 0.45, 0, 1.6), -PI / 2)
	_console(a + Vector3(w - 0.45, 0, w - 1.6), -PI / 2, Color(1.0, 0.75, 0.3))
	_console(a + Vector3(w * 0.78, 0, w - 0.45), PI, Color(0.3, 0.8, 1.0))

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
	box(a + Vector3(w - 1.0, 1.0, 1.4), Vector3(1.4, 2.0, 2.2), _col(Color(0.2, 0.3, 0.75))).visible = false       # loader
	_prop("bp_loader", a + Vector3(w - 1.0, 0, 1.4), 0.0, false)
	box(a + Vector3(w * 0.5, h - 0.05, w * 0.5), Vector3(w * 0.6, 0.1, w * 0.6), Game.mat("metal", 0.5), false)   # the roof hatch
	info["entries"].append(a + Vector3(2.0, 0.3, w - 2.0))
	_cover(a + Vector3(1.5, 0, 2.5)); _cover(a + Vector3(w - 1.5, 0, w - 2.5))

func _quarters(a: Vector3, w: float) -> void:
	# bunks in the corners and one in the middle: the doorways stay free
	for bp in [Vector3(1.8, 0, 1.3), Vector3(1.8, 0, 2.7), Vector3(1.8, 0, w - 2.7), Vector3(1.8, 0, w - 1.3),
			Vector3(w - 1.8, 0, w - 2.7), Vector3(w - 1.8, 0, w - 1.3), Vector3(w / 2, 0, w / 2)]:
		_bunk(a + bp, true)
	for k in 3:
		_cabinet(a + Vector3(w - 0.4, 0, 0.9 + k * 0.95), -PI / 2, Color(0.4, 0.42, 0.45))

func _lab(a: Vector3, w: float) -> void:
	_terminal(a + Vector3(w * 0.76, 0, 0.45), 0.0, "research", "Laboratoř: strom výzkumu", Color(0.4, 1.0, 0.6))
	_monitor_wall(a + Vector3(w * 0.76, 0, 0.08), 0.0, 1, 2.6)
	_terminal(a + Vector3(0.45, 0, 2.2), PI / 2, "ency", "Encyklopedie", Color(0.6, 0.85, 1.0))
	for k in 3:
		_cabinet(a + Vector3(w - 0.4, 0, 1.0 + k * 1.0), -PI / 2, Color(0.3, 0.5, 0.85) if k != 1 else Color(0.2, 0.22, 0.25))
	_desk(a + Vector3(2.2, 0, w - 1.0), PI)
	_desk(a + Vector3(1.0, 0, w - 3.0), PI / 2, Color(1.0, 0.8, 0.3))
	# the autopsy table: steel, a lamp over it, something under a sheet
	var t := a + Vector3(w * 0.6, 0, w * 0.55)
	box(t + Vector3(0, 0.85, 0), Vector3(2.2, 0.08, 1.0), _col(Color(0.75, 0.78, 0.82))).visible = false
	_prop("bp_autopsy", t, 0.0, false)
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
		g.position = a + Vector3(0.9 + k * 0.6, 1.5, 0.35)
		g.rotation = Vector3(0, PI / 2, PI / 2 * 0.0)
		g.rotation.z = PI / 2
	box(a + Vector3(2.1, 1.5, 0.15), Vector3(3.2, 1.6, 0.08), _col(Color(0.4, 0.38, 0.35)), false)
	for k in 2:
		var b := a + Vector3(3.2 + k * 3.6, 0, w * 0.55)
		box(b + Vector3(0, 0.46, 0), Vector3(1.8, 0.92, 0.75), _col(Color(0.5, 0.42, 0.32))).visible = false
		_prop("workbench", b, PI if k == 0 else 0.0, false)
	for k in 3:
		_crate(a + Vector3(1.0 + k * 1.1, 0, w - 0.9), 0.9)
	_cabinet(a + Vector3(w - 0.4, 0, w - 1.5), -PI / 2, Color(0.2, 0.22, 0.25))

func _infirmary(a: Vector3, w: float) -> void:
	for bx in [1.2, 2.8, w - 2.8, w - 1.2]:
		var b := a + Vector3(bx, 0, 1.6)
		box(b + Vector3(0, 0.55, 0), Vector3(1.0, 0.15, 2.1), _col(Color(0.92, 0.93, 0.95))).visible = false
		_prop("bp_sickbed", b, 0.0, false)
		_prop("bp_curtain", b + Vector3(0.8 if bx < w / 2 else -0.8, 0, 0), 0.0, false)
	_cabinet(a + Vector3(w - 0.4, 0, w - 1.5), -PI / 2, Color(0.9, 0.9, 0.92))
	_cabinet(a + Vector3(w - 0.4, 0, w - 2.5), -PI / 2, Color(0.9, 0.9, 0.92))
	_desk(a + Vector3(2.0, 0, w - 1.0), PI)

func _radar_room(a: Vector3, w: float, h: float) -> void:
	# a big screen with the sweep, consoles in a row
	box(a + Vector3(2.0, 1.8, 0.2), Vector3(3.2, 2.4, 0.1), _col(Color(0.15, 0.17, 0.2)), false)
	var scr := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0; cm.bottom_radius = 1.0; cm.height = 0.02
	scr.mesh = cm
	scr.material_override = Game.color_mat(Color(0.2, 0.9, 0.35), true)
	root.add_child(scr)
	scr.position = a + Vector3(2.0, 1.8, 0.27)
	scr.rotation.x = PI / 2
	_monitor_wall(a + Vector3(0.08, 0, w - 2.0), PI / 2, 2)
	for k in 4:
		_console(a + Vector3(2.6 + k * 1.6, 0, 3.0), PI)
		_chair(a + Vector3(2.6 + k * 1.6, 0, 3.8), 0.0)

func _containment(a: Vector3, w: float, live: Array) -> void:
	# glass cells along the walls, a chair with straps in each - and whoever we brought home alive
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.4, 0.65, 1.0, 0.3)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.emission_enabled = true
	glass.emission = Color(0.1, 0.25, 0.5)
	var spots := [Vector3(1.6, 0, 1.6), Vector3(w - 1.6, 0, 1.6), Vector3(1.6, 0, w - 1.6), Vector3(w - 1.6, 0, w - 1.6)]
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
	_terminal(a + Vector3(w / 2, 0, w / 2), 0.0, "ency", "Encyklopedie", Color(0.6, 0.85, 1.0))

# ---- 0.57: the defences -----------------------------------------------------------------------
## Raketové silo: a round shaft through the middle with a rocket standing in it, the launch desk by the wall.
func _silo(a: Vector3, w: float) -> void:
	var c := a + Vector3(w / 2, 0, w / 2)
	var steel := _col(Color(0.32, 0.34, 0.36))
	# the shaft: a black hole in the floor with a railing round it (it goes down out of sight)
	cyl(c + Vector3(0, 0.005, 0), 2.45, 2.45, 0.01, _col(Color(0.8, 0.65, 0.1)), false, 16)
	cyl(c + Vector3(0, 0.015, 0), 2.3, 2.3, 0.01, _col(Color(0.02, 0.02, 0.025)), false, 16)
	for k in 12:
		var ang := TAU * k / 12.0
		box(c + Vector3(cos(ang) * 2.5, 0.55, sin(ang) * 2.5), Vector3(0.07, 1.1, 0.07), steel, true)
		var ang2 := ang + TAU / 24.0
		box(c + Vector3(cos(ang2) * 2.5, 1.08, sin(ang2) * 2.5), Vector3(1.3, 0.06, 0.06), steel, false, -ang2 - PI / 2)
	# the rocket standing in it, only the top half above the floor: white body, red tip, fins
	cyl(c + Vector3(0, 0.4, 0), 0.45, 0.45, 3.6, _col(Color(0.88, 0.88, 0.85)), true, 10)
	cyl(c + Vector3(0, 2.6, 0), 0.05, 0.45, 0.8, _col(Color(0.75, 0.15, 0.12)), false, 10)
	box(c + Vector3(0, 1.2, 0), Vector3(0.95, 0.12, 0.95), _col(Color(0.75, 0.15, 0.12)), false)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.45, 0.3)
	l.light_energy = 0.8
	l.omni_range = 5.0
	root.add_child(l)
	l.position = c + Vector3(0, 2.6, 0)
	for k in 3:
		_console(a + Vector3(2.2 + k * 1.5, 0, 0.6), 0.0, Color(1.0, 0.55, 0.3))
	_cabinet(a + Vector3(w - 0.4, 0, w - 1.5), -PI / 2, Color(0.25, 0.3, 0.25))

## Laserové / plazmové věže: the room under the turrets - the lift column up to them, the gunners' seats.
func _tower_room(a: Vector3, w: float, col: Color) -> void:
	var c := a + Vector3(w / 2, 0, w / 2)
	cyl(c + Vector3(0, (H - 0.6) / 2, 0), 1.0, 1.0, H - 0.6, _col(Color(0.22, 0.24, 0.27)), true, 12)
	cyl(c + Vector3(0, 1.4, 0), 1.03, 1.03, 0.12, Game.color_mat(col, true), false, 12)
	cyl(c + Vector3(0, 2.4, 0), 1.03, 1.03, 0.12, Game.color_mat(col, true), false, 12)
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 0.9
	l.omni_range = 5.0
	root.add_child(l)
	l.position = c + Vector3(0, 2.0, 1.4)
	for k in 4:
		var ang := TAU * k / 4.0 + PI / 4
		var p := c + Vector3(cos(ang) * 3.4, 0, sin(ang) * 3.4)
		_console(p, atan2(c.x - p.x, c.z - p.z), col)
		_chair(p + (p - c).normalized() * 0.8, atan2(c.x - p.x, c.z - p.z) + PI)
	_monitor_wall(a + Vector3(0.08, 0, w - 2.0), PI / 2, 2)

## Maskující jádro: a cage round a slowly pulsing green core, cables out to the walls.
func _cloak_core(a: Vector3, w: float) -> void:
	var c := a + Vector3(w / 2, 0, w / 2)
	cyl(c + Vector3(0, 0.15, 0), 1.6, 1.8, 0.3, _col(Color(0.2, 0.22, 0.24)), true, 12)
	var core := cyl(c + Vector3(0, 1.5, 0), 0.55, 0.55, 2.2, Game.color_mat(Color(0.3, 1.0, 0.55), true), true, 12)
	core.set_meta("pulse", true)
	for k in 8:
		var ang := TAU * k / 8.0
		box(c + Vector3(cos(ang) * 1.3, 1.5, sin(ang) * 1.3), Vector3(0.08, 2.8, 0.08), _col(Color(0.4, 0.42, 0.45)), false)
	cyl(c + Vector3(0, 2.95, 0), 1.4, 1.4, 0.1, _col(Color(0.4, 0.42, 0.45)), false, 12)
	var l := OmniLight3D.new()
	l.light_color = Color(0.35, 1.0, 0.55)
	l.light_energy = 1.4
	l.omni_range = 7.0
	root.add_child(l)
	l.position = c + Vector3(0, 1.6, 0)
	info["lights"].append(l)
	for k in 4:
		var ang2 := TAU * k / 4.0
		box(c + Vector3(cos(ang2) * 3.4, 0.05, sin(ang2) * 3.4), Vector3(0.25 if k % 2 == 0 else 3.4, 0.08, 3.4 if k % 2 == 0 else 0.25), _col(Color(0.1, 0.1, 0.12)), false)
	_console(a + Vector3(1.5, 0, 0.6), 0.0, Color(0.35, 1.0, 0.55))
	info["sounds"].append({"name": "ufo_hum", "pos": c + Vector3(0, 1.5, 0), "db": -14.0})

## X-PSI-001 (0.57): the stationary psionic shield PSF-01 - a ribbed generator column on a plinth,
## the violet resonator core, two tilted rings turning around it, four emitter masts in the corners
## aimed at it, coolant pipes into the floor, the control desk and its warning ring on the floor.
func _psi_shield(a: Vector3, w: float) -> void:
	var c := a + Vector3(w / 2, 0, w / 2)
	var steel := _col(Color(0.34, 0.36, 0.4))
	var dark := _col(Color(0.16, 0.17, 0.2))
	var violet := Color(0.72, 0.42, 1.0)
	var glow := Game.color_mat(violet, true)
	# the floor: a yellow-black warning ring, a dark disc inside, the plinth
	cyl(c + Vector3(0, 0.006, 0), 2.75, 2.75, 0.012, Game.color_mat(Color(0.9, 0.72, 0.1)), false, 24)
	cyl(c + Vector3(0, 0.012, 0), 2.5, 2.5, 0.012, dark, false, 24)
	for k in 12:
		var ang := TAU * k / 12.0
		box(c + Vector3(cos(ang) * 2.62, 0.02, sin(ang) * 2.62), Vector3(0.34, 0.012, 0.14), dark, false, -ang)
	cyl(c + Vector3(0, 0.18, 0), 1.55, 1.75, 0.36, dark, true, 16)
	cyl(c + Vector3(0, 0.42, 0), 1.25, 1.35, 0.14, steel, false, 16)
	# the generator: a ribbed housing, the glowing core above it, a heavy cap and the antenna
	cyl(c + Vector3(0, 0.95, 0), 0.85, 1.0, 0.95, steel, true, 12)
	for k in 8:
		var ang2 := TAU * k / 8.0
		box(c + Vector3(cos(ang2) * 0.93, 0.95, sin(ang2) * 0.93), Vector3(0.12, 0.9, 0.12), dark, false, -ang2)
	cyl(c + Vector3(0, 1.45, 0), 0.7, 0.85, 0.08, dark, false, 12)
	var core := cyl(c + Vector3(0, 2.05, 0), 0.32, 0.32, 1.1, glow, false, 12)
	core.set_meta("pulse", true)
	for y in [1.6, 2.05, 2.5]:
		cyl(c + Vector3(0, y, 0), 0.4, 0.4, 0.05, steel, false, 12)
	cyl(c + Vector3(0, 2.72, 0), 0.55, 0.75, 0.26, steel, false, 12)
	cyl(c + Vector3(0, 2.92, 0), 0.25, 0.45, 0.16, dark, false, 12)
	cyl(c + Vector3(0, 3.2, 0), 0.03, 0.05, 0.45, steel, false, 6)
	cyl(c + Vector3(0, 3.44, 0), 0.07, 0.07, 0.07, glow, false, 8)
	# the resonator rings: tilted, each turning its own way around the core
	for rr in [[0.32, 0.55, 1.18], [-0.38, -0.4, 1.38]]:
		var pivot := Node3D.new()
		root.add_child(pivot)
		pivot.position = c + Vector3(0, 2.05, 0)
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = float(rr[2]) - 0.05
		tm.outer_radius = float(rr[2]) + 0.05
		tm.rings = 32
		tm.ring_segments = 8
		ring.mesh = tm
		ring.material_override = glow
		pivot.add_child(ring)
		ring.rotation.x = float(rr[0])
		pivot.set_meta("spin", float(rr[1]))
		info.get_or_add("spinners", []).append(pivot)
		# two small emitter beads riding on each ring
		for side in [-1.0, 1.0]:
			var bead := MeshInstance3D.new()
			var bm := SphereMesh.new()
			bm.radius = 0.09
			bm.height = 0.18
			bead.mesh = bm
			bead.material_override = _col(Color(0.85, 0.85, 0.9))
			ring.add_child(bead)
			bead.position = Vector3(float(rr[2]) * side, 0, 0)
	# four emitter masts on the diagonals (the middle of every wall is a doorway), aimed at the core
	for k in 4:
		var ang3 := TAU * k / 4.0 + PI / 4
		var mp := c + Vector3(cos(ang3), 0, sin(ang3)) * 4.1
		cyl(mp + Vector3(0, 0.12, 0), 0.32, 0.38, 0.24, dark, true, 8)
		box(mp + Vector3(0, 1.45, 0), Vector3(0.14, 2.6, 0.14), steel, false)
		box(mp + Vector3(0, 0.9, 0), Vector3(0.24, 0.5, 0.24), dark, false)
		var head := cyl(mp + Vector3(0, 2.8, 0), 0.22, 0.12, 0.22, glow, false, 10)
		var aim := (c + Vector3(0, 2.05, 0) - (mp + Vector3(0, 2.8, 0))).normalized()
		head.basis = Basis.looking_at(aim, Vector3.UP) * Basis(Vector3.RIGHT, -PI / 2)      # the wide face at the core
		# the cable along the floor from the mast to the plinth
		var mid := (mp + c) * 0.5
		box(mid + Vector3(0, 0.03, 0), Vector3(0.08, 0.05, mp.distance_to(c) - 1.7), dark, false, ang3 + PI / 2)
	# coolant: three pipes from the housing down into the floor, frosty white
	var frost := _col(Color(0.78, 0.84, 0.9))
	for k in 3:
		var ang4 := TAU * k / 3.0 + 0.5
		var d := Vector3(cos(ang4), 0, sin(ang4))
		box(c + d * 1.15 + Vector3(0, 1.1, 0), Vector3(0.1, 0.1, 0.5), frost, false, -ang4 + PI / 2)
		box(c + d * 1.4 + Vector3(0, 0.6, 0), Vector3(0.1, 1.0, 0.1), frost, false)
	# the control desk (violet screens) and the field monitor on the wall
	_console(a + Vector3(1.5, 0, 0.6), 0.0, violet)
	_console(a + Vector3(w - 0.6, 0, w - 1.5), -PI / 2, Color(0.4, 0.9, 1.0))
	var l := OmniLight3D.new()
	l.light_color = violet
	l.light_energy = 1.6
	l.omni_range = 8.0
	root.add_child(l)
	l.position = c + Vector3(0, 2.1, 0)
	info["lights"].append(l)
	info["sounds"].append({"name": "ufo_hum", "pos": c + Vector3(0, 1.8, 0), "db": -16.0})

func _stores(a: Vector3, w: float) -> void:
	for k in 3:
		_shelf(a + Vector3(2.6 + k * 2.4, 0, 2.6), true)
		_shelf(a + Vector3(2.6 + k * 2.4, 0, w - 2.6), true)
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

# ---- alarms, cables, the globe on the screens, the range ----------------------------------------
## Each room: an orange rotating beacon (radar alarm, off until the radar sees something) and a red
## emergency lamp (blinks when the base is attacked and the fuses are gone).
func _alarms(a: Vector3, w: float, h: float) -> void:
	for corner in [Vector3(0.35, 0, 0.35), Vector3(w - 0.35, 0, w - 0.35)]:
		var p: Vector3 = a + corner + Vector3(0, h - 0.35, 0)
		cyl(p, 0.12, 0.14, 0.22, Game.color_mat(Color(1.0, 0.55, 0.1), true), false, 8)
		var beam := SpotLight3D.new()
		beam.light_color = Color(1.0, 0.55, 0.1)
		beam.light_energy = 0.0
		beam.spot_range = 9.0
		beam.spot_angle = 28.0
		root.add_child(beam)
		beam.position = p
		info["alarm_orange"].append(beam)
		var red := OmniLight3D.new()
		red.light_color = Color(1.0, 0.08, 0.05)
		red.light_energy = 0.0
		red.omni_range = 7.0
		root.add_child(red)
		red.position = p - Vector3(0, 0.4, 0)
		box(red.position, Vector3(0.25, 0.12, 0.08), Game.color_mat(Color(0.6, 0.05, 0.03), true), false)
		info["alarm_red"].append(red)

## Cable runs along the tops of the walls and bundles down to the consoles.
func _cables(a: Vector3, w: float, h: float, kind: String) -> void:
	var cols := [Color(0.08, 0.08, 0.09), Color(0.15, 0.15, 0.2), Color(0.35, 0.12, 0.1), Color(0.12, 0.25, 0.12)]
	for k in 3:
		var y := h - 0.25 - k * 0.07
		var m := _col(cols[k % cols.size()])
		box(a + Vector3(w / 2, y, 0.16 + k * 0.05), Vector3(w - 0.4, 0.04, 0.04), m, false)
		box(a + Vector3(0.16 + k * 0.05, y, w / 2), Vector3(0.04, 0.04, w - 0.4), m, false)
	# a bundle dropping down in a corner, clamped every metre
	for k in 4:
		box(a + Vector3(w - 0.2 - k * 0.06, h / 2, 0.2), Vector3(0.04, h, 0.04), _col(cols[k]), false)
	for y in range(1, int(h)):
		box(a + Vector3(w - 0.29, y, 0.2), Vector3(0.3, 0.05, 0.1), _col(Color(0.5, 0.5, 0.52)), false)
	if kind in ["velin", "radar", "laborator"]:
		for k in 5:
			var x := 1.2 + k * 1.9
			box(a + Vector3(x, 0.03, w * 0.35), Vector3(0.06, 0.04, w * 0.6), _col(cols[k % 4]), false)

## The globe as the radar sees it: one small picture (a turning Earth, red dots for what is out
## there) shown on every screen in the base.
func _globe_texture() -> Texture2D:
	if _globe_tex:
		return _globe_tex
	var vp := SubViewport.new()
	vp.size = Vector2i(192, 108)
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var w3 := Node3D.new()
	vp.add_child(w3)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.0, 0.04, 0.03)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	env.environment = e
	w3.add_child(env)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.2, 2.6)
	w3.add_child(cam)
	var earth := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0; sm.height = 2.0
	earth.mesh = sm
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = load("res://assets/textures/earth_day.png")
	gm.albedo_color = Color(0.4, 1.0, 0.6)
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	earth.material_override = gm
	w3.add_child(earth)
	earth.set_meta("spin", 0.25)
	info["spinners"].append(earth)
	for b in blips:
		var lat := deg_to_rad(float(b[0]))
		var lon := deg_to_rad(float(b[1]))
		var dot := MeshInstance3D.new()
		var ds := SphereMesh.new()
		ds.radius = 0.045; ds.height = 0.09
		dot.mesh = ds
		dot.material_override = Game.color_mat(Color(1.0, 0.15, 0.1), true)
		earth.add_child(dot)
		dot.position = Vector3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon)) * 1.01
	# a scan line over it
	var ln := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(4.0, 0.015, 0.01)
	ln.mesh = bm
	ln.material_override = Game.color_mat(Color(0.5, 1.0, 0.6), true)
	w3.add_child(ln)
	ln.position = Vector3(0, 0, 1.3)
	ln.set_meta("scan", true)
	info["spinners"].append(ln)
	_globe_tex = vp.get_texture()
	return _globe_tex

## A row of monitors on a wall, each showing the globe; cables hanging under them.
func _monitor_wall(p: Vector3, yaw: float, n: int, y := 2.0) -> void:
	var side := Vector3(cos(yaw), 0, -sin(yaw))
	var out := Vector3(sin(yaw), 0, cos(yaw))
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _globe_texture()
	mat.emission_enabled = true
	mat.emission_texture = mat.albedo_texture
	mat.emission_energy_multiplier = 1.2
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for k in n:
		var c := p + side * (k - (n - 1) / 2.0) * 1.35 + Vector3(0, y, 0)
		box(c, Vector3(1.25, 0.75, 0.08) if absf(sin(yaw)) < 0.5 else Vector3(0.08, 0.75, 1.25), _col(Color(0.2, 0.2, 0.22)), false)
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(1.12, 0.63)
		q.mesh = qm
		q.material_override = mat
		root.add_child(q)
		q.position = c + out * 0.06
		q.rotation.y = yaw
		for j in 2:
			box(c + side * (j - 0.5) * 0.4 + Vector3(0, -0.9, 0) + out * 0.03, Vector3(0.03, 1.1, 0.03), _col(Color(0.08, 0.08, 0.09)), false)

## The range: booths on a firing line, man-shaped boards down the lanes, sandbags at the back,
## an ammo locker (E: magazines for whatever you hold).
func _range(a: Vector3, w: float) -> void:
	var lanes := [1.2, 2.7, w - 2.7, w - 1.2]     # the middle of the room is the way through
	for k in 4:
		var z: float = lanes[k]
		# booth partitions and the counter
		box(a + Vector3(1.6, 0.55, z), Vector3(0.5, 0.08, 1.2), _col(Color(0.45, 0.4, 0.33)))
		if k == 0 or k == 2:
			box(a + Vector3(1.6, 0.8, z + 0.75), Vector3(1.4, 1.6, 0.06), _col(Color(0.5, 0.52, 0.56)), false)
		# the target
		var t := a + Vector3(w - 1.4 - (k % 2) * 2.0, 0, z)
		box(t + Vector3(0, 0.6, 0), Vector3(0.06, 1.2, 0.06), _col(Color(0.3, 0.3, 0.32)), false)
		var board := box(t + Vector3(0, 1.4, 0), Vector3(0.05, 1.0, 0.6), _col(Color(0.92, 0.9, 0.82)))
		board.set_meta("target", true)
		box(t + Vector3(-0.03, 1.55, 0), Vector3(0.02, 0.5, 0.36), _col(Color(0.15, 0.15, 0.15)), false)
		box(t + Vector3(-0.03, 1.95, 0), Vector3(0.02, 0.24, 0.2), _col(Color(0.15, 0.15, 0.15)), false)
		box(t + Vector3(-0.04, 1.55, 0), Vector3(0.02, 0.08, 0.08), _col(Color(0.8, 0.1, 0.1)), false)
	for k in 10:
		if k >= 3 and k <= 6:
			continue
		box(a + Vector3(w - 0.4, 0.2 + (k % 2) * 0.4, 0.6 + k * 1.0), Vector3(0.6, 0.4, 0.95), _col(Color(0.45, 0.4, 0.28)))
	box(a + Vector3(1.0, 0.01, w / 2), Vector3(0.1, 0.02, w - 1.0), Game.color_mat(Color(0.9, 0.75, 0.1)), false)    # the firing line
	_cabinet(a + Vector3(0.4, 0, w - 0.8), PI / 2, Color(0.25, 0.35, 0.2))
	info["terminals"].append({"pos": a + Vector3(1.1, 0, w - 0.8), "kind": "ammo", "label": "Bedna s municí: zásobníky do toho, co držíš"})

## A doorway into a room still being built: the steel door slid two thirds across, yellow-black tape,
## a sign; an invisible wall so nobody walks in. @a inward: which way is inside (+1/-1 on the axis).
func _blockade(c: Vector3, along_x: bool, inward: float) -> void:
	var wd := DOOR[1] - DOOR[0]
	var steel := Game.mat("metal", 0.5)
	var door_off := Vector3(-wd * 0.18, 0, 0) if along_x else Vector3(0, 0, -wd * 0.18)
	box(c + door_off + Vector3(0, 1.3, 0), Vector3(wd * 0.65, 2.6, 0.1) if along_x else Vector3(0.1, 2.6, wd * 0.65), steel, false)
	# the sign on the door
	var lbl := Label3D.new()
	lbl.text = "STAVÍ SE\nVSTUP ZAKÁZÁN"
	lbl.font_size = 40
	lbl.pixel_size = 0.004
	lbl.modulate = Color(0.1, 0.08, 0.05)
	lbl.outline_size = 0
	var plate := box(c + door_off + Vector3(0, 1.6, 0) + (Vector3(0, 0, -inward * 0.07) if along_x else Vector3(-inward * 0.07, 0, 0)),
		Vector3(0.9, 0.45, 0.02) if along_x else Vector3(0.02, 0.45, 0.9), Game.color_mat(Color(0.95, 0.78, 0.1)), false)
	root.add_child(lbl)
	lbl.position = plate.position + (Vector3(0, 0, -inward * 0.02) if along_x else Vector3(-inward * 0.02, 0, 0))
	lbl.rotation.y = (0.0 if inward < 0 else PI) if along_x else (PI / 2 if inward < 0 else -PI / 2)
	# tape: diagonal-ish bands of yellow and black across the opening (on the corridor side)
	for y in [0.9, 1.3]:
		for k in 8:
			var t := (k + 0.5) / 8.0 - 0.5
			var p := c + (Vector3(t * wd, y + (k % 2) * 0.02, -inward * 0.18) if along_x else Vector3(-inward * 0.18, y + (k % 2) * 0.02, t * wd))
			box(p, Vector3(wd / 8.0, 0.08, 0.01) if along_x else Vector3(0.01, 0.08, wd / 8.0), Game.color_mat(Color(0.95, 0.8, 0.1) if k % 2 == 0 else Color(0.08, 0.08, 0.08)), false)
	# the invisible wall
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(wd, 3.0, 0.3) if along_x else Vector3(0.3, 3.0, wd)
	cs.shape = bs
	sb.add_child(cs)
	root.add_child(sb)
	sb.position = c + Vector3(0, 1.5, 0)

## The builders: hard hats, one welding (sparks, blue flicker), one hammering, one on a jackhammer.
## Only scenery behind the tape; the mission plays their noises.
func _workers(a: Vector3, w: float) -> void:
	var jobs := [["weld", Vector3(w * 0.3, 0, w * 0.35), PI * 0.5], ["hammer", Vector3(w * 0.65, 0, w * 0.4), -PI * 0.3], ["drill", Vector3(w * 0.5, 0, w * 0.7), PI]]
	for j in jobs:
		var m: Node3D = Game.model("civ_a" if j[0] != "hammer" else "civ_b")
		root.add_child(m)
		m.position = a + (j[1] as Vector3)
		m.rotation.y = float(j[2])
		var ap: AnimationPlayer = m.find_child("AnimationPlayer", true, false)
		if ap and ap.has_animation("idle"):
			ap.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
			ap.play("idle")
		var bb := _aabb3(m)
		# hard hat and a hi-vis vest
		var hat := MeshInstance3D.new()
		var hm := SphereMesh.new()
		hm.radius = 0.15; hm.height = 0.18; hm.is_hemisphere = true
		hat.mesh = hm
		hat.material_override = Game.color_mat(Color(1.0, 0.8, 0.1))
		m.add_child(hat)
		hat.position = Vector3(0, bb.end.y - 0.08, 0)
		var vest := MeshInstance3D.new()
		var vm := BoxMesh.new()
		vm.size = Vector3(0.42, 0.45, 0.26)
		vest.mesh = vm
		vest.material_override = Game.color_mat(Color(1.0, 0.55, 0.05))
		m.add_child(vest)
		vest.position = Vector3(0, bb.end.y * 0.68, 0)
		var fwd := Vector3(-sin(float(j[2])), 0, -cos(float(j[2])))
		var tool_at: Vector3 = m.position + fwd * 0.55 + Vector3(0, 0.9 if j[0] == "weld" else (1.0 if j[0] == "hammer" else 0.1), 0)
		var fx := {"kind": j[0], "pos": tool_at, "node": m}
		match j[0]:
			"weld":
				var l := OmniLight3D.new()
				l.light_color = Color(0.55, 0.75, 1.0)
				l.omni_range = 4.0
				root.add_child(l)
				l.position = tool_at
				fx["light"] = l
				var sp := CPUParticles3D.new()
				sp.amount = 24
				sp.lifetime = 0.5
				sp.direction = Vector3(0, 1, 0)
				sp.spread = 70.0
				sp.initial_velocity_min = 1.0
				sp.initial_velocity_max = 2.5
				sp.gravity = Vector3(0, -9, 0)
				sp.scale_amount_min = 0.5
				var qm := SphereMesh.new()
				qm.radius = 0.012; qm.height = 0.024
				qm.material = Game.color_mat(Color(1.0, 0.8, 0.4), true)
				sp.mesh = qm
				root.add_child(sp)
				sp.position = tool_at
				fx["sparks"] = sp
				box(tool_at + fwd * 0.3 + Vector3(0, -0.4, 0), Vector3(0.8, 0.8, 0.8), Game.mat("metal", 0.5), false)    # the beam being welded
			"drill":
				box(tool_at + Vector3(0, 0.45, 0), Vector3(0.12, 0.8, 0.12), _col(Color(0.8, 0.15, 0.1)), false)
				box(tool_at + Vector3(0, 0.85, 0), Vector3(0.5, 0.06, 0.06), _col(Color(0.2, 0.2, 0.2)), false)
			"hammer":
				box(tool_at + fwd * 0.25 + Vector3(0, -0.2, 0), Vector3(0.6, 1.4, 0.6), Game.mat("concrete", 0.5), false)
		info.get_or_add("workers", []).append(fx)

func _aabb3(n: Node3D) -> AABB:
	var box_ := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c
		var b: AABB = (n.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
		box_ = b if first else box_.merge(b)
		first = false
	return box_
