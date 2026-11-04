extends Control
## Dílna (the Workshop): Ari fixes how items sit in the hands and corrects poses himself.
## Everything changed here goes to Game.tweaks and is saved to upravy.json next to the game;
## the game applies it at once (held items, hold poses, salute/at ease/hips, alien jobs).

const PlayerScript := preload("res://scripts/player.gd")
const AlienScript := preload("res://scripts/alien.gd")

const MODES := [["fp", "Předmět v ruce - z očí"], ["tp", "Předmět v ruce - zvenku (+ ruce)"], ["back", "Zbraň na zádech"],
	["emote", "Pózy žoldáka (pozdrav, pohov, v bok)"], ["alien", "Vetřelci - práce a postoje"]]
const EMOTES := [["salute", "Pozdrav (J)"], ["atease", "Pohov (U)"], ["hips", "Ruce v bok (stání)"]]
const ALIENS := ["grey", "grey_velitel", "jestetan", "bijec", "lihnoun", "zombie", "ohar"]
const ALIEN_ACTS := {"grey": ["work", "work_high", "talk", "stare"], "grey_velitel": ["work", "work_high", "talk", "stare"],
	"jestetan": ["guard", "stare"], "bijec": ["guard", "stare"], "lihnoun": ["eat"], "zombie": ["sway"], "ohar": ["sniff"]}
const ACT_NAMES := {"work": "práce u krávy (klečí)", "work_high": "oprava UFO (ruce nahoru)", "talk": "šeptání ve dvou", "stare": "zírání",
	"guard": "hlídka", "eat": "hodování", "sway": "kymácení", "sniff": "čmuchání"}
const HOLD_ACTS := [["", "drží"], ["1", "nabíjí"], ["2", "úder (chladná zbraň)"], ["3", "hrabe v batohu"], ["4", "ošetřuje"]]

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
	frame.add_theme_stylebox_override("panel", UiSkin.inset(3))
	frame.position = Vector2(6, 6)
	frame.size = Vector2(384, 348)
	add_child(frame)
	svc = SubViewportContainer.new()
	svc.stretch = true
	svc.gui_input.connect(_view_input)
	# a holder at the frame's size; the view inside renders at the screen's real resolution
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(378, 342)
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
	p.position = Vector2(396, 6)
	p.size = Vector2(238, 348)
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
	mode_opt.item_selected.connect(func(i): mode = MODES[i][0]; _rebuild_panel())
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
	_btn(row, "Zpět", func(): get_tree().change_scene_to_file("res://scenes/Main.tscn"))
	var row2 := HBoxContainer.new()
	panel_box.add_child(row2)
	_btn(row2, "Kopírovat", _copy)
	_btn(row2, "Vložit", _paste)
	_btn(row2, "Zrcadlit L/P", _mirror)
	_btn(row2, "Krok zpět", _undo)
	var row3 := HBoxContainer.new()
	panel_box.add_child(row3)
	var pause := CheckBox.new()
	pause.text = "Zastavit pohyb"
	pause.add_theme_font_size_override("font_size", 8)
	pause.toggled.connect(func(on): _paused = on)
	row3.add_child(pause)
	var grip := CheckBox.new()
	grip.text = "Levá drží zbraň"
	grip.button_pressed = true
	grip.add_theme_font_size_override("font_size", 8)
	grip.toggled.connect(func(on): _grip_on = on)
	row3.add_child(grip)
	var row4 := HBoxContainer.new()
	panel_box.add_child(row4)
	for v in [["Zepředu", PI, 0.0], ["Z boku", PI * 0.5, 0.0], ["Shora", PI, -1.2], ["Zezadu", 0.0, -0.1]]:
		var vy: float = v[1]
		var vp: float = v[2]
		_btn(row4, v[0], func(): yaw = vy; pitch = vp)
	_lbl(panel_box, "Ctrl+Z = krok zpět. Při ladění polohy zbraně vypni „Levá drží zbraň“, ať se ti nehýbe ruka; pak ji zase zapni.", UiSkin.DIM)
	_rebuild_panel()
	if Game.autotest() == "workshop":
		_selftest.call_deferred()

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
	for s in subjects:
		subj_opt.add_item(s[1])
		subj_opt.set_item_metadata(subj_opt.item_count - 1, s[0])
	subject = subjects[0][0]
	subj_opt.item_selected.connect(func(i):
		subject = subj_opt.get_item_metadata(i)
		_fill_sub2()
		_build_scene())
	sub2_opt = _opt(dyn)
	sub2_opt.item_selected.connect(func(i): sub2 = String(sub2_opt.get_item_metadata(i)); _sync_sliders(); _build_scene())
	if mode in ["fp", "tp", "back"]:
		_lbl(dyn, "POSUN A NATOČENÍ PŘEDMĚTU")
		for k in [["pos.x", "doprava", -0.3, 0.3, 0.002], ["pos.y", "nahoru", -0.3, 0.3, 0.002], ["pos.z", "dozadu", -0.3, 0.3, 0.002],
				["rot.x", "kývnutí", -180, 180, 1], ["rot.y", "otočení", -180, 180, 1], ["rot.z", "náklon", -180, 180, 1], ["scale", "velikost", 0.5, 2.0, 0.01]]:
			var key: String = k[0]
			item_sliders[key] = _slider(dyn, k[1], k[2], k[3], k[4], func(): _item_changed())
	if mode in ["tp", "emote", "alien"]:
		_lbl(dyn, "KOST (natočení navíc ke stávající póze)")
		bone_opt = _opt(dyn)
		bone_opt.item_selected.connect(func(i): bone = String(bone_opt.get_item_metadata(i)); _sync_sliders())
		for ax in [["x", "předklon"], ["y", "otočení"], ["z", "do strany"]]:
			var a: String = ax[0]
			bone_sliders[a] = _slider(dyn, ax[1], -180, 180, 1, func(): _bone_changed())
		_lbl(dyn, "Klikni na kloub v obrázku a táhni: nahoru/dolů ho ohýbá, do stran otáčí, se Shiftem naklání do strany. Pravé tlačítko otáčí pohled.", UiSkin.DIM)
	if mode == "tp":
		_lbl(dyn, "LEVÁ RUKA NA ZBRANI (oranžová tečka)")
		for ax in [["x", "do strany"], ["y", "nahoru"], ["z", "dopředu/zpět"]]:
			var a2: String = ax[0]
			grip_sliders[a2] = _slider(dyn, ax[1], -0.8, 0.8, 0.002, func(): _grip_changed())
		_lbl(dyn, "Levá ruka se sama chytí zbraně - posuneš zbraň nebo pravou ruku a levá jde s ní.", UiSkin.DIM)
	_lbl(dyn, "Myš: tažení mimo kloub (nebo pravým tlačítkem) otáčí pohled, kolečko přibližuje." if mode != "fp" else "Pohled je přesně z očí žoldáka.", UiSkin.DIM)
	_fill_sub2()
	_build_scene()

func _fill_sub2() -> void:
	sub2_opt.clear()
	sub2_opt.visible = mode in ["tp", "alien"]
	if mode == "tp":
		for a in HOLD_ACTS:
			sub2_opt.add_item(a[1])
			sub2_opt.set_item_metadata(sub2_opt.item_count - 1, a[0])
	elif mode == "alien":
		for a in ALIEN_ACTS.get(subject, []):
			sub2_opt.add_item(ACT_NAMES.get(a, a))
			sub2_opt.set_item_metadata(sub2_opt.item_count - 1, a)
	sub2 = String(sub2_opt.get_item_metadata(0)) if sub2_opt.item_count > 0 else ""

## The tweak key edited right now.
func _item_key() -> String:
	return {"fp": "fp/", "tp": "tp/", "back": "back/"}.get(mode, "") + subject

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
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_Z and ev.ctrl_pressed:
		_undo()
		get_viewport().set_input_as_handled()

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
	_push_undo()
	var t2 := {"pos": [item_sliders["pos.x"].value, item_sliders["pos.y"].value, item_sliders["pos.z"].value],
		"rot": [item_sliders["rot.x"].value, item_sliders["rot.y"].value, item_sliders["rot.z"].value], "scale": item_sliders["scale"].value}
	Game.tweaks[_item_key()] = t2
	_place_item()

func _bone_changed() -> void:
	if bone == "":
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
	_syncing = true
	if not item_sliders.is_empty():
		var t2: Dictionary = Game.tweaks.get(_item_key(), {})
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
	if mode in ["fp", "tp", "back"]:
		Game.tweaks.erase(_item_key())
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
	(world.get_node("Floor") as Node3D).visible = mode != "fp"
	match mode:
		"fp":
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
				holder.add_child(Game.model("hands_" + subject))
			else:
				holder.add_child(Game.model("hand_l" if shield else "hand_r"))
		"tp", "back", "emote":
			model = Game.model("merc")
			model.scale = Vector3(-1, 1, 1)     # as in the game: the gun hand is the right one
			world.add_child(model)
			Game.apply_look(model, Game.merc.get("look", {}))
			for gname in ["Gear_Scanner", "Gear_Plate", "Gear_Grenade", "Gear_Flare"]:
				var gn := model.find_child(gname, true, false)
				if gn:
					gn.visible = false     # the old hand-held scanner and spare kit: not on show here
			_setup_rig()
			if mode in ["tp", "back"]:
				holder = Node3D.new()
				var att := BoneAttachment3D.new()
				att.bone_name = "spine"
				sk.add_child(att)
				att.add_child(holder)
				var rest := sk.get_bone_global_rest(sk.find_bone("spine"))
				if mode == "tp":
					holder.transform = rest.affine_inverse() * Transform3D(Basis(), Vector3(-0.1, 1.2, -0.3))
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
	_place_item()
	_fill_bones()
	_sync_sliders()

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
	else:
		item_node = Game.held_model(subject, mode == "tp")
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
			"tp":
				var a := int(sub2) if sub2 != "" else 0
				want = Game.tweak_pose("hold/" + subject, PlayerScript.hold_want(subject, "", a, fmod(t, 1.2)))
			"back":
				want = PlayerScript.hold_want("", "", 0, 0.0)
			"emote":
				var base: Dictionary = {"salute": PlayerScript.POSE_SALUTE, "atease": PlayerScript.POSE_ATEASE, "hips": PlayerScript.POSE_HIPS}[subject]
				want = Game.tweak_pose("emote/" + subject, base)
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
		if mode == "tp" and holder and item_node:
			# exactly as in the game: the gun sits in the right hand, the left hand takes hold of it
			var hi := sk.find_bone("hand.R")
			if hi >= 0:
				var hand := sk.global_transform * sk.get_bone_global_pose(hi)
				holder.global_position = hand.origin + hand.basis.y.normalized() * -0.05
			var g := ArmIK.grips(subject, item_node) if Game.ITEMS.get(subject, {}).get("type", "") == "weapon" else {}
			if g.has("l") and sub2 == "" and _grip_on:
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
	if mode != "fp":
		var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
		cam.position = target + dir * dist
		cam.look_at(target, Vector3.UP)
		cam.fov = 50.0

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
	if mode == "fp":
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
				dragging = true
				_bone_drag = false
				_pick_bone(ev.position)
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
func _pick_bone(at: Vector2) -> void:
	if sk == null or bone_opt == null:
		return
	var vs := Vector2(view.size)
	var scale := vs / Vector2(378, 342)
	var p := at * scale
	var best := -1
	var bd := 20.0 * scale.x
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
		_bone_drag = true        # keep the button down and drag: the joint turns
