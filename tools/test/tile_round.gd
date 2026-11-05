extends Node3D
## Every kind of map block: built by the generator, taken down into data (MapPieces.capture), through
## JSON and built again from the data - both must come out the same (parts, places, notes).
## --kinds=a,b  --seed=N

func _ready() -> void:
	_run.call_deferred()

func _sig(mg, nav: Node3D) -> Dictionary:
	var parts := []
	var counts := {}
	for n in nav.find_children("*", "", true, false):
		if n is MultiMeshInstance3D:
			continue
		var c: String = n.get_class()
		counts[c] = counts.get(c, 0) + 1
		if n is MeshInstance3D and (n as MeshInstance3D).is_visible_in_tree():
			var a: AABB = (n as MeshInstance3D).global_transform * (n as MeshInstance3D).get_aabb()
			parts.append("%.2f,%.2f,%.2f/%.2f,%.2f,%.2f" % [a.position.x, a.position.y, a.position.z, a.size.x, a.size.y, a.size.z])
		if n is Light3D:
			parts.append("L%.2f,%.2f,%.2f" % [(n as Light3D).global_position.x, (n as Light3D).global_position.y, (n as Light3D).global_position.z])
	parts.sort()
	var notes := {}
	for key in mg.info:
		var v = mg.info[key]
		if v is Array:
			notes[key] = (v as Array).size()
		elif v is Vector3 and v != Vector3.ZERO:
			notes[key] = "%.2f,%.2f,%.2f" % [v.x, v.y, v.z]
	return {"counts": counts, "parts": parts, "notes": notes}

func _close(x: String, y: String) -> bool:
	if x.left(1) != y.left(1):
		return false
	var xs := x.trim_prefix("L").replace("/", ",").split(",")
	var ys := y.trim_prefix("L").replace("/", ",").split(",")
	if xs.size() != ys.size():
		return false
	for i in xs.size():
		if absf(float(xs[i]) - float(ys[i])) > 0.03:
			return false
	return true

func _gen() -> Variant:
	var mg = load("res://scripts/map_gen.gd").new()
	var nav := Node3D.new()
	add_child(nav)
	mg.root = nav
	mg.rng.seed = int(Game.cmd_arg("seed", "5"))
	mg.N = 7
	mg.info["size"] = 84.0
	return mg

func _run() -> void:
	var only := Game.cmd_arg("kinds", "")
	var ok := 0
	var bad := 0
	var o := Vector3(24, 0, 36)
	for k in MapPieces.KINDS:
		if only != "" and not k in only.split(","):
			continue
		var spec: Array = MapPieces.KINDS[k]
		var mg0 = _gen()
		mg0.callv(String(spec[0]), [o] + (spec[1] as Array))
		var a := _sig(mg0, mg0.root)
		var mg1 = _gen()
		var d := MapPieces.capture(mg1, k, o)
		var js := JSON.stringify(d)
		var d2 = JSON.parse_string(js)
		var mg2 = _gen()
		MapPieces.build(mg2, d2, o)
		var b := _sig(mg2, mg2.root)
		var diffs := []
		for key in a["counts"]:
			if a["counts"][key] != b["counts"].get(key, 0):
				diffs.append("%s %d->%d" % [key, a["counts"][key], b["counts"].get(key, 0)])
		for key in b["counts"]:
			if not a["counts"].has(key):
				diffs.append("%s 0->%d" % [key, b["counts"][key]])
		for key in a["notes"]:
			if str(a["notes"][key]) != str(b["notes"].get(key, "")):
				diffs.append("note %s %s->%s" % [key, a["notes"][key], b["notes"].get(key, "-")])
		var pa: Array = a["parts"]
		var pb: Array = b["parts"]
		var used := {}
		var miss := 0
		var first_miss := ""
		for x in pa:
			var found := false
			for j in pb.size():
				if not used.has(j) and _close(String(x), String(pb[j])):
					used[j] = true
					found = true
					break
			if not found:
				miss += 1
				if first_miss == "":
					first_miss = x
		if miss > 0:
			diffs.append("%d of %d parts elsewhere (e.g. %s)" % [miss, pa.size(), first_miss])
		print("[ROUND] %s: %d parts, %d bytes %s" % [k, (d["prvky"] as Array).size(), js.length(), "OK" if diffs.is_empty() else "DIFF " + "; ".join(diffs)])
		if diffs.is_empty():
			ok += 1
		else:
			bad += 1
		for m in [mg0, mg1, mg2]:
			m.root.free()
	print("RESULT tileround ok %d bad %d" % [ok, bad])
	get_tree().quit()
