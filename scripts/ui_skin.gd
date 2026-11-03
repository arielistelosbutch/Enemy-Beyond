class_name UiSkin
## The look of every menu: gunmetal plates with chamfered corners, bevelled steel edges and a thin
## cyan glow line - a late-90s military terminal. Everything is drawn here in code (no image files),
## so one place decides how panels, buttons, fields and scrollbars look.

const TEXT := Color(0.84, 0.89, 0.92)
const DIM := Color(0.55, 0.62, 0.67)
const GLOW := Color(0.36, 0.86, 0.96)       # the cyan of screens and edge lights
const AMBER := Color(1.0, 0.74, 0.32)       # titles and warnings (the old UFO amber)
const STEEL_HI := Color(0.56, 0.62, 0.66)
const STEEL_LO := Color(0.05, 0.06, 0.07)

static var _cache := {}
static var _theme: Theme

static func font(bold := false) -> Font:
	var key := "font_b" if bold else "font"
	if not _cache.has(key):
		var f := FontVariation.new()
		f.base_font = load("res://assets/fonts/ChakraPetch-%s.ttf" % ("SemiBold" if bold else "Regular"))
		f.spacing_glyph = 1 if bold else 0
		_cache[key] = f
	return _cache[key]

# ---- pixel helpers -----------------------------------------------------------------------------
static func _noise(x: int, y: int, seed := 0) -> float:
	var h := (x * 374761393 + y * 668265263 + seed * 2147483647) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h & 1023) / 1023.0

## Is (x, y) cut off by a chamfer of size c in the given corners (tl, tr, br, bl)?
static func _cut(x: int, y: int, w: int, h: int, c: int, corners: Array) -> bool:
	if corners[0] and x + y < c: return true
	if corners[1] and (w - 1 - x) + y < c: return true
	if corners[2] and (w - 1 - x) + (h - 1 - y) < c: return true
	if corners[3] and x + (h - 1 - y) < c: return true
	return false

## Distance (in pixels) from the plate's outline, chamfers included.
static func _edge(x: int, y: int, w: int, h: int, c: int, corners: Array) -> int:
	var d := mini(mini(x, y), mini(w - 1 - x, h - 1 - y))
	if corners[0]: d = mini(d, x + y - c)
	if corners[1]: d = mini(d, (w - 1 - x) + y - c)
	if corners[2]: d = mini(d, (w - 1 - x) + (h - 1 - y) - c)
	if corners[3]: d = mini(d, x + (h - 1 - y) - c)
	return d

## A steel plate: top/bottom gradient, brushed grain, bevel, an optional cyan line inside the rim.
static func _plate(w: int, h: int, chamfer: int, corners: Array, top: Color, bottom: Color,
		rim: Color, glow: Color, scan := true, rivets := false) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			if _cut(x, y, w, h, chamfer, corners):
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var e := _edge(x, y, w, h, chamfer, corners)
			var c := top.lerp(bottom, float(y) / float(h - 1))
			c = c.lightened(( _noise(x / 3, y, 7) - 0.5) * 0.05)       # brushed grain, horizontal
			if scan and y % 2 == 1:
				c = c.darkened(0.06)
			if e == 0:
				c = rim
			elif e == 1:
				# bevel: light from the top left
				var lit := (y < h / 2 and x < w - 2) or x < 2
				c = STEEL_HI if lit else STEEL_LO
				c.a = top.a
			elif e == 3 and glow.a > 0.0:
				c = c.lerp(Color(glow, 1.0), glow.a)
			img.set_pixel(x, y, c)
	if rivets:
		for p in [Vector2i(w - 6, 5), Vector2i(5, h - 6)]:
			img.set_pixel(p.x, p.y, STEEL_HI)
			img.set_pixel(p.x + 1, p.y, Color(0.32, 0.36, 0.39))
			img.set_pixel(p.x, p.y + 1, Color(0.32, 0.36, 0.39))
			img.set_pixel(p.x + 1, p.y + 1, STEEL_LO)
	return ImageTexture.create_from_image(img)

static func _box(tex: Texture2D, m: int, content: Vector4) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.set_texture_margin_all(m)
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.content_margin_left = content.x
	sb.content_margin_top = content.y
	sb.content_margin_right = content.z
	sb.content_margin_bottom = content.w
	return sb

# ---- the pieces ----------------------------------------------------------------------------------
## The big window panel (menus, popups, inventory).
static func panel(margin := 9.0) -> StyleBox:
	var key := "panel%d" % int(margin)
	if not _cache.has(key):
		var t := _plate(48, 48, 9, [true, false, true, false], Color(0.15, 0.17, 0.19, 0.97),
			Color(0.08, 0.09, 0.105, 0.97), Color(0.02, 0.025, 0.03), Color(GLOW, 0.45), true, true)
		_cache[key] = _box(t, 14, Vector4(margin, margin, margin, margin))
	return _cache[key]

## A smaller inset panel (side bars, info boxes): darker, recessed.
static func inset(margin := 5.0) -> StyleBox:
	var key := "inset%d" % int(margin)
	if not _cache.has(key):
		var t := _plate(24, 24, 4, [false, true, false, true], Color(0.06, 0.075, 0.085, 0.95),
			Color(0.09, 0.105, 0.115, 0.95), Color(0.22, 0.27, 0.30), Color(0, 0, 0, 0), true)
		_cache[key] = _box(t, 7, Vector4(margin, margin, margin, margin))
	return _cache[key]

## Title strip at the top of a panel: dark glass with a cyan underline and a notch.
static func header() -> StyleBox:
	if not _cache.has("header"):
		var w := 32
		var h := 14
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			for x in w:
				var c := Color(0.03, 0.08, 0.10, 0.85).lerp(Color(0.05, 0.14, 0.17, 0.85), float(y) / h)
				if y % 2 == 1:
					c = c.darkened(0.15)
				if y == h - 1:
					c = Color(GLOW, 0.9)
				elif y == h - 2:
					c = Color(GLOW, 0.25)
				img.set_pixel(x, y, c)
		var sb := _box(ImageTexture.create_from_image(img), 3, Vector4(8, 2, 8, 4))
		_cache["header"] = sb
	return _cache["header"]

static func _btn_tex(state: String) -> StyleBox:
	var key := "btn_" + state
	if not _cache.has(key):
		var t: ImageTexture
		match state:
			"normal": t = _plate(24, 16, 4, [true, false, false, false], Color(0.30, 0.33, 0.36), Color(0.15, 0.17, 0.19),
				Color(0.03, 0.035, 0.04), Color(GLOW, 0.0), false)
			"hover": t = _plate(24, 16, 4, [true, false, false, false], Color(0.20, 0.40, 0.46), Color(0.09, 0.20, 0.25),
				Color(GLOW, 0.95), Color(GLOW, 0.35), false)
			"pressed": t = _plate(24, 16, 4, [true, false, false, false], Color(0.06, 0.16, 0.20), Color(0.14, 0.32, 0.38),
				Color(GLOW, 1.0), Color(0, 0, 0, 0), false)
			"disabled": t = _plate(24, 16, 4, [true, false, false, false], Color(0.12, 0.13, 0.14), Color(0.09, 0.10, 0.11),
				Color(0.05, 0.05, 0.06), Color(0, 0, 0, 0), false)
		# a lamp on the left edge: dim on the normal button, lit when the mouse is over it
		var img := t.get_image()
		var lamp: Color = {"normal": Color(0.20, 0.42, 0.48), "hover": GLOW, "pressed": Color(1, 1, 1), "disabled": Color(0.16, 0.17, 0.18)}[state]
		for y in range(5, 11):
			img.set_pixel(3, y, lamp)
		t = ImageTexture.create_from_image(img)
		_cache[key] = _box(t, 5, Vector4(9, 2, 6, 2))
	return _cache[key]

## Gives a button the steel look (keeps the button's own font size).
static func button(b: BaseButton) -> void:
	for s in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(s, _btn_tex(s))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover_pressed", _btn_tex("pressed"))
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color(0.92, 1.0, 1.0))
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	b.add_theme_color_override("font_disabled_color", Color(0.42, 0.45, 0.47))

## A slot / tile button tinted by what it holds (base facilities and the like).
static func tile(b: BaseButton, tint: Color) -> void:
	var key := "tile_%s" % tint.to_html()
	if not _cache.has(key):
		var t := _plate(24, 24, 5, [true, false, true, false], tint.lightened(0.15), tint.darkened(0.35),
			Color(0.03, 0.035, 0.04), Color(GLOW, 0.3), true)
		_cache[key] = _box(t, 7, Vector4(4, 3, 4, 3))
	b.add_theme_stylebox_override("normal", _cache[key])
	b.add_theme_stylebox_override("hover", _btn_tex("hover"))

static func field() -> StyleBox:
	if not _cache.has("field"):
		var t := _plate(16, 16, 3, [false, false, true, false], Color(0.03, 0.05, 0.06), Color(0.05, 0.08, 0.09),
			Color(0.30, 0.40, 0.45), Color(0, 0, 0, 0), true)
		_cache["field"] = _box(t, 4, Vector4(5, 2, 5, 2))
	return _cache["field"]

## The background behind the menus: bulkhead plates with seams, rivets and a dark vignette.
static func backdrop(w := 640, h := 360) -> ImageTexture:
	if _cache.has("backdrop"):
		return _cache["backdrop"]
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var pw := 96
	var ph := 72
	for y in h:
		for x in w:
			var px := x % pw
			var py := (y + (ph / 2 if (x / pw) % 2 == 1 else 0)) % ph
			var c := Color(0.075, 0.085, 0.095).lerp(Color(0.045, 0.05, 0.058), float(py) / ph)
			c = c.lightened((_noise(x / 4, y, 3) - 0.5) * 0.04)
			if px == 0 or py == 0:
				c = Color(0.02, 0.022, 0.025)
			elif px == 1 or py == 1:
				c = Color(0.13, 0.145, 0.16)
			if (px == 5 or px == pw - 6) and (py == 5 or py == ph - 6):
				c = Color(0.22, 0.24, 0.26)
			if y % 3 == 0:
				c = c.darkened(0.12)
			# vignette
			var v := Vector2(float(x) / w - 0.5, float(y) / h - 0.5).length()
			c = c.darkened(clampf(v * 1.3 - 0.15, 0.0, 0.75))
			img.set_pixel(x, y, c)
	_cache["backdrop"] = ImageTexture.create_from_image(img)
	return _cache["backdrop"]

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
	t.set_stylebox("panel", "TooltipPanel", inset(4))
	t.set_color("font_color", "TooltipLabel", TEXT)
	for s in ["normal", "hover", "pressed", "disabled"]:
		for cls in ["Button", "OptionButton", "MenuButton"]:
			t.set_stylebox(s, cls, _btn_tex(s))
	for cls in ["Button", "OptionButton", "MenuButton", "CheckBox", "CheckButton"]:
		t.set_stylebox("focus", cls, StyleBoxEmpty.new())
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, Color(0.92, 1.0, 1.0))
		t.set_color("font_pressed_color", cls, Color(1, 1, 1))
		t.set_color("font_disabled_color", cls, Color(0.42, 0.45, 0.47))
	t.set_color("font_color", "Label", TEXT)
	for cls in ["LineEdit", "TextEdit", "SpinBox"]:
		t.set_stylebox("normal", cls, field())
		t.set_stylebox("focus", cls, field())
		t.set_stylebox("read_only", cls, field())
		t.set_color("font_color", cls, Color(0.75, 0.97, 1.0))
		t.set_color("caret_color", cls, GLOW)
		t.set_color("selection_color", cls, Color(GLOW, 0.35))
	# scrollbars: a thin steel rail with a cyan grabber
	var rail := StyleBoxFlat.new()
	rail.bg_color = Color(0.04, 0.05, 0.055, 0.8)
	rail.border_color = Color(0.20, 0.24, 0.27)
	rail.set_border_width_all(1)
	rail.set_content_margin_all(2)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(0.30, 0.36, 0.40)
	grab.border_color = Color(0.5, 0.56, 0.6)
	grab.set_border_width_all(1)
	var grab_h := grab.duplicate()
	grab_h.bg_color = Color(0.2, 0.55, 0.62)
	grab_h.border_color = GLOW
	for cls in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", cls, rail)
		t.set_stylebox("grabber", cls, grab)
		t.set_stylebox("grabber_highlight", cls, grab_h)
		t.set_stylebox("grabber_pressed", cls, grab_h)
	# sliders: dark slot, cyan fill
	var slot := StyleBoxFlat.new()
	slot.bg_color = Color(0.03, 0.04, 0.05)
	slot.border_color = Color(0.25, 0.3, 0.33)
	slot.set_border_width_all(1)
	slot.content_margin_top = 2
	slot.content_margin_bottom = 2
	var fill := slot.duplicate()
	fill.bg_color = Color(0.16, 0.5, 0.58)
	fill.border_color = GLOW
	for cls in ["HSlider", "VSlider"]:
		t.set_stylebox("slider", cls, slot)
		t.set_stylebox("grabber_area", cls, fill)
		t.set_stylebox("grabber_area_highlight", cls, fill)
	var pb := slot.duplicate()
	t.set_stylebox("background", "ProgressBar", pb)
	t.set_stylebox("fill", "ProgressBar", fill)
	t.set_color("font_color", "ProgressBar", TEXT)
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color(0.92, 1.0, 1.0))
	var hov := StyleBoxFlat.new()
	hov.bg_color = Color(0.12, 0.32, 0.38)
	t.set_stylebox("hover", "PopupMenu", hov)
	t.set_stylebox("separator", "VSeparator", StyleBoxLine.new())
	_theme = t
	return t

## A panel title: amber caps on a dark glass strip.
static func title(l: Label, size := 14) -> void:
	l.text = l.text.to_upper()
	l.add_theme_font_override("font", font(true))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", AMBER)
	l.add_theme_stylebox_override("normal", header())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

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
