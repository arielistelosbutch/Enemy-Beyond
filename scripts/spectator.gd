class_name Spectator
extends Node3D
## (0.70+) Ari: "dobré by bylo zapnout kameru po smrti v bojišti, abys mohl sledovat posledního
## přeživšího". After the own merc died (dead, not just down) in a co-op mission, the dead player
## watches the living teammates until the mission ends:
##  - za zády (default): a camera behind and above the teammate, the mouse turns it round him, the
##    wheel moves it closer / further; it does not go through walls
##  - z očí (Space): from his eyes, looking where he looks (his own body hidden for this camera)
##  - LMB / D = next teammate, RMB / A = previous; when the watched one dies, after a moment it goes
##    to the next living one by itself (standing ones first) - so in the end the last survivor.
## Only what the teammate himself could see: no HUD of his, no aliens marked, nothing through walls
## (hardcore). Nothing goes over the network - every machine watches with its own camera; the
## sounds are heard where the camera is (the camera is the listener).

const HIDE_LAYER := 1 << 17          # the watched teammate's body in the "z očí" view
const DELAY := 3.0                   # the moment of death stays in the own eyes first
const SWITCH_AFTER := 2.5            # the watched one died: this long on his body, then the next
const DIST_MIN := 1.6
const DIST_MAX := 7.0

var me: Node                         # the dead local merc
var mission: Node
var cam: Camera3D
var target: Node = null
var eyes := false
var yaw := 0.0
var pitch := -0.3
var dist := 3.4
var waiting := DELAY                 # > 0: still the own (dead) eyes
var _mouse := Vector2.ZERO
var _hidden: Array = []              # [node, old layers] hidden in the eyes view
var _gone_t := 0.0                   # how long the watched one is dead
var _pos := Vector3.ZERO
var _placed := false

## Is it time for the spectator (own merc dead, the mission goes on, somebody else alive)?
static func wanted(m: Node, p: Node) -> bool:
	return p != null and p.dead and not m.finished and not living(m, p).is_empty()

## Living teammates (also the downed: they are alive), in a fixed order (the same on every press).
static func living(m: Node, p: Node) -> Array:
	var out := []
	for o in m.players():
		if o != p and is_instance_valid(o) and not o.dead:
			out.append(o)
	out.sort_custom(func(a, b): return String(a.name) < String(b.name))
	return out

func _ready() -> void:
	name = "Spectator"
	cam = Camera3D.new()
	cam.fov = Game.fov
	cam.near = 0.05
	cam.far = me.cam.far if me and me.cam else 4000.0
	cam.cull_mask = 0xFFFFF & ~me.FP_LAYER & ~me.SHIELD_LAYER & ~HIDE_LAYER
	add_child(cam)

func active() -> bool:
	return waiting <= 0.0 and target != null and is_instance_valid(target)

func _unhandled_input(event: InputEvent) -> void:
	if waiting > 0.0 or (mission.hud and mission.hud.paused):
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse += event.screen_relative
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			dist = maxf(DIST_MIN, dist - 0.4)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dist = minf(DIST_MAX, dist + 0.4)

func _process(delta: float) -> void:
	if not is_instance_valid(me) or mission == null:
		queue_free()
		return
	if waiting > 0.0:
		waiting -= delta
		if waiting > 0.0:
			return
		_pick(0, true)
		if target == null:
			waiting = 0.5           # nobody alive just now: try again in a moment
			return
		cam.current = true
	if target == null or not is_instance_valid(target):
		_set_target(null)
		_pick(0, true)
		if target == null:
			return
	# the controls (not while the menu is open)
	var free: bool = not (mission.hud and mission.hud.paused)
	if free:
		if Input.is_action_just_pressed("fire") or Input.is_action_just_pressed("move_right"):
			_pick(1, false)
		elif Input.is_action_just_pressed("aim") or Input.is_action_just_pressed("move_left"):
			_pick(-1, false)
		if Input.is_action_just_pressed("jump"):
			eyes = not eyes
			_hide_body(eyes)
			_placed = false
	# the watched one died: stay a while, then the next living one
	if target.dead:
		_gone_t += delta
		if _gone_t > SWITCH_AFTER and not Spectator.living(mission, me).is_empty():
			_pick(1, true)
	else:
		_gone_t = 0.0
	cam.fov = Game.fov
	if eyes and not target.dead:
		_eyes_view(delta)
	else:
		_orbit_view(delta)

## Next (+1) / previous (-1) / best (0) living teammate. `auto`: standing ones first.
func _pick(step: int, auto: bool) -> void:
	var ls := Spectator.living(mission, me)
	if ls.is_empty():
		return
	if auto:
		var up := ls.filter(func(o): return not o.downed)
		if not up.is_empty():
			ls = up
	var i := ls.find(target)
	var n: Node = ls[0] if i < 0 else ls[posmod(i + step, ls.size())]
	if step == 0 and i >= 0:
		n = target
	if n != target:
		_set_target(n)

func _set_target(n: Node) -> void:
	_hide_body(false)
	target = n
	_gone_t = 0.0
	_placed = false
	if n != null:
		yaw = n.global_rotation.y
		pitch = -0.3
		if eyes:
			_hide_body(true)

## The watched teammate's own body (and his name tag) out of this camera in the eyes view;
## what he holds stays (it hangs on bone attachments).
func _hide_body(on: bool) -> void:
	for h in _hidden:
		if is_instance_valid(h[0]):
			h[0].layers = h[1]
	_hidden.clear()
	if not on or target == null or not is_instance_valid(target):
		return
	var root: Node = target.merc_model if target.merc_model else target.body
	for n in root.find_children("*", "VisualInstance3D", true, false):
		var held := false
		var a: Node = n.get_parent()
		while a and a != root:
			if a is BoneAttachment3D:
				held = true
				break
			a = a.get_parent()
		if not held:
			_hidden.append([n, n.layers])
			n.layers = HIDE_LAYER
	if target.label:
		_hidden.append([target.label, target.label.layers])
		target.label.layers = HIDE_LAYER

## The point the camera turns round: his chest (the smoothed picture, not the network steps).
func _pivot() -> Vector3:
	var b: Node3D = target.body if target.body else target
	var h := 0.55 if (target.dead or target.downed or target.prone) else (1.05 if target.crouching else 1.45)
	return b.global_position + Vector3(0, h, 0)

func _orbit_view(delta: float) -> void:
	var sens := 0.0012 * Game.mouse_sens
	yaw -= _mouse.x * sens
	pitch = clampf(pitch - _mouse.y * sens * (-1.0 if Game.invert_y else 1.0), -1.25, 0.6)
	_mouse = Vector2.ZERO
	var piv := _pivot()
	var dir := Basis.from_euler(Vector3(pitch, yaw, 0)) * Vector3(0, 0, 1)
	var want := piv + dir * dist
	# not through walls: stop in front of the first one (a hand's width off it)
	var q := PhysicsRayQueryParameters3D.create(piv, want, Game.WORLD)
	q.exclude = [target.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		want = piv + dir * maxf(0.3, piv.distance_to(hit["position"]) - 0.25)
	_pos = want if not _placed else _pos.lerp(want, minf(1.0, delta * 12.0))
	_placed = true
	cam.global_position = _pos
	cam.look_at(piv, Vector3.UP)

func _eyes_view(delta: float) -> void:
	_mouse = Vector2.ZERO
	var b: Node3D = target.body if target.body else target
	var h := 0.4 if (target.downed or target.prone) else (1.05 if target.crouching else 1.62)
	var eye: Vector3 = b.global_position + Vector3(0, h, 0)
	var basis := Basis.from_euler(Vector3(target.pitch, b.global_rotation.y, 0))
	eye += basis * Vector3(0, 0, -0.12)            # just in front of his face
	if not _placed:
		cam.global_transform = Transform3D(basis, eye)
		_placed = true
	else:
		var k := minf(1.0, delta * 14.0)
		cam.global_transform = Transform3D(cam.global_transform.basis.slerp(basis.orthonormalized(), k), cam.global_position.lerp(eye, k))
	# keep the orbit behind him for when the view goes back
	yaw = b.global_rotation.y
	pitch = -0.3

## Back to the own camera (the mission ended, or the own merc was somehow back on his feet).
func stop() -> void:
	_hide_body(false)
	if is_instance_valid(me) and me.cam:
		me.cam.current = true
	queue_free()
