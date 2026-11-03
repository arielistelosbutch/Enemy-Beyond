extends SceneTree
## Quick pose check: godot --path . -s tools/test/bonetest.gd -- out.png 'bone=x,y,z;bone=x,y,z' ...
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var root3 := Node3D.new()
	get_root().add_child(root3)
	var m: Node3D = load("res://assets/models/merc.glb").instantiate()
	root3.add_child(m)
	var sk: Skeleton3D = m.find_child("Skeleton3D", true, false)
	var ap: AnimationPlayer = m.find_child("AnimationPlayer", true, false)
	if ap and ap.has_animation("idle"):
		ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		ap.play("idle")
		ap.advance(0.1)
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
	e.ambient_light_color = Color(0.6, 0.6, 0.6)
	env.environment = e
	root3.add_child(env)
	var shots := []
	for a in args.slice(1):
		shots.append(a)
	var out: String = args[0]
	await process_frame
	var imgs := []
	for sh in shots:
		if ap:
			ap.seek(0.1, true)
		for part in String(sh).split(";"):
			if part.strip_edges() == "":
				continue
			var kv := part.split("=")
			var v := kv[1].split(",")
			var bi := sk.find_bone(kv[0])
			if bi >= 0:
				var rest := sk.get_bone_rest(bi).basis.get_rotation_quaternion()
				sk.set_bone_pose_rotation(bi, rest * Quaternion.from_euler(Vector3(float(v[0]), float(v[1]), float(v[2]))))
		for view in [Vector3(0, 1.35, 1.25), Vector3(1.25, 1.35, 0)]:
			cam.position = view
			cam.look_at(Vector3(0, 1.25, 0))
			await process_frame
			await process_frame
			await process_frame
			imgs.append(get_root().get_texture().get_image())
	var w: int = imgs[0].get_width()
	var h: int = imgs[0].get_height()
	var big := Image.create(w * 2, h * shots.size(), false, imgs[0].get_format())
	for i in imgs.size():
		big.blit_rect(imgs[i], Rect2i(0, 0, w, h), Vector2i((i % 2) * w, (i / 2) * h))
	big.save_png(out)
	quit()
