extends RefCounted
## (2026-11-27, Ari: „když je velká mise, třeba teror, a zbývá poslední vetřelec, má tendence se
## někde schovat… někdy je to otrava ho hledat“) The last alien of a "crew down" mission does not
## hide for ever. When it has been out of the fight (nobody of the team sees it, it sees nobody) for
## a while, it gives up hiding:
##  - a soldier / officer / machine calls a ship and runs for it - to the UFO if there is one on the
##    map, otherwise to an open place away from the team. The ship hangs over the spot with its long
##    beam (like the reinforcements' drop ship); the team sees and hears where it is going - no
##    marker, no text on the screen (hardcore). In the beam it is lifted aboard and is gone: the job
##    is done, but the rating is worse and there is no body. Killed on the way = as always.
##    When the ship waits in vain (PICK_WAIT), it flies off and the alien comes for the team.
##  - a beast (Líhavec, Ohař, Nakažený) calls no ship: it comes out howling for whoever is nearest.
## Host only (only the host thinks for the aliens); the ship is an rpc, so everyone sees the same.
## `--nolast=1` turns it off (A/B), `--lastquiet=<s>` sets the waiting time (tests).

const QUIET := {"easy": 35.0, "normal": 45.0, "veteran": 60.0}
const MIN_CREW := 4           # only missions that had at least this many aliens
const PICK_WAIT := 50.0       # the ship waits over the spot this long
const PICK_R := 3.2           # flat distance from the beam that counts as "in it"
const PICK_LIFT := 2.6        # up the beam
const HUNT_EVERY := 8.0       # a hunting last one: a new run at the nearest man, a cry
const SEE_R := 35.0
const STUCK_S := 7.0          # no nearer to the beam for this long = stuck
const DROP_ALT := 30.0       # = mission.DROP_ALT (the ship's height)
const BEAM_AFTER := 6.2      # = mission.DROP_IN + DROP_BEAM (the beam reaches the ground)           # within this and in the line of sight = the team has found it

static func off() -> bool:
	return Game.cmd_arg("nolast", "") == "1"

static func quiet_time() -> float:
	var q := float(Game.cmd_arg("lastquiet", "-1"))
	if q >= 0.0:
		return q
	return float(QUIET.get(String(Net.mission_difficulty), 45.0))

static func _st(m: Node) -> Dictionary:
	if not m.has_meta("last_alien"):
		m.set_meta("last_alien", {"mode": "", "t": 0.0, "a": null, "at": Vector3.ZERO, "wait": 0.0, "cry": 0.0, "ship_used": false, "tw": null,
			"best": 1e9, "still": 0.0, "moves": 0})
	return m.get_meta("last_alien")

## Host, every frame of a running mission (from mission._late_tick).
static func tick(m: Node, delta: float) -> void:
	if off() or m.finished or not m._kill_all() or m.aliens_total < MIN_CREW:
		return
	var s := _st(m)
	var live: Array = m.aliens().filter(func(a): return not a.dead and not a.husk)
	match String(s["mode"]):
		"run":
			_run(m, s, delta)
			return
		"lift":
			_lifting(m, s)
			return
		"hunt":
			if live.size() > 1 or m._drops_pending > 0:
				s["mode"] = ""          # more of them came: they fight together again
			else:
				_hunt(m, s, delta)
			return
	if live.size() != 1 or m._drops_pending > 0:
		s["t"] = 0.0
		s["a"] = null
		return
	var a: Node = live[0]
	if a != s["a"]:
		s["a"] = a
		s["t"] = 0.0
	if a.race in ["mozek", "pylon"] or a.state == a.S.DRAG:
		return
	s["t"] = 0.0 if engaged(m, a) else float(s["t"]) + delta
	if float(s["t"]) < quiet_time():
		return
	if a.R.has("melee") or bool(s["ship_used"]):
		s["mode"] = "hunt"
		s["cry"] = 0.0
		if Game.autotest() != "": print("[LAST] %s (%s) comes out to hunt" % [a.name, a.race])
	else:
		_start(m, s, a)

## The team and the alien see each other (it has been found): no need to flush it out.
static func engaged(m: Node, a: Node) -> bool:
	if m.t - float(a._hit_t) < 4.0:
		return true
	for p in m.players():
		if p.dead:
			continue
		if p.global_position.distance_to(a.global_position) < SEE_R and a._los(p.global_position + Vector3(0, 1.5, 0)):
			return true
	return false

static func _sky_open(m: Node, p: Vector3) -> bool:
	var ss: PhysicsDirectSpaceState3D = m.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.6, 0), p + Vector3(0, DROP_ALT, 0), Game.WORLD | Game.GLASS)
	return ss.intersect_ray(q).is_empty()

## It can walk there (the paths go all the way, not just as near as they can).
static func _reachable(a: Node, p: Vector3) -> bool:
	var nm: RID = a.get_world_3d().navigation_map
	var path := NavigationServer3D.map_get_path(nm, a.global_position, p, true)
	return path.size() > 0 and Vector2(path[path.size() - 1].x - p.x, path[path.size() - 1].z - p.z).length() < PICK_R * 0.6

static func _team_mid(m: Node) -> Vector3:
	var c := Vector3.ZERO
	var n := 0
	for p in m.players():
		if not p.dead:
			c += p.global_position
			n += 1
	return c / float(n) if n > 0 else m.map.get("evac", Vector3.ZERO)

static func _ship_reach(m: Node) -> float:
	return 28.0 if String(m.map.get("ufo_kind", "")) in ["battleship", "supply"] else m._ship_r()

## Where the ship comes for it: by the UFO on the side away from the team, else an open place
## away from the team (not too far from the alien).
static func spot_for(m: Node, a: Node) -> Vector3:
	var mid := _team_mid(m)
	var ufo: Vector3 = m.map.get("ufo", Vector3.ZERO)
	if ufo != Vector3.ZERO and not m.bug_gone:
		var away := Vector3(ufo.x - mid.x, 0, ufo.z - mid.z)
		away = away.normalized() if away.length() > 0.5 else Vector3.FORWARD
		for extra in [3.0, 6.0, 10.0]:
			for i in 12:
				var ang := float(int((i + 1) / 2.0)) * 0.5 * (1.0 if i % 2 == 0 else -1.0)
				var p: Vector3 = ufo + away.rotated(Vector3.UP, ang) * (_ship_reach(m) + extra)
				p = a._snap(p)
				if p != Vector3.ZERO and _sky_open(m, p) and _reachable(a, p):
					return p
	var best := Vector3.INF
	var bs := -1e9
	for w in m.map.get("waypoints", []):
		var p: Vector3 = a._snap(w)
		if p == Vector3.ZERO or not _sky_open(m, p) or not _reachable(a, p):
			continue
		var near := 1e9
		for pl in m.players():
			if not pl.dead:
				near = minf(near, pl.global_position.distance_to(p))
		var sc: float = minf(near, 60.0) - 0.5 * a.global_position.distance_to(p)
		if sc > bs:
			bs = sc
			best = p
	if best == Vector3.INF:
		best = a._snap(a.global_position)     # (nowhere to run: the ship comes down where it is)
	return best

## Stuck: the nearest open sky right by it (not the place it could not get to).
static func _near_open(m: Node, a: Node, old: Vector3) -> Vector3:
	var here: Vector3 = a._snap(a.global_position)
	if here != Vector3.ZERO and _sky_open(m, here):
		return here
	for r in [2.5, 4.0, 6.0, 9.0, 13.0]:
		for i in 10:
			var p: Vector3 = a._snap(a.global_position + Vector3(r, 0, 0).rotated(Vector3.UP, TAU * i / 10.0))
			if p == Vector3.ZERO or Vector2(p.x - old.x, p.z - old.z).length() < PICK_R:
				continue
			if _sky_open(m, p) and _reachable(a, p):
				return p
	return here if here != Vector3.ZERO else old

static func _start(m: Node, s: Dictionary, a: Node) -> void:
	var at := spot_for(m, a)
	s["mode"] = "run"
	s["at"] = at
	s["wait"] = PICK_WAIT
	s["ship_used"] = true
	s["best"] = 1e9
	s["still"] = 0.0
	s["moves"] = 0
	a.escape_to = at
	var from := Vector3(at.x - _team_mid(m).x, 0, at.z - _team_mid(m).z).normalized()
	if from == Vector3.ZERO:
		from = Vector3.FORWARD
	m._pickup_fx.rpc(at, from)
	if Game.autotest() != "": print("[LAST] %s (%s) runs for the ship at %s (%.0f m)" % [a.name, a.race, at, a.global_position.distance_to(at)])

static func _run(m: Node, s: Dictionary, delta: float) -> void:
	var a = s["a"]
	if not is_instance_valid(a) or a.dead or a.husk:
		s["mode"] = "done"
		m._pickup_leave.rpc()
		return
	s["wait"] = float(s["wait"]) - delta
	var at: Vector3 = s["at"]
	var flat := Vector2(a.global_position.x - at.x, a.global_position.z - at.z).length()
	var beam_down: bool = float(s["wait"]) < PICK_WAIT - BEAM_AFTER
	# (after two moves the beam reaches a little further: it is stuck in some corner right by it)
	if beam_down and flat < (PICK_R if int(s["moves"]) < 2 else 5.5) and a.state != a.S.DRAG:
		_lift(m, s, a)
		return
	# stuck on the way (a car, a fence the paths do not know): the ship comes over to where it is
	if flat < float(s["best"]) - 1.0:
		s["best"] = flat
		s["still"] = 0.0
	else:
		s["still"] = float(s["still"]) + delta
	if float(s["still"]) > STUCK_S and int(s["moves"]) < 2:
		s["moves"] = int(s["moves"]) + 1
		s["still"] = 0.0
		var nat: Vector3 = _near_open(m, a, at)
		s["at"] = nat
		s["best"] = 1e9
		s["wait"] = PICK_WAIT
		a.escape_to = nat
		m._pickup_move.rpc(nat)
		if Game.autotest() != "": print("[LAST] %s stuck - the ship moves to %s" % [a.name, nat])
		return
	if float(s["wait"]) <= 0.0:
		a.escape_to = Vector3.INF
		m._pickup_leave.rpc()
		s["mode"] = "hunt"
		s["cry"] = 0.0
		if Game.autotest() != "": print("[LAST] the ship left without %s" % a.name)

static func _lift(m: Node, s: Dictionary, a: Node) -> void:
	s["mode"] = "lift"
	a.escape_to = Vector3.INF
	a.set_physics_process(false)
	a.velocity = Vector3.ZERO
	var tw: Tween = m.create_tween().bind_node(a)
	tw.tween_property(a, "global_position", a.global_position + Vector3(0, DROP_ALT - 3.0, 0), PICK_LIFT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if not is_instance_valid(a) or a.dead:
			return
		s["mode"] = "done"
		if Game.autotest() != "": print("[LAST] %s (%s) got away aboard" % [a.name, a.race])
		m._escaped_fx.rpc(String(a.race))
		a.queue_free()
		m._pickup_leave.rpc()
		m.get_tree().create_timer(0.2).timeout.connect(func(): if is_instance_valid(m): m._done_check()))
	s["tw"] = tw
	if Game.autotest() != "": print("[LAST] %s in the beam" % a.name)

## Shot dead up the beam: it falls.
static func _lifting(m: Node, s: Dictionary) -> void:
	var a = s["a"]
	if is_instance_valid(a) and a.dead:
		var tw = s.get("tw")
		if tw is Tween and (tw as Tween).is_valid():
			(tw as Tween).kill()
		a.set_physics_process(true)
		s["mode"] = "done"
		m._pickup_leave.rpc()

static func _hunt(m: Node, s: Dictionary, delta: float) -> void:
	var a = s["a"]
	if not is_instance_valid(a) or a.dead or a.husk:
		s["mode"] = "done"
		return
	s["cry"] = float(s["cry"]) - delta
	if float(s["cry"]) > 0.0 or engaged(m, a):
		return
	s["cry"] = HUNT_EVERY
	# a cry the team hears (where it comes from tells them where it is)
	var base := String(a.race).trim_suffix("_velitel")
	match base:
		"lihnoun":
			a._roar_fx.rpc()
		"ohar":
			a._howl_fx.rpc()
			m._ambient.rpc("growl", a.global_position + Vector3.UP, 2.0)
		"zombie":
			m._ambient.rpc("zombie_groan", a.global_position + Vector3.UP, 2.0)
		"grey", "levit", "myslodej":
			m._ambient.rpc("alien", a.global_position + Vector3.UP, 0.0)
		"diskoll", "kolos":
			pass                 # machines hum and clank on their own
		_:
			m._ambient.rpc("roar", a.global_position + Vector3.UP, 0.0)
	if a.has_method("_hunt_somebody"):
		a._hunt_somebody()
		return
	var best: Node = null
	var bd := 1e9
	for p in m.players():
		if p.dead:
			continue
		var d: float = p.global_position.distance_to(a.global_position)
		if d < bd:
			bd = d
			best = p
	if best:
		if a.state == a.S.COMBAT:
			a.state = a.S.LURK      # out of its hole
		a.stalk(best)
		a.alert = true
