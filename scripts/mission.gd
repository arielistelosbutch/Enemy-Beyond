extends Node3D
## One mission: builds the night, the random map, spawns the team and the
## aliens (the host decides, everybody sees the same), judges the end.

const PlayerScript := preload("res://scripts/player.gd")
const AlienScript := preload("res://scripts/alien.gd")
const MeleeScript := preload("res://scripts/melee_alien.gd")
const DroneScript := preload("res://scripts/drone_alien.gd")
const BossScript := preload("res://scripts/boss.gd")
const AD := preload("res://scripts/ai_director.gd")     # (0.64: tension instead of fixed times; the players' styles)
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
	if Net.mission_params.get("type", "") in ["mars", "home", "alienbase"] or Net.mission_params.has("base"):
		w = "clear"
	weather = w

# ---- ready check: after the briefing everyone confirms; the night starts together ----------
var go := false
var ready_ids := {}

## Called when this player presses Enter in the ship.
var _me_ready := false
func i_am_ready() -> void:
	if _me_ready:
		return
	_me_ready = true
	_set_ready.rpc_id(1)

## The local briefing has been read: into the ship (the ramp stays shut until all are ready).
func brief_done() -> void:
	go = true
	if mtype() == "base" and indoor():
		Game.play_ui(self, "fuse_out", -2)    # the fuses go: a clunk, a dying hum, the dark
	if Game.autotest() != "":
		i_am_ready()

@rpc("any_peer", "call_local", "reliable")
func _set_ready() -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	ready_ids[id if id != 0 else 1] = true
	_ready_state()

func _ready_state() -> void:
	var need: Array = roster().keys() if not roster().is_empty() else [1]
	var n := 0
	for id in need:
		if ready_ids.has(id):
			n += 1
	_ready_sync.rpc(n, need.size(), n >= need.size())

## After the briefing: a few seconds inside the Kondor with the ramp closed (check the gear),
## then the ramp drops and the night begins. The aliens wait for the ramp too.
const PREP_TIME := 10.0
var prep_left := PREP_TIME      # > 0 = the ramp is shut (it opens when everyone pressed Enter)
var _prep_note := 0.0
var _door: Node3D

func started() -> bool:
	return go and prep_left <= 0.0

func _build_door() -> void:
	if not map.has("door"):
		prep_left = 0.0
		return
	_door = Node3D.new()
	_door.name = "KondorDoor"
	add_child(_door)
	_door.global_position = map["door"]
	var body := StaticBody3D.new()
	_door.add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(3.2, 2.8, 0.14)
	cs.shape = bs
	cs.position = Vector3(0, 1.4, 0)
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(3.0, 2.7, 0.12)
	mi.mesh = bm
	mi.material_override = Game.mat("skyranger", 0.5)
	mi.position = Vector3(0, 1.35, 0)
	_door.add_child(mi)
	# (0.7x) the transport's own ramp is the door now (the box only when a model has none)
	mi.visible = _ship_ramp() == null
	# a red lamp above the ramp: red while closed, green when open
	var lamp := OmniLight3D.new()
	lamp.name = "Lamp"
	lamp.light_color = Color(1.0, 0.15, 0.1)
	lamp.light_energy = 1.4
	lamp.omni_range = 4.0
	add_child(lamp)
	lamp.global_position = map["door"] + Vector3(0, 2.5, -0.6)
	if Game.autotest() != "" and Game.cmd_arg("prep", "") == "":
		prep_left = 0.0

## (0.7x) Our transport on the landing site with a ramp of its own (null = no model / no ramp).
var _ramp_ship: Node3D
var _ramp_done := false
func _ship_ramp() -> Node3D:
	if _ramp_ship == null:
		for s in get_tree().get_nodes_in_group("our_ship"):
			if s.find_child("Ramp", true, false):
				_ramp_ship = s
	return _ramp_ship

## The ramp goes with the door: shut in the prep, falls open with it, then stays down.
func _ramp_tick() -> void:
	if _ramp_done or _ship_ramp() == null:
		return
	var open := 0.0
	if _door:
		open = _door.rotation.x / (PI / 2 + 0.18)
	elif prep_left <= 0.0:
		open = 1.0
		_ramp_done = true
	Game.ship_ramp(_ramp_ship, open)

func _prep_tick(delta: float) -> void:
	_ramp_tick()
	if not go or prep_left <= 0.0 and _door == null:
		return
	if prep_left > 0.0:
		if Input.is_action_just_pressed("ready") and not hud.inventory_open:
			i_am_ready()
			Game.play_ui(self, "clink", -10)
		_prep_note -= delta
		if _prep_note <= 0.0 and hud:
			_prep_note = 1.0
			var cnt := " (připraveno %d/%d)" % [hud.ready_n, hud.ready_total] if hud.ready_total > 1 else ""
			hud.message(("PŘIPRAVEN - čeká se na ostatní%s." % cnt) if _me_ready else ("V LODI: vybav se (I), domluvte se. ENTER = připraven%s." % cnt), 1.3)
		return
	if _door:
		# the ramp falls outwards and becomes the walkway
		_door.rotation.x = minf(_door.rotation.x + delta * 1.6, PI / 2 + 0.18)
		var lamp: OmniLight3D = get_node_or_null("Lamp")
		if lamp:
			lamp.light_color = Color(0.2, 1.0, 0.3)
		if _door.rotation.x >= PI / 2 + 0.17:
			_door.queue_free()
			_door = null

@rpc("authority", "call_local", "reliable")
func _ready_sync(n: int, total: int, all: bool) -> void:
	if hud:
		hud.ready_count(n, total)
	if all and prep_left > 0.0:
		go = true
		prep_left = 0.0
		if hud:
			hud.brief_go()
			hud.message("Rampa dole. Hodně štěstí.", 2.0)
		Game.play_ui(self, "ramp", -2)

## How much louder footsteps are on this ground (snow crunches).
func step_noise() -> float:
	return 1.6 if map.get("terrain", "") == "snow" else 1.0

## Rain drowns what the aliens do: their sounds are quieter for the team.
func alien_db() -> float:
	return {"rain": -7.0, "storm": -10.0, "snow": -3.0}.get(weather, 0.0)

## Solo: the helper drone (made when the lone mercenary is on the ground).
var guard_drone: Node = null
func _guard_drone_tick() -> void:
	if guard_drone != null or not solo() or home() or local() or finished:
		return
	if local_player() == null:
		return
	guard_drone = preload("res://scripts/guard_drone.gd").new()
	guard_drone.mission = self
	add_child(guard_drone)
	guard_drone.global_position = local_player().global_position + Vector3(0, 2.0, 0)

## The first moments after landing: nobody waits at the ramp. Aliens do not notice a man
## near the ship for the first SAFE_LANDING seconds.
const SAFE_LANDING := 45.0
func landing_safe(p: Node3D) -> bool:
	if mtype() == "base":
		return t < BASE_WAKE      # our base: they have only just broken in, the team is still waking up
	return t < SAFE_LANDING and map.get("evac", Vector3.ZERO) != Vector3.ZERO and p.global_position.distance_to(map["evac"]) < 25.0 and not mtype() in ["base", "home"]
## Our base attacked: for the first seconds the aliens are still coming in and have not found anyone.
const BASE_WAKE := 15.0

## (tests) A solid block in the world.
func map_box(pos: Vector3, size: Vector3) -> StaticBody3D:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	sb.add_child(mi)
	add_child(sb)
	sb.global_position = pos
	return sb

## Played alone (nobody to drag you back up): the aliens go a little easier. Co-op gets it all.
func solo() -> bool:
	return roster().size() <= 1

func calm() -> bool:
	return t < CALM_TIME

func _ready() -> void:
	name = "Mission"
	_local = bool(Net.mission_params.get("local", false))
	if not _local:
		# (a left-over offline branch from a base walk must never swallow a real mission)
		get_tree().set_multiplayer(null, get_path())
	if local():
		# a base walk of one's own while the host is busy on the globe: this branch runs offline
		# (the connection to the host stays alive above it)
		var api := SceneMultiplayer.new()
		api.multiplayer_peer = OfflineMultiplayerPeer.new()
		get_tree().set_multiplayer(api, get_path())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Game.camo = Game.camo_for(Net.mission_params if not Net.mission_params.is_empty() else {"type": "crash"})
	_pick_weather()
	_environment()
	if mtype() == "alienbase":
		map = preload("res://scripts/alien_base_gen.gd").new().build(self, Net.mission_seed, Net.mission_params)
		_underground_env()
	else:
		map = (preload("res://scripts/base_gen.gd").new() if indoor() else MapGen.new()).build(self, Net.mission_seed, Net.mission_params)
	if indoor():
		_home_env()
	_hang_doors()
	_core_hums()
	if home():
		_base_people()
	if multiplayer.is_server():
		_nav_prime()
	# 0.62 výkon: stíny lamp jen blízko kamery, měsíc ve 2 pásmech (Game.shadow_light / shadow_sun)
	for l in find_children("*", "Light3D", true, false):
		if l is DirectionalLight3D:
			Game.shadow_sun(l)
		else:
			Game.shadow_light(l)
	# 0.62 výkon: drobnosti a tráva se kreslí jen do vzdálenosti podle velikosti (Game.far_cull)
	if Game.cmd_arg("detail", "") != "":
		Game.detail = int(Game.cmd_arg("detail", "1"))
	if Game.cmd_arg("lod", "") != "off":
		Game.far_cull(find_child("Nav", true, false))
	actors = Node3D.new()
	actors.name = "Actors"
	add_child(actors)
	if Net.mission_params.get("testroom", false) and OS.has_feature("editor"):
		var tr := Node.new()
		tr.set_script(load("res://scripts/test_room.gd"))
		tr.name = "TestRoom"
		add_child(tr)
	spawner = MultiplayerSpawner.new()
	spawner.name = "Spawner"
	add_child(spawner)
	spawner.spawn_path = spawner.get_path_to(actors)
	spawner.spawn_function = _spawn
	hud = Hud.new()
	add_child(hud)
	voice = preload("res://scripts/voice.gd").new()
	add_child(voice)
	# 0.70 Facelift II: the echo of the place (a reverb on the sounds the game has, no new sounds)
	add_child(preload("res://scripts/room_echo.gd").new())
	# no music: wind, silence and what moves in it
	music = AudioStreamPlayer.new()
	music.stream = Game.loop_stream(_wind_name())
	music.volume_db = -12
	music.bus = "Wind"
	add_child(music)
	music.play()
	var bed := _ambient_bed()
	if bed != "":
		_loop_player(AudioStreamPlayer.new(), bed, -16.0)
	if weather == "storm" or weather == "rain":
		# the rain is loud (it hides your steps - and theirs); under a roof it drums on the roof instead
		_rain_out = AudioStreamPlayer.new()
		_loop_player(_rain_out, "storm" if weather == "storm" else "rain", RAIN_DB)
		_rain_roof = AudioStreamPlayer.new()
		_loop_player(_rain_roof, "rain_roof", -60.0)
		music.volume_db = -16
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
	_build_door()
	_ufo_ambience()
	_ship_engine()
	_drone = AudioStreamPlayer.new()
	_drone.stream = Game.loop_stream("low_drone")
	_drone.volume_db = -60.0
	_drone.bus = "Ambient"
	add_child(_drone)
	_drone.play()
	_build_beacons()
	if mtype() == "rescue":
		var vr := RandomNumberGenerator.new()
		vr.seed = Net.mission_seed + 7
		vip_name = VIP_NAMES[vr.randi() % VIP_NAMES.size()]
	if home():
		hud.briefing(("Základna v rokli na Vysočině, pod zemí." if String(Net.mission_params.get("where", "Vysočina")) == "Vysočina" else "Základna pod zemí, oblast %s." % Net.mission_params.get("where", "")) + " Mezi misemi se tu dá chodit: ubikace, laboratoř, dílna, hangár s lodí.\n\nE u terminálu:\n  Velín - zpět ke globusu (mise, nákupy, stavby; ovládá hostitel)\n  Laboratoř - strom výzkumu, encyklopedie\n\nNikdo tu po vás nestřílí. Zatím.")
	else:
		hud.briefing(_briefing_text() + "\nPočasí: " + WEATHER_NAMES[weather] + ".")
	multiplayer.peer_disconnected.connect(_on_peer_left)
	Net.note.connect(_on_note)
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
		# the host may still be loading (his Mission not there yet - the message is lost and he
		# would wait for us forever: a black screen). Say it again until we are spawned.
		var tm := Timer.new()
		tm.wait_time = 1.0
		tm.autostart = true
		tm.timeout.connect(func():
			if local_player() != null or finished:
				tm.queue_free()
				return
			_client_ready.rpc_id(1))
		add_child(tm)

## Which wind blows here: forest rustle, polar gale, the thin Martian air...
func _wind_name() -> String:
	if indoor():
		return "base_interior"      # our base is under the ground: no wind, no night outside
	var biome := String(Net.mission_params.get("biome", "farm"))
	match String(map.get("terrain", "")):
		"alienbase": return "cave_ambience"
		"snow": return "polar"
		"mars": return "mars"
		"desert": return "night_silence"
	if biome == "forest":
		return "wind_forest"
	if biome == "mountain":
		return "mountain"
	return "wind"

## What lives under the wind: crickets over the fields, a distant town, humming machines.
func _ambient_bed() -> String:
	if indoor():
		return ""                   # (the base's own hum is the bed already - no crickets in here)
	if mtype() == "base":
		return "base_interior" if indoor() else "ufo_interior"
	if mtype() == "alienbase":
		return "ufo_interior"
	if map.get("terrain", "") in ["mars", "snow"]:
		return ""
	match String(Net.mission_params.get("biome", "farm")):
		"farm": return "night_field"
		"town": return "town_night"
		"industrial": return "industrial"
		"base": return "base_interior"
	return ""

## Animals only outside on Earth: not under the ground, not inside a base, not on Mars.
func critters_here() -> bool:
	return not indoor() and not mtype() in ["base", "alienbase", "home", "mars"] and map.get("terrain", "") != "mars"

## Now and then something out there: a dog in the village, an owl, a cow in the barn.
var _critter_t := 25.0
func _critters(delta: float) -> void:
	_critter_t -= delta
	if _critter_t > 0.0:
		return
	_critter_t = randf_range(35.0, 80.0)
	if not critters_here() or weather == "storm":
		return
	var biome := String(Net.mission_params.get("biome", "farm"))
	var pool := ["owl"]
	if biome in ["farm", "town"]:
		pool += ["dog", "dog", "cow"]
	if biome == "forest":
		pool += ["owl"]
	if mtype() == "terror" or biome == "town":
		pool += ["distant_scream"]
	var s: String = pool[randi() % pool.size()]
	var a := randf() * TAU
	var me: Node3D = local_player()
	var c: Vector3 = me.global_position if me else Vector3(map["size"] / 2.0, 0, map["size"] / 2.0)
	Game.play_at(self, s, c + Vector3(cos(a), 0.2, sin(a)) * randf_range(30.0, 55.0), -6)

## The UFO's hatch and the hatches between the halls of a big ship hiss open as someone
## (one of us or one of them) steps through: you hear where they come from.
var _hatch_t := 0.0
var _hatch_busy := {}
func _hatch_tick(delta: float) -> void:
	_hatch_t -= delta
	if _hatch_t > 0.0:
		return
	_hatch_t = 0.15
	var pts: Array = map.get("ship_doors", []).duplicate()
	if map.get("ufo_door", Vector3.ZERO) != Vector3.ZERO and map.get("ufo", Vector3.ZERO) != Vector3.ZERO and not mtype() in ["base", "mars"]:
		pts.append(map["ufo_door"])
	if pts.is_empty():
		return
	var me: Node3D = local_player()
	var bodies: Array = []
	for p in players():
		if not p.dead:
			bodies.append(p)
	for a in aliens():
		if not a.dead and (me == null or a.global_position.distance_to(me.global_position) < 45.0):
			bodies.append(a)
	for i in pts.size():
		var d: Vector3 = pts[i]
		var near := false
		for b in bodies:
			var bp: Vector3 = (b as Node3D).global_position
			if absf(bp.y - d.y) < 2.5 and Vector2(bp.x - d.x, bp.z - d.z).length() < 1.5:
				near = true
				break
		if near and not _hatch_busy.get(i, false):
			Game.play_at(self, "ufo_door", d + Vector3(0, 1.4, 0), -6.0, randf_range(0.95, 1.05))
		_hatch_busy[i] = near

## Our transport waits at the landing zone with the engines idling: you can find it by ear.
func _ship_engine() -> void:
	if map.get("evac", Vector3.ZERO) == Vector3.ZERO or mtype() in ["base", "alienbase"]:
		return
	var heli := String(Net.mission_params.get("transport", "kondor")) == "heli"
	var ap := AudioStreamPlayer3D.new()
	ap.unit_size = 4.0
	ap.max_distance = 45.0
	add_child(ap)
	ap.global_position = map["evac"] + Vector3(0, 2.0, 0)
	_loop_player(ap, "heli_flight" if heli else "dropship_engine", -14.0 if heli else -10.0)

## Dread: a low drone swells when something is close and you cannot see it.
var _drone: AudioStreamPlayer
var _drone_t := 0.0
func _drone_tick(delta: float) -> void:
	_drone_t -= delta
	if _drone == null or _drone_t > 0.0:
		return
	_drone_t = 0.25
	var me: Node3D = local_player()
	var want := -60.0
	if me and not me.dead:
		var near := 1e9
		for a in aliens():
			if not a.dead:
				near = minf(near, a.global_position.distance_to(me.global_position))
		if near < 28.0:
			want = lerpf(-6.0, -26.0, clampf((near - 6.0) / 22.0, 0.0, 1.0))
	_drone.volume_db = lerpf(_drone.volume_db, want, 0.15)

## The landed (or crashed) ship hums in the dark: you hear it before you see it.
func _ufo_ambience() -> void:
	if not map.has("ufo") or map["ufo"] == Vector3.ZERO or mtype() in ["base", "mars"]:
		return
	var ap := AudioStreamPlayer3D.new()
	ap.unit_size = 5.0
	ap.max_distance = 45.0
	add_child(ap)
	ap.global_position = map["ufo"] + Vector3(0, 1.5, 0)
	_loop_player(ap, "ufo_hum", -6.0)
	# inside the hull it sounds different: a close, breathing machine
	var ins := AudioStreamPlayer3D.new()
	ins.unit_size = 2.0
	ins.max_distance = 9.0
	add_child(ins)
	ins.global_position = map["ufo"] + Vector3(0, 1.2, 0)
	_loop_player(ins, "ufo_interior", -4.0)
	if String(map.get("ufo_kind", "")) in ["battleship", "supply"]:
		# a whole ship around you: the big hull breathes everywhere inside
		var big := AudioStreamPlayer3D.new()
		big.unit_size = 10.0
		big.max_distance = 40.0
		add_child(big)
		big.global_position = map["ufo"] + Vector3(0, 2.0, 0)
		_loop_player(big, "ufo_ship_ambience", -6.0)

const RAIN_DB := -7.0
var _rain_out: AudioStreamPlayer
var _rain_roof: AudioStreamPlayer

func _loop_player(ap: Node, sname: String, db: float) -> void:
	ap.stream = Game.loop_stream(sname)
	ap.volume_db = db
	ap.bus = "Ambient"
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
			"mars": "Pelikán přistál na rudé pláni. Před vámi je tunel do jejich velína a za ním Velký mozek - to, co je všechny řídí. Chrání ho štít ze tří pylonů. Zničte pylony, pak mozek. Myslí na vás. Uslyšíte ho.",
			"rescue": "Nouzový maják vysílá z oblasti, kam dosedlo UFO. Někdo tam přežil a vetřelci po něm jdou. Signál ukazuje směr a vzdálenost (nahoře na obrazovce).",
			"alienbase": "Výslech prozradil, kde mají základnu: jeskyně pod zemí, vykopané do skály a zarostlé jejich zahradou. Sjíždíte šachtou dolů. Někde v hloubce je velitelské centrum s řídicím jádrem - a v líhni prý drží lidi.",
			"sabotage": "Tři cizí majáky v krajině vysílají k jejich lodím. Dokud stojí, přicházejí další. Každý maják: drž u něj E 3 sekundy, nálož bouchne za 8 sekund.",
			"base": "Vetřelci přistáli nad základnou. Vyřadili pojistky - hlavní světla zhasla, svítí jen rudé nouzové lampy. Lezou dovnitř hangárem a šachtou výtahu, ve vlnách. Vydržet a zabít všechny. Znáte tu každou chodbu - oni ne." if Net.mission_params.has("base") else "Vetřelci přistáli u základny v rokli. Kondor stojí na ploše a nikam se neletí. Útočí ve vlnách od okraje rokle. Vydržet a zabít všechny.",
			"terror": "Vetřelci vtrhli do městečka. Spojení s místními je přerušeno. Poslední hovor na tísňovou linku: \"Je to černé, je to rychlé, a ti, co to zabilo, zase vstávají.\"\nZachraň, koho můžeš (E u vyděšeného civilisty - půjde za tebou do Kondoru).",
		}
		var terr: String = {"snow": "\nTerén: sníh.", "desert": "\nTerén: poušť."}.get(mp.get("terrain", ""), "")
		var task := "ÚKOL: zneškodnit posádku a vrátit se do Kondoru.\nOmráčení vetřelci mají pro výzkum velkou cenu. Co vetřelci upustí, posbíráme při odletu."
		match String(mp.get("type", "")):
			"mars": task = "ÚKOL: zničit tři pylony štítu a Velký mozek. Návrat není."
			"rescue": task = "ÚKOL: najít a přivést do Kondoru živého - ostatní vetřelci jsou až na druhém místě (E u něj = půjde za tebou)."
			"sabotage": task = "ÚKOL: zničit všechny tři majáky a vrátit se do Kondoru."
			"alienbase": task = "ÚKOL: najít velitelské centrum, zničit řídicí jádro (výbuch!) a vrátit se k šachtě. Zajatce z líhně vezměte s sebou (E u nich)."
			"base": task = "ÚKOL: ubránit základnu - přežít všechny vlny. Prohra znamená vyrabovanou základnu."
		var learned := ""
		var hb: Dictionary = mp.get("habits", {})
		for who in hb:
			var parts := []
			for it in hb[who]:
				if Campaign.HABIT_TEXT.has(it) and parts.size() < 2:      # two per man: the briefing has to fit
					parts.append(Campaign.HABIT_TEXT[it])
			if not parts.is_empty():
				learned += "\n%s pořád nosí %s." % [who, "; ".join(parts)]
		# (0.57, Ari: no hand-holding - they still learn, nobody tells you how)
		learned = ""
		if Game.camo != "":
			task += "\n\nMaskáče: %s vzor." % Game.CAMO_NAMES.get(Game.camo, Game.camo)
		return "%s\nOblast: %s, místní čas %02d:%02d (%s), mapa %s%s\n\n%s\n\n" % [
			String(mp.get("type_name", "Mise")).to_upper(), mp.get("place", "?"), int(h), int(fmod(h, 1.0) * 60),
			PHASE_NAMES.get(phase(), "noc"), MapGen.SIZE_NAMES.get(mp.get("size", "medium"), "střední"), terr, flavor.get(mp.get("type", "crash"), "")] + task
	var r := RandomNumberGenerator.new()
	r.seed = Net.mission_seed
	var day := r.randi_range(24, 30)
	var hh := r.randi_range(1, 3)
	var mm := r.randi_range(0, 59)
	var places := ["u Telče", "nad Kamenicí", "u Pelhřimova", "pod Javořicí", "u Nové Bystřice"]
	return "%d. dubna 1990, %02d:%02d\nVysočina, samota %s.\n\nRadar zachytil pád neznámého objektu. Od 23:40 nekomunikuje farma Horákových.\nPolicejní hlídka, která sem jela, se nevrátila.\n\nÚKOL: zneškodnit posádku UFO a vrátit se do Kondoru.\nPilot čeká se zapnutými motory." % [day, hh, mm, places[r.randi() % places.size()]]

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

## Night vision, only on this machine: the picture goes through the tube shader, and the
## world gets a little light of its own (an intensifier sees what the eye does not).
var nvg_on := false
var nvg_ir := false
var _nvg_layer: CanvasLayer
var _nvg_mat: ShaderMaterial
var _nvg_amb := 0.0
func set_nvg(on: bool, ir := false) -> void:
	if on == nvg_on and (ir and on) == nvg_ir:
		return
	nvg_on = on
	nvg_ir = ir and on
	if _nvg_layer == null:
		_nvg_layer = CanvasLayer.new()
		_nvg_layer.layer = 1
		_nvg_layer.name = "NvgFilter"
		var cr := ColorRect.new()
		cr.set_anchors_preset(Control.PRESET_FULL_RECT)
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sm := ShaderMaterial.new()
		sm.shader = preload("res://shaders/nvg.gdshader")
		var me := local_player()
		if me and Game.has_talent(me.merc, "nocni_oko"):
			sm.set_shader_parameter("grain", 0.035)
		cr.material = sm
		_nvg_mat = sm
		_nvg_layer.add_child(cr)
		add_child(_nvg_layer)
	_nvg_layer.visible = on
	# brighter by the darkness of the hour: at noon it only washes out
	var add := 0.0
	if on:
		add = {"noc": 0.55, "soumrak": 0.25, "svitani": 0.25}.get(phase(), 0.05)
		if nvg_ir:
			add += 0.2 if phase() == "noc" else 0.05
	# NVG-01 only amplifies what light there is: under clouds on a starless night the passive
	# picture is murky and noisy (the illuminator fixes that); in fog the IR comes back off the haze
	var gain := 5.0
	var grain := 0.035 if (local_player() and Game.has_talent(local_player().merc, "nocni_oko")) else 0.1
	if on and not nvg_ir and phase() == "noc" and weather in ["overcast", "rain", "storm"]:
		gain = 2.4
		grain += 0.07
	elif on and nvg_ir and weather == "fog":
		gain = 3.6
		grain += 0.05
	_nvg_mat.set_shader_parameter("gain", gain)
	_nvg_mat.set_shader_parameter("grain", grain)
	_amb_base += add - _nvg_amb
	env.ambient_light_energy += add - _nvg_amb
	_nvg_amb = add

## A bright flash in front of the tube: the gain cannot drop fast enough, the picture burns out green.
func nvg_glare(at: Vector3, reach: float, k: float) -> void:
	if not nvg_on:
		return
	var me := local_player()
	if me == null or me.dead or me.cam == null:
		return
	var d: float = me.cam.global_position.distance_to(at)
	if d > reach:
		return
	var fwd: Vector3 = -me.cam.global_transform.basis.z
	if fwd.dot((at - me.cam.global_position).normalized()) < 0.2:
		return          # (behind you: the tube does not see it)
	var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 0.3, 0), me.cam.global_position, Game.WORLD)
	if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		return
	hud.nvg_overload(clampf(k * (1.3 - d / reach), 0.25, 1.0))

## The Night Eye talent: the eyes get used to the dark (only on this machine).
func night_eyes() -> void:
	var add: float = {"noc": 0.18, "soumrak": 0.08, "svitani": 0.08}.get(phase(), 0.0)
	_amb_base += add
	env.ambient_light_energy += add

func set_retro(on: bool) -> void:
	var f := get_node_or_null("RetroFilter")
	if f:
		f.visible = on

func is_day() -> bool:
	return phase() != "noc"

## The local hour of the mission (the globe's clock; quick missions pick it in the menu).
func hour() -> float:
	var mp: Dictionary = Net.mission_params
	if mp.is_empty():
		return 23.0
	return float(mp.get("hour", 23.0 if mp.get("night", true) else 14.0))

## (0.62) How high the sun stands over the mission, in degrees. A campaign mission carries the real
## sun over its place ("sun", Campaign.sun_at - the same sun that lights the globe); a quick mission
## or a test only has the hour: dawn 5:00-7:30, day until 18:00, dusk until 20:30 as before.
func sun_elev() -> float:
	var mp: Dictionary = Net.mission_params
	if mp.is_empty():
		return -30.0
	if mp.has("sun"):
		return float(mp["sun"])
	if not mp.has("hour"):
		return -30.0 if mp.get("night", true) else 40.0
	var h := hour()
	if h >= 5.0 and h < 7.5: return lerpf(Campaign.SUN_NIGHT, Campaign.SUN_DAY, (h - 5.0) / 2.5)
	if h >= 7.5 and h < 18.0: return Campaign.SUN_DAY + 52.0 * sin(PI * (h - 7.5) / 10.5)
	if h >= 18.0 and h < 20.5: return lerpf(Campaign.SUN_DAY, Campaign.SUN_NIGHT, (h - 18.0) / 2.5)
	return -30.0

## Where the sun stands (degrees, 0 north, 90 east): east in the morning, south at noon, west at dusk.
func sun_az() -> float:
	var mp: Dictionary = Net.mission_params
	if mp.has("sun_az"):
		return float(mp["sun_az"])
	return 180.0 + lerpf(-80.0, 80.0, clampf((hour() - 5.0) / 15.5, 0.0, 1.0))

## Night, dawn, day or dusk - from the height of the sun (Campaign.phase_of: the globe agrees).
func phase() -> String:
	if Net.mission_params.is_empty():
		return "noc"
	return Campaign.phase_of(sun_elev(), hour())

## 0 at the edge of the night .. 1 at full day: how far into the light a dawn or a dusk is.
func twilight() -> float:
	return clampf((sun_elev() - Campaign.SUN_NIGHT) / (Campaign.SUN_DAY - Campaign.SUN_NIGHT), 0.0, 1.0)

const PHASE_NAMES := {"noc": "noc", "svitani": "svítání", "den": "den", "soumrak": "soumrak"}

## The sun (or the moon) by the hour: it rises in the east, stands high at noon, sets in the west;
## at dawn and dusk it hangs low and long shadows fall. The moon at night stands still.
func _sky_light() -> void:
	var ph := phase()
	if ph == "noc":
		moon.rotation_degrees = Vector3(-38, 40, 0)
		return
	# (0.62) the real sun over the place (world: -X east, -Z north, +Y up); a sun just under the
	# horizon still lights from a few degrees up, otherwise everything would be in shadow
	var el := deg_to_rad(clampf(sun_elev(), 6.0, 85.0))
	var az := deg_to_rad(sun_az())
	var to_sun := Vector3(-sin(az) * cos(el), sin(el), -cos(az) * cos(el))
	moon.basis = Basis.looking_at(-to_sun, Vector3.UP)

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
	# the mist must not turn the moon into a second sun (a white disc in the fog)
	moon.light_volumetric_fog_energy = 0.12
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.85
	# (0.62) the night values: a dawn or a dusk near the night edge fades back towards them below
	var nv := [env.background_color, env.ambient_light_color, env.ambient_light_energy, env.fog_light_color,
		env.fog_density, env.volumetric_fog_density, moon.light_color, moon.light_energy, moon.light_volumetric_fog_energy]
	match phase():
		"den":
			# overcast daylight: grey, flat, still uneasy
			env.background_color = Color(0.42, 0.45, 0.5)
			env.ambient_light_color = Color(0.55, 0.58, 0.62)
			env.ambient_light_energy = 0.9
			env.fog_light_color = Color(0.5, 0.52, 0.56)
			env.fog_density = 0.025
			env.volumetric_fog_density = 0.01
			moon.light_color = Color(0.9, 0.9, 0.85)
			moon.light_energy = 0.9
			env.adjustment_saturation = 0.9
		"svitani":
			# dawn: cold lilac sky, a pale pink sun low over the fields, mist still lying
			env.background_color = Color(0.33, 0.3, 0.4)
			env.ambient_light_color = Color(0.45, 0.45, 0.58)
			env.ambient_light_energy = 0.55
			env.fog_light_color = Color(0.4, 0.36, 0.44)
			env.fog_density = 0.035
			env.volumetric_fog_density = 0.02
			moon.light_color = Color(1.0, 0.72, 0.6)
			moon.light_energy = 0.55
			moon.light_volumetric_fog_energy = 0.25
			env.adjustment_saturation = 0.95
		"soumrak":
			# dusk: the sun goes down red behind the trees, the shadows grow long, the east is dark already
			env.background_color = Color(0.3, 0.17, 0.13)
			env.ambient_light_color = Color(0.5, 0.36, 0.34)
			env.ambient_light_energy = 0.45
			env.fog_light_color = Color(0.34, 0.21, 0.16)
			env.fog_density = 0.03
			env.volumetric_fog_density = 0.018
			moon.light_color = Color(1.0, 0.5, 0.25)
			moon.light_energy = 0.75
			moon.light_volumetric_fog_energy = 0.25
			env.adjustment_saturation = 1.1
			env.adjustment_contrast = 1.05
	if phase() in ["svitani", "soumrak"]:
		# (0.62, Ari: "noc, ale svítí jako slunce") the sun just over the horizon lights like the dusk,
		# just under it only a glow is left - continuously, as the globe darkens
		var w := smoothstep(0.0, 1.0, twilight())
		env.background_color = (nv[0] as Color).lerp(env.background_color, w)
		env.ambient_light_color = (nv[1] as Color).lerp(env.ambient_light_color, w)
		env.ambient_light_energy = lerpf(nv[2], env.ambient_light_energy, w)
		env.fog_light_color = (nv[3] as Color).lerp(env.fog_light_color, w)
		env.fog_density = lerpf(nv[4], env.fog_density, w)
		env.volumetric_fog_density = lerpf(nv[5], env.volumetric_fog_density, w)
		moon.light_color = (nv[6] as Color).lerp(moon.light_color, w)
		moon.light_energy = lerpf(nv[7], moon.light_energy, w)
		moon.light_volumetric_fog_energy = lerpf(nv[8], moon.light_volumetric_fog_energy, w)
	_sky_light()
	add_child(moon)
	_weather_env()

## Light, fog and wind by the weather (night values; day keeps its flat grey light).
func _weather_env() -> void:
	var vol := volumetric_on()
	var day := is_day()
	# (0.62) how much of the night look the weather still adds: all at night, fading out through a dawn or dusk
	var nw := 0.0 if phase() == "den" else (1.0 if not day else 1.0 - smoothstep(0.0, 1.0, twilight()))
	match weather:
		"clear":
			# a cold moon: you see further - and so do they
			if nw > 0.0:
				moon.light_energy = lerpf(moon.light_energy, 0.35, nw)
				env.ambient_light_energy = lerpf(env.ambient_light_energy, 0.3, nw)
				env.background_color = env.background_color.lerp(Color(0.03, 0.045, 0.09), nw)
			env.fog_density = 0.006 if vol else 0.03
			env.volumetric_fog_density = 0.008
			_wind_base = 0.6
		"fog":
			# the torch only lights a grey wall
			env.fog_density = 0.05 if vol else 0.14
			env.volumetric_fog_density = 0.07
			env.fog_light_color = Color(0.08, 0.09, 0.1) if not day else env.fog_light_color.lerp(Color(0.6, 0.62, 0.64), 0.5 if phase() == "den" else 0.25)
			_wind_base = 0.25
		"overcast":
			if day and phase() != "den":
				moon.light_energy *= 0.5       # the low sun hidden in the clouds
			if nw > 0.0:
				moon.light_energy = lerpf(moon.light_energy, 0.05, nw)
				env.ambient_light_energy = lerpf(env.ambient_light_energy, 0.14, nw)
				env.background_color = env.background_color.lerp(Color(0.008, 0.01, 0.02), nw)
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
	if Net.mission_params.get("type", "") == "mars":
		# Mars: a rust-red night, dust hanging in the air, a small cold sun gone down
		env.background_color = Color(0.09, 0.03, 0.02)
		env.ambient_light_color = Color(0.45, 0.2, 0.15)
		env.ambient_light_energy = 0.35
		env.fog_light_color = Color(0.25, 0.08, 0.05)
		env.fog_density = 0.02 if vol else 0.045
		moon.light_color = Color(1.0, 0.6, 0.45)
		moon.light_energy = 0.25
		_wind_base = 0.3
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
	for id in roster():
		if not _ready_peers.has(id):
			return
	_spawned = true
	var i := 0
	for id in roster():
		var sp: Vector3 = map["player_spawns"][i % map["player_spawns"].size()]
		spawner.spawn({"kind": "player", "peer": id, "pos": sp, "yaw": float(map.get("spawn_yaw", PI)), "merc": roster()[id]["merc"], "name": roster()[id]["name"]})
		i += 1
	if home():
		return          # nobody else down here
	var rng := RandomNumberGenerator.new()
	rng.seed = Net.mission_seed + 99
	var spawns: Array = map["alien_spawns"].duplicate()
	if mtype() == "base":
		spawns = _base_entries_far(map["player_spawns"], spawns, false)    # (the walls are not in the physics yet: distance only)
	var count := (1 if roster().size() <= 1 else 2) + Net.roster.size() + (5 if String(map.get("ufo_kind", "")) in ["battleship", "supply"] else 0) + int(Net.mission_params.get("extra_aliens", 0)) + (1 if Game.veteran() else (-1 if Game.easy() else 0)) + int({"large": 1, "huge": 2, "colossal": 4}.get(Net.mission_params.get("size", ""), 0))
	# co-op: every mercenary beyond the first brings more of them (on top of the one above)
	count += maxi(0, Net.roster.size() - 1)
	# 0.63 (Ari): a ship carries the crew it has room for - the players only add a few, never past its size
	# (campaign crash / landed missions carry "crew_of" = the ship that flew; quick missions and tests as before)
	var kind := String(Net.mission_params.get("crew_of", ""))
	_crew_cap = 0
	if SHIP_CREW.has(kind) and mtype() in ["crash", "landed"]:
		var sc: Array = SHIP_CREW[kind]
		count = int(ceil(float(sc[0]) + float(sc[1]) * maxi(0, Net.roster.size() - 1) - 0.001)) + (1 if mtype() == "landed" else 0) + (1 if Game.veteran() else (-1 if Game.easy() else 0))
		_crew_cap = int(sc[2])
	var crew := _crew(count, rng)
	for k in crew.size():
		var p: Vector3 = spawns[k % spawns.size()] + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1))
		if map.get("evac", Vector3.ZERO) != Vector3.ZERO and p.distance_to(map["evac"]) < 35.0 and not mtype() in ["base", "home", "alienbase"]:
			p = _far_point(rng, 35.0)      # nobody waits at the ramp
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
	# Mars: the Great Brain on its dais and the three pylons of its shield
	if map.has("brain"):
		spawner.spawn({"kind": "alien", "id": next_alien_id, "pos": map["brain"], "race": "mozek"})
		next_alien_id += 1
		for pp in map["pylons"]:
			spawner.spawn({"kind": "alien", "id": next_alien_id, "pos": pp, "race": "pylon"})
			next_alien_id += 1
	# civilians (terror and abduction)
	var mt: String = Net.mission_params.get("type", "")
	var nciv := 0
	if mt == "terror":
		nciv = rng.randi_range(5, 8)
	elif mt == "abduction":
		nciv = rng.randi_range(1, 3)
	var cpos: Array = map.get("captives", [])
	if mt == "alienbase":
		nciv = cpos.size()
	elif mt in ["crash", "landed"] and String(map.get("ufo_kind", "")) == "harvester" and not (map.get("ufo_inside", []) as Array).is_empty():
		# a Sklízeč: people from the last farm still locked in its holds
		var inside: Array = map["ufo_inside"]
		nciv = mini(rng.randi_range(1, 3), inside.size())
		cpos = []
		for hi in nciv:
			cpos.append(inside[(hi * 2) % inside.size()] + Vector3(0, 0.1, 0))
		# their commander waits by the core
		if map.has("command") and not crew.is_empty():
			var off: String = GROUPS.get(crew_group, {}).get("officer", "grey_velitel")
			spawner.spawn({"kind": "alien", "id": next_alien_id, "pos": map["command"], "race": off})
			next_alien_id += 1
			aliens_total += 1
	for ci in nciv:
		spawner.spawn({"kind": "civ", "id": ci, "pos": cpos[ci] if ci < cpos.size() else _far_point(rng, 12.0)})
	civs_total = nciv
	if Game.autotest() != "" and nciv > 0:
		print("[CIV] %d civilians (%s)" % [nciv, "aboard the ship" if mt in ["crash", "landed"] else mt])
	_spawn_objectives(rng)

## A random walkable point at least @a min_d from the team's landing spot.
func _far_point(rng: RandomNumberGenerator, min_d: float) -> Vector3:
	var wp: Array = map["waypoints"]
	for i in 30:
		var p: Vector3 = wp[rng.randi() % wp.size()] + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
		if p.distance_to(map["evac"]) > min_d:
			return p   # (the nav map is not synced yet at spawn time)
	return wp[0]

## The alien groups, as in the old game: who serves with whom, and the terror
## creature each group brings. "from": campaign month from which the group appears (0.61, Ari: the war
## opens with the Šediváci alone, the Levité come in the 2nd month, Ještěřani 3rd, Bijci and Myslodějové 4th).
const GROUPS := {
	"sedaci": {"name": "Šediváci", "soldier": "grey", "officer": "grey_velitel", "beast": "diskoll", "terror": "diskoll", "from": 0},
	"levite": {"name": "Levité", "soldier": "levit", "officer": "levit_velitel", "beast": "ohar", "terror": "ohar", "from": 1},
	"jestetani": {"name": "Ještěřani", "soldier": "jestetan", "officer": "jestetan_velitel", "beast": "lihnoun", "terror": "lihnoun", "from": 2},
	"bijci": {"name": "Bijci", "soldier": "bijec", "officer": "bijec_velitel", "beast": "nador", "terror": "ohnivec", "from": 3},
	"myslodejove": {"name": "Myslodějové", "soldier": "bijec", "officer": "myslodej", "beast": "kolos", "terror": "kolos", "from": 3},
}

var crew_style := ""
## 0.63: crew by ship (crash / landed) - [alone, each further mercenary, most it carries]
const SHIP_CREW := {"scout": [2, 0.67, 4], "raider": [3, 1.0, 6], "harvester": [4, 1.34, 9], "supply": [7, 1.67, 13], "battleship": [8, 2.0, 15]}
var _crew_cap := 0
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
		# the make-up of the crew changes from ship to ship - you never know what waits inside:
		# the usual crew, a pack (more beasts than soldiers), a strike team (no beasts),
		# or guests from another race on board
		count = maxi(2, count + [-1, 0, 0, 0, 1][rng.randi() % 5])
		if _crew_cap > 0:
			count = mini(count, _crew_cap)
		var r := rng.randf()
		crew_style = "posádka"
		if r < 0.22:
			crew_style = "smečka"
			var nb := clampi(int(round(count * rng.randf_range(0.5, 0.65))), 1, count - 1)    # (one of them still a soldier)
			for i in nb:
				out.append(g["beast"])
			if big:
				out.append(g["officer"])
		elif r < 0.37:
			crew_style = "úderka"
			out.append(g["officer"])
		elif r < 0.5 and (not Campaign.active or month >= 1):
			crew_style = "hosté"
			var others := []
			for og in GROUPS:
				if og != gid and int(GROUPS[og]["from"]) <= month:
					others.append(og)
			if not others.is_empty():
				var o: Dictionary = GROUPS[others[rng.randi() % others.size()]]
				for i in clampi(rng.randi_range(1, 2), 1, count - 1):
					out.append(o["soldier"] if rng.randf() < 0.6 else o["beast"])
			if big and out.size() < count - 1:
				out.append(g["officer"])
		else:
			if big or rng.randf() < 0.3:
				out.append(g["officer"])
			for i in (rng.randi_range(1, 2) if count >= 4 else (1 if rng.randf() < 0.5 else 0)):
				out.append(g["beast"])
		if gid == "bijci" and count >= 6:
			out.append("ohnivec")
	while out.size() < count:
		out.append(g["soldier"])
	if Game.autotest() != "": print("[CREW] %s %s: %s" % [gid, crew_style, out])
	crew_group = gid
	if _crew_cap > 0:
		return out.slice(0, mini(max(count + 1, 1), _crew_cap))
	return out.slice(0, max(count + 1, 1))

## Host: brings a new alien into the mission (a Líhavec hatching, a victim rising).
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
	elif race == "mozek" or race == "pylon":
		a.set_script(BossScript)
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

## A Líhavec tearing its way out of a body.
@rpc("authority", "call_local", "reliable")
func burst_fx(p: Vector3, hatch := false) -> void:
	blood_fx(p)
	blood_fx(p + Vector3(0, 0.3, 0))
	Game.play_at(self, "burst", p, 2)
	if hatch:
		Game.play_at(self, "egg_burst", p, 0)      # the brood tearing its way out
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
	_prep_tick(delta)
	_nav_tick(delta)
	if home():
		_home_tick(delta)
		_mines_tick()
		return
	if indoor():
		_home_tick(delta)
	if started():
		t += delta
		_critters(delta)
		_hatch_tick(delta)
		_drone_tick(delta)
		_guard_drone_tick()
		_late_tick(delta)
	for l in map.get("lights", []):
		if is_instance_valid(l):
			l.light_energy = 1.4 + sin(t * 13.0) * 0.25 + sin(t * 7.3) * 0.2
	_electric(delta)
	_fires_tick(delta)
	_mines_tick()
	_storm_fx(delta)
	_hallucinate(delta)
	if multiplayer.is_server() and _spawned and not finished:
		_doors_tick(delta)
		_watch_tick(delta)
		_objectives_tick(delta)
		_judge()
		_director(delta)
		_risen()

## Host: a mercenary who bled out with a Líhavec's seed inside does not stay down.
func _risen() -> void:
	for p in players():
		if p.dead and p.infected and not p.has_meta("risen"):
			p.set_meta("risen", true)
			var at: Vector3 = p.global_position
			get_tree().create_timer(6.0).timeout.connect(func():
				if not finished and is_instance_valid(p):
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

var _roof_t := 0.0
func _storm_fx(delta: float) -> void:
	# wind for trees, wheat and grass: a slow swell, a shove with every lightning
	var ws := (1.0 + 0.45 * sin(t * 0.13) + 0.25 * sin(t * 0.41 + 1.0)) * _wind_base + (0.8 if _flash_t > 0 else 0.0)
	RenderingServer.global_shader_parameter_set("wind_strength", ws)
	var me := local_player()
	if me and rain:
		rain.global_position = me.global_position + Vector3(0, 7, 0) + me.velocity * 0.4
		# under a roof (a house, a barn, inside their ship) it does not rain
		_roof_t -= delta
		if _roof_t <= 0.0:
			_roof_t = 0.3
			var q := PhysicsRayQueryParameters3D.create(me.global_position + Vector3(0, 1.8, 0), me.global_position + Vector3(0, 30, 0), 1)
			var under := not get_world_3d().direct_space_state.intersect_ray(q).is_empty()
			rain.visible = not under
			if _rain_out:
				var tw := create_tween().set_parallel()
				tw.tween_property(_rain_out, "volume_db", RAIN_DB - (12.0 if under else 0.0), 0.5)
				tw.tween_property(_rain_roof, "volume_db", -9.0 if under else -60.0, 0.5)
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
			get_tree().create_timer(i * 0.45).timeout.connect(func(): if is_instance_valid(p): Game.play_at(self, "step_%s%d" % [Game.surface_at(self, p.global_position, map), i], p.global_position + back, -8))
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
	if not AD.off():
		AD.tick(self, delta, ps)
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
		var pick := ["rustle", "rustle", "creak", "creak"]
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
		if not AD.off():
			# (0.64) only in a quiet build-up, and only a man they know is out alone - where they last had him
			var lk: Array = AD.lone_known(self, ps) if AD.phase(self) == "build" and AD.quiet(self) > 25.0 else []
			if not lk.is_empty():
				var hunter2: Node = null
				for a in aliens():
					if not a.dead and a.state == a.S.LURK and (hunter2 == null or a.global_position.distance_to(lk[1]) < hunter2.global_position.distance_to(lk[1])):
						hunter2 = a
				if hunter2:
					hunter2._tlog("director hunt %s" % lk[0].name)
					hunter2.stalk(lk[0], lk[1])
		elif t - combat_t > 20.0:
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

## The mercenaries' part of a mission reward (split between them); the rest goes to the base.
const MERC_SHARE := 0.4

## Quiet beats (no radio chatter any more): a knock on the hull, a lure in the barn, the
## power going out. And when the job is done, the banner at the top says so.
var done_banner := false

func _story(ps: Array) -> void:
	if not AD.off():
		# (0.64) the beats wait for a quiet moment: never in a fight, never right after one
		if t > 60.0 and not _radio_done.has("knock_snd") and AD.beat_ok(self, 40.0, 0.0):
			_radio_done["knock_snd"] = true
			_knock.rpc()
		elif t > 100.0 and map["barn"] != Vector3.ZERO and not _radio_done.has("lure") and _radio_done.has("knock_snd") and AD.beat_ok(self, 30.0):
			_radio_done["lure"] = true
			for a in aliens():
				if not a.dead and a.state == a.S.LURK:
					a.lurk_at(map["barn"])
					break
		elif t > 150.0 and not _radio_done.has("power") and _radio_done.has("knock_snd") and AD.beat_ok(self, 35.0):
			_radio_done["power"] = true
			_blackout.rpc()
		if not done_banner and _objective_met():
			_show_done.rpc()
		return
	if t > 95.0 and not _radio_done.has("knock_snd"):
		_radio_done["knock_snd"] = true
		_knock.rpc()
	if t > 150.0 and map["barn"] != Vector3.ZERO and not _radio_done.has("lure"):
		_radio_done["lure"] = true
		for a in aliens():
			if not a.dead and a.state == a.S.LURK:
				a.lurk_at(map["barn"])
				break
	if t > 210.0 and not _radio_done.has("power"):
		_radio_done["power"] = true
		_blackout.rpc()
	if not done_banner and _objective_met():
		_show_done.rpc()

## Is the task of this mission fulfilled (the team may fly home with a success)?
func _objective_met() -> bool:
	match mtype():
		"rescue":
			var v := vip()
			return v != null and v.saved
		"sabotage":
			return not beacons.is_empty() and beacons_left() == 0
		"base", "mars":
			return false
		"alienbase":
			return core_down()
	return _spawned and aliens_total > 0 and alive_aliens() == 0

@rpc("authority", "call_local", "reliable")
func _show_done() -> void:
	done_banner = true
	Game.play_ui(self, "ping", -6)
	if hud:
		hud.message("ÚKOL SPLNĚN. Enter = odletět hned, transport vás vyzvedne (k lodi se vracet nemusíte).", 8.0)

# ---- rockets, explosions, smoke and mines --------------------------------------------------
@rpc("any_peer", "call_local", "reliable")
func fire_rocket(from: Vector3, dir: Vector3, shooter: String, kind := "rocket") -> void:
	var r := Node3D.new()
	r.set_script(preload("res://scripts/rocket.gd"))
	r.kind = kind
	r.dir = dir
	r.shooter = shooter
	r.mission = self
	add_child(r)
	r.global_position = from

## A blast's bang (0.57): the beasts that hunt by ear are deafened by it (Pitva Ohaře).
func blast_shock(p: Vector3, radius: float) -> void:
	for a in aliens():
		if not a.dead and a.global_position.distance_to(p) < radius:
			a.blast_near(p)

## Host: damage around a point (rockets, autocannon shells, mines).
@rpc("any_peer", "call_local", "reliable")
func explode(p: Vector3, radius: float, dmg: float, by: String, big: bool) -> void:
	if not multiplayer.is_server():
		return
	_boom.rpc(p, big)
	noise(p, 50.0 if big else 30.0)
	blast_shock(p, 14.0 if big else 10.0)
	blast_breakables(p, radius, dmg)
	# a blast near anything that burns may set it alight
	if randf() < (0.75 if _flammable_near(p, radius + 1.0) else 0.12):
		ignite(p)
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
			pl.hurt.rpc_id(pl.get_multiplayer_authority(), dmg * 0.6 * (1.0 - d2 / radius), p, false, "blast")

# ---- destruction: planks, fences, crates and windows break; brick and sheet metal only to
# explosives and plasma (like the old game, the ground itself stays) ------------------------------
const BREAK_MULT := {
	"bullet": {"wood": 1.0, "crate": 1.0, "glass": 1.0, "brick": 0.0, "metal": 0.0},
	"melee": {"wood": 0.5, "crate": 1.0, "glass": 1.0, "brick": 0.0, "metal": 0.0},
	"plasma": {"wood": 2.5, "crate": 2.5, "glass": 1.0, "brick": 0.6, "metal": 0.4},
	"explosion": {"wood": 3.0, "crate": 3.0, "glass": 1.0, "brick": 1.0, "metal": 0.7},
	"fire": {"wood": 1.0, "crate": 1.2, "glass": 0.6, "brick": 0.0, "metal": 0.0},
	"melt": {"wood": 3.0, "crate": 3.0, "glass": 3.0, "brick": 2.0, "metal": 1.6}}     # the Ohnivec's heat: nothing holds
var _nav_dirty := 0.0

@rpc("any_peer", "call_local", "reliable")
func hit_breakable(i: int, dmg: float, kind: String) -> void:
	if not multiplayer.is_server() or i < 0 or i >= map.get("breakables", []).size():
		return
	var n0 = map["breakables"][i]
	if not is_instance_valid(n0) or n0.get_meta("broken", false):
		return
	var n: Node3D = n0
	var k: float = BREAK_MULT.get(kind, BREAK_MULT["bullet"]).get(String(n.get_meta("break_kind")), 0.0)
	if k <= 0.0:
		return
	var hp: float = float(n.get_meta("hp")) - dmg * k
	n.set_meta("hp", hp)
	if hp <= 0.0:
		_break.rpc(i)

## A wooden building whose walls are mostly gone loses its roof (it does not hang in the air).
func _roofs_check() -> void:
	var arr: Array = map.get("breakables", [])
	for r in map.get("wood_roofs", []):
		if not is_instance_valid(r["node"]):
			continue      # (a typed var cannot take a freed node - fireshot)
		var n: Node3D = r["node"]
		if n.has_meta("falling"):
			continue
		var rect: Rect2 = r["rect"]
		var total := 0
		var gone := 0
		for b in arr:
			if not is_instance_valid(b):
				continue
			if String(b.get_meta("break_kind", "")) != "wood":
				continue
			var bp: Vector3 = (b as Node3D).global_position
			if bp.y > n.global_position.y + 0.5 or not rect.has_point(Vector2(bp.x, bp.z)):
				continue
			total += 1
			if b.get_meta("broken", false):
				gone += 1
		if total > 0 and float(gone) / total >= 0.4:
			n.set_meta("falling", true)
			Game.play_at(self, "wood_collapse", n.global_position, 4)
			var tw := create_tween()
			tw.tween_property(n, "position:y", n.position.y - 2.4, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(n, "rotation:z", randf_range(-0.25, 0.25), 0.9)
			tw.tween_interval(6.0)
			tw.tween_callback(n.queue_free)
			# dust and sparks where it hit
			var parts := CPUParticles3D.new()
			parts.one_shot = true
			parts.amount = 40
			parts.lifetime = 2.0
			parts.explosiveness = 0.8
			parts.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			parts.emission_box_extents = Vector3(rect.size.x * 0.4, 0.3, rect.size.y * 0.4)
			parts.direction = Vector3.UP
			parts.initial_velocity_min = 1.0
			parts.initial_velocity_max = 3.0
			parts.color = Color(0.25, 0.22, 0.2)
			var pm := BoxMesh.new()
			pm.size = Vector3(0.15, 0.15, 0.15)
			parts.mesh = pm
			add_child(parts)
			parts.global_position = Vector3(rect.get_center().x, n.global_position.y - 1.5, rect.get_center().y)
			parts.emitting = true
			get_tree().create_timer(3.0).timeout.connect(parts.queue_free)

## Host: a blast breaks what is around it.
func blast_breakables(p: Vector3, radius: float, dmg: float) -> void:
	if not multiplayer.is_server():
		return
	var arr: Array = map.get("breakables", [])
	for i in arr.size():
		var n = arr[i]
		if is_instance_valid(n) and not n.get_meta("broken", false):
			var d: float = n.global_position.distance_to(p)
			if d < radius + 1.0:
				hit_breakable(i, dmg * clampf(1.2 - d / (radius + 1.0), 0.2, 1.0), "explosion")

@rpc("authority", "call_local", "reliable")
func _break(i: int) -> void:
	var n0 = map["breakables"][i]
	if not is_instance_valid(n0) or n0.get_meta("broken", false):
		return
	var n: Node3D = n0
	n.set_meta("broken", true)
	var kind := String(n.get_meta("break_kind"))
	var at := n.global_position
	if n == map.get("core") and multiplayer.is_server():
		hud_note.rpc("ŘÍDICÍ JÁDRO ZNIČENO! Zpět k šachtě.")
	if n.has_meta("explode") and multiplayer.is_server():
		# the power core of a big ship: it goes up
		var ex: Array = n.get_meta("explode")
		get_tree().create_timer(0.4).timeout.connect(func(): explode(at, float(ex[0]), float(ex[1]), "-", true))
	var sz := Vector3.ONE
	var mat: Material = null
	for c in n.get_children():
		if c is MeshInstance3D and c.mesh is BoxMesh:
			sz = (c.mesh as BoxMesh).size
			mat = c.material_override
	# debris: a burst of chunks of the same stuff, a cloud of dust, a crack
	var parts := CPUParticles3D.new()
	parts.one_shot = true
	parts.amount = clampi(int(sz.x * sz.y * sz.z * 14.0) + 8, 8, 60)
	parts.lifetime = 1.6
	parts.explosiveness = 0.95
	parts.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	parts.emission_box_extents = sz * 0.5
	parts.direction = Vector3(0, 1, 0)
	parts.spread = 70.0
	parts.initial_velocity_min = 1.5
	parts.initial_velocity_max = 4.5
	parts.gravity = Vector3(0, -12, 0)
	parts.angular_velocity_min = -300
	parts.angular_velocity_max = 300
	var chunk := BoxMesh.new()
	chunk.size = Vector3(0.18, 0.1, 0.14) if kind != "glass" else Vector3(0.06, 0.06, 0.01)
	chunk.material = mat
	parts.mesh = chunk
	add_child(parts)
	parts.global_transform = n.global_transform
	parts.emitting = true
	get_tree().create_timer(2.5).timeout.connect(parts.queue_free)
	# some rubble stays (knee-high at most, so it does not block the way)
	if kind in ["brick", "wood", "crate"]:
		var rub := MeshInstance3D.new()
		var rb := BoxMesh.new()
		rb.size = Vector3(maxf(sz.x, 0.4) * 0.9, 0.18, maxf(sz.z, 0.4) * 0.9)
		rub.mesh = rb
		rub.material_override = mat
		add_child(rub)
		rub.global_position = Vector3(at.x, 0.09 + (at.y - sz.y / 2 if at.y - sz.y / 2 > 0.5 else 0.0), at.z)
		rub.rotation.y = n.global_rotation.y
	if kind == "wood" and fires.values().any(func(f): return (f["pos"] as Vector3).distance_to(at) < 5.0):
		Game.play_at(self, "wood_collapse", at, 0)
	if kind == "wood":
		_roofs_check()
	if n.has_meta("explode") or n == map.get("core"):
		Game.play_at(self, "core_explode", at, 8)
		for c in n.get_children():
			if c is AudioStreamPlayer3D: c.stop()
	Game.play_at(self, "wood_break" if kind == "wood" or kind == "crate" else ("glass_break" if kind == "glass" else "explosion"), at, -4 if kind != "brick" else -10)
	for dn in n.get_meta("deco", []):
		if is_instance_valid(dn):
			(dn as Node).queue_free()       # the window frame on a wall piece that is gone
			if (dn as Node).has_meta("mg"): merge_dirty(dn.get_meta("mg"))
	for c in n.get_children():
		if c.has_meta("mg"): merge_dirty(c.get_meta("mg"))
	n.queue_free()
	_nav_dirty = 2.0

## 0.62 výkon: rozbitý kus zmizí i ze sloučené sítě své zdi (map_gen._merge_breakable); přestaví se
## jednou na konci snímku, i když výbuch rozbije víc kusů naráz.
var _mg_dirty := {}
func merge_dirty(g) -> void:
	if not is_instance_valid(g):
		return
	if _mg_dirty.is_empty():
		_merge_flush.call_deferred()
	_mg_dirty[g] = true

func _merge_flush() -> void:
	for g in _mg_dirty:
		if is_instance_valid(g):
			preload("res://scripts/map_gen.gd").merge_build(g)
	_mg_dirty.clear()

## Host: after things broke, the aliens learn the new ways through (rebuilt in the background).
func _nav_tick(delta: float) -> void:
	if _nav_dirty <= 0.0:
		return
	_nav_dirty -= delta
	if _nav_dirty <= 0.0 and multiplayer.is_server():
		# 0.62 výkon: jen změněné čtverce mapy, pečení ve vlákně (dřív zásek ~180 ms, viz nav_cache.gd)
		if _nav_cache == null:
			_nav_prime()
		if _nav_cache:
			_nav_cache.rebake()

## 0.62 výkon: paměť geometrie cest po čtvercích (hostitel; hned při načtení mise, ne až při prvním rozbití).
var _nav_cache: RefCounted
func _nav_prime() -> void:
	var nav := find_child("Nav", true, false) as NavigationRegion3D
	if nav and nav.navigation_mesh:
		_nav_cache = preload("res://scripts/nav_cache.gd").new(nav)
		var t0 := Time.get_ticks_msec()
		_nav_cache.prime()
		if Game.autotest() != "": print("[NAV] cache %d ms" % (Time.get_ticks_msec() - t0))

@rpc("authority", "call_local", "reliable")
func _boom(p: Vector3, big: bool) -> void:
	nvg_glare(p, 30.0 if big else 18.0, 1.0 if big else 0.7)
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
	get_tree().create_timer(28.0).timeout.connect(func(): if is_instance_valid(c): c.emitting = false)
	get_tree().create_timer(35.0).timeout.connect(c.queue_free)

# ---- fire: it spreads over wood and crates, burns buildings down, hurts, and smokes ------------
## Host decides; every machine shows the flames, the light, the roar and the black smoke column
## (the smoke is a wall for the eyes - the aliens' and ours).
var fires := {}            # id -> {pos, node, light, sound, until, size}
var _fire_id := 0
var _fire_t := 0.0
const FIRE_MAX := 24

func _flammable_near(p: Vector3, r: float) -> bool:
	for b in map.get("breakables", []):
		if is_instance_valid(b) and not b.get_meta("broken", false) and String(b.get_meta("break_kind", "")) in ["wood", "crate"] \
				and (b as Node3D).global_position.distance_to(p) < r:
			return true
	return false

## Host: sets a fire at @a p (if none burns right there yet).
func ignite(p: Vector3, size := 1.0) -> void:
	if not multiplayer.is_server() or fires.size() >= FIRE_MAX:
		return
	for f in fires.values():
		if (f["pos"] as Vector3).distance_to(p) < 2.2:
			return
	_fire_id += 1
	var gp := p
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.5, 0), p + Vector3(0, -3.0, 0), 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		gp = hit.position
	_fire_on.rpc(_fire_id, gp, size, randf_range(35.0, 60.0))

@rpc("authority", "call_local", "reliable")
func _fire_on(id: int, p: Vector3, size: float, life: float) -> void:
	var n := Node3D.new()
	add_child(n)
	n.global_position = p
	var fl := CPUParticles3D.new()
	fl.amount = int(36 * size)
	fl.lifetime = 0.9
	fl.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fl.emission_box_extents = Vector3(0.7, 0.1, 0.7) * size
	fl.direction = Vector3(0, 1, 0)
	fl.spread = 12.0
	fl.gravity = Vector3(0, 2.5, 0)
	fl.initial_velocity_min = 0.6
	fl.initial_velocity_max = 1.6
	fl.scale_amount_min = 0.6
	fl.scale_amount_max = 1.4
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.85, 0.3, 1.0))
	grad.set_color(1, Color(0.7, 0.1, 0.02, 0.0))
	grad.add_point(0.4, Color(1.0, 0.45, 0.08, 0.9))
	fl.color_ramp = grad
	var qm := QuadMesh.new()
	qm.size = Vector2(0.55, 0.75) * size
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.vertex_color_use_as_albedo = true
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.material = fm
	fl.mesh = qm
	n.add_child(fl)
	# black smoke: a tall, wide column
	var sm := CPUParticles3D.new()
	sm.amount = 50
	sm.lifetime = 7.0
	sm.preprocess = 3.0
	sm.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sm.emission_sphere_radius = 1.2 * size
	sm.direction = Vector3(0, 1, 0)
	sm.spread = 25.0
	sm.gravity = Vector3(0.3, 0.6, 0)
	sm.initial_velocity_min = 0.6
	sm.initial_velocity_max = 1.2
	sm.scale_amount_min = 2.5
	sm.scale_amount_max = 5.0
	var sq := QuadMesh.new()
	sq.size = Vector2(1.8, 1.8)
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.09, 0.085, 0.08, 0.6)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smat.cull_mode = BaseMaterial3D.CULL_DISABLED
	sq.material = smat
	sm.mesh = sq
	n.add_child(sm)
	sm.position = Vector3(0, 1.6, 0)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.5, 0.15)
	l.light_energy = 2.5
	l.omni_range = 9.0 * size
	l.shadow_enabled = true
	Game.shadow_light(l)
	n.add_child(l)
	l.position = Vector3(0, 1.0, 0)
	var snd := AudioStreamPlayer3D.new()
	snd.stream = Game.loop_stream("fire_crackle")
	snd.unit_size = 4.0
	snd.max_distance = 40.0
	snd.volume_db = -4.0
	snd.bus = "SFX"
	n.add_child(snd)
	snd.play()
	Game.play_at(self, "fire_ignite", p + Vector3.UP * 0.5, -2)
	fires[id] = {"pos": p, "node": n, "light": l, "until": t + life, "size": size, "flames": fl, "smoke": sm}
	# the smoke blocks sight like a smoke grenade, a little above the flames
	smokes.append({"pos": p + Vector3(0, 0.6, 0), "until": t + life + 8.0})

@rpc("authority", "call_local", "reliable")
func _fire_off(id: int) -> void:
	if not fires.has(id):
		return
	var f: Dictionary = fires[id]
	fires.erase(id)
	(f["flames"] as CPUParticles3D).emitting = false
	(f["smoke"] as CPUParticles3D).emitting = false
	(f["light"] as OmniLight3D).queue_free()
	var n: Node3D = f["node"]
	get_tree().create_timer(8.0).timeout.connect(func(): if is_instance_valid(n): n.queue_free())
	# a black scorch where it burned
	var sc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.4 * float(f["size"]); cm.bottom_radius = cm.top_radius; cm.height = 0.01
	sc.mesh = cm
	sc.material_override = Game.color_mat(Color(0.05, 0.045, 0.04))
	add_child(sc)
	sc.global_position = (f["pos"] as Vector3) + Vector3(0, 0.02, 0)

## Every machine: the flames flicker. The host: burns, spreads, ends.
func _fires_tick(delta: float) -> void:
	for f in fires.values():
		var l: OmniLight3D = f["light"]
		if is_instance_valid(l):
			l.light_energy = 2.0 + randf() * 1.4
	if not multiplayer.is_server() or fires.is_empty():
		return
	_fire_t -= delta
	if _fire_t > 0.0:
		return
	_fire_t = 0.5
	for id in fires.keys():
		var f: Dictionary = fires[id]
		var p: Vector3 = f["pos"]
		var r: float = 1.4 * float(f["size"])
		for pl in players():
			if not pl.dead and pl.global_position.distance_to(p) < r:
				pl.hurt.rpc_id(pl.get_multiplayer_authority(), 4.0, p, false, "heat")
		for a in aliens():
			if not a.dead and a.race != "ohnivec" and a.global_position.distance_to(p) < r:
				hit_kind = "fire"
				a.damage(5.0, p, null)
				hit_kind = ""
		# wood and crates nearby char and give way; the fire creeps onto them
		var arr: Array = map.get("breakables", [])
		for i in arr.size():
			var b = arr[i]
			if not is_instance_valid(b) or b.get_meta("broken", false):
				continue
			var kind := String(b.get_meta("break_kind", ""))
			if not kind in ["wood", "crate", "glass"]:
				continue
			var bp: Vector3 = (b as Node3D).global_position
			var d := Vector2(bp.x - p.x, bp.z - p.z).length()
			if d < 2.6:
				hit_breakable(i, 3.5, "fire")       # (it burned through a wall in seconds - slower now)
			if kind != "glass" and d < 4.8 and d > 1.5 and randf() < 0.05:
				ignite(Vector3(bp.x, p.y, bp.z), clampf(float(f["size"]) * randf_range(0.8, 1.1), 0.7, 1.4))
		if t > float(f["until"]):
			_fire_off.rpc(id)

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
		# (0.57, MN-01's entry) a pressure plate: only a foot (or a claw) on it sets it off - what floats
		# over it (Levit, Nádor, Mysloděj, Diskoll) passes untouched; and it does not ask whose foot it is
		var hit := false
		for a in aliens():
			if not a.dead and not a.R.has("hover") and not a.airborne and not a.flying \
					and a.global_position.distance_to(mn["pos"]) < 1.0 + float(a.R.get("r", 0.4)) * 0.5:
				hit = true
				break
		if not hit:
			for pl in players() + civilians():
				if not pl.dead and pl.global_position.distance_to(mn["pos"]) < 0.8:
					hit = true
					break
		if hit:
			_mine_gone.rpc(mines.find(mn))
			explode(mn["pos"], 3.8, 120.0, mn["by"], true)

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
	var n: Node3D
	if ResourceLoader.exists("res://assets/models/%s.glb" % item["id"]):
		# the thing itself, lying on its side; alien guns still glow a little
		n = Game.model(item["id"])
		n.rotation.z = PI / 2
		if Game.ITEMS[item["id"]].get("alien", false):
			var gl := OmniLight3D.new()
			gl.light_color = Color(0.7, 0.4, 1.0)
			gl.light_energy = 0.6
			gl.omni_range = 1.6
			n.add_child(gl)
	elif item["id"] == "a_pack":
		var pk := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.22; sm.height = 0.3; sm.radial_segments = 8; sm.rings = 4
		pk.mesh = sm
		pk.material_override = Game.color_mat(Color(0.18, 0.15, 0.2))
		var clasp := MeshInstance3D.new()
		var cb := BoxMesh.new()
		cb.size = Vector3(0.1, 0.04, 0.06)
		clasp.mesh = cb
		clasp.material_override = Game.color_mat(Color(0.7, 0.4, 1.0), true)
		pk.add_child(clasp)
		clasp.position = Vector3(0, 0.12, 0.12)
		n = pk
	else:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.12, 0.08, 0.55) if Game.ITEMS[item["id"]]["type"] == "weapon" else Vector3(0.18, 0.1, 0.18)
		mi.mesh = bm
		mi.material_override = Game.color_mat(Color(0.12, 0.12, 0.13))
		n = mi
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
		if not a.dead and not a.husk:       # (a fallen Nádor does not hold up the mission - but it may get up)
			n += 1
	return n

func _judge() -> void:
	var ps := players()
	if ps.is_empty():
		return
	var standing := 0
	var living := 0
	var at_evac := 0
	var done := objective_done()
	for p in ps:
		if not p.dead:
			living += 1
			if p.wants_evac and (done or p.global_position.distance_to(map["evac"]) < 3.5):
				at_evac += 1
			elif done and p.downed:
				at_evac += 1          # the transport picks up the wounded too
		if not p.dead and (not p.downed or (guard_drone != null and guard_drone.can_rescue(p))):
			standing += 1       # (the drone is about to bring him back)
	if map.has("brain"):
		for a in aliens():
			if a.race == "mozek" and a.dead and not finished:
				_end.rpc(true, "VELKÝ MOZEK JE MRTVÝ. Jejich velín na Marsu utichl - a s ním každá loď, každý Šedivák, každý hlas v hlavě. Je konec.")
				return
	var mt := mtype()
	if mt == "rescue":
		var v := vip()
		if v and v.dead and not finished:
			_end.rpc(false, "%s nepřežil. Mise selhala." % vip_name)
			return
	if mt == "base" and waves_left <= 0 and alive_aliens() == 0 and standing > 0:
		_end.rpc(true, "Základna ubráněna. Poslední vetřelec leží u plotu.")
		return
	if standing == 0:
		_end.rpc(false, "Celý tým padl." if mt != "base" else "Celý tým padl. Základna je v rukou vetřelců.")
	elif at_evac == living and mt != "base":
		var won := alive_aliens() == 0
		var why := "Posádka UFO zneškodněna." if won else "Tým se stáhl z mise."
		match mt:
			"rescue":
				var v2 := vip()
				won = v2 != null and v2.saved
				why = ("%s je v bezpečí na palubě." % vip_name) if won else ("Odlet bez %s. Mise selhala." % vip_name)
			"sabotage":
				won = beacons_left() == 0
				why = "Všechny majáky zničeny." if won else "Majáky dál volají posily. Mise selhala."
			"alienbase":
				won = core_down()
				why = "Řídicí jádro jejich základny je zničené. Bez něj jsou slepí a hluší." if won else "Jádro dál stojí. Základna vetřelců přežila."
		_end.rpc(won, why, done)

## Is the job done? Then Enter anywhere ends the mission - the transport comes for everybody.
## Every machine knows it from the host's banner (_show_done), so the client's Enter works too.
var _airlift := false
## (0.57) The mission was given up from the pause menu: who is not at the evac point stays out there.
var _abandoned := false
## Host: co-op players who walked out of it through the menu (their mercs count as lost).
var _deserters := 0
func objective_done() -> bool:
	return done_banner

## Is there solid world between two points (walls, rocks - not bodies)?
func blocked_from(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()

## Host: a PG-01 went off here. The ground smoulders (X-WEP-010: what it touches may burn),
## and near the UFO it cooks part of what we wanted to take home.
var salvage_burn := 0.0
func plasma_burst(p: Vector3) -> void:
	if not multiplayer.is_server():
		return
	ignite(p, 0.7)
	if map.has("ufo") and (map["ufo"] as Vector3).distance_to(p) < 12.0:
		salvage_burn = minf(0.5, salvage_burn + 0.1)

## Won missions: everything the aliens dropped is picked up on the way out (no carrying needed).
func _loot(success: bool) -> Dictionary:
	var out := {}
	if not success:
		return out
	var r := RandomNumberGenerator.new()
	r.seed = Net.mission_seed + 77
	for a in aliens():
		# the bodies (and the living) go home on the Kondor for the laboratory
		if a.captured:
			out["live_" + a.race] = int(out.get("live_" + a.race, 0)) + 1
		elif a.dead and a.race in Campaign.WRECKS:
			# a blown-up machine: only scraps - the Diskolls one load a mission, every Kolos its own
			out["trosky_" + a.race] = int(out.get("trosky_" + a.race, 0)) + 1 if a.race == "kolos" else 1
		elif a.dead and not a.seared:
			out["corpse_" + a.race] = int(out.get("corpse_" + a.race, 0)) + 1
	for a in aliens():
		if a.dead and not a.seared and Campaign.RACE_WEAPON.has(a.race) and r.randf() < 0.6:
			var w: String = Campaign.RACE_WEAPON[a.race]
			out[w] = int(out.get(w, 0)) + 1
	var mt: String = Net.mission_params.get("type", "")
	var mk: Array = {"crash": [25, 50], "landed": [50, 100], "abduction": [30, 60], "terror": [10, 25], "rescue": [10, 30], "sabotage": [30, 60], "base": [40, 80]}.get(mt, [0, 0])
	var al: Array = {"crash": [6, 14], "landed": [10, 20], "abduction": [6, 12], "terror": [0, 3], "rescue": [2, 6], "sabotage": [6, 12], "base": [8, 16]}.get(mt, [0, 0])
	out["moskovium"] = int(r.randi_range(mk[0], mk[1]) * (1.0 - salvage_burn))
	out["slitiny"] = int(r.randi_range(al[0], al[1]) * (1.0 - salvage_burn))
	# a ship we shot down: the wreck goes to the hangar for the technicians
	if mt == "crash" and String(Net.mission_params.get("ufo", "")) != "":
		out["vrak_" + String(Net.mission_params["ufo"])] = 1
	return out

@rpc("authority", "call_local", "reliable")
func _end(success: bool, why: String, airlift := false, abandoned := false) -> void:
	if finished:
		return
	_airlift = airlift
	_abandoned = abandoned
	finished = true
	if Game.autotest() != "":
		print("[END] success=%s why=%s" % [success, why])
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var me := local_player()
	var fate := "zdráv"
	var xp_text := ""
	var q := quality(success)
	var campaign := Net.mission_params.has("cid")
	var my_pay := 0
	var my_xp := 0
	if me and not campaign:
		# a quick mission: a try-out, nothing is kept (pay, experience, wounds, death)
		fate = "rychlá mise - nic se nepočítá, tvůj voják z kampaně zůstal doma beze změny"
	elif me:
		Game.on_mission = ""        # (0.57) he came to the end of it (saved with him below)
		Game.merc["missions"] = int(Game.merc.get("missions", 0)) + 1
		Game.merc["kills"] = int(Game.merc.get("kills", 0)) + me.kills
		Game.merc["captures"] = int(Game.merc.get("captures", 0)) + me.captures
		# personal pay: the share of the reward (the base keeps the rest), what he did, what he found
		var pay: int = (100 if success else 30) + me.kills * 30 + me.captures * 80 + me.revives * 25
		if success:
			pay += int(int(Net.mission_params.get("reward", 0)) * MERC_SHARE / maxi(1, players().size()))
		pay = int(pay * q) + me.salvage
		my_pay = pay
		var purse := int(Game.merc.get("money", 0)) + pay
		if pay > 0:
			xp_text += "\nTvůj žold: +%d kr (máš %d kr)%s" % [pay, purse, ("  - z toho nálezy %d kr" % me.salvage) if me.salvage > 0 else ""]
		var aboard: bool = _airlift or me.global_position.distance_to(map["evac"]) < 3.5
		if left_behind(me) and not me.dead and not me.downed:
			# (0.57) the mission given up from the menu: nobody comes for him
			purse = maxi(0, purse - 250)
			fate = "NEZVĚSTNÝ - mise opuštěna a on nestál u místa výsadku; zůstal na místě (odškodné rodině -250 kr; úspory převzal nový voják)"
			Game.merc = Game.new_merc()
		elif left_behind(me):
			# the family is paid off: less when the body came home with the team
			var cost := 80 if aboard else 250
			purse = maxi(0, purse - cost)
			fate = "PADL - voják je mrtvý (%s, odškodné rodině -%d kr; úspory převzal nový voják)" % ["tělo jste přivezli domů" if aboard else "tělo zůstalo na místě", cost]
			Game.merc = Game.new_merc()      # the same slot gets a fresh recruit
		else:
			# experience: only the living learn
			var xp: int = 40 + (120 if success else 0) + me.kills * 25 + me.captures * 60 + me.revives * 30
			var gained: Array = Game.add_xp(xp)
			my_xp = xp
			xp_text = "\nZkušenosti +%d  (%s)" % [xp, Game.rank_name(Game.merc)]
			for g in gained:
				xp_text += "\n" + g
			if me.wounded or me.downed or me.hp < me.max_hp - 0.5:
				fate = "zraněn"
				# campaign missions: off to the sick bay for some days of game time; pulled out
				# half-dead (carried aboard on the floor) means a long stay
				if Net.mission_params.has("cid"):
					var lost_hp: float = me.max_hp * 0.8 if me.downed else me.max_hp - me.hp
					var days := Game.wound(Game.merc, lost_hp, str(Net.mission_params["cid"]), float(Net.mission_params.get("day", 0.0)))
					if me.downed:
						Game.merc["heal_days"] = float(Game.merc.get("heal_days", 0.0)) + 3.0
						days += 3.0
					if days > 0.0:
						fate = "zraněn - na marodce %d %s herního času (mezitím můžeš hrát za jiného vojáka)" % [int(days), "den" if days < 2 else ("dny" if days < 5 else "dní")]
			if me.infected and Net.mission_params.has("cid"):
				# the seed came home inside him: only the sick bay (or what the Líhavec autopsy taught us) gets it out
				var bay := bool(Net.mission_params.get("osetrovna", false))
				if bay or Game.has_research("pitva_lihnoun"):
					var op := 3.0 if bay else 6.0
					if float(Game.merc.get("heal_days", 0.0)) <= 0.0:
						Game.merc["heal_cid"] = str(Net.mission_params["cid"])
						Game.merc["heal_seen"] = float(Net.mission_params.get("day", 0.0))
					Game.merc["heal_days"] = float(Game.merc.get("heal_days", 0.0)) + op
					Game.merc["injury"] = maxf(float(Game.merc.get("injury", 0.0)), me.max_hp * 0.5)
					var dd := int(ceilf(float(Game.merc["heal_days"])))
					fate = "zárodek vyříznut%s - na marodce %d %s herního času" % [" na ošetřovně" if bay else "", dd, "den" if dd < 2 else ("dny" if dd < 5 else "dní")]
				else:
					purse = maxi(0, purse - 250)
					fate = "PADL - zárodek se v něm vylíhl cestou domů (odškodné rodině -250 kr; úspory převzal nový voják)"
					Game.merc = Game.new_merc()
		Game.merc["money"] = purse
		Game.save_merc()
		# the campaign record lives with the host
		if multiplayer.is_server() and Campaign.active:
			Campaign.keep_merc(Game.merc)
		else:
			Net.update_merc()
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
			if left_behind(p):
				lost += 1
		lost += _deserters
		if not officer_killers.is_empty():
			Campaign.mark_nemesis(officer_killers)
		var gl := gear_lost(success)
		Campaign.add_fallen(fallen_list())       # (0.70: the wall of the fallen; before mission_done saves)
		Campaign.learn_styles(AD.style_out(self), lost, players().size())     # (0.64: before mission_done saves)
		camp = Campaign.mission_done(int(Net.mission_params.get("id", -1)), success, tk, tc, lost, civ_saved, civ_dead, crew_names, _loot(success), lost >= players().size() + _deserters and not _abandoned, kits, q, gl, kits_locker)
		# what came out of their own lockers: each one crosses it off his own list
		for peer in gl:
			var ll := Campaign.locker_part(kits.get(peer, []), gl[peer], kits_locker.get(peer, {}))
			var pl2: Node = actors.get_node_or_null("P%d" % peer)
			if pl2 and not ll.is_empty():
				pl2.locker_lost.rpc_id(peer, ll)
		Net.last_result = camp
	if campaign:
		lines.append("Hodnocení mise: %s (odměny ×%.2f)" % [quality_name(q), q])
	# 0.66: a mission won and he flies home - the look into the transport with his own numbers
	if success and me and not left_behind(me) and not home() and not local() and (Game.autotest() == "" or Game.autotest() == "transport"):
		_show_transport(me, campaign, q, my_pay, my_xp, fate, camp, civ_saved, civ_dead)
		return
	hud.show_result(("MISE SPLNĚNA" if success else "MISE NEÚSPĚŠNÁ"), why + "\n\n" + "\n".join(lines) + "\n\nTvůj voják: " + fate + xp_text + ("\n\n" + camp if camp != "" else ""))
	if Game.autotest() != "": print("[END] result shown, leaving in a moment")
	get_tree().create_timer(8.0 if Game.autotest() != "campaign" else 2.0).timeout.connect(func(): _leave(""))

## 0.66 Facelift I: the team in the transport on the way home (see transport.gd). Everyone who flies
## home is there in his own look (a copy of his body); under it only this player's numbers.
const TransportScene := preload("res://scripts/transport.gd")
var transport: CanvasLayer
func _show_transport(me: Node, campaign: bool, q: float, pay: int, xp: int, fate: String, camp: String, civ_saved: int, civ_dead: int) -> void:
	Game.play_music("debriefing", false)
	Game.play_ui(hud, "mission_complete", -2)
	hud.visible = false
	var team := []
	var hurt := 0
	for p in players():
		if left_behind(p):
			continue
		var st := "down" if p.downed else ("hurt" if p.wounded or p.hp < p.max_hp * 0.6 else "ok")
		if p.downed or p.wounded or p.hp < p.max_hp - 0.5:
			hurt += 1
		team.append({"model": _body_copy(p), "state": st, "me": p == me})
	var loot := _loot(true)
	var bodies := 0
	var live := 0
	var guns := 0
	for k in loot:
		if String(k).begins_with("corpse_") or String(k).begins_with("trosky_"):
			bodies += int(loot[k])
		elif String(k).begins_with("live_"):
			live += int(loot[k])
		elif Campaign.RACE_WEAPON.values().has(k):
			guns += int(loot[k])
	var stats := [["Zabití", str(me.kills)], ["Zajatí živí", str(me.captures)],
		["Oživil jsi", str(me.revives)], ["Zranění v týmu", "%d z %d" % [hurt, players().size()]],
		["Nálezy", "%d kr" % me.salvage], ["Žold", ("+%d kr" % pay) if campaign else "-"],
		["Zkušenosti", ("+%d" % xp) if campaign and xp > 0 else "-"], ["Hodnocení", quality_name(q) if campaign else "-"],
		["Kořist: těla", str(bodies)], ["zajatci", str(live)], ["zbraně", str(guns)], ["moskovium", str(int(loot.get("moskovium", 0)))]]
	if civs_total > 0:
		stats.append_array([["Civilisté zachránění", str(civ_saved)], ["mrtví", str(civ_dead)]])
	var report := "Tvůj voják: " + fate + ("\n\n" + camp if camp != "" else "")
	var heli := String(Net.mission_params.get("transport", "kondor")) == "heli"
	transport = TransportScene.new()
	add_child(transport)
	transport.setup(team, "CESTA DOMŮ - " + String(Net.mission_params.get("type_name", "mise")).to_upper(), stats, report, heli)
	transport.closed.connect(func(): _leave(""))
	if Game.autotest() != "":
		print("[END] transport shown, %d aboard" % team.size())

## A soldier's body as it is now (look, camouflage, armour), without the gun: built new from the
## model like player._build_body, then every part shown or hidden as on him.
func _body_copy(p: Node) -> Node3D:
	var src: Node3D = p.get("merc_model")
	var c: Node3D = Game.model("merc")
	if c == null:
		return null
	c.scale = Vector3(-1, 1, 1)
	var ix: int = abs(int(p.get_multiplayer_authority())) % 4 if int(p.get_multiplayer_authority()) != 1 else 0
	for mi in c.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var sm: Material = mi.mesh.surface_get_material(i)
			if sm and sm.resource_name == "Uniform" and Game.camo == "":
				mi.set_surface_override_material(i, Game.color_mat(p.TEAM_COLORS[ix]))
			elif sm and sm.resource_name == "Patch":
				mi.set_surface_override_material(i, Game.color_mat(p.PATCH_COLORS[ix]))
	Game.apply_look(c, p.merc.get("look", {}) if p.get("merc") is Dictionary else {})
	if src:
		var shown := {}
		for mi in src.find_children("*", "MeshInstance3D", true, false):
			shown[String(mi.name)] = mi.visible
		for mi in c.find_children("*", "MeshInstance3D", true, false):
			if shown.has(String(mi.name)):
				mi.visible = shown[String(mi.name)]
	# (0.70) as dirty and bloody as he came out of it
	var ud: Node = p.get_node_or_null("UniformDirt")
	if ud:
		preload("res://scripts/uniform_dirt.gd").copy_onto(c, ud.state())
	var ap: Node = c.find_child("AnimationPlayer", true, false)
	if ap:
		ap.get_parent().remove_child(ap)
		ap.free()
	return c

## How well it went (the same on every machine: it is counted from what everybody sees):
## success, civilians saved or lost, mercenaries lost, aliens taken alive. Scales all rewards.
func quality(success: bool) -> float:
	var q := 1.0 if success else 0.35
	var lost := 0
	var caps := 0
	for p in players():
		caps += p.captures
		if left_behind(p):
			lost += 1
	lost += _deserters
	q -= 0.25 * float(lost) / maxf(1.0, float(players().size() + _deserters))
	for c in civilians():
		if c.saved: q += 0.06
		elif c.dead: q -= 0.05
	q += 0.08 * mini(caps, 3)
	return clampf(q, 0.25, 1.5)

static func quality_name(q: float) -> String:
	if q >= 1.25: return "VÝBORNĚ"
	if q >= 0.95: return "dobře"
	if q >= 0.6: return "ucházející"
	return "špatně"

## Does this one stay out there? Dead; down and not carried aboard; or (the mission given up from
## the menu) simply not standing at the evac point when the transport went.
## (0.70) Who of the team stays here, for the wall of the fallen: name, flag, mission, kills; mia = left
## behind alive (missing), not seen dead.
func fallen_list() -> Array:
	var out := []
	var where := String(Net.mission_params.get("place", ""))
	var what := String(Net.mission_params.get("type_name", ""))
	for p in players():
		if not left_behind(p):
			continue
		var mm: Dictionary = p.merc if p.get("merc") is Dictionary else {}
		out.append({"n": String(p.display_name), "f": String(mm.get("look", {}).get("flag", "")), "m": what + (" - " + where if where != "" else ""),
			"k": int(p.kills), "mia": not p.dead})
	return out

func left_behind(p: Node) -> bool:
	if p.dead:
		return true
	var aboard: bool = _airlift or p.global_position.distance_to(map["evac"]) < 3.5
	return not aboard and (p.downed or _abandoned)

## (0.57) Hardcore: "Opustit misi" in the pause menu (alive, down or dead) is not a way out of a
## mission going badly - it was possible to walk out and fly straight back in from the globe.
## Alone or the host: the mission ends as a FAILURE for the whole team (the globe drops it like
## any lost mission); who does not stand at the evac point is left behind (X-COM's abort).
## A co-op client: only he walks out - his merc is lost unless he stands at the evac point,
## the others play on and he counts among the lost at their end.
func leave_from_menu() -> void:
	if finished or home() or local():
		Net.after_mission()
		return
	if multiplayer.is_server():
		_end.rpc(false, "Mise opuštěna. Transport odletěl jen s tím, kdo stál u místa výsadku.", false, true)
		return
	# his own end, only on this machine (the result screen, his merc's fate, then out to the lobby;
	# the host takes his body out of the game as he goes - see _leave)
	_walked_out = true
	_end(false, "Opustil jsi misi. Tým pokračuje bez tebe.", false, true)

var _walked_out := false

## Host: a co-op player walked out of the mission (he is in the lobby now, still connected).
@rpc("any_peer", "call_remote", "reliable")
func _deserted() -> void:
	if not multiplayer.is_server() or finished:
		return
	var id := multiplayer.get_remote_sender_id()
	var n := actors.get_node_or_null("P%d" % id)
	if n == null:
		return
	_deserters += 1
	hud_note.rpc("%s opustil misi." % String(n.display_name))
	n.queue_free()

func _leave(why: String) -> void:
	if Game.autotest() != "": print("[END] leave '%s'" % why)
	if Game.autotest() != "" and Game.autotest() != "campaign" and not Game.autotest().begins_with("coopwipe"):
		return
	if why != "":
		# the host went away (his game, his connection): not this player's doing - his merc lives
		if Game.on_mission != "":
			Game.mission_out(false)
		Net.close()
		Net.back_to_menu()
		return
	if _walked_out and Net.is_online() and not multiplayer.is_server():
		_deserted.rpc_id(1)
	Net.after_mission()

## Host: how close each mercenary is to being spotted (the eye on his HUD).
var _watch_t := 0.0
func _watch_tick(delta: float) -> void:
	_watch_t -= delta
	if _watch_t > 0:
		return
	_watch_t = 0.2
	for p in players():
		var v := 0.0
		for a in aliens():
			if a.dead:
				continue
			if a.state == a.S.COMBAT and is_instance_valid(a.target) and a.target == p:
				v = 1.0
				break
			v = maxf(v, float(a.sus.get(String(p.name), 0.0)))
		var who: int = p.get_multiplayer_authority()
		if who == multiplayer.get_unique_id() or who in multiplayer.get_peers():
			p.set_watched.rpc_id(who, v)

# ---- objectives (0.23): rescue a VIP, sabotage three beacons, defend the base ------------------
const VIP_NAMES := ["Dr. Kateřina Hronová", "pilot Sokola Jan Vrba", "Ing. Pavel Mráček", "Dr. Ilona Šebestová", "kpt. Radek Holub"]
var vip_name := ""
var beacons := []          # every machine: [{node, pos, planted, gone}]
var _plant_t := {}         # host: beacon index -> seconds to blast
var _reinf_t := 80.0
var waves_left := 0
var _wave_t := 0.0

func mtype() -> String:
	return String(Net.mission_params.get("type", ""))

## Walking round our own base between missions (no aliens, no night - lights and terminals).
func home() -> bool:
	return mtype() == "home"

func core_down() -> bool:
	if not map.has("core"):
		return false
	var c = map["core"]
	return not is_instance_valid(c) or c.get_meta("broken", false)

## Their base underground: violet gloom, close air.
func _underground_env() -> void:
	env.background_color = Color(0.01, 0.005, 0.02)
	env.ambient_light_color = Color(0.5, 0.35, 0.7)
	env.ambient_light_energy = 0.12
	env.fog_light_color = Color(0.08, 0.04, 0.12)
	env.fog_density = 0.03
	moon.light_energy = 0.0
	moon.visible = false

## Our own copy of the base (a co-op client walking round while the host plays the globe).
## A base walk of one's own (a co-op client while the host is on the globe): this mission runs
## on its own offline branch. Remembered at the start - Net.mission_params is replaced the moment
## the host starts a real mission, and the branch must still be taken down on the way out.
var _local := false
func local() -> bool:
	return _local

var _local_roster := {}
func roster() -> Dictionary:
	if not local():
		return Net.roster
	if _local_roster.is_empty():
		var me: Dictionary = Net.roster.get(Net.multiplayer.get_unique_id(), {}) if Net.is_online() else {}
		_local_roster = {1: {"merc": me.get("merc", Game.merc), "name": me.get("name", String(Game.merc.get("name", "Voják")))}}
	return _local_roster

func _exit_tree() -> void:
	if _nav_cache:
		_nav_cache.finish()      # (0.62: pečení cest ve vlákně musí doběhnout)
	if _local:
		get_tree().set_multiplayer(null, get_path())

## Inside our base: walking round it, or defending it.
func indoor() -> bool:
	return home() or (mtype() == "base" and Net.mission_params.has("base"))

func _home_env() -> void:
	env.background_color = Color(0.02, 0.015, 0.01)
	env.ambient_light_color = Color(0.6, 0.55, 0.5)
	env.ambient_light_energy = 0.35
	env.fog_density = 0.004
	env.volumetric_fog_enabled = false
	moon.light_energy = 0.0
	moon.visible = false
	if not home():
		# under attack: the fuses are gone - darkness and the red emergency lamps
		env.ambient_light_energy = 0.06
		env.ambient_light_color = Color(0.5, 0.35, 0.35)

var _term_note := 0.0
func _home_tick(delta: float) -> void:
	for g in map.get("spinners", []):
		if is_instance_valid(g):
			if g.has_meta("scan"):
				g.position.y = fmod(Time.get_ticks_msec() * 0.0008, 2.4) - 1.2
			else:
				g.rotation.y += delta * float(g.get_meta("spin", 0.2))
	_alarm_tick(delta)
	_workers_tick(delta)
	if not home():
		return
	# the campaign clock keeps going down here (slowly): the radar may see something
	if multiplayer.is_server() and Campaign.active and started():
		_clock_t += delta
		if _clock_t >= 1.0:
			_clock_t = 0.0
			Campaign.advance(5.0 / 1440.0)
	var me := local_player()
	_term_note -= delta
	if me and _term_note <= 0.0 and hud and not hud.inventory_open:
		var tm := terminal_near(me.global_position)
		if not tm.is_empty():
			_term_note = 1.0
			hud.message("E: " + String(tm["label"]), 1.1)

# ---- alarms: orange beacons and a siren when the radar sees a UFO; red blinking when attacked ----
var _clock_t := 0.0
var _orange_t := 0.0
var _siren: AudioStreamPlayer
var _red_t := 0.0
var _home_hooked := false

func _hook_radar() -> void:
	if _home_hooked or not home() or not multiplayer.is_server() or not Campaign.active:
		return
	_home_hooked = true
	Campaign.flight_found.connect(func(f): _radar_alarm.rpc("RADAR: neznámý objekt nad %s. Do velínu!" % Campaign.nearest_place(float(f.get("lat", 0)), float(f.get("lon", 0)))))
	Campaign.mission_found.connect(func(m): _radar_alarm.rpc("RADAR: %s - %s. Do velínu!" % [String(Campaign.MTYPES[m["type"]]["name"]), String(m.get("place", ""))]))
	Campaign.research_done.connect(func(id): hud_note.rpc("Laboratoř hlásí: dokončen výzkum %s." % Campaign.RESEARCH[id]["name"]))

@rpc("authority", "call_local", "reliable")
func _radar_alarm(text: String) -> void:
	_orange_t = 25.0
	hud.message(text, 6.0)
	if _siren == null:
		_siren = AudioStreamPlayer.new()
		_siren.stream = Game.loop_stream("base_siren")
		_siren.volume_db = -8.0
		_siren.bus = "SFX"
		add_child(_siren)
	_siren.play()

func _alarm_tick(delta: float) -> void:
	_hook_radar()
	if _orange_t > 0.0:
		_orange_t -= delta
		var k := 1.0 if _orange_t > 1.0 else _orange_t
		for b in map.get("alarm_orange", []):
			if is_instance_valid(b):
				b.light_energy = 3.0 * k
				b.rotation = Vector3(-0.5, Time.get_ticks_msec() * 0.006, 0)
		if _orange_t <= 0.0 and _siren:
			_siren.stop()
	if not home():
		# the base under attack: red lamps blink - on for a moment, then darkness again
		_red_t += delta
		var on := fmod(_red_t, 2.4) < 0.7
		for r in map.get("alarm_red", []):
			if is_instance_valid(r):
				r.light_energy = move_toward(r.light_energy, 2.2 if on else 0.0, delta * 9.0)

## A worker's machine noise: one looping player, on while the tool works.
func _work_loop(wk: Dictionary, sname: String, on: bool, db: float) -> void:
	var ap: AudioStreamPlayer3D = wk.get("snd")
	if ap == null:
		ap = AudioStreamPlayer3D.new()
		ap.stream = Game.loop_stream(sname)
		ap.volume_db = db
		ap.unit_size = 3.0
		ap.max_distance = 30.0
		ap.bus = "SFX"
		add_child(ap)
		ap.global_position = wk["pos"]
		wk["snd"] = ap
	if on and not ap.playing:
		ap.play(randf() * 2.0)
	elif not on and ap.playing:
		ap.stop()

## 0.66 Facelift I: the scientists and technicians at the base (scenery, see base_npc.gd): two or three
## per room, never more than there are places to work. Not while the base is attacked (no posts then).
const BaseNpc := preload("res://scripts/base_npc.gd")
func _base_people() -> void:
	if AnimClips.get_clip("tp_npc_walk").is_empty() and Game.autotest() != "npcshot":
		return       # (Ari's movements are only in the game's .pck: without them nobody walks the base)
	var rng := RandomNumberGenerator.new()
	rng.seed = Net.mission_seed + 404
	var crews: Dictionary = map.get("npc_posts", {})
	for crew in crews:
		var c: Dictionary = crews[crew]
		var posts: Array = c["posts"]
		var busy := {}
		var n := mini(posts.size() - 2, 2 + int(rng.randf() < 0.5))
		for k in maxi(1, n):
			var npc := Node3D.new()
			npc.set_script(BaseNpc)
			add_child(npc)
			npc.setup(String(c["role"]), posts, busy, rng.randi(), rng.randf() < 0.3)

## The builders behind the tape: welding flicker and crackle, hammer blows, the jackhammer's rattle.
var _work_t := {}
func _workers_tick(delta: float) -> void:
	for wk in map.get("workers", []):
		var k := String(wk["kind"])
		var t: float = _work_t.get(wk, 0.0) - delta
		var node: Node3D = wk["node"]
		match k:
			"weld":
				var on := fmod(Time.get_ticks_msec() * 0.001 + 0.3, 4.0) < 2.6
				var l: OmniLight3D = wk["light"]
				l.light_energy = (randf_range(0.6, 2.4) if on else 0.0)
				(wk["sparks"] as CPUParticles3D).emitting = on
				_work_loop(wk, "weld_loop", on, -8.0)
				if on and t <= 0.0:
					t = randf_range(0.25, 0.5)
					Game.play_at(self, "zap", wk["pos"], -22)
			"hammer":
				if t <= 0.0:
					t = 0.7 if randf() < 0.8 else 2.5
					Game.play_at(self, "hammer", wk["pos"], -6)
					node.rotation.x = 0.12
				node.rotation.x = move_toward(node.rotation.x, 0.0, delta * 0.6)
			"drill":
				var burst := fmod(Time.get_ticks_msec() * 0.001, 5.0) < 2.2
				_work_loop(wk, "jackhammer", burst, -6.0)
				node.position.y = (randf_range(0.0, 0.025) if burst else 0.0) + float(wk.get("y0", node.position.y if not wk.has("y0") else wk["y0"]))
				if not wk.has("y0"):
					wk["y0"] = node.position.y
		_work_t[wk] = t

# ---- doors: E opens and shuts them; the aliens shove them open; a shot or a blast breaks them ----
var doors: Array = []        # [{pivot, body, open, spec}]
func _hang_doors() -> void:
	for spec in map.get("doors", []):
		var c: Vector3 = spec["c"]
		var w: float = spec["w"]
		var h: float = spec["h"]
		var ax := Vector3(1, 0, 0) if spec["along_x"] else Vector3(0, 0, 1)
		var pivot := Node3D.new()
		add_child(pivot)
		pivot.global_position = c - ax * (w / 2.0)
		pivot.rotation.y = 0.0 if spec["along_x"] else -PI / 2
		var sb := StaticBody3D.new()
		sb.collision_layer = 64
		sb.collision_mask = 0
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(w - 0.04, h, 0.06)
		cs.shape = bs
		sb.add_child(cs)
		var blast := String(spec.get("kind", "")) == "blast"
		if blast:
			bs.size.z = 0.12
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = bs.size
		mi.mesh = bm
		mi.material_override = Game.mat("planks", 1.0) if not blast else Game.mat("metal", 0.5)
		sb.add_child(mi)
		if blast:
			_blast_look(sb, w, h)
		else:
			var knob := MeshInstance3D.new()
			var km := SphereMesh.new()
			km.radius = 0.035; km.height = 0.07
			knob.mesh = km
			knob.material_override = Game.color_mat(Color(0.7, 0.6, 0.3))
			sb.add_child(knob)
			knob.position = Vector3(w / 2 - 0.12, -h / 2 + 1.0, 0.05)
		pivot.add_child(sb)
		sb.position = Vector3(w / 2, h / 2, 0)
		# it breaks like a plank wall (the base's steel only to plasma and blasts)
		sb.set_meta("break", map["breakables"].size())
		sb.set_meta("break_kind", "wood" if not blast else "metal")
		sb.set_meta("hp", 120.0 if not blast else BLAST_HP)
		map["breakables"].append(sb)
		var d := {"pivot": pivot, "body": sb, "open": false, "c": c, "base": pivot.rotation.y}
		if blast:
			d["slide"] = pivot.global_position     # it slides along itself into the wall
			d["ax"] = ax
		doors.append(d)
		if spec.get("open", false):
			_swing(d, 1.0, true)

## 0.60 blast door of the base: steel plate with a frame of ribs, yellow-black stripes at the
## bottom edge and a small window (looks the same from both sides).
const BLAST_HP := 360.0           # metal: plasma x0.4, blast x0.7 (~12 plasma rifle hits, 3 grenades)
const BLAST_PRY := 3.2            # seconds of an alien prying it before it gives (a Bijec or more aliens faster)
func _blast_look(sb: Node3D, w: float, h: float) -> void:
	var dark := Game.color_mat(Color(0.2, 0.21, 0.22))
	var yel := Game.color_mat(Color(0.85, 0.7, 0.1))
	var blk := Game.color_mat(Color(0.08, 0.08, 0.08))
	var add := func(pos: Vector3, size: Vector3, m: Material) -> void:
		var mm := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = size
		mm.mesh = b
		mm.material_override = m
		sb.add_child(mm)
		mm.position = pos
	for zs in [-1.0, 1.0]:
		var z: float = zs * 0.07
		# ribs round the edge and across the middle
		add.call(Vector3(0, h / 2 - 0.06, z), Vector3(w - 0.04, 0.1, 0.03), dark)
		add.call(Vector3(-w / 2 + 0.06, 0, z), Vector3(0.1, h - 0.04, 0.03), dark)
		add.call(Vector3(w / 2 - 0.06, 0, z), Vector3(0.1, h - 0.04, 0.03), dark)
		add.call(Vector3(0, 0.1, z), Vector3(w - 0.2, 0.08, 0.03), dark)
		# the stripes at the bottom
		var n := 8
		for k in n:
			add.call(Vector3(-w / 2 + (k + 0.5) * w / n, -h / 2 + 0.17, z), Vector3(w / n, 0.22, 0.02), yel if k % 2 == 0 else blk)
		# a small window, a handle
		add.call(Vector3(0, h / 2 - 0.55, z), Vector3(0.5, 0.25, 0.02), Game.color_mat(Color(0.25, 0.4, 0.45)))
		add.call(Vector3(w / 2 - 0.3, -0.15, z * 1.3), Vector3(0.06, 0.4, 0.05), blk)

## Power cores (big ship, alien base) hum until somebody breaks them.
func _core_hums() -> void:
	for b in map.get("breakables", []):
		if is_instance_valid(b) and (b.has_meta("explode") or b == map.get("core")):
			var ap := AudioStreamPlayer3D.new()
			ap.stream = Game.loop_stream("core_hum")
			ap.volume_db = -2.0
			ap.unit_size = 4.0
			ap.max_distance = 35.0
			ap.bus = "SFX"
			b.add_child(ap)
			ap.play()

func _swing(d: Dictionary, side: float, instant := false) -> void:
	d["open"] = side != 0.0
	if d.has("tween") and (d["tween"] as Tween).is_valid():
		(d["tween"] as Tween).kill()       # a new push wins over a swing still going
	if d.has("slide"):
		# the blast door: along itself into the corridor wall (0.1 m of it stays in sight, a handle)
		var w: float = ((d["body"] as Node3D).get_child(0).shape as BoxShape3D).size.x
		var to: Vector3 = (d["slide"] as Vector3) + (d["ax"] as Vector3) * (w - 0.1 if d["open"] else 0.0)
		if instant:
			(d["pivot"] as Node3D).global_position = to
			return
		var tws := create_tween()
		d["tween"] = tws
		tws.tween_property(d["pivot"], "global_position", to, 0.9).set_trans(Tween.TRANS_SINE)
		return
	var want: float = float(d["base"]) + side * 1.65
	if instant:
		(d["pivot"] as Node3D).rotation.y = want
		return
	var tw := create_tween()
	d["tween"] = tw
	tw.tween_property(d["pivot"], "rotation:y", want, 0.45).set_trans(Tween.TRANS_SINE)

## The door nearest to @a p (within reach), or -1.
func door_near(p: Vector3, reach := 1.8) -> int:
	var best := -1
	var bd := reach
	for i in doors.size():
		var d: Dictionary = doors[i]
		if not is_instance_valid(d["body"]):
			continue
		var dd: float = (d["c"] as Vector3).distance_to(Vector3(p.x, (d["c"] as Vector3).y, p.z))
		if dd < bd:
			bd = dd
			best = i
	return best

@rpc("any_peer", "call_local", "reliable")
func use_door(i: int, from: Vector3) -> void:
	if not multiplayer.is_server() or i < 0 or i >= doors.size():
		return
	var d: Dictionary = doors[i]
	if not is_instance_valid(d["body"]):
		return
	var side := 0.0
	if not d["open"]:
		# it opens away from whoever pushes it
		var normal := Vector3(0, 0, 1).rotated(Vector3.UP, float(d["base"]))
		side = 1.0 if normal.dot(from - (d["c"] as Vector3)) > 0.0 else -1.0
	_door_state.rpc(i, side, false)
	noise(d["c"], 7.0)

@rpc("authority", "call_local", "reliable")
func _door_state(i: int, side: float, slam: bool) -> void:
	var d: Dictionary = doors[i]
	if not is_instance_valid(d["body"]):
		return
	_swing(d, side)
	if d.has("slide"):
		# steel on rails: the old hatch of the ship's hull is the closest we have (Ari records his own later)
		Game.play_at(self, "door_bash" if slam else "ufo_door", d["c"] + Vector3(0, 1.2, 0), 0 if slam else -4)
	elif slam:
		Game.play_at(self, "door_bash", d["c"] + Vector3(0, 1.2, 0), 0)
	else:
		Game.play_at(self, "door_open" if side != 0.0 else "door_close", d["c"] + Vector3(0, 1.2, 0), -3)
		if side != 0.0 and randf() < 0.35:
			Game.play_at(self, "door_creak", d["c"] + Vector3(0, 1.4, 0), -8)     # old hinges

## Host: an alien at a shut door shoves it open (loudly). A blast door of the base it has to pry
## for a while (BLAST_PRY; a Bijec or several of them faster), with blows the whole corridor hears.
var _door_t := 0.0
func _doors_tick(delta: float) -> void:
	_door_t -= delta
	if _door_t > 0.0 or doors.is_empty():
		return
	_door_t = 0.3
	var pried := {}
	for a in aliens():
		if a.dead or a.husk:
			continue
		var i := door_near(a.global_position, 1.4)
		if i < 0 or doors[i]["open"]:
			continue
		if doors[i].has("slide"):
			pried[i] = float(pried.get(i, 0.0)) + (2.0 if String(a.race).begins_with("bijec") or String(a.race).begins_with("kolos") else 1.0)
			continue
		var normal := Vector3(0, 0, 1).rotated(Vector3.UP, float(doors[i]["base"]))
		_door_state.rpc(i, 1.0 if normal.dot(a.global_position - (doors[i]["c"] as Vector3)) > 0.0 else -1.0, true)
	for i in doors.size():
		var d: Dictionary = doors[i]
		if not d.has("slide"):
			continue
		if not pried.has(i):
			d["pry"] = maxf(0.0, float(d.get("pry", 0.0)) - 0.3 * 0.5)     # it does not heal at once
			continue
		var before := float(d.get("pry", 0.0))
		d["pry"] = before + 0.3 * float(pried[i])
		if int(before / 0.9) != int(float(d["pry"]) / 0.9):
			_door_blow.rpc(i)
			noise(d["c"], 14.0)
		if float(d["pry"]) >= BLAST_PRY:
			d["pry"] = 0.0
			_door_state.rpc(i, 1.0, true)

@rpc("authority", "call_local", "unreliable")
func _door_blow(i: int) -> void:
	if i < 0 or i >= doors.size() or not is_instance_valid(doors[i]["body"]):
		return
	Game.play_at(self, "door_bash", doors[i]["c"] + Vector3(0, 1.2, 0), -2)
	var b: Node3D = doors[i]["body"]
	var tw := create_tween()
	tw.tween_property(b, "rotation:x", 0.025, 0.06)
	tw.tween_property(b, "rotation:x", 0.0, 0.15)

func terminal_near(p: Vector3) -> Dictionary:
	for tm in map.get("terminals", []):
		if (tm["pos"] as Vector3).distance_to(p) < 1.6:
			return tm
	return {}

## The local player pressed E at a terminal.
func use_terminal(tm: Dictionary) -> void:
	Game.play_ui(self, "ui_click", -6)
	match String(tm["kind"]):
		"globe":
			if local():
				# up the lift, straight to the host's globe (the co-op connection stayed alive)
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				Net.mission_params = {}
				get_tree().change_scene_to_file("res://scenes/Geoscape.tscn" if Campaign.viewer else "res://scenes/Main.tscn")
				return
			if not multiplayer.is_server():
				hud.message("Velín ovládá hostitel.", 2.5)
				return
			_go_home_globe.rpc()
		"research":
			hud.open_screen(ResearchScreen.open(hud))
		"ency":
			hud.open_screen(Encyclopedia.open(hud))
		"ammo":
			var me := local_player()
			var got := []
			for slot in ["rh", "lh", "back", "side"]:
				var it: Dictionary = me.item_in(slot)
				var am := String(Game.ITEMS.get(String(it.get("id", "")), {}).get("ammo", ""))
				if am != "" and not am in got:
					got.append(am)
					for n in 2:
						drop_item({"id": am}, me.global_position + Vector3(0, 0.3, 0) - me.global_transform.basis.z * 0.7 + Vector3(n * 0.2, 0, 0))
			hud.message("Zásobníky leží u bedny (E sebrat)." if not got.is_empty() else "Nemáš zbraň, do které by šly náboje.", 2.5)

@rpc("authority", "call_local", "reliable")
func _go_home_globe() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Net.after_mission()

## The person to rescue (a civilian marked as VIP), or null.
func vip() -> Node:
	for c in civilians():
		if c.vip:
			return c
	return null

## A spot where a person fits (not inside a crate or a wall): the spot itself, or the nearest
## free one around it (rings of 0.35 m up to 1.4 m).
func free_spot(at: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = 0.27
	cap.height = 1.6
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.collision_mask = 1 | 64 | 128
	for r in [0.0, 0.35, 0.7, 1.05, 1.4]:
		for i in (1 if r == 0.0 else 12):
			var p: Vector3 = at + Vector3(cos(TAU * i / 12.0), 0, sin(TAU * i / 12.0)) * r
			q.transform = Transform3D(Basis(), p + Vector3(0, 0.65, 0))
			if space.intersect_shape(q, 1).is_empty():
				return p
	return at

## Host, at spawn: what each kind of mission needs on the map.
func _spawn_objectives(rng: RandomNumberGenerator) -> void:
	match mtype():
		"rescue":
			var spots: Array = map.get("vip_spots", []).duplicate()
			var best: Vector3 = _far_point(rng, 40.0)
			var bd := 0.0
			for sp in spots:
				var d: float = (sp as Vector3).distance_to(map["evac"])
				if d > bd and d > 25.0:
					bd = d
					best = sp
			# (onto the walkable ground nearest the spot: never inside furniture or a roof)
			var nm := get_world_3d().navigation_map
			if NavigationServer3D.map_get_iteration_id(nm) > 0:
				var snap := NavigationServer3D.map_get_closest_point(nm, best)
				if snap.distance_to(best) < 3.0:
					best = snap + Vector3(0, 0.3, 0)
			best = free_spot(best)
			spawner.spawn({"kind": "civ", "id": 50, "pos": best, "vip": true})
			# hunters already near the beacon
			for k in 2:
				spawn_alien(_crew(1, rng)[0], best + Vector3(rng.randf_range(-12, 12), 0.3, rng.randf_range(-12, 12)))
		"base":
			waves_left = 2 + (1 if Game.veteran() else 0) + (1 if Net.roster.size() > 2 else 0)
			if int(Net.mission_params.get("base_def", 0)) > 0:
				waves_left = maxi(1, waves_left - 1)      # (the towers keep one of their ships from landing)
			_wave_t = 75.0

## Every machine builds the beacons from the map (same seed = same places).
func _build_beacons() -> void:
	if mtype() != "sabotage":
		return
	var r := RandomNumberGenerator.new()
	r.seed = Net.mission_seed + 313
	var wp: Array = map["waypoints"].duplicate()
	var picked := []
	for tries in 400:
		if picked.size() >= 3 or wp.is_empty():
			break
		var p: Vector3 = wp[r.randi() % wp.size()]
		if p.y > 1.0 or p.distance_to(map["evac"]) < 30.0 or p.distance_to(map["ufo"]) < 14.0:
			continue
		var ok := true
		for q in picked:
			if p.distance_to(q) < 28.0 - tries * 0.05:
				ok = false
		if ok:
			picked.append(p)
	for i in picked.size():
		var n: Node3D = Game.model("pylon")
		n.scale = Vector3.ONE * 0.6
		add_child(n)
		n.global_position = picked[i] + Vector3(1.5, 0, 1.5)
		var l := OmniLight3D.new()
		l.light_color = Color(0.4, 1.0, 0.6)
		l.light_energy = 2.0
		l.omni_range = 6.0
		n.add_child(l)
		l.position = Vector3(0, 2.5, 0)
		var ap := AudioStreamPlayer3D.new()
		ap.unit_size = 2.0
		ap.max_distance = 30.0
		n.add_child(ap)
		_loop_player(ap, "hum", -12.0)
		ap.pitch_scale = 1.6
		beacons.append({"node": n, "pos": n.global_position, "planted": false, "gone": false, "light": l})

func beacons_left() -> int:
	var k := 0
	for b in beacons:
		if not b["gone"]:
			k += 1
	return k

## The beacon a mercenary stands at (-1 = none).
func beacon_near(p: Vector3) -> int:
	for i in beacons.size():
		if not beacons[i]["gone"] and not beacons[i]["planted"] and p.distance_to(beacons[i]["pos"]) < 2.6:
			return i
	return -1

@rpc("any_peer", "call_local", "reliable")
func plant(i: int) -> void:
	if not multiplayer.is_server() or i < 0 or i >= beacons.size() or beacons[i]["planted"]:
		return
	_plant_t[i] = 8.0
	_armed.rpc(i)

@rpc("authority", "call_local", "reliable")
func _armed(i: int) -> void:
	beacons[i]["planted"] = true
	(beacons[i]["light"] as OmniLight3D).light_color = Color(1.0, 0.15, 0.1)
	Game.play_at(self, "ping", beacons[i]["pos"], -2)
	if hud:
		hud.message("NÁLOŽ POLOŽENA - 8 sekund, pryč od majáku!", 3.0)

@rpc("authority", "call_local", "reliable")
func _beacon_gone(i: int) -> void:
	beacons[i]["gone"] = true
	if is_instance_valid(beacons[i]["node"]):
		beacons[i]["node"].queue_free()
	if hud:
		var left := beacons_left()
		hud.message(("Maják zničen. Zbývá %d." % left) if left > 0 else "Všechny majáky zničeny. Zpátky do Kondoru!", 3.5)

## Host, every frame: timers of the objectives.
func _objectives_tick(delta: float) -> void:
	if not started():
		return
	for i in _plant_t.keys():
		_plant_t[i] -= delta
		if _plant_t[i] <= 0.0:
			_plant_t.erase(i)
			explode(beacons[i]["pos"] + Vector3(0, 0.8, 0), 6.0, 160.0, "", true)
			_beacon_gone.rpc(i)
	if mtype() == "sabotage" and beacons_left() > 0:
		# the beacons call for help
		_reinf_t -= delta
		if _reinf_t <= 0.0:
			_reinf_t = 85.0
			var rr := RandomNumberGenerator.new()
			rr.randomize()
			spawn_alien(_crew(1, rr)[0], _edge_point(rr))
			hud_note.rpc("Maják vysílá - z temnoty přichází další vetřelec.")
	if mtype() == "base" and waves_left > 0:
		_wave_t -= delta
		if _wave_t <= 0.0 or alive_aliens() == 0:
			if _wave_t > 82.0 and alive_aliens() == 0 and _wave_t > 0.0:
				return          # the last wave is still landing
			waves_left -= 1
			_wave_t = 90.0
			var rr2 := RandomNumberGenerator.new()
			rr2.randomize()
			var n := 2 + Net.roster.size() + (1 if Game.veteran() else 0)
			var crew := _crew(n, rr2)
			var from := _edge_point(rr2)
			for k in crew.size():
				spawn_alien(crew[k], _spawn_beside(from, 3.0, rr2))
			hud_note.rpc(("DALŠÍ VLNA! Lezou dovnitř hangárem nebo šachtou výtahu (%d)." if indoor() else "DALŠÍ VLNA! Útočí od okraje rokle (%d).") % crew.size())

## A place for one of a wave near the way in @e - only where it can really stand: on the floor,
## on the same side of the walls as the way in (a hatch is in a corner: up to 3 m off it put them
## behind the wall, out of reach - Ari had to climb over the rooms to get at them).
func _spawn_beside(e: Vector3, spread: float, rr: RandomNumberGenerator) -> Vector3:
	var ss := get_world_3d().direct_space_state
	var nm := get_world_3d().navigation_map
	for k in 12:
		var c := e + Vector3(rr.randf_range(-spread, spread), 0.3, rr.randf_range(-spread, spread))
		var up := Vector3(0, 0.9, 0)
		var q := PhysicsRayQueryParameters3D.create(e + up, c + up, Game.WORLD | Game.GLASS)
		if not ss.intersect_ray(q).is_empty():
			continue          # a wall (or a barrel) between it and the way in
		var qd := PhysicsRayQueryParameters3D.create(c + up, c + Vector3(0, -1.5, 0), Game.WORLD)
		if ss.intersect_ray(qd).is_empty():
			continue          # no floor under it
		var ball := SphereShape3D.new()
		ball.radius = 0.55
		var qp := PhysicsShapeQueryParameters3D.new()
		qp.shape = ball
		qp.transform = Transform3D(Basis(), c + up)
		qp.collision_mask = Game.WORLD | Game.GLASS | 4
		if not ss.intersect_shape(qp, 1).is_empty():
			continue          # too close to a wall, a barrel or another of them (pushed apart, one would go through the wall)
		var on := NavigationServer3D.map_get_closest_point(nm, c)
		if on != Vector3.ZERO and Vector2(on.x - c.x, on.z - c.z).length() > 0.8:
			continue          # off the paths: a nook nobody walks to
		return c
	return e + Vector3(rr.randf_range(-0.3, 0.3), 0.3, rr.randf_range(-0.3, 0.3))

## Our base attacked: the ways in (hangar hatch, lift shaft) that are far from the team. Not the
## one in the room they woke in, nor one they can see - nobody is shot in the back the moment the
## mission starts. (None far enough: the farthest one.)
const BASE_ENTRY_FAR := 20.0
func _base_entries_far(team: Array, entries: Array, los := true) -> Array:
	if entries.is_empty() or team.is_empty():
		return entries
	var ss := get_world_3d().direct_space_state
	var ok: Array = []
	var best: Vector3 = entries[0]
	var bd := -1.0
	for e in entries:
		var near := 1e9
		var seen := false
		for tp in team:
			var pos: Vector3 = tp.global_position if tp is Node3D else tp
			near = minf(near, pos.distance_to(e))
			var q := PhysicsRayQueryParameters3D.create(e + Vector3(0, 1.4, 0), pos + Vector3(0, 1.4, 0), Game.WORLD)
			if los and ss.intersect_ray(q).is_empty():
				seen = true
		if Game.autotest() != "": print("[BASE]   entry %s: %.1f m%s" % [str(e), near, " seen" if seen else ""])
		if near > bd:
			bd = near
			best = e
		if near >= BASE_ENTRY_FAR and not seen:
			ok.append(e)
	if Game.autotest() != "": print("[BASE] alien entries %d of %d far from the team (farthest %.1f m)" % [ok.size(), entries.size(), bd])
	return ok if not ok.is_empty() else [best]

## A point at the edge of the map, far from the team.
func _edge_point(rr: RandomNumberGenerator) -> Vector3:
	if not map.get("entries", []).is_empty():
		# inside our base: through the hangar hatch or down the lift shaft - one far from us
		var far := _base_entries_far(players().filter(func(pl): return not pl.downed), map["entries"])
		return far[rr.randi() % far.size()]
	var s: float = map["size"]
	var best := Vector3(s / 2, 0.3, s - 4)
	var bd := 0.0
	for k in 8:
		var e := rr.randi() % 4
		var t2 := rr.randf_range(6.0, s - 6.0)
		var p: Vector3 = [Vector3(t2, 0.3, 4.0), Vector3(t2, 0.3, s - 4.0), Vector3(4.0, 0.3, t2), Vector3(s - 4.0, 0.3, t2)][e]
		var near := 999.0
		for pl in players():
			near = minf(near, pl.global_position.distance_to(p))
		if near > bd:
			bd = near
			best = p
	return best

## Mission text for the HUD's objective line.
func objective_text() -> String:
	match mtype():
		"rescue":
			var v := vip()
			if v == null:
				return ""
			if v.dead:
				return "%s je mrtvý." % vip_name
			if v.saved:
				return "%s je v Kondoru. Odlet: všichni Enter v lodi." % vip_name
			if v.st == v.C.FOLLOW:
				return "%s jde za tebou (zdraví %d/3) - do Kondoru!" % [vip_name, v.vip_hp]
			return "Najdi: %s (nouzový maják)" % vip_name
		"sabotage":
			return "Majáky: zničeno %d/%d (drž E u majáku 3 s)" % [beacons.size() - beacons_left(), beacons.size()]
		"base":
			return "Obrana základny: vln zbývá %d, vetřelců %d" % [waves_left, alive_aliens()]
	return ""

## Host: who killed one of their commanders this mission (they will remember him).
var officer_killers := []

# ---- the late war: night packs and reinforcements -------------------------------------------------
var _pack_t := 60.0
var _late_reinf_t := 0.0
var _reinf_waves := 0
var _supply_drops := 0
var _nem_done := false
## Host, every frame of a running mission.
func _late_tick(delta: float) -> void:
	if not multiplayer.is_server() or not started() or home() or mtype() in ["base", "mars"]:
		return
	if not _nem_done and t > 4.0:
		_nem_done = true
		_nemesis_start()
	var late := clampf((float(Net.mission_params.get("day", 0.0)) - 15.0) / 90.0, 0.0, 1.0)
	if Game.cmd_arg("late", "") != "":
		late = float(Game.cmd_arg("late", "0"))
	# at night they hunt in packs: a few of the waiting ones close in on one mercenary together
	if phase() == "noc":
		_pack_t -= delta
		if _pack_t <= 0.0:
			_pack_t = randf_range(lerpf(110.0, 55.0, late), lerpf(160.0, 85.0, late))
			var ps := players().filter(func(p): return not p.dead and not p.downed)
			if not ps.is_empty():
				var prey: Node = ps[randi() % ps.size()]
				var n := 0
				var want := 2 + int(round(late * 2.0)) + maxi(0, Net.roster.size() - 1)
				var near := aliens().filter(func(a): return not a.dead and not a.husk and a.state != a.S.COMBAT and a.state != a.S.DRAG \
					and a.global_position.distance_to(prey.global_position) < 70.0)
				near.sort_custom(func(a, b): return a.global_position.distance_to(prey.global_position) < b.global_position.distance_to(prey.global_position))
				for a in near:
					if n >= want:
						break
					a.stalk(prey)
					n += 1
				if n >= 2 and Game.autotest() != "": print("[LATE] night pack of %d after %s" % [n, prey.display_name])
	# terror: the supply ship over the town makes good their losses - while its holds last
	if mtype() == "terror" and _supply_drops < 2 and aliens_total > 0 and alive_aliens() <= aliens_total / 2:
		_supply_drops += 1
		var g2: Dictionary = GROUPS.get(crew_group, GROUPS.values()[0])
		var rng2 := RandomNumberGenerator.new()
		rng2.seed = Net.mission_seed + 700 + _supply_drops
		var at2: Vector3 = _far_point(rng2, 35.0)
		var n2 := 2 + maxi(0, Net.roster.size() - 1)
		for i2 in n2:
			spawn_alien(String(g2["soldier"]), free_spot(at2 + Vector3(rng2.randf_range(-3, 3), 0.3, rng2.randf_range(-3, 3))))
		if Game.autotest() != "": print("[TERROR] supply drop %d (%d)" % [_supply_drops, n2])
	# took too long: another ship drops more of them (the later in the war, the sooner)
	_late_reinf_t += delta
	var first := lerpf(600.0, 360.0, late)
	if _reinf_waves < 3 and _late_reinf_t >= first + _reinf_waves * lerpf(300.0, 200.0, late):
		_reinf_waves += 1
		var g: Dictionary = GROUPS.get(crew_group, GROUPS.values()[0])
		var cnt := 2 + int(round(late)) + maxi(0, Net.roster.size() - 1)
		var rng := RandomNumberGenerator.new()
		rng.seed = Net.mission_seed + 500 + _reinf_waves
		var at: Vector3 = _far_point(rng, 40.0)
		for i in cnt:
			spawn_alien(String(g["officer"] if i == 0 and late > 0.5 else g["soldier"]), free_spot(at + Vector3(rng.randf_range(-3, 3), 0.3, rng.randf_range(-3, 3))))
		hud_note.rpc("RADAR: další loď shodila posily (%d). Zdržujete se - pospěšte!" % cnt)
		if Game.autotest() != "": print("[LATE] reinforcements %d (wave %d)" % [cnt, _reinf_waves])

## Host, at the start: the marked ones learn they are hunted; some aliens go straight for them.
func _nemesis_start() -> void:
	var names: Array = Net.mission_params.get("nemesis", [])
	if names.is_empty():
		return
	for p in players():
		if p.display_name in names:
			p.hunted_note.rpc_id(p.get_multiplayer_authority())
			var hunters := aliens().filter(func(a): return not a.dead and (a.R.has("guns") or a.tac in ["grey", "levit", "soldier", "hunter"]))
			hunters.shuffle()
			for a in hunters.slice(0, 1 + int(hunters.size() / 3)):
				a.nemesis = p

## Host: what each mercenary took on board (lost with the Kondor if the whole team falls).
var kits := {}
var kits_now := {}        # host: what each one carries now (reported every few seconds)
var kits_locker := {}     # host: how much of each kit came from the merc's own locker
var _claimed := {}        # host: armory pieces already taken by the team
@rpc("any_peer", "call_local", "reliable")
func report_kit(ids: Array, from_locker := {}) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	id = id if id != 0 else 1
	# the armory is one for the whole team: what is over its stock stays at the base
	var allot: Dictionary = Net.mission_params.get("allot", {})
	var armory: Dictionary = Net.mission_params.get("armory", {})
	var cnt := {}
	for i in ids:
		cnt[i] = int(cnt.get(i, 0)) + 1
	var strip := {}
	if Net.mission_params.has("allot"):
		for i in cnt:
			var need := maxi(0, int(cnt[i]) - int(allot.get(i, 0)) - int(from_locker.get(i, 0)))
			var free := maxi(0, int(armory.get(i, 0)) - int(_claimed.get(i, 0)))
			var take := mini(need, free)
			_claimed[i] = int(_claimed.get(i, 0)) + take
			if need > take:
				strip[i] = need - take
	var kept := ids.duplicate()
	for i in strip:
		for k in int(strip[i]):
			kept.erase(i)
	kits[id] = kept
	kits_now[id] = kept
	kits_locker[id] = from_locker
	if not strip.is_empty():
		var pl: Node = actors.get_node_or_null("P%d" % id)
		if pl:
			pl.kit_strip.rpc_id(id, strip)

@rpc("any_peer", "call_local", "reliable")
func report_kit_now(ids: Array) -> void:
	if multiplayer.is_server():
		var id := multiplayer.get_remote_sender_id()
		kits_now[id if id != 0 else 1] = ids

## Host, at the end: what each one lost - {peer: {item: n}}. Won and home alive: what he used up or
## left lying; otherwise everything he took (it stays out there).
func gear_lost(success: bool) -> Dictionary:
	var out := {}
	for peer in kits:
		var pl: Node = actors.get_node_or_null("P%d" % peer)
		var home: bool = success and pl != null and not left_behind(pl)
		var now: Array = (kits_now.get(peer, []) as Array).duplicate() if home else []
		var lost := {}
		for i in kits[peer]:
			if i in now:
				now.erase(i)
			else:
				lost[i] = int(lost.get(i, 0)) + 1
		out[peer] = lost
	return out

## A short line for everybody (the Brain calling its guards...).
@rpc("authority", "call_local", "reliable")
func hud_note(t: String) -> void:
	if hud:
		hud.message(t, 3.0)

func _on_note(t: String) -> void:
	if hud:
		hud.message(t, 3.0)

func _on_peer_left(id: int) -> void:
	if multiplayer.is_server() and not go:
		ready_ids.erase(id)
		_ready_state.call_deferred()
	var n := actors.get_node_or_null("P%d" % id)
	if n and multiplayer.is_server():
		n.queue_free()
	hud.message("Hráč se odpojil.", 3.0)
