extends Control
## Animace (0.52, after the Svitky Světlenu animation editor): every movement of the game as an
## animation Ari can open, change and save - the body (standing, walking, running, crouching, lying,
## crawling, dying), what the hands do with each thing seen from outside (holding, reloading, a blow,
## bandaging, digging in the pack, a throw), the poses (salute, at ease, hands on the hips) and what the
## eyes see (reloading, a blow, a throw, bandaging, digging). A body movement that was never changed
## is read from the game's model, so there is always something to start from.
##
## Click a joint (orange dot) and turn it by its rings - the key is written at the current time by
## itself. The bar at the bottom is the time line: a row per joint, keys as diamonds (drag = move in
## time, double click = key here, right click = delete), the top row moves the whole pose. The thing
## in the hand can be locked to the hand: then it turns with the hand in every movement.
## Saved to res://animace/<id>.json (AnimClips); the game uses it at once.

const PlayerScript := preload("res://scripts/player.gd")
const BONES := ["root", "hips", "spine", "neck", "head", "upperarm.L", "forearm.L", "hand.L", "upperarm.R", "forearm.R", "hand.R",
	"thigh.L", "shin.L", "thigh.R", "shin.R"]
const BONE_NAMES := {"root": "Celé tělo (posun)", "hips": "Pánev", "spine": "Trup", "neck": "Krk", "head": "Hlava",
	"upperarm.L": "Levé rameno", "forearm.L": "Levý loket", "hand.L": "Levá ruka", "upperarm.R": "Pravé rameno",
	"forearm.R": "Pravý loket", "hand.R": "Pravá ruka", "thigh.L": "Levé stehno", "shin.L": "Levé koleno",
	"thigh.R": "Pravé stehno", "shin.R": "Pravé koleno"}
const BODY := [["idle", "Stání"], ["walk", "Chůze"], ["run", "Běh"], ["sprint", "Sprint"], ["crouch", "Podřep"],
	["crouch_walk", "Chůze v podřepu"], ["prone", "Leh"], ["prone_crawl", "Plazení"], ["downed", "Raněný na zemi"],
	["crawl_idle", "Raněný na čtyřech"], ["crawl_hurt", "Raněný leze"], ["dead", "Smrt (pád)"]]
const LOOPS := ["idle", "walk", "run", "sprint", "crouch", "crouch_walk", "prone", "prone_crawl", "downed", "crawl_idle", "crawl_hurt"]
const HANDS := [["hold", "Držení (postoj)"], ["reload", "Přebíjení"], ["strike", "Úder (nůž, obušek, pažba)"], ["heal", "Ošetřování"],
	["dig", "Hrabání v batohu"], ["throw", "Hod (granát, světlice)"]]
const EMOTES := [["salute", "Pozdrav (J)"], ["atease", "Pohov (U)"], ["hips", "Ruce v bok"]]
const EYES := [["reload", "Přebíjení"], ["reload1", "Přebíjení po náboji"], ["strike", "Úder"], ["throw", "Hod"],
	["heal", "Ošetřování"], ["dig", "Hrabání v batohu"]]
const SOUNDS := ["mag_out", "mag_in", "pistol_slide", "revolver_open", "revolver_close", "shell_insert", "shotgun_pump",
	"sniper_bolt", "reload", "casing", "clink", "knife_stab", "baton_hit", "bandage", "backpack_zip", "backpack_rummage",
	"gear_rattle", "pickup", "flare", "fuse_out", "body_drag", "prone"]
const CARRY := ["", "pistol_mag", "rifle_clip", "shell", "round", "magnum_rounds", "bandage", "medkit", "grenade", "flare"]
const ROOT_POS := "root@pos"

var kind := "body"           # body / hand / emote / eyes
var act := "idle"
var item := "vse"
var clip_id := ""
var _ac := {}                # the clip being edited
var _saved_json := ""        # what is on disk (to know if it changed)
var _from_game := false      # nothing saved yet: read from the game
var t := 0.0
var playing := false
var speed := 1.0
var sel := "spine"           # a bone (body/hand/emote) or a thing (eyes: zbran / ruka / a part)
var tool := "otaceni"        # otaceni / posun (eyes, root)
var _undo := []
var _redo := []
var _clip_pose := {}         # copied pose
var lock := true

# 3D
var svc: SubViewportContainer
var view: SubViewport
var world: Node3D
var cam: Camera3D
var ov: EdUI.Overlay
var model: Node3D
var sk: Skeleton3D
var ap: AnimationPlayer
var holder: Node3D           # what the right hand holds (tp) / the gun (eyes)
var item_node: Node3D
var hand_l: Node3D           # eyes: the free left hand
var _carry := "?"
var _lock_rel := Transform3D()
var _lock_ok := false
var yaw := PI + 0.6
var pitch := -0.15
var dist := 2.4
var target := Vector3(0, 1.0, 0)

# mouse
var _drag := ""
var _drag_axis := -1
var _drag_from := Vector2.ZERO
var _drag_start := Transform3D()
var _drag_parent := Basis()
var _drag_val := []
var _hover := -1
var _grid: MeshInstance3D

# ui
var act_list: ItemList
var _act_keys: Array = []
var item_opt: OptionButton
var info_lbl: Label
var title_lbl: Label
var status: Label
var hint: Label
var time_lbl: Label
var len_spin: SpinBox
var loop_chk: CheckBox
var lock_chk: CheckBox
var sel_lbl: Label
var _f := {}
var _updating := false
var ease_opt: OptionButton
var ev_list: ItemList
var ev_opt: OptionButton
var tl: Timeline
var _tool_btns := {}

func _ready() -> void:
	EdUI.enter(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = EdUI.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 8
	root.offset_top = 6
	root.offset_right = -8
	root.offset_bottom = -6
	root.add_theme_constant_override("separation", 6)
	add_child(root)
	EdUI.tabs(root, "anim")
	var main := HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 6)
	root.add_child(main)
	_build_left(main)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 4)
	main.add_child(mid)
	_build_toolbar(mid)
	title_lbl = EdUI.lbl(mid, "", EdUI.ACCENT)
	title_lbl.clip_text = true
	var v := EdUI.view3d(mid)
	svc = v[0]
	view = v[1]
	world = v[2]
	cam = v[3]
	svc.gui_input.connect(_view_input)
	ov = EdUI.Overlay.new(cam, view)
	world.add_child(ov)
	_grid = EdUI.grid3d(world, 3.0)
	var tlp := PanelContainer.new()
	tlp.custom_minimum_size = Vector2(0, 230)
	mid.add_child(tlp)
	var tlv := VBoxContainer.new()
	tlp.add_child(tlv)
	var tr := HFlowContainer.new()
	tr.add_theme_constant_override("h_separation", 6)
	tlv.add_child(tr)
	EdUI.btn(tr, "|◀", func(): t = 0.0; playing = false, "Na začátek (Home)")
	EdUI.btn(tr, "▶ / ❚❚", func(): playing = not playing, "Přehrát / zastavit (mezerník)")
	EdUI.opt(tr, [[1.0, "rychlost 100 %"], [0.5, "50 %"], [0.25, "25 %"], [0.1, "10 %"]], func(v2): speed = float(v2))
	time_lbl = EdUI.lbl(tr, "", EdUI.AMBER)
	time_lbl.custom_minimum_size = Vector2(120, 0)
	EdUI.lbl(tr, "Délka:")
	len_spin = EdUI.spin(tr, 0.1, 20.0, 0.05, func(val):
		if _updating:
			return
		_push()
		_ac["delka"] = val
		t = minf(t, val)
		_changed(), " s")
	len_spin.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	loop_chk = EdUI.check(tr, "Smyčka", false, func(on):
		if _updating:
			return
		_push()
		_ac["smycka"] = on
		_changed())
	EdUI.btn(tr, "Natáhnout délku…", _stretch_dialog, "Zrychlí nebo zpomalí celou animaci (klíče se posunou)")
	tl = Timeline.new()
	tl.ed = self
	tl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tlv.add_child(tl)
	_build_right(main)
	var foot := EdUI.row(root, 10)
	status = EdUI.lbl(foot, "", EdUI.AMBER)
	status.custom_minimum_size = Vector2(320, 0)
	hint = EdUI.lbl(foot, "", EdUI.DIM, 12, true)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.custom_minimum_size = Vector2(200, 0)
	hint.text = "Klik na kloub = vybrat · tah za kruh = otočit (klíč se zapíše sám) · tah za šipku = posun · Pravé: otáčet pohled · Střední: posun pohledu · Kolečko: zoom · Mezerník: přehrát · K klíč · Shift+K klíč všem · Del smazat klíč · Ctrl+C/V póza · M zrcadlit · ,/. o snímek · Ctrl+Z/Y · Ctrl+S"
	_fill_acts()
	var want := Game.cmd_arg("anim", "")
	if want != "":
		var p := want.split(":")
		_open(p[0], p[1], p[2] if p.size() > 2 else "vse")
	else:
		_open("body", "walk", "vse")
	if Game.autotest() == "animator":
		_selftest.call_deferred()
	elif Game.autotest() == "animatorshots":
		_shots.call_deferred()

# ---- panels ---------------------------------------------------------------------------------------
func _build_left(parent: Node) -> void:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(260, 0)
	box.add_theme_constant_override("separation", 6)
	parent.add_child(box)
	var p := PanelContainer.new()
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	EdUI.head(v, "Co animuji")
	act_list = ItemList.new()
	act_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	act_list.item_selected.connect(func(i):
		var k: Array = _act_keys[i]
		if k.is_empty():
			return
		_ask_then(func(): _open(k[0], k[1], item)))
	v.add_child(act_list)
	EdUI.head(v, "Pro věc")
	item_opt = OptionButton.new()
	item_opt.focus_mode = Control.FOCUS_NONE
	item_opt.item_selected.connect(func(i):
		var it := String(item_opt.get_item_metadata(i))
		_ask_then(func(): _open(kind, act, it)))
	v.add_child(item_opt)
	info_lbl = EdUI.lbl(v, "", EdUI.DIM, 12, true)
	var g := EdUI.grid(v, 1)
	EdUI.btn(g, "Uložit (Ctrl+S)", _save).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	EdUI.btn(g, "Uložit pro všechny věci", _save_for_all, "Uloží tuhle animaci jako společnou pro každou věc (věci bez vlastní animace ji použijí)").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	EdUI.btn(g, "Vrátit původní ze hry", func(): EdUI.ask(self, "Smazat upravenou animaci a vrátit původní pohyb ze hry?", _revert, "Vrátit"), "Smaže soubor s úpravou").size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _build_toolbar(parent: Node) -> void:
	var bar := HFlowContainer.new()      # wraps onto a second line in a small window
	bar.add_theme_constant_override("h_separation", 4)
	bar.add_theme_constant_override("v_separation", 4)
	parent.add_child(bar)
	for e in [["otaceni", "Otáčení (R)"], ["posun", "Posun (G)"]]:
		var m: String = e[0]
		_tool_btns[m] = EdUI.btn(bar, e[1], func(): _set_tool(m), "", true)
	EdUI.lbl(bar, " ")
	EdUI.btn(bar, "Klíč (K)", _key_here, "Zapíše klíč vybranému kloubu v tomhle čase")
	EdUI.btn(bar, "Klíč všem (Shift+K)", _key_all, "Zapíše klíč všem kloubům v tomhle čase")
	EdUI.btn(bar, "Smazat klíč (Del)", _delete_key)
	EdUI.btn(bar, "Kopírovat pózu", _copy_pose, "Ctrl+C")
	EdUI.btn(bar, "Vložit pózu", _paste_pose, "Ctrl+V")
	EdUI.btn(bar, "Zrcadlit L↔P (M)", _mirror_pose)
	EdUI.btn(bar, "Zpět", _undo_step, "Ctrl+Z")
	EdUI.btn(bar, "Znovu", _redo_step, "Ctrl+Y")

func _build_right(parent: Node) -> void:
	var outer := VBoxContainer.new()
	outer.custom_minimum_size = Vector2(290, 0)
	parent.add_child(outer)
	var v := EdUI.panel(outer)
	EdUI.head(v, "Vybráno")
	sel_lbl = EdUI.lbl(v, "", EdUI.ACCENT, 15)
	var bo := EdUI.opt(v, [], func(b): _select(String(b)))
	bo.name = "SelOpt"
	EdUI.lbl(v, "Natočení (°)", EdUI.DIM, 12)
	var g1 := EdUI.row(v, 3)
	for k in 3:
		var kk := k
		var s := EdUI.spin(g1, -720, 720, 0.5, func(val): _on_field("r", kk, val))
		s.custom_minimum_size = Vector2(60, 0)
		s.prefix = ["X", "Y", "Z"][k]
		_f["r%d" % k] = s
	EdUI.lbl(v, "Posun (cm)", EdUI.DIM, 12)
	var g2 := EdUI.row(v, 3)
	for k in 3:
		var kk := k
		var s := EdUI.spin(g2, -500, 500, 0.1, func(val): _on_field("p", kk, val))
		s.custom_minimum_size = Vector2(60, 0)
		s.prefix = ["X", "Y", "Z"][k]
		_f["p%d" % k] = s
	var r3 := EdUI.row(v)
	EdUI.btn(r3, "Vynulovat", _reset_sel, "Kloub zpět do výchozí polohy (zapíše klíč)")
	EdUI.lbl(r3, "Přechod:")
	ease_opt = EdUI.opt(r3, [["", "plynule"], ["rovnomerne", "rovnoměrně"], ["skok", "skokem"]], func(k2): _set_ease(String(k2)))
	EdUI.head(v, "Věc v ruce")
	lock_chk = EdUI.check(v, "Zamknout věc do ruky", true, func(on):
		if _updating:
			return
		lock = on
		if item != "vse" and item != "":
			Game.tweaks["lock/" + item] = on
			Game.save_tweaks()
		status.text = "Věc teď %s s rukou." % ("jde" if on else "nejde"), "Zamknutá věc se otáčí s rukou (úder, přebíjení...). Platí i ve hře.")
	EdUI.lbl(v, "Zamknutá věc drží v ruce stejně jako při držení a jde s každým pohybem ruky.", EdUI.DIM, 12, true)
	EdUI.head(v, "Události")
	ev_list = ItemList.new()
	ev_list.custom_minimum_size = Vector2(0, 110)
	ev_list.item_activated.connect(func(i): t = float((_ac.get("udalosti", []) as Array)[i]["t"]))
	v.add_child(ev_list)
	ev_opt = OptionButton.new()
	ev_opt.focus_mode = Control.FOCUS_NONE
	v.add_child(ev_opt)
	var r4 := EdUI.row(v)
	EdUI.btn(r4, "+ přidat v tomto čase", _add_event)
	EdUI.btn(r4, "Smazat", _delete_event)
	EdUI.head(v, "Jak na to")
	EdUI.lbl(v, "1) Vlevo vyber pohyb (a věc).\n2) Posuň čas na ose dole.\n3) Klikni na kloub a otoč ho za kruh - klíč se zapíše sám.\n4) Mezi klíči se pohyb dopočítá. Mezerník přehraje.\n5) Ctrl+S uloží - hra to hned použije.", EdUI.DIM, 12, true)

func _fill_acts() -> void:
	act_list.clear()
	_act_keys.clear()
	var add_head := func(text: String):
		act_list.add_item(text)
		var i := act_list.item_count - 1
		act_list.set_item_disabled(i, true)
		act_list.set_item_selectable(i, false)
		act_list.set_item_custom_fg_color(i, EdUI.AMBER)
		_act_keys.append([])
	var add := func(k: String, a: String, text: String):
		var mark := " •" if _has_any(k, a) else ""
		act_list.add_item("   " + text + mark)
		_act_keys.append([k, a])
		if k == kind and a == act:
			act_list.select(act_list.item_count - 1)
	add_head.call("TĚLO (pohyby)")
	for e in BODY:
		add.call("body", e[0], e[1])
	add_head.call("RUCE ZVENKU (s věcí)")
	for e in HANDS:
		add.call("hand", e[0], e[1])
	add_head.call("PÓZY")
	for e in EMOTES:
		add.call("emote", e[0], e[1])
	add_head.call("Z OČÍ (s věcí)")
	for e in EYES:
		add.call("eyes", e[0], e[1])

func _has_any(k: String, a: String) -> bool:
	for id in AnimClips.all_ids():
		if id.begins_with(_prefix(k, a)):
			return true
	return false

func _prefix(k: String, a: String) -> String:
	match k:
		"body": return "tp_body_" + a
		"hand", "emote": return "tp_%s_" % a
		_: return "fp_%s_" % a

func _fill_items() -> void:
	item_opt.clear()
	if kind == "body" or kind == "emote":
		item_opt.add_item("— nic v ruce —" if kind == "emote" else "— bez věci —")
		item_opt.set_item_metadata(0, "vse")
		item_opt.disabled = kind == "emote"
		if kind == "body":
			for id in Game.ITEMS:
				if ResourceLoader.exists("res://assets/models/%s.glb" % id) and not id.begins_with("a_pack"):
					item_opt.add_item("ukázat s: " + String(Game.ITEMS[id]["name"]))
					item_opt.set_item_metadata(item_opt.item_count - 1, "show:" + id)
		item_opt.disabled = kind == "emote"
	else:
		item_opt.disabled = false
		if kind == "hand":
			item_opt.add_item("— pro všechno —")
			item_opt.set_item_metadata(0, "vse")
		for id in Game.ITEMS:
			if not ResourceLoader.exists("res://assets/models/%s.glb" % id) or id.begins_with("a_pack"):
				continue
			var ty: String = Game.ITEMS[id].get("type", "")
			if kind == "eyes" and act in ["reload", "reload1"] and ty != "weapon":
				continue
			var own := FileAccess.file_exists(AnimClips.path_of("%s%s" % [_prefix(kind, act), id]))
			item_opt.add_item(String(Game.ITEMS[id]["name"]) + (" •" if own else ""))
			item_opt.set_item_metadata(item_opt.item_count - 1, id)
	EdUI.opt_select(item_opt, item)

# ---- opening and saving -----------------------------------------------------------------------------
func _ask_then(cb: Callable) -> void:
	if _dirty():
		EdUI.ask(self, "Animace má neuložené změny. Zahodit je?", cb, "Zahodit")
	else:
		cb.call()

func _dirty() -> bool:
	return JSON.stringify(_ac) != _saved_json

func _open(k: String, a: String, it: String) -> void:
	kind = k
	act = a
	var show := ""
	if it.begins_with("show:"):
		show = it.substr(5)
	if k == "body":
		item = it if show != "" else "vse"
	elif k == "emote":
		item = "vse"
	elif k == "eyes":
		item = it if it != "vse" and Game.ITEMS.has(it) else ("pistol" if a in ["reload", "reload1", "strike"] else "grenade")
		if a == "strike" and it == "vse":
			item = "knife"
		elif a == "heal" and it == "vse":
			item = "medkit"
	else:
		item = it
	clip_id = (_prefix(k, a) + ("" if k == "body" else (item if item != "vse" or k != "eyes" else "pistol"))) if k != "body" else "tp_body_" + a
	if k in ["hand", "emote"] and item == "vse":
		clip_id = "tp_%s_vse" % a
	var own := AnimClips.get_clip(clip_id)
	_from_game = own.is_empty()
	if not own.is_empty():
		_ac = own.duplicate(true)
		_saved_json = JSON.stringify(_ac)
	else:
		_ac = _start_clip()
		_saved_json = JSON.stringify(_ac)
	_undo.clear()
	_redo.clear()
	t = 0.0
	playing = kind == "body" and act in LOOPS
	lock = bool(Game.tweaks.get("lock/" + (show if show != "" else item), true))
	_build_scene(show)
	_fill_acts()
	_fill_items()
	if show != "":
		EdUI.opt_select(item_opt, "show:" + show)
	_fill_sel_opt()
	if kind == "eyes":
		_select("zbran")
		_set_tool("posun")
	else:
		_select("spine" if kind == "body" else "upperarm.R")
		_set_tool("otaceni")
	_fill_events()
	_sync_ui()
	status.text = ("Upravená animace: %s" % AnimClips.path_of(clip_id)) if not _from_game else "Pohyb ze hry - úpravy se uloží do %s" % AnimClips.path_of(clip_id)

## Something to start from: a body movement from the model, a hand action from the game's poses.
func _start_clip() -> Dictionary:
	var name := _title()
	var c := AnimClips.new_clip("tp" if kind != "eyes" else "fp", name)
	if kind == "body":
		var m := (load("res://assets/models/merc.glb") as PackedScene).instantiate()
		var a := m.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var s := m.find_child("Skeleton3D", true, false) as Skeleton3D
		if a and a.has_animation(act):
			c = import_animation(a.get_animation(act), s, name)
		m.free()
		c["smycka"] = act in LOOPS
		return c
	if kind == "hand" and act in ["reload", "strike"] and item != "vse":
		# from the clip for everything, if there is one
		var fall := AnimClips.get_clip("tp_%s_vse" % act)
		if not fall.is_empty():
			c = fall.duplicate(true)
	if kind == "eyes":
		var fall2 := AnimClips.find("fp", act, item)
		if not fall2.is_empty():
			c = fall2.duplicate(true)
		c["delka"] = {"reload": 1.5, "reload1": 0.8, "strike": 0.45, "throw": 0.6, "heal": 2.0, "dig": 2.0}.get(act, 1.0)
	if kind == "hand":
		c["delka"] = {"reload": 1.5, "strike": 0.45, "heal": 2.0, "dig": 2.0, "throw": 0.6, "hold": 1.2}.get(act, 1.0)
		c["smycka"] = act in ["hold", "heal", "dig"]
	if kind == "emote":
		c["delka"] = 2.4
		c["smycka"] = act != "salute"
	return c

## A body movement of the model as an editable clip: the turn of every joint at every key (degrees,
## from the joint's rest) and the move of the whole body (root, metres from rest).
static func import_animation(anim: Animation, s: Skeleton3D, name: String) -> Dictionary:
	var c := AnimClips.new_clip("tp", name)
	c["delka"] = snappedf(anim.length, 0.01)
	for tr in anim.get_track_count():
		var path := String(anim.track_get_path(tr))
		var bone := path.get_slice(":", 1)
		var bi := s.find_bone(bone)
		if bi < 0:
			continue
		var rest := s.get_bone_rest(bi)
		var times := []
		var vals := []
		var row := bone
		match anim.track_get_type(tr):
			Animation.TYPE_ROTATION_3D:
				var rq := rest.basis.get_rotation_quaternion()
				var prev := Vector3.ZERO
				for k in anim.track_get_key_count(tr):
					var q: Quaternion = anim.track_get_key_value(tr, k)
					var off := Basis(rq.inverse() * q).get_euler() * (180.0 / PI)
					if k > 0:
						# no jumps of 360 degrees between keys
						for j in 3:
							off[j] = prev[j] + wrapf(off[j] - prev[j], -180.0, 180.0)
					prev = off
					times.append(anim.track_get_key_time(tr, k))
					vals.append([off.x, off.y, off.z])
			Animation.TYPE_POSITION_3D:
				if bone != "root":
					continue
				row = ROOT_POS
				for k in anim.track_get_key_count(tr):
					var p: Vector3 = anim.track_get_key_value(tr, k) - rest.origin
					times.append(anim.track_get_key_time(tr, k))
					vals.append([p.x, p.y, p.z])
			_:
				continue
		if times.is_empty():
			continue
		# only the keys that matter (the model has one every frame): what is left in between is a straight line
		var keep := {0: true, times.size() - 1: true}
		_reduce(times, vals, 0, times.size() - 1, 0.005 if row == ROOT_POS else 1.0, keep)
		var ks := keep.keys()
		ks.sort()
		for i in ks:
			var v: Array = vals[i]
			var d := 0.001 if row == ROOT_POS else 0.1
			AnimClips.set_key(c, row, float(times[i]), [snappedf(v[0], d), snappedf(v[1], d), snappedf(v[2], d)])
		for key in AnimClips.track(c, row):
			key["prechod"] = "rovnomerne"
	return c

## Douglas-Peucker on a track: keeps the key that strays most from the straight line, until none strays more than @a tol.
static func _reduce(times: Array, vals: Array, a: int, b: int, tol: float, keep: Dictionary) -> void:
	if b - a < 2:
		return
	var worst := -1
	var wd := tol
	var ta := float(times[a])
	var tb := float(times[b])
	for i in range(a + 1, b):
		var k := (float(times[i]) - ta) / maxf(0.0001, tb - ta)
		for j in 3:
			var lin := lerpf(float(vals[a][j]), float(vals[b][j]), k)
			var dd := absf(float(vals[i][j]) - lin)
			if dd > wd:
				wd = dd
				worst = i
	if worst < 0:
		return
	keep[worst] = true
	_reduce(times, vals, a, worst, tol, keep)
	_reduce(times, vals, worst, b, tol, keep)

func _title() -> String:
	var lists := {"body": BODY, "hand": HANDS, "emote": EMOTES, "eyes": EYES}
	var nm := act
	for e in lists[kind]:
		if e[0] == act:
			nm = e[1]
	var it := ""
	if kind in ["hand", "eyes"]:
		it = " – " + (String(Game.ITEMS[item]["name"]) if Game.ITEMS.has(item) else "všechno")
	return {"body": "Tělo: ", "hand": "Ruce: ", "emote": "Póza: ", "eyes": "Z očí: "}[kind] + nm + it

func _save() -> void:
	if AnimClips.save_clip(clip_id, _ac):
		_saved_json = JSON.stringify(_ac)
		_from_game = false
		status.text = "Uloženo: %s (hra ji použije hned)." % AnimClips.path_of(clip_id)
		Game.play_ui(self, "ui_confirm", -6)
	else:
		status.text = "Uložení se nepovedlo."
		Game.play_ui(self, "ui_deny", -6)
	_fill_acts()
	_fill_items()
	_sync_ui()

func _save_for_all() -> void:
	if kind == "body" or kind == "emote":
		_save()
		return
	var id := ("tp_%s_vse" if kind == "hand" else "fp_%s_vse") % act
	AnimClips.save_clip(id, _ac)
	status.text = "Uloženo jako společná: %s" % AnimClips.path_of(id)
	_fill_acts()

func _revert() -> void:
	AnimClips.delete_clip(clip_id)
	_open(kind, act, item)
	status.text = "Vráceno - hra zase používá původní pohyb."

# ---- undo -------------------------------------------------------------------------------------------
func _push() -> void:
	_redo.clear()
	_undo.append(_ac.duplicate(true))
	if _undo.size() > 150:
		_undo.pop_front()

func _undo_step() -> void:
	if _undo.is_empty():
		return
	_redo.append(_ac.duplicate(true))
	_ac = _undo.pop_back()
	_changed()

func _redo_step() -> void:
	if _redo.is_empty():
		return
	_undo.append(_ac.duplicate(true))
	_ac = _redo.pop_back()
	_changed()

func _changed() -> void:
	_fill_events()
	_sync_ui()

# ---- the scene ---------------------------------------------------------------------------------------
func _build_scene(show := "") -> void:
	if model:
		model.queue_free()
	model = null
	sk = null
	ap = null
	holder = null
	item_node = null
	hand_l = null
	_carry = "?"
	_lock_ok = false
	if kind == "eyes":
		_grid.visible = false
		model = Node3D.new()
		world.add_child(model)
		cam.transform = Transform3D()
		cam.fov = Game.fov
		holder = Node3D.new()
		model.add_child(holder)
		var shield: bool = Game.ITEMS.get(item, {}).get("type", "") == "shield"
		holder.position = PlayerScript.VM_ONE_L if shield else PlayerScript.VM_R.get(item, PlayerScript.VM_ONE_R)
		if Game.two_handed(item):
			var hb := Game.model("hands_" + item)
			hb.name = "GripTwo"
			holder.add_child(hb)
			var h1 := Game.model("hand_r")
			h1.name = "GripOne"
			h1.visible = false
			holder.add_child(h1)
		else:
			holder.add_child(Game.model("hand_l" if shield else "hand_r"))
		if Game.ITEMS.has(item):
			item_node = Game.held_model(item, false)
			holder.add_child(item_node)
		hand_l = Game.model("hand_l")
		model.add_child(hand_l)
		hand_l.visible = false
		return
	_grid.visible = true
	model = Game.model("merc")
	model.scale = Vector3(-1, 1, 1)
	world.add_child(model)
	if kind == "body" and act in ["prone", "prone_crawl", "dead"]:
		# as the game lays him down: on the belly (prone) or on the back (dead)
		var dead := act == "dead"
		model.rotation.x = PI / 2 if dead else -PI / 2
		model.position = Vector3(0, 0.18, -0.9 if dead else 0.9)
	Game.apply_look(model, Game.merc.get("look", {}))
	for gname in ["Gear_Scanner", "Gear_Plate", "Gear_Grenade", "Gear_Flare"]:
		var gn := model.find_child(gname, true, false)
		if gn:
			gn.visible = false
	sk = model.find_child("Skeleton3D", true, false)
	ap = model.find_child("AnimationPlayer", true, false)
	if ap:
		ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var base := act if kind == "body" else ("crouch" if act in ["dig", "heal"] else "idle")
		if ap.has_animation(base):
			ap.play(base)
	var it := show if show != "" else (item if item != "vse" else "")
	if kind == "hand" and it == "":
		it = {"reload": "rifle", "strike": "knife", "heal": "medkit", "throw": "grenade", "hold": "rifle", "dig": ""}.get(act, "")
	if it != "" and Game.ITEMS.has(it):
		# not on a bone attachment: it would lag a frame behind the pose set by hand
		holder = Node3D.new()
		model.add_child(holder)
		item_node = Game.held_model(it, true)
		holder.add_child(item_node)
		holder.set_meta("item", it)
	target = Vector3(0, 0.95 if kind == "body" else 1.15, 0)
	dist = 2.6 if kind == "body" else 2.0
	if act in ["prone", "prone_crawl", "downed", "crawl_idle", "crawl_hurt", "dead"]:
		target = Vector3(0, 0.3, 0.0)
		dist = 3.2

## The joints' values now: the base movement, the game's pose for the action, then the clip.
func _pose_now() -> Dictionary:
	var want := {}
	if kind == "hand":
		var a: int = {"reload": 1, "strike": 2, "dig": 3, "heal": 4}.get(act, 0)
		var it := String(holder.get_meta("item")) if holder else ""
		want = Game.tweak_pose("hold/" + (it if it != "" else "nic"), PlayerScript.hold_want(it, "", a, t))
	elif kind == "emote":
		var base: Dictionary = {"salute": PlayerScript.POSE_SALUTE, "atease": PlayerScript.POSE_ATEASE, "hips": PlayerScript.POSE_HIPS}[act]
		want = Game.tweak_pose("emote/" + act, base)
	want.merge(AnimClips.pose(_ac, t), true)
	if kind == "body" and holder:
		# as in the game: with a thing in the hand the arms keep the holding pose (Ruce zvenku: Držení)
		var it2 := String(holder.get_meta("item"))
		want.merge(Game.tweak_pose("hold/" + it2, PlayerScript.hold_want(it2, "", 0, t)), true)
	return want

func _apply_pose() -> void:
	if sk == null:
		return
	if ap and ap.current_animation != "":
		var base_len := ap.current_animation_length
		ap.seek(fmod(t, base_len) if kind != "body" else minf(t, base_len), true)
	# the movement from the game first, then what the clip says
	var want := _pose_now()
	for bn in want:
		var i := sk.find_bone(bn)
		if i >= 0:
			var rest: Quaternion = sk.get_bone_rest(i).basis.get_rotation_quaternion()
			sk.set_bone_pose_rotation(i, rest * Quaternion.from_euler(want[bn]))
	var ri := sk.find_bone("root")
	if ri >= 0 and AnimClips.has_track(_ac, ROOT_POS):
		var v := AnimClips.sample(_ac, ROOT_POS, t)
		sk.set_bone_pose_position(ri, sk.get_bone_rest(ri).origin + Vector3(float(v[0]), float(v[1]), float(v[2])))
	# the thing in the hand: where the game puts it (the hand), locked = it turns with the hand too
	if holder and sk.find_bone("hand.R") >= 0:
		var hand := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("hand.R"))
		if not _lock_ok:
			_lock_ok = _find_lock_rel()
		if lock and _lock_ok and kind != "emote":
			holder.global_transform = hand * _lock_rel
		else:
			holder.global_transform = _game_hold()
		holder.visible = kind != "emote"

## Where the game puts the thing without the lock: turned with the trunk, at the right hand.
func _game_hold() -> Transform3D:
	var si := sk.find_bone("spine")
	var gs := sk.global_transform * sk.get_bone_global_pose(si)
	var w := gs * sk.get_bone_global_rest(si).affine_inverse() * Transform3D(Basis(), Vector3(-0.1, 1.2, -0.3))
	var hand := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("hand.R"))
	w.origin = hand.origin + hand.basis.y.normalized() * -0.05
	return w

## How the thing sits in the hand while just holding it (the game's way: at the hand, turned with the
## body) - kept relative to the hand, so a locked thing follows every turn of the hand.
func _find_lock_rel() -> bool:
	if holder == null or sk == null:
		return false
	var it := String(holder.get_meta("item"))
	var hold := Game.tweak_pose("hold/" + it, PlayerScript.hold_want(it, "", 0, 0.0))
	var keep := {}
	for bn in hold:
		var i := sk.find_bone(bn)
		if i >= 0:
			keep[i] = sk.get_bone_pose_rotation(i)
			var rest: Quaternion = sk.get_bone_rest(i).basis.get_rotation_quaternion()
			sk.set_bone_pose_rotation(i, rest * Quaternion.from_euler(hold[bn]))
	var hand := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("hand.R"))
	_lock_rel = hand.affine_inverse() * _game_hold()
	for i in keep:
		sk.set_bone_pose_rotation(i, keep[i])
	return true

## Eyes view: the gun's offset, its parts, the free hand (as the game shows it).
func _apply_fp() -> void:
	if holder == null:
		return
	var shield: bool = Game.ITEMS.get(item, {}).get("type", "") == "shield"
	var base: Vector3 = PlayerScript.VM_ONE_L if shield else PlayerScript.VM_R.get(item, PlayerScript.VM_ONE_R)
	var gx := AnimClips.xform(_ac, "zbran", t)
	holder.transform = Transform3D(gx.basis, base + gx.origin)
	if item_node:
		for pn in _parts():
			var n := item_node.find_child(pn, true, false) as Node3D
			if n == null:
				continue
			if not n.has_meta("rest"):
				n.set_meta("rest", n.transform)
			n.transform = (n.get_meta("rest") as Transform3D) * AnimClips.xform(_ac, pn, t)
			if pn == "Mag":
				var vis := true
				for e in _ac.get("udalosti", []):
					if float(e["t"]) <= t + 0.0001:
						if String(e["typ"]) == "skryt:Mag": vis = false
						elif String(e["typ"]) == "ukazat:Mag": vis = true
				n.visible = vis
	if hand_l:
		var on := AnimClips.hand_free(_ac, t) or (sel == "ruka" and not AnimClips.has_track(_ac, "ruka"))
		hand_l.visible = on
		var g2 := holder.get_node_or_null("GripTwo")
		var g1 := holder.get_node_or_null("GripOne")
		if g2 and g1:
			g2.visible = not on
			g1.visible = on
		var hv := _obj_value("ruka")
		hand_l.transform = Transform3D(Basis.from_euler(Vector3(float(hv[3]), float(hv[4]), float(hv[5])) * (PI / 180.0)), Vector3(float(hv[0]), float(hv[1]), float(hv[2])))
		var carry := AnimClips.last_event(_ac, "drzi", t)
		if carry != _carry:
			_carry = carry
			for c in hand_l.get_children():
				if String(c.name).begins_with("Carry"):
					c.queue_free()
			var cm := PlayerScript.make_carry(carry)
			if cm:
				hand_l.add_child(cm)

func _parts() -> Array:
	var out := []
	if item_node == null:
		return out
	for mi in item_node.find_children("*", "MeshInstance3D", true, false):
		var n := String(mi.name)
		if n.to_lower() != item.to_lower() and n in ["Slide", "Mag", "Barrel", "MinigunBarrels", "Warhead"]:
			out.append(n)
	return out

func _obj_value(o: String) -> Array:
	var v := AnimClips.sample(_ac, o, t)
	if v.size() >= 6:
		return v
	if o == "ruka":
		return [-0.14, -0.22, -0.34, 40.0, 0.0, 0.0]
	return [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

func _obj_node(o: String) -> Node3D:
	match o:
		"zbran": return holder
		"ruka": return hand_l
	return item_node.find_child(o, true, false) as Node3D if item_node else null

# ---- the frame ---------------------------------------------------------------------------------------
func _process(delta: float) -> void:
	var d := maxf(0.05, float(_ac.get("delka", 1.0)))
	if playing:
		var t0 := t
		t += delta * speed
		if t > d:
			t = fmod(t, d) if _ac.get("smycka", false) or kind == "body" else d
			if not (_ac.get("smycka", false) or kind == "body"):
				playing = false
			t0 = -0.01
		for e in AnimClips.events_between(_ac, t0, t):
			if String(e).begins_with("zvuk:"):
				Game.play_ui(self, String(e).substr(5), -6)
	t = clampf(t, 0.0, d)
	if kind == "eyes":
		_apply_fp()
	else:
		_apply_pose()
		var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
		cam.position = target + dir * dist
		cam.look_at(target, Vector3.UP)
		cam.fov = 45.0
	if playing:
		_sync_fields()
	time_lbl.text = "%.2f / %.2f s%s" % [t, d, "   ▶" if playing else ""]
	title_lbl.text = "%s%s" % [_title(), "  *neuloženo" if _dirty() else ("  (ze hry)" if _from_game else "")]
	tl.queue_redraw()
	_draw_overlay()

# ---- selection and values ------------------------------------------------------------------------
func _fill_sel_opt() -> void:
	var o := find_child("SelOpt", true, false) as OptionButton
	o.clear()
	if kind == "eyes":
		for e in [["zbran", "Zbraň (celá)"], ["ruka", "Levá ruka"]] + _parts().map(func(p): return [p, "Díl: " + p]):
			o.add_item(e[1])
			o.set_item_metadata(o.item_count - 1, e[0])
	else:
		for b in BONES:
			o.add_item(BONE_NAMES[b])
			o.set_item_metadata(o.item_count - 1, b)

func _select(o: String) -> void:
	sel = o
	EdUI.opt_select(find_child("SelOpt", true, false) as OptionButton, o)
	if kind != "eyes":
		_set_tool("posun" if o == "root" else "otaceni")
	_sync_ui()

func _row() -> String:
	return ROOT_POS if (kind != "eyes" and sel == "root") else sel

func _bone_value(b: String) -> Vector3:
	var v := AnimClips.sample(_ac, b, t)
	if v.size() >= 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	var p := _pose_now()
	if p.has(b):
		return (p[b] as Vector3) * (180.0 / PI)
	if sk and ap and ap.current_animation != "":
		var i := sk.find_bone(b)
		if i >= 0:
			var rq := sk.get_bone_rest(i).basis.get_rotation_quaternion()
			return Basis(rq.inverse() * sk.get_bone_pose_rotation(i)).get_euler() * (180.0 / PI)
	return Vector3.ZERO

## The value of the selected row now: [x, y, z] (a joint, degrees / the body's move, metres) or 6 values (eyes).
func _value() -> Array:
	if kind == "eyes":
		return _obj_value(sel)
	if sel == "root":
		var v := AnimClips.sample(_ac, ROOT_POS, t)
		return v if v.size() >= 3 else [0.0, 0.0, 0.0]
	var b := _bone_value(sel)
	return [b.x, b.y, b.z]

func _sync_ui() -> void:
	_updating = true
	len_spin.value = float(_ac.get("delka", 1.0))
	loop_chk.button_pressed = bool(_ac.get("smycka", false))
	lock_chk.button_pressed = lock
	lock_chk.disabled = holder == null or kind == "eyes"
	_updating = false
	_sync_fields()
	sel_lbl.text = (BONE_NAMES.get(sel, sel) if kind != "eyes" else {"zbran": "Zbraň (celá)", "ruka": "Levá ruka"}.get(sel, "Díl: " + sel))
	info_lbl.text = ("Upravená (%s)" % clip_id) if not _from_game else ("Původní ze hry – po uložení vznikne %s" % clip_id)
	# events that make sense here
	ev_opt.clear()
	for s in SOUNDS:
		ev_opt.add_item("zvuk: " + s)
		ev_opt.set_item_metadata(ev_opt.item_count - 1, "zvuk:" + s)
	if kind == "eyes":
		for c in CARRY:
			ev_opt.add_item("levá drží: " + (c if c != "" else "nic"))
			ev_opt.set_item_metadata(ev_opt.item_count - 1, "drzi:" + c)
		for e in [["leva:volna", "levá ruka pustí zbraň"], ["leva:zbran", "levá ruka zpět na zbraň"], ["skryt:Mag", "zásobník zmizí"],
				["ukazat:Mag", "zásobník zpět"], ["vyhodit:zasobnik", "zásobník vypadne"], ["vyhodit:nabojnice", "nábojnice vypadnou"]]:
			ev_opt.add_item(e[1])
			ev_opt.set_item_metadata(ev_opt.item_count - 1, e[0])

func _sync_fields() -> void:
	_updating = true
	var v := _value()
	var rot_on := kind == "eyes" or sel != "root"
	var pos_on := kind == "eyes" or sel == "root"
	for k in 3:
		(_f["r%d" % k] as SpinBox).editable = rot_on
		(_f["p%d" % k] as SpinBox).editable = pos_on
		if kind == "eyes":
			(_f["p%d" % k] as SpinBox).value = snappedf(float(v[k]) * 100.0, 0.01)
			(_f["r%d" % k] as SpinBox).value = snappedf(float(v[3 + k]), 0.1)
		elif sel == "root":
			(_f["p%d" % k] as SpinBox).value = snappedf(float(v[k]) * 100.0, 0.01)
			(_f["r%d" % k] as SpinBox).value = 0.0
		else:
			(_f["r%d" % k] as SpinBox).value = snappedf(float(v[k]), 0.1)
			(_f["p%d" % k] as SpinBox).value = 0.0
	var tr := AnimClips.track(_ac, _row())
	var ki := AnimClips.key_index(tr, t)
	ease_opt.disabled = ki < 0
	EdUI.opt_select(ease_opt, String(tr[ki].get("prechod", "")) if ki >= 0 else "")
	_updating = false

func _on_field(which: String, k: int, val: float) -> void:
	if _updating:
		return
	var v: Array = _value().duplicate()
	if kind == "eyes":
		if which == "p":
			v[k] = val / 100.0
		else:
			v[3 + k] = val
	elif sel == "root":
		if which != "p":
			return
		v[k] = val / 100.0
	else:
		if which != "r":
			return
		v[k] = val
	_push()
	_write(v)
	_changed()

## Writes the selected row's value as a key at the current time.
func _write(v: Array) -> void:
	var out := []
	for x in v:
		out.append(snappedf(float(x), 0.0001 if kind == "eyes" or sel == "root" else 0.1))
	AnimClips.set_key(_ac, _row(), t, out)

func _key_here() -> void:
	_push()
	_write(_value())
	_changed()
	status.text = "Klíč v %.2f s." % t

func _key_all() -> void:
	_push()
	if kind == "eyes":
		for o in ["zbran", "ruka"] + _parts():
			AnimClips.set_key(_ac, o, t, _obj_value(o))
	else:
		for b in BONES:
			if b == "root":
				continue
			var bv := _bone_value(b)
			AnimClips.set_key(_ac, b, t, [snappedf(bv.x, 0.1), snappedf(bv.y, 0.1), snappedf(bv.z, 0.1)])
	_changed()
	status.text = "Klíč všem v %.2f s." % t

func _delete_key() -> void:
	_push()
	if AnimClips.delete_key(_ac, _row(), t):
		status.text = "Klíč smazán."
	else:
		status.text = "Tady žádný klíč není (posuň čas na kosočtverec)."
	_changed()

func _reset_sel() -> void:
	_push()
	if kind == "eyes":
		_write([-0.14, -0.22, -0.34, 40.0, 0.0, 0.0] if sel == "ruka" else [0, 0, 0, 0, 0, 0])
	else:
		_write([0, 0, 0])
	_changed()

func _set_ease(k: String) -> void:
	if _updating:
		return
	var tr := AnimClips.track(_ac, _row())
	var ki := AnimClips.key_index(tr, t)
	if ki < 0:
		return
	_push()
	if k == "":
		tr[ki].erase("prechod")
	else:
		tr[ki]["prechod"] = k
	_changed()

func _copy_pose() -> void:
	_clip_pose = {}
	if kind == "eyes":
		for o in ["zbran", "ruka"] + _parts():
			_clip_pose[o] = _obj_value(o)
	else:
		for b in BONES:
			if b != "root":
				var bv := _bone_value(b)
				_clip_pose[b] = [bv.x, bv.y, bv.z]
	status.text = "Póza zkopírována (Ctrl+V ji vloží v jiném čase)."

func _paste_pose() -> void:
	if _clip_pose.is_empty():
		status.text = "Nejdřív zkopíruj pózu."
		return
	_push()
	for k in _clip_pose:
		AnimClips.set_key(_ac, k, t, _clip_pose[k])
	_changed()
	status.text = "Póza vložena v %.2f s." % t

func _mirror_pose() -> void:
	if kind == "eyes":
		return
	_push()
	var p := {}
	for b in BONES:
		if b != "root":
			var bv := _bone_value(b)
			p[b] = [bv.x, bv.y, bv.z]
	var m := AnimClips.mirrored(p)
	for b in m:
		AnimClips.set_key(_ac, b, t, m[b])
	_changed()
	status.text = "Póza zrcadlena (levá ↔ pravá)."

func _stretch_dialog() -> void:
	var d := ConfirmationDialog.new()
	d.title = "Natáhnout délku"
	var vb := VBoxContainer.new()
	var l := Label.new()
	l.text = "Nová délka (s) - klíče se posunou poměrně:"
	vb.add_child(l)
	var s := SpinBox.new()
	s.min_value = 0.1
	s.max_value = 20
	s.step = 0.05
	s.value = float(_ac.get("delka", 1.0))
	vb.add_child(s)
	d.add_child(vb)
	d.confirmed.connect(func():
		_push()
		var old := maxf(0.01, float(_ac.get("delka", 1.0)))
		var f: float = s.value / old
		for name in _ac.get("stopy", {}):
			for key in _ac["stopy"][name]:
				key["t"] = snappedf(float(key["t"]) * f, 0.01)
		for e in _ac.get("udalosti", []):
			e["t"] = snappedf(float(e["t"]) * f, 0.01)
		_ac["delka"] = s.value
		t *= f
		_changed()
		d.queue_free())
	d.canceled.connect(d.queue_free)
	add_child(d)
	d.popup_centered()

# ---- events ------------------------------------------------------------------------------------------
func _fill_events() -> void:
	ev_list.clear()
	for e in _ac.get("udalosti", []):
		ev_list.add_item("%.2f s  %s" % [float(e["t"]), String(e["typ"])])

func _add_event() -> void:
	if ev_opt.selected < 0:
		return
	_push()
	if not _ac.has("udalosti"):
		_ac["udalosti"] = []
	_ac["udalosti"].append({"t": snappedf(t, 0.01), "typ": String(ev_opt.get_item_metadata(ev_opt.selected))})
	(_ac["udalosti"] as Array).sort_custom(func(a, b): return float(a["t"]) < float(b["t"]))
	_changed()

func _delete_event() -> void:
	var s := ev_list.get_selected_items()
	if s.is_empty():
		return
	_push()
	(_ac["udalosti"] as Array).remove_at(s[0])
	_changed()

# ---- the 3D handles -----------------------------------------------------------------------------------
func _set_tool(m: String) -> void:
	tool = m
	for k in _tool_btns:
		(_tool_btns[k] as Button).button_pressed = k == m

func _scr(w: Vector3) -> Vector2:
	return cam.unproject_position(w) * (svc.size / Vector2(view.size))

func _vp(at: Vector2) -> Vector2:
	return at * (Vector2(view.size) / svc.size)

## The world transform of what is selected (a joint, the body, a thing in the eyes view).
func _sel_xf() -> Transform3D:
	if kind == "eyes":
		var n := _obj_node(sel)
		return n.global_transform if n else Transform3D()
	if sk == null:
		return Transform3D()
	var i := sk.find_bone(sel)
	if i < 0:
		return Transform3D()
	var g := sk.global_transform * sk.get_bone_global_pose(i)
	return g

func _axes() -> Array:
	if kind == "eyes":
		var b := cam.global_transform.basis
		if tool == "otaceni":
			var n := _obj_node(sel)
			if n:
				b = n.global_transform.basis
		return [b.x.normalized(), b.y.normalized(), b.z.normalized()]
	if sel == "root":
		var mb := model.global_transform.basis
		return [mb.x.normalized(), mb.y.normalized(), mb.z.normalized()]
	var g := _sel_xf().basis
	return [g.x.normalized(), g.y.normalized(), g.z.normalized()]

func _glen(o: Vector3) -> float:
	return 70.0 * ov.px(o)

func _handle_hit(m: Vector2) -> int:
	var o := _sel_xf().origin
	if cam.is_position_behind(o):
		return -1
	var axes := _axes()
	var l := _glen(o)
	var so := _scr(o)
	var best := -1
	var bd := 11.0
	for i in 3:
		var dd := INF
		if tool == "otaceni":
			var ring := EdUI.ring_points(o, axes[i], l * 0.9)
			for k in ring.size() - 1:
				dd = minf(dd, m.distance_to(Geometry2D.get_closest_point_to_segment(m, _scr(ring[k]), _scr(ring[k + 1]))))
		else:
			dd = m.distance_to(Geometry2D.get_closest_point_to_segment(m, so, _scr(o + axes[i] * l * 1.15)))
		if dd < bd:
			bd = dd
			best = i
	return best

func _joint_at(m: Vector2) -> String:
	if sk == null:
		return ""
	var best := ""
	var bd := 12.0
	for b in BONES:
		var i := sk.find_bone(b)
		if i < 0:
			continue
		var p := sk.global_transform * sk.get_bone_global_pose(i).origin
		var d := m.distance_to(_scr(p))
		if d < bd:
			bd = d
			best = b
	return best

func _pick_fp(m: Vector2) -> String:
	var p := _vp(m)
	var o := cam.project_ray_origin(p)
	var d := cam.project_ray_normal(p)
	var best := ""
	var bd := 1e9
	var cands := []
	if hand_l and hand_l.visible:
		for mi in hand_l.find_children("*", "MeshInstance3D", true, false):
			cands.append([mi, "ruka"])
	if item_node:
		var parts := _parts()
		for mi in item_node.find_children("*", "MeshInstance3D", true, false):
			cands.append([mi, String(mi.name) if String(mi.name) in parts else "zbran"])
	if holder:
		for c in holder.get_children():
			if c != item_node:
				for mi in (c as Node).find_children("*", "MeshInstance3D", true, false):
					cands.append([mi, "zbran"])
	for c in cands:
		var mm := c[0] as MeshInstance3D
		var inv := mm.global_transform.affine_inverse()
		var hit = mm.get_aabb().grow(0.005).intersects_ray(inv * o, (inv.basis * d).normalized())
		if hit != null:
			var dd: float = (mm.global_transform * (hit as Vector3)).distance_to(o)
			if dd < bd:
				bd = dd
				best = c[1]
	return best

func _view_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.pressed:
			get_viewport().gui_release_focus()
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed and kind != "eyes":
					dist = maxf(0.4, dist * 0.9)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed and kind != "eyes":
					dist = minf(12.0, dist * 1.1)
			MOUSE_BUTTON_RIGHT:
				_drag = ("pan" if mb.shift_pressed else "orbit") if mb.pressed else ""
			MOUSE_BUTTON_MIDDLE:
				_drag = "pan" if mb.pressed else ""
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					var h := _handle_hit(mb.position)
					if h >= 0:
						_start_handle(h, mb.position)
						return
					var j := _joint_at(mb.position) if kind != "eyes" else _pick_fp(mb.position)
					if j != "":
						_select(j)
						status.text = "Vybráno: %s - táhni za kruh (otáčení) nebo šipku (posun)." % sel_lbl.text
				else:
					if _drag == "handle":
						_changed()
					_drag = ""
					_drag_axis = -1
	elif ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		match _drag:
			"orbit":
				if kind != "eyes":
					yaw -= mm.relative.x * 0.008
					pitch = clampf(pitch + mm.relative.y * 0.008, -1.5, 1.5)
			"pan":
				if kind != "eyes":
					var b := cam.global_transform.basis
					var px := ov.px(target) * (Vector2(view.size) / svc.size).y
					target += (-b.x * mm.relative.x + b.y * mm.relative.y) * px
			"handle":
				_drag_handle(mm.position, mm.ctrl_pressed)
			"":
				_hover = _handle_hit(mm.position)

func _start_handle(ax: int, m: Vector2) -> void:
	_push()
	playing = false
	_drag = "handle"
	_drag_axis = ax
	_drag_from = m
	_drag_start = _sel_xf()
	_drag_val = _value().duplicate()
	if kind != "eyes" and sk and sel != "root":
		var i := sk.find_bone(sel)
		var pi := sk.get_bone_parent(i)
		_drag_parent = (sk.get_bone_global_pose(pi).basis if pi >= 0 else Basis())

func _drag_handle(m: Vector2, coarse: bool) -> void:
	var axes := _axes()
	var o := _drag_start.origin
	var ax: Vector3 = axes[_drag_axis]
	if tool == "otaceni":
		var so := _scr(o)
		var ang := wrapf((m - so).angle() - (_drag_from - so).angle(), -PI, PI)
		if ax.dot(cam.global_transform.basis.z) < 0.0:
			ang = -ang
		ang = -ang
		ang = snappedf(ang, deg_to_rad(15.0) if coarse else deg_to_rad(0.5))
		if kind == "eyes":
			var n := _obj_node(sel)
			if n == null:
				return
			var nw := Transform3D(Basis(ax, ang) * _drag_start.basis, _drag_start.origin)
			_write(_fp_value_from(sel, n, nw))
		else:
			# the turn in the world -> the joint's own turn (the skeleton may be mirrored)
			var skb := sk.global_transform.basis
			var r_sk := skb.inverse() * Basis(ax, ang) * skb
			var i := sk.find_bone(sel)
			var g0 := sk.global_transform.affine_inverse() * _drag_start
			var g_new := r_sk * g0.basis
			var local := _drag_parent.inverse() * g_new
			var rq := sk.get_bone_rest(i).basis.get_rotation_quaternion()
			var off := Basis(rq.inverse() * local.get_rotation_quaternion()).get_euler() * (180.0 / PI)
			_write([off.x, off.y, off.z])
		status.text = "Otočení %.1f°" % rad_to_deg(ang)
	else:
		var l := _glen(o)
		var sv := _scr(o + ax * l) - _scr(o)
		if sv.length() < 1.0:
			return
		var dw := (m - _drag_from).dot(sv.normalized()) * (l / sv.length())
		dw = snappedf(dw, 0.01 if coarse else 0.001)
		if kind == "eyes":
			var n2 := _obj_node(sel)
			if n2 == null:
				return
			var nw2 := Transform3D(_drag_start.basis, _drag_start.origin + ax * dw)
			_write(_fp_value_from(sel, n2, nw2))
		elif sel == "root":
			# the body's move: in the skeleton's space
			var d_sk := sk.global_transform.basis.inverse() * (ax * dw)
			_write([float(_drag_val[0]) + d_sk.x, float(_drag_val[1]) + d_sk.y, float(_drag_val[2]) + d_sk.z])
		status.text = "Posun %.1f cm" % (dw * 100.0)
	_sync_fields()

## Eyes view: a node's new world transform as its track's value.
func _fp_value_from(o: String, n: Node3D, w: Transform3D) -> Array:
	var local := n.get_parent_node_3d().global_transform.affine_inverse() * w
	var v := Transform3D()
	match o:
		"zbran":
			var shield: bool = Game.ITEMS.get(item, {}).get("type", "") == "shield"
			var base: Vector3 = PlayerScript.VM_ONE_L if shield else PlayerScript.VM_R.get(item, PlayerScript.VM_ONE_R)
			v = Transform3D(local.basis, local.origin - base)
		"ruka":
			v = local
		_:
			var rest: Transform3D = n.get_meta("rest") if n.has_meta("rest") else n.transform
			v = rest.affine_inverse() * local
	var e := v.basis.get_euler() * (180.0 / PI)
	return [v.origin.x, v.origin.y, v.origin.z, e.x, e.y, e.z]

func _unhandled_key_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed):
		return
	var k := ev as InputEventKey
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	var d := maxf(0.05, float(_ac.get("delka", 1.0)))
	var handled := true
	match k.keycode:
		KEY_SPACE: playing = not playing
		KEY_HOME: t = 0.0
		KEY_END: t = d
		KEY_COMMA: t = maxf(0.0, t - 1.0 / 30.0); playing = false
		KEY_PERIOD: t = minf(d, t + 1.0 / 30.0); playing = false
		KEY_K:
			if k.shift_pressed: _key_all()
			else: _key_here()
		KEY_DELETE: _delete_key()
		KEY_Z when k.ctrl_pressed: _undo_step()
		KEY_Y when k.ctrl_pressed: _redo_step()
		KEY_S when k.ctrl_pressed: _save()
		KEY_C when k.ctrl_pressed: _copy_pose()
		KEY_V when k.ctrl_pressed: _paste_pose()
		KEY_M: _mirror_pose()
		KEY_R: _set_tool("otaceni")
		KEY_G: _set_tool("posun")
		_: handled = false
	if handled:
		_sync_fields()
		get_viewport().set_input_as_handled()

func _draw_overlay() -> void:
	ov.clear()
	if sk and kind != "eyes":
		for b in BONES:
			var i := sk.find_bone(b)
			if i < 0:
				continue
			var p := sk.global_transform * sk.get_bone_global_pose(i).origin
			var pi := sk.get_bone_parent(i)
			if pi >= 0 and b != "hips":
				ov.line(sk.global_transform * sk.get_bone_global_pose(pi).origin, p, Color(1.0, 0.6, 0.15, 0.7), 2.0)
			var keyed: bool = AnimClips.has_track(_ac, b if b != "root" else ROOT_POS)
			var hl: bool = b == sel
			ov.dot(p, Color(0, 0, 0, 0.6), 13.0 if hl else 10.0)
			ov.dot(p, Color(1.0, 0.95, 0.3) if hl else (Color(1.0, 0.55, 0.1) if keyed else Color(0.85, 0.85, 0.85)), 10.0 if hl else 7.0)
	if (sk and kind != "eyes") or (kind == "eyes" and _obj_node(sel) != null):
		var o := _sel_xf().origin
		var axes := _axes()
		var l := _glen(o)
		for i in 3:
			var hot := i == _drag_axis or (_drag == "" and i == _hover)
			var col: Color = Color(1.0, 0.95, 0.4) if hot else EdUI.AXIS_COL[i]
			if tool == "otaceni":
				ov.ring(o, axes[i], l * 0.9, col, 4.0 if hot else 2.5)
			else:
				var tip: Vector3 = o + axes[i] * l
				ov.line(o, tip, col, 4.0 if hot else 3.0)
				var side: Vector3 = (axes[i] as Vector3).cross(cam.global_position - tip).normalized() * l * 0.08
				ov.tri(tip - side, tip + side, tip + axes[i] * l * 0.22, col)
	ov.flush()

# ---- the time line ------------------------------------------------------------------------------------
class Timeline:
	extends Control
	var ed
	const HEAD := 22.0
	const ROW := 18.0
	const LABEL := 150.0
	var _drag_key := -1.0
	var _drag_row := ""
	var _scrub := false
	var _scroll := 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		clip_contents = true

	func rows() -> Array:
		var out := ["*"]
		var tracks: Dictionary = ed._ac.get("stopy", {})
		var order: Array = []
		if ed.kind == "eyes":
			order = ["zbran", "ruka"] + ed._parts()
		else:
			order = ed.BONES.map(func(b): return b if b != "root" else ed.ROOT_POS)
		for r in order:
			if tracks.has(r) or r == ed._row():
				out.append(r)
		for r in tracks:
			if not r in out:
				out.append(r)
		out.append("udalosti")
		return out

	func name_of(r: String) -> String:
		match r:
			"*": return "Celá póza"
			"udalosti": return "Události"
			"zbran": return "Zbraň"
			"ruka": return "Levá ruka"
		if r == ed.ROOT_POS:
			return "Celé tělo (posun)"
		return ed.BONE_NAMES.get(r, r)

	func x_of(t: float) -> float:
		var d := maxf(0.05, float(ed._ac.get("delka", 1.0)))
		return LABEL + (size.x - LABEL - 12.0) * t / d

	func t_of(x: float) -> float:
		var d := maxf(0.05, float(ed._ac.get("delka", 1.0)))
		return clampf((x - LABEL) / maxf(1.0, size.x - LABEL - 12.0) * d, 0.0, d)

	func row_at(y: float) -> String:
		var rs := rows()
		var i := int((y - HEAD) / ROW) + _scroll
		return rs[i] if y >= HEAD and i >= 0 and i < rs.size() else ""

	func keys_of(r: String) -> Array:
		if r == "udalosti":
			return (ed._ac.get("udalosti", []) as Array).map(func(e): return float(e["t"]))
		if r == "*":
			var all := {}
			for n in ed._ac.get("stopy", {}):
				for k in ed._ac["stopy"][n]:
					all[snappedf(float(k["t"]), 0.01)] = true
			return all.keys()
		return AnimClips.track(ed._ac, r).map(func(k): return float(k["t"]))

	func key_at(r: String, x: float) -> float:
		for kt in keys_of(r):
			if absf(x_of(kt) - x) < 6.0:
				return kt
		return -1.0

	func _draw() -> void:
		var font := get_theme_default_font()
		var fs := 12
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.08, 0.09))
		var d := maxf(0.05, float(ed._ac.get("delka", 1.0)))
		# the ruler
		var stp := 0.1 if d <= 2.0 else (0.25 if d <= 5.0 else 0.5)
		var tt := 0.0
		while tt <= d + 0.0001:
			var x := x_of(tt)
			var major := absf(fmod(tt + 0.0001, stp * 5.0)) < 0.002
			draw_line(Vector2(x, HEAD - (8 if major else 4)), Vector2(x, size.y), Color(0.2, 0.23, 0.26) if not major else Color(0.3, 0.34, 0.38), 1.0)
			if major:
				draw_string(font, Vector2(x + 2, 12), "%.1f" % tt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, EdUI.DIM)
			tt += stp
		var rs := rows()
		for i in range(_scroll, rs.size()):
			var y := HEAD + (i - _scroll) * ROW
			if y > size.y:
				break
			var r: String = rs[i]
			var selrow: bool = r == ed._row()
			if selrow:
				draw_rect(Rect2(0, y, size.x, ROW), Color(0.12, 0.25, 0.28, 0.6))
			draw_string(font, Vector2(6, y + 13), name_of(r), HORIZONTAL_ALIGNMENT_LEFT, LABEL - 10, fs, EdUI.AMBER if r in ["*", "udalosti"] else (EdUI.ACCENT if selrow else EdUI.TEXT))
			draw_line(Vector2(0, y + ROW), Vector2(size.x, y + ROW), Color(0.15, 0.17, 0.19), 1.0)
			for kt in keys_of(r):
				var x := x_of(kt)
				var c := Vector2(x, y + ROW * 0.5)
				var col := Color(1.0, 0.55, 0.12) if r != "udalosti" else Color(0.4, 0.85, 1.0)
				if absf(kt - ed.t) < 0.011:
					col = Color(1.0, 0.95, 0.4)
				var s := 5.5
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)]), col)
		# the time cursor
		var cx := x_of(ed.t)
		draw_line(Vector2(cx, 0), Vector2(cx, size.y), Color(1.0, 0.3, 0.25), 2.0)
		draw_rect(Rect2(cx - 4, 0, 8, 8), Color(1.0, 0.3, 0.25))

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton:
			var mb := e as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
				_scroll = maxi(0, _scroll - 1)
				queue_redraw()
				return
			if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
				_scroll = mini(maxi(0, rows().size() - 3), _scroll + 1)
				queue_redraw()
				return
			var r := row_at(mb.position.y)
			if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
				var kt := key_at(r, mb.position.x)
				if kt >= 0.0:
					ed._push()
					if r == "udalosti":
						var evs: Array = ed._ac["udalosti"]
						for i in evs.size():
							if absf(float(evs[i]["t"]) - kt) < 0.011:
								evs.remove_at(i)
								break
					elif r == "*":
						for n in ed._ac.get("stopy", {}).keys():
							AnimClips.delete_key(ed._ac, n, kt)
					else:
						AnimClips.delete_key(ed._ac, r, kt)
					ed._changed()
				return
			if mb.button_index != MOUSE_BUTTON_LEFT:
				return
			if mb.pressed:
				if mb.double_click and r != "" and r != "udalosti":
					ed.t = t_of(mb.position.x)
					if r != "*":
						ed._select(r if r != ed.ROOT_POS else "root")
						ed._key_here()
					else:
						ed._key_all()
					return
				var kt2 := key_at(r, mb.position.x) if r != "" else -1.0
				if kt2 >= 0.0:
					ed.t = kt2
					if r != "*" and r != "udalosti":
						ed._select(r if r != ed.ROOT_POS else "root")
					_drag_key = kt2
					_drag_row = r
					ed._push()
				else:
					_scrub = true
					ed.playing = false
					ed.t = t_of(mb.position.x)
					if r != "" and r != "*" and r != "udalosti":
						ed._select(r if r != ed.ROOT_POS else "root")
				ed._sync_fields()
			else:
				if _drag_key >= 0.0:
					ed._changed()
				_drag_key = -1.0
				_scrub = false
		elif e is InputEventMouseMotion:
			var mm := e as InputEventMouseMotion
			if _scrub:
				ed.t = t_of(mm.position.x)
				ed._sync_fields()
			elif _drag_key >= 0.0:
				var nt := snappedf(t_of(mm.position.x), 0.01)
				if absf(nt - _drag_key) < 0.005:
					return
				if _drag_row == "udalosti":
					for ev in ed._ac.get("udalosti", []):
						if absf(float(ev["t"]) - _drag_key) < 0.011:
							ev["t"] = nt
							break
					_drag_key = nt
				elif _drag_row == "*":
					var free := true
					for n in ed._ac.get("stopy", {}):
						var tr: Array = ed._ac["stopy"][n]
						if AnimClips.key_index(tr, _drag_key) >= 0 and AnimClips.key_index(tr, nt) >= 0:
							free = false
					if free:
						for n in ed._ac.get("stopy", {}):
							AnimClips.move_key(ed._ac, n, _drag_key, nt)
						_drag_key = nt
				else:
					_drag_key = AnimClips.move_key(ed._ac, _drag_row, _drag_key, nt)
				ed.t = _drag_key
				ed._sync_fields()

# ---- tests ---------------------------------------------------------------------------------------
## The editor's tools on real clips (nothing is saved): a body movement read from the model, a joint
## turned by its ring (key written by itself), a key moved, the lock (the knife turns with the hand),
## the eyes view (the gun moved by its arrow).
func _selftest() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	# a real click on the left knee (through the window, as the mouse does it)
	playing = false
	t = 0.0
	await get_tree().process_frame
	var kp := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("shin.L")).origin
	var at := svc.get_global_transform() * _scr(kp)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		get_viewport().push_input(ev)
		await get_tree().process_frame
	var clicked := sel == "shin.L"
	var keys0 := AnimClips.track(_ac, "thigh.L").size()
	var imported := not _from_game or keys0 > 3
	# turn the right elbow by its first ring at 0.3 s
	playing = false
	t = 0.3
	_select("forearm.R")
	await get_tree().process_frame
	var v0: Array = _value().duplicate()
	var o := _sel_xf().origin
	var so := _scr(o)
	var ring := EdUI.ring_points(o, _axes()[0], _glen(o) * 0.9)
	_start_handle(0, _scr(ring[0]))
	_drag_handle(_scr(ring[10]), false)
	_changed()
	var v1 := _value()
	var turned := absf(float(v1[0]) - float(v0[0])) + absf(float(v1[1]) - float(v0[1])) + absf(float(v1[2]) - float(v0[2])) > 20.0
	var keyed := AnimClips.key_index(AnimClips.track(_ac, "forearm.R"), 0.3) >= 0
	# a key moved in time
	var moved_to := AnimClips.move_key(_ac, "forearm.R", 0.3, 0.5)
	# the knife in a blow: locked, it turns with the hand
	_open("hand", "strike", "knife")
	await get_tree().process_frame
	t = 0.0
	_apply_pose()
	var q0 := item_node.global_transform.basis.get_rotation_quaternion() if item_node else Quaternion()
	t = 0.2
	_apply_pose()
	var q1 := item_node.global_transform.basis.get_rotation_quaternion() if item_node else Quaternion()
	var follows := q0.angle_to(q1) > 0.2
	# the eyes view: the gun moved along its arrow
	_open("eyes", "reload", "pistol")
	await get_tree().process_frame
	_select("zbran")
	_set_tool("posun")
	t = 0.4
	_apply_fp()
	var g0 := holder.position
	var oo := _sel_xf().origin
	_start_handle(1, _scr(oo))
	_drag_handle(_scr(oo) + Vector2(0, -60), false)
	_changed()
	_apply_fp()
	var fp_moved := holder.position.distance_to(g0) > 0.01
	get_viewport().get_texture().get_image().save_png("user://anim_fp.png")
	print("RESULT animator click %s imported %s turned %s keyed %s moved %s follows %s fp %s" % [clicked, imported, turned, keyed, absf(moved_to - 0.5) < 0.001, follows, fp_moved])
	get_tree().quit()

## Pictures of the editor: user://anim_<n>.png
func _shots() -> void:
	var list := [["body", "walk", "vse", 0.35], ["hand", "strike", "knife", 0.2], ["eyes", "reload", "pistol", 0.5], ["body", "prone_crawl", "vse", 0.3]]
	for i in list.size():
		var e: Array = list[i]
		_open(e[0], e[1], e[2])
		playing = false
		t = float(e[3])
		_select("forearm.R" if e[0] != "eyes" else "zbran")
		for f in 6:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("user://anim_%d.png" % i)
	print("RESULT animatorshots %d" % list.size())
	get_tree().quit()
