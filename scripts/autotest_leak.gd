extends RefCounted
## 0.69 (Ari: „kameny pořád protékají“): kudy jde projít něčím, co vypadá pevně.
## --autotest=leaktest [--biome=... --mtype=...]: každý model na mapě (kameny, led, krápníky,
## skály základny vetřelců...) a každá krabice bez kolize, která vypadá jako kámen: vodorovné
## paprsky ze všech stran ve výšce kolen až hlavy. „Díra“ = paprsek, který viditelný povrch
## protne, ale kolize (Game.WORLD) ho nezastaví do 0,3 m za ním - tudy voják projde.
## RESULT leaktest <biome> props N rays R leak X % (worst: model leak% ...)

const LAYER := 1 << 20
## models that are meant to be walked through (grass, bushes, crowns, cloth...)
const SOFT := ["grass", "bush", "fern", "flower", "reed", "hay", "wheat", "corn", "crop", "leaves", "ivy", "vine", "web", "curtain", "flag", "rug", "carpet", "puddle", "blood", "decal", "scorch", "smoke", "fire", "light", "lamp", "shadow", "water", "sign", "wire", "chain", "rope", "cable"]

static func run(at: Node, p: Node) -> void:
	if p == null or at.step > 0:
		return
	at._skip_brief()
	var m: Node = at.m()
	if not m.go and not m.started():
		return
	at.step = 1
	for a in m.aliens():
		a.set_physics_process(false)
	await at.get_tree().create_timer(1.0).timeout
	var res := await check(at, p)
	at.out("RESULT %s %s props %d rays %d leak %.1f %% stone_leak %.1f %% (worst: %s)" % [Game.autotest(), Game.cmd_arg("biome", "?"), res["props"], res["rays"], res["leak"], res["stone"], res["worst"]])
	if Game.autotest() in ["leakhost", "leakclient"]:
		await at.get_tree().create_timer(4.0).timeout     # (the other side finishes too)
	at.get_tree().quit()

static func _soft(name: String) -> bool:
	var l := name.to_lower()
	for s in SOFT:
		if s in l:
			return true
	return false

static func check(at: Node, p: Node) -> Dictionary:
	var m: Node = at.m()
	var items := []      # [label, [MeshInstance3D...], centre node]
	for n in m.find_children("*", "Node3D", true, false):
		var mn := String(n.get_meta("model", ""))
		if mn == "" or _soft(mn) or n.has_meta("nocol"):
			continue
		var mis := []
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).is_visible_in_tree() and (mi as MeshInstance3D).mesh != null:
				mis.append(mi)
		if not mis.is_empty():
			items.append([mn, mis, n])
	# rock-looking boxes and cylinders (alien rock walls, stalagmites, cliffs): by material
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var mat: Material = (mi as MeshInstance3D).material_override
		if mat == null or not (mi as MeshInstance3D).is_visible_in_tree():
			continue
		var tex := String(mat.get_meta("tex", "")) + String(mat.resource_name)
		if "rock" in tex.to_lower() or "stone" in tex.to_lower() or "cliff" in tex.to_lower():
			var par: Node = mi.get_parent()
			var skip := false
			while par != null and par != m:
				if String(par.get_meta("model", "")) != "":
					skip = true
					break
				par = par.get_parent()
			if not skip:
				items.append(["box:" + tex, [mi], mi])
	var vbs := []
	for it in items:
		var vb := StaticBody3D.new()
		vb.collision_layer = LAYER
		vb.collision_mask = 0
		m.add_child(vb)
		vbs.append(vb)
		it.append(vb)
		for mi in it[1]:
			var sh: ConcavePolygonShape3D = (mi as MeshInstance3D).mesh.create_trimesh_shape()
			if sh == null:
				continue
			sh.backface_collision = true
			var cs := CollisionShape3D.new()
			cs.shape = sh
			vb.add_child(cs)
			cs.global_transform = (mi as MeshInstance3D).global_transform
	for f in 3:
		await at.get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var per := {}
	var rays := 0
	var leaks := 0
	var srays := 0
	var sleaks := 0
	var shown := 0
	for it in items:
		var label: String = it[0]
		var bb := AABB()
		var first := true
		for mi in it[1]:
			var b: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			bb = b if first else bb.merge(b)
			first = false
		if maxf(bb.size.x, bb.size.z) < 0.3 or bb.size.y < 0.3:
			continue
		var c := bb.get_center()
		var rad := Vector2(bb.size.x, bb.size.z).length() / 2.0 + 0.6
		var ground: float = bb.position.y
		var is_stone: bool = (it[2] as Node).has_meta("stone") or label.begins_with("box:") or "rock" in label or "spire" in label or "shard" in label
		for k in 16:
			var a := TAU * k / 16.0
			for hy in [0.35, 0.7, 1.1, 1.6]:
				var y: float = maxf(ground, (it[2] as Node3D).global_position.y) + hy
				if y > bb.end.y - 0.05:
					continue
				var from := Vector3(c.x + sin(a) * rad, y, c.z + cos(a) * rad)
				var to := Vector3(c.x - sin(a) * rad, y, c.z - cos(a) * rad)
				var qv := PhysicsRayQueryParameters3D.create(from, to, LAYER)
				var hv := space.intersect_ray(qv)
				if hv.is_empty() or hv["collider"] != it[3]:
					continue
				# only rays that meet THIS item's visible surface first
				var dv: float = (Vector3(hv["position"]) - from).length()
				var q := PhysicsRayQueryParameters3D.create(from, to, Game.WORLD)
				var hc := space.intersect_ray(q)
				var dc: float = 99.0 if hc.is_empty() else (Vector3(hc["position"]) - from).length()
				if dc < dv - 0.3:
					continue          # something else stands in front of it
				rays += 1
				if not per.has(label):
					per[label] = [0, 0]
				per[label][0] += 1
				if is_stone:
					srays += 1
				if dc > dv + 0.3:
					leaks += 1
					per[label][1] += 1
					if is_stone:
						sleaks += 1
						if shown < 12 and Game.cmd_arg("leakdebug", "") == "1":
							shown += 1
							at.out("  leak %s at %s: visible %.2f, stops %.2f, hit %s" % [label, Vector3(hv["position"]).snapped(Vector3.ONE * 0.01), dv, dc, "nic" if hc.is_empty() else String((hc["collider"] as Node).get_path()).right(60)])
	var worst := []
	for lb in per:
		if per[lb][1] > 0:
			worst.append([lb, 100.0 * per[lb][1] / per[lb][0], per[lb][0]])
	worst.sort_custom(func(x, y): return x[1] * x[2] > y[1] * y[2])
	var ws := ""
	for w in worst.slice(0, 10):
		ws += "%s %.0f%%/%d, " % [w[0], w[1], w[2]]
	for vb in vbs:
		(vb as Node).queue_free()
	return {"props": items.size(), "rays": rays, "leak": 100.0 * leaks / maxf(rays, 1), "stone": 100.0 * sleaks / maxf(srays, 1), "worst": ws}
