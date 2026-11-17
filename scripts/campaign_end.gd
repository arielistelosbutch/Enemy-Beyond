extends Control
## (0.7x, Ari 2026-11-15: "Game over obrazovka chybí se statistikou") The end of a campaign on one
## screen: why it ended, how long the war lasted, the missions, the aliens put down (by the race
## names the team already knows - no hidden numbers, hardcore), the fallen and the best soldiers.
## The globe opens it when the campaign is lost (or won) - the host, solo player and co-op mates
## alike (the mates get the host's last state, Campaign.close_campaign). The main menu shows the
## record of ended campaigns with it too (Campaign.past_campaigns).

const FRAME := Color(0.67, 0.70, 0.74)   # 0.72: neutral secondary text (was cyan)
const TEXT := UiSkin.TEXT
const DIM := Color(0.6, 0.66, 0.7)
const ACCENT := UiSkin.ACC
const RED := Color(1.0, 0.4, 0.3)
const GOLD := Color(0.95, 0.8, 0.4)

var panel: PanelContainer
var buttons: HBoxContainer

## s = Campaign.summary(); acts = [[text, Callable], ...] (the buttons at the bottom).
func setup(s: Dictionary, acts: Array) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.015, 0.03, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiSkin.panel(8))
	panel.position = Vector2(14, 8)
	panel.size = Vector2(612, 344)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	var won: bool = s.get("won", false)
	var tl := _lbl(box, "VÍTĚZSTVÍ" if won else "KONEC KAMPANĚ", ACCENT if won else RED, 14)
	UiSkin.title(tl, 14)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var why := _lbl(box, String(s.get("why", "")), GOLD if won else RED, 9)
	why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var days := int(s.get("days", 0))
	var dn := "den" if days == 1 else ("dny" if days >= 2 and days <= 4 else "dní")
	var bloc := String(s.get("bloc", ""))
	var head := _lbl(box, "%s - %s  (%d %s)   Obtížnost: %s   Základna: %s%s" % [s.get("start", ""), s.get("end", ""), days, dn,
		Game.DIFF_NAMES.get(String(s.get("diff", "")), String(s.get("diff", ""))), s.get("place", ""), (" (%s)" % bloc) if bloc != "" else ""], FRAME, 8)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(0, 230)
	box.add_child(sc)
	var cols := HBoxContainer.new()
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 12)
	sc.add_child(cols)
	var left := _col(cols)
	var right := _col(cols)
	# --- the war
	_head(left, "VÁLKA")
	var ms := int(s.get("missions", 0))
	var mw := int(s.get("won_missions", 0))
	_row(left, "Mise", "%d  (úspěch %d, neúspěch %d)" % [ms, mw, ms - mw])
	_row(left, "Zneškodnění vetřelci", str(int(s.get("kills", 0))))
	_row(left, "Zajatí vetřelci", str(int(s.get("captures", 0))))
	_row(left, "Sestřelená UFO", _n(s, "ufo_down"))
	_row(left, "Ztracené stíhačky", _n(s, "jets_lost"))
	var cs := int(s.get("civ_saved", -1))
	var cd := int(s.get("civ_dead", -1))
	_row(left, "Civilisté", "-" if cs < 0 else "zachráněno %d, mrtvých %d" % [cs, cd])
	_row(left, "Dokončený výzkum", "%d projektů" % int(s.get("research", 0)))
	_row(left, "Výdělek z misí", _n(s, "earned", " kr"))
	_row(left, "Rozpočet na konci", "%d kr" % int(s.get("credits", 0)))
	_row(left, "Důvěra států", "%d %%" % int(s.get("trust", 0)))
	_row(left, "Moskovium 115", "%d g" % int(s.get("moskovium", 0)))
	var races: Array = s.get("races", [])
	if not races.is_empty():
		_head(left, "ZNEŠKODNĚNO PODLE DRUHU")
		for r in races:
			_row(left, String(r[0]), str(int(r[1])))
	# --- the soldiers
	_head(right, "PADLÍ ZA PROJEKT X")
	var fallen := int(s.get("fallen", 0))
	var mia := int(s.get("mia", 0))
	if fallen == 0:
		_lbl(right, "Nikdo nepadl.", TEXT, 8)
	else:
		_lbl(right, "%d %s%s" % [fallen, "voják" if fallen == 1 else ("vojáci" if fallen <= 4 else "vojáků"), (", z toho nezvěstní %d" % mia) if mia > 0 else ""], TEXT, 8)
		for f in s.get("fallen_list", []):
			var l := _lbl(right, "%s%s - %s, %s%s" % [String(f[0]), "  (NEZVĚSTNÝ)" if f[3] else "", String(f[4]), String(f[1]),
				(", zabití %d" % int(f[2])) if int(f[2]) > 0 else ""], GOLD, 7)
			l.custom_minimum_size = Vector2(290, 0)
		if fallen > (s.get("fallen_list", []) as Array).size():
			_lbl(right, "a dalších %d" % (fallen - (s.get("fallen_list", []) as Array).size()), DIM, 7)
	var best: Array = s.get("best", [])
	if not best.is_empty():
		_head(right, "NEJLEPŠÍ VOJÁCI")
		for b in best:
			_row(right, String(b[0]) + (" †" if b[3] else ""), "zabití %d, mise %d" % [int(b[1]), int(b[2])])
	buttons = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)
	for a in acts:
		var bt := Button.new()
		bt.text = String(a[0])
		bt.add_theme_font_size_override("font_size", 10)
		UiSkin.button(bt)
		bt.focus_mode = Control.FOCUS_NONE
		bt.pressed.connect(a[1])
		buttons.add_child(bt)

func _n(s: Dictionary, k: String, unit := "") -> String:
	var v := int(s.get(k, -1))
	return "-" if v < 0 else str(v) + unit       # (a save older than this screen did not count it)

func _col(parent: Node) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_theme_constant_override("separation", 1)
	parent.add_child(c)
	return c

func _head(parent: Node, s: String) -> void:
	var l := _lbl(parent, s, ACCENT, 9)
	l.custom_minimum_size = Vector2(0, 14)

func _row(parent: Node, k: String, v: String) -> void:
	var h := HBoxContainer.new()
	parent.add_child(h)
	var a := _lbl(h, k, DIM, 8)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.autowrap_mode = TextServer.AUTOWRAP_OFF
	a.clip_text = true
	var b := _lbl(h, v, TEXT, 8)
	b.autowrap_mode = TextServer.AUTOWRAP_OFF
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _lbl(parent: Node, s: String, col: Color, size: int) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	parent.add_child(l)
	return l

func _unhandled_input(event: InputEvent) -> void:
	# (Esc does not throw the screen away - the buttons decide; the globe below must not get it)
	if event is InputEventKey and event.pressed:
		get_viewport().set_input_as_handled()
