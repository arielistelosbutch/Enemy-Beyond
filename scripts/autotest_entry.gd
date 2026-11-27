extends RefCounted
## 0.72.6 oprava (Ari: „sundali jsme bitevní loď, ale nedalo se do ní dostat, na mapě nebyl vchod“):
## tým musí dojít od dveří UFO dovnitř lodi. --autotest=ufoentry --mtype=crash|landed --ufo=<loď>
## Cesta (navigace) z místa 6 m před dveřmi do středu lodi, pak voják jde po ní (skutečná fyzika).
## RESULT ufoentry <loď> nav <m od středu> walk <m od středu> inside true|false

static func run(at: Node, p: Node) -> void:
	if p == null or at.step > 0:
		return
	at._skip_brief()
	var m: Node = at.m()
	if not m.go:
		return
	at.step = 1
	for a in m.aliens():
		a.set_physics_process(false)
		a.global_position = Vector3(0, -80, 0)
	await at.get_tree().create_timer(1.0).timeout
	var c: Vector3 = m.map.get("ufo", Vector3.ZERO)
	var door: Vector3 = m.map.get("ufo_door", c)
	var kind := String(m.map.get("ufo_kind", "?"))
	var out_dir := Vector3(door.x - c.x, 0, door.z - c.z).normalized()
	var start := door + out_dir * 6.0
	var goal := c + Vector3(0, 0.1, 0)
	var nav_map: RID = p.get_world_3d().navigation_map
	var s2 := NavigationServer3D.map_get_closest_point(nav_map, start)
	var g2 := NavigationServer3D.map_get_closest_point(nav_map, goal)
	var path := NavigationServer3D.map_get_path(nav_map, s2, g2, true)
	var nav_end := 1e9 if path.is_empty() else Vector2(path[-1].x - c.x, path[-1].z - c.z).length()
	# the merc walks it
	p.set_physics_process(false)
	p.global_position = s2 + Vector3(0, 0.2, 0)
	p.velocity = Vector3.ZERO
	await at.get_tree().physics_frame
	var pts: Array = Array(path) if not path.is_empty() else [goal]
	if Vector2(pts[-1].x - c.x, pts[-1].z - c.z).length() > 1.5:
		pts.append(goal)                 # (no way in: walk straight at the middle, see what stops him)
	var i := 0
	for f in 1800:
		if i >= pts.size():
			break
		var t: Vector3 = pts[i]
		var d := Vector3(t.x - p.global_position.x, 0, t.z - p.global_position.z)
		if d.length() < 0.5:
			i += 1
			continue
		p.velocity = d.normalized() * 4.0 + Vector3(0, p.velocity.y - 9.8 / 60.0, 0)
		p.move_and_slide()
		await at.get_tree().physics_frame
	var walk := Vector2(p.global_position.x - c.x, p.global_position.z - c.z).length()
	var inside := walk < 10.0      # (past the skirt and the entry hall)
	at.out("RESULT ufoentry %s nav %.1f walk %.1f inside %s" % [kind, nav_end, walk, str(inside)])
	at.get_tree().quit()

## lawntest (Ari 2026-11-27: „v některých UFO je pořád uvnitř trávník“): kolik stébel trávy roste
## pod lodí (malé: do poloměru místností, obří: pod trupem). --autotest=lawntest --mtype=crash|landed --ufo=<loď>
## RESULT lawntest <loď> inside <stébel pod lodí> cut <vyhozených>
static func lawn(at: Node, p: Node) -> void:
	if p == null or at.step > 0:
		return
	at._skip_brief()
	var m: Node = at.m()
	if not m.go:
		return
	at.step = 1
	var c: Vector3 = m.map.get("ufo", Vector3.ZERO)
	var kind := String(m.map.get("ufo_kind", "?"))
	var r: float = {"scout": 5.0, "raider": 7.0, "harvester": 10.0}.get(kind, 0.0)
	var inside := 0
	var blades := 0
	for mi in m.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := mi as MultiMeshInstance3D
		if mmi.multimesh == null or not (mmi.material_override is ShaderMaterial):
			continue
		if (mmi.material_override as ShaderMaterial).shader != preload("res://shaders/grass.gdshader"):
			continue
		var g := mmi.global_transform
		for k in mmi.multimesh.instance_count:
			var w: Vector3 = g * mmi.multimesh.get_instance_transform(k).origin
			blades += 1
			var d := Vector2(w.x - c.x, w.z - c.z)
			var lim := r
			if r == 0.0:
				var dn := Vector3(d.x, 0, d.y).normalized()
				lim = 23.0 / pow(pow(absf(dn.x), 4.0) + pow(absf(dn.z), 4.0), 0.25)
			if d.length() < lim:
				inside += 1
	if DisplayServer.get_name() != "headless":
		# a look at the floor from inside (window only): user://lawn_<loď>_<n>.png
		for a in m.aliens():
			a.set_physics_process(false)
			a.global_position = Vector3(0, -80, 0)
		for w in 30:
			at._skip_brief()
			await at.get_tree().create_timer(0.2).timeout
		p.set_physics_process(false)
		var fl: Vector3 = c + Vector3(0, 0.15, 0)
		var ins: Array = m.map.get("ufo_inside", [])
		if not ins.is_empty():
			fl = ins[0] + Vector3(0, 0.15, 0)
		for n in 3:
			var ang := TAU * n / 3.0
			p.global_position = fl + Vector3(sin(ang), 0, cos(ang)) * (1.2 if r > 0.0 else 3.0)
			p.rotation.y = ang
			p.pitch = -0.5
			for f in 20:
				await at.get_tree().process_frame
			at.get_viewport().get_texture().get_image().save_png("user://lawn_%s_%d.png" % [kind, n])
	at.out("RESULT lawntest %s inside %d cut %d blades %d" % [kind, inside, int(m.map.get("lawn_cut", -1)), blades])
	at.get_tree().quit()

## darktest (Ari 2026-11-27: „při Blackoutu dál svítí televize, osvětlení benzinky…“): výpadek proudu
## zhasne lampy, televize a svítící materiály ve městě; loď vetřelců, auta a transportér svítí dál.
## --autotest=darktest --mtype=terror --biome=town --seed=3
## RESULT darktest civ <materiálů> off <zhasnutých> tv <zhasnutých>/<televizí> lamps_on <rozsvícených> ufo_glow <svítících na lodi>
static func dark(at: Node, p: Node) -> void:
	if p == null or at.step > 0:
		return
	at._skip_brief()
	var m: Node = at.m()
	if not m.go:
		return
	at.step = 1
	var civ: Array = m.map.get("civ_glow", [])
	var names := []
	for mt in civ:
		var sp = mt.get_meta("spec", [])
		names.append(str(sp))
	at.out("[DARK] civ glow: " + ", ".join(names))
	var fps := func(tag: String) -> float:
		var n := 0
		var t0 := Time.get_ticks_usec()
		while Time.get_ticks_usec() - t0 < 3000000:
			await at.get_tree().process_frame
			n += 1
		if DisplayServer.get_name() != "headless":
			at.get_viewport().get_texture().get_image().save_png("user://dark_%s.png" % tag)
		return float(Time.get_ticks_usec() - t0) / 1000.0 / maxf(n, 1)
	var ms_on := 0.0
	if DisplayServer.get_name() != "headless":
		var fuel := Vector3.ZERO
		for lm in m.map.get("landmarks", []):
			if lm[0] == "fuel":
				fuel = lm[1] + Vector3(12.0, 0, 12.0)
		if fuel != Vector3.ZERO:
			p.set_physics_process(false)
			p.global_position = fuel + Vector3(0, 0.1, 4.0)
			p.rotation.y = PI * 0.75
			p.pitch = 0.0
		ms_on = await fps.call("on")
	m._blackout()
	await at.get_tree().create_timer(0.5).timeout
	var ms_off := 0.0
	if DisplayServer.get_name() != "headless":
		ms_off = await fps.call("off")
		at.out("[DARK] frame ms before %.1f after %.1f" % [ms_on, ms_off])
	var off := 0
	for mt in civ:
		if float(mt.get_shader_parameter("emission_energy")) == 0.0:
			off += 1
	var tv := 0
	var tv_off := 0
	for l in m.map.get("lights", []):
		if is_instance_valid(l) and l.get_meta("tv", false):
			tv += 1
			if not l.visible:
				tv_off += 1
	var lamps_on := 0
	for l in m.map.get("elec_lights", []):
		if is_instance_valid(l) and l.visible and l.light_energy > 0.01 and not l.get_meta("powered", false):
			lamps_on += 1
	var ufo_glow := 0
	var u: Node = m.map.get("ufo_node")
	if u != null:
		for mi in u.find_children("*", "MeshInstance3D", true, false):
			for i in (mi as MeshInstance3D).mesh.get_surface_count():
				var sm = (mi as MeshInstance3D).get_surface_override_material(i)
				if sm is ShaderMaterial and sm.get_shader_parameter("emission_energy") != null and float(sm.get_shader_parameter("emission_energy")) > 0.0:
					ufo_glow += 1
	at.out("RESULT darktest civ %d off %d tv %d/%d lamps_on %d ufo_glow %d" % [civ.size(), off, tv_off, tv, lamps_on, ufo_glow])
	at.get_tree().quit()