extends SceneTree
## (2026-11-22, Ari) Captured aliens in the soldier's record, and ranks above Kapitán.
## Ranks: sorted by experience, the old ones keep their index (Kapitán stays 8, the talent tree too),
## a Kapitán gets promoted on to Major ... Generál with a talent point each. Captures: saved in the
## profile, shown on the soldier's card, in the best soldiers and the fallen on the campaign end.
## godot --headless --path . -s tools/test/caprank.gd   (backs up and restores merc.cfg / campaign.cfg)
const FILES := ["user://merc.cfg", "user://campaign.cfg"]
var bak := {}

func _texts(n: Node, out: Array) -> void:
	if n is Label or n is Button:
		out.append(String(n.text))
	for c in n.get_children():
		_texts(c, out)

func _initialize() -> void:
	await process_frame
	for f in FILES:
		bak[f] = FileAccess.get_file_as_bytes(f) if FileAccess.file_exists(f) else null
	var G = root.get_node("Game")
	var C = root.get_node("Campaign")
	# 1. ranks: same count as thresholds, thresholds rising, the old ones where they were
	var t1: bool = G.RANKS.size() == G.RANK_XP.size() and G.RANKS.size() >= 12
	for i in range(1, G.RANK_XP.size()):
		t1 = t1 and int(G.RANK_XP[i]) > int(G.RANK_XP[i - 1])
	t1 = t1 and G.RANKS[8] == "Kapitán" and int(G.RANK_XP[8]) == 3200 and G.RANKS[9] == "Major" and G.RANKS[G.RANKS.size() - 1] == "Generál"
	t1 = t1 and G.RANKS[G.TREE_RANK[4]] == "Kapitán"
	print("[RANK] order %s: %s" % [", ".join(G.RANKS), t1])
	# 2. a Kapitán (old save, more xp than the old top) goes on up with points
	var m: Dictionary = G.new_merc("Alfa")
	m["xp"] = 3500
	m["talent_points"] = 0
	G.mercs = [m]
	G.active = 0
	G.merc = m
	var r0: int = G.rank_of(m)
	var lines: Array = G.add_xp(1000)       # 4500 -> Major
	var t2: bool = r0 == 8 and G.rank_name(G.merc) == "Major" and int(G.merc["talent_points"]) == 1 and lines.size() == 1 and String(lines[0]).find("Major") >= 0
	lines = G.add_xp(10000)                 # -> Generál, 3 more promotions
	t2 = t2 and G.rank_name(G.merc) == "Generál" and int(G.merc["talent_points"]) == 4 and lines.size() == 3
	print("[RANK] Kapitán -> Major -> Generál, points %d: %s" % [int(G.merc["talent_points"]), t2])
	# 3. captures in the profile
	G.merc["captures"] = 3
	G.merc["kills"] = 12
	G.merc["created"] = true
	G.save_merc()
	G.mercs = []
	G.load_merc()
	var t3: bool = int(G.merc.get("captures", 0)) == 3
	print("[CAPS] saved in the profile: %s" % t3)
	# 4. soldier's card shows them
	var mm = load("res://scenes/Main.tscn").instantiate()
	var t4 := false
	if mm:
		root.add_child(mm)
		for i in 10:
			await process_frame
		mm._show_merc()
		for i in 3:
			await process_frame
		var tx := []
		_texts(mm, tx)
		for s in tx:
			if s.to_upper().find("3 ZAJATÝCH") >= 0 and s.to_upper().find("12 ZABITÍ") >= 0:
				t4 = true
				print("[CAPS] card: " + s)
		mm.queue_free()
	print("[CAPS] soldier card: %s" % t4)
	# 5. campaign end: best soldiers and the fallen
	C.new_campaign("normal")
	C.data["mercs"] = {"u1": {"name": "Alfa", "kills": 12, "missions": 5, "captures": 3}}
	C.data["fallen"] = [{"n": "Bravo", "f": "cz", "m": "Havárie UFO", "k": 2, "c": 1, "mia": false, "d": "1. 5. 1990"},
		{"n": "Starý", "f": "cz", "m": "Teror", "k": 4, "mia": false, "d": "2. 5. 1990"}]   # old record without "c"
	var s: Dictionary = C.summary()
	var end = load("res://scripts/campaign_end.gd").new()
	root.add_child(end)
	end.setup(s, [])
	await process_frame
	var tx2 := []
	_texts(end, tx2)
	var best_ok := false
	var fall_ok := false
	var old_ok := false
	for t in tx2:
		if t.find("zajatí 3") >= 0:
			best_ok = true
		if t.find("Bravo") >= 0 and t.find("zajatí 1") >= 0:
			fall_ok = true
		if t.find("Starý") >= 0 and t.find("zajatí") < 0:
			old_ok = true
	var t5: bool = best_ok and fall_ok and old_ok
	print("[CAPS] campaign end best %s fallen %s old %s: %s" % [best_ok, fall_ok, old_ok, t5])
	end.queue_free()
	var ok: bool = t1 and t2 and t3 and t4 and t5
	print("RESULT caprank %s" % ("ok" if ok else "FAIL"))
	for f in FILES:
		if bak[f] == null:
			if FileAccess.file_exists(f):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
		else:
			var fa := FileAccess.open(f, FileAccess.WRITE)
			fa.store_buffer(bak[f])
			fa.close()
	quit(0 if ok else 1)
