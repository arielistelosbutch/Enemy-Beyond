extends RefCounted
## The aliens as a team (0.63, the AI plan, steps 3-4): one shared board for the whole mission (host).
## - squads: the alert aliens near each other form a squad every second; an officer (*_velitel)
##   leads it if there is one (it reaches further and plans faster), else the strongest one.
##   Killing the leader leaves them without a plan for a while.
## - what one of them saw, the squad knows: the last place of every mercenary goes round the squad
##   (cover against all of them, where to look). Shooting still needs its own eyes.
## - roles and a common attack: against the mercenary the squad knows best, the leader leaves some
##   to hold him down (fix: firing spots, no wandering off) and sends one or two round to the sides
##   (flank). When they are in place - or it takes too long - all of them open up at once.
## - melee packs (Líhavec, Ohař): two or more after the same prey spread round it (from behind
##   first) and spring together; a lone Líhavec comes round to his back.
## - the heat map: where the aliens have seen or heard the mercenaries in this mission. The lost
##   are looked for there first, the Líhavec waits in the dark near it.
## Honest: everything comes from what some alien saw or heard (AT.saw, AT.heard_shot).
## Every player counts the same: 1-4 mercenaries, nothing is tied to "the" player.
## --oldai=1 turns it off together with alien_tactics.gd.

const AT := preload("res://scripts/alien_tactics.gd")
const AM := preload("res://scripts/alien_mind.gd")
const LINK := 25.0              # m: squad mates within this of each other (an officer: OFFICER_LINK)
const OFFICER_LINK := 40.0
const CELL := 4.0               # m: heat map cell
const PLAN_CD := 10.0           # s: between two common attacks (officer: 0.6 of it)
const PLAN_MAX := 15.0          # s: the flankers have this long to get round before the attack goes
const HUNTERS := ["soldier", "hunter", "grey", "levit", "psi"]
const PACK := ["lihnoun", "ohar"]

static func off() -> bool:
	return AT.off()

static func board(m: Node) -> Dictionary:
	if not m.has_meta("ai_board"):
		m.set_meta("ai_board", {"t": -99.0, "heat": {}, "heat_t": {}, "plans": {}, "packs": {}, "lost_lead": -99.0, "last": {}})
	return m.get_meta("ai_board")

static func is_officer(a: Node) -> bool:
	return String(a.race).ends_with("_velitel")

# ---- heat map ---------------------------------------------------------------------------------
## A mercenary seen or heard at @a pos (once a second for each of them is enough).
static func heat_note(a: Node, p: Node, pos: Vector3) -> void:
	if off() or a.mission == null:
		return
	var b := board(a.mission)
	var k := String(p.name) if p else "?"
	if p and "display_name" in p:
		b["last"][String(p.display_name)] = [pos, a.mission.t]     # (the director's and the nemesis hunt's "where was he")
	if a.mission.t - float(b["heat_t"].get(k, -99.0)) < 1.0:
		return
	b["heat_t"][k] = a.mission.t
	var c := Vector2i(floori(pos.x / CELL), floori(pos.z / CELL))
	b["heat"][c] = float(b["heat"].get(c, 0.0)) + 1.0

## How much the mercenaries have been round @a pos (cells within @a r m).
static func heat_at(m: Node, pos: Vector3, r := 8.0) -> float:
	if off():
		return 0.0
	var h: Dictionary = board(m)["heat"]
	if h.is_empty():
		return 0.0
	var n := int(ceil(r / CELL))
	var c0 := Vector2i(floori(pos.x / CELL), floori(pos.z / CELL))
	var s := 0.0
	for dx in range(-n, n + 1):
		for dz in range(-n, n + 1):
			var c := c0 + Vector2i(dx, dz)
			if h.has(c):
				var cc := Vector3((c.x + 0.5) * CELL, pos.y, (c.y + 0.5) * CELL)
				var d := Vector2(cc.x - pos.x, cc.z - pos.z).length()
				if d <= r:
					s += float(h[c]) * (1.0 - d / (r + CELL))
	return s

## The heat of the hottest place on the map (to scale a search by).
static func heat_max(m: Node) -> float:
	var mx := 0.0
	for v in board(m)["heat"].values():
		mx = maxf(mx, float(v))
	return mx

# ---- the board, once in a while ---------------------------------------------------------------
## Every alien's think calls this; the board itself is worked out once per 0.5 s.
static func tick(a: Node, _delta: float) -> void:
	if off() or a.mission == null:
		return
	var m: Node = a.mission
	var b := board(m)
	if m.t - float(b["t"]) >= 0.5:
		b["t"] = m.t
		_update(m, b)
	_member_tick(a, b)

static func _alert(a: Node) -> bool:
	return not a.dead and not a.husk and not a.R.get("dumb", false) and a.alert \
		and a.state in [a.S.COMBAT, a.S.STALK, a.S.SEARCH, a.S.INVESTIGATE]

static func _update(m: Node, b: Dictionary) -> void:
	var ranged := []
	var melee := []
	for a in m.aliens():
		if a.R.has("melee") and a.race in PACK and not a.dead and a.state == a.S.COMBAT:
			melee.append(a)          # (a pack of hounds hunts together, dull as they are)
			continue
		if not _alert(a):
			a._squad = ""
			a._slot = Vector3.INF
			continue
		if a.R.has("melee"):
			if a.race in PACK and a.state == a.S.COMBAT:
				melee.append(a)
			else:
				a._slot = Vector3.INF
		elif not a.R.has("drone"):
			ranged.append(a)
	_squads(m, b, ranged)
	_packs(m, b, melee)

# ---- ranged squads ------------------------------------------------------------------------------
static func _squads(m: Node, b: Dictionary, al: Array) -> void:
	# clusters: anyone within LINK of a member (an officer's voice carries further)
	var left := al.duplicate()
	var groups := []
	while not left.is_empty():
		var g := [left.pop_back()]
		var i := 0
		while i < g.size():
			var x: Node = g[i]
			for j in range(left.size() - 1, -1, -1):
				var y: Node = left[j]
				var reach := OFFICER_LINK if is_officer(x) or is_officer(y) else LINK
				if x.global_position.distance_to(y.global_position) < reach:
					g.append(y)
					left.remove_at(j)
			i += 1
		groups.append(g)
	var live_plans := {}
	for g in groups:
		var lead: Node = null
		for x in g:
			if lead == null or (is_officer(x) and not is_officer(lead)) or (is_officer(x) == is_officer(lead) and float(x.R["hp"]) > float(lead.R["hp"])):
				lead = x
		var key := String(lead.name)
		for x in g:
			x._squad = key
		_share(m, g)
		if g.size() >= 2:
			live_plans[key] = true
			_plan(m, b, key, lead, g)
	for k in b["plans"].keys():
		if not live_plans.has(k):
			_drop_plan(m, b, k)

## What one saw, all know: the freshest place of every mercenary goes round the squad.
static func _share(m: Node, g: Array) -> void:
	var best := {}
	for x in g:
		for k in x._seen_pos:
			var e: Array = x._seen_pos[k]
			if not best.has(k) or float(e[1]) > float(best[k][1]):
				best[k] = e
	for x in g:
		for k in best:
			if not x._seen_pos.has(k) or float(x._seen_pos[k][1]) < float(best[k][1]):
				x._seen_pos[k] = best[k]
				x._thr_t = -1.0
		# lost sight of its man: where a mate saw him last
		if x.state == x.S.COMBAT and is_instance_valid(x.target) and m.t - float(x._seen_t) > 1.5:
			var tk := String(x.target.name)
			if best.has(tk) and float(best[tk][1]) > float(x._seen_t):
				x.last_seen = best[tk][0]

static func _plan(m: Node, b: Dictionary, key: String, lead: Node, g: Array) -> void:
	var pl: Dictionary = b["plans"].get(key, {})
	if pl.is_empty():
		pl = {"cd": m.t + 2.0, "roles": {}, "spots": {}, "ready": {}, "t0": 0.0, "target": null, "go": -1.0}
		b["plans"][key] = pl
	if m.t - float(b["lost_lead"]) < 6.0 and g.size() > 0 and not is_officer(lead):
		return            # (the officer has just fallen: nobody gives orders for a moment)
	var fighters := []
	for x in g:
		if x.state == x.S.COMBAT and x.tac in HUNTERS and not x.flying and not x.airborne:
			fighters.append(x)
	var tgt: Node = pl["target"]
	if pl["roles"].is_empty():
		if m.t < float(pl["cd"]) or fighters.size() < 2:
			return
		tgt = _focus(m, g)
		if tgt == null:
			return
		_assign(m, pl, lead, fighters, tgt)
		return
	# a plan is running
	if tgt == null or not is_instance_valid(tgt) or tgt.dead or tgt.downed:
		_reset(m, pl, lead)
		return
	var ready := true
	var any_flank := false
	for n in pl["roles"]:
		if pl["roles"][n] != "flank":
			continue
		var x: Node = _by_name(g, n)
		if x == null or x.dead:
			continue
		any_flank = true
		if not pl["ready"].has(n):
			ready = false
	var wait_max := PLAN_MAX * (0.8 if Game.veteran() else (1.25 if Game.easy() else 1.0))
	if float(pl["go"]) < 0 and (not any_flank or ready or m.t - float(pl["t0"]) > wait_max):
		pl["go"] = m.t + 0.4
		lead._tlog("squad go (%d, ready %s)" % [pl["roles"].size(), ready])
		lead._alert_voice.rpc()          # (the order is heard: a moment's warning for the mercenaries)
	elif float(pl["go"]) > 0 and m.t > float(pl["go"]) + 2.5:
		_reset(m, pl, lead)

static func _by_name(g: Array, n: String) -> Node:
	for x in g:
		if String(x.name) == n:
			return x
	return null

## The mercenary the squad knows best right now: seen most recently by the most of them.
static func _focus(m: Node, g: Array) -> Node:
	var best: Node = null
	var bs := -1e9
	for p in m.players():
		if p.dead or p.downed or p.has_meta("ghost"):
			continue
		var k := String(p.name)
		var sc := 0.0
		for x in g:
			if x._seen_pos.has(k):
				var age: float = m.t - float(x._seen_pos[k][1])
				if age < 12.0:
					sc += 1.0 - age / 12.0
				if x.target == p:
					sc += 0.5
		if sc > bs and sc > 0.3:
			bs = sc
			best = p
	return best

static func _assign(m: Node, pl: Dictionary, lead: Node, fighters: Array, tgt: Node) -> void:
	var tp: Vector3 = tgt.global_position
	var k := String(tgt.name)
	if lead._seen_pos.has(k):
		tp = lead._seen_pos[k][0]       # (where they believe he is)
	# the fixers' side of him: the nearest ones (and the leader) stay there
	fighters.sort_custom(func(x, y): return x.global_position.distance_to(tp) < y.global_position.distance_to(tp))
	var n := fighters.size()
	var n_flank := clampi(n / 2 + (1 if AM.style(lead, tgt, "dug_in") else 0), 1, clampi(n - 1, 1, 3))    # (0.64: a man who digs in is gone round from more sides)
	var fix_dir := Vector3.ZERO
	for i in n - n_flank:
		var v: Vector3 = fighters[i].global_position - tp
		v.y = 0
		fix_dir += v.normalized() if v.length() > 0.1 else Vector3.ZERO
	if fix_dir.length() < 0.1:
		var v0: Vector3 = fighters[0].global_position - tp
		v0.y = 0
		fix_dir = v0 if v0.length() > 0.1 else Vector3.FORWARD
	fix_dir = fix_dir.normalized()
	# flankers: of the rest (never the leader), the ones already most to the side
	var cand := []
	for x in fighters:
		if x == lead and n > 2:
			continue
		if x.run_spd < 3.5:
			continue          # (the slow heavy ones hold him down; going round would take them all day)
		var v: Vector3 = x.global_position - tp
		v.y = 0
		var side: float = absf(fix_dir.cross(v.normalized()).y) if v.length() > 0.1 else 0.0
		var sgn: float = signf(fix_dir.cross(v).y) if v.length() > 0.1 else 1.0
		cand.append([side + (0.3 if x.tac == "grey" else 0.0), x, sgn])
	cand.sort_custom(func(p, q): return p[0] > q[0])
	pl["roles"] = {}
	pl["spots"] = {}
	pl["ready"] = {}
	for x in fighters:
		pl["roles"][String(x.name)] = "fix"
		x._role = "fix"
	var used_sides := []
	for i in mini(n_flank, cand.size()):
		var x: Node = cand[i][1]
		var sgn: float = cand[i][2]
		if used_sides.has(sgn):
			sgn = -sgn                       # (two flankers: one from each side)
		used_sides.append(sgn)
		var spot := _flank_spot(x, tgt, tp, fix_dir, sgn)
		pl["roles"][String(x.name)] = "flank"
		pl["spots"][String(x.name)] = spot
		x._role = "flank"
		x.target = tgt
		x.last_seen = tp
		if x.phase != "shoot":
			x._go(spot)
			x.phase = "flank"         # (one firing now goes after its burst: after_burst)
		x._tlog("role flank %.0f m" % x.global_position.distance_to(spot))
	pl["target"] = tgt
	pl["t0"] = m.t
	pl["go"] = -1.0
	lead._tlog("squad plan %d fighters, %d flank, on %s" % [n, n_flank, tgt.name])

## A cover point out to one side of him (75-115° from where the fixers are), that sees him.
static func _flank_spot(x: Node, tgt: Node, tp: Vector3, fix_dir: Vector3, sgn: float) -> Vector3:
	var ss: PhysicsDirectSpaceState3D = x.get_world_3d().direct_space_state
	var ang: float = sgn * x.rng.randf_range(deg_to_rad(75.0), deg_to_rad(115.0))
	var ideal: Vector3 = tp + fix_dir.rotated(Vector3.UP, ang) * x.rng.randf_range(9.0, 14.0)
	var face: Vector3 = -tgt.global_transform.basis.z
	face.y = 0
	var best := Vector3.INF
	var bs := 1e9
	for c in x.mission.map["cover"]:
		var cp: Vector3 = c
		var di := Vector2(cp.x - ideal.x, cp.z - ideal.z).length()
		if di > 7.0 or cp.distance_to(tp) < 5.0:
			continue
		var q := PhysicsRayQueryParameters3D.create(cp + Vector3(0, 1.4, 0), tp + Vector3(0, 1.1, 0), Game.WORLD)
		if not ss.intersect_ray(q).is_empty():
			continue
		var sc: float = di + AT.exposure_extra(x, cp, tp + Vector3(0, 1.3, 0), 1.0) * 10.0 + x.rng.randf() * 2.0
		var to_c: Vector3 = cp - tp
		to_c.y = 0
		if face.length() > 0.1 and to_c.length() > 0.1 and face.normalized().dot(to_c.normalized()) > 0.6:
			sc += 6.0                     # (right where he looks: not there)
		if sc < bs:
			bs = sc
			best = cp
	if best == Vector3.INF:
		best = x._snap(ideal)
	return best

static func _reset(m: Node, pl: Dictionary, lead: Node) -> void:
	for n in pl["roles"]:
		var x: Node = _find(m, n)
		if x:
			x._role = ""
	pl["roles"] = {}
	pl["spots"] = {}
	pl["ready"] = {}
	pl["target"] = null
	pl["go"] = -1.0
	pl["cd"] = m.t + PLAN_CD * (0.6 if is_officer(lead) else 1.0) * (0.8 if Game.veteran() else (1.4 if Game.easy() else 1.0))

static func _drop_plan(m: Node, b: Dictionary, k: String) -> void:
	var pl: Dictionary = b["plans"][k]
	for n in pl["roles"]:
		var x: Node = _find(m, n)
		if x:
			x._role = ""
	b["plans"].erase(k)

static func _find(m: Node, n: String) -> Node:
	for x in m.aliens():
		if String(x.name) == n:
			return x
	return null

## The squad member's side of the plan, every think.
static func _member_tick(a: Node, b: Dictionary) -> void:
	if a._role == "" or a._squad == "" or a.state != a.S.COMBAT:
		return
	var pl: Dictionary = b["plans"].get(a._squad, {})
	if pl.is_empty() or pl["roles"].is_empty():
		a._role = ""
		return
	var go: float = pl["go"]
	if go > 0 and a.mission.t >= go and a._go_done != go:
		a._go_done = go
		_open_fire(a, pl["target"])

## The attack goes: up and firing (or, not seeing him from here, on to a place that does).
static func _open_fire(a: Node, tgt: Node) -> void:
	if tgt == null or not is_instance_valid(tgt) or tgt.dead:
		return
	if a.phase == "shoot" and a.react < 0.0:
		a.shots_left = maxi(a.shots_left, a._shots() + 1)
		return
	a.target = tgt
	var chest: Vector3 = tgt.global_position + Vector3(0, 0.9 if tgt.crouching else 1.3, 0)
	if a.visible_to(tgt) or a._los(chest):
		a.phase = "shoot"
		a.shots_left = a._shots() + 1
		a.react = a.rng.randf_range(0.05, 0.3) * a._react_k
		a._know(tgt, 3.0)
		a._tlog("go: fire")
	else:
		var fs: Vector3 = a._fire_spot(a.last_seen)
		if fs != Vector3.INF:
			a._go(fs)
			a.phase = "move"
			a._tlog("go: to a firing spot")

## _next_move with a role: a fixer keeps to firing spots, a flanker on its way goes on.
## True = handled.
static func next_move(a: Node) -> bool:
	if off() or a._role == "":
		return false
	var b := board(a.mission)
	var pl: Dictionary = b["plans"].get(a._squad, {})
	if pl.is_empty() or pl["roles"].is_empty():
		return false
	var me := String(a.name)
	if a._role == "flank":
		if pl["ready"].has(me):
			a.phase = "hide"
			a.hide_t = 1.5           # (in place: waiting for the word)
			return true
		a._go(pl["spots"][me])
		a.phase = "flank"
		return true
	# fix: keep him busy - often from a firing spot near by, else its own way (but not far round him)
	if a.rng.randf() < 0.6:
		var fs: Vector3 = a._fire_spot(a.last_seen)
		if fs != Vector3.INF:
			a._go(fs)
			a.phase = "move"
			return true
	return false

## After a burst: a flanker still on its way goes on round (instead of ducking where it is).
static func after_burst(a: Node) -> bool:
	if off() or a._role != "flank":
		return false
	var pl: Dictionary = board(a.mission)["plans"].get(a._squad, {})
	if pl.is_empty() or not pl["spots"].has(String(a.name)) or pl["ready"].has(String(a.name)) or float(pl["go"]) > 0:
		return false
	a._go(pl["spots"][String(a.name)])
	a.phase = "flank"
	return true

## Arrived on the flank: wait there (hidden) for the word, a while at most.
static func flank_wait(a: Node) -> bool:
	if off() or a._role != "flank":
		return false
	var pl: Dictionary = board(a.mission)["plans"].get(a._squad, {})
	if pl.is_empty() or float(pl["go"]) > 0:
		return false
	var spot: Vector3 = pl["spots"].get(String(a.name), a.global_position)
	if not pl["ready"].has(String(a.name)) and a.global_position.distance_to(spot) > 3.0 and a.mission.t - float(pl["t0"]) < 3.0:
		return true               # (the path is not worked out yet: still on the way)
	if not pl["ready"].has(String(a.name)):
		pl["ready"][String(a.name)] = true
		a._tlog("flank ready")
	a.phase = "hide"
	a.hide_t = PLAN_MAX
	return true

## An officer has fallen: no plans for a moment.
static func leader_down(dead: Node) -> void:
	if off() or dead.mission == null or not is_officer(dead):
		return
	var b := board(dead.mission)
	b["lost_lead"] = dead.mission.t
	if b["plans"].has(String(dead.name)):
		_drop_plan(dead.mission, b, String(dead.name))

# ---- melee packs ----------------------------------------------------------------------------------
static func _packs(m: Node, b: Dictionary, al: Array) -> void:
	var by_prey := {}
	for a in al:
		if not is_instance_valid(a.prey) or not a.prey.has_method("is_player"):
			a._slot = Vector3.INF
			continue
		var k := String(a.prey.name)
		if not by_prey.has(k):
			by_prey[k] = []
		by_prey[k].append(a)
	var live := {}
	for k in by_prey:
		var g: Array = by_prey[k]
		var prey: Node = g[0].prey
		var near := []
		for a in g:
			if a.global_position.distance_to(prey.global_position) < 30.0:
				near.append(a)
			else:
				a._slot = Vector3.INF
		if near.is_empty():
			continue
		var pk: Dictionary = b["packs"].get(k, {})
		if pk.is_empty() or pk["n"] != near.size():
			pk = {"t0": m.t, "go": -1.0, "n": near.size(), "cd": float(pk.get("cd", -99.0))}
			b["packs"][k] = pk
		live[k] = true
		if float(pk["go"]) > 0 or m.t < float(pk["cd"]) or (near.size() == 1 and near[0].race != "lihnoun"):
			for a in near:
				a._slot = Vector3.INF
			if float(pk["go"]) > 0 and m.t > float(pk["go"]) + 4.0:
				pk["go"] = -1.0
				pk["t0"] = m.t
				pk["cd"] = m.t + 5.0
			continue
		_slots(m, pk, prey, near)
	for k in b["packs"].keys():
		if not live.has(k):
			b["packs"].erase(k)

## Round the prey: the first place right behind him, the others spread to the sides.
static func _slots(m: Node, pk: Dictionary, prey: Node, g: Array) -> void:
	var pp: Vector3 = prey.global_position
	var back: Vector3 = prey.global_transform.basis.z
	back.y = 0
	back = back.normalized() if back.length() > 0.1 else Vector3.BACK
	var n := g.size()
	var angs: Array = [0.0] if n == 1 else ([-0.9, 0.9] if n == 2 else ([0.0, -1.9, 1.9] if n == 3 else [-0.75, 0.75, -2.3, 2.3]))
	var free := []
	for i in mini(n, angs.size()):
		free.append(back.rotated(Vector3.UP, angs[i]))
	var all_in := true
	for a in g:
		var pc: Array = a.R.get("pounce", [6.0, 1.0])
		var stand: float = float(pc[0]) + 1.5
		var v: Vector3 = a.global_position - pp
		v.y = 0
		var bi := 0
		var bd := 1e9
		for i in free.size():
			var d: float = (pp + free[i] * stand).distance_to(a.global_position)
			if d < bd:
				bd = d
				bi = i
		if free.is_empty():
			a._slot = Vector3.INF
			continue
		a._slot = pp + free[bi] * stand
		free.remove_at(bi)
		if Vector2(a.global_position.x - a._slot.x, a.global_position.z - a._slot.z).length() > 2.5:
			all_in = false
	var wait_max := 6.0 if n > 1 else 7.0
	if all_in or m.t - float(pk["t0"]) > wait_max:
		pk["go"] = m.t
		for a in g:
			a._slot = Vector3.INF
		g[0]._tlog("pack go %d (in place %s)" % [n, all_in])

## Where a pack member goes for its prey now: its place round him, or him.
static func melee_goal(a: Node, pp: Vector3) -> Vector3:
	if off() or a._slot == Vector3.INF or a._charging:
		return pp
	# round him along the ring, not across in front of him
	var v: Vector3 = a.global_position - pp
	v.y = 0
	var w: Vector3 = a._slot - pp
	w.y = 0
	if v.length() < 0.5 or w.length() < 0.5:
		return a._slot
	var da: float = wrapf(atan2(w.x, w.z) - atan2(v.x, v.z), -PI, PI)
	if absf(da) < 0.9:
		return a._slot
	return pp + v.normalized().rotated(Vector3.UP, signf(da) * 0.8) * w.length()

## Still waiting for the others (do not start the dash yet)?
static func melee_hold(a: Node) -> bool:
	return not off() and a._slot != Vector3.INF and not a._charging

## Líhavec: a dark hiding place near where the mercenaries have been (none known: INF).
static func ambush_spot(a: Node) -> Vector3:
	if off():
		return Vector3.INF
	var m: Node = a.mission
	if heat_max(m) < 2.0:
		return Vector3.INF
	var thr: Array = AT.threats(a)
	var best := Vector3.INF
	var bs := 1e9
	for c in m.map["cover"]:
		var cp: Vector3 = c
		var d: float = a.global_position.distance_to(cp)
		if d < 4.0 or d > 40.0:
			continue
		var h := heat_at(m, cp, 10.0)
		if h < 1.0:
			continue
		var sc: float = -minf(h, 20.0) + a.rng.randf_range(0.0, 6.0) + d * 0.05
		for l in m.map.get("lights", []):
			if is_instance_valid(l) and l.global_position.distance_to(cp) < 7.0:
				sc += 12.0
		for t in thr:
			if (t as Vector3).distance_to(cp) < 12.0:
				sc += 25.0
		if sc < bs:
			bs = sc
			best = cp
	return best
