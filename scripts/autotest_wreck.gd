extends RefCounted
## wrecktest (2026-11-27, Ari: „zničitelné stromy, co hoří po laseru a plazmě; kanón přepůlí kmen;
## auta, co začnou hořet a pak vybuchnou“). Mise s auty i stromy (teror ve městě / havárie na farmě).
##  1) auto: střelba z pušky (skutečné výstřely) -> kouř, oheň, za 8-14 s výbuch, vrak; auto
##     postavené vedle dostane od výbuchu ránu (řetěz)
##  2) strom: laserová puška (skutečné výstřely) -> hoří (oheň u paty)
##  3) strom: autokanón do kmene (skutečné výstřely) -> padne, leží (osa nahoru je vodorovně), pařez
##  4) výbuch granátu u kmene -> strom padne
## Výsledek: RESULT wrecktest trees T cars C car_smoke S car_burn B car_boom X wreck W chain K
##           tree_burn TB tree_fall F lying L stump P blast_fall G

static func _arm(p: Node, w: String) -> void:
	p.inv["rh"] = {"id": w, "loaded": 999}
	p._update_held()
	p.spread_bloom = 0.0

static func _fire(at: Node, p: Node, w: String, target: Vector3, n: int, gap := 0.25) -> void:
	_arm(p, w)
	for k in n:
		at._aim_at(p, target)
		p.spread_bloom = 0.0
		p.fire_cd = 0.0
		var rule: Dictionary = Game.ITEMS[w]
		if rule.get("laser", false):
			p.inv["rh"]["loaded"] = 1
			p.inv["rh"].erase("drained")
		p._pl_shoot("rh", p.inv["rh"], rule)
		await at.get_tree().create_timer(gap).timeout

## místo u věci @a at_p ve vzdálenosti @a dist, odkud je na ni vidět (zkusí 8 směrů)
static func _stand(p: Node, target: Vector3, dist: float, own: Node) -> bool:
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	for k in 8:
		var a := k * TAU / 8.0
		var spot := target + Vector3(sin(a), 0, cos(a)) * dist
		var dq := PhysicsRayQueryParameters3D.create(spot + Vector3(0, 3, 0), spot + Vector3(0, -3, 0), Game.WORLD)
		var dh := space.intersect_ray(dq)
		if dh.is_empty():
			continue
		spot.y = (dh.position as Vector3).y
		var q := PhysicsRayQueryParameters3D.create(spot + Vector3(0, 1.6, 0), target, Game.WORLD | Game.GLASS)
		q.exclude = [p.get_rid()]
		var h := space.intersect_ray(q)
		if (own != null and (h.collider == own or own.is_ancestor_of(h.collider))):
			p.global_position = spot + Vector3(0, 0.05, 0)
			p.velocity = Vector3.ZERO
			return true
	return false

## --stress=1: naráz hoří 10 stromů a 6 aut, pak auta vybuchnou; měří čas snímků (klid / požár / výbuchy).
static func _frames(at: Node, secs: float) -> Array:
	var ts := []
	var t0 := Time.get_ticks_usec()
	var last := t0
	while Time.get_ticks_usec() - t0 < int(secs * 1.0e6):
		await at.get_tree().process_frame
		var now := Time.get_ticks_usec()
		ts.append((now - last) / 1000.0)
		last = now
	ts.sort()
	var sum := 0.0
	for x in ts: sum += x
	return [sum / maxf(ts.size(), 1), ts[int(ts.size() * 0.99)] if ts.size() > 0 else 0.0, ts.back() if ts.size() > 0 else 0.0]

static func stress(at: Node, p: Node) -> void:
	var m: Node = at.m()
	var W: Node = m.wreck
	await at.get_tree().create_timer(1.0).timeout
	var calm: Array = await _frames(at, 6.0)
	var lit := 0
	var cars := 0
	for i in W.count():
		if W.kind[i] == "tree" and lit < 10 and W.state[i] == W.OK:
			W.hit(i, 200.0, "plasma", true, W.base[i] + Vector3(5, 0, 0))
			lit += 1
	for i in W.count():
		if W.kind[i] == "car" and cars < 6 and W.state[i] == W.OK:
			W.hit(i, 250.0, "plasma", true, W.base[i] + Vector3(5, 0, 0))
			cars += 1
	await at.get_tree().create_timer(0.5).timeout
	var fire: Array = await _frames(at, 7.0)
	var boom: Array = await _frames(at, 9.0)
	var gone := 0
	for i in W.count():
		if W.kind[i] == "car" and W.state[i] == W.GONE: gone += 1
	at.out("RESULT wreckstress lit %d cars %d gone %d fires %d klid %.1f ms (99 %% %.0f, max %.0f) pozar %.1f ms (99 %% %.0f, max %.0f) vybuchy %.1f ms (99 %% %.0f, max %.0f)" % [lit, cars, gone, m.fires.size(), calm[0], calm[1], calm[2], fire[0], fire[1], fire[2], boom[0], boom[1], boom[2]])
	at.get_tree().quit()

## wreckhost + wreckclient: klient střílí (zásah jde hostiteli), na konci oba vypíšou stav
## všech stromů a aut - musí být stejný (a strom u klienta leží).
static func coop(at: Node, p: Node) -> void:
	var m: Node = at.m()
	var W: Node = m.wreck
	var host := String(at.mode).ends_with("host")
	var res := ""
	if not host:
		var ci := -1
		var tf := -1
		for i in W.count():
			if W.kind[i] == "car" and ci < 0: ci = i
			if W.kind[i] == "tree" and tf < 0: tf = i
		if ci >= 0:
			var cp: Vector3 = W.base[ci] + Vector3(0, 0.8, 0)
			_stand(p, cp, 9.0, W.nodes[ci])
			for k in 40:
				await _fire(at, p, "rifle", cp, 1, 0.15)
				if W.state[ci] >= W.BURN: break
		if tf >= 0:
			var fp: Vector3 = W.base[tf] + Vector3(0, 0.6, 0)
			var tree: Node3D = W.nodes[tf]
			_stand(p, fp, 10.0, tree)
			for k in 12:
				await _fire(at, p, "autocannon", fp, 1, 0.35)
				if W.state[tf] == W.DOWN: break
			await at.get_tree().create_timer(2.6).timeout
			res = " lying %s" % str(is_instance_valid(tree) and absf(tree.global_transform.basis.y.normalized().dot(Vector3.UP)) < 0.35)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < (28000 if host else 18000):
		await at.get_tree().create_timer(0.5).timeout
	var sig := ""
	var cnt := [0, 0, 0, 0, 0]
	for i in W.count():
		sig += str(W.state[i])
		cnt[W.state[i]] += 1
	at.out("RESULT wreckcoop %s states %s hash %d%s" % [at.mode, str(cnt), sig.hash(), res])
	if host:
		await at.get_tree().create_timer(2.0).timeout
	at.get_tree().quit()

static func run(at: Node, p: Node) -> void:
	if p == null: return
	at._skip_brief()
	if at.step > 0 or not at.m().started(): return
	if String(at.mode) != "wrecktest":
		if at.m().players().size() < 2: return
		at.step = 1
		p.hp = 1.0e6
		for a in at.m().aliens():
			a.global_position += Vector3(0, -300, 0)
			a.set_physics_process(false)
		await at.get_tree().create_timer(1.0).timeout
		await coop(at, p)
		return
	at.step = 1
	var m: Node = at.m()
	p.hp = 1.0e6
	for a in m.aliens():
		a.global_position += Vector3(0, -300, 0)      # (ať nikdo neruší)
		a.set_physics_process(false)
	await at.get_tree().create_timer(0.5).timeout
	if Game.cmd_arg("stress", "") == "1":
		p.global_position += Vector3(0, 0, 0)
		await stress(at, p)
		return
	var W: Node = m.wreck
	var trees := []
	var cars := []
	for i in W.count():
		if W.kind[i] == "tree": trees.append(i)
		else: cars.append(i)
	var res := {"car_smoke": false, "car_burn": false, "car_boom": false, "wreck": false, "chain": -1.0,
		"tree_burn": false, "tree_fall": false, "lying": false, "stump": false, "blast_fall": false}
	var t0 := Time.get_ticks_msec()
	# 1) auto
	if cars.size() >= 1:
		var ci: int = cars[0]
		var car: Node3D = W.nodes[ci]
		var cp: Vector3 = W.base[ci]
		# druhé auto vedle (3,5 m): řetěz
		var cj := -1
		if cars.size() >= 2:
			cj = cars[1]
			var car2: Node3D = W.nodes[cj]
			car2.global_position = cp + car.global_transform.basis.x * 3.6
			W.moved(cj)
		_stand(p, cp + Vector3(0, 0.8, 0), 9.0, car)
		var hp2: float = W.hp[cj] if cj >= 0 else 0.0
		for k in 40:
			await _fire(at, p, "rifle", cp + Vector3(0, 0.8, 0), 1, 0.15)
			if W.state[ci] == W.SMOKE: res["car_smoke"] = true
			if W.state[ci] >= W.BURN: break
		res["car_smoke"] = res["car_smoke"] or W.state[ci] >= W.BURN
		res["car_burn"] = W.state[ci] == W.BURN
		at.out("[WRECK] auto po %d ms: stav %d hp %.0f, ohňů %d" % [Time.get_ticks_msec() - t0, W.state[ci], W.hp[ci], m.fires.size()])
		p.global_position = cp + Vector3(0, 0, 25)      # (od výbuchu)
		var t1 := Time.get_ticks_msec()
		while W.state[ci] != W.GONE and Time.get_ticks_msec() - t1 < 17000:
			await at.get_tree().create_timer(0.25).timeout
		res["car_boom"] = W.state[ci] == W.GONE
		await at.get_tree().create_timer(0.3).timeout
		res["wreck"] = not m.find_children("*", "Node3D", true, false).filter(func(n): return String(n.get_meta("model", "")) == "v_car_burnt").is_empty()
		if cj >= 0:
			res["chain"] = hp2 - float(W.hp[cj])
		at.out("[WRECK] výbuch za %.1f s, druhé auto -%.0f hp (stav %d)" % [(Time.get_ticks_msec() - t1) / 1000.0, float(res["chain"]), W.state[cj] if cj >= 0 else -1])
	# 2) strom hoří od laseru
	var ti := -1
	var tf := -1
	var tb := -1
	for i in trees:
		if W.state[i] != W.OK: continue
		if ti < 0: ti = i
		elif tf < 0 and W.base[i].distance_to(W.base[ti]) > 12.0: tf = i
		elif tb < 0 and tf >= 0 and W.base[i].distance_to(W.base[ti]) > 12.0 and W.base[i].distance_to(W.base[tf]) > 12.0: tb = i
	if ti >= 0:
		var tp: Vector3 = W.base[ti] + Vector3(0, 0.7, 0)
		_stand(p, tp, 8.0, W.nodes[ti])
		for k in 12:
			await _fire(at, p, "laser_rifle", tp, 1, 0.2)
			if W.state[ti] == W.BURN: break
		res["tree_burn"] = W.state[ti] == W.BURN
		at.out("[WRECK] strom (laser): stav %d žár %.0f, ohňů %d" % [W.state[ti], W.heat[ti], m.fires.size()])
	# 3) autokanón do kmene
	if tf >= 0:
		var fp: Vector3 = W.base[tf] + Vector3(0, 0.6, 0)
		var tree: Node3D = W.nodes[tf]
		_stand(p, fp, 10.0, tree)
		for k in 12:
			await _fire(at, p, "autocannon", fp, 1, 0.3)
			if W.state[tf] == W.DOWN: break
		res["tree_fall"] = W.state[tf] == W.DOWN
		await at.get_tree().create_timer(2.6).timeout
		if is_instance_valid(tree):
			res["lying"] = absf(tree.global_transform.basis.y.normalized().dot(Vector3.UP)) < 0.35
		for n in m.find_children("*", "Node3D", true, false):
			if String(n.get_meta("model", "")) == "v_stump" and (n as Node3D).global_position.distance_to(W.base[tf]) < 0.5:
				res["stump"] = true
		at.out("[WRECK] strom (kanón) %s: stav %d hp %.0f, leží %s, pařez %s" % [W.nodes[tf].get_meta("model", "") if is_instance_valid(W.nodes[tf]) else "-", W.state[tf], W.hp[tf], str(res["lying"]), str(res["stump"])])
	# 4) granát u kmene
	at.out("[WRECK] stromy %d / %d / %d" % [ti, tf, tb])
	if tb >= 0:
		m.explode(W.base[tb] + Vector3(0.6, 0.2, 0), 6.5, 100.0, String(p.name), false)
		await at.get_tree().create_timer(0.2).timeout
		res["blast_fall"] = W.state[tb] == W.DOWN
	await at.get_tree().create_timer(0.5).timeout
	var r := "RESULT wrecktest trees %d cars %d" % [trees.size(), cars.size()]
	for k in res:
		r += " %s %s" % [k, ("%.0f" % res[k]) if res[k] is float else str(res[k])]
	at.out(r)
	at.get_tree().quit()
