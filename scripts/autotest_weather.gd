extends RefCounted
## Nápady z deště (2026-11-17, Ari): rozstřelitelné lampy, mokrý asfalt a louže, kapky a zamlžení
## mířidel, stopy vetřelců v blátě a sněhu, změna počasí během mise, vítr nese kouř a oheň.
## lamptest: --autotest=lamptest --mtype=terror --biome=town --hour=23 --seed=3
##   každou lampu (pouliční i žárovky) zkusí trefit paprskem z výšky očí; jednu rozstřelí přes
##   hit_breakable (hostitel → rpc _break) a ověří, že zhasne natrvalo (ani _electric ji nerozsvítí).

static func lamps(at: Node, p: Node) -> void:
	if p == null: return
	at._skip_brief()
	if not at.m().started(): return
	var m: Node = at.m()
	if at.step == 0:
		at.step = 1
		p.hp = 1.0e6
		for a in m.aliens():
			a.set_physics_process(false)
			a.global_position += Vector3(0, -200, 0)
		var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
		var n := 0
		var hit := 0
		var target: Node = null
		for l in m.map.get("elec_lights", []):
			if not is_instance_valid(l) or not l.has_meta("lamp_body"):
				continue
			n += 1
			var b: Node3D = l.get_meta("lamp_body")
			var ok := false
			for k in 8:
				var from: Vector3 = b.global_position + Vector3(3.0, 0, 0).rotated(Vector3.UP, TAU * k / 8.0)
				from.y = maxf(1.5, b.global_position.y - 2.0)
				var q := PhysicsRayQueryParameters3D.create(from, b.global_position + (b.global_position - from).normalized() * 0.5, Game.WORLD | Game.GLASS | 4)
				var h := space.intersect_ray(q)
				if not h.is_empty() and h.collider == b:
					ok = true
					break
			if ok:
				hit += 1
				if target == null and l.visible:
					target = l
		at.set_meta("lt_n", [n, hit])
		at.set_meta("lt_target", target)
		if target:
			var b2: Node = target.get_meta("lamp_body")
			m.hit_breakable(int(b2.get_meta("break")), 30.0, "bullet")
		at.set_meta("lt_t", 0)
		return
	at.set_meta("lt_t", int(at.get_meta("lt_t")) + 1)
	if int(at.get_meta("lt_t")) < 90:
		return
	var nh: Array = at.get_meta("lt_n")
	var t = at.get_meta("lt_target")
	var dark := false
	if t != null and is_instance_valid(t):
		dark = not t.visible and t.get_meta("shot", false)
		var lens = t.get_meta("lens", null)
		if is_instance_valid(lens): dark = dark and not lens.visible
	var lit := 0
	for l in m.map.get("elec_lights", []):
		if is_instance_valid(l) and l.visible: lit += 1
	at.out("RESULT lamptest lamps %d hittable %d shot_dark %s still_lit %d" % [nh[0], nh[1], dark, lit])
	at.get_tree().quit()

## wxtest: --autotest=wxtest --mtype=crash --biome=farm --weather=overcast --wxshift=rain@4 --wxblend=6
##   (then a second change it asks itself: rain → fog) - the rain comes, the ground soaks, puddles
##   show; then the rain goes and the mist rises.
static func shift(at: Node, p: Node) -> void:
	if p == null: return
	at._skip_brief()
	if not at.m().started(): return
	var m: Node = at.m()
	var wx: Node = m.wx
	if at.step == 0:
		at.step = 1
		p.hp = 1.0e6
		for a in m.aliens():
			a.set_physics_process(false)
			a.global_position += Vector3(0, -200, 0)
		at.set_meta("wx0", [m.weather, wx.wet, m.env.fog_density, wx.puddles != null])
		return
	if at.step == 1 and m.t > float(Game.cmd_arg("wxshift", "x@4").split("@")[1]) + float(Game.cmd_arg("wxblend", "6")) + 1.5:
		at.step = 2
		var ratio := -1.0
		if m.rain is GPUParticles3D: ratio = (m.rain as GPUParticles3D).amount_ratio
		var pc := 0
		if wx.puddles: pc = int(wx.puddles.get_meta("count", 0))
		at.set_meta("wx1", [m.weather, m.rain != null, ratio, wx.wet, pc, m._rain_out != null, wx.wind.length()])
		var fog0: float = m.env.fog_density
		at.set_meta("fog1", fog0)
		m._weather_shift.rpc("fog")
		at.set_meta("t2", m.t)
		return
	if at.step == 2 and m.t > float(at.get_meta("t2")) + float(Game.cmd_arg("wxblend", "6")) + 2.5:
		var a: Array = at.get_meta("wx0")
		var b: Array = at.get_meta("wx1")
		at.out("RESULT wxtest from %s wet %.2f -> %s rain %s ratio %.2f wet %.2f puddles %d sound %s wind %.2f -> %s rain %s sound %s fog %.3f -> %.3f" % [
			a[0], a[1], b[0], b[1], b[2], b[3], b[4], b[5], b[6], m.weather, m.rain != null, m._rain_out != null, float(at.get_meta("fog1")), m.env.fog_density])
		at.get_tree().quit()

## wxshot: --autotest=wxshot --mtype=terror --biome=town --weather=rain --hour=23 --seed=3
##   snímky louží a mokré ulice u lampy (wx_puddle_N.png), pak „po dešti“ za dne (wx_day.png).
static func shots(at: Node, p: Node) -> void:
	if p == null: return
	at._skip_brief()
	if at.step > 0 or not at.m().started(): return
	at.step = 1
	var m: Node = at.m()
	p.hp = 1.0e6
	for a in m.aliens():
		a.set_physics_process(false)
		a.visible = false
		a.global_position += Vector3(0, -200, 0)
	await at.get_tree().create_timer(1.0).timeout
	var wx: Node = m.wx
	var pud: Array = []
	if wx.puddles:
		for c in wx.puddles.get_children():
			var best := 99.0
			var lamp: Node3D = null
			for l in m.map.get("elec_lights", []):
				if is_instance_valid(l) and l.visible and (l as Node3D).global_position.distance_to(c.global_position) < best:
					best = (l as Node3D).global_position.distance_to(c.global_position)
					lamp = l
			pud.append([best, c, lamp])
	pud.sort_custom(func(a, b): return a[0] < b[0])
	at.out("[WX] puddles %d wet %.2f" % [pud.size(), wx.wet])
	for i in mini(3, pud.size()):
		var c: Node3D = pud[i][1]
		var dir := Vector3(1, 0, 0).rotated(Vector3.UP, i * 1.9)
		if pud[i][2] != null:
			dir = (pud[i][2] as Node3D).global_position - c.global_position
			dir.y = 0
			dir = dir.normalized()      # the lamp beyond the puddle: it mirrors in it
		p.global_position = c.global_position - dir * 4.5 + Vector3(0, 0.1, 0)
		p.velocity = Vector3.ZERO
		await at.get_tree().create_timer(0.8).timeout
		at._aim_at(p, c.global_position + Vector3(0, 0.1, 0))
		await at.get_tree().create_timer(0.8).timeout
		at._snap("wx_puddle_%d" % i)
	at.get_tree().quit()

## tracktest: --autotest=tracktest --mtype=crash --biome=forest --terrain=snow --day=1 --seed=3
##   (nebo --biome=farm --weather=rain): šedivák projde 12 m po zemi, jeho kroky (Alien._footsteps)
##   nechají stopy; pak kouřový granát a vítr: kouř se posune po větru (smoke_at, emitor jde s ním),
##   oheň se šíří víc po větru (_downwind). Snímek stop wx_tracks.png (s oknem).
static func tracks(at: Node, p: Node) -> void:
	if p == null: return
	at._skip_brief()
	if at.step > 0 or not at.m().started(): return
	at.step = 1
	var m: Node = at.m()
	p.hp = 1.0e6
	var al: Node = null
	for a in m.aliens():
		a.set_physics_process(false)
		if al == null and a.race in ["grey", "jestetan", "bijec"]:
			al = a
		else:
			a.global_position += Vector3(0, -200, 0)
	await at.get_tree().create_timer(1.0).timeout
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var made0: int = m.wx.tracks_made
	var tried := 0
	if al:
		# a straight walk over open ground near the soldier
		var start: Vector3 = p.global_position + Vector3(3, 0, 0)
		var dir := Vector3(0, 0, 1)
		al.dead = false
		for i in 120:
			var q: Vector3 = start + dir * (i * 0.1)
			var h := space.intersect_ray(PhysicsRayQueryParameters3D.create(q + Vector3(0, 3, 0), q + Vector3(0, -3, 0), Game.WORLD))
			if not h.is_empty(): q = h.position
			al.global_position = q
			al.velocity = dir * 1.6
			al._footsteps(0.016)
			tried += 1
		p.global_position = start + dir * 6.0 + Vector3(-2.5, 0.1, 0)
		await at.get_tree().create_timer(0.6).timeout
		at._aim_at(p, start + dir * 6.0)
		await at.get_tree().create_timer(0.6).timeout
		if DisplayServer.get_name() != "headless":
			at._snap("wx_tracks")
	var made: int = m.wx.tracks_made - made0
	# the wind: a smoke grenade drifts, a fire spreads downwind
	var w: Vector3 = m.wind_now()
	var sp: Vector3 = p.global_position + Vector3(0, 0, -6)
	m.add_smoke(sp)
	var sm: Dictionary = m.smokes[m.smokes.size() - 1]
	var t0: float = m.t
	await at.get_tree().create_timer(6.0).timeout
	var moved: float = (m.smoke_at(sm) - sp).length()
	var node_moved: float = ((sm["node"] as Node3D).global_position - (sp + Vector3(0, 1.2, 0))).length()
	var down: float = m._downwind(sp, sp + w.normalized() * 3.0) if w.length() > 0.05 else 1.0
	var up: float = m._downwind(sp, sp - w.normalized() * 3.0) if w.length() > 0.05 else 1.0
	at.out("RESULT tracktest weather %s wet %.2f terrain %s steps %d tracks %d wind %.2f smoke_drift %.2f m in %.1f s node %.2f fire_down %.2f fire_up %.2f" % [
		m.weather, m.wx.wet, m.map.get("terrain", ""), tried, made, w.length(), moved, m.t - t0, node_moved, down, up])
	at.get_tree().quit()

## lensshot: --autotest=lensshot --mtype=crash --biome=farm --weather=storm --seed=3
##   puška s továrním kolimátorem, míření venku v bouřce (kapky na sklíčku, wx_lens_rain.png),
##   pak přechod z chladu pod střechu (zamlžení, wx_lens_fog.png).
static func lens(at: Node, p: Node) -> void:
	if p == null: return
	at._skip_brief()
	if at.step > 0 or not at.m().started(): return
	at.step = 1
	var m: Node = at.m()
	var wx: Node = m.wx
	p.hp = 1.0e6
	for a in m.aliens():
		a.set_physics_process(false)
		a.global_position += Vector3(0, -200, 0)
	# out under the open sky
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	for k in 24:
		var q: Vector3 = p.global_position + Vector3(8.0 + k, 0, 0).rotated(Vector3.UP, k * 0.9)
		var up := space.intersect_ray(PhysicsRayQueryParameters3D.create(q + Vector3(0, 2.0, 0), q + Vector3(0, 40, 0), 1))
		var dn := space.intersect_ray(PhysicsRayQueryParameters3D.create(q + Vector3(0, 3.0, 0), q + Vector3(0, -3, 0), Game.WORLD))
		if up.is_empty() and not dn.is_empty():
			p.global_position = (dn.position as Vector3) + Vector3(0, 0.1, 0)
			break
	await at.get_tree().create_timer(1.0).timeout
	Input.action_press("aim")
	await at.get_tree().create_timer(7.0).timeout
	var n_rain: int = wx.drops.size()
	var mode: String = p.sight_mode()
	if DisplayServer.get_name() != "headless":
		at._snap("wx_lens_rain")
	# in from the cold
	wx._out_t = 30.0
	wx._was_under = false
	m.under_roof = true
	m._roof_t = 99.0
	wx._lens_tick(0.016)
	var fog: float = wx.lens_fog
	await at.get_tree().create_timer(0.4).timeout
	if DisplayServer.get_name() != "headless":
		at._snap("wx_lens_fog")
	await at.get_tree().create_timer(6.0).timeout
	at.out("RESULT lensshot sight %s drops %d fog %.2f after6s %.2f" % [mode, n_rain, fog, wx.lens_fog])
	Input.action_release("aim")
	at.get_tree().quit()

## pudcheck: --autotest=pudcheck --mtype=terror --biome=town --weather=rain --seed=3
##   (2026-11-22, Ari: černé fleky na zemi) každá louže: je nad ní střecha/strop (uvnitř domu)?
##   leží její viditelná plocha pod zdí, prahem nebo jinou věcí (část schovaná pod zdí = „půlkruh“)?
static func pudcheck(at: Node, p: Node) -> void:
	if p == null: return
	at._skip_brief()
	if at.step > 0 or not at.m().started(): return
	at.step = 1
	var m: Node = at.m()
	for a in m.aliens():
		a.set_physics_process(false)
		a.global_position += Vector3(0, -200, 0)
	await at.get_tree().create_timer(0.5).timeout
	var wx: Node = m.wx
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var n := 0
	var roofed := 0
	var under := 0
	var flagged: Array = []
	if wx.puddles:
		for c in wx.puddles.get_children():
			n += 1
			var mi := c as MeshInstance3D
			var pc: Vector3 = mi.global_position
			var q := PhysicsRayQueryParameters3D.create(pc + Vector3(0, 0.2, 0), pc + Vector3(0, 40, 0))
			q.hit_back_faces = true
			var roof := not space.intersect_ray(q).is_empty()
			var sz: Vector2 = (mi.mesh as PlaneMesh).size
			var bad := 0
			for ix in range(-4, 5):
				for iz in range(-4, 5):
					var lp := Vector3(ix / 8.0 * sz.x, 0, iz / 8.0 * sz.y)
					if Vector2(ix, iz).length() > 4.0: continue
					var w: Vector3 = mi.global_transform * lp
					var qd := PhysicsRayQueryParameters3D.create(w + Vector3(0, 2.5, 0), w + Vector3(0, -0.3, 0))
					var hd := space.intersect_ray(qd)
					if not hd.is_empty() and (hd.position as Vector3).y > pc.y + 0.05:
						bad += 1
			if roof: roofed += 1
			if bad > 0: under += 1
			if roof or bad > 0:
				at.out("[PUD] %s roof %s covered %d size %s" % [pc, roof, bad, sz])
				flagged.append([bad, mi])
	at.out("RESULT pudcheck puddles %d roofed %d under %d" % [n, roofed, under])
	if Game.cmd_arg("pudsnap", "") != "":
		flagged.sort_custom(func(a, b): return a[0] > b[0])
		if flagged.is_empty() and wx.puddles and wx.puddles.get_child_count() > 0:
			flagged.append([0, wx.puddles.get_child(0)])
		p.hp = 1.0e6
		for i in mini(3, flagged.size()):
			var c: Node3D = flagged[i][1]
			var dir := Vector3(1, 0, 0).rotated(Vector3.UP, i * 2.1)
			p.global_position = c.global_position - dir * 3.5 + Vector3(0, 0.1, 0)
			p.velocity = Vector3.ZERO
			await at.get_tree().create_timer(0.6).timeout
			at._aim_at(p, c.global_position)
			await at.get_tree().create_timer(0.8).timeout
			at._snap("pud_%s_%d" % [Game.cmd_arg("pudsnap", ""), i])
	at.get_tree().quit()

## scorchshot: --autotest=scorchshot --mtype=terror --biome=town --day=1 --seed=5
##   (2026-11-22) oheň u dveří domu a uvnitř u ležícího vojáka shoří, zbude obtisk sazí (Decal), ne černý
##   kotouč přes zdi; snímky scorch_N.png. RESULT: kolik po ohni zůstalo kotoučů (MeshInstance) a obtisků.
static func scorch(at: Node, p: Node) -> void:
	if p == null: return
	at._skip_brief()
	if at.step > 0 or not at.m().started(): return
	at.step = 1
	var m: Node = at.m()
	p.hp = 1.0e6
	for a in m.aliens():
		a.set_physics_process(false)
		a.visible = false
		a.global_position += Vector3(0, -200, 0)
	var spots: Array = []
	for d in m.map.get("doors", []):
		if spots.size() >= 2: break
		spots.append([(d["c"] as Vector3), d])
	for i in spots.size():
		m.ignite((spots[i][0] as Vector3) + Vector3(0, 0.3, 0), 1.0)
	await at.get_tree().create_timer(1.0).timeout
	var burnt: Array = []
	for id in m.fires.keys():
		burnt.append(m.fires[id]["pos"])
		m._fire_off(id)
	await at.get_tree().create_timer(0.5).timeout
	var discs := 0
	var decals := 0
	for c in m.get_children():
		if c is Decal:
			decals += 1
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is CylinderMesh:
			for bp in burnt:
				if Vector2((c as Node3D).global_position.x - bp.x, (c as Node3D).global_position.z - bp.z).length() < 0.3:
					discs += 1
	at.out("RESULT scorchshot decals %d discs %d (kotouče u ohňů)" % [decals, discs])
	if DisplayServer.get_name() == "headless":
		at.get_tree().quit()
		return
	var fp: Array = []
	for c in m.get_children():
		if c is Decal: fp.append((c as Node3D).global_position)
	# a fire in the open, right in front of the soldier: how the soot looks on plain ground
	var front: Vector3 = p.global_position - (p.global_basis.z * Vector3(1, 0, 1)).normalized() * 3.5
	m.ignite(front + Vector3(0, 0.3, 0), 1.0)
	await at.get_tree().create_timer(0.6).timeout
	for id in m.fires.keys():
		m._fire_off(id)
	fp.append(front)
	await at.get_tree().create_timer(9.0).timeout      # the last smoke drifts off
	if not fp.is_empty():
		at._aim_at(p, fp[-1])
		await at.get_tree().create_timer(0.8).timeout
		at._snap("scorch_%s_top" % Game.cmd_arg("tag", "x"))
	for i in spots.size():
		var d: Dictionary = spots[i][1]
		var c: Vector3 = spots[i][0]
		var across := Vector3(0, 0, 1) if d.get("along_x", true) else Vector3(1, 0, 0)
		p.global_position = c + across * 4.0 + Vector3(0, 0.1, 0)
		p.velocity = Vector3.ZERO
		await at.get_tree().create_timer(0.6).timeout
		at._aim_at(p, c)
		await at.get_tree().create_timer(0.8).timeout
		at._snap("scorch_%s_%d" % [Game.cmd_arg("tag", "x"), i])
	var k := 0
	for c in m.get_children():
		if is_instance_valid(c) and c is Decal and k < 3:
			var dp: Vector3 = (c as Node3D).global_position
			var off := Vector3(1.6, 0, 0)
			for t in 4:
				var q := PhysicsRayQueryParameters3D.create(dp + Vector3(0, 0.5, 0), dp + off.rotated(Vector3.UP, t * PI / 2) + Vector3(0, 0.5, 0), 1)
				if p.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
					off = off.rotated(Vector3.UP, t * PI / 2)
					break
			p.global_position = dp + off
			p.velocity = Vector3.ZERO
			await at.get_tree().create_timer(0.6).timeout
			at._aim_at(p, dp)
			await at.get_tree().create_timer(0.6).timeout
			at._snap("scorch_%s_d%d" % [Game.cmd_arg("tag", "x"), k])
			k += 1
	at.get_tree().quit()
