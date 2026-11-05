class_name EdUI
## The editors at full window resolution (0.52, after the Svitky Světlenu editor): the game draws
## its menus at 640x360 and stretches them, which made the old editors tiny. While an editor is
## open the window shows real pixels (scaled for big screens), with a plain dark theme, normal-sized
## text, panels along the sides and the 3D view in the middle. Leaving the editor puts the game's
## stretching back. Also: small widget helpers and the 3D overlay (lines, dots, rings drawn in
## pixels on top of everything) the editors draw their handles with.

const BG := Color(0.09, 0.10, 0.11)
const PANEL := Color(0.13, 0.145, 0.16)
const PANEL2 := Color(0.17, 0.19, 0.21)
const LINE := Color(0.27, 0.31, 0.34)
const TEXT := Color(0.88, 0.91, 0.93)
const DIM := Color(0.58, 0.63, 0.67)
const ACCENT := Color(0.36, 0.86, 0.96)
const AMBER := Color(1.0, 0.74, 0.32)
const AXIS_COL := [Color8(235, 70, 60), Color8(110, 210, 80), Color8(80, 140, 250)]

static var _saved := {}
static var _theme: Theme

## Real pixels while an editor is open (call in _ready; it restores itself when @a node leaves).
static func enter(node: Control) -> void:
	var w := node.get_window()
	if _saved.is_empty():
		_saved = {"mode": w.content_scale_mode, "aspect": w.content_scale_aspect, "factor": w.content_scale_factor}
	w.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	w.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	w.content_scale_factor = clampf(float(w.size.y) / 1000.0, 1.0, 2.0)
	node.theme = theme()
	node.set_meta("ed_native", true)
	var tree := node.get_tree()
	node.tree_exiting.connect(func():
		# (going to another editor keeps the real pixels; the game gets its stretching back)
		await tree.process_frame
		await tree.process_frame
		var nxt := tree.current_scene
		if nxt == null or not nxt.has_meta("ed_native"):
			leave(w))

static func leave(w: Window) -> void:
	if _saved.is_empty() or w == null:
		return
	w.content_scale_mode = _saved["mode"]
	w.content_scale_aspect = _saved["aspect"]
	w.content_scale_factor = _saved["factor"]
	_saved = {}

static func _flat(bg: Color, border := Color(0, 0, 0, 0), bw := 0, margin := 6.0, radius := 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	return s

static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 14
	t.set_stylebox("panel", "PanelContainer", _flat(PANEL, LINE, 1, 8, 6))
	t.set_stylebox("panel", "Panel", _flat(PANEL, LINE, 1, 8, 6))
	t.set_stylebox("panel", "PopupPanel", _flat(PANEL, LINE, 1, 6, 6))
	t.set_stylebox("panel", "PopupMenu", _flat(PANEL, LINE, 1, 4, 4))
	t.set_stylebox("panel", "TooltipPanel", _flat(Color(0.05, 0.06, 0.07, 0.95), LINE, 1, 6, 4))
	t.set_color("font_color", "TooltipLabel", TEXT)
	var normal := _flat(PANEL2, LINE, 1, 6, 4)
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	var hover := normal.duplicate()
	hover.border_color = ACCENT
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.12, 0.30, 0.34)
	pressed.border_color = ACCENT
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.13, 0.14, 0.15)
	for cls in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", cls, normal)
		t.set_stylebox("hover", cls, hover)
		t.set_stylebox("pressed", cls, pressed)
		t.set_stylebox("hover_pressed", cls, pressed)
		t.set_stylebox("disabled", cls, disabled)
		t.set_stylebox("focus", cls, StyleBoxEmpty.new())
	for cls in ["Button", "OptionButton", "MenuButton", "CheckBox", "CheckButton", "Label", "ItemList", "PopupMenu", "LineEdit", "SpinBox"]:
		t.set_color("font_color", cls, TEXT)
	for cls in ["Button", "OptionButton", "MenuButton", "CheckBox"]:
		t.set_color("font_hover_color", cls, Color(1, 1, 1))
		t.set_color("font_pressed_color", cls, ACCENT)
		t.set_color("font_hover_pressed_color", cls, ACCENT)
		t.set_color("font_disabled_color", cls, Color(0.45, 0.48, 0.5))
	t.set_stylebox("focus", "CheckBox", StyleBoxEmpty.new())
	for cls in ["LineEdit", "SpinBox"]:
		t.set_stylebox("normal", cls, _flat(Color(0.07, 0.08, 0.09), LINE, 1, 5, 4))
		t.set_stylebox("focus", cls, _flat(Color(0.07, 0.08, 0.09), ACCENT, 1, 5, 4))
		t.set_color("caret_color", cls, ACCENT)
		t.set_color("selection_color", cls, Color(ACCENT, 0.35))
	t.set_stylebox("panel", "ItemList", _flat(Color(0.07, 0.08, 0.09), LINE, 1, 4, 4))
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("selected", "ItemList", _flat(Color(0.12, 0.33, 0.38), Color(0, 0, 0, 0), 0, 2, 2))
	t.set_stylebox("selected_focus", "ItemList", _flat(Color(0.12, 0.33, 0.38), Color(0, 0, 0, 0), 0, 2, 2))
	t.set_stylebox("hovered", "ItemList", _flat(Color(0.14, 0.17, 0.19), Color(0, 0, 0, 0), 0, 2, 2))
	t.set_color("font_selected_color", "ItemList", Color(1, 1, 1))
	t.set_stylebox("hover", "PopupMenu", _flat(Color(0.12, 0.32, 0.38), Color(0, 0, 0, 0), 0, 2, 2))
	t.set_stylebox("panel", "TabContainer", _flat(PANEL, LINE, 1, 8, 6))
	var rail := _flat(Color(0.06, 0.07, 0.08), Color(0, 0, 0, 0), 0, 2, 3)
	var grab := _flat(Color(0.30, 0.36, 0.40), Color(0, 0, 0, 0), 0, 2, 3)
	var grab_h := _flat(Color(0.2, 0.55, 0.62), Color(0, 0, 0, 0), 0, 2, 3)
	for cls in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", cls, rail)
		t.set_stylebox("grabber", cls, grab)
		t.set_stylebox("grabber_highlight", cls, grab_h)
		t.set_stylebox("grabber_pressed", cls, grab_h)
	var slot := _flat(Color(0.05, 0.06, 0.07), LINE, 1, 2, 3)
	var fill := _flat(Color(0.16, 0.5, 0.58), Color(0, 0, 0, 0), 0, 2, 3)
	t.set_stylebox("slider", "HSlider", slot)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_stylebox("separator", "HSeparator", StyleBoxLine.new())
	_theme = t
	return t

# ---- widgets ---------------------------------------------------------------------------------------
static func btn(parent: Node, text: String, cb: Callable, tip := "", toggle := false) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.toggle_mode = toggle
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

static func lbl(parent: Node, text: String, col := TEXT, size := 0, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", col)
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)
	return l

static func head(parent: Node, text: String) -> Label:
	var l := lbl(parent, text.to_upper(), AMBER, 12)
	l.add_theme_constant_override("line_spacing", 0)
	return l

static func row(parent: Node, sep := 4) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	parent.add_child(h)
	return h

static func grid(parent: Node, cols: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	parent.add_child(g)
	return g

static func opt(parent: Node, items: Array, cb: Callable) -> OptionButton:
	## items: [[value, text], ...]
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	for it in items:
		o.add_item(String(it[1]))
		o.set_item_metadata(o.item_count - 1, it[0])
	o.item_selected.connect(func(i): cb.call(o.get_item_metadata(i)))
	parent.add_child(o)
	return o

static func opt_select(o: OptionButton, value) -> void:
	for i in o.item_count:
		if o.get_item_metadata(i) == value:
			o.select(i)
			return

static func spin(parent: Node, lo: float, hi: float, step: float, cb: Callable, suffix := "") -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.suffix = suffix
	s.allow_greater = true
	s.allow_lesser = true
	s.custom_minimum_size = Vector2(84, 0)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.select_all_on_focus = true
	s.value_changed.connect(cb)
	parent.add_child(s)
	return s

static func check(parent: Node, text: String, on: bool, cb: Callable, tip := "") -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = on
	c.tooltip_text = tip
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(cb)
	parent.add_child(c)
	return c

static func panel(parent: Node) -> VBoxContainer:
	## A side panel that scrolls when it gets long.
	var p := PanelContainer.new()
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(p)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	sc.add_child(v)
	return v

## The tab bar of the editor (native size): the parts of the editor, the way back to the game.
static func tabs(parent: Node, active: String) -> HBoxContainer:
	var bar := row(parent, 6)
	var t := lbl(bar, "EDITOR", AMBER, 16)
	t.custom_minimum_size = Vector2(80, 0)
	for tab in EditorTabs.TABS:
		var b := Button.new()
		b.text = tab[1]
		b.focus_mode = Control.FOCUS_NONE
		if not ResourceLoader.exists(tab[2]):
			b.disabled = true
			b.text = tab[1] + " (brzy)"
		elif tab[0] == active:
			b.disabled = true
			b.add_theme_color_override("font_disabled_color", AMBER)
		else:
			var path: String = tab[2]
			b.pressed.connect(func(): parent.get_tree().change_scene_to_file(path))
		bar.add_child(b)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(sp)
	var back := Button.new()
	back.text = "Do menu"
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func(): parent.get_tree().change_scene_to_file("res://scenes/Main.tscn"))
	bar.add_child(back)
	return bar

## A message box with OK / Cancel; @a ok runs on OK.
static func ask(parent: Node, text: String, ok: Callable, ok_text := "Ano") -> void:
	var d := ConfirmationDialog.new()
	d.dialog_text = text
	d.ok_button_text = ok_text
	d.cancel_button_text = "Zrušit"
	d.confirmed.connect(func(): ok.call(); d.queue_free())
	d.canceled.connect(d.queue_free)
	parent.add_child(d)
	d.popup_centered()

## A 3D view with its own world: [container, viewport, world root, camera].
static func view3d(parent: Node, bg := Color(0.13, 0.15, 0.17)) -> Array:
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	svc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	svc.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(svc)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.handle_input_locally = false
	svc.add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = bg
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.62, 0.66)
	env.environment = e
	world.add_child(env)
	for d in [[Vector3(-40, 30, 0), 1.2], [Vector3(-25, 210, 0), 0.6]]:
		var l := DirectionalLight3D.new()
		l.rotation_degrees = d[0]
		l.light_energy = d[1]
		world.add_child(l)
	var cam := Camera3D.new()
	cam.fov = 45.0
	world.add_child(cam)
	return [svc, vp, world, cam]

## A floor grid (1 m squares, faint 10 cm lines near the middle) - drawn by a shader on a flat
## square, not with lines (lines that pass under the camera smear on some graphics drivers).
const GRID_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
uniform float half_size = 4.0;
float gl(vec2 p, float step_m, float w) {
	vec2 g = abs(fract(p / step_m - 0.5) - 0.5) * step_m;
	vec2 fw = fwidth(p) * w;
	vec2 l = 1.0 - smoothstep(vec2(0.0), fw, g);
	return max(l.x, l.y);
}
void fragment() {
	vec2 p = (inverse(VIEW_MATRIX) * vec4(VERTEX, 1.0)).xz;
	float major = gl(p, 1.0, 1.2);
	float minor = gl(p, 0.1, 0.8) * (1.0 - smoothstep(0.6, 1.6, length(p)));
	float axis = max(1.0 - smoothstep(0.0, fwidth(p.x) * 1.6, abs(p.x)), 1.0 - smoothstep(0.0, fwidth(p.y) * 1.6, abs(p.y)));
	float edge = 1.0 - smoothstep(half_size * 0.7, half_size, max(abs(p.x), abs(p.y)));
	vec3 col = mix(vec3(0.32, 0.36, 0.4), vec3(0.5, 0.55, 0.6), axis);
	ALBEDO = col;
	ALPHA = max(max(major * 0.8, minor * 0.25), axis * 0.9) * edge;
}
"""

static func grid3d(world: Node3D, size := 4.0) -> MeshInstance3D:
	var pm := PlaneMesh.new()
	pm.size = Vector2(size * 2.0, size * 2.0)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	var sh := Shader.new()
	sh.code = GRID_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("half_size", size)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = 0.001
	world.add_child(mi)
	return mi

# ---- the overlay: handles drawn in pixels, always on top -----------------------------------------
class Overlay:
	extends MeshInstance3D
	var cam: Camera3D
	var vp: SubViewport
	var _v := PackedVector3Array()
	var _c := PackedColorArray()
	var _im := ImmediateMesh.new()

	func _init(c: Camera3D, v: SubViewport) -> void:
		cam = c
		vp = v
		mesh = _im
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.no_depth_test = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.render_priority = 100
		material_override = m
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		extra_cull_margin = 16384.0

	## The size of one pixel (metres) at a point.
	func px(at: Vector3) -> float:
		var d := (cam.global_position - at).length()
		if cam.projection == Camera3D.PROJECTION_ORTHOGONAL:
			return cam.size / maxf(float(vp.size.y), 1.0)
		return 2.0 * d * tan(deg_to_rad(cam.fov) * 0.5) / maxf(float(vp.size.y), 1.0)

	func clear() -> void:
		_v.clear()
		_c.clear()

	func line(a: Vector3, b: Vector3, col: Color, w_px := 2.0) -> void:
		var mid := (a + b) * 0.5
		var side := (b - a).cross(mid - cam.global_position)
		if side.length_squared() < 1e-14:
			return
		side = side.normalized() * w_px * 0.5 * px(mid)
		for v in [a - side, a + side, b + side, a - side, b + side, b - side]:
			_v.append(v)
			_c.append(col)

	func dot(p: Vector3, col: Color, size_px := 8.0) -> void:
		var b := cam.global_transform.basis
		var s := size_px * 0.5 * px(p)
		var x := b.x * s
		var y := b.y * s
		for v in [p - x - y, p + x - y, p + x + y, p - x - y, p + x + y, p - x + y]:
			_v.append(v)
			_c.append(col)

	func tri(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
		for v in [a, b, c]:
			_v.append(v)
			_c.append(col)

	func ring(o: Vector3, axis: Vector3, r: float, col: Color, w_px := 2.5) -> void:
		var a := axis.normalized()
		var u := a.cross(Vector3.UP if absf(a.y) < 0.9 else Vector3.RIGHT).normalized()
		var v := a.cross(u).normalized()
		var pts: Array = []
		for k in 41:
			var t := TAU * k / 40.0
			pts.append(o + (u * cos(t) + v * sin(t)) * r)
		for k in pts.size() - 1:
			line(pts[k], pts[k + 1], col, w_px)

	func box(corners: Array, col: Color, w_px := 1.5) -> void:
		for e in [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]:
			line(corners[e[0]], corners[e[1]], col, w_px)

	func flush() -> void:
		_im.clear_surfaces()
		if _v.is_empty():
			return
		_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in _v.size():
			_im.surface_set_color(_c[i])
			_im.surface_add_vertex(_v[i])
		_im.surface_end()

static func ring_points(o: Vector3, axis: Vector3, r: float, n := 40) -> Array:
	var a := axis.normalized()
	var u := a.cross(Vector3.UP if absf(a.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := a.cross(u).normalized()
	var pts: Array = []
	for k in n + 1:
		var t := TAU * k / float(n)
		pts.append(o + (u * cos(t) + v * sin(t)) * r)
	return pts

## A rectangle drawn while dragging out a selection (2D, over the view).
class SelRect:
	extends Control
	var a := Vector2.ZERO
	var b := Vector2.ZERO
	var on := false
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
	func _draw() -> void:
		if not on:
			return
		var r := Rect2(a, b - a).abs()
		draw_rect(r, Color(0.36, 0.86, 0.96, 0.12), true)
		draw_rect(r, Color(0.36, 0.86, 0.96, 0.9), false, 1.0)
