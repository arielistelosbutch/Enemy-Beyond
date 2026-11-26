extends RefCounted
## interiors (2026-11-13, Ari: „gauč za schody, v patře vede stěna na zábradlí“): projde domy na mapě
## (dům, patrový dům, srub, sklad, obchod, hospoda, kasárna, polární chata, hangár) a u každého:
## - najde místa, kde se dá stát (podlaha, nad ní volno na postavu), v každém patře,
## - zkusí k nim cestu navigace zvenku (od vchodu bloku) - nedosažitelné místo = kout zatarasený
##   nábytkem, schody, stěnou (vypíše je po skupinách),
## - schody: nad horním koncem a před dolním koncem musí být volno (nábytek, stěna), boky schodů
##   v patře nesmí protínat stěna,
## - snímek shora v řezu každého patra (user://int_<druh>_<patro>.png, jen s oknem / xvfb).
## Výsledek: RESULT interiors N houses, pockets P, stairs_bad S

const KINDS := ["house", "house2", "cabin", "warehouse", "shop", "pub", "barracks", "polarhut", "hangar", "barn"]

static func run(at: Node, p: Node) -> void:
	if p == null: return
	at._skip_brief()
	if at.step > 0 or not at.m().started(): return
	at.step = 1
	p.hp = 1.0e6
	p.set_physics_process(false)
	p.global_position = Vector3(0, -60, 0)
	at.m().hud.visible = false
	for a in at.m().aliens():
		a.set_physics_process(false)
		a.visible = false
		a.global_position += Vector3(0, -200, 0)
	for cv in at.m().find_children("*", "Civilian", true, false):
		cv.visible = false
	await at.get_tree().create_timer(1.0).timeout
	# doors open (a shut door is not a wall)
	for i in at.m().doors.size():
		at.m()._swing(at.m().doors[i], 1.0, true)
	await at.get_tree().physics_frame
	await at.get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var nmap: RID = at.m().get_world_3d().navigation_map
	var blocks := []
	var seen := {}
	for lm in at.m().map.get("landmarks", []):
		if String(lm[0]) in KINDS and not seen.has(lm[0]):
			seen[lm[0]] = true
			blocks.append([String(lm[0]), lm[1]])
	var hv: Vector3 = at.m().map.get("house", Vector3.ZERO)
	if hv != Vector3.ZERO and not seen.has("house"):
		var o := hv - Vector3(5.6, 0, 1.5)
		if absf(fposmod(o.x, 12.0)) < 0.01 and absf(fposmod(o.z, 12.0)) < 0.01:
			blocks.append(["house", o])
	var only := Game.cmd_arg("kinds", "")
	var pockets := 0
	var stairs_bad := 0
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.7
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.collision_mask = Game.WORLD
	q.exclude = [p.get_rid()]
	for b in blocks:
		var kind: String = b[0]
		if only != "" and not kind in only.split(","):
			continue
		var o: Vector3 = b[1]
		# the way in: the closest navigation point to the front of the block
		var start := NavigationServer3D.map_get_closest_point(nmap, o + Vector3(6, 0, -0.3))
		var spots := {}       # floor level (rounded) -> [standable points]
		var x := 0.25
		while x < 12.0:
			var z := 0.25
			while z < 12.0:
				var top := 12.0
				for k in 4:
					var rq := PhysicsRayQueryParameters3D.create(o + Vector3(x, top, z), o + Vector3(x, -0.5, z), Game.WORLD)
					rq.exclude = [p.get_rid()]
					var hit := space.intersect_ray(rq)
					if hit.is_empty():
						break
					var fp: Vector3 = hit.position
					top = fp.y - 0.05
					if (hit.normal as Vector3).y < 0.8:
						continue
					q.transform = Transform3D(Basis(), fp + Vector3(0, 0.08 + 0.85, 0))
					if not space.intersect_shape(q, 1).is_empty():
						continue
					# inside a building only: something over the head within 7 m
					var uq := PhysicsRayQueryParameters3D.create(fp + Vector3(0, 1.8, 0), fp + Vector3(0, 9.0, 0), Game.WORLD)
					uq.exclude = [p.get_rid()]
					uq.hit_back_faces = true
					var ceil := space.intersect_ray(uq)
					var lvl := int(round(fp.y / 0.5))
					if ceil.is_empty() and kind != "shop":
						continue        # a roof, the open yard
					if ceil.is_empty() and fp.y < 0.5:
						continue
					if fp.y > 0.3 and fp.y < 2.4 and not _on_ramp(hit):
						continue        # the top of a table, a crate, a bed: not a floor
					if not spots.has(lvl): spots[lvl] = []
					spots[lvl].append(fp)
				z += 0.5
			x += 0.5
		var bad_pts := []
		var total := 0
		for lvl in spots:
			for fp in spots[lvl]:
				total += 1
				var cp := NavigationServer3D.map_get_closest_point(nmap, fp)
				var ok := Vector2(cp.x - fp.x, cp.z - fp.z).length() < 0.75 and absf(cp.y - fp.y) < 0.6
				if ok:
					var path := NavigationServer3D.map_get_path(nmap, start, cp, true)
					ok = path.size() > 0 and path[path.size() - 1].distance_to(cp) < 0.5
				if not ok:
					bad_pts.append(fp)
		# group unreachable points into pockets (points within 0.75 m belong together)
		var groups := []
		for bp in bad_pts:
			var g := -1
			for i in groups.size():
				for gp in groups[i]:
					if (gp as Vector3).distance_to(bp) < 0.8:
						g = i
						break
				if g >= 0: break
			if g < 0:
				groups.append([bp])
			else:
				groups[g].append(bp)
		var real := 0
		for gr in groups:
			if gr.size() < 2:
				continue        # a single half-metre spot by a wall: the nav margin, not a pocket
			real += 1
			var mid := Vector3.ZERO
			for gp in gr: mid += gp
			mid /= gr.size()
			at.out("[INT] %s pocket %d spots at %s (local %s)" % [kind, gr.size(), str(snapped(mid, Vector3(0.1, 0.1, 0.1))), str(snapped(mid - o, Vector3(0.1, 0.1, 0.1)))])
		pockets += real
		# stairs: the walking ramps of this block (StaticBody with one tilted box shape)
		for sb in at.m().find_children("*", "StaticBody3D", true, false):
			var lp: Vector3 = (sb as Node3D).global_position - o
			if lp.x < 0 or lp.x > 12 or lp.z < 0 or lp.z > 12:
				continue
			var tilt: float = (sb as Node3D).global_transform.basis.z.normalized().y
			if absf(tilt) < 0.25 or absf(tilt) > 0.95 or sb.get_child_count() != 1 or not sb.get_child(0) is CollisionShape3D:
				continue
			var sh = (sb.get_child(0) as CollisionShape3D).shape
			if not sh is BoxShape3D:
				continue
			var bz: Vector3 = (sb as Node3D).global_transform.basis.z.normalized()
			var half: float = (sh as BoxShape3D).size.z / 2.0
			var ends := [(sb as Node3D).global_position + bz * half, (sb as Node3D).global_position - bz * half]
			var hi: Vector3 = ends[0] if ends[0].y > ends[1].y else ends[1]
			var lo: Vector3 = ends[1] if ends[0].y > ends[1].y else ends[0]
			var fwd := Vector3(hi.x - lo.x, 0, hi.z - lo.z).normalized()
			var sw: float = (sh as BoxShape3D).size.x
			var probs := []
			var side := fwd.cross(Vector3.UP)
			for e in [[hi + fwd * 0.55, "top"], [lo - fwd * 0.55, "foot"]]:
				var ok := false
				# straight on, a little to the sides - at the top also off the stair to either side
				var tries := [Vector3.ZERO, -side * 0.3 * sw / 2, side * 0.3 * sw / 2]
				if e[1] == "top":
					tries += [-fwd * 0.75 - side * (sw / 2 + 0.6), -fwd * 0.75 + side * (sw / 2 + 0.6)]
				for off in tries:
					var ep: Vector3 = (e[0] as Vector3) + off
					var dq := PhysicsRayQueryParameters3D.create(ep + Vector3(0, 0.6, 0), ep + Vector3(0, -0.6, 0), Game.WORLD)
					dq.exclude = [p.get_rid()]
					var dh := space.intersect_ray(dq)
					if not dh.is_empty():
						ep.y = (dh.position as Vector3).y
					q.transform = Transform3D(Basis(), ep + Vector3(0, 0.08 + 0.85, 0))
					if space.intersect_shape(q, 1).is_empty():
						ok = true
						break
				if not ok:
					probs.append(e[1])
			# along the ramp, at head height above it: nothing solid in the way of a walking man
			for k in 7:
				var t := 0.15 + k * 0.12
				var pt: Vector3 = lo.lerp(hi, t) + Vector3(0, 0.14 + 0.85, 0)
				q.transform = Transform3D(Basis(), pt)
				var r := space.intersect_shape(q, 2)
				for h in r:
					if h["collider"] != sb:
						var cn: Node = h["collider"]
						probs.append("cesta %.0f %% (%s @%s)" % [t * 100, cn.name, str(snapped((cn as Node3D).global_position - o, Vector3(0.1, 0.1, 0.1)))])
						break
			if not probs.is_empty():
				stairs_bad += 1
				at.out("[INT] %s stairs %s -> %s: %s" % [kind, str(snapped(lo - o, Vector3(0.1, 0.1, 0.1))), str(snapped(hi - o, Vector3(0.1, 0.1, 0.1))), probs])
		if Game.cmd_arg("probe", "") == kind:
			var prow := ""
			for zi in 15:
				var zz := zi * 0.5 + 2.0
				var uq2 := PhysicsRayQueryParameters3D.create(o + Vector3(float(Game.cmd_arg("px", "8.2")), float(Game.cmd_arg("py", "2.8")), zz), o + Vector3(float(Game.cmd_arg("px", "8.2")), 12.0, zz), Game.WORLD)
				uq2.hit_back_faces = true
				uq2.exclude = [p.get_rid()]
				var hh := space.intersect_ray(uq2)
				prow += " z%.1f:%s" % [zz, ("%.2f" % (hh.position as Vector3).y) if not hh.is_empty() else "-"]
			at.out("[INT] probe" + prow)
		at.out("[INT] %s at %s: %d standing spots on %d levels, %d unreachable, %d pockets" % [kind, str(o), total, spots.size(), bad_pts.size(), real])
		# --eye=x,y,z,tx,ty,tz[;...] (block-local): eye-level views for a look round
		if DisplayServer.get_name() != "headless" and only == kind and Game.cmd_arg("eye", "") != "":
			var ei := 0
			var env0: Environment = at.get_viewport().world_3d.environment
			if env0: env0.fog_enabled = false
			for ev in Game.cmd_arg("eye", "").split(";"):
				var f := ev.split_floats(",")
				var cam := Camera3D.new()
				at.m().add_child(cam)
				cam.fov = 80.0
				cam.near = 0.05
				cam.global_position = o + Vector3(f[0], f[1], f[2])
				cam.look_at(o + Vector3(f[3], f[4], f[5]), Vector3.UP)
				cam.current = true
				var lamp := OmniLight3D.new()
				lamp.omni_range = 9.0
				lamp.light_energy = 1.2
				at.m().add_child(lamp)
				lamp.global_position = cam.global_position + Vector3(0, 0.3, 0)
				await at.get_tree().create_timer(0.7).timeout
				at.get_viewport().get_texture().get_image().save_png("user://int_eye_%s_%d.png" % [kind, ei])
				ei += 1
				cam.queue_free()
				lamp.queue_free()
		# a cutaway from above for each floor
		if DisplayServer.get_name() != "headless":
			var lv := spots.keys()
			lv.sort()
			var done := {}
			for l in lv:
				var fy: float = float(l) * 0.5
				var key := int(round(fy / 2.5))
				if done.has(key) or spots[l].size() < 6:
					continue
				done[key] = true
				await _shot(at, o, fy, "user://int_%s_%d.png" % [kind, done.size() - 1])
	at.out("RESULT interiors %d houses, pockets %d, stairs_bad %d" % [blocks.size() if only == "" else only.split(",").size(), pockets, stairs_bad])
	at.get_tree().quit()

static func _on_ramp(hit: Dictionary) -> bool:
	var n: Vector3 = hit.normal
	return n.y < 0.995

static func _shot(at: Node, o: Vector3, fy: float, path: String) -> void:
	# everything that starts above this floor's ceiling is hidden (the upper floor, the roof),
	# the camera looks straight down from high up: walls and furniture of this floor in plan
	var hidden := []
	for gi in at.m().find_children("*", "GeometryInstance3D", true, false):
		var g := gi as GeometryInstance3D
		if not g.is_visible_in_tree():
			continue
		var bb := g.get_aabb()
		var gb: AABB = g.global_transform * bb
		var cx := gb.get_center()
		if cx.x < o.x - 3 or cx.x > o.x + 15 or cx.z < o.z - 3 or cx.z > o.z + 15:
			continue
		if gb.position.y > fy + 2.0 or gb.get_center().y > fy + 2.6 or (gb.size.y < 0.6 and gb.position.y > fy + 1.9):
			g.visible = false
			hidden.append(g)
	var env: Environment = at.get_viewport().world_3d.environment if at.get_viewport().world_3d else null
	var fog := false
	if env:
		fog = env.fog_enabled
		env.fog_enabled = false
	var cam := Camera3D.new()
	at.m().add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 13.0
	cam.near = 0.05
	cam.far = 60.0
	cam.global_position = o + Vector3(6, fy + 30.0, 6)
	cam.rotation = Vector3(-PI / 2, 0, 0)
	cam.current = true
	var lamp := DirectionalLight3D.new()
	lamp.light_energy = 0.6
	lamp.shadow_enabled = false
	at.m().add_child(lamp)
	lamp.rotation = Vector3(-1.2, 0.5, 0)
	await at.get_tree().create_timer(0.6).timeout
	at.get_viewport().get_texture().get_image().save_png(path)
	cam.queue_free()
	lamp.queue_free()
	for g in hidden:
		if is_instance_valid(g): g.visible = true
	if env:
		env.fog_enabled = fog
