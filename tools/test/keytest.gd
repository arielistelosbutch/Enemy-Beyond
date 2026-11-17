extends SceneTree
## (0.72) Own keys: rebinding, a key taken from another action, the dogfight's own keys, saving and
## the settings screen (click a key, press the new one, right click clears).
## godot --headless --path . -s tools/test/keytest.gd   (backs up and restores settings.cfg)
const F := "user://settings.cfg"

func _has(action: String, k: int) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == k:
			return true
	return false

func _initialize() -> void:
	await process_frame
	var bak = FileAccess.get_file_as_bytes(F) if FileAccess.file_exists(F) else null
	var G = root.get_node("Game")
	var ok := true
	G.reset_keys()
	var t1: bool = _has("radio_talk", KEY_TAB) and _has("talk", KEY_T) and _has("lean_left", KEY_Q) and _has("decoy", KEY_Q)
	print("[KEYS] defaults Tab=radio T=talk Q=lean+decoy: %s" % t1)
	G.rebind("talk", 0, KEY_P)
	G.rebind("sprint", 0, KEY_P)          # P leaves "talk"
	var t2: bool = _has("sprint", KEY_P) and not _has("sprint", KEY_SHIFT) and not _has("talk", KEY_P) and G.key_name("talk") == "-"
	print("[KEYS] rebind and steal: %s" % t2)
	G.rebind("lean_left", 0, KEY_Z)       # Z leaves prone (on foot), decoy keeps Q
	var t3: bool = _has("lean_left", KEY_Z) and not _has("prone", KEY_Z) and _has("prone", KEY_Y) and _has("decoy", KEY_Q)
	print("[KEYS] groups: %s" % t3)
	G.rebind("move_forward", 1, 0)        # clear the arrow
	var t4: bool = _has("move_forward", KEY_W) and not _has("move_forward", KEY_UP)
	print("[KEYS] clear second: %s" % t4)
	G.key_binds = {}
	G.load_settings()
	G._apply_keys()
	var t5: bool = _has("sprint", KEY_P) and _has("lean_left", KEY_Z) and not _has("move_forward", KEY_UP)
	print("[KEYS] saved and loaded: %s" % t5)
	# the settings screen
	G.reset_keys()
	var box := VBoxContainer.new()
	root.add_child(box)
	load("res://scripts/hud.gd").settings_ui(box)
	await process_frame
	var bt: Button = null
	for hb in box.get_children():
		if hb is HBoxContainer and hb.get_child_count() == 3 and hb.get_child(0) is Label and (hb.get_child(0) as Label).text == "Vysílačka (držet)":
			bt = hb.get_child(1)
	var t6 := bt != null and bt.text == "Tab"
	if bt:
		bt.pressed.emit()
		var waiting: bool = G.binding_key and bt.text == "stiskni..."
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_O
		ev.pressed = true
		bt.gui_input.emit(ev)
		t6 = t6 and waiting and bt.text == "O" and _has("radio_talk", KEY_O) and not _has("radio_talk", KEY_TAB)
		var rc := InputEventMouseButton.new()
		rc.button_index = MOUSE_BUTTON_RIGHT
		rc.pressed = true
		bt.gui_input.emit(rc)
		t6 = t6 and _has("radio_talk", KEY_K) and not _has("radio_talk", KEY_O)
	print("[KEYS] settings screen: %s" % t6)
	var rows := 0
	for hb in box.get_children():
		if hb is HBoxContainer and hb.get_child_count() == 3:
			rows += 1
	print("[KEYS] rows %d" % rows)
	ok = t1 and t2 and t3 and t4 and t5 and t6
	G.reset_keys()
	if bak == null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(F))
	else:
		var f := FileAccess.open(F, FileAccess.WRITE)
		f.store_buffer(bak)
		f.close()
	print("RESULT keytest %s" % ("ok" if ok else "FAIL"))
	quit()
