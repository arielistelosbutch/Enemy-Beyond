extends "res://scripts/alien.gd"
## Machines. They do not hide and do not tire; the baton only sparks on them;
## when they are destroyed they blow apart.
##  Diskoll - a fast flying disc that escorts the greys. Quick, very precise
##            bursts (not one-shot kills). Plasma and explosions cut through it.
##  Kolos   - a huge armoured spider on eight legs, almost silent: two rotary plasma guns
##            under the head fire bursts, the cannon on top a heavy bolt every few seconds.
##            It climbs walls onto roofs to fire from above, and comes down again.

var hum: AudioStreamPlayer3D
var _cannon_t := 6.0
var _gait := 0.0

func setup(data: Dictionary) -> void:
	super.setup(data)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.2, 0.1) if race == "kolos" else Color(0.3, 0.9, 1.0)
	l.light_energy = 0.8
	l.omni_range = 4.0
	l.position = Vector3(0, float(R.get("hover", 0.0)) + (2.0 if race == "kolos" else 0.0), -0.8)
	body.add_child(l)

func _ready() -> void:
	super._ready()
	hum = AudioStreamPlayer3D.new()
	hum.stream = Game.loop_stream("drone_hover") if race == "diskoll" else Game.sound("hum")
	hum.volume_db = -8.0 if race == "diskoll" else -30.0     # (the Kolos moves almost without a sound)
	hum.pitch_scale = 1.3 if race == "diskoll" else 0.7
	hum.max_distance = 30.0
	hum.unit_size = 3.0
	hum.bus = "SFX"
	add_child(hum)
	hum.play()
	hum.finished.connect(func(): if not dead: hum.play())

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if dead:
		if hum and hum.playing:
			hum.stop()
		return
	var ring := _part("Ring")
	if ring:
		ring.rotation.y += delta * (3.0 + _speed)
	if race == "kolos":
		# the legs stepping in turn (eight: two alternating sets of four, like a spider)
		var spd := 3.0 if flying else clampf(_speed, 0.0, 4.5)
		_gait += delta * spd * 2.4
		var moving := 1.0 if flying else clampf(_speed, 0.0, 1.0)
		var n := 8 if _part("Leg7") else 3
		for i in n:
			var leg := _part("Leg%d" % i)
			if leg:
				var ph := _gait + ((PI * float((i / 2 + i) % 2)) if n == 8 else i * TAU / 3.0)
				leg.rotation.y = sin(ph) * 0.18 * moving
				leg.rotation.z = maxf(0.0, cos(ph)) * 0.14 * moving * (1.0 if i % 2 == 0 else -1.0)
		# on a wall: belly to the wall, head up, legs gripping it
		var on_wall := flying and not _jet.is_empty() and _wall_n != Vector3.ZERO \
				and Vector2((_jet[0] as Vector3).x - global_position.x, (_jet[0] as Vector3).z - global_position.z).length() < 0.3 \
				and absf((_jet[0] as Vector3).y - global_position.y) > 0.3
		body.rotation.x = lerp_angle(body.rotation.x, PI / 2.0 if on_wall else 0.0, delta * 5.0)
		if on_wall:
			rotation.y = lerp_angle(rotation.y, atan2(_wall_n.x, _wall_n.z), delta * 8.0)
		var hull := _part("Hull")
		if hull:
			hull.position.y = -absf(sin(_gait * 1.5)) * 0.05 * moving
		var turret := _part("Turret")
		if turret:
			var want := 0.0
			if alert and is_instance_valid(target):
				var to: Vector3 = global_transform.affine_inverse() * target.global_position
				want = atan2(-to.x, -to.z)
			turret.rotation.y = lerp_angle(turret.rotation.y, want, delta * 2.0)

func _think(delta: float) -> void:
	super._think(delta)
	if race == "diskoll" and not dead:
		_scan(delta)
	if race != "kolos" or dead:
		return
	if R.has("climb"):
		_climb_tick(delta)
	# roof cannon: a heavy bolt at whatever it is fighting, every few seconds
	_cannon_t -= delta
	if _cannon_t <= 0 and state == S.COMBAT and is_instance_valid(target) and not target.dead and visible_to(target):
		_cannon_t = rng.randf_range(5.0, 8.0)
		var tgt: Vector3 = target.global_position + Vector3(0, 1.0, 0)
		var miss := 0.4 + global_position.distance_to(tgt) * 0.03
		tgt += Vector3(rng.randf_range(-miss, miss), rng.randf_range(-miss, miss) * 0.5, rng.randf_range(-miss, miss))
		var from := global_position + Vector3(0, 2.75, 0) - global_transform.basis.z * 1.0
		_plasma.rpc(from, (tgt - from).normalized(), 2.0, "plasma")

## Kolos: up a wall onto a roof to fire from above - and, after a while, down again somewhere else.
var _climb_cd := 10.0
var _wall_top := Vector3.INF
var _wall_base := Vector3.INF
var _wall_n := Vector3.ZERO
func _climb_tick(delta: float) -> void:
	_climb_cd -= delta
	if flying or _climb_cd > 0.0 or state != S.COMBAT or not is_instance_valid(target) or target.dead:
		return
	_climb_cd = rng.randf_range(14.0, 22.0)
	if airborne:
		_climb_down()
	else:
		_climb_up(target.global_position)

func _climb_up(at: Vector3) -> bool:
	var ss := get_world_3d().direct_space_state
	var cand := []
	for r in mission.map.get("roofs", []):
		var rp: Vector3 = r
		if rp.y < -50.0:
			# a pitched roof: how high it is there
			var q0 := PhysicsRayQueryParameters3D.create(Vector3(rp.x, 40.0, rp.z), Vector3(rp.x, -1.0, rp.z), Game.WORLD)
			var h0 := ss.intersect_ray(q0)
			rp = Vector3(rp.x, h0.position.y if not h0.is_empty() else -999.0, rp.z)
		if rp.y < 2.5 or rp.y > 14.0:
			continue
		var d := Vector2(rp.x - global_position.x, rp.z - global_position.z).length()
		if d < 4.0 or d > 26.0 or rp.distance_to(at) > 40.0:
			continue
		cand.append(rp)
	cand.shuffle()
	for rp in cand:
		# the wall it goes up: where the line to the building meets it
		var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.0, 0), Vector3(rp.x, global_position.y + 1.0, rp.z), Game.WORLD)
		q.exclude = [get_rid()]
		var h := ss.intersect_ray(q)
		if h.is_empty():
			continue
		var n: Vector3 = h.normal
		n.y = 0
		if n.length() < 0.5:
			continue
		n = n.normalized()
		var base: Vector3 = h.position + n * 0.4
		base.y = global_position.y
		# the roof edge above that point
		var top_probe: Vector3 = h.position - n * 1.2
		var q2 := PhysicsRayQueryParameters3D.create(top_probe + Vector3(0, 30, 0), top_probe + Vector3(0, -2, 0), Game.WORLD)
		var h2 := ss.intersect_ray(q2)
		if h2.is_empty() or h2.position.y < 2.5:
			continue
		var top: Vector3 = h2.position + Vector3(0, 0.1, 0)
		var q3 := PhysicsRayQueryParameters3D.create(top + Vector3(0, 2.5, 0), at + Vector3(0, 1.2, 0), Game.WORLD)
		if not ss.intersect_ray(q3).is_empty():
			continue        # (no shot from up there)
		var up: Vector3 = Vector3(base.x, top.y + 0.3, base.z)
		_wall_base = base
		_wall_top = up
		_wall_n = n
		_jet = [base, up, top]
		_jet_perch = true
		flying = true
		airborne = true
		lurking = false
		goal = top
		_tlog("climb up %.1f m" % top.y)
		return true
	return false

func _climb_down() -> void:
	if _wall_top == Vector3.INF:
		return
	var away: Vector3 = _wall_base + (_wall_base - _wall_top).normalized() * 0.0
	var off := (Vector3(_wall_base.x, 0, _wall_base.z) - Vector3(_wall_top.x, 0, _wall_top.z))
	var dest: Vector3 = mission.free_spot(_wall_base + Vector3(rng.randf_range(-3, 3), 0.2, rng.randf_range(-3, 3)) + off * 2.0)
	_jet = [_wall_top, _wall_base, dest]
	_jet_perch = false
	flying = true
	airborne = true
	goal = dest
	agent.target_position = dest
	_tlog("climb down")

func _muzzle_pos() -> Vector3:
	if race == "kolos":
		# the two front heads, alternating
		var side := 0.3 if randf() < 0.5 else -0.3
		return global_transform * Vector3(side, 1.72, -1.1)
	if race == "diskoll":
		var side2 := 0.22 if randf() < 0.5 else -0.22
		return global_transform * Vector3(side2, float(R["hover"]) - 0.08, -0.9)
	return super._muzzle_pos()

func _try_drag() -> bool:
	return false

func stun(amount: float, from: Vector3, by: Node) -> void:
	# a machine: the baton only sparks
	Game.play_at(mission, "zap", global_position, -4)
	damage(amount * 0.2, from, by)

func damage(dmg: float, from: Vector3, by: Node) -> void:
	var was := dead
	super.damage(dmg, from, by)
	if dead and not was and multiplayer.is_server():
		if race == "diskoll":
			# its link goes dead: the Šediváci around lose the picture it gave them for a while
			for a in mission.aliens():
				if a != self and not a.dead and a.tac == "grey" and a.global_position.distance_to(global_position) < 80.0:
					a._disarray_t = maxf(a._disarray_t, 8.0)
		var ex: Array = R.get("explode", [4.0, 50.0])
		var at := global_position + Vector3(0, float(R.get("hover", 0.0)) + (1.8 if race == "kolos" else 0.0), 0)
		get_tree().create_timer(0.6).timeout.connect(func(): mission.explode(at, float(ex[0]), float(ex[1]), "-", true))

# ---- Diskoll: the greys' eyes ---------------------------------------------------------------
## It maps the ground under it and tells the greys where everybody is.
var _scan_t := 1.0
var _mark_cd := {}
func _scan(delta: float) -> void:
	_scan_t -= delta
	if _scan_t > 0.0:
		return
	_scan_t = 0.6
	for p in mission.players():
		if p.dead or p.downed:
			continue
		var d := global_position.distance_to(p.global_position)
		var sees := visible_to(p) or (d < 24.0 and _los(p.global_position + Vector3(0, 1.0, 0)))
		if not sees:
			continue
		var told := 0
		for a in mission.aliens():
			if a != self and not a.dead and a.tac == "grey" and a.global_position.distance_to(global_position) < 80.0:
				a.intel(p)
				told += 1
		var k := String(p.name)
		if told > 0 and mission.t > float(_mark_cd.get(k, -99.0)):
			_mark_cd[k] = mission.t + 15.0
			_mark_fx.rpc(k, p.global_position)

@rpc("authority", "call_local", "reliable")
func _mark_fx(who: String, at: Vector3) -> void:
	Game.play_at(mission, "diskoll_scan", global_position, 0)
	# a thin green sweep from the disc to the man it marked
	var mi := MeshInstance3D.new()
	var from := global_position + Vector3(0, float(R.get("hover", 0.0)), 0)
	var to := at + Vector3(0, 1.0, 0)
	var bm := BoxMesh.new()
	bm.size = Vector3(0.02, 0.02, from.distance_to(to))
	mi.mesh = bm
	mi.material_override = Game.color_mat(Color(0.3, 1.0, 0.5), true)
	mission.add_child(mi)
	mi.global_position = (from + to) / 2.0
	if from.distance_to(to) > 0.1:
		mi.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.95 else Vector3.RIGHT)
	var tw := mi.create_tween()
	tw.tween_interval(0.35)
	tw.tween_callback(mi.queue_free)
	var me: Node = mission.local_player()
	if me and String(me.name) == who:
		Game.play_ui(me, "radar_ping", -6)
		mission.hud.message("Ten disk tě zaměřil - šediváci teď vědí, kde jsi.", 3.0)
