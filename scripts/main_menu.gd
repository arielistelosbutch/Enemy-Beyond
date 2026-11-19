extends Control
const MapGen := preload("res://scripts/map_gen.gd")
## Main menu in the spirit of UFO's screens: dark blue panels, light frames.

const BG := Color(0.04, 0.045, 0.05)
const PANEL := Color(0.10, 0.115, 0.13)
const FRAME := Color(0.67, 0.70, 0.74)   # 0.72: neutral secondary text (was cyan)
const TEXT := UiSkin.TEXT
const ACCENT := UiSkin.ACC

var _box: VBoxContainer
var _confirm_new := false
var _confirm_fire := false
var _arrows: Callable       # 0.72: ↑↓ on the open screen (dir -1 / +1)
var _esc: Callable          # 0.72: what Esc does on the open screen (none = nothing)
var _status: Label

func _ready() -> void:
	if Game.autotest() != "": print("[MENU] main menu ready")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.texture = UiSkin.backdrop()
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# 0.66 (Ari): his title picture behind the menu - bright on the main screen, dimmed under the others;
	# it covers any window shape (cut at the edges, never stretched)
	if ResourceLoader.exists(TITLE_PIC):
		_title = TextureRect.new()
		_title.name = "TitlePic"
		_title.texture = load(TITLE_PIC)
		_title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_title.set_anchors_preset(Control.PRESET_FULL_RECT)
		_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_title)
	_build_logo()
	Net.roster_changed.connect(_refresh_lobby)
	Net.wallets_changed.connect(_refresh_lobby)
	Net.stock_changed.connect(_stock_redraw)
	Net.note.connect(_on_note)
	Net.connection_failed.connect(func(r): _show_main(r))
	Net.connected_ok.connect(_show_lobby)
	# coming back from the globe or from a co-op mission
	if Game.open_screen != "":
		var scr := Game.open_screen
		Game.open_screen = ""
		_back_target = "geo"
		if scr == "loadout": _show_loadout()
		elif scr == "merc": _show_merc()
		elif scr == "money": _show_money()
		elif scr == "mods": _show_mods()
		elif scr == "lobby":
			_back_target = ""
			_show_lobby()        # (0.7x: the host after the end of a co-op campaign - the friends stay)
		elif scr == "quick":
			_back_target = ""
			_show_quick()
	elif Net.drop_reason != "":
		# the line to the host ended outside the menu (kicked on his globe, he quit)
		var why := Net.drop_reason
		Net.drop_reason = ""
		_show_main(why)
	elif Net.is_online() and not multiplayer.is_server():
		_show_lobby()
	elif Game.autotest() == "" and Game.seen_version != Game.VERSION_NUM and Game.changelog().has(Game.VERSION_NUM):
		_show_news()
	else:
		_show_main()
	Game.play_music("main_menu")
	# (0.70) the intro film on the very first start (only here, never on the way back from a game)
	if INTRO_ON and Game.autotest() == "" and not Game.intro_seen and not Net.is_online() and _back_target == "":
		_play_intro()
	if Game.autotest() == "":
		Game.update_changed.connect(_upd_refresh)
		Game.check_update()
	_autotest.call_deferred()

## (0.70) Ari 2026-11-11: the intro stays locked out of the game for now ("bude potřebovat hodně lásky") -
## no first-start film, no "Úvod" button; the code and its test (--autotest=introshots) stay for later.
const INTRO_ON := false
## (0.70) The intro film (scripts/intro.gd) over the menu; when it ends or is skipped, the menu's music.
func _play_intro() -> void:
	if get_node_or_null("Intro"):
		return
	var it: CanvasLayer = preload("res://scripts/intro.gd").new()
	it.finished.connect(func():
		Game.intro_seen = true
		Game.save_settings()
		Game.play_music("main_menu"))
	add_child(it)

var _back_target := ""
var _mods_from := ""      # 0.66: the weapon parts opened from the soldier / the kit screen - Back goes there
func _back() -> void:
	if _back_target == "lobby" or (Net.is_online() and not multiplayer.is_server() and _back_target == ""):
		_back_target = ""
		Net.update_merc()
		_show_lobby()
	elif _back_target == "geo":
		_back_target = ""
		Game.goto_globe()          # 0.72: the parked globe comes back at once (no loading)
	elif _back_target == "quick":
		_back_target = ""
		_show_quick()
	elif _back_target == "campaign":
		_back_target = ""
		_show_campaign()
	else:
		_show_main()

# ---- helpers -----------------------------------------------------------------
## 0.72 (Ari, návrh A): the rail on the left - the game's name, the main choices one under another
## (the open one with a gold bar), the version under them. Windows open to the right of it; a wide
## screen that would lie over it hides it (one thing at a time).
const RAIL_X := 18.0
const RAIL_W := 140.0
const RAIL := [["campaign", "Kampaň"], ["quick", "Rychlá mise"], ["coop", "Co-op"], ["merc", "Vojáci"],
	["settings", "Nastavení"], ["editor", "Editor"], ["quit", "Ukončit"]]
var _rail_btns := {}
var _rail_on := ""
var _rail_off := false          # a wide screen: no rail at all

func _build_logo() -> void:
	var dim := TextureRect.new()      # the picture darkens towards the rail, so the words read
	dim.name = "RailDim"
	dim.texture = _rail_shade()
	dim.stretch_mode = TextureRect.STRETCH_SCALE
	dim.position = Vector2.ZERO
	dim.size = Vector2(380, 360)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var holder := Control.new()      # not a PanelContainer: screens clear those
	holder.name = "Logo"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var v := VBoxContainer.new()
	v.name = "Rail"
	v.add_theme_constant_override("separation", 2)
	v.position = Vector2(RAIL_X, 88)
	v.custom_minimum_size = Vector2(RAIL_W, 0)
	holder.add_child(v)
	var name_l := Label.new()
	name_l.text = "OPERACE X"
	name_l.add_theme_font_override("font", UiSkin.font(true))
	name_l.add_theme_font_size_override("font_size", 24)
	name_l.add_theme_color_override("font_color", UiSkin.TEXT)
	v.add_child(name_l)
	var sub := Label.new()
	sub.text = "ENEMY BEYOND"
	sub.add_theme_font_override("font", UiSkin.caps_font())
	sub.add_theme_font_size_override("font_size", 8)
	sub.add_theme_color_override("font_color", UiSkin.ACC)
	v.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 12)
	v.add_child(gap)
	for e in RAIL:
		if e[0] == "editor" and not OS.has_feature("editor"):
			continue
		var b := Button.new()
		b.name = "Rail_" + e[0]
		b.text = e[1]
		b.add_theme_font_size_override("font_size", 11)
		b.custom_minimum_size = Vector2(RAIL_W - 20, 17)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_rail_go.bind(e[0]))
		v.add_child(b)
		_rail_btns[e[0]] = b
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 10)
	v.add_child(gap2)
	var ver := Label.new()
	ver.text = "verze %s  ·  pocta UFO: Enemy Unknown" % Game.VERSION
	ver.add_theme_font_size_override("font_size", 7)
	ver.add_theme_color_override("font_color", UiSkin.DIM)
	v.add_child(ver)
	_rail_paint()

static func _rail_shade() -> ImageTexture:
	var img := Image.create(64, 4, false, Image.FORMAT_RGBA8)
	for x in 64:
		var t := float(x) / 63.0
		var a := 0.93 if t < 0.35 else lerpf(0.93, 0.0, smoothstep(0.35, 1.0, t))
		for y in 4:
			img.set_pixel(x, y, Color(0.02, 0.027, 0.043, a))
	return ImageTexture.create_from_image(img)

func _rail_paint() -> void:
	for k in _rail_btns:
		var b: Button = _rail_btns[k]
		var on: bool = k == _rail_on
		UiSkin.button(b)
		var m := Vector4(8, 1, 6, 1)
		var idle := UiBox.make(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, m)
		var lit := UiBox.make(Color(UiSkin.ACC, 0.08), Color(0, 0, 0, 0), 0, m).with_bar(UiSkin.ACC, 0, 2.0)
		var hov := UiBox.make(Color(1, 1, 1, 0.05), Color(0, 0, 0, 0), 0, m).with_bar(Color(1, 1, 1, 0.5), 0, 2.0)
		b.add_theme_stylebox_override("normal", lit if on else idle)
		b.add_theme_stylebox_override("hover", lit if on else hov)
		b.add_theme_stylebox_override("pressed", lit)
		b.add_theme_stylebox_override("hover_pressed", lit)
		b.add_theme_color_override("font_color", UiSkin.ACC if on else UiSkin.TEXT)
		b.add_theme_color_override("font_hover_color", UiSkin.ACC_HI if on else Color(1, 1, 1))

func _rail_go(k: String) -> void:
	_back_target = ""
	match k:
		"campaign": _show_campaign()
		"quick": _show_quick()
		"coop": _show_coop()
		"merc": _show_merc()
		"settings": _show_settings()
		"editor": _show_editor()
		"quit": get_tree().quit()

## Which rail item a window belongs to (by its title).
const RAIL_OF := {"KAMPAŇ": "campaign", "NOVÁ KAMPAŇ": "campaign", "SKONČENÉ KAMPANĚ": "campaign",
	"RYCHLÁ MISE": "quick", "CO-OP": "coop", "PŘIPOJIT KE HŘE": "coop", "NASTAVENÍ": "settings", "EDITOR": "editor"}

## The full-width screens (soldiers, recruiting, upgrades) cover the logo; the small ones show it.
const TITLE_PIC := "res://assets/ui/titulni_obrazovka.png"
var _title: TextureRect
var _title_mode := false        # the main screen: the picture in full, the buttons in a row under the logo

## 0.72: one thing at a time - the rail gives way to any window that would lie over it.
func _logo_clear(_p: Control) -> void:
	_rail_tick()

func _rail_tick() -> void:
	var l: Control = get_node_or_null("Logo")
	if l == null:
		return
	var free := not _rail_off
	if free:
		var rr := Rect2(Vector2(RAIL_X - 4, 0), Vector2(RAIL_W + 6, 360))
		for c in get_children():
			if c is PanelContainer and c.visible and not c.is_queued_for_deletion() and not String(c.name).begins_with("PanelKeys") and (c as Control).get_global_rect().intersects(rr):
				free = false
				break
	l.visible = free
	var d: Control = get_node_or_null("RailDim")
	if d:
		d.visible = free

func _logo(on: bool) -> void:
	_rail_off = not on
	_rail_tick()

## (0.7x) the armory changed (a teammate took something, a delivery came): the kit screen redraws
## when what I can take is different now.
var _panel_title := ""
var _stock_sig := ""
func _stock_redraw() -> void:
	if _panel_title != "VÝSTROJ NA MISI" or not is_inside_tree():
		return
	var sig := str(Game.stash_for(Game.difficulty == "veteran"))
	if sig != _stock_sig:
		_show_loadout()

func _panel(title: String) -> void:
	_panel_title = title
	_esc = _back
	_arrows = Callable()
	_hotkeys = {}
	_logo(true)
	_rail_on = RAIL_OF.get(title, "")
	_rail_paint()
	_title_mode = false
	if _title:
		_title.modulate = Color(0.3, 0.31, 0.35)
	_free_preview()
	for c in get_children():
		if c is PanelContainer:
			c.queue_free()
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiSkin.panel(10))
	p.position = Vector2(170, 8)
	p.custom_minimum_size = Vector2(300, 0)
	add_child(p)
	_logo_clear.call_deferred(p)
	# the content scrolls when it would not fit on the screen
	_menu_prev_want = Vector2.ZERO
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(_scroll)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 3)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_box)
	var t := Label.new()
	t.text = title.substr(0, 1) + title.substr(1).to_lower()     # 0.72 (návrh A): "Rychlá mise", bold, no caps
	UiSkin.headline(t, 14)
	_box.add_child(t)
	_status = null
	_panel_keys([["Esc", "zpět"]])

## 0.72 (direction A): a full screen - breadcrumb and status on top, key bar at the bottom, the
## body in between (returned; 612 x ~314 canvas units). Used by Vojáci, Talenty, Úpravy zbraní,
## tvorba vojáka, Výstroj na misi and Tým.
var _scr_status: Label
var _scr_keys: HBoxContainer
func _screen(parts: Array, status: String, keys: Array) -> VBoxContainer:
	_rl_w = 370.0
	_panel_title = ""
	_esc = _back
	_arrows = Callable()
	_hotkeys = {}
	_logo(false)
	_free_preview()
	for c in get_children():
		if c is PanelContainer:
			c.queue_free()
	_scroll = null
	var p := PanelContainer.new()
	p.name = "Screen"
	p.add_theme_stylebox_override("panel", UiSkin.full(Vector4(0, 0, 0, 0)))
	p.position = Vector2.ZERO
	p.custom_minimum_size = Vector2(640, 360)
	p.size = Vector2(640, 360)
	add_child(p)
	_cr_ui = p
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	p.add_child(col)
	var top := MarginContainer.new()
	for side in ["left", "right"]:
		top.add_theme_constant_override("margin_" + side, 14)
	top.add_theme_constant_override("margin_top", 8)
	top.add_theme_constant_override("margin_bottom", 6)
	col.add_child(top)
	var bar := UiSkin.crumb(parts, status)
	top.add_child(bar)
	_scr_status = bar.get_node("Status")
	var mid := MarginContainer.new()
	for side in ["left", "right"]:
		mid.add_theme_constant_override("margin_" + side, 14)
	mid.add_theme_constant_override("margin_bottom", 6)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(mid)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(body)
	var kb := UiSkin.key_bar(keys)
	col.add_child(kb)
	_scr_keys = kb.get_child(0)
	return body

## 0.72: the key bar under a menu window (its own strip at the bottom of the screen).
func _panel_keys(keys: Array) -> void:
	var old_kb := get_node_or_null("PanelKeys")
	if old_kb:
		old_kb.name = "PanelKeysOld"
		old_kb.queue_free()
	if keys.is_empty():
		return
	var kb := UiSkin.key_bar(keys)
	kb.name = "PanelKeys"
	kb.set_meta("overlay", true)
	add_child(kb)
	var h := kb.get_combined_minimum_size().y
	kb.custom_minimum_size = Vector2(640, h)
	kb.size = Vector2(640, h)
	kb.position = Vector2(0, 360.0 - h)

func _label(text: String, color := TEXT, size := 10) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	_box.add_child(l)
	return l

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 11)
	UiSkin.auto(b)
	b.custom_minimum_size.y = 17
	b.pressed.connect(cb)
	_box.add_child(b)
	return b

# ---- screens ---------------------------------------------------------------------
## Quick mission types (also used by a hosted co-op game outside the campaign).
const QUICK := [
	["Noc na samotě (Šediváci, Diskoll)", {"group": "sedaci", "type": "crash", "type_name": "Havárie UFO", "biome": "farm", "place": "Samota u Telče", "extra_aliens": 0}],
	["Teror v městečku (Ještěřani, Líhavci, civilisté)", {"group": "jestetani", "type": "terror", "type_name": "Teror", "biome": "town", "place": "Městečko u Jihlavy", "extra_aliens": 1, "size": "huge"}],
	["Únos na venkově (Levité, Ohař)", {"group": "levite", "type": "abduction", "type_name": "Únos", "biome": "farm", "place": "Samota u Třeště", "extra_aliens": 0}],
	["Přistání v lesích (Bijci, Nádor, Ohnivec)", {"group": "bijci", "type": "landed", "type_name": "Přistání UFO", "biome": "forest", "place": "Lesy pod Javořicí", "extra_aliens": 2}],
	["Velká loď (Myslodějové, Kolos)", {"group": "myslodejove", "type": "landed", "type_name": "Přistání UFO", "biome": "forest", "place": "Lesy u Dačic", "extra_aliens": 2, "ufo": "harvester", "size": "large"}],
	["Zimní noc v horách (Šediváci, sníh)", {"group": "sedaci", "type": "crash", "type_name": "Havárie UFO", "biome": "forest", "place": "Krkonoše", "extra_aliens": 1, "terrain": "snow", "size": "medium"}],
	["Poušť (Bijci, Ohnivec)", {"group": "bijci", "type": "landed", "type_name": "Přistání UFO", "biome": "desert", "place": "Sahara", "extra_aliens": 1, "terrain": "desert", "size": "large"}],
	["Záchrana v horách (vědkyně, Levité, sníh)", {"group": "levite", "type": "rescue", "type_name": "Záchrana", "biome": "mountain", "place": "Krkonoše", "extra_aliens": 1, "terrain": "snow", "size": "large"}],
	["Sabotáž v průmyslovém areálu (Šediváci)", {"group": "sedaci", "type": "sabotage", "type_name": "Sabotáž", "biome": "industrial", "place": "Kladno - Poldi", "extra_aliens": 2, "size": "large"}],
	["Obrana základny (Bijci, vlny)", {"group": "bijci", "type": "base", "type_name": "Útok na základnu", "biome": "base", "place": "Základna - Vysočina", "extra_aliens": 2, "size": "medium"}],
	["Polární stanice (Šediváci, led)", {"group": "sedaci", "type": "sabotage", "type_name": "Sabotáž", "biome": "polar", "place": "Špicberky", "extra_aliens": 1, "terrain": "snow", "size": "large"}],
	["Teror v průmyslu (Ještěřani)", {"group": "jestetani", "type": "terror", "type_name": "Teror", "biome": "industrial", "place": "Ostrava - Vítkovice", "extra_aliens": 2, "size": "huge"}],
	["Karanténa (Nakažení, městečko)", {"group": "bijci", "type": "quarantine", "type_name": "Karanténa", "biome": "town", "place": "Slavonice", "extra_aliens": 1, "size": "large"}],
	["Štěnice na lodi (Šediváci, les, zkušební)", {"group": "sedaci", "type": "bug", "type_name": "Štěnice na lodi", "biome": "forest", "place": "Lesy u Telče", "extra_aliens": 1, "size": "medium", "crew_of": "raider", "ufo": "raider"}],
	["Uvízlý konvoj (Šediváci, les)", {"group": "sedaci", "type": "convoy", "type_name": "Uvízlý konvoj", "biome": "forest", "place": "Silnice u Jindřichova Hradce", "extra_aliens": 1, "size": "medium"}],
	["Poslední mise: Velín na Marsu (Velký mozek)", {"group": "myslodejove", "type": "mars", "type_name": "Velín na Marsu", "biome": "mars", "terrain": "mars", "place": "Mars - rudá pláň", "extra_aliens": 3, "size": "large"}],
	["Náhodná mise", {}],
]
var quick_pick := 0

static var quick_size := ""     # "" = by mission type; or small / medium / large / huge
static var quick_group := ""    # "" = by the scenario; else a group from Mission.GROUPS
static var quick_map := 0       # index into QUICK_MAPS (0 = by the scenario)
static var quick_night := true
static var quick_time := 0      # index into QUICK_TIMES
## Quick mission time of day: name, local hour.
const QUICK_TIMES := [["noc", 23.5], ["svítání", 6.2], ["den", 14.0], ["soumrak", 19.3], ["náhodně", -1.0]]
static var quick_merc := "copy"
## Maps for a quick mission: name, biome, terrain ("" = keep).
const QUICK_MAPS := [["podle scénáře", "", ""], ["statek", "farm", "temperate"], ["městečko", "town", "temperate"],
	["les", "forest", "temperate"], ["hory se sněhem", "mountain", "snow"], ["průmysl", "industrial", "temperate"],
	["poušť", "desert", "desert"], ["polární stanice", "polar", "snow"]]
static func quick_params(i: int) -> Dictionary:
	var pp: Dictionary = QUICK[i][1].duplicate()
	if not pp.is_empty():
		var qh: float = QUICK_TIMES[quick_time][1]
		if qh < 0.0:
			qh = [23.5, 2.0, 6.2, 10.0, 14.0, 17.0, 19.3][randi() % 7]
		pp["hour"] = qh
		pp["night"] = qh < 5.0 or qh >= 20.5      # (same as mission.phase() for a quick mission: by the hour)
		quick_night = pp["night"]
		pp["id"] = -1
		if quick_size != "":
			pp["size"] = quick_size
		# a base defence and Mars keep their own place
		if not String(pp.get("type", "")) in ["base", "mars"]:
			if quick_group != "":
				pp["group"] = quick_group
			if quick_map > 0:
				pp["biome"] = QUICK_MAPS[quick_map][1]
				pp["terrain"] = QUICK_MAPS[quick_map][2]
	return pp

func _show_quick() -> void:
	_panel("RYCHLÁ MISE")
	_label("Zkouška nanečisto: vezmi si, co chceš. Voják je jen na jedno použití - žold, zkušenosti, zranění ani smrt se do kampaně nepočítají.", FRAME, 8).custom_minimum_size = Vector2(300, 0)
	var names := []
	for q in QUICK:
		names.append(q[0])
	_cycle(_box, "Scénář", names, quick_pick, func(i): quick_pick = i)
	var gk := ["", "sedaci", "jestetani", "levite", "bijci", "myslodejove"]
	var gn := ["podle scénáře", "Šediváci", "Ještěřani", "Levité", "Bijci", "Myslodějové"]
	_cycle(_box, "Nepřítel", gn, gk.find(quick_group), func(i): quick_group = gk[i])
	var mn := []
	for m in QUICK_MAPS:
		mn.append(m[0])
	_cycle(_box, "Mapa", mn, quick_map, func(i): quick_map = i)
	var sizes := ["", "small", "medium", "large", "huge", "colossal"]
	var sn := ["podle mise"]
	for k in sizes.slice(1):
		sn.append(MapGen.SIZE_NAMES[k])
	_cycle(_box, "Velikost", sn, sizes.find(quick_size), func(i): quick_size = sizes[i])
	_cycle(_box, "Čas", QUICK_TIMES.map(func(e): return e[0]), quick_time, func(i): quick_time = i)
	var dk := ["easy", "normal", "veteran"]
	_cycle(_box, "Obtížnost", [Game.DIFF_NAMES["easy"], Game.DIFF_NAMES["normal"], "HARDCORE"], maxi(0, dk.find(Game.difficulty)), func(i): Game.difficulty = dk[i]; Game.save_settings())
	var mk := Game.SKIRMISH_KINDS.keys()
	_cycle(_box, "Voják", Game.SKIRMISH_KINDS.values(), maxi(0, mk.find(quick_merc)), func(i): quick_merc = mk[i])
	# 0.72 (návrh A): the choices in one row under the table
	var play := func():
		Campaign.active = false
		Game.begin_skirmish(quick_merc)
		Net.play_solo()
		Net.start_mission(quick_params(quick_pick))
	var brow := HFlowContainer.new()
	brow.add_theme_constant_override("h_separation", 4)
	brow.add_theme_constant_override("v_separation", 4)
	_box.add_child(brow)
	UiSkin.primary(_small_btn(brow, "HRÁT SÁM", play))
	_small_btn(brow, "HOSTOVAT (2-4)", func():
		Campaign.active = false
		Game.begin_skirmish(quick_merc)
		_host())
	_small_btn(brow, "PŘIPOJIT SE", _show_join)
	UiSkin.ghost(_small_btn(brow, "Výstroj", func(): _back_target = "quick"; _show_loadout()))
	UiSkin.ghost(_small_btn(brow, "Zpět", _show_main))
	_hotkeys = {KEY_ENTER: play, KEY_KP_ENTER: play}
	_panel_keys([["< >", "změnit volbu"], ["Enter", "hrát sám"], ["Esc", "zpět"]])

func _show_main(msg := "") -> void:
	Game.end_skirmish()
	Game.drop_parked()        # (0.72: the main menu itself - a globe left parked is no longer wanted)
	# 0.72 (návrh A): the picture in full, the rail on the left, bottom right a small card with
	# what's new (and any warning or update) - no window in the middle
	_panel("NOVINKY %s" % Game.VERSION_NUM)
	_rail_on = ""
	_rail_paint()
	_title_mode = true
	if _title:
		_title.modulate = Color(1, 1, 1)
	var card := _scroll.get_parent() as PanelContainer
	card.name = "NewsCard"
	card.add_theme_stylebox_override("panel", UiBox.make(Color(0.043, 0.055, 0.071, 0.82), Color(0, 0, 0, 0), 0, Vector4(9, 6, 9, 7)).with_bar(UiSkin.ACC, 0, 2.0))
	_panel_keys([])
	var nh := _box.get_child(0) as Label
	nh.text = "Novinky %s" % Game.VERSION_NUM
	UiSkin.eyebrow(nh, ACCENT, 8)
	# started straight from the zip (Windows unpacks it into a temporary folder):
	# settings, updates and the microphone may not work - say so
	var exe := OS.get_executable_path().to_lower()
	if not OS.has_feature("editor") and (exe.contains("\\temp\\") or exe.contains("/temp/") or exe.contains(".zip")):
		_card_text("Hra běží přímo ze zipu. Nejdřív zip rozbal (pravé tlačítko > Extrahovat vše) a spusť EnemyBeyond.exe z rozbalené složky, jinak nemusí fungovat mikrofon, nastavení ani aktualizace.", UiSkin.BAD)
	_upd_label = _card_text("", ACCENT)
	if Game.crash_note != "":
		# (0.57) the game went down mid-mission last time: say once what it cost
		_card_text(Game.crash_note, UiSkin.BAD)
		Game.crash_note = ""
	if msg != "":
		_card_text(msg, UiSkin.BAD)
	_upd_btn = _button("Restartovat a hrát novou verzi", func(): Game.restart_game())
	_upd_btn.add_theme_font_size_override("font_size", 9)
	UiSkin.primary(_upd_btn)
	_upd_refresh()
	var log: Dictionary = Game.changelog()
	var lines: Array = log.get(Game.VERSION_NUM, [])
	var gist := []
	for ln in lines.slice(0, 3):
		var t := String(ln).split(":")[0].split(" (")[0].strip_edges()
		gist.append(t if t.length() <= 46 else t.substr(0, 44) + "…")
	if not gist.is_empty():
		_card_text(", ".join(gist) + "…", TEXT)
	var more := _button("Celé novinky", _show_news)
	more.add_theme_font_size_override("font_size", 9)
	UiSkin.ghost(more)
	if INTRO_ON:
		var b := _button("Úvod", _play_intro)
		b.add_theme_font_size_override("font_size", 9)
		UiSkin.ghost(b)

## A line of the main screen's card: wraps at the card's width.
func _card_text(t: String, col: Color) -> Label:
	var l := _label(t, col, 8)
	l.custom_minimum_size = Vector2(210, 0)
	l.visible = t != ""
	return l

## 0.72 (návrh A): co-op in one place - join a friend, host a quick mission, the campaign together.
func _show_coop() -> void:
	_panel("CO-OP")
	_label("Hrajte ve 2 až 4. Kamarádi se připojí na IP hostitele (port %d, TCP/UDP). Po internetu přes Radmin VPN nebo ZeroTier." % Net.PORT, FRAME, 8).custom_minimum_size = Vector2(280, 0)
	_button("Připojit se ke hře kamaráda", func(): _back_target = ""; _show_join())
	_button("Hostovat rychlou misi", _show_quick)
	_label("Kampaň s kamarády: hostitel otevře svou kampaň a na glóbu dá Co-op. Kampaň i vojáky si pamatuje hostitel.", FRAME, 8).custom_minimum_size = Vector2(280, 0)
	_button("Moje kampaň", _show_campaign)
	_button("Zpět", _show_main)

## The campaign: carry on, found a new one (its difficulty is fixed until it ends), or join a friend's.
func _show_campaign(msg := "") -> void:
	_panel("KAMPAŇ")
	var save := _peek_campaign()
	if not save.is_empty():
		var diff := String(save.get("difficulty", Game.difficulty))
		_label("Uložená kampaň: den %d, obtížnost %s, rozpočet %d kr." % [int(float(save.get("day", 0.0))), Game.DIFF_NAMES.get(diff, diff), int(save.get("credits", 0))], FRAME, 9)
		_button("Pokračovat v kampani", func(): Campaign.load_campaign(); Game.load_scene("res://scenes/Geoscape.tscn"))
	_button("Založit novou kampaň", _show_new_campaign)
	_button("Připojit se ke hře (kampaň kamaráda)", _show_join)
	_button("Moji vojáci", func(): _back_target = "campaign"; _show_merc())
	var past := Campaign.past_campaigns()
	if not past.is_empty():
		_button("Skončené kampaně (%d)" % past.size(), _show_past)
	if not Game.merc.get("created", true):
		_label("Nemáš vlastního vojáka - vytvoř si ho v \"Moji vojáci\".", UiSkin.WARN, 9)
	_label("Vojáci rostou jen v kampani: mise, žold, zranění i smrt. Co-op kampaň si pamatuje hostitel - hraje se s jeho záznamem o každém vojákovi.", FRAME, 8).custom_minimum_size = Vector2(300, 0)
	_button("Zpět", _show_main)
	if msg != "":
		_label(msg, UiSkin.BAD, 10)

## (0.7x) The record of ended campaigns (lost or won): one line each, a click opens its end screen.
func _show_past() -> void:
	_panel("SKONČENÉ KAMPANĚ")
	if Campaign.past_campaigns().is_empty():
		_label("Zatím žádná kampaň neskončila.", FRAME, 9)
	for s in Campaign.past_campaigns().slice(0, 8):
		var d: Dictionary = s
		var diff := String(d.get("diff", ""))
		_button("%s  %s - %s, %d dní, %s" % ["VÍTĚZSTVÍ" if d.get("won", false) else "KONEC", d.get("start", ""), d.get("end", ""), int(d.get("days", 0)), Game.DIFF_NAMES.get(diff, diff)], func():
			var scr: Control = preload("res://scripts/campaign_end.gd").new()
			scr.setup(d, [["Zpět", func(): scr.queue_free()]])
			add_child(scr))
	_button("Zpět", _show_campaign)

func _peek_campaign() -> Dictionary:
	var cf := ConfigFile.new()
	if cf.load("user://campaign.cfg") != OK:
		return {}
	return cf.get_value("campaign", "data", {})

var _new_diff := "normal"
func _show_new_campaign() -> void:
	_panel("NOVÁ KAMPAŇ")
	_label("Obtížnost platí po celou kampaň a změnit ji nejde.", ACCENT, 9)
	var info := {
		"easy": "Snadná: slabší a pomalejší vetřelci, ceny a doby výzkumu i staveb základní, 1500 kr na začátek. Oko ukazuje, jestli tě vidí.",
		"normal": "Normální: ceny o třetinu vyšší, výzkum a stavby o čtvrtinu delší, 1200 kr na začátek.",
		"veteran": "HARDCORE: plazma zabíjí na 1-2 zásahy, panika, palba do vlastních, zranění se hojí dlouho. Ceny +60 %, výzkum a stavby o polovinu delší, 1000 kr na začátek.",
	}
	for d in ["easy", "normal", "veteran"]:
		var dd: String = d
		_button(("> " if _new_diff == dd else "") + Game.DIFF_NAMES[dd], func(): _new_diff = dd; _show_new_campaign())
	_label(info[_new_diff], UiSkin.BAD if _new_diff == "veteran" else TEXT, 8).custom_minimum_size = Vector2(300, 0)
	if Campaign.has_save():
		_label("Pozor: stará kampaň bude přepsána.", UiSkin.BAD, 9)
	_button("ZAČÍT KAMPAŇ", func():
		Campaign.new_campaign(_new_diff)
		Game.load_scene("res://scenes/Geoscape.tscn"))
	_button("Zpět", _show_campaign)

func _show_settings() -> void:
	_panel("NASTAVENÍ")
	_label("Ovládání, zvuk, grafika, hlas. Totéž najdeš ve hře v pauze (Esc).", FRAME, 8)
	preload("res://scripts/hud.gd").settings_ui(_box)
	_button("Zpět", _back)

## One place for the tools (only when running from the Godot editor, never in a released build).
func _show_editor() -> void:
	_panel("EDITOR")
	_label("Nástroje pro tvorbu hry. Ve vydané verzi nejsou.", FRAME, 8)
	_button("Dílna - zbraně v rukou a pózy", func(): get_tree().change_scene_to_file("res://scenes/Workshop.tscn"))
	_button("Modelář - kostky modelů", func(): get_tree().change_scene_to_file("res://scenes/Modeler.tscn"))
	# (0.57, Ari: the Animace editor is gone from the menu - the movements come from Mixamo)
	_button("Testovací místnost - pohyby, zbraně, vetřelci", _test_room)
	var md := _button("Mapové díly (připravuje se)", func(): pass)
	md.disabled = true
	_button("Zpět", _show_main)

## Testovací místnost (scripts/test_room.gd): a mirror of your soldier, every gun, the row of aliens.
func _test_room() -> void:
	Net.play_solo()
	Campaign.active = false
	Net.start_mission({"testroom": true, "type": "landed", "type_name": "Testovací místnost", "biome": "forest", "place": "Testovací místnost", "size": "small",
		"night": false, "hour": 14.0, "id": -1})

## 0.57 (Ari): the soldiers - the roster, the chosen one in 3D, his record; the same full-width
## skin as the recruiting screen.
func _show_merc() -> void:
	if not Game.merc.get("created", true) and Game.mercs.size() <= 1:
		_show_create(true)
		return
	var m: Dictionary = Game.merc
	# 0.72 (návrh A): the roster on the left, the soldier in the middle, his record on the right
	var body := _screen(["Základna" if Campaign.active else "Menu", "Vojáci"], "Moje peníze %s kr" % BaseScreen.money(int(m.get("money", 0))),
		[["↑↓", "vybrat vojáka"], ["Esc", "zpět"]])
	_esc = _back
	_arrows = func(d: int):
		var n := Game.mercs.size()
		if n > 1:
			Game.switch_merc(posmod(Game.active + d, n))
			_confirm_fire = false
			_show_merc()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	# ---- left: the roster
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(170, 0)
	left.add_theme_constant_override("separation", 0)
	row.add_child(left)
	var hd := HBoxContainer.new()
	left.add_child(hd)
	var h1 := Label.new(); h1.text = "Voják"; UiSkin.eyebrow(h1); h1.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hd.add_child(h1)
	var h2 := Label.new(); h2.text = "Misí"; UiSkin.eyebrow(h2); hd.add_child(h2)
	for i in Game.MERC_SLOTS:
		var k := i
		if i < Game.mercs.size():
			var mm: Dictionary = Game.mercs[i]
			var sick := Game.heal_days_left(mm) > 0.0
			var b := _roster_row(left, str(mm.get("name", "?")), Game.RANKS[Game.rank_of(mm)] + ("  · marodka" if sick else ""),
				str(int(mm.get("missions", 0))), i == Game.active, func():
				Game.switch_merc(k)
				_confirm_fire = false
				_show_merc())
			if sick:
				b.add_theme_color_override("font_color", UiSkin.BAD)
		else:
			var nb := _small_btn(left, "+  naverbovat vojáka", func():
				var n := Game.hire_merc()
				if n >= 0:
					Game.switch_merc(n)
				_show_create(true))
			UiSkin.ghost(nb)
			nb.alignment = HORIZONTAL_ALIGNMENT_LEFT
			nb.custom_minimum_size = Vector2(170, 16)
			break
	# ---- middle: the soldier, turning slowly
	var mid := VBoxContainer.new()
	mid.custom_minimum_size = Vector2(180, 0)
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(mid)
	_cr = {"look": (m.get("look", {}) as Dictionary).duplicate(true)}
	_build_preview(mid, false, Vector2(180, 290))
	# ---- right: the record
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 3)
	row.add_child(right)
	var name_edit := LineEdit.new()
	name_edit.text = m["name"]
	name_edit.add_theme_font_override("font", UiSkin.font(true))
	name_edit.add_theme_font_size_override("font_size", 16)
	name_edit.add_theme_stylebox_override("normal", UiBox.make(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, Vector4(0, 0, 0, 0)))
	name_edit.add_theme_stylebox_override("focus", UiBox.make(Color(0, 0, 0, 0), UiSkin.ACC, 8, Vector4(0, 0, 0, 0)))
	name_edit.tooltip_text = "Klikni a přepiš jméno."
	name_edit.text_changed.connect(func(t): Game.merc["name"] = t; Game.save_merc())
	right.add_child(name_edit)
	var xp := int(m.get("xp", 0))
	var rk := Game.rank_of(m)
	var nxt := "" if rk + 1 >= Game.RANK_XP.size() else " / %d" % Game.RANK_XP[rk + 1]
	var sub := Label.new()
	sub.text = "%s · zkušenosti %d%s · %d misí · %d zabití" % [Game.RANKS[rk], xp, nxt, int(m.get("missions", 0)), int(m.get("kills", 0))]
	UiSkin.eyebrow(sub)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD
	sub.custom_minimum_size = Vector2(200, 0)
	right.add_child(sub)
	if not m.get("created", true):
		var cb := _small_btn(right, "Tenhle voják ještě nemá vlastnosti ani vzhled - naverbovat", func(): _show_create(true))
		UiSkin.primary(cb)
	if Game.heal_days_left(m) > 0.0:
		_rl_w = 226.0
		_rlabel(right, "%s - chybí mu %d zdraví. Na misi nemůže, dokud se v kampani neuzdraví." % [Game.sick_text(m), ceili(float(m.get("injury", 0)))], UiSkin.BAD, 8)
	var sl := Label.new()
	sl.text = "Schopnosti"
	UiSkin.section(sl)
	right.add_child(sl)
	for st in Game.STAT_ORDER:
		_stat_row(right, Game.STAT_NAMES[st], int(m.get(st, 0)))
	var tl := []
	for t in m.get("talents", []):
		tl.append(Game.TALENTS[Game.TALENT_NEW.get(t, t)][0])
	_rl_w = 226.0
	_rlabel(right, "Talenty: " + (", ".join(tl) if not tl.is_empty() else "zatím žádné"), UiSkin.DIM, 8)
	var brow := HFlowContainer.new()
	brow.add_theme_constant_override("h_separation", 4)
	brow.add_theme_constant_override("v_separation", 4)
	right.add_child(brow)
	var pts := int(m.get("talent_points", 0))
	var tb := _small_btn(brow, "TALENTY" + (" (body: %d)" % pts if pts > 0 else ""), _show_talents)
	if pts > 0:
		UiSkin.primary(tb)
	_small_btn(brow, "ÚPRAVY ZBRANÍ", func(): _mods_from = "merc"; _show_mods())
	_small_btn(brow, "VZHLED", func(): _show_create(false))
	if Game.mercs.size() > 1:
		var fb := _small_btn(brow, "Propustit" if not _confirm_fire else "OPRAVDU propustit?", func():
			if not _confirm_fire:
				_confirm_fire = true
				_show_merc()
				return
			_confirm_fire = false
			Game.dismiss_merc(Game.active)
			_show_merc())
		UiSkin.ghost(fb)
		if _confirm_fire:
			fb.add_theme_color_override("font_color", UiSkin.BAD)
	else:
		UiSkin.ghost(_small_btn(brow, "Nahradit novým", func(): _show_create(true)))
	UiSkin.ghost(_small_btn(brow, "Zpět", _back))

## A roster line: name and rank, a number on the right; the chosen one with the gold bar.
func _roster_row(parent: Node, name: String, sub: String, num: String, on: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.text = "%s  %s" % [name, sub]
	b.add_theme_font_size_override("font_size", 8)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(170, 16)
	b.clip_text = true
	UiSkin.row(b, on)
	b.pressed.connect(cb)
	parent.add_child(b)
	var n := Label.new()
	n.text = num
	n.add_theme_font_size_override("font_size", 8)
	n.add_theme_color_override("font_color", UiSkin.DIM)
	n.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	n.offset_left = -18
	n.offset_right = -4
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(n)
	return b

## Přesnost  ━━━━━━━━━──────  44  (the bar out of 100).
func _stat_row(parent: Node, name: String, v: int, mx := 100) -> void:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 6)
	parent.add_child(r)
	var nm := Label.new()
	nm.text = name
	nm.custom_minimum_size = Vector2(52, 0)
	nm.add_theme_font_size_override("font_size", 8)
	nm.add_theme_color_override("font_color", TEXT)
	r.add_child(nm)
	var bar := ProgressBar.new()
	bar.max_value = mx
	bar.value = v
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 3)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("background", UiBox.make(Color(1, 1, 1, 0.08), Color(0, 0, 0, 0), 0, Vector4.ZERO))
	bar.add_theme_stylebox_override("fill", UiBox.make(UiSkin.TEXT, Color(0, 0, 0, 0), 0, Vector4.ZERO))
	r.add_child(bar)
	var val := Label.new()
	val.text = str(v)
	val.custom_minimum_size = Vector2(16, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.add_theme_font_size_override("font_size", 8)
	val.add_theme_color_override("font_color", UiSkin.DIM)
	r.add_child(val)

## 0.62 (Ari): the talent tree, next to the soldiers and their weapon parts. Four branches of five,
## all of it shown (what is owned, what can be taken now, what waits for a rank); a promotion gives
## one point, a talent is taken for good (two clicks). Easy difficulty: the drone instead of Šestý smysl.
var _talent_arm := ""
var _talent_info: Label
func _show_talents() -> void:
	var m: Dictionary = Game.merc
	var pts := int(m.get("talent_points", 0))
	# 0.72 (návrh A): four columns of cards, what the hovered talent does in the bottom bar
	var body := _screen([str(m.get("name", "?")), "Talenty"], "Volné body %d · %s" % [pts, Game.RANKS[Game.rank_of(m)]],
		[["LTM", "2× potvrdit"], ["Esc", "zpět"], ["", "vybraný talent nejde vrátit"]])
	_esc = func(): _talent_arm = ""; _show_merc()
	_talent_info = Label.new()
	_talent_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	_talent_info.custom_minimum_size = Vector2(330, 0)
	_talent_info.add_theme_font_size_override("font_size", 7)
	_talent_info.add_theme_color_override("font_color", TEXT)
	_talent_info.text = "Za každé povýšení dostaneš bod. Talent ve větvi jde vzít, když máš ten nad ním a dost vysokou hodnost."
	_scr_keys.add_child(_talent_info)
	_scr_keys.move_child(_talent_info, 0)
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 10)
	body.add_child(grid)
	for b in Game.TALENT_TREE.size():
		var bi: int = b
		var branch := VBoxContainer.new()
		branch.add_theme_constant_override("separation", 4)
		branch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(branch)
		var bn := Label.new()
		bn.text = String(Game.TALENT_TREE[b][0])
		UiSkin.eyebrow(bn, ACCENT)
		branch.add_child(bn)
		for t in 5:
			var ti: int = t
			var id := Game.tree_talent(b, t, m)
			var st := Game.talent_state(m, b, t)
			var sub: String = {"owned": "máš", "open": "vzít - klikni", "nopoint": "chybí bod za povýšení",
				"rank": "od: %s" % Game.RANKS[Game.TREE_RANK[t]], "locked": "po talentu nad ním · %s" % Game.RANKS[Game.TREE_RANK[t]]}[st]
			if st == "open" and _talent_arm == id:
				sub = "OPRAVDU? Klikni znovu"
			var line: Color = {"owned": ACCENT, "open": TEXT, "nopoint": UiSkin.EDGE, "rank": UiSkin.LINE, "locked": UiSkin.LINE}[st]
			var fill := Color(ACCENT, 0.10) if st == "owned" else Color(1, 1, 1, 0.025)
			var card := _card(branch, Game.TALENTS[id][0], sub, line, fill,
				TEXT if st in ["owned", "open", "nopoint"] else UiSkin.DIM, func():
				if Game.talent_state(Game.merc, bi, ti) != "open":
					_talent_hint(id)
					return
				if _talent_arm != id:
					_talent_arm = id
					_show_talents()
					_talent_hint(id)
					return
				_talent_arm = ""
				Game.pick_talent(id)
				_show_talents())
			card.mouse_entered.connect(func(): _talent_hint(id))
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 4)
	body.add_child(brow)
	_small_btn(brow, "ÚPRAVY ZBRANÍ", func(): _talent_arm = ""; _mods_from = "talents"; _show_mods())
	UiSkin.ghost(_small_btn(brow, "Zpět k vojákům", func(): _talent_arm = ""; _show_merc()))

## A two-line card (a talent, a research project): the name bright, a small line under it.
func _card(parent: Node, name: String, sub: String, line: Color, fill: Color, col: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 30)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var n := UiBox.make(fill, line, 15, Vector4(6, 3, 6, 3))
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", UiBox.make(Color(fill, fill.a + 0.04), UiSkin.ACC_HI, 15, Vector4(6, 3, 6, 3)))
	b.add_theme_stylebox_override("pressed", n)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(cb)
	parent.add_child(b)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 6
	v.offset_top = 3
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var a := Label.new()
	a.text = name
	a.add_theme_font_override("font", UiSkin.font(true))
	a.add_theme_font_size_override("font_size", 8)
	a.add_theme_color_override("font_color", col)
	a.clip_text = true
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(a)
	var c := Label.new()
	c.text = sub
	c.add_theme_font_size_override("font_size", 6)
	c.add_theme_color_override("font_color", UiSkin.DIM)
	c.clip_text = true
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(c)
	return b

func _talent_hint(id: String) -> void:
	if is_instance_valid(_talent_info):
		_talent_info.text = "%s - %s" % Game.TALENTS[id]

## 0.57: weapon upgrades - the guns on the left; on the right the chosen gun in 3D as the soldier
## has it, what its parts change, and its slots: each slot holds one part (optic, muzzle, under the
## barrel, rails, magazine...). A part is bought once and stays in the soldier's box; mounting and
## taking off is free. Almost every part is something for something (weight, aiming, reloading).
## Everything belongs to the soldier (saved with him; in a campaign the host keeps him).
var _mods_sel := ""
var _mods_info: Label
func _show_mods() -> void:
	if _mods_sel == "" or not Game.MOD_FITS.has(_mods_sel):
		_mods_sel = "rifle" if Game.MOD_FITS.has("rifle") else String(Game.MOD_FITS.keys()[0])
	var wsel := _mods_sel
	# 0.72 (návrh A): the guns on the left; the gun and its numbers on top, the slots as a table under it
	var body := _screen([str(Game.merc.get("name", "Voják")), "Úpravy zbraní"], "Peníze %s kr" % BaseScreen.money(Game.purse()),
		[["LTM", "nasadit / koupit"], ["", "najeď na díl: co umí a co stojí"], ["Esc", "zpět"]])
	_esc = _mods_back
	var guns: Array = Game.MOD_FITS.keys()
	_arrows = func(d: int):
		_mods_sel = String(guns[posmod(guns.find(_mods_sel) + d, guns.size())])
		_show_mods()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(110, 0)
	left.add_theme_constant_override("separation", 0)
	row.add_child(left)
	var lh := Label.new()
	lh.text = "Zbraň"
	UiSkin.eyebrow(lh)
	left.add_child(lh)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(sc)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	for w in guns:
		var wid: String = w
		var on := 0
		for sl in Game.fitted(wid):
			if not Game.MODS[Game.fitted(wid)[sl]].get("stock", false):
				on += 1
		var b := _roster_row(list, String(Game.ITEMS[wid]["short"]), "", ("+%d" % on) if on > 0 else "", wid == wsel, func(): _mods_sel = wid; _show_mods())
		b.custom_minimum_size = Vector2(104, 15)
		b.tooltip_text = String(Game.ITEMS[wid]["name"])
	# right: the chosen gun
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 4)
	row.add_child(right)
	var wn := Label.new()
	wn.text = String(Game.ITEMS[wsel]["name"])
	UiSkin.headline(wn, 13)
	right.add_child(wn)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	right.add_child(top)
	_gun_preview(top, wsel)
	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 0)
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(stats)
	for kv in _mods_stats_kv(wsel):
		_kv(stats, kv[0], kv[1])
	# the slots, one table row each: nothing / the parts (gold = mounted, white = in the box, dim = buy)
	var th := HBoxContainer.new()
	right.add_child(th)
	var t1 := Label.new(); t1.text = "Slot"; UiSkin.eyebrow(t1); t1.custom_minimum_size = Vector2(66, 0); th.add_child(t1)
	var t2 := Label.new(); t2.text = "Díly · zlatě = nasazeno, bíle = v bedně, šedě = koupit"; UiSkin.eyebrow(t2); th.add_child(t2)
	var sc2 := ScrollContainer.new()
	sc2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc2.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(sc2)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 0)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc2.add_child(rows)
	var slots := []
	for m in Game.MOD_FITS[wsel]:
		var sl := Game.mod_slot(m)
		if not sl in slots:
			slots.append(sl)
	var fit := Game.fitted(wsel)
	for sl in slots:
		var slot: String = sl
		var rp := PanelContainer.new()
		rp.add_theme_stylebox_override("panel", UiBox.make(Color(0, 0, 0, 0), UiSkin.LINE, 8, Vector4(0, 3, 0, 3)))
		rows.add_child(rp)
		var r2 := HFlowContainer.new()
		r2.add_theme_constant_override("h_separation", 3)
		r2.add_theme_constant_override("v_separation", 2)
		rp.add_child(r2)
		var opts := []
		for m in Game.MOD_FITS[wsel]:
			if Game.mod_slot(m) == slot:
				opts.append(m)
		var sn := Label.new()
		sn.text = String(Game.MOD_SLOTS.get(slot, "Doplněk"))
		sn.custom_minimum_size = Vector2(66, 0)
		sn.add_theme_font_size_override("font_size", 8)
		sn.add_theme_color_override("font_color", TEXT)
		r2.add_child(sn)
		var has_stock := false
		for m in opts:
			if Game.MODS[m].get("stock", false):
				has_stock = true
		if not has_stock:
			var nb := _chip(r2, "nic", "on" if not fit.has(slot) else "own", func():
				Game.unmount_slot(wsel, slot)
				_show_mods())
			nb.mouse_entered.connect(func(): _mods_hint("Nic v tomhle místě: zbraň je lehčí, nic tu nepřekáží."))
		for m in opts:
			var mid: String = m
			var on: bool = fit.get(slot, "") == mid
			var own := Game.owns_mod(wsel, mid)
			var price := Game.mod_price(mid)
			var txt := String(Game.MODS[mid]["name"])
			if not on and not own:
				txt += " · %d kr" % price
			var bb := _chip(r2, txt, "on" if on else ("own" if own else "buy"), func():
				if on:
					Game.unmount_slot(wsel, slot)
				elif own:
					Game.mount_mod(wsel, mid)
				elif not Game.buy_mod(wsel, mid):
					_show_main_msg("Nemáš dost peněz.")
					return
				_show_mods())
			if not on and not own:
				bb.disabled = Game.purse() < price
			var how := "Klikni a sundáš." if on and not Game.MODS[mid].get("stock", false) else ("Nasazeno." if on else ("Máš v bedně: klikni a namontuješ (zdarma)." if own else "Koupit za %d kr a hned namontovat." % price))
			bb.mouse_entered.connect(func(): _mods_hint("%s - %s %s  %s" % [Game.MODS[mid]["name"], Game.MODS[mid]["desc"], _part_effects(mid), how]))
	var info := Label.new()
	info.text = "Úpravy patří tvému vojákovi a fungují, kdykoli tu zbraň drží."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.custom_minimum_size = Vector2(300, 22)
	info.add_theme_font_size_override("font_size", 7)
	info.add_theme_color_override("font_color", UiSkin.DIM)
	right.add_child(info)
	_mods_info = info
	var back := _small_btn(right, "Zpět", _mods_back)
	UiSkin.ghost(back)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

## 0.66: one level up - to the screen the parts were opened from (the soldier, the kit, the talents).
func _mods_back() -> void:
	var fr := _mods_from
	_mods_from = ""
	if fr == "merc":
		_show_merc()
	elif fr == "talents":
		_show_talents()
	elif fr == "loadout":
		_show_loadout()
	elif _back_target != "":
		_back()
	else:
		_show_merc()

## A part on the weapon parts table: on = gold edge, own = white edge, buy = dim (dashed in the mockup).
func _chip(parent: Node, t: String, kind: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 7)
	var line: Color = {"on": UiSkin.ACC, "own": UiSkin.TEXT, "buy": Color(1, 1, 1, 0.2)}[kind]
	var col: Color = {"on": UiSkin.ACC, "own": UiSkin.TEXT, "buy": UiSkin.DIM}[kind]
	var n := UiBox.make(Color(UiSkin.ACC, 0.1) if kind == "on" else Color(0, 0, 0, 0), line, 15, Vector4(4, 1, 4, 1))
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("pressed", n)
	b.add_theme_stylebox_override("hover", UiBox.make(Color(1, 1, 1, 0.05), UiSkin.ACC_HI, 15, Vector4(4, 1, 4, 1)))
	b.add_theme_stylebox_override("disabled", UiBox.make(Color(0, 0, 0, 0), Color(1, 1, 1, 0.1), 15, Vector4(4, 1, 4, 1)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_hover_color", UiSkin.ACC_HI)
	b.add_theme_color_override("font_disabled_color", Color(UiSkin.DIM, 0.5))
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

## Váha ............ 7,3 kg  (a key/value line with a divider under it).
func _kv(parent: Node, k: String, v: String, col := TEXT) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiBox.make(Color(0, 0, 0, 0), UiSkin.LINE, 8, Vector4(0, 2, 0, 2)))
	parent.add_child(p)
	var h := HBoxContainer.new()
	p.add_child(h)
	var a := Label.new()
	a.text = k
	a.add_theme_font_size_override("font_size", 7)
	a.add_theme_color_override("font_color", UiSkin.DIM)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(a)
	var b := Label.new()
	b.text = v
	b.add_theme_font_size_override("font_size", 7)
	b.add_theme_color_override("font_color", col)
	h.add_child(b)

func _mods_hint(t: String) -> void:
	if _mods_info and is_instance_valid(_mods_info):
		_mods_info.text = t

## What a part costs besides money, in words ("+0,5 kg, do oka o 25 % pomaleji").
func _part_effects(mid: String) -> String:
	var d: Dictionary = Game.MODS[mid]
	var out := []
	var w := float(d.get("w", 0.0))
	if absf(w) > 0.001:
		out.append(("+" if w > 0.0 else "") + String.num(w, 2).replace(".", ",") + " kg")
	for k in [["ads", "do oka", true], ["reload", "přebíjení", false], ["draw", "tasení", false], ["sway", "klepání rukou", false], ["charge", "nabíjení článku", true]]:
		var v := float(d.get(k[0], 1.0))
		if absf(v - 1.0) < 0.001:
			continue
		var pct := roundi(absf(v - 1.0) * 100.0)
		var worse: bool = (v < 1.0) if k[2] else (v > 1.0)
		if not worse and k[0] == "charge":
			continue      # (the cell's faster charging is its gain, the description says it)
		out.append("%s o %d %% %s" % [k[1], pct, ("pomaleji" if k[0] != "sway" else "víc") if worse else ("rychleji" if k[0] != "sway" else "míň")])
	return ("Daň: " + ", ".join(out) + ".") if not out.is_empty() else ""

## The same as rows for the table (0.72).
func _mods_stats_kv(wid: String) -> Array:
	var w := float(Game.ITEMS[wid]["weight"]) + Game.part_weight(wid)
	var out := [["Váha", "%s kg" % ("%.1f" % w).replace(".", ",")]]
	for k in [["ads", "Do oka"], ["reload", "Přebíjení"], ["draw", "Tasení"], ["sway", "Klepání"]]:
		var v := Game.part_mult(wid, k[0])
		if k[0] == "ads":
			v = 1.0 / v
		out.append([k[1], "%d %%" % roundi(v * 100.0)])
	if Game.ITEMS[wid].get("laser", false):
		out.append(["Nabíjení", "%d %%" % roundi(100.0 / Game.part_mult(wid, "charge"))])
	var sg := Game.sight_of(wid)
	if not sg.is_empty():
		out.append(["Míření", ("objektiv %dx" % int(sg.get("zoom", 1.0))) if sg["kind"] == "scope" else ("vlastní mířidla" if sg["kind"] == "iron" else "červený bod")])
	return out

## The whole gun as the soldier carries it: weight and how the parts add up.
func _mods_stats(wid: String) -> String:
	var w := float(Game.ITEMS[wid]["weight"]) + Game.part_weight(wid)
	var t := "Váha se vším: %s kg\n" % ("%.1f" % w).replace(".", ",")
	var lines := []
	for k in [["ads", "Do oka"], ["reload", "Přebíjení"], ["draw", "Tasení"], ["sway", "Klepání"]]:
		var v := Game.part_mult(wid, k[0])
		if k[0] == "ads":
			v = 1.0 / v
		lines.append("%s: %d %%" % [k[1], roundi(v * 100.0)])
	if Game.ITEMS[wid].get("laser", false):
		lines.append("Nabíjení: %d %%" % roundi(100.0 / Game.part_mult(wid, "charge")))
	t += "\n".join(lines)
	var sg := Game.sight_of(wid)
	if not sg.is_empty():
		t += "\nMíření: %s" % ("skrz objektiv %dx" % int(sg.get("zoom", 1.0)) if sg["kind"] == "scope" else ("vlastní mířidla" if sg["kind"] == "iron" else "červený bod"))
	return t + "\n(100 % = holá zbraň, víc = pomaleji / víc)"

## The chosen gun in 3D with its parts, slowly turning (the merc preview's little world).
func _gun_preview(parent: Node, wid: String) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(560, 240)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.043, 0.055, 0.071)   # 0.72: the screen colour (UiSkin.BG)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.7)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var cam := Camera3D.new()
	cam.fov = 30
	vp.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.4
	sun.rotation = Vector3(-0.7, 0.5, 0)
	vp.add_child(sun)
	var holder := Node3D.new()
	vp.add_child(holder)
	var gm := Game.model(wid)
	Game.dress_gun(gm, wid)
	holder.add_child(gm)
	# centre it on its outline, the camera far enough for the whole gun
	var box := AABB()
	var first := true
	for mi in gm.find_children("*", "MeshInstance3D", true, false):
		var bb: AABB = (mi as MeshInstance3D).get_aabb()
		var xf := Transform3D()
		var n: Node = mi
		while n != gm and n is Node3D:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		bb = xf * bb
		box = bb if first else box.merge(bb)
		first = false
	gm.position = -box.get_center()
	var reach := maxf(box.size.z, maxf(box.size.x, box.size.y))
	cam.position = Vector3(0, reach * 0.14, reach * 1.35)
	cam.look_at(Vector3.ZERO)
	_cr_vp = vp
	_cr_model = holder
	_cr_face = false
	_cr_lock = false
	_cr_rot = PI * 0.5 + 0.35
	holder.rotation.y = _cr_rot
	var tr := TextureRect.new()
	tr.texture = vp.get_texture()
	tr.custom_minimum_size = Vector2(260, 104)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	parent.add_child(tr)

# ---- creating a mercenary: name, looks, stats by points or by dice ---------------------------
var _scroll: ScrollContainer
var _upd_label: Label
var _upd_btn: Button

## The update line in the main menu (checking / downloading 45 % / ready - restart).
func _upd_refresh() -> void:
	if _upd_label == null or not is_instance_valid(_upd_label):
		return
	var t := ""
	match Game.upd_state:
		"checking": t = "Hledám aktualizace..."
		"downloading":
			var mb := Game.update_mb()
			if mb.y > 0:
				t = "Stahuji verzi %s... %d %% (%.0f / %.0f MB)" % [Game.upd_version, int(Game.update_progress() * 100), mb.x, mb.y]
			else:
				t = "Stahuji verzi %s... %.0f MB" % [Game.upd_version, mb.x]
		"ready": t = "Verze %s je stažená - restartuj hru." % Game.upd_version
		"full": t = "Vyšla verze %s - stáhni nový zip z GitHubu (tahle verze se nedá doplnit)." % Game.upd_version
		"error": t = "Aktualizace: " + Game.upd_error
		"current": t = ""
	_upd_label.text = t
	_upd_label.visible = t != ""
	_upd_btn.visible = Game.upd_state == "ready"

## What's new: shown once after an update, and from the main menu.
func _show_news() -> void:
	Game.seen_version = Game.VERSION_NUM
	Game.save_settings()
	_panel("NOVINKY")
	var log: Dictionary = Game.changelog()
	var vers := log.keys()
	vers.sort_custom(func(a, b): return Boot.newer(a, b))
	for i in mini(vers.size(), 4):
		var v: String = vers[i]
		_label("Verze " + v + (" (právě hraješ)" if v == Game.VERSION_NUM else ""), ACCENT, 11)
		for line in log[v]:
			var l := _label("• " + String(line), TEXT, 9)
			l.custom_minimum_size = Vector2(380, 0)
	_button("Pokračovat", _show_main)
var _cr: Dictionary           # the merc being made
var _cr_full := true          # false = only the looks (an existing merc)
var _cr_mode := "points"      # points / dice
var _cr_auto_name := true
var _cr_vp: SubViewport
var _cr_model: Node3D
var _cr_rot := PI + 0.4
var _cr_face := false
var _cr_tab := 0          # 0.57: looks tab (face / clothes / trinkets)
var _cr_presets := false  # 0.60: the right column shows the saved soldier templates
var _cr_note := ""
var _cr_lock := false
var _cr_cam: Camera3D
var _cr_ui: PanelContainer

func _show_create(full: bool) -> void:
	_cr_full = full
	_cr_note = ""
	# 0.60: a new soldier (after a death, most often) starts on the saved templates, if there are any
	_cr_presets = full and not Game.presets("merc").is_empty()
	if full:
		_cr = Game.new_merc()
		_cr_auto_name = true
		# (0.72) the rolls are the profile's: a roll made before (left the screen, dismissed) stays
		var last := Game.dice_last()
		if not last.is_empty():
			_cr_mode = "dice"
			Game.set_levels(_cr, last)
		else:
			_cr_mode = "points"
			var lv := {}
			for st in Game.STAT_ORDER:
				lv[st] = 5
			Game.set_levels(_cr, lv)
	else:
		_cr = Game.merc.duplicate(true)
		if not _cr.has("look"):
			_cr["look"] = Game.random_look(false, RandomNumberGenerator.new())
	_build_create()

func _free_preview() -> void:
	if _cr_vp and is_instance_valid(_cr_vp):
		_cr_vp.queue_free()
	_cr_vp = null
	_cr_model = null
	_cr_clip = {}
	_cr_sk = null

func _build_create() -> void:
	# 0.72 (návrh A): the looks on the left, the soldier in the middle, name and points on the right
	var body := _screen(["Nový voják" if _cr_full else Game.merc.get("name", "Voják"), "Vzhled"], "Šablony %d" % Game.presets("merc").size(),
		[["myš", "otočit vojáka"], ["< >", "změnit"], ["Esc", "zpět"]])
	_esc = _create_back
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	# ---- left: the looks
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(176, 0)
	left.add_theme_constant_override("separation", 2)
	row.add_child(left)
	var look: Dictionary = _cr["look"]
	# 0.57 facelift: the looks in three tabs (face / clothes / trinkets) - the column would not fit otherwise
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 2)
	left.add_child(tabs)
	for t in [[0, "Tvář"], [1, "Oblečení"], [2, "Doplňky"]]:
		var tb := _small_btn(tabs, str(t[1]), func(): _cr_tab = t[0]; _build_create())
		UiSkin.row(tb, _cr_tab == t[0])
		tb.alignment = HORIZONTAL_ALIGNMENT_CENTER
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _cr_tab == 0:
		_cycle(left, "Pohlaví", ["Muž", "Žena"], 1 if look.get("female", false) else 0, func(i):
			look["female"] = i == 1
			if look["female"]:
				look["beard"] = 0
			if _cr_auto_name and _cr_full:
				var r := RandomNumberGenerator.new(); r.randomize()
				_cr["name"] = Game.random_name(look["female"], r)
			_build_create())
		_cycle(left, "Vlasy", Game.HAIR_STYLES.map(func(h): return h[1]), _index_of(Game.HAIR_STYLES, look.get("hair", "short")), func(i): look["hair"] = Game.HAIR_STYLES[i][0]; _refresh_preview())
		_cycle(left, "Barva vlasů", Game.HAIR_COLORS.map(func(h): return h[0]), int(look.get("hair_color", 1)), func(i): look["hair_color"] = i; _refresh_preview())
		if not look.get("female", false):
			_cycle(left, "Vousy", Game.BEARDS.map(func(h): return h[1]), int(look.get("beard", 0)), func(i): look["beard"] = i; _refresh_preview())
		_cycle(left, "Oči", Game.EYE_COLORS.map(func(h): return h[0]), int(look.get("eye_color", 0)), func(i): look["eye_color"] = i; _refresh_preview())
		_cycle(left, "Pleť", Game.SKIN_TONES.map(func(h): return h[0]), int(look.get("skin", 1)), func(i): look["skin"] = i; _refresh_preview())
		_cycle(left, "Maskování", _look_names(Game.PAINTS), Game.look_i(look, "paint", Game.PAINTS), _look_pick(look, "paint"))
	elif _cr_tab == 1:
		var tops: Array = _look_names(Game.TOPS)
		if look.get("female", false):
			tops[3] = "Tílko"
		_cycle(left, "Na sobě", tops, Game.look_i(look, "top", Game.TOPS), _look_pick(look, "top"))
		_cycle(left, "Vesta", _look_names(Game.VESTS), Game.look_i(look, "vest", Game.VESTS), _look_pick(look, "vest"))
		_cycle(left, "Kalhoty", _look_names(Game.PANTS), Game.look_i(look, "pants", Game.PANTS), _look_pick(look, "pants"))
		_cycle(left, "Na hlavě", _look_names(Game.HEADGEAR), int(look.get("headgear", 0)), func(i): look["headgear"] = i; _build_create())
		if Game.HEADGEAR[Game.look_i(look, "headgear", Game.HEADGEAR)][0] in ["beret", "bandana"]:
			_cycle(left, "Barva látky", Game.BERET_COLORS.map(func(h): return h[0]), Game.look_i(look, "beret_color", Game.BERET_COLORS), _look_pick(look, "beret_color"))
		_cycle(left, "Vlajka", Game.FLAGS.map(func(f): return f[1]), Game.flag_index(str(look.get("flag", ""))), func(i): look["flag"] = Game.FLAGS[i][0]; _refresh_preview())
		var note := Label.new()
		note.text = "Vesta jen na pohled - pancíř z výstroje ji překryje.\nKamufláž se na misi řídí terénem."
		note.add_theme_font_size_override("font_size", 7)
		note.add_theme_color_override("font_color", FRAME)
		left.add_child(note)
	else:
		_cycle(left, "Tetování", _look_names(Game.TATTOOS), Game.look_i(look, "tattoo", Game.TATTOOS), _look_pick(look, "tattoo"))
		_cycle(left, "Brýle", _look_names(Game.GLASSES), Game.look_i(look, "glasses", Game.GLASSES), _look_pick(look, "glasses"))
		_cycle(left, "Krk a tvář", _look_names(Game.NECKS), Game.look_i(look, "neck", Game.NECKS), _look_pick(look, "neck"))
		_cycle(left, "V puse", _look_names(Game.MOUTHS), Game.look_i(look, "mouth", Game.MOUTHS), _look_pick(look, "mouth"))
		var note := Label.new()
		note.text = "Tetování je vidět jen na holých pažích\n(ohrnuté rukávy, tričko, bez trička)."
		note.add_theme_font_size_override("font_size", 7)
		note.add_theme_color_override("font_color", FRAME)
		left.add_child(note)
	# ---- middle: the soldier, turning slowly (drag with the mouse)
	var mid := VBoxContainer.new()
	mid.custom_minimum_size = Vector2(170, 0)
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(mid)
	_build_preview(mid, true, Vector2(170, 250))
	# ---- right: name, stats, the finish
	_rl_w = 236.0
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 2)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var jl := Label.new()
	jl.text = "Jméno"
	UiSkin.eyebrow(jl)
	right.add_child(jl)
	var ne := LineEdit.new()
	ne.text = _cr["name"]
	ne.add_theme_font_override("font", UiSkin.font(true))
	ne.add_theme_font_size_override("font_size", 12)
	ne.add_theme_stylebox_override("normal", UiBox.make(Color(0, 0, 0, 0), UiSkin.EDGE, 8, Vector4(0, 1, 0, 2)))
	ne.add_theme_stylebox_override("focus", UiBox.make(Color(0, 0, 0, 0), UiSkin.ACC, 8, Vector4(0, 1, 0, 2)))
	ne.text_changed.connect(func(t): _cr["name"] = t; _cr_auto_name = false)
	right.add_child(ne)
	if _cr_presets:
		_build_merc_presets(right)
	else:
		_build_stats(right)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(sp)
	var brow := HFlowContainer.new()
	brow.add_theme_constant_override("h_separation", 4)
	brow.add_theme_constant_override("v_separation", 4)
	right.add_child(brow)
	var ok := _small_btn(brow, "NAVERBOVAT" if _cr_full else "ULOŽIT VZHLED", func():
		_cr["created"] = true
		if _cr_full:
			_cr["made"] = _cr_mode      # 0.60: a template keeps the levels only of a points-made soldier
			Game.dice_used(_cr_mode == "dice")
			_cr["money"] = int(Game.merc.get("money", 0))
			Game.merc = _cr
		else:
			Game.merc["look"] = _cr["look"]
			Game.merc["name"] = _cr["name"]
		Game.save_merc()
		Net.reregister()
		_show_merc())
	UiSkin.primary(ok)
	if _cr_full:
		var used3 := 0
		for st in Game.STAT_ORDER:
			used3 += int(_cr["levels"][st])
		ok.disabled = _cr_mode == "points" and used3 < Game.LEVEL_POOL
		if ok.disabled:
			ok.tooltip_text = "Nejdřív rozděl všechny body."
	_small_btn(brow, "Náhodné jméno", func():
		var r := RandomNumberGenerator.new(); r.randomize()
		_cr["name"] = Game.random_name(_cr["look"].get("female", false), r)
		_cr_auto_name = true
		_build_create())
	var pb := _small_btn(brow, "Šablony (%d)" % Game.presets("merc").size(), func(): _cr_presets = not _cr_presets; _cr_note = ""; _build_create())
	UiSkin.ghost(pb)
	if _cr_presets:
		pb.add_theme_color_override("font_color", ACCENT)
	UiSkin.ghost(_small_btn(brow, "Zpět", _create_back))

## Back from the creation screen: to the roster, or - for the only, not yet made soldier (the roster
## would open this screen again) - where the player came from: the globe, the co-op lobby, the menu.
func _create_back() -> void:
	if Game.merc.get("created", true) or Game.mercs.size() > 1:
		_show_merc()
	elif _back_target != "" or Net.is_online():
		_back()
	else:
		_show_main()

## 0.60: the saved soldier templates - put one on (looks, name, the points) or save this one.
func _build_merc_presets(right: VBoxContainer) -> void:
	var ht := Label.new()
	ht.text = "Šablony vojáků"
	UiSkin.section(ht)
	right.add_child(ht)
	_rlabel(right, "Uložený vzhled a jméno; u vojáka z rozdělených bodů i jeho body. Hod kostkami se neukládá - kostky se házejí vždy znovu.", FRAME, 7)
	var list := Game.presets("merc")
	if list.is_empty():
		_rlabel(right, "Zatím žádná šablona.", TEXT, 8)
	for i in list.size():
		var k := i
		var pr: Dictionary = list[i]
		var prow := HBoxContainer.new()
		prow.add_theme_constant_override("separation", 3)
		right.add_child(prow)
		var what := "body" if pr.has("levels") else "jen vzhled"
		var lb := _small_btn(prow, "%s  -  %s (%s)" % [String(pr.get("label", "?")), String(pr.get("name", "")), what], func(): _apply_merc_preset(pr))
		lb.custom_minimum_size = Vector2(0, 16)
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lb.clip_text = true
		lb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var db := _small_btn(prow, "×", func(): Game.delete_preset("merc", k); _cr_note = ""; _build_create())
		db.custom_minimum_size = Vector2(22, 16)
		db.tooltip_text = "Smazat šablonu"
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 3)
	right.add_child(srow)
	var le := LineEdit.new()
	le.text = Game.preset_label("merc", String(_cr.get("name", "Voják")))
	le.custom_minimum_size = Vector2(100, 0)
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.add_theme_font_size_override("font_size", 9)
	srow.add_child(le)
	var points := _cr_mode == "points" if _cr_full else String(_cr.get("made", "")) == "points"
	var sb := _small_btn(srow, "Uložit", func():
		var lbl := le.text.strip_edges()
		if lbl == "":
			lbl = Game.preset_label("merc", String(_cr.get("name", "Voják")))
		if Game.save_preset("merc", lbl, Game.merc_preset(_cr, points)):
			_cr_note = "Uloženo: " + lbl + ("" if points else " (bez bodů)")
		else:
			_cr_note = "Plno (%d šablon) - nejdřív nějakou smaž." % Game.PRESET_MAX
		_build_create())
	sb.custom_minimum_size = Vector2(0, 16)
	if _cr_note != "":
		_rlabel(right, _cr_note, UiSkin.OK, 8)

func _apply_merc_preset(pr: Dictionary) -> void:
	var lk: Dictionary = pr.get("look", {})
	if not lk.is_empty():
		_cr["look"] = lk.duplicate(true)
	if _cr_full:
		var nm := String(pr.get("name", "")).strip_edges()
		if nm != "":
			# two soldiers of the same name in the roster would mix up (the missing one is found by name)
			var taken := false
			for i in Game.mercs.size():
				if i != Game.active and String(Game.mercs[i].get("name", "")) == nm:
					taken = true
			_cr["name"] = nm + " ml." if taken else nm
			_cr_auto_name = false
		var lv: Dictionary = pr.get("levels", {})
		var sum := 0
		var good := not lv.is_empty()
		for st in Game.STAT_ORDER:
			var l := int(lv.get(st, -1))
			good = good and l >= 0 and l <= Game.LEVEL_MAX
			sum += l
		if good and sum <= Game.LEVEL_POOL:
			_cr_mode = "points"
			Game.set_levels(_cr, lv)
	_cr_note = ""
	_cr_presets = false
	_build_create()

## The points / dice and the six stats (right column of the creation screen).
func _build_stats(right: VBoxContainer) -> void:
	if _cr_full:
		var mrow := HFlowContainer.new()
		mrow.add_theme_constant_override("h_separation", 2)
		mrow.add_theme_constant_override("v_separation", 2)
		right.add_child(mrow)
		var bp := _small_btn(mrow, "Rozdělit body", func():
			_cr_mode = "points"
			var lv := {}
			for st in Game.STAT_ORDER:
				lv[st] = 5
			Game.set_levels(_cr, lv)
			_build_create())
		UiSkin.row(bp, _cr_mode == "points")
		var bd := _small_btn(mrow, "Kostky (zbývá %d)" % Game.dice_left(), func():
			if Game.dice_left() <= 0:
				return
			_cr_mode = "dice"
			Game.set_levels(_cr, Game.dice_roll())
			_build_create())
		UiSkin.row(bd, _cr_mode == "dice")
		bd.disabled = Game.dice_left() <= 0
		if bd.disabled:
			bd.tooltip_text = "Hody došly. Nové hody dostaneš za vojáka ztraceného na misi nebo za nové místo v soupisce."
		# (0.72) the last roll can be taken back after a look at the points (no new roll for it)
		var last := Game.dice_last()
		if _cr_mode == "points" and not last.is_empty():
			var bl := _small_btn(mrow, "Vzít poslední hod", func():
				_cr_mode = "dice"
				Game.set_levels(_cr, Game.dice_last())
				_build_create())
			UiSkin.ghost(bl)
		var used := 0
		for st in Game.STAT_ORDER:
			used += int(_cr["levels"][st])
		var info := "Body: rozdej %d bodů mezi vlastnosti (0-10 každá). Zbývá: %d" % [Game.LEVEL_POOL, Game.LEVEL_POOL - used] if _cr_mode == "points" \
			else "Kostky: každá vlastnost 2k6-2 (0-10, nejčastěji 5). Součet: %d (průměr 30). Hod nejde upravit. Hody (%d) patří profilu - odchod ani propuštění vojáka je nevrátí; nové jen za vojáka ztraceného na misi." % [used, Game.DICE_ROLLS]
		var eb := Label.new()
		eb.text = ("Body · zbývá %d" % maxi(0, Game.LEVEL_POOL - used)) if _cr_mode == "points" else ("Kostky · součet %d" % used)
		UiSkin.eyebrow(eb, ACCENT if _cr_mode == "points" and used < Game.LEVEL_POOL else UiSkin.DIM)
		right.add_child(eb)
		_rlabel(right, info.substr(info.find(" ") + 1) if _cr_mode == "dice" else "Rozdej %d bodů mezi vlastnosti (0-10 každá)." % Game.LEVEL_POOL, UiSkin.DIM, 7)
	var help := Label.new()
	for st in Game.STAT_ORDER:
		var key: String = st
		var srow := HBoxContainer.new()
		srow.add_theme_constant_override("separation", 3)
		srow.mouse_filter = Control.MOUSE_FILTER_PASS
		right.add_child(srow)
		srow.mouse_entered.connect(func(): help.text = "%s: %s" % [Game.STAT_NAMES[key], Game.STAT_HELP[key]])
		var nm := Label.new()
		nm.text = Game.STAT_NAMES[key]
		nm.custom_minimum_size = Vector2(48, 0)
		nm.add_theme_font_size_override("font_size", 8)
		nm.add_theme_color_override("font_color", TEXT)
		nm.mouse_filter = Control.MOUSE_FILTER_PASS
		srow.add_child(nm)
		var lvl := int(_cr.get("levels", {}).get(key, 5))
		var pts := _cr_full and _cr_mode == "points"
		if pts:
			var minus := _small_btn(srow, "-", func(): _bump(key, -1))
			minus.custom_minimum_size = Vector2(14, 0)
			UiSkin.ghost(minus)
			minus.disabled = lvl <= 0
		var bar := ProgressBar.new()
		bar.max_value = Game.LEVEL_MAX
		bar.value = lvl
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 3)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.add_theme_stylebox_override("background", UiBox.make(Color(1, 1, 1, 0.08), Color(0, 0, 0, 0), 0, Vector4.ZERO))
		bar.add_theme_stylebox_override("fill", UiBox.make(UiSkin.TEXT, Color(0, 0, 0, 0), 0, Vector4.ZERO))
		bar.mouse_filter = Control.MOUSE_FILTER_PASS
		srow.add_child(bar)
		if pts:
			var used2 := 0
			for s2 in Game.STAT_ORDER:
				used2 += int(_cr["levels"][s2])
			var plus := _small_btn(srow, "+", func(): _bump(key, 1))
			plus.custom_minimum_size = Vector2(14, 0)
			UiSkin.ghost(plus)
			plus.disabled = lvl >= Game.LEVEL_MAX or used2 >= Game.LEVEL_POOL
		var val := Label.new()
		val.text = str(int(_cr[key]))
		val.custom_minimum_size = Vector2(16, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.add_theme_font_size_override("font_size", 8)
		val.add_theme_color_override("font_color", UiSkin.DIM)
		srow.add_child(val)
	# what the stat under the mouse does (one line for all of them - 0.72)
	help.text = "Najeď na vlastnost: co dělá."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD
	help.custom_minimum_size = Vector2(_rl_w, 30)
	help.add_theme_font_size_override("font_size", 7)
	help.add_theme_color_override("font_color", UiSkin.DIM)
	right.add_child(help)

func _bump(st: String, d: int) -> void:
	var lv: Dictionary = _cr["levels"].duplicate()
	var used := 0
	for s2 in Game.STAT_ORDER:
		used += int(lv[s2])
	var nv := clampi(int(lv[st]) + d, 0, Game.LEVEL_MAX)
	if d > 0 and used >= Game.LEVEL_POOL:
		return
	lv[st] = nv
	Game.set_levels(_cr, lv)
	_build_create()

## 0.57: the option names of a look list ([key, name] pairs) and a cycle callback that stores the index.
func _look_names(list: Array) -> Array:
	return list.map(func(h): return h[1])

func _look_pick(look: Dictionary, key: String) -> Callable:
	return func(i): look[key] = i; _refresh_preview()

func _index_of(arr: Array, key: String) -> int:
	for i in arr.size():
		if arr[i][0] == key:
			return i
	return 0

func _rlabel(parent: Node, text: String, color: Color, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(_rl_w, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l

var _rl_w := 370.0           # 0.72: how wide _rlabel wraps (a narrower column on the full screens)
func _small_btn(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 8)
	UiSkin.button(b)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

## "Label  < value >" - cycles through the options.
func _cycle(parent: Node, label: String, opts: Array, cur: int, cb: Callable) -> void:
	# 0.72 (návrh A): a table line - the name on the left, ‹ value › on the right, a divider under it
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiBox.make(Color(0, 0, 0, 0), UiSkin.LINE, 8, Vector4(0, 1, 0, 1)))
	parent.add_child(pc)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	row.custom_minimum_size = Vector2(0, 14)
	pc.add_child(row)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(56, 0)
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", TEXT)
	row.add_child(l)
	var val := Label.new()
	var state := {"i": clampi(cur, 0, opts.size() - 1)}
	val.text = str(opts[state["i"]])
	val.custom_minimum_size = Vector2(76, 0)
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.clip_text = true
	val.add_theme_font_size_override("font_size", 8)
	val.add_theme_color_override("font_color", TEXT)
	val.tooltip_text = val.text
	val.mouse_filter = Control.MOUSE_FILTER_PASS
	var prev := _small_btn(row, "‹", func():
		state["i"] = (state["i"] - 1 + opts.size()) % opts.size()
		val.text = str(opts[state["i"]])
		val.tooltip_text = val.text
		cb.call(state["i"]))
	prev.custom_minimum_size = Vector2(12, 0)
	UiSkin.ghost(prev)
	row.add_child(val)
	var nxt := _small_btn(row, "›", func():
		state["i"] = (state["i"] + 1) % opts.size()
		val.text = str(opts[state["i"]])
		val.tooltip_text = val.text
		cb.call(state["i"]))
	nxt.custom_minimum_size = Vector2(12, 0)
	UiSkin.ghost(nxt)

## The merc in 3D, slowly turning (own little world in a SubViewport).
func _build_preview(parent: Node, editing := true, show := Vector2(210, 158)) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(420, 360)
	vp.own_world_3d = true
	vp.transparent_bg = true      # 0.72: the soldier stands on the screen itself
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.043, 0.055, 0.071)   # 0.72: the screen colour (UiSkin.BG)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.55, 0.65)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var cam := Camera3D.new()
	cam.fov = 32
	vp.add_child(cam)
	_cr_cam = cam
	_place_cam()
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.3
	sun.rotation = Vector3(-0.6, 0.6, 0)
	vp.add_child(sun)
	_cr_model = Game.model("merc")
	_cr_model.scale = Vector3(-1, 1, 1)     # same as in the game (gun hand = right)
	vp.add_child(_cr_model)
	for mi in _cr_model.find_children("Gear_*", "MeshInstance3D", true, false):
		if not String(mi.name) in ["Gear_Helmet", "Gear_Cap", "Gear_Torch"]:
			mi.visible = String(mi.name) in ["Gear_Belt0", "Gear_Belt1", "Gear_Holster"]
	var an: AnimationPlayer = _cr_model.find_child("AnimationPlayer", true, false)
	# (Ari 0.71) a calm stance from the afk pack (the base people's idle, arms down, else pohov);
	# the model's own "idle" holds an invisible rifle - arms forward looked odd in the creator
	_cr_clip = {}
	for id in CR_POSES:
		_cr_clip = AnimClips.get_clip(id)
		if not _cr_clip.is_empty():
			break
	_cr_sk = _cr_model.find_child("Skeleton3D", true, false)
	_cr_clip_t = 0.0
	if an and (_cr_clip.is_empty() or _cr_sk == null):
		an.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
		an.play("idle")
	elif an:
		an.stop()
	_cr_model.rotation.y = _cr_rot
	_cr_vp = vp
	_cr_pose_tick(0.0)
	_refresh_preview()
	var tr := TextureRect.new()
	tr.texture = vp.get_texture()
	tr.custom_minimum_size = show
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_STOP
	tr.gui_input.connect(func(e: InputEvent):       # 0.72: drag the soldier round with the mouse
		if e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT):
			_cr_rot += e.relative.x * 0.03)
	parent.add_child(tr)
	if not editing:
		return            # 0.72: the roster shows the soldier alone (it turns by itself)
	var rrow := HFlowContainer.new()
	rrow.add_theme_constant_override("h_separation", 2)
	rrow.add_theme_constant_override("v_separation", 2)
	parent.add_child(rrow)
	_small_btn(rrow, "↺", func(): _cr_rot -= 0.6).custom_minimum_size = Vector2(22, 0)
	_small_btn(rrow, "↻", func(): _cr_rot += 0.6).custom_minimum_size = Vector2(22, 0)
	_small_btn(rrow, "Tvář/celý", func(): _cr_face = not _cr_face; _place_cam()).custom_minimum_size = Vector2(50, 0)
	var lk := _small_btn(rrow, "Zamknout" if not _cr_lock else "Odemknout", func(): pass)
	lk.custom_minimum_size = Vector2(52, 0)
	lk.pressed.connect(func():
		_cr_lock = not _cr_lock
		if _cr_lock:
			_cr_rot = PI       # face to the camera, and stay
		lk.text = "Odemknout" if _cr_lock else "Zamknout")
	lk.tooltip_text = "Zastaví otáčení náhledu, ať si v klidu uděláš obličej."
	_small_btn(rrow, "Náhodně", func():
		var r := RandomNumberGenerator.new(); r.randomize()
		var f: bool = _cr["look"].get("female", false)
		_cr["look"] = Game.random_look(f, r)
		_build_create()).custom_minimum_size = Vector2(44, 0)

func _place_cam() -> void:
	if _cr_cam == null or not is_instance_valid(_cr_cam):
		return
	if _cr_face:
		_cr_cam.position = Vector3(0, 1.68, 0.95)
		_cr_cam.look_at(Vector3(0, 1.64, 0))
	else:
		_cr_cam.position = Vector3(0, 1.2, 3.4)
		_cr_cam.look_at(Vector3(0, 1.0, 0))

## The creator's stance: an afk clip played in place on the preview soldier (like the transport does).
const CR_POSES := ["tp_npc_idle", "tp_atease_vse"]
var _cr_clip := {}
var _cr_sk: Skeleton3D
var _cr_clip_t := 0.0
func _cr_pose_tick(delta: float) -> void:
	if _cr_clip.is_empty() or _cr_sk == null or not is_instance_valid(_cr_sk):
		return
	_cr_clip_t += delta
	var len_ := float(_cr_clip.get("delka", 1.0))
	var t := AnimClips.clip_time(_cr_clip, _cr_clip_t)
	if _cr_clip.get("smycka", false) and len_ > 0.2:
		t = 0.04 + fmod(_cr_clip_t, len_ - 0.08)      # (without the first and last key: no hop each loop)
	var p := AnimClips.pose(_cr_clip, t)
	for bn in p:
		var i := _cr_sk.find_bone(bn)
		if i >= 0:
			_cr_sk.set_bone_pose_rotation(i, _cr_sk.get_bone_rest(i).basis.get_rotation_quaternion() * Quaternion.from_euler(p[bn]))
	if AnimClips.has_track(_cr_clip, "root@pos"):
		var ri := _cr_sk.find_bone("root")
		if ri >= 0:
			var v := AnimClips.sample(_cr_clip, "root@pos", t)
			# (in place and in the middle of the picture: only the height follows the clip)
			_cr_sk.set_bone_pose_position(ri, _cr_sk.get_bone_rest(ri).origin + Vector3(0, float(v[1]), 0))

func _refresh_preview() -> void:
	if _cr_model and is_instance_valid(_cr_model):
		Game.apply_look(_cr_model, _cr["look"])

var _lobby_t := 0.0
var _menu_prev_want := Vector2.ZERO     # the size before the last change (no flip-flopping between two)
func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and _hotkeys.has(e.keycode):
		get_viewport().set_input_as_handled()
		var hk: Callable = _hotkeys[e.keycode]
		hk.call()
		return
	if _arrows.is_valid() and (e.is_action_pressed("ui_up") or e.is_action_pressed("ui_down")):
		get_viewport().set_input_as_handled()
		var ac := _arrows
		ac.call(-1 if e.is_action_pressed("ui_up") else 1)
		return
	if e.is_action_pressed("ui_cancel") and _esc.is_valid() and not _title_mode:
		get_viewport().set_input_as_handled()
		var cb := _esc
		cb.call()

func _process(delta: float) -> void:
	_lobby_t += delta
	if _lobby_t > 0.15 and Net.is_online() and _status and is_instance_valid(_status) and _status.text.begins_with("Hráči"):
		_lobby_t = 0.0
		_refresh_lobby()
	# keep the menu panel on screen: as tall as its content, at most what fits
	if _scroll and is_instance_valid(_scroll) and _box and is_instance_valid(_box):
		var p := _scroll.get_parent() as Control
		var room: float = 344.0 - (p.position.y - 8.0) - 22.0 - (get_node("PanelKeys").size.y - 6.0 if get_node_or_null("PanelKeys") else 0.0)
		if _title_mode:
			room = 150.0
		var need := _box.get_combined_minimum_size()
		# taller than the screen: the scrollbar takes room on the right - count it in, so the text
		# does not re-wrap when it appears (that flipped the size back and forth every frame)
		var want := Vector2(need.x + (10.0 if need.y > room else 0.0), minf(need.y, room))
		if _scroll.custom_minimum_size != want and want != _menu_prev_want:
			_menu_prev_want = _scroll.custom_minimum_size
			_scroll.custom_minimum_size = want
			p.size = Vector2.ZERO
		if _title_mode:
			p.position = Vector2(roundf(632.0 - p.size.x), roundf(352.0 - p.size.y))
		elif not _rail_off and p.size.x <= 640.0 - 172.0 - 8.0:
			p.position.x = 172.0          # 0.72: windows open to the right of the rail
		else:
			p.position.x = roundf((640.0 - p.size.x) / 2.0)
	_rail_tick()
	if _cr_model and is_instance_valid(_cr_model) and _cr_vp and is_instance_valid(_cr_vp):
		_cr_model.rotation.y = lerp_angle(_cr_model.rotation.y, _cr_rot, delta * 5.0)
		_cr_pose_tick(delta)
		if not _cr_lock:
			_cr_rot += delta * (0.12 if _cr_face else 0.25)

# ---- loadout: UFO-style equip screen --------------------------------------------------------
var _gear_note := ""
var _lo_cat := "all"
func _show_loadout() -> void:
	var vet := Game.difficulty == "veteran"
	var cur: Dictionary = Game.valid_loadout(vet)
	Game.loadout = cur
	Net.report_claim()      # (0.7x) the others see at once what this kit takes from the armory
	var left: Dictionary = Game.stash_for(vet).duplicate()
	_stock_sig = str(left)
	for slot in cur:
		left[cur[slot]] = int(left[cur[slot]]) - 1
	for k in left.keys():
		if int(left[k]) <= 0:
			left.erase(k)
	var weight := 0
	for slot in cur:
		weight += int(Game.ITEMS[cur[slot]]["weight"])
	var cap := int(Game.merc.get("strength", 30))
	# 0.72 (návrh A): the soldier's kit on the left (sets, armour, guns, belt and pack), the store as a
	# table on the right (tabs by kind), the weight on top
	var scr := _screen(["Před misí", "Výstroj"], "Váha %d / %d kg · síla %d%s" % [weight, cap, cap, "  · PŘETÍŽEN" if weight > cap else ""],
		[["LTM", "vzít / vrátit"], ["R", "výchozí výstroj"], ["Esc", "hotovo"]])
	_panel_title = "VÝSTROJ NA MISI"
	_hotkeys = {KEY_R: func(): Game.loadout = {}; Game.save_settings(); _show_loadout()}
	if weight > cap:
		_scr_status.add_theme_color_override("font_color", UiSkin.BAD)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scr.add_child(row)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 3)
	body.custom_minimum_size = Vector2(286, 0)
	row.add_child(body)
	# sets: soldier types and the player's own saved sets (0.60, kept on this computer)
	var mine := HFlowContainer.new()
	mine.add_theme_constant_override("h_separation", 3)
	mine.add_theme_constant_override("v_separation", 2)
	body.add_child(mine)
	var ml := Label.new()
	ml.text = "Moje sady"
	UiSkin.eyebrow(ml)
	mine.add_child(ml)
	var sets := Game.presets("gear")
	for i in sets.size():
		var k := i
		var pr: Dictionary = sets[i]
		var sb := _chip(mine, String(pr.get("label", "?")), "own", func():
			var want: Dictionary = pr.get("loadout", {})
			Game.loadout = want.duplicate()
			Game.save_settings()
			var got := Game.valid_loadout(vet)
			var miss: Array = []
			for slot in want:
				if String(want[slot]) != "" and Game.ITEMS.has(want[slot]) and not got.values().has(want[slot]):
					var nm: String = Game.ITEMS[want[slot]]["short"]
					if not nm in miss:
						miss.append(nm)
			_gear_note = "Sada %s nasazena." % String(pr.get("label", "")) + ("" if miss.is_empty() else " Ve skladu chybí: " + ", ".join(miss))
			_show_loadout())
		sb.tooltip_text = "Nasadit uloženou sadu (co ve skladu chybí, zůstane prázdné)"
		var db := _chip(mine, "×", "buy", func(): Game.delete_preset("gear", k); _gear_note = ""; _show_loadout())
		db.tooltip_text = "Smazat sadu"
	var gle := LineEdit.new()
	var base: String = Game.ITEMS[cur["rh"]]["short"] if cur.has("rh") and Game.ITEMS.has(cur["rh"]) else "Sada"
	gle.text = Game.preset_label("gear", base)
	gle.custom_minimum_size = Vector2(64, 0)
	gle.add_theme_font_size_override("font_size", 7)
	mine.add_child(gle)
	_chip(mine, "+ uložit", "buy", func():
		var lbl := gle.text.strip_edges()
		if lbl == "":
			lbl = Game.preset_label("gear", base)
		if Game.save_preset("gear", lbl, {"loadout": cur.duplicate()}):
			_gear_note = "Uloženo: " + lbl
		else:
			_gear_note = "Plno (%d sad) - nejdřív nějakou smaž." % Game.PRESET_MAX
		_show_loadout())
	var kits := HFlowContainer.new()
	kits.add_theme_constant_override("h_separation", 3)
	body.add_child(kits)
	var kl := Label.new()
	kl.text = "Typ vojáka"
	UiSkin.eyebrow(kl)
	kits.add_child(kl)
	for k in Game.KITS:
		var kit: String = k
		_chip(kits, kit, "own", func(): Game.loadout = Game.KITS[kit].duplicate(); Game.save_settings(); _show_loadout())
	if _gear_note != "":
		var gn := Label.new()
		gn.text = _gear_note
		gn.autowrap_mode = TextServer.AUTOWRAP_WORD
		gn.custom_minimum_size = Vector2(280, 0)
		gn.add_theme_font_size_override("font_size", 7)
		gn.add_theme_color_override("font_color", UiSkin.OK)
		body.add_child(gn)
		_gear_note = ""
	var names := {"rh": "primární", "side": "sekundární", "lh": "štít"}
	var al := Label.new()
	al.text = "Zbroj"
	UiSkin.section(al, 7)
	body.add_child(al)
	var ab := _small_btn(body, Game.ITEMS[cur["armor"]]["short"] if cur.has("armor") else "vesta nebo pancíř ze skladu", func():
		if Game.loadout.has("armor"):
			Game.loadout.erase("armor")
			Game.save_settings()
			_show_loadout())
	ab.custom_minimum_size = Vector2(0, 16)
	if cur.has("armor"):
		UiSkin.item_icon(ab, cur["armor"], 22)
	else:
		UiSkin.ghost(ab)
	for g in [["Zbraně · primární je na začátku v rukou", ["rh", "side", "lh"], 3], ["Opasek 3-6 · batoh", ["b0", "b1", "b2", "b3"] + Game.pack_slots(), 4]]:
		var l := Label.new()
		l.text = g[0]
		UiSkin.section(l, 7)
		body.add_child(l)
		var grid := GridContainer.new()
		grid.columns = g[2]
		grid.add_theme_constant_override("h_separation", 3)
		grid.add_theme_constant_override("v_separation", 3)
		body.add_child(grid)
		for slot in g[1]:
			var sl: String = slot
			var txt: String = Game.ITEMS[cur[sl]]["short"] if cur.has(sl) and cur[sl] != "" else names.get(sl, "")
			var b := _small_btn(grid, txt, func():
				if Game.loadout.has(sl):
					Game.loadout.erase(sl)
					Game.save_settings()
					_show_loadout())
			b.custom_minimum_size = Vector2(92 if g[2] == 3 else 68, 30)
			var has_it: bool = cur.has(sl) and cur[sl] != ""
			UiSkin.item_tile(b, cur[sl] if has_it else "", txt, {"rh": "1", "side": "2", "b0": "3", "b1": "4", "b2": "5", "b3": "6"}.get(sl, ""))
			if sl == "rh" and has_it:
				b.add_theme_stylebox_override("normal", UiBox.make(Color(UiSkin.ACC, 0.08), UiSkin.ACC, 15, Vector4(3, 2, 3, 2)))
	var brow := HFlowContainer.new()
	brow.add_theme_constant_override("h_separation", 4)
	body.add_child(brow)
	UiSkin.ghost(_small_btn(brow, "Výchozí výstroj", func(): Game.loadout = {}; Game.save_settings(); _show_loadout()))
	_small_btn(brow, "ÚPRAVY ZBRANÍ", func(): _mods_from = "loadout"; _show_mods())
	UiSkin.ghost(_small_btn(brow, "Hotovo", _back))
	# right: the base stores as a table
	var store_box := VBoxContainer.new()
	store_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	store_box.add_theme_constant_override("separation", 2)
	row.add_child(store_box)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 2)
	store_box.add_child(tabs)
	for c in [["all", "Vše"], ["weapon", "Zbraně"], ["ammo", "Munice"], ["grenade", "Granáty"], ["gear", "Výstroj"]]:
		var cc: String = c[0]
		var tb := _small_btn(tabs, c[1], func(): _lo_cat = cc; _show_loadout())
		UiSkin.row(tb, _lo_cat == cc)
		tb.alignment = HORIZONTAL_ALIGNMENT_CENTER
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var th := HBoxContainer.new()
	store_box.add_child(th)
	for h in [["Sklad" + (" (veterán)" if vet else ""), 0], ["Ks", 24], ["Kg", 24], ["", 40]]:
		var hl := Label.new()
		hl.text = h[0]
		UiSkin.eyebrow(hl)
		if h[1] == 0:
			hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			hl.custom_minimum_size = Vector2(h[1], 0)
			hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		th.add_child(hl)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	store_box.add_child(sc)
	var store := VBoxContainer.new()
	store.add_theme_constant_override("separation", 0)
	store.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(store)
	for id in left:
		var item: String = id
		if _lo_cat != "all" and preload("res://scripts/geoscape.gd")._arm_cat(item) != _lo_cat:
			continue
		var rp := PanelContainer.new()
		rp.add_theme_stylebox_override("panel", UiBox.make(Color(0, 0, 0, 0), UiSkin.LINE, 8, Vector4(0, 1, 0, 1)))
		store.add_child(rp)
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 0)
		rp.add_child(r)
		var nm := Label.new()
		nm.text = String(Game.ITEMS[item]["short"])
		nm.tooltip_text = String(Game.ITEMS[item]["name"])
		nm.mouse_filter = Control.MOUSE_FILTER_PASS
		nm.clip_text = true
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.add_theme_font_size_override("font_size", 8)
		nm.add_theme_color_override("font_color", TEXT)
		r.add_child(nm)
		for v in [str(int(left[item])), str(int(Game.ITEMS[item]["weight"]))]:
			var vl := Label.new()
			vl.text = v
			vl.custom_minimum_size = Vector2(24, 0)
			vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			vl.add_theme_font_size_override("font_size", 8)
			vl.add_theme_color_override("font_color", UiSkin.DIM)
			r.add_child(vl)
		var pad := Control.new()
		pad.custom_minimum_size = Vector2(6, 0)
		r.add_child(pad)
		var b := _chip(r, "vzít", "own", func(): _loadout_take(item))
		b.custom_minimum_size = Vector2(34, 0)
		b.disabled = int(left[item]) <= 0
	_rl_w = 280.0

var _hotkeys := {}           # 0.72: single keys of the open screen (R = výchozí výstroj ...)

## Put a thing from the store on the soldier: the first free slot that takes it.
func _loadout_take(item: String) -> void:
	if Game.ITEMS[item]["type"] == "armor":
		Game.loadout["armor"] = item
		Game.save_settings()
		_show_loadout()
		return
	var two := Game.two_handed(item)
	var t: String = Game.ITEMS[item]["type"]
	var order := ["b0", "b1", "b2", "b3"] + Game.pack_slots()
	if t == "shield":
		order = ["lh"] + Game.pack_slots()
	elif t == "weapon" and two:
		order = ["rh"] + Game.pack_slots()
	elif t == "weapon":
		order = ["rh", "side"] + order
	elif t == "melee":
		order = ["side", "rh"] + order
	for slot in order:
		if Game.loadout.has(slot) and Game.loadout[slot] != "":
			continue
		if slot in ["rh", "lh", "side"] and Game.slot_refuse(slot, item) != "":
			continue
		if slot == "rh" and two and Game.loadout.get("lh", "") != "":
			continue
		if slot == "lh" and Game.two_handed(Game.loadout.get("rh", "")):
			continue
		Game.loadout[slot] = item
		break
	Game.save_settings()
	_show_loadout()

func _host() -> void:
	var err := Net.host()
	if err != "":
		_show_main(err)
		return
	_show_lobby()

func _show_join() -> void:
	_panel("PŘIPOJIT KE HŘE")
	_label("IP adresa hostitele:")
	var ip := LineEdit.new()
	ip.text = "127.0.0.1"
	ip.add_theme_font_size_override("font_size", 11)
	_box.add_child(ip)
	_button("Připojit", func():
		var err := Net.join(ip.text.strip_edges())
		if err != "":
			_show_main(err)
		else:
			_connecting(ip.text.strip_edges()))
	_button("Zpět", _show_main)

## Waiting for the host: a way out right away, and a word when he does not answer.
var _join_try := 0
func _connecting(ip: String) -> void:
	_join_try += 1
	var my_try := _join_try
	_panel("PŘIPOJUJI...")
	var st := _label("Čekám na hostitele %s..." % ip)
	_button("Zrušit připojování", func():
		_join_try += 1
		Net.close()
		_show_join())
	await get_tree().create_timer(10.0).timeout
	if my_try != _join_try or not is_instance_valid(st) or Net.roster.size() > 0:
		return
	st.text = "Hostitel %s neodpovídá. Zkontroluj IP adresu, jestli hostitel spustil hru a jestli ho nepouští firewall (port %d). Můžeš dál čekat nebo připojování zrušit." % [ip, Net.PORT]
	st.add_theme_color_override("font_color", UiSkin.WARN)
	st.custom_minimum_size = Vector2(300, 0)

func _show_lobby() -> void:
	var host := multiplayer.is_server()
	# 0.72 (návrh A): the mission and the team table on the left, everything to do on the right
	var ip := ""
	for a in IP.get_local_addresses():
		if String(a).count(".") == 3 and not String(a).begins_with("127.") and not String(a).begins_with("169.254"):
			ip = String(a)
			break
	var scr := _screen(["Co-op", "Tým"], ("%s · %d" % [ip, Net.PORT]) if host and ip != "" else ("port %d" % Net.PORT),
		[["T", "mluvit"], ["Tab", "vysílačka"]])
	_esc = Callable()           # leaving the team is a button (Odejít), not a slip of Esc
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scr.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 3)
	row.add_child(left)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(150, 0)
	right.add_theme_constant_override("separation", 4)
	row.add_child(right)
	_box = left
	_rl_w = 420.0
	var hl := Label.new()
	UiSkin.headline(hl, 14)
	left.add_child(hl)
	var sub := Label.new()
	left.add_child(sub)
	if Campaign.active or Campaign.viewer:
		hl.text = "Kampaň"
		sub.text = Game.DIFF_NAMES.get(Campaign.difficulty(), "normální") + " · palba do vlastních " + ("zapnutá" if Game.friendly_fire else "vypnutá")
	else:
		var qn: String = QUICK[quick_pick][0]
		var cut := qn.find(" (")
		hl.text = qn.substr(0, cut) if cut > 0 else qn
		sub.text = (qn.substr(cut + 2).trim_suffix(")") + " · " if cut > 0 else "") + Game.DIFF_NAMES.get(Game.difficulty, "normální") \
			+ " · palba do vlastních " + ("zapnutá" if Game.friendly_fire else "vypnutá") \
			+ " · mapa " + ("podle mise" if quick_size == "" else MapGen.SIZE_NAMES[quick_size])
	UiSkin.eyebrow(sub)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD
	sub.custom_minimum_size = Vector2(300, 0)
	_status = Label.new()
	_status.visible = false        # (keeps the refresh going: _process looks for "Hráči")
	left.add_child(_status)
	# the table: player, money, ping, microphone, state (and the host's kick)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 4)
	left.add_child(th)
	for h in [["Hráč", 0], ["Peníze", 48], ["Ping", 70], ["Mikrofon", 66], ["Stav", 58]] + ([["", 44]] if host else []):
		var l := Label.new()
		l.text = h[0]
		UiSkin.eyebrow(l)
		if h[1] == 0:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			l.custom_minimum_size = Vector2(h[1], 0)
		th.add_child(l)
	_lobby_rows = VBoxContainer.new()
	_lobby_rows.add_theme_constant_override("separation", 0)
	left.add_child(_lobby_rows)
	_lobby_sig = ""
	_lobby_mic = _label("", UiSkin.DIM, 8)
	if host:
		_label("Kamarádi se připojí na tvou IP adresu, port %d (TCP/UDP). Po internetu přes Radmin VPN / ZeroTier." % Net.PORT, UiSkin.DIM, 7)
	else:
		_label("Čekáme, až hostitel spustí misi. Mezitím si připrav výstroj a domluvte se (mikrofon funguje i tady).", UiSkin.DIM, 7)
	# right: what to do
	var acts := []
	if host:
		acts.append(["ZAČÍT MISI", func(): Net.start_mission(quick_params(quick_pick)), "primary"])
	elif Campaign.viewer:
		acts.append(["ZÁKLADNA A GLÓBUS", func(): _back_target = "lobby"; Game.goto_globe(), "primary"])
	acts.append_array([["VÝSTROJ NA MISI", func(): _back_target = "lobby"; _show_loadout(), ""],
		["MŮJ VOJÁK", func(): _back_target = "lobby"; _show_merc(), ""],
		["ÚPRAVY ZBRANÍ", func(): _back_target = "lobby"; _show_mods(), ""],
		["PENÍZE V TÝMU", func(): _back_target = "lobby"; _show_money(), ""],
		["HLAS A MIKROFON", func():
			_back_target = "lobby"
			preload("res://scripts/hud.gd").settings_tab = "voice"
			_panel("NASTAVENÍ")
			preload("res://scripts/hud.gd").settings_ui(_box)
			_button("Zpět", _back), ""]])
	if host:
		var sizes := ["", "small", "medium", "large", "huge", "colossal"]
		acts.append_array([["Změnit typ mise", func(): quick_pick = (quick_pick + 1) % QUICK.size(); _show_lobby(), "ghost"],
			["Palba do vlastních", func(): Game.friendly_fire = not Game.friendly_fire; Game.save_settings(); _show_lobby(), "ghost"],
			["Velikost mapy", func():
				quick_size = sizes[(sizes.find(quick_size) + 1) % sizes.size()]
				_show_lobby(), "ghost"]])
	acts.append(["Odejít", func(): Net.close(); _show_main(), "bad"])
	for act in acts:
		var b := _small_btn(right, act[0], act[1])
		b.custom_minimum_size = Vector2(150, 16)
		match act[2]:
			"primary": UiSkin.primary(b)
			"ghost": UiSkin.ghost(b)
			"bad":
				UiSkin.ghost(b)
				b.add_theme_color_override("font_color", UiSkin.BAD)
	_refresh_lobby()

var _lobby_rows: VBoxContainer
var _lobby_mic: Label
var _lobby_sig := ""
var _lobby_row := {}      # peer -> {"name", "money", "ping", "mic", "state": Label, "kick": Button or null}
var _kick_arm := {}       # peer -> msec: the first press only asks, the second sends him away
const MIC_TEXT := {"off": "vypnutý", "ptt": "na Tab", "open": "otevřený", "dead": "NEJDE"}

func _lobby_cell(row: Node, w: float, col := TEXT) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", col)
	l.clip_text = true
	if w <= 0.0:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size.x = 80
	else:
		l.custom_minimum_size.x = w
	row.add_child(l)
	return l

func _refresh_lobby() -> void:
	if _status == null or not is_instance_valid(_status):
		return
	if _lobby_rows == null or not is_instance_valid(_lobby_rows) or not is_inside_tree():
		return
	var host := multiplayer.is_server()
	var sig := str(host) + str(Net.roster.keys())
	if sig != _lobby_sig:
		_lobby_sig = sig
		_lobby_row.clear()
		for c in _lobby_rows.get_children():
			c.queue_free()
		for id in Net.roster:
			var pid: int = id
			var rp := PanelContainer.new()
			rp.add_theme_stylebox_override("panel", UiBox.make(Color(0, 0, 0, 0), UiSkin.LINE, 8, Vector4(0, 2, 0, 2)))
			_lobby_rows.add_child(rp)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			rp.add_child(row)
			var cells := {"name": _lobby_cell(row, 0), "money": _lobby_cell(row, 48), "ping": _lobby_cell(row, 70, UiSkin.DIM),
				"mic": _lobby_cell(row, 66, UiSkin.DIM), "state": _lobby_cell(row, 58, UiSkin.DIM)}
			var kb: Button = null
			if host and pid != 1:
				kb = _chip(row, "Vyhodit", "own", func():
					if Time.get_ticks_msec() - int(_kick_arm.get(pid, -100000)) < 3000:
						_kick_arm.erase(pid)
						Net.kick(pid)
					else:
						_kick_arm[pid] = Time.get_ticks_msec()
						_refresh_lobby())
				kb.custom_minimum_size.x = 44
			elif host:
				var gap := Control.new()      # the host's own row: keep the columns in line
				gap.custom_minimum_size.x = 44
				row.add_child(gap)
			cells["kick"] = kb
			_lobby_row[pid] = cells
	var lv: Node = Net.get_node_or_null("LobbyVoice")
	for id in _lobby_row:
		if not Net.roster.has(id):
			continue
		var r: Dictionary = _lobby_row[id]
		(r["name"] as Label).text = String(Net.roster[id]["name"]) + ("  (hostitel)" if id == 1 else "")
		(r["money"] as Label).text = ("%s" % BaseScreen.money(int(Net.wallets[id]))) if Net.wallets.has(id) else "-"
		var ping := Net.ping_of(id)
		var ln := Net.line_of(id)
		var shaky := false
		var pt := "-"
		if id != 1 and ping >= 0:
			pt = "%d" % ping
			if not ln.is_empty():
				pt += " ±%d · %d %%" % [int(ln["var"]), roundi(float(ln["loss"]) * 100.0)]
				shaky = float(ln["loss"]) > 0.03 or int(ln["var"]) > 40
		(r["ping"] as Label).text = pt
		var pcol := UiSkin.DIM
		if id != 1 and ping >= 0:
			pcol = UiSkin.OK if ping < 80 else (UiSkin.WARN if ping < 160 else UiSkin.BAD)
			if shaky and ping < 160:
				pcol = UiSkin.WARN
		(r["ping"] as Label).add_theme_color_override("font_color", pcol)
		var mic_s := Net.mic_of(id)
		(r["mic"] as Label).text = MIC_TEXT.get(mic_s, "-")
		(r["mic"] as Label).add_theme_color_override("font_color", UiSkin.WARN if mic_s == "dead" else UiSkin.DIM)
		var sick_m: Dictionary = Game.merc if id == Net.my_id() else Net.roster[id].get("merc", {})
		var st := "ve hře"
		var scol := UiSkin.DIM
		if lv and lv.speaking(id):
			st = "MLUVÍ"
			scol = ACCENT
		elif float(sick_m.get("sick", 0.0)) > 0.0:
			st = "na marodce"
			scol = UiSkin.WARN
		elif Net.ready_peers.has(id):
			st = "připraven"
			scol = UiSkin.OK
		(r["state"] as Label).text = st
		(r["state"] as Label).add_theme_color_override("font_color", scol)
		var kb: Button = r["kick"]
		if kb and is_instance_valid(kb):
			var armed := Time.get_ticks_msec() - int(_kick_arm.get(id, -100000)) < 3000
			kb.text = "Opravdu?" if armed else "Vyhodit"
			kb.add_theme_color_override("font_color", UiSkin.BAD if armed else TEXT)
	var bars := int(clampf(Game.mic_level * 60.0, 0.0, 12.0))
	var mic := "Mikrofon vypnutý (Nastavení)" if Game.voice_mode == "off" else "Tvůj mikrofon: [%s%s] %s" % ["|".repeat(bars), " ".repeat(12 - bars),
		"VYSÍLÁŠ" if Net.get_node("LobbyVoice").talking else ("drž Tab" if Game.voice_mode == "ptt" else "ticho")]
	_status.text = "Hráči (%d/%d):" % [Net.roster.size(), Net.MAX_PLAYERS]
	if _lobby_mic and is_instance_valid(_lobby_mic):
		_lobby_mic.text = mic + ("\n" + _last_note if _last_note != "" else "")

## Money between teammates (host included): agree who buys what and help each other out.
var _gift_to := 0
var _gift_amt := 100
func _show_money() -> void:
	_panel("PENÍZE V TÝMU")
	_label("Máš: %d kr. Žold dostává každý (i hostitel) - podíl z odměny, zabití, nálezy. Zbytek odměny jde do rozpočtu základny." % Net.my_money(), ACCENT, 9)
	if Campaign.active or Campaign.viewer:
		_label("Rozpočet základny: %d kr. Z něj se platí výzkum, stavby, zbraně a měsíční údržba." % int(Campaign.data.get("credits", 0)), FRAME, 9)
		var rowd := HBoxContainer.new()
		_box.add_child(rowd)
		for a2 in [100, 250, 500, 1000]:
			var amt2: int = a2
			_small_btn(rowd, "Přispět %d kr" % amt2, func():
				if Net.my_money() < amt2:
					_show_main_msg("Tolik peněz nemáš.")
					return
				Net.donate(amt2)
				await get_tree().create_timer(0.4).timeout
				_show_money())
	var others := []
	for id in Net.roster:
		if id != Net.my_id():
			others.append(id)
	if others.is_empty():
		_label("Nikdo další není připojený.", FRAME, 9)
	else:
		if not _gift_to in others:
			_gift_to = others[0]
		var row := HBoxContainer.new()
		_box.add_child(row)
		for id in others:
			var pid: int = id
			_small_btn(row, ("> " if pid == _gift_to else "") + str(Net.roster[pid]["name"]), func(): _gift_to = pid; _show_money())
		var row2 := HBoxContainer.new()
		_box.add_child(row2)
		for a in [50, 100, 250, 500, 1000]:
			var amt: int = a
			_small_btn(row2, ("> " if amt == _gift_amt else "") + "%d kr" % amt, func(): _gift_amt = amt; _show_money())
		_button("Poslat %d kr hráči %s" % [_gift_amt, Net.roster[_gift_to]["name"]], func():
			if Net.my_money() < _gift_amt:
				_show_main_msg("Tolik peněz nemáš.")
				return
			Net.give_money(_gift_to, _gift_amt)
			await get_tree().create_timer(0.4).timeout
			_show_money())
	_button("Zpět", _back)

var _last_note := ""
func _on_note(t: String) -> void:
	_last_note = t
	_refresh_lobby()

func _show_main_msg(t: String) -> void:
	if _status and is_instance_valid(_status):
		_status.text = t
	else:
		_label(t, UiSkin.BAD, 9)

# ---- headless tests -------------------------------------------------------------
func _autotest() -> void:
	match Game.autotest():
		"mocapview", "mocapinstall", "afkinstall", "tilesurvey", "tileround":
			var mv := Node.new() if Game.autotest() in ["mocapinstall", "afkinstall"] else Node3D.new()
			mv.set_script(load({"mocapview": "res://tools/test/mocap_preview.gd", "mocapinstall": "res://tools/test/mocap_install.gd",
				"afkinstall": "res://tools/test/afk_install.gd",
				"tilesurvey": "res://tools/test/tile_survey.gd", "tileround": "res://tools/test/tile_round.gd"}[Game.autotest()]))
			get_tree().root.add_child.call_deferred(mv)
			queue_free()
		"animator", "animatorshots", "animmixamo":
			get_tree().change_scene_to_file("res://scenes/Animator.tscn")
		"workshop", "wsclick", "animtest", "animshots", "agun", "modelcheck":
			get_tree().change_scene_to_file("res://scenes/Workshop.tscn")
		"tileeditor", "tileshots":
			get_tree().change_scene_to_file("res://scenes/TileEditor.tscn")
		"modeler", "modclick", "modspeed":
			get_tree().change_scene_to_file("res://scenes/Modeler.tscn")
		"geo", "campaign", "campair", "uigeo", "geoevents", "encyshot", "striketest", "geomodels", "basepick", "carttest", "gameover":
			# (the test machine's merc may still be on the sick bay from an earlier test run)
			for k in ["heal_days", "injury", "sick", "heal_cid", "heal_seen"]:
				Game.merc.erase(k)
			if Game.cmd_arg("newcamp", "1") == "1":
				Campaign.new_campaign()
			else:
				Campaign.load_campaign()
			get_tree().change_scene_to_file("res://scenes/Geoscape.tscn")
		"loadprog":
			# 0.72: the globe parked behind the menu screens, the loading bar while a mission is built
			if get_tree().root.has_node("LoadProgTest"):
				return
			var lt := Node.new()
			lt.set_script(load("res://scripts/autotest_load.gd"))
			get_tree().root.add_child.call_deferred(lt)
		"menuflicker":
			# every menu panel must settle: its size may not keep changing frame after frame
			if not Campaign.has_save():
				Campaign.new_campaign("normal")
				Campaign.active = false
			var bad := 0
			for e in [["newcamp_easy", "easy"], ["newcamp_normal", "normal"], ["newcamp_vet", "veteran"], ["quick", ""], ["campaign", ""], ["settings", ""], ["news", ""]]:
				match String(e[0]):
					"quick": _show_quick()
					"campaign": _show_campaign()
					"settings": _show_settings()
					"news": _show_news()
					_:
						_new_diff = e[1]
						_show_new_campaign()
				for f in 20: await get_tree().process_frame
				var changes := 0
				var last := _scroll.custom_minimum_size
				for f in 60:
					await get_tree().process_frame
					if _scroll.custom_minimum_size != last:
						changes += 1
						last = _scroll.custom_minimum_size
				print("[FLICKER] %s: %d changes in 60 frames" % [e[0], changes])
				if changes > 1:
					bad += 1
			print("RESULT menuflicker %d unstable" % bad)
			get_tree().quit()
		"ui":
			# every menu screen, checked for text sticking out of the screen
			var shots := [["main", func(): _show_main("Tohle je dlouhá zpráva hlavního menu, která by se měla zalomit a nevylézt z okna ven.")],
				["quick", _show_quick], ["campaign", func(): _show_campaign()], ["newcamp", _show_new_campaign], ["editor", _show_editor], ["merc", func(): Game.merc["created"] = true; _show_merc()],
				["create", func(): _show_create(true)],
				["create_dice", func():
					var keep: Dictionary = Game.dice.duplicate(true)
					Game.dice = {"left": 0, "last": Game.roll_levels(RandomNumberGenerator.new()), "peak": 1}
					_show_create(true); _cr_mode = "points"; _build_create()
					Game.dice = keep], ["look", func(): _show_create(false)],
				["settings", _show_settings], ["coop", _show_coop],
				["set_snd", func(): preload("res://scripts/hud.gd").settings_tab = "snd"; _show_settings()], ["set_voice", func(): preload("res://scripts/hud.gd").settings_tab = "voice"; _show_settings()],
				["set_gfx", func(): preload("res://scripts/hud.gd").settings_tab = "gfx"; _show_settings()],
				["keys_0", func(): preload("res://scripts/hud.gd").settings_tab = "keys"; preload("res://scripts/hud.gd").keys_group = 0; _show_settings()], ["keys_1", func(): preload("res://scripts/hud.gd").keys_group = 1; _show_settings()],
				["keys_2", func(): preload("res://scripts/hud.gd").keys_group = 2; _show_settings()], ["keys_3", func(): preload("res://scripts/hud.gd").keys_group = 3; _show_settings()],
				["keys_4", func(): preload("res://scripts/hud.gd").keys_group = 4; _show_settings(); preload("res://scripts/hud.gd").settings_tab = "ctl"; preload("res://scripts/hud.gd").keys_group = 0],
				["loadout", _show_loadout], ["join", _show_join], ["connecting", func(): _connecting("192.168.0.99")], ["news", _show_news], ["mods", _show_mods], ["talents", _show_talents], ["money", _show_money], ["lobby", _show_lobby], ["past", _show_past],
				["update", func(): Game.upd_state = "full"; Game.upd_version = "0.14"; _show_main()],
				["ready", func(): Game.upd_state = "ready"; _show_main()]]
			for e in shots:
				e[1].call()
				await get_tree().process_frame
				await get_tree().process_frame
				Game.ui_audit(self, e[0])
				if DisplayServer.get_name() != "headless":
					get_viewport().get_texture().get_image().save_png("user://ui_%s.png" % e[0])
			get_tree().quit()
		"talentui":
			# 0.62: the talent tree - order and ranks hold, a point is spent, the easy swap (user://talents_N.png)
			Game.skirmish = true
			Game.merc = Game.merc.duplicate(true)
			Game.merc["xp"] = 1300          # Rotný: tiers 1-3 open
			Game.merc["talents"] = ["rychle_prebiti"]
			Game.merc["talent_points"] = 3
			Game.difficulty = "normal"
			Game.pick_talent("strelec")                    # the one above it missing
			var skip := Game.has_talent(Game.merc, "strelec")
			Game.pick_talent("pevna_ruka")
			Game.pick_talent("strelec")
			var chain := Game.has_talent(Game.merc, "pevna_ruka") and Game.has_talent(Game.merc, "strelec")
			Game.pick_talent("rychle_taseni")              # needs Rotmistr
			var rank := not Game.has_talent(Game.merc, "rychle_taseni") and Game.talent_state(Game.merc, 0, 3) == "rank"
			Game.pick_talent("mezek")
			var spent := int(Game.merc["talent_points"]) == 0 and Game.talent_state(Game.merc, 3, 1) == "nopoint"
			var normal_eye := Game.tree_talent(3, 3, Game.merc) == "sesty_smysl"
			Game.difficulty = "easy"
			var easy_drone := Game.tree_talent(3, 3, Game.merc) == "technik_dronu"
			_show_talents()
			await get_tree().create_timer(0.8).timeout
			Game.ui_audit(self, "talents")
			if DisplayServer.get_name() != "headless":
				get_viewport().get_texture().get_image().save_png("user://talents_1.png")
			Game.merc["talent_points"] = 1
			Game.difficulty = "normal"
			_show_talents()
			await get_tree().create_timer(0.5).timeout
			if DisplayServer.get_name() != "headless":
				get_viewport().get_texture().get_image().save_png("user://talents_2.png")
			print("[TALENT] skip %s chain %s rank %s spent %s eye %s drone %s" % [not skip, chain, rank, spent, normal_eye, easy_drone])
			get_tree().quit()
		"modsui":
			# 0.57: the weapon parts screen - buy, mount, swap (user://modsui_N.png, [UI] audit);
			# on a copy of the soldier that is never saved
			Game.skirmish = true
			Game.merc = Game.merc.duplicate(true)
			Game.merc["money"] = 1500
			Game.merc.erase("fit")
			Game.merc.erase("mods")
			_mods_sel = "rifle"
			_show_mods()
			await get_tree().create_timer(1.2).timeout
			Game.ui_audit(self, "mods_plain")
			get_viewport().get_texture().get_image().save_png("user://modsui_1.png")
			var ok1 := Game.buy_mod("rifle", "optika") and Game.buy_mod("rifle", "bajonet") and Game.buy_mod("rifle", "rukojet")
			_show_mods()
			_mods_hint("%s - %s\n%s" % [Game.MODS["optika"]["name"], Game.MODS["optika"]["desc"], _part_effects("optika")])
			await get_tree().create_timer(1.2).timeout
			Game.ui_audit(self, "mods_parts")
			get_viewport().get_texture().get_image().save_png("user://modsui_2.png")
			Game.mount_mod("rifle", "kolimator_t")
			Game.unmount_slot("rifle", "hlaven")
			print("[MODS] bought %s fit %s owns optika %s money %d kg %.2f" % [ok1, Game.fitted("rifle"), Game.owns_mod("rifle", "optika"), Game.purse(), Game.part_weight("rifle")])
			get_tree().quit()
		"voicedsp":
			preload("res://scripts/autotest_voice.gd").run()
			get_tree().quit()
		"vnethost", "vnetclient":
			# (0.62) voice over the real network: own channel, sequence numbers, every 7th packet lost
			Game.merc["name"] = "Host" if Game.autotest() == "vnethost" else "Klient"
			var lv: Node = Net.get_node("LobbyVoice")
			if Game.autotest() == "vnethost":
				Net.host(int(Game.cmd_arg("port", str(Net.PORT))))
				var t0 := Time.get_ticks_msec()
				while Time.get_ticks_msec() - t0 < 9000 + maxi(0, int(Game.cmd_arg("pkts", "50")) - 50) * 60:
					await get_tree().create_timer(0.2).timeout
				var rx = lv._chan.values()[0]["rx"] if not lv._chan.is_empty() else null
				print("RESULT vnet received %d lost %d dry %d" % [lv.received, rx.lost if rx else -1, rx.underruns if rx else -1])
				if rx:
					print("[VNET] late %d dropped %d filled %d jitter %.0f ms cushion %.0f ms" % [rx.late, rx.dropped, rx.rescued, rx.jitter * 1000.0, rx.target() * 1000.0])
			else:
				await get_tree().create_timer(1.5).timeout
				Net.join("127.0.0.1", int(Game.cmd_arg("port", str(Net.PORT))))
				await get_tree().create_timer(2.5).timeout
				var chunk := int(lv.Voice.RATE * lv.Voice.CHUNK)
				var n := 0
				for k in int(Game.cmd_arg("pkts", "50")):
					var smp := PackedFloat32Array()
					smp.resize(chunk)
					for i in chunk:
						smp[i] = sin(TAU * 200.0 * (k * chunk + i) / lv.Voice.RATE) * 0.2
					var pkt: PackedByteArray = lv.dsp.packet(smp)
					if k % 7 != 3 or Game.cmd_arg("pkts", "") != "":
						lv._lobby_voice.rpc(pkt, false, false)
						n += 1
					await get_tree().create_timer(0.06).timeout
				print("RESULT vnet client sent %d" % n)
				await get_tree().create_timer(2.0).timeout
			get_tree().quit()
		"introshots":
			preload("res://scripts/autotest_facelift2.gd").intro(self)
		"presets":
			# 0.60: soldier templates and saved loadouts (own test file - the player's presets stay)
			Game.preset_file = "user://presety_test.cfg"
			DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.preset_file))
			Game.skirmish = true      # nothing gets saved, free stores
			var keep_lo: Dictionary = Game.loadout.duplicate()
			_show_create(true)
			var first_view := _cr_presets
			var lv := {"accuracy": 9, "reactions": 7, "strength": 2, "bravery": 4, "health": 5, "stamina": 3}
			Game.set_levels(_cr, lv)
			_cr["name"] = "Test Vzor"
			_cr["look"]["tattoo"] = 2
			Game.save_preset("merc", "Vzor", Game.merc_preset(_cr, true))
			Game.save_preset("merc", "Kostky", Game.merc_preset(_cr, false))
			_show_create(true)
			await get_tree().create_timer(1.0).timeout
			Game.ui_audit(self, "create_presets")
			if DisplayServer.get_name() != "headless":
				get_viewport().get_texture().get_image().save_png("user://presets_1.png")
			var on_list := _cr_presets
			_apply_merc_preset(Game.presets("merc")[0])
			var merc_ok: bool = _cr["name"] == "Test Vzor" and int(_cr["look"].get("tattoo", 0)) == 2 and not _cr_presets
			var lv_ok: bool = int(_cr["levels"]["accuracy"]) == 9 and int(_cr["accuracy"]) == Game.stat_value("accuracy", 9)
			var dice_ok: bool = not Game.presets("merc")[1].has("levels")
			Game.loadout = Game.KITS["Odstřelovač"].duplicate()
			_show_loadout()
			Game.save_preset("gear", "Snajpr", {"loadout": Game.valid_loadout(false)})
			Game.loadout = {}
			_show_loadout()
			Game.loadout = (Game.presets("gear")[0]["loadout"] as Dictionary).duplicate()
			_gear_note = "Sada Snajpr nasazena."
			_show_loadout()
			await get_tree().create_timer(1.0).timeout
			Game.ui_audit(self, "loadout_presets")
			if DisplayServer.get_name() != "headless":
				get_viewport().get_texture().get_image().save_png("user://presets_2.png")
			var gear_ok: bool = Game.valid_loadout(false).get("rh", "") == "sniper"
			# Back from making a new (only) soldier goes where the player came from, not to the menu
			Game.merc["created"] = false
			_back_target = "campaign"
			_create_back()
			print("[PRESET] back campaign %s" % (_back_target == "" and Game.mercs.size() <= 1))
			Game.loadout = keep_lo
			DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.preset_file))
			print("[PRESET] first %s list %s merc %s levels %s dice_nolevels %s gear %s" % [first_view, on_list, merc_ok, lv_ok, dice_ok, gear_ok])
			get_tree().quit()
		"create":
			_show_create(true)
			await get_tree().create_timer(1.0).timeout
			get_viewport().get_texture().get_image().save_png("user://70_create_points.png")
			_bump("accuracy", 1)
			_bump("bravery", -2)
			_bump("health", 2)
			print("[CREATE] levels %s acc %d hp %d" % [_cr["levels"], _cr["accuracy"], _cr["health"]])
			_cr["look"] = {"female": true, "hair": "long", "hair_color": 4, "beard": 0, "eye_color": 3, "skin": 0, "headgear": 2}
			_cr_face = true
			_cr_rot = PI
			_build_create()
			await get_tree().create_timer(1.0).timeout
			get_viewport().get_texture().get_image().save_png("user://71_create_female.png")
			_cr_mode = "dice"
			var r := RandomNumberGenerator.new(); r.seed = 3
			Game.set_levels(_cr, Game.roll_levels(r))
			_cr["look"] = {"female": false, "hair": "mohawk", "hair_color": 0, "beard": 4, "eye_color": 4, "skin": 3, "headgear": 2}
			_cr_rot = PI + 0.3
			_build_create()
			await get_tree().create_timer(1.0).timeout
			get_viewport().get_texture().get_image().save_png("user://72_create_dice.png")
			get_tree().quit()
		"air", "airfx":
			Net.mission_params = {"intercept": true, "id": -1, "ufo": Game.cmd_arg("ufo", "raider")}
			get_tree().change_scene_to_file("res://scenes/Intercept.tscn")
		"escort":
			Net.mission_params = {"escort": true, "craft": -1, "transport": Game.cmd_arg("tr", "heli"), "escort_n": int(Game.cmd_arg("esc", "2")), "pilots": [], "driver": 0}
			get_tree().change_scene_to_file("res://scenes/Escort.tscn")
		"town", "zoo", "terror", "shouldershot", "radiosprint", "voice", "club", "uimission", "stance", "wshot", "sightshot", "muzzleshot", "pose", "rlanim", "ufoshot", "mapshot", "objtest", "breaktest", "armstest", "invtest", "actshot", "stuntest", "tactics", "cloakshot", "doorshot", "passcheck", "rooftest", "camoshot", "lookshot", "soundcheck", "dronetest", "dronereal", "airdeath", "vipcheck", "climb", "rocktest", "hitbox", "leaktest", "leakmap", "ufohull", "wedgetest", "leantest", "pockettest", "leaveany", "safeend", "skyshot", "zfight", "suittest", "levgrab", "mirotest", "bijtest", "weaktest", "sgtest", "kanontest", "mgheat", "seedtest", "supplytest", "rockettest", "bvtest", "nadtest", "ohntest", "mystest", "koltest", "lasertest", "lcshot", "ppshot", "bijanim", "afkalien", "softparts", "fpmocap", "vrplay", "vrstrike", "strikeshot", "fpreload", "quickcut", "civanim", "civdeath", "tpwalk", "blendtest", "talenttest", "dragshot", "testroom", "plasmatest", "aitest", "nadetest", "searchtest", "feartest", "squadtest", "packtest", "heattest", "tunetest", "styletest", "dirtest", "nemtest", "civtest", "latetest", "reinfcap", "gunshots", "topshot", "shieldtest", "shieldshot", "locktest", "mocapgame", "beltthrow", "fireshot", "abase", "radartest", "loadshots", "transport", "uifit", "groundtest", "ceiltest", "rainshot", "lamptest", "wxtest", "wxshot", "tracktest", "lensshot", "interiors", "spectate", "dazetest", "chaintest", "echotest", "dirtshot", "flaretest", "civpanic", "nvgtest", "civstuck", "civlooks", "fragtest", "convoytest", "bugtest", "quartest":
			Net.play_solo()
			Campaign.active = false
			Net.start_mission({"type": Game.cmd_arg("mtype", "terror"), "biome": Game.cmd_arg("biome", "town"), "night": Game.cmd_arg("day", "0") != "1",
				"hour": float(Game.cmd_arg("hour", "14.0" if Game.cmd_arg("day", "0") == "1" else "23.0")), "place": "Test", "type_name": "Test", "extra_aliens": 1, "id": -1, "testroom": Game.autotest() == "testroom", "terrain": Game.cmd_arg("terrain", "temperate"), "size": Game.cmd_arg("size", "medium"), "ufo": Game.cmd_arg("ufo", ""), "crew_of": Game.cmd_arg("crewof", ""), "group": Game.cmd_arg("group", ""), "research": Array(Game.cmd_arg("research", "").split(",", false)),
				"habits": {String(Game.merc.get("name", "")): Game.cmd_arg("habits", "").split(",", false)} if Game.cmd_arg("habits", "") != "" else {},
				"styles": {String(Game.merc.get("name", "")): Array(Game.cmd_arg("styles", "").split(",", false))} if Game.cmd_arg("styles", "") != "" else {}})
		"basewalk", "basepass", "basenade", "basefly", "blastdoor", "npcshot", "baseshot", "echobase", "wallshot", "dazebase", "chainbase":
			Net.play_solo()
			var b := []
			for i in 24:
				b.append({"type": "", "days": 0.0})
			var lay := {0: "velin", 1: "hangar", 6: "ubikace", 7: "laborator", 2: "dilna", 8: "cela", 13: "osetrovna", 3: "radar", 9: "sklad", 14: "laborator", 12: "strelnice",
				4: "silo", 10: "laser_vez", 15: "plazma_vez", 16: "maskovani", 11: "psi_gen"}
			for k in lay:
				b[k] = {"type": lay[k], "days": 4.0 if k == 14 else 0.0}
			var atk := Game.cmd_arg("attack", "") == "1" or Game.autotest() == "blastdoor"
			Net.start_mission({"type": "base" if atk else "home", "type_name": "Útok na základnu" if atk else "Základna", "base": b, "grid_w": 6, "grid_h": 4, "transport": "heli",
				"live": ["grey", "levit"], "night": false, "attack": atk, "blips": [[50.0, 15.0], [40.0, -3.0], [10.0, 30.0]], "group": "sedaci",
				"fallen": _test_fallen(int(Game.cmd_arg("fallen", "0")))})
		"solo", "rampcheck", "perf", "navcache", "farview", "mergeshot", "shot", "ai", "panic", "arsenal", "evac":
			if Game.autotest() == "shot":
				await get_tree().create_timer(1.5).timeout
				get_viewport().get_texture().get_image().save_png("user://00_menu.png")
				_show_merc()
				await get_tree().create_timer(0.5).timeout
				get_viewport().get_texture().get_image().save_png("user://00_merc.png")
				_show_loadout()
				await get_tree().create_timer(0.5).timeout
				get_viewport().get_texture().get_image().save_png("user://00_loadout.png")
				_panel("NASTAVENÍ")
				preload("res://scripts/hud.gd").settings_ui(_box)
				await get_tree().create_timer(0.4).timeout
				get_viewport().get_texture().get_image().save_png("user://00_settings.png")
			Net.play_solo()
			Net.start_mission()
		"airhost":
			Net.host(int(Game.cmd_arg("port", str(Net.PORT))))
			while Net.roster.size() < 2:
				await get_tree().create_timer(0.2).timeout
			await get_tree().create_timer(0.5).timeout
			Net.start_intercept({"intercept": true, "id": -1, "ufo": Game.cmd_arg("ufo", "harvester"), "pilots": Net.roster.keys()})
		"airclient":
			Game.merc["name"] = "Wingman"
			await get_tree().create_timer(1.0).timeout
			Net.join("127.0.0.1", int(Game.cmd_arg("port", str(Net.PORT))))
		"kickhost":
			# (0.61) the lobby: the host sees the client's ping and microphone, sends him away,
			# and the same client cannot come straight back
			Game.merc["name"] = "Host"
			Net.host(int(Game.cmd_arg("port", str(Net.PORT))))
			_show_lobby()
			while Net.roster.size() < 2:
				await get_tree().create_timer(0.2).timeout
			await get_tree().create_timer(2.5).timeout
			var cid: int = Net.roster.keys().filter(func(k): return k != 1)[0]
			var rows := _lobby_rows.get_child_count() if _lobby_rows and is_instance_valid(_lobby_rows) else 0
			var ping0 := Net.ping_of(cid)
			var mic0 := Net.mic_of(cid)
			print("RESULT kick lobby rows %d ping %d mic %s info '%s'" % [rows, Net.ping_of(cid), Net.mic_of(cid), (_lobby_row[cid]["ping"] as Label).text + " / " + (_lobby_row[cid]["mic"] as Label).text if _lobby_row.has(cid) else "-"])
			if DisplayServer.get_name() != "headless":
				_kick_arm[cid] = Time.get_ticks_msec()
				_refresh_lobby()
				await get_tree().create_timer(0.3).timeout
				get_viewport().get_texture().get_image().save_png("user://lobby_kick.png")
			Net.kick(cid)
			var after := Net.roster.size()
			var t0 := Time.get_ticks_msec()
			var back := false
			while Time.get_ticks_msec() - t0 < 8000:
				await get_tree().create_timer(0.2).timeout
				if Net.roster.size() > 1:
					back = true
			print("RESULT kick summary rows %d ping %d mic %s after %d rejoined %s" % [rows, ping0, mic0, after, back])
			get_tree().quit()
		"kickclient":
			Game.merc["name"] = "Klient"
			Game.voice_mode = "open"
			await get_tree().create_timer(1.5).timeout
			var msgs := []
			Net.connection_failed.connect(func(r): msgs.append(r))
			Net.join("127.0.0.1", int(Game.cmd_arg("port", str(Net.PORT))))
			var t1 := Time.get_ticks_msec()
			while msgs.is_empty() and Time.get_ticks_msec() - t1 < 15000:
				await get_tree().create_timer(0.2).timeout
			print("KICK client 1: %s (my ping %d)" % [msgs, Net.ping_of(Net.my_id())])
			Net.join("127.0.0.1", int(Game.cmd_arg("port", str(Net.PORT))))
			t1 = Time.get_ticks_msec()
			while msgs.size() < 2 and Time.get_ticks_msec() - t1 < 6000:
				await get_tree().create_timer(0.2).timeout
			print("RESULT kick client %s" % [msgs])
			get_tree().quit()
		"michost", "micclient":
			Game.voice_mode = "open"
			Game.merc["name"] = "Host" if Game.autotest() == "michost" else "Klient"
			if Game.autotest() == "michost":
				Net.host(int(Game.cmd_arg("port", str(Net.PORT))))
			else:
				await get_tree().create_timer(1.5).timeout
				Net.join("127.0.0.1", int(Game.cmd_arg("port", str(Net.PORT))))
			var lv: Node = Net.get_node("LobbyVoice")
			for i in (8 if Game.autotest() == "micclient" or Game.cmd_arg("tomission", "") != "1" else 5):
				await get_tree().create_timer(1.0).timeout
				print("[MIC %s] t=%d open=%s frames/s=%d level=%.3f talking=%s sent=%d received=%d devices=%s" % [Game.autotest(), i, lv.mic != null, lv.frames_in, Game.mic_level, lv.talking, lv.sent, lv.received, AudioServer.get_input_device_list()])
			if Game.cmd_arg("tomission", "") == "1" and Game.autotest() == "michost":
				Net.start_mission()
			if Game.cmd_arg("tomission", "") != "1":
				var f := FileAccess.open("user://rx_%s.raw" % Game.autotest(), FileAccess.WRITE)
				f.store_buffer(lv.dbg_rx.to_byte_array())
				f.close()
				get_tree().quit()
		"gearloss":
			# economy: an order takes days; a won mission costs what was used up; a lost one everything taken
			Campaign.new_campaign()
			Campaign.data["credits"] = 5000
			var g0 := int(Campaign.data["armory"].get("grenade", 0))
			Campaign.buy("grenade")
			var arrived0 := int(Campaign.data["armory"].get("grenade", 0)) == g0
			Campaign.advance(5.0)
			var arrived1 := int(Campaign.data["armory"].get("grenade", 0)) == g0 + 1
			var c0 := int(Campaign.data["credits"])
			Campaign.sell("grenade")
			var sold := int(Campaign.data["credits"]) > c0
			var gr := int(Campaign.data["armory"].get("grenade", 0))
			var kit := ["rifle", "rifle_clip", "rifle_clip", "rifle_clip", "grenade", "grenade", "vesta"]
			# won: threw one grenade, all else home
			Campaign.mission_done(-1, true, 1, 0, 0, 0, 0, [], {}, false, {1: kit}, 1.0, {1: {"grenade": 1, "rifle_clip": 1}}, {1: {}})
			var gr1 := int(Campaign.data["armory"].get("grenade", 0))
			var clips1 := int(Campaign.data["armory"].get("rifle_clip", 0))
			# lost: everything taken stays out there
			Campaign.mission_done(-1, false, 0, 0, 1, 0, 0, [], {}, true, {1: kit}, 1.0, {1: {"rifle": 1, "rifle_clip": 3, "grenade": 2, "vesta": 1}}, {1: {}})
			print("RESULT gearloss order_wait %s arrived %s sold %s won_grenades %d->%d clips_kept %s lost_grenades %d vests %d" % [arrived0, arrived1, sold, gr, gr1, clips1 == int(Campaign.START_ARMORY["rifle_clip"]), int(Campaign.data["armory"].get("grenade", 0)), int(Campaign.data["armory"].get("vesta", 0))])
			get_tree().quit()
		"basedef":
			# (Ari 2026-11-13) raids on the base are rare, and a lost (or ignored) defence ends the campaign
			Campaign.new_campaign()
			Campaign.data["base_pick"] = false
			var raids := []
			while float(Campaign.data["day"]) < 240.0 and not Campaign.data["lost"]:
				Campaign.data["trust"] = 60
				Campaign.data["credits"] = 100000
				Campaign.data["next_strike"] = 9999.0
				Campaign.advance(0.25)
				for mm in Campaign.data["missions"].duplicate():
					if mm["type"] == "base":
						raids.append([float(Campaign.data["day"]), int(mm["extra_aliens"])])
						Campaign.data["missions"].erase(mm)       # (defended)
			var gaps := []
			for i in range(1, raids.size()):
				gaps.append(snappedf(raids[i][0] - raids[i - 1][0], 0.1))
			print("[BASEDEF] raids %s gaps %s" % [str(raids), str(gaps)])
			# a defence won: the campaign goes on
			var bid := func() -> int:
				Campaign.data["next_raid"] = float(Campaign.data["day"])
				Campaign.data["trust"] = 60
				Campaign.advance(0.01)
				for mm in Campaign.data["missions"]:
					if mm["type"] == "base":
						return int(mm["id"])
				return -1
			var id1: int = bid.call()
			Campaign.mission_done(id1, true, 4, 0, 0)
			var lost_won: bool = Campaign.data["lost"]
			# lost: game over
			var id2: int = bid.call()
			var t2 := Campaign.mission_done(id2, false, 1, 0, 1, 0, 0, [], {}, true)
			var lost_fail: bool = Campaign.data["lost"]
			# nobody went: game over too
			Campaign.new_campaign()
			Campaign.data["base_pick"] = false
			Campaign.data["day"] = 40.0
			var id3: int = bid.call()
			Campaign.advance(0.3)
			print("RESULT basedef raids %d first %.1f won_lost %s fail_lost %s konec %s ignored %s ignored_lost %s" % [raids.size(), raids[0][0] if not raids.is_empty() else -1.0, lost_won, lost_fail, t2.begins_with("KONEC"), id3 >= 0, Campaign.data["lost"]])
			get_tree().quit()
		"workshoptest":
			# 0.57: what research opened is made in the workshop (credits, alloys, Moskovium, days);
			# ordinary gear is bought and here the next day; the Jestřáb and the Kondor are built too
			Campaign.new_campaign()
			Campaign.data["credits"] = 50000
			Campaign.data["moskovium"] = 200
			var w := []
			w.append(Campaign.workshop_lines() == 1)
			Campaign.data["research"]["done"] += ["laser", "laser_puska", "rozbor_plazma", "slitiny", "vesta", "pancir", "jestrab", "kondor", "pancir_letadel"]
			w.append(not Campaign.buy("laser_rifle"))
			var g0 := int(Campaign.data["armory"].get("grenade", 0))
			Campaign.buy("grenade")
			Campaign.advance(0.5)
			var g_half := int(Campaign.data["armory"].get("grenade", 0)) == g0
			Campaign.advance(0.6)
			w.append(g_half and int(Campaign.data["armory"].get("grenade", 0)) == g0 + 1)
			Campaign.data["found"] = {"slitiny": 5}
			w.append(not Campaign.make("pancir"))
			Campaign.data["found"]["slitiny"] = 6
			w.append(Campaign.make("pancir") and Campaign.alloys() == 0)
			w.append(Campaign.make("laser_rifle"))
			var t_a := Campaign.made_at("laser_rifle")
			# one line: the rifle waits for the vest
			w.append(t_a > float(Campaign.data["day"]) + Campaign.make_days("laser_rifle") + 0.1)
			Campaign.data["base"][3] = {"type": "dilna", "days": 0.0}
			Campaign._workshop_eta()
			# a second workshop: the same queue, half as fast again
			var t_a2 := Campaign.made_at("laser_rifle")
			w.append(t_a2 < t_a - 0.5)
			w.append(Campaign.make("laser_rifle") and float(Campaign.data["orders"][-1]["at"]) > t_a2)
			Campaign.advance(9.0)
			w.append(int(Campaign.data["armory"].get("pancir", 0)) == 1 and int(Campaign.data["armory"].get("laser_rifle", 0)) == 2)
			# fighters: a Sokol tomorrow, a Jestřáb from the workshop
			var j0 := Campaign.jets()
			Campaign.buy_jet()
			w.append(Campaign.jets() == j0)
			Campaign.advance(1.1)
			w.append(Campaign.jets() == j0 + 1)
			Campaign.data["found"]["slitiny"] = 40
			w.append(Campaign.buy_hawk() and Campaign.hawks() == 0)
			Campaign.advance(8.0)
			w.append(Campaign.hawks() == 1)
			w.append(Campaign.transport() == "heli" and Campaign.make_kondor())
			Campaign.advance(6.0)
			w.append(Campaign.transport() == "kondor")
			# an upgrade researched is only a design until the workshop makes it
			var ip := {"id": 1, "kind": "scout", "lat": 0.0, "lon": 0.0}
			w.append(not Campaign.intercept_params(ip).get("jet_armor", false) and not ("pancir_letadel" in Campaign.active_research()))
			w.append(Campaign.make_upgrade("pancir_letadel"))
			Campaign.advance(5.0)
			w.append(Campaign.intercept_params(ip).get("jet_armor", false))
			# the Pelikán too
			Campaign.data["research"]["done"].append("orel")
			Campaign.data["found"]["slitiny"] = 60
			w.append(not Campaign.pelikan() and Campaign.make_pelikan())
			Campaign.advance(9.0)
			w.append(Campaign.pelikan())
			# PG-01 is built around a PL-MAG-01 from the armory
			Campaign.data["research"]["done"] += ["plazma", "plazma_granat"]
			Campaign.data["armory"].erase("plasma_cell")
			w.append(not Campaign.make("plasma_grenade"))
			Campaign.data["armory"]["plasma_cell"] = 1
			w.append(Campaign.make("plasma_grenade") and not Campaign.data["armory"].has("plasma_cell"))
			print("RESULT workshoptest %s" % " ".join(w.map(func(x): return "ok" if x else "NO")))
			get_tree().quit()
		"wrecks":
			# a Diskoll blown up on three won missions: the scraps make one whole for the laboratory
			Campaign.new_campaign()
			var res := []
			for i in 3:
				Campaign.mission_done(-1, true, 1, 0, 0, 0, 0, ["diskoll"], {"trosky_diskoll": 1})
				res.append([int(Campaign.data["found"].get("trosky_diskoll", 0)), int(Campaign.data["found"].get("corpse_diskoll", 0)),
					Campaign.research_available("rozbor_diskoll")])
			print("RESULT wrecks ", res, " ", Campaign.research_needs("rozbor_diskoll") if Campaign.has_method("research_needs") else "")
			get_tree().quit()
		"checkall":
			for f in DirAccess.get_files_at("res://scripts"):
				if f.ends_with(".gd"):
					print("[CHECK] ", f, " ", "ok" if load("res://scripts/" + f) != null else "FAIL")
			get_tree().quit()
		"econhost":
			Campaign.new_campaign()
			Campaign.data["found"] = {"a_pistol": 1}
			Campaign.data["moskovium"] = 40
			Game.merc["name"] = "Hostitel"
			Net.host(int(Game.cmd_arg("port", str(Net.PORT))))
			get_tree().change_scene_to_file("res://scenes/Geoscape.tscn")
		"econclient":
			Game.merc["name"] = "Klient"
			Game.merc["money"] = 1100
			await get_tree().create_timer(1.5).timeout
			Net.join("127.0.0.1", int(Game.cmd_arg("port", str(Net.PORT))))
			while not Campaign.viewer:
				await get_tree().create_timer(0.2).timeout
			print("[ECON] snapshot credits=%d my=%d wallets=%s stash_rifle=%d" % [int(Campaign.data["credits"]), Net.my_money(), Net.wallets, int(Game.stash_for(false).get("rifle", 0))])
			Net.buy_for_base("rifle")
			await get_tree().create_timer(2.5).timeout
			print("[ECON] after buy my=%d base rifles=%d" % [Net.my_money(), int(Campaign.data["armory"].get("rifle", 0))])
			Net.give_money(1, 200)
			await get_tree().create_timer(2.5).timeout
			print("[ECON] after gift my=%d wallets=%s" % [Net.my_money(), Net.wallets])
			# (0.7x) the armory basket: several things for the base in one request (300 kr: 2 clips + 1 grenade, 120 kr more than money left -> grenade 2 is not bought)
			var arm0 := int(Campaign.data["armory"].get("rifle_clip", 0)) + Campaign.on_order("rifle_clip")
			Net.buy_cart_for_base({"rifle_clip": 2, "grenade": 2})
			await get_tree().create_timer(2.5).timeout
			print("RESULT cart client my=%d clips +%d grenades on order %d" % [Net.my_money(), int(Campaign.data["armory"].get("rifle_clip", 0)) + Campaign.on_order("rifle_clip") - arm0, Campaign.on_order("grenade")])
			get_tree().change_scene_to_file("res://scenes/Geoscape.tscn")
		"stockhost", "stockclient":
			# (0.7x, Ari: co-op saw a different store) host and client must see the same armory
			Game.merc["name"] = "Hostitel" if Game.autotest() == "stockhost" else "Klient"
			if Game.autotest() == "stockhost":
				Campaign.new_campaign("normal")
				Net.host(int(Game.cmd_arg("port", str(Net.PORT))))
				while Net.roster.size() < 2:
					await get_tree().create_timer(0.2).timeout
			else:
				await get_tree().create_timer(1.0).timeout
				Net.join("127.0.0.1", int(Game.cmd_arg("port", str(Net.PORT))))
				while not Campaign.viewer:
					await get_tree().create_timer(0.2).timeout
			get_tree().change_scene_to_file("res://scenes/Geoscape.tscn")
		"readyhost", "gohost":
			Campaign.new_campaign("normal")
			Game.merc["name"] = "Hostitel"
			Net.host(int(Game.cmd_arg("port", str(Net.PORT))))
			while Net.roster.size() < 2:
				await get_tree().create_timer(0.2).timeout
			await get_tree().create_timer(1.0).timeout
			get_tree().change_scene_to_file("res://scenes/Geoscape.tscn")
		"readyclient", "goclient":
			Game.merc["name"] = "Klient"
			await get_tree().create_timer(1.0).timeout
			Net.join("127.0.0.1", int(Game.cmd_arg("port", str(Net.PORT))))
			while not Campaign.viewer:
				await get_tree().create_timer(0.2).timeout
			get_tree().change_scene_to_file("res://scenes/Geoscape.tscn")
		"geolivehost":
			# the host flies a transport on his globe; the client's globe must show it moving
			Campaign.new_campaign("normal")
			Game.merc["name"] = "Hostitel"
			Net.host(int(Game.cmd_arg("port", str(Net.PORT))))
			while Net.roster.size() < 2:
				await get_tree().create_timer(0.2).timeout
			await get_tree().create_timer(1.0).timeout
			var gm: Dictionary = Campaign.generate_mission()
			Campaign.data["missions"].append(gm)
			Campaign.launch_craft("kondor", gm, "mission")
			Net.broadcast_team()
			get_tree().change_scene_to_file("res://scenes/Geoscape.tscn")
		"geoliveclient":
			# (the measuring is done on the globe: geoscape.gd _autotest)
			Game.merc["name"] = "Klient"
			await get_tree().create_timer(1.0).timeout
			Net.join("127.0.0.1", int(Game.cmd_arg("port", str(Net.PORT))))
			while not Campaign.viewer:
				await get_tree().create_timer(0.2).timeout
			get_tree().change_scene_to_file("res://scenes/Geoscape.tscn")
		"coopevachost":
			# (0.69, Ari: crash flying home) a co-op campaign mission won, everybody at the Kondor:
			# the transport, then the host to the globe and the clients back to the lobby
			if Net.is_online():
				return
			Campaign.new_campaign("normal")
			for k in ["heal_days", "injury", "sick", "heal_cid", "heal_seen"]:
				Game.merc.erase(k)
			Game.merc["name"] = "Hostitel"
			Net.host(int(Game.cmd_arg("port", str(Net.PORT))))
			while Net.roster.size() < int(Game.cmd_arg("players", "2")):
				await get_tree().create_timer(0.2).timeout
			await get_tree().create_timer(1.0).timeout
			var me2: Dictionary = Campaign.generate_mission()
			me2["type"] = "crash"
			Campaign.data["missions"].append(me2)
			Net.start_mission(Campaign.mission_params(me2))
		"coopevacclient":
			if Net.is_online():
				print("[EVAC] client back in the menu, online")
				await get_tree().create_timer(3.0).timeout
				get_tree().quit()
				return
			for k in ["heal_days", "injury", "sick", "heal_cid", "heal_seen"]:
				Game.merc.erase(k)
			Game.merc["name"] = "Klient" + Game.cmd_arg("ci", "1")
			await get_tree().create_timer(1.0 + 0.5 * int(Game.cmd_arg("ci", "1"))).timeout
			Net.join("127.0.0.1", int(Game.cmd_arg("port", str(Net.PORT))))
		"coopwipehost":
			# co-op campaign mission that the team loses to the last man, then back to the globe
			Campaign.new_campaign("normal")
			for k in ["heal_days", "injury", "sick", "heal_cid", "heal_seen"]:
				Game.merc.erase(k)
			Game.merc["name"] = "Hostitel"
			Net.host(int(Game.cmd_arg("port", str(Net.PORT))))
			while Net.roster.size() < 2:
				await get_tree().create_timer(0.2).timeout
			await get_tree().create_timer(1.0).timeout
			var mm: Dictionary = Campaign.generate_mission()
			mm["type"] = "crash"
			Campaign.data["missions"].append(mm)
			print("[WIPE] host starts %s" % mm["type"])
			Net.start_mission(Campaign.mission_params(mm))
		"coopwipeclient":
			for k in ["heal_days", "injury", "sick", "heal_cid", "heal_seen"]:
				Game.merc.erase(k)
			Game.merc["name"] = "Klient"
			await get_tree().create_timer(1.0).timeout
			Net.join("127.0.0.1", int(Game.cmd_arg("port", str(Net.PORT))))
		"lbhost":
			# a campaign host; the client goes down to the base alone, then the host starts a mission
			Campaign.new_campaign("normal")
			Game.merc["name"] = "Hostitel"
			Net.host(int(Game.cmd_arg("port", str(Net.PORT))))
			while Net.roster.size() < 2:
				await get_tree().create_timer(0.2).timeout
			await get_tree().create_timer(9.0).timeout
			if Game.cmd_arg("nade", "") == "1":
				await get_tree().create_timer(30.0).timeout     # (the client throws grenades in its base meanwhile)
				get_tree().quit()
				return
			print("[LB] host starts the mission")
			Net.start_mission({"type": "crash", "biome": "farm", "night": false, "hour": 14.0, "place": "Test", "type_name": "Test", "id": -1})
		"hbhost":
			# (0.7x) the HOST goes down to the base alone; the client stays on the globe and sees the
			# campaign go on; then the host comes up and starts a drop - it pulls the client in
			Campaign.new_campaign("normal")
			Game.merc["name"] = "Hostitel"
			Net.host(int(Game.cmd_arg("port", str(Net.PORT))))
			while Net.roster.size() < 2:
				await get_tree().create_timer(0.2).timeout
			await get_tree().create_timer(3.0).timeout
			print("[HB] host goes down to the base alone")
			Net.start_local_base({"type": "home", "type_name": "Základna", "base": Campaign.data["base"].duplicate(true), "grid_w": Campaign.GRID_W, "grid_h": Campaign.GRID_H, "transport": "heli", "live": [], "research": [], "night": false, "hour": 12.0, "blips": []})
		"hbclient":
			Game.merc["name"] = "Klient"
			await get_tree().create_timer(1.0).timeout
			Net.join("127.0.0.1", int(Game.cmd_arg("port", str(Net.PORT))))
			while not Campaign.viewer:
				await get_tree().create_timer(0.2).timeout
			get_tree().change_scene_to_file("res://scenes/Geoscape.tscn")
		"lbclient":
			Game.merc["name"] = "Klient"
			await get_tree().create_timer(1.0).timeout
			Net.join("127.0.0.1", int(Game.cmd_arg("port", str(Net.PORT))))
			while not Campaign.viewer:
				await get_tree().create_timer(0.2).timeout
			await get_tree().create_timer(1.0).timeout
			print("[LB] client goes down to the base alone")
			Net.start_local_base({"type": "home", "type_name": "Základna", "base": Campaign.data["base"].duplicate(true), "grid_w": Campaign.GRID_W, "grid_h": Campaign.GRID_H, "transport": "heli", "live": [], "research": [], "night": false, "hour": 12.0, "blips": []})
		"coophealhost", "aimphost", "safeouthost", "hullhost", "pothost", "leakhost":
			if Game.autotest() == "aimphost":
				Game.seed_override = int(Game.cmd_arg("seed", "4242"))     # (the same map for the old and the new AI)
			Net.host(int(Game.cmd_arg("port", str(Net.PORT))))
			while Net.roster.size() < int(Game.cmd_arg("players", "2")):
				await get_tree().create_timer(0.2).timeout
			await get_tree().create_timer(0.5).timeout
			var mp := {"type": Game.cmd_arg("mtype", "crash"), "biome": Game.cmd_arg("biome", "farm"), "night": false, "hour": 14.0, "place": "Test", "type_name": "Test", "id": -1, "ufo": Game.cmd_arg("ufo", "raider" if Game.autotest() == "hullhost" else ""), "size": Game.cmd_arg("size", "medium")}
			if Game.autotest() == "pothost":
				mp["cid"] = "pottest"      # (0.70: the pay is counted only in a campaign mission)
				mp["reward"] = 200
			Net.start_mission(mp)
		"coophealclient", "aimpclient", "safeoutclient", "hullclient", "potclient", "leakclient":
			Game.merc["name"] = "Klient" if Game.cmd_arg("ci", "1") == "1" else "Klient" + Game.cmd_arg("ci", "1")
			await get_tree().create_timer(1.0 + 0.5 * int(Game.cmd_arg("ci", "1"))).timeout
			Net.join("127.0.0.1", int(Game.cmd_arg("port", str(Net.PORT))))
		"nadehost", "flarehost":
			# (Ari 2026-11-10) the whole team in the base together, grenades in the velín
			Net.host(int(Game.cmd_arg("port", str(Net.PORT))))
			while Net.roster.size() < 2:
				await get_tree().create_timer(0.2).timeout
			await get_tree().create_timer(0.5).timeout
			var b := []
			for i in 24:
				b.append({"type": "", "days": 0.0})
			for k in {0: "velin", 1: "hangar", 6: "ubikace", 7: "laborator", 2: "dilna"}:
				b[k] = {"type": {0: "velin", 1: "hangar", 6: "ubikace", 7: "laborator", 2: "dilna"}[k], "days": 0.0}
			Net.start_mission({"type": "home", "type_name": "Základna", "base": b, "grid_w": 6, "grid_h": 4, "transport": "heli",
				"live": [], "research": [], "night": false, "hour": 12.0, "blips": []})
		"nmradarhost", "nmbughost":
			# (0.7x nové mise) the host's objectives reach the client (rpc _power_on / _bug_placed / _bug_lift)
			Net.host(int(Game.cmd_arg("port", str(Net.PORT))))
			while Net.roster.size() < 2:
				await get_tree().create_timer(0.2).timeout
			await get_tree().create_timer(0.5).timeout
			var rad := Game.autotest() == "nmradarhost"
			Net.start_mission({"type": "radar" if rad else "bug", "type_name": "Test", "place": "Test", "biome": "base" if rad else "forest", "size": "large" if rad else "medium",
				"ufo": "raider", "crew_of": "raider", "extra_aliens": 1, "id": -1, "night": true, "hour": 23.0})
		"nadeclient", "flareclient", "nmradarclient", "nmbugclient":
			Game.merc["name"] = "Klient"
			await get_tree().create_timer(1.0).timeout
			Net.join("127.0.0.1", int(Game.cmd_arg("port", str(Net.PORT))))
		"host":
			Game.seed_override = 4242
			Net.host(int(Game.cmd_arg("port", str(Net.PORT))))
			while Net.roster.size() < 2:
				await get_tree().create_timer(0.2).timeout
			await get_tree().create_timer(0.5).timeout
			Net.start_mission()
		"client":
			Game.merc["name"] = "Klient"
			await get_tree().create_timer(1.0).timeout
			Net.join("127.0.0.1", int(Game.cmd_arg("port", str(Net.PORT))))

## (0.70) --autotest=wallshot --fallen=N: made-up fallen for the wall in the velín (only the test).
func _test_fallen(n: int) -> Array:
	var names := ["Jan Novák", "Petra Dvořáková", "Mike O'Hara", "Lukas Brandt", "Anna Kowalska", "Pierre Lefèvre", "Giulia Rossi", "Sven Lindqvist"]
	var flags := ["cz", "sk", "ie", "de", "pl", "fr", "it", ""]
	var out := []
	for i in n:
		out.append({"n": names[i % names.size()] + ("" if i < names.size() else " ml."), "f": flags[i % flags.size()], "d": "%d. května 1990" % (3 + i),
			"m": ["Havárie UFO - Brno", "Teror - Lyon", "Přistání UFO - Kerry"][i % 3], "k": i % 5, "mia": i % 4 == 3})
	return out
