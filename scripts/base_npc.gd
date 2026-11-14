extends Node3D
## 0.66 Facelift I (Ari): the people of the base - scientists in white coats in the laboratory,
## technicians in blue overalls in the workshop and the hangar. Only scenery, no mechanics: each one
## keeps to his room, works at one place for a while (types at the computer, writes on a clipboard,
## fixes something kneeling, looks at a thing, talks) and walks over to another. The soldier's model
## (merc.glb, same bones) in other clothes, the gold X of the project on the back, the UAI patch on
## both shoulders; the movements are Ari's from afk.ai (vedci_technici.glb -> animace/tp_npc_*.json,
## only in the game's .pck). No tablets or phones - it is 1990: a clipboard is the most they carry.
## Every machine has its own (not synced): it is only the look of the base.

const WALK_SPEED := 1.05
const ACTS := {
	# what he does at a post -> the movement (several = one of them, changes now and then)
	"typing": ["tp_npc_typing"],
	"interact": ["tp_npc_interact", "tp_npc_idle2"],
	"confused": ["tp_npc_confused", "tp_npc_idle", "tp_npc_shake"],
	"fix": ["tp_npc_fix"],
	"write": ["tp_npc_idle2", "tp_npc_listen", "tp_npc_nod"],
	"talk": ["tp_npc_talk", "tp_npc_listen", "tp_npc_nod", "tp_npc_yes"],
}
const HAT_AT := Vector3(0, 0.16, 0.0)  # the hard hat's rim from the head bone (rest pose, model space)
const BOARD_ACTS := ["write", "confused", "talk"]      # the clipboard stays in his hand for these (and walking)

var role := "sci"
var posts: Array = []
var _post := -1
var _path: PackedVector3Array = []
var _work_t := 0.0
var _clip := {}
var _clip_id := ""
var _t := 0.0
var _sk: Skeleton3D
var _model: Node3D
var _board: Node3D
var _rng := RandomNumberGenerator.new()
var _busy: Dictionary          # shared by the room: post index -> who stands there
var _walk_id := "tp_npc_walk"
var builder := false           # (0.69) a technician on the building site: a yellow hard hat, no clipboard

func setup(r: String, p: Array, busy: Dictionary, seed_: int, female: bool, build := false) -> void:
	role = r
	builder = build
	posts = p
	_busy = busy
	_rng.seed = seed_
	name = "Npc_%s_%d" % [r, seed_ % 10000]
	_model = Game.model("merc")
	_model.scale = Vector3(-1, 1, 1)
	add_child(_model)
	var ap: Node = _model.find_child("AnimationPlayer", true, false)
	if ap:
		ap.get_parent().remove_child(ap)
		ap.free()
	_sk = _model.find_child("Skeleton3D", true, false)
	_dress(female)
	if female:
		_walk_id = "tp_npc_walk_f"
	# the first post: a free one
	_pick_post(true)
	if _post >= 0:
		position = posts[_post]["pos"]
		rotation.y = float(posts[_post]["yaw"])
		_start_work()

## The clothes: the look of a soldier (face, hair) with a white coat or blue overalls on top.
func _dress(female: bool) -> void:
	var look := {
		"female": female, "skin": _rng.randi() % 5, "hair": (["long", "bun", "pony"] if female else ["short", "buzz", "none"])[_rng.randi() % 3] if not builder else "buzz",
		"hair_color": _rng.randi() % 9, "eye_color": _rng.randi() % 6, "beard": 0 if female or _rng.randf() < 0.55 else 1 + _rng.randi() % 4,
		"top": 0 if role == "sci" else 1, "pants": 2, "vest": 3, "headgear": 2 if role == "sci" or builder or _rng.randf() < 0.5 else 1,
		"glasses": 0, "flag": "",
	}
	Game.apply_look(_model, look)
	var coat := Game.color_mat(Color(0.9, 0.91, 0.9))
	var slacks := Game.color_mat(Color(0.28, 0.29, 0.31))
	var overall := Game.color_mat(Color(0.17, 0.24, 0.38))
	var patch := Game.color_mat(Color(0.85, 0.65, 0.15))
	var look_gear := ["Gear_Beret", "Gear_Boonie", "Gear_Bandana", "Gear_Headset", "Gear_Cap", "Gear_Helmet", "Gear_Torch"]
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		var nm := String(mi.name)
		if nm.begins_with("Gear_") and not nm in look_gear:
			mi.visible = false        # (no pouches, backpack, vest or armour at home)
		for i in mi.mesh.get_surface_count():
			var src: Material = mi.mesh.surface_get_material(i)
			if src == null:
				continue
			match String(src.resource_name):
				"Uniform", "Sleeve", "Tee":
					if role == "sci":
						mi.set_surface_override_material(i, coat if nm.begins_with("Look_Top") else slacks)
					else:
						mi.set_surface_override_material(i, overall)
				"Patch":
					mi.set_surface_override_material(i, patch)
	if _sk == null:
		return
	# the gold X of the project on the back (as on the backpacks)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.85, 0.66, 0.2)
	gold.metallic = 0.6
	gold.roughness = 0.35
	var x := _on_bone("spine", Vector3(0, 1.27, 0.13))
	for r in [0.7, -0.7]:
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.04, 0.2, 0.008)
		bar.mesh = bm
		bar.material_override = gold
		bar.rotation.z = r
		x.add_child(bar)
	# the builders' hard hat: a yellow shell with a ridge and a brim, on the head bone
	if builder:
		var hb := _sk.find_bone("head")
		var top := (_sk.get_bone_global_rest(hb).origin if hb >= 0 else Vector3(0, 1.6, 0))
		var hat := _on_bone("head", top + HAT_AT)
		var yel := Game.color_mat(Color(0.95, 0.75, 0.08))
		var shell := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.2; sm.height = 0.2; sm.is_hemisphere = true
		sm.radial_segments = 20; sm.rings = 6
		shell.mesh = sm
		shell.material_override = yel
		shell.scale = Vector3(0.95, 0.8, 1.05)      # (over the square head and its hair)
		hat.add_child(shell)
		var brim := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.215; cm.bottom_radius = 0.22; cm.height = 0.014; cm.radial_segments = 20
		brim.mesh = cm
		brim.material_override = yel
		brim.scale = Vector3(0.95, 1.0, 1.12)
		brim.position = Vector3(0, 0.006, -0.02)
		hat.add_child(brim)
		return
	# a clipboard for the scientists (brown board, white sheet, the clip)
	if role == "sci" or _rng.randf() < 0.4:
		var hb := _sk.find_bone("hand.L")
		_board = _on_bone("hand.L", (_sk.get_bone_global_rest(hb).origin if hb >= 0 else Vector3(0.3, 0.9, 0)) + Vector3(0, -0.06, 0))
		var hold := Node3D.new()
		_board.add_child(hold)
		hold.position = Vector3(0.0, -0.1, 0.0)
		hold.rotation = Vector3(0.0, PI / 2, 0.0)
		for part in [[Vector3(0.23, 0.32, 0.012), Color(0.42, 0.27, 0.12), Vector3.ZERO],
				[Vector3(0.2, 0.27, 0.004), Color(0.93, 0.93, 0.9), Vector3(0, -0.015, 0.008)],
				[Vector3(0.08, 0.03, 0.02), Color(0.6, 0.6, 0.62), Vector3(0, 0.15, 0.01)]]:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = part[0]
			mi.mesh = bm
			mi.material_override = Game.color_mat(part[1])
			mi.position = part[2]
			hold.add_child(mi)

## A node that moves with a bone, placed at a point of the model in its rest pose.
func _on_bone(bone: String, at: Vector3) -> Node3D:
	var bi := _sk.find_bone(bone)
	var n := Node3D.new()
	if bi < 0:
		_model.add_child(n)
		n.position = at
		return n
	var att := BoneAttachment3D.new()
	att.bone_name = bone
	_sk.add_child(att)
	att.add_child(n)
	n.transform = _sk.get_bone_global_rest(bi).affine_inverse() * Transform3D(Basis(), at)
	return n

func _pick_post(first := false) -> void:
	var free := []
	for i in posts.size():
		if i != _post and not _busy.has(i):
			free.append(i)
	if free.is_empty():
		return
	if _post >= 0:
		_busy.erase(_post)
	_post = free[_rng.randi() % free.size()]
	_busy[_post] = self
	if not first:
		var to: Vector3 = posts[_post]["pos"]
		_path = PackedVector3Array()
		var nm := get_world_3d().navigation_map if is_inside_tree() else RID()
		if nm.is_valid() and NavigationServer3D.map_get_iteration_id(nm) > 0:
			_path = NavigationServer3D.map_get_path(nm, global_position, to, true)
		if _path.is_empty():
			_path = PackedVector3Array([to])
		_play(_walk_id if _board == null or _rng.randf() < 0.5 else "tp_npc_walk_formal")

func _start_work() -> void:
	var act := String(posts[_post]["act"])
	var list: Array = ACTS.get(act, ["tp_npc_idle"])
	_play(list[_rng.randi() % list.size()])
	_work_t = _rng.randf_range(9.0, 24.0) if act != "typing" else _rng.randf_range(18.0, 40.0)
	if _board:
		_board.visible = act in BOARD_ACTS

func _play(id: String) -> void:
	if id == _clip_id:
		return
	var c := AnimClips.get_clip(id)
	if c.is_empty():
		c = AnimClips.get_clip("tp_body_idle" if not id.contains("walk") else "tp_body_walk")
	_clip = c
	_clip_id = id
	_t = _rng.randf() * float(c.get("delka", 1.0))

func _process(delta: float) -> void:
	if _post < 0:
		return
	if not _path.is_empty():
		# walking over to the next place
		var to := _path[0]
		var d := to - global_position
		d.y = 0
		if d.length() < 0.08:
			_path.remove_at(0)
			if _path.is_empty():
				global_position.x = to.x
				global_position.z = to.z
				_start_work()
		else:
			var step := minf(d.length(), WALK_SPEED * delta)
			global_position += d.normalized() * step
			rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), delta * 6.0)
	else:
		rotation.y = lerp_angle(rotation.y, float(posts[_post]["yaw"]), delta * 4.0)
		_work_t -= delta
		if _work_t <= 0.0:
			if posts.size() > 1 and _rng.randf() < 0.75:
				_pick_post()
				if _path.is_empty():
					_start_work()
			else:
				_start_work()
		elif _rng.randf() < delta / 8.0 and String(posts[_post]["act"]) != "typing" and String(posts[_post]["act"]) != "fix":
			var list: Array = ACTS.get(String(posts[_post]["act"]), [])
			if list.size() > 1:
				_play(list[_rng.randi() % list.size()])
	_pose(delta)

func _pose(delta: float) -> void:
	if _sk == null or _clip.is_empty():
		return
	_t += delta
	var t := AnimClips.clip_time(_clip, _t)
	var p := AnimClips.pose(_clip, t)
	for bn in p:
		var i := _sk.find_bone(bn)
		if i >= 0:
			_sk.set_bone_pose_rotation(i, _sk.get_bone_rest(i).basis.get_rotation_quaternion() * Quaternion.from_euler(p[bn]))
	if AnimClips.has_track(_clip, "root@pos"):
		var ri := _sk.find_bone("root")
		if ri >= 0:
			var v := AnimClips.sample(_clip, "root@pos", t)
			_sk.set_bone_pose_position(ri, _sk.get_bone_rest(ri).origin + Vector3(float(v[0]), float(v[1]), float(v[2])))
