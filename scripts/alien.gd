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
	"grey": {"name": "Šeďák", "hp": 70.0, "walk": 1.7, "run": 4.0, "armor": 1.0, "model": "grey", "h": 1.3, "r": 0.3, "eye": 1.15,
		"bolt": 1.0, "shots": [1, 2], "miss": 1.0, "glint": [Vector3(0, 1.22, -0.215), Color(0.3, 1.0, 0.4)], "hide": 1.0},
	"grey_velitel": {"name": "Šeďák velitel", "hp": 95.0, "walk": 1.7, "run": 4.0, "armor": 1.0, "model": "grey_velitel", "h": 1.35, "r": 0.3, "eye": 1.2,
		"bolt": 1.0, "shots": [1, 2], "miss": 0.9, "glint": [Vector3(0, 1.26, -0.22), Color(0.8, 0.45, 1.0)], "hide": 1.3, "psi": 1},
	"diskoll": {"name": "Diskoll", "hp": 110.0, "walk": 2.8, "run": 5.5, "armor": 0.6, "model": "diskoll", "h": 0.5, "r": 0.7, "eye": 1.5,
		"bolt": 0.7, "shots": [4, 5], "miss": 0.55, "rate": 0.3, "hover": 1.45, "explode": [3.5, 40.0], "hide": 0.2,
		"weak": {"plasma": 2.0, "laser": 1.8, "explosion": 1.5}},
	"levit": {"name": "Levit", "hp": 70.0, "walk": 2.4, "run": 5.2, "armor": 1.0, "model": "levit", "h": 0.8, "r": 0.35, "eye": 1.75,
		"bolt": 1.0, "shots": [1, 3], "miss": 1.0, "hover": 1.1, "hide": 0.7},
	"ohar": {"name": "Ohař", "hp": 160.0, "walk": 2.2, "run": 6.8, "armor": 0.8, "model": "ohar", "h": 1.1, "r": 0.5, "eye": 1.0,
		"melee": [28.0, 40.0], "reach": 2.2, "strike_cd": 1.2, "dumb": true},
	"jestetan": {"name": "Ještěřan", "hp": 140.0, "walk": 1.2, "run": 2.6, "armor": 0.7, "model": "jestetan", "h": 2.1, "r": 0.38, "eye": 2.0,
		"bolt": 1.2, "shots": [1, 2], "miss": 0.95, "hide": 0.8},
	"jestetan_velitel": {"name": "Ještěřan velitel", "hp": 185.0, "walk": 1.2, "run": 2.6, "armor": 0.5, "model": "jestetan_velitel", "h": 2.1, "r": 0.4, "eye": 2.0,
		"bolt": 1.3, "shots": [2, 3], "miss": 0.85, "hide": 0.8},
	"lihnoun": {"name": "Líhnoun", "hp": 110.0, "walk": 2.2, "run": 6.6, "armor": 0.8, "model": "lihnoun", "h": 1.4, "r": 0.3, "eye": 1.5,
		"melee": [38.0, 52.0], "reach": 1.8, "strike_cd": 0.85, "implant": true},
	"zombie": {"name": "Nakažený", "hp": 65.0, "walk": 1.0, "run": 1.7, "armor": 1.0, "model": "zombie", "h": 1.6, "r": 0.3, "eye": 1.6,
		"melee": [14.0, 22.0], "reach": 1.5, "strike_cd": 1.6},
	"bijec": {"name": "Bijec", "hp": 160.0, "walk": 1.6, "run": 3.6, "armor": 0.75, "model": "bijec", "h": 2.1, "r": 0.42, "eye": 1.96,
		"bolt": 1.5, "shots": [2, 3], "miss": 0.8, "hide": 0.5},
	"bijec_velitel": {"name": "Bijec velitel", "hp": 215.0, "walk": 1.6, "run": 3.6, "armor": 0.65, "model": "bijec_velitel", "h": 2.1, "r": 0.42, "eye": 1.96,
		"bolt": 1.5, "shots": [2, 4], "miss": 0.75, "hide": 0.5},
	"nador": {"name": "Nádor", "hp": 55.0, "walk": 1.0, "run": 1.9, "armor": 1.0, "model": "nador", "h": 0.5, "r": 0.42, "eye": 1.0,
		"spit": "acid", "bolt": 1.1, "shots": [1, 1], "miss": 1.1, "rate": 1.6, "hover": 0.85, "hide": 0.3, "regen": true},
	"ohnivec": {"name": "Ohnivec", "hp": 170.0, "walk": 0.9, "run": 1.6, "armor": 0.2, "model": "ohnivec", "h": 0.7, "r": 0.6, "eye": 0.6,
		"spit": "lava", "bolt": 1.4, "shots": [1, 1], "miss": 1.0, "rate": 2.2, "hide": 0.0, "touch": 22.0,
		"weak": {"explosion": 6.0}},
	"myslodej": {"name": "Mysloděj", "hp": 140.0, "walk": 1.3, "run": 2.8, "armor": 0.8, "model": "myslodej", "h": 1.6, "r": 0.4, "eye": 1.55,
		"bolt": 1.2, "shots": [1, 2], "miss": 0.7, "hover": 0.35, "hide": 1.2, "psi": 2},
	"mozek": {"name": "Velký mozek", "hp": 2200.0, "walk": 0.0, "run": 0.0, "armor": 0.6, "model": "mozek", "h": 2.6, "r": 1.6, "eye": 1.3,
		"hide": 0.0, "psi": 3, "weak": {"explosion": 1.4, "laser": 1.3, "plasma": 1.2}},
	"pylon": {"name": "Pylon štítu", "hp": 260.0, "walk": 0.0, "run": 0.0, "armor": 0.7, "model": "pylon", "h": 2.9, "r": 0.6, "eye": 2.8,
		"hide": 0.0, "explode": [3.0, 25.0], "weak": {"explosion": 2.0}},
	"kolos": {"name": "Kolos", "hp": 320.0, "walk": 1.6, "run": 3.2, "armor": 0.45, "model": "kolos", "h": 2.4, "r": 0.9, "eye": 2.0,
		"bolt": 1.3, "shots": [2, 3], "miss": 0.8, "explode": [6.0, 90.0], "hide": 0.0, "weak": {"explosion": 1.3}},
}

# ---- synchronized ----
var dead := false
var alert := false
var captured := false     # knocked out alive - worth more
var lurking := true
var striking := false     # melee races: the attack animation is playing
var husk := false         # Nádor: "dead" on the ground - must be destroyed again or it comes back
var race := "grey"
var bleeding := false     # badly hurt: it drips as it goes - a trail to follow

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
	collision_layer = 4
	collision_mask = 1
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
	anim = m.find_child("AnimationPlayer", true, false)
	if anim:
		for an in anim.get_animation_list():
			anim.get_animation(an).loop_mode = Animation.LOOP_LINEAR
		anim.play("idle")
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
	for prop in [":position", ":rotation", ":dead", ":alert", ":lurking", ":captured", ":striking", ":husk", ":bleeding"]:
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
	if dead:
		_death_anim(delta)
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
	_think(delta)
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

## Eyes only flash when a flashlight catches them - and only for a moment.
func _eyeshine(delta: float) -> void:
	glint_t -= delta
	var p: Node = mission.local_player() if mission else null
	if not dead and p and p.light_on and not p.downed and p.cam:
		var from: Vector3 = p.cam.global_position
		var to := eye()
		var d := from.distance_to(to)
		if d < 24.0 and (-p.cam.global_transform.basis.z).dot((to - from).normalized()) > 0.965:
			var q := PhysicsRayQueryParameters3D.create(from, to, 1)
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
	var q := PhysicsRayQueryParameters3D.create(eye(), to, 1)
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
		return
	# hurt: break contact at once and come back from somewhere else
	if hp < float(R["hp"]) * 0.45:
		bleeding = true
	_flinch.rpc(from)
	last_seen = from
	_enter_combat(null)
	_relocate(from)
	phase = "move"

## Stun damage (baton): when it outweighs the remaining health, the alien
## collapses unconscious and can be taken alive.
func stun(amount: float, from: Vector3, by: Node) -> void:
	if dead:
		return
	stun_dmg += amount
	alert = true
	if stun_dmg >= hp:
		if dragging:
			_release()
		_knocked_out.rpc()
		if by and by.has_method("is_player"):
			_credit_capture.rpc_id(by.get_multiplayer_authority(), by.name)
		return
	last_seen = from
	_enter_combat(null)

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
		if p.dead or p.downed:
			continue
		var seen_now := visible_to(p)
		if not aware:
			var k := String(p.name)
			var v := float(sus.get(k, 0.0))
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
		shots_left = rng.randi_range(R["shots"][0], R["shots"][1]) if R.has("shots") else 1
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
				shots_left = rng.randi_range(R["shots"][0], R["shots"][1])
				react = rng.randf_range(0.35, 0.7)
	elif (state != S.COMBAT or phase == "hide" or phase == "flank") and _try_drag():
		return
	match state:
		S.LURK:
			wait -= delta
			if _arrived():
				lurking = true
				velocity.x = 0; velocity.z = 0
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
	unseen_t += delta if seen == null else 0.0
	if unseen_t > 45.0:
		state = S.SEARCH
		search_t = rng.randf_range(8.0, 14.0)
		return
	match phase:
		"shoot":
			lurking = false
			velocity.x = 0; velocity.z = 0
			_face(last_seen, delta)
			if seen == null:
				if react < -1.5:
					_relocate(last_seen)
					phase = "move"
				return
			if react <= 0 and shoot_cd <= 0:
				_fire(seen)
				mission.combat_t = mission.t
				shots_left -= 1
				shoot_cd = rng.randf_range(0.7, 1.1) * float(R.get("rate", 1.0))
				if shots_left <= 0:
					_relocate(last_seen)
					phase = "move"
		"move":
			lurking = false
			_walk(run_spd, delta)
			if _arrived():
				phase = "hide"
				hide_t = rng.randf_range(2.5, 6.0) * float(R["hide"])
		"hide":
			lurking = true
			velocity.x = 0; velocity.z = 0
			hide_t -= delta
			if hide_t <= 0:
				# hurt ones keep their heads down longer; the rest come from the side
				if hp < float(R["hp"]) * 0.4 and rng.randf() < 0.5:
					hide_t = rng.randf_range(2.0, 4.0)
					_relocate(last_seen)
					phase = "move"
				else:
					_flank()
					phase = "flank"
		"flank":
			lurking = false
			_walk(walk_spd * 1.4, delta)
			if _arrived():
				phase = "hide"
				hide_t = rng.randf_range(3.0, 7.0) * float(R["hide"])

## Breaks line of sight: a cover point that hides it from @a from,
## preferably to the side, so the next attack comes from elsewhere.
func _relocate(from: Vector3) -> void:
	var best := Vector3.ZERO
	var bs := 1e9
	var to_me := (global_position - from)
	to_me.y = 0
	to_me = to_me.normalized()
	for c in mission.map["cover"]:
		var d: float = global_position.distance_to(c)
		if d > 16.0 or d < 2.0:
			continue
		var q := PhysicsRayQueryParameters3D.create(c + Vector3(0, 0.8, 0), from + Vector3(0, 1.0, 0), 1)
		if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			continue
		var dir: Vector3 = (c - global_position)
		dir.y = 0
		var side: float = abs(to_me.cross(dir.normalized()).y)
		var score: float = d - side * 5.0
		if c.distance_to(from) < 6.0:
			score += 20.0
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

## Back into the dark: a hiding spot away from the mercenaries.
func _go_lurk(move_far: bool) -> void:
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
	for p in mission.players():
		var claimed := false
		for a in mission.aliens():
			if a != self and a.dragging == p:
				claimed = true
		if claimed:
			continue
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
			var bs := -1.0
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
	return agent.is_navigation_finished() or global_position.distance_to(goal) < 1.0

var _stuck_base := 0.0
func _walk(speed: float, delta: float) -> void:
	if _arrived():
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
	var tgt: Vector3 = p.global_position + Vector3(0, 0.8 if p.crouching else 1.2, 0)
	var miss := (0.8 + global_position.distance_to(tgt) * 0.055) * float(R.get("miss", 1.0))
	if Game.veteran(): miss *= 0.8
	elif Game.easy(): miss *= 1.4
	if _rally_t > 0: miss *= 0.75
	if p.crouching: miss *= 1.3
	if Vector2(p.velocity.x, p.velocity.z).length() > 2.0: miss *= 1.5
	tgt += Vector3(rng.randf_range(-miss, miss), rng.randf_range(-miss, miss) * 0.6, rng.randf_range(-miss, miss))
	var from := _muzzle_pos()
	var kind: String = R.get("spit", "plasma")
	var d := (tgt - from)
	if kind != "plasma":
		# spit: lob it - aim above the target so it falls onto him
		var dist := Vector2(d.x, d.z).length()
		var tt := dist / 15.0
		d = d / max(tt, 0.05)
		d.y += 0.5 * 7.0 * tt
		d = d / 15.0
	_plasma.rpc(from, d.normalized() if kind == "plasma" else d, float(R.get("bolt", 1.0)), kind)

@rpc("authority", "call_local", "reliable")
func _plasma(from: Vector3, dir: Vector3, power := 1.0, kind := "plasma") -> void:
	# the big ones (and the drones) fire the heavy plasma, ten takes so it never repeats
	Game.play_at(mission, ("plasma_heavy" if power >= 1.3 else "plasma") if kind == "plasma" else ("acid_spit" if kind == "acid" else "lunge"), from, -2 + (power - 1.0) * 2.0)
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
		if state == S.LURK and _arrived():
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
		if r < 0.6:
			best.psi_blast.rpc_id(best.get_multiplayer_authority(), rng.randf_range(9.0, 16.0))
			return
		# a stronger will: harder to resist
		best.psi_attack.rpc_id(best.get_multiplayer_authority(), 0.25 + rng.randf() * 0.75)
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
