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
	"raider": {"name": "Nájezdník (střední UFO)", "hp": 170.0, "speed": 52.0, "turn": 1.0, "guns": 2, "aliens": 1, "armor": 0.6, "scale": 2.0},
	"harvester": {"name": "Sklízeč (velké UFO)", "hp": 360.0, "speed": 42.0, "turn": 0.6, "guns": 3, "aliens": 3, "armor": 0.35, "scale": 1.8},
	# 0.56: the giants fly too, late in the war - the same hulls you walk round when they land
	"supply": {"name": "Zásobovací loď (obří UFO)", "hp": 520.0, "speed": 36.0, "turn": 0.4, "guns": 3, "aliens": 5, "armor": 0.25, "scale": 1.5},
	"battleship": {"name": "Bitevní loď (obří UFO)", "hp": 640.0, "speed": 32.0, "turn": 0.35, "guns": 5, "aliens": 6, "armor": 0.2, "scale": 1.5},
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
var _alarm: AudioStreamPlayer
var _flyby_cd := 0.0
var ammo := 400
var missiles := 4
# 0.57: the Jestřáb and the weapons fitted in the hangar (Campaign.jet_gun / jet_heavy)
var hawk := false
var gun := "cannon"             # cannon, laser, plasma
var heavy := "missiles"         # missiles, laser_cannon, plasma_cannon
var charge := 0.0               # the heavy gun's charge (laser / plasma cannon), 0..1
var heavy_ammo := 4
const GUN_INFO := {"cannon": {"cd": 0.06, "dmg": 3.0, "armour": 1.0, "color": Color(1.0, 0.8, 0.35), "speed": 900.0, "ammo": 400, "size": 0.15},
	"laser": {"cd": 0.08, "dmg": 3.5, "armour": 0.5, "color": Color(0.75, 0.35, 1.0), "speed": 1600.0, "ammo": -1, "size": 0.12},
	"plasma": {"cd": 0.11, "dmg": 5.0, "armour": 0.35, "color": Color(0.35, 1.0, 0.45), "speed": 700.0, "ammo": 260, "size": 0.35}}
const HEAVY_INFO := {"missiles": {"name": "RAKETY", "ammo": 4},
	"laser_cannon": {"name": "LASER. DĚLO", "ammo": -1, "charge": 1.2, "cd": 2.5, "dmg": 45.0},
	"plasma_cannon": {"name": "PLAZM. DĚLO", "ammo": 5, "charge": 0.8, "cd": 1.6, "dmg": 90.0}}
var cannon_cd := 0.0
const MG_PER_MAG := 65         # plasma machine gun shots out of one PL-MAG-01
const PC_PER_MAG := 2          # plasma cannon shots out of one
var ammo0 := 0
var heavy0 := 0
## How many magazines this flight burnt (the host takes them off the armory).
func plasma_mags_used() -> int:
	var n := 0
	if gun == "plasma":
		n += ceili(float(ammo0 - maxi(ammo, 0)) / MG_PER_MAG)
	if heavy == "plasma_cannon":
		n += ceili(float(heavy0 - maxi(heavy_ammo, 0)) / PC_PER_MAG)
	return n
# X-AIR-003: the laser machine gun fires from an energy reserve; shot dry it charges all the way
var cell := 1.0
var cell_dry := false
var cell_idle := 0.0
const CELL_SHOTS := 45.0
const CELL_CHARGE := 0.3      # of the reserve per second
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


## X-AIR-002/003: the laser pods hang under the wings (the machine gun inside, the cannon outside).
func _fit_pods(node: Node3D, is_hawk := false) -> void:
	if gun != "laser" and heavy != "laser_cannon":
		return
	var box := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var bb: AABB = (mi as MeshInstance3D).get_aabb()
		bb = node.global_transform.affine_inverse() * (mi as MeshInstance3D).global_transform * bb
		box = bb if first else box.merge(bb)
		first = false
	var span := box.size.x * 0.5
	var len := box.size.z
	for e in [["jet_laser_mg", 0.3, 0.17], ["jet_laser_cannon", 0.52, 0.23]]:
		# (the Jestřáb's own belly pods take whichever gun is fitted)
		if (e[0] == "jet_laser_mg" and (gun != "laser" or is_hawk)) or (e[0] == "jet_laser_cannon" and heavy != "laser_cannon"):
			continue
		for sx in [-1.0, 1.0]:
			var pod := Game.model(e[0])
			node.add_child(pod)
			pod.scale = Vector3.ONE * len * float(e[2])
			pod.position = Vector3(box.get_center().x + sx * span * float(e[1]), box.position.y + box.size.y * 0.36, box.get_center().z - len * 0.05)

## X-AIR-001: alloy plates in our hulls - every hit takes a quarter less (a third more hits to go down).
func armor_k() -> float:
	return 0.75 if params.get("jet_armor", false) else 1.0

func _ready() -> void:
	Game.play_music("interception")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	params = Net.mission_params
	kind = params.get("ufo", "raider")
	var k: Dictionary = UFO_KINDS[kind]
	ufo_hp = k["hp"]
	ufo_max = k["hp"]
	if kind == "battleship":
		field = FIELD_MAX
	_world()
	gun = String(params.get("gun", Game.cmd_arg("gun", "cannon")))
	heavy = String(params.get("heavy", Game.cmd_arg("heavy", "missiles")))
	if not GUN_INFO.has(gun): gun = "cannon"
	if not HEAVY_INFO.has(heavy): heavy = "missiles"
	# X-WEP-007: the plasma guns feed on the base's PL-MAG-01 magazines (in the fighters' supply modules)
	var mags := int(params.get("plasma_mags", 99))
	if gun == "plasma" and mags <= 0: gun = "cannon"
	ammo = int(GUN_INFO[gun]["ammo"])
	if gun == "plasma":
		ammo = mini(ammo, mags * MG_PER_MAG)
		mags -= ceili(float(ammo) / MG_PER_MAG)
	if heavy == "plasma_cannon" and mags <= 0: heavy = "missiles"
	heavy_ammo = int(HEAVY_INFO[heavy]["ammo"])
	if heavy == "plasma_cannon":
		heavy_ammo = mini(heavy_ammo, mags * PC_PER_MAG)
	ammo0 = ammo
	heavy0 = heavy_ammo
	missiles = heavy_ammo if heavy == "missiles" else 0
	var n_hawks := int(params.get("hawks", int(Game.cmd_arg("hawks", "0"))))
	net = Net.is_online() and params.has("pilots")
	if net:
		pilots = params["pilots"]
		me_pilot = Net.my_id() in pilots
	for i in pilots.size():
		var pid: int = pilots[i]
		var node := Game.model("jestrab" if i < n_hawks else "sokol")
		add_child(node)
		_fit_pods(node, i < n_hawks)
		node.position = Vector3((i - (pilots.size() - 1) / 2.0) * 40.0, 900 + i * 6.0, i * 15.0)
		if pid == Net.my_id() or not net:
			jet = node
			hawk = i < n_hawks
			if hawk:
				jet_hp = 160.0
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
	music.stream = Game.loop_stream("wind")
	var jet_snd := AudioStreamPlayer.new()
	jet_snd.stream = Game.loop_stream("jet_engine")
	jet_snd.volume_db = -9
	jet_snd.bus = "SFX"
	add_child(jet_snd)
	jet_snd.play()
	music.volume_db = -6
	music.bus = "Wind"
	add_child(music)
	music.play()
	_say("KONTAKT: %s. Přivést k zemi poškozené = posádka a kořist. Rozstřílet = nic." % k["name"], 6.0)

## 0.57: the sky over the fight, in our style: a painted gradient with stars, the moon (or the sun by day),
## a deck of soft clouds lit from that side, and far below the Earth - land and sea in big pixels,
## fields and, at night, the lights of towns - curving away towards the horizon.
var night := true
const EARTH_R := 60000.0          # exaggerated: the curve shows from a fighter's height
func _world() -> void:
	night = bool(params.get("night", Game.cmd_arg("day", "0") != "1"))
	var sky_top := Color(0.012, 0.018, 0.06) if night else Color(0.16, 0.33, 0.62)
	var sky_hor := Color(0.1, 0.09, 0.2) if night else Color(0.66, 0.74, 0.84)
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var ssh := Shader.new()
	ssh.code = """shader_type sky;
uniform vec3 top_col;
uniform vec3 hor_col;
uniform vec3 low_col;
uniform bool night_sky;
float h3(vec3 p){ return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
void sky(){
	float y = EYEDIR.y;
	vec3 col = mix(hor_col, top_col, smoothstep(-0.02, 0.55, y));
	col = mix(col, low_col, smoothstep(0.0, -0.25, y));
	// a band of light along the horizon
	col += hor_col * 0.35 * exp(-abs(y) * 18.0);
	vec3 L = normalize(LIGHT0_DIRECTION);
	float d = dot(EYEDIR, L);
	if (night_sky) {
		vec3 cell = floor(EYEDIR * 260.0);
		float st = h3(cell);
		if (st > 0.9975 && y > 0.0) {
			float tw = 0.55 + 0.45 * fract(st * 917.0);       // fixed brightness: a sky that never redraws itself
			col += vec3(0.8, 0.85, 1.0) * tw * smoothstep(0.0, 0.15, y);
		}
		col += vec3(0.85, 0.88, 1.0) * smoothstep(0.9993, 0.9996, d);          // the moon
		col += vec3(0.25, 0.27, 0.4) * pow(max(d, 0.0), 300.0);                 // its halo
	} else {
		col += vec3(1.0, 0.95, 0.8) * smoothstep(0.9990, 0.9994, d) * 2.0;      // the sun
		col += vec3(0.5, 0.42, 0.3) * pow(max(d, 0.0), 120.0);
	}
	COLOR = col;
}"""
	var smat := ShaderMaterial.new()
	smat.shader = ssh
	smat.set_shader_parameter("top_col", sky_top)
	smat.set_shader_parameter("hor_col", sky_hor)
	smat.set_shader_parameter("low_col", sky_hor.darkened(0.5))
	smat.set_shader_parameter("night_sky", night)
	sky.sky_material = smat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	env.sky = sky
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.25, 0.42) if night else Color(0.6, 0.66, 0.75)
	env.ambient_light_energy = 0.55 if night else 0.7
	env.fog_enabled = true
	env.fog_light_color = sky_hor
	env.fog_density = 0.00032
	env.fog_sky_affect = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.7, 0.75, 1.0) if night else Color(1.0, 0.96, 0.88)
	moon.light_energy = 0.6 if night else 1.3
	moon.rotation_degrees = Vector3(-24, 35, 0) if night else Vector3(-38, 120, 0)
	add_child(moon)
	# far below: the Earth (follows the camera, its pattern is fixed in the world)
	var earth := MeshInstance3D.new()
	var em := PlaneMesh.new()
	em.size = Vector2(16000, 16000)
	em.subdivide_width = 48
	em.subdivide_depth = 48
	earth.mesh = em
	var esh := Shader.new()
	esh.code = """shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform bool night_land;
uniform float earth_r;
float h(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p){ vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
 return mix(mix(h(i), h(i+vec2(1,0)), f.x), mix(h(i+vec2(0,1)), h(i+vec2(1,1)), f.x), f.y); }
float fbm(vec2 p){ return n(p) * 0.5 + n(p * 2.1) * 0.25 + n(p * 4.3) * 0.15 + n(p * 9.1) * 0.1; }
varying vec3 wp;
void vertex(){
	VERTEX.y -= dot(VERTEX.xz, VERTEX.xz) / (2.0 * earth_r);
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment(){
	vec2 px = floor(wp.xz / 48.0) * 48.0;                 // big pixels
	float land = fbm(px * 0.00022 + vec2(17.0, 3.0));
	float fields = h(floor(px / 192.0));
	vec3 sea = night_land ? vec3(0.02, 0.04, 0.08) : vec3(0.08, 0.2, 0.32);
	vec3 shore = night_land ? vec3(0.03, 0.06, 0.09) : vec3(0.16, 0.32, 0.4);
	vec3 green = night_land ? vec3(0.03, 0.05, 0.035) : vec3(0.2, 0.32, 0.14);
	vec3 brown = night_land ? vec3(0.05, 0.045, 0.035) : vec3(0.38, 0.33, 0.2);
	vec3 forest = night_land ? vec3(0.02, 0.035, 0.025) : vec3(0.1, 0.2, 0.1);
	vec3 col = sea;
	if (land > 0.47) col = shore;
	if (land > 0.5) {
		col = mix(green, brown, step(0.62, fields));
		col = mix(col, forest, step(0.72, fbm(px * 0.0011)));
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
	if (night_land && land > 0.5) {
		float town = h(floor(px / 96.0) + 3.1);
		float big = step(0.66, fbm(px * 0.0007 + 9.0));
		if (town > 0.985 - big * 0.06) EMISSION = vec3(1.0, 0.62, 0.25) * (0.8 + town);
	}
}"""
	var emat := ShaderMaterial.new()
	emat.shader = esh
	emat.set_shader_parameter("night_land", night)
	emat.set_shader_parameter("earth_r", EARTH_R)
	earth.material_override = emat
	earth.name = "Earth"
	add_child(earth)
	# the cloud deck: soft, in a few bands of light, lit from the moon's / sun's side
	var clouds := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12000, 12000)
	pm.subdivide_width = 40
	pm.subdivide_depth = 40
	clouds.mesh = pm
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform float time_s;
uniform float earth_r;
uniform vec3 lit_col;
uniform vec3 dark_col;
uniform vec2 light_xz;
float h(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p){ vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
 return mix(mix(h(i), h(i+vec2(1,0)), f.x), mix(h(i+vec2(0,1)), h(i+vec2(1,1)), f.x), f.y); }
float fbm(vec2 p){ return n(p) * 0.5 + n(p * 2.3) * 0.28 + n(p * 5.1) * 0.14 + n(p * 11.0) * 0.08; }
varying vec3 wp;
void vertex(){
	VERTEX.y -= dot(VERTEX.xz, VERTEX.xz) / (2.0 * earth_r);
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment(){
	vec2 p = wp.xz * 0.0028 + vec2(time_s * 0.012, 0.0);
	float v = fbm(p);
	// the side towards the light is brighter: sample a little towards it
	float v2 = fbm(p + light_xz * 0.06);
	float shade = clamp((v - v2) * 6.0 + 0.5, 0.0, 1.0);
	shade = floor(shade * 3.0 + 0.5) / 3.0;              // a few bands, painted
	ALBEDO = mix(dark_col, lit_col, shade);
	float d = length(wp.xz - CAMERA_POSITION_WORLD.xz);
	ALPHA = smoothstep(0.42, 0.62, v) * 0.92 * (1.0 - smoothstep(3000.0, 5800.0, d));
}"""
	var cm := ShaderMaterial.new()
	cm.shader = sh
	cm.set_shader_parameter("earth_r", EARTH_R)
	cm.set_shader_parameter("lit_col", Color(0.42, 0.44, 0.58) if night else Color(0.97, 0.97, 0.98))
	cm.set_shader_parameter("dark_col", Color(0.1, 0.11, 0.18) if night else Color(0.58, 0.63, 0.74))
	var ld := -moon.global_transform.basis.z if moon.is_inside_tree() else Vector3(0.5, 0, 0.5)
	cm.set_shader_parameter("light_xz", Vector2(ld.x, ld.z).normalized())
	clouds.material_override = cm
	clouds.position.y = 600
	clouds.name = "Clouds"
	add_child(clouds)

## The ground and the clouds go along under the camera (their pattern stays put in the world).
func _sky_follow() -> void:
	(get_node("Clouds").material_override as ShaderMaterial).set_shader_parameter("time_s", t)
	var cp := cam.global_position
	(get_node("Clouds") as Node3D).position = Vector3(cp.x, 600.0, cp.z)
	(get_node("Earth") as Node3D).position = Vector3(cp.x, 0.0, cp.z)

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
	# the saucer whooshing past close
	_flyby_cd -= delta
	if _flyby_cd <= 0.0 and outcome == "" and is_instance_valid(ufo) and ufo.visible and jet \
			and ufo.global_position.distance_to(jet.global_position) < 110.0:
		_flyby_cd = 7.0
		Game.play_ui(self, "jet_flyby", -4)
	_sky_follow()
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
	var target_speed := 50.0 + throttle * 60.0 + (40.0 if boost else 0.0) + (25.0 if hawk else 0.0)
	var agile := 1.35 if hawk else 1.0       # the gravity drive: sharper turns
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
	jet.rotate_object_local(Vector3.RIGHT, aim.y * 1.8 * agile * delta)
	jet.rotate_object_local(Vector3.UP, (-aim.x * 1.2 - roll_in * 0.9) * agile * delta)
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
	if heavy == "missiles" and ang < deg_to_rad(12) and dist < 900 and missiles > 0:
		if lock < 1.0 and lock + delta / 1.5 >= 1.0:
			Game.play_ui(self, "missile_lock", -4)
		lock = min(1.0, lock + delta / 1.5)
	else:
		lock = max(0.0, lock - delta * 2.0)
	var gi: Dictionary = GUN_INFO[gun]
	if gun == "laser":
		cell_idle += delta
		if cell_idle > 0.6 or cell_dry:
			cell = minf(1.0, cell + CELL_CHARGE * delta)
			if cell >= 1.0 and cell_dry:
				cell_dry = false
				Game.play_ui(self, "ping", -12)
	var dry := gun == "laser" and cell_dry
	if Input.is_action_just_pressed("fire") and dry:
		Game.play_ui(self, "empty", -6)
	if Input.is_action_pressed("fire") and cannon_cd <= 0 and ammo != 0 and not dry:
		cannon_cd = float(gi["cd"])
		if gun == "laser":
			cell_idle = 0.0
			cell -= 1.0 / CELL_SHOTS
			if cell <= 0.0:
				cell = 0.0
				cell_dry = true
		if ammo > 0:
			ammo -= 1
		var spread := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * (0.012 if gun == "cannon" else 0.006)
		var d := (fwd + spread).normalized()
		# the Jestřáb fires from both pods under the belly, the Sokol from the nose
		var muzzles := [jet.global_position + fwd * 5.0 + jet.global_transform.basis.y * -0.3]
		if hawk:
			muzzles = [jet.global_position + fwd * 3.6 + jet.global_transform.basis.x * 0.62 - jet.global_transform.basis.y * 0.48,
				jet.global_position + fwd * 3.6 - jet.global_transform.basis.x * 0.62 - jet.global_transform.basis.y * 0.48]
		# the pods take turns (twice the noise, not twice the damage)
		var mz: Vector3 = muzzles[_shots % muzzles.size()]
		_tracer(mz, d, false, gun)
		_shots += 1
		if net and _shots % 3 == 0:
			_fx_shot.rpc(mz, d, gun)
		if _shots % 3 == 0:
			Game.play_ui(self, {"cannon": "cannon_jet", "laser": "laser", "plasma": "plasma"}.get(gun, "cannon_jet"), -8)
	var heavy_btn := Input.is_action_pressed("aim") or Input.is_action_pressed("reload")
	if heavy == "missiles":
		if (Input.is_action_just_pressed("aim") or Input.is_action_just_pressed("reload")) and missile_cd <= 0:
			if missiles <= 0:
				_say("Rakety došly.", 1.5)
			elif lock < 1.0:
				_say("Raketa nemá zaměřeno - drž UFO ve středu.", 1.5)
			else:
				missiles -= 1
				missile_cd = 1.0
				_fire_missile()
		return
	# laser / plasma cannon: hold the button - it charges - and it fires by itself when full
	var hi: Dictionary = HEAVY_INFO[heavy]
	if heavy_btn and missile_cd <= 0 and heavy_ammo != 0:
		if charge == 0.0:
			Game.play_ui(self, "laser_charge", -6)
		charge = minf(1.0, charge + delta / float(hi["charge"]))
		if charge >= 1.0:
			charge = 0.0
			missile_cd = float(hi["cd"])
			if heavy_ammo > 0:
				heavy_ammo -= 1
			_fire_heavy(jet.global_position + fwd * 4.0 - jet.global_transform.basis.y * 0.5, fwd, false)
	else:
		charge = maxf(0.0, charge - delta * 2.0)
		if Input.is_action_just_pressed("aim") and heavy_ammo == 0:
			_say("Plazmové dělo je prázdné.", 1.5)

## The heavy shot: the laser cannon is a beam (hits at once along the line), the plasma cannon a big
## green ball that flies (and hits whatever its line crosses).
func _fire_heavy(from: Vector3, dir: Vector3, fake: bool) -> void:
	var hi: Dictionary = HEAVY_INFO[heavy]
	if heavy == "laser_cannon":
		Game.play_ui(self, "laser", 0)
		var end := from + dir * 1600.0
		if _seg_hits(from, end, ufo.global_position, _ufo_radius()):
			end = from + dir * from.distance_to(ufo.global_position)
			if not fake:
				_damage_ufo(float(hi["dmg"]) * lerpf(float(UFO_KINDS[kind]["armor"]), 1.0, 0.7), end)
			_flash(end, 8.0)
		var beam := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var blen := from.distance_to(end)
		bm.size = Vector3(0.6, 0.6, blen)
		beam.mesh = bm
		beam.material_override = Game.color_mat(Color(0.8, 0.4, 1.0), true)
		add_child(beam)
		beam.global_position = (from + end) / 2.0
		beam.look_at(end, Vector3.UP)
		var tw := create_tween()
		tw.tween_property(beam, "scale", Vector3(0.05, 0.05, 1.0), 0.35)
		tw.tween_callback(beam.queue_free)
	else:
		Game.play_ui(self, "plasma_cannon", -2)
		var n := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.6
		sm.height = 3.2
		sm.radial_segments = 10
		sm.rings = 5
		n.mesh = sm
		n.material_override = Game.color_mat(Color(0.35, 1.0, 0.4), true)
		var l := OmniLight3D.new()
		l.light_color = Color(0.4, 1.0, 0.5)
		l.light_energy = 5.0
		l.omni_range = 30.0
		n.add_child(l)
		add_child(n)
		n.global_position = from
		tracers.append({"node": n, "vel": dir * 600.0 - jet.global_transform.basis.z * speed * 0.0, "life": 3.0, "fake": fake,
			"dmg": float(hi["dmg"]), "armour": 0.0, "big": true})
	if net and not fake:
		_fx_heavy.rpc(from, dir, heavy)

func _tracer(from: Vector3, dir: Vector3, fake := false, g := "cannon") -> void:
	var gi: Dictionary = GUN_INFO.get(g, GUN_INFO["cannon"])
	var n := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var sz := float(gi["size"])
	bm.size = Vector3(sz, sz, 6.0 if g != "laser" else 10.0)
	n.mesh = bm
	n.material_override = Game.color_mat(gi["color"], true)
	add_child(n)
	n.global_position = from
	n.look_at(from + dir, Vector3.UP)
	tracers.append({"node": n, "vel": dir * float(gi["speed"]) + (dir * 120.0 if fake else -jet.global_transform.basis.z * speed), "life": 1.2, "fake": fake,
		"dmg": float(gi["dmg"]), "armour": float(gi["armour"])})

func _fire_missile() -> void:
	Game.play_ui(self, "missile_launch", -2)
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
			# cannon shells barely scratch the armour of the big ones; laser and plasma care less
			if not tr.get("fake", false):
				var arm := lerpf(1.0, float(UFO_KINDS[kind]["armor"]), float(tr.get("armour", 1.0)))
				_damage_ufo(float(tr.get("dmg", CANNON_DMG)) * arm, n.global_position)
			if tr.get("big", false):
				_flash(n.global_position, 14.0)
				Game.play_ui(self, "explosion", -2)
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
			jet_hp -= 9.0 * (1.5 if kind in ["supply", "battleship"] else 1.0) * armor_k()      # (their heavy plasma cannons)
			if jet_hp <= 0 and net:
				down = true
				jet.visible = false
				_flash(jet.global_position, 12.0)
				_say("SOKOL SESTŘELEN. Pilot se katapultoval - díváš se z křídla ostatních.", 5.0)
				_jet_down.rpc(Net.my_id())
			_say("ZÁSAH! Trup %d %%" % int(max(jet_hp, 0)), 1.5)
			if jet_hp < 35.0 and jet_hp > 0.0 and _alarm == null:
				_alarm = AudioStreamPlayer.new()
				_alarm.stream = Game.loop_stream("warning_alarm")
				_alarm.volume_db = -10
				_alarm.bus = "SFX"
				add_child(_alarm)
				_alarm.play()
			_flash(n.global_position, 8.0)
			Game.play_ui(self, "hit", 0)
			bo["life"] = 0
		n.global_position = nxt
		if bo["life"] <= 0:
			n.queue_free()
			bolts.erase(bo)

func _ufo_radius() -> float:
	return {"scout": 4.5, "raider": 8.0, "harvester": 14.0, "supply": 22.0, "battleship": 22.0}[kind] * float(UFO_KINDS[kind]["scale"])

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

## Analýza UFO - Bitevní loď: an active field round the hull eats the hits first; it weakens
## under steady fire and comes back when the guns stop for a few seconds.
const FIELD_MAX := 160.0
var field := 0.0
var _field_hit_t := -99.0
func _field_absorb(d: float) -> float:
	if field <= 0.0:
		return d
	_field_hit_t = t
	var took := minf(field, d * 0.85)
	field -= took
	return d - took

func _field_tick(delta: float) -> void:
	if kind == "battleship" and t - _field_hit_t > 3.0:
		field = minf(FIELD_MAX, field + 12.0 * delta)

func _damage_ufo(d: float, at: Vector3) -> void:
	if kind == "battleship" and field > 0.0:
		var l := OmniLight3D.new()
		l.light_color = Color(0.45, 0.7, 1.0)
		l.light_energy = 6.0
		l.omni_range = 9.0
		add_child(l)
		l.global_position = at
		get_tree().create_timer(0.12).timeout.connect(l.queue_free)
	if net:
		_hit_ufo.rpc_id(1, d)
	else:
		ufo_hp -= _field_absorb(d)
		recent.append([t, d])
	if randf() < 0.3:
		_flash(at, 2.0)

# ---- UFO: weaves, turns away from the jet, fires if armed, flees when hurt ----------------
func _ufo_ai(delta: float) -> void:
	var k: Dictionary = UFO_KINDS[kind]
	_field_tick(delta)
	# (a Průzkumník runs as soon as it is hurt; a Nájezdník does not shy away from a fight)
	if not fleeing and ufo_hp < ufo_max * (0.3 if kind == "raider" else 0.5):
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
		ufo_jink_cd = randf_range(0.9, 2.0) * (1.6 if kind in ["harvester", "supply", "battleship"] else 1.0)
		var perp := ufo_dir.cross(Vector3.UP).normalized() * (1.0 if randf() < 0.5 else -1.0)
		ufo_jink = (perp + Vector3(0, randf_range(-0.5, 0.5), 0)).normalized() * spd * (1.6 if kind == "scout" else 1.1)
		# a sharp jink can shake off a missile (small, nimble UFOs much more often)
		var shake: float = {"scout": 0.6, "raider": 0.35, "harvester": 0.15}.get(kind, 0.08)
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
	ufo_hp -= _field_absorb(d)
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

@rpc("any_peer", "unreliable")
func _fx_shot(from: Vector3, dir: Vector3, g: String) -> void:
	_tracer(from, dir, true, g)

@rpc("any_peer", "reliable")
func _fx_heavy(from: Vector3, dir: Vector3, h: String) -> void:
	var keep := heavy
	heavy = h
	_fire_heavy(from, dir, true)
	heavy = keep

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
	if _alarm:
		_alarm.stop()
	if o == "crashed":
		Game.play_ui(self, "ufo_crash", -2)
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
	print("[AIR] outcome=%s ufo_hp=%.0f/%.0f jet_hp=%.0f ammo=%d missiles=%d heavy=%s/%d hawk=%s gun=%s t=%.1f" % [o, ufo_hp, ufo_max, jet_hp, ammo, missiles, heavy, heavy_ammo, hawk, gun, t])

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
	Campaign.spend_plasma_mags(plasma_mags_used())
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
		_msg_plate(c, Vector2(mid.x, sz.y - 76), "Tvoje stíhačka je dole - sleduješ spoluhráče.", Color(1, 0.6, 0.4))
	# 0.57: the panels on plates of the menus' metal (UiSkin), as in the ground HUD
	var lab := Color(0.45, 0.78, 0.86)
	var val := Color(0.84, 0.89, 0.92)
	var amber := Color(1.0, 0.74, 0.32)
	var bad := Color(1, 0.4, 0.3)
	# flight, bottom left
	_hplate(c, Rect2(4, sz.y - 60, 200, 56))
	txt.call(Vector2(12, sz.y - 46), "RYCHLOST", lab, 8)
	txt.call(Vector2(66, sz.y - 46), "%d km/h" % int(speed * 3.6), val, 9)
	txt.call(Vector2(122, sz.y - 46), "PLYN", lab, 8)
	_hbar(c, Rect2(150, sz.y - 53, 46, 6), throttle, Color(0.3, 0.6, 0.9))
	txt.call(Vector2(12, sz.y - 32), "VÝŠKA", lab, 8)
	txt.call(Vector2(66, sz.y - 32), "%d m" % int(jet.global_position.y), val, 9)
	txt.call(Vector2(12, sz.y - 16), "TRUP", lab, 8)
	var hp_max := 160.0 if hawk else 100.0
	_hbar(c, Rect2(66, sz.y - 23, 130, 7), maxf(jet_hp, 0.0) / hp_max, Color(0.8, 0.15, 0.12) if jet_hp < 40 else Color(0.35, 0.8, 0.45))
	# weapons, bottom right
	var gname: String = {"cannon": "KANÓN", "laser": "LASER", "plasma": "PLAZMA"}[gun]
	var hn: String = HEAVY_INFO[heavy]["name"]
	var hcount := missiles if heavy == "missiles" else heavy_ammo
	_hplate(c, Rect2(sz.x - 204, sz.y - 60, 200, 56))
	txt.call(Vector2(sz.x - 196, sz.y - 46), gname, lab, 8)
	if gun == "laser":
		txt.call(Vector2(sz.x - 120, sz.y - 46), "nabíjí se" if cell_dry else "rezerva", amber if not cell_dry else bad, 9)
		_hbar(c, Rect2(sz.x - 60, sz.y - 53, 50, 6), cell, Color(0.8, 0.4, 1.0) if not cell_dry else bad)
	else:
		txt.call(Vector2(sz.x - 120, sz.y - 46), str(ammo) if ammo >= 0 else "neomezeně", amber, 9)
	txt.call(Vector2(sz.x - 196, sz.y - 32), hn, lab, 8)
	txt.call(Vector2(sz.x - 120, sz.y - 32), str(hcount) if hcount >= 0 else "nabíjí se", amber, 9)
	if heavy == "missiles":
		_hbar(c, Rect2(sz.x - 60, sz.y - 39, 50, 6), lock, bad if lock >= 1.0 else amber)
	elif charge > 0.0 or missile_cd > 0.0:
		_hbar(c, Rect2(sz.x - 60, sz.y - 39, 50, 6), charge if charge > 0.0 else 1.0 - clampf(missile_cd / float(HEAVY_INFO[heavy]["cd"]), 0.0, 1.0),
			Color(0.8, 0.4, 1.0) if heavy == "laser_cannon" else Color(0.4, 1.0, 0.5))
	var fuel := maxf(0, TIME_LIMIT - t)
	txt.call(Vector2(sz.x - 196, sz.y - 16), "PALIVO", lab, 8)
	_hbar(c, Rect2(sz.x - 120, sz.y - 23, 110, 7), fuel / TIME_LIMIT, amber if fuel > 30 else bad)
	if charge > 0.0:
		c.draw_rect(Rect2(mid.x - 60, mid.y + 40, 120, 6), Color(0, 0, 0, 0.5))
		c.draw_rect(Rect2(mid.x - 60, mid.y + 40, 120 * charge, 6), Color(0.8, 0.4, 1.0) if heavy == "laser_cannon" else Color(0.4, 1.0, 0.5))
	# the target and how to fly, top right
	var k: Dictionary = UFO_KINDS[kind]
	_hplate(c, Rect2(sz.x - 218, 4, 214, 62))
	txt.call(Vector2(sz.x - 210, 18), k["name"], amber, 9)
	_hbar(c, Rect2(sz.x - 210, 24, 198, 7), ufo_hp / ufo_max, bad)
	txt.call(Vector2(sz.x - 210, 44), "Myš řídí, A/D ostrý úhyb, W/S plyn, Shift forsáž", lab, 7)
	txt.call(Vector2(sz.x - 210, 56), "L: %s   P: %s" % [{"cannon": "kanón", "laser": "laser", "plasma": "plazma"}[gun],
		"raketa (po zaměření)" if heavy == "missiles" else "držet = nabít a vypálit"], lab, 7)
	if msg_t > 0:
		_msg_plate(c, Vector2(mid.x, 66), msg, amber)

## A plate of the menus' dark metal behind a group of the HUD.
func _hplate(c: Control, r: Rect2) -> void:
	UiSkin.inset(4).draw(c.get_canvas_item(), r)

## A bar as in the ground HUD: a dark well, the fill with a sheen, tenths, a thin cyan frame.
func _hbar(c: Control, r: Rect2, v: float, col: Color) -> void:
	c.draw_rect(r, Color(0.01, 0.015, 0.02, 0.8))
	var fill := Rect2(r.position, Vector2(r.size.x * clampf(v, 0.0, 1.0), r.size.y))
	c.draw_rect(fill, col)
	c.draw_rect(Rect2(fill.position, Vector2(fill.size.x, 2)), col.lightened(0.35))
	for k in range(1, 10):
		var x := r.position.x + r.size.x * k / 10.0
		c.draw_line(Vector2(x, r.position.y + 1), Vector2(x, r.end.y - 1), Color(0, 0, 0, 0.45), 1.0)
	c.draw_rect(r, Color(0.45, 0.78, 0.86, 0.6), false, 1.0)

## A message in the middle: on a plate that fits the text.
func _msg_plate(c: Control, centre: Vector2, s: String, col: Color, size := 10) -> void:
	var f := ThemeDB.fallback_font
	var w := minf(f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x, c.size.x - 40)
	_hplate(c, Rect2(centre.x - w / 2 - 10, centre.y - size - 5, w + 20, size + 12))
	c.draw_string(f, Vector2(centre.x - w / 2, centre.y), s, HORIZONTAL_ALIGNMENT_LEFT, w + 4, size, col)

# ---- test ------------------------------------------------------------------------------------------
var _shot_done := {}
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
	if heavy == "missiles":
		if lock >= 1.0 and missiles > 2: Input.action_press("aim")
		else: Input.action_release("aim")
	elif line and to.length() < 900: Input.action_press("aim")
	else: Input.action_release("aim")
	for bo in bolts:
		if (bo["node"] as Node3D).global_position.distance_to(jet.global_position) < 140.0 and break_cd <= 0.0:
			_break(-1.0 if randf() < 0.5 else 1.0)
			print("[AIR] uhyb t=%.1f hp=%d" % [t, jet_hp])
	for st in [5, 8, 20]:
		if t >= st and not _shot_done.has(st):
			_shot_done[st] = true
			get_viewport().get_texture().get_image().save_png("user://40_air_%d.png" % st)
	if outcome != "" and end_t > 1.0 and end_t < 1.05:
		get_viewport().get_texture().get_image().save_png("user://41_air_end.png")
	if Game.autotest() in ["air", "airhost", "airclient"] and ((outcome != "" and end_t > 2.0) or t > 100):
		print("[AIR-%s] end outcome=%s ufo_hp=%.0f me_hp=%.0f others=%s" % [Game.autotest(), outcome, ufo_hp, jet_hp, others.keys()])
		get_tree().quit()
