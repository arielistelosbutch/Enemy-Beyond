extends Control
## Mapové díly (0.55): the 12 m blocks the maps are made of, one at a time. On the left the kind of
## block (house, barn, warehouse...), its variants (what the generator makes - each number a
## different one - and the ones saved by hand) and its parts. In the middle the block, worked like in
## the Modelář: click a part, drag it with the handles (move / turn / size), or type the numbers; add
## blocks, cylinders, balls, village models, lights and notes (cover, where the aliens go, doors,
## windows...). Saving makes the block a hand-made variant: the maps then use it (dilky/<kind>/).
##
## Mouse and keys as in the Modelář: left = select (Shift/Ctrl add), drag over empty space = select
## in a rectangle, drag a selected part = move it, handles = move / turn / size along an axis
## (Ctrl = coarse steps, Shift + arrow = drag a copy); right drag = turn the view, middle (or
## Shift + right) = pan, wheel = zoom. G / R / S tools, Ctrl+A, Esc, Ctrl+D copy, M mirror,
## Del delete, F focus, 1 / 3 / 7 views, arrows + PgUp / PgDn nudge, Ctrl+Z / Y, Ctrl+S save.

const MapGenScript := preload("res://scripts/map_gen.gd")
const TOOLS := {"posun": "Posun (G)", "otaceni": "Otáčení (R)", "velikost": "Velikost (S)"}
const DOT := 3
const BLOCK := 12.0
## The notes: [kind / point type, Czech name, colour on the overlay]
const NOTES := [["cover", "Kryt (kde se dá krýt)", Color(0.35, 0.9, 0.4)], ["waypoints", "Trasa vetřelců", Color(0.35, 0.6, 1.0)],
	["vip_spots", "Místo pro civilistu / VIP", Color(1.0, 0.8, 0.2)], ["alien_spawns", "Vetřelci začínají", Color(1.0, 0.3, 0.25)],
	["player_spawns", "Hráči začínají", Color(0.9, 0.9, 0.9)], ["cows", "Kráva (pro výzkum)", Color(0.8, 0.7, 0.6)],
	["door", "Dveře", Color(1.0, 0.55, 0.15)], ["window", "Okno (vetřelci střílí ven)", Color(0.4, 0.9, 1.0)],
	["sound", "Zvuk (oheň, rádio, déšť...)", Color(0.8, 0.45, 1.0)]]
const SOUNDS := ["fire", "static", "rain", "creak", "wind", "hum"]
const BREAKS := [["", "nerozbitné"], ["wood", "dřevo"], ["brick", "cihly"], ["glass", "sklo"], ["metal", "plech"], ["crate", "bedna"]]
const KIND_NAMES := {"box": "Kostka", "cyl": "Válec", "ball": "Koule", "model": "Model", "light": "Světlo", "fire": "Oheň",
	"grass": "Tráva", "link": "Cesta nahoru (pro vetřelce)", "solid": "Neviditelná zeď / rampa", "point": "Značka", "spot": "Místo pro misi",
	"door": "Dveře", "window": "Okno", "sound": "Zvuk", "woodroof": "Dřevěná střecha (spadne)"}
const SPOTS := {"house": "dům (mise: civilisté)", "barn": "stodola", "truck": "náklaďák", "circle": "kruh v obilí", "forklift": "vozík"}

var kind := "house"
var variant := ""            # "" = the generator's (gen_seed), else the saved file's name
var gen_seed := 1
var work := {}               # {"nazev", "vaha", "prvky": [...]}
var sel := -1                # the active part
var sels: Array = []         # all selected parts (numbers)
var mode := "posun"
var yaw := PI + 0.7
var pitch := -0.6
var dist := 22.0
var target := Vector3(6, 0, 6)
var extent := 12.0
var dirty := false
var terrain := "temperate"
var _undo := []
var _redo := []
var _clip := []
var _pick_ground := false
var _show_notes := true

var svc: SubViewportContainer
var view: SubViewport
var world: Node3D
var cam: Camera3D
var ov: EdUI.Overlay
var _rect: EdUI.SelRect
var _grid: MeshInstance3D
var _tile: Node3D            # the block's nodes live here
var mg                       # the generator the parts are built with
var _nodes: Array = []       # part number -> its nodes
var _sun: DirectionalLight3D
var _night := false

# mouse
var _drag := ""
var _drag_axis := -1
var _drag_from := Vector2.ZERO
var _drag_start := {}
var _drag_pivot := Vector3.ZERO
var _drag_dir := Vector2.ZERO
var _drag_scale := 0.0
var _drag_plane := Plane()
var _drag_hit0 := Vector3.ZERO
var _hover := -1

# panel
var kind_list: ItemList
var var_list: ItemList
var part_list: ItemList
var _var_ids: Array = []
var _kind_ids: Array = []
var _list_pos := {}
var _list_ids: Array = []
var title_lbl: Label
var status: Label
var hint: Label
var _tool_btns := {}
var _f := {}
var _updating := false
var _scl_lbl: Label
var _name_edit: LineEdit
var _weight: SpinBox
var _mix: CheckBox
var _seed_lbl: Label
var _props: VBoxContainer
var _props_for := ""
var _model_opt: OptionButton
var _note_opt: OptionButton
var _terrain_opt: OptionButton
var _tex_names: Array = []

func _ready() -> void:
	EdUI.enter(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for f in DirAccess.get_files_at("res://assets/textures"):
		if f.ends_with(".png"):
			_tex_names.append(f.get_basename())
		elif f.ends_with(".png.import"):
			var n := f.trim_suffix(".png.import")
			if not n in _tex_names:
				_tex_names.append(n)
	_tex_names.sort()
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
	EdUI.tabs(root, "tiles")
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
	for c in world.get_children():
		if c is DirectionalLight3D and _sun == null:
			_sun = c
			_sun.shadow_enabled = true
	svc.gui_input.connect(_view_input)
	_rect = EdUI.SelRect.new()
	svc.add_child(_rect)
	ov = EdUI.Overlay.new(cam, view)
	world.add_child(ov)
	_grid = EdUI.grid3d(world, 9.0)
	_grid.position = Vector3(6, 0.004, 6)
	_tile = Node3D.new()
	_tile.name = "Tile"
	world.add_child(_tile)
	_build_right(main)
	var foot := EdUI.row(root, 10)
	status = EdUI.lbl(foot, "", EdUI.AMBER)
	status.custom_minimum_size = Vector2(360, 0)
	hint = EdUI.lbl(foot, "", EdUI.DIM, 12, true)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.custom_minimum_size = Vector2(200, 0)
	_show_hint()
	_fill_kinds()
	var first := Game.cmd_arg("open", "house")
	_load(first if MapPieces.KINDS.has(first) else "house", "", 1)
	match Game.autotest():
		"tileeditor": _selftest.call_deferred()
		"tileshots": _shots.call_deferred()

# ---- the panels -------------------------------------------------------------------------------------
func _build_left(parent: Node) -> void:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(250, 0)
	box.add_theme_constant_override("separation", 6)
	parent.add_child(box)
	var p1 := PanelContainer.new()
	p1.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p1.size_flags_stretch_ratio = 1.1
	box.add_child(p1)
	var v1 := VBoxContainer.new()
	p1.add_child(v1)
	EdUI.head(v1, "1) Druh dílu")
	kind_list = ItemList.new()
	kind_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	kind_list.item_selected.connect(func(i):
		var id := String(_kind_ids[i])
		if id == kind:
			return
		_ask_discard(func(): _load(id, "", 1)))
	v1.add_child(kind_list)
	var p2 := PanelContainer.new()
	p2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p2.size_flags_stretch_ratio = 0.7
	box.add_child(p2)
	var v2 := VBoxContainer.new()
	p2.add_child(v2)
	EdUI.head(v2, "2) Varianta")
	var_list = ItemList.new()
	var_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var_list.item_selected.connect(func(i):
		var id := String(_var_ids[i])
		if id == variant and (id != "" or true):
			if id != "":
				return
		_ask_discard(func(): _load(kind, id, gen_seed)))
	v2.add_child(var_list)
	var sr := EdUI.row(v2)
	EdUI.btn(sr, "◄", func(): _ask_discard(func(): _load(kind, "", maxi(1, gen_seed - 1))), "Jiná varianta z generátoru")
	_seed_lbl = EdUI.lbl(sr, "", EdUI.DIM, 12)
	_seed_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	EdUI.btn(sr, "►", func(): _ask_discard(func(): _load(kind, "", gen_seed + 1)), "Jiná varianta z generátoru")
	var p3 := PanelContainer.new()
	p3.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p3.size_flags_stretch_ratio = 1.4
	box.add_child(p3)
	var v3 := VBoxContainer.new()
	p3.add_child(v3)
	EdUI.head(v3, "3) Části dílu (Ctrl / Shift = více)")
	part_list = ItemList.new()
	part_list.select_mode = ItemList.SELECT_MULTI
	part_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	part_list.multi_selected.connect(func(_i, _s): _from_list())
	part_list.item_selected.connect(func(_i): _from_list())
	v3.add_child(part_list)

func _build_toolbar(parent: Node) -> void:
	var bar := HFlowContainer.new()
	bar.add_theme_constant_override("h_separation", 4)
	bar.add_theme_constant_override("v_separation", 4)
	parent.add_child(bar)
	for m in TOOLS:
		var mm: String = m
		_tool_btns[m] = EdUI.btn(bar, TOOLS[m], func(): _set_mode(mm), "", true)
	EdUI.lbl(bar, "  ")
	EdUI.btn(bar, "Zepředu (1)", func(): _view_from(0), "Pohled zepředu")
	EdUI.btn(bar, "Z boku (3)", func(): _view_from(1), "Pohled z boku")
	EdUI.btn(bar, "Shora (7)", func(): _view_from(2), "Pohled shora")
	EdUI.btn(bar, "Zaměřit (F)", _focus, "Přiblížit na výběr (nic vybráno = celý díl)")
	EdUI.check(bar, "Mřížka", true, func(on): _grid.visible = on)
	EdUI.check(bar, "Noc", false, func(on): _set_night(on), "Jak díl vypadá v noci (svítí jen lampy a oheň)")
	EdUI.check(bar, "Značky", true, func(on): _show_notes = on, "Ukázat značky (kryt, trasy, dveře, okna...)")
	_terrain_opt = EdUI.opt(bar, [["temperate", "Léto"], ["snow", "Sníh"], ["desert", "Poušť"]], func(t):
		terrain = String(t)
		_rebuild_all())
	_terrain_opt.tooltip_text = "Krajina: tráva se v zimě a v poušti sama vymění za sníh a písek"
	title_lbl = EdUI.lbl(bar, "", EdUI.AMBER)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _build_right(parent: Node) -> void:
	var outer := VBoxContainer.new()
	outer.custom_minimum_size = Vector2(310, 0)
	parent.add_child(outer)
	var v := EdUI.panel(outer)
	EdUI.head(v, "Soubor")
	var r0 := EdUI.grid(v, 2)
	EdUI.btn(r0, "Uložit (Ctrl+S)", func(): _save(false), "Uloží tuhle variantu; vygenerovaná se tím stane ručně upravenou").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	EdUI.btn(r0, "Uložit jako novou", func(): _save(true), "Uloží jako další variantu vedle téhle").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	EdUI.btn(r0, "Zpět (Ctrl+Z)", _undo_step).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	EdUI.btn(r0, "Znovu (Ctrl+Y)", _redo_step).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	EdUI.btn(r0, "Vrátit změny", func(): EdUI.ask(self, "Zahodit neuložené změny téhle varianty?", func(): _load(kind, variant, gen_seed), "Zahodit"), "Načte variantu znovu").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	EdUI.btn(r0, "Smazat variantu", _delete_variant, "Smaže uloženou variantu (vygenerované zůstávají)").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nr := EdUI.row(v)
	EdUI.lbl(nr, "Název", EdUI.DIM, 12)
	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.placeholder_text = "např. Statek se studnou"
	_name_edit.text_changed.connect(func(t):
		work["nazev"] = t
		dirty = true
		_title())
	nr.add_child(_name_edit)
	var wr := EdUI.row(v)
	EdUI.lbl(wr, "Jak často na mapě", EdUI.DIM, 12)
	_weight = EdUI.spin(wr, 0, 10, 0.5, func(val):
		if _updating:
			return
		work["vaha"] = val
		dirty = true
		_title())
	_weight.tooltip_text = "Váha: 2 = dvakrát častěji než varianta s 1, 0 = nikdy"
	_mix = EdUI.check(v, "Na mapách i vygenerované díly", false, func(on):
		if _updating:
			return
		var s := MapPieces.settings(kind)
		s["generovany"] = 1.0 if on else 0.0
		MapPieces.save_settings(kind, s)
		status.text = "Mapy teď berou %s." % ("uložené i vygenerované díly" if on else "jen uložené díly (když nějaké jsou)"),
		"Vypnuto: když má druh uložené varianty, mapy berou jen je")
	EdUI.head(v, "Výběr")
	var r1 := EdUI.grid(v, 2)
	EdUI.btn(r1, "Vybrat vše (Ctrl+A)", _select_all).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	EdUI.btn(r1, "Nic (Esc)", func(): _set_sel([])).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	EdUI.btn(r1, "Stejný materiál", _select_same_mat, "Všechny části se stejným materiálem jako aktivní").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	EdUI.check(r1, "Vybírat i zem", false, func(on): _pick_ground = on, "Kliknutím jde vybrat i zem pod dílem")
	EdUI.head(v, "Aktivní část (čísla)")
	EdUI.lbl(v, "Změna platí pro celý výběr (o stejný kus).", EdUI.DIM, 12, true)
	for grp in [["pos", "Poloha (cm)", 1.0], ["rot", "Natočení (°)", 1.0], ["scl", "Rozměr (cm)", 1.0]]:
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
	EdUI.head(v, "Vlastnosti")
	_props = VBoxContainer.new()
	_props.add_theme_constant_override("separation", 4)
	v.add_child(_props)
	EdUI.head(v, "Přidat")
	var r2 := EdUI.grid(v, 3)
	EdUI.btn(r2, "+ Kostka", func(): _add({"k": "box", "s": [1, 1, 1], "m": ["t", "planks", 0.5, [0, 0, 0, 1]], "c": true})).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	EdUI.btn(r2, "+ Válec", func(): _add({"k": "cyl", "rt": 0.3, "rb": 0.3, "h": 1.0, "m": ["t", "metal", 0.5, [0, 0, 0, 1]], "c": true})).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	EdUI.btn(r2, "+ Koule", func(): _add({"k": "ball", "rad": 0.4, "h": 0.8, "n": 12, "rings": 6, "m": ["c", [0.5, 0.5, 0.5, 1.0], false, 0.0, 1.0], "c": false})).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var r3 := EdUI.row(v)
	var models := _model_names()
	_model_opt = EdUI.opt(r3, models, func(_m): pass)
	_model_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_model_opt.fit_to_longest_item = false
	EdUI.btn(r3, "+ Model", func(): _add({"k": "model", "n": String(_model_opt.get_item_metadata(_model_opt.selected)), "volne": true}))
	var r4 := EdUI.row(v)
	_note_opt = EdUI.opt(r4, NOTES.map(func(n): return [n[0], n[1]]), func(_m): pass)
	_note_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_note_opt.fit_to_longest_item = false
	EdUI.btn(r4, "+ Značka", _add_note)
	var r5 := EdUI.grid(v, 2)
	EdUI.btn(r5, "+ Lampa", func(): _add({"k": "light", "t": "omni", "col": [1.0, 0.78, 0.5], "e": 1.1, "rng": 5.5, "stin": true, "base": 1.1, "elektr": true}), "Elektrické světlo (zhasne, když vetřelci vyřadí proud)").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	EdUI.btn(r5, "+ Oheň", _add_fire, "Plameny se světlem a praskáním").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	EdUI.head(v, "Upravit")
	var r6 := EdUI.grid(v, 2)
	for e in [["Kopie (Ctrl+D)", _duplicate_sel, "Kopie vybraných částí kousek vedle"], ["Zrcadlit (M)", _mirror_sel, "Zrcadlová kopie na druhou stranu dílu"],
			["Kopírovat (Ctrl+C)", _copy, "Do schránky (vložit jde i do jiného dílu)"], ["Vložit (Ctrl+V)", _paste, ""],
			["Otočit o 90°", func(): _turn90(), "Otočí výběr kolem jeho středu"], ["Smazat (Del)", _delete_sel, ""]]:
		EdUI.btn(r6, e[0], e[1], e[2]).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	EdUI.head(v, "Jemné posunutí (šipky)")
	var r7 := EdUI.grid(v, 3)
	for e in [["◄ X−", Vector3(-1, 0, 0)], ["▲ Y+", Vector3(0, 1, 0)], ["► X+", Vector3(1, 0, 0)],
			["● Z+", Vector3(0, 0, 1)], ["▼ Y−", Vector3(0, -1, 0)], ["○ Z−", Vector3(0, 0, -1)]]:
		var d: Vector3 = e[1]
		EdUI.btn(r7, e[0], func(): _nudge(d, 1.0)).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	EdUI.head(v, "Značky v obrázku")
	var leg := EdUI.lbl(v, "", EdUI.DIM, 12, true)
	var txt := ""
	for n in NOTES:
		txt += "● %s\n" % n[1]
	leg.text = txt.strip_edges()
	# (the legend's dots in their colours: a RichTextLabel would do, a plain list is enough)
	var rl := RichTextLabel.new()
	rl.bbcode_enabled = true
	rl.fit_content = true
	rl.scroll_active = false
	rl.add_theme_font_size_override("normal_font_size", 12)
	var bb := ""
	for n in NOTES:
		bb += "[color=#%s]●[/color] %s\n" % [(n[2] as Color).to_html(false), n[1]]
	bb += "[color=#bbbbbb]□[/color] neviditelná zeď, rampa\n[color=#ffe066]●[/color] světlo"
	rl.text = bb
	v.add_child(rl)
	leg.queue_free()

func _model_names() -> Array:
	var out := []
	for f in DirAccess.get_files_at("res://assets/models"):
		var n := f.trim_suffix(".import").trim_suffix(".glb")
		if (f.ends_with(".glb") or f.ends_with(".glb.import")) and n.begins_with("v_") and not out.any(func(x): return x[0] == n):
			out.append([n, n.substr(2).replace("_", " ")])
	for extra in [["cow", "kráva"], ["sokol", "stíhačka Sokol"], ["mars_rock0", "marsovský kámen"]]:
		if ResourceLoader.exists("res://assets/models/%s.glb" % extra[0]):
			out.append(extra)
	out.sort_custom(func(a, b): return String(a[1]) < String(b[1]))
	return out

func _fill_kinds() -> void:
	kind_list.clear()
	_kind_ids.clear()
	var arr := []
	for k in MapPieces.KINDS:
		arr.append([k, String(MapPieces.KINDS[k][2])])
	arr.sort_custom(func(a, b): return String(a[1]) < String(b[1]))
	for e in arr:
		var n := MapPieces.designs(e[0]).size()
		kind_list.add_item(String(e[1]) + ("  • %d" % n if n > 0 else ""))
		_kind_ids.append(e[0])
		if e[0] == kind:
			kind_list.select(kind_list.item_count - 1)
	kind_list.ensure_current_is_visible()

func _fill_variants() -> void:
	var_list.clear()
	_var_ids.clear()
	var_list.add_item("Z generátoru (číslo %d)" % gen_seed)
	_var_ids.append("")
	if variant == "":
		var_list.select(0)
	for d in MapPieces.designs(kind):
		var nm := String(d.get("nazev", ""))
		if nm == "":
			nm = String(d["_soubor"])
		var_list.add_item("✎ %s  (×%s)" % [nm, str(d.get("vaha", 1.0))])
		_var_ids.append(String(d["_soubor"]))
		if String(d["_soubor"]) == variant:
			var_list.select(var_list.item_count - 1)
	_seed_lbl.text = "generátor: číslo %d" % gen_seed

func _ask_discard(then: Callable) -> void:
	if dirty:
		EdUI.ask(self, "Díl má neuložené změny. Zahodit je?", then, "Zahodit")
	else:
		then.call()

# ---- loading and building ------------------------------------------------------------------------
func _new_mg():
	var m = MapGenScript.new()
	m.root = _tile
	m.rng.seed = gen_seed
	m.terrain = terrain
	m.biome = {"house": "farm", "barn": "farm", "shop": "town", "pub": "town", "park": "town", "parking": "town",
		"warehouse": "industrial", "containers": "industrial", "tanks": "industrial", "yard": "industrial",
		"hangar": "base", "barracks": "base", "radar": "base", "sandbags": "base", "icelake": "polar", "icespires": "polar",
		"polarhut": "polar"}.get(kind, "farm")
	m.N = 40
	m.info["size"] = 480.0
	return m

func _clear_tile() -> void:
	for c in _tile.get_children():
		c.free()
	_nodes = []

func _load(k: String, v: String, s: int) -> void:
	kind = k
	variant = v
	gen_seed = s
	_undo.clear()
	_redo.clear()
	dirty = false
	sels = []
	sel = -1
	_clear_tile()
	if v == "":
		mg = _new_mg()
		work = MapPieces.capture(mg, k, Vector3.ZERO)
		work["nazev"] = ""
		work["vaha"] = 1.0
		_clear_tile()
	else:
		work = {}
		for d in MapPieces.designs(k):
			if String(d["_soubor"]) == v:
				work = (d as Dictionary).duplicate(true)
		if work.is_empty():
			_load(k, "", 1)
			return
	_rebuild_all()
	_updating = true
	_name_edit.text = String(work.get("nazev", ""))
	_weight.value = float(work.get("vaha", 1.0))
	_mix.button_pressed = float(MapPieces.settings(k).get("generovany", 0.0)) > 0.0
	_updating = false
	_fill_kinds()
	_fill_variants()
	_after_change()
	var what := String(MapPieces.KINDS[k][2])
	status.text = ("%s: varianta z generátoru č. %d (%d částí). Úpravy se uloží jako ruční varianta." % [what, s, _els().size()]) if v == "" else ("%s: %s (%d částí)." % [what, work.get("nazev", v), _els().size()])

func _els() -> Array:
	return work["prvky"]

func _rebuild_all() -> void:
	_clear_tile()
	mg = _new_mg()
	for i in _els().size():
		_nodes.append(_make(i))
	_set_night(_night)

func _make(i: int) -> Array:
	var n0 := _tile.get_child_count()
	var e: Dictionary = _els()[i]
	MapPieces.make(mg, e, Vector3.ZERO, _els())
	var out := []
	for j in range(n0, _tile.get_child_count()):
		out.append(_tile.get_child(j))
	# links between parts (a lamp's bulb): only in the game
	return out

func _rebuild_el(i: int) -> void:
	if i < 0 or i >= _nodes.size():
		return
	for n in _nodes[i]:
		if is_instance_valid(n):
			(n as Node).free()
	_nodes[i] = _make(i)

func _set_night(on: bool) -> void:
	_night = on
	for c in world.get_children():
		if c is DirectionalLight3D:
			(c as DirectionalLight3D).light_energy = (0.05 if on else (1.2 if c == _sun else 0.6))
		if c is WorldEnvironment:
			(c as WorldEnvironment).environment.ambient_light_color = Color(0.08, 0.09, 0.12) if on else Color(0.6, 0.62, 0.66)
			(c as WorldEnvironment).environment.background_color = Color(0.03, 0.035, 0.05) if on else Color(0.13, 0.15, 0.17)

# ---- the parts as boxes (for picking, the handles and the numbers) ------------------------------------
func _kind_of(i: int) -> String:
	return String(_els()[i].get("k", "")) if i >= 0 and i < _els().size() else ""

static func _v3(a) -> Vector3:
	return Vector3(a[0], a[1], a[2]) if a is Array and (a as Array).size() >= 3 else Vector3.ZERO

## The part's natural box in its own space (a unit cube -> the part).
func _base(e: Dictionary) -> Transform3D:
	match String(e.get("k", "")):
		"cyl":
			var r := maxf(float(e["rt"]), float(e["rb"]))
			return Transform3D(Basis.from_scale(Vector3(r * 2, float(e["h"]), r * 2)), Vector3.ZERO)
		"ball":
			return Transform3D(Basis.from_scale(Vector3(float(e["rad"]) * 2, float(e["h"]), float(e["rad"]) * 2)), Vector3.ZERO)
		"model":
			var a := MapPieces.model_box(String(e["n"]))
			return Transform3D(Basis.from_scale(a.size.max(Vector3.ONE * 0.05)), a.get_center())
		"door":
			var w := float(e.get("w", 1.5))
			var h := float(e.get("h", 2.15))
			var b := Basis.from_scale(Vector3(w, h, 0.3)) if bool(e.get("x", true)) else Basis(Vector3.UP, PI / 2) * Basis.from_scale(Vector3(w, h, 0.3))
			return Transform3D(b, Vector3(0, h / 2, 0))
		"window":
			var w := float(e.get("w", 1.0))
			var sill := float(e.get("sill", 0.9))
			var top := 2.0
			var nn := _v3(e.get("n", [0, 0, 1]))
			var b := Basis.from_scale(Vector3(w, top - sill, 0.3)) if absf(nn.z) > 0.5 else Basis(Vector3.UP, PI / 2) * Basis.from_scale(Vector3(w, top - sill, 0.3))
			return Transform3D(b, Vector3(0, (sill + top) / 2, 0))
	return Transform3D(Basis.from_scale(Vector3.ONE * 0.4), Vector3(0, 0.2, 0))

## A unit cube -> where the part is in the block.
func _frame(i: int) -> Transform3D:
	var e: Dictionary = _els()[i]
	var k := String(e.get("k", ""))
	match k:
		"box", "solid":
			var s := _v3(e.get("s", [1, 1, 1])).max(Vector3.ONE * 0.005)
			return MapPieces.local_xf(e) * Transform3D(Basis.from_scale(s), Vector3.ZERO)
		"cyl", "ball", "model":
			return MapPieces.local_xf(e) * _base(e)
		"link":
			var a := _v3(e["a"])
			var b := _v3(e["b"])
			return Transform3D(Basis.from_scale(Vector3.ONE * 0.4), (a + b) / 2)
		"grass":
			return Transform3D(Basis.from_scale(Vector3(BLOCK, 0.1, BLOCK)), Vector3(BLOCK / 2, 0.05, BLOCK / 2))
		"woodroof":
			var rr: Array = e.get("rect", [0, 0, 1, 1])
			var ri := int(e.get("i", -1))
			var y := 3.0
			if ri >= 0 and ri < _els().size():
				y = MapPieces.local_xf(_els()[ri]).origin.y
			return Transform3D(Basis.from_scale(Vector3(float(rr[2]), 0.2, float(rr[3]))), Vector3(float(rr[0]) + float(rr[2]) / 2, y, float(rr[1]) + float(rr[3]) / 2))
	return Transform3D(Basis(), _v3(e.get("p", [0, 0, 0]))) * _base(e)

## Writes a part back from where its unit cube is now.
func _set_frame(i: int, f: Transform3D) -> void:
	var e: Dictionary = _els()[i]
	var k := String(e.get("k", ""))
	match k:
		"box", "solid":
			var b := f.basis
			var s := Vector3(b.x.length(), b.y.length(), b.z.length())
			var r := Basis(b.x / maxf(s.x, 1e-6), b.y / maxf(s.y, 1e-6), b.z / maxf(s.z, 1e-6)).orthonormalized().get_euler() * (180.0 / PI)
			e["p"] = MapPieces._v(f.origin)
			e["s"] = MapPieces._v(s.max(Vector3.ONE * 0.005))
			_put_rot(e, r)
		"cyl", "ball", "model":
			var l := f * _base(e).affine_inverse()
			var b := l.basis
			var s := Vector3(b.x.length(), b.y.length(), b.z.length())
			var r := Basis(b.x / maxf(s.x, 1e-6), b.y / maxf(s.y, 1e-6), b.z / maxf(s.z, 1e-6)).orthonormalized().get_euler() * (180.0 / PI)
			e["p"] = MapPieces._v(l.origin)
			_put_rot(e, r)
			if (s - Vector3.ONE).length() > 0.001:
				e["sc"] = MapPieces._v(s)
			else:
				e.erase("sc")
		"link":
			var old := _frame(i).origin
			var d := f.origin - old
			e["a"] = MapPieces._v(_v3(e["a"]) + d)
			e["b"] = MapPieces._v(_v3(e["b"]) + d)
		"grass":
			pass
		"woodroof":
			var rr: Array = e["rect"]
			var old := _frame(i).origin
			rr[0] = snappedf(float(rr[0]) + f.origin.x - old.x, 0.001)
			rr[1] = snappedf(float(rr[1]) + f.origin.z - old.z, 0.001)
		_:
			e["p"] = MapPieces._v(f.origin - _base(e).origin)

func _put_rot(e: Dictionary, r: Vector3) -> void:
	if r.length() > 0.01:
		e["r"] = [snappedf(r.x, 0.01), snappedf(r.y, 0.01), snappedf(r.z, 0.01)]
	else:
		e.erase("r")

func _corners(i: int) -> Array:
	var f := _frame(i)
	var out := []
	var u := AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
	for k in 8:
		out.append(f * u.get_endpoint(k))
	return out

func _center_of(i: int) -> Vector3:
	return _frame(i).origin

func _is_ground(i: int) -> bool:
	var e: Dictionary = _els()[i]
	if String(e.get("k", "")) != "box":
		return false
	var s := _v3(e.get("s", [0, 0, 0]))
	var p := _v3(e.get("p", [0, 0, 0]))
	return s.x >= 11.0 and s.z >= 11.0 and p.y + s.y / 2 <= 0.06

# ---- undo -----------------------------------------------------------------------------------------------
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

## The parts changed: build again (only @a only, when just those moved) and the lists follow.
func _commit(only: Array = []) -> void:
	if only.is_empty() or _nodes.size() != _els().size():
		_rebuild_all()
	else:
		for i in only:
			_rebuild_el(int(i))
	sels = sels.filter(func(x): return int(x) >= 0 and int(x) < _els().size())
	if not sel in sels:
		sel = sels[-1] if not sels.is_empty() else -1
	_after_change(only.is_empty())

func _after_change(full := true) -> void:
	if full or _list_ids.size() != _els().size():
		_fill_parts()
	else:
		_sync_list()
	_refresh_fields()
	_title()

func _title() -> void:
	var what := String(MapPieces.KINDS.get(kind, ["", [], kind])[2])
	var vn := ("generátor č. %d" % gen_seed) if variant == "" else String(work.get("nazev", variant))
	title_lbl.text = "%s · %s%s   ·   vybráno %d" % [what, vn, " *neuloženo" if dirty else "", sels.size()]

# ---- selection ------------------------------------------------------------------------------------------
func _set_sel(ids: Array, active := -1) -> void:
	sels = []
	for i in ids:
		if not int(i) in sels:
			sels.append(int(i))
	sel = active if active >= 0 else (sels[-1] if not sels.is_empty() else -1)
	if sel >= 0 and not sel in sels:
		sels.append(sel)
	_after_change(false)

func _toggle(i: int) -> void:
	if i in sels:
		sels.erase(i)
		_set_sel(sels)
	else:
		sels.append(i)
		_set_sel(sels, i)

func _select_all() -> void:
	var all := []
	for i in _els().size():
		if not _is_ground(i) and _kind_of(i) != "grass":
			all.append(i)
	_set_sel(all)
	status.text = "Vybráno vše kromě země (%d částí)." % sels.size()

func _select_same_mat() -> void:
	if sel < 0:
		return
	var want = _els()[sel].get("m", null)
	if want == null:
		return
	var out := []
	for i in _els().size():
		if _els()[i].get("m", null) == want:
			out.append(i)
	_set_sel(out, sel)

func _label(i: int) -> String:
	var e: Dictionary = _els()[i]
	var k := String(e.get("k", ""))
	var t := String(KIND_NAMES.get(k, k))
	match k:
		"box", "solid":
			var s := _v3(e.get("s", [1, 1, 1]))
			t += " %.2f × %.2f × %.2f m" % [s.x, s.y, s.z]
			if _is_ground(i):
				t = "Zem"
		"cyl":
			t += " ⌀%.2f × %.2f m" % [maxf(float(e["rt"]), float(e["rb"])) * 2, float(e["h"])]
		"model":
			t += ": " + String(e["n"]).trim_prefix("v_").replace("_", " ")
		"point":
			for n in NOTES:
				if n[0] == String(e.get("t", "")):
					t = String(n[1])
		"spot":
			t += ": " + String(SPOTS.get(String(e.get("t", "")), e.get("t", "")))
		"sound":
			t += ": " + String(e.get("n", ""))
	if e.has("m") and e["m"] is Array and (e["m"] as Array).size() > 1 and String(e["m"][0]) == "t":
		t += " · " + String(e["m"][1])
	if e.has("br"):
		t += " · rozbitné"
	return t

func _note_color(i: int) -> Color:
	var e: Dictionary = _els()[i]
	var k := String(e.get("k", ""))
	var key := String(e.get("t", "")) if k == "point" else k
	for n in NOTES:
		if n[0] == key:
			return n[2]
	match k:
		"light": return Color(1.0, 0.88, 0.4)
		"fire": return Color(1.0, 0.5, 0.15)
		"spot": return Color(1.0, 0.3, 0.8)
		"link": return Color(0.6, 0.8, 1.0)
	if e.has("m") and e["m"] is Array and String(e["m"][0]) == "c":
		var c: Array = e["m"][1]
		return Color(c[0], c[1], c[2])
	return EdUI.TEXT

func _fill_parts() -> void:
	_updating = true
	part_list.clear()
	_list_ids.clear()
	_list_pos.clear()
	for i in _els().size():
		part_list.add_item("%d  %s" % [i + 1, _label(i)])
		part_list.set_item_custom_fg_color(part_list.item_count - 1, EdUI.AMBER if i == sel else (_note_color(i) if not _els()[i].has("m") else EdUI.TEXT))
		_list_pos[i] = _list_ids.size()
		_list_ids.append(i)
		if i in sels:
			part_list.select(part_list.item_count - 1, false)
	if sel >= 0:
		part_list.ensure_current_is_visible()
	_updating = false

func _sync_list() -> void:
	_updating = true
	part_list.deselect_all()
	for r in part_list.item_count:
		var i: int = _list_ids[r]
		part_list.set_item_custom_fg_color(r, EdUI.AMBER if i == sel else (_note_color(i) if not _els()[i].has("m") else EdUI.TEXT))
	for i in sels:
		var r: int = _list_pos.get(i, -1)
		if r >= 0:
			part_list.select(r, false)
	if sel >= 0:
		part_list.ensure_current_is_visible()
	_updating = false

func _from_list() -> void:
	if _updating:
		return
	var ids := []
	for r in part_list.get_selected_items():
		ids.append(_list_ids[r])
	var act: int = sel if sel in ids else (int(ids[-1]) if not ids.is_empty() else -1)
	_updating = true
	sels = ids
	sel = act
	_refresh_fields()
	_title()
	_updating = false

# ---- numbers and properties -------------------------------------------------------------------------------
func _refresh_fields() -> void:
	_updating = true
	var on := sel >= 0 and sel < _els().size()
	var k := _kind_of(sel) if on else ""
	for key in _f:
		(_f[key] as SpinBox).editable = on and not (key.begins_with("rot") and not k in ["box", "solid", "cyl", "ball", "model"]) \
			and not (key.begins_with("scl") and not k in ["box", "solid", "cyl", "ball", "model"])
	if on:
		var e: Dictionary = _els()[sel]
		var p := _v3(e.get("p", [0, 0, 0])) if e.has("p") else _center_of(sel)
		var r := _v3(e.get("r", [0, 0, 0]))
		var s := Vector3.ONE
		match k:
			"box", "solid": s = _v3(e.get("s", [1, 1, 1])) * 100.0
			"cyl", "ball", "model": s = _v3(e.get("sc", [1, 1, 1])) * 100.0
		for i in 3:
			(_f["pos%d" % i] as SpinBox).value = snappedf(p[i] * 100.0, 0.1)
			(_f["rot%d" % i] as SpinBox).value = snappedf(r[i], 0.1)
			(_f["scl%d" % i] as SpinBox).value = snappedf(s[i], 0.1)
		_scl_lbl.text = "Rozměr (cm)" if k in ["box", "solid"] else ("Velikost (%)" if k in ["cyl", "ball", "model"] else "Rozměr (u značek se nemění)")
	_updating = false
	_fill_props()

func _on_field(key: String, val: float) -> void:
	if _updating or sel < 0:
		return
	var ax := int(key.right(1))
	var kd := key.left(3)
	var e0: Dictionary = _els()[sel]
	var k0 := _kind_of(sel)
	var delta := 0.0
	match kd:
		"pos":
			var p0 := _v3(e0.get("p", [0, 0, 0])) if e0.has("p") else _center_of(sel)
			delta = val / 100.0 - p0[ax]
		"rot":
			delta = val - _v3(e0.get("r", [0, 0, 0]))[ax]
		"scl":
			var s0 := _v3(e0.get("s", [1, 1, 1])) if k0 in ["box", "solid"] else _v3(e0.get("sc", [1, 1, 1]))
			delta = (val / 100.0) / maxf(s0[ax], 0.0001)
	_push()
	for i in sels:
		var e: Dictionary = _els()[i]
		var k := _kind_of(i)
		match kd:
			"pos":
				if e.has("p"):
					var p := _v3(e["p"])
					p[ax] += delta
					e["p"] = MapPieces._v(p)
				else:
					var f := _frame(i)
					f.origin[ax] += delta
					_set_frame(i, f)
			"rot":
				if k in ["box", "solid", "cyl", "ball", "model"]:
					var r := _v3(e.get("r", [0, 0, 0]))
					r[ax] += delta
					_put_rot(e, r)
			"scl":
				if k in ["box", "solid"]:
					var s := _v3(e.get("s", [1, 1, 1]))
					s[ax] = clampf(s[ax] * delta, 0.005, 200.0)
					e["s"] = MapPieces._v(s)
				elif k in ["cyl", "ball", "model"]:
					var s := _v3(e.get("sc", [1, 1, 1]))
					s[ax] = clampf(s[ax] * delta, 0.01, 50.0)
					e["sc"] = MapPieces._v(s)
	_commit(sels.duplicate())

## The properties of the active part (material, solid, breakable, light, door...).
func _fill_props() -> void:
	var k := _kind_of(sel)
	var key := "%d|%s|%d" % [sel, k, _els().size()]
	if key == _props_for:
		return
	_props_for = key
	for c in _props.get_children():
		c.queue_free()
	if sel < 0:
		EdUI.lbl(_props, "Nic není vybráno.", EdUI.DIM, 12)
		return
	var e: Dictionary = _els()[sel]
	match k:
		"box", "cyl", "ball":
			var m: Array = e.get("m", ["c", [0.5, 0.5, 0.5, 1.0]])
			var r := EdUI.row(_props)
			EdUI.lbl(r, "Materiál", EdUI.DIM, 12)
			var items := [["", "(barva)"]] + _tex_names.map(func(t): return [t, t])
			var o := EdUI.opt(r, items, func(t):
				_set_prop(func(x: Dictionary):
					var old: Array = x.get("m", [])
					var sc := float(old[2]) if old.size() > 2 and String(old[0]) == "t" else 0.5
					x["m"] = ["t", String(t), sc, [0, 0, 0, 1]] if String(t) != "" else ["c", [0.5, 0.5, 0.5, 1.0], false, 0.0, 1.0]))
			o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			o.fit_to_longest_item = false
			EdUI.opt_select(o, String(m[1]) if String(m[0]) == "t" else "")
			var r2 := EdUI.row(_props)
			if String(m[0]) == "t":
				EdUI.lbl(r2, "Hustota textury", EdUI.DIM, 12)
				var s := EdUI.spin(r2, 0.05, 8.0, 0.05, func(val):
					_set_prop(func(x: Dictionary):
						if x.get("m", [""])[0] == "t":
							x["m"][2] = val))
				s.set_value_no_signal(float(m[2]) if m.size() > 2 else 0.5)
			else:
				EdUI.lbl(r2, "Barva", EdUI.DIM, 12)
				var cb := ColorPickerButton.new()
				cb.custom_minimum_size = Vector2(80, 26)
				cb.edit_alpha = false
				var c: Array = m[1]
				cb.color = Color(c[0], c[1], c[2])
				cb.color_changed.connect(func(col):
					_set_prop(func(x: Dictionary):
						if x.get("m", [""])[0] == "c":
							x["m"][1] = [snappedf(col.r, 0.001), snappedf(col.g, 0.001), snappedf(col.b, 0.001), 1.0]))
				r2.add_child(cb)
				EdUI.check(r2, "Svítí", bool(m[2]) if m.size() > 2 else false, func(on):
					_set_prop(func(x: Dictionary):
						if x.get("m", [""])[0] == "c":
							while (x["m"] as Array).size() < 5:
								x["m"].append([false, 0.0, 1.0][(x["m"] as Array).size() - 2])
							x["m"][2] = on))
			var r3 := EdUI.row(_props)
			EdUI.check(r3, "Pevné", bool(e.get("c", true)), func(on): _set_prop(func(x: Dictionary): x["c"] = on), "Nedá se jím projít, kulky ho nepropustí")
			EdUI.check(r3, "Viditelné", bool(e.get("vis", true)), func(on):
				_set_prop(func(x: Dictionary):
					if on: x.erase("vis")
					else: x["vis"] = false), "Neviditelná zeď (třeba kolem krávy)")
			var r4 := EdUI.row(_props)
			EdUI.lbl(r4, "Rozbitné", EdUI.DIM, 12)
			var ob := EdUI.opt(r4, BREAKS, func(b):
				_set_prop(func(x: Dictionary):
					if String(b) == "": x.erase("br")
					else: x["br"] = String(b)))
			ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			EdUI.opt_select(ob, String(e.get("br", "")))
			if k == "cyl":
				var r5 := EdUI.row(_props)
				EdUI.lbl(r5, "Nahoře / dole (cm)", EdUI.DIM, 12)
				var st := EdUI.spin(r5, 0, 2000, 1, func(val): _set_prop(func(x: Dictionary): x["rt"] = val / 100.0))
				st.set_value_no_signal(float(e["rt"]) * 100.0)
				var sb := EdUI.spin(r5, 0, 2000, 1, func(val): _set_prop(func(x: Dictionary): x["rb"] = val / 100.0))
				sb.set_value_no_signal(float(e["rb"]) * 100.0)
		"model":
			var r := EdUI.row(_props)
			EdUI.lbl(r, "Model", EdUI.DIM, 12)
			var o := EdUI.opt(r, _model_names(), func(n): _set_prop(func(x: Dictionary): x["n"] = String(n)))
			o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			o.fit_to_longest_item = false
			EdUI.opt_select(o, String(e["n"]))
			EdUI.check(_props, "Smí se posunout (když vadí)", bool(e.get("volne", false)), func(on): _set_prop(func(x: Dictionary): x["volne"] = on),
				"Když na mapě stojí v cestě něčemu jinému, posune se kousek vedle (nebo zmizí)")
		"light":
			var r := EdUI.row(_props)
			EdUI.lbl(r, "Barva", EdUI.DIM, 12)
			var cb := ColorPickerButton.new()
			cb.custom_minimum_size = Vector2(80, 26)
			cb.edit_alpha = false
			var c: Array = e.get("col", [1, 1, 1])
			cb.color = Color(c[0], c[1], c[2])
			cb.color_changed.connect(func(col): _set_prop(func(x: Dictionary): x["col"] = [snappedf(col.r, 0.001), snappedf(col.g, 0.001), snappedf(col.b, 0.001)]))
			r.add_child(cb)
			var r2 := EdUI.row(_props)
			EdUI.lbl(r2, "Síla / dosah (m)", EdUI.DIM, 12)
			var se := EdUI.spin(r2, 0, 20, 0.1, func(val):
				_set_prop(func(x: Dictionary):
					x["e"] = val
					if x.has("base"): x["base"] = val))
			se.set_value_no_signal(float(e.get("e", 1.0)))
			var sr := EdUI.spin(r2, 0.5, 60, 0.5, func(val): _set_prop(func(x: Dictionary): x["rng"] = val))
			sr.set_value_no_signal(float(e.get("rng", 5.0)))
			var r3 := EdUI.row(_props)
			EdUI.check(r3, "Stín", bool(e.get("stin", false)), func(on): _set_prop(func(x: Dictionary): x["stin"] = on))
			EdUI.check(r3, "Na proud", bool(e.get("elektr", false)), func(on): _set_prop(func(x: Dictionary): x["elektr"] = on), "Zhasne, když vetřelci vyřadí proud")
			EdUI.check(r3, "Mihotá", bool(e.get("mihot", false)), func(on):
				_set_prop(func(x: Dictionary):
					x["mihot"] = on
					x["ohen"] = on), "Mihotavé světlo ohně")
		"door":
			var r := EdUI.row(_props)
			EdUI.lbl(r, "Šířka / výška (cm)", EdUI.DIM, 12)
			var sw := EdUI.spin(r, 50, 400, 5, func(val): _set_prop(func(x: Dictionary): x["w"] = val / 100.0))
			sw.set_value_no_signal(float(e.get("w", 1.5)) * 100.0)
			var sh := EdUI.spin(r, 100, 400, 5, func(val): _set_prop(func(x: Dictionary): x["h"] = val / 100.0))
			sh.set_value_no_signal(float(e.get("h", 2.15)) * 100.0)
			var r2 := EdUI.row(_props)
			EdUI.check(r2, "Ve zdi podél X", bool(e.get("x", true)), func(on): _set_prop(func(x: Dictionary): x["x"] = on))
			EdUI.check(r2, "Otevřené", bool(e.get("open", false)), func(on): _set_prop(func(x: Dictionary): x["open"] = on))
			EdUI.lbl(_props, "Dveře se pověsí do mezery ve zdi: zeď v tom místě musí mít otvor.", EdUI.DIM, 11, true)
		"window":
			var r := EdUI.row(_props)
			EdUI.lbl(r, "Šířka / parapet (cm)", EdUI.DIM, 12)
			var sw := EdUI.spin(r, 30, 400, 5, func(val): _set_prop(func(x: Dictionary): x["w"] = val / 100.0))
			sw.set_value_no_signal(float(e.get("w", 1.0)) * 100.0)
			var ss := EdUI.spin(r, 0, 200, 5, func(val): _set_prop(func(x: Dictionary): x["sill"] = val / 100.0))
			ss.set_value_no_signal(float(e.get("sill", 0.9)) * 100.0)
			EdUI.check(_props, "Ve zdi podél X", absf(_v3(e.get("n", [0, 0, 1])).z) > 0.5, func(on):
				_set_prop(func(x: Dictionary): x["n"] = [0, 0, 1] if on else [1, 0, 0]))
		"sound":
			var r := EdUI.row(_props)
			EdUI.lbl(r, "Zvuk / hlasitost (dB)", EdUI.DIM, 12)
			var o := EdUI.opt(r, SOUNDS.map(func(s): return [s, s]), func(s): _set_prop(func(x: Dictionary): x["n"] = String(s)))
			EdUI.opt_select(o, String(e.get("n", "static")))
			var sd := EdUI.spin(r, -60, 0, 1, func(val): _set_prop(func(x: Dictionary): x["db"] = val))
			sd.set_value_no_signal(float(e.get("db", -18.0)))
		"point":
			var r := EdUI.row(_props)
			EdUI.lbl(r, "Druh značky", EdUI.DIM, 12)
			var o := EdUI.opt(r, NOTES.filter(func(n): return not n[0] in ["door", "window", "sound"]).map(func(n): return [n[0], n[1]]),
				func(t): _set_prop(func(x: Dictionary): x["t"] = String(t)))
			o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			o.fit_to_longest_item = false
			EdUI.opt_select(o, String(e.get("t", "")))
		"grass":
			var r := EdUI.row(_props)
			EdUI.lbl(r, "Stébel / výška (cm)", EdUI.DIM, 12)
			var sn := EdUI.spin(r, 0, 5000, 50, func(val): _set_prop(func(x: Dictionary): x["n"] = int(val)))
			sn.set_value_no_signal(float(e.get("n", 300)))
			var smx := EdUI.spin(r, 10, 300, 5, func(val): _set_prop(func(x: Dictionary): x["max"] = val / 100.0))
			smx.set_value_no_signal(float(e.get("max", 1.3)) * 100.0)
			EdUI.lbl(_props, "Tráva roste po celém dílu kromě míst, kde stojí něco pevného.", EdUI.DIM, 11, true)
		"spot":
			EdUI.lbl(_props, "Místo, které hledá mise: %s." % SPOTS.get(String(e.get("t", "")), e.get("t", "")), EdUI.DIM, 12, true)
		"fire":
			var r := EdUI.row(_props)
			EdUI.lbl(r, "Plamenů", EdUI.DIM, 12)
			var sn := EdUI.spin(r, 4, 80, 1, func(val): _set_prop(func(x: Dictionary): x["n"] = int(val)))
			sn.set_value_no_signal(float(e.get("n", 20)))
		_:
			EdUI.lbl(_props, String(KIND_NAMES.get(k, k)), EdUI.DIM, 12, true)

## Changes every selected part of the same kind as the active one.
func _set_prop(fn: Callable) -> void:
	if _updating or sel < 0:
		return
	var k := _kind_of(sel)
	_push()
	var touched := []
	for i in sels:
		if _kind_of(i) == k or (k in ["box", "cyl", "ball"] and _kind_of(i) in ["box", "cyl", "ball"]):
			fn.call(_els()[i])
			touched.append(i)
	_props_for = ""       # (the material type may have changed: the panel again)
	_commit(touched)

# ---- adding and editing -------------------------------------------------------------------------------
func _need_sel() -> bool:
	if sels.is_empty():
		status.text = "Nejdřív vyber část (klik do obrázku nebo do seznamu)."
		return false
	return true

## Where a new part goes: beside the active one, or the middle of the view.
func _new_at() -> Vector3:
	if sel >= 0:
		return _center_of(sel) + cam.global_transform.basis.x * 1.0
	return Vector3(target.x, 0.0, target.z)

func _add(e: Dictionary) -> void:
	_push()
	var at := _new_at()
	var ne := e.duplicate(true)
	match String(ne["k"]):
		"box": at.y = maxf(at.y, 0.5)
		"cyl": at.y = maxf(at.y, float(ne["h"]) / 2)
		"ball": at.y = maxf(at.y, float(ne["rad"]))
		"light": at.y = maxf(at.y, 2.4)
		"model": at.y = 0.0
	ne["p"] = MapPieces._v(at)
	_els().append(ne)
	_commit()
	_set_sel([_els().size() - 1])
	status.text = "Přidáno: %s. Táhni to úchyty nebo bílou tečkou." % _label(_els().size() - 1)

func _add_note() -> void:
	var t := String(_note_opt.get_item_metadata(_note_opt.selected))
	match t:
		"door": _add({"k": "door", "x": true, "w": 1.5, "h": 2.15, "open": false})
		"window": _add({"k": "window", "n": [0, 0, 1], "sill": 0.9, "w": 1.0})
		"sound": _add({"k": "sound", "n": "static", "db": -18.0})
		_: _add({"k": "point", "t": t})

func _add_fire() -> void:
	_push()
	var at := _new_at()
	at.y = maxf(at.y, 0.2)
	_els().append({"k": "fire", "n": 20, "p": MapPieces._v(at)})
	_els().append({"k": "light", "t": "omni", "col": [1.0, 0.45, 0.12], "e": 1.6, "rng": 5.0, "stin": false, "mihot": true, "ohen": true,
		"p": MapPieces._v(at + Vector3(0, 0.6, 0))})
	_els().append({"k": "sound", "n": "fire", "db": -18.0, "p": MapPieces._v(at)})
	_commit()
	var n := _els().size()
	_set_sel([n - 3, n - 2, n - 1], n - 3)
	status.text = "Oheň: plameny, světlo a praskání (tři části, posouvej je spolu)."

func _copies(ids: Array, off: Vector3) -> Array:
	var made := []
	for i in ids:
		var ne: Dictionary = (_els()[i] as Dictionary).duplicate(true)
		if String(ne.get("k", "")) in ["woodroof", "grass"]:
			continue
		ne.erase("lens")
		ne.erase("na")
		_els().append(ne)
		var j := _els().size() - 1
		var f := _frame(i)
		f.origin += off
		_set_frame(j, f)
		made.append(j)
	return made

func _duplicate_sel() -> void:
	if not _need_sel():
		return
	_push()
	var off := cam.global_transform.basis.x * 0.6
	off.y = 0.0
	var made := _copies(sels, off)
	_commit()
	_set_sel(made)
	status.text = "Kopie hotová (%d částí) – posuň ji, kam patří." % made.size()

## Mirror copies across the middle of the block (left - right).
func _mirror_sel() -> void:
	if not _need_sel():
		return
	_push()
	var made := []
	for i in sels:
		var ne: Dictionary = (_els()[i] as Dictionary).duplicate(true)
		if String(ne.get("k", "")) in ["woodroof", "grass"]:
			continue
		ne.erase("lens")
		ne.erase("na")
		_els().append(ne)
		var j := _els().size() - 1
		var f := _frame(i)
		# mirror across x = 6: the box is the same box turned (a block mirrored = itself turned)
		var b := f.basis
		var s := Vector3(b.x.length(), b.y.length(), b.z.length())
		var e := Basis(b.x / maxf(s.x, 1e-6), b.y / maxf(s.y, 1e-6), b.z / maxf(s.z, 1e-6)).orthonormalized().get_euler()
		var mb := Basis.from_euler(Vector3(e.x, -e.y, -e.z)).scaled_local(s)
		_set_frame(j, Transform3D(mb, Vector3(BLOCK - f.origin.x, f.origin.y, f.origin.z)))
		if String(ne.get("k", "")) == "link":
			var a := _v3(ne["a"])
			var bb := _v3(ne["b"])
			ne["a"] = MapPieces._v(Vector3(BLOCK - a.x, a.y, a.z))
			ne["b"] = MapPieces._v(Vector3(BLOCK - bb.x, bb.y, bb.z))
		made.append(j)
	_commit()
	_set_sel(made)
	status.text = "Zrcadlová kopie (%d částí) na druhé straně dílu." % made.size()

func _turn90() -> void:
	if not _need_sel():
		return
	_push()
	var pv := _pivot()
	var r := Transform3D(Basis(Vector3.UP, PI / 2), Vector3.ZERO)
	for i in sels:
		var f := _frame(i)
		_set_frame(i, Transform3D(Basis(), pv) * r * Transform3D(Basis(), -pv) * f)
		var e: Dictionary = _els()[i]
		if String(e.get("k", "")) == "door":
			e["x"] = not bool(e.get("x", true))
		elif String(e.get("k", "")) == "window":
			var n := _v3(e.get("n", [0, 0, 1]))
			e["n"] = MapPieces._v(Vector3(n.z, 0, -n.x))
	_commit()

func _copy() -> void:
	if not _need_sel():
		return
	_clip = []
	for i in sels:
		var ne: Dictionary = (_els()[i] as Dictionary).duplicate(true)
		if String(ne.get("k", "")) in ["woodroof", "grass"]:
			continue
		ne.erase("lens")
		ne.erase("na")
		_clip.append(ne)
	status.text = "Zkopírováno %d částí (Ctrl+V vloží, i do jiného dílu)." % _clip.size()

func _paste() -> void:
	if _clip.is_empty():
		status.text = "Schránka je prázdná (Ctrl+C)."
		return
	_push()
	var made := []
	for ne0 in _clip:
		_els().append((ne0 as Dictionary).duplicate(true))
		made.append(_els().size() - 1)
	_commit()
	_set_sel(made)
	status.text = "Vloženo %d částí (na stejné místo jako v původním dílu)." % made.size()

func _delete_sel() -> void:
	if not _need_sel():
		return
	_push()
	var gone := sels.duplicate()
	gone.sort()
	# numbers of the parts after the deleted ones move down: the links between parts too
	var remap := {}
	var j := 0
	for i in _els().size():
		if i in gone:
			continue
		remap[i] = j
		j += 1
	var keep := []
	for i in _els().size():
		if i in gone:
			continue
		var e: Dictionary = _els()[i]
		if e.has("lens"):
			if remap.has(int(e["lens"])):
				e["lens"] = remap[int(e["lens"])]
			else:
				e.erase("lens")
		if e.has("na"):
			var na := []
			for hi in e["na"]:
				if remap.has(int(hi)):
					na.append(remap[int(hi)])
			if na.is_empty():
				e.erase("na")
			else:
				e["na"] = na
		if String(e.get("k", "")) == "woodroof":
			if not remap.has(int(e.get("i", -1))):
				continue
			e["i"] = remap[int(e["i"])]
		keep.append(e)
	work["prvky"] = keep
	sels = []
	sel = -1
	_commit()
	status.text = "Smazáno %d částí (Ctrl+Z vrátí)." % gone.size()

func _nudge(d: Vector3, mult: float) -> void:
	if not _need_sel():
		return
	var w := d * 0.05 * mult
	_push()
	for i in sels:
		var f := _frame(i)
		f.origin += w
		_set_frame(i, f)
	_commit(sels.duplicate())

# ---- saving --------------------------------------------------------------------------------------------
func _slug(s: String) -> String:
	var t := s.to_lower().strip_edges()
	var from := "áčďéěíňóřšťúůýž"
	var to := "acdeeinorstuuyz"
	var out := ""
	for ch in t:
		var k := from.find(ch)
		if k >= 0:
			out += to[k]
		elif (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
		elif out != "" and not out.ends_with("_"):
			out += "_"
	return out.trim_suffix("_")

func _save(as_new: bool) -> void:
	var file := variant
	if file == "" or as_new:
		var base := _slug(String(work.get("nazev", "")))
		if base == "":
			base = kind
		file = base
		var n := 2
		var have := MapPieces.designs(kind).map(func(d): return String(d["_soubor"]))
		while file in have:
			file = "%s_%d" % [base, n]
			n += 1
		if String(work.get("nazev", "")) == "":
			work["nazev"] = "%s %d" % [String(MapPieces.KINDS[kind][2]), have.size() + 1]
	var path := MapPieces.save(kind, file, work)
	if path == "":
		status.text = "Uložení se nepovedlo (%s)." % MapPieces.save_dir()
		Game.play_ui(self, "ui_deny", -6)
		return
	variant = file
	dirty = false
	_updating = true
	_name_edit.text = String(work.get("nazev", ""))
	_updating = false
	_fill_kinds()
	_fill_variants()
	_title()
	status.text = "Uloženo: %s – mapy ho od teď používají." % path
	Game.play_ui(self, "ui_confirm", -6)

func _delete_variant() -> void:
	if variant == "":
		status.text = "Vygenerovaná varianta se smazat nedá (není uložená)."
		return
	EdUI.ask(self, "Smazat uloženou variantu „%s“?" % work.get("nazev", variant), func():
		MapPieces.remove(kind, variant)
		_load(kind, "", gen_seed)
		status.text = "Varianta smazána.", "Smazat")

# ---- the view ----------------------------------------------------------------------------------------
func _process(_d: float) -> void:
	var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	cam.position = target + dir * dist
	cam.look_at(target, Vector3.UP if absf(pitch) < 1.5 else Vector3.FORWARD)
	cam.near = 0.05
	cam.far = 400.0
	_draw_overlay()

func _view_from(k: int) -> void:
	yaw = [PI, PI / 2, PI][k]
	pitch = [-0.05, -0.05, -1.55][k]

func _focus() -> void:
	if sels.is_empty():
		target = Vector3(6, 0.5, 6)
		dist = 22.0
		return
	target = _pivot()
	var r := 0.0
	for i in sels:
		for c in _corners(i):
			r = maxf(r, (c as Vector3).distance_to(target))
	dist = clampf(r * 3.0, 1.0, 60.0)

func _axes() -> Array:
	return [Vector3.RIGHT, Vector3.UP, Vector3.BACK]

func _pivot() -> Vector3:
	if sels.is_empty():
		return Vector3.ZERO
	var c := Vector3.ZERO
	for i in sels:
		c += _center_of(i)
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

## The nearest part under the mouse (its box): -1 = none.
func _pick(m: Vector2) -> int:
	var p := _vp(m)
	var o := cam.project_ray_origin(p)
	var d := cam.project_ray_normal(p)
	var best := -1
	var bd := 1e9
	var unit := AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
	for i in _els().size():
		var k := _kind_of(i)
		if k == "grass" or (not _pick_ground and _is_ground(i)):
			continue
		var f := _frame(i)
		if absf(f.basis.determinant()) < 1e-9:
			continue
		var inv := f.affine_inverse()
		var lo := inv * o
		var ld := inv.basis * d
		var hit = unit.intersects_ray(lo, ld)
		if hit == null:
			continue
		var dd: float = (f * (hit as Vector3)).distance_to(o)
		if k == "model":
			# a model's box is much bigger than the model (a roof over the whole house): its triangles
			var lx := MapPieces.local_xf(_els()[i])
			var li := lx.affine_inverse()
			var mo := li * o
			var md := (li.basis * d).normalized()
			var tris := MapPieces.model_tris(String(_els()[i]["n"]))
			var best_t := INF
			for t in range(0, tris.size(), 3):
				var th = Geometry3D.ray_intersects_triangle(mo, md, tris[t], tris[t + 1], tris[t + 2])
				if th != null:
					best_t = minf(best_t, (lx * (th as Vector3)).distance_to(o))
			if best_t == INF:
				continue
			dd = best_t
		# notes and lights are small: they win over the wall right behind them
		if not _els()[i].has("m") and k != "model":
			dd -= 0.5
		if dd < bd:
			bd = dd
			best = i
	return best

func _start_drag(kd: String, ax: int, m: Vector2) -> void:
	_push()
	_drag = kd
	_drag_axis = ax
	_drag_from = m
	_drag_start = {}
	for i in sels:
		_drag_start[i] = _frame(i)
	_drag_pivot = _pivot()
	var p := _vp(m)
	_drag_plane = Plane(Vector3.UP, _drag_pivot) if kd == "move" else Plane(-cam.global_transform.basis.z, _drag_pivot)
	if kd == "move" and absf(cam.global_transform.basis.z.y) < 0.15:
		_drag_plane = Plane(-cam.global_transform.basis.z, _drag_pivot)      # looking from the side: up and down too
	var hit = _drag_plane.intersects_ray(cam.project_ray_origin(p), cam.project_ray_normal(p))
	_drag_hit0 = hit if hit != null else _drag_pivot
	if kd == "gizmo" and ax >= 0 and ax < 3:
		var axes := _axes()
		var l := _glen(_drag_pivot)
		var sv := _scr(_drag_pivot + axes[ax] * l) - _scr(_drag_pivot)
		_drag_dir = sv.normalized() if sv.length() > 1.0 else Vector2.RIGHT
		_drag_scale = l / maxf(sv.length(), 1.0)

func _drag_to(m: Vector2, coarse: bool) -> void:
	if _drag == "move" or (_drag == "gizmo" and _drag_axis == DOT and mode != "velikost"):
		var p := _vp(m)
		var hit = _drag_plane.intersects_ray(cam.project_ray_origin(p), cam.project_ray_normal(p))
		if hit == null:
			return
		var off: Vector3 = hit - _drag_hit0
		var st := 0.25 if coarse else 0.05
		off = (off / st).round() * st
		for i in _drag_start:
			var w: Transform3D = _drag_start[i]
			w.origin += off
			_set_frame(i, w)
		status.text = "Posun: %.2f, %.2f, %.2f m" % [off.x, off.y, off.z]
	elif _drag == "gizmo":
		var axes := _axes()
		match mode:
			"posun":
				var dw := (m - _drag_from).dot(_drag_dir) * _drag_scale
				dw = snappedf(dw, 0.25 if coarse else 0.05)
				for i in _drag_start:
					var w: Transform3D = _drag_start[i]
					w.origin += axes[_drag_axis] * dw
					_set_frame(i, w)
				status.text = "Posun: %.2f m" % dw
			"otaceni":
				var so := _scr(_drag_pivot)
				var a0 := (_drag_from - so).angle()
				var a1 := (m - so).angle()
				var ang := wrapf(a1 - a0, -PI, PI)
				var ax: Vector3 = axes[_drag_axis]
				if ax.dot(cam.global_transform.basis.z) < 0.0:
					ang = -ang
				ang = -ang
				ang = snappedf(ang, deg_to_rad(15.0) if coarse else deg_to_rad(1.0))
				var r := Transform3D(Basis(ax, ang), Vector3.ZERO)
				for i in _drag_start:
					var w: Transform3D = _drag_start[i]
					_set_frame(i, Transform3D(Basis(), _drag_pivot) * r * Transform3D(Basis(), -_drag_pivot) * w)
				status.text = "Otočení: %.0f°" % rad_to_deg(ang)
			"velikost":
				if _drag_axis == DOT:
					var f := maxf(1.0 + (m.x - _drag_from.x - (m.y - _drag_from.y)) * 0.005, 0.02)
					f = snappedf(f, 0.1 if coarse else 0.01)
					for i in _drag_start:
						var w: Transform3D = _drag_start[i]
						_set_frame(i, Transform3D(w.basis * Basis.from_scale(Vector3.ONE * f), _drag_pivot + (w.origin - _drag_pivot) * f))
					status.text = "Velikost: %.0f %%" % (f * 100.0)
				else:
					var ax2: Vector3 = axes[_drag_axis]
					var dw := (m - _drag_from).dot(_drag_dir) * _drag_scale
					var ext := 0.0
					for i in _drag_start:
						var w0: Transform3D = _drag_start[i]
						var u := AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
						for k in 8:
							ext = maxf(ext, absf((w0 * u.get_endpoint(k) - _drag_pivot).dot(ax2)))
					ext = maxf(ext, 0.05)
					var f := maxf((ext + dw) / ext, 0.02)
					f = snappedf(f, 0.1 if coarse else 0.01)
					for i in _drag_start:
						var w: Transform3D = _drag_start[i]
						var best := 0
						var bd := -1.0
						for k in 3:
							var dd := absf(w.basis[k].normalized().dot(ax2))
							if dd > bd:
								bd = dd
								best = k
						var sv := Vector3.ONE
						sv[best] = f
						var rel := w.origin - _drag_pivot
						_set_frame(i, Transform3D(w.basis * Basis.from_scale(sv), _drag_pivot + rel + ax2 * rel.dot(ax2) * (f - 1.0)))
					status.text = "Velikost: %.0f %%" % (f * 100.0)
	for i in _drag_start:
		_rebuild_el(int(i))
	_refresh_fields()

func _view_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.pressed:
			get_viewport().gui_release_focus()
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					dist = maxf(0.5, dist * 0.9)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					dist = minf(120.0, dist * 1.1)
			MOUSE_BUTTON_RIGHT:
				_drag = ("pan" if mb.shift_pressed else "orbit") if mb.pressed else ""
			MOUSE_BUTTON_MIDDLE:
				_drag = "pan" if mb.pressed else ""
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					var ax := _gizmo_hit(mb.position)
					if ax >= 0:
						if mb.shift_pressed and mode == "posun":
							_push()
							var made := _copies(sels, Vector3.ZERO)
							_commit()
							_set_sel(made)
							status.text = "Kopie – táhni ji, kam patří."
						_start_drag("gizmo", ax, mb.position)
						return
					var id := _pick(mb.position)
					if id >= 0 and id in sels and not (mb.shift_pressed or mb.ctrl_pressed):
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
								if id >= 0:
									_toggle(id)
							else:
								_set_sel([id] if id >= 0 else [])
							if id < 0 and not (mb.shift_pressed or mb.ctrl_pressed):
								status.text = "Nic nevybráno. (Táhni obdélník přes části, nebo klikni na část.)"
							elif id >= 0:
								status.text = "%d  %s" % [id + 1, _label(id)]
						"rect":
							_rect_select(mb.shift_pressed or mb.ctrl_pressed)
						"gizmo", "move":
							_commit(sels.duplicate())
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
	for i in _els().size():
		if _is_ground(i) or _kind_of(i) == "grass":
			continue
		var c := _center_of(i)
		if cam.is_position_behind(c):
			continue
		if r.has_point(_scr(c)) and not i in ids:
			ids.append(i)
	_set_sel(ids)
	status.text = "Vybráno %d částí." % sels.size()

func _set_mode(m: String) -> void:
	mode = m
	for k in _tool_btns:
		(_tool_btns[k] as Button).button_pressed = k == m
	_show_hint()

func _show_hint() -> void:
	if hint:
		hint.text = "Levé: výběr (Shift/Ctrl přidá), tah po prázdnu = obdélník, tah části = posun po zemi · úchyty: %s (Ctrl = po 25 cm / 15°, Shift + šipka = kopie) · Pravé: otáčet pohled · Střední / Shift+pravé: posun pohledu · Kolečko: zoom · G/R/S · Ctrl+A · Ctrl+D kopie · M zrcadlo · Del · šipky/PgUp/PgDn po 5 cm (Shift po 50) · Ctrl+Z/Y · Ctrl+S" % TOOLS[mode]
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
		KEY_S when k.ctrl_pressed: _save(false)
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

# ---- the overlay ---------------------------------------------------------------------------------------
func _draw_overlay() -> void:
	ov.clear()
	# the block's edge
	var y0 := 0.02
	var edge := Color(1.0, 0.74, 0.32, 0.55)
	ov.line(Vector3(0, y0, 0), Vector3(BLOCK, y0, 0), edge, 1.5)
	ov.line(Vector3(BLOCK, y0, 0), Vector3(BLOCK, y0, BLOCK), edge, 1.5)
	ov.line(Vector3(BLOCK, y0, BLOCK), Vector3(0, y0, BLOCK), edge, 1.5)
	ov.line(Vector3(0, y0, BLOCK), Vector3(0, y0, 0), edge, 1.5)
	# notes, lights, the invisible parts
	for i in (_els().size() if _show_notes else 0):
		var e: Dictionary = _els()[i]
		var k := String(e.get("k", ""))
		match k:
			"point", "spot", "light", "sound", "fire":
				var c := _note_color(i)
				var p := _center_of(i)
				if not cam.is_position_behind(p):
					ov.dot(p, Color(0, 0, 0, 0.7), 11.0)
					ov.dot(p, c, 8.0)
			"door", "window":
				ov.box(_corners(i), _note_color(i), 1.6)
			"solid":
				ov.box(_corners(i), Color(0.75, 0.75, 0.75, 0.6), 1.0)
			"link":
				ov.line(MapPieces._p(e, "a"), MapPieces._p(e, "b"), _note_color(i), 2.0)
			"box", "cyl", "ball":
				if not bool(e.get("vis", true)):
					ov.box(_corners(i), Color(0.75, 0.75, 0.75, 0.6), 1.0)
	if not sels.is_empty():
		for i in sels:
			if i < 0 or i >= _els().size():
				continue
			ov.box(_corners(i), Color(1.0, 0.92, 0.3) if i == sel else Color(1.0, 0.62, 0.2, 0.85), 2.0 if i == sel else 1.4)
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

# ---- tests -------------------------------------------------------------------------------------------
## Opens a block, clicks a part, moves / turns / stretches it, adds, mirrors, deletes, undoes, saves
## into a test folder and checks that the map then builds the saved block.
func _selftest() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_load("house", "", 1)
	await get_tree().process_frame
	await get_tree().process_frame
	var n0 := _els().size()
	# a click on a wall: the projected middle of the first solid box that is not the ground
	var wall := -1
	for i in _els().size():
		if _kind_of(i) == "box" and bool(_els()[i].get("c", true)) and not _is_ground(i) and _v3(_els()[i]["s"]).y > 2.0:
			wall = i
			break
	target = _center_of(wall)
	dist = 8.0
	yaw = PI + 0.3
	pitch = -0.4
	await get_tree().process_frame
	await get_tree().process_frame
	var clicked := _pick(_scr(_center_of(wall)))
	var click_ok := clicked >= 0
	var click_what := _label(clicked) if clicked >= 0 else "-"
	_set_sel([wall])
	# moved along x with the handle
	var p0 := _center_of(sel)
	mode = "posun"
	_start_drag("gizmo", 0, _scr(p0))
	_drag_to(_scr(p0) + _drag_dir * 60.0, false)
	_commit(sels.duplicate())
	var moved := _center_of(sel).distance_to(p0) > 0.1
	# turned 90 on the screen around y
	var r0 := _v3(_els()[sel].get("r", [0, 0, 0])).y
	_turn90()
	var turned := absf(absf(wrapf(_v3(_els()[sel].get("r", [0, 0, 0])).y - r0, -180, 180)) - 90.0) < 1.0
	# stretched with the numbers
	var s0 := _v3(_els()[sel]["s"]).y
	(_f["scl1"] as SpinBox).value = s0 * 150.0
	var stretched := absf(_v3(_els()[sel]["s"]).y - s0 * 1.5) < 0.01
	# the node in the view follows the data
	var nd: Node3D = _nodes[sel][0]
	var follows := nd.global_position.distance_to(MapPieces._p(_els()[sel])) < 0.01
	# add a model and a note, mirror them, delete one, undo
	_set_sel([])
	_add({"k": "model", "n": "v_well", "volne": true})
	var added_model: bool = (_nodes[_els().size() - 1] as Array).size() > 0
	_note_opt.select(0)
	_add_note()
	var with_notes := _els().size()
	_set_sel([with_notes - 2, with_notes - 1])
	_mirror_sel()
	var mirrored := _els().size() == with_notes + 2 and absf(_center_of(_els().size() - 1).x - (BLOCK - _center_of(with_notes - 1).x)) < 0.05
	_delete_sel()
	var deleted := _els().size() == with_notes
	_undo_step()
	var undone := _els().size() == with_notes + 2
	# save into a test folder; the map must build the saved block for this kind
	var keep_dir := MapPieces.test_dir
	MapPieces.test_dir = OS.get_user_data_dir().path_join("dilky_test")
	DirAccess.make_dir_recursive_absolute(MapPieces.test_dir)
	for f in DirAccess.get_files_at(MapPieces.test_dir.path_join("house")):
		DirAccess.remove_absolute(MapPieces.test_dir.path_join("house").path_join(f))
	MapPieces.forget()
	_name_edit.text = "Zkušební statek"
	_name_edit.text_changed.emit("Zkušební statek")
	_save(false)
	var saved := FileAccess.file_exists(MapPieces.test_dir.path_join("house/zkusebni_statek.json"))
	var mg2 = MapGenScript.new()
	var holder := Node3D.new()
	world.add_child(holder)
	mg2.root = holder
	mg2.rng.seed = 3
	mg2.info["size"] = 120.0
	var d := MapPieces.pick(mg2, "house")
	var picked := String(d.get("nazev", "")) == "Zkušební statek"
	MapPieces.build(mg2, d, Vector3(24, 0, 24))
	var built := holder.get_child_count() > 20
	holder.free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("user://tile_editor_test.png")
	for f in DirAccess.get_files_at(MapPieces.test_dir.path_join("house")):
		DirAccess.remove_absolute(MapPieces.test_dir.path_join("house").path_join(f))
	MapPieces.test_dir = keep_dir
	MapPieces.forget()
	print("[TILE] clicked: %s (wall %s)" % [click_what, _label(wall)])
	print("RESULT tileeditor parts %d click %s moved %s turned %s stretched %s follows %s model %s mirror %s delete %s undo %s saved %s picked %s built %s" % [
		n0, click_ok, moved, turned, stretched, follows, added_model, mirrored, deleted, undone, saved, picked, built])
	get_tree().quit()

## Pictures of the editor with a few blocks (for the release notes and the overlap check).
func _shots() -> void:
	await get_tree().process_frame
	var n := 0
	_show_notes = Game.cmd_arg("notes", "1") == "1"
	_grid.visible = _show_notes
	for k in String(Game.cmd_arg("kinds", "house,house2,barn,warehouse,pub,cabin")).split(","):
		_load(k, "", 1)
		target = Vector3(6, 1.0, 6)
		dist = 19.0
		yaw = PI + 0.7
		pitch = -0.55
		if Game.cmd_arg("cam", "") != "":
			var cv := Game.cmd_arg("cam", "").split_floats(",")
			target = Vector3(cv[0], cv[1], cv[2])
			dist = cv[3]
			yaw = cv[4]
			pitch = cv[5]
		if n == 0 and _show_notes:
			for i in _els().size():
				if _kind_of(i) == "door":
					_set_sel([i])
					break
		for f in 4:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("user://tile_%s.png" % k)
		n += 1
	print("RESULT tileshots %d" % n)
	get_tree().quit()
