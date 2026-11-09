extends RefCounted
## Autotests of the aliens' AI (alien_tactics.gd). Called from autotest.gd; @a at is the test driver.
## aimphost/aimpclient: two mercenaries, a squad of greys - how often is one "in cover" in plain sight
##   of one of the two? (run again with --oldai=1 for the old behaviour)
## nadetest: a live grenade at an alien's feet, several times - does it get away?
## searchtest: two aliens lose him - do they go round the hiding places or turn on the spot?
## feartest: two of three fall - does the third pull back?

static func run(at: Node, p: Node) -> void:
	match at.mode:
		"aimphost", "aimpclient": _aimp(at, p)
		"nadetest": _nadetest(at, p)
		"searchtest": _searchtest(at, p)
		"feartest": _feartest(at, p)

static func _open_spots(at: Node, p: Node) -> Array:
	# the most open waypoint, and a second one 9-16 m from it that sees it (a man beside his mate)
	var ss: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var wps: Array = at.m().map.get("waypoints", [])
	var a := Vector3.INF
	var an := -1
	for wp in wps:
		var c: Vector3 = wp
		var n := 0
		for k in 8:
			var ang := k * TAU / 8.0
			var q := PhysicsRayQueryParameters3D.create(c + Vector3(0, 1.4, 0), c + Vector3(sin(ang) * 25.0, 1.4, cos(ang) * 25.0), Game.WORLD)
			if ss.intersect_ray(q).is_empty():
				n += 1
		if n > an:
			an = n
			a = c
	var b := a + Vector3(12, 0, 0)
	var bd := 1e9
	for wp in wps:
		var c: Vector3 = wp
		var d := c.distance_to(a)
		if d < 9.0 or d > 16.0:
			continue
		var q := PhysicsRayQueryParameters3D.create(c + Vector3(0, 1.4, 0), a + Vector3(0, 1.4, 0), Game.WORLD)
		if not ss.intersect_ray(q).is_empty():
			continue
		var sc := absf(d - 12.0)
		if sc < bd:
			bd = sc
			b = c
	return [a, b]

static func _place_squad(at: Node, p: Node, center: Vector3, n: int, race: String, rmin := 20.0, rmax := 32.0) -> void:
	var ss: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var placed := 0
	for k in 300:
		if placed >= n:
			break
		var ang := randf() * TAU
		var pt: Vector3 = at.m().free_spot(center + Vector3(sin(ang), 0, cos(ang)) * randf_range(rmin, rmax) + Vector3(0, 0.3, 0))
		var fq := PhysicsRayQueryParameters3D.create(pt + Vector3(0, 1.0, 0), pt + Vector3(0, -1.0, 0), Game.WORLD)
		var fh := ss.intersect_ray(fq)
		if fh.is_empty() or absf(fh.position.y - center.y) > 0.6:
			continue
		at.m().spawn_alien(race, pt)
		placed += 1

static func _clear(at: Node) -> void:
	for a in at.m().aliens():
		a.queue_free()

static func _aimp(at: Node, p: Node) -> void:
	at._skip_brief()
	if p == null or at.step > 0 or not at.m().started() or at.m().players().size() < 2:
		return
	at.step = 1
	var host: bool = at.mode == "aimphost"
	p.hp = 99999.0
	p.max_hp = 99999.0
	at.m().hud.inventory_open = false
	var spots := _open_spots(at, p)
	p.global_position = (spots[0] if host else spots[1]) + Vector3(0, 0.1, 0)
	at.out("AIMP %s at %s" % [at.mode, p.global_position])
	if not host:
		await at.get_tree().create_timer(95.0).timeout
		at.out("RESULT aimp client hp %.0f" % (p.hp if is_instance_valid(p) else -1.0))
		at.get_tree().quit()
		return
	_clear(at)
	await at.get_tree().create_timer(2.0).timeout
	var mid: Vector3 = (spots[0] + spots[1]) * 0.5
	_place_squad(at, p, mid, int(Game.cmd_arg("n", "4")), Game.cmd_arg("race", "grey"))
	await at.get_tree().create_timer(0.6).timeout
	var pl: Array = at.m().players()
	for a in at.m().aliens():
		var tg: Node = pl[0] if pl[0].global_position.distance_to(a.global_position) < pl[1].global_position.distance_to(a.global_position) else pl[1]
		a.target = tg
		a.last_seen = tg.global_position
		a._enter_combat(tg)
	var ss: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var hide_n := 0
	var exposed := 0
	var both := 0
	var exp_duck := 0
	var hits := 0
	var hp0 := {}
	for q in pl:
		hp0[q.name] = q.hp
	for i in 150:
		await at.get_tree().create_timer(0.5).timeout
		if i % 4 == 3 and Game.cmd_arg("quiet", "") == "":
			# both of them fire every 2 s at the nearest alien they can see (the flash gives them away)
			for q in pl:
				at.m().noise(q.global_position, 60.0)
				var tg: Node = null
				for a in at.m().aliens():
					if a.dead or a.husk:
						continue
					var hh := 0.6 if a.phase == "duck" else (0.8 if a.lurking else 1.1)
					var qr := PhysicsRayQueryParameters3D.create(q.global_position + Vector3(0, 1.4, 0), a.global_position + Vector3(0, hh, 0), Game.WORLD)
					if ss.intersect_ray(qr).is_empty() and (tg == null or a.global_position.distance_to(q.global_position) < tg.global_position.distance_to(q.global_position)):
						tg = a
				if tg:
					hits += 1
					tg.damage(9.0, q.global_position + Vector3(0, 1.4, 0), q)
		for a in at.m().aliens():
			if a.dead or a.state != a.S.COMBAT or not a.phase in ["hide", "duck"] or not a._arrived():
				continue
			hide_n += 1
			var seen := 0
			for q in pl:
				var qr := PhysicsRayQueryParameters3D.create(q.global_position + Vector3(0, 1.4, 0), a.global_position + Vector3(0, 0.6 if a.phase == "duck" else 0.8, 0), Game.WORLD)
				if ss.intersect_ray(qr).is_empty():
					seen += 1
			if seen > 0 and Game.cmd_arg("dbg", "") != "" and i % 4 == 0:
				var who := []
				for q in pl:
					var qr2 := PhysicsRayQueryParameters3D.create(q.global_position + Vector3(0, 1.4, 0), a.global_position + Vector3(0, 0.8, 0), Game.WORLD)
					who.append("%s:%s%s d%.0f" % [q.name, "SEES" if ss.intersect_ray(qr2).is_empty() else "-", " K" if a._knows(q) else "", q.global_position.distance_to(a.global_position)])
				at.out("EXPOSED %s %s thr%d hide_t %.1f flying %s %s" % [a.name, a.phase, a.AT.threats(a).size(), a.hide_t, a.flying, who])
			if seen > 0:
				exposed += 1
				if a.phase == "duck": exp_duck += 1
			if seen > 1:
				both += 1
		if i % 20 == 0:
			var line := ""
			for a in at.m().aliens():
				line += "%s:%s/%s d%.0f thr%d | " % [a.name, a.state, a.phase, a.global_position.distance_to(mid), a.AT.threats(a).size() if not a.dead else -1]
			at.out(line)
	var dmg := 0.0
	for q in pl:
		dmg += float(hp0[q.name]) - float(q.hp)
	var pct := 100.0 * exposed / maxf(1.0, hide_n)
	var killed := int(Game.cmd_arg("n", "4"))
	for a in at.m().aliens():
		if not a.dead: killed -= 1
	at.out("RESULT aimp old %s hide %d exposed %d (%.0f %%) both %d duck %d dmg %.0f hits %d killed %d" % [Game.cmd_arg("oldai", "0"), hide_n, exposed, pct, both, exp_duck, dmg, hits, killed])
	at.get_tree().quit()

static func _solo_start(at: Node, p: Node) -> bool:
	at._skip_brief()
	if p == null or at.step > 0 or not at.m().started():
		return false
	at.step = 1
	p.hp = 99999.0
	p.max_hp = 99999.0
	at.m().hud.inventory_open = false
	return true

static func _nadetest(at: Node, p: Node) -> void:
	if not _solo_start(at, p):
		return
	_clear(at)
	var spots := _open_spots(at, p)
	p.global_position = spots[0] + Vector3(0, 0.1, 0)
	await at.get_tree().create_timer(0.5).timeout
	var trials := int(Game.cmd_arg("n", "8"))
	var away_n := 0
	var alive_n := 0
	for k in trials:
		_place_squad(at, p, p.global_position, 1, Game.cmd_arg("race", "grey"), 10.0, 16.0)
		await at.get_tree().create_timer(0.5).timeout
		var a: Node = null
		for x in at.m().aliens():
			if not x.dead:
				a = x
		if a == null:
			continue
		a.target = p
		a.last_seen = p.global_position
		a._enter_combat(p)
		a.react = 99.0          # (it stands and waits: only the grenade moves it)
		await at.get_tree().create_timer(0.4).timeout
		var off := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * 1.2
		var np: Vector3 = a.global_position + off + Vector3(0, 0.4, 0)
		p._spawn_throwable.rpc("grenade", np, Vector3.ZERO, p.name)
		await at.get_tree().create_timer(2.7).timeout
		var d: float = a.global_position.distance_to(np) if is_instance_valid(a) else 0.0
		var alive: bool = is_instance_valid(a) and not a.dead
		if d > 5.0: away_n += 1
		if alive: alive_n += 1
		at.out("NADE %d %s d %.1f alive %s hp %.0f" % [k, a.race if is_instance_valid(a) else "?", d, alive, a.hp if is_instance_valid(a) else 0.0])
		_clear(at)
		await at.get_tree().create_timer(0.3).timeout
	at.out("RESULT nadetest old %s away %d of %d alive %d" % [Game.cmd_arg("oldai", "0"), away_n, trials, alive_n])
	at.get_tree().quit()

static func _searchtest(at: Node, p: Node) -> void:
	if not _solo_start(at, p):
		return
	_clear(at)
	var spots := _open_spots(at, p)
	# he is gone (far away, out of sight); they think he was at the open spot
	p.global_position = at.m().map["evac"] + Vector3(0, 0.3, 0)
	p.set_physics_process(false)
	p.global_position += Vector3(0, -60, 0)
	await at.get_tree().create_timer(0.3).timeout
	_place_squad(at, p, spots[0], 2, Game.cmd_arg("race", "grey"), 6.0, 10.0)
	await at.get_tree().create_timer(0.5).timeout
	var al: Array = at.m().aliens()
	var start := {}
	for a in al:
		a.alert = true
		a.last_seen = spots[0]
		a.state = a.S.INVESTIGATE
		a._go(a._snap(spots[0]))
		start[a.name] = a.global_position
	var path := {}
	var prev := {}
	for a in al:
		path[a.name] = 0.0
		prev[a.name] = a.global_position
	var searched := false
	for i in 60:
		await at.get_tree().create_timer(0.5).timeout
		for a in al:
			if not is_instance_valid(a):
				continue
			if a.state == a.S.SEARCH:
				searched = true
				path[a.name] += (a.global_position - prev[a.name]).length()
			prev[a.name] = a.global_position
	var tot := 0.0
	for k in path:
		tot += path[k]
	at.out("RESULT searchtest old %s searched %s walked %.0f m" % [Game.cmd_arg("oldai", "0"), searched, tot])
	at.get_tree().quit()

static func _feartest(at: Node, p: Node) -> void:
	if not _solo_start(at, p):
		return
	_clear(at)
	var spots := _open_spots(at, p)
	p.global_position = spots[0] + Vector3(0, 0.1, 0)
	await at.get_tree().create_timer(0.5).timeout
	_place_squad(at, p, p.global_position, 3, Game.cmd_arg("race", "grey"), 16.0, 22.0)
	await at.get_tree().create_timer(0.6).timeout
	var al: Array = at.m().aliens()
	for a in al:
		a.target = p
		a.last_seen = p.global_position
		a._enter_combat(p)
	await at.get_tree().create_timer(2.0).timeout
	# the survivor: the one furthest from the other two; the two closest to each other fall
	var keep: Node = al[al.size() - 1]
	var k := 0
	for a in al:
		if a != keep:
			k += 1
			a.global_position = at.m().free_spot(keep.global_position + Vector3(3.0 * k, 0.3, 2.0))   # (right beside it)
	await at.get_tree().create_timer(0.3).timeout
	for a in al:
		if a != keep:
			a.damage(9999.0, p.global_position + Vector3(0, 1.5, 0), p)
	await at.get_tree().create_timer(0.2).timeout
	var f0: float = keep._fear
	keep.damage(float(keep.R["hp"]) * 0.6, p.global_position + Vector3(0, 1.5, 0), p)
	var fear: float = keep._fear
	var d0: float = keep.global_position.distance_to(p.global_position)
	await at.get_tree().create_timer(14.0).timeout
	at.out("RESULT feartest old %s fear %.2f->%.2f fell_back %d dist %.0f -> %.0f" % [Game.cmd_arg("oldai", "0"), f0, fear, int(keep.get_meta("fell_back", 0)), d0, keep.global_position.distance_to(p.global_position)])
	at.get_tree().quit()
