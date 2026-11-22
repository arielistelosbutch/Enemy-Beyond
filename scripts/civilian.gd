extends CharacterBody3D
## Civilian on a terror mission. Panics: runs from aliens and gunfire, hides,
## cowers. A mercenary standing next to a cowering civilian calms him down -
## then he follows that mercenary (E) to the Kondor. A Líhavec kills with one
## strike, and a few seconds later the body gets up again.

enum C { WANDER, FLEE, COWER, FOLLOW, SAFE, HIDE }

const WALK := 1.3
const RUN := 4.0
const GRAVITY := 18.0

# ---- synchronized ----
var dead := false
var infected := false
var cowering := false
var saved := false
var terror := 0.0          # (0.72) 0 calm .. 1 out of his mind: how long a soldier has to talk him round
var hidden := false        # (0.72) shut in a house behind a locked door

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
var model_name := "civ_a"   # (the set of afk clips: civ_a man, civ_b woman)
var civ_type := ""         # (0.72.1) CivLook type: urednik, farmar, babicka...
const CivLook := preload("res://scripts/civ_look.gd")
var vip := false           # the one to rescue: hides until found, takes three strikes
var vip_hp := 3
## 0.7x Karanténa: carries the brood inside (from the spawn data, the same on every machine; nobody
## is told - up close the skin gives it away and he groans now and then)
var carrier := false
var _follow_t := 0.0
var _turn_after := 60.0
var _tell_t := 0.0
var _tell_on := false

func is_civilian() -> bool:
	return true

func setup(data: Dictionary) -> void:
	position = data["pos"]
	rng.seed = int(data["id"]) * 4241 + 5
	vip = bool(data.get("vip", false))
	carrier = bool(data.get("carrier", false))
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
	# (0.72.1, Ari: "ať vypadají víc jako vojáci a jejich tváře") the soldier's model in everyday
	# clothes, a type for the town or the village (CivLook); the look comes from the id, so every
	# machine dresses him the same. The afk clips of civ_a/civ_b fit the same 15 bones.
	var look := CivLook.make(CivLook.place_of(String(Net.mission_params.get("biome", "farm"))), int(data["id"]) + (Net.mission_seed % 997) * 131, _vip_sex() if vip else "")
	civ_type = String(look["type"])
	var female := bool(look["look"]["female"])
	model_name = "civ_b" if female else "civ_a"
	var m: Node3D = Game.model("merc")
	m.scale = Vector3(-1, 1, 1)
	body.add_child(m)
	CivLook.dress(m, look)
	anim = m.find_child("AnimationPlayer", true, false)
	if anim:
		_afk_clips(m)
		for an in ["idle", "walk", "run", "lurk"]:
			if anim.has_animation(an):
				anim.get_animation(an).loop_mode = Animation.LOOP_LINEAR
		anim.play("idle")
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in [":position", ":rotation", ":dead", ":infected", ":cowering", ":saved", ":terror", ":hidden"]:
		cfg.add_property(NodePath("." + prop))
	sync.replication_config = cfg
	sync.root_path = NodePath("..")
	NetSmooth.setup(sync, cfg, ["position", "rotation"])
	add_child(sync)
	NetSmooth.attach(self, sync, body, false)

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
	# (0.72.1) merc.glb's library is shared by every soldier on the map: the civilian gets his own copy
	lib = lib.duplicate()
	anim.remove_animation_library(&"")
	anim.add_animation_library(&"", lib)
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

## The person to rescue from the briefing: a woman when the first name ends with -a (Kateřina, Ilona).
func _vip_sex() -> String:
	var sc: Node = get_tree().current_scene if is_inside_tree() else Engine.get_main_loop().current_scene
	var vn := String(sc.get("vip_name")) if sc and sc.get("vip_name") != null else ""
	var parts := vn.split(" ", false)
	if parts.size() < 2:
		return "m"
	return "f" if parts[parts.size() - 2].ends_with("a") else "m"

func _ready() -> void:
	mission = get_tree().current_scene
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.6
	agent.target_desired_distance = 0.8
	agent.radius = 0.35
	add_child(agent)
	goal = global_position
	wait = rng.randf_range(2.0, 6.0)
	_turn_after = rng.randf_range(45.0, 80.0)
	if vip:
		st = C.COWER
		cowering = true
	_spawn_check()

func _physics_process(delta: float) -> void:
	var _pt := PerfLog.t0()
	_pl_physics_process(delta)
	PerfLog.took("civilisté: pohyb (snímek)", _pt)

func _pl_physics_process(delta: float) -> void:
	if dead and not _death_done:
		_death_start(cowering, true)     # (dead already when this machine joined: lies as he fell)
	_animate(delta)
	if carrier and not dead:
		_tells(delta)
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
	StepUp.climb(self, delta, StepUp.MAN if _old_ai() else StepUp.ALIEN)    # (0.72: the paths are baked for 0,4 m steps - a civilian takes them too, or he walks into the ledge for good)
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
	var _pt := PerfLog.t0()
	_pl_hear(pos, radius)
	PerfLog.took("civilista slyší", _pt)

const HEAR_SAME_MS := 500
var _heard_ms := -100000
var _heard_pos := Vector3.INF
var _heard_r := 0.0
func _pl_hear(pos: Vector3, radius: float) -> void:
	if dead or st == C.FOLLOW or st == C.SAFE:
		return
	if global_position.distance_to(pos) >= radius * 0.6:
		return
	# (0.72.5 výkon, Ari: propady při střelbě z kulometu) dávka = až 20 ran za s ze stejného místa:
	# reaguje se na první, další ze stejného místa (do 4 m), ne hlasitější, se do 0,5 s přeskočí
	# (dřív každá rána znovu plánovala cestu / útěk)
	var _now := Time.get_ticks_msec()
	if _now - _heard_ms < HEAR_SAME_MS and pos.distance_to(_heard_pos) < 4.0 and radius <= _heard_r + 0.5:
		return
	_heard_ms = _now
	_heard_pos = pos
	_heard_r = radius
	# the noise is one of the soldiers (steps, a shot): people don't run from their rescuers -
	# a close shot makes them duck where they are
	for p in mission.players():
		if not p.dead and p.global_position.distance_to(pos) < 3.0:
			if radius > 10.0:
				terror = minf(1.0, terror + 0.12)
			if radius > 10.0 and st != C.FLEE and st != C.HIDE and global_position.distance_to(pos) < 15.0:
				st = C.COWER
				cowering = true
				velocity.x = 0
				velocity.z = 0
			return
	if (st == C.HIDE or hidden) and global_position.distance_to(pos) > 6.0:
		terror = 1.0
		return                 # (on his way to the hideout or in it: he keeps going, keeps still)
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
	var _pt := PerfLog.t0()
	_pl_flee_from(p)
	PerfLog.took("civilista utíká (výběr cesty)", _pt)

func _pl_flee_from(p: Vector3) -> void:
	terror = 1.0
	if hidden or _hide_i >= 0:
		_unhide()
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
	if _try_hide(near):
		_cry()
		return
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
	_cry()

## A scream: the aliens near by hear it (that is how they find them in a terror).
func _cry() -> void:
	if multiplayer.is_server() and mission.t - _cry_t > 4.0:
		_cry_t = mission.t
		for a in mission.aliens():
			if not a.dead and a.global_position.distance_to(global_position) < 28.0 and a.has_method("hear_cry"):
				a.hear_cry(global_position)

var _cry_t := -99.0

func _think(delta: float) -> void:
	var _pt := PerfLog.t0()
	_pl_think(delta)
	PerfLog.took("AI civilistů", _pt)

func _pl_think(delta: float) -> void:
	if mission and not mission.started():
		return
	var dz := _danger()
	_fear_tick(delta, dz)
	if vip and st == C.COWER:
		velocity.x = 0; velocity.z = 0
		return             # stays hidden, does not run into the dark
	if dz and st == C.FOLLOW and not _old_ai():
		# (0.72) led to the ship: a thing close by and he ducks where he is; right on top of him and
		# he bolts - the soldier has to catch him and talk him round again
		var dd: float = dz.global_position.distance_to(global_position)
		if dd < 4.5 and rng.randf() < delta * 1.2:
			follow = null
			_flee_from(dz.global_position)
			return
		if dd < 10.0 and _duck_t <= 0.0:
			_duck_t = rng.randf_range(1.8, 3.2)
	if dz and st != C.FOLLOW:
		if hidden and dz.global_position.distance_to(global_position) > 5.0:
			pass               # behind the locked door he keeps still and hopes
		elif st == C.HIDE:
			# (only when the thing is at his hideout, or right on him: not on every look back)
			var hs: Vector3 = mission.map["vip_spots"][_hide_i] if _hide_i >= 0 else global_position
			if dz.global_position.distance_to(global_position) < 2.5 or dz.global_position.distance_to(hs) < 6.0:
				_unhide()
				_flee_from(dz.global_position)     # (it is in the way: somewhere else)
		elif st != C.FLEE or fear_t < 3.0:
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
		C.HIDE:
			fear_t -= delta
			_walk(RUN, delta)
			if global_position.distance_to(goal) < 1.2 or _arrived():
				_lock_in()
			elif fear_t <= -12.0:
				st = C.COWER          # (stuck on the way: he cowers where he is)
				cowering = true
		C.COWER:
			velocity.x = 0; velocity.z = 0
		C.FOLLOW:
			if carrier:
				_follow_t += delta
				if _follow_t > _turn_after or global_position.distance_to(mission.map["evac"]) < 12.0:
					_hatch_now()
					return
			if not is_instance_valid(follow) or follow.dead or follow.downed:
				follow = null
				st = C.COWER
				cowering = true
				return
			var d: float = follow.global_position.distance_to(global_position)
			if global_position.distance_to(mission.map["evac"]) < 5.5:
				_saved.rpc()
				return
			if _duck_t > 0.0:
				_duck_t -= delta
				cowering = true
				velocity.x = 0; velocity.z = 0
				return
			cowering = false
			if d > 2.5:
				_go(follow.global_position)
				_walk(RUN if d > 6.0 else WALK * 1.8, delta)
			else:
				velocity.x = 0; velocity.z = 0

var _duck_t := 0.0
var _door_cd := 0.0

func _old_ai() -> bool:
	return Game.cmd_arg("oldai", "") == "1" or Game.cmd_arg("ai063", "") == "1" or Game.cmd_arg("oldciv", "") == "1"

## (0.72) How scared he is: up at once, down slowly (shut in a house he stays stiff with fear).
func _fear_tick(delta: float, dz: Node) -> void:
	if dz:
		terror = minf(1.0, terror + delta * (0.6 if dz.global_position.distance_to(global_position) < 12.0 else 0.2))
		return
	var floor_k := 0.0
	match st:
		C.FOLLOW: floor_k = 0.15
		C.COWER, C.HIDE: floor_k = 0.55 if hidden else 0.4
		C.FLEE: floor_k = 0.8
	var down := 0.03 if st == C.FOLLOW else 0.012
	if terror > floor_k:
		terror = maxf(floor_k, terror - delta * down)

## (0.72, Ari: real panic) Into a house and lock himself in. The spots are the rooms of the houses
## (map vip_spots); two people at most in one; never towards an alien, never past one. With a soldier
## close by he would rather run to him (the open-ground choice does that).
const HIDE_R := 30.0
const HIDE_PER := 2
func _try_hide(near: Array) -> bool:
	if _old_ai() or vip or mission.home():
		return false
	for pl in mission.players():
		if not pl.dead and not pl.downed and pl.global_position.distance_to(global_position) < 14.0:
			return false
	if rng.randf() > 0.7:
		return false            # (not everybody thinks of it)
	var spots: Array = mission.map.get("vip_spots", [])
	var best := Vector3.INF
	var bs := -1e9
	var bi := -1
	for i in spots.size():
		var sp: Vector3 = spots[i]
		var d := sp.distance_to(global_position)
		if d > HIDE_R or d < 1.0:
			continue
		if int(mission.civ_hides.get(i, 0)) >= HIDE_PER:
			continue
		var snap := _snap(sp)
		if snap.distance_to(sp) > 1.6 or absf(snap.y - global_position.y) > 3.5:
			continue
		var sc := -d
		var bad := false
		for ap in near:
			var da: float = (ap as Vector3).distance_to(snap)
			if da < 9.0:
				bad = true
			var mid: Vector3 = (snap + global_position) * 0.5
			if (ap as Vector3).distance_to(mid) < 5.0:
				bad = true
			sc += minf(da, 30.0) * 0.5
		if bad:
			continue
		if sc > bs:
			bs = sc
			best = snap
			bi = i
	if bi < 0:
		return false
	_hide_i = bi
	mission.civ_hides[bi] = int(mission.civ_hides.get(bi, 0)) + 1
	st = C.HIDE
	cowering = false
	fear_t = 0.0
	# (a second one in the same room squats beside the first)
	var off := Vector3(0.7, 0, 0).rotated(Vector3.UP, rng.randf() * TAU) if int(mission.civ_hides[bi]) > 1 else Vector3.ZERO
	_go(_snap(best + off))
	return true

var _hide_i := -1
## In the room: the doors of the house shut and locked behind him; he cowers in the corner.
func _lock_in() -> void:
	st = C.COWER
	cowering = true
	hidden = true
	velocity.x = 0; velocity.z = 0
	var sp: Vector3 = mission.map["vip_spots"][_hide_i] if _hide_i >= 0 else global_position
	for i in mission.house_doors(sp):
		mission.lock_door(i, name)

func _unhide() -> void:
	hidden = false
	if _hide_i >= 0:
		mission.civ_hides[_hide_i] = maxi(0, int(mission.civ_hides.get(_hide_i, 1)) - 1)
		var sp: Vector3 = mission.map["vip_spots"][_hide_i]
		for i in mission.house_doors(sp):
			mission.unlock_door(i, name)
	_hide_i = -1

## A soldier knocked on the locked door (host): if nothing is on the prowl near him, he comes and
## unlocks it after a while; otherwise he stays still.
func knocked(i: int) -> void:
	if dead or not hidden:
		return
	get_tree().create_timer(rng.randf_range(2.5, 4.5)).timeout.connect(func():
		if not is_instance_valid(self) or dead or not hidden or mission.finished:
			return
		var dz := _danger()
		if dz and dz.global_position.distance_to(global_position) < 18.0:
			return
		mission.unlock_door(i, name, true))

## How long a soldier has to talk to him (every machine: from the synchronized terror).
func talk_time() -> float:
	if terror < 0.3:
		return 0.0
	return 1.0 + terror * 3.0

## A mercenary pressed E next to this civilian: he follows him (host).
func calm_by(p: Node) -> bool:
	if dead or infected or saved:
		return false
	if not _old_ai():
		var dz := _danger()
		if dz and dz.global_position.distance_to(global_position) < 14.0:
			terror = 1.0
			return false            # "it is out there!" - he will not move while he can see it
	if hidden:
		_unhide()
	terror = minf(terror, 0.5)
	follow = p
	st = C.FOLLOW
	cowering = false
	return true

@rpc("authority", "call_local", "reliable")
func _saved() -> void:
	if carrier:
		return            # (never aboard: _think hatches him before the ramp)
	saved = true
	visible = false
	collision_layer = 0
	if mission.local_player():
		mission.hud.message(("%s je na palubě Kondoru." % mission.vip_name) if vip else "Civilista je na palubě Kondoru.", 2.5)

## Struck by an alien (host). A Líhavec's victim rises again.
func killed_by(race: String) -> void:
	if dead:
		return
	if carrier:
		# (Ari) "z každého takhle padlého se zrodí líhňák": the brood does not die with him
		_die.rpc(false)
		get_tree().create_timer(rng.randf_range(3.0, 5.0)).timeout.connect(func():
			if multiplayer.is_server() and is_instance_valid(mission) and not mission.finished and is_inside_tree():
				mission.hatch_from(self))
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
	var _pt := PerfLog.t0()
	_pl_die(seeded)
	PerfLog.took("smrt civilisty", _pt)

func _pl_die(seeded: bool) -> void:
	var low := cowering
	if multiplayer.is_server() and (hidden or _hide_i >= 0):
		_unhide()
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

## Host: the brood tears its way out of a living carrier (on the way to the Kondor, or when its time comes).
func _hatch_now() -> void:
	follow = null
	_die.rpc(false)
	mission.hatch_from(self)

## Every machine: what gives a carrier away - only up close (hardcore: nothing on the screen).
const TELL_R := 4.0
static var _sick_mat: StandardMaterial3D
func _tells(delta: float) -> void:
	_tell_t -= delta
	if _tell_t > 0.0:
		return
	_tell_t = 0.25
	var me: Node = mission.local_player() if mission and mission.has_method("local_player") else null
	var near: bool = me != null and me.global_position.distance_to(global_position) < TELL_R
	if near != _tell_on:
		_tell_on = near
		if _sick_mat == null:
			_sick_mat = StandardMaterial3D.new()
			_sick_mat.albedo_color = Color(0.42, 0.55, 0.32, 0.38)
			_sick_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_sick_mat.roughness = 0.35
		for mi in body.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_overlay = _sick_mat if near else null
	if me != null and me.global_position.distance_to(global_position) < 7.0 and rng.randf() < 0.03:
		Game.play_at(mission, "groan", global_position + Vector3(0, 1.5, 0), -14.0)

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

## (0.72, Ari: „občas se nám vesničan zasekl ve zdi“) walking and getting nowhere - into a corner,
## a fence, a wall the path runs along: after a few seconds he gives that way up and goes somewhere
## else; and if he ever ends up inside a wall or a thing, he is put back out next to it.
var _prog_t := 0.0
var _prog_best := INF
var _prog_goal := Vector3.INF
const STUCK_AFTER := 2.6
func _progress(delta: float) -> void:
	var d := global_position.distance_to(goal)
	if goal != _prog_goal or d < _prog_best - 0.4:
		_prog_goal = goal
		_prog_best = d
		_prog_t = 0.0
		return
	_prog_t += delta
	if _prog_t < STUCK_AFTER:
		return
	_prog_t = 0.0
	_prog_best = INF
	_unstuck()

func _unstuck() -> void:
	# inside something: out next to it
	var ss := get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = 0.2
	cap.height = 1.2
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.collision_mask = Game.WORLD
	q.transform = Transform3D(Basis(), global_position + Vector3(0, 0.95, 0))
	if not ss.intersect_shape(q, 1).is_empty():
		global_position = _free_near(global_position)
	elif get_real_velocity().length() < 0.1 and get_slide_collision_count() > 0:
		global_position.y += 0.12     # (caught on a seam of the ground: every slide only hits the floor)
	# pinned between an open door and the wall (someone swung it into him): he pushes it shut and
	# goes round it - he opens it again from his own side if he still needs it
	var di: int = mission.door_near(global_position, 1.8)
	if di >= 0 and mission.doors[di]["open"] and not mission.doors[di].has("slide"):
		var leaf: Node3D = mission.doors[di]["body"]
		if is_instance_valid(leaf) and leaf.global_position.distance_to(global_position + Vector3(0, 1.0, 0)) < 1.3:
			mission._door_state.rpc(di, 0.0, false)
	if st == C.HIDE:
		_unhide()               # the way in is no good: he runs on instead
		st = C.FLEE
		fear_t = rng.randf_range(4.0, 7.0)
	# another way: a point to the side or back, somewhere he can stand
	var back := global_position - goal
	back.y = 0
	if back.length() < 0.1:
		back = Vector3(1, 0, 0)
	var dir := back.normalized().rotated(Vector3.UP, rng.randf_range(-1.4, 1.4))
	_go(_snap(global_position + dir * rng.randf_range(3.0, 7.0)))

## The nearest place round p (up to 4 m) where a person fits between walls and things.
func _free_near(p: Vector3) -> Vector3:
	var ss := get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.5
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.collision_mask = Game.WORLD
	q.exclude = [get_rid()]
	for r in [0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0]:
		var n := 1 if r == 0.0 else int(6 + r * 6)
		for i in n:
			var c: Vector3 = p + Vector3(cos(TAU * i / n), 0, sin(TAU * i / n)) * r
			c = _snap(c) if r > 0.0 else c
			if absf(c.y - p.y) > 1.0:
				continue
			q.transform = Transform3D(Basis(), c + Vector3(0, 0.85, 0))
			if ss.intersect_shape(q, 1).is_empty():
				return c
	return p

## (0.72) once the map stands (the physics is not up yet when he is placed): out of a wall or a
## thing he was put into
func _spawn_check() -> void:
	await get_tree().create_timer(0.6).timeout
	if not is_instance_valid(self) or dead or vip or not multiplayer.is_server() or _old_ai():
		return
	global_position = _free_near(global_position)

func _walk(speed: float, delta: float) -> void:
	if _arrived():
		velocity.x = 0; velocity.z = 0
		_prog_t = 0.0
		return
	if not _old_ai():
		_progress(delta)
	var nxt := agent.get_next_path_position()
	var dir := nxt - global_position
	dir.y = 0
	if dir.length() < 0.05:
		dir = goal - global_position
		dir.y = 0
	dir = dir.normalized()
	# (0.72) a shut door in the way: he opens it (a locked one stays shut, he goes round)
	_door_cd -= delta
	if _door_cd <= 0.0:
		_door_cd = 0.25
		var di: int = mission.door_near(global_position + dir * 0.6, 1.1)
		if di >= 0 and not mission.doors[di]["open"]:
			if mission.door_locked(di) and st == C.HIDE:
				mission.unlock_door(di, String(mission.doors[di]["locked"]), true)   # the one inside lets him in
			else:
				mission.open_door(di, global_position)
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	var want := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, want, delta * 8.0)
