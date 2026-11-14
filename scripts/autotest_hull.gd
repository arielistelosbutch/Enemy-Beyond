extends RefCounted
## 0.69 oprava (Ari: „stříleli nás skrz obrys lodě UFO“): plášť lodi na misi musí zastavit střely
## i pohled. --autotest=ufohull --mtype=crash|landed --ufo=scout|raider|harvester|battleship|supply
## Viditelný plášť (map["ufo_shell"]) dostane na zkoušku kolizi na vrstvě 1 << 20; pak se střílí
## paprsky s maskou Game.WORLD (stejně jako kulky, plazma a pohled vetřelců) kolem lodi ze všech
## stran, vodorovně v různých výškách, šikmo nahoru i shora dolů. „Díra“ = paprsek, který plášť
## viditelně protne, ale hra ho nezastaví do 0,3 m za tím místem.
## Navíc: voják natisknutý na loď (jde k ní, dokud ho něco nezastaví) - jeho hlava nesmí být
## uvnitř pláště a vetřelec z druhé strany lodi ho nesmí vidět.
## RESULT ufohull <loď> rays N leak X % hug_inside K seen S
## Co-op (--autotest=hullhost / hullclient, ve fulltestu pár ufo_hull): to samé u hostitele
## i u klienta (mapa i plášť se staví na každém počítači sám ze stejného semínka).

const LAYER := 1 << 20
const ROOM := {"scout": [5.0, 2.64], "raider": [7.0, 2.74], "harvester": [10.0, 2.94]}   # radius, wall top

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
	await at.get_tree().physics_frame
	var res := await check(at, p)
	at.out("RESULT ufohull %s rays %d leak %.1f %% hug_inside %d seen %d bodies %d" % [res["kind"], res["rays"], res["leak"], res["hug"], res["seen"], res["bodies"]])
	if Game.autotest() in ["hullhost", "hullclient"]:
		await at.get_tree().create_timer(4.0).timeout     # (the other side finishes too)
	at.get_tree().quit()

static func check(at: Node, p: Node) -> Dictionary:
	var m: Node = at.m()
	var shell: Array = m.map.get("ufo_shell", [])
	var c: Vector3 = m.map.get("ufo", Vector3.ZERO)
	var kind := String(m.map.get("ufo_kind", "?"))
	if shell.is_empty():
		return {"kind": kind + "(no shell)", "rays": 0, "leak": 100.0, "hug": 99, "seen": 99, "bodies": 0}
	var vb := StaticBody3D.new()
	vb.collision_layer = LAYER
	vb.collision_mask = 0
	m.add_child(vb)
	var bb := AABB()
	var first := true
	for mi in shell:
		if not is_instance_valid(mi):
			continue
		var sh: ConcavePolygonShape3D = (mi as MeshInstance3D).mesh.create_trimesh_shape()
		sh.backface_collision = true
		var cs := CollisionShape3D.new()
		cs.shape = sh
		vb.add_child(cs)
		cs.global_transform = (mi as MeshInstance3D).global_transform
		var b: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		bb = b if first else bb.merge(b)
		first = false
	for f in 3: await at.get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var rad := Vector2(bb.size.x, bb.size.z).length() / 2.0 + 3.0
	var top := bb.end.y
	var rays := 0
	var leak := 0
	var where := {}
	var lines := []
	for k in 36:
		var a := TAU * (k + 0.5) / 36.0
		var dir := Vector3(sin(a), 0, cos(a))
		for hy in [0.4, 0.9, 1.4, 1.8, 2.4, 3.0, 3.8, 4.6, 5.5]:
			if hy < top - c.y + 0.5:
				lines.append([c + dir * rad + Vector3(0, hy, 0), c - dir * rad + Vector3(0, hy, 0)])
		# up from a man on the ground over the hull, and down from above (a Levit, a roof)
		lines.append([c + dir * rad + Vector3(0, 1.5, 0), c - dir * rad + Vector3(0, top - c.y + 2.0, 0)])
		lines.append([c + dir * rad * 0.5 + Vector3(0, top - c.y + 6.0, 0), c - dir * rad * 0.3 + Vector3(0, 0.5, 0)])
	for ln in lines:
		var from: Vector3 = ln[0]
		var to: Vector3 = ln[1]
		var hv := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, LAYER))
		if hv.is_empty():
			continue
		rays += 1
		var hc := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, Game.WORLD))
		var dv := (Vector3(hv["position"]) - from).length()
		var dc := 1e9 if hc.is_empty() else (Vector3(hc["position"]) - from).length()
		var hp0: Vector3 = hv["position"] - c
		if ROOM.has(kind) and Vector2(hp0.x, hp0.z).length() < ROOM[kind][0] + 0.12 and hp0.y < ROOM[kind][1]:
			rays -= 1
			continue                      # (inside the rooms, through the open door: consoles, not the hull)
		if dc > dv + 0.3:
			leak += 1
			var tag := "h%.1f" % (Vector3(hv["position"]).y - c.y)
			where[tag] = int(where.get(tag, 0)) + 1
			if Game.cmd_arg("dbg", "") == "1":
				var hp: Vector3 = hv["position"]
				var dd: Vector3 = m.map.get("ufo_door", c)
				at.out("leak at %s r %.2f, door angle %.0f deg, game hit %s" % [(hp - c).snapped(Vector3.ONE * 0.01), Vector2(hp.x - c.x, hp.z - c.z).length(), rad_to_deg(Vector2(hp.x - c.x, hp.z - c.z).angle_to(Vector2(dd.x - c.x, dd.z - c.z))), str(hc.get("collider", null))])
	if leak > 0:
		at.out("ufohull leaks by height of the hit: %s" % str(where))
	# a merc walks up to the ship from 8 sides until something stops him; head inside the shell?
	var hug := 0
	var seen := 0
	var al: Node = null
	for a in m.aliens():
		al = a
		break
	var door: Vector3 = m.map.get("ufo_door", c)
	var door_dir := (door - c).normalized()
	for k in 8:
		var a := TAU * (k + 0.25) / 8.0
		var dir := Vector3(sin(a), 0, cos(a))
		if dir.dot(door_dir) > 0.8:
			continue                      # (the doorway is open on purpose)
		p.global_position = c + dir * rad + Vector3(0, 0.2, 0)
		p.velocity = Vector3.ZERO
		await at.get_tree().physics_frame
		for i in 120:
			p.velocity = -dir * 4.0
			p.move_and_slide()
			if Vector2(p.global_position.x - c.x, p.global_position.z - c.z).length() < 1.0:
				break
		var head: Vector3 = p.global_position + Vector3(0, 1.6, 0)
		if Game.cmd_arg("dbg", "") == "1":
			var hh := space.intersect_ray(PhysicsRayQueryParameters3D.create(p.global_position + Vector3(0, 0.6, 0), p.global_position + Vector3(0, 0.6, 0) - dir * 2.0, p.collision_mask))
			at.out("hug %d at r %.2f y %.2f blocked by %s" % [k, Vector2(p.global_position.x - c.x, p.global_position.z - c.z).length(), p.global_position.y - c.y, str(hh.get("collider", null)) + " " + (str(hh["collider"].get_path()) if hh else "")])
		# inside = a ray from the head straight out hits the shell from inside before anything else
		var hv := space.intersect_ray(PhysicsRayQueryParameters3D.create(head, head + dir * rad, LAYER))
		var near := 1e9 if hv.is_empty() else (Vector3(hv["position"]) - head).length()
		if near < 3.0:
			hug += 1
			at.out("ufohull hug %d: head %s inside the shell (%.2f m to its outer face)" % [k, head.snapped(Vector3.ONE * 0.01), near])
		# an alien off to the side (along the hull) must not see the head poking out of the shell
		if al:
			var side := Vector3(dir.z, 0, -dir.x)
			for sg in [-1.0, 1.0]:
				al.global_position = p.global_position + side * sg * 12.0 + dir * 1.5
				al.look_at(Vector3(head.x, al.global_position.y, head.z), Vector3.UP)
				al.alert = true
				await at.get_tree().physics_frame
				var eye: Vector3 = al.eye()
				var vis := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, head, LAYER))
				if al.visible_to(p) and not vis.is_empty():
					seen += 1
					at.out("ufohull seen %d: alien %s sees the merc's head %s through the shell" % [k, eye.snapped(Vector3.ONE * 0.1), head.snapped(Vector3.ONE * 0.1)])
	var bodies := 0
	for n in m.find_children("*", "StaticBody3D", true, false):
		for cs in (n as Node).get_children():
			if cs is CollisionShape3D and (cs as CollisionShape3D).shape is ConcavePolygonShape3D and (n as StaticBody3D).collision_layer & 1:
				var sh := (cs as CollisionShape3D).shape as ConcavePolygonShape3D
				if sh.get_faces().size() > 300 and (n as Node3D).global_position.distance_to(c) < 30.0:
					bodies += 1
	vb.queue_free()
	return {"kind": kind, "rays": rays, "leak": 100.0 * leak / maxf(rays, 1), "hug": hug, "seen": seen, "bodies": bodies}
