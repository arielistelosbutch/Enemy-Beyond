class_name UiSkin
## The look of every menu (0.72, "Čistý taktický"): dark flat surfaces, hairline edges, one gold
## accent, Barlow Condensed type. Everything is drawn here in code (UiBox), so one place decides how
## panels, buttons, fields and scrollbars look. Colour names from the old steel skin are kept
## (GLOW, AMBER) so older screens pick up the new accent on their own.

# ---- tokens ------------------------------------------------------------------------------------
const BG := Color(0.043, 0.055, 0.071)        # #0b0e12
const SURF := Color(0.043, 0.055, 0.071, 0.94) # window surface
const RAISE := Color(1, 1, 1, 0.035)           # a slightly lighter area inside a window
const LINE := Color(1, 1, 1, 0.10)             # dividers
const EDGE := Color(1, 1, 1, 0.27)             # button and field edges
const TEXT := Color(0.90, 0.914, 0.933)        # #e6e9ee
const DIM := Color(0.553, 0.592, 0.647)        # #8d97a5
const ACC := Color(0.89, 0.643, 0.235)         # #e3a43c - the one accent
const ACC_HI := Color(1.0, 0.784, 0.38)        # hover / glow of the accent
const OK := Color(0.44, 0.83, 0.55)
const WARN := Color(0.95, 0.76, 0.36)
const BAD := Color(0.90, 0.36, 0.33)
const GLOW := ACC                              # old name: the "lit" colour
const AMBER := ACC                             # old name: titles
const STEEL_HI := Color(0.56, 0.62, 0.66)
const STEEL_LO := Color(0.05, 0.06, 0.07)

static var _cache := {}
static var _theme: Theme

## UI type: Barlow Condensed (Medium, bold = SemiBold). body=true: Barlow for longer paragraphs.
static func font(bold := false, body := false) -> Font:
	var key := "font_%s_%s" % [bold, body]
	if not _cache.has(key):
		var f := FontVariation.new()
		var file := "BarlowCondensed-SemiBold" if bold else "BarlowCondensed-Medium"
		if body:
			file = "Barlow-Medium" if bold else "Barlow-Regular"
		f.base_font = load("res://assets/fonts/%s.ttf" % file)
		f.spacing_glyph = 0
		_cache[key] = f
	return _cache[key]

## Small caps label with letter spacing (section names, eyebrows, key hints).
static func caps_font() -> Font:
	if not _cache.has("caps"):
		var f := FontVariation.new()
		f.base_font = load("res://assets/fonts/BarlowCondensed-Medium.ttf")
		f.spacing_glyph = 1
		_cache["caps"] = f
	return _cache["caps"]

static func _box(f: Color, l: Color, s := 15, m := Vector4(6, 3, 6, 3)) -> UiBox:
	return UiBox.make(f, l, s, m)

# ---- the pieces ----------------------------------------------------------------------------------
## The big window panel (menus, popups, inventory): dark surface, hairline edge.
static func panel(margin := 9.0) -> StyleBox:
	var key := "panel%d" % int(margin)
	if not _cache.has(key):
		_cache[key] = _box(SURF, LINE, 15, Vector4(margin, margin, margin, margin))
	return _cache[key]

## A smaller inset area (side bars, info boxes): a touch lighter, a fainter edge.
static func inset(margin := 5.0) -> StyleBox:
	var key := "inset%d" % int(margin)
	if not _cache.has(key):
		_cache[key] = _box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.08), 15, Vector4(margin, margin, margin, margin))
	return _cache[key]

## Title strip at the top of a panel: no plate, just a divider under the gold caps.
static func header() -> StyleBox:
	if not _cache.has("header"):
		_cache["header"] = _box(Color(0, 0, 0, 0), LINE, 8, Vector4(2, 1, 2, 4))
	return _cache["header"]

static func _btn_tex(state: String) -> StyleBox:
	var key := "btn_" + state
	if not _cache.has(key):
		var m := Vector4(7, 2, 7, 2)
		match state:
			"normal": _cache[key] = _box(Color(1, 1, 1, 0.025), EDGE, 15, m)
			"hover": _cache[key] = _box(Color(ACC, 0.13), ACC, 15, m)
			"pressed": _cache[key] = _box(Color(ACC, 0.32), ACC_HI, 15, m)
			"disabled": _cache[key] = _box(Color(0, 0, 0, 0), Color(1, 1, 1, 0.09), 15, m)
			"primary": _cache[key] = _box(ACC, ACC, 15, m)
			"primary_hover": _cache[key] = _box(ACC_HI, ACC_HI, 15, m)
	return _cache[key]

## Gives a button the look (keeps the button's own font size).
static func button(b: BaseButton) -> void:
	for s in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(s, _btn_tex(s))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover_pressed", _btn_tex("pressed"))
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	b.add_theme_color_override("font_disabled_color", Color(DIM, 0.6))
	_click(b)

## The one main action of a screen: a gold button with dark text.
static func primary(b: BaseButton) -> void:
	button(b)
	b.add_theme_stylebox_override("normal", _btn_tex("primary"))
	b.add_theme_stylebox_override("hover", _btn_tex("primary_hover"))
	b.add_theme_stylebox_override("pressed", _btn_tex("primary_hover"))
	b.add_theme_stylebox_override("hover_pressed", _btn_tex("primary_hover"))
	var dark := Color(0.07, 0.06, 0.04)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, dark)

## A quiet button (only text, edge on hover): secondary actions, "Zpět".
static func ghost(b: BaseButton) -> void:
	button(b)
	b.add_theme_stylebox_override("normal", _box(Color(0, 0, 0, 0), Color(1, 1, 1, 0.12), 15, Vector4(7, 2, 7, 2)))
	b.add_theme_color_override("font_color", Color(0.80, 0.83, 0.86))

## Picks the look from the label: the screen's main action is written in capitals (ZAČÍT KAMPAŇ,
## VZLÉTNOUT) and turns gold, the way back is quiet, everything else is a normal button.
static func auto(b: Button) -> void:
	var t := b.text.strip_edges()
	var letters := t.replace(" ", "")
	if t in ["Zpět", "Zrušit", "Zavřít", "Ne", "< Zpět"] or t.begins_with("Zpět "):
		ghost(b)
	elif letters.length() >= 4 and letters == letters.to_upper() and letters != letters.to_lower():
		primary(b)
	else:
		button(b)

static func _click(b: BaseButton) -> void:
	if not b.has_meta("click"):
		b.set_meta("click", true)
		b.pressed.connect(func():
			if b.is_inside_tree():
				Game.play_ui(b.get_tree().root, "ui_click", -9))

## A slot / tile button tinted by what it holds (base facilities and the like).
static func tile(b: BaseButton, tint: Color) -> void:
	var key := "tile_%s" % tint.to_html()
	if not _cache.has(key):
		var f := tint.darkened(0.35)
		f.a = 0.9
		_cache[key] = _box(f, Color(tint.lightened(0.35), 0.55), 15, Vector4(4, 3, 4, 3))
	b.add_theme_stylebox_override("normal", _cache[key])
	b.add_theme_stylebox_override("hover", _btn_tex("hover"))

## A selectable row of a list or table: no edge, a gold bar on the left when chosen.
static func row(b: BaseButton, chosen := false) -> void:
	button(b)
	var m := Vector4(7, 2, 7, 2)
	var base := _box(Color(0, 0, 0, 0), LINE, 8, m)
	var sel := _box(Color(ACC, 0.10), LINE, 8, m).with_bar(ACC, 0, 2.0)
	b.add_theme_stylebox_override("normal", sel if chosen else base)
	b.add_theme_stylebox_override("hover", _box(Color(1, 1, 1, 0.05), LINE, 8, m).with_bar(ACC_HI, 0, 2.0))
	b.add_theme_stylebox_override("pressed", sel)
	b.add_theme_stylebox_override("hover_pressed", sel)
	b.add_theme_stylebox_override("disabled", base)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT

static func field() -> StyleBox:
	if not _cache.has("field"):
		_cache["field"] = _box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.35), 8, Vector4(5, 2, 5, 2))
	return _cache["field"]

static func field_focus() -> StyleBox:
	if not _cache.has("field_f"):
		_cache["field_f"] = _box(Color(1, 1, 1, 0.05), ACC, 8, Vector4(5, 2, 5, 2))
	return _cache["field_f"]

## The background behind the menus: a dark radial wash, brighter top right, faint grain.
static func backdrop(w := 640, h := 360) -> ImageTexture:
	if _cache.has("backdrop"):
		return _cache["backdrop"]
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var lit := Color(0.094, 0.125, 0.165)     # #18202a
	for y in h:
		for x in w:
			var d := Vector2((float(x) / w - 0.7) * 1.2, float(y) / h - 0.2).length()
			var c := lit.lerp(BG, clampf(d / 0.75, 0.0, 1.0))
			c = c.lightened((_noise(x, y, 3) - 0.5) * 0.012)
			img.set_pixel(x, y, c)
	_cache["backdrop"] = ImageTexture.create_from_image(img)
	return _cache["backdrop"]

## A tiny icon drawn pixel by pixel (canvas units; Godot scales it with the window).
static func _icon_tex(w: int, h: int, px: Callable) -> ImageTexture:
	var img := Image.create(w * 3, h * 3, false, Image.FORMAT_RGBA8)
	for y in h * 3:
		for x in w * 3:
			img.set_pixel(x, y, px.call(x / 3, y / 3))
	var tex := ImageTexture.create_from_image(img)
	tex.set_size_override(Vector2i(w, h))
	return tex

static func _noise(x: int, y: int, seed := 0) -> float:
	var h := (x * 374761393 + y * 668265263 + seed * 2147483647) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h & 1023) / 1023.0

## The whole game's theme: the default font and the look of every standard control.
static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 10
	t.set_stylebox("panel", "PanelContainer", panel())
	t.set_stylebox("panel", "Panel", panel())
	t.set_stylebox("panel", "PopupPanel", panel())
	t.set_stylebox("panel", "PopupMenu", panel(4))
	t.set_stylebox("panel", "TooltipPanel", _box(BG, EDGE, 15, Vector4(5, 3, 5, 3)))
	t.set_color("font_color", "TooltipLabel", TEXT)
	for s in ["normal", "hover", "pressed", "disabled"]:
		for cls in ["Button", "OptionButton", "MenuButton"]:
			t.set_stylebox(s, cls, _btn_tex(s))
	for cls in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("hover_pressed", cls, _btn_tex("pressed"))
	for cls in ["Button", "OptionButton", "MenuButton", "CheckBox", "CheckButton"]:
		t.set_stylebox("focus", cls, StyleBoxEmpty.new())
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, Color(1, 1, 1))
		t.set_color("font_pressed_color", cls, Color(1, 1, 1))
		t.set_color("font_hover_pressed_color", cls, Color(1, 1, 1))
		t.set_color("font_disabled_color", cls, Color(DIM, 0.6))
	for cls in ["CheckBox", "CheckButton"]:
		for s in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			t.set_stylebox(s, cls, _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, Vector4(2, 1, 2, 1)))
	t.set_color("font_color", "Label", TEXT)
	for cls in ["LineEdit", "TextEdit", "SpinBox"]:
		t.set_stylebox("normal", cls, field())
		t.set_stylebox("focus", cls, field_focus())
		t.set_stylebox("read_only", cls, field())
		t.set_color("font_color", cls, Color(1, 1, 1))
		t.set_color("caret_color", cls, ACC)
		t.set_color("selection_color", cls, Color(ACC, 0.35))
	# scrollbars: a hairline rail, a quiet grabber that turns gold under the mouse
	var rail := _box(Color(1, 1, 1, 0.02), Color(1, 1, 1, 0.06), 15, Vector4(1, 1, 1, 1))
	var grab := _box(Color(1, 1, 1, 0.22), Color(0, 0, 0, 0), 0, Vector4(0, 0, 0, 0))
	var grab_h := _box(Color(ACC, 0.85), Color(0, 0, 0, 0), 0, Vector4(0, 0, 0, 0))
	for cls in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", cls, rail)
		t.set_stylebox("grabber", cls, grab)
		t.set_stylebox("grabber_highlight", cls, grab_h)
		t.set_stylebox("grabber_pressed", cls, grab_h)
	# sliders and progress bars: a thin track, gold fill
	var slot := _box(Color(1, 1, 1, 0.12), Color(0, 0, 0, 0), 0, Vector4(0, 1, 0, 1))
	var fill := _box(ACC, Color(0, 0, 0, 0), 0, Vector4(0, 1, 0, 1))
	for cls in ["HSlider", "VSlider"]:
		t.set_stylebox("slider", cls, slot)
		t.set_stylebox("grabber_area", cls, fill)
		t.set_stylebox("grabber_area_highlight", cls, _box(ACC_HI, Color(0, 0, 0, 0), 0, Vector4(0, 1, 0, 1)))
	t.set_stylebox("background", "ProgressBar", _box(Color(1, 1, 1, 0.10), Color(0, 0, 0, 0), 0, Vector4(0, 0, 0, 0)))
	t.set_stylebox("fill", "ProgressBar", _box(ACC, Color(0, 0, 0, 0), 0, Vector4(0, 0, 0, 0)))
	t.set_color("font_color", "ProgressBar", TEXT)
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color(1, 1, 1))
	t.set_stylebox("hover", "PopupMenu", _box(Color(ACC, 0.18), Color(0, 0, 0, 0), 0).with_bar(ACC, 0, 2.0))
	t.set_stylebox("separator", "VSeparator", _box(Color(0, 0, 0, 0), LINE, 1, Vector4(2, 0, 2, 0)))
	t.set_stylebox("separator", "HSeparator", _box(Color(0, 0, 0, 0), LINE, 2, Vector4(0, 2, 0, 2)))
	# tabs: plain caps, the active one underlined in gold
	var tab := _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, Vector4(7, 2, 7, 3))
	var tab_on := _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, Vector4(7, 2, 7, 3)).with_bar(ACC, 3, 2.0)
	t.set_stylebox("tab_unselected", "TabBar", tab)
	t.set_stylebox("tab_hovered", "TabBar", tab)
	t.set_stylebox("tab_selected", "TabBar", tab_on)
	t.set_stylebox("tab_unselected", "TabContainer", tab)
	t.set_stylebox("tab_hovered", "TabContainer", tab)
	t.set_stylebox("tab_selected", "TabContainer", tab_on)
	t.set_stylebox("panel", "TabContainer", _box(Color(0, 0, 0, 0), LINE, 2, Vector4(4, 6, 4, 4)))
	t.set_color("font_selected_color", "TabBar", Color(1, 1, 1))
	t.set_color("font_unselected_color", "TabBar", DIM)
	t.set_color("font_hovered_color", "TabBar", TEXT)
	t.set_color("font_selected_color", "TabContainer", Color(1, 1, 1))
	t.set_color("font_unselected_color", "TabContainer", DIM)
	t.set_color("font_hovered_color", "TabContainer", TEXT)
	# small flat icons instead of Godot's round defaults: slider grabber, check boxes
	var gr := _icon_tex(4, 10, func(x, y): return Color(1, 1, 1))
	var gr_h := _icon_tex(4, 10, func(x, y): return ACC_HI)
	for cls in ["HSlider", "VSlider"]:
		t.set_icon("grabber", cls, gr)
		t.set_icon("grabber_highlight", cls, gr_h)
		t.set_icon("grabber_disabled", cls, _icon_tex(4, 10, func(x, y): return Color(DIM, 0.5)))
	var box_off := _icon_tex(9, 9, func(x, y): return Color(1, 1, 1, 0.55) if x == 0 or y == 0 or x == 8 or y == 8 else Color(0, 0, 0, 0))
	var box_on := _icon_tex(9, 9, func(x, y):
		if x == 0 or y == 0 or x == 8 or y == 8: return ACC
		return ACC if x >= 2 and x <= 6 and y >= 2 and y <= 6 else Color(0, 0, 0, 0))
	for cls in ["CheckBox", "CheckButton"]:
		for n in ["unchecked", "unchecked_disabled"]:
			t.set_icon(n, cls, box_off)
		for n in ["checked", "checked_disabled"]:
			t.set_icon(n, cls, box_on)
		t.set_icon("radio_unchecked", cls, box_off)
		t.set_icon("radio_checked", cls, box_on)
	t.set_icon("checked", "CheckButton", box_on)
	t.set_icon("unchecked", "CheckButton", box_off)
	_theme = t
	return t

## A panel title: gold caps on a hairline divider.
static func title(l: Label, size := 14) -> void:
	l.text = l.text.to_upper()
	l.add_theme_font_override("font", caps_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", ACC)
	l.add_theme_stylebox_override("normal", header())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

## A section name inside a window (small gold caps, divider under it).
static func section(l: Label, size := 8) -> void:
	l.text = l.text.to_upper()
	l.add_theme_font_override("font", caps_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", ACC)
	l.add_theme_stylebox_override("normal", header())

# ---- icons rendered from the game's models (tools/icons.gd) ------------------------------------
static func icon(id: String) -> Texture2D:
	var key := "icon_" + id
	if not _cache.has(key):
		var path := "res://assets/icons/%s.png" % id
		_cache[key] = load(path) if ResourceLoader.exists(path) else null
	return _cache[key]

## The item's picture behind the button's text (inventory slots); text gets a dark outline.
static func item_backdrop(b: Button, id: String, alpha := 0.85) -> void:
	var tr: TextureRect = b.get_node_or_null("Ico")
	if tr == null:
		tr = TextureRect.new()
		tr.name = "Ico"
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.offset_left = 8
		tr.offset_top = 2
		tr.offset_right = -3
		tr.offset_bottom = -2
		tr.show_behind_parent = false
		b.add_child(tr)
		b.move_child(tr, 0)
		b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		b.add_theme_constant_override("outline_size", 3)
	tr.texture = icon(id) if id != "" else null
	tr.modulate = Color(1, 1, 1, alpha)
	tr.visible = tr.texture != null

## An inventory tile in the UFO manner: the item's picture, its name under it, the key in the
## top-left corner and the count (rounds, uses) in the top-right. The button's own text is not used.
static func item_tile(b: Button, id: String, caption: String, key := "", count := "") -> void:
	b.text = ""
	var holder: Control = b.get_node_or_null("Tile")
	if holder == null:
		holder = Control.new()
		holder.name = "Tile"
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.set_anchors_preset(Control.PRESET_FULL_RECT)
		b.add_child(holder)
		var tr := TextureRect.new()
		tr.name = "Ico"
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.offset_left = 8
		tr.offset_top = 2
		tr.offset_right = -3
		tr.offset_bottom = -10
		holder.add_child(tr)
		for e in [["Cap", Control.PRESET_BOTTOM_WIDE, HORIZONTAL_ALIGNMENT_CENTER, Color(0.88, 0.92, 0.95)],
				["Key", Control.PRESET_TOP_LEFT, HORIZONTAL_ALIGNMENT_LEFT, GLOW],
				["Cnt", Control.PRESET_TOP_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT, AMBER]]:
			var l := Label.new()
			l.name = e[0]
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			l.add_theme_font_size_override("font_size", 7)
			l.add_theme_color_override("font_color", e[3])
			l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
			l.add_theme_constant_override("outline_size", 3)
			l.horizontal_alignment = e[2]
			l.clip_text = true
			holder.add_child(l)
			l.set_anchors_preset(e[1])
			if e[0] == "Cap":
				l.offset_top = -11
				l.offset_bottom = 0
				l.offset_left = 6
				l.offset_right = -2
			elif e[0] == "Key":
				l.position = Vector2(8, 0)
				l.size = Vector2(34, 10)
				l.clip_text = false
			else:
				l.offset_left = -40
				l.offset_right = -3
				l.offset_top = 0
				l.offset_bottom = 10
	var ico: TextureRect = holder.get_node("Ico")
	ico.texture = icon(id) if id != "" else null
	(holder.get_node("Cap") as Label).text = caption
	(holder.get_node("Key") as Label).text = key
	(holder.get_node("Cnt") as Label).text = count
	(holder.get_node("Cap") as Label).add_theme_color_override("font_color", Color(0.88, 0.92, 0.95) if id != "" else DIM)

## A small picture at the left of a list button (stores, armoury).
static func item_icon(b: Button, id: String, w := 30) -> void:
	b.icon = icon(id)
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", w)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
