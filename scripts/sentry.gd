extends StaticBody3D
## (0.80, Ari: "tu věž tam můžeš přidat… lepší zbraně s výzkumem") ST-01, strážní věž.
## A tripod with a turning head and a motion sensor: it fires at an alien that MOVES in front
## of it (±60° from where it was set facing, up to 25 m, a clear line of sight) - one that lies
## still in cover is safe from it. The host decides everything (who, when, hit or miss) and sends
## the shot to all; a player in the line of fire stops it. Research changes what it carries:
## ST-01 a rifle (rifle magazines, F to top up), Laserová věž (its own cell, recharges slowly),
## Plazmová věž (PL-MAG cells). Bolts and blasts wreck it (HP 160). F folds it back up.
const KINDS := {
	"rifle": {"name": "Strážní věž ST-01", "dmg": 24.0, "rate": 0.2, "start": 40, "max": 60, "ammo": "rifle_clip", "snd": "rifle", "noise": 40.0},
	"laser": {"name": "Laserová věž ST-02", "dmg": 34.0, "rate": 0.5, "start": 40, "max": 40, "ammo": "", "snd": "laser", "noise": 22.0, "recharge": 3.0},
	"plasma": {"name": "Plazmová věž ST-03", "dmg": 68.0, "rate": 0.85, "start": 20, "max": 40, "ammo": "plasma_cell", "snd": "plasma", "noise": 30.0},
}
const RANGE := 25.0
const ARC := 1.05          # ±60° from the facing it was set up with
const TURN := 2.6          # rad/s of the head
const HP := 160.0
const MUZZLE := Vector3(0, 0.08, -0.74)
const PIVOT_Y := 0.62

var kind := "rifle"
var owner_name := ""
var face_yaw := 0.0
var ammo := 0
var hp := HP
var yaw := 0.0              # head, relative to the base
var _want := 0.0
var _cd := 0.0
var _scan_t := 0.0
var _target: Node = null
var _charge_t := 0.0
var _aim_send := 0.0
var _gone := false
var fired := 0             # (host) shots so far - for the test
var head: Node3D
var eye: MeshInstance3D
var mission: Node

func setup(m: Node, k: String, by: String, face: Vector3, rounds: int) -> void:
	mission = m
	kind = k if KINDS.has(k) else "rifle"
	owner_name = by
	var f := Vector3(face.x, 0, face.z)
	if f.length() < 0.01:
		f = Vector3(0, 0, -1)
	face_yaw = atan2(-f.x, -f.z)
	rotation.y = face_yaw
	ammo = rounds if rounds >= 0 else int(KINDS[kind]["start"])
	ammo = mini(ammo, int(KINDS[kind]["max"]))
	collision_layer = 1
	collision_mask = 0
	add_to_group("sentry")
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.32
	sh.height = 0.85
	cs.shape = sh
	cs.position.y = 0.42
	add_child(cs)
	var mdl := Game.model("sentry")
	add_child(mdl)
	head = mdl.find_child("Head", true, false) as Node3D
	eye = mdl.find_child("Eye", true, false) as MeshInstance3D
	if kind != "rifle" and head:
		# the research barrels: the same head, the light of the weapon in the eye and on the barrel
		var col := Color(1.0, 0.15, 0.1) if kind == "laser" else Color(0.35, 1.0, 0.45)
		var lit := OmniLight3D.new()
		lit.light_color = col
		lit.light_energy = 0.4
		lit.omni_range = 0.8
		head.add_child(lit)
		lit.position = MUZZLE + Vector3(0, 0, 0.2)

func display_name() -> String:
	return String(KINDS[kind]["name"])

func ammo_max() -> int:
	return int(KINDS[kind]["max"])

func ammo_item() -> String:
	return String(KINDS[kind]["ammo"])

func _muzzle() -> Vector3:
	if head:
		return head.global_transform * MUZZLE
	return global_position + Vector3(0, PIVOT_Y, 0)

func _physics_process(dt: float) -> void:
	if _gone or mission == null:
		return
	if head:
		head.rotation.y = lerp_angle(head.rotation.y, yaw, minf(1.0, dt * 12.0))
	if eye:
		eye.visible = ammo > 0 or fmod(Time.get_ticks_msec() / 1000.0, 1.0) < 0.5
	if not multiplayer.is_server() or not mission.started():
		return
	if KINDS[kind].has("recharge") and ammo < ammo_max():
		_charge_t += dt
		if _charge_t >= float(KINDS[kind]["recharge"]):
			_charge_t = 0.0
			ammo += 1
	_cd -= dt
	_scan_t -= dt
	if _scan_t <= 0.0:
		_scan_t = 0.25
		_target = _pick()
	if _target == null or not is_instance_valid(_target) or _target.dead:
		_target = null
		return
	var to: Vector3 = _target.global_position - global_position
	_want = clampf(wrapf(atan2(-to.x, -to.z) - face_yaw, -PI, PI), -ARC, ARC)
	yaw = move_toward(yaw, _want, TURN * dt)
	_aim_send -= dt
	if _aim_send <= 0.0:
		_aim_send = 0.15
		_aim.rpc(yaw)
	if absf(yaw - _want) < 0.07 and _cd <= 0.0 and ammo > 0 and _clear_line(_target):
		_shoot(_target)

## A moving alien, in the arc, in range, seen; the nearest wins.
func _pick() -> Node:
	var best: Node = null
	var bd := RANGE
	for a in mission.aliens():
		if a.dead or a.get("husk"):
			continue
		var to: Vector3 = a.global_position - global_position
		var d := to.length()
		if d > bd or d < 0.6:
			continue
		if absf(wrapf(atan2(-to.x, -to.z) - face_yaw, -PI, PI)) > ARC + 0.05:
			continue
		var moving: bool = float(a.get("_speed")) > 0.35 or bool(a.get("flying")) or a.state == a.S.COMBAT
		if not moving:
			continue
		if a.get("cloak") and d > 6.0:
			continue
		if not _sees(a):
			continue
		bd = d
		best = a
	return best

func _aim_at(a: Node) -> Vector3:
	return a.global_position + Vector3(0, 0.9 if not a.R.has("hover") else 1.2, 0)

func _sees(a: Node) -> bool:
	var from := global_position + Vector3(0, PIVOT_Y + 0.1, 0)
	var q := PhysicsRayQueryParameters3D.create(from, _aim_at(a), Game.WORLD | Game.GLASS)
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

## Nobody of ours between the barrel and the alien (or just behind it).
func _clear_line(a: Node) -> bool:
	var from := _muzzle()
	var to := _aim_at(a)
	var dir := to - from
	var L := dir.length()
	if L < 0.1:
		return true
	dir /= L
	for pl in mission.players():
		if pl.dead:
			continue
		var rel: Vector3 = pl.global_position + Vector3(0, 1.0, 0) - from
		var along := rel.dot(dir)
		if along > 0.0 and along < L + 2.0 and (rel - dir * along).length() < 1.3:
			return false
	return true

func _shoot(a: Node) -> void:
	_cd = float(KINDS[kind]["rate"])
	ammo -= 1
	fired += 1
	var from := _muzzle()
	var to := _aim_at(a)
	var d := from.distance_to(to)
	var chance := clampf(0.92 - d / 45.0, 0.35, 0.92)
	if float(a.get("_speed")) > 3.0:
		chance *= 0.7
	if Game.veteran():
		chance *= 0.9
	var hit := randf() < chance
	var end := to
	if not hit:
		end = to + Vector3(randf_range(-1, 1), randf_range(-0.4, 0.9), randf_range(-1, 1)).normalized() * randf_range(0.6, 1.4)
		end = from + (end - from).normalized() * (d + 6.0)
	_fx.rpc(yaw, end)
	mission.noise(from, float(KINDS[kind]["noise"]))
	if a.has_method("suppressed"):
		a.suppressed(global_position)
	if hit:
		mission.hit_kind = "plasma" if kind == "plasma" else ("laser" if kind == "laser" else "bullet")
		a.damage(float(KINDS[kind]["dmg"]), global_position, null)
		mission.hit_kind = ""
		if a.dead:
			var by: Node = mission.actors.get_node_or_null(owner_name)
			if by:
				a._credit.rpc_id(by.get_multiplayer_authority(), owner_name)

@rpc("authority", "call_local", "unreliable")
func _aim(y: float) -> void:
	yaw = y

@rpc("authority", "call_local", "unreliable")
func _fx(y: float, end: Vector3) -> void:
	yaw = y
	if head:
		head.rotation.y = y
	var from := _muzzle()
	var snd: String = KINDS[kind]["snd"]
	Game.play_at(mission, snd, from, -3)
	if mission.nvg_on:
		mission.nvg_flash(from, 0.25)
	if kind == "plasma":
		var me: Node = mission.local_player()
		if me and me.has_method("_plasma_pulse"):
			me._plasma_pulse(from, end)
		return
	var tracer := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var len := from.distance_to(end)
	bm.size = Vector3(0.02 if kind == "rifle" else 0.035, 0.02 if kind == "rifle" else 0.035, len)
	tracer.mesh = bm
	tracer.material_override = Game.color_mat(Color(1.0, 0.85, 0.4) if kind == "rifle" else Color(1.0, 0.15, 0.1), true)
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mission.add_child(tracer)
	tracer.global_position = (from + end) / 2.0
	if len > 0.01:
		tracer.look_at(end, Vector3.UP if absf((end - from).normalized().y) < 0.99 else Vector3.RIGHT)
	var fl := OmniLight3D.new()
	fl.light_color = Color(1.0, 0.8, 0.4) if kind == "rifle" else Color(1.0, 0.2, 0.1)
	fl.light_energy = 2.5
	fl.omni_range = 5.0
	mission.add_child(fl)
	fl.global_position = from
	get_tree().create_timer(0.05 if kind == "rifle" else 0.09).timeout.connect(func():
		if is_instance_valid(tracer): tracer.queue_free()
		if is_instance_valid(fl): fl.queue_free())

## Host: a bolt or a blast hit it.
func sentry_hit(dmg: float) -> void:
	if _gone or not multiplayer.is_server():
		return
	hp -= dmg
	if hp <= 0.0:
		_gone = true
		mission.explode(global_position + Vector3(0, 0.5, 0), 2.2, 30.0, "-", false)
		_wrecked.rpc()

@rpc("authority", "call_local", "reliable")
func _wrecked() -> void:
	_gone = true
	if mission and mission.hud and mission.local_player() and mission.local_player().name == owner_name:
		mission.hud.message("Tvoje věž je zničená.", 2.5)
	queue_free()

## Host: F with a magazine - top it up (the player has already taken the magazine out of the pack).
@rpc("any_peer", "call_local", "reliable")
func req_reload(rounds: int) -> void:
	if not multiplayer.is_server() or _gone:
		return
	ammo = mini(ammo_max(), ammo + rounds)
	_ammo_now.rpc(ammo)

@rpc("authority", "call_local", "reliable")
func _ammo_now(n: int) -> void:
	ammo = n

## Host: F without a magazine - fold it up; the one who asked gets it back in his pack.
@rpc("any_peer", "call_local", "reliable")
func req_pickup(who: String) -> void:
	if not multiplayer.is_server() or _gone:
		return
	var pl: Node = mission.actors.get_node_or_null(who)
	if pl == null:
		return
	_gone = true
	pl._got_item.rpc_id(pl.get_multiplayer_authority(), {"id": "sentry", "rounds": ammo, "kind": kind})
	_folded.rpc()

@rpc("authority", "call_local", "reliable")
func _folded() -> void:
	_gone = true
	Game.play_at(mission, "clink", global_position + Vector3(0, 0.5, 0), -6)
	queue_free()
