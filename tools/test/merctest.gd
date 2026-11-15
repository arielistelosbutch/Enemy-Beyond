extends SceneTree
## (0.7x) Soldiers between games: the campaign's record by the soldier's id, fallen soldiers stay
## fallen, the own locker belongs to the campaign it was bought in.
## godot --headless --path . -s tools/test/merctest.gd   (backs up and restores merc.cfg / campaign.cfg)
const FILES := ["user://merc.cfg", "user://campaign.cfg"]
var bak := {}

func _initialize() -> void:
	await process_frame
	for f in FILES:
		bak[f] = FileAccess.get_file_as_bytes(f) if FileAccess.file_exists(f) else null
	var ok := true
	var G = root.get_node("Game")
	var C = root.get_node("Campaign")
	# 1. my soldier with plasma bought in campaign "X" steps into a new campaign
	var a: Dictionary = G.new_merc("Alfa")
	a["locker"] = {"plasma_rifle": 1, "plasma_clip": 3}
	a["gear_cid"] = "X"
	G.mercs = [a]
	G.active = 0
	G.merc = a
	C.new_campaign("normal")
	var cid := String(C.data["cid"])
	var t1: bool = (G.merc.get("locker", {}) as Dictionary).is_empty() and G.merc["lockers"].has("X") and String(G.merc["gear_cid"]) == cid
	print("[MERC] own locker stays in its campaign: %s" % t1)
	G.merc["locker"] = {"grenade": 2}         # bought here
	# 2. back home: the plasma comes back, the grenades wait in the new campaign
	var back: bool = G.gear_to(G.merc, "X")
	var t2: bool = back and int(G.merc["locker"].get("plasma_rifle", 0)) == 1 and int(G.merc["lockers"][cid].get("grenade", 0)) == 2
	G.gear_to(G.merc, cid)
	t2 = t2 and int(G.merc["locker"].get("grenade", 0)) == 2 and not G.merc["locker"].has("plasma_rifle")
	print("[MERC] locker comes back with him: %s" % t2)
	# 3. a friend's soldier with plasma from his own war joins: the host hands back the locker of this campaign
	var b: Dictionary = G.new_merc("Bravo")
	b["locker"] = {"plasma_pistol": 1}
	b["gear_cid"] = "Z"
	b["missions"] = 4
	b["money"] = 500
	var kb: Dictionary = C.keep_merc(b)
	var t3: bool = (kb.get("locker", {}) as Dictionary).is_empty() and kb["lockers"].has("Z") and int(kb["money"]) == 500 and b["locker"].has("plasma_pistol")
	print("[MERC] friend's plasma stays at home: %s" % t3)
	# 4. the record is further along (his copy is older): he plays the record, his purse stays
	var rec: Dictionary = C.data["mercs"][String(b["uid"])]
	rec["missions"] = 9
	var b_old: Dictionary = kb.duplicate(true)
	b_old["missions"] = 4
	b_old["money"] = 80
	var k4: Dictionary = C.keep_merc(b_old)
	var t4: bool = int(k4["missions"]) == 9 and int(k4["money"]) == 80
	print("[MERC] newer record wins, purse stays: %s" % t4)
	# 5. Bravo falls; a new recruit from the template has the same name: he is somebody else
	C.merc_gone(k4)
	var c: Dictionary = G.new_merc("Bravo")
	c["missions"] = 0
	var k5: Dictionary = C.keep_merc(c)
	var t5: bool = int(k5.get("missions", 0)) == 0 and String(k5["uid"]) == String(c["uid"]) and C.data["mercs"][String(b["uid"])].get("gone", false)
	# the same id coming back is never handed the fallen record
	var k5b: Dictionary = C.keep_merc(b_old)
	t5 = t5 and int(k5b["missions"]) == 4
	print("[MERC] fallen stays fallen (same name, new soldier): %s" % t5)
	# 6. a record from before the ids (kept by the name): still found once
	C.data["mercs"]["Charlie"] = {"name": "Charlie", "missions": 7, "xp": 900}
	var d: Dictionary = G.new_merc("Charlie")
	var k6: Dictionary = C.keep_merc(d)
	var t6: bool = int(k6["missions"]) == 7 and not C.data["mercs"].has("Charlie") and C.data["mercs"].has(String(d["uid"]))
	print("[MERC] old name record taken over once: %s" % t6)
	# 7. old soldiers get an id on load
	var cf := ConfigFile.new()
	var old_m := {"name": "Delta", "missions": 2, "locker": {"rifle_clip": 2}}
	cf.set_value("merc", "roster", [old_m])
	cf.set_value("merc", "active", 0)
	cf.save("user://merc.cfg")
	G.load_merc()
	var t7: bool = String(G.merc.get("uid", "")) != "" and String(G.merc.get("gear_cid", "")) == cid
	print("[MERC] old soldier gets id, locker home = this computer's campaign: %s" % t7)
	ok = t1 and t2 and t3 and t4 and t5 and t6 and t7
	print("RESULT merctest %s" % ("ok" if ok else "FAIL"))
	for f in FILES:
		if bak[f] == null:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
		else:
			var fa := FileAccess.open(f, FileAccess.WRITE)
			fa.store_buffer(bak[f])
			fa.close()
	quit()
