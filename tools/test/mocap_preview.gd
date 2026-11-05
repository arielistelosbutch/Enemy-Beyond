extends Node3D
## Trial of Mixamo movements on the merc (no game files are touched): the Mixamo man on one side,
## our merc with the converted movement on the other, frame by frame into PNGs.
## --fbx=<file or folder> [--only=a,b] --out=<folder> [--fps=15] [--size=WxH]

var cam: Camera3D
var _err_sum := 0.0
var _err_n := 0
var _err_max := 0.0
var _err_max_b := {}
var lbl: Label

func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.16, 0.17, 0.19)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.57, 0.6)
	e.ambient_light_energy = 0.9
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 150, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12, 12)
	floor.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.32, 0.33, 0.3)
	floor.material_override = fm
	add_child(floor)
	cam = Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	cam.position = Vector3(1.0, 1.6, -4.8)
	cam.look_at(Vector3(0, 0.8, 0), Vector3.UP)
	var ui := CanvasLayer.new()
	add_child(ui)
	lbl = Label.new()
	lbl.position = Vector2(12, 8)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 5)
	ui.add_child(lbl)
	_run.call_deferred()

## The Mixamo skeleton as sticks (the files come without the body).
var _stick := {}
func _sticks(ss: Skeleton3D, holder: Node3D) -> void:
	var xf := ss.global_transform
	for i in ss.get_bone_count():
		var nm := ss.get_bone_name(i)
		var pi := ss.get_bone_parent(i)
		if pi < 0 or nm.contains("Hand") and not nm.ends_with("Hand") or nm.contains("Eye") or nm.contains("Toe_End"):
			continue
		var a := xf * ss.get_bone_global_pose(pi).origin
		var b := xf * ss.get_bone_global_pose(i).origin
		if not _stick.has(i):
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.05, 0.05, 1.0)
			mi.mesh = bm
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.95, 0.55, 0.2) if nm.contains("Left") else (Color(0.3, 0.7, 1.0) if nm.contains("Right") else Color(0.85, 0.85, 0.85))
			mi.material_override = m
			add_child(mi)
			_stick[i] = mi
		var st: MeshInstance3D = _stick[i]
		var d := b - a
		if d.length() < 1e-4:
			st.visible = false
			continue
		st.visible = true
		var up := Vector3.UP if absf(d.normalized().dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
		st.global_transform = Transform3D(Basis.looking_at(d, up).scaled_local(Vector3(1, 1, d.length())), (a + b) * 0.5)

func _files() -> Array:
	var src := Game.cmd_arg("fbx", "")
	var only := Game.cmd_arg("only", "")
	var out := []
	if src.ends_with(".fbx"):
		out.append(src)
	else:
		for f in DirAccess.get_files_at(src):
			if f.ends_with(".fbx") and not f.begins_with("copzombie"):
				if only == "" or f.trim_suffix(".fbx") in only.split(","):
					out.append(src.path_join(f))
	return out

func _run() -> void:
	var outdir := Game.cmd_arg("out", "user://mocap")
	var fps := float(Game.cmd_arg("fps", "15"))
	DirAccess.make_dir_recursive_absolute(outdir)
	var target: Node3D = Game.model("merc")
	add_child(target)
	target.visible = false
	var tsk: Skeleton3D = target.find_child("Skeleton3D", true, false)
	var merc: Node3D = Game.model("merc")
	merc.scale = Vector3(-1, 1, 1)
	merc.position = Vector3(0.75, 0, 0)
	add_child(merc)
	Game.apply_look(merc, Game.merc.get("look", {}))
	var map := merc.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if map:
		map.stop()
	var msk: Skeleton3D = merc.find_child("Skeleton3D", true, false)
	var n := 0
	for path in _files():
		var nm := String(path).get_file().trim_suffix(".fbx")
		var holder := Node3D.new()
		add_child(holder)
		var sc := Mocap.load_fbx(path, holder)
		if sc == null:
			print("[MOCAP] cannot read ", path)
			holder.queue_free()
			continue
		var t0 := Time.get_ticks_msec()
		var travel := false
		for w in ["walk", "run", "sprint", "crawl", "prone", "strafe"]:
			if nm.to_lower().contains(w):
				travel = true
		var clip := Mocap.convert(sc, tsk, nm, travel)
		var keys := 0
		for tr in clip.get("stopy", {}):
			keys += (clip["stopy"][tr] as Array).size()
		print("[MOCAP] %s: %.2f s, %d keys, converted in %d ms" % [nm, float(clip.get("delka", 0)), keys, Time.get_ticks_msec() - t0])
		var f := FileAccess.open(outdir.path_join(nm + ".json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(clip, " ", false))
		f.close()
		# the Mixamo man: turned round to face the same way as ours, scaled to our size
		var ss: Skeleton3D = sc.find_children("*", "Skeleton3D", true, false)[0]
		var ap: AnimationPlayer = sc.find_children("*", "AnimationPlayer", true, false)[0]
		var hips := -1
		for i in ss.get_bone_count():
			if ss.get_bone_name(i).ends_with("Hips"):
				hips = i
		var k: float = 0.95 / maxf(0.01, ss.get_bone_global_rest(hips).origin.y)
		holder.scale = Vector3.ONE * k
		holder.rotation.y = PI
		var an := Mocap.main_anim(ap)
		ap.play(an)
		var L: float = ap.get_animation(an).length
		ap.seek(0.0, true)
		var h0 := ss.get_bone_global_pose(hips).origin
		ap.seek(L, true)
		var h1 := ss.get_bone_global_pose(hips).origin
		var frames := maxi(2, int(ceil(L * fps)) + 1)
		var sub := outdir.path_join(nm)
		DirAccess.make_dir_recursive_absolute(sub)
		for fr in frames:
			var t := minf(L, fr / fps)
			ap.seek(t, true)
			var trend: Vector3 = (h0.lerp(h1, t / maxf(L, 0.001)) - h0) if travel else Vector3.ZERO
			trend.y = 0.0
			holder.position = Vector3(-0.75, 0, 0) - holder.basis * (trend)
			_sticks(ss, holder)
			# ours
			var pose := AnimClips.pose(clip, t)
			for b in pose:
				var bi := msk.find_bone(b)
				if bi >= 0:
					msk.set_bone_pose_rotation(bi, msk.get_bone_rest(bi).basis.get_rotation_quaternion() * Quaternion.from_euler(pose[b]))
			var rp := AnimClips.sample(clip, "root@pos", t)
			if rp.size() >= 3:
				var ri := msk.find_bone("root")
				msk.set_bone_pose_position(ri, msk.get_bone_rest(ri).origin + Vector3(float(rp[0]), float(rp[1]), float(rp[2])))
			# check: does each of our limbs point where the Mixamo one does (both as seen in the world)?
			for b in ["spine", "upperarm.L", "forearm.L", "upperarm.R", "forearm.R", "thigh.L", "shin.L", "thigh.R", "shin.R"]:
				var m: Array = Mocap.MAP[b]
				var s0 := Mocap._find(ss, m[1])
				var s1 := Mocap._find(ss, m[2])
				var sd: Vector3 = (ss.global_transform * ss.get_bone_global_pose(s1).origin) - (ss.global_transform * ss.get_bone_global_pose(s0).origin)
				var child: String = {"spine": "neck", "upperarm.L": "forearm.L", "forearm.L": "hand.L", "upperarm.R": "forearm.R", "forearm.R": "hand.R", "thigh.L": "shin.L", "thigh.R": "shin.R"}.get(b, "")
				var md := Vector3.ZERO
				var p0 := msk.global_transform * msk.get_bone_global_pose(msk.find_bone(b)).origin
				if child != "":
					md = (msk.global_transform * msk.get_bone_global_pose(msk.find_bone(child)).origin) - p0
				else:
					md = (msk.global_transform * msk.get_bone_global_pose(msk.find_bone(b))).basis * (msk.get_bone_global_rest(msk.find_bone(b)).basis.inverse() * Vector3.DOWN)
				var ang := rad_to_deg(sd.angle_to(md))
				_err_sum += ang
				_err_n += 1
				_err_max = maxf(_err_max, ang)
				if ang > _err_max_b.get("a", 0.0):
					_err_max_b = {"a": ang, "b": b, "t": t}
			lbl.text = "%s    %.2f s        vlevo: náš žoldák   ·   vpravo: Mixamo" % [nm, t]
			await get_tree().process_frame
			await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(sub.path_join("f%04d.png" % fr))
		print("[MOCAP] %s limb direction error: avg %.1f deg, max %.1f deg (%s at %.2f s)" % [nm, _err_sum / maxf(1, _err_n), _err_max, _err_max_b.get("b", ""), _err_max_b.get("t", 0.0)])
		_err_sum = 0.0
		_err_n = 0
		_err_max = 0.0
		_err_max_b = {}
		holder.queue_free()
		for st in _stick.values():
			(st as Node).queue_free()
		_stick.clear()
		await get_tree().process_frame
		n += 1
	print("RESULT mocapview %d" % n)
	get_tree().quit()
