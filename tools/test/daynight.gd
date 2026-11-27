extends SceneTree
## (2026-11-27, Ari: „hra ukazovala den, ale ve hře byla noc“) Den a noc v kampani:
##  1. glóbus (vzorec stínu z globe.gdshader + geoscape.latlon_to_local) a mise (Campaign.sun_at / phase_of)
##     se shodnou na každém místě a v každou hodinu, v dubnu, v létě i v zimě;
##  2. „Při příletu“ na glóbu = fáze, kterou tým na místě opravdu dostane (Čáp i Kondor);
##     vypíše i, jak často se lišila fáze „teď“ od fáze při příletu (to ukazoval glóbus dřív);
##  3. roční doby: délka dne v Praze v červnu ~16 h, v prosinci ~8 h, na rovníku ~12 h.
## godot --headless --path . -s tools/test/daynight.gd
func _initialize() -> void:
	await process_frame
	var C = root.get_node("Campaign")
	var G := load("res://scripts/geoscape.gd")
	var keep: Dictionary = C.data
	C.data = {"day": 0.0, "base_lat": 49.5, "base_lon": 15.6, "crafts": []}
	var ok := true
	var rng := RandomNumberGenerator.new()
	rng.seed = 1990
	# 1. globe vs mission
	var n := 0
	var bad := 0
	for day in [0.0, 58.0, 150.0, 241.0, 330.0]:
		for step in 96:
			C.data["day"] = day + step / 96.0
			var ss: Vector2 = C.subsolar()
			var sd: Vector3 = G.latlon_to_local(ss.x, ss.y)
			for pl in C.PLACES:
				var l: float = G.latlon_to_local(pl[1], pl[2]).dot(sd)
				var k := smoothstep(-0.12, 0.18, l)       # globe.gdshader: how lit the globe is there
				var ph: String = C.day_phase(pl[2], pl[1])
				n += 1
				if (ph == "noc" and k > 0.06) or (ph == "den" and k < 0.9):
					bad += 1
					if bad < 5:
						print("[DAYNIGHT] globe/mission differ: %s day %.2f phase %s globe light %.2f" % [pl[0], C.data["day"], ph, k])
	print("[DAYNIGHT] globe vs mission: %d / %d differ" % [bad, n])
	ok = ok and bad == 0
	# 2. the forecast on the globe = what the team lands into
	for kind in ["heli", "kondor"]:
		var tot := 0
		var was := 0
		var miss := 0
		for i in 3000:
			var pl: Array = C.PLACES[rng.randi() % C.PLACES.size()]
			var d0 := rng.randf_range(0.0, 365.0)
			C.data["day"] = d0
			var m := {"id": i, "lat": pl[1], "lon": pl[2]}
			var now: String = C.day_phase(pl[2], pl[1])
			var said: String = C.arrival_text(m, kind)
			# the clock runs until the transport lands, then the mission is built like on the globe
			C.data["day"] = d0 + C.eta_hours(kind, pl[1], pl[2]) / 24.0
			var sun: Vector2 = C.sun_at(pl[1], pl[2])
			var landed: String = C.phase_of(sun.x, C.local_hour(pl[2]))
			tot += 1
			if (now == "noc") != (landed == "noc"):
				was += 1
			if not said.ends_with(C.PHASE_TEXT[landed]):
				miss += 1
		print("[DAYNIGHT] %s: night/day now vs at landing differ %d / %d (old globe text), forecast wrong %d" % [kind, was, tot, miss])
		ok = ok and miss == 0
	# 3. seasons
	var lens := []
	for c in [[50.1, 14.4, 58.0, 15.3, 16.9], [50.1, 14.4, 241.0, 7.5, 8.9], [0.0, 30.0, 58.0, 11.6, 12.6], [0.0, 30.0, 241.0, 11.6, 12.6], [50.1, 14.4, 0.0, 13.6, 14.8]]:
		var up := 0
		for s in 1440:
			C.data["day"] = float(c[2]) + s / 1440.0
			if C.sun_at(c[0], c[1]).x > -0.83:
				up += 1
		var hrs := up / 60.0
		lens.append("%.1f/%.1f/day%d %.1f h" % [c[0], c[1], int(c[2]), hrs])
		if hrs < c[3] or hrs > c[4]:
			ok = false
			print("[DAYNIGHT] day length off: ", lens[-1])
	print("[DAYNIGHT] day lengths: " + ", ".join(lens))
	# a craft already on the way: the forecast counts from where it is
	C.data["day"] = 10.0
	C.data["crafts"] = [{"id": 1, "kind": "heli", "lat": 30.0, "lon": 31.0, "target": 77, "ttype": "mission", "state": "out"}]
	var near: String = C.arrival_text({"id": 77, "lat": 30.0, "lon": 31.2}, "heli")
	var lh: float = C.local_hour(31.2, 0.05)
	var fly_ok := near.begins_with("%02d:" % int(lh))
	print("[DAYNIGHT] craft on the way: %s (local now %.2f) %s" % [near, C.local_hour(31.2), "ok" if fly_ok else "bad"])
	ok = ok and fly_ok
	C.data = keep
	print("RESULT daynight %s" % ("ok" if ok else "FAIL"))
	quit()
