extends RefCounted
## (2026-11-27, Ari: „hra ukazovala den, ale ve hře byla noc a měsíc svítil až přehnaně jasně“)
## Mise postavená stejnou cestou jako v kampani (Campaign.mission_params: slunce nad místem v daný den):
##   --autotest=daynight --lat=30.0 --lon=31.2 --cday=0.9 [--weather=clear]
## vypíše fázi, výšku slunce, světlo a co říká briefing. Navíc u noci: noktovizor zapnout, změnit počasí,
## noktovizor vypnout - okolní světlo se musí vrátit tam, kde bylo (dřív spadlo do tmy).
## Co-op: --autotest=dnhost / dnclient (pár daynight_coop ve fulltestu) - klient musí mít stejné
## světlo jako hostitel.
## RESULT daynight <role> phase P sun S moon M amb A brief B [nvgwx ok|bad]

## The mission parameters for a test place and campaign day (what the globe would launch).
static func params(lat: float, lon: float, cday: float, weather: String) -> Dictionary:
	var keep: Dictionary = Campaign.data
	Campaign.data = {"day": cday}
	var sun: Vector2 = Campaign.sun_at(lat, lon)
	var p := {"type": "crash", "biome": "farm", "terrain": "temperate", "place": "Test", "type_name": "Test", "id": -1,
		"lat": lat, "lon": lon, "night": Campaign.is_night(lon, lat), "hour": Campaign.local_hour(lon), "sun": sun.x, "sun_az": sun.y,
		"globe_phase": Campaign.day_phase(lon, lat), "size": "small", "extra_aliens": 0}
	if weather != "":
		p["weather"] = weather
	Campaign.data = keep
	return p

static func test_params() -> Dictionary:
	return params(float(Game.cmd_arg("lat", "49.5")), float(Game.cmd_arg("lon", "15.6")), float(Game.cmd_arg("cday", "0.0")), Game.cmd_arg("weather", "clear"))

static func run(at: Node, p: Node) -> void:
	if p == null or at.step > 0:
		return
	at._skip_brief()
	var m: Node = at.m()
	if not m.started():
		return
	at.step = 1
	for a in m.aliens():
		a.set_physics_process(false)
	p.hp = 999.0
	await at.get_tree().create_timer(0.5).timeout
	var mp: Dictionary = Net.mission_params
	var ph: String = m.phase()
	if DisplayServer.get_name() != "headless":
		p.light_on = false
		var ev: Vector3 = m.map["evac"]
		var nav_map: RID = m.get_world_3d().navigation_map
		p.global_position = NavigationServer3D.map_get_closest_point(nav_map, ev + Vector3(14, 0, -14)) + Vector3(0, 0.3, 0)
		for i in 40:
			at._skip_brief()
			await at.get_tree().create_timer(0.1).timeout
			if m.hud._brief_t < 0:
				break
		at._aim_at(p, ev + Vector3(0, 1.5, 0))
		await at.get_tree().create_timer(1.0).timeout
		at._snap("dn_%s_%s_%s" % [Game.autotest(), ph, m.weather])
	var brief: String = m._briefing_text()
	var named: String = m.PHASE_NAMES.get(ph, "?")
	var wn: String = m.weather_name()
	var brief_ok: bool = brief.contains("(%s)" % named) and (ph == "noc" or not wn.contains("měsíc")) and (ph == "den" or not (wn == "jasno" or wn == "zataženo"))
	var globe_ok := String(mp.get("globe_phase", ph)) == ph
	var line := "RESULT daynight %s phase %s sun %.1f moon %.2f amb %.2f brief %s globe %s weather '%s'" % [Game.autotest(), ph, m.sun_elev(),
		m.moon.light_energy, m.env.ambient_light_energy, "ok" if brief_ok else "bad", "ok" if globe_ok else "bad", wn]
	if Game.autotest() == "daynight" and ph == "noc":
		# the NVG on, the weather turns, the NVG off: the night must be as dark as before, not black
		var amb0: float = m.env.ambient_light_energy
		p.inv["p5"] = {"id": "nvg"}
		m.set_nvg(true)
		var amb_nvg: float = m.env.ambient_light_energy
		m._weather_shift(Game.cmd_arg("wxto", "overcast"))
		m.wx._blend["dur"] = 0.3
		await at.get_tree().create_timer(1.0).timeout
		var amb_mid: float = m.env.ambient_light_energy
		m.set_nvg(false)
		await at.get_tree().create_timer(0.2).timeout
		var amb1: float = m.env.ambient_light_energy
		var ok: bool = amb_nvg > amb0 + 0.3 and amb_mid > amb0 and amb1 > 0.05 and amb1 < amb0 + 0.05 and absf(amb1 - m._amb_base) < 0.01
		at.out("[DN] nvg+weather: before %.2f nvg %.2f after_shift %.2f off %.2f base %.2f" % [amb0, amb_nvg, amb_mid, amb1, m._amb_base])
		line += " nvgwx %s" % ("ok" if ok else "bad")
	at.out(line)
	if Game.autotest() in ["dnhost", "dnclient"]:
		await at.get_tree().create_timer(4.0).timeout
	at.get_tree().quit()
