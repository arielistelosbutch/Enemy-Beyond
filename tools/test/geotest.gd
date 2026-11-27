extends SceneTree
## (Ari, 2026-11-27: „občas to vyhodí špatné místo na glóbusu, stalo se nám to u Egypta“, „Sahara,
## teror a byl tam trávník a domečky“) The places, countries and the ground of the missions.
## godot --headless --path . -s tools/test/geotest.gd   (backs up and restores campaign.cfg)
const F := "user://campaign.cfg"

# known points: [lat, lon, country (1990), climate]  ("" = do not check)
const KNOWN := [
	[30.04, 31.24, "Egypt", "desert"], [26.0, 28.0, "Egypt", "desert"], [24.0, 33.0, "Egypt", "desert"], [22.6, 31.0, "Egypt", "desert"],
	[25.3, 26.5, "Egypt", "desert"], [25.0, 23.5, "Libye", "desert"], [20.5, 30.0, "Súdán", "desert"], [15.6, 32.5, "Súdán", "dry"],
	[27.0, 17.0, "Libye", "desert"], [24.7, 46.7, "Saúdská Arábie", "desert"], [29.55, 34.95, "Izrael", "desert"], [31.95, 35.93, "Jordánsko", ""],
	[13.0, 15.0, "Čad", "dry"], [17.0, 18.0, "Čad", "desert"], [25.0, 4.0, "Alžírsko", "desert"], [16.8, -3.0, "Mali", "desert"],
	[50.09, 14.42, "Československo", "temperate"], [48.15, 17.11, "Československo", "temperate"], [52.52, 13.4, "NDR", "temperate"],
	[48.14, 11.58, "NSR", "temperate"], [50.45, 30.52, "SSSR", "temperate"], [55.75, 37.62, "SSSR", "temperate"], [44.8, 20.47, "Jugoslávie", "temperate"],
	[36.17, -115.14, "USA", "desert"], [33.45, -112.07, "USA", "desert"], [40.71, -74.0, "USA", "temperate"], [-23.7, 133.88, "Austrálie", "desert"],
	[-3.1, -60.0, "Brazílie", "tropic"], [-4.3, 15.3, "Zair", "tropic"], [-6.2, 106.8, "Indonésie", "tropic"], [1.35, 103.8, "Singapur", "tropic"],
	[39.0, 83.0, "Čína", "desert"], [43.0, 105.0, "Mongolsko", "desert"], [-23.0, 15.5, "Namibie", "desert"], [-24.0, -69.5, "Chile", "desert"],
	[64.0, -42.0, "Grónsko", "ice"], [35.7, 51.4, "Írán", ""], [28.6, 77.2, "Indie", "dry"], [10.0, 76.3, "Indie", "tropic"],
	[19.4, -99.1, "Mexiko", "dry"], [-1.29, 36.82, "Keňa", "dry"], [-34.6, -58.4, "Argentina", "temperate"],
]

func _initialize() -> void:
	await process_frame
	var bak = FileAccess.get_file_as_bytes(F) if FileAccess.file_exists(F) else null
	var C = root.get_node("Campaign")
	C.new_campaign()
	var bad := []
	for k in KNOWN:
		var cn: String = C.country_name(k[0], k[1])
		var cl: String = C.climate_at(k[0], k[1])
		if cn != k[2] or (k[3] != "" and cl != k[3]):
			bad.append("%s,%s=%s/%s (want %s/%s)" % [k[0], k[1], cn, cl, k[2], k[3]])
	print("[GEO] known points %d, wrong %d %s" % [KNOWN.size(), bad.size(), bad])
	# every city lies in its country, on land
	var cbad := []
	for c in C.GeoData.CITIES:
		var cn: String = C.country_name(float(c[2]), float(c[3]))
		if cn != String(c[1]):
			cbad.append("%s: %s" % [c[0], cn])
	print("[GEO] cities %d, outside their country %d %s" % [C.GeoData.CITIES.size(), cbad.size(), cbad])
	# names: a sample of land points - the name's country is the place's country
	var nbad := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var n := 0
	while n < 3000:
		var la := rad_to_deg(asin(rng.randf_range(-0.85, 0.95)))
		var lo := rng.randf_range(-180, 180)
		if not C.is_land(la, lo):
			continue
		n += 1
		var cn: String = C.country_name(la, lo)
		var pl: String = C.nearest_place(la, lo)
		if cn == "" or not (pl == cn or pl.ends_with(", " + cn) or cn == "Československo"):
			nbad.append("%.1f,%.1f %s/%s" % [la, lo, pl, cn])
	print("[GEO] names of 3000 land points, wrong %d %s" % [nbad.size(), nbad.slice(0, 8)])
	# the missions: ground and map as the place is
	var mbad := []
	var counts := {}
	C.data["day"] = 40.0
	C.data["month"] = 4
	for i in 4000:
		var m: Dictionary = C.generate_mission()
		var la := float(m["lat"]); var lo := float(m["lon"])
		var terr := String(m["terrain"])
		var key := "%s/%s" % [terr, m["biome"]]
		counts[key] = int(counts.get(key, 0)) + 1
		if String(m["biome"]) != "polar" and terr != C.terrain_at(la, lo):
			mbad.append("terrain %s at %.1f,%.1f" % [terr, la, lo])
		if terr == "desert" and String(m["biome"]) in ["farm", "forest", "mountain"]:
			mbad.append("desert with %s" % m["biome"])
		if String(m["type"]) in ["terror", "quarantine"]:
			var city := false
			for c in C.GeoData.CITIES:
				if String(m["place"]) == "%s, %s" % [c[0], c[1]] and C.arc_deg(la, lo, float(c[2]), float(c[3])) < 0.2:
					city = true
			if not city:
				mbad.append("terror not in a city: %s" % m["place"])
		elif C.country_name(la, lo) != "" and not String(m["place"]).contains(C.country_name(la, lo)) and C.country_name(la, lo) != "Československo":
			mbad.append("place %s at %.1f,%.1f (%s)" % [m["place"], la, lo, C.country_name(la, lo)])
	# a crash in the desert stays a desert crash
	var cr: Dictionary = C.generate_mission(Vector2(26.0, 28.0), "crash")
	if cr["type"] != "crash" or cr["terrain"] != "desert" or cr["biome"] in ["farm", "forest", "mountain"]:
		mbad.append("crash in the Egyptian desert: %s %s" % [cr["terrain"], cr["biome"]])
	print("[GEO] 4000 missions, wrong %d %s" % [mbad.size(), mbad.slice(0, 8)])
	print("[GEO] terrain/biome: %s" % counts)
	if bak != null:
		var f := FileAccess.open(F, FileAccess.WRITE); f.store_buffer(bak); f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(F))
	print("RESULT geotest %s" % ("ok" if bad.is_empty() and cbad.is_empty() and nbad.is_empty() and mbad.is_empty() else "FAIL"))
	quit()
