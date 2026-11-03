extends SceneTree
## Alien pose check: godot --path . -s tools/test/alienpose.gd -- out.png model rootdy 'bone=x,y,z;...' ['...']
## Each pose is rendered from the front-side and from the side.
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var model: String = args[1]
	var dy := float(args[2])
	var root3 := Node3D.new()
	get_root().add_child(root3)
	var m: Node3D = load("res://assets/models/%s.glb" % model).instantiate()
	root3.add_child(m)
	var sk: Skeleton3D = m.find_child("Skeleton3D", true, false)
	var cam := Camera3D.new()
	root3.add_child(cam)
	var l := DirectionalLight3D.new()
	root3.add_child(l)
	l.rotation_degrees = Vector3(-30, 20, 0)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.5, 0.55, 0.6)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.7, 0.7)
	env.environment = e
	root3.add_child(env)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(4, 4)
	floor.mesh = pm
	root3.add_child(floor)
	await process_frame
	var imgs := []
	for sh in args.slice(3):
		sk.reset_bone_poses()
		for part in String(sh).split(";"):
			if part.strip_edges() == "":
				continue
			var kv := part.split("=")
			var v := kv[1].split(",")
			var bi := sk.find_bone(kv[0])
			if bi >= 0:
				var rest := sk.get_bone_rest(bi).basis.get_rotation_quaternion()
				sk.set_bone_pose_rotation(bi, rest * Quaternion.from_euler(Vector3(float(v[0]), float(v[1]), float(v[2]))))
		var ri := sk.find_bone("root")
		if ri >= 0:
			sk.set_bone_pose_position(ri, sk.get_bone_rest(ri).origin + Vector3(0, dy, 0))
		for view in [Vector3(-0.9, 1.0, -1.4), Vector3(1.7, 0.9, 0)]:
			cam.position = view
			cam.look_at(Vector3(0, 0.6, 0))
			for f in 3:
				await process_frame
			imgs.append(get_root().get_texture().get_image())
	var w: int = imgs[0].get_width()
	var h: int = imgs[0].get_height()
	var rows := imgs.size() / 2
	var big := Image.create(w * 2, h * rows, false, imgs[0].get_format())
	for i in imgs.size():
		big.blit_rect(imgs[i], Rect2i(0, 0, w, h), Vector2i((i % 2) * w, (i / 2) * h))
	big.save_png(out)
	quit()
