extends RefCounted
## 0.61: the collision of a prop model follows what you can see.
## The models came from Blender with boxes ("-colonly") imported as hollow trimeshes; a box is
## often wider or taller than the thing (a log, a fence, a tree trunk, a car's rounded nose):
## a bullet stopped in thin air ("I shoot into a wall and do not know it") and a merc bumped
## into nothing. Now each separate piece of the visible model (a post, a plank, a wheel, a log)
## gets its own convex hull - but only the pieces the old boxes were meant for (a piece whose
## part inside one of them; a piece sticking out keeps only that part), so a tree's crown or a
## scarecrow's hat stay as they were (no collision). Breakable / per-part bodies keep their pieces (each piece goes to
## the body whose box held it). Built once per model and cached.

static var _cache := {}
const SLICE := 0.6            # m: tall pieces are cut into slices this high
const MAX_PIECES := 160       # more than this (grass, chains...): keep the old boxes

## Refits the collision of @a n (a model instance, before it is scaled or moved - the shapes
## are in the model's own space, so scaling the node later scales them too).
static func fit(n: Node3D) -> void:
	var key := String(n.get_meta("model", ""))
	if key == "":
		return
	var bodies: Array = n.find_children("*", "StaticBody3D", true, false)
	if bodies.is_empty():
		return
	if not _cache.has(key):
		_cache[key] = _build(n, bodies)
	var plan: Array = _cache[key]
	if plan.is_empty():
		return          # (nothing better found: the old boxes stay)
	for sb in bodies:
		for c in (sb as Node).get_children():
			if c is CollisionShape3D:
				sb.remove_child(c)
				c.free()
	for e in plan:
		var sb: StaticBody3D = bodies[int(e["b"])]
		var cs := CollisionShape3D.new()
		cs.shape = e["shape"]
		cs.transform = e["xf"]
		sb.add_child(cs)

## [{b: body index, shape, xf: the shape's transform in the body}] or [] = keep as it is.
static func _build(n: Node3D, bodies: Array) -> Array:
	# the old boxes, in the model's space
	var boxes := []        # [body index, AABB]
	for bi in bodies.size():
		var sb: Node3D = bodies[bi]
		for c in sb.get_children():
			if c is CollisionShape3D and (c as CollisionShape3D).shape != null:
				var dm: Mesh = (c as CollisionShape3D).shape.get_debug_mesh()
				if dm == null:
					continue
				boxes.append([bi, rel(c, n) * dm.get_aabb()])
	if boxes.is_empty():
		return []
	# the visible pieces: triangles joined through shared corners (welded by position)
	var pieces := []       # PackedVector3Array per piece, in the model's space
	var piece_tris := []   # its triangles (for cutting it to a box)
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		if not (mi as MeshInstance3D).visible or (mi as MeshInstance3D).mesh == null:
			continue
		var xf := rel(mi, n)
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		for sf in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(sf)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if idx.is_empty():
				idx.resize(verts.size())
				for i in verts.size():
					idx[i] = i
			var weld := {}
			var wid := PackedInt32Array()
			wid.resize(verts.size())
			for i in verts.size():
				var k := verts[i].snapped(Vector3.ONE * 0.0005)
				if not weld.has(k):
					weld[k] = weld.size()
				wid[i] = weld[k]
			var par := PackedInt32Array()
			par.resize(weld.size())
			for i in par.size():
				par[i] = i
			for t in range(0, idx.size() - 2, 3):
				var a := _root(par, wid[idx[t]])
				for j in [1, 2]:
					var b := _root(par, wid[idx[t + j]])
					if a != b:
						par[b] = a
			var groups := {}
			var tris := {}
			for i in verts.size():
				var r := _root(par, wid[i])
				if not groups.has(r):
					groups[r] = []
					tris[r] = []
				(groups[r] as Array).append(xf * verts[i])
			for t in range(0, idx.size() - 2, 3):
				var r := _root(par, wid[idx[t]])
				(tris[r] as Array).append([xf * verts[idx[t]], xf * verts[idx[t + 1]], xf * verts[idx[t + 2]]])
			for r in groups:
				pieces.append(PackedVector3Array(groups[r]))
				piece_tris.append(tris[r])
	# tall pieces (a bent trunk, a zigzag wire, a knobbly spire) in slices: one hull for the whole
	# would fill the air beside the bends
	var n0 := pieces.size()
	for pi in n0:
		var pts0: PackedVector3Array = pieces[pi]
		if pts0.size() < 3:
			continue
		var lo := INF
		var hi := -INF
		for v in pts0:
			lo = minf(lo, v.y)
			hi = maxf(hi, v.y)
		if hi - lo < SLICE * 2.0:
			continue
		var nb := ceili((hi - lo) / SLICE)
		var step := (hi - lo) / nb
		for k in nb:
			var y0 := lo + step * k
			var y1 := y0 + step
			var band := PackedVector3Array()
			for v in pts0:
				if v.y >= y0 - 0.001 and v.y <= y1 + 0.001:
					band.append(v)
			for t in piece_tris[pi]:
				for e in 3:
					var a: Vector3 = t[e]
					var b: Vector3 = t[(e + 1) % 3]
					for yc in [y0, y1]:
						if (a.y - yc) * (b.y - yc) < 0.0:
							band.append(a.lerp(b, (yc - a.y) / (b.y - a.y)))
			if band.size() >= 4:
				pieces.append(band)
				piece_tris.append(null)      # (a slice: cut to a box only by squeezing)
		pieces[pi] = PackedVector3Array()    # (replaced by its slices)
	var plan := []
	for pi in pieces.size():
		var pts: PackedVector3Array = pieces[pi]
		if pts.size() < 3:
			continue
		var bb := AABB((pts as PackedVector3Array)[0], Vector3.ZERO)
		for v in pts:
			bb = bb.expand(v)
		# the old box it belongs to: the one that holds most of it
		var owner := -1
		var obox := AABB()
		var best := 0.0
		for b in boxes:
			var ab: AABB = (b[1] as AABB).grow(0.05)
			if not ab.intersects(bb):
				continue
			var cut := ab.intersection(bb)
			var share := cut.size.x * cut.size.y * cut.size.z + (1000.0 if ab.has_point(bb.get_center()) else 0.0)
			if owner < 0 or share > best:
				owner = int(b[0])
				obox = ab
				best = share
		if owner < 0:
			continue          # (not something the model was meant to stop: a crown, a hat)
		var vol := maxf(bb.size.x, 0.01) * maxf(bb.size.y, 0.01) * maxf(bb.size.z, 0.01)
		var cut := obox.intersection(bb)
		var in_vol := maxf(cut.size.x, 0.01) * maxf(cut.size.y, 0.01) * maxf(cut.size.z, 0.01)
		if not obox.encloses(bb) and in_vol < vol * 0.6:
			# sticking well out of its box (a branch off the trunk, a tower's leg): only the part
			# that was solid before stays solid - the piece cut by the box
			var inside := PackedVector3Array()
			if piece_tris[pi] == null:
				for v in pts:
					inside.append(v.clamp(obox.position, obox.end))
			else:
				inside = _cut(pts, piece_tris[pi], obox)
			if inside.size() < 4:
				continue
			pts = inside
			bb = AABB(pts[0], Vector3.ZERO)
			for v in pts:
				bb = bb.expand(v)
		var p2: PackedVector3Array = pts
		# a flat piece (a sign, a plank face): a little thickness, or the hull falls apart
		for ax in 3:
			if bb.size[ax] < 0.02:
				var off := Vector3.ZERO
				off[ax] = 0.015
				var thick := PackedVector3Array()
				for v in p2:
					thick.append(v + off)
					thick.append(v - off)
				p2 = thick
		var sh := ConvexPolygonShape3D.new()
		sh.points = p2
		plan.append({"b": owner, "shape": sh, "xf": rel(bodies[owner], n).affine_inverse()})
	if plan.is_empty() or plan.size() > MAX_PIECES:
		return []
	return plan

## The convex piece @a pts (triangles @a tris) cut by the box @a box: the corners of what is left.
static func _cut(pts: PackedVector3Array, tris: Array, box: AABB) -> PackedVector3Array:
	var mid := Vector3.ZERO
	for v in pts:
		mid += v
	mid /= float(pts.size())
	var planes: Array[Plane] = []
	var seen := {}
	for t in tris:
		var a: Vector3 = t[0]
		var nrm: Vector3 = (t[1] - a).cross(t[2] - a)
		if nrm.length() < 1e-9:
			continue
		var pl := Plane(nrm.normalized(), a)
		if pl.distance_to(mid) > 0.0:
			pl = -pl          # (facing out of the piece)
		var k := "%.3f %.3f %.3f %.3f" % [pl.normal.x, pl.normal.y, pl.normal.z, pl.d]
		if not seen.has(k):
			seen[k] = true
			planes.append(pl)
	if planes.size() > 160:
		var sq := PackedVector3Array()     # (too round to cut exactly: squeezed into the box)
		for v in pts:
			sq.append(v.clamp(box.position, box.end))
		return sq
	planes.append(Plane(Vector3.RIGHT, box.end.x))
	planes.append(Plane(Vector3.LEFT, -box.position.x))
	planes.append(Plane(Vector3.UP, box.end.y))
	planes.append(Plane(Vector3.DOWN, -box.position.y))
	planes.append(Plane(Vector3.BACK, box.end.z))
	planes.append(Plane(Vector3.FORWARD, -box.position.z))
	return Geometry3D.compute_convex_mesh_points(planes)

static func _root(par: PackedInt32Array, i: int) -> int:
	while par[i] != i:
		par[i] = par[par[i]]
		i = par[i]
	return i

## The transform of @a a in the space of @a top (a's ancestor).
static func rel(a: Node3D, top: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var x: Node = a
	while x != null and x != top:
		if x is Node3D:
			xf = (x as Node3D).transform * xf
		x = x.get_parent()
	return xf
