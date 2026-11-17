extends RefCounted
## shouldershot (Ari 2026-11-16: „vojáci nemají pušku opřenou o rameno a při střelbě to nevypadá
## nejlépe“): kamarád (vzdálený hráč) s puškou v různých polohách (stojí, míří, střílí, jde a
## střílí, v kleku míří a střílí, míří nahoru a dolů). Pro každou vypíše, jak daleko je konec pažby
## od pravého ramene (`[SHOULDER] <poloha> stock_to_shoulder=… m  barrel_vs_aim=…°`) a uloží snímky
## zboku a zepředu (`shoulder_<poloha>_side/front.png`). `--guns=rifle,laser_rifle,…`

const STATES := [
	# name, aiming, firing, pitch, crouching, speed (m/s forward)
	["idle", false, false, 0.0, false, 0.0],
	["aim", true, false, 0.0, false, 0.0],
	["fire", true, true, 0.0, false, 0.0],
	["aim_up", true, false, 0.45, false, 0.0],
	["aim_down", true, false, -0.4, false, 0.0],
	["fire_walk", true, true, 0.0, false, 1.4],
	["run", false, false, 0.0, false, 4.2],
	["run_aim", true, false, 0.0, false, 4.2],
	["run_fire", true, true, 0.0, false, 4.2],
	["crouch_aim", true, false, 0.0, true, 0.0],
	["crouch_fire", true, true, 0.0, true, 0.0],
]

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
	var guns: Array = Game.cmd_arg("guns", "rifle").split(",")
	var start: Vector3 = m.free_spot(m.map["evac"] + Vector3(6, 0.3, -6))
	p.global_position = start + Vector3(0, 0, 30)
	p.body.visible = false
	var data := {"kind": "player", "peer": 7, "pos": start, "yaw": 0.0,
		"merc": m.roster()[p.get_multiplayer_authority()]["merc"], "name": "Kamarad"}
	var mate: Node = m._spawn(data)
	m.actors.add_child(mate)
	mate.set_physics_process(false)      # driven here, frame by frame
	var cam := Camera3D.new()
	m.add_child(cam)
	cam.fov = 40.0
	cam.current = true
	var tot := 0.0
	var n := 0
	for gun in guns:
		mate.held = gun
		var only: Array = Game.cmd_arg("states", "").split(",", false)
		for st in STATES:
			if not only.is_empty() and not st[0] in only:
				continue
			mate.aiming = st[1]
			mate.pitch = st[3]
			mate.crouching = st[4]
			var t := 0.0
			var worst := 0.0
			var sum := 0.0
			var cnt := 0
			var ang := 0.0
			var base: Vector3 = mate.global_position
			while t < 1.6:
				var dt: float = at.get_physics_process_delta_time()
				await at.get_tree().physics_frame
				t += dt
				if st[5] > 0.0:
					mate.global_position += -mate.global_transform.basis.z * float(st[5]) * dt
				if st[2] and fmod(t, 0.16) < dt:
					mate._fired_at = Time.get_ticks_msec() / 1000.0
				mate._remote_visuals()
				if t > 0.8:
					var r: Array = measure(mate)
					if r.is_empty():
						continue
					worst = maxf(worst, r[0])
					sum += r[0]
					ang += r[1]
					cnt += 1
			var avg := sum / maxf(1, cnt)
			if st[1]:      # (the mean: only where he aims or shoots - carrying it is the movement's)
				tot += avg
				n += 1
			at.out("[SHOULDER] %s %s mode=%s stock_to_shoulder=%.3f worst=%.3f barrel_vs_aim=%.1f" % [gun, st[0], mate._hold_mode(), avg, worst, ang / maxf(1, cnt)])
			if Game.cmd_arg("snaps", "1") != "0":
				var c: Vector3 = mate.global_position + Vector3(0, 1.3 if not st[4] else 0.95, 0)
				var fw: Vector3 = -mate.global_transform.basis.z
				var rt: Vector3 = mate.global_transform.basis.x
				for view in ["side", "front", "back"]:
					if view == "side":
						cam.global_position = c + rt * 2.6 + fw * 0.2
					elif view == "front":
						cam.global_position = c + fw * 2.6 + rt * 1.0 + Vector3(0, 0.2, 0)
					else:
						cam.global_position = c - fw * 2.2 + rt * 0.9 + Vector3(0, 0.35, 0)
					cam.look_at(c - Vector3(0, 0.1, 0) + fw * 0.2, Vector3.UP)
					await RenderingServer.frame_post_draw
					at._snap("shoulder_%s_%s_%s" % [gun, st[0], view])
			mate.global_position = start
	at.out("RESULT shouldershot mean %.3f" % (tot / maxf(1, n)))
	at.get_tree().quit()

## [distance of the butt from the right shoulder (m), angle between the barrel and the aim (deg)]
static func measure(p: Node) -> Array:
	var sk: Skeleton3D = p._sk
	if sk == null or p.body_gun == null or p.body_gun.get_child_count() == 0:
		return []
	var ui := sk.find_bone("upperarm.R")
	if ui < 0:
		return []
	var sh: Vector3 = (sk.global_transform * sk.get_bone_global_pose(ui)).origin
	var g: Node3D = p.body_gun.get_child(0)
	var butt: Vector3 = p.stock_point(g)
	var muzzle_dir: Vector3 = -(g.global_transform.basis.z).normalized()
	var aim: Vector3 = p.aim_dir()
	return [butt.distance_to(sh), rad_to_deg(muzzle_dir.angle_to(aim))]

## radiosprint (Ari: „když sprintuješ a zmáčkneš vysílačku, hráč vytáhne třetí ruku“): vlastní
## voják s puškou sprintuje a drží T. Z očí: kolik rukou je vidět (`[RADIO] grip_two … radio …`),
## snímky radio_sprint_N.png.
static func radio(at: Node, p: Node) -> void:
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
	p.hp = 9999.0
	var radio_slot := ""
	for s in ["b0", "b1", "b2", "b3"]:
		if not p.inv.has(s):
			radio_slot = s
			break
	p.inv[radio_slot] = {"id": "radio"}
	await at.get_tree().create_timer(0.5).timeout
	Input.action_press("sprint")
	Input.action_press("move_forward")
	await at.get_tree().create_timer(0.8).timeout
	Input.action_press("radio_talk")
	var bad := 0
	for i in 6:
		await at.get_tree().create_timer(0.25).timeout
		var g2: Node3D = p.gun.get_node_or_null("GripTwo")
		var two_on := g2 != null and g2.is_visible_in_tree()
		var r_on := false
		for c in p.find_children("*", "Node3D", true, false):
			if String(c.name).to_lower().contains("radio") and (c as Node3D).is_visible_in_tree() and p.cam.is_ancestor_of(c):
				r_on = true
		if two_on and r_on:
			bad += 1
		at.out("[RADIO] t %d sprint %s radio_up %s held_l %s grip_two %s lower %.2f" % [i, p.sprinting, p.radio_up, p.held_l, two_on, p._radio_lower])
		await RenderingServer.frame_post_draw
		at._snap("radio_sprint_%d" % i)
	Input.action_release("radio_talk")
	Input.action_release("sprint")
	Input.action_release("move_forward")
	at.out("RESULT radiosprint three_hands %d" % bad)
	at.get_tree().quit()
