extends Node3D
## Air combat prototype: the interceptor "Sokol" against a flying UFO, at
## night above the clouds. Bring it down damaged and it crashes (a ground
## mission with survivors and loot); blast it apart and nothing is left.
## Big UFOs shoot back.
##
## Rules (own): the UFO has structure points. When they reach zero it goes
## down - but if it took more than a third of its structure in the last two
## seconds (missile salvo, point-blank burst) it explodes in the air instead.
## Below half structure it tries to flee; far enough away = escaped.

const UFO_KINDS := {
	"scout": {"name": "Průzkumník (malé UFO)", "hp": 70.0, "speed": 62.0, "turn": 1.6, "guns": 1, "aliens": 0, "armor": 1.0, "scale": 2.2},
	"raider": {"name": "Nájezdník (střední UFO)", "hp": 170.0, "speed": 52.0, "turn": 1.0, "guns": 1, "aliens": 1, "armor": 0.6, "scale": 2.0},
	"harvester": {"name": "Sklízeč (velké UFO)", "hp": 360.0, "speed": 42.0, "turn": 0.6, "guns": 3, "aliens": 3, "armor": 0.35, "scale": 1.8},
}
const CANNON_DMG := 3.0
const MISSILE_DMG := 38.0
const TIME_LIMIT := 150.0

var params := {}
var kind := "raider"
var jet: Node3D
var ufo: Node3D
var cam: Camera3D
var hud: Control
var env: Environment

# jet state
var speed := 70.0
var throttle := 0.7
var jet_hp := 100.0
var ammo := 400
var missiles := 4
var cannon_cd := 0.0
var missile_cd := 0.0
var lock := 0.0
# arcade dodge: tap A/D = sharp break to the side (sideslip + snap roll)
var slide := Vector3.ZERO
var break_cd := 0.0
var snap_roll := 0.0
# ufo dodge
var ufo_jink := Vector3.ZERO
var ufo_jink_cd := 1.5
var _mouse := Vector2.ZERO
var aim := Vector2.ZERO        # virtual stick, -1..1

# ufo state
var ufo_hp := 170.0
var ufo_max := 170.0
var ufo_vel := Vector3.ZERO
var ufo_dir := Vector3.FORWARD
var recent := []               # [time, damage]
var fleeing := false
var ufo_fire_cd := 2.0
var weave := 0.0

var speed_cap := 999.0         # the escort's transport flies slower than a jet
var t := 0.0
var outcome := ""
var end_t := 0.0
var msg := ""
var msg_t := 0.0
var bolts := []                # [{node, vel, life}]
var tracers := []
var rockets := []
# ---- co-op: one Sokol per pilot; the host flies the UFO, every pilot his own jet ----------
var net := false
var pilots: Array = [1]
var me_pilot := true
var down := false               # my jet is gone
var others := {}                # peer -> {node, pos, prev, vel, down}
var _sync_t := 0.0
var _ufo_goal := Vector3.ZERO
var _shots := 0

func _ready() -> void:
	Game.play_music("interception")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	params = Net.mission_params
	kind = params.get("ufo", "raider")
	var k: Dictionary = UFO_KINDS[kind]
	ufo_hp = k["hp"]
	ufo_max = k["hp"]
	_world()
	net = Net.is_online() and params.has("pilots")
	if net:
		pilots = params["pilots"]
		me_pilot = Net.my_id() in pilots
	for i in pilots.size():
		var pid: int = pilots[i]
		var node := Game.model("sokol")
		add_child(node)
		node.position = Vector3((i - (pilots.size() - 1) / 2.0) * 40.0, 900 + i * 6.0, i * 15.0)
		if pid == Net.my_id() or not net:
			jet = node
		else:
			others[pid] = {"node": node, "pos": node.position, "prev": node.position, "vel": Vector3.ZERO, "down": false, "name": Net.roster.get(pid, {}).get("name", "Sokol")}
	if jet == null:
		# not flying (more players than jets): ride along on the host's wing
		jet = others[pilots[0]]["node"]
		down = true
	ufo = Game.model("ufo_" + kind)
	add_child(ufo)
	ufo.scale = Vector3.ONE * float(k["scale"])
	ufo.position = Vector3(randf_range(-150, 150), 920, -650)
	var eng := AudioStreamPlayer3D.new()
	eng.stream = Game.loop_stream("ufo_engine")
	eng.unit_size = 40.0
	eng.max_distance = 900.0
	eng.autoplay = true
	ufo.add_child(eng)
	ufo_dir = Vector3(randf_range(-1, 1), 0, -1).normalized()
	var ul := OmniLight3D.new()
	ul.light_color = Color(0.6, 0.35, 1.0)
	ul.light_energy = 6.0
	ul.omni_range = 60.0
	ufo.add_child(ul)
	var jl := OmniLight3D.new()
	jl.light_color = Color(1.0, 0.6, 0.3)
	jl.light_energy = 2.0
	jl.omni_range = 12.0
	jet.add_child(jl)
	jl.position = Vector3(0, 0, 4)
	cam = Camera3D.new()
	cam.fov = 70
	cam.far = 6000
	add_child(cam)
	cam.current = true
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.draw.connect(_draw_hud)
	var cl := CanvasLayer.new()
	cl.layer = 5
	cl.add_child(hud)
	add_child(cl)
	var music := AudioStreamPlayer.new()
	var st: AudioStreamWAV = Game.sound("wind").duplicate()
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_end = st.data.size() / 2
	music.stream = st
	music.volume_db = -6
	music.bus = "Wind"
	add_child(music)
	music.play()
	_say("KONTAKT: %s. Přivést k zemi poškozené = posádka a kořist. Rozstřílet = nic." % k["name"], 6.0)

func _world() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.03, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.2, 0.25, 0.4)
	env.ambient_light_energy = 0.5
	env.fog_enabled = true
	env.fog_light_color = Color(0.03, 0.05, 0.1)
	env.fog_density = 0.0008
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.7, 0.75, 1.0)
	moon.light_energy = 0.6
	moon.rotation_degrees = Vector3(-30, 30, 0)
	add_child(moon)
	# cloud deck below: a big plane with a moving noise shader
	var clouds := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12000, 12000)
	pm.subdivide_width = 1
	clouds.mesh = pm
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;
uniform float time_s;
float h(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p){ vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
 return mix(mix(h(i), h(i+vec2(1,0)), f.x), mix(h(i+vec2(0,1)), h(i+vec2(1,1)), f.x), f.y); }
varying vec3 wp;
void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
 vec2 p = wp.xz * 0.004 + vec2(time_s * 0.01, 0.0);
 float v = n(p) * 0.5 + n(p * 2.3) * 0.3 + n(p * 5.1) * 0.2;
 float d = length(wp.xz - CAMERA_POSITION_WORLD.xz);
 ALBEDO = mix(vec3(0.05, 0.06, 0.1), vec3(0.32, 0.35, 0.45), smoothstep(0.35, 0.8, v));
 ALPHA = smoothstep(0.3, 0.6, v) * (1.0 - smoothstep(2500.0, 5500.0, d));
}"""
	var cm := ShaderMaterial.new()
	cm.shader = sh
	clouds.material_override = cm
	clouds.position.y = 600
	clouds.name = "Clouds"
	add_child(clouds)
	# stars
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var qm := QuadMesh.new()
	qm.size = Vector2(6, 6)
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smat.albedo_color = Color(0.85, 0.9, 1.0)
	qm.material = smat
	mm.mesh = qm
	mm.instance_count = 500
	var r := RandomNumberGenerator.new()
	r.seed = 3
	for i in 500:
		var d := Vector3(r.randf_range(-1, 1), r.randf_range(0.05, 1), r.randf_range(-1, 1)).normalized() * 4500.0
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * r.randf_range(0.5, 1.6)), d))
	var stars := MultiMeshInstance3D.new()
	stars.multimesh = mm
	stars.name = "Stars"
	add_child(stars)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse += e.screen_relative

func _say(s: String, secs := 3.0) -> void:
	msg = s
	msg_t = secs

# ---- frame -----------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	t += delta
	msg_t -= delta
	(get_node("Clouds").material_override as ShaderMaterial).set_shader_parameter("time_s", t)
	get_node("Stars").position = cam.global_position
	if outcome != "":
		end_t += delta
		_debris(delta)
		_camera(delta)
		hud.queue_redraw()
		if end_t > 4.0 and not Game.autotest() in ["air", "airhost", "airclient"]:
			_finish()
		return
	if me_pilot and not down:
		_fly(delta)
		_weapons(delta)
	if net:
		_net_sync(delta)
	if multiplayer.is_server() or not net:
		_ufo_ai(delta)
	else:
		ufo.global_position = ufo.global_position.lerp(_ufo_goal, clampf(delta * 10.0, 0, 1))
	_projectiles(delta)
	_camera(delta)
	if multiplayer.is_server() or not net:
		_judge()
	hud.queue_redraw()

# ---- the interceptor: mouse moves a virtual stick, the jet follows ------------------------
func _fly(delta: float) -> void:
	var sens := 0.0025 * Game.mouse_sens
	aim += _mouse * sens * Vector2(1, -1 if not Game.invert_y else 1)
	_mouse = Vector2.ZERO
	aim = aim.limit_length(1.0)
	aim = aim.lerp(Vector2.ZERO, delta * 0.6)       # springs back to centre slowly
	if Input.is_action_pressed("move_forward"): throttle = min(1.0, throttle + delta * 0.6)
	if Input.is_action_pressed("move_back"): throttle = max(0.25, throttle - delta * 0.6)
	var boost := Input.is_action_pressed("sprint")
	var target_speed := 50.0 + throttle * 60.0 + (40.0 if boost else 0.0)
	speed = minf(lerp(speed, target_speed, delta * 0.8), speed_cap)
	var roll_in := Input.get_axis("move_left", "move_right")
	# A/D tap: hard break - throw the jet sideways and snap-roll (cooldown 1 s)
	break_cd -= delta
	var side := 0.0
	if Input.is_action_just_pressed("move_left"): side = -1.0
	if Input.is_action_just_pressed("move_right"): side = 1.0
	if side != 0.0:
		_break(side)
	slide = slide.lerp(Vector3.ZERO, clamp(delta * 2.2, 0, 1))
	var sr: float = clamp(snap_roll, -delta * 9.0, delta * 9.0)
	snap_roll -= sr
	# pitch/yaw from the stick; held A/D = hard bank turn (arcade, much sharper than before)
	jet.rotate_object_local(Vector3.RIGHT, aim.y * 1.8 * delta)
	jet.rotate_object_local(Vector3.UP, (-aim.x * 1.2 - roll_in * 0.9) * delta)
	jet.rotate_object_local(Vector3.FORWARD, (roll_in * 1.6 + aim.x * 1.2) * delta + sr)
	# auto-level so it stays flyable with a mouse (also out of inverted flight)
	var bx := jet.global_transform.basis
	var roll := atan2(bx.x.y, bx.y.y)
	if absf(snap_roll) < 0.05:
		jet.rotate_object_local(Vector3.FORWARD, roll * delta * 1.2 * (1.0 - abs(roll_in) * 0.7))
	jet.global_position += (-jet.global_transform.basis.z * speed + slide) * delta
	jet.global_position.y = clamp(jet.global_position.y, 620.0, 1800.0)

func _break(side: float) -> void:
	if break_cd > 0.0:
		return
	break_cd = 1.0
	slide += jet.global_transform.basis.x * side * 70.0
	snap_roll = -side * TAU * 0.5
	Game.play_ui(self, "lunge", -8)

func _camera(delta: float) -> void:
	if down and net:
		for pid in others:
			if not others[pid]["down"]:
				jet = others[pid]["node"]
				break
	var b := jet.global_transform.basis
	var want := jet.global_position + b.z * 22.0 + b.y * 6.0
	if outcome == "shot_down":
		want = jet.global_position + Vector3(30, 20, 30)
	cam.global_position = cam.global_position.lerp(want, clamp(delta * 6.0, 0, 1))
	var look := jet.global_position - b.z * 40.0
	if Input.is_action_pressed("aim") and outcome == "":
		look = ufo.global_position      # look at the target while holding RMB? no: RMB fires missiles
	cam.look_at(look, b.y)

# ---- weapons: cannon (LMB, precise) and missiles (R / middle: lock first) ------------------
func _weapons(delta: float) -> void:
	cannon_cd -= delta
	missile_cd -= delta
	var fwd := -jet.global_transform.basis.z
	var to_ufo := ufo.global_position - jet.global_position
	var dist := to_ufo.length()
	var ang := fwd.angle_to(to_ufo)
	# missile lock: keep the UFO in a 12 degree cone within 900 m for 1.5 s
	if ang < deg_to_rad(12) and dist < 900 and missiles > 0:
		lock = min(1.0, lock + delta / 1.5)
	else:
		lock = max(0.0, lock - delta * 2.0)
	if Input.is_action_pressed("fire") and cannon_cd <= 0 and ammo > 0:
		cannon_cd = 0.06
		ammo -= 1
		var spread := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.012
		var d := (fwd + spread).normalized()
		_tracer(jet.global_position + fwd * 5.0 + jet.global_transform.basis.y * -0.3, d)
		_shots += 1
		if net and _shots % 3 == 0:
			_fx_tracer.rpc(jet.global_position + fwd * 5.0, d)
		if ammo % 3 == 0:
			Game.play_ui(self, "minigun", -12)
	if (Input.is_action_just_pressed("aim") or Input.is_action_just_pressed("reload")) and missile_cd <= 0:
		if missiles <= 0:
			_say("Rakety došly.", 1.5)
		elif lock < 1.0:
			_say("Raketa nemá zaměřeno - drž UFO ve středu.", 1.5)
		else:
			missiles -= 1
			missile_cd = 1.0
			_fire_missile()

func _tracer(from: Vector3, dir: Vector3, fake := false) -> void:
	var n := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.15, 0.15, 6.0)
	n.mesh = bm
	n.material_override = Game.color_mat(Color(1.0, 0.8, 0.35), true)
	add_child(n)
	n.global_position = from
	n.look_at(from + dir, Vector3.UP)
	tracers.append({"node": n, "vel": dir * 900.0 + (dir * 120.0 if fake else -jet.global_transform.basis.z * speed), "life": 1.2, "fake": fake})

func _fire_missile() -> void:
	Game.play_ui(self, "launch", -2)
	var side := 2.0 if missiles % 2 == 0 else -2.0
	var from := jet.global_position + jet.global_transform.basis.x * side - jet.global_transform.basis.y * 0.4
	var vel := -jet.global_transform.basis.z * (speed + 40.0)
	_missile_node(from, vel, false)
	if net:
		_fx_missile.rpc(from, vel)

func _missile_node(from: Vector3, vel: Vector3, fake: bool) -> void:
	var n := Game.model("rocket")
	add_child(n)
	n.scale = Vector3.ONE * 4.0
	n.global_position = from
	var l := OmniLight3D.new()
	l.light_color = Color(1, 0.6, 0.3)
	l.light_energy = 4.0
	l.omni_range = 20.0
	n.add_child(l)
	rockets.append({"node": n, "vel": vel, "life": 8.0, "fake": fake})

func _projectiles(delta: float) -> void:
	for tr in tracers.duplicate():
		var n: Node3D = tr["node"]
		var nxt: Vector3 = n.global_position + tr["vel"] * delta
		tr["life"] -= delta
		if _seg_hits(n.global_position, nxt, ufo.global_position, _ufo_radius()):
			# cannon shells barely scratch the armour of the big ones
			if not tr.get("fake", false):
				_damage_ufo(CANNON_DMG * float(UFO_KINDS[kind]["armor"]), n.global_position)
			tr["life"] = 0
		n.global_position = nxt
		if tr["life"] <= 0:
			n.queue_free()
			tracers.erase(tr)
	for rk in rockets.duplicate():
		var n: Node3D = rk["node"]
		var to: Vector3 = (ufo.global_position - n.global_position)
		var v: Vector3 = rk["vel"]
		if not rk.get("lost", false):
			v = v.lerp(to.normalized() * 260.0, clamp(delta * 2.5, 0, 1))
		rk["vel"] = v
		var nxt: Vector3 = n.global_position + v * delta
		n.look_at(nxt + v, Vector3.UP)
		rk["life"] -= delta
		if _seg_hits(n.global_position, nxt, ufo.global_position, _ufo_radius() + 3.0):
			if not rk.get("fake", false):
				_damage_ufo(MISSILE_DMG, n.global_position)
			_flash(n.global_position, 20.0)
			Game.play_ui(self, "explosion", -2)
			rk["life"] = 0
		n.global_position = nxt
		if rk["life"] <= 0:
			n.queue_free()
			rockets.erase(rk)
	for bo in bolts.duplicate():
		var n: Node3D = bo["node"]
		var nxt: Vector3 = n.global_position + bo["vel"] * delta
		bo["life"] -= delta
		if me_pilot and not down and _seg_hits(n.global_position, nxt, jet.global_position, 4.0):
			jet_hp -= 9.0
			if jet_hp <= 0 and net:
				down = true
				jet.visible = false
				_flash(jet.global_position, 12.0)
				_say("SOKOL SESTŘELEN. Pilot se katapultoval - díváš se z křídla ostatních.", 5.0)
				_jet_down.rpc(Net.my_id())
			_say("ZÁSAH! Trup %d %%" % int(max(jet_hp, 0)), 1.5)
			_flash(n.global_position, 8.0)
			Game.play_ui(self, "hit", 0)
			bo["life"] = 0
		n.global_position = nxt
		if bo["life"] <= 0:
			n.queue_free()
			bolts.erase(bo)

func _ufo_radius() -> float:
	return {"scout": 4.5, "raider": 8.0, "harvester": 14.0}[kind] * float(UFO_KINDS[kind]["scale"])

static func _seg_hits(a: Vector3, b: Vector3, c: Vector3, r: float) -> bool:
	var ab := b - a
	var k := clampf((c - a).dot(ab) / max(ab.length_squared(), 0.0001), 0.0, 1.0)
	return (a + ab * k).distance_to(c) < r

func _flash(p: Vector3, size: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.25)
	l.light_energy = 10.0
	l.omni_range = size * 3.0
	add_child(l)
	l.global_position = p
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = size * 0.5
	sm.height = size
	sm.radial_segments = 8
	sm.rings = 4
	ball.mesh = sm
	ball.material_override = Game.color_mat(Color(1.0, 0.55, 0.15), true)
	add_child(ball)
	ball.global_position = p
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.6)
	tw.parallel().tween_property(ball, "scale", Vector3.ONE * 0.1, 0.5)
	tw.tween_callback(func(): l.queue_free(); ball.queue_free())

func _damage_ufo(d: float, at: Vector3) -> void:
	if net:
		_hit_ufo.rpc_id(1, d)
	else:
		ufo_hp -= d
		recent.append([t, d])
	if randf() < 0.3:
		_flash(at, 2.0)

# ---- UFO: weaves, turns away from the jet, fires if armed, flees when hurt ----------------
func _ufo_ai(delta: float) -> void:
	var k: Dictionary = UFO_KINDS[kind]
	if not fleeing and ufo_hp < ufo_max * 0.5:
		fleeing = true
		_say("UFO je poškozené a zrychluje - utíká!", 2.5)
	var tg := _target()
	var tpos: Vector3 = tg["pos"]
	var away := (ufo.global_position - tpos)
	away.y = 0
	var want := ufo_dir
	weave += delta
	if fleeing:
		want = away.normalized().lerp(ufo_dir, 0.3)
	elif away.length() < 250:
		# break away to the side when the jet is close
		want = away.normalized().rotated(Vector3.UP, sin(weave * 0.7) * 1.2)
	want = want.rotated(Vector3.UP, sin(weave * 1.3) * 0.6 * k["turn"])
	ufo_dir = ufo_dir.slerp(want.normalized(), clamp(delta * k["turn"], 0, 1)).normalized()
	var spd: float = k["speed"] * (1.35 if fleeing else 1.0) * (0.6 + 0.4 * clamp(ufo_hp / ufo_max, 0, 1) if not fleeing else 1.0)
	# dodging: jinks sideways when a missile comes or when the jet sits on its tail and aims at it
	ufo_jink_cd -= delta
	var threat := false
	for rk in rockets:
		if (rk["node"] as Node3D).global_position.distance_to(ufo.global_position) < 160.0:
			threat = true
	var to_ufo := (ufo.global_position - tpos)
	var aimed: bool = (tg["fwd"] as Vector3).dot(to_ufo.normalized()) > 0.985 and to_ufo.length() < 500.0
	if ufo_jink_cd <= 0.0 and (threat or (aimed and randf() < delta * 3.0)):
		ufo_jink_cd = randf_range(0.9, 2.0) * (1.6 if kind == "harvester" else 1.0)
		var perp := ufo_dir.cross(Vector3.UP).normalized() * (1.0 if randf() < 0.5 else -1.0)
		ufo_jink = (perp + Vector3(0, randf_range(-0.5, 0.5), 0)).normalized() * spd * (1.6 if kind == "scout" else 1.1)
		# a sharp jink can shake off a missile (small, nimble UFOs much more often)
		var shake: float = {"scout": 0.6, "raider": 0.35, "harvester": 0.15}[kind]
		for rk in rockets:
			if not rk.get("lost", false) and (rk["node"] as Node3D).global_position.distance_to(ufo.global_position) < 160.0 and randf() < shake:
				rk["lost"] = true
				_say("UFO uhnulo střele!", 1.5)
	ufo_jink = ufo_jink.lerp(Vector3.ZERO, clamp(delta * 1.8, 0, 1))
	ufo_vel = ufo_dir * spd + ufo_jink + Vector3(0, sin(weave * 2.1) * 6.0, 0)
	ufo.global_position += ufo_vel * delta
	ufo.global_position.y = clamp(ufo.global_position.y, 700, 1300)
	ufo.rotate_y(delta * (2.0 if kind == "scout" else 0.6))
	# smoke when damaged
	if ufo_hp < ufo_max * 0.5 and randf() < delta * 8.0:
		_puff(ufo.global_position)
	if k["guns"] > 0:
		ufo_fire_cd -= delta
		var d := tpos.distance_to(ufo.global_position)
		if ufo_fire_cd <= 0 and d < 700 and tg["alive"]:
			ufo_fire_cd = randf_range(1.4, 2.2) / sqrt(float(k["guns"])) * (1.6 if kind == "scout" else 1.0)
			# precise lead on the jet's real motion - a break with A/D is how you make it miss
			var jv: Vector3 = tg["vel"]
			var lead := tpos + jv * (d / 300.0)
			var dir := (lead - ufo.global_position).normalized()
			dir = (dir + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.012).normalized()
			if net:
				_bolt.rpc(ufo.global_position + dir * (_ufo_radius() + 2), dir)
			else:
				_bolt(ufo.global_position + dir * (_ufo_radius() + 2), dir)

## The jet the UFO cares about: the nearest one still flying.
func _target() -> Dictionary:
	var best := {"pos": jet.global_position, "vel": -jet.global_transform.basis.z * speed + slide, "fwd": -jet.global_transform.basis.z, "alive": not down and me_pilot}
	var bd := 1e9 if down or not me_pilot else jet.global_position.distance_to(ufo.global_position)
	for pid in others:
		var o: Dictionary = others[pid]
		if o["down"]:
			continue
		var n: Node3D = o["node"]
		var dd := n.global_position.distance_to(ufo.global_position)
		if dd < bd:
			bd = dd
			best = {"pos": n.global_position, "vel": o["vel"], "fwd": -n.global_transform.basis.z, "alive": true}
	return best

# ---- network ---------------------------------------------------------------------------------
func _net_sync(delta: float) -> void:
	_sync_t -= delta
	if _sync_t <= 0.0:
		_sync_t = 0.033
		if me_pilot and not down:
			_jet_state.rpc(jet.global_position, jet.global_transform.basis.get_rotation_quaternion(), -jet.global_transform.basis.z * speed + slide)
		if multiplayer.is_server():
			_ufo_state.rpc(ufo.global_position, ufo.rotation.y, ufo_hp, fleeing)
	# others' jets glide toward their last known place (plus where they were heading)
	for pid in others:
		var o: Dictionary = others[pid]
		var n: Node3D = o["node"]
		if not o["down"]:
			o["pos"] = (o["pos"] as Vector3) + (o["vel"] as Vector3) * delta
			n.global_position = n.global_position.lerp(o["pos"], clampf(delta * 12.0, 0, 1))

@rpc("any_peer", "unreliable_ordered")
func _jet_state(pos: Vector3, rot: Quaternion, vel: Vector3) -> void:
	var pid := multiplayer.get_remote_sender_id()
	if not others.has(pid):
		return
	var o: Dictionary = others[pid]
	o["pos"] = pos
	o["vel"] = vel
	(o["node"] as Node3D).global_transform.basis = Basis(rot)

@rpc("authority", "unreliable_ordered")
func _ufo_state(pos: Vector3, rot_y: float, hp: float, flee: bool) -> void:
	_ufo_goal = pos
	ufo.rotation.y = rot_y
	if hp < ufo_hp and hp < ufo_max * 0.5 and randf() < 0.3:
		_puff(ufo.global_position)
	ufo_hp = hp
	fleeing = flee

## A pilot's hit on the UFO counts on the host.
@rpc("any_peer", "call_local", "reliable")
func _hit_ufo(d: float) -> void:
	if not multiplayer.is_server() or outcome != "":
		return
	ufo_hp -= d
	recent.append([t, d])

## Somebody's Sokol went down.
@rpc("any_peer", "call_local", "reliable")
func _jet_down(pid: int) -> void:
	if others.has(pid):
		others[pid]["down"] = true
		var n: Node3D = others[pid]["node"]
		_flash(n.global_position, 12.0)
		n.visible = false
		_say("%s sestřelen! Pilot se katapultoval." % others[pid]["name"], 3.0)

## The others' guns: only a picture, the damage was counted by the shooter.
@rpc("any_peer", "unreliable")
func _fx_tracer(from: Vector3, dir: Vector3) -> void:
	_tracer(from, dir, true)

@rpc("any_peer", "reliable")
func _fx_missile(from: Vector3, vel: Vector3) -> void:
	_missile_node(from, vel, true)

@rpc("authority", "call_local", "reliable")
func _end_all(o: String) -> void:
	if outcome == "":
		_end(o)

@rpc("authority", "call_local", "reliable")
func _bolt(from: Vector3, dir: Vector3) -> void:
	var n := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.2
	sm.height = 2.4
	sm.radial_segments = 6
	sm.rings = 3
	n.mesh = sm
	n.material_override = Game.color_mat(Color(0.4, 1.0, 0.45), true)
	var l := OmniLight3D.new()
	l.light_color = Color(0.4, 1.0, 0.5)
	l.light_energy = 3.0
	l.omni_range = 18.0
	n.add_child(l)
	add_child(n)
	n.global_position = from
	bolts.append({"node": n, "vel": dir * 300.0, "life": 4.0})
	Game.play_ui(self, "plasma_heavy", -8)

func _puff(p: Vector3) -> void:
	var n := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 2.0
	sm.height = 4.0
	sm.radial_segments = 6
	sm.rings = 3
	n.mesh = sm
	n.material_override = Game.color_mat(Color(0.15, 0.15, 0.17))
	add_child(n)
	n.global_position = p
	var tw := create_tween()
	tw.tween_property(n, "scale", Vector3.ONE * 3.0, 2.0)
	tw.tween_callback(n.queue_free)

# ---- outcome -----------------------------------------------------------------------------------
func _judge() -> void:
	for r in recent.duplicate():
		if t - float(r[0]) > 2.0:
			recent.erase(r)
	if ufo_hp <= 0:
		var burst := 0.0
		for r in recent:
			burst += float(r[1])
		if burst > ufo_max / 3.0:
			_end("destroyed")
		else:
			_end("crashed")
	elif (not net and jet_hp <= 0) or (net and _all_down()):
		_end("shot_down")
	elif fleeing and (_target()["pos"] as Vector3).distance_to(ufo.global_position) > 1500:
		_end("escaped")
	elif t > TIME_LIMIT:
		_end("fuel")

func _all_down() -> bool:
	if me_pilot and not down:
		return false
	for pid in others:
		if not others[pid]["down"]:
			return false
	return true

func _end(o: String) -> void:
	if net and multiplayer.is_server() and outcome == "":
		outcome = o
		_end_all.rpc(o)
		outcome = ""
	outcome = o
	Game.play_ui(self, "explosion", 2)
	match o:
		"destroyed":
			_flash(ufo.global_position, _ufo_radius() * 5.0)
			ufo.visible = false
			_say("UFO ROZPRÁŠENO. Nezbylo nic, co by šlo prozkoumat.", 6.0)
		"crashed":
			_say("UFO PADÁ! Zřítilo se pod mraky. Pozemní tým může vyrazit.", 6.0)
		"shot_down":
			if not net:
				_flash(jet.global_position, 12.0)
				jet.visible = false
			_say("SOKOL SESTŘELEN. Pilot se katapultoval.", 6.0)
		"escaped":
			_say("UFO UNIKLO.", 5.0)
		"fuel":
			_say("Dochází palivo - návrat na základnu.", 5.0)
	print("[AIR] outcome=%s ufo_hp=%.0f/%.0f jet_hp=%.0f ammo=%d missiles=%d t=%.1f" % [o, ufo_hp, ufo_max, jet_hp, ammo, missiles, t])

func _debris(delta: float) -> void:
	if outcome == "crashed":
		ufo.global_position += Vector3(ufo_dir.x * 30, -40, ufo_dir.z * 30) * delta
		ufo.rotate_z(delta * 0.8)
		if randf() < delta * 15:
			_puff(ufo.global_position)

var _finished := false
func _finish() -> void:
	if _finished:
		return
	_finished = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Net.mission_params = {}
	if net and not multiplayer.is_server():
		# a co-op pilot: back to the lobby (or the host's globe view)
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
		return
	var lost := 0
	if net:
		for pid in others:
			if others[pid]["down"]:
				lost += 1
		if down and me_pilot:
			lost += 1
		Net.last_result = Campaign.intercept_done(int(params.get("id", -1)), outcome, kind, jet_hp, lost, 1 if (jet_hp < 60 and not down) else 0)
	else:
		Net.last_result = Campaign.intercept_done(int(params.get("id", -1)), outcome, kind, jet_hp)
	get_tree().change_scene_to_file("res://scenes/Geoscape.tscn")

# ---- HUD ----------------------------------------------------------------------------------------
func _draw_hud() -> void:
	var c := hud
	var sz := c.size
	var mid := sz / 2
	var f := ThemeDB.fallback_font
	var green := Color(0.4, 1.0, 0.5, 0.9)
	var txt := func(p: Vector2, s: String, col := green, size := 9):
		c.draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color(0, 0, 0, 0.7))
		c.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	# gun cross where the nose points, and the stick position
	var nose := cam.unproject_position(jet.global_position - jet.global_transform.basis.z * 300.0)
	c.draw_arc(nose, 7, 0, TAU, 12, green, 1.0)
	c.draw_line(nose + Vector2(-12, 0), nose + Vector2(-8, 0), green)
	c.draw_line(nose + Vector2(8, 0), nose + Vector2(12, 0), green)
	c.draw_circle(mid + aim * 60.0, 2.0, Color(1, 1, 1, 0.6))
	c.draw_arc(mid, 60, 0, TAU, 24, Color(1, 1, 1, 0.12), 1.0)
	# target box
	if ufo.visible and not cam.is_position_behind(ufo.global_position):
		var up := cam.unproject_position(ufo.global_position)
		var s := 14.0
		var col := Color(1, 0.4, 0.3) if lock >= 1.0 else Color(1, 0.8, 0.3)
		c.draw_rect(Rect2(up - Vector2(s, s), Vector2(s * 2, s * 2)), col, false, 1.0)
		if lock > 0 and lock < 1:
			c.draw_arc(up, s + 4, -PI / 2, -PI / 2 + TAU * lock, 16, col, 2.0)
		txt.call(up + Vector2(s + 4, 0), "%d m" % int(jet.global_position.distance_to(ufo.global_position)), col, 8)
	else:
		# arrow to the UFO when off-screen
		var lp: Vector3 = cam.global_transform.basis.inverse() * (ufo.global_position - cam.global_position)
		var d2 := Vector2(lp.x, -lp.y).normalized()
		c.draw_circle(mid + d2 * 120.0, 4.0, Color(1, 0.6, 0.3))
	# wingmen
	for pid in others:
		var on: Node3D = others[pid]["node"]
		if not others[pid]["down"] and on != jet and not cam.is_position_behind(on.global_position):
			var op := cam.unproject_position(on.global_position)
			c.draw_arc(op, 5, 0, TAU, 10, Color(0.5, 0.8, 1.0), 1.0)
			txt.call(op + Vector2(7, 3), String(others[pid]["name"]), Color(0.5, 0.8, 1.0), 7)
	if down and net:
		txt.call(Vector2(mid.x - 120, sz.y - 70), "Tvůj Sokol je dole - sleduješ spoluhráče.", Color(1, 0.6, 0.4), 9)
	# bars
	txt.call(Vector2(10, sz.y - 46), "RYCHLOST %d km/h   PLYN %d %%" % [int(speed * 3.6), int(throttle * 100)])
	txt.call(Vector2(10, sz.y - 34), "VÝŠKA %d m   TRUP %d %%" % [int(jet.global_position.y), int(max(jet_hp, 0))], green if jet_hp > 40 else Color(1, 0.4, 0.3))
	txt.call(Vector2(10, sz.y - 22), "KANÓN %d   RAKETY %d   PALIVO %d s" % [ammo, missiles, int(max(0, TIME_LIMIT - t))])
	var k: Dictionary = UFO_KINDS[kind]
	txt.call(Vector2(sz.x - 210, 18), k["name"], Color(1, 0.8, 0.3), 9)
	c.draw_rect(Rect2(sz.x - 210, 24, 200, 6), Color(0, 0, 0, 0.5))
	c.draw_rect(Rect2(sz.x - 210, 24, 200 * clamp(ufo_hp / ufo_max, 0, 1), 6), Color(1, 0.4, 0.3))
	c.draw_line(Vector2(sz.x - 210, 22), Vector2(sz.x - 210, 32), Color(1, 1, 1, 0.5))
	txt.call(Vector2(sz.x - 210, 44), "Myš řídí, A/D ostrý úhyb, W/S plyn, Shift forsáž", Color(0.7, 0.8, 0.9), 7)
	txt.call(Vector2(sz.x - 210, 54), "L: kanón   P: raketa (po zaměření)", Color(0.7, 0.8, 0.9), 7)
	if msg_t > 0:
		txt.call(Vector2(mid.x - 220, 70), msg, Color(1, 0.85, 0.4), 10)

# ---- test ------------------------------------------------------------------------------------------
func _process(_d: float) -> void:
	if not Game.autotest() in ["air", "campair", "airhost", "airclient"]:
		return
	if down:
		if outcome != "" and end_t > 2.0 and Game.autotest() != "campair":
			get_tree().quit()
		return
	# a crude autopilot: steer at the UFO, cannon when lined up, missiles when locked
	var to := ufo.global_position - jet.global_position
	var lp: Vector3 = jet.global_transform.basis.inverse() * to
	aim = Vector2(clamp(lp.x / 60.0, -1, 1), clamp(lp.y / 60.0, -1, 1))
	_mouse = Vector2.ZERO
	var line := (-jet.global_transform.basis.z).angle_to(to) < deg_to_rad(4)
	if line and to.length() < 600: Input.action_press("fire")
	else: Input.action_release("fire")
	if lock >= 1.0 and missiles > 2: Input.action_press("aim")
	else: Input.action_release("aim")
	for bo in bolts:
		if (bo["node"] as Node3D).global_position.distance_to(jet.global_position) < 140.0 and break_cd <= 0.0:
			_break(-1.0 if randf() < 0.5 else 1.0)
			print("[AIR] uhyb t=%.1f hp=%d" % [t, jet_hp])
	if int(t * 10) == 80 or int(t * 10) == 200:
		get_viewport().get_texture().get_image().save_png("user://40_air_%d.png" % int(t))
	if outcome != "" and end_t > 1.0 and end_t < 1.05:
		get_viewport().get_texture().get_image().save_png("user://41_air_end.png")
	if Game.autotest() in ["air", "airhost", "airclient"] and ((outcome != "" and end_t > 2.0) or t > 100):
		print("[AIR-%s] end outcome=%s ufo_hp=%.0f me_hp=%.0f others=%s" % [Game.autotest(), outcome, ufo_hp, jet_hp, others.keys()])
		get_tree().quit()
