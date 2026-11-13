extends Node3D
## Strážce: a small helper drone that flies with a mercenary who went alone (solo only).
## It hovers over his right shoulder, slowly patches him up (never above half his health),
## brings him back once per mission when he goes down, and beeps when something shoots at him
## from where he is not looking. It is no gun: the horror stays, he just is not quite alone.

var mission: Node
var charge := 1             # one rescue per mission
var _spent_one := false     # (0.62) Technik dronu: the first of two rescues used
var _rescue_t := -1.0
var _warn_cd := {}          # alien name -> seconds until it may warn about it again
var _bob := 0.0
var _body: Node3D
var _lamp: OmniLight3D
var _eye: MeshInstance3D
var _rotors: Array[Node3D] = []   # (0.70) the four propellers; meta "rotor" true = turns the other way
var _last_pos := Vector3.ZERO
var _tilt := Vector3.ZERO         # lean into the flight (x = pitch, z = roll)
const PROP_SPIN := 34.0           # rad/s - slow enough that the eye still sees the blades go round
var _hum: AudioStreamPlayer3D

const HEAL_RATE := 0.45     # health per second
const HEAL_CAP := 0.5       # up to this part of max health

func _ready() -> void:
	name = "GuardDrone"
	_body = Node3D.new()
	add_child(_body)
	_build()
	_lamp = OmniLight3D.new()
	_lamp.light_color = Color(0.4, 1.0, 0.6)
	_lamp.light_energy = 0.25
	_lamp.omni_range = 1.6
	add_child(_lamp)
	_hum = AudioStreamPlayer3D.new()
	_hum.stream = Game.loop_stream("hum")
	_hum.volume_db = -30.0
	_hum.pitch_scale = 2.2
	_hum.unit_size = 1.0
	_hum.max_distance = 8.0
	_hum.bus = "SFX"
	add_child(_hum)
	_hum.play()

## (0.70 facelift) the model from tools/blender/drone.py: a quadcopter with four guarded
## propellers (Prop_*) that spin, the sensor Eye in front. Without the file the old box drone.
func _build() -> void:
	if ResourceLoader.exists("res://assets/models/guard_drone.glb"):
		var m := Game.model("guard_drone")
		_body.add_child(m)
		for n in m.find_children("*", "MeshInstance3D", true, false):
			if n.name.begins_with("Prop"):
				n.set_meta("rotor", n.name.ends_with("FL") or n.name.ends_with("BR"))
				_rotors.append(n)
			elif n.name == "Eye":
				_eye = n
		if _eye != null:
			return
	var grey := Game.color_mat(Color(0.36, 0.38, 0.42))
	var dark := Game.color_mat(Color(0.12, 0.13, 0.15))
	_part(BoxMesh.new(), Vector3(0.22, 0.07, 0.22), Vector3.ZERO, grey)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_part(BoxMesh.new(), Vector3(0.05, 0.02, 0.05), Vector3(sx * 0.15, 0.04, sz * 0.15), dark)
			var rotor := _part(CylinderMesh.new(), Vector3(0.16, 0.006, 0.16), Vector3(sx * 0.15, 0.06, sz * 0.15), dark)
			rotor.set_meta("rotor", true)
			_rotors.append(rotor)
	_eye = _part(SphereMesh.new(), Vector3(0.05, 0.05, 0.05), Vector3(0, -0.02, -0.11), Game.color_mat(Color(0.3, 1.0, 0.5), true))
	# a red cross on top: the medic
	_part(BoxMesh.new(), Vector3(0.1, 0.01, 0.03), Vector3(0, 0.04, 0), Game.color_mat(Color(0.9, 0.15, 0.15)))
	_part(BoxMesh.new(), Vector3(0.03, 0.01, 0.1), Vector3(0, 0.04, 0), Game.color_mat(Color(0.9, 0.15, 0.15)))

func _part(mesh: PrimitiveMesh, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if mesh is BoxMesh:
		(mesh as BoxMesh).size = size
	elif mesh is CylinderMesh:
		(mesh as CylinderMesh).top_radius = size.x
		(mesh as CylinderMesh).bottom_radius = size.x
		(mesh as CylinderMesh).height = size.y
	elif mesh is SphereMesh:
		(mesh as SphereMesh).radius = size.x / 2.0
		(mesh as SphereMesh).height = size.x
	mi.mesh = mesh
	mi.material_override = mat
	_body.add_child(mi)
	mi.position = pos
	return mi

## Will it still bring him back? (the mission does not call it a lost fight yet)
func can_rescue(p: Node) -> bool:
	return charge > 0 and is_instance_valid(p) and p.downed and not p.dead

func _process(delta: float) -> void:
	var p: Node3D = mission.local_player()
	if p == null or not is_instance_valid(p):
		return
	# fly: over the right shoulder, a little behind; low over him when he is down
	_bob += delta
	var basis_y := Basis(Vector3.UP, p.rotation.y)
	var want: Vector3 = p.global_position + basis_y * Vector3(0.55, 2.05, 0.45)
	if p.downed:
		want = p.global_position + Vector3(0.3, 0.9, 0.0)
	want.y += sin(_bob * 2.3) * 0.05
	global_position = global_position.lerp(want, clampf(delta * 3.0, 0.0, 1.0)) if global_position.distance_to(want) < 6.0 else want
	rotation.y = lerp_angle(rotation.y, p.rotation.y, clampf(delta * 4.0, 0.0, 1.0))
	# (0.70) the propellers turn (opposite pairs the other way, as on a real quadcopter; a touch
	# faster while it climbs or chases him) and the body leans the way it flies
	var vel := (global_position - _last_pos) / maxf(delta, 0.001) if _last_pos != Vector3.ZERO else Vector3.ZERO
	_last_pos = global_position
	if vel.length() > 20.0:
		vel = Vector3.ZERO           # (it jumped to him from far away)
	var spin := PROP_SPIN * (1.0 + clampf(vel.length() * 0.12 + maxf(vel.y, 0.0) * 0.2, 0.0, 0.6))
	for r in _rotors:
		if is_instance_valid(r):
			r.rotate_y(delta * spin * (1.0 if r.get_meta("rotor", true) else -1.0))
	var local_v := global_transform.basis.inverse() * vel
	var want_tilt := Vector3(clampf(local_v.z * 0.12, -0.3, 0.3), 0.0, clampf(-local_v.x * 0.12, -0.3, 0.3))
	_tilt = _tilt.lerp(want_tilt, clampf(delta * 5.0, 0.0, 1.0))
	_body.rotation = Vector3(_tilt.x, 0.0, _tilt.z)
	if p.dead:
		_lamp.light_energy = 0.0
		return
	if not multiplayer.is_server():
		return
	_heal(p, delta)
	_rescue(p, delta)
	_warn(p, delta)

## 0.62 talent Technik dronu (the easy difficulty's swap for Šestý smysl): twice the healing, up to
## three quarters of the health, and two rescues a mission.
func _tech(p: Node) -> bool:
	return Game.has_talent(p.merc, "technik_dronu")

func _heal(p: Node, delta: float) -> void:
	var cap := HEAL_CAP * (1.5 if _tech(p) else 1.0)
	if p.downed or p.hp >= p.max_hp * cap:
		return
	p.hp = minf(p.max_hp * cap, p.hp + HEAL_RATE * (2.0 if _tech(p) else 1.0) * delta)
	_lamp.light_energy = 0.25 + absf(sin(_bob * 6.0)) * 0.5

func _rescue(p: Node, delta: float) -> void:
	if not can_rescue(p):
		_rescue_t = -1.0
		_wait_t = 0.0
		_waiting = false
		return
	# (0.60, 0.68) it does not stand him up into the claws: while something is right over him it
	# holds back a moment - but not for ever (aliens linger by a fallen man, a grey drags him off:
	# waiting for a gap that never comes left him to bleed out). Being dragged is no reason to wait:
	# standing up gets him out of the alien's hands.
	if _threat_near(p) and _wait_t < MAX_WAIT and p.bleed_left > LAST_CALL:
		if not _waiting:
			_waiting = true
			mission.hud.message("Strážce: nepřítel je moc blízko. Čekám na chvilku...", 3.0)
		_wait_t += delta
		_lamp.light_energy = 0.15
		return
	if _rescue_t < 0.0 or _waiting:
		_waiting = false
		if _rescue_t < 0.0:
			_rescue_t = 3.5
			_smoke(p)          # the cloud builds while it works on him
		mission.hud.message("Strážce: zůstaň se mnou! Aplikuji stimulant...", 3.0)
		Game.play_ui(mission, "radar_ping", -6)
	_rescue_t -= delta
	_lamp.light_energy = 1.2 if fmod(_bob, 0.4) < 0.2 else 0.2
	if _rescue_t <= 0.0:
		if _tech(p) and not _spent_one:
			_spent_one = true      # (0.62) Technik dronu: a second dose
		else:
			charge = 0
		_rescue_t = -1.0
		_wait_t = 0.0
		_cover(p)
		p.revived.rpc_id(p.get_multiplayer_authority(), "Strážce")
		mission.hud.message("Strážce: stimulant došel. Podruhé už tě nezvednu." if charge == 0 else "Strážce: mám ještě jednu dávku stimulantu.", 5.0)

const SAFE_R := 4.0         # an alien this close (right over him): hold back a moment
const MAX_WAIT := 5.0       # ... at most this long
const LAST_CALL := 20.0     # and never once he has less than this left to bleed
var _waiting := false
var _wait_t := 0.0

func _threat_near(p: Node3D) -> bool:
	for a in mission.aliens():
		if a.dead or a.get("husk") or a.get("dragging") == p:
			continue
		if a.global_position.distance_to(p.global_position) < SAFE_R:
			return true
	return false

## The drone drops a smoke cloud over him as it starts (it is thick by the time he gets up).
func _smoke(p: Node3D) -> void:
	mission.add_smoke(p.global_position)
	Game.play_at(mission, "smoke_pop", p.global_position, -4)

## The moment he gets up: whoever was fighting him is caught off guard (the man they left on the
## ground stands up) - the same surprise as on first sight, no blindness, no forgetting: they still
## know where he is. An alien dragging him lets go (he is no longer down).
func _cover(p: Node3D) -> void:
	for a in mission.aliens():
		if a.dead or a.global_position.distance_to(p.global_position) > 40.0:
			continue
		if a.get("target") == p or a.global_position.distance_to(p.global_position) < 20.0:
			if "react" in a:
				a.react = maxf(a.react, randf_range(0.9, 1.6))

func _warn(p: Node3D, delta: float) -> void:
	for k in _warn_cd.keys():
		_warn_cd[k] = float(_warn_cd[k]) - delta
		if _warn_cd[k] <= 0.0:
			_warn_cd.erase(k)
	for a in mission.aliens():
		if a.dead or _warn_cd.has(String(a.name)):
			continue
		if a.state != a.S.COMBAT or not is_instance_valid(a.target) or a.target != p:
			continue
		var to: Vector3 = a.global_position - p.global_position
		to.y = 0.0
		to = to.normalized()
		var look: Vector3 = -p.global_transform.basis.z
		look.y = 0.0
		look = look.normalized()
		var front := look.dot(to)
		if front > 0.64:
			continue          # he can see it himself (within ~50 degrees)
		_warn_cd[String(a.name)] = 12.0
		var right: Vector3 = p.global_transform.basis.x
		var side := "za tebou" if front < -0.64 else ("vpravo" if right.dot(to) > 0.0 else "vlevo")
		mission.hud.message("Strážce: kontakt %s!" % side, 2.0)
		Game.play_ui(mission, "scanner_close", -4)
		_eye.material_override = Game.color_mat(Color(1.0, 0.3, 0.2), true)
		get_tree().create_timer(1.0).timeout.connect(func(): if is_instance_valid(_eye): _eye.material_override = Game.color_mat(Color(0.3, 1.0, 0.5), true))
		break
