extends SceneTree
## (0.80) The hidden debug mode: off by default (nothing shows), Ctrl+Alt+Shift+D wakes it, then
## all research / everything into the stock / buildings, research and workshop finished / days
## forward / invulnerability work on a fresh campaign.
## godot --headless --path . -s tools/test/debugtest.gd   (backs up and restores merc.cfg / campaign.cfg / settings.cfg)
const FILES := ["user://merc.cfg", "user://campaign.cfg", "user://settings.cfg"]
var bak := {}

func _initialize() -> void:
	await process_frame
	for f in FILES:
		bak[f] = FileAccess.get_file_as_bytes(f) if FileAccess.file_exists(f) else null
	var G = root.get_node("Game")
	var C = root.get_node("Campaign")
	var D = G.debug
	var hidden: bool = D != null and not D.on and not G.debug_on()
	# the secret keys
	var e := InputEventKey.new()
	e.physical_keycode = KEY_D
	e.ctrl_pressed = true
	e.alt_pressed = true
	e.shift_pressed = true
	e.pressed = true
	D._input(e)
	var woke: bool = G.debug_on()
	# (26. 11.) it stays on after a restart (settings), the tag is a button, an open panel frees the mouse
	var kept: bool = G.debug_mode
	G.load_settings()
	kept = kept and G.debug_mode
	var tag_btn: bool = D._tag is Button and D._tag.visible
	C.new_campaign("normal")
	C.data["base_pick"] = false
	# something under construction, a research running, an order in the workshop
	var free_i := -1
	for i in C.data["base"].size():
		if String(C.data["base"][i]["type"]) == "" and C.can_build_at(i):
			free_i = i
			break
	C.data["base"][free_i] = {"type": "laborator", "days": 9.0}
	C.data["research"]["current"] = "zenijni"
	D._open()
	var panel: bool = G.debug_panel()
	D._all_research()
	var all_res := true
	for id in C.RESEARCH:
		all_res = all_res and C.researched(id)
	D._stock_all()
	var stock: bool = int(C.data["armory"].get("sentry", 0)) >= 10 and int(C.data["armory"].get("plasma_rifle", 0)) >= 10
	var cr0 := int(C.data["credits"])
	D._btn_press_money()
	var money: bool = int(C.data["credits"]) == cr0 + 50000
	D._finish_all()
	var built: bool = float(C.data["base"][free_i]["days"]) <= 0.0
	var d0 := float(C.data["day"])
	D._days(7.0)
	var days: bool = absf(float(C.data["day"]) - d0 - 7.0) < 0.01
	D.god = true
	var god: bool = G.debug_god()
	var xp0: int = G.rank_of(G.merc)
	D._promote()
	var promo: bool = G.rank_of(G.merc) == xp0 + 1
	D._close()
	panel = panel and not G.debug_panel()
	G.set_debug_mode(false)
	var off: bool = not G.debug_on() and not G.debug_god() and not G.debug_mode
	print("[DEBUG] kept %s tag %s panel %s" % [kept, tag_btn, panel])
	print("[DEBUG] hidden %s woke %s research %s stock %s money %s built %s days %s god %s promoted %s off %s" % [hidden, woke, all_res, stock, money, built, days, god, promo, off])
	var ok := kept and tag_btn and panel and hidden and woke and all_res and stock and money and built and days and god and promo and off
	print("RESULT debugtest %s" % ("ok" if ok else "FAIL"))
	C.active = false
	for f in FILES:
		if bak[f] == null:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
		else:
			var fa := FileAccess.open(f, FileAccess.WRITE)
			fa.store_buffer(bak[f])
			fa.close()
	quit()
