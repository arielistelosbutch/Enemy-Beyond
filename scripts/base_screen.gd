extends Control
class_name BaseScreen
## 0.57 (Ari): the base screen. The base itself seen from above - the very rooms the team walks
## through (base_gen builds them in a hidden world, a camera under the ceilings takes one picture).
## 0.72 (Ari picked "Výkres s paletou"): the picture is a dimmed blueprint with hairline rooms;
## two modes - PŘEHLED (click a room: what it is, the hangar, the workshop) and STAVĚT (a palette of
## rooms by purpose on the left, the gold + places on the plan, the right panel says what it costs,
## what it does and when it is done; click a place, click it again or "Postavit sem").

const TEXT := UiSkin.TEXT
const DIM := UiSkin.DIM
const ACCENT := UiSkin.ACC
const CYAN := UiSkin.ACC   # 0.72: one accent
const PPM := 15.0            # pixels per metre of the rendered picture
const MAP_W := 272.0         # the map on screen
const MAP_H := 282.0
const BLOCK := 12.0          # one base cell (map_gen.BLOCK)
const SIDE_W := 166.0        # text width of the right panel
## The palette: rooms by what they are for.
const GROUPS := [["Výzkum a výroba", ["laborator", "dilna", "sklad"]],
	["Lidé", ["osetrovna", "cela", "strelnice"]],
	["Obrana a radar", ["radar", "silo", "laser_vez", "plazma_vez", "maskovani", "psi_gen"]]]
const UNIQUE := ["cela", "maskovani", "psi_gen"]

var on_close: Callable
var sel := -1
var hover := -1
var mode := "plan"           # plan / build
var pick := ""               # the room chosen in the palette (build mode)
var map_tex: TextureRect
var overlay: Control
var side: VBoxContainer
var left_box: VBoxContainer
var credits_lbl: Label
var title_lbl: Label
var hint_lbl: Label
var tab_btns := {}
var scale_k := 1.0           # screen px per metre
var _busy := false

static func open(parent: Node, select := -1) -> BaseScreen:
	var b := BaseScreen.new()
	parent.add_child(b)
	b.build()
	b.sel = select
	if select >= 0 and String(Campaign.data["base"][select]["type"]) == "" and not Campaign.viewer:
		b.mode = "build"
	b.refresh()
	return b

func build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiSkin.theme()
	var bg := TextureRect.new()
	bg.texture = UiSkin.backdrop()
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# top bar: name and mode, the tabs, budget and date
	title_lbl = Label.new()
	title_lbl.position = Vector2(8, 6)
	title_lbl.size = Vector2(250, 16)
	add_child(title_lbl)
	var tabs := HBoxContainer.new()
	tabs.position = Vector2(262, 6)
	tabs.add_theme_constant_override("separation", 2)
	add_child(tabs)
	for t in [["plan", "Přehled"], ["build", "Stavět"]]:
		var b := Button.new()
		b.text = t[1]
		b.add_theme_font_size_override("font_size", 8)
		b.custom_minimum_size = Vector2(50, 15)
		b.pressed.connect(_set_mode.bind(t[0]))
		tabs.add_child(b)
		tab_btns[t[0]] = b
	credits_lbl = Label.new()
	credits_lbl.position = Vector2(372, 7)
	credits_lbl.size = Vector2(260, 14)
	credits_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	credits_lbl.add_theme_font_size_override("font_size", 8)
	credits_lbl.add_theme_color_override("font_color", DIM)
	add_child(credits_lbl)
	# left: the palette (build) or the base at a glance (plan)
	var left := PanelContainer.new()
	left.name = "Palette"
	left.add_theme_stylebox_override("panel", UiSkin.panel(5))
	left.position = Vector2(8, 28)
	left.size = Vector2(138, 298)
	left.custom_minimum_size = left.size
	add_child(left)
	var lsc := ScrollContainer.new()
	lsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(lsc)
	left_box = VBoxContainer.new()
	left_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_box.add_theme_constant_override("separation", 1)
	lsc.add_child(left_box)
	# middle: the blueprint
	var frame := PanelContainer.new()
	frame.name = "Plan"
	frame.add_theme_stylebox_override("panel", UiSkin.inset(4))
	frame.position = Vector2(152, 28)
	frame.size = Vector2(MAP_W + 8, 298)
	frame.custom_minimum_size = frame.size
	add_child(frame)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(MAP_W, MAP_H)
	frame.add_child(holder)
	map_tex = TextureRect.new()
	map_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map_tex.size = Vector2(MAP_W, MAP_H)
	map_tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	map_tex.modulate = Color(0.55, 0.58, 0.62)       # dimmed: the lines are the plan, the photo is the ground
	holder.add_child(map_tex)
	overlay = Control.new()
	overlay.size = Vector2(MAP_W, MAP_H)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.draw.connect(_draw_overlay)
	overlay.gui_input.connect(_map_input)
	overlay.mouse_exited.connect(func(): hover = -1; overlay.queue_redraw())
	holder.add_child(overlay)
	# right: what is selected / what is being built
	var right := PanelContainer.new()
	right.name = "Detail"
	right.add_theme_stylebox_override("panel", UiSkin.panel(6))
	right.position = Vector2(438, 28)
	right.size = Vector2(194, 298)
	right.custom_minimum_size = right.size
	add_child(right)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(sc)
	side = VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 3)
	sc.add_child(side)
	# bottom: the keys, the way out
	hint_lbl = Label.new()
	hint_lbl.position = Vector2(8, 332)
	hint_lbl.size = Vector2(560, 14)
	hint_lbl.add_theme_font_size_override("font_size", 8)
	hint_lbl.add_theme_color_override("font_color", DIM)
	add_child(hint_lbl)
	var close := Button.new()
	close.text = "Zavřít"
	close.add_theme_font_size_override("font_size", 9)
	close.position = Vector2(574, 330)
	close.size = Vector2(58, 18)
	UiSkin.ghost(close)
	close.pressed.connect(_close)
	add_child(close)
	_render_map()

func _close() -> void:
	if on_close.is_valid():
		on_close.call()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if pick != "":
			_set_pick("")
		else:
			_close()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		get_viewport().set_input_as_handled()
		_set_mode("plan" if mode == "build" else "build")
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and pick != "":
		get_viewport().set_input_as_handled()
		_set_pick("")

func _set_mode(m: String) -> void:
	if m == "build" and Campaign.viewer:
		m = "plan"
	mode = m
	if mode == "plan":
		pick = ""
	elif sel >= 0 and String(Campaign.data["base"][sel]["type"]) != "":
		sel = -1
	refresh()

func _set_pick(f: String) -> void:
	pick = f
	refresh()

func _lbl(parent: Node, s: String, col := TEXT, size := 9) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(SIDE_W, 0)
	parent.add_child(l)
	return l

func _btn(parent: Node, s: String, cb: Callable, size := 8) -> Button:
	var b := Button.new()
	b.text = s
	b.add_theme_font_size_override("font_size", size)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(SIDE_W, 0)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	UiSkin.button(b)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

## A label | value line (Rozpočet 3 406 → 2 906).
func _kv(k: String, v: String, col := TEXT) -> void:
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(SIDE_W, 0)
	side.add_child(h)
	var a := Label.new()
	a.text = k
	a.add_theme_font_size_override("font_size", 8)
	a.add_theme_color_override("font_color", DIM)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(a)
	var b := Label.new()
	b.text = v
	b.add_theme_font_size_override("font_size", 8)
	b.add_theme_color_override("font_color", col)
	h.add_child(b)

static func money(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out

## A campaign day as a short date: 30. 4. 1990 (day 0 = 24. dubna 1990).
static func date_of(day: float) -> String:
	var mdays := [30, 31, 30, 31, 31, 30, 31, 30, 31, 31, 28, 31]
	var m := 0
	var dd := int(day) + 23
	while dd >= mdays[m % 12]:
		dd -= mdays[m % 12]
		m += 1
	return "%d. %d. %d" % [dd + 1, (m + 3) % 12 + 1, Campaign.START_YEAR + int((m + 3) / 12)]

# ---- the picture ---------------------------------------------------------------------------------
## The rooms are built for real in a world of their own and photographed from under the ceilings.
func _render_map() -> void:
	if _busy:
		return
	_busy = true
	var gw := Campaign.GRID_W
	var gh := Campaign.GRID_H
	var wm := gw * BLOCK          # metres: the grid, plus the hangar's bay one block north
	var hm := (gh + 1) * BLOCK
	var sv := SubViewport.new()
	sv.size = Vector2i(int(wm * PPM), int(hm * PPM))
	sv.own_world_3d = true
	sv.msaa_3d = Viewport.MSAA_2X
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)
	var world := Node3D.new()
	sv.add_child(world)
	BaseGenScript.new().build(world, 7, {"base": Campaign.data["base"].duplicate(true), "grid_w": gw, "grid_h": gh,
		"transport": Campaign.transport(), "live": [], "no_nav": true})
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.06, 0.05, 0.04)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.78, 0.8)
	e.ambient_light_energy = 0.9
	env.environment = e
	sv.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-70, 30, 0)
	sun.light_energy = 0.6
	sv.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = hm
	cam.near = 0.05
	cam.far = 30.0
	sv.add_child(cam)
	cam.position = Vector3(wm / 2.0, 3.2, (gh - 1) * BLOCK / 2.0)      # under every ceiling
	cam.rotation_degrees = Vector3(-90, 0, 0)
	for f in 4:
		await RenderingServer.frame_post_draw
	if not is_instance_valid(self):
		return
	var img := sv.get_texture().get_image()
	map_tex.texture = ImageTexture.create_from_image(img)
	sv.queue_free()
	scale_k = minf(MAP_W / wm, MAP_H / hm)
	_busy = false
	overlay.queue_redraw()

const BaseGenScript := preload("res://scripts/base_gen.gd")

## Where a grid cell lies on the map (screen px inside the overlay).
func _cell_rect(i: int) -> Rect2:
	var B := BLOCK
	var wm := Campaign.GRID_W * B
	var hm := (Campaign.GRID_H + 1) * B
	var off := Vector2((MAP_W - wm * scale_k) / 2.0, (MAP_H - hm * scale_k) / 2.0)
	var gx := i % Campaign.GRID_W
	var gz := i / Campaign.GRID_W
	return Rect2(off + Vector2(gx * B, (gz + 1) * B) * scale_k, Vector2(B, B) * scale_k)

func _cell_at(p: Vector2) -> int:
	for i in Campaign.data["base"].size():
		if _cell_rect(i).has_point(p):
			return i
	# the hangar's bay north of the grid belongs to the hangar below it
	for i in Campaign.GRID_W:
		var r := _cell_rect(i)
		r.position.y -= r.size.y
		if r.has_point(p) and String(Campaign.data["base"][i]["type"]) == "hangar":
			return i
	return -1

func _free_spot(i: int) -> bool:
	return i >= 0 and String(Campaign.data["base"][i]["type"]) == "" and Campaign.can_build_at(i)

func _draw_overlay() -> void:
	if map_tex.texture == null:
		overlay.draw_string(UiSkin.font(), Vector2(MAP_W / 2 - 40, MAP_H / 2), "Načítám plán...", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, DIM)
		return
	var f := UiSkin.caps_font()
	var building_mode := mode == "build"
	for i in Campaign.data["base"].size():
		var c: Dictionary = Campaign.data["base"][i]
		var r := _cell_rect(i).grow(-1.0 * scale_k)          # the room itself (1 m of earth round it)
		var ty := String(c["type"])
		if ty == "":
			if Campaign.can_build_at(i) and building_mode:
				var lit: bool = i == hover or i == sel
				if pick != "" and i == sel:
					_ghost(r, pick, 1.0)
				elif pick != "" and i == hover:
					_ghost(r, pick, 0.6)
				else:
					_dashed(r.grow(-2), Color(ACCENT, 0.9 if lit else 0.5))
					var pc := r.get_center()
					var a := 1.0 if lit else 0.6
					overlay.draw_line(pc - Vector2(4, 0), pc + Vector2(4, 0), Color(ACCENT, a), -1)
					overlay.draw_line(pc - Vector2(0, 4), pc + Vector2(0, 4), Color(ACCENT, a), -1)
			elif i == sel:
				overlay.draw_rect(r, Color(1, 1, 1, 0.35), false, -1)
		else:
			var name: String = Campaign.FACILITIES[ty].get("short", Campaign.FACILITIES[ty]["name"])
			var building := float(c["days"]) > 0.0
			var full := _full_rect(i)
			overlay.draw_rect(full, Color(0.04, 0.05, 0.07, 0.35))
			if building:
				_dashed(full, Color(ACCENT, 0.85))
			else:
				overlay.draw_rect(full, Color(TEXT, 0.55), false, -1)
			var ty_pos := full.position.y + 3 if ty != "hangar" else full.end.y - 4 - _name_h(name, full.size.x - 4)
			_name(name, Rect2(full.position.x + 2, ty_pos, full.size.x - 4, 0), ACCENT if building else TEXT)
			if building:
				var bt := "STAVBA %d d" % ceili(float(c["days"]))
				var bw := f.get_string_size(bt, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
				overlay.draw_string(f, Vector2(r.get_center().x - bw / 2.0, r.get_center().y + 4), bt, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, ACCENT)
			if i == hover and i != sel:
				overlay.draw_rect(full.grow(1), Color(1, 1, 1, 0.45), false, -1)
			if i == sel:
				_corners(full.grow(1), ACCENT)

## A room in the plan before it is built: gold wash, dashed outline, the name.
func _ghost(r: Rect2, ft: String, a: float) -> void:
	overlay.draw_rect(r, Color(ACCENT, 0.14 * a))
	_dashed(r, Color(ACCENT, a))
	var name := String(Campaign.FACILITIES[ft].get("short", Campaign.FACILITIES[ft]["name"]))
	var h := _name_h(name, r.size.x - 4)
	_name(name, Rect2(r.position.x + 2, r.get_center().y - h / 2.0, r.size.x - 4, 0), Color(ACCENT, a))

## A room's name in capitals, made to fit its box: one line, else two, else smaller.
func _name_lines(name: String, w: float) -> Array:
	var f := UiSkin.caps_font()
	var t := name.to_upper()
	for fs in [7, 6]:
		if f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= w:
			return [fs, [t]]
		var words := t.split(" ")
		if words.size() > 1:
			var best: Array = []
			var bw := 9999.0
			for k in range(1, words.size()):
				var a := " ".join(words.slice(0, k))
				var b := " ".join(words.slice(k))
				var m := maxf(f.get_string_size(a, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, f.get_string_size(b, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
				if m < bw:
					bw = m
					best = [a, b]
			if bw <= w:
				return [fs, best]
	return [5, [t]]

func _name_h(name: String, w: float) -> float:
	var nl := _name_lines(name, w)
	return (int(nl[0]) + 2) * (nl[1] as Array).size()

func _name(name: String, r: Rect2, col: Color) -> void:
	var f := UiSkin.caps_font()
	var nl := _name_lines(name, r.size.x)
	var fs: int = nl[0]
	var y := r.position.y + fs + 1
	for line in nl[1]:
		var tw := f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		overlay.draw_string(f, Vector2(r.position.x + (r.size.x - tw) / 2.0, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		y += fs + 2

## The selection: four gold corner ticks.
func _corners(r: Rect2, col: Color) -> void:
	var k := 5.0
	for p in [[r.position, Vector2(1, 1)], [Vector2(r.end.x, r.position.y), Vector2(-1, 1)], [r.end, Vector2(-1, -1)], [Vector2(r.position.x, r.end.y), Vector2(1, -1)]]:
		var o: Vector2 = p[0]
		var d: Vector2 = p[1]
		overlay.draw_line(o, o + Vector2(d.x * k, 0), col, 1.0)
		overlay.draw_line(o, o + Vector2(0, d.y * k), col, 1.0)

## The hangar's outline takes its bay too.
func _full_rect(i: int) -> Rect2:
	var r := _cell_rect(i).grow(-1.0 * scale_k)
	if String(Campaign.data["base"][i]["type"]) == "hangar" and i < Campaign.GRID_W and float(Campaign.data["base"][i]["days"]) <= 0.0:
		r.position.y -= _cell_rect(i).size.y
		r.size.y += _cell_rect(i).size.y
	return r

func _dashed(r: Rect2, col: Color) -> void:
	var pts := [r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y), r.position]
	for k in 4:
		overlay.draw_dashed_line(pts[k], pts[k + 1], col, -1, 3.0)

func _map_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := _cell_at(event.position)
		if h != hover:
			hover = h
			overlay.queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := _cell_at(event.position)
		if i < 0:
			return
		if mode == "build" and pick != "" and i == sel and _free_spot(i):
			_do_build()                                 # second click on the same place = build
			return
		sel = i
		if String(Campaign.data["base"][i]["type"]) != "" and mode == "build":
			mode = "plan"                               # a finished room: look at it
			pick = ""
		elif _free_spot(i) and not Campaign.viewer:
			mode = "build"
		Game.play_ui(self, "ui_click", -9)
		refresh()

func _do_build() -> void:
	if pick == "" or not _free_spot(sel) or _why_not(pick) != "":
		return
	if Campaign.build(sel, pick):
		Game.play_ui(self, "ui_click", -6)
		pick = ""
		refresh()
		_render_map()

## Why the chosen room cannot go in now ("" = it can).
func _why_not(f: String) -> String:
	if Campaign.viewer:
		return "Stavět může jen hostitel - je to jeho základna."
	if not Campaign.facility_open(f):
		return "Nejdřív je potřeba výzkum."
	if f in UNIQUE and Campaign.data["base"].any(func(c): return String(c["type"]) == f):
		return "Základna ji už má - stačí jedna."
	if int(Campaign.data["credits"]) < Campaign.facility_cost(f):
		return "Na tohle teď nemáme peníze."
	return ""

# ---- the panels ----------------------------------------------------------------------------------
func refresh() -> void:
	title_lbl.text = "Základna  ·  " + ("Stavění" if mode == "build" else "Přehled") + "  ·  " + Campaign.base_place()
	UiSkin.title(title_lbl, 11)
	title_lbl.remove_theme_stylebox_override("normal")
	credits_lbl.text = "Rozpočet %s kr  ·  %s  ·  den %d" % [money(int(Campaign.data["credits"])), date_of(float(Campaign.data["day"])), int(Campaign.data["day"])]
	for k in tab_btns:
		UiSkin.row(tab_btns[k], k == mode)
		tab_btns[k].alignment = HORIZONTAL_ALIGNMENT_CENTER
	tab_btns["build"].disabled = Campaign.viewer
	if mode == "build":
		hint_lbl.text = "LTM vybrat místo, znovu = postavit    PTM zrušit    Zlatá místa navazují na chodby    Tab přehled"
	else:
		hint_lbl.text = "LTM vybrat místnost    Tab stavět    Esc zavřít"
	for ch in left_box.get_children():
		ch.queue_free()
	for ch in side.get_children():
		ch.queue_free()
	overlay.queue_redraw()
	if mode == "build":
		_palette()
		_build_panel()
	else:
		_overview()
		_room_panel()

func _section(parent: Node, s: String) -> void:
	var l := Label.new()
	l.text = s
	UiSkin.section(l, 7)
	parent.add_child(l)

## Build mode, left: every room the base can dig, by purpose.
func _palette() -> void:
	for g in GROUPS:
		_section(left_box, g[0])
		for f in g[1]:
			var fi: Dictionary = Campaign.FACILITIES[f]
			var b := Button.new()
			b.text = String(fi.get("short", fi["name"]))
			b.add_theme_font_size_override("font_size", 8)
			b.custom_minimum_size = Vector2(124, 15)
			b.clip_text = true
			UiSkin.row(b, f == pick)
			left_box.add_child(b)
			var r := Label.new()
			r.add_theme_font_size_override("font_size", 7)
			r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			r.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			r.set_anchors_preset(Control.PRESET_FULL_RECT)
			r.offset_right = -5
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(r)
			var why := _why_not(f)
			if not Campaign.facility_open(f):
				r.text = "výzkum"
				r.add_theme_color_override("font_color", Color(DIM, 0.7))
				b.disabled = true
			elif f in UNIQUE and Campaign.data["base"].any(func(c): return String(c["type"]) == f):
				r.text = "máme"
				r.add_theme_color_override("font_color", Color(DIM, 0.7))
				b.disabled = true
			else:
				r.text = "%s · %d d" % [money(Campaign.facility_cost(f)), int(Campaign.facility_days(f))]
				r.add_theme_color_override("font_color", UiSkin.BAD if why != "" and not Campaign.viewer else DIM)
				b.disabled = Campaign.viewer
			b.pressed.connect(func(): _set_pick("" if pick == f else f))

## Build mode, right: what the chosen room costs, does and when it is done.
func _build_panel() -> void:
	if pick == "":
		_section(side, "Stavění")
		if Campaign.viewer:
			_lbl(side, "Stavět může jen hostitel - je to jeho základna.", DIM, 8)
			return
		if _free_spot(sel):
			_lbl(side, "Místo je vybrané. Vlevo vyber, co tu vykopat a vybavit.", TEXT, 8)
		else:
			_lbl(side, "Vlevo vyber místnost, pak na plánu zlaté místo. Stavět se dá jen vedle hotové místnosti - chodba je spojí.", TEXT, 8)
		_lbl(side, "Pozemek: %d z %d míst zastavěno." % [Campaign.data["base"].filter(func(c): return String(c["type"]) != "").size(), Campaign.data["base"].size()], DIM, 8)
		return
	var fi: Dictionary = Campaign.FACILITIES[pick]
	_section(side, "Stavíš")
	var n := _lbl(side, String(fi["name"]), TEXT, 11)
	n.add_theme_font_override("font", UiSkin.font(true))
	_lbl(side, String(fi["desc"]), DIM, 8)
	var eff := _effect(pick)
	if not eff.is_empty():
		_kv(eff[0], eff[1], UiSkin.OK)
	var cost := Campaign.facility_cost(pick)
	var cr := int(Campaign.data["credits"])
	_kv("Cena", money(cost) + " kr")
	_kv("Rozpočet", "%s → %s" % [money(cr), money(cr - cost)], UiSkin.BAD if cr < cost else TEXT)
	var days := Campaign.facility_days(pick)
	_kv("Doba", "%d dní" % int(days) if days >= 5 else "%d dny" % int(days) if days >= 2 else "%d den" % int(days))
	_kv("Hotovo", date_of(float(Campaign.data["day"]) + days))
	var why := _why_not(pick)
	if why == "" and not _free_spot(sel):
		why = "Vyber na plánu zlaté místo."
	if why != "":
		_lbl(side, why, UiSkin.BAD if why.begins_with("Na tohle") else DIM, 8)
	var go := _btn(side, "Postavit sem", _do_build, 9)
	UiSkin.primary(go)
	go.alignment = HORIZONTAL_ALIGNMENT_CENTER
	go.disabled = why != ""
	var no := _btn(side, "Zrušit výběr", func(): _set_pick(""), 8)
	UiSkin.ghost(no)
	no.alignment = HORIZONTAL_ALIGNMENT_CENTER

## What one more of this room changes (only what our own rooms do - nothing about the enemy).
func _effect(f: String) -> Array:
	var n := Campaign.count(f)
	match f:
		"laborator":
			var a := 0.0 if n == 0 else 1.0 + 0.5 * (n - 1)
			return ["Výzkum", "%d %% → %d %%" % [roundi(a * 100), roundi((1.0 + 0.5 * n) * 100)]]
		"dilna":
			var a := 0.0 if n == 0 else 1.0 + 0.5 * (n - 1)
			return ["Výroba", "%d %% → %d %%" % [roundi(a * 100), roundi((1.0 + 0.5 * n) * 100)]]
		"sklad":
			return ["Munice a granáty", "−%d %% → −%d %%" % [roundi((1.0 - pow(0.9, n)) * 100), roundi((1.0 - pow(0.9, n + 1)) * 100)]]
		"osetrovna":
			return ["Hojení", "2× rychleji" if n == 0 else "už máme"]
		"radar":
			return ["Radary", "%d → %d" % [n, n + 1]]
	return []

## Plan mode, left: the base at a glance, by purpose.
func _overview() -> void:
	_section(left_box, "Místnosti")
	var counts := {}
	var building := {}
	for c in Campaign.data["base"]:
		var t := String(c["type"])
		if t == "":
			continue
		if float(c["days"]) > 0.0:
			building[t] = int(building.get(t, 0)) + 1
		else:
			counts[t] = int(counts.get(t, 0)) + 1
	for t in counts:
		_glance(Campaign.FACILITIES[t].get("short", Campaign.FACILITIES[t]["name"]), "×%d" % counts[t], TEXT)
	for t in building:
		_glance(Campaign.FACILITIES[t].get("short", Campaign.FACILITIES[t]["name"]), "stavba", ACCENT)
	_section(left_box, "Tempo")
	_glance("Výzkum", "%d %%" % roundi((0.0 if Campaign.count("laborator") == 0 else 1.0 + 0.5 * (Campaign.count("laborator") - 1)) * 100), TEXT)
	_glance("Výroba", "%d %%" % roundi(Campaign.workshop_rate() * 100), TEXT)
	_section(left_box, "Letka")
	_glance("Stíhačky", "%d (%d připr.)" % [Campaign.jets(), Campaign.jets_ready()], TEXT)
	_glance("Transport", String(Campaign.CRAFT_NAMES.get(Campaign.transport(), Campaign.transport())), TEXT)

func _glance(k: String, v: String, col: Color) -> void:
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(124, 0)
	left_box.add_child(h)
	var a := Label.new()
	a.text = k
	a.add_theme_font_size_override("font_size", 8)
	a.add_theme_color_override("font_color", DIM)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.clip_text = true
	h.add_child(a)
	var b := Label.new()
	b.text = v
	b.add_theme_font_size_override("font_size", 8)
	b.add_theme_color_override("font_color", col)
	h.add_child(b)

## Plan mode, right: the selected room.
func _room_panel() -> void:
	if sel < 0:
		_section(side, "Plán základny")
		_lbl(side, "Klikni na místnost na plánu. Novou místnost přidáš v režimu Stavět (Tab).", TEXT, 8)
		return
	var c: Dictionary = Campaign.data["base"][sel]
	var ty := String(c["type"])
	if ty == "":
		_section(side, "Zemina")
		_lbl(side, "Tady je jen hlína a skála. Stavět se dá jen vedle hotové místnosti, jinak by k ní nevedla chodba.", TEXT, 8)
		return
	var fi: Dictionary = Campaign.FACILITIES[ty]
	_section(side, "Místnost")
	var n := _lbl(side, String(fi["name"]), TEXT, 11)
	n.add_theme_font_override("font", UiSkin.font(true))
	if float(c["days"]) > 0.0:
		_lbl(side, "Ve výstavbě - hotovo %s (za %d d)." % [date_of(float(Campaign.data["day"]) + float(c["days"])), ceili(float(c["days"]))], ACCENT, 8)
	else:
		_lbl(side, "V provozu.", UiSkin.OK, 8)
	_lbl(side, String(fi["desc"]), DIM, 8)
	if ty == "hangar":
		_hangar()
	elif ty == "dilna" and float(c["days"]) <= 0.0:
		_workshop()

func _head(s: String) -> void:
	_section(side, s)

## The workshop: what is being made, and the way to the production list.
func _workshop() -> void:
	var now := float(Campaign.data["day"])
	var q := []
	for o in Campaign.data.get("orders", []):
		if o.get("made", false):
			var it := String(o["item"])
			var nm: String = Game.ITEMS[it]["short"] if Game.ITEMS.has(it) else Campaign.queue_name(it)
			q.append("%s (%d h)" % [nm, ceili((float(o["at"]) - now) * 24.0)])
	_lbl(side, "Dílny: %d (tempo %d %%)   Slitiny: %d ks   Moskovium: %d g" % [Campaign.workshop_lines(), int(round(Campaign.workshop_rate() * 100.0)), Campaign.alloys(), Campaign.moskovium()], DIM, 8)
	_lbl(side, ("Ve výrobě: " + ", ".join(q)) if not q.is_empty() else "Nic se nevyrábí.", TEXT, 8).custom_minimum_size = Vector2(SIDE_W, 0)
	var host := get_parent()
	if host and host.has_method("_show_workshop"):
		_btn(side, "Výroba...", func():
			_close()
			host.call("_show_workshop"))

## The hangar: the fighters and what they carry.
func _hangar() -> void:
	_head("STÍHAČKY")
	_lbl(side, "Ve službě: %d z %d (připraveno %d)%s." % [Campaign.jets(), Campaign.MAX_JETS, Campaign.jets_ready(),
		(", z toho Jestřábů %d" % Campaign.hawks()) if Campaign.hawks() > 0 else ""], TEXT, 8)
	var coming := []
	for k in [["sokol", "Sokol"], ["jestrab", "Jestřáb"], ["kondor", "Kondor"], ["orel", "Pelikán"]]:
		if Campaign.crafts_coming(k[0]) > 0:
			coming.append("%s %d×" % [k[1], Campaign.crafts_coming(k[0])])
	if not coming.is_empty():
		_lbl(side, "Na cestě / v dílně: " + ", ".join(coming), ACCENT, 8)
	if not Campaign.viewer and Campaign.jets() + Campaign.hulls_coming() < Campaign.MAX_JETS:
		_btn(side, "Koupit Sokol - %d kr (zítra)" % Campaign.jet_price(), func():
			if Campaign.buy_jet(): refresh()
		).disabled = int(Campaign.data["credits"]) < Campaign.jet_price()
	if not Campaign.viewer and Campaign.can_buy_hawk():
		var hm: Dictionary = Campaign.CRAFT_MAKE["jestrab"]
		_btn(side, ("Dílna: Jestřáb - %d kr, %d sl., %d g" if Campaign.hawk_new() else "Dílna: Sokol na Jestřába - %d kr, %d sl., %d g") % [Campaign.hawk_price(), int(hm["al"]), int(hm["mk"])], func():
			if Campaign.buy_hawk(): refresh()
		).disabled = not Campaign.can_make_hawk()
	if not Campaign.viewer and Campaign.researched("orel") and not Campaign.pelikan() and Campaign.crafts_coming("orel") == 0:
		var pm: Dictionary = Campaign.CRAFT_MAKE["orel"]
		_btn(side, "Dílna: Pelikán - %d kr, %d sl., %d g" % [Campaign.pelikan_price(), int(pm["al"]), int(pm["mk"])], func():
			if Campaign.make_pelikan(): refresh()
		).disabled = not Campaign.can_make_pelikan()
	if not Campaign.viewer and Campaign.researched("kondor") and Campaign.transport() != "kondor" and Campaign.crafts_coming("kondor") == 0:
		_btn(side, "Dílna: Kondor - %d kr" % Campaign.kondor_price(), func():
			if Campaign.make_kondor(): refresh()
		).disabled = not Campaign.can_make_kondor()
	_lbl(side, "Výzbroj stíhaček (klikni = další):", DIM, 8)
	var gb := _btn(side, "Kulomet: " + String(Campaign.JET_GUNS[Campaign.jet_gun()][0]), func(): Campaign.cycle_jet_weapon(false); refresh())
	var hb := _btn(side, "Těžká zbraň: " + String(Campaign.JET_HEAVY[Campaign.jet_heavy()][0]), func(): Campaign.cycle_jet_weapon(true); refresh())
	gb.disabled = Campaign.viewer
	hb.disabled = Campaign.viewer
