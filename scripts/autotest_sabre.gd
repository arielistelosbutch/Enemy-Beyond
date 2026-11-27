extends RefCounted
## sabretest (Ari 2026-11-27: „šavli z cizáckých slitin… velmi účinná nablízko, delší než dýka a dá
## se kombinovat se štítem“). Ve štítu (levá ruka) a se šavlí (pravá) proti Ještěřanovi zepředu:
##  - shield: šavle jde do pravé ruky se štítem v levé, štít po vzetí šavle zůstane,
##  - near: na 1,4 m sekne šavle víc než nůž (a prořízne část pancíře: víc než jen poměr poškození),
##  - far: na 2,6 m nůž nedosáhne, šavle ano,
##  - swing: celý úder (V / levé tlačítko) zasáhne, i se zvednutým štítem,
##  - clip: zvenku si bere seknutí obušku, dokud nemá vlastní.
## Výsledek „RESULT sabretest …“.

static func run(at: Node, p: Node) -> void:
	if p == null: return
	at._skip_brief()
	if at.step > 0 or not at.m().started() or at.m().aliens().is_empty(): return
	at.step = 1
	var m: Node = at.m()
	m.hud.inventory_open = false
	p.hp = 9999.0
	p.max_hp = 9999.0
	var vic: Node = null
	for a in m.aliens():
		a.set_physics_process(false)
		if vic == null and a.has_method("taken") and not a.R.has("hover") and a.race.begins_with("jestetan"):
			vic = a
		else:
			a.global_position += Vector3(0, -200, 0)
	if vic == null:
		at.out("RESULT sabretest no lizard")
		at.get_tree().quit()
		return
	# a spot with 4 m of open ground ahead
	var ss: PhysicsDirectSpaceState3D = m.get_world_3d().direct_space_state
	var yaw := 0.0
	var start: Vector3 = p.global_position
	var found := false
	for r in [0.0, 6.0, 12.0, 18.0, 24.0]:
		for j in (1 if r == 0.0 else 8):
			var c: Vector3 = p.global_position + Vector3(cos(j * TAU / 8.0), 0, sin(j * TAU / 8.0)) * r
			var dn := ss.intersect_ray(PhysicsRayQueryParameters3D.create(c + Vector3(0, 3, 0), c + Vector3(0, -5, 0), Game.WORLD))
			if dn.is_empty(): continue
			c = dn.position
			for k in 12:
				var y2 := k * TAU / 12.0
				var fw := Vector3(-sin(y2), 0, -cos(y2))
				var clear := true
				for hh in [0.5, 1.2, 1.8]:
					var o: Vector3 = c + Vector3(0, hh, 0)
					if not ss.intersect_ray(PhysicsRayQueryParameters3D.create(o, o + fw * 4.5, Game.WORLD)).is_empty():
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
	# the shield in the left hand, the sabre in the right
	p.inv["lh"] = {"id": "stit"}
	var refuse := Game.slot_refuse("rh", "savle")
	p.inv["rh"] = {"id": "savle"}
	p._update_held()
	await at.get_tree().physics_frame
	var shield_ok: bool = refuse == "" and not Game.two_handed("savle") and p.item_in("lh").get("id", "") == "stit" \
		and p.held == "savle" and p.held_l == "stit"
	at.out("[SABRE] shield %s (refuse '%s', held %s / %s)" % [shield_ok, refuse, p.held, p.held_l])
	var tal: Array = p.merc.get("talents", [])
	tal.erase("rvac")
	p.merc["talents"] = tal
	# one cut with each blade from a distance: how much it took off
	var cut := func(w: String, d: float) -> float:
		vic.hp = 1000.0
		vic.state = vic.S.COMBAT
		vic.sus[String(p.name)] = 1.0
		vic.global_position = p.global_position + fwd * d
		vic.rotation.y = yaw + PI          # facing the soldier: no blow from behind
		vic.velocity = Vector3.ZERO
		await at.get_tree().physics_frame
		await at.get_tree().physics_frame
		at._aim_at(p, vic.global_position + Vector3(0, 1.0, 0))
		p._melee_hit(Game.ITEMS[w])
		await at.get_tree().physics_frame
		return 1000.0 - float(vic.hp)
	var kn_near: float = await cut.call("knife", 1.4)
	var sv_near: float = await cut.call("savle", 1.4)
	var kn_far: float = await cut.call("knife", 2.6)
	var sv_far: float = await cut.call("savle", 2.6)
	var ratio: float = float(Game.ITEMS["savle"]["damage"]) / float(Game.ITEMS["knife"]["damage"])
	var near_ok: bool = kn_near > 0.0 and sv_near > kn_near * ratio * 1.05      # (more than the plain ratio: the alloy cuts the armour)
	var far_ok: bool = kn_far == 0.0 and sv_far > 0.0
	at.out("[SABRE] near knife %.1f sabre %.1f (ratio %.2f)  far knife %.1f sabre %.1f" % [kn_near, sv_near, sv_near / maxf(kn_near, 0.01), kn_far, sv_far])
	# the whole blow, with the shield up
	vic.hp = 1000.0
	vic.global_position = p.global_position + fwd * 1.8
	vic.rotation.y = yaw + PI
	p.shield_up = true
	p.fire_cd = 0.0
	at._aim_at(p, vic.global_position + Vector3(0, 1.0, 0))
	p._melee("rh", Game.ITEMS["savle"])
	await at.get_tree().create_timer(0.8).timeout
	var swing_ok: bool = float(vic.hp) < 1000.0
	p.shield_up = false
	# the outside clip: the baton's cut until the sabre has its own
	p.held = "savle"
	var like: String = p._tp_like("strike")
	var clip_ok: bool = like == ("savle" if not AnimClips.get_clip("tp_strike_savle").is_empty() else "stun_baton")
	at.out("[SABRE] swing %s (hp %.0f)  clip %s -> %s" % [swing_ok, vic.hp, like, clip_ok])
	at.out("RESULT sabretest shield %s near %s far %s swing %s clip %s" % [shield_ok, near_ok, far_ok, swing_ok, clip_ok])
	at.get_tree().quit()

## shielddraw (Ari 2026-11-27: „štít se nenasadí z hotbaru“): štít na opasku a klávesa opasku
##  - rifle: s puškou v rukou jde štít na levou ruku a puška na záda,
##  - sabre: se šavlí v ruce jde štít na ruku a šavle zůstane,
##  - swap: druhý štít z opasku vymění ten na ruce (starý jde na jeho místo),
##  - stow: klávesa prázdného slotu, odkud štít přišel, ho vrátí na opasek.
## Výsledek „RESULT shielddraw rifle … sabre … swap … stow …“.
static func draw(at: Node, p: Node) -> void:
	if p == null: return
	at._skip_brief()
	if at.step > 0 or not at.m().started(): return
	at.step = 1
	at.m().hud.inventory_open = false
	var wait := func():
		for i in 120:
			await at.get_tree().physics_frame
			if p.busy <= 0.0: break
		await at.get_tree().physics_frame
	for s in ["rh", "lh", "back", "side", "b0", "b1", "b2", "b3"]:
		p.inv.erase(s)
	p.inv["rh"] = {"id": "rifle", "loaded": 30}
	p.inv["b0"] = {"id": "stit"}
	p.busy = 0.0
	p._update_held()
	p._belt_key(0)
	await wait.call()
	var rifle_ok: bool = p.item_in("lh").get("id", "") == "stit" and not p.inv.has("rh") \
		and p.item_in("back").get("id", "") == "rifle" and p.held_l == "stit"
	at.out("[SHIELD] rifle %s lh %s rh %s back %s held_l %s" % [rifle_ok, p.item_in("lh"), p.item_in("rh"), p.item_in("back"), p.held_l])
	p.inv["rh"] = {"id": "savle"}
	p.inv["b1"] = {"id": "stit_x"}
	p._update_held()
	p._belt_key(1)
	await wait.call()
	var sabre_ok: bool = p.item_in("rh").get("id", "") == "savle" and p.item_in("lh").get("id", "") == "stit_x" and p.held == "savle"
	var swap_ok: bool = p.item_in("b1").get("id", "") == "stit"
	at.out("[SHIELD] sabre %s swap %s lh %s rh %s b1 %s" % [sabre_ok, swap_ok, p.item_in("lh"), p.item_in("rh"), p.item_in("b1")])
	p.inv.erase("b1")
	p._belt_key(1)
	await wait.call()
	var stow_ok: bool = not p.inv.has("lh") and p.item_in("b1").get("id", "") == "stit_x" and p.item_in("rh").get("id", "") == "savle"
	at.out("RESULT shielddraw rifle %s sabre %s swap %s stow %s" % [rifle_ok, sabre_ok, swap_ok, stow_ok])
	at.get_tree().quit()
