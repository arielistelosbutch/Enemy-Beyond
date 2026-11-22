extends SceneTree
## (Ari, 2026-11-22) The same thing put into the workshop several times is one queue line with a
## count, not new lines; an order can be taken back (one piece or all) with everything paid returned. Older saves with the same item on several lines are folded at load.
## godot --headless --path . -s tools/test/stacktest.gd   (backs up and restores campaign.cfg)
const F := "user://campaign.cfg"

func _initialize() -> void:
	await process_frame
	var bak = FileAccess.get_file_as_bytes(F) if FileAccess.file_exists(F) else null
	var C = root.get_node("Campaign")
	C.new_campaign()
	C.data["credits"] = 100000
	C.data["moskovium"] = 1000
	C.data["orders"] = []
	var done: Array = C.data["research"]["done"]
	for r in ["rozbor_plazma", "laser", "laser_puska", "laser_pistole"]:
		if not r in done:
			done.append(r)
	var dilna := false
	for cell in C.data["base"]:
		if String(cell.get("type", "")) == "dilna" and float(cell.get("days", 0.0)) <= 0.0:
			dilna = true
	if not dilna:
		C.data["base"].append({"type": "dilna", "x": 5, "y": 3, "days": 0.0})
	var rate: float = C.workshop_rate()
	var each: float = C.make_days("laser_rifle")
	# --- three rifles and a pistol: two lines, the rifles counted on one
	var ok_make: bool = C.make("laser_rifle") and C.make("laser_rifle") and C.make("laser_pistol") and C.make("laser_rifle")
	var made: Array = C._made_orders()
	var t1: bool = ok_make and made.size() == 2 and C.order_n(made[0]) == 3 and C.order_n(made[1]) == 1 \
		and C.on_order("laser_rifle") == 3 and C.on_order("laser_pistol") == 1
	print("[STACK] 3 rifles + 1 pistol -> lines %d, rifles %d on one line, on_order %d: %s" % [made.size(), C.order_n(made[0]), C.on_order("laser_rifle"), t1])
	# the eta of the rifle line is when the last of the three is done; the pistol waits behind them
	var day0 := float(C.data["day"])
	var eta_ok: bool = absf(C.made_at("laser_rifle") - (day0 + 3.0 * each / rate)) < 0.01 \
		and C.made_at("laser_pistol") > C.made_at("laser_rifle")
	var now: Dictionary = C.workshop_now()
	var t2: bool = eta_ok and int(now.get("more", 0)) == 3 and int(now.get("n", 0)) == 3
	print("[STACK] eta of the last rifle %.2f (want %.2f), pistol after it, globe 'more' %d: %s" % [C.made_at("laser_rifle"), day0 + 3.0 * each / rate, int(now.get("more", 0)), t2])
	# --- pieces come out one by one
	var a0 := int(C.data["armory"].get("laser_rifle", 0))
	C.advance(each / rate * 1.05)
	var one: bool = int(C.data["armory"].get("laser_rifle", 0)) == a0 + 1 and C.order_n(C._made_orders()[0]) == 2
	C.advance(each / rate * 2.1)
	var three: bool = int(C.data["armory"].get("laser_rifle", 0)) == a0 + 3 and C.on_order("laser_rifle") == 0 \
		and C._made_orders().size() == 1
	var t3: bool = one and three
	print("[STACK] one after one piece time %s, all three after three %s" % [one, three])
	# --- an older save: the same item on three lines, the first part-made, folded at load
	C.data["orders"] = [
		{"item": "laser_rifle", "work": each * 0.4, "total": each, "at": 0.0, "made": true},
		{"item": "laser_pistol", "work": 1.0, "total": 1.0, "at": 0.0, "made": true},
		{"item": "laser_rifle", "work": each, "total": each, "at": 0.0, "made": true},
		{"item": "craft_kondor", "work": 4.0, "total": 4.0, "at": 0.0, "made": true},
		{"item": "laser_rifle", "work": each, "total": each, "at": 0.0, "made": true},
		{"item": "rifle_clip", "at": float(C.data["day"]) + 1.0}]
	C.save()
	C.load_campaign()
	var m2: Array = C._made_orders()
	var t4: bool = m2.size() == 3 and String(m2[0]["item"]) == "laser_rifle" and C.order_n(m2[0]) == 3 \
		and absf(float(m2[0]["work"]) - each * 0.4) < 0.001 and C.on_order("laser_rifle") == 3 \
		and C.on_order("rifle_clip") == 1 and C.on_order("craft_kondor") == 1
	print("[STACK] old save: made lines %d, rifles %d on the first line, part-made work kept: %s" % [m2.size(), C.order_n(m2[0]), t4])
	# --- crafts are never stacked
	C._queue("craft_kondor", 4.0)
	var t5: bool = C.on_order("craft_kondor") == 2 and C.crafts_coming("kondor") == 2
	print("[STACK] crafts keep their own lines: %s" % t5)
	# --- (Ari 2026-11-22) cancelling: one piece or the whole line, everything paid comes back
	C.data["orders"] = []
	C.data["credits"] = 100000
	var cr0 := int(C.data["credits"])
	var mk0: int = C.moskovium()
	var al0: int = C.alloys()
	var pr: int = C.price("laser_rifle")
	C.make("laser_rifle"); C.make("laser_rifle"); C.make("laser_rifle")
	var line: Dictionary = C._made_orders()[0]
	C.advance(each / rate * 0.5)            # the first one half made
	var work_half := float(line["work"])
	var c1: bool = C.cancel_order(line, false) and C.order_n(line) == 2 and int(C.data["credits"]) == cr0 - 2 * pr \
		and absf(float(line["work"]) - work_half) < 0.0001
	C.viewer = true
	var c_view: bool = not C.cancel_order(line, true)
	C.viewer = false
	var c2: bool = C.cancel_order(line, true) and C.on_order("laser_rifle") == 0 and int(C.data["credits"]) == cr0 \
		and C.moskovium() == mk0 and C.alloys() == al0
	var logged: bool = String((C.data["log"] as Array)[-1]).contains("zrušila")
	# a craft line (one of a kind) and an order from an older save without the price kept
	C._queue("craft_kondor", 4.0, {}, {"cr": 1500})
	var c3: bool = C.cancel_order(C._made_orders()[0], false) and int(C.data["credits"]) == cr0 + 1500 and C._made_orders().is_empty()
	C.data["orders"] = [{"item": "laser_rifle", "work": each, "total": each, "n": 2, "at": 0.0, "made": true}]
	var cr1 := int(C.data["credits"])
	var c4: bool = C.cancel_order(C.data["orders"][0], true) and int(C.data["credits"]) == cr1 + 2 * pr
	var t6: bool = c1 and c_view and c2 and logged and c3 and c4
	print("[STACK] cancel one piece %s, host only %s, whole line all back %s, logged %s, craft %s, old save %s" % [c1, c_view, c2, logged, c3, c4])
	if bak == null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(F))
	else:
		var f := FileAccess.open(F, FileAccess.WRITE)
		f.store_buffer(bak)
		f.close()
	print("RESULT stacktest %s" % ("ok" if t1 and t2 and t3 and t4 and t5 and t6 else "FAIL %s %s %s %s %s %s" % [t1, t2, t3, t4, t5, t6]))
	quit()
