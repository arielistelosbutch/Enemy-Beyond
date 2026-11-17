extends Node
## Nápady z deště (2026-11-17, Ari: „líbí se mi všechno…“) – počasí, které žije s misí:
##  - změna počasí během mise (začne pršet, zvedne se mlha, bouřka přejde, mlha opadne): hostitel
##    ji vyhlásí (Mission._weather_shift, rpc), každý počítač ji pak sám plynule prolne (světlo, mlha,
##    vítr, déšť a jeho zvuk);
##  - mokro: po dešti (nebo když pršelo před misí) je asfalt, hlína a střechy tmavší a na zemi pod
##    otevřeným nebem stojí louže (odráží lampy, v dešti se na nich dělají kroužky); pomalu osychá;
##  - vítr: jeden směr na misi (ze seedu, všude stejný), sílu dává počasí – nese kouř granátů a ohně,
##    plamen se kloní a oheň se šíří víc po větru (to rozhoduje hostitel);
##  - stopy vetřelců v blátě (mokrá hlína a tráva) a ve sněhu – jen to, co by bylo vidět, žádné značky;
##  - mířidla v dešti: kapky na sklíčku kolimátoru a optiky, po vstupu z chladu pod střechu se sklo
##    na chvíli zamlží (kreslí HUD přes okénko mířidla, Hud._lens_fx).
## Vše kromě vyhlášení změny počasí a šíření ohně si počítá každý počítač sám ze stejných dat.

var m: Node                      # the mission
var wet := 0.0                   # 0 dry .. 1 soaked
var wind := Vector3.ZERO         # where the wind blows (horizontal, length = strength)
var wind_dir := Vector3.FORWARD
var shift_at := -1.0             # host: mission time of the weather change (-1 none)
var shift_to := ""
var puddles: Node3D
var _pud_mat: ShaderMaterial
var _wet_mats := []              # [[material, k]]
var _wet_shown := -1.0
var _blend := {}                 # the weather change being faded in
var _rain_gain := 0.0            # dB added to the rain sound (fades in/out with a change)
var raw_env := {}                # the environment before the weather was applied (Mission._environment)

const WET_TEX := {"asphalt": 1.0, "dirt": 0.75, "earth": 0.75, "scorch": 0.7, "roof": 0.6, "grass": 0.35, "hay": 0.4}
const DRY_TIME := 1500.0         # s from soaked to dry (it does not dry in one mission - only a little)
const SOAK_TIME := 80.0          # s of rain to soak it
const SHIFTS := {"clear": ["fog", "overcast"], "overcast": ["rain", "fog", "rain"], "rain": ["fog", "overcast"],
	"storm": ["rain"], "fog": ["clear", "overcast"], "snow": ["overcast"]}
const BLEND_TIME := 50.0

func setup(mission: Node) -> void:
	m = mission
	name = "WeatherFx"
	var r := RandomNumberGenerator.new()
	r.seed = Net.mission_seed * 53 + 11
	wind_dir = Vector3.FORWARD.rotated(Vector3.UP, r.randf() * TAU)
	var w: String = m.weather
	var terr := String(Net.mission_params.get("terrain", m.map.get("terrain", "")))
	var open := changeable()
	if w in ["rain", "storm"]:
		wet = 1.0
	elif open and not terr in ["snow", "desert", "mars"] and r.randf() < 0.32:
		wet = r.randf_range(0.5, 0.85)        # it rained before they came
	# the weather turns, now and then (the host announces it; the same seed picks it on every machine)
	var pick := r.randf()
	var when := r.randf_range(150.0, 420.0)
	var opts: Array = SHIFTS.get(w, [])
	var to: String = opts[r.randi() % opts.size()] if not opts.is_empty() else ""
	if open and pick < 0.4 and to != "":
		shift_at = when
		shift_to = _terrain_ok(to, terr)
	var arg := Game.cmd_arg("wxshift", "")       # tests: --wxshift=rain@20
	if arg != "":
		var parts := arg.split("@")
		shift_to = _terrain_ok(parts[0], terr)
		shift_at = float(parts[1]) if parts.size() > 1 else 10.0
	if shift_to == w:
		shift_at = -1.0
	_collect_wet_mats()
	if wet > 0.02 or shift_to in ["rain", "storm"]:
		_puddles_later()
	_apply_wet(true)
	_update_wind()

## Weather changes only out in the open (not in our base, theirs, on Mars).
func changeable() -> bool:
	if m.indoor() or m.mtype() in ["mars", "home", "alienbase"] or Net.mission_params.has("base"):
		return false
	return String(Net.mission_params.get("weather", "")) == "" or Game.cmd_arg("wxshift", "") != ""

func _terrain_ok(w: String, terr: String) -> String:
	if terr == "snow" and w in ["rain", "storm"]:
		return "snow"
	if terr == "desert" and w in ["rain", "storm", "fog", "snow"]:
		return "overcast"
	if terr != "snow" and w == "snow":
		return "rain"
	return w

func raining() -> bool:
	return m.weather in ["rain", "storm"]

func _process(delta: float) -> void:
	if m == null:
		return
	_update_wind()
	if raining():
		wet = minf(1.0, wet + delta / SOAK_TIME)
	elif wet > 0.0 and m.weather != "snow":
		wet = maxf(0.0, wet - delta / DRY_TIME)
	_apply_wet(false)
	_blend_tick(delta)
	_lens_tick(delta)
	_tracks_tick(delta)

func _update_wind() -> void:
	var tt: float = m.t
	var gust := 1.0 + 0.3 * sin(tt * 0.13) + 0.15 * sin(tt * 0.41 + 1.0)
	wind = wind_dir.rotated(Vector3.UP, 0.25 * sin(tt * 0.021)) * float(m._wind_base) * gust

# ---- wet ground ------------------------------------------------------------------------
func _collect_wet_mats() -> void:
	_wet_mats.clear()
	for k in Game._materials:
		var mt = Game._materials[k]
		if not mt is ShaderMaterial or (mt as ShaderMaterial).shader != Game.WORLD_SHADER:
			continue
		if mt.has_meta("tex") and WET_TEX.has(String(mt.get_meta("tex"))):
			_wet_mats.append([mt, WET_TEX[String(mt.get_meta("tex"))]])
		elif mt.has_meta("spec"):
			var sp: Array = mt.get_meta("spec")
			if sp[0] == "c" and not sp[2]:
				var c: Array = sp[1]
				if absf(c[0] - 0.1) < 0.02 and absf(c[1] - 0.1) < 0.02 and absf(c[2] - 0.11) < 0.02:
					_wet_mats.append([mt, 1.0])        # the street's asphalt

func _apply_wet(force: bool) -> void:
	var shown := snappedf(wet, 0.02)
	if not force and shown == _wet_shown:
		return
	_wet_shown = shown
	for e in _wet_mats:
		if is_instance_valid(e[0]):
			(e[0] as ShaderMaterial).set_shader_parameter("wet", shown * float(e[1]))
	if _pud_mat:
		_pud_mat.set_shader_parameter("wet", shown)
		var bg: Color = m.env.background_color if m.env else Color(0.05, 0.06, 0.09)
		_pud_mat.set_shader_parameter("sky_col", Vector3(bg.r, bg.g, bg.b))
		_pud_mat.set_shader_parameter("rain", 1.0 if m.weather == "storm" else (0.6 if m.weather == "rain" else 0.0))
	if puddles:
		puddles.visible = shown > 0.04

func _exit_tree() -> void:
	# the materials are shared by every mission: the next one starts dry
	for e in _wet_mats:
		if is_instance_valid(e[0]):
			(e[0] as ShaderMaterial).set_shader_parameter("wet", 0.0)

func _puddles_later() -> void:
	# the ground of a fresh map is in the physics only after a physics step
	await get_tree().physics_frame
	await get_tree().physics_frame
	_build_puddles()
	_apply_wet(true)

## Puddles: where the open sky falls on low, flat ground (a road, a yard, a field path).
func _build_puddles() -> void:
	if puddles:
		return
	puddles = Node3D.new()
	puddles.name = "Puddles"
	m.add_child(puddles)
	_pud_mat = ShaderMaterial.new()
	_pud_mat.shader = preload("res://shaders/puddle.gdshader")
	var r := RandomNumberGenerator.new()
	r.seed = Net.mission_seed * 17 + 3
	var sz: float = float(m.map.get("size", 60.0))
	var want := clampi(int(sz * sz / 160.0), 10, 70)
	var space: PhysicsDirectSpaceState3D = m.get_world_3d().direct_space_state
	var placed: Array = []
	var why := {}
	for i in want * 5:
		if placed.size() >= want:
			break
		var x := r.randf_range(2.0, sz - 2.0)
		var z := r.randf_range(2.0, sz - 2.0)
		var s := r.randf_range(0.9, 2.6)
		var yaw := r.randf() * TAU
		var q := PhysicsRayQueryParameters3D.create(Vector3(x, 40.0, z), Vector3(x, -1.0, z), Game.WORLD | Game.GLASS)
		var h := space.intersect_ray(q)
		if h.is_empty() or (h.position as Vector3).y > 0.35 or (h.normal as Vector3).y < 0.97:
			var wk := "none" if h.is_empty() else ("high" if (h.position as Vector3).y > 0.35 else "slope")
			why[wk] = why.get(wk, 0) + 1
			continue
		var p: Vector3 = h.position
		var sf := Game.surface_at(m, p, m.map)
		if not sf in ["hard", "dirt", "grass"]:
			why[sf] = why.get(sf, 0) + 1
			continue
		var close := false
		for o in placed:
			if (o as Vector3).distance_to(p) < 3.0:
				close = true
		if close:
			continue
		# all of it flat: the four corners too (not half over a kerb)
		var flat := true
		for k in 4:
			var c := p + Vector3(s * 0.4, 0, 0).rotated(Vector3.UP, yaw + k * PI / 2)
			var qc := PhysicsRayQueryParameters3D.create(c + Vector3(0, 40, 0), c + Vector3(0, -1, 0), Game.WORLD | Game.GLASS)
			var hc := space.intersect_ray(qc)
			if hc.is_empty() or absf((hc.position as Vector3).y - p.y) > 0.03:
				flat = false
				break
		if not flat:
			why["flat"] = why.get("flat", 0) + 1
			continue
		placed.append(p)
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(s, s * r.randf_range(0.55, 1.0))
		mi.mesh = pm
		mi.material_override = _pud_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 70.0
		puddles.add_child(mi)
		mi.position = p + Vector3(0, 0.012, 0)
		mi.rotation.y = yaw
	puddles.set_meta("count", placed.size())
	if Game.autotest() != "": print("[WX] puddles %d %s" % [placed.size(), why])

## Is there a puddle under @a p (a step splashes)?
func puddle_at(p: Vector3) -> bool:
	if puddles == null or not puddles.visible or wet < 0.25:
		return false
	for c in puddles.get_children():
		var mi := c as MeshInstance3D
		var lp: Vector3 = mi.global_transform.affine_inverse() * p
		var hs: Vector2 = (mi.mesh as PlaneMesh).size * 0.5 * (0.35 + 0.5 * wet)
		if absf(lp.y) < 0.3 and absf(lp.x) < hs.x and absf(lp.z) < hs.y:
			return true
	return false

# ---- the weather changes ------------------------------------------------------------------
static func snap(env: Environment, moon: DirectionalLight3D) -> Dictionary:
	return {"bg": env.background_color, "amb_c": env.ambient_light_color, "amb": env.ambient_light_energy,
		"fog_c": env.fog_light_color, "fog": env.fog_density, "vfog": env.volumetric_fog_density,
		"moon_c": moon.light_color, "moon": moon.light_energy}

static func put(env: Environment, moon: DirectionalLight3D, d: Dictionary) -> void:
	env.background_color = d["bg"]; env.ambient_light_color = d["amb_c"]; env.ambient_light_energy = d["amb"]
	env.fog_light_color = d["fog_c"]; env.fog_density = d["fog"]; env.volumetric_fog_density = d["vfog"]
	moon.light_color = d["moon_c"]; moon.light_energy = d["moon"]

static func mix(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var o := {}
	for key in a:
		o[key] = (a[key] as Color).lerp(b[key], k) if a[key] is Color else lerpf(a[key], b[key], k)
	return o

## Every machine: the new weather (from the host's rpc). Light, mist and wind fade over BLEND_TIME,
## the rain comes (or goes) slowly.
func shift(to: String, instant := false) -> void:
	if to == m.weather:
		return
	var was: String = m.weather
	var env: Environment = m.env
	var moon: DirectionalLight3D = m.moon
	var cur := snap(env, moon)
	var wind0: float = m._wind_base
	if not raw_env.is_empty():
		put(env, moon, raw_env)
	m.weather = to
	m._weather_env()
	var tgt := snap(env, moon)
	var wind1: float = m._wind_base
	put(env, moon, cur)
	m._wind_base = wind0
	_blend = {"a": cur, "b": tgt, "k": 0.0, "dur": 0.2 if instant else float(Game.cmd_arg("wxblend", str(BLEND_TIME))), "w0": wind0, "w1": wind1}
	# the rain
	var rains := to in ["rain", "storm", "snow"]
	var rained := was in ["rain", "storm", "snow"]
	if rains and (not rained or (to == "snow") != (was == "snow")):
		if rained:
			_rain_off(true)
		m._build_rain(to == "snow", 380 if to == "rain" else 700)
		if m.rain is GPUParticles3D:
			(m.rain as GPUParticles3D).amount_ratio = 0.0
			(m.rain as GPUParticles3D).preprocess = 0.0
		_blend["rain_in"] = 1.0 if to != "rain" else 0.55
	elif rains and rained:
		_blend["rain_from"] = (m.rain as GPUParticles3D).amount_ratio if m.rain is GPUParticles3D else 1.0
		_blend["rain_in"] = 0.55 if to == "rain" else 1.0
	elif rained and not rains:
		_blend["rain_out"] = true
	if to in ["rain", "storm"]:
		_build_puddles()
		if m._rain_out == null:
			_rain_gain = -40.0
			m._rain_out = AudioStreamPlayer.new()
			m._loop_player(m._rain_out, "storm" if to == "storm" else "rain", m.rain_db() + _rain_gain)
			m._rain_roof = AudioStreamPlayer.new()
			m._loop_player(m._rain_roof, "rain_roof", -60.0)
		elif was != to:
			m._loop_player(m._rain_out, "storm" if to == "storm" else "rain", m._rain_out.volume_db)
		if not rained:
			Game.play_ui(m, "thunder", -20)       # far off, the first of it

func gain_db() -> float:
	return _rain_gain

## A change is still fading in (the mission leaves the rain's volume to it meanwhile).
func blending() -> bool:
	return not _blend.is_empty()

func _rain_off(now: bool) -> void:
	if m.rain:
		var r: Node = m.rain
		m.rain = null
		if now:
			r.queue_free()
		else:
			r.get_tree().create_timer(2.0).timeout.connect(func(): if is_instance_valid(r): r.queue_free())
	if m.rain_field:
		m.rain_field.queue_free()
		m.rain_field = null

func _blend_tick(delta: float) -> void:
	if _blend.is_empty():
		return
	var k: float = minf(1.0, float(_blend["k"]) + delta / float(_blend["dur"]))
	_blend["k"] = k
	var s := smoothstep(0.0, 1.0, k)
	var d := mix(_blend["a"], _blend["b"], s)
	if m._flash_t <= 0.0:
		put(m.env, m.moon, d)
	m._moon_base = d["moon"]; m._amb_base = d["amb"]; m._fog_base = d["fog"]; m._bg_base = d["bg"]
	m._wind_base = lerpf(_blend["w0"], _blend["w1"], s)
	if _blend.has("rain_in") and m.rain:
		var from: float = _blend.get("rain_from", 0.0)
		var ratio := lerpf(from, float(_blend["rain_in"]), clampf(k * 1.6, 0.0, 1.0))
		if m.rain is GPUParticles3D:
			(m.rain as GPUParticles3D).amount_ratio = ratio
		_rain_gain = lerpf(-40.0, 0.0, clampf(k * 1.6, 0.0, 1.0)) if not _blend.has("rain_from") else 0.0
	if _blend.has("rain_out"):
		var left := clampf(1.0 - k * 1.8, 0.0, 1.0)
		if m.rain is GPUParticles3D:
			(m.rain as GPUParticles3D).amount_ratio = left
		elif m.rain and left < 0.5:
			m.rain.visible = false
		_rain_gain = lerpf(0.0, -40.0, 1.0 - left)
		if left <= 0.0:
			_blend.erase("rain_out")
			_rain_off(false)
			for ap in [m._rain_out, m._rain_roof]:
				if is_instance_valid(ap):
					(ap as Node).queue_free()
			m._rain_out = null
			m._rain_roof = null
	if m._rain_out and is_instance_valid(m._rain_out):
		var under: bool = m.under_roof
		m._rain_out.volume_db = m.rain_db() - (12.0 if under else 0.0) + _rain_gain
		if is_instance_valid(m._rain_roof):
			m._rain_roof.volume_db = (-9.0 if under else -60.0) + _rain_gain
	if k >= 1.0 and not _blend.has("rain_out"):
		_blend = {}

# ---- the sights in the rain: drops on the glass, a cold lens fogs up indoors -----------------
var drops := []                  # [{p: Vector2 in the unit disc, r, life, snow}]
var lens_fog := 0.0              # 0 clear .. 1 white
var _out_t := 0.0                # how long the local soldier has been out in the cold
var _was_under := false
var _drop_acc := 0.0

func _lens_tick(delta: float) -> void:
	var me: Node = m.local_player()
	if me == null or me.dead:
		drops.clear()
		lens_fog = 0.0
		return
	var under: bool = m.under_roof
	var terr := String(m.map.get("terrain", ""))
	var cold: bool = m.phase() == "noc" or terr == "snow" or m.weather in ["rain", "storm", "fog", "snow"]
	if not under:
		_out_t = _out_t + delta if cold else 0.0
	elif not _was_under:
		if _out_t > 12.0:
			lens_fog = clampf(0.45 + _out_t / 120.0, 0.45, 0.9)
		_out_t = 0.0
	_was_under = under
	lens_fog = maxf(0.0, lens_fog - delta * (0.11 if under else 0.25))
	var rate := 0.0
	if not under:
		rate = {"storm": 1.7, "rain": 0.9, "snow": 0.7}.get(m.weather, 0.0)
	_drop_acc += rate * delta
	while _drop_acc >= 1.0:
		_drop_acc -= 1.0
		if drops.size() >= 18:
			drops.pop_front()
		var a := randf() * TAU
		var d := sqrt(randf()) * 0.92
		drops.append({"p": Vector2(cos(a), sin(a)) * d, "r": randf_range(0.04, 0.12), "life": randf_range(5.0, 11.0), "snow": m.weather == "snow"})
	for dr in drops.duplicate():
		dr["life"] = float(dr["life"]) - delta * (2.5 if under else 1.0)
		if not dr["snow"] and dr["r"] > 0.09:
			dr["p"] = (dr["p"] as Vector2) + Vector2(0, delta * 0.05)      # a big one runs down
		if dr["life"] <= 0.0 or (dr["p"] as Vector2).length() > 1.0:
			drops.erase(dr)

## The HUD draws over the sight's window (centre @a mid, radius @a r in HUD pixels).
func draw_lens(c: CanvasItem, mid: Vector2, r: float) -> void:
	if r < 3.0:
		return
	if lens_fog > 0.01:
		# the mist clears from the middle out as the glass warms up
		var clear_r := r * clampf(1.15 - lens_fog * 1.3, 0.0, 0.95)
		var band := r - clear_r
		var col := Color(0.8, 0.82, 0.84, 0.55 * clampf(lens_fog * 1.4, 0.0, 1.0))
		if clear_r < 1.0:
			c.draw_circle(mid, r, col)
		else:
			c.draw_arc(mid, clear_r + band * 0.5, 0, TAU, 40, col, band)
			# a soft inner edge: thinner mist towards the clear middle
			var soft := minf(clear_r, r * 0.3)
			for k in 4:
				var rr := clear_r - soft * (k + 0.5) / 4.0
				c.draw_arc(mid, rr, 0, TAU, 40, Color(col.r, col.g, col.b, col.a * (0.8 - k * 0.2)), soft / 4.0 + 0.5)
	for dr in drops:
		var fade := clampf(float(dr["life"]) / 1.5, 0.0, 1.0)
		var at: Vector2 = mid + (dr["p"] as Vector2) * r
		var rr: float = maxf(1.0, float(dr["r"]) * r)
		if dr["snow"]:
			c.draw_circle(at, rr * 0.7, Color(0.92, 0.94, 0.98, 0.55 * fade))
			continue
		c.draw_circle(at, rr, Color(0.55, 0.6, 0.68, 0.22 * fade))
		c.draw_arc(at, rr, 0.6, 3.6, 10, Color(0.02, 0.02, 0.03, 0.45 * fade), maxf(0.6, rr * 0.18))
		c.draw_circle(at + Vector2(-rr * 0.35, -rr * 0.35), maxf(0.4, rr * 0.22), Color(1, 1, 1, 0.5 * fade))

# ---- tracks: what walks through mud or snow leaves its feet in it ----------------------------
## Every machine prints them itself, from the aliens' own steps (Alien._footsteps): nothing is
## sent and nothing marks them - you see them only where your light (or the day) falls on them.
const TRACK_SHAPE := {"grey": "claw", "grey_velitel": "claw", "lihnoun": "claw", "jestetan": "lizard",
	"jestetan_velitel": "lizard", "bijec": "big", "bijec_velitel": "big", "zombie": "bare", "ohar": "paw"}
const TRACK_SIZE := {"claw": Vector2(0.16, 0.22), "lizard": Vector2(0.21, 0.32), "big": Vector2(0.27, 0.4),
	"bare": Vector2(0.12, 0.29), "paw": Vector2(0.16, 0.17)}
## The prints: ellipses [x, y, rx, ry, turn] in -1..1 (y+ = the toes).
const TRACK_PADS := {
	"claw": [[0.0, -0.45, 0.32, 0.38, 0.0], [-0.42, 0.35, 0.12, 0.5, -0.45], [0.0, 0.5, 0.12, 0.5, 0.0], [0.42, 0.35, 0.12, 0.5, 0.45]],
	"lizard": [[0.0, -0.3, 0.5, 0.45, 0.0], [-0.5, 0.45, 0.14, 0.5, -0.5], [0.0, 0.6, 0.15, 0.42, 0.0], [0.5, 0.45, 0.14, 0.5, 0.5], [0.0, -0.85, 0.12, 0.2, 0.0]],
	"big": [[0.0, -0.15, 0.62, 0.75, 0.0], [-0.42, 0.72, 0.2, 0.25, -0.2], [0.0, 0.82, 0.2, 0.22, 0.0], [0.42, 0.72, 0.2, 0.25, 0.2]],
	"bare": [[0.0, -0.55, 0.34, 0.4, 0.0], [0.08, 0.05, 0.42, 0.42, 0.1], [-0.3, 0.68, 0.16, 0.16, 0.0], [-0.02, 0.76, 0.1, 0.11, 0.0], [0.18, 0.72, 0.09, 0.1, 0.0], [0.35, 0.62, 0.08, 0.09, 0.0], [0.48, 0.48, 0.07, 0.08, 0.0]],
	"paw": [[0.0, -0.3, 0.5, 0.42, 0.0], [-0.62, 0.3, 0.2, 0.24, 0.0], [-0.22, 0.65, 0.2, 0.24, 0.0], [0.22, 0.65, 0.2, 0.24, 0.0], [0.62, 0.3, 0.2, 0.24, 0.0]],
}
const TRACK_MAX := 260
const TRACK_LIFE := 300.0        # s, then they fade (snow falling fills them sooner)
var _tracks := {}                # shape -> {mm, next, born: PackedFloat32Array}
var _track_t := 0.0
var tracks_made := 0

## Where soft ground takes a print: snow (snow country), mud (wet earth and grass).
func soft_ground(p: Vector3) -> bool:
	var snow := String(m.map.get("terrain", "")) == "snow"
	if not snow and wet < 0.3:
		return false
	var sf := Game.surface_at(m, p, m.map)
	return sf in ["snow", "dirt", "grass"] if snow else sf in ["dirt", "grass"]

func track(a: Node3D, pos: Vector3, scale: float) -> void:
	var shape: String = TRACK_SHAPE.get(String(a.race).trim_suffix("_v2"), "")
	if shape == "":
		return
	var me: Node = m.local_player()
	if me and me.global_position.distance_to(pos) > 90.0:
		return
	var fwd: Vector3 = a.velocity if "velocity" in a else Vector3.ZERO
	fwd.y = 0
	if fwd.length() < 0.2:
		fwd = -a.global_transform.basis.z
		fwd.y = 0
	if fwd.length() < 0.01:
		return
	fwd = fwd.normalized()
	var side: float = -float(a.get_meta("trk_side", 1.0))
	a.set_meta("trk_side", side)
	var p := pos + fwd.cross(Vector3.UP) * side * 0.13 * scale
	var space: PhysicsDirectSpaceState3D = m.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.5, 0), p + Vector3(0, -0.7, 0), Game.WORLD)
	var h := space.intersect_ray(q)
	if h.is_empty() or (h.normal as Vector3).y < 0.85:
		return
	var at: Vector3 = h.position
	var up := PhysicsRayQueryParameters3D.create(at + Vector3(0, 0.4, 0), at + Vector3(0, 30, 0), 1)
	if not space.intersect_ray(up).is_empty():
		return        # under a roof: a floor, no mud
	if not soft_ground(at):
		return
	var tr: Dictionary = _track_set(shape)
	var mm: MultiMesh = tr["mm"]
	var i: int = tr["next"]
	tr["next"] = (i + 1) % TRACK_MAX
	var n: Vector3 = h.normal
	var z := fwd - n * fwd.dot(n)
	var x := n.cross(z).normalized()
	var s: Vector2 = TRACK_SIZE[shape] * scale
	var b := Basis(x * s.x, n, z.normalized() * s.y)
	if side < 0 and shape != "paw":
		b.x = -b.x                       # a left foot is the mirror of the right
	mm.set_instance_transform(i, Transform3D(b, at + n * 0.012))
	mm.set_instance_color(i, Color(1, 1, 1, 1))
	(tr["born"] as PackedFloat32Array)[i] = m.t
	mm.visible_instance_count = maxi(mm.visible_instance_count, i + 1)
	tracks_made += 1

func _track_set(shape: String) -> Dictionary:
	if _tracks.has(shape):
		return _tracks[shape]
	var snow := String(m.map.get("terrain", "")) == "snow"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var pm := PlaneMesh.new()
	pm.size = Vector2(1, 1)
	mm.mesh = pm
	mm.instance_count = TRACK_MAX
	mm.visible_instance_count = 0
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _track_tex(shape)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	mat.albedo_color = Color(0.3, 0.35, 0.46) if snow else Color(0.06, 0.045, 0.03)
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 1.0 if snow else 0.35          # wet mud shines a little
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "Tracks_" + shape
	m.add_child(mi)
	var born := PackedFloat32Array()
	born.resize(TRACK_MAX)
	_tracks[shape] = {"mm": mm, "next": 0, "born": born}
	return _tracks[shape]

static func _track_tex(shape: String) -> ImageTexture:
	var n := 48
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var pads: Array = TRACK_PADS[shape]
	for yy in n:
		for xx in n:
			var u := (xx + 0.5) / n * 2.0 - 1.0
			var v := 1.0 - (yy + 0.5) / n * 2.0
			var a := 0.0
			for e in pads:
				var d := Vector2(u - float(e[0]), v - float(e[1])).rotated(-float(e[4]))
				var k: float = (d.x / float(e[2])) * (d.x / float(e[2])) + (d.y / float(e[3])) * (d.y / float(e[3]))
				a = maxf(a, clampf((1.0 - k) * 4.0, 0.0, 1.0))
			img.set_pixel(xx, n - 1 - yy, Color(1, 1, 1, a * 0.85))
	return ImageTexture.create_from_image(img)

func _tracks_tick(delta: float) -> void:
	_track_t -= delta
	if _track_t > 0.0 or _tracks.is_empty():
		return
	_track_t = 1.0
	var life := TRACK_LIFE * (0.5 if m.weather == "snow" else 1.0)
	for tr in _tracks.values():
		var mm: MultiMesh = tr["mm"]
		var born: PackedFloat32Array = tr["born"]
		for i in mm.visible_instance_count:
			var age: float = m.t - born[i]
			mm.set_instance_color(i, Color(1, 1, 1, clampf((life - age) / 60.0, 0.0, 1.0)))
