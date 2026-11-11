extends RefCounted
## The aliens' fighting sense beyond the single alien's state machine (0.57, the AI plan, steps 1-2):
## - every mercenary it knows about counts as a threat, not just the one it last saw (co-op: cover
##   and firing spots are judged against all of them, the rear is not open to the second man)
## - a target is chosen by what he does to them, not only by how near he is
## - a live grenade near by: it gets out of the way (if it noticed it in time)
## - a fallen comrade is seen and feared; the shaken pull back towards the others to regroup
## - a lost mercenary is searched for: the hiding places round where he was, one after another,
##   the squad sharing them out, instead of turning on the spot
## Only the host thinks. Everything is a static function on the alien (alien.gd keeps the state).
## --oldai=1 turns it all off (A/B tests against the old behaviour).

const KNOW_SECS := 25.0          # how long a sighting of a mercenary still counts as a threat
const NADE_SEE := 7.5            # a grenade this close is a danger
const NADE_SAFE := 7.5           # and this far away is safe
const SEARCH_SPOTS := 4
const SQUAD := "res://scripts/alien_squad.gd"

static func off() -> bool:
	return Game.cmd_arg("oldai", "") == "1"

# ---- what it knows about the mercenaries -------------------------------------------------------
## Remember where @a p was seen (its own eyes, a squad mate's shout, a drone).
static func saw(a: Node, p: Node) -> void:
	if p == null or not is_instance_valid(p) or a.mission == null:
		return
	a._seen_pos[String(p.name)] = [p.global_position, a.mission.t]

## The places the threats are, as far as this alien knows (eye height): every mercenary still
## standing that it has seen or been told about in the last KNOW_SECS.
static func threats(a: Node) -> Array:
	if a._thr_t == a.mission.t:
		return a._thr_cache
	var out := []
	for p in a.mission.players():
		if p.dead or p.downed or p.has_meta("ghost"):
			continue
		var k := String(p.name)
		var pos := Vector3.INF
		if a._knows(p):
			pos = p.global_position
		elif a._seen_pos.has(k) and a.mission.t - float(a._seen_pos[k][1]) < KNOW_SECS:
			pos = a._seen_pos[k][0]
		if pos != Vector3.INF:
			out.append(pos + Vector3(0, 1.3, 0))
	a._thr_t = a.mission.t
	a._thr_cache = out
	return out

## How many of the threats other than the one at @a primary would see a body at @a c (height @a h).
static func exposure_extra(a: Node, c: Vector3, primary: Vector3, h := 1.0) -> int:
	if off():
		return 0
	var n := 0
	var ss: PhysicsDirectSpaceState3D = a.get_world_3d().direct_space_state
	for t in threats(a):
		var tp: Vector3 = t
		if Vector2(tp.x - primary.x, tp.z - primary.z).length() < 3.0:
			continue
		if tp.distance_to(c) > 70.0:
			continue
		var q := PhysicsRayQueryParameters3D.create(tp, c + Vector3(0, h, 0), Game.WORLD)
		if ss.intersect_ray(q).is_empty():
			n += 1
	return n

## How many threats in all see @a c (for the test log and the fall-back).
static func exposure_all(a: Node, c: Vector3, h := 1.0) -> int:
	var n := 0
	var ss: PhysicsDirectSpaceState3D = a.get_world_3d().direct_space_state
	for t in threats(a):
		var q := PhysicsRayQueryParameters3D.create(t, c + Vector3(0, h, 0), Game.WORLD)
		if ss.intersect_ray(q).is_empty():
			n += 1
	return n

## Target choice: the man who is hurting them comes first, then a badly wounded one (hardcore:
## they finish what they started). Lower = preferred (added to the distance score).
static func target_bias(a: Node, p: Node) -> float:
	if off():
		return 0.0
	var b := 0.0
	var k := String(p.name)
	if a._hurt_by.has(k) and a.mission.t - float(a._hurt_by[k]) < 10.0:
		b -= 8.0
	if "max_hp" in p and float(p.max_hp) > 0.0 and float(p.hp) < float(p.max_hp) * 0.35:
		b -= 4.0
	return b

# ---- every think: grenades and fear -------------------------------------------------------------
static func tick(a: Node, delta: float) -> void:
	if off() or a.dead or a.husk:
		return
	a._fear = maxf(0.0, a._fear - 0.015 * delta)
	if a._dodge_t > 0.0:
		a._dodge_t -= delta
		if a._dodge_t <= 0.0:
			_dodge(a)
		return
	a._nade_chk -= delta
	if a._nade_chk > 0.0:
		return
	a._nade_chk = 0.2
	if a.state == a.S.DRAG or a.R.get("dumb", false) or a._frenzy:
		return
	for n in a.get_tree().get_nodes_in_group("live_nade"):
		if not is_instance_valid(n) or not (n is Node3D):
			continue
		var np: Vector3 = (n as Node3D).global_position
		var id: int = n.get_instance_id()
		if a._nades_seen.has(id):
			continue
		var d: float = a.global_position.distance_to(np)
		if d > NADE_SEE:
			continue
		# it has to notice it: the thud close by, or in sight
		if d > 2.5 and not a._los(np + Vector3(0, 0.15, 0)):
			continue
		a._nades_seen[id] = true
		var notice: float = 0.85 if Game.veteran() else (0.5 if Game.easy() else 0.7)
		if a.rng.randf() > notice:
			a._tlog("nade missed")
			continue
		a._nade_at = np
		a._dodge_t = a.rng.randf_range(0.2, 0.55) * a._react_k
		return

static func _dodge(a: Node) -> void:
	var np: Vector3 = a._nade_at
	var ss: PhysicsDirectSpaceState3D = a.get_world_3d().direct_space_state
	var best := Vector3.INF
	var bs := 1e9
	for c in a.mission.map["cover"]:
		var cp: Vector3 = c
		var d: float = a.global_position.distance_to(cp)
		if d > 11.0 or cp.distance_to(np) < NADE_SAFE:
			continue
		var sc: float = d
		# behind something from the blast is best
		var q := PhysicsRayQueryParameters3D.create(np + Vector3(0, 0.3, 0), cp + Vector3(0, 0.6, 0), Game.WORLD)
		if not ss.intersect_ray(q).is_empty():
			sc -= 4.0
		# do not run across the blast to get there
		var mid: Vector3 = (cp + a.global_position) * 0.5
		if mid.distance_to(np) < 3.0:
			sc += 10.0
		sc += exposure_all(a, cp, 0.8) * 3.0
		if sc < bs:
			bs = sc
			best = cp
	if best == Vector3.INF:
		var away: Vector3 = a.global_position - np
		away.y = 0
		if away.length() < 0.1:
			away = Vector3(1, 0, 0)
		best = a._snap(a.global_position + away.normalized() * 8.5)
	a._tlog("dodge nade d%.1f" % a.global_position.distance_to(np))
	a.set_meta("dodged", int(a.get_meta("dodged", 0)) + 1)
	if a.state != a.S.COMBAT:
		a._enter_combat(null)
	a._go(best)
	a.phase = "move"
	a.react = maxf(a.react, 0.4)

## A comrade has fallen at @a at (killed by @a by, maybe unknown). Those who see it are shaken;
## those who were not fighting come to look - carefully, from cover, not straight to the body.
static func comrade_down(dead: Node, by: Node) -> void:
	if off() or dead.mission == null:
		return
	var at: Vector3 = dead.global_position + Vector3(0, 0.8, 0)
	for a in dead.mission.aliens():
		if a == dead or a.dead or a.husk or a.R.get("dumb", false):
			continue
		var d: float = a.global_position.distance_to(at)
		if d > 45.0:
			continue
		var sees: bool = a._los(at)
		if not sees and d > 12.0:
			continue
		a._fear += 0.35 if d < 25.0 else 0.2
		if by and is_instance_valid(by) and by.has_method("is_player") and a.visible_to(by):
			a._know(by, 8.0)
		if a.state == a.S.LURK or a.state == a.S.SEARCH or a.state == a.S.INVESTIGATE:
			a.alert = true
			a.lurking = false
			a.state = a.S.INVESTIGATE
			a.last_seen = at
			var away: Vector3 = a.global_position - at
			away.y = 0
			a._go(a._snap(at + (away.normalized() if away.length() > 0.1 else Vector3.FORWARD) * a.rng.randf_range(5.0, 8.0)))
			a._tlog("body seen")

## Badly hurt: it is shaken too (once).
static func wounded(a: Node) -> void:
	if off() or a._hurt_scare:
		return
	a._hurt_scare = true
	a._fear += 0.3

## Shaken (comrades fell, it is hurt, the officer is gone): pull back from all of them towards the
## others, regroup, then fight on. Not the beasts, the frenzied, the painless or an officer's men.
static func maybe_fall_back(a: Node) -> bool:
	if off() or a._fear < 0.7 or a._rally_t > 0.0 or a._frenzy:
		return false
	if not a.tac in ["soldier", "hunter", "grey", "psi"] or a.R.has("no_pain") or a.R.has("melee"):
		return false
	if a.nemesis and is_instance_valid(a.nemesis) and not a.nemesis.dead:
		return false
	var thr: Array = threats(a)
	if thr.is_empty():
		return false
	var ss: PhysicsDirectSpaceState3D = a.get_world_3d().direct_space_state
	var near0: float = _nearest_threat(a.global_position, thr)
	var best := Vector3.INF
	var bs := 1e9
	for c in a.mission.map["cover"]:
		var cp: Vector3 = c
		var d: float = a.global_position.distance_to(cp)
		if d > 28.0 or d < 4.0:
			continue
		var nd: float = _nearest_threat(cp, thr)
		if nd < near0 + 6.0:
			continue          # it has to be further from all of them
		var seen := 0
		for t in thr:
			var q := PhysicsRayQueryParameters3D.create(t, cp + Vector3(0, 0.9, 0), Game.WORLD)
			if ss.intersect_ray(q).is_empty():
				seen += 1
		var sc: float = d * 0.5 + seen * 15.0 - minf(nd, 40.0) * 0.3
		# towards the others (not alone in the dark)
		var mate := 1e9
		for o in a.mission.aliens():
			if o != a and not o.dead and not o.husk:
				mate = minf(mate, o.global_position.distance_to(cp))
		sc += minf(mate, 30.0) * 0.4
		if sc < bs:
			bs = sc
			best = cp
	if best == Vector3.INF:
		return false
	a._fear = maxf(0.0, a._fear - 0.45)
	a._tlog("fall back")
	a.set_meta("fell_back", int(a.get_meta("fell_back", 0)) + 1)
	a._go(best)
	a.phase = "move"
	return true

static func _nearest_threat(p: Vector3, thr: Array) -> float:
	var m := 1e9
	for t in thr:
		m = minf(m, Vector2(p.x - t.x, p.z - t.z).length())
	return m

# ---- searching --------------------------------------------------------------------------------
## Lost him: the hiding places round where he was, nearest first, none that a squad mate already
## goes to look at. Returns false when off (the old turning on the spot).
static func begin_search(a: Node, secs: float) -> bool:
	if off():
		return false
	a.state = a.S.SEARCH
	a.search_t = secs + 12.0
	a._srch_look = a.rng.randf_range(1.5, 3.0)
	var claimed := []
	for o in a.mission.aliens():
		if o != a and not o.dead and o.state == a.S.SEARCH:
			claimed.append_array(o._search_spots)
	var cand := []
	var sq = load(SQUAD)          # (0.63: the heat map - where they have been seen before - pulls the search)
	for c in a.mission.map["cover"]:
		var cp: Vector3 = c
		var dl: float = cp.distance_to(a.last_seen)
		if dl > 30.0 or cp.distance_to(a.global_position) < 2.0:
			continue
		var heat: float = minf(12.0, sq.heat_at(a.mission, cp, 8.0))
		if dl > 16.0 and heat < 3.0:
			continue
		var taken := false
		for s in claimed:
			if (s as Vector3).distance_to(cp) < 3.0:
				taken = true
				break
		if not taken:
			cand.append([dl + a.rng.randf() * 5.0 - heat * (0.5 if dl <= 16.0 else 1.2), cp])
	cand.sort_custom(func(x, y): return x[0] < y[0])
	a._search_spots = []
	for i in mini(SEARCH_SPOTS, cand.size()):
		a._search_spots.append(cand[i][1])
	a._tlog("search %d spots" % a._search_spots.size())
	return true

static func search_tick(a: Node, delta: float) -> bool:
	if off():
		return false
	a.search_t -= delta
	if a.search_t <= 0.0:
		a.alert = false
		a._search_spots = []
		a._go_lurk(true)
		return true
	if a._srch_look > 0.0:
		# at a spot: still, looking round
		a.lurking = true
		a.velocity.x = 0; a.velocity.z = 0
		a.rotation.y += delta * 1.1 * (1.0 if int(a.search_t) % 4 < 2 else -1.0)
		a._srch_look -= delta
		if a._srch_look <= 0.0 and not a._search_spots.is_empty():
			a._go(a._search_spots.pop_front())
		return true
	a.lurking = false
	a._walk(a.walk_spd * 1.15, delta)
	if a._arrived():
		a._srch_look = a.rng.randf_range(1.5, 3.0) if not a._search_spots.is_empty() else a.search_t
	return true

# ---- cover that is cover for all of them ---------------------------------------------------------
## Arrived to hide, but one of them has it in plain sight: on to a place none of them sees
## (not more often than every 4 s, so it does not run round in circles). True = it is moving on.
static func rehide(a: Node) -> bool:
	if off() or a.mission.t - a._rehide_t < 4.0 or a.tac in ["levit", "brute"] or a.R.has("melee") or a.flying or a.airborne:
		return false
	if threats(a).size() < 2 or exposure_all(a, a.global_position, 0.8) == 0:
		return false          # (alone against one man the old way is fine: it hid from him)
	a._rehide_t = a.mission.t
	var best := Vector3.INF
	var bs := 1e9
	for c in a.mission.map["cover"]:
		var cp: Vector3 = c
		var d: float = a.global_position.distance_to(cp)
		if d > 10.0 or d < 1.0:
			continue
		if exposure_all(a, cp, 0.8) > 0:
			continue
		if d < bs:
			bs = d
			best = cp
	if best == Vector3.INF:
		return false
	a._tlog("rehide")
	a._go(best)
	a.phase = "move"
	return true

## A side approach: of a few ways round, the one the other mercenaries do not watch.
static func pick_flank(a: Node, p: Vector3, v: Vector3) -> Vector3:
	if off() or threats(a).size() < 2:
		return p
	var prim: Vector3 = a.last_seen + Vector3(0, 1.3, 0)
	var best := p
	var bs: float = exposure_extra(a, p, prim) * 10.0 + p.distance_to(a.global_position) * 0.3
	for i in 3:
		var ang: float = a.rng.randf_range(1.2, 2.3) * (1.0 if a.rng.randf() < 0.5 else -1.0)
		var c: Vector3 = a._snap(a.last_seen + v.normalized().rotated(Vector3.UP, ang) * a.rng.randf_range(7.0, 12.0))
		var sc: float = exposure_extra(a, c, prim) * 10.0 + c.distance_to(a.global_position) * 0.3
		if sc < bs:
			bs = sc
			best = c
	return best

## Duck where it stands after a burst? Only if crouched it is out of sight of all of them
## (one man: the old way, the low cover in front of him is enough).
static func duck_ok(a: Node) -> bool:
	if off() or threats(a).size() < 2:
		return true
	return exposure_all(a, a.global_position, 0.6) <= 1 and exposure_extra(a, a.global_position, a.last_seen + Vector3(0, 1.3, 0), 0.6) == 0

## A shot heard: even without seeing the flash it roughly knows the direction it came from - a
## threat to keep cover against (not a target: for shooting it has to see him).
static func heard_shot(a: Node, pos: Vector3) -> void:
	if off() or a.global_position.distance_to(pos) > 70.0:
		return
	for p in a.mission.players():
		if p.dead or p.global_position.distance_to(pos) > 2.0:
			continue
		var k := String(p.name)
		if a._seen_pos.has(k) and a.mission.t - float(a._seen_pos[k][1]) < 2.0:
			continue
		var fuzz := Vector3(a.rng.randf_range(-2.0, 2.0), 0, a.rng.randf_range(-2.0, 2.0))
		a._seen_pos[k] = [pos + fuzz, a.mission.t]
