extends Control
const MapGen := preload("res://scripts/map_gen.gd")
## Main menu in the spirit of UFO's screens: dark blue panels, light frames.

const BG := Color(0.04, 0.045, 0.05)
const PANEL := Color(0.10, 0.115, 0.13)
const FRAME := Color(0.45, 0.78, 0.86)
const TEXT := Color(0.84, 0.89, 0.92)
const ACCENT := Color(1.0, 0.74, 0.32)

var _box: VBoxContainer
var _confirm_new := false
var _confirm_fire := false
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
		Game.load_scene("res://scenes/Geoscape.tscn")
	elif _back_target == "quick":
		_back_target = ""
		_show_quick()
	elif _back_target == "campaign":
		_back_target = ""
		_show_campaign()
	else:
		_show_main()

# ---- helpers -----------------------------------------------------------------
## The game's name on a steel nameplate at the left, with the version and a blinking terminal line.
func _build_logo() -> void:
	var holder := Control.new()      # not a PanelContainer: screens clear those
	holder.name = "Logo"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UiSkin.inset(6))
	plate.position = Vector2(10, 10)
	plate.custom_minimum_size = Vector2(150, 0)
	holder.add_child(plate)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	plate.add_child(v)
	for e in [["OPERACE", 20, UiSkin.TEXT], ["X", 34, UiSkin.AMBER], ["ENEMY BEYOND", 10, UiSkin.DIM]]:
		var l := Label.new()
		l.text = e[0]
		l.add_theme_font_override("font", UiSkin.font(true))
		l.add_theme_font_size_override("font_size", e[1])
		l.add_theme_color_override("font_color", e[2])
		l.add_theme_constant_override("line_spacing", -4)
		v.add_child(l)
	var line := ColorRect.new()
	line.color = UiSkin.GLOW
	line.custom_minimum_size = Vector2(0, 1)
	v.add_child(line)
	var sub := Label.new()
	sub.text = "TERMINÁL X-NET  v" + Game.VERSION_NUM
	sub.add_theme_font_size_override("font_size", 7)
	sub.add_theme_color_override("font_color", UiSkin.GLOW)
	v.add_child(sub)
	var cur := Label.new()
	cur.add_theme_font_size_override("font_size", 7)
	cur.add_theme_color_override("font_color", UiSkin.DIM)
	v.add_child(cur)
	var tw := cur.create_tween().set_loops()
	tw.tween_callback(func(): cur.text = "> SPOJENÍ NAVÁZÁNO _")
	tw.tween_interval(0.6)
	tw.tween_callback(func(): cur.text = "> SPOJENÍ NAVÁZÁNO")
	tw.tween_interval(0.6)


## The full-width screens (soldiers, recruiting, upgrades) cover the logo; the small ones show it.
const TITLE_PIC := "res://assets/ui/titulni_obrazovka.png"
var _title: TextureRect
var _title_mode := false        # the main screen: the picture in full, the buttons in a row under the logo

func _logo(on: bool) -> void:
	var l := get_node_or_null("Logo")
	if l:
		l.visible = on

func _panel(title: String) -> void:
	_logo(true)
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
	t.text = title
	UiSkin.title(t, 15)
	_box.add_child(t)
	_status = null

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
	UiSkin.button(b)
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
	_button("Výstroj (celý arzenál)", func(): _back_target = "quick"; _show_loadout())
	_button("HRÁT SÁM", func():
		Campaign.active = false
		Game.begin_skirmish(quick_merc)
		Net.play_solo()
		Net.start_mission(quick_params(quick_pick)))
	_button("Hostovat pro kamarády (2-4 hráči)", func():
		Campaign.active = false
		Game.begin_skirmish(quick_merc)
		_host())
	_button("Připojit se ke hře", _show_join)
	_button("Zpět", _show_main)

func _show_main(msg := "") -> void:
	Game.end_skirmish()
	_panel("OPERACE X - Enemy Beyond")
	_label("Pocta UFO: Enemy Unknown  -  %s" % Game.VERSION, FRAME, 9).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# started straight from the zip (Windows unpacks it into a temporary folder):
	# settings, updates and the microphone may not work - say so
	var exe := OS.get_executable_path().to_lower()
	if not OS.has_feature("editor") and (exe.contains("\\temp\\") or exe.contains("/temp/") or exe.contains(".zip")):
		var w := _label("Hra běží přímo ze zipu. Nejdřív zip rozbal (pravé tlačítko > Extrahovat vše) a spusť EnemyBeyond.exe z rozbalené složky, jinak nemusí fungovat mikrofon, nastavení ani aktualizace.", Color(1, 0.45, 0.35), 9)
		w.custom_minimum_size = Vector2(300, 0)
	_upd_label = _label("", ACCENT, 9)
	_upd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_upd_label.custom_minimum_size = Vector2(300, 0)
	if Game.crash_note != "":
		# (0.57) the game went down mid-mission last time: say once what it cost
		var cn := _label(Game.crash_note, Color(1, 0.45, 0.35), 9)
		cn.custom_minimum_size = Vector2(300, 0)
		Game.crash_note = ""
	_upd_btn = _button("Restartovat a hrát novou verzi", func(): Game.restart_game())
	_upd_refresh()
	# with the title picture: its logo stays free, the buttons go in a row at the bottom
	var first := _box.get_child_count()
	_button("KAMPAŇ", _show_campaign)
	_button("Rychlá mise", _show_quick)
	_button("Novinky", _show_news)
	if INTRO_ON:
		_button("Úvod", _play_intro)
	_button("Nastavení", _show_settings)
	if OS.has_feature("editor"):
		_button("Editor", _show_editor)
	_button("Ukončit", func(): get_tree().quit())
	if _title:
		_title_mode = true
		_title.modulate = Color(1, 1, 1)
		_logo(false)
		(_box.get_child(0) as Control).visible = false       # (the picture has the name)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 4)
		var btns := _box.get_children().slice(first)
		_box.add_child(row)
		_box.move_child(row, first)
		for bt in btns:
			_box.remove_child(bt)
			row.add_child(bt)
			(bt as Button).custom_minimum_size.x = 84
	if msg != "":
		_label(msg, Color(1, 0.5, 0.4), 10)

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
	if not Game.merc.get("created", true):
		_label("Nemáš vlastního vojáka - vytvoř si ho v \"Moji vojáci\".", Color(1.0, 0.75, 0.4), 9)
	_label("Vojáci rostou jen v kampani: mise, žold, zranění i smrt. Co-op kampaň si pamatuje hostitel - hraje se s jeho záznamem o každém vojákovi.", FRAME, 8).custom_minimum_size = Vector2(300, 0)
	_button("Zpět", _show_main)
	if msg != "":
		_label(msg, Color(1, 0.5, 0.4), 10)

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
	_label(info[_new_diff], Color(1, 0.55, 0.4) if _new_diff == "veteran" else TEXT, 8).custom_minimum_size = Vector2(300, 0)
	if Campaign.has_save():
		_label("Pozor: stará kampaň bude přepsána.", Color(1, 0.5, 0.4), 9)
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
	_logo(false)
	_free_preview()
	for c in get_children():
		if c is PanelContainer:
			c.queue_free()
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiSkin.panel(8))
	p.position = Vector2(8, 4)
	p.custom_minimum_size = Vector2(624, 352)
	add_child(p)
	_cr_ui = p
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	p.add_child(row)
	var m: Dictionary = Game.merc
	# ---- left: the soldier, turning slowly, and the roster
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(210, 0)
	left.add_theme_constant_override("separation", 2)
	row.add_child(left)
	var title := Label.new()
	title.text = "VOJÁCI"
	title.add_theme_color_override("font_color", ACCENT)
	title.add_theme_font_size_override("font_size", 13)
	left.add_child(title)
	_cr = {"look": (m.get("look", {}) as Dictionary).duplicate(true)}
	_build_preview(left, false)
	var hint := Label.new()
	hint.text = "Na misi jde voják označený ►"
	hint.add_theme_font_size_override("font_size", 7)
	hint.add_theme_color_override("font_color", FRAME)
	left.add_child(hint)
	for i in Game.MERC_SLOTS:
		var k := i
		if i < Game.mercs.size():
			var mm: Dictionary = Game.mercs[i]
			var sick := Game.heal_days_left(mm) > 0.0
			var b := _small_btn(left, "%s%s  -  %s%s" % ["► " if i == Game.active else "", str(mm.get("name", "?")), Game.RANKS[Game.rank_of(mm)], "  (marodka)" if sick else ""], func():
				Game.switch_merc(k)
				_confirm_fire = false
				_show_merc())
			b.custom_minimum_size = Vector2(210, 18)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			if sick:
				b.add_theme_color_override("font_color", Color(1, 0.5, 0.4))
			if i == Game.active:
				b.add_theme_color_override("font_color", ACCENT)
		else:
			var nb := _small_btn(left, "+  Naverbovat vojáka", func():
				var n := Game.hire_merc()
				if n >= 0:
					Game.switch_merc(n)
				_show_create(true))
			nb.custom_minimum_size = Vector2(210, 18)
			nb.alignment = HORIZONTAL_ALIGNMENT_LEFT
			nb.add_theme_color_override("font_color", FRAME)
	# ---- right: the record
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(390, 0)
	right.add_theme_constant_override("separation", 3)
	row.add_child(right)
	var name_edit := LineEdit.new()
	name_edit.text = m["name"]
	name_edit.add_theme_font_size_override("font_size", 11)
	name_edit.text_changed.connect(func(t): Game.merc["name"] = t; Game.save_merc())
	right.add_child(name_edit)
	if not m.get("created", true):
		var cb := _small_btn(right, "Tenhle voják ještě nemá vlastnosti ani vzhled - naverbovat", func(): _show_create(true))
		cb.custom_minimum_size = Vector2(0, 18)
	var xp := int(m.get("xp", 0))
	var rk := Game.rank_of(m)
	var nxt := "" if rk + 1 >= Game.RANK_XP.size() else " / %d" % Game.RANK_XP[rk + 1]
	_rlabel(right, "%s   ·   zkušenosti %d%s   ·   mise %d, zabití %d" % [Game.RANKS[rk].to_upper(), xp, nxt, int(m.get("missions", 0)), int(m.get("kills", 0))], ACCENT, 9)
	if Game.heal_days_left(m) > 0.0:
		_rlabel(right, "%s - chybí mu %d zdraví. Na misi nemůže, dokud se v kampani neuzdraví." % [Game.sick_text(m), ceili(float(m.get("injury", 0)))], Color(1, 0.5, 0.4), 8)
	for st in Game.STAT_ORDER:
		var key: String = st
		var srow := HBoxContainer.new()
		srow.add_theme_constant_override("separation", 4)
		right.add_child(srow)
		var nm := Label.new()
		nm.text = Game.STAT_NAMES[key]
		nm.custom_minimum_size = Vector2(62, 0)
		nm.add_theme_font_size_override("font_size", 9)
		nm.add_theme_color_override("font_color", ACCENT)
		srow.add_child(nm)
		var lvl := int(m.get("levels", {}).get(key, 5))
		var bar := Label.new()
		bar.text = "■".repeat(lvl) + "□".repeat(Game.LEVEL_MAX - lvl)
		bar.add_theme_font_size_override("font_size", 9)
		bar.add_theme_color_override("font_color", TEXT)
		srow.add_child(bar)
		var val := Label.new()
		val.text = "  %d" % int(m.get(key, 0))
		val.add_theme_font_size_override("font_size", 9)
		val.add_theme_color_override("font_color", Color(1, 1, 1))
		srow.add_child(val)
	var tl := []
	for t in m.get("talents", []):
		tl.append(Game.TALENTS[Game.TALENT_NEW.get(t, t)][0])
	_rlabel(right, "Talenty: " + (", ".join(tl) if not tl.is_empty() else "zatím žádné"), TEXT, 8)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(spacer)
	# (0.62) the soldier's own things together: his talents and the parts on his guns
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 4)
	right.add_child(trow)
	var tb := _small_btn(trow, "Talenty" + (" (volné body: %d)" % int(m.get("talent_points", 0)) if int(m.get("talent_points", 0)) > 0 else ""), _show_talents)
	tb.custom_minimum_size = Vector2(150, 18)
	if int(m.get("talent_points", 0)) > 0:
		tb.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	_small_btn(trow, "Úpravy zbraní", func(): _mods_from = "merc"; _show_mods()).custom_minimum_size = Vector2(150, 18)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 4)
	right.add_child(brow)
	_small_btn(brow, "Upravit vzhled", func(): _show_create(false)).custom_minimum_size = Vector2(96, 18)
	if Game.mercs.size() > 1:
		var fb := _small_btn(brow, "Propustit" if not _confirm_fire else "OPRAVDU propustit?", func():
			if not _confirm_fire:
				_confirm_fire = true
				_show_merc()
				return
			_confirm_fire = false
			Game.dismiss_merc(Game.active)
			_show_merc())
		fb.custom_minimum_size = Vector2(96, 18)
		if _confirm_fire:
			fb.add_theme_color_override("font_color", Color(1, 0.5, 0.4))
	else:
		_small_btn(brow, "Nahradit novým", func(): _show_create(true)).custom_minimum_size = Vector2(96, 18)
	_small_btn(brow, "Zpět", _back).custom_minimum_size = Vector2(80, 18)

## 0.62 (Ari): the talent tree, next to the soldiers and their weapon parts. Four branches of five,
## all of it shown (what is owned, what can be taken now, what waits for a rank); a promotion gives
## one point, a talent is taken for good (two clicks). Easy difficulty: the drone instead of Šestý smysl.
var _talent_arm := ""
var _talent_info: Label
func _show_talents() -> void:
	_logo(false)
	_free_preview()
	for c in get_children():
		if c is PanelContainer:
			c.queue_free()
	var m: Dictionary = Game.merc
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiSkin.panel(8))
	p.position = Vector2(8, 4)
	p.custom_minimum_size = Vector2(624, 352)
	add_child(p)
	_cr_ui = p
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	p.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	col.add_child(head)
	var title := Label.new()
	title.text = "TALENTY"
	title.add_theme_color_override("font_color", ACCENT)
	title.add_theme_font_size_override("font_size", 13)
	head.add_child(title)
	var pts := int(m.get("talent_points", 0))
	var who := Label.new()
	who.text = "%s  -  %s   ·   volné body: %d" % [str(m.get("name", "?")), Game.RANKS[Game.rank_of(m)], pts]
	who.add_theme_font_size_override("font_size", 9)
	who.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6) if pts > 0 else TEXT)
	head.add_child(who)
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 6)
	col.add_child(grid)
	for b in Game.TALENT_TREE.size():
		var bi: int = b
		var branch := VBoxContainer.new()
		branch.add_theme_constant_override("separation", 3)
		branch.custom_minimum_size = Vector2(148, 0)
		grid.add_child(branch)
		var bn := Label.new()
		bn.text = String(Game.TALENT_TREE[b][0]).to_upper()
		bn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bn.add_theme_font_size_override("font_size", 10)
		bn.add_theme_color_override("font_color", FRAME)
		branch.add_child(bn)
		for t in 5:
			var ti: int = t
			var id := Game.tree_talent(b, t, m)
			var st := Game.talent_state(m, b, t)
			var sub: String = {"owned": "MÁŠ", "open": "vzít (klikni)", "nopoint": "chybí bod za povýšení",
				"rank": "od hodnosti %s" % Game.RANKS[Game.TREE_RANK[t]], "locked": "po talentu nad ním, od: %s" % Game.RANKS[Game.TREE_RANK[t]]}[st]
			if st == "open" and _talent_arm == id:
				sub = "OPRAVDU? Klikni znovu"
			var tb := _small_btn(branch, "%d. %s\n%s" % [t + 1, Game.TALENTS[id][0], sub], func():
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
			tb.custom_minimum_size = Vector2(148, 44)
			tb.add_theme_color_override("font_color", {"owned": Color(0.45, 1.0, 0.5), "open": ACCENT,
				"nopoint": TEXT, "rank": Color(0.55, 0.6, 0.65), "locked": Color(0.4, 0.43, 0.46)}[st])
			tb.mouse_entered.connect(func(): _talent_hint(id))
	_talent_info = Label.new()
	_talent_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	_talent_info.custom_minimum_size = Vector2(600, 40)
	_talent_info.add_theme_font_size_override("font_size", 9)
	_talent_info.add_theme_color_override("font_color", TEXT)
	_talent_info.text = "Za každé povýšení dostaneš bod. Talent ve větvi jde vzít, když máš ten nad ním a dost vysokou hodnost. Vybraný talent už nejde vrátit."
	col.add_child(_talent_info)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 4)
	col.add_child(brow)
	_small_btn(brow, "Úpravy zbraní", func(): _talent_arm = ""; _mods_from = "talents"; _show_mods()).custom_minimum_size = Vector2(96, 18)
	_small_btn(brow, "Zpět k vojákům", func(): _talent_arm = ""; _show_merc()).custom_minimum_size = Vector2(110, 18)

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
	_logo(false)
	_free_preview()
	for c in get_children():
		if c is PanelContainer:
			c.queue_free()
	if _mods_sel == "" or not Game.MOD_FITS.has(_mods_sel):
		_mods_sel = "rifle" if Game.MOD_FITS.has("rifle") else String(Game.MOD_FITS.keys()[0])
	var wsel := _mods_sel
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiSkin.panel(8))
	p.position = Vector2(8, 4)
	p.custom_minimum_size = Vector2(624, 352)
	add_child(p)
	_cr_ui = p
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	p.add_child(row)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(160, 0)
	left.add_theme_constant_override("separation", 2)
	row.add_child(left)
	var title := Label.new()
	title.text = "ÚPRAVY ZBRANÍ"
	title.add_theme_color_override("font_color", ACCENT)
	title.add_theme_font_size_override("font_size", 13)
	left.add_child(title)
	var money := Label.new()
	money.text = "Peníze: %d kr" % Game.purse()
	money.add_theme_font_size_override("font_size", 9)
	money.add_theme_color_override("font_color", TEXT)
	left.add_child(money)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(160, 300)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(sc)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	sc.add_child(list)
	for w in Game.MOD_FITS:
		var wid: String = w
		var on := 0
		for s in Game.fitted(wid):
			if not Game.MODS[Game.fitted(wid)[s]].get("stock", false):
				on += 1
		var b := _small_btn(list, "%s%s" % [Game.ITEMS[wid]["short"], ("   +%d" % on) if on > 0 else ""], func(): _mods_sel = wid; _show_mods())
		b.custom_minimum_size = Vector2(150, 22)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.tooltip_text = String(Game.ITEMS[wid]["name"])
		UiSkin.item_icon(b, wid, 34)
		if wid == wsel:
			b.add_theme_color_override("font_color", ACCENT)
	# right: the chosen gun
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(440, 0)
	right.add_theme_constant_override("separation", 3)
	row.add_child(right)
	var wn := Label.new()
	wn.text = String(Game.ITEMS[wsel]["name"]).to_upper()
	wn.add_theme_font_override("font", UiSkin.font(true))
	wn.add_theme_font_size_override("font_size", 12)
	wn.add_theme_color_override("font_color", ACCENT)
	right.add_child(wn)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	right.add_child(top)
	_gun_preview(top, wsel)
	var stats := Label.new()
	stats.text = _mods_stats(wsel)
	stats.add_theme_font_size_override("font_size", 8)
	stats.add_theme_color_override("font_color", TEXT)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD
	stats.custom_minimum_size = Vector2(150, 0)
	top.add_child(stats)
	# the slots, one row each: what fits there (mounted / in the box / for sale)
	var sc2 := ScrollContainer.new()
	sc2.custom_minimum_size = Vector2(440, 118)
	sc2.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(sc2)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 2)
	sc2.add_child(rows)
	var slots := []
	for m in Game.MOD_FITS[wsel]:
		var sl := Game.mod_slot(m)
		if not sl in slots:
			slots.append(sl)
	var fit := Game.fitted(wsel)
	for sl in slots:
		var slot: String = sl
		var r2 := HBoxContainer.new()
		r2.add_theme_constant_override("separation", 3)
		rows.add_child(r2)
		var opts := []
		for m in Game.MOD_FITS[wsel]:
			if Game.mod_slot(m) == slot:
				opts.append(m)
		var sn := Label.new()
		sn.text = String(Game.MOD_SLOTS.get(slot, "Doplněk"))
		sn.custom_minimum_size = Vector2(66, 0)
		sn.add_theme_font_size_override("font_size", 8)
		sn.add_theme_color_override("font_color", FRAME)
		r2.add_child(sn)
		var has_stock := false
		for m in opts:
			if Game.MODS[m].get("stock", false):
				has_stock = true
		if not has_stock:
			var nb := _small_btn(r2, "nic", func():
				Game.unmount_slot(wsel, slot)
				_show_mods())
			nb.custom_minimum_size = Vector2(30, 18)
			if not fit.has(slot):
				nb.add_theme_color_override("font_color", Color(0.45, 0.95, 0.75))
			nb.mouse_entered.connect(func(): _mods_hint("Nic v tomhle místě: zbraň je lehčí, nic tu nepřekáží."))
		for m in opts:
			var mid: String = m
			var on: bool = fit.get(slot, "") == mid
			var own := Game.owns_mod(wsel, mid)
			var price := Game.mod_price(mid)
			var txt := String(Game.MODS[mid]["name"])
			if on:
				txt = "✓ " + txt
			elif not own:
				txt += "  %d kr" % price
			var bb := _small_btn(r2, txt, func():
				if on:
					Game.unmount_slot(wsel, slot)
				elif own:
					Game.mount_mod(wsel, mid)
				elif not Game.buy_mod(wsel, mid):
					_show_main_msg("Nemáš dost peněz.")
					return
				_show_mods())
			bb.custom_minimum_size = Vector2(0, 18)
			if on:
				bb.add_theme_color_override("font_color", Color(0.45, 0.95, 0.75))
			elif own:
				bb.add_theme_color_override("font_color", TEXT)
			else:
				bb.add_theme_color_override("font_color", ACCENT)
				bb.disabled = Game.purse() < price
			var how := "Klikni a sundáš." if on and not Game.MODS[mid].get("stock", false) else ("Nasazeno." if on else ("Máš v bedně: klikni a namontuješ (zdarma)." if own else "Koupit za %d kr a hned namontovat." % price))
			bb.mouse_entered.connect(func(): _mods_hint("%s - %s\n%s  %s" % [Game.MODS[mid]["name"], Game.MODS[mid]["desc"], _part_effects(mid), how]))
	var info := Label.new()
	info.text = "Najeď na díl: co umí a co tě stojí. Úpravy patří tvému vojákovi a fungují, kdykoli tu zbraň drží."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.custom_minimum_size = Vector2(440, 40)
	info.add_theme_font_size_override("font_size", 8)
	info.add_theme_color_override("font_color", TEXT)
	right.add_child(info)
	_mods_info = info
	var back := _small_btn(right, "Zpět", func():
		# 0.66: one level up - to the screen it was opened from (the soldier, the kit), else where we came from
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
			_show_merc())
	back.custom_minimum_size = Vector2(80, 18)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

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
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.07, 0.12)
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
	tr.custom_minimum_size = Vector2(280, 120)
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
		"downloading": t = "Stahuji verzi %s... %d %%" % [Game.upd_version, int(Game.update_progress() * 100)]
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
var _cr_rolls := 3
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
		_cr_mode = "points"
		_cr_rolls = 3
		_cr_auto_name = true
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

func _build_create() -> void:
	_logo(false)
	_free_preview()
	for c in get_children():
		if c is PanelContainer:
			c.queue_free()
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiSkin.panel(8))
	p.position = Vector2(8, 4)
	p.custom_minimum_size = Vector2(624, 352)
	add_child(p)
	_cr_ui = p
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	p.add_child(row)
	# ---- left: the merc, turning slowly, and the looks
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(210, 0)
	left.add_theme_constant_override("separation", 2)
	row.add_child(left)
	var title := Label.new()
	title.text = "NOVÝ VOJÁK" if _cr_full else "VZHLED VOJÁKA"
	title.add_theme_color_override("font_color", ACCENT)
	title.add_theme_font_size_override("font_size", 13)
	left.add_child(title)
	_build_preview(left)
	var look: Dictionary = _cr["look"]
	# 0.57 facelift: the looks in three tabs (face / clothes / trinkets) - the column would not fit otherwise
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 2)
	left.add_child(tabs)
	for t in [[0, "Tvář"], [1, "Oblečení"], [2, "Doplňky"]]:
		var tb := _small_btn(tabs, ("● " if _cr_tab == t[0] else "") + str(t[1]), func(): _cr_tab = t[0]; _build_create())
		tb.custom_minimum_size = Vector2(68, 0)
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
	# ---- right: name, stats, the finish
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 2)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var nrow := HBoxContainer.new()
	right.add_child(nrow)
	var ne := LineEdit.new()
	ne.text = _cr["name"]
	ne.custom_minimum_size = Vector2(270, 0)
	ne.add_theme_font_size_override("font_size", 10)
	ne.text_changed.connect(func(t): _cr["name"] = t; _cr_auto_name = false)
	nrow.add_child(ne)
	var rn := _small_btn(nrow, "Náhodné jméno", func():
		var r := RandomNumberGenerator.new(); r.randomize()
		_cr["name"] = Game.random_name(_cr["look"].get("female", false), r)
		_cr_auto_name = true
		_build_create())
	rn.custom_minimum_size = Vector2(90, 0)
	if _cr_presets:
		_build_merc_presets(right)
	else:
		_build_stats(right)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 6)
	right.add_child(brow)
	var ok := _small_btn(brow, "NAVERBOVAT" if _cr_full else "ULOŽIT VZHLED", func():
		_cr["created"] = true
		if _cr_full:
			_cr["made"] = _cr_mode      # 0.60: a template keeps the levels only of a points-made soldier
			_cr["money"] = int(Game.merc.get("money", 0))
			Game.merc = _cr
		else:
			Game.merc["look"] = _cr["look"]
			Game.merc["name"] = _cr["name"]
		Game.save_merc()
		Net.reregister()
		_show_merc())
	ok.custom_minimum_size = Vector2(150, 18)
	if _cr_full:
		var used3 := 0
		for st in Game.STAT_ORDER:
			used3 += int(_cr["levels"][st])
		ok.disabled = _cr_mode == "points" and used3 < Game.LEVEL_POOL
		if ok.disabled:
			ok.tooltip_text = "Nejdřív rozděl všechny body."
	var pb := _small_btn(brow, ("● " if _cr_presets else "") + "Šablony (%d)" % Game.presets("merc").size(), func(): _cr_presets = not _cr_presets; _cr_note = ""; _build_create())
	pb.custom_minimum_size = Vector2(90, 18)
	_small_btn(brow, "Zpět", _create_back).custom_minimum_size = Vector2(80, 18)

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
	_rlabel(right, "ŠABLONY VOJÁKŮ", ACCENT, 10)
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
		lb.custom_minimum_size = Vector2(330, 16)
		lb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var db := _small_btn(prow, "×", func(): Game.delete_preset("merc", k); _cr_note = ""; _build_create())
		db.custom_minimum_size = Vector2(22, 16)
		db.tooltip_text = "Smazat šablonu"
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 3)
	right.add_child(srow)
	var le := LineEdit.new()
	le.text = Game.preset_label("merc", String(_cr.get("name", "Voják")))
	le.custom_minimum_size = Vector2(200, 0)
	le.add_theme_font_size_override("font_size", 9)
	srow.add_child(le)
	var points := _cr_mode == "points" if _cr_full else String(_cr.get("made", "")) == "points"
	var sb := _small_btn(srow, "Uložit tohoto vojáka", func():
		var lbl := le.text.strip_edges()
		if lbl == "":
			lbl = Game.preset_label("merc", String(_cr.get("name", "Voják")))
		if Game.save_preset("merc", lbl, Game.merc_preset(_cr, points)):
			_cr_note = "Uloženo: " + lbl + ("" if points else " (bez bodů)")
		else:
			_cr_note = "Plno (%d šablon) - nejdřív nějakou smaž." % Game.PRESET_MAX
		_build_create())
	sb.custom_minimum_size = Vector2(130, 16)
	if _cr_note != "":
		_rlabel(right, _cr_note, Color(0.6, 1.0, 0.6), 8)

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
		var mrow := HBoxContainer.new()
		right.add_child(mrow)
		var bp := _small_btn(mrow, ("● " if _cr_mode == "points" else "") + "Rozdělit body", func():
			_cr_mode = "points"
			var lv := {}
			for st in Game.STAT_ORDER:
				lv[st] = 5
			Game.set_levels(_cr, lv)
			_build_create())
		bp.custom_minimum_size = Vector2(130, 0)
		var bd := _small_btn(mrow, ("● " if _cr_mode == "dice" else "") + "Hodit kostkami (zbývá %d)" % _cr_rolls, func():
			if _cr_rolls <= 0:
				return
			_cr_rolls -= 1
			_cr_mode = "dice"
			var r := RandomNumberGenerator.new(); r.randomize()
			Game.set_levels(_cr, Game.roll_levels(r))
			_build_create())
		bd.custom_minimum_size = Vector2(170, 0)
		bd.disabled = _cr_rolls <= 0
		var used := 0
		for st in Game.STAT_ORDER:
			used += int(_cr["levels"][st])
		var info := "Body: rozdej %d bodů mezi vlastnosti (0-10 každá). Zbývá: %d" % [Game.LEVEL_POOL, Game.LEVEL_POOL - used] if _cr_mode == "points" \
			else "Kostky: každá vlastnost 2k6-2 (0-10, nejčastěji 5). Součet: %d (průměr 30). Hod nejde upravit - jen hodit znovu." % used
		_rlabel(right, info, Color(0.6, 1.0, 0.6), 8)
	for st in Game.STAT_ORDER:
		var key: String = st
		var srow := HBoxContainer.new()
		srow.add_theme_constant_override("separation", 4)
		right.add_child(srow)
		var nm := Label.new()
		nm.text = Game.STAT_NAMES[key]
		nm.custom_minimum_size = Vector2(62, 0)
		nm.add_theme_font_size_override("font_size", 9)
		nm.add_theme_color_override("font_color", ACCENT)
		srow.add_child(nm)
		var lvl := int(_cr.get("levels", {}).get(key, 5))
		if _cr_full and _cr_mode == "points":
			var minus := _small_btn(srow, "-", func(): _bump(key, -1))
			minus.custom_minimum_size = Vector2(18, 0)
			minus.disabled = lvl <= 0
		var bar := Label.new()
		bar.text = "■".repeat(lvl) + "□".repeat(Game.LEVEL_MAX - lvl)
		bar.add_theme_font_size_override("font_size", 9)
		bar.add_theme_color_override("font_color", TEXT)
		srow.add_child(bar)
		if _cr_full and _cr_mode == "points":
			var used2 := 0
			for s2 in Game.STAT_ORDER:
				used2 += int(_cr["levels"][s2])
			var plus := _small_btn(srow, "+", func(): _bump(key, 1))
			plus.custom_minimum_size = Vector2(18, 0)
			plus.disabled = lvl >= Game.LEVEL_MAX or used2 >= Game.LEVEL_POOL
		var val := Label.new()
		val.text = "  %d" % int(_cr[key])
		val.add_theme_font_size_override("font_size", 9)
		val.add_theme_color_override("font_color", Color(1, 1, 1))
		srow.add_child(val)
		_rlabel(right, Game.STAT_HELP[key], FRAME, 7)

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
	l.custom_minimum_size = Vector2(370, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l

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
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.custom_minimum_size = Vector2(0, 15)
	parent.add_child(row)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(62, 0)
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", FRAME)
	row.add_child(l)
	var val := Label.new()
	var state := {"i": clampi(cur, 0, opts.size() - 1)}
	val.text = str(opts[state["i"]])
	val.custom_minimum_size = Vector2(100, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.add_theme_font_size_override("font_size", 8)
	val.add_theme_color_override("font_color", TEXT)
	var prev := _small_btn(row, "<", func():
		state["i"] = (state["i"] - 1 + opts.size()) % opts.size()
		val.text = str(opts[state["i"]])
		cb.call(state["i"]))
	prev.custom_minimum_size = Vector2(16, 0)
	row.add_child(val)
	var nxt := _small_btn(row, ">", func():
		state["i"] = (state["i"] + 1) % opts.size()
		val.text = str(opts[state["i"]])
		cb.call(state["i"]))
	nxt.custom_minimum_size = Vector2(16, 0)

## The merc in 3D, slowly turning (own little world in a SubViewport).
func _build_preview(parent: Node, editing := true) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(420, 360)
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.07, 0.12)
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
	if an:
		an.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
		an.play("idle")
	_cr_model.rotation.y = _cr_rot
	_cr_vp = vp
	_refresh_preview()
	var tr := TextureRect.new()
	tr.texture = vp.get_texture()
	tr.custom_minimum_size = Vector2(210, 158)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	parent.add_child(tr)
	var rrow := HBoxContainer.new()
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
	if not editing:
		return
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

func _refresh_preview() -> void:
	if _cr_model and is_instance_valid(_cr_model):
		Game.apply_look(_cr_model, _cr["look"])

var _lobby_t := 0.0
var _menu_prev_want := Vector2.ZERO     # the size before the last change (no flip-flopping between two)
func _process(delta: float) -> void:
	_lobby_t += delta
	if _lobby_t > 0.15 and Net.is_online() and _status and is_instance_valid(_status) and _status.text.begins_with("Hráči"):
		_lobby_t = 0.0
		_refresh_lobby()
	# keep the menu panel on screen: as tall as its content, at most what fits
	if _scroll and is_instance_valid(_scroll) and _box and is_instance_valid(_box):
		var p := _scroll.get_parent() as Control
		var room := 344.0 - (p.position.y - 8.0) - 22.0
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
		p.position.x = roundf((640.0 - p.size.x) / 2.0)
		if _title_mode:
			p.position.y = 354.0 - p.size.y
	if _cr_model and is_instance_valid(_cr_model) and _cr_vp and is_instance_valid(_cr_vp):
		_cr_model.rotation.y = lerp_angle(_cr_model.rotation.y, _cr_rot, delta * 5.0)
		if not _cr_lock:
			_cr_rot += delta * (0.12 if _cr_face else 0.25)

# ---- loadout: UFO-style equip screen --------------------------------------------------------
var _gear_note := ""
func _show_loadout() -> void:
	_panel("VÝSTROJ NA MISI")
	var vet := Game.difficulty == "veteran"
	var cur: Dictionary = Game.valid_loadout(vet)
	Game.loadout = cur
	var left: Dictionary = Game.stash_for(vet).duplicate()
	for slot in cur:
		left[cur[slot]] = int(left[cur[slot]]) - 1
	for k in left.keys():
		if int(left[k]) <= 0:
			left.erase(k)
	var weight := 0
	for slot in cur:
		weight += int(Game.ITEMS[cur[slot]]["weight"])
	var kits := HBoxContainer.new()
	_box.add_child(kits)
	var kl := Label.new()
	kl.text = "Typ vojáka:"
	kl.add_theme_font_size_override("font_size", 8)
	kl.add_theme_color_override("font_color", FRAME)
	kits.add_child(kl)
	for k in Game.KITS:
		var kit: String = k
		_small_btn(kits, kit, func(): Game.loadout = Game.KITS[kit].duplicate(); Game.save_settings(); _show_loadout())
	# 0.60: the player's own saved sets (kept on this computer, outlive the soldier)
	var mine := HFlowContainer.new()
	mine.add_theme_constant_override("h_separation", 2)
	_box.add_child(mine)
	var ml := Label.new()
	ml.text = "Moje sady:"
	ml.add_theme_font_size_override("font_size", 8)
	ml.add_theme_color_override("font_color", FRAME)
	mine.add_child(ml)
	var sets := Game.presets("gear")
	for i in sets.size():
		var k := i
		var pr: Dictionary = sets[i]
		var sb := _small_btn(mine, String(pr.get("label", "?")), func():
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
		var db := _small_btn(mine, "×", func(): Game.delete_preset("gear", k); _gear_note = ""; _show_loadout())
		db.tooltip_text = "Smazat sadu"
	var gle := LineEdit.new()
	var base: String = Game.ITEMS[cur["rh"]]["short"] if cur.has("rh") and Game.ITEMS.has(cur["rh"]) else "Sada"
	gle.text = Game.preset_label("gear", base)
	gle.custom_minimum_size = Vector2(80, 0)
	gle.add_theme_font_size_override("font_size", 8)
	mine.add_child(gle)
	_small_btn(mine, "Uložit sadu", func():
		var lbl := gle.text.strip_edges()
		if lbl == "":
			lbl = Game.preset_label("gear", base)
		if Game.save_preset("gear", lbl, {"loadout": cur.duplicate()}):
			_gear_note = "Uloženo: " + lbl
		else:
			_gear_note = "Plno (%d sad) - nejdřív nějakou smaž." % Game.PRESET_MAX
		_show_loadout())
	if _gear_note != "":
		var gn := Label.new()
		gn.text = _gear_note
		gn.add_theme_font_size_override("font_size", 8)
		gn.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
		_box.add_child(gn)
		_gear_note = ""
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_box.add_child(row)
	# left: the body (slots)
	var body := VBoxContainer.new()
	row.add_child(body)
	var names := {"rh": "1 primární", "side": "2 sekundár.", "lh": "štít"}
	var arm_lbl := Label.new()
	arm_lbl.text = "ZBROJ"
	arm_lbl.add_theme_font_size_override("font_size", 8)
	arm_lbl.add_theme_color_override("font_color", FRAME)
	body.add_child(arm_lbl)
	var ab := _button(Game.ITEMS[cur["armor"]]["short"] if cur.has("armor") else "(žádná - vesta/pancíř ze skladu)", func():
		if Game.loadout.has("armor"):
			Game.loadout.erase("armor")
			Game.save_settings()
			_show_loadout())
	ab.reparent(body)
	ab.custom_minimum_size = Vector2(160, 16)
	ab.add_theme_font_size_override("font_size", 8)
	if cur.has("armor"):
		UiSkin.item_icon(ab, cur["armor"], 22)
	for g in [["ZBRANĚ (primární je na začátku v rukou)", ["rh", "side", "lh"]], ["OPASEK (3-6)", ["b0", "b1", "b2", "b3"]], ["BATOH", Game.pack_slots()]]:
		var l := Label.new()
		l.text = g[0]
		l.add_theme_font_size_override("font_size", 8)
		l.add_theme_color_override("font_color", FRAME)
		body.add_child(l)
		var grid := GridContainer.new()
		grid.columns = 4 if g[0].begins_with("OPASEK") else 3
		body.add_child(grid)
		for slot in g[1]:
			var sl: String = slot
			var txt: String = Game.ITEMS[cur[sl]]["short"] if cur.has(sl) and cur[sl] != "" else "(" + names.get(sl, "-") + ")"
			var b := _button(txt, func():
				if Game.loadout.has(sl):
					Game.loadout.erase(sl)
					Game.save_settings()
					_show_loadout())
			b.reparent(grid)
			b.custom_minimum_size = Vector2(60, 28)
			var has_it: bool = cur.has(sl) and cur[sl] != ""
			UiSkin.item_tile(b, cur[sl] if has_it else "", txt, {"rh": "1", "side": "2", "b0": "3", "b1": "4", "b2": "5", "b3": "6"}.get(sl, ""))
	# right: the base stores
	var store_box := VBoxContainer.new()
	row.add_child(store_box)
	var store := GridContainer.new()
	store.columns = 2
	store.add_theme_constant_override("h_separation", 2)
	store.add_theme_constant_override("v_separation", 1)
	var sl2 := Label.new()
	sl2.text = "SKLAD" + (" (veterán)" if vet else "")
	sl2.add_theme_font_size_override("font_size", 8)
	sl2.add_theme_color_override("font_color", FRAME)
	store_box.add_child(sl2)
	store_box.add_child(store)
	for id in left:
		var item: String = id
		var b := _button("%s x%d (%dkg)" % [Game.ITEMS[item]["short"], int(left[item]), int(Game.ITEMS[item]["weight"])], func():
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
			_show_loadout())
		b.reparent(store)
		b.add_theme_font_size_override("font_size", 7)
		b.custom_minimum_size = Vector2(98, 14)
		UiSkin.item_icon(b, item, 26)
		b.disabled = int(left[item]) <= 0
	var cap := int(Game.merc.get("strength", 30))
	var wl := _label("Váha %d / síla %d%s" % [weight, cap, "  PŘETÍŽEN - budeš pomalejší" if weight > cap else ""], Color(1, 0.5, 0.4) if weight > cap else TEXT, 9)
	var hl := _label("Sklad = vezmi. Tělo = vrať. Opasek je rychlý, batoh pomalý.", FRAME, 8)
	var bottom := HBoxContainer.new()
	_box.add_child(bottom)
	_button("Výchozí výstroj", func(): Game.loadout = {}; Game.save_settings(); _show_loadout()).reparent(bottom)
	_button("Úpravy zbraní", func(): _mods_from = "loadout"; _show_mods()).reparent(bottom)
	_button("Zpět", _back).reparent(bottom)
	for c in bottom.get_children():
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 0.57: the weight and the buttons at the top, under the title - the long store scrolls below them
	_box.move_child(bottom, 1)
	_box.move_child(wl, 2)
	_box.move_child(hl, 3)
	(_box.get_parent().get_parent() as Control).position.y = 6

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
	st.add_theme_color_override("font_color", Color(1, 0.6, 0.4))
	st.custom_minimum_size = Vector2(300, 0)

func _show_lobby() -> void:
	_panel("TÝM")
	_status = _label("")
	# (0.61) one row per player: name, ping, microphone, and for the host a button to send him away
	_lobby_rows = VBoxContainer.new()
	_lobby_rows.add_theme_constant_override("separation", 1)
	_box.add_child(_lobby_rows)
	_lobby_sig = ""
	_lobby_mic = _label("")
	if multiplayer.is_server():
		_label("Kamarádi se připojí na tvou IP adresu, port %d (TCP/UDP). Po internetu přes Radmin VPN / ZeroTier." % Net.PORT, FRAME, 9)
		_label("Obtížnost: " + Game.DIFF_NAMES.get(Campaign.difficulty() if Campaign.active else Game.difficulty, "normální") + (" (daná kampaní)" if Campaign.active else " (mění se v Rychlé misi)"), ACCENT, 9)
		_button("ZAČÍT MISI: " + QUICK[quick_pick][0], func(): Net.start_mission(quick_params(quick_pick)))
		_button("Změnit typ mise", func(): quick_pick = (quick_pick + 1) % QUICK.size(); _show_lobby())
		_button("Palba do vlastních: " + ("ZAPNUTÁ" if Game.friendly_fire else "vypnutá"), func(): Game.friendly_fire = not Game.friendly_fire; Game.save_settings(); _show_lobby())
		var sizes := ["", "small", "medium", "large", "huge", "colossal"]
		_button("Velikost mapy: " + ("podle mise" if quick_size == "" else MapGen.SIZE_NAMES[quick_size]), func():
			quick_size = sizes[(sizes.find(quick_size) + 1) % sizes.size()]
			_show_lobby())
	else:
		_label("Čekáme, až hostitel spustí misi. Mezitím si připrav výstroj a domluvte se (mikrofon funguje i tady).", FRAME, 9)
		if Campaign.viewer:
			_button("Základna a glóbus hostitele", func(): _back_target = "lobby"; get_tree().change_scene_to_file("res://scenes/Geoscape.tscn"))
	_button("Výstroj na misi", func(): _back_target = "lobby"; _show_loadout())
	_button("Můj voják (talenty, vzhled)", func(): _back_target = "lobby"; _show_merc())
	_button("Úpravy zbraní za peníze (svítilna, laser, tlumič...)", func(): _back_target = "lobby"; _show_mods())
	_button("Peníze: spoluhráčům a do rozpočtu základny", func(): _back_target = "lobby"; _show_money())
	_button("Hlas a mikrofon (hlasitost spoluhráčů, test)", func():
		_back_target = "lobby"
		_panel("NASTAVENÍ")
		preload("res://scripts/hud.gd").settings_ui(_box)
		_button("Zpět", _back))
	_button("Odejít", func(): Net.close(); _show_main())
	_refresh_lobby()

var _lobby_rows: VBoxContainer
var _lobby_mic: Label
var _lobby_sig := ""
var _lobby_row := {}      # peer -> {"name": Label, "info": Label, "kick": Button or null}
var _kick_arm := {}       # peer -> msec: the first press only asks, the second sends him away
const MIC_TEXT := {"off": "mikrofon vypnutý", "ptt": "mikrofon na Tab", "open": "mikrofon otevřený", "dead": "MIKROFON NEJDE"}

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
			var row := HBoxContainer.new()
			_lobby_rows.add_child(row)
			var nm := Label.new()
			nm.add_theme_font_size_override("font_size", 10)
			nm.add_theme_color_override("font_color", TEXT)
			nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nm.clip_text = true
			nm.custom_minimum_size.x = 120
			row.add_child(nm)
			var inf := Label.new()
			inf.add_theme_font_size_override("font_size", 8)
			row.add_child(inf)
			var kb: Button = null
			if host and pid != 1:
				kb = _small_btn(row, "Vyhodit", func():
					if Time.get_ticks_msec() - int(_kick_arm.get(pid, -100000)) < 3000:
						_kick_arm.erase(pid)
						Net.kick(pid)
					else:
						_kick_arm[pid] = Time.get_ticks_msec()
						_refresh_lobby())
				kb.custom_minimum_size.x = 58
			elif host:
				var gap := Control.new()      # the host's own row: keep the columns in line
				gap.custom_minimum_size.x = 58
				row.add_child(gap)
			_lobby_row[pid] = {"name": nm, "info": inf, "kick": kb}
	var lv: Node = Net.get_node_or_null("LobbyVoice")
	for id in _lobby_row:
		if not Net.roster.has(id):
			continue
		var r: Dictionary = _lobby_row[id]
		var money := ""
		if Net.wallets.has(id):
			money = "  -  %d kr" % int(Net.wallets[id])
		var talk := "   <<< MLUVÍ" if lv and lv.speaking(id) else ""
		var sick_m: Dictionary = Game.merc if id == Net.my_id() else Net.roster[id].get("merc", {})
		if float(sick_m.get("sick", 0.0)) > 0.0:
			talk += "  [NA MARODCE]"
		(r["name"] as Label).text = "%s %s%s%s" % ["*" if id == 1 else "-", Net.roster[id]["name"], money, talk]
		var ping := Net.ping_of(id)
		var mic_s := Net.mic_of(id)
		var bits := []
		if id == 1:
			bits.append("hostitel")
		elif ping >= 0:
			bits.append("ping %d ms" % ping)
		if MIC_TEXT.has(mic_s):
			bits.append(MIC_TEXT[mic_s])
		var col := FRAME
		if id != 1 and ping >= 0:
			col = Color(0.55, 0.9, 0.5) if ping < 80 else (Color(1, 0.85, 0.4) if ping < 160 else Color(1, 0.45, 0.35))
		if mic_s == "dead":
			col = Color(1, 0.6, 0.35)
		(r["info"] as Label).text = "   ".join(bits)
		(r["info"] as Label).add_theme_color_override("font_color", col)
		var kb: Button = r["kick"]
		if kb and is_instance_valid(kb):
			var armed := Time.get_ticks_msec() - int(_kick_arm.get(id, -100000)) < 3000
			kb.text = "Opravdu?" if armed else "Vyhodit"
			kb.add_theme_color_override("font_color", Color(1, 0.45, 0.35) if armed else TEXT)
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
		_label(t, Color(1, 0.5, 0.4), 9)

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
		"geo", "campaign", "campair", "uigeo", "encyshot", "striketest":
			# (the test machine's merc may still be on the sick bay from an earlier test run)
			for k in ["heal_days", "injury", "sick", "heal_cid", "heal_seen"]:
				Game.merc.erase(k)
			if Game.cmd_arg("newcamp", "1") == "1":
				Campaign.new_campaign()
			else:
				Campaign.load_campaign()
			get_tree().change_scene_to_file("res://scenes/Geoscape.tscn")
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
				["create", func(): _show_create(true)], ["look", func(): _show_create(false)],
				["settings", _show_settings],
				["loadout", _show_loadout], ["join", _show_join], ["connecting", func(): _connecting("192.168.0.99")], ["news", _show_news], ["mods", _show_mods], ["talents", _show_talents], ["money", _show_money], ["lobby", _show_lobby],
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
				while Time.get_ticks_msec() - t0 < 9000:
					await get_tree().create_timer(0.2).timeout
				var rx = lv._chan.values()[0]["rx"] if not lv._chan.is_empty() else null
				print("RESULT vnet received %d lost %d rescued %d" % [lv.received, rx.lost if rx else -1, rx.rescued if rx else -1])
			else:
				await get_tree().create_timer(1.5).timeout
				Net.join("127.0.0.1", int(Game.cmd_arg("port", str(Net.PORT))))
				await get_tree().create_timer(2.5).timeout
				var chunk := int(lv.Voice.RATE * lv.Voice.CHUNK)
				var n := 0
				for k in 50:
					var smp := PackedFloat32Array()
					smp.resize(chunk)
					for i in chunk:
						smp[i] = sin(TAU * 200.0 * (k * chunk + i) / lv.Voice.RATE) * 0.2
					var pkt: PackedByteArray = lv.dsp.packet(smp)
					if k % 7 != 3:
						lv._lobby_voice.rpc(pkt)
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
		"air":
			Net.mission_params = {"intercept": true, "id": -1, "ufo": Game.cmd_arg("ufo", "raider")}
			get_tree().change_scene_to_file("res://scenes/Intercept.tscn")
		"escort":
			Net.mission_params = {"escort": true, "craft": -1, "transport": Game.cmd_arg("tr", "heli"), "escort_n": int(Game.cmd_arg("esc", "2")), "pilots": [], "driver": 0}
			get_tree().change_scene_to_file("res://scenes/Escort.tscn")
		"town", "zoo", "terror", "voice", "club", "uimission", "stance", "wshot", "sightshot", "muzzleshot", "pose", "rlanim", "ufoshot", "mapshot", "objtest", "breaktest", "armstest", "invtest", "actshot", "stuntest", "tactics", "cloakshot", "doorshot", "passcheck", "camoshot", "lookshot", "soundcheck", "dronetest", "airdeath", "vipcheck", "climb", "rocktest", "hitbox", "wedgetest", "pockettest", "leaveany", "skyshot", "zfight", "suittest", "levgrab", "mirotest", "bijtest", "weaktest", "sgtest", "kanontest", "mgheat", "seedtest", "supplytest", "rockettest", "bvtest", "nadtest", "ohntest", "mystest", "koltest", "lasertest", "lcshot", "ppshot", "bijanim", "afkalien", "softparts", "fpmocap", "vrplay", "vrstrike", "strikeshot", "fpreload", "quickcut", "civanim", "civdeath", "tpwalk", "blendtest", "talenttest", "dragshot", "testroom", "plasmatest", "aitest", "nadetest", "searchtest", "feartest", "squadtest", "packtest", "heattest", "tunetest", "styletest", "dirtest", "nemtest", "civtest", "latetest", "gunshots", "topshot", "shieldtest", "shieldshot", "locktest", "mocapgame", "beltthrow", "fireshot", "abase", "radartest", "loadshots", "transport", "uifit", "groundtest", "echotest", "dirtshot":
			Net.play_solo()
			Campaign.active = false
			Net.start_mission({"type": Game.cmd_arg("mtype", "terror"), "biome": Game.cmd_arg("biome", "town"), "night": Game.cmd_arg("day", "0") != "1",
				"hour": float(Game.cmd_arg("hour", "14.0" if Game.cmd_arg("day", "0") == "1" else "23.0")), "place": "Test", "type_name": "Test", "extra_aliens": 1, "id": -1, "testroom": Game.autotest() == "testroom", "terrain": Game.cmd_arg("terrain", "temperate"), "size": Game.cmd_arg("size", "medium"), "ufo": Game.cmd_arg("ufo", ""), "crew_of": Game.cmd_arg("crewof", ""), "group": Game.cmd_arg("group", ""), "research": Array(Game.cmd_arg("research", "").split(",", false)),
				"habits": {String(Game.merc.get("name", "")): Game.cmd_arg("habits", "").split(",", false)} if Game.cmd_arg("habits", "") != "" else {},
				"styles": {String(Game.merc.get("name", "")): Array(Game.cmd_arg("styles", "").split(",", false))} if Game.cmd_arg("styles", "") != "" else {}})
		"basewalk", "basepass", "basenade", "basefly", "blastdoor", "npcshot", "echobase", "wallshot":
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
		"solo", "perf", "navcache", "farview", "mergeshot", "shot", "ai", "panic", "arsenal", "evac":
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
			print("RESULT kick lobby rows %d ping %d mic %s info '%s'" % [rows, Net.ping_of(cid), Net.mic_of(cid), (_lobby_row[cid]["info"] as Label).text if _lobby_row.has(cid) else "-"])
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
			Game.merc["money"] = 700
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
		"lbclient":
			Game.merc["name"] = "Klient"
			await get_tree().create_timer(1.0).timeout
			Net.join("127.0.0.1", int(Game.cmd_arg("port", str(Net.PORT))))
			while not Campaign.viewer:
				await get_tree().create_timer(0.2).timeout
			await get_tree().create_timer(1.0).timeout
			print("[LB] client goes down to the base alone")
			Net.start_local_base({"type": "home", "type_name": "Základna", "base": Campaign.data["base"].duplicate(true), "grid_w": Campaign.GRID_W, "grid_h": Campaign.GRID_H, "transport": "heli", "live": [], "research": [], "night": false, "hour": 12.0, "blips": []})
		"coophealhost", "aimphost":
			if Game.autotest() == "aimphost":
				Game.seed_override = int(Game.cmd_arg("seed", "4242"))     # (the same map for the old and the new AI)
			Net.host(int(Game.cmd_arg("port", str(Net.PORT))))
			while Net.roster.size() < int(Game.cmd_arg("players", "2")):
				await get_tree().create_timer(0.2).timeout
			await get_tree().create_timer(0.5).timeout
			Net.start_mission({"type": "crash", "biome": "farm", "night": false, "hour": 14.0, "place": "Test", "type_name": "Test", "id": -1})
		"coophealclient", "aimpclient":
			Game.merc["name"] = "Klient" if Game.cmd_arg("ci", "1") == "1" else "Klient" + Game.cmd_arg("ci", "1")
			await get_tree().create_timer(1.0 + 0.5 * int(Game.cmd_arg("ci", "1"))).timeout
			Net.join("127.0.0.1", int(Game.cmd_arg("port", str(Net.PORT))))
		"nadehost":
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
		"nadeclient":
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
