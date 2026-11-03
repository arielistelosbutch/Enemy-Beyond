extends "res://scripts/alien.gd"
## Machines. They do not hide and do not tire; the baton only sparks on them;
## when they are destroyed they blow apart.
##  Diskoll - a fast flying disc that escorts the greys. Quick, very precise
##            bursts (not one-shot kills). Plasma and explosions cut through it.
##  Kolos   - a walking machine on three legs: two plasma heads in front fire
##            bursts, the roof cannon fires a heavy bolt every few seconds. Deadly
##            and accurate, but stupid: it walks straight at the last thing it saw.

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
	hum.volume_db = -8.0 if race == "diskoll" else -4.0
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
		# three legs stepping in turn while it walks
		_gait += delta * clampf(_speed, 0.0, 3.5) * 2.2
		var moving := clampf(_speed, 0.0, 1.0)
		for i in 3:
			var leg := _part("Leg%d" % i)
			if leg:
				var ph := _gait + i * TAU / 3.0
				leg.rotation.x = sin(ph) * 0.22 * moving
				leg.rotation.z = maxf(0.0, cos(ph)) * 0.12 * moving
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
	if race != "kolos" or dead:
		return
	# roof cannon: a heavy bolt at whatever it is fighting, every few seconds
	_cannon_t -= delta
	if _cannon_t <= 0 and state == S.COMBAT and is_instance_valid(target) and not target.dead and visible_to(target):
		_cannon_t = rng.randf_range(5.0, 8.0)
		var tgt: Vector3 = target.global_position + Vector3(0, 1.0, 0)
		var miss := 0.4 + global_position.distance_to(tgt) * 0.03
		tgt += Vector3(rng.randf_range(-miss, miss), rng.randf_range(-miss, miss) * 0.5, rng.randf_range(-miss, miss))
		var from := global_position + Vector3(0, 2.75, 0) - global_transform.basis.z * 1.0
		_plasma.rpc(from, (tgt - from).normalized(), 2.0, "plasma")

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
		var ex: Array = R.get("explode", [4.0, 50.0])
		var at := global_position + Vector3(0, float(R.get("hover", 0.0)) + (1.8 if race == "kolos" else 0.0), 0)
		get_tree().create_timer(0.6).timeout.connect(func(): mission.explode(at, float(ex[0]), float(ex[1]), "-", true))
