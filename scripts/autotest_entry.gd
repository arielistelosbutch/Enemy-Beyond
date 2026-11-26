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
