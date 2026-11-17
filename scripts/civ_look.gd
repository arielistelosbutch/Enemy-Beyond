extends RefCounted
## (0.72, Ari: „několik typů civilistů… ať vypadají víc jako vojáci a jejich tváře, ať se to s ničím
## nemíchá, i vesničanky; do města jiné oblečení, na vesnici jiné“) Civilians are the soldier's model
## (merc.glb: the same face, hair, beards, skin and the same 15 bones as the soldiers, the scientists
## and the technicians), only in everyday clothes of 1990. Each type is a soldier's look (which
## pieces) plus colours for the pieces. No new meshes: the shirt is the soldier's top, the jeans his
## trousers, the farmer's cap his field cap, the headscarf his bandana - all repainted.


## Colours (1990: no neon, faded fabrics)
const JEANS := [Color(0.16, 0.24, 0.42), Color(0.24, 0.33, 0.5), Color(0.12, 0.16, 0.27)]
const DARK := [Color(0.16, 0.16, 0.18), Color(0.2, 0.18, 0.15), Color(0.13, 0.15, 0.22)]
const SUIT := [Color(0.26, 0.27, 0.29), Color(0.17, 0.2, 0.3), Color(0.33, 0.25, 0.18), Color(0.34, 0.33, 0.29)]
const SHIRT := [Color(0.88, 0.88, 0.85), Color(0.6, 0.72, 0.85), Color(0.86, 0.82, 0.62), Color(0.72, 0.74, 0.72)]
const TEE := [Color(0.7, 0.13, 0.12), Color(0.85, 0.72, 0.18), Color(0.86, 0.86, 0.84), Color(0.14, 0.42, 0.45), Color(0.2, 0.22, 0.42)]
const COAT_F := [Color(0.62, 0.12, 0.14), Color(0.72, 0.62, 0.45), Color(0.38, 0.2, 0.42), Color(0.16, 0.38, 0.4), Color(0.3, 0.32, 0.42)]
const TOP_F := [Color(0.85, 0.5, 0.58), Color(0.88, 0.88, 0.85), Color(0.86, 0.78, 0.35), Color(0.48, 0.66, 0.8)]
const BEIGE := [Color(0.62, 0.55, 0.42), Color(0.45, 0.42, 0.38), Color(0.5, 0.45, 0.35)]
const WORK := [Color(0.17, 0.24, 0.38), Color(0.22, 0.28, 0.2)]          # montérky: modré, zelené
const FLANNEL := [Color(0.6, 0.15, 0.12), Color(0.22, 0.35, 0.2), Color(0.18, 0.24, 0.42), Color(0.45, 0.32, 0.18)]
const OLD := [Color(0.34, 0.25, 0.16), Color(0.3, 0.32, 0.22), Color(0.36, 0.36, 0.34), Color(0.22, 0.2, 0.18)]
const SCARF := [Color(0.7, 0.14, 0.14), Color(0.2, 0.3, 0.58), Color(0.86, 0.84, 0.78), Color(0.5, 0.3, 0.5), Color(0.25, 0.42, 0.25)]
const PASTEL := [Color(0.62, 0.7, 0.78), Color(0.78, 0.66, 0.62), Color(0.72, 0.74, 0.6), Color(0.56, 0.5, 0.62)]
const SHOES := [Color(0.08, 0.07, 0.06), Color(0.28, 0.17, 0.09)]
const SNEAKER := [Color(0.82, 0.82, 0.8), Color(0.3, 0.32, 0.36)]
const WELLIES := [Color(0.1, 0.16, 0.08), Color(0.06, 0.06, 0.06)]
const CAPS := [Color(0.18, 0.24, 0.45), Color(0.24, 0.3, 0.2), Color(0.6, 0.15, 0.1), Color(0.3, 0.3, 0.3)]
const HATS := [Color(0.27, 0.22, 0.16), Color(0.18, 0.18, 0.18), Color(0.3, 0.3, 0.26)]
const STRAW := [Color(0.78, 0.68, 0.42)]

## Type: name, who, top (Game.TOPS: 0 jacket, 1 rolled, 2 tee, 3 bare = tank top for a woman),
## colours of the top / trousers / shoes, headgear (Game.HEADGEAR index; 2 = none) and its colours
## (with a chance), neck scarf (chance + colours), hair styles, beards, grey hair (chance).
const TYPES := {
	"town": [
		{"id": "urednik", "name": "Úředník", "female": false, "top": [0], "top_c": SUIT, "pants_c": DARK, "shoes": SHOES,
			"hair": ["short", "short", "none"], "beard": [0, 0, 2], "grey": 0.35},
		{"id": "kosile", "name": "Pán v košili", "female": false, "top": [1], "top_c": SHIRT, "pants_c": BEIGE + DARK, "shoes": SHOES,
			"hair": ["short", "buzz", "none"], "beard": [0, 1, 2], "grey": 0.25},
		{"id": "mladik", "name": "Mladík", "female": false, "top": [2], "top_c": TEE, "pants_c": JEANS, "shoes": SNEAKER,
			"hair": ["short", "long", "buzz", "mohawk"], "beard": [0, 0, 1], "grey": 0.0},
		{"id": "pani", "name": "Paní v kabátku", "female": true, "top": [0], "top_c": COAT_F, "pants_c": DARK, "shoes": SHOES,
			"hair": ["bun", "long", "short"], "neck": 0.45, "neck_c": SCARF, "grey": 0.25},
		{"id": "divka", "name": "Dívka", "female": true, "top": [2, 3], "top_c": TOP_F + TEE, "pants_c": JEANS, "shoes": SNEAKER,
			"hair": ["pony", "long", "long"], "grey": 0.0},
	],
	"village": [
		{"id": "farmar", "name": "Farmář", "female": false, "top": [1], "top_c": FLANNEL, "pants_c": WORK, "shoes": WELLIES,
			"hair": ["buzz", "short"], "beard": [0, 1, 2, 2], "head": 1, "head_p": 0.75, "head_c": CAPS, "grey": 0.3},
		{"id": "deda", "name": "Děda", "female": false, "top": [0], "top_c": OLD, "pants_c": OLD, "shoes": SHOES,
			"hair": ["short", "none"], "beard": [2, 2, 4, 1], "head": 4, "head_p": 0.7, "head_c": HATS, "grey": 1.0},
		{"id": "traktorista", "name": "Traktorista", "female": false, "top": [2], "top_c": [Color(0.86, 0.86, 0.84), Color(0.5, 0.52, 0.5)] + [Color(0.7, 0.13, 0.12)],
			"pants_c": WORK, "shoes": WELLIES + SHOES, "hair": ["buzz", "short", "long"], "beard": [0, 1, 2], "head": 1, "head_p": 0.4, "head_c": CAPS, "grey": 0.1},
		{"id": "babicka", "name": "Vesničanka v šátku", "female": true, "top": [0, 1], "top_c": PASTEL + [Color(0.34, 0.25, 0.16), Color(0.3, 0.32, 0.22)], "pants_c": DARK, "shoes": SHOES + WELLIES,
			"hair": ["bun"], "head": 5, "head_p": 0.9, "head_c": SCARF, "grey": 0.6},
		{"id": "vesnicanka", "name": "Mladá vesničanka", "female": true, "top": [1, 2], "top_c": FLANNEL + PASTEL, "pants_c": JEANS + WORK, "shoes": WELLIES + SNEAKER,
			"hair": ["pony", "long", "bun"], "head": 4, "head_p": 0.3, "head_c": STRAW, "grey": 0.0},
	],
}

## Where people dress like the town and where like the village.
static func place_of(biome: String) -> String:
	return "town" if biome in ["town", "industrial", "base"] else "village"

static func _pick(r: RandomNumberGenerator, a: Array):
	return a[r.randi() % a.size()]

## A civilian's look for this place, from his own number (the same on every machine).
## sex: "" any type, "m" / "f" only men / women (the one to rescue is the person from the briefing).
static func make(place: String, seed_: int, sex := "") -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = seed_ * 7919 + 13
	var list: Array = TYPES.get(place, TYPES["village"])
	if sex != "":
		list = list.filter(func(t): return bool(t["female"]) == (sex == "f"))
	var t: Dictionary = list[r.randi() % list.size()]
	return make_type(t, r)

static func make_type(t: Dictionary, r: RandomNumberGenerator) -> Dictionary:
	var female: bool = t["female"]
	var grey := r.randf() < float(t.get("grey", 0.0))
	var look := {
		"female": female, "skin": r.randi() % 3 if r.randf() < 0.85 else 3 + r.randi() % 2,
		"hair": _pick(r, t["hair"]), "hair_color": (7 + r.randi() % 2) if grey else r.randi() % 6,
		"eye_color": r.randi() % 6, "beard": 0 if female else int(_pick(r, t.get("beard", [0]))),
		"top": int(_pick(r, t["top"])), "pants": 2, "vest": 3, "headgear": 2, "glasses": 0, "flag": "",
		"neck": 0, "paint": 0, "tattoo": 0, "mouth": 0,
	}
	if t.has("head") and r.randf() < float(t.get("head_p", 1.0)):
		look["headgear"] = int(t["head"])
	if r.randf() < float(t.get("neck", 0.0)):
		look["neck"] = 1
	var cols := {
		"top": _pick(r, t["top_c"]), "pants": _pick(r, t["pants_c"]), "shoes": _pick(r, t["shoes"]),
		"head": _pick(r, t.get("head_c", [Color.GRAY])), "neck": _pick(r, t.get("neck_c", SCARF)),
	}
	return {"type": t["id"], "name": t["name"], "look": look, "cols": cols}

## Dress a merc.glb: the soldier's look, then nothing military on him and the clothes repainted.
static func dress(model: Node, d: Dictionary) -> void:
	var look: Dictionary = d["look"]
	Game.apply_look(model, look)
	var cols: Dictionary = d["cols"]
	var top_c: Color = cols["top"]
	var mats := {}
	var m := func(c: Color) -> Material:
		var key := c.to_html()
		if not mats.has(key):
			mats[key] = Game.color_mat(c)
		return mats[key]
	var leather: Material = m.call(Color(0.22, 0.14, 0.08))
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var nm := String(mi.name)
		if nm.begins_with("Gear_") and not nm in ["Gear_Cap", "Gear_Boonie", "Gear_Bandana"]:
			mi.visible = false               # (no pouches, belt kit, helmet, torch)
		if nm.begins_with("Look_Patch") or nm.begins_with("Look_Flag_") or nm.begins_with("Look_Armband") \
				or nm == "Look_PantsCargo" or nm == "Look_KneePads" or nm.begins_with("Look_Vest"):
			mi.visible = false               # (no badges of the project, no army trousers)
		for i in mi.mesh.get_surface_count():
			var src: Material = mi.mesh.surface_get_material(i)
			if src == null:
				continue
			var mn := String(src.resource_name)
			if nm.begins_with("Look_Top"):
				if mn in ["Uniform", "Tee"]:
					mi.set_surface_override_material(i, m.call(top_c))
				elif mn == "Webbing":
					mi.set_surface_override_material(i, m.call(top_c.darkened(0.25)))
			elif nm == "Body":
				match mn:
					"Uniform": mi.set_surface_override_material(i, m.call(cols["pants"]))
					"Boots", "Sole": mi.set_surface_override_material(i, m.call(cols["shoes"] if mn == "Boots" else (cols["shoes"] as Color).darkened(0.4)))
					"Webbing": mi.set_surface_override_material(i, leather)     # a belt
					"Glove": mi.set_surface_override_material(i, leather)       # the watch strap
					"IdLight": mi.set_surface_override_material(i, m.call(Color(0.1, 0.1, 0.1)))
			elif nm == "Look_Female" and mn == "Boots":
				mi.set_surface_override_material(i, m.call(cols["shoes"]))
			elif nm in ["Gear_Cap", "Gear_Boonie"]:
				mi.set_surface_override_material(i, m.call(cols["head"] if mn == "Uniform" else (cols["head"] as Color).darkened(0.35)))
			elif nm == "Gear_Bandana" or (nm.begins_with("Look_Neck") and mn in ["Scarf", "ScarfLine"]):
				var sc: Color = cols["head"] if nm == "Gear_Bandana" else cols["neck"]
				mi.set_surface_override_material(i, m.call(sc if mn != "ScarfLine" else sc.lightened(0.3)))

## Lay a dressed merc.glb dead on the ground (the Líhavec's meal): the last pose of one of Ari's
## civilian deaths; without the clips (public repo) the model is just tipped over on its back.
static func lie_dead(model: Node3D, pick: int) -> void:
	var ap: Node = model.find_child("AnimationPlayer", true, false)
	if ap:
		ap.get_parent().remove_child(ap)
		ap.free()
	var sk: Skeleton3D = model.find_child("Skeleton3D", true, false)
	var c := AnimClips.get_clip("al_civ_a_death_%d" % (1 + absi(pick) % 9)) if sk else {}
	if c.is_empty():
		model.rotation.x = -PI / 2
		model.position.y += 0.12
		return
	var t := float(c.get("delka", 1.0))
	var p := AnimClips.pose(c, t)
	for bn in p:
		var i := sk.find_bone(bn)
		if i >= 0:
			sk.set_bone_pose_rotation(i, sk.get_bone_rest(i).basis.get_rotation_quaternion() * Quaternion.from_euler(p[bn]))
	if AnimClips.has_track(c, "root@pos"):
		var ri := sk.find_bone("root")
		if ri >= 0:
			var v := AnimClips.sample(c, "root@pos", t)
			sk.set_bone_pose_position(ri, sk.get_bone_rest(ri).origin + Vector3(float(v[0]), float(v[1]), float(v[2])))
