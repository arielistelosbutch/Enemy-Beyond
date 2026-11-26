extends SceneTree
## Forklift (Ari 22. 11.: „ještěrka má divná kolečka"): the yard forklift is the model v_forklift
## (tools/blender/street.py) - round tyres, mast, forks, overhead guard - not the old black boxes, in
## the generator (map_gen._forklift) and in the saved tile (dilky/yard/yard.json). Collision follows
## the model (FitCollision.WHOLE): the tyres, the mast, a fork and the guard roof stop a ray where
## you see them, the open cab between the guard posts does not.
##   godot --headless --path . -s tools/test/forklifttest.gd   -> "RESULT forklifttest ok"
##   with a window (xvfb) it also saves user://forklift_0..2.png
func _initialize() -> void:
	await process_frame
	var bad := []
	# the saved tile: one model, none of the old boxes
	var f := FileAccess.open("res://dilky/yard/yard.json", FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	var models := 0
	for e in d["prvky"]:
		if e.get("k") == "model" and e.get("n") == "v_forklift":
			models += 1
		if e.get("k") == "box" and e.get("s") in [[1.1, 0.7, 1.7], [0.22, 0.6, 0.6], [1.1, 0.06, 1.2]]:
			bad.append("yard.json still has the box forklift")
	if models != 1:
		bad.append("yard.json forklift models %d" % models)
	var src := FileAccess.get_file_as_string("res://scripts/map_gen.gd")
	var a := src.find("func _forklift(")
	var body := src.substr(a, src.find("\nfunc ", a + 10) - a)
	if body.find("_prop(\"forklift\"") < 0 or body.find("box(") >= 0:
		bad.append("map_gen._forklift is not the model")
	# the model and its collision
	var world := Node3D.new()
	root.add_child(world)
	var n: Node3D = root.get_node("Game").model("v_forklift")
	world.add_child(n)
	load("res://scripts/fit_collision.gd").fit(n)      # (by load: a -s script compiles before the class names)
	var shapes := n.find_children("*", "CollisionShape3D", true, false).size()
	print("[FORK] collision pieces %d" % shapes)
	if shapes < 20:
		bad.append("collision pieces %d" % shapes)
	await physics_frame
	await physics_frame
	var space := world.get_world_3d().direct_space_state
	# [name, from, to, expected distance or -1 = must not hit before the far side]
	var rays := [
		["front tyre", Vector3(2.0, 0.31, -0.45), Vector3(0, 0.31, -0.45), 2.0 - 0.68],
		["rear tyre", Vector3(-2.0, 0.25, 0.75), Vector3(0, 0.25, 0.75), 2.0 - 0.66],
		["tyre round (top front)", Vector3(0.56, 0.55, -2.0), Vector3(0.56, 0.55, 0), 2.0 - 0.67],
		["mast", Vector3(0.36, 1.9, -3.0), Vector3(0.36, 1.9, 0), 3.0 - 0.84],
		["fork tine", Vector3(1.5, 0.1, -1.5), Vector3(-1.5, 0.1, -1.5), 1.5 - 0.34],
		["guard roof", Vector3(0, 3.0, 0.22), Vector3(0, 0, 0.22), 3.0 - 2.2],
		["open cab", Vector3(2.0, 1.75, 0.0), Vector3(-2.0, 1.75, 0.0), -1.0],
	]
	for r in rays:
		var q := PhysicsRayQueryParameters3D.create(r[1], r[2])
		var hit := space.intersect_ray(q)
		var dist: float = (hit["position"] - r[1]).length() if hit else -1.0
		print("[FORK] %s hit %.2f (want %.2f)" % [r[0], dist, r[3]])
		if r[3] < 0.0:
			if hit:
				bad.append("%s blocked at %.2f" % [r[0], dist])
		elif not hit or absf(dist - r[3]) > 0.12:
			bad.append("%s %.2f" % [r[0], dist])
	if DisplayServer.get_name() != "headless":
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = Color(0.25, 0.28, 0.33)
		env.environment.ambient_light_color = Color(0.5, 0.5, 0.55)
		world.add_child(env)
		var sun := DirectionalLight3D.new()
		sun.rotation = Vector3(-0.8, 0.6, 0)
		world.add_child(sun)
		var ground := MeshInstance3D.new()
		ground.mesh = PlaneMesh.new()
		(ground.mesh as PlaneMesh).size = Vector2(12, 12)
		world.add_child(ground)
		var cam := Camera3D.new()
		world.add_child(cam)
		cam.current = true
		var i := 0
		for at in [Vector3(3.2, 2.0, -3.4), Vector3(-3.6, 1.7, 2.6), Vector3(4.0, 1.2, 0.2)]:
			cam.position = at
			cam.look_at(Vector3(0, 0.9, -0.2))
			for k in 4:
				await process_frame
			root.get_viewport().get_texture().get_image().save_png("user://forklift_%d.png" % i)
			i += 1
	print("RESULT forklifttest %s" % ("ok" if bad.is_empty() else "BAD " + ", ".join(bad)))
	quit()
