extends CanvasLayer
## 0.70 Facelift II: the game's intro - a short film in the engine (no video), before the main menu on
## the first start and from the menu's "Úvod" button. Our own story, not the old UFO intro:
##   I.   the Earth from orbit at night, something falls towards Europe (music intro_1, ~15 s)
##   II.  the velín of Project X: the alarm, the radar finds it, a team goes (intro_2, ~16 s)
##   III. a farm at night: the craft lands, a man runs, things move in the dark, the helicopter
##        comes, three soldiers with lamps on their helmets walk into the yard - something steps into
##        the light, a shot, black; the name of the game (intro_3, ~60 s)
## The shots are timed on the music: with Ari's intro_1..3 (hudba/ or assets/music) each part lasts as
## long as its track; without them the fixed times above (and silence - no sounds are made up here).
## Captions in Czech, never a name of a creature (hardcore). Any key or click skips it. Only on this
## machine (never in co-op). Its own 3D world in a SubViewport, like the transport (transport.gd).

signal finished

const PART := [15.0, 16.0, 60.0]           # the parts' lengths without music
const ALIEN := preload("res://scripts/alien.gd")
const NPC := preload("res://scripts/base_npc.gd")
const PLAYER := preload("res://scripts/player.gd")

var _vp: SubViewport
var _world: Node3D
var _cam: Camera3D
var _env: Environment
var _sets := {}                  # "space" / "velin" / "farm" -> Node3D
var _t := 0.0                    # film time (on the fixed scale: 0..91 + the logo)
var _real := 0.0
var _seg := PART.duplicate()     # real length of each part (= the music's when it is there)
var _music: AudioStreamPlayer
var _track := -1
var _done := false
var _cap: Label
var _cap_text := ""
var _cap_t := 0.0
var _caps: Array = []            # [film time, text, how long]
var _black: ColorRect
var _logo: Control
var _men: Array = []             # {sk, clip, t, node, speed}
var _afk: Array = []             # [AnimationPlayer, anim]
var _rotors: Array = []
var _guns: Array = []            # {sk, gun, model, clip}
var _ufo: Node3D
var _ufo_light: OmniLight3D
var _beam: MeshInstance3D
var _streak: Node3D
var _globe: MeshInstance3D
var _alarm: OmniLight3D
var _beacon: Node3D
var _radar: ShaderMaterial
var _heli: Node3D
var _heli_light: SpotLight3D
var _civ: Node3D
var _grey: Node3D
var _hound: Node3D
var _hound_ap: AnimationPlayer
var _brute: Node3D
var _brute_ap: AnimationPlayer
var _squad: Array = []           # the three soldiers (pivots)
var _flash: OmniLight3D
var shots_seen: Array = []       # (autotest: which sets were shown)
var _set_now := ""
var skippable := true

func _ready() -> void:
	layer = 125
	name = "Intro"
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var s := DisplayServer.window_get_size() if DisplayServer.get_name() != "headless" else Vector2i(640, 360)
	_vp.size = Vector2i(maxi(s.x, 640), maxi(s.y, 360))
	add_child(_vp)
	var tr := TextureRect.new()
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.texture = _vp.get_texture()
	root.add_child(tr)
	# letterbox: a film
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_left = 0.0
		bar.anchor_right = 1.0
		bar.anchor_top = 0.0 if top else 0.9
		bar.anchor_bottom = 0.1 if top else 1.0
		root.add_child(bar)
	_cap = Label.new()
	_cap.anchor_left = 0.08
	_cap.anchor_right = 0.92
	_cap.anchor_top = 0.905
	_cap.anchor_bottom = 0.995
	_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cap.add_theme_font_size_override("font_size", 11)
	_cap.add_theme_color_override("font_color", Color(0.86, 0.84, 0.76))
	_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_cap)
	var skip := Label.new()
	skip.text = "libovolná klávesa - přeskočit"
	skip.anchor_left = 0.7
	skip.anchor_right = 0.99
	skip.anchor_top = 0.02
	skip.anchor_bottom = 0.08
	skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip.add_theme_font_size_override("font_size", 7)
	skip.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.7))
	skip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(skip)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_black)
	_logo = _make_logo()
	root.add_child(_logo)
	_build()
	_captions()
	_start_music()
	_show("space")
	_update(0.0)

# ---------------------------------------------------------------- the world

func _build() -> void:
	_world = Node3D.new()
	_vp.add_child(_world)
	_env = Environment.new()
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.glow_enabled = true
	_env.glow_intensity = 0.9
	_env.glow_bloom = 0.15
	var we := WorldEnvironment.new()
	we.environment = _env
	_world.add_child(we)
	_cam = Camera3D.new()
	_cam.fov = 50.0
	_cam.far = 400.0
	_world.add_child(_cam)
	_cam.current = true
	_build_space()
	_build_velin()
	_build_farm()

func _new_set(n: String) -> Node3D:
	var s := Node3D.new()
	s.name = n
	_world.add_child(s)
	_sets[n] = s
	return s

func _box(parent: Node3D, pos: Vector3, size: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	parent.add_child(mi)
	mi.position = pos
	return mi

func _prop(parent: Node3D, mname: String, pos: Vector3, yaw := 0.0, sc := 1.0) -> Node3D:
	var m: Node3D = Game.model(mname)
	if m == null:
		return null
	parent.add_child(m)
	m.position = pos
	m.rotation.y = yaw
	m.scale *= sc
	return m

func _glow(c: Color, e := 3.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

## I. the Earth at night, the stars, the falling light.
func _build_space() -> void:
	var s := _new_set("space")
	_globe = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 96
	sm.rings = 48
	_globe.mesh = sm
	var gm := ShaderMaterial.new()
	gm.shader = load("res://shaders/globe.gdshader")
	gm.set_shader_parameter("day_tex", load("res://assets/textures/earth_day.png"))
	gm.set_shader_parameter("night_tex", load("res://assets/textures/earth_night.png"))
	gm.set_shader_parameter("grid", 0.0)
	# the sun behind the Earth's edge east of Europe: Europe at night, the dawn coming over Asia
	gm.set_shader_parameter("sun_dir", _geo(40.0, 110.0))
	_globe.material_override = gm
	s.add_child(_globe)
	# the stars: little points on a far shell
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2(0.18, 0.18)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.vertex_color_use_as_albedo = true
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = qm
	mm.mesh = q
	mm.instance_count = 1800
	var rng := RandomNumberGenerator.new()
	rng.seed = 1990
	for i in mm.instance_count:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * rng.randf_range(0.4, 1.4)), d * 120.0))
		var b := rng.randf_range(0.35, 1.0)
		mm.set_instance_color(i, Color(b, b, b * rng.randf_range(0.9, 1.1), b))
	var stars := MultiMeshInstance3D.new()
	stars.multimesh = mm
	s.add_child(stars)
	# the falling light: a hot point with a tail
	_streak = Node3D.new()
	s.add_child(_streak)
	var head := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.022
	hs.height = 0.044
	head.mesh = hs
	head.material_override = _glow(Color(0.85, 0.6, 1.0), 8.0)
	_streak.add_child(head)
	var tail := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.016
	cm.height = 0.5
	tail.mesh = cm
	var tm := _glow(Color(0.6, 0.35, 1.0), 4.0)
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.albedo_color.a = 0.5
	tail.material_override = tm
	tail.rotation.x = PI / 2
	tail.position = Vector3(0, 0, 0.25)
	_streak.add_child(tail)

## A point of the globe (lat, lon in degrees) as globe.gdshader reads it (lon = atan(x, z)).
func _geo(lat: float, lon: float) -> Vector3:
	var la := deg_to_rad(lat)
	var lo := deg_to_rad(lon)
	return Vector3(sin(lo) * cos(la), sin(la), cos(lo) * cos(la))

## II. the velín: the table with the globe, consoles, two at the keyboards, the red alarm, the radar.
func _build_velin() -> void:
	var s := _new_set("velin")
	s.position = Vector3(0, 0, 400)
	var wall: Material = Game.mat("base_wall", 0.5)
	_box(s, Vector3(0, -0.05, 0), Vector3(12, 0.1, 12), Game.mat("base_floor", 0.5))
	_box(s, Vector3(0, 3.5, 0), Vector3(12, 0.2, 12), wall)
	for side in [[Vector3(0, 1.7, -6), Vector3(12, 3.6, 0.2)], [Vector3(0, 1.7, 6), Vector3(12, 3.6, 0.2)],
			[Vector3(-6, 1.7, 0), Vector3(0.2, 3.6, 12)], [Vector3(6, 1.7, 0), Vector3(0.2, 3.6, 12)]]:
		_box(s, side[0], side[1], wall)
	_prop(s, "v_bp_command_table", Vector3.ZERO)
	var g := MeshInstance3D.new()
	var gs := SphereMesh.new()
	gs.radius = 0.45
	gs.height = 0.9
	g.mesh = gs
	var gmat := StandardMaterial3D.new()
	gmat.albedo_texture = load("res://assets/textures/earth_day.png")
	gmat.emission_enabled = true
	gmat.emission_texture = gmat.albedo_texture
	gmat.emission_energy_multiplier = 0.7
	g.material_override = gmat
	s.add_child(g)
	g.position = Vector3(0, 1.6, 0)
	g.set_meta("spin", true)
	for k in 4:
		var x := -4.6 + k * 1.8
		_prop(s, "v_bp_console", Vector3(x, 0, -5.4), 0.0)
		_box(s, Vector3(x, 1.75, -5.85), Vector3(1.4, 0.8, 0.05), _glow(Color(0.15, 0.5 + 0.1 * k, 0.4), 1.4))
	# the big radar screen on the east wall
	var scr := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(2.6, 2.0)
	scr.mesh = qm
	_radar = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = RADAR_SHADER
	_radar.shader = sh
	scr.material_override = _radar
	s.add_child(scr)
	scr.position = Vector3(5.88, 1.9, -1.5)
	scr.rotation.y = -PI / 2
	_box(s, Vector3(5.93, 1.9, -1.5), Vector3(0.05, 2.2, 2.8), _col(Color(0.12, 0.12, 0.13)))
	var l := OmniLight3D.new()
	l.light_color = Color(0.85, 0.9, 1.0)
	l.light_energy = 0.55
	l.omni_range = 9.0
	l.position = Vector3(0, 3.0, 0)
	s.add_child(l)
	_alarm = OmniLight3D.new()
	_alarm.light_color = Color(1.0, 0.12, 0.08)
	_alarm.light_energy = 0.0
	_alarm.omni_range = 11.0
	_alarm.position = Vector3(-3, 3.1, 3)
	s.add_child(_alarm)
	_beacon = Node3D.new()
	s.add_child(_beacon)
	_beacon.position = Vector3(-3, 3.3, 3)
	_box(_beacon, Vector3.ZERO, Vector3(0.25, 0.12, 0.25), _glow(Color(1.0, 0.15, 0.1), 4.0))
	var sp := SpotLight3D.new()
	sp.light_color = Color(1.0, 0.15, 0.08)
	sp.light_energy = 3.0
	sp.spot_range = 9.0
	sp.spot_angle = 22.0
	sp.rotation = Vector3(-0.5, 0, 0)
	_beacon.add_child(sp)
	# two at the keyboards (the base's own people), the officer at the table
	var busy := {}
	for k in 2:
		var npc: Node3D = NPC.new()
		npc.setup("sci" if k == 0 else "tech", [{"pos": s.position + Vector3(-4.6 + k * 3.6, 0, -4.6), "yaw": 0.0, "act": "typing"}], busy, 1990 + k, k == 1)
		s.add_child(npc)
		npc.position = Vector3(-4.6 + k * 3.6, 0, -4.6)
		npc.rotation.y = 0.0
	var off := _soldier(s, Vector3(1.6, 0, 1.4), PI * 0.8, "tp_body_idle", 7, false)
	off.set_meta("velin", true)

## III. the farm at night.
func _build_farm() -> void:
	var s := _new_set("farm")
	s.position = Vector3(0, 0, -400)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(240, 240)
	ground.mesh = pm
	ground.material_override = Game.mat("grass", 0.5)
	s.add_child(ground)
	var path := MeshInstance3D.new()
	var pp := PlaneMesh.new()
	pp.size = Vector2(2.4, 40)
	path.mesh = pp
	path.material_override = Game.mat("dirt", 0.5)
	s.add_child(path)
	path.position = Vector3(-2, 0.01, -2)
	path.rotation.y = 0.15
	_prop(s, "v_coop", Vector3(-9, 0, -9), 0.3)
	_prop(s, "v_silo", Vector3(-16, 0, -14))
	_prop(s, "v_tractor", Vector3(7, 0, -11), -0.6)
	_prop(s, "v_hay_bale", Vector3(4, 0, -6), 0.4)
	_prop(s, "v_hay_bale", Vector3(5.4, 0, -6.6), 1.2)
	_prop(s, "v_scarecrow", Vector3(12, 0, -3), -0.8)
	_prop(s, "v_well", Vector3(9.5, 0, -1.5))
	for i in 9:
		if i in [4, 5]:
			continue        # (the gate: the team comes in this way)
		_prop(s, "v_wire_fence", Vector3(-16 + i * 4.0, 0, 4.0), 0.0)
	var cow := _prop(s, "cow", Vector3(9, 0, 1.5), 2.2)
	if cow:
		cow.set_meta("graze", true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 24
	for i in 46:
		var a := rng.randf() * TAU
		var r := rng.randf_range(26.0, 70.0)
		var p := Vector3(cos(a) * r, 0, sin(a) * r - 10.0)
		if p.z > 10.0 and absf(p.x) < 30.0:
			continue          # (the camera's side stays open)
		_prop(s, ["v_tree_pine", "v_tree_spruce", "v_tree_spruce2", "v_tree_oak", "v_tree_birch"][rng.randi() % 5], p, rng.randf() * TAU, rng.randf_range(0.9, 1.4))
	# the lamp over the coop's door
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.7, 0.4)
	lamp.light_energy = 1.4
	lamp.omni_range = 7.0
	lamp.shadow_enabled = true
	lamp.position = Vector3(-7.4, 2.6, -6.6)
	s.add_child(lamp)
	_box(s, Vector3(-7.4, 2.5, -6.7), Vector3(0.16, 0.12, 0.16), _glow(Color(1.0, 0.75, 0.45), 3.0))
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.62, 0.9)
	moon.light_energy = 0.35
	moon.shadow_enabled = true
	moon.rotation = Vector3(-0.75, -0.6, 0)
	s.add_child(moon)
	# the craft: comes down behind the coop with its violet glow and a beam
	_ufo = _prop(s, "ufo_scout", Vector3(-2, 30, -24), 0.4)
	if _ufo == null:
		_ufo = Node3D.new()
		s.add_child(_ufo)
	_ufo_light = OmniLight3D.new()
	_ufo_light.light_color = Color(0.7, 0.35, 1.0)
	_ufo_light.light_energy = 3.0
	_ufo_light.omni_range = 16.0
	_ufo_light.position = Vector3(0, -0.5, 0)
	_ufo.add_child(_ufo_light)
	_beam = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.8
	cm.bottom_radius = 3.0
	cm.height = 12.0
	_beam.mesh = cm
	var bm := _glow(Color(0.6, 0.35, 1.0), 1.5)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.albedo_color = Color(0.25, 0.12, 0.4, 0.25)
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam.material_override = bm
	_beam.position = Vector3(0, -6.0, 0)
	_ufo.add_child(_beam)
	# a man runs out of the yard
	_civ = _figure(s, "civ_a", "al_civ_a_run", Vector3(-6, 0, -8), 1.15)
	# something walks after him, far back in the dark
	_grey = _figure(s, "grey", "al_grey_walk", Vector3(-9, 0, -16), 0.85)
	# the four-legged one sniffs along the fence
	_hound = ALIEN.afk_scene("ohar")
	if _hound:
		s.add_child(_hound)
		_hound.position = Vector3(3.5, 0, 5.6)
		_hound.rotation.y = PI * 0.55
		_hound_ap = _hound.find_child("AnimationPlayer", true, false)
		_afk_play(_hound_ap, ["sniff", "lurk_walk", "idle"])
	# the big one at the end (the Bijec's roar when the pack has it, else the Ještěřan with its gun)
	for r in ["bijec", "jestetan"]:
		_brute = ALIEN.afk_scene(r)
		if _brute:
			_brute.set_meta("race", r)
			break
	if _brute:
		s.add_child(_brute)
		_brute.position = Vector3(-3.2, 0, -12.5)
		_brute.rotation.y = PI * 0.92
		_brute_ap = _brute.find_child("AnimationPlayer", true, false)
		_afk_play(_brute_ap, ["lurk", "idle"])
	else:
		_brute = _figure(s, "grey", "al_grey_aim", Vector3(-3.2, 0, -12.5), 0.0)
	# the helicopter
	_heli = _prop(s, "heli", Vector3(40, 26, 20), -PI * 0.6)
	if _heli:
		for n in _heli.find_children("*", "Node3D", true, false):
			if String(n.name).begins_with("Rotor") or String(n.name).begins_with("Prop"):
				_rotors.append(n)
		_heli_light = SpotLight3D.new()
		_heli_light.light_color = Color(1.0, 0.96, 0.85)
		_heli_light.light_energy = 6.0
		_heli_light.spot_range = 40.0
		_heli_light.spot_angle = 14.0
		_heli_light.shadow_enabled = true
		_heli.add_child(_heli_light)
		_heli_light.position = Vector3(0, -0.6, -2.0)
		_heli_light.rotation = Vector3(-0.9, 0, 0)
	# the three of the team (they come out of the helicopter later)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 3
	for k in 3:
		_squad.append(_soldier(s, Vector3(8 + k * 0.9, 0, 9 + k * 0.6), PI * 0.8, "tp_body_walk", 11 + k, true))
	# the beam of the leader's lamp that finds it (the helmet lamps light the way, this one the face)
	var torch := SpotLight3D.new()
	torch.name = "Torch"
	torch.light_color = Color(1.0, 0.95, 0.82)
	torch.light_energy = 0.0
	torch.spot_range = 20.0
	torch.spot_angle = 12.0
	torch.shadow_enabled = true
	s.add_child(torch)
	_flash = OmniLight3D.new()
	_flash.light_color = Color(1.0, 0.85, 0.55)
	_flash.light_energy = 0.0
	_flash.omni_range = 9.0
	s.add_child(_flash)

func _col(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m

## A creature or a civilian of the old rigged models (the soldier's bones), posed by an afk clip.
func _figure(parent: Node3D, mname: String, clip_id: String, pos: Vector3, speed: float) -> Node3D:
	var m: Node3D = Game.model(mname)
	if m == null:
		return null
	var pivot := Node3D.new()
	parent.add_child(pivot)
	pivot.position = pos
	pivot.add_child(m)
	var ap: Node = m.find_child("AnimationPlayer", true, false)
	var clip := AnimClips.get_clip(clip_id)
	if clip.is_empty() and ap:
		var a: AnimationPlayer = ap
		for an in ["run", "walk", "idle"]:
			if a.has_animation(an):
				a.play(an)
				break
	elif ap:
		ap.get_parent().remove_child(ap)
		ap.free()
	var sk: Skeleton3D = m.find_child("Skeleton3D", true, false)
	_men.append({"sk": sk, "clip": clip, "t": 0.0, "node": pivot, "speed": speed})
	return pivot

## A soldier (the merc model in a random look), with a rifle in his hands and a lamp on the helmet.
func _soldier(parent: Node3D, pos: Vector3, yaw: float, clip_id: String, seed_: int, lamp: bool) -> Node3D:
	var m: Node3D = Game.model("merc")
	var pivot := Node3D.new()
	parent.add_child(pivot)
	pivot.position = pos
	pivot.rotation.y = yaw
	if m == null:
		return pivot
	m.scale = Vector3(-1, 1, 1)
	pivot.add_child(m)
	var ap: Node = m.find_child("AnimationPlayer", true, false)
	if ap:
		ap.get_parent().remove_child(ap)
		ap.free()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var look := Game.random_look(rng.randf() < 0.3, rng)
	look["headgear"] = 1 if lamp else look.get("headgear", 0)
	Game.apply_look(m, look)
	var camo := Game.camo_mat("woodland")
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var nm := String(mi.name)
		if nm in ["Gear_Pouches", "Gear_Backpack"]:
			mi.visible = true
		for i in mi.mesh.get_surface_count():
			var src: Material = mi.mesh.surface_get_material(i)
			if src and String(src.resource_name) == "Uniform":
				mi.set_surface_override_material(i, camo)
	var sk: Skeleton3D = m.find_child("Skeleton3D", true, false)
	var clip := AnimClips.get_clip(clip_id)
	if clip.is_empty():
		clip = AnimClips.get_clip("tp_body_idle")
	_men.append({"sk": sk, "clip": clip, "t": rng.randf() * 1.5, "node": pivot, "speed": 0.0})
	var gun: Node3D = Game.model("rifle")
	if gun and sk:
		var holder := Node3D.new()
		_world.add_child(holder)
		holder.add_child(gun)
		_guns.append({"sk": sk, "gun": gun, "holder": holder, "model": m})
	if lamp and sk and sk.find_bone("head") >= 0:
		var att := BoneAttachment3D.new()
		att.bone_name = "head"
		sk.add_child(att)
		var sl := SpotLight3D.new()
		sl.light_color = Color(1.0, 0.95, 0.82)
		sl.light_energy = 4.0
		sl.spot_range = 22.0
		sl.spot_angle = 18.0
		sl.shadow_enabled = true
		att.add_child(sl)
		sl.position = Vector3(0, 0.2, -0.15)
		sl.rotation = Vector3(-0.12, 0, 0)
	return pivot

func _afk_play(ap: AnimationPlayer, names: Array) -> void:
	if ap == null:
		return
	for n in names:
		if ap.has_animation(n):
			ap.get_animation(n).loop_mode = Animation.LOOP_LINEAR if n != "roar" else Animation.LOOP_NONE
			ap.play(n, 0.3)
			return

func _set_clip(pivot: Node3D, clip_id: String, speed := -1.0) -> void:
	for e in _men:
		if e["node"] == pivot:
			var c := AnimClips.get_clip(clip_id)
			if not c.is_empty() and e["clip"] != c:
				e["clip"] = c
				e["t"] = 0.0
			if speed >= 0.0:
				e["speed"] = speed

# ---------------------------------------------------------------- the story

func _captions() -> void:
	_caps = [
		[1.5, "24. dubna 1990", 4.0],
		[6.5, "Nad Evropou se objevil objekt, který nepatří nikomu na Zemi.", 7.5],
		[16.5, "Projekt X. Základna, o které nevědí ani vlády, které ji platí.", 6.0],
		[23.5, "Objekt přistál. Venkov, daleko od města.", 4.0],
		[28.0, "Vyslat tým.", 2.8],
		[32.5, "Jižní Morava. Farma u lesa. 23:40", 5.0],
		[69.0, "Tým Projektu X na místě.", 4.0],
	]

func _start_music() -> void:
	Game.play_music("")
	var tracks: Array = []
	for n in ["intro_1", "intro_2", "intro_3"]:
		var st: AudioStream = Game._music_stream(n) if Game.autotest() == "" else null
		tracks.append(st)
	if tracks.has(null):
		return       # (no music yet: the fixed times)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	for i in 3:
		var st: AudioStream = tracks[i]
		if "loop" in st:
			st.loop = false
		_seg[i] = maxf(4.0, st.get_length())
	_music.set_meta("tracks", tracks)
	_next_track()

func _next_track() -> void:
	_track += 1
	var tracks: Array = _music.get_meta("tracks")
	if _track >= tracks.size():
		return
	_music.stream = tracks[_track]
	_music.play()

## Real seconds -> the film's time (each part stretched to its track).
func _film_time(real: float) -> float:
	var acc := 0.0
	var film := 0.0
	for i in 3:
		if real < acc + _seg[i]:
			return film + (real - acc) / _seg[i] * PART[i]
		acc += _seg[i]
		film += PART[i]
	return film + (real - acc)

func _show(n: String) -> void:
	if _set_now == n:
		return
	_set_now = n
	shots_seen.append(n)
	for k in _sets:
		(_sets[k] as Node3D).visible = k == n
	match n:
		"space":
			_env.background_mode = Environment.BG_COLOR
			_env.background_color = Color(0.0, 0.0, 0.01)
			_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			_env.ambient_light_color = Color(0, 0, 0)
			_env.fog_enabled = false
			_cam.far = 400.0
		"velin":
			_env.background_mode = Environment.BG_COLOR
			_env.background_color = Color(0.02, 0.02, 0.03)
			_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			_env.ambient_light_color = Color(0.35, 0.37, 0.45)
			_env.ambient_light_energy = 0.35
			_env.fog_enabled = false
		"farm":
			_env.background_mode = Environment.BG_COLOR
			_env.background_color = Color(0.03, 0.045, 0.08)
			_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			_env.ambient_light_color = Color(0.3, 0.36, 0.55)
			_env.ambient_light_energy = 0.22
			_env.fog_enabled = true
			_env.fog_light_color = Color(0.05, 0.07, 0.12)
			_env.fog_density = 0.022
			_env.fog_sky_affect = 1.0
			_cam.far = 200.0

func _process(delta: float) -> void:
	if _done:
		return
	_real += delta
	if _music and not _music.playing and _real > 0.5:
		_next_track()
	_update(delta)

## The whole film at film time _t.
func _update(delta: float) -> void:
	_t = _film_time(_real)
	var t := _t
	# fade from black at the start and around the cuts
	var a := 0.0
	for cut in [0.0, 15.0, 31.0]:
		if t >= cut - 0.6 and t < cut and cut > 0.0:
			a = maxf(a, (t - (cut - 0.6)) / 0.6)
		elif t >= cut and t < cut + 0.9:
			a = maxf(a, 1.0 - (t - cut) / 0.9)
	if t >= 85.6:
		a = 1.0
	_black.color.a = clampf(a, 0.0, 1.0)
	_cap_update(t)
	if t < 15.0:
		_show("space")
		_space(t)
	elif t < 31.0:
		_show("velin")
		_velin(t - 15.0, delta)
	elif t < 86.0:
		_show("farm")
		_farm(t - 31.0, delta)
	_logo_update(t)
	for e in _men:
		_pose(e, delta)
	for g in _guns:
		_hold(g)
	if t > 95.0 and not _done:
		finish()

func _cap_update(t: float) -> void:
	var txt := ""
	var shown := 0.0
	for c in _caps:
		if t >= c[0] and t < c[0] + c[2]:
			txt = c[1]
			shown = t - float(c[0])
	# typewriter: 28 letters a second
	var n := mini(txt.length(), int(shown * 28.0))
	_cap.text = txt.substr(0, n)

func _space(t: float) -> void:
	var eu := _geo(48.0, 16.0)
	# the camera swings slowly round to Europe and closes in
	var k := smoothstep(0.0, 15.0, t)
	var dir := _geo(lerpf(30.0, 46.0, k), lerpf(-40.0, 12.0, k))
	_cam.fov = 40.0
	_cam.global_position = (_sets["space"] as Node3D).global_position + dir * lerpf(4.2, 2.15, k)
	_cam.look_at((_sets["space"] as Node3D).global_position + eu * lerpf(0.0, 0.55, k), Vector3.UP)
	# the light falls in from deep space towards Europe, from 5 to 13 s
	var f := clampf((t - 5.0) / 8.0, 0.0, 1.0)
	var from := eu * 1.9 + Vector3(0.55, 0.5, -0.25)
	var to := eu * 1.01
	var p := from.lerp(to, f * f)
	_streak.visible = t > 5.0 and t < 13.2
	_streak.position = p
	if f < 1.0:
		_streak.look_at(_streak.global_position + (to - from).normalized(), Vector3.UP)

func _velin(t: float, delta: float) -> void:
	var s: Node3D = _sets["velin"]
	# the alarm turns from 1.5 s
	var on := t > 1.5
	_alarm.light_energy = (0.6 + 0.6 * absf(sin(t * 4.0))) if on else 0.0
	_beacon.visible = on
	_beacon.rotation.y += delta * 5.0
	if _radar:
		_radar.set_shader_parameter("time", t)
		_radar.set_shader_parameter("blip", clampf((t - 4.0) / 2.0, 0.0, 1.0))
	for g in s.get_children():
		if g.has_meta("spin"):
			(g as Node3D).rotation.y += delta * 0.4
	if t < 8.0:
		# over the table towards the consoles
		var k := smoothstep(0.0, 8.0, t)
		_cam.fov = 55.0
		_cam.global_position = s.global_position + Vector3(lerpf(-4.5, -2.5, k), lerpf(2.6, 2.0, k), lerpf(4.8, 3.2, k))
		_cam.look_at(s.global_position + Vector3(0.2, 1.3, -1.0), Vector3.UP)
	else:
		# the radar screen: the blip
		var k := smoothstep(8.0, 16.0, t)
		_cam.fov = 45.0
		_cam.global_position = s.global_position + Vector3(lerpf(2.4, 3.6, k), 1.85, lerpf(0.6, -0.6, k))
		_cam.look_at(s.global_position + Vector3(5.9, 1.85, -1.5), Vector3.UP)

func _farm(t: float, delta: float) -> void:
	var s: Node3D = _sets["farm"]
	var o := s.global_position
	# the craft comes down (0..10) behind the coop and sits; its light pulses
	var land := smoothstep(0.0, 10.0, t)
	if _ufo:
		_ufo.position = Vector3(-2, lerpf(30.0, 0.4, land), -24)
		_ufo.rotation.y += delta * lerpf(0.8, 0.15, land)
		_ufo_light.light_energy = 2.4 + 1.2 * sin(t * 2.3)
		_beam.visible = t < 12.0
	# the man runs (from 9 s) down the path towards the camera; it follows him (12 m behind)
	if _civ:
		var rk := clampf((t - 8.5) / 8.0, 0.0, 1.0)
		_civ.position = Vector3(-6, 0, -8).lerp(Vector3(2.5, 0, 9.0), rk)
		_civ.look_at(o + _civ.position + Vector3(8.5, 0, 17).normalized(), Vector3.UP)
		_civ.visible = t > 8.0 and t < 17.0
	if _grey:
		var gk := clampf((t - 11.0) / 16.0, 0.0, 1.0)
		_grey.position = Vector3(-9, 0, -16).lerp(Vector3(-3, 0, 0), gk)
		_grey.look_at(o + _grey.position + Vector3(6, 0, 16).normalized(), Vector3.UP)
		_grey.visible = t > 10.0 and t < 27.5
	# the helicopter (from 27 s) comes in and sets down at (11, 0, 12) by 37 s
	if _heli:
		var hk := smoothstep(27.0, 37.0, t)
		_heli.position = Vector3(40, 26, 20).lerp(Vector3(11, 0.05, 12), hk)
		_heli.position.y = lerpf(26.0, 0.05, smoothstep(27.0, 37.5, t))
		for r in _rotors:
			(r as Node3D).rotate_y(delta * 22.0)
		_heli.visible = t > 26.0
		_heli_light.light_energy = 6.0 if t < 39.0 else 1.5
	# the team walks out (37..45) towards the yard, then stops and looks round with the lamps
	for k in _squad.size():
		var sq: Node3D = _squad[k]
		var wk := clampf((t - 37.5 - k * 0.6) / 8.0, 0.0, 1.0)
		var start := Vector3(9.5 + k * 0.9, 0, 12.5 + k * 0.5)
		var goal := Vector3(1.0 + k * 1.6, 0, 1.0 + k * 0.9)
		sq.position = start.lerp(goal, wk)
		sq.visible = t > 37.0
		var aim := Vector3(-3.2, 0, -12.5) + Vector3(sin(t * 0.7 + k) * 3.0, 0, 0)
		sq.look_at(o + Vector3(aim.x, 0, aim.z), Vector3.UP)
		_set_clip(sq, "tp_body_walk" if wk < 1.0 else "tp_body_idle_aim", 0.0)
	# the four-legged one at the fence (16..27 in the picture), the big one steps into the light at 47
	if _hound:
		_hound.visible = t > 15.0 and t < 28.0
	if _brute:
		var bk := smoothstep(46.0, 50.0, t)
		_brute.position = Vector3(-3.2, 0, -16.0).lerp(Vector3(-2.2, 0, -8.5), bk)
		_brute.visible = t > 45.0
		if _squad.size() > 1:
			_brute.look_at(o + (_squad[1] as Node3D).position, Vector3.UP)
		if t > 49.5 and not _brute.has_meta("up"):
			_brute.set_meta("up", true)
			_afk_play(_brute_ap, ["roar", "aim", "fire", "idle"])
	var torch: SpotLight3D = s.get_node_or_null("Torch")
	if torch and _brute and _squad.size() > 0:
		var src: Vector3 = (_squad[0] as Node3D).position + Vector3(0, 1.6, 0)
		torch.position = src
		var aimp: Vector3 = _brute.position + Vector3(0, 1.5, 0) + Vector3(sin(t * 3.0) * 0.4, 0, 0) * (1.0 - smoothstep(48.0, 50.0, t))
		torch.look_at(o + aimp, Vector3.UP)
		torch.light_energy = 7.0 * smoothstep(46.5, 47.5, t)
	# the shot at 53.5: the muzzle flashes, then black
	_flash.light_energy = 6.0 if t > 53.5 and fmod(t * 14.0, 1.0) < 0.5 and t < 54.6 else 0.0
	if _squad.size() > 0:
		_flash.position = (_squad[0] as Node3D).position + Vector3(0, 1.4, -0.8)
	# the camera
	if t < 9.0:
		# wide over the field: the craft comes down behind the coop
		_cam.fov = 48.0
		_cam.global_position = o + Vector3(lerpf(14.0, 11.0, t / 9.0), 2.2, 18.0)
		_cam.look_at(o + Vector3(-4, lerpf(9.0, 2.5, t / 9.0), -16), Vector3.UP)
	elif t < 16.0:
		# low by the path: the man runs at us, the light behind him
		_cam.fov = 50.0
		_cam.global_position = o + Vector3(4.2, 0.8, 10.5)
		_cam.look_at(o + (_civ.position if _civ else Vector3.ZERO) + Vector3(0, 1.2, 0), Vector3.UP)
	elif t < 27.0:
		if _hound and t < 22.0:
			# down by the fence: something sniffs along it
			_cam.fov = 42.0
			_cam.global_position = o + Vector3(lerpf(6.8, 6.2, (t - 16.0) / 6.0), 0.55, 9.0)
			_cam.look_at(o + _hound.position + Vector3(0, 0.6, 0), Vector3.UP)
		else:
			# the yard from behind the hay: the shape that walks after him
			_cam.fov = 40.0
			_cam.global_position = o + Vector3(5.5, 1.1, -4.0)
			_cam.look_at(o + (_grey.position if _grey else Vector3(-6, 0, -8)) + Vector3(0, 1.1, 0), Vector3.UP)
	elif t < 37.5:
		# the helicopter comes in over the trees, its searchlight sweeps the field
		_cam.fov = 50.0
		_cam.global_position = o + Vector3(-2.0, 1.4, 14.0)
		_cam.look_at(o + (_heli.position if _heli else Vector3(11, 4, 12)) + Vector3(0, 0.5, 0), Vector3.UP)
	elif t < 41.5:
		# they jump out of the helicopter: from its side, the yard behind them
		_cam.fov = 50.0
		_cam.global_position = o + Vector3(4.5, 1.5, 15.5)
		_cam.look_at(o + Vector3(10.0, 1.0, 11.0), Vector3.UP)
	elif t < 46.0:
		# over their shoulders towards the yard
		_cam.fov = 52.0
		var lead: Node3D = _squad[1] if _squad.size() > 1 else null
		var at := (lead.position if lead else Vector3(4, 0, 6)) + Vector3(1.2, 1.7, 3.2)
		_cam.global_position = o + at
		_cam.look_at(o + Vector3(-2, 1.0, -8), Vector3.UP)
	else:
		# from the side in the dark: the big one steps into their lamps
		_cam.fov = 46.0
		var k := smoothstep(46.0, 54.0, t)
		_cam.global_position = o + Vector3(lerpf(-13.5, -12.0, k), 1.4, lerpf(-0.2, -0.8, k))
		var mid := (_brute.position if _brute else Vector3(-2.2, 0, -8.5)).lerp(Vector3(2.5, 0, 2.0), 0.5)
		_cam.look_at(o + mid + Vector3(0, 1.4, 0), Vector3.UP)

# ---------------------------------------------------------------- bodies

func _pose(m: Dictionary, delta: float) -> void:
	var sk: Skeleton3D = m["sk"]
	var clip: Dictionary = m["clip"]
	if sk == null or clip.is_empty() or not (m["node"] as Node3D).is_visible_in_tree():
		return
	m["t"] = float(m["t"]) + delta * (float(m["speed"]) if float(m["speed"]) > 0.0 else 1.0)
	var t := AnimClips.clip_time(clip, float(m["t"]))
	var p := AnimClips.pose(clip, t)
	for bn in p:
		var i := sk.find_bone(bn)
		if i >= 0:
			sk.set_bone_pose_rotation(i, sk.get_bone_rest(i).basis.get_rotation_quaternion() * Quaternion.from_euler(p[bn]))
	if AnimClips.has_track(clip, "root@pos"):
		var ri := sk.find_bone("root")
		if ri >= 0:
			var v := AnimClips.sample(clip, "root@pos", t)
			sk.set_bone_pose_position(ri, sk.get_bone_rest(ri).origin + Vector3(0, float(v[1]), 0))

## The rifle in a soldier's hands as in the game: the grip in the right hand, the barrel to the left one.
func _hold(g: Dictionary) -> void:
	var sk: Skeleton3D = g["sk"]
	var gun: Node3D = g["gun"]
	var holder: Node3D = g["holder"]
	var model: Node3D = g["model"]
	holder.visible = model.is_visible_in_tree()
	if not holder.visible:
		return
	var hr := sk.find_bone("hand.R")
	var hl := sk.find_bone("hand.L")
	var sp := sk.find_bone("spine")
	if hr < 0 or hl < 0:
		return
	sk.force_update_all_bone_transforms()
	var r := sk.global_transform * sk.get_bone_global_pose(hr)
	var l := sk.global_transform * sk.get_bone_global_pose(hl)
	var dir := (l.origin - r.origin).normalized()
	var up := (sk.global_transform.basis * sk.get_bone_global_pose(sp).basis).y.normalized() if sp >= 0 else Vector3.UP
	if absf(dir.dot(up)) > 0.97:
		up = Vector3.UP
	var B := Basis.looking_at(dir, up)
	holder.global_transform = PLAYER.afk_gun_xform(B, r.origin, gun, Vector3.ONE, "rifle")

# ---------------------------------------------------------------- the end

func _make_logo() -> Control:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t1 := Label.new()
	t1.text = "OPERACE X"
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t1.add_theme_font_size_override("font_size", 40)
	t1.add_theme_color_override("font_color", Color(0.9, 0.75, 0.35))
	box.add_child(t1)
	var t2 := Label.new()
	t2.text = "ENEMY BEYOND"
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t2.add_theme_font_size_override("font_size", 14)
	t2.add_theme_color_override("font_color", Color(0.75, 0.75, 0.72))
	box.add_child(t2)
	box.modulate.a = 0.0
	return box

func _logo_update(t: float) -> void:
	# after the black: the name comes up (87.5..89.5), stays, goes (93..95)
	var a := clampf((t - 87.5) / 2.0, 0.0, 1.0) * (1.0 - clampf((t - 93.0) / 2.0, 0.0, 1.0))
	_logo.modulate.a = a

func _input(e: InputEvent) -> void:
	if _done or not skippable or _real < 0.4:
		return
	if (e is InputEventKey and e.pressed and not e.echo) or (e is InputEventMouseButton and e.pressed) or (e is InputEventJoypadButton and e.pressed):
		get_viewport().set_input_as_handled()
		finish()

## Ends it (skipped or over): a short fade, then the menu.
func finish() -> void:
	if _done:
		return
	_done = true
	if _music:
		var tw0 := create_tween()
		tw0.tween_property(_music, "volume_db", -40.0, 0.5)
	var tw := create_tween()
	tw.tween_property(_black, "color:a", 1.0, 0.35)
	tw.tween_callback(func():
		finished.emit()
		queue_free())

## Jumps to a film time (the autotest's pictures).
func seek(film_t: float) -> void:
	var acc := 0.0
	var film := 0.0
	var real := film_t
	for i in 3:
		if film_t < film + PART[i]:
			real = acc + (film_t - film) / PART[i] * _seg[i]
			break
		acc += _seg[i]
		film += PART[i]
		real = acc + (film_t - film)
	_real = real

const RADAR_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float time = 0.0;
uniform float blip = 0.0;
void fragment() {
	vec2 p = (UV - 0.5) * vec2(1.3, 1.0) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float sweep = mod(a - time * 1.6, 6.2831853) / 6.2831853;
	float trail = pow(1.0 - sweep, 6.0) * step(r, 0.95);
	float rings = step(0.985, fract(r * 4.0)) * 0.35 + step(0.995, 1.0 - abs(p.x)) * 0.0;
	float cross = (step(abs(p.x), 0.006) + step(abs(p.y), 0.006)) * 0.3 * step(r, 0.95);
	vec2 bp = vec2(-0.32, -0.22);
	float b = (1.0 - smoothstep(0.02, 0.05, length(p - bp))) * blip * (0.6 + 0.4 * sin(time * 9.0));
	vec3 c = vec3(0.05, 0.9, 0.35) * (trail * 0.8 + rings + cross) + vec3(1.0, 0.25, 0.2) * b * 3.0;
	c *= step(r, 1.0);
	c += vec3(0.0, 0.05, 0.02);
	ALBEDO = c;
}
"""
