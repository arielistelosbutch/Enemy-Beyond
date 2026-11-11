extends CharacterBody3D
## Civilian on a terror mission. Panics: runs from aliens and gunfire, hides,
## cowers. A mercenary standing next to a cowering civilian calms him down -
## then he follows that mercenary (E) to the Kondor. A Líhavec kills with one
## strike, and a few seconds later the body gets up again.

enum C { WANDER, FLEE, COWER, FOLLOW, SAFE }

const WALK := 1.3
const RUN := 4.0
const GRAVITY := 18.0

# ---- synchronized ----
var dead := false
var infected := false
var cowering := false
var saved := false

# ---- host ----
var st := C.WANDER
var goal := Vector3.ZERO
var wait := 0.0
var fear_t := 0.0
var follow: Node = null
var agent: NavigationAgent3D
var mission: Node
var rng := RandomNumberGenerator.new()

# ---- every machine ----
var body: Node3D
var anim: AnimationPlayer
var _last := Vector3.ZERO
var _speed := 0.0
var _scream_t := 0.0
var model_name := "civ_a"
var vip := false           # the one to rescue: hides until found, takes three strikes
var vip_hp := 3

func is_civilian() -> bool:
	return true

func setup(data: Dictionary) -> void:
	position = data["pos"]
	rng.seed = int(data["id"]) * 4241 + 5
	model_name = "civ_b" if int(data["id"]) % 2 == 1 else "civ_a"
	vip = bool(data.get("vip", false))
	if vip:
		model_name = "civ_a" if Net.mission_seed % 2 == 0 else "civ_b"
	collision_layer = 8
	collision_mask = 1 | 64 | 128
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	add_child(cs)
	body = Node3D.new()
	add_child(body)
	var m := Game.model(model_name)
	body.add_child(m)
	anim = m.find_child("AnimationPlayer", true, false)
	if anim:
		_afk_clips(m)
		for an in anim.get_animation_list():
			if not String(an).begins_with("death"):
				anim.get_animation(an).loop_mode = Animation.LOOP_LINEAR
		anim.play("idle")
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in [":position", ":rotation", ":dead", ":infected", ":cowering", ":saved"]:
		cfg.add_property(NodePath("." + prop))
	sync.replication_config = cfg
	sync.root_path = NodePath("..")
	add_child(sync)

## 0.62: frightened people - Ari's afk movements on their bones (animace/al_civ_a|b_<clip>.json,
## tools/test/afk_install.gd --race=civ_a): looking round nervously, walking, running, and cowering
## (Terrified). Only in the game package like the other afk movements; without them the old clips stay.
const AlienScript := preload("res://scripts/alien.gd")
const StepUp := preload("res://scripts/step_up.gd")
## Deaths (Ari: they have no guns, but can die like the soldiers): "death_1".."death_9" from the same
## pack, "death_crouch" for one shot while cowering; without them the old toppling over stays.
const CIV_CLIPS := ["idle", "walk", "run", "lurk",
	"death_1", "death_2", "death_3", "death_4", "death_5", "death_6", "death_7", "death_8", "death_9", "death_crouch"]
static var _civ_cache := {}
var _deaths: Array = []       # this one's own death movements (empty: he topples over as before)
var _dying := false           # an afk death is playing
var _death_done := false
func _afk_clips(m: Node) -> void:
	var sk: Skeleton3D = m.find_child("Skeleton3D", true, false)
	var lib: AnimationLibrary = anim.get_animation_library(&"")
	if sk == null or lib == null or not lib.has_animation("idle"):
		return
	var ref: Animation = lib.get_animation("idle")
	var sk_path := ""
	for t in ref.get_track_count():
		if ref.track_get_path(t).get_subname_count() > 0:
			sk_path = String(ref.track_get_path(t)).split(":")[0]
			break
	if sk_path == "":
		return
	for cn in CIV_CLIPS:
		var id := "al_%s_%s" % [model_name, cn]
		if not FileAccess.file_exists(AnimClips.path_of(id)):
			continue
		if not _civ_cache.has(id):
			_civ_cache[id] = AlienScript._afk_build(AnimClips.get_clip(id), sk, sk_path, ref)
		var made: Array = _civ_cache[id]
		if made.is_empty():
			continue
		if lib.has_animation(cn):
			lib.remove_animation(cn)
		lib.add_animation(cn, made[0])
		if cn.begins_with("death_") and cn != "death_crouch":
			_deaths.append(cn)

func _ready() -> void:
	mission = get_tree().current_scene
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.6
	agent.target_desired_distance = 0.8
	agent.radius = 0.35
	add_child(agent)
	goal = global_position
	wait = rng.randf_range(2.0, 6.0)
	if vip:
		st = C.COWER
		cowering = true

func _physics_process(delta: float) -> void:
	if dead and not _death_done:
		_death_start(cowering, true)     # (dead already when this machine joined: lies as he fell)
	_animate(delta)
	if dead or saved:
		if dead and not _dying:
			body.rotation.x = lerp(body.rotation.x, 1.5, delta * 6.0)
			body.position.y = lerp(body.position.y, 0.15, delta * 6.0)
		return
	if not multiplayer.is_server():
		return
	_think(delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0
	StepUp.climb(self, delta, StepUp.MAN)
	move_and_slide()

func _animate(delta: float) -> void:
	if dead and _dying:
		return         # Ari's death plays out and holds its last pose
	if anim == null or dead:
		if anim and anim.is_playing():
			anim.pause()
		return
	var mv := global_position - _last
	mv.y = 0
	_last = global_position
	_speed = lerp(_speed, mv.length() / max(delta, 0.001), 0.2)
	var want := "idle"
	if cowering and _speed < 0.4:
		want = "lurk"
	elif _speed > 2.2:
		want = "run"
	elif _speed > 0.3:
		want = "walk"
	if anim.current_animation != want:
		anim.play(want, 0.2)
	# whimpering and screams, heard by the local player
	_scream_t -= delta
	if _scream_t <= 0:
		_scream_t = randf_range(6.0, 14.0)
		var me: Node = mission.local_player() if mission else null
		if me and (cowering or _speed > 2.2) and me.global_position.distance_to(global_position) < 30.0:
			Game.play_at(mission, "whimper" if cowering else "scream", global_position, -8 if cowering else -4)

# ---- host brain -----------------------------------------------------------------------------
func hear(pos: Vector3, radius: float) -> void:
	if dead or st == C.FOLLOW or st == C.SAFE:
		return
	if global_position.distance_to(pos) >= radius * 0.6:
		return
	# the noise is one of the soldiers (steps, a shot): people don't run from their rescuers -
	# a close shot makes them duck where they are
	for p in mission.players():
		if not p.dead and p.global_position.distance_to(pos) < 3.0:
			if radius > 10.0 and st != C.FLEE and global_position.distance_to(pos) < 15.0:
				st = C.COWER
				cowering = true
				velocity.x = 0
				velocity.z = 0
			return
	_flee_from(pos)

const SEE_ALIEN := 24.0      # m: an alien in sight this close and they run (0.64: was 14 m)

func _danger() -> Node:
	for a in mission.aliens():
		if a.dead or ("husk" in a and a.husk):
			continue
		var d: float = a.global_position.distance_to(global_position)
		if d < SEE_ALIEN:
			var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.5, 0), a.global_position + Vector3(0, 1.0, 0), Game.WORLD)
			if d < 4.0 or get_world_3d().direct_space_state.intersect_ray(q).is_empty():
				return a
	return null

func _flee_from(p: Vector3) -> void:
	st = C.FLEE
	cowering = false
	fear_t = rng.randf_range(7.0, 11.0)
	var away := global_position - p
	away.y = 0
	if away.length() < 0.1:
		away = Vector3(1, 0, 0)
	if Game.cmd_arg("oldai", "") == "1" or Game.cmd_arg("ai063", "") == "1":
		_go(_snap(global_position + away.normalized().rotated(Vector3.UP, rng.randf_range(-0.7, 0.7)) * rng.randf_range(10.0, 16.0)))
		return
	# (0.64, Ari: they run from the aliens) - away from every alien they know of round them, and
	# towards the soldiers if there are any that way; never past an alien
	var near := []
	for a in mission.aliens():
		if not a.dead and a.global_position.distance_to(global_position) < 30.0:
			near.append(a.global_position)
	if near.is_empty():
		near.append(p)
	var best := Vector3.INF
	var bs := -1e9
	for i in 10:
		var dir := away.normalized().rotated(Vector3.UP, (i - 4.5) * 0.45 + rng.randf_range(-0.15, 0.15))
		var c := _snap(global_position + dir * rng.randf_range(12.0, 20.0))
		if c.distance_to(global_position) < 5.0:
			continue          # (a wall: the nav mesh gives nothing that way)
		var sc := 0.0
		for ap in near:
			var da: float = (ap as Vector3).distance_to(c)
			sc += minf(da, 30.0)
			if da < 6.0:
				sc -= 40.0       # straight into its arms
			# the path would run past it
			var mid: Vector3 = (c + global_position) * 0.5
			if (ap as Vector3).distance_to(mid) < 5.0:
				sc -= 25.0
		var pd := 1e9
		for pl in mission.players():
			if not pl.dead and not pl.downed:
				pd = minf(pd, pl.global_position.distance_to(c))
		if pd < 40.0:
			sc += (40.0 - pd) * 0.6        # the soldiers are safety
		if sc > bs:
			bs = sc
			best = c
	_go(best if best != Vector3.INF else _snap(global_position + away.normalized() * rng.randf_range(10.0, 16.0)))
	# a scream: the aliens near by hear it (that is how they find them in a terror)
	if multiplayer.is_server() and mission.t - _cry_t > 4.0:
		_cry_t = mission.t
		for a in mission.aliens():
			if not a.dead and a.global_position.distance_to(global_position) < 28.0 and a.has_method("hear_cry"):
				a.hear_cry(global_position)

var _cry_t := -99.0

func _think(delta: float) -> void:
	if mission and not mission.started():
		return
	var dz := _danger()
	if vip and st == C.COWER:
		velocity.x = 0; velocity.z = 0
		return             # stays hidden, does not run into the dark
	if dz and st != C.FOLLOW:
		if st != C.FLEE or fear_t < 3.0:
			_flee_from(dz.global_position)
	match st:
		C.WANDER:
			wait -= delta
			if _arrived():
				velocity.x = 0; velocity.z = 0
				if wait <= 0:
					wait = rng.randf_range(4.0, 10.0)
					_go(_snap(global_position + Vector3(rng.randf_range(-5, 5), 0, rng.randf_range(-5, 5))))
			else:
				_walk(WALK, delta)
		C.FLEE:
			fear_t -= delta
			_walk(RUN, delta)
			if _arrived() or fear_t <= 0:
				st = C.COWER
				cowering = true
				wait = rng.randf_range(20.0, 40.0)
		C.COWER:
			velocity.x = 0; velocity.z = 0
		C.FOLLOW:
			if not is_instance_valid(follow) or follow.dead or follow.downed:
				follow = null
				st = C.COWER
				cowering = true
				return
			var d: float = follow.global_position.distance_to(global_position)
			if global_position.distance_to(mission.map["evac"]) < 5.5:
				_saved.rpc()
				return
			if d > 2.5:
				_go(follow.global_position)
				_walk(RUN if d > 6.0 else WALK * 1.8, delta)
			else:
				velocity.x = 0; velocity.z = 0

## A mercenary pressed E next to this civilian: he follows him (host).
func calm_by(p: Node) -> void:
	if dead or infected or saved:
		return
	follow = p
	st = C.FOLLOW
	cowering = false

@rpc("authority", "call_local", "reliable")
func _saved() -> void:
	saved = true
	visible = false
	collision_layer = 0
	if mission.local_player():
		mission.hud.message(("%s je na palubě Kondoru." % mission.vip_name) if vip else "Civilista je na palubě Kondoru.", 2.5)

## Struck by an alien (host). A Líhavec's victim rises again.
func killed_by(race: String) -> void:
	if dead:
		return
	if vip and vip_hp > 1:
		_vip_hurt.rpc(vip_hp - 1)
		return
	_die.rpc(race == "lihnoun")
	if race == "lihnoun":
		var at := global_position
		get_tree().create_timer(rng.randf_range(4.0, 7.0)).timeout.connect(func():
			if multiplayer.is_server() and not mission.finished and is_inside_tree():
				_rise.rpc()
				mission.spawn_alien("zombie", at))

@rpc("authority", "call_local", "reliable")
func _vip_hurt(left: int) -> void:
	vip_hp = left
	Game.play_at(mission, "scream", global_position, 0)
	if mission.hud:
		mission.hud.message("%s je zraněn! (zdraví %d/3)" % [mission.vip_name, left], 2.5)

@rpc("authority", "call_local", "reliable")
func _die(seeded: bool) -> void:
	var low := cowering
	dead = true
	infected = seeded
	cowering = false
	_death_start(low, false)
	collision_layer = 0
	Game.play_at(mission, "scream", global_position, 0)

## Ari's death movement (the same one on every machine: picked by the node's name); crouched in
## fear he dies from the crouch. at_end: already lying (joined later) - straight to the last pose.
func _death_start(low: bool, at_end: bool) -> void:
	_death_done = true
	if anim == null or _deaths.is_empty():
		return
	var pick: String = _deaths[absi(hash(String(name))) % _deaths.size()]
	if low and anim.has_animation("death_crouch"):
		pick = "death_crouch"
	anim.speed_scale = 1.0
	anim.play(pick, 0.0 if at_end else 0.12)
	if at_end:
		anim.seek(anim.current_animation_length, true)
	_dying = true

@rpc("authority", "call_local", "reliable")
func _rise() -> void:
	visible = false   # the Nakažený takes its place

func _go(p: Vector3) -> void:
	goal = p
	agent.target_position = p

func _snap(p: Vector3) -> Vector3:
	return NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, p)

func _arrived() -> bool:
	return agent.is_navigation_finished() or global_position.distance_to(goal) < 1.0

func _walk(speed: float, delta: float) -> void:
	if _arrived():
		velocity.x = 0; velocity.z = 0
		return
	var nxt := agent.get_next_path_position()
	var dir := nxt - global_position
	dir.y = 0
	if dir.length() < 0.05:
		dir = goal - global_position
		dir.y = 0
	dir = dir.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	var want := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, want, delta * 8.0)
