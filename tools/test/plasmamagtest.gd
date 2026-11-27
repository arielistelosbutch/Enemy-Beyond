extends SceneTree
## (0.72.8) The fighters' PL-MAG-01: a few shots no longer throw whole magazines away, the opened
## magazine's rest carries over to the next flight, and the wing shares the armory fairly.
## godot --headless --path . -s tools/test/plasmamagtest.gd   (saves and puts back campaign.cfg)

func _initialize() -> void:
	await process_frame
	var ok := true
	var C = root.get_node("Campaign")
	var path := "user://campaign.cfg"
	var had := FileAccess.file_exists(path)
	var backup := FileAccess.get_file_as_bytes(path) if had else PackedByteArray()
	C.new_campaign()
	C.active = true
	C.data["armory"]["plasma_cell"] = 4
	C.data["plasma_open"] = 0.0
	# 3 plasma MG shots and 1 cannon shot = 3/65 + 1/2 of a magazine -> one magazine opened, ~45 % left
	C.spend_plasma(3.0 / 65.0 + 0.5)
	var m1: int = C.plasma_mags()
	var o1 := float(C.data["plasma_open"])
	print("[PM] after small burst mags %d open %.2f pool %.2f" % [m1, o1, C.plasma_pool()])
	ok = ok and m1 == 3 and absf(o1 - (1.0 - 3.0 / 65.0 - 0.5)) < 0.01
	# the next flight burns 0.4: comes out of the opened one, no new magazine
	C.spend_plasma(0.4)
	print("[PM] after 0.4 mags %d open %.2f" % [C.plasma_mags(), float(C.data["plasma_open"])])
	ok = ok and C.plasma_mags() == 3
	# a big one: 2.3 magazines
	C.spend_plasma(2.3)
	print("[PM] after 2.3 mags %d open %.2f" % [C.plasma_mags(), float(C.data["plasma_open"])])
	ok = ok and C.plasma_mags() == 0 and float(C.data["plasma_open"]) > 0.7
	# nothing left: spending more cannot go below zero
	C.spend_plasma(5.0)
	ok = ok and C.plasma_mags() == 0 and float(C.data["plasma_open"]) == 0.0
	# the loadout: 1.5 magazines for two pilots -> each 0.75: cannon 1 shot, MG 16 shots
	var I = load("res://scripts/intercept.gd").new()
	# (0.72.8: a magazine = 4 cannon shots or 130 MG shots) 3 magazines for two pilots -> each 1.5:
	# cannon 5 shots (1.25), MG the rest 0.25 = 32 shots
	I.params = {"gun": "plasma", "heavy": "plasma_cannon", "plasma_pool": 3.0, "pilots": [1, 2], "gun_alt": "laser", "heavy_alt": "laser_cannon"}
	I._loadout()
	print("[PM] wing of 2 on 3 mags: heavy %s %d gun %s %d" % [I.heavy, I.heavy_ammo, I.gun, I.ammo])
	ok = ok and I.heavy == "plasma_cannon" and I.heavy_ammo == 5 and I.gun == "plasma" and I.ammo == 32
	I.free()
	var J = load("res://scripts/intercept.gd").new()
	J.params = {"gun": "plasma", "heavy": "plasma_cannon", "plasma_pool": 0.0, "pilots": [1], "gun_alt": "laser", "heavy_alt": "laser_cannon"}
	J._loadout()
	print("[PM] empty armory: heavy %s gun %s note '%s'" % [J.heavy, J.gun, J.mag_note])
	ok = ok and J.heavy == "laser_cannon" and J.gun == "laser" and J.mag_note != ""
	J.free()
	if had:
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_buffer(backup)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("RESULT plasmamag %s" % ("ok" if ok else "FAIL"))
	quit()
