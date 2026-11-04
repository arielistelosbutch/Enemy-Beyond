extends Node3D
## A slow green plasma bolt. Every machine flies its own copy; only the host
## decides whether it hurt somebody.

const SPEED := 34.0

## How fast a bolt of this power/kind flies (the shooters lead their aim with it).
static func speed_for(power: float, kind: String) -> float:
	if kind == "rocket":
		return 24.0
	if kind != "plasma":
		return 15.0
	return SPEED * 1.5 if power < 1.8 else SPEED

var dir := Vector3.FORWARD
var from := Vector3.ZERO
var shooter_pos := Vector3.ZERO
var travelled := 0.0
var scared := false
var power := 1.0             # heavy guns hit harder
var kind := "plasma"         # plasma / acid (Nádor) / lava (Ohnivec): the spit falls in an arc
var vel := Vector3.ZERO
var mission: Node
var streak := false

func _ready() -> void:
	var mi := MeshInstance3D.new()
	var col := Color(0.4, 1.0, 0.45)
	if kind == "acid": col = Color(0.65, 0.95, 0.15)
	elif kind == "lava": col = Color(1.0, 0.4, 0.05)
	elif kind == "rocket": col = Color(1.0, 0.55, 0.15)
	streak = (kind == "plasma" and power < 1.8) or kind == "rocket"
	if kind == "rocket":
		# the Levit officer's launcher: a dark tube with a burning tail
		var cm := CylinderMesh.new()
		cm.top_radius = 0.05; cm.bottom_radius = 0.05; cm.height = 0.5; cm.radial_segments = 6
		mi.mesh = cm
		mi.rotation.x = PI / 2
		var tail := MeshInstance3D.new()
		var sm2 := SphereMesh.new()
		sm2.radius = 0.09; sm2.height = 0.3
		tail.mesh = sm2
		tail.material_override = Game.color_mat(col, true)
		add_child(tail)
		tail.position = Vector3(0, 0, 0.3)
		col = Color(0.15, 0.15, 0.17)
	elif streak:
		# hand weapons: a long thin dash of light (the round balls are for ship cannons)
		var bm := BoxMesh.new()
		bm.size = Vector3(0.035, 0.035, 0.85 + power * 0.25)
		mi.mesh = bm
	else:
		var sm := SphereMesh.new()
		sm.radius = 0.09; sm.height = 0.18; sm.radial_segments = 6; sm.rings = 3
		mi.mesh = sm
		mi.scale = Vector3.ONE * (0.8 + power * 0.35) * (1.4 if kind != "plasma" else 1.0)
	mi.material_override = Game.color_mat(col, kind != "rocket")
	add_child(mi)
	if kind == "rocket":
		col = Color(1.0, 0.55, 0.15)
	vel = dir * speed_for(power, kind)
	if streak and vel.length() > 0.1:
		look_at(global_position + vel, Vector3.UP if absf(vel.normalized().y) < 0.95 else Vector3.RIGHT)
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 1.5
	l.omni_range = 4.0
	add_child(l)

func _physics_process(dt: float) -> void:
	# a bolt hissing past your head is terrifying
	var me: Node = mission.local_player()
	if not scared and me and not me.downed and global_position.distance_to(me.global_position + Vector3(0, 1.4, 0)) < 1.8:
		scared = true
		me.stress = min(100.0, me.stress + 14.0)
	if kind != "plasma" and kind != "rocket":
		vel.y -= 7.0 * dt
	var nxt := global_position + vel * dt
	var q := PhysicsRayQueryParameters3D.create(global_position, nxt, 1 | 2)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit and kind == "rocket":
		if multiplayer.is_server():
			mission.explode(hit.position, 4.2, 85.0 * (1.15 if Game.veteran() else 1.0), "-", true)
		queue_free()
		return
	if hit:
		var base := (randf_range(18.0, 30.0) if Game.veteran() else randf_range(8.0, 14.0)) * power
		if multiplayer.is_server() and hit.collider and hit.collider.has_method("is_player"):
			var pl: Node = hit.collider
			pl.hurt.rpc_id(pl.get_multiplayer_authority(), base, shooter_pos)
		if multiplayer.is_server() and hit.collider and hit.collider.has_meta("break"):
			mission.hit_breakable(int(hit.collider.get_meta("break")), base, "plasma")
		if kind == "plasma" and power >= 1.9 and multiplayer.is_server():
			# the plasma cannon: the bolt bursts - through a wall, if need be
			mission.explode(hit.position, 2.6, 30.0 * power / 2.0, "-", false)
		if kind != "plasma":
			# a splash of acid / molten rock: hurts whoever stands close
			if multiplayer.is_server():
				for pl2 in mission.players():
					if pl2 != hit.collider and not pl2.dead and pl2.global_position.distance_to(hit.position) < 1.8:
						pl2.hurt.rpc_id(pl2.get_multiplayer_authority(), base * 0.5, hit.position)
			mission.splash_fx(hit.position, kind)
		queue_free()
		return
	global_position = nxt
	travelled += vel.length() * dt
	if travelled > 140.0:
		queue_free()
