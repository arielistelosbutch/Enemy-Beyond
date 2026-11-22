extends RefCounted
## scantest (2026-11-22, Ari: „u vylepšení detektoru nesnímá pohyb spojenců, jen civily a vetřelce“).
## Kolem vojáka s detektorem se hýbe kamarád (jako vzdálený hráč), civilista a vetřelec, každý jinde.
## Bez výzkumu `detektor_opasek` detektor ukáže všechny tři, s ním jen civilistu a vetřelce
## (výzkum se bere z parametrů mise, takže v co-opu je to u všech stejné).

static func _blip_near(hud: Node, pos: Vector3) -> bool:
	for b in hud._blips:
		if Vector2(b["pos"].x - pos.x, b["pos"].z - pos.z).length() < 2.2:
			return true
	return false

## Moves the three for ~2.5 s (side to side) and says which of them showed on the detector.
static func _pass(at: Node, p: Node, who: Dictionary) -> Dictionary:
	var hud: Node = at.m().hud
	hud._blips.clear()
	hud._last_pos.clear()
	var seen := {}
	for k in who:
		seen[k] = false
	var t := 0.0
	while t < 2.5:
		await at.get_tree().physics_frame
		t += at.get_physics_process_delta_time()
		for k in who:
			var n: Node = who[k]["node"]
			n.global_position = who[k]["at"] + Vector3(sin(t * 3.0) * 1.2, 0, 0)
			n.velocity = Vector3.ZERO
		for k in who:
			if _blip_near(hud, who[k]["at"]):
				seen[k] = true
	return seen

static func run(at: Node, p: Node) -> void:
	if p == null: return
	at._skip_brief()
	if at.step > 0 or not at.m().started(): return
	at.step = 1
	var m: Node = at.m()
	m.hud.inventory_open = false
	var start: Vector3 = m.free_spot(m.map["evac"] + Vector3(6, 0.3, -6))
	p.global_position = start
	p.inv["lh"] = {"id": "scanner"}
	# everything else far away and still
	var alien: Node = null
	for a in m.aliens():
		if alien == null:
			alien = a
		a.set_physics_process(false)
		a.global_position += Vector3(0, -200, 0)
	var civ: Node = null
	for c in m.civilians():
		if civ == null:
			civ = c
		c.set_physics_process(false)
		c.global_position += Vector3(0, -200, 0)
	var data := {"kind": "player", "peer": 9, "pos": start, "yaw": 0.0,
		"merc": m.roster()[p.get_multiplayer_authority()]["merc"], "name": "Kamarad"}
	var mate: Node = m._spawn(data)
	m.actors.add_child(mate)
	mate.set_physics_process(false)
	await at.get_tree().create_timer(0.3).timeout
	if alien == null or civ == null:
		at.out("RESULT scantest missing alien %s civ %s" % [alien != null, civ != null])
		at.get_tree().quit()
		return
	var who := {
		"mate": {"node": mate, "at": start + Vector3(8, 0, 0)},
		"civ": {"node": civ, "at": start + Vector3(0, 0, 10)},
		"alien": {"node": alien, "at": start + Vector3(-9, 0, -4)},
	}
	var research: Array = Net.mission_params.get("research", []).duplicate()
	research.erase("detektor_opasek")
	Net.mission_params["research"] = research
	var base: Dictionary = await _pass(at, p, who)
	var base_belt: bool = p.has_scanner()
	Net.mission_params["research"] = research + ["detektor_opasek"]
	p.inv.erase("lh")
	p.inv["b0"] = {"id": "scanner"}      # (s displejem v helmě stačí na opasku)
	var up: Dictionary = await _pass(at, p, who)
	at.out("[SCAN] bez výzkumu %s  s výzkumem %s  na opasku %s" % [base, up, p.has_scanner()])
	var ok_base: bool = base["mate"] and base["civ"] and base["alien"]
	var ok_up: bool = not up["mate"] and up["civ"] and up["alien"]
	at.out("RESULT scantest base %s upgraded %s belt %s" % [ok_base, ok_up, p.has_scanner() and base_belt])
	at.get_tree().quit()
