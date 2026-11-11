extends RefCounted
## groundtest (0.62, Ari: „vetřelci občas propadnou do země, když je chodník vyšší“): vetřelci
## chodí po mapě (každé 4 s nový cíl, často na chodník, podlahu, schod), test každý snímek měří,
## jak hluboko jim nohy zajely pod to, co je vidět (vyvýšené plochy bez kolize: chodníky, podlahy)
## a pod to, o co se opravdu opírají (kolize). Na konci: kolik vyvýšených ploch nemá kolizi,
## kolik snímků byl vetřelec zabořený a nejhlubší zabořenost.
static var _flat: Array = []        # [AABB] raised walkable surfaces you can see
static var _bare := 0               # ... of them without collision under them
static var _n := 0
static var _sunk := 0
static var _deep := 0.0
static var _fell := 0
static var _next := 0.0
static var _climbs := 0
static var _was_low := {}

static func run(at: Node, p: Node) -> void:
	if p == null: return
	at._skip_brief()
	if not at.m().started(): return
	p.hp = 1.0e6
	var dur := float(Game.cmd_arg("dur", "60"))
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	if at.step == 0 and Game.cmd_arg("surf", "") == "1":
		# what the feet sound like on a grid over the map, by the old way (the textures) and now
		var hist := {}
		var sz: float = float(at.m().map.get("size", 60.0))
		var x := 1.5
		while x < sz:
			var z := 1.5
			while z < sz:
				var r := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 6, z), Vector3(x, -1, z), 1))
				if not r.is_empty() and float(r["position"].y) < 0.5:
					var sf := Game.surface_at(at.m(), r["position"], at.m().map)
					hist[sf] = int(hist.get(sf, 0)) + 1
				z += 3.0
			x += 3.0
		at.out("RESULT surftest %s" % [hist])
		at.get_tree().quit()
		return
	if at.step == 0:
		at.step = 1
		_t0 = at.t
		# the player out of the way, up high (the aliens do not hunt him)
		p.global_position = Vector3(-30, 30, -30)
		p.set_physics_process(false)
		for mi in at.m().find_children("*", "MeshInstance3D", true, false):
			var g := mi as MeshInstance3D
			if not (g.mesh is BoxMesh or g.mesh is CylinderMesh) or not g.is_visible_in_tree(): continue
			var b: AABB = g.global_transform * g.get_aabb()
			var top := b.end.y
			if b.position.y > 0.06 or top < 0.06 or top > 0.6 or b.size.x < 0.8 or b.size.z < 0.8: continue
			if b.size.x * b.size.z > 140.0: continue      # (the ground itself)
			_flat.append(b)
			# is there something solid under its top surface?
			var c := b.get_center()
			var q := PhysicsRayQueryParameters3D.create(Vector3(c.x, top + 0.5, c.z), Vector3(c.x, -1.0, c.z), 1)
			var h := space.intersect_ray(q)
			if h.is_empty() or float(h["position"].y) < top - 0.04:
				_bare += 1
				var mt: Material = g.material_override
				if Game.cmd_arg("list", "") == "1": at.out("[GROUND] bare top %.2f size %s at %s mat %s" % [top, b.size.snapped(Vector3.ONE * 0.01), c.snapped(Vector3.ONE * 0.1), mt.get_meta("tex", "") if mt else "-"])
		at.out("[GROUND] %d raised surfaces, %d without collision" % [_flat.size(), _bare])
		for a in at.m().aliens():
			a.set_meta("gt_hp", a.hp)
	var al: Array = at.m().aliens().filter(func(a): return not a.dead and not a.flying and not a.airborne)
	if at.t > _next and at.step == 1:
		_next = at.t + 4.0
		for a in al:
			a.hp = maxf(a.hp, 50.0)
			var tgt: Vector3
			if not _flat.is_empty() and randf() < 0.7:
				var b: AABB = _flat[randi() % _flat.size()]
				tgt = b.get_center()
			else:
				tgt = a.global_position + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10))
			a._go(a._snap(tgt))
	for a in (al if at.step == 1 else []):
		var pos: Vector3 = a.global_position
		_n += 1
		if pos.y < -0.4:
			_fell += 1
		var q := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.7, 0), pos - Vector3(0, 1.5, 0), 1)
		q.exclude = [a.get_rid()]
		var h := space.intersect_ray(q)
		var floor_y: float = float(h["position"].y) if not h.is_empty() else -1.0
		for b in _flat:
			if pos.x > b.position.x and pos.x < b.end.x and pos.z > b.position.z and pos.z < b.end.z:
				floor_y = maxf(floor_y, b.end.y)
		var d := floor_y - pos.y
		if d > 0.05:
			_sunk += 1
			_deep = maxf(_deep, d)
		# up a kerb: from low to on top of a raised surface
		var k: int = a.get_instance_id()
		var on_top := false
		for b in _flat:
			if pos.x > b.position.x and pos.x < b.end.x and pos.z > b.position.z and pos.z < b.end.z and pos.y > b.end.y - 0.04:
				on_top = true
		if on_top: _on += 1
		if _last.has(k): _moved += pos.distance_to(_last[k])
		_last[k] = pos
		if on_top and _was_low.get(k, false):
			_climbs += 1
		_was_low[k] = pos.y < 0.03 and not on_top
	if at.t - _t0 > dur and at.step == 1:
		at.step = 2
		_kerbs(at, p)
	if at.step == 3:
		at.out("RESULT groundtest %d raised, %d bare, samples %d, sunk %d (%.1f %%), deepest %.2f m, fell %d, climbs %d, on top %d, walked %.0f m, kerbs alien %d/%d merc %d/%d" % [_flat.size(), _bare, _n, _sunk, 100.0 * _sunk / maxf(1, _n), _deep, _fell, _climbs, _on, _moved, _k_al_ok, _k_al, _k_me_ok, _k_me])
		at.get_tree().quit()

static var _t0 := 0.0
static var _on := 0
static var _moved := 0.0
static var _last := {}

## Up a kerb on purpose: an alien and the merc next to raised surfaces, each walks onto it.
static var _k_al := 0
static var _k_al_ok := 0
static var _k_me := 0
static var _k_me_ok := 0
static func _kerbs(at: Node, p: Node) -> void:
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 1.8
	var al: Array = at.m().aliens().filter(func(a): return not a.dead and not a.R.has("hover") and not a.flying)
	p.set_physics_process(true)
	var tried := 0
	for b in _flat:
		var bb: AABB = b
		if bb.end.y < 0.09 or minf(bb.size.x, bb.size.z) < 1.2 or tried >= 8:
			continue
		var c := bb.get_center()
		var ax := Vector3(1, 0, 0) if bb.size.x < bb.size.z else Vector3(0, 0, 1)
		var half := (bb.size.x if bb.size.x < bb.size.z else bb.size.z) / 2.0
		for sgn in [-1.0, 1.0]:
			var s0: Vector3 = Vector3(c.x, 0.0, c.z) + ax * sgn * (half + 1.3)
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = cap
			q.collision_mask = 1 | 64 | 128
			q.transform = Transform3D(Basis.IDENTITY, s0 + Vector3(0, 1.05, 0))
			if not space.intersect_shape(q, 1).is_empty():
				continue
			var r := space.intersect_ray(PhysicsRayQueryParameters3D.create(s0 + Vector3(0, 0.5, 0), s0 - Vector3(0, 1, 0), 1))
			if r.is_empty() or absf(float(r["position"].y)) > 0.05:
				continue
			var goal := Vector3(c.x, bb.end.y, c.z)
			tried += 1
			# the alien
			if not al.is_empty():
				var a: Node = al[tried % al.size()]
				a.global_position = s0 + Vector3(0, 0.05, 0)
				a.velocity = Vector3.ZERO
				_k_al += 1
				var ok := false
				a.set_physics_process(false)      # walked by hand: the body, not the AI's decisions
				for f in 150:
					await at.get_tree().physics_frame
					var dv: Vector3 = goal - a.global_position
					dv.y = 0
					dv = dv.normalized() * 2.5
					a.velocity = Vector3(dv.x, a.velocity.y - 9.8 / 60.0 if not a.is_on_floor() else 0.0, dv.z)
					if a.has_method("_physics_process") and "StepUp" in a: a.StepUp.climb(a, 1.0 / 60.0, a.StepUp.ALIEN)
					a.move_and_slide()
					var ap: Vector3 = a.global_position
					if ap.y > bb.end.y - 0.04 and ap.x > bb.position.x and ap.x < bb.end.x and ap.z > bb.position.z and ap.z < bb.end.z:
						ok = true
						break
				if ok: _k_al_ok += 1
				else: at.out("[GROUND] alien %s stuck at kerb %.2f m near %s (at %s)" % [a.race, bb.end.y, c.snapped(Vector3.ONE * 0.1), a.global_position.snapped(Vector3.ONE * 0.01)])
				a.set_physics_process(true)
				a.global_position = Vector3(-40, 0.2, -40)
			# the merc
			var d: Vector3 = goal - s0
			d.y = 0
			p.global_position = s0 + Vector3(0, 0.05, 0)
			p.velocity = Vector3.ZERO
			p.rotation.y = atan2(-d.x, -d.z)
			for f in 5: await at.get_tree().physics_frame
			_k_me += 1
			Input.action_press("move_forward")
			var ok2 := false
			for f in 120:
				await at.get_tree().physics_frame
				var pp: Vector3 = p.global_position
				if pp.y > bb.end.y - 0.04 and pp.x > bb.position.x and pp.x < bb.end.x and pp.z > bb.position.z and pp.z < bb.end.z:
					ok2 = true
					break
			Input.action_release("move_forward")
			if ok2: _k_me_ok += 1
			else: at.out("[GROUND] merc stuck at kerb %.2f m near %s (at %s)" % [bb.end.y, c.snapped(Vector3.ONE * 0.1), p.global_position.snapped(Vector3.ONE * 0.01)])
			break
	at.out("[GROUND] kerbs: alien %d/%d, merc %d/%d" % [_k_al_ok, _k_al, _k_me_ok, _k_me])
	at.step = 3
