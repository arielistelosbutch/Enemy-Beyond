extends Node
## 0.70 Facelift II: dirt and blood on the uniform. A child of the player; every machine runs it for
## every soldier from what it sees anyway (the synced stance, downed and hp), nothing goes over the net.
## Lying, crawling and being down dirty the clothes (the knees and boots first) with the mud of the
## ground (its colour from the mission's terrain); a hit leaves a blood stain that dries brown.
## Only a look: the stains are a material_overlay (shaders/uniform_dirt.gdshader) on the skinned pieces,
## whose meshes get the rest-pose place of each vertex in COLOR once (cached per mesh).

const SHADER := preload("res://shaders/uniform_dirt.gdshader")
const MAX_BLOOD := 8
const MUD := {"woodland": Color(0.27, 0.2, 0.12), "urban": Color(0.33, 0.31, 0.28), "desert": Color(0.62, 0.5, 0.34),
	"snow": Color(0.42, 0.4, 0.38), "mars": Color(0.5, 0.24, 0.13), "night": Color(0.2, 0.16, 0.12)}

static var _baked := {}          # mesh -> the same mesh with COLOR = rest place
static var _spots := {}          # mesh -> rest places on the torso and arms (where a hit can land)

var dirt := 0.0
var low := 0.0
var blood: Array = []            # [Vector3 rest place, radius, age 0..1]
var mud := Color(0.27, 0.2, 0.12)
var off := false                 # (home base: nothing sticks)
var _mat: ShaderMaterial
var _p: Node3D
var _last_hp := -1.0
var _last_pos := Vector3.ZERO
var _pieces: Array = []

func _ready() -> void:
	name = "UniformDirt"
	_p = get_parent()
	var params: Dictionary = Net.mission_params
	var camo := Game.camo_for(params)
	off = camo == "" or String(params.get("type", "")) == "home"
	mud = MUD.get(camo, MUD["woodland"])
	if params.get("rain", false) or params.get("weather", "") == "rain":
		mud = mud.darkened(0.25)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("mud", mud)
	_mat.set_shader_parameter("seed", float(String(_p.get("display_name")).hash() % 997) / 997.0)
	_mat.render_priority = 1
	var model: Node3D = _p.get("merc_model")
	if model:
		dress(model, _mat)
	_last_hp = float(_p.get("hp"))
	_last_pos = _p.global_position
	_push()

## Puts the overlay on every skinned piece of a soldier model (the player's or a copy of him).
static func dress(model: Node, mat: Material) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		if not (mi.get_parent() is Skeleton3D) or mi.mesh == null:
			continue
		mi.mesh = baked(mi.mesh)
		mi.material_overlay = mat

## The mesh with the rest-pose place of each vertex in COLOR (x, y, z mapped to 0..1 over a 2 m box).
static func baked(mesh: Mesh) -> Mesh:
	if mesh.has_meta("dirt_baked"):
		return mesh
	if _baked.has(mesh):
		return _baked[mesh]
	var am := ArrayMesh.new()
	var spots := PackedVector3Array()
	for i in mesh.get_surface_count():
		var arr: Array = mesh.surface_get_arrays(i)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var cols := PackedColorArray()
		cols.resize(vs.size())
		for k in vs.size():
			var v: Vector3 = vs[k]
			cols[k] = Color(clampf(v.x * 0.5 + 0.5, 0, 1), clampf(v.y * 0.5, 0, 1), clampf(v.z * 0.5 + 0.5, 0, 1))
			if k % 7 == 0 and v.y > 0.75 and v.y < 1.55:
				spots.append(v)
		arr[Mesh.ARRAY_COLOR] = cols
		var flags: int = mesh.surface_get_format(i) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		am.add_surface_from_arrays(mesh.surface_get_primitive_type(i), arr, [], {}, flags)
		am.surface_set_material(i, mesh.surface_get_material(i))
		if mesh is ArrayMesh:
			am.surface_set_name(i, (mesh as ArrayMesh).surface_get_name(i))
	am.resource_name = mesh.resource_name
	am.set_meta("dirt_baked", true)
	_baked[mesh] = am
	_spots[am] = spots
	return am

func _process(delta: float) -> void:
	if off or _p == null:
		return
	var moved: float = (_p as Node3D).global_position.distance_to(_last_pos)
	_last_pos = _p.global_position
	var sp: float = moved / maxf(delta, 0.001)
	if sp > 20.0:
		sp = 0.0          # (a teleport, a respawn)
	var on_ground: bool = _p.get("downed") or _p.get("dead")
	if _p.get("prone") or on_ground:
		# lying: the front and the knees in the mud; crawling rubs it in fast
		dirt += delta * (0.012 + 0.03 * minf(sp, 1.5))
		low += delta * (0.02 + 0.03 * minf(sp, 1.5))
	elif _p.get("crouching"):
		low += delta * (0.004 + 0.012 * minf(sp, 2.0))
	elif sp > 0.5:
		low += delta * 0.0018 * minf(sp, 6.0)
	dirt = minf(dirt, 1.0)
	low = minf(low, 1.0)
	var hp := float(_p.get("hp"))
	if _last_hp >= 0.0 and hp < _last_hp - 1.5:
		bleed(_last_hp - hp)
	_last_hp = hp
	for b in blood:
		b[2] = minf(1.0, b[2] + delta / 90.0)
	_push()

## A hit: a stain somewhere on the torso or the arms, bigger with the wound.
func bleed(dmg: float) -> void:
	var spots := PackedVector3Array()
	for mi in _pieces_list():
		spots.append_array(_spots.get(mi.mesh, PackedVector3Array()))
	if spots.is_empty():
		return
	var at: Vector3 = spots[randi() % spots.size()]
	var r := clampf(0.06 + dmg * 0.007, 0.07, 0.18)
	if blood.size() >= MAX_BLOOD:
		blood.remove_at(0)
	blood.append([at, r, 0.0])

func _pieces_list() -> Array:
	if _pieces.is_empty():
		var model: Node3D = _p.get("merc_model")
		if model:
			for mi in model.find_children("*", "MeshInstance3D", true, false):
				if mi.material_overlay == _mat and mi.visible:
					_pieces.append(mi)
	return _pieces

var _push_t := 0.0
func _push() -> void:
	var bl: Array = []
	var ages: Array = []
	for i in MAX_BLOOD:
		if i < blood.size():
			var b: Array = blood[i]
			var v: Vector3 = b[0]
			bl.append(Vector4(v.x, v.y, v.z, b[1]))
			ages.append(b[2])
		else:
			bl.append(Vector4.ZERO)
			ages.append(0.0)
	_mat.set_shader_parameter("dirt", dirt)
	_mat.set_shader_parameter("low", low)
	_mat.set_shader_parameter("blood", bl)
	_mat.set_shader_parameter("blood_age", ages)

## The state, for a copy of the soldier (the transport after the mission).
func state() -> Dictionary:
	return {"dirt": dirt, "low": low, "blood": blood.duplicate(true), "mud": mud}

## Dirties a copy of a soldier the same way (it keeps its own material).
static func copy_onto(model: Node, st: Dictionary) -> void:
	if st.is_empty():
		return
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.render_priority = 1
	mat.set_shader_parameter("mud", st["mud"])
	mat.set_shader_parameter("dirt", st["dirt"])
	mat.set_shader_parameter("low", st["low"])
	var bl: Array = []
	var ages: Array = []
	for i in MAX_BLOOD:
		var b: Array = st["blood"][i] if i < st["blood"].size() else [Vector3.ZERO, 0.0, 0.0]
		bl.append(Vector4(b[0].x, b[0].y, b[0].z, b[1]))
		ages.append(b[2])
	mat.set_shader_parameter("blood", bl)
	mat.set_shader_parameter("blood_age", ages)
	dress(model, mat)
