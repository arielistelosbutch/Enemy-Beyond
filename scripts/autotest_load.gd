extends Node

func _init() -> void:
	name = "LoadProgTest"
## 0.72 (Ari: "nahrávání jen při změně scény", "aby byl postup skutečně vidět"): --autotest=loadprog
## 1) main menu -> the globe (threaded loading), 2) the globe -> soldier screen -> Back: the SAME globe
## comes back with no loading screen, 3) the globe -> a mission: the bar moves while the map is built
## and the screen is drawn from inside the build (with a window; headless counts the steps only).
## Prints RESULT loadprog parked <bool> same <bool> back_ms <n> loading_on_back <bool> bar <n> pumps <n> gap <n>

var _bar_seen := 0.0
var _bar_steps := 0
var _last_bar := -1.0

func _ready() -> void:
	name = "LoadProgTest"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run()

func _process(_d: float) -> void:
	var ld = Game._loading
	if is_instance_valid(ld):
		var f: float = ld.progress()
		if f != _last_bar:
			_bar_steps += 1
			_last_bar = f
		_bar_seen = maxf(_bar_seen, f)

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _run() -> void:
	for k in ["heal_days", "injury", "sick", "heal_cid", "heal_seen"]:
		Game.merc.erase(k)
	Campaign.new_campaign()
	Game.load_scene(Game.GLOBE_SCENE)
	while not (get_tree().current_scene and get_tree().current_scene.name == "Geoscape"):
		await get_tree().process_frame
	await _wait(1.0)
	var geo: Node = get_tree().current_scene
	var gid := geo.get_instance_id()
	geo.selected = 7
	geo._menu_screen("merc")
	await _wait(0.5)
	var cur: Node = get_tree().current_scene
	var on_menu := cur != null and cur.name != "Geoscape" and cur.has_method("_show_merc")
	var parked := Game.globe_parked()
	var t0 := Time.get_ticks_msec()
	cur._back()
	var loading_on_back := false
	while not (get_tree().current_scene and get_tree().current_scene.name == "Geoscape"):
		loading_on_back = loading_on_back or is_instance_valid(Game._loading)
		await get_tree().process_frame
	var back_ms := Time.get_ticks_msec() - t0
	await get_tree().process_frame
	var g2: Node = get_tree().current_scene
	var same := g2.get_instance_id() == gid and int(g2.selected) == 7
	var sig_ok := Campaign.changed.is_connected(g2._live_dirty)
	print("[LOADPROG] menu %s parked %s same %s signals %s back %d ms" % [on_menu, parked, same, sig_ok, back_ms])
	# the battle part: a mission behind the loading screen
	_bar_seen = 0.0
	_bar_steps = 0
	Net.play_solo()
	Net.start_mission({"type": "terror", "type_name": "Teror", "biome": "town", "size": "medium"})
	while not (get_tree().current_scene and get_tree().current_scene.name == "Mission"):
		await get_tree().process_frame
	await _wait(0.3)
	var pumps_note := Game.load_pumps
	await _wait(1.0)
	print("RESULT loadprog parked %s same %s signals %s back_ms %d loading_on_back %s bar %.2f steps %d dropped %s" % [parked, same, sig_ok, back_ms, loading_on_back, _bar_seen, _bar_steps, not Game.globe_parked(), ])
	get_tree().quit()
