extends Node
## Testovací místnost (only in Godot - Editor menu): a clean stage up in the sky to look at movement.
## - a MIRROR: a copy of your soldier stands across a mirror line and does what you do, the way the
##   others see you (walk, crouch, lie down, reload, throw, every gun in the hands);
## - O: your own body from outside (a camera behind you), live;
## - T / Shift+T: the next / previous thing in the hand (full magazine, spare ones in the belt);
## - K: what the row of aliens does (idle, walk, run, aim, lurk, attack, roar);
## - you cannot be hurt and nothing attacks.

const WEAPONS := ["rifle", "pistol", "shotgun", "sniper", "magnum", "minigun", "autocannon", "rocket_launcher",
	"laser_pistol", "laser_rifle", "laser_cannon", "laser_minigun", "energo_nuz", "plasma_pistol", "plasma_rifle",
	"plasma_cannon", "plasma_minigun", "knife", "stun_baton", "grenade", "plasma_grenade", "smoke_grenade", "medkit", ""]
const ZOO := ["grey", "grey_velitel", "diskoll", "levit", "levit_velitel", "ohar", "jestetan", "jestetan_velitel", "lihnoun",
	"zombie", "bijec", "bijec_velitel", "nador", "ohnivec", "myslodej", "kolos"]
const MODES := ["idle", "walk", "run", "aim", "lurk", "attack", "roar"]
const MODE_NAMES := {"idle": "klid", "walk": "chůze", "run": "běh", "aim": "míření", "lurk": "číhání", "attack": "útok", "roar": "řev (Bijec)"}
const SYNC := ["pitch", "crouching", "light_on", "held", "held_l", "held_back", "prone", "sprinting", "act", "emote", "aiming", "gear"]

var m: Node
var base := Vector3(0, 120, 0)
var mirror_z := 0.0
var puppet: CharacterBody3D
var aliens: Array = []
var wi := 0
var mode := 0
var outside := false
var cam_out: Camera3D
var help: Label
var _ready_done := false

func _process(delta: float) -> void:
	if m == null:
		m = get_parent()
	var me: Node = m.local_player() if m.has_method("local_player") else null
	if not _ready_done:
		if m.has_method("started"):
			m.prep_left = 0.0
		if m.hud and m.hud._brief_t >= 0:
			m.hud._brief_t = float(m.hud._brief_len) / 40.0 + 1.0
		if me == null or not m.started():
			return
		_build(me)
		_ready_done = true
		return
	if me == null:
		return
	me.hp = 9999.0
	_mirror(me)
	_drive_aliens(delta)
	if outside:
		me._remote_visuals()       # your own body, as the others see it
		var fw: Vector3 = -me.global_transform.basis.z
		cam_out.global_position = me.global_position + Vector3(0, 1.9, 0) - fw * 3.2 + me.global_transform.basis.x * 0.7
		cam_out.look_at(me.global_position + Vector3(0, 1.2, 0) + fw * 1.5, Vector3.UP)
	_help()

func _unhandled_input(e: InputEvent) -> void:
	if not _ready_done or not e is InputEventKey or not e.pressed or e.echo:
		return
	var me: Node = m.local_player()
	match e.keycode:
		KEY_T:
			wi = (wi + (WEAPONS.size() - 1 if e.shift_pressed else 1)) % WEAPONS.size()
			_give(me, WEAPONS[wi])
		KEY_K:
			mode = (mode + 1) % MODES.size()
		KEY_O:
			outside = not outside
			cam_out.current = outside
			if not outside:
				me.cam.current = true
			me.body.visible = outside
			if me.gun:
				me.gun.visible = not outside

## The stage: a floor and lights high above the map, the mirror line, the row of aliens.
func _build(me: Node) -> void:
	for a in m.aliens():
		a.queue_free()
	var fl := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(44, 0.2, 40)
	fl.mesh = fm
	fl.material_override = Game.mat("grass", 0.5)
	m.add_child(fl)
	fl.global_position = base + Vector3(0, -0.1, 0)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = fm.size
	cs.shape = bs
	sb.add_child(cs)
	fl.add_child(sb)
	for lp in [Vector3(0, 6, 6), Vector3(-10, 6, -8), Vector3(10, 6, -8), Vector3(0, 6, -16)]:
		var l := OmniLight3D.new()
		l.light_energy = 2.6
		l.omni_range = 22.0
		m.add_child(l)
		l.global_position = base + lp
	if m.get("env"):
		m.env.fog_density = 0.002
	# the mirror: a thin glowing line on the floor
	mirror_z = base.z - 1.0
	var ln := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(10, 0.02, 0.04)
	ln.mesh = lm
	ln.material_override = Game.color_mat(Color(0.4, 0.9, 1.0), true)
	m.add_child(ln)
	ln.global_position = Vector3(base.x, base.y + 0.01, mirror_z)
	me.global_position = base + Vector3(0, 0.3, 3.0)
	me.rotation.y = 0.0
	# your copy across the mirror (not one of the mission's players: nothing counts it)
	puppet = CharacterBody3D.new()
	puppet.set_script(load("res://scripts/player.gd"))
	puppet.name = "Zrcadlo"
	puppet.set_multiplayer_authority(987654)
	puppet.setup({"merc": me.merc, "name": "zrcadlo", "pos": base + Vector3(0, 0.3, -5.0), "yaw": PI, "peer": 987654})
	add_child(puppet)
	if puppet.sync:
		puppet.sync.queue_free()
		puppet.sync = null
	puppet.label.visible = false
	puppet.set_collision_layer(0)
	# the row of aliens, facing you, behind the mirror
	for i in ZOO.size():
		m.spawn_alien(ZOO[i], base + Vector3((i - ZOO.size() / 2.0 + 0.5) * 2.6, 0.3, -12.0))
	await get_tree().create_timer(0.5).timeout
	aliens = m.aliens()
	for a in aliens:
		a.set_physics_process(false)
		a.rotation.y = 0.0
	cam_out = Camera3D.new()
	cam_out.fov = 60.0
	m.add_child(cam_out)
	help = Label.new()
	help.add_theme_font_size_override("font_size", 9)
	help.add_theme_color_override("font_color", Color(0.6, 0.95, 1.0))
	help.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	help.add_theme_constant_override("outline_size", 4)
	help.position = Vector2(8, 6)
	m.hud.add_child(help)
	_give(me, WEAPONS[0])

func _give(me: Node, id: String) -> void:
	for sl in ["b0", "b1", "b2", "b3", "p0", "p1", "p2", "p3"]:
		me.inv.erase(sl)
	if id == "":
		me.inv.erase("rh")
	else:
		var it := {"id": id}
		var r: Dictionary = Game.ITEMS.get(id, {})
		var ammo := String(r.get("ammo", ""))
		if r.get("type", "") == "weapon":
			it["loaded"] = Game.mag_size(id) if ammo != "" or r.has("cap") else 0
			if ammo != "":
				for sl in ["b0", "b1", "b2", "p0", "p1", "p2"]:
					me.inv[sl] = {"id": ammo}
		me.inv["rh"] = it
	me.inv.erase("lh")
	me._update_held()

## The copy: your pose mirrored across the line - come closer and it comes to you.
func _mirror(me: Node) -> void:
	if puppet == null:
		return
	for k in SYNC:
		puppet.set(k, me.get(k))
	# (0.57: the afk movements - the copy kicks when you shoot and limps when you are badly hurt)
	puppet._fired_at = me._fired_at
	puppet.max_hp = me.max_hp
	puppet.hp = maxf(1.0, me.hp)
	var p: Vector3 = me.global_position
	puppet.global_position = Vector3(p.x, p.y, 2.0 * mirror_z - p.z)
	puppet.rotation.y = PI - me.rotation.y
	puppet.body.visible = true

func _drive_aliens(delta: float) -> void:
	var want: String = MODES[mode]
	for a in aliens:
		if not is_instance_valid(a) or a.dead:
			continue
		if a.has_method("_tentacle_tick") and not (a.get("_tent_meshes") as Array).is_empty():
			a._tentacle_tick(delta)
		var ap: AnimationPlayer = a.get("anim")
		if ap == null:
			continue
		var clip := want if ap.has_animation(want) else "idle"
		if not ap.has_animation(clip):
			continue
		if ap.current_animation != clip or (not ap.is_playing() and clip == "roar"):
			ap.play(clip, 0.2)
		ap.advance(delta)

func _help() -> void:
	if help == null:
		return
	var w: String = WEAPONS[wi]
	help.text = "TESTOVACÍ MÍSTNOST (jen v Godotu)\nT / Shift+T: v ruce: %s   |   K: vetřelci: %s   |   O: pohled zvenčí: %s\nZa modrou čarou je zrcadlo: tvůj voják tak, jak tě vidí ostatní. Esc: menu." % [
		(String(Game.ITEMS[w]["name"]) if w != "" else "prázdné ruce"), MODE_NAMES[MODES[mode]], "zapnut" if outside else "vypnut"]
