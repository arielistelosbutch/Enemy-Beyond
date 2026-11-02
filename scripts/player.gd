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
	collision_layer = 2
	collision_mask = 1 | 2
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
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
			":held_l", ":held_back", ":prone", ":sprinting", ":captures", ":infected"]:
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
var body_anim: AnimationPlayer
var _gear_nodes := {}
var _last_body_pos := Vector3.ZERO
var _body_speed := 0.0
const GEAR_BITS := ["Gear_Belt0", "Gear_Belt1", "Gear_Belt2", "Gear_Belt3", "Gear_Backpack", "Gear_Grenade",
	"Gear_Flare", "Gear_Medkit", "Gear_Holster", "Gear_Scanner"]
const TEAM_COLORS := [Color(0.22, 0.24, 0.17), Color(0.18, 0.2, 0.24), Color(0.26, 0.22, 0.17), Color(0.17, 0.17, 0.17)]
const PATCH_COLORS := [Color(0.85, 0.65, 0.15), Color(0.2, 0.6, 0.95), Color(0.9, 0.25, 0.2), Color(0.4, 0.9, 0.4)]

## The mercenary as others see him: a rigged model whose gear matches his inventory.
func _build_body(data: Dictionary) -> void:
	merc_model = Game.model("merc")
	body.add_child(merc_model)
	body_anim = merc_model.find_child("AnimationPlayer", true, false)
	if body_anim:
		for an in body_anim.get_animation_list():
			body_anim.get_animation(an).loop_mode = Animation.LOOP_LINEAR
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
	# the weapon is carried in front of the chest and follows the torso
	var sk: Skeleton3D = merc_model.find_child("Skeleton3D", true, false)
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
const VM_R := {"rifle": Vector3(0.17, -0.18, -0.4), "plasma_rifle": Vector3(0.17, -0.18, -0.4), "shotgun": Vector3(0.17, -0.19, -0.42), "autocannon": Vector3(0.2, -0.24, -0.48),
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
	if bracing:
		# braced against the hip, pulled in and a bit to the centre
		base = Vector3(base.x * 0.55, base.y - 0.03, base.z + 0.08)
		rot = Vector3(0.0, 0.02, 0.0)
	if sprinting:
		# weapon swung low across the body, swinging with the stride
		base = Vector3(0.12, -0.32, -0.32) + Vector3(sin(_vm_t) * 0.04, -abs(cos(_vm_t)) * 0.04, 0)
		rot = Vector3(0.35 + sin(_vm_t) * 0.06, 0.9, 0.45)
	# reload: tilt in, hold, back up (the magazine drops at a quarter)
	var rl := 0.0
	if busy > 0 and busy_total > 0 and busy_text.begins_with("Přebíj"):
		var ph := 1.0 - busy / busy_total
		rl = smoothstep(0.0, 0.25, ph) * (1.0 - smoothstep(0.75, 1.0, ph))
	# digging in the backpack: hands drop out of view
	var dig := 1.0 if (busy > 0 and busy_stand) else 0.0
	var target: Vector3 = base + bob + Vector3(0.0, -0.1 * rl - 0.4 * dig, 0.05 * _vm_kick)
	gun.position = gun.position.lerp(target, k)
	gun.rotation.x = lerp(gun.rotation.x, rot.x + _vm_kick * 0.12 * kick_mult - rl * 0.5, k)
	gun.rotation.y = lerp(gun.rotation.y, rot.y, k)
	gun.rotation.z = lerp(gun.rotation.z, rot.z + rl * 0.7, k)
	if gun_l:
		var lt: Vector3 = VM_ONE_L + Vector3(-bob.x, bob.y, 0) + Vector3(0, -0.4 * dig, 0)
		if sprinting:
			lt += Vector3(0, -0.15, 0.05)
		gun_l.position = gun_l.position.lerp(lt, k)
	# melee swing
	if _swing > 0:
		var holder: Node3D = gun_l if _swing_left else gun
		var side := -1.0 if _swing_left else 1.0
		var ph := 1.0 - _swing
		if _swing_kind == 0:
			# knife: a quick diagonal slash
			var sw := sin(ph * PI)
			holder.rotation = Vector3(-0.9 * sw, 0.6 * sw * side, 0.4 * sw)
			_swing_shift(holder, Vector3(-0.15 * sw * side, 0.05 * sw, -0.12 * sw))
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
	if downed or dead:
		want = "downed"
	elif prone:
		want = "prone_crawl" if _body_speed > 0.2 else "prone"
	elif sprinting:
		want = "sprint"
	elif crouching:
		want = "crouch_walk" if _body_speed > 0.3 else "crouch"
	elif _body_speed > 3.2:
		want = "run"
	elif _body_speed > 0.3:
		want = "walk"
	if body_anim.current_animation != want:
		body_anim.play(want, 0.2)
	if dead:
		body_anim.pause()
	# lying on the back when down
	var lying := downed or dead
	var rx := -PI / 2 if lying else (PI / 2 if prone and not lying else 0.0)
	merc_model.rotation.x = lerp_angle(merc_model.rotation.x, rx, delta * 6.0)
	merc_model.position.y = lerp(merc_model.position.y, 0.18 if (lying or prone) else 0.0, delta * 6.0)
	merc_model.position.z = lerp(merc_model.position.z, 0.9 if lying else (-0.9 if prone else 0.0), delta * 6.0)

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
			gun.add_child(Game.model("hands_" + r if two else "hand_r"))
		if body_gun:
			body_gun.add_child(_held_model(r))
	if l != "" and not two:
		if gun_l:
			gun_l.add_child(_held_model(l))
			gun_l.add_child(Game.model("hand_l"))
		if body_l:
			body_l.add_child(_held_model(l))
	if back != "" and body_back:
		body_back.add_child(Game.model(back))

## A held item's model. Clubs (baton) are held upright, ready to come down.
func _held_model(id: String) -> Node3D:
	var m := Game.model(id)
	if Game.ITEMS.get(id, {}).get("blunt", false):
		m.rotation.x = deg_to_rad(78.0)
		m.position = Vector3(0, 0.01, 0.01)
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
	var w := 0
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
	var r: Dictionary = after.get("rh", {})
	var l: Dictionary = after.get("lh", {})
	for hand in [r, l]:
		if not hand.is_empty() and Game.ITEMS[hand["id"]]["type"] == "ammo":
			mission.hud.message("Náboje se do ruky neberou - nabíjí se klávesou R.", 2.0)
			return false
	if not r.is_empty() and Game.two_handed(r["id"]) and not l.is_empty():
		mission.hud.message("Obouruční zbraň potřebuje obě ruce - uvolni levou.", 2.0)
		return false
	if not l.is_empty() and Game.two_handed(l["id"]):
		mission.hud.message("Obouruční zbraň patří do pravé ruky (drží se oběma).", 2.0)
		return false
	var bk: Dictionary = after.get("back", {})
	if not bk.is_empty() and not Game.two_handed(bk["id"]):
		mission.hud.message("Na záda patří jen dlouhá zbraň.", 2.0)
		return false
	var t: float = Game.fetch_time(ia["id"], a)
	if ib != null:
		t = max(t, Game.fetch_time(ib["id"], b))
	t *= 0.65 if Game.has_talent(merc, "rychle_ruce") else 1.0
	var dig := a.begins_with("p") or b.begins_with("p")
	busy_stand = dig
	_start_busy(t, ("Hrabu se v batohu" if dig else "Beru") + ": " + Game.ITEMS[ia["id"]]["short"], func():
		busy_stand = false
		if inv.get(a) != ia:
			return
		inv.erase(a); inv.erase(b)
		inv[b] = ia
		if ib != null: inv[a] = ib
		_update_held()
		Game.play_ui(self, "reload", -16))
	return true

## Keys 1-4: belt slot <-> hand. A one-handed item goes to the left hand when
## the right is busy; a long gun in the hands goes on the back first.
func _belt_key(i: int) -> void:
	var slot := "b%d" % i
	if not inv.has(slot):
		# empty belt slot: put the left-hand (or right-hand) item there
		if inv.has("lh"): timed_move("lh", slot)
		elif inv.has("rh") and not Game.two_handed(inv["rh"]["id"]): timed_move("rh", slot)
		return
	var id: String = inv[slot]["id"]
	if Game.ITEMS[id]["type"] == "ammo":
		# ammunition on the belt: the key reloads the gun that takes it
		for hs in ["rh", "lh"]:
			var g := gun_in(hs)
			if not g.is_empty() and Game.ITEMS[g["id"]].get("ammo", "") == id:
				_reload(g, Game.ITEMS[g["id"]])
				return
		mission.hud.message("%s - do ruky se nebere, nabíjí se klávesou R." % Game.ITEMS[id]["short"], 2.0)
		return
	if Game.two_handed(id):
		if inv.has("lh"):
			mission.hud.message("Nejdřív uvolni levou ruku.", 1.5)
			return
		timed_move(slot, "rh")
		return
	var rh := item_in("rh")
	if not rh.is_empty() and Game.two_handed(rh["id"]):
		if inv.has("back"):
			mission.hud.message("Na zádech už zbraň máš - dlouhou zbraň nejdřív odlož.", 1.5)
			return
		# sling the long gun, then the item into the left hand
		inv["back"] = rh
		inv.erase("rh")
		_update_held()
		timed_move(slot, "lh")
		return
	timed_move(slot, "lh" if not inv.has("lh") or inv.has("rh") else "rh")

# ---- input (owner only) ------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority() or mission.finished:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# screen pixels, not the low-res viewport: same feel at any window size
		_mouse += event.screen_relative

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		_remote_visuals()
		return
	if dead or mission.finished:
		velocity = Vector3.ZERO
		return
	var inv_open: bool = mission.hud.inventory_open
	# look
	var sens := 0.0012 * Game.mouse_sens * (0.6 if aiming else 1.0)
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
		_start_busy(0.8, "Lehám si" if prone else "Vstávám", func(): pass)
	head.position.y = lerp(head.position.y, 0.35 if prone else (1.0 if crouching else 1.6), delta * 6.0)
	var rh := item_in("rh")
	var two := not rh.is_empty() and Game.two_handed(rh["id"])
	var brace_w: bool = two and Game.ITEMS[rh["id"]].get("brace", false)
	# heavy guns are not aimed down a sight: they are pulled in tight to the body
	bracing = brace_w and Input.is_action_pressed("aim") and not inv_open and not sprinting and busy <= 0
	aiming = two and not brace_w and Input.is_action_pressed("aim") and not inv_open and not sprinting and busy <= 0
	if cam:
		cam.fov = lerp(cam.fov, Game.fov * 0.7 if aiming else Game.fov, delta * 8.0)
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
			Game.play_ui(self, "breath", -22 + breath * 12.0)
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
			Game.play_at(self, "step", global_position, -22 if prone else (-18 if crouching else (-6 if sprint else -12)))
			mission.noise(global_position, (1.0 if prone else (2.0 if crouching else (14.0 if sprint else 6.0))) * quiet)
	# actions
	fire_cd -= delta
	spread_bloom = max(0.0, spread_bloom - delta * 3.0)
	spin = max(0.0, spin - delta * 0.8)
	if busy > 0:
		busy -= delta
		if busy <= 0 and busy_done.is_valid():
			busy_done.call()
		elif Input.is_action_just_pressed("fire") and busy_text.begins_with("Přebíjím po"):
			busy = 0.0       # interrupt single-round reloading to shoot
	elif not inv_open:
		_actions(delta)
	_stress(delta)
	_bleed(delta)
	if Input.is_action_just_pressed("flashlight"):
		light_on = not light_on
	flash.visible = light_on
	_flicker(delta)
	# evac: E at the Kondor
	gear = _gear_mask()
	_viewmodel_motion(delta, Vector2(velocity.x, velocity.z).length())
	# evac: hold E for two seconds (no accidental take-offs)
	if global_position.distance_to(mission.map["evac"]) < 3.5 and Input.is_action_pressed("use") and not inv_open:
		evac_hold += delta
	else:
		evac_hold = 0.0
	wants_evac = evac_hold >= 2.0

func _actions(delta: float) -> void:
	radio_button = false
	var rh := item_in("rh")
	var lh := item_in("lh")
	var two := not rh.is_empty() and Game.two_handed(rh["id"])
	if not sprinting:
		if two:
			# long gun: left button fires, right button aims
			_use_hand("rh", Input.is_action_pressed("fire"), Input.is_action_just_pressed("fire"), delta)
		else:
			# each hand on its own button: left button = left hand, right button = right hand
			_use_hand("lh", Input.is_action_pressed("fire"), Input.is_action_just_pressed("fire"), delta)
			_use_hand("rh", Input.is_action_pressed("aim"), Input.is_action_just_pressed("aim"), delta)
	if Input.is_action_just_pressed("reload"):
		var g := gun_in("rh")
		var slot := "rh"
		if g.is_empty() or int(g.get("loaded", 0)) >= Game.mag_size(g["id"]):
			if not gun_in("lh").is_empty():
				g = gun_in("lh"); slot = "lh"
		if not g.is_empty():
			_reload(g, Game.ITEMS[g["id"]])
	if Input.is_action_just_pressed("swap"):
		# long gun: hands <-> back
		if two and not inv.has("back"):
			timed_move("rh", "back")
		elif inv.has("back"):
			if inv.has("lh") or (inv.has("rh") and not two):
				mission.hud.message("Na dlouhou zbraň potřebuješ obě ruce volné.", 1.5)
			else:
				timed_move("back", "rh")
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
		_heal_self()
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
					spin = min(1.0, spin + delta / rule["spinup"] + delta * 0.8)
				if spin < 1.0:
					return
			var trigger := pressed if rule["auto"] else just
			if trigger and fire_cd <= 0:
				if int(it.get("loaded", 0)) > 0:
					_shoot(slot, it, rule)
				elif just:
					Game.play_at(self, "reload", global_position, -14)
					mission.hud.message("Prázdná zbraň - R přebije", 1.5)
		"melee":
			if just and fire_cd <= 0:
				_melee(slot, rule)
		"grenade", "flare":
			if just:
				_throw(it["id"], slot)
		"medkit":
			if just:
				_heal_self()
		"radio":
			# hold the button of the hand with the radio = talk on the radio
			if pressed:
				radio_button = true

# ---- shooting ---------------------------------------------------------------------------
func current_spread() -> float:
	var wp := gun_in("rh")
	if wp.is_empty():
		wp = gun_in("lh")
	if wp.is_empty():
		return 3.0
	var rule: Dictionary = Game.ITEMS[wp["id"]]
	var s: float = rule["spread"] * (1.7 - float(merc.get("accuracy", 50)) / 100.0)
	if prone: s *= 0.4
	elif crouching: s *= 0.6
	if aiming: s *= 0.5
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
	fire_cd = rule["rate"] / (2.0 if slot == "lh" and not gun_in("rh").is_empty() else 1.0)
	_vm_kick = 1.0
	kick_mult = float(rule.get("kick", 1.0))
	var spread := deg_to_rad(current_spread())
	spread_bloom = min(5.0, spread_bloom + 0.7 * kick_mult)
	pitch += (0.012 + randf() * 0.01) * kick_mult * (0.5 if prone else 1.0)
	var from := cam.global_position
	var basis_ := cam.global_transform.basis
	var muzzle := _muzzle(slot, rule)
	mission.noise(global_position, rule["noise"])
	if rule.get("projectile", false):
		var d := (-basis_.z).rotated(basis_.x, randf_range(-spread, spread) * 0.3).normalized()
		mission.fire_rocket.rpc(muzzle, d, name)
		Game.play_at(mission, rule["sound"], muzzle, 2)
		return
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
		# veteran: friendly fire - your bullets do not know who is who
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * 120.0, (1 | 4 | 2 | 8) if Game.veteran() else (1 | 4))
		q.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		var to := from + dir * 120.0
		if hit:
			to = hit.position
			var c: Object = hit.collider
			if c and c.has_method("is_alien"):
				var dmg: float = rule["damage"] * randf_range(0.6, 1.4) * (1.15 if Game.has_research("pitva") else 1.0)
				mission.hud.hitmarker()
				_hit_alien.rpc_id(1, c.name, dmg, "plasma" if wp["id"] == "plasma_rifle" else "bullet")
			elif c and c.has_method("is_player") and not c.dead:
				c.hurt.rpc_id(c.get_multiplayer_authority(), rule["damage"] * randf_range(0.5, 1.0), global_position)
			elif c and c.has_method("is_civilian") and not c.dead:
				mission.shoot_civ.rpc_id(1, c.name)
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
	_swing_kind = 0
	_swing_speed = 3.5
	_melee_hit(rule)

func _melee_hit(rule: Dictionary) -> void:
	Game.play_at(self, rule.get("sound", "swish"), global_position + Vector3.UP, -6)
	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * float(rule["reach"]), 1 | 4)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not (Game.has_talent(merc, "tichy_zabijak") and rule.has("backstab")):
		mission.noise(global_position, 3.0)
	if hit and hit.collider and hit.collider.has_method("is_alien"):
		var a: Node = hit.collider
		var behind: bool = (-a.global_transform.basis.z).dot((a.global_position - global_position).normalized()) > 0.3
		var dmg: float = float(rule["damage"]) * (float(rule.get("backstab", 1.0)) if behind else 1.0)
		if behind and Game.has_talent(merc, "tichy_zabijak") and rule.has("backstab"):
			dmg = 999.0
		var stun: float = float(rule.get("stun", 0.0)) * (1.5 if Game.has_talent(merc, "lovec_hlav") else 1.0)
		mission.hud.hitmarker()
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
	if snd != "":
		Game.play_at(mission, snd, from, -2)
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
	busy_stand = dig
	Game.play_at(self, "reload", global_position, -8)
	# the empty magazine drops out at a quarter of the motion
	get_tree().create_timer(t2 * 0.25).timeout.connect(func(): _drop_mag())
	_start_busy(t2, "Přebíjím" + (" (z batohu)" if dig else ""), func():
		busy_stand = false
		if inv.has(slot):
			inv.erase(slot)
			wp["loaded"] = cap
			Game.play_ui(self, "reload", -12))

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
	Game.play_at(mission, "explosion", p, 4)
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
func hurt(dmg: float, from: Vector3) -> void:
	if not is_multiplayer_authority() or dead:
		return
	if downed:
		bleed_left -= dmg * 0.5
		return
	hp -= dmg
	wounded = true
	stress = min(100.0, stress + dmg * (1.4 - float(merc.get("bravery", 40)) / 100.0) * 2.0)
	if dmg > 6.0:
		bleeding += 0.25
	Game.play_ui(self, "hit", -4)
	mission.hud.damage_flash(from)
	if hp <= 0:
		hp = 0
		downed = true
		bleed_left = BLEED_OUT
		crouching = true
		light_on = false
		mission.hud.message("PADL JSI! Krvácíš - spoluhráč tě musí ošetřit (E s lékárničkou) nebo odnést.", 6.0)
		Game.play_ui(self, "death", -6)

func _bleed(delta: float) -> void:
	if bleeding > 0 and not downed:
		hp -= bleeding * delta
		if hp <= 0:
			hurt(0.1, global_position)

func _downed(delta: float) -> void:
	head.position.y = lerp(head.position.y, 0.35, delta * 4.0)
	bleed_left -= delta
	if bleed_left <= 0:
		dead = true
		mission.hud.message("Vykrvácel jsi.", 8.0)
		return
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
	hp = max(8.0, max_hp * 0.3)
	bleeding = 0
	crouching = true
	mission.hud.message("%s tě ošetřil. Jsi zraněný, ale na nohou." % by, 4.0)

@rpc("any_peer", "call_local", "reliable")
func set_carried(by_peer: int) -> void:
	if is_multiplayer_authority() and downed:
		carried_by = by_peer

func _heal_self() -> void:
	var slot := find_item(func(it): return it["id"] == "medkit" and int(it.get("uses", 0)) > 0)
	if slot == "":
		mission.hud.message("Nemáš lékárničku.", 1.5)
		return
	if hp >= max_hp and bleeding <= 0:
		return
	_start_busy(3.0, "Ošetřuji se", func():
		if not inv.has(slot): return
		inv[slot]["uses"] = int(inv[slot]["uses"]) - 1
		if int(inv[slot]["uses"]) <= 0: inv.erase(slot)
		hp = min(max_hp, hp + (20.0 if Game.has_talent(merc, "felcar") else 10.0))
		bleeding = 0.0)

func _use_teammate() -> bool:
	var best: Node = null
	for p in mission.players():
		if p != self and p.downed and not p.dead and p.global_position.distance_to(global_position) < 2.2:
			best = p
	if best == null:
		return false
	var slot := find_item(func(it): return it["id"] == "medkit" and int(it.get("uses", 0)) > 0)
	if slot != "":
		var target := best
		var heal_time := 2.0 if Game.has_talent(merc, "felcar") else 3.0
		if best.infected and not Game.has_research("pitva_lihnoun"):
			heal_time *= 1.6     # cutting the seed out takes time
		_start_busy(heal_time, ("Vyřezávám zárodek - %s" if best.infected else "Ošetřuji %s") % best.display_name, func():
			if inv.has(slot) and is_instance_valid(target) and target.global_position.distance_to(global_position) < 2.6:
				inv[slot]["uses"] = int(inv[slot]["uses"]) - 1
				if int(inv[slot]["uses"]) <= 0: inv.erase(slot)
				revives += 1
				target.revived.rpc_id(target.get_multiplayer_authority(), display_name))
	else:
		var me := get_multiplayer_authority()
		best.set_carried.rpc_id(best.get_multiplayer_authority(), 0 if best.carried_by == me else me)
		mission.hud.message("Táhneš %s" % best.display_name if best.carried_by != me else "Pustil jsi %s" % best.display_name, 2.0)
	return true

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
	return item_in("rh").get("id", "") == "radio" or item_in("lh").get("id", "") == "radio"

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

func _pick_up() -> void:
	var it: Dictionary = mission.nearest_pickup(global_position)
	if it.is_empty():
		return
	var slot := ""
	for s in ["rh"] + Game.SLOTS:
		if not inv.has(s):
			slot = s
			break
	if slot == "":
		mission.hud.message("Nemáš kam to dát.", 1.5)
		return
	mission.take_pickup.rpc(it["pid"])
	var item: Dictionary = it["item"]
	inv[slot] = item
	_update_held()
	mission.hud.message("Sebral jsi: %s" % Game.ITEMS[item["id"]]["name"], 1.5)

## How far an alien can spot this mercenary (light gives you away).
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
	if k > 0 and randf() < 0.15 + k * 0.5:
		flash.light_energy = 3.0 * randf_range(0.0, 0.6)
	else:
		flash.light_energy = 3.0

# ---- others' view ------------------------------------------------------------------------------
func _remote_visuals() -> void:
	_show_items(held, held_l, held_back)
	head.rotation.x = pitch
	flash.visible = light_on and not downed
	_flicker(get_physics_process_delta_time())
	_apply_gear()
	_animate_body(get_physics_process_delta_time())
	label.text = display_name + (" [!]" if downed else (" [PANIKA]" if panic != "" else ""))
	label.modulate = Color(1, 0.4, 0.3) if downed else Color(0.6, 0.85, 1.0)
