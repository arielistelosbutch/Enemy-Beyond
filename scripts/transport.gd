extends CanvasLayer
## 0.66 Facelift I (Ari): after a SUCCESSFUL mission, a look into the transport on the way home.
## The wounded lie on the floor or sit against the wall, the ones in one piece sit on the seats
## (or stand, stretch, talk) - everyone in his own look (a copy of his body from the mission, with
## camouflage and armour). Under it this player's own numbers only (in co-op each sees his own):
## kills, captures, revives, the wounded of the team, what was found, the pay. Enter (or a click)
## goes on. Its own little 3D world in a SubViewport: the mission scene stays as it is underneath.

signal closed

const SEAT_Y := 0.54           # top of the seats (the hips go there)
const FLOOR_Y := 0.2
const LIE_CLIP := "tp_npc_sleep"   # (Ari 0.69) out cold: flat on the back, a calm patient (afk Sleeping, base people pack)

var _vp: SubViewport
var _cam: Camera3D
var _men: Array = []           # {sk, clip, t, pivot, hip_y}
var _t := 0.0
var _done := false
var _bobs: Array = []
var _dbg_cam := false
var _report: ScrollContainer
const CAM_AT := Vector3(0.75, 2.05, 3.7)
const LOOK_AT := Vector3(-0.3, 0.05, -0.9)     # (low: the men sit above the panel at the bottom)

## team: [{"model": Node3D (a copy of the body), "state": "ok"|"hurt"|"down", "me": bool}]
## stats: [[label, value], ...]; report: the longer text (the campaign's report) or "".
func setup(team: Array, title: String, stats: Array, report: String, heli := false) -> void:
	layer = 105
	name = "Transport"
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	# the 3D picture at the window's real resolution (a SubViewportContainer would draw it at the
	# 640x360 of the UI and blow it up - blurry, Ari 0.66), shown through a TextureRect
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.size = _px_size()
	add_child(_vp)
	var svc := TextureRect.new()
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	svc.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	svc.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	svc.texture = _vp.get_texture()
	root.add_child(svc)
	_build_cabin(heli)
	_seat(team)
	_panel(root, title, stats, report)
	# fade in from black
	bg.modulate.a = 1.0
	svc.modulate.a = 0.0
	create_tween().tween_property(svc, "modulate:a", 1.0, 0.8)

## The size of the window in real pixels (at least the UI's 640x360).
func _px_size() -> Vector2i:
	var s := DisplayServer.window_get_size() if DisplayServer.get_name() != "headless" else Vector2i(640, 360)
	return Vector2i(maxi(s.x, 640), maxi(s.y, 360))

func _build_cabin(heli: bool) -> void:
	var w := Node3D.new()
	_vp.add_child(w)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.04, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.34, 0.4)
	env.ambient_light_energy = 0.38
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	w.add_child(we)
	var ship: Node3D = Game.model("heli" if heli else "dropship")
	if ship:
		w.add_child(ship)
		Game.ship_ramp(ship, 0.0)       # (0.7x) flying home: the rear shut
	if ship == null:
		# (no model: a plain floor and the two rows of seats)
		var metal: Material = Game.mat("metal")
		_box(w, Vector3(0, FLOOR_Y - 0.05, 0.4), Vector3(3.1, 0.1, 7.6), metal)
		for sx in [-1.0, 1.0]:
			_box(w, Vector3(sx * 1.3, SEAT_Y - 0.04, 0.4), Vector3(0.42, 0.07, 5.6), metal)
	# the lamps: a warm one over the aisle, the red night light at the back, a weak blue from the windows
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.82, 0.58)
	lamp.light_energy = 1.3
	lamp.omni_range = 5.5
	lamp.shadow_enabled = true
	lamp.position = Vector3(0, 2.4, 0.2)
	w.add_child(lamp)
	_bobs.append(lamp)
	var red := OmniLight3D.new()
	red.light_color = Color(1.0, 0.18, 0.12)
	red.light_energy = 0.5
	red.omni_range = 3.5
	red.position = Vector3(0, 2.3, -2.6)
	w.add_child(red)
	var blue := DirectionalLight3D.new()
	blue.light_color = Color(0.5, 0.6, 0.9)
	blue.light_energy = 0.25
	blue.rotation = Vector3(-0.9, 0.6, 0)
	w.add_child(blue)
	_cam = Camera3D.new()
	_cam.fov = 64.0
	w.add_child(_cam)
	_cam.position = CAM_AT
	_cam.look_at(LOOK_AT, Vector3.UP)
	var dbg := Game.cmd_arg("tcam", "")
	if dbg != "":
		var c := dbg.split_floats(",")
		_cam.position = Vector3(c[0], c[1], c[2])
		_cam.look_at(Vector3(c[3], c[4], c[5]), Vector3.UP)
		_dbg_cam = true
	_cam.current = true

func _box(parent: Node3D, pos: Vector3, size: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)

## Places the men: the ones in one piece on the seats (one of them standing when there are three
## or more, for a bit of life), the wounded sitting on the floor, the ones out cold lying in the aisle.
func _seat(team: Array) -> void:
	var seats := [Vector3(-1.25, 0, 0.5), Vector3(1.25, 0, -0.5), Vector3(-1.25, 0, -0.9), Vector3(1.25, 0, -1.8), Vector3(-1.25, 0, -2.1), Vector3(1.25, 0, 0.7)]
	var floor_spots := [Vector3(0.85, 0, -1.15), Vector3(-0.85, 0, -0.2), Vector3(0.85, 0, 0.15)]
	var lie_spots := [Vector3(-0.3, 0, -1.5), Vector3(0.2, 0, 0.0)]
	var rng := RandomNumberGenerator.new()
	rng.seed = Net.mission_seed + 5
	var oks := 0
	for e in team:
		var model: Node3D = e["model"]
		if model == null:
			continue
		var pivot := Node3D.new()
		_vp.get_child(0).add_child(pivot)
		model.position = Vector3.ZERO
		model.rotation = Vector3.ZERO
		pivot.add_child(model)
		var sk: Skeleton3D = model.find_child("Skeleton3D", true, false)
		var clip_id := "tp_emote_sit"
		var t0 := rng.randf() * 2.0
		var on_seat := false
		match String(e["state"]):
			"down":
				# (Ari 0.69) on the back, a calm patient - face down they looked like they were dying
				clip_id = LIE_CLIP
				var p: Vector3 = lie_spots.pop_front() if not lie_spots.is_empty() else Vector3(0, 0, 0.8)
				pivot.position = p + Vector3(0, FLOOR_Y, 0)
				pivot.rotation.y = rng.randf_range(-0.2, 0.2)
				if AnimClips.get_clip(LIE_CLIP).is_empty():
					clip_id = "tp_body_dead"
					t0 = 99.0      # (no lying clip in the pack: the end of the fall)
			"hurt":
				clip_id = "tp_body_dragged"
				var p: Vector3 = floor_spots.pop_front() if not floor_spots.is_empty() else Vector3(0.6, 0, 1.0)
				pivot.position = p + Vector3(0, FLOOR_Y, 0)
				pivot.rotation.y = (-PI / 2 if p.x < 0 else PI / 2) + rng.randf_range(-0.4, 0.4)     # back to the wall
			_:
				oks += 1
				var standing := oks == 3 or (oks == 2 and team.size() == 2 and rng.randf() < 0.5)
				if standing:
					clip_id = ["tp_emote_talk", "tp_atease_vse", "tp_emote_stretch", "tp_emote_tired"][rng.randi() % 4]
					pivot.position = Vector3(0.25, FLOOR_Y, -2.4)
					pivot.rotation.y = PI * 0.9
				else:
					var p: Vector3 = seats.pop_front()
					pivot.position = p
					pivot.rotation.y = -PI / 2 if p.x < 0 else PI / 2      # facing the aisle
					on_seat = true
		var clip := AnimClips.get_clip(clip_id)
		if clip.is_empty():
			clip = AnimClips.get_clip("tp_body_idle")
		_men.append({"sk": sk, "clip": clip, "t": t0, "pivot": pivot, "seat": on_seat})
		_pose(_men[-1], 0.0)
		if Game.autotest() == "transport":
			var hi0 := sk.find_bone("hips") if sk else -1
			print("[TRANSPORT] %s at %s hips %s" % [e["state"], pivot.position, (sk.global_transform * sk.get_bone_global_pose(hi0)).origin if hi0 >= 0 else Vector3.ZERO])
		if on_seat:
			# the hips onto the seat (the clip sits on the ground)
			var hi := sk.find_bone("hips") if sk else -1
			if hi >= 0:
				sk.force_update_all_bone_transforms()
				var hy := (sk.global_transform * sk.get_bone_global_pose(hi)).origin.y
				pivot.position.y += SEAT_Y + 0.08 - hy

func _pose(m: Dictionary, delta: float) -> void:
	var sk: Skeleton3D = m["sk"]
	if sk == null:
		return
	m["t"] = float(m["t"]) + delta
	var clip: Dictionary = m["clip"]
	var t := AnimClips.clip_time(clip, float(m["t"]))
	# a looping idle without its first and last key: in the afk sit clips those put the root 25 cm back,
	# so every loop the man jumped forward (Ari 0.66) - here they only sit / stand and breathe in place
	var len_ := float(clip.get("delka", 1.0))
	if clip.get("smycka", false) and len_ > 0.2 and float(m["t"]) < 50.0:
		t = 0.04 + fmod(float(m["t"]), len_ - 0.08)
	var p := AnimClips.pose(clip, t)
	for bn in p:
		var i := sk.find_bone(bn)
		if i >= 0:
			sk.set_bone_pose_rotation(i, sk.get_bone_rest(i).basis.get_rotation_quaternion() * Quaternion.from_euler(p[bn]))
	if AnimClips.has_track(clip, "root@pos"):
		var ri := sk.find_bone("root")
		if ri >= 0:
			var v := AnimClips.sample(clip, "root@pos", t)
			# (in place: only the height of the root follows the clip, never a step aside)
			var hold: Vector3 = m.get("root_xz", Vector3(INF, 0, 0))
			if hold.x == INF:
				hold = Vector3(float(v[0]), 0, float(v[2]))
				m["root_xz"] = hold
			sk.set_bone_pose_position(ri, sk.get_bone_rest(ri).origin + Vector3(hold.x, float(v[1]), hold.z))

func _panel(root: Control, title: String, stats: Array, report: String) -> void:
	# a band at the bottom that grows upwards to what it holds (never under the screen's edge)
	var band := PanelContainer.new()
	band.add_theme_stylebox_override("panel", UiSkin.panel())
	band.anchor_left = 0.0
	band.anchor_right = 1.0
	band.anchor_top = 1.0
	band.anchor_bottom = 1.0
	band.offset_left = 14
	band.offset_right = -14
	band.offset_top = -10
	band.offset_bottom = -10
	band.grow_vertical = Control.GROW_DIRECTION_BEGIN
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(band)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	band.add_child(v)
	# the title, Enter on the right of it
	var top := HBoxContainer.new()
	v.add_child(top)
	var head := Label.new()
	head.text = title
	head.clip_text = true
	head.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiSkin.title(head, 12)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	top.add_child(head)
	var hint := Label.new()
	hint.text = "ENTER - pokračovat"
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", Color(0.62, 0.95, 0.88))
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(hint)
	# his own numbers: four pairs on a row, across the whole band
	var g := GridContainer.new()
	g.columns = 8
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 1)
	v.add_child(g)
	for s in stats:
		var k := Label.new()
		k.text = String(s[0])
		k.add_theme_font_size_override("font_size", 9)
		k.add_theme_color_override("font_color", Color(0.62, 0.72, 0.8))
		g.add_child(k)
		var val := Label.new()
		val.text = String(s[1])
		val.custom_minimum_size.x = 44
		val.add_theme_font_size_override("font_size", 9)
		val.add_theme_color_override("font_color", Color(0.95, 0.88, 0.6))
		g.add_child(val)
	# under them the report (his soldier's fate, the base's news): three lines, scrolls when longer
	if report.strip_edges() != "":
		var sep := HSeparator.new()
		v.add_child(sep)
		var r := Label.new()
		r.text = report.strip_edges().replace("\n\n", "\n")
		r.autowrap_mode = TextServer.AUTOWRAP_WORD
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_theme_font_size_override("font_size", 8)
		r.add_theme_color_override("font_color", Color(0.8, 0.88, 0.95))
		var sc := ScrollContainer.new()
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.custom_minimum_size.y = r.get_line_height() * 3 + 2      # (whole lines, no half one at the bottom)
		v.add_child(sc)
		sc.add_child(r)
		_report = sc

func _process(delta: float) -> void:
	_t += delta
	for m in _men:
		_pose(m, delta)
	# the flight: the cabin rocks a little, the lamp sways
	if _vp and _vp.size != _px_size():
		_vp.size = _px_size()
	if _cam and not _dbg_cam:
		# the transport in flight: a slow roll and sway, now and then a small bump of the air
		var bump := maxf(0.0, sin(_t * 0.37) - 0.92) * 0.6 * sin(_t * 23.0)
		_cam.position = CAM_AT + Vector3(sin(_t * 0.5) * 0.03, sin(_t * 1.3) * 0.025 + bump * 0.03, 0)
		_cam.look_at(LOOK_AT, Vector3.UP)
		_cam.rotate_object_local(Vector3.FORWARD, sin(_t * 0.9) * 0.02 + sin(_t * 2.3) * 0.005 + bump * 0.01)
	for b in _bobs:
		b.position.x = sin(_t * 1.1) * 0.06

func _input(e: InputEvent) -> void:
	if _done or _t < 0.6:
		return
	var go := false
	# the arrows scroll a long report
	if _report and e is InputEventKey and e.pressed and e.keycode in [KEY_UP, KEY_DOWN]:
		_report.scroll_vertical += 11 * (1 if e.keycode == KEY_DOWN else -1)
		get_viewport().set_input_as_handled()
		return
	if e is InputEventKey and e.pressed and not e.echo and e.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
		go = true
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		go = true
	if go:
		get_viewport().set_input_as_handled()
		finish()

func finish() -> void:
	if _done:
		return
	_done = true
	closed.emit()
	var tw := create_tween()
	tw.tween_property(get_child(0), "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)
