extends RefCounted
## (26. 11. 2026, Ari) F1 = zadání mise. --autotest=tasktest --mtype=<typ> [--biome=...]:
## F1 opens the panel with the task from the briefing, it fits above the bars, the state line
## follows the mission (done = green), Esc closes it before the pause, F2 hides the HUD,
## and no other key on foot sits on F1/F2. Snapshots task_<typ>.png under xvfb.

static func run(at: Node, p: Node) -> void:
	if p == null or at.step > 0:
		return
	at._skip_brief()
	var m: Node = at.m()
	if not m.go:
		return
	at.step = 1
	var h: Node = m.hud
	await at.get_tree().create_timer(3.0).timeout       # the briefing fades out
	h.inventory_open = false
	# the keys: F1 / F2 and nobody else on foot uses them
	var keys_ok: bool = KEY_F1 in Game.keys_of("mission_info") and KEY_F2 in Game.keys_of("hud_toggle")
	for row in Game.KEY_ROWS:
		var a: String = row[0]
		if a == "" or a in ["mission_info", "hud_toggle"] or Game.KEY_OWN_GROUP.has(a):
			continue
		if KEY_F1 in Game.keys_of(a) or KEY_F2 in Game.keys_of(a):
			keys_ok = false
			at.out("[TASK] key clash %s" % a)
	at.out("[TASK] before: window_up %s inv %s paused %s brief_t %.1f fade %.1f" % [h.window_up(), h.inventory_open, h.paused, h._brief_t, h._brief_fade])
	await _tap(at, "mission_info")
	var open: bool = h.task_open()
	var task_ok := false
	var fits := -1
	var bottom := 0.0
	if open:
		var txt := ""
		for l in h._task_panel.find_children("*", "Label", true, false):
			txt += (l as Label).text + "\n"
		var want := String(h._task_parts.get("task", ""))
		task_ok = want != "" and txt.contains(want.left(30))
		await at.get_tree().process_frame
		await at.get_tree().process_frame
		bottom = h._task_panel.get_global_rect().end.y
		fits = preload("res://scripts/autotest_facelift.gd").fit(h._task_panel, "task")
		if bottom > 270.0:
			fits += 1
			at.out("[UI] task: přetéká přes lišty dole (%.0f)" % bottom)
		await at.get_tree().create_timer(0.5).timeout
		preload("res://scripts/autotest_facelift.gd").shot(at, "task_" + String(m.mtype()))
	# the state follows the mission
	m.done_banner = true       # (the host would take it back at once: the crew still lives)
	h._task_tick()
	var done_ok: bool = open and h._task_now.text.contains("splněn")
	m.done_banner = false
	# Esc: the panel goes first, the pause does not open
	await _tap(at, "pause")
	var esc_ok: bool = not h.task_open() and not h.paused
	# F1 again opens, F1 closes
	await _tap(at, "mission_info")
	var again: bool = h.task_open()
	await _tap(at, "mission_info")
	again = again and not h.task_open()
	# F2 = HUD
	await _tap(at, "hud_toggle")
	var hud_ok: bool = Game.hud_hidden
	await _tap(at, "hud_toggle")
	hud_ok = hud_ok and not Game.hud_hidden
	at.out("[TASK] task \"%s\" bottom %.0f" % [String(h._task_parts.get("task", "")).replace("\n", " / ").left(80), bottom])
	at.out("RESULT tasktest open %s task %s fits %d done %s esc %s again %s hud %s keys %s" % [open, task_ok, fits, done_ok, esc_ok, again, hud_ok, keys_ok])
	at.get_tree().quit()

static func _tap(at: Node, action: String) -> void:
	await at.get_tree().process_frame      # timers fire after the nodes' _process: press at the frame's start
	Input.action_press(action)
	await at.get_tree().process_frame
	Input.action_release(action)
	await at.get_tree().process_frame
	await at.get_tree().process_frame
