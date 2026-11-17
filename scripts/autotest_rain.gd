extends RefCounted
## rainshot (2026-11-17, Ari: „když je člověk v budově, nevidí déšť venku, a když vyleze, začne
## pršet nanovo“): voják se postaví do domu (nad hlavou střecha) tak, aby se díval oknem nebo dveřmi
## ven, kde je nad zemí volné nebe. Snímky s deštěm a bez něj (rozdíl = kapky, které jsou vidět),
## pak voják vyjde ven: déšť se nesmí vypnout (GPU déšť běží pořád, kapky zastaví střecha).
## Čas snímku s deštěm a bez něj, v pohybu (výška terénu pro kapky se přepočítá při posunu).
## Spuštění: --autotest=rainshot --weather=storm --mtype=terror --biome=town [--cpurain=1]

static func run(at: Node, p: Node) -> void:
	if p == null: return
	at._skip_brief()
	if at.step > 0 or not at.m().started(): return
	at.step = 1
	var m: Node = at.m()
	p.hp = 1.0e6
	m.hud.inventory_open = false
	for a in m.aliens():
		a.set_physics_process(false)
		a.visible = false
		a.global_position += Vector3(0, -200, 0)
	if m.rain == null:
		at.out("RESULT rainshot no rain (weather %s)" % m.weather)
		at.get_tree().quit()
		return
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var sz: float = float(m.map.get("size", 60.0))
	# an indoor spot (roof above) that looks out through an opening onto open sky 3-9 m away
	var best := []
	var x := 1.0
	while x < sz and best.is_empty():
		var z := 1.0
		while z < sz and best.is_empty():
			var down := PhysicsRayQueryParameters3D.create(Vector3(x, 2.0, z), Vector3(x, -0.4, z), Game.WORLD)
			down.exclude = [p.get_rid()]
			var fh := space.intersect_ray(down)
			if not fh.is_empty() and (fh.normal as Vector3).y > 0.8:
				var feet: Vector3 = fh.position
				if _roofed(space, feet) and _roomy(space, feet):
					for k in 8:
						var d := Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 8.0)
						var eye := feet + Vector3(0, 1.55, 0)
						# from the back of the room: walk back until a wall, the opening ahead
						var hr := PhysicsRayQueryParameters3D.create(eye, eye + d * 9.0, Game.WORLD)
						var hit := space.intersect_ray(hr)
						if not hit.is_empty():
							continue
						var out_at := eye + d * 6.0
						if _roofed(space, out_at - Vector3(0, 1.55, 0)):
							continue
						best = [feet, d]
						break
			z += 1.5
		x += 1.5
	if best.is_empty():
		at.out("RESULT rainshot no indoor spot")
		at.get_tree().quit()
		return
	var feet: Vector3 = best[0]
	var dir: Vector3 = best[1]
	p.global_position = feet + Vector3(0, 0.1, 0)
	p.velocity = Vector3.ZERO
	await at.get_tree().create_timer(1.5).timeout
	at._aim_at(p, feet + Vector3(0, 1.4, 0) + dir * 10.0)
	await at.get_tree().create_timer(1.0).timeout
	var gpu: bool = m.rain_gpu
	at.out("[RAIN] gpu %s spot %s dir %s amount %d" % [gpu, feet, dir, m.rain.amount])
	var shots := DisplayServer.get_name() != "headless"
	var img_on: Image
	var img_off: Image
	if shots:
		await RenderingServer.frame_post_draw
		img_on = at.get_viewport().get_texture().get_image()
		at._snap("rain_inside")
	var ft_on := await _frames(at, 90)
	var vis_inside: bool = m.rain.visible
	m.rain.visible = false
	await at.get_tree().create_timer(0.3).timeout
	if shots:
		await RenderingServer.frame_post_draw
		img_off = at.get_viewport().get_texture().get_image()
		at._snap("rain_inside_off")
	var ft_off := await _frames(at, 90)
	m.rain.visible = vis_inside
	var diff := -1.0
	if img_on and img_off:
		var n := 0
		var w := img_on.get_width()
		var h := img_on.get_height()
		for yy in range(0, h, 2):
			for xx in range(0, w, 2):
				var a := img_on.get_pixel(xx, yy)
				var b := img_off.get_pixel(xx, yy)
				if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.04:
					n += 1
		diff = 100.0 * n / float((w / 2) * (h / 2))
	# step out: the rain must keep running (not hidden, not restarted)
	var outside := feet + dir * 7.0
	var walk_ft := 0.0
	var steps := 40
	for i in steps:
		p.global_position = feet.lerp(outside, float(i + 1) / steps) + Vector3(0, 0.1, 0)
		var t0 := Time.get_ticks_usec()
		await at.get_tree().process_frame
		walk_ft += (Time.get_ticks_usec() - t0) / 1000.0
	await at.get_tree().create_timer(0.8).timeout
	at._aim_at(p, outside + Vector3(0, 1.4, 0) - dir * 10.0)
	await at.get_tree().create_timer(0.6).timeout
	if shots:
		at._snap("rain_outside_back")
	at.out("[RAIN] frame ms with rain %.2f without %.2f walking %.2f" % [ft_on, ft_off, walk_ft / steps])
	at.out("RESULT rainshot gpu %s visible_inside %s visible_outside %s seen_outside %.2f%%" % [gpu, vis_inside, m.rain.visible, diff])
	at.get_tree().quit()

static func _roofed(space: PhysicsDirectSpaceState3D, feet: Vector3) -> bool:
	var up := PhysicsRayQueryParameters3D.create(feet + Vector3(0, 1.8, 0), feet + Vector3(0, 30, 0), 1)
	return not space.intersect_ray(up).is_empty()

static func _roomy(space: PhysicsDirectSpaceState3D, feet: Vector3) -> bool:
	# a real room: walls not right next to the eye on every side
	# and walls round it (a room, not the space under a tree or a lamp): at least 3 sides within 5 m
	var eye := feet + Vector3(0, 1.5, 0)
	var walls := 0
	for k in 4:
		var d := Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 4.0)
		var q := PhysicsRayQueryParameters3D.create(eye, eye + d * 0.6, Game.WORLD)
		if not space.intersect_ray(q).is_empty():
			return false
		q = PhysicsRayQueryParameters3D.create(eye, eye + d * 5.0, Game.WORLD)
		if not space.intersect_ray(q).is_empty():
			walls += 1
	return walls >= 3

static func _frames(at: Node, n: int) -> float:
	var t0 := Time.get_ticks_usec()
	for i in n:
		await at.get_tree().process_frame
	return (Time.get_ticks_usec() - t0) / 1000.0 / n
