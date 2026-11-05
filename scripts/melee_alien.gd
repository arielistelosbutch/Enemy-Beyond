extends "res://scripts/alien.gd"
## Melee races. The host thinks for them.
##  Líhavec - near-black, very fast. Waits in the dark until somebody is alone or
##            looking away, then runs in, strikes and is gone again. A body it
##            kills does not stay dead: a civilian rises as a Nakažený in seconds,
##            a mercenary who bleeds out with its seed inside rises too.
##  Nakažený - what is left of the victim. Slow, relentless. When it falls, or
##            after a while anyway, a new Líhavec tears its way out.
##  Ohař     - blind beast. Hunts by sound: anything that makes noise brings it
##            running. Up close it smells you. Walk slowly and it may pass by.

var prey: Node = null
var strike_cd := 0.0
var windup := 0.0
var retreat_t := 0.0
var repath_t := 0.0
var voice_t := 3.0
var life_t := 0.0         # Nakažený: time until the thing inside comes out
var heard_t := 0.0
var _misses := 0
var _ignore := {}          # prey it could not reach -> time until it tries again

func _ready() -> void:
	super._ready()
	agent.radius = float(R["r"]) + 0.1
	if race == "zombie":
		life_t = rng.randf_range(70.0, 95.0)
		state = S.SEARCH
	if race == "lihnoun":
		voice_t = rng.randf_range(2.0, 6.0)

func _physics_process(delta: float) -> void:
	_voice(delta)
	if race == "lihnoun" and not dead and multiplayer.is_server():
		# now and then its roar carries over the whole map: you know it is out there
		_roar_t -= delta
		if _roar_t <= 0.0:
			_roar_t = randf_range(70.0, 130.0)
			_roar_fx.rpc()
		# the dread: whoever sees it close knows what it does to people
		_dread_t -= delta
		if _dread_t <= 0.0:
			_dread_t = 1.5
			for p in mission.players():
				if p.dead or p.downed or p.global_position.distance_to(global_position) > 16.0:
					continue
				if _los(p.global_position + Vector3(0, 1.5, 0)):
					p.dread.rpc_id(p.get_multiplayer_authority(), 5.0)
	super._physics_process(delta)

var _dread_t := 0.0

var _roar_t := randf_range(25.0, 50.0)
@rpc("authority", "call_local", "reliable")
func _roar_fx() -> void:
	if mission == null or not mission.is_inside_tree():
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = Game.sound("lihnoun_roar")
	p.volume_db = 4.0
	p.unit_size = 30.0
	p.max_distance = 260.0
	p.bus = "SFX"
	mission.add_child(p)
	p.global_position = global_position + Vector3.UP
	p.play()
	p.finished.connect(p.queue_free)
	var me: Node = mission.local_player()
	if me and not me.dead:
		me.stress = minf(100.0, me.stress + 4.0)

## Every machine: the sound the creature makes near the local player.
func _voice(delta: float) -> void:
	if dead:
		return
	voice_t -= delta
	if voice_t > 0:
		return
	var me: Node = mission.local_player() if mission else null
	var d := 99.0 if me == null else global_position.distance_to(me.global_position)
	match race:
		"lihnoun":
			voice_t = randf_range(1.5, 4.0) if _speed > 2.0 else randf_range(5.0, 11.0)
			if d < 26.0:
				Game.play_at(mission, "skitter", global_position, -4 if _speed > 2.0 else -10)
		"zombie":
			voice_t = randf_range(4.0, 9.0)
			if d < 30.0:
				Game.play_at(mission, "zombie_groan" if randf() < 0.6 else "groan", global_position, -6)
		"ohar":
			voice_t = randf_range(3.0, 7.0) if alert else randf_range(8.0, 16.0)
			if d < 40.0:
				Game.play_at(mission, "growl" if alert else "sniff", global_position, -3 if alert else -9)

func _go_lurk(move_far: bool) -> void:
	if race == "zombie":
		state = S.SEARCH
		search_t = 4.0
		return
	super._go_lurk(move_far)

# ---- senses ----------------------------------------------------------------------------
## Players and (for the Líhavec) civilians it notices right now.
func _sense(p: Node) -> bool:
	var d: float = global_position.distance_to(p.global_position)
	if R.has("blind"):
		# smell up close, louder when the prey moves fast
		var v := Vector2(p.velocity.x, p.velocity.z).length() if "velocity" in p else 0.0
		return d < (4.5 + v * 0.8)
	if race == "lihnoun" and d < 7.0:
		return true      # this close it feels you - breath, heat, heartbeat
	if p.has_method("is_player"):
		if p.downed:
			return d < 14.0 and _los(p.global_position + Vector3(0, 0.4, 0))
		return visible_to(p)
	# civilians: no flashlight, but they panic and run - easy to see
	if d > 22.0:
		return false
	return _los(p.global_position + Vector3(0, 1.0, 0))

func _pick_prey() -> Node:
	var best: Node = null
	var bs := 1e9
	for p in mission.players():
		if p.dead or p.has_meta("ghost"):
			continue
		if p.downed and race != "lihnoun":
			continue
		if _ignore.get(p, -1.0) > mission.t:
			continue
		if _sense(p):
			var sc := global_position.distance_to(p.global_position)
			if p.downed:
				sc -= 4.0     # it finishes what it started
			if sc < bs:
				bs = sc
				best = p
	if true:
		for c in mission.civilians():
			if c.dead or c.infected or c.saved or _ignore.get(c, -1.0) > mission.t:
				continue
			if _sense(c):
				var sc2 := global_position.distance_to(c.global_position) - (6.0 if race == "lihnoun" else 0.0)
				if sc2 < bs:
					bs = sc2
					best = c
	return best

func hear(pos: Vector3, radius: float) -> void:
	if dead:
		return
	if R.has("blind"):
		radius *= 1.6      # it lives by its ears
	if global_position.distance_to(pos) > radius:
		return
	alert = true
	last_seen = pos
	heard_t = 6.0
	if state != S.COMBAT:
		state = S.INVESTIGATE
		lurking = false
		_go(_snap(pos))

func stalk(p: Node) -> void:
	if dead or state == S.COMBAT:
		return
	state = S.STALK
	target = p
	lurking = false
	_go(_snap(p.global_position + (global_position - p.global_position).normalized() * (5.0 if race == "lihnoun" else 9.0)))

func lurk_at(pos: Vector3) -> void:
	if race == "zombie":
		return
	super.lurk_at(pos)

func damage(dmg: float, from: Vector3, by: Node) -> void:
	if dead:
		return
	if Game.has_research("pitva_lihnoun") and (race == "lihnoun" or race == "zombie"):
		dmg *= 1.3
	hp -= taken(dmg)
	alert = true
	if hp <= 0:
		_die.rpc()
		if by and by.has_method("is_player"):
			_credit.rpc_id(by.get_multiplayer_authority(), by.name)
		if race == "zombie":
			_hatch_later(1.2)
		return
	last_seen = from
	match race:
		"lihnoun":
			# badly hurt: melt back into the dark and come again later
			if hp < float(R["hp"]) * 0.4 and rng.randf() < 0.6:
				_retreat(rng.randf_range(5.0, 9.0))
			elif by and by.has_method("is_player") and not by.downed:
				prey = by
				state = S.COMBAT
				lurking = false
				_charging = true      # hurt: no more creeping
				_charge_prey = by
		_:
			if by and by.has_method("is_player"):
				prey = by
				state = S.COMBAT
				lurking = false
				_charging = true      # hurt: no more creeping
				_charge_prey = by

func stun(amount: float, from: Vector3, by: Node) -> void:
	if race == "zombie":
		damage(amount * 0.3, from, by)   # nothing left in there to knock out
		return
	super.stun(amount, from, by)

func _retreat(secs: float) -> void:
	_charging = false
	retreat_t = secs
	state = S.LURK
	prey = null
	striking = false
	var from := last_seen
	_relocate(from)

# ---- brain (host) ---------------------------------------------------------------------------
func _think(delta: float) -> void:
	strike_cd -= delta
	repath_t -= delta
	heard_t -= delta
	if race == "zombie":
		life_t -= delta
		if life_t <= 0:
			_die.rpc()
			_hatch_later(0.3)
			return
	if windup > 0:
		_strike_tick(delta)
		return
	if retreat_t > 0:
		retreat_t -= delta
		lurking = false
		_walk(run_spd, delta)
		if _arrived():
			lurking = true
			velocity.x = 0; velocity.z = 0
		if retreat_t <= 0:
			state = S.LURK
			wait = rng.randf_range(4.0, 10.0)
		return
	var seen := _pick_prey()
	# the first quiet minute belongs to the night, not to the claws
	if seen and mission.calm() and race != "zombie" and global_position.distance_to(seen.global_position) > 6.0:
		seen = null
	if seen:
		prey = seen
		state = S.COMBAT
		alert = true
	if state == S.COMBAT:
		_hunt(delta)
		return
	match state:
		S.LURK:
			if race == "lihnoun":
				# waits in the dark - then goes hunting on its own: the nearest
				# living thing, approached from the dark side
				wait -= delta
				if _arrived():
					lurking = true
					velocity.x = 0; velocity.z = 0
					if wait <= 0:
						if not mission.calm() and rng.randf() < 0.7:
							_hunt_somebody()
						else:
							_go_lurk(true)
				else:
					lurking = false
					_walk(walk_spd * 1.4, delta)
			else:
				wait -= delta
				if _arrived():
					lurking = race == "ohar"
					velocity.x = 0; velocity.z = 0
					if wait <= 0:
						_go_lurk(true)
				else:
					_walk(walk_spd, delta)
		S.INVESTIGATE, S.STALK:
			lurking = false
			_walk(run_spd if (race == "ohar" or (race == "lihnoun" and state == S.STALK)) else walk_spd * 1.5, delta)
			if state == S.STALK and race == "lihnoun" and is_instance_valid(target) and not target.dead \
					and global_position.distance_to(target.global_position) < 9.0:
				prey = target      # close enough: the run-in
				state = S.COMBAT
				return
			if _arrived():
				state = S.SEARCH
				search_t = rng.randf_range(4.0, 9.0)
		S.SEARCH:
			if race == "zombie":
				# shamble towards the nearest living thing it can find
				search_t -= delta
				if search_t <= 0 or _arrived():
					search_t = rng.randf_range(5.0, 9.0)
					var near: Node = null
					for p in mission.players():
						if not p.dead and (near == null or p.global_position.distance_to(global_position) < near.global_position.distance_to(global_position)):
							near = p
					if near and near.global_position.distance_to(global_position) < 45.0:
						_go(_snap(near.global_position + Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4))))
					else:
						_go(_snap(global_position + Vector3(rng.randf_range(-8, 8), 0, rng.randf_range(-8, 8))))
				_walk(walk_spd, delta)
				return
			search_t -= delta
			velocity.x = 0; velocity.z = 0
			rotation.y += delta * 0.8
			if search_t <= 0:
				alert = false
				_go_lurk(true)

## Melee creatures must reach their prey even where the nav mesh gives up:
## when the path ends short of the goal, they go straight at it.
func _arrived() -> bool:
	return global_position.distance_to(goal) < 1.0

func _walk(speed: float, delta: float) -> void:
	if _arrived():
		velocity.x = 0
		velocity.z = 0
		return
	var dir: Vector3
	if agent.is_navigation_finished():
		dir = goal - global_position
	else:
		dir = agent.get_next_path_position() - global_position
	dir.y = 0
	if dir.length() < 0.05:
		dir = goal - global_position
		dir.y = 0
	dir = dir.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_face(global_position + dir, delta)
	# stuck against something: give up this goal
	if get_slide_collision_count() > 0 and Vector2(get_real_velocity().x, get_real_velocity().z).length() < speed * 0.2:
		_stuck_t += delta
		if _stuck_t > 1.5:
			_stuck_t = 0.0
			goal = global_position
			if state == S.COMBAT:
				_go(_snap(goal + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))))
	else:
		_stuck_t = 0.0

var _stuck_t := 0.0

func _hunt_somebody() -> void:
	var best: Node = null
	var bd := 1e9
	for p in mission.players() + mission.civilians():
		if p.dead or ("saved" in p and p.saved) or ("infected" in p and p.infected and not p.has_method("is_player")):
			continue
		var d: float = global_position.distance_to(p.global_position)
		if p.has_method("is_player"):
			# a lone mercenary counts as close
			var alone := true
			for o in mission.players():
				if o != p and not o.dead and o.global_position.distance_to(p.global_position) < 8.0:
					alone = false
			d *= 0.6 if alone else 1.0
		if d < bd:
			bd = d
			best = p
	if best:
		stalk(best)
	else:
		_go_lurk(true)

var _charging := false
var _charge_prey: Node = null
@rpc("authority", "call_local", "reliable")
func _charge_fx() -> void:
	Game.play_at(mission, "ohar_charge" if race == "ohar" else ("lihnoun_charge" if race == "lihnoun" else "hiss"), global_position + Vector3.UP, 4 if race == "ohar" else 2)

## The Ohař's roar as it breaks cover: the green ones freeze for a moment (bravery and missions help).
func _roar_scare() -> void:
	for p in mission.players():
		if p.dead or p.downed or p.global_position.distance_to(global_position) > 20.0:
			continue
		p.ohar_roar.rpc_id(p.get_multiplayer_authority(), rng.randf())

var _lunge_t := 0.0
var _lunge_cd := 0.0
func _hunt(delta: float) -> void:
	lurking = false
	if not is_instance_valid(prey) or prey != _charge_prey:
		_charging = false
		_charge_prey = prey
	if not is_instance_valid(prey) or prey.dead or (prey.has_method("is_player") and prey.downed and race != "lihnoun") \
			or (not prey.has_method("is_player") and prey.infected):
		prey = null
		state = S.SEARCH
		search_t = 3.0
		return
	var pp: Vector3 = prey.global_position
	var d := global_position.distance_to(pp)
	# lost it? (out of senses for a while)
	if not _sense(prey):
		unseen_t += delta
		if unseen_t > (4.0 if race != "zombie" else 12.0):
			last_seen = pp
			state = S.INVESTIGATE
			_go(_snap(last_seen))
			unseen_t = 0.0
			return
	else:
		unseen_t = 0.0
	var reach := float(R["reach"])
	if d < reach:
		velocity.x = 0; velocity.z = 0
		_face(pp, delta * 2.0)
		if strike_cd <= 0:
			windup = 0.32 if race != "zombie" else 0.55
			_strike_anim.rpc(true)
		return
	if repath_t <= 0:
		repath_t = 0.25
		_go(_snap(pp))
	var spd := run_spd
	if race == "zombie":
		# dull and slow - and then, close up, a sudden desperate lunge
		_lunge_cd -= delta
		if _lunge_t > 0.0:
			_lunge_t -= delta
			spd = run_spd * 2.6
		elif d < 4.5 and _lunge_cd <= 0.0:
			_lunge_cd = rng.randf_range(4.0, 8.0)
			if rng.randf() < 0.6:
				_lunge_t = 0.7
				_charge_fx.rpc()
	var pc: Array = R.get("pounce", [])
	if not pc.is_empty():
		# creep in low and quiet - then, close enough, the mad dash
		if not _charging and d > float(pc[0]):
			spd = walk_spd * 1.15
			lurking = true
		else:
			if not _charging:
				_charging = true
				_charge_fx.rpc()
				if race == "ohar":
					_roar_scare()
			spd = run_spd * float(pc[1])
	_walk(spd, delta)

func _strike_tick(delta: float) -> void:
	velocity.x = 0; velocity.z = 0
	windup -= delta
	if is_instance_valid(prey):
		_face(prey.global_position, delta * 2.0)
	if windup > 0:
		return
	strike_cd = float(R["strike_cd"]) * rng.randf_range(0.85, 1.2)
	get_tree().create_timer(0.35).timeout.connect(func(): if is_inside_tree(): _strike_anim.rpc(false))
	if not is_instance_valid(prey) or prey.dead:
		return
	if global_position.distance_to(prey.global_position) > float(R["reach"]) + 0.5:
		Game.play_at(mission, "swish", global_position, -4)
		_misses += 1
		if _misses >= 3:
			# cannot get at it (behind a wall, inside): leave it for a while
			_ignore[prey] = mission.t + 20.0
			prey = null
			_misses = 0
			state = S.SEARCH
			search_t = 2.0
		return
	_misses = 0
	var dmg := rng.randf_range(R["melee"][0], R["melee"][1]) * (1.3 if Game.veteran() else 1.0)
	mission.combat_t = mission.t
	if prey.has_method("is_player"):
		prey.hurt.rpc_id(prey.get_multiplayer_authority(), dmg, global_position)
		if R.has("implant"):
			prey.implant.rpc_id(prey.get_multiplayer_authority())
		_hit_fx.rpc(prey.global_position + Vector3(0, 1.0, 0))
		# Líhavec: strike, then gone again - sometimes
		if race == "lihnoun" and not prey.downed and rng.randf() < 0.45:
			_retreat(rng.randf_range(2.5, 5.0))
	else:
		_hit_fx.rpc(prey.global_position + Vector3(0, 1.0, 0))
		prey.killed_by(race)
		prey = null

@rpc("authority", "call_local", "reliable")
func _strike_anim(on: bool) -> void:
	striking = on
	if on:
		Game.play_at(mission, "lunge" if race != "zombie" else "groan", global_position, -2)

@rpc("authority", "call_local", "reliable")
func _hit_fx(p: Vector3) -> void:
	Game.play_at(mission, "slash", p, 0)
	mission.blood_fx(p)

## Nakažený: the thing inside tears its way out.
func _hatch_later(secs: float) -> void:
	var at := global_position
	get_tree().create_timer(secs).timeout.connect(func():
		if multiplayer.is_server() and not mission.finished:
			mission.burst_fx.rpc(at + Vector3(0, 1.0, 0), true)
			mission.spawn_alien("lihnoun", at))
