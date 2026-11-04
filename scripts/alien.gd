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

## Race table. hp, speeds, armor (damage taken x), capsule, eye height, bolt power,
## shots per burst, accuracy (miss x), rate (time between shots x), glint (eye shine),
## weak (damage x by kind: plasma / explosion / bullet), psi (1 = officer, 2 = Mysloděj).
## Groups as in the old game: Šeďáci + Diskoll, Levité + Ohař, Ještěřani + Líhnouni,
## Bijci + Nádor + Ohnivec, Myslodějové + Kolos.
const RACES := {
	"grey": {"name": "Šeďák", "hp": 70.0, "walk": 2.0, "run": 4.9, "tac": "grey", "armor": 1.0, "model": "grey", "h": 1.3, "r": 0.3, "eye": 1.15,
		"bolt": 1.0, "shots": [1, 2], "miss": 0.9, "glint": [Vector3(0, 1.22, -0.215), Color(0.3, 1.0, 0.4)], "hide": 1.2},
	"grey_velitel": {"name": "Šeďák velitel", "hp": 95.0, "walk": 2.0, "run": 4.9, "tac": "grey", "armor": 1.0, "model": "grey_velitel", "h": 1.35, "r": 0.3, "eye": 1.2,
		"bolt": 1.0, "shots": [1, 2], "miss": 0.9, "glint": [Vector3(0, 1.26, -0.22), Color(0.8, 0.45, 1.0)], "hide": 1.3, "psi": 1, "illusion": true},
	"diskoll": {"name": "Diskoll", "hp": 110.0, "walk": 2.8, "run": 5.5, "armor": 0.6, "model": "diskoll", "h": 0.5, "r": 0.7, "eye": 1.5,
		"bolt": 0.7, "shots": [4, 5], "miss": 0.55, "rate": 0.3, "hover": 1.45, "explode": [3.5, 40.0], "hide": 0.2,
		"weak": {"plasma": 2.0, "laser": 1.8, "explosion": 1.5}},
	"levit": {"name": "Levit", "hp": 70.0, "tac": "levit", "walk": 2.4, "run": 5.2, "armor": 1.0, "model": "levit", "h": 0.8, "r": 0.35, "eye": 1.75,
		"bolt": 1.0, "shots": [1, 3], "miss": 1.0, "hover": 1.1, "hide": 0.7},
	"levit_velitel": {"name": "Levit velitel", "hp": 115.0, "tac": "levit", "walk": 3.0, "run": 6.6, "armor": 0.8, "model": "levit", "scale": 1.15, "h": 0.9, "r": 0.38, "eye": 1.95,
		"bolt": 1.1, "shots": [2, 3], "miss": 0.8, "hover": 1.25, "hide": 0.4, "jet": 1.9, "rocket": true},
	"ohar": {"name": "Ohař", "hp": 160.0, "walk": 2.2, "run": 6.8, "armor": 0.8, "model": "ohar", "h": 1.1, "r": 0.5, "eye": 1.0,
		"melee": [28.0, 40.0], "reach": 2.2, "strike_cd": 1.2, "dumb": true, "pounce": [11.0, 1.75]},
	"jestetan": {"name": "Ještěřan", "hp": 140.0, "walk": 1.2, "run": 2.6, "armor": 0.7, "model": "jestetan", "h": 2.1, "r": 0.38, "eye": 2.0,
		"bolt": 1.2, "shots": [1, 2], "miss": 0.95, "hide": 0.8, "tac": "hunter", "guns": ["minigun", "mg", "cannon", "rifle"], "nades": true, "traps": 2, "cloak": true,
		"glint": [Vector3(0, 2.02, -0.3), Color(1.0, 0.6, 0.1)]},
	"jestetan_velitel": {"name": "Ještěřan velitel", "hp": 185.0, "walk": 1.2, "run": 2.6, "armor": 0.5, "model": "jestetan_velitel", "h": 2.1, "r": 0.4, "eye": 2.0,
		"bolt": 1.3, "shots": [2, 3], "miss": 0.85, "hide": 0.8, "tac": "hunter", "guns": ["minigun", "cannon", "mg"], "nades": true, "traps": 3, "cloak": true, "grab": true,
		"glint": [Vector3(0, 2.02, -0.3), Color(1.0, 0.45, 0.1)]},
	"lihnoun": {"name": "Líhnoun", "hp": 110.0, "walk": 2.2, "run": 6.6, "armor": 0.8, "model": "lihnoun", "h": 1.4, "r": 0.3, "eye": 1.5,
		"melee": [38.0, 52.0], "reach": 1.8, "strike_cd": 0.85, "implant": true, "pounce": [9.0, 1.45], "weak": {"plasma": 1.6}},
	"zombie": {"name": "Nakažený", "hp": 65.0, "walk": 1.0, "run": 1.7, "armor": 1.0, "model": "zombie", "h": 1.6, "r": 0.3, "eye": 1.6,
		"melee": [14.0, 22.0], "reach": 1.5, "strike_cd": 1.6},
	"bijec": {"name": "Bijec", "hp": 160.0, "walk": 1.6, "run": 3.6, "armor": 0.75, "model": "bijec", "h": 2.1, "r": 0.42, "eye": 1.96,
		"bolt": 1.5, "shots": [2, 3], "miss": 0.8, "hide": 0.5, "tac": "soldier", "guns": ["rifle", "mg", "minigun", "cannon"], "nades": true},
	"bijec_velitel": {"name": "Bijec velitel", "hp": 340.0, "walk": 1.6, "run": 3.6, "armor": 0.5, "model": "bijec_velitel", "h": 2.1, "r": 0.42, "eye": 1.96,
		"bolt": 1.5, "shots": [2, 4], "miss": 0.5, "hide": 0.4, "tac": "soldier", "guns": ["hminigun"], "nades": true, "heal": 3.0, "warcry": true},
	"nador": {"name": "Nádor", "hp": 55.0, "walk": 1.0, "run": 1.9, "armor": 1.0, "model": "nador", "h": 0.5, "r": 0.42, "eye": 1.0,
		"spit": "acid", "bolt": 1.1, "shots": [1, 1], "miss": 1.1, "rate": 1.6, "hover": 0.85, "hide": 0.3, "regen": true, "tac": "brute"},
	"ohnivec": {"name": "Ohnivec", "hp": 170.0, "walk": 0.9, "run": 1.6, "armor": 0.2, "model": "ohnivec", "h": 0.7, "r": 0.6, "eye": 0.6,
		"spit": "lava", "bolt": 1.4, "shots": [1, 1], "miss": 1.0, "rate": 2.2, "hide": 0.0, "touch": 22.0, "tac": "brute", "heal": 4.0,
		"weak": {"explosion": 6.0}},
	"myslodej": {"name": "Mysloděj", "hp": 140.0, "walk": 1.3, "run": 2.8, "armor": 0.8, "model": "myslodej", "h": 1.6, "r": 0.4, "eye": 1.55,
		"bolt": 0.75, "shots": [1, 2], "miss": 0.8, "hover": 0.35, "hide": 1.4, "psi": 2, "tac": "psi"},
	"mozek": {"name": "Velký mozek", "hp": 2200.0, "walk": 0.0, "run": 0.0, "armor": 0.6, "model": "mozek", "h": 2.6, "r": 1.6, "eye": 1.3,
		"hide": 0.0, "psi": 3, "weak": {"explosion": 1.4, "laser": 1.3, "plasma": 1.2}},
	"pylon": {"name": "Pylon štítu", "hp": 260.0, "walk": 0.0, "run": 0.0, "armor": 0.7, "model": "pylon", "h": 2.9, "r": 0.6, "eye": 2.8,
		"hide": 0.0, "explode": [3.0, 25.0], "weak": {"explosion": 2.0}},
	"kolos": {"name": "Kolos", "hp": 320.0, "walk": 1.6, "run": 3.2, "armor": 0.45, "model": "kolos", "h": 2.4, "r": 0.9, "eye": 2.0,
		"bolt": 1.3, "shots": [2, 3], "miss": 0.8, "explode": [6.0, 90.0], "hide": 0.0, "tac": "brute", "weak": {"explosion": 1.3}},
}

## Heavy weapons of the soldier races (each one carries one of its race's "guns").
## Override shots / rate (time between shots x) / bolt (power) / miss.
const GUNS := {
	"rifle": {},
	"mg": {"shots": [5, 8], "rate": 0.24, "bolt": 0.8, "miss": 1.25, "name": "kulomet"},
	"minigun": {"shots": [12, 18], "rate": 0.1, "bolt": 0.55, "miss": 1.55, "name": "minigun"},
	"cannon": {"shots": [1, 1], "rate": 2.4, "bolt": 2.1, "miss": 0.8, "name": "plazmové dělo"},
	"hminigun": {"shots": [16, 24], "rate": 0.09, "bolt": 0.85, "miss": 1.0, "name": "těžký plazmový minigun"},
}

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
	var m := Game.model(String(R["model"]))
	body.add_child(m)
	if R.has("scale"):
		m.scale *= float(R["scale"])
	anim = m.find_child("AnimationPlayer", true, false)
	if anim:
		for an in anim.get_animation_list():
			anim.get_animation(an).loop_mode = Animation.LOOP_LINEAR
		anim.play("idle")
		# advanced by hand, so the activity poses can be laid over the clip each frame
		anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		_rig = m.find_child("Skeleton3D", true, false)
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
		m.position.y = float(R["hover"])
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
	if multiplayer.is_server() and not _traps.is_empty():
		_traps_tick(delta)
	if dead:
		_death_anim(delta)
		if multiplayer.is_server() and (airborne or flying):
			# shot out of the air / off the roof: it drops
			flying = false
			_jet.clear()
			if not is_on_floor():
				velocity = Vector3(0, velocity.y - GRAVITY * delta, 0)
				move_and_slide()
			else:
				airborne = false
		return
	if husk:
		# fallen, twitching on the ground
		bob_t += delta * 0.4
		body.position.y = lerp(body.position.y, -float(R.get("hover", 0.0)) * 0.75, delta * 4.0)
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

func _animate(delta: float) -> void:
	_flinch_tick(delta)
	if anim == null:
		return
	var moved := global_position - _last_anim_pos
	moved.y = 0
	_last_anim_pos = global_position
	_speed = lerp(_speed, moved.length() / max(delta, 0.001), 0.2)
	var want := "idle"
	if striking and anim.has_animation("attack"):
		want = "attack"
	elif lurking and _speed < 0.5:
		want = "lurk"
	elif _speed > 2.4:
		want = "run"
	elif _speed > 0.3:
		want = "walk"
	elif alert:
		want = "aim"
	if anim.current_animation != want:
		anim.play(want, 0.25)
	anim.speed_scale = clamp(_speed / walk_spd, 0.7, 1.6) if want == "walk" else (clamp(_speed / run_spd * 1.2, 0.7, 1.4) if want == "run" else 1.0)
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
	if anim:
		anim.pause()
	var hov := float(R.get("hover", 0.0))
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
	if hov > 0.0:
		# floaters drop out of the air and land on their side
		_fall = Vector3(0, 0, 0.35 if dir % 2 == 0 else -0.35)
		_rest_y = -bb.position.y + 0.02 - 0.05
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

func _death_anim(delta: float) -> void:
	if _death_t < 0.0:
		_death_setup()
	_death_t += delta
	var hov := float(R.get("hover", 0.0))
	var t := _death_t
	if hov > 0.0:
		# drops like a stone, bounces once
		var k := clampf(t / 0.55, 0.0, 1.0)
		body.position.y = lerpf(0.0, _rest_y - hov, k * k) + (sin(clampf((t - 0.55) / 0.3, 0.0, 1.0) * PI) * 0.12 if t > 0.55 else 0.0)
		body.rotation.z = lerpf(0.0, _fall.z, clampf(t / 0.8, 0.0, 1.0))
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
		var base := Vector3(-0.55, 1.05 + sin(bob_t * 1.3) * 0.08, -0.15)
		w.position = w.position.lerp(base, delta * 4.0)
		if alert and is_instance_valid(target):
			var to: Vector3 = target.global_position + Vector3(0, 1.2, 0)
			w.look_at(to, Vector3.UP)
			w.rotate_object_local(Vector3.UP, PI)
		else:
			w.rotation = w.rotation.lerp(Vector3(0, sin(bob_t * 0.7) * 0.3, 0), delta * 2.0)
	var body_mesh := _part("Body")
	if body_mesh and R.get("spit", "") == "acid":
		var k2 := 1.0 + sin(bob_t * 3.3) * 0.06 + sin(bob_t * 7.1) * 0.03
		body_mesh.scale = Vector3(k2, 2.0 - k2, k2)

## Where its shots come from.
func _muzzle_pos() -> Vector3:
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
	if d > p.visibility_range() and d > 4.0:
		return false
	var fwd := -global_transform.basis.z
	if d > 4.0 and fwd.dot((head_pos - eye()).normalized()) < SIGHT_ANGLE and not alert:
		return false
	if mission.smoke_blocks(eye(), head_pos):
		return false
	return _los(head_pos)

func hear(pos: Vector3, radius: float) -> void:
	if dead or state == S.DRAG:
		return
	if mission.calm():
		radius *= 0.5
	if global_position.distance_to(pos) > radius:
		return
	if radius >= 25.0 and multiplayer.is_server() and global_position.distance_to(pos) < 130.0:
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
func taken(dmg: float) -> float:
	var kind: String = mission.hit_kind if mission else ""
	var w: Dictionary = R.get("weak", {})
	var k := float(w.get(kind, 1.0))
	var base := race.trim_suffix("_velitel")
	if Campaign.AUTOPSY_BONUS.has(base) and Game.has_research(Campaign.AUTOPSY_BONUS[base]):
		k *= 1.2           # the laboratory found where it is soft
	if kind == "explosion" and k > 1.0:
		return dmg * k       # armour does not stop a blast from tearing it apart
	return dmg * float(R["armor"]) * k

func damage(dmg: float, from: Vector3, by: Node) -> void:
	if dead:
		return
	# from the dark, unseen: an ambush hurts twice as much
	if state != S.COMBAT and state != S.DRAG and by and by.has_method("is_player") and float(sus.get(String(by.name), 0.0)) < 1.0:
		dmg *= 2.0
		_ambush_note.rpc_id(by.get_multiplayer_authority(), String(by.name))
	hp -= taken(dmg)
	alert = true
	_hit_t = mission.t
	_decloak_t = maxf(_decloak_t, 1.2)
	var shooter_known := by != null and by.has_method("is_player")
	if shooter_known:
		# it knows where that came from - and so do the others nearby
		_know(by, 15.0)
		target = by
		_warn_squad(by, 40.0)
	if dragging:
		_release()
	if hp <= 0 and R.has("regen") and not husk:
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
		if by and by.has_method("is_player"):
			_credit.rpc_id(by.get_multiplayer_authority(), by.name)
			_warn_squad(by, 30.0)     # one of theirs falls: the rest come for the killer
		return
	# hurt: break contact at once and come back from somewhere else
	if hp < float(R["hp"]) * 0.45:
		bleeding = true
	_flinch.rpc(from)
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
func stun(amount: float, from: Vector3, by: Node) -> void:
	if dead:
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
		mission.hud.message("Omráčení %d %%" % pct, 1.0)

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
	mission.drop_item({"id": "a_pack", "what": f[0], "value": randi_range(int(f[1]), int(f[2]))}, global_position - global_transform.basis.x * 0.6)

## Host: the dead alien's gun lies next to it - anyone can pick it up (E).
func _drop_gun() -> void:
	var w: String = Campaign.RACE_WEAPON.get(race, "")
	if w == "" or not Game.ITEMS.has(w) or not multiplayer.is_server():
		return
	var r: Dictionary = Game.ITEMS[w]
	var cells := randi_range(1, int(r["cells"]))
	mission.drop_item({"id": w, "loaded": randi_range(int(r["cap"]) / 3, int(r["cap"])), "cells": cells}, global_position + global_transform.basis.x * 0.6)

@rpc("authority", "call_local", "reliable")
func _ambush_note(player_name: String) -> void:
	var p: Node = mission.actors.get_node_or_null(player_name)
	if p and p.is_multiplayer_authority():
		mission.hud.message("Útok ze zálohy - dvojnásobné zranění.", 2.0)

@rpc("authority", "call_local", "reliable")
func _die() -> void:
	dead = true
	lurking = false
	collision_layer = 0
	Game.play_at(mission, "death", global_position, -4)

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
		_jet_to(p)          # in a fight it does not walk: it flies
		return
	goal = p
	agent.target_position = p

func _snap(p: Vector3) -> Vector3:
	return NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, p)

## Stealth: an alien that is not yet fighting does not spot you at once. While it can see
## you, suspicion grows - fast when you are close, lit, standing or running; slowly when
## you crouch or crawl in the dark and keep still. Half full: it turns and comes to look.
## Full: it has you. Hidden again, it fades.
var sus := {}          # player node name -> 0..1
var _think_dt := 0.016

func _sus_rate(p: Node) -> float:
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
			var score := global_position.distance_to(p.global_position)
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
		react = rng.randf_range(0.9, 1.6) * (0.65 if Game.veteran() else (1.4 if Game.easy() else 1.0)) * (0.7 if _rally_t > 0 else 1.0)   # the moment of surprise
		hide_t = rng.randf_range(2.0, 4.0)
	alert = true
	lurking = false
	unseen_t = 0.0

var regen_t := 0.0
var _touch_t := 0.0
@rpc("authority", "call_local", "reliable")
func _husk_fx(down: bool) -> void:
	Game.play_at(mission, "burst" if down else "groan", global_position, -4)
	if not down and mission.local_player() and mission.local_player().global_position.distance_to(global_position) < 25.0:
		mission.hud.message("Něco se tam zase zvedá...", 3.0)

func _think(delta: float) -> void:
	_think_dt = delta
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
					p.hurt.rpc_id(p.get_multiplayer_authority(), float(R["touch"]) * (1.3 if Game.veteran() else 1.0), global_position)
	if R.has("heal") and hp < float(R["hp"]) and mission.t - _hit_t > 3.0:
		# Ohnivec: the molten core seals its wounds
		hp = minf(float(R["hp"]), hp + float(R["heal"]) * delta)
	if R.has("psi"):
		_psi(delta)
	if state == S.DRAG:
		_drag(delta)
		return
	var seen := _find_target()
	if seen:
		target = seen
		last_seen = seen.global_position
		unseen_t = 0.0
		if state != S.COMBAT:
			_enter_combat(seen)
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
		S.STALK:
			_walk(walk_spd * 1.3, delta)
			if _arrived():
				# close enough - wait in the dark, then come from the side
				_enter_combat(null)
				phase = "hide"
				hide_t = rng.randf_range(4.0, 9.0)
				lurking = true
		S.SEARCH:
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
				if R.has("nades") and _nade_cd <= 0 and dist > 7.0 and dist < 26.0 and rng.randf() < (0.75 if _habit(seen, "pancir") else 0.4):
					_throw_nade(seen.global_position)
				else:
					_fire(seen)
				mission.combat_t = mission.t
				shots_left -= 1
				shoot_cd = rng.randf_range(0.7, 1.1) * float(_g("rate", 1.0))
				if shots_left <= 0:
					_after_burst()
		"move":
			lurking = false
			_walk(run_spd, delta)
			if _arrived():
				phase = "hide"
				hide_t = rng.randf_range(2.5, 6.0) * float(R["hide"])
				if tac == "levit":
					hide_t = rng.randf_range(0.6, 1.6)
				if R.has("traps"):
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
			if hide_t <= 0:
				_next_move()
		"grab":
			_grab(delta)
		"flank":
			lurking = false
			_walk(walk_spd * 1.4 if tac != "grey" else run_spd * 0.85, delta)
			if _arrived():
				phase = "hide"
				hide_t = rng.randf_range(3.0, 7.0) * float(R["hide"])
				if tac == "levit":
					hide_t = rng.randf_range(0.8, 2.0)

## A burst is over: away from where it was seen.
func _after_burst() -> void:
	if _can_grab() and rng.randf() < 0.5:
		_tlog("grab start")
		phase = "grab"
		_brute_repath = 0.0
		return
	if tac == "levit" and rng.randf() < 0.8 and _levit_hop(last_seen, false):
		phase = "move"
		return
	_relocate(last_seen)
	phase = "move"

## Done hiding: where next.
func _next_move() -> void:
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
	if dist > 28.0 and _advance(last_seen):
		return
	if not R.has("hover") and rng.randf() < (0.55 if tac in ["soldier", "hunter"] else 0.4):
		var w := _window_spot(last_seen)
		if w != Vector3.INF:
			_tlog("window")
			_go(w)
			return
	_flank()

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
	_go(_snap(p))

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

@rpc("authority", "call_local", "reliable")
func _warcry_fx() -> void:
	var at := global_position + Vector3(0, 2.0, 0)
	Game.play_at(mission, "roar", at, 6)
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
func _can_grab() -> bool:
	return R.has("grab") and can_cloak and _grab_cd <= 0.0 and is_instance_valid(target) and target.has_method("is_player") \
			and not target.downed and not target.dead and global_position.distance_to(target.global_position) < 35.0

func _grab(delta: float) -> void:
	lurking = false
	if not is_instance_valid(target) or target.dead or target.downed or not can_cloak:
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
	if not cloak and dd < 6.0:
		velocity.x = 0; velocity.z = 0      # let the cloak settle before the last steps
		return
	_walk(run_spd * (0.85 if dd > 6.0 else 1.25), delta)
	if dd < 1.7:
		_face(tp, delta * 3.0)
		_tlog("grab KO")
		target.knock_out.rpc_id(target.get_multiplayer_authority())
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
	Game.play_at(mission, "baton_hit", at, 2)

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
			shoot_cd = rng.randf_range(0.7, 1.1) * float(_g("rate", 1.0))
	elif _arrived():
		velocity.x = 0; velocity.z = 0
		rotation.y += delta * 0.7      # where did it go

# ---- Levit: jets ------------------------------------------------------------------------------
var airborne := false     # host: hovering where there is no floor (roof, window)
var _jet: Array = []
var _jet_perch := false
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
	_jet_to(best, entry, true)
	return true

func _jet_to(dest: Vector3, entry := Vector3.INF, perch := false) -> void:
	var from := global_position
	var last := entry if entry != Vector3.INF else dest
	var cruise := maxf(maxf(from.y, last.y) + 4.0, 8.5)
	_jet = [Vector3(from.x, cruise, from.z), Vector3(last.x, cruise, last.z)]
	if entry != Vector3.INF:
		_jet.append(entry)
	_jet.append(dest)
	_jet_perch = perch
	_tlog("jet %s perch=%s h=%.1f" % ["window" if entry != Vector3.INF else "", perch, dest.y])
	flying = true
	airborne = true
	lurking = false
	goal = dest
	if not perch:
		agent.target_position = dest

## Host: follows the flight path (straight through the air - nothing up there to hit).
func _fly(delta: float) -> void:
	if _jet.is_empty():
		flying = false
		airborne = _jet_perch
		return
	var tgt: Vector3 = _jet[0]
	var flat := Vector2(tgt.x - global_position.x, tgt.z - global_position.z).length()
	var spd := (12.0 if flat > 0.3 else 8.0) * float(R.get("jet", 1.0))
	global_position = global_position.move_toward(tgt, spd * delta)
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
			_jet_snd.stream = Game.loop_stream("rocket_fly")
			_jet_snd.unit_size = 5.0
			_jet_snd.max_distance = 60.0
			_jet_snd.volume_db = -6.0
			_jet_snd.pitch_scale = 1.4
			_jet_snd.bus = "SFX"
			add_child(_jet_snd)
			_jet_light = OmniLight3D.new()
			_jet_light.light_color = Color(1.0, 0.25, 0.15) if race == "levit_velitel" else Color(0.45, 0.6, 1.0)
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
	_nade_cd = rng.randf_range(14.0, 24.0) * (0.75 if Game.veteran() else 1.0)
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
			Game.play_at(mission, "ping", rb.global_position, 2)
			l.light_energy = 4.0
			var me: Node = mission.local_player()
			if k == 0 and me and not me.dead and me.global_position.distance_to(rb.global_position) < 9.0:
				mission.hud.message("GRANÁT! Pryč od toho!", 1.6))
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
	if traps_left <= 0 or rng.randf() > chance or airborne:
		return
	var p := global_position
	for a in mission.aliens():
		for t in a._traps:
			if (t[0] as Vector3).distance_to(p) < 7.0:
				return
	traps_left -= 1
	_trap_n += 1
	var id := "%s_%d" % [name, _trap_n]
	_traps.append([p, id])
	_tlog("trap")
	_trap_put.rpc(p, id)

@rpc("authority", "call_local", "reliable")
func _trap_put(p: Vector3, id: String) -> void:
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
	var dm := Game.color_mat(Color(1.0, 0.15, 0.05), true)
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
				_trap_go.rpc(String(_traps[i][1]), tp)
				_traps.remove_at(i)
				mission.noise(tp, 30.0)
				# the hunters know at once where the prey is
				for a in mission.aliens():
					if not a.dead and a.global_position.distance_to(tp) < 55.0 and not a.R.get("dumb", false):
						a._know(p, 12.0)
						if a.state != S.COMBAT and a.state != S.DRAG:
							a.stalk(p)
				break

@rpc("authority", "call_local", "reliable")
func _trap_go(id: String, p: Vector3) -> void:
	var n := mission.get_node_or_null("Trap_" + id)
	if n:
		n.queue_free()
	Game.play_at(mission, "zap", p, 6)
	Game.play_at(mission, "burst", p, 2)
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
				mission.hud.message("Oslepující záblesk! Past!", 2.5)

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

func _cloak_tick(delta: float) -> void:
	if not R.has("cloak"):
		return
	var want := 1.0 if cloak and not dead else 0.0
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
	if R.has("rocket") and _rocket_cd <= 0.0 and dist > 7.0:
		# Levit officer: a rocket at his feet
		_rocket_cd = rng.randf_range(6.0, 10.0)
		var rf := _muzzle_pos()
		var rt: Vector3 = p.global_position + Vector3(0, 0.2, 0) + Vector3(p.velocity.x, 0, p.velocity.z) * (dist / 24.0) * 0.8
		rt += Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
		_tlog("rocket")
		_plasma.rpc(rf, (rt - rf).normalized(), 1.0, "rocket")
		return
	var miss := (0.45 + dist * 0.032) * float(_g("miss", 1.0))
	if Game.veteran(): miss *= 0.8
	elif Game.easy(): miss *= 1.4
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
	Game.play_at(mission, "minigun_fire", global_position + Vector3(0, 1.2, 0), 0)

@rpc("authority", "call_local", "reliable")
func _plasma(from: Vector3, dir: Vector3, power := 1.0, kind := "plasma", quiet := false) -> void:
	# the big ones (and the drones) fire the heavy plasma, ten takes so it never repeats
	if kind == "rocket":
		Game.play_at(mission, "missile_launch", from, 2)
	elif not quiet: Game.play_at(mission, ("plasma_heavy" if power >= 1.3 else "plasma") if kind == "plasma" else ("acid_spit" if kind == "acid" else "lunge"), from, -2 + (power - 1.0) * 2.0)
	var bolt := Node3D.new()
	bolt.set_script(BoltScript)
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
func _psi(delta: float) -> void:
	psi_cd -= delta
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
		if r < 0.78:
			best.psi_blast.rpc_id(best.get_multiplayer_authority(), rng.randf_range(9.0, 16.0))
			return
		# a stronger will: harder to resist
		best.psi_attack.rpc_id(best.get_multiplayer_authority(), 0.25 + rng.randf() * 0.75)
		return
	if R.has("illusion") and rng.randf() < 0.5:
		# the grey officer's trick: a friend's face becomes one of theirs
		for o in mission.players():
			if o != best and not o.dead and o.global_position.distance_to(best.global_position) < 30.0:
				_tlog("illusion")
				best.psi_illusion.rpc_id(best.get_multiplayer_authority(), String(o.name), rng.randf_range(14.0, 22.0), rng.randf())
				return
	best.psi_attack.rpc_id(best.get_multiplayer_authority(), rng.randf())

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
				walk_spd = float(R["walk"])
				run_spd = float(R["run"]))

@rpc("authority", "call_local", "reliable")
func _psi_fx() -> void:
	striking = true
	if anim and anim.has_animation("attack"):
		anim.play("attack", 0.1)
	Game.play_at(mission, "psi", global_position, 2)
	get_tree().create_timer(1.0).timeout.connect(func(): striking = false)

# ---- what they do while nobody is looking -------------------------------------------------------
## Activities: the host picks one at the start (a grey working at a cow, two greys whispering,
## a guard at the ship's door, a Líhnoun feeding...). Every machine lays a pose over the
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
	if _rig == null:
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
		"talk": Game.play_at(mission, "alien", at, -14); _act_snd = randf_range(4.0, 8.0)
		"eat": Game.play_at(mission, "growl" if randf() < 0.3 else "skitter", at, -12); _act_snd = randf_range(2.0, 4.0)
		"sniff": Game.play_at(mission, "sniff", at, -12); _act_snd = randf_range(3.0, 6.0)
		"sway": Game.play_at(mission, "groan", at, -14); _act_snd = randf_range(6.0, 12.0)
		"stare": _act_snd = 10.0
		"guard": _act_snd = 10.0

## The Líhnoun's meal: what is left of somebody, lying in front of it (every machine makes its own).
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
