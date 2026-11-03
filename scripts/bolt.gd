extends Node3D
## A slow green plasma bolt. Every machine flies its own copy; only the host
## decides whether it hurt somebody.

const SPEED := 22.0

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
	streak = kind == "plasma" and power < 1.8
	if streak:
		# hand weapons: a long thin dash of light (the round balls are for ship cannons)
		var bm := BoxMesh.new()
		bm.size = Vector3(0.035, 0.035, 0.85 + power * 0.25)
		mi.mesh = bm
	else:
		var sm := SphereMesh.new()
		sm.radius = 0.09; sm.height = 0.18; sm.radial_segments = 6; sm.rings = 3
		mi.mesh = sm
		mi.scale = Vector3.ONE * (0.8 + power * 0.35) * (1.4 if kind != "plasma" else 1.0)
	mi.material_override = Game.color_mat(col, true)
	add_child(mi)
	vel = dir * ((SPEED * 1.5 if streak else SPEED) if kind == "plasma" else 15.0)
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
	if kind != "plasma":
		vel.y -= 7.0 * dt
	var nxt := global_position + vel * dt
	var q := PhysicsRayQueryParameters3D.create(global_position, nxt, 1 | 2)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		var base := (randf_range(18.0, 30.0) if Game.veteran() else randf_range(8.0, 14.0)) * power
		if multiplayer.is_server() and hit.collider and hit.collider.has_method("is_player"):
			var pl: Node = hit.collider
			pl.hurt.rpc_id(pl.get_multiplayer_authority(), base, shooter_pos)
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
	if travelled > 70.0:
		queue_free()
