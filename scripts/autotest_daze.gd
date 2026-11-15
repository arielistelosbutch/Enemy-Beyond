extends RefCounted
## dazetest (Ari 2026-11-15, co-op obrana základny: „dostali jsme hodně moc stunu, nemohli jsme se
## pohnout“): 24 s pod neustálým řevem Ohařů a psionickým tlakem (každých 0,5 s řev, každé 2 s psi)
## – jak velkou část času voják nemůže hrát (panic != ""). Pak skutečný Ohař (--crew=ohar): dva
## řevy po sobě (druhý má být v pauze ROAR_CD) a řev za zdí z dálky. Výsledek „RESULT dazetest …“.

static func run(at: Node, p: Node) -> void:
	if p == null: return
	at._skip_brief()
	if at.step > 0 or not at.m().started(): return
	at.step = 1
	var m: Node = at.m()
	m.hud.inventory_open = false
	p.hp = 5000.0
	p.max_hp = 5000.0
	var ohar: Node = null
	for a in m.aliens():
		if a.race == "ohar" and ohar == null:
			ohar = a
		a.set_physics_process(false)
		a.global_position += Vector3(0, -200, 0)
	await at.get_tree().create_timer(0.5).timeout
	var frozen := 0.0
	var total := 0.0
	var freezes := 0
	var was := false
	var next_roar := 0.0
	var next_psi := 0.3
	var t := 0.0
	while t < 24.0:
		await at.get_tree().physics_frame
		var dt: float = at.get_physics_process_delta_time()
		t += dt
		if t >= next_roar:
			next_roar += 0.5
			p.ohar_roar(0.99)
		if t >= next_psi:
			next_psi += 2.0
			p.psi_attack(0.7)
		total += dt
		var now: bool = p.panic != ""
		if now:
			frozen += dt
		if now and not was:
			freezes += 1
		was = now
	var share := frozen / maxf(total, 0.01)
	var cd_ok := "-"
	var wall_ok := "-"
	if ohar and "_roar_cd" in ohar:
		p.stress = 0.0
		ohar.global_position = p.global_position - p.global_transform.basis.z * 5.0
		ohar._roar_cd = 0.0
		await at.get_tree().physics_frame
		ohar._roar_scare()
		await at.get_tree().physics_frame
		var s1: float = p.stress
		ohar._roar_scare()
		await at.get_tree().physics_frame
		cd_ok = str(s1 > 0.0 and absf(p.stress - s1) < 1.0)
		# far behind the ground (15 m away, 3 m under it): heard only as a growl
		p.stress = 0.0
		ohar.global_position = p.global_position + Vector3(15.0, -3.0, 0.0)
		ohar._roar_cd = 0.0
		await at.get_tree().physics_frame
		var seen: bool = ohar.visible_to(p)
		ohar._roar_scare()
		await at.get_tree().physics_frame
		wall_ok = str(seen or p.stress < 1.0)
	at.out("RESULT dazetest home %s frozen %.0f %% freezes %d cooldown %s wall %s" % [p.home_ground() if p.has_method("home_ground") else "?", share * 100.0, freezes, cd_ok, wall_ok])
	at.get_tree().quit()
