extends SceneTree
## (Ari, 2026-11-22) Base rooms can be torn down (part of the money back) and rebuilt as another room;
## what holds the base together cannot go (the lift, hangar, quarters, a room others hang on, the last
## laboratory, the last workshop with work in it, the cell with a live prisoner, anything under attack).
## godot --headless --path . -s tools/test/basesell.gd   (backs up and restores campaign.cfg)
const F := "user://campaign.cfg"

func _initialize() -> void:
	await process_frame
	var bak = FileAccess.get_file_as_bytes(F) if FileAccess.file_exists(F) else null
	var C = root.get_node("Campaign")
	C.new_campaign("normal")
	C.data["credits"] = 10000
	C.data["orders"] = []
	var W: int = C.GRID_W
	var ok := true
	# fixed rooms
	var fixed: bool = C.demolish_why(0) != "" and C.demolish_why(1) != "" and C.demolish_why(W) != "" \
		and not C.demolish(0) and C.rebuild_why(1, "sklad") != ""
	print("[SELL] velín, hangár, ubikace zůstávají: %s" % fixed)
	ok = ok and fixed
	# the last laboratory stays
	var lab: bool = C.demolish_why(W + 1) != "" and C.rebuild_why(W + 1, "sklad") != ""
	print("[SELL] poslední laboratoř: %s (%s)" % [lab, C.demolish_why(W + 1)])
	ok = ok and lab
	# a chain: dílna (2) - sklad (3) - radar (4): the sklad holds the radar
	C.build(3, "sklad")
	C.build(4, "radar")
	var cr0 := int(C.data["credits"])
	var linked: bool = C.demolish_why(3) != "" and C.rebuild_why(3, "strelnice") == ""
	print("[SELL] místnost, na které visí další: bourat ne, přestavět ano: %s" % linked)
	ok = ok and linked
	# calling off a dig gives back 75 %
	var back: int = C.refund_of(4)
	var cancel: bool = C.demolish(4) and String(C.data["base"][4]["type"]) == "" \
		and int(C.data["credits"]) == cr0 + back and back == int(round(C.facility_cost("radar") * 0.75 / 10.0) * 10)
	print("[SELL] zrušená stavba radaru vrátí %d kr: %s" % [back, cancel])
	ok = ok and cancel
	# a finished room gives back 30 %, rebuild pays the difference
	C.advance(10.0)
	var done_back: int = C.refund_of(3)
	var r30: bool = done_back == int(round(C.facility_cost("sklad") * 0.3 / 10.0) * 10)
	var cr1 := int(C.data["credits"])
	var rb: bool = C.rebuild(3, "strelnice") and String(C.data["base"][3]["type"]) == "strelnice" \
		and float(C.data["base"][3]["days"]) > 0.0 and int(C.data["credits"]) == cr1 - C.facility_cost("strelnice") + done_back
	print("[SELL] hotový sklad vrátí %d kr (30 %%) %s, přestavba na střelnici %s" % [done_back, r30, rb])
	ok = ok and r30 and rb
	# the workshop with work in it, then without
	C.data["orders"] = [{"item": "rifle_clip", "work": 1.0, "total": 1.0, "each": 1.0, "n": 1, "at": 0.0, "made": true}]
	var busy: bool = C.demolish_why(2) != ""
	C.data["orders"] = []
	# (the strelnice next to it still hangs on the dílna? 3 sits next to 2 only -> dílna holds it)
	var holds: bool = C.demolish_why(2) != ""
	print("[SELL] dílna s výrobou %s, dílna drží střelnici %s" % [busy, holds])
	ok = ok and busy and holds
	# a cell with a live prisoner
	C.advance(10.0)
	C.data["research"]["done"].append("pvo_silo")
	C.rebuild(3, "cela")
	C.advance(10.0)
	C.data["found"] = {"live_grey": 1}
	var jail: bool = C.demolish_why(3) != "" and C.rebuild_why(3, "radar") != ""
	C.data["found"] = {}
	var unique: bool = C.build(4, "sklad") and C.rebuild_why(4, "cela") != ""
	print("[SELL] cela se zajatcem %s, druhá cela ne %s" % [jail, unique])
	ok = ok and jail and unique
	# under attack nothing goes
	C.data["missions"].append({"type": "base", "expires": float(C.data["day"]) + 3.0})
	var attack: bool = C.demolish_why(4) != ""
	C.data["missions"] = C.data["missions"].filter(func(m): return String(m["type"]) != "base")
	# a viewer (co-op client) decides nothing
	C.viewer = true
	var view: bool = C.demolish_why(4) != "" and not C.demolish(4)
	C.viewer = false
	print("[SELL] při útoku %s, spoluhráč nerozhoduje %s" % [attack, view])
	ok = ok and attack and view
	# saved and loaded
	C.demolish(4)
	C.save()
	C.load_campaign()
	var saved: bool = String(C.data["base"][4]["type"]) == "" and String(C.data["base"][3]["type"]) == "cela"
	var logged: bool = (C.data["log"] as Array).any(func(l): return String(l).contains("Přestavba:")) \
		and (C.data["log"] as Array).any(func(l): return String(l).contains("Stavba zrušena:"))
	print("[SELL] uloženo a načteno %s, deník %s" % [saved, logged])
	ok = ok and saved and logged
	# the screen: the buttons are there for a room, not for the lift
	var host := Control.new()
	root.add_child(host)
	var bs = load("res://scripts/base_screen.gd").open(host, 3)
	await process_frame
	var has_btn: bool = bs.find_child("Demolish", true, false) != null and bs.find_child("Rebuild", true, false) != null
	bs.sel = 0
	bs.refresh()
	await process_frame
	var none_lift: bool = bs.find_child("Demolish", true, false) == null
	bs.sel = 3
	bs._start_rebuild()
	bs._set_pick("radar")
	var cr2 := int(C.data["credits"])
	bs._do_rebuild()
	var ui_rb: bool = String(C.data["base"][3]["type"]) == "radar" and int(C.data["credits"]) < cr2 + 1000 and not bs.rebuild
	print("[SELL] obrazovka: tlačítka u místnosti %s, u velínu nic %s, přestavba z obrazovky %s" % [has_btn, none_lift, ui_rb])
	ok = ok and has_btn and none_lift and ui_rb
	bs.queue_free()
	if bak != null:
		var f := FileAccess.open(F, FileAccess.WRITE)
		f.store_buffer(bak)
		f.close()
	elif FileAccess.file_exists(F):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(F))
	print("RESULT basesell %s" % ("ok" if ok else "FAIL"))
	quit()
