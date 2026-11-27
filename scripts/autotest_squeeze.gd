extends RefCounted
## squeeze (2026-11-27, Tomík: „Bijci, Ještěřani a Líhavci se v úzkých prostorech zasekávají a půlku
## boje hledají cestu“; Ari: všichni velcí tvorové, i Kolos a Mysloděj): a creature of each race is set
## down 12-28 m (by the paths) from a spot inside a house / a room of the base / the inside of the UFO
## and has to get there - through doors, corridors, past furniture.
##   --mode=walk  it just walks there (the merc is a ghost): the bare locomotion and its "stuck" escape
##   --mode=hunt  the merc stands there and it knows it: the real fight logic (melee repaths, advances)
## Every 0.25 s: where it is; "stuck" = it pushes (velocity > 0.5 m/s) but over the last second moved
## less than 0.35 m. Prints per race: reached N/K, mean time, stuck seconds, the worst run.
##   --races=bijec,jestetan,...  --tries=4  --limit=40  --old=1 (A/B: the movement as before)

static func _wait(at: Node, s: float) -> void:
	await at.get_tree().create_timer(s).timeout

static func _targets(m: Node) -> Array:
	var out: Array = []
	var mp: Dictionary = m.map
	for v in mp.get("vip_spots", []):
		out.append(v)
	for t in mp.get("terminals", []):
		var tp: Vector3 = t["pos"] if t is Dictionary and t.has("pos") else (t as Node3D).global_position if t is Node3D else (t if t is Vector3 else Vector3.INF)
		if tp != Vector3.INF:
			out.append(tp)
	var u = mp.get("ufo", null)
	if u is Vector3 and String(Net.mission_params.get("type", "")) in ["crash", "landed"]:
		out.append(u)
	elif u is Node3D:
		out.append((u as Node3D).global_position)
	return out

static func _plen(path: PackedVector3Array) -> float:
	var L := 0.0
	for k in range(1, path.size()):
		L += path[k].distance_to(path[k - 1])
	return L

static func run(at: Node, p: Node) -> void:
	if p == null: return
	at._skip_brief()
	if at.step > 0 or not at.m().started(): return
	at.step = 1
	var m: Node = at.m()
	m.hud.inventory_open = false
	p.hp = 99999.0
	p.max_hp = 99999.0
	await _wait(at, 1.0)
	for a in m.aliens():
		a.queue_free()
	for c in m.civilians():
		c.queue_free()
	await _wait(at, 0.3)
	var mode := Game.cmd_arg("mode", "walk")
	var races: PackedStringArray = Game.cmd_arg("races", "bijec,jestetan,lihnoun,ohar,kolos,ohnivec,myslodej,nador,diskoll,grey").split(",")
	var tries := int(Game.cmd_arg("tries", "4"))
	var limit := float(Game.cmd_arg("limit", "40"))
	var nm: RID = p.get_world_3d().navigation_map
	var targets: Array = _targets(m)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Game.cmd_arg("seed", "3")) * 31 + 7
	# targets the paths really reach (snapped), each with a start 12-28 m of path away
	var runs: Array = []
	for i in range(targets.size() - 1, 0, -1):      # (the same order every time: old and new code get the same runs)
		var j := rng.randi() % (i + 1)
		var tmp = targets[i]
		targets[i] = targets[j]
		targets[j] = tmp
	for tg in targets:
		var t: Vector3 = NavigationServer3D.map_get_closest_point(nm, tg)
		if t.distance_to(tg) > 1.2:
			continue
		for k in 40:
			var ang := rng.randf() * TAU
			var r := rng.randf_range(10.0, 20.0)
			var s: Vector3 = NavigationServer3D.map_get_closest_point(nm, t + Vector3(cos(ang) * r, 0, sin(ang) * r))
			var path := NavigationServer3D.map_get_path(nm, s, t, true)
			if path.size() < 2 or path[path.size() - 1].distance_to(t) > 0.8:
				continue
			var L := _plen(path)
			if L < 12.0 or L > 28.0:
				continue
			runs.append([s, t, L])
			at.out("[SQZ] run %d from %s to %s path %.1f m (%d pts, end %s)" % [runs.size() - 1, s.snapped(Vector3.ONE * 0.1), t.snapped(Vector3.ONE * 0.1), L, path.size(), path[path.size() - 1].snapped(Vector3.ONE * 0.1)])
			break
		if runs.size() >= tries:
			break
	at.out("[SQZ] mode %s targets %d runs %d" % [mode, targets.size(), runs.size()])
	if mode == "walk":
		p.set_meta("ghost", true)
	var total_stuck := 0.0
	var total_fail := 0
	var summary := ""
	var worst_race := ""
	var worst := 0.0
	var ms_think := 0.0
	var frames := 0
	var fps_min := 9999.0
	var fps_sum := 0.0
	var fps_n := 0
	var phys_max := 0.0
	for race in races:
		var reached := 0
		var t_sum := 0.0
		var stuck_s := 0.0
		var r_worst := 0.0
		var where := ""
		for run_i in runs.size():
			var rr: Array = runs[run_i]
			var s: Vector3 = rr[0]
			var t: Vector3 = rr[1]
			if mode == "hunt":
				p.global_position = t + Vector3(0, 0.1, 0)
				p.velocity = Vector3.ZERO
			var before: Array = m.aliens()
			m.spawn_alien(race, s + Vector3(0, 0.15, 0))
			await at.get_tree().physics_frame
			var a: Node = null
			for x in m.aliens():
				if not x in before:
					a = x
			if a == null:
				at.out("[SQZ] %s spawn failed" % race)
				continue
			await at.get_tree().physics_frame
			await at.get_tree().physics_frame
			a.react = -1.0
			if mode == "walk":
				a.state = a.S.LURK
				a.alert = false
				a.wait = 9999.0
				a.activity = 0
				a._go(t)
			else:
				a.alert = true
				a._know(p, 999.0)
				a.last_seen = t
				if a.has_method("_hunt"):
					a.prey = p
					a.state = a.S.COMBAT
				else:
					a.stalk(p)
			var trail: Array = []
			var el := 0.0
			var done := false
			var my_stuck := 0.0
			var t_start := Time.get_ticks_usec()
			var f0 := Engine.get_physics_frames()
			while el < limit:
				await _wait(at, 0.25)
				el += 0.25
				if not is_instance_valid(a) or a.dead:
					break
				var ap: Vector3 = a.global_position
				var flat := Vector2(ap.x - t.x, ap.z - t.z).length()
				if mode == "walk":
					if mode == "walk" and a.state != a.S.LURK:
						a.state = a.S.LURK
					if flat < 1.6 and absf(ap.y - t.y) < 1.5:
						done = true
					elif a._arrived() and flat >= 1.6:
						a._go(t)          # (gave up / walked aside: send it again - the test wants it there)
				else:
					var reach := 2.6 if a.R.has("melee") else 7.0
					if flat < reach and absf(ap.y - t.y) < 1.5 and (a.R.has("melee") or a._los(p.global_position + Vector3(0, 1.4, 0))):
						done = true
				if Game.cmd_arg("sqzdbg", "") == str(run_i) and int(el * 4) % 2 == 0:
					var sl := []
					for k in a.get_slide_collision_count():
						var kc: KinematicCollision3D = a.get_slide_collision(k)
						var cn: Node = kc.get_collider() as Node
						var info := "?"
						if cn:
							var shp := []
							for cs in cn.find_children("*", "CollisionShape3D", false, false):
								shp.append("%s%s@%s" % [cs.shape.get_class(), (cs.shape as BoxShape3D).size.snapped(Vector3.ONE * 0.01) if cs.shape is BoxShape3D else "", (cs as Node3D).global_position.snapped(Vector3.ONE * 0.01)])
							info = "%s/%s L%d %s" % [cn.name, cn.get_parent().name, (cn as CollisionObject3D).collision_layer, shp.slice(0, 3)]
						sl.append("%s n%s at %s" % [info, kc.get_normal().snapped(Vector3.ONE * 0.1), kc.get_position().snapped(Vector3.ONE * 0.01)])
					at.out("[SQZDBG] %s %.1f pos %s vel %s real %s goal %s next %s fin %s st %d flr %s sqz %s push %.2f det %s %s" % [race, el, ap.snapped(Vector3.ONE * 0.05),
						a.velocity.snapped(Vector3.ONE * 0.1), a.get_real_velocity().snapped(Vector3.ONE * 0.1), a.goal.snapped(Vector3.ONE * 0.1),
						a.agent.get_next_path_position().snapped(Vector3.ONE * 0.1), a.agent.is_navigation_finished(), a.state, a.is_on_floor(),
						a.get("squeezed"), float(a.get("_push_t")), a.get("_resume_goal") != Vector3.INF, sl])
				fps_min = minf(fps_min, Engine.get_frames_per_second())
				fps_sum += Engine.get_frames_per_second()
				fps_n += 1
				phys_max = maxf(phys_max, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
				trail.append(ap)
				if trail.size() > 4:
					trail.pop_front()
				var hv := Vector2(a.velocity.x, a.velocity.z).length()
				if trail.size() == 4 and hv > 0.5 and (trail[0] as Vector3).distance_to(ap) < 0.35:
					my_stuck += 0.25
				if done:
					break
			frames += Engine.get_physics_frames() - f0
			ms_think += float(Time.get_ticks_usec() - t_start) / 1000.0
			if done:
				reached += 1
				t_sum += el
			else:
				total_fail += 1
				where += " miss#%d@%s(left %.1f m dy %.1f sqz %d det %d)" % [run_i, a.global_position.snapped(Vector3.ONE * 0.1) if is_instance_valid(a) else Vector3.ZERO,
					Vector2(a.global_position.x - t.x, a.global_position.z - t.z).length() if is_instance_valid(a) else -1.0,
					a.global_position.y - t.y if is_instance_valid(a) else 0.0, int(a.get("_sqz_n")) if a.get("_sqz_n") != null else -1, int(a.get("_detour_n")) if a.get("_detour_n") != null else -1]
			stuck_s += my_stuck
			r_worst = maxf(r_worst, el if not done else my_stuck)
			if is_instance_valid(a):
				a.queue_free()
			await at.get_tree().physics_frame
		total_stuck += stuck_s
		var line := "%s %d/%d t %.1f s stuck %.1f s" % [race, reached, runs.size(), t_sum / maxf(1.0, float(reached)), stuck_s]
		at.out("[SQZ] %s%s" % [line, where])
		summary += " | " + line
		if stuck_s > worst:
			worst = stuck_s
			worst_race = race
	at.out("[SQZ] fps avg %.0f min %.0f physics max %.1f ms" % [fps_sum / maxf(1.0, fps_n), fps_min, phys_max])
	at.out("RESULT squeeze mode %s fail %d stuck %.1f worst %s%s" % [mode, total_fail, total_stuck, worst_race, summary])
	at.get_tree().quit()
