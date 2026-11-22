extends RefCounted
## quiettest (Ari 2026-11-22: „tlumiče na pistoli prý nefungují, projeď je všude… a perky, kočičí
## pohyb a stealth celkově“). Pro každou zbraň, na kterou jde tlumič (Game.MOD_FITS), bez něj a s ním:
##  - hear: vetřelec 12 m za vojákem výstřel slyší jen bez tlumiče,
##  - sound: s tlumičem hraje tichý výstřel (player.quiet_shots), ne plný,
##  - hit: zásah zezadu ze tmy – s tlumičem zasažený neví, kdo to byl (jen přibližné místo),
##    kamarád 6 m od něj nic; bez tlumiče oba vědí,
##  - kill: tiché zabití nevaruje skupinu,
##  - model: díl Part_tlumic na modelu zbraně, uložení vojáka (var_to_str) ho drží.
## Pak nůž zezadu s Tichým zabijákem (zabije, kamarád neví), kroky (chůze slyšet na 4,5 m,
## s Kočičím krokem ne, přikrčený ne). Výsledek „RESULT quiettest …“.

static func _reset(a: Node) -> void:
	a.alert = false
	a.state = a.S.LURK
	a.target = null
	a.sus.clear()
	a.known.clear()
	a._seen_pos.clear()
	a._hurt_by.clear()
	a.last_seen = a.global_position

static func _place(a: Node, pos: Vector3, yaw: float) -> void:
	a.global_position = pos
	a.last_seen = pos
	a.rotation.y = yaw
	a.velocity = Vector3.ZERO

static func _arm(p: Node, w: String, quiet: bool) -> void:
	var f: Dictionary = p.merc.get("fit", {})
	var fit: Dictionary = (f.get(w, {}) as Dictionary).duplicate()
	if quiet:
		fit["hlaven"] = "tlumic"
	else:
		fit.erase("hlaven")
	f[w] = fit
	p.merc["fit"] = f
	p.inv["rh"] = {"id": w, "loaded": 40}
	p._update_held()
	p.light_on = false
	p.spread_bloom = 0.0

static func run(at: Node, p: Node) -> void:
	if p == null: return
	at._skip_brief()
	if at.step > 0 or not at.m().started() or at.m().aliens().size() < 3: return
	at.step = 1
	var m: Node = at.m()
	m.hud.inventory_open = false
	p.hp = 9999.0
	p.max_hp = 9999.0
	m.t = m.CALM_TIME + 5.0         # (the first minute halves what they hear)
	var al: Array = []
	for a in m.aliens():
		if al.size() < 3 and a.has_method("quiet_hit") and not a.R.has("melee") and not a.R.has("hover"):
			al.append(a)
		a.set_physics_process(false)
		a.global_position += Vector3(0, -200, 0)
	if al.size() < 3:
		at.out("RESULT quiettest aliens %d" % al.size())
		at.get_tree().quit()
		return
	for a in al:
		a.set_physics_process(false)
		a.global_position += Vector3(0, -200, 0)
	p.crouching = false
	# a spot and a way with 26 m of open ground (at the feet, the chest and the eyes) and 13 m behind
	var ss: PhysicsDirectSpaceState3D = m.get_world_3d().direct_space_state
	var yaw := 0.0
	var start: Vector3 = p.global_position
	var found := false
	for r in [0.0, 8.0, 16.0, 24.0, 32.0, 40.0]:
		for j in (1 if r == 0.0 else 8):
			var c: Vector3 = p.global_position + Vector3(cos(j * TAU / 8.0), 0, sin(j * TAU / 8.0)) * r
			var dn := ss.intersect_ray(PhysicsRayQueryParameters3D.create(c + Vector3(0, 3, 0), c + Vector3(0, -5, 0), Game.WORLD))
			if dn.is_empty():
				continue
			c = dn.position
			for k in 24:
				var y2 := k * TAU / 24.0
				var fw := Vector3(-sin(y2), 0, -cos(y2))
				var clear := true
				for hh in [0.5, 1.2, 1.8]:
					var o: Vector3 = c + Vector3(0, hh, 0)
					if not ss.intersect_ray(PhysicsRayQueryParameters3D.create(o, o + fw * 26.0, Game.WORLD)).is_empty() \
							or not ss.intersect_ray(PhysicsRayQueryParameters3D.create(o, o - fw * 13.0, Game.WORLD)).is_empty():
						clear = false
						break
				if clear:
					yaw = y2
					start = c + Vector3(0, 0.1, 0)
					found = true
					break
			if found: break
		if found: break
	p.global_position = start
	p.rotation.y = yaw
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var side := Vector3(fwd.z, 0, -fwd.x)
	var base: Vector3 = p.global_position
	var lis: Node = al[0]
	var vic: Node = al[1]
	var mate: Node = al[2]
	var guns: Array = []
	for w in Game.MOD_FITS:
		if "tlumic" in Game.MOD_FITS[w] and Game.ITEMS.has(w):
			guns.append(w)
	var bad := 0
	for w in guns:
		var row := {}
		for quiet in [false, true]:
			_arm(p, w, quiet)
			var rule: Dictionary = Game.ITEMS[w]
			# 1) hearing: a listener 12 m behind, out of sight
			for a in al:
				_reset(a)
			_place(lis, base - fwd * 12.0, yaw)
			_place(vic, base + Vector3(0, -200, 0), yaw)
			_place(mate, base + Vector3(0, -200, 0) + side * 5.0, yaw)
			await at.get_tree().physics_frame
			p.global_position = base
			p.rotation.y = yaw
			p.pitch = 0.6                     # into the sky
			var q0: int = p.quiet_shots
			p._shoot("rh", p.inv["rh"], rule)
			await at.get_tree().create_timer(0.15).timeout
			var heard: bool = lis.alert or lis.state != lis.S.LURK
			var snd_quiet: bool = p.quiet_shots > q0
			# 2) a hit from behind, from the dark: victim 16 m ahead facing away, a mate 6 m past it
			if vic.dead:
				for a in m.aliens():
					if not a.dead and not a in al and a.has_method("quiet_hit") and not a.R.has("melee") and not a.R.has("hover"):
						al[1] = a
						vic = a
						break
			for a in al:
				_reset(a)
			_place(lis, base + Vector3(0, -200, 0) - fwd * 30.0, yaw)
			_place(vic, base + fwd * 16.0, yaw)
			_place(mate, base + fwd * 22.0 + side * 1.5, yaw)
			vic.hp = 5000.0
			await at.get_tree().physics_frame
			var hit := false
			for i in 10:
				p.global_position = base
				p.spread_bloom = 0.0
				at._aim_at(p, vic.global_position + Vector3(0, 1.0, 0))
				await at.get_tree().physics_frame
				var h0: float = vic.hp
				p.fire_cd = 0.0
				p._shoot("rh", p.inv["rh"], rule)
				await at.get_tree().create_timer(0.12).timeout
				if vic.hp < h0:
					hit = true
					break
			var vic_knows: bool = vic._knows(p)
			var vic_err: float = (vic.last_seen as Vector3).distance_to(p.global_position)
			var mate_knows: bool = mate._knows(p)
			# 3) a kill: the mate must not learn who it was
			for a in [vic, mate]:
				_reset(a)
			vic.hp = 1.0
			var killed := false
			for i in 10:
				p.global_position = base
				p.spread_bloom = 0.0
				at._aim_at(p, vic.global_position + Vector3(0, 1.0, 0))
				await at.get_tree().physics_frame
				p.fire_cd = 0.0
				p._shoot("rh", p.inv["rh"], rule)
				await at.get_tree().create_timer(0.12).timeout
				if vic.dead:
					killed = true
					break
			var mate_knows_kill: bool = mate._knows(p)
			row["loud" if not quiet else "quiet"] = [heard, snd_quiet, hit, vic_knows, vic_err, mate_knows, killed, mate_knows_kill]
		var L: Array = row["loud"]
		var Q: Array = row["quiet"]
		# the model and the save
		var gm: Node3D = Game.model(w)
		var part_ok := false
		if gm:
			Game.dress_gun(gm, w, p.merc)
			var pt := gm.find_child("Part_tlumic", true, false) as Node3D
			part_ok = pt != null and pt.visible
			gm.free()
		var saved: Variant = str_to_var(var_to_str(p.merc))
		var save_ok: bool = saved is Dictionary and Game.has_mod(w, "tlumic", saved)
		var ok: bool = L[0] and not Q[0] and not L[1] and Q[1] and Q[2] and not Q[3] and Q[4] > 0.3 and not Q[5] and Q[6] and not Q[7] \
				and L[3] and L[5] and part_ok and save_ok
		if not ok:
			bad += 1
		at.out("[QUIET] %s loud: heard %s hit %s vic_knows %s mate_knows %s | quiet: heard %s sound %s hit %s vic_knows %s guess_off %.1f mate_knows %s kill %s mate_after %s | part %s save %s -> %s" % [
			w, L[0], L[2], L[3], L[5], Q[0], Q[1], Q[2], Q[3], Q[4], Q[5], Q[6], Q[7], part_ok, save_ok, "ok" if ok else "BAD"])
	# 4) the knife from behind with Tichý zabiják: dead, nobody knows
	var tal: Array = p.merc.get("talents", [])
	var knife_ok := false
	var vic2: Node = null
	for a in m.aliens():
		if not a.dead and a != mate and a != lis and a.has_method("quiet_hit") and not a.R.has("hover"):
			vic2 = a
			break
	if vic2:
		vic2.set_physics_process(false)
		if not "tichy_zabijak" in tal:
			tal.append("tichy_zabijak")
		p.merc["talents"] = tal
		p.inv["rh"] = {"id": "knife"}
		p._update_held()
		_reset(vic2)
		_reset(mate)
		p.global_position = base
		p.rotation.y = yaw
		_place(vic2, base + fwd * 1.1 + Vector3(0, 0, 0), yaw)
		_place(mate, base + fwd * 7.0 + side * 1.0, yaw)
		await at.get_tree().physics_frame
		at._aim_at(p, vic2.global_position + Vector3(0, 0.9, 0))
		p._melee_hit(Game.ITEMS["knife"])
		await at.get_tree().create_timer(0.2).timeout
		knife_ok = vic2.dead and not mate._knows(p)
		at.out("[QUIET] knife backstab dead %s mate_knows %s" % [vic2.dead, mate._knows(p)])
	tal.erase("tichy_zabijak")
	# 5) footsteps: walking 4.5 m beside a listener (out of sight) - heard; Kočičí krok or crouched - not
	var steps := {}
	var lis2: Node = mate
	for case in ["walk", "cat", "crouch"]:
		if case == "cat":
			tal.append("kocici_krok")
		else:
			tal.erase("kocici_krok")
		p.merc["talents"] = tal
		p.crouching = case == "crouch"
		p.inv.erase("rh")
		p._update_held()
		p.global_position = base
		p.rotation.y = yaw
		p.velocity = Vector3.ZERO
		_reset(lis2)
		_place(lis2, base + side * 4.5 - fwd * 0.5, yaw + PI)      # facing away from the walker's path
		await at.get_tree().create_timer(0.3).timeout
		_reset(lis2)
		Input.action_press("move_forward")
		await at.get_tree().create_timer(2.6).timeout
		Input.action_release("move_forward")
		steps[case] = [lis2.alert or lis2.state != lis2.S.LURK, p.global_position.distance_to(base)]
	tal.erase("kocici_krok")
	p.crouching = false
	var steps_ok: bool = steps["walk"][0] and not steps["cat"][0] and not steps["crouch"][0] and float(steps["walk"][1]) > 1.0
	at.out("[QUIET] steps walk heard %s (%.1f m) cat heard %s (%.1f m) crouch heard %s (%.1f m)" % [steps["walk"][0], steps["walk"][1], steps["cat"][0], steps["cat"][1], steps["crouch"][0], steps["crouch"][1]])
	at.out("RESULT quiettest guns %d bad %d knife %s steps %s" % [guns.size(), bad, knife_ok, steps_ok])
	at.get_tree().quit()

## Co-op (quiethost / quietclient): the client fires a silenced pistol into the sky, then the same
## pistol without it. The host - who decides what the aliens hear - must play the quiet shot for the
## client's mercenary and its listener 12 m behind him must hear only the loud one.
static func pair(at: Node, p: Node) -> void:
	if p == null: return
	at._skip_brief()
	var m: Node = at.m()
	if at.step > 0 or not m.started() or m.players().size() < 2: return
	at.step = 1
	m.hud.inventory_open = false
	p.hp = 9999.0
	var host := Game.autotest() == "quiethost"
	if not host:
		await at.get_tree().create_timer(3.0).timeout
		_arm(p, "pistol", true)
		p.pitch = 0.6
		await at.get_tree().physics_frame
		p._shoot("rh", p.inv["rh"], Game.ITEMS["pistol"])
		await at.get_tree().create_timer(2.0).timeout
		_arm(p, "pistol", false)
		p.fire_cd = 0.0
		p._shoot("rh", p.inv["rh"], Game.ITEMS["pistol"])
		at.out("RESULT quietcoop client quiet_shots %d" % p.quiet_shots)
		await at.get_tree().create_timer(2.0).timeout
		at.get_tree().quit()
		return
	m.t = m.CALM_TIME + 5.0
	var mate: Node = null
	for q in m.players():
		if q != p:
			mate = q
	var lis: Node = null
	for a in m.aliens():
		a.set_physics_process(false)
		if lis == null and a.has_method("quiet_hit") and not a.R.has("melee"):
			lis = a
		else:
			a.global_position += Vector3(0, -200, 0)
	var quiet_sound := false
	var quiet_heard := true
	var loud_heard := false
	if lis and mate:
		_reset(lis)
		var back: Vector3 = mate.global_transform.basis.z
		back.y = 0
		_place(lis, mate.global_position + back.normalized() * 12.0, mate.rotation.y)
		var fired0: float = mate._fired_at
		for i in 80:
			await at.get_tree().create_timer(0.1).timeout
			if mate.quiet_shots > 0:
				break
		quiet_sound = mate.quiet_shots > 0
		await at.get_tree().create_timer(0.4).timeout
		quiet_heard = lis.alert or lis.state != lis.S.LURK
		_reset(lis)
		var fired1: float = mate._fired_at
		for i in 60:
			await at.get_tree().create_timer(0.1).timeout
			if mate._fired_at != fired1 and mate._fired_at != fired0:
				break
		await at.get_tree().create_timer(0.4).timeout
		loud_heard = lis.alert or lis.state != lis.S.LURK
	at.out("RESULT quietcoop host listener %s quiet_sound %s quiet_heard %s loud_heard %s" % [lis != null, quiet_sound, quiet_heard, loud_heard])
	await at.get_tree().create_timer(3.0).timeout
	at.get_tree().quit()
