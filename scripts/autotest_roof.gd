extends RefCounted
## (Ari 17. 11.) Roofs you fell through: every flat slab overhead (fuel station canopy, ceilings,
## porch roofs - map_gen._roof_slab, recorded in map["roof_slabs"]) must stop a ray from above
## at its top. --autotest=rooftest --mtype=terror --biome=town [--seed=N]
##   RESULT rooftest slabs N holes 0
static func run(at: Node, p: Node) -> void:
	at._skip_brief()
	if p == null or at.step > 0 or not at.m().started():
		return
	at.step = 1
	for f in 4: await at.get_tree().physics_frame
	var map: Dictionary = at.m().map
	var slabs: Array = map.get("roof_slabs", [])
	var space: PhysicsDirectSpaceState3D = (p as Node3D).get_world_3d().direct_space_state
	var holes := 0
	for sl in slabs:
		var top: Vector3 = sl[0]
		var size: Vector3 = sl[1]
		var ok := false
		# the middle and four points towards the corners
		for d in [Vector2.ZERO, Vector2(0.3, 0.3), Vector2(-0.3, 0.3), Vector2(0.3, -0.3), Vector2(-0.3, -0.3)]:
			var at_p := top + Vector3(d.x * size.x, 0, d.y * size.z)
			var q := PhysicsRayQueryParameters3D.create(at_p + Vector3(0, 1.2, 0), at_p + Vector3(0, -0.5, 0), Game.WORLD)
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				ok = false
				break
			ok = true
		if not ok:
			holes += 1
			if holes <= 10:
				at.out("[ROOF] hole at %s size %s" % [top, size])
	at.out("RESULT rooftest slabs %d holes %d" % [slabs.size(), holes])
	at.get_tree().quit()
