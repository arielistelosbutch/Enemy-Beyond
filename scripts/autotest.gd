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
		"coophealhost", "coophealclient": _coopheal(p)
		"coopwipehost", "coopwipeclient":
			_skip_brief()
			if p and m().started() and step == 0:
				step = 1
				out("[WIPE] %s in mission, players %d" % [mode, m().players().size()])
				if mode == "coopwipehost":
					await get_tree().create_timer(3.0).timeout
					for q in m().players():
						q.hurt.rpc_id(q.get_multiplayer_authority(), 999.0, q.global_position + Vector3(0, 0, 2))
					out("[WIPE] everybody shot down")
		"lbhost", "lbclient":
			_skip_brief()
			if t > 2.0 and int(t) % 5 == 0 and int(t * 10) % 50 == 0:
				out("[LB] %s t=%.0f scene mission local=%s go=%s players=%d p=%s" % [mode, t, m().local(), m().go, m().players().size(), p != null])
			if p and m().started() and not m().local() and step == 0:
				step = 1
				var n0: int = m().players().size()
				out("[LB] %s in the real mission: players %d, local %s" % [mode, n0, m().local()])
				await get_tree().create_timer(6.0 if mode == "lbhost" else 2.0).timeout
				out("RESULT lb %s players %d" % [mode, n0])
				get_tree().quit()
		"basepass": _passcheck(p)
		"doorshot": _doorshot(p)
		"passcheck": _passcheck(p)
		"camoshot": _camoshot(p)
		"soundcheck": _soundcheck(p)
		"dronetest": _dronetest(p)
		"airdeath": _airdeath(p)
		"vipcheck": _vipcheck(p)
		"climb": _climb(p)
		"leaveany": _leaveany(p)
		"skyshot": _skyshot(p)
		"zfight": _zfight(p)
		"suittest": _suittest(p)
		"levgrab": _levgrab(p)
		"mirotest": _mirotest(p)
		"bijtest": _bijtest(p)
		"bvtest": _bvtest(p)
		"nadtest": _nadtest(p)
		"ohntest": _ohntest(p)
		"mystest": _mystest(p)
		"koltest": _koltest(p)
		"lasertest": _lasertest(p)
		"aitest": _aitest(p)
		"latetest": _latetest(p)
		"gunshots": _gunshots(p)
		"topshot": _topshot(p)
		"shieldtest": _shieldtest(p)
		"locktest": _locktest(p)
		"mocapgame": _mocapgame(p)
		"beltthrow": _beltthrow(p)
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
## --zoo=levit,ohar: only these.
func _zoo_list() -> Array:
	var only := Game.cmd_arg("zoo", "")
	return ZOO if only == "" else Array(only.split(","))

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
	if Game.cmd_arg("kit", "") != "":
		# the full kit on show: armour, backpack, belt, medkit, helmet; the camera all round
		p.armor = "vesta"
		p.inv["b0"] = {"id": "rifle_clip"}
		p.inv["b1"] = {"id": "rifle_clip"}
		p.inv[Game.pack_slots()[0]] = {"id": "medkit"}
		p.inv["p0"] = {"id": "medkit"}
		p.gear = p._gear_mask()
		p._apply_gear()
		Game.apply_look(p.merc_model, {"gear": "helmet", "hair": "buzz"})
		for e2 in [["kit_front", Vector3(0.9, 1.0, -2.4)], ["kit_side", Vector3(2.6, 1.0, 0.0)], ["kit_back", Vector3(-0.6, 1.0, 2.5)]]:
			cam.global_position = p.global_position + e2[1]
			cam.look_at(p.global_position + Vector3(0, 0.9, 0))
			for i in 20:
				p._animate_body(1.0 / 30.0)
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("user://pose_%s.png" % e2[0])
		get_tree().quit()
		return
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
		shots = [["out", u + Vector3(-34, 14, -40), u + Vector3(0, 3, 0)], ["door", door + Vector3(0, 0.3, -6.0), u],
			["gallery", u + Vector3(3.5, 4.9, -4.0), u + Vector3(-2.0, 5.5, 3.0)], ["up", u + Vector3(-15.0 + 3.5, 4.9, -4.0), u + Vector3(-16.0, 5.8, 1.0)]]
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
		m().env.ambient_light_energy = 0.6 if e[0] != "out" else 2.0
		m().env.fog_enabled = e[0] != "out"
		m().env.volumetric_fog_enabled = false
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
	if Game.cmd_arg("lh", "") != "":
		# what is in the hands (e.g. --lh=stit --rh=pistol: the view through the shield)
		p.inv["rh"] = {"id": Game.cmd_arg("rh", "pistol"), "loaded": 10}
		p.inv["lh"] = {"id": Game.cmd_arg("lh", "")}
		p._update_held()
		if Game.cmd_arg("up", "") != "":
			Input.action_press("aim")
	await get_tree().create_timer(1.5).timeout
	get_viewport().get_texture().get_image().save_png("user://weather_%s.png" % m().weather)
	get_tree().quit()

## 0.50: the whole map from straight above (orthographic), to check the layout: user://top_<biome>_<seed>.png
func _topshot(p: Node) -> void:
	if p == null or step > 0 or not m().started():
		return
	step = 1
	_skip_brief()
	m().hud.visible = false
	var size: float = m().map["size"]
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = size * 1.02
	cam.far = 300
	m().add_child(cam)
	cam.global_position = Vector3(size / 2, 120, size / 2)
	cam.rotation = Vector3(-PI / 2, 0, 0)
	cam.make_current()
	m().env.fog_enabled = false
	m().env.volumetric_fog_enabled = false
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.2
	sun.rotation = Vector3(-1.1, 0.4, 0)
	m().add_child(sun)
	await get_tree().create_timer(1.5).timeout
	get_viewport().get_texture().get_image().save_png("user://top_%s_%s.png" % [Game.cmd_arg("biome", "farm"), Game.cmd_arg("seed", "0")])
	out("RESULT topshot untangled %s evac %s size %.0f" % [m().map.get("untangled", []), m().map["evac"], size])
	get_tree().quit()

## 0.50: every gun in the hands, one picture each (user://gun_<id>.png).
func _gunshots(p: Node) -> void:
	if p == null or step > 0 or not m().started():
		return
	step = 1
	_skip_brief()
	await get_tree().create_timer(2.0).timeout
	m().hud.inventory_open = false
	p.hp = 9999.0
	for a in m().aliens():
		a.queue_free()
	p.global_position = m().free_spot(m().map["evac"] + Vector3(6, 0.3, -6))
	_aim_at(p, m().map["ufo"] + Vector3(0, 1.5, 0))
	var ids := Game.cmd_arg("guns", "rifle,pistol,shotgun,magnum,sniper,autocannon,minigun,rocket_launcher,plasma_rifle,laser_pistol,laser_rifle,laser_cannon").split(",")
	for id in ids:
		p.inv["rh"] = {"id": id, "loaded": 5}
		p.inv.erase("lh")
		p._update_held()
		if Game.cmd_arg("aim", "") != "":
			Input.action_press("aim")
		await get_tree().create_timer(1.4).timeout
		get_viewport().get_texture().get_image().save_png("user://gun_%s.png" % id)
		Input.action_release("aim")
	out("RESULT gunshots %d" % ids.size())
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
		for i in _zoo_list().size():
			m().spawn_alien(_zoo_list()[i], m().map["ufo"] + Vector3(i * 2.0 - _zoo_list().size(), 0.3, 20))
		return
	al = al.filter(func(a): return is_instance_valid(a) and not a.is_queued_for_deletion())
	if step == 0 and t > 2.5 and al.size() >= _zoo_list().size():
		step = 1
		var base: Vector3 = m().map["ufo"] + Vector3(0, 0, 13)
		if Game.cmd_arg("stage", "") != "":
			# a clean stage up in the sky (no walls in the way): a floor and a light
			base = Vector3(0, 80, 0)
			var fl := MeshInstance3D.new()
			var fm := BoxMesh.new()
			fm.size = Vector3(40, 0.2, 30)
			fl.mesh = fm
			fl.material_override = Game.mat("grass", 0.5)
			m().add_child(fl)
			fl.global_position = base + Vector3(0, -0.1, 0)
			var sb := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = fm.size
			cs.shape = bs
			sb.add_child(cs)
			fl.add_child(sb)
			p.set_physics_process(false)
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
		p.global_position = f + (Vector3(3.4, 0, 1.2) if Game.cmd_arg("side", "") != "" else Vector3(0.6, 0, -3.2))
		_aim_at(p, f + Vector3(0, 1.0, 0))
		if Game.cmd_arg("side", "") != "":
			for c in p.cam.get_children():
				if c is MeshInstance3D or (c is Node3D and not c is Light3D):
					c.visible = false
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

## Co-op bandaging: the client is hit (bleeding), the host bandages him; then the host is hit
## and treats himself. Both log their health for a while after: it must stop dropping.
func _coopheal(p: Node) -> void:
	_skip_brief()
	if p == null or step > 0 or not m().started():
		return
	step = 1
	for a in m().aliens():
		a.set_physics_process(false)
		a.global_position += Vector3(0, -200, 0)
	var host := Game.autotest() == "coophealhost"
	await get_tree().create_timer(2.0).timeout
	if host:
		var other: Node = null
		for q in m().players():
			if q != p:
				other = q
		if other == null:
			out("RESULT coopheal no client"); get_tree().quit(); return
		other.hurt.rpc_id(other.get_multiplayer_authority(), 9.0, other.global_position + Vector3(0, 0, 3))
		other.hurt.rpc_id(other.get_multiplayer_authority(), 9.0, other.global_position + Vector3(0, 0, 3))
		await get_tree().create_timer(1.5).timeout
		p.global_position = other.global_position + Vector3(1.0, 0, 0)
		p.inv["rh"] = {"id": "medkit", "uses": 4}
		p._update_held()
		await get_tree().create_timer(0.5).timeout
		out("host treats: target %s" % (p.heal_target().display_name if p.heal_target() else "-"))
		p._treat_teammate("rh")
		await get_tree().create_timer(4.0).timeout
		# now himself
		p.hurt(9.0, p.global_position + Vector3(0, 0, 3))
		p.hurt(9.0, p.global_position + Vector3(0, 0, 3))
		out("host hurt: hp %.1f bleeding %.2f" % [p.hp, p.bleeding])
		p.inv["rh"] = {"id": "medkit", "uses": 4}
		p._heal_self()
		await get_tree().create_timer(3.6).timeout
		var h0: float = p.hp
		await get_tree().create_timer(5.0).timeout
		out("host after self-bandage: hp %.1f -> %.1f bleeding %.2f" % [h0, p.hp, p.bleeding])
		out("RESULT coopheal host %s" % ("ok" if p.hp >= h0 - 0.05 else "PORAD KRVACI"))
		await get_tree().create_timer(3.0).timeout
		get_tree().quit()
	else:
		for k in 16:
			await get_tree().create_timer(1.0).timeout
			out("client t=%d hp %.1f bleeding %.2f healed_t %.1f" % [k, p.hp, p.bleeding, p.healed_t])
		get_tree().quit()

## Climbing: a 2 m block (from the ground), a 2.9 m block (jump + Space held), then a house roof.
## A Levit takes a lone merc with its tentacles and carries him off.
func _levgrab(p: Node) -> void:
	_skip_brief()
	if p == null or step > 0 or not m().started():
		return
	var ls: Array = m().aliens().filter(func(a): return a.race == "levit")
	if ls.is_empty():
		return
	step = 1
	for a in m().aliens():
		if not a in ls:
			a.queue_free()
	var l: Node = ls[0]
	for o in ls.slice(1):
		o.queue_free()
	p.hp = 999.0
	l.global_position = m().free_spot(p.global_position + Vector3(0, 0.3, 6))     # (behind the ramp - not on a wing)
	l.target = p
	l.last_seen = p.global_position
	l._enter_combat(null)
	l._grab_cd = 0.0
	l.phase = "grab"
	for i in 40:
		await get_tree().create_timer(0.25).timeout
		if i % 4 == 0: out("lev %s phase %s state %s" % [l.global_position, l.phase, l.state])
		if p.ko:
			break
	await get_tree().create_timer(3.0).timeout
	out("RESULT levgrab ko %s carried %s state %s phase %s dist %.1f lpos %s" % [p.ko, p.carried_by != 0, l.state, l.phase, l.global_position.distance_to(p.global_position), l.global_position])
	get_tree().quit()

## A Šedivák hit hard: his suit fails (slower, worse aim).
func _suittest(p: Node) -> void:
	_skip_brief()
	if p == null or step > 0 or not m().started():
		return
	var gs: Array = m().aliens().filter(func(a): return a.tac == "grey")
	if gs.is_empty():
		return
	step = 1
	var g: Node = gs[0]
	var r0: float = g.run_spd
	g.state = g.S.COMBAT
	g.damage(float(g.R["hp"]) * 0.65, g.global_position + Vector3(0, 1, 2), null)
	await get_tree().create_timer(0.3).timeout
	out("RESULT suittest down %s run %.1f -> %.1f alive %s" % [g.suit_down, r0, g.run_spd, not g.dead])
	get_tree().quit()

## The shield: low it stops half from the front, up nearly all; acid wears it out until it breaks.
func _shieldtest(p: Node) -> void:
	_skip_brief()
	if p == null or step > 0 or not m().started():
		return
	step = 1
	p.hp = 9999.0
	p.armor = ""
	p.inv["rh"] = {"id": "pistol", "loaded": 10}
	p.inv["lh"] = {"id": "stit"}
	p._update_held()
	m().hud.inventory_open = false
	await get_tree().create_timer(0.3).timeout
	var front: Vector3 = p.global_position - p.global_transform.basis.z * 10.0
	var h0: float = p.hp
	p.hurt(20.0, front)
	var low: float = h0 - p.hp
	Input.action_press("aim")
	await get_tree().create_timer(0.3).timeout
	var h1: float = p.hp
	p.hurt(20.0, front)
	var up: float = h1 - p.hp
	var n := 0
	while p.item_in("lh").get("id", "") == "stit" and n < 200:
		p.hurt(30.0, front, true)
		n += 1
	Input.action_release("aim")
	out("RESULT shieldtest low %.0f up %.0f broke %s after %d" % [low, up, p.item_in("lh").is_empty(), n])
	get_tree().quit()

## Editor animations in the game (0.52): a knife locked to the hand turns with it in a blow, a body
## movement changed in the editor replaces the model's own, a blow made in the eyes view moves the knife.
func _locktest(p: Node) -> void:
	_skip_brief()
	if p == null or step > 0 or not m().started():
		return
	step = 1
	p.hp = 9999.0
	p.inv["rh"] = {"id": "knife"}
	p.inv.erase("lh")
	p._update_held()
	m().hud.inventory_open = false
	await get_tree().create_timer(0.6).timeout
	var still := func():
		p._last_body_pos = p.global_position
		p._body_speed = 0.0
		p._animate_body(0.016)      # (his own body is animated only for the others; standing still)
	for i in 10:
		still.call()
	var sk: Skeleton3D = p._sk
	var hand_of := func() -> Transform3D: return sk.global_transform * sk.get_bone_global_pose(sk.find_bone("hand.R"))
	# where the knife is this frame (the bone attachment catches up only after the skeleton updates)
	var gun_of := func() -> Transform3D: return sk.global_transform * sk.get_bone_global_pose(sk.find_bone("spine")) * p.body_gun.transform
	var rel0 := Transform3D()
	var b0: Basis = gun_of.call().basis
	# a blow: the knife follows the hand (its place in the hand stays, the knife itself turns)
	p._melee("rh", Game.ITEMS["knife"])
	p.act = 2
	p._act_t = 0.0
	var worst := 0.0
	var turned := 0.0
	for i in 12:
		await get_tree().process_frame
		await get_tree().process_frame
		p.act = 2
		still.call()
		var rel: Transform3D = hand_of.call().affine_inverse() * gun_of.call()
		if i == 0:
			rel0 = p._lock_rel      # (taken into the hand as the blow starts)
		worst = maxf(worst, rel.origin.distance_to(rel0.origin))
		turned = maxf(turned, gun_of.call().basis.get_rotation_quaternion().angle_to(b0.get_rotation_quaternion()))
	p.act = 0
	# a body movement from the editor
	var clip := AnimClips.new_clip("tp", "test")
	AnimClips.set_key(clip, "spine", 0.0, [0.0, 0.0, 40.0])
	AnimClips.set_key(clip, "root@pos", 0.0, [0.0, 0.3, 0.0])
	clip["delka"] = 1.0
	clip["smycka"] = true
	still.call()
	var bid := "tp_body_" + String(p.body_anim.current_animation)
	var had := AnimClips.get_clip(bid).duplicate(true)      # (an installed one comes back afterwards)
	AnimClips.save_clip(bid, clip)
	p._bclip_name = ""
	await get_tree().create_timer(0.5).timeout
	for i in 3:
		still.call()
	var si := sk.find_bone("spine")
	var rq: Quaternion = sk.get_bone_rest(si).basis.get_rotation_quaternion()
	var off: Vector3 = Basis(rq.inverse() * sk.get_bone_pose_rotation(si)).get_euler() * (180.0 / PI)
	var ri := sk.find_bone("root")
	var up: float = sk.get_bone_pose_position(ri).y - sk.get_bone_rest(ri).origin.y
	AnimClips.delete_clip(bid)
	if not had.is_empty():
		AnimClips.save_clip(bid, had)
	# a blow from the eyes-view editor
	var fc := AnimClips.new_clip("fp", "test")
	AnimClips.set_key(fc, "zbran", 0.0, [0, 0, 0, 0, 0, 0])
	AnimClips.set_key(fc, "zbran", 0.25, [0.0, 0.2, 0.0, 0.0, 0.0, 0.0])
	AnimClips.set_key(fc, "zbran", 0.5, [0, 0, 0, 0, 0, 0])
	fc["delka"] = 0.5
	AnimClips.save_clip("fp_strike_knife", fc)
	p.fire_cd = 0.0
	var y0: float = p.gun.position.y
	p._melee("rh", Game.ITEMS["knife"])
	var ymax := y0
	for i in 20:
		await get_tree().process_frame
		ymax = maxf(ymax, p.gun.position.y)
	AnimClips.delete_clip("fp_strike_knife")
	out("RESULT locktest follows %s turned %s body %s root %s fp %s" % [worst < 0.02, turned > 0.3, absf(off.z - 40.0) < 2.0, absf(up - 0.3) < 0.02, ymax - y0 > 0.08])
	get_tree().quit()

## G throws the grenade on the belt (here a smoke one), not one from the pack.
func _beltthrow(p: Node) -> void:
	_skip_brief()
	if p == null or step > 0 or not m().started():
		return
	step = 1
	for s in p.inv.keys():
		if String(s).begins_with("b") or String(s).begins_with("p"):
			p.inv.erase(s)
	p.inv["b1"] = {"id": "smoke_grenade"}
	p.inv["p0"] = {"id": "grenade"}
	p._throw_belt_grenade()
	var started: bool = p.busy > 0.0 and String(p.busy_text).begins_with("Házím")
	await get_tree().create_timer(1.5).timeout
	out("RESULT beltthrow started %s belt_used %s pack_kept %s" % [started, not p.inv.has("b1"), p.inv.has("p0")])
	get_tree().quit()

## The Mixamo movements in the game, seen from outside: walking each way, crouching, lying,
## crawling wounded, dying. Pictures user://mocap_<n>.png; checks that the body follows the clips.
func _mocapgame(p: Node) -> void:
	_skip_brief()
	if p == null or step > 0 or not m().started():
		return
	step = 1
	p.hp = 9999.0
	for a in m().aliens():
		a.set_physics_process(false)
	p.body.visible = true
	p.set_physics_process(false)
	var cam := Camera3D.new()
	m().add_child(cam)
	if m().hud is CanvasItem:
		(m().hud as CanvasItem).visible = false
	elif m().hud.has_method("hide"):
		m().hud.hide()
	# out of the ship, on open ground
	var base: Vector3 = p.global_position + p.global_transform.basis * Vector3(0, 0, -9.0)
	var hit: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(base + Vector3.UP * 20.0, base + Vector3.DOWN * 20.0))
	if not hit.is_empty():
		base = hit["position"]
	cam.global_position = base + p.global_transform.basis * Vector3(1.6, 1.5, -3.4)
	cam.look_at(base + Vector3(0, 0.8, 0))
	cam.make_current()
	var shots := [["chuze", Vector3(0, 0, -2.6), {}], ["vzad", Vector3(0, 0, 2.6), {}], ["vlevo", Vector3(-2.6, 0, 0), {}],
		["podrep", Vector3(0, 0, -1.3), {"crouching": true}], ["plazeni", Vector3(0, 0, -0.7), {"prone": true}],
		["smrt", Vector3.ZERO, {"dead": true}], ["raneny", Vector3(0, 0, -0.5), {"downed": true}], ["smrt_z_kleku", Vector3.ZERO, {"dead": true}],
		["otoceni", Vector3.ZERO, {"turn": 2.0}], ["otoceni_podrep", Vector3.ZERO, {"crouching": true, "turn": -2.0}],
		["hod_vleze", Vector3.ZERO, {"prone": true, "act": 5}],
		["skok", Vector3.ZERO, {"act": 8}], ["splhani", Vector3.ZERO, {"act": 7}], ["panika", Vector3.ZERO, {"panic": "drop"}],
		["batoh", Vector3.ZERO, {"act": 3}], ["prebijeni_vleze", Vector3.ZERO, {"prone": true, "act": 1}],
		["mireni", Vector3.ZERO, {"aiming": true}], ["dvere", Vector3.ZERO, {"act": 6}], ["zasah", Vector3.ZERO, {"hit": true}]]
	var ok := 0
	for i in shots.size():
		var e: Array = shots[i]
		for k in ["crouching", "prone", "downed", "dead", "aiming"]:
			p.set(k, bool((e[2] as Dictionary).get(k, false)))
		p.act = int((e[2] as Dictionary).get("act", 0))
		p.panic = String((e[2] as Dictionary).get("panic", ""))
		if (e[2] as Dictionary).get("hit", false):
			p._hit_id = "tp_hit_1_vse"
			p._hit_t = 0.0
		p.held = "rifle"
		p.global_position = base
		p._last_body_pos = base
		var vel: Vector3 = p.global_transform.basis * (e[1] as Vector3)
		var turn := float((e[2] as Dictionary).get("turn", 0.0))
		if not (e[2] as Dictionary).get("dead", false):
			p._body_want = ""
		for f in 75:
			p.global_position += vel / 60.0
			p.rotation.y += turn / 60.0
			p._animate_body(1.0 / 60.0)
			p.global_position -= vel / 60.0      # (on the spot, the camera stays on him)
			p._last_body_pos = p.global_position
		cam.make_current()
		for f in 3:
			await get_tree().process_frame
			p.global_position += vel / 60.0
			p.rotation.y += turn / 60.0
			p._animate_body(1.0 / 60.0)
			p.global_position -= vel / 60.0
			p._last_body_pos = p.global_position
		if DisplayServer.get_name() != "headless":
			get_viewport().get_texture().get_image().save_png("user://mocap_%d_%s.png" % [i, e[0]])
		print("[MOCAP] %s: body %s at %.2f s, hit %s" % [e[0], p._bclip_id, p._bclip_t, p._hit_id])
		if p._bclip_id.begins_with("tp_body_") or (e[2] as Dictionary).has("act") or (e[2] as Dictionary).has("hit"):
			ok += 1
	out("RESULT mocapgame %d of %d use the movements" % [ok, shots.size()])
	get_tree().quit()

## A firefight to measure them: a squad against a merc who cannot die, standing at a house corner.
## How much damage reaches him in 45 s, and what they did (from the [TAC] lines).
func _aitest(p: Node) -> void:
	_skip_brief()
	if p == null or step > 0 or not m().started():
		return
	step = 1
	var race := Game.cmd_arg("race", "jestetan")
	for a in m().aliens():
		a.queue_free()
	await get_tree().create_timer(0.3).timeout
	p.hp = 99999.0
	var ss: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	# an open spot for him: one that sees far in most directions
	var bestp: Vector3 = p.global_position
	var bestn := -1
	for wp in m().map.get("waypoints", []):
		var c: Vector3 = wp
		var n := 0
		for k in 8:
			var a := k * TAU / 8.0
			var q0 := PhysicsRayQueryParameters3D.create(c + Vector3(0, 1.4, 0), c + Vector3(sin(a) * 25.0, 1.4, cos(a) * 25.0), Game.WORLD)
			if ss.intersect_ray(q0).is_empty():
				n += 1
		if n > bestn:
			bestn = n
			bestp = c
	p.global_position = bestp + Vector3(0, 0.1, 0)
	await get_tree().create_timer(0.3).timeout
	var at: Vector3 = p.global_position
	var placed := 0
	for k in 200:
		if placed >= int(Game.cmd_arg("n", "4")):
			break
		var a := randf() * TAU
		var pt: Vector3 = m().free_spot(at + Vector3(sin(a), 0, cos(a)) * randf_range(18.0, 30.0) + Vector3(0, 0.3, 0))
		var q := PhysicsRayQueryParameters3D.create(pt + Vector3(0, 1.6, 0), at + Vector3(0, 1.4, 0), Game.WORLD)
		var fq := PhysicsRayQueryParameters3D.create(pt + Vector3(0, 1.0, 0), pt + Vector3(0, -1.0, 0), Game.WORLD)
		var fh := ss.intersect_ray(fq)
		if fh.is_empty() or absf(fh.position.y - at.y) > 0.6:
			continue          # (off the map, or into a cellar)
		if ss.intersect_ray(q).is_empty() or k > 150:
			m().spawn_alien(race, pt)
			placed += 1
	await get_tree().create_timer(0.5).timeout
	for a in m().aliens():
		a.target = p
		a.last_seen = p.global_position
		a._enter_combat(p)
		out("  %s gun %s nades %s mines %d traps %d hp %.0f at %s me %s" % [a.race, a.gun, a.has_nades, a.mines_left, a.traps_left, a.hp, a.global_position, p.global_position])
	var hp0: float = p.hp
	for i in 90:
		await get_tree().create_timer(0.5).timeout
		if i % 6 == 0:
			var line := ""
			for a in m().aliens():
				line += "%s:%s/%s d%.0f los%s vis%s react%.1f arr%s | " % [a.name, a.state, a.phase, a.global_position.distance_to(p.global_position), int(a._los(p.global_position + Vector3(0, 1.4, 0))), int(a.visible_to(p)), a.react, int(a._arrived())]
			out(line)
	var shots := 0
	for a in m().aliens():
		shots += a.shots_fired
		out("  %s state %s phase %s shots %d dist %.0f los %s" % [a.name, a.state, a.phase, a.shots_fired, a.global_position.distance_to(p.global_position), a._los(p.global_position + Vector3(0, 1.4, 0))])
	out("RESULT aitest %s late %s dmg %.0f shots %d" % [race, Game.cmd_arg("late", "0"), hp0 - p.hp, shots])
	get_tree().quit()

## Laser: shot dry, it will not fire until the cell is full again.
func _lasertest(p: Node) -> void:
	_skip_brief()
	if p == null or step > 0 or not m().started():
		return
	step = 1
	p.inv["rh"] = {"id": "laser_rifle", "loaded": 1}
	p._update_held()
	var r: Dictionary = Game.ITEMS["laser_rifle"]
	p._shoot("rh", p.inv["rh"], r)
	var drained: bool = p.inv["rh"].get("drained", false)
	await get_tree().create_timer(2.5).timeout
	var part: int = int(p.inv["rh"]["loaded"])
	var still: bool = p.inv["rh"].get("drained", false)
	var cap := Game.mag_size("laser_rifle")
	await get_tree().create_timer(float(cap) / float(r["recharge"]) + 1.5).timeout
	out("RESULT lasertest drained %s partial %s still %s full %s free %s" % [drained, part > 0 and part < cap, still, int(p.inv["rh"]["loaded"]) >= cap, not p.inv["rh"].get("drained", false)])
	get_tree().quit()

## The late war: a night pack, the nemesis, an officer's killer remembered, reinforcements; the campaign side.
func _latetest(p: Node) -> void:
	_skip_brief()
	if p == null or step > 0 or not m().started() or m().aliens().size() < 3:
		return
	step = 1
	p.hp = 9999.0
	m()._nem_done = true
	await get_tree().create_timer(1.0).timeout
	var S = m().aliens()[0].S
	# 1) a night pack: bring them within reach and let the timer run out
	for a in m().aliens():
		a.global_position = m().free_spot(p.global_position + Vector3(randf_range(-30, 30), 0.3, randf_range(25, 45)))
		a.state = S.LURK
	m()._pack_t = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	var stalkers: int = m().aliens().filter(func(a): return a.state == S.STALK).size()
	# 2) the nemesis
	Net.mission_params["nemesis"] = [p.display_name]
	m()._nemesis_start()
	var hunters: int = m().aliens().filter(func(a): return a.nemesis == p).size()
	# 3) an officer's killer
	var off: String = String(m().GROUPS.get(m().crew_group, m().GROUPS["sedaci"])["officer"])
	m().spawn_alien(off, m().free_spot(p.global_position + Vector3(0, 0.3, 6)))
	await get_tree().create_timer(0.6).timeout
	var o = m().aliens().filter(func(a): return a.race == off and not a.dead)
	if not o.is_empty():
		o[0].damage(99999.0, p.global_position, p)
	await get_tree().create_timer(0.3).timeout
	var marked: bool = p.display_name in m().officer_killers
	# 4) reinforcements: pretend they took far too long
	var before: int = m().aliens().filter(func(a): return not a.dead).size()
	m()._late_reinf_t = 100000.0
	for i in 5:
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	var after: int = m().aliens().filter(func(a): return not a.dead).size()
	# 5) the campaign side
	var d0 = Campaign.data.duplicate(true)
	Campaign.data["day"] = 105.0
	Campaign.data["nemesis"] = {}
	Campaign.data["log"] = []
	var ws: float = Campaign.war_stage()
	Campaign.mark_nemesis(["Testovic"])
	var left := []
	for i in 3:
		Campaign._nemesis_tick()
		left.append(Campaign.data["nemesis"].size())
	Campaign.data = d0
	out("RESULT latetest pack %d nemesis %d marked %s waves %d added %d war %.2f nem %s" % [stalkers, hunters, marked, m()._reinf_waves, after - before, ws, left])
	get_tree().quit()

## Kolos: up a wall onto a roof, then down again.
func _koltest(p: Node) -> void:
	_skip_brief()
	if p == null or step > 0 or not m().started():
		return
	var ks: Array = m().aliens().filter(func(a): return a.race == "kolos")
	if ks.is_empty():
		if not has_meta("kol_spawned"):
			set_meta("kol_spawned", true)
			m().spawn_alien("kolos", m().free_spot(p.global_position + Vector3(0, 0.3, 8)))
		return
	step = 1
	p.hp = 9999.0
	for a in m().aliens():
		if not a in ks:
			a.queue_free()
	var k: Node = ks[0]
	await get_tree().create_timer(0.5).timeout
	var ok := false
	var tries := 0
	# walk it round the houses until one has a wall it can go up
	for r in m().map.get("roofs", []):
		var rp: Vector3 = r
		if rp.y < -50.0:
			rp.y = 5.0
		if rp.y > 14.0:
			continue
		tries += 1
		k.global_position = m().free_spot(Vector3(rp.x + 10.0, 0.3, rp.z))
		await get_tree().create_timer(0.2).timeout
		if k._climb_up(Vector3(rp.x + 14.0, 0.0, rp.z)):
			ok = true
			break
		if tries > 12:
			break
	var top := 0.0
	for i in 60:
		await get_tree().create_timer(0.25).timeout
		top = maxf(top, k.global_position.y)
		if Game.cmd_arg("shot", "") != "" and i == 7:
			# a picture of it on the wall
			p.global_position = Vector3(k.global_position.x, 0.2, k.global_position.z) + (k._wall_base - k._wall_top).normalized() * 0.0 + Vector3(k._wall_base.x - k._wall_top.x, 0, k._wall_base.z - k._wall_top.z).normalized() * 10.0 + Vector3(4, 0, 0)
			_aim_at(p, k.global_position + Vector3(0, 1.0, 0))
			await get_tree().create_timer(0.3).timeout
			_snap("52_kolos_climb")
		if not k.flying:
			break
	if Game.cmd_arg("shot", "") != "":
		_aim_at(p, k.global_position + Vector3(0, 1.0, 0))
		await get_tree().create_timer(0.3).timeout
		_snap("53_kolos_roof")
	var perched: bool = k.airborne and k.global_position.y > 2.0
	k._climb_down()
	for i in 60:
		await get_tree().create_timer(0.25).timeout
		if not k.flying:
			break
	out("RESULT koltest found %s up %s top %.1f down %s" % [ok, perched, top, k.global_position.y < 1.0 and not k.airborne])
	get_tree().quit()

## Mysloděj: shot, it is gone - somewhere else, out of the shooter's sight.
func _mystest(p: Node) -> void:
	_skip_brief()
	if p == null or step > 0 or not m().started():
		return
	var ms: Array = m().aliens().filter(func(a): return a.race == "myslodej")
	if ms.is_empty():
		if not has_meta("mys_spawned"):
			set_meta("mys_spawned", true)
			m().spawn_alien("myslodej", p.global_position + Vector3(0, 0.3, 10))
		return
	step = 1
	await get_tree().create_timer(0.5).timeout
	var a: Node = ms[0]
	var at0: Vector3 = a.global_position
	a.damage(20.0, p.global_position, p)
	var moved: float = a.global_position.distance_to(at0)
	var at1: Vector3 = a.global_position
	a.damage(20.0, p.global_position, p)      # (too soon: it stays)
	out("RESULT mystest moved %s again %s alive %s" % [moved > 8.0, a.global_position.distance_to(at1) > 1.0, not a.dead])
	get_tree().quit()

## Ohnivec: it finds you through the ground, glows up and lets go a beam of heat.
func _ohntest(p: Node) -> void:
	_skip_brief()
	if p == null or step > 0 or not m().started():
		return
	var os_: Array = m().aliens().filter(func(a): return a.race == "ohnivec")
	if os_.is_empty():
		if not has_meta("ohn_spawned"):
			set_meta("ohn_spawned", true)
			m().spawn_alien("ohnivec", p.global_position + Vector3(0, 0.3, 6))
		return
	step = 1
	for a in m().aliens():
		if not a in os_:
			a.queue_free()
	var o: Node = os_[0]
	o.global_position = p.global_position + Vector3(0, 0.2, 6)
	p.crouching = true
	var hp0: float = p.hp
	o.target = p
	o._enter_combat(null)
	o._heat_cd = 0.0
	var knew := false
	var charged := false
	for i in 40:
		await get_tree().create_timer(0.2).timeout
		knew = knew or o._knows(p)
		charged = charged or o._charge > 0.0
		if p.hp < hp0 - 20.0:
			break
	out("RESULT ohntest knows %s charged %s hurt %s" % [knew, charged, p.hp < hp0 - 20.0])
	get_tree().quit()

## Nádor: bullets only knock it down (and then do nothing); a blast tears it apart for good.
func _nadtest(p: Node) -> void:
	_skip_brief()
	if p == null or step > 0 or not m().started():
		return
	var ns: Array = m().aliens().filter(func(a): return a.race == "nador")
	if ns.size() < 2:
		if not has_meta("nad_spawned"):
			set_meta("nad_spawned", true)
			for i in 2 - ns.size():
				m().spawn_alien("nador", p.global_position + Vector3(i * 6.0, 0.3, 16))
		return
	step = 1
	await get_tree().create_timer(0.5).timeout
	var a: Node = ns[0]
	var b: Node = ns[1]
	a.damage(999.0, a.global_position + Vector3(0, 0, 2), null)        # bullets: down, not dead
	var husk1: bool = a.husk and not a.dead
	for i in 5:
		a.damage(999.0, a.global_position + Vector3(0, 0, 2), null)    # still bullets: nothing
	var still: bool = a.husk and not a.dead
	m().hit_kind = "explosion"
	a.damage(60.0, a.global_position, null)                            # a grenade finishes it
	b.damage(999.0, b.global_position, null)                           # and one caught standing is torn apart at once
	m().hit_kind = ""
	out("RESULT nadtest husk %s still %s blast %s direct %s" % [husk1, still, a.dead, b.dead and not b.husk])
	get_tree().quit()

## Bijec officer: left alone in a fight it calls reinforcements; a shot into the forearm module stops that.
func _bvtest(p: Node) -> void:
	_skip_brief()
	if p == null or step > 0 or not m().started():
		return
	var vs: Array = m().aliens().filter(func(a): return a.race == "bijec_velitel")
	if vs.size() < 2:
		if not has_meta("bv_spawned"):
			set_meta("bv_spawned", true)
			for i in 2 - vs.size():
				m().spawn_alien("bijec_velitel", p.global_position + Vector3(i * 4.0, 0.3, 14))
		return
	step = 1
	p.hp = 9999.0
	await get_tree().create_timer(0.5).timeout
	var a: Node = vs[0]
	var b: Node = vs[1]
	# the module, where the weak spot is
	var sk: Skeleton3D = b._rig
	var bi := sk.find_bone("forearm.L")
	var bp: Vector3 = (sk.global_transform * sk.get_bone_global_pose(bi)).origin
	var tip: Vector3 = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("hand.L"))).origin
	var spot: Vector3 = bp.lerp(tip, 0.45)
	var weak: bool = b.weak_spot(spot)
	var not_weak: bool = not b.weak_spot(b.global_position + Vector3(0, 1.0, 0))
	b.module_hit()
	var n0: int = m().aliens().size()
	a.state = a.S.COMBAT
	b.state = b.S.COMBAT
	a._reinf_t = 999.0
	b._reinf_t = 999.0
	a._reinf_tick(0.1)
	b._reinf_tick(0.1)
	await get_tree().create_timer(1.0).timeout
	out("RESULT bvtest weak %s body %s module %s reinf %d" % [weak, not_weak, b.module_ok, m().aliens().size() - n0])
	get_tree().quit()

## Bijec: no flinch from pain; hit hard, the armour fails and the bullets bite more.
func _bijtest(p: Node) -> void:
	_skip_brief()
	if p == null or step > 0 or not m().started():
		return
	var bs: Array = m().aliens().filter(func(a): return a.race == "bijec")
	if bs.is_empty():
		if not has_meta("bij_spawned"):
			set_meta("bij_spawned", true)
			m().spawn_alien("bijec", p.global_position + Vector3(0, 0.3, 14))
		return
	step = 1
	var b: Node = bs[0]
	b.state = b.S.COMBAT
	var t0: float = b.taken(10.0)
	b.damage(float(b.R["hp"]) * 0.7 / float(b.R["armor"]), b.global_position + Vector3(0, 1, 2), null)
	await get_tree().create_timer(0.3).timeout
	out("RESULT bijtest broken %s flinch %s taken %.1f -> %.1f alive %s" % [b.armor_broken, b._flinch_t > 0.0, t0, b.taken(10.0), not b.dead])
	get_tree().quit()

## Levit Mírotvůrce: the Levits near it go berserk; badly hurt it pulls back and heals.
func _mirotest(p: Node) -> void:
	_skip_brief()
	if p == null or step > 0 or not m().started():
		return
	var ms: Array = m().aliens().filter(func(a): return a.race == "levit_velitel")
	var ls: Array = m().aliens().filter(func(a): return a.race == "levit")
	if ms.is_empty() or ls.is_empty():
		# (not every crew has both: bring in what is missing, once)
		if not has_meta("miro_spawned"):
			set_meta("miro_spawned", true)
			var at: Vector3 = p.global_position + Vector3(0, 0.3, 14)
			if ms.is_empty():
				m().spawn_alien("levit_velitel", at)
			if ls.is_empty():
				m().spawn_alien("levit", at + Vector3(3, 0, 0))
		return
	step = 1
	p.hp = 999.0
	var mv: Node = ms[0]
	var lv: Node = ls[0]
	lv.global_position = mv.global_position + Vector3(3, 0, 0)
	var r0: float = lv.run_spd
	mv._enter_combat(null)
	lv._enter_combat(null)
	await get_tree().create_timer(2.5).timeout
	var fr: bool = lv._frenzy
	var r1: float = lv.run_spd
	mv.damage(float(mv.R["hp"]) * 0.7 / float(mv.R["armor"]), mv.global_position + Vector3(0, 1, 2), null)
	var hp0: float = mv.hp
	var mending: bool = mv._mending
	await get_tree().create_timer(9.0).timeout
	out("RESULT mirotest frenzy %s run %.1f -> %.1f mending %s hp %.0f -> %.0f healed %s" % [fr, r0, r1, mending, hp0, mv.hp, mv.hp > hp0 + 10.0])
	get_tree().quit()

## Flickering surfaces: two boxes whose faces lie in the same plane and overlap (z-fighting).
## Lists them with sizes and materials, so the map code can be fixed.
func _zfight(p: Node) -> void:
	if p == null or step > 0:
		return
	step = 1
	var boxes := []
	for mi in m().find_children("*", "MeshInstance3D", true, false):
		var mm := mi as MeshInstance3D
		if not mm.is_visible_in_tree() or mm.mesh == null:
			continue
		if not (mm.mesh is BoxMesh or mm.mesh is PlaneMesh or mm.mesh is QuadMesh or mm.mesh is CylinderMesh):
			continue
		var yaw := fposmod(mm.global_rotation.y, PI / 2.0)
		if minf(yaw, PI / 2.0 - yaw) > 0.01 or absf(mm.global_rotation.x) > 0.01 or absf(mm.global_rotation.z) > 0.01:
			continue
		var bb: AABB = mm.global_transform * mm.get_aabb()
		var mat_name := ""
		var mat: Material = mm.material_override if mm.material_override else (mm.mesh.surface_get_material(0) if mm.mesh.get_surface_count() > 0 else null)
		if mat: mat_name = mat.resource_name if mat.resource_name != "" else str(mat.get_instance_id())
		boxes.append([bb, mm, mat_name])
	var cell := {}
	for i in boxes.size():
		var bb: AABB = boxes[i][0]
		for cx in range(int(floor(bb.position.x / 8.0)), int(floor(bb.end.x / 8.0)) + 1):
			for cz in range(int(floor(bb.position.z / 8.0)), int(floor(bb.end.z / 8.0)) + 1):
				var k := Vector2i(cx, cz)
				if not cell.has(k): cell[k] = []
				cell[k].append(i)
	var seen := {}
	var hits := []
	var E := 0.004
	for k in cell:
		var lst: Array = cell[k]
		for ai in lst.size():
			for bi in range(ai + 1, lst.size()):
				var a: int = lst[ai]
				var b: int = lst[bi]
				var key := Vector2i(mini(a, b), maxi(a, b))
				if seen.has(key): continue
				seen[key] = true
				var A: AABB = boxes[a][0]
				var B: AABB = boxes[b][0]
				var why := ""
				# same top face (both seen from above)
				if absf(A.end.y - B.end.y) < E and _ov(A.position.x, A.end.x, B.position.x, B.end.x) * _ov(A.position.z, A.end.z, B.position.z, B.end.z) > 0.02:
					why = "vrch"
				elif absf(A.position.y - B.position.y) < E and A.position.y > 0.05 and _ov(A.position.x, A.end.x, B.position.x, B.end.x) * _ov(A.position.z, A.end.z, B.position.z, B.end.z) > 0.02:
					why = "spodek"
				else:
					var oy := _ov(A.position.y, A.end.y, B.position.y, B.end.y)
					for pr in [[A.position.x, B.position.x, "x"], [A.end.x, B.end.x, "x"], [A.position.z, B.position.z, "z"], [A.end.z, B.end.z, "z"]]:
						if absf(pr[0] - pr[1]) < E:
							var o2: float = _ov(A.position.z, A.end.z, B.position.z, B.end.z) if pr[2] == "x" else _ov(A.position.x, A.end.x, B.position.x, B.end.x)
							if oy * o2 > 0.05:
								why = "bok " + pr[2]
								break
				if why != "" and boxes[a][2] != boxes[b][2]:
					hits.append("%s @%s: %s %s [%s] / %s %s [%s]" % [why, str(A.get_center().snapped(Vector3.ONE * 0.1)),
						(boxes[a][1] as Node).get_parent().name, str(A.size.snapped(Vector3.ONE * 0.01)), boxes[a][2], (boxes[b][1] as Node).get_parent().name, str(B.size.snapped(Vector3.ONE * 0.01)), boxes[b][2]])
	var kinds := {}
	for h in hits:
		var sig: String = h.split(": ")[1].replace(h.split(": ")[1].split(" ")[0], "")
		kinds[sig] = kinds.get(sig, 0) + 1
	for h in hits.slice(0, 40):
		out("[Z] " + h)
	out("RESULT zfight %d boxes, %d flicker pairs" % [boxes.size(), hits.size()])
	get_tree().quit()

func _ov(a0: float, a1: float, b0: float, b1: float) -> float:
	return maxf(0.0, minf(a1, b1) - maxf(a0, b0))

## Time of day: one look towards the sun/moon, one away from it.
func _skyshot(p: Node) -> void:
	_skip_brief()
	if p == null or step > 0 or not m().started():
		return
	step = 1
	m().hud.inventory_open = false
	for a in m().aliens():
		a.set_physics_process(false)
	p.hp = 999.0
	p.light_on = Game.cmd_arg("light", "0") == "1"
	var ev: Vector3 = m().map["evac"]
	var nav_map: RID = m().get_world_3d().navigation_map
	p.global_position = NavigationServer3D.map_get_closest_point(nav_map, ev + Vector3(float(Game.cmd_arg("ox", "14")), 0, float(Game.cmd_arg("oz", "-14")))) + Vector3(0, 0.3, 0)
	var look := Game.cmd_arg("look", "")
	if look != "" and m().map.has(look):
		var tp: Vector3 = m().map[look]
		var off := Vector3(float(Game.cmd_arg("lx", "7")), 0, float(Game.cmd_arg("lz", "6")))
		p.global_position = NavigationServer3D.map_get_closest_point(nav_map, tp + off) + Vector3(0, 0.3, 0)
		for i in 40:
			await get_tree().create_timer(0.1).timeout
			if m().hud._brief_t < 0:
				break
		await get_tree().create_timer(0.5).timeout
		_aim_at(p, tp + Vector3(0, 0.8, 0))
		await get_tree().create_timer(0.8).timeout
		if DisplayServer.get_name() != "headless":
			_snap("look_" + look)
		out("RESULT look %s at %s" % [look, tp])
		get_tree().quit()
		return
	await get_tree().create_timer(2.5).timeout
	var tag := "%s_%s" % [m().phase(), m().weather]
	var to_light: Vector3 = m().moon.global_transform.basis.z      # towards the light source
	_aim_at(p, p.global_position + Vector3(0, 1.6, 0) + Vector3(to_light.x, maxf(to_light.y, 0.25), to_light.z) * 20.0)
	await get_tree().create_timer(0.6).timeout
	if DisplayServer.get_name() != "headless":
		_snap("sky_%s_sun" % tag)
	_aim_at(p, p.global_position + Vector3(0, 1.2, 0) - Vector3(to_light.x, 0, to_light.z) * 20.0)
	await get_tree().create_timer(0.6).timeout
	if DisplayServer.get_name() != "headless":
		_snap("sky_%s_away" % tag)
	if Game.cmd_arg("nvg", "0") == "1":
		p.inv["p5"] = {"id": "nvg"}
		Input.action_press("nvg")
		await get_tree().physics_frame
		await get_tree().physics_frame
		Input.action_release("nvg")
		await get_tree().create_timer(0.6).timeout
		out("nvg on %s" % m().nvg_on)
		if DisplayServer.get_name() != "headless":
			_snap("sky_%s_nvg" % tag)
		out("RESULT skyshot %s hour %.1f light %.2f" % [tag, m().hour(), m().moon.light_energy])
	get_tree().quit()

## Job done -> Enter anywhere ends the mission (no walk back to the ship).
func _leaveany(p: Node) -> void:
	_skip_brief()
	if p == null or step > 0 or not m().started():
		return
	step = 1
	m().hud.inventory_open = false
	for i in 40:
		await get_tree().create_timer(0.25).timeout
		if m().aliens_total > 0:
			break
	var ev: Vector3 = m().map["evac"]
	var nav_map: RID = m().get_world_3d().navigation_map
	var spot: Vector3 = NavigationServer3D.map_get_closest_point(nav_map, ev + Vector3(25, 0, 25))
	p.global_position = spot + Vector3(0, 0.3, 0)
	p.velocity = Vector3.ZERO
	await get_tree().create_timer(0.5).timeout
	var far: float = p.global_position.distance_to(ev)
	Input.action_press("ready")
	await get_tree().physics_frame
	Input.action_release("ready")
	await get_tree().create_timer(0.5).timeout
	out("before: done %s, wants_evac %s (should be false), %.0f m from the ship" % [m().objective_done(), p.wants_evac, far])
	var early: bool = p.wants_evac
	for i in 40:
		for a in m().aliens():
			if not a.dead:
				a.damage(9999.0, a.global_position + Vector3(0, 0, 1), p)
		await get_tree().create_timer(0.25).timeout
		if m().objective_done():
			break
	out("aliens dead (%d alive, %d total, type %s), done %s" % [m().alive_aliens(), m().aliens_total, m().mtype(), m().objective_done()])
	Input.action_press("ready")
	await get_tree().physics_frame
	Input.action_release("ready")
	for i in 20:
		await get_tree().create_timer(0.25).timeout
		if m().finished:
			break
	out("RESULT leaveany early_block %s done %s finished %s far %.0f" % [not early, m().objective_done(), m().finished, far])
	get_tree().quit()

func _climb(p: Node) -> void:
	_skip_brief()
	if p == null or step > 0 or not m().started():
		return
	step = 1
	m().hud.inventory_open = false
	for a in m().aliens():
		a.set_physics_process(false)
	var results := []
	for hgt in [2.0, 2.9]:
		var base: Vector3 = p.global_position + Vector3(0, 30, 0)     # up in the sky: nothing else around
		var floor_b: Node = m().map_box(base + Vector3(0, -0.5, 0), Vector3(12, 1, 12))
		var blk: Node = m().map_box(base + Vector3(0, hgt / 2.0, -2.0), Vector3(4, hgt, 2))
		p.global_position = base + Vector3(0, 0.05, -0.6)
		p.rotation.y = 0.0
		p.velocity = Vector3.ZERO
		for f in 6: await get_tree().physics_frame
		if hgt < 2.5:
			Input.action_press("jump")
			await get_tree().physics_frame
			Input.action_release("jump")
		else:
			Input.action_press("jump")
			for f in 40: await get_tree().physics_frame
			Input.action_release("jump")
		await get_tree().create_timer(1.2).timeout
		var up: float = p.global_position.y - base.y
		results.append(up)
		out("climb %.1f m block: feet now %.2f m up" % [hgt, up])
		floor_b.queue_free()
		blk.queue_free()
		await get_tree().physics_frame
	# a house: under the eaves, jump and hold Space - onto the roof
	var roof_ok := true
	var hv: Vector3 = m().map.get("house", Vector3.ZERO)
	if hv != Vector3.ZERO:
		var c := hv - Vector3(3.6, 0, -1.5)     # the house's corner (map_gen: house = c + (3.6, 0, -1.5))
		p.global_position = c + Vector3(6.0, 0.3, -0.45)
		p.rotation.y = PI                      # facing +z, the long north wall
		p.velocity = Vector3.ZERO
		for f in 40: await get_tree().physics_frame
		var y0: float = p.global_position.y
		Input.action_press("jump")
		for f in 40: await get_tree().physics_frame
		Input.action_release("jump")
		await get_tree().create_timer(1.2).timeout
		out("house roof: feet %.2f m up (from %.2f)" % [p.global_position.y - y0, y0])
		roof_ok = p.global_position.y - y0 > 2.6
		get_viewport().get_texture().get_image().save_png("user://climb_roof.png") if DisplayServer.get_name() != "headless" else null
	out("RESULT climb %s" % ("ok" if absf(results[0] - 2.0) < 0.3 and absf(results[1] - 2.9) < 0.3 and roof_ok else "FAIL"))
	get_tree().quit()

## Rescue spots: a person standing there must fit - nothing solid in the body, no roof through the head.
func _vipcheck(p: Node) -> void:
	_skip_brief()
	if p == null or step > 0 or not m().go:
		return
	step = 1
	await get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = 0.25
	cap.height = 1.6
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.collision_mask = 1 | 64 | 128
	var roofs := []
	for mi in m().find_children("*", "MeshInstance3D", true, false):
		var n := String(mi.name).to_lower() + String(mi.get_parent().name).to_lower()
		if "roof" in n and mi.is_visible_in_tree():
			var bb0: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			# the eaves are at the roof's origin (a downpipe may hang lower, that is not the roof)
			var eaves: float = (mi.get_parent() as Node3D).global_position.y - 0.3 if mi.get_parent() is Node3D else bb0.position.y
			if bb0.position.y < eaves:
				bb0 = AABB(Vector3(bb0.position.x, eaves, bb0.position.z), Vector3(bb0.size.x, bb0.end.y - eaves, bb0.size.z))
			roofs.append(bb0)
	var bad := 0
	var spots: Array = m().map.get("vip_spots", [])
	var nm: RID = p.get_world_3d().navigation_map
	for sp0 in spots:
		var errs := []
		# (as the game does at spawn: onto the nearest walkable ground)
		var sp: Vector3 = sp0
		var snap := NavigationServer3D.map_get_closest_point(nm, sp0)
		if snap.distance_to(sp0) < 3.0:
			sp = snap + Vector3(0, 0.3, 0)
		sp = m().free_spot(sp)
		q.transform = Transform3D(Basis(), (sp as Vector3) + Vector3(0, 0.65, 0))   # (sp is 0.3 above the floor)
		for h in space.intersect_shape(q, 4):
			var cn: Node = h["collider"]
			var sz := ""
			for ch in cn.get_children():
				if ch is CollisionShape3D and (ch as CollisionShape3D).shape is BoxShape3D:
					sz = str(((ch as CollisionShape3D).shape as BoxShape3D).size)
			errs.append("v těle: %s %s @%s" % [cn.name, sz, str(snapped((cn as Node3D).global_position, Vector3(0.1, 0.1, 0.1)))])
		for rb in roofs:
			var bb: AABB = rb
			# standing at the eaves' height or higher, inside the roof's footprint: in the roof
			var inside := Rect2(bb.position.x + 0.2, bb.position.z + 0.2, bb.size.x - 0.4, bb.size.z - 0.4).has_point(Vector2(sp.x, sp.z))
			if inside and sp.y > bb.position.y - 0.4 and sp.y < bb.end.y:
				errs.append("hlava ve střeše")
				break
		if not errs.is_empty():
			bad += 1
			out("[VIP] %s: %s" % [str(snapped(sp, Vector3(0.1, 0.1, 0.1))), errs])
	out("RESULT vipcheck %d spots, %d bad" % [spots.size(), bad])
	get_tree().quit()

## A Levit shot out of the air falls to the ground (and does not hang up there).
func _airdeath(p: Node) -> void:
	_skip_brief()
	if p == null or step > 0 or not m().go or m().hud._brief_t >= 0:
		return
	step = 1
	p.set_physics_process(false)
	p.hp = 5000.0
	var lv: Node = null
	for a in m().aliens():
		if String(a.race).begins_with("levit"):
			lv = a
			break
	if lv == null:
		out("RESULT airdeath no levit"); get_tree().quit(); return
	lv._jet_to(lv.global_position + Vector3(30, 0, 0))
	await get_tree().create_timer(1.2).timeout
	var y0: float = lv.global_position.y
	lv.damage(9999.0, lv.global_position + Vector3(0, 0, 3), p)
	for k in 8:
		await get_tree().create_timer(0.5).timeout
		out("  y %.2f vel %.2f floor %s flying %s airborne %s" % [lv.global_position.y, lv.velocity.y, lv.is_on_floor(), lv.flying, lv.airborne])
	var q := PhysicsRayQueryParameters3D.create(lv.global_position + Vector3.UP * 0.5, lv.global_position + Vector3.DOWN * 40.0, 1)
	var hit: Dictionary = lv.get_world_3d().direct_space_state.intersect_ray(q)
	var gap: float = lv.global_position.y - (hit.position.y if not hit.is_empty() else 0.0)
	out("levit died at y %.1f, 4 s later %.1f above the ground (dead %s)" % [y0, gap, lv.dead])
	out("RESULT airdeath %s" % ("ok" if gap < 0.6 else "VISÍ"))
	get_tree().quit()

## Solo helper drone: it is there, it heals to half, it brings the man back once - and only once;
## the aliens do not notice anybody by the ship in the first moments.
func _dronetest(p: Node) -> void:
	_skip_brief()
	if p == null or step > 0 or not m().go or m().hud._brief_t >= 0:
		return
	step = 1
	m().hud.inventory_open = false
	for a in m().aliens():
		a.set_physics_process(false)
	await get_tree().create_timer(1.0).timeout
	var d: Node = m().guard_drone
	out("drone %s solo %s safe-at-ship %s" % [d != null, m().solo(), m().landing_safe(p)])
	# a look at it from the side
	var cam := Camera3D.new()
	m().add_child(cam)
	cam.global_position = p.global_position + p.global_transform.basis * Vector3(2.2, 2.3, -1.6)
	cam.look_at(d.global_position if d else p.global_position + Vector3.UP * 2.0)
	cam.make_current()
	for f in 20: await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		get_viewport().get_texture().get_image().save_png("user://drone_0.png")
	cam.queue_free()
	p.cam.make_current()
	p.hp = 3.0
	await get_tree().create_timer(4.0).timeout
	out("heal 3 -> %.1f (cap %.1f)" % [p.hp, p.max_hp * 0.5])
	p.hp = 0.0
	p.downed = true
	await get_tree().create_timer(5.0).timeout
	out("first fall: downed %s hp %.1f finished %s charge %d" % [p.downed, p.hp, m().finished, d.charge])
	p.hp = 0.0
	p.downed = true
	await get_tree().create_timer(3.0).timeout
	out("second fall: finished %s" % m().finished)
	out("RESULT dronetest")
	get_tree().quit()

## The sound of every kind of place: what plays as wind, what as the bed, whether animals call.
## Rules: indoors (our base, the alien base) no wind, no crickets, no owls; Mars and snow no
## crickets; outdoor missions have their wind.
func _soundcheck(p: Node) -> void:
	_skip_brief()
	if p == null or step > 0 or not m().go:
		return
	step = 1
	var keep_params: Dictionary = Net.mission_params
	var keep_terr = m().map.get("terrain", "")
	var outdoor := ["wind", "wind_forest", "mountain", "polar", "mars", "night_silence", "night_field", "town_night", "industrial"]
	var cases := [
		["základna (procházka)", {"type": "home", "base": []}, "base"],
		["útok na základnu", {"type": "base", "base": [], "biome": "base"}, "base"],
		["obrana (rychlá mise)", {"type": "base", "biome": "base"}, "temperate"],
		["základna vetřelců", {"type": "alienbase", "biome": "alienbase"}, "alienbase"],
		["statek", {"type": "crash", "biome": "farm"}, "temperate"],
		["městečko", {"type": "terror", "biome": "town"}, "temperate"],
		["les", {"type": "landed", "biome": "forest"}, "temperate"],
		["hory se sněhem", {"type": "rescue", "biome": "mountain"}, "snow"],
		["průmysl", {"type": "sabotage", "biome": "industrial"}, "temperate"],
		["poušť", {"type": "landed", "biome": "desert"}, "desert"],
		["polár", {"type": "sabotage", "biome": "polar"}, "snow"],
		["Mars", {"type": "mars", "biome": "mars"}, "mars"],
	]
	var bad := 0
	for c in cases:
		Net.mission_params = c[1]
		m().map["terrain"] = c[2]
		var wind: String = m()._wind_name()
		var bed: String = m()._ambient_bed()
		var crit: bool = m().critters_here()
		var inside: bool = m().indoor() or String(c[1]["type"]) == "alienbase"
		var errs := []
		if inside and wind in outdoor and wind != "base_interior": errs.append("venkovní vítr uvnitř")
		if inside and bed in ["night_field", "town_night"]: errs.append("cvrčci/město uvnitř")
		if inside and crit: errs.append("zvířata uvnitř")
		if c[2] in ["mars", "snow"] and bed == "night_field": errs.append("cvrčci na sněhu/Marsu")
		if c[2] == "mars" and crit: errs.append("zvířata na Marsu")
		if not inside and wind == "base_interior": errs.append("venku hučí základna")
		for snd in [wind, bed]:
			if snd != "" and not ResourceLoader.exists("res://assets/sounds/%s.wav" % snd): errs.append("chybí zvuk " + snd)
		if not errs.is_empty(): bad += 1
		out("[SND] %-22s vítr=%-14s podklad=%-14s zvířata=%s %s" % [c[0], wind, bed if bed != "" else "-", "ano" if crit else "ne", ("CHYBA: " + ", ".join(errs)) if not errs.is_empty() else "ok"])
	Net.mission_params = keep_params
	m().map["terrain"] = keep_terr
	out("RESULT soundcheck %d chyb" % bad)
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
	for a in m().aliens():
		a.set_physics_process(false)       # (nobody shoves a door while we measure)
	await get_tree().create_timer(1.0).timeout
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
			if String(wy["what"]).begins_with("dveře"):
				var di := int(String(wy["what"]).substr(6))
				var dd: Dictionary = m().doors[di]
				out("   door: base %.2f now %.2f pivot %s spec %s" % [float(dd["base"]), (dd["pivot"] as Node3D).rotation.y, str(snapped((dd["pivot"] as Node3D).global_position, Vector3(0.1, 0.1, 0.1))), str(m().map["doors"][di])])
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
