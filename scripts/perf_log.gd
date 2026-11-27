extends Node
class_name PerfLog
## (Ari 22. 11.) Záznamník výkonu: „červík", který sbírá informace jen o hře. Když se snímek
## protáhne (zásek, propad FPS), zapíše do user://logs/vykon_<datum>.txt, co se v tu chvíli dělo:
## čas snímku, skripty / fyzika / navigace / kreslení (CPU i grafická karta), kolik je vetřelců,
## civilistů, světel, částic, uzlů, paměť, kompilace shaderů, síť, co hra právě dělala (výstřely,
## rozbité zdi, přestavby sítí a cest, výbuchy, načtené modely, zvuky…) a kde voják stál.
## Každých 30 s krátký souhrn. Nic neposílá po síti, nečte nic mimo hru.
## Zapíná se v Nastavení → Grafika („Záznam výkonu") nebo F9; F8 = „teď to seklo" (ruční značka).
## Režie: jedno měření času za snímek, počítadla jsou slovníky; podrobný soupis jen při záseku.
## Ostatní skripty hlásí, co dělají: PerfLog.ev("výstřel") a  var t0 := PerfLog.t0() … PerfLog.took("rozbití", t0).

const SPIKE_MS := 45.0        # snímek delší než tohle = zásek (při 60 FPS je snímek 16,7 ms)
const SPIKE_REL := 2.5        # nebo 2,5× delší než obvykle (a aspoň 25 ms)
const SUMMARY_EVERY := 30.0
const KEEP_FILES := 12
const DETAIL_EVERY := 2.0     # podrobný soupis scény nejvýš jednou za 2 s (soupis sám něco stojí)

static var inst: Node = null
static var _ev := {}          # co se stalo v tomto snímku: jméno -> počet
static var _sect := {}        # kolik µs co trvalo v tomto snímku
static var tot := {}          # (pro testy) celkem µs od spuštění
static var tot_n := {}
var on := true
var _f: FileAccess = null
var _path := ""
var _buf := PackedStringArray()
var _flush_t := 0.0
var _last_us := 0
var _hist := PackedFloat32Array()     # posledních 120 snímků (ms) – „obvyklý" snímek
var _recent: Array = []               # posledních ~2 s: [čas, ms, události, úseky]
var _sum := {}                        # průběžný souhrn
var _all := PackedFloat32Array()      # (časy snímků za souhrn; balené pole se nesmí brát ze slovníku – kopie)
var _sum_t := 0.0
var _detail_t := -99.0
var _scene := ""
var _skip := 0                         # snímků po vlastním zápisu se nepočítá (soupis zdržuje)
var _pipe0 := {}
var _vp_rid := RID()

static func ev(k: String, n := 1) -> void:
	if inst and inst.on:
		_ev[k] = int(_ev.get(k, 0)) + n

static func t0() -> int:
	return Time.get_ticks_usec() if inst and inst.on else 0

static func took(k: String, t: int) -> void:
	if t > 0:
		var us := Time.get_ticks_usec() - t
		_sect[k] = int(_sect.get(k, 0)) + us
		_ev[k] = int(_ev.get(k, 0)) + 1
		tot[k] = int(tot.get(k, 0)) + us
		tot_n[k] = int(tot_n.get(k, 0)) + 1

func _ready() -> void:
	inst = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 1000          # (po všech ostatních: měří celý snímek)
	on = Game.perf_log and Game.autotest() == ""       # (autotesty jen s --perflog=1)
	if Game.cmd_arg("perflog", "") != "":
		on = Game.cmd_arg("perflog", "1") == "1"
	_reset_sum()
	if on:
		_open()

func set_on(v: bool) -> void:
	if v == on:
		return
	on = v
	if on:
		_open()
	else:
		_line("=== záznam vypnut")
		_close()

func _open() -> void:
	if _f != null:
		return
	DirAccess.make_dir_recursive_absolute("user://logs")
	_prune()
	var d := Time.get_datetime_dict_from_system()
	_path = "user://logs/vykon_%04d-%02d-%02d_%02d-%02d-%02d.txt" % [d.year, d.month, d.day, d.hour, d.minute, d.second]
	if Game.autotest() != "":      # (testy: víc her najednou na jednom počítači – každá svůj soubor)
		_path = _path.replace(".txt", "_%s%s.txt" % [Game.autotest(), Game.cmd_arg("ci", "")])
	_f = FileAccess.open(_path, FileAccess.WRITE)
	if _f == null:
		on = false
		return
	_line("=== ZÁZNAM VÝKONU – Operace X %s, %04d-%02d-%02d %02d:%02d" % [Game.VERSION, d.year, d.month, d.day, d.hour, d.minute])
	_line("Počítač: %s | CPU %s (%d vláken) | %s | grafika %s (%s), ovladač %s" % [OS.get_name(), OS.get_processor_name(), OS.get_processor_count(), OS.get_version(),
		RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor(), RenderingServer.get_video_adapter_api_version()])
	_line("Nastavení: okno %s %s | 3D rozlišení %.0f %% | stíny %d | detaily %d | mlha %s | tráva %s | vsync %d | max FPS %d" % [
		DisplayServer.window_get_size(), "celá obrazovka" if Game.fullscreen else "v okně", Game.render_scale * 100.0, Game.shadows, Game.detail,
		Game.volumetric, Game.grass, DisplayServer.window_get_vsync_mode(), Engine.max_fps])
	_line("Zásek = snímek nad %.0f ms nebo %.1f× delší než obvykle. Sloupce: proc = skripty, fyz = fyzika, nav = navigace, kresl = kreslení na CPU, gpu = grafická karta." % [SPIKE_MS, SPIKE_REL])
	_line("Když je snímek dlouhý, ale proc/fyz/kresl/gpu malé, zdrželo to něco mimo hru (Windows, jiný program, ovladač, disk).")
	_flush()

func _close() -> void:
	if _f:
		_flush()
		_f.close()
		_f = null

func _exit_tree() -> void:
	if _f:
		_summary(true)
	_close()
	if inst == self:
		inst = null

func _prune() -> void:
	var d := DirAccess.open("user://logs")
	if d == null:
		return
	var fs: Array = Array(d.get_files()).filter(func(f): return String(f).begins_with("vykon_"))
	fs.sort()
	while fs.size() >= KEEP_FILES:
		d.remove(fs.pop_front())

func _line(s: String) -> void:
	_buf.append(s)

func _flush() -> void:
	if _f and not _buf.is_empty():
		_f.store_string("\n".join(_buf) + "\n")
		_f.flush()
		_buf.clear()

func _input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	if e.physical_keycode == KEY_F9:
		Game.set_perf_log(not on)
		_note("Záznam výkonu %s." % ("zapnut (F8 = označit zásek)" if on else "vypnut"))
	elif e.physical_keycode == KEY_F8 and on:
		_line("")
		_line(">>> F8: hráč označil zásek (%s)" % _clock())
		_line(_detail(0.0, true))
		_line(_recent_text())
		_flush()
		_note("Zásek označen v záznamu výkonu.")

func _note(s: String) -> void:
	var m := get_tree().current_scene
	if m and m.get("hud") and m.hud and m.hud.has_method("message"):
		m.hud.message(s, 2.0)
	else:
		print(s)

func _clock() -> String:
	var m := get_tree().current_scene
	var mt := ""
	if m and m.get("t") != null and m.has_method("started"):
		mt = " | mise %.1f s" % float(m.t)
	return "%.1f s hry%s" % [Time.get_ticks_msec() / 1000.0, mt]

func _process(_d: float) -> void:
	if not on:
		_ev.clear(); _sect.clear()
		_last_us = 0
		return
	var now := Time.get_ticks_usec()
	var ms := float(now - _last_us) / 1000.0 if _last_us > 0 else 0.0
	_last_us = now
	_scene_watch()
	if ms <= 0.0:
		_ev.clear(); _sect.clear()
		return
	if not _vp_rid.is_valid():
		_vp_rid = get_viewport().get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(_vp_rid, true)
	var t := Time.get_ticks_msec() / 1000.0
	var ev_now := _ev.duplicate() if not _ev.is_empty() else {}
	var sect_now := _sect.duplicate() if not _sect.is_empty() else {}
	_ev.clear(); _sect.clear()
	_recent.append([t, ms, ev_now, sect_now])
	while not _recent.is_empty() and t - float(_recent[0][0]) > 2.0:
		_recent.pop_front()
	var usual := _usual()
	_hist.append(ms)
	if _hist.size() > 120:
		_hist.remove_at(0)
	# souhrn
	_sum["n"] += 1
	_sum["ms"] += ms
	_sum["max"] = maxf(_sum["max"], ms)
	_sum["proc"] += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	_sum["phys"] += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	_sum["gpu"] += RenderingServer.viewport_get_measured_render_time_gpu(_vp_rid)
	_sum["cpu"] += RenderingServer.viewport_get_measured_render_time_cpu(_vp_rid)
	_all.append(ms)
	for k in ev_now:
		_sum["ev"][k] = int(_sum["ev"].get(k, 0)) + int(ev_now[k])
	for k in sect_now:
		_sum["sect"][k] = int(_sum["sect"].get(k, 0)) + int(sect_now[k])
	if _skip > 0:
		_skip -= 1
	elif ms > SPIKE_MS or (ms > 25.0 and usual > 0.0 and ms > usual * SPIKE_REL):
		_sum["spikes"] += 1
		_spike(ms, usual, ev_now, sect_now)
	_sum_t += _d if _d > 0.0 else ms / 1000.0
	if _sum_t >= SUMMARY_EVERY:
		_summary(false)
	_flush_t += ms / 1000.0
	if _flush_t > 5.0:
		_flush_t = 0.0
		_flush()

func _usual() -> float:
	if _hist.size() < 20:
		return 0.0
	var s := _hist.duplicate()
	s.sort()
	return s[s.size() / 2]

func _scene_watch() -> void:
	var cs := get_tree().current_scene
	var nm := String(cs.name) if cs else ""
	if nm == _scene:
		return
	_scene = nm
	_hist.clear()
	_recent.clear()
	_skip = 30          # (scéna se právě postavila: první snímky jsou dlouhé vždy)
	var extra := ""
	if cs and cs.has_method("mtype"):
		var p: Dictionary = Net.mission_params
		extra = " | mise %s, terén %s, počasí %s, seed %s, hráčů %d%s" % [p.get("type", Game.cmd_arg("mtype", "?")), p.get("biome", Game.cmd_arg("biome", "?")), p.get("weather", "?"), p.get("seed", Game.seed_override),
			Net.roster.size() if not Net.roster.is_empty() else 1, " (hostitel)" if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and not Net.roster.is_empty() else (" (klient)" if multiplayer.has_multiplayer_peer() and not multiplayer.is_server() else "")]
	_line("")
	_line("--- %s scéna %s%s" % [_clock(), nm, extra])
	_flush()

func _spike(ms: float, usual: float, ev_now: Dictionary, sect_now: Dictionary) -> void:
	_line("")
	var why := ""
	var proc := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var phys := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var nav := Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0
	var rc := RenderingServer.viewport_get_measured_render_time_cpu(_vp_rid)
	var rg := RenderingServer.viewport_get_measured_render_time_gpu(_vp_rid)
	var known := proc + phys + rc
	if known < ms * 0.35 and rg < ms * 0.5:
		why = "  ← většina času mimo měřené části (načítání, kompilace shaderů, Windows/jiný program)"
	_line("!!! ZÁSEK %.0f ms (obvykle %.1f ms) | %s | proc %.1f fyz %.1f nav %.1f kresl %.1f gpu %.1f%s" % [ms, usual, _clock(), proc, phys, nav, rc, rg, why])
	if not sect_now.is_empty():
		var ks := sect_now.keys()
		ks.sort_custom(func(a, b): return sect_now[a] > sect_now[b])
		var parts := PackedStringArray()
		for k in ks:
			parts.append("%s %.1f ms" % [k, sect_now[k] / 1000.0])
		_line("    hra dělala: " + ", ".join(parts))
	if not ev_now.is_empty():
		_line("    v tomto snímku: " + _evtext(ev_now))
	_line(_recent_text())
	var t := Time.get_ticks_msec() / 1000.0
	_line(_detail(ms, t - _detail_t > DETAIL_EVERY))
	if t - _detail_t > DETAIL_EVERY:
		_detail_t = t
		_skip = 2
	_flush()

## Co se stalo za poslední 2 s (součty), kolik snímků bylo dlouhých.
func _recent_text() -> String:
	var evs := {}
	var long := 0
	var tot := 0.0
	for r in _recent:
		tot += float(r[1])
		if float(r[1]) > 33.0: long += 1
		for k in r[2]:
			evs[k] = int(evs.get(k, 0)) + int(r[2][k])
	return "    poslední 2 s: %d snímků (%.0f FPS), dlouhých nad 33 ms %d; %s" % [_recent.size(), _recent.size() / maxf(tot / 1000.0, 0.001), long, _evtext(evs) if not evs.is_empty() else "nic zvláštního"]

func _evtext(d: Dictionary) -> String:
	var ks := d.keys()
	ks.sort_custom(func(a, b): return d[a] > d[b])
	var parts := PackedStringArray()
	for k in ks:
		parts.append("%s %d×" % [k, d[k]])
	return ", ".join(parts)

## Soupis stavu: rychlý vždy, podrobný (počítání uzlů ve scéně) jen občas.
func _detail(_ms: float, full: bool) -> String:
	var s := PackedStringArray()
	s.append("    scéna: uzlů %d (sirotků %d), objektů %d, paměť %.0f MB, video %.0f MB | kreslení: volání %d, objektů %d, trojúhelníků %d tis." % [
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000])
	var pipe := _pipes()
	var pd := PackedStringArray()
	for k in pipe:
		var dv := int(pipe[k]) - int(_pipe0.get(k, 0))
		if dv > 0: pd.append("%s +%d" % [k, dv])
	_pipe0 = pipe
	s.append("    fyzika: aktivních těles %d, párů %d | navigace: map %d, oblastí %d, agentů %d | kompilace shaderů od minula: %s | okno %s" % [
		Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS), Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS),
		Performance.get_monitor(Performance.NAVIGATION_ACTIVE_MAPS), Performance.get_monitor(Performance.NAVIGATION_REGION_COUNT), Performance.get_monitor(Performance.NAVIGATION_AGENT_COUNT),
		", ".join(pd) if not pd.is_empty() else "žádné", "aktivní" if DisplayServer.window_is_focused() else "NEAKTIVNÍ (alt-tab?)"])
	var m := get_tree().current_scene
	if m and m.has_method("aliens"):
		var al: Array = m.aliens()
		var alive := 0
		var near := 0
		var pl: Node3D = m.local_player() if m.has_method("local_player") else null
		for a in al:
			if not a.dead:
				alive += 1
				if pl and (a as Node3D).global_position.distance_to(pl.global_position) < 30.0: near += 1
		var civ: Array = m.civilians() if m.has_method("civilians") else []
		var line := "    mise: vetřelců %d (živých %d, do 30 m %d), civilistů %d, hráčů %d, ohňů %d, kouřů %d" % [al.size(), alive, near, civ.size(),
			m.players().size() if m.has_method("players") else 0, (m.fires as Dictionary).size() if m.get("fires") is Dictionary else 0, (m.smokes as Array).size() if m.get("smokes") is Array else 0]
		if pl:
			line += " | voják %s %s%s" % [_v(pl.global_position), "střílí" if pl.get("_since_shot") != null and float(pl._since_shot) < 0.3 else "", " (zbraň %s)" % String(pl.weapon().get("id", "")) if pl.has_method("weapon") else ""]
		if multiplayer.has_multiplayer_peer() and multiplayer.get_unique_id() != 1:
			line += " | klient, ping %d ms" % Net.ping_of(multiplayer.get_unique_id())
		s.append(line)
		if full:
			var c := {}
			for k in ["OmniLight3D", "SpotLight3D", "CPUParticles3D", "GPUParticles3D", "AudioStreamPlayer3D", "MeshInstance3D", "RigidBody3D", "Skeleton3D"]:
				c[k] = 0
			_count(m, c)
			var sh := 0
			for l in m.find_children("*", "Light3D", true, false):
				if (l as Light3D).shadow_enabled and (l as Light3D).is_visible_in_tree(): sh += 1
			s.append("    soupis: světel %d (stínů %d), reflektorů %d, částic CPU %d / GPU %d, zvuků %d, sítí %d, padajících těles %d, koster %d" % [c["OmniLight3D"], sh, c["SpotLight3D"], c["CPUParticles3D"], c["GPUParticles3D"], c["AudioStreamPlayer3D"], c["MeshInstance3D"], c["RigidBody3D"], c["Skeleton3D"]])
	return "\n".join(s)

static func _count(n: Node, c: Dictionary) -> void:
	for ch in n.get_children():
		var k := ch.get_class()
		if c.has(k): c[k] += 1
		if ch.get_child_count() > 0: _count(ch, c)

static func _v(p: Vector3) -> String:
	return "(%.0f, %.0f, %.0f)" % [p.x, p.y, p.z]

func _pipes() -> Dictionary:
	var d := {}
	for pair in [["plátno", RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS], ["sítě", RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH],
			["povrchy", RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE], ["kreslení", RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW],
			["specializace", RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION]]:
		d[pair[0]] = RenderingServer.get_rendering_info(pair[1])
	return d

func _reset_sum() -> void:
	_sum = {"n": 0, "ms": 0.0, "max": 0.0, "proc": 0.0, "phys": 0.0, "gpu": 0.0, "cpu": 0.0, "spikes": 0, "ev": {}, "sect": {}}
	_all = PackedFloat32Array()
	_sum_t = 0.0

func _summary(last: bool) -> void:
	var n: int = _sum["n"]
	if n > 0 and _f:
		var a := _all.duplicate()
		a.sort()
		var p99: float = a[mini(a.size() - 1, int(a.size() * 0.99))]
		var p1: float = a[mini(a.size() - 1, int(a.size() * 0.5))]
		_line("")
		_line("··· souhrn %.0f s (%s): %.0f FPS, snímek průměr %.1f / medián %.1f / 99 %% %.1f / max %.0f ms | záseků %d | proc %.1f fyz %.1f kresl %.1f gpu %.1f ms" % [
			_sum_t, _clock(), n / maxf(_sum["ms"] / 1000.0, 0.001), _sum["ms"] / n, p1, p99, _sum["max"], _sum["spikes"], _sum["proc"] / n, _sum["phys"] / n, _sum["cpu"] / n, _sum["gpu"] / n])
		var sd: Dictionary = _sum["sect"]
		if not sd.is_empty():
			var ks := sd.keys()
			ks.sort_custom(func(x, y): return sd[x] > sd[y])
			var parts := PackedStringArray()
			for k in ks.slice(0, 10):
				parts.append("%s %.0f ms (%d×)" % [k, sd[k] / 1000.0, int(_sum["ev"].get(k, 0))])
			_line("    nejvíc času: " + ", ".join(parts))
		var ed: Dictionary = (_sum["ev"] as Dictionary).duplicate()
		for k in sd: ed.erase(k)
		if not ed.is_empty():
			_line("    události: " + _evtext(ed))
		_line(_detail(0.0, false))
		_flush()
	if not last:
		_reset_sum()
