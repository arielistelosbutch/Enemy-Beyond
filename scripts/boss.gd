extends "res://scripts/alien.gd"
## The last mission on Mars: the Great Brain ("Mozek") and its three shield pylons.
## The Brain does not move. While any pylon stands, nothing touches it (a violet shield).
## It reaches into minds across the whole hall (panic, pain, taking hands), and calls
## its guards. Pylons only stand and hum - shoot them down to open the shield.

var _psi_t := 6.0
var _call_t := 20.0
var _shield: MeshInstance3D
var _pulse := 0.0

func setup(data: Dictionary) -> void:
	super.setup(data)
	if race == "mozek":
		_shield = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 2.4
		sm.height = 4.0
		_shield.mesh = sm
		var mt := StandardMaterial3D.new()
		mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mt.albedo_color = Color(0.6, 0.3, 1.0, 0.18)
		mt.cull_mode = BaseMaterial3D.CULL_DISABLED
		_shield.material_override = mt
		add_child(_shield)
		_shield.position = Vector3(0, 1.4, 0)
		var l := OmniLight3D.new()
		l.light_color = Color(0.8, 0.4, 1.0)
		l.light_energy = 2.0
		l.omni_range = 10.0
		add_child(l)
		l.position = Vector3(0, 3.0, 0)

func pylons_up() -> int:
	var n := 0
	for a in mission.aliens():
		if a.race == "pylon" and not a.dead:
			n += 1
	return n

## While the pylons stand, the Brain takes no harm.
func taken(dmg: float) -> float:
	if race == "mozek" and pylons_up() > 0:
		if mission and mission.local_player():
			mission.hud.message("Štít drží! Nejdřív zničte pylony (%d)." % pylons_up(), 1.5)
		return 0.0
	return super.taken(dmg)

func _physics_process(delta: float) -> void:
	_pulse += delta
	if race == "mozek" and body:
		var s := 1.0 + sin(_pulse * (2.0 if pylons_up() == 0 else 1.2)) * 0.03
		body.scale = Vector3(s, s, s)
		if _shield:
			_shield.visible = not dead and pylons_up() > 0
	elif race == "pylon" and body and not dead:
		body.rotation.y += delta * 0.6
	if dead:
		if race == "pylon" and body:
			body.position.y = lerp(body.position.y, -0.6, delta * 2.0)
			body.rotation.z = lerp(body.rotation.z, 0.5, delta * 2.0)
		return
	if not multiplayer.is_server() or (mission and not mission.started()):
		return
	if race == "mozek":
		_brain_think(delta)

func _brain_think(delta: float) -> void:
	alert = true
	_psi_t -= delta
	_call_t -= delta
	var angry := pylons_up() == 0
	if _psi_t <= 0:
		_psi_t = rng.randf_range(4.0, 7.0) if angry else rng.randf_range(7.0, 11.0)
		var targets := []
		for p in mission.players():
			if not p.dead and not p.downed and p.global_position.distance_to(global_position) < 45.0:
				targets.append(p)
		if not targets.is_empty():
			var t: Node = targets[rng.randi() % targets.size()]
			_psi_fx.rpc()
			if rng.randf() < 0.5:
				t.psi_blast.rpc_id(t.get_multiplayer_authority(), rng.randf_range(8.0, 14.0) * (1.4 if angry else 1.0))
			else:
				t.psi_attack.rpc_id(t.get_multiplayer_authority(), 0.4 + rng.randf() * 0.6)
	if _call_t <= 0:
		# guards come out of the walls
		_call_t = rng.randf_range(18.0, 26.0) if not angry else rng.randf_range(12.0, 16.0)
		var spots: Array = mission.map["alien_spawns"]
		var n := 2 if not angry else 3
		for i in n:
			mission.spawn_alien(["myslodej", "bijec", "bijec_velitel"][rng.randi() % 3], spots[rng.randi() % spots.size()])
		mission.hud_note.rpc("Mozek volá stráže...")
