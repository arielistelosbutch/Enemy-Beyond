extends "res://scripts/map_gen.gd"
## Their base on Earth: a grid of 12 m cells dug into violet rock. Most are caves overgrown with
## their garden; some are built halls lined with their panels: a hall of chairs and barrels, a
## hatchery with people in cages, stores, and the command centre with the control core (the
## objective). Every cell is reached from its neighbours through a gap in the rock in the middle
## of the shared side (a spanning tree keeps everything connected; extra gaps make loops) - so a
## tunnel never ends in rock. The team comes down a shaft at one edge and leaves the same way.

const H := 5.5
var cells := {}           # Vector2i -> role
var _ab_open := {}           # passages between cells (edge key -> true)

func build(parent: Node3D, map_seed: int, params := {}) -> Dictionary:
	_t0 = Time.get_ticks_msec()
	rng.seed = map_seed
	N = 8 if params.get("size", "large") != "colossal" else 10
	terrain = "alienbase"
	info["size"] = BLOCK * N
	info["terrain"] = "alienbase"
	info["captives"] = []
	nav = NavigationRegion3D.new()
	nav.name = "Nav"
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.4
	nm.agent_height = 1.6
	nm.agent_max_climb = 0.4
	nm.cell_size = 0.2
	nm.cell_height = 0.2
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 0xFFFFFFFF & ~(64 | 128)
	nav.navigation_mesh = nm
	parent.add_child(nav)
	root = nav
	# roles: the shaft at the south edge, the command centre far from it, the rest mixed
	var entry := Vector2i(rng.randi_range(1, N - 2), 0)
	var command := Vector2i(clampi(N - 1 - entry.x + rng.randi_range(-1, 1), 1, N - 2), N - 1)
	for x in N:
		for z in N:
			cells[Vector2i(x, z)] = "cave"
	cells[entry] = "entry"
	cells[command] = "command"
	var built := ["hatchery", "hall", "hall", "stores", "hatchery" if N > 8 else "stores", "hall"]
	for b in built:
		for t in 40:
			var c := Vector2i(rng.randi_range(0, N - 1), rng.randi_range(1, N - 1))
			if cells[c] == "cave" and c.distance_to(entry) > 2.0:
				cells[c] = b
				break
	# passages: a random spanning tree (all connected), then some extra gaps for loops
	var open := {}
	var seen := {entry: true}
	var frontier := [entry]
	while not frontier.is_empty():
		var i := rng.randi() % frontier.size()
		var c: Vector2i = frontier[i]
		var nbs := []
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n2: Vector2i = c + d
			if n2.x >= 0 and n2.y >= 0 and n2.x < N and n2.y < N and not seen.has(n2):
				nbs.append(n2)
		if nbs.is_empty():
			frontier.remove_at(i)
			continue
		var nx: Vector2i = nbs[rng.randi() % nbs.size()]
		seen[nx] = true
		frontier.append(nx)
		open[_edge(c, nx)] = true
	for x in N:
		for z in N:
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var a := Vector2i(x, z)
				var b2: Vector2i = a + d
				if b2.x < N and b2.y < N and rng.randf() < 0.45:
					open[_edge(a, b2)] = true
	_ab_open = open
	# floor and ceiling over the whole base
	box(Vector3(N * BLOCK / 2, -0.25, N * BLOCK / 2), Vector3(N * BLOCK, 0.5, N * BLOCK), Game.mat("alien_rock", 0.5))
	box(Vector3(N * BLOCK / 2, H + 0.4, N * BLOCK / 2), Vector3(N * BLOCK + 2, 0.8, N * BLOCK + 2), Game.mat("alien_rock", 0.5))
	# rock walls on every cell edge (gaps where open), the outer ring solid
	for x in N + 1:
		for z in N:
			var a := Vector2i(x - 1, z)
			var b3 := Vector2i(x, z)
			var gap := x > 0 and x < N and open.has(_edge(a, b3))
			_rock_wall(Vector3(x * BLOCK, 0, z * BLOCK), false, gap)
	for z in N + 1:
		for x in N:
			var a := Vector2i(x, z - 1)
			var b4 := Vector2i(x, z)
			var gap := z > 0 and z < N and open.has(_edge(a, b4))
			_rock_wall(Vector3(x * BLOCK, 0, z * BLOCK), true, gap)
	for c in cells:
		var o := Vector3(c.x * BLOCK, 0, c.y * BLOCK)
		match cells[c]:
			"entry": _shaft(o)
			"command": _command(o)
			"hall": _hall(o)
			"hatchery": _hatchery(o)
			"stores": _stores_a(o)
			_: _cave(o)
		if cells[c] != "entry":
			info["alien_spawns"].append(o + Vector3(BLOCK / 2 + rng.randf_range(-2, 2), 0.2, BLOCK / 2 + rng.randf_range(-2, 2)))
			info["waypoints"].append(o + Vector3(BLOCK / 2, 0, BLOCK / 2))
	_zfix()
	nav.bake_navigation_mesh(false)
	if Game.autotest() != "": print("[ABASE] built %d ms, cells %s" % [Time.get_ticks_msec() - _t0, cells.values()])
	return info

func _edge(a: Vector2i, b: Vector2i) -> String:
	var lo := a if (a.x < b.x or (a.x == b.x and a.y < b.y)) else b
	var hi := b if lo == a else a
	return "%d,%d-%d,%d" % [lo.x, lo.y, hi.x, hi.y]

## A rock wall along a cell edge, rough (a few lumps), with a 3.5 m gap in the middle if open.
func _rock_wall(p: Vector3, along_x: bool, gap: bool) -> void:
	var rock := Game.mat("alien_rock", 0.5)
	var segs := [[0.0, BLOCK]] if not gap else [[0.0, BLOCK / 2 - 1.75], [BLOCK / 2 + 1.75, BLOCK]]
	for sg in segs:
		var a: float = sg[0]
		var b: float = sg[1]
		var mid := (a + b) / 2.0
		var c := p + (Vector3(mid, H / 2, 0) if along_x else Vector3(0, H / 2, mid))
		var th := rng.randf_range(1.0, 1.6)
		box(c, Vector3(b - a, H, th) if along_x else Vector3(th, H, b - a), rock)
		# jagged lumps sticking out of the face
		for k in 2:
			var t := rng.randf_range(a + 0.5, b - 0.5)
			var lp := p + (Vector3(t, rng.randf_range(0.5, H - 1.0), 0) if along_x else Vector3(0, rng.randf_range(0.5, H - 1.0), t))
			var sz := rng.randf_range(0.6, 1.3)
			box(lp, Vector3(sz, sz * 1.4, sz * 2.2) if along_x else Vector3(sz * 2.2, sz * 1.4, sz), rock, false, rng.randf() * 0.6)
	if gap:
		# the lintel over the passage
		var gc := p + (Vector3(BLOCK / 2, H - 0.7, 0) if along_x else Vector3(0, H - 0.7, BLOCK / 2))
		box(gc, Vector3(3.6, 1.4, 1.2) if along_x else Vector3(1.2, 1.4, 3.6), rock)

# ---- the cells ----------------------------------------------------------------------------------
## Their garden: violet bulbs, orange trumpets, red coral, green leaves; stalagmites for cover.
func _cave(o: Vector3) -> void:
	var glow := false
	for k in rng.randi_range(10, 18):
		var p := o + Vector3(rng.randf_range(1.5, BLOCK - 1.5), 0, rng.randf_range(1.5, BLOCK - 1.5))
		# 0.56: their garden as models (tools/blender/alien_base.py)
		var yaw := rng.randf() * TAU
		match rng.randi() % 5:
			0:
				_prop("ab_bulbs", p, yaw, false).scale = Vector3.ONE * rng.randf_range(0.8, 1.4)
				glow = true
			1:
				_prop("ab_trumpets", p, yaw, false).scale = Vector3.ONE * rng.randf_range(0.8, 1.3)
			2:
				_prop("ab_coral", p, yaw, false).scale = Vector3.ONE * rng.randf_range(0.8, 1.5)
			3:
				_prop("ab_leaves", p, yaw, false).scale = Vector3.ONE * rng.randf_range(0.9, 1.6)
			4:
				var sp := _prop("ab_spire" if rng.randf() < 0.55 else "ab_spire_low", p, yaw, false)
				sp.scale = Vector3(1, rng.randf_range(0.85, 1.15), 1)
				_cover(p + Vector3(0.9, 0, 0))
	var l := OmniLight3D.new()
	l.light_color = Color(0.6, 0.35, 0.9)
	l.light_energy = 0.7 if glow else 0.3
	l.omni_range = 9.0
	root.add_child(l)
	l.position = o + Vector3(BLOCK / 2, 1.0, BLOCK / 2)
	_cover(o + Vector3(BLOCK / 2, 0, 2.0)); _cover(o + Vector3(2.0, 0, BLOCK / 2))

## A built cell: pale panels lining the rock, tiled floor, violet light.
func _built(o: Vector3, floor_col := Color(0.62, 0.62, 0.7)) -> void:
	box(o + Vector3(BLOCK / 2, 0.03, BLOCK / 2), Vector3(BLOCK - 1.6, 0.06, BLOCK - 1.6), Game.mat("ufo_floor", 0.5), false)
	# the panels line the rock - with a gap where the rock has one (0.56: they used to hide the
	# passages behind a "wall" you could walk through)
	var cell := Vector2i(int(round(o.x / BLOCK)), int(round(o.z / BLOCK)))
	var pm := Game.mat("alien_panel", 0.5)
	for sd in [0, 1]:
		var nz := cell + Vector2i(0, -1 if sd == 0 else 1)
		var nx := cell + Vector2i(-1 if sd == 0 else 1, 0)
		var z_open := _ab_open.has(_edge(cell, nz))
		var x_open := _ab_open.has(_edge(cell, nx))
		for half in ([[0.9, BLOCK / 2 - 1.9], [BLOCK / 2 + 1.9, BLOCK - 0.9]] if z_open else [[0.9, BLOCK - 0.9]]):
			box(o + Vector3((half[0] + half[1]) / 2, 1.6, 0.9 + sd * (BLOCK - 1.8)), Vector3(half[1] - half[0], 3.2, 0.1), pm, false)
		for half in ([[0.9, BLOCK / 2 - 1.9], [BLOCK / 2 + 1.9, BLOCK - 0.9]] if x_open else [[0.9, BLOCK - 0.9]]):
			box(o + Vector3(0.9 + sd * (BLOCK - 1.8), 1.6, (half[0] + half[1]) / 2), Vector3(0.1, 3.2, half[1] - half[0]), pm, false)
	var l := OmniLight3D.new()
	l.light_color = Color(0.7, 0.5, 1.0)
	l.light_energy = 1.3
	l.omni_range = 11.0
	root.add_child(l)
	l.position = o + Vector3(BLOCK / 2, H - 1.0, BLOCK / 2)

## Where the team came down: a shaft with our cable lift, a work lamp. The way out.
func _shaft(o: Vector3) -> void:
	var c := o + Vector3(BLOCK / 2, 0, BLOCK / 2)
	box(c + Vector3(0, 0.08, 0), Vector3(3.0, 0.16, 3.0), Game.mat("metal", 0.5)).visible = false     # the lift's floor
	_prop("ab_lift", c, 0.0, false)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.92, 0.8)
	lamp.light_energy = 1.5
	lamp.omni_range = 8.0
	root.add_child(lamp)
	lamp.position = c + Vector3(0, 3.0, 0)
	info["evac"] = c + Vector3(0, 0.2, 0)
	for i in 4:
		info["player_spawns"].append(c + Vector3((i % 2) * 1.2 - 0.6, 0.3, (i / 2) * 1.2 - 0.6))
	info["spawn_yaw"] = PI
	_cave(o)

## The hall: rows of blue chairs by a pale paved path, barrels of their stores, consoles, orbs on stands.
func _hall(o: Vector3) -> void:
	_built(o)
	box(o + Vector3(BLOCK / 2, 0.07, BLOCK / 2), Vector3(2.0, 0.04, BLOCK - 2.0), Game.color_mat(Color(0.8, 0.8, 0.86)), false)
	for row in 4:
		for sd in [-1.0, 1.0]:
			for k in 3:
				var p := o + Vector3(BLOCK / 2 + sd * (1.8 + k * 0.9), 0, 2.4 + row * 2.2)
				_prop("ab_seat", p, PI if row % 2 else 0.0, false)
	for p in [Vector3(1.8, 0, 1.8), Vector3(BLOCK - 1.8, 0, BLOCK - 1.8)]:
		_prop("ab_barrel", o + p, rng.randf() * TAU, false)
	_prop("ab_console", o + Vector3(BLOCK - 1.8, 0, 1.8), PI * 0.75, false)
	for p in [Vector3(1.8, 0, BLOCK - 1.8), Vector3(BLOCK - 2.6, 0, BLOCK / 2)]:
		_prop("ab_orb_lamp", o + p, 0.0, false)
	box(o + Vector3(BLOCK / 2, 0.09, BLOCK - 2.2), Vector3(1.6, 0.04, 1.6), Game.color_mat(Color(0.9, 0.12, 0.1), true), false)
	_cover(o + Vector3(2.5, 0, 2.5)); _cover(o + Vector3(BLOCK - 2.5, 0, BLOCK - 2.5))

## The hatchery: glass walls, cages in yellow frames with people inside, a green tank in the middle.
func _hatchery(o: Vector3) -> void:
	_built(o, Color(0.7, 0.72, 0.8))
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.6, 0.75, 0.95, 0.25)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for k in 6:
		var p := o + Vector3(2.4 + (k % 3) * 3.6, 0, 2.4 + (k / 3) * 7.2)
		# a cage: yellow frame, glass sides, one side bars (we can open it)
		_prop("ab_cage", p, PI, false)
		box(p + Vector3(-0.8, 1.1, 0), Vector3(0.03, 2.1, 1.6), glass, true)
		box(p + Vector3(0.8, 1.1, 0), Vector3(0.03, 2.1, 1.6), glass, true)
		if k < 3:
			info["captives"].append(p + Vector3(0, 0.2, 0))
	var c := o + Vector3(BLOCK / 2, 0, BLOCK / 2)
	cyl(c + Vector3(0, 0.15, 0), 0.9, 1.0, 0.3, Game.color_mat(Color(0.75, 0.72, 0.7)), true, 12).visible = false
	_prop("ab_tank", c, 0.0, false)
	var liquid := StandardMaterial3D.new()
	liquid.albedo_color = Color(0.3, 0.95, 0.4, 0.5)
	liquid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	liquid.emission_enabled = true
	liquid.emission = Color(0.15, 0.6, 0.2)
	cyl(c + Vector3(0, 1.3, 0), 0.8, 0.8, 2.0, liquid, true, 12)
	var gl := OmniLight3D.new()
	gl.light_color = Color(0.3, 1.0, 0.4)
	gl.light_energy = 1.6
	gl.omni_range = 6.0
	root.add_child(gl)
	gl.position = c + Vector3(0, 1.4, 0)

## Stores: barrels, crates of their stuff, a cage or two.
func _stores_a(o: Vector3) -> void:
	_built(o)
	for k in 8:
		var p := o + Vector3(rng.randf_range(2.0, BLOCK - 2.0), 0, rng.randf_range(2.0, BLOCK - 2.0))
		_prop("ab_barrel" if rng.randf() < 0.6 else "ab_crate", p, rng.randf() * TAU, false)
		_cover(p + Vector3(1.0, 0, 0))

## The command centre: a violet glowing chequered floor, panels of orange and blue, a red grid in the
## middle, chests and consoles, and the control core - destroy it and the base is blind and deaf.
func _command(o: Vector3) -> void:
	_built(o)
	for x in 5:
		for z in 5:
			var fp := o + Vector3(2.0 + x * 2.0, 0.08, 2.0 + z * 2.0)
			box(fp, Vector3(1.9, 0.02, 1.9), Game.color_mat(Color(0.65, 0.2, 0.85), true) if (x + z) % 2 == 0 else Game.color_mat(Color(0.4, 0.12, 0.55)), false)
	var c := o + Vector3(BLOCK / 2, 0, BLOCK / 2)
	for x in 3:
		for z in 3:
			box(c + Vector3((x - 1) * 0.7, 0.1, (z - 1) * 0.7) + Vector3(0, 0, -3.0), Vector3(0.6, 0.03, 0.6), Game.color_mat(Color(0.95, 0.15, 0.1), true), false)
	# the core: a dark pillar ringed with green light
	cyl(c + Vector3(0, 0.3, 1.5), 1.2, 1.3, 0.6, Game.color_mat(Color(0.15, 0.1, 0.2)), true, 10).visible = false
	_prop("ab_core", c + Vector3(0, 0, 1.5), 0.0, false)
	var core := cyl(c + Vector3(0, 2.0, 1.5), 0.55, 0.55, 3.0, Game.color_mat(Color(0.25, 0.12, 0.35)), true, 10)
	_breakable(core, "metal")
	core.set_meta("hp", 320.0)
	core.set_meta("explode", [6.0, 110.0])
	info["core"] = core
	for y in [1.2, 2.0, 2.8]:
		cyl(c + Vector3(0, y, 1.5), 0.62, 0.62, 0.12, Game.color_mat(Color(0.3, 1.0, 0.5), true), false, 10)
	var cl := OmniLight3D.new()
	cl.light_color = Color(0.4, 1.0, 0.5)
	cl.light_energy = 2.0
	cl.omni_range = 7.0
	root.add_child(cl)
	cl.position = c + Vector3(0, 2.0, 1.5)
	for k in 3:
		var p := o + Vector3(2.0 + k * 4.0, 0, BLOCK - 1.6)
		_prop("ab_console", p, 0.0, false)
	for p in [Vector3(1.6, 0, 1.6), Vector3(BLOCK - 1.6, 0, 1.6)]:
		_prop("ab_crate", o + p, rng.randf_range(-0.3, 0.3), false)
	info["command"] = c + Vector3(0, 0.2, -1.5)
	_cover(o + Vector3(2.5, 0, BLOCK / 2)); _cover(o + Vector3(BLOCK - 2.5, 0, BLOCK / 2))
