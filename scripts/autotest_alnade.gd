extends RefCounted
## alnadetest / alnadehost + alnadeclient (0.72.6, Ari: „hážou granáty, které vybuchnou později
## pod nohama, vůbec ne v moment dopadu“): vetřelec (Bijec, Ještěřan) hodí plazmový granát na vojáka
## na rovné zemi, několikrát. Pro každý granát test sleduje, kde dopadl (první náraz – změna rychlosti
## oproti volnému pádu), kde zmizel (výbuch) a jak dlouho po dopadu: `roll` = jak daleko se po dopadu
## posunul, `delay` = výbuch po dopadu. V co-opu klient hlásí i `drift` = jak daleko byl jeho granát
## od místa, kde vybuchl u hostitele (dřív si každý počítač kutálel vlastní kuličku fyzikou).
## Funguje se starým (RigidBody) i novým granátem, takže jde porovnat.

static func _nades(m: Node) -> Array:
	var out := []
	for c in m.get_children():
		if String(c.name).begins_with("ANade_") or (c is RigidBody3D and (c as RigidBody3D).collision_layer == 8):
			out.append(c)
	return out

static func run(at: Node, p: Node) -> void:
	if p == null: return
	at._skip_brief()
	var m: Node = at.m()
	var mode: String = at.mode
	var host := not mode.ends_with("client")
	if at.step > 0 or not m.started(): return
	if mode != "alnadetest" and m.players().size() < 2: return
	at.step = 1
	m.hud.inventory_open = false
	p.hp = 5000.0
	var thrower: Node = null
	for a in m.aliens():
		if thrower == null and a.has_nades and a.race.begins_with(Game.cmd_arg("race", "bijec")):
			thrower = a
	for a in m.aliens():
		if a != thrower:
			a.set_physics_process(false)
			a.visible = false
			a.global_position += Vector3(0, -300, 0)
	if thrower == null:
		at.out("RESULT alnade %s no thrower" % mode)
		at.get_tree().quit()
		return
	# a flat open spot: the soldier there, the alien 13 m away (both held still)
	var spot: Vector3 = m.free_spot(m.map["evac"] + Vector3(10, 0.3, 10))
	var ss: PhysicsDirectSpaceState3D = m.get_world_3d().direct_space_state
	var hit := ss.intersect_ray(PhysicsRayQueryParameters3D.create(spot + Vector3(0, 20, 0), spot - Vector3(0, 20, 0), Game.WORLD))
	if not hit.is_empty():
		spot = hit["position"]
	var apos: Vector3 = spot + Vector3(13, 0.1, 0)
	thrower.set_physics_process(false)
	thrower.global_position = apos
	thrower.look_at(spot + Vector3(0, thrower.global_position.y - spot.y, 0), Vector3.UP)
	p.global_position = spot + Vector3(0, 0.1, 0)
	await at.get_tree().create_timer(1.5).timeout
	var n := int(Game.cmd_arg("throws", "5"))
	var rolls := []
	var delays := []
	var drifts := []
	var to_me := []
	var seen := 0
	var track := {}      # node -> {last, lastv, t, land, land_t, gone}
	var t := 0.0
	var thrown := 0
	var next := 0.0
	while t < n * 4.5 + 6.0:
		await at.get_tree().physics_frame
		var dt: float = at.get_physics_process_delta_time()
		t += dt
		p.global_position = spot + Vector3(0, 0.1, 0)
		if is_instance_valid(thrower):
			thrower.global_position = apos
		if host and thrown < n and t >= next:
			thrown += 1
			next = t + 4.5
			thrower._nade_cd = 0.0
			thrower._throw_nade(p.global_position)
		for g in _nades(m):
			if not track.has(g):
				track[g] = {"last": (g as Node3D).global_position, "v": Vector3.ZERO, "t": t, "land": null, "land_t": 0.0}
				seen += 1
				continue
			var r: Dictionary = track[g]
			var pos: Vector3 = (g as Node3D).global_position
			var v: Vector3 = (pos - r["last"]) / maxf(dt, 0.001)
			if r["land"] == null and t - r["t"] > 0.1:
				var want: float = r["v"].y - 9.8 * dt
				if absf(v.y - want) > 2.5 or (g.has_meta("down") or g.has_meta("rest")):
					r["land"] = pos
					r["land_t"] = t
			r["v"] = v
			r["last"] = pos
			if g.has_meta("on"):
				r["on"] = g.get_meta("on")
		for g in track.keys():
			if is_instance_valid(g) and (g as Node).is_inside_tree() and not (g as Node).is_queued_for_deletion():
				continue
			var r: Dictionary = track[g]
			track.erase(g)
			var end: Vector3 = r["last"]
			var land: Vector3 = r["land"] if r["land"] != null else end
			rolls.append(Vector2(end.x - land.x, end.z - land.z).length())
			delays.append(t - (r["land_t"] if r["land"] != null else t))
			to_me.append(Vector2(end.x - spot.x, end.z - spot.z).length())
			if r.has("on"):
				at.out("[ALNADE] on %s" % r["on"])
			at.out("[ALNADE] %s land %s end %s roll %.2f delay %.2f to_me %.1f" % [mode, land.snapped(Vector3.ONE * 0.01), end.snapped(Vector3.ONE * 0.01), rolls[-1], delays[-1], to_me[-1]])
			if not host:
				drifts.append(r.get("drift", 0.0))
		# (client) how far my own copy lay from where the host says it landed
		if not host:
			for g in track.keys():
				if is_instance_valid(g) and g.has_meta("drift"):
					track[g]["drift"] = float(g.get_meta("drift"))
	var mx := func(a: Array) -> float:
		var b := 0.0
		for x in a:
			b = maxf(b, float(x))
		return b
	var mn := func(a: Array) -> float:
		var b := 99.0
		for x in a:
			b = minf(b, float(x))
		return b if a.size() > 0 else -1.0
	at.out("RESULT alnade %s throws %d roll %.2f delay %.2f-%.2f drift %.2f to_me %.1f" % [mode, rolls.size(), mx.call(rolls), mn.call(delays), mx.call(delays), mx.call(drifts), mx.call(to_me)])
	if host and mode != "alnadetest":
		await at.get_tree().create_timer(2.0).timeout
	at.get_tree().quit()
