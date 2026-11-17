extends RefCounted
## 0.7x nové typy misí. convoytest: Uvízlý konvoj – na mapě je silnice s náklaďáky a nákladem,
## vlny přicházejí, vetřelci jdou k nákladu a páčí ho, po --hold s přiletí Čáp, úkol je splněný
## (Enter = odlet, úspěch). S --fail=1 tým stojí stranou a vetřelci náklad rozbijí = neúspěch.

static func convoy(at: Node, p: Node) -> void:
	if p == null: return
	at._skip_brief()
	if at.step > 0 or not at.m().started(): return
	at.step = 1
	var m: Node = at.m()
	m.hud.inventory_open = false
	p.hp = 99999.0
	p.max_hp = 99999.0
	var fail := Game.cmd_arg("fail", "") == "1"
	var spots: Array = m.cargo_spots()
	var crates: int = at.get_tree().get_nodes_in_group("cargo_crate").size()
	at.out("[CONVOY] cargo spots %d crates %d hold %.0f waves %d aliens %d" % [spots.size(), crates, m._hold, m.waves_left, m.alive_aliens()])
	if fail:
		# the team stands aside in the Kondor (nobody sees it), the aliens are at the trucks
		p.global_position = m.map["evac"] + Vector3(0, 0.3, -1.0)
		for a in m.aliens():
			a.global_position = m.free_spot(spots[0] + Vector3(randf_range(-2, 2), 0.3, randf_range(-2, 2)))
			a.state = a.S.LURK
	var t0: float = m.t
	var waves0: int = m.waves_left
	var near_min := 999.0
	var hp_min := 100.0
	var tmax: float = 120.0 if fail else float(m._hold) + 20.0
	while m.t - t0 < tmax and not m.finished:
		await at.get_tree().create_timer(0.25).timeout
		if not fail:
			p.hp = 99999.0
		hp_min = minf(hp_min, m.cargo_hp)
		for a in m.aliens():
			if a.dead: continue
			for sp in spots:
				near_min = minf(near_min, a.global_position.distance_to(sp))
		if m.convoy_saved and m.done_banner:
			break
	var crates_after := -1
	if m.convoy_saved:
		await at.get_tree().create_timer(23.0).timeout
		crates_after = at.get_tree().get_nodes_in_group("cargo_crate").size()
		p.wants_evac = true
		await at.get_tree().create_timer(1.0).timeout
	at.out("RESULT convoytest saved %s banner %s cargo %.0f level %d waves %d near %.1f crates_after %d finished %s" % [m.convoy_saved, m.done_banner, hp_min, m.cargo_level, waves0 - m.waves_left, near_min, crates_after, m.finished])
	await at.get_tree().create_timer(0.5).timeout
	at.get_tree().quit()

## bugtest: Štěnice na lodi. Bez --fail: vetřelci jsou daleko, voják dojde k místu u trupu a
## připevní štěnici (plant), úkol splněn, odlet = úspěch a v kořisti bug_tag. S --fail=1 si ho jeden
## vetřelec všimne (boj), loď se zahřeje a odstartuje (bug_gone, kdo byl u lodi, zmizí), odlet =
## neúspěch.
static func bug(at: Node, p: Node) -> void:
	if p == null: return
	at._skip_brief()
	if at.step > 0 or not at.m().started(): return
	at.step = 1
	var m: Node = at.m()
	m.hud.inventory_open = false
	p.hp = 99999.0
	p.max_hp = 99999.0
	var fail := Game.cmd_arg("fail", "") == "1"
	var bi := -1
	for i in m.beacons.size():
		if m.beacons[i].get("bug", false):
			bi = i
	var spot: Vector3 = m.beacons[bi]["pos"] if bi >= 0 else Vector3.INF
	var c: Vector3 = m.map["ufo"]
	at.out("[BUG] spot %s ship %s r %.1f kind %s aliens %d near_ship %d" % [spot, c, m._ship_r(), m.map.get("ufo_kind", ""), m.alive_aliens(), m.aliens().filter(func(a): return Vector2(a.global_position.x - c.x, a.global_position.z - c.z).length() < m._ship_r() + 1.5).size()])
	if bi < 0:
		at.out("RESULT bugtest nospot")
		at.get_tree().quit()
		return
	var t0: float = m.t
	if not fail:
		for a in m.aliens():
			a.global_position = m._far_point(RandomNumberGenerator.new(), 45.0)
			a.state = a.S.LURK
		p.global_position = spot + Vector3(0, 0.4, 0)
		await at.get_tree().create_timer(0.5).timeout
		var near: int = m.beacon_near(p.global_position)
		m.plant(near)
		await at.get_tree().create_timer(1.0).timeout
		var loot: Dictionary = m._loot(true)
		at.out("[BUG] near %d tagged %s banner %s loot_tag %d gone %s" % [near, m.bug_tagged, m.done_banner, int(loot.get("bug_tag", 0)), m.bug_gone])
	else:
		p.global_position = m.map["evac"] + Vector3(0, 0.3, -1.0)
		var a0: Node = null
		for a in m.aliens():
			if not a.dead:
				a0 = a
				break
		if a0:
			a0.target = p
			a0.state = a0.S.COMBAT
		var before: int = m.alive_aliens()
		while m.t - t0 < 60.0 and not m.bug_gone:
			await at.get_tree().create_timer(0.25).timeout
			p.hp = 99999.0
		var ship_y: float = m.map["ufo_node"].global_position.y if is_instance_valid(m.map.get("ufo_node")) else -1.0
		await at.get_tree().create_timer(9.0).timeout
		at.out("[BUG] gone %s after %.1f s aliens %d -> %d ship_y %.1f freed %s" % [m.bug_gone, m.t - t0, before, m.alive_aliens(), ship_y, not is_instance_valid(m.map.get("ufo_node"))])
	p.global_position = m.map["evac"] + Vector3(0, 0.3, -1.0)
	p.wants_evac = true
	await at.get_tree().create_timer(2.0).timeout
	at.out("RESULT bugtest tagged %s gone %s finished %s" % [m.bug_tagged, m.bug_gone, m.finished])
	await at.get_tree().create_timer(0.5).timeout
	at.get_tree().quit()

## quartest: Karanténa. Zdroj nákazy v domě, civilisté (část nakažených, poznat jen zblízka),
## zastřelený nakažený = vylíhne se Líhavec, nakažený, který jde za vojákem, se cestou do Kondoru
## promění, zdravý dojde do Kondoru; nálož na zdroj = úkol splněn, odlet = úspěch.
static func quar(at: Node, p: Node) -> void:
	if p == null: return
	at._skip_brief()
	if at.step > 0 or not at.m().started(): return
	at.step = 1
	var m: Node = at.m()
	m.hud.inventory_open = false
	p.hp = 99999.0
	p.max_hp = 99999.0
	await at.get_tree().create_timer(1.0).timeout
	for a in m.aliens():
		a.set_physics_process(false)
	var civs: Array = m.civilians()
	var sick: Array = civs.filter(func(c): return c.carrier)
	var well: Array = civs.filter(func(c): return not c.carrier)
	var nest: Vector3 = m.nest_spot()
	var races := {}
	for a in m.aliens():
		races[a.race] = int(races.get(a.race, 0)) + 1
	at.out("[QUAR] civs %d carriers %d nest %s (%.0f m from evac) beacons %d crew %s" % [civs.size(), sick.size(), nest, nest.distance_to(m.map["evac"]), m.beacons.size(), races])
	# a carrier gives itself away only up close
	var c0: Node = sick[0]
	p.global_position = c0.global_position + Vector3(12, 0.3, 0)
	await at.get_tree().create_timer(0.6).timeout
	var far_tell: bool = c0._tell_on
	p.global_position = c0.global_position + Vector3(2.0, 0.3, 0)
	await at.get_tree().create_timer(0.6).timeout
	var near_tell: bool = c0._tell_on
	var w0: Node = well[0]
	p.global_position = w0.global_position + Vector3(2.0, 0.3, 0)
	await at.get_tree().create_timer(0.6).timeout
	at.out("[QUAR] tell far %s near %s healthy %s" % [far_tell, near_tell, w0._tell_on])
	# shot carrier -> a Líhavec
	var n0: int = m.aliens().size()
	m.shoot_civ(c0.name)
	await at.get_tree().create_timer(6.0).timeout
	var hatched: int = m.aliens().filter(func(a): return a.race == "lihnoun").size()
	at.out("[QUAR] shot carrier dead %s -> lihnoun %d (aliens %d -> %d)" % [c0.dead, hatched, n0, m.aliens().size()])
	for a in m.aliens():
		a.set_physics_process(false)
	# a carrier following to the Kondor turns on the way
	if sick.size() > 1:
		var c1: Node = sick[1]
		c1.global_position = m.free_spot(m.map["evac"] + Vector3(20, 0.3, 0))
		p.global_position = c1.global_position + Vector3(1.5, 0.3, 0)
		c1.calm_by(p)
		for k in 30:
			p.global_position = p.global_position.move_toward(m.map["evac"] + Vector3(0, 0.3, 0), 1.0)
			await at.get_tree().create_timer(0.25).timeout
			if c1.dead: break
		at.out("[QUAR] carrier on the way: dead %s saved %s dist %.1f" % [c1.dead, c1.saved, c1.global_position.distance_to(m.map["evac"])])
	for a in m.aliens():
		a.set_physics_process(false)
	# a healthy one is saved
	for a in m.aliens():
		if a.global_position.distance_to(m.map["evac"]) < 32.0:
			a.global_position = m.map["evac"] + Vector3(0, -40, 0)     # (the Líhavec from the carrier above would scare him: the test is about saving)
	w0.global_position = m.free_spot(m.map["evac"] + Vector3(14, 0.3, 0))
	p.global_position = w0.global_position + Vector3(1.0, 0.3, 0)
	w0.calm_by(p)
	for k in 40:
		p.global_position = p.global_position.move_toward(m.map["evac"] + Vector3(0, 0.3, 0), 0.8)
		await at.get_tree().create_timer(0.25).timeout
		if w0.saved: break
	at.out("[QUAR] healthy follower saved %s" % w0.saved)
	# the nest
	p.global_position = nest + Vector3(1.5, 0.3, 0)
	var bi: int = m.beacon_near(p.global_position)
	m.plant(maxi(0, bi))
	p.global_position = m.map["evac"] + Vector3(0, 0.3, 0)
	await at.get_tree().create_timer(10.0).timeout
	at.out("[QUAR] nest near %d left %d banner %s" % [bi, m.beacons_left(), m.done_banner])
	p.wants_evac = true
	await at.get_tree().create_timer(2.0).timeout
	at.out("RESULT quartest carriers %d tell %s/%s hatched %d saved %s nest %d finished %s" % [sick.size(), near_tell, far_tell, hatched, w0.saved, m.beacons_left(), m.finished])
	await at.get_tree().create_timer(0.5).timeout
	at.get_tree().quit()
