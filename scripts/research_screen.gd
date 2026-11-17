extends Control
class_name ResearchScreen
## The research tree: every project is a box with its picture, lines lead from what it needs.
## Columns go left to right as the knowledge builds up; the rows are the branches.
## Green = done, amber = in progress, cyan = can start now, grey = still locked.

const TEXT := UiSkin.TEXT
const FRAME := Color(0.67, 0.70, 0.74)   # 0.72: neutral secondary text (was cyan)
const ACCENT := UiSkin.ACC
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
	# 0.72 (návrh A): a full screen - breadcrumb, the tree on the left, the project on the right, keys
	var sc0 := UiSkin.screen(self, ["Základna", "Výzkum"], "", [["LTM", "vybrat projekt"], ["", "zlatě hotovo · bíle lze zahájit · ??? zatím neznámé"], ["Esc", "zpět"]], 1.0)
	head_lbl = sc0["status"]
	var body: VBoxContainer = sc0["body"]
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 14)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cols)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 3)
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(lv)
	bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 2)
	bar.show_percentage = false
	var bgs := StyleBoxFlat.new()
	bgs.bg_color = Color(1, 1, 1, 0.08)
	var fgs := StyleBoxFlat.new()
	fgs.bg_color = ACCENT
	bar.add_theme_stylebox_override("background", bgs)
	bar.add_theme_stylebox_override("fill", fgs)
	lv.add_child(bar)
	# the tree
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(400, 0)
	lv.add_child(sc)
	canvas = TreeCanvas.new()
	canvas.screen = self
	sc.add_child(canvas)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 6)
	lv.add_child(foot)
	_btn(foot, "Encyklopedie", func(): _ency(""), 8)
	var zb := _btn(foot, "Zpět", close, 8)
	UiSkin.ghost(zb)
	# detail
	var dsc := ScrollContainer.new()
	dsc.custom_minimum_size = Vector2(188, 0)
	dsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cols.add_child(dsc)
	detail = VBoxContainer.new()
	detail.custom_minimum_size = Vector2(180, 0)
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
	UiSkin.auto(b)
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

## 0.50: research keeps its secrets. A project is known (name, needs) once it can be started or is done;
## the ones that follow straight after a known one show only as "???"; the rest are not shown at all.
func known(id: String) -> bool:
	var st := _state(id)
	return st != "locked"

func hinted(id: String) -> bool:
	if known(id):
		return true
	var n: Dictionary = Campaign.RESEARCH[id]["needs"]
	if not n.has("research"):
		return true          # (something to be found out there: its place shows, nothing more)
	var reqs: Array = n["research"] if n["research"] is Array else [n["research"]]
	for r in reqs:
		if Campaign.researched(r):
			return true
	return false

func _state(id: String) -> String:
	if Campaign.researched(id):
		return "done"
	if Campaign.data["research"]["current"] == id:
		return "current"
	if Campaign.research_available(id):
		return "open"
	return "locked"

func _col(st: String) -> Color:
	return {"done": ACCENT, "current": UiSkin.ACC_HI, "open": TEXT, "locked": UiSkin.DIM}[st]

func refresh() -> void:
	var r: Dictionary = Campaign.data["research"]
	var cur := String(r["current"])
	head_lbl.text = ("Kredity %d · moskovium %d g · laboratoře %d · probíhá %s" % [int(Campaign.data["credits"]), Campaign.moskovium(), Campaign.count("laborator"),
		(Campaign.RESEARCH[cur]["name"] + " %d %%" % int(float(r["progress"]) / Campaign.research_days(cur) * 100)) if cur != "" else "nic - vyber projekt"]).to_upper()
	bar.value = float(r["progress"]) / Campaign.research_days(cur) * 100.0 if cur != "" else 0.0
	for id in nodes:
		var b: Button = nodes[id]
		var st := _state(id)
		b.visible = hinted(id)
		var kn := known(id)
		b.text = String(Campaign.RESEARCH[id]["name"]) if kn else "???"
		var ic := String(Campaign.RESEARCH[id].get("icon", ""))
		b.icon = UiSkin.icon(ic) if kn and ic != "" and UiSkin.icon(ic) else null
		# 0.72 (návrh A): gold = done, gold bar = in progress, white = can start, dim = unknown
		var c := _col(st)
		var fill: Color = {"done": Color(ACCENT, 0.10), "current": Color(ACCENT, 0.16), "open": Color(1, 1, 1, 0.04), "locked": Color(1, 1, 1, 0.015)}[st]
		var line: Color = {"done": Color(ACCENT, 0.7), "current": ACCENT, "open": Color(1, 1, 1, 0.55), "locked": Color(1, 1, 1, 0.12)}[st]
		if id == selected:
			line = UiSkin.ACC_HI
		var sb := UiBox.make(fill, line, 15, Vector4(3, 1, 3, 1))
		if st == "current":
			sb = sb.with_bar(ACCENT, 0, 2.0)
		var sh := UiBox.make(Color(fill.r, fill.g, fill.b, fill.a + 0.06), UiSkin.ACC_HI, 15, Vector4(3, 1, 3, 1))
		for s3 in ["normal", "pressed", "focus"]:
			b.add_theme_stylebox_override(s3, sb)
		b.add_theme_stylebox_override("hover", sh)
		b.add_theme_color_override("font_color", c)
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
	if not known(id):
		var tl0 := _lbl(detail, "???", ACCENT, 10)
		UiSkin.title(tl0, 10)
		_lbl(detail, "NEZNÁMÝ PROJEKT", LOCKED.lightened(0.3), 8)
		_lbl(detail, "Laboratoř zatím neví, co tu hledat. Něco z toho, co je venku, ještě nemáme - nebo jsme to ještě nepochopili. Přineste z boje víc.", TEXT, 8)
		return
	var ic := String(rr.get("icon", ""))
	if ic != "" and UiSkin.icon(ic):
		var tr := TextureRect.new()
		tr.texture = UiSkin.icon(ic)
		tr.custom_minimum_size = Vector2(178, 54)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		detail.add_child(tr)
	var stt: String = {"done": "Hotovo", "current": "Probíhá", "open": "Lze zahájit", "locked": "Zamčeno"}[st]
	if st == "current":
		stt += " · %d %%" % int(float(Campaign.data["research"]["progress"]) / Campaign.research_days(id) * 100)
	var el := _lbl(detail, stt, _col(st), 7)
	UiSkin.eyebrow(el, ACCENT if st in ["done", "current"] else UiSkin.DIM, 7)
	var tl := _lbl(detail, String(rr["name"]), TEXT, 12)
	UiSkin.headline(tl, 12)
	tl.custom_minimum_size = Vector2(178, 0)
	_lbl(detail, String(rr["desc"]), Color(0.80, 0.83, 0.86), 7).custom_minimum_size = Vector2(178, 0)
	UiSkin.kv(detail, "Cena", "%d kr%s" % [Campaign.research_cost(id), (" + %d g Mk" % int(rr["mk"])) if rr.has("mk") else ""])
	UiSkin.kv(detail, "Doba", "%d dní" % ceili(Campaign.research_days(id)))
	var nl := Campaign.needs_list(id)
	if not nl.is_empty() and st != "done":
		var ok := true
		for c in nl:
			ok = ok and bool(c[1])
		UiSkin.kv(detail, "Vyžaduje", "" if ok else "chybí", TEXT if ok else RED)
		for c in nl:
			var cl := _lbl(detail, ("✔ " if c[1] else "✘ ") + String(c[0]), UiSkin.OK if c[1] else RED, 7)
			cl.custom_minimum_size = Vector2(178, 0)
	var lt := Campaign.leads_to(id)
	if not lt.is_empty():
		var names := []
		for k in lt:
			names.append(Campaign.RESEARCH[k]["name"] if known(k) else "???")
		_lbl(detail, "Vede k: " + ", ".join(names), UiSkin.DIM, 7).custom_minimum_size = Vector2(178, 0)
	if st == "open" and not Campaign.viewer:
		var busy := String(Campaign.data["research"]["current"]) != ""
		var b := _btn(detail, "ZAHÁJIT VÝZKUM" if not busy else "Probíhá jiný výzkum", func():
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
			draw_line(Vector2(2, b[0]), Vector2(size.x - 2, b[0]), UiSkin.LINE, 1.0)
			draw_string(UiSkin.caps_font(), Vector2(6, b[0] + 9), String(b[2]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UiSkin.DIM)
		for id in Campaign.RESEARCH:
			var n: Dictionary = Campaign.RESEARCH[id]["needs"]
			if not n.has("research"):
				continue
			var reqs: Array = n["research"] if n["research"] is Array else [n["research"]]
			if not screen.hinted(id):
				continue
			for r in reqs:
				if not screen.hinted(r):
					continue
				var a: Vector2 = screen.pos[r] + Vector2(screen.NODE_W, screen.NODE_H / 2)
				var b2: Vector2 = screen.pos[id] + Vector2(0, screen.NODE_H / 2)
				var done: bool = Campaign.researched(r)
				var col := Color(UiSkin.ACC, 0.6) if done else Color(1, 1, 1, 0.18)
				if id == screen.selected or r == screen.selected:
					col = UiSkin.ACC_HI
				var mx := a.x + 10.0
				var pts := PackedVector2Array([a, Vector2(mx, a.y), Vector2(mx, b2.y), b2])
				draw_polyline(pts, col, 1.5 if done else 1.0)
				draw_colored_polygon(PackedVector2Array([b2, b2 + Vector2(-5, -3), b2 + Vector2(-5, 3)]), col)
		var cur := String(Campaign.data["research"]["current"])
		if cur != "" and screen.pos.has(cur):
			var p: Vector2 = screen.pos[cur]
			draw_rect(Rect2(p - Vector2(3, 3), Vector2(screen.NODE_W + 6, screen.NODE_H + 6)), Color(UiSkin.ACC, 0.2 + pulse * 0.4), false, 1.0)
