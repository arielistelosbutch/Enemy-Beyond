extends Node3D
## What the map's blocks are made of: builds each kind of block alone and counts the node types,
## meshes and the map notes (info) it leaves. --kinds=a,b (default all)

const KINDS := ["field", "dunes", "meadow", "pasture", "forest", "house", "barn", "chapel", "house2", "ruin", "garden",
	"orchard", "stream", "rocks", "cabin", "warehouse", "containers", "tanks", "yard", "fuel", "hangar", "barracks", "radar",
	"sandbags", "shop", "pub", "park", "parking", "icelake", "icespires", "polarhut", "open", "road", "street"]

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var only := Game.cmd_arg("kinds", "")
	var total := {}
	for k in KINDS:
		if only != "" and not k in only.split(","):
			continue
		var mg = load("res://scripts/map_gen.gd").new()
		var nav := Node3D.new()
		add_child(nav)
		mg.root = nav
		mg.rng.seed = 7
		var before := {}
		for key in mg.info:
			before[key] = (mg.info[key] as Array).size() if mg.info[key] is Array else -1
		var fn: String = "_" + k
		if k == "radar": fn = "_radar_tower"
		if k == "polarhut": fn = "_polar_hut"
		mg.call(fn, Vector3.ZERO)
		var counts := {}
		for n in nav.find_children("*", "", true, false):
			var c: String = n.get_class()
			if n is MeshInstance3D and (n as MeshInstance3D).mesh:
				c += ":" + (n as MeshInstance3D).mesh.get_class()
			if n.get_script():
				c += "+script"
			counts[c] = counts.get(c, 0) + 1
			total[c] = total.get(c, 0) + 1
		var notes := []
		for key in mg.info:
			if mg.info[key] is Array and (mg.info[key] as Array).size() != before.get(key, 0):
				notes.append("%s+%d" % [key, (mg.info[key] as Array).size() - before.get(key, 0)])
			elif not mg.info[key] is Array and not before.has(key):
				notes.append(key)
			elif mg.info[key] is Vector3 and mg.info[key] != Vector3.ZERO:
				notes.append(key)
		var top := []
		for n in nav.get_children():
			top.append(n.get_class())
		print("[TILE] %s: %d top nodes; %s; notes %s" % [k, nav.get_child_count(), JSON.stringify(counts), notes])
		nav.free()
	print("[TILE] ALL ", JSON.stringify(total))
	print("RESULT tilesurvey")
	get_tree().quit()
