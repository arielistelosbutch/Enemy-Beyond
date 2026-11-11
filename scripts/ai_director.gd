extends RefCounted
## The mission's director and the aliens' memory of how each mercenary fights (0.64, the AI plan,
## steps 5 and 6). Only the host runs it; everything is a static function, the state lives in the
## mission's meta "ai_dir". --oldai=1 turns it off (the old timer director comes back).
##
## Step 5 - the style of play, between missions: what the aliens lived through with each man -
##   from how far his hits came (far / close), how much of a fight he spent on one spot (dug_in),
##   how often he was off on his own (loner). At the end of the mission it goes to the campaign,
##   which keeps it with a slow forgetting (like the gear habits); a style seen in two missions or
##   so is "known" and the aliens answer it (alien_mind.gd). Nothing of it is ever shown to the
##   players (hardcore: they find out by playing).
## Step 6 - the director: a tension meter instead of fixed times. It rises with the damage the team
##   takes and with the aliens fighting near them, and falls by itself. build -> peak -> relax ->
##   build: the quiet beats (the knock, the lure into the barn, the power going out) and the
##   hunting of a lone man only come in a quiet build-up, never in the middle of a fight or right
##   after one. It never touches numbers (no secret easing, no secret help for the aliens) and the
##   hunters it sends only know what the aliens have seen or heard.

const SAMPLE := 2.0          # s between two samples of what each man is doing
const FAR := 24.0            # m: an average hit from further than this = he fights from afar
const CLOSE := 9.0           # m: and nearer than this = up close
const MIN_DMG := 60.0        # damage he must have done for the range to count
const MIN_SAMPLES := 15      # samples in a fight (30 s) for dug_in / loner to count
const STILL := 1.5           # m: moved less than this between two samples = on the same spot
const ALONE := 18.0          # m: the nearest mate further than this = on his own
const STYLE_TAGS := ["far", "close", "dug_in", "loner"]
# tension
const T_DECAY := 0.022       # per s
const T_PEAK := 0.55
const T_CALM := 0.25
const T_QUIET := 0.15

static func off() -> bool:
	return Game.cmd_arg("oldai", "") == "1" or Game.cmd_arg("ai063", "") == "1"

static func st(m: Node) -> Dictionary:
	if not m.has_meta("ai_dir"):
		m.set_meta("ai_dir", {"t": 0.0, "men": {}, "hp": -1.0, "T": 0.0, "phase": "build",
			"relax_until": 0.0, "quiet_from": 0.0, "beat_t": 0.0, "hunt_t": 0.0, "log_t": 0.0})
	return m.get_meta("ai_dir")

static func _man(s: Dictionary, p: Node) -> Dictionary:
	var k := String(p.display_name) if "display_name" in p and String(p.display_name) != "" else String(p.name)
	if not s["men"].has(k):
		s["men"][k] = {"dmg": 0.0, "dd": 0.0, "n": 0, "still": 0, "alone": 0, "at": p.global_position}
	return s["men"][k]

# ---- step 5: what the aliens learn about each man --------------------------------------------------
## An alien was hit by @a by from @a dist m.
static func style_hit(m: Node, by: Node, dist: float, dmg: float) -> void:
	if off() or m == null or by == null or not by.has_method("is_player"):
		return
	var mm := _man(st(m), by)
	mm["dmg"] = float(mm["dmg"]) + dmg
	mm["dd"] = float(mm["dd"]) + dmg * dist

static func _sample(m: Node, s: Dictionary, ps: Array) -> void:
	var fight: bool = m.t - float(m.combat_t) < 20.0
	if not fight:
		for a in m.aliens():
			if not a.dead and a.state == a.S.COMBAT:
				fight = true
				break
	for p in ps:
		var mm := _man(s, p)
		var moved: float = (p.global_position - mm["at"]).length()
		mm["at"] = p.global_position
		if not fight or p.downed:
			continue
		mm["n"] = int(mm["n"]) + 1
		if moved < STILL:
			mm["still"] = int(mm["still"]) + 1
		if ps.size() > 1:
			var dmin := 1e9
			for o in ps:
				if o != p and not o.dead:
					dmin = minf(dmin, o.global_position.distance_to(p.global_position))
			if dmin > ALONE:
				mm["alone"] = int(mm["alone"]) + 1

## The end of the mission: {man: [tags]} of what stood out this time.
static func style_out(m: Node) -> Dictionary:
	var out := {}
	if off() or not m.has_meta("ai_dir"):
		return out
	for k in st(m)["men"]:
		var mm: Dictionary = st(m)["men"][k]
		var tags := []
		if float(mm["dmg"]) >= MIN_DMG:
			var avg := float(mm["dd"]) / float(mm["dmg"])
			if avg > FAR:
				tags.append("far")
			elif avg < CLOSE:
				tags.append("close")
		var n := int(mm["n"])
		if n >= MIN_SAMPLES:
			if float(mm["still"]) / n > 0.6:
				tags.append("dug_in")
			if float(mm["alone"]) / n > 0.5:
				tags.append("loner")
		if not tags.is_empty():
			out[k] = tags
	return out

# ---- step 6: the director ------------------------------------------------------------------------------
static func tension(m: Node) -> float:
	return float(st(m)["T"]) if m.has_meta("ai_dir") else 0.0

static func phase(m: Node) -> String:
	return String(st(m)["phase"]) if m.has_meta("ai_dir") else "build"

## How long it has been quiet (seconds), 0 in a fight.
static func quiet(m: Node) -> float:
	var s := st(m)
	return m.t - float(s["quiet_from"]) if s["phase"] == "build" and float(s["T"]) < T_QUIET else 0.0

static func tick(m: Node, delta: float, ps: Array) -> void:
	var s := st(m)
	# what each man does (step 5), every 2 s
	if m.t - float(s["t"]) >= SAMPLE:
		s["t"] = m.t
		_sample(m, s, ps)
	# the damage the team took since the last frame
	var hp := 0.0
	var mx := 0.0
	for p in ps:
		hp += maxf(0.0, float(p.hp)) if not p.downed else 0.0
		mx += float(p.max_hp)
	var T := float(s["T"])
	if float(s["hp"]) >= 0.0 and hp < float(s["hp"]):
		T += (float(s["hp"]) - hp) / maxf(10.0, mx * 0.5)
	s["hp"] = hp
	# aliens fighting near them
	var near := 0
	for a in m.aliens():
		if a.dead or a.state != a.S.COMBAT:
			continue
		for p in ps:
			if a.global_position.distance_to(p.global_position) < 35.0:
				near += 1
				break
	T += minf(near, 4) * 0.012 * delta
	if m.t - float(m.combat_t) < 1.0:
		T += 0.02 * delta
	T = clampf(T - T_DECAY * delta, 0.0, 1.0)
	s["T"] = T
	var ph := String(s["phase"])
	match ph:
		"build":
			if T >= T_PEAK:
				ph = "peak"
		"peak":
			if T < T_CALM:
				ph = "relax"
				s["relax_until"] = m.t + randf_range(20.0, 35.0)
		"relax":
			if T >= T_PEAK:
				ph = "peak"
			elif m.t > float(s["relax_until"]) and T < T_CALM:
				ph = "build"
	if ph != String(s["phase"]):
		s["phase"] = ph
		if Game.autotest() != "":
			print("[DIR] %.0f s %s T %.2f" % [m.t, ph, T])
	if ph != "build" or T >= T_QUIET:
		s["quiet_from"] = m.t

## A quiet beat may come now (once the last one is @a gap s old and it has been quiet @a need s).
static func beat_ok(m: Node, need: float, gap := 40.0) -> bool:
	if off():
		return true
	var s := st(m)
	if quiet(m) < need or m.t - float(s["beat_t"]) < gap:
		return false
	s["beat_t"] = m.t
	return true

## Whom the aliens know to be off on his own, and where they last had him: [man, place] or [].
## (Only what the aliens saw or heard: the squads' board, alien_squad.gd.)
static func lone_known(m: Node, ps: Array) -> Array:
	var b: Dictionary = (m.get_meta("ai_board") if m.has_meta("ai_board") else {}).get("last", {})
	var known := {}
	for p in ps:
		var k := String(p.display_name)
		if not p.downed and b.has(k) and m.t - float(b[k][1]) <= 90.0:
			known[p] = b[k][0]
	var best: Array = []
	var bs := -1.0
	for p in known:
		# (how far from the others - as far as the aliens know where the others are)
		var dmin := 60.0
		for o in known:
			if o != p:
				dmin = minf(dmin, (known[o] as Vector3).distance_to(known[p]))
		if dmin > bs:
			bs = dmin
			best = [p, known[p]]
	return best
