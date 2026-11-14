extends RefCounted
## spectate (0.70+, Ari: „po smrti sledovat posledního přeživšího“): do mise přibudou dva kamarádi
## (jako vzdálení hráči), vlastní voják zemře. Po chvíli se zapne divácký pohled (scripts/spectator.gd):
## kamera za zády kamaráda, Mezerník = z jeho očí (jeho tělo pro kameru skryté), LTM = další,
## smrt sledovaného = po chvíli sám na dalšího živého. Mise mezitím běží dál (žijí). Snímky spect_N.png.

static func _press(at: Node, action: String) -> void:
	await at.get_tree().process_frame       # (pressed before the nodes' _process of this frame)
	Input.action_press(action)
	await at.get_tree().process_frame
	await at.get_tree().process_frame
	Input.action_release(action)
	await at.get_tree().process_frame

static func run(at: Node, p: Node) -> void:
	if p == null: return
	at._skip_brief()
	if at.step > 0 or not at.m().started(): return
	at.step = 1
	var m: Node = at.m()
	m.hud.inventory_open = false
	for a in m.aliens():
		a.set_physics_process(false)
		a.visible = false
		a.global_position += Vector3(0, -200, 0)
	var start: Vector3 = m.free_spot(m.map["evac"] + Vector3(6, 0.3, -6))
	p.global_position = start
	var mates := []
	for i in 2:
		var data := {"kind": "player", "peer": 7 + i, "pos": m.free_spot(start + Vector3(2.0 + i * 2.0, 0.3, -1.5)), "yaw": 0.4 * i,
			"merc": m.roster()[p.get_multiplayer_authority()]["merc"], "name": "Kamarad%d" % (i + 1)}
		var mate: Node = m._spawn(data)
		m.actors.add_child(mate)
		mates.append(mate)
	await at.get_tree().create_timer(0.5).timeout
	# the own merc dies
	p.hp = 0.0
	p.downed = true
	p.bleed_left = 0.01
	await at.get_tree().create_timer(0.5).timeout
	var early: bool = p.spectator != null and p.spectator.active()
	await at.get_tree().create_timer(Spectator.DELAY + 0.6).timeout
	var sp: Node = p.spectator
	var active: bool = sp != null and sp.active() and sp.cam.current
	at.out("[SPECT] dead %s early %s active %s target %s dist %.2f body %s" % [p.dead, early, active, sp.target.name if sp and sp.target else "-",
		sp.cam.global_position.distance_to(sp.target.global_position) if active else -1.0, p.body.visible])
	await RenderingServer.frame_post_draw
	at._snap("spect_0")
	# from his eyes
	await _press(at, "jump")
	await at.get_tree().create_timer(0.4).timeout
	var eyes: bool = sp.eyes
	var hidden: int = sp._hidden.size()
	var eye_d: float = sp.cam.global_position.distance_to(sp.target.global_position + Vector3(0, 1.62, 0))
	await RenderingServer.frame_post_draw
	at._snap("spect_1")
	await _press(at, "jump")
	var back: bool = not sp.eyes and sp._hidden.is_empty()
	# next one
	var t0: Node = sp.target
	await _press(at, "fire")
	var nxt: bool = sp.target != t0 and sp.target in mates
	# the watched one dies -> after a while the other living one
	var t1: Node = sp.target
	t1.dead = true
	await at.get_tree().create_timer(Spectator.SWITCH_AFTER + 0.6).timeout
	var auto: bool = sp.target != t1 and not sp.target.dead
	await RenderingServer.frame_post_draw
	at._snap("spect_2")
	at.out("[SPECT] eyes %s hidden %d eye_d %.2f back %s next %s auto %s finished %s" % [eyes, hidden, eye_d, back, nxt, auto, m.finished])
	at.out("RESULT spectate active %s eyes %s next %s auto %s running %s" % [active and not early, eyes and hidden > 0 and eye_d < 0.4, nxt, auto, not m.finished])
	at.get_tree().quit()
