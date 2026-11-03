extends CharacterBody3D
## A mercenary. The machine that owns him moves him and decides what he does;
## damage comes from the host; everybody else sees the synchronized state.

const WALK := 2.6
const CROUCH := 1.3
const SPRINT := 4.4
const GRAVITY := 18.0
const BLEED_OUT := 60.0

# ---- synchronized state ----
var pitch := 0.0
var crouching := false
var light_on := true
var hp := 30.0
var max_hp := 30.0
var downed := false
var dead := false
var wounded := false
var bleed_left := BLEED_OUT
var carried_by := 0
var wants_evac := false
var evac_hold := 0.0
var plant_hold := 0.0
var kills := 0
var display_name := ""
var held := ""            # item id in the right hand (for others to see)
var held_l := ""
var held_back := ""
var prone := false
var sprinting := false
var captures := 0
var revives := 0
var breath := 0.0         # 0..1 how out of breath (aim wanders)
var spin := 0.0           # minigun spin-up
var busy_total := 0.0
var busy_stand := false   # digging in the backpack: no moving
var kick_mult := 1.0
var _swing_left := false
var _swing_kind := 0       # 0 stab/slash (knife), 1 overhead, 2 right-to-left diagonal, 3 left-to-right
var _swing_speed := 3.5
var bracing := false
var _breath_ph := 0.0
var _breath_snd := 0.0
var panic := ""           # "", "flee", "drop", "berserk" (X-COM style panic)
var infected := false     # a Líhnoun's seed: bleed out with it and you rise again
var radio_button := false
var _winded := false      # ran out of stamina: sprint locked until it recovers # holding the mouse button of the hand with the radio

# ---- local only ----
var merc := {}
var inv := {}             # slot -> {"id":..., "loaded":..., "uses":...}
var stamina := 100.0
var stress := 0.0
var bleeding := 0.0
var spread_bloom := 0.0
var fire_cd := 0.0
var busy := 0.0           # reloading / healing / throwing
var busy_text := ""
var busy_done: Callable
var aiming := false
var step_t := 0.0
var _mouse := Vector2.ZERO
var _sway := Vector2.ZERO
var _hb := 0.0

var head: Node3D
var cam: Camera3D
var flash: SpotLight3D
var body: Node3D
var gun: Node3D
var label: Label3D
var sync: MultiplayerSynchronizer
var mission: Node

func is_player() -> bool:
	return true

func setup(data: Dictionary) -> void:
	merc = data["merc"]
	display_name = data["name"]
	max_hp = float(merc.get("health", 30)) + (5.0 if Game.has_talent(merc, "houzevnaty") else 0.0) + (8.0 if Game.has_research("slitiny") else 0.0)
	hp = max_hp
	bleed_left = BLEED_OUT + (30.0 if Game.has_talent(merc, "houzevnaty") else 0.0) + (20.0 if Game.has_research("medicina") else 0.0)
	if Game.veteran():
		# old wounds come along to the next mission
		hp = max(max_hp * 0.4, max_hp - Game.injury_now(merc))
		wounded = hp < max_hp
	position = data["pos"]
	rotation.y = float(data.get("yaw", PI))     # out of the Kondor, down the ramp
	collision_layer = 2
	collision_mask = 1 | 2
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	_body_cs = cs
	_body_cap = cap
	head = Node3D.new()
	head.position.y = 1.6
	add_child(head)
	flash = SpotLight3D.new()
	flash.light_energy = 3.0
	flash.light_volumetric_fog_energy = 1.6
	flash.spot_range = 22.0
	flash.spot_angle = 16.0
	flash.light_color = Color(1.0, 0.95, 0.8)
	flash.shadow_enabled = true
	head.add_child(flash)
	flash.position = Vector3(0.1, -0.15, -0.7)
	# body for the others
	body = Node3D.new()
	add_child(body)
	_build_body(data)
	label = Label3D.new()
	label.text = display_name
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 2.1
	label.font_size = 24
	label.pixel_size = 0.006
	label.modulate = Color(0.6, 0.85, 1.0)
	label.no_depth_test = true
	add_child(label)
	# what everybody needs to see
	sync = MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop in [":position", ":rotation", ":pitch", ":crouching", ":light_on", ":hp", ":downed", ":dead", ":wounded",
			":bleed_left", ":carried_by", ":wants_evac", ":kills", ":held", ":panic", ":gear",
			":held_l", ":held_back", ":prone", ":sprinting", ":captures", ":infected", ":act", ":emote"]:
		cfg.add_property(NodePath("." + prop))
		cfg.property_set_replication_mode(NodePath("." + prop), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = cfg
	sync.root_path = NodePath("..")
	add_child(sync)
	sync.set_multiplayer_authority(get_multiplayer_authority())

func _part(parent: Node3D, pos: Vector3, size: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	parent.add_child(mi)
	mi.position = pos
	return mi

func _ready() -> void:
	mission = get_tree().current_scene
	if is_multiplayer_authority():
		inv = Game.default_loadout()
		if inv.has("rh"):
			inv["rh"]["home"] = "back"
		for hs in ["side", "b0", "b1", "b2", "b3"]:
			if inv.has(hs):
				inv[hs]["home"] = hs
		armor = String(Game.valid_loadout(Game.veteran()).get("armor", ""))
		var ids := []
		for sl in inv:
			ids.append(inv[sl]["id"])
		(func(): mission.report_kit.rpc_id(1, ids)).call_deferred()
		cam = Camera3D.new()
		cam.fov = Game.fov
		cam.near = 0.05
		head.add_child(cam)
		cam.current = true
		body.visible = false
		label.visible = false
		_build_viewmodel()
		_update_held()

var body_gun: Node3D
var _shown_gun := "-"
var gear := 0              # synced bitmask: which equipment is visible on the body
var merc_model: Node3D
var _sk: Skeleton3D
var _hand_r := -1
var body_anim: AnimationPlayer
var _gear_nodes := {}
var _last_body_pos := Vector3.ZERO
var _body_speed := 0.0
const GEAR_BITS := ["Gear_Belt0", "Gear_Belt1", "Gear_Belt2", "Gear_Belt3", "Gear_Backpack", "Gear_Grenade",
	"Gear_Flare", "Gear_Medkit", "Gear_Holster", "Gear_Scanner", "Gear_Vest", "Gear_Plate"]
var armor := ""        # worn armour id (vesta / pancir), from the loadout
var _body_cs: CollisionShape3D
var _body_cap: CapsuleShape3D

## The body's hit and collision shape follows the stance on every machine: standing 1.8 m,
## crouched 1.2 m, lying (prone, down, dead) a low 0.7 m - you can shoot over a fallen friend.
func _fit_body_shape() -> void:
	if _body_cap == null:
		return
	var h := 0.7 if (prone or downed or dead) else (1.25 if crouching else 1.8)
	if absf(_body_cap.height - h) > 0.01:
		_body_cap.height = h
		_body_cs.position.y = h / 2.0
const TEAM_COLORS := [Color(0.22, 0.24, 0.17), Color(0.18, 0.2, 0.24), Color(0.26, 0.22, 0.17), Color(0.17, 0.17, 0.17)]
const PATCH_COLORS := [Color(0.85, 0.65, 0.15), Color(0.2, 0.6, 0.95), Color(0.9, 0.25, 0.2), Color(0.4, 0.9, 0.4)]

## The mercenary as others see him: a rigged model whose gear matches his inventory.
func _build_body(data: Dictionary) -> void:
	merc_model = Game.model("merc")
	body.add_child(merc_model)
	body_anim = merc_model.find_child("AnimationPlayer", true, false)
	if body_anim:
		for an in body_anim.get_animation_list():
			body_anim.get_animation(an).loop_mode = Animation.LOOP_NONE if an == "dead" else Animation.LOOP_LINEAR
		body_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		body_anim.play("idle")
	var idx: int = abs(int(data["peer"])) % 4 if int(data["peer"]) != 1 else 0
	var h := display_name.hash()
	for mi in merc_model.find_children("*", "MeshInstance3D", true, false):
		_gear_nodes[String(mi.name)] = mi
		for i in mi.mesh.get_surface_count():
			var src: Material = mi.mesh.surface_get_material(i)
			if src and src.resource_name == "Uniform":
				mi.set_surface_override_material(i, Game.color_mat(TEAM_COLORS[idx]))
			elif src and src.resource_name == "Patch":
				mi.set_surface_override_material(i, Game.color_mat(PATCH_COLORS[idx]))
	# face, hair, beard, headgear: chosen by the player (the merc dict travels with the spawn)
	Game.apply_look(merc_model, data.get("merc", {}).get("look", {}))
	# the weapon follows the torso's turn and lean; its position is put in the right hand each frame
	var sk: Skeleton3D = merc_model.find_child("Skeleton3D", true, false)
	_sk = sk
	_hand_r = sk.find_bone("hand.R") if sk else -1
	body_gun = Node3D.new()
	if sk and sk.find_bone("spine") >= 0:
		var att := BoneAttachment3D.new()
		att.bone_name = "spine"
		sk.add_child(att)
		att.add_child(body_gun)
		var rest := sk.get_bone_global_rest(sk.find_bone("spine"))
		body_gun.transform = rest.affine_inverse() * Transform3D(Basis(), Vector3(-0.1, 1.2, -0.3))
	else:
		body.add_child(body_gun)
		body_gun.position = Vector3(-0.1, 1.2, -0.3)
	body_l = Node3D.new()
	body_back = Node3D.new()
	if sk and sk.find_bone("hand.L") >= 0:
		var al := BoneAttachment3D.new()
		al.bone_name = "hand.L"
		sk.add_child(al)
		al.add_child(body_l)
		var rl := sk.get_bone_global_rest(sk.find_bone("hand.L"))
		body_l.transform = rl.affine_inverse() * Transform3D(Basis(), Vector3(0.24, 0.82, -0.04))
		var ab := BoneAttachment3D.new()
		ab.bone_name = "spine"
		sk.add_child(ab)
		ab.add_child(body_back)
		var rs := sk.get_bone_global_rest(sk.find_bone("spine"))
		# slung diagonally across the back, muzzle up
		body_back.transform = rs.affine_inverse() * Transform3D(Basis.from_euler(Vector3(-PI / 2 + 0.3, 0, 0.6)), Vector3(0.0, 1.2, 0.2))
	else:
		body.add_child(body_l)
		body.add_child(body_back)
	_apply_gear()

## First-person hands: sway with steps, kick on shots, swing when sprinting,
## a proper reload motion, and the slow settling of breath after a run.
var _vm_t := 0.0
var _vm_kick := 0.0
var _swing := 0.0            # melee swing timer
const VM_R := {"rifle": Vector3(0.17, -0.18, -0.4), "sniper": Vector3(0.17, -0.19, -0.42), "plasma_rifle": Vector3(0.17, -0.18, -0.4), "shotgun": Vector3(0.17, -0.19, -0.42), "autocannon": Vector3(0.2, -0.24, -0.48),
	"minigun": Vector3(0.21, -0.3, -0.42), "rocket_launcher": Vector3(0.21, -0.1, -0.3)}
const VM_ONE_R := Vector3(0.2, -0.2, -0.36)
const VM_ONE_L := Vector3(-0.2, -0.2, -0.36)
func _viewmodel_motion(delta: float, speed: float) -> void:
	if gun == null:
		return
	_vm_t += delta * speed * (2.6 if sprinting else 2.2)
	_vm_kick = max(0.0, _vm_kick - delta * 7.0)
	_swing = max(0.0, _swing - delta * _swing_speed)
	if _swing <= 0 and _swing_holder and is_instance_valid(_swing_holder):
		_swing_holder.position -= _swing_off
		_swing_off = Vector3.ZERO
		_swing_holder = null
	var k: float = clamp(delta * 12.0, 0.0, 1.0)
	var bob: Vector3 = Vector3(sin(_vm_t) * 0.012, -abs(cos(_vm_t)) * 0.01, 0) * clamp(speed / 2.6, 0.0, 1.6)
	var r := item_in("rh")
	var rid: String = r.get("id", "")
	var two := Game.two_handed(rid)
	var base: Vector3 = VM_R.get(rid, VM_ONE_R)
	var rot := Vector3(0.02, 0.06, 0)
	if Game.ITEMS.get(rid, {}).get("blunt", false):
		# club: low on the right, tip leaning out to the right
		base = Vector3(0.25, -0.27, -0.46)
		rot = Vector3(-0.1, 0.1, -0.3)
	if aiming and two:
		base = Vector3(0.0, -0.165, -0.3) if rid != "rocket_launcher" else Vector3(0.12, -0.09, -0.22)
		rot = Vector3(0, 0, 0)
	elif aiming and pistol_grip():
		base = Vector3(0.0, -0.105, -0.34)      # both hands, sights in front of the eye
		rot = Vector3(0, 0, 0)
	elif pistol_grip():
		base = Vector3(0.1, -0.17, -0.38)       # both hands, low ready, a little to the right
	if bracing:
		# braced against the hip, pulled in and a bit to the centre
		base = Vector3(base.x * 0.55, base.y - 0.03, base.z + 0.08)
		rot = Vector3(0.0, 0.02, 0.0)
	if _radio_lower > 0.01:
		# the left hand lets go, the gun sinks in the right hand out of sight
		base = base.lerp(Vector3(0.32, -0.8, -0.3), _radio_lower)
		rot = rot.lerp(Vector3(1.0, 0.55, 0.35), _radio_lower)
	if sprinting:
		# weapon swung low across the body, swinging with the stride
		base = Vector3(0.12, -0.32, -0.32) + Vector3(sin(_vm_t) * 0.04, -abs(cos(_vm_t)) * 0.04, 0)
		rot = Vector3(0.35 + sin(_vm_t) * 0.06, 0.9, 0.45)
	# reload: tilt in, hold, back up (the magazine drops at a quarter)
	var rl := 0.0
	var reloading := busy > 0 and busy_total > 0 and busy_text.begins_with("Přebíj")
	if reloading and not rid in ["pistol", "magnum", "shotgun"]:
		var ph := 1.0 - busy / busy_total
		rl = smoothstep(0.0, 0.25, ph) * (1.0 - smoothstep(0.75, 1.0, ph))
	# pistol and revolver: full hand-made reloads (after Ari's videos)
	var ra := _reload_anim(delta, rid, reloading)
	base += ra[0]
	rot += ra[1]
	# which right-hand grip shows: both hands on the gun, or the right hand alone (the left
	# is busy reloading, or holds something)
	var busy_l := (reloading and rid in ["pistol", "magnum", "shotgun"]) or _rev_open > 0.05
	var g2 := gun.get_node_or_null("GripTwo")
	var g1 := gun.get_node_or_null("GripOne")
	if g2 and g1:
		g2.visible = pistol_grip() and not busy_l
		g1.visible = not g2.visible
	_lower_left = busy_l and inv.has("lh")
	# digging in the backpack: hands drop out of view
	var dig := 1.0 if (busy > 0 and busy_stand) else 0.0
	var target: Vector3 = base + bob + Vector3(0.0, -0.1 * rl - 0.4 * dig, 0.05 * _vm_kick)
	gun.position = gun.position.lerp(target, k)
	gun.rotation.x = lerp(gun.rotation.x, rot.x + _vm_kick * 0.12 * kick_mult - rl * 0.5, k)
	gun.rotation.y = lerp(gun.rotation.y, rot.y, k)
	if _twirl > 0.0:
		# two turns around the trigger finger, slowing into the grip at the end
		_twirl = maxf(0.0, _twirl - delta / 0.9)
		var tw := 1.0 - _twirl
		gun.rotation.x = rot.x - TAU * 2.0 * (1.0 - pow(1.0 - tw, 2.0))
	gun.rotation.z = lerp(gun.rotation.z, rot.z + rl * 0.7, k)
	if gun_l:
		# the left hand puts its thing down while it helps reload the right gun
		_lower_l_t = move_toward(_lower_l_t, 1.0 if _lower_left else 0.0, delta * 4.0)
		var lt: Vector3 = VM_ONE_L + Vector3(-bob.x, bob.y, 0) + Vector3(0, -0.4 * dig - 0.45 * _lower_l_t, 0)
		if sprinting:
			lt += Vector3(0, -0.15, 0.05)
		gun_l.position = gun_l.position.lerp(lt, k)
	# melee swing
	if _swing > 0:
		var holder: Node3D = gun_l if _swing_left else gun
		var side := -1.0 if _swing_left else 1.0
		var ph := 1.0 - _swing
		if _swing_kind == 0:
			# knife: a quick thrust forward
			var sw := sin(ph * PI)
			holder.rotation = Vector3(-0.9 * sw, 0.6 * sw * side, 0.4 * sw)
			_swing_shift(holder, Vector3(-0.15 * sw * side, 0.05 * sw, -0.12 * sw))
		elif _swing_kind == 4:
			# knife: up high, point down - then a hard stab down and forward
			var up4 := smoothstep(0.0, 0.35, ph) * (1.0 - smoothstep(0.35, 0.55, ph))
			var dn4 := smoothstep(0.35, 0.55, ph) * (1.0 - smoothstep(0.7, 1.0, ph))
			holder.rotation = Vector3(1.6, 0.2, 0.3) * up4 + Vector3(-1.2, 0.1, 0.2) * dn4
			_swing_shift(holder, Vector3(-0.05, 0.22, 0.05) * up4 + Vector3(-0.08, -0.06, -0.18) * dn4)
		elif _swing_kind == 5:
			# knife: a wide slash from the right shoulder across to the left hip
			var a5 := smoothstep(0.0, 0.3, ph) * (1.0 - smoothstep(0.3, 0.45, ph))
			var b5 := smoothstep(0.3, 0.5, ph) * (1.0 - smoothstep(0.7, 1.0, ph))
			holder.rotation = Vector3(0.6, -0.5, -0.9) * a5 + Vector3(-0.7, 0.9, 1.0) * b5
			_swing_shift(holder, Vector3(0.1, 0.12, 0.02) * a5 + Vector3(-0.28, -0.1, -0.12) * b5)
		else:
			# club: raise it back (wind-up), bring it down hard, recover
			var up := smoothstep(0.0, 0.3, ph) * (1.0 - smoothstep(0.3, 0.45, ph))
			var down := smoothstep(0.3, 0.45, ph) * (1.0 - smoothstep(0.6, 1.0, ph))
			var dx := 0.0     # sideways travel: + = from right to left
			match _swing_kind:
				2: dx = 1.0
				3: dx = -1.0
			dx *= side if _swing_left else 1.0
			# wind-up: club tilted back over the shoulder, start corner of the diagonal
			var rot_up := Vector3(0.9, 0.25 * dx, -0.55 * dx)
			var pos_up := Vector3(0.08 * dx, 0.14, -0.04)
			# strike: club swept forward and down through the target to the opposite corner
			var rot_dn := Vector3(-1.5, -0.3 * dx, 0.55 * dx)
			var pos_dn := Vector3(-0.14 * dx, -0.1, -0.14)
			holder.rotation = rot_up * up + rot_dn * down
			_swing_shift(holder, pos_up * up + pos_dn * down)
	elif gun_l:
		gun_l.rotation = gun_l.rotation.lerp(Vector3(0.02, -0.06, 0), k)
	# minigun barrels spin
	if rid == "minigun":
		var b: Node3D = gun.find_child("MinigunBarrels", true, false)
		if b:
			b.rotate_object_local(Vector3(0, 0, 1), spin * delta * 40.0)

# ---- minigun sound: the barrels spin up, the gun roars in a loop, then winds down ---------
var _mg_last := -10.0
var _casing_n := 0
var _mg_loop: AudioStreamPlayer3D
var _mg_firing := false
func _mg_tick() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var firing := now - _mg_last < 0.15
	if firing and not _mg_firing:
		if _mg_loop == null:
			_mg_loop = AudioStreamPlayer3D.new()
			var st: AudioStreamWAV = (Game.sound("minigun_fire") as AudioStreamWAV).duplicate()
			st.loop_mode = AudioStreamWAV.LOOP_FORWARD
			st.loop_begin = 0
			st.loop_end = int(st.get_length() * st.mix_rate)
			_mg_loop.stream = st
			_mg_loop.unit_size = 6.0
			_mg_loop.max_distance = 90.0
			_mg_loop.bus = "SFX"
			_mg_loop.volume_db = -1.0
			add_child(_mg_loop)
			_mg_loop.position = Vector3(0, 1.2, 0)
		_mg_loop.play()
	elif not firing and _mg_firing:
		if _mg_loop:
			_mg_loop.stop()
		Game.play_at(mission, "minigun_stop", global_position + Vector3.UP, -2)
	_mg_firing = firing

@rpc("any_peer", "call_local", "unreliable")
func _mg_spinup() -> void:
	Game.play_at(mission, "minigun_spin", global_position + Vector3.UP, -2)

## Moves the swinging hand by @a off from where it would be (no drift frame to frame).
var _swing_off := Vector3.ZERO
var _swing_holder: Node3D
func _swing_shift(holder: Node3D, off: Vector3) -> void:
	if _swing_holder == holder:
		holder.position -= _swing_off
	holder.position += off
	_swing_off = off
	_swing_holder = holder

func _gear_mask() -> int:
	var m := 0
	for i in 4:
		if inv.has("b%d" % i): m |= 1 << i
	for s in ["p0", "p1", "p2", "p3", "p4", "p5"]:
		if inv.has(s): m |= 1 << 4
	for s in inv:
		var id: String = inv[s]["id"]
		if id == "grenade": m |= 1 << 5
		if id == "flare": m |= 1 << 6
		if id == "medkit": m |= 1 << 7
		if (id == "pistol" or id == "magnum") and s != "rh" and s != "lh": m |= 1 << 8
	if armor == "vesta": m |= 1 << 10
	if armor == "pancir": m |= 1 << 11
	return m

func _apply_gear() -> void:
	for i in GEAR_BITS.size():
		var n: Node3D = _gear_nodes.get(GEAR_BITS[i])
		if n:
			n.visible = (gear >> i) & 1 == 1

func _animate_body(delta: float) -> void:
	if body_anim == null:
		return
	var moved := global_position - _last_body_pos
	moved.y = 0
	_last_body_pos = global_position
	_body_speed = lerp(_body_speed, moved.length() / max(delta, 0.001), 0.2)
	var want := "idle"
	if dead:
		want = "dead"
	elif downed:
		# wounded: on hands and knees, crawling when moving (or being dragged)
		want = "crawl_hurt" if _body_speed > 0.15 else "crawl_idle"
	elif prone:
		want = "prone_crawl" if _body_speed > 0.2 else "prone"
	elif sprinting:
		want = "sprint"
	elif crouching or (act >= 3 and _body_speed < 0.3):
		want = "crouch_walk" if _body_speed > 0.3 else "crouch"
	elif _body_speed > 3.2:
		want = "run"
	elif _body_speed > 0.3:
		want = "walk"
	if not body_anim.has_animation(want):
		want = "downed" if dead or downed else "idle"
	if body_anim.current_animation != want:
		body_anim.play(want, 0.25)
	body_anim.advance(0.0 if dead and body_anim.current_animation_position > 0.3 else delta)
	# dead: on the back. wounded: upright on all fours. prone: on the belly, arms ahead.
	var rx := PI / 2 if dead else (-PI / 2 if prone and not downed else 0.0)
	merc_model.rotation.x = lerp_angle(merc_model.rotation.x, rx, delta * 6.0)
	merc_model.position.y = lerp(merc_model.position.y, 0.18 if (dead or (prone and not downed)) else 0.0, delta * 6.0)
	merc_model.position.z = lerp(merc_model.position.z, -0.9 if dead else (0.9 if prone and not downed else 0.0), delta * 6.0)
	if not (dead or downed or prone or sprinting):
		_hold_pose(delta)
		_emote_pose(delta)
	# the long gun sits in the right hand (follows the arms in every pose), not on the belly
	if _sk and _hand_r >= 0 and body_gun:
		var hand := _sk.global_transform * _sk.get_bone_global_pose(_hand_r)
		body_gun.global_position = hand.origin + hand.basis.y.normalized() * -0.05
	# fallen: the hands are empty (the gun lies by him), only the slung one stays on the back
	if body_gun:
		body_gun.visible = not (dead or downed or emote != 0)
	if body_l:
		body_l.visible = not (dead or downed)

# ---- how the others see you hold things: the arms are posed over the walk cycle -----------
## what the hands are doing right now (synced): 0 nothing special, 1 reloading, 2 striking
var act := 0
var _act_t := 0.0
var _bone_ix := {}

func _bone(n: String) -> int:
	if not _bone_ix.has(n):
		_bone_ix[n] = _sk.find_bone(n) if _sk else -1
	return _bone_ix[n]

## Arm poses (bone: euler as in the model's rig: +X swings a limb forward).
const POSE_RIFLE := {"upperarm.R": Vector3(0.5, 0, -0.25), "forearm.R": Vector3(1.3, 0, 0), "upperarm.L": Vector3(0.95, 0, 0.45), "forearm.L": Vector3(0.75, 0, 0)}
const POSE_HIP := {"upperarm.R": Vector3(0.2, 0, -0.25), "forearm.R": Vector3(1.05, 0, 0), "upperarm.L": Vector3(0.6, 0, 0.4), "forearm.L": Vector3(0.95, 0, 0)}
const POSE_SHOULDER := {"upperarm.R": Vector3(1.0, 0, -0.55), "forearm.R": Vector3(1.9, 0, 0), "upperarm.L": Vector3(1.25, 0, 0.35), "forearm.L": Vector3(0.8, 0, 0)}
const POSE_PISTOL := {"upperarm.R": Vector3(0.55, 0, -0.1), "forearm.R": Vector3(0.6, 0, 0)}
const POSE_PISTOL2 := {"upperarm.R": Vector3(0.7, 0, -0.1), "forearm.R": Vector3(0.6, 0, 0), "upperarm.L": Vector3(0.9, 0, 0.45), "forearm.L": Vector3(0.75, 0, 0)}
const POSE_SIDE_R := {"upperarm.R": Vector3(0.1, 0, -0.12), "forearm.R": Vector3(0.45, 0, 0)}
const POSE_LOOSE_R := {"upperarm.R": Vector3(0.05, 0, -0.1), "forearm.R": Vector3(0.15, 0, 0)}
const POSE_LOOSE_L := {"upperarm.L": Vector3(0.05, 0, 0.1), "forearm.L": Vector3(0.15, 0, 0)}
const POSE_ITEM_R := {"upperarm.R": Vector3(0.35, 0, -0.1), "forearm.R": Vector3(1.0, 0, 0)}
const POSE_ITEM_L := {"upperarm.L": Vector3(0.35, 0, 0.1), "forearm.L": Vector3(1.0, 0, 0)}
const POSE_RADIO_L := {"upperarm.L": Vector3(0.9, 0, 0.55), "forearm.L": Vector3(2.1, 0, 0)}

func _hold_pose(delta: float) -> void:
	if _sk == null:
		return
	_act_t += delta
	var want := {}
	var r: String = held
	var l: String = held_l
	var rule: Dictionary = Game.ITEMS.get(r, {})
	var two := Game.two_handed(r)
	if r == "":
		want.merge(POSE_LOOSE_R)
	elif rule.get("type", "") == "weapon":
		if r in ["shotgun"]:
			want.merge(POSE_HIP)
			if act == 1:
				# one shell after another: the left hand from the belt up under the gun
				# (the gun turned over a little), then the pump
				var k := 0.5 + 0.5 * sin(_act_t * 6.0)
				want["upperarm.R"] = Vector3(0.25, 0, -0.3)
				want["forearm.R"] = Vector3(1.15, 0, 0)
				want["upperarm.L"] = Vector3(0.1 + 0.5 * k, 0, 0.1 + 0.35 * k)
				want["forearm.L"] = Vector3(0.6 + 0.45 * k, 0, 0)
		elif r in ["minigun", "autocannon", "a_heavy"]:
			want.merge(POSE_HIP)
			want["upperarm.R"] = Vector3(0.1, 0, -0.35)
		elif r == "rocket_launcher":
			want.merge(POSE_SHOULDER)
		elif two:
			want.merge(POSE_RIFLE)
			if act == 1:
				# reload: the gun dips, the left hand goes to the magazine and back
				var k2 := sin(_act_t * 3.0)
				want["upperarm.R"] = Vector3(0.3, 0, -0.25)
				want["forearm.R"] = Vector3(1.25, 0, 0)
				want["upperarm.L"] = Vector3(0.45 + 0.15 * k2, 0, 0.3)
				want["forearm.L"] = Vector3(1.2 + 0.2 * k2, 0, 0)
		elif l == "":
			want.merge(POSE_PISTOL2)
			if act == 1:
				# pistol / revolver reload: the gun comes in to the chest, muzzle down,
				# the left hand works at it (after Ari's videos)
				var k3 := sin(_act_t * 5.0)
				want["upperarm.R"] = Vector3(0.3, 0, -0.35)
				want["forearm.R"] = Vector3(1.75, 0, 0)
				want["hand.R"] = Vector3(-0.6, 0, 0)
				want["upperarm.L"] = Vector3(0.45, 0, 0.45)
				want["forearm.L"] = Vector3(1.55 + 0.2 * k3, 0, 0)
		else:
			want.merge(POSE_PISTOL)
	elif rule.get("type", "") == "melee":
		if rule.get("blunt", false):
			want.merge(POSE_LOOSE_R)       # the club hangs along the arm
			if act == 2:
				var ph := clampf(_act_t / 0.45, 0.0, 1.0)
				var up := smoothstep(0.0, 0.35, ph) * (1.0 - smoothstep(0.35, 0.6, ph))
				var dn := smoothstep(0.35, 0.6, ph) * (1.0 - smoothstep(0.75, 1.0, ph))
				want["upperarm.R"] = Vector3(0.05 + 2.4 * up + 0.9 * dn, 0, -0.1 - 0.3 * up)
				want["forearm.R"] = Vector3(0.15 + 0.9 * up + 0.1 * dn, 0, 0)
		else:
			want.merge(POSE_SIDE_R)        # knife low at the hip
			if act == 2:
				# a fighter's stance: the free hand up in front as a guard, the knife cuts
				var ph2 := clampf(_act_t / 0.4, 0.0, 1.0)
				var th := sin(ph2 * PI)
				want["upperarm.R"] = Vector3(0.6 + 1.0 * th, 0, -0.3 + 0.6 * th)
				want["forearm.R"] = Vector3(1.2 - 0.8 * th, 0, 0)
				want["upperarm.L"] = Vector3(1.0, 0, 0.35)
				want["forearm.L"] = Vector3(1.0, 0, 0)
	else:
		want.merge(POSE_ITEM_R)
	if not two:
		if l == "radio":
			want.merge(POSE_RADIO_L, true)
		elif l != "":
			want.merge(POSE_ITEM_L, true)
		elif not (rule.get("type", "") == "weapon" and l == "" and not two) and not (act == 2 and rule.get("type", "") == "melee" and not rule.get("blunt", false)):
			want.merge(POSE_LOOSE_L, true)
	elif l == "radio":
		# talking on the radio with a long gun: lowered in the right hand
		want.merge(POSE_RADIO_L, true)
		want["upperarm.R"] = Vector3(0.15, 0, -0.2)
		want["forearm.R"] = Vector3(0.5, 0, 0)
	if act >= 3:
		# down on one knee at the pack / over the wounded: both hands low in front, working
		var w := sin(_act_t * (6.0 if act == 3 else 7.0))
		want["upperarm.R"] = Vector3(0.9 + 0.15 * w, 0, -0.15)
		want["forearm.R"] = Vector3(0.5 + 0.2 * w, 0, 0)
		want["upperarm.L"] = Vector3(0.9 - 0.15 * w, 0, 0.15)
		want["forearm.L"] = Vector3(0.5 - 0.2 * w, 0, 0)
		want["spine"] = Vector3(-0.35, 0, 0)
	for bn in want:
		var i := _bone(bn)
		if i >= 0:
			var rest: Quaternion = _sk.get_bone_rest(i).basis.get_rotation_quaternion()
			_sk.set_bone_pose_rotation(i, rest * Quaternion.from_euler(want[bn]))
	_body_pack(act == 3)

## Others see the pack on the ground in front while he digs in it.
var _ground_pack: Node3D
func _body_pack(on: bool) -> void:
	if not on:
		if _ground_pack:
			_ground_pack.visible = false
		return
	if _ground_pack == null:
		_ground_pack = Node3D.new()
		for part in [[Vector3(0.36, 0.26, 0.14), Vector3(0, 0.13, 0), Color(0.2, 0.21, 0.18)], [Vector3(0.33, 0.02, 0.12), Vector3(0, 0.26, 0), Color(0.55, 0.55, 0.5)]]:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = part[0]
			mi.mesh = bm
			mi.material_override = Game.color_mat(part[2])
			mi.position = part[1]
			_ground_pack.add_child(mi)
		merc_model.add_child(_ground_pack)
		_ground_pack.position = Vector3(0, 0, -0.55)
	_ground_pack.visible = true

# ---- emotes and idling (after Ari's videos): J salute, U at ease; empty hands at rest go
# to the hips and the head looks around -------------------------------------------------------
## 0 nothing, 1 salute, 2 at ease (synced)
var emote := 0
var _emote_t := 0.0
var _idle_t := 0.0
const POSE_SALUTE := {"upperarm.R": Vector3(0.1, 0, 1.35), "forearm.R": Vector3(0, 0, 2.6),
	"upperarm.L": Vector3(0.0, 0, 0.05), "forearm.L": Vector3(0.05, 0, 0)}
const POSE_ATEASE := {"upperarm.R": Vector3(-0.3, 3.1, 0.1), "forearm.R": Vector3(1.5, 0, 0), "upperarm.L": Vector3(-0.3, -3.1, -0.1), "forearm.L": Vector3(1.5, 0, 0),
	"thigh.L": Vector3(0, 0, -0.1), "thigh.R": Vector3(0, 0, 0.1), "shin.L": Vector3(0, 0, 0.1), "shin.R": Vector3(0, 0, -0.1)}
const POSE_HIPS := {"upperarm.R": Vector3(-0.1, 0, 0.8), "forearm.R": Vector3(0, 0, -2.0), "upperarm.L": Vector3(-0.1, 0, -0.8), "forearm.L": Vector3(0, 0, 2.0)}

func _emote_input(delta: float) -> void:
	if Input.is_action_just_pressed("salute"):
		emote = 1
		_emote_t = 2.4
	elif Input.is_action_just_pressed("atease"):
		emote = 0 if emote == 2 else 2
		_emote_t = 9999.0
	if emote != 0:
		_emote_t -= delta
		var moving := Vector2(velocity.x, velocity.z).length() > 0.6
		if _emote_t <= 0.0 or moving or Input.is_action_just_pressed("fire") or busy > 0 or crouching or prone or downed:
			emote = 0

func _emote_pose(delta: float) -> void:
	if _sk == null:
		return
	var want := {}
	if emote == 1:
		want = POSE_SALUTE
	elif emote == 2:
		want = POSE_ATEASE
	if _body_speed < 0.15 and not crouching:
		_idle_t += delta
	else:
		_idle_t = 0.0
	# standing about with empty hands: hands on the hips
	if want.is_empty() and held == "" and held_l == "" and _idle_t > 4.0:
		want = POSE_HIPS
	for bn in want:
		var i := _bone(bn)
		if i >= 0:
			var rest: Quaternion = _sk.get_bone_rest(i).basis.get_rotation_quaternion()
			_sk.set_bone_pose_rotation(i, rest * Quaternion.from_euler(want[bn]))
	# a long wait: the head turns, looks around now and then
	if _idle_t > 3.0 and emote != 1:
		var hi := _bone("head")
		if hi >= 0:
			var look := sin(_idle_t * 0.45) * 0.5 * smoothstep(3.0, 5.0, _idle_t) + sin(_idle_t * 1.3) * 0.05
			var rest2: Quaternion = _sk.get_bone_rest(hi).basis.get_rotation_quaternion()
			_sk.set_bone_pose_rotation(hi, rest2 * Quaternion.from_euler(Vector3(-0.08 * sin(_idle_t * 0.3), look, 0)))

## Owner: what the hands are doing, for the others to see.
func _act_tick() -> void:
	var a := 0
	if busy > 0 and busy_total > 0 and busy_text.begins_with("Přebíj"):
		a = 1
	elif _swing > 0.0:
		a = 2
	elif busy > 0 and busy_stand and busy_text.begins_with("Hrabu"):
		a = 3
	elif busy > 0 and (busy_text.begins_with("Ošetřuji") or busy_text.begins_with("Obvazuji") or busy_text.begins_with("Vyřezávám")):
		a = 4
	if a != act:
		act = a
		_act_t = 0.0

func _build_viewmodel() -> void:
	gun = Node3D.new()
	cam.add_child(gun)
	gun.position = Vector3(0.2, -0.21, -0.36)
	gun_l = Node3D.new()
	cam.add_child(gun_l)
	gun_l.position = VM_ONE_L

var gun_l: Node3D
var body_l: Node3D
var body_back: Node3D
var _shown := "-"

## Models in the hands (first person) and on the body (others): right hand,
## left hand and the weapon slung on the back.
func _show_items(r: String, l: String, back: String) -> void:
	var key := r + "|" + l + "|" + back
	if key == _shown:
		return
	_shown = key
	for holder in [gun, gun_l, body_gun, body_l, body_back]:
		if holder == null:
			continue
		for c in holder.get_children():
			c.queue_free()
	var two := Game.two_handed(r)
	if r != "":
		if gun:
			gun.add_child(_held_model(r))
			if two:
				gun.add_child(Game.model("hands_" + r))
			else:
				var one := Game.model("hand_r")
				one.name = "GripOne"
				gun.add_child(one)
				if Game.ITEMS[r]["type"] == "weapon" and ResourceLoader.exists("res://assets/models/hands_%s.glb" % r):
					var both := Game.model("hands_" + r)
					both.name = "GripTwo"
					both.visible = false
					gun.add_child(both)
		if body_gun:
			body_gun.add_child(_held_model(r, true))
	if l != "" and (not two or l == "radio"):
		if gun_l:
			var lm := _held_model(l)
			if l == "stit":
				lm.position = Vector3(0.05, -0.05, -0.15)
			gun_l.add_child(lm)
			gun_l.add_child(Game.model("hand_l"))
		if body_l:
			body_l.add_child(_held_model(l, true))
	if back != "" and body_back:
		body_back.add_child(Game.model(back))

## A held item's model. Clubs (baton) are held upright, ready to come down.
## Knife: blade up in the fist. Radio: upright, antenna up.
func _held_model(id: String, third := false) -> Node3D:
	var m := Game.model(id)
	if Game.ITEMS.get(id, {}).get("blunt", false):
		m.rotation.x = deg_to_rad(78.0)
		m.position = Vector3(0, 0.01, 0.01)
	elif id == "knife":
		m.rotation.x = deg_to_rad(80.0 if third else 58.0)
	elif id in ["radio", "flare", "scanner"]:
		m.rotation.x = deg_to_rad(80.0 if id == "radio" else 35.0)
	return m

# ---- inventory helpers --------------------------------------------------------------
func item_in(slot: String) -> Dictionary:
	return inv.get(slot, {})

## The gun in a hand (empty if that hand holds no firearm).
func gun_in(slot: String) -> Dictionary:
	var it := item_in(slot)
	if it.is_empty() or Game.ITEMS[it["id"]]["type"] != "weapon":
		return {}
	return it

func weapon() -> Dictionary:
	var w := gun_in("rh")
	return w if not w.is_empty() else gun_in("lh")

func has_scanner() -> bool:
	for s in ["rh", "lh"]:
		var it := item_in(s)
		if not it.is_empty() and it["id"] == "scanner":
			return true
	return false

func carried_weight() -> int:
	var w := int(Game.ITEMS[armor]["weight"]) if armor != "" else 0
	for s in inv:
		w += int(Game.ITEMS[inv[s]["id"]]["weight"])
	return w

## Finds an item; belt before backpack (like UFO, the backpack is slow to reach).
func find_item(pred: Callable) -> String:
	for s in ["lh", "rh", "b0", "b1", "b2", "b3", "p0", "p1", "p2", "p3", "p4", "p5"]:
		var it := item_in(s)
		if not it.is_empty() and pred.call(it):
			return s
	return ""

func _update_held() -> void:
	held = item_in("rh").get("id", "")
	held_l = item_in("lh").get("id", "")
	held_back = item_in("back").get("id", "")
	_show_items(held, held_l, held_back)
	if is_multiplayer_authority():
		gear = _gear_mask()

## Moves an item between two slots, taking time like in UFO: the belt is quick,
## the backpack is a dig (and you stand still while digging).
func timed_move(a: String, b: String) -> bool:
	if a == b or not inv.has(a):
		return false
	var ia: Dictionary = inv[a]
	var ib = inv.get(b)
	# what would the hands hold afterwards?
	var after := inv.duplicate()
	after.erase(a); after.erase(b)
	after[b] = ia
	if ib != null: after[a] = ib
	for sl in after:
		if sl in ["rh", "lh", "back", "side"]:
			var why := Game.slot_refuse(sl, after[sl]["id"])
			if why != "":
				mission.hud.message(why, 2.0)
				return false
	var r: Dictionary = after.get("rh", {})
	var l: Dictionary = after.get("lh", {})
	if not r.is_empty() and Game.two_handed(r["id"]) and not l.is_empty():
		mission.hud.message("Obouruční zbraň potřebuje obě ruce - štít nejdřív odlož.", 2.0)
		return false
	var t: float = Game.fetch_time(ia["id"], a)
	if ib != null:
		t = max(t, Game.fetch_time(ib["id"], b))
	t *= 0.65 if Game.has_talent(merc, "rychle_ruce") else 1.0
	var dig := a.begins_with("p") or b.begins_with("p")
	busy_stand = dig
	if dig:
		_pack_sounds()
	_start_busy(t, ("Hrabu se v batohu" if dig else "Beru") + ": " + Game.ITEMS[ia["id"]]["short"], func():
		busy_stand = false
		if inv.get(a) != ia:
			return
		inv.erase(a); inv.erase(b)
		inv[b] = ia
		if ib != null: inv[a] = ib
		for hs in [a, b]:
			if inv.has(hs) and hs in ["back", "side", "b0", "b1", "b2", "b3"]:
				inv[hs]["home"] = hs
		_update_held()
		Game.play_ui(self, "reload", -16))
	return true

## Where an item taken out by a shortcut came from (medkit by H).
var _came_from := {}
## Q: the slot of what the hands held before Q brought the primary out (Q again brings it back).
var _q_prev := ""

## One thing in the hands at a time. 1 = primary weapon, 2 = secondary, 3-6 = belt; what the
## hands held goes back where it came from (its home), else to the slot it is swapped with,
## else to a free belt/pack slot. Belt and holsters are quick, the backpack is a dig.
func draw_slot(src: String) -> void:
	if busy > 0 or not inv.has(src) or src == "rh":
		return
	var it: Dictionary = inv[src]
	var why := Game.slot_refuse("rh", it["id"])
	if why != "":
		mission.hud.message(why, 2.0)
		return
	var cur := item_in("rh")
	var put := ""
	if not cur.is_empty():
		var home: String = cur.get("home", "")
		if home != "" and home != src and not inv.has(home) and Game.slot_refuse(home, cur["id"]) == "":
			put = home
		elif Game.slot_refuse(src, cur["id"]) == "":
			put = src          # straight swap
		else:
			put = _free_slot([src])
		if put == "":
			mission.hud.message("Není kam uklidit %s." % Game.ITEMS[cur["id"]]["short"], 1.5)
			return
	# a long gun and the shield do not go together: the shield goes off the arm
	var shield_to := ""
	if Game.two_handed(it["id"]) and inv.has("lh"):
		shield_to = _free_slot([src, put])
		if shield_to == "":
			mission.hud.message("S dlouhou zbraní štít neudržíš a není kam ho dát.", 2.0)
			return
	var t: float = Game.fetch_time(it["id"], src)
	if put != "":
		t += Game.fetch_time(cur["id"], put) * 0.6
	t *= 0.65 if Game.has_talent(merc, "rychle_ruce") else 1.0
	var dig := src.begins_with("p") or put.begins_with("p")
	busy_stand = dig
	if dig:
		_pack_sounds()
	if src in ["back", "side", "b0", "b1", "b2", "b3"]:
		it["home"] = src
	_start_busy(t, ("Hrabu se v batohu" if dig else "Beru") + ": " + Game.ITEMS[it["id"]]["short"], func():
		busy_stand = false
		if inv.get(src) != it or (not cur.is_empty() and inv.get("rh") != cur):
			return
		inv.erase(src)
		if not cur.is_empty():
			inv.erase("rh")
			inv[put] = cur
			if put in ["back", "side", "b0", "b1", "b2", "b3"]:
				cur["home"] = put
		if shield_to != "":
			inv[shield_to] = inv["lh"]
			inv.erase("lh")
		inv["rh"] = it
		_update_held()
		Game.play_ui(self, "reload", -16))

## Puts what the hands hold away (home, else a free slot) - hands empty.
func holster() -> void:
	var cur := item_in("rh")
	if cur.is_empty() or busy > 0:
		return
	var home: String = cur.get("home", "")
	var to := home if home != "" and not inv.has(home) else _free_slot([])
	if to == "":
		mission.hud.message("Není kam to uklidit.", 1.5)
		return
	timed_move("rh", to)

## Q: the primary weapon into the hands; Q again brings back what the hands held before.
func _q_swap(_two: bool) -> void:
	var rh := item_in("rh")
	if not rh.is_empty() and rh.get("home", "") == "back":
		if _q_prev != "" and inv.has(_q_prev):
			draw_slot(_q_prev)
		else:
			holster()
		_q_prev = ""
		return
	if not inv.has("back"):
		mission.hud.message("Nemáš primární zbraň (slot 1).", 1.5)
		return
	_q_prev = String(rh.get("home", "")) if not rh.is_empty() else ""
	draw_slot("back")

## Keys 1 and 2: primary / secondary weapon. Pressed again with it in the hands: put it away.
func _weapon_key(slot: String) -> void:
	var rh := item_in("rh")
	if not rh.is_empty() and rh.get("home", "") == slot:
		holster()
		return
	if not inv.has(slot):
		mission.hud.message("Ve slotu %s nic není." % ("1 (primární zbraň)" if slot == "back" else "2 (sekundární zbraň)"), 1.5)
		return
	draw_slot(slot)

func _free_slot(skip: Array) -> String:
	for sl in ["b0", "b1", "b2", "b3", "p0", "p1", "p2", "p3", "p4", "p5"]:
		if not inv.has(sl) and not sl in skip:
			return sl
	return ""

## Throws a thing from the inventory on the ground in front (anyone can pick it up).
func drop_slot(slot: String) -> void:
	if not inv.has(slot) or busy > 0:
		return
	var it: Dictionary = inv[slot]
	inv.erase(slot)
	_update_held()
	mission.drop_item(it, global_position + Vector3(0, 0.3, 0) - global_transform.basis.z * 0.9)
	mission.hud.message("Zahozeno: %s" % Game.ITEMS[it["id"]]["short"], 1.5)

# ---- T: the radio. On the belt it is at hand at once, from the pack it takes a moment.
# Whatever is in the hands goes down first (the left hand lets go, the gun sinks out of
# sight in the right), then the radio comes up; let go of T and the gun comes back up.
# With radios in the helmets (research) nothing of this is needed.
var radio_up := false
var _radio_fetch := 0.0
var _radio_lower := 0.0
var _radio_have := false

var _radio_snd := false
func _radio_tick(delta: float) -> void:
	var held_t := Input.is_action_pressed("radio_talk") and not downed and not dead
	var on := held_t and (radio_up or Game.has_research("vysilacky"))
	if on != _radio_snd:
		_radio_snd = on
		Game.play_at(mission, "radio_click", global_position + Vector3.UP * 1.5, -8)
	if not held_t:
		if radio_up or _radio_fetch > 0.0 or _radio_have:
			radio_up = false
			_radio_have = false
			_radio_fetch = 0.0
			_update_held()
		_radio_lower = move_toward(_radio_lower, 1.0 if emote != 0 else 0.0, delta * 3.5)
		return
	if Game.has_research("vysilacky"):
		return     # in the helmet: no hands needed
	if not _radio_have:
		var where := ""
		for s in ["rh", "b0", "b1", "b2", "b3", "side", "p0", "p1", "p2", "p3", "p4", "p5"]:
			if item_in(s).get("id", "") == "radio":
				where = s
				break
		if where == "":
			if Input.is_action_just_pressed("radio_talk"):
				mission.hud.message("Nemáš vysílačku.", 1.5)
			return
		if where.begins_with("p"):
			if _radio_fetch <= 0.0:
				_radio_fetch = 1.3
				mission.hud.message("Lovím vysílačku z batohu...", 1.3)
			_radio_fetch -= delta
			if _radio_fetch > 0.0:
				_radio_lower = move_toward(_radio_lower, 1.0, delta * 3.5)
				return
		_radio_have = true
	if held == "radio":
		radio_up = true      # the radio itself is in the hands
		return
	# the hands are busy with something: down with it first, then the radio
	var needs_down := held != ""
	_radio_lower = move_toward(_radio_lower, 1.0 if needs_down else 0.0, delta * 3.5)
	if not radio_up and (not needs_down or _radio_lower >= 0.98):
		radio_up = true
		held_l = "radio"
		_show_items(held, "radio", held_back)

## Keys 3-6: a belt slot into the hands (ammunition on the belt reloads instead).
## An empty belt slot takes what the hands hold.
func _belt_key(i: int) -> void:
	var slot := "b%d" % i
	if not inv.has(slot):
		if inv.has("rh"):
			timed_move("rh", slot)
		return
	var id: String = inv[slot]["id"]
	if Game.ITEMS[id]["type"] == "ammo":
		var g := gun_in("rh")
		if not g.is_empty() and Game.ITEMS[g["id"]].get("ammo", "") == id:
			_reload(g, Game.ITEMS[g["id"]])
			return
		mission.hud.message("%s - do ruky se nebere, nabíjí se klávesou R." % Game.ITEMS[id]["short"], 2.0)
		return
	var rh := item_in("rh")
	if not rh.is_empty() and rh.get("home", "") == slot:
		holster()
		return
	draw_slot(slot)

# ---- input (owner only) ------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority() or mission.finished:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# screen pixels, not the low-res viewport: same feel at any window size
		_mouse += event.screen_relative

func _physics_process(delta: float) -> void:
	_blood_watch(delta)
	_mg_tick()
	_drag_sound(delta)
	if not is_multiplayer_authority():
		_remote_visuals()
		return
	_fit_body_shape()
	if dead or mission.finished:
		velocity = Vector3.ZERO
		return
	var inv_open: bool = mission.hud.inventory_open
	# look
	var sens := 0.0012 * Game.mouse_sens * ((0.22 if scoped() else 0.6) if aiming else 1.0)
	rotation.y -= _mouse.x * sens
	pitch = clamp(pitch - _mouse.y * sens * (-1.0 if Game.invert_y else 1.0), -1.4, 1.4)
	_mouse = Vector2.ZERO
	# sway: steady hands come from reactions; stress shakes them
	var shake := (0.25 + stress / 60.0) * (1.6 - float(merc.get("reactions", 45)) / 100.0)
	if Game.has_talent(merc, "pevna_ruka"): shake *= 0.65
	if prone: shake *= 0.5
	_sway = _sway.lerp(Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 0.02, delta * 2.0)
	# breathing after a run: the sights rise and fall, slower as it calms down
	_breath_ph += delta * lerp(1.2, 3.2, breath)
	var bsw := Vector2(sin(_breath_ph * 0.5) * 0.4, sin(_breath_ph)) * breath * 0.035 * (0.6 if aiming else 1.0)
	head.rotation.x = pitch + _sway.y + bsw.y
	head.rotation.y = _sway.x + bsw.x
	# stance
	if downed:
		panic = ""
		_downed(delta)
		return
	if panic != "":
		_panic_tick(delta)
		_stress(delta)
		_bleed(delta)
		_flicker(delta)
		return
	if Input.is_action_just_pressed("crouch") and not inv_open:
		crouching = not crouching
		prone = false
	if Input.is_action_just_pressed("prone") and not inv_open:
		prone = not prone
		crouching = false
		Game.play_at(mission, "prone", global_position, -6 if prone else -10)
		_start_busy(0.8, "Lehám si" if prone else "Vstávám", func(): pass)
		var hv := item_in("rh")
		if prone and not hv.is_empty() and Game.ITEMS[hv["id"]].has("heavy"):
			# nobody crawls with an autocannon: it goes on the back (or down next to you)
			if not inv.has("back"):
				inv["back"] = hv
				hv["home"] = "back"
			else:
				mission.drop_item(hv, global_position + Vector3(0, 0.2, 0) - global_transform.basis.z * 0.6)
			inv.erase("rh")
			_update_held()
			mission.hud.message("S těžkou zbraní se plazit nedá - %s jde %s." % [Game.ITEMS[hv["id"]]["short"], "na záda" if item_in("back") == hv else "k zemi"], 3.0)
	head.position.y = lerp(head.position.y, 0.35 if prone else (1.0 if crouching else 1.6), delta * 6.0)
	var rh := item_in("rh")
	var two := not rh.is_empty() and Game.two_handed(rh["id"])
	var brace_w: bool = two and Game.ITEMS[rh["id"]].get("brace", false)
	# heavy guns are not aimed down a sight: they are pulled in tight to the body
	bracing = brace_w and Input.is_action_pressed("aim") and not inv_open and not sprinting and busy <= 0
	aiming = (two and not brace_w or pistol_grip()) and Input.is_action_pressed("aim") and not inv_open and not sprinting and busy <= 0
	if cam:
		var scoped: bool = aiming and Game.ITEMS[rh["id"]].get("scope", false)
		var zoom := 0.2 if scoped else (0.5 if Game.has_mod(rh.get("id", ""), "optika", merc) else 0.7)
		cam.fov = lerp(cam.fov, Game.fov * zoom if aiming else Game.fov, delta * (14.0 if scoped else 8.0))
		if gun:
			gun.visible = not (scoped and cam.fov < Game.fov * 0.4)
	# move
	var dir := Vector3.ZERO
	if not inv_open:
		var iv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		dir = (transform.basis * Vector3(iv.x, 0, iv.y)).normalized()
	# out of breath: no sprint until the stamina is back over a quarter AND Shift is pressed again
	# (otherwise the regen of a single frame flips sprint on and off - the gun twitches)
	if stamina <= 1.0:
		_winded = true
	if _winded and stamina > 25.0 and not Input.is_action_pressed("sprint"):
		_winded = false
	var sprint := Input.is_action_pressed("sprint") and not _winded and not crouching and not prone and not aiming and dir.length() > 0.1 and not busy_stand
	if _winded and Input.is_action_just_pressed("sprint"):
		mission.hud.message("Nemáš dech.", 1.0)
	sprinting = sprint
	var speed := 0.7 if prone else (CROUCH if crouching else (SPRINT if sprint else WALK))
	if aiming:
		speed *= 0.6
	if bracing:
		speed *= 0.55
	if busy_stand:
		speed = 0.0
	# heavy weapons slow you down
	var heavy: float = Game.ITEMS[rh["id"]].get("heavy", 1.0) if not rh.is_empty() else 1.0
	if Game.has_talent(merc, "tezka_vaha"): heavy = 1.0 - (1.0 - heavy) * 0.5
	speed *= heavy
	var w := carried_weight()
	var strength := float(merc.get("strength", 30)) + (10.0 if Game.has_talent(merc, "mezek") else 0.0)
	if w > strength:
		speed *= max(0.45, strength / float(w))
	if Game.veteran() and hp < max_hp * 0.6:
		speed *= 0.6 + 0.4 * hp / (max_hp * 0.6)   # limping
	var drain := 2600.0 / float(merc.get("stamina", 60)) * (0.6 if Game.has_talent(merc, "sprinter") else 1.0)
	if sprint:
		stamina = max(0.0, stamina - delta * drain)
		breath = min(1.0, breath + delta * 0.22)
	else:
		stamina = min(100.0, stamina + delta * 9.0)
		# breath calms slowly (faster when standing still, crouched or prone)
		var calm := 0.09 * (1.6 if dir.length() < 0.1 else 1.0) * (1.4 if crouching or prone else 1.0)
		if Game.has_talent(merc, "sprinter"): calm *= 1.5
		breath = max(0.0, breath - delta * calm)
	if breath > 0.35:
		_breath_snd -= delta
		if _breath_snd <= 0:
			_breath_snd = lerp(2.6, 1.1, breath)
			Game.play_ui(self, "breath_scared" if stress > 60.0 else "breath", -22 + breath * 12.0)
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Input.is_action_just_pressed("jump") and not crouching and not prone and not inv_open and not busy_stand:
		velocity.y = 4.2
	move_and_slide()
	# footsteps: what you sound like is what the aliens hear
	if is_on_floor() and dir.length() > 0.1:
		step_t -= delta * speed
		if step_t <= 0:
			step_t = 1.6
			var quiet := 0.5 if Game.has_talent(merc, "kocici_krok") else 1.0
			var surf := Game.surface_at(self, global_position, mission.map)
			Game.play_at(self, "step_%s%d" % [surf, randi() % 4], global_position, (-24 if prone else (-19 if crouching else (-7 if sprint else -13))) + float(Game.STEP_DB.get(surf, 0.0)))
			if sprint and randf() < 0.5:
				Game.play_at(self, "gear", global_position + Vector3.UP, -12)   # the kit rattles when you run
			mission.noise(global_position, (1.0 if prone else (2.0 if crouching else (14.0 if sprint else 6.0))) * quiet * mission.step_noise())
	# actions
	fire_cd -= delta
	spread_bloom = max(0.0, spread_bloom - delta * 3.0)
	spin = max(0.0, spin - delta * 0.8)
	_act_tick()
	if busy > 0:
		busy -= delta
		if busy <= 0 and busy_done.is_valid():
			busy_done.call()
		elif Input.is_action_just_pressed("fire") and busy_text.begins_with("Přebíjím po"):
			busy = 0.0       # interrupt single-round reloading to shoot
	elif not inv_open:
		_actions(delta)
	if inv_open:
		_click_lock = true      # a click in a menu must not fire the gun when the menu closes
	_stress(delta)
	_bleed(delta)
	healed_t = maxf(0.0, healed_t - delta)
	_laser_charge(delta)
	_laser_dot()
	if Input.is_action_just_pressed("flashlight"):
		light_on = not light_on
	flash.visible = light_on
	_flicker(delta)
	# evac: E at the Kondor
	gear = _gear_mask()
	_viewmodel_motion(delta, Vector2(velocity.x, velocity.z).length())
	# evac: hold E for two seconds (no accidental take-offs)
	# once you have held E for 2 s you stay "on board" until you step out (others can take their time)
	var at_ship: bool = global_position.distance_to(mission.map["evac"]) < 3.5
	# sabotage: hold E at a beacon to plant a charge
	var bi: int = mission.beacon_near(global_position)
	if bi >= 0 and Input.is_action_pressed("use") and not inv_open and not downed:
		plant_hold += delta
		if plant_hold >= 3.0:
			plant_hold = 0.0
			mission.plant.rpc_id(1, bi)
	else:
		plant_hold = 0.0
	_evac_input(at_ship, inv_open)

## Enter in the ship: "ready to take off" (again = not yet). The wounded on the floor can
## do it too; the dead cannot. Leaving the ship takes it back.
func _evac_input(at_ship: bool, inv_open: bool) -> void:
	if not at_ship:
		wants_evac = false
		return
	if not mission.started() or inv_open or dead:
		return
	if Input.is_action_just_pressed("ready"):
		wants_evac = not wants_evac
		mission.hud.message("PŘIPRAVEN K ODLETU - čeká se na ostatní (Enter = ještě ne)." if wants_evac else "Ještě neodlétáme.", 2.5)
		Game.play_ui(self, "clink", -10)

## Laser sight: a red dot where the gun points (only while the gun is up, not sprinting).
var _dot: MeshInstance3D
func _laser_dot() -> void:
	var w := weapon()
	var on: bool = not w.is_empty() and Game.has_mod(w["id"], "laser", merc) and not sprinting and not mission.hud.inventory_open and not downed
	if _dot == null:
		if not on:
			return
		_dot = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.025
		sm.height = 0.05
		sm.radial_segments = 6
		sm.rings = 3
		_dot.mesh = sm
		_dot.material_override = Game.color_mat(Color(1.0, 0.05, 0.02), true)
		_dot.top_level = true
		add_child(_dot)
	_dot.visible = on
	if not on:
		return
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * 60.0
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 4)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	_dot.visible = not hit.is_empty()
	if not hit.is_empty():
		_dot.global_position = hit["position"]

## Laser cells refill by themselves once the trigger has rested for a moment.
var _since_shot := 9.0
func _laser_charge(delta: float) -> void:
	_since_shot += delta
	if _since_shot < 0.7:
		return
	for s in ["rh", "lh"]:
		var w := gun_in(s)
		if w.is_empty():
			continue
		var r: Dictionary = Game.ITEMS[w["id"]]
		if not r.get("laser", false):
			continue
		var cap := Game.mag_size(w["id"])
		var c: float = float(w.get("charge", 0.0)) + float(r["recharge"]) * delta
		while c >= 1.0 and int(w["loaded"]) < cap:
			w["loaded"] = int(w["loaded"]) + 1
			c -= 1.0
		w["charge"] = c if int(w["loaded"]) < cap else 0.0

var _click_lock := false
func _actions(delta: float) -> void:
	radio_button = false
	var rh := item_in("rh")
	var lh := item_in("lh")
	var two := not rh.is_empty() and Game.two_handed(rh["id"])
	if _click_lock and not Input.is_action_pressed("fire") and not Input.is_action_pressed("aim"):
		_click_lock = false
	if not sprinting and not _click_lock and not radio_up and _radio_lower < 0.05:
		# one thing in the hands: left button uses it, right button aims
		_use_hand("rh", Input.is_action_pressed("fire"), Input.is_action_just_pressed("fire"), delta)
	if Input.is_action_just_pressed("reload"):
		var g := gun_in("rh")
		if not g.is_empty() and g["id"] == "magnum" and int(g.get("loaded", 0)) >= Game.mag_size("magnum") and busy <= 0:
			_twirl = 1.0      # full already: a twirl on the trigger finger (just for show)
			Game.play_ui(self, "swish", -18)
		elif not g.is_empty():
			_reload(g, Game.ITEMS[g["id"]])
	if Input.is_action_just_pressed("swap") and busy <= 0:
		_q_swap(two)
	_radio_tick(delta)
	if Input.is_action_just_pressed("drop") and not mission.hud.inventory_open:
		drop_slot("lh" if inv.has("lh") and not inv.has("rh") else "rh")
	_emote_input(delta)
	if Input.is_action_just_pressed("primary") and busy <= 0:
		_weapon_key("back")
	if Input.is_action_just_pressed("secondary") and busy <= 0:
		_weapon_key("side")
	for i in 4:
		if Input.is_action_just_pressed("belt%d" % (i + 1)):
			_belt_key(i)
	if Input.is_action_just_pressed("grenade"):
		_throw("grenade")
	if Input.is_action_just_pressed("smoke"):
		_throw("smoke_grenade")
	if Input.is_action_just_pressed("mine"):
		_throw("mine")
	if Input.is_action_just_pressed("flare"):
		_throw("flare")
	if Input.is_action_just_pressed("melee"):
		_quick_melee()
	if Input.is_action_just_pressed("heal"):
		_medkit()
	if Input.is_action_just_pressed("use"):
		if not _use_teammate() and not _use_civilian():
			_pick_up()

## What a hand does with its item when its button is pressed.
func _use_hand(slot: String, pressed: bool, just: bool, delta: float) -> void:
	var it := item_in(slot)
	if it.is_empty():
		return
	var rule: Dictionary = Game.ITEMS[it["id"]]
	match rule["type"]:
		"weapon":
			if rule.has("spinup"):
				if pressed:
					if spin <= 0.05 and not _mg_firing:
						_mg_spinup.rpc()
					spin = min(1.0, spin + delta / rule["spinup"] + delta * 0.8)
				if spin < 1.0:
					return
			var trigger := pressed if rule["auto"] else just
			if trigger and fire_cd <= 0:
				if int(it.get("loaded", 0)) > 0:
					_shoot(slot, it, rule)
				elif just:
					Game.play_at(self, "empty", global_position, -6)
					mission.hud.message("Prázdná zbraň - R přebije", 1.5)
		"melee":
			if just and fire_cd <= 0:
				_melee(slot, rule)
		"grenade", "flare":
			if just:
				_throw(it["id"], slot)
		"medkit":
			if just:
				_medkit()
		"radio":
			# hold the button of the hand with the radio = talk on the radio
			if pressed:
				radio_button = true

# ---- shooting ---------------------------------------------------------------------------
## A one-handed gun in the right hand and nothing in the left: held in both hands, aimed like a rifle.
func pistol_grip() -> bool:
	var r := item_in("rh")
	return not r.is_empty() and not inv.has("lh") and Game.ITEMS[r["id"]]["type"] == "weapon" and not Game.two_handed(r["id"])

## Looking through a rifle scope right now (zoomed in).
func scoped() -> bool:
	return aiming and cam != null and Game.ITEMS.get(item_in("rh").get("id", ""), {}).get("scope", false) and cam.fov < Game.fov * 0.4

func current_spread() -> float:
	var wp := gun_in("rh")
	if wp.is_empty():
		wp = gun_in("lh")
	if wp.is_empty():
		return 3.0
	var rule: Dictionary = Game.ITEMS[wp["id"]]
	var s: float = rule["spread"] * (1.7 - float(merc.get("accuracy", 50)) / 100.0) * (2.2 if Game.alien_unknown(wp["id"]) else 1.0)
	if prone: s *= 0.4
	elif crouching: s *= 0.6
	if aiming: s *= 0.5
	elif rule.has("hip"): s *= float(rule["hip"])      # a scoped rifle from the hip goes anywhere
	if not aiming and Game.has_mod(wp["id"], "laser", merc): s *= 0.75
	if aiming and Game.has_mod(wp["id"], "optika", merc): s *= 0.8
	if bracing: s *= 0.55
	if Vector2(velocity.x, velocity.z).length() > 0.5: s *= 1.8
	if not gun_in("rh").is_empty() and not gun_in("lh").is_empty(): s *= 1.35    # two guns at once
	if Game.has_talent(merc, "strelec"): s *= 0.75
	s *= 1.0 + stress / 80.0 + breath * 0.6
	return s + spread_bloom

func _muzzle(slot: String, rule: Dictionary) -> Vector3:
	var holder: Node3D = gun if slot == "rh" else gun_l
	if holder == null:
		return cam.global_position
	var b := cam.global_transform.basis
	return holder.global_position + (-b.z) * float(rule.get("muzzle", 0.3)) + b.y * 0.035

func _shoot(slot: String, wp: Dictionary, rule: Dictionary) -> void:
	wp["loaded"] = int(wp["loaded"]) - 1
	_since_shot = 0.0
	fire_cd = rule["rate"] / (2.0 if slot == "lh" and not gun_in("rh").is_empty() else 1.0)
	_vm_kick = 1.0
	kick_mult = float(rule.get("kick", 1.0))
	var spread := deg_to_rad(current_spread())
	if Game.has_mod(wp["id"], "rukojet", merc):
		kick_mult *= 0.65
	spread_bloom = min(5.0, spread_bloom + 0.7 * kick_mult)
	pitch += (0.012 + randf() * 0.01) * kick_mult * (0.5 if prone else 1.0)
	var from := cam.global_position
	var basis_ := cam.global_transform.basis
	var muzzle := _muzzle(slot, rule)
	mission.noise(global_position, float(rule["noise"]) * (0.35 if Game.has_mod(wp["id"], "tlumic", merc) else 1.0))
	if rule.get("projectile", false):
		var d := (-basis_.z).rotated(basis_.x, randf_range(-spread, spread) * 0.3).normalized()
		mission.fire_rocket.rpc(muzzle, d, name)
		Game.play_at(mission, rule["sound"], muzzle, 2)
		return
	if wp["id"] in ["rifle", "pistol", "sniper", "autocannon", "minigun"]:
		_casing_n += 1
		if not rule.get("auto", false) or _casing_n % 3 == 0:
			var cpos := global_position + global_transform.basis.x * 0.4
			get_tree().create_timer(randf_range(0.35, 0.6)).timeout.connect(func(): if is_instance_valid(self): Game.play_at(mission, "casing", cpos, -16))
	var tracers := []
	var pellets := int(rule.get("pellets", 1))
	# shotgun: the mercenary's aim wanders a little, the pellets spread in a fixed cone around it
	var aim_dir := -basis_.z
	var cone := spread
	if pellets > 1:
		var aim_err := spread * 0.3
		aim_dir = aim_dir.rotated(basis_.x, randf_range(-aim_err, aim_err)).rotated(basis_.y, randf_range(-aim_err, aim_err))
		cone = deg_to_rad(float(rule.get("choke", 3.0)))
	for i in pellets:
		var a1 := randf() * TAU
		var r1 := sqrt(randf()) * cone
		var dir := aim_dir.rotated(basis_.x, sin(a1) * r1).rotated(basis_.y, cos(a1) * r1).normalized() if pellets > 1 \
			else aim_dir.rotated(basis_.x, randf_range(-spread, spread)).rotated(basis_.y, randf_range(-spread, spread)).normalized()
		# friendly fire (host's setting): your bullets do not know who is who
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * 120.0, (1 | 4 | 2 | 8) if (Net.friendly_fire or Game.veteran()) else (1 | 4))
		q.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		var to := from + dir * 120.0
		if hit:
			to = hit.position
			var c: Object = hit.collider
			if c and c.has_method("is_alien"):
				var dmg: float = rule["damage"] * randf_range(0.6, 1.4) * (1.15 if Game.has_research("pitva") else 1.0) * (0.45 if Game.alien_unknown(wp["id"]) else 1.0)
				mission.hud.hitmarker()
				_hit_alien.rpc_id(1, c.name, dmg, "plasma" if wp["id"] == "plasma_rifle" or rule.get("alien", false) else ("laser" if Game.ITEMS[wp["id"]].get("laser", false) else "bullet"))
			elif c and c.has_method("is_player") and not c.dead:
				c.hurt.rpc_id(c.get_multiplayer_authority(), rule["damage"] * randf_range(0.5, 1.0), global_position)
				c.shot_by.rpc_id(c.get_multiplayer_authority(), display_name)
				mission.hud.message("Zasáhl jsi spoluhráče %s!" % c.display_name, 2.0)
			elif c and c.has_method("is_civilian") and not c.dead:
				mission.shoot_civ.rpc_id(1, c.name)
			elif c and c.has_meta("break"):
				mission.hit_breakable.rpc_id(1, int(c.get_meta("break")), float(rule["damage"]), "plasma" if wp["id"] == "plasma_rifle" or Game.ITEMS[wp["id"]].get("laser", false) else "bullet")
			if rule.has("splash"):
				mission.explode.rpc_id(1, to, float(rule["splash"]), float(rule["damage"]) * 0.6, name, false)
		if i < 4:
			tracers.append(to)
	for to in tracers:
		_shot_fx.rpc(muzzle, to, rule["sound"] if to == tracers[0] else "")

## Knife and baton. The knife from behind is deadly, the baton knocks out
## (a living alien is worth more).
func _melee(slot: String, rule: Dictionary) -> void:
	fire_cd = rule["rate"]
	_swing = 1.0
	_swing_left = slot == "lh"
	var blunt: bool = rule.get("blunt", false)
	if blunt:
		# overhead, right-to-left, left-to-right - never the same twice in a row
		var k := randi_range(1, 3)
		if k == _swing_kind:
			k = k % 3 + 1
		_swing_kind = k
		_swing_speed = 1.0 / max(0.35, float(rule["rate"]) * 0.75)
		Game.play_at(self, "swish", global_position + Vector3.UP, -8)
		# the blow lands when the club comes down
		get_tree().create_timer(0.14 / (_swing_speed / 2.2)).timeout.connect(func(): if is_instance_valid(self) and not dead: _melee_hit(rule))
		return
	# knife: a thrust, an overhead stab, a slash across - never the same twice in a row
	var kk: int = [0, 4, 5][randi() % 3]
	if kk == _swing_kind:
		kk = {0: 4, 4: 5, 5: 0}[kk]
	_swing_kind = kk
	_swing_speed = 3.5 if kk == 0 else 2.6
	Game.play_at(self, "swish", global_position + Vector3.UP, -12)
	if kk == 0:
		_melee_hit(rule)
	else:
		get_tree().create_timer(0.16).timeout.connect(func(): if is_instance_valid(self) and not dead: _melee_hit(rule))

func _melee_hit(rule: Dictionary) -> void:
	Game.play_at(self, rule.get("sound", "swish"), global_position + Vector3.UP, -6)
	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * float(rule["reach"]), 1 | 4)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not (Game.has_talent(merc, "tichy_zabijak") and rule.has("backstab")):
		mission.noise(global_position, 3.0)
	if hit and hit.collider and hit.collider.has_meta("break"):
		mission.hit_breakable.rpc_id(1, int(hit.collider.get_meta("break")), float(rule["damage"]) * 0.6, "melee")
	if hit and hit.collider and hit.collider.has_method("is_alien"):
		var a: Node = hit.collider
		var behind: bool = (-a.global_transform.basis.z).dot((a.global_position - global_position).normalized()) > 0.3
		var dmg: float = float(rule["damage"]) * (float(rule.get("backstab", 1.0)) if behind else 1.0)
		if behind and Game.has_talent(merc, "tichy_zabijak") and rule.has("backstab"):
			dmg = 999.0
		var stun: float = float(rule.get("stun", 0.0)) * (1.5 if Game.has_talent(merc, "lovec_hlav") else 1.0)
		mission.hud.hitmarker()
		Game.play_at(mission, "baton_hit" if rule.get("blunt", false) else "knife_stab", hit.position, -2)
		_melee_alien.rpc_id(1, a.name, dmg, stun)

@rpc("any_peer", "call_local", "reliable")
func _melee_alien(alien_name: String, dmg: float, stun: float) -> void:
	if not multiplayer.is_server():
		return
	var a: Node = mission.actors.get_node_or_null(alien_name)
	if a and not a.dead:
		if stun > 0:
			a.stun(stun, global_position, self)
		if dmg > 0:
			a.damage(dmg, global_position, self)

## V: quick melee with whatever blade/baton is in a hand or on the belt.
func _quick_melee() -> void:
	for s in ["rh", "lh"]:
		var it := item_in(s)
		if not it.is_empty() and Game.ITEMS[it["id"]]["type"] == "melee":
			_melee(s, Game.ITEMS[it["id"]])
			return
	var b := find_item(func(it): return Game.ITEMS[it["id"]]["type"] == "melee")
	if b.begins_with("b"):
		# drawn from the belt for one quick strike
		var rule: Dictionary = Game.ITEMS[inv[b]["id"]]
		_start_busy(0.25, "Tasím", func(): _melee("rh", rule))
	else:
		# rifle butt
		_melee("rh", {"damage": 12, "reach": 1.6, "rate": 0.9, "sound": "swish"})

func _start_busy(time: float, text: String, done: Callable) -> void:
	busy_total = time
	busy = time
	busy_text = text
	busy_done = done

@rpc("any_peer", "call_local", "reliable")
func _hit_alien(alien_name: String, dmg: float, kind := "bullet") -> void:
	if not multiplayer.is_server():
		return
	var a: Node = mission.actors.get_node_or_null(alien_name)
	if a and not a.dead:
		mission.hit_kind = kind
		a.damage(dmg, global_position, self)
		mission.hit_kind = ""

@rpc("any_peer", "call_local", "unreliable")
func _shot_fx(from: Vector3, to: Vector3, snd: String) -> void:
	if snd == "minigun":
		_mg_last = Time.get_ticks_msec() / 1000.0      # the firing loop runs while bullets fly
	elif snd != "":
		Game.play_at(mission, snd, from, -2)
		if snd == "shotgun":
			get_tree().create_timer(0.38).timeout.connect(func(): if is_instance_valid(self): Game.play_at(mission, "shotgun_pump", global_position + Vector3.UP, -6))
		elif snd == "sniper":
			get_tree().create_timer(0.55).timeout.connect(func(): if is_instance_valid(self): Game.play_at(mission, "sniper_bolt", global_position + Vector3.UP, -6))
	if multiplayer.is_server() and mission and mission.started():
		var dir := to - from
		var L := dir.length()
		if L > 0.5:
			for a in mission.aliens():
				if a.dead:
					continue
				var rel: Vector3 = a.global_position + Vector3(0, 1.0, 0) - from
				var along := clampf(rel.dot(dir / L), 0.0, L + 3.0)
				if (rel - dir / L * along).length() < 2.5:
					a.suppressed(from)
	var tracer := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var len := from.distance_to(to)
	bm.size = Vector3(0.02, 0.02, len)
	tracer.mesh = bm
	tracer.material_override = Game.color_mat(Color(1.0, 0.85, 0.4), true)
	mission.add_child(tracer)
	tracer.global_position = (from + to) / 2
	if len > 0.01:
		tracer.look_at(to, Vector3.UP if abs((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
	var fl := OmniLight3D.new()
	fl.light_color = Color(1.0, 0.8, 0.4)
	fl.light_energy = 3.0
	fl.omni_range = 6.0
	mission.add_child(fl)
	fl.global_position = from
	get_tree().create_timer(0.05).timeout.connect(func(): tracer.queue_free(); fl.queue_free())

func _reload(wp: Dictionary, rule: Dictionary) -> void:
	var cap := Game.mag_size(wp["id"])
	if int(wp.get("loaded", 0)) >= cap:
		return
	if rule.get("laser", false):
		mission.hud.message("Laser se dobíjí sám - chvíli nestřílej.", 1.5)
		return
	if rule.get("alien", false):
		if int(wp.get("cells", 0)) <= 0:
			mission.hud.message("%s: žádný článek už nezbývá. Odhoď ji (přetáhni v inventáři)." % rule["short"], 2.5)
			return
		var unknown := Game.alien_unknown(wp["id"])
		var ta: float = float(rule["reload"]) * (3.5 if unknown else 1.0) * (0.65 if Game.has_talent(merc, "rychle_prebiti") else 1.0)
		Game.play_at(self, "laser_charge", global_position, -8)
		_start_busy(ta, "Zkouším, jak se to nabíjí" if unknown else "Nabíjím článek", func():
			if not is_instance_valid(self) or dead:
				return
			wp["cells"] = int(wp.get("cells", 0)) - 1
			wp["loaded"] = Game.mag_size(wp["id"])
			Game.play_ui(self, "ping", -12))
		return
	var slot := find_item(func(it): return it["id"] == rule["ammo"])
	if slot == "" or slot == "rh" or slot == "lh":
		slot = ""
		for s2 in ["b0", "b1", "b2", "b3", "p0", "p1", "p2", "p3", "p4", "p5"]:
			if item_in(s2).get("id", "") == rule["ammo"]:
				slot = s2
				break
	if slot == "":
		mission.hud.message("Nemáš náboje do: %s" % rule["name"], 2.0)
		return
	var fast := 0.65 if Game.has_talent(merc, "rychle_prebiti") else 1.0
	var dig := slot.begins_with("p")
	if rule.has("single"):
		# shotgun / revolver: one round at a time (fire interrupts)
		var t: float = float(rule["single"]) * fast + (Game.fetch_time(rule["ammo"], slot) * 0.5 if dig else 0.0)
		if wp == item_in("rh") and inv.has("lh") and _rev_open < 0.05:
			t += 0.5
		Game.play_at(self, "reload", global_position, -12)
		_start_busy(t, "Přebíjím po náboji", func():
			if not inv.has(slot):
				return
			var box: Dictionary = inv[slot]
			box["left"] = int(box.get("left", Game.ITEMS[rule["ammo"]]["rounds"])) - 1
			if int(box["left"]) <= 0:
				inv.erase(slot)
			wp["loaded"] = int(wp["loaded"]) + 1
			Game.play_ui(self, "reload", -18)
			if int(wp["loaded"]) < cap:
				_reload(wp, rule))
		return
	var t2: float = float(rule.get("reload", 1.5)) * fast + (Game.fetch_time(rule["ammo"], slot) if dig else 0.0)
	if wp == item_in("rh") and inv.has("lh") and not Game.two_handed(wp["id"]):
		t2 += 0.6      # the left hand has to put its thing away and take it back
	busy_stand = dig
	# magazine out, (the hand fetches a new one), magazine in
	Game.play_at(self, "mag_out", global_position + Vector3.UP, -4)
	get_tree().create_timer(t2 * 0.25).timeout.connect(func(): _drop_mag())
	get_tree().create_timer(t2 * 0.62).timeout.connect(func(): if is_instance_valid(self) and busy > 0: Game.play_at(mission, "mag_in", global_position + Vector3.UP, -4))
	_start_busy(t2, "Přebíjím" + (" (z batohu)" if dig else ""), func():
		busy_stand = false
		if inv.has(slot):
			inv.erase(slot)
			wp["loaded"] = cap
			Game.play_ui(self, "reload", -18))

# ---- reload animations, after Ari's videos ------------------------------------------------
# Pistol: tilt the gun in, magazine drops out, the left hand brings a new one up and slaps it
# in, the gun rolls on its side and the hand racks the slide, back on target.
# Revolver (top-break): muzzle up, the barrel tips down, empties fall out, the left hand
# feeds the rounds one by one, a flick of the wrist snaps it shut.
var _rl_hand: Node3D
var _rl_carry := ""
var _twirl := 0.0
var _sg_roll := 0.0
var _sg_was := false
var _rev_open := 0.0
var _rev_was := false
var _rev_closing := 0.0
var _rl_last := 0.0
var _lower_left := false
var _lower_l_t := 0.0

func _vm_part(n: String) -> Node3D:
	if gun == null:
		return null
	for c in gun.get_children():
		var f := c.find_child(n, true, false)
		if f:
			if not f.has_meta("rest"):
				f.set_meta("rest", f.transform)
			return f
	return null

func _reload_hand(carry: String) -> Node3D:
	if _rl_hand == null:
		_rl_hand = Game.model("hand_l")
		_rl_hand.top_level = true
		cam.add_child(_rl_hand)
	if carry != _rl_carry:
		_rl_carry = carry
		for c in _rl_hand.get_children():
			if c.name.begins_with("Carry"):
				c.queue_free()
		if carry == "bandage":
			# a white roll, a loose end trailing from it
			var bd := MeshInstance3D.new()
			var bc := CylinderMesh.new()
			bc.top_radius = 0.022
			bc.bottom_radius = 0.022
			bc.height = 0.06
			bc.radial_segments = 10
			bd.mesh = bc
			bd.material_override = Game.color_mat(Color(0.92, 0.9, 0.85))
			bd.name = "Carry"
			bd.position = Vector3(0, 0.03, -0.04)
			bd.rotation = Vector3(0, 0, PI / 2)
			var tail := MeshInstance3D.new()
			var tm := BoxMesh.new()
			tm.size = Vector3(0.05, 0.18, 0.004)
			tail.mesh = tm
			tail.material_override = bd.material_override
			tail.position = Vector3(0, -0.1, 0.02)
			bd.add_child(tail)
			_rl_hand.add_child(bd)
		elif carry == "shell":
			# a red shotgun shell with a brass base
			var sh := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.0105
			cm.bottom_radius = 0.0105
			cm.height = 0.065
			cm.radial_segments = 8
			sh.mesh = cm
			sh.material_override = Game.color_mat(Color(0.7, 0.12, 0.08))
			sh.name = "Carry"
			sh.position = Vector3(0, 0.02, -0.04)
			sh.rotation = Vector3(PI / 2, 0, 0)
			var base := MeshInstance3D.new()
			var bm := CylinderMesh.new()
			bm.top_radius = 0.011
			bm.bottom_radius = 0.011
			bm.height = 0.015
			bm.radial_segments = 8
			base.mesh = bm
			base.material_override = Game.color_mat(Color(0.75, 0.6, 0.25))
			base.position = Vector3(0, -0.035, 0)
			sh.add_child(base)
			_rl_hand.add_child(sh)
		elif carry != "":
			var m := Game.model(carry)
			m.name = "Carry"
			_rl_hand.add_child(m)
	return _rl_hand

## Zip open, then the hand rummages.
func _pack_sounds() -> void:
	Game.play_at(mission, "backpack_zip", global_position + Vector3.UP, -6)
	get_tree().create_timer(0.5).timeout.connect(func(): if is_instance_valid(self) and busy > 0: Game.play_at(mission, "backpack_rummage", global_position + Vector3.UP, -6))

## The backpack swung round to the front while digging in it (first person).
var _pack_node: Node3D
var _pack_t := 0.0
func _vm_pack(on: bool, delta: float) -> void:
	_pack_t = move_toward(_pack_t, 1.0 if on else 0.0, delta * 4.0)
	if _pack_t <= 0.0:
		if _pack_node:
			_pack_node.visible = false
		return
	if _pack_node == null:
		_pack_node = Node3D.new()
		var dark := Game.color_mat(Color(0.2, 0.21, 0.18))
		var inner := Game.color_mat(Color(0.55, 0.55, 0.5))
		for part in [[Vector3(0.36, 0.13, 0.26), Vector3.ZERO, dark], [Vector3(0.33, 0.01, 0.23), Vector3(0, 0.066, 0), inner],
				[Vector3(0.36, 0.25, 0.02), Vector3(0, 0.18, 0.13), dark], [Vector3(0.33, 0.23, 0.01), Vector3(0, 0.18, 0.118), inner]]:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = part[0]
			mi.mesh = bm
			mi.material_override = part[2]
			mi.position = part[1]
			_pack_node.add_child(mi)
		cam.add_child(_pack_node)
	_pack_node.visible = true
	var k := smoothstep(0.0, 1.0, _pack_t)
	_pack_node.position = Vector3(0.0, -0.75, -0.3).lerp(Vector3(0.0, -0.29, -0.42), k)
	_pack_node.rotation = Vector3(0.75, 0, 0)

## Returns [position offset, rotation offset] for the gun, and moves slide, magazine,
## barrel and the reloading hand.
func _reload_anim(delta: float, rid: String, reloading: bool) -> Array:
	var dp := Vector3.ZERO
	var dr := Vector3.ZERO
	var hand_on := false
	var hand_at := Vector3.ZERO
	var hand_rot := Vector3(0.7, 0.0, 0.0)
	var ph := 1.0 - busy / busy_total if busy_total > 0 else 0.0
	if rid == "pistol":
		var slide := _vm_part("Slide")
		var mag := _vm_part("Mag")
		var down := Vector3(0, -0.969, 0.247)      # along the grip, out of the gun
		var mag_off := 0.0
		var slide_back := _vm_kick * 0.02          # the slide also kicks back on every shot
		if reloading:
			var tilt := smoothstep(0.0, 0.12, ph) * (1.0 - smoothstep(0.55, 0.64, ph))
			var side := smoothstep(0.55, 0.66, ph) * (1.0 - smoothstep(0.86, 0.98, ph))
			dp = Vector3(-0.13, 0.17, -0.06) * tilt + Vector3(-0.12, 0.12, -0.1) * side
			dr = Vector3(0.12, 0.3, 0.45) * tilt + Vector3(0.05, -0.1, 0.95) * side
			# old magazine drops (0.12-0.25), gun empty, the new one goes in (0.38-0.55)
			if ph < 0.12: mag_off = 0.0
			elif ph < 0.25: mag_off = smoothstep(0.12, 0.25, ph) * 0.18
			elif ph < 0.38: mag_off = 1.0
			elif ph < 0.55: mag_off = 0.11 * (1.0 - smoothstep(0.42, 0.55, ph))
			if mag:
				mag.visible = mag_off < 0.9
			# the left hand: up from below with the spare (0.22-0.38), pushes it in, then racks
			if ph > 0.2 and ph < 0.58 and mag and slide:
				hand_on = true
				var mrest: Transform3D = mag.get_meta("rest")
				var bottom: Vector3 = gun.global_transform * (mrest.origin + down * (0.05 + maxf(mag_off, 0.11 if ph < 0.38 else mag_off)))
				var from_below: Vector3 = cam.global_transform * Vector3(-0.08, -0.5, -0.35)
				hand_at = from_below.lerp(bottom, smoothstep(0.2, 0.36, ph))
				_reload_hand("pistol_mag" if ph < 0.38 else "")
			elif ph > 0.62 and ph < 0.92 and slide:
				hand_on = true
				var top: Vector3 = slide.global_transform * Vector3(0, 0.03, -0.01)
				var from_side: Vector3 = cam.global_transform * Vector3(-0.3, -0.3, -0.3)
				hand_at = from_side.lerp(top, smoothstep(0.62, 0.7, ph)).lerp(from_side, smoothstep(0.84, 0.92, ph))
				hand_rot = Vector3(0.0, -0.3, 0.2)
				_reload_hand("")
				slide_back = 0.04 * smoothstep(0.7, 0.78, ph) * (1.0 - smoothstep(0.8, 0.82, ph))
			# sounds on the beats of the video: magazine seated, slide released
			if _rl_last < 0.52 and ph >= 0.52:
				pass      # (the magazine sounds come from the reload itself)
			if _rl_last < 0.8 and ph >= 0.8:
				Game.play_ui(self, "pistol_slide", -4)
			_rl_last = ph
		elif mag:
			mag.visible = true
			_rl_last = 0.0
		if mag:
			var r0: Transform3D = mag.get_meta("rest")
			mag.position = r0.origin + down * clampf(mag_off, 0.0, 0.2)
		if slide:
			var s0: Transform3D = slide.get_meta("rest")
			slide.position = s0.origin + Vector3(0, 0, slide_back)
	elif rid == "shotgun":
		var single2 := reloading and busy_text.begins_with("Přebíjím po")
		_sg_roll = move_toward(_sg_roll, 1.0 if single2 else 0.0, delta * 5.0)
		var o2 := smoothstep(0.0, 1.0, _sg_roll)
		# the gun rolls onto its side (loading port up to the hand), muzzle a little down
		dp = Vector3(-0.06, 0.03, 0.02) * o2
		dr = Vector3(-0.15, 0.25, 1.1) * o2
		if single2 and _sg_roll > 0.6:
			hand_on = true
			var port: Vector3 = gun.global_transform * Vector3(0.0, -0.06, -0.12)
			var from_belt: Vector3 = cam.global_transform * Vector3(-0.12, -0.5, -0.25)
			hand_at = from_belt.lerp(port, smoothstep(0.05, 0.5, ph)).lerp(from_belt, smoothstep(0.75, 1.0, ph))
			hand_rot = Vector3(0.9, -0.3, 1.0)
			_reload_hand("shell" if ph < 0.65 else "")
			if _rl_last < 0.55 and ph >= 0.55:
				Game.play_ui(self, "shell_insert", -6)
			_rl_last = ph
			if ph < 0.05:
				_rl_last = 0.0
		elif _sg_was and not single2:
			Game.play_ui(self, "shotgun_pump", -4)     # the pump racked at the end
		_sg_was = single2
	elif rid == "magnum":
		var barrel := _vm_part("Barrel")
		var single := reloading and busy_text.begins_with("Přebíjím po")
		if single and not _rev_was:
			_rev_was = true
			_eject_empties()
		if single:
			_rev_open = minf(1.0, _rev_open + delta * 4.0)
			_rev_closing = 0.0
		elif _rev_was:
			_rev_was = false
			_rev_closing = 0.35
			Game.play_ui(self, "revolver_close", -2)      # snapped shut
		if _rev_closing > 0.0:
			_rev_closing -= delta
			_rev_open = maxf(0.0, _rev_open - delta * 6.0)
		var o := smoothstep(0.0, 1.0, _rev_open)
		dp = Vector3(-0.1, 0.08, -0.07) * o
		dr = Vector3(0.75, 0.35, 0.25) * o + Vector3(0.25, 0, 0) * (_rev_closing / 0.35 if _rev_closing > 0 else 0.0)
		if barrel:
			var b0: Transform3D = barrel.get_meta("rest")
			barrel.transform = b0 * Transform3D(Basis(Vector3.RIGHT, -1.1 * o), Vector3.ZERO)
			if single and _rev_open >= 1.0:
				# one round: the hand brings it from the belt and pushes it into a chamber
				hand_on = true
				var chamber: Vector3 = barrel.global_transform * Vector3(0.012, 0.019, 0.07) + cam.global_transform.basis * Vector3(-0.03, -0.045, 0.03)
				var from_low: Vector3 = cam.global_transform * Vector3(-0.15, -0.45, -0.3)
				hand_at = from_low.lerp(chamber, smoothstep(0.0, 0.55, ph)).lerp(from_low, smoothstep(0.85, 1.0, ph))
				hand_rot = Vector3(0.4, -0.2, 0.0)
				_reload_hand("round" if ph < 0.8 else "")
	# digging in the backpack (it comes round to the front, the hand rummages in it) and
	# bandaging (a roll of bandage wound round and round) - after Ari's videos
	var digging := busy > 0 and busy_stand and busy_text.begins_with("Hrabu")
	var wrapping := busy > 0 and (busy_text.begins_with("Ošetřuji") or busy_text.begins_with("Obvazuji"))
	_vm_pack(digging, delta)
	if digging and _pack_node:
		hand_on = true
		var tt := Time.get_ticks_msec() / 1000.0
		hand_at = _pack_node.global_transform * Vector3(sin(tt * 5.0) * 0.07, 0.06 + absf(sin(tt * 3.3)) * 0.06, cos(tt * 4.1) * 0.04)
		hand_rot = Vector3(1.3, 0.2, 0.3)
		_reload_hand("medkit" if ph > 0.75 else "")
	elif wrapping:
		hand_on = true
		var tw := Time.get_ticks_msec() / 1000.0 * 6.5
		hand_at = cam.global_transform * Vector3(-0.02 + cos(tw) * 0.07, -0.26 + sin(tw) * 0.05, -0.36)
		hand_rot = Vector3(0.6, 0.3 * sin(tw), 0.8)
		_reload_hand("bandage")
	if _rl_hand:
		_rl_hand.visible = hand_on
		if hand_on:
			_rl_hand.global_position = hand_at
			_rl_hand.global_transform.basis = cam.global_transform.basis * Basis.from_euler(hand_rot)
	return [dp, dr]

## The revolver breaks open: the empties fall out.
func _eject_empties() -> void:
	var barrel := _vm_part("Barrel")
	if barrel == null or not is_inside_tree():
		return
	Game.play_at(mission, "revolver_open", global_position + Vector3.UP, -2)
	get_tree().create_timer(0.25).timeout.connect(func(): if is_instance_valid(self): Game.play_at(mission, "casings", global_position, -6))
	for i in 5:
		var b := RigidBody3D.new()
		b.collision_layer = 0
		b.collision_mask = 1
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(0.01, 0.01, 0.03)
		cs.shape = sh
		b.add_child(cs)
		b.add_child(Game.model("round"))
		mission.add_child(b)
		b.global_position = barrel.global_transform * Vector3(randf_range(-0.01, 0.01), 0.02, 0.05)
		b.linear_velocity = velocity + Vector3(randf_range(-0.4, 0.4), -0.5, randf_range(-0.2, 0.4))
		b.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), 0)
		get_tree().create_timer(12.0).timeout.connect(b.queue_free)

func _drop_mag() -> void:
	if gun == null or not is_inside_tree():
		return
	var m := RigidBody3D.new()
	m.collision_layer = 0
	m.collision_mask = 1
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.03, 0.12, 0.05)
	cs.shape = sh
	m.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sh.size
	mi.mesh = bm
	mi.material_override = Game.color_mat(Color(0.06, 0.06, 0.065))
	m.add_child(mi)
	mission.add_child(m)
	m.global_position = gun.global_position + Vector3(0, -0.1, 0)
	m.linear_velocity = velocity + Vector3(0, -1, 0)
	get_tree().create_timer(20.0).timeout.connect(m.queue_free)
	Game.play_at(mission, "clink", m.global_position, -10)

# ---- grenades and flares -----------------------------------------------------------------
func _throw(kind: String, from_slot := "") -> void:
	var slot := from_slot
	if slot == "":
		slot = find_item(func(it): return it["id"] == kind)
	if slot == "":
		mission.hud.message("Nemáš: %s" % Game.ITEMS[kind]["name"], 1.5)
		return
	var t := 0.4 if (slot == "lh" or slot == "rh") else Game.fetch_time(kind, slot) + 0.3
	busy_stand = slot.begins_with("p")
	_start_busy(t, "Házím" if kind != "mine" else "Pokládám minu", func():
		busy_stand = false
		if not inv.has(slot):
			return
		inv.erase(slot)
		_update_held()
		var dir := -cam.global_transform.basis.z
		var from := cam.global_position + dir * 0.5
		var v := dir * 13.0 + Vector3.UP * 3.0
		if kind == "mine":
			v = dir * 3.0 + Vector3.UP * 1.0
		_spawn_throwable.rpc(kind, from, v, name))

@rpc("any_peer", "call_local", "reliable")
func _spawn_throwable(kind: String, from: Vector3, vel: Vector3, thrower: String) -> void:
	var rb := RigidBody3D.new()
	rb.collision_layer = 8
	rb.collision_mask = 1
	rb.mass = 0.5
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.08
	cs.shape = sh
	rb.add_child(cs)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.08; sm.height = 0.16
	mi.mesh = sm
	rb.add_child(mi)
	mission.add_child(rb)
	rb.global_position = from
	rb.linear_velocity = vel
	if kind == "smoke_grenade":
		mi.material_override = Game.color_mat(Color(0.45, 0.46, 0.44))
		get_tree().create_timer(1.5).timeout.connect(func():
			if is_instance_valid(rb):
				Game.play_at(mission, "smoke_pop", rb.global_position, -2)
				mission.add_smoke(rb.global_position)
				get_tree().create_timer(2.0).timeout.connect(rb.queue_free))
		return
	if kind == "mine":
		mi.visible = false
		var mm := Game.model("mine")
		rb.add_child(mm)
		mm.position.y = -0.05
		get_tree().create_timer(1.2).timeout.connect(func():
			if is_instance_valid(rb):
				var p := rb.global_position
				rb.queue_free()
				mission.add_mine(p, thrower))
		return
	if kind == "flare":
		mi.material_override = Game.color_mat(Color(1.0, 0.25, 0.2), true)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.35, 0.25)
		l.light_energy = 2.5
		l.omni_range = 11.0
		rb.add_child(l)
		# struck, then it fizzes and burns as long as it lies there
		Game.play_at(mission, "flare_strike", from, -4)
		var burn := AudioStreamPlayer3D.new()
		var bst: AudioStreamWAV = (Game.sound("flare_burn") as AudioStreamWAV).duplicate()
		bst.loop_mode = AudioStreamWAV.LOOP_FORWARD
		bst.loop_begin = 0
		bst.loop_end = int(bst.get_length() * bst.mix_rate)
		burn.stream = bst
		burn.unit_size = 3.0
		burn.max_distance = 30.0
		burn.volume_db = -8.0
		burn.bus = "Ambient"
		rb.add_child(burn)
		get_tree().create_timer(1.2).timeout.connect(func(): if is_instance_valid(burn): burn.play())
		get_tree().create_timer(60.0).timeout.connect(rb.queue_free)
	else:
		mi.material_override = Game.color_mat(Color(0.25, 0.3, 0.2))
		get_tree().create_timer(2.5).timeout.connect(func():
			if not is_instance_valid(rb):
				return
			var p := rb.global_position
			rb.queue_free()
			_explosion_fx(p)
			if multiplayer.is_server():
				mission.noise(p, 40.0)
				mission.blast_breakables(p, 4.0, 160.0)
				for a in mission.aliens():
					var d: float = a.global_position.distance_to(p)
					if d < 5.0 and not a.dead:
						mission.hit_kind = "explosion"
						a.damage(90.0 * (1.0 - d / 5.0) + 10.0, p, mission.actors.get_node_or_null(thrower))
						mission.hit_kind = ""
				for pl in mission.players():
					var d2: float = pl.global_position.distance_to(p)
					if d2 < 5.0:
						pl.hurt.rpc_id(pl.get_multiplayer_authority(), 60.0 * (1.0 - d2 / 5.0), p))

func _explosion_fx(p: Vector3) -> void:
	Game.play_at(mission, "explosion_big", p, 4)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.2)
	l.light_energy = 8.0
	l.omni_range = 14.0
	mission.add_child(l)
	l.global_position = p + Vector3.UP
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.8; sm.height = 3.6; sm.radial_segments = 8; sm.rings = 4
	ball.mesh = sm
	ball.material_override = Game.color_mat(Color(1.0, 0.55, 0.15), true)
	mission.add_child(ball)
	ball.global_position = p + Vector3.UP * 0.5
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.6)
	tw.parallel().tween_property(ball, "scale", Vector3(0.1, 0.1, 0.1), 0.4)
	tw.tween_callback(func(): l.queue_free(); ball.queue_free())

# ---- wounds ---------------------------------------------------------------------------------
@rpc("any_peer", "call_local", "reliable")
func shot_by(who: String) -> void:
	mission.hud.message("Trefil tě %s!" % who, 2.5)

@rpc("any_peer", "call_local", "reliable")
func hurt(dmg: float, from: Vector3) -> void:
	if not is_multiplayer_authority() or dead:
		return
	if Game.easy():
		dmg *= 0.7
	if downed:
		bleed_left -= dmg * 0.5
		return
	if armor != "":
		dmg *= float(Game.ITEMS[armor].get("protect", 1.0))
	# a shield in the left hand stops most of what comes from the front
	if item_in("lh").get("id", "") == "stit" and from.distance_to(global_position) > 1.5:
		var to: Vector3 = (from - global_position)
		to.y = 0
		if to.length() > 0.1 and (-global_transform.basis.z).dot(to.normalized()) > 0.45:
			dmg *= 0.25
			Game.play_at(self, "clink", global_position + Vector3.UP, -2)
	hp -= dmg
	wounded = true
	stress = min(100.0, stress + dmg * (1.4 - float(merc.get("bravery", 40)) / 100.0) * 2.0)
	if dmg > 6.0:
		bleeding += 0.25
	Game.play_ui(self, "hurt_female" if merc.get("look", {}).get("female", false) else "hurt_male", -4)
	mission.hud.damage_flash(from)
	if hp <= 0:
		hp = 0
		downed = true
		bleed_left = BLEED_OUT
		crouching = true
		light_on = false
		mission.hud.message("PADL JSI! Krvácíš - spoluhráč tě musí ošetřit (E s lékárničkou) nebo odnést.", 6.0)
		Game.play_ui(self, "death_female" if merc.get("look", {}).get("female", false) else "death_male", -6)

func _bleed(delta: float) -> void:
	if bleeding > 0 and not downed:
		hp -= bleeding * delta
		if hp <= 0:
			hurt(0.1, global_position)

func _downed(delta: float) -> void:
	head.position.y = lerp(head.position.y, 0.35, delta * 4.0)
	healed_t = maxf(0.0, healed_t - delta)
	if healed_t <= 0.0:
		bleed_left -= delta      # while a medic works on you, you do not bleed out
	if bleed_left <= 0:
		dead = true
		wants_evac = false
		mission.hud.message("Vykrvácel jsi.", 8.0)
		return
	_evac_input(global_position.distance_to(mission.map["evac"]) < 3.5, mission.hud.inventory_open)
	# being dragged by a teammate
	if carried_by > 0:
		var c: Node = mission.actors.get_node_or_null("P%d" % carried_by)
		if c and not c.downed:
			var target: Vector3 = c.global_position - c.global_transform.basis.z * -1.0
			global_position = global_position.lerp(target, delta * 6.0)
			return
		carried_by = 0
	elif carried_by < 0:
		# something is dragging you into the dark
		var a: Node = mission.actors.get_node_or_null("A%d" % (-carried_by - 1))
		if a and not a.dead:
			var target: Vector3 = a.global_position + a.global_transform.basis.z * 0.9
			global_position = global_position.lerp(target, delta * 6.0)
			return
		carried_by = 0
	# crawl
	var iv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(iv.x, 0, iv.y)).normalized()
	velocity = dir * 0.5
	velocity.y -= GRAVITY * delta
	move_and_slide()

@rpc("any_peer", "call_local", "reliable")
func revived(by: String) -> void:
	if not is_multiplayer_authority() or dead:
		return
	downed = false
	carried_by = 0
	infected = false
	healed_t = 0.0
	hp = max(8.0, max_hp * 0.3)
	bleeding = 0
	crouching = true
	mission.hud.message("%s tě ošetřil. Jsi zraněný, ale na nohou." % by, 4.0)

@rpc("any_peer", "call_local", "reliable")
func set_carried(by_peer: int) -> void:
	if is_multiplayer_authority() and downed:
		carried_by = by_peer

## H (or the hand's button): the medkit must be in a hand. A teammate in reach is treated
## first (bandage the hurt, bring the downed back), otherwise yourself. Not in a hand: H takes it.
func _medkit() -> void:
	var slot := ""
	for s in ["lh", "rh"]:
		if item_in(s).get("id", "") == "medkit" and int(item_in(s).get("uses", 1)) > 0:
			slot = s
	if slot == "":
		var from := find_item(func(it): return it["id"] == "medkit" and int(it.get("uses", 1)) > 0)
		if from == "":
			mission.hud.message("Nemáš lékárničku.", 1.5)
			return
		mission.hud.message("Beru lékárničku do rukou - H ošetří, Q vrátí zbraň.", 2.5)
		_came_from["medkit"] = from
		_q_prev = ""
		draw_slot(from)
		return
	if heal_target() != null:
		_treat_teammate(slot)
	else:
		_heal_self()

func _heal_self() -> void:
	var slot := find_item(func(it): return it["id"] == "medkit" and int(it.get("uses", 0)) > 0)
	if slot == "":
		mission.hud.message("Nemáš lékárničku.", 1.5)
		return
	if hp >= max_hp and bleeding <= 0:
		return
	Game.play_ui(self, "bandage", -6)
	_start_busy(3.0, "Ošetřuji se", func():
		if not inv.has(slot): return
		inv[slot]["uses"] = int(inv[slot]["uses"]) - 1
		if int(inv[slot]["uses"]) <= 0: inv.erase(slot)
		hp = min(max_hp, hp + (20.0 if Game.has_talent(merc, "felcar") else 10.0))
		bleeding = 0.0)

## The teammate E would help right now: down (first) or hurt, within reach.
func heal_target() -> Node:
	var best: Node = null
	var bd := 2.8
	for p in mission.players():
		if p == self or p.dead:
			continue
		var d := Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()
		if absf(p.global_position.y - global_position.y) > 1.5:
			continue
		var need: bool = p.downed or p.hp < p.max_hp - 1.0
		if need and (d < bd or (p.downed and best and not best.downed and d < 2.8)):
			if best == null or p.downed or not best.downed:
				bd = d
				best = p
	return best

func has_medkit() -> bool:
	return find_item(func(it): return it["id"] == "medkit" and int(it.get("uses", 1)) > 0) != ""

## E next to a downed teammate: drag him (treating is H with the medkit in hand).
func _use_teammate() -> bool:
	var best := heal_target()
	if best == null or not best.downed:
		return false
	var me := get_multiplayer_authority()
	best.set_carried.rpc_id(best.get_multiplayer_authority(), 0 if best.carried_by == me else me)
	mission.hud.message("Táhneš %s (k lodi, nebo ošetři: lékárnička do ruky a H)" % best.display_name if best.carried_by != me else "Pustil jsi %s" % best.display_name, 2.5)
	return true

func _treat_teammate(slot: String) -> void:
	var best := heal_target()
	if true:
		var target := best
		var heal_time := 2.0 if Game.has_talent(merc, "felcar") else 3.0
		if best.infected and not Game.has_research("pitva_lihnoun"):
			heal_time *= 1.6     # cutting the seed out takes time
		var verb := "Vyřezávám zárodek - %s" if best.infected else ("Ošetřuji %s" if best.downed else "Obvazuji %s")
		target.being_healed.rpc_id(target.get_multiplayer_authority(), display_name, heal_time)
		Game.play_at(mission, "bandage", global_position + Vector3.UP, -6)
		_start_busy(heal_time, verb % best.display_name, func():
			if not is_instance_valid(target) or target.dead:
				return
			if Vector2(target.global_position.x - global_position.x, target.global_position.z - global_position.z).length() > 3.6:
				mission.hud.message("%s je moc daleko." % target.display_name, 2.0)
				return
			if inv.has(slot):
				inv[slot]["uses"] = int(inv[slot].get("uses", 1)) - 1
				if int(inv[slot]["uses"]) <= 0: inv.erase(slot)
			revives += 1
			if target.downed:
				target.revived.rpc_id(target.get_multiplayer_authority(), display_name)
			else:
				target.patched.rpc_id(target.get_multiplayer_authority(), display_name, 20.0 if Game.has_talent(merc, "felcar") else 10.0))

## A teammate has started treating you (shown on your screen).
var healed_by := ""
var healed_t := 0.0
var healed_total := 1.0
@rpc("any_peer", "call_local", "reliable")
func being_healed(by: String, secs: float) -> void:
	if not is_multiplayer_authority():
		return
	healed_by = by
	healed_t = secs
	healed_total = secs

## A teammate bandaged you (not down, just hurt).
@rpc("any_peer", "call_local", "reliable")
func patched(by: String, amount: float) -> void:
	if not is_multiplayer_authority() or dead:
		return
	hp = min(max_hp, hp + amount)
	bleeding = 0.0
	healed_t = 0.0
	mission.hud.message("%s tě obvázal." % by, 2.5)

# ---- radio ------------------------------------------------------------------------------------
## Hears the radio: a handheld anywhere on you, or the helmet set (research).
func has_radio() -> bool:
	return Game.has_research("vysilacky") or find_item(func(it): return it["id"] == "radio") != ""

## Can talk on the radio right now: the handheld must be in a hand.
func radio_tx() -> bool:
	if dead:
		return false
	if Game.has_research("vysilacky"):
		return true
	if radio_up:
		return true
	for s in ["rh", "lh"]:
		if item_in(s).get("id", "") == "radio":
			return true
	return false

## E next to a frightened civilian: "come with me" - he follows you to the Kondor.
func _use_civilian() -> bool:
	for c in mission.civilians():
		if not c.dead and not c.saved and c.global_position.distance_to(global_position) < 2.4:
			mission.calm_civ.rpc_id(1, c.name, name)
			mission.hud.message("\"Pojďte za mnou, dovedu vás k lodi.\"", 2.5)
			return true
	return false

## A Líhnoun's claw leaves something inside (only matters once you are down).
@rpc("any_peer", "call_local", "reliable")
func implant() -> void:
	if not is_multiplayer_authority() or dead:
		return
	if not infected:
		infected = true
	if downed:
		# it grows fast: much less time for the medic
		bleed_left = min(bleed_left, 22.0)
		mission.hud.message("Něco se ti hýbe pod kůží. Ošetření hned, nebo vstaneš jako jeden z nich.", 6.0)

## Kněz reaches into your mind. Brave mercenaries shrug it off; others panic,
## and the weakest lose their hands to it for a few seconds.
@rpc("any_peer", "call_local", "reliable")
func psi_attack(roll: float) -> void:
	if not is_multiplayer_authority() or dead or downed:
		return
	var brave := float(merc.get("bravery", 40)) / 100.0
	stress = min(100.0, stress + 30.0 * (1.3 - brave))
	if Game.autotest() != "": print("[PSI] roll %.2f brave %.2f" % [roll, brave])
	Game.play_ui(self, "psi", -2)
	mission.hud.psi_flash()
	var resist := brave * 0.8 + (0.15 if Game.has_talent(merc, "zelezne_nervy") else 0.0) + (0.15 if Game.has_research("vyslech") else 0.0) + (0.3 if Game.has_research("psi_clona") else 0.0)
	if roll < resist or panic != "":
		mission.hud.message("Cizí hlas v hlavě. Odolal jsi.", 3.0)
		return
	if roll > 0.75 and not weapon().is_empty():
		panic = "berserk"
		panic_t = 5.0
		mission.hud.message("NĚCO TI OVLÁDÁ RUCE!", 4.0)
	else:
		panic = "flee"
		panic_t = 4.0
		_panic_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		mission.hud.message("Hlas ti šeptá: UTEČ.", 3.0)
	Game.play_ui(self, "heartbeat", 0)

## Mysloděj tears at your mind: real pain, blood from the nose.
@rpc("any_peer", "call_local", "reliable")
func psi_blast(dmg: float) -> void:
	if not is_multiplayer_authority() or dead or downed:
		return
	if Game.has_research("psi_clona"):
		dmg *= 0.6
	mission.hud.psi_flash()
	Game.play_ui(self, "psi", 0)
	mission.hud.message("Hlava ti třeští. Teče ti krev z nosu.", 3.0)
	hurt(dmg, global_position + Vector3(0, 1, 0))

# ---- fear ---------------------------------------------------------------------------------------
func _stress(delta: float) -> void:
	var gain := 0.0
	for a in mission.aliens():
		if a.dead:
			continue
		var d: float = a.global_position.distance_to(global_position)
		if d < 13.0:
			gain += (13.0 - d) * 0.35      # you cannot see it, but you feel it
		if d < 16.0 and a.visible_to(self):
			gain += (16.0 - d) * 0.6
	for p in mission.players():
		if p != self and p.downed and p.global_position.distance_to(global_position) < 20.0:
			gain += 2.0
	if not light_on:
		gain += 0.4
	gain *= 1.3 - float(merc.get("bravery", 40)) / 100.0
	if Game.has_talent(merc, "zelezne_nervy"): gain *= 0.6
	stress = clamp(stress + (gain - 2.5) * delta, 0.0, 100.0)
	if stress > 45:
		_hb -= delta
		if _hb <= 0:
			_hb = 1.1 - stress / 200.0
			Game.play_ui(self, "heartbeat", -18 + stress / 8.0)
	_panic_check(delta)

# ---- panic (like X-COM: the soldier stops obeying) -----------------------------------------
var panic_t := 0.0
var panic_cd := 25.0
var _panic_dir := Vector3.ZERO

func _panic_check(delta: float) -> void:
	panic_cd -= delta
	if panic != "" or panic_cd > 0 or downed:
		return
	var limit := 85.0 if Game.veteran() else 98.0
	if stress < limit:
		return
	var chance := (1.25 - float(merc.get("bravery", 40)) / 100.0) * (0.35 if Game.veteran() else 0.15)
	if randf() > chance * delta:
		return
	var r := randf()
	if Game.veteran() and r < 0.2 and not weapon().is_empty():
		panic = "berserk"
		panic_t = 3.0
		mission.hud.message("ŠÍLÍŠ! Střílíš naslepo!", 3.0)
	elif r < 0.6 and not item_in("rh").is_empty():
		panic = "drop"
		panic_t = 3.0
		var it: Dictionary = inv["rh"]
		inv.erase("rh")
		_update_held()
		mission.drop_item(it, global_position + Vector3(0, 0.2, 0) - global_transform.basis.z * 0.6)
		mission.hud.message("PANIKA! Zbraň ti vypadla z rukou. (E ji zvedne)", 3.5)
	else:
		panic = "flee"
		panic_t = 4.0
		_panic_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		var near: Node = null
		for a in mission.aliens():
			if not a.dead and (near == null or a.global_position.distance_to(global_position) < near.global_position.distance_to(global_position)):
				near = a
		if near:
			_panic_dir = global_position - near.global_position
			_panic_dir.y = 0
			_panic_dir = _panic_dir.normalized()
		mission.hud.message("PANIKA! Utíkáš!", 3.0)
	Game.play_ui(self, "heartbeat", 0)

func _panic_tick(delta: float) -> void:
	panic_t -= delta
	crouching = panic == "drop"
	head.position.y = lerp(head.position.y, 1.0 if crouching else 1.6, delta * 8.0)
	velocity.x = 0; velocity.z = 0
	match panic:
		"flee":
			velocity.x = _panic_dir.x * SPRINT
			velocity.z = _panic_dir.z * SPRINT
			rotation.y = lerp_angle(rotation.y, atan2(-_panic_dir.x, -_panic_dir.z), delta * 5.0)
			mission.noise(global_position, 14.0)
		"berserk":
			rotation.y += randf_range(-3.0, 3.0) * delta
			pitch = clamp(pitch + randf_range(-1.5, 1.5) * delta, -0.4, 0.4)
			fire_cd -= delta
			var wp := weapon()
			if not wp.is_empty() and fire_cd <= 0 and int(wp.get("loaded", 0)) > 0:
				_shoot("rh", wp, Game.ITEMS[wp["id"]])
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()
	if panic_t <= 0:
		panic = ""
		stress = 55.0
		panic_cd = 25.0
		mission.hud.message("Vzpamatoval ses.", 2.0)

## Money for what the mercenary found (alien packs), paid with his share after the mission.
var salvage := 0

func _pick_up() -> void:
	var it: Dictionary = mission.nearest_pickup(global_position)
	if it.is_empty():
		return
	if Game.ITEMS[it["item"]["id"]]["type"] == "salvage":
		# an alien's pack: tools, alloy offcuts, a strange device - worth money to the right people
		mission.take_pickup.rpc(it["pid"])
		var v := int(it["item"].get("value", 100))
		salvage += v
		mission.hud.message("Batoh vetřelce: %s. Za nález dostaneš +%d kr." % [it["item"].get("what", "cizí technologie"), v], 3.0)
		Game.play_ui(self, "ping", -8)
		return
	var slot := ""
	var pid: String = it["item"]["id"]
	for s in ["rh", "back", "side", "lh", "b0", "b1", "b2", "b3", "p0", "p1", "p2", "p3", "p4", "p5"]:
		if not inv.has(s) and Game.slot_refuse(s, pid) == "" and not (s == "rh" and inv.has("lh") and Game.two_handed(pid)):
			slot = s
			break
	if slot == "":
		mission.hud.message("Nemáš kam to dát.", 1.5)
		return
	mission.take_pickup.rpc(it["pid"])
	var item: Dictionary = it["item"]
	inv[slot] = item
	if slot != "rh" and not slot.begins_with("p"):
		item["home"] = slot
	_update_held()
	mission.hud.message("Sebral jsi: %s" % Game.ITEMS[item["id"]]["name"], 1.5)
	Game.play_ui(mission, "pickup", -6)

## How far an alien can spot this mercenary (light gives you away).
## 0 = nobody has noticed me, 1 = they have me (sent by the host, shown as the eye).
var watched := 0.0
@rpc("any_peer", "call_local", "unreliable")
func set_watched(v: float) -> void:
	if multiplayer.get_remote_sender_id() in [0, 1]:
		watched = v

func visibility_range() -> float:
	if downed:
		return 6.0
	var r := 40.0 if light_on else 13.0
	if prone:
		r *= 0.4
	elif crouching:
		r *= 0.65
	return r

## The UFO crew's presence disturbs electronics: the flashlight stutters
## when one of them is near. Often the only warning you get.
var _flick_t := 0.0
func _flicker(delta: float) -> void:
	_flick_t -= delta
	if _flick_t > 0:
		return
	_flick_t = 0.07
	var near := 99.0
	for a in mission.aliens():
		if not a.dead:
			near = min(near, a.global_position.distance_to(global_position))
	var k := clampf((13.0 - near) / 9.0, 0.0, 1.0)
	# a torch on the gun: stronger, longer beam
	var lit := Game.has_mod(weapon().get("id", ""), "svitilna", merc)
	var base_e := 4.6 if lit else 3.0
	flash.spot_range = 34.0 if lit else 22.0
	flash.spot_angle = 19.0 if lit else 16.0
	if k > 0 and randf() < 0.15 + k * 0.5:
		flash.light_energy = base_e * randf_range(0.0, 0.6)
	else:
		flash.light_energy = base_e

## A downed body scraping over the ground while a teammate (or something else) drags it.
var _drag_ap: AudioStreamPlayer3D
var _drag_last := Vector3.INF
func _drag_sound(delta: float) -> void:
	var moving := false
	if downed and carried_by != 0 and _drag_last != Vector3.INF and delta > 0.0:
		moving = Vector2(global_position.x - _drag_last.x, global_position.z - _drag_last.z).length() / delta > 0.4
	_drag_last = global_position
	if moving and _drag_ap == null:
		_drag_ap = AudioStreamPlayer3D.new()
		_drag_ap.stream = Game.loop_stream("body_drag")
		_drag_ap.volume_db = -6.0
		_drag_ap.unit_size = 5.0
		_drag_ap.max_distance = 40.0
		_drag_ap.bus = "SFX"
		add_child(_drag_ap)
	if _drag_ap:
		if moving and not _drag_ap.playing:
			_drag_ap.play()
		elif not moving and _drag_ap.playing:
			_drag_ap.stop()

# ---- others' view ------------------------------------------------------------------------------
var _rs_last := Vector3.INF
var _rs_acc := 0.0
## Teammates' footsteps (their own machine plays them only for themselves).
func _remote_steps() -> void:
	if _rs_last == Vector3.INF or downed or dead:
		_rs_last = global_position
		return
	var d := Vector2(global_position.x - _rs_last.x, global_position.z - _rs_last.z).length()
	_rs_last = global_position
	if d > 2.0 or absf(velocity.y) > 1.0:
		return               # teleport or jump
	_rs_acc += d
	var stride := 0.6 if prone else (0.65 if crouching else 0.8)
	if _rs_acc >= stride:
		_rs_acc = 0.0
		var surf := Game.surface_at(self, global_position, mission.map)
		Game.play_at(self, "step_%s%d" % [surf, randi() % 4], global_position, (-24 if prone else (-19 if crouching else -12)) + float(Game.STEP_DB.get(surf, 0.0)))

var _act_seen := 0
# ---- wounds the others can see: blood soaking through clothes and armour, cuts on the face ----
## absolute rest positions of the model (front is -Z), size, health share below which it shows
const WOUNDS := [
	["spine", Vector3(-0.06, 1.3, -0.176), Vector3(0.11, 0.09, 0.01), 0.8],
	["upperarm.R", Vector3(-0.215, 1.25, -0.062), Vector3(0.07, 0.08, 0.01), 0.65],
	["head", Vector3(0.05, 1.655, -0.121), Vector3(0.032, 0.045, 0.008), 0.5],
	["thigh.L", Vector3(0.1, 0.78, -0.082), Vector3(0.09, 0.12, 0.01), 0.4],
	["spine", Vector3(0.07, 1.1, -0.176), Vector3(0.09, 0.1, 0.01), 0.25],
	["head", Vector3(-0.02, 1.6, -0.118), Vector3(0.045, 0.025, 0.008), 0.15],
]
var _wound_nodes: Array = []
func _wounds() -> void:
	if _sk == null:
		return
	if _wound_nodes.is_empty():
		var mat := Game.color_mat(Color(0.3, 0.015, 0.015))
		for w in WOUNDS:
			var bi := _sk.find_bone(w[0])
			if bi < 0:
				_wound_nodes.append(null)
				continue
			var att := BoneAttachment3D.new()
			att.bone_name = w[0]
			_sk.add_child(att)
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = w[2]
			mi.mesh = bm
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			att.add_child(mi)
			mi.transform = _sk.get_bone_global_rest(bi).affine_inverse() * Transform3D(Basis(), w[1])
			mi.visible = false
			_wound_nodes.append(mi)
	var f := hp / maxf(max_hp, 1.0)
	for i in WOUNDS.size():
		var n = _wound_nodes[i]
		if n:
			n.visible = dead or downed and i < 3 or f < float(WOUNDS[i][3])

## When the health drops (seen on every machine, health is synced) a little red falls on the ground.
var _blood_hp := -1.0
var _blood_t := 0.0
func _blood_watch(delta: float) -> void:
	if mission == null:
		return
	if _blood_hp < 0.0:
		_blood_hp = hp
	if hp < _blood_hp - 0.5:
		Game.blood_splat(mission, global_position + Vector3(randf_range(-0.25, 0.25), 0.6, randf_range(-0.25, 0.25)),
			Color(0.35, 0.02, 0.02), clampf((_blood_hp - hp) * 0.05, 0.2, 0.6))
	_blood_hp = hp
	# badly hurt or down: a drop now and then
	if (downed or hp < max_hp * 0.35) and not dead:
		_blood_t -= delta
		if _blood_t <= 0.0:
			_blood_t = randf_range(0.6, 1.4)
			Game.blood_splat(mission, global_position + Vector3(0, 0.5, 0), Color(0.3, 0.02, 0.02), randf_range(0.08, 0.15))

func _remote_visuals() -> void:
	if act != _act_seen:
		_act_seen = act
		_act_t = 0.0
	_fit_body_shape()
	_remote_steps()
	_show_items(held, held_l, held_back)
	head.rotation.x = pitch
	flash.visible = light_on and not downed
	_flicker(get_physics_process_delta_time())
	_apply_gear()
	_animate_body(get_physics_process_delta_time())
	_wounds()
	label.text = display_name + (" [!]" if downed else (" [PANIKA]" if panic != "" else ""))
	label.modulate = Color(1, 0.4, 0.3) if downed else Color(0.6, 0.85, 1.0)
