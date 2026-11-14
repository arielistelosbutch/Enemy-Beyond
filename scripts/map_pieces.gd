class_name MapPieces
## Map blocks as data (0.55): a block the generator builds can be taken down into a list of parts
## (blocks, cylinders, balls, village models, lights, fire, grass) and notes (where the aliens wait,
## cover, doors, windows, sounds...), saved in dilky/<kind>/<name>.json, edited in the Mapové díly
## editor and built again on the map. A kind with saved blocks uses them instead of the generator
## (or beside it: the "generovaný" weight in dilky/<kind>/nastaveni.json).

const DIR := "res://dilky"

## kind -> [the generator's function, its extra arguments], Czech name for the editor.
const KINDS := {
	"house": ["_house", [], "Statek (dům se zahradou)"], "house2": ["_house2", [], "Patrový dům"],
	"barn": ["_barn", [], "Stodola"], "chapel": ["_chapel", [], "Náves s kapličkou"],
	"ruin": ["_ruin", [], "Spálená ruina"], "garden": ["_garden", [], "Zahrada s kůlnou"],
	"orchard": ["_orchard", [], "Sad"], "field": ["_field", [], "Pole"], "pasture": ["_pasture", [], "Pastvina"],
	"meadow": ["_meadow", [], "Louka"], "forest": ["_forest", [], "Les"], "stream": ["_stream", [], "Potok"],
	"rocks": ["_rocks", [], "Skály"], "cabin": ["_cabin", [], "Srub"], "dunes": ["_dunes", [], "Duny"],
	"open": ["_open", [], "Volné místo"], "shop": ["_shop", [], "Obchod"], "pub": ["_pub", [], "Hospoda"],
	"park": ["_park", [], "Park"], "parking": ["_parking", [], "Parkoviště"], "fuel": ["_fuel", [], "Benzínka"],
	"warehouse": ["_warehouse", [], "Sklad"], "containers": ["_containers", [], "Kontejnery"],
	"tanks": ["_tanks", [], "Nádrže"], "yard": ["_yard", [], "Dvůr skladu"], "hangar": ["_hangar", [], "Hangár"],
	"barracks": ["_barracks", [], "Kasárna"], "radar": ["_radar_tower", [], "Radarová věž"],
	"sandbags": ["_sandbags", [], "Pytle s pískem"], "icelake": ["_icelake", [], "Zamrzlé jezero"],
	"icespires": ["_icespires", [], "Ledové věže"], "polarhut": ["_polar_hut", [], "Polární chata"],
	"road_ns": ["_road", [false], "Silnice (sever-jih)"], "road_ew": ["_road", [true], "Silnice (východ-západ)"],
	"road_x": ["_road", [false, true], "Křižovatka silnic"], "street_ns": ["_street", [false], "Ulice (sever-jih)"],
	"street_ew": ["_street", [true], "Ulice (východ-západ)"], "street_x": ["_street", [false, true], "Křižovatka ulic"],
}
## Notes kept as plain points.
const POINT_KEYS := ["waypoints", "cover", "vip_spots", "alien_spawns", "player_spawns", "cows"]
## What is worked out again from the parts when the block is built (not saved).
const DERIVED := ["roofs", "surfaces", "breakables", "lights", "elec_lights", "landmarks"]

# ---- materials ---------------------------------------------------------------------------------------
static func mat_spec(m: Material) -> Array:
	if m == null:
		return ["c", [0.5, 0.5, 0.5, 1.0]]
	if m.has_meta("spec"):
		return m.get_meta("spec")
	if m is BaseMaterial3D:
		var c: Color = (m as BaseMaterial3D).albedo_color
		if (m as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			return ["glass"]
		return ["c", [snappedf(c.r, 0.001), snappedf(c.g, 0.001), snappedf(c.b, 0.001), 1.0]]
	return ["c", [0.5, 0.5, 0.5, 1.0]]

static func mat_from(mg, s: Array) -> Material:
	match String(s[0]) if not s.is_empty() else "":
		"t":
			var tex := String(s[1])
			if mg != null:
				tex = _terrain_tex(mg, tex)
			var em: Color = Color.BLACK
			if s.size() > 3 and s[3] is Array:
				em = Color(s[3][0], s[3][1], s[3][2], s[3][3] if (s[3] as Array).size() > 3 else 1.0)
			return Game.mat(tex, float(s[2]) if s.size() > 2 else 0.5, em)
		"c":
			var c: Array = s[1]
			return Game.color_mat(Color(c[0], c[1], c[2], c[3] if c.size() > 3 else 1.0), bool(s[2]) if s.size() > 2 else false,
				float(s[3]) if s.size() > 3 else 0.0, float(s[4]) if s.size() > 4 else 1.0)
		"glass":
			return mg._glass_mat() if mg != null else Game.glass_mat()
	return Game.color_mat(Color(0.5, 0.5, 0.5))

## The same ground in snow and in the desert as the generator would lay (see MapGen._ground).
static func _terrain_tex(mg, tex: String) -> String:
	match String(mg.terrain):
		"mars": return "mars" if tex in ["grass", "dirt", "hay", "snow", "sand"] else tex
		"snow": return "snow" if tex in ["grass", "dirt", "hay"] else tex
		"desert": return "sand" if tex in ["grass", "dirt"] else tex
	return tex

# ---- taking a block down into data -------------------------------------------------------------------
## Builds the block @a kind at @a o with the generator and returns it as data (the nodes stay).
static func capture(mg, kind: String, o: Vector3) -> Dictionary:
	var spec: Array = KINDS.get(kind, ["_" + kind, [], kind])
	var before := {}
	for key in mg.info:
		before[key] = (mg.info[key] as Array).size() if mg.info[key] is Array else mg.info[key]
	var n0: int = mg.root.get_child_count()
	mg.capturing = true
	mg._cap_calls = []
	mg.callv(String(spec[0]), [o] + (spec[1] as Array))
	mg.capturing = false
	var els := []
	var idx := {}
	for i in range(n0, mg.root.get_child_count()):
		var n: Node = mg.root.get_child(i)
		if n is Node3D:
			_ser(mg, n as Node3D, Transform3D.IDENTITY, o, els, idx)
	for c in mg._cap_calls:
		match String(c[0]):
			"grass":
				els.append({"k": "grass", "n": int(c[2]), "druh": String(c[3]), "min": float(c[4]), "max": float(c[5])})
	# lights that carry a bulb, and wooden roofs: by the part's number
	for i in els.size():
		var e: Dictionary = els[i]
		if e.has("_lens"):
			var ln = e["_lens"]
			e.erase("_lens")
			if idx.has(ln):
				e["lens"] = idx[ln]
		if e.has("_na"):
			var hosts: Array = e["_na"]
			e.erase("_na")
			var na := []
			for hn in hosts:
				if idx.has(hn):
					na.append(idx[hn])
			if not na.is_empty():
				e["na"] = na
	for key in mg.info:
		var v = mg.info[key]
		if v is Array:
			var start: int = before.get(key, 0) if before.get(key, 0) is int else 0
			for j in range(start, (v as Array).size()):
				var it = v[j]
				if key in DERIVED:
					continue
				if key in POINT_KEYS and it is Vector3:
					els.append({"k": "point", "t": key, "p": _v(it - o)})
				elif key == "doors":
					els.append({"k": "door", "p": _v(it["c"] - o), "x": bool(it["along_x"]), "w": snappedf(float(it["w"]), 0.001),
						"h": snappedf(float(it["h"]), 0.001), "open": bool(it.get("open", false))})
				elif key == "windows":
					els.append({"k": "window", "p": _v(it["c"] - o), "n": _v(it["n"]), "sill": snappedf(float(it["sill"]), 0.001),
						"w": snappedf(float(it["w"]), 0.001)})
				elif key == "sounds":
					els.append({"k": "sound", "n": String(it["name"]), "p": _v(it["pos"] - o), "db": float(it["db"])})
				elif key == "wood_roofs":
					var r: Rect2 = it["rect"]
					if idx.has(it["node"]):
						els.append({"k": "woodroof", "i": idx[it["node"]], "rect": [snappedf(r.position.x - o.x, 0.001),
							snappedf(r.position.y - o.z, 0.001), snappedf(r.size.x, 0.001), snappedf(r.size.y, 0.001)]})
				elif it is Vector3:
					els.append({"k": "point", "t": key, "p": _v(it - o)})
				else:
					push_warning("MapPieces: %s note %s not kept" % [kind, key])
		elif v is Vector3 and v != before.get(key, Vector3.ZERO):
			els.append({"k": "spot", "t": key, "p": _v(v - o)})
		elif not before.has(key) and v is Vector3:
			els.append({"k": "spot", "t": key, "p": _v(v - o)})
	return {"druh": kind, "nazev": "", "prvky": els}

static func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]

static func _put_xf(e: Dictionary, xf: Transform3D, o: Vector3) -> void:
	e["p"] = _v(xf.origin - o)
	var b := xf.basis
	var s := Vector3(b.x.length(), b.y.length(), b.z.length())
	var r := Basis(b.x / maxf(s.x, 1e-6), b.y / maxf(s.y, 1e-6), b.z / maxf(s.z, 1e-6)).orthonormalized().get_euler() * (180.0 / PI)
	if r.length() > 0.01:
		e["r"] = [snappedf(r.x, 0.01), snappedf(r.y, 0.01), snappedf(r.z, 0.01)]
	if (s - Vector3.ONE).length() > 0.001:
		e["sc"] = _v(s)

static func _prim(mi: MeshInstance3D) -> Dictionary:
	var m := mi.mesh
	var e := {}
	if m is BoxMesh:
		e = {"k": "box", "s": _v((m as BoxMesh).size)}
	elif m is CylinderMesh:
		var cm := m as CylinderMesh
		e = {"k": "cyl", "rt": snappedf(cm.top_radius, 0.001), "rb": snappedf(cm.bottom_radius, 0.001), "h": snappedf(cm.height, 0.001)}
		if cm.radial_segments != 8:
			e["n"] = cm.radial_segments
	elif m is SphereMesh:
		var sm := m as SphereMesh
		e = {"k": "ball", "rad": snappedf(sm.radius, 0.001), "h": snappedf(sm.height, 0.001)}
		if sm.radial_segments != 64:
			e["n"] = sm.radial_segments
		if sm.rings != 32:
			e["rings"] = sm.rings
	else:
		return {}
	e["m"] = mat_spec(mi.material_override if mi.material_override else m.surface_get_material(0))
	if not mi.visible:
		e["vis"] = false
	if mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		e["stin"] = false
	return e

static func _ser(mg, n: Node3D, pxf: Transform3D, o: Vector3, els: Array, idx: Dictionary) -> void:
	var xf := pxf * n.transform
	if n.has_meta("model"):
		var e := {"k": "model", "n": String(n.get_meta("model"))}
		_put_xf(e, xf, o)
		if n in mg._loose:
			e["volne"] = true
		if n.has_meta("retex"):
			e["retex"] = n.get_meta("retex")
		if n.has_meta("nocol"):
			e["nocol"] = true
		if n.has_meta("noslab"):
			e["noslab"] = true       # (a roof without its flat collision slab: the cabin's loft)
		for sb in n.find_children("*", "StaticBody3D", true, false):
			if sb.has_meta("break_kind"):
				e["br"] = String(sb.get_meta("break_kind"))
				break
		if not n.visible:
			e["vis"] = false
		idx[n] = els.size()
		els.append(e)
		# things the code added into the model (a cow's wound): separate parts
		for c in n.find_children("*", "MeshInstance3D", true, false):
			var cm := c as MeshInstance3D
			if cm.owner == null and cm.has_meta("_added") == false and _added_by_code(n, cm):
				var pe := _prim(cm)
				if not pe.is_empty():
					_put_xf(pe, xf * _rel(n, cm), o)
					pe["c"] = false
					els.append(pe)
		return
	if n is StaticBody3D:
		var meshes := []
		var shapes := []
		for c in n.get_children():
			if c is MeshInstance3D:
				meshes.append(c)
			elif c is CollisionShape3D:
				shapes.append(c)
		if meshes.size() == 1 and shapes.size() <= 1:
			var mi: MeshInstance3D = meshes[0]
			var e := _prim(mi)
			if not e.is_empty():
				_put_xf(e, xf * mi.transform, o)
				e["c"] = true
				var sb := n as StaticBody3D
				if sb.collision_layer != 1:
					e["l"] = sb.collision_layer
				if sb.has_meta("break_kind"):
					e["br"] = String(sb.get_meta("break_kind"))
				if not n.visible:
					e["vis"] = false
				idx[n] = els.size()
				els.append(e)
				return
		if n.has_meta("under_ramp"):
			return          # (made again under the ramp when the tile is built)
		if meshes.is_empty() and shapes.size() == 1 and (shapes[0] as CollisionShape3D).shape is BoxShape3D:
			var e := {"k": "solid", "s": _v(((shapes[0] as CollisionShape3D).shape as BoxShape3D).size)}
			_put_xf(e, xf * (shapes[0] as CollisionShape3D).transform, o)
			idx[n] = els.size()
			els.append(e)
			return
		push_warning("MapPieces: an odd static body (%d meshes, %d shapes)" % [meshes.size(), shapes.size()])
		return
	if n is MeshInstance3D:
		var e := _prim(n as MeshInstance3D)
		if e.is_empty():
			push_warning("MapPieces: mesh %s not kept" % (n as MeshInstance3D).mesh)
			return
		_put_xf(e, xf, o)
		e["c"] = false
		if n.has_meta("deco_of"):
			e["_na"] = n.get_meta("deco_of")
		idx[n] = els.size()
		els.append(e)
		return
	if n is Light3D:
		var l := n as Light3D
		var e := {"k": "light", "t": "spot" if n is SpotLight3D else "omni",
			"col": [snappedf(l.light_color.r, 0.001), snappedf(l.light_color.g, 0.001), snappedf(l.light_color.b, 0.001)],
			"e": snappedf(l.light_energy, 0.001), "stin": l.shadow_enabled}
		if n is OmniLight3D:
			e["rng"] = snappedf((n as OmniLight3D).omni_range, 0.001)
			if (n as OmniLight3D).omni_attenuation != 1.0:
				e["att"] = (n as OmniLight3D).omni_attenuation
		else:
			var sl := n as SpotLight3D
			e["rng"] = snappedf(sl.spot_range, 0.001)
			e["ang"] = snappedf(sl.spot_angle, 0.01)
			if sl.spot_attenuation != 1.0:
				e["att"] = sl.spot_attenuation
		_put_xf(e, xf, o)
		if l.has_meta("base"):
			e["base"] = float(l.get_meta("base"))
		if l.has_meta("flicker"):
			e["mihot"] = true
		if l in mg.info["elec_lights"]:
			e["elektr"] = true
		if l in mg.info["lights"]:
			e["ohen"] = true
		if l.has_meta("lens"):
			e["_lens"] = l.get_meta("lens")
		if not l.visible:
			e["vis"] = false
		idx[n] = els.size()
		els.append(e)
		return
	if n is CPUParticles3D:
		var e := {"k": "fire", "n": (n as CPUParticles3D).amount}
		_put_xf(e, xf, o)
		idx[n] = els.size()
		els.append(e)
		return
	if n is MultiMeshInstance3D:
		return          # grass: kept from the call (see _cap_calls)
	if n is NavigationLink3D:
		var nl := n as NavigationLink3D
		els.append({"k": "link", "a": _v(xf * nl.start_position - o), "b": _v(xf * nl.end_position - o)})
		return
	if n.get_class() == "Node3D":
		for c in n.get_children():
			if c is Node3D:
				_ser(mg, c as Node3D, xf, o, els, idx)
		return
	push_warning("MapPieces: %s not kept" % n.get_class())

## A mesh inside a model that the model's own file does not have (added by the code).
static func _added_by_code(model: Node, mi: Node) -> bool:
	return mi.owner != model and mi.owner == null

static func _rel(anc: Node3D, n: Node3D) -> Transform3D:
	var t := n.transform
	var p := n.get_parent()
	while p and p != anc:
		if p is Node3D:
			t = (p as Node3D).transform * t
		p = p.get_parent()
	return t

# ---- building a block from data ----------------------------------------------------------------------
static func _p(e: Dictionary, key := "p") -> Vector3:
	var a: Array = e.get(key, [0, 0, 0])
	return Vector3(a[0], a[1], a[2])

static func _r(e: Dictionary) -> Vector3:
	var a: Array = e.get("r", [0, 0, 0])
	return Vector3(a[0], a[1], a[2])

static func _sc(e: Dictionary) -> Vector3:
	var a: Array = e.get("sc", [1, 1, 1])
	return Vector3(a[0], a[1], a[2])

## The part's place in the block (position, turn, stretch).
static func local_xf(e: Dictionary) -> Transform3D:
	var r := _r(e) * (PI / 180.0)
	return Transform3D(Basis.from_euler(r).scaled_local(_sc(e)), _p(e))

## Builds the block @a d at @a o; returns the node of each part (null for notes).
static func build(mg, d: Dictionary, o: Vector3) -> Array:
	var els: Array = d.get("prvky", [])
	var nodes := []
	for e in els:
		nodes.append(make(mg, e, o, els))
	for i in els.size():
		var e: Dictionary = els[i]
		match String(e.get("k", "")):
			"light":
				var li := int(e.get("lens", -1))
				if nodes[i] and li >= 0 and li < nodes.size() and nodes[li]:
					(nodes[i] as Node).set_meta("lens", nodes[li])
			"box", "cyl", "ball", "model":
				if e.has("na") and nodes[i]:
					var hosts := []
					for hi in e["na"]:
						if int(hi) >= 0 and int(hi) < nodes.size() and nodes[int(hi)]:
							hosts.append(nodes[int(hi)])
					mg._deco(nodes[i], hosts)
			"woodroof":
				var ri := int(e.get("i", -1))
				if ri >= 0 and ri < nodes.size() and nodes[ri]:
					var rr: Array = e["rect"]
					if not mg.info.has("wood_roofs"):
						mg.info["wood_roofs"] = []
					mg.info["wood_roofs"].append({"node": nodes[ri], "rect": Rect2(o.x + float(rr[0]), o.z + float(rr[1]), float(rr[2]), float(rr[3]))})
	return nodes

## One part (or note) of a block; @a els (all of them) for grass to keep off the solid ones.
static func make(mg, e: Dictionary, o: Vector3, els := []) -> Node3D:
	var k := String(e.get("k", ""))
	var p := o + _p(e)
	var r := _r(e)
	var flat := absf(r.x) < 0.001 and absf(r.z) < 0.001
	var n: Node3D = null
	match k:
		"box":
			n = mg.box(p, _p(e, "s"), mat_from(mg, e.get("m", [])), bool(e.get("c", true)), deg_to_rad(r.y) if flat else 0.0)
			if not flat:
				n.rotation_degrees = r
		"cyl":
			n = mg.cyl(p, float(e["rt"]), float(e["rb"]), float(e["h"]), mat_from(mg, e.get("m", [])), bool(e.get("c", true)), int(e.get("n", 8)))
			n.rotation_degrees = r
		"ball":
			var mi := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = float(e["rad"])
			sm.height = float(e["h"])
			sm.radial_segments = int(e.get("n", 64))
			sm.rings = int(e.get("rings", 32))
			mi.mesh = sm
			mi.material_override = mat_from(mg, e.get("m", []))
			if bool(e.get("c", false)):
				var sb := StaticBody3D.new()
				var cs := CollisionShape3D.new()
				var sh := SphereShape3D.new()
				sh.radius = sm.radius
				cs.shape = sh
				sb.add_child(cs)
				sb.add_child(mi)
				n = sb
			else:
				n = mi
			mg.root.add_child(n)
			n.position = p
			n.rotation_degrees = r
		"model":
			var nm := String(e["n"])
			if nm.begins_with("v_"):
				n = mg._prop(nm.substr(2), p, deg_to_rad(r.y), false)
				if not bool(e.get("volne", false)):
					mg._loose.erase(n)
			else:
				n = Game.model(nm)
				mg.root.add_child(n)
				n.position = p
				# 0.69: a stone from the editor is solid in its shape too (it came with a hollow box)
				if nm.begins_with("mars_rock"):
					mg._solid_stone(n)
				elif nm.begins_with("mars_"):
					preload("res://scripts/fit_collision.gd").fit(n)
				if bool(e.get("volne", false)):
					mg._loose.append(n)
			n.rotation_degrees = r
			if bool(e.get("nocol", false)):
				for sb in n.find_children("*", "StaticBody3D", true, false):
					sb.free()
				n.set_meta("nocol", true)
			if bool(e.get("noslab", false)):
				mg._roof_no_slab(n)
			if e.has("retex"):
				var swap := {}
				for key in e["retex"]:
					swap[key] = mat_from(mg, e["retex"][key])
				mg._retexture(n, swap)
		"light":
			var l: Light3D
			if String(e.get("t", "omni")) == "spot":
				var sl := SpotLight3D.new()
				sl.spot_range = float(e.get("rng", 8.0))
				sl.spot_angle = float(e.get("ang", 40.0))
				if e.has("att"):
					sl.spot_attenuation = float(e["att"])
				l = sl
			else:
				var ol := OmniLight3D.new()
				ol.omni_range = float(e.get("rng", 5.0))
				if e.has("att"):
					ol.omni_attenuation = float(e["att"])
				l = ol
			var c: Array = e.get("col", [1, 1, 1])
			l.light_color = Color(c[0], c[1], c[2])
			l.light_energy = float(e.get("e", 1.0))
			l.shadow_enabled = bool(e.get("stin", false))
			if e.has("base"):
				l.set_meta("base", float(e["base"]))
			if bool(e.get("mihot", false)):
				l.set_meta("flicker", true)
			mg.root.add_child(l)
			l.position = p
			l.rotation_degrees = r
			if bool(e.get("elektr", false)):
				mg.info["elec_lights"].append(l)
			if bool(e.get("ohen", false)):
				mg.info["lights"].append(l)
			n = l
		"fire":
			n = mg._flame_fx(p, int(e.get("n", 20)))
		"grass":
			var solid := []
			for e2 in els:
				if String(e2.get("k", "")) in ["box", "cyl", "model"] and bool(e2.get("c", true)):
					var a := aabb(e2)
					if a.size.y > 0.4 and a.end.y > 0.3:
						solid.append(Rect2(a.position.x - 0.2, a.position.z - 0.2, a.size.x + 0.4, a.size.z + 0.4))
			mg._grass(o, int(e.get("n", 300)), String(e.get("druh", "grass")), float(e.get("min", 0.6)), float(e.get("max", 1.3)),
				func(lp: Vector3) -> bool:
					for rr in solid:
						if (rr as Rect2).has_point(Vector2(lp.x, lp.z)):
							return false
					return true)
		"link":
			var nl := NavigationLink3D.new()
			nl.bidirectional = true
			nl.start_position = o + _p(e, "a")
			nl.end_position = o + _p(e, "b")
			mg.root.add_child(nl)
		"solid":
			var sb := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			var sh := BoxShape3D.new()
			sh.size = _p(e, "s")
			cs.shape = sh
			sb.add_child(cs)
			mg.root.add_child(sb)
			sb.position = p
			sb.rotation_degrees = r
			n = sb
			# a ramp (a thin tilted slab): solid under it, as the generator's stairs (2026-11-13)
			var tz := absf(sb.transform.basis.z.normalized().y)
			if sh.size.y < 0.3 and tz > 0.25 and tz < 0.95:
				mg._under_ramp(sb, sh.size)
		"point":
			var key := String(e.get("t", "waypoints"))
			if not mg.info.has(key):
				mg.info[key] = []
			mg.info[key].append(p)
		"spot":
			mg.info[String(e.get("t", "house"))] = p
		"door":
			var lim := float(mg.info.get("size", mg.BLOCK * mg.N))
			if minf(minf(p.x, p.z), minf(lim - p.x, lim - p.z)) >= 1.8:
				mg.info["doors"].append({"c": p, "along_x": bool(e.get("x", true)), "w": float(e.get("w", 1.5)),
					"h": float(e.get("h", 2.15)), "open": bool(e.get("open", false))})
		"window":
			mg.info["windows"].append({"c": p, "n": _p(e, "n"), "sill": float(e.get("sill", 0.9)), "w": float(e.get("w", 1.0))})
		"sound":
			mg.info["sounds"].append({"name": String(e.get("n", "static")), "pos": p, "db": float(e.get("db", -18.0))})
	if n and k in ["box", "cyl", "ball", "model"]:
		if e.has("sc"):
			n.scale = _sc(e)
		if e.has("vis"):
			n.visible = bool(e["vis"])
		if e.has("l") and n is CollisionObject3D:
			(n as CollisionObject3D).collision_layer = int(e["l"])
		if e.has("br") and n is StaticBody3D:
			mg._breakable(n, String(e["br"]))
		elif e.has("br") and k == "model":
			mg._breakable_model(n, String(e["br"]))
		if e.has("stin"):
			for gi in ([n] + n.find_children("*", "GeometryInstance3D", true, false)):
				if gi is GeometryInstance3D:
					(gi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if bool(e["stin"]) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n

## The part's box in the block (for picking and for keeping grass off it).
static func aabb(e: Dictionary) -> AABB:
	var unit := AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
	var xf := local_xf(e)
	match String(e.get("k", "")):
		"box", "solid":
			xf = xf * Transform3D(Basis.from_scale(_p(e, "s").max(Vector3.ONE * 0.01)), Vector3.ZERO)
		"cyl":
			var rr := maxf(float(e["rt"]), float(e["rb"]))
			xf = xf * Transform3D(Basis.from_scale(Vector3(rr * 2, float(e["h"]), rr * 2)), Vector3.ZERO)
		"ball":
			xf = xf * Transform3D(Basis.from_scale(Vector3(float(e["rad"]) * 2, float(e["h"]), float(e["rad"]) * 2)), Vector3.ZERO)
		"model":
			var a := model_box(String(e["n"]))
			return xf * a
		_:
			xf = xf * Transform3D(Basis.from_scale(Vector3.ONE * 0.4), Vector3(0, 0.2, 0))
	return xf * unit

static var _model_tris := {}
## A model's triangles in its own space (picking in the editor).
static func model_tris(nm: String) -> PackedVector3Array:
	if _model_tris.has(nm):
		return _model_tris[nm]
	var out := PackedVector3Array()
	var n: Node3D = Game.model(nm)
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var xf: Transform3D = MapPieces._rel(n, m)
		for v in m.mesh.get_faces():
			out.append(xf * v)
	n.free()
	_model_tris[nm] = out
	return out

static var _model_boxes := {}
## A model's size (all its meshes, in its own space).
static func model_box(nm: String) -> AABB:
	if _model_boxes.has(nm):
		return _model_boxes[nm]
	var n: Node3D = Game.model(nm)
	var box := AABB(Vector3(-0.5, 0, -0.5), Vector3.ONE)
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var b: AABB = MapPieces._rel(n, m) * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	n.free()
	_model_boxes[nm] = box
	return box

# ---- saved blocks -----------------------------------------------------------------------------------
static var _designs := {}
static var test_dir := ""          # (the editor's self-test saves here)

## Where the editor saves (in the Godot project; next to the game for a released one).
static func save_dir() -> String:
	if test_dir != "":
		return test_dir
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path(DIR)
	return OS.get_executable_path().get_base_dir().path_join("dilky")

static func forget() -> void:
	_designs = {}

## Every saved block of a kind: [{nazev, vaha, prvky...}], sorted by name.
static func designs(kind: String) -> Array:
	if _designs.has(kind):
		return _designs[kind]
	var out := {}
	for base in [DIR, save_dir()]:
		var dir := String(base).path_join(kind)
		if not DirAccess.dir_exists_absolute(dir):
			continue
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".json") and f != "nastaveni.json":
				var d = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(f)))
				if d is Dictionary and d.has("prvky"):
					d["_soubor"] = f.get_basename()
					out[f.get_basename()] = d
	var arr := out.values()
	arr.sort_custom(func(a, b): return String(a["_soubor"]) < String(b["_soubor"]))
	_designs[kind] = arr
	return arr

static func settings(kind: String) -> Dictionary:
	for base in [save_dir(), DIR]:
		var path := String(base).path_join(kind).path_join("nastaveni.json")
		if FileAccess.file_exists(path):
			var d = JSON.parse_string(FileAccess.get_file_as_string(path))
			if d is Dictionary:
				return d
	return {}

## Which block the map gets for this kind: a saved one, or {} = let the generator make it.
## (The map's own random numbers: the same on every machine.)
static func pick(mg, kind: String) -> Dictionary:
	var ds := designs(kind)
	if ds.is_empty():
		return {}
	var gen := float(settings(kind).get("generovany", 0.0))
	var total := gen
	for d in ds:
		total += maxf(0.0, float(d.get("vaha", 1.0)))
	if total <= 0.0:
		return {}
	var x: float = mg.rng.randf() * total
	for d in ds:
		x -= maxf(0.0, float(d.get("vaha", 1.0)))
		if x < 0.0:
			return d
	return {}

static func save(kind: String, file: String, d: Dictionary) -> String:
	var dir := save_dir().path_join(kind)
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join(file + ".json")
	var out := d.duplicate(true)
	out.erase("_soubor")
	out["druh"] = kind
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(out, " ", false))
	f.close()
	_designs.erase(kind)
	return path

static func remove(kind: String, file: String) -> bool:
	var path := save_dir().path_join(kind).path_join(file + ".json")
	_designs.erase(kind)
	return DirAccess.remove_absolute(path) == OK

static func save_settings(kind: String, s: Dictionary) -> void:
	var dir := save_dir().path_join(kind)
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir.path_join("nastaveni.json"), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(s, " ", false))
