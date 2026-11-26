extends RefCounted
## kerbtest (2026-11-22, Ari: „obrubníky ve městě potřebují lehký skok, jako by byly moc vysoké“):
## voják jde na chodník z různých úhlů (kolmo, 40°, 65°) chůzí, sprintem a v podřepu; měří se,
## jestli vyjde nahoru bez skoku, kolik snímků se o hranu zasekne (skoro stojí) a jak velký skok
## nahoru udělá za jeden snímek. Pak totéž vetřelec (Šedivák) po cestě navigace.
## --autotest=kerbtest --mtype=terror --biome=town --seed=3 --day=1

static var _res := {}

static func run(at: Node, p: Node) -> void:
	if p == null: return
	at._skip_brief()
	if not at.m().started() or at.step != 0: return
	at.step = 1
	p.hp = 1.0e6
	_go(at, p)

static func _kerbs(at: Node) -> Array:
	var out: Array = []
	for mi in at.m().find_children("*", "MeshInstance3D", true, false):
		var g := mi as MeshInstance3D
		if not (g.mesh is BoxMesh) or not g.is_visible_in_tree(): continue
		var b: AABB = g.global_transform * g.get_aabb()
		if b.position.y > 0.05 or b.end.y < float(Game.cmd_arg("kmin", "0.12")) or b.end.y > 0.3: continue
		if minf(b.size.x, b.size.z) < 1.2 or b.size.x * b.size.z > 140.0: continue
		out.append(b)
	if Game.cmd_arg("klist", "") == "1":
		for b in out: at.out("[KERB] k %s" % [b])
	return out

static func _go(at: Node, p: Node) -> void:
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.8
	var kerbs := _kerbs(at)
	at.out("[KERB] %d kerbs" % kerbs.size())
	for a in at.m().aliens():
		a.global_position = Vector3(-60, 0.2, -60)
		a.set_physics_process(false)
	var modes := ["walk", "sprint", "crouch"]
	var angles := [0.0, 40.0, 65.0]
	var used := 0
	for b in kerbs:
		if used >= int(Game.cmd_arg("kerbs", "6")): break
		var bb: AABB = b
		var c := bb.get_center()
		var ax := Vector3(1, 0, 0) if bb.size.x < bb.size.z else Vector3(0, 0, 1)
		var half := minf(bb.size.x, bb.size.z) / 2.0
		var did := false
		for sgn in [-1.0, 1.0]:
			var edge: Vector3 = Vector3(c.x, 0, c.z) + ax * sgn * half
			var inward: Vector3 = -ax * sgn
			var ok_side := true
			for ang in angles:
				var d: Vector3 = inward.rotated(Vector3.UP, deg_to_rad(ang))
				var s0: Vector3 = edge - d * 1.6
				var q := PhysicsShapeQueryParameters3D.new()
				q.shape = cap
				q.collision_mask = 1 | 64 | 128
				q.transform = Transform3D(Basis.IDENTITY, s0 + Vector3(0, 1.05, 0))
				if not space.intersect_shape(q, 1).is_empty(): ok_side = false
				var r := space.intersect_ray(PhysicsRayQueryParameters3D.create(s0 + Vector3(0, 0.5, 0), s0 - Vector3(0, 1, 0), 1))
				if r.is_empty() or absf(float(r["position"].y)) > 0.05: ok_side = false
				# and free on top too (no lamp post / car right there)
				var s1: Vector3 = edge + d * 0.6 + Vector3(0, bb.end.y, 0)
				q.transform = Transform3D(Basis.IDENTITY, s1 + Vector3(0, 1.05, 0))
				if not space.intersect_shape(q, 1).is_empty(): ok_side = false
			if not ok_side: continue
			did = true
			for mode in modes:
				for ang in angles:
					var d: Vector3 = inward.rotated(Vector3.UP, deg_to_rad(ang))
					await _walk(at, p, bb, edge, d, mode, ang)
			break
		if did: used += 1
	# the aliens on the same kerbs (by hand, like groundtest: the body, not the AI)
	var al: Array = at.m().aliens().filter(func(a): return not a.dead and not a.R.has("hover") and not a.flying)
	var a_ok := 0
	var a_n := 0
	var a_stall := 0
	if not al.is_empty():
		var a: Node = al[0]
		used = 0
		for b in kerbs:
			if used >= 6: break
			var bb: AABB = b
			var c := bb.get_center()
			var ax := Vector3(1, 0, 0) if bb.size.x < bb.size.z else Vector3(0, 0, 1)
			var half := minf(bb.size.x, bb.size.z) / 2.0
			var edge: Vector3 = Vector3(c.x, 0, c.z) - ax * half
			var s0: Vector3 = edge - ax * 1.6
			var r := space.intersect_ray(PhysicsRayQueryParameters3D.create(s0 + Vector3(0, 0.5, 0), s0 - Vector3(0, 1, 0), 1))
			if r.is_empty() or absf(float(r["position"].y)) > 0.05: continue
			used += 1
			for ang in [0.0, 50.0]:
				var d: Vector3 = ax.rotated(Vector3.UP, deg_to_rad(ang))
				a.global_position = edge - d * 1.6 + Vector3(0, 0.05, 0)
				a.velocity = Vector3.ZERO
				a_n += 1
				var ok := false
				for f in 120:
					await at.get_tree().physics_frame
					var dv: Vector3 = d * 2.5
					var before: Vector3 = a.global_position
					a.velocity = Vector3(dv.x, a.velocity.y - 9.8 / 60.0 if not a.is_on_floor() else 0.0, dv.z)
					a.StepUp.climb(a, 1.0 / 60.0, a.StepUp.ALIEN)
					a.move_and_slide()
					var mv: Vector3 = a.global_position - before
					mv.y = 0
					if mv.length() < 2.5 / 60.0 * 0.35 and a.global_position.y < bb.end.y - 0.04: a_stall += 1
					var ap: Vector3 = a.global_position
					if ap.y > bb.end.y - 0.04 and (ap - edge).dot(d) > 0.5:
						ok = true
						break
				if ok: a_ok += 1
				else: at.out("[KERB] alien stuck %d° at %s (kerb %.2f, edge %s)" % [int(ang), a.global_position.snapped(Vector3.ONE * 0.01), bb.end.y, edge.snapped(Vector3.ONE * 0.01)])
	# summary
	var lines := []
	var tot_ok := 0
	var tot := 0
	var tot_stall := 0
	var worst_rise := 0.0
	for k in _res:
		var v: Array = _res[k]
		lines.append("%s %d/%d stall %d" % [k, v[0], v[1], v[2]])
		tot_ok += v[0]; tot += v[1]; tot_stall += v[2]
		worst_rise = maxf(worst_rise, v[3])
	for l in lines: at.out("[KERB] " + l)
	at.out("RESULT kerbtest merc %d/%d stall %d rise %.2f alien %d/%d stall %d" % [tot_ok, tot, tot_stall, worst_rise, a_ok, a_n, a_stall])
	at.get_tree().quit()

static func _walk(at: Node, p: Node, bb: AABB, edge: Vector3, d: Vector3, mode: String, ang: float) -> void:
	p.crouching = mode == "crouch"
	p.global_position = edge - d * 1.6 + Vector3(0, 0.05, 0)
	p.velocity = Vector3.ZERO
	p.rotation.y = atan2(-d.x, -d.z)
	for f in 6: await at.get_tree().physics_frame
	p.stamina = 100.0
	if mode == "sprint": Input.action_press("sprint")
	Input.action_press("move_forward")
	var ok := false
	var stall := 0
	var rise := 0.0
	var last: Vector3 = p.global_position
	var v_flat := 0.0
	for f in 150:
		await at.get_tree().physics_frame
		var pp: Vector3 = p.global_position
		var mv := Vector3(pp.x - last.x, 0, pp.z - last.z).length()
		if f > 3 and f < 8: v_flat = maxf(v_flat, mv)
		if f >= 8 and pp.y < bb.end.y - 0.04 and mv < v_flat * 0.35: stall += 1
		rise = maxf(rise, pp.y - last.y)
		last = pp
		if pp.y > bb.end.y - 0.04 and (pp - edge).dot(d) > 0.5:
			ok = true
			break
	Input.action_release("move_forward")
	Input.action_release("sprint")
	p.crouching = false
	var k := "%s %d°" % [mode, int(ang)]
	var v: Array = _res.get(k, [0, 0, 0, 0.0])
	v[0] += 1 if ok else 0
	v[1] += 1
	v[2] += stall
	v[3] = maxf(v[3], rise)
	_res[k] = v
	if not ok: at.out("[KERB] stuck %s at %s (kerb %.2f)" % [k, p.global_position.snapped(Vector3.ONE * 0.01), bb.end.y])
