extends SceneTree
## (0.72.3) B = selector: bound to B, LR-01 has a burst (5 pulses), every other gun either switches
## something or says why not (Ari: "laserová puška střílí po jednom a B nepřepíná").
## godot --headless --path . -s tools/test/firemodetest.gd
func _has(action: String, k: int) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == k:
			return true
	return false

func _initialize() -> void:
	await process_frame
	var G = root.get_node("Game")
	var P = load("res://scripts/player.gd")
	var ok: bool = G.keys_of("firemode").has(KEY_B) == (not G.key_binds.has("firemode")) or G.key_binds.has("firemode")
	var bound: bool = _has("firemode", KEY_B) or G.key_binds.has("firemode")
	print("[FIRE] B bound: %s" % bound)
	ok = ok and bound
	var silent := []
	var told := 0
	for id in G.ITEMS:
		var r: Dictionary = G.ITEMS[id]
		if r.get("type", "") != "weapon" or r.get("alien", false):
			continue
		if r.has("ammo_alt") or r.has("bursts") or r.has("pulses") or r.get("modes", false):
			continue
		var t: String = P.firemode_none(id)
		if t == "":
			silent.append(id)
		else:
			told += 1
	var lt: String = P.firemode_none("laser_pistol")
	print("[FIRE] laser_pistol: %s" % lt)
	var pn: bool = int(G.ITEMS["laser_rifle"].get("pulses", 0)) >= 5
	print("[FIRE] laser_rifle pulses %d" % int(G.ITEMS["laser_rifle"].get("pulses", 0)))
	ok = ok and silent.is_empty() and told > 0 and lt.contains("pulzy") and pn
	print("RESULT firemode %s told %d silent %s" % ["ok" if ok else "FAIL", told, str(silent)])
	quit(0 if ok else 1)
