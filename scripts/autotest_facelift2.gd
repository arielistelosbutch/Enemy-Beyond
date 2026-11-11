extends RefCounted
## 0.70 Facelift II tests (called from autotest.gd): the echo of the place, dirt and blood on the uniform,
## the wall of the fallen, the intro.

## A screenshot when there is a screen (xvfb); nothing under --headless.
static func shot(at: Node, name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var img: Image = at.get_viewport().get_texture().get_image()
	if img != null:
		img.save_png("user://%s.png" % name)

## --autotest=echotest (a mission) / echobase (the home base): the soldier stands in a few places and the
## test prints what the ears hear there (RoomEcho.kind) and how wet the reverb is.
static func echo(at: Node, p: Node) -> void:
	at._skip_brief()
	if p == null or at.step > 0 or not at.m().started():
		return
	at.step = 1
	var m: Node = at.m()
	p.hp = 99999.0
	var re: Node = m.get_node_or_null("RoomEcho")
	if re == null:
		at.out("RESULT echo none")
		at.get_tree().quit()
		return
	var spots := []
	var mp: Dictionary = m.map
	if mp.get("home", false) or String(Net.mission_params.get("type", "")) in ["base", "home"]:
		spots.append(["spawn", p.global_position])
		for q in (mp.get("passages", []) as Array).slice(0, 2):
			spots.append(["passage", (q["c"] as Vector3) + Vector3(0, 0.3, 0)])
	else:
		spots.append(["spawn", p.global_position])
		if mp.has("ufo") and (mp["ufo"] as Vector3) != Vector3.ZERO:
			spots.append(["ufo", (mp["ufo"] as Vector3) + Vector3(0, 0.6, 0)])
		if mp.has("house"):
			spots.append(["house", (mp["house"] as Vector3) + Vector3(0, 0.3, 0)])
		spots.append(["evac", (mp["evac"] as Vector3) + Vector3(0, 0.3, 0)])
		# the open: the waypoint with the fewest things round it (the test takes the first one heard as open)
		var wps: Array = mp.get("waypoints", [])
		for i in mini(6, wps.size()):
			var w: Vector3 = wps[(i * 7919) % wps.size()]
			spots.append(["field", w + Vector3(0, 0.3, 0)])
	var kinds := []
	for s in spots:
		p.global_position = s[1]
		p.velocity = Vector3.ZERO
		await at.get_tree().create_timer(1.6).timeout
		at.out("RESULT echo %s %s wet %.3f size %.2f probe %s" % [s[0], re.kind, float(re._fx.wet), float(re._fx.room_size), str(re.probe)])
		kinds.append(re.kind)
	at.out("RESULT echo kinds %s open %s bus %s" % [",".join(kinds.slice(0, kinds.size() - 6 if kinds.size() > 6 and not mp.get("home", false) else kinds.size())), "open" in kinds, Game.RoomEcho.bus()])
	at.get_tree().quit()

## --autotest=dirtshot [--mtype=crash --biome=farm --day=1]: the soldier crawls, lies and gets hit; prints
## how dirty and bloody he got (and that the transport's copy of him is the same), shots dirt_0..3.png.
static func dirt(at: Node, p: Node) -> void:
	at._skip_brief()
	if p == null or at.step > 0 or not at.m().started():
		return
	at.step = 1
	var m: Node = at.m()
	for x in m.aliens():
		x.global_position += Vector3(0, -60, 0)
		x.set_physics_process(false)
	await at.get_tree().create_timer(1.2).timeout
	at._skip_brief()
	m.hud.inventory_open = false
	m.hud.visible = false
	var ud: Node = p.get_node_or_null("UniformDirt")
	if ud == null:
		at.out("RESULT dirt none")
		at.get_tree().quit()
		return
	var start: Vector3 = m.free_spot(m.map["evac"] + Vector3(6, 0.3, -6))
	p.global_position = start
	p.body.visible = true
	var cam := Camera3D.new()
	m.add_child(cam)
	cam.fov = 45.0
	cam.current = true
	var frame := func(k: int) -> void:
		var f: Vector3 = -p.global_transform.basis.z
		var side := f.cross(Vector3.UP)
		cam.global_position = p.global_position + f * 2.3 + side * 0.8 + Vector3(0, 1.3, 0)
		cam.look_at(p.global_position + Vector3(0, 0.85, 0), Vector3.UP)
	frame.call(0)
	await at.get_tree().create_timer(0.6).timeout
	shot(at, "dirt_0")
	var clean: float = ud.dirt + ud.low
	# crawl for a while (the body moves under the dirt script like when the player drags himself on)
	p.prone = true
	var t := 0.0
	while t < 14.0:
		await at.get_tree().physics_frame
		var d: float = at.get_physics_process_delta_time()
		t += d
		p.global_position += -p.global_transform.basis.z * 0.6 * d
	p.prone = false
	await at.get_tree().create_timer(1.2).timeout
	frame.call(1)
	await at.get_tree().create_timer(0.5).timeout
	shot(at, "dirt_1")
	at.out("RESULT dirt crawl dirt %.2f low %.2f (clean %.2f)" % [ud.dirt, ud.low, clean])
	# hits
	p.hp = 100.0
	for i in 4:
		p.hp -= 7.0
		await at.get_tree().create_timer(0.15).timeout
	await at.get_tree().create_timer(0.4).timeout
	frame.call(2)
	await at.get_tree().create_timer(0.3).timeout
	shot(at, "dirt_2")
	# the back
	cam.global_position = p.global_position + p.global_transform.basis.z * 2.3 + Vector3(0, 1.3, 0)
	cam.look_at(p.global_position + Vector3(0, 0.85, 0), Vector3.UP)
	await at.get_tree().create_timer(0.3).timeout
	shot(at, "dirt_3")
	var copy: Node3D = m._body_copy(p)
	var dressed := 0
	var same := true
	if copy:
		for mi in copy.find_children("*", "MeshInstance3D", true, false):
			if mi.material_overlay is ShaderMaterial:
				dressed += 1
				same = same and absf(float(mi.material_overlay.get_shader_parameter("dirt")) - ud.dirt) < 0.001
		copy.free()
	at.out("RESULT dirt blood %d copy %d same %s" % [ud.blood.size(), dressed, same])
	at.get_tree().quit()

## --autotest=wallshot [--fallen=N]: the wall of the fallen in the velín - prints how many names it shows,
## shots wall_0 (whole) and wall_1 (close).
static func wall(at: Node, p: Node) -> void:
	at._skip_brief()
	if p == null or at.step > 0 or not at.m().started():
		return
	at.step = 1
	var m: Node = at.m()
	await at.get_tree().create_timer(1.0).timeout
	m.hud.visible = false
	var labels := 0
	for lb in m.find_children("*", "Label3D", true, false):
		if String(lb.text) == "PADLÍ ZA PROJEKT X":
			labels += 1
	var cam := Camera3D.new()
	m.add_child(cam)
	cam.fov = 55.0
	cam.current = true
	# the velín's room: the player's spawn is on its lift (north-west); the wall is on the south side
	var sp: Vector3 = m.map["player_spawns"][0]
	var a := Vector3(sp.x - 1.5, 0, sp.z - 1.5)
	var cx := a.x + 0.45 + 1.7
	var z := a.z + 10.0
	cam.global_position = Vector3(cx + 0.6, 1.65, z - 3.6)
	cam.look_at(Vector3(cx, 1.45, z), Vector3.UP)
	await at.get_tree().create_timer(0.4).timeout
	shot(at, "wall_0")
	cam.global_position = Vector3(cx + 0.7, 1.75, z - 1.5)
	cam.look_at(Vector3(cx + 0.7, 1.75, z), Vector3.UP)
	await at.get_tree().create_timer(0.3).timeout
	shot(at, "wall_1")
	at.out("RESULT wall title %d shown %d" % [labels, int(m.map.get("fallen_shown", -1))])
	at.get_tree().quit()

## --autotest=introshots: the intro film over the main menu - pictures at its key moments
## (intro_<n>.png), then a key press skips it and the menu is back.
static func intro(at: Node) -> void:
	var it: CanvasLayer = load("res://scripts/intro.gd").new()
	at.get_tree().root.add_child(it)
	var ends := [false]
	it.finished.connect(func(): ends[0] = true)
	var moments := [2.0, 10.0, 18.0, 27.0, 36.0, 44.0, 51.0, 56.0, 63.0, 70.0, 75.0, 80.0, 84.5, 91.0]
	if Game.cmd_arg("at", "") != "":
		moments = Array(Game.cmd_arg("at", "").split_floats(","))
	var k := 0
	for ft in moments:
		it.seek(ft)
		await at.get_tree().create_timer(0.35).timeout
		shot(at, "intro_%02d" % k)
		print("[AT] " + "RESULT intro t %.1f shot %s caption '%s'" % [ft, it._set_now, it._cap.text])
		if Game.cmd_arg("dbg", "") == "1":
			print("   cam %s squad %s brute %s" % [it._cam.global_position, it._squad.map(func(q): return [q.global_position, q.visible]), it._brute.global_position if it._brute else null])
		k += 1
	it.seek(20.0)
	await at.get_tree().create_timer(0.6).timeout
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.pressed = true
	Input.parse_input_event(ev)
	var sets: Array = _uniq(it.shots_seen)
	await at.get_tree().create_timer(1.0).timeout
	print("[AT] " + "RESULT intro sets %s skipped %s gone %s" % [",".join(PackedStringArray(sets)), ends[0], not is_instance_valid(it)])
	at.get_tree().quit()

static func _uniq(a: Array) -> Array:
	var o := []
	for x in a:
		if not x in o:
			o.append(x)
	return o
