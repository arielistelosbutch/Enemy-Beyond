extends RefCounted
## 0.62 výkon (propady FPS): cesty vetřelců po rozbití zdi se přepočítají bez zaškubnutí hry.
## Dřív `bake_navigation_mesh(true)` sice pekl ve vlákně, ale celou mapu (tisíce kolizních tvarů)
## nejdřív prošel na hlavním vlákně - u hostitele zásek ~180 ms při každém rozbití,
## v co-opu ho cítili všichni (stojí celá simulace). Teď se mapa rozdělí na čtverce CELL × CELL m,
## každý čtverec se projde jednou (při načtení mise) a výsledek se pamatuje; po rozbití se znovu
## projde jen čtverec, kterému něco ubylo nebo přibylo. Spojení čtverců i pečení běží ve vlákně.
const CELL := 16.0
const GROUP := "_nav_parse"

var nav: NavigationRegion3D
var _units := {}        # Vector2i -> {instance_id: Node}  (pevná tělesa a překážky ve čtverci)
var _cells := {}        # Vector2i -> NavigationMeshSourceGeometryData3D (geometrie čtverce)
var _dirty := {}        # Vector2i -> true
var _busy := false
var _again := false
var _parse_nm: NavigationMesh
var _task := -1

func _init(region: NavigationRegion3D) -> void:
	nav = region

func _cell_of(n: Node3D) -> Vector2i:
	var p: Vector3 = nav.global_transform.affine_inverse() * n.global_position
	return Vector2i(floori(p.x / CELL), floori(p.z / CELL))

static func _is_unit(n: Node) -> bool:
	return n is StaticBody3D or n is NavigationObstacle3D

func _add(n: Node) -> void:
	var c := _cell_of(n as Node3D)
	if not _units.has(c):
		_units[c] = {}
	_units[c][n.get_instance_id()] = n
	_dirty[c] = true

## Při načtení mise (za briefingem): projde celou mapu jednou, pak už jen hlídá, co přibude.
func prime() -> void:
	for n in nav.find_children("*", "StaticBody3D", true, false) + nav.find_children("*", "NavigationObstacle3D", true, false):
		_add(n)
	for c in _dirty:
		_cells[c] = _parse(_units[c])
	_dirty.clear()
	nav.get_tree().node_added.connect(_on_added)

func _on_added(n: Node) -> void:
	if _is_unit(n) and is_instance_valid(nav) and nav.is_ancestor_of(n):
		_add(n)

## Projde jen kusy jednoho čtverce (skupina + GROUPS_EXPLICIT: souřadnice zůstanou vůči oblasti cest).
func _parse(units: Dictionary) -> NavigationMeshSourceGeometryData3D:
	if _parse_nm == null:
		_parse_nm = nav.navigation_mesh.duplicate()
		_parse_nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_EXPLICIT
		_parse_nm.geometry_source_group_name = GROUP
	for n in units.values():
		(n as Node).add_to_group(GROUP)
	var d := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(_parse_nm, d, nav)
	for n in units.values():
		(n as Node).remove_from_group(GROUP)
	return d

func busy() -> bool:
	return _busy

## Konec mise uprostřed pečení: počkat na vlákno.
func finish() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1

## Přepočítá cesty: znovu projde jen změněné čtverce; spojení a pečení ve vlákně, pak vymění síť cest.
func rebake() -> void:
	if not is_instance_valid(nav) or nav.navigation_mesh == null:
		return
	if _busy:
		_again = true
		return
	for c in _units:
		var u: Dictionary = _units[c]
		for id in u.keys():
			if not is_instance_id_valid(id) or not (u[id] as Node).is_inside_tree():
				u.erase(id)
				_dirty[c] = true
	for c in _dirty:
		_cells[c] = _parse(_units.get(c, {}))
	_dirty.clear()
	var parts: Array = _cells.values()
	var nm: NavigationMesh = nav.navigation_mesh.duplicate()
	_busy = true
	_task = WorkerThreadPool.add_task(func():
		var all := NavigationMeshSourceGeometryData3D.new()
		for d in parts:
			all.merge(d)
		NavigationServer3D.bake_from_source_geometry_data(nm, all)
		_done.call_deferred(nm))

func _done(nm: NavigationMesh) -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)     # (hotový úkol se musí převzít, jinak hra spadne při ukončení)
		_task = -1
	_busy = false
	if is_instance_valid(nav):
		nav.navigation_mesh = nm
	if _again:
		_again = false
		rebake()
