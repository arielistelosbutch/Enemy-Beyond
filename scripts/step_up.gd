extends RefCounted
## 0.62 (Ari: „vetřelci občas propadnou do země, když je chodník vyšší“): krok nahoru.
## CharacterBody3D sám na schod nevyleze - kapsle se o hranu obrubníku zarazí, nebo se po ní
## kousek vyšplhá a sklouzne zpátky. Když je tělo na zemi a v cestě mu je nízká překážka
## (obrubník, práh, podlaha obchodu), zkusí se: nahoru o výšku kroku, kousek dopředu, dolů na
## novou podlahu. Když je nahoře zase zeď nebo za hranou díra, nic se neděje (rozhoduje dál
## move_and_slide). Volá se těsně před move_and_slide (vetřelci, vojáci, civilisté).

const ALIEN := 0.42     # m: vetřelci (cesty pro ně se pečou s agent_max_climb 0,4)
const MAN := 0.35       # m: voják a civilista (výš se leze skokem / přitažením)

static func climb(b: CharacterBody3D, delta: float, step: float) -> float:
	if b.velocity.y > 0.5:
		return 0.0                   # a jump
	var hv := Vector3(b.velocity.x, 0.0, b.velocity.z)
	if hv.length() < 0.05:
		return 0.0
	# (2026-11-27, trhání v co-opu) a body pushing against a wall, a crate or a crowd tried the whole
	# step (5 test_moves) every physics tick - with a dozen aliens 6-8 ms a tick. After a try that
	# found no step the next one waits a moment.
	var now := Time.get_ticks_msec()
	if now < int(b.get_meta(&"su_wait", 0)):
		return 0.0
	var xf := b.global_transform
	# on the ground - or half up the kerb's edge already (the round bottom of the body rides up
	# it and then "is not on the floor")
	if not b.is_on_floor() and not b.test_move(xf, Vector3(0, -0.12, 0)):
		return 0.0
	# look a bit further than one frame, so a slow walker finds the kerb too
	var probe := hv.normalized() * maxf(hv.length() * delta, 0.06)
	var hit := KinematicCollision3D.new()
	if not b.test_move(xf, probe, hit):
		return 0.0                   # nothing in the way
	var who := hit.get_collider()
	if who is CharacterBody3D or who is RigidBody3D:
		b.set_meta(&"su_wait", now + WAIT_MS)
		return 0.0                   # another body (an alien, a soldier, a barrel), not a kerb
	b.set_meta(&"su_wait", now + WAIT_MS)    # (cleared again below when it does step up)
	# (2026-11-22, Ari: „na obrubník je potřeba vyskočit“) the step is tried straight INTO the edge,
	# not along the walking direction: walking at an angle the old probe got only a couple of cm
	# over the edge, the round bottom of the capsule then "landed" on the corner a few mm higher and
	# that counted as a slope - the body slid along the kerb and only a jump got it up.
	var into := -Vector3(hit.get_normal().x, 0.0, hit.get_normal().z)
	if into.length() < 0.3:
		return 0.0                   # the floor itself (a slope under the feet), not an edge
	into = into.normalized()
	if into.dot(hv.normalized()) < 0.15:
		return 0.0                   # walking along the kerb, not onto it
	var over := into * REACH
	var rise := step
	var col := KinematicCollision3D.new()
	if b.test_move(xf, Vector3(0, step, 0), col):
		rise = col.get_travel().length() - 0.02     # a ceiling, a beam: only as far as there is room
		if rise < 0.12:
			return 0.0
	var up := xf.translated(Vector3(0, rise, 0))
	if b.test_move(up, over):
		return 0.0                   # a wall, not a step
	var down := KinematicCollision3D.new()
	if not b.test_move(up.translated(over), Vector3(0, -rise - 0.05, 0), down):
		return 0.0                   # no floor behind the edge (a hole, a drop)
	if down.get_normal().angle_to(Vector3.UP) > b.floor_max_angle + 0.01:
		return 0.0                   # a steep slope, not a tread
	var h := rise - down.get_travel().length()
	if h < 0.03:
		return 0.0                   # just a slope - move_and_slide manages that itself
	b.global_position.y += h + 0.005
	b.velocity.y = 0.0
	b.set_meta(&"su_wait", 0)
	return h + 0.005

## how far over the edge the new floor is looked for (about the body's radius: the capsule must
## stand on the tread with its middle, not balance on the corner)
const REACH := 0.22
## ms until the next try after one that found no step (a wall, a crowd, a slope)
const WAIT_MS := 120
