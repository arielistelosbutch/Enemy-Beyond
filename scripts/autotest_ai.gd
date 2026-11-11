extends RefCounted
## Autotests of the aliens' AI (alien_tactics.gd). Called from autotest.gd; @a at is the test driver.
## aimphost/aimpclient: two mercenaries, a squad of greys - how often is one "in cover" in plain sight
##   of one of the two? (run again with --oldai=1 for the old behaviour)
## nadetest: a live grenade at an alien's feet, several times - does it get away?
## searchtest: two aliens lose him - do they go round the hiding places or turn on the spot?
## feartest: two of three fall - does the third pull back?
## squadtest: one mercenary, a squad of greys (--lead=1: with an officer) - from how many sides do the
##   shots come, and how often do several of them fire at once? (0.63 squads)
## packtest: one mercenary standing still, three Líhavci (--race=ohar...) - from where do the blows
##   come, and do they spring together? (0.63 packs)
## heattest: he was seen for a while at one place, then lost elsewhere - does the search go there?
## aimphost --players=4 (+ aimpclient --ci=1..3): the co-op test with up to four mercenaries
## tunetest / styletest / dirtest / nemtest: 0.64 (autotune, the styles, the director, the honest nemesis)

static func run(at: Node, p: Node) -> void:
	match at.mode:
		"aimphost", "aimpclient": _aimp(at, p)
		"nadetest": _nadetest(at, p)
		"searchtest": _searchtest(at, p)
		"feartest": _feartest(at, p)
		"squadtest": _squadtest(at, p)
		"packtest": _packtest(at, p)
		"heattest": _heattest(at, p)
		"tunetest": _tunetest(at, p)
		"styletest": _styletest(at, p)
		"dirtest": _dirtest(at, p)
		"nemtest": _nemtest(at, p)
		"civtest": _civtest(at, p)

static func _open_spots(at: Node, p: Node, ground := false) -> Array:
	# the most open waypoint, and a second one 9-16 m from it that sees it (a man beside his mate)
	var ss: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var wps: Array = at.m().map.get("waypoints", [])
	var a := Vector3.INF
	var an := -1
	for wp in wps:
		var c: Vector3 = wp
		if ground and c.y > 0.8:
			continue                # (on the ground, not up on a roof)
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

static func _place_squad(at: Node, p: Node, center: Vector3, n: int, race: String, rmin := 20.0, rmax := 32.0, toward := Vector3.ZERO) -> void:
	var ss: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var placed := 0
	for k in 300:
		if placed >= n:
			break
		var ang := randf() * TAU
		if toward != Vector3.ZERO:
			ang = atan2(toward.x, toward.z) + randf_range(-0.6, 0.6)    # (all of them from one side)
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

## Only the ones this test put down (the mission's own crew can still turn up late): the rest go.
static func _ours(at: Node, before: Array) -> Array:
	var out := []
	for a in at.m().aliens():
		if a in before:
			a.queue_free()
		else:
			out.append(a)
	return out

static func _aimp(at: Node, p: Node) -> void:
	at._skip_brief()
	if p == null or at.step > 0 or not at.m().started() or at.m().players().size() < int(Game.cmd_arg("players", "2")):
		return
	at.step = 1
	var host: bool = at.mode == "aimphost"
	p.hp = 99999.0
	p.max_hp = 99999.0
	at.m().hud.inventory_open = false
	var spots := _open_spots(at, p)
	var ci := int(Game.cmd_arg("ci", "1"))
	var place: Vector3 = spots[0] if host else spots[1]
	if not host and ci > 1:
		# the third and the fourth man: round the first one, the same distance as the second
		place = at.m().free_spot(spots[0] + (spots[1] - spots[0]).rotated(Vector3.UP, 1.3 if ci == 2 else -1.3) + Vector3(0, 0.3, 0))
	p.global_position = place + Vector3(0, 0.1, 0)
	at.out("AIMP %s at %s" % [at.mode, p.global_position])
	if not host:
		await at.get_tree().create_timer(95.0).timeout
		if not is_instance_valid(at):
			return      # the host finished first and left: the client went back to the menu
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
		var tg: Node = pl[0]
		for q in pl:
			if q.global_position.distance_to(a.global_position) < tg.global_position.distance_to(a.global_position):
				tg = q
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
	at.out("RESULT aimp old %s players %d hide %d exposed %d (%.0f %%) both %d duck %d dmg %.0f hits %d killed %d" % [Game.cmd_arg("oldai", "0"), pl.size(), hide_n, exposed, pct, both, exp_duck, dmg, hits, killed])
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

static func _ang_of(c: Vector3, x: Vector3) -> float:
	return atan2(x.x - c.x, x.z - c.z)

static func _ang_diff(a: float, b: float) -> float:
	return absf(wrapf(a - b, -PI, PI))

static func _squadtest(at: Node, p: Node) -> void:
	if not _solo_start(at, p):
		return
	_clear(at)
	var spots := _open_spots(at, p, true)
	p.global_position = spots[0] + Vector3(0, 0.1, 0)
	var dir0 := Vector3(1, 0, 0).rotated(Vector3.UP, randf() * TAU)
	var c: Vector3 = p.global_position
	await at.get_tree().create_timer(0.5).timeout
	var n := int(Game.cmd_arg("n", "5"))
	var before: Array = at.m().aliens()
	_place_squad(at, p, c, n, Game.cmd_arg("race", "grey"), 18.0, 28.0, dir0)
	if Game.cmd_arg("lead", "") == "1":
		_place_squad(at, p, c, 1, "grey_velitel", 22.0, 30.0, dir0)
	await at.get_tree().create_timer(0.6).timeout
	var al: Array = _ours(at, before)
	for a in al:
		a.target = p
		a.last_seen = p.global_position
		a._enter_combat(p)
	var ss: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var last := {}
	for a in al:
		last[a.name] = a.shots_fired
	var shots := []          # [t, alien, angle]
	var hp0: float = p.hp
	var t := 0.0
	var dur := float(Game.cmd_arg("secs", "70"))
	var hits := 0
	while t < dur:
		await at.get_tree().create_timer(0.1).timeout
		t += 0.1
		for a in al:
			if not is_instance_valid(a):
				continue
			if a.shots_fired > int(last[a.name]):
				last[a.name] = a.shots_fired
				shots.append([t, String(a.name), _ang_of(c, a.global_position)])
		if Game.cmd_arg("dbg", "") != "" and int(t * 10.0) % 30 == 0:
			var line := "t%.0f " % t
			for a in al:
				if is_instance_valid(a):
					line += "%s:%s/%s %s d%.0f sh%d %s| " % [a.name, a.S.keys()[a.state], a.phase, a._role, a.global_position.distance_to(c), a.shots_fired, "SEES " if a.visible_to(p) else ""]
			at.out(line)
		if int(t * 10.0) % 20 == 0:
			# he fires every 2 s at the nearest alien he can see (light hits: the fight goes on)
			at.m().noise(p.global_position, 60.0)
			var tg: Node = null
			for a in al:
				if not is_instance_valid(a) or a.dead:
					continue
				var hh := 0.6 if a.phase == "duck" else (0.8 if a.lurking else 1.1)
				var qr := PhysicsRayQueryParameters3D.create(p.global_position + Vector3(0, 1.4, 0), a.global_position + Vector3(0, hh, 0), Game.WORLD)
				if ss.intersect_ray(qr).is_empty() and (tg == null or a.global_position.distance_to(c) < tg.global_position.distance_to(c)):
					tg = a
			if tg:
				hits += 1
				tg.damage(4.0, p.global_position + Vector3(0, 1.4, 0), p)
	# sides: 45° sectors the shots came from; crossfire: in each 3 s window with two or more
	# shooters, the widest angle between them (average); volleys: 1.5 s windows with 3+ shooters
	var sectors := {}
	for s in shots:
		sectors[int(floor(wrapf(s[2], 0.0, TAU) / (TAU / 8.0)))] = true
	var cross_sum := 0.0
	var cross_n := 0
	var volleys := 0
	var w := 0.0
	while w < dur:
		var who := {}
		var who2 := {}
		for s in shots:
			if s[0] >= w and s[0] < w + 3.0:
				who[s[1]] = s[2]
			if s[0] >= w and s[0] < w + 1.5:
				who2[s[1]] = true
		if who.size() >= 2:
			var mx := 0.0
			var ks := who.keys()
			for i in ks.size():
				for j in range(i + 1, ks.size()):
					mx = maxf(mx, _ang_diff(who[ks[i]], who[ks[j]]))
			cross_sum += rad_to_deg(mx)
			cross_n += 1
		if who2.size() >= 3:
			volleys += 1
		w += 1.5
	var alive := 0
	for a in al:
		if is_instance_valid(a) and not a.dead:
			alive += 1
	at.out("RESULT squadtest old %s shots %d sides %d cross %.0f deg volleys %d dmg %.0f alive %d of %d" % [Game.cmd_arg("oldai", "0"),
		shots.size(), sectors.size(), cross_sum / maxf(1.0, cross_n), volleys, hp0 - p.hp, alive, al.size()])
	at.get_tree().quit()

static func _packtest(at: Node, p: Node) -> void:
	if not _solo_start(at, p):
		return
	_clear(at)
	var spots := _open_spots(at, p, true)
	p.global_position = spots[0] + Vector3(0, 0.1, 0)
	at.m().t = at.m().CALM_TIME + 1.0        # (past the quiet first minute)
	await at.get_tree().create_timer(0.5).timeout
	var n := int(Game.cmd_arg("n", "3"))
	var race := Game.cmd_arg("race", "lihnoun")
	# they come from in front of him (the way he looks)
	var fwd: Vector3 = -p.global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var before: Array = at.m().aliens()
	_place_squad(at, p, p.global_position, n, race, 18.0, 26.0, fwd)
	await at.get_tree().create_timer(0.5).timeout
	var al: Array = _ours(at, before)
	for a in al:
		a.prey = p
		a.target = p
		a.alert = true
		a.state = a.S.COMBAT
	var prev := {}
	var first := {}
	var starts := []
	var behind := 0
	var side := 0
	var front := 0
	var t := 0.0
	var hp0: float = p.hp
	var rot0: Vector3 = p.rotation
	while t < float(Game.cmd_arg("secs", "40")):
		await at.get_tree().create_timer(0.05).timeout
		t += 0.05
		p.rotation = rot0                          # (he stands there, looking ahead)
		if int(t * 20.0) % 30 == 0:
			at.m().noise(p.global_position, 30.0)   # (an Ohař hunts by ear)
		if Game.cmd_arg("dbg", "") != "" and int(t * 20.0) % 40 == 0:
			var line := "t%.0f " % t
			for a in al:
				if is_instance_valid(a):
					line += "%s:%s ch%s slot%s d%.1f st%s | " % [a.name, a.S.keys()[a.state], a._charging, a._slot != Vector3.INF, a.global_position.distance_to(p.global_position), a.striking]
			at.out(line)
		for a in al:
			if not is_instance_valid(a) or a.dead:
				continue
			var on: bool = a.striking or a.leaping
			if on and not prev.get(a.name, false):
				var to: Vector3 = a.global_position - p.global_position
				to.y = 0
				var dt: float = fwd.dot(to.normalized()) if to.length() > 0.1 else 1.0
				starts.append([t, String(a.name)])
				if not first.has(a.name):
					# (the first blow of each: where it came from - after that they cling to him anyway)
					first[a.name] = t
					if dt < -0.3:
						behind += 1
					elif dt < 0.4:
						side += 1
					else:
						front += 1
			prev[a.name] = on
	var together := 0
	for i in starts.size():
		for j in starts.size():
			if i != j and starts[i][1] != starts[j][1] and absf(float(starts[i][0]) - float(starts[j][0])) < 1.5:
				together += 1
				break
	var fs: Array = first.values()
	var spread: float = (fs.max() - fs.min()) if fs.size() > 1 else -1.0
	at.out("RESULT packtest old %s race %s strikes %d first_behind %d first_side %d first_front %d together %d first_spread %.1f s dmg %.0f" % [Game.cmd_arg("oldai", "0"),
		race, starts.size(), behind, side, front, together, spread, hp0 - p.hp])
	at.get_tree().quit()

static func _heattest(at: Node, p: Node) -> void:
	if not _solo_start(at, p):
		return
	_clear(at)
	var spots := _open_spots(at, p)
	var a_spot: Vector3 = spots[0]
	# a place 14-22 m from it, where they will think he went
	var b_spot := a_spot
	for wp in at.m().map.get("waypoints", []):
		var d: float = (wp as Vector3).distance_to(a_spot)
		if d > 14.0 and d < 22.0:
			b_spot = wp
			break
	p.global_position = a_spot + Vector3(0, 0.1, 0)
	await at.get_tree().create_timer(0.5).timeout
	var before: Array = at.m().aliens()
	_place_squad(at, p, a_spot, 2, Game.cmd_arg("race", "grey"), 14.0, 20.0)
	await at.get_tree().create_timer(0.5).timeout
	var al: Array = _ours(at, before)
	# 1) they see him about the open place for a while (he walks round it)
	for i in 30:
		p.global_position = at.m().free_spot(a_spot + Vector3(randf_range(-4, 4), 0.3, randf_range(-4, 4)))
		for a in al:
			a._know(p, 1.0)
			a.react = 99.0
			a.state = a.S.LURK
			a.alert = false
		await at.get_tree().create_timer(1.0).timeout
	# 2) he is gone; they are put down past the other place and think he went there
	p.set_physics_process(false)
	p.global_position += Vector3(0, -60, 0)
	var away: Vector3 = (b_spot - a_spot)
	away.y = 0
	away = away.normalized() if away.length() > 0.1 else Vector3.RIGHT
	for a in al:
		a.global_position = at.m().free_spot(b_spot + away * 6.0 + Vector3(randf_range(-2, 2), 0.3, randf_range(-2, 2)))
		a.known = {}
		a.react = 0.0
		a.alert = true
		a.last_seen = b_spot
		a.state = a.S.INVESTIGATE
		a._go(a._snap(b_spot))
	var near_t := 0.0
	var min_d := 1e9
	for i in 80:
		await at.get_tree().create_timer(0.5).timeout
		for a in al:
			if not is_instance_valid(a):
				continue
			var d: float = a.global_position.distance_to(a_spot)
			min_d = minf(min_d, d)
			if d < 8.0:
				near_t += 0.5
	at.out("RESULT heattest old %s a_to_b %.0f m min_dist %.1f near_a %.1f s" % [Game.cmd_arg("oldai", "0"), a_spot.distance_to(b_spot), min_d, near_t])
	at.get_tree().quit()

# ---- 0.64 (the AI plan, steps 5-8) ---------------------------------------------------------------------
## tunetest: one mercenary with his normal health at a cover point, a bot that fires every 0.8 s at the
##   nearest alien it can see (hits like a fair shot with a rifle), three greys (--n, --race) 22-34 m
##   away who know of him. Does he go down within 90 s? (tools/autotune.sh runs it over seeds,
##   difficulties and --aitune values)
static func _tunetest(at: Node, p: Node) -> void:
	at._skip_brief()
	if p == null or at.step > 0 or not at.m().started():
		return
	at.step = 1
	at.m().hud.inventory_open = false
	var hp0: float = p.hp
	_clear(at)
	var spots := _open_spots(at, p, true)
	# the cover point nearest the open place: he stands at it, as a man would
	var stand: Vector3 = spots[0]
	var bd := 1e9
	for c in at.m().map.get("cover", []):
		var d: float = (c as Vector3).distance_to(spots[0])
		if d < bd and absf((c as Vector3).y - spots[0].y) < 0.6:
			bd = d
			stand = c
	p.global_position = stand + Vector3(0, 0.1, 0)
	await at.get_tree().create_timer(1.0).timeout
	var before: Array = at.m().aliens()
	var n := int(Game.cmd_arg("n", "3"))
	_place_squad(at, p, stand, n, Game.cmd_arg("race", "grey"), 22.0, 34.0)
	await at.get_tree().create_timer(0.5).timeout
	var al: Array = _ours(at, before)
	for a in al:
		a.target = p
		a.last_seen = p.global_position
		a._enter_combat(p)
	var ss: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var t := 0.0
	var down := false
	var shots := 0
	while t < 90.0:
		await at.get_tree().create_timer(0.8).timeout
		t += 0.8
		if not is_instance_valid(p) or p.downed or p.dead:
			down = true
			break
		var alive := 0
		var tg: Node = null
		for a in al:
			if not is_instance_valid(a) or a.dead or a.husk:
				continue
			alive += 1
			var hh := 0.6 if a.phase == "duck" else (0.8 if a.lurking else 1.1)
			var qr := PhysicsRayQueryParameters3D.create(p.global_position + Vector3(0, 1.4, 0), a.global_position + Vector3(0, hh, 0), Game.WORLD)
			if ss.intersect_ray(qr).is_empty() and (tg == null or a.global_position.distance_to(p.global_position) < tg.global_position.distance_to(p.global_position)):
				tg = a
		if alive == 0:
			break
		if tg:
			shots += 1
			at.m().noise(p.global_position, 45.0)
			var d: float = tg.global_position.distance_to(p.global_position)
			if randf() < clampf(0.75 - d * 0.012, 0.3, 0.7) * (0.6 if tg.phase == "duck" else 1.0):
				tg.damage(32.0, p.global_position + Vector3(0, 1.4, 0), p)
	var killed := 0
	for a in al:
		if not is_instance_valid(a) or a.dead:
			killed += 1
	at.out("RESULT tunetest diff %s tune %s old %s down %s t %.0f killed %d of %d shots %d hp %.0f of %.0f" % [Net.mission_difficulty, Game.cmd_arg("aitune", "-"),
		Game.cmd_arg("oldai", "0"), down, t, killed, al.size(), shots, p.hp if is_instance_valid(p) else -1.0, hp0])
	at.get_tree().quit()

## styletest: what the next move is weighed to be against the same man, with each style he can be known
##   for (and none): the share of each choice over 300 weighings of one grey 20 m from him.
static func _styletest(at: Node, p: Node) -> void:
	if not _solo_start(at, p):
		return
	_clear(at)
	var spots := _open_spots(at, p, true)
	p.global_position = spots[0] + Vector3(0, 0.1, 0)
	await at.get_tree().create_timer(0.5).timeout
	var before: Array = at.m().aliens()
	_place_squad(at, p, spots[0], 1, Game.cmd_arg("race", "jestetan"), 18.0, 22.0)
	await at.get_tree().create_timer(0.5).timeout
	var al: Array = _ours(at, before)
	if al.is_empty():
		at.out("RESULT styletest failed (no alien)")
		at.get_tree().quit()
		return
	var a: Node = al[0]
	a.set_physics_process(false)
	a.target = p
	a.last_seen = p.global_position
	var line := "RESULT styletest"
	for tg in ["", "far", "close", "dug_in", "loner"]:
		Net.mission_params["styles"] = {String(p.display_name): [tg]} if tg != "" else {}
		var cnt := {}
		for i in 300:
			var sc: Array = a.AM.scores(a)
			var top := String(sc[0][1])
			cnt[top] = int(cnt.get(top, 0)) + 1
		var keys := cnt.keys()
		keys.sort_custom(func(x, y): return cnt[x] > cnt[y])
		var parts := []
		for k in keys.slice(0, 3):
			parts.append("%s %d%%" % [k, roundi(100.0 * cnt[k] / 300.0)])
		line += " | %s: %s" % [tg if tg != "" else "none", ", ".join(parts)]
	at.out(line)
	at.get_tree().quit()

## dirtest: the director. A quiet start, a fight (he takes hits, they fire at him), quiet again: when do
##   the beats (knock, power) and the hunt come, and does the tension rise and fall?
static func _dirtest(at: Node, p: Node) -> void:
	if not _solo_start(at, p):
		return
	p.hp = 30.0
	p.max_hp = 30.0
	var m: Node = at.m()
	var AD: Script = load("res://scripts/ai_director.gd")
	var fight_beats := 0
	var beats_at := []
	var peak := 0.0
	var phases := []
	var had: Dictionary = m._radio_done.duplicate()
	for i in 260:
		await at.get_tree().create_timer(1.0).timeout
		var tt: float = m.t
		var in_fight := tt > 70.0 and tt < 110.0
		if in_fight:
			if i % 3 == 0:
				p.hp = maxf(5.0, p.hp - 4.0)
			m.combat_t = tt
		else:
			p.hp = minf(30.0, p.hp + 1.0)
		peak = maxf(peak, AD.tension(m))
		var ph: String = AD.phase(m)
		if phases.is_empty() or phases[-1] != ph:
			phases.append(ph)
		for k in m._radio_done:
			if not had.has(k):
				had[k] = true
				beats_at.append("%s@%.0f" % [k, tt])
				if AD.tension(m) >= AD.T_QUIET or (tt > 70.0 and tt < 110.0):
					fight_beats += 1
	at.out("RESULT dirtest old %s peak %.2f phases %s beats %s in_fight %d" % [Game.cmd_arg("oldai", "0"), peak, "-".join(phases), " ".join(beats_at), fight_beats])
	at.get_tree().quit()

## nemtest: a marked man the aliens have not seen - does a hunter still walk to him? Then they see him
##   once and he moves 30 m on: does the hunter go where they had him (not where he is)?
static func _nemtest(at: Node, p: Node) -> void:
	if not _solo_start(at, p):
		return
	_clear(at)
	var spots := _open_spots(at, p, true)
	var home: Vector3 = spots[0]
	p.global_position = home + Vector3(0, 0.1, 0)
	await at.get_tree().create_timer(0.5).timeout
	var before: Array = at.m().aliens()
	_place_squad(at, p, home, 1, "grey", 40.0, 50.0)
	await at.get_tree().create_timer(0.5).timeout
	var al: Array = _ours(at, before)
	if al.is_empty():
		at.out("RESULT nemtest failed (no alien)")
		at.get_tree().quit()
		return
	var a: Node = al[0]
	a.nemesis = p
	a._nem_t = 0.0
	var d0: float = a.global_position.distance_to(p.global_position)
	# 1) 20 s unseen (he keeps out of its sight: far below the map)
	var hidden: Vector3 = p.global_position
	p.set_physics_process(false)
	p.global_position = hidden + Vector3(0, -80, 0)
	await at.get_tree().create_timer(20.0).timeout
	var unseen_goal_d: float = a.goal.distance_to(hidden)
	var stalked_unseen: bool = a.state == a.S.STALK
	# 2) seen once at home, then gone 30 m away: the hunt goes to home
	p.global_position = hidden
	a._know(p, 0.5)
	await at.get_tree().create_timer(0.3).timeout
	var away: Vector3 = at.m().free_spot(home + Vector3(30, 0.3, 0))
	p.global_position = away + Vector3(0, -80, 0)
	a.state = a.S.LURK
	a.known = {}
	a._seen_pos = {}
	a._nem_t = 0.0
	await at.get_tree().create_timer(1.0).timeout
	var goal_home: float = a.goal.distance_to(home)
	var goal_away: float = a.goal.distance_to(away)
	at.out("RESULT nemtest old %s start %.0f m unseen_stalk %s unseen_goal %.0f m seen_stalk %s goal_to_seen %.0f m goal_to_real %.0f m" % [Game.cmd_arg("oldai", "0"),
		d0, stalked_unseen, unseen_goal_d, a.state == a.S.STALK, goal_home, goal_away])
	at.get_tree().quit()

## civtest: a terror with nobody to stop it (the mercenary out of the way): after 70 s, how many of the
##   people are dead, how many shot by the gunmen, and how far do the living ones keep from the aliens?
static func _civtest(at: Node, p: Node) -> void:
	if not _solo_start(at, p):
		return
	var m: Node = at.m()
	p.set_physics_process(false)
	p.global_position += Vector3(0, -80, 0)
	m.t += 70.0
	var n0: int = m.civilians().size()
	var gap := 0.0
	var gn := 0
	for i in 70:
		await at.get_tree().create_timer(1.0).timeout
		for c in m.civilians():
			if c.dead or c.saved:
				continue
			var dmin := 1e9
			for a in m.aliens():
				if not a.dead:
					dmin = minf(dmin, a.global_position.distance_to(c.global_position))
			if dmin < 1e8:
				gap += minf(dmin, 60.0)
				gn += 1
	var dead := 0
	for c in m.civilians():
		if c.dead:
			dead += 1
	var races := {}
	for a in m.aliens():
		races[a.race] = int(races.get(a.race, 0)) + 1
	at.out("RESULT civtest old %s v063 %s civ %d dead %d gap %.1f m aliens %s" % [Game.cmd_arg("oldai", "0"), Game.cmd_arg("ai063", "0"), n0, dead, gap / maxf(1.0, gn), races])
	at.get_tree().quit()
