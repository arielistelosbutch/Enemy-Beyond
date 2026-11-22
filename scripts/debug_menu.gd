extends CanvasLayer
## (0.80, Ari: "Debug mód na testování, něco co instantně odemkne všechno a takový ptákoviny")
## Hidden from normal players: nothing in the menus points to it. It wakes with the launch
## argument `--debug=1` or with Ctrl+Alt+Shift+D anywhere; then a small "DEBUG" shows in the
## corner and F10 opens the panel. What it can do depends on where you are:
##   campaign (solo / the host): all research done, money, everything into the stock, moskovium
##     and alloys, buildings / research / workshop finished, days forward, trust, a new mission;
##   your soldier (anyone): money, a promotion, talent points;
##   mission: invulnerability, kill all aliens (host), health and ammo, a turret and gear into the pack.
## In co-op the campaign buttons only work for the host (the others see his campaign), and the
## result goes to everybody as any other change of the campaign does.
const PANEL_W := 236.0

var on := false
var god := false
var _panel: PanelContainer
var _box: VBoxContainer
var _tag: Label
var _note: Label

func _ready() -> void:
	layer = 125
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tag = Label.new()
	_tag.text = "DEBUG  (F10)"
	_tag.add_theme_color_override("font_color", Color(1.0, 0.35, 0.25))
	_tag.add_theme_font_size_override("font_size", 8)
	_tag.position = Vector2(4, 2)
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag.visible = false
	add_child(_tag)
	if Game.cmd_arg("debug", "") == "1":
		toggle_mode(true)

func toggle_mode(v: bool) -> void:
	on = v
	_tag.visible = on
	if not on:
		god = false
		_close()

func _input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var k := e as InputEventKey
	if k.physical_keycode == KEY_D and k.ctrl_pressed and k.alt_pressed and k.shift_pressed:
		toggle_mode(not on)
		get_viewport().set_input_as_handled()
		return
	if on and k.physical_keycode == KEY_F10:
		if _panel and is_instance_valid(_panel):
			_close()
		else:
			_open()
		get_viewport().set_input_as_handled()

func _close() -> void:
	if _panel and is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null
	if _mission() and not _mission().get("finished") and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not _mission().hud.window_up():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _mission() -> Node:
	var s := get_tree().current_scene
	if s and s.has_method("local_player") and s.has_method("aliens"):
		return s
	return null

func _host() -> bool:
	return not Net.is_online() or multiplayer.is_server()

func _camp_ok() -> bool:
	return Campaign.active and not Campaign.viewer and not Campaign.closed and _host()

func _open() -> void:
	_close()
	_panel = PanelContainer.new()
	_panel.position = Vector2(8, 14)
	_panel.custom_minimum_size = Vector2(PANEL_W, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.06, 0.94)
	sb.border_color = Color(1.0, 0.35, 0.25)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(6)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(PANEL_W, 300)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(sc)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 2)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_box)
	_head("DEBUG - jen pro testování")
	_note = Label.new()
	_note.add_theme_font_size_override("font_size", 7)
	_note.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(PANEL_W - 12, 0)
	_box.add_child(_note)
	var m := _mission()
	if m:
		_head("MISE")
		_btn(("Nesmrtelnost: ZAP" if god else "Nesmrtelnost: VYP"), func(): god = not god; _say("Nesmrtelnost " + ("zapnutá." if god else "vypnutá.")); _open())
		_btn("Doplnit zdraví, výdrž a náboje", _heal_me)
		_btn("Do batohu: věž, Claymore, granáty, lékárny", _kit_me)
		if _host():
			_btn("Zabít všechny vetřelce", _kill_all)
		else:
			_dim("(zabít vetřelce může jen hostitel)")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Campaign.active:
		_head("KAMPAŇ")
		if _camp_ok():
			_btn("Veškerý výzkum hotový", _all_research)
			_btn("Dokončit stavby, výzkum a výrobu", _finish_all)
			_btn("+50 000 kr do rozpočtu", _btn_press_money)
			_btn("Vše do skladu (10 ks od všeho)", _stock_all)
			_btn("+200 Moskovia, +100 slitin", _mats)
			_btn("Důvěra na 100", func(): _camp(func(): Campaign.data["trust"] = 100, "Důvěra 100."))
			_btn("+1 den", func(): _days(1.0))
			_btn("+7 dní", func(): _days(7.0))
			_btn("Nová mise hned", _new_mission)
		else:
			_dim("(kampaň mění jen hostitel)")
	_head("MŮJ VOJÁK")
	_btn("+10 000 kr mně", func():
		Game.merc["money"] = int(Game.merc.get("money", 0)) + 10000
		_merc_saved("+10 000 kr na tvůj účet."))
	_btn("Povýšit o hodnost", _promote)
	_btn("+5 bodů do talentů", func():
		Game.merc["talent_points"] = int(Game.merc.get("talent_points", 0)) + 5
		_merc_saved("+5 bodů talentů."))
	_btn("Zavřít (F10)", _close)

func _head(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", Color(1.0, 0.45, 0.3))
	_box.add_child(l)

func _dim(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 7)
	l.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_box.add_child(l)

func _btn(t: String, f: Callable) -> void:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", 8)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(f)
	_box.add_child(b)

func _say(t: String) -> void:
	if _note and is_instance_valid(_note):
		_note.text = t
	print("[DEBUG] ", t)

func _merc_saved(t: String) -> void:
	Game.save_merc()
	if Net.is_online():
		Net.update_merc()
	_say(t)

func _camp(f: Callable, t: String) -> void:
	if not _camp_ok():
		return
	f.call()
	Campaign.save()
	Campaign.changed.emit()
	Net.broadcast_team()
	_say(t)

# ---- campaign ------------------------------------------------------------------------------
func all_research() -> void:
	var done: Array = Campaign.data["research"]["done"]
	for id in Campaign.RESEARCH:
		if not id in done:
			done.append(id)
	Campaign.data["research"]["current"] = ""
	Campaign.data["research"]["progress"] = 0.0
	if not Campaign.data.has("built"):
		Campaign.data["built"] = []
	for id in Campaign.UPGRADES:
		if not id in Campaign.data["built"]:
			Campaign.data["built"].append(id)

func _all_research() -> void:
	_camp(all_research, "Veškerý výzkum hotový (i vylepšení z dílny).")

func finish_all() -> void:
	for c in Campaign.data["base"]:
		if float(c["days"]) > 0.0:
			c["days"] = 0.0001
	var r: Dictionary = Campaign.data["research"]
	if String(r["current"]) != "":
		r["progress"] = Campaign.research_days(String(r["current"]))
	var now := float(Campaign.data["day"])
	for o in Campaign.data.get("orders", []):
		if o.has("work"):
			o["work"] = 0.0
		o["at"] = now
	Campaign.advance(0.0002)

func _finish_all() -> void:
	_camp(finish_all, "Stavby, výzkum a výroba dokončené.")

func stock_all(n := 10) -> void:
	for id in Game.ITEMS:
		var ty := String(Game.ITEMS[id].get("type", ""))
		if ty in ["salvage", ""] or String(id).begins_with("a_") or String(id).begins_with("al_"):
			continue
		Campaign.data["armory"][id] = int(Campaign.data["armory"].get(id, 0)) + n

func _btn_press_money() -> void:
	_camp(func(): Campaign.data["credits"] = int(Campaign.data["credits"]) + 50000, "+50 000 kr.")

func _stock_all() -> void:
	_camp(stock_all, "Do skladu přibylo 10 ks od každé věci.")

func _mats() -> void:
	_camp(func():
		Campaign.data["moskovium"] = Campaign.moskovium() + 200
		if not Campaign.data.has("found"):
			Campaign.data["found"] = {}
		Campaign.data["found"]["slitiny"] = Campaign.alloys() + 100, "+200 Moskovia, +100 slitin.")

func _days(d: float) -> void:
	_camp(func():
		var left := d
		while left > 0.0:
			var st := minf(0.05, left)
			Campaign.advance(st)
			left -= st, "Čas posunut o %s." % ("1 den" if d == 1.0 else "%d dní" % int(d)))

func _new_mission() -> void:
	_camp(func():
		var ms: Dictionary = Campaign.generate_mission()
		if not ms.is_empty():
			Campaign.data["missions"].append(ms)
			Campaign.mission_found.emit(ms), "Nová mise je na glóbu.")

# ---- soldier -------------------------------------------------------------------------------
func _promote() -> void:
	var r := Game.rank_of(Game.merc)
	var need := 0
	for xp in range(int(Game.merc.get("xp", 0)), int(Game.merc.get("xp", 0)) + 100000, 25):
		Game.merc["xp"] = xp
		if Game.rank_of(Game.merc) > r:
			need = xp
			break
	Game.merc["xp"] = int(Game.merc.get("xp", 0))
	if need == 0:
		_say("Vyšší hodnost už není.")
		return
	Game.merc["xp"] = need - 1
	var lines := Game.add_xp(1)
	_merc_saved(("Povýšen. " + " ".join(lines)) if not lines.is_empty() else "Povýšen.")

# ---- mission -------------------------------------------------------------------------------
func _heal_me() -> void:
	var p: Node = _mission().local_player() if _mission() else null
	if p == null:
		return
	if p.has_method("debug_refill"):
		p.debug_refill()
	_say("Zdraví, výdrž a náboje doplněné.")

func _kit_me() -> void:
	var p: Node = _mission().local_player() if _mission() else null
	if p == null:
		return
	var given := 0
	for id in ["sentry", "mine", "mine", "grenade", "grenade", "medkit", "medkit", "flare"]:
		for s in Game.pack_slots():
			if not p.inv.has(s):
				p.inv[s] = {"id": id}
				given += 1
				break
	p._update_held()
	_say("Do batohu: %d věcí." % given)

func _kill_all() -> void:
	var m := _mission()
	if m == null or not _host():
		return
	var n := 0
	for a in m.aliens():
		if not a.dead:
			m.hit_kind = "explosion"
			a.damage(99999.0, a.global_position + Vector3(0, 5, 0), null)
			m.hit_kind = ""
			n += 1
	_say("Zneškodněno vetřelců: %d." % n)
