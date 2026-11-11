## 0.61: no flickering faces. Two blocks of different materials whose faces lie in the same plane
## (a shelf's end board flush with its back panel, a stripe flush with a wall, a door frame flush with
## the wall...) fight over which one the graphics card draws: the face shimmers as the camera moves.
## After a map or the base is built, every such pair is found and the smaller block is pushed out of
## the shared plane by a few millimetres (only its looks: the collision stays where it was).
## Works on everything built from blocks, the generators and the saved map tiles (dilky) alike.
extends RefCounted

const E := 0.0035          # faces closer than this count as one plane
const GROW := 0.006        # how far the smaller block steps out (unseen, but clear of the depth buffer)
const MIN_AREA := 0.0004   # overlaps smaller than 2 x 2 cm are not worth it
const CELL := 8.0

## Returns how many faces were moved. A block pushed out can meet a third one in its new plane,
## so it goes round again (a few rounds settle it).
static func fix(root: Node) -> int:
	var boxes := []        # [aabb, mesh instance, material id, volume, cylinder]
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not (mi.mesh is BoxMesh or mi.mesh is CylinderMesh) or not mi.is_visible_in_tree():
			continue
		if not _square(mi.global_transform.basis):
			continue
		var mat: Material = mi.material_override
		if mat == null:
			mat = (mi.mesh as PrimitiveMesh).material
		boxes.append([AABB(), mi, mat.get_instance_id() if mat else 0, 0.0, mi.mesh is CylinderMesh])
	var total := 0
	var changed := {}
	for round_i in 4:
		for b in boxes:
			var bb: AABB = (b[1] as MeshInstance3D).global_transform * (b[1] as MeshInstance3D).get_aabb()
			b[0] = bb
			b[3] = bb.size.x * bb.size.y * bb.size.z
		var moved := _pass(boxes, changed if round_i > 0 else {})
		total += moved.size()
		if moved.is_empty():
			break
		changed = moved
	return total

## One round: returns the blocks it moved (index -> true). With `only`, just pairs touching those.
static func _pass(boxes: Array, only: Dictionary) -> Dictionary:
	# faces sorted into buckets by direction, plane and place on the map
	var buckets := {}
	for i in boxes.size():
		var bb: AABB = boxes[i][0]
		for ax in 3:
			if boxes[i][4] and ax != 1:
				continue            # a cylinder: only its flat ends
			for sd in 2:
				var plane: float = bb.end[ax] if sd == 1 else bb.position[ax]
				if ax == 1 and sd == 0 and plane < 0.05:
					continue        # undersides on the ground are never seen
				var pk := int(round(plane / E))
				var u := (ax + 1) % 3
				var v := (ax + 2) % 3
				var hx := (u if u != 1 else v)       # a horizontal axis of the face, for the map cell
				for c in range(int(floor(bb.position[hx] / CELL)), int(floor(bb.end[hx] / CELL)) + 1):
					var k := Vector4i(ax, sd, pk, c)
					if not buckets.has(k):
						buckets[k] = []
					buckets[k].append(i)
	var grow := {}           # box index -> [neg Vector3, pos Vector3]
	var seen := {}
	for k in buckets:
		var ax: int = k.x
		var sd: int = k.y
		var lst: Array = buckets[k].duplicate()
		# the neighbouring plane bucket too (a plane right at a rounding edge)
		var k2 := Vector4i(ax, sd, k.z + 1, k.w)
		var other: Array = buckets.get(k2, [])
		var u := (ax + 1) % 3
		var v := (ax + 2) % 3
		for ai in lst.size():
			var cand := lst.slice(ai + 1) + other
			for bj in cand:
				var a: int = lst[ai]
				var b: int = bj
				if a == b or boxes[a][2] == boxes[b][2]:
					continue
				if not only.is_empty() and not only.has(a) and not only.has(b):
					continue
				var key := Vector4i(mini(a, b), maxi(a, b), ax, sd)
				if seen.has(key):
					continue
				seen[key] = true
				var A: AABB = boxes[a][0]
				var B: AABB = boxes[b][0]
				var pa: float = A.end[ax] if sd == 1 else A.position[ax]
				var pb: float = B.end[ax] if sd == 1 else B.position[ax]
				if absf(pa - pb) >= E:
					continue
				var ov := _ov(A.position[u], A.end[u], B.position[u], B.end[u]) * _ov(A.position[v], A.end[v], B.position[v], B.end[v])
				if ov < MIN_AREA:
					continue
				var small: int = a if boxes[a][3] <= boxes[b][3] else b
				if not grow.has(small):
					grow[small] = [Vector3.ZERO, Vector3.ZERO]
				grow[small][sd][ax] = GROW
	for i in grow:
		_apply(boxes[i][1], boxes[i][0], grow[i][0], grow[i][1])
		grow[i] = true
	return grow

static func _square(b: Basis) -> bool:
	# rotated only by whole right angles (any axis), so its faces are world planes
	var n := b.orthonormalized()
	for c in 3:
		var col := n[c]
		var m := maxf(absf(col.x), maxf(absf(col.y), absf(col.z)))
		if m < 0.9999:
			return false
	return true

static func _apply(mi: MeshInstance3D, bb: AABB, neg: Vector3, pos: Vector3) -> void:
	var gb := mi.global_transform.basis
	var shift := Vector3.ZERO
	for ax in 3:
		var add := neg[ax] + pos[ax]
		if add <= 0.0 or bb.size[ax] < 0.0001:
			continue
		# the local axis of the block that lies along this world axis
		var la := 0
		var best := 0.0
		for c in 3:
			var w := absf(gb[c].normalized()[ax])
			if w > best:
				best = w
				la = c
		var s := mi.scale
		s[la] *= (bb.size[ax] + add) / bb.size[ax]
		mi.scale = s
		shift[ax] = (pos[ax] - neg[ax]) / 2.0
	mi.global_position += shift

static func _ov(a0: float, a1: float, b0: float, b1: float) -> float:
	return maxf(0.0, minf(a1, b1) - maxf(a0, b0))
