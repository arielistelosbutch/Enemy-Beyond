extends Control
## Modelář 2 (0.52, after the Svitky Světlenu editor): every model of the game is made of blocks,
## cylinders and balls; here Ari picks one or many, moves, turns and stretches them with handles
## (arrows, rings, squares) or by numbers, copies, mirrors, paints, adds new blocks and saves.
## Changes go to modely/<model>.json and the game uses them at once (ModelMods).
##
## Mouse: left click = select (Shift/Ctrl = add or take away), left drag on empty space = select
## everything in the rectangle, drag a selected block = move it on the screen, drag a handle = move /
## turn / stretch along that axis (Ctrl = coarse steps, Shift on an arrow = drag a copy), the white dot
## in the middle = move freely. Right drag = turn the view, middle drag (or Shift + right) = pan,
## wheel = zoom. Keys: G / R / S tools, Ctrl+A all, Esc nothing, Ctrl+D copy, Ctrl+C / Ctrl+V,
## M mirror copy, Del delete, F look at the selection, 1 / 3 / 7 front / side / top, arrows nudge,
## Ctrl+Z / Ctrl+Y undo / redo, Ctrl+S save.

const AlienScript := preload("res://scripts/alien.gd")
const PALETTE := [[0.08, 0.08, 0.08], [0.22, 0.22, 0.23], [0.45, 0.46, 0.48], [0.75, 0.76, 0.78], [0.95, 0.95, 0.93],
	[0.30, 0.17, 0.08], [0.55, 0.36, 0.18], [0.24, 0.27, 0.16], [0.42, 0.45, 0.28], [0.62, 0.52, 0.34],
	[0.55, 0.09, 0.07], [0.85, 0.55, 0.10], [0.95, 0.85, 0.30], [0.16, 0.28, 0.55], [0.35, 0.86, 0.96],
	[0.85, 0.25, 1.0], [0.20, 0.17, 0.22], [0.62, 0.47, 0.20]]
const NAMES := {"merc": "Voják", "heli": "Vrtulník Čáp", "dropship": "Kondor", "sokol": "Stíhačka Sokol", "cow": "Kráva",
	"civ_a": "Civilista A", "civ_b": "Civilista B", "mozek": "Velký mozek", "ufo_g_scout": "UFO průzkumník (přistálé)",
	"ufo_g_raider": "UFO nájezdník (přistálé)", "ufo_g_harvester": "UFO sklízeč (přistálé)", "ufo_scout": "UFO průzkumník (let)",
	"ufo_raider": "UFO nájezdník (let)", "ufo_harvester": "UFO sklízeč (let)",
	"ufo_supply": "UFO zásobovací loď (let)", "ufo_battleship": "UFO bitevní loď (let)",
	"jestrab": "Stíhačka Jestřáb", "pelikan": "Transportér Pelikán"}
const TOOLS := {"posun": "Posun (G)", "otaceni": "Otáčení (R)", "velikost": "Velikost (S)"}
const DOT := 3

var model_name := ""
var model: Node3D
var work := {}               # the mods being edited (also live in Game.model_mods)
var sel := ""                # the active part ("Piece:n" or "new:k")
var sels: Array = []         # all selected parts
var mode := "posun"
var space := "model"         # handle axes: "model" (the model's own) or "dil" (the active part's)
var yaw := PI + 0.6
var pitch := -0.25
var dist := 1.5
var target := Vector3.ZERO
var extent := 1.0
var dirty := false
var _undo := []
var _redo := []
var _clip := []              # copied parts (as new blocks)

var svc: SubViewportContainer
var view: SubViewport
var world: Node3D
var cam: Camera3D
var ov: EdUI.Overlay
var _rect: EdUI.SelRect
var _grid: MeshInstance3D

# mouse
var _drag := ""              # "", "orbit", "pan", "gizmo", "move", "rect", "click"
var _drag_axis := -1
var _drag_from := Vector2.ZERO
var _drag_start := {}        # part id -> world transform at the start of the drag
var _drag_pivot := Vector3.ZERO
var _drag_dir := Vector2.ZERO
var _drag_scale := 0.0
var _drag_plane := Plane()
var _drag_hit0 := Vector3.ZERO
var _hover := -1

# panel
var model_list: ItemList
var model_filter: LineEdit
var part_list: ItemList
var _list_ids: Array = []
var _list_pos := {}          # part id -> row in the parts list
var _list_hl: Array = []     # rows drawn as the active part
var _plist: Array = []       # every part: [mesh instance, part dict] (rebuilt when the meshes are)
var _idx := {}               # part id -> [mesh instance, part dict]
var _model_ids: Array = []
var title_lbl: Label
var status: Label
var hint: Label
var _tool_btns := {}
var _f := {}                 # the number fields
var _updating := false
var _color_btn: ColorPickerButton
var _space_btn: Button
var _scl_lbl: Label

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
	EdUI.tabs(root, "models")
	var main := HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 6)
	root.add_child(main)
	_build_left(main)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(mid)
	_build_toolbar(mid)
	var v := EdUI.view3d(mid)
	svc = v[0]
	view = v[1]
	world = v[2]
	cam = v[3]
	svc.gui_input.connect(_view_input)
	_rect = EdUI.SelRect.new()
	svc.add_child(_rect)
	ov = EdUI.Overlay.new(cam, view)
	world.add_child(ov)
	_grid = EdUI.grid3d(world, 3.0)
	_build_right(main)
	var foot := EdUI.row(root, 10)
	status = EdUI.lbl(foot, "", EdUI.AMBER)
	status.custom_minimum_size = Vector2(320, 0)
	hint = EdUI.lbl(foot, "", EdUI.DIM, 12, true)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.custom_minimum_size = Vector2(200, 0)
	_show_hint()
	_fill_models()
	var first := "rifle"
	if Game.cmd_arg("open", "") != "":
		first = Game.cmd_arg("open", "")
	_load_model(first if _model_ids.has(first) else String(_model_ids[0]))
	if Game.autotest() == "modeler":
		_selftest.call_deferred()
	if Game.autotest() == "modclick":
		_clicktest.call_deferred()
	if Game.autotest() == "modspeed":
		_speedtest.call_deferred()

# ---- the panels ------------------------------------------------------------------------------------
func _build_left(parent: Node) -> void:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(250, 0)
	box.add_theme_constant_override("separation", 6)
	parent.add_child(box)
	var p1 := PanelContainer.new()
	p1.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(p1)
	var v1 := VBoxContainer.new()
	p1.add_child(v1)
	EdUI.head(v1, "Model")
	model_filter = LineEdit.new()
	model_filter.placeholder_text = "hledat model…"
	model_filter.text_changed.connect(func(_t): _fill_models())
	v1.add_child(model_filter)
	model_list = ItemList.new()
	model_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	model_list.item_selected.connect(func(i):
		var id := String(model_list.get_item_metadata(i))
		if id == model_name:
			return
		if dirty:
			EdUI.ask(self, "Model %s má neuložené změny. Zahodit je?" % model_name, func(): _load_model(id), "Zahodit")
		else:
			_load_model(id))
	v1.add_child(model_list)
	var p2 := PanelContainer.new()
	p2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(p2)
	var v2 := VBoxContainer.new()
	p2.add_child(v2)
	EdUI.head(v2, "Díly modelu (Ctrl / Shift = více)")
	part_list = ItemList.new()
	part_list.select_mode = ItemList.SELECT_MULTI
	part_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	part_list.multi_selected.connect(func(_i, _s): _from_list())
	part_list.item_selected.connect(func(_i): _from_list())
	v2.add_child(part_list)

func _build_toolbar(parent: Node) -> void:
	var bar := HFlowContainer.new()      # wraps onto a second line in a small window
	bar.add_theme_constant_override("h_separation", 4)
	bar.add_theme_constant_override("v_separation", 4)
	parent.add_child(bar)
	for m in TOOLS:
		var mm: String = m
		_tool_btns[m] = EdUI.btn(bar, TOOLS[m], func(): _set_mode(mm), "", true)
	_space_btn = EdUI.btn(bar, "Osy: modelu", func():
		space = "dil" if space == "model" else "model"
		_space_btn.text = "Osy: dílu" if space == "dil" else "Osy: modelu", "Ruční úchyty podle os celého modelu, nebo podle natočení vybraného dílu")
	EdUI.lbl(bar, "  ")
	EdUI.btn(bar, "Zepředu (1)", func(): _view_from(0), "Pohled zepředu")
	EdUI.btn(bar, "Z boku (3)", func(): _view_from(1), "Pohled z boku")
	EdUI.btn(bar, "Shora (7)", func(): _view_from(2), "Pohled shora")
	EdUI.btn(bar, "Zaměřit (F)", _focus, "Přiblížit na výběr")
	EdUI.check(bar, "Mřížka", true, func(on): _grid.visible = on)
	title_lbl = EdUI.lbl(bar, "", EdUI.AMBER)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _build_right(parent: Node) -> void:
	var outer := VBoxContainer.new()
	outer.custom_minimum_size = Vector2(300, 0)
	parent.add_child(outer)
	var v := EdUI.panel(outer)
	EdUI.head(v, "Soubor")
	var r0 := EdUI.grid(v, 2)
	EdUI.btn(r0, "Uložit (Ctrl+S)", _save).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	EdUI.btn(r0, "Vrátit vše", func(): EdUI.ask(self, "Vrátit celý model do původní podoby?", _reset_all, "Vrátit")).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	EdUI.btn(r0, "Zpět (Ctrl+Z)", _undo_step).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	EdUI.btn(r0, "Znovu (Ctrl+Y)", _redo_step).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	EdUI.head(v, "Výběr")
	var r1 := EdUI.grid(v, 2)
	EdUI.btn(r1, "Vybrat vše (Ctrl+A)", _select_all).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	EdUI.btn(r1, "Nic (Esc)", func(): _set_sel([])).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	EdUI.btn(r1, "Stejná barva", _select_same_color, "Vybere všechny díly se stejnou barvou jako aktivní díl").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	EdUI.btn(r1, "Stejný kloub", _select_same_bone, "Vybere všechny díly, které visí na stejné kosti").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	EdUI.head(v, "Aktivní díl (čísla)")
	EdUI.lbl(v, "Změna platí pro celý výběr (o stejný kus).", EdUI.DIM, 12, true)
	for grp in [["pos", "Poloha (cm)", 0.1], ["rot", "Natočení (°)", 1.0], ["scl", "Velikost (%)", 1.0]]:
		var gl := EdUI.lbl(v, grp[1], EdUI.DIM, 12)
		if grp[0] == "scl":
			_scl_lbl = gl
		var g := EdUI.row(v, 3)
		for k in 3:
			var key := "%s%d" % [grp[0], k]
			var kk: String = key
			var s := EdUI.spin(g, -100000, 100000, grp[2], func(val): _on_field(kk, val))
			s.prefix = ["X", "Y", "Z"][k]
			s.add_theme_color_override("font_color", EdUI.AXIS_COL[k])
			_f[key] = s
	EdUI.head(v, "Barva")
	var pg := EdUI.grid(v, 6)
	for c in PALETTE:
		var col: Array = c
		var b := Button.new()
		b.custom_minimum_size = Vector2(36, 22)
		b.focus_mode = Control.FOCUS_NONE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(col[0], col[1], col[2])
		sb.set_corner_radius_all(3)
		sb.border_color = Color(0, 0, 0)
		sb.set_border_width_all(1)
		b.add_theme_stylebox_override("normal", sb)
		var sh := sb.duplicate()
		sh.border_color = EdUI.ACCENT
		sh.set_border_width_all(2)
		b.add_theme_stylebox_override("hover", sh)
		b.add_theme_stylebox_override("pressed", sh)
		b.pressed.connect(func(): _paint(col))
		pg.add_child(b)
	var pr := EdUI.row(v)
	_color_btn = ColorPickerButton.new()
	_color_btn.custom_minimum_size = Vector2(60, 26)
	_color_btn.edit_alpha = false
	_color_btn.color_changed.connect(func(c): _paint([c.r, c.g, c.b]))
	pr.add_child(_color_btn)
	EdUI.btn(pr, "Původní barva", func(): _paint(null))
	EdUI.head(v, "Přidat a upravit")
	var r2 := EdUI.grid(v, 3)
	EdUI.btn(r2, "+ Kostka", func(): _add("box")).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	EdUI.btn(r2, "+ Válec", func(): _add("cyl")).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	EdUI.btn(r2, "+ Koule", func(): _add("ball")).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var r3 := EdUI.grid(v, 2)
	for e in [["Kopie (Ctrl+D)", _duplicate_sel, "Kopie vybraných dílů kousek vedle"], ["Zrcadlit (M)", _mirror_sel, "Zrcadlová kopie na druhou stranu modelu"],
			["Kopírovat (Ctrl+C)", _copy, ""], ["Vložit (Ctrl+V)", _paste, ""],
			["Převrátit X", func(): _flip(0), "Převrátí výběr na místě"], ["Převrátit Z", func(): _flip(2), "Převrátí výběr na místě"],
			["Smazat (Del)", _delete_sel, ""], ["Vrátit díl", _reset_sel, "Vrátí původní díly do původní podoby"]]:
		EdUI.btn(r3, e[0], e[1], e[2]).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	EdUI.head(v, "Jemné posunutí (šipky)")
	var r4 := EdUI.grid(v, 3)
	for e in [["◄ X−", Vector3(-1, 0, 0)], ["▲ Y+", Vector3(0, 1, 0)], ["► X+", Vector3(1, 0, 0)],
			["● Z+", Vector3(0, 0, 1)], ["▼ Y−", Vector3(0, -1, 0)], ["○ Z−", Vector3(0, 0, -1)]]:
		var d: Vector3 = e[1]
		EdUI.btn(r4, e[0], func(): _nudge(d, 1.0)).size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _fill_models() -> void:
	model_list.clear()
	_model_ids.clear()
	var f := model_filter.text.strip_edges().to_lower()
	for e in _model_list():
		if f != "" and String(e[1]).to_lower().find(f) < 0 and String(e[0]).find(f) < 0:
			continue
		var mark := " •" if Game.model_mods.has(e[0]) and not (Game.model_mods[e[0]].get("parts", {}).is_empty() and Game.model_mods[e[0]].get("new", []).is_empty()) else ""
		model_list.add_item(String(e[1]) + mark)
		model_list.set_item_metadata(model_list.item_count - 1, e[0])
		_model_ids.append(e[0])
		if e[0] == model_name:
			model_list.select(model_list.item_count - 1)

func _model_list() -> Array:
	var out := []
	var seen := {}
	for id in Game.ITEMS:
		if ResourceLoader.exists("res://assets/models/%s.glb" % id):
			out.append([id, "Věc: " + String(Game.ITEMS[id]["name"])])
			seen[id] = true
	out.append(["merc", "Voják"])
	seen["merc"] = true
	for r in AlienScript.RACES:
		var m := String(AlienScript.RACES[r].get("model", ""))
		if m != "" and not seen.has(m) and ResourceLoader.exists("res://assets/models/%s.glb" % m):
			out.append([m, "Vetřelec: " + String(AlienScript.RACES[r]["name"])])
			seen[m] = true
	var rest := []
	for f in DirAccess.get_files_at("res://assets/models"):
		var n := f.trim_suffix(".import").trim_suffix(".glb")
		if (f.ends_with(".glb") or f.ends_with(".glb.import")) and not seen.has(n):
			seen[n] = true
			rest.append([n, NAMES.get(n, n.replace("_", " "))])
	rest.sort_custom(func(a, b): return String(a[1]) < String(b[1]))
	return out + rest

# ---- the model ----------------------------------------------------------------------------------
func _load_model(n: String) -> void:
	model_name = n
	work = Game.model_mods.get(n, {}).duplicate(true)
	if not work.has("parts"):
		work["parts"] = {}
	if not work.has("new"):
		work["new"] = []
	_undo.clear()
	_redo.clear()
	dirty = false
	sel = ""
	sels = []
	if model:
		model.queue_free()
	model = (load("res://assets/models/%s.glb" % n) as PackedScene).instantiate()
	if n == "merc":
		model.scale = Vector3(-1, 1, 1)     # as in the game: the gun hand on the right
	world.add_child(model)
	var ap := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap:
		ap.stop()
	_refresh_meshes(true)
	var box := _world_box()
	extent = maxf(box.size.length(), 0.05)
	target = box.get_center()
	dist = extent * 1.25 + 0.15
	_grid.scale = Vector3.ONE * clampf(extent / 2.0, 0.05, 6.0)
	_grid.position = Vector3(target.x, box.position.y, target.z)
	_fill_models()
	_after_change()
	status.text = "Model: %s (%d dílů). Klikni na díl, nebo táhni obdélník." % [NAMES.get(n, n), _parts().size()]

## The meshes again from the mods (no new instance: fast enough while dragging).
func _refresh_meshes(all := false, only: Array = []) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		if not only.is_empty() and not mi in only:
			continue
		var touched := all or mi.has_meta("eb_src")
		if not touched:
			var piece := String(mi.name)
			for k in work["parts"]:
				if String(k).begins_with(piece + ":"):
					touched = true
					break
			for np in work["new"]:
				if String(np.get("piece", "")) == piece:
					touched = true
		if touched:
			ModelMods.rebuild(mi, work)
			Game._restyle(mi)
	if model_name == "merc":
		Game.apply_look(model, Game.merc.get("look", {}))
	_reindex()

func _world_box() -> AABB:
	var box := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		if not mi.visible:
			continue
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

## Every part: [mesh instance, part dict] in the order they were built.
func _parts() -> Array:
	return _plist

## The list of parts and the look-up by id, again after the meshes changed (the model may have
## thousands of parts: everything else asks this index instead of going through them all).
func _reindex() -> void:
	_plist = []
	_idx = {}
	if model == null:
		return
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		if not mi.visible:
			continue
		for p in mi.get_meta("eb_parts", []):
			var e := [mi, p]
			_plist.append(e)
			_idx[String(p["id"])] = e

func _find(id: String) -> Array:
	return _idx.get(id, [])

func _mesh_of(id: String) -> MeshInstance3D:
	var e := _find(id)
	return e[0] if not e.is_empty() else null

## An original part's block of the source mesh: {center, box} (before any change).
func _island(id: String) -> Dictionary:
	var mi := _mesh_of(id)
	if mi == null or id.begins_with("new:"):
		return {}
	var src: Mesh = mi.get_meta("eb_src") if mi.has_meta("eb_src") else mi.mesh
	var isl := ModelMods.islands(src)
	var i := int(id.get_slice(":", 1))
	return isl[i] if i < isl.size() else {}

func _entry(id: String, make := true) -> Dictionary:
	if id.begins_with("new:"):
		var i := int(id.substr(4))
		return work["new"][i] if i < work["new"].size() else {}
	if not work["parts"].has(id):
		if not make:
			return {}
		work["parts"][id] = {}
	return work["parts"][id]

func _xf_of(id: String) -> Array:
	var en := _entry(id, false)
	return en.get("xf", ModelMods.IDENT) if not en.is_empty() else ModelMods.IDENT

## The part's transform in its mesh's space (a unit block for new parts, the original block for old ones).
func _mesh_xf(id: String) -> Transform3D:
	var xf := _xf_of(id)
	var bas := ModelMods.xf_basis(xf)
	if id.begins_with("new:"):
		return Transform3D(bas, ModelMods.xf_pos(xf))
	var c: Vector3 = _island(id).get("center", Vector3.ZERO)
	return Transform3D(bas, c + ModelMods.xf_pos(xf) - bas * c)

func _world_xf(id: String) -> Transform3D:
	var mi := _mesh_of(id)
	if mi == null:
		return Transform3D()
	return mi.global_transform * _mesh_xf(id)

## Writes a part's transform from one in its mesh's space (rotation and scale taken apart again).
func _set_mesh_xf(id: String, t: Transform3D) -> void:
	var b := t.basis
	var s := Vector3(b.x.length(), b.y.length(), b.z.length())
	var r := Basis(b.x / maxf(s.x, 1e-6), b.y / maxf(s.y, 1e-6), b.z / maxf(s.z, 1e-6)).orthonormalized()
	var e := r.get_euler() * (180.0 / PI)
	var pos := t.origin
	if not id.begins_with("new:"):
		var c: Vector3 = _island(id).get("center", Vector3.ZERO)
		pos = t.origin + b * c - c
	var en := _entry(id)
	en["xf"] = [snappedf(pos.x, 0.0001), snappedf(pos.y, 0.0001), snappedf(pos.z, 0.0001),
		snappedf(e.x, 0.01), snappedf(e.y, 0.01), snappedf(e.z, 0.01),
		snappedf(s.x, 0.0001), snappedf(s.y, 0.0001), snappedf(s.z, 0.0001)]

func _set_world_xf(id: String, w: Transform3D) -> void:
	var mi := _mesh_of(id)
	if mi:
		_set_mesh_xf(id, mi.global_transform.affine_inverse() * w)

## The middle of the part in the world (the middle of its block).
func _center_of(id: String) -> Vector3:
	if id.begins_with("new:"):
		return _world_xf(id).origin
	var isl := _island(id)
	if isl.is_empty():
		return Vector3.ZERO
	return _world_xf(id) * (isl["box"] as AABB).get_center()

## The eight corners of the part's block in the world.
func _corners(id: String) -> Array:
	var w := _world_xf(id)
	var bb := AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
	if not id.begins_with("new:"):
		bb = _island(id).get("box", bb)
	var out := []
	for k in 8:
		out.append(w * bb.get_endpoint(k))
	return out

# ---- undo -------------------------------------------------------------------------------------------
func _push() -> void:
	_redo.clear()
	_undo.append(work.duplicate(true))
	if _undo.size() > 120:
		_undo.pop_front()
	dirty = true

func _undo_step() -> void:
	if _undo.is_empty():
		status.text = "Není co vracet."
		return
	_redo.append(work.duplicate(true))
	work = _undo.pop_back()
	_commit()
	status.text = "Krok zpět."

func _redo_step() -> void:
	if _redo.is_empty():
		status.text = "Není co vrátit dopředu."
		return
	_undo.append(work.duplicate(true))
	work = _redo.pop_back()
	_commit()
	status.text = "Krok znovu."

## The change is done: the game sees it, the view and the lists follow.
func _commit(only: Array = []) -> void:
	Game.model_mods[model_name] = work
	_refresh_meshes(false, only)
	sels = sels.filter(func(x): return not _find(x).is_empty())
	if not sel in sels:
		sel = sels[-1] if not sels.is_empty() else ""
	# only moved (the same parts): the list stays, just the selection in it
	_after_change(only.is_empty())

## @a full: the parts may have changed (fill the list again); otherwise only the selection did.
func _after_change(full := true) -> void:
	if full or _list_ids.size() != _plist.size():
		_fill_parts()
	else:
		_sync_list()
	_refresh_fields()
	title_lbl.text = "%s%s   ·   vybráno %d" % [NAMES.get(model_name, model_name), " *neuloženo" if dirty else "", sels.size()]

# ---- selection --------------------------------------------------------------------------------------
func _set_sel(ids: Array, active := "") -> void:
	sels = []
	for i in ids:
		if not i in sels:
			sels.append(i)
	sel = active if active != "" else (sels[-1] if not sels.is_empty() else "")
	if sel != "" and not sel in sels:
		sels.append(sel)
	_after_change(false)

func _toggle(id: String) -> void:
	if id in sels:
		sels.erase(id)
		_set_sel(sels)
	else:
		sels.append(id)
		_set_sel(sels, id)

func _select_all() -> void:
	_set_sel(_parts().map(func(e): return String(e[1]["id"])))
	status.text = "Vybráno vše (%d dílů)." % sels.size()

func _select_same_color() -> void:
	if sel == "":
		return
	var want = _color_of(sel)
	var out := []
	for e in _parts():
		if _color_of(String(e[1]["id"])) == want:
			out.append(String(e[1]["id"]))
	_set_sel(out, sel)

func _select_same_bone() -> void:
	var e0 := _find(sel)
	if e0.is_empty():
		return
	var b := String(e0[1].get("bone", ""))
	var out := []
	for e in _parts():
		if String(e[1].get("bone", "")) == b and e[0] == e0[0]:
			out.append(String(e[1]["id"]))
	_set_sel(out, sel)

func _color_of(id: String) -> Array:
	var en := _entry(id, false)
	if en.has("color"):
		return en["color"]
	var e := _find(id)
	if e.is_empty():
		return [0, 0, 0]
	var mi: MeshInstance3D = e[0]
	var src: Mesh = mi.get_meta("eb_src") if mi.has_meta("eb_src") else mi.mesh
	var isl := _island(id)
	var m := src.surface_get_material(int(isl.get("surf", 0))) if not isl.is_empty() else null
	if m is BaseMaterial3D:
		var c: Color = (m as BaseMaterial3D).albedo_color
		return [snappedf(c.r, 0.01), snappedf(c.g, 0.01), snappedf(c.b, 0.01)]
	return [0.5, 0.5, 0.5]

func _fill_parts() -> void:
	_updating = true
	part_list.clear()
	_list_ids.clear()
	_list_pos.clear()
	_list_hl.clear()
	for e in _parts():
		var id := String(e[1]["id"])
		var bone := String(e[1].get("bone", ""))
		var txt := ("nový díl %s" % id.substr(4)) if id.begins_with("new:") else id
		if bone != "":
			txt += "  (%s)" % bone
		part_list.add_item(txt)
		var c: Array = _color_of(id)
		part_list.set_item_icon_modulate(part_list.item_count - 1, Color(c[0], c[1], c[2]))
		part_list.set_item_custom_fg_color(part_list.item_count - 1, EdUI.AMBER if id == sel else EdUI.TEXT)
		_list_pos[id] = _list_ids.size()
		_list_ids.append(id)
		if id == sel:
			_list_hl.append(part_list.item_count - 1)
		if id in sels:
			part_list.select(part_list.item_count - 1, false)
	if sel != "":
		var i := _list_ids.find(sel)
		if i >= 0:
			part_list.ensure_current_is_visible()
	_updating = false

## Only the selection changed: mark it in the list (no new rows).
func _sync_list() -> void:
	_updating = true
	for r in _list_hl:
		if r < part_list.item_count:
			part_list.set_item_custom_fg_color(r, EdUI.TEXT)
	_list_hl.clear()
	part_list.deselect_all()
	for id in sels:
		var r: int = _list_pos.get(id, -1)
		if r >= 0:
			part_list.select(r, false)
	var ra: int = _list_pos.get(sel, -1)
	if ra >= 0:
		part_list.set_item_custom_fg_color(ra, EdUI.AMBER)
		_list_hl.append(ra)
		part_list.ensure_current_is_visible()
	_updating = false

func _from_list() -> void:
	if _updating:
		return
	var ids := []
	for i in part_list.get_selected_items():
		ids.append(_list_ids[i])
	var act: String = sel if sel in ids else (String(ids[-1]) if not ids.is_empty() else "")
	_updating = true
	sels = ids
	sel = act
	_refresh_fields()
	title_lbl.text = "%s%s   ·   vybráno %d" % [NAMES.get(model_name, model_name), " *neuloženo" if dirty else "", sels.size()]
	_updating = false

# ---- the number fields --------------------------------------------------------------------------
func _refresh_fields() -> void:
	_updating = true
	var on := sel != "" and not _find(sel).is_empty()
	for k in _f:
		(_f[k] as SpinBox).editable = on
	if on:
		var xf := _xf_of(sel)
		var c := Vector3.ZERO if sel.begins_with("new:") else (_island(sel).get("center", Vector3.ZERO) as Vector3)
		var p := c + ModelMods.xf_pos(xf) if not sel.begins_with("new:") else ModelMods.xf_pos(xf)
		for k in 3:
			(_f["pos%d" % k] as SpinBox).value = snappedf(p[k] * 100.0, 0.01)
			(_f["rot%d" % k] as SpinBox).value = snappedf(float(xf[3 + k]), 0.1)
			(_f["scl%d" % k] as SpinBox).value = snappedf(float(xf[6 + k]) * 100.0, 0.1)
		var col: Array = _color_of(sel)
		_color_btn.color = Color(col[0], col[1], col[2])
		_scl_lbl.text = "Rozměr nového dílu (cm)" if sel.begins_with("new:") else "Velikost proti původní (%)"
	_updating = false

func _on_field(key: String, val: float) -> void:
	if _updating or sel == "":
		return
	var k := int(key.right(1))
	var kind := key.left(3)
	var xf0: Array = _xf_of(sel).duplicate()
	var c := Vector3.ZERO if sel.begins_with("new:") else (_island(sel).get("center", Vector3.ZERO) as Vector3)
	var delta := 0.0
	match kind:
		"pos":
			var p0: float = (c[k] + float(xf0[k])) * 100.0
			delta = (val - p0) / 100.0
		"rot":
			delta = val - float(xf0[3 + k])
		"scl":
			delta = val / maxf(float(xf0[6 + k]) * 100.0, 0.0001)
	_push()
	for id in sels:
		var en := _entry(id)
		if not en.has("xf"):
			en["xf"] = ModelMods.IDENT.duplicate()
		var xf: Array = en["xf"]
		match kind:
			"pos": xf[k] = float(xf[k]) + delta
			"rot": xf[3 + k] = float(xf[3 + k]) + delta
			"scl": xf[6 + k] = clampf(float(xf[6 + k]) * delta, 0.005, 100.0)
	_commit()

# ---- editing ------------------------------------------------------------------------------------
func _need_sel() -> bool:
	if sels.is_empty():
		status.text = "Nejdřív vyber díl (klik do obrázku nebo seznamu)."
		return false
	return true

func _paint(col) -> void:
	if not _need_sel():
		return
	_push()
	for id in sels:
		var en := _entry(id)
		if col == null:
			en.erase("color")
			if id.begins_with("new:"):
				en["color"] = [0.5, 0.5, 0.5]
		else:
			en["color"] = col
	_commit()

func _add(shape: String) -> void:
	_push()
	var e := _find(sel) if sel != "" else []
	var mi: MeshInstance3D = e[0] if not e.is_empty() else model.find_children("*", "MeshInstance3D", true, false)[0]
	var at_w := _center_of(sel) if sel != "" else target
	at_w += cam.global_transform.basis.x * extent * 0.08
	var at := mi.global_transform.affine_inverse() * at_w
	var s := extent * 0.06
	work["new"].append({"piece": String(mi.name), "shape": shape, "xf": [at.x, at.y, at.z, 0, 0, 0, s, s, s],
		"color": [0.5, 0.5, 0.5], "bone": String(e[1].get("bone", "")) if not e.is_empty() else ""})
	var id := "new:%d" % (work["new"].size() - 1)
	_commit()
	_set_sel([id])
	status.text = "Přidáno. Táhni ho úchyty nebo bílou tečkou."

## A part as a new block of the same place, size and colour (original parts are copied as a box).
func _as_new(id: String) -> Dictionary:
	var e := _find(id)
	if e.is_empty():
		return {}
	var mi: MeshInstance3D = e[0]
	if id.begins_with("new:"):
		return (_entry(id) as Dictionary).duplicate(true)
	var bb: AABB = _island(id)["box"]
	var t := _mesh_xf(id) * Transform3D(Basis.from_scale(bb.size.max(Vector3.ONE * 0.001)), bb.get_center())
	var np := {"piece": String(mi.name), "shape": "box", "xf": ModelMods.IDENT.duplicate(), "color": _color_of(id), "bone": String(e[1].get("bone", ""))}
	return {"_t": t, "np": np}

func _add_copies(ids: Array, off_w: Vector3) -> Array:
	var made := []
	for id in ids:
		var mi := _mesh_of(id)
		if mi == null:
			continue
		var c := _as_new(id)
		var np: Dictionary
		var t: Transform3D
		if c.has("np"):
			np = c["np"]
			t = c["_t"]
		else:
			np = c
			t = Transform3D(ModelMods.xf_basis(np["xf"]), ModelMods.xf_pos(np["xf"]))
		var tw := mi.global_transform * t
		tw.origin += off_w
		work["new"].append(np)
		var nid := "new:%d" % (work["new"].size() - 1)
		# a new block's xf: from its world transform (in the mesh's space)
		var tm := mi.global_transform.affine_inverse() * tw
		var b := tm.basis
		var s := Vector3(b.x.length(), b.y.length(), b.z.length())
		var r := Basis(b.x / maxf(s.x, 1e-6), b.y / maxf(s.y, 1e-6), b.z / maxf(s.z, 1e-6)).orthonormalized().get_euler() * (180.0 / PI)
		np["xf"] = [tm.origin.x, tm.origin.y, tm.origin.z, r.x, r.y, r.z, s.x, s.y, s.z]
		made.append(nid)
	return made

func _duplicate_sel() -> void:
	if not _need_sel():
		return
	_push()
	var made := _add_copies(sels, cam.global_transform.basis.x * extent * 0.05)
	_commit()
	_set_sel(made)
	status.text = "Kopie hotová (%d dílů) – posuň ji, kam patří." % made.size()

## Mirror copies on the other side of the model (left-right across its middle, in its own space).
func _mirror_sel() -> void:
	if not _need_sel():
		return
	_push()
	var made := []
	var mid_w := _world_box().get_center()
	for id in sels:
		var mi := _mesh_of(id)
		if mi == null:
			continue
		var c := _as_new(id)
		var np: Dictionary = c["np"] if c.has("np") else c
		var t: Transform3D = c["_t"] if c.has("np") else Transform3D(ModelMods.xf_basis(np["xf"]), ModelMods.xf_pos(np["xf"]))
		var cx := (mi.global_transform.affine_inverse() * mid_w).x
		# mirror across x = cx: position and the turn (a block mirrored is the same block turned)
		var e := Basis(t.basis.x.normalized(), t.basis.y.normalized(), t.basis.z.normalized()).get_euler()
		var s := Vector3(t.basis.x.length(), t.basis.y.length(), t.basis.z.length())
		var me := Vector3(e.x, -e.y, -e.z) * (180.0 / PI)
		np["xf"] = [2.0 * cx - t.origin.x, t.origin.y, t.origin.z, me.x, me.y, me.z, s.x, s.y, s.z]
		var b := String(np.get("bone", ""))
		if b.ends_with(".L"): np["bone"] = b.trim_suffix(".L") + ".R"
		elif b.ends_with(".R"): np["bone"] = b.trim_suffix(".R") + ".L"
		work["new"].append(np)
		made.append("new:%d" % (work["new"].size() - 1))
	_commit()
	_set_sel(made)
	status.text = "Zrcadlová kopie (%d dílů) na druhé straně." % made.size()

## Turns the selection over in place (180° around the axis through its middle).
func _flip(axis: int) -> void:
	if not _need_sel():
		return
	_push()
	var pv := _pivot()
	var ax: Vector3 = _axes()[axis]
	var r := Transform3D(Basis(ax, PI), Vector3.ZERO)
	for id in sels:
		var w := _world_xf(id)
		var nw := Transform3D(Basis(), pv) * r * Transform3D(Basis(), -pv) * w
		_set_world_xf(id, nw)
	_commit()

func _copy() -> void:
	if not _need_sel():
		return
	_clip = []
	for id in sels:
		var c := _as_new(id)
		if c.has("np"):
			var t: Transform3D = c["_t"]
			var np: Dictionary = c["np"]
			var b := t.basis
			var s := Vector3(b.x.length(), b.y.length(), b.z.length())
			var r := Basis(b.x / s.x, b.y / s.y, b.z / s.z).orthonormalized().get_euler() * (180.0 / PI)
			np["xf"] = [t.origin.x, t.origin.y, t.origin.z, r.x, r.y, r.z, s.x, s.y, s.z]
			_clip.append(np)
		else:
			_clip.append(c)
	status.text = "Zkopírováno %d dílů (Ctrl+V vloží)." % _clip.size()

func _paste() -> void:
	if _clip.is_empty():
		status.text = "Schránka je prázdná (Ctrl+C)."
		return
	_push()
	var made := []
	var pieces := {}
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		pieces[String(mi.name)] = true
	var first := String(model.find_children("*", "MeshInstance3D", true, false)[0].name)
	for np0 in _clip:
		var np: Dictionary = (np0 as Dictionary).duplicate(true)
		if not pieces.has(String(np.get("piece", ""))):
			np["piece"] = first     # (copied from another model: into its first mesh)
		np["xf"][0] = float(np["xf"][0]) + extent * 0.04
		work["new"].append(np)
		made.append("new:%d" % (work["new"].size() - 1))
	_commit()
	_set_sel(made)
	status.text = "Vloženo %d dílů." % made.size()

func _delete_sel() -> void:
	if not _need_sel():
		return
	_push()
	var news := []
	for id in sels:
		if id.begins_with("new:"):
			news.append(int(id.substr(4)))
		else:
			_entry(id)["del"] = true
	news.sort()
	news.reverse()
	for i in news:
		work["new"].remove_at(i)
	sels = []
	sel = ""
	_commit()
	status.text = "Smazáno (Ctrl+Z vrátí)."

func _reset_sel() -> void:
	if not _need_sel():
		return
	_push()
	for id in sels:
		if not id.begins_with("new:"):
			work["parts"].erase(id)
	_commit()
	status.text = "Původní díly jsou zase původní."

func _reset_all() -> void:
	_push()
	work = {"parts": {}, "new": []}
	sels = []
	sel = ""
	_refresh_meshes(true)
	Game.model_mods[model_name] = work
	_after_change()
	status.text = "Model je zase původní (ulož, ať to platí)."

func _nudge(d: Vector3, mult: float) -> void:
	if not _need_sel():
		return
	var axes := _axes()
	var stepm := extent * 0.005 * mult
	var w: Vector3 = (axes[0] * d.x + axes[1] * d.y + axes[2] * d.z) * stepm
	_push()
	var meshes := []
	for id in sels:
		var t := _world_xf(id)
		t.origin += w
		_set_world_xf(id, t)
		var mi := _mesh_of(id)
		if mi and not mi in meshes:
			meshes.append(mi)
	_commit(meshes)

func _save() -> void:
	Game.model_mods[model_name] = work
	if Game.save_model_mods(model_name):
		dirty = false
		status.text = "Uloženo: %s" % Game.models_dir().path_join(model_name + ".json")
		Game.play_ui(self, "ui_confirm", -6)
	else:
		status.text = "Uložení se nepovedlo (%s)." % Game.models_dir()
		Game.play_ui(self, "ui_deny", -6)
	_after_change(false)
	_fill_models()

# ---- the view ------------------------------------------------------------------------------------
func _process(_d: float) -> void:
	var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	cam.position = target + dir * dist
	cam.look_at(target, Vector3.UP if absf(pitch) < 1.5 else Vector3.FORWARD)
	cam.near = maxf(0.005, dist * 0.01)
	cam.far = maxf(100.0, dist * 50.0)
	_draw_overlay()

func _view_from(k: int) -> void:
	yaw = [PI, PI / 2, PI][k]
	pitch = [0.0, 0.0, -1.55][k]

func _focus() -> void:
	if sels.is_empty():
		var box := _world_box()
		target = box.get_center()
		dist = extent * 1.25 + 0.15
		return
	target = _pivot()
	var r := 0.0
	for id in sels:
		for c in _corners(id):
			r = maxf(r, (c as Vector3).distance_to(target))
	dist = clampf(r * 3.0, extent * 0.05, extent * 4.0)

func _axes() -> Array:
	var b := model.global_transform.basis
	if space == "dil" and sel != "":
		b = _world_xf(sel).basis
	return [b.x.normalized(), b.y.normalized(), b.z.normalized()]

func _pivot() -> Vector3:
	if sels.is_empty():
		return Vector3.ZERO
	var c := Vector3.ZERO
	for id in sels:
		c += _center_of(id)
	return c / sels.size()

func _glen(o: Vector3) -> float:
	return 80.0 * ov.px(o)

func _vp(at: Vector2) -> Vector2:
	return at * (Vector2(view.size) / svc.size)

func _scr(w: Vector3) -> Vector2:
	return cam.unproject_position(w) * (svc.size / Vector2(view.size))

func _gizmo_hit(m: Vector2) -> int:
	if sels.is_empty():
		return -1
	var o := _pivot()
	if cam.is_position_behind(o):
		return -1
	var so := _scr(o)
	if m.distance_to(so) < 10.0:
		return DOT
	var axes := _axes()
	var l := _glen(o)
	var best := -1
	var bd := 11.0
	for i in 3:
		var dd := INF
		if mode == "otaceni":
			var ring := EdUI.ring_points(o, axes[i], l * 0.9)
			for k in ring.size() - 1:
				dd = minf(dd, m.distance_to(Geometry2D.get_closest_point_to_segment(m, _scr(ring[k]), _scr(ring[k + 1]))))
		else:
			dd = m.distance_to(Geometry2D.get_closest_point_to_segment(m, so, _scr(o + axes[i] * l * 1.15)))
		if dd < bd:
			bd = dd
			best = i
	return best

func _pick(m: Vector2) -> String:
	var p := _vp(m)
	var o := cam.project_ray_origin(p)
	var d := cam.project_ray_normal(p)
	var best := ""
	var bd := 1e9
	for e in _parts():
		var mi: MeshInstance3D = e[0]
		var tris: PackedVector3Array = e[1]["tris"]
		var xf := mi.global_transform
		for k in range(0, tris.size(), 3):
			var hit = Geometry3D.ray_intersects_triangle(o, d, xf * tris[k], xf * tris[k + 1], xf * tris[k + 2])
			if hit != null:
				var dd: float = (hit - o).length()
				if dd < bd:
					bd = dd
					best = e[1]["id"]
	return best

func _start_drag(kind: String, ax: int, m: Vector2) -> void:
	_push()
	_drag = kind
	_drag_axis = ax
	_drag_from = m
	_drag_start = {}
	for id in sels:
		_drag_start[id] = _world_xf(id)
	_drag_pivot = _pivot()
	var p := _vp(m)
	_drag_plane = Plane(-cam.global_transform.basis.z, _drag_pivot)
	var hit = _drag_plane.intersects_ray(cam.project_ray_origin(p), cam.project_ray_normal(p))
	_drag_hit0 = hit if hit != null else _drag_pivot
	if kind == "gizmo" and ax >= 0 and ax < 3:
		var axes := _axes()
		var l := _glen(_drag_pivot)
		var sv := _scr(_drag_pivot + axes[ax] * l) - _scr(_drag_pivot)
		_drag_dir = sv.normalized() if sv.length() > 1.0 else Vector2.RIGHT
		_drag_scale = l / maxf(sv.length(), 1.0)

func _drag_to(m: Vector2, coarse: bool) -> void:
	var meshes := []
	for id in sels:
		var mi := _mesh_of(id)
		if mi and not mi in meshes:
			meshes.append(mi)
	if _drag == "move" or (_drag == "gizmo" and _drag_axis == DOT and mode == "posun") or (_drag == "gizmo" and _drag_axis == DOT and mode == "otaceni"):
		var p := _vp(m)
		var hit = _drag_plane.intersects_ray(cam.project_ray_origin(p), cam.project_ray_normal(p))
		if hit == null:
			return
		var off: Vector3 = hit - _drag_hit0
		if coarse:
			var st := extent * 0.025
			off = (off / st).round() * st
		for id in _drag_start:
			var w: Transform3D = _drag_start[id]
			w.origin += off
			_set_world_xf(id, w)
	elif _drag == "gizmo":
		var axes := _axes()
		match mode:
			"posun":
				var dw := (m - _drag_from).dot(_drag_dir) * _drag_scale
				dw = snappedf(dw, extent * (0.025 if coarse else 0.001))
				for id in _drag_start:
					var w: Transform3D = _drag_start[id]
					w.origin += axes[_drag_axis] * dw
					_set_world_xf(id, w)
			"otaceni":
				var so := _scr(_drag_pivot)
				var a0 := (_drag_from - so).angle()
				var a1 := (m - so).angle()
				var ang := wrapf(a1 - a0, -PI, PI)
				var ax: Vector3 = axes[_drag_axis]
				# turning on the screen clockwise = turning away from the viewer around the axis
				if ax.dot(cam.global_transform.basis.z) < 0.0:
					ang = -ang
				ang = -ang
				ang = snappedf(ang, deg_to_rad(15.0) if coarse else deg_to_rad(1.0))
				var r := Transform3D(Basis(ax, ang), Vector3.ZERO)
				for id in _drag_start:
					var w: Transform3D = _drag_start[id]
					_set_world_xf(id, Transform3D(Basis(), _drag_pivot) * r * Transform3D(Basis(), -_drag_pivot) * w)
				status.text = "Otočení: %.0f°" % rad_to_deg(ang)
			"velikost":
				if _drag_axis == DOT:
					var f := maxf(1.0 + (m.x - _drag_from.x - (m.y - _drag_from.y)) * 0.005, 0.02)
					f = snappedf(f, 0.1 if coarse else 0.01)
					for id in _drag_start:
						var w: Transform3D = _drag_start[id]
						var nw := Transform3D(w.basis * Basis.from_scale(Vector3.ONE * f), _drag_pivot + (w.origin - _drag_pivot) * f)
						_set_world_xf(id, nw)
					status.text = "Velikost: %.0f %%" % (f * 100.0)
				else:
					var ax2: Vector3 = axes[_drag_axis]
					var dw := (m - _drag_from).dot(_drag_dir) * _drag_scale
					var ext := 0.0
					for id in _drag_start:
						for c in _corners(id):
							ext = maxf(ext, absf(((c as Vector3) - _drag_pivot).dot(ax2)))
					ext = maxf(ext, extent * 0.01)
					var f := maxf((ext + dw) / ext, 0.02)
					f = snappedf(f, 0.1 if coarse else 0.01)
					for id in _drag_start:
						var w: Transform3D = _drag_start[id]
						# the part's own axis that lies most along the dragged one is stretched
						var best := 0
						var bd := -1.0
						for k in 3:
							var d := absf(w.basis[k].normalized().dot(ax2))
							if d > bd:
								bd = d
								best = k
						var sv := Vector3.ONE
						sv[best] = f
						var nb := w.basis * Basis.from_scale(sv)
						var rel := w.origin - _drag_pivot
						var no := _drag_pivot + rel + ax2 * rel.dot(ax2) * (f - 1.0)
						_set_world_xf(id, Transform3D(nb, no))
					status.text = "Velikost: %.0f %%" % (f * 100.0)
	Game.model_mods[model_name] = work
	_refresh_meshes(false, meshes)
	_refresh_fields()

func _view_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.pressed:
			get_viewport().gui_release_focus()
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					dist = maxf(extent * 0.03, dist * 0.9)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					dist = minf(extent * 10.0, dist * 1.1)
			MOUSE_BUTTON_RIGHT:
				_drag = ("pan" if mb.shift_pressed else "orbit") if mb.pressed else ""
			MOUSE_BUTTON_MIDDLE:
				_drag = "pan" if mb.pressed else ""
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					var ax := _gizmo_hit(mb.position)
					if ax >= 0:
						if mb.shift_pressed and mode == "posun":
							# Shift + an arrow: drag a copy (the original stays)
							var made := _add_copies(sels, Vector3.ZERO)
							_commit()
							_set_sel(made)
							status.text = "Kopie – táhni ji, kam patří."
						_start_drag("gizmo", ax, mb.position)
						return
					var id := _pick(mb.position)
					if id != "" and id in sels and not (mb.shift_pressed or mb.ctrl_pressed):
						sel = id
						_start_drag("move", -1, mb.position)
						return
					_drag = "click"
					_drag_from = mb.position
				else:
					match _drag:
						"click":
							var id := _pick(mb.position)
							if mb.shift_pressed or mb.ctrl_pressed:
								if id != "":
									_toggle(id)
							else:
								_set_sel([id] if id != "" else [])
							if id == "" and not (mb.shift_pressed or mb.ctrl_pressed):
								status.text = "Nic nevybráno. (Táhni obdélník přes díly, nebo klikni na díl.)"
						"rect":
							_rect_select(mb.shift_pressed or mb.ctrl_pressed)
						"gizmo", "move":
							_commit()
					_drag = ""
					_drag_axis = -1
					_rect.on = false
					_rect.queue_redraw()
	elif ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		match _drag:
			"orbit":
				yaw -= mm.relative.x * 0.008
				pitch = clampf(pitch + mm.relative.y * 0.008, -1.55, 1.55)
			"pan":
				var b := cam.global_transform.basis
				var px := ov.px(target) * (Vector2(view.size) / svc.size).y
				target += (-b.x * mm.relative.x + b.y * mm.relative.y) * px
			"gizmo", "move":
				_drag_to(mm.position, mm.ctrl_pressed)
			"click":
				if mm.position.distance_to(_drag_from) > 6.0:
					_drag = "rect"
					_rect.on = true
					_rect.a = _drag_from
					_rect.b = mm.position
					_rect.queue_redraw()
			"rect":
				_rect.b = mm.position
				_rect.queue_redraw()
			"":
				_hover = _gizmo_hit(mm.position)

func _rect_select(add: bool) -> void:
	var r := Rect2(_rect.a, _rect.b - _rect.a).abs()
	var ids: Array = sels.duplicate() if add else []
	for e in _parts():
		var id := String(e[1]["id"])
		var c := _center_of(id)
		if cam.is_position_behind(c):
			continue
		if r.has_point(_scr(c)) and not id in ids:
			ids.append(id)
	_set_sel(ids)
	status.text = "Vybráno %d dílů." % sels.size()

func _set_mode(m: String) -> void:
	mode = m
	for k in _tool_btns:
		(_tool_btns[k] as Button).button_pressed = k == m
	_show_hint()

func _show_hint() -> void:
	if hint:
		hint.text = "Levé: výběr (Shift/Ctrl přidá), tah po prázdnu = obdélník, tah dílu = posun · úchyty: %s (Ctrl = hrubě, Shift + šipka = kopie) · Pravé: otáčet pohled · Střední / Shift+pravé: posun pohledu · Kolečko: zoom · G/R/S nástroje · Ctrl+A vše · Ctrl+D kopie · M zrcadlo · Del smazat · šipky/PgUp/PgDn posun · Ctrl+Z/Y · Ctrl+S" % TOOLS[mode]
	for k in _tool_btns:
		(_tool_btns[k] as Button).button_pressed = k == mode

func _unhandled_key_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed):
		return
	var k := ev as InputEventKey
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	var handled := true
	var mult := 10.0 if k.shift_pressed else 1.0
	match k.keycode:
		KEY_Z when k.ctrl_pressed: _undo_step()
		KEY_Y when k.ctrl_pressed: _redo_step()
		KEY_S when k.ctrl_pressed: _save()
		KEY_D when k.ctrl_pressed: _duplicate_sel()
		KEY_C when k.ctrl_pressed: _copy()
		KEY_V when k.ctrl_pressed: _paste()
		KEY_A when k.ctrl_pressed: _select_all()
		KEY_G: _set_mode("posun")
		KEY_S: _set_mode("velikost")
		KEY_R: _set_mode("otaceni")
		KEY_M: _mirror_sel()
		KEY_DELETE, KEY_X: _delete_sel()
		KEY_ESCAPE: _set_sel([])
		KEY_F: _focus()
		KEY_1, KEY_KP_1: _view_from(0)
		KEY_3, KEY_KP_3: _view_from(1)
		KEY_7, KEY_KP_7: _view_from(2)
		KEY_LEFT: _nudge(Vector3(-1, 0, 0), mult)
		KEY_RIGHT: _nudge(Vector3(1, 0, 0), mult)
		KEY_UP: _nudge(Vector3(0, 0, -1), mult)
		KEY_DOWN: _nudge(Vector3(0, 0, 1), mult)
		KEY_PAGEUP: _nudge(Vector3(0, 1, 0), mult)
		KEY_PAGEDOWN: _nudge(Vector3(0, -1, 0), mult)
		_: handled = false
	if handled:
		get_viewport().set_input_as_handled()

# ---- the overlay -------------------------------------------------------------------------------------
func _draw_overlay() -> void:
	ov.clear()
	if model and not sels.is_empty():
		for id in sels:
			if _find(id).is_empty():
				continue
			ov.box(_corners(id), Color(1.0, 0.92, 0.3) if id == sel else Color(1.0, 0.62, 0.2, 0.85), 2.0 if id == sel else 1.4)
		var o := _pivot()
		var axes := _axes()
		var l := _glen(o)
		for i in 3:
			var hot := i == _drag_axis or (_drag == "" and i == _hover)
			var col: Color = Color(1.0, 0.95, 0.4) if hot else EdUI.AXIS_COL[i]
			var ax: Vector3 = axes[i]
			match mode:
				"otaceni":
					ov.ring(o, ax, l * 0.9, col, 4.0 if hot else 2.5)
				_:
					var tip := o + ax * l
					ov.line(o, tip, col, 4.0 if hot else 3.0)
					if mode == "posun":
						var side := ax.cross(cam.global_position - tip).normalized() * l * 0.08
						ov.tri(tip - side, tip + side, tip + ax * l * 0.22, col)
					else:
						ov.dot(tip + ax * l * 0.05, col, 12.0)
		var hot_dot := _drag_axis == DOT or (_drag == "" and _hover == DOT)
		ov.dot(o, Color(0, 0, 0, 0.6), 15.0 if hot_dot else 12.0)
		ov.dot(o, Color(1.0, 0.95, 0.4) if hot_dot else Color(1, 1, 1), 10.0 if hot_dot else 7.0)
	ov.flush()

# ---- tests --------------------------------------------------------------------------------------
## How long the editor makes Ari wait (ms): opening a model, a click on a part, grabbing it, a drag
## step, one frame of the handles. Nothing is saved.
func _speedtest() -> void:
	var keep := Game.model_mods.duplicate(true)
	var worst := {}
	for n in ["rifle", "merc", "dropship", "mars_hq", "v_house_roof"]:
		var t0 := Time.get_ticks_usec()
		_load_model(n)
		var t_open := (Time.get_ticks_usec() - t0) / 1000.0
		await get_tree().process_frame
		var parts := _parts()
		var id := String(parts[parts.size() / 2][1]["id"])
		var at := _scr(_center_of(id))
		t0 = Time.get_ticks_usec()
		var got := _pick(at)
		var t_pick := (Time.get_ticks_usec() - t0) / 1000.0
		t0 = Time.get_ticks_usec()
		_set_sel([got if got != "" else id])
		var t_sel := (Time.get_ticks_usec() - t0) / 1000.0
		t0 = Time.get_ticks_usec()
		_start_drag("move", -1, at)
		var t_grab := (Time.get_ticks_usec() - t0) / 1000.0
		var c0 := _center_of(sel)
		t0 = Time.get_ticks_usec()
		_drag_to(at + Vector2(12, 5), false)
		var t_drag := (Time.get_ticks_usec() - t0) / 1000.0
		_drag = ""
		if _center_of(sel).distance_to(c0) < 1e-5:
			print("[SPEED] %s: the drag did not move the part" % n)
			t_drag = 99999.0
		t0 = Time.get_ticks_usec()
		_draw_overlay()
		var t_frame := (Time.get_ticks_usec() - t0) / 1000.0
		_undo_step()
		print("[SPEED] %s parts %d: open %.0f pick %.0f select %.0f grab %.0f drag %.0f frame %.1f ms" % [n, parts.size(), t_open, t_pick, t_sel, t_grab, t_drag, t_frame])
		for k in ["open", "pick", "select", "grab", "drag", "frame"]:
			var v: float = {"open": t_open, "pick": t_pick, "select": t_sel, "grab": t_grab, "drag": t_drag, "frame": t_frame}[k]
			worst[k] = maxf(worst.get(k, 0.0), v)
	Game.model_mods = keep
	# (limits for the slow software renderer of the test machine; a real graphics card is far faster)
	var fast: bool = worst["open"] < 2000.0 and worst["pick"] < 100.0 and worst["select"] < 100.0 and worst["grab"] < 100.0 and worst["drag"] < 500.0 and worst["frame"] < 20.0
	print("RESULT modspeed %s open %.0f pick %.0f select %.0f grab %.0f drag %.0f frame %.1f" % ["ok" if fast else "POMALU", worst["open"], worst["pick"], worst["select"], worst["grab"], worst["drag"], worst["frame"]])
	get_tree().quit()

## Real mouse clicks through the window (as Ari's hand does): on a part in the view.
func _clicktest() -> void:
	_load_model("rifle")
	for f in 10: await get_tree().process_frame
	var xf := get_viewport().get_final_transform()
	var parts := _parts()
	var pi := 0
	for k in parts.size():
		var id := String(parts[k][1]["id"])
		var c := _center_of(id)
		if _pick(_scr(c)) == id:
			pi = k
			break
	var want := String(parts[pi][1]["id"])
	var local := _scr(_center_of(want))
	var win: Vector2 = xf * (svc.get_global_transform() * local)
	print("[CLICK] window %s local %s" % [win, local])
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = win
		ev.global_position = win
		Input.parse_input_event(ev)
		for f in 3: await get_tree().process_frame
	print("RESULT modclick sel '%s' (want '%s')" % [sel, want])
	get_tree().quit()

## The tools on the rifle: rectangle selection, a group turned around its middle, moved, stretched,
## copied, mirrored, painted, undone; then the merc. Pictures: user://mod_*.png
func _selftest() -> void:
	var keep := Game.model_mods.duplicate(true)
	_load_model("rifle")
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("user://mod_0_before.png")
	var n0 := _parts().size()
	# rectangle over the whole view: everything
	_rect.a = Vector2(2, 2)
	_rect.b = svc.size - Vector2(2, 2)
	_rect_select(false)
	var all_ok := sels.size() == n0
	# a few parts: turned 90° around their middle
	var some: Array = _parts().slice(0, 4).map(func(e): return String(e[1]["id"]))
	_set_sel(some)
	var c0 := _pivot()
	var w0 := _world_xf(some[0])
	_start_drag("gizmo", 1, _scr(c0) + Vector2(60, 0))
	mode = "otaceni"
	var so := _scr(c0)
	_drag_to(so + Vector2(0, 60), false)       # a quarter turn on the screen
	_commit()
	var w1 := _world_xf(some[0])
	var turned := absf(rad_to_deg(w0.basis.y.normalized().angle_to(w1.basis.y.normalized())) - 90.0) < 2.0 or absf(rad_to_deg(w0.basis.x.normalized().angle_to(w1.basis.x.normalized())) - 90.0) < 2.0
	var pivot_kept := _pivot().distance_to(c0) < extent * 0.01
	# moved along x
	mode = "posun"
	var p0 := _center_of(some[0])
	_start_drag("gizmo", 0, _scr(c0))
	_drag_to(_scr(c0) + _drag_dir * 50.0, false)
	_commit()
	var moved := _center_of(some[0]).distance_to(p0) > extent * 0.005
	# stretched
	mode = "velikost"
	var s0 := float(_xf_of(some[0])[6]) + float(_xf_of(some[0])[7]) + float(_xf_of(some[0])[8])
	_start_drag("gizmo", DOT, _scr(c0))
	_drag_to(_scr(c0) + Vector2(80, 0), false)
	_commit()
	var s1 := float(_xf_of(some[0])[6]) + float(_xf_of(some[0])[7]) + float(_xf_of(some[0])[8])
	var stretched := s1 > s0 * 1.2
	mode = "posun"
	_paint([0.6, 0.08, 0.06])
	_duplicate_sel()
	var dup_n: int = work["new"].size()
	_mirror_sel()
	var mir_n: int = work["new"].size()
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("user://mod_1_after.png")
	for i in 3:
		_undo_step()
	var undone: int = work["new"].size()
	print("RESULT modeler rect %s turned %s pivot %s moved %s stretched %s copy %d mirror %d undo %d" % [all_ok, turned, pivot_kept, moved, stretched, dup_n, mir_n, undone])
	_load_model("merc")
	await get_tree().process_frame
	_set_sel([String(_parts()[3][1]["id"])])
	_paint([0.85, 0.55, 0.10])
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("user://mod_2_merc.png")
	Game.model_mods = keep
	get_tree().quit()
