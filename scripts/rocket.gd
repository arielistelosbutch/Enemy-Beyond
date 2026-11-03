extends Node3D
## A rocket from the launcher. Every machine flies its own copy; the host
## decides the damage when it bursts.

const SPEED := 32.0
var dir := Vector3.FORWARD
var shooter := ""
var mission: Node
var travelled := 0.0

func _ready() -> void:
	var m := Game.model("rocket")
	add_child(m)
	# the motor roars along with the rocket (and goes quiet when it bursts)
	var snd := AudioStreamPlayer3D.new()
	snd.stream = Game.sound("rocket_fly")
	snd.unit_size = 8.0
	snd.max_distance = 120.0
	snd.bus = "SFX"
	add_child(snd)
	snd.play()
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.25)
	l.light_energy = 3.0
	l.omni_range = 6.0
	add_child(l)
	l.position = Vector3(0, 0, 0.35)
	var trail := CPUParticles3D.new()
	trail.amount = 40
	trail.lifetime = 0.8
	trail.local_coords = false
	trail.gravity = Vector3(0, 0.6, 0)
	trail.initial_velocity_min = 0.2
	trail.initial_velocity_max = 0.5
	trail.scale_amount_min = 0.6
	trail.scale_amount_max = 1.4
	var qm := QuadMesh.new()
	qm.size = Vector2(0.25, 0.25)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.5, 0.5, 0.5, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.material = mat
	trail.mesh = qm
	add_child(trail)
	trail.position = Vector3(0, 0, 0.3)
	look_at(global_position + dir, Vector3.UP if abs(dir.y) < 0.99 else Vector3.RIGHT)

func _physics_process(dt: float) -> void:
	var nxt := global_position + dir * SPEED * dt
	var q := PhysicsRayQueryParameters3D.create(global_position, nxt, 1 | 4)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit or travelled > 120.0:
		var p: Vector3 = hit.position if hit else global_position
		if multiplayer.is_server():
			mission.explode(p, 4.5, 160.0, shooter, true)
		queue_free()
		return
	global_position = nxt
	travelled += SPEED * dt
