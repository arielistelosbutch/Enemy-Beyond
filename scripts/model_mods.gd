class_name ModelMods
## The block modeller's changes to a model: every model in the game is made of blocks, cylinders
## and balls, so each mesh is split back into those pieces ("parts"); a part can be moved, turned,
## stretched, recoloured or removed, and new blocks can be added. Rigged models stay rigged: a part
## keeps the bone it was bound to, a new part takes the bone it is given.
##
## Mods (one JSON per model): {"parts": {"<Piece>:<n>": {"xf": [px,py,pz, rx,ry,rz (deg), sx,sy,sz],
##   "color": [r,g,b], "del": true}}, "new": [{"piece": "<Piece>", "shape": "box|cyl|ball",
##   "xf": [...], "color": [r,g,b], "bone": "<bone>"}]}
## A part's xf is applied around its own centre; a new part's xf places a unit shape (size = scale).

static var _cache := {}       # mesh rid -> Array of islands

## Splits a mesh into its blocks: [{surf, tris: PackedInt32Array (vertex indices, 3 per triangle),
## center: Vector3, box: AABB}]. Triangles of one block come one after another and touch each other.
static func islands(mesh: Mesh) -> Array:
	var key := mesh.get_rid().get_id()
	if _cache.has(key):
		return _cache[key]
	var out := []
	for s in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(v.size()))
		var cur: Dictionary = {}
		var tris := PackedInt32Array()
		for t in range(0, idx.size(), 3):
			var keys := []
			var touches := false
			for k in 3:
				var p := v[idx[t + k]]
				var kk := Vector3i(roundi(p.x * 10000.0), roundi(p.y * 10000.0), roundi(p.z * 10000.0))
				keys.append(kk)
				if cur.has(kk):
					touches = true
			if not touches and tris.size() > 0:
				out.append(_island(s, tris, v))
				cur = {}
				tris = PackedInt32Array()
			for kk in keys:
				cur[kk] = true
			tris.append_array([idx[t], idx[t + 1], idx[t + 2]])
		if tris.size() > 0:
			out.append(_island(s, tris, v))
	_cache[key] = out
	return out

static func _island(s: int, tris: PackedInt32Array, v: PackedVector3Array) -> Dictionary:
	var box := AABB(v[tris[0]], Vector3.ZERO)
	for i in tris:
		box = box.expand(v[i])
	return {"surf": s, "tris": tris, "center": box.get_center(), "box": box}

static func xf_basis(xf: Array) -> Basis:
	var r := Vector3(float(xf[3]), float(xf[4]), float(xf[5])) * (PI / 180.0)
	return Basis.from_euler(r) * Basis.from_scale(Vector3(float(xf[6]), float(xf[7]), float(xf[8])))

static func xf_pos(xf: Array) -> Vector3:
	return Vector3(float(xf[0]), float(xf[1]), float(xf[2]))

const IDENT := [0, 0, 0, 0, 0, 0, 1, 1, 1]

## Applies the mods to every mesh of an instanced model (before it is restyled).
static func apply(root: Node, mods: Dictionary) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var piece := String(mi.name)
		var touched := false
		for k in mods.get("parts", {}):
			if String(k).begins_with(piece + ":"):
				touched = true
				break
		for np in mods.get("new", []):
			if String(np.get("piece", "")) == piece:
				touched = true
		if touched or mods.get("_all", false):
			rebuild(mi, mods)

## Rebuilds one mesh with the changes. Leaves a list of the parts (for picking) in the meta "eb_parts".
static func rebuild(mi: MeshInstance3D, mods: Dictionary) -> void:
	var src: Mesh = mi.get_meta("eb_src") if mi.has_meta("eb_src") else mi.mesh
	mi.set_meta("eb_src", src)
	var piece := String(mi.name)
	var isl := islands(src)
	var skel: Skeleton3D = mi.get_node_or_null(mi.skeleton) if mi.skin else null
	var arrays := []
	for s in src.get_surface_count():
		arrays.append(src.surface_get_arrays(s))
	var surfs := {}        # "s|color" -> {mat, v, n, b, w}
	var picks := []
	var pm: Dictionary = mods.get("parts", {})
	var sl := _slices(src, isl, arrays)
	if skel and mi.skin and not sl.is_empty() and not sl[0].has("bone_set"):
		for d in sl:
			d["bone_set"] = true
			var bi: int = (d["b"] as PackedInt32Array)[0] if (d["b"] as PackedInt32Array).size() > 0 else -1
			if bi >= 0 and bi < mi.skin.get_bind_count():
				var bn := mi.skin.get_bind_name(bi)
				if bn == "" and mi.skin.get_bind_bone(bi) >= 0:
					bn = skel.get_bone_name(mi.skin.get_bind_bone(bi))
				d["bone"] = String(bn)
	var ids := _ids_for(piece, isl.size())
	var empty := {}
	for i in isl.size():
		var id: String = ids[i]
		var m: Dictionary = pm.get(id, empty) if not pm.is_empty() else empty
		if not m.is_empty() and m.get("del", false):
			continue
		var it: Dictionary = isl[i]
		var xf: Array = m.get("xf", IDENT) if not m.is_empty() else IDENT
		var col = m.get("color", null) if not m.is_empty() else null
		var surf: int = it["surf"]
		var key: String = _PLAIN[surf] if col == null and surf < _PLAIN.size() else "%d|%s" % [surf, str(col)]
		if not surfs.has(key):
			var mat: Material = src.surface_get_material(it["surf"])
			if col != null:
				mat = _recolor(mat, col)
			surfs[key] = {"mat": mat, "v": PackedVector3Array(), "n": PackedVector3Array(), "b": PackedInt32Array(), "w": PackedFloat32Array()}
		var o: Dictionary = surfs[key]
		var piece_sl: Dictionary = sl[i]
		var tri: PackedVector3Array = piece_sl["v"]
		var c: Vector3 = it["center"]
		var off := xf_pos(xf)
		if _is_ident(xf):
			# untouched: the block as it is (one copy in the engine, not vertex by vertex)
			o["v"].append_array(tri)
			o["n"].append_array(piece_sl["n"])
		else:
			var bas := xf_basis(xf)
			var nb := bas.inverse().transposed()
			var sv: PackedVector3Array = piece_sl["v"]
			var sn: PackedVector3Array = piece_sl["n"]
			tri = PackedVector3Array()
			tri.resize(sv.size())
			var nn := PackedVector3Array()
			nn.resize(sn.size())
			for k in sv.size():
				tri[k] = c + bas * (sv[k] - c) + off
				nn[k] = (nb * sn[k]).normalized()
			o["v"].append_array(tri)
			o["n"].append_array(nn)
		o["b"].append_array(piece_sl["b"])
		o["w"].append_array(piece_sl["w"])
		picks.append({"id": id, "tris": tri, "center": c + off, "kind": "old", "bone": piece_sl["bone"]})
	# new blocks
	for np in mods.get("new", []):
		if String(np.get("piece", "")) != piece:
			continue
		var xf: Array = np.get("xf", IDENT)
		var col: Array = np.get("color", [0.5, 0.5, 0.5])
		var key := "new|%s" % str(col)
		if not surfs.has(key):
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(float(col[0]), float(col[1]), float(col[2]))
			mat.resource_name = "Custom"
			surfs[key] = {"mat": mat, "v": PackedVector3Array(), "n": PackedVector3Array(), "b": PackedInt32Array(), "w": PackedFloat32Array()}
		var o: Dictionary = surfs[key]
		var bind := _bind_index(mi, skel, String(np.get("bone", "")))
		var tri := PackedVector3Array()
		var bas := xf_basis(xf)
		var nb := bas.inverse().transposed()
		var pos := xf_pos(xf)
		var geo := shape_tris(String(np.get("shape", "box")))
		for k in range(0, geo.size(), 2):
			var p: Vector3 = pos + bas * geo[k]
			o["v"].append(p)
			tri.append(p)
			o["n"].append((nb * geo[k + 1]).normalized())
			o["b"].append_array([bind, 0, 0, 0])
			o["w"].append_array([1.0, 0.0, 0.0, 0.0])
		picks.append({"id": "new:%d" % _new_index(mods, np), "tris": tri, "center": pos, "kind": "new", "bone": String(np.get("bone", ""))})
	var mesh := ArrayMesh.new()
	var skinned := mi.skin != null
	for key in surfs:
		var o: Dictionary = surfs[key]
		if o["v"].is_empty():
			continue
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = o["v"]
		arr[Mesh.ARRAY_NORMAL] = o["n"]
		if skinned:
			arr[Mesh.ARRAY_BONES] = o["b"]
			arr[Mesh.ARRAY_WEIGHTS] = o["w"]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(mesh.get_surface_count() - 1, o["mat"])
	mi.mesh = mesh
	mi.set_meta("eb_parts", picks)

const _PLAIN := ["0|<null>", "1|<null>", "2|<null>", "3|<null>", "4|<null>", "5|<null>", "6|<null>", "7|<null>",
	"8|<null>", "9|<null>", "10|<null>", "11|<null>", "12|<null>", "13|<null>", "14|<null>", "15|<null>"]
static var _id_cache := {}
static func _ids_for(piece: String, n: int) -> Array:
	var k := "%s#%d" % [piece, n]
	if not _id_cache.has(k):
		var a := []
		for i in n:
			a.append("%s:%d" % [piece, i])
		_id_cache[k] = a
	return _id_cache[k]

static func _is_ident(xf: Array) -> bool:
	return xf == IDENT or (absf(float(xf[0])) + absf(float(xf[1])) + absf(float(xf[2])) + absf(float(xf[3])) + absf(float(xf[4])) + absf(float(xf[5])) < 1e-9
		and float(xf[6]) == 1.0 and float(xf[7]) == 1.0 and float(xf[8]) == 1.0)

## Each block of a source mesh as its own ready arrays (vertices, normals, 4 bones and weights per
## vertex, its bone): made once per mesh, so a rebuild only copies them.
static var _slice_cache := {}
static func _slices(src: Mesh, isl: Array, arrays: Array) -> Array:
	var key := src.get_rid().get_id()
	if _slice_cache.has(key):
		return _slice_cache[key]
	var out := []
	for it in isl:
		var a: Array = arrays[it["surf"]]
		var sv: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var sn = a[Mesh.ARRAY_NORMAL]
		var sb = a[Mesh.ARRAY_BONES]
		var sw = a[Mesh.ARRAY_WEIGHTS]
		var per: int = (sb.size() / sv.size()) if sb != null and sv.size() > 0 else 0
		var tris: PackedInt32Array = it["tris"]
		var v := PackedVector3Array()
		v.resize(tris.size())
		var n := PackedVector3Array()
		n.resize(tris.size())
		var b := PackedInt32Array()
		b.resize(tris.size() * 4)
		var w := PackedFloat32Array()
		w.resize(tris.size() * 4)
		for j in tris.size():
			var vi: int = tris[j]
			v[j] = sv[vi]
			n[j] = (sn[vi] as Vector3).normalized() if sn != null else Vector3.UP
			for k in 4:
				b[j * 4 + k] = sb[vi * per + k] if per > k else 0
				w[j * 4 + k] = sw[vi * per + k] if per > k else (1.0 if k == 0 else 0.0)
		out.append({"v": v, "n": n, "b": b, "w": w, "bone": ""})
	_slice_cache[key] = out
	return out

static func _new_index(mods: Dictionary, np: Dictionary) -> int:
	return (mods.get("new", []) as Array).find(np)

static func _recolor(mat: Material, col: Array) -> Material:
	var m: Material = mat.duplicate() if mat else StandardMaterial3D.new()
	if m is BaseMaterial3D:
		(m as BaseMaterial3D).albedo_color = Color(float(col[0]), float(col[1]), float(col[2]))
		if (m as BaseMaterial3D).emission_enabled:
			(m as BaseMaterial3D).emission = (m as BaseMaterial3D).albedo_color
	m.resource_name = mat.resource_name if mat else "Custom"
	return m

## Which bone a block of the original mesh follows (its first vertex's main bone).
static func _bone_of(mi: MeshInstance3D, skel: Skeleton3D, sb, it: Dictionary, per: int) -> String:
	if skel == null or sb == null or per == 0:
		return ""
	var bi: int = sb[int(it["tris"][0]) * per]
	var name := mi.skin.get_bind_name(bi)
	if name == "" and mi.skin.get_bind_bone(bi) >= 0:
		name = skel.get_bone_name(mi.skin.get_bind_bone(bi))
	return name

static func _bind_index(mi: MeshInstance3D, skel: Skeleton3D, bone: String) -> int:
	if mi.skin == null:
		return 0
	for i in mi.skin.get_bind_count():
		var n := mi.skin.get_bind_name(i)
		if n == "" and skel and mi.skin.get_bind_bone(i) >= 0:
			n = skel.get_bone_name(mi.skin.get_bind_bone(i))
		if n == bone:
			return i
	return 0

## Flat-shaded unit shapes: [pos, normal, pos, normal, ...] for triangles.
## box: 1x1x1 centred; cyl: radius 0.5, height 1 along Y (10 sides); ball: diameter 1.
static var _shapes := {}
static func shape_tris(kind: String) -> PackedVector3Array:
	if _shapes.has(kind):
		return _shapes[kind]
	var out := PackedVector3Array()
	match kind:
		"cyl":
			var n := 10
			for i in n:
				var a0 := TAU * i / n
				var a1 := TAU * (i + 1) / n
				var p0 := Vector3(cos(a0) * 0.5, 0, sin(a0) * 0.5)
				var p1 := Vector3(cos(a1) * 0.5, 0, sin(a1) * 0.5)
				var nn := Vector3(cos((a0 + a1) / 2), 0, sin((a0 + a1) / 2))
				_quad(out, p0 + Vector3(0, -0.5, 0), p1 + Vector3(0, -0.5, 0), p1 + Vector3(0, 0.5, 0), p0 + Vector3(0, 0.5, 0), nn)
				_tri(out, Vector3(0, 0.5, 0), p1 + Vector3(0, 0.5, 0), p0 + Vector3(0, 0.5, 0), Vector3.UP)
				_tri(out, Vector3(0, -0.5, 0), p0 + Vector3(0, -0.5, 0), p1 + Vector3(0, -0.5, 0), Vector3.DOWN)
		"ball":
			var seg := 10
			var rings := 6
			for r in rings:
				var t0 := PI * r / rings
				var t1 := PI * (r + 1) / rings
				for i in seg:
					var a0 := TAU * i / seg
					var a1 := TAU * (i + 1) / seg
					var q := [_sph(t0, a0), _sph(t0, a1), _sph(t1, a1), _sph(t1, a0)]
					var nn: Vector3 = ((q[0] + q[1] + q[2] + q[3]) as Vector3).normalized()
					_quad(out, q[3], q[2], q[1], q[0], nn)
		_:
			var h := 0.5
			for f in [[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.UP, Vector3.FORWARD], [Vector3.UP, Vector3.BACK, Vector3.RIGHT],
					[Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT], [Vector3.BACK, Vector3.UP, Vector3.LEFT], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT]]:
				var nrm: Vector3 = f[0]
				var u: Vector3 = f[1]
				var w: Vector3 = f[2]
				var c := nrm * h
				_quad(out, c - u * h - w * h, c - u * h + w * h, c + u * h + w * h, c + u * h - w * h, nrm)
	_shapes[kind] = out
	return out

static func _sph(t: float, a: float) -> Vector3:
	return Vector3(sin(t) * cos(a), cos(t), sin(t) * sin(a)) * 0.5

static func _tri(out: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	# Godot front faces are clockwise as seen from the front
	var face := (b - a).cross(c - a)
	if face.dot(n) > 0:
		out.append_array([a, n, c, n, b, n])
	else:
		out.append_array([a, n, b, n, c, n])

static func _quad(out: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	_tri(out, a, b, c, n)
	_tri(out, a, c, d, n)
