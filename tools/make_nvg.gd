extends SceneTree
## Builds assets/models/nvg.glb: a PVS-7 style night vision goggle (one tube body, one big
## objective lens in front, two eyepieces behind, a head strap mount on top).
## Run: godot --headless --path . -s tools/make_nvg.gd

func _box(root: Node3D, size: Vector3, pos: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.8
	m.material = mat
	mi.mesh = m
	mi.position = pos
	root.add_child(mi)
	mi.owner = root

func _cyl(root: Node3D, r: float, h: float, pos: Vector3, col: Color, rough := 0.8) -> void:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 10
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = rough
	if rough < 0.3:
		mat.metallic = 0.3
	m.material = mat
	mi.mesh = m
	mi.rotation.x = PI / 2
	mi.position = pos
	root.add_child(mi)
	mi.owner = root

func _init() -> void:
	var root := Node3D.new()
	root.name = "nvg"
	var dark := Color(0.12, 0.13, 0.12)
	var olive := Color(0.22, 0.24, 0.18)
	_box(root, Vector3(0.11, 0.05, 0.07), Vector3(0, 0, 0), olive)          # the body
	_cyl(root, 0.026, 0.07, Vector3(0, 0, -0.065), dark)                    # objective barrel
	_cyl(root, 0.022, 0.006, Vector3(0, 0, -0.1), Color(0.15, 0.35, 0.3), 0.1)   # the lens
	_cyl(root, 0.016, 0.03, Vector3(-0.032, 0, 0.05), dark)                 # eyepieces
	_cyl(root, 0.016, 0.03, Vector3(0.032, 0, 0.05), dark)
	_box(root, Vector3(0.04, 0.02, 0.04), Vector3(0, 0.035, 0.0), dark)     # mount
	_box(root, Vector3(0.014, 0.014, 0.02), Vector3(0.045, 0.03, -0.01), dark)   # battery cap
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	doc.append_from_scene(root, st)
	var err := doc.write_to_filesystem(st, "res://assets/models/nvg.glb")
	print("nvg.glb written: ", err)
	quit()
