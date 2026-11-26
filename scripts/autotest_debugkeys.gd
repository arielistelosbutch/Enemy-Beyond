extends RefCounted
## debugkeys (Ari 26. 11.: „hlavně přidat ten debug mód“): v misi skutečné klávesy přes Input
## (Ctrl+Alt+Shift+D, F10) zapnou debug mód a otevřou panel, kliknutí myší na tlačítko panelu
## projde (nesmrtelnost), F10 panel zavře. V co-opu u klienta panel ukáže jen věci vojáka a mise.

static func _key(at: Node, code: Key, mods := true) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.ctrl_pressed = mods
	e.alt_pressed = mods
	e.shift_pressed = mods
	e.pressed = true
	Input.parse_input_event(e)
	await at.get_tree().process_frame
	var u := e.duplicate()
	u.pressed = false
	Input.parse_input_event(u)
	await at.get_tree().process_frame

static func _btn_named(n: Node, start: String) -> Button:
	if n is Button and String((n as Button).text).begins_with(start):
		return n
	for c in n.get_children():
		var b := _btn_named(c, start)
		if b:
			return b
	return null

static func run(at: Node, p: Node) -> void:
	if p == null: return
	at._skip_brief()
	if at.step > 0 or not at.m().started(): return
	at.step = 1
	var D: Node = Game.debug
	var was: bool = Game.debug_on()
	await _key(at, KEY_D)
	var woke: bool = Game.debug_on() and not was
	await _key(at, KEY_F10, false)
	await at.get_tree().process_frame
	var panel: bool = Game.debug_panel()
	var god_b: Button = _btn_named(D._panel, "Nesmrtelnost")
	var clicked := false
	if god_b:
		await at.get_tree().process_frame
		var r: Rect2 = god_b.get_global_rect()
		var at_px: Vector2 = god_b.get_viewport().get_final_transform() * r.get_center()
		var mv := InputEventMouseMotion.new()
		mv.position = at_px
		mv.global_position = at_px
		Input.parse_input_event(mv)
		await at.get_tree().process_frame
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.position = at_px
		mb.global_position = at_px
		mb.pressed = true
		Input.parse_input_event(mb)
		await at.get_tree().process_frame
		var mu := mb.duplicate()
		mu.pressed = false
		Input.parse_input_event(mu)
		await at.get_tree().process_frame
		await at.get_tree().process_frame
		clicked = Game.debug_god()
		print("[DEBUGKEYS] button at %s px %s" % [r, at_px])
	var hp0: float = p.hp
	p.hurt(30.0, p.global_position + Vector3(0, 0, 3))
	var immortal: bool = p.hp == hp0
	var camp_line: bool = _btn_named(Game.debug._panel, "Veškerý výzkum") != null if Game.debug_panel() else false
	await _key(at, KEY_F10, false)
	var closed: bool = not Game.debug_panel()
	D.god = false
	Game.set_debug_mode(false)
	print("[DEBUGKEYS] woke %s panel %s clicked %s immortal %s campaign_buttons %s closed %s" % [woke, panel, clicked, immortal, camp_line, closed])
	var ok := woke and panel and clicked and immortal and closed
	print("RESULT debugkeys %s" % ("ok" if ok else "FAIL"))
	at.get_tree().quit()
