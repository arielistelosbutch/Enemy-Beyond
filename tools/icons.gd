extends SceneTree
## Renders the inventory / globe icons from the game's own models:
##   godot --path . -s tools/icons.gd        (needs a display: xvfb-run on Linux)
## Writes res://assets/icons/<id>.png with a transparent background.

const ITEM_SIZE := Vector2i(96, 48)
const CRAFT_SIZE := Vector2i(64, 64)

## Items without a model of their own: built from the pieces we have.
func _stand_in(id: String) -> Node3D:
	var n := Node3D.new()
	var mag: PackedScene = load("res://assets/models/pistol_mag.glb")
	var rnd: PackedScene = load("res://assets/models/round.glb")
	match id:
		"pistol_clip", "rifle_clip", "sniper_clip", "ac_clip":
			var m: Node3D = mag.instantiate()
			m.scale = Vector3.ONE * {"pistol_clip": 1.0, "rifle_clip": 1.4, "sniper_clip": 1.25, "ac_clip": 2.0}[id]
			if id == "rifle_clip":
				m.rotation.x = 0.25       # a curved magazine, more or less
			n.add_child(m)
		"shells", "magnum_rounds", "minigun_belt":
			var k: int = {"shells": 4, "magnum_rounds": 6, "minigun_belt": 9}[id]
			for i in k:
				var r: Node3D = rnd.instantiate()
				r.scale = Vector3.ONE * (1.6 if id == "shells" else 1.0)
				r.rotation.x = PI / 2        # standing upright, side by side
				r.position = Vector3(0, 0, (i - k / 2.0) * (0.03 if id == "shells" else 0.016))
				n.add_child(r)
		"plasma_cell":
			n.add_child(_prim(CylinderMesh.new(), Vector3(0.05, 0.12, 0.05), Color(0.2, 0.22, 0.24)))
			var core := _prim(CylinderMesh.new(), Vector3(0.035, 0.09, 0.035), Color(0.3, 1.0, 0.5), true)
			core.position.x = 0.012
			n.add_child(core)
			n.rotation.x = PI / 2
		"vesta", "pancir":
			var col := Color(0.20, 0.24, 0.18) if id == "vesta" else Color(0.45, 0.48, 0.55)
			var body := _prim(BoxMesh.new(), Vector3(0.08, 0.45, 0.38), col)
			n.add_child(body)
			for s in [-1, 1]:
				var strap := _prim(BoxMesh.new(), Vector3(0.09, 0.12, 0.08), col.darkened(0.2))
				strap.position = Vector3(0, 0.27, s * 0.13)
				n.add_child(strap)
			var plate := _prim(BoxMesh.new(), Vector3(0.09, 0.2, 0.22), col.lightened(0.15) if id == "pancir" else col.darkened(0.15))
			plate.position = Vector3(0.005, 0.02, 0)
			n.add_child(plate)
		"a_pack":
			var p := _prim(SphereMesh.new(), Vector3(0.25, 0.3, 0.3), Color(0.35, 0.3, 0.45))
			n.add_child(p)
			var g := _prim(SphereMesh.new(), Vector3(0.06, 0.06, 0.06), Color(0.5, 1.0, 0.6), true)
			g.position = Vector3(0.11, 0.05, 0)
			n.add_child(g)
	return n

func _prim(mesh: PrimitiveMesh, size: Vector3, col: Color, glow := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if mesh is BoxMesh:
		mesh.size = size
	elif mesh is CylinderMesh:
		mesh.top_radius = size.x / 2
		mesh.bottom_radius = size.x / 2
		mesh.height = size.y
	elif mesh is SphereMesh:
		mesh.radius = size.x / 2
		mesh.height = size.y
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	if glow:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 1.5
	mi.material_override = m
	return mi

func _aabb(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for c in n.find_children("*", "GeometryInstance3D", true, false):
		var vi: GeometryInstance3D = c
		var b := vi.global_transform * vi.get_aabb()
		if first:
			box = b
			first = false
		else:
			box = box.merge(b)
	return box

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/icons"))
	var sv := SubViewport.new()
	sv.transparent_bg = true
	sv.own_world_3d = true
	sv.msaa_3d = Viewport.MSAA_4X
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(sv)
	var root3 := Node3D.new()
	sv.add_child(root3)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	root3.add_child(cam)
	for d in [[Vector3(-35, 30, 0), 1.6], [Vector3(-10, 200, 0), 0.6]]:
		var l := DirectionalLight3D.new()
		l.rotation_degrees = d[0]
		l.light_energy = d[1]
		root3.add_child(l)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.58, 0.62)
	e.ambient_light_energy = 0.9
	env.environment = e
	root3.add_child(env)
	RenderingServer.set_default_clear_color(Color(0, 0, 0, 0))
	var items := ["rifle", "pistol", "shotgun", "magnum", "autocannon", "minigun", "rocket_launcher", "plasma_rifle",
		"sniper", "laser_pistol", "laser_rifle", "laser_cannon", "stun_baton", "knife", "rifle_clip", "sniper_clip",
		"pistol_clip", "shells", "magnum_rounds", "ac_clip", "minigun_belt", "plasma_cell", "rocket", "grenade",
		"smoke_grenade", "mine", "flare", "medkit", "a_pistol", "a_rifle", "a_heavy", "a_pack", "stit", "vesta",
		"pancir", "scanner", "radio"]
	var crafts := ["ufo_scout", "ufo_raider", "ufo_harvester", "sokol", "heli", "dropship"]
	var all := []
	var views := {"stit": Vector3(0.25, 0.3, 1.0), "radio": Vector3(1, 0.5, 0.6), "medkit": Vector3(1, 0.6, 0.5)}
	for id in items:
		all.append([id, ITEM_SIZE, views.get(id, Vector3(1, 0.35, 0.18))])
	for id in crafts:
		all.append([id, CRAFT_SIZE, Vector3(0.9, 1.1, 1.3) if id.begins_with("ufo") else Vector3(1.1, 1.2, 0.9)])
	for e2 in all:
		var id: String = e2[0]
		sv.size = e2[1] * 2      # rendered at double size, scaled down for smooth edges
		var path := "res://assets/models/%s.glb" % id
		var m: Node3D = load(path).instantiate() if ResourceLoader.exists(path) else _stand_in(id)
		root3.add_child(m)
		await process_frame
		var box := _aabb(m)
		var c := box.get_center()
		var dir: Vector3 = (e2[2] as Vector3).normalized()
		cam.position = c + dir * (box.size.length() + 2.0)
		cam.look_at(c, Vector3.UP)
		# fit: project the 8 corners, size the ortho view to the widest side
		var xf := cam.global_transform.affine_inverse()
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for i in 8:
			var p := xf * box.get_endpoint(i)
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
		var aspect := float(e2[1].x) / float(e2[1].y)
		var span := hi - lo
		cam.size = maxf(span.y, span.x / aspect) * 1.12
		var mid := (lo + hi) / 2.0
		cam.position += cam.global_transform.basis.x * mid.x + cam.global_transform.basis.y * mid.y
		for f in 4:
			await process_frame
		var img := sv.get_texture().get_image()
		img.resize(e2[1].x, e2[1].y, Image.INTERPOLATE_LANCZOS)
		img.save_png("res://assets/icons/%s.png" % id)
		print("icon ", id)
		m.queue_free()
		await process_frame
	quit()
