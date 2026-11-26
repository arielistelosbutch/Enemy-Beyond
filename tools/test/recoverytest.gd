extends SceneTree
## (Ari 2026-11-26: „když lehne celý tým, hráči přijdou o celou techniku") The whole team fell:
## the site stays on the globe as "Vyzvednout padlé" (a second chance). Who brings a fallen man's
## kit home gives the base its armory pieces back, the player his locker pieces and gun parts.
## godot --headless --path . -s tools/test/recoverytest.gd   (backs up and restores merc.cfg / campaign.cfg)
const FILES := ["user://merc.cfg", "user://campaign.cfg"]
var bak := {}

func _initialize() -> void:
	await process_frame
	for f in FILES:
		bak[f] = FileAccess.get_file_as_bytes(f) if FileAccess.file_exists(f) else null
	var ok := true
	var G = root.get_node("Game")
	var C = root.get_node("Campaign")
	C.new_campaign("normal")
	# the fallen soldier: a plasma rifle from the armory, grenades of his own, an optic on his rifle
	var a: Dictionary = G.new_merc("Alfa")
	a["uid"] = "u_alfa"
	a["mods"] = {"rifle": ["optika", "tlumic"]}
	a["locker"] = {}
	G.mercs = [a]
	G.active = 0
	G.merc = a
	C.data["armory"]["plasma_rifle"] = 2
	var m: Dictionary = C.generate_mission(Vector2(49.4, 15.6), "crash")
	C.data["missions"].append(m)
	var kit := ["rifle", "rifle_clip", "plasma_rifle", "grenade", "grenade"]
	var lost := {"rifle": 1, "rifle_clip": 1, "plasma_rifle": 1, "grenade": 2}
	var from_locker := {"grenade": 2}
	var site := {"bodies": [{"uid": "u_alfa", "name": "Alfa", "look": {}, "pos": [10.0, 0.0, 12.0],
		"armory": C.armory_part(kit, lost, from_locker), "locker": C.locker_part(kit, lost, from_locker), "mods": a["mods"].duplicate(true)}],
		"survivors": ["grey", "grey", "lihnoun"]}
	var pr_before := int(C.data["armory"].get("plasma_rifle", 0))
	C.mission_done(int(m["id"]), false, 0, 0, 1, 0, 0, ["grey"], {}, true, {1: kit}, 1.0, {1: lost}, {1: from_locker}, site)
	var pr_after := int(C.data["armory"].get("plasma_rifle", 0))
	G.merc = G.lost_merc(a)        # (as the mission's end does on his own machine)
	G.mercs[0] = G.merc
	var rec := {}
	for mm in C.data["missions"]:
		if String(mm["type"]) == "recovery":
			rec = mm
	var t1: bool = not rec.is_empty() and String(rec["of_type"]) == "crash" and int(rec["seed"]) == int(m["seed"]) and (rec["bodies"] as Array).size() == 1 \
		and (rec["survivors"] as Array).size() == 3 and pr_after == pr_before - 1 and float(rec["expires"]) > float(C.data["day"]) + 2.0 \
		and int(site["bodies"][0]["armory"].get("plasma_rifle", 0)) == 1 and not site["bodies"][0]["armory"].has("grenade") \
		and int(site["bodies"][0]["locker"].get("grenade", 0)) == 2
	print("[REC] wiped team -> recovery mission on the globe: %s (plasma rifles %d -> %d, armory part %s, locker part %s)" % [t1, pr_before, pr_after, site["bodies"][0]["armory"], site["bodies"][0]["locker"]])
	ok = ok and t1
	var t1b: bool = G.fallen_uids.has("u_alfa")
	print("[REC] the profile remembers the fallen soldier: %s" % t1b)
	ok = ok and t1b
	# the recovery: Bravo carried Alfa's kit into the Kondor
	var params: Dictionary = C.mission_params(rec)
	var t2a: bool = params.has("bodies") and String(params["type"]) == "recovery"
	C.mission_done(int(rec["id"]), true, 2, 0, 0, 0, 0, ["grey"], {}, false, {}, 1.0, {}, {}, {"brought": rec["bodies"]})
	var t2: bool = t2a and int(C.data["armory"].get("plasma_rifle", 0)) == pr_before and (C.data.get("returns", []) as Array).size() == 1 \
		and not C.data["missions"].any(func(x): return String(x["type"]) == "recovery")
	print("[REC] kit home -> armory back: %s (plasma rifles %d)" % [t2, int(C.data["armory"].get("plasma_rifle", 0))])
	ok = ok and t2
	var txt: String = G.claim_returns(C.data)
	var t3: bool = int(G.merc["locker"].get("grenade", 0)) == 2 and "optika" in G.merc["mods"].get("rifle", []) and "tlumic" in G.merc["mods"].get("rifle", []) and txt != ""
	print("[REC] the player's locker and gun parts back: %s (%s)" % [t3, txt])
	ok = ok and t3
	var again: String = G.claim_returns(C.data)
	var t4: bool = again == "" and int(G.merc["locker"].get("grenade", 0)) == 2
	print("[REC] not twice: %s" % t4)
	ok = ok and t4
	# somebody else's fallen soldier: nothing for us
	G.returned = {}
	G.fallen_uids = {}
	var other: String = G.claim_returns(C.data)
	var t5: bool = other == ""
	print("[REC] a co-op mate's kit is not ours: %s" % t5)
	ok = ok and t5
	# a recovery that fails: nothing comes home, and no third chance
	var m2: Dictionary = C.generate_mission(Vector2(49.4, 15.6), "landed")
	C.data["missions"].append(m2)
	C.mission_done(int(m2["id"]), false, 0, 0, 1, 0, 0, ["grey"], {}, true, {}, 1.0, {}, {}, site)
	var rec2 := {}
	for mm in C.data["missions"]:
		if String(mm["type"]) == "recovery":
			rec2 = mm
	var ret_n := (C.data.get("returns", []) as Array).size()
	C.mission_done(int(rec2["id"]), false, 0, 0, 1, 0, 0, ["grey"], {}, true, {}, 1.0, {}, {}, {"brought": []})
	var t6: bool = not C.data["missions"].any(func(x): return String(x["type"]) == "recovery") and (C.data.get("returns", []) as Array).size() == ret_n
	print("[REC] a failed recovery: no third chance, nothing back: %s" % t6)
	ok = ok and t6
	# nobody goes: the site expires
	var m3: Dictionary = C.generate_mission(Vector2(49.4, 15.6), "crash")
	C.data["missions"].append(m3)
	C.mission_done(int(m3["id"]), false, 0, 0, 1, 0, 0, ["grey"], {}, true, {}, 1.0, {}, {}, site)
	C.data["day"] = float(C.data["day"]) + 3.0
	C.advance(0.05)
	var t7: bool = not C.data["missions"].any(func(x): return String(x["type"]) == "recovery")
	print("[REC] nobody went - the site expires: %s" % t7)
	ok = ok and t7
	# (Ari 2026-11-26) one man fell, the rest won: his kit comes home by itself, no recovery mission
	var m4: Dictionary = C.generate_mission(Vector2(49.4, 15.6), "crash")
	C.data["missions"].append(m4)
	var b2: Dictionary = G.new_merc("Charlie")
	b2["uid"] = "u_charlie"
	b2["mods"] = {"pistol": ["tlumic"]}
	G.mercs = [b2]
	G.active = 0
	G.merc = b2
	var pr4 := int(C.data["armory"].get("plasma_rifle", 0))
	var r4 := (C.data.get("returns", []) as Array).size()
	var t4b: String = C.mission_done(int(m4["id"]), true, 3, 0, 1, 0, 0, ["grey"], {}, false, {1: ["plasma_rifle"]}, 1.0, {1: {}}, {}, \
		{"brought": [{"uid": "u_charlie", "name": "Charlie", "armory": {}, "locker": {}, "mods": b2["mods"].duplicate(true)}]})
	G.merc = G.lost_merc(b2)
	G.mercs[0] = G.merc
	var txt8: String = G.claim_returns(C.data)
	var t8: bool = int(C.data["armory"].get("plasma_rifle", 0)) == pr4 and (C.data["returns"] as Array).size() == r4 + 1 \
		and "tlumic" in G.merc["mods"].get("pistol", []) and not C.data["missions"].any(func(x): return String(x["type"]) == "recovery") and "je doma" in t4b
	print("[REC] a man fell, the team won: kit and gun parts home by themselves: %s (%s)" % [t8, txt8])
	ok = ok and t8
	for f in FILES:
		if bak[f] == null:
			if FileAccess.file_exists(f):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
		else:
			var fa := FileAccess.open(f, FileAccess.WRITE)
			fa.store_buffer(bak[f])
			fa.close()
	print("RESULT recoverytest %s" % ("ok" if ok else "FAIL"))
	quit()
