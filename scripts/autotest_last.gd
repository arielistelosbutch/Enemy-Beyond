extends RefCounted
## lasttest / lasthost + lastclient (2026-11-27, Ari: „zbývá poslední vetřelec, má tendence se
## někde schovat… je otrava ho hledat“). Všechny vetřelce kromě jednoho zabije, voják stojí u
## transportu (nesmrtelný) a čeká. Poslední vetřelec má po `--lastquiet` s zavolat loď a doběhnout
## k ní (u UFO, nebo na volné místo), loď ho paprskem vyzvedne a úkol je splněný. Zvíře (`--race=lihnoun`)
## místo toho vyrazí na vojáka. `--shoot=1`: voják vetřelce cestou zabije (nikdo neuteče).
## RESULT last <mode> mode <run|hunt> ship <n> escaped <n> done <bool> reach <bool> sky <bool> ...

static func run(at: Node, p: Node) -> void:
	if p == null: return
	at._skip_brief()
	var m: Node = at.m()
	var mode: String = at.mode
	var host := not mode.ends_with("client")
	if at.step > 0 or not m.started(): return
	if mode != "lasttest" and m.players().size() < 2: return
	at.step = 1
	m.hud.inventory_open = false
	for pl in m.players():
		pl.hp = 50000.0
	var race := Game.cmd_arg("race", "")
	var keep: Node = null
	await at.get_tree().create_timer(1.0).timeout
	if host:
		# the one that stays: of the wanted race (or the farthest from the team)
		var far := -1.0
		for a in m.aliens():
			if a.dead or a.race in ["mozek", "pylon"]:
				continue
			if race != "" and not String(a.race).begins_with(race):
				continue
			var d: float = a.global_position.distance_to(p.global_position)
			if d > far:
				far = d
				keep = a
		if keep == null:
			at.out("RESULT last %s no alien" % mode)
			at.get_tree().quit()
			return
		for a in m.aliens():
			if a != keep and not a.dead:
				m.hit_kind = "explosion"
				a.damage(99999.0, a.global_position + Vector3(0, 5, 0), null)
				m.hit_kind = ""
		# the last one goes to hide far from the team
		keep._go_lurk(true)
	var spot: Vector3 = p.global_position
	var t := 0.0
	var started_run := -1.0
	var reach := false
	var shot := false
	var at_ship := 1e9
	var sky := false
	var dmin := 1e9
	var limit := 150.0
	while t < limit:
		await at.get_tree().physics_frame
		t += at.get_physics_process_delta_time()
		for pl in m.players():
			pl.hp = 50000.0
		var st: Dictionary = m.get_meta("last_alien") if m.has_meta("last_alien") else {}
		var md := String(st.get("mode", ""))
		if host and is_instance_valid(keep):
			for a in m.aliens():
				if a != keep and not a.dead and not a.husk:      # (late ones: the terror supply ship)
					m.hit_kind = "explosion"
					a.damage(99999.0, a.global_position + Vector3(0, 5, 0), null)
					m.hit_kind = ""
		if host and is_instance_valid(keep) and not keep.dead:
			dmin = minf(dmin, keep.global_position.distance_to(p.global_position))
			if md == "hunt" and keep.global_position.distance_to(p.global_position) < 8.0:
				reach = true
			if Game.cmd_arg("lastdbg", "") == "1" and int(t * 10.0) % 20 == 0 and md != "":
				at.out("[LASTDBG] %s st %d ph %s pos %s goal %s esc %s spd %.1f seen %.1f act %d air %s vel %s fin %s ufo %s" % [md, keep.state, keep.phase, keep.global_position.snapped(Vector3.ONE * 0.1), keep.goal.snapped(Vector3.ONE * 0.1), keep.escape_to, keep._speed, keep.unseen_t, keep.activity, keep.get("airborne"), keep.velocity.snapped(Vector3.ONE * 0.1), keep.agent.is_navigation_finished(), m.map.get("ufo")])
			if md in ["run", "lift"]:
				if started_run < 0.0:
					started_run = t
					var spt: Vector3 = st["at"]
					sky = preload("res://scripts/alien_last.gd")._sky_open(m, spt)
					var ufo: Vector3 = m.map.get("ufo", Vector3.ZERO)
					at_ship = Vector2(spt.x - ufo.x, spt.z - ufo.z).length() if ufo != Vector3.ZERO else -1.0
				if Game.cmd_arg("shoot", "") == "1" and not shot and t - started_run > 8.0:
					shot = true
					m.hit_kind = "bullet"
					keep.damage(99999.0, p.global_position, p)
					m.hit_kind = ""
		if host and race != "" and reach:
			break
		if m.escaped > 0 and m.done_banner:
			break
		if host and shot and (not is_instance_valid(keep) or keep.dead) and t - started_run > 12.0 and m.done_banner:
			break
		if not host and m.escaped > 0:
			break
	await at.get_tree().create_timer(1.0).timeout
	var st2: Dictionary = m.get_meta("last_alien") if m.has_meta("last_alien") else {}
	var gone := m.get_node_or_null("LastPickup") == null
	at.out("RESULT last %s mode %s ship %d escaped %d done %s reach %s sky %s ship_d %.1f run_s %.1f alive %d dmin %.1f shipgone %s" % [mode,
		String(st2.get("mode", "-")), m.pickups_seen, m.escaped, m.done_banner, reach, sky, at_ship, t - started_run if started_run >= 0.0 else -1.0,
		m.alive_aliens(), dmin, gone])
	at.get_tree().quit()
