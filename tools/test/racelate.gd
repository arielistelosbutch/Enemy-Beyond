extends SceneTree
## (2026-11-26) A race that joins the war late grows from its own first month (alien.RACE_FROM).
## godot --headless --path . -s tools/test/racelate.gd
func _initialize() -> void:
	await process_frame
	var A := load("res://scripts/alien.gd")
	var M := load("res://scripts/mission.gd")
	var ok := true
	# RACE_FROM must follow mission.GROUPS["from"]
	for g in M.GROUPS:
		var gr: Dictionary = M.GROUPS[g]
		for k in ["soldier", "officer", "beast", "terror"]:
			var r: String = gr[k]
			var want := 1000
			for g2 in M.GROUPS:
				for k2 in ["soldier", "officer", "beast", "terror"]:
					if M.GROUPS[g2][k2] == r:
						want = mini(want, int(M.GROUPS[g2]["from"]))
			if int(A.RACE_FROM.get(r, 0)) != want:
				print("FAIL race_from %s %d != %d" % [r, int(A.RACE_FROM.get(r, 0)), want])
				ok = false
	var net = root.get_node("Net")
	var out := []
	for day in [10.0, 60.0, 103.0, 200.0]:
		net.mission_params = {"day": day}
		var row := "day %d:" % int(day)
		for r in ["grey", "levit", "jestetan", "bijec"]:
			row += " %s %.2f" % [r, float(A.threat(r)["late"])]
		out.append(row)
	print("[RACELATE] " + " | ".join(out))
	net.mission_params = {"day": 103.0}
	ok = ok and is_equal_approx(float(A.threat("grey")["late"]), 88.0 / 90.0)
	ok = ok and is_equal_approx(float(A.threat("bijec")["late"]), 13.0 / 90.0)
	ok = ok and is_equal_approx(float(A.threat("jestetan")["late"]), 43.0 / 90.0)
	net.mission_params = {"day": 200.0}
	ok = ok and float(A.threat("bijec")["late"]) == 1.0
	ok = ok and float(A.RACES["jestetan"]["bite"][1]) <= 30.0
	net.mission_params = {}
	print("RESULT racelate %s" % ("ok" if ok else "FAIL"))
	quit(0 if ok else 1)
