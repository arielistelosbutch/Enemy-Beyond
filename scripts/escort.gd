extends "res://scripts/intercept.gd"
## Escort: on the way to a mission small UFOs jump our transport. The Sokols that went
## along (players, or wingmen flown by their own pilots) defend it; the transport is flown
## by a player or by its pilot (AI). Drive them off or hold out until they give up and the
## flight goes on; lose the transport and the team turns back.
##
## Host: runs the attackers and the AI transport, counts every hit on them, syncs it all.

var tr_node: Node3D
var tr_hp := 100.0
var tr_kind := "heli"
var tr_vel := Vector3(0, 0, -70)
var tr_goal := Vector3.ZERO
var tr_rot := Quaternion.IDENTITY
var driver := 0                 # peer flying the transport, 0 = its own pilot (AI)
var flying_transport := false
var swarm: Array = []           # {node, hp, dir, vel, fire_cd, weave, jink, jcd, alive, goal}
var wing: Array = []            # AI Sokols: {node, cd, ti}
var limit := 150.0
var _sw_sync := 0.0
var _rotors: Array = []
var lost_jets := 0

func _ready() -> void:
	Game.play_music("interception")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	params = Net.mission_params
	tr_kind = String(params.get("transport", "heli"))
	driver = int(params.get("driver", 0))
	net = Net.is_online()
	var esc := int(params.get("escort_n", 0))
	pilots = params.get("pilots", [])
	if not net and esc > 0:
		pilots = [1]
	if not net and esc == 0:
		driver = 1          # alone and without escort: you fly the transport yourself
	limit = 120.0 if esc > 0 else 70.0
	kind = "scout"
	_world()
	# the transport
	tr_node = Game.model(tr_kind if tr_kind == "heli" else "dropship")
	add_child(tr_node)
	tr_node.position = Vector3(0, 880, 0)
	for rn in ["RotorF", "RotorR", "PropL", "PropR"]:
		var r := tr_node.find_child(rn, true, false)
		if r:
			_rotors.append(r)
	# the Kondor in cruise: nacelles swung forward, the proprotors pull like propellers
	for tn in ["TiltL", "TiltR"]:
		var tl0 := tr_node.find_child(tn, true, false) as Node3D
		if tl0:
			tl0.rotation.x = -PI / 2
	# in the air the rear ramp is shut (it only drops on the ground)
	var ramp := MeshInstance3D.new()
	var rbm := BoxMesh.new()
	rbm.size = Vector3(3.0, 2.7, 0.12)
	ramp.mesh = rbm
	ramp.material_override = Game.mat("skyranger", 0.5)
	tr_node.add_child(ramp)
	ramp.position = Vector3(0, 1.5, 4.0)
	var tl := OmniLight3D.new()
	tl.light_color = Color(1.0, 0.8, 0.5)
	tl.light_energy = 2.0
	tl.omni_range = 18.0
	tr_node.add_child(tl)
	me_pilot = Net.my_id() in pilots
	# the Sokols around it
	for i in pilots.size():
		var pid: int = pilots[i]
		var node := Game.model("sokol")
		add_child(node)
		node.position = Vector3((i - (pilots.size() - 1) / 2.0) * 50.0, 900 + i * 6.0, 60.0 + i * 15.0)
		if pid == Net.my_id() or not net:
			jet = node
		else:
			others[pid] = {"node": node, "pos": node.position, "prev": node.position, "vel": Vector3.ZERO, "down": false, "name": Net.roster.get(pid, {}).get("name", "Sokol")}
	for i in maxi(0, esc - pilots.size()):
		var wn := Game.model("sokol")
		add_child(wn)
		wn.position = Vector3(-80.0 + i * 160.0, 905, 90.0)
		wing.append({"node": wn, "cd": 1.0, "ti": i})
	if driver == Net.my_id() or (not net and driver != 0):
		flying_transport = true
		me_pilot = true
		jet = tr_node
		speed = 60.0
		speed_cap = 85.0
	if jet == null:
		jet = tr_node       # nobody to fly: watch from the transport
		down = true
	# the attackers come from ahead and from the side
	var n := 3 + (1 if float(Campaign.data.get("day", 0.0)) > 20 else 0) + (1 if esc >= 2 else 0)
	for i in n:
		var u := Game.model("ufo_scout")
		add_child(u)
		u.scale = Vector3.ONE * 1.6
		var eng := AudioStreamPlayer3D.new()
		eng.stream = Game.loop_stream("ufo_engine")
		eng.unit_size = 40.0
		eng.max_distance = 900.0
		eng.autoplay = true
		u.add_child(eng)
		var a := -PI / 2 + (i - n / 2.0) * 0.5
		u.position = Vector3(cos(a) * 700.0, 920 + randf_range(-40, 40), sin(a) * 700.0)
		var ul := OmniLight3D.new()
		ul.light_color = Color(0.6, 0.35, 1.0)
		ul.light_energy = 4.0
		ul.omni_range = 40.0
		u.add_child(ul)
		swarm.append({"node": u, "hp": 55.0, "dir": Vector3(0, 0, 1), "vel": Vector3.ZERO, "fire_cd": randf_range(2.0, 4.0),
			"weave": randf() * 10.0, "jink": Vector3.ZERO, "jcd": 1.0, "alive": true, "goal": u.position})
	ufo = swarm[0]["node"]
	ufo_hp = 55.0
	ufo_max = 55.0
	cam = Camera3D.new()
	cam.fov = 70
	cam.far = 6000
	add_child(cam)
	cam.current = true
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.draw.connect(_draw_hud)
	var cl := CanvasLayer.new()
	cl.layer = 5
	cl.add_child(hud)
	add_child(cl)
	var wind := AudioStreamPlayer.new()
	wind.stream = Game.loop_stream("heli_flight" if String(Net.mission_params.get("transport", "")) == "heli" else "wind")
	wind.volume_db = -6
	wind.bus = "Wind"
	add_child(wind)
	wind.play()
	if flying_transport:
		_say("PŘEPADENÍ! Řídíš %s - uhýbej (A/D), Shift forsáž. Vydrž, dokud to nevzdají." % Campaign.CRAFT_NAMES.get(tr_kind, "transport"), 6.0)
	elif not down:
		_say("PŘEPADENÍ! Malá UFO jdou po transportu. Sestřel je, než ho rozstřílejí.", 6.0)
	else:
		_say("PŘEPADENÍ! Sedíš v transportu a díváš se, jak ho stíhačky brání.", 6.0)

func _alive() -> Array:
	return swarm.filter(func(s): return s["alive"])

# ---- frame -----------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	t += delta
	msg_t -= delta
	_sky_follow()
	for r in _rotors:
		(r as Node3D).rotate_y(delta * 18.0)
	if outcome != "":
		end_t += delta
		_camera(delta)
		hud.queue_redraw()
		if end_t > 4.0 and Game.autotest() != "escort":
			_finish()
		return
	_pick_target()
	if me_pilot and not down:
		_fly(delta)
		if not flying_transport:
			_weapons(delta)
	var host := multiplayer.is_server() or not net
	if host:
		_swarm_ai(delta)
		if driver == 0:
			_transport_ai(delta)
		_wing_ai(delta)
	else:
		for s in swarm:
			var sn: Node3D = s["node"]
			sn.global_position = sn.global_position.lerp(s["goal"], clampf(delta * 10.0, 0, 1))
		if not flying_transport:
			tr_goal += tr_vel * delta
			tr_node.global_position = tr_node.global_position.lerp(tr_goal, clampf(delta * 10.0, 0, 1))
			tr_node.global_transform.basis = Basis(tr_rot)
	if net:
		_net_e(delta)
	_projectiles(delta)
	_camera(delta)
	if host:
		_judge()
	hud.queue_redraw()

## the target box / missile lock: the attacker nearest to where the nose points
func _pick_target() -> void:
	var best: Dictionary = {}
	var bv := -2.0
	var fwd := -jet.global_transform.basis.z
	for s in _alive():
		var d: Vector3 = (s["node"] as Node3D).global_position - jet.global_position
		var v := fwd.dot(d.normalized()) - d.length() / 4000.0
		if v > bv:
			bv = v
			best = s
	if not best.is_empty():
		if ufo != best["node"]:
			lock = 0.0
		ufo = best["node"]
		ufo_hp = best["hp"]

func _swarm_ai(delta: float) -> void:
	var tp := tr_node.global_position
	for s in _alive():
		var n: Node3D = s["node"]
		s["weave"] = float(s["weave"]) + delta
		var w: float = s["weave"]
		# circle the transport at 120-220 m and dive in to shoot
		var to_tr := tp - n.global_position
		var orbit := to_tr.cross(Vector3.UP).normalized() * (1.0 if int(w * 0.3) % 2 == 0 else -1.0)
		var want := (to_tr.normalized() * (1.0 if to_tr.length() > 200.0 else -0.3) + orbit * 0.8).normalized()
		# a Sokol right behind: break away
		for jt in _jets():
			var jp: Vector3 = jt["pos"]
			if jp.distance_to(n.global_position) < 180.0 and (jt["fwd"] as Vector3).dot((n.global_position - jp).normalized()) > 0.9:
				s["jcd"] = float(s["jcd"]) - delta * 2.0
		s["jcd"] = float(s["jcd"]) - delta
		if float(s["jcd"]) <= 0.0:
			s["jcd"] = randf_range(1.0, 2.2)
			s["jink"] = (orbit * (1.0 if randf() < 0.5 else -1.0) + Vector3(0, randf_range(-0.4, 0.4), 0)).normalized() * 70.0
			for rk in rockets:
				if not rk.get("lost", false) and (rk["node"] as Node3D).global_position.distance_to(n.global_position) < 160.0 and randf() < 0.5:
					rk["lost"] = true
		s["jink"] = (s["jink"] as Vector3).lerp(Vector3.ZERO, clampf(delta * 1.8, 0, 1))
		s["dir"] = (s["dir"] as Vector3).slerp(want, clampf(delta * 1.6, 0, 1)).normalized()
		s["vel"] = (s["dir"] as Vector3) * 75.0 + s["jink"] + Vector3(0, sin(w * 2.0) * 5.0, 0)
		n.global_position += (s["vel"] as Vector3) * delta
		n.global_position.y = clampf(n.global_position.y, 780.0, 1100.0)
		n.rotate_y(delta * 2.5)
		if float(s["hp"]) < 30.0 and randf() < delta * 6.0:
			_puff(n.global_position)
		# fire: mostly at the transport, sometimes at the jet that hunts it
		s["fire_cd"] = float(s["fire_cd"]) - delta
		if float(s["fire_cd"]) <= 0.0:
			s["fire_cd"] = randf_range(3.0, 4.6)
			var aim_at := tp + tr_vel * (to_tr.length() / 300.0)
			if randf() < 0.3:
				var js := _jets()
				if not js.is_empty():
					var jt2: Dictionary = js[randi() % js.size()]
					if (jt2["pos"] as Vector3).distance_to(n.global_position) < 600.0:
						aim_at = jt2["pos"] + (jt2["vel"] as Vector3) * ((jt2["pos"] as Vector3).distance_to(n.global_position) / 300.0)
			if aim_at.distance_to(n.global_position) < 650.0:
				var dir := (aim_at - n.global_position).normalized()
				dir = (dir + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.035).normalized()
				if net:
					_bolt.rpc(n.global_position + dir * 9.0, dir)
				else:
					_bolt(n.global_position + dir * 9.0, dir)

## every Sokol still flying (players and wingmen): pos, vel, fwd
func _jets() -> Array:
	var out := []
	if me_pilot and not down and not flying_transport:
		out.append({"pos": jet.global_position, "vel": -jet.global_transform.basis.z * speed, "fwd": -jet.global_transform.basis.z})
	for pid in others:
		if not others[pid]["down"]:
			var on: Node3D = others[pid]["node"]
			out.append({"pos": on.global_position, "vel": others[pid]["vel"], "fwd": -on.global_transform.basis.z})
	for w in wing:
		var wn: Node3D = w["node"]
		out.append({"pos": wn.global_position, "vel": -wn.global_transform.basis.z * 110.0, "fwd": -wn.global_transform.basis.z})
	return out

## The transport's own pilot: holds the course, weaves when it is being hit.
func _transport_ai(delta: float) -> void:
	var w := t * (0.6 if tr_hp > 50.0 else 1.3)
	var want := Vector3(sin(w) * (0.25 if tr_hp > 50.0 else 0.6), sin(w * 0.7) * 0.05, -1.0).normalized()
	tr_vel = tr_vel.slerp(want * 70.0, clampf(delta * 0.8, 0, 1))
	tr_node.global_position += tr_vel * delta
	tr_node.global_position.y = clampf(tr_node.global_position.y, 800.0, 1000.0)
	tr_node.look_at(tr_node.global_position + tr_vel, Vector3.UP)
	tr_node.rotate_object_local(Vector3.FORWARD, -tr_vel.normalized().x * 0.6)

## Wingmen flown by their own pilots: hunt the nearest attacker, short bursts when lined up.
func _wing_ai(delta: float) -> void:
	var al := _alive()
	for w in wing:
		var wn: Node3D = w["node"]
		var tg: Dictionary = {}
		var bd := 1e9
		for s in al:
			var d := (s["node"] as Node3D).global_position.distance_to(wn.global_position)
			if d < bd:
				bd = d
				tg = s
		var goal: Vector3 = tr_node.global_position + Vector3(80, 20, 60) if tg.is_empty() else (tg["node"] as Node3D).global_position
		var fwd := -wn.global_transform.basis.z
		var to := (goal - wn.global_position).normalized()
		var nf := fwd.slerp(to, clampf(delta * 1.4, 0, 1)).normalized()
		wn.look_at(wn.global_position + nf, Vector3.UP)
		wn.global_position += nf * 110.0 * delta
		w["cd"] = float(w["cd"]) - delta
		if not tg.is_empty() and float(w["cd"]) <= 0.0 and fwd.angle_to(to) < deg_to_rad(10) and bd < 550.0:
			w["cd"] = 0.45
			_tracer(wn.global_position + fwd * 5.0, (to + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.03).normalized(), true)
			if randf() < 0.45:
				_hit_swarm_local(swarm.find(tg), 5.0)

# ---- hits -------------------------------------------------------------------------------------
func _projectiles(delta: float) -> void:
	for tr in tracers.duplicate():
		var n: Node3D = tr["node"]
		var nxt: Vector3 = n.global_position + tr["vel"] * delta
		tr["life"] -= delta
		if not tr.get("fake", false):
			for i in swarm.size():
				var s: Dictionary = swarm[i]
				if s["alive"] and _seg_hits(n.global_position, nxt, (s["node"] as Node3D).global_position, 7.0):
					_damage_swarm(i, CANNON_DMG)
					tr["life"] = 0
					break
		n.global_position = nxt
		if tr["life"] <= 0:
			n.queue_free()
			tracers.erase(tr)
	for rk in rockets.duplicate():
		var n: Node3D = rk["node"]
		if not rk.has("tgt"):
			rk["tgt"] = swarm.find(_entry(ufo))
		var ti: int = rk["tgt"]
		var tpos: Vector3 = (swarm[ti]["node"] as Node3D).global_position if ti >= 0 and swarm[ti]["alive"] else n.global_position + (rk["vel"] as Vector3)
		var v: Vector3 = rk["vel"]
		if not rk.get("lost", false) and ti >= 0 and swarm[ti]["alive"]:
			v = v.lerp((tpos - n.global_position).normalized() * 260.0, clampf(delta * 2.5, 0, 1))
		rk["vel"] = v
		var nxt: Vector3 = n.global_position + v * delta
		n.look_at(nxt + v, Vector3.UP)
		rk["life"] -= delta
		if ti >= 0 and swarm[ti]["alive"] and _seg_hits(n.global_position, nxt, tpos, 10.0):
			if not rk.get("fake", false):
				_damage_swarm(ti, MISSILE_DMG)
			_flash(n.global_position, 20.0)
			Game.play_ui(self, "explosion", -2)
			rk["life"] = 0
		n.global_position = nxt
		if rk["life"] <= 0:
			n.queue_free()
			rockets.erase(rk)
	var host := multiplayer.is_server() or not net
	for bo in bolts.duplicate():
		var n: Node3D = bo["node"]
		var nxt: Vector3 = n.global_position + bo["vel"] * delta
		bo["life"] -= delta
		if _seg_hits(n.global_position, nxt, tr_node.global_position, 9.0):
			if host:
				tr_hp -= 4.0 * armor_k()
				if tr_hp < 50.0 and randf() < 0.5:
					_puff(tr_node.global_position)
			if flying_transport:
				_say("ZÁSAH DO TRANSPORTU! Trup %d %%" % int(maxf(tr_hp, 0)), 1.5)
			_flash(n.global_position, 8.0)
			Game.play_ui(self, "hit", -2)
			bo["life"] = 0
		elif me_pilot and not down and not flying_transport and _seg_hits(n.global_position, nxt, jet.global_position, 4.0):
			jet_hp -= 9.0 * armor_k()
			if jet_hp <= 0:
				down = true
				jet.visible = false
				_flash(jet.global_position, 12.0)
				_say("SOKOL SESTŘELEN. Pilot se katapultoval.", 5.0)
				if net:
					_jet_down.rpc(Net.my_id())
				else:
					lost_jets += 1
				jet = tr_node
			else:
				_say("ZÁSAH! Trup %d %%" % int(maxf(jet_hp, 0)), 1.5)
			_flash(n.global_position, 8.0)
			Game.play_ui(self, "hit", 0)
			bo["life"] = 0
		n.global_position = nxt
		if bo["life"] <= 0:
			n.queue_free()
			bolts.erase(bo)

func _entry(node: Node3D) -> Dictionary:
	for s in swarm:
		if s["node"] == node:
			return s
	return {}

func _damage_swarm(i: int, d: float) -> void:
	if net and not multiplayer.is_server():
		_hit_sw.rpc_id(1, i, d)
	else:
		_hit_swarm_local(i, d)
	if randf() < 0.3:
		_flash((swarm[i]["node"] as Node3D).global_position, 2.0)

func _hit_swarm_local(i: int, d: float) -> void:
	if i < 0 or i >= swarm.size() or not swarm[i]["alive"]:
		return
	swarm[i]["hp"] = float(swarm[i]["hp"]) - d
	if float(swarm[i]["hp"]) <= 0.0:
		_ufo_gone(i)
		if net:
			_sw_dead.rpc(i)

@rpc("any_peer", "reliable")
func _hit_sw(i: int, d: float) -> void:
	if multiplayer.is_server() and outcome == "":
		_hit_swarm_local(i, d)

@rpc("authority", "reliable")
func _sw_dead(i: int) -> void:
	_ufo_gone(i)

func _ufo_gone(i: int) -> void:
	if not swarm[i]["alive"]:
		return
	swarm[i]["alive"] = false
	var n: Node3D = swarm[i]["node"]
	_flash(n.global_position, 30.0)
	Game.play_ui(self, "explosion", 0)
	n.visible = false
	_say("UFO SESTŘELENO! Zbývá %d." % _alive().size(), 2.0)

# ---- network ------------------------------------------------------------------------------------
func _net_e(delta: float) -> void:
	_sync_t -= delta
	if _sync_t <= 0.0:
		_sync_t = 0.033
		if me_pilot and not down and not flying_transport:
			_jet_state.rpc(jet.global_position, jet.global_transform.basis.get_rotation_quaternion(), -jet.global_transform.basis.z * speed + slide)
		if flying_transport or (multiplayer.is_server() and driver == 0):
			_tr_state.rpc(tr_node.global_position, tr_node.global_transform.basis.get_rotation_quaternion(), tr_vel if not flying_transport else -tr_node.global_transform.basis.z * speed)
	_sw_sync -= delta
	if multiplayer.is_server() and _sw_sync <= 0.0:
		_sw_sync = 0.05
		var pos := []
		var hp := []
		for s in swarm:
			pos.append((s["node"] as Node3D).global_position)
			hp.append(float(s["hp"]))
		var wpos := []
		for w in wing:
			wpos.append((w["node"] as Node3D).global_transform)
		_swarm_state.rpc(pos, hp, tr_hp, wpos)
	for pid in others:
		var o: Dictionary = others[pid]
		var n: Node3D = o["node"]
		if not o["down"]:
			o["pos"] = (o["pos"] as Vector3) + (o["vel"] as Vector3) * delta
			n.global_position = n.global_position.lerp(o["pos"], clampf(delta * 12.0, 0, 1))

@rpc("any_peer", "unreliable_ordered")
func _tr_state(pos: Vector3, rot: Quaternion, vel: Vector3) -> void:
	if flying_transport:
		return
	tr_goal = pos
	tr_rot = rot
	tr_vel = vel
	if multiplayer.is_server():
		# a player flies it: the host still needs it where it is (the attackers aim at it)
		tr_node.global_position = pos
		tr_node.global_transform.basis = Basis(rot)

@rpc("authority", "unreliable_ordered")
func _swarm_state(pos: Array, hp: Array, thp: float, wpos: Array) -> void:
	for i in mini(pos.size(), swarm.size()):
		swarm[i]["goal"] = pos[i]
		swarm[i]["hp"] = hp[i]
	tr_hp = thp
	for i in mini(wpos.size(), wing.size()):
		(wing[i]["node"] as Node3D).global_transform = wpos[i]

@rpc("any_peer", "call_local", "reliable")
func _jet_down(pid: int) -> void:
	lost_jets += 1
	if others.has(pid):
		others[pid]["down"] = true
		var n: Node3D = others[pid]["node"]
		_flash(n.global_position, 12.0)
		n.visible = false
		_say("%s sestřelen! Pilot se katapultoval." % others[pid]["name"], 3.0)

# ---- outcome -----------------------------------------------------------------------------------
func _judge() -> void:
	if tr_hp <= 0.0:
		_end("transport_down")
	elif _alive().is_empty():
		_end("repelled")
	elif t > limit:
		_end("escaped")

func _end(o: String) -> void:
	if net and multiplayer.is_server() and outcome == "":
		outcome = o
		_end_all.rpc(o)
		outcome = ""
	outcome = o
	match o:
		"repelled":
			_say("ÚTOK ODRAŽEN. Transport pokračuje k cíli.", 6.0)
		"escaped":
			_say("UFO to vzdala a mizí. Transport pokračuje k cíli.", 6.0)
		"transport_down":
			_flash(tr_node.global_position, 25.0)
			Game.play_ui(self, "explosion", 2)
			_say("TRANSPORT ZASAŽEN! Pilot nouzově přistává - mise je ztracena.", 6.0)
	print("[ESCORT] outcome=%s tr_hp=%.0f alive=%d jet_hp=%.0f t=%.1f" % [o, tr_hp, _alive().size(), jet_hp, t])

func _finish() -> void:
	if _finished:
		return
	_finished = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Net.mission_params = {}
	if net and not multiplayer.is_server():
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
		return
	Net.last_result = Campaign.escort_done(int(params.get("craft", -1)), outcome, tr_hp, lost_jets)
	get_tree().change_scene_to_file("res://scenes/Geoscape.tscn")

# ---- HUD ----------------------------------------------------------------------------------------
func _draw_hud() -> void:
	var c := hud
	var sz := c.size
	var f := ThemeDB.fallback_font
	var green := Color(0.4, 1.0, 0.5, 0.9)
	var txt := func(p: Vector2, s: String, col := green, size := 9):
		c.draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color(0, 0, 0, 0.7))
		c.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	if not flying_transport and not down:
		super._draw_hud()
	else:
		_hplate(c, Rect2(4, sz.y - 30, 200, 26))
		txt.call(Vector2(12, sz.y - 13), "RYCHLOST %d km/h   VÝŠKA %d m" % [int(speed * 3.6), int(jet.global_position.y)], Color(0.84, 0.89, 0.92), 9)
		_hplate(c, Rect2(sz.x - 218, 4, 214, 24))
		txt.call(Vector2(sz.x - 210, 19), "Myš řídí, A/D úhyb, W/S plyn, Shift forsáž", Color(0.45, 0.78, 0.86), 7)
		if msg_t > 0:
			_msg_plate(c, Vector2(sz.x / 2, 66), msg, Color(1.0, 0.74, 0.32))
	# every attacker: a small red box, or an arrow at the edge
	for s in _alive():
		var p: Vector3 = (s["node"] as Node3D).global_position
		if not cam.is_position_behind(p):
			var sp := cam.unproject_position(p)
			c.draw_rect(Rect2(sp - Vector2(6, 6), Vector2(12, 12)), Color(1, 0.35, 0.3, 0.8), false, 1.0)
	# the transport
	var tcol := Color(0.6, 0.9, 1.0)
	if not cam.is_position_behind(tr_node.global_position) and not flying_transport:
		var tp := cam.unproject_position(tr_node.global_position)
		c.draw_arc(tp, 9, 0, TAU, 14, tcol, 1.5)
		txt.call(tp + Vector2(11, 3), "TRANSPORT", tcol, 7)
	_hplate(c, Rect2(4, 4, 178, 46))
	txt.call(Vector2(12, 18), "TRANSPORT %d %%" % int(maxf(tr_hp, 0)), tcol if tr_hp > 40 else Color(1, 0.4, 0.3), 9)
	_hbar(c, Rect2(12, 23, 160, 7), tr_hp / 100.0, tcol if tr_hp > 40 else Color(1, 0.4, 0.3))
	txt.call(Vector2(12, 43), "UFO: %d   vydržet ještě %d s" % [_alive().size(), int(maxf(0, limit - t))], Color(1.0, 0.74, 0.32), 9)

# ---- test ------------------------------------------------------------------------------------------
var _ramp_shot := false
func _process(_d: float) -> void:
	if Game.autotest() != "escort":
		return
	if outcome != "" and end_t > 1.5:
		print("[ESCORT-TEST] outcome=%s tr_hp=%.0f alive=%d" % [outcome, tr_hp, _alive().size()])
		get_viewport().get_texture().get_image().save_png("user://escort_end.png")
		get_tree().quit()
		return
	if int(t * 10) == 60:
		get_viewport().get_texture().get_image().save_png("user://escort_6.png")
	if t > 2.0 and not _ramp_shot and Game.cmd_arg("rampshot", "") == "1":
		_ramp_shot = true
		# a look at the transport's rear (the ramp must be shut in the air)
		var c2 := Camera3D.new()
		add_child(c2)
		c2.global_position = tr_node.global_transform * Vector3(4.0, 3.0, 16.0)
		c2.look_at(tr_node.global_transform * Vector3(0, 1.5, 3.0))
		c2.make_current()
		await get_tree().process_frame
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("user://escort_ramp.png")
		c2.queue_free()
	if down or flying_transport or ufo == null:
		return
	var to := ufo.global_position - jet.global_position
	var lp: Vector3 = jet.global_transform.basis.inverse() * to
	aim = Vector2(clamp(lp.x / 60.0, -1, 1), clamp(lp.y / 60.0, -1, 1))
	_mouse = Vector2.ZERO
	var line := (-jet.global_transform.basis.z).angle_to(to) < deg_to_rad(4)
	if line and to.length() < 600: Input.action_press("fire")
	else: Input.action_release("fire")
	if lock >= 1.0 and missiles > 0: Input.action_press("aim")
	else: Input.action_release("aim")
