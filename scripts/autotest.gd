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
			("hp %.0f pos %s kills %d ammo %s busy %s rh %s lock %s inv %s spr %s" % [p.hp, p.global_position.snapped(Vector3.ONE * 0.1), p.kills, p.weapon().get("loaded", -1), p.busy_text if p.busy > 0 else "", p.item_in("rh").get("id", "-"), p._click_lock, m().hud.inventory_open, p.sprinting]) if p else "-"])
	if Game.cmd_arg("healtest", "") == "1" and multiplayer.is_server() and p:
		_heal_test(p)
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
		"evac":
			if p and m().go and step == 0:
				step = 1
				p.global_position = m().map["evac"] + Vector3(0, 0.3, 0)
				p.wants_evac = true
				out("at the Kondor, holding E")
			if step == 1 and m().finished:
				out("RESULT evac finished ok")
				get_tree().quit()
		"shot": _shot(p)
		"ai": _ai(p)
		"arsenal": _arsenal(p)
		"town": _town(p)
		"zoo": _zoo(p)
		"tactics": _tactics(p)
		"basewalk": _basewalk(p)
		"basepass": _passcheck(p)
		"doorshot": _doorshot(p)
		"passcheck": _passcheck(p)
		"camoshot": _camoshot(p)
		"fireshot": _fireshot(p)
		"abase": _abase(p)
		"cloakshot": _cloakshot(p)
		"voice": _voice_test(p)
		"club": _club(p)
		"uimission": _ui_mission(p)
		"stance": _stance(p)
		"wshot": _wshot(p)
		"pose": _pose(p)
		"invtest": _invtest(p)
		"rlanim": _rlanim(p)
		"ufoshot": _ufoshot(p)
		"actshot": _actshot(p)
		"stuntest": _stuntest(p)
		"mapshot": _mapshot(p)
		"objtest": _objtest(p)
		"breaktest": _breaktest(p)
		"armstest": _armstest(p)
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
			if mode == "client" and p and m().go and step < 10 and t > 12.0:
				step = 10
				Input.action_press("radio_talk")
				var smp := PackedFloat32Array()
				for i in 24000:
					smp.append(sin(i * 0.12) * 0.05 * (1.0 + sin(i * 0.001)))
				m().voice.test_speak(smp)
				out("client speaks on the radio (radio_tx %s)" % p.radio_tx())
			if mode == "client" and step != 10:
				_solo(p)
			if t > 25.0:
				out("RESULT players=%d aliens=%d" % [m().players().size(), m().aliens().size()])
				get_tree().quit()
	if t > 120.0 and mode != "campaign" and mode != "tactics":
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
		p._click_lock = false
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
		if p._click_lock:
			Input.action_release("fire")    # let go once, like a hand after closing a menu
			Input.action_release("aim")
			return
		Input.action_press("fire")
		Input.action_press("aim")
		if p.weapon().is_empty() or int(p.weapon().get("loaded", 0)) == 0:
			Input.action_release("fire")
			# tap R (a held key only counts once)
			if Engine.get_physics_frames() % 4 < 2:
				Input.action_press("reload")
			else:
				Input.action_release("reload")
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
		p.wants_evac = true      # Enter in the ship
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
const ZOO := ["grey", "grey_velitel", "diskoll", "levit", "levit_velitel", "ohar", "jestetan", "jestetan_velitel", "lihnoun", "bijec", "bijec_velitel", "nador", "ohnivec", "myslodej", "kolos"]
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
	m().hud._brief_t = -1.0       # stop the typing: the whole text at once
	m().hud._brief_lbl.visible_characters = -1
	await get_tree().create_timer(0.3).timeout
	await _uic("m_briefing_full")
	out("BRIEF len %d vis %d text %s" % [m().hud._brief_len, m().hud._brief_lbl.visible_characters, m().hud._brief_lbl.text.replace("\n", " | ")])
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

## One weapon in the hands: 1 / 2 / belt / Q / radio, checked step by step.
func _invtest(p: Node) -> void:
	if p == null or step > 0:
		return
	step = 1
	_skip_brief()
	await get_tree().create_timer(3.0).timeout
	m().hud.inventory_open = false
	m().set_process(false)
	for a in m().aliens():
		a.queue_free()
	var show := func(tag: String) -> void:
		var d := {}
		for sl in ["rh", "lh", "back", "side", "b0", "b1", "b2", "b3"]:
			d[sl] = p.item_in(sl).get("id", "-")
		out("%s  rh=%s back=%s side=%s belt=%s,%s,%s,%s home=%s" % [tag, d.rh, d.back, d.side, d.b0, d.b1, d.b2, d.b3, p.item_in("rh").get("home", "")])
	var wait := func() -> void:
		await get_tree().process_frame
		while p.busy > 0:
			await get_tree().process_frame
		await get_tree().process_frame
	show.call("start")
	p._weapon_key("side"); await wait.call(); show.call("key2")
	p._weapon_key("back"); await wait.call(); show.call("key1")
	var bi := -1
	for i in 4:
		var it: Dictionary = p.item_in("b%d" % i)
		if not it.is_empty() and Game.ITEMS[it["id"]]["type"] != "ammo":
			bi = i
			break
	if bi >= 0:
		p._belt_key(bi); await wait.call(); show.call("belt%d" % (bi + 3))
	p._q_swap(false); await wait.call(); show.call("Q")
	p._q_swap(false); await wait.call(); show.call("Q again")
	p._weapon_key("back"); await wait.call(); show.call("key1")
	p._weapon_key("back"); await wait.call(); show.call("key1 again (holster)")
	p._q_swap(false); await wait.call(); show.call("Q")
	# digging in the pack and bandaging, first person
	var ps := ""
	for sl in ["p0", "p1", "p2", "p3", "p4", "p5"]:
		if not p.item_in(sl).is_empty():
			ps = sl
			break
	if ps != "":
		p.draw_slot(ps)
		for i in 6:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("user://fp_dig.png")
		await wait.call()
	p.hp = p.max_hp - 5.0
	p.bleeding = 1.0
	p._heal_self()
	for i in 8:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("user://fp_bandage.png")
	out("act during bandage: %d busy=%s" % [p.act, p.busy_text])
	await wait.call()
	# radio with the rifle: the gun goes down first, then the radio comes up
	Input.action_press("radio_talk")
	var t0 := Time.get_ticks_msec()
	while not p.radio_up and Time.get_ticks_msec() - t0 < 3000:
		await get_tree().process_frame
	out("radio up after %d ms, lowered %.2f, left=%s, tx=%s" % [Time.get_ticks_msec() - t0, p._radio_lower, p.held_l, p.radio_tx()])
	Input.action_release("radio_talk")
	for i in 30:
		await get_tree().process_frame
	out("radio down: up=%s lowered %.2f left=%s" % [p.radio_up, p._radio_lower, p.held_l])
	# the loadout rules
	out("refuse lh rifle: " + Game.slot_refuse("lh", "rifle"))
	out("refuse side rifle: " + Game.slot_refuse("side", "rifle"))
	out("RESULT invtest done")
	get_tree().quit()

## Third-person look at our own mercenary in every stance (gun in the hands, prone on the belly).
func _pose(p: Node) -> void:
	if p == null or step > 0:
		return
	step = 1
	_skip_brief()
	await get_tree().create_timer(3.5).timeout
	m().hud.inventory_open = false
	m().hud.visible = false
	m().set_process(false)          # no judging: a lone downed mercenary would end the mission
	p.global_position = m().map["evac"] + Vector3(0, 40.3, 0)
	var fl := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(10, 0.2, 10)
	fl.mesh = fm
	fl.material_override = Game.mat("grass", 0.5)
	m().add_child(fl)
	fl.global_position = p.global_position + Vector3(0, -0.4, 0)
	var fsb := StaticBody3D.new()
	var fcs := CollisionShape3D.new()
	var fbs := BoxShape3D.new()
	fbs.size = fm.size
	fcs.shape = fbs
	fsb.add_child(fcs)
	fl.add_child(fsb)
	p.body.visible = true
	var cam := Camera3D.new()
	m().add_child(cam)
	cam.global_position = p.global_position + Vector3(2.2, 1.0, -1.6)
	cam.look_at(p.global_position + Vector3(0, 0.75, 0))
	cam.make_current()
	var l := OmniLight3D.new()
	l.light_energy = 4.0
	l.omni_range = 8.0
	m().add_child(l)
	l.global_position = p.global_position + Vector3(2, 2.5, -1)
	p.set_physics_process(false)
	for a in m().aliens():
		a.queue_free()
	p.gun.visible = false
	p.gun_l.visible = false
	var shots := [["stand", false, false, false, false], ["crouch", true, false, false, false], ["prone", false, true, false, false]]
	var only := Game.cmd_arg("only", "")
	if only != "":
		shots = []
	for e in shots:
		p.crouching = e[1]; p.prone = e[2]; p.downed = e[3]; p.dead = e[4]
		for i in 40:
			p._animate_body(1.0 / 30.0)
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("user://pose_%s.png" % e[0])
	p.prone = false
	for id in (Game.cmd_arg("items", "knife,shotgun").split(",") if only == "" else []):
		p.inv["rh"] = {"id": id, "loaded": 5}
		p.inv.erase("lh")
		p._update_held()
		p.act = 0
		for i in 20:
			p._animate_body(1.0 / 30.0)
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("user://pose_item_%s.png" % id)
		if Game.ITEMS[id]["type"] == "melee" or id == "shotgun":
			p.act = 2 if id != "shotgun" else 1
			p._act_t = 0.0
			for i in 6:
				p._animate_body(1.0 / 30.0)
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("user://pose_item_%s_act.png" % id)
			p.act = 0
	# talking on the radio with a long gun
	p.inv["rh"] = {"id": "rifle", "loaded": 5}
	p._update_held()
	p.held_l = "radio"
	p._show_items(p.held, "radio", p.held_back)
	for i in 20:
		p._animate_body(1.0 / 30.0)
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("user://pose_item_zradio.png")
	# emotes and idling (salute, at ease, hands on the hips), reloads seen from outside
	p.held_l = ""
	var fwd0: Vector3 = -p.merc_model.global_transform.basis.z.normalized()
	cam.global_position = p.global_position + fwd0 * 2.4 + fwd0.cross(Vector3.UP) * 0.9 + Vector3(0, 1.2, 0)
	cam.look_at(p.global_position + Vector3(0, 1.0, 0))
	for em in [["zsalute", 1], ["zatease", 2], ["zhips", 0]]:
		p.inv.erase("rh")
		p._update_held()
		p.emote = em[1]
		p._idle_t = 0.0
		if Game.cmd_arg("quick", "") != "" and em[0] != "zsalute":
			pass
		for i in (160 if em[1] == 0 else 30):
			p._animate_body(1.0 / 30.0)
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("user://pose_%s.png" % em[0])
	p.emote = 0
	for rl in ["pistol", "shotgun", "rifle"]:
		p.inv["rh"] = {"id": rl, "loaded": 1}
		p._update_held()
		p.act = 1
		p._act_t = 0.0
		for i in 12:
			p._animate_body(1.0 / 30.0)
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("user://pose_zreload_%s.png" % rl)
	p.act = 0
	p.inv.erase("rh")
	p._update_held()
	cam.global_position = p.global_position + Vector3(2.2, 1.0, -1.6)
	cam.look_at(p.global_position + Vector3(0, 0.75, 0))
	# wounds through the armour + blood of a few races on the floor
	p.held_l = ""
	p._show_items("", "", p.held_back)
	p.hp = p.max_hp * 0.1
	p._wounds()
	var cols := [Color(0.35, 1.0, 0.45), Color(0.5, 0.45, 1.0), Color(1.0, 0.55, 0.12), Color(0.2, 0.95, 1.0), Color(0.35, 0.02, 0.02)]
	for k in cols.size():
		Game.blood_splat(m(), p.global_position + Vector3(0.9 - k * 0.45, 0.5, -0.9), cols[k], 0.4, k < 4)
	for i in 10:
		p._animate_body(1.0 / 30.0)
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("user://pose_zwound.png")
	var fwd: Vector3 = -p.merc_model.global_transform.basis.z.normalized()
	cam.global_position = p.global_position + fwd * 0.8 + Vector3(0, 1.62, 0) + fwd.cross(Vector3.UP) * 0.25
	cam.look_at(p.global_position + Vector3(0, 1.4, 0))
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("user://pose_zwound_face.png")
	cam.global_position = p.global_position + Vector3(2.2, 1.0, -1.6)
	cam.look_at(p.global_position + Vector3(0, 0.75, 0))
	for e2 in [["zdowned", true, false], ["zdead", false, true]]:
		p.downed = e2[1]; p.dead = e2[2]
		for i in 40:
			p._last_body_pos -= Vector3(0, 0, 0.02)     # make the crawl move
			p._animate_body(1.0 / 30.0)
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("user://pose_%s.png" % e2[0])
	get_tree().quit()

func _rlanim(p: Node) -> void:
	if p == null or step > 0 or not m().go or m().hud._brief_t >= 0:
		return
	step = 1
	m().hud.inventory_open = false
	p.set_physics_process(false)
	p.global_position = m().map["evac"] + Vector3(0, 40, 8)     # up in the sky: nothing in the way
	p.rotation.y = PI
	p.pitch = 0.0
	p.flash.visible = false
	for id in Game.cmd_arg("rlguns", "pistol,magnum").split(","):
		p.inv["rh"] = {"id": id.trim_suffix("2"), "loaded": 0}
		p.inv.erase("lh")
		if id.ends_with("2"):
			p.inv["lh"] = {"id": "pistol", "loaded": 12}
		if id == "aim":
			p.inv["rh"] = {"id": "pistol", "loaded": 12}
			p._update_held()
			for a in 2:
				p.aiming = a == 1
				for k in 25:
					p._viewmodel_motion(0.05, 0.0)
				await get_tree().process_frame
				await get_tree().process_frame
				get_viewport().get_texture().get_image().save_png("user://rl_aim_%d.png" % a)
			continue
		id = id.trim_suffix("2") if not id.ends_with("2") else id
		p._update_held()
		await get_tree().process_frame
		var phs := [0.0, 0.18, 0.3, 0.45, 0.68, 0.76, 1.0] if id.begins_with("pistol") else [0.0, 0.2, 0.5, 0.7, -1.0]
		if Game.cmd_arg("dense", "") == "1":
			phs = []
			var n := 34 if id == "pistol" else 14
			for j in n:
				phs.append(float(j) / (n - 1))
			if id == "magnum":
				phs += [0.0, 0.3, 0.6, 0.9, -1.0, -1.0, -1.0]
		for i in phs.size():
			var ph: float = phs[i]
			if ph < 0:
				p.busy = 0.0
				p.busy_text = ""
				for k in 3:
					p._viewmodel_motion(0.05, 0.0)
			else:
				p.busy_total = 1.7 if id.begins_with("pistol") else 0.7
				p.busy = p.busy_total * (1.0 - ph) + 0.0001
				p.busy_text = "Přebíjím" if id.begins_with("pistol") else "Přebíjím po náboji"
				for k in (25 if Game.cmd_arg("dense", "") != "1" else 4):
					p._viewmodel_motion(0.05, 0.0)
			await get_tree().process_frame
			await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("user://rl_%s_%d.png" % [id, i])
	get_tree().quit()

func _ufoshot(p: Node) -> void:
	if p == null or step > 0 or not m().go or m().hud._brief_t >= 0:
		return
	step = 1
	m().hud.inventory_open = false
	p.set_physics_process(false)
	var races := []
	for a in m().aliens():
		races.append(a.race)
		if Game.cmd_arg("keep", "") == "" or not a.race in ["mozek", "pylon"]:
			a.queue_free()
	out("RACES %s brain=%s" % [races, m().map.get("brain", "-")])
	var u: Vector3 = m().map["ufo"]
	var door: Vector3 = m().map["ufo_door"]
	var out := (door - u)
	out.y = 0
	out = out.normalized()
	var shots := [["out", u + out * (40.0 if m().map.has("brain") else 26.0) + Vector3(6, 4.5, 0), u + Vector3(0, 1.5, 0)],
		["door", door + out * 2.5 + Vector3(0, 0.3, 0), u],
		["in", door - out * 2.6 + Vector3(0, 0.3, 0), u - out * 3.0]]
	if String(m().map.get("ufo_kind", "")) in ["battleship", "supply"]:
		shots = [shots[0], ["door", door + Vector3(0, 0.3, -6.0), u]]
		for k in [[0, 0], [-1, 0], [1, 0], [0, 1], [-1, 1], [1, 1]]:
			var sc: Vector3 = u + Vector3(k[0] * 15.0, 0, k[1] * 15.0)
			shots.append(["sec%d_%d" % [k[0] + 1, k[1]], sc + Vector3(3.5, 0.3, -4.5), sc + Vector3(-1.0, 1.0, 1.0)])
	if m().map.has("brain"):
		shots = [shots[0], ["door", u + out * 16.0 + Vector3(0, 0.3, 0), u],
			["in", u + out * 9.0 + Vector3(2, 0.3, 0), m().map["brain"] + Vector3(0, 1.2, 0)]]
	for e in shots:
		p.global_position = e[1]
		_aim_at(p, e[2])
		p.flash.visible = true
		m().env.ambient_light_energy = 0.6
		await get_tree().create_timer(1.5).timeout
		get_viewport().get_texture().get_image().save_png("user://ufo_%s_%s.png" % [m().map.get("ufo_kind", "?"), e[0]])
	get_tree().quit()

## Overview pictures of a whole map (daylight helps to see the tiles).
func _mapshot(p: Node) -> void:
	if p == null or step > 0 or not m().go or m().hud._brief_t >= 0:
		return
	step = 1
	m().hud.visible = false
	var size: float = m().map["size"]
	var cam := Camera3D.new()
	cam.far = 400
	m().add_child(cam)
	var c := Vector3(size / 2, 0, size / 2)
	m().env.fog_density = 0.0015
	m().env.volumetric_fog_enabled = false
	for i in 4:
		var pos: Vector3 = [c + Vector3(-size * 0.55, size * 0.55, size * 0.75), c + Vector3(size * 0.6, size * 0.45, -size * 0.5), c + Vector3(0, size * 0.25, size * 0.2), c + Vector3(0, size * 1.05, 0.01)][i]
		cam.global_position = pos
		cam.look_at(c if i != 2 else Vector3(m().map["ufo"]), Vector3.UP)
		cam.make_current()
		await get_tree().create_timer(1.0).timeout
		get_viewport().get_texture().get_image().save_png("user://map_%s_%d.png" % [Game.cmd_arg("biome", "farm"), i])
	var nmap0: RID = m().get_world_3d().navigation_map
	for lk in m().find_children("*", "NavigationLink3D", true, false):
		var sp: Vector3 = lk.global_transform * lk.start_position
		var ep: Vector3 = lk.global_transform * lk.end_position
		var cs := NavigationServer3D.map_get_closest_point(nmap0, sp)
		var ce := NavigationServer3D.map_get_closest_point(nmap0, ep)
		out("LINK start %s near %s (%.2f)  end %s near %s (%.2f) map_ok=%s links_on_map=%d radius=%.2f" % [sp, cs, cs.distance_to(sp), ep, ce, ce.distance_to(ep), lk.get_navigation_map() == nmap0, NavigationServer3D.map_get_links(nmap0).size(), NavigationServer3D.map_get_link_connection_radius(nmap0)])
		var lp := NavigationServer3D.map_get_path(nmap0, cs, ce, false)
		out("LINK path %s" % [lp])
	# close-ups of the new places, from eye height at a corner of their block
	var seen := {}
	var k := 0
	for lm in m().map.get("landmarks", []):
		if seen.has(lm[0]) or k >= 6:
			continue
		seen[lm[0]] = true
		var o: Vector3 = lm[1]
		var mid := o + Vector3(6, 0, 6)
		var toc := (c - mid)
		toc.y = 0
		toc = toc.normalized() if toc.length() > 0.1 else Vector3(1, 0, 0)
		cam.global_position = mid + toc * 9.5 + Vector3(0, 2.4, 0)
		cam.look_at(mid + Vector3(0, 1.2, 0), Vector3.UP)
		await get_tree().create_timer(0.8).timeout
		get_viewport().get_texture().get_image().save_png("user://lm_%s_%s.png" % [Game.cmd_arg("biome", "farm"), lm[0]])
		k += 1
		if lm[0] in ["house2", "cabin", "warehouse"]:
			# can they walk upstairs? (navigation path from the yard to the upper floor)
			var up: Vector3 = {"house2": o + Vector3(3.8, 3.1, 7.2), "cabin": o + Vector3(5.2, 2.7, 8.0), "warehouse": o + Vector3(3.5, 3.06, 9.3)}[lm[0]]
			var nmap: RID = m().get_world_3d().navigation_map
			var path := NavigationServer3D.map_get_path(nmap, NavigationServer3D.map_get_closest_point(nmap, o + Vector3(6, 0, 0.5)), NavigationServer3D.map_get_closest_point(nmap, up), true)
			out("NAVUP %s: path %d points, end y %.2f (want %.2f)  start %s target %s closest %s path %s" % [lm[0], path.size(), path[path.size() - 1].y if path.size() > 0 else -1.0, up.y, o + Vector3(6, 0, 0.5), up, NavigationServer3D.map_get_closest_point(nmap, up), path])
			var nm: NavigationMesh = m().get_node("Nav").navigation_mesh if m().has_node("Nav") else null
			if nm == null:
				for ch in m().find_children("*", "NavigationRegion3D", true, false):
					nm = ch.navigation_mesh
			var hi := 0
			var near_up := 99.0
			for v in nm.get_vertices():
				if v.y > 1.5:
					hi += 1
					near_up = minf(near_up, Vector2(v.x - up.x, v.z - up.z).length())
			out("NAVUP verts above 1.5 m: %d, nearest to target %.1f m, closest point %s" % [hi, near_up, NavigationServer3D.map_get_closest_point(nmap, up)])
			if lm[0] == "house2":
				var cc := o + Vector3(1.8, 0, 2.2)
				var pts := {"door_out": cc + Vector3(3.6, 0, -1.0), "inside": cc + Vector3(3.6, 0, 1.5), "right_room": cc + Vector3(5.5, 0, 4.0), "ramp_foot": cc + Vector3(7.3, 0, 0.8), "ramp_mid": cc + Vector3(7.3, 1.55, 3.6), "landing": cc + Vector3(7.3, 3.1, 7.4), "upstairs": cc + Vector3(3.0, 3.1, 5.0)}
				var cnt := 0
				for v in nm.get_vertices():
					var lv: Vector3 = v - cc
					if lv.x > 6.3 and lv.x < 8.4 and lv.z > 0 and lv.z < 8 and v.y > 0.6 and v.y < 3.0:
						cnt += 1
						if cnt < 12: out("RAMPV %s" % lv)
				out("RAMPV count %d" % cnt)
				var names := pts.keys()
				for a in names.size() - 1:
					var pa: Vector3 = NavigationServer3D.map_get_closest_point(nmap, pts[names[a]])
					var pb: Vector3 = NavigationServer3D.map_get_closest_point(nmap, pts[names[a + 1]])
					var pp := NavigationServer3D.map_get_path(nmap, pa, pb, true)
					out("SEG %s %s -> %s %s : end %s ok=%s" % [names[a], pa, names[a + 1], pb, pp[pp.size() - 1] if pp.size() else "-", pp.size() > 0 and pp[pp.size() - 1].distance_to(pb) < 0.5])
			# and a look from up there
			cam.global_position = up + Vector3(0, 1.6, 0)
			cam.look_at(up + Vector3(-3, 1.2, -3), Vector3.UP)
			await get_tree().create_timer(0.8).timeout
			get_viewport().get_texture().get_image().save_png("user://lm_%s_%s_up.png" % [Game.cmd_arg("biome", "farm"), lm[0]])
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

var _ht := 0
func _heal_test(p: Node) -> void:
	var other: Node = null
	for o in m().players():
		if o != p:
			other = o
	if other == null:
		return
	p.hp = 999.0
	if _ht == 0 and t > 6.0:
		_ht = 1
		other.hurt.rpc_id(other.get_multiplayer_authority(), 999.0, other.global_position)
		out("HEAL: downing %s" % other.name)
	elif _ht == 1 and t > 7.5:
		_ht = 2
		p.global_position = other.global_position + Vector3(1.2, 0.0, 0.5)
		m().hud.inventory_open = false
		out("HEAL: target=%s downed=%s medkit=%s" % [p.heal_target(), other.downed, p.has_medkit()])
		p._medkit()
		out("HEAL: (take in hand) busy %s %.1f" % [p.busy_text, p.busy])
	elif _ht == 2 and t > 10.0:
		_ht = 3
		p._medkit()
		out("HEAL: busy %s %.1f lh=%s" % [p.busy_text, p.busy, p.item_in("lh").get("id", "-")])
	elif _ht == 3 and t > 15.0:
		_ht = 4
		out("HEAL RESULT: other downed=%s dead=%s hp=%.0f revives=%d busy=%s" % [other.downed, other.dead, other.hp, p.revives, p.busy_text])

## The new mission types, played through by a bot (rescue / sabotage / base).
func _objtest(p: Node) -> void:
	if p == null:
		return
	_skip_brief()
	if not m().started():
		return
	p.hp = 9999.0
	p.max_hp = 9999.0
	if m().finished:
		if step < 900:
			step = 900
			out("OBJ RESULT finished: %s" % str(m().hud.result_panel != null))
			await get_tree().create_timer(1.0).timeout
			get_tree().quit()
		return
	match m().mtype():
		"rescue":
			var v: Node = m().vip()
			if v == null:
				return
			if step == 0:
				step = 1
				out("OBJ vip %s at %s (evac %s)" % [m().vip_name, v.global_position, m().map["evac"]])
				# how much of the map can be reached from the Kondor?
				var nmap: RID = m().get_world_3d().navigation_map
				var ev: Vector3 = NavigationServer3D.map_get_closest_point(nmap, m().map["evac"] + Vector3(0, 0, 3))
				var bad := []
				for wp in m().map["waypoints"]:
					var pp := NavigationServer3D.map_get_path(nmap, ev, NavigationServer3D.map_get_closest_point(nmap, wp), true)
					if pp.is_empty() or pp[pp.size() - 1].distance_to(NavigationServer3D.map_get_closest_point(nmap, wp)) > 1.0:
						bad.append(wp)
				out("OBJ reach: %d of %d waypoints unreachable: %s" % [bad.size(), m().map["waypoints"].size(), bad])
				for lm in m().map.get("landmarks", []):
					out("OBJ landmark %s at %s" % lm)
				p.global_position = v.global_position + Vector3(1.0, 0.2, 0)
			elif step == 1 and t > 1.0:
				step = 2
				out("OBJ use civilian: %s" % p._use_civilian())
			elif step == 2:
				await get_tree().create_timer(1.0).timeout
				out("OBJ vip state %d (follow=%d)" % [v.st, v.C.FOLLOW])
				for a in m().aliens():
					a.set_physics_process(false)
				p.global_position = m().map["evac"] + Vector3(0, 0.3, 2.5)
				step = 3
			elif step == 3:
				if v.saved:
					out("OBJ vip saved")
					p.global_position = m().map["evac"] + Vector3(0, 0.3, 0)
					p.wants_evac = true
					step = 4
				elif log_t > 1.9:
					out("OBJ vip walking %s dist %.1f next %s path %s fin %s" % [v.global_position, v.global_position.distance_to(m().map["evac"]), v.agent.get_next_path_position(), v.agent.get_current_navigation_path(), v.agent.is_navigation_finished()])
					if t > 90.0:
						v.global_position = m().map["evac"] + Vector3(0, 0.3, 1.0)
		"sabotage":
			if step == 0:
				step = 1
				out("OBJ beacons %d" % m().beacons.size())
				for a in m().aliens():
					a.set_physics_process(false)
			if step >= 1 and step <= m().beacons.size():
				var b: Dictionary = m().beacons[step - 1]
				p.global_position = b["pos"] + Vector3(2.0, 0.3, 0)
				out("OBJ near beacon %d: %d" % [step - 1, m().beacon_near(p.global_position)])
				m().plant(step - 1)
				step += 1
				p.global_position = m().map["evac"] + Vector3(0, 0.3, 0)
			elif step == m().beacons.size() + 1 and m().beacons_left() == 0:
				out("OBJ all beacons gone")
				p.wants_evac = true
				step = 99
		"base":
			if log_t > 1.9:
				out("OBJ waves %d alive %d" % [m().waves_left, m().alive_aliens()])
			for a in m().aliens():
				if not a.dead:
					a.damage(5000.0, a.global_position, null)

## Destruction: a house wall before and after a blast, a fence shot to pieces.
func _breaktest(p: Node) -> void:
	if p == null or step > 0 or not m().started():
		return
	step = 1
	m().hud.visible = false
	m().env.fog_density = 0.002
	var arr: Array = m().map["breakables"]
	out("BREAK breakables: %d" % arr.size())
	var target: Node3D = null
	for n in arr:
		if n.get_meta("break_kind") == "brick" and n.global_position.y < 2.0 and n.global_position.distance_to(m().map["evac"]) > 15.0:
			target = n
			break
	if target == null:
		get_tree().quit()
		return
	var cam := Camera3D.new()
	m().add_child(cam)
	var tp := target.global_position
	cam.global_position = tp + Vector3(5, 1.2, 5)
	cam.look_at(tp, Vector3.UP)
	cam.make_current()
	await get_tree().create_timer(1.0).timeout
	_snap("70_before")
	m().explode(tp + Vector3(0.6, 0.5, 0.6), 4.5, 160.0, "", true)
	await get_tree().create_timer(0.3).timeout
	_snap("71_blast")
	await get_tree().create_timer(2.5).timeout
	_snap("72_after")
	var broken := 0
	for n in arr:
		if not is_instance_valid(n):
			broken += 1
	out("BREAK broken pieces: %d" % broken)
	get_tree().quit()

## Alien guns: one dies, the gun lies there, the mercenary takes it, fires, re-primes.
func _armstest(p: Node) -> void:
	if p == null or step > 0 or not m().started():
		return
	step = 1
	for a in m().aliens():
		a.set_physics_process(false)
	var target: Node = null
	for a in m().aliens():
		if Campaign.RACE_WEAPON.has(a.race):
			target = a
			break
	if target == null:
		out("ARMS no armed alien (crew %s)" % [m().aliens().map(func(x): return x.race)])
		get_tree().quit()
		return
	p.inv.erase("rh")
	p.inv.erase("back")
	p._update_held()
	target.damage(99999.0, target.global_position, p)
	await get_tree().create_timer(0.5).timeout
	out("ARMS pickups after the kill: %d" % m().pickups.size())
	p.global_position = target.global_position + Vector3(0.5, 0.3, 0)
	await get_tree().create_timer(0.3).timeout
	p._pick_up()
	var rh: Dictionary = p.item_in("rh")
	out("ARMS in hand: %s unknown=%s" % [rh, Game.alien_unknown(rh.get("id", ""))])
	if rh.is_empty():
		get_tree().quit()
		return
	rh["loaded"] = 0
	var t0 := t
	p._reload(rh, Game.ITEMS[rh["id"]])
	out("ARMS re-priming: %s (%.1f s)" % [p.busy_text, p.busy_total])
	await get_tree().create_timer(p.busy_total + 0.5).timeout
	out("ARMS after: loaded %d cells %d spread %.2f" % [int(rh["loaded"]), int(rh.get("cells", 0)), p.current_spread()])
	# lying bodies are low: shots go over them
	p.prone = true
	await get_tree().create_timer(0.2).timeout
	out("ARMS prone capsule height %.2f" % p._body_cap.height)
	get_tree().quit()

func _skip_brief() -> void:
	var h: Node = m().hud
	if h._brief_t >= 0 and h._brief_t < float(h._brief_len) / 40.0 + 1.0:
		h._brief_t = float(h._brief_len) / 40.0 + 1.0

func _zoo(p: Node) -> void:
	if p == null: return
	_skip_brief()
	m().hud.inventory_open = false
	p.hp = 999.0
	var al: Array = m().aliens()
	if step == 0 and t > 1.5 and not has_meta("zoo_spawned"):
		set_meta("zoo_spawned", true)
		for a in al:
			a.queue_free()
		for i in ZOO.size():
			m().spawn_alien(ZOO[i], m().map["ufo"] + Vector3(i * 2.0 - ZOO.size(), 0.3, 20))
		return
	al = al.filter(func(a): return is_instance_valid(a) and not a.is_queued_for_deletion())
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
	if step == 1 and t > 4.5 and Game.cmd_arg("die", "") != "":
		# death test: everyone falls at once; pictures during and after, from the side
		step = 100
		# a clean stage up in the sky: a floor, a light, nothing else in the way
		var base2 := Vector3(0, 80, 0)
		var fl := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(40, 0.2, 20)
		fl.mesh = fm
		fl.material_override = Game.mat("grass", 0.5)
		m().add_child(fl)
		fl.global_position = base2 + Vector3(0, -0.1, 0)
		var sl := OmniLight3D.new()
		sl.light_energy = 4.0
		sl.omni_range = 30.0
		m().add_child(sl)
		sl.global_position = base2 + Vector3(0, 6, 6)
		p.set_physics_process(false)
		for i in al.size():
			al[i].global_position = base2 + Vector3((i - al.size() / 2.0 + 0.5) * 2.4, 0, 0)
		p.global_position = base2 + Vector3(0, 2.5, 9.0)
		_aim_at(p, base2 + Vector3(0, 0.3, 0))
		await get_tree().create_timer(0.6).timeout
		_snap("60_alive")
		for a in al:
			a.dead = true
			a.collision_layer = 0
			a.set_physics_process(true)
		await get_tree().create_timer(0.35).timeout
		_snap("61_falling")
		await get_tree().create_timer(1.5).timeout
		_snap("62_dead")
		p.global_position = base2 + Vector3(-al.size() * 1.1 - 3.0, 1.0, 1.5)
		_aim_at(p, base2 + Vector3(0, 0.2, 0))
		await get_tree().create_timer(0.6).timeout
		_snap("63_dead_front")
		get_tree().quit()
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

## Aliens at their jobs: let them walk to them, then photograph each one from close by.
func _actshot(p: Node) -> void:
	if p == null or step > 0 or not m().go or m().hud._brief_t >= 0:
		return
	step = 1
	m().hud.inventory_open = false
	p.set_meta("ghost", true)     # nobody to notice: they stay at their jobs
	p.hp = 1000.0
	p.set_physics_process(false)
	p.global_position = Vector3(2, 0.3, 2)
	Engine.time_scale = 6.0
	await get_tree().create_timer(70.0).timeout
	Engine.time_scale = 1.0
	var n := 0
	for a in m().aliens():
		var act: String = a.ACTS[a.activity] if a.activity < a.ACTS.size() else "?"
		out("ALIEN %s act=%s speed=%.2f w=%.2f at %s" % [a.race, act, a._speed, a._act_w, a.global_position])
	for a in m().aliens():
		if n >= 6 or a.dead:
			continue
		if a.activity == 0 and a.race != "zombie":
			continue
		var fwd: Vector3 = -a.global_transform.basis.z
		var side: Vector3 = a.global_transform.basis.x
		p.global_position = a.global_position + fwd * 2.6 + side * 1.6 - Vector3(0, 0.6, 0)
		_aim_at(p, a.global_position + Vector3(0, 0.7, 0))
		for f in 8:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("user://act_%d_%s.png" % [n, a.ACTS[a.activity] if a.activity > 0 else "sway"])
		n += 1
	out("RESULT actshot %d" % n)
	get_tree().quit()

## The stun baton: three blows must knock a grey out.
func _stuntest(p: Node) -> void:
	if p == null or step > 0 or not m().go or m().hud._brief_t >= 0:
		return
	step = 1
	m().hud.inventory_open = false
	var a: Node = null
	for x in m().aliens():
		if x.race.begins_with("grey"):
			a = x
			break
	if a == null:
		out("RESULT no grey"); get_tree().quit(); return
	p.inv["rh"] = {"id": "stun_baton"}
	p._update_held()
	for i in 6:
		a.set_physics_process(false)
		p.global_position = a.global_position - a.global_transform.basis.z * 1.1
		_aim_at(p, a.global_position + Vector3(0, 0.9, 0))
		await get_tree().process_frame
		p._melee("rh", Game.ITEMS["stun_baton"])
		await get_tree().create_timer(0.9).timeout
		out("blow %d: stun %.0f hp %.0f captured %s dead %s" % [i, a.stun_dmg, a.hp, a.captured, a.dead])
		if a.dead:
			break
	out("RESULT stuntest captured=%s" % a.captured)
	get_tree().quit()

## AI tactics: the merc snipes from the Kondor's ramp; the aliens must answer (cover, return
## fire, flanking, their race's tricks). Logs [TAC] events from the aliens.
var _tac_t := 0.0
var _tac_hp := 0.0
var _snipes := 0
func _tactics(p: Node) -> void:
	if p == null or not m().go or m().hud._brief_t >= 0:
		return
	if step == 0:
		step = 1
		m().hud.inventory_open = false
		p.hp = 5000.0
		_tac_hp = p.hp
		p.set_physics_process(false)
		p.global_position = m().map["evac"] + Vector3(0, 0.3, 0)
		if Game.cmd_arg("spot", "") == "open":
			p.global_position = NavigationServer3D.map_get_closest_point(p.get_world_3d().navigation_map, m().map["ufo"] + (m().map["evac"] - m().map["ufo"]) * 0.5) + Vector3(0, 0.3, 0)
		if Game.cmd_arg("spot", "") == "ufo":
			p.global_position = NavigationServer3D.map_get_closest_point(p.get_world_3d().navigation_map, m().map["ufo"] + (m().map["evac"] - m().map["ufo"]).normalized() * 22.0) + Vector3(0, 0.3, 0)
		m().t += 70.0       # past the quiet start
		Engine.time_scale = float(Game.cmd_arg("ts", "3"))
		out("TAC start at %s" % p.global_position)
	_tac_t -= get_process_delta_time()
	if _tac_t <= 0.0 and step == 1:
		_tac_t = 4.0
		var eye: Vector3 = p.global_position + Vector3(0, 1.5, 0)
		var best: Node = null
		for a in m().aliens():
			if a.dead or a.husk:
				continue
			var d: float = a.global_position.distance_to(p.global_position)
			if d > 80.0:
				continue
			var q := PhysicsRayQueryParameters3D.create(eye, a.global_position + Vector3(0, 1.0, 0), 1)
			if p.get_world_3d().direct_space_state.intersect_ray(q).is_empty() and (best == null or d < best.global_position.distance_to(p.global_position)):
				best = a
		if best and _snipes < int(Game.cmd_arg("snipes", "999")):
			_snipes += 1
			_aim_at(p, best.global_position + Vector3(0, 1.0, 0))
			m().noise(p.global_position, 60.0)
			best.damage(12.0, p.global_position + Vector3(0, 1.5, 0), p)
			out("TAC snipe %s %s d%.0f hp %.0f" % [best.name, best.race, best.global_position.distance_to(p.global_position), best.hp])
		var st := []
		for a in m().aliens():
			st.append("%s:%s/%s d%.0f sh%d%s%s" % [a.name, a.S.keys()[a.state], a.phase, a.global_position.distance_to(p.global_position), a.shots_fired, " x" if a.dead else "", " K" if a.has_method("_knows") and a._knows(p) else ""])
		out("   " + ", ".join(st) + " | php %.0f started %s" % [p.hp, m().started()])
	if t > float(Game.cmd_arg("secs", "150")):
		var fired := 0
		var lines := []
		for a in m().aliens():
			fired += a.shots_fired
			lines.append("%s %s %s/%s d%.0f shots %d%s%s" % [a.name, a.race, a.S.keys()[a.state], a.phase, a.global_position.distance_to(p.global_position), a.shots_fired, " DEAD" if a.dead else "", " AIR" if a.airborne else ""])
		for l in lines:
			out("  " + l)
		out("RESULT tactics shots %d player lost %.0f hp downed %s" % [fired, _tac_hp - p.hp, p.downed])
		Engine.time_scale = 1.0
		get_tree().quit()

## Pictures: a lizard officer cloaked / uncloaked, a Levit officer up on its jets.
func _cloakshot(p: Node) -> void:
	if p == null or step > 0 or not m().go or m().hud._brief_t >= 0:
		return
	step = 1
	m().hud.inventory_open = false
	p.set_meta("ghost", true)
	p.hp = 1000.0
	p.set_physics_process(false)
	var shots := 0
	for a in m().aliens():
		a.set_physics_process(false)
		var fwd: Vector3 = -a.global_transform.basis.z
		p.global_position = a.global_position + fwd * 3.2 - Vector3(0, 0.0, 0)
		_aim_at(p, a.global_position + Vector3(0, float(a.R["h"]) * 0.7, 0))
		for k in [0.0, 1.0]:
			a.cloak = k > 0.5
			a._cloak_k = 1.0 - k
			for f in 90:
				a._cloak_tick(0.05)
				a._jet_tick(0.05)
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("user://cloak_%s_%d.png" % [a.race, int(k)])
			shots += 1
	out("RESULT cloakshot %d" % shots)
	get_tree().quit()

## Our base: a picture of every room (ghost walk), then the terminals answer.
func _basewalk(p: Node) -> void:
	if p == null or step > 0 or not m().go or m().hud._brief_t >= 0:
		return
	step = 1
	m().hud.inventory_open = false
	p.set_physics_process(false)
	p.set_meta("ghost", true)
	p.hp = 5000.0
	if Game.cmd_arg("attack", "") == "1":
		p.light_on = true
		await get_tree().create_timer(1.0).timeout
	if m().home():
		m()._radar_alarm("RADAR: test")
	var cells: Array = Net.mission_params["base"]
	var gw := int(Net.mission_params["grid_w"])
	var n := 0
	for i in cells.size():
		if String(cells[i]["type"]) == "":
			continue
		var o := Vector3((i % gw) * 12.0, 0, (i / gw) * 12.0)
		p.global_position = o + Vector3(2.0, 0.3, 10.0)
		_aim_at(p, o + Vector3(8.0, 1.2, 3.0))
		for f in 10:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("user://base%s_%d_%s.png" % ["A" if not m().home() else "", n, cells[i]["type"]])
		n += 1
	# the room still being built (cell 14), seen from the infirmary next door
	p.global_position = Vector3(24.0 - 3.0, 0.3, 24.0 + 6.2)
	_aim_at(p, Vector3(24.0 + 3.0, 1.2, 24.0 + 6.0))
	for f in 40:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("user://base%s_build.png" % ["A" if not m().home() else ""])
	out("terminals %d: %s" % [m().map["terminals"].size(), m().map["terminals"].map(func(t): return t["kind"])])
	var tm: Dictionary = m().map["terminals"][0]
	p.global_position = tm["pos"] + Vector3(0, 0.3, 0)
	out("near %s" % m().terminal_near(p.global_position).get("kind", "-"))
	out("RESULT basewalk %d rooms" % n)
	get_tree().quit()

## Camouflage: a mercenary in each pattern in front of the camera (and the hands in view).
func _camoshot(p: Node) -> void:
	_skip_brief()
	if p == null or step > 0 or not m().go or m().hud._brief_t >= 0:
		return
	step = 1
	m().hud.inventory_open = false
	p.set_physics_process(false)
	p.hp = 5000.0
	var cam: Camera3D = p.cam
	for sch in ["woodland", "desert", "snow", "urban", "mars", "night"]:
		Game.camo = sch
		var row := Node3D.new()
		m().add_child(row)
		var fwd := -cam.global_transform.basis.z
		fwd.y = 0
		fwd = fwd.normalized()
		var side := fwd.cross(Vector3.UP)
		for k in 2:
			var mm: Node3D = Game.model("merc")
			Game.apply_look(mm, Game.merc.get("look", {}))
			row.add_child(mm)
			mm.global_position = p.global_position + fwd * 2.6 + side * (k - 0.5) * 1.1 - Vector3(0, 0.0, 0)
			mm.look_at(p.global_position, Vector3.UP)
			mm.rotate_y(PI if k == 0 else PI * 0.6)
		for f in 12: await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("user://camo_%s.png" % sch)
		row.queue_free()
	out("RESULT camoshot")
	get_tree().quit()

## Can a man walk through? Every door opened, every base doorway: a player-sized capsule swept
## from 0.9 m before to 0.9 m behind; anything it bumps into is reported (with the culprit's name).
func _passcheck(p: Node) -> void:
	_skip_brief()
	if p == null or step > 0 or not m().go:
		return
	step = 1
	p.set_physics_process(false)
	p.global_position = Vector3(0, -50, 0)
	var ways: Array = []
	for i in m().doors.size():
		var d: Dictionary = m().doors[i]
		m()._swing(d, 1.0, true)
		ways.append({"c": d["c"], "n": Vector3(0, 0, 1).rotated(Vector3.UP, float(d["base"])), "what": "dveře %d" % i, "w": float(m().map["doors"][i]["w"])})
	for ps in m().map.get("passages", []):
		ways.append({"c": ps["c"], "n": ps["n"], "what": "průchod", "w": 2.4})
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = 0.33
	cap.height = 1.7
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.collision_mask = 1 | 64 | 128
	var bad := 0
	for wy in ways:
		var c: Vector3 = wy["c"]
		var nrm: Vector3 = wy["n"]
		var side := nrm.cross(Vector3.UP)
		var ok := false
		var hits := {}
		# a man can sidestep: try the middle and a little to each side
		for off in [0.0, -0.2, 0.2, -0.4, 0.4]:
			if absf(off) > float(wy["w"]) / 2.0 - 0.3:
				continue
			var clear := true
			for k in 10:
				var t := -0.9 + k * 0.2
				q.transform = Transform3D(Basis(), c + nrm * t + side * off + Vector3(0, 0.25 + 0.85 + 0.05, 0))
				var r := space.intersect_shape(q, 4)
				if not r.is_empty():
					clear = false
					for h in r:
						var o: Object = h["collider"]
						var nm := String(o.name)
						if o is Node and (o as Node).get_parent(): nm += "<" + String((o as Node).get_parent().name)
						for ch in (o as Node).get_children(): nm += "," + String(ch.name)
						if o is Node and (o as Node).get_child_count() > 0 and (o as Node).get_child(-1) is MeshInstance3D:
							var mi: MeshInstance3D = (o as Node).get_child(-1)
							if mi.mesh is BoxMesh: nm += " box%s" % str((mi.mesh as BoxMesh).size)
						hits[nm + " @" + str(snapped((o as Node3D).global_position, Vector3(0.1, 0.1, 0.1)))] = true
					break
			if clear:
				ok = true
				break
		if not ok:
			bad += 1
			out("BLOCKED %s at %s: %s" % [wy["what"], str(snapped(c, Vector3(0.1, 0.1, 0.1))), hits.keys()])
	out("RESULT passcheck %d ways, %d blocked" % [ways.size(), bad])
	get_tree().quit()

## Doors and glass: a closed door, the same door opened by E, a window before and after a shot.
func _doorshot(p: Node) -> void:
	_skip_brief()
	if p == null or step > 0 or not m().go or m().hud._brief_t >= 0:
		return
	step = 1
	m().hud.inventory_open = false
	p.set_meta("ghost", true)
	p.hp = 5000.0
	p.set_physics_process(false)
	p.light_on = true
	m().env.ambient_light_energy = 1.0
	out("doors %d glass %d" % [m().doors.size(), m().map["breakables"].filter(func(b): return is_instance_valid(b) and String(b.get_meta("break_kind", "")) == "glass").size()])
	if m().doors.is_empty():
		out("RESULT doorshot no doors"); get_tree().quit(); return
	var d: Dictionary = m().doors[0]
	for dd in m().doors:
		if not dd["open"]:
			d = dd
			break
	var c: Vector3 = d["c"]
	var nrm := Vector3(0, 0, 1).rotated(Vector3.UP, float(d["base"]))
	p.global_position = c + nrm * 2.5 + Vector3(0, 0.3, 0)
	_aim_at(p, c + Vector3(0, 1.1, 0))
	for f in 20: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("user://door_0.png")
	m().use_door(m().doors.find(d), p.global_position)
	await get_tree().create_timer(0.8).timeout
	get_viewport().get_texture().get_image().save_png("user://door_1.png")
	out("door open %s" % d["open"])
	var panes: Array = m().map["breakables"].filter(func(b): return is_instance_valid(b) and String(b.get_meta("break_kind", "")) == "glass")
	if not panes.is_empty():
		var g: Node3D = panes[0]
		var gn := Vector3(1, 0, 0) if absf(g.global_transform.basis.x.x) < 0.5 else Vector3(0, 0, 1)
		var sz: Vector3 = (g.get_child(0).shape as BoxShape3D).size
		gn = Vector3(1, 0, 0) if sz.x < sz.z else Vector3(0, 0, 1)
		p.global_position = g.global_position + gn * 3.0 - Vector3(0, g.global_position.y - 0.3, 0)
		_aim_at(p, g.global_position)
		for f in 20: await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("user://glass_0.png")
		m().hit_breakable(int(g.get_meta("break")), 30.0, "bullet")
		await get_tree().create_timer(0.6).timeout
		get_viewport().get_texture().get_image().save_png("user://glass_1.png")
		out("glass broken %s" % (not is_instance_valid(g)))
	out("RESULT doorshot")
	get_tree().quit()

## Fire: light a wooden building, watch it spread and smoke, count what burned.
func _fireshot(p: Node) -> void:
	_skip_brief()
	if p == null or step > 0 or not m().go or m().hud._brief_t >= 0:
		return
	step = 1
	m().hud.inventory_open = false
	p.set_meta("ghost", true)
	p.hp = 5000.0
	p.set_physics_process(false)
	var woods: Array = m().map["breakables"].filter(func(b): return is_instance_valid(b) and String(b.get_meta("break_kind", "")) == "wood")
	out("wood pieces %d" % woods.size())
	if woods.is_empty():
		out("RESULT fireshot no wood"); get_tree().quit(); return
	# the wooden piece with the most wood around it
	var best: Node3D = woods[0]
	var bn := 0
	for w in woods:
		var n := 0
		for w2 in woods:
			if (w as Node3D).global_position.distance_to(w2.global_position) < 5.0:
				n += 1
		if n > bn:
			bn = n
			best = w
	var at := best.global_position
	m().explode(at + Vector3(0, 0.5, 0), 3.0, 40.0, "-", false)
	m().ignite(at)
	var before := woods.size()
	p.global_position = at + Vector3(9, 0.3, 9)
	_aim_at(p, at + Vector3(0, 1.5, 0))
	Engine.time_scale = 3.0
	for k in 3:
		await get_tree().create_timer(15.0).timeout
		get_viewport().get_texture().get_image().save_png("user://fire_%d.png" % k)
		var left: int = m().map["breakables"].filter(func(b): return is_instance_valid(b) and String(b.get_meta("break_kind", "")) == "wood").size()
		out("t%d fires %d wood left %d of %d smoke-blocks %s" % [k, m().fires.size(), left, before, m().smoke_blocks(p.global_position + Vector3(0, 1.5, 0), at + Vector3(0, 1.0, 0))])
	Engine.time_scale = 1.0
	out("RESULT fireshot")
	get_tree().quit()

## Their base: pictures of the cells, the captives, the core blown up, the objective.
func _abase(p: Node) -> void:
	_skip_brief()
	if p == null or step > 0 or not m().go or m().hud._brief_t >= 0:
		return
	step = 1
	m().hud.inventory_open = false
	p.set_meta("ghost", true)
	p.hp = 5000.0
	p.set_physics_process(false)
	p.light_on = true
	out("captives %d civs %d aliens %d core %s" % [m().map["captives"].size(), m().civilians().size(), m().aliens().size(), m().map.has("core")])
	for a in m().aliens():
		a.set_physics_process(false)
	var shots := 0
	var gen = m().map
	var wps: Array = gen["waypoints"]
	for i in range(0, wps.size(), maxi(1, wps.size() / 6)):
		var c: Vector3 = wps[i]
		p.global_position = c + Vector3(-4.5, 0.3, -4.5)
		_aim_at(p, c + Vector3(0, 1.0, 0))
		for f in 15: await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("user://abase_%d.png" % shots)
		shots += 1
	var cmd: Vector3 = gen["command"]
	p.global_position = cmd + Vector3(3.5, 0.1, -3.0)
	_aim_at(p, cmd + Vector3(0, 1.5, 3.0))
	for f in 15: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("user://abase_command.png")
	var core: Node3D = gen["core"]
	out("core idx %d kind %s hp %s same %s" % [int(core.get_meta("break")), core.get_meta("break_kind"), core.get_meta("hp"), m().map["breakables"][int(core.get_meta("break"))] == core])
	m().hit_breakable(int(core.get_meta("break")), 999.0, "explosion")
	out("after hp %s broken %s" % [core.get_meta("hp") if is_instance_valid(core) else "freed", core.get_meta("broken", false) if is_instance_valid(core) else true])
	await get_tree().create_timer(1.0).timeout
	out("core down %s objective %s" % [m().core_down(), m()._objective_met()])
	out("RESULT abase %d" % shots)
	get_tree().quit()
