extends SceneTree
## (0.80, Ari) The alloy shield BSH-02 comes with the laser research and is made in the workshop from
## the alloys (Ari, 2026-11-22).
## godot --headless --path . -s tools/test/alloytest.gd   (backs up and restores campaign.cfg)
const F := "user://campaign.cfg"

func _initialize() -> void:
	await process_frame
	var bak = FileAccess.get_file_as_bytes(F) if FileAccess.file_exists(F) else null
	var C = root.get_node("Campaign")
	var G = root.get_node("Game")
	C.new_campaign()
	C.data["credits"] = 50000
	C.data["research"]["done"] = []
	var done: Array = C.data["research"]["done"]
	if not C.data.has("found"):
		C.data["found"] = {}
	# --- the shield
	var it: Dictionary = G.ITEMS.get("stit_x", {})
	var t1: bool = G.is_shield("stit_x") and G.is_shield("stit") and not G.is_shield("rifle") \
		and G.tweak_id("stit_x") == "stit" and ResourceLoader.exists("res://assets/models/stit_x.glb") \
		and FileAccess.file_exists("res://assets/icons/stit_x.png")
	print("[ALLOY] item, model, icon, anchors of BSH-01: %s" % t1)
	var locked: bool = not C.unlocked("stit_x") and C.workshop_item("stit_x")
	done.append("rozbor_plazma")
	done.append("laser")
	var opens: bool = C.unlocked("stit_x")
	print("[ALLOY] locked before the laser research %s, open after %s" % [locked, opens])
	# the workshop needs the alloys from the wrecks
	var dilna := false
	for cell in C.data["base"]:
		if String(cell.get("type", "")) == "dilna":
			dilna = true
	if not dilna:
		C.data["base"].append({"type": "dilna", "x": 5, "y": 3, "days": 0.0})
	C.data["found"]["slitiny"] = 0
	var no_al: bool = not C.can_make("stit_x")
	C.data["found"]["slitiny"] = 10
	var al0: int = C.alloys()
	var made: bool = C.make("stit_x")
	var paid: bool = C.alloys() == al0 - int(C.SHOP_AL["stit_x"])
	print("[ALLOY] workshop: none without alloys %s, made %s, alloys paid %s" % [no_al, made, paid])
	# the encyclopedia opens it with the laser research
	var ency := false
	var ED = load("res://scripts/ency_data.gd")
	for e in ED.entries():
		if String(e.get("id", "")) == "item_stit_x":
			ency = String(e.get("unlock", "")) == "res:laser" and String(e.get("text", "")).contains("BSH-02")
	print("[ALLOY] encyclopedia entry with the laser research: %s" % ency)
	var t2: bool = locked and opens and no_al and made and paid and ency
	if bak == null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(F))
	else:
		var f := FileAccess.open(F, FileAccess.WRITE)
		f.store_buffer(bak)
		f.close()
	print("RESULT alloytest %s" % ("ok" if t1 and t2 else "FAIL %s %s" % [t1, t2]))
	quit()
