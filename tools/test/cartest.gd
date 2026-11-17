extends SceneTree
## Car windows (Ari 13./17. 11.): the windscreen and the rear window must lean in with the pillars in
## the MODEL itself (tools/blender/car_windows.py), not only through a Dílna edit - wherever the edit
## was not applied they leaned out over the bonnet / the boot. Also: car glass is the tinted one.
##   godot --headless --path . -s tools/test/cartest.gd   -> "RESULT cartest ok"
func _initialize() -> void:
	await process_frame
	var bad := []
	for cn in ["v_car_red", "v_car_blue", "v_car_beige"]:
		var n: Node3D = load("res://assets/models/%s.glb" % cn).instantiate()
		for mi in n.find_children("Auto_*", "MeshInstance3D", true, false):
			var mesh: Mesh = (mi as MeshInstance3D).mesh
			for it in ModelMods.islands(mesh):
				var mat := mesh.surface_get_material(it["surf"])
				var box: AABB = it["box"]
				if mat == null or mat.resource_name != "VCarGlass" or box.size.x < 1.0:
					continue     # only the panes across the car
				var v: PackedVector3Array = mesh.surface_get_arrays(it["surf"])[Mesh.ARRAY_VERTEX]
				var front: bool = box.get_center().z < 0.0
				var top := Vector2(-1, 0)    # (y, z) of the highest and the lowest point
				var low := Vector2(9, 0)
				for i in it["tris"]:
					var p := v[i]
					if p.y > top.x: top = Vector2(p.y, p.z)
					if p.y < low.x: low = Vector2(p.y, p.z)
				# front pane: top further back (bigger z) than the foot; rear pane: the other way
				var lean := (top.y - low.y) if front else (low.y - top.y)
				print("[CAR] %s %s lean %.2f m over %.2f m" % [cn, "front" if front else "rear", lean, top.x - low.x])
				if lean < 0.15:
					bad.append("%s %s" % [cn, "front" if front else "rear"])
		n.free()
		var mods: Dictionary = root.get_node("Game").model_mods.get(cn, {})
		for k in mods.get("parts", {}):
			if String(k).ends_with(":85") or String(k).ends_with(":86"):
				bad.append("%s still turns %s in modely/" % [cn, k])
		var m: Node3D = root.get_node("Game").model(cn)
		var tinted := false
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			for s in (mi as MeshInstance3D).mesh.get_surface_count():
				if (mi as MeshInstance3D).get_surface_override_material(s) == root.get_node("Game").car_glass_mat():
					tinted = true
		if not tinted:
			bad.append("%s glass not tinted" % cn)
		m.free()
	print("RESULT cartest %s" % ("ok" if bad.is_empty() else "BAD " + ", ".join(bad)))
	quit()
