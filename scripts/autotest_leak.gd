extends RefCounted
## 0.69 (Ari: „kameny pořád protékají“): kudy jde projít něčím, co vypadá pevně.
## --autotest=leaktest [--biome=... --mtype=...]: každý model na mapě (kameny, led, krápníky,
## skály základny vetřelců...) a každá krabice bez kolize, která vypadá jako kámen: vodorovné
## paprsky ze všech stran ve výšce kolen až hlavy. „Díra“ = paprsek, který viditelný povrch
## protne, ale kolize (Game.WORLD) ho nezastaví do 0,3 m za ním - tudy voják projde.
## RESULT leaktest <biome> props N rays R leak X % (worst: model leak% ...)

const LAYER := 1 << 20
## leakmap: models whose leaks are known and meant (see-through or walked through on purpose)
const KNOWN := ["v_tree", "cow", "v_laundry", "v_dune", "ufo_", "v_ab_bulbs", "v_ab_trumpets", "v_ab_coral", "v_ab_console", "v_ab_lift", "v_ab_tank", "v_ab_core", "v_house_roof", "v_radio_tower", "v_litter_bin", "dropship", "pelikan", "v_barbed_fence", "v_workbench", "v_car_"]
## models that are meant to be walked through (grass, bushes, crowns, cloth...)
const SOFT := ["grass", "bush", "fern", "flower", "reed", "hay", "wheat", "corn", "crop", "leaves", "ivy", "vine", "web", "curtain", "flag", "rug", "carpet", "puddle", "blood", "decal", "scorch", "smoke", "fire", "light", "lamp", "shadow", "water", "sign", "wire", "chain", "rope", "cable"]

static func run(at: Node, p: Node) -> void:
	if p == null or at.step > 0:
		return
	at._skip_brief()
	var m: Node = at.m()
	if not m.go and not m.started():
		return
	at.step = 1
	for a in m.aliens():
		a.set_physics_process(false)
	await at.get_tree().create_timer(1.0).timeout
	if Game.autotest() == "leakmap":
		var r2 := await sweep(at, p)
		# still a way in: the walk from the landing site to the target (the brain on Mars)
		var nav_rid: RID = p.get_world_3d().navigation_map
		var sp: Vector3 = (m.map["player_spawns"] as Array)[0] if not (m.map.get("player_spawns", []) as Array).is_empty() else p.global_position
		var goal: Vector3 = m.map.get("brain", m.map.get("ufo", sp))
		var path := NavigationServer3D.map_get_path(nav_rid, sp, goal, true)
		var miss := 999.0 if path.is_empty() else Vector2(path[-1].x - goal.x, path[-1].z - goal.z).length()
		at.out("RESULT leakmap %s %s rays %d leak %d hard %d nav_miss %.1f m (%s)" % [Game.cmd_arg("mtype", "?"), Game.cmd_arg("biome", "?"), r2["rays"], r2["leaks"], r2["hard"], miss, r2["worst"]])
		at.get_tree().quit()
		return
	var res := await check(at, p)
	at.out("RESULT %s %s props %d rays %d leak %.1f %% stone_leak %.1f %% (worst: %s)" % [Game.autotest(), Game.cmd_arg("biome", "?"), res["props"], res["rays"], res["leak"], res["stone"], res["worst"]])
	if Game.autotest() in ["leakhost", "leakclient"]:
		await at.get_tree().create_timer(4.0).timeout     # (the other side finishes too)
	at.get_tree().quit()

static func _soft(name: String) -> bool:
	var l := name.to_lower()
	for s in SOFT:
		if s in l:
			return true
	return false

static func check(at: Node, p: Node) -> Dictionary:
	var m: Node = at.m()
	var items := []      # [label, [MeshInstance3D...], centre node]
	for n in m.find_children("*", "Node3D", true, false):
		var mn := String(n.get_meta("model", ""))
		if mn == "" or _soft(mn) or n.has_meta("nocol"):
			continue
		var mis := []
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).is_visible_in_tree() and (mi as MeshInstance3D).mesh != null:
				mis.append(mi)
		if not mis.is_empty():
			items.append([mn, mis, n])
	# rock-looking boxes and cylinders (alien rock walls, stalagmites, cliffs): by material
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var mat: Material = (mi as MeshInstance3D).material_override
		if mat == null or not (mi as MeshInstance3D).is_visible_in_tree():
			continue
		var tex := String(mat.get_meta("tex", "")) + String(mat.resource_name)
		if "rock" in tex.to_lower() or "stone" in tex.to_lower() or "cliff" in tex.to_lower():
			var par: Node = mi.get_parent()
			var skip := false
			while par != null and par != m:
				if String(par.get_meta("model", "")) != "":
					skip = true
					break
				par = par.get_parent()
			if not skip:
				items.append(["box:" + tex, [mi], mi])
	var vbs := []
	for it in items:
		var vb := StaticBody3D.new()
		vb.collision_layer = LAYER
		vb.collision_mask = 0
		m.add_child(vb)
		vbs.append(vb)
		it.append(vb)
		for mi in it[1]:
			var sh: ConcavePolygonShape3D = (mi as MeshInstance3D).mesh.create_trimesh_shape()
			if sh == null:
				continue
			sh.backface_collision = true
			var cs := CollisionShape3D.new()
			cs.shape = sh
			vb.add_child(cs)
			cs.global_transform = (mi as MeshInstance3D).global_transform
	for f in 3:
		await at.get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var per := {}
	var rays := 0
	var leaks := 0
	var srays := 0
	var sleaks := 0
	var shown := 0
	for it in items:
		var label: String = it[0]
		var bb := AABB()
		var first := true
		for mi in it[1]:
			var b: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			bb = b if first else bb.merge(b)
			first = false
		if maxf(bb.size.x, bb.size.z) < 0.3 or bb.size.y < 0.3:
			continue
		var c := bb.get_center()
		var rad := Vector2(bb.size.x, bb.size.z).length() / 2.0 + 0.6
		var ground: float = bb.position.y
		var is_stone: bool = (it[2] as Node).has_meta("stone") or label.begins_with("box:") or "rock" in label or "spire" in label or "shard" in label
		for k in 16:
			var a := TAU * k / 16.0
			for hy in [0.35, 0.7, 1.1, 1.6]:
				var y: float = maxf(ground, (it[2] as Node3D).global_position.y) + hy
				if y > bb.end.y - 0.05:
					continue
				var from := Vector3(c.x + sin(a) * rad, y, c.z + cos(a) * rad)
				var to := Vector3(c.x - sin(a) * rad, y, c.z - cos(a) * rad)
				var qv := PhysicsRayQueryParameters3D.create(from, to, LAYER)
				var hv := space.intersect_ray(qv)
				if hv.is_empty() or hv["collider"] != it[3]:
					continue
				# only rays that meet THIS item's visible surface first
				var dv: float = (Vector3(hv["position"]) - from).length()
				var q := PhysicsRayQueryParameters3D.create(from, to, Game.WORLD)
				var hc := space.intersect_ray(q)
				var dc: float = 99.0 if hc.is_empty() else (Vector3(hc["position"]) - from).length()
				if dc < dv - 0.3:
					continue          # something else stands in front of it
				rays += 1
				if not per.has(label):
					per[label] = [0, 0]
				per[label][0] += 1
				if is_stone:
					srays += 1
				if dc > dv + 0.3:
					leaks += 1
					per[label][1] += 1
					if is_stone:
						sleaks += 1
						if shown < 12 and Game.cmd_arg("leakdebug", "") == "1":
							shown += 1
							at.out("  leak %s at %s: visible %.2f, stops %.2f, hit %s" % [label, Vector3(hv["position"]).snapped(Vector3.ONE * 0.01), dv, dc, "nic" if hc.is_empty() else String((hc["collider"] as Node).get_path()).right(60)])
	var worst := []
	for lb in per:
		if per[lb][1] > 0:
			worst.append([lb, 100.0 * per[lb][1] / per[lb][0], per[lb][0]])
	worst.sort_custom(func(x, y): return x[1] * x[2] > y[1] * y[2])
	var ws := ""
	for w in worst.slice(0, 10):
		ws += "%s %.0f%%/%d, " % [w[0], w[1], w[2]]
	for vb in vbs:
		(vb as Node).queue_free()
	return {"props": items.size(), "rays": rays, "leak": 100.0 * leaks / maxf(rays, 1), "stone": 100.0 * sleaks / maxf(srays, 1), "worst": ws}


## 0.70 (Ari: „dělají to spíš dílky než kameny“): the whole map, not only the models. Every visible
## mesh that is not a person (boxes of the generated tiles and of saved ones, merged meshes,
## models) gets a copy of its surface on its own layer; then rows of rays every metre across the
## whole map, along x and along z both ways, at knee, waist and head height. Each place a ray
## meets a visible surface where the game's collision does not stop it within 0,3 m = a leak,
## counted by what the surface is (model / texture / mesh name).
static func _label(mi: MeshInstance3D, m: Node) -> String:
	var x: Node = mi
	while x != null and x != m:
		var mn := String(x.get_meta("model", ""))
		if mn != "":
			return mn
		x = x.get_parent()
	var mat: Material = mi.material_override if mi.material_override else (mi.mesh.surface_get_material(0) if mi.mesh and mi.mesh.get_surface_count() > 0 else null)
	var t := ""
	if mat:
		t = String(mat.get_meta("tex", ""))
		if t == "":
			t = mat.resource_name
		if t == "" and mat is BaseMaterial3D:
			t = "#" + (mat as BaseMaterial3D).albedo_color.to_html(false)
	return "%s/%s" % [String(mi.name).get_slice("@", 0), t]

static func sweep(at: Node, p: Node) -> Dictionary:
	var m: Node = at.m()
	var vb := StaticBody3D.new()
	vb.collision_layer = LAYER
	vb.collision_mask = 0
	m.add_child(vb)
	var labels := []
	var nodes := []
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var x: Node = mi
		var skip := false
		while x != null and x != m:
			if x is CharacterBody3D or x is RigidBody3D or (x is Node3D and not (x as Node3D).visible):
				skip = true
				break
			x = x.get_parent()
		if skip or (mi as MeshInstance3D).mesh == null:
			continue
		var mat: Material = (mi as MeshInstance3D).material_override
		if mat is BaseMaterial3D and (mat as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			continue
		var lb := _label(mi, m)
		if _soft(lb):
			continue
		# only what you would take cover behind (a pebble, a vegetable or a curb does not count)
		var gb: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		if gb.size.y < 0.5 or maxf(gb.size.x, gb.size.z) < 0.35 or gb.end.y < 0.6:
			continue
		var sh: ConcavePolygonShape3D = (mi as MeshInstance3D).mesh.create_trimesh_shape()
		if sh == null:
			continue
		sh.backface_collision = true
		var cs := CollisionShape3D.new()
		cs.shape = sh
		vb.add_child(cs)
		cs.global_transform = (mi as MeshInstance3D).global_transform
		labels.append(lb)
		nodes.append(mi)
	for f in 3:
		await at.get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var size: float = float(m.map.get("size", 120.0))
	var per := {}
	var where := {}
	var rays := 0
	var leaks := 0
	var lo := -6.0
	var hi := size + 6.0
	for axis in 2:
		for sgn in [1.0, -1.0]:
			for row in range(int(lo), int(hi)):
				for hy in [0.43, 0.97, 1.53]:
					var a := lo if sgn > 0 else hi
					var b := hi if sgn > 0 else lo
					var from := Vector3(a, hy, row + 0.5) if axis == 0 else Vector3(row + 0.5, hy, a)
					var end := Vector3(b, hy, row + 0.5) if axis == 0 else Vector3(row + 0.5, hy, b)
					# ground under the row is not flat everywhere: ride on it? (tiles are at y 0)
					var guard := 0
					while guard < 200:
						guard += 1
						var qv := PhysicsRayQueryParameters3D.create(from, end, LAYER)
						var hv := space.intersect_ray(qv)
						if hv.is_empty():
							break
						var hp: Vector3 = hv["position"]
						var q := PhysicsRayQueryParameters3D.create(from, end, Game.WORLD | Game.GLASS)
						q.hit_from_inside = true
						var hc := space.intersect_ray(q)
						var dv := from.distance_to(hp)
						var dc: float = 9999.0 if hc.is_empty() else from.distance_to(Vector3(hc["position"]))
						rays += 1
						var graze := false
						if dc > dv + 0.45 and absf(Vector3(hv["normal"]).dot((end - from).normalized())) < 0.35:
							# the edge of something round: how much of it does the ray really cross?
							var qx := PhysicsRayQueryParameters3D.create(hp + (end - from).normalized() * 0.01, end, LAYER)
							var hx := space.intersect_ray(qx)
							graze = hx.is_empty() or hp.distance_to(Vector3(hx["position"])) < 0.3
						if dc > dv + 0.45 and not graze:
							# a face pressed against something solid (a panel lining the rock): no one gets there
							var qb := PhysicsRayQueryParameters3D.create(hp - (end - from).normalized() * 0.01, hp - (end - from).normalized() * 0.5, Game.WORLD | Game.GLASS)
							if not space.intersect_ray(qb).is_empty():
								graze = true
						if dc > dv + 0.45 and not graze:
							# a lid or a top edge a few cm above the solid part does not let anyone through
							var dn := Vector3(0, -0.06, 0)
							var q2 := PhysicsRayQueryParameters3D.create(from + dn, end + dn, Game.WORLD | Game.GLASS)
							q2.hit_from_inside = true
							var h2 := space.intersect_ray(q2)
							if not h2.is_empty() and from.distance_to(Vector3(h2["position"]) - dn) <= dv + 0.45:
								graze = true
						if dc > dv + 0.45 and not graze:
							var lb: String = labels[clampi(int(hv["shape"]), 0, labels.size() - 1)]
							leaks += 1
							per[lb] = int(per.get(lb, 0)) + 1
							if Game.cmd_arg("leakall", "") != "" and Game.cmd_arg("leakall", "") in lb:
								at.out("LEAKPT %s %s dir %s d %.2f" % [lb, hp.snapped(Vector3.ONE * 0.1), (end - from).normalized().snapped(Vector3.ONE), dc - dv])
							if not where.has(lb):
								where[lb] = hp.snapped(Vector3.ONE * 0.1)
								if Game.cmd_arg("leakdbg", "") != "":
									var nd: Node = nodes[clampi(int(hv["shape"]), 0, nodes.size() - 1)]
									var chain := ""
									var y: Node = nd
									for k in 5:
										if y == null or y == m: break
										chain = "%s(%s)/" % [y.name, y.get_class()] + chain
										y = y.get_parent()
									var mm: Mesh = (nd as MeshInstance3D).mesh
									var pq := PhysicsPointQueryParameters3D.new()
									pq.position = hp + (end - from).normalized() * 0.1
									pq.collision_mask = 0xFFFFF
									var inside := []
									var sq := PhysicsShapeQueryParameters3D.new()
									var sph := SphereShape3D.new()
									sph.radius = 0.6
									sq.shape = sph
									sq.transform = Transform3D(Basis(), hp)
									sq.collision_mask = 0xFFFFF & ~LAYER
									for r in space.intersect_shape(sq, 8):
										var co: CollisionObject3D = r["collider"]
										var so: Node = co.shape_owner_get_owner(co.shape_find_owner(int(r["shape"])))
										var ab := ""
										if so is CollisionShape3D and (so as CollisionShape3D).shape is ConvexPolygonShape3D:
											var pts: PackedVector3Array = ((so as CollisionShape3D).shape as ConvexPolygonShape3D).points
											var bb := AABB((so as Node3D).global_transform * pts[0], Vector3.ZERO)
											for pt in pts: bb = bb.expand((so as Node3D).global_transform * pt)
											ab = " %s..%s n%d" % [bb.position, bb.end, pts.size()]
										inside.append("%s L%d %s dis=%s%s" % [co.get_path(), co.collision_layer, (so as CollisionShape3D).shape.get_class() if so is CollisionShape3D else so.get_class(), so.disabled if so is CollisionShape3D else "-", ab])
									var ms := ""
									if mm is BoxMesh: ms = "box %s" % (mm as BoxMesh).size
									elif mm: ms = "%s aabb %s" % [mm.get_class(), mm.get_aabb().size]
									at.out("LEAKDBG %s %s %s org %s %s mo=%s smat=%s col=%s inside=%s" % [lb, hp, chain, (nd as Node3D).global_position, ms, (nd as MeshInstance3D).material_override, mm.surface_get_material(0) if mm and mm.get_surface_count() > 0 else null, "none" if hc.is_empty() else str(hc["collider"].get_path()) + " d" + str(dc - dv), inside])
						var dir := (end - from).normalized()
						if dc < dv - 0.01 and dc > 0.02:
							from = Vector3(hc["position"]) + dir * 0.05
						else:
							from = hp + dir * 0.05
						if (end - from).dot(dir) <= 0.0:
							break
	# what is left once the known see-through things are out: crowns of trees, cows, washing,
	# dunes, the alien plants, the inside of a UFO (consoles, seats), our ship's open back...
	var hard := 0
	for lb in per:
		var known := false
		for kn in KNOWN:
			if String(lb).begins_with(kn):
				known = true
		if not known:
			hard += int(per[lb])
	var worst := []
	for lb in per:
		worst.append([lb, per[lb]])
	worst.sort_custom(func(x, y): return x[1] > y[1])
	var ws := ""
	for w in worst.slice(0, 25):
		ws += "%s %d @%s, " % [w[0], w[1], where[w[0]]]
	vb.queue_free()
	return {"rays": rays, "leaks": leaks, "hard": hard, "worst": ws}
