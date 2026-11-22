extends RefCounted
## 0.62 výkon (propady FPS): cesty vetřelců po rozbití zdi se přepočítají bez zaškubnutí hry.
## Dřív `bake_navigation_mesh(true)` sice pekl ve vlákně, ale celou mapu (tisíce kolizních tvarů)
## nejdřív prošel na hlavním vlákně - u hostitele zásek ~180 ms při každém rozbití,
## v co-opu ho cítili všichni (stojí celá simulace).
## 0.72.5 (Ari 22. 11., propady na teroru při střelbě z kulometu): dřív se paměť vedla po čtvercích
## 16 m a po rozbití se celý čtverec procházel znovu na hlavním vlákně (ve městě 13–22 ms za čtverec,
## dva čtverce + kontrola všech kusů = zásek 40–50 ms každé ~2 s, dokud se rozbíjelo). Teď si paměť
## vede geometrii každého pevného kusu zvlášť: kus, který zmizí, se jen vyškrtne (signál
## tree_exiting), znovu se prochází jen kus nový nebo pohnutý (spadlá střecha: `touch`).
## Spojení všech kusů i pečení běží ve vlákně.
const GROUP := "_nav_parse"

var nav: NavigationRegion3D
var _geo := {}          # instance_id -> NavigationMeshSourceGeometryData3D (geometrie jednoho kusu)
var _node := {}         # instance_id -> Node (sledované kusy)
var _new := {}          # instance_id -> Node: projít při příštím přepečení (nový nebo pohnutý)
var _busy := false
var _again := false
var _parse_nm: NavigationMesh
var _task := -1

func _init(region: NavigationRegion3D) -> void:
	nav = region

static func _is_unit(n: Node) -> bool:
	return n is StaticBody3D or n is NavigationObstacle3D

func _track(n: Node) -> void:
	var id := n.get_instance_id()
	if _node.has(id):
		return
	_node[id] = n
	_new[id] = n
	n.tree_exiting.connect(_on_gone.bind(id), CONNECT_ONE_SHOT)

func _on_gone(id: int) -> void:
	_geo.erase(id)
	_node.erase(id)
	_new.erase(id)

## Při načtení mise (za briefingem): projde celou mapu jednou, pak už jen hlídá, co přibude a ubude.
func prime() -> void:
	for n in nav.find_children("*", "StaticBody3D", true, false) + nav.find_children("*", "NavigationObstacle3D", true, false):
		_track(n)
	_parse_new()
	nav.get_tree().node_added.connect(_on_added)

func _on_added(n: Node) -> void:
	if _is_unit(n) and is_instance_valid(nav) and nav.is_ancestor_of(n):
		_track(n)

## Něco se pohnulo (padající střecha): jeho kusy se při příštím přepečení projdou znovu.
func touch(root: Node) -> void:
	if not is_instance_valid(root):
		return
	var all: Array = [root] if _is_unit(root) else []
	all += root.find_children("*", "StaticBody3D", true, false) + root.find_children("*", "NavigationObstacle3D", true, false)
	for n in all:
		var id: int = (n as Node).get_instance_id()
		if _node.has(id):
			_new[id] = n

## Projde nové kusy, každý zvlášť (skupina + GROUPS_EXPLICIT: souřadnice zůstanou vůči oblasti cest);
## jeden kus je zlomek milisekundy.
func _parse_new() -> void:
	if _parse_nm == null:
		_parse_nm = nav.navigation_mesh.duplicate()
		_parse_nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_EXPLICIT
		_parse_nm.geometry_source_group_name = GROUP
	for id in _new:
		var n: Node = _new[id]
		if not is_instance_valid(n) or not n.is_inside_tree():
			continue
		n.add_to_group(GROUP)
		var d := NavigationMeshSourceGeometryData3D.new()
		NavigationServer3D.parse_source_geometry_data(_parse_nm, d, nav)
		n.remove_from_group(GROUP)
		_geo[id] = d
	_new.clear()

func busy() -> bool:
	return _busy

## Konec mise uprostřed pečení: počkat na vlákno.
func finish() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1

## Přepočítá cesty: projde jen nové/pohnuté kusy; spojení a pečení ve vlákně, pak vymění síť cest.
func rebake() -> void:
	var _pt := PerfLog.t0()
	_pl_rebake()
	PerfLog.took("přepečení cest (hlavní vlákno)", _pt)

func _pl_rebake() -> void:
	if not is_instance_valid(nav) or nav.navigation_mesh == null:
		return
	if _busy:
		_again = true
		return
	_parse_new()
	var parts: Array = _geo.values()
	var nm: NavigationMesh = nav.navigation_mesh.duplicate()
	_busy = true
	_task = WorkerThreadPool.add_task(func():
		var all := NavigationMeshSourceGeometryData3D.new()
		for d in parts:
			all.merge(d)
		NavigationServer3D.bake_from_source_geometry_data(nm, all)
		_done.call_deferred(nm))

func _done(nm: NavigationMesh) -> void:
	var _pt := PerfLog.t0()
	_pl_done(nm)
	PerfLog.took("nové cesty převzaty", _pt)

func _pl_done(nm: NavigationMesh) -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)     # (hotový úkol se musí převzít, jinak hra spadne při ukončení)
		_task = -1
	_busy = false
	if is_instance_valid(nav):
		nav.navigation_mesh = nm
	if _again:
		_again = false
		rebake()
