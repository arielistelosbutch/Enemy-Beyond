extends RefCounted
## overlaptest (2026-11-27, Ari: „mrkni i na to, aby se modely nepřekrývaly, auta v sobě atd.“):
## projde postavenou mapu fyzikou – každý model (auto, bedna, traktor, strom…) se svou kolizí
## zeptá, do čeho zajíždí, a změří hloubku průniku. Nepočítá se, co stojí na podlaze/zemi/chodníku
## (průnik jen pod 0,3 m) ani dotek do 0,12 m.
## --overlapmaps=<biom:terén:seed,...> projde víc map za sebou (mise se nahraje znovu).
## Výsledek: RESULT overlaptest props P pairs X prop_prop A prop_wall B worst <hloubka>

const DEEP := 0.12        # deeper than this = they stand inside each other
const FLOOR_Y := 0.3      # contacts only below this = feet / wheels in the floor, a slab, the ground

static func _owner(n: Node, root: Node) -> Node:
	while n and n != root:
		if n.has_meta("model") and String(n.get_meta("model")).begins_with("v_"):
			return n
		n = n.get_parent()
	return null

static func _name(n: Node) -> String:
	if n == null:
		return "?"
	if n.has_meta("model"):
		return String(n.get_meta("model"))
	return String(n.name)

static func scan(at: Node) -> Dictionary:
	var mroot: Node = at.m()
	var space: PhysicsDirectSpaceState3D = mroot.get_world_3d().direct_space_state
	var props := []
	for n in mroot.find_children("*", "Node3D", true, false):
		if n.has_meta("model") and String(n.get_meta("model")).begins_with("v_") and _owner(n.get_parent(), mroot) == null:
			props.append(n)
	var pairs := {}
	var pp := 0
	var pw := 0
	var worst := 0.0
	var lines := []
	var nq := 0
	var nh := 0
	for a in props:
		var mine := []
		for sb in (a as Node).find_children("*", "CollisionObject3D", true, false):
			mine.append((sb as CollisionObject3D).get_rid())
		if a is CollisionObject3D:
			mine.append((a as CollisionObject3D).get_rid())
		for cs in (a as Node).find_children("*", "CollisionShape3D", true, false):
			var sh: Shape3D = (cs as CollisionShape3D).shape
			if sh == null or sh is ConcavePolygonShape3D or (cs as CollisionShape3D).disabled:
				continue
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = sh
			q.transform = (cs as CollisionShape3D).global_transform
			q.collision_mask = Game.WORLD
			q.exclude = mine
			var hits := space.intersect_shape(q, 24)
			nq += 1
			nh += hits.size()
			var rids := []
			for h in hits:
				rids.append(h.rid)
			for h in hits:
				var other: Node = h.collider
				var ob := _owner(other, mroot)
				if ob == a:
					continue
				if ob and _name(a).begins_with("v_tree") and _name(ob).begins_with("v_tree"):
					continue       # (two trees grown together in a wood: as in a real wood)
				var key := "%d|%d" % [a.get_instance_id(), (ob if ob else other).get_instance_id()]
				var key2 := "%d|%d" % [(ob if ob else other).get_instance_id(), a.get_instance_id()]
				if pairs.has(key) or pairs.has(key2):
					continue
				var q2 := PhysicsShapeQueryParameters3D.new()
				q2.shape = sh
				q2.transform = q.transform
				q2.collision_mask = Game.WORLD
				q2.exclude = mine + rids.filter(func(r): return r != h.rid)
				var pts := space.collide_shape(q2, 16)
				var depth := 0.0
				var high := false
				var where := Vector3.ZERO
				for i in range(0, pts.size() - 1, 2):
					var d: float = (pts[i] as Vector3).distance_to(pts[i + 1])
					var y: float = maxf((pts[i] as Vector3).y, (pts[i + 1] as Vector3).y)
					if y >= FLOOR_Y:
						high = true
						if d > depth:
							depth = d
							where = pts[i]
				if not high or depth < DEEP:
					continue
				pairs[key] = depth
				worst = maxf(worst, depth)
				if ob:
					pp += 1
				else:
					pw += 1
				lines.append([depth, "%s ~ %s  hloubka %.2f m  u %s" % [_name(a), _name(ob) if ob else "stavba " + _name(other) + " (" + str(other.get_parent().name) + ")", depth, str(where.snapped(Vector3.ONE * 0.1))]])
	lines.sort_custom(func(x, y): return x[0] > y[0])
	at.out("[OVERLAP] dotazů %d, zásahů %d" % [nq, nh])
	return {"props": props.size(), "pairs": pairs.size(), "pp": pp, "pw": pw, "worst": worst, "lines": lines}


# ---- what you see: the solid-looking things (cars, wrecks, tractors, crates...) against every
# visible box and every other model, by their oriented boxes (no collision needed) ----------------
const SOLID := ["v_car", "v_humvee", "v_truck", "v_tractor", "v_forklift", "v_snowmobile", "v_mil_crates", "v_woodpile",
	"v_trough", "v_bench", "v_well", "v_coop", "v_silo", "v_drum", "v_bus_stop", "v_workbench", "v_hay_bale", "v_pallet", "v_litter_bin"]
const SKIP := ["v_tree", "v_bush", "v_reeds", "v_dune", "v_crater", "v_debris", "v_rubble", "v_flower_bed", "v_laundry",
	"v_wire_fence", "v_barbed_fence", "v_broken_fence", "v_pole", "v_railing", "v_window", "v_house_roof", "v_alien", "v_cactus", "v_dead_tree", "v_fallen_signal"]

static func _is(nm: String, lst: Array) -> bool:
	for k in lst:
		if nm.begins_with(k):
			return true
	return false

## The oriented box of all meshes under @a n (in n's space -> world basis, centre, half sizes).
static func _obb(n: Node3D) -> Array:
	var inv := n.global_transform.affine_inverse()
	var bb := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		if not (mi as MeshInstance3D).visible or (mi as MeshInstance3D).mesh == null:
			continue
		var b: AABB = (inv * (mi as MeshInstance3D).global_transform) * (mi as MeshInstance3D).get_aabb()
		bb = b if first else bb.merge(b)
		first = false
	if first:
		return []
	var x := n.global_transform
	return [x.basis, x * bb.get_center(), bb.size / 2.0]

static func _box_obb(mi: MeshInstance3D) -> Array:
	var b: AABB = mi.get_aabb()
	var x := mi.global_transform
	return [x.basis, x * b.get_center(), b.size / 2.0]

## Separating axes: how deep two oriented boxes go into each other (0 = apart).
static func _sat(a: Array, b: Array) -> float:
	var ax: Array = []
	for i in 3:
		ax.append((a[0] as Basis)[i].normalized())
		ax.append((b[0] as Basis)[i].normalized())
	var depth := 1.0e9
	var d: Vector3 = b[1] - a[1]
	for v in ax:
		var ra := 0.0
		var rb := 0.0
		for i in 3:
			ra += absf((a[0] as Basis)[i].normalized().dot(v)) * (a[2] as Vector3)[i] * (a[0] as Basis)[i].length()
			rb += absf((b[0] as Basis)[i].normalized().dot(v)) * (b[2] as Vector3)[i] * (b[0] as Basis)[i].length()
		var o := ra + rb - absf(d.dot(v))
		if o <= 0.0:
			return 0.0
		depth = minf(depth, o)
	return depth

static func _ybot_top(o: Array) -> Vector2:
	var h := 0.0
	for i in 3:
		h += absf((o[0] as Basis)[i].y) * (o[2] as Vector3)[i]
	return Vector2((o[1] as Vector3).y - h, (o[1] as Vector3).y + h)

static func visual(at: Node) -> Dictionary:
	var mroot: Node = at.m()
	var solid := []
	var others := []
	for n in mroot.find_children("*", "Node3D", true, false):
		if not n.has_meta("model"):
			continue
		var nm := String(n.get_meta("model"))
		if not nm.begins_with("v_") or _owner(n.get_parent(), mroot) != null:
			continue
		var o := _obb(n)
		if o.is_empty():
			continue
		if _is(nm, SOLID):
			solid.append([n, o, nm])
		elif not _is(nm, SKIP):
			others.append([n, o, nm])
	var boxes := []
	for mi in mroot.find_children("*", "MeshInstance3D", true, false):
		if not (mi as MeshInstance3D).mesh is BoxMesh or not (mi as MeshInstance3D).visible or _owner(mi, mroot) != null:
			continue
		var o := _box_obb(mi)
		var yt := _ybot_top(o)
		if yt.y < 0.35 or (o[2] as Vector3).length() < 0.05:
			continue       # the ground, floors, kerbs, rugs
		var mat = (mi as MeshInstance3D).material_override
		if mat is BaseMaterial3D and (mat as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			continue
		var tex := String(mat.get_meta("tex", "")) if mat else ""
		boxes.append([mi, o, "krabice %s %s" % [tex, str(((mi as MeshInstance3D).mesh as BoxMesh).size.snapped(Vector3.ONE * 0.01))]])
	var found := []
	for i in solid.size():
		var A: Array = solid[i]
		var ya := _ybot_top(A[1])
		for B in solid.slice(i + 1) + others + boxes:
			if B[0] == A[0] or (B[0] as Node).is_ancestor_of(A[0]) or (A[0] as Node).is_ancestor_of(B[0]):
				continue
			if ((A[1][1] as Vector3) - (B[1][1] as Vector3)).length() > (A[1][2] as Vector3).length() + (B[1][2] as Vector3).length():
				continue
			var yb := _ybot_top(B[1])
			var yo := minf(ya.y, yb.y) - maxf(ya.x, yb.x)
			if yo < 0.25:
				continue        # on top of it / under it (a crate on a pallet, a thing on a shelf)
			var d := _sat(A[1], B[1])
			if d > 0.18:
				found.append([d, "%s ~ %s  %.2f m  u %s" % [A[2], B[2], d, str((A[1][1] as Vector3).snapped(Vector3.ONE * 0.1))], ((A[1][1] as Vector3) + (B[1][1] as Vector3)) / 2.0])
	# the ship itself (a crashed UFO on the parked cars, in a house)
	var ufo = mroot.map.get("ufo", null)
	if ufo is Vector3 and String(mroot.map.get("ufo_kind", "")) in ["scout", "raider", "harvester"]:
		var r: float = mroot._ship_r() * 0.85
		for B in solid + others:
			var c: Vector3 = B[1][1]
			var d := Vector2(c.x - ufo.x, c.z - ufo.z).length()
			if d < r and _ybot_top(B[1]).x < (ufo as Vector3).y + 2.0:
				found.append([r - d, "UFO ~ %s  %.2f m od středu  u %s" % [B[2], d, str(c.snapped(Vector3.ONE * 0.1))], c])
	found.sort_custom(func(x, y): return x[0] > y[0])
	return {"n": found.size(), "lines": found, "solid": solid.size()}

static func run(at: Node, p: Node) -> void:
	if p == null: return
	at._skip_brief()
	if at.step > 0 or not at.m().started(): return
	at.step = 1
	p.hp = 1.0e6
	await at.get_tree().create_timer(0.6).timeout
	if Game.cmd_arg("overlapself", "") == "1":
		# the detector itself: a car driven into another one must be found
		for c in at.m().find_children("*", "Node3D", true, false):
			if String(c.get_meta("model", "")).begins_with("v_car"):
				var twin: Node3D = Game.model("v_car_blue")
				c.get_parent().add_child(twin)
				twin.global_transform = (c as Node3D).global_transform.translated(Vector3(0.9, 0, 0.6))
				preload("res://scripts/fit_collision.gd").fit(twin)
				break
		await at.get_tree().physics_frame
		await at.get_tree().physics_frame
	var r := scan(at)
	for l in r["lines"].slice(0, 40):
		at.out("[OVERLAP] " + String(l[1]))
	var v := visual(at)
	for l in v["lines"].slice(0, 40):
		at.out("[SEEN] " + String(l[1]))
	if Game.cmd_arg("overlapsnap", "") == "1" and DisplayServer.get_name() != "headless":
		# a look at the first few: the camera 5 m off, at the middle of the pair
		var cam := Camera3D.new()
		at.m().add_child(cam)
		cam.make_current()
		for cl in at.get_tree().root.find_children("*", "CanvasLayer", true, false):
			(cl as CanvasLayer).visible = false
		var env := at.get_viewport().world_3d.environment if at.get_viewport().world_3d else null
		if env:
			env.fog_enabled = false
			env.volumetric_fog_enabled = false
		var k := 0
		for l in v["lines"].slice(0, 6):
			var c: Vector3 = l[2]
			cam.global_position = c + Vector3(2.5, 4.5, 2.5)
			cam.look_at(c)
			for f in 4:
				await RenderingServer.frame_post_draw
			at.get_viewport().get_texture().get_image().save_png("user://overlap_%d.png" % k)
			k += 1
	at.out("RESULT overlaptest props %d pairs %d prop_prop %d prop_wall %d worst %.2f seen %d of %d" % [r["props"], r["pairs"], r["pp"], r["pw"], r["worst"], v["n"], v["solid"]])
	at.get_tree().quit()
