extends Node3D
## One mission: builds the night, the random map, spawns the team and the
## aliens (the host decides, everybody sees the same), judges the end.

const PlayerScript := preload("res://scripts/player.gd")
const AlienScript := preload("res://scripts/alien.gd")
const MeleeScript := preload("res://scripts/melee_alien.gd")
const DroneScript := preload("res://scripts/drone_alien.gd")
const CivScript := preload("res://scripts/civilian.gd")
const MapGen := preload("res://scripts/map_gen.gd")
const Hud := preload("res://scripts/hud.gd")

var map := {}
var actors: Node3D
var spawner: MultiplayerSpawner
var hud: CanvasLayer
var voice: Node
var music: AudioStreamPlayer
var _ready_peers := {}
var _spawned := false
var finished := false
var aliens_total := 0
var next_alien_id := 0
var civs_total := 0
var crew_names := []
var crew_group := ""
var hit_kind := ""          # what is hitting an alien right now: bullet / plasma / explosion        # races on this mission (for the result / archive)
var t := 0.0
var combat_t := -100.0     # last time an alien fired
var _amb_t := 14.0
var _stalk_t := 80.0
var _cows := 2
const CALM_TIME := 60.0
var env: Environment
var moon: DirectionalLight3D
var _flash_t := 0.0          # lightning
var _storm_t := 35.0
var _radio_done := {}
var _power_out := false
var rain: CPUParticles3D
var _phantom: Node3D
var _phantom_t := 0.0
var _hallu_t := 20.0

## Weather: chosen from the mission seed (every machine picks the same) unless the
## mission says. storm = rain + lightning, rain, fog, overcast, clear (moonlit).
const WEATHER_NAMES := {"snow": "sněží", "storm": "bouřka", "rain": "déšť", "fog": "hustá mlha", "overcast": "zataženo, tma", "clear": "jasno, svítí měsíc"}
var weather := "storm"
var _moon_base := 0.12
var _amb_base := 0.2
var _fog_base := 0.07
var _bg_base := Color(0.015, 0.02, 0.045)
var _wind_base := 1.0

func _pick_weather() -> void:
	var w: String = Net.mission_params.get("weather", Game.cmd_arg("weather", ""))
	if w == "" or not WEATHER_NAMES.has(w):
		var r := RandomNumberGenerator.new()
		r.seed = Net.mission_seed * 31 + 7
		var x := r.randf()
		w = "storm" if x < 0.28 else ("rain" if x < 0.46 else ("fog" if x < 0.66 else ("overcast" if x < 0.82 else "clear")))
	# snow country: rain falls as snow
	if Net.mission_params.get("terrain", "") == "snow" and (w == "rain" or w == "storm"):
		w = "snow"
	elif Net.mission_params.get("terrain", "") == "desert" and (w == "rain" or w == "fog"):
		w = "clear"
	weather = w

# ---- ready check: after the briefing everyone confirms; the night starts together ----------
var go := false
var ready_ids := {}

## Called by the local HUD when this player presses "ready".
func i_am_ready() -> void:
	_set_ready.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func _set_ready() -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	ready_ids[id if id != 0 else 1] = true
	_ready_state()

func _ready_state() -> void:
	var need: Array = Net.roster.keys() if not Net.roster.is_empty() else [1]
	var n := 0
	for id in need:
		if ready_ids.has(id):
			n += 1
	_ready_sync.rpc(n, need.size(), n >= need.size())

@rpc("authority", "call_local", "reliable")
func _ready_sync(n: int, total: int, all: bool) -> void:
	if hud:
		hud.ready_count(n, total)
	if all and not go:
		go = true
		if hud:
			hud.brief_go()

## How much louder footsteps are on this ground (snow crunches).
func step_noise() -> float:
	return 1.6 if map.get("terrain", "") == "snow" else 1.0

## Rain drowns what the aliens do: their sounds are quieter for the team.
func alien_db() -> float:
	return {"rain": -7.0, "storm": -10.0, "snow": -3.0}.get(weather, 0.0)

func calm() -> bool:
	return t < CALM_TIME

func _ready() -> void:
	name = "Mission"
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_pick_weather()
	_environment()
	_post_filter()
	map = MapGen.new().build(self, Net.mission_seed, Net.mission_params)
	actors = Node3D.new()
	actors.name = "Actors"
	add_child(actors)
	spawner = MultiplayerSpawner.new()
	spawner.name = "Spawner"
	add_child(spawner)
	spawner.spawn_path = spawner.get_path_to(actors)
	spawner.spawn_function = _spawn
	hud = Hud.new()
	add_child(hud)
	voice = preload("res://scripts/voice.gd").new()
	add_child(voice)
	# no music: wind, silence and what moves in it
	music = AudioStreamPlayer.new()
	var st: AudioStreamWAV = Game.sound("wind")
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_end = st.data.size() / 2
	music.stream = st
	music.volume_db = -12
	add_child(music)
	music.play()
	if weather == "storm" or weather == "rain":
		_loop_player(AudioStreamPlayer.new(), "rain", -17.0 if weather == "storm" else -20.0)
	for snd in map["sounds"]:
		var ap := AudioStreamPlayer3D.new()
		ap.unit_size = 2.0
		ap.max_distance = 25.0
		add_child(ap)
		ap.global_position = snd["pos"]
		_loop_player(ap, snd["name"], snd["db"])
	if weather == "snow":
		_build_rain()
		rain.amount = 900
		rain.lifetime = 4.0
		rain.gravity = Vector3(0, -0.6, 0)
		rain.initial_velocity_min = 0.6
		rain.initial_velocity_max = 1.4
		rain.direction = Vector3(0.3, -1, 0.1)
		rain.spread = 25.0
		var sq := QuadMesh.new()
		sq.size = Vector2(0.04, 0.04)
		var smat := StandardMaterial3D.new()
		smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smat.albedo_color = Color(0.85, 0.88, 0.95, 0.8)
		smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		sq.material = smat
		rain.mesh = sq
	if weather == "storm" or weather == "rain":
		_build_rain()
		if weather == "rain":
			rain.amount = 380
	hud.briefing(_briefing_text() + "\nPočasí: " + WEATHER_NAMES[weather] + ".")
	multiplayer.peer_disconnected.connect(_on_peer_left)
	multiplayer.server_disconnected.connect(func(): _leave("Spojení s hostitelem bylo ztraceno."))
	if Game.autotest() != "":
		var at := Node.new()
		at.set_script(load("res://scripts/autotest.gd"))
		at.mode = Game.autotest()
		at.name = "AutoTest"
		add_child(at)
	if multiplayer.is_server():
		_ready_peers[1] = true
		_maybe_spawn()
	else:
		_client_ready.rpc_id(1)

func _loop_player(ap: Node, sname: String, db: float) -> void:
	var st: AudioStreamWAV = Game.sound(sname).duplicate()
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_end = st.data.size() / 2
	ap.stream = st
	ap.volume_db = db
	if not ap.is_inside_tree():
		add_child(ap)
	ap.play()

func _briefing_text() -> String:
	var mp: Dictionary = Net.mission_params
	if not mp.is_empty():
		var h: float = float(mp.get("hour", 2.0))
		var flavor := {
			"crash": "Malé UFO spadlo po zásahu do krajiny. Část posádky mohla přežít a hledá úkryt.",
			"landed": "UFO přistálo neporušené. Posádka je venku a něco tu dělá. Zatím neví, že o nás ví.",
			"abduction": "Z okolních stavení zmizeli lidé. Nad krajinou viděli světla. Možná ještě někdo žije.",
			"terror": "Vetřelci vtrhli do městečka. Spojení s místními je přerušeno. Poslední hovor na tísňovou linku: \"Je to černé, je to rychlé, a ti, co to zabilo, zase vstávají.\"\nZachraň, koho můžeš (E u vyděšeného civilisty - půjde za tebou do Kondoru).",
		}
		var terr: String = {"snow": "\nTerén: sníh - každý krok je slyšet.", "desert": "\nTerén: poušť - málo úkrytů."}.get(mp.get("terrain", ""), "")
		return "%s\nOblast: %s, místní čas %02d:%02d (%s), mapa %s%s\n\n%s\n\nÚKOL: zneškodnit posádku a vrátit se do Kondoru.\nOmráčení vetřelci mají pro výzkum velkou cenu. Co vetřelci upustí, posbíráme při odletu." % [
			String(mp.get("type_name", "Mise")).to_upper(), mp.get("place", "?"), int(h), int(fmod(h, 1.0) * 60),
			"noc" if mp.get("night", true) else "den", MapGen.SIZE_NAMES.get(mp.get("size", "medium"), "střední"), terr, flavor.get(mp.get("type", "crash"), "")]
	var r := RandomNumberGenerator.new()
	r.seed = Net.mission_seed
	var day := r.randi_range(3, 27)
	var hh := r.randi_range(1, 3)
	var mm := r.randi_range(0, 59)
	var places := ["u Telče", "nad Kamenicí", "u Pelhřimova", "pod Javořicí", "u Nové Bystřice"]
	return "%d. listopadu 1999, %02d:%02d\nVysočina, samota %s.\n\nRadar zachytil pád neznámého objektu. Od 23:40 nekomunikuje farma Horákových.\nPolicejní hlídka, která sem jela, se nevrátila.\n\nÚKOL: zneškodnit posádku UFO a vrátit se do Kondoru.\nPilot čeká se zapnutými motory." % [day, hh, mm, places[r.randi() % places.size()]]

func volumetric_on() -> bool:
	return Game.volumetric and RenderingServer.get_current_rendering_method() == "forward_plus"

func _post_filter() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 1
	cl.name = "RetroFilter"
	var cr := ColorRect.new()
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://shaders/post.gdshader")
	cr.material = sm
	cl.add_child(cr)
	add_child(cl)
	cl.visible = Game.retro

func set_retro(on: bool) -> void:
	var f := get_node_or_null("RetroFilter")
	if f:
		f.visible = on

func is_day() -> bool:
	return not Net.mission_params.is_empty() and not Net.mission_params.get("night", true)

func _environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.02, 0.045)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.12, 0.14, 0.22)
	env.ambient_light_energy = 0.2
	env.fog_enabled = true
	env.fog_light_color = Color(0.03, 0.04, 0.08)
	env.fog_density = 0.07
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	if volumetric_on():
		# light you can see: the torch beam in the rain, the UFO's glow in the mist
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.028
		env.volumetric_fog_albedo = Color(0.55, 0.6, 0.7)
		env.volumetric_fog_emission = Color(0.006, 0.008, 0.016)
		env.volumetric_fog_anisotropy = 0.7
		env.volumetric_fog_length = 48.0
		env.volumetric_fog_ambient_inject = 0.15
		env.fog_density = 0.02
		env.glow_enabled = true
		env.glow_intensity = 0.6
		env.glow_bloom = 0.05
		env.glow_hdr_threshold = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.62, 0.9)
	moon.light_energy = 0.12
	moon.shadow_enabled = true
	if is_day():
		# overcast daylight: grey, flat, still uneasy
		env.background_color = Color(0.42, 0.45, 0.5)
		env.ambient_light_color = Color(0.55, 0.58, 0.62)
		env.ambient_light_energy = 0.9
		env.fog_light_color = Color(0.5, 0.52, 0.56)
		env.fog_density = 0.025
		env.volumetric_fog_density = 0.01
		moon.light_color = Color(0.9, 0.9, 0.85)
		moon.light_energy = 0.9
	moon.rotation_degrees = Vector3(-35, 40, 0)
	add_child(moon)
	_weather_env()

## Light, fog and wind by the weather (night values; day keeps its flat grey light).
func _weather_env() -> void:
	var vol := volumetric_on()
	var day := is_day()
	match weather:
		"clear":
			# a cold moon: you see further - and so do they
			if not day:
				moon.light_energy = 0.35
				env.ambient_light_energy = 0.3
				env.background_color = Color(0.03, 0.045, 0.09)
			env.fog_density = 0.006 if vol else 0.03
			env.volumetric_fog_density = 0.008
			_wind_base = 0.6
		"fog":
			# the torch only lights a grey wall
			env.fog_density = 0.05 if vol else 0.14
			env.volumetric_fog_density = 0.07
			env.fog_light_color = Color(0.08, 0.09, 0.1) if not day else Color(0.6, 0.62, 0.64)
			_wind_base = 0.25
		"overcast":
			if not day:
				moon.light_energy = 0.05
				env.ambient_light_energy = 0.14
				env.background_color = Color(0.008, 0.01, 0.02)
			_wind_base = 0.9
		"rain":
			_wind_base = 1.1
		"snow":
			# snow throws the little light back: brighter, but the falling flakes close the distance
			env.ambient_light_energy *= 1.6
			env.fog_density = 0.035 if vol else 0.07
			env.fog_light_color = Color(0.25, 0.27, 0.32)
			_wind_base = 0.7
		"storm":
			_wind_base = 1.5
	_moon_base = moon.light_energy
	_amb_base = env.ambient_light_energy
	_fog_base = env.fog_density
	_bg_base = env.background_color

# ---- spawning (host decides, MultiplayerSpawner replicates) -------------------
@rpc("any_peer", "reliable")
func _client_ready() -> void:
	_ready_peers[multiplayer.get_remote_sender_id()] = true
	_maybe_spawn()

func _maybe_spawn() -> void:
	if _spawned:
		return
	for id in Net.roster:
		if not _ready_peers.has(id):
			return
	_spawned = true
	var i := 0
	for id in Net.roster:
		var sp: Vector3 = map["player_spawns"][i % map["player_spawns"].size()]
		spawner.spawn({"kind": "player", "peer": id, "pos": sp, "yaw": float(map.get("spawn_yaw", PI)), "merc": Net.roster[id]["merc"], "name": Net.roster[id]["name"]})
		i += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = Net.mission_seed + 99
	var spawns: Array = map["alien_spawns"].duplicate()
	var count := 2 + Net.roster.size() + int(Net.mission_params.get("extra_aliens", 0)) + (1 if Game.veteran() else 0) + int({"large": 1, "huge": 2}.get(Net.mission_params.get("size", ""), 0))
	var crew := _crew(count, rng)
	for k in crew.size():
		var p: Vector3 = spawns[k % spawns.size()] + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1))
		if crew[k] in ["lihnoun", "ohar", "nador", "ohnivec"]:
			# these do not stay by the ship: somewhere out in the dark
			var wp: Array = map["waypoints"]
			if not wp.is_empty():
				p = _far_point(rng, 25.0)
		spawner.spawn({"kind": "alien", "id": next_alien_id, "pos": p, "race": crew[k]})
		next_alien_id += 1
		if not crew[k] in crew_names:
			crew_names.append(crew[k])
	aliens_total = crew.size()
	# civilians (terror and abduction)
	var mt: String = Net.mission_params.get("type", "")
	var nciv := 0
	if mt == "terror":
		nciv = rng.randi_range(5, 8)
	elif mt == "abduction":
		nciv = rng.randi_range(1, 3)
	for ci in nciv:
		spawner.spawn({"kind": "civ", "id": ci, "pos": _far_point(rng, 12.0)})
	civs_total = nciv

## A random walkable point at least @a min_d from the team's landing spot.
func _far_point(rng: RandomNumberGenerator, min_d: float) -> Vector3:
	var wp: Array = map["waypoints"]
	for i in 30:
		var p: Vector3 = wp[rng.randi() % wp.size()] + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
		if p.distance_to(map["evac"]) > min_d:
			return p   # (the nav map is not synced yet at spawn time)
	return wp[0]

## The alien groups, as in the old game: who serves with whom, and the terror
## creature each group brings. "from": campaign month from which the group appears.
const GROUPS := {
	"sedaci": {"name": "Šeďáci", "soldier": "grey", "officer": "grey_velitel", "beast": "diskoll", "terror": "diskoll", "from": 0},
	"levite": {"name": "Levité", "soldier": "levit", "officer": "levit", "beast": "ohar", "terror": "ohar", "from": 0},
	"jestetani": {"name": "Ještěřani", "soldier": "jestetan", "officer": "jestetan_velitel", "beast": "lihnoun", "terror": "lihnoun", "from": 1},
	"bijci": {"name": "Bijci", "soldier": "bijec", "officer": "bijec_velitel", "beast": "nador", "terror": "ohnivec", "from": 2},
	"myslodejove": {"name": "Myslodějové", "soldier": "bijec", "officer": "myslodej", "beast": "kolos", "terror": "kolos", "from": 3},
}

## Who is on board: one group per ship, soldiers, an officer on bigger ships,
## their beasts or machines; on terror missions their terror creatures.
func _crew(count: int, rng: RandomNumberGenerator) -> Array:
	var forced := Game.cmd_arg("crew", "")
	if forced != "":
		return forced.split(",")
	var mp: Dictionary = Net.mission_params
	var mt: String = mp.get("type", "crash")
	var month := int(Campaign.data.get("month", 0)) if Campaign.active else 3
	var gid: String = mp.get("group", "")
	if gid == "" or not GROUPS.has(gid):
		var pool := []
		for g in GROUPS:
			if int(GROUPS[g]["from"]) <= month:
				pool.append(g)
		if mt == "terror" and "jestetani" in pool:
			pool.append("jestetani")     # the lizards and their hatchlings love a town
			pool.append("jestetani")
		gid = pool[rng.randi() % pool.size()]
	var g: Dictionary = GROUPS[gid]
	var out := []
	var big: bool = count >= 5 or mt == "landed" or String(mp.get("ufo", "")) == "harvester"
	if mt == "terror":
		var nt := clampi(1 + count / 3, 1, 3)
		for i in nt:
			out.append(g["terror"])
		if gid == "bijci":
			out.append("nador")
	else:
		if big or rng.randf() < 0.3:
			out.append(g["officer"])
		if count >= 4 or rng.randf() < 0.4:
			out.append(g["beast"])
		if gid == "bijci" and count >= 6:
			out.append("ohnivec")
	while out.size() < count:
		out.append(g["soldier"])
	crew_group = gid
	return out.slice(0, max(count + 1, 1))

## Host: brings a new alien into the mission (a Líhnoun hatching, a victim rising).
func spawn_alien(race: String, pos: Vector3) -> void:
	if not multiplayer.is_server():
		return
	spawner.spawn({"kind": "alien", "id": next_alien_id, "pos": pos, "race": race})
	next_alien_id += 1
	aliens_total += 1
	if not race in crew_names:
		crew_names.append(race)

func _spawn(data: Variant) -> Node:
	if data["kind"] == "player":
		var p := CharacterBody3D.new()
		p.set_script(PlayerScript)
		p.name = "P%d" % data["peer"]
		p.set_multiplayer_authority(data["peer"])
		p.setup(data)
		return p
	if data["kind"] == "civ":
		var c := CharacterBody3D.new()
		c.set_script(CivScript)
		c.name = "C%d" % data["id"]
		c.setup(data)
		return c
	var a := CharacterBody3D.new()
	var race: String = data.get("race", "grey")
	if race in ["lihnoun", "zombie", "ohar"]:
		a.set_script(MeleeScript)
	elif race == "diskoll" or race == "kolos":
		a.set_script(DroneScript)
	else:
		a.set_script(AlienScript)
	a.name = "A%d" % data["id"]
	a.setup(data)
	return a

# ---- queries used by players and aliens -----------------------------------------
func players() -> Array:
	var out := []
	for c in actors.get_children():
		if c.has_method("is_player"):
			out.append(c)
	return out

func aliens() -> Array:
	var out := []
	for c in actors.get_children():
		if c.has_method("is_alien"):
			out.append(c)
	return out

func civilians() -> Array:
	var out := []
	for c in actors.get_children():
		if c.has_method("is_civilian"):
			out.append(c)
	return out

## A mercenary pressed E by a civilian (sent to the host).
@rpc("any_peer", "call_local", "reliable")
func calm_civ(civ_name: String, player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var c := actors.get_node_or_null(civ_name)
	var p := actors.get_node_or_null(player_name)
	if c and p:
		c.calm_by(p)

@rpc("any_peer", "call_local", "reliable")
func shoot_civ(civ_name: String) -> void:
	var c := actors.get_node_or_null(civ_name)
	if multiplayer.is_server() and c and not c.dead:
		c.killed_by("bullet")

## Blood spray where a claw or a maw hit (every machine).
func blood_fx(p: Vector3) -> void:
	var cp := CPUParticles3D.new()
	cp.one_shot = true
	cp.emitting = true
	cp.amount = 24
	cp.lifetime = 0.7
	cp.explosiveness = 0.95
	cp.direction = Vector3(0, 0.5, 0)
	cp.spread = 70.0
	cp.initial_velocity_min = 1.5
	cp.initial_velocity_max = 4.0
	cp.gravity = Vector3(0, -9.8, 0)
	var qm := QuadMesh.new()
	qm.size = Vector2(0.05, 0.05)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(0.35, 0.02, 0.02)
	qm.material = m
	cp.mesh = qm
	add_child(cp)
	cp.global_position = p
	get_tree().create_timer(1.5).timeout.connect(cp.queue_free)

## Acid or lava splashing where a spit landed (every machine).
func splash_fx(p: Vector3, kind: String) -> void:
	var cp := CPUParticles3D.new()
	cp.one_shot = true
	cp.emitting = true
	cp.amount = 20
	cp.lifetime = 0.8
	cp.explosiveness = 0.9
	cp.direction = Vector3(0, 1, 0)
	cp.spread = 60.0
	cp.initial_velocity_min = 1.0
	cp.initial_velocity_max = 3.0
	cp.gravity = Vector3(0, -9.8, 0)
	var qm := QuadMesh.new()
	qm.size = Vector2(0.06, 0.06)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(0.65, 0.95, 0.15) if kind == "acid" else Color(1.0, 0.45, 0.05)
	qm.material = m
	cp.mesh = qm
	add_child(cp)
	cp.global_position = p
	var l := OmniLight3D.new()
	l.light_color = m.albedo_color
	l.light_energy = 2.0
	l.omni_range = 3.0
	add_child(l)
	l.global_position = p + Vector3(0, 0.3, 0)
	Game.play_at(self, "slash", p, -6)
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, 2.5 if kind == "lava" else 1.0)
	tw.tween_callback(func(): l.queue_free(); cp.queue_free())

## A violet shimmer around an alien a Mysloděj strengthened (every machine).
func psi_glow(n: Node3D) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(0.7, 0.3, 1.0)
	l.light_energy = 3.0
	l.omni_range = 4.0
	n.add_child(l)
	l.position = Vector3(0, 1.2, 0)
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, 1.5)
	tw.tween_callback(l.queue_free)

## A Líhnoun tearing its way out of a body.
@rpc("authority", "call_local", "reliable")
func burst_fx(p: Vector3) -> void:
	blood_fx(p)
	blood_fx(p + Vector3(0, 0.3, 0))
	Game.play_at(self, "burst", p, 2)
	var me := local_player()
	if me and me.global_position.distance_to(p) < 20.0:
		me.stress = min(100.0, me.stress + 25.0)
		hud.message("Z těla se něco prodírá ven...", 3.0)

func local_player() -> Node:
	for p in players():
		if p.is_multiplayer_authority():
			return p
	return null

## A sound the aliens may hear (any machine may report; the host decides).
func noise(pos: Vector3, radius: float) -> void:
	if multiplayer.is_server():
		for a in aliens():
			a.hear(pos, radius)
		for c in civilians():
			c.hear(pos, radius)
	else:
		_noise.rpc_id(1, pos, radius)

@rpc("any_peer", "unreliable")
func _noise(pos: Vector3, radius: float) -> void:
	noise(pos, radius)

# ---- the end ------------------------------------------------------------------------
func _process(delta: float) -> void:
	if go:
		t += delta
	for l in map.get("lights", []):
		if is_instance_valid(l):
			l.light_energy = 1.4 + sin(t * 13.0) * 0.25 + sin(t * 7.3) * 0.2
	_electric(delta)
	_mines_tick()
	_storm_fx(delta)
	_hallucinate(delta)
	if multiplayer.is_server() and _spawned and not finished:
		_judge()
		_director(delta)
		_risen()

## Host: a mercenary who bled out with a Líhnoun's seed inside does not stay down.
func _risen() -> void:
	for p in players():
		if p.dead and p.infected and not p.has_meta("risen"):
			p.set_meta("risen", true)
			var at: Vector3 = p.global_position
			get_tree().create_timer(6.0).timeout.connect(func():
				if not finished:
					_hide_body.rpc(p.name)
					burst_fx.rpc(at + Vector3(0, 0.6, 0))
					spawn_alien("zombie", at))

@rpc("authority", "call_local", "reliable")
func _hide_body(pname: String) -> void:
	var p := actors.get_node_or_null(pname)
	if p:
		p.body.visible = false
		if p.is_multiplayer_authority():
			hud.message("Tvé tělo vstává. Už to nejsi ty.", 6.0)

# ---- the farm's electricity: dies when they come close ------------------------------------
## Moths circling a lamp - small grey specks, only while the light burns.
func _moths(l: Light3D) -> Node3D:
	var p := CPUParticles3D.new()
	p.amount = 14
	p.lifetime = 3.0
	p.preprocess = 3.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.6
	p.gravity = Vector3.ZERO
	p.orbit_velocity_min = 0.6
	p.orbit_velocity_max = 1.4
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.8
	p.direction = Vector3(0, 1, 0)
	p.spread = 180.0
	p.radial_accel_min = -1.5
	p.radial_accel_max = -0.6
	p.tangential_accel_min = 1.0
	p.tangential_accel_max = 3.0
	p.particle_flag_rotate_y = false
	var qm := QuadMesh.new()
	qm.size = Vector2(0.035, 0.035)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(0.75, 0.7, 0.6)
	qm.material = m
	p.mesh = qm
	l.add_child(p)
	p.position = Vector3(0, -0.3, 0)
	return p

var _elec_t := 0.0
func _electric(delta: float) -> void:
	_elec_t -= delta
	if _elec_t > 0:
		return
	_elec_t = 0.07
	for l in map.get("elec_lights", []):
		if not is_instance_valid(l):
			continue
		var base: float = l.get_meta("base", 1.0)
		var near := 99.0
		for a in aliens():
			if not a.dead:
				near = min(near, a.global_position.distance_to(l.global_position))
		var e := base
		if _power_out:
			e = 0.0
		elif near < 14.0 and randf() < 0.25 + (14.0 - near) / 14.0 * 0.6:
			e = base * randf_range(0.0, 0.4)
		elif randf() < 0.01:
			e = base * 0.3     # a tired battery, an old wire
		l.light_energy = e
		if not l.has_meta("moths"):
			l.set_meta("moths", _moths(l))
		var mo: Node3D = l.get_meta("moths")
		if is_instance_valid(mo):
			mo.visible = e > base * 0.5
		var lens: Node = l.get_meta("lens", null)
		if lens:
			lens.visible = e > base * 0.2

# ---- storm: lightning shows for a blink what stands in the field ----------------------------
func _build_rain() -> void:
	rain = CPUParticles3D.new()
	rain.amount = 700
	rain.lifetime = 0.9
	rain.preprocess = 1.0
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(9, 0.5, 9)
	rain.direction = Vector3(0.15, -1, 0.05)
	rain.spread = 3.0
	rain.gravity = Vector3(0, -9, 0)
	rain.initial_velocity_min = 14.0
	rain.initial_velocity_max = 17.0
	rain.local_coords = false
	var qm := QuadMesh.new()
	qm.size = Vector2(0.015, 0.35)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.55, 0.6, 0.7, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	qm.material = mat
	rain.mesh = qm
	add_child(rain)

func _storm_fx(delta: float) -> void:
	# wind for trees, wheat and grass: a slow swell, a shove with every lightning
	var ws := (1.0 + 0.45 * sin(t * 0.13) + 0.25 * sin(t * 0.41 + 1.0)) * _wind_base + (0.8 if _flash_t > 0 else 0.0)
	RenderingServer.global_shader_parameter_set("wind_strength", ws)
	var me := local_player()
	if me and rain:
		rain.global_position = me.global_position + Vector3(0, 7, 0) + me.velocity * 0.4
	if _flash_t > 0:
		_flash_t -= delta
		# a double flash: bright, dark, bright
		var on := _flash_t > 0.28 or (_flash_t > 0.06 and _flash_t < 0.16)
		moon.light_energy = 2.6 if on else _moon_base
		env.ambient_light_energy = 1.3 if on else _amb_base
		env.background_color = Color(0.35, 0.38, 0.5) if on else _bg_base
		env.fog_density = _fog_base * 0.5 if on else _fog_base
		if _flash_t <= 0:
			moon.light_energy = _moon_base
			env.ambient_light_energy = _amb_base
			env.background_color = _bg_base
			env.fog_density = _fog_base

@rpc("authority", "call_local", "reliable")
func _lightning(thunder_delay: float) -> void:
	_flash_t = 0.4
	get_tree().create_timer(thunder_delay).timeout.connect(func(): Game.play_ui(self, "thunder", -3))

# ---- radio: the pilot, and something else on the frequency ----------------------------------
@rpc("authority", "call_local", "reliable")
func _radio(text: String, secs: float) -> void:
	Game.play_ui(self, "radio", -8)
	if Game.autotest() != "": print("[RADIO] t=%.0f %s" % [t, text])
	hud.message("[RÁDIO] " + text, secs)

func _radio_once(key: String, text: String, secs := 5.0) -> void:
	if _radio_done.has(key):
		return
	_radio_done[key] = true
	_radio.rpc(text, secs)

@rpc("authority", "call_local", "reliable")
func _knock() -> void:
	Game.play_at(self, "knock", map["evac"] + Vector3(0, 1.5, -2.0), 4.0)

@rpc("authority", "call_local", "reliable")
func _blackout() -> void:
	_power_out = true
	Game.play_ui(self, "creak", -6)

## Things only a frightened mercenary sees and hears. Local, never synced.
func _hallucinate(delta: float) -> void:
	var p := local_player()
	if p == null or p.dead or p.downed or p.cam == null:
		return
	if _phantom:
		_phantom_t -= delta
		var to: Vector3 = _phantom.global_position + Vector3(0, 1.0, 0) - p.cam.global_position
		var look: float = (-p.cam.global_transform.basis.z).dot(to.normalized())
		if _phantom_t <= 0 or look > 0.995 or to.length() < 6.0:
			_phantom.queue_free()
			_phantom = null
		return
	_hallu_t -= delta
	if _hallu_t > 0 or p.stress < 55.0:
		return
	_hallu_t = randf_range(12.0, 30.0) * (1.6 - p.stress / 100.0)
	var r := randf()
	if r < 0.45:
		# a figure at the very edge of the light
		var side := 1.0 if randf() < 0.5 else -1.0
		var dir: Vector3 = (-p.cam.global_transform.basis.z).rotated(Vector3.UP, side * randf_range(0.26, 0.36))
		dir.y = 0
		var pos: Vector3 = p.global_position + dir.normalized() * randf_range(9.0, 15.0)
		_phantom = Node3D.new()
		add_child(_phantom)
		_phantom.global_position = pos
		_phantom.look_at(p.global_position, Vector3.UP)
		var dark := Game.color_mat(Color(0.09, 0.09, 0.1))
		for part in [[Vector3(0, 0.6, 0), Vector3(0.34, 0.6, 0.22)], [Vector3(0, 0.15, 0), Vector3(0.28, 0.3, 0.2)]]:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = part[1]
			mi.mesh = bm
			mi.material_override = dark
			_phantom.add_child(mi)
			mi.position = part[0]
		var head := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.24; sm.height = 0.55
		head.mesh = sm
		head.material_override = dark
		_phantom.add_child(head)
		head.position = Vector3(0, 1.15, 0)
		_phantom_t = randf_range(1.0, 2.5)
	elif r < 0.75:
		# footsteps right behind you
		var back: Vector3 = p.global_transform.basis.z * 2.5
		for i in 3:
			get_tree().create_timer(i * 0.45).timeout.connect(func(): if is_instance_valid(p): Game.play_at(self, "step", p.global_position + back, -8))
	else:
		var back2: Vector3 = p.global_transform.basis.z.rotated(Vector3.UP, randf_range(-1, 1)) * 3.0
		Game.play_at(self, "whisper", p.global_position + back2 + Vector3(0, 1.5, 0), -4)

# ---- the director: builds tension instead of throwing enemies at you ----------------
func _director(delta: float) -> void:
	var ps := []
	for p in players():
		if not p.dead:
			ps.append(p)
	if ps.is_empty():
		return
	_story(ps)
	# the storm: sometimes the flash comes exactly when one of them is close
	_storm_t -= delta
	var reveal := false
	if _storm_t < 15.0 and not calm():
		for a in aliens():
			if a.dead: continue
			for p in ps:
				var d: float = a.global_position.distance_to(p.global_position)
				if d < 22.0 and d > 7.0 and not a.visible_to(p):
					reveal = randf() < 0.02
	if (_storm_t <= 0 or reveal) and weather == "storm":
		_storm_t = randf_range(30.0, 75.0)
		_lightning.rpc(randf_range(0.8, 3.0))
	elif _storm_t <= 0:
		_storm_t = randf_range(60.0, 120.0)
		if weather == "rain":
			# far away thunder, no flash
			Game.play_ui(self, "thunder", -16)
	# sounds from the dark, mostly behind somebody
	_amb_t -= delta
	if _amb_t <= 0:
		_amb_t = randf_range(14.0, 32.0)
		var p: Node = ps[randi() % ps.size()]
		var behind: Vector3 = p.global_transform.basis.z.rotated(Vector3.UP, randf_range(-1.0, 1.0))
		var pos: Vector3 = p.global_position + behind * randf_range(10.0, 25.0) + Vector3(0, 0.5, 0)
		var pick := ["rustle", "rustle", "distant", "creak"]
		if _cows > 0 and t > 30.0 and randf() < 0.3:
			pick = ["cow"]
			_cows -= 1
			pos = p.global_position + behind * 35.0
		var sname: String = pick[randi() % pick.size()]
		_ambient.rpc(sname, pos, -2.0 if sname != "distant" else 2.0)
	# after the quiet start, now and then one of them goes hunting a lone merc
	_stalk_t -= delta
	if _stalk_t <= 0 and not calm():
		_stalk_t = randf_range(35.0, 60.0)
		if t - combat_t > 20.0:
			var prey: Node = null
			var best := -1.0
			for p in ps:
				if p.downed: continue
				var dmin := 1e9
				for o in ps:
					if o != p: dmin = min(dmin, o.global_position.distance_to(p.global_position))
				if dmin > best:
					best = dmin
					prey = p
			var hunter: Node = null
			for a in aliens():
				if not a.dead and a.state == a.S.LURK and (hunter == null or a.global_position.distance_to(prey.global_position) < hunter.global_position.distance_to(prey.global_position)):
					hunter = a
			if prey and hunter:
				hunter.stalk(prey)

## Scripted beats that make the night feel like it has a story.
func _story(ps: Array) -> void:
	if t > 12.0:
		_radio_once("start", "Pilot: Kondor na zemi. Motory nechávám běžet. Ozvěte se, až budete mít posádku.", 6.0)
	if t > 95.0:
		_radio_once("knock", "Pilot: ...něco mi klepe na trup. Asi kroupy. Asi.", 5.0)
		if _radio_done.has("knock") and not _radio_done.has("knock_snd"):
			_radio_done["knock_snd"] = true
			_knock.rpc()
	if t > 150.0 and map["barn"] != Vector3.ZERO:
		if not _radio_done.has("lure"):
			_radio_once("lure", "...pro-sím... je tu někdo?... stodola... jsem ve sto...", 6.0)
			# the voice was not the farmer's: one of them waits in the barn
			for a in aliens():
				if not a.dead and a.state == a.S.LURK:
					a.lurk_at(map["barn"])
					break
	if t > 210.0 and not _radio_done.has("power"):
		_radio_done["power"] = true
		_blackout.rpc()
		_radio.rpc("Pilot: Přišli jste o světla na farmě? Mně taky zhasly přístroje. Pospěšte si.", 6.0)
	if alive_aliens() == 0:
		_radio_once("clear", "Pilot: Detektory jsou tiché. Vraťte se na palubu. Hned.", 6.0)
	for p in ps:
		if p.downed:
			_radio_once("down_" + p.name, "Pilot: Ztrácím signál od %s! Někdo k němu běžte!" % p.display_name, 5.0)

# ---- rockets, explosions, smoke and mines --------------------------------------------------
@rpc("any_peer", "call_local", "reliable")
func fire_rocket(from: Vector3, dir: Vector3, shooter: String) -> void:
	var r := Node3D.new()
	r.set_script(preload("res://scripts/rocket.gd"))
	r.dir = dir
	r.shooter = shooter
	r.mission = self
	add_child(r)
	r.global_position = from

## Host: damage around a point (rockets, autocannon shells, mines).
@rpc("any_peer", "call_local", "reliable")
func explode(p: Vector3, radius: float, dmg: float, by: String, big: bool) -> void:
	if not multiplayer.is_server():
		return
	_boom.rpc(p, big)
	noise(p, 50.0 if big else 30.0)
	var shooter: Node = actors.get_node_or_null(by)
	for a in aliens():
		var d: float = a.global_position.distance_to(p)
		if d < radius and not a.dead:
			hit_kind = "explosion"
			a.damage(dmg * (1.0 - d / radius) + 8.0, p, shooter)
			hit_kind = ""
	for pl in players():
		var d2: float = pl.global_position.distance_to(p)
		if d2 < radius * 0.9 and not pl.dead:
			pl.hurt.rpc_id(pl.get_multiplayer_authority(), dmg * 0.6 * (1.0 - d2 / radius), p)

@rpc("authority", "call_local", "reliable")
func _boom(p: Vector3, big: bool) -> void:
	var pl := local_player()
	if pl == null and not players().is_empty():
		pl = players()[0]
	if big:
		if pl: pl._explosion_fx(p)
	else:
		Game.play_at(self, "explosion", p, -6)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.6, 0.25)
		l.light_energy = 4.0
		l.omni_range = 5.0
		add_child(l)
		l.global_position = p
		get_tree().create_timer(0.08).timeout.connect(l.queue_free)

var smokes := []     # [{pos, until}]
const SMOKE_R := 4.5

func add_smoke(p: Vector3) -> void:
	smokes.append({"pos": p, "until": t + 28.0})
	Game.play_at(self, "rustle", p, 0)
	var c := CPUParticles3D.new()
	c.amount = 90
	c.lifetime = 6.0
	c.preprocess = 2.0
	c.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	c.emission_sphere_radius = 2.5
	c.gravity = Vector3(0, 0.05, 0)
	c.initial_velocity_min = 0.1
	c.initial_velocity_max = 0.4
	c.scale_amount_min = 2.0
	c.scale_amount_max = 4.0
	var qm := QuadMesh.new()
	qm.size = Vector2(1.6, 1.6)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.56, 0.58, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	qm.material = mat
	c.mesh = qm
	add_child(c)
	c.global_position = p + Vector3(0, 1.2, 0)
	get_tree().create_timer(28.0).timeout.connect(func(): c.emitting = false)
	get_tree().create_timer(35.0).timeout.connect(c.queue_free)

## True when a line of sight crosses a smoke cloud.
func smoke_blocks(a: Vector3, b: Vector3) -> bool:
	for sm in smokes:
		if sm["until"] < t:
			continue
		var c: Vector3 = sm["pos"] + Vector3(0, 1.2, 0)
		var ab := b - a
		var k := clampf((c - a).dot(ab) / max(ab.length_squared(), 0.001), 0.0, 1.0)
		if (a + ab * k).distance_to(c) < SMOKE_R:
			return true
	return false

var mines := []      # [{node, pos, by, armed_at}]
func add_mine(p: Vector3, by: String) -> void:
	var m := Game.model("mine")
	add_child(m)
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.5, 0), p + Vector3(0, -3, 0), 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	m.global_position = hit.position if hit else p
	var led := OmniLight3D.new()
	led.light_color = Color(1, 0.1, 0.05)
	led.light_energy = 0.5
	led.omni_range = 1.0
	m.add_child(led)
	led.position.y = 0.1
	mines.append({"node": m, "pos": m.global_position, "by": by, "armed_at": t + 2.0, "led": led})

func _mines_tick() -> void:
	for mn in mines.duplicate():
		if not is_instance_valid(mn["node"]):
			mines.erase(mn)
			continue
		mn["led"].visible = fmod(t, 1.0) < 0.15 and t > mn["armed_at"]
		if not multiplayer.is_server() or t < mn["armed_at"]:
			continue
		for a in aliens():
			if not a.dead and a.global_position.distance_to(mn["pos"]) < 2.2:
				_mine_gone.rpc(mines.find(mn))
				explode(mn["pos"], 3.8, 120.0, mn["by"], true)
				break

@rpc("authority", "call_local", "reliable")
func _mine_gone(i: int) -> void:
	if i >= 0 and i < mines.size():
		if is_instance_valid(mines[i]["node"]):
			mines[i]["node"].queue_free()
		mines.remove_at(i)

# ---- items lying on the ground (a weapon dropped in panic...) ---------------------------
var pickups := {}     # pid -> {"node": Node3D, "item": Dictionary}
var _pid := 0

func drop_item(item: Dictionary, pos: Vector3) -> void:
	_pid += 1
	_add_pickup.rpc("%d_%d" % [multiplayer.get_unique_id(), _pid], item, pos)

@rpc("any_peer", "call_local", "reliable")
func _add_pickup(pid: String, item: Dictionary, pos: Vector3) -> void:
	var n := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.12, 0.08, 0.55) if Game.ITEMS[item["id"]]["type"] == "weapon" else Vector3(0.18, 0.1, 0.18)
	n.mesh = bm
	n.material_override = Game.color_mat(Color(0.12, 0.12, 0.13))
	add_child(n)
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.5, 0), pos + Vector3(0, -3, 0), 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	n.global_position = (hit.position + Vector3(0, 0.05, 0)) if hit else pos
	n.rotation.y = randf() * TAU
	pickups[pid] = {"node": n, "item": item}

@rpc("any_peer", "call_local", "reliable")
func take_pickup(pid: String) -> void:
	if pickups.has(pid):
		pickups[pid]["node"].queue_free()
		pickups.erase(pid)

func nearest_pickup(pos: Vector3) -> Dictionary:
	for pid in pickups:
		if pickups[pid]["node"].global_position.distance_to(pos) < 1.8:
			return {"pid": pid, "item": pickups[pid]["item"]}
	return {}

@rpc("authority", "call_local", "unreliable")
func _ambient(sname: String, pos: Vector3, db: float) -> void:
	Game.play_at(self, sname, pos, db)

func alive_aliens() -> int:
	var n := 0
	for a in aliens():
		if not a.dead:
			n += 1
	return n

func _judge() -> void:
	var ps := players()
	if ps.is_empty():
		return
	var standing := 0
	var at_evac := 0
	for p in ps:
		if not p.downed and not p.dead:
			standing += 1
			if p.global_position.distance_to(map["evac"]) < 3.5 and p.wants_evac:
				at_evac += 1
	if standing == 0:
		_end.rpc(false, "Celý tým padl.")
	elif at_evac == standing:
		var won := alive_aliens() == 0
		_end.rpc(won, "Posádka UFO zneškodněna." if won else "Tým se stáhl z mise.")

@rpc("authority", "call_local", "reliable")
## Won missions: everything the aliens dropped is picked up on the way out (no carrying needed).
func _loot(success: bool) -> Dictionary:
	var out := {}
	if not success:
		return out
	var r := RandomNumberGenerator.new()
	r.seed = Net.mission_seed + 77
	for a in aliens():
		if a.dead and Campaign.RACE_WEAPON.has(a.race) and r.randf() < 0.6:
			var w: String = Campaign.RACE_WEAPON[a.race]
			out[w] = int(out.get(w, 0)) + 1
	var mt: String = Net.mission_params.get("type", "")
	var mk: Array = {"crash": [25, 50], "landed": [50, 100], "abduction": [30, 60], "terror": [10, 25]}.get(mt, [0, 0])
	var al: Array = {"crash": [6, 14], "landed": [10, 20], "abduction": [6, 12], "terror": [0, 3]}.get(mt, [0, 0])
	out["moskovium"] = r.randi_range(mk[0], mk[1])
	out["slitiny"] = r.randi_range(al[0], al[1])
	return out

func _end(success: bool, why: String) -> void:
	if finished:
		return
	finished = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var me := local_player()
	var fate := "zdráv"
	var xp_text := ""
	if me:
		Game.merc["missions"] = int(Game.merc.get("missions", 0)) + 1
		Game.merc["kills"] = int(Game.merc.get("kills", 0)) + me.kills
		Game.merc["captures"] = int(Game.merc.get("captures", 0)) + me.captures
		# personal pay (the host's campaign money is the base treasury, so he gets none here)
		var pay: int = (100 if success else 30) + me.kills * 30 + me.captures * 80 + me.revives * 25
		if multiplayer.is_server() and not Net.mission_params.is_empty() and Campaign.active:
			pay = 0
		var purse := int(Game.merc.get("money", 0)) + pay
		if pay > 0:
			xp_text += "\nŽold: +%d kr (máš %d kr)" % [pay, purse]
		if me.dead or (me.downed and not me.global_position.distance_to(map["evac"]) < 3.5):
			fate = "PADL - žoldák je mrtvý (úspory převzal nový žoldák)"
			Game.merc = Game.new_merc()
		else:
			# experience: only the living learn
			var xp: int = 40 + (120 if success else 0) + me.kills * 25 + me.captures * 60 + me.revives * 30
			var gained: Array = Game.add_xp(xp)
			xp_text = "\nZkušenosti +%d  (%s)" % [xp, Game.rank_name(Game.merc)]
			for g in gained:
				xp_text += "\n" + g
			if me.wounded:
				fate = "zraněn"
				if Game.veteran():
					Game.merc["injury"] = me.max_hp - me.hp
					Game.merc["injury_time"] = Time.get_unix_time_from_system()
					fate = "zraněn - uzdraví se za %d min" % Game.heal_minutes_left(Game.merc)
		Game.merc["money"] = purse
		Game.save_merc()
	var lines := []
	for p in players():
		lines.append("%s - zabití %d, zajato %d - %s" % [p.display_name, p.kills, p.captures, "mrtev" if p.dead else ("v bezvědomí" if p.downed else ("zraněn" if p.wounded else "v pořádku"))])
	var civ_saved := 0
	var civ_dead := 0
	for c in civilians():
		if c.saved:
			civ_saved += 1
		elif c.dead:
			civ_dead += 1
	if civs_total > 0:
		lines.append("Civilisté: zachráněno %d, mrtvých %d, ztraceno ve tmě %d" % [civ_saved, civ_dead, civs_total - civ_saved - civ_dead])
	var camp := ""
	if not Net.mission_params.is_empty() and multiplayer.is_server() and Campaign.active:
		var tk := 0
		var tc := 0
		var lost := 0
		for p in players():
			tk += p.kills
			tc += p.captures
			if p.dead or (p.downed and p.global_position.distance_to(map["evac"]) >= 3.5):
				lost += 1
		camp = Campaign.mission_done(int(Net.mission_params.get("id", -1)), success, tk, tc, lost, civ_saved, civ_dead, crew_names, _loot(success))
		Net.last_result = camp
	hud.show_result(("MISE SPLNĚNA" if success else "MISE NEÚSPĚŠNÁ"), why + "\n\n" + "\n".join(lines) + "\n\nTvůj žoldák: " + fate + xp_text + ("\n\n" + camp if camp != "" else ""))
	get_tree().create_timer(8.0 if Game.autotest() != "campaign" else 2.0).timeout.connect(func(): _leave(""))

func _leave(why: String) -> void:
	if Game.autotest() != "" and Game.autotest() != "campaign":
		return
	if why != "":
		Net.close()
		Net.back_to_menu()
		return
	Net.after_mission()

func _on_peer_left(id: int) -> void:
	if multiplayer.is_server() and not go:
		ready_ids.erase(id)
		_ready_state.call_deferred()
	var n := actors.get_node_or_null("P%d" % id)
	if n and multiplayer.is_server():
		n.queue_free()
	hud.message("Hráč se odpojil.", 3.0)
