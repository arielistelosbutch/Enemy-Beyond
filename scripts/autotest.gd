extends Node
## Headless/xvfb test driver. Added by the mission when --autotest=... is given.
## solo: plays a short fight as the local player and goes home.
## shot: takes screenshots from a few places.  host/client: checks the sync.

var mode := ""
var t := 0.0
var step := 0
var log_t := 0.0
var shots := 0

func m() -> Node:
	return get_parent()

func out(s: String) -> void:
	print("[AT %5.1f] %s" % [t, s])

func _process(delta: float) -> void:
	t += delta
	var p: Node = m().local_player()
	log_t -= delta
	if log_t <= 0:
		log_t = 2.0
		var al: Array = m().aliens()
		var states := []
		for a in al:
			states.append("%s%s" % ["x" if a.dead else ("!" if a.alert else "."), "" ])
		out("blk=%s vet=%s players=%d aliens=%d alive=%d %s me=%s" % [m().hud.inventory_open, Game.veteran(), m().players().size(), al.size(), m().alive_aliens(), "".join(states),
			("hp %.0f pos %s kills %d ammo %s busy %s" % [p.hp, p.global_position.snapped(Vector3.ONE * 0.1), p.kills, p.weapon().get("loaded", -1), p.busy_text if p.busy > 0 else ""]) if p else "-"])
	if Game.cmd_arg("speak", "") == "1" and step < 900 and t > 5.0 and not has_meta("spoke"):
		set_meta("spoke", true)
		var smp := PackedFloat32Array()
		for i in 18000:
			var x := float(i) / 11025.0
			smp.append(sin(TAU * 150.0 * x) * maxf(0.0, sin(TAU * 3.0 * x)) * 0.4)
		for i in 6000:
			smp.append(0.0)
		m().voice.test_speak(smp)
		out("client speaks")
	match mode:
		"solo", "campaign": _solo(p)
		"shot": _shot(p)
		"ai": _ai(p)
		"arsenal": _arsenal(p)
		"town": _town(p)
		"zoo": _zoo(p)
		"voice": _voice_test(p)
		"club": _club(p)
		"uimission": _ui_mission(p)
		"stance": _stance(p)
		"wshot": _wshot(p)
		"terror": _terror(p)
		"panic":
			if p and step == 0 and t > 3:
				step = 1
				var it: Dictionary = p.inv["rh"]; p.inv.erase("rh"); p._update_held()
				m().drop_item(it, p.global_position)
				out("dropped -> rh=%s pickups=%d" % [p.item_in("rh").get("id", "-"), m().pickups.size()])
			if p and step == 1 and t > 4:
				step = 2
				p._pick_up()
				out("picked up -> rh=%s pickups=%d gun visible %s" % [p.item_in("rh").get("id", "-"), m().pickups.size(), p.gun.visible])
			if p and p.panic == "" and t < 40: p.stress = 100.0
			if p and p.panic != "" and log_t > 1.95:
				out("PANIC %s rh=%s pickups=%d pos %s" % [p.panic, p.item_in("rh").get("id", "-"), m().pickups.size(), p.global_position.snapped(Vector3.ONE * 0.1)])
			if p and t > 29.5 and t < 29.6 and p.panic == "" and not m().pickups.is_empty():
				p.global_position = m().pickups.values()[0]["node"].global_position
				p._pick_up()
				out("picked up -> rh=%s pickups=%d" % [p.item_in("rh").get("id", "-"), m().pickups.size()])
			if t > 33: get_tree().quit()
		"host", "client":
			if mode == "client":
				_solo(p)
			if t > 25.0:
				out("RESULT players=%d aliens=%d" % [m().players().size(), m().aliens().size()])
				get_tree().quit()
	if t > 120.0 and mode != "campaign":
		out("TIMEOUT")
		get_tree().quit()

func _aim_at(p: Node, pos: Vector3) -> void:
	var d: Vector3 = pos - (p.global_position + Vector3(0, 1.6, 0))
	p.rotation.y = atan2(-d.x, -d.z)
	p.pitch = atan2(d.y, Vector2(d.x, d.z).length())

func _nearest(p: Node) -> Node:
	var best: Node = null
	for a in m().aliens():
		if a.dead: continue
		if best == null or a.global_position.distance_to(p.global_position) < best.global_position.distance_to(p.global_position):
			best = a
	return best

func _solo(p: Node) -> void:
	if p == null: return
	if step == 0 and t > 3.0:
		step = 1
		out("teleport to the UFO, start the fight")
	if step == 1:
		var a := _nearest(p)
		if a == null:
			step = 2
			out("all aliens dead, going home")
			return
		# stand 6 m from the alien and shoot (a cheat: the test checks the rules, not the aim)
		if p.global_position.distance_to(a.global_position) > 7.0:
			var dir: Vector3 = (p.global_position - a.global_position)
			dir.y = 0
			p.global_position = a.global_position + dir.normalized() * 6.0 + Vector3(0, 0.3, 0)
		_aim_at(p, a.global_position + Vector3(0, 0.9, 0))
		Input.action_press("fire")
		Input.action_press("aim")
		if p.weapon().is_empty() or int(p.weapon().get("loaded", 0)) == 0:
			Input.action_release("fire")
			Input.action_press("reload")
		else:
			Input.action_release("reload")
		if p.downed:
			out("RESULT downed in the fight, kills %d" % p.kills)
			if mode == "solo": get_tree().quit()
		if t > 90.0 and mode == "solo":
			out("RESULT timeout in fight, alive %d kills %d" % [m().alive_aliens(), p.kills])
			get_tree().quit()
	if step == 2:
		Input.action_release("fire")
		Input.action_release("aim")
		p.global_position = m().map["evac"] + Vector3(0, 0.3, 0)
		Input.action_press("use")
		step = 3
	if step == 3 and m().finished and mode == "solo":
		out("RESULT finished, kills %d merc missions %d" % [p.kills, Game.merc["missions"]])
		get_tree().quit()

func _snap(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://" + name + ".png")
	out("screenshot " + ProjectSettings.globalize_path("user://" + name + ".png"))

func _shot(p: Node) -> void:
	if p == null: return
	p.hp = max(p.hp, 25.0)      # the camera must survive the photo session
	p.bleeding = 0.0
	var mp: Dictionary = m().map
	var plan := [
		[2.5, "01_briefing", func(): pass],
		[12.0, "02_skyranger", func(): pass],
		[16.0, "03_truck", func():
			out("truck at %s" % mp["truck"])
			if mp["truck"] != Vector3.ZERO:
				p.global_position = mp["truck"] + Vector3(6.5, 0.3, -3.0)
				_aim_at(p, mp["truck"] + Vector3(0, 0.8, 0))],
		[20.0, "04_house", func():
			if mp["house"] != Vector3.ZERO:
				p.global_position = mp["house"] + Vector3(0, 0.3, -2.5)
				_aim_at(p, mp["house"] + Vector3(-1.0, 1.0, 3.5))],
		[24.0, "05_cow", func():
			if not mp["cows"].is_empty():
				var c: Vector3 = mp["cows"][0]
				p.global_position = c + Vector3(3.5, 0.3, 3.5)
				_aim_at(p, c + Vector3(0, 0.4, 0))
			elif mp["circle"] != Vector3.ZERO:
				p.global_position = mp["circle"] + Vector3(0, 0.3, 7)
				_aim_at(p, mp["circle"])],
		[28.0, "06_lightning", func():
			var u: Vector3 = mp["ufo"]
			p.global_position = u + Vector3(-6, 0.3, 16)
			_aim_at(p, u + Vector3(0, 1.0, 0))
			m()._flash_t = 1.0],
		[32.0, "07_alien", func():
			var a := _nearest(p)
			if a:
				var fwd: Vector3 = -a.global_transform.basis.z
				p.global_position = a.global_position + fwd * 3.2 + Vector3(0, 0.3, 0)
				_aim_at(p, a.global_position + Vector3(0, 0.9, 0))
				p.light_on = true],
		[34.0, "07b_alien_flash", func():
			m()._flash_t = 1.0],
		[38.0, "09_ship", func():
			p.global_position = mp["evac"] + Vector3(5, 0.3, 13)
			_aim_at(p, mp["evac"] + Vector3(0, 1.0, -1))
			m()._flash_t = 1.0],
		[44.0, "10_mercs", func():
			# a look at two mercs and a grey, under the dropship lamp
			var ev: Vector3 = mp["evac"]
			var poses := [["idle", Vector3(-0.6, 0, 3.0), 0.3], ["crouch", Vector3(0.7, 0, 2.6), -0.4], ["prone", Vector3(0.0, 0, 1.0), 0.0]]
			for ps in poses:
				var mm := Game.model("merc")
				m().add_child(mm)
				mm.global_position = ev + ps[1]
				mm.rotation.y = PI + ps[2]
				var ap: AnimationPlayer = mm.find_child("AnimationPlayer", true, false)
				ap.play(ps[0])
				if ps[0] == "prone":
					mm.rotation.x = PI / 2
					mm.position.y += 0.18
				for g in mm.find_children("Gear_Cap", "MeshInstance3D", true, false): g.visible = false
			p.global_position = ev + Vector3(0, 0.3, 5.6)
			_aim_at(p, ev + Vector3(0, 1.0, 2.6))
			p.light_on = true],
		[46.0, "11_reload", func():
			p.inv["rh"]["loaded"] = 0
			p._reload(p.inv["rh"], Game.ITEMS["rifle"])],
		[50.0, "12_dual", func():
			p.inv.erase("rh")
			p.inv["rh"] = {"id": "magnum", "loaded": 6}
			p.inv["lh"] = {"id": "scanner"}
			p._update_held()],
		[53.0, "13_knife_flare", func():
			p.inv["rh"] = {"id": "knife"}
			p.inv["lh"] = {"id": "flare"}
			p._update_held()],
		[56.0, "14_minigun", func():
			p.inv.erase("lh")
			p.inv["rh"] = {"id": "minigun", "loaded": 150}
			p._update_held()],
		[59.0, "15_sprint", func():
			p.inv["rh"] = {"id": "shotgun", "loaded": 6}
			p._update_held()
			Input.action_press("sprint")
			Input.action_press("move_forward")],
		[62.0, "16_autocannon", func():
			Input.action_release("sprint")
			Input.action_release("move_forward")
			p.inv["rh"] = {"id": "autocannon", "loaded": 8}
			p._update_held()],
		[65.0, "17_rocket", func():
			p.inv["rh"] = {"id": "rocket_launcher", "loaded": 1}
			p._update_held()],
		[68.0, "08_phantom", func():
			p.stress = 90.0
			m()._hallu_t = 0.0],
	]
	if step < plan.size():
		var e: Array = plan[step]
		if t > e[0] - (0.6 if e[1] in ["06_lightning", "07b_alien_flash", "09_ship"] else 2.5) and shots == step:
			e[2].call()
			shots += 1
		if t > e[0]:
			_snap(e[1])
			step += 1
	elif t > 69.0:
		out("phantom seen: %s" % (m()._phantom != null))
		get_tree().quit()

## Watch the aliens' brains: the merc stands still near the UFO.
var _ai_log := 0.0
func _ai(p: Node) -> void:
	if p == null: return
	if step == 0 and t > 1.0:
		step = 1
		p.global_position = m().map["ufo"] + Vector3(0, 0.3, 18)
		if Game.cmd_arg("skip", "") != "":
			m().t += float(Game.cmd_arg("skip", "0"))
			p.global_position = m().map["evac"] + Vector3(0, 0.3, 0)
			p.hp = 9999.0
	if p.downed and step < 3:
		pass
	if step == 1 and t > 40.0 and Game.veteran() and p.stress < 90:
		p.stress = 100.0   # force a panic test
	if step == 1 and t > 85.0:
		step = 2
		out("forcing the merc down to see if they drag him")
		p.hurt(999.0, p.global_position)
	_ai_log -= get_process_delta_time()
	if _ai_log <= 0:
		_ai_log = 3.0
		var l := []
		for a in m().aliens():
			l.append("%s:%s/%s d%.0f%s" % [a.name, a.S.keys()[a.state], a.phase, a.global_position.distance_to(p.global_position), " L" if a.lurking else ""])
		out("  vet=%s panic=%s pickups=%d calm=%s hp=%.0f carried=%d stress=%.0f | %s" % [Game.veteran(), p.panic, m().pickups.size(), m().calm(), p.hp, p.carried_by, p.stress, ", ".join(l)])
	if t > 115.0:
		out("RESULT ai watch done hp %.0f downed %s carried %d" % [p.hp, p.downed, p.carried_by])
		get_tree().quit()

## Tries every weapon on the nearest alien, then the baton, smoke, a mine.
var _ars_i := 0
var _ars_t := 0.0
const ARS := ["rocket_launcher", "magnum", "autocannon", "minigun", "shotgun", "knife", "stun_baton"]
var _ars_last := ""
func _arsenal(p: Node) -> void:
	if p == null or t < 3.0: return
	for al in m().aliens():
		var st := "%s:%s%.0f/%.0f" % [al.name, "C" if al.captured else ("X" if al.dead else ""), al.hp, al.stun_dmg]
		if not (st in _ars_last):
			pass
	var snap := ""
	for al in m().aliens():
		snap += "%s:%s%.0f/%.0f " % [al.name, "C" if al.captured else ("X" if al.dead else ""), al.hp, al.stun_dmg]
	if snap != _ars_last:
		_ars_last = snap
		out("  aliens " + snap)
	m().hud.inventory_open = false
	p.hp = max(p.hp, 30.0)
	_ars_t -= get_process_delta_time()
	var a := _nearest(p)
	if a == null:
		out("RESULT arsenal: all aliens down, kills %d captures %d" % [p.kills, p.captures])
		get_tree().quit()
		return
	if _ars_t <= 0:
		_ars_t = 2.5
		if _ars_i < ARS.size():
			var id: String = ARS[_ars_i]
			p.inv.erase("lh")
			p.inv["rh"] = {"id": id, "loaded": Game.mag_size(id)} if Game.ITEMS[id]["type"] == "weapon" else {"id": id}
			p._update_held()
			out("weapon %s, alien %s hp %.0f stun %.0f" % [id, a.name, a.hp, a.stun_dmg])
			_ars_i += 1
		elif _ars_i == ARS.size():
			m().add_smoke(a.global_position)
			out("smoke blocks: %s" % m().smoke_blocks(p.global_position + Vector3.UP, a.global_position + Vector3.UP))
			m().add_mine(a.global_position, p.name)
			_ars_i += 1
	var id2: String = p.item_in("rh").get("id", "")
	var reach := 1.2 if Game.ITEMS.get(id2, {}).get("type", "") == "melee" else 7.0
	var dir: Vector3 = (p.global_position - a.global_position)
	dir.y = 0
	if Game.ITEMS.get(id2, {}).get("type", "") == "melee":
		# from behind for the knife
		dir = a.global_transform.basis.z
	p.global_position = a.global_position + dir.normalized() * reach + Vector3(0, 0.3, 0)
	_aim_at(p, a.global_position + Vector3(0, 0.9, 0))
	p.spin = 1.0
	if Game.ITEMS.get(id2, {}).get("type", "") == "melee":
		p._melee("rh", Game.ITEMS[id2]) if p.fire_cd <= 0 else null
	else:
		var w: Dictionary = p.gun_in("rh")
		if not w.is_empty() and p.fire_cd <= 0 and int(w.get("loaded", 0)) > 0:
			p._shoot("rh", w, Game.ITEMS[id2])
	if t > 60.0:
		out("RESULT arsenal timeout kills %d captures %d" % [p.kills, p.captures])
		get_tree().quit()

## A look around a generated map (biome/time from the command line).
func _town(p: Node) -> void:
	if p == null: return
	p.hp = max(p.hp, 25.0)
	m().hud.inventory_open = false
	var mp: Dictionary = m().map
	var shots := [[11.0, "30_a", Vector3(36, 1.6, 30), Vector3(30, 1.4, 40)], [13.0, "31_b", mp["ufo"] + Vector3(-10, 1.5, 14), mp["ufo"] + Vector3(0, 1.5, 0)],
		[15.0, "32_c", mp["evac"] + Vector3(4, 1.6, 14), mp["evac"] + Vector3(4, 1.4, 30)]]
	if step < shots.size():
		var e: Array = shots[step]
		if t > e[0] - 1.5:
			p.global_position = e[2] - Vector3(0, 1.3, 0)
			_aim_at(p, e[3])
		if t > e[0]:
			_snap(e[1])
			step += 1
	elif t > 16.0:
		get_tree().quit()

## Line-up of the whole roster for screenshots (frozen, lit).
const ZOO := ["grey", "grey_velitel", "diskoll", "levit", "ohar", "jestetan", "jestetan_velitel", "lihnoun", "bijec", "bijec_velitel", "nador", "ohnivec", "myslodej", "kolos"]
## Fake speech into the voice system: snippets get stored, an alien plays one back.
var _vt := 0.0
func _voice_test(p: Node) -> void:
	if p == null: return
	_skip_brief()
	p.hp = 999.0
	var v: Node = m().voice
	if step == 0 and t > 1.0:
		step = 1
		m().t += 70.0
		v.mimic_t = 6.0
		var a0: Node = m().aliens()[0]
		a0.global_position = p.global_position + Vector3(14, 0, 0)
	_vt -= get_process_delta_time()
	if step == 1 and _vt <= 0:
		_vt = 3.0
		var smp := PackedFloat32Array()
		var dur := randf_range(1.0, 2.2)
		for i in int(dur * 11025):
			var x := float(i) / 11025.0
			var syl := maxf(0.0, sin(TAU * 3.5 * x))
			var f0 := 130.0 + 20.0 * sin(TAU * 0.8 * x)
			var w := sin(TAU * f0 * x) * 0.5 + sin(TAU * f0 * 2.0 * x) * 0.3 + sin(TAU * 700.0 * x) * 0.15
			smp.append(w * syl * 0.4)
		for i in 6000:
			smp.append(0.0)
		v.test_speak(smp)
		out("spoke %.1f s, talking=%s radio=%s" % [dur, v.talking, v.on_radio])
	if t > 60.0:
		out("RESULT voice: snippets %s" % [v.snippets.keys()])
		get_tree().quit()

## Baton held upright + three swing variants (screenshots mid-swing); ammo on the belt key.
func _club(p: Node) -> void:
	if p == null: return
	if p._swing > 0 and p.gun:
		out("  swing %.2f kind %d rot %s pos %s" % [1.0 - p._swing, p._swing_kind, p.gun.rotation.snapped(Vector3.ONE * 0.01), p.gun.position.snapped(Vector3.ONE * 0.01)])
	_skip_brief()
	p.hp = 999.0
	m().hud.inventory_open = false
	if step == 0 and t > 2.0:
		step = 1
		p.inv["rh"] = {"id": "stun_baton"}
		p.inv["b2"] = {"id": "shells"}
		p._update_held()
		p.light_on = true
	if step == 1 and t > 3.0:
		_snap("60_club_hold")
		step = 2
	for k in 3:
		var t0 := 4.0 + k * 1.5
		if step == 2 + k * 2 and t > t0:
			p._melee("rh", Game.ITEMS["stun_baton"])
			out("swing kind %d" % p._swing_kind)
			step += 1
		if step == 3 + k * 2 and t > t0 + float(Game.cmd_arg("swingt", "0.27")):
			_snap("61_club_swing_%d" % k)
			step += 1
	if step == 8 and t > 9.0:
		p.inv["rh"] = {"id": "shotgun", "loaded": 2}
		p._update_held()
		p._belt_key(2)
		out("belt key on shells: busy=%s rh=%s" % [p.busy_text, p.item_in("rh").get("id", "")])
		step = 9
	if step == 9 and t > 12.0:
		out("RESULT club: rh=%s loaded=%s" % [p.item_in("rh").get("id", ""), p.item_in("rh").get("loaded", -1)])
		get_tree().quit()

## Every HUD window with the longest texts it can get, checked for overflow.
var _uim_busy := false
func _ui_mission(p: Node) -> void:
	if p == null or _uim_busy or step > 0:
		return
	_uim_busy = true
	step = 1
	var h: Node = m().hud
	await get_tree().create_timer(1.0).timeout
	await _uic("m_briefing")
	_skip_brief()
	await get_tree().create_timer(3.0).timeout
	h.message("[RÁDIO] Pilot: Ztrácím signál od Vendula Sokolová! Někdo k ní běžte, než ji něco odtáhne do tmy. Opakuji, ztrácím signál!", 5.0)
	h.radio_from("Zdeněk Kopecký")
	p.inv["rh"] = {"id": "stun_baton"}
	p.inv["lh"] = {"id": "magnum", "loaded": 6}
	p._update_held()
	await _uic("m_hud")
	h._open_inventory()
	await _uic("m_inventory")
	h._close_inventory()
	h._pause()
	await _uic("m_pause")
	h.pause_panel.visible = false
	h.paused = false
	var lines := []
	for i in 4:
		lines.append("Bořek Krejčí %d - zabití 12, zajato 3 - v bezvědomí" % i)
	lines.append("Civilisté: zachráněno 3, mrtvých 4, ztraceno ve tmě 1")
	h.show_result("MISE NEÚSPĚŠNÁ", "Tým se stáhl z mise.\n\n" + "\n".join(lines) + "\n\nTvůj žoldák: zraněn - uzdraví se za 120 min\nZkušenosti +345  (Desátník)\nPOVÝŠEN: Desátník! Přesnost +3, Odvaha +2. Vyber si talent v menu Můj žoldák.\n\nTeror (Městečko u Jihlavy): neúspěch. Odměna 120 kr, důvěra -14. Padlí: 2. Civilisté: zachráněno 3, mrtvých 4.")
	await _uic("m_result")
	get_tree().quit()

## Stance icons and the out-of-breath sprint lock.
func _stance(p: Node) -> void:
	if p == null or step > 0:
		return
	step = 1
	_skip_brief()
	await get_tree().create_timer(3.5).timeout
	m().hud.inventory_open = false
	for e in [["stand", false, false], ["crouch", true, false], ["prone", false, true]]:
		p.crouching = e[1]
		p.prone = e[2]
		await get_tree().create_timer(0.4).timeout
		p.crouching = e[1]
		p.prone = e[2]
		get_viewport().get_texture().get_image().save_png("user://stance_%s.png" % e[0])
	p.crouching = false
	p.prone = false
	# sprint until out of breath: count how often sprint flips while Shift stays held
	Input.action_press("sprint")
	Input.action_press("move_forward")
	var flips := 0
	var last: bool = p.sprinting
	for i in 600:
		await get_tree().physics_frame
		if p.sprinting != last:
			flips += 1
			last = p.sprinting
		if i == 300:
			get_viewport().get_texture().get_image().save_png("user://stance_sprint.png")
	out("stamina %.1f winded %s flips %d" % [p.stamina, p._winded, flips])
	get_viewport().get_texture().get_image().save_png("user://stance_winded.png")
	Input.action_release("sprint")
	for i in 300:
		await get_tree().physics_frame
	Input.action_press("sprint")
	await get_tree().physics_frame
	await get_tree().physics_frame
	out("RESULT stance: after rest stamina %.1f sprinting again %s" % [p.stamina, p.sprinting])
	get_tree().quit()

func _wshot(p: Node) -> void:
	if p == null or step > 0:
		return
	step = 1
	_skip_brief()
	await get_tree().create_timer(3.5).timeout
	m().hud.inventory_open = false
	p.global_position = m().map["ufo"] + Vector3(4, 0.3, 16)
	_aim_at(p, m().map["ufo"] + Vector3(0, 1.0, 0))
	await get_tree().create_timer(1.5).timeout
	get_viewport().get_texture().get_image().save_png("user://weather_%s.png" % m().weather)
	get_tree().quit()

func _uic(tag: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	Game.ui_audit(m().hud, tag)
	if DisplayServer.get_name() != "headless":
		get_viewport().get_texture().get_image().save_png("user://ui_%s.png" % tag)

func _skip_brief() -> void:
	var h: Node = m().hud
	if h._brief_t >= 0 and h._brief_t < float(h._brief_len) / 40.0 + 2.5:
		h._brief_t = float(h._brief_len) / 40.0 + 2.5

func _zoo(p: Node) -> void:
	if p == null: return
	_skip_brief()
	m().hud.inventory_open = false
	p.hp = 999.0
	var al: Array = m().aliens()
	if step == 0 and t > 2.5 and al.size() >= ZOO.size():
		step = 1
		var base: Vector3 = m().map["ufo"] + Vector3(0, 0, 13)
		var right := Vector3(1, 0, 0)
		for i in al.size():
			var a: Node = al[i]
			a.set_physics_process(false)
			a.global_position = base + right * (i - al.size() / 2.0 + 0.5) * 2.2
			a.rotation.y = 0.0
			if a.anim:
				a.anim.play("idle")
		var l := OmniLight3D.new()
		l.light_energy = 3.0
		l.omni_range = 16.0
		m().add_child(l)
		l.global_position = base + Vector3(0, 4, 4)
		m().env.fog_density = 0.002
		p.global_position = base + Vector3(0, 0, 9)
		_aim_at(p, base + Vector3(0, 1.0, 0))
	if step == 1 and t > 4.5:
		_snap("50_zoo")
		step = 2
	if step >= 2 and step < 2 + al.size() and t > 4.5 + (step - 1) * 1.2:
		var a: Node = al[step - 2]
		var f: Vector3 = a.global_position
		p.global_position = f + Vector3(0.6, 0, -3.2)
		_aim_at(p, f + Vector3(0, 1.0, 0))
		if a.anim and a.anim.has_animation("attack"):
			a.anim.play("aim" if a.race in ["grey", "hlidac", "meduza"] else "attack")
		step += 1
		await get_tree().create_timer(0.9).timeout
		_snap("51_%s" % a.race)
	if step >= 2 + al.size() and t > 6.0 + al.size() * 1.2 + 1.0:
		get_tree().quit()

## Terror mission watch: god-mode merc, logs what the hunters and the civilians do.
var _ter_log := 0.0
var _ter_shot := 0
func _terror(p: Node) -> void:
	if p == null: return
	_skip_brief()
	m().hud.inventory_open = false
	p.hp = max(p.hp, 25.0)
	if p.downed:
		p.revived("test")
	if step == 0 and t > 1.0:
		step = 1
		m().t += 70.0     # skip the calm minute
	_ter_log -= get_process_delta_time()
	if _ter_log <= 0:
		_ter_log = 4.0
		var l := []
		for a in m().aliens():
			l.append("%s:%s:%s%s d%.0f v%.1f%s" % [a.name, a.race, "X" if a.dead else ("HUSK" if a.husk else a.S.keys()[a.state]), "*" if a.striking else "", a.global_position.distance_to(p.global_position), Vector2(a.velocity.x, a.velocity.z).length(), "F" if a.agent.is_navigation_finished() else ""])
		var c := []
		for cv in m().civilians():
			c.append("%s:%s" % [cv.name, "dead" + ("+" if cv.infected else "") if cv.dead else ("saved" if cv.saved else ["wander", "flee", "cower", "follow", "safe"][cv.st])])
		out("  hp=%.0f stress=%.0f | %s | civ %s" % [p.hp, p.stress, ", ".join(l), ", ".join(c)])
	# a few screenshots of whatever comes close
	if _ter_shot < 3 and t > 10.0:
		for a in m().aliens():
			if not a.dead and a.race in ["lihnoun", "zombie", "ohar"] and a.global_position.distance_to(p.global_position) < 9.0:
				_aim_at(p, a.global_position + Vector3(0, 1.0, 0))
				_ter_shot += 1
				_snap("52_terror_%d" % _ter_shot)
				break
	if t > float(Game.cmd_arg("secs", "120")):
		var z := 0
		var lh := 0
		for a in m().aliens():
			if a.race == "zombie": z += 1
			if a.race == "lihnoun": lh += 1
		out("RESULT terror: aliens %d (zombies %d, lihnoun %d), civ dead %d" % [m().aliens().size(), z, lh, m().civilians().filter(func(cv): return cv.dead).size()])
		get_tree().quit()
