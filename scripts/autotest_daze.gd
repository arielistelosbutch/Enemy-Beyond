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

## chaintest (Ari 2026-11-17: „ať se nedá dostat do trvalého omráčení, nic se nesčítá – v singlu by to
## bylo šílené“): 60 s všeho najednou – řev Ohaře a psi útok každých 0,25 s, strach pořád na 100 –
## a měří nejdelší souvislé ochromení, podíl času bez ovládání celkem a v nejhorších 30 s. Pak
## knock-out hned po zvednutí (nesmí ho znovu složit), dva záblesky po sobě (bílá se nesčítá) a dvě
## iluze po sobě (druhá neprojde). Výsledek „RESULT chaintest …“.
static func chain(at: Node, p: Node) -> void:
	if p == null: return
	at._skip_brief()
	if at.step > 0 or not at.m().started(): return
	at.step = 1
	var m: Node = at.m()
	m.hud.inventory_open = false
	p.hp = 5000.0
	p.max_hp = 5000.0
	for a in m.aliens():
		a.set_physics_process(false)
		a.global_position += Vector3(0, -200, 0)
	await at.get_tree().create_timer(0.5).timeout
	var t := 0.0
	var next := 0.0
	var run := 0.0
	var longest := 0.0
	var frozen := 0.0
	var freezes := 0
	var was := false
	var hist: Array = []        # frozen flag per frame with its dt (for the worst 30 s)
	while t < 60.0:
		await at.get_tree().physics_frame
		var dt: float = at.get_physics_process_delta_time()
		t += dt
		p.stress = 100.0
		p.panic_cd = 0.0
		if t >= next:
			next += 0.25
			p.ohar_roar(0.99)
			p.psi_attack(0.99)
		var now: bool = p.panic != ""
		if now:
			frozen += dt
			run += dt
			longest = maxf(longest, run)
		else:
			run = 0.0
		if now and not was:
			freezes += 1
		was = now
		hist.append([dt, now])
	var worst := 0.0
	var win := 0.0
	var span := 0.0
	var i0 := 0
	for i in hist.size():
		span += hist[i][0]
		if hist[i][1]: win += hist[i][0]
		while span > 30.0:
			span -= hist[i0][0]
			if hist[i0][1]: win -= hist[i0][0]
			i0 += 1
		worst = maxf(worst, win)
	# knock-out right after being stood up
	p.knock_out()
	var ko1: bool = p.downed
	p.revived("Test")
	await at.get_tree().physics_frame
	p.knock_out()
	var ko2: bool = p.downed
	if ko2:
		p.revived("Test")
	# two flashes in a row: never whiter than the first, gone after a while
	m.hud.blind_flash(1.0)
	var b1: float = m.hud.blind_level()
	m.hud.blind_flash(1.0)
	m.hud.blind_flash(1.0)
	var b2: float = m.hud.blind_level()
	await at.get_tree().create_timer(8.0).timeout
	var b3: float = m.hud.blind_level()
	# two illusions: the second is ignored
	var ill := "-"
	var mates: Array = m.players().filter(func(o): return o != p)
	if not mates.is_empty():
		p.psi_illusion(String(mates[0].name), 3.0, 0.0)
		var on1: bool = p._illusion_t > 0.0
		var t1: float = p._illusion_t
		await at.get_tree().create_timer(0.3).timeout
		p.psi_illusion(String(mates[0].name), 20.0, 0.0)
		ill = str(on1 and p._illusion_t <= t1)
	at.out("RESULT chaintest solo %s longest %.1f s frozen %.0f %% worst30 %.1f s freezes %d ko_first %s ko_again %s blind %.2f/%.2f/%.2f illusion %s" % [p._solo(), longest, 100.0 * frozen / 60.0, worst, freezes, ko1, ko2, b1, b2, b3, ill])
	at.get_tree().quit()
