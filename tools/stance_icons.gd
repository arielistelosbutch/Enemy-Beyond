extends SceneTree
## 0.57: the HUD's stance pictures - our mercenary (merc.glb) posed by the game's own movements
## (Mixamo clips in animace/), all white, seen from the side, on a transparent background.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . -s tools/stance_icons.gd
## Writes res://assets/icons/stance_<name>.png (the HUD tints them).

const SIZE := Vector2i(96, 96)
## name: [clip, time, lying (the model is turned onto its belly, as the player does it)]
const POSES := {"stand": ["tp_body_idle_aim", 0.4, false], "crouch": ["tp_body_crouch_aim", 0.4, false],
	"prone": ["tp_body_prone", 0.5, true], "sprint": ["tp_body_sprint", 0.25, false], "downed": ["tp_body_crawl_idle", 0.5, false],
	"winded": ["tp_body_idle", 0.6, false]}

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/icons"))
	var sv := SubViewport.new()
	sv.transparent_bg = true
	sv.own_world_3d = true
	sv.msaa_3d = Viewport.MSAA_4X
	sv.size = SIZE * 4
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(sv)
	var root3 := Node3D.new()
	sv.add_child(root3)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.4
	root3.add_child(cam)
	RenderingServer.set_default_clear_color(Color(0, 0, 0, 0))
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.albedo_color = Color(1, 1, 1)
	var only := OS.get_cmdline_user_args()
	await process_frame
	for name in POSES:
		if not only.is_empty() and not name in only:
			continue
		var e: Array = POSES[name]
		var m: Node3D = load("res://assets/models/merc.glb").instantiate()
		root3.add_child(m)
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = white
		var sk: Skeleton3D = m.find_children("*", "Skeleton3D", true, false)[0]
		var clip := AnimClips.get_clip(String(e[0]))
		if clip.is_empty():
			clip = AnimClips.get_clip(String(e[0]).replace("_aim", ""))
		var p := AnimClips.pose(clip, AnimClips.clip_time(clip, float(e[1]) * float(clip.get("delka", 1.0))))
		for bn in p:
			var i := sk.find_bone(bn)
			if i >= 0:
				var rest: Quaternion = sk.get_bone_rest(i).basis.get_rotation_quaternion()
				sk.set_bone_pose_rotation(i, rest * Quaternion.from_euler(p[bn]))
		var lying: bool = e[2] and not bool(clip.get("vlastni_poloha", false))
		if lying:
			m.rotation.x = -PI / 2
			m.position = Vector3(0, 0.18, 0.9)
		# from the left side: he faces to the right of the picture
		var c := Vector3(0, 0.95, 0.2)
		cam.look_at_from_position(c + Vector3(-6.0, 0, 0), c, Vector3.UP)
		for f in 4:
			await process_frame
		var shot := sv.get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		# the same scale for every pose: centred left-right, standing on the bottom edge
		var used := shot.get_used_rect()
		var img := Image.create(shot.get_width(), shot.get_height(), false, Image.FORMAT_RGBA8)
		var dst := Vector2i((img.get_width() - used.size.x) / 2, img.get_height() - used.size.y - 8)
		img.blit_rect(shot, used, dst)
		img.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
		img.save_png("res://assets/icons/stance_%s.png" % name)
		print("stance ", name, " clip ", e[0], " lying ", lying)
		m.queue_free()
		await process_frame
	quit()
