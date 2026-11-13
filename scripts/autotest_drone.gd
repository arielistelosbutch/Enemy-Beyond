extends RefCounted
## 0.70 facelift: Strážce's new model (tools/blender/drone.py -> assets/models/guard_drone.glb).
## --autotest=dronetest --shots=1 [--day=1]: the drone over the soldier's shoulder from close by, from three
## sides, then in flight (it leans) and the view over the shoulder; checks the four propellers turn.
## RESULT droneshot model true props 4 spin true eye true. Pictures user://droneshot_N.png (xvfb).

static func run(at: Node, p: Node) -> void:
	if p == null or at.step > 0:
		return
	at._skip_brief()
	var m: Node = at.m()
	if not m.go or m.hud._brief_t >= 0:
		return
	at.step = 1
	m.hud.inventory_open = false
	for a in m.aliens():
		a.global_position += Vector3(0, -80, 0)
		a.set_physics_process(false)
	if m.nvg_on:
		m.set_nvg(false)
	await at.get_tree().create_timer(1.5).timeout
	var d: Node3D = m.guard_drone
	if d == null:
		at.out("RESULT droneshot no drone")
		at.get_tree().quit()
		return
	var props: Array = d._rotors
	var b0: Array = []
	for r in props:
		b0.append((r as Node3D).transform.basis)
	await at.get_tree().create_timer(0.3).timeout
	var spin: bool = props.size() > 0
	for i in props.size():
		if (props[i] as Node3D).transform.basis.is_equal_approx(b0[i]):
			spin = false
	var model: bool = d._body.get_child_count() == 1
	at.out("RESULT droneshot model %s props %d spin %s eye %s" % [model, props.size(), spin, d._eye != null])
	var cam := Camera3D.new()
	cam.fov = 50.0
	m.add_child(cam)
	cam.make_current()
	var views := [Vector3(0.75, 0.35, -0.55), Vector3(-0.7, 0.45, 0.6), Vector3(0.1, -0.35, -0.8)]
	for i in views.size():
		for f in 6:
			cam.global_position = d.global_position + Basis(Vector3.UP, d.rotation.y) * views[i]
			cam.look_at(d.global_position)
			await at.get_tree().process_frame
		FLshot(at, "droneshot_%d" % i)
	# in flight: the soldier runs off, the drone follows and leans
	p.global_position += Basis(Vector3.UP, p.rotation.y) * Vector3(0, 0, -3.0)
	for f in 8:
		await at.get_tree().process_frame
	cam.global_position = d.global_position + Basis(Vector3.UP, d.rotation.y) * Vector3(1.2, 0.2, 0.0)
	cam.look_at(d.global_position)
	await at.get_tree().process_frame
	at.out("droneshot tilt %.2f %.2f" % [d._body.rotation.x, d._body.rotation.z])
	FLshot(at, "droneshot_3")
	await at.get_tree().create_timer(1.5).timeout
	# over the shoulder, as the player sees it when he turns his head
	cam.global_position = p.global_position + Basis(Vector3.UP, p.rotation.y) * Vector3(-0.2, 1.75, 0.6)
	cam.look_at(d.global_position)
	await at.get_tree().process_frame
	await at.get_tree().process_frame
	FLshot(at, "droneshot_4")
	cam.queue_free()
	at.get_tree().quit()

static func FLshot(at: Node, name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	at.get_viewport().get_texture().get_image().save_png("user://%s.png" % name)
