extends SceneTree
## (0.80) Strategic play-through of the whole campaign, without the missions themselves: a simple
## "player" researches, builds, intercepts and goes on missions, the outcome of a mission is a
## dice roll (by difficulty and crew size), the crew is the game's own (mission._crew), the loot
## like mission._loot. Answers: can the campaign be finished, how long it takes, where it stalls,
## whether the money and trust hold.
## godot --headless --path . -s tools/test/campsim.gd -- [--runs=20] [--diff=easy,normal,veteran]
##   [--players=1] [--attend=0.7] [--win=0.85,0.78,0.7] [--days=400] [--log=1]
## (backs up and restores user://campaign.cfg)
const SAVE := "user://campaign.cfg"
var C
var G
var N
var M          # a mission script instance (only for _crew)
var R := RandomNumberGenerator.new()
var verbose := false

## What the player researches first: the way to Mars, then what helps on the way.
const PRIORITY := ["pitva", "zenijni", "tezke", "vesta", "rozbor_plazma", "vyslech", "slitiny", "kondor",
	"laser", "moskovium", "pancir", "pvo_silo", "vzduch_laser", "laser_puska", "medicina", "pitva_levit", "pitva_ohar",
	"pitva_jestetan", "pitva_bijec", "pitva_lihnoun", "pitva_nador", "pitva_ohnivec", "pitva_myslodej",
	"rozbor_diskoll", "rozbor_kolos", "vyslech_velitel", "signal", "psi_clona", "pvo_laser", "plazma",
	"orel", "kdo_invaze", "psi_ochrana", "ruda_planeta", "vzduch_laser_delo", "plazma_puska", "pvo_plazma", "maskovani"]
## What gets built, in this order (when the money and the research allow, keeping a reserve).
const BUILD := ["cela", "laborator", "radar", "dilna", "silo", "laser_vez", "laborator", "sklad", "plazma_vez", "osetrovna", "maskovani", "laser_vez"]

func arg(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + k + "="):
			return a.substr(k.length() + 3)
	return d

func _initialize() -> void:
	await process_frame
	var bak = FileAccess.get_file_as_bytes(SAVE) if FileAccess.file_exists(SAVE) else null
	C = root.get_node("Campaign")
	G = root.get_node("Game")
	N = root.get_node("Net")
	M = load("res://scripts/mission.gd").new()
	verbose = arg("log", "0") == "1"
	var runs := int(arg("runs", "20"))
	var players := int(arg("players", "1"))
	var wins := arg("win", "0.85,0.78,0.70").split(",")
	var diffs := arg("diff", "easy,normal,veteran").split(",")
	var all_d := ["easy", "normal", "veteran"]
	for d in diffs:
		var pw := float(wins[all_d.find(d)])
		var res := []
		for i in runs:
			res.append(play(d, 1000 + i, players, pw))
		report(d, players, pw, res)
	M.free()
	if bak != null:
		var f := FileAccess.open(SAVE, FileAccess.WRITE)
		f.store_buffer(bak)
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	quit()

func play(diff: String, sd: int, players: int, p_win: float) -> Dictionary:
	seed(sd)
	R.seed = sd
	C.rng.seed = sd
	C.new_campaign(diff)
	C.found_base(C.BASE_LAT, C.BASE_LON)
	var attend := float(arg("attend", "0.7"))
	var days := float(arg("days", "400"))
	var out := {"diff": diff, "end": "", "day": 0.0, "first": {}, "money": [], "trust": [], "missions": 0, "won_m": 0,
		"skipped": 0, "base_fights": 0, "strikes": 0, "stall": ""}
	var tried := {}
	var step := 0.05
	while float(C.data["day"]) < days:
		var t0 := int(C.data["trust"])
		C.advance(step)
		_tr(out, "čas (nevyřízené mise)", int(C.data["trust"]) - t0)
		if arg("safe", "0") == "1":
			C.data["trust"] = maxi(int(C.data["trust"]), 40)
		if C.data.get("lost", false) or C.is_over():
			out["end"] = String(C.data.get("end_why", "lost"))
			break
		if C.won():
			out["end"] = "won"
			break
		var month := int(float(C.data["day"]) / 30.0)
		if out["money"].size() <= month:
			out["money"].append(int(C.data["credits"]))
			out["trust"].append(int(C.data["trust"]))
		_manage()
		# the radar: UFOs in flight
		for f in (C.data["flights"] as Array).duplicate():
			if tried.has("f%d" % int(f["id"])):
				continue
			tried["f%d" % int(f["id"])] = true
			if f.get("strike", false):
				out["strikes"] += 1
			if f.get("strike", false) and arg("safe", "0") == "1":
				C.data["flights"].erase(f)
				continue
			if C.jets_ready() > 0 and (f.get("strike", false) or R.randf() < 0.75):
				var oc := _air(String(f["kind"]))
				if f.get("strike", false) and arg("safe", "0") == "1":
					oc = "crashed"
				C.intercept_done(int(f["id"]), oc, String(f["kind"]), 80.0)
		# missions on the globe
		for m in (C.data["missions"] as Array).duplicate():
			var key := "m%d" % int(m["id"])
			if tried.has(key):
				continue
			if m["type"] == "mars" and not C.built("psi_ochrana"):
				continue
			tried[key] = true
			var go: bool = m["type"] in ["base", "mars", "alienbase"] or R.randf() < attend
			if not go:
				out["skipped"] += 1
				continue
			if m["type"] == "base":
				out["base_fights"] += 1
			var t1 := int(C.data["trust"])
			_fight(m, players, p_win)
			_tr(out, "mise " + String(m["type"]), int(C.data["trust"]) - t1)
			if m["type"] == "mars" and not C.won():
				tried.erase(key)     # the Pelikán flies again
			out["missions"] += 1
	out["day"] = float(C.data["day"])
	if verbose:
		for l in (C.data["log"] as Array).slice(-int(arg("logn", "40"))):
			print("  LOG " + String(l))
	for r in C.data["research"]["done"]:
		out["first"][r] = float(C.data.get("_t_" + String(r), 0.0))
	out["done"] = (C.data["research"]["done"] as Array).duplicate()
	out["pelikan"] = C.pelikan()
	out["found"] = (C.data.get("found", {}) as Dictionary).duplicate()
	out["seen"] = (C.data.get("seen_races", []) as Array).duplicate()
	if out["end"] == "":
		out["end"] = "time"
		out["stall"] = _stall()
	return out

## What blocks the way to Mars at the end of the time.
func _stall() -> String:
	for id in ["kdo_invaze", "orel", "ruda_planeta", "psi_ochrana"]:
		if not C.researched(id):
			var miss := []
			for r in C.RESEARCH[id]["needs"].get("research", []):
				if not C.researched(r):
					miss.append(r + "(" + C.needs_text(r) + ")")
			return id + " <- " + ", ".join(miss)
	if not C.pelikan():
		return "Pelikán nepostaven"
	if not C.built("psi_ochrana"):
		return "psi_ochrana nevyrobena"
	return "Mars neuspěl"

func _tr(out: Dictionary, k: String, dv: int) -> void:
	if dv == 0:
		return
	var mon := "m%d" % int(float(C.data["day"]) / 30.0)
	var t: Dictionary = out.get_or_add("tr", {})
	var mm: Dictionary = t.get_or_add(mon, {})
	mm[k] = int(mm.get(k, 0)) + dv

func _air(kind: String) -> String:
	var better := 0.0
	if C.built("vzduch_laser"):
		better += 0.12
	if C.built("vzduch_plazma"):
		better += 0.12
	var hard: float = {"scout": 0.0, "raider": 0.1, "harvester": 0.2, "supply": 0.35, "battleship": 0.5}[kind]
	var r := R.randf()
	var crash := clampf(0.55 - hard + better, 0.05, 0.85)
	if r < crash:
		return "crashed"
	if r < crash + 0.12:
		return "destroyed"
	if r < crash + 0.12 + 0.12 + hard * 0.3:
		return "shot_down"
	return "escaped"

func _fight(m: Dictionary, players: int, p_win: float) -> void:
	var mp: Dictionary = C.mission_params(m)
	N.mission_params = mp
	G.difficulty = C.difficulty()
	var mt := String(m["type"])
	var ext := int(m.get("extra_aliens", 0))
	var size_add := int({"large": 1, "huge": 2, "colossal": 4}.get(m.get("size", ""), 0))
	var vet := 1 if C.difficulty() == "veteran" else (-1 if C.difficulty() == "easy" else 0)
	var count := (1 if players <= 1 else 2) + players + (5 if String(m.get("ufo", "")) in ["battleship", "supply"] else 0) + ext + vet + size_add + maxi(0, players - 1)
	M._crew_cap = 0
	var kind := String(m.get("crew_of", ""))
	if M.SHIP_CREW.has(kind) and mt in ["crash", "landed", "bug"]:
		var sc: Array = M.SHIP_CREW[kind]
		count = int(ceil(float(sc[0]) + float(sc[1]) * maxi(0, players - 1) - 0.001)) + (1 if mt in ["landed", "bug"] else 0) + vet
		M._crew_cap = int(sc[2])
	if mt == "base":
		count = int(ceil(float(M.BASE_CREW[0]) + float(M.BASE_CREW[1]) * maxi(0, players - 1) - 0.001)) + ext + vet
		M._crew_cap = int(M.BASE_CREW[2]) + ext
	if M.SITE_CREW.has(mt):
		var scc: Array = M.SITE_CREW[mt]
		count = int(ceil(float(scc[0]) + float(scc[1]) * maxi(0, players - 1) - 0.001)) + ext / 2 + vet
		M._crew_cap = int(scc[2])
	var rng := RandomNumberGenerator.new()
	rng.seed = R.randi()
	var crew: Array = M._crew(count, rng)
	if mt == "quarantine":
		crew = ["nador"]
		for k in maxi(1, count - 1):
			crew.append("zombie")
	if mt == "mars":
		crew = ["myslodej", "bijec", "bijec", "kolos"]
	var p := clampf(p_win - 0.025 * maxi(0, crew.size() - 5) / float(players), 0.15, 0.97)
	if mt == "mars":
		p = p_win * 0.75
	if arg("safe", "0") == "1" and mt == "base":
		p = 1.0
	var ok := R.randf() < p
	var loot := {}
	var kills := 0
	var caps := 0
	if ok:
		var cap_k := 0.18 if C.count("cela") > 0 else 0.0
		for a in crew:
			var race := String(a)
			if R.randf() < cap_k and not race in C.WRECKS and not race in ["kolos", "ohnivec"]:
				loot["live_" + race] = int(loot.get("live_" + race, 0)) + 1
				caps += 1
				continue
			kills += 1
			if race in C.WRECKS:
				loot["trosky_" + race] = int(loot.get("trosky_" + race, 0)) + 1 if race == "kolos" else 1
			elif R.randf() > 0.08:
				loot["corpse_" + race] = int(loot.get("corpse_" + race, 0)) + 1
				if C.RACE_WEAPON.has(race) and R.randf() < 0.6:
					loot[C.RACE_WEAPON[race]] = int(loot.get(C.RACE_WEAPON[race], 0)) + 1
		var mk: Array = {"crash": [25, 50], "landed": [50, 100], "abduction": [30, 60], "terror": [10, 25], "rescue": [10, 30], "pilot": [5, 15], "bug": [0, 0], "quarantine": [10, 25], "radar": [30, 60], "sabotage": [30, 60], "base": [40, 80], "convoy": [40, 80]}.get(mt, [0, 0])
		var al: Array = {"crash": [6, 14], "landed": [10, 20], "abduction": [6, 12], "terror": [0, 3], "rescue": [2, 6], "pilot": [1, 4], "bug": [0, 3], "quarantine": [0, 3], "radar": [6, 12], "sabotage": [6, 12], "base": [8, 16], "convoy": [8, 16]}.get(mt, [0, 0])
		loot["moskovium"] = R.randi_range(mk[0], mk[1])
		loot["slitiny"] = R.randi_range(al[0], al[1])
		if mt == "crash" and String(m.get("ufo", "")) != "":
			loot["vrak_" + String(m["ufo"])] = 1
		if mt == "bug" and R.randf() < 0.6:
			loot["bug_tag"] = 1
	else:
		kills = int(crew.size() * 0.4)
	var civ := 0
	if mt in ["terror", "rescue", "abduction", "quarantine"] and ok:
		civ = R.randi_range(2, 6)
	var lost := 0 if ok and R.randf() < 0.7 else R.randi_range(1, players)
	C.mission_done(int(m["id"]), ok, kills, caps, lost, civ, 0 if ok else R.randi_range(1, 4), crew, loot, not ok and R.randf() < 0.3)
	if verbose:
		print("  d%.1f %s %s %s -> %s" % [float(C.data["day"]), mt, crew, "OK" if ok else "FAIL", loot.keys()])

func _manage() -> void:
	var d: Dictionary = C.data
	# research: the first available one in the order
	if d["research"]["current"] == "":
		for id in PRIORITY:
			if C.research_available(id) and C.start_research(id):
				d["_t_" + id] = float(d["day"])     # (start day; the end day = the next start, roughly)
				break
	var reserve := 500 + int(d["day"]) * 4
	# the black market: alien guns beyond one of each, alloys beyond what the Pelikán needs
	var fd: Dictionary = d.get("found", {})
	for k in ["a_pistol", "a_rifle", "a_heavy"]:
		while int(fd.get(k, 0)) > 1 and C.sell_loot(k):
			pass
	while C.alloys() > 140 and C.sell_loot("slitiny"):
		pass
	# workshop: the way to Mars first
	if C.can_make_kondor():
		C.make_kondor()
	for up in ["psi_ochrana", "vzduch_laser", "pancir_letadel", "vesta", "vzduch_plazma"]:
		if C.can_make_upgrade(up) and int(d["credits"]) - C.upgrade_price(up) > reserve:
			C.make_upgrade(up)
	if C.can_make_pelikan():
		C.make_pelikan()
	# a second fighter
	if C.jets() < 2 and C.jet_room() and int(d["credits"]) - C.jet_price() > reserve + 500:
		C.buy_jet()
	# buildings
	var have := {}
	for c in d["base"]:
		have[String(c["type"])] = int(have.get(String(c["type"]), 0)) + 1
	var want := {}
	for ft in BUILD:
		want[ft] = int(want.get(ft, 0)) + 1
		if int(have.get(ft, 0)) >= int(want[ft]) + (1 if ft in ["laborator", "dilna"] else 0):
			continue
		if not C.facility_open(ft):
			continue
		if int(d["credits"]) - C.facility_cost(ft) < reserve:
			break
		for i in d["base"].size():
			if String(d["base"][i]["type"]) == "" and C.can_build_at(i):
				C.build(i, ft)
				break
		break

func report(diff: String, players: int, pw: float, res: Array) -> void:
	var ends := {}
	var wdays := []
	var wmis := []
	var stalls := {}
	var t_key := {"orel": [], "ruda_planeta": [], "psi_ochrana": [], "kdo_invaze": [], "signal": [], "rozbor_kolos": [], "rozbor_diskoll": [], "pitva_myslodej": [], "vyslech_velitel": [], "moskovium": []}
	var low := 99999
	for r in res:
		ends[r["end"]] = int(ends.get(r["end"], 0)) + 1
		if r["end"] == "won":
			wdays.append(r["day"])
			wmis.append(r["missions"])
		if r["stall"] != "":
			stalls[r["stall"]] = int(stalls.get(r["stall"], 0)) + 1
		for k in t_key:
			if r["first"].has(k):
				t_key[k].append(r["first"][k])
		for mny in r["money"]:
			low = mini(low, int(mny))
	wdays.sort()
	print("[SIM] %s hráčů %d výhra mise %.2f: %s" % [diff, players, pw, ends])
	if not wdays.is_empty():
		wmis.sort()
		print("[SIM]   vítězství den: min %d, medián %d, max %d; misí do vítězství medián %d" % [int(wdays[0]), int(wdays[wdays.size() / 2]), int(wdays[-1]), int(wmis[wmis.size() / 2])])
	for r in res:
		print("[SIM]   běh: %s den %d mise %d rozpočet %s výzkum %d" % [r["end"], int(r["day"]), r["missions"], str(r["money"]), r["done"].size()])
	for k in t_key:
		var a: Array = t_key[k]
		a.sort()
		if not a.is_empty():
			print("[SIM]   %s začato den: medián %d (%d/%d běhů)" % [k, int(a[a.size() / 2]), a.size(), res.size()])
	for s in stalls:
		print("[SIM]   uvízlo: %s ×%d" % [s, stalls[s]])
	print("[SIM]   nejnižší rozpočet při měsíčním hlášení: %d" % low)
	var sums := {}
	for r in res:
		for mon in r.get("tr", {}):
			for k in r["tr"][mon]:
				var key: String = mon + " " + k
				sums[key] = int(sums.get(key, 0)) + int(r["tr"][mon][k])
	var ks := sums.keys()
	ks.sort()
	for k in ks:
		print("[SIM]   důvěra %s: %+.1f za běh" % [k, float(sums[k]) / res.size()])
	var r0: Dictionary = res[0]
	print("[SIM]   běh 1: konec %s den %d, mise %d (vynecháno %d), obrany %d, útoky bitevní lodě %d, rozpočet po měsících %s, důvěra %s" % [r0["end"], int(r0["day"]), r0["missions"], r0["skipped"], r0["base_fights"], r0["strikes"], r0["money"], r0["trust"]])
