extends RefCounted
## (0.72, Ari: „větší panika civilistů“ a „noční vidění“)
## civpanic: teror ve městě, voják daleko. Vedle civilistů se objeví vetřelec – kolik jich uteče do
## domu a zamkne se; zaklepání na zamčené dveře (bez vetřelce poblíž odemkne); přemlouvání (držet F,
## čím víc strachu, tím déle); odmítnutí, když vetřelec stojí na dohled; Šedivák u zamčených dveří
## je musí chvíli vyrážet. Výsledek „RESULT civpanic …“.
## nvgtest: noc, noktovizor dole. Lampa před okem oslní, odvrácený pohled se vrátí; záblesk
## výstřelu; vlastní svítilna; slabá baterie bliká, vybitá zhasne a nejde zapnout.

static func _wait(at: Node, s: float) -> void:
	await at.get_tree().create_timer(s).timeout

static func _freeze(a: Node) -> void:
	a.set_physics_process(false)
	a.set_process(false)
	a.process_mode = Node.PROCESS_MODE_DISABLED

## spawn_alien gives nothing back: the newest one in Actors
static func _spawn(at: Node, m: Node, race: String, pos: Vector3) -> Node:
	var before: Array = m.aliens()
	m.spawn_alien(race, pos)
	await at.get_tree().physics_frame
	for a in m.aliens():
		if not a in before:
			return a
	return null

static func civpanic(at: Node, p: Node) -> void:
	if p == null: return
	at._skip_brief()
	if at.step > 0 or not at.m().started(): return
	at.step = 1
	var m: Node = at.m()
	m.hud.inventory_open = false
	p.hp = 5000.0
	p.max_hp = 5000.0
	for a in m.aliens():
		_freeze(a)
		a.global_position += Vector3(0, -300, 0)
	await _wait(at, 0.5)
	var civs: Array = m.civilians().filter(func(c): return not c.dead and not c.vip)
	if civs.is_empty():
		at.out("RESULT civpanic no civilians")
		at.get_tree().quit()
		return
	# the soldier far away from them
	var center := Vector3.ZERO
	for c in civs:
		center += c.global_position
	center /= civs.size()
	var far: Vector3 = p.global_position
	var fd := 0.0
	for wp in m.map.get("waypoints", []):
		var d: float = (wp as Vector3).distance_to(center)
		if d > fd:
			fd = d
			far = wp
	p.global_position = far + Vector3(0, 0.3, 0)
	# a frozen alien next to each little group: the danger they see
	var scare: Array = []
	for c in civs:
		var near := false
		for s in scare:
			if (s as Node).global_position.distance_to(c.global_position) < 14.0:
				near = true
		if near:
			continue
		var a: Node = await _spawn(at, m, "grey", m.free_spot(c.global_position + Vector3(6, 0.3, 0)))
		if a:
			_freeze(a)
			scare.append(a)
	await _wait(at, 22.0)
	var hidden := 0
	var fled := 0
	var follow := 0
	for c in civs:
		if c.dead: continue
		if c.hidden: hidden += 1
		elif c.terror > 0.5: fled += 1
	var locked := []
	for i in m.doors.size():
		if m.door_locked(i):
			locked.append(i)
	at.out("[CIV] civilians %d hidden %d fled %d locked doors %d" % [civs.size(), hidden, fled, locked.size()])
	if DisplayServer.get_name() != "headless" and hidden > 0:
		for c in civs:
			if c.hidden:
				p.global_position = c.global_position + Vector3(1.2, 0, 0)
				p.rotation.y = atan2(1.2, 0.0)
				break
		await _wait(at, 0.6)
		at._snap("civ_hidden")
	# the aliens go; a soldier knocks on a locked door
	for s in scare:
		if is_instance_valid(s):
			s.queue_free()
	await _wait(at, 0.5)
	var knock_ok := false
	var knock_t := -1.0
	if not locked.is_empty():
		var i: int = locked[0]
		var d: Dictionary = m.doors[i]
		var normal := Vector3(0, 0, 1).rotated(Vector3.UP, float(d["base"]))
		var outside: Vector3 = d["c"] + normal * 1.0
		var q := PhysicsRayQueryParameters3D.create(outside + Vector3(0, 0.5, 0), outside + Vector3(0, 9, 0), Game.WORLD)
		if not p.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			outside = d["c"] - normal * 1.0
		p.global_position = outside
		m.use_door(i, outside)
		var t0: float = m.t
		while m.t - t0 < 7.0:
			await at.get_tree().physics_frame
			if not m.door_locked(i):
				knock_ok = true
				knock_t = m.t - t0
				break
	at.out("[CIV] knock unlocked %s after %.1f s" % [knock_ok, knock_t])
	# talking one round: hold F by him
	var talk_ok := false
	var talk_t := -1.0
	var need := 0.0
	var tc: Node = null
	for c in civs:
		if not c.dead and c.cowering and c.st != 3:
			tc = c
			break
	if tc:
		tc.terror = 0.9
		await _wait(at, 0.3)
		need = tc.talk_time()
		p.global_position = tc.global_position + Vector3(1.4, 0, 0)
		if not tc.hidden:
			pass
		await at.get_tree().physics_frame
		var ss: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
		for k in 8:
			var o := Vector3(1.4, 0, 0).rotated(Vector3.UP, k * TAU / 8.0)
			var lq := PhysicsRayQueryParameters3D.create(tc.global_position + o + Vector3(0, 1.2, 0), tc.global_position + Vector3(0, 0.9, 0), Game.WORLD)
			if ss.intersect_ray(lq).is_empty():
				p.global_position = tc.global_position + o
				break
		await at.get_tree().physics_frame
		Input.action_press("use")
		var t0: float = m.t
		while m.t - t0 < 8.0:
			await at.get_tree().physics_frame
			if tc.st == 3:      # C.FOLLOW
				talk_ok = true
				talk_t = m.t - t0
				break
		Input.action_release("use")
	at.out("[CIV] talk need %.1f s done %s after %.1f s" % [need, talk_ok, talk_t])
	# no: an alien in his sight
	var refused := false
	var rc: Node = null
	for c in civs:
		if not c.dead and c != tc and not c.saved:
			rc = c
			break
	if rc:
		var a2: Node = await _spawn(at, m, "grey", m.free_spot(rc.global_position + Vector3(0, 0.3, 5)))
		if a2:
			_freeze(a2)
			var ss2: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
			var lq2 := PhysicsRayQueryParameters3D.create(rc.global_position + Vector3(0, 1.5, 0), a2.global_position + Vector3(0, 1.0, 0), Game.WORLD)
			var seen: bool = ss2.intersect_ray(lq2).is_empty() or rc.global_position.distance_to(a2.global_position) < 4.0
			refused = seen and not rc.calm_by(p)
			if not seen:
				refused = true      # (a wall between them: nothing to test there)
			a2.queue_free()
	at.out("[CIV] refused with an alien in sight %s" % refused)
	# a Šedivák at a locked door: it takes him a while
	var pry_t := -1.0
	var di := -1
	for i in m.doors.size():
		if not m.doors[i].has("slide") and is_instance_valid(m.doors[i]["body"]) and not m.door_locked(i):
			di = i
			break
	if di >= 0:
		if m.doors[di]["open"]:
			m._door_state.rpc(di, 0.0, false)
		await _wait(at, 0.6)
		m._door_lock.rpc(di, "Test")
		var normal2 := Vector3(0, 0, 1).rotated(Vector3.UP, float(m.doors[di]["base"]))
		var a3: Node = await _spawn(at, m, "grey", m.doors[di]["c"] + normal2 * 0.9 + Vector3(0, 0.3, 0))
		at.out("[CIV] pry door %d alien %s" % [di, a3 != null])
		if a3:
			_freeze(a3)
			var t0: float = m.t
			while m.t - t0 < 6.0:
				await at.get_tree().physics_frame
				if m.doors[di]["open"]:
					pry_t = m.t - t0
					break
	at.out("[CIV] alien broke a locked door after %.1f s" % pry_t)
	at.out("RESULT civpanic hidden %d locked %d knock %s talk %s refused %s pry %s" % [hidden, locked.size(), knock_ok, talk_ok and talk_t >= need - 0.2, refused, pry_t > 1.2])
	at.get_tree().quit()

static func nvgtest(at: Node, p: Node) -> void:
	if p == null: return
	at._skip_brief()
	if at.step > 0 or not at.m().started(): return
	at.step = 1
	var m: Node = at.m()
	m.hud.inventory_open = false
	p.hp = 5000.0
	p.max_hp = 5000.0
	for a in m.aliens():
		a.set_physics_process(false)
		a.global_position += Vector3(0, -300, 0)
	p.light_on = false
	p.inv["p5"] = {"id": "nvg"}
	await _wait(at, 0.4)
	m.set_nvg(true, false)
	await _wait(at, 1.5)
	var dark: float = m.nvg_wash
	if DisplayServer.get_name() != "headless": at._snap("nvg_dark")
	var lamp := OmniLight3D.new()
	lamp.light_energy = 2.2
	lamp.omni_range = 9.0
	m.add_child(lamp)
	lamp.global_position = p.cam.global_position - p.cam.global_transform.basis.z * 5.0
	await _wait(at, 2.6)      # (the lights are looked up every 2 s)
	var blind: float = m.nvg_wash
	if DisplayServer.get_name() != "headless": at._snap("nvg_lamp")
	p.rotation.y += PI
	await _wait(at, 0.3)
	var soon: float = m.nvg_wash
	await _wait(at, 2.5)
	var away: float = m.nvg_wash
	lamp.queue_free()
	await _wait(at, 0.3)
	m.nvg_flash(p.cam.global_position - p.cam.global_transform.basis.z * 3.0, 0.35)
	var shot := 0.0
	for k in 24:
		await at.get_tree().physics_frame
		shot = maxf(shot, m.nvg_wash)
	await _wait(at, 1.5)
	p.light_on = true
	await _wait(at, 0.5)
	var torch: float = m.nvg_wash
	p.light_on = false
	await _wait(at, 2.0)
	# the battery
	var slot := ""
	for s in p.inv:
		if p.item_in(s).get("id", "") == "nvg":
			slot = s
	p.inv[slot]["batt"] = 30.0
	var fl := 1.0
	for k in 40:
		await at.get_tree().physics_frame
		fl = minf(fl, m.nvg_flick)
	p.inv[slot]["batt"] = 1.0
	await _wait(at, 1.5)
	var died: bool = not m.nvg_on
	Input.action_press("nvg")
	await at.get_tree().physics_frame
	await at.get_tree().physics_frame
	Input.action_release("nvg")
	await at.get_tree().physics_frame
	var stays_off: bool = not m.nvg_on
	at.out("[NVG] dark %.2f lamp %.2f turned %.2f -> %.2f shot %.2f torch %.2f low flick %.2f" % [dark, blind, soon, away, shot, torch, fl])
	at.out("RESULT nvgtest blind %s recover %s shot %s torch %s low %s dead %s off %s" % [blind > 0.45 and blind > dark + 0.3, soon > away and away < 0.2, shot > 0.15, torch > 0.25, fl < 0.9, died, stays_off])
	at.get_tree().quit()

## civstuck (Ari: „občas se nám vesničan zasekl ve zdi“): many people on the map, aliens around them
## now and then, a minute of wandering, running, hiding. Every 0.25 s each one is checked: his body
## inside a wall/thing (World), or walking hard for 4 s and getting nowhere. --old=1: the spawn as before.
static func civstuck(at: Node, p: Node) -> void:
	if p == null: return
	at._skip_brief()
	if at.step > 0 or not at.m().started(): return
	at.step = 1
	var m: Node = at.m()
	m.hud.inventory_open = false
	p.hp = 5000.0
	p.max_hp = 5000.0
	for a in m.aliens():
		_freeze(a)
		a.global_position += Vector3(0, -300, 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var n := int(Game.cmd_arg("civs", "24"))
	var spawn_bad := 0
	for i in n:
		var sp: Vector3 = m.civ_spawn_point(rng) if Game.cmd_arg("old", "") != "1" else m._far_point(rng, 12.0)
		m.spawner.spawn({"kind": "civ", "id": 100 + i, "pos": sp})
	await _wait(at, 1.0)      # (the physics of the map is up after a moment: then they are checked)
	var civs: Array = m.civilians().filter(func(c): return not c.vip)
	var ss: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = 0.18
	cap.height = 1.1
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.collision_mask = Game.WORLD
	var inwall := {}
	var stuck := {}
	var trail := {}
	var wall_run := {}
	var stuck_run := {}
	var wall_max := 0
	var stuck_max := 0
	for c in civs:
		q.transform = Transform3D(Basis(), c.global_position + Vector3(0, 0.95, 0))
		if not ss.intersect_shape(q, 1).is_empty():
			spawn_bad += 1
	var scare: Array = []
	var dur := float(Game.cmd_arg("dur", "60"))
	var t0: float = m.t
	var next_scare := 0.0
	var where := ""
	while m.t - t0 < dur:
		await _wait(at, 0.25)
		var el: float = m.t - t0
		if el >= next_scare:
			# a few aliens show up by random people, then go
			next_scare = el + 12.0
			for s in scare:
				if is_instance_valid(s):
					s.queue_free()
			scare.clear()
			for k in 3:
				var c: Node = civs[rng.randi() % civs.size()]
				if not is_instance_valid(c) or c.dead:
					continue
				var a: Node = await _spawn(at, m, "grey", m.free_spot(c.global_position + Vector3(rng.randf_range(-7, 7), 0.3, rng.randf_range(-7, 7))))
				if a:
					_freeze(a)
					scare.append(a)
		for c in civs:
			if not is_instance_valid(c) or c.dead or c.saved:
				continue
			q.transform = Transform3D(Basis(), c.global_position + Vector3(0, 0.95, 0))
			var hit: Array = ss.intersect_shape(q, 1)
			wall_run[c] = int(wall_run.get(c, 0)) + 1 if not hit.is_empty() else 0
			wall_max = maxi(wall_max, int(wall_run[c]))
			if not hit.is_empty():
				if not inwall.has(c):
					where += " %s@%s(%s)" % [c.name, c.global_position.snapped(Vector3.ONE * 0.1), hit[0]["collider"].name]
				inwall[c] = int(inwall.get(c, 0)) + 1
			var tr: Array = trail.get(c, [])
			var v: Vector3 = c.velocity
			v.y = 0
			tr.append([c.global_position, v.length() > 0.5 and not c.hidden and not c.cowering])
			if tr.size() > 16:
				tr.pop_front()
			trail[c] = tr
			if tr.size() == 16:
				var all_push := true
				for e in tr:
					all_push = all_push and e[1]
				var now_stuck: bool = all_push and (tr[0][0] as Vector3).distance_to(c.global_position) < 0.3
				stuck_run[c] = int(stuck_run.get(c, 0)) + 1 if now_stuck else 0
				stuck_max = maxi(stuck_max, int(stuck_run[c]))
				if int(stuck_run[c]) == 30:
					var bq := PhysicsShapeQueryParameters3D.new()
					var bcap := CapsuleShape3D.new()
					bcap.radius = 0.45
					bcap.height = 1.8
					bq.shape = bcap
					bq.collision_mask = 0xFFFF
					bq.exclude = [c.get_rid()]
					bq.transform = Transform3D(Basis(), c.global_position + Vector3(0, 0.9, 0))
					var near_names := []
					for h in ss.intersect_shape(bq, 6):
						var col: Node = h["collider"]
						var kids := []
						for k in col.get_parent().get_children():
							kids.append(String(k.name))
						near_names.append("%s/%s@%s meta %s layer %d kind %s shapes %s" % [col.name, col.get_parent().name, (col as Node3D).global_position.snapped(Vector3.ONE * 0.1), col.get_meta_list(), col.collision_layer, col.get_meta("break_kind", ""), col.find_children("*", "CollisionShape3D", false, false).map(func(cs): return [cs.shape.get_class(), cs.shape.size if cs.shape is BoxShape3D else 0, cs.global_basis.get_euler().snapped(Vector3.ONE * 0.1)])])
					var sl := []
					for k in c.get_slide_collision_count():
						var kc: KinematicCollision3D = c.get_slide_collision(k)
						sl.append("%s n%s" % [(kc.get_collider() as Node).name if kc.get_collider() else "?", kc.get_normal().snapped(Vector3.ONE * 0.1)])
					at.out("[CIV] slides %s real %s" % [sl, c.get_real_velocity().snapped(Vector3.ONE * 0.1)])
					at.out("[CIV] long stuck %s at %s st %d goal %s vel %s floor %s near %s" % [c.name, c.global_position.snapped(Vector3.ONE * 0.05), c.st, c.goal.snapped(Vector3.ONE * 0.1), c.velocity.snapped(Vector3.ONE * 0.1), c.is_on_floor(), near_names])
				if now_stuck:
					if not stuck.has(c):
						var vd: Vector3 = Vector3(c.velocity.x, 0, c.velocity.z).normalized()
						var fcap := CapsuleShape3D.new()
						fcap.radius = 0.28
						fcap.height = 1.7
						var fq := PhysicsShapeQueryParameters3D.new()
						fq.shape = fcap
						fq.collision_mask = 1 | 64 | 128
						fq.exclude = [c.get_rid()]
						fq.transform = Transform3D(Basis(), c.global_position + Vector3(0, 0.87, 0) + vd * 0.12)
						var fr: Array = ss.intersect_shape(fq, 4)
						var fh: Dictionary = fr[0] if not fr.is_empty() else {}
						where += " stuck %s@%s st %d goal %.1f front %s door %d" % [c.name, c.global_position.snapped(Vector3.ONE * 0.1), c.st, c.global_position.distance_to(c.goal),
							(String(fh["collider"].name) + "/" + String(fh["collider"].get_parent().name)) if not fh.is_empty() else "-", m.door_near(c.global_position, 1.5)]
					stuck[c] = int(stuck.get(c, 0)) + 1
	at.out("[CIV] stuck where:%s" % where)
	# longest time one of them stayed in a wall / stuck walking (a stuck spell counts from 4 s on)
	at.out("RESULT civstuck civs %d spawn_in_wall %d in_wall %d stuck %d longest_wall %.1f s longest_stuck %.1f s" % [civs.size(), spawn_bad, inwall.size(), stuck.size(), wall_max * 0.25, (stuck_max + 15) * 0.25 if stuck_max > 0 else 0.0])
	at.get_tree().quit()

## civlooks: the civilian types (civ_look.gd) lined up on a stage above the map, standing as the
## people of the base stand (tp_npc_idle): user://civ_typy_<town|village>_<front|back>.png
static func civlooks(at: Node, p: Node) -> void:
	if p == null: return
	at._skip_brief()
	if at.step > 0 or not at.m().started(): return
	at.step = 1
	var m: Node = at.m()
	m.hud.inventory_open = false
	p.set_physics_process(false)
	for a in m.aliens():
		_freeze(a)
	var CL := preload("res://scripts/civ_look.gd")
	var hidden_ui: Array = []
	for cl in at.get_tree().root.find_children("*", "CanvasLayer", true, false):
		if cl.visible:
			cl.visible = false
			hidden_ui.append(cl)
	var stage := Node3D.new()
	m.add_child(stage)
	stage.global_position = p.global_position + Vector3(0, 80, 0)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	floor_mi.mesh = pm
	floor_mi.material_override = Game.color_mat(Color(0.3, 0.3, 0.3))
	stage.add_child(floor_mi)
	var cam := Camera3D.new()
	cam.fov = 34
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.52, 0.55)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.58)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	cam.environment = env
	stage.add_child(cam)
	var lamp := DirectionalLight3D.new()
	stage.add_child(lamp)
	lamp.look_at_from_position(stage.global_position, stage.global_position + Vector3(0.5, -0.8, -0.6), Vector3.UP)
	lamp.light_energy = 1.3
	var fill := OmniLight3D.new()
	fill.omni_range = 20.0
	fill.light_energy = 0.7
	stage.add_child(fill)
	fill.position = Vector3(0, 3, 6)
	var clip := AnimClips.get_clip("tp_npc_idle")
	var variants := int(Game.cmd_arg("variants", "2"))
	for place in ["town", "village"]:
		var row := Node3D.new()
		stage.add_child(row)
		var types: Array = CL.TYPES[place]
		var n := types.size() * variants
		var k := 0
		var names := []
		for v in variants:
			for t in types:
				var r := RandomNumberGenerator.new()
				r.seed = 1000 + k * 31 + (0 if place == "town" else 500)
				var d: Dictionary = CL.make_type(t, r)
				var mm: Node3D = Game.model("merc")
				mm.scale = Vector3(-1, 1, 1)
				row.add_child(mm)
				CL.dress(mm, d)
				var ap: Node = mm.find_child("AnimationPlayer", true, false)
				if ap:
					ap.get_parent().remove_child(ap)
					ap.free()
				var sk: Skeleton3D = mm.find_child("Skeleton3D", true, false)
				if sk and not clip.is_empty():
					var pose := AnimClips.pose(clip, AnimClips.clip_time(clip, 0.4 + k * 0.37))
					for bn in pose:
						var bi := sk.find_bone(bn)
						if bi >= 0:
							sk.set_bone_pose_rotation(bi, sk.get_bone_rest(bi).basis.get_rotation_quaternion() * Quaternion.from_euler(pose[bn]))
				mm.position = Vector3((k - (n - 1) / 2.0) * 0.82, 0, 0)
				names.append(d["name"])
				k += 1
		at.out("[CIVLOOK] %s: %s" % [place, ", ".join(names)])
		for side in ["front", "back"]:
			row.rotation.y = PI if side == "front" else 0.0
			var sp := stage.global_position
			cam.look_at_from_position(sp + Vector3(0, 1.4, n * 0.8 + 0.6), sp + Vector3(0, 0.9, 0), Vector3.UP)
			cam.current = true
			for f in 8: await at.get_tree().process_frame
			at.get_viewport().get_texture().get_image().save_png("user://civ_typy_%s_%s.png" % [place, side])
		# close-ups: the faces of the first row
		row.rotation.y = PI
		for half in 2:
			var c := Vector3.ZERO
			for i in types.size():
				c += (row.get_child(half * types.size() + i) as Node3D).global_position / types.size()
			cam.look_at_from_position(c + Vector3(0, 1.45, 4.3), c + Vector3(0, 1.15, 0), Vector3.UP)
			cam.current = true
			for f in 6: await at.get_tree().process_frame
			at.get_viewport().get_texture().get_image().save_png("user://civ_typy_%s_detail_%d.png" % [place, half])
		row.queue_free()
	# the Líhavec's meal (alien._lay_corpse): one of them lying dead
	var dm: Node3D = Game.model("merc")
	dm.scale = Vector3(-1, 1, 1)
	stage.add_child(dm)
	CL.dress(dm, CL.make("village", 3))
	CL.lie_dead(dm, 2)
	var so := stage.global_position
	cam.look_at_from_position(so + Vector3(1.8, 1.6, 2.4), so + Vector3(0, 0.2, 0), Vector3.UP)
	cam.current = true
	for f in 6: await at.get_tree().process_frame
	at.get_viewport().get_texture().get_image().save_png("user://civ_typy_mrtvy.png")
	for cl in hidden_ui:
		if is_instance_valid(cl):
			cl.visible = true
	at.out("RESULT civlooks ok")
	at.get_tree().quit()
