extends RefCounted
## ceiltest (0.69, Ari: „kluci proskočili stropem budovy“): voják se postaví na mřížku míst
## uvnitř budov (nad hlavou je střecha / strop s kolizí) a v 8 směrech zkusí přitažení (výskok
## s drženým skokem, přitažení ze stoje) a vylezení po třetím skoku. Chyba = cíl leží na střeše
## nebo nad stropem místnosti (tělo by prošlo stropem). Navíc pár skutečných skoků u zdí
## (skok + dopředu, mezerník držený) - po nich musí voják stát pod stropem.

static func run(at: Node, p: Node) -> void:
	if p == null: return
	at._skip_brief()
	if at.step > 0 or not at.m().started(): return
	at.step = 1
	p.hp = 1.0e6
	at.m().hud.inventory_open = false
	for a in at.m().aliens():
		a.set_physics_process(false)
		a.visible = false
		a.global_position += Vector3(0, -200, 0)
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var sz: float = float(at.m().map.get("size", 60.0))
	var spots := []        # [feet, ceiling y]
	var x := 0.6
	while x < sz:
		var z := 0.6
		while z < sz:
			for fy in [0.0, 3.2, 6.4]:
				var down := PhysicsRayQueryParameters3D.create(Vector3(x, fy + 2.0, z), Vector3(x, fy - 0.4, z), Game.WORLD)
				down.exclude = [p.get_rid()]
				var fh := space.intersect_ray(down)
				if fh.is_empty() or (fh.normal as Vector3).y < 0.8:
					continue
				var feet: Vector3 = fh.position
				var up := PhysicsRayQueryParameters3D.create(feet + Vector3(0, 1.0, 0), feet + Vector3(0, 7.0, 0), Game.WORLD)
				up.exclude = [p.get_rid()]
				up.hit_back_faces = true
				var ch := space.intersect_ray(up)
				if ch.is_empty():
					continue
				var cy: float = (ch.position as Vector3).y
				if cy - feet.y < 1.9:
					continue           # under a table, a shelf
				# room for the body
				var cap := CapsuleShape3D.new()
				cap.radius = 0.32
				cap.height = 1.75
				var q := PhysicsShapeQueryParameters3D.new()
				q.shape = cap
				q.collision_mask = Game.WORLD
				q.exclude = [p.get_rid()]
				q.transform = Transform3D(Basis(), feet + Vector3(0, 0.95, 0))
				if not space.intersect_shape(q, 1).is_empty():
					continue
				spots.append([feet, cy])
			z += 0.75
		x += 0.75
	var tries := 0
	var leaks := 0
	var shown := 0
	var unstuck_leaks := 0
	var picked := []       # real jumps: where the check found a way up (before the fix), else by walls
	for s in spots:
		var feet: Vector3 = s[0]
		var cy: float = s[1]
		p.global_position = feet + Vector3(0, 0.02, 0)
		p.velocity = Vector3.ZERO
		p.crouching = false
		for k in 8:
			p.rotation.y = TAU * k / 8.0
			for reach in [p.MANTLE_JUMP, p.MANTLE_STAND]:
				tries += 1
				var t: Vector3 = p.mantle_spot(reach)
				if t != Vector3.INF and t.y > cy - 0.3:
					leaks += 1
					var far := true
					for o in picked:
						if (o[0] as Vector3).distance_to(feet) < 4.0: far = false
					if far and picked.size() < 10:
						picked.append([feet, cy, p.rotation.y])
					if shown < 12:
						shown += 1
						at.out("leak mantle at %s ceil %.2f -> %s" % [feet.snapped(Vector3.ONE * 0.01), cy, t.snapped(Vector3.ONE * 0.01)])
			# the third jump on the spot
			p._stuck_at = p.global_position
			p._stuck_n = 2
			p._mantle_t = -1.0
			if p._unstuck_try():
				var t2: Vector3 = p._mantle_to
				if t2.y > cy - 0.3:
					unstuck_leaks += 1
					if shown < 12:
						shown += 1
						at.out("leak unstuck at %s ceil %.2f -> %s" % [feet.snapped(Vector3.ONE * 0.01), cy, t2.snapped(Vector3.ONE * 0.01)])
			p._mantle_t = -1.0
			p._stuck_n = 0
	# real jumps: a few indoor spots next to a wall, jump held and forward
	var real := 0
	var real_bad := 0
	for s in spots:
		if picked.size() >= 10: break
		var feet: Vector3 = s[0]
		if float(s[1]) - feet.y > 3.3:
			continue           # (low ceilings first: there the roof is within the reach of a jump)
		for k in 8:
			var a := TAU * k / 8.0
			var fwd := Vector3(-sin(a), 0, -cos(a))
			var q := PhysicsRayQueryParameters3D.create(feet + Vector3(0, 1.2, 0), feet + Vector3(0, 1.2, 0) + fwd * 0.7, Game.WORLD)
			q.exclude = [p.get_rid()]
			if not space.intersect_ray(q).is_empty():
				var far := true
				for o in picked:
					if (o[0] as Vector3).distance_to(feet) < 4.0: far = false
				if far:
					picked.append([feet, s[1], a])
				break
	for s in picked:
		var feet: Vector3 = s[0]
		p.global_position = feet + Vector3(0, 0.02, 0)
		p.velocity = Vector3.ZERO
		p.rotation.y = s[2]
		p._mantle_t = -1.0
		p._stuck_n = 0
		p.crouching = false
		p.prone = false
		for f in 10: await at.get_tree().physics_frame
		Input.action_press("move_forward")
		var top_y := -100.0
		var mant := false
		for j in 4:
			Input.action_press("jump")
			for f in 40:
				await at.get_tree().physics_frame
				top_y = maxf(top_y, p.global_position.y)
				if p._mantle_t >= 0.0 and not mant and Game.cmd_arg("cdebug", "") == "1":
					at.out("  mantle from %s to %s" % [p._mantle_from.snapped(Vector3.ONE * 0.01), p._mantle_to.snapped(Vector3.ONE * 0.01)])
				mant = mant or p._mantle_t >= 0.0
			Input.action_release("jump")
			for f in 15: await at.get_tree().physics_frame
		Input.action_release("move_forward")
		for f in 40: await at.get_tree().physics_frame
		real += 1
		if Game.cmd_arg("cdebug", "") == "1":
			at.out("jump at %s ceil %.2f top %.2f mantle %s now %s" % [feet.snapped(Vector3.ONE * 0.01), s[1], top_y, mant, p.global_position.snapped(Vector3.ONE * 0.01)])
		if top_y > float(s[1]) - 0.3:
			real_bad += 1
			at.out("leak jump at %s ceil %.2f top %.2f -> now %s" % [feet.snapped(Vector3.ONE * 0.01), s[1], top_y, p.global_position.snapped(Vector3.ONE * 0.01)])
	at.out("RESULT ceiltest %d spots, %d tries, leaks %d, unstuck %d, jumps %d bad %d" % [spots.size(), tries, leaks, unstuck_leaks, real, real_bad])
	at.get_tree().quit()
