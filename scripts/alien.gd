extends CharacterBody3D
## "Šedák" - small grey crew of the crashed UFO. The host thinks for it.
## It does not stand and trade fire: it hides in the dark, listens, stalks
## lone mercenaries, fires once or twice and vanishes again to come from
## another side. A fallen mercenary gets dragged away into the dark.
##
## The same script runs the other ranged races (stats in RACES): Hlídač (heavy
## guard), Kněz (psionic leader), Medúza (floating). Melee races extend this in
## melee_alien.gd, the hovering machine in drone_alien.gd.

enum S { LURK, INVESTIGATE, STALK, COMBAT, SEARCH, DRAG }

const WALK := 1.5
const RUN := 3.4
const GRAVITY := 18.0
const SIGHT_ANGLE := 0.5   # cos(60°)
const BoltScript := preload("res://scripts/bolt.gd")
const AT := preload("res://scripts/alien_tactics.gd")    # (the AI plan: threats, grenades, fear, searching)

## Race table. hp, speeds, armor (damage taken x), capsule, eye height, bolt power,
## shots per burst, accuracy (miss x), rate (time between shots x), glint (eye shine),
## weak (damage x by kind: plasma / explosion / bullet), psi (1 = officer, 2 = Mysloděj).
## Groups as in the old game: Šediváci + Diskoll, Levité + Ohař, Ještěřani + Líhavci,
## Bijci + Nádor + Ohnivec, Myslodějové + Kolos.
const RACES := {
	"grey": {"name": "Šedivák", "hp": 70.0, "walk": 2.0, "run": 4.9, "tac": "grey", "armor": 1.0, "model": "grey", "h": 1.3, "r": 0.3, "eye": 1.15,
		"bolt": 1.0, "shots": [1, 2], "miss": 0.9, "glint": [Vector3(0, 1.22, -0.215), Color(0.3, 1.0, 0.4)], "hide": 1.2},
	"grey_velitel": {"name": "Šedivák velitel", "hp": 95.0, "walk": 2.0, "run": 4.9, "tac": "grey", "armor": 1.0, "model": "grey_velitel", "h": 1.35, "r": 0.3, "eye": 1.2,
		"bolt": 1.0, "shots": [1, 2], "miss": 0.9, "glint": [Vector3(0, 1.26, -0.22), Color(0.8, 0.45, 1.0)], "hide": 1.3, "psi": 1, "illusion": true},
	"diskoll": {"name": "Diskoll", "hp": 110.0, "walk": 2.8, "run": 5.5, "armor": 0.6, "model": "diskoll", "h": 0.5, "r": 0.7, "eye": 1.5,
		"bolt": 0.7, "shots": [4, 5], "miss": 0.55, "rate": 0.3, "hover": 1.45, "explode": [3.5, 40.0], "hide": 0.2,
		"weak": {"plasma": 2.0, "laser": 1.8, "explosion": 1.5}},
	"levit": {"name": "Levit", "hp": 70.0, "tac": "levit", "walk": 2.4, "run": 5.2, "armor": 1.0, "model": "levit", "h": 0.8, "r": 0.35, "eye": 1.75,
		"bolt": 1.0, "shots": [1, 3], "miss": 1.0, "hover": 1.1, "hide": 0.7, "laser": true, "grab": true, "grab_open": true},
	"levit_velitel": {"name": "Levit Mírotvůrce", "hp": 165.0, "tac": "levit", "walk": 3.0, "run": 6.6, "armor": 0.75, "model": "levit_velitel", "scale": 1.18, "h": 0.9, "r": 0.4, "eye": 1.98,
		"bolt": 1.5, "shots": [2, 3], "miss": 0.8, "hover": 1.25, "hide": 0.4, "jet": 1.7, "bolt_col": Color(0.75, 0.25, 1.0), "mend": 6.0, "frenzy": 35.0},
	"ohar": {"name": "Ohař", "hp": 160.0, "walk": 2.2, "run": 6.8, "armor": 0.8, "model": "ohar", "h": 1.1, "r": 0.5, "eye": 1.0,
		"melee": [28.0, 40.0], "reach": 2.2, "strike_cd": 1.2, "dumb": true, "pounce": [11.0, 1.75]},
	"jestetan": {"name": "Ještěřan", "hp": 190.0, "walk": 1.1, "run": 2.4, "armor": 0.6, "model": "jestetan", "h": 2.1, "r": 0.4, "eye": 2.2,
		"bolt": 1.2, "shots": [1, 2], "miss": 0.75, "hide": 0.8, "tac": "hunter", "guns": ["rifle", "rifle", "rifle", "mg", "cannon"], "nades": true, "traps": 2, "cloak": true,
		"night_eyes": true, "bite": [30.0, 45.0], "glint": [Vector3(0, 2.02, -0.3), Color(1.0, 0.6, 0.1)], "light_shy": true, "weak": {"fire": 1.5, "explosion": 1.25}},
	"jestetan_velitel": {"name": "Ještěřan velitel", "hp": 230.0, "walk": 1.2, "run": 2.6, "armor": 0.5, "model": "jestetan_velitel", "h": 2.1, "r": 0.4, "eye": 2.0,
		"bolt": 1.3, "shots": [2, 3], "miss": 0.7, "hide": 0.8, "tac": "hunter", "guns": ["rifle", "rifle", "minigun", "cannon"], "nades": true, "traps": 3, "cloak": true, "grab": true,
		"bite": [35.0, 50.0], "glint": [Vector3(0, 2.02, -0.3), Color(1.0, 0.45, 0.1)], "light_shy": true, "goggles": true, "weak": {"fire": 1.5, "explosion": 1.25}},
	"lihnoun": {"name": "Líhavec", "hp": 110.0, "walk": 2.2, "run": 6.6, "armor": 0.8, "model": "lihnoun", "h": 1.4, "r": 0.3, "eye": 1.5,
		"melee": [38.0, 52.0], "reach": 1.8, "strike_cd": 0.85, "implant": true, "pounce": [9.0, 1.45], "weak": {"plasma": 1.6, "fire": 1.6}},
	"zombie": {"name": "Nakažený", "hp": 65.0, "walk": 1.0, "run": 1.7, "armor": 1.0, "model": "zombie", "h": 1.6, "r": 0.3, "eye": 1.6,
		"melee": [14.0, 22.0], "reach": 1.5, "strike_cd": 1.6},
	"bijec": {"name": "Bijec", "hp": 200.0, "walk": 1.6, "run": 3.6, "armor": 0.75, "model": "bijec", "h": 2.1, "r": 0.42, "eye": 1.96,
		"bolt": 1.5, "shots": [2, 3], "miss": 0.7, "hide": 0.5, "tac": "soldier", "guns": ["rifle", "rifle", "mg", "cannon"], "nades": true, "bolt_col": Color(0.7, 0.3, 1.0), "no_pain": true, "armor_break": 0.35, "joints": true},
	"bijec_velitel": {"name": "Bijec velitel", "hp": 380.0, "walk": 1.6, "run": 3.6, "armor": 0.5, "model": "bijec_velitel", "h": 2.1, "r": 0.42, "eye": 1.96,
		"bolt": 1.5, "shots": [2, 4], "miss": 0.5, "hide": 0.4, "tac": "soldier", "guns": ["hminigun"], "nades": true, "heal": 3.0, "warcry": true, "no_pain": true, "armor_break": 0.35, "module": true, "joints": true, "bolt_col": Color(1.0, 0.2, 0.15)},
	"nador": {"name": "Nádor", "hp": 55.0, "walk": 1.0, "run": 1.9, "armor": 1.0, "model": "nador", "scale": 1.2, "h": 0.5, "r": 0.48, "eye": 1.1,
		"spit": "acid", "bolt": 1.1, "shots": [1, 1], "miss": 1.1, "rate": 1.6, "hover": 0.95, "hide": 0.3, "regen": true, "tac": "brute"},
	"ohnivec": {"name": "Ohnivec", "hp": 170.0, "walk": 0.9, "run": 1.2, "armor": 0.2, "model": "ohnivec", "h": 0.7, "r": 0.6, "eye": 0.6,
		"spit": "lava", "bolt": 1.4, "shots": [1, 1], "miss": 1.0, "rate": 2.2, "hide": 0.0, "touch": 22.0, "tac": "brute", "heal": 4.0,
		"weak": {"explosion": 6.0, "fire": 0.2}, "burn": true},
	"myslodej": {"name": "Mysloděj", "hp": 115.0, "walk": 1.3, "run": 2.8, "armor": 1.0, "model": "myslodej", "h": 1.6, "r": 0.4, "eye": 1.55,
		"bolt": 0.75, "shots": [1, 2], "miss": 0.8, "hover": 0.35, "hide": 1.4, "psi": 2, "tac": "psi", "teleport": true},
	"mozek": {"name": "Velký mozek", "hp": 2200.0, "walk": 0.0, "run": 0.0, "armor": 0.6, "model": "mozek", "h": 2.6, "r": 1.6, "eye": 1.3,
		"hide": 0.0, "psi": 3, "weak": {"explosion": 1.4, "laser": 1.3, "plasma": 1.2}},
	"pylon": {"name": "Pylon štítu", "hp": 260.0, "walk": 0.0, "run": 0.0, "armor": 0.7, "model": "pylon", "h": 2.9, "r": 0.6, "eye": 2.8,
		"hide": 0.0, "explode": [3.0, 25.0], "weak": {"explosion": 2.0}},
	"kolos": {"name": "Kolos", "hp": 340.0, "walk": 2.4, "run": 4.6, "armor": 0.45, "model": "kolos", "h": 2.4, "r": 0.9, "eye": 2.0,
		"bolt": 1.3, "shots": [2, 3], "miss": 0.8, "explode": [8.5, 100.0], "hide": 0.0, "tac": "brute", "weak": {"explosion": 1.3}, "climb": true, "jet": 0.45},
}

## Heavy weapons of the soldier races (each one carries one of its race's "guns").
## Override shots / rate (time between shots x) / bolt (power) / miss.
const GUNS := {
	"rifle": {},
	"mg": {"shots": [5, 8], "rate": 0.24, "bolt": 0.8, "miss": 1.25, "name": "kulomet"},
	"minigun": {"shots": [12, 18], "rate": 0.1, "bolt": 0.55, "miss": 1.55, "name": "minigun"},
	"cannon": {"shots": [1, 1], "rate": 2.4, "bolt": 2.1, "miss": 0.8, "name": "plazmové dělo"},
	"hminigun": {"shots": [16, 24], "rate": 0.09, "bolt": 0.85, "miss": 1.0, "name": "těžký plazmový minigun"},
	"rocket": {"shots": [1, 1], "rate": 3.2, "bolt": 1.0, "miss": 0.7, "name": "raketomet", "rocket": true},
	"hcannon": {"shots": [1, 2], "rate": 2.0, "bolt": 2.6, "miss": 0.75, "name": "těžké plazmové dělo"},
}
## Later in the war the soldier races bring heavier things (a share of them, growing with the days).
const GUNS_LATE := {"jestetan": ["minigun", "hcannon", "rocket"], "jestetan_velitel": ["hcannon", "rocket"],
	"bijec": ["minigun", "rocket", "hcannon"], "bijec_velitel": ["rocket"]}
## Plasma mines laid on the way (late war: more of them, and more races lay them).
const MINES := {"bijec": 1, "bijec_velitel": 2, "jestetan_velitel": 1}

func _g(key: String, def):
	var gd: Dictionary = GUNS.get(gun, {})
	return gd[key] if gd.has(key) else R.get(key, def)

func _shots() -> int:
	var sh: Array = _g("shots", [1, 1])
	return rng.randi_range(int(sh[0]), int(sh[1]))

# ---- synchronized ----
var dead := false
var alert := false
var captured := false     # knocked out alive - worth more
var lurking := true
var striking := false     # melee races: the attack animation is playing
var leaping := false      # melee races: the leap at the end of the dash (Líhavec)
var _fire_anim_t := 0.0   # a shot just went: Ari's firing movement (standing), if the model has one
const FIRE_ANIM := 0.45
const LEAP_SKIP := 0.2          # pounce clip: skip the slow start of the crouch
const LEAP_ANIM_SPEED := 1.35   # pounce clip: landing (1.35 s in) about 0.85 s after the spring starts
var husk := false         # Nádor: "dead" on the ground - must be destroyed again or it comes back
var race := "grey"
var bleeding := false     # badly hurt: it drips as it goes - a trail to follow
var activity := 0         # what it does while nobody is looking (ACTS index)
var cloak := false        # Ještěřan: blended into the dark, only the eyes show
var flying := false       # Levit: on its jets

# ---- host only ----
var hp := 70.0
var stun_dmg := 0.0
var state := S.LURK
var phase := ""            # combat: shoot / move / hide / flank
var target: Node = null
var last_seen := Vector3.ZERO
var goal := Vector3.ZERO
var wait := 0.0
var shoot_cd := 0.0
var shots_left := 0
var react := 0.0
var hide_t := 0.0
var unseen_t := 0.0
var search_t := 0.0
var dragging: Node = null
var agent: NavigationAgent3D
var mission: Node
var rng := RandomNumberGenerator.new()
var R: Dictionary = RACES["grey"]
var walk_spd := WALK
var run_spd := RUN
var psi_cd := 18.0
var bob_t := 0.0
var tac := ""             # how it fights: grey / levit / hunter / soldier / psi / brute ("" = plain)
var gun := "rifle"        # the weapon this one carries (GUNS)
var known := {}           # player name -> mission time until which it knows where he is
var can_cloak := false
var shots_fired := 0      # (tests)

# ---- every machine ----
var body: Node3D
var eye_glint: MeshInstance3D
var anim: AnimationPlayer
var _last_anim_pos := Vector3.ZERO
var _speed := 0.0
var glint_t := 0.0

## {late: 0..1 over the war, coop: mercenaries beyond the first}.
static func threat() -> Dictionary:
	var day := float(Net.mission_params.get("day", 0.0))
	var lt := clampf((day - 15.0) / 90.0, 0.0, 1.0)
	if Game.cmd_arg("late", "") != "":
		lt = float(Game.cmd_arg("late", "0"))
	return {"late": lt, "coop": maxi(0, Net.roster.size() - 1)}

var _late := 0.0
var _aim_k := 1.0
var _react_k := 1.0
var _press := 0.3
var has_nades := false
var mines_left := 0
var _duck_t := 0.0
var _seen_t := -99.0
var nemesis: Node = null      # the marked mercenary it hunts (killed one of their commanders)
var _nem_t := 0.0
# (alien_tactics.gd keeps its state here)
var _seen_pos := {}           # player name -> [where, mission time] it was last seen or reported
var _thr_t := -1.0
var _thr_cache := []
var _hurt_by := {}            # player name -> mission time he last hit it
var _fear := 0.0
var _hurt_scare := false
var _dodge_t := 0.0
var _nade_chk := 0.0
var _nade_at := Vector3.ZERO
var _nades_seen := {}
var _search_spots := []
var _srch_look := 0.0
var _rehide_t := -99.0

func is_alien() -> bool:
	return true

func setup(data: Dictionary) -> void:
	position = data["pos"]
	race = data.get("race", "grey")
	R = RACES.get(race, RACES["grey"])
	hp = float(R["hp"]) * (1.25 if Game.veteran() else (0.75 if Game.easy() else 1.0))
	walk_spd = float(R["walk"])
	run_spd = float(R["run"])
	rng.seed = int(data["id"]) * 7919 + 13
	tac = String(R.get("tac", ""))
	if R.has("guns"):
		var gl: Array = R["guns"]
		gun = String(gl[rng.randi() % gl.size()])
	traps_left = int(R.get("traps", 0))
	# how hard the war has got: late days and every extra mercenary in co-op make them tougher,
	# sharper, quicker - and better armed
	var th := threat()
	_late = float(th["late"])
	var coop := float(th["coop"])
	hp *= 1.0 + 0.35 * _late + 0.18 * coop
	_aim_k = (1.0 - 0.3 * _late) * pow(0.9, coop)
	_react_k = (1.0 - 0.35 * _late) * pow(0.92, coop)
	_press = 0.3 + 0.45 * _late + 0.1 * coop
	if GUNS_LATE.has(race) and rng.randf() < 0.15 + 0.55 * _late:
		var gl2: Array = GUNS_LATE[race]
		gun = String(gl2[rng.randi() % gl2.size()])
	has_nades = R.has("nades") or (tac in ["grey", "levit"] and _late > 0.25 and rng.randf() < _late)
	mines_left = int(MINES.get(race, 0)) + (1 if _late > 0.5 and tac in ["soldier", "hunter"] else 0)
	traps_left += int(_late * 2.0) if R.has("traps") else 0
	for who in Net.mission_params.get("habits", {}):
		for it in Net.mission_params["habits"][who]:
			if it in ["rocket_launcher", "autocannon", "grenade", "laser_cannon"]:
				_spread_out = true
	# a team that brings heavy armour: the soldiers come with their heaviest guns
	if R.has("guns") and gun != "cannon" and "cannon" in R["guns"]:
		for who in Net.mission_params.get("habits", {}):
			if "pancir" in Net.mission_params["habits"][who] and rng.randf() < 0.5:
				gun = "cannon"
	# the cloak: officers from the start; as the war goes on, their soldiers get it too
	var day := float(Net.mission_params.get("day", 0.0))
	can_cloak = R.has("cloak") and (race.ends_with("_velitel") or day >= (30.0 if Game.veteran() else 45.0) or Game.cmd_arg("cloak", "") == "1")
	collision_layer = 4
	collision_mask = 1 | 64 | 128
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = float(R["r"])
	# hovering races: the capsule reaches down to the ground (it rests on it,
	# the model floats above)
	cap.height = max(float(R["h"]) + float(R.get("hover", 0.0)) * 0.9, cap.radius * 2.0 + 0.1)
	cs.shape = cap
	cs.position.y = cap.height / 2.0
	add_child(cs)
	body = Node3D.new()
	add_child(body)
	var m := _afk_model()
	if m == null:
		m = Game.model(String(R["model"]))
	body.add_child(m)
	if R.has("scale"):
		m.scale *= float(R["scale"])
	anim = m.find_child("AnimationPlayer", true, false)
	if anim:
		_mixamo_clips()
		_afk_clips()
		for an in anim.get_animation_list():
			anim.get_animation(an).loop_mode = Animation.LOOP_NONE if an in ONE_SHOT or String(an).begins_with("death") else Animation.LOOP_LINEAR
		anim.play("idle")
		# advanced by hand, so the activity poses can be laid over the clip each frame
		anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		_rig = m.find_child("Skeleton3D", true, false)
	_attach_gun(m)
	_soft_parts(m)
	# eye glint follows the head bone
	eye_glint = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.24, 0.025, 0.01)
	eye_glint.mesh = bm
	var gl: Array = R.get("glint", [Vector3(0, float(R["eye"]), -0.2), Color(0.3, 1.0, 0.4)])
	eye_glint.material_override = Game.color_mat(gl[1], true)
	eye_glint.visible = false
	var sk: Skeleton3D = m.find_child("Skeleton3D", true, false)
	if sk and sk.find_bone("head") >= 0 and R.has("glint"):
		var att := BoneAttachment3D.new()
		att.bone_name = "head"
		sk.add_child(att)
		att.add_child(eye_glint)
		var rest := sk.get_bone_global_rest(sk.find_bone("head"))
		eye_glint.transform = rest.affine_inverse() * Transform3D(Basis(), gl[0])
	else:
		body.add_child(eye_glint)
		eye_glint.position = gl[0]
	if R.has("hover"):
		# (Ari's afk Levit hangs its tentacles down to the ground itself: just off it)
		m.position.y = float(R["hover"]) if not (_afk_native and race in AFK_GROUNDED) else 0.0
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in [":position", ":rotation", ":dead", ":alert", ":lurking", ":captured", ":striking", ":husk", ":bleeding", ":activity", ":cloak", ":flying"]:
		cfg.add_property(NodePath("." + prop))
	sync.replication_config = cfg
	sync.root_path = NodePath("..")
	add_child(sync)

func _unused_part(pos: Vector3, size: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	body.add_child(mi)
	mi.position = pos
	return mi

func _ready() -> void:
	mission = get_tree().current_scene
	# the big brain pulses, the shield pylon crackles - you hear them from afar
	if race in ["mozek", "pylon"]:
		var lp := AudioStreamPlayer3D.new()
		lp.stream = Game.loop_stream("brain_pulse" if race == "mozek" else "shield_pylon")
		lp.unit_size = 6.0
		lp.max_distance = 50.0
		lp.bus = "Ambient"
		add_child(lp)
		lp.position = Vector3(0, 1.5, 0)
		lp.autoplay = true
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.6
	agent.target_desired_distance = 0.8
	agent.radius = max(0.4, float(R["r"]))
	agent.height = 1.3
	add_child(agent)
	goal = global_position
	wait = rng.randf_range(20.0, 50.0)
	if multiplayer.is_server():
		_go_lurk.call_deferred(false)

func _physics_process(delta: float) -> void:
	_eyeshine(delta)
	_drip(delta)
	_cloak_tick(delta)
	_jet_tick(delta)
	_footsteps(delta)
	if multiplayer.is_server() and not _traps.is_empty():
		_traps_tick(delta)
	if dead:
		_death_anim(delta)
		if multiplayer.is_server() and _death_t < 8.0 and not _landed_dead:
			# shot out of the air / off a roof: it drops. (The flight moves it without physics,
			# so the "on the floor" flag is stale - move with gravity until it really lands.)
			flying = false
			_jet.clear()
			velocity = Vector3(velocity.x * 0.98, velocity.y - GRAVITY * delta, velocity.z * 0.98)
			move_and_slide()
			if is_on_floor():
				_landed_dead = true
				airborne = false
				velocity = Vector3.ZERO
		return
	if husk:
		# fallen, twitching on the ground
		bob_t += delta * 0.4
		var down_y := -float(R.get("hover", 0.0)) * 0.75
		if race == "nador" and _afk_native and _rig:
			down_y = _head_down_y()      # its head on the ground, the tentacles out to the sides
		body.position.y = lerp(body.position.y, down_y, delta * 4.0)
		body.rotation.z = sin(bob_t * 3.0) * 0.05
		_rigid_anim(delta * 0.3)
	elif R.has("hover"):
		bob_t += delta
		body.position.y = sin(bob_t * 1.7) * 0.1
		body.rotation.z = sin(bob_t * 1.1) * 0.05
		_rigid_anim(delta)
	_animate(delta)
	if not multiplayer.is_server():
		return
	if mission and not mission.started():
		return      # the team is still reading the briefing
	if activity != 0 and state != S.LURK:
		if Game.autotest() != "": print("[ACT] %s disturbed at %s (state %d)" % [name, ACTS[activity], state])
		activity = 0         # disturbed: the job is forgotten
	if can_cloak:
		_decloak_t -= delta
		cloak = _decloak_t <= 0.0 and not husk and _stagger <= 0.0
	if _stagger > 0.0:
		_stagger -= delta
		velocity.x = 0
		velocity.z = 0
		if not airborne:
			move_and_slide()
		return
	if flying:
		_fly(delta)
		return
	_think(delta)
	if airborne:
		velocity = Vector3.ZERO      # hovering on a roof / in a window
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0
	move_and_slide()

## Picks the animation from what the alien is doing (works on every machine:
## speed comes from how far it moved, the rest from synced flags).
## Hit reaction: the body jerks away from the shot and comes back (every machine).
var _flinch_t := 0.0
var _flinch_dir := Vector3.ZERO
@rpc("authority", "call_local", "unreliable")
func _flinch(from: Vector3) -> void:
	_flinch_t = 0.35
	_bleed(0.35 + randf() * 0.25)
	var d := global_position - from
	d.y = 0
	_flinch_dir = (global_transform.basis.inverse() * d.normalized()) if d.length() > 0.1 else Vector3(0, 0, 1)

## Blood by race - and not every one of them bleeds the same (some barely at all).
const BLOOD := {"grey": Color(0.35, 1.0, 0.45), "levit": Color(0.5, 0.45, 1.0), "jestetan": Color(0.75, 0.95, 0.2),
	"bijec": Color(1.0, 0.55, 0.12), "myslodej": Color(0.2, 0.95, 1.0), "lihnoun": Color(0.12, 0.55, 0.15),
	"ohar": Color(0.62, 0.9, 0.2), "nador": Color(0.82, 1.0, 0.3), "zombie": Color(0.28, 0.04, 0.03)}
var _blood_c := Color(0, 0, 0, 0)
var _blood_done := false
var _drip_t := 0.0
func _blood_col() -> Color:
	if not _blood_done:
		_blood_done = true
		var base := race.trim_suffix("_velitel")
		if BLOOD.has(base):
			var h := absi(String(name).hash())
			if h % 7 != 0:   # about one in seven leaves no trail at all
				_blood_c = BLOOD[base]
				if h % 5 == 1 and base != "zombie":   # an odd one: a different blood
					_blood_c.h = fposmod(_blood_c.h + 0.17, 1.0)
	return _blood_c

func _bleed(size: float) -> void:
	var c := _blood_col()
	if c.a <= 0.0 or mission == null:
		return
	var off := Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
	Game.blood_splat(mission, global_position + off + Vector3.UP * 0.5, c, size, race.trim_suffix("_velitel") != "zombie")

func _drip(delta: float) -> void:
	if not bleeding or dead:
		return
	_drip_t -= delta
	if _drip_t <= 0.0:
		_drip_t = randf_range(0.35, 0.8)
		_bleed(randf_range(0.08, 0.16))

func _flinch_tick(delta: float) -> void:
	if _flinch_t <= 0.0 or body == null:
		return
	_flinch_t = maxf(0.0, _flinch_t - delta)
	var k := sin(_flinch_t / 0.35 * PI) * 0.22
	body.rotation.x = _flinch_dir.z * k
	body.rotation.z = -_flinch_dir.x * k
	if _flinch_t <= 0.0:
		body.rotation.x = 0.0
		body.rotation.z = 0.0

## Cloth and tentacles that move by themselves (purely visual, every machine on its own):
## the Bijec commander's cape hangs on spring bones, the Levits' and Nádor's tentacles sway in a shader.
const TENTACLES := {"LevTent": -0.05, "MirTent": -0.05, "NadTent": -0.18}
static var _tent_shader: Shader
var _tent_meshes: Array = []
func _soft_parts(m: Node) -> void:
	var sk: Skeleton3D = m.find_child("Skeleton3D", true, false)
	if sk and sk.find_bone("cape.L.0") >= 0:
		_cape_springs(sk)
	for k: Skeleton3D in m.find_children("*", "Skeleton3D", true, false):
		if k.find_bone("tent_0_0") >= 0 or k.find_bone("tailx_0") >= 0 or k.find_bone("tail.1") >= 0:
			_afk_springs(k)
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for si in mesh.get_surface_count():
			var mat := mesh.surface_get_material(si) as StandardMaterial3D
			if mat == null or not TENTACLES.has(mat.resource_name) or _springs != null:
				continue
			if _tent_shader == null:
				_tent_shader = load("res://shaders/tentacle_sway.gdshader")
			var sm := ShaderMaterial.new()
			sm.shader = _tent_shader
			sm.set_shader_parameter("albedo", mat.albedo_color)
			sm.set_shader_parameter("roughness", mat.roughness)
			sm.set_shader_parameter("metallic", mat.metallic)
			sm.set_shader_parameter("emission", mat.emission * mat.emission_energy_multiplier if mat.emission_enabled else Color.BLACK)
			sm.set_shader_parameter("top", float(TENTACLES[mat.resource_name]))
			sm.set_shader_parameter("speed", 0.7 if race == "nador" else 1.0)
			(mi as MeshInstance3D).set_surface_override_material(si, sm)
			if not mi in _tent_meshes:
				_tent_meshes.append(mi)

func _cape_springs(sk: Skeleton3D) -> void:
	var sim := SpringBoneSimulator3D.new()
	sim.name = "Cape"
	sk.add_child(sim)
	sim.setting_count = 2
	for i in 2:
		var side: String = ["L", "R"][i]
		sim.set_root_bone_name(i, "cape.%s.0" % side)
		sim.set_end_bone_name(i, "cape.%s.3" % side)
		sim.set_extend_end_bone(i, true)
		sim.set_end_bone_length(i, 0.2)
		sim.set_stiffness(i, 0.35)
		sim.set_drag(i, 0.4)
		sim.set_gravity(i, 2.0)
		sim.set_gravity_direction(i, Vector3.DOWN)
		sim.set_radius(i, 0.05)
	# the body it falls against: the back and both legs
	for c in [["spine", 0.27, 0.75, 0.32], ["thigh.L", 0.17, 0.62, 0.24], ["thigh.R", 0.17, 0.62, 0.24],
			["shin.L", 0.14, 0.6, 0.26], ["shin.R", 0.14, 0.6, 0.26]]:
		var cap := SpringBoneCollisionCapsule3D.new()
		cap.bone_name = c[0]
		cap.radius = c[1]
		cap.height = c[2]
		cap.position_offset = Vector3(0, c[3], 0)
		sim.add_child(cap)

## 0.57: Ari's afk models with spring bones added (tools: afk_springs, see CLAUDE.md): the Levit's
## twelve tentacles (tent_<i>_0..3, tip) and the Ještěřan's tail (tailx_0..3, tip). They hang on the
## animated body and swing after it by themselves - the afk movements stay as they are. The ground
## (a plane on the root bone) keeps them out of the floor, also when the body falls dead.
var _springs: SpringBoneSimulator3D = null
func _afk_springs(sk: Skeleton3D) -> void:
	var sim := SpringBoneSimulator3D.new()
	sim.name = "Springs"
	sk.add_child(sim)
	var chains: Array = []
	var i := 0
	while sk.find_bone("tent_%d_0" % i) >= 0:
		chains.append(["tent_%d_0" % i, "tent_%d_tip" % i, 1.0, 0.35, 1.2, 0.05])
		i += 1
	if sk.find_bone("tailx_0") >= 0:
		chains.append(["tailx_0", "tailx_tip", 0.9, 0.5, 0.35, 0.08])
	if sk.find_bone("tail.1") >= 0:
		chains.append(["tail.1", "tail.6", 0.9, 0.5, 0.35, 0.08])     # the tail as a part of its own (afk_tail)
	sim.setting_count = chains.size()
	for k in chains.size():
		var c: Array = chains[k]
		sim.set_root_bone_name(k, c[0])
		sim.set_end_bone_name(k, c[1])
		sim.set_stiffness(k, c[2])
		sim.set_drag(k, c[3])
		sim.set_gravity(k, c[4])
		sim.set_gravity_direction(k, Vector3.DOWN)
		sim.set_radius(k, c[5])
		if c[1] == "tail.6":
			sim.set_extend_end_bone(k, true)
			sim.set_end_bone_length(k, 0.25)
	var root := sk.find_bone("root")
	var ground := SpringBoneCollisionPlane3D.new()
	if root >= 0 and (race in AFK_GROUNDED or not R.has("hover")):
		ground.bone_name = "root"
		ground.position_offset = Vector3(0, -sk.get_bone_global_rest(root).origin.y + 0.02, 0)
	else:
		# a skeleton of its own (the tail): the ground follows the alien (_spring_tick)
		ground.top_level = true
		_spring_ground = ground
	sim.add_child(ground)
	_springs = sim
var _spring_ground: Node3D = null

## Dead: nothing holds them in shape any more - they flop to the ground.
func _springs_limp() -> void:
	if _springs == null:
		return
	_springs.set_external_force(Vector3.ZERO)
	var sk := _springs.get_parent() as Skeleton3D
	for k in _springs.setting_count:
		_springs.set_stiffness(k, 0.06)
		_springs.set_drag(k, 0.55)
		_springs.set_gravity(k, 4.0)
		if race == "nador" and sk:
			# Nádor: its head lies on the ground, the tentacles slide out to all sides
			var r := sk.find_bone(_springs.get_root_bone_name(k))
			var e := sk.find_bone(_springs.get_end_bone_name(k))
			if r >= 0 and e >= 0:
				var out := sk.get_bone_global_pose(e).origin - sk.get_bone_global_pose(r).origin
				out.y = 0.0
				if out.length() < 0.01:
					out = Vector3(cos(k * 2.4), 0, sin(k * 2.4))
				_springs.set_gravity_direction(k, (out.normalized() * 1.0 + Vector3.DOWN * 0.35).normalized())
				_springs.set_gravity(k, 3.0)

## Up again (the Nádor rising from its husk): the tentacles hang and swing as before.
func _springs_firm() -> void:
	if _springs == null:
		return
	for k in _springs.setting_count:
		if not String(_springs.get_root_bone_name(k)).begins_with("tent_"):
			continue
		_springs.set_stiffness(k, 1.0)
		_springs.set_drag(k, 0.35)
		_springs.set_gravity(k, 1.2)
		_springs.set_gravity_direction(k, Vector3.DOWN)

## Nádor down: the body height that lays its head (the round body) on the ground.
func _head_down_y() -> float:
	var hi := _rig.find_bone("head")      # (the middle of the round body)
	if hi < 0:
		return body.position.y
	var hy: float = (_rig.global_transform * _rig.get_bone_global_pose(hi)).origin.y - global_position.y
	return body.position.y + 0.34 * float(R.get("scale", 1.0)) - hy

## The Levit's tentacles stir a little even when it hangs still (as if in a current).
func _spring_tick() -> void:
	if _spring_ground and is_inside_tree():
		_spring_ground.global_transform = Transform3D(Basis(), global_position + Vector3(0, 0.02, 0))
	if _springs == null or not R.has("hover"):
		return
	if dead or husk:
		return
	var t := bob_t
	_springs.set_external_force(global_transform.basis * Vector3(sin(t * 1.3) * 0.25, 0, cos(t * 0.9) * 0.25))

var _tent_last := Vector3.INF
var _tent_vel := Vector3.ZERO
func _tentacle_tick(delta: float) -> void:
	# from the movement itself, not from velocity: on the clients the position is all that comes
	if _tent_last != Vector3.INF and delta > 0.0:
		_tent_vel = _tent_vel.lerp((global_position - _tent_last) / delta, minf(1.0, delta * 4.0))
	_tent_last = global_position
	for mi in _tent_meshes:
		if is_instance_valid(mi):
			(mi as MeshInstance3D).set_instance_shader_parameter("vel", (mi as Node3D).global_transform.basis.inverse() * _tent_vel)

## Mixamo motion for some races (animace/mixamo_<race>.glb, made by tools/blender/retarget_mixamo.py).
## It is only in the game package, not in the sources (Mixamo licence): without it the old clips stay.
const MIXAMO_CLIPS := {"bijec": "res://animace/mixamo_bijec.glb", "bijec_velitel": "res://animace/mixamo_bijec.glb"}
const ONE_SHOT := ["roar", "vanish", "materialize"]
static var _mx_cache := {}
func _mixamo_clips() -> void:
	var path: String = MIXAMO_CLIPS.get(race, "")
	if path == "" or not ResourceLoader.exists(path):
		return
	var lib: AnimationLibrary = _mx_cache.get(path)
	if lib == null:
		lib = AnimationLibrary.new()
		var ps := load(path) as PackedScene
		if ps:
			var sc := ps.instantiate()
			var ap: AnimationPlayer = sc.find_child("AnimationPlayer", true, false)
			if ap:
				for an in ap.get_animation_list():
					lib.add_animation(an, ap.get_animation(an).duplicate())
			sc.free()
		_mx_cache[path] = lib
	var main: AnimationLibrary = anim.get_animation_library(&"")
	if main == null or lib.get_animation_list().is_empty():
		return
	var sk: Skeleton3D = body.find_child("Skeleton3D", true, false)
	for an in lib.get_animation_list():
		var a: Animation = lib.get_animation(an)
		# a bone the clip leaves out (the root, which our crouches move) is pinned to rest
		var ref: String = String(an) if main.has_animation(an) else "idle"
		if sk and main.has_animation(ref):
			var o: Animation = main.get_animation(ref)
			for t in o.get_track_count():
				var tp := o.track_get_path(t)
				if a.find_track(tp, o.track_get_type(t)) < 0:
					var bi := sk.find_bone(String(tp.get_concatenated_subnames()))
					if bi < 0:
						continue
					var nt := a.add_track(o.track_get_type(t))
					a.track_set_path(nt, tp)
					match o.track_get_type(t):
						Animation.TYPE_POSITION_3D:
							a.position_track_insert_key(nt, 0.0, sk.get_bone_rest(bi).origin)
						Animation.TYPE_ROTATION_3D:
							a.rotation_track_insert_key(nt, 0.0, sk.get_bone_rest(bi).basis.get_rotation_quaternion())
						Animation.TYPE_SCALE_3D:
							a.scale_track_insert_key(nt, 0.0, Vector3.ONE)
		if main.has_animation(an):
			main.remove_animation(an)
		main.add_animation(an, a)

## 0.57: Ari's own afk.ai movements for a race (animace/al_<race>_<clip>.json, made by
## tools/test/afk_install.gd --race=<race>; only in the game package, like the Mixamo ones - without
## them the model's own clips stay). An officer takes his ordinary race's ones where he has none of his own.
## The deaths ("death_1".."death_9", "death_crouch") replace the toppling over.
const AFK_CLIPS := ["idle", "walk", "run", "aim", "lurk", "lurk_walk", "fire", "attack", "psi", "roar",
	"death_1", "death_2", "death_3", "death_4", "death_5", "death_6", "death_7", "death_8", "death_9", "death_crouch"]
const AFK_FPS := 30.0
static var _afk_cache := {}      # clip id -> [Animation, speed m/s] (built once for the whole mission)
var _afk_deaths: Array = []      # this one's own death movements (empty: it topples over as before)
var _afk_speed := {}             # clip -> m/s its legs go at (walk, run: played faster or slower to match)
var _afk_dying := false
func _afk_clips() -> void:
	var sk: Skeleton3D = body.find_child("Skeleton3D", true, false)
	var main: AnimationLibrary = anim.get_animation_library(&"")
	if sk == null or main == null or not main.has_animation("idle"):
		return
	# the path of the skeleton as the model's own clips name it ("Armature/Skeleton3D")
	var sk_path := ""
	var ref: Animation = main.get_animation("idle")
	for t in ref.get_track_count():
		var tp := ref.track_get_path(t)
		if tp.get_subname_count() > 0:
			sk_path = String(tp).split(":")[0]
			break
	if sk_path == "":
		return
	var base := race.trim_suffix("_velitel")
	if _afk_native:
		for cn in AFK_CLIPS:
			if cn.begins_with("death_") and cn != "death_crouch" and main.has_animation(cn):
				_afk_deaths.append(cn)
		for k in 9:
			var an := "attack" if k == 0 else "attack_%d" % (k + 1)
			if main.has_animation(an):
				_attacks.append(an)
		return
	for cn in AFK_CLIPS:
		var id := ""
		for r in [race, base]:
			if FileAccess.file_exists(AnimClips.path_of("al_%s_%s" % [r, cn])):
				id = "al_%s_%s" % [r, cn]
				break
		if id == "":
			continue
		var key := "%s|%s" % [id, sk_path]
		if not _afk_cache.has(key):
			_afk_cache[key] = _afk_build(AnimClips.get_clip(id), sk, sk_path, ref)
		var made: Array = _afk_cache[key]
		if made.is_empty():
			continue
		if main.has_animation(cn):
			main.remove_animation(cn)
		main.add_animation(cn, made[0])
		if float(made[1]) > 0.1:
			_afk_speed[cn] = float(made[1])
		if cn.begins_with("death_") and cn != "death_crouch":
			_afk_deaths.append(cn)

## 0.57: a race Ari animated whole in afk.ai: his export (his model on afk's own skeleton, with all
## its movements) is the model itself - animace/afk_<race>.glb, only in the game package like the
## Mixamo movements (without it the old model stays). Its movements under the names the game asks for
## (a list: variants, taken in turn - "attack" each strike, "death_N" each a death of its own).
const AFK_MODELS := {
	"lihnoun": {"idle": "Idle_ShakeOff", "walk": "Walk", "run": "Run_Anime", "aim": "Crouch_Idle",
		"lurk": "Crouch_Idle", "lurk_walk": "Crouch_Walk", "attack": ["Zombie_Scratch", "Hook_Lead"], "roar": "Roar",
		"pounce": "Mutant_Jump_Attack",
		"death": ["Death_B", "Death_C", "Death_D", "Death_Forward", "Death_Headshot", "Death_Left", "Death_Right", "Death_Flying_Back"],
		"death_crouch": "Death_Crouching"},
	# Ještěřan: animated in afk without its tail (it gets the tail of its own, afk_tail); the commander
	# is his model on the very same afk rig (his armour skinned onto it), so the same movements
	"jestetan": {"idle": "Rifle_Idle", "walk": "Rifle_Walk", "run": "Rifle_Run", "aim": "Rifle_Aim_Idle",
		"lurk": "Rifle_Kneel_Idle", "lurk_walk": "Rifle_Crouch_Walk", "attack": ["Rifle_Butt", "Headbutt"], "fire": "Rifle_Fire",
		"death": ["Death_A", "Death_B", "Death_C", "Death_Backward", "Death_Forward", "Death_Headshot", "Death_Left", "Death_Right", "Rifle_Death"],
		"death_crouch": "Death_Crouching"},
	"jestetan_velitel": {"idle": "Rifle_Idle", "walk": "Rifle_Walk", "run": "Rifle_Run", "aim": "Rifle_Aim_Idle",
		"lurk": "Rifle_Kneel_Idle", "lurk_walk": "Rifle_Crouch_Walk", "attack": ["Rifle_Butt", "Headbutt"], "fire": "Rifle_Fire",
		"death": ["Death_A", "Death_B", "Death_C", "Death_Backward", "Death_Forward", "Death_Headshot", "Death_Left", "Death_Right", "Rifle_Death"],
		"death_crouch": "Death_Crouching"},
	"bijec": {"idle": "Rifle_Idle", "walk": "Rifle_Walk", "run": "Rifle_Run", "aim": "Rifle_Aim_Idle",
		"lurk": "Rifle_Kneel_Idle", "lurk_walk": "Rifle_Crouch_Walk", "attack": "Rifle_Butt", "fire": "Rifle_Fire", "roar": "Roar",
		"death": ["Death_B", "Death_D", "Death_Backward", "Death_Flying_Back", "Death_Headshot", "Death_Left", "Death_Right", "Death_To_Knees", "Rifle_Death"],
		"death_crouch": "Death_Crouching"},
	# Levit: Ari's own rig (skirt, tentacles - these on spring bones now); its deaths are the Ještěřan's
	# afk deaths moved onto its upper body (tools/blender/afk_springs.py), the tentacles fall by themselves
	"levit": {"idle": "Float_Idle", "walk": "Drift", "run": "Chase", "aim": "Float_Idle", "lurk": "Float_Idle",
		"death": ["Death_A", "Death_B", "Death_C", "Death_D", "Death_Flying_Back", "Rifle_Death"]},
	# Ohař: Ari's own four-legged rig (ohar_v3), 89 movements
	"ohar": {"idle": "Idle", "walk": "Walk", "run": "Run", "aim": "Combat_Idle", "lurk": "Stalk_Crouch", "lurk_walk": "Sneak",
		"attack": ["Bite", "Paw_Swipe_Left", "Bite_Lunge", "Paw_Swipe_Right"], "pounce": "Leap_Attack", "roar": "Howl",
		"death": ["Death", "Knockdown"]},
	# the races Ari animated first (their old models on rigs of his own, the same meshes and places):
	# Nakažený on afk's humanoid rig (its strikes are the Líhavec's, moved over: tools/blender/afk_zombie.py)
	"zombie": {"idle": "Idle Hurt", "walk": "Injured_Walk", "run": "Walk", "aim": "Idle Hurt", "lurk": "Idle_Rail", "lurk_walk": "Crouch_Walk",
		"attack": ["Zombie_Scratch", "Hook_Lead"],
		"death": ["Death_A", "Death_B", "Death_C", "Death_D", "Death_Backward", "Death_Forward", "Death_Left", "Death_Right", "Death_To_Knees"],
		"death_crouch": "Death_Crouching"},
	"diskoll": {"idle": "Look_Around", "walk": "Float", "run": "Spin", "aim": "Float", "lurk": "Float"},
	"kolos": {"idle": "Idle", "walk": "Walk", "run": "Walk", "aim": "Idle", "lurk": "Groom", "attack": "Bite"},
	"myslodej": {"idle": "Float_Idle", "walk": "Drift", "run": "Drift", "aim": "Sway", "lurk": "Float_Idle", "attack": ["Wail", "Cackle"],
		"vanish": "Vanish", "materialize": "Materialize"},
	"nador": {"idle": "Float_Idle", "walk": "Sway", "run": "Chase", "aim": "Float_Idle", "lurk": "Float_Idle", "fire": "Spook"},
	# Ohnivec: the walk and the death Ari added later (tools/blender/afk_merge.py)
	"ohnivec": {"idle": "Idle", "walk": "Walk", "run": "Walk", "aim": "Idle", "lurk": "Eat", "fire": "Snap", "attack": "Snap",
		"death": ["Death"]},
}
## afk exports that face -Z already (like ours): not turned round.
const AFK_NO_TURN := ["ohnivec"]
## afk models that stand on the ground by themselves (the hover is in their movements): the others
## keep the old model's hover (the same mesh, the same place) and fall out of the air when they die.
const AFK_GROUNDED := ["levit"]
## Pieces of the old model the afk export lost, hung on a bone of it: race -> {piece: bone}.
const AFK_GRAFT := {"diskoll": {"Guns": "body"}}
## The size of an afk model against the game's old one (Ari's Ohař is a head taller than the hit capsule).
const AFK_SCALE := {"ohar": 0.85}
## The leap clip for a race whose leap differs from the Líhavec's: [skip at the start, speed] -
## so that it springs ~0.15 s and lands ~0.85 s after the start, like the brain's leap (melee_alien LEAP_*).
const AFK_LEAP := {"ohar": [0.37, 0.66]}
## Our bone names on Ari's afk skeleton (Unreal style).
const AFK_BONE := {"hips": "pelvis", "spine": "spine_02", "neck": "neck_01", "head": "head",
	"upperarm.L": "upperarm_l", "forearm.L": "lowerarm_l", "hand.L": "hand_l",
	"upperarm.R": "upperarm_r", "forearm.R": "lowerarm_r", "hand.R": "hand_r",
	"thigh.L": "thigh_l", "shin.L": "calf_l", "thigh.R": "thigh_r", "shin.R": "calf_r"}
func _bn(b: String) -> String:
	return String(AFK_BONE.get(b, b)) if _afk_native else b
var _afk_native := false        # the model is Ari's afk export (its own bones: the code's bone poses stay off)
var _attacks: Array = []        # strike variants ("attack", "attack_2"...)
var _attack_i := 0
var _was_striking := false
func _afk_model() -> Node3D:
	var holder := afk_scene(race)
	if holder == null:
		return null
	holder.set_meta("model", String(R["model"]))
	_afk_native = true
	return holder

## Ari's afk model of the race with the game's clip names (null: none). Shared with the Dílna.
static func afk_scene(race_id: String) -> Node3D:
	if not AFK_MODELS.has(race_id):
		return null
	var path := "res://animace/afk_%s.glb" % race_id
	if not ResourceLoader.exists(path):
		return null
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	var holder := Node3D.new()
	var inst: Node3D = ps.instantiate()
	if not race_id in AFK_NO_TURN:
		inst.rotation.y = PI          # afk stands facing +Z, ours face -Z
	inst.scale *= float(AFK_SCALE.get(race_id, 1.0))
	afk_tail(inst, race_id)
	holder.add_child(inst)
	_afk_graft(inst, race_id)
	Game._restyle(inst)
	var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
	var lib: AnimationLibrary = ap.get_animation_library(&"") if ap else null
	if lib == null:
		holder.free()
		return null
	var map: Dictionary = AFK_MODELS[race_id]
	for cn: String in map:
		var srcs: Array = map[cn] if map[cn] is Array else [map[cn]]
		for k in srcs.size():
			var an: String = srcs[k]
			if not lib.has_animation(an):
				continue
			var nm := cn if k == 0 else "%s_%d" % [cn, k + 1]
			if cn == "death":
				nm = "death_%d" % (k + 1)
			lib.add_animation(nm, lib.get_animation(an).duplicate())
	if lib.has_animation("pounce"):
		_pin_forward(lib.get_animation("pounce"))
	return holder

## 0.57: Ari animates the Ještěřan in afk without its tail (afk's humanoid rig has none and the
## tail spoiled the movements); the tail is a model of its own (assets/models/<race>_ocas.glb, made
## by tools/blender/jestetan_v2.py ... bezocasu: tail_root, tail.1-6, in the body's own coordinates)
## hung on the pelvis here, swinging on spring bones (_afk_springs). A model that has its own tail
## bones (tailx_0 from afk_springs.py) gets none.
const AFK_TAIL := {"jestetan": "jestetan_ocas", "jestetan_velitel": "jestetan_velitel_ocas"}
static func afk_tail(inst: Node3D, race_id: String) -> void:
	var path := "res://assets/models/%s.glb" % AFK_TAIL.get(race_id, "")
	if not AFK_TAIL.has(race_id) or not ResourceLoader.exists(path):
		return
	var sk: Skeleton3D = inst.find_child("Skeleton3D", true, false)
	if sk == null or sk.find_bone("tailx_0") >= 0 or sk.find_bone("tail.1") >= 0:
		return
	var pi := sk.find_bone("pelvis")
	var hi := sk.find_bone("head")
	if pi < 0:
		return
	var tail: Node3D = (load(path) as PackedScene).instantiate()
	tail.name = "Tail"
	Game._restyle(tail)
	# the skeleton's place in the afk scene (its Armature may be turned or scaled)
	var to_sk := Transform3D()
	var n: Node = sk
	while n != inst and n is Node3D:
		to_sk = (n as Node3D).transform * to_sk
		n = n.get_parent()
	var rest := sk.get_bone_global_rest(pi)
	# the tail was made facing -Z like our models; afk's export faces +Z (head ahead of the pelvis)
	var flip := hi >= 0 and (to_sk * sk.get_bone_global_rest(hi).origin).z > (to_sk * rest.origin).z
	var place := Transform3D(Basis(Vector3.UP, PI) if flip else Basis(), Vector3.ZERO)
	var att := BoneAttachment3D.new()
	att.name = "TailMount"
	att.bone_name = "pelvis"
	sk.add_child(att)
	att.add_child(tail)
	tail.transform = rest.affine_inverse() * to_sk.affine_inverse() * place

## The old model's piece (in the old model's own place) on a bone of the afk model.
static func _afk_graft(inst: Node3D, race_id: String) -> void:
	if not AFK_GRAFT.has(race_id):
		return
	var sk: Skeleton3D = inst.find_child("Skeleton3D", true, false)
	if sk == null:
		return
	var old: Node3D = Game.model(String(RACES[race_id]["model"]))
	for pn: String in AFK_GRAFT[race_id]:
		var bi := sk.find_bone(String(AFK_GRAFT[race_id][pn]))
		var piece: Node3D = old.find_child(pn, true, false)
		if bi < 0 or piece == null:
			continue
		var at := Transform3D()
		var n: Node = piece
		while n != old and n is Node3D:
			at = (n as Node3D).transform * at
			n = n.get_parent()
		piece.get_parent().remove_child(piece)
		var att := BoneAttachment3D.new()
		att.name = "Graft" + pn
		att.bone_name = sk.get_bone_name(bi)
		sk.add_child(att)
		att.add_child(piece)
		# the skeleton's place in the model as the holder (turned round) sees it
		var to_sk := Transform3D()
		n = sk
		while n != null and n is Node3D:
			to_sk = (n as Node3D).transform * to_sk
			n = n.get_parent()
		piece.transform = sk.get_bone_global_rest(bi).affine_inverse() * to_sk.affine_inverse() * at
	old.free()

## The leap carries the body itself (the brain moves it to the prey): the pelvis keeps its height and
## bob, but not its own way forward - or it would land twice as far and snap back afterwards.
static func _pin_forward(a: Animation) -> void:
	for t in a.get_track_count():
		if a.track_get_type(t) != Animation.TYPE_POSITION_3D or not String(a.track_get_path(t).get_concatenated_subnames()) in ["pelvis", "Hips"]:
			continue
		if a.track_get_key_count(t) == 0:
			continue
		var y0: float = (a.track_get_key_value(t, 0) as Vector3).y
		for k in a.track_get_key_count(t):
			var v: Vector3 = a.track_get_key_value(t, k)
			v.y = y0
			a.track_set_key_value(t, k, v)

## A clip (our editor's form: degrees over the rest pose, keyed) as an Animation for the model's
## AnimationPlayer: every bone the model's own idle moves gets a track (the ones the clip leaves out held at rest).
static func _afk_build(c: Dictionary, sk: Skeleton3D, sk_path: String, ref: Animation) -> Array:
	if c.is_empty():
		return []
	var a := Animation.new()
	var d := maxf(0.05, float(c.get("delka", 1.0)))
	a.length = d
	var n := maxi(2, int(ceil(d * AFK_FPS)) + 1)
	var bones := {}
	for t in ref.get_track_count():
		var tp := ref.track_get_path(t)
		if tp.get_subname_count() > 0:
			bones[String(tp.get_concatenated_subnames())] = true
	for bn in c.get("stopy", {}):
		if not String(bn).contains("@"):
			bones[bn] = true
	for bn: String in bones:
		var bi := sk.find_bone(bn)
		if bi < 0:
			continue
		var rest := sk.get_bone_rest(bi)
		var rt := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(rt, NodePath("%s:%s" % [sk_path, bn]))
		if AnimClips.has_track(c, bn):
			for f in n:
				var t := minf(d, f / AFK_FPS)
				var v := AnimClips.sample(c, bn, t)
				a.rotation_track_insert_key(rt, t, rest.basis.get_rotation_quaternion() * Quaternion.from_euler(Vector3(float(v[0]), float(v[1]), float(v[2])) * (PI / 180.0)))
		else:
			a.rotation_track_insert_key(rt, 0.0, rest.basis.get_rotation_quaternion())
		if bn == "root":
			var pt := a.add_track(Animation.TYPE_POSITION_3D)
			a.track_set_path(pt, NodePath("%s:%s" % [sk_path, bn]))
			if AnimClips.has_track(c, "root@pos"):
				for f in n:
					var t := minf(d, f / AFK_FPS)
					var v := AnimClips.sample(c, "root@pos", t)
					a.position_track_insert_key(pt, t, rest.origin + Vector3(float(v[0]), float(v[1]), float(v[2])))
			else:
				a.position_track_insert_key(pt, 0.0, rest.origin)
	a.optimize()
	return [a, float(c.get("rychlost", 0.0))]

const ROAR_TIME := 3.4
var seared := false      # burnt by a plasma grenade (PG-01): nothing left for the lab or the armory
var _cry_anim_t := 0.0      # the Bijec officer's war cry: the whole body roars for a moment
var _tele_anim_t := 0.0     # Mysloděj after a teleport: Ari's Materialize

func _animate(delta: float) -> void:
	_flinch_tick(delta)
	_spring_tick()
	if not _tent_meshes.is_empty():
		_tentacle_tick(delta)
	if anim == null:
		return
	_gun_tick()
	var moved := global_position - _last_anim_pos
	moved.y = 0
	_last_anim_pos = global_position
	_speed = lerp(_speed, moved.length() / max(delta, 0.001), 0.2)
	var want := "idle"
	_cry_anim_t -= delta
	_fire_anim_t -= delta
	_tele_anim_t -= delta
	if _tele_anim_t > 0.0 and anim.has_animation("materialize"):
		want = "materialize"       # Mysloděj takes shape again where it went
	elif _cry_anim_t > 0.0 and anim.has_animation("roar"):
		want = "roar"
	elif _fire_anim_t > 0.0 and _speed < 0.5 and not lurking and anim.has_animation("fire"):
		want = "fire"              # the recoil of the shot (Ještěřan)
	elif leaping and anim.has_animation("pounce"):
		want = "pounce"            # the leap at the end of the dash
	elif striking and anim.has_animation("attack"):
		want = "attack"
		if _attacks.size() > 1:
			# Ari's strikes, one after another
			if not _was_striking:
				_attack_i = (_attack_i + 1) % _attacks.size()
			want = _attacks[_attack_i]
	elif lurking and _speed < 0.5:
		want = "lurk"
	elif lurking and _speed < walk_spd * 2.0 and anim.has_animation("lurk_walk"):
		want = "lurk_walk"         # creeping in low
	elif _speed > 2.4:
		want = "run"
	elif _speed > 0.3:
		want = "walk"
	elif alert:
		want = "aim"
	_was_striking = striking
	if not anim.has_animation(want):
		want = "idle"
	if anim.current_animation != want:
		anim.play(want, 0.25 if want != "pounce" else 0.1)
		if want == "pounce":
			anim.seek(float(AFK_LEAP.get(race, [LEAP_SKIP])[0]), true)    # straight into the crouch before the spring
	if want == "roar" or want == "materialize":
		anim.speed_scale = 1.0
		anim.advance(delta)
		_activity_pose(delta)
		return
	anim.speed_scale = clamp(_speed / walk_spd, 0.7, 1.6) if want == "walk" else (clamp(_speed / run_spd * 1.2, 0.7, 1.4) if want == "run" else 1.0)
	if want == "pounce":
		anim.speed_scale = float(AFK_LEAP.get(race, [0.0, LEAP_ANIM_SPEED])[1])
	elif want == "lurk_walk":
		anim.speed_scale = clampf(_speed / walk_spd, 0.6, 1.6)
	elif want.begins_with("attack") and _afk_native:
		# the whole strike within the blow's own time (wind-up and swing, ~0.7 s)
		anim.speed_scale = clampf(anim.get_animation(want).length / 0.75, 1.0, 3.0)
	if _afk_speed.has(want):
		# Ari's movement: the feet go as fast as the body (no sliding)
		anim.speed_scale = clampf(_speed / float(_afk_speed[want]), 0.6, 1.8)
	anim.advance(delta)
	_activity_pose(delta)

## Eyes only flash when a flashlight catches them - and only for a moment.
func _eyeshine(delta: float) -> void:
	glint_t -= delta
	var p: Node = mission.local_player() if mission else null
	if not dead and p and p.light_on and not p.downed and p.cam:
		var from: Vector3 = p.cam.global_position
		var to := eye()
		var d := from.distance_to(to)
		if d < 24.0 and (-p.cam.global_transform.basis.z).dot((to - from).normalized()) > 0.965:
			var q := PhysicsRayQueryParameters3D.create(from, to, Game.WORLD)
			if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
				if glint_t < -0.6:
					glint_t = 0.3
	eye_glint.visible = glint_t > 0 and not dead

# ---- rigid creatures: the game moves their pieces ----------------------------------
var _parts := {}
# ---- dying: the legs give way, the body tips over and comes to rest ON the ground ----------
var _death_t := -1.0
var _fall := Vector3.ZERO        # rotation it falls to
var _rest_y := 0.0               # body height that keeps it lying on top of the ground
var _skel: Skeleton3D
var _limp := {}                  # bone index -> target extra rotation

func _death_setup() -> void:
	_death_t = 0.0
	_springs_limp()
	if anim:
		anim.pause()
	var hov := float(R.get("hover", 0.0))
	if anim and not _afk_deaths.is_empty() and (hov <= 0.0 or (_afk_native and race in AFK_GROUNDED)):
		# Ari's own deaths: the whole body falls by itself (crouched in hiding: from the crouch;
		# the afk Levit stands on the ground already, its bob stops)
		body.position.y = 0.0
		body.rotation.z = 0.0
		var pick: String = _afk_deaths[absi(hash(String(name))) % _afk_deaths.size()]
		if lurking and anim.has_animation("death_crouch"):
			pick = "death_crouch"
		anim.speed_scale = 1.0
		anim.play(pick, 0.12)
		_afk_dying = true
		return
	# where its parts are, in body space (to lie on the ground, not in it)
	var inv := body.global_transform.affine_inverse()
	var bb := AABB()
	var first := true
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		if not mi.visible or mi == eye_glint:
			continue
		var a: AABB = (inv * mi.global_transform) * mi.get_aabb()
		bb = a if first else bb.merge(a)
		first = false
	if first:
		bb = AABB(Vector3(-0.3, 0, -0.3), Vector3(0.6, float(R["h"]), 0.6))
	var dir := absi(hash(String(name))) % 4
	if hov > 0.0 and race == "nador" and _afk_native and _rig:
		# Nádor: the head comes down upright onto the ground (the tentacles splay out: _springs_limp)
		_fall = Vector3.ZERO
		_rest_y = hov + _head_down_y() - body.position.y
	elif hov > 0.0:
		# floaters drop out of the air and land on their side
		_fall = Vector3(0, 0, 0.35 if dir % 2 == 0 else -0.35)
		_rest_y = -bb.position.y + 0.02 - 0.05
	elif race == "kolos" and _afk_native and _rig:
		_kolos_splay()
		return
	else:
		match dir:
			0: _fall = Vector3(PI / 2, 0, 0); _rest_y = bb.end.z           # on its back
			1: _fall = Vector3(-PI / 2, 0, 0); _rest_y = -bb.position.z    # face down
			2: _fall = Vector3(0, 0, PI / 2); _rest_y = -bb.position.x     # on the side
			_: _fall = Vector3(0, 0, -PI / 2); _rest_y = bb.end.x
		_rest_y = maxf(_rest_y * 0.92, 0.06)
	# limbs go slack (works for the shared bone names of the rigs)
	_skel = body.find_child("Skeleton3D", true, false)
	if _skel:
		var r := RandomNumberGenerator.new()
		r.seed = hash(String(name))
		var want := {"thigh.L": Vector3(0.5, 0, 0.1), "thigh.R": Vector3(0.3, 0, -0.15), "shin.L": Vector3(-0.9, 0, 0), "shin.R": Vector3(-0.5, 0, 0),
			"spine": Vector3(-0.35, 0, 0.1), "neck": Vector3(-0.3, 0, 0), "head": Vector3(-0.4, 0.3, 0.2),
			"upperarm.L": Vector3(0.2, 0, 1.0), "upperarm.R": Vector3(-0.3, 0, -1.1), "forearm.L": Vector3(0.6, 0, 0), "forearm.R": Vector3(0.3, 0, 0),
			"tail": Vector3(0, 0, 0.5), "jaw": Vector3(0.5, 0, 0)}
		for bn in want:
			var i := _skel.find_bone(bn)
			if i >= 0:
				var v: Vector3 = want[bn] * r.randf_range(0.7, 1.2)
				_limp[i] = [_skel.get_bone_pose_rotation(i), _skel.get_bone_pose_rotation(i) * Quaternion.from_euler(v)]

## Kolos: no toppling - the body sinks onto the ground, all its legs slide out to the sides.
var _splay_drop := 0.0
func _kolos_splay() -> void:
	_fall = Vector3.ZERO
	_skel = _rig
	var up := Vector3.UP
	var hi := _rig.find_bone("hips")
	var c: Vector3 = _rig.get_bone_global_pose(hi).origin if hi >= 0 else Vector3.ZERO
	for b in _rig.get_bone_count():
		var bn := _rig.get_bone_name(b)
		if not bn.begins_with("leg_") or not (bn.contains("_1_") or bn.contains("_2_") or bn.contains("_3_")):
			continue
		var g := _rig.get_bone_global_pose(b)
		var h := g.origin - c
		h.y = 0.0
		if h.length() < 0.01:
			continue
		# turn the leg about the axis that swings its lower end outward and up
		var axis := (-up).cross(h.normalized()).normalized()
		var ang := 0.55 if bn.contains("_1_") else (0.35 if bn.contains("_2_") else 0.2)
		var local_axis := (g.basis.inverse() * axis).normalized()
		var q0 := _rig.get_bone_pose_rotation(b)
		_limp[b] = [q0, q0 * Quaternion(local_axis, ang)]
	# the hull comes down to rest on the ground
	_splay_drop = float(R["h"]) * 0.45
	_rest_y = -_splay_drop

var _landed_dead := false
func _death_anim(delta: float) -> void:
	if _death_t < 0.0:
		_death_setup()
	_death_t += delta
	if _afk_dying:
		anim.advance(delta)
		return
	var hov := float(R.get("hover", 0.0))
	var t := _death_t
	if hov > 0.0:
		# drops like a stone, bounces once
		var k := clampf(t / 0.55, 0.0, 1.0)
		body.position.y = lerpf(0.0, _rest_y - hov, k * k) + (sin(clampf((t - 0.55) / 0.3, 0.0, 1.0) * PI) * 0.12 if t > 0.55 else 0.0)
		body.rotation.z = lerpf(0.0, _fall.z, clampf(t / 0.8, 0.0, 1.0))
		return
	if _splay_drop > 0.0:
		var ks := clampf(t / 0.9, 0.0, 1.0)
		ks = ks * ks * (3.0 - 2.0 * ks)
		body.position.y = -_splay_drop * ks
		for i in _limp:
			_skel.set_bone_pose_rotation(i, (_limp[i][0] as Quaternion).slerp(_limp[i][1], ks))
		return
	# 1) the knees go (0 - 0.3 s), 2) it topples, faster and faster (0.3 - 0.95 s),
	# 3) a small bounce as it hits the ground, then still
	var buckle := clampf(t / 0.3, 0.0, 1.0)
	var f := clampf((t - 0.25) / 0.7, 0.0, 1.0)
	var fall := f * f                         # gravity: slow start, hard landing
	var bounce := 0.0
	if t > 0.95 and t < 1.25:
		bounce = sin((t - 0.95) / 0.3 * PI) * 0.06
	body.rotation = _fall * fall + Vector3(_fall.x * 0.08 + bounce, 0, _fall.z * 0.08) * buckle * (1.0 - fall)
	body.position.y = lerpf(-float(R["h"]) * 0.12 * buckle, _rest_y, fall) + bounce * 0.5
	if _skel:
		var lk := clampf(t / 0.9, 0.0, 1.0)
		for i in _limp:
			_skel.set_bone_pose_rotation(i, (_limp[i][0] as Quaternion).slerp(_limp[i][1], lk))

func _part(n: String) -> Node3D:
	if not _parts.has(n):
		_parts[n] = body.find_child(n, true, false)
	return _parts[n]

# ---- the weapon in the hand (0.57) ------------------------------------------------------------
## The old models have their gun in the mesh. Every other model (the new *_v2 ones, made without
## weapons) gets the race's gun model on its right hand bone (a floating race: a "Weapon" piece that
## _rigid_anim moves), placed by Ari's anchor from the Dílna ("Zbraň vetřelce"):
## "agun/<model>/<weapon>" {pos, rot, scale} in the hand's frame over GUN_DEFAULT, and on top of it
## "agun/<model>/<weapon>@<clip>" for one movement (idle, walk, run, lurk, aim, attack, roar).
## A commander without its own anchor takes the plain model's (bijec_velitel_v2 -> bijec_v2).
const BAKED_GUN := ["grey", "grey_velitel", "levit", "levit_velitel", "jestetan", "jestetan_velitel", "bijec", "bijec_velitel", "myslodej"]
const FLOAT_GUN := ["levit", "levit_velitel", "myslodej"]
## The heavier GUNS look like the heavy plasma (the rest: the race's own, Campaign.RACE_WEAPON).
const HEAVY_GUNS := ["mg", "minigun", "cannon", "hminigun", "hcannon", "rocket"]
## Before any anchor: the gun's barrel (-Z) along the hand bone (+Y), a little out from the wrist.
const GUN_DEFAULT := Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0)), Vector3(0, 0.06, 0))
var hand_gun: Node3D = null       # the holder on the hand (null: the gun is part of the model)
var _hand_gun_id := ""
var _hand_gun_clip := "?"
var _gun_base := Transform3D()    # floating: turned round (_rigid_anim points the holder's +Z at the target)

## Which gun model this race shows for this gun ("" = none).
static func gun_item(race_id: String, gun_id: String) -> String:
	var w: String = Campaign.RACE_WEAPON.get(race_id, "")
	if w == "":
		return ""
	return "a_heavy" if gun_id in HEAVY_GUNS else w

## The model whose anchor counts: its own, else the commander takes the plain one's.
static func anchor_model(mname: String, w: String) -> String:
	if Game.tweaks.has("agun/%s/%s" % [mname, w]) or not mname.contains("_velitel"):
		return mname
	var plain := mname.replace("_velitel", "")
	return plain if Game.tweaks.has("agun/%s/%s" % [plain, w]) else mname

## The gun model's transform under its holder (GUN_DEFAULT): the anchor, then the movement's own.
## Shared with the Dílna, so what Ari sets there is what the game does.
static func gun_anchor(mname: String, w: String, clip := "") -> Transform3D:
	var am := anchor_model(mname, w)
	var t := Game.tweak_xform("agun/%s/%s" % [am, w])
	if clip != "":
		t = t * Game.tweak_xform("agun/%s/%s@%s" % [am, w, clip])
	return t * Game.grip_shift(w)

func _attach_gun(m: Node3D) -> void:
	var mname := String(R["model"])
	_hand_gun_id = gun_item(race, gun)
	if (mname in BAKED_GUN and not _afk_native) or _hand_gun_id == "" or not ResourceLoader.exists("res://assets/models/%s.glb" % _hand_gun_id):
		return
	if m.find_child("Weapon", true, false) != null:
		return           # (the model brings its own)
	var sk: Skeleton3D = m.find_child("Skeleton3D", true, false)
	hand_gun = Node3D.new()
	if sk and sk.find_bone(_bn("hand.R")) >= 0:
		var att := BoneAttachment3D.new()
		att.bone_name = _bn("hand.R")
		sk.add_child(att)
		att.add_child(hand_gun)
		hand_gun.transform = GUN_DEFAULT
		if _afk_native:
			_afk_hold = att
	elif race in FLOAT_GUN:
		hand_gun.name = "Weapon"     # _rigid_anim floats it beside the body and turns it to the target
		body.add_child(hand_gun)
		_gun_base = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	else:
		hand_gun.free()
		hand_gun = null
		return
	var gm := Game.model(_hand_gun_id)
	hand_gun.add_child(gm)
	gm.transform = _gun_base * gun_anchor(mname, _hand_gun_id)

## Ari's afk model holds its gun with both hands: in the right, the barrel out past the left
## (as the soldier's afk_gun_xform), set again every frame after the pose.
var _afk_hold: BoneAttachment3D = null
func _afk_gun_pose() -> void:
	if _afk_hold == null or _rig == null:
		return
	var aim = null
	if race in FLOAT_GUN and alert and is_instance_valid(target):
		aim = target.global_position + Vector3(0, 1.2, 0)
	hand_gun.global_transform = afk_hold_xform(_rig, race, global_transform.basis, body.global_transform.basis.get_scale(), aim)

## Where the gun holder sits on an afk model this frame (the game and the Dílna): in the right hand,
## the barrel out past the left - or, one hand / a floating race (Levit, its arms wide), straight
## where it faces, turned to `aim` (a point) when that is roughly ahead.
static func afk_hold_xform(rig: Skeleton3D, race_id: String, facing: Basis, sc: Vector3, aim = null) -> Transform3D:
	var ri := rig.find_bone("hand_r")
	var li := rig.find_bone("hand_l")
	var rp: Vector3 = (rig.global_transform * rig.get_bone_global_pose(ri)).origin
	var ahead := -facing.z.normalized()
	var fw := ahead
	if race_id in FLOAT_GUN:
		if aim != null:
			var to: Vector3 = aim - rp
			if to.length() > 0.5 and to.normalized().dot(fw) > 0.3:
				fw = to
	elif li >= 0:
		var lp: Vector3 = (rig.global_transform * rig.get_bone_global_pose(li)).origin
		fw = lp - rp
		if fw.length() < 0.12 or fw.dot(ahead) < 0.0:
			fw = ahead          # one hand, or the left behind: straight ahead
	fw = fw.normalized()
	var up := facing.y.normalized()
	if absf(fw.dot(up)) > 0.95:
		up = facing.z.normalized()
	return Transform3D(Basis.looking_at(fw, up).scaled(sc), rp)

## Each frame: the movement's own anchor (only when the movement changed).
func _gun_tick() -> void:
	if hand_gun == null or anim == null or hand_gun.get_child_count() == 0:
		return
	if _afk_hold:
		_afk_gun_pose.call_deferred()
	var c := String(anim.current_animation)
	if c == _hand_gun_clip:
		return
	_hand_gun_clip = c
	(hand_gun.get_child(0) as Node3D).transform = _gun_base * gun_anchor(String(R["model"]), _hand_gun_id, c)

func _rigid_anim(delta: float) -> void:
	var organ := _part("Organ")
	if organ:
		var k := 1.0 + sin(bob_t * 5.0) * 0.12
		organ.scale = Vector3(k, k, 2.0 - k)
	var robe := _part("Robe")
	if robe:
		robe.rotation.x = sin(bob_t * 0.9) * 0.04 - clampf(_speed, 0.0, 3.0) * 0.06
	var w := _part("Weapon")
	if w:
		# the levitating rifle drifts beside it; when it fights the rifle turns to the target
		var base := Vector3(-0.55 if not _afk_native else -0.75, (1.45 if _afk_native else 1.05) + sin(bob_t * 1.3) * 0.08, -0.15)
		w.position = w.position.lerp(base, delta * 4.0)
		if alert and is_instance_valid(target):
			var to: Vector3 = target.global_position + Vector3(0, 1.2, 0)
			w.look_at(to, Vector3.UP)
			w.rotate_object_local(Vector3.UP, PI)
		else:
			w.rotation = w.rotation.lerp(Vector3(0, sin(bob_t * 0.7) * 0.3, 0), delta * 2.0)
	var magma := _part("Magma")
	if magma:
		var sp := 9.0 if _charge > 0.0 else 2.2
		var k3 := 1.0 + sin(bob_t * sp) * (0.06 if _charge > 0.0 else 0.03)
		magma.scale = Vector3(k3, k3, k3)
	var body_mesh := _part("Body")
	if body_mesh and R.get("spit", "") == "acid":
		var k2 := 1.0 + sin(bob_t * 3.3) * 0.06 + sin(bob_t * 7.1) * 0.03
		body_mesh.scale = Vector3(k2, 2.0 - k2, k2)

## Where its shots come from.
func _muzzle_pos() -> Vector3:
	if hand_gun and hand_gun.get_child_count() > 0:
		var gm: Node3D = hand_gun.get_child(0)
		var mp: Variant = Game.model_point(_hand_gun_id, "Muzzle")
		if mp != null:
			return gm.global_transform * (mp as Vector3)
		var mz := float(Game.ITEMS.get(_hand_gun_id, {}).get("muzzle", 0.5))
		return gm.global_position - gm.global_transform.basis.z.normalized() * mz
	var w := _part("Weapon")
	if w:
		return w.global_position - w.global_transform.basis.z * 0.5
	return eye() + (-global_transform.basis.z) * 0.45 + Vector3(0, -0.08, 0)

# ---- senses ----------------------------------------------------------------------
func eye() -> Vector3:
	var e := float(R["eye"])
	if lurking and not R.has("hover"):
		e *= 0.72
	return global_position + Vector3(0, e, 0)

func _los(to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(eye(), to, Game.WORLD)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

## Can this alien see @a p right now? (used by the players' fear too)
func visible_to(p: Node) -> bool:
	if dead or husk:
		return false
	var head_pos: Vector3 = p.global_position + Vector3(0, 1.0 if p.crouching else 1.5, 0)
	var d := eye().distance_to(head_pos)
	var vr: float = p.visibility_range() * (1.0 + 0.3 * _late)      # (they learn where to look)
	if R.has("night_eyes") and mission.phase() != "den":
		vr = maxf(vr, 34.0)              # the Ještěřan sees in the dark
	if race in ["diskoll", "kolos", "jestetan_velitel"] and p.get("ir_on"):
		vr = maxf(vr, 42.0)              # (their sensors see the infrared illuminator like a lamp)
	if d > vr and d > 4.0:
		return false
	var fwd := -global_transform.basis.z
	if d > 4.0 and fwd.dot((head_pos - eye()).normalized()) < SIGHT_ANGLE and not alert:
		return false
	if mission.smoke_blocks(eye(), head_pos):
		# (0.57, SM-01's entry) smoke is for eyes: the machines see heat and radar through it, the
		# Ohnivec feels the ground shake, a grey's gear still picks out a man close by
		if d > float(SMOKE_SEE.get(race, 0.0)):
			return false
	return _los(head_pos)

const SMOKE_SEE := {"diskoll": 25.0, "kolos": 25.0, "ohnivec": 12.0, "grey": 8.0, "grey_velitel": 8.0}

func hear(pos: Vector3, radius: float) -> void:
	if dead or state == S.DRAG:
		return
	if mission.calm():
		radius *= 0.5
	if global_position.distance_to(pos) > radius:
		return
	if radius >= 25.0 and multiplayer.is_server() and global_position.distance_to(pos) < 130.0:
		AT.heard_shot(self, pos)
		# a gunshot: the muzzle flash shows exactly where he is (a silencer keeps it small)
		for p in mission.players():
			if not p.dead and p.global_position.distance_to(pos) < 2.0 and _los(pos + Vector3(0, 1.2, 0)):
				_know(p, 6.0)
	if state == S.COMBAT:
		last_seen = pos
		return
	alert = true
	last_seen = pos
	state = S.INVESTIGATE
	lurking = false
	# do not walk straight at the sound: stop short and look from cover
	_go(_snap(pos + (global_position - pos).normalized() * rng.randf_range(4.0, 9.0)))

## The director hides this one somewhere particular (the barn after the radio lure).
func lurk_at(pos: Vector3) -> void:
	if dead or state == S.COMBAT or state == S.DRAG:
		return
	state = S.LURK
	wait = 120.0
	lurking = false
	_go(_snap(pos + Vector3(1.5, 0, 1.0)))

## The director sends this one to creep up on a mercenary.
func stalk(p: Node) -> void:
	if dead or state == S.COMBAT or state == S.DRAG:
		return
	target = p
	last_seen = p.global_position
	state = S.STALK
	lurking = false
	var away: Vector3 = global_position - p.global_position
	away.y = 0
	_go(_snap(p.global_position + away.normalized() * rng.randf_range(12.0, 17.0)))

## Damage after armour and the race's weaknesses (the mission says what kind of hit it is).
## The Levit's anti-gravity organ (the soft lower half that holds it up): a hit there tears it.
func weak_spot(at: Vector3) -> bool:
	if R.has("module"):
		# the Bijec officer's command module on the left forearm
		if not module_ok or _rig == null or _rig.find_bone("forearm.L") < 0:
			return false
		var bi := _rig.find_bone("forearm.L")
		var bp: Vector3 = (_rig.global_transform * _rig.get_bone_global_pose(bi)).origin
		var tip: Vector3 = (_rig.global_transform * _rig.get_bone_global_pose(_rig.find_bone("hand.L"))).origin if _rig.find_bone("hand.L") >= 0 else bp
		return at.distance_to(bp.lerp(tip, 0.45)) < 0.3 * float(R.get("scale", 1.0))
	var lp := to_local(at)
	var sc := float(R.get("scale", 1.0))
	# 0.57: the autopsies' weak points - they work from the first night, research or not
	if tac == "grey":
		# the neck: the suit's nerve interface sits there (Pitva šediváka)
		var ny := _bone_y("neck", 0.95 * sc)
		var hy := _bone_y("head", 1.06 * sc)
		return at.y > ny - 0.05 and at.y < hy + 0.03
	if race == "lihnoun":
		# the brood sacs on its back (Pitva Líhavce): a shot from behind, into the upper body
		return lp.z > 0.05 and lp.y > float(R["h"]) * 0.5 * sc
	if race == "ohar":
		# the soft belly and the braced joints of the legs (Pitva Ohaře)
		return lp.y < 0.36 * sc
	if race == "diskoll":
		# the radio mast at the back of the dome (Rozbor Diskollu)
		return antenna_ok and lp.y > 1.5 and lp.x > -0.05 and lp.z > -0.15
	if race == "kolos":
		# the leg joints (low) and the red sensor eye under the head (Rozbor Kolosu)
		return lp.y < 1.25 or lp.distance_to(Vector3(0, 2.0, -0.8)) < 0.5
	if tac != "levit" or not R.has("hover"):
		return false
	return lp.y < (float(R["hover"]) + 0.15) * sc

## Height of a bone of the rig right now (world), or @a def above the feet.
func _bone_y(bn: String, def: float) -> float:
	bn = _bn(bn)
	if _rig and _rig.find_bone(bn) >= 0:
		return (_rig.global_transform * _rig.get_bone_global_pose(_rig.find_bone(bn))).origin.y
	return global_position.y + def

## Host: a weak point was hit (the shooter's client found it, @a at is where).
var antenna_ok := true
var _leg_dmg := 0.0
var legs_hurt := false
var _sensor_hits := 0
func weak_hit(at: Vector3) -> void:
	if dead:
		return
	if R.has("module"):
		module_hit()
		return
	if tac == "grey" and not suit_down and not husk:
		_tlog("neck hit: suit fails")
		_suit_fail.rpc()
	elif race == "diskoll" and antenna_ok:
		antenna_ok = false
		_tlog("antenna shot off")
		_antenna_fx.rpc()
		for a in mission.aliens():
			if a != self and not a.dead and a.tac == "grey" and a.global_position.distance_to(global_position) < 80.0:
				a._disarray_t = maxf(a._disarray_t, 10.0)
	elif race == "kolos":
		if to_local(at).y < 1.25:
			_leg_dmg += 1.0
			if _leg_dmg >= 4.0 and not legs_hurt:
				legs_hurt = true
				walk_spd *= 0.6
				run_spd *= 0.6
				_tlog("legs hurt")
				_sparks_fx.rpc(Vector3(0, 0.7, 0), Color(1.0, 0.75, 0.3))
		else:
			_sensor_hits += 1
			if _sensor_hits == 2:
				_tlog("sensor out")
				_sparks_fx.rpc(Vector3(0, 2.0, -0.8), Color(1.0, 0.3, 0.15))

@rpc("authority", "call_local", "reliable")
func _antenna_fx() -> void:
	antenna_ok = false
	_sparks_fx(Vector3(0.27, float(R.get("hover", 0.0)) + 0.6, 0.13), Color(1.0, 0.3, 0.15))

## A burst of sparks and a zap at @a lp (local to the alien).
@rpc("authority", "call_local", "reliable")
func _sparks_fx(lp: Vector3, col: Color) -> void:
	Game.play_at(mission, "zap", to_global(lp), 0)
	var sp := CPUParticles3D.new()
	sp.one_shot = true
	sp.amount = 30
	sp.lifetime = 0.6
	sp.explosiveness = 0.9
	sp.spread = 80.0
	sp.initial_velocity_min = 1.5
	sp.initial_velocity_max = 3.5
	sp.gravity = Vector3(0, -6, 0)
	var qm := QuadMesh.new()
	qm.size = Vector2(0.03, 0.03)
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_color = col
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.material = mm
	sp.mesh = qm
	add_child(sp)
	sp.position = lp
	sp.emitting = true
	get_tree().create_timer(1.5).timeout.connect(sp.queue_free)

func taken(dmg: float) -> float:
	var kind: String = mission.hit_kind if mission else ""
	var w: Dictionary = R.get("weak", {})
	var k := float(w.get(kind, 1.0))
	# 0.57: no damage bonus for autopsies any more (Ari) - what they teach is in the encyclopedia
	if kind == "explosion" and k > 1.0:
		return dmg * k       # armour does not stop a blast from tearing it apart
	var arm := float(R["armor"])
	if kind == "slug":
		arm = lerpf(arm, 1.0, 0.3)    # a solid slug carries through more of the armour
	if R.has("joints") and kind in ["laser", "plasma"]:
		arm = lerpf(arm, 1.0, 0.5)    # the beam finds the joints between the plates (Pitva Bijce)
	return dmg * (lerpf(arm, 1.0, 0.6) if armor_broken else arm) * k

func damage(dmg: float, from: Vector3, by: Node) -> void:
	if dead:
		return
	# from the dark, unseen: an ambush hurts twice as much
	if state != S.COMBAT and state != S.DRAG and by and by.has_method("is_player") and float(sus.get(String(by.name), 0.0)) < 1.0:
		dmg *= 2.0
		_ambush_note.rpc_id(by.get_multiplayer_authority(), String(by.name))
	# the Nádor: once down, only a blast tears it apart for good - bullets just make the mass twitch
	if husk and R.has("regen") and mission.hit_kind != "explosion":
		regen_t += 0.3
		return
	var got := taken(dmg)
	hp -= got
	alert = true
	_hit_t = mission.t
	_decloak_t = maxf(_decloak_t, 1.2)
	if race == "myslodej" and got >= 25.0 and hp > 0.0:
		_psi_break()
	var shooter_known := by != null and by.has_method("is_player")
	if shooter_known:
		# it knows where that came from - and so do the others nearby
		_hurt_by[String(by.name)] = mission.t
		_know(by, 15.0)
		target = by
		_warn_squad(by, 40.0)
	if dragging:
		_release()
	if hp <= 0 and R.has("regen") and not husk and mission.hit_kind != "explosion":
		# it falls - but it is not dead yet
		husk = true
		hp = 35.0
		regen_t = rng.randf_range(18.0, 26.0)
		lurking = false
		_husk_fx.rpc(true)
		return
	if hp <= 0:
		_die.rpc()
		_death_pool.rpc()
		_drop_gun()
		_drop_pack()
		AT.comrade_down(self, by)
		if by and by.has_method("is_player"):
			_credit.rpc_id(by.get_multiplayer_authority(), by.name)
			_warn_squad(by, 30.0)     # one of theirs falls: the rest come for the killer
			if (race.ends_with("_velitel") or race == "myslodej") and not by.display_name in mission.officer_killers:
				mission.officer_killers.append(by.display_name)
		return
	# hurt: break contact at once and come back from somewhere else
	if hp < float(R["hp"]) * 0.45:
		bleeding = true
		AT.wounded(self)
	# a Šedivák's suit is what makes him fast: hit him hard and it fails (sparks, he slows down, aims worse)
	if tac == "grey" and not suit_down and hp < float(R["hp"]) * 0.4:
		_suit_fail.rpc()
	# the Mírotvůrce: badly hurt, it pulls back to heal and comes back
	if R.has("mend") and not _mending and _mend_cd <= 0.0 and hp < float(R["hp"]) * 0.4:
		_mending = true
		_mend_cd = 25.0
		_tlog("mend: pulls back")
	if R.has("teleport") and hp > 0.0 and _teleport_away(by.global_position if shooter_known else from):
		return
	# the Bijec's synthetic armour: hit hard enough and its systems fail (sparks, it stops shrugging off bullets)
	if R.has("armor_break") and not armor_broken and hp < float(R["hp"]) * float(R["armor_break"]):
		_armor_break.rpc()
	if not R.has("no_pain"):
		_flinch.rpc(from)       # (a Bijec does not even flinch)
		_hurt_voice.rpc()
	last_seen = by.global_position if shooter_known else from
	_enter_combat(null)
	if tac == "brute":
		return               # pain only makes it angrier
	if tac == "levit" and _levit_hop(last_seen, true):
		phase = "move"
		return
	_relocate(last_seen)
	phase = "move"

## Stun damage (baton): when it outweighs the remaining health, the alien
## collapses unconscious and can be taken alive.
## How a race takes the baton's shock (0.57, ST-01's entry): scales, chitin and synthetic armour
## keep the current out, the Nádor has no nerves to speak of; a grey's suit soaks some of it.
const STUN_K := {"grey": 0.6, "grey_velitel": 0.6, "levit": 0.7, "levit_velitel": 0.6, "jestetan": 0.4, "jestetan_velitel": 0.35,
	"lihnoun": 0.3, "bijec": 0.35, "bijec_velitel": 0.3, "nador": 0.0, "ohnivec": 0.2}
func stun(amount: float, from: Vector3, by: Node) -> void:
	if dead:
		return
	var sk := float(STUN_K.get(race, 1.0))
	if tac == "grey" and suit_down:
		sk = 1.2              # the suit is dead: nothing between the prongs and the nerves
	elif armor_broken:
		sk = minf(1.0, sk * 2.0)
	amount *= sk
	if amount <= 0.0:
		alert = true
		return
	stun_dmg += amount
	alert = true
	_stagger = 1.1           # the shock rattles it: a moment without shooting or moving
	if by and by.has_method("is_player") and stun_dmg < hp:
		_stun_note.rpc_id(by.get_multiplayer_authority(), by.name, int(100.0 * stun_dmg / maxf(hp, 1.0)))
	if stun_dmg >= hp:
		if dragging:
			_release()
		_knocked_out.rpc()
		if by and by.has_method("is_player"):
			_credit_capture.rpc_id(by.get_multiplayer_authority(), by.name)
		return
	last_seen = from
	_enter_combat(null)

var _stagger := 0.0
@rpc("authority", "call_local", "reliable")
func _stun_note(player_name: String, pct: int) -> void:
	var p: Node = mission.actors.get_node_or_null(player_name)
	if p and p.is_multiplayer_authority():
		pass

@rpc("authority", "call_local", "reliable")
func _knocked_out() -> void:
	dead = true
	captured = true
	lurking = false
	collision_layer = 0
	Game.play_at(mission, "zap", global_position, -2)

@rpc("authority", "call_local", "reliable")
func _credit_capture(player_name: String) -> void:
	var p: Node = mission.actors.get_node_or_null(player_name)
	if p and p.is_multiplayer_authority():
		p.captures += 1
		mission.hud.message("Vetřelec omráčen - zajat živý.", 2.5)

## Host: now and then a dead alien carries a pack (material, a piece of technology).
const PACK_FINDS := [["kus slitiny", 60, 110], ["cizí nástroje", 80, 140], ["krystal Moskovia", 120, 200], ["neznámé zařízení", 150, 260], ["mapové fólie", 90, 160]]
func _drop_pack() -> void:
	if not multiplayer.is_server() or R.has("hover") or race in ["mozek", "pylon", "zombie", "lihnoun", "ohar"]:
		return
	if randf() > 0.3:
		return
	var f: Array = PACK_FINDS[randi() % PACK_FINDS.size()]
	mission.drop_item({"id": "a_pack", "what": f[0], "value": randi_range(int(f[1]), int(f[2]))}, _ground_below(global_position - global_transform.basis.x * 0.6))

## Host: the dead alien's gun lies next to it - anyone can pick it up (E).
func _drop_gun() -> void:
	var w: String = Campaign.RACE_WEAPON.get(race, "")
	if w == "" or not Game.ITEMS.has(w) or not multiplayer.is_server():
		return
	var r: Dictionary = Game.ITEMS[w]
	var cells := randi_range(1, int(r["cells"]))
	mission.drop_item({"id": w, "loaded": randi_range(int(r["cap"]) / 3, int(r["cap"])), "cells": cells}, _ground_below(global_position + global_transform.basis.x * 0.6))

## Where a thing let go of here comes to rest (shot out of the air: on the ground or a roof below).
func _ground_below(p: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.5, 0), p + Vector3(0, -60.0, 0), Game.WORLD)
	q.exclude = [get_rid()]
	var h := get_world_3d().direct_space_state.intersect_ray(q)
	return (h.position + Vector3(0, 0.05, 0)) if h else p

@rpc("authority", "call_local", "reliable")
func _ambush_note(player_name: String) -> void:
	var p: Node = mission.actors.get_node_or_null(player_name)
	if p and p.is_multiplayer_authority():
		pass

## Their commander falls: the ones around him lose their heads for a while (worse aim, no rally).
var _disarray_t := 0.0
@rpc("authority", "call_local", "reliable")
func _die() -> void:
	if R.has("psi") and multiplayer.is_server():
		for a in mission.aliens():
			if a != self and not a.dead and a.global_position.distance_to(global_position) < 40.0:
				a._disarray_t = 14.0
				a._rally_t = 0.0
	dead = true
	lurking = false
	collision_layer = 0
	if hand_gun:
		hand_gun.visible = false      # (it falls from the hand: _drop_gun lays the real one down)
	# each race's own death when its recording is there (<race>_death), else the shared one
	var own := "%s_death" % race.trim_suffix("_velitel")
	Game.play_at(mission, own if ResourceLoader.exists("res://assets/sounds/%s.wav" % own) else "death", global_position, -4)

## Hit: a short cry by race - [sound, dB, pitch, length in s, from where in the sound].
## Stand-ins cut from the sounds we have, until each race has its own <race>_hurt.
const HURT := {
	"grey": ["alien", -8.0, 1.35, 0.5, 0.0], "grey_velitel": ["alien", -7.0, 1.25, 0.55, 0.0],
	"jestetan": ["hiss", -3.0, 0.8, 0.6, 0.2], "jestetan_velitel": ["hiss", -2.0, 0.75, 0.6, 0.2],
	"bijec": ["growl", -1.0, 0.7, 0.7, 0.0],
	"levit": ["groan", -6.0, 1.15, 0.6, 0.0], "levit_velitel": ["groan", -5.0, 1.0, 0.7, 0.0],
	"myslodej": ["whisper", -5.0, 1.3, 0.6, 0.0],
	"nador": ["hiss", -6.0, 1.35, 0.45, 0.0], "ohnivec": ["fire_ignite", -8.0, 1.4, 0.6, 0.0],
	"lihnoun": ["hiss", -3.0, 1.25, 0.5, 0.0], "zombie": ["zombie_groan", -6.0, 1.15, 0.7, 0.0],
	"ohar": ["growl", -3.0, 1.3, 0.55, 0.3],
}
var _hurt_cd := 0.0
@rpc("authority", "call_local", "unreliable")
func _hurt_voice() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _hurt_cd or mission == null or dead:
		return
	_hurt_cd = now + randf_range(0.9, 1.6)
	var own := "%s_hurt" % race.trim_suffix("_velitel")
	if ResourceLoader.exists("res://assets/sounds/%s.wav" % own):
		Game.play_at(mission, own, global_position + Vector3.UP * 1.2, -3.0, randf_range(0.94, 1.06))
		return
	if not HURT.has(race):
		return
	var h: Array = HURT[race]
	Game.play_cut(mission, h[0], global_position + Vector3.UP * 1.2, h[1], h[2] * randf_range(0.94, 1.06), h[3], h[4])

## Footsteps by race: [sound ("surface" = the ground under it, as a soldier's), dB, metres per step, pitch].
## The big ones thud, the small greys pad on alien soles, the hound and the infected scuff the real ground.
## Hovering, flying and climbing races and the machines (Kolos walks almost without a sound) have none.
const STEPS := {
	"grey": ["step_alien", -17.0, 0.55, 1.15], "grey_velitel": ["step_alien", -16.0, 0.55, 1.1],
	"jestetan": ["step_heavy", -7.0, 1.0, 0.95], "jestetan_velitel": ["step_heavy", -6.0, 1.0, 0.9],
	"bijec": ["step_heavy", -5.0, 1.1, 0.85], "bijec_velitel": ["step_heavy", -4.0, 1.1, 0.8],
	"lihnoun": ["step_alien", -15.0, 0.8, 1.3], "zombie": ["surface", -13.0, 0.55, 0.85],
	"ohar": ["surface", -15.0, 0.75, 1.3],
}
var _step_prev := Vector3.INF
var _step_d := 0.0
func _footsteps(_delta: float) -> void:
	if not STEPS.has(race) or mission == null:
		return
	var pos := global_position
	var was := _step_prev
	_step_prev = pos
	if dead or husk or flying or airborne or leaping or was == Vector3.INF:
		_step_d = 0.0
		return
	var moved := Vector2(pos.x - was.x, pos.z - was.z).length()
	if moved > 2.0 or absf(pos.y - was.y) > 0.6:
		return          # a jump, a teleport, a pounce through the air: no steps
	_step_d += moved
	var st: Array = STEPS[race]
	var stride: float = st[2] * float(R.get("scale", 1.0))
	if _step_d < stride:
		return
	_step_d = fmod(_step_d, stride)
	var me: Node3D = mission.local_player()
	if me == null or me.global_position.distance_to(pos) > 40.0:
		return
	var sname: String = st[0]
	if sname == "surface":
		sname = "step_%s%d" % [Game.surface_at(mission, pos, mission.map), randi() % 4]
	elif sname == "step_alien":
		sname = "step_alien%d" % (randi() % 4)
	var db: float = st[1] + (-8.0 if cloak else 0.0) + (-5.0 if lurking and state == S.LURK else 0.0)
	if mission.has_method("alien_db"):
		db += mission.alien_db()      # rain covers them
	Game.play_at(mission, sname, pos, db, st[3] * randf_range(0.93, 1.07))

## It has seen you: a voice by race (greys chitter, the big ones roar, the rest hiss).
var _voice_cd := 0.0
@rpc("authority", "call_local", "unreliable")
func _alert_voice() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _voice_cd or mission == null:
		return
	_voice_cd = now + 8.0
	var base := race.trim_suffix("_velitel")
	var v := ""
	match base:
		"grey", "levit", "myslodej": v = "alien"
		"bijec", "jestetan": v = "roar" if randf() < 0.5 else "hiss"
		"lihnoun", "nador": v = "hiss"
	if v != "":
		Game.play_at(mission, v, global_position + Vector3.UP, -4)

@rpc("authority", "call_local", "reliable")
func _death_pool() -> void:
	_bleed(0.9)
	_bleed(0.5)

@rpc("authority", "call_local", "reliable")
func _credit(player_name: String) -> void:
	var p: Node = mission.actors.get_node_or_null(player_name)
	if p and p.is_multiplayer_authority():
		p.kills += 1
		mission.hud.message("Zásah. Přestal se hýbat.", 2.5)

# ---- brain (host) ------------------------------------------------------------------
func _go(p: Vector3) -> void:
	if activity != 0 and p.distance_to(_act_spot) > 1.5:
		if Game.autotest() != "": print("[ACT] %s leaves %s (state %d)" % [name, ACTS[activity], state])
		activity = 0         # off somewhere else: the job is left
	if tac == "levit" and not flying and not dead and multiplayer.is_server() \
			and (airborne or (state == S.COMBAT and global_position.distance_to(p) > 7.0)):
		if _jet_to(p):      # in a fight it does not walk: it flies (where the air is open)
			return
		airborne = false    # no way through the air from here: down, and on foot
	goal = p
	agent.target_position = p

func _snap(p: Vector3) -> Vector3:
	var nm := get_world_3d().navigation_map
	var c := NavigationServer3D.map_get_closest_point(nm, p)
	if c == Vector3.ZERO and p.length() > 2.0:
		return p          # (the paths are not ready, or being rebuilt: (0,0,0) is no place to go - a Levit flew off to the corner)
	return c

## Stealth: an alien that is not yet fighting does not spot you at once. While it can see
## you, suspicion grows - fast when you are close, lit, standing or running; slowly when
## you crouch or crawl in the dark and keep still. Half full: it turns and comes to look.
## Full: it has you. Hidden again, it fades.
var sus := {}          # player node name -> 0..1
var _think_dt := 0.016

func _sus_rate(p: Node) -> float:
	if mission.landing_safe(p):
		return 0.0                                   # the first moments by the ship: they have not noticed the landing yet
	var head_pos: Vector3 = p.global_position + Vector3(0, 1.0 if p.crouching else 1.5, 0)
	var d := eye().distance_to(head_pos)
	if d < 3.5:
		return 99.0                                   # right in front of it
	var vr: float = maxf(4.0, p.visibility_range())
	var near := clampf(1.0 - d / vr, 0.0, 1.0)        # 1 = close, 0 = at the edge of sight
	var spd := Vector2(p.velocity.x, p.velocity.z).length()
	var move := 0.35 if spd < 0.4 else (1.0 if spd < 4.5 else 1.9)
	var rate := (0.25 + near * 2.4) * move
	if p.light_on:
		rate *= 2.2
	if Game.veteran():
		rate *= 1.35
	elif Game.easy():
		rate *= 0.7
	if mission.solo():
		rate *= 0.8                                  # one man alone: a moment longer to slip away
	if alert:
		rate *= 1.6                                  # already on edge
	return rate

func _find_target() -> Node:
	var best: Node = null
	var bd := 1e9
	var aware := state == S.COMBAT or state == S.DRAG
	for p in mission.players():
		if p.dead or p.downed or p.has_meta("ghost"):
			continue
		var seen_now := visible_to(p) or _sees_known(p)
		if not aware:
			var k := String(p.name)
			var v := float(sus.get(k, 0.0))
			if _knows(p):
				v = 1.0
			if seen_now:
				v = minf(1.0, v + _sus_rate(p) * _think_dt)
			else:
				v = maxf(0.0, v - 0.12 * _think_dt)
			sus[k] = v
			if seen_now and v >= 0.5 and v < 1.0 and state != S.INVESTIGATE:
				# something is there: go and look (but not shoot yet)
				alert = true
				last_seen = p.global_position
				state = S.INVESTIGATE
				lurking = false
				_go(_snap(p.global_position + (global_position - p.global_position).normalized() * 3.0))
			if v < 1.0:
				continue
		if seen_now:
			AT.saw(self, p)
			var score := global_position.distance_to(p.global_position) + AT.target_bias(self, p)
			if p == nemesis:
				score -= 25.0             # him first
			# a lone mercenary is the preferred prey
			for o in mission.players():
				if o != p and not o.downed and o.global_position.distance_to(p.global_position) < 8.0:
					score += 6.0
			if score < bd:
				bd = score
				best = p
	return best

func _enter_combat(seen: Node) -> void:
	if state != S.COMBAT and seen and not R.get("dumb", false):
		_call_squad(seen)
	if state != S.COMBAT:
		state = S.COMBAT
		phase = "shoot" if seen else "hide"
		_alert_voice.rpc()
		shots_left = _shots() if R.has("shots") else 1
		react = rng.randf_range(0.9, 1.6) * (0.65 if Game.veteran() else (1.4 if Game.easy() else 1.0)) * (0.7 if _rally_t > 0 else 1.0) * _react_k   # the moment of surprise
		hide_t = rng.randf_range(2.0, 4.0)
	alert = true
	lurking = false
	unseen_t = 0.0

var regen_t := 0.0
var _touch_t := 0.0
@rpc("authority", "call_local", "reliable")
func _husk_fx(down: bool) -> void:
	Game.play_at(mission, "burst" if down else "groan", global_position, -4)
	if down:
		_springs_limp()
	else:
		_springs_firm()
	if not down and mission.local_player() and mission.local_player().global_position.distance_to(global_position) < 25.0:
		pass

func _think(delta: float) -> void:
	_think_dt = delta
	AT.tick(self, delta)
	if R.has("bite"):
		_bite_tick(delta)
	if R.has("mend"):
		_mend_tick(delta)
	if tac == "levit" and not R.has("frenzy"):
		_frenzy_check(delta)
	if husk:
		velocity.x = 0; velocity.z = 0
		regen_t -= delta
		if regen_t <= 0:
			husk = false
			hp = float(R["hp"]) * 0.6
			_husk_fx.rpc(false)
		return
	if R.has("touch"):
		# glowing rock: standing next to it burns
		_touch_t -= delta
		if _touch_t <= 0:
			_touch_t = 1.0
			for p in mission.players():
				if not p.dead and p.global_position.distance_to(global_position) < 1.7:
					p.hurt.rpc_id(p.get_multiplayer_authority(), float(R["touch"]) * (1.3 if Game.veteran() else 1.0), global_position, false, "heat")
	if R.has("burn"):
		_burn_tick(delta)
	if R.has("heal") and hp < float(R["hp"]) and mission.t - _hit_t > 3.0:
		# Ohnivec: the molten core seals its wounds
		hp = minf(float(R["hp"]), hp + float(R["heal"]) * delta)
	_disarray_t = maxf(0.0, _disarray_t - delta)
	if R.has("light_shy"):
		_light_tick(delta)
	if R.has("psi") and not (tac == "grey" and suit_down):     # (a commander's broken suit takes the circlet with it)
		_psi(delta)
	if state == S.DRAG:
		_drag(delta)
		return
	if nemesis and is_instance_valid(nemesis) and not nemesis.dead:
		_nem_t -= delta
		if _nem_t <= 0.0:
			_nem_t = 15.0
			_know(nemesis, 6.0)
			if state != S.COMBAT and state != S.DRAG:
				stalk(nemesis)
	var seen := _find_target()
	if seen:
		_seen_t = mission.t
		target = seen
		last_seen = seen.global_position
		unseen_t = 0.0
		if state != S.COMBAT:
			_enter_combat(seen)
		elif phase == "move" and tac in ["soldier", "hunter", "grey"] and react < -0.5 and rng.randf() < _press * delta * 3.0:
			# on the move and there he is: stop and fire (more often the later it gets)
			phase = "shoot"
			shots_left = _shots()
			react = rng.randf_range(0.25, 0.5) * _react_k
		elif phase == "flank" or phase == "hide":
			# came round the corner and there he is
			if phase == "hide" and hide_t > 1.0:
				pass
			else:
				phase = "shoot"
				shots_left = _shots()
				react = rng.randf_range(0.35, 0.7)
	elif (state != S.COMBAT or phase == "hide" or phase == "flank") and _try_drag():
		return
	match state:
		S.LURK:
			wait -= delta
			if _arrived() and activity != 0:
				# at its job: it stays there, turned to what it is doing, until disturbed
				lurking = false
				velocity.x = 0; velocity.z = 0
				_face(_act_face, delta * 0.5)
				wait = maxf(wait, 5.0)
			elif _arrived():
				lurking = true
				velocity.x = 0; velocity.z = 0
				if R.has("traps") and not mission.calm():
					_maybe_trap(delta * 0.1)
				if rng.randf() < delta * 0.15:
					rotation.y += rng.randf_range(-1.2, 1.2)
				if wait <= 0:
					_go_lurk(true)
			else:
				lurking = false
				_walk(walk_spd, delta)
		S.INVESTIGATE:
			_walk(walk_spd * 1.2, delta)
			if _arrived():
				state = S.SEARCH
				lurking = true
				search_t = rng.randf_range(6.0, 12.0)
				AT.begin_search(self, search_t)
		S.STALK:
			_walk(walk_spd * 1.3, delta)
			if _arrived():
				# close enough - wait in the dark, then come from the side
				_enter_combat(null)
				phase = "hide"
				hide_t = rng.randf_range(4.0, 9.0)
				lurking = true
		S.SEARCH:
			if AT.search_tick(self, delta):
				return
			search_t -= delta
			velocity.x = 0; velocity.z = 0
			rotation.y += delta * 0.6
			if search_t <= 0:
				alert = false
				_go_lurk(true)
		S.COMBAT:
			_combat(delta, seen)

## Spotted someone: the others nearby close in from the sides (the officer's voice carries further).
func _call_squad(seen: Node) -> void:
	var reach := 35.0 if R.has("psi") else 22.0
	for a in mission.aliens():
		if a == self or a.dead or a.husk or a.state == S.COMBAT or a.state == S.DRAG:
			continue
		if a.global_position.distance_to(global_position) < reach and not a.R.get("dumb", false):
			a._know(seen, 8.0)
			a.stalk(seen)
	# an officer also lends its own: sharper eyes, faster hands for a while
	if R.has("psi"):
		for a in mission.aliens():
			if not a.dead and a.global_position.distance_to(global_position) < 25.0:
				a._rally_t = 15.0

var _rally_t := 0.0
## Bullets cracking past: anything standing in the open dives for cover.
func suppressed(from: Vector3) -> void:
	if dead or husk or R.get("dumb", false) or R.has("melee"):
		return
	alert = true
	last_seen = from
	if state != S.COMBAT:
		_enter_combat(null)
	if phase == "shoot" and react > -0.2 and rng.randf() < (0.75 if Game.veteran() else 0.55):
		_relocate(from)
		phase = "move"

func _combat(delta: float, seen: Node) -> void:
	_rally_t -= delta
	react -= delta
	shoot_cd -= delta
	_burst_snd -= delta
	_nade_cd -= delta
	_rocket_cd -= delta
	_grab_cd -= delta
	if R.has("warcry"):
		_warcry_tick(delta)
	unseen_t += delta if seen == null else 0.0
	if seen:
		_know(seen, 4.0)
	if unseen_t > 45.0:
		state = S.SEARCH
		search_t = rng.randf_range(8.0, 14.0)
		AT.begin_search(self, search_t)
		return
	if tac == "brute":
		_brute(delta, seen)
		return
	if phase != "shoot":
		_bail_done = false
	match phase:
		"shoot":
			lurking = false
			velocity.x = 0; velocity.z = 0
			_face(last_seen, delta)
			if seen == null:
				if react < -1.5:
					_after_burst()
				return
			var dist := global_position.distance_to(seen.global_position)
			if tac != "brute" and react < 0.3 and ((dist < 9.0 and (_habit(seen, "shotgun") or _habit(seen, "magnum"))) or (dist < 6.0 and _habit(seen, "stun_baton"))):
				# it knows what he carries up close: no closer
				_keep_away(seen.global_position)
				phase = "move"
				return
			if tac == "psi" and dist < 13.0 and react < 0.3:
				# a Mysloděj does not trade shots up close: it slips away
				_keep_away(seen.global_position)
				phase = "move"
				return
			if react <= 0 and shoot_cd <= 0:
				if tac == "grey" and not _bail_done:
					_bail_done = true
					if not _back_to_me(seen) and rng.randf() < 0.6 and dist > 6.0:
						# he is looking this way: not now - round behind him
						_flank_rear(seen)
						phase = "flank"
						return
				if has_nades and _nade_cd <= 0 and dist > 7.0 and dist < 26.0 and rng.randf() < (0.75 if _habit(seen, "pancir") else 0.4):
					_throw_nade(seen.global_position)
				else:
					_fire(seen)
				mission.combat_t = mission.t
				shots_left -= 1
				shoot_cd = rng.randf_range(0.7, 1.1) * float(_g("rate", 1.0)) * (0.6 if _frenzy else 1.0)
				if shots_left <= 0:
					_after_burst()
		"move":
			lurking = false
			_walk(run_spd, delta)
			if _arrived() and seen and tac in ["soldier", "hunter", "grey"] and hp > float(R["hp"]) * 0.45:
				phase = "shoot"           # (a firing position: straight to it)
				shots_left = _shots()
				react = rng.randf_range(0.2, 0.45) * _react_k
			elif _arrived() and AT.rehide(self):
				pass                      # (in the open for one of them: on to real cover first)
			elif _arrived():
				phase = "hide"
				hide_t = rng.randf_range(2.5, 6.0) * float(R["hide"]) * (1.0 - 0.45 * _late)
				if tac == "levit":
					hide_t = rng.randf_range(0.6, 1.6)
					if _frenzy:
						hide_t *= 0.4      # mad with rage: no waiting
					if _mending:
						hide_t = 12.0      # out of sight until the wounds close
				if traps_left > 0 or mines_left > 0:
					_maybe_trap(0.5)
		"hide":
			lurking = true
			velocity.x = 0; velocity.z = 0
			hide_t -= delta
			if tac == "grey" and is_instance_valid(target) and not target.dead and _knows(target) and _back_to_me(target) \
					and global_position.distance_to(target.global_position) < 40.0 and _los(target.global_position + Vector3(0, 1.2, 0)):
				# peeking out: his back is turned - now
				phase = "shoot"
				shots_left = _shots() + 1
				react = rng.randf_range(0.15, 0.35)
				return
			if _mending and hide_t <= 0 and mission.t - _hit_t > 2.0:
				hide_t = 1.0
			if hide_t <= 0:
				_next_move()
		"grab":
			_grab(delta)
		"duck":
			lurking = true
			velocity.x = 0; velocity.z = 0
			_duck_t -= delta
			if _duck_t <= 0.0:
				if seen:
					phase = "shoot"
					shots_left = _shots()
					react = rng.randf_range(0.15, 0.4) * _react_k
				else:
					_next_move()
		"flank":
			lurking = false
			_walk(walk_spd * 1.4 if tac != "grey" else run_spd * 0.85, delta)
			if _arrived() and AT.rehide(self):
				pass
			elif _arrived():
				phase = "hide"
				hide_t = rng.randf_range(3.0, 7.0) * float(R["hide"])
				if tac == "levit":
					hide_t = rng.randf_range(0.8, 2.0)

## Ještěřan: too close and the jaws (and the claws) come down on you.
var _bite_cd := 0.0
func _bite_tick(delta: float) -> void:
	_bite_cd -= delta
	if _bite_cd > 0.0 or state != S.COMBAT or not is_instance_valid(target) or not target.has_method("is_player"):
		return
	if target.dead or target.downed or global_position.distance_to(target.global_position) > 2.3:
		return
	_bite_cd = rng.randf_range(1.4, 2.0)
	var b: Array = R["bite"]
	_face(target.global_position, 10.0)
	Game.play_at(mission, "roar", global_position + Vector3.UP * 1.8, 0)
	target.hurt.rpc_id(target.get_multiplayer_authority(), rng.randf_range(float(b[0]), float(b[1])) * (1.3 if Game.veteran() else 1.0), global_position, false, "blow")
	mission.combat_t = mission.t

## Ohnivec: feels the footsteps through the ground (it always knows where you are, close by), melts
## whatever stands in its way, and - near enough - glows up and lets go a beam of heat.
var _burn_t := 0.0
var _sense_t := 0.0
var _charge := 0.0
var _heat_cd := 4.0
const HEAT_CHARGE := 2.2
func _burn_tick(delta: float) -> void:
	_sense_t -= delta
	if _sense_t <= 0.0:
		_sense_t = 2.0
		for p in mission.players():
			if not p.dead and p.global_position.distance_to(global_position) < 40.0:
				_know(p, 4.0)
	_burn_t -= delta
	if _burn_t <= 0.0:
		_burn_t = 0.5
		# what is right in front of it melts
		var fwd := -global_transform.basis.z
		var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.45, 0), global_position + Vector3(0, 0.45, 0) + fwd * 1.6, Game.WORLD | Game.GLASS)
		q.exclude = [get_rid()]
		var h := get_world_3d().direct_space_state.intersect_ray(q)
		if h and h.collider and h.collider.has_meta("break"):
			mission.hit_breakable(int(h.collider.get_meta("break")), 30.0, "melt")
			if rng.randf() < 0.3:
				mission.ignite(h.position)
	_heat_cd -= delta
	var tgt: Node = target if is_instance_valid(target) and target.has_method("is_player") and not target.dead else null
	if _charge > 0.0:
		_charge += delta
		if _charge >= HEAT_CHARGE:
			_charge = 0.0
			_heat_cd = rng.randf_range(6.0, 9.0)
			if tgt:
				_discharge(tgt.global_position + Vector3(0, 1.0, 0))
			else:
				_heat_glow.rpc(false)
	elif tgt and _heat_cd <= 0.0 and global_position.distance_to(tgt.global_position) < 9.0 \
			and _los(tgt.global_position + Vector3(0, 1.2, 0)):
		_charge = 0.01
		_heat_glow.rpc(true)

func _discharge(at: Vector3) -> void:
	var from := global_position + Vector3(0, 0.5, 0)
	var dir := (at - from).normalized()
	var to := from + dir * 10.0
	var q := PhysicsRayQueryParameters3D.create(from, to, Game.WORLD | Game.GLASS)
	q.exclude = [get_rid()]
	var h := get_world_3d().direct_space_state.intersect_ray(q)
	if h:
		to = h.position
		if h.collider and h.collider.has_meta("break"):
			mission.hit_breakable(int(h.collider.get_meta("break")), 160.0, "melt")    # straight through a wall
	var dmg := 45.0 * (1.35 if Game.veteran() else 1.0)
	for p in mission.players():
		if p.dead:
			continue
		var pp: Vector3 = p.global_position + Vector3(0, 1.0, 0)
		var t := clampf((pp - from).dot(dir) / maxf(0.01, from.distance_to(to)), 0.0, 1.0)
		if pp.distance_to(from.lerp(to, t)) < 1.4:
			p.hurt.rpc_id(p.get_multiplayer_authority(), dmg, global_position, false, "heat")
	mission.ignite(to)
	mission.ignite(from.lerp(to, 0.6))
	_tlog("heat discharge")
	_heat_fx.rpc(from, to)

@rpc("authority", "call_local", "reliable")
func _heat_glow(on: bool) -> void:
	var old := body.get_node_or_null("Heat")
	if old:
		old.queue_free()
	if not on:
		return
	var l := OmniLight3D.new()
	l.name = "Heat"
	l.light_color = Color(1.0, 0.35, 0.05)
	l.omni_range = 7.0
	l.light_energy = 0.0
	body.add_child(l)
	l.position = Vector3(0, 0.6, 0)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "light_energy", 7.0, HEAT_CHARGE)
	tw.tween_property(l, "light_color", Color(1.0, 0.9, 0.4), HEAT_CHARGE)
	Game.play_at(mission, "fire", global_position, 2)
	var me: Node = mission.local_player()
	if me and me.global_position.distance_to(global_position) < 15.0 and mission.hud:
		pass

@rpc("authority", "call_local", "reliable")
func _heat_fx(from: Vector3, to: Vector3) -> void:
	var old := body.get_node_or_null("Heat")
	if old:
		old.queue_free()
	Game.play_at(mission, "fire_ignite", from, 6)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.18
	cm.bottom_radius = 0.18
	cm.height = from.distance_to(to)
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.75, 0.2)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mission.add_child(mi)
	mi.global_position = (from + to) / 2.0
	mi.look_at_from_position(mi.global_position, to, Vector3.UP if absf((to - from).normalized().y) < 0.95 else Vector3.RIGHT)
	mi.rotate_object_local(Vector3.RIGHT, PI / 2.0)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.15)
	l.light_energy = 8.0
	l.omni_range = 9.0
	mi.add_child(l)
	var tw := mi.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.45)
	tw.parallel().tween_property(l, "light_energy", 0.0, 0.45)
	tw.tween_callback(mi.queue_free)

## Levit Mírotvůrce: wounds close when nothing has hit it for a while (up to three quarters).
var _mending := false
var _mend_cd := 0.0
func _mend_tick(delta: float) -> void:
	_mend_cd -= delta
	var top := float(R["hp"]) * 0.75
	if hp < top and mission.t - _hit_t > 5.0:
		hp = minf(top, hp + float(R["mend"]) * delta)
	if _mending and hp >= float(R["hp"]) * 0.7:
		_mending = false
		_tlog("mend: back")

## Levits near a Mírotvůrce in a fight go berserk: a howl, faster, shooting more, no hiding.
var _frenzy := false
var _frenzy_chk := 0.0
func _frenzy_check(delta: float) -> void:
	_frenzy_chk -= delta
	if _frenzy_chk > 0.0:
		return
	_frenzy_chk = 1.0
	var on := false
	if state == S.COMBAT:
		for a in mission.aliens():
			if a != self and not a.dead and a.R.has("frenzy") and a.state == S.COMBAT \
					and a.global_position.distance_to(global_position) < float(a.R["frenzy"]):
				on = true
				break
	if on != _frenzy:
		_set_frenzy.rpc(on)

@rpc("authority", "call_local", "reliable")
func _set_frenzy(on: bool) -> void:
	_frenzy = on
	if on:
		Game.play_at(mission, "roar", global_position, -2)
	if multiplayer.is_server():
		var k := 1.3 if on else 1.0 / 1.3
		walk_spd *= k
		run_spd *= k

## A burst is over: away from where it was seen.
func _after_burst() -> void:
	if AT.maybe_fall_back(self):
		return
	if _can_grab() and rng.randf() < 0.5:
		_tlog("grab start")
		phase = "grab"
		_brute_repath = 0.0
		return
	if tac == "levit" and rng.randf() < 0.8 and _levit_hop(last_seen, false):
		phase = "move"
		return
	if tac in ["soldier", "hunter", "grey"] and hp > float(R["hp"]) * 0.45:
		# hold the ground: duck behind what it stands at, then up and firing again -
		# more so when a squad mate is moving up meanwhile (one shoots, one runs)
		var p := _press
		for a in mission.aliens():
			if a != self and not a.dead and a.phase in ["move", "flank"] and a.global_position.distance_to(global_position) < 20.0:
				p += 0.2
				break
		if rng.randf() < p and AT.duck_ok(self):
			phase = "duck"
			_duck_t = rng.randf_range(0.5, 1.4) * (1.0 - 0.3 * _late)
			return
	_relocate(last_seen)
	phase = "move"

## Done hiding: where next.
func _next_move() -> void:
	if AT.maybe_fall_back(self):
		return
	var dist := global_position.distance_to(last_seen)
	phase = "flank"
	# hurt ones keep their heads down longer
	if hp < float(R["hp"]) * 0.4 and rng.randf() < 0.5:
		hide_t = rng.randf_range(2.0, 4.0)
		_relocate(last_seen)
		phase = "move"
		return
	if is_instance_valid(target) and target.has_method("is_player"):
		if _habit(target, "sniper") and dist > 14.0 and _advance(last_seen):
			return           # a sniper: close in under cover, never stay at his range
		if (_habit(target, "stit") or _habit(target, "minigun")) and tac != "brute":
			_flank_rear(target)
			return
	if _can_grab() and rng.randf() < 0.7:
		phase = "grab"
		_brute_repath = 0.0
		return
	match tac:
		"levit":
			if _levit_hop(last_seen, false):
				phase = "move"
				return
		"grey":
			if is_instance_valid(target) and not target.dead:
				_flank_rear(target)
				return
		"psi":
			_keep_away(last_seen)
			return
	if dist > lerpf(28.0, 15.0, _late) and _advance(last_seen):
		return           # (late in the war they press in instead of trading shots from afar)
	if tac in ["soldier", "hunter"] and mission.t - _seen_t > 5.0 and rng.randf() < 0.3 + _press:
		# lost sight of him for a while: push straight in until it sees him again
		var dir := last_seen - global_position
		dir.y = 0
		if dir.length() > 5.0:
			_tlog("push")
			phase = "flank"
			_go(_snap(global_position + dir.normalized() * minf(dir.length() - 3.0, 14.0)))
			return
	if tac in ["soldier", "hunter", "grey"] and rng.randf() < 0.35 + _press * 0.6:
		# a firing position: cover near by, from which it can see where he was
		var fs := _fire_spot(last_seen)
		if fs != Vector3.INF:
			_tlog("fire spot")
			_go(fs)
			return
	if not R.has("hover") and rng.randf() < (0.55 if tac in ["soldier", "hunter"] else 0.4):
		var w := _window_spot(last_seen)
		if w != Vector3.INF:
			_tlog("window")
			_go(w)
			return
	_flank()

## A cover point near by from which @a at can be seen (and shot): half cover preferred.
func _fire_spot(at: Vector3) -> Vector3:
	var ss := get_world_3d().direct_space_state
	var best := Vector3.INF
	var bs := 1e9
	for c in mission.map["cover"]:
		var cp: Vector3 = c
		var d := global_position.distance_to(cp)
		if d > 14.0 or d < 1.5:
			continue
		var dt := cp.distance_to(at)
		if dt < 7.0 or dt > 34.0:
			continue
		var q := PhysicsRayQueryParameters3D.create(cp + Vector3(0, 1.5, 0), at + Vector3(0, 1.1, 0), Game.WORLD)
		if not ss.intersect_ray(q).is_empty():
			continue
		var sc := d + absf(dt - 16.0) * 0.4 + rng.randf() * 3.0
		var q2 := PhysicsRayQueryParameters3D.create(cp + Vector3(0, 0.6, 0), at + Vector3(0, 0.6, 0), Game.WORLD)
		if not ss.intersect_ray(q2).is_empty():
			sc -= 5.0           # something low in front of it: it can duck
		for a in mission.aliens():
			if a != self and not a.dead and a.goal.distance_to(cp) < 3.0:
				sc += 6.0
		sc += AT.exposure_extra(self, cp, at, 1.0) * 8.0     # (co-op: the other man must not have it in the open)
		if sc < bs:
			bs = sc
			best = cp
	return best

## Breaks line of sight: a cover point that hides it from @a from,
## preferably to the side, so the next attack comes from elsewhere.
func _relocate(from: Vector3) -> void:
	var best := Vector3.ZERO
	var bs := 1e9
	var to_me := (global_position - from)
	to_me.y = 0
	to_me = to_me.normalized()
	var far := global_position.distance_to(from) > 30.0
	for c in mission.map["cover"]:
		var d: float = global_position.distance_to(c)
		if d > 16.0 or d < 2.0:
			continue
		var q := PhysicsRayQueryParameters3D.create(c + Vector3(0, 0.8, 0), from + Vector3(0, 1.0, 0), Game.WORLD)
		if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			continue
		var dir: Vector3 = (c - global_position)
		dir.y = 0
		var side: float = abs(to_me.cross(dir.normalized()).y)
		var score: float = d - side * 5.0
		if c.distance_to(from) < 6.0:
			score += 20.0
		if _spread_out:
			# they carry explosives: do not bunch up
			for a in mission.aliens():
				if a != self and not a.dead and a.goal.distance_to(c) < 5.0:
					score += 8.0
		if far or tac == "soldier":
			# a shooter far away: each move brings it closer to him
			score += (c.distance_to(from) - global_position.distance_to(from)) * 0.6
		score += AT.exposure_extra(self, c, from, 0.8) * 12.0   # hidden from him, but not in the open for the others
		if score < bs:
			bs = score
			best = c
	if bs < 1e9:
		_go(best)
	else:
		_go(_snap(global_position + to_me * 9.0))

func _flank() -> void:
	var v := global_position - last_seen
	v.y = 0
	if v.length() < 0.1:
		v = Vector3(1, 0, 0)
	var ang := rng.randf_range(1.2, 2.3) * (1.0 if rng.randf() < 0.5 else -1.0)
	var p := last_seen + v.normalized().rotated(Vector3.UP, ang) * rng.randf_range(7.0, 12.0)
	_go(AT.pick_flank(self, _snap(p), v))

# ---- tactics -------------------------------------------------------------------------------
## What this mercenary is known to bring (the aliens have learned it over the campaign).
func _habit(p: Node, item: String) -> bool:
	if p == null or not is_instance_valid(p) or not "display_name" in p:
		return false
	var h: Dictionary = Net.mission_params.get("habits", {})
	return item in h.get(String(p.display_name), [])

func _tlog(what: String) -> void:
	if Game.autotest() != "":
		print("[TAC] %s %s %s" % [name, race, what])

var _bail_done := false
var _spread_out := false
var _burst_snd := 0.0
var _nade_cd := 8.0
var _rocket_cd := 2.0
var _grab_cd := 6.0
var _cry_t := 6.0

## Bijec officer: a roar that drives the others on - steadier, faster, wounds forgotten.
func _warcry_tick(delta: float) -> void:
	if R.has("module"):
		_reinf_tick(delta)
		if not module_ok:
			return             # the module is gone: no more orders
	_cry_t -= delta
	if _cry_t > 0.0:
		return
	_cry_t = rng.randf_range(18.0, 28.0)
	var n := 0
	for a in mission.aliens():
		if a != self and not a.dead and not a.husk and a.global_position.distance_to(global_position) < 26.0:
			a._rally_t = 15.0
			a.react = minf(a.react, 0.15)
			a.hp = minf(float(a.R["hp"]) * 1.2, a.hp + 20.0)
			n += 1
	_tlog("warcry %d" % n)
	_warcry_fx.rpc()

## Bijec officer: the command module on its forearm. Left alive too long in a fight, it calls more of them;
## shoot the module and it can neither call nor drive the others on.
var module_ok := true
var _reinf_t := 0.0
var _reinf_done := false
func _reinf_tick(delta: float) -> void:
	if not module_ok or _reinf_done or state != S.COMBAT:
		return
	_reinf_t += delta
	if _reinf_t < (55.0 if Game.veteran() else 75.0):
		return
	_reinf_done = true
	var soldier: String = race.trim_suffix("_velitel")
	var away := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
	for i in (3 if Game.veteran() else 2):
		var at: Vector3 = mission.free_spot(global_position + away * rng.randf_range(24.0, 32.0) + Vector3(rng.randf_range(-4, 4), 0.3, rng.randf_range(-4, 4)))
		mission.spawn_alien(soldier, at)
	_tlog("reinforcements")
	_reinf_fx.rpc()

@rpc("authority", "call_local", "reliable")
func _reinf_fx() -> void:
	Game.play_at(mission, "bijec_warcry", global_position + Vector3(0, 2.0, 0), 8)
	if mission.hud:
		pass

func module_hit() -> void:
	if not module_ok or dead:
		return
	module_ok = false
	hp -= 30.0
	_tlog("module destroyed")
	_module_fx.rpc()

@rpc("authority", "call_local", "reliable")
func _module_fx() -> void:
	module_ok = false
	Game.play_at(mission, "zap", global_position + Vector3.UP * 1.2, 2)
	var me: Node = mission.local_player()
	if me and me.global_position.distance_to(global_position) < 60.0 and mission.hud:
		pass

@rpc("authority", "call_local", "reliable")
func _warcry_fx() -> void:
	var at := global_position + Vector3(0, 2.0, 0)
	Game.play_at(mission, "bijec_warcry", at, 6)
	if anim and anim.has_animation("roar"):
		_cry_anim_t = minf(anim.get_animation("roar").length, ROAR_TIME)
	var me: Node = mission.local_player()
	if me and me.global_position.distance_to(global_position) < 35.0:
		me.stress = minf(100.0, me.stress + 8.0)
var _hit_t := -99.0
var _decloak_t := 0.0

## Host: it knows where @a p is for @a secs (shot from there, a muzzle flash, a drone told it).
func _know(p: Node, secs: float) -> void:
	if p == null or not is_instance_valid(p) or mission == null:
		return
	var k := String(p.name)
	known[k] = maxf(float(known.get(k, 0.0)), mission.t + secs)
	sus[k] = 1.0
	AT.saw(self, p)

func _knows(p: Node) -> bool:
	return float(known.get(String(p.name), -1.0)) > mission.t

## A known mercenary in plain line of sight - dark or not, it knows where to look.
func _sees_known(p: Node) -> bool:
	if dead or husk or not _knows(p):
		return false
	var chest: Vector3 = p.global_position + Vector3(0, 0.9 if p.crouching else 1.3, 0)
	if eye().distance_to(chest) > 120.0 or mission.smoke_blocks(eye(), chest):
		return false
	return _los(chest)

## Is @a p turned away from this alien?
func _back_to_me(p: Node) -> bool:
	var fwd: Vector3 = -p.global_transform.basis.z
	fwd.y = 0
	var to_me: Vector3 = global_position - p.global_position
	to_me.y = 0
	if fwd.length() < 0.01 or to_me.length() < 0.01:
		return false
	return fwd.normalized().dot(to_me.normalized()) < -0.15

## Everyone around learns who it was.
func _warn_squad(p: Node, reach: float) -> void:
	for a in mission.aliens():
		if a == self or a.dead or a.husk or a.R.get("dumb", false):
			continue
		if a.global_position.distance_to(global_position) > reach:
			continue
		a._know(p, 12.0)
		if a.state == S.COMBAT:
			a.target = p
			a.last_seen = p.global_position
		elif a.state != S.DRAG:
			if a.tac == "grey":
				a.target = p
				a.last_seen = p.global_position
				a._enter_combat(null)
				a._flank_rear(p)
				a.phase = "flank"
			else:
				a.stalk(p)

## Drone intel: a Diskoll tells the greys where somebody is.
func intel(p: Node) -> void:
	if dead or husk or state == S.DRAG:
		return
	_know(p, 6.0)
	last_seen = p.global_position
	if state != S.COMBAT:
		_tlog("intel")
		target = p
		_enter_combat(null)
		_flank_rear(p)
		phase = "flank"
	elif phase == "hide" or phase == "flank":
		target = p

## Greys: round behind the target - the shot comes into his back.
func _flank_rear(p: Node) -> void:
	var back: Vector3 = p.global_transform.basis.z
	back.y = 0
	back = back.normalized() if back.length() > 0.01 else Vector3.BACK
	var best := Vector3.INF
	var bs := 1e9
	for i in 4:
		var c: Vector3 = p.global_position + back.rotated(Vector3.UP, rng.randf_range(-0.9, 0.9)) * rng.randf_range(6.0, 11.0)
		c = _snap(c)
		var sc := c.distance_to(global_position) + rng.randf() * 4.0
		# do not cross right in front of him if it can be helped
		var mid: Vector3 = (c + global_position) / 2.0 - p.global_position
		mid.y = 0
		if mid.length() > 0.1 and (-p.global_transform.basis.z).dot(mid.normalized()) > 0.5:
			sc += 15.0
		sc += AT.exposure_extra(self, c, p.global_position + Vector3(0, 1.3, 0), 1.0) * 10.0   # (behind him is in front of his mate?)
		if sc < bs:
			bs = sc
			best = c
	last_seen = p.global_position
	_go(best if best != Vector3.INF else _snap(p.global_position + back * 8.0))

## A shooter far away: the next cover closer to him that he cannot see.
func _advance(at: Vector3) -> bool:
	var my_d := global_position.distance_to(at)
	var best := Vector3.INF
	var bs := 1e9
	for c in mission.map["cover"]:
		var d: float = global_position.distance_to(c)
		if d > 20.0 or d < 3.0 or c.distance_to(at) > my_d - 5.0:
			continue
		var q := PhysicsRayQueryParameters3D.create(c + Vector3(0, 0.9, 0), at + Vector3(0, 1.2, 0), Game.WORLD)
		if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			continue
		var sc: float = c.distance_to(at) + d * 0.5 + rng.randf() * 3.0
		sc += AT.exposure_extra(self, c, at, 0.9) * 10.0
		if sc < bs:
			bs = sc
			best = c
	if best == Vector3.INF:
		return false
	_tlog("advance")
	_go(best)
	return true

## Mysloděj: cover 16-28 m from the fight - close enough for its mind, far from the guns.
func _keep_away(at: Vector3) -> void:
	var best := Vector3.INF
	var bs := 1e9
	for c in mission.map["cover"]:
		var dd: float = c.distance_to(at)
		var d: float = global_position.distance_to(c)
		if dd < 16.0 or dd > 28.0 or d > 25.0:
			continue
		var q := PhysicsRayQueryParameters3D.create(c + Vector3(0, 1.0, 0), at + Vector3(0, 1.2, 0), Game.WORLD)
		if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			continue
		var sc: float = d + rng.randf() * 4.0
		sc += AT.exposure_extra(self, c, at, 1.0) * 10.0
		if sc < bs:
			bs = sc
			best = c
	if best == Vector3.INF:
		_relocate(at)
	else:
		_go(best)

## A window to shoot from at @a at: it stands on the far side of the wall from him.
func _window_spot(at: Vector3, high_only := false) -> Vector3:
	var best := Vector3.INF
	var bs := 1e9
	var ss := get_world_3d().direct_space_state
	for w in mission.map.get("windows", []):
		var c: Vector3 = w["c"]
		if high_only and c.y < 1.5:
			continue
		var dm := c.distance_to(global_position)
		var dt := c.distance_to(at)
		if dm > 32.0 or dt > 45.0 or dt < 5.0:
			continue
		var n: Vector3 = w["n"]
		var sd := -1.0 if n.dot(at - c) > 0.0 else 1.0
		var spot := c + n * 0.6 * sd
		var eh := maxf(float(R["eye"]) + float(R.get("hover", 0.0)) * 0.3, float(w["sill"]) + 0.35)
		var q := PhysicsRayQueryParameters3D.create(spot + Vector3(0, eh, 0), at + Vector3(0, 1.2, 0), Game.WORLD)
		if not ss.intersect_ray(q).is_empty():
			continue
		if not high_only:
			var sn := _snap(spot)
			if Vector2(sn.x - spot.x, sn.z - spot.z).length() > 0.8 or absf(sn.y - spot.y) > 0.6:
				continue
			spot = sn
		var sc := dm + rng.randf() * 6.0
		if sc < bs:
			bs = sc
			best = spot
	return best

# ---- Ještěřan officer: unseen, a blow to the back of the head, then off to the ship --------------
## (The Levit grabs in the open, with its tentacles - but only a man the others are too far to help.)
func _can_grab() -> bool:
	if not (R.has("grab") and (can_cloak or R.get("grab_open", false)) and _grab_cd <= 0.0 and is_instance_valid(target) and target.has_method("is_player") \
			and not target.downed and not target.dead and global_position.distance_to(target.global_position) < 35.0):
		return false
	return not R.get("grab_open", false) or _other_prey(target) == null

func _grab(delta: float) -> void:
	lurking = false
	var open: bool = R.get("grab_open", false)
	if not is_instance_valid(target) or target.dead or target.downed or not (can_cloak or open) or (open and _other_prey(target) != null):
		phase = "hide"
		hide_t = 0.8
		return
	var tp: Vector3 = target.global_position
	var back: Vector3 = target.global_transform.basis.z
	back.y = 0
	back = back.normalized() if back.length() > 0.01 else Vector3.BACK
	_brute_repath -= delta
	if _brute_repath <= 0.0:
		_brute_repath = 0.3
		_go(_snap(tp + back * 0.9))
	var dd := global_position.distance_to(tp)
	if not cloak and not open and dd < 6.0:
		velocity.x = 0; velocity.z = 0      # let the cloak settle before the last steps
		return
	_walk(run_spd * (0.85 if dd > 6.0 else 1.25), delta)
	if dd < 1.7:
		_face(tp, delta * 3.0)
		_tlog("grab KO")
		target.knock_out.rpc_id(target.get_multiplayer_authority())
		if open:
			target.abducted_note.rpc_id(target.get_multiplayer_authority())
		_grab_fx.rpc(tp + Vector3(0, 1.5, 0))
		_grab_cd = rng.randf_range(35.0, 50.0)
		_decloak_t = 0.8
		var nxt := _other_prey(target)
		if nxt:
			# somebody else around: get rid of him first
			target = nxt
			last_seen = nxt.global_position
			phase = "shoot"
			shots_left = _shots()
			react = 0.4
		else:
			phase = "hide"
			hide_t = 0.3

func _other_prey(t: Node) -> Node:
	for p in mission.players():
		if p != t and not p.dead and not p.downed and p.global_position.distance_to(t.global_position) < 20.0:
			return p
	return null

@rpc("authority", "call_local", "reliable")
func _grab_fx(at: Vector3) -> void:
	Game.play_at(mission, "ko_hit", at, 2)

# ---- brutes: no cover, no fear - straight at whatever it saw last -------------------------
var _brute_repath := 0.0
func _brute(delta: float, seen: Node) -> void:
	lurking = false
	_brute_repath -= delta
	var d := global_position.distance_to(last_seen)
	if d > 5.0 or seen == null:
		if _brute_repath <= 0.0:
			_brute_repath = 0.8
			_go(_snap(last_seen))
		_walk(walk_spd * 1.15, delta)
	else:
		velocity.x = 0; velocity.z = 0
	if seen:
		_face(seen.global_position, delta * 1.5)
		if react <= 0 and shoot_cd <= 0 and R.has("shots"):
			_fire(seen)
			mission.combat_t = mission.t
			shoot_cd = rng.randf_range(0.7, 1.1) * float(_g("rate", 1.0)) * (0.6 if _frenzy else 1.0)
	elif _arrived():
		velocity.x = 0; velocity.z = 0
		rotation.y += delta * 0.7      # where did it go

# ---- Levit: jets ------------------------------------------------------------------------------
var airborne := false     # host: hovering where there is no floor (roof, window)
var _jet: Array = []
var _jet_perch := false
var _jet_free := 0        # the last legs of the flight not checked for walls (in through a window)
var _jet_snd: AudioStreamPlayer3D
var _jet_light: OmniLight3D
var _was_flying := false

## Up, over and down onto a roof or into a window, from where it sees @a at.
## @a away: anywhere out of his sight will do (it was hit).
func _levit_hop(at: Vector3, away: bool) -> bool:
	if not R.has("hover") or _stagger > 0.0:
		return false
	var ss := get_world_3d().direct_space_state
	var best := Vector3.INF
	var entry := Vector3.INF
	var bs := 1e9
	var roofs: Array = mission.map.get("roofs", [])
	for i in roofs.size():
		var r: Vector3 = roofs[i]
		if r.y < -50.0:
			# a pitched roof: find its ridge once
			var q0 := PhysicsRayQueryParameters3D.create(Vector3(r.x, r.y + 140.0, r.z), Vector3(r.x, r.y + 99.0, r.z), Game.WORLD)
			var h0 := ss.intersect_ray(q0)
			r = Vector3(r.x, h0.position.y if not h0.is_empty() else -999.0, r.z)
			roofs[i] = r
		if r.y < 1.5:
			continue
		var dm := Vector2(r.x - global_position.x, r.z - global_position.z).length()
		var dt := r.distance_to(at)
		if dm > 40.0 or dm < 4.0 or dt > 45.0 or dt < 7.0:
			continue
		var q := PhysicsRayQueryParameters3D.create(r + Vector3(0, 1.9, 0), at + Vector3(0, 1.2, 0), Game.WORLD)
		var open := ss.intersect_ray(q).is_empty()
		if open == away:
			continue
		var sc := dm * 0.4 - r.y * 1.2 + rng.randf() * 6.0
		if sc < bs:
			bs = sc
			best = r + Vector3(0, 0.15, 0)
			entry = Vector3.INF
	if not away:
		for w in mission.map.get("windows", []):
			var c: Vector3 = w["c"]
			if c.y < 1.5 or Vector2(c.x - global_position.x, c.z - global_position.z).length() > 40.0:
				continue
			var n: Vector3 = w["n"]
			var sd := -1.0 if n.dot(at - c) > 0.0 else 1.0
			var inside := c + n * 0.8 * sd
			var q2 := PhysicsRayQueryParameters3D.create(inside + Vector3(0, 1.8, 0), at + Vector3(0, 1.2, 0), Game.WORLD)
			if not ss.intersect_ray(q2).is_empty():
				continue
			var sc2 := Vector2(c.x - global_position.x, c.z - global_position.z).length() * 0.4 - c.y * 1.2 - 2.0 + rng.randf() * 6.0
			if sc2 < bs:
				bs = sc2
				best = inside
				entry = c - n * 1.6 * sd
	if best == Vector3.INF:
		return false
	return _jet_to(best, entry, true)

## Is the air open from @a to @b (the alien's origin, its feet)? A ball the size of its body
## swept along the way - walls, ceilings, roofs, doors, glass. (The flight itself moves it without
## physics, so before this they flew through the base's ceilings and walls.)
func _air_clear(a: Vector3, b: Vector3) -> bool:
	if a.distance_to(b) < 0.01:
		return true
	var ball := SphereShape3D.new()
	ball.radius = clampf(float(R["r"]) * 0.9, 0.25, 0.45)
	var up := Vector3(0, maxf(ball.radius + 0.25, 0.9), 0)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = ball
	q.transform = Transform3D(Basis(), a + up)
	q.motion = b - a
	q.collision_mask = Game.WORLD | Game.GLASS
	q.exclude = [get_rid()]
	var ss := get_world_3d().direct_space_state
	var r := ss.cast_motion(q)
	var ok := r.size() >= 2 and r[0] >= 1.0
	if not ok and Game.autotest() != "":
		q.transform.origin += q.motion * (r[1] if r.size() >= 2 else 0.0)
		q.motion = Vector3.ZERO
		q.margin = 0.05
		var hit := ss.intersect_shape(q, 1)
		_tlog("air blocked %s -> %s at %.2f by %s" % [str(a.snapped(Vector3.ONE * 0.1)), str(b.snapped(Vector3.ONE * 0.1)), r[1] if r.size() >= 2 else -1.0,
			str(hit[0]["collider"].get_parent().name) + "/" + str(hit[0]["collider"].name) if not hit.is_empty() and hit[0]["collider"] else "?"])
	return ok

func _path_clear(pts: Array, from: Vector3, unchecked: int) -> bool:
	var at := from
	for i in pts.size() - unchecked:
		if not _air_clear(at, pts[i]):
			return false
		at = pts[i]
	return true

## Plans a flight and takes off; false when there is no open way through the air (indoors: the
## base, a ship - the ceiling is over its head), then it has to walk.
func _jet_to(dest: Vector3, entry := Vector3.INF, perch := false) -> bool:
	var from := global_position
	var last := entry if entry != Vector3.INF else dest
	var cruise := maxf(maxf(from.y, last.y) + 4.0, 8.5)
	var pts: Array = [Vector3(from.x, cruise, from.z), Vector3(last.x, cruise, last.z)]
	if entry != Vector3.INF:
		pts.append(entry)
	pts.append(dest)
	var unchecked := 1 if entry != Vector3.INF else 0     # the last leg goes in through the window
	if not _path_clear(pts, from, unchecked):
		# no sky over it: straight across, at body height, if nothing is in the way
		pts = [dest] if entry == Vector3.INF else [entry, dest]
		if not _path_clear(pts, from, unchecked):
			_tlog("jet blocked h=%.1f" % dest.y)
			return false
	_jet = pts
	_jet_free = unchecked
	_jet_perch = perch
	_tlog("jet %s perch=%s h=%.1f" % ["window" if entry != Vector3.INF else "", perch, dest.y])
	flying = true
	airborne = true
	lurking = false
	goal = dest
	if not perch:
		agent.target_position = dest
	return true

## Host: follows the flight path (checked open when it took off; a door shut since, or anything
## new in the way, ends the flight - it drops and goes on foot).
func _fly(delta: float) -> void:
	if _jet.is_empty():
		flying = false
		airborne = _jet_perch
		return
	var tgt: Vector3 = _jet[0]
	var flat := Vector2(tgt.x - global_position.x, tgt.z - global_position.z).length()
	var spd := (9.25 if flat > 0.3 else 6.25) * float(R.get("jet", 1.0))    # 0.44 slowed them from 12 to 6.5, too much: half of it back
	var nxt := global_position.move_toward(tgt, spd * delta)
	if _jet.size() > _jet_free and not _air_clear(global_position, nxt):
		_tlog("jet stopped by a wall")
		_jet.clear()
		flying = false
		airborne = false     # falls (gravity) and walks on
		velocity = Vector3.ZERO
		return
	global_position = nxt
	if flat > 0.3:
		_face(tgt, delta)
	elif is_instance_valid(target):
		_face(target.global_position, delta)
	if global_position.distance_to(tgt) < 0.05:
		_jet.pop_front()
		if _jet.is_empty():
			flying = false
			airborne = _jet_perch
			velocity = Vector3.ZERO

## Every machine: the roar and the blue flame of the jets.
func _jet_tick(delta: float) -> void:
	if tac != "levit":
		return
	if flying != _was_flying:
		_was_flying = flying
		if _jet_snd == null:
			_jet_snd = AudioStreamPlayer3D.new()
			_jet_snd.stream = Game.loop_stream("levit_jet")
			_jet_snd.unit_size = 5.0
			_jet_snd.max_distance = 60.0
			_jet_snd.volume_db = -4.0
			_jet_snd.bus = "SFX"
			add_child(_jet_snd)
			_jet_light = OmniLight3D.new()
			_jet_light.light_color = Color(0.75, 0.25, 1.0) if race == "levit_velitel" else Color(0.45, 0.6, 1.0)
			_jet_light.omni_range = 5.0
			_jet_light.light_energy = 0.0
			add_child(_jet_light)
			_jet_light.position = Vector3(0, float(R["hover"]) - 0.2, 0)
		if flying:
			_jet_snd.play()
			Game.play_at(mission, "hiss", global_position, 0)
		else:
			_jet_snd.stop()
	if _jet_light:
		_jet_light.light_energy = move_toward(_jet_light.light_energy, (2.2 + randf() * 0.8) if flying else 0.0, delta * 8.0)

# ---- Ještěřani and Bijci: plasma grenades --------------------------------------------------------
func _throw_nade(at: Vector3) -> void:
	for a in mission.aliens():
		if a != self and not a.dead and a.global_position.distance_to(at) < 5.0:
			_fire_instead(at)
			return
	_nade_cd = rng.randf_range(14.0, 24.0) * (0.75 if Game.veteran() else 1.0) * (1.0 - 0.4 * _late)
	var fwd := -global_transform.basis.z
	var from := global_position + Vector3(0, float(R["h"]) * 0.85, 0) + fwd * 0.4
	var aim := at + Vector3(rng.randf_range(-1.2, 1.2), 0.1, rng.randf_range(-1.2, 1.2))
	var d := aim - from
	var flat := Vector2(d.x, d.z).length()
	var t := clampf(flat / 11.0, 0.7, 1.8)
	var v := Vector3(d.x / t, d.y / t + 0.5 * 9.8 * t, d.z / t)
	_decloak_t = 1.6
	_tlog("grenade")
	_lob.rpc(from, v)

func _fire_instead(at: Vector3) -> void:
	_nade_cd = 3.0
	if is_instance_valid(target):
		_fire(target)

@rpc("authority", "call_local", "reliable")
func _lob(from: Vector3, v: Vector3) -> void:
	var rb := RigidBody3D.new()
	rb.collision_layer = 8
	rb.collision_mask = 1
	rb.mass = 0.6
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.09
	cs.shape = sh
	rb.add_child(cs)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.09; sm.height = 0.18; sm.radial_segments = 8; sm.rings = 4
	mi.mesh = sm
	mi.material_override = Game.color_mat(Color(0.35, 1.0, 0.45), true)
	rb.add_child(mi)
	var l := OmniLight3D.new()
	l.light_color = Color(0.35, 1.0, 0.45)
	l.light_energy = 1.2
	l.omni_range = 3.0
	rb.add_child(l)
	mission.add_child(rb)
	rb.global_position = from
	rb.linear_velocity = v
	Game.play_at(mission, "swish", from, -4)
	for k in 3:
		get_tree().create_timer(0.9 + k * 0.45).timeout.connect(func():
			if not is_instance_valid(rb):
				return
			Game.play_at(mission, "plasma_grenade_beep", rb.global_position, 2)
			l.light_energy = 4.0
			var me: Node = mission.local_player()
			if k == 0 and me and not me.dead and me.global_position.distance_to(rb.global_position) < 9.0:
				pass)
	get_tree().create_timer(2.4).timeout.connect(func():
		if not is_instance_valid(rb):
			return
		var p := rb.global_position
		rb.queue_free()
		if multiplayer.is_server():
			mission.explode(p, 4.5, 70.0 * (1.2 if Game.veteran() else 1.0), "-", false))

# ---- Ještěřani: flash traps -----------------------------------------------------------------------
var traps_left := 0
var _traps: Array = []        # host: [pos, id]
var _trap_t := 0.0
var _trap_n := 0

func _maybe_trap(chance: float) -> void:
	if (traps_left <= 0 and mines_left <= 0) or rng.randf() > chance or airborne:
		return
	var p := global_position
	for a in mission.aliens():
		for t in a._traps:
			if (t[0] as Vector3).distance_to(p) < 7.0:
				return
	var kind := "flash"
	if mines_left > 0 and (traps_left <= 0 or rng.randf() < 0.5):
		kind = "mine"
		mines_left -= 1
	else:
		traps_left -= 1
	_trap_n += 1
	var id := "%s_%d" % [name, _trap_n]
	_traps.append([p, id, kind])
	_tlog("trap " + kind)
	_trap_put.rpc(p, id, kind)

@rpc("authority", "call_local", "reliable")
func _trap_put(p: Vector3, id: String, kind := "flash") -> void:
	var n := Node3D.new()
	n.name = "Trap_" + id
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.11; cm.bottom_radius = 0.13; cm.height = 0.035; cm.radial_segments = 10
	disc.mesh = cm
	disc.material_override = Game.color_mat(Color(0.12, 0.13, 0.1))
	n.add_child(disc)
	var dot := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.012; sm.height = 0.024
	dot.mesh = sm
	var dm := Game.color_mat(Color(0.35, 1.0, 0.45) if kind == "mine" else Color(1.0, 0.15, 0.05), true)
	dot.material_override = dm
	n.add_child(dot)
	dot.position.y = 0.025
	mission.add_child(n)
	n.global_position = p + Vector3(0, 0.02, 0)
	# a slow blink - hard to notice in the grass
	var tw := n.create_tween().set_loops()
	tw.tween_callback(func(): dot.visible = true)
	tw.tween_interval(0.12)
	tw.tween_callback(func(): dot.visible = false)
	tw.tween_interval(2.3)

func _traps_tick(delta: float) -> void:
	_trap_t -= delta
	if _trap_t > 0.0:
		return
	_trap_t = 0.2
	for i in range(_traps.size() - 1, -1, -1):
		var tp: Vector3 = _traps[i][0]
		for p in mission.players():
			if p.dead:
				continue
			var dd: Vector3 = p.global_position - tp
			if Vector2(dd.x, dd.z).length() < 1.6 and absf(dd.y) < 1.5:
				var kind: String = _traps[i][2] if _traps[i].size() > 2 else "flash"
				_trap_go.rpc(String(_traps[i][1]), tp, kind)
				_traps.remove_at(i)
				if kind == "mine":
					get_tree().create_timer(0.35).timeout.connect(func(): mission.explode(tp + Vector3(0, 0.3, 0), 3.8, 75.0 * (1.2 if Game.veteran() else 1.0), "-", true))
				mission.noise(tp, 30.0)
				# the hunters know at once where the prey is
				for a in mission.aliens():
					if not a.dead and a.global_position.distance_to(tp) < 55.0 and not a.R.get("dumb", false):
						a._know(p, 12.0)
						if a.state != S.COMBAT and a.state != S.DRAG:
							a.stalk(p)
				break

@rpc("authority", "call_local", "reliable")
func _trap_go(id: String, p: Vector3, kind := "flash") -> void:
	var n := mission.get_node_or_null("Trap_" + id)
	if n:
		n.queue_free()
	if kind == "mine":
		Game.play_at(mission, "plasma_grenade_beep", p, 6)
		var me0: Node = mission.local_player()
		if me0 and not me0.dead and me0.global_position.distance_to(p) < 8.0:
			pass
		return
	Game.play_at(mission, "flash_trap", p, 6)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.97, 0.9)
	l.light_energy = 40.0
	l.omni_range = 16.0
	mission.add_child(l)
	l.global_position = p + Vector3(0, 0.6, 0)
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.5)
	tw.tween_callback(l.queue_free)
	var me: Node = mission.local_player()
	if me and not me.dead and me.cam:
		var d: float = me.cam.global_position.distance_to(p)
		if d < 12.0:
			var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.4, 0), me.cam.global_position, Game.WORLD)
			if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
				mission.hud.blind_flash(clampf(1.4 - d / 12.0, 0.3, 1.0))
				me.stress = minf(100.0, me.stress + 25.0)
				pass

# ---- Ještěřani: the cloak - only the eyes give them away ----------------------------------------
var _cloak_k := 0.0
var _cloak_meshes: Array = []
var _cloak_eyes: Node3D
var _shimmer: ShaderMaterial
const SHIMMER := """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
uniform float k = 0.0;
void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float wob = 0.6 + 0.4 * sin(TIME * 5.0 + VERTEX.y * 9.0);
	ALBEDO = vec3(0.3, 0.45, 0.4) * f * wob;
	ALPHA = f * k * 0.35;
}"""

var _cloak_snd := false
func _cloak_tick(delta: float) -> void:
	if not R.has("cloak"):
		return
	var want := 1.0 if cloak and not dead else 0.0
	if cloak != _cloak_snd:
		_cloak_snd = cloak
		Game.play_at(mission, "cloak_on" if cloak else "cloak_off", global_position + Vector3.UP, -6)
	if absf(_cloak_k - want) < 0.001 and _cloak_eyes != null:
		return
	if _cloak_eyes == null:
		for c in body.find_children("*", "GeometryInstance3D", true, false):
			if c != eye_glint:
				_cloak_meshes.append(c)
		_shimmer = ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = SHIMMER
		_shimmer.shader = sh
		_cloak_eyes = Node3D.new()
		var col: Color = (R.get("glint", [Vector3.ZERO, Color(1, 0.6, 0.1)]) as Array)[1]
		for sx in [-0.065, 0.065]:
			var e := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.022; sm.height = 0.044; sm.radial_segments = 8; sm.rings = 4
			e.mesh = sm
			e.material_override = Game.color_mat(col, true)
			_cloak_eyes.add_child(e)
			e.position = Vector3(sx, 0, 0)
		eye_glint.get_parent().add_child(_cloak_eyes)
		_cloak_eyes.transform = eye_glint.transform
		_cloak_eyes.visible = false
	_cloak_k = move_toward(_cloak_k, want, delta * (0.6 if want > 0.0 else 2.5))
	for g in _cloak_meshes:
		if is_instance_valid(g):
			g.transparency = _cloak_k * 0.95
			g.material_overlay = _shimmer if _cloak_k > 0.02 else null
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if _cloak_k > 0.5 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_shimmer.set_shader_parameter("k", _cloak_k)
	_cloak_eyes.visible = _cloak_k > 0.35

## Back into the dark: a hiding spot away from the mercenaries.
func _go_lurk(move_far: bool) -> void:
	if not move_far and activity != 0:
		state = S.LURK       # already given a job by a partner: go and do it
		phase = ""
		return
	if not move_far and not _act_picked:
		_act_picked = true
		if _pick_activity():
			state = S.LURK
			phase = ""
			wait = rng.randf_range(25.0, 60.0)
			return
	state = S.LURK
	phase = ""
	wait = rng.randf_range(25.0, 60.0)
	var best := global_position
	var bs := 1e9
	for c in mission.map["cover"]:
		var d: float = global_position.distance_to(c)
		if move_far and (d < 6.0 or d > 30.0):
			continue
		var score := d if not move_far else rng.randf_range(0.0, 10.0)
		for p in mission.players():
			if p.global_position.distance_to(c) < 15.0:
				score += 30.0
		for l in mission.map.get("lights", []):
			if is_instance_valid(l) and l.global_position.distance_to(c) < 6.0:
				score += 10.0
		if score < bs:
			bs = score
			best = c
	_go(best)

# ---- dragging a fallen mercenary away ------------------------------------------------
func _try_drag() -> bool:
	if airborne or flying:
		return false
	for p in mission.players():
		var claimed := false
		for a in mission.aliens():
			if a != self and a.dragging == p:
				claimed = true
		if claimed:
			continue
		if R.has("grab") and _other_prey(p) != null:
			continue         # it takes its prey only when nobody can stop it
		if p.downed and not p.dead and p.carried_by == 0 and global_position.distance_to(p.global_position) < 16.0:
			if _los(p.global_position + Vector3(0, 0.4, 0)):
				state = S.DRAG
				dragging = p
				lurking = false
				phase = "reach"
				_go(p.global_position)
				return true
	return false

func _drag(delta: float) -> void:
	if not is_instance_valid(dragging) or not dragging.downed or dragging.dead:
		_release()
		return
	if phase == "reach":
		_go(dragging.global_position)
		_walk(run_spd, delta)
		if global_position.distance_to(dragging.global_position) < 1.4:
			dragging.set_carried.rpc_id(dragging.get_multiplayer_authority(), -(int(name.substr(1)) + 1))
			phase = "away"
			Game.play_at(mission, "alien", global_position, -2)
			# somewhere dark and far from the others: the UFO, or the farthest cover
			var best: Vector3 = mission.map["ufo"]
			var bs := -1.0 if not R.has("grab") else 1e9     # the lizard officer: into the ship
			if R.has("grab") and mission.map.get("ufo_door", Vector3.ZERO) != Vector3.ZERO:
				best = _snap(mission.map["ufo_door"])
			for c in mission.map["cover"]:
				var dmin := 1e9
				for o in mission.players():
					if o != dragging:
						dmin = min(dmin, o.global_position.distance_to(c))
				if global_position.distance_to(c) < 25.0 and dmin > bs:
					bs = dmin
					best = c
			_go(best)
		return
	if dragging.carried_by != -(int(name.substr(1)) + 1):
		_release()
		return
	_walk(walk_spd * 0.75, delta)
	if _arrived():
		velocity.x = 0; velocity.z = 0
		lurking = true

func _release() -> void:
	if is_instance_valid(dragging) and dragging.carried_by == -(int(name.substr(1)) + 1):
		dragging.set_carried.rpc_id(dragging.get_multiplayer_authority(), 0)
	dragging = null
	if not dead:
		_enter_combat(null)
		_relocate(global_position)
		phase = "move"

# ---- movement ------------------------------------------------------------------------
func _arrived() -> bool:
	if flying:
		return false
	if airborne:
		return true
	return agent.is_navigation_finished() or global_position.distance_to(goal) < 1.0

var _stuck_base := 0.0
func _walk(speed: float, delta: float) -> void:
	if _arrived() or airborne:
		velocity.x = 0
		velocity.z = 0
		return
	var nxt := agent.get_next_path_position()
	var dir := nxt - global_position
	dir.y = 0
	if dir.length() < 0.05:
		dir = goal - global_position
		dir.y = 0
	dir = dir.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_face(global_position + dir, delta)
	# big bodies get stuck in gaps the path thinks are fine: give up that goal
	if get_slide_collision_count() > 0 and Vector2(get_real_velocity().x, get_real_velocity().z).length() < speed * 0.25:
		_stuck_base += delta
		if _stuck_base > 2.0:
			_stuck_base = 0.0
			_go(_snap(global_position + Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6))))
	else:
		_stuck_base = 0.0

func _face(p: Vector3, delta: float) -> void:
	var d := p - global_position
	d.y = 0
	if d.length() < 0.01:
		return
	var want := atan2(-d.x, -d.z)
	rotation.y = lerp_angle(rotation.y, want, delta * 6.0)

func _fire(p: Node) -> void:
	var tgt: Vector3 = p.global_position + Vector3(0, 0.75 if p.crouching else 1.15, 0)
	var dist := global_position.distance_to(tgt)
	if (R.has("rocket") and _rocket_cd <= 0.0 and dist > 7.0) or (gun == "rocket" and dist > 6.0):
		# Levit officer: a rocket at his feet
		_rocket_cd = rng.randf_range(6.0, 10.0)
		var rf := _muzzle_pos()
		var rt: Vector3 = p.global_position + Vector3(0, 0.2, 0) + Vector3(p.velocity.x, 0, p.velocity.z) * (dist / 24.0) * 0.8
		rt += Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
		_tlog("rocket")
		_plasma.rpc(rf, (rt - rf).normalized(), 1.0, "rocket")
		return
	var miss := (0.45 + dist * 0.032) * float(_g("miss", 1.0)) * (1.5 if suit_down else 1.0) * (1.6 if _disarray_t > 0.0 else 1.0) * (1.4 if _psi_spent > 0.0 else 1.0)
	if R.has("night_eyes"):
		# the Ještěřan sees best in the dark: at night its aim is steadier still
		miss *= {"noc": 0.6, "soumrak": 0.8, "svitani": 0.8}.get(mission.phase(), 1.0)
	if _blind_t > 0.0:
		miss *= 3.0           # dazzled: it fires where it last saw you
	if _sensor_hits >= 2:
		miss *= 1.8           # the Kolos with its sensor eye shot out
	if Game.veteran(): miss *= 0.8
	elif Game.easy(): miss *= 1.4
	miss *= _aim_k
	if _rally_t > 0: miss *= 0.75
	if p.crouching: miss *= 1.25
	var pv := Vector3(p.velocity.x, 0, p.velocity.z)
	if pv.length() > 2.0: miss *= 1.35
	if tac == "grey" and _back_to_me(p):
		miss *= 0.55          # a shot into the back is taken calmly
	var from := _muzzle_pos()
	var kind: String = R.get("spit", "plasma")
	# lead the target: where he will be when the bolt gets there
	var bolt_v: float = BoltScript.speed_for(float(_g("bolt", 1.0)), kind)
	tgt += pv * clampf(dist / bolt_v, 0.0, 1.5) * (0.85 if not Game.easy() else 0.4)
	tgt += Vector3(rng.randf_range(-miss, miss), rng.randf_range(-miss, miss) * 0.6, rng.randf_range(-miss, miss))
	# the gun is low (behind a sill, a wall): lift it to the eyes, which do see him
	var q := PhysicsRayQueryParameters3D.create(from, tgt, Game.WORLD)
	if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		var e := eye() + Vector3(0, -0.08, 0) + (-global_transform.basis.z) * 0.35
		var q2 := PhysicsRayQueryParameters3D.create(e, tgt, Game.WORLD)
		if get_world_3d().direct_space_state.intersect_ray(q2).is_empty():
			from = e
	var d := (tgt - from)
	if kind != "plasma":
		# spit: lob it - aim above the target so it falls onto him
		var dist2 := Vector2(d.x, d.z).length()
		var tt := dist2 / 15.0
		d = d / max(tt, 0.05)
		d.y += 0.5 * 7.0 * tt
		d = d / 15.0
	_decloak_t = 1.6
	shots_fired += 1
	var quiet := gun == "minigun" or gun == "hminigun"
	if quiet and _burst_snd <= 0.0:
		_burst_snd = 1.4
		_gun_fx.rpc(gun)
	_plasma.rpc(from, d.normalized() if kind == "plasma" else d, float(_g("bolt", 1.0)), kind, quiet)

## Every machine: the heavy gun's roar (one sound for the burst, not for every bolt).
@rpc("authority", "call_local", "reliable")
func _gun_fx(g: String) -> void:
	Game.play_at(mission, "alien_minigun", global_position + Vector3(0, 1.2, 0), 0)

@rpc("authority", "call_local", "reliable")
func _plasma(from: Vector3, dir: Vector3, power := 1.0, kind := "plasma", quiet := false) -> void:
	_fire_anim_t = FIRE_ANIM
	# the big ones (and the drones) fire the heavy plasma, ten takes so it never repeats
	if kind == "rocket":
		Game.play_at(mission, "missile_launch", from, 2)
	elif not quiet and R.get("laser", false) and kind == "plasma": Game.play_at(mission, "laser", from, -1)    # the Levit's laser rifle
	elif not quiet: Game.play_at(mission, ("plasma_cannon" if power >= 1.9 else "plasma_heavy" if power >= 1.3 else "plasma") if kind == "plasma" else ("acid_spit" if kind == "acid" else "lunge"), from, -2 + (power - 1.0) * 2.0)
	var bolt := Node3D.new()
	bolt.set_script(BoltScript)
	bolt.red = R.get("laser", false) and kind == "plasma"
	if R.has("bolt_col") and kind == "plasma":
		bolt.tint = R["bolt_col"]
	bolt.power = power
	bolt.kind = kind
	bolt.dir = dir
	bolt.shooter_pos = from
	bolt.mission = mission
	mission.add_child(bolt)
	bolt.global_position = from

# ---- Kněz: it reaches into the mercenaries' minds ------------------------------------------
## Works when the Kněz itself, or any other alien, can see the mercenary (it looks
## through their eyes), up to 35 m. Fear first; a weak mind can be taken over.
var _psi_spent := 0.0      # (výslech velitele: a strong push of the mind costs it - a few dull seconds after)
func _psi(delta: float) -> void:
	psi_cd -= delta
	_psi_spent = maxf(0.0, _psi_spent - delta)
	if psi_cd > 0 or mission.calm():
		return
	var best: Node = null
	for p in mission.players():
		if p.dead or p.downed or global_position.distance_to(p.global_position) > 35.0:
			continue
		# it feels minds nearby even through walls
		var seen := visible_to(p) or global_position.distance_to(p.global_position) < 18.0
		if not seen:
			for a in mission.aliens():
				if a != self and not a.dead and a.global_position.distance_to(p.global_position) < 25.0 and a.visible_to(p):
					seen = true
					break
		if seen and (best == null or p.stress < best.stress):
			best = p
	if best == null:
		psi_cd = 2.0
		# too far from their minds: creep closer (stays out of sight, 12-17 m)
		if state == S.LURK and _arrived() and activity == 0:
			var near: Node = null
			for p in mission.players():
				if not p.dead and (near == null or p.global_position.distance_to(global_position) < near.global_position.distance_to(global_position)):
					near = p
			if near and near.global_position.distance_to(global_position) > 28.0:
				stalk(near)
		return
	var lvl := int(R["psi"])
	psi_cd = (rng.randf_range(24.0, 34.0) if lvl == 1 else rng.randf_range(11.0, 17.0)) * (0.8 if Game.veteran() else 1.0)
	_psi_fx.rpc()
	if lvl == 1:
		_psi_spent = 3.0
	if lvl >= 2:
		# Mysloděj: lend strength to its own, tear at a mind, or take it over
		var r := rng.randf()
		var ally := _hurt_ally()
		if ally and r < (0.5 if Game.veteran() else 0.4):
			ally.psi_boost.rpc()
			return
		if r < 0.55:
			# it rouses its own: sharper eyes, steadier hands, fearless
			var n := 0
			for a in mission.aliens():
				if not a.dead and a != self and a.global_position.distance_to(global_position) < 28.0 and a.state == S.COMBAT:
					a._rally_t = 18.0
					a.react = minf(a.react, 0.2)
					n += 1
			if n > 0:
				return
		if r < 0.68 and _illusion_try(best):
			return
		if r < 0.8:
			best.psi_blast.rpc_id(best.get_multiplayer_authority(), rng.randf_range(9.0, 16.0))
			return
		# a stronger will: harder to resist
		best.psi_attack.rpc_id(best.get_multiplayer_authority(), 0.25 + rng.randf() * 0.75)
		_psi_held[String(best.name)] = mission.t + 5.0
		return
	if R.has("illusion") and rng.randf() < 0.5 and _illusion_try(best):
		return
	best.psi_attack.rpc_id(best.get_multiplayer_authority(), rng.randf())

## The illusion: a friend's face becomes one of theirs (the grey officer, the Mysloděj).
func _illusion_try(best: Node) -> bool:
	for o in mission.players():
		if o != best and not o.dead and o.global_position.distance_to(best.global_position) < 30.0:
			_tlog("illusion")
			best.psi_illusion.rpc_id(best.get_multiplayer_authority(), String(o.name), rng.randf_range(14.0, 22.0), rng.randf())
			return true
	return false

# ---- 0.57: the weaknesses from the autopsies, in play from the first night ---------------------
## Ještěřan (Pitva Ještěřana): eyes made for the dark - a flare close by, or a torch straight
## into its face at night, dazzles it for a few seconds (it stops, then fires wild).
var _blind_t := 0.0
var _blind_cd := 0.0
var _light_t := 0.0
func _light_tick(delta: float) -> void:
	_blind_t = maxf(0.0, _blind_t - delta)
	_blind_cd -= delta
	_light_t -= delta
	if _light_t > 0.0 or _blind_cd > 0.0 or dead or husk:
		return
	_light_t = 0.25
	var ep := eye()
	# the commander's goggles take most of it: only a flare right at its feet, and only briefly
	var gog := R.has("goggles")
	for f in get_tree().get_nodes_in_group("flare"):
		if f is Node3D and (f as Node3D).global_position.distance_to(ep) < (2.8 if gog else 6.5) and _los((f as Node3D).global_position + Vector3.UP * 0.2):
			_dazzle(1.2 if gog else 3.0)
			return
	if gog:
		return
	var dark: bool = mission.phase() != "den" or String(Net.mission_params.get("type", "")) in ["alienbase", "base", "mars"]
	if not dark:
		return
	var fwd := -global_transform.basis.z
	for p in mission.players():
		if p.dead or p.downed or not p.light_on:
			continue
		var pe: Vector3 = p.global_position + Vector3(0, 1.5 if not p.crouching else 1.0, 0)
		var to_me := ep - pe
		var d := to_me.length()
		if d > 15.0 or d < 0.5:
			continue
		var look: Vector3 = -(p as Node3D).global_transform.basis.z
		var h1 := Vector2(look.x, look.z).normalized()
		var h2 := Vector2(to_me.x, to_me.z).normalized()
		if h1.dot(h2) < 0.965 or absf(to_me.y) / d > 0.6:
			continue          # the beam is not on its face
		if fwd.dot(-to_me / d) < 0.25:
			continue          # it is not looking into it
		if _los(pe):
			_dazzle()
			return

func _dazzle(secs := 3.0) -> void:
	_blind_t = secs
	_blind_cd = 9.0
	_stagger = 0.9
	cloak = false
	_decloak_t = maxf(_decloak_t, 3.0)
	_tlog("dazzled")
	_dazzle_fx.rpc()

@rpc("authority", "call_local", "reliable")
func _dazzle_fx() -> void:
	Game.play_at(mission, "hiss", eye(), 2)

## Mysloděj (Pitva Mysloděje): a hard hit tears its concentration - whoever it holds is free,
## and it needs a while before it can reach into a mind again.
var _psi_held := {}        # player name -> until when its last psi strike holds him
func _psi_break() -> void:
	psi_cd = maxf(psi_cd, 9.0)
	for p in mission.players():
		if float(_psi_held.get(String(p.name), -1.0)) > mission.t and not p.dead:
			p.psi_free.rpc_id(p.get_multiplayer_authority())
	_psi_held.clear()
	_tlog("psi broken")

## Ohař (Pitva Ohaře) hunts by ear: a blast close by deafens it for a while. (melee_alien)
func blast_near(_at: Vector3) -> void:
	pass

## Mysloděj: hit, it is simply somewhere else - out of sight, a few dozen metres away.
var _tele_cd := 0.0
func _teleport_away(from: Vector3) -> bool:
	if _tele_cd > mission.t or dead or husk:
		return false
	var ss := get_world_3d().direct_space_state
	for i in 12:
		var a := rng.randf() * TAU
		var d := rng.randf_range(12.0, 22.0)
		var to: Vector3 = mission.free_spot(global_position + Vector3(sin(a) * d, 0.3, cos(a) * d))
		if to.distance_to(global_position) < 8.0:
			continue
		var q := PhysicsRayQueryParameters3D.create(from + Vector3(0, 1.4, 0), to + Vector3(0, 1.2, 0), Game.WORLD)
		if ss.intersect_ray(q).is_empty() and i < 9:
			continue        # (somewhere the shooter cannot see, if it can)
		_tele_cd = mission.t + rng.randf_range(7.0, 11.0)
		psi_cd = maxf(psi_cd, 4.0)     # the jump drains it (Pitva Mysloděje: a costly gift)
		_tlog("teleport")
		_teleport_fx.rpc(global_position, to)
		global_position = to
		goal = to
		last_seen = from
		return true
	return false

@rpc("authority", "call_local", "reliable")
func _teleport_fx(from: Vector3, to: Vector3) -> void:
	if anim and anim.has_animation("materialize"):
		# Ari's movements: where it was, it fades out (a copy of it, Vanish); here it takes shape
		_tele_anim_t = anim.get_animation("materialize").length
		anim.play("materialize", 0.0)
		var ghost := afk_scene(race)
		if ghost:
			mission.add_child(ghost)
			ghost.global_transform = Transform3D(body.global_transform.basis, from + Vector3(0, body.position.y + (body.get_child(0) as Node3D).position.y, 0))
			var gap: AnimationPlayer = ghost.find_child("AnimationPlayer", true, false)
			if gap and gap.has_animation("vanish"):
				gap.get_animation("vanish").loop_mode = Animation.LOOP_NONE
				gap.play("vanish")
				get_tree().create_timer(gap.get_animation("vanish").length).timeout.connect(ghost.queue_free)
			else:
				ghost.queue_free()
	for at in [from, to]:
		Game.play_at(mission, "psi", at + Vector3.UP, 0)
		var l := OmniLight3D.new()
		l.light_color = Color(0.7, 0.25, 1.0)
		l.light_energy = 5.0
		l.omni_range = 6.0
		mission.add_child(l)
		l.global_position = at + Vector3(0, 1.2, 0)
		var tw := l.create_tween()
		tw.tween_property(l, "light_energy", 0.0, 0.6)
		tw.tween_callback(l.queue_free)

## An ally worth strengthening: hurt, or fighting.
func _hurt_ally() -> Node:
	var best: Node = null
	for a in mission.aliens():
		if a == self or a.dead or a.global_position.distance_to(global_position) > 30.0:
			continue
		if a.hp < float(a.R["hp"]) * 0.75 or a.state == S.COMBAT:
			if best == null or a.hp < best.hp:
				best = a
	return best

## Mysloděj's gift: wounds close, the body moves faster for a while.
var _boost_t := 0.0
@rpc("authority", "call_local", "reliable")
func psi_boost() -> void:
	Game.play_at(mission, "psi", global_position, -2)
	mission.psi_glow(self)
	if multiplayer.is_server():
		hp = min(float(R["hp"]) * (1.25 if Game.veteran() else 1.0), hp + 45.0)
		if _boost_t <= 0:
			walk_spd *= 1.35
			run_spd *= 1.35
		_boost_t = 12.0
		get_tree().create_timer(12.0).timeout.connect(func():
			if is_inside_tree() and _boost_t > 0:
				_boost_t = 0.0
				walk_spd = float(R["walk"]) * (0.55 if suit_down else 1.0)
				run_spd = float(R["run"]) * (0.55 if suit_down else 1.0))

var armor_broken := false
@rpc("authority", "call_local", "reliable")
func _armor_break() -> void:
	armor_broken = true
	_tlog("armor broken")
	Game.play_at(mission, "zap", global_position + Vector3.UP * 1.5, 0)
	var sp := CPUParticles3D.new()
	sp.one_shot = true
	sp.amount = 40
	sp.lifetime = 0.7
	sp.explosiveness = 0.85
	sp.direction = Vector3.UP
	sp.spread = 90.0
	sp.initial_velocity_min = 2.0
	sp.initial_velocity_max = 4.5
	sp.gravity = Vector3(0, -7, 0)
	var qm := QuadMesh.new()
	qm.size = Vector2(0.03, 0.03)
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_color = Color(0.8, 0.45, 1.0)
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.material = mm
	sp.mesh = qm
	add_child(sp)
	sp.position = Vector3(0, float(R["h"]) * 0.7, 0)
	sp.emitting = true
	get_tree().create_timer(1.8).timeout.connect(sp.queue_free)

## The biomechanical suit gives out: sparks from the collar, the speed and the reflexes are gone.
var suit_down := false
@rpc("authority", "call_local", "reliable")
func _suit_fail() -> void:
	suit_down = true
	walk_spd *= 0.55
	run_spd *= 0.55
	Game.play_at(mission, "zap", global_position + Vector3.UP, -2)
	var sp := CPUParticles3D.new()
	sp.one_shot = true
	sp.amount = 24
	sp.lifetime = 0.5
	sp.explosiveness = 0.9
	sp.direction = Vector3.UP
	sp.spread = 70.0
	sp.initial_velocity_min = 1.5
	sp.initial_velocity_max = 3.5
	sp.gravity = Vector3(0, -6, 0)
	var qm := QuadMesh.new()
	qm.size = Vector2(0.025, 0.025)
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_color = Color(0.75, 0.95, 1.0)
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.material = mm
	sp.mesh = qm
	add_child(sp)
	sp.position = Vector3(0, float(R["h"]) * 0.72, 0)
	sp.emitting = true
	get_tree().create_timer(1.5).timeout.connect(sp.queue_free)

@rpc("authority", "call_local", "reliable")
func _psi_fx() -> void:
	striking = true
	if anim and anim.has_animation("attack"):
		anim.play("attack", 0.1)
	Game.play_at(mission, "psi", global_position, 2)
	get_tree().create_timer(1.0).timeout.connect(func(): striking = false)

# ---- what they do while nobody is looking -------------------------------------------------------
## Activities: the host picks one at the start (a grey working at a cow, two greys whispering,
## a guard at the ship's door, a Líhavec feeding...). Every machine lays a pose over the
## animation clip while the alien stands at it; any alarm and the job is dropped for good.
const ACTS := ["", "work", "work_high", "talk", "guard", "stare", "eat", "sniff"]
const HUMANOID := ["grey", "grey_velitel", "jestetan", "jestetan_velitel", "bijec", "bijec_velitel"]
var _rig: Skeleton3D
var _act_picked := false
var _act_spot := Vector3.INF
var _act_face := Vector3.ZERO
var _act_w := 0.0
var _act_t := 0.0
var _act_snd := 3.0
var _corpse: Node3D
var _look_t := 0.0

## Host: picks a job for this alien (returns false = none, it just lurks).
func _pick_activity() -> bool:
	if _rig == null or rng.randf() > 0.8:
		return false
	var me := global_position
	var spot := Vector3.INF
	var face := Vector3.ZERO
	var act := ""
	var base := race.trim_suffix("_velitel")
	match base:
		"grey":
			var cows: Array = mission.map.get("cows", [])
			var near_cow := Vector3.INF
			for c in cows:
				if me.distance_to(c) < 60.0 and (near_cow == Vector3.INF or me.distance_to(c) < me.distance_to(near_cow)):
					near_cow = c
			var partner: Node = null
			for a in mission.aliens():
				if a != self and not a.dead and a.race.trim_suffix("_velitel") == "grey" and a.global_position.distance_to(me) < 30.0 \
						and int(a.activity) in [0, ACTS.find("stare")]:
					partner = a
					break
			var roll := rng.randf()
			if near_cow != Vector3.INF and roll < 0.45:
				var away: Vector3 = (me - near_cow)
				away.y = 0
				spot = near_cow + (away.normalized() if away.length() > 0.1 else Vector3.FORWARD) * 1.2
				face = near_cow
				act = "work"
			elif partner and roll < 0.75:
				# two of them, close together, chittering in the dark
				var pp: Vector3 = partner.goal if partner.goal != Vector3.ZERO else partner.global_position
				var side := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
				spot = pp + side * 1.4
				face = pp
				act = "talk"
				partner.activity = ACTS.find("talk")
				partner._act_picked = true
				partner._act_spot = pp
				partner._act_face = spot
				partner._go(pp)
			elif mission.map.get("ufo", Vector3.ZERO) != Vector3.ZERO and me.distance_to(mission.map["ufo"]) < 45.0:
				var u: Vector3 = mission.map["ufo"]
				var dir := (me - u)
				dir.y = 0
				dir = dir.normalized() if dir.length() > 0.1 else Vector3.BACK
				spot = u + dir * 6.5
				face = u
				act = "work_high"
			elif mission.map.get("house", Vector3.ZERO) != Vector3.ZERO and me.distance_to(mission.map["house"]) < 50.0:
				spot = mission.map["house"] + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(3.5, 5.0))
				face = mission.map["house"]
				act = "stare"
			else:
				spot = me
				face = me + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1))
				act = "stare"
		"jestetan", "bijec":
			var door: Vector3 = mission.map.get("ufo_door", Vector3.ZERO)
			if door != Vector3.ZERO and me.distance_to(door) < 50.0:
				var u: Vector3 = mission.map.get("ufo", door)
				var out := (door - u)
				out.y = 0
				out = out.normalized() if out.length() > 0.1 else Vector3.BACK
				var side := out.cross(Vector3.UP) * rng.randf_range(-2.5, 2.5)
				spot = door + out * 2.5 + side
				face = spot + out * 5.0
			else:
				spot = goal if goal != Vector3.ZERO else me
				face = spot + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1))
			act = "guard"
		"lihnoun":
			spot = goal if goal != Vector3.ZERO else me
			face = spot + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
			act = "eat"
		"ohar":
			spot = goal if goal != Vector3.ZERO else me
			face = spot + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1))
			act = "sniff"
	if act == "":
		return false
	_act_spot = spot         # (no nav snap here: at spawn the navigation map is not ready yet)
	_act_face = face
	activity = ACTS.find(act)
	_go(_act_spot)
	return true

## Every machine: the pose of the job laid over the clip, plus a slow look around when idle.
func _activity_pose(delta: float) -> void:
	if _rig == null or _afk_native:
		return
	_act_t += delta
	var act: String = ACTS[clampi(activity, 0, ACTS.size() - 1)]
	if race == "zombie" and not striking:
		act = "sway"           # the infected never stand still, they rock
	var on := act != "" and not alert and _speed < 0.35 and not striking and not dead and not husk
	_act_w = move_toward(_act_w, 1.0 if on else 0.0, delta * (1.2 if on else 3.0))
	if on:
		_act_sounds(act, delta)
		if act == "eat" and _corpse == null:
			_lay_corpse()
	if _act_w > 0.01:
		var pose := pose_for(act if act != "" else "stare", _act_t + float(absi(hash(String(name))) % 100), float(R["h"]))
		pose[0] = Game.tweak_pose("act/" + act, pose[0])
		for bn in pose[0]:
			var i := _rig.find_bone(bn)
			if i < 0:
				continue
			var rest: Quaternion = _rig.get_bone_rest(i).basis.get_rotation_quaternion()
			var cur := _rig.get_bone_pose_rotation(i)
			_rig.set_bone_pose_rotation(i, cur.slerp(rest * Quaternion.from_euler(pose[0][bn]), _act_w))
		var ri := _rig.find_bone("root")
		if ri >= 0 and float(pose[1]) != 0.0:
			var cp := _rig.get_bone_pose_position(ri)
			_rig.set_bone_pose_position(ri, cp.lerp(_rig.get_bone_rest(ri).origin + Vector3(0, float(pose[1]), 0), _act_w))
	elif _speed < 0.35 and not alert and not dead and not husk:
		# no job: now and then the head turns slowly, looks, comes back
		_look_t += delta
		var hi := _rig.find_bone("head")
		if hi >= 0:
			var k := smoothstep(0.0, 1.0, sin(_look_t * 0.23) * 1.6 - 0.6)
			var turn := sin(_look_t * 0.61 + 1.3) * 0.55 * k
			_rig.set_bone_pose_rotation(hi, _rig.get_bone_pose_rotation(hi) * Quaternion.from_euler(Vector3(0, turn, 0)))
	else:
		_look_t = 0.0

## [bone -> euler, root drop] for a job at time t (Blender-style absolute bone rotations).
static func pose_for(act: String, t: float, height: float) -> Array:
	var s := height / 1.3
	match act:
		"work":
			return [{"spine": Vector3(-0.5, 0, 0), "neck": Vector3(0.1, 0, 0), "head": Vector3(0.35 + sin(t * 0.9) * 0.08, sin(t * 0.7) * 0.15, 0),
				"thigh.L": Vector3(1.2, 0, 0.1), "thigh.R": Vector3(0.4, 0, -0.1), "shin.L": Vector3(-1.6, 0, 0), "shin.R": Vector3(-1.9, 0, 0),
				"upperarm.L": Vector3(1.1 + sin(t * 2.1) * 0.12, 0, 0.15), "upperarm.R": Vector3(1.15, 0, -0.15),
				"forearm.L": Vector3(0.6 + sin(t * 3.3) * 0.25, 0, 0), "forearm.R": Vector3(0.8 + sin(t * 5.0 + 1.0) * 0.3, 0, 0),
				"hand.R": Vector3(sin(t * 6.0) * 0.35, 0, 0)}, -0.3 * s]
		"work_high":
			return [{"spine": Vector3(-0.05, 0, sin(t * 0.4) * 0.06), "head": Vector3(0.3, sin(t * 0.5) * 0.2, 0),
				"upperarm.L": Vector3(1.9, 0, 0.2), "upperarm.R": Vector3(1.7 + sin(t * 1.3) * 0.15, 0, -0.2),
				"forearm.L": Vector3(0.5 + sin(t * 4.0) * 0.25, 0, 0), "forearm.R": Vector3(0.7 + sin(t * 5.0 + 2.0) * 0.3, 0, 0),
				"hand.L": Vector3(sin(t * 7.0) * 0.3, 0, 0)}, 0.0]
		"talk":
			return [{"spine": Vector3(-0.08, sin(t * 0.5) * 0.12, 0), "head": Vector3(0.05 + sin(t * 0.9) * 0.1, sin(t * 0.6) * 0.25, sin(t * 1.3) * 0.25),
				"upperarm.R": Vector3(0.5 + sin(t * 1.1) * 0.3, 0, -0.25), "forearm.R": Vector3(1.2 + sin(t * 1.7) * 0.4, 0, 0),
				"hand.R": Vector3(sin(t * 2.3) * 0.4, 0, 0), "upperarm.L": Vector3(0.1, 0, 0.1), "forearm.L": Vector3(0.3, 0, 0)}, 0.0]
		"guard":
			return [{"spine": Vector3(-0.05, sin(t * 0.3) * 0.25, 0), "head": Vector3(0.0, sin(t * 0.35) * 0.6, 0),
				"upperarm.R": Vector3(0.6, 0, 0.1), "forearm.R": Vector3(0.9, 0, 0), "upperarm.L": Vector3(0.8, 0, -0.4), "forearm.L": Vector3(1.0, 0, 0),
				"thigh.L": Vector3(0.08, 0, 0.08), "thigh.R": Vector3(-0.05, 0, -0.08)}, 0.0]
		"stare":
			var tw := pow(maxf(0.0, sin(t * 0.9)), 30.0) * 0.5
			return [{"head": Vector3(0.05, tw * 0.6, 0.35 - tw), "neck": Vector3(0.05, 0, 0.05),
				"upperarm.L": Vector3(0.0, 0, 0.05), "upperarm.R": Vector3(0.0, 0, -0.05), "forearm.L": Vector3(0.15, 0, 0), "forearm.R": Vector3(0.15, 0, 0)}, 0.0]
		"eat":
			return [{"spine": Vector3(-1.25, 0, sin(t * 1.3) * 0.08), "neck": Vector3(0.6, 0, 0), "head": Vector3(1.0 + sin(t * 8.0) * 0.18, sin(t * 2.0) * 0.15, 0),
				"thigh.L": Vector3(1.45, 0, 0.35), "thigh.R": Vector3(1.45, 0, -0.35), "shin.L": Vector3(-1.85, 0, 0), "shin.R": Vector3(-1.85, 0, 0),
				"upperarm.L": Vector3(1.6 + sin(t * 6.0) * 0.2, 0, 0.2), "upperarm.R": Vector3(1.5 + sin(t * 6.0 + 1.5) * 0.2, 0, -0.2),
				"forearm.L": Vector3(0.4, 0, 0), "forearm.R": Vector3(0.6, 0, 0), "hand.L": Vector3(0.5, 0, 0), "hand.R": Vector3(0.5, 0, 0)}, -0.45]
		"sniff":
			return [{"neck": Vector3(-0.6, 0, 0), "head": Vector3(-0.4 + sin(t * 3.0) * 0.1, sin(t * 1.7) * 0.5, 0)}, 0.0]
		"sway":
			return [{"spine": Vector3(-0.25, 0, sin(t * 0.8) * 0.15), "head": Vector3(-0.5, sin(t * 0.5) * 0.2, sin(t * 0.7) * 0.3),
				"upperarm.L": Vector3(0.1 + sin(t * 0.8) * 0.1, 0, 0.05), "upperarm.R": Vector3(0.1 - sin(t * 0.8) * 0.1, 0, -0.05),
				"forearm.L": Vector3(0.3, 0, 0), "forearm.R": Vector3(0.3, 0, 0)}, 0.0]
	return [{}, 0.0]

## Little noises of the job (each machine plays its own - quiet, close up only).
func _act_sounds(act: String, delta: float) -> void:
	_act_snd -= delta
	if _act_snd > 0.0 or mission == null:
		return
	var p: Node3D = mission.local_player() if mission.has_method("local_player") else null
	if p == null or p.global_position.distance_to(global_position) > 30.0:
		_act_snd = 2.0
		return
	var at := global_position + Vector3.UP
	match act:
		"work": Game.play_at(mission, "clink" if randf() < 0.6 else "zap", at, -16); _act_snd = randf_range(1.5, 3.5)
		"work_high": Game.play_at(mission, "zap", at + Vector3.UP, -16); _act_snd = randf_range(2.0, 4.5)
		"talk": Game.play_at(mission, "grey_chitter" if race.begins_with("grey") else "alien", at, -14); _act_snd = randf_range(4.0, 8.0)
		"eat": Game.play_at(mission, "growl" if randf() < 0.3 else "skitter", at, -12); _act_snd = randf_range(2.0, 4.0)
		"sniff": Game.play_at(mission, "sniff", at, -12); _act_snd = randf_range(3.0, 6.0)
		"sway": Game.play_at(mission, "groan", at, -14); _act_snd = randf_range(6.0, 12.0)
		"stare": _act_snd = 10.0
		"guard": _act_snd = 10.0

## The Líhavec's meal: what is left of somebody, lying in front of it (every machine makes its own).
func _lay_corpse() -> void:
	_corpse = Game.model("civ_b" if absi(hash(String(name))) % 2 == 0 else "civ_a")
	mission.add_child(_corpse)
	var fwd := -global_transform.basis.z
	fwd.y = 0
	_corpse.global_position = global_position + fwd.normalized() * 0.9 + Vector3(0, 0.12, 0)
	_corpse.rotation = Vector3(-PI / 2, rotation.y + 1.2, 0)
	var ap: AnimationPlayer = _corpse.find_child("AnimationPlayer", true, false)
	if ap:
		ap.stop()
	var pool := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.75
	cm.bottom_radius = 0.75
	cm.height = 0.01
	pool.mesh = cm
	pool.material_override = Game.color_mat(Color(0.22, 0.02, 0.02))
	mission.add_child(pool)
	pool.global_position = _corpse.global_position - Vector3(0, 0.1, 0)
