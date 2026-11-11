extends RefCounted
## 0.62 (Ari: „vetřelci občas propadnou do země, když je chodník vyšší“): krok nahoru.
## CharacterBody3D sám na schod nevyleze - kapsle se o hranu obrubníku zarazí, nebo se po ní
## kousek vyšplhá a sklouzne zpátky. Když je tělo na zemi a v cestě mu je nízká překážka
## (obrubník, práh, podlaha obchodu), zkusí se: nahoru o výšku kroku, kousek dopředu, dolů na
## novou podlahu. Když je nahoře zase zeď nebo za hranou díra, nic se neděje (rozhoduje dál
## move_and_slide). Volá se těsně před move_and_slide (vetřelci, vojáci, civilisté).

const ALIEN := 0.42     # m: vetřelci (cesty pro ně se pečou s agent_max_climb 0,4)
const MAN := 0.35       # m: voják a civilista (výš se leze skokem / přitažením)

static func climb(b: CharacterBody3D, delta: float, step: float) -> void:
	if b.velocity.y > 0.5:
		return                       # a jump
	var hv := Vector3(b.velocity.x, 0.0, b.velocity.z)
	if hv.length() < 0.05:
		return
	var xf := b.global_transform
	# on the ground - or half up the kerb's edge already (the round bottom of the body rides up
	# it and then "is not on the floor")
	if not b.is_on_floor() and not b.test_move(xf, Vector3(0, -0.12, 0)):
		return
	# look a bit further than one frame, so a slow walker finds the kerb too
	var probe := hv.normalized() * maxf(hv.length() * delta, 0.06)
	if not b.test_move(xf, probe):
		return                       # nothing in the way
	var rise := step
	var col := KinematicCollision3D.new()
	if b.test_move(xf, Vector3(0, step, 0), col):
		rise = col.get_travel().length() - 0.02     # a ceiling, a beam: only as far as there is room
		if rise < 0.12:
			return
	var up := xf.translated(Vector3(0, rise, 0))
	if b.test_move(up, probe):
		return                       # a wall, not a step
	var down := KinematicCollision3D.new()
	if not b.test_move(up.translated(probe), Vector3(0, -rise - 0.05, 0), down):
		return                       # no floor behind the edge (a hole, a drop)
	if down.get_normal().angle_to(Vector3.UP) > b.floor_max_angle + 0.01:
		return                       # a steep slope, not a tread
	var h := rise - down.get_travel().length()
	if h < 0.03:
		return                       # just a slope - move_and_slide manages that itself
	b.global_position.y += h + 0.005
	b.velocity.y = 0.0
