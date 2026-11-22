extends SceneTree
## (0.72.x, Ari: „při odeslání vojáka na marodku zmizí vybavení a nepřesune se do skladu")
## The own locker (things bought with the player's own money) goes with the player to the soldier
## he plays now - like the purse - and is never left behind on the soldier on the sick bay.
## godot --headless --path . -s tools/test/sickbaytest.gd   (backs up and restores merc.cfg / campaign.cfg)
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
	var cid := String(C.data["cid"])
	var day := float(C.data.get("day", 0.0))
	# 1. Alfa bought grenades and a medkit, came home wounded: off to the sick bay, Bravo goes next
	var a: Dictionary = G.new_merc("Alfa")
	var b: Dictionary = G.new_merc("Bravo")
	a["locker"] = {"grenade": 2, "medkit": 1}
	a["gear_cid"] = cid
	a["money"] = 300
	G.mercs = [a, b]
	G.active = 0
	G.merc = a
	G.wound(G.merc, 40.0, cid, day)
	var sick: bool = G.heal_days_left(G.merc) > 0.0
	var st0 := int(G.stash_for(false).get("grenade", 0))
	G.switch_merc(1)
	var t1: bool = sick and int(G.merc["locker"].get("grenade", 0)) == 2 and int(G.merc["locker"].get("medkit", 0)) == 1 \
		and (G.mercs[0].get("locker", {}) as Dictionary).is_empty() and int(G.merc["money"]) == 300 \
		and int(G.stash_for(false).get("grenade", 0)) == st0 and String(G.merc.get("gear_cid", "")) == cid
	print("[SICK] locker goes with the player to the next soldier: %s (stash grenades %d -> %d)" % [t1, st0, int(G.stash_for(false).get("grenade", 0))])
	ok = ok and t1
	# 2. healed, back to Alfa: the locker (with what Bravo bought) comes along again
	G.merc["locker"]["flare"] = 1
	G.switch_merc(0)
	var t2: bool = int(G.merc["locker"].get("grenade", 0)) == 2 and int(G.merc["locker"].get("flare", 0)) == 1 and (G.mercs[1].get("locker", {}) as Dictionary).is_empty()
	print("[SICK] and back: %s" % t2)
	ok = ok and t2
	# 3. lockers of other campaigns travel too, each one stays its campaign's
	G.merc["lockers"] = {"X": {"plasma_rifle": 1}}
	G.switch_merc(1)
	var t3: bool = G.merc.has("lockers") and int(G.merc["lockers"]["X"].get("plasma_rifle", 0)) == 1 and not G.merc["locker"].has("plasma_rifle")
	print("[SICK] other campaigns' lockers go along: %s" % t3)
	ok = ok and t3
	# 4. an older profile: the locker stuck on the soldier on the sick bay -> gathered at load
	G.mercs[0]["locker"] = {"rifle_clip": 3}
	G.mercs[0]["gear_cid"] = cid
	G.save_merc()
	G.load_merc()
	var t4: bool = G.active == 1 and int(G.merc["locker"].get("rifle_clip", 0)) == 3 and int(G.merc["locker"].get("grenade", 0)) == 2 and (G.mercs[0].get("locker", {}) as Dictionary).is_empty()
	print("[SICK] stuck locker from an older save gathered: %s" % t4)
	ok = ok and t4
	# 5. dismissing a soldier who is not played: what is in his locker stays with the player
	var c: Dictionary = G.new_merc("Charlie")
	c["locker"] = {"knife": 1}
	G.mercs.append(c)
	G.dismiss_merc(2)
	var t5: bool = G.mercs.size() == 2 and int(G.merc["locker"].get("knife", 0)) == 1
	print("[SICK] dismissed soldier's locker kept: %s" % t5)
	ok = ok and t5
	# 6. he falls: the new recruit takes the savings and the locker
	var fresh: Dictionary = G.lost_merc()
	var t6: bool = int(fresh["locker"].get("grenade", 0)) == 2 and int(fresh["locker"].get("knife", 0)) == 1 and String(fresh.get("gear_cid", "")) == cid
	print("[SICK] new recruit after a fallen one gets the locker: %s" % t6)
	ok = ok and t6
	G.merc = fresh
	G.mercs[G.active] = fresh
	# 7. co-op: the host's record of the soldier now played keeps the locker (keep_merc)
	var kept: Dictionary = C.keep_merc(G.merc)
	var rec: Dictionary = C.data["mercs"][String(G.merc["uid"])]
	var t7: bool = int(kept["locker"].get("grenade", 0)) == 2 and int(rec["locker"].get("grenade", 0)) == 2
	print("[SICK] host's record keeps the locker: %s" % t7)
	ok = ok and t7
	for f in FILES:
		if bak[f] == null:
			if FileAccess.file_exists(f):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
		else:
			var fa := FileAccess.open(f, FileAccess.WRITE)
			fa.store_buffer(bak[f])
			fa.close()
	print("RESULT sickbaytest %s" % ("ok" if ok else "FAIL"))
	quit()
