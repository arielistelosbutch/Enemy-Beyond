extends Node3D
## (0.57) Nahrávání pohybů z očí ve VR (Oculus Rift přes OpenXR).
## Spuštění: tools/vr_nahravani.bat (Godot s --xr-mode on, scéna scenes/VrRecord.tscn).
##
## Pravý ovladač drží zbraň (model ze hry i s rukama), levý je volná ruka. Nahrává se poloha
## zbraně a levé ruky vůči hlavě a po uložení se z toho stane obyčejný klip z očí
## animace/fp_reload_<zbraň>.json (stejný formát jako „Animace z očí“ v Dílně, jde tam dál ladit).
## Hra ho pak při přebíjení z očí přehraje místo spuštění zbraně z obrazu (klip s "zdroj": "vr").
##
## Ovládání (pravý ovladač): A = odpočet a nahrávání / konec nahrávání / uložit záběr,
## B = zahodit záběr (v klidu: přehrát uložený klip), páčka vlevo/vpravo = jiná zbraň,
## páčka nahoru/dolů = naklonit zbraň v ruce. Spoušť = cvaknutí závěru (zvuk v klipu).
## Levý ovladač: grip = drží zásobník (u šachty zásobník vyndá / zasune, jinde ho pustí na zem).
##
## Bez brýlí (nebo s --vrtest) běží na obrazovce: --vrtest nahraje umělý pohyb, převede ho,
## uloží do user://vrtest/ a skončí (test v cloudu).

const PlayerScript := preload("res://scripts/player.gd")
const REST_ROT := Vector3(0.02, 0.06, 0.0)        # player.gd: the gun's turn in the hands at rest
const PISTOL_REST := Vector3(0.1, -0.17, -0.38)    # player.gd: pistol grip, both hands, low ready
const RUKA_REST := Vector3(30.0, 0.0, 0.0)         # the free left hand's turn at the start (deg)
const TOL_POS := 0.003                             # key reduction: 3 mm
const TOL_ROT := 1.5                               # and 1.5 degrees
const FREE_AT := 0.07                              # the left hand has let go of the gun (m)
const BACK_AT := 0.04                              # ... and holds it again
const WELL_R := 0.12                               # near the magazine well (m)
const CFG := "user://vr_nahravani.cfg"

var guns: Array = []
var acts: Array = []          # what to record, in order: {act, item, gun, carry, name}
var gi := 0                   # (index into acts)
var xr := false
var test := false
var out_dir := "res://animace"
var raw_dir := "res://animace/vr_zaznamy"

var origin: XROrigin3D
var head: XRCamera3D
var cr: XRController3D
var cl: XRController3D
var rh: Node3D                # the right hand as recorded: the controller, or the tracked hand (Quest 3)
var lh: Node3D                # the left one
var hands_used := ""          # shown on the sign: what tracks each hand now
var gun_node: Node3D
var lmag: Node3D
var lmark: Node3D
var label: Label3D
var label2d: Label
var ghost: Node3D
var ghost_hand: Node3D

var state := "idle"           # idle, count, rec, review, play
var t := 0.0
var frames: Array = []
var clip := {}
var tilt := 0.0
var msg := ""
var _prev := {}
var _stick_free := true
var _grip_l := false
var _trig_r := false

func _ready() -> void:
	test = "--vrtest" in OS.get_cmdline_user_args()
	for id in Game.ITEMS:
		var it: Dictionary = Game.ITEMS[id]
		if it.get("type", "") == "weapon" and not String(id).begins_with("a_") and ResourceLoader.exists("res://assets/models/%s.glb" % id):
			guns.append(id)
	acts = make_acts(guns)
	var cf := ConfigFile.new()
	if cf.load(CFG) == OK:
		tilt = float(cf.get_value("vr", "tilt", 0.0))
		var want := String(cf.get_value("vr", "akce", "fp_reload_rifle"))
		for i in acts.size():
			if clip_id(acts[i]) == want:
				gi = i
	var xri := XRServer.find_interface("OpenXR")
	if xri and not test:
		if xri.is_initialized() or xri.initialize():
			xr = true
			get_viewport().use_xr = true
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_build_world()
	_build_rig()
	_set_gun()
	var conv := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--vrconvert="):
			conv = a.substr(12)
	if conv != "":
		_convert_raw(conv)
		return
	if test:
		out_dir = "user://vrtest"
		raw_dir = "user://vrtest"
		_run_test()
	elif not xr:
		msg = "Brýle nenalezeny (OpenXR). Zapni Oculus aplikaci, v ní Nastavení > Obecné > OpenXR Runtime\nnastav Oculus jako aktivní a spusť přes tools/vr_nahravani.bat."

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.13, 0.14, 0.16)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.62, 0.66)
	e.ambient_light_energy = 0.7
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.5, 0)
	add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6, 6)
	floor_mi.mesh = pm
	floor_mi.material_override = Game.color_mat(Color(0.22, 0.23, 0.22))
	add_child(floor_mi)
	for i in range(-3, 4):
		for ax in 2:
			var line := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(6, 0.004, 0.01) if ax == 0 else Vector3(0.01, 0.004, 6)
			line.mesh = bm
			line.material_override = Game.color_mat(Color(0.35, 0.36, 0.34))
			line.position = Vector3(0, 0.002, i) if ax == 0 else Vector3(i, 0.002, 0)
			add_child(line)

func _build_rig() -> void:
	origin = XROrigin3D.new()
	add_child(origin)
	head = XRCamera3D.new()
	head.near = 0.02
	head.current = true
	origin.add_child(head)
	if not xr:
		head.position = Vector3(0, 1.6, 0)
	cr = XRController3D.new()
	cr.tracker = &"right_hand"
	cr.pose = &"grip_pose"
	origin.add_child(cr)
	cl = XRController3D.new()
	cl.tracker = &"left_hand"
	cl.pose = &"grip_pose"
	origin.add_child(cl)
	rh = Node3D.new()
	rh.position = Vector3(0.2, 1.1, -0.3)       # (until a hand is seen: in front, not on the floor)
	origin.add_child(rh)
	_jr = _joint_set()
	_jl = _joint_set()
	lh = Node3D.new()
	lh.position = Vector3(-0.2, 1.1, -0.4)
	origin.add_child(lh)
	gun_node = Node3D.new()
	rh.add_child(gun_node)
	lmark = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.025
	sm.height = 0.05
	(lmark as MeshInstance3D).mesh = sm
	(lmark as MeshInstance3D).material_override = Game.color_mat(Color(0.8, 0.7, 0.55))
	lh.add_child(lmark)
	label = Label3D.new()
	label.position = Vector3(0, -0.12, -0.8)
	label.pixel_size = 0.0009
	label.font_size = 32
	label.outline_size = 8
	label.no_depth_test = true
	label.fixed_size = false
	label.width = 900
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(label)
	ghost = Node3D.new()
	ghost.visible = false
	head.add_child(ghost)
	ghost_hand = Game.model("hand_l")
	ghost_hand.top_level = true
	ghost_hand.visible = false
	head.add_child(ghost_hand)
	if not xr:
		var cv := CanvasLayer.new()
		add_child(cv)
		label2d = Label.new()
		label2d.position = Vector2(20, 20)
		label2d.add_theme_font_size_override("font_size", 18)
		cv.add_child(label2d)
		label.visible = false

## The queue: every gun's reload (and one round at a time where the gun loads so), then the
## things done with a gun in the right hand: digging in the backpack, the medkit, a grenade.
static func make_acts(gl: Array) -> Array:
	var out := []
	for g in gl:
		var it: Dictionary = Game.ITEMS[g]
		out.append({"act": "reload", "item": g, "gun": g, "carry": String(it.get("ammo", "")), "name": "%s – přebíjení" % it["name"]})
		if it.has("single"):
			out.append({"act": "reload1", "item": g, "gun": g, "carry": "shell" if g == "shotgun" else "round", "name": "%s – náboj po jednom" % it["name"]})
	out.append({"act": "dig", "item": "vse", "gun": "rifle", "carry": "medkit", "ruce": true, "name": "Hrabání v batohu (pro všechny zbraně)"})
	out.append({"act": "heal", "item": "vse", "gun": "rifle", "carry": "medkit", "ruce": true, "name": "Lékárnička / obvazování (pro všechny zbraně)"})
	out.append({"act": "throw", "item": "vse", "gun": "rifle", "carry": "grenade", "name": "Hod granátem (pro všechny zbraně)"})
	return out

static func clip_id(e: Dictionary) -> String:
	return "fp_%s_%s" % [e["act"], e["item"]]

func act_e() -> Dictionary:
	return acts[gi] if not acts.is_empty() else {"act": "reload", "item": "rifle", "gun": "rifle", "carry": "rifle_clip", "name": "Puška – přebíjení"}

func gun_id() -> String:
	return String(act_e()["gun"])

## Where the game holds this gun in the eyes' view at rest (camera space).
static func rest_xform(id: String) -> Transform3D:
	var pos: Vector3 = PlayerScript.VM_R.get(id, PlayerScript.VM_ONE_R) if Game.two_handed(id) else PISTOL_REST
	return Transform3D(Basis.from_euler(REST_ROT), pos)

## The gun as the game shows it: the model (with its Dílna fp tweak) and the hands.
static func gun_model(id: String) -> Node3D:
	var n := Node3D.new()
	var wm := Game.held_model(id)
	wm.name = "Weapon"
	n.add_child(wm)
	if ResourceLoader.exists("res://assets/models/hands_%s.glb" % id):
		var hm := Game.model("hands_" + id)
		n.add_child(hm)
		Game.apply_left_hand(hm, id)
	else:
		n.add_child(Game.model("hand_r"))
	var hr := Game.model("hand_r")       # (just the right hand: "hands only" things - bandaging, the backpack)
	hr.name = "HandR"
	hr.visible = false
	n.add_child(hr)
	return n

## "Hands only": the gun goes out of the picture, both hands are seen (shown and recorded so).
static func hands_only(m: Node3D, on: bool) -> void:
	(m.get_node("Weapon") as Node3D).visible = not on
	(m.get_child(1) as Node3D).visible = not on
	(m.get_node("HandR") as Node3D).visible = on

## The magazine well in the gun node's space (the model's "Mag" part, else between the hands).
func _well(id: String, lrel0: Vector3) -> Vector3:
	var m := gun_model(id)
	var wm := m.get_node("Weapon") as Node3D
	var mag := wm.find_child("Mag", true, false) as Node3D
	var at := lrel0 * 0.5 + Vector3(0, -0.07, 0)
	if mag:
		var tr := Transform3D()
		var c: Node = mag
		while c != m and c is Node3D:
			tr = (c as Node3D).transform * tr
			c = c.get_parent()
		at = tr.origin
	m.free()
	return at

## How long the game takes for it (the clip is stretched to that); 0 when it varies.
static func game_time(e: Dictionary) -> float:
	var it: Dictionary = Game.ITEMS.get(e["gun"], {})
	match String(e["act"]):
		"reload": return float(it.get("reload", 2.0))
		"reload1": return float(it.get("single", 0.0))
		"heal": return 3.0
	return 0.0

func _set_gun() -> void:
	for c in gun_node.get_children():
		c.queue_free()
	var id := gun_id()
	var m := gun_model(id)
	gun_node.add_child(m)
	# the in-game right hand (the gun node's origin, or the model's Grip point) onto the controller
	var shift := Transform3D()
	var g: Variant = Game.model_point(id, "Grip")
	if g != null:
		shift = Transform3D(Basis(), -((m.get_node("Weapon") as Node3D).transform * (g as Vector3)))
	gun_node.transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(tilt), 0, 0)), Vector3.ZERO) * shift
	if lmag:
		lmag.queue_free()
		lmag = null
	hands_only(m, act_e().get("ruce", false))
	var cy := String(act_e()["carry"])
	if cy != "":
		lmag = Game.model(cy)
		lmag.visible = false
		lh.add_child(lmag)
	_save_cfg()

func _save_cfg() -> void:
	var cf := ConfigFile.new()
	cf.set_value("vr", "tilt", tilt)
	cf.set_value("vr", "akce", clip_id(act_e()))
	cf.save(CFG)

# ---- input -----------------------------------------------------------------------------------------
func _pressed(c: XRController3D, b: String) -> bool:
	var key := String(c.tracker) + b
	var now := c.is_button_pressed(b)
	var was: bool = _prev.get(key, false)
	_prev[key] = now
	return now and not was

func _process(delta: float) -> void:
	if test:
		return
	var ht_r := _hand("right")
	var ht_l := _hand("left")
	# each hand: the controller when it is held, else the tracked hand (Quest 3 sees the fingers).
	# (the pose is read from the tracker itself under whatever name the runtime gives it -
	# the first try on the Quest left both on the floor: the controllers' pose never came)
	var pr: Variant = _ctl_pose("right_hand")
	var pl: Variant = _ctl_pose("left_hand")
	var ctl_r: bool = pr != null
	var ctl_l: bool = pl != null
	if ctl_r:
		rh.transform = pr
	elif ht_r:
		rh.transform = _palm(ht_r, false)
	if ctl_l:
		lh.transform = pl
	elif ht_l:
		lh.transform = _palm(ht_l, true)
	_show_joints(ht_r, _jr)
	_show_joints(ht_l, _jl)
	hands_used = "pravá: %s, levá: %s · %s" % ["ovladač" if ctl_r else ("ruka" if ht_r else "NEVIDÍM"), "ovladač" if ctl_l else ("ruka" if ht_l else "NEVIDÍM"), _diag()]
	var a := _pressed(cr, "ax_button")
	var b := _pressed(cr, "by_button")
	var stick := cr.get_vector2("primary")
	var flick := Vector2i.ZERO
	if stick.length() < 0.3:
		_stick_free = true
	elif _stick_free and stick.length() > 0.7:
		_stick_free = false
		flick = Vector2i(signi(roundi(stick.x)), signi(roundi(stick.y)))
	if not ctl_r and ht_r:
		# bare right hand: thumb on the index finger = A, on the middle finger = B
		a = _gesture("ra", _pinch(ht_r, XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP))
		b = _gesture("rb", _pinch(ht_r, XRHandTracker.HAND_JOINT_MIDDLE_FINGER_TIP))
	if not ctl_l and ht_l:
		# bare left hand: a fist holds the magazine; while waiting, pinches page through the list
		var tip := _jpos(ht_l, XRHandTracker.HAND_JOINT_MIDDLE_FINGER_TIP)
		var palm := _jpos(ht_l, XRHandTracker.HAND_JOINT_PALM)
		_grip_l = tip.distance_to(palm) < (0.07 if _grip_l else 0.055)
		if state == "idle":
			if _gesture("ln", _pinch(ht_l, XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP)):
				flick.x = 1
			elif _gesture("lp", _pinch(ht_l, XRHandTracker.HAND_JOINT_MIDDLE_FINGER_TIP)):
				flick.x = -1
	else:
		_grip_l = cl.get_float("grip") > (0.45 if _grip_l else 0.65)
	var trig := cr.get_float("trigger") > (0.45 if _trig_r else 0.65)
	var trig_click := trig and not _trig_r
	_trig_r = trig
	if lmag:
		lmag.visible = _grip_l
	lmark.visible = not _grip_l or lmag == null
	_step(delta, a, b, flick, trig_click)
	_show()

const POSES := [&"grip", &"grip_pose", &"default", &"default_pose", &"aim", &"aim_pose", &"palm", &"palm_pose"]

## A controller's pose (in the XR origin's space) or null when it is not tracked.
func _ctl_pose(tname: String) -> Variant:
	var tr := XRServer.get_tracker(StringName(tname)) as XRPositionalTracker
	if tr == null:
		return null
	for pn in POSES:
		if tr.has_pose(pn):
			var xp := tr.get_pose(pn)
			if xp and xp.has_tracking_data:
				return xp.get_adjusted_transform()
	return null

## What the runtime gives (shown small on the sign, for when something does not move).
var _diag_t := 0.0
var _diag_s := ""
func _diag() -> String:
	if Time.get_ticks_msec() / 1000.0 - _diag_t < 1.0:
		return _diag_s
	_diag_t = Time.get_ticks_msec() / 1000.0
	var parts := []
	for tname in ["right_hand", "left_hand"]:
		var tr := XRServer.get_tracker(StringName(tname)) as XRPositionalTracker
		if tr == null:
			parts.append(tname + ": žádný")
			continue
		var ps := []
		for pn in POSES:
			if tr.has_pose(pn):
				var xp := tr.get_pose(pn)
				ps.append(String(pn) + ("+" if xp and xp.has_tracking_data else "-"))
		parts.append("%s: %s" % [tname, ",".join(ps) if not ps.is_empty() else "bez pozic"])
	for side in ["left", "right"]:
		var ht := XRServer.get_tracker(StringName("/user/hand_tracker/" + side)) as XRHandTracker
		parts.append("prsty %s: %s" % [side, "není" if ht == null else ("ano" if ht.has_tracking_data else "nevidí")])
	parts.append("snímání prstů " + ("zapnuto" if ProjectSettings.get_setting("xr/openxr/extensions/hand_tracking", false) else "VYPNUTO"))
	_diag_s = " | ".join(parts)
	return _diag_s

## Small balls on the fingers of a tracked hand, so the hands are seen in the headset.
var _jr: Node3D
var _jl: Node3D
const SHOW_JOINTS := [XRHandTracker.HAND_JOINT_PALM, XRHandTracker.HAND_JOINT_THUMB_TIP, XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP,
	XRHandTracker.HAND_JOINT_MIDDLE_FINGER_TIP, XRHandTracker.HAND_JOINT_RING_FINGER_TIP, XRHandTracker.HAND_JOINT_PINKY_FINGER_TIP,
	XRHandTracker.HAND_JOINT_INDEX_FINGER_PHALANX_PROXIMAL, XRHandTracker.HAND_JOINT_MIDDLE_FINGER_PHALANX_PROXIMAL, XRHandTracker.HAND_JOINT_RING_FINGER_PHALANX_PROXIMAL,
	XRHandTracker.HAND_JOINT_PINKY_FINGER_PHALANX_PROXIMAL, XRHandTracker.HAND_JOINT_WRIST]
func _show_joints(ht: XRHandTracker, n: Node3D) -> void:
	n.visible = ht != null
	if ht == null:
		return
	for i in SHOW_JOINTS.size():
		(n.get_child(i) as Node3D).position = ht.get_hand_joint_transform(SHOW_JOINTS[i]).origin

func _joint_set() -> Node3D:
	var n := Node3D.new()
	var mat := Game.color_mat(Color(0.85, 0.72, 0.6))
	for i in SHOW_JOINTS.size():
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.009 if i > 0 else 0.018
		sm.height = sm.radius * 2.0
		mi.mesh = sm
		mi.material_override = mat
		n.add_child(mi)
	n.visible = false
	origin.add_child(n)
	return n

## The tracked hand (Quest 3 hand tracking), or null when it is not seen.
func _hand(side: String) -> XRHandTracker:
	var ht := XRServer.get_tracker(StringName("/user/hand_tracker/" + side)) as XRHandTracker
	return ht if ht and ht.has_tracking_data else null

func _jpos(ht: XRHandTracker, j: int) -> Vector3:
	return ht.get_hand_joint_transform(j).origin

## The palm as a controller-like grip: -Z along the fingers' fist, as the controller's grip pose.
func _palm(ht: XRHandTracker, _left: bool) -> Transform3D:
	return ht.get_hand_joint_transform(XRHandTracker.HAND_JOINT_PALM)

func _pinch(ht: XRHandTracker, j: int) -> bool:
	return _jpos(ht, XRHandTracker.HAND_JOINT_THUMB_TIP).distance_to(_jpos(ht, j)) < 0.018

## A gesture counts once, after it has been held a moment (not a brush of the fingers).
var _held := {}
func _gesture(key: String, on: bool) -> bool:
	if not on:
		_held[key] = 0
		return false
	_held[key] = int(_held.get(key, 0)) + 1
	return int(_held[key]) == 12

func _step(delta: float, a: bool, b: bool, flick: Vector2i, trig_click: bool) -> void:
	match state:
		"idle":
			if flick.x != 0 and not guns.is_empty():
				gi = posmod(gi + flick.x, acts.size())
				_set_gun()
			elif flick.y != 0:
				tilt = clampf(tilt + 5.0 * flick.y, -60.0, 60.0)
				_set_gun()
			if a:
				state = "count"
				t = 3.0
			elif b:
				var c := AnimClips.get_clip(clip_id(act_e()))
				if not c.is_empty():
					clip = c
					state = "play"
					t = 0.0
		"count":
			t -= delta
			if t <= 0.0:
				state = "rec"
				t = 0.0
				frames.clear()
				_buzz(0.15)
		"rec":
			t += delta
			_record(t, trig_click)
			if a or t > 20.0:
				# (the thumb on the button at the end is not part of the move)
				while frames.size() > 2 and float(frames[-1]["t"]) > t - 0.15:
					frames.pop_back()
				_buzz(0.1)
				if frames.size() < 10:
					msg = "Záběr byl moc krátký."
					state = "idle"
				else:
					clip = convert_take(frames, gun_id(), act_e())
					state = "review"
					t = 0.0
		"review", "play":
			t += delta
			_ghost(clip, fmod(t, float(clip.get("delka", 1.0)) + 0.6))
			if state == "review" and a:
				msg = _save(clip, frames, act_e())
				state = "idle"
				# straight on to the next thing that has no VR clip yet (a "studio" queue)
				for i in range(1, acts.size()):
					var nx := posmod(gi + i, acts.size())
					if not _done(acts[nx]):
						gi = nx
						_set_gun()
						msg += "\nDalší na řadě: %s" % act_e()["name"]
						break
			elif b:
				if state == "review":
					msg = "Záběr zahozen."
				state = "idle"
	var live := state != "review" and state != "play"
	gun_node.visible = live
	ghost.visible = not live
	if live:
		ghost_hand.visible = false

## Is this already recorded in VR?
static func _done(e: Dictionary) -> bool:
	return AnimClips.get_clip(clip_id(e)).get("zdroj", "") == "vr"

func _buzz(sec: float) -> void:
	cr.trigger_haptic_pulse(&"haptic", 0.0, 0.6, sec, 0.0)

func _record(now: float, trig_click: bool) -> void:
	var hinv := head.global_transform.affine_inverse()
	frames.append({"t": now, "gn": _tf(hinv * gun_node.global_transform), "lh": _tf(hinv * lh.global_transform),
		"grip": _grip_l, "trig": trig_click})

static func _tf(x: Transform3D) -> Array:
	var q := x.basis.get_rotation_quaternion()
	return [x.origin.x, x.origin.y, x.origin.z, q.x, q.y, q.z, q.w]

static func _xf(a: Array) -> Transform3D:
	return Transform3D(Basis(Quaternion(a[3], a[4], a[5], a[6]).normalized()), Vector3(a[0], a[1], a[2]))

func _show() -> void:
	var e := act_e()
	var id := gun_id()
	var game_t := game_time(e)
	var s := "NAHRÁVÁNÍ POHYBŮ Z OČÍ\nNatáčí se: %s (%d/%d)%s · náklon %d°\n" % [e["name"], gi + 1, acts.size(), (" · ve hře %.1f s" % game_t) if game_t > 0.0 else "", int(tilt)]
	match state:
		"idle":
			var has := _done(e)
			s += "Hotovo z VR: %d/%d\n" % [acts.filter(func(x): return _done(x)).size(), acts.size()]
			s += "A = natáčet · B = přehrát uložené%s\npáčka ←→ další/předchozí, ↑↓ náklon zbraně · levý grip = drží %s · spoušť = závěr" % [" (je z VR)" if has else "", "zásobník" if e["act"] == "reload" else "věc"]
			if xr:
				s += "\nBez ovladače: palec+ukazovák = A, palec+prostředníček = B · levá: palec+ukazovák = další, palec+prostředníček = předchozí, pěst = drží"
		"count":
			s += "Drž zbraň v klidu jako ve hře... %d" % ceili(t)
		"rec":
			s += "● NAHRÁVÁM %.1f s – konec tlačítkem A" % t
		"review":
			s += "Záběr %.2f s%s\nA = uložit · B = zahodit" % [float(clip["delka"]), (" (ve hře se natáhne na %.1f s)" % game_t) if game_t > 0.0 else ""]
		"play":
			s += "Uložený klip „%s“ · B = zpět" % clip.get("nazev", "")
	if xr:
		s += "\n(" + hands_used + ")"
	if msg != "":
		s += "\n" + msg
	label.text = s
	if label2d:
		label2d.text = s

## The clip shown the way the game will show it (relative to the eyes).
func _ghost(c: Dictionary, tt: float) -> void:
	var id := gun_id()
	if ghost.get_child_count() == 0 or ghost.get_meta("gun", "") != id:
		for ch in ghost.get_children():
			ch.free()
		ghost.add_child(gun_model(id))
		ghost.set_meta("gun", id)
	tt = minf(tt, float(c.get("delka", 1.0)))
	var g := AnimClips.xform(c, "zbran", tt)
	var r0 := rest_xform(id)
	ghost.transform = Transform3D(Basis.from_euler(REST_ROT + g.basis.get_euler()), r0.origin + g.origin)
	var free := AnimClips.hand_free(c, tt)
	ghost_hand.visible = free
	var hands := ghost.get_child(0).get_child(1) as Node3D
	if hands:
		hands.visible = not free
	if c.get("jen_ruce", false):
		hands_only(ghost.get_child(0), true)
	else:
		(ghost.get_child(0).get_node("Weapon") as Node3D).visible = true
		(ghost.get_child(0).get_node("HandR") as Node3D).visible = false
	if free:
		var h := AnimClips.xform(c, "ruka", tt)
		ghost_hand.global_transform = Transform3D(head.global_transform.basis * h.basis, head.global_transform * h.origin)
		var cy := AnimClips.last_event(c, "drzi", tt)
		if ghost_hand.get_meta("carry", "") != cy:
			ghost_hand.set_meta("carry", cy)
			for ch in ghost_hand.get_children():
				if ch.name.begins_with("Carry"):
					ch.free()
			var cm := PlayerScript.make_carry(cy) if cy != "" else null
			if cm:
				ghost_hand.add_child(cm)

# ---- a take into a clip --------------------------------------------------------------------------
## Frames (gun node and left controller relative to the head) -> an eyes' clip: the game's gun
## follows the recorded gun rigidly from its rest place, the left hand keeps its place against the gun.
func convert_take(fr_raw: Array, id: String, ae: Dictionary) -> Dictionary:
	# a real gun has weight, the controller has none: the shake of an empty hand is smoothed out
	# (the gun more than the free hand), forwards and backwards so nothing lags behind
	var fr := _steady(fr_raw)
	# (the magazine comes out of the gun and goes in; not where rounds go in one by one)
	var mags: bool = ae["act"] == "reload" and not Game.ITEMS.get(id, {}).has("single")
	var g0 := rest_xform(id)
	var gn0 := _xf(fr[0]["gn"])
	var d := gn0.affine_inverse() * g0
	var lrel0 := gn0.affine_inverse() * _xf(fr[0]["lh"])
	var crot := (g0.basis * lrel0.basis).inverse() * Basis.from_euler(RUKA_REST * (PI / 180.0))
	var t0 := float(fr[0]["t"])
	var dur := float(fr[-1]["t"]) - t0
	var zk := []
	var rk := []
	var prev_e := REST_ROT
	var prev_h := Vector3.ZERO
	var first := true
	var ruce: bool = ae.get("ruce", false)
	var ev := [{"t": 0.0, "typ": "leva:volna" if ruce else "leva:zbran"}]
	var free := ruce
	var last_back := -1.0
	var well := _well(id, lrel0.origin)
	var carry := String(ae["carry"])
	var holding := false
	var grabs := 0          # how many times the left hand closes in the whole take
	var grab_n := 0
	var was := false
	for f in fr:
		if bool(f["grip"]) and not was:
			grabs += 1
		was = bool(f["grip"])
	for f in fr:
		var tt := float(f["t"]) - t0
		var gn := _xf(f["gn"])
		var gg := gn * d
		var e := _unwrap(gg.basis.get_euler(), prev_e)
		prev_e = e
		# the last fifth of a second eases back into the rest place (the game goes on from there)
		var w := 1.0 - smoothstep(dur - 0.2, dur, tt)
		var dp := (gg.origin - g0.origin) * w
		var dr := (e - REST_ROT) * w
		zk.append([tt, [dp.x, dp.y, dp.z, rad_to_deg(dr.x), rad_to_deg(dr.y), rad_to_deg(dr.z)]])
		var lrel := gn.affine_inverse() * _xf(f["lh"])
		var gv := Transform3D(Basis.from_euler(REST_ROT + dr), g0.origin + dp)
		var hc := gv * Transform3D(lrel.basis * crot, lrel.origin)
		var he := hc.basis.get_euler() if first else _unwrap(hc.basis.get_euler(), prev_h)
		first = false
		prev_h = he
		rk.append([tt, [hc.origin.x, hc.origin.y, hc.origin.z, rad_to_deg(he.x), rad_to_deg(he.y), rad_to_deg(he.z)]])
		var off := lrel.origin.distance_to(lrel0.origin)
		if ruce:
			pass        # (hands only: the left hand is its own the whole time)
		elif not free and off > FREE_AT:
			free = true
			ev.append({"t": snappedf(maxf(0.0, tt - 0.05), 0.01), "typ": "leva:volna"})
		elif free and off < BACK_AT:
			free = false
			last_back = tt
			ev.append({"t": snappedf(tt, 0.01), "typ": "leva:zbran"})
		var near := lrel.origin.distance_to(well) < WELL_R
		var g_on := bool(f["grip"])
		if mags and grabs == 1:
			near = not g_on and holding     # one grab: a new one from the belt, its release puts it in
		elif mags and grabs >= 2:
			# two grabs = a magazine change, wherever the hand was: the 1st grab takes the old one
			# out, its release drops it; the 2nd grab is the new one, its release puts it in
			near = (grab_n == 0 and g_on and not holding) or (grab_n == 2 and not g_on and holding)
		if g_on and not holding:
			grab_n += 1
			holding = true
			if near and mags:
				ev.append({"t": snappedf(tt, 0.01), "typ": "skryt:Mag"})
				ev.append({"t": snappedf(tt, 0.01), "typ": "zvuk:mag_out"})
			ev.append({"t": snappedf(tt, 0.01), "typ": "drzi:" + carry})
		elif not g_on and holding:
			holding = false
			if near and mags:
				ev.append({"t": snappedf(tt, 0.01), "typ": "ukazat:Mag"})
				ev.append({"t": snappedf(tt, 0.01), "typ": "zvuk:mag_in"})
			elif mags and (grabs < 2 or grab_n == 1):
				ev.append({"t": snappedf(tt, 0.01), "typ": "vyhodit:zasobnik"})
			ev.append({"t": snappedf(tt, 0.01), "typ": "drzi:"})
		if bool(f["trig"]):
			ev.append({"t": snappedf(tt, 0.01), "typ": "zvuk:pistol_slide"})
	if free:
		ev.append({"t": snappedf(maxf(0.0, dur - 0.1), 0.01), "typ": "leva:zbran"})
	if holding:
		ev.append({"t": snappedf(dur, 0.01), "typ": "drzi:"})
	var stopy := {"zbran": _reduce(zk)}
	if ev.any(func(x): return x["typ"] == "leva:volna"):
		stopy["ruka"] = _reduce(rk)
	ev.sort_custom(func(x, y): return float(x["t"]) < float(y["t"]))
	var out := {"nazev": "%s (VR)" % ae["name"], "druh": "fp", "zdroj": "vr",
		"delka": snappedf(dur, 0.01), "smycka": false, "stopy": stopy, "udalosti": ev}
	if ruce:
		out["jen_ruce"] = true      # the game hides the gun and shows both hands
	return out

const STEADY_GUN := 0.07         # s: how much the gun is smoothed (Gaussian, both ways)
const STEADY_HAND := 0.035       # s: the free hand

static func _steady(fr: Array) -> Array:
	var out := []
	for f in fr:
		out.append((f as Dictionary).duplicate())
	for spec in [["gn", STEADY_GUN], ["lh", STEADY_HAND]]:
		var key: String = spec[0]
		var sig: float = spec[1]
		for i in fr.size():
			var ti := float(fr[i]["t"])
			var pos := Vector3.ZERO
			var q0 := Quaternion(fr[i][key][3], fr[i][key][4], fr[i][key][5], fr[i][key][6])
			var qs := Vector4.ZERO
			var wsum := 0.0
			var j := i
			while j > 0 and ti - float(fr[j - 1]["t"]) < sig * 3.0:
				j -= 1
			while j < fr.size() and float(fr[j]["t"]) - ti < sig * 3.0:
				var a: Array = fr[j][key]
				var dt := float(fr[j]["t"]) - ti
				var w := exp(-dt * dt / (2.0 * sig * sig))
				pos += Vector3(a[0], a[1], a[2]) * w
				var q := Quaternion(a[3], a[4], a[5], a[6])
				if q.dot(q0) < 0.0:
					q = -q
				qs += Vector4(q.x, q.y, q.z, q.w) * w
				wsum += w
				j += 1
			pos /= wsum
			qs = qs.normalized()
			out[i][key] = [pos.x, pos.y, pos.z, qs.x, qs.y, qs.z, qs.w]
	return out

static func _unwrap(e: Vector3, prev: Vector3) -> Vector3:
	for i in 3:
		while e[i] - prev[i] > PI:
			e[i] -= TAU
		while e[i] - prev[i] < -PI:
			e[i] += TAU
	return e

## Fewer keys (the Dílna stays usable): a key only where the straight line from the last kept
## key would miss the recording by more than the tolerance. Keys move evenly between each other.
static func _reduce(keys: Array) -> Array:
	var out := []
	if keys.is_empty():
		return out
	var kept := [0]
	var a := 0
	var j := 2
	while j < keys.size():
		var ok := true
		for i in range(a + 1, j):
			var k := (float(keys[i][0]) - float(keys[a][0])) / maxf(0.0001, float(keys[j][0]) - float(keys[a][0]))
			for c in 6:
				var v := lerpf(float(keys[a][1][c]), float(keys[j][1][c]), k)
				if absf(v - float(keys[i][1][c])) > (TOL_POS if c < 3 else TOL_ROT):
					ok = false
					break
			if not ok:
				break
		if not ok:
			a = j - 1
			kept.append(a)
		j += 1
	if kept[-1] != keys.size() - 1:
		kept.append(keys.size() - 1)
	var last_t := -1.0
	for i in kept:
		var tt := snappedf(float(keys[i][0]), 0.01)
		if tt - last_t < 0.02 and i != kept[-1]:
			continue          # (AnimClips keys sit at least 0.02 s apart)
		if tt - last_t < 0.02:
			out.pop_back()
		var v := []
		for c in 6:
			v.append(snappedf(float(keys[i][1][c]), 0.0001 if c < 3 else 0.01))
		out.append({"t": tt, "v": v, "prechod": "rovnomerne"})
		last_t = tt
	return out

func _save(c: Dictionary, fr: Array, e: Dictionary) -> String:
	var id := clip_id(e)
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(raw_dir))
	var raw := FileAccess.open(raw_dir.path_join("%s_%s.json" % [id, stamp]), FileAccess.WRITE)
	if raw:
		raw.store_string(JSON.stringify({"zbran": id, "snimky": fr}))
		raw.close()
	var cid := id
	var dst := out_dir.path_join(cid + ".json")
	if FileAccess.file_exists(dst):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(dst), ProjectSettings.globalize_path(raw_dir.path_join("zaloha_%s_%s.json" % [cid, stamp])))
	var ok := false
	if out_dir == AnimClips.DIR:
		ok = AnimClips.save_clip(cid, c)
	else:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
		var f := FileAccess.open(dst, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(c, " ", false))
			f.close()
			ok = true
	return ("Uloženo: %s.json (%d klíčů zbraně, %d ruky)" % [cid, c["stopy"]["zbran"].size(), c["stopy"].get("ruka", []).size()]) if ok else "Uložení se nepovedlo!"

# ---- test without the headset ---------------------------------------------------------------------
## A made-up reload: the gun tips in, the left hand goes down to the magazine, pulls it out,
## throws it away, takes a new one from the belt, puts it in and goes back to the foregrip.
## A take saved before (animace/vr_zaznamy/<clip>_<time>.json) made into its clip again with
## today's rules (e.g. "hands only" for the backpack and the medkit) - no new recording needed.
## --vrconvert=<raw file>[,<raw file>...] [--vrout=<folder>] (default: next to the game's clips).
func _convert_raw(list: String) -> void:
	var dst := AnimClips.DIR
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--vrout="):
			dst = a.substr(8)
	for path in list.split(","):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		var cid := String(d.get("zbran", "")) if d is Dictionary else ""
		var e := {}
		for x in acts:
			if clip_id(x) == cid:
				e = x
		if e.is_empty():
			print("[VRCONVERT] %s: neznámý klip %s" % [path, cid])
			continue
		var c := convert_take(d["snimky"], String(e["gun"]), e)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dst))
		var f := FileAccess.open(dst.path_join(cid + ".json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(c, " ", false))
		f.close()
		print("[VRCONVERT] %s -> %s.json (%.2f s, jen ruce %s, klíče zbraň %d ruka %d)" % [path.get_file(), cid, c["delka"], c.get("jen_ruce", false), c["stopy"]["zbran"].size(), c["stopy"].get("ruka", []).size()])
	get_tree().quit()

func _run_test() -> void:
	var id := "rifle"
	gi = 0
	var e: Dictionary = acts[0]
	for i in acts.size():
		if clip_id(acts[i]) == "fp_reload_rifle":
			gi = i
			e = acts[i]
	_set_gun()
	var fr := []
	var n := 150
	var hs := Transform3D(Basis(), Vector3(0, 1.6, 0))
	var gn_rest := Transform3D(Basis.from_euler(Vector3(0.1, 0.05, 0)), Vector3(0.15, -0.24, -0.32))
	var l_rest := gn_rest * Transform3D(Basis.from_euler(Vector3(0.3, 0, 0.4)), Vector3(-0.04, 0.02, -0.3))
	for i in n:
		var tt := i / 90.0
		var k := sin(clampf(tt / 1.6, 0, 1) * PI)
		var gn := gn_rest * Transform3D(Basis.from_euler(Vector3(0.2 * k, 0.3 * k, -0.5 * k)), Vector3(-0.05, 0.05, 0.03) * k)
		var dip := sin(clampf((tt - 0.2) / 1.1, 0, 1) * PI)
		var lh := Transform3D(l_rest.basis.rotated(Vector3.RIGHT, 0.6 * dip), l_rest.origin + Vector3(0.03, -0.25, 0.2) * dip)
		fr.append({"t": tt, "gn": _tf(hs.affine_inverse() * hs * gn), "lh": _tf(lh), "grip": tt > 0.45 and tt < 1.2, "trig": i == 140})
	var c := convert_take(fr, id, e)
	var ch := convert_take(fr, id, acts[-2])
	print("[VRTEST] acts=%d heal=%s events=%s" % [acts.size(), clip_id(acts[-2]), ch["udalosti"].map(func(x): return x["typ"])])
	var g_at0 := AnimClips.xform(c, "zbran", 0.0)
	var g_mid := AnimClips.xform(c, "zbran", 0.8)
	print("[VRTEST] delka=%.2f zbran_keys=%d ruka_keys=%d events=%d" % [c["delka"], c["stopy"]["zbran"].size(), c["stopy"].get("ruka", []).size(), c["udalosti"].size()])
	print("[VRTEST] start_off=%.4f mid_off=%.3f end_off=%.4f" % [g_at0.origin.length(), g_mid.origin.length(), AnimClips.xform(c, "zbran", c["delka"]).origin.length()])
	var r0 := AnimClips.xform(c, "ruka", 0.0)
	print("[VRTEST] ruka0=%s ruka0_rot=%s" % [r0.origin, r0.basis.get_euler() * (180.0 / PI)])
	print("[VRTEST] udalosti=%s" % [c["udalosti"].map(func(x): return "%.2f %s" % [x["t"], x["typ"]])])
	print("[VRTEST] " + _save(c, fr, e))
	clip = c
	state = "play"
	head.position = Vector3(0, 1.6, 0)
	for shot in [0.0, 0.7, 1.0]:
		_ghost(c, shot)
		gun_node.visible = false
		ghost.visible = true
		_show()
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://vrtest/vrtest_%d.png" % int(shot * 10))
	print("[VRTEST] diag: " + _diag())
	print("[VRTEST] done")
	get_tree().quit()
