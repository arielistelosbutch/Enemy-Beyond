extends Node
const FitCollision := preload("res://scripts/fit_collision.gd")
## (2026-11-27, Ari: „zničitelné stromy, které začnou hořet po laseru nebo plazmě; kanónem přes kmen,
## že je to přepůlí a shodí na zem; auta, co začnou hořet a potom vybuchnou")
##
## Stromy a auta na mapě (MapGen._wrecks -> info["wrecks"], na všech počítačích stejné pořadí, takže
## index je všude stejný; každé tělo kolize modelu má meta "wreck" = index).
## Rozhoduje hostitel (zdraví, žár, kdy co vzplane/padne/vybuchne), stav rozešle rpc _state; každý
## počítač pak sám přehraje pád, plameny v koruně, kouř z kapoty, výbuch a výměnu za vrak.
##   strom: žár z laseru/plazmy/zápalné munice a od ohně vedle -> hoří (oheň Mission.ignite u paty +
##          plameny v koruně bez světla), po BURN_TIME zůstane ohořelý kmen (v_dead_tree);
##          kanón (autokanón, plazmový, laserový) nebo výbuch u kmene -> pád (směr od střelce, hostitel
##          hledá směr bez zdi), zůstane pařez, kmen leží (jde přelézt), kdo stojí pod ním, dostane ránu.
##   auto: kulky málo, plazma/laser víc, kanón a výbuchy nejvíc; pod CAR_SMOKE kouří, pod CAR_FIRE
##          hoří (oheň) a za 8-14 s vybuchne (Mission.explode) -> ohořelý vrak (v_car_burnt);
##          výbuch zasáhne i auta vedle (řetěz), oheň vedle auto pomalu dopaluje.
## Hardcore: žádné texty ani ukazatele. Nic se nepočítá každý snímek (jen hostitel 1× za s u ohňů).

const TREES := ["v_tree_spruce", "v_tree_spruce2", "v_tree_pine", "v_tree_oak", "v_tree_oak2", "v_tree_birch", "v_tree_fruit"]
const CARS := ["v_car_red", "v_car_blue", "v_car_beige"]

const TREE_HP := 220.0           # kanón: autokanón 150 ×1,0 = dvě rány, plazmový/laserový kanón jedna
const CAR_HP := 300.0
const IGNITE_HEAT := 70.0        # žár, při kterém strom vzplane (laserová puška ~3 rány, plazmová 1-2)
const BURN_TIME := 45.0          # jak dlouho strom hoří, než z něj zbude ohořelý kmen
const BURN_MAX := 10             # nejvíc naráz hořících stromů (plameny v koruně; oheň má svůj strop)
const CAR_SMOKE := 0.55          # pod tímhle podílem zdraví auto kouří
const CAR_FIRE := 0.25           # pod tímhle hoří a pak vybuchne
const CAR_FUSE := [8.0, 14.0]
const CAR_BLAST := [6.5, 110.0]  # poloměr a síla výbuchu auta (granát 6,5 m / 100)
const FALL_TIME := 1.9
const FALL_HIT := 45.0           # komu spadne kmen na hlavu
const NEAR_FIRE := 4.0           # oheň do téhle vzdálenosti zahřívá strom / pálí auto

## zdraví -> násobek podle druhu zásahu
const TREE_MULT := {"bullet": 0.0, "laser": 0.15, "plasma": 0.25, "cannon": 1.0, "explosion": 2.4, "fire": 0.0}   # granát u kmene ho porazí
const CAR_MULT := {"bullet": 0.35, "laser": 0.8, "plasma": 1.0, "cannon": 1.4, "explosion": 1.5, "fire": 1.0}
## žár stromu podle druhu (jen horké zásahy)
const TREE_HEAT := {"laser": 1.0, "plasma": 1.3, "cannon": 1.0, "explosion": 0.6, "fire": 1.0}

enum {OK, SMOKE, BURN, DOWN, GONE}
const NO_DIR := -99.0            # strom nemá kam padnout (jen se zlomí)

var mission: Node
var nodes: Array = []            # model (Node3D) nebo null, když už je pryč
var kind: Array = []             # "tree" / "car"
var hp: PackedFloat32Array
var heat: PackedFloat32Array
var state: PackedInt32Array
var base: PackedVector3Array     # pata stromu / střed auta na zemi
var tall: PackedFloat32Array     # výška stromu (m) / auta
var _until := {}                 # i -> čas (hostitel: dohoření stromu, výbuch auta)
var _by := {}                    # i -> kdo ho zapálil (zabití výbuchem auta)
var _fx := {}                    # i -> uzel efektu (plameny, kouř)
var _grid := {}                  # Vector2i -> [i] (buňky 4 m)
var _t := 0.0
var _tick := 0.0
static var _tall_cache := {}

func setup(m: Node) -> void:
	mission = m
	name = "Wreck"
	var arr: Array = m.map.get("wrecks", [])
	var n := arr.size()
	hp.resize(n); heat.resize(n); state.resize(n); base.resize(n); tall.resize(n)
	for i in n:
		var w: Node3D = arr[i]
		nodes.append(w)
		var k := kind_of(String(w.get_meta("model", "")))
		kind.append(k)
		hp[i] = TREE_HP if k == "tree" else CAR_HP
		heat[i] = 0.0
		state[i] = OK
		base[i] = w.global_position
		tall[i] = _height(w)
		var c := Vector2i(floori(w.global_position.x / 4.0), floori(w.global_position.z / 4.0))
		if not _grid.has(c): _grid[c] = []
		_grid[c].append(i)
	if Game.autotest() != "": print("[WRECK] trees %d cars %d" % [kind.count("tree"), kind.count("car")])

static func kind_of(model: String) -> String:
	if model in TREES: return "tree"
	if model in CARS: return "car"
	return ""

## MapGen: každé tělo kolize stromu/auta dostane index (zásah ho pak najde).
static func tag(n: Node3D, i: int) -> void:
	for sb in n.find_children("*", "StaticBody3D", true, false):
		(sb as Node).set_meta("wreck", i)

func count() -> int:
	return nodes.size()

func _height(w: Node3D) -> float:
	var key := String(w.get_meta("model", ""))
	if not _tall_cache.has(key):
		var top := 1.5
		for mi in w.find_children("*", "MeshInstance3D", true, false):
			var m3 := mi as MeshInstance3D
			if m3.mesh == null: continue
			# výška vrchu sítě v souřadnicích modelu (bez měřítka modelu)
			var rel: Transform3D = w.global_transform.affine_inverse() * m3.global_transform
			var bb: AABB = rel * m3.mesh.get_aabb()
			top = maxf(top, bb.end.y)
		_tall_cache[key] = top
	return float(_tall_cache[key]) * w.scale.y

## Strom/auto se pohnulo (test, editor): nová buňka mřížky a pata.
func moved(i: int) -> void:
	for c in _grid:
		_grid[c].erase(i)
	base[i] = (nodes[i] as Node3D).global_position
	var c := Vector2i(floori(base[i].x / 4.0), floori(base[i].z / 4.0))
	if not _grid.has(c): _grid[c] = []
	_grid[c].append(i)

func near(p: Vector3, r: float) -> Array:
	var out := []
	var c0 := Vector2i(floori((p.x - r) / 4.0), floori((p.z - r) / 4.0))
	var c1 := Vector2i(floori((p.x + r) / 4.0), floori((p.z + r) / 4.0))
	for x in range(c0.x, c1.x + 1):
		for z in range(c0.y, c1.y + 1):
			for i in _grid.get(Vector2i(x, z), []):
				if state[i] != GONE and Vector2(base[i].x - p.x, base[i].z - p.z).length() < r:
					out.append(i)
	return out

# ---- zásahy (hostitel) ------------------------------------------------------------------------

## Hráč (rpc_id(1)): zásah do stromu/auta @a i. @a wkind bullet/laser/plasma/cannon/explosion,
## @a hot = laser, plazma, zápalná munice (strom se zahřívá), @a from = odkud střela letěla.
@rpc("any_peer", "call_local", "reliable")
func hit_rpc(i: int, dmg: float, wkind: String, hot: bool, from: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var by := "-"
	var sid := multiplayer.get_remote_sender_id()
	if sid == 0: sid = 1
	for p in mission.players():
		if p.get_multiplayer_authority() == sid:
			by = String(p.name)
	hit(i, dmg, wkind, hot, from, by)

func hit(i: int, dmg: float, wkind: String, hot: bool, from: Vector3, by := "-") -> void:
	if not multiplayer.is_server() or i < 0 or i >= nodes.size():
		return
	var st := state[i]
	if st == GONE or st == DOWN:
		return
	if kind[i] == "tree":
		if hot and st != BURN:
			heat[i] += dmg * float(TREE_HEAT.get(wkind, 1.0))
			if heat[i] >= IGNITE_HEAT:
				_tree_burn(i, by)
		hp[i] -= dmg * float(TREE_MULT.get(wkind, 0.0))
		if hp[i] <= 0.0:
			_tree_fall(i, from, by)
	else:
		hp[i] -= dmg * float(CAR_MULT.get(wkind, 0.35))
		_car_check(i, by)

## Výbuch (Mission.explode): stromy u kmene padají, kolem se zahřejí; auta dostanou ránu.
func blast(p: Vector3, radius: float, dmg: float, by := "-") -> void:
	if not multiplayer.is_server():
		return
	for i in near(p, radius + 1.0):
		var d := Vector2(base[i].x - p.x, base[i].z - p.z).length()
		var k := clampf(1.15 - d / (radius + 1.0), 0.15, 1.0)
		if kind[i] == "tree":
			# u kmene (do 1,8 m) plnou silou, dál jen ožehne
			hit(i, dmg * (k if d < 1.8 else k * 0.25), "explosion", true, p, by)
		else:
			hit(i, dmg * k, "explosion", true, p, by)

func _process(delta: float) -> void:
	_t += delta
	if not multiplayer.is_server() or nodes.is_empty():
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 1.0
	# ohně kolem: stromy se zahřívají (lesní požár jde pomalu), auta dohořívají
	for f in mission.fires.values():
		var fp: Vector3 = f["pos"]
		for i in near(fp, NEAR_FIRE):
			if kind[i] == "tree":
				if state[i] == OK:
					heat[i] += 7.0 * randf_range(0.5, 1.5)
					if heat[i] >= IGNITE_HEAT:
						_tree_burn(i, "-")
			elif state[i] != GONE:
				hp[i] -= 9.0
				_car_check(i, "-")
	for i in _until.keys():
		if _t < float(_until[i]):
			continue
		_until.erase(i)
		if kind[i] == "tree" and state[i] == BURN:
			_state.rpc(i, GONE, 0.0)          # ohořelý kmen
		elif kind[i] == "car" and state[i] != GONE:
			var at := base[i] + Vector3(0, 0.6, 0)
			_state.rpc(i, GONE, 0.0)          # vrak (napřed, ať výbuch nezasáhne sám sebe)
			mission.explode(at, CAR_BLAST[0], CAR_BLAST[1], String(_by.get(i, "-")), true)
			mission.ignite(base[i], 1.1)

func _tree_burn(i: int, by: String) -> void:
	var burning := 0
	for j in state.size():
		if state[j] == BURN and kind[j] == "tree": burning += 1
	if burning >= BURN_MAX:
		heat[i] = IGNITE_HEAT * 0.8          # (počká, až některý dohoří)
		return
	_by[i] = by
	_until[i] = _t + BURN_TIME * randf_range(0.85, 1.15)
	_state.rpc(i, BURN, 0.0)
	mission.ignite(base[i], 1.0)

func _car_check(i: int, by: String) -> void:
	var f := hp[i] / CAR_HP
	if state[i] == OK and f < CAR_SMOKE:
		_state.rpc(i, SMOKE, 0.0)
	if state[i] != BURN and f < CAR_FIRE:
		_by[i] = by
		_state.rpc(i, BURN, 0.0)
		mission.ignite(base[i], 1.0)
		_until[i] = _t + randf_range(CAR_FUSE[0], CAR_FUSE[1])
	if f < -0.35 and state[i] == BURN:
		_until[i] = minf(float(_until.get(i, _t)), _t + 0.4)     # dostalo plnou ránu: hned

## Hostitel: kam strom padne. Napřed od střelce, pak do stran, nikdy do zdi (paprsek v půlce a
## u koruny). Když nikam, jen se zlomí (pařez, kmen zmizí v třískách).
func _tree_fall(i: int, from: Vector3, by: String) -> void:
	var w: Node3D = nodes[i]
	if not is_instance_valid(w):
		return
	var away := Vector3(base[i].x - from.x, 0, base[i].z - from.z)
	if away.length() < 0.1: away = Vector3(randf() - 0.5, 0, randf() - 0.5)
	away = away.normalized()
	var ex := []
	for sb in w.find_children("*", "StaticBody3D", true, false):
		ex.append((sb as CollisionObject3D).get_rid())
	var space := (w as Node3D).get_world_3d().direct_space_state
	var h := tall[i] * 0.9
	var pick := NO_DIR
	for a in [0.0, 0.6, -0.6, 1.2, -1.2, PI]:
		var d := away.rotated(Vector3.UP, a)
		var ok := true
		for y in [1.2, h * 0.55]:
			var q := PhysicsRayQueryParameters3D.create(base[i] + Vector3(0, y, 0) + d * 0.5, base[i] + Vector3(0, y, 0) + d * h, Game.WORLD | Game.GLASS)
			q.exclude = ex
			if not space.intersect_ray(q).is_empty():
				ok = false
				break
		if ok:
			pick = atan2(d.x, d.z)
			break
	_by[i] = by
	_until.erase(i)
	_state.rpc(i, DOWN, pick)
	if pick > NO_DIR + 1.0:
		get_tree().create_timer(FALL_TIME * 0.92).timeout.connect(_fall_hit.bind(i, pick))

## Hostitel: kdo stál pod padajícím kmenem.
func _fall_hit(i: int, yaw: float) -> void:
	if not is_instance_valid(mission) or yaw <= NO_DIR + 1.0:
		return
	var d := Vector3(sin(yaw), 0, cos(yaw))
	var a := base[i] + d * 1.0
	var b := base[i] + d * tall[i] * 0.95
	var by: Node = mission.actors.get_node_or_null(String(_by.get(i, "-")))
	for pl in mission.players():
		if not pl.dead and _seg_dist(pl.global_position, a, b) < 0.9:
			pl.hurt.rpc_id(pl.get_multiplayer_authority(), FALL_HIT, base[i], false, "blast")
	for al in mission.aliens():
		if not al.dead and _seg_dist(al.global_position, a, b) < 1.0:
			mission.hit_kind = "explosion"
			al.damage(FALL_HIT * 1.6, base[i], by)
			mission.hit_kind = ""
	mission.noise(base[i], 30.0)

static func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var p2 := Vector2(p.x, p.z); var a2 := Vector2(a.x, a.z); var b2 := Vector2(b.x, b.z)
	var ab := b2 - a2
	var t := clampf((p2 - a2).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return (a2 + ab * t).distance_to(p2)

# ---- co vidí všichni ---------------------------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _state(i: int, st: int, a: float) -> void:
	if i < 0 or i >= nodes.size() or state[i] == GONE or state[i] == st:
		return
	var was := state[i]
	state[i] = st
	var w = nodes[i]
	if not is_instance_valid(w):
		return
	match st:
		SMOKE:
			_set_fx(i, _smoke(w as Node3D))
		BURN:
			if kind[i] == "tree":
				_set_fx(i, _crown_fire(w as Node3D, tall[i]))
			else:
				_set_fx(i, _car_fire(w as Node3D))
				Game.play_at(mission, "fire_ignite", base[i] + Vector3.UP, 0)
		DOWN:
			_clear_fx(i)
			_fall(i, w as Node3D, a)
		GONE:
			_clear_fx(i)
			if kind[i] == "tree":
				if was == DOWN:
					return
				_swap(i, w as Node3D, "v_dead_tree", true)
			else:
				_swap(i, w as Node3D, "v_car_burnt", false)

func _set_fx(i: int, n: Node) -> void:
	_clear_fx(i)
	_fx[i] = n

func _clear_fx(i: int) -> void:
	if _fx.has(i):
		var n = _fx[i]
		_fx.erase(i)
		if is_instance_valid(n):
			for c in (n as Node).get_children():
				if c is CPUParticles3D: (c as CPUParticles3D).emitting = false
			get_tree().create_timer(4.0).timeout.connect(func(): if is_instance_valid(n): n.queue_free())

## Strom/auto nahradí jiný model (ohořelý kmen, vrak) na stejném místě.
func _swap(i: int, w: Node3D, model: String, charred: bool) -> void:
	var n := Game.model(model)
	var par := w.get_parent()
	par.add_child(n)
	FitCollision.fit(n)
	n.global_transform = w.global_transform
	if charred:
		var ov := StandardMaterial3D.new()
		ov.albedo_color = Color(0.03, 0.025, 0.02, 0.55)
		ov.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_overlay = ov
	if mission._nav_cache: mission._nav_cache.touch(n)
	nodes[i] = null
	w.queue_free()
	mission._nav_dirty = 2.0

## Pád: celý strom se překlopí kolem paty (zůstane pařez). @a yaw NO_DIR = zlomí se na místě.
func _fall(i: int, w: Node3D, yaw: float) -> void:
	var stump := Game.model("v_stump")
	w.get_parent().add_child(stump)
	FitCollision.fit(stump)
	stump.global_position = base[i]
	stump.rotation.y = w.rotation.y
	stump.scale = Vector3.ONE * clampf(w.scale.x, 0.6, 1.4)
	Game.play_at(mission, "wood_break", base[i] + Vector3.UP, 2)
	_chips(base[i] + Vector3(0, 0.8, 0))
	if yaw <= NO_DIR + 1.0:
		nodes[i] = null
		w.queue_free()
		mission._nav_dirty = 2.0
		return
	var d := Vector3(sin(yaw), 0, cos(yaw))
	var axis := Vector3.UP.cross(d).normalized()
	var b0 := w.transform.basis
	var tw := w.create_tween()
	tw.tween_method(func(k: float):
		if is_instance_valid(w):
			w.transform.basis = Basis(axis, k) * b0
			w.position = base[i] + d * sin(k) * 0.25 + Vector3(0, 0.55 * sin(k), 0),
		0.0, 1.5, FALL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		Game.play_at(mission, "wood_collapse", base[i] + d * tall[i] * 0.5, 4)
		_dust(base[i] + d * tall[i] * 0.5, tall[i])
		if mission._nav_cache: mission._nav_cache.touch(w)
		mission._nav_dirty = 2.0)

# ---- efekty (lacné: žádné světlo, světlo a stín má oheň u paty) ------------------------------

static var _flame_mesh: QuadMesh
static var _smoke_mesh: QuadMesh

static func _flames_mesh() -> QuadMesh:
	if _flame_mesh == null:
		_flame_mesh = QuadMesh.new()
		_flame_mesh.size = Vector2(0.7, 0.9)
		var fm := StandardMaterial3D.new()
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.vertex_color_use_as_albedo = true
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_flame_mesh.material = fm
	return _flame_mesh

static func _smokes_mesh() -> QuadMesh:
	if _smoke_mesh == null:
		_smoke_mesh = QuadMesh.new()
		_smoke_mesh.size = Vector2(1.2, 1.2)
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.3, 0.3, 0.3, 0.45)
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		sm.cull_mode = BaseMaterial3D.CULL_DISABLED
		_smoke_mesh.material = sm
	return _smoke_mesh

func _flames(amount: int, box: Vector3, life := 0.8) -> CPUParticles3D:
	var fl := CPUParticles3D.new()
	fl.amount = amount
	fl.lifetime = life
	fl.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fl.emission_box_extents = box
	fl.direction = Vector3.UP
	fl.spread = 15.0
	fl.gravity = Vector3(0, 2.5, 0) + mission.wind_now() * 0.9
	fl.initial_velocity_min = 0.5
	fl.initial_velocity_max = 1.4
	fl.scale_amount_min = 0.6
	fl.scale_amount_max = 1.5
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.85, 0.3, 1.0))
	grad.set_color(1, Color(0.7, 0.1, 0.02, 0.0))
	grad.add_point(0.4, Color(1.0, 0.45, 0.08, 0.9))
	fl.color_ramp = grad
	fl.mesh = _flames_mesh()
	return fl

## Hořící koruna: plameny po celé výšce koruny (bez vlastního světla - to má oheň u paty).
## (živý test 27. 11.: první zapálení zaseklo kompilací shaderů) Plameny, kouř a třísky na pár snímků
## před kamerou za načítací obrazovkou, ať se shadery přeloží dopředu. Volá Player._warm_shot.
func warm(holder: Node3D) -> void:
	var fl := _flames(4, Vector3(0.1, 0.1, 0.1), 0.3)
	holder.add_child(fl)
	fl.emitting = true
	var sm := CPUParticles3D.new()
	sm.amount = 2
	sm.lifetime = 0.3
	sm.mesh = _smokes_mesh()
	holder.add_child(sm)
	sm.emitting = true
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.05, 0.05)
	bm.material = Game.color_mat(Color(0.42, 0.3, 0.18))
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	holder.add_child(mi)

func _crown_fire(w: Node3D, h: float) -> Node3D:
	var n := Node3D.new()
	mission.add_child(n)
	n.global_position = w.global_position + Vector3(0, h * 0.6, 0)
	var fl := _flames(36, Vector3(1.0, h * 0.25, 1.0) * clampf(w.scale.x, 0.7, 1.3), 1.0)
	n.add_child(fl)
	n.set_meta("wreck_fx", "crown")
	return n

func _car_fire(w: Node3D) -> Node3D:
	var n := _smoke(w)
	var fl := _flames(28, Vector3(0.8, 0.15, 1.4))
	n.add_child(fl)
	fl.position = Vector3(0, 0.5, 0)
	return n

func _smoke(w: Node3D) -> Node3D:
	var n := Node3D.new()
	mission.add_child(n)
	n.global_position = w.global_position + Vector3(0, 0.9, 0)
	var sm := CPUParticles3D.new()
	sm.amount = 18
	sm.lifetime = 3.5
	sm.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sm.emission_sphere_radius = 0.4
	sm.direction = Vector3.UP
	sm.spread = 20.0
	sm.gravity = Vector3(0, 0.8, 0) + mission.wind_now() * 0.5
	sm.initial_velocity_min = 0.4
	sm.initial_velocity_max = 0.9
	sm.scale_amount_min = 0.8
	sm.scale_amount_max = 2.2
	sm.mesh = _smokes_mesh()
	n.add_child(sm)
	return n

func _chips(p: Vector3) -> void:
	var parts := CPUParticles3D.new()
	parts.one_shot = true
	parts.amount = 30
	parts.lifetime = 1.4
	parts.explosiveness = 0.95
	parts.spread = 80.0
	parts.direction = Vector3.UP
	parts.initial_velocity_min = 2.0
	parts.initial_velocity_max = 5.0
	parts.gravity = Vector3(0, -12, 0)
	var bm := BoxMesh.new()
	bm.size = Vector3(0.12, 0.05, 0.08)
	bm.material = Game.color_mat(Color(0.42, 0.3, 0.18))
	parts.mesh = bm
	mission.add_child(parts)
	parts.global_position = p
	parts.emitting = true
	get_tree().create_timer(2.0).timeout.connect(parts.queue_free)

func _dust(p: Vector3, h: float) -> void:
	var parts := CPUParticles3D.new()
	parts.one_shot = true
	parts.amount = 26
	parts.lifetime = 2.0
	parts.explosiveness = 0.8
	parts.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	parts.emission_box_extents = Vector3(1.0, 0.2, h * 0.3)
	parts.direction = Vector3.UP
	parts.initial_velocity_min = 0.6
	parts.initial_velocity_max = 2.0
	parts.color = Color(0.35, 0.3, 0.25)
	var pm := BoxMesh.new()
	pm.size = Vector3(0.14, 0.14, 0.14)
	parts.mesh = pm
	mission.add_child(parts)
	parts.global_position = p
	parts.emitting = true
	get_tree().create_timer(3.0).timeout.connect(parts.queue_free)
