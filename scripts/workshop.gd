extends Control
## Dílna (the Workshop): Ari fixes how items sit in the hands and corrects poses himself.
## Everything changed here goes to Game.tweaks and is saved to upravy.json next to the game;
## the game applies it at once (held items, hold poses, salute/at ease/hips, alien jobs).

const PlayerScript := preload("res://scripts/player.gd")
const AlienScript := preload("res://scripts/alien.gd")

const MODES := [["fp", "Předmět v ruce - z očí"], ["tp", "Předmět v ruce - zvenku (+ ruce)"], ["back", "Zbraň na zádech"],
	["emote", "Pózy vojáka (pozdrav, pohov, v bok)"], ["alien", "Vetřelci - práce a postoje"],
	["agun", "Zbraň vetřelce (kotva v ruce)"],
	["anim", "ANIMACE → editor Animace (všechny pohyby)"]]
const EMOTES := [["hips", "Ruce v bok (stání)"]]      # (0.57: salute, at ease and the wheel are afk movements)
const ALIENS := ["grey", "grey_velitel", "jestetan", "bijec", "lihnoun", "zombie", "ohar"]
const ALIEN_ACTS := {"grey": ["work", "work_high", "talk", "stare"], "grey_velitel": ["work", "work_high", "talk", "stare"],
	"jestetan": ["guard", "stare"], "bijec": ["guard", "stare"], "lihnoun": ["eat"], "zombie": ["sway"], "ohar": ["sniff"]}
const ACT_NAMES := {"work": "práce u krávy (klečí)", "work_high": "oprava UFO (ruce nahoru)", "talk": "šeptání ve dvou", "stare": "zírání",
	"guard": "hlídka", "eat": "hodování", "sway": "kymácení", "sniff": "čmuchání"}
## 0.57: what the soldier does while you place the item - the game's own movements (afk), the
## handgun ones when it is one. Body movements (tp_body_*) or the hands' actions over standing.
const HOLD_ACTS := [["tp_body_idle", "stojí"], ["tp_body_idle_2", "stojí 2 (rozhlíží se)"], ["tp_body_idle_3", "stojí 3"],
	["tp_body_idle_4", "stojí 4"], ["tp_body_idle_5", "stojí 5"], ["tp_body_idle_hurt", "stojí zraněný"], ["tp_body_walk_hurt", "kulhá"], ["tp_body_idle_aim", "míří"], ["tp_body_walk", "chůze"], ["tp_body_walk_back", "chůze dozadu"],
	["tp_body_walk_left", "úkrok vlevo"], ["tp_body_walk_right", "úkrok vpravo"], ["tp_body_run", "běh"], ["tp_body_sprint", "sprint"],
	["tp_body_crouch", "klek"], ["tp_body_crouch_aim", "klek - míří"], ["tp_body_crouch_fire", "klek - střílí"], ["tp_body_crouch_fire_walk", "plížení - střílí"], ["tp_body_crouch_walk", "plížení"], ["tp_body_prone", "leh"],
	["tp_body_jump", "skok"], ["tp_body_turn_left", "otočka"], ["tp_body_fire", "střílí"], ["tp_body_fire_walk", "střílí v chůzi"],
	["tp_body_fire_run", "střílí v běhu"], ["reload", "přebíjí"], ["strike", "úder"], ["throw", "hod granátu"],
	["draw", "bere zbraň"], ["use", "použití"], ["heal", "ošetřuje"]]

## 0.57 Zbraň vetřelce: the gun in an alien's hand (alien.gd _attach_gun, anchors "agun/<model>/<weapon>").
## The models come from the game (assets/models) and, while they are being made, from Ari's folder
## of new models (animace/Maximo/postavy, *_v2[_rig].glb, read straight from the file).
const AG_DIR := "res://animace/Maximo/postavy"
const AG_WEAPONS := ["a_rifle", "a_heavy", "a_pistol"]
const AG_CLIPS := [["idle", "stojí"], ["walk", "chůze"], ["run", "běh"], ["lurk", "číhá"], ["lurk_walk", "plíží se"], ["aim", "míří"], ["fire", "střílí"], ["attack", "útok"], ["roar", "řev"]]
var _ag_race := ""
var _ag_w := ""
var _ag_w_opt: OptionButton

var mode := "fp"
var subject := ""            # item id / emote / alien race
var sub2 := ""               # tp: act, alien: job
var bone := ""
var view: SubViewport
var svc: SubViewportContainer
var world: Node3D
var cam: Camera3D
var model: Node3D            # what is shown (merc, alien, or the first-person hands)
var item_node: Node3D        # the item being placed
var holder: Node3D           # where the item hangs
var sk: Skeleton3D
var anim: AnimationPlayer
var t := 0.0
var yaw := 0.6
var pitch := -0.15
var dist := 2.4
var target := Vector3(0, 1.1, 0)
var dragging := false

var panel_box: VBoxContainer
var subj_opt: OptionButton
var sub2_opt: OptionButton
var bone_opt: OptionButton
var item_sliders := {}       # "pos.x" -> HSlider
var bone_sliders := {}       # "x" -> HSlider
var status: Label
var _syncing := false
var grip_sliders := {}       # "x" -> HSlider (left hand on the gun)
var _paused := false
var _bone_drag := false
var _grip_on := true
var _clip: Variant = null    # copied tweak (Dictionary) and what kind it was
var _clip_kind := ""
var _undo_stack := []
# ---- the editing handles (as in the Svitky editor): rings turn a joint or the item, arrows move the item
const AXIS_COL := [Color(0.92, 0.27, 0.24), Color(0.43, 0.82, 0.31), Color(0.31, 0.55, 0.98)]
var focus := "bone"          # what the handles work on: "bone", "item" or "none"
var _item_tool := "posun"    # the item: "posun" (arrows) or "otaceni" (rings)
var _giz: MeshInstance3D
var _hint: Label
var _pause_cb: CheckBox
var _hover_k := -1
var _drag_k := -1
var _drag_tan := Vector2.ZERO
var _dots := {}
var _undo_t := 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.texture = UiSkin.backdrop()
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# the 3D view on the left
	var frame := PanelContainer.new()
	_frame = frame
	frame.add_theme_stylebox_override("panel", UiSkin.inset(3))
	frame.position = Vector2(6, 20)
	frame.size = Vector2(384, 314)
	add_child(frame)
	svc = SubViewportContainer.new()
	svc.stretch = true
	svc.gui_input.connect(_view_input)
	# a holder at the frame's size; the view inside renders at the screen's real resolution
	var holder := Control.new()
	_vholder = holder
	holder.custom_minimum_size = Vector2(378, 308)
	holder.clip_contents = true
	frame.add_child(holder)
	holder.add_child(svc)
	view = SubViewport.new()
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	svc.add_child(view)
	world = Node3D.new()
	view.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.13, 0.15, 0.17)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.58, 0.62)
	env.environment = e
	world.add_child(env)
	for d in [[Vector3(-40, 30, 0), 1.3], [Vector3(-20, 210, 0), 0.5]]:
		var l := DirectionalLight3D.new()
		l.rotation_degrees = d[0]
		l.light_energy = d[1]
		world.add_child(l)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6, 6)
	floor.mesh = pm
	floor.material_override = Game.color_mat(Color(0.22, 0.24, 0.26))
	floor.name = "Floor"
	world.add_child(floor)
	cam = Camera3D.new()
	world.add_child(cam)
	# the controls on the right
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiSkin.panel(6))
	p.position = Vector2(396, 20)
	p.size = Vector2(238, 314)
	add_child(p)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(sc)
	panel_box = VBoxContainer.new()
	panel_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_box.add_theme_constant_override("separation", 2)
	sc.add_child(panel_box)
	var title := Label.new()
	title.text = "Dílna"
	UiSkin.title(title, 12)
	panel_box.add_child(title)
	var mode_opt := _opt(panel_box)
	for m in MODES:
		mode_opt.add_item(m[1])
	mode_opt.item_selected.connect(func(i):
		if MODES[i][0] == "anim":
			# the animations have their own editor now (time line, rings, the whole body)
			get_tree().change_scene_to_file("res://scenes/Animator.tscn")
			return
		mode = MODES[i][0]
		_rebuild_panel())
	var dyn := VBoxContainer.new()
	dyn.name = "Dyn"
	dyn.add_theme_constant_override("separation", 2)
	panel_box.add_child(dyn)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 7)
	status.add_theme_color_override("font_color", UiSkin.DIM)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD
	panel_box.add_child(status)
	var row := HBoxContainer.new()
	panel_box.add_child(row)
	_btn(row, "Uložit", func():
		if Game.save_tweaks():
			status.text = "Uloženo do " + Game.tweak_path() + "\nTen soubor pošli Claudovi, zapíše to natrvalo."
			Game.play_ui(self, "ui_confirm", -6)
		else:
			status.text = "Nepodařilo se uložit do " + Game.tweak_path()
			Game.play_ui(self, "ui_deny", -6))
	_btn(row, "Vynulovat", _reset_current)
	var row2 := HBoxContainer.new()
	panel_box.add_child(row2)
	_btn(row2, "Kopírovat", _copy)
	_btn(row2, "Vložit", _paste)
	_btn(row2, "Zrcadlit L/P", _mirror)
	_btn(row2, "Krok zpět", _undo)
	var row3 := HBoxContainer.new()
	panel_box.add_child(row3)
	var pause := CheckBox.new()
	_pause_cb = pause
	pause.text = "Zastavit pohyb"
	pause.add_theme_font_size_override("font_size", 8)
	pause.toggled.connect(func(on): _paused = on)
	row3.add_child(pause)
	_btn(row3, "Kontrola modelů", func():
		var rep := model_check()
		status.text = "Kontrola modelů: %d problémů, %d poznámek. Celé v %s" % [rep[0], rep[1], rep[2]]
		Game.play_ui(self, "ui_confirm" if rep[0] == 0 else "ui_deny", -6))
	var row4 := HBoxContainer.new()
	panel_box.add_child(row4)
	for v in [["Zepředu", PI, 0.0], ["Z boku", PI * 0.5, 0.0], ["Shora", PI, -1.2], ["Zezadu", 0.0, -0.1]]:
		var vy: float = v[1]
		var vp: float = v[2]
		_btn(row4, v[0], func(): yaw = vy; pitch = vp)
	_giz = MeshInstance3D.new()
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.vertex_color_use_as_albedo = true
	gm.no_depth_test = true
	gm.render_priority = 10
	gm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_giz.material_override = gm
	world.add_child(_giz)
	EditorTabs.add(self, "hands")
	_hint = EditorTabs.hint(self)
	_rebuild_panel()
	if Game.autotest() == "workshop":
		_selftest.call_deferred()
	if Game.autotest() == "wsclick":
		_clicktest.call_deferred()
	if Game.autotest() == "animtest":
		_animtest.call_deferred()
	if Game.autotest() == "animshots":
		_animshots.call_deferred()
	if Game.autotest() == "agun":
		_aguntest.call_deferred()
	if Game.autotest() == "modelcheck":
		var rep := model_check()
		print("RESULT modelcheck %d problems %d notes" % [rep[0], rep[1]])
		get_tree().quit.call_deferred()

## Real clicks through the window: a joint (left forearm), then a drag on its red ring, then the gun.
func _mouse(win: Vector2, pressed: Variant, rel := Vector2.ZERO) -> void:
	var ev: InputEvent
	if pressed == null:
		var mm := InputEventMouseMotion.new()
		mm.position = win; mm.global_position = win; mm.relative = rel; mm.button_mask = MOUSE_BUTTON_MASK_LEFT
		ev = mm
	else:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT; mb.pressed = pressed; mb.position = win; mb.global_position = win
		ev = mb
	Input.parse_input_event(ev)
	for f in 2: await get_tree().process_frame

func _win_of(w: Vector3) -> Vector2:
	return get_viewport().get_final_transform() * (svc.get_global_transform() * (cam.unproject_position(w) / (Vector2(view.size) / svc.size)))

func _clicktest() -> void:
	var keep := Game.tweaks.duplicate(true)
	mode = "emote"          # (0.57: the joints are turned in the poses; "tp" plays the game's movements)
	_rebuild_panel()
	for f in 15: await get_tree().process_frame
	var bi := sk.find_bone("head")
	var jw := sk.global_transform * sk.get_bone_global_pose(bi).origin
	var win := _win_of(jw)
	await _mouse(win, true)
	await _mouse(win, false)
	print("[WSC] clicked joint -> bone %s" % bone)
	var _bone_ok := bone == "head"
	for f in 3: await get_tree().process_frame
	var h := _handles()
	var pts := _ring_pts(h[0], h[1][0], _gsize())
	var rp: Vector3 = pts[5]
	var w0 := _win_of(rp)
	var loc := (svc.get_global_transform().affine_inverse() * (get_viewport().get_final_transform().affine_inverse() * w0))
	print("[WSC] focus %s handles %s hit %s" % [focus, not _handles().is_empty(), _handle_at(loc)])
	var x0: float = bone_sliders["x"].value + bone_sliders["y"].value * 1000.0 + bone_sliders["z"].value * 1000000.0
	await _mouse(w0, true)
	var w1 := _win_of(pts[8])
	for i in 6:
		await _mouse(w0.lerp(w1, (i + 1) / 6.0), null, (w1 - w0) / 6.0)
	await _mouse(w1, false)
	var x1: float = bone_sliders["x"].value + bone_sliders["y"].value * 1000.0 + bone_sliders["z"].value * 1000000.0
	print("[WSC] ring drag: changed %s" % (x1 != x0))
	if DisplayServer.get_name() != "headless":
		get_viewport().get_texture().get_image().save_png("user://ws_rings.png")
	mode = "tp"
	_rebuild_panel()
	for f in 15: await get_tree().process_frame
	var ib: AABB = (item_node.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).global_transform * (item_node.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).get_aabb()
	var far: Vector3 = ib.get_center()
	for ci in 8:
		if ib.get_endpoint(ci).distance_to(jw) > far.distance_to(jw): far = ib.get_endpoint(ci)
	focus = "none"
	for lt in [0.3, 0.45, 0.6, 0.15]:
		var iw := _win_of(ib.get_center().lerp(far, lt))
		await _mouse(iw, true)
		await _mouse(iw, false)
		if focus == "item":
			break
	print("[WSC] clicked gun -> focus %s" % focus)
	if DisplayServer.get_name() != "headless":
		for f in 3: await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("user://ws_gizmo.png")
	print("RESULT wsclick bone %s ring %s item %s" % [_bone_ok, x1 != x0, focus == "item"])
	Game.tweaks = keep
	get_tree().quit()

## Test: every mode, a tweak each, screenshots, then put everything back.
func _selftest() -> void:
	var keep := Game.tweaks.duplicate(true)
	var shots := [["fp", "rifle"], ["tp", "rifle"], ["back", "rifle"], ["emote", "salute"], ["alien", "grey"], ["alien", "lihnoun"]]
	for e in shots:
		mode = e[0]
		_rebuild_panel()
		var opts: OptionButton = subj_opt
		for i in opts.item_count:
			if String(opts.get_item_metadata(i)) == e[1]:
				opts.select(i)
				subject = e[1]
		_fill_sub2()
		_build_scene()
		if not item_sliders.is_empty():
			item_sliders["pos.y"].value = 0.02
			item_sliders["rot.z"].value = 10
		if not bone_sliders.is_empty() and mode != "tp":
			bone_sliders["x"].value = 15
		if mode == "tp":
			yaw = PI * 0.5 + 0.2
			pitch = -0.3
		for f in 20:
			await get_tree().process_frame
		print("[WS] %s %s bone=%s ik_err=%.3f" % [mode, subject, bone, _ik_err])
		get_viewport().get_texture().get_image().save_png("user://ws_%s_%s.png" % [mode, subject])
	Game.tweaks = keep
	get_tree().quit()

## Zbraň vetřelce in every model that has a hand: the gun is there and follows the slider.
func _aguntest() -> void:
	var keep := Game.tweaks.duplicate(true)
	mode = "agun"
	_rebuild_panel()
	var n := 0
	var ok := 0
	for i in subj_opt.item_count:
		subj_opt.select(i)
		subj_opt.item_selected.emit(i)
		for f in 5:
			await get_tree().process_frame
		if holder == null:
			print("[AGUN] %s: bez ruky" % subject)
			continue
		n += 1
		var p0 := item_node.global_position
		item_sliders["pos.y"].value = item_sliders["pos.y"].value + 0.1
		for f in 3:
			await get_tree().process_frame
		var moved := item_node.global_position.distance_to(p0) > 0.05
		ok += 1 if moved else 0
		print("[AGUN] %s %s moved %s" % [subject, _ag_w, moved])
		get_viewport().get_texture().get_image().save_png("user://agun_%s.png" % subject)
	Game.tweaks = keep
	print("RESULT agun %d of %d" % [ok, n])
	get_tree().quit()

## Kontrola modelů: what each model needs so that the game and the Dílna can use it - the bones
## by the game's names, the movements, the hands model for the eyes view, an anchor. Written to
## kontrola_modelu.txt next to upravy.json. Returns [problems, notes, path].
const NEED_BONES := ["root", "hips", "spine", "neck", "head", "upperarm.L", "forearm.L", "upperarm.R", "forearm.R", "thigh.L", "shin.L", "thigh.R", "shin.R"]
const NEED_CLIPS := ["idle", "walk", "run", "lurk", "aim"]
static func model_check() -> Array:
	var lines := []
	var bad := 0
	var notes := 0
	lines.append("KONTROLA MODELŮ  (! = problém, - = poznámka)")
	lines.append("")
	lines.append("ZBRANĚ A VĚCI DO RUKY")
	for id in Game.ITEMS:
		if not ResourceLoader.exists("res://assets/models/%s.glb" % id) or id.begins_with("a_pack"):
			continue
		var it: Dictionary = Game.ITEMS[id]
		if it.get("type", "") != "weapon":
			continue
		var msg := []
		var b2 := 0
		if Game.two_handed(id):
			if not ResourceLoader.exists("res://assets/models/hands_%s.glb" % id) and not id in ["a_rifle", "a_heavy"]:
				msg.append("! chybí ruce pro pohled z očí (hands_%s.glb)" % id); b2 += 1
			if not PlayerScript.VM_R.has(id):
				msg.append("- z očí bez vlastní polohy (player.VM_R)")
			if not Game.tweaks.has("tpa/" + id):
				msg.append("- zvenku bez vlastní kotvy (tpa/%s), drží se podle obrysu" % id)
		elif not Game.tweaks.has("tp/" + id):
			msg.append("- zvenku bez vlastní kotvy (tp/%s)" % id)
		bad += b2
		notes += msg.size() - b2
		lines.append("%s %s%s" % ["!" if b2 > 0 else " ", id, (": " + ", ".join(msg)) if not msg.is_empty() else ": v pořádku"])
	lines.append("")
	lines.append("VETŘELCI (modely ze hry a nové *_v2)")
	var keys := []
	for r in AlienScript.RACES:
		var m := String(AlienScript.RACES[r]["model"])
		for k in [m, m + "_v2"]:
			if keys.any(func(e): return e[0] == k):
				continue
			if ResourceLoader.exists("res://assets/models/%s.glb" % k) or ag_file(k) != "":
				keys.append([k, r])
	for e in keys:
		var k: String = e[0]
		var r: String = e[1]
		var n := ag_model(k)
		var sk: Skeleton3D = n.find_child("Skeleton3D", true, false)
		var ap: AnimationPlayer = n.find_child("AnimationPlayer", true, false)
		var msg := []
		var b2 := 0
		var src := "hra" if ResourceLoader.exists("res://assets/models/%s.glb" % k) else ag_file(k).get_file()
		if sk == null:
			if not k.trim_suffix("_v2") in ["diskoll", "levit", "levit_velitel", "myslodej", "nador", "ohnivec", "kolos", "mozek", "pylon"]:
				msg.append("! bez kostry"); b2 += 1
			else:
				msg.append("- bez kostry (hýbe se kódem)")
		else:
			var miss := []
			for bn in NEED_BONES:
				if sk.find_bone(bn) < 0:
					miss.append(bn)
			if not miss.is_empty():
				msg.append("! chybí kosti " + ", ".join(miss)); b2 += 1
			var tail := 0
			for i in sk.get_bone_count():
				if sk.get_bone_name(i).begins_with("tail."):
					tail += 1
			if tail > 0:
				msg.append("- ocas %d kostí" % tail)
			var cm := []
			for c in NEED_CLIPS:
				if ap == null or not ap.has_animation(c):
					cm.append(c)
			if not cm.is_empty():
				if k.ends_with("_v2"):
					msg.append("- zatím bez pohybů " + ", ".join(cm))
				else:
					msg.append("! chybí pohyby " + ", ".join(cm)); b2 += 1
		var w := AlienScript.gun_item(r, "rifle")
		if w != "" and not k in AlienScript.BAKED_GUN:
			if sk != null and sk.find_bone("hand.R") < 0 and not r in AlienScript.FLOAT_GUN:
				msg.append("! nosí zbraň, ale nemá kost hand.R"); b2 += 1
			elif not Game.tweaks.has("agun/%s/%s" % [AlienScript.anchor_model(k, w), w]):
				msg.append("- zbraň %s bez kotvy (Dílna: Zbraň vetřelce)" % w)
		n.free()
		bad += b2
		notes += msg.size() - b2
		lines.append("%s %s [%s, %s]%s" % ["!" if b2 > 0 else " ", k, r, src, (": " + ", ".join(msg)) if not msg.is_empty() else ": v pořádku"])
	lines.append("")
	lines.append("Celkem: %d problémů, %d poznámek." % [bad, notes])
	var path := Game.tweak_path().get_base_dir().path_join("kontrola_modelu.txt")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\n")
	for l in lines:
		print("[MODEL] " + l)
	return [bad, notes, path]

# ---- small UI helpers ----------------------------------------------------------------------------
func _opt(parent: Node) -> OptionButton:
	var o := OptionButton.new()
	o.add_theme_font_size_override("font_size", 8)
	o.fit_to_longest_item = false
	parent.add_child(o)
	return o

func _btn(parent: Node, s: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = s
	b.add_theme_font_size_override("font_size", 8)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiSkin.button(b)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _lbl(parent: Node, s: String, col := UiSkin.GLOW) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", col)
	if parent is HBoxContainer:
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER    # (a label in a row: no wrapping)
	else:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
	parent.add_child(l)
	return l

func _slider(parent: Node, name: String, lo: float, hi: float, step: float, cb: Callable) -> HSlider:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var l := Label.new()
	l.text = name
	l.custom_minimum_size = Vector2(46, 0)
	l.add_theme_font_size_override("font_size", 7)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(0, 12)
	row.add_child(s)
	var v := Label.new()
	v.custom_minimum_size = Vector2(36, 0)
	v.add_theme_font_size_override("font_size", 7)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)
	s.value_changed.connect(func(x):
		v.text = ("%.3f" if step < 0.01 else "%.0f") % x
		if not _syncing:
			cb.call())
	return s

# ---- the panel for the current mode ----------------------------------------------------------------
func _rebuild_panel() -> void:
	var dyn: VBoxContainer = panel_box.get_node("Dyn")
	for c in dyn.get_children():
		c.queue_free()
	item_sliders.clear()
	bone_sliders.clear()
	grip_sliders.clear()
	bone_opt = null
	sub2 = ""
	bone = ""
	_anim_layout()
	if mode in ["atp", "afp"]:
		_build_anim_panel(dyn)
		return
	subj_opt = _opt(dyn)
	var subjects := []
	match mode:
		"fp", "tp":
			for id in Game.ITEMS:
				if ResourceLoader.exists("res://assets/models/%s.glb" % id) and not id.begins_with("a_pack"):
					subjects.append([id, Game.ITEMS[id]["name"]])
		"back":
			for id in Game.ITEMS:
				if Game.ITEMS[id].get("type", "") == "weapon" and Game.two_handed(id):
					subjects.append([id, Game.ITEMS[id]["name"]])
		"emote":
			subjects = EMOTES
		"alien":
			for r in ALIENS:
				subjects.append([r, String(AlienScript.RACES[r]["name"])])
		"agun":
			subjects = ag_models()
	for s in subjects:
		subj_opt.add_item(s[1])
		subj_opt.set_item_metadata(subj_opt.item_count - 1, s[0])
	subject = subjects[0][0]
	_ag_race = String(subjects[0][2]) if mode == "agun" else ""
	subj_opt.item_selected.connect(func(i):
		subject = subj_opt.get_item_metadata(i)
		if mode == "agun":
			_ag_race = String(subjects[i][2])
			_ag_fill_weapons()
		_fill_sub2()
		_build_scene())
	_ag_w_opt = null
	if mode == "agun":
		_ag_w_opt = _opt(dyn)
		_ag_w_opt.item_selected.connect(func(i): _ag_w = String(_ag_w_opt.get_item_metadata(i)); _mark_sub2(); _build_scene())
		_ag_fill_weapons()
	sub2_opt = _opt(dyn)
	sub2_opt.item_selected.connect(func(i):
		sub2 = String(sub2_opt.get_item_metadata(i))
		_sync_sliders()
		if mode == "agun":
			_ag_play()        # (the same model: just its other movement)
		else:
			_build_scene())
	if mode in ["fp", "tp", "back", "agun"]:
		_lbl(dyn, "POSUN A NATOČENÍ PŘEDMĚTU")
		if mode in ["tp", "agun"]:
			var pc := CheckBox.new()
			pc.text = "Jen pro tento pohyb (zbraně)"
			pc.button_pressed = _per_clip
			pc.tooltip_text = "Zapnuto: posun a natočení platí jen v pohybu vybraném nahoře, navíc k obecnému nastavení.\nVypnuto: obecné nastavení zbraně pro všechny pohyby."
			pc.toggled.connect(func(on): _per_clip = on; _sync_sliders())
			dyn.add_child(pc)
		for k in [["pos.x", "doprava", -0.3, 0.3, 0.002], ["pos.y", "nahoru", -0.3, 0.3, 0.002], ["pos.z", "dozadu", -0.3, 0.3, 0.002],
				["rot.x", "kývnutí", -180, 180, 1], ["rot.y", "otočení", -180, 180, 1], ["rot.z", "náklon", -180, 180, 1], ["scale", "velikost", 0.5, 2.0, 0.01]]:
			var key: String = k[0]
			item_sliders[key] = _slider(dyn, k[1], k[2], k[3], k[4], func(): _item_changed())
	if mode == "agun":
		_lbl(dyn, "Vetřelec hraje svůj pohyb ze hry, zbraň drží v pravé ruce. Kotva platí pro tento model a tuto zbraň (velitel bez vlastní převezme kotvu obyčejného). Tečka • = pohyb má vlastní úpravu. Nový model se jmenuje jako soubor (např. bijec_v2) – stejné jméno mu dej i ve hře.", UiSkin.DIM)
	if mode == "tp":
		_lbl(dyn, "Voják hraje pohyby ze hry (afk) - vyber nahoře, co dělá. Mezerník pauza. Dlouhá zbraň: posun a natočení jsou vůči úchopu (x doprava, y nahoru, z podél hlavně), hlaveň míří k levé ruce sama. Platí hned i ve hře.", UiSkin.DIM)
	if mode in ["emote", "alien"]:
		_lbl(dyn, "KOST (natočení navíc ke stávající póze)")
		bone_opt = _opt(dyn)
		bone_opt.item_selected.connect(func(i): bone = String(bone_opt.get_item_metadata(i)); _sync_sliders())
		for ax in [["x", "předklon"], ["y", "otočení"], ["z", "do strany"]]:
			var a: String = ax[0]
			bone_sliders[a] = _slider(dyn, ax[1], -180, 180, 1, func(): _bone_changed())
		_lbl(dyn, "Klikni na kloub v obrázku a táhni: nahoru/dolů ho ohýbá, do stran otáčí, se Shiftem naklání do strany. Pravé tlačítko otáčí pohled.", UiSkin.DIM)
	if false:
		_lbl(dyn, "LEVÁ RUKA NA ZBRANI (oranžová tečka)")
		for ax in [["x", "do strany"], ["y", "nahoru"], ["z", "dopředu/zpět"]]:
			var a2: String = ax[0]
			grip_sliders[a2] = _slider(dyn, ax[1], -0.8, 0.8, 0.002, func(): _grip_changed())
		_lbl(dyn, "Levá ruka se sama chytí zbraně - posuneš zbraň nebo pravou ruku a levá jde s ní.", UiSkin.DIM)
	_lbl(dyn, "Myš: tažení mimo kloub (nebo pravým tlačítkem) otáčí pohled, kolečko přibližuje." if mode != "fp" else "Pohled je přesně z očí vojáka.", UiSkin.DIM)
	_fill_sub2()
	_build_scene()

func _fill_sub2() -> void:
	sub2_opt.clear()
	sub2_opt.visible = mode in ["tp", "alien", "agun"]
	if mode == "tp":
		for a in HOLD_ACTS:
			if _tp_clip(String(a[0])).is_empty():
				continue
			sub2_opt.add_item(a[1])
			sub2_opt.set_item_metadata(sub2_opt.item_count - 1, a[0])
	elif mode == "agun":
		for a in AG_CLIPS:
			sub2_opt.add_item(a[1])
			sub2_opt.set_item_metadata(sub2_opt.item_count - 1, a[0])
	elif mode == "alien":
		for a in ALIEN_ACTS.get(subject, []):
			sub2_opt.add_item(ACT_NAMES.get(a, a))
			sub2_opt.set_item_metadata(sub2_opt.item_count - 1, a)
	sub2 = String(sub2_opt.get_item_metadata(0)) if sub2_opt.item_count > 0 else ""
	_mark_sub2()

## The movements that have their own correction for this thing: a dot after the name.
func _mark_sub2() -> void:
	if sub2_opt == null or not mode in ["tp", "agun"]:
		return
	for i in sub2_opt.item_count:
		var a := String(sub2_opt.get_item_metadata(i))
		var own := false
		if mode == "agun":
			own = Game.tweaks.has("agun/%s/%s@%s" % [AlienScript.anchor_model(subject, _ag_w), _ag_w, a])
		else:
			own = Game.tweaks.has("tpa/%s@%s" % [subject, a])
		var nm := sub2_opt.get_item_text(i).trim_suffix(" •")
		sub2_opt.set_item_text(i, nm + (" •" if own else ""))

## The tweak key edited right now.
func _item_key() -> String:
	if mode == "agun":
		if _per_clip and sub2 != "":
			return "agun/%s/%s@%s" % [AlienScript.anchor_model(subject, _ag_w), _ag_w, sub2]
		return "agun/%s/%s" % [subject, _ag_w]       # (its own; until then the sliders show what it takes over)
	if mode == "tp" and _per_clip and sub2.begins_with("tp_body_") and Game.ITEMS.get(subject, {}).get("type", "") == "weapon":
		return "tpa/%s@%s" % [subject, sub2]      # only in this movement (over the general one)
	if mode == "tp" and _long_gun():
		return "tpa/" + subject       # 0.57: the long gun in the afk hands (player.afk_gun_xform)
	return {"fp": "fp/", "tp": "tp/", "back": "back/"}.get(mode, "") + subject

## A two-handed gun: the game puts it from the right hand towards the left (player.afk_gun_xform).
func _long_gun() -> bool:
	return Game.ITEMS.get(subject, {}).get("type", "") == "weapon" and Game.two_handed(subject)

func _pose_key() -> String:
	match mode:
		"tp": return "hold/" + subject
		"emote": return "emote/" + subject
		"alien": return "act/" + sub2
	return ""

func _grip_changed() -> void:
	_push_undo()
	Game.tweaks["grip/" + subject] = {"l": [grip_sliders["x"].value, grip_sliders["y"].value, grip_sliders["z"].value]}

## Undo: a snapshot of all tweaks before a change (one per drag, not per pixel).
func _push_undo() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _undo_t > 0.7:
		_undo_stack.append(Game.tweaks.duplicate(true))
		if _undo_stack.size() > 60:
			_undo_stack.pop_front()
	_undo_t = now

func _undo() -> void:
	if _undo_stack.is_empty():
		status.text = "Není co vracet."
		return
	Game.tweaks = _undo_stack.pop_back()
	_undo_t = 0.0
	_sync_sliders()
	_place_item()
	status.text = "Krok zpět."

func _input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed and not ev.echo):
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	if mode in ["atp", "afp"] and _an_key(ev):
		get_viewport().set_input_as_handled()
		return
	var done := true
	match ev.keycode:
		KEY_Z when ev.ctrl_pressed: _undo()
		KEY_S when ev.ctrl_pressed: _save()
		KEY_SPACE: _pause_cb.button_pressed = not _pause_cb.button_pressed
		KEY_G: _item_tool = "posun"; focus = "item"; status.text = "Předmět: posun šipkami."
		KEY_R: _item_tool = "otaceni"; focus = "item"; status.text = "Předmět: otáčení kruhy."
		KEY_TAB: focus = "item" if focus == "bone" else "bone"
		KEY_ESCAPE: focus = "none"
		_: done = false
	if done:
		get_viewport().set_input_as_handled()

func _save() -> void:
	if Game.save_tweaks():
		status.text = "Uloženo do " + Game.tweak_path()
		Game.play_ui(self, "ui_confirm", -6)
	else:
		status.text = "Nepodařilo se uložit do " + Game.tweak_path()
		Game.play_ui(self, "ui_deny", -6)

## Copy / paste: an item placement onto another item, or a pose (all its bones) onto another pose.
func _copy() -> void:
	if not bone_sliders.is_empty() and Game.tweaks.has(_pose_key()):
		_clip = Game.tweaks[_pose_key()].duplicate(true)
		_clip_kind = "pose"
		status.text = "Zkopírována póza (%d kostí). Vyber jinou pózu a dej Vložit." % _clip.size()
	elif not item_sliders.is_empty() and Game.tweaks.has(_item_key()):
		_clip = Game.tweaks[_item_key()].duplicate(true)
		_clip_kind = "item"
		status.text = "Zkopírováno umístění předmětu. Vyber jiný předmět a dej Vložit."
	else:
		status.text = "Tady zatím není žádná úprava ke zkopírování."

func _paste() -> void:
	if _clip == null:
		status.text = "Nejdřív něco zkopíruj."
		return
	_push_undo()
	_undo_t = 0.0
	if _clip_kind == "pose" and not bone_sliders.is_empty():
		Game.tweaks[_pose_key()] = _clip.duplicate(true)
		status.text = "Póza vložena."
	elif _clip_kind == "item" and not item_sliders.is_empty():
		Game.tweaks[_item_key()] = _clip.duplicate(true)
		status.text = "Umístění vloženo."
	else:
		status.text = "Tohle sem vložit nejde (póza jde jen do pózy, předmět do předmětu)."
		return
	_sync_sliders()
	_place_item()

## Mirror the pose: what the right arm does, the left does (and back), turned the other way.
func _mirror() -> void:
	if bone_sliders.is_empty():
		status.text = "Zrcadlit jde jen póza."
		return
	_push_undo()
	_undo_t = 0.0
	var d: Dictionary = Game.tweaks.get(_pose_key(), {})
	var out := {}
	for b in d:
		var o: String = b
		if b.ends_with(".L"): o = b.trim_suffix(".L") + ".R"
		elif b.ends_with(".R"): o = b.trim_suffix(".R") + ".L"
		var v: Array = d[b]
		out[o] = [v[0], -float(v[1]), -float(v[2])]
	Game.tweaks[_pose_key()] = out
	_sync_sliders()
	status.text = "Póza zrcadlena (levá a pravá strana prohozené)."

func _item_changed() -> void:
	if mode == "afp":
		if _an_sel == "":
			return
		_an_undo_push()
		AnimClips.set_key(_ac, _an_sel, _an_t, [item_sliders["pos.x"].value, item_sliders["pos.y"].value, item_sliders["pos.z"].value,
			item_sliders["rot.x"].value, item_sliders["rot.y"].value, item_sliders["rot.z"].value])
		_an_dirty = true
		_an_play = false
		return
	_push_undo()
	if mode == "agun":
		# a commander that took the plain model's anchor gets its own copy before anything changes
		var own := "agun/%s/%s" % [subject, _ag_w]
		var inh := "agun/%s/%s" % [AlienScript.anchor_model(subject, _ag_w), _ag_w]
		if not Game.tweaks.has(own) and Game.tweaks.has(inh) and inh != own:
			Game.tweaks[own] = (Game.tweaks[inh] as Dictionary).duplicate(true)
	var t2 := {"pos": [item_sliders["pos.x"].value, item_sliders["pos.y"].value, item_sliders["pos.z"].value],
		"rot": [item_sliders["rot.x"].value, item_sliders["rot.y"].value, item_sliders["rot.z"].value], "scale": item_sliders["scale"].value}
	Game.tweaks[_item_key()] = t2
	_place_item()
	_mark_sub2()

func _bone_changed() -> void:
	if bone == "":
		return
	if mode == "atp":
		_an_undo_push()
		AnimClips.set_key(_ac, bone, _an_t, [bone_sliders["x"].value, bone_sliders["y"].value, bone_sliders["z"].value])
		_an_dirty = true
		_an_play = false
		return
	_push_undo()
	var key := _pose_key()
	var d: Dictionary = Game.tweaks.get(key, {}).duplicate()
	var v := [bone_sliders["x"].value, bone_sliders["y"].value, bone_sliders["z"].value]
	if v == [0.0, 0.0, 0.0]:
		d.erase(bone)
	else:
		d[bone] = v
	if d.is_empty():
		Game.tweaks.erase(key)
	else:
		Game.tweaks[key] = d

func _sync_sliders() -> void:
	if mode in ["atp", "afp"]:
		_an_sync_sliders()
		return
	_syncing = true
	if not item_sliders.is_empty():
		var t2: Dictionary = Game.tweaks.get(_item_key(), {})
		if mode == "agun" and t2.is_empty() and not _per_clip:
			t2 = Game.tweaks.get("agun/%s/%s" % [AlienScript.anchor_model(subject, _ag_w), _ag_w], {})
		var p: Array = t2.get("pos", [0, 0, 0])
		var r: Array = t2.get("rot", [0, 0, 0])
		item_sliders["pos.x"].value = p[0]; item_sliders["pos.y"].value = p[1]; item_sliders["pos.z"].value = p[2]
		item_sliders["rot.x"].value = r[0]; item_sliders["rot.y"].value = r[1]; item_sliders["rot.z"].value = r[2]
		item_sliders["scale"].value = t2.get("scale", 1.0)
	if not bone_sliders.is_empty():
		var b: Array = Game.tweaks.get(_pose_key(), {}).get(bone, [0, 0, 0])
		bone_sliders["x"].value = b[0]; bone_sliders["y"].value = b[1]; bone_sliders["z"].value = b[2]
	if not grip_sliders.is_empty() and item_node:
		var g := ArmIK.grips(subject, item_node)
		var v: Vector3 = g.get("l", Vector3.ZERO)
		grip_sliders["x"].value = v.x; grip_sliders["y"].value = v.y; grip_sliders["z"].value = v.z
	_syncing = false

func _reset_current() -> void:
	if mode in ["fp", "tp", "back", "agun"]:
		Game.tweaks.erase(_item_key())
		_mark_sub2()
	if mode in ["tp", "emote", "alien"]:
		Game.tweaks.erase(_pose_key())
	if mode == "tp":
		Game.tweaks.erase("grip/" + subject)
	_sync_sliders()
	_build_scene()
	status.text = "Vynulováno (ulož, ať to platí i v souboru)."

# ---- the 3D scene -----------------------------------------------------------------------------------
func _build_scene() -> void:
	if model:
		model.queue_free()
	model = null
	item_node = null
	holder = null
	sk = null
	anim = null
	(world.get_node("Floor") as Node3D).visible = not mode in ["fp", "afp"]
	_an_hand = null
	match mode:
		"fp", "afp":
			# exactly what the eyes see: camera at the origin, the hand(s) where the game puts them
			model = Node3D.new()
			world.add_child(model)
			cam.transform = Transform3D()
			cam.fov = Game.fov
			holder = Node3D.new()
			model.add_child(holder)
			var shield: bool = Game.ITEMS.get(subject, {}).get("type", "") == "shield"
			holder.position = PlayerScript.VM_ONE_L if shield else PlayerScript.VM_R.get(subject, PlayerScript.VM_ONE_R)
			if Game.two_handed(subject):
				var hb := Game.model("hands_" + subject)
				hb.name = "GripTwo"
				holder.add_child(hb)
				if mode == "afp":
					var h1 := Game.model("hand_r")
					h1.name = "GripOne"
					h1.visible = false
					holder.add_child(h1)
			else:
				holder.add_child(Game.model("hand_l" if shield else "hand_r"))
			if mode == "afp":
				_an_hand = Game.model("hand_l")
				model.add_child(_an_hand)
				_an_hand.visible = false
		"tp", "back", "emote", "atp":
			model = Game.model("merc")
			model.scale = Vector3(-1, 1, 1)     # as in the game: the gun hand is the right one
			world.add_child(model)
			Game.apply_look(model, Game.merc.get("look", {}))
			for gname in ["Gear_Scanner", "Gear_Plate", "Gear_Grenade", "Gear_Flare"]:
				var gn := model.find_child(gname, true, false)
				if gn:
					gn.visible = false     # the old hand-held scanner and spare kit: not on show here
			_setup_rig()
			if mode in ["tp", "back"] or (mode == "atp" and Game.ITEMS.has(subject)):
				holder = Node3D.new()
				var att := BoneAttachment3D.new()
				att.bone_name = "spine"
				sk.add_child(att)
				att.add_child(holder)
				var rest := sk.get_bone_global_rest(sk.find_bone("spine"))
				if mode in ["tp", "atp"]:
					holder.transform = rest.affine_inverse() * Transform3D(Basis(), Vector3(-0.1, 1.2, -0.3))
					_holder_base = holder.transform
				else:
					holder.transform = rest.affine_inverse() * Transform3D(Basis.from_euler(Vector3(-PI / 2 + 0.3, 0, 0.6)), Vector3(0.0, 1.2, 0.2))
			target = Vector3(0, 1.25 if mode != "back" else 1.2, 0)
			dist = 2.0 if mode == "tp" else 2.2
			yaw = PI + 0.6 if mode != "back" else 0.4
		"alien":
			model = Game.model(String(AlienScript.RACES[subject]["model"]))
			world.add_child(model)
			_setup_rig()
			target = Vector3(0, float(AlienScript.RACES[subject]["h"]) * 0.55, 0)
			dist = float(AlienScript.RACES[subject]["h"]) * 1.7 + 0.8
			yaw = PI + 0.7
		"agun":
			_ag_native = ag_afk(subject, _ag_race)
			model = AlienScript.afk_scene(_ag_race) if _ag_native else null
			if model == null:
				_ag_native = false
				model = ag_model(subject)
			world.add_child(model)
			if AlienScript.RACES[_ag_race].has("scale"):
				model.scale *= float(AlienScript.RACES[_ag_race]["scale"])
			_setup_rig()
			var h := float(AlienScript.RACES[_ag_race]["h"])
			if _ag_native:
				h = maxf(h, _ag_height(model))       # (the Levit's afk body hangs far below its old hover height)
			target = Vector3(0, h * 0.6, 0)
			dist = h * 1.3 + 0.6
			yaw = PI + 0.9
			var hn := "hand_r" if _ag_native else "hand.R"
			var hb := sk.find_bone(hn) if sk else -1
			if hb >= 0:
				var att := BoneAttachment3D.new()
				att.bone_name = hn
				sk.add_child(att)
				holder = Node3D.new()
				att.add_child(holder)
				holder.transform = AlienScript.GUN_DEFAULT
				target = (sk.global_transform * sk.get_bone_global_rest(hb)).origin.lerp(target, 0.5)
			_ag_play()
			if sk == null or hb < 0:
				status.text = "Tenhle model nemá kostru s kostí hand.R – zbraň nemá kam dát. Model potřebuje kosti pojmenované jako ve hře (soubor *_rig.glb)."
			elif anim == null:
				status.text = "Model nemá pohyby (stojí v T-pozici). Kotvu jde naladit i tak; pohyby přibudou s afk."
			else:
				status.text = ""
	_place_item()
	_fill_bones()
	_an_fill_objects()
	_sync_sliders()

## Zbraň vetřelce: every model that carries a gun - the game's and the new ones from Ari's folder.
## [key (the model's name), label, race].
static func ag_models() -> Array:
	var out := []
	var seen := {}
	for r in Campaign.RACE_WEAPON:
		if not AlienScript.RACES.has(r):
			continue
		var m := String(AlienScript.RACES[r]["model"])
		var nm := String(AlienScript.RACES[r]["name"])
		if not seen.has(m) and ag_afk(m, r):
			out.append([m, nm + " (afk)", r])      # the game shows Ari's afk model: the anchor is for it
			seen[m] = true
		elif not seen.has(m) and ResourceLoader.exists("res://assets/models/%s.glb" % m):
			out.append([m, nm + (" (zbraň v modelu)" if m in AlienScript.BAKED_GUN else ""), r])
			seen[m] = true
		var v := m + "_v2"
		if not seen.has(v) and (ResourceLoader.exists("res://assets/models/%s.glb" % v) or ag_file(v) != ""):
			out.append([v, nm + " – nový model", r])
			seen[v] = true
	return out

## The race's own model is Ari's afk one in the game (alien._afk_model): show that one.
static func ag_afk(key: String, race_id: String) -> bool:
	return AlienScript.RACES.has(race_id) and String(AlienScript.RACES[race_id]["model"]) == key \
		and AlienScript.AFK_MODELS.has(race_id) and ResourceLoader.exists("res://animace/afk_%s.glb" % race_id)

## The new model's file in Ari's folder (the rigged one first), "" when there is none.
static func ag_file(key: String) -> String:
	if not OS.has_feature("editor"):
		return ""
	var dir := ProjectSettings.globalize_path(AG_DIR)
	for f in [key + "_rig.glb", key + ".glb"]:
		if FileAccess.file_exists(dir.path_join(f)):
			return dir.path_join(f)
	return ""

static var _ag_cache := {}
## The model: from the game when it is there, else read from the .glb file (no import needed:
## the folder is hidden from Godot), with the game's own materials.
static func ag_model(key: String) -> Node3D:
	if ResourceLoader.exists("res://assets/models/%s.glb" % key):
		return Game.model(key)
	var path := ag_file(key)
	if path != "":
		if not _ag_cache.has(path):
			var doc := GLTFDocument.new()
			var st := GLTFState.new()
			var ps: PackedScene = null
			if doc.append_from_file(path, st) == OK:
				var n := doc.generate_scene(st)
				if n:
					for c in n.find_children("*", "", true, false):
						c.owner = n
					ps = PackedScene.new()
					ps.pack(n)
					n.free()
			_ag_cache[path] = ps
		if _ag_cache[path] != null:
			var inst: Node3D = (_ag_cache[path] as PackedScene).instantiate()
			Game._restyle(inst)
			return inst
	return Game.model(key)      # (a grey box: nothing to read)

## The model's height from its meshes (rest pose).
static func _ag_height(m: Node3D) -> float:
	var top := 0.0
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var bb: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		top = maxf(top, bb.end.y)
	return top

var _ag_native := false       # the afk model: the holder follows the hands (alien.afk_hold_xform)

func _ag_fill_weapons() -> void:
	if _ag_w_opt == null:
		return
	_ag_w_opt.clear()
	var own := String(Campaign.RACE_WEAPON.get(_ag_race, ""))
	var ws: Array = [own] if own != "" else []
	for w in AG_WEAPONS:
		if not w in ws:
			ws.append(w)
	for w in ws:
		if Game.ITEMS.has(w) and ResourceLoader.exists("res://assets/models/%s.glb" % w):
			_ag_w_opt.add_item(String(Game.ITEMS[w]["name"]) + (" (jeho)" if w == own else ""))
			_ag_w_opt.set_item_metadata(_ag_w_opt.item_count - 1, w)
	_ag_w = String(_ag_w_opt.get_item_metadata(0)) if _ag_w_opt.item_count > 0 else ""

## The chosen movement on the alien (what alien._animate plays under that name).
func _ag_play() -> void:
	if anim == null:
		return
	var c := sub2 if anim.has_animation(sub2) else "idle"
	if anim.has_animation(c):
		anim.get_animation(c).loop_mode = Animation.LOOP_LINEAR
		anim.play(c)

func _setup_rig() -> void:
	sk = model.find_child("Skeleton3D", true, false)
	anim = model.find_child("AnimationPlayer", true, false)
	if anim:
		anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		if anim.has_animation("idle"):
			anim.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
			anim.play("idle")

func _place_item() -> void:
	if holder == null:
		return
	if item_node:
		item_node.queue_free()
	if mode == "back":
		item_node = Game.model(subject)
		Game.apply_item_tweak(item_node, "back/" + subject)
	elif mode == "agun":
		if _ag_w == "":
			return
		item_node = Game.model(_ag_w)
		item_node.transform = AlienScript.gun_anchor(subject, _ag_w, sub2)
	else:
		if not Game.ITEMS.has(subject):
			return
		item_node = Game.held_model(subject, mode in ["tp", "atp"])
	holder.add_child(item_node)

func _fill_bones() -> void:
	if bone_opt == null:
		return
	bone_opt.clear()
	if sk == null:
		return
	var names := []
	for i in sk.get_bone_count():
		var n := sk.get_bone_name(i)
		if n != "root":
			names.append(n)
	for n in names:
		bone_opt.add_item(_bone_cz(n))
		bone_opt.set_item_metadata(bone_opt.item_count - 1, n)
	var pref := "upperarm.R" if mode != "alien" else "spine"
	var idx := names.find(pref)
	bone_opt.select(maxi(idx, 0))
	bone = names[maxi(idx, 0)] if names.size() > 0 else ""

static func _bone_cz(n: String) -> String:
	var side := ""
	if n.ends_with(".L"): side = " L"
	elif n.ends_with(".R"): side = " P"
	var base := n.trim_suffix(".L").trim_suffix(".R")
	if base.begins_with("tail."):
		return "ocas " + base.substr(5)
	return {"hips": "boky", "spine": "páteř", "neck": "krk", "head": "hlava", "upperarm": "rameno", "forearm": "předloktí",
		"hand": "ruka", "thigh": "stehno", "shin": "lýtko", "jaw": "čelist", "tail": "ocas"}.get(base, base) + side

func _process(delta: float) -> void:
	Game.sharp_view(svc)
	if not _paused:
		t += delta
	if anim:
		anim.advance(0.0 if _paused else delta)
	if sk:
		var want := {}
		var drop := 0.0
		match mode:
			"atp":
				want = _an_base_pose()
				want.merge(AnimClips.pose(_ac, _an_t), true)
			"tp":
				_tp_tick()
			"back":
				want = PlayerScript.hold_want("", "", 0, 0.0)
			"emote":
				var base: Dictionary = {"salute": PlayerScript.POSE_SALUTE, "atease": PlayerScript.POSE_ATEASE, "hips": PlayerScript.POSE_HIPS}[subject]
				want = Game.tweak_pose("emote/" + subject, base)
			"agun":
				if item_node and is_instance_valid(item_node):
					item_node.transform = AlienScript.gun_anchor(subject, _ag_w, sub2)     # (as alien._gun_tick)
				if _ag_native and holder and is_instance_valid(holder):
					holder.global_transform = AlienScript.afk_hold_xform(sk, _ag_race, model.global_transform.basis, model.global_transform.basis.get_scale())
			"alien":
				var pose: Array = AlienScript.pose_for(sub2, t, float(AlienScript.RACES[subject]["h"]))
				want = Game.tweak_pose("act/" + sub2, pose[0])
				drop = float(pose[1])
		for bn in want:
			var i := sk.find_bone(bn)
			if i >= 0:
				var rest: Quaternion = sk.get_bone_rest(i).basis.get_rotation_quaternion()
				sk.set_bone_pose_rotation(i, rest * Quaternion.from_euler(want[bn]))
		var ri := sk.find_bone("root")
		if ri >= 0 and drop != 0.0:
			sk.set_bone_pose_position(ri, sk.get_bone_rest(ri).origin + Vector3(0, drop, 0))
		if mode == "tp":
			_grip_marker(Vector3.INF)
		elif mode in ["tp", "atp"] and holder and item_node:
			# exactly as in the game: the gun sits in the right hand, the left hand takes hold of it
			var hi := sk.find_bone("hand.R")
			if hi >= 0:
				var hand := sk.global_transform * sk.get_bone_global_pose(hi)
				holder.global_position = hand.origin + hand.basis.y.normalized() * -0.05
			var g := ArmIK.grips(subject, item_node) if Game.ITEMS.get(subject, {}).get("type", "") == "weapon" else {}
			if g.has("l") and (sub2 == "" or (mode == "atp" and sub2 == "hold" and not AnimClips.has_track(_ac, "upperarm.L"))) and _grip_on:
				var wg: Vector3 = holder.global_transform * item_node.transform * g["l"]
				var ie := sk.find_bone("forearm.L")
				ArmIK.solve(sk, "L", wg, sk.global_transform * sk.get_bone_global_pose(ie).origin + Vector3.DOWN * 0.3)
				_ik_err = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("hand.L")).origin).distance_to(wg)
				if Game.autotest() == "workshop" and Engine.get_process_frames() % 30 == 0:
					var sh := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("upperarm.L")).origin
					var hr := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("hand.R")).origin
					print("[IK] shoulder->grip %.2f  handR->grip %.2f grip=%s box=%s" % [sh.distance_to(wg), hr.distance_to(wg), g["l"], ArmIK._boxes.get(subject)])
				_grip_marker(wg)
			else:
				_grip_marker(Vector3.INF)
		else:
			_grip_marker(Vector3.INF)
		_highlight_bone()
	if mode in ["atp", "afp"]:
		_anim_tick(delta)
	_joint_dots()
	_draw_giz()
	_show_hint()
	if not mode in ["fp", "afp"]:
		var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
		cam.position = target + dir * dist
		cam.look_at(target, Vector3.UP)
		cam.fov = 50.0

## The game's movement for the chosen act: a body one, or the hands' one (stand under it).
func _tp_clip(a: String) -> Dictionary:
	if a.begins_with("tp_body_"):
		if subject in PlayerScript.HEAVY and not AnimClips.get_clip(a + "_heavy").is_empty():
			return AnimClips.get_clip(a + "_heavy")
		if not _long_gun() and not AnimClips.get_clip(a + "_pistol").is_empty():
			return AnimClips.get_clip(a + "_pistol")
		return AnimClips.get_clip(a)
	if a == "draw" and not _long_gun():
		return AnimClips.find("tp", "drawp", subject)
	return AnimClips.find("tp", a, subject)

func _apply_clip(c: Dictionary, at: float) -> void:
	if c.is_empty():
		return
	var tt := AnimClips.clip_time(c, at)
	var p := AnimClips.pose(c, tt)
	for bn in p:
		var i := sk.find_bone(bn)
		if i >= 0:
			sk.set_bone_pose_rotation(i, sk.get_bone_rest(i).basis.get_rotation_quaternion() * Quaternion.from_euler(p[bn]))
	var ri := sk.find_bone("root")
	if ri >= 0:
		var v := AnimClips.sample(c, "root@pos", tt) if AnimClips.has_track(c, "root@pos") else [0, 0, 0]
		sk.set_bone_pose_position(ri, sk.get_bone_rest(ri).origin + Vector3(float(v[0]), float(v[1]), float(v[2])))

var _holder_base := Transform3D()
var _per_clip := false        # tp, long gun: the sliders set it for the chosen movement only
var _ws_cal := Basis()
var _ws_grip_basis := Basis()
var _ws_has_cal := false
## The soldier as the game shows him (Předmět v ruce - zvenku): the afk movement, the gun put in the
## hands exactly as player.gd does it (a long gun from the right hand to the left; during an action
## it stays as it sat in the hand while standing).
func _tp_tick() -> void:
	var a := sub2 if sub2 != "" else "tp_body_idle"
	var body := a.begins_with("tp_body_")
	var idle := _tp_clip("tp_body_idle")
	var hi := sk.find_bone("hand.R")
	var li := sk.find_bone("hand.L")
	if holder == null or item_node == null or hi < 0:
		_apply_clip(_tp_clip(a) if body else idle, t)
		return
	if not _long_gun():
		_apply_clip(idle if not body else _tp_clip(a), t)
		if not body:
			_apply_clip(_tp_clip(a), t)
		var hand := sk.global_transform * sk.get_bone_global_pose(hi)
		holder.transform = _holder_base
		holder.global_position = hand.origin + hand.basis.y.normalized() * -0.05
		if body:
			# a handgun: its correction for this movement, in the gun's frame (as player._mixamo_gun)
			var adj := Game.tweak_xform("tpa/%s@%s" % [subject, a])
			if adj != Transform3D():
				holder.transform = holder.transform * adj
		return
	# the long gun: calm standing first (its roll in the wrist, and how it sits in the hand)
	_apply_clip(idle, 0.0)
	var g0 := _ws_gun(true, "tp_body_idle")
	var h0 := sk.global_transform * sk.get_bone_global_pose(hi)
	var rel := h0.affine_inverse() * g0
	if body:
		_apply_clip(_tp_clip(a), t)
		holder.global_transform = _ws_gun(a.begins_with("tp_body_idle") or a == "tp_body_crouch", a)
	else:
		_apply_clip(idle, t)
		_apply_clip(_tp_clip(a), t)
		holder.global_transform = sk.global_transform * sk.get_bone_global_pose(hi) * rel

## The gun's holder (world) for the pose the skeleton has now - player._mixamo_gun.
func _ws_gun(calm: bool, clip: String) -> Transform3D:
	var hand := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("hand.R"))
	var origin := hand.origin + hand.basis.y.normalized() * -0.05
	var lh := (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("hand.L"))).origin
	var dir := (lh - origin).normalized()
	var hb := hand.basis.orthonormalized()
	var up := Vector3.UP
	if not calm and _ws_has_cal:
		up = (hb * _ws_cal).y.normalized()
	if absf(dir.dot(up)) > 0.97:
		up = Vector3.UP if absf(dir.y) < 0.9 else Vector3.BACK
	var B := Basis.looking_at(dir, up)
	_ws_grip_basis = B
	if calm:
		_ws_cal = hb.inverse() * B
		_ws_has_cal = true
	return PlayerScript.afk_gun_xform(B, origin, item_node, Vector3.ONE, subject, clip)

var _gm: MeshInstance3D
var _ik_err := -1.0
func _grip_marker(at: Vector3) -> void:
	if _gm == null:
		_gm = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.018
		sm.height = 0.036
		_gm.mesh = sm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.55, 0.1)
		m.no_depth_test = true
		_gm.material_override = m
		world.add_child(_gm)
	_gm.visible = at != Vector3.INF
	if _gm.visible:
		_gm.global_position = at

## A small glowing marker on the chosen bone, so you see what you are turning.
var _marker: MeshInstance3D
func _highlight_bone() -> void:
	if _marker == null:
		_marker = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.025
		sm.height = 0.05
		_marker.mesh = sm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = UiSkin.GLOW
		m.no_depth_test = true
		_marker.material_override = m
		world.add_child(_marker)
	var i := sk.find_bone(bone) if bone != "" else -1
	_marker.visible = i >= 0
	if i >= 0:
		_marker.global_position = sk.global_transform * sk.get_bone_global_pose(i).origin

func _view_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion and _drag_k < 0 and not dragging:
		_hover_k = _handle_at(ev.position)[0]
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			var h: Array = _handle_at(ev.position)
			if h[0] >= 0:
				_drag_k = h[0]
				_drag_tan = h[1]
				_push_undo()
				_undo_t = 0.0
				return
			if mode != "fp" and _pick_bone(ev.position):
				focus = "bone"
				return
			if mode == "afp":
				var o := _an_pick_fp(ev.position)
				if o != "":
					_an_select(o)
					focus = "item"
					return
			elif _pick_item(ev.position):
				focus = "item"
				return
		elif _drag_k >= 0:
			_drag_k = -1
			return
	if ev is InputEventMouseMotion and _drag_k >= 0:
		_drag_handle(ev.relative)
		return
	if mode in ["fp", "afp"]:
		return
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			dist = maxf(0.4, dist * 0.9)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dist = minf(8.0, dist * 1.1)
		elif ev.button_index == MOUSE_BUTTON_RIGHT:
			dragging = ev.pressed           # right button: turn the view
			_bone_drag = false
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				dragging = true          # (not on a joint or the item: turn the view)
				_bone_drag = false
			else:
				dragging = false
				_bone_drag = false
	elif ev is InputEventMouseMotion and dragging:
		if _bone_drag and not bone_sliders.is_empty():
			# drag the joint: up/down bends it forward/back, left/right turns it (Shift: sideways)
			if ev.shift_pressed:
				bone_sliders["z"].value = clampf(bone_sliders["z"].value - ev.relative.x * 0.6, -180, 180)
			else:
				bone_sliders["y"].value = clampf(bone_sliders["y"].value + ev.relative.x * 0.6, -180, 180)
				bone_sliders["x"].value = clampf(bone_sliders["x"].value + ev.relative.y * 0.6, -180, 180)
		else:
			yaw -= ev.relative.x * 0.01
			pitch = clampf(pitch + ev.relative.y * 0.01, -1.3, 1.3)

## Click near a joint in the picture: that bone is selected.
func _pick_bone(at: Vector2) -> bool:
	if sk == null or bone_opt == null:
		return false
	# (the view renders at the screen's real resolution: the click is in the same pixels)
	var scale := Vector2(view.size) / svc.size
	var p := at * scale
	var best := -1
	var bd := 7.0 * Vector2(view.size).x / 378.0
	for i in bone_opt.item_count:
		var bi := sk.find_bone(String(bone_opt.get_item_metadata(i)))
		if bi < 0:
			continue
		var w := sk.global_transform * sk.get_bone_global_pose(bi).origin
		if cam.is_position_behind(w):
			continue
		var d := cam.unproject_position(w).distance_to(p)
		if d < bd:
			bd = d
			best = i
	if best >= 0:
		bone_opt.select(best)
		bone = String(bone_opt.get_item_metadata(best))
		_sync_sliders()
		dragging = true
		_bone_drag = true        # keep the button down and drag: the joint turns
		return true
	return false


# ---- handles ---------------------------------------------------------------------------------------
## Where the handles are and which way they point: [centre, [axis0, axis1, axis2], kind]
## kind "rings" (turning) or "arrows" (moving); empty when there is nothing to hold.
func _handles() -> Array:
	if focus == "bone" and sk != null and bone != "" and not bone_sliders.is_empty():
		var i := sk.find_bone(bone)
		if i < 0:
			return []
		var g := sk.global_transform * sk.get_bone_global_pose(i)
		return [g.origin, [g.basis.x.normalized(), g.basis.y.normalized(), g.basis.z.normalized()], "rings", signf(g.basis.determinant())]
	if focus == "item" and mode == "afp":
		var sn := _an_sel_node()
		if sn == null:
			return []
		var fb: Basis = (sn.get_parent() as Node3D).global_transform.basis if _an_sel != "ruka" and _an_sel != "zbran" else Basis.IDENTITY
		return [sn.global_position, [fb.x.normalized(), fb.y.normalized(), fb.z.normalized()], "arrows" if _item_tool == "posun" else "rings", signf(fb.determinant()), [fb.x, fb.y, fb.z]]
	if focus == "item" and item_node != null and is_instance_valid(item_node) and not item_sliders.is_empty():
		var hb := holder.global_transform.basis
		if mode == "tp" and _long_gun() and not (_per_clip and false):
			hb = _ws_grip_basis          # "tpa/": the sliders move it in the grip's frame
		var ax := [hb.x, hb.y, hb.z]
		var axn := [hb.x.normalized(), hb.y.normalized(), hb.z.normalized()]
		return [item_node.global_position, axn, "arrows" if _item_tool == "posun" else "rings", signf(hb.determinant()), ax]
	return []

func _gsize() -> float:
	if mode in ["fp", "afp"]:
		return 0.06
	return dist * 0.12

## Points along a ring (world), for drawing and for hitting it with the mouse.
func _ring_pts(c: Vector3, ax: Vector3, r: float, n := 40) -> Array:
	var u := ax.cross(Vector3.UP if absf(ax.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := ax.cross(u).normalized()
	var out := []
	for i in n + 1:
		var a := TAU * i / n
		out.append(c + (u * cos(a) + v * sin(a)) * r)
	return out

func _scr(w: Vector3) -> Vector2:
	return cam.unproject_position(w) / (Vector2(view.size) / svc.size)

## The handle under the mouse: [index 0-2 or -1, screen direction the value grows along].
func _handle_at(at: Vector2) -> Array:
	var h := _handles()
	if h.is_empty():
		return [-1, Vector2.ZERO]
	var c: Vector3 = h[0]
	if cam.is_position_behind(c):
		return [-1, Vector2.ZERO]
	var best := -1
	var bd := 6.0
	var tan := Vector2.ZERO
	var L := _gsize()
	for k in 3:
		var ax: Vector3 = h[1][k]
		if h[2] == "arrows":
			var a := _scr(c)
			var b := _scr(c + ax * L * 1.4)
			var d := Geometry2D.get_closest_point_to_segment(at, a, b).distance_to(at)
			if d < bd and at.distance_to(a) > 3.0:
				bd = d
				best = k
				tan = (b - a).normalized() * (L * 1.4 / maxf(1.0, (b - a).length()))
		else:
			var pts := _ring_pts(c, ax, L * (1.0 + 0.12 * k))
			for i in pts.size() - 1:
				var a2 := _scr(pts[i])
				var b2 := _scr(pts[i + 1])
				var d2 := Geometry2D.get_closest_point_to_segment(at, a2, b2).distance_to(at)
				if d2 < bd:
					bd = d2
					best = k
					tan = (b2 - a2).normalized()
	return [best, tan]

## Dragging a handle: a ring turns (degrees), an arrow moves (metres in the item's frame).
func _drag_handle(rel: Vector2) -> void:
	var h := _handles()
	if h.is_empty():
		return
	var along := rel.dot(_drag_tan.normalized()) if h[2] == "rings" else rel.dot(_drag_tan.normalized()) * _drag_tan.length()
	var k := _drag_k
	if h[2] == "rings":
		var deg := along * 0.7 * float(h[3])
		if focus == "bone":
			var s: HSlider = bone_sliders[["x", "y", "z"][k]]
			s.value = clampf(s.value + deg, -180, 180)
		else:
			var s2: HSlider = item_sliders[["rot.x", "rot.y", "rot.z"][k]]
			s2.value = wrapf(s2.value + deg, -180, 180)
	else:
		var axlen: float = (h[4][k] as Vector3).length()
		var s3: HSlider = item_sliders[["pos.x", "pos.y", "pos.z"][k]]
		s3.value = clampf(s3.value + along / maxf(0.001, axlen), s3.min_value, s3.max_value)

## Click on the item (gun, radio...) in the picture.
func _pick_item(at: Vector2) -> bool:
	if item_node == null or not is_instance_valid(item_node) or item_sliders.is_empty():
		return false
	var p := at * (Vector2(view.size) / svc.size)
	var o := cam.project_ray_origin(p)
	var d := cam.project_ray_normal(p)
	for mi in item_node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var inv := m.global_transform.affine_inverse()
		var lo := inv * o
		var ld := (inv.basis * d).normalized()
		if m.get_aabb().grow(0.01).intersects_ray(lo, ld) != null:
			return true
	return false

func _draw_giz() -> void:
	var h := _handles()
	var im := ImmediateMesh.new()
	if not h.is_empty():
		var c: Vector3 = h[0]
		var L := _gsize()
		var w := L * 0.035
		var camz := cam.global_transform.basis.z
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for k in 3:
			var ax: Vector3 = h[1][k]
			var col: Color = AXIS_COL[k].lightened(0.45) if k == _hover_k or k == _drag_k else AXIS_COL[k]
			var segs := []
			if h[2] == "arrows":
				segs = [[c, c + ax * L * 1.4]]
			else:
				var pts := _ring_pts(c, ax, L * (1.0 + 0.12 * k))
				for i in pts.size() - 1:
					segs.append([pts[i], pts[i + 1]])
			for sg in segs:
				var a: Vector3 = sg[0]
				var b: Vector3 = sg[1]
				var side := (b - a).cross(camz).normalized() * w     # a flat strip facing the camera
				for v in [a - side, a + side, b + side, a - side, b + side, b - side]:
					im.surface_set_color(col)
					im.surface_add_vertex(v)
			if h[2] == "arrows":
				var tip := c + ax * L * 1.4
				var s2 := ax.cross(camz).normalized() * w * 3.0
				for v in [tip + ax * L * 0.2, tip + s2, tip - s2]:
					im.surface_set_color(col)
					im.surface_add_vertex(v)
		im.surface_end()
	_giz.mesh = im

## Every joint you can take hold of: a small grey dot (the chosen one is the bigger blue one).
func _joint_dots() -> void:
	var want := {}
	if sk != null and bone_opt != null and not mode in ["fp", "afp"]:
		for i in bone_opt.item_count:
			var bn := String(bone_opt.get_item_metadata(i))
			var bi := sk.find_bone(bn)
			if bi >= 0 and bn != bone:
				want[bn] = sk.global_transform * sk.get_bone_global_pose(bi).origin
	for bn in _dots.keys():
		if not want.has(bn):
			_dots[bn].queue_free()
			_dots.erase(bn)
	for bn in want:
		if not _dots.has(bn):
			var d := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.014
			sm.height = 0.028
			d.mesh = sm
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(0.85, 0.88, 0.9, 0.85)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.no_depth_test = true
			m.render_priority = 5
			d.material_override = m
			world.add_child(d)
			_dots[bn] = d
		_dots[bn].global_position = want[bn]
		_dots[bn].scale = Vector3.ONE * (dist / 2.0)

func _show_hint() -> void:
	if _hint == null:
		return
	var t2 := ""
	if mode in ["atp", "afp"]:
		_hint.text = "ANIMACE: klik do osy = čas · táhni kruh/šipku = klíč se zapíše sám · K klíč · Shift+K všem · Del smazat · Mezerník přehrát · ←→ snímek · Ctrl+S uložit · Ctrl+Z zpět"
		return
	if focus == "bone" and bone != "" and not bone_sliders.is_empty():
		t2 = "KLOUB %s: táhni kruh (červený předklon, zelený otočení, modrý do strany). " % _bone_cz(bone)
	elif focus == "item" and not item_sliders.is_empty():
		t2 = "PŘEDMĚT: " + ("táhni šipky (R = otáčení kruhy). " if _item_tool == "posun" else "táhni kruhy (G = posun šipkami). ")
	else:
		t2 = "Klikni na kloub (tečky) nebo na předmět. "
	_hint.text = t2 + "Tab kloub/předmět · Mezerník stop · Ctrl+Z zpět · Ctrl+S uložit · pravé tl. pohled"

# ==== ANIMACE: keyframes on a time line (after the Svitky editor) =====================================
## Pick the action and the item, set the time, turn the joints (or move the gun / the hand in the
## eyes view) - a key is written by itself. Space plays it. The game uses it at once
## (scripts/anim_clips.gd, files in res://animace).
const AN_SOUNDS := ["mag_out", "mag_in", "pistol_slide", "revolver_open", "revolver_close", "shell_insert", "shotgun_pump",
	"sniper_bolt", "reload", "casings", "clink", "knife_stab", "bandage", "backpack_zip", "backpack_rummage", "gear_0"]
const AN_CARRY := ["", "pistol_mag", "rifle_clip", "shell", "round", "magnum_rounds", "bandage", "medkit", "grenade", "flare"]
const TL_HEAD := 11.0
const TL_ROW := 15.0
const TL_LABEL := 70.0

class Timeline extends Control:
	var ed
	func _draw() -> void:
		ed._tl_draw(self)
	func _gui_input(e: InputEvent) -> void:
		ed._tl_input(self, e)

var _frame: PanelContainer
var _vholder: Control
var _ac: Dictionary = {}
var _clip_id := ""
var _an_t := 0.0
var _an_t_shown := -1.0
var _an_play := false
var _an_dirty := false
var _an_sel := "zbran"            # afp: zbran, ruka or a part (Mag, Slide, Barrel...)
var _an_hand: Node3D
var _an_carry := "-"
var _an_tl: Timeline
var _an_len: SpinBox
var _an_loop: CheckBox
var _an_time_lbl: Label
var _an_info: Label
var _an_obj_opt: OptionButton
var _an_ev_opt: OptionButton
var _an_pre_opt: OptionButton
var _an_undo: Array = []
var _an_redo: Array = []
var _an_undo_t := 0.0
var _an_key_row := ""
var _an_key_t := -1.0
var _tl_drag := ""
var _tl_moved := false
var _an_clipboard := {}
var _an_rests := {}

func _anim_layout() -> void:
	var on := mode in ["atp", "afp"]
	if _an_tl == null:
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", UiSkin.inset(2))
		pc.position = Vector2(6, 258)
		pc.size = Vector2(384, 76)
		pc.name = "TimelineBox"
		add_child(pc)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 1)
		pc.add_child(vb)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 3)
		vb.add_child(hb)
		_btn(hb, "|<", func(): _an_t = 0.0; _an_play = false)
		_btn(hb, "Přehrát", func(): _an_play = not _an_play)
		_an_time_lbl = Label.new()
		_an_time_lbl.add_theme_font_size_override("font_size", 8)
		_an_time_lbl.add_theme_color_override("font_color", UiSkin.AMBER)
		hb.add_child(_an_time_lbl)
		_an_tl = Timeline.new()
		_an_tl.ed = self
		_an_tl.custom_minimum_size = Vector2(376, TL_HEAD + TL_ROW * 3 + 2)
		_an_tl.mouse_filter = Control.MOUSE_FILTER_STOP
		vb.add_child(_an_tl)
	(get_node("TimelineBox") as Control).visible = on
	_frame.size = Vector2(384, 236 if on else 314)
	_vholder.custom_minimum_size = Vector2(378, 230 if on else 308)
	_an_play = false

func _an_druh() -> String:
	return "tp" if mode == "atp" else "fp"

func _an_id() -> String:
	return "%s_%s_%s" % [_an_druh(), sub2, subject]

func _build_anim_panel(dyn: VBoxContainer) -> void:
	# what: the action (sub2) and the item (subject)
	sub2_opt = _opt(dyn)
	var acts: Array = AnimClips.TP_ACTS if mode == "atp" else AnimClips.FP_ACTS
	for a in acts:
		sub2_opt.add_item(a[1])
		sub2_opt.set_item_metadata(sub2_opt.item_count - 1, a[0])
	sub2 = acts[0][0]
	subj_opt = _opt(dyn)
	if mode == "atp":
		subj_opt.add_item("— pro všechno —")
		subj_opt.set_item_metadata(0, "vse")
	for id in Game.ITEMS:
		if not ResourceLoader.exists("res://assets/models/%s.glb" % id) or id.begins_with("a_pack"):
			continue
		var ty: String = Game.ITEMS[id].get("type", "")
		if mode == "afp" and ty != "weapon":
			continue
		subj_opt.add_item(Game.ITEMS[id]["name"])
		subj_opt.set_item_metadata(subj_opt.item_count - 1, id)
	subject = String(subj_opt.get_item_metadata(0))
	if mode == "afp":
		for i in subj_opt.item_count:
			if String(subj_opt.get_item_metadata(i)) == "pistol":
				subj_opt.select(i)
				subject = "pistol"
	var reload_clip := func():
		_an_ask_discard(func():
			_an_load()
			_build_scene())
	sub2_opt.item_selected.connect(func(i): sub2 = String(sub2_opt.get_item_metadata(i)); reload_clip.call())
	subj_opt.item_selected.connect(func(i): subject = String(subj_opt.get_item_metadata(i)); reload_clip.call())
	_an_info = _lbl(dyn, "", UiSkin.AMBER)
	var lr := HBoxContainer.new()
	dyn.add_child(lr)
	_lbl(lr, "Délka (s):")
	_an_len = SpinBox.new()
	_an_len.min_value = 0.1
	_an_len.max_value = 10.0
	_an_len.step = 0.05
	_an_len.add_theme_font_size_override("font_size", 8)
	_an_len.get_line_edit().add_theme_font_size_override("font_size", 8)
	_an_len.value_changed.connect(func(v):
		if not _syncing:
			_an_undo_push()
			_ac["delka"] = v
			_an_t = minf(_an_t, v)
			_an_dirty = true)
	lr.add_child(_an_len)
	_an_loop = CheckBox.new()
	_an_loop.text = "Smyčka"
	_an_loop.add_theme_font_size_override("font_size", 8)
	_an_loop.focus_mode = Control.FOCUS_NONE
	_an_loop.toggled.connect(func(on):
		if not _syncing:
			_an_undo_push()
			_ac["smycka"] = on
			_an_dirty = true)
	lr.add_child(_an_loop)
	var g := GridContainer.new()
	g.columns = 2
	dyn.add_child(g)
	for b in [["Uložit anim. (Ctrl+S)", _an_save], ["Smazat animaci", _an_delete],
			["Klíč (K)", _an_key_here], ["Klíč všem (Shift+K)", _an_key_all],
			["Smazat klíč (Del)", _an_delete_key], ["Začátek → sem", _an_first_here],
			["Kopírovat pózu", _an_copy_pose], ["Vložit pózu", _an_paste_pose]]:
		var bt := _btn(g, b[0], b[1])
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if mode == "atp":
		_btn(dyn, "Zrcadlit pózu L ↔ P", _an_mirror)
	var pr := HBoxContainer.new()
	dyn.add_child(pr)
	_lbl(pr, "Přechod dál:")
	_an_pre_opt = _opt(pr)
	for k in AnimClips.PRECHODY:
		_an_pre_opt.add_item(AnimClips.PRECHODY[k])
		_an_pre_opt.set_item_metadata(_an_pre_opt.item_count - 1, k)
	_an_pre_opt.item_selected.connect(func(i): _an_set_prechod(String(_an_pre_opt.get_item_metadata(i))))
	var er := HBoxContainer.new()
	dyn.add_child(er)
	_an_ev_opt = _opt(er)
	for s in AN_SOUNDS:
		_an_ev_opt.add_item("zvuk: " + s)
		_an_ev_opt.set_item_metadata(_an_ev_opt.item_count - 1, "zvuk:" + s)
	if mode == "afp":
		for c in AN_CARRY:
			_an_ev_opt.add_item("levá drží: " + (c if c != "" else "nic"))
			_an_ev_opt.set_item_metadata(_an_ev_opt.item_count - 1, "drzi:" + c)
		for e in [["leva:volna", "levá ruka pustí zbraň"], ["leva:zbran", "levá ruka zpět na zbraň"], ["skryt:Mag", "zásobník zmizí"], ["ukazat:Mag", "zásobník zpět"], ["vyhodit:zasobnik", "zásobník vypadne"], ["vyhodit:nabojnice", "nábojnice vypadnou"]]:
			_an_ev_opt.add_item(e[1])
			_an_ev_opt.set_item_metadata(_an_ev_opt.item_count - 1, e[0])
	_an_ev_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn(er, "+ událost", _an_add_event)
	if mode == "atp":
		_lbl(dyn, "KLOUB (klíč se zapíše sám)")
		bone_opt = _opt(dyn)
		bone_opt.item_selected.connect(func(i): bone = String(bone_opt.get_item_metadata(i)); _an_sync_sliders())
		for ax in [["x", "předklon"], ["y", "otočení"], ["z", "do strany"]]:
			var a2: String = ax[0]
			bone_sliders[a2] = _slider(dyn, ax[1], -180, 180, 1, func(): _bone_changed())
	else:
		_lbl(dyn, "CO SE HÝBE (klikni na to v obrázku)")
		_an_obj_opt = _opt(dyn)
		_an_obj_opt.item_selected.connect(func(i): _an_select(String(_an_obj_opt.get_item_metadata(i))))
		for k in [["pos.x", "doprava", -0.8, 0.8, 0.002], ["pos.y", "nahoru", -0.8, 0.8, 0.002], ["pos.z", "dozadu", -0.8, 0.8, 0.002],
				["rot.x", "kývnutí", -180, 180, 1], ["rot.y", "otočení", -180, 180, 1], ["rot.z", "náklon", -180, 180, 1]]:
			var key: String = k[0]
			item_sliders[key] = _slider(dyn, k[1], k[2], k[3], k[4], func(): _item_changed())
	_lbl(dyn, "Postup: na začátku osy nastav výchozí pózu, posuň čas a nastav další - mezi klíči se pohyb dopočítá. Mezerník přehraje. Ulož Ctrl+S, hra ji hned použije.", UiSkin.DIM)
	_an_load()
	_build_scene()

## The clip of the chosen action and item: its own file, or (to start from) the one for everything.
func _an_load() -> void:
	_clip_id = _an_id()
	var own := AnimClips.get_clip(_clip_id)
	var fall := AnimClips.find(_an_druh(), sub2, subject)
	if not own.is_empty():
		_ac = own.duplicate(true)
		_an_info.text = "Vlastní animace (%s)." % _clip_id
	elif not fall.is_empty():
		_ac = fall.duplicate(true)
		_an_info.text = "Hra teď použije animaci pro všechno. Úpravou a uložením vznikne vlastní pro tenhle předmět."
	else:
		_ac = AnimClips.new_clip(_an_druh(), "%s %s" % [sub2, subject])
		_ac["delka"] = {"reload": 2.0, "reload1": 0.8, "strike": 0.5, "heal": 1.5, "dig": 1.5, "hold": 1.2, "salute": 2.4, "atease": 1.0, "hips": 1.0, "twirl": 0.9}.get(sub2, 1.0)
		_ac["smycka"] = sub2 in ["hold", "heal", "dig", "atease", "hips"]
		_an_info.text = "Zatím žádná animace - hra používá tu napsanou v kódu. Nastav pózu na začátku (K) a na konci."
	_an_t = 0.0
	_an_dirty = false
	_an_undo.clear()
	_an_redo.clear()
	_an_key_row = ""
	_an_t_shown = -1.0
	_syncing = true
	_an_len.value = float(_ac.get("delka", 1.0))
	_an_loop.button_pressed = bool(_ac.get("smycka", false))
	_syncing = false

func _an_ask_discard(cb: Callable) -> void:
	if _an_dirty:
		status.text = "Neuložené změny animace zahozeny."
	cb.call()

func _an_save() -> void:
	_ac["delka"] = _an_len.value
	_ac["smycka"] = _an_loop.button_pressed
	if AnimClips.save_clip(_clip_id, _ac):
		_an_dirty = false
		_an_info.text = "Vlastní animace (%s)." % _clip_id
		status.text = "Animace uložena: " + AnimClips.path_of(_clip_id)
		Game.play_ui(self, "ui_confirm", -6)
	else:
		status.text = "Nepodařilo se uložit animaci."

func _an_delete() -> void:
	AnimClips.delete_clip(_clip_id)
	status.text = "Animace %s smazána - hra se vrátí k té z kódu (nebo pro všechno)." % _clip_id
	_an_load()

# ---- undo ----
func _an_undo_push() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _an_undo_t > 0.6:
		_an_undo.append(_ac.duplicate(true))
		if _an_undo.size() > 80:
			_an_undo.pop_front()
		_an_redo.clear()
	_an_undo_t = now

func _an_do_undo(redo := false) -> void:
	var src: Array = _an_redo if redo else _an_undo
	var dst: Array = _an_undo if redo else _an_redo
	if src.is_empty():
		return
	dst.append(_ac.duplicate(true))
	_ac = src.pop_back()
	_an_undo_t = 0.0
	_an_dirty = true
	_an_t_shown = -1.0
	_syncing = true
	_an_len.value = float(_ac.get("delka", 1.0))
	_an_loop.button_pressed = bool(_ac.get("smycka", false))
	_syncing = false

# ---- values ----
## The pose under the clip: how the game holds the item for this action, with the Dílna tweaks.
func _an_base_pose() -> Dictionary:
	if sub2 in AnimClips.EMOTES:
		var base: Dictionary = {"salute": PlayerScript.POSE_SALUTE, "atease": PlayerScript.POSE_ATEASE, "hips": PlayerScript.POSE_HIPS}[sub2]
		return Game.tweak_pose("emote/" + sub2, base)
	var a: int = {"reload": 1, "strike": 2, "dig": 3, "heal": 4}.get(sub2, 0)
	var item := subject if Game.ITEMS.has(subject) else ""
	return Game.tweak_pose("hold/" + (item if item != "" else "nic"), PlayerScript.hold_want(item, "", a, _an_t))

func _an_bone_value(b: String) -> Vector3:
	var v := AnimClips.sample(_ac, b, _an_t)
	if v.size() >= 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	var base := _an_base_pose()
	if base.has(b):
		return (base[b] as Vector3) * (180.0 / PI)
	return Vector3.ZERO

## eyes view: a track's value now, or where the thing is when nothing is keyed.
func _an_obj_value(o: String) -> Array:
	var v := AnimClips.sample(_ac, o, _an_t)
	if v.size() >= 6:
		return v
	if o == "ruka":
		return [-0.14, -0.22, -0.34, 40.0, 0.0, 0.0]
	return [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

func _an_sync_sliders() -> void:
	_syncing = true
	if mode == "atp" and not bone_sliders.is_empty() and bone != "":
		var v := _an_bone_value(bone)
		bone_sliders["x"].value = v.x; bone_sliders["y"].value = v.y; bone_sliders["z"].value = v.z
	if mode == "afp" and not item_sliders.is_empty():
		var o := _an_obj_value(_an_sel)
		var ks := ["pos.x", "pos.y", "pos.z", "rot.x", "rot.y", "rot.z"]
		for i in 6:
			item_sliders[ks[i]].value = float(o[i])
	_syncing = false
	if _an_pre_opt:
		var tr := AnimClips.track(_ac, _an_row())
		var ki := AnimClips.key_index(tr, _an_t)
		_an_pre_opt.disabled = ki < 0
		var pre: String = String(tr[ki].get("prechod", "")) if ki >= 0 else ""
		for i in _an_pre_opt.item_count:
			if String(_an_pre_opt.get_item_metadata(i)) == pre:
				_an_pre_opt.select(i)

## The row of the time line that belongs to what is selected.
func _an_row() -> String:
	return bone if mode == "atp" else _an_sel

func _an_parts() -> Array:
	var out := []
	if item_node == null:
		return out
	for mi in item_node.find_children("*", "MeshInstance3D", true, false):
		var n := String(mi.name)
		if n.to_lower() != subject.to_lower():
			out.append(n)
	return out

func _an_sel_node() -> Node3D:
	match _an_sel:
		"zbran": return holder
		"ruka": return _an_hand
	if item_node:
		return item_node.find_child(_an_sel, true, false) as Node3D
	return null

func _an_select(o: String) -> void:
	_an_sel = o
	if _an_obj_opt:
		for i in _an_obj_opt.item_count:
			if String(_an_obj_opt.get_item_metadata(i)) == o:
				_an_obj_opt.select(i)
	_an_sync_sliders()

func _an_fill_objects() -> void:
	if _an_obj_opt == null:
		return
	_an_obj_opt.clear()
	var objs := [["zbran", "Zbraň (celá)"], ["ruka", "Levá ruka"]]
	for p2 in _an_parts():
		objs.append([p2, "Díl: " + p2])
	for o in objs:
		_an_obj_opt.add_item(o[1])
		_an_obj_opt.set_item_metadata(_an_obj_opt.item_count - 1, o[0])
	if not _an_sel in objs.map(func(e): return e[0]):
		_an_sel = "zbran"
	_an_select(_an_sel)

## Click in the eyes view: the hand, a part of the gun, or the gun.
func _an_pick_fp(at: Vector2) -> String:
	var p := at * (Vector2(view.size) / svc.size)
	var o := cam.project_ray_origin(p)
	var d := cam.project_ray_normal(p)
	var best := ""
	var bd := 1e9
	var cands := []
	if _an_hand and _an_hand.visible:
		for mi in _an_hand.find_children("*", "MeshInstance3D", true, false):
			cands.append([mi, "ruka"])
	if item_node:
		var parts := _an_parts()
		for mi in item_node.find_children("*", "MeshInstance3D", true, false):
			cands.append([mi, String(mi.name) if String(mi.name) in parts else "zbran"])
	if holder:
		for c in holder.get_children():
			if c != item_node:
				for mi in (c as Node).find_children("*", "MeshInstance3D", true, false):
					cands.append([mi, "zbran"])
	for c in cands:
		var m := c[0] as MeshInstance3D
		var inv := m.global_transform.affine_inverse()
		var hit = m.get_aabb().grow(0.005).intersects_ray(inv * o, (inv.basis * d).normalized())
		if hit != null:
			var dd: float = (m.global_transform * (hit as Vector3)).distance_to(o)
			if dd < bd:
				bd = dd
				best = c[1]
	return best

# ---- keys ----
func _an_key_here() -> void:
	_an_undo_push()
	_an_undo_t = 0.0
	if mode == "atp":
		if bone == "":
			return
		var v := _an_bone_value(bone)
		AnimClips.set_key(_ac, bone, _an_t, [snappedf(v.x, 0.1), snappedf(v.y, 0.1), snappedf(v.z, 0.1)])
	else:
		AnimClips.set_key(_ac, _an_sel, _an_t, _an_obj_value(_an_sel))
	_an_dirty = true
	_an_key_row = _an_row()
	_an_key_t = snappedf(_an_t, 0.01)
	status.text = "Klíč: %s v %.2f s." % [_an_row(), _an_t]

func _an_key_all() -> void:
	_an_undo_push()
	_an_undo_t = 0.0
	if mode == "atp":
		if sk == null:
			return
		for i in sk.get_bone_count():
			var b := sk.get_bone_name(i)
			if b == "root":
				continue
			var v := _an_bone_value(b)
			AnimClips.set_key(_ac, b, _an_t, [snappedf(v.x, 0.1), snappedf(v.y, 0.1), snappedf(v.z, 0.1)])
	else:
		for o in ["zbran", "ruka"] + _an_parts():
			if o == "ruka" and not AnimClips.has_track(_ac, "ruka"):
				continue
			AnimClips.set_key(_ac, o, _an_t, _an_obj_value(o))
	_an_dirty = true
	status.text = "Klíč všemu v %.2f s." % _an_t

func _an_delete_key() -> void:
	var row := _an_key_row if _an_key_row != "" else _an_row()
	var t2 := _an_key_t if _an_key_row != "" else _an_t
	_an_undo_push()
	_an_undo_t = 0.0
	if row == "udalosti":
		var ev: Array = _ac.get("udalosti", [])
		for i in ev.size():
			if absf(float(ev[i]["t"]) - t2) < AnimClips.SNAP:
				ev.remove_at(i)
				break
	elif not AnimClips.delete_key(_ac, row, t2):
		status.text = "Tady není klíč."
		return
	_an_key_row = ""
	_an_dirty = true
	_an_t_shown = -1.0

func _an_first_here() -> void:
	_an_undo_push()
	_an_undo_t = 0.0
	for name in _ac.get("stopy", {}):
		var v := AnimClips.sample(_ac, name, 0.0)
		AnimClips.set_key(_ac, name, _an_t, v)
	_an_dirty = true
	status.text = "První póza zkopírována do %.2f s (smyčka se plynule vrátí)." % _an_t

func _an_copy_pose() -> void:
	_an_clipboard = {}
	for name in _ac.get("stopy", {}):
		_an_clipboard[name] = AnimClips.sample(_ac, name, _an_t)
	status.text = "Póza v %.2f s zapamatována." % _an_t

func _an_paste_pose() -> void:
	if _an_clipboard.is_empty():
		status.text = "Nejdřív zkopíruj pózu."
		return
	_an_undo_push()
	_an_undo_t = 0.0
	for name in _an_clipboard:
		AnimClips.set_key(_ac, name, _an_t, _an_clipboard[name])
	_an_dirty = true
	_an_t_shown = -1.0

func _an_mirror() -> void:
	if sk == null:
		return
	var p := {}
	for i in sk.get_bone_count():
		var b := sk.get_bone_name(i)
		if b != "root":
			var v := _an_bone_value(b)
			p[b] = [v.x, v.y, v.z]
	_an_undo_push()
	_an_undo_t = 0.0
	var m := AnimClips.mirrored(p)
	for b in m:
		AnimClips.set_key(_ac, b, _an_t, m[b])
	_an_dirty = true
	_an_t_shown = -1.0

func _an_set_prechod(k: String) -> void:
	var tr := AnimClips.track(_ac, _an_row())
	var i := AnimClips.key_index(tr, _an_t)
	if i < 0:
		return
	_an_undo_push()
	if k == "":
		(tr[i] as Dictionary).erase("prechod")
	else:
		tr[i]["prechod"] = k
	_an_dirty = true

func _an_add_event() -> void:
	_an_undo_push()
	_an_undo_t = 0.0
	if not _ac.has("udalosti"):
		_ac["udalosti"] = []
	var typ := String(_an_ev_opt.get_item_metadata(_an_ev_opt.selected))
	(_ac["udalosti"] as Array).append({"t": snappedf(_an_t, 0.01), "typ": typ})
	(_ac["udalosti"] as Array).sort_custom(func(a, b): return float(a["t"]) < float(b["t"]))
	_an_dirty = true
	status.text = "Událost „%s“ v %.2f s." % [typ, _an_t]

func _an_key(ev: InputEventKey) -> bool:
	match ev.keycode:
		KEY_SPACE: _an_play = not _an_play
		KEY_K:
			if ev.shift_pressed: _an_key_all()
			else: _an_key_here()
		KEY_DELETE: _an_delete_key()
		KEY_HOME: _an_t = 0.0; _an_play = false
		KEY_LEFT, KEY_RIGHT:
			_an_play = false
			_an_t = clampf(snappedf(_an_t, 1.0 / 30.0) + (1.0 if ev.keycode == KEY_RIGHT else -1.0) / 30.0, 0.0, float(_ac.get("delka", 1.0)))
		KEY_S when ev.ctrl_pressed: _an_save()
		KEY_Z when ev.ctrl_pressed: _an_do_undo(ev.shift_pressed)
		KEY_Y when ev.ctrl_pressed: _an_do_undo(true)
		KEY_C when ev.ctrl_pressed: _an_copy_pose()
		KEY_V when ev.ctrl_pressed: _an_paste_pose()
		_: return false
	return true

# ---- the preview ----
func _anim_tick(delta: float) -> void:
	var d := maxf(0.05, float(_ac.get("delka", 1.0)))
	var t0 := _an_t
	if _an_play:
		_an_t += delta
		if _an_t > d:
			_an_t = fmod(_an_t, d) if _ac.get("smycka", false) else 0.0
			t0 = -0.01
		for e in AnimClips.events_between(_ac, t0, _an_t):
			if String(e).begins_with("zvuk:"):
				Game.play_ui(self, String(e).substr(5), -6)
	_an_t = clampf(_an_t, 0.0, d)
	if mode == "afp":
		_an_apply_fp()
	if absf(_an_t - _an_t_shown) > 0.0001:
		_an_t_shown = _an_t
		_an_sync_sliders()
	if _an_time_lbl:
		_an_time_lbl.text = "%.2f / %.2f s%s   %s" % [_an_t, d, " *neuloženo" if _an_dirty else "", "▶" if _an_play else ""]
	if _an_tl:
		_an_tl.queue_redraw()

## The eyes view as the game will show it: the gun's offset, the hand, the parts.
func _an_apply_fp() -> void:
	if holder == null:
		return
	var base: Vector3 = PlayerScript.VM_R.get(subject, PlayerScript.VM_ONE_R)
	var gx := AnimClips.xform(_ac, "zbran", _an_t)
	holder.transform = Transform3D(gx.basis, base + gx.origin)
	if item_node:
		for p2 in _an_parts():
			var n := item_node.find_child(p2, true, false) as Node3D
			if n == null:
				continue
			if not n.has_meta("rest"):
				n.set_meta("rest", n.transform)
			var r0: Transform3D = n.get_meta("rest")
			n.transform = r0 * AnimClips.xform(_ac, p2, _an_t)
			if p2 == "Mag":
				var vis := true
				for e in _ac.get("udalosti", []):
					if float(e["t"]) <= _an_t + 0.0001:
						if String(e["typ"]) == "skryt:Mag": vis = false
						elif String(e["typ"]) == "ukazat:Mag": vis = true
				n.visible = vis
	if _an_hand:
		var on := AnimClips.hand_free(_ac, _an_t) or (_an_sel == "ruka" and not AnimClips.has_track(_ac, "ruka"))
		_an_hand.visible = on
		var g2 := holder.get_node_or_null("GripTwo")
		var g1 := holder.get_node_or_null("GripOne")
		if g2 and g1:
			g2.visible = not on
			g1.visible = on
		if on:
			var hv := _an_obj_value("ruka")
			_an_hand.transform = Transform3D(Basis.from_euler(Vector3(float(hv[3]), float(hv[4]), float(hv[5])) * (PI / 180.0)), Vector3(float(hv[0]), float(hv[1]), float(hv[2])))
		var carry := AnimClips.last_event(_ac, "drzi", _an_t)
		if carry != _an_carry:
			_an_carry = carry
			for c in _an_hand.get_children():
				if String(c.name).begins_with("Carry"):
					c.queue_free()
			var cm := PlayerScript.make_carry(carry)
			if cm:
				_an_hand.add_child(cm)

# ---- the time line ----
func _tl_rows() -> Array:
	return ["*", _an_row(), "udalosti"]

func _tl_x(c: Control, t2: float) -> float:
	return TL_LABEL + t2 / maxf(float(_ac.get("delka", 1.0)), 0.01) * (c.size.x - TL_LABEL - 6.0)

func _tl_t(c: Control, x: float) -> float:
	var d := float(_ac.get("delka", 1.0))
	return clampf((x - TL_LABEL) / maxf(c.size.x - TL_LABEL - 6.0, 1.0) * d, 0.0, d)

func _tl_keys(row: String) -> Array:
	if row == "udalosti":
		return _ac.get("udalosti", [])
	if row == "*":
		var ts := {}
		for name in _ac.get("stopy", {}):
			for k in AnimClips.track(_ac, name):
				ts[snappedf(float(k["t"]), 0.01)] = true
		return ts.keys().map(func(x): return {"t": x})
	return AnimClips.track(_ac, row)

func _tl_draw(c: Control) -> void:
	var font := c.get_theme_default_font()
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.07, 0.08, 0.09))
	var d := float(_ac.get("delka", 1.0))
	var steps := int(d / 0.1 + 0.001)
	for i in steps + 1:
		var x := _tl_x(c, i * 0.1)
		var major := i % 5 == 0
		c.draw_line(Vector2(x, TL_HEAD - (5.0 if major else 2.0)), Vector2(x, c.size.y), Color(1, 1, 1, 0.12 if major else 0.04))
		if major:
			c.draw_string(font, Vector2(x + 1, 8), "%.1f" % (i * 0.1), HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(1, 1, 1, 0.55))
	var rows := _tl_rows()
	var names := {"*": "všechny klíče", "udalosti": "události"}
	for r in rows.size():
		var row: String = rows[r]
		var y := TL_HEAD + r * TL_ROW
		if r == 1:
			c.draw_rect(Rect2(0, y, c.size.x, TL_ROW), Color(1.0, 0.8, 0.3, 0.1))
		var nm: String = names.get(row, _bone_cz(row) if mode == "atp" else row)
		c.draw_string(font, Vector2(3, y + TL_ROW - 4), nm, HORIZONTAL_ALIGNMENT_LEFT, TL_LABEL - 5, 7, UiSkin.AMBER if r == 1 else Color(1, 1, 1, 0.6))
		var cy := y + TL_ROW * 0.5
		for k in _tl_keys(row):
			var x := _tl_x(c, float(k["t"]))
			var hot := _an_key_row == row and absf(float(k["t"]) - _an_key_t) < 0.001
			if row == "udalosti":
				var col := Color(1.0, 0.95, 0.4) if hot else Color(0.45, 0.8, 1.0)
				c.draw_colored_polygon(PackedVector2Array([Vector2(x - 3, y + 2), Vector2(x + 3, y + 2), Vector2(x, y + TL_ROW - 3)]), col)
				var label := String(k["typ"]).replace("zvuk:", "♪").replace("drzi:", "✋")
				c.draw_string(font, Vector2(x + 4, y + TL_ROW - 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, col)
			else:
				var col2 := Color(1.0, 0.95, 0.4) if hot else (Color(1.0, 0.6, 0.2) if r == 1 else Color(0.8, 0.82, 0.86))
				var s := 3.5
				c.draw_colored_polygon(PackedVector2Array([Vector2(x, cy - s), Vector2(x + s, cy), Vector2(x, cy + s), Vector2(x - s, cy)]), col2)
	c.draw_line(Vector2(TL_LABEL - 2, 0), Vector2(TL_LABEL - 2, c.size.y), Color(1, 1, 1, 0.2))
	var px := _tl_x(c, _an_t)
	c.draw_line(Vector2(px, 0), Vector2(px, c.size.y), Color(1.0, 0.35, 0.3), 1.5)

func _tl_row_at(y: float) -> String:
	var i := int(floor((y - TL_HEAD) / TL_ROW))
	var rows := _tl_rows()
	return rows[i] if y >= TL_HEAD and i >= 0 and i < rows.size() else ""

func _tl_key_at(c: Control, row: String, x: float) -> float:
	if row == "" or row == "*":
		return -1.0
	var best := -1.0
	var bd := 5.0
	for k in _tl_keys(row):
		var dd := absf(_tl_x(c, float(k["t"])) - x)
		if dd < bd:
			bd = dd
			best = float(k["t"])
	return best

func _tl_input(c: Control, e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if not mb.pressed:
			_tl_drag = ""
			return
		var row := _tl_row_at(mb.position.y)
		var t2 := _tl_t(c, mb.position.x)
		var hit := _tl_key_at(c, row, mb.position.x)
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if hit >= 0.0:
				_an_key_row = row
				_an_key_t = hit
				_an_delete_key()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		_an_play = false
		if hit >= 0.0:
			_an_key_row = row
			_an_key_t = hit
			_an_t = hit
			_tl_drag = "key"
			_tl_moved = false
		elif mb.double_click and row == _an_row():
			_an_t = t2
			_an_key_here()
		else:
			_an_key_row = ""
			_an_t = t2
			_tl_drag = "scrub"
	elif e is InputEventMouseMotion:
		var t3 := _tl_t(c, (e as InputEventMouseMotion).position.x)
		match _tl_drag:
			"scrub":
				_an_t = t3
			"key":
				if not _tl_moved:
					_an_undo_push()
					_an_undo_t = 0.0
					_tl_moved = true
				if _an_key_row == "udalosti":
					for ev in _ac.get("udalosti", []):
						if absf(float(ev["t"]) - _an_key_t) < 0.001:
							ev["t"] = snappedf(t3, 0.01)
							_an_key_t = snappedf(t3, 0.01)
							break
				else:
					_an_key_t = AnimClips.move_key(_ac, _an_key_row, _an_key_t, t3)
				_an_t = _an_key_t
				_an_dirty = true


## Test: a pose at the start and the end of a reload, played back; then the eyes view with the hand.
func _animtest() -> void:
	var shot := func(n: String):
		for f in 4: await get_tree().process_frame
		if DisplayServer.get_name() != "headless":
			get_viewport().get_texture().get_image().save_png("user://anim_%s.png" % n)
	mode = "atp"
	_rebuild_panel()
	for i in subj_opt.item_count:
		if String(subj_opt.get_item_metadata(i)) == "pistol":
			subj_opt.select(i)
			subj_opt.item_selected.emit(i)
	for f in 5: await get_tree().process_frame
	bone = "upperarm.R"
	_an_t = 0.0
	_an_sync_sliders()
	bone_sliders["x"].value = 30.0
	_an_t = 1.0
	_an_t_shown = -1.0
	for f in 2: await get_tree().process_frame
	bone_sliders["x"].value = 80.0
	_an_t = 0.5
	for f in 3: await get_tree().process_frame
	var mid := _an_bone_value("upperarm.R")
	print("[ANIM] keys %d, mid value %.1f (between 30 and 80)" % [AnimClips.track(_ac, "upperarm.R").size(), mid.x])
	await shot.call("tp")
	mode = "afp"
	_rebuild_panel()
	for f in 5: await get_tree().process_frame
	_an_select("ruka")
	_an_t = 0.3
	item_sliders["pos.x"].value = -0.05
	_an_select("Mag")
	item_sliders["pos.y"].value = -0.1
	_an_ev_opt.select(AN_SOUNDS.size() + 1)
	_an_add_event()
	_an_t = 0.6
	for f in 3: await get_tree().process_frame
	print("[ANIM] fp tracks %s hand visible %s carry '%s'" % [_ac.get("stopy", {}).keys(), _an_hand.visible, _an_carry])
	focus = "item"
	await shot.call("fp")
	print("RESULT animtest mid %s fp %s" % [mid.x > 31 and mid.x < 79, _an_hand.visible and _an_carry == "pistol_mag"])
	get_tree().quit()


## Renders a clip as a row of pictures (for comparing with a video):
## --clip=tp_salute_vse --item=pistol --frames=8 --yaw=3.14 --pitch=0
func _animshots() -> void:
	var id := Game.cmd_arg("clip", "tp_salute_vse")
	var parts := id.split("_")
	mode = "atp" if parts[0] == "tp" else "afp"
	_rebuild_panel()
	sub2 = parts[1]
	subject = "_".join(parts.slice(2))
	_an_load()
	_build_scene()
	yaw = float(Game.cmd_arg("yaw", str(PI)))
	pitch = float(Game.cmd_arg("pitch", "-0.05"))
	if mode == "atp":
		dist = float(Game.cmd_arg("dist", "2.4"))
		target = Vector3(0, 1.0, 0)
	_paused = true
	focus = "none"
	bone = ""
	var n := int(Game.cmd_arg("frames", "8"))
	var d := float(_ac.get("delka", 1.0))
	var imgs := []
	for i in n:
		_an_t = d * i / maxf(1.0, n - 1)
		for f in 4: await get_tree().process_frame
		for dd in _dots.values():
			dd.visible = false
		if _marker: _marker.visible = false
		var img := view.get_texture().get_image()
		if mode == "atp":
			var cw := int(img.get_height() * 0.6)
			img = img.get_region(Rect2i((img.get_width() - cw) / 2, 0, cw, img.get_height()))
		var hh := 220 if mode == "atp" else 300
		img.resize(int(img.get_width() * float(hh) / img.get_height()), hh)
		imgs.append(img)
	var w: int = imgs[0].get_width()
	var hh2: int = imgs[0].get_height()
	var out := Image.create(w * n, hh2, false, imgs[0].get_format())
	for i in n:
		out.blit_rect(imgs[i], Rect2i(0, 0, w, hh2), Vector2i(w * i, 0))
	out.save_png("user://shots_%s.png" % id)
	print("RESULT animshots %s %d frames" % [id, n])
	get_tree().quit()
