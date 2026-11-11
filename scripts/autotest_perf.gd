extends RefCounted
## perf: měření výkonu v misi (propady FPS). Voják je nesmrtelný, střílí na nejbližšího vetřelce
## jako v "solo", ale vetřelce nezabije (--kill=1 zabíjí). Každou sekundu vypíše čas snímku,
## na konci souhrn: průměr, 99. percentil a nejhorší snímek, plus kolik čeho ve scéně je.
static var _t := 0.0
static var _frames: Array = []
static var _proc: Array = []
static var _phys: Array = []
static var _next := 0.0
static var _last_us := 0
static var _prof_t := 0.0
static var _snap0 := {}
const PROF := preload("res://scripts/prof.gd")

static func run(at: Node, p: Node) -> void:
	if p == null: return
	at._skip_brief()
	var now := Time.get_ticks_usec()
	var dt := float(now - _last_us) / 1000.0 if _last_us > 0 else 0.0
	_last_us = now
	p.hp = 1.0e6
	var dur := float(Game.cmd_arg("dur", "40"))
	if at.t < 4.0: return
	if at.step == 0:
		at.step = 1
		p._click_lock = false
		at.out("[PERF] start: %s" % _census(at))
		PROF.reset(); _prof_t = at.t
	var a: Node = at._nearest(p)
	if a and Game.cmd_arg("fight", "1") == "1":
		if p.global_position.distance_to(a.global_position) > 14.0:
			var dir: Vector3 = (p.global_position - a.global_position)
			dir.y = 0
			p.global_position = a.global_position + dir.normalized() * 12.0 + Vector3(0, 0.3, 0)
		at._aim_at(p, a.global_position + Vector3(0, 0.9, 0))
		if Game.cmd_arg("kill", "0") != "1":
			a.hp = maxf(a.hp, 50.0)
		Input.action_press("aim")
		var shoot: bool = int(p.weapon().get("loaded", 0)) > 0
		if shoot: Input.action_press("fire")
		else: Input.action_release("fire")
		if not shoot and Engine.get_physics_frames() % 4 < 2: Input.action_press("reload")
		else: Input.action_release("reload")
	_t += dt / 1000.0
	var snap: Dictionary = PROF.acc.duplicate()
	if dt > 40.0 and at.step == 1:
		var top := []
		for k in snap:
			var d := int(snap[k]) - int(_snap0.get(k, 0))
			if d > 3000: top.append("%s %.0f" % [k, d / 1000.0])
		at.out("[PERF] spike-kde: %s" % ", ".join(top))
		at.out("[PERF] spike %.0f ms (proc %.1f phys %.1f) aliens %d nodes %d" % [dt, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, at.m().alive_aliens(), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	_snap0 = snap
	if dt > 0.0:
		_frames.append(dt)
		_proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		_phys.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	if at.t > _next:
		_next = at.t + 2.0
		var vp := at.get_viewport()
		var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		var pr := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		var ob := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
		at.out("[PERF] fyzika aktivni %d pary %d ostrovy %d | nav mapy %d regiony %d agenti %d prekazky %d" % [Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS), Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS), Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT), Performance.get_monitor(Performance.NAVIGATION_ACTIVE_MAPS), Performance.get_monitor(Performance.NAVIGATION_REGION_COUNT), Performance.get_monitor(Performance.NAVIGATION_AGENT_COUNT), Performance.get_monitor(Performance.NAVIGATION_OBSTACLE_COUNT)])
		at.out("[PERF] render draw %d prim %d obj %d" % [dc, pr, ob])
		at.out("[PERF] frame %.1f ms (max %.1f) proc %.1f phys %.1f aliens %d alive %d nodes %d" % [_avg(_frames, 60), _max(_frames, 60), _avg(_proc, 60), _avg(_phys, 60), at.m().aliens().size(), at.m().alive_aliens(), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	if Game.cmd_arg("rab", "") == "1":
		_rab(at)
	if Game.cmd_arg("ab", "") == "1":
		_ab(at)
	if at.t - _prof_t >= 10.0 and _prof_t > 0.0:
		at.out("[PERF] profil za %.0f s:%s" % [at.t - _prof_t, PROF.report(at.t - _prof_t)])
		PROF.reset(); _prof_t = at.t
	if Game.cmd_arg("snap", "") != "" and at.t > 7.0 and not at.has_meta("snapped"):
		at.set_meta("snapped", true)
		at.get_viewport().get_texture().get_image().save_png(Game.cmd_arg("snap", ""))
	if at.t > dur:
		var s := _frames.duplicate(); s.sort()
		var p99: float = s[int(s.size() * 0.99)] if s.size() > 0 else 0.0
		at.out("[PERF] census: %s" % _census(at))
		at.out("RESULT perf frames %d avg %.2f ms p99 %.2f max %.2f proc %.2f phys %.2f" % [s.size(), _avg(_frames, 0), p99, _max(_frames, 0), _avg(_proc, 0), _avg(_phys, 0)])
		at.get_tree().quit()

static func _census(at: Node) -> String:
	var root: Node = at.m()
	var c := {}
	for k in ["OmniLight3D", "SpotLight3D", "SpringBoneSimulator3D", "Skeleton3D", "AnimationPlayer", "MeshInstance3D", "GPUParticles3D", "CPUParticles3D", "AudioStreamPlayer3D", "RayCast3D", "NavigationAgent3D", "BoneAttachment3D", "SkeletonIK3D", "CollisionShape3D", "StaticBody3D", "RigidBody3D", "Area3D", "CharacterBody3D", "NavigationObstacle3D", "GPUParticles3D"]:
		c[k] = root.find_children("*", k, true, false).size()
	var sh := 0
	for l in root.find_children("*", "Light3D", true, false):
		if (l as Light3D).shadow_enabled and (l as Light3D).visible: sh += 1
	c["stinova_svetla"] = sh
	return str(c)

static func _avg(a: Array, n: int) -> float:
	var s := a.slice(-n) if n > 0 else a
	if s.is_empty(): return 0.0
	var t := 0.0
	for v in s: t += v
	return t / s.size()

static func _max(a: Array, n: int) -> float:
	var s := a.slice(-n) if n > 0 else a
	var m := 0.0
	for v in s: m = maxf(m, v)
	return m

static var _ph := -1
static var _ph_phys: Array = []
static var _ph_proc: Array = []
static var _ph_fr: Array = []
static func _sum(a: Array) -> float:
	var t := 0.0
	for v in a: t += v
	return t
const PHASES := ["zaklad", "pruziny vyp", "navigace vyp", "civilove vyp", "vetrelci vyp", "zaklad2", "kostry vyp", "stiny vyp"]
static var _cpu0 := 0
static func _cpu_ms() -> int:
	var f := FileAccess.open("/proc/self/stat", FileAccess.READ)
	if f == null: return 0
	var parts := f.get_as_text().split(" ")
	return (int(parts[13]) + int(parts[14])) * 10
static func _ab(at: Node) -> void:
	Engine.max_fps = 60
	var ph := int((at.t - 5.0) / 6.0)
	if ph != _ph:
		var cpu := _cpu_ms()
		if _ph >= 0 and _ph < PHASES.size():
			at.out("[AB] %-14s CPU %.0f ms za sekundu" % [PHASES[_ph], (cpu - _cpu0) / 6.0])
		_cpu0 = cpu
		if false:
			at.out("[AB] %-14s snimek %.2f ms (CPU za sekundu %.0f ms)  max-phys %.2f max-proc %.2f" % [PHASES[_ph], _avg(_ph_fr, 0), _sum(_ph_fr) / 6.0, _avg(_ph_phys, 0), _avg(_ph_proc, 0)])
		_ph_phys.clear(); _ph_proc.clear(); _ph_fr.clear()
		_ph = ph
		var root: Node = at.m()
		for sb in root.find_children("*", "SpringBoneSimulator3D", true, false): sb.active = ph != 1
		NavigationServer3D.set_active(ph != 2)
		for c in root.get_tree().get_nodes_in_group("civilians"): c.process_mode = Node.PROCESS_MODE_DISABLED if ph == 3 else Node.PROCESS_MODE_INHERIT
		for a in root.aliens(): a.process_mode = Node.PROCESS_MODE_DISABLED if ph == 4 else Node.PROCESS_MODE_INHERIT
		for k in root.find_children("*", "Skeleton3D", true, false): k.process_mode = Node.PROCESS_MODE_DISABLED if ph == 6 else Node.PROCESS_MODE_INHERIT
		for l in root.find_children("*", "Light3D", true, false):
			if not l.has_meta("sh0"): l.set_meta("sh0", l.shadow_enabled)
			l.shadow_enabled = false if ph == 7 else bool(l.get_meta("sh0"))
	if not _frames.is_empty(): _ph_fr.append(_frames[-1])
	_ph_phys.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	_ph_proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)

static var _rph := -1
static var _rv: Array = []
const RPHASES := ["zaklad", "bodove stiny vyp", "mesic bez stinu", "mesic 2 deleni 40 m", "mlha vyp", "vetrelci skryti", "hraci skryti", "zaklad2"]
static func _rab(at: Node) -> void:
	var ph := int((at.t - 6.0) / 5.0)
	if ph != _rph:
		if _rph >= 0 and _rph < RPHASES.size() and not _rv.is_empty():
			var a := [0.0, 0.0, 0.0, 0.0]
			for v in _rv:
				for i in 4: a[i] += v[i]
			for i in 4: a[i] /= _rv.size()
			at.out("[RAB] %-20s draw %6.0f prim %8.0f obj %6.0f frame %.1f ms" % [RPHASES[_rph], a[0], a[1], a[2], a[3]])
		_rv.clear()
		_rph = ph
		var root: Node = at.m()
		for l in root.find_children("*", "Light3D", true, false):
			if not l.has_meta("sh0"): l.set_meta("sh0", l.shadow_enabled)
			if l is DirectionalLight3D:
				l.shadow_enabled = ph != 2 and bool(l.get_meta("sh0"))
				l.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if ph == 3 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
				l.directional_shadow_max_distance = 40.0 if ph == 3 else 100.0
			else:
				l.shadow_enabled = ph != 1 and bool(l.get_meta("sh0"))
		root.env.volumetric_fog_enabled = ph != 4 and Game.volumetric
		for a in root.aliens(): a.visible = ph != 5
		for p in root.players():
			if p != root.local_player(): p.visible = ph != 6
	_rv.append([RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME), at.get_process_delta_time() * 1000.0])

## navcache: rozbije 25 kusů zdí a porovná cesty z paměti po čtvercích (nav_cache.gd) s plným přepečením.
static func navcache(at: Node, p: Node) -> void:
	if p == null: return
	at._skip_brief()
	var mi: Node = at.m()
	if at.step == 0 and at.t > 3.0:
		at.step = 1
		var arr: Array = mi.map.get("breakables", [])
		var c: Vector3 = p.global_position
		var idx := range(arr.size()).filter(func(i): return is_instance_valid(arr[i]) and not arr[i].get_meta("broken", false))
		idx.sort_custom(func(a, b): return arr[a].global_position.distance_to(c) < arr[b].global_position.distance_to(c))
		var n := 0
		var gs := {}
		for i in idx.slice(0, 25):
			for ch in (arr[i] as Node).get_children():
				if ch.has_meta("mg"): gs[ch.get_meta("mg")] = true
			for dn in (arr[i] as Node).get_meta("deco", []):
				if is_instance_valid(dn) and dn.has_meta("mg"): gs[dn.get_meta("mg")] = true
		var vb := 0
		for g in gs: vb += _verts(g)
		at.set_meta("mg_groups", gs.keys())
		at.set_meta("mg_vb", vb)
		for i in idx.slice(0, 25):
			mi._break(i)
			n += 1
		at.set_meta("t_break", at.t)
		at.out("[NAVC] broke %d pieces" % n)
	if at.step == 1 and at.t > float(at.get_meta("t_break")) + 4.0 and mi._nav_cache and not mi._nav_cache.busy():
		at.step = 2
		var nav: NavigationRegion3D = mi.find_child("Nav", true, false)
		var got: NavigationMesh = nav.navigation_mesh
		var ref: NavigationMesh = got.duplicate()
		var d := NavigationMeshSourceGeometryData3D.new()
		var t0 := Time.get_ticks_msec()
		NavigationServer3D.parse_source_geometry_data(ref, d, nav)
		var t1 := Time.get_ticks_msec()
		NavigationServer3D.bake_from_source_geometry_data(ref, d)
		at.out("[NAVC] full parse %d ms, bake %d ms" % [t1 - t0, Time.get_ticks_msec() - t1])
		var same := got.get_polygon_count() == ref.get_polygon_count() and got.get_vertices().size() == ref.get_vertices().size()
		var va := 0
		var gl: Array = at.get_meta("mg_groups", [])
		for g in gl: va += _verts(g)
		at.out("[NAVC] sloucene zdi: %d skupin, vrcholu %d -> %d" % [gl.size(), int(at.get_meta("mg_vb", 0)), va])
		at.out("RESULT navcache same %s polys %d/%d verts %d/%d" % [same, got.get_polygon_count(), ref.get_polygon_count(), got.get_vertices().size(), ref.get_vertices().size()])
		at.get_tree().quit()

## farview: pohled do dálky (Ari: ve městě propady FPS při pohledu do dálky). Voják se postaví
## na okraj mapy i doprostřed a rozhlédne se do 8 stran; pro každý pohled vypíše, kolik se kreslí.
static var _fv := []
static var _fv_i := -1
static var _fv_n := 0
static var _fv_acc := [0.0, 0, 0, 0, 0.0]
static func farview(at: Node, p: Node) -> void:
	if p == null: return
	at._skip_brief()
	p.hp = 1.0e6
	var now := Time.get_ticks_usec()
	var dt := float(now - _last_us) / 1000.0 if _last_us > 0 else 0.0
	_last_us = now
	if at.t < 4.0: return
	var root: Node = at.m()
	if _fv.is_empty():
		for a in root.aliens(): a.process_mode = Node.PROCESS_MODE_DISABLED
		var lo := Vector3(1e9, 0, 1e9); var hi := Vector3(-1e9, 0, -1e9)
		for n in root.find_children("*", "MeshInstance3D", true, false):
			var q: Vector3 = (n as Node3D).global_position
			lo = Vector3(minf(lo.x, q.x), 0, minf(lo.z, q.z)); hi = Vector3(maxf(hi.x, q.x), 0, maxf(hi.z, q.z))
		var c := (lo + hi) / 2.0
		RenderingServer.viewport_set_measure_render_time(at.get_viewport().get_viewport_rid(), true)
		at.out("[FV] mapa %.0f x %.0f m | %s" % [hi.x - lo.x, hi.z - lo.z, _kinds(root)])
		for spot in [c, Vector3(lo.x + 6, 0, c.z), lo + Vector3(6, 0, 6)]:
			for k in 6:
				_fv.append([spot, k * TAU / 6.0])
		_fv_i = -1
	if _fv_n <= 0:
		if _fv_i >= 0:
			var f: float = _fv_acc[0] / 12.0
			at.out("[FV] pohled %2d  snimek %.1f ms  CPU kresleni %.2f ms  draw %d  obj %d  prim %d" % [_fv_i, f, _fv_acc[4] / 12.0, _fv_acc[1] / 12, _fv_acc[2] / 12, _fv_acc[3] / 12])
			_fv_sum.append([f, _fv_acc[1] / 12, _fv_acc[2] / 12, _fv_acc[3] / 12, _fv_acc[4] / 12.0])
		_fv_i += 1
		if _fv_i >= _fv.size():
			var s := [0.0, 0, 0, 0, 0.0]; var mx := [0.0, 0, 0, 0, 0.0]
			for r in _fv_sum:
				for j in 5:
					s[j] += r[j]; mx[j] = maxf(mx[j], r[j])
			var n := float(_fv_sum.size())
			at.out("RESULT farview avg %.1f ms cpu %.2f draw %d obj %d prim %d | max %.1f ms cpu %.2f draw %d obj %d prim %d" % [s[0] / n, s[4] / n, s[1] / n, s[2] / n, s[3] / n, mx[0], mx[4], mx[1], mx[2], mx[3]])
			at.get_tree().quit()
			return
		var v: Array = _fv[_fv_i]
		var sp: Vector3 = v[0]
		var hit: Dictionary = root.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(sp + Vector3(0, 40, 0), sp - Vector3(0, 10, 0)))
		p.global_position = (hit["position"] if hit else sp) + Vector3(0, 0.2, 0)
		p.velocity = Vector3.ZERO
		p.rotation.y = v[1]
		p.pitch = 0.02
		_fv_n = 22
		_fv_acc = [0.0, 0, 0, 0, 0.0]
		if Game.cmd_arg("snap", "") != "" and _fv_i % 6 == 0:
			at.set_meta("snap_at", _fv_i)
		return
	p.rotation.y = _fv[_fv_i][1]
	p.pitch = 0.02
	_fv_n -= 1
	if _fv_n < 12:
		_fv_acc[0] += dt
		_fv_acc[1] += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		_fv_acc[2] += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
		_fv_acc[3] += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		_fv_acc[4] += RenderingServer.viewport_get_measured_render_time_cpu(at.get_viewport().get_viewport_rid()) + RenderingServer.get_frame_setup_time_cpu()
	if _fv_n == 1 and at.has_meta("snap_at") and int(at.get_meta("snap_at")) == _fv_i:
		at.get_viewport().get_texture().get_image().save_png(Game.cmd_arg("snap", "") + "_%d.png" % _fv_i)
static var _fv_sum := []

static func _kinds(root: Node) -> String:
	var mi := root.find_children("*", "MeshInstance3D", true, false)
	var mm := root.find_children("*", "MultiMeshInstance3D", true, false)
	var merged := 0; var vr := 0; var small := 0; var tri := 0
	for n in mi:
		var m := n as MeshInstance3D
		if m.name.begins_with("Merged"): merged += 1
		if m.visibility_range_end > 0.0: vr += 1
		if m.mesh and m.get_aabb().size.length() < 1.5: small += 1
	var inst := 0
	for n in mm:
		var x := n as MultiMeshInstance3D
		if x.multimesh: inst += x.multimesh.instance_count
	var bk := [0, 0, 0, 0, 0, 0]; var lim := [0.3, 0.6, 1.0, 2.0, 4.0, 1e9]; var names := {}
	for n in mi:
		var m := n as MeshInstance3D
		if m.mesh == null or not m.is_visible_in_tree(): continue
		var L := (m.global_transform.basis * m.get_aabb().size).abs()
		var l := maxf(L.x, maxf(L.y, L.z))
		for j in 6:
			if l < lim[j]: bk[j] += 1; break
		var nm := String(m.mesh.resource_path.get_file()) if m.mesh.resource_path != "" else m.mesh.get_class()
		names[nm] = names.get(nm, 0) + 1
	var nav: Node = root.find_child("Nav", true, false)
	var why := {}
	for n in mi:
		var m := n as MeshInstance3D
		if not m.mesh is BoxMesh: continue
		var par := m.get_parent()
		var r := "?"
		if par == nav: r = "primo:" + (",".join(m.get_meta_list()) if not m.get_meta_list().is_empty() else ("pruhl" if m.material_override is BaseMaterial3D and (m.material_override as BaseMaterial3D).transparency != 0 else ("nomat" if m.material_override == null else "jine")))
		elif par is StaticBody3D and par.get_parent() == nav:
			r = "telo:" + (",".join(par.get_meta_list()) if not par.get_meta_list().is_empty() else "deti%d" % par.get_child_count())
		else:
			r = "hloub:" + par.get_class() + "/" + String(par.name).left(12) + "<" + (par.get_parent().get_class() if par.get_parent() else "")
		why[r] = why.get(r, 0) + 1
	var wk := why.keys(); wk.sort_custom(func(a, b): return why[a] > why[b])
	var ws := []
	for k in wk.slice(0, 14): ws.append("%s %d" % [k, why[k]])
	print("[FV] box proc: ", ", ".join(ws))
	var vis := {}
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.is_visible_in_tree(): continue
		var k := g.get_class()
		if g is MeshInstance3D and (g as MeshInstance3D).mesh:
			var mm2: Mesh = (g as MeshInstance3D).mesh
			k = (mm2.resource_path.get_file().get_slice("::", 0) if mm2.resource_path != "" else mm2.get_class()) + ("/srf%d" % mm2.get_surface_count() if mm2.get_surface_count() > 1 else "")
			if String(g.name).begins_with("Merged"): k = String(g.name)
		vis[k] = vis.get(k, 0) + 1
	var vk := vis.keys(); vk.sort_custom(func(a, b): return vis[a] > vis[b])
	var vs := []
	for k in vk.slice(0, 25): vs.append("%s %d" % [k, vis[k]])
	print("[FV] viditelne: ", ", ".join(vs))
	var top := names.keys(); top.sort_custom(func(a, b): return names[a] > names[b])
	var ts := []
	for k in top.slice(0, 12): ts.append("%s %d" % [k, names[k]])
	var mmb := []
	for n in mm.slice(0, 3): mmb.append(str((n as MultiMeshInstance3D).get_aabb().size))
	return "velikosti <0,3/0,6/1/2/4/vic m: %s | druhy: %s | trava aabb %s\n" % [str(bk), ", ".join(ts), ", ".join(mmb)] + "sitě %d (sloučené %d, s dosahem %d, malé <1,5 m %d) multimesh %d (%d kusů)" % [mi.size(), merged, vr, small, mm.size(), inst]

## mergeshot: snímky města zešikma za dne bez mlhy (kontrola, že sloučené zdi a dosah drobností
## vypadají stejně): --nomerge=1 bez slučování rozbitelných zdí, --lod=N s dosahem drobností.
static func mergeshot(at: Node, p: Node) -> void:
	if p == null or at.step > 0 or not at.m().started():
		return
	at.step = 1
	at._skip_brief()
	var root: Node = at.m()
	for a in root.aliens(): a.process_mode = Node.PROCESS_MODE_DISABLED
	for c in root.get_tree().get_nodes_in_group("civilians"): c.process_mode = Node.PROCESS_MODE_DISABLED
	root.hud.visible = false
	var size: float = root.map["size"]
	var cam := Camera3D.new()
	cam.fov = 60
	cam.far = 500
	root.add_child(cam)
	cam.make_current()
	root.env.fog_enabled = false
	root.env.volumetric_fog_enabled = false
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.2
	sun.rotation = Vector3(-1.1, 0.4, 0)
	root.add_child(sun)
	if Game.cmd_arg("break", "") == "1":
		var arr: Array = root.map.get("breakables", [])
		var c := Vector3(size / 2, 0, size / 2)
		for i in arr.size():
			if is_instance_valid(arr[i]) and i % 3 == 0 and String(arr[i].get_meta("break_kind", "")) != "glass":
				root._break(i)
		await root.get_tree().create_timer(3.5).timeout
	var spots := [[Vector3(-5, 14, -5), Vector3(size / 2, 0, size / 2)], [Vector3(size + 5, 6, size / 2), Vector3(size / 2, 2, size / 2)],
		[Vector3(size / 2, 2.2, 4), Vector3(size / 2, 2.0, size)], [Vector3(4, 2.2, size / 2), Vector3(size, 2.0, size / 2)]]
	for i in spots.size():
		cam.look_at_from_position(spots[i][0], spots[i][1], Vector3.UP)
		await root.get_tree().create_timer(0.8).timeout
		at.get_viewport().get_texture().get_image().save_png(Game.cmd_arg("snap", "/tmp/ms") + "_%d.png" % i)
	at.out("RESULT mergeshot done")
	at.get_tree().quit()

static func _verts(g) -> int:
	if not is_instance_valid(g) or (g as MeshInstance3D).mesh == null: return 0
	var m: Mesh = (g as MeshInstance3D).mesh
	var t := 0
	for si in m.get_surface_count():
		t += (m.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return t
