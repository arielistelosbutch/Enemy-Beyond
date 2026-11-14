extends RefCounted
## 0.66 Facelift I tests (called from autotest.gd): the solo drone radar, the transporter after
## a mission, the loading screens' pictures, the people at the base.

static func radar(at: Node, p: Node) -> void:
	if p == null or at.step > 0:
		return
	at._skip_brief()
	if not at.m().go:
		return
	at.step = 1
	var ids := []
	for s in p.inv:
		ids.append(String(p.inv[s]["id"]))
	at.out("RESULT radar solo %s scanner %s kit_scanner %s kit_radio %s" % [at.m().solo(), p.has_scanner(), "scanner" in ids, "radio" in ids])
	await at.get_tree().create_timer(1.0).timeout
	shot(at, "radar")
	# the loading screen over it, for a look (it stays until freed here: scene_ready is never called)
	var ld: CanvasLayer = Game.LoadingScreen.new()
	ld.setup("Příprava mise", true)
	Game.add_child(ld)
	await at.get_tree().create_timer(1.0).timeout
	shot(at, "loading_1")
	ld._slide_t = ld.SLIDE + ld.XFADE * 0.5
	await at.get_tree().create_timer(0.05).timeout
	shot(at, "loading_2")
	at.out("RESULT loading pictures %d" % ld._tex.size())
	ld.queue_free()
	at.get_tree().quit()

## A screenshot when there is a screen (xvfb); nothing under --headless.
static func shot(at: Node, name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var img: Image = at.get_viewport().get_texture().get_image()
	if img != null:
		img.save_png("user://%s.png" % name)

## --autotest=loadshots [--race=grey] [--tag=farm]: pictures for the loading screens - the team (the player
## and two mates in different looks) in a firefight with a few aliens, from a film camera, no HUD.
## Saves user://load_<tag>_<n>.png (1280x720 under xvfb); the good ones go to assets/ui/loading/.
static func loadshots(at: Node, p: Node) -> void:
	at._skip_brief()
	if p == null or at.step > 0 or not at.m().started():
		return
	at.step = 1
	var m: Node = at.m()
	p.hp = 99999.0
	await at.get_tree().create_timer(1.2).timeout
	at._skip_brief()
	m.hud.inventory_open = false
	m.hud.visible = false
	var tag := Game.cmd_arg("tag", "x")
	var race := Game.cmd_arg("race", "grey")
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Game.cmd_arg("seed", "1")) * 97 + 3
	var ss: PhysicsDirectSpaceState3D = m.get_world_3d().direct_space_state
	# a place with open ground ahead and to both sides (rays at chest height and at 3 m, for the trees)
	var size: float = m.map["size"]
	var base: Vector3 = m.map["evac"]
	var fwd := Vector3(0, 0, -1)
	var best := -1.0
	for t in 70:
		var c: Vector3 = m.free_spot(Vector3(rng.randf_range(0.15, 0.85) * size, 0.3, rng.randf_range(0.15, 0.85) * size))
		for i in 8:
			var ang := TAU * i / 8.0 + rng.randf() * 0.4
			var d := Vector3(sin(ang), 0, cos(ang))
			var r := d.cross(Vector3.UP)
			var score := 0.0
			for probe in [[d, 18.0], [d * 0.7 + r * 0.7, 12.0], [d * 0.7 - r * 0.7, 12.0], [r, 9.0], [-r, 9.0], [-d * 0.7 + r * 0.7, 9.0], [-d * 0.7 - r * 0.7, 9.0]]:
				for hgt in [1.2, 3.0]:
					var from: Vector3 = c + Vector3(0, hgt, 0)
					var to: Vector3 = from + (probe[0] as Vector3).normalized() * float(probe[1])
					var h := ss.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, Game.WORLD))
					score += 1.0 if h.is_empty() else from.distance_to(h.position) / float(probe[1])
			score += rng.randf() * 0.5
			for cw in m.map.get("cows", []):
				if (cw as Vector3).distance_to(c + d * 8.0) < 14.0:
					score -= 3.0      # (cows walk into the picture)
			if score > best:
				best = score
				base = c
				fwd = d
	# (0.66, Ari: no first-person hands, nobody standing stiff) - the player himself is out of the picture,
	# the team is three mates in different looks, every one aiming and shooting
	p.global_position = base + Vector3(0, -60, 0)
	p.rotation.y = atan2(-fwd.x, -fwd.z)
	p.visible = false
	p.set_physics_process(false)
	var right := fwd.cross(Vector3.UP).normalized()
	var mates := []
	var looks := [{"top": 2, "vest": 1, "headgear": 3}, {"top": 1, "vest": 2, "headgear": 4, "paint": 1}, {"top": 0, "vest": 0, "headgear": 6}]
	for k in 3:
		var mm: Dictionary = m.roster()[p.get_multiplayer_authority()]["merc"].duplicate(true)
		var lk: Dictionary = mm.get("look", {}).duplicate()
		lk.merge(looks[(k + rng.randi()) % looks.size()], true)
		lk["female"] = rng.randf() < 0.35
		mm["look"] = lk
		var off: Vector3 = [Vector3.ZERO, right * 2.2 - fwd * 0.8, -right * 2.0 - fwd * 2.2][k]
		var pos: Vector3 = m.free_spot(base + off + Vector3(0, 0.3, 0))
		var data := {"kind": "player", "peer": 7 + k, "pos": pos, "yaw": atan2(-fwd.x, -fwd.z), "merc": mm, "name": "Kamarád %d" % k}
		var mate: Node = m._spawn(data)
		m.actors.add_child(mate)
		mates.append(mate)
	await at.get_tree().physics_frame
	for mate in mates:
		mate.hp = 99999.0
		mate.held = "rifle"
		mate.aiming = true
		mate.crouching = rng.randf() < 0.5
		mate.rotation.y = p.rotation.y + rng.randf_range(-0.25, 0.25)
		if mate.get("label"):
			mate.label.visible = false
	if m.get("guard_drone") and is_instance_valid(m.guard_drone):
		m.guard_drone.visible = false
	if m.nvg_on:
		m.set_nvg(false)
	# the aliens: a few of them ahead, in the open, already fighting
	for a in m.aliens():
		a.global_position += Vector3(0, -80, 0)
		a.set_physics_process(false)
	for i in int(Game.cmd_arg("n", "3")):
		var spot: Vector3 = m.free_spot(base + fwd * rng.randf_range(6.5, 9.0) + right * rng.randf_range(-3.5, 3.5) + Vector3(0, 0.3, 0))
		m.spawn_alien(race if i > 0 or Game.cmd_arg("race2", "") == "" else Game.cmd_arg("race2", ""), spot)
	await at.get_tree().create_timer(0.4).timeout
	for a in m.aliens():
		if a.global_position.y < -40:
			continue
		a.target = mates[0]
		a.last_seen = mates[0].global_position
		a._enter_combat(mates[0])
		a.alert = true
		a.set_physics_process(false)      # they stand and shoot (the AI would run them into cover, out of the picture)
	var cam := Camera3D.new()
	m.add_child(cam)
	cam.fov = 52.0
	cam.current = true
	var n := 0
	var tt := 0.0
	# [sideways, height, back, look-at point along the line team -> aliens 0..1]
	var views := [[-7.5, 0.6, -6.0, 0.5], [2.4, 0.5, 2.6, 0.75], [8.0, 1.4, -7.0, 0.5], [-1.8, 0.2, 1.8, 0.85], [-5.0, 2.6, -3.0, 0.45], [6.0, 0.3, -9.5, 0.3]]
	while n < int(Game.cmd_arg("shots", "8")) and tt < 30.0:
		await at.get_tree().physics_frame
		var dt: float = at.get_physics_process_delta_time()
		tt += dt
		var foe: Node = null
		for a in m.aliens():
			if not a.dead and a.global_position.y > -40:
				foe = a
				break
		var aim: Vector3 = (foe.global_position if foe else base + fwd * 14.0) + Vector3(0, 1.1, 0)
		for mate in mates:
			var mt: Vector3 = aim - mate.global_position
			mate.rotation.y = atan2(-mt.x, -mt.z)
			if rng.randf() < dt * 2.2:
				var hand: Vector3 = mate.global_position + Vector3(0, 1.0 if mate.crouching else 1.4, 0) - mate.global_transform.basis.z * 0.7
				mate._shot_fx(hand, aim + Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.4, 0.6), 0), "rifle")
			mate._remote_visuals()
		for a in m.aliens():
			if a.global_position.y > -40 and not a.dead:
				a.hp = maxf(a.hp, 60.0)       # (nobody dies before the pictures are taken)
				var la: Vector3 = mates[0].global_position - a.global_position
				a.rotation.y = atan2(-la.x, -la.z)
				a._animate(dt)
				if rng.randf() < dt * 1.4:
					var mz: Vector3 = a._muzzle_pos()
					var tgt: Node = mates[rng.randi() % mates.size()]
					a._plasma(mz, (tgt.global_position + Vector3(0, 1.2 + rng.randf_range(-0.3, 0.6), 0) + right * rng.randf_range(-1.2, 1.2) - mz).normalized())
		if tt > 2.0 + n * 1.3:
			var v: Array = views[n % views.size()]
			if not _frame(m, cam, mates[0], mates.slice(1), base, fwd, right, v, rng):
				n += 1
				continue
			await RenderingServer.frame_post_draw
			shot(at, "load_%s_%d" % [tag, n])
			n += 1
	at.out("RESULT loadshots %s %d" % [tag, n])
	at.get_tree().quit()

## Puts the film camera near the wanted spot so that the soldiers and the aliens are all in clear view.
static func _frame(m: Node, cam: Camera3D, p: Node, mates: Array, base: Vector3, fwd: Vector3, right: Vector3, v: Array, rng: RandomNumberGenerator) -> bool:
	# (0.66, Ari: "naaranžovat") a film camera from the side of the fight, 7-13 m away, so that the
	# team on one side and the aliens on the other are both in the picture; never inside a bush or car
	var ss: PhysicsDirectSpaceState3D = m.get_world_3d().direct_space_state
	var who := [p] + mates
	for a in m.aliens():
		if not a.dead and a.global_position.y > -40:
			who.append(a)
	var mid := Vector3.ZERO
	for w in who:
		mid += w.global_position
	mid = mid / who.size() + Vector3(0, 1.0, 0)
	var side: float = signf(float(v[0])) if float(v[0]) != 0.0 else 1.0
	var ball := SphereShape3D.new()
	ball.radius = 1.1
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = ball
	q.collision_mask = Game.WORLD
	var best := -99.0
	var best_pos := Vector3.ZERO
	for i in 160:
		# mostly from the side (60-125 degrees off the line of fire), sometimes over the shoulder of the team
		var ang := rng.randf_range(1.05, 2.2) * side if rng.randf() < 0.8 else rng.randf_range(2.5, 2.9) * side
		var dir := fwd.rotated(Vector3.UP, ang)
		var pos: Vector3 = mid + dir * rng.randf_range(5.5, 9.0) + Vector3(0, rng.randf_range(0.2, 1.8) + float(v[1]) * 0.3, 0)
		var down := ss.intersect_ray(PhysicsRayQueryParameters3D.create(pos + Vector3(0, 4, 0), pos - Vector3(0, 8, 0), Game.WORLD))
		if down.is_empty() or pos.y - down.position.y < 1.0:
			continue
		q.transform = Transform3D(Basis(), pos)
		if not ss.intersect_shape(q, 1).is_empty():
			continue        # (a wall, a car, a tree right at the lens)
		var seen := 0.0
		for w in who:
			var t: Vector3 = w.global_position + Vector3(0, 1.1, 0)
			if ss.intersect_ray(PhysicsRayQueryParameters3D.create(pos, t, Game.WORLD)).is_empty():
				seen += 1.0
			if (t - pos).normalized().angle_to((mid - pos).normalized()) > 0.46:
				seen -= 1.0
		seen += rng.randf() * 0.3
		if seen > best:
			best = seen
			best_pos = pos
	if best < who.size() - 1.2:
		print("[LOADSHOT] view %s: best %.1f of %d" % [v, best, who.size()])
		return false
	cam.fov = 58.0
	cam.global_position = best_pos
	cam.look_at(mid, Vector3.UP)
	return true

## --autotest=transport: the mission won with two mates aboard (one wounded, one out cold) - the look
## into the transport and the numbers under it. Saves user://transport_1/2.png (xvfb).
static func transport(at: Node, p: Node) -> void:
	at._skip_brief()
	if p == null or at.step > 0 or not at.m().started():
		return
	at.step = 1
	var m: Node = at.m()
	await at.get_tree().create_timer(0.8).timeout
	var looks := [{"top": 2, "vest": 1, "headgear": 3, "tattoo": 2}, {"top": 1, "vest": 2, "headgear": 4, "paint": 1, "female": true}, {"top": 0, "vest": 0, "headgear": 5}]
	var mates := []
	for k in int(Game.cmd_arg("mates", "2")):
		var mm: Dictionary = m.roster()[p.get_multiplayer_authority()]["merc"].duplicate(true)
		var lk: Dictionary = mm.get("look", {}).duplicate()
		lk.merge(looks[k % looks.size()], true)
		mm["look"] = lk
		var mate: Node = m._spawn({"kind": "player", "peer": 7 + k, "pos": m.map["evac"] + Vector3(0.6 * k, 0.3, 0.5), "yaw": 0.0, "merc": mm, "name": "Kamarád %d" % k})
		m.actors.add_child(mate)
		mates.append(mate)
	await at.get_tree().physics_frame
	p.global_position = m.map["evac"] + Vector3(0, 0.3, 0)
	p.kills = 4
	p.captures = 1
	p.salvage = 120
	if mates.size() > 0:
		mates[0].wounded = true
		mates[0].hp = mates[0].max_hp * 0.4
	if mates.size() > 1:
		mates[1].downed = true
	m._end(true, "Test.")
	await at.get_tree().create_timer(1.6).timeout
	var tr: Node = m.get("transport")
	at.out("RESULT transport shown %s" % (tr != null and is_instance_valid(tr)))
	shot(at, "transport_1")
	await at.get_tree().create_timer(1.5).timeout
	shot(at, "transport_2")
	if tr and is_instance_valid(tr):
		tr.finish()
	await at.get_tree().create_timer(0.6).timeout
	at.out("RESULT transport closed %s" % (not is_instance_valid(tr)))
	at.get_tree().quit()

## --autotest=npcshot: the people of the base (scientists, technicians): how many, that they work and
## walk between their places; pictures user://npc_<n>.png of each from close by (xvfb).
static func npcshot(at: Node, p: Node) -> void:
	at._skip_brief()
	if p == null or at.step > 0 or not at.m().started():
		return
	at.step = 1
	var m: Node = at.m()
	var npcs := []
	for c in m.get_children():
		if c.get_script() == m.BaseNpc:
			npcs.append(c)
	var start := {}
	for n in npcs:
		start[n] = n.global_position
	at.out("RESULT npc count %d (sci %d, tech %d), clips %s" % [npcs.size(), npcs.filter(func(n): return n.role == "sci").size(), npcs.filter(func(n): return n.role == "tech").size(), not AnimClips.get_clip("tp_npc_walk").is_empty()])
	p.body.visible = false
	m.hud.visible = false
	var cam := Camera3D.new()
	m.add_child(cam)
	cam.fov = 60.0
	cam.current = true
	var k := 0
	if Game.cmd_arg("who", "") == "board":
		npcs = npcs.filter(func(n): return n._board != null and n.role == "sci")
		npcs = npcs.slice(0, 1)
		for n in npcs:
			n._busy.clear()
			n._post = n.posts.find(n.posts.filter(func(q): return q["act"] == "talk")[0])
			n._work_t = 99.0
			n._path = PackedVector3Array()
			n.global_position = n.posts[n._post]["pos"]
			n._start_work()
	for n in npcs:
		await at.get_tree().create_timer(1.5).timeout
		var fwd := Vector3(-sin(n.rotation.y), 0, -cos(n.rotation.y))
		var side := fwd.cross(Vector3.UP)
		cam.global_position = n.global_position + (fwd * 1.6 + side * 1.1 if Game.cmd_arg("who", "") != "board" else fwd * 1.5 + side * 0.7) + Vector3(0, 1.55, 0)
		cam.look_at(n.global_position + Vector3(0, 1.0, 0), Vector3.UP)
		await at.get_tree().process_frame
		await at.get_tree().process_frame
		shot(at, "npc_%d" % k)
		k += 1
		if k >= int(Game.cmd_arg("shots", "8")):
			break
	await at.get_tree().create_timer(float(Game.cmd_arg("wait", "20"))).timeout
	var moved := 0
	for n in npcs:
		if n.global_position.distance_to(start[n]) > 1.0:
			moved += 1
	at.out("RESULT npc moved %d of %d" % [moved, npcs.size()])
	at.get_tree().quit()

## --autotest=baseshot (0.69, Ari's glitches at the base): the building site (builders = technicians with
## hard hats, the shut door without a sign), the gun rack, a console from the front and the side, the
## hangar's corner by the west doorway. Pictures user://base_<what>.png (xvfb).
static func baseshot(at: Node, p: Node) -> void:
	at._skip_brief()
	if p == null or at.step > 0 or not at.m().started():
		return
	at.step = 1
	var m: Node = at.m()
	var builders := []
	for c in m.get_children():
		if c.get_script() == m.BaseNpc and c.builder:
			builders.append(c)
	at.out("RESULT baseshot builders %d" % builders.size())
	p.body.visible = false
	m.hud.visible = false
	var cam := Camera3D.new()
	m.add_child(cam)
	cam.fov = 60.0
	cam.current = true
	var views := [
		["site", Vector3(30.0, 1.7, 21.5), Vector3(30.0, 1.2, 26.0)],
		["site_in", Vector3(33.5, 2.2, 33.5), Vector3(28.5, 0.6, 28.0)],
		["rack", Vector3(27.1, 1.5, 3.9), Vector3(27.1, 1.45, 1.1)],
		["rack_side", Vector3(29.6, 1.6, 3.0), Vector3(26.8, 1.4, 1.2)],
		["console", Vector3(21.4, 1.65, 15.0), Vector3(20.6, 1.0, 13.5)],
		["console_side", Vector3(22.2, 1.3, 14.0), Vector3(20.6, 1.0, 13.6)],
		["hangar", Vector3(16.5, 1.7, 3.0), Vector3(13.4, 1.0, 8.0)],
	]
	for v in views:
		cam.global_position = v[1]
		cam.look_at(v[2], Vector3.UP)
		await at.get_tree().create_timer(0.6).timeout
		shot(at, "base_" + String(v[0]))
	var k := 0
	for n in builders:
		var fwd := Vector3(-sin(n.rotation.y), 0, -cos(n.rotation.y))
		var side := fwd.cross(Vector3.UP)
		cam.global_position = n.global_position + fwd * 1.7 + side * 1.2 + Vector3(0, 1.6, 0)
		cam.look_at(n.global_position + Vector3(0, 0.9, 0), Vector3.UP)
		await at.get_tree().create_timer(0.6).timeout
		shot(at, "base_builder_%d" % k)
		var hb: int = n._sk.find_bone("head")
		var head: Vector3 = (n._sk.global_transform * n._sk.get_bone_global_pose(hb)).origin
		cam.global_position = head + side * 0.7 + fwd * 0.3 + Vector3(0, 0.1, 0)
		cam.look_at(head + Vector3(0, 0.1, 0), Vector3.UP)
		cam.fov = 40.0
		await at.get_tree().process_frame
		await at.get_tree().process_frame
		shot(at, "base_builder_head_%d" % k)
		cam.fov = 60.0
		k += 1
		continue
		await at.get_tree().create_timer(0.6).timeout
		shot(at, "base_builder_%d" % k)
		k += 1
	at.get_tree().quit()

## Overflow check for one screen (0.66, Ari: "aby nic nepřetékalo"): Game.ui_audit (out of the screen)
## and on top: a control sticking out of its panel, a text taller/wider than its box, a container
## squeezed under its minimum, a scrolling box too narrow to read. Prints "[UI] <tag>: ... přetéká".
static func fit(root: Node, tag: String) -> int:
	var bad := Game.ui_audit(root, tag)
	for c in root.find_children("*", "Control", true, false):
		var ctl: Control = c
		if not ctl.is_visible_in_tree() or ctl.size == Vector2.ZERO:
			continue
		var scrolled := false
		var panel: Control = null
		var an := ctl.get_parent()
		while an and an is Control:
			if an is ScrollContainer or (an as Control).clip_contents:
				scrolled = true
				break
			if panel == null and (an is Panel or an is PanelContainer):
				panel = an
			an = an.get_parent()
		if scrolled:
			continue
		var why := ""
		var r := ctl.get_global_rect()
		var need := ctl.get_combined_minimum_size()
		if panel and not panel.get_global_rect().grow(1.0).encloses(r):
			why = "přetéká panel %s (%s v %s)" % [panel.name, r, panel.get_global_rect()]
		elif need.x > ctl.size.x + 1.0 or need.y > ctl.size.y + 1.0:
			why = "přetéká: potřebuje %s, má %s" % [need, ctl.size]
		elif ctl is ScrollContainer and ctl.size.x < 140.0:
			why = "přetéká: posuvné pole je úzké (%.0f px)" % ctl.size.x
		if why != "":
			bad += 1
			var txt := String(ctl.get("text")).replace("\n", " / ").left(50) if "text" in ctl else ""
			print("[UI] %s: %s %s - %s \"%s\"" % [tag, ctl.get_class(), ctl.name, why, txt])
	print("[UI] %s: fit %d" % [tag, bad])
	return bad

## --autotest=uifit: every variant of the 0.66 screens against the 640x360 screen - the loading
## screen with each title and each tip / mood line (easy and hardcore), the transport panel with the
## shortest and the longest numbers, civilians, 1-4 soldiers, a long report, the solo HUD with the
## drone radar. RESULT uifit bad 0 = nothing overflows. Pictures user://fit_*.png (xvfb).
static func uifit(at: Node, p: Node) -> void:
	at._skip_brief()
	if p == null or at.step > 0 or not at.m().go:
		return
	at.step = 1
	var m: Node = at.m()
	var tree := at.get_tree()
	var bad := 0
	await tree.create_timer(1.0).timeout
	at._skip_brief()
	m.hud.inventory_open = false
	await tree.create_timer(2.5).timeout
	# the solo HUD with the radar in the corner
	bad += fit(m.hud, "fit_hud_radar")
	shot(at, "fit_hud_radar")
	# (0.66 jednotný HUD) the minimal HUD, a message on its plate, the compass with a loud sound
	Game.hud_min = true
	Game.loud_at = p.global_position + Vector3(12, 0, -10)
	Game.loud_ms = Time.get_ticks_msec()
	m.hud.message("Strážce: nepřítel je moc blízko. Čekám, až se vzdálí...", 3.0)
	await tree.create_timer(0.3).timeout
	bad += fit(m.hud, "fit_hud_min")
	shot(at, "fit_hud_min")
	Game.hud_min = false
	Game.hud_hidden = true
	await tree.create_timer(0.2).timeout
	shot(at, "fit_hud_hidden")
	Game.hud_hidden = false
	# the loading screen: every title x every line
	var titles: Array = Game.LOAD_WHAT.values() + ["Načítání"]
	var lines: Array = Game.LoadingScreen.TIPS + Game.LoadingScreen.MOOD
	var ld: CanvasLayer = Game.LoadingScreen.new()
	ld.setup("x", true)
	Game.add_child(ld)
	ld._root.modulate.a = 1.0
	var longest := ""
	for t in titles:
		for l in lines:
			ld.set_what(String(t))
			ld._line.text = l
			for n in [1, 3]:
				ld._set_dots(n)
				await tree.process_frame
				bad += fit(ld, "fit_load")
			if String(l).length() > longest.length():
				longest = l
	ld.set_what("Stíhačka startuje")
	ld._line.text = longest
	await tree.process_frame
	shot(at, "fit_loading")
	ld.queue_free()
	# and the real thing running: pictures and lines change by themselves (fast), checked every frame
	ld = Game.LoadingScreen.new()
	ld.setup("Mise", true)
	Game.add_child(ld)
	var frames := 0
	var lines_seen := {}
	var t_end := Time.get_ticks_msec() + 9000
	while Time.get_ticks_msec() < t_end:
		ld._slide_t += 0.6
		await tree.process_frame
		lines_seen[ld._line.text] = true
		var b := fit(ld, "fit_load_run")
		bad += b
		frames += 1
		if b > 0:
			shot(at, "fit_loading_bad")
			break
	at.out("RESULT loading run frames %d lines %d" % [frames, lines_seen.size()])
	ld.queue_free()
	# the transport: short and long numbers, with and without civilians and report, 1-4 aboard
	var short := [["Zabití", "0"], ["Zajatí živí", "0"], ["Oživil jsi", "0"], ["Zranění v týmu", "0 z 1"],
		["Nálezy", "0 kr"], ["Žold", "-"], ["Zkušenosti", "-"], ["Hodnocení", "-"],
		["Kořist: těla", "0"], ["zajatci", "0"], ["zbraně", "0"], ["moskovium", "0"]]
	var long := [["Zabití", "48"], ["Zajatí živí", "12"], ["Oživil jsi", "9"], ["Zranění v týmu", "4 z 4"],
		["Nálezy", "12 480 kr"], ["Žold", "+18 750 kr"], ["Zkušenosti", "+1 240"], ["Hodnocení", "ucházející"],
		["Kořist: těla", "126"], ["zajatci", "14"], ["zbraně", "37"], ["moskovium", "2 450"],
		["Civilisté zachránění", "124"], ["mrtví", "37"]]
	var report_long := "Tvůj voják: Vrátil se raněný, týden na marodce.\n\n" + "Výzkum dokončen: rozbor plazmové zbraně. Na globu se objevilo nové UFO nad severní Afrikou. ".repeat(6)
	var cases := [["short", short, "", 1], ["long", long, report_long, 4], ["long_norep", long, "", 4],
		["mid", short + [["Civilisté zachránění", "3"], ["mrtví", "1"]], "Tvůj voják: v pořádku.", 2]]
	var mtype_names := ["HAVÁRIE UFO", "TERORISTICKÝ ÚTOK NA MĚSTO", "PŘISTÁNÍ UFO", "ZÁKLADNA VETŘELCŮ - ÚTOK"]
	for c in cases:
		for tn in mtype_names:
			var team := []
			for k in int(c[3]):
				team.append({"model": m._body_copy(p), "state": ["ok", "hurt", "down", "ok"][k], "me": k == 0})
			var tr: CanvasLayer = m.TransportScene.new()
			Game.add_child(tr)
			tr.setup(team, "CESTA DOMŮ - " + tn, c[1], c[2], c[0] == "mid")
			await tree.process_frame
			await tree.process_frame
			bad += fit(tr, "fit_transport_" + String(c[0]))
			if tn == mtype_names[1]:
				await tree.create_timer(0.4).timeout
				shot(at, "fit_transport_" + String(c[0]))
			tr.queue_free()
			await tree.process_frame
	at.out("RESULT uifit bad %d" % bad)
	tree.quit()
