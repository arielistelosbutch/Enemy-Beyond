extends RefCounted
## An alien's choice of the next move by weighing the options (0.64, the AI plan, step 7: utility
## scoring), what it knows of how each mercenary fights (step 5, the campaign's "styles") and the
## honest hunt of a marked man (nemesis).
## Only the host thinks; static functions on the alien (alien.gd keeps the state). --oldai=1 = the
## old fixed order of checks.
##
## choose_move: every option gets a score from what the alien knows right now - how hurt it is, how
## far he is, how many of them it knows of, what he carries (habits) and how he fights (styles), its
## own kind and how hard the war has got - plus a little noise so they are never quite predictable.
## The best one that can be done is done; one that cannot (no cover there...) gives way to the next.
## Nothing here knows more than the alien itself: the target, last_seen and its threats.

const AT := preload("res://scripts/alien_tactics.gd")
const NOISE := 0.3
## How much the autotune (tools/autotune.sh) found the aliens' aim has to be scaled for each
## difficulty to hit the wanted losses (1.0 = as written). The aim's spread is multiplied by it.
const TUNE_MISS := {"easy": 1.0, "normal": 1.0, "veteran": 1.0}

static func off() -> bool:
	return AT.off() or Game.cmd_arg("ai063", "") == "1"     # (--ai063=1: as in 0.63, for A/B tests)

## Is @a p known to fight like @a tag (far, close, dug_in, loner)? (Campaign.known_styles)
static func style(_a: Node, p: Node, tag: String) -> bool:
	if off() or p == null or not is_instance_valid(p) or not "display_name" in p:
		return false
	var s: Dictionary = Net.mission_params.get("styles", {})
	return tag in s.get(String(p.display_name), [])

static func miss_tune() -> float:
	if Game.cmd_arg("aitune", "") != "":
		return float(Game.cmd_arg("aitune", "1"))
	return float(TUNE_MISS.get("veteran" if Game.veteran() else ("easy" if Game.easy() else "normal"), 1.0))

## The scores of everything it could do next: [[score, name], ...] best first.
static func scores(a: Node) -> Array:
	var out := []
	var hpf: float = a.hp / maxf(1.0, float(a.R["hp"]))
	var dist: float = a.global_position.distance_to(a.last_seen)
	var thr: int = maxi(1, AT.threats(a).size())
	var tg: Node = a.target if is_instance_valid(a.target) and a.target.has_method("is_player") and not a.target.dead else null
	var tac: String = a.tac
	# hurt: keep its head down
	out.append([(0.35 + (0.4 - hpf) * 2.5 if hpf < 0.4 else 0.05) + 0.08 * (thr - 1), "hide"])
	# far from him: closer, under cover (a sniper / a man who fights from afar: never stay at his range)
	var far_d: float = lerpf(28.0, 15.0, a._late)
	var adv := 0.0
	if tac != "psi":
		if dist > far_d:
			adv = 0.6 + minf(dist - far_d, 15.0) * 0.02
		if tg and dist > 14.0 and (a._habit(tg, "sniper") or style(a, tg, "far")):
			adv = maxf(adv, 0.9)
	out.append([adv, "advance"])
	# lost sight of him for a while: push straight in
	if tac in ["soldier", "hunter"] and a.mission.t - a._seen_t > 5.0:
		out.append([0.25 + a._press * 0.6 - 0.15 * (thr - 1), "push"])
	# a firing position (more of them about: hold one rather than walk round)
	if tac in ["soldier", "hunter", "grey"]:
		var fs: float = 0.35 + a._press * 0.5 + 0.05 * (thr - 1)
		if tg and style(a, tg, "far"):
			fs -= 0.2              # (not a shooting match at his range)
		if tg and style(a, tg, "dug_in"):
			fs -= 0.1              # (he will not come out of it: go round him instead)
		out.append([fs, "fire_spot"])
	if not a.R.has("hover"):
		out.append([0.4 if tac in ["soldier", "hunter"] else 0.3, "window"])
	# round him
	var fl := 0.4 - 0.12 * (thr - 1)
	if tg and style(a, tg, "dug_in"):
		fl += 0.2
	if tg and style(a, tg, "close"):
		fl -= 0.1
	out.append([fl, "flank"])
	if tg:
		var rear := 0.0
		if tac == "grey":
			rear = 0.75
		if tac != "brute" and (a._habit(tg, "stit") or a._habit(tg, "minigun")):
			rear = maxf(rear, 0.9)
		if style(a, tg, "dug_in"):
			rear = maxf(rear, 0.55)
		if style(a, tg, "loner"):
			rear = maxf(rear, 0.5)
		if rear > 0.0:
			out.append([rear - 0.06 * (thr - 1), "rear"])
		# up close is where he is dangerous: keep the distance
		var away := 1.2 if tac == "psi" else 0.0
		if tac != "brute" and dist < 12.0 and (style(a, tg, "close") or a._habit(tg, "shotgun") or a._habit(tg, "magnum")):
			away = maxf(away, 0.75)
		if away > 0.0:
			out.append([away, "keep_away"])
	elif tac == "psi":
		out.append([1.2, "keep_away"])
	if a._can_grab():
		out.append([0.8, "grab"])
	if tac == "levit":
		out.append([0.85, "hop"])
	for o in out:
		o[0] = float(o[0]) + a.rng.randf() * NOISE
	out.sort_custom(func(x, y): return x[0] > y[0])
	return out

## Done hiding: weigh the options and do the best one that works.
static func choose_move(a: Node) -> void:
	a.phase = "flank"
	for o in scores(a):
		if _try(a, String(o[1])):
			a._tlog("util %s %.2f" % [o[1], o[0]])
			return
	a._flank()

static func _try(a: Node, what: String) -> bool:
	match what:
		"hide":
			a.hide_t = a.rng.randf_range(2.0, 4.0)
			a._relocate(a.last_seen)
			a.phase = "move"
			return true
		"advance":
			return a._advance(a.last_seen)
		"push":
			var dir: Vector3 = a.last_seen - a.global_position
			dir.y = 0
			if dir.length() <= 5.0:
				return false
			a._go(a._snap(a.global_position + dir.normalized() * minf(dir.length() - 3.0, 14.0)))
			return true
		"fire_spot":
			var fs: Vector3 = a._fire_spot(a.last_seen)
			if fs == Vector3.INF:
				return false
			a._go(fs)
			return true
		"window":
			var w: Vector3 = a._window_spot(a.last_seen)
			if w == Vector3.INF:
				return false
			a._go(w)
			return true
		"flank":
			a._flank()
			return true
		"rear":
			a._flank_rear(a.target)
			return true
		"keep_away":
			a._keep_away(a.last_seen)
			return true
		"grab":
			a.phase = "grab"
			a._brute_repath = 0.0
			return true
		"hop":
			if a._levit_hop(a.last_seen, false):
				a.phase = "move"
				return true
	return false

# ---- the marked man ----------------------------------------------------------------------------------------
## Every 15 s: the hunter of a nemesis goes where the aliens last had him (the squads' board: seen,
## heard or told) - no more than that. Nobody has had him for two minutes: it waits for him like
## the others do. (Before 0.64 it was simply told where he was for 6 s of every 15.)
static func nemesis_hunt(a: Node) -> void:
	var p: Node = a.nemesis
	if a.state == a.S.COMBAT or a.state == a.S.DRAG:
		return
	var b: Dictionary = (a.mission.get_meta("ai_board") if a.mission.has_meta("ai_board") else {}).get("last", {})
	var k := String(p.display_name)
	if not b.has(k) or a.mission.t - float(b[k][1]) > 120.0:
		return
	a._tlog("nemesis hunt %.0f s old" % (a.mission.t - float(b[k][1])))
	a.stalk(p, b[k][0])

# ---- a terror: the people (0.64, Ari: "they try to kill the civilians in a terror - it works, but too little") ----
## Not fighting a mercenary: a civilian in sight within CIV_RANGE m gets a bolt. It stops, aims a
## moment, fires one, and looks for the next. (Before 0.64 only the beasts went for them.)
const CIV_RANGE := 32.0
static func civ_tick(a: Node, delta: float) -> bool:
	if off() or a.mission == null or a.mission.mtype() != "terror" or a.husk or a.R.has("spit"):
		return false
	a._civ_cd -= delta
	if a._civ_t > 0.0:
		var c: Node = a._civ_tgt
		if not is_instance_valid(c) or c.dead or c.saved:
			a._civ_t = 0.0
			return false
		a.velocity.x = 0
		a.velocity.z = 0
		a.lurking = false
		a._face(c.global_position, delta)
		a._civ_t -= delta
		if a._civ_t <= 0.0:
			_civ_shot(a, c)
			a._civ_cd = a.rng.randf_range(1.0, 2.0)
		return true
	if a._civ_cd > 0.0:
		return false
	a._civ_cd = 0.5
	var best: Node = null
	var bd := CIV_RANGE
	for c in a.mission.civilians():
		if c.dead or c.saved or c.infected:
			continue
		var d: float = a.global_position.distance_to(c.global_position)
		if d < bd and a._los(c.global_position + Vector3(0, 1.2, 0)):
			bd = d
			best = c
	if best == null:
		# nobody in sight: it combs the streets - towards somewhere round one of them (not to him: the
		# town is where the people are, it does not know where each one hides)
		if a.state == a.S.LURK and a._arrived() and a.rng.randf() < 0.25:
			var cs := []
			for c in a.mission.civilians():
				if not c.dead and not c.saved and not c.infected and a.global_position.distance_to(c.global_position) < 60.0:
					cs.append(c)
			if not cs.is_empty():
				var c0: Node = cs[a.rng.randi() % cs.size()]
				var jit: Vector3 = Vector3(a.rng.randf_range(-1, 1), 0, a.rng.randf_range(-1, 1)).normalized() * a.rng.randf_range(6.0, 14.0)
				a.lurking = false
				a.wait = a.rng.randf_range(4.0, 8.0)
				a._go(a._snap(c0.global_position + jit))
				a._tlog("terror comb")
		return false
	a._civ_tgt = best
	a._civ_t = a.rng.randf_range(0.45, 0.85) * (1.3 if Game.easy() else (0.8 if Game.veteran() else 1.0))
	a._tlog("civ aim %.0f m" % bd)
	return true

static func _civ_shot(a: Node, c: Node) -> void:
	var from: Vector3 = a._muzzle_pos()
	var tgt: Vector3 = c.global_position + Vector3(0, 0.6 if c.cowering else 1.2, 0)
	var d: float = from.distance_to(tgt)
	var run: bool = Vector2(c.velocity.x, c.velocity.z).length() > 2.0
	var p_hit := clampf(0.95 - d * 0.012, 0.45, 0.9) * (0.8 if run else 1.0) * (0.8 if Game.easy() else 1.0)
	var hit: bool = a.rng.randf() < p_hit
	var aim := tgt
	if not hit:
		aim += Vector3(a.rng.randf_range(-1.2, 1.2), a.rng.randf_range(-0.4, 0.6), a.rng.randf_range(-1.2, 1.2))
	a._decloak_t = 1.6
	a.shots_fired += 1
	a._plasma.rpc(from, (aim - from).normalized(), float(a._g("bolt", 1.0)), "plasma")
	if hit:
		var tt := d / 30.0
		a.get_tree().create_timer(clampf(tt, 0.05, 1.2)).timeout.connect(func():
			if is_instance_valid(c) and not c.dead and not c.saved and is_instance_valid(a.mission) and not a.mission.finished:
				c.killed_by(String(a.race)))
	a._tlog("civ shot %s %.0f m" % ["hit" if hit else "miss", d])
