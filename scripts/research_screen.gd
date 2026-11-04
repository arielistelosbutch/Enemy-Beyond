extends Control
class_name ResearchScreen
## The research tree: every project is a box with its picture, lines lead from what it needs.
## Columns go left to right as the knowledge builds up; the rows are the branches.
## Green = done, amber = in progress, cyan = can start now, grey = still locked.

const TEXT := Color(0.84, 0.89, 0.92)
const FRAME := Color(0.45, 0.78, 0.86)
const ACCENT := Color(1.0, 0.74, 0.32)
const DONE := Color(0.4, 0.9, 0.5)
const LOCKED := Color(0.38, 0.42, 0.47)
const RED := Color(1.0, 0.45, 0.35)
const NODE_W := 112.0
const NODE_H := 30.0
const COL_W := 136.0
const ROW_H := 36.0

var canvas: TreeCanvas
var detail: VBoxContainer
var head_lbl: Label
var bar: ProgressBar
var selected := ""
var nodes := {}            # id -> Button
var pos := {}              # id -> Vector2
var on_close: Callable
var on_changed: Callable

static func open(parent: Node) -> ResearchScreen:
	var s := ResearchScreen.new()
	parent.add_child(s)
	s.build()
	return s

func build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := TextureRect.new()
	bg.texture = UiSkin.backdrop()
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# header
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", UiSkin.panel(5))
	top.position = Vector2(4, 3)
	top.size = Vector2(632, 34)
	add_child(top)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 10)
	top.add_child(th)
	var t := Label.new()
	t.text = "VÝZKUM"
	th.add_child(t)
	UiSkin.title(t, 13)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 1)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	th.add_child(hv)
	head_lbl = _lbl(hv, "", TEXT, 8)
	bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(300, 6)
	bar.show_percentage = false
	hv.add_child(bar)
	_btn(th, "Encyklopedie", func(): _ency(""), 8).custom_minimum_size = Vector2(80, 16)
	_btn(th, "Zavřít", close, 8).custom_minimum_size = Vector2(60, 16)
	# the tree
	var tp := PanelContainer.new()
	tp.add_theme_stylebox_override("panel", UiSkin.inset(3))
	tp.position = Vector2(4, 40)
	tp.size = Vector2(430, 316)
	add_child(tp)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(424, 310)
	tp.add_child(sc)
	canvas = TreeCanvas.new()
	canvas.screen = self
	sc.add_child(canvas)
	# detail
	var dp := PanelContainer.new()
	dp.add_theme_stylebox_override("panel", UiSkin.panel(7))
	dp.position = Vector2(438, 40)
	dp.size = Vector2(198, 316)
	add_child(dp)
	var dsc := ScrollContainer.new()
	dsc.custom_minimum_size = Vector2(184, 300)
	dsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dp.add_child(dsc)
	detail = VBoxContainer.new()
	detail.custom_minimum_size = Vector2(178, 0)
	detail.add_theme_constant_override("separation", 3)
	dsc.add_child(detail)
	_layout()
	refresh()
	var cur := String(Campaign.data["research"]["current"])
	_select(cur if cur != "" else _first_available())

func _first_available() -> String:
	for id in Campaign.RESEARCH:
		if Campaign.research_available(id):
			return id
	return Campaign.RESEARCH.keys()[0]

func close() -> void:
	if on_close.is_valid():
		on_close.call()
	queue_free()

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()

func _lbl(parent: Node, s: String, col := TEXT, size := 9) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	parent.add_child(l)
	return l

func _btn(parent: Node, s: String, cb: Callable, size := 9) -> Button:
	var b := Button.new()
	b.text = s
	b.add_theme_font_size_override("font_size", size)
	UiSkin.button(b)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

# ---- layout: depth = longest chain of projects it needs --------------------------------------
var _depth := {}
func _d(id: String) -> int:
	if _depth.has(id):
		return _depth[id]
	var n: Dictionary = Campaign.RESEARCH[id]["needs"]
	var best := 0
	if n.has("research"):
		var reqs: Array = n["research"] if n["research"] is Array else [n["research"]]
		for r in reqs:
			best = maxi(best, _d(r) + 1)
	_depth[id] = best
	return best

func _layout() -> void:
	var y := 6.0
	var maxd := 0
	for br in Campaign.BRANCHES:
		var cols := {}
		for id in Campaign.RESEARCH:
			if Campaign.RESEARCH[id].get("branch", "") != br:
				continue
			var d := _d(id)
			maxd = maxi(maxd, d)
			if not cols.has(d):
				cols[d] = []
			cols[d].append(id)
		var rows := 1
		for d in cols:
			rows = maxi(rows, cols[d].size())
		canvas.bands.append([y, rows * ROW_H + 14.0, Campaign.BRANCHES[br]])
		for d in cols:
			for i in cols[d].size():
				pos[cols[d][i]] = Vector2(10 + d * COL_W, y + 12.0 + i * ROW_H)
		y += rows * ROW_H + 20.0
	canvas.custom_minimum_size = Vector2(20 + (maxd + 1) * COL_W, y)
	for id in Campaign.RESEARCH:
		var key: String = id
		var b := Button.new()
		b.position = pos[id]
		b.size = Vector2(NODE_W, NODE_H)
		b.focus_mode = Control.FOCUS_NONE
		b.text = String(Campaign.RESEARCH[id]["name"])
		b.add_theme_font_size_override("font_size", 7)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD
		b.clip_text = true
		var ic := String(Campaign.RESEARCH[id].get("icon", ""))
		if ic != "" and UiSkin.icon(ic):
			b.icon = UiSkin.icon(ic)
			b.expand_icon = true
			b.add_theme_constant_override("icon_max_width", 26)
		b.pressed.connect(func(): _select(key); Game.play_ui(self, "ui_click", -10))
		canvas.add_child(b)
		nodes[id] = b

func _state(id: String) -> String:
	if Campaign.researched(id):
		return "done"
	if Campaign.data["research"]["current"] == id:
		return "current"
	if Campaign.research_available(id):
		return "open"
	return "locked"

func _col(st: String) -> Color:
	return {"done": DONE, "current": ACCENT, "open": FRAME, "locked": LOCKED}[st]

func refresh() -> void:
	var r: Dictionary = Campaign.data["research"]
	var cur := String(r["current"])
	head_lbl.text = "Kredity: %d   Moskovium: %d g   Laboratoře: %d   Probíhá: %s" % [int(Campaign.data["credits"]), Campaign.moskovium(), Campaign.count("laborator"),
		(Campaign.RESEARCH[cur]["name"] + " %d %%" % int(float(r["progress"]) / Campaign.research_days(cur) * 100)) if cur != "" else "nic - vyber projekt"]
	bar.value = float(r["progress"]) / Campaign.research_days(cur) * 100.0 if cur != "" else 0.0
	for id in nodes:
		var b: Button = nodes[id]
		var st := _state(id)
		var sb := StyleBoxFlat.new()
		var c := _col(st)
		sb.bg_color = Color(c.r * 0.18, c.g * 0.18, c.b * 0.22, 0.95) if st != "locked" else Color(0.08, 0.09, 0.1, 0.9)
		sb.border_color = c if id != selected else Color(1, 1, 1)
		sb.set_border_width_all(1 if id != selected else 2)
		sb.set_corner_radius_all(2)
		sb.content_margin_left = 3
		for s in ["normal", "hover", "pressed"]:
			var s2: StyleBoxFlat = sb.duplicate()
			if s == "hover":
				s2.bg_color = s2.bg_color.lightened(0.12)
			b.add_theme_stylebox_override(s, s2)
		b.add_theme_color_override("font_color", c.lightened(0.3) if st != "locked" else LOCKED.lightened(0.15))
		b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
		b.modulate.a = 1.0 if st != "locked" else 0.8
	canvas.queue_redraw()

func _select(id: String) -> void:
	selected = id
	refresh()
	for c in detail.get_children():
		c.queue_free()
	var rr: Dictionary = Campaign.RESEARCH[id]
	var st := _state(id)
	var ic := String(rr.get("icon", ""))
	if ic != "" and UiSkin.icon(ic):
		var tr := TextureRect.new()
		tr.texture = UiSkin.icon(ic)
		tr.custom_minimum_size = Vector2(178, 54)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		detail.add_child(tr)
	var tl := _lbl(detail, String(rr["name"]).to_upper(), ACCENT, 10)
	UiSkin.title(tl, 10)
	_lbl(detail, {"done": "HOTOVO", "current": "PROBÍHÁ", "open": "LZE ZAHÁJIT", "locked": "ZAMČENO"}[st], _col(st), 8)
	_lbl(detail, String(rr["desc"]), TEXT, 8)
	_lbl(detail, "Cena: %d kr%s   Doba: %d dní" % [Campaign.research_cost(id), (" + %d g Moskovia" % int(rr["mk"])) if rr.has("mk") else "", ceili(Campaign.research_days(id))], FRAME, 8)
	var nl := Campaign.needs_list(id)
	if not nl.is_empty():
		_lbl(detail, "Vyžaduje:", FRAME, 8)
		for c in nl:
			_lbl(detail, ("  ✔ " if c[1] else "  ✘ ") + String(c[0]), DONE if c[1] else RED, 8)
	var lt := Campaign.leads_to(id)
	if not lt.is_empty():
		var names := []
		for k in lt:
			names.append(Campaign.RESEARCH[k]["name"])
		_lbl(detail, "Vede k: " + ", ".join(names), LOCKED.lightened(0.3), 8)
	if st == "open" and not Campaign.viewer:
		var busy := String(Campaign.data["research"]["current"]) != ""
		var b := _btn(detail, "Zahájit výzkum" if not busy else "Probíhá jiný výzkum", func():
			if Campaign.start_research(id):
				Game.play_ui(self, "ui_confirm", -6)
				if on_changed.is_valid(): on_changed.call()
				_select(id)
			else:
				Game.play_ui(self, "ui_deny", -6)
				_lbl(detail, "Nedostatek kreditů nebo Moskovia.", RED, 8), 9)
		b.disabled = busy
	var ent := EncyData.for_research(id)
	if st == "done" and ent != "":
		_btn(detail, "Otevřít v encyklopedii", func(): _ency(ent), 8)

func _ency(id: String) -> void:
	var e := Encyclopedia.open(self, id)
	e.z_index = 5

func _process(_d2: float) -> void:
	if canvas:
		canvas.pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
		if String(Campaign.data["research"]["current"]) != "":
			canvas.queue_redraw()

## The tree's background: branch bands and the lines from each project to what it opens.
class TreeCanvas extends Control:
	var screen
	var bands: Array = []
	var pulse := 0.0
	func _draw() -> void:
		for b in bands:
			draw_rect(Rect2(2, b[0], size.x - 4, b[1]), Color(0.1, 0.13, 0.17, 0.55))
			draw_line(Vector2(2, b[0]), Vector2(size.x - 2, b[0]), Color(0.3, 0.42, 0.5, 0.6), 1.0)
			draw_string(UiSkin.font(true), Vector2(6, b[0] + 9), String(b[2]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.5, 0.65, 0.72))
		for id in Campaign.RESEARCH:
			var n: Dictionary = Campaign.RESEARCH[id]["needs"]
			if not n.has("research"):
				continue
			var reqs: Array = n["research"] if n["research"] is Array else [n["research"]]
			for r in reqs:
				var a: Vector2 = screen.pos[r] + Vector2(screen.NODE_W, screen.NODE_H / 2)
				var b2: Vector2 = screen.pos[id] + Vector2(0, screen.NODE_H / 2)
				var done: bool = Campaign.researched(r)
				var col := Color(0.4, 0.9, 0.5, 0.85) if done else Color(0.4, 0.45, 0.5, 0.6)
				if id == screen.selected or r == screen.selected:
					col = Color(1.0, 0.85, 0.5, 0.95)
				var mx := a.x + 10.0
				var pts := PackedVector2Array([a, Vector2(mx, a.y), Vector2(mx, b2.y), b2])
				draw_polyline(pts, col, 1.5 if done else 1.0)
				draw_colored_polygon(PackedVector2Array([b2, b2 + Vector2(-5, -3), b2 + Vector2(-5, 3)]), col)
		var cur := String(Campaign.data["research"]["current"])
		if cur != "" and screen.pos.has(cur):
			var p: Vector2 = screen.pos[cur]
			draw_rect(Rect2(p - Vector2(3, 3), Vector2(screen.NODE_W + 6, screen.NODE_H + 6)), Color(1.0, 0.74, 0.32, 0.25 + pulse * 0.5), false, 2.0)
