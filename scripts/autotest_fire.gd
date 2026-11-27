extends RefCounted
## firelag (2026-11-27, Ari: „lagy při větším požáru domů a více efektech“): stresový test požárů.
## 6 s klid, pak se zapálí FIRES ohňů na dřevě a bednách kolem vojáka (domy ve městě), každé
## 1,5 s výbuch granátu poblíž, 30 s hoří; pak 8 s dohořívání. Měří čas snímku (průměr, 99 %, max)
## a co ho stálo (PerfLog), počty ohňů, světel se stínem, částic, kouřů a rozbitých kusů.
## Pár firehost/fireclient: hostitel zapaluje, klient jen měří (vidí stejné ohně přes rpc).
## Spouštět: --autotest=firelag --mtype=terror --biome=town --seed=3 --perflog=1 [--fires=24] [--nades=1]
## (v okně na PC pak měří i kreslení na grafické kartě).

static var _s := {}
static var _last_us := 0
static var PH := [["klid", 6.0], ["požár", 30.0], ["dohořívá", 8.0]]

static func run(at: Node, p: Node) -> void:
	at._skip_brief()
	var host: bool = at.mode != "fireclient"
	var now := Time.get_ticks_usec()
	var dt := float(now - _last_us) / 1000.0 if _last_us > 0 else 0.0
	_last_us = now
	if p == null or not at.m().started():
		return
	if at.mode in ["firehost", "fireclient"] and _s.is_empty() and at.m().players().size() < 2:
		return
	p.hp = 1.0e6
	p.max_hp = 1.0e6
	if _s.has("done"):
		return
	if _s.is_empty():
		PH[1][1] = float(Game.cmd_arg("firedur", "30"))
		_s = {"t0": at.t, "ph": -1, "fr": [], "rows": [], "lit": false, "boom": 0.0, "peak": {}}
		if Game.perf: Game.perf.set_on(true)
		for a in at.m().aliens():      # (vetřelci by vojáka rozptylovali; měří se oheň)
			if Game.cmd_arg("keep", "0") != "1":
				a.queue_free()
		at.out("[FIRE] %s start, rozbitelných kusů %d" % [at.mode, at.m().map.get("breakables", []).size()])
		return
	var tt: float = at.t - float(_s["t0"])
	var ph := 0
	var acc := 0.0
	for i in PH.size():
		acc += float(PH[i][1])
		if tt < acc:
			ph = i
			break
		ph = i + 1
	if ph != int(_s["ph"]):
		if int(_s["ph"]) >= 0:
			_report(at, int(_s["ph"]))
		_s["ph"] = ph
		_s["fr"] = []
		_s["t0p"] = PerfLog.tot.duplicate()
		_s["n0p"] = PerfLog.tot_n.duplicate()
		if ph >= PH.size():
			_finish(at)
			return
	if dt > 0.0 and tt > 0.5 and at.t >= float(_s.get("skip", 0.0)):
		(_s["fr"] as Array).append(dt)
	# slowly looks round, so the fires come in and out of view
	p.rotation.y += 0.006
	p.pitch = -0.08
	if ph == 1 and host:
		if not _s["lit"]:
			_s["lit"] = true
			_light_up(at, p)
		_s["boom"] = float(_s["boom"]) - (1.0 / 60.0)
		if Game.cmd_arg("nades", "1") == "1" and fmod(tt, 1.5) < fmod(tt - dt / 1000.0, 1.5):
			var a := randf() * TAU
			var bp: Vector3 = p.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(8.0, 18.0)
			at.m().explode(bp, 6.5, 100.0, "-", randf() < 0.4)
			at.m().ignite_around(bp, 6.5, 0.4, 2)
	# (soupis scény prochází 25 tis. uzlů a na PC stojí 150-280 ms ve dvou snímcích - jen 3× za požár
	#  a 0,4 s po něm se snímky nepočítají; dřív každé 2 s a dělal sám ty „záseky mimo měřené části“)
	if ph == 1 and fmod(tt, 10.0) < fmod(tt - dt / 1000.0, 10.0):
		_census(at)
		_last_us = Time.get_ticks_usec()
		_s["skip"] = at.t + 0.4
		if Game.perf: PerfLog.ev("soupis scény (test)")

static func _light_up(at: Node, p: Node) -> void:
	var want := int(Game.cmd_arg("fires", "24"))
	var arr: Array = at.m().map.get("breakables", [])
	var c := []
	for b in arr:
		if is_instance_valid(b) and String(b.get_meta("break_kind", "")) in ["wood", "crate"]:
			var d: float = (b as Node3D).global_position.distance_to(p.global_position)
			if d < 55.0:
				c.append([d, b])
	c.sort_custom(func(x, y): return x[0] < y[0])
	var n := 0
	for e in c:
		if n >= want:
			break
		var bp: Vector3 = (e[1] as Node3D).global_position
		var k0: int = at.m().fires.size()
		at.m().ignite(Vector3(bp.x, bp.y, bp.z), randf_range(0.9, 1.4))
		if at.m().fires.size() > k0:
			n += 1
	at.out("[FIRE] zapáleno %d ohňů (dřevo v okolí %d)" % [n, c.size()])

static func _census(at: Node) -> void:
	var pk: Dictionary = _s["peak"]
	var root: Node = at.m()
	var lights := 0
	var shad := 0
	var parts := 0
	var emit := 0
	for l in root.find_children("*", "Light3D", true, false):
		if (l as Light3D).visible:
			lights += 1
			if (l as Light3D).shadow_enabled: shad += 1
	for c in root.find_children("*", "CPUParticles3D", true, false):
		if (c as CPUParticles3D).emitting:
			emit += 1
			parts += (c as CPUParticles3D).amount
	for c in root.find_children("*", "GPUParticles3D", true, false):
		if (c as GPUParticles3D).emitting:
			emit += 1
			parts += (c as GPUParticles3D).amount
	var snd := root.find_children("*", "AudioStreamPlayer3D", true, false).size()
	var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var tri := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000
	var fsh := 0
	for f in root.fires.values():
		if is_instance_valid(f["light"]) and (f["light"] as Light3D).shadow_enabled: fsh += 1
	var vals := {"fshadow": fsh, "draws": dc, "ktri": tri, "fires": root.fires.size(), "lights": lights, "shadow": shad, "emitters": emit,
		"particles": parts, "smokes": root.smokes.size(), "sounds": snd, "nodes": at.get_tree().get_node_count()}
	for k in vals:
		pk[k] = maxi(int(pk.get(k, 0)), int(vals[k]))

static func _report(at: Node, ph: int) -> void:
	var fr: Array = _s["fr"]
	var s := fr.duplicate(); s.sort()
	var avg := 0.0
	for x in fr: avg += x
	avg /= maxf(1.0, fr.size())
	var p99: float = s[int(s.size() * 0.99)] if not s.is_empty() else 0.0
	var mx: float = s[-1] if not s.is_empty() else 0.0
	var big := 0
	for x in fr:
		if x > 40.0: big += 1
	var secs: float = float(PH[ph][1])
	var d := {}
	for k in PerfLog.tot:
		var v := int(PerfLog.tot[k]) - int((_s["t0p"] as Dictionary).get(k, 0))
		if v > 0: d[k] = v
	var ks := d.keys()
	ks.sort_custom(func(x, y): return d[x] > d[y])
	var parts := PackedStringArray()
	for k in ["výbuch", "oheň", "mise._fires_tick", "rozbití kusu"]:
		if not k in ks.slice(0, 8): ks.append(k)
	for k in ks.slice(0, 8) + ["výbuch", "oheň", "mise._fires_tick", "rozbití kusu"]:
		if not d.has(k): continue
		parts.append("%s %.1f ms/s (%d/s)" % [k, d[k] / 1000.0 / secs, (int(PerfLog.tot_n[k]) - int((_s["n0p"] as Dictionary).get(k, 0))) / secs])
	at.out("[FIRE] %s %-9s snímek %.1f ms, 99 %% %.1f, max %.0f, nad 40 ms %d | %s" % [at.mode, PH[ph][0], avg, p99, mx, big, ", ".join(parts)])
	(_s["rows"] as Array).append([avg, p99, mx, big])

static func _finish(at: Node) -> void:
	var r: Array = _s["rows"]
	var pk: Dictionary = _s["peak"]
	var broken := int(PerfLog.tot_n.get("rozbití kusu", 0))
	at.out("[FIRE] nejvíc: ohňů %d, světel %d (se stínem %d), částicových zdrojů %d (%d částic), kouřů %d, 3D zvuků %d, uzlů %d, kreslení %d volání / %d tis. trojúhelníků; rozbito %d" % [
		pk.get("fires", 0), pk.get("lights", 0), pk.get("shadow", 0), pk.get("emitters", 0), pk.get("particles", 0), pk.get("smokes", 0), pk.get("sounds", 0), pk.get("nodes", 0), pk.get("draws", 0), pk.get("ktri", 0), broken])
	var path := ""
	if Game.perf:
		Game.perf._flush()
		path = Game.perf._path
	at.out("RESULT firelag %s klid %.1f ms pozar %.1f ms (99 %% %.0f, max %.0f, nad40 %d) navic %.1f ms ohnu %d stin %d stin_ohnu %d kresleni %d log %s" % [
		at.mode, r[0][0], r[1][0], r[1][1], r[1][2], r[1][3], r[1][0] - r[0][0], pk.get("fires", 0), pk.get("shadow", 0), pk.get("fshadow", 0), pk.get("draws", 0), path])
	_s = {"done": true}
	if at.mode == "firehost":
		at.get_tree().create_timer(5.0).timeout.connect(func(): at.get_tree().quit())     # (klient dopíše výsledek)
	else:
		at.get_tree().quit()
