extends Control
## The command screen: a turning globe with day and night, the missions the
## radar found, time controls and the base menus (research, armory, building).

const BG := Color(0.02, 0.03, 0.07)
const PANEL := Color(0.10, 0.115, 0.13, 0.95)
const FRAME := Color(0.45, 0.78, 0.86)
const TEXT := Color(0.84, 0.89, 0.92)
const ACCENT := Color(1.0, 0.74, 0.32)
const RED := Color(1.0, 0.4, 0.3)
const SPEEDS := [0.0, 5.0 / 1440.0, 1.0 / 24.0, 6.0 / 24.0]   # days per second
const SPEED_NAMES := ["Stop", "5 min", "1 h", "6 h"]

var vp: SubViewport
var view: TextureRect     # shows the globe; picking uses its local mouse coordinates
var hover := -1
var report_box: VBoxContainer   # clickable list of radar reports over the globe
var report_key := ""
var tag_lbl: Label              # name tag that sits on the selected marker
var cam: Camera3D
var globe: MeshInstance3D
var gmat: ShaderMaterial
var markers := {}          # mission id -> Node3D
var base_marker: Node3D
var speed := 1
var yaw := deg_to_rad(-15.0)
var tilt := deg_to_rad(30.0)
var zoom := 3.2
var dragging := false
var selected := -1
var side: VBoxContainer
var info_lbl: Label
var status_lbl: Label
var popup: PanelContainer
var t := 0.0

func _ready() -> void:
	if Game.autotest() != "": print("[GEO] globe ready (viewer %s)" % Campaign.viewer)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Net.blocked.connect(_alert)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if not Campaign.active and not Campaign.viewer and not Campaign.load_campaign():
		Campaign.new_campaign()
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_build_globe()
	_build_side()
	if Campaign.base_picking() and not Campaign.viewer:
		if Game.autotest() != "" and Game.autotest() != "basepick":
			Campaign.data["base_pick"] = false        # (the tests keep the base in the Vysočina, no bonus)
		else:
			_begin_pick()
	Game.play_music("game_over" if Campaign.data.get("lost", false) else "geoscape")
	_toast = Label.new()
	_toast.position = Vector2(8, 334)
	_toast.size = Vector2(415, 16)
	_toast.add_theme_font_size_override("font_size", 9)
	_toast.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	add_child(_toast)
	Net.note.connect(_on_note)
	Campaign.mission_found.connect(func(m): Game.play_ui(self, "radar_alert", -4); _alert("RADAR: %s\n%s\n%s" % [Campaign.MTYPES[m["type"]]["name"], m["place"], Campaign.MTYPES[m["type"]]["text"]]); selected = int(m["id"]); _focus(m))
	Campaign.flight_found.connect(func(f): Game.play_ui(self, "radar_ping", -4); _alert("RADAR: UFO V LETU\n%s nad oblastí %s.\nVyber ho na glóbu a vyšli stíhačky, než zmizí." % [Campaign.UFO_NAMES[f["kind"]], Campaign.nearest_place(float(f["lat"]), float(f["lon"]))]); selected = int(f["id"]); _focus(f))
	Campaign.research_done.connect(func(id):
		Game.play_ui(self, "research_done", -3)
		_alert("VÝZKUM DOKONČEN\n%s\n%s" % [Campaign.RESEARCH[id]["name"], Campaign.RESEARCH[id]["desc"]])
		var ent: String = EncyData.for_research(id)
		if ent != "" and popup:
			var box: VBoxContainer = popup.get_child(0)
			_btn(box, "Otevřít v encyklopedii", func(): _show_archive(ent), 9))
	Campaign.report.connect(func(txt): Game.play_ui(self, "warning_alarm" if String(txt).begins_with("KONEC") or "MÍNUSU" in String(txt) else "money", -6); _alert(txt))
	# the hum of the control room under everything
	var hum := AudioStreamPlayer.new()
	hum.stream = Game.loop_stream("geoscape_hum")
	hum.volume_db = -14
	hum.bus = "Ambient"
	add_child(hum)
	hum.play()
	Campaign.craft_arrived.connect(_on_arrived)
	Campaign.craft_ambushed.connect(_on_ambush)
	# a craft that was waiting at the target when the game was saved
	if not Campaign.viewer:
		for c in Campaign.crafts():
			if c.get("state", "") == "arrived":
				(func(): _on_arrived(c)).call_deferred()
				break
			if c.get("state", "") == "ambush":
				(func(): _on_ambush(c)).call_deferred()
				break
	if Net.last_result != "":
		var lr := Net.last_result
		if lr.begins_with("KONEC"):
			Game.play_ui(self, "warning_alarm", -6)      # (the base fell: the campaign is over)
			_alert(lr)
		else:
			_alert("NÁVRAT Z MISE\n" + lr)
		Net.last_result = ""
	elif Campaign.data.get("lost", false):
		# a lost campaign (also a co-op mate back from the fallen base): say why the clock stands
		var lg: Array = Campaign.data.get("log", [])
		_alert("KONEC\n" + (String(lg[-1]) if not lg.is_empty() else "Projekt X skončil."))
	if Campaign.won() and not Campaign.data.get("won_shown", false):
		Campaign.data["won_shown"] = true
		Campaign.save()
		Game.play_music("victory", false)
		_alert("VÍTĚZSTVÍ\nVelký mozek je mrtvý a velín na Marsu utichl. UFO padají z nebe jako mrtví ptáci, Šediváci v lesích jen stojí a dívají se do tmy.\nVojáci přežili noc, která neměla konec.\n\nOPERACE X - ENEMY BEYOND\nPocta UFO: Enemy Unknown - fanouškovská hra, ne na prodej.\nNápad a hra: Ari (Ivo Arielistelos Florek).\nKampaň můžeš hrát dál.")
	_autotest.call_deferred()

# ---- the globe -------------------------------------------------------------------------------
func _build_globe() -> void:
	vp = SubViewport.new()
	vp.size = Vector2i(430, 360)
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	view = TextureRect.new()
	view.position = Vector2.ZERO
	view.size = Vector2(430, 360)
	view.texture = vp.get_texture()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	report_box = VBoxContainer.new()
	report_box.position = Vector2(6, 6)
	report_box.add_theme_constant_override("separation", 2)
	add_child(report_box)
	tag_lbl = Label.new()
	tag_lbl.add_theme_font_size_override("font_size", 8)
	tag_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	tag_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	tag_lbl.add_theme_constant_override("outline_size", 3)
	tag_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tag_lbl)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BG
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR      # (the ships over the globe; the globe is unshaded)
	env.ambient_light_color = Color(0.55, 0.6, 0.7)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	cam = Camera3D.new()
	cam.fov = 40
	vp.add_child(cam)
	var key := DirectionalLight3D.new()       # light from over the viewer's shoulder, so the ships read on the night side too
	key.rotation = Vector3(deg_to_rad(-35), deg_to_rad(25), 0)
	key.light_energy = 1.1
	cam.add_child(key)
	globe = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 64
	sm.rings = 32
	globe.mesh = sm
	gmat = ShaderMaterial.new()
	gmat.shader = preload("res://shaders/globe.gdshader")
	gmat.set_shader_parameter("day_tex", load("res://assets/textures/earth_day.png"))
	gmat.set_shader_parameter("night_tex", load("res://assets/textures/earth_night.png"))
	globe.material_override = gmat
	vp.add_child(globe)
	# stars
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var qm := QuadMesh.new()
	qm.size = Vector2(0.02, 0.02)
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smat.albedo_color = Color(0.8, 0.85, 1.0)
	qm.material = smat
	mm.mesh = qm
	mm.instance_count = 400
	for i in 400:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * 30.0
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * rng.randf_range(0.5, 2.0)), d))
	var stars := MultiMeshInstance3D.new()
	stars.multimesh = mm
	vp.add_child(stars)
	base_marker = _marker(Color(0.3, 0.8, 1.0), 0.03)
	_place(base_marker, Campaign.base_lat(), Campaign.base_lon())

func _marker(c: Color, size: float) -> Node3D:
	var n := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(size, size, size)
	n.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	n.material_override = m
	globe.add_child(n)
	return n

## A small 3D model of the ship flying over the globe (0.69: instead of the flat picture).
## `size` = its longest side in globe units; `tint` = colour of the ring on the ground under it
## (red = UFO, blue = ours). Falls back to the old picture if the model is missing.
func _craft_marker(model: String, tint: Color, size: float) -> Node3D:
	if not ResourceLoader.exists("res://assets/models/%s.glb" % model):
		return _icon_marker(model, tint, size)
	var holder := Node3D.new()
	holder.set_meta("craft", true)
	var m := Game.model(model)
	Game.ship_ramp(m, 0.0)          # (in the air the back ramp is shut)
	var box := _mesh_box(m, Transform3D.IDENTITY)
	var k := size / maxf(0.001, maxf(box.size.x, box.size.z))
	m.scale = Vector3.ONE * k
	m.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * k     # centred, sitting on its belly
	m.name = "Model"
	var spin := Node3D.new()
	spin.name = "Spin"
	holder.add_child(spin)
	spin.add_child(m)
	for n in m.find_children("*", "GeometryInstance3D", true, false):
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# rotors and propellers keep turning
	var props := []
	for nm in ["RotorF", "RotorR", "PropL", "PropR"]:
		var r := m.find_child(nm, true, false)
		if r:
			props.append(r)
	holder.set_meta("props", props)
	holder.set_meta("round", model.begins_with("ufo_") and model != "ufo_harvester")
	# the ring on the ground under it (blinks for UFOs, like the old marker)
	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	var tm := TorusMesh.new()
	tm.inner_radius = size * 0.47
	tm.outer_radius = size * 0.52
	tm.rings = 24
	tm.ring_segments = 4
	ring.mesh = tm
	ring.scale = Vector3(1, 0.05, 1)
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(tint.r, tint.g, tint.b, 0.65)
	ring.material_override = rm
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(ring)
	globe.add_child(holder)
	return holder

static func _mesh_box(n: Node, xf: Transform3D) -> AABB:
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	var b := AABB()
	var any := false
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		b = t * (n as MeshInstance3D).mesh.get_aabb()
		any = true
	for c in n.get_children():
		var cb := _mesh_box(c, t)
		if cb.size != Vector3.ZERO:
			b = cb if not any else b.merge(cb)
			any = true
	return b

const FLY_ALT := 0.035        # how high the ships fly over the globe (globe radius 1)
var _heading := {}            # marker id -> heading in degrees (from its motion on the globe)
var _last_ll := {}

## Puts a 3D ship over (lat, lon): belly to the ground, nose along its heading (degrees from
## north towards east). The heading comes from how the marker moved; `hint` until it moves.
func _place_craft(id: int, n: Node3D, lat: float, lon: float, hint := INF) -> void:
	if not n.has_meta("craft"):
		_place(n, lat, lon)
		return
	var hd: float = _heading.get(id, hint if hint != INF else 0.0)
	if _last_ll.has(id):
		var o: Vector2 = _last_ll[id]
		var dn := lat - o.x
		var de := wrapf(lon - o.y, -180.0, 180.0) * cos(deg_to_rad(lat))
		if Vector2(dn, de).length() > 0.0005:
			var want := rad_to_deg(atan2(de, dn))
			var k := 1.0 if not _heading.has(id) else minf(1.0, get_process_delta_time() * 5.0)
			hd = hd + wrapf(want - hd, -180.0, 180.0) * k
	elif hint != INF:
		hd = hint
	_heading[id] = hd
	_last_ll[id] = Vector2(lat, lon)
	var up := latlon_to_local(lat, lon).normalized()
	var north := (Vector3.UP - up * up.dot(Vector3.UP))
	if north.length() < 0.01:
		north = Vector3.FORWARD
	north = north.normalized()
	var east := north.cross(up).normalized()
	var h := deg_to_rad(hd)
	var fwd := (north * cos(h) + east * sin(h)).normalized()
	var z := -fwd                            # the models fly nose first along -Z
	var x := up.cross(z).normalized()
	n.transform = Transform3D(Basis(x, up, z), up * (1.0 + FLY_ALT))
	var ring: Node3D = n.get_node_or_null("Ring")
	if ring:
		ring.position = Vector3(0, -FLY_ALT + 0.003, 0)

## Bigger when selected / under the mouse (a 3D ship grows in place, its ring stays on the ground).
func _mark_scale(n: Node3D, k: float) -> void:
	if not n.has_meta("craft"):
		n.scale = Vector3.ONE * k
		return
	(n.get_node("Spin") as Node3D).scale = Vector3.ONE * k
	(n.get_node("Ring") as Node3D).scale = Vector3(k, 0.05, k)

## Turns the rotors, spins the round saucers and bobs the ships a little (every frame).
func _animate_craft(n: Node3D, delta: float) -> void:
	if not n.has_meta("craft"):
		return
	var spin: Node3D = n.get_node("Spin")
	if n.get_meta("round", false):
		spin.rotate_y(delta * 0.8)
	spin.position.y = sin(t * 2.2 + float(n.get_instance_id() % 97)) * 0.002
	for r in n.get_meta("props", []):
		(r as Node3D).rotate_y(delta * 30.0)

## A picture of the ship itself (rendered from its model) that always faces the camera.
func _icon_marker(model: String, tint: Color, size: float) -> Node3D:
	var tex := UiSkin.icon(model)
	if tex == null:
		return _marker(tint, size * 0.6)
	var s := Sprite3D.new()
	s.texture = tex
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.pixel_size = size / float(tex.get_width())
	s.modulate = tint
	s.shaded = false
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	globe.add_child(s)
	return s

static func latlon_to_local(lat: float, lon: float, r := 1.0) -> Vector3:
	var la := deg_to_rad(lat)
	var lo := deg_to_rad(lon)
	return Vector3(cos(la) * sin(lo), sin(la), cos(la) * cos(lo)) * r

var _live_t := 0.0
## Teammates watching the host's globe: markers glide to where the host's packet put them
## (four packets a second would make them jump otherwise).
var _shown := {}
func _glide(id: int, n: Node3D, lat: float, lon: float, hint := INF) -> void:
	if not Campaign.viewer or not _shown.has(id):
		_shown[id] = Vector2(lat, lon)
	else:
		var cur: Vector2 = _shown[id]
		var dlon := wrapf(lon - cur.y, -180.0, 180.0)
		var k := minf(1.0, get_process_delta_time() * 6.0)
		if absf(lat - cur.x) > 20.0 or absf(dlon) > 20.0:
			k = 1.0          # a jump (new flight, landed): no slow slide across the world
		_shown[id] = Vector2(lerpf(cur.x, lat, k), wrapf(cur.y + dlon * k, -180.0, 180.0))
	var v: Vector2 = _shown[id]
	_place_craft(id, n, v.x, v.y, hint)

func _place(n: Node3D, lat: float, lon: float) -> void:
	# local to the globe, so the marker turns with it (look_at_from_position worked in world space = bug)
	var p := latlon_to_local(lat, lon, 1.012)
	n.transform = Transform3D(Basis.looking_at(p.normalized(), Vector3.UP if abs(lat) < 85 else Vector3.RIGHT), p)

func _focus(m: Dictionary) -> void:
	# turn the globe so the place faces the camera
	yaw = -deg_to_rad(float(m["lon"]))
	tilt = deg_to_rad(clamp(float(m["lat"]), -60, 60))

func _on_note(t: String) -> void:
	_toast.text = t
	_toast_t = 6.0

var _toast: Label
var _toast_t := 0.0
func _process(delta: float) -> void:
	t += delta
	_toast_t -= delta
	if _toast and _toast_t <= 0:
		_toast.text = ""
	# render the globe at the real window resolution (sharp), not at the 640x360 layout size
	var sc := get_viewport().get_final_transform().get_scale()
	var want := Vector2i(maxi(64, int(view.size.x * sc.x)), maxi(64, int(view.size.y * sc.y)))
	if vp.size != want:
		vp.size = want
	view.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hover != -1 else Control.CURSOR_ARROW
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hover != -1 and popup == null else Input.CURSOR_ARROW)
	# globe orientation: rotate so (yaw, tilt) faces the camera at +Z
	globe.basis = Basis(Vector3.RIGHT, tilt) * Basis(Vector3.UP, yaw)
	cam.position = Vector3(0, 0, zoom)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	# sun: the subsolar point (November: about 18 degrees south)
	var sun_lon := -(Campaign.utc_hours() - 12.0) * 15.0
	gmat.set_shader_parameter("sun_dir", latlon_to_local(Campaign.SUN_LAT, sun_lon))     # (the missions use the same sun: Campaign.sun_at)
	# time
	if popup == null and not Campaign.viewer and not Campaign.data.get("lost", false) and not Campaign.base_picking():
		if Campaign.advance(SPEEDS[speed] * delta):
			speed = 0
	if Campaign.viewer:
		# the host's clock runs on between his packets (each packet sets it right again)
		Campaign.data["day"] = float(Campaign.data["day"]) + Net.geo_speed * delta
	elif Net.is_online():
		_live_t -= delta
		if _live_t <= 0.0:
			_live_t = 0.25
			Net.send_geo_live(0.0 if popup != null or Campaign.data.get("lost", false) else SPEEDS[speed])
	_place(base_marker, Campaign.base_lat(), Campaign.base_lon())
	base_marker.visible = not Campaign.base_picking()
	_pick_tick()
	_ready_tick()
	_sync_markers()
	_sync_reports()
	_update_text()

## List of reports on the left: click = select and turn the globe there.
func _sync_reports() -> void:
	var all: Array = Campaign.data["missions"] + Campaign.data.get("flights", [])
	var key := ""
	for m in all:
		key += "%d," % int(m["id"])
	key += "|%d" % selected
	if key != report_key:
		report_key = key
		for c in report_box.get_children():
			c.queue_free()
		for m in all.slice(0, 12):
			var id := int(m["id"])
			var nm: String = ("UFO v letu: " + Campaign.UFO_NAMES[m["kind"]]) if m.has("kind") and not m.has("type") else (Campaign.MTYPES[m["type"]]["name"] + " - " + str(m["place"]))
			var mm: Dictionary = m
			var b := _btn(report_box, ("> " if id == selected else "") + nm, func(): selected = id; _focus(mm), 8)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# name tag pinned to the selected marker (projected from the globe every frame)
	tag_lbl.visible = false
	for m in all:
		if int(m["id"]) != selected and int(m["id"]) != hover:
			continue
		var wp := globe.global_transform * latlon_to_local(float(m["lat"]), float(m["lon"]), 1.02)
		if (wp - cam.global_position).dot(wp) > 0.0:
			continue
		var sp := cam.unproject_position(wp) / Vector2(vp.size) * view.size
		tag_lbl.text = (Campaign.UFO_NAMES[m["kind"]] if not m.has("type") else str(m["place"]))
		var off := 8.0
		if not m.has("type"):
			# (0.69) a 3D ship: the tag goes past its side, not over it when zoomed in
			var half := float(UFO_SIZE.get(String(m.get("kind", "")), 0.1)) * 0.5 * (1.6 if int(m["id"]) == selected else 1.3)
			var ep := cam.unproject_position(wp + cam.global_transform.basis.x * half) / Vector2(vp.size) * view.size
			off = maxf(off, ep.x - sp.x + 4.0)
		tag_lbl.position = sp + Vector2(off, -6)
		var tw := tag_lbl.get_minimum_size().x
		if tag_lbl.position.x + tw > view.position.x + view.size.x - 2.0:
			tag_lbl.position.x = sp.x - off - tw      # (near the right edge: on the other side)
		tag_lbl.visible = true
		if int(m["id"]) == selected:
			break

## How big the UFOs look over the globe (longest side, globe radius = 1).
const UFO_SIZE := {"scout": 0.075, "raider": 0.095, "harvester": 0.115, "supply": 0.135, "battleship": 0.14}

func _sync_markers() -> void:
	var ids := {}
	for m in Campaign.data["missions"]:
		var id := int(m["id"])
		ids[id] = true
		if not markers.has(id):
			var col := RED if m["type"] in ["terror", "base"] else ACCENT
			markers[id] = _marker(col, 0.045)
			_place(markers[id], float(m["lat"]), float(m["lon"]))
		var mk: Node3D = markers[id]
		var blink := fmod(t * 2.0, 1.0) < 0.6
		mk.visible = blink or id == selected
		mk.scale = Vector3.ONE * (1.6 if id == selected else (1.3 if id == hover else 1.0))
	for f in Campaign.data.get("flights", []):
		var id := int(f["id"])
		ids[id] = true
		if not markers.has(id):
			markers[id] = _craft_marker("ufo_" + String(f["kind"]), Color(1.0, 0.3, 0.25), UFO_SIZE.get(String(f["kind"]), 0.1))
		_glide(id, markers[id], float(f["lat"]), float(f["lon"]), float(f.get("heading", 0.0)))
		var on := fmod(t * 3.0, 1.0) < 0.7 or id == selected
		if markers[id].has_meta("craft"):
			markers[id].get_node("Ring").visible = on      # (the ship itself stays: only its ring blinks)
		else:
			markers[id].visible = on
		_mark_scale(markers[id], 1.6 if id == selected else (1.3 if id == hover else 1.0))
		_animate_craft(markers[id], get_process_delta_time())
	for c in Campaign.crafts():
		var cid := 900000 + int(c["id"])
		ids[cid] = true
		if not markers.has(cid):
			markers[cid] = _craft_marker({"jet": "sokol", "heli": "heli", "kondor": "dropship"}.get(String(c["kind"]), "dropship"), Color(0.35, 0.8, 1.0), {"jet": 0.065, "heli": 0.07}.get(String(c["kind"]), 0.08))
		_glide(cid, markers[cid], float(c["lat"]), float(c["lon"]))
		markers[cid].visible = true
		_animate_craft(markers[cid], get_process_delta_time())
	for id in markers.keys():
		if not ids.has(id):
			markers[id].queue_free()
			markers.erase(id)
			_shown.erase(id)
			_heading.erase(id)
			_last_ll.erase(id)
			if selected == id:
				selected = -1

func _gui_input(event: InputEvent) -> void:
	pass

## 0.66 (Ari): the game menu only through Esc or straight from the globe - Esc closes an open
## window first (one level up), on the bare globe it opens the game menu.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.is_action("pause"))):
		return
	get_viewport().set_input_as_handled()
	if popup != null:
		_close_popup()
	else:
		_game_menu()

func _game_menu() -> void:
	var box := _overlay("HERNÍ MENU", 260)
	_btn(box, "Pokračovat", _close_popup, 10)
	if Campaign.viewer:
		_btn(box, "Zpět do lobby", func(): get_tree().change_scene_to_file("res://scenes/Main.tscn"), 10)
	else:
		_btn(box, "Uložit a odejít do hlavního menu", _quit, 10)

func _input(event: InputEvent) -> void:
	if popup != null:
		return
	if not event is InputEventMouse:
		return
	var lp := view.get_local_mouse_position()
	var inside: bool = Rect2(Vector2.ZERO, view.size).has_point(lp)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and inside:
			zoom = max(1.6, zoom - 0.15)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and inside:
			zoom = min(4.5, zoom + 0.15)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			dragging = event.pressed and inside
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed and inside and pick_panel != null:
			_pick_click(lp)
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed and inside:
			var id := _pick_at(lp)
			if id != -1 or not Input.is_key_pressed(KEY_SHIFT):
				selected = id
	elif event is InputEventMouseMotion:
		if dragging:
			yaw += event.relative.x * 0.008 * zoom / 3.2
			tilt = clamp(tilt + event.relative.y * 0.008 * zoom / 3.2, -1.4, 1.4)
		hover = _pick_at(lp) if inside else -1
		if pick_panel != null:
			_pick_hover = _globe_ll(lp) if inside else Vector2.INF

# ---- 0.69: the host picks the place of the first base ----------------------------------------
var pick_panel: PanelContainer
var _pick_hover := Vector2.INF        # lat, lon under the mouse (INF = off the globe)
var _pick_at_ll := Vector2.INF        # the chosen place
var _pick_info: Label
var _pick_go: Button
var _pick_mark: Node3D
var _viewer_wait: Label
static var _region_tex: ImageTexture

## The blocs of 1990 painted into a map the globe shader reads (colour = the bloc, alpha = its number).
## (Drawn once into assets/textures/blocs_1990.png - the basepick test writes a fresh one to user://
## when Campaign.bloc_at changes; without the file it is drawn here, about 1,5 s.)
static func region_texture(fresh := false) -> ImageTexture:
	if _region_tex != null:
		return _region_tex
	if not fresh and ResourceLoader.exists("res://assets/textures/blocs_1990.png"):
		var tx: Texture2D = load("res://assets/textures/blocs_1990.png")
		_region_tex = ImageTexture.create_from_image(tx.get_image())
		return _region_tex
	var w := 1440
	var h := 720
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		var lat := 90.0 - (float(y) + 0.5) * 180.0 / h
		for x in w:
			var lon := (float(x) + 0.5) * 360.0 / w - 180.0
			if not Campaign.is_land(lat, lon):
				continue
			var b := Campaign.bloc_at(lat, lon)
			if b == "":
				continue
			var c: Color = Campaign.BLOCS[b]["color"]
			c.a = float(Campaign.BLOC_ORDER.find(b) + 1) / 16.0
			img.set_pixel(x, y, c)
	_region_tex = ImageTexture.create_from_image(img)
	return _region_tex

## Where on the globe (lat, lon) is this point of the view? INF = past the edge.
func _globe_ll(lp: Vector2) -> Vector2:
	var pos := lp / view.size * Vector2(vp.size)
	var o := cam.project_ray_origin(pos)
	var d := cam.project_ray_normal(pos)
	var b := o.dot(d)
	var c := o.dot(o) - 1.0
	var disc := b * b - c
	if disc < 0.0:
		return Vector2.INF
	var hit := o + d * (-b - sqrt(disc))
	var l := (globe.global_transform.affine_inverse() * hit).normalized()
	return Vector2(rad_to_deg(asin(clampf(l.y, -1.0, 1.0))), rad_to_deg(atan2(l.x, l.z)))

func _begin_pick() -> void:
	gmat.set_shader_parameter("region_tex", region_texture())
	gmat.set_shader_parameter("regions", 1.0)
	speed = 0
	pick_panel = PanelContainer.new()
	_style(pick_panel)
	pick_panel.position = Vector2(431, 0)
	pick_panel.size = Vector2(209, 360)
	pick_panel.clip_contents = true
	add_child(pick_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	pick_panel.add_child(box)
	var title := _lbl(box, "KDE BUDE ZÁKLADNA", ACCENT, 12)
	UiSkin.title(title, 11)
	_lbl(box, "Duben 1990. Vyber na glóbu místo první základny (jen pevnina). Každý blok dává jinou výhodu. Mise se budou objevovat hlavně v okolí.", TEXT, 8)
	var grid := GridContainer.new()
	grid.columns = 2
	box.add_child(grid)
	for bid in Campaign.BLOC_ORDER:
		var b: String = bid
		var bt := _btn(grid, Campaign.BLOCS[b]["name"], func(): _focus_bloc(b), 8)
		bt.custom_minimum_size = Vector2(94, 15)
		bt.add_theme_color_override("font_color", (Campaign.BLOCS[b]["color"] as Color).lerp(Color.WHITE, 0.35))
	var isc := ScrollContainer.new()
	isc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	isc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	isc.custom_minimum_size = Vector2(196, 40)
	box.add_child(isc)
	_pick_info = _lbl(isc, "", TEXT, 8)
	_pick_info.custom_minimum_size = Vector2(186, 0)
	_pick_go = _btn(box, "POSTAVIT ZÁKLADNU ZDE", _pick_confirm, 10)
	_btn(box, "Vysočina (jako dřív)", func():
		_pick_at_ll = Vector2(Campaign.BASE_LAT, Campaign.BASE_LON)
		_focus({"lat": Campaign.BASE_LAT, "lon": Campaign.BASE_LON}), 8)
	_pick_mark = _marker(Color(0.3, 0.9, 1.0), 0.035)
	_pick_mark.visible = false
	_focus({"lat": Campaign.BASE_LAT, "lon": Campaign.BASE_LON})

## A bloc's button: turn the globe to the middle of its land.
const BLOC_VIEW := {"na": [45.0, -98.0], "latam": [-10.0, -62.0], "west": [48.0, 4.0], "east": [50.0, 19.0], "ussr": [57.0, 70.0],
	"me": [28.0, 42.0], "africa": [3.0, 20.0], "asia": [30.0, 100.0], "pacific": [-20.0, 140.0]}
func _focus_bloc(b: String) -> void:
	var v: Array = BLOC_VIEW[b]
	_focus({"lat": v[0], "lon": v[1]})
	if _pick_at_ll == Vector2.INF or Campaign.bloc_at(_pick_at_ll.x, _pick_at_ll.y) != b:
		_pick_info_for(b, Vector2.INF)

func _pick_click(lp: Vector2) -> void:
	var ll := _globe_ll(lp)
	if ll == Vector2.INF:
		return
	if not Campaign.is_land(ll.x, ll.y) or Campaign.bloc_at(ll.x, ll.y) == "":
		Game.play_ui(self, "ui_back", -6)
		_toast_say("Tady je moře. Základnu jde postavit jen na pevnině.")
		return
	_pick_at_ll = ll
	Game.play_ui(self, "ui_confirm", -6)

func _pick_info_for(b: String, ll: Vector2) -> void:
	if _pick_info == null:
		return
	if b == "":
		_pick_info.text = "Najeď myší nebo klikni na pevninu."
		return
	var bl: Dictionary = Campaign.BLOCS[b]
	var where := ""
	if ll != Vector2.INF:
		where = "Místo: %s (%.1f°, %.1f°)\n" % [Campaign.nearest_place(ll.x, ll.y), ll.x, ll.y]
	_pick_info.text = "%s%s\n%s\n\nVÝHODA: %s" % [where, String(bl["name"]).to_upper(), bl["who"], bl["bonus"]]

func _pick_tick() -> void:
	if Campaign.viewer:
		# a teammate waits while the host picks
		if Campaign.base_picking() and _viewer_wait == null:
			_viewer_wait = _lbl(self, "Hostitel vybírá místo základny…", ACCENT, 10)
			_viewer_wait.position = Vector2(110, 314)      # (above the toast line at the bottom)
		elif not Campaign.base_picking() and _viewer_wait != null:
			_viewer_wait.queue_free()
			_viewer_wait = null
		return
	if pick_panel == null:
		return
	var seen := _pick_at_ll if _pick_at_ll != Vector2.INF else _pick_hover
	var b := ""
	if seen != Vector2.INF and Campaign.is_land(seen.x, seen.y):
		b = Campaign.bloc_at(seen.x, seen.y)
	if b != "" or _pick_at_ll == Vector2.INF:
		_pick_info_for(b, seen if b != "" else Vector2.INF)
	var hb := _pick_hover
	var hl := 0.0
	if hb != Vector2.INF and Campaign.is_land(hb.x, hb.y) and Campaign.bloc_at(hb.x, hb.y) != "":
		hl = float(Campaign.BLOC_ORDER.find(Campaign.bloc_at(hb.x, hb.y)) + 1) / 16.0
	elif _pick_at_ll != Vector2.INF:
		hl = float(Campaign.BLOC_ORDER.find(Campaign.bloc_at(_pick_at_ll.x, _pick_at_ll.y)) + 1) / 16.0
	gmat.set_shader_parameter("hl_bloc", hl)
	_pick_go.disabled = _pick_at_ll == Vector2.INF
	_pick_mark.visible = _pick_at_ll != Vector2.INF and fmod(t * 2.0, 1.0) < 0.75
	if _pick_at_ll != Vector2.INF:
		_place(_pick_mark, _pick_at_ll.x, _pick_at_ll.y)

func _pick_confirm() -> void:
	if _pick_at_ll == Vector2.INF or not Campaign.found_base(_pick_at_ll.x, _pick_at_ll.y):
		return
	Game.play_ui(self, "research_done", -4)
	gmat.set_shader_parameter("regions", 0.0)
	pick_panel.queue_free()
	pick_panel = null
	_pick_mark.queue_free()
	_pick_info = null
	Net.broadcast_team()
	var b: Dictionary = Campaign.BLOCS[Campaign.base_bloc()]
	_alert("ZÁKLADNA POSTAVENA\n%s - %s\n%s\n\nPusť čas. Radar hlídá oblohu." % [Campaign.base_place(), b["name"], b["bonus"]])

## Which marker is under this point of the globe view (view-local coordinates)? -1 = none.
## Tests the marker positions projected to the screen, so it works at any resolution and zoom.
func _pick_at(lp: Vector2) -> int:
	var pos := lp / view.size * Vector2(vp.size)
	var px_scale := float(vp.size.y) / 360.0
	var best := -1
	var bd := 14.0 * px_scale
	for m in Campaign.data["missions"] + Campaign.data.get("flights", []):
		var id := int(m["id"])
		var wp := globe.global_transform * latlon_to_local(float(m["lat"]), float(m["lon"]), 1.012 if m.has("type") else 1.0 + FLY_ALT)
		# skip the far side of the globe
		if (wp - cam.global_position).dot(wp) > 0.0:
			continue
		var sp := cam.unproject_position(wp)
		var d := sp.distance_to(pos)
		if d < bd:
			bd = d
			best = id
	return best

# ---- side panel ---------------------------------------------------------------------------------
func _style(c: Control, _bgc := PANEL) -> void:
	c.add_theme_stylebox_override("panel", UiSkin.panel(7))

func _lbl(parent: Node, s: String, col := TEXT, size := 9) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	parent.add_child(l)
	return l

func _btn(parent: Node, s: String, cb: Callable, size := 9) -> Button:
	var b := Button.new()
	b.text = s
	b.add_theme_font_size_override("font_size", size)
	UiSkin.button(b)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _build_side() -> void:
	var p := PanelContainer.new()
	_style(p)
	p.position = Vector2(431, 0)
	p.size = Vector2(209, 360)
	p.clip_contents = true
	add_child(p)
	side = VBoxContainer.new()
	side.add_theme_constant_override("separation", 3)
	p.add_child(side)
	var title := _lbl(side, "VELÍN", ACCENT, 13)
	UiSkin.title(title, 12)
	_build_ready()
	status_lbl = _lbl(side, "", TEXT, 8)
	var row := HBoxContainer.new()
	side.add_child(row)
	for i in (0 if Campaign.viewer else SPEEDS.size()):
		var k := i
		_btn(row, SPEED_NAMES[i], func(): speed = k, 8).custom_minimum_size = Vector2(44, 14)
	# the details of what is selected: takes whatever room is left and scrolls if it needs more
	var isc := ScrollContainer.new()
	isc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	isc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	isc.custom_minimum_size = Vector2(196, 40)
	side.add_child(isc)
	info_lbl = _lbl(isc, "", TEXT, 8)
	info_lbl.custom_minimum_size = Vector2(186, 0)
	info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var entries := [["Základna", _show_base], ["Výzkum", _show_research], ["Zbrojnice", _show_armory],
			["Výstroj", func(): _menu_screen("loadout")], ["Voják", func(): _menu_screen("merc")],
			["Úpravy zbraní", func(): _menu_screen("mods")],
			["Hlášení", _show_log], ["Encyklopedie", func(): _show_archive()], ["Hangár", _show_hangar]]
	if Campaign.viewer:
		# a co-op client: the host's globe, read-only; buying with own money
		_lbl(side, "Díváš se na základnu hostitele. Misi spouští on.", FRAME, 8)
		entries += [["Peníze v týmu", func(): _menu_screen("money")], ["Zpět do lobby", func(): get_tree().change_scene_to_file("res://scenes/Main.tscn")],
			["Na základnu (sám)", _go_base]]
	else:
		_btn(side, "VYSLAT (tým / stíhačku)", _launch, 10)
		entries += [["Na základnu", _go_base], ["Co-op / peníze týmu", func():
			if Net.is_online(): _menu_screen("money")
			else: _host()], ["Uložit a menu", _quit]]
	var grid := GridContainer.new()
	grid.columns = 2
	side.add_child(grid)
	for e in entries:
		_btn(grid, e[0], e[1], 8).custom_minimum_size = Vector2(94, 15)

func _update_text() -> void:
	var d: Dictionary = Campaign.data
	var r: Dictionary = d["research"]
	var rs := "nic"
	if r["current"] != "":
		var rr: Dictionary = Campaign.RESEARCH[r["current"]]
		rs = "%s %d %%" % [rr["name"], int(float(r["progress"]) / Campaign.research_days(r["current"]) * 100)]
	if not Campaign.kondor_ready():
		rs += "   Kondor za %d h" % Campaign.kondor_hours()
	var co := "\nOsobní majetek: %d kr" % Net.my_money()
	if Net.is_online():
		co += "\nCo-op: %d hráčů připojeno" % Net.roster.size()
	var air := []
	for c in Campaign.crafts():
		air.append("%s %s" % [("Stíhačka" if int(c.get("n", 1)) == 1 else "%d× stíhačka" % int(c.get("n", 1))) if c["kind"] == "jet" else Campaign.CRAFT_NAMES[c["kind"]].capitalize(), "letí k cíli" if c["state"] == "out" else ("u cíle" if c["state"] in ["arrived", "ambush"] else "se vrací")])
	if not air.is_empty():
		# (two jets out on the same errand read once: "2× stíhačka letí k cíli")
		var seen_air := {}
		var order := []
		for a in air:
			if not seen_air.has(a):
				order.append(a)
			seen_air[a] = int(seen_air.get(a, 0)) + 1
		co += "\nVe vzduchu: " + ", ".join(order.map(func(a): return a if int(seen_air[a]) == 1 else "%d× %s" % [seen_air[a], a.left(1).to_lower() + a.substr(1)]))
	status_lbl.text = "%s\nRozpočet základny: %d kr   Důvěra: %d %%\nMk-115: %d g   Výzkum: %s   Rychlost: %s%s" % [Campaign.date_text(), int(d["credits"]), int(d["trust"]), Campaign.moskovium(), rs, SPEED_NAMES[speed], co]
	var fl := _selected_flight()
	if not fl.is_empty():
		var left2: float = (float(fl["until"]) - float(d["day"])) * 24.0
		info_lbl.text = "UFO V LETU\n%s\nNad oblastí: %s\nZmizí z radaru asi za %d min\n\nStíhačky: %s\n\nPoškozené UFO spadne (mise s posádkou a kořistí). Rozstřílené na kusy nedá nic. Velká UFO střílí zpět." % [
			Campaign.UFO_NAMES[fl["kind"]], Campaign.nearest_place(float(fl["lat"]), float(fl["lon"])), int(left2 * 60),
			"připraveno %d z %d" % [Campaign.jets_ready(), Campaign.jets()]]
		return
	var m := _selected_mission()
	if m.is_empty():
		var n: int = d["missions"].size() + d.get("flights", []).size()
		info_lbl.text = "Radar hlídá oblohu.\n\n" + ("Na glóbu je %d hlášení - klikni na blikající značku." % n if n > 0 else "Pusť čas a čekej na hlášení.") + "\n\nPravé tlačítko: otáčet glóbem\nKolečko: přiblížit"
		return
	var left: float = (float(m["expires"]) - float(d["day"])) * 24.0
	var dph := Campaign.day_phase(float(m["lon"]), float(m.get("lat", Campaign.BASE_LAT)))
	var lh := Campaign.local_hour(float(m["lon"]))
	var biome: String = {"farm": "venkov, farma", "forest": "lesy", "town": "městečko", "industrial": "průmyslový areál", "mountain": "hory, horská chata", "polar": "polární pustina", "desert": "poušť", "base": "naše základna", "mars": "Mars"}.get(String(m["biome"]), "krajina")
	info_lbl.text = "%s\n%s  (%s)\nMístní čas %02d:%02d - %s\nVydrží ještě asi %d h\nOdhad posádky: %s\nOdměna: %d kr\n\n%s" % [
		Campaign.MTYPES[m["type"]]["name"].to_upper(), m["place"], biome, int(lh), int(fmod(lh, 1.0) * 60),
		{"noc": "NOC", "svitani": "svítání", "den": "den", "soumrak": "soumrak"}.get(dph, "den"), int(left), ["malá", "střední", "velká", "obrovská"][clampi(int(m["extra_aliens"]), 0, 3)],
		int(m["reward"]), Campaign.MTYPES[m["type"]]["text"]]

func _selected_flight() -> Dictionary:
	for f in Campaign.data.get("flights", []):
		if int(f["id"]) == selected:
			return f
	return {}

func _selected_mission() -> Dictionary:
	for m in Campaign.data["missions"]:
		if int(m["id"]) == selected:
			return m
	return {}

# ---- (0.7x) co-op: "Připraven" -----------------------------------------------------------------------
## Above the date and the time controls: my button and who of the team is ready. The host's starts
## (the drop, the jets, the fight, the base) wait until everybody is ready - or the host starts anyway.
var _ready_box: VBoxContainer
var _ready_btn: Button
var _ready_lbl: Label
var _ready_key := ""
var _gate_go := Callable()       # host: the start waiting for the team
var _gate_back := Callable()     # host: where "Zpět" goes (the window the start came from)
var _gate_what := ""
var _ready_heard := ""

func _build_ready() -> void:
	_ready_box = VBoxContainer.new()
	_ready_box.add_theme_constant_override("separation", 1)
	side.add_child(_ready_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_ready_box.add_child(row)
	_ready_btn = _btn(row, "PŘIPRAVEN", func(): Net.set_ready(not Net.is_ready(Net.my_id())), 9)
	_ready_btn.custom_minimum_size = Vector2(84, 16)
	_ready_btn.tooltip_text = "Dej najevo, že jsi připraven na další výsadek. Hostitel začne, až budou připraveni všichni."
	_ready_lbl = _lbl(row, "", TEXT, 8)
	_ready_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ready_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ready_lbl.custom_minimum_size = Vector2(100, 0)
	_ready_box.visible = false

func _ready_tick() -> void:
	if _ready_box == null:
		return
	var on: bool = Net.is_online() and not Campaign.data.get("lost", false)
	_ready_box.visible = on
	if not on:
		_gate_go = Callable()
		return
	if Net.ready_wait != _ready_heard:
		if Net.ready_wait != "" and Campaign.viewer:
			Game.play_ui(self, "radar_ping", -6)       # (a client: the host waits for us)
		_ready_heard = Net.ready_wait
	var me := Net.is_ready(Net.my_id())
	var waiting := Net.not_ready()
	var key := "%s|%s|%s|%d" % [me, ",".join(waiting), Net.ready_wait, Net.roster.size()]
	if key != _ready_key:
		_ready_key = key
		_ready_btn.text = "[X] PŘIPRAVEN" if me else "[  ] PŘIPRAVEN"
		_ready_btn.add_theme_color_override("font_color", Color(0.5, 1.0, 0.55) if me else TEXT)
		var n := Net.roster.size()
		var t := "Připraveni %d/%d" % [n - waiting.size(), n]
		if waiting.is_empty():
			t += " - všichni"
		elif waiting.size() <= 2:
			t += "\nčeká se: " + ", ".join(waiting)
		else:
			t += "\nčeká se na %d" % waiting.size()
		_ready_lbl.text = t
		_ready_lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.55) if waiting.is_empty() else (ACCENT if Net.ready_wait != "" else TEXT))
		if popup and popup.has_meta("ready_wait"):
			_show_gate()
	# host: the start goes as soon as everybody is ready
	if _gate_go.is_valid() and Net.is_online() and multiplayer.is_server():
		if Net.all_ready():
			_gate_run()
		elif popup == null:
			_show_gate()      # (another window took its place: back to the waiting)

## Host: start now when the team is ready (or playing alone), otherwise wait for it.
func _gate(what: String, go: Callable, back := Callable()) -> void:
	if not Net.is_online() or not multiplayer.is_server() or Net.all_ready() and Net.roster.size() > 0 \
			or (Game.autotest() != "" and not Game.autotest().begins_with("ready")):
		_close_popup()
		go.call()
		return
	_gate_go = go
	_gate_back = back
	_gate_what = what
	Net.ask_ready(what)
	if Net.all_ready():
		_gate_run()
		return
	_show_gate()

func _show_gate() -> void:
	var box := _overlay("ČEKÁ SE NA TÝM", 330)
	popup.set_meta("ready_wait", true)
	popup.position.x = (431.0 - 330.0) / 2.0     # (over the globe: the team's PŘIPRAVEN stays in sight)
	_lbl(box, _gate_what, TEXT, 9)
	var waiting := Net.not_ready()
	_lbl(box, "Připraveni %d z %d. Ještě nejsou: %s" % [Net.roster.size() - waiting.size(), Net.roster.size(), ", ".join(waiting)], ACCENT, 9).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl(box, "Začne se samo, až všichni zmáčknou PŘIPRAVEN.", FRAME, 8)
	var row := HBoxContainer.new()
	box.add_child(row)
	_btn(row, "Začít hned", _gate_run, 10)
	_btn(row, "Zpět", func():
		var back := _gate_back
		_gate_go = Callable()
		_gate_back = Callable()
		Net.stop_waiting()
		_close_popup()
		if back.is_valid():
			back.call(), 10)

func _gate_run() -> void:
	var go := _gate_go
	_gate_go = Callable()
	_gate_back = Callable()
	_close_popup()
	Net.stop_waiting()
	if go.is_valid():
		go.call()

# ---- actions -------------------------------------------------------------------------------------
## Who flies what (co-op): peer ids picked in the launch window.
var _pick := {}

func _launch() -> void:
	var fl := _selected_flight()
	if not fl.is_empty():
		_launch_jets(fl)
		return
	var m := _selected_mission()
	if m.is_empty():
		_alert("Nejdřív vyber hlášení na glóbu.")
		return
	# X-PSI-002: no landing on Mars without the crew shield in the Pelikán
	if m["type"] == "mars" and not Campaign.built("psi_ochrana"):
		_alert("Výsadek nepovolen\nVelitelství Projektu X nepustí Pelikán k Marsu bez lodní psionické ochrany posádky (CPS-01).")
		return
	# the base and Mars: nobody has to fly anywhere first
	if m["type"] in ["base", "mars"]:
		_gate("Mise: %s" % m.get("place", "?"), func(): _start_ground(m))
		return
	for c in Campaign.crafts():
		if c["kind"] != "jet" and int(c["target"]) == int(m["id"]):
			_alert("Transport už k cíli letí.")
			return
	if Campaign.transport_out():
		_alert("Transport je ve vzduchu\n%s je na cestě. Počkej, až se vrátí do hangáru." % Campaign.CRAFT_NAMES[Campaign.transport()].capitalize())
		return
	if not Campaign.kondor_ready():
		_alert("Transport je ztracen\nNáhradní stroj dorazí do hangáru za %d h. Nech čas běžet." % Campaign.kondor_hours())
		return
	_launch_transport(m)

## Before a fight in the air: who sits in the Sokols.
func _launch_jets(fl: Dictionary) -> void:
	var ready := Campaign.jets_ready()
	if ready <= 0:
		_alert("Žádná stíhačka není připravena\nStíhačky jsou v opravě nebo ve vzduchu.")
		return
	var eta := Campaign.eta_hours("jet", float(fl["lat"]), float(fl["lon"]))
	var left: float = (float(fl["until"]) - float(Campaign.data["day"])) * 24.0
	var box := _overlay("VYSLAT STÍHAČKY", 360)
	_lbl(box, "%s nad oblastí %s.\nLet k UFO asi %.1f h, z radaru zmizí asi za %.1f h.%s" % [Campaign.UFO_NAMES[fl["kind"]], Campaign.nearest_place(float(fl["lat"]), float(fl["lon"])), eta, left,
		"\nNEJSPÍŠ NESTIHNOU - UFO uletí dřív." if eta > left else ""], RED if eta > left else TEXT, 9)
	if Net.is_online():
		if _pick.is_empty():
			_pick = {1: true}
		_lbl(box, "Kdo usedne do stíhaček (připraveno %d) - klikni na jméno:" % ready, ACCENT, 9)
		for id in Net.roster:
			var pid: int = id
			var on: bool = _pick.get(pid, false)
			_btn(box, ("[X] " if on else "[  ] ") + str(Net.roster[pid]["name"]), func():
				if _pick.get(pid, false):
					_pick.erase(pid)
				elif _pick.size() < ready:
					_pick[pid] = true
				else:
					_pick.erase(_pick.keys()[0])   # all seats taken: the first one hands his Sokol over
					_pick[pid] = true
				_launch_jets(fl), 9)
	else:
		_lbl(box, "Letíš sám (stíhaček připraveno: %d)." % ready, ACCENT, 9)
	var row := HBoxContainer.new()
	box.add_child(row)
	_btn(row, "VZLÉTNOUT", func(): _gate("Stíhačky k UFO (%s)" % Campaign.UFO_NAMES[fl["kind"]], func(): _go_jets(fl), func(): _launch_jets(fl)), 10)
	_btn(row, "Zrušit", func(): _pick = {}; _close_popup(), 10)

func _go_jets(fl: Dictionary) -> void:
	var pilots: Array = [1]
	if Net.is_online():
		pilots = _pick.keys().filter(func(k): return k is int)
		if pilots.is_empty():
			return
	_pick = {}
	_close_popup()
	Campaign.launch_craft("jet", fl, "flight", {"n": pilots.size(), "pilots": pilots})
	Game.play_ui(self, "ui_confirm", -4)
	_toast_say("Stíhačky vzlétly. Pusť čas - na místě začne souboj.")

## Before a ground mission: the transport flies there; jets can go along as escort.
var _escort := 0
func _launch_transport(m: Dictionary) -> void:
	var tk := Campaign.transport()
	var eta := Campaign.eta_hours(tk, float(m["lat"]), float(m["lon"]))
	var left: float = (float(m["expires"]) - float(Campaign.data["day"])) * 24.0
	var ready := Campaign.jets_ready()
	_escort = mini(_escort, ready)
	var box := _overlay("VYSLAT TÝM", 380)
	_lbl(box, "%s - %s\n%s poletí asi %.1f h, hlášení vydrží asi %.1f h.%s" % [Campaign.MTYPES[m["type"]]["name"], m["place"], Campaign.CRAFT_NAMES[tk].capitalize(), eta, left,
		"\nNESTIHNE TO - než dorazí, vetřelci budou pryč." if eta > left else ""], RED if eta > left else TEXT, 9)
	if tk == "heli":
		_lbl(box, "Čáp je pomalý. Výzkum Transportér Kondor zkrátí lety asi na třetinu.", FRAME, 8)
	_lbl(box, "Doprovod stíhaček (chrání transport, když ho cestou napadnou): %d / %d" % [_escort, ready], ACCENT, 9)
	var er := HBoxContainer.new()
	box.add_child(er)
	_btn(er, " - ", func(): _escort = maxi(0, _escort - 1); _launch_transport(m), 9)
	_btn(er, " + ", func(): _escort = mini(ready, _escort + 1); _launch_transport(m), 9)
	if Net.is_online():
		_lbl(box, "Kdo řídí transport (ostatní letí v doprovodu, pokud je stíhačka):", FRAME, 8)
		var drv: int = int(_pick.get("driver", 1))
		var dr := HBoxContainer.new()
		box.add_child(dr)
		_btn(dr, ("> " if drv == 0 else "") + "AI pilot", func(): _pick["driver"] = 0; _launch_transport(m), 8)
		for id in Net.roster:
			var pid: int = id
			_btn(dr, ("> " if drv == pid else "") + str(Net.roster[pid]["name"]), func(): _pick["driver"] = pid; _launch_transport(m), 8)
	var row := HBoxContainer.new()
	box.add_child(row)
	_btn(row, "VZLÉTNOUT", func(): _gate("Výsadek: %s" % m.get("place", "?"), func(): _go_transport(m, tk), func(): _launch_transport(m)), 10)
	_btn(row, "Zrušit", func(): _pick = {}; _close_popup(), 10)

func _go_transport(m: Dictionary, tk: String) -> void:
	var drv2: int = int(_pick.get("driver", 0 if not Net.is_online() else 1))
	var pilots := []
	if Net.is_online():
		for id in Net.roster:
			if id != drv2 and pilots.size() < _escort:
				pilots.append(id)
	elif _escort > 0:
		pilots = [1]
		drv2 = 0
	_pick = {}
	_close_popup()
	Campaign.launch_craft(tk, m, "mission", {"escort": _escort, "pilots": pilots, "driver": drv2})
	Game.play_ui(self, "ui_confirm", -4)
	_toast_say("%s vzlétl. Pusť čas - u cíle začne mise." % Campaign.CRAFT_NAMES[tk].capitalize())

func _toast_say(s: String) -> void:
	if _toast:
		_toast.text = s
		_toast_t = 4.0

## The craft is at the target: the fight or the mission begins.
func _on_arrived(c: Dictionary) -> void:
	speed = 0
	if c["kind"] == "jet":
		var fl := Campaign._target_of(c)
		var box := _overlay("SOKOL U CÍLE", 320)
		_lbl(box, "%s má UFO na radaru. Zbraně odjištěny." % ("Stíhačka" if int(c.get("n", 1)) == 1 else "%d stíhačky" % int(c.get("n", 1))), TEXT, 9)
		_btn(box, "DO BOJE", func():
			_gate("Souboj se UFO", func(): _start_air(c, fl), func(): _on_arrived(c)), 10)
		return
	var m := Campaign._target_of(c)
	var box2 := _overlay("PŘISTÁNÍ", 320)
	_lbl(box2, "%s dosedl u cíle: %s.\nRampa se otevře, až budete připraveni." % [Campaign.CRAFT_NAMES[c["kind"]].capitalize(), m.get("place", "?")], TEXT, 9)
	_btn(box2, "ZAČÍT MISI", func(): _gate("Mise: %s" % m.get("place", "?"), func(): _begin_landed(c, m), func(): _on_arrived(c)), 10)

func _begin_landed(c: Dictionary, m: Dictionary) -> void:
	_close_popup()
	if not _start_ground(m):
		Campaign.recall_craft(c, "Mise nezačala - transport se vrací.")

func _start_air(c: Dictionary, fl: Dictionary) -> void:
	if fl.is_empty():
		Campaign.recall_craft(c, "UFO zmizelo - stíhačky se vracejí.")
		return
	Campaign.save()
	var ip := Campaign.intercept_params(fl)
	if Net.is_online():
		ip["pilots"] = c.get("pilots", [1])
		Net.start_intercept(ip)
	else:
		Net.mission_params = ip
		Game.load_scene("res://scenes/Intercept.tscn")

## Everyone down into the base: walk round it between missions (back up at the velín terminal).
func _go_base() -> void:
	if not Campaign.viewer:
		Campaign.save()
	if not Net.is_online():
		Net.play_solo()
	var live := []
	for k in Campaign.data.get("found", {}):
		if String(k).begins_with("live_") and int(Campaign.data["found"][k]) > 0:
			for n in mini(int(Campaign.data["found"][k]), 2):
				live.append(String(k).substr(5))
	var params := {"type": "home", "type_name": "Základna", "base": Campaign.data["base"].duplicate(true), "grid_w": Campaign.GRID_W, "grid_h": Campaign.GRID_H,
		"transport": Campaign.transport(), "where": Campaign.base_place(), "live": live, "research": Campaign.active_research(), "night": false, "hour": 12.0, "fallen": (Campaign.data.get("fallen", []) as Array).duplicate(true),
		"blips": Campaign.data["flights"].map(func(f): return [float(f.get("lat", 0)), float(f.get("lon", 0))]) + Campaign.data["missions"].map(func(m): return [float(m.get("lat", 0)), float(m.get("lon", 0))])}
	if Campaign.viewer or Net.is_online():
		# (0.7x) co-op: everyone goes down alone (own copy), the others stay on the globe; the host's
		# campaign runs on under him. A drop the host starts later pulls everybody up again.
		if not Campaign.viewer:
			Net.stop_waiting()
		Net.start_local_base(params)
	else:
		Net.start_mission(params)

func _start_ground(m: Dictionary) -> bool:
	Campaign.save()
	if not Net.is_online():
		Net.play_solo()
	return Net.start_mission(Campaign.mission_params(m))

## On the way, small UFOs jump the transport: the escort (and the transport pilot) fight it out.
func _on_ambush(c: Dictionary) -> void:
	speed = 0
	var box := _overlay("TRANSPORT NAPADEN!", 340)
	var esc := int(c.get("escort", 0))
	_lbl(box, "Cestou k cíli se na %s vrhla malá UFO.\n%s" % [Campaign.CRAFT_NAMES[c["kind"]], ("Doprovod %d stíhaček se otáčí k obraně." % esc) if esc > 0 else "Bez doprovodu: pilot musí uniknout."], RED, 9)
	_btn(box, "BRÁNIT TRANSPORT", func(): _gate("Obrana transportu", func(): _begin_escort(c), func(): _on_ambush(c)), 10)

func _begin_escort(c: Dictionary) -> void:
	_close_popup()
	Campaign.save()
	var ep := {"escort": true, "craft": int(c["id"]), "transport": c["kind"], "jet_armor": Campaign.built("pancir_letadel"), "escort_n": int(c.get("escort", 0)), "pilots": c.get("pilots", []), "driver": int(c.get("driver", 0))}
	ep["night"] = Campaign.is_night(float(c.get("lon", Campaign.BASE_LON)), float(c.get("lat", Campaign.BASE_LAT)))      # day or night where they meet
	if Net.is_online():
		Net.start_escort(ep)
	else:
		Net.mission_params = ep
		Game.load_scene("res://scenes/Escort.tscn")

func _host() -> void:
	if Net.is_online():
		_alert("Co-op už běží. Kamarádi se připojí přes 'Připojit ke hře' na tvou IP.\nPřipojeno: %d" % Net.roster.size())
		return
	var err := Net.host()
	_alert("Hostuješ hru na portu %d.\nKamarádi: hlavní menu → Připojit ke hře → tvoje IP.\nPak vyber misi a vyšli tým." % Net.PORT if err == "" else err)

func _quit() -> void:
	Campaign.save()
	Net.close()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _menu_screen(which: String) -> void:
	Campaign.save()
	Game.open_screen = which
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

# ---- overlays ---------------------------------------------------------------------------------------
func _overlay(title: String, w := 400.0) -> VBoxContainer:
	_close_popup()
	popup = PanelContainer.new()
	_style(popup, Color(0.04, 0.07, 0.15, 0.98))
	popup.position = Vector2((640 - w) / 2, 14)
	popup.custom_minimum_size = Vector2(w, 0)
	add_child(popup)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	popup.add_child(box)
	var tl := _lbl(box, title, ACCENT, 12)
	UiSkin.title(tl, 12)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return box

## A scrolling area inside an overlay (long lists).
func _scroll(box: VBoxContainer, h := 280.0) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, h)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(sc)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 3)
	sc.add_child(inner)
	return inner

func _close_popup() -> void:
	if popup:
		popup.queue_free()
		popup = null

func _alert(text: String) -> void:
	var parts := text.split("\n", true, 1)
	if parts[0].begins_with("Nelze") or parts[0].begins_with("Nemáš") or parts[0].begins_with("Stavba"):
		Game.play_ui(self, "ui_deny", -6)
	var box := _overlay(parts[0], 330)
	if parts.size() > 1:
		_lbl(box, parts[1], TEXT, 9)
	_btn(box, "OK", _close_popup, 10)

## (0.7x) The hangar straight from the globe: what flies, and a Sokol bought from the base budget
## or from one's own money (co-op friends too - no need to go through the base screen).
func _show_hangar() -> void:
	var box := _overlay("HANGÁR - STÍHAČKY", 360)
	_lbl(box, "Ve službě: %d z %d, připraveno k letu %d%s." % [Campaign.jets(), Campaign.MAX_JETS, Campaign.jets_ready(),
		(", z toho Jestřábů %d" % Campaign.hawks()) if Campaign.hawks() > 0 else ""], TEXT, 8)
	var coming := Campaign.crafts_coming("sokol") + Campaign.crafts_coming("jestrab")
	if coming > 0:
		_lbl(box, "Na cestě nebo v dílně: %d" % coming, ACCENT, 8)
	var price := Campaign.jet_price()
	_lbl(box, "Nový Sokol stojí %d kr a v hangáru je druhý den. Tvoje peníze: %d kr." % [price, Net.my_money()], FRAME, 8).custom_minimum_size = Vector2(340, 0)
	if not Campaign.jet_room():
		_lbl(box, "Hangár je plný.", ACCENT, 8)
	else:
		var mine := _btn(box, "Koupit Sokol ze svých peněz - %d kr" % price, func():
			if Net.my_money() < price:
				_alert("Nelze koupit\nNemáš dost vlastních peněz.")
				return
			Net.buy_jet_mine()
			Game.play_ui(self, "money", -10)
			await get_tree().create_timer(0.5).timeout
			_show_hangar(), 9)
		mine.disabled = Net.my_money() < price
		if not Campaign.viewer:
			var bb := _btn(box, "Koupit Sokol z rozpočtu základny (%d kr)" % int(Campaign.data["credits"]), func():
				if Campaign.buy_jet():
					Game.play_ui(self, "money", -10)
					Net.broadcast_team()
					_show_hangar()
				else: _alert("Nelze koupit\nV rozpočtu základny není dost kreditů."), 9)
			bb.disabled = int(Campaign.data["credits"]) < price
	var row := HBoxContainer.new()
	box.add_child(row)
	if not Campaign.viewer:
		_btn(row, "Výzbroj a dílna...", func(): _show_base(1), 9)
	_btn(row, "Zavřít", _close_popup, 9)

func _show_log() -> void:
	var box := _overlay("HLÁŠENÍ", 460)
	var log: Array = Campaign.data["log"]
	var st: Dictionary = Campaign.data["stats"]
	_lbl(box, "Mise %d (úspěšných %d), zabito %d, zajato %d" % [st["missions"], st["won"], st["kills"], st["captures"]], ACCENT, 8)
	_lbl(box, "\n".join(log.slice(max(0, log.size() - 14))), TEXT, 8)
	_btn(box, "Zavřít", _close_popup)

func _show_archive(entry := "") -> void:
	_close_popup()
	Encyclopedia.open(self, entry)

func _show_research() -> void:
	_close_popup()
	var rs := ResearchScreen.open(self)
	rs.on_changed = func(): _update_text()
	rs.on_close = func(): _update_text()

func _show_armory() -> void:
	var box := _overlay("ZBROJNICE - NÁKUP", 500)
	var base_pay := "ze svých peněz" if Campaign.viewer else "z rozpočtu základny (%d kr)" % int(Campaign.data["credits"])
	_lbl(box, "Běžná výbava od dodavatelů, ve skladu je druhý den. DO SKLADU = pro celý tým natrvalo, platí se %s. SOBĚ = jen do tvé skříňky, ze tvých peněz (%d kr). Co jsme vyzkoumali, nikdo neprodá - to vyrábí dílna." % [base_pay, Net.my_money()], FRAME, 8).custom_minimum_size = Vector2(480, 0)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	_scroll(box, 215).add_child(grid)
	var locker: Dictionary = Game.merc.get("locker", {})
	for id in Campaign.SHOP:
		if not Game.ITEMS.has(id) or Campaign.workshop_item(id):
			continue
		var key: String = id
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		grid.add_child(row)
		var arm_n := int(Campaign.data["armory"].get(id, 0))
		var ord_n := Campaign.on_order(id)
		var name_b := _btn(row, "%s  %d kr\nsklad %d%s, tvoje %d" % [Game.ITEMS[id]["short"], Campaign.price(id), arm_n, (" +%d zítra" % ord_n) if ord_n > 0 else "", int(locker.get(id, 0))], func(): pass, 8)
		name_b.custom_minimum_size = Vector2(150, 24)
		name_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiSkin.item_icon(name_b, key, 30)
		var bb := _btn(row, "Sklad", func():
			if Campaign.viewer:
				if Net.my_money() < Campaign.price(key):
					_alert("Nelze koupit\nNemáš dost peněz.")
					return
				Net.buy_for_base(key)
				await get_tree().create_timer(0.5).timeout
				_show_armory()
			elif Campaign.buy(key):
				Game.play_ui(self, "money", -10)
				_show_armory()
			else: _alert("Nelze koupit\nV rozpočtu základny není dost kreditů."), 8)
		bb.custom_minimum_size = Vector2(38, 24)
		var mb := _btn(row, "Sobě", func():
			if Game.buy_for_me(key): Game.play_ui(self, "money", -10); _show_armory()
			else: _alert("Nelze koupit\nNemáš dost vlastních peněz."), 8)
		mb.custom_minimum_size = Vector2(38, 24)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 6)
	box.add_child(foot)
	_btn(foot, "Dílna - výroba...", _show_workshop, 9)
	_btn(foot, "Prodat ze skladu a kořisti...", _show_sell, 9)
	_btn(box, "Zavřít", _close_popup)

## The workshop: what research opened is made here - credits, alloys from the wrecks,
## Moskovium, and days on a line. Only the host orders it (it is his base).
func _show_workshop() -> void:
	var box := _overlay("DÍLNA - VÝROBA", 500)
	var lines := Campaign.workshop_lines()
	_lbl(box, "Dílny: %d (tempo %d %%). Kredity základny: %d   Slitiny: %d ks   Moskovium 115: %d g" % [lines, int(round(Campaign.workshop_rate() * 100.0)), int(Campaign.data["credits"]), Campaign.alloys(), Campaign.moskovium()], FRAME, 8).custom_minimum_size = Vector2(480, 0)
	if lines == 0:
		_lbl(box, "Základna nemá dílnu. Bez ní se nic nevyrobí.", ACCENT, 8)
	elif Campaign.viewer:
		_lbl(box, "Výrobu zadává a platí hostitel.", FRAME, 8)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	_scroll(box, 190).add_child(grid)
	var n := 0
	for id in Campaign.SHOP:
		if not Game.ITEMS.has(id) or not Campaign.workshop_item(id) or not Campaign.unlocked(id):
			continue
		n += 1
		var key: String = id
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		grid.add_child(row)
		var parts := ["%d kr" % Campaign.price(id)]
		if Campaign.SHOP_AL.has(id): parts.append("%d sl." % int(Campaign.SHOP_AL[id]))
		if Campaign.SHOP_MK.has(id): parts.append("%d g" % int(Campaign.SHOP_MK[id]))
		for it in Campaign.MAKE_EATS.get(id, {}):
			parts.append("%d× %s" % [int(Campaign.MAKE_EATS[id][it]), String(Game.ITEMS[it]["short"])])
		var ord_n := Campaign.on_order(id)
		var name_b := _btn(row, "%s  %s, %s\nsklad %d%s" % [Game.ITEMS[id]["short"], " + ".join(parts), _span(Campaign.make_days(id) / maxf(Campaign.workshop_rate(), 1.0)),
			int(Campaign.data["armory"].get(id, 0)), (", vyrábí se %d" % ord_n) if ord_n > 0 else ""], func(): pass, 8)
		name_b.custom_minimum_size = Vector2(190, 24)
		name_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiSkin.item_icon(name_b, key, 30)
		var mb := _btn(row, "Vyrobit", func():
			if Campaign.make(key):
				Game.play_ui(self, "money", -10)
				_show_workshop()
			else: _alert("Nelze vyrobit\nChybí kredity, slitiny nebo Moskovium 115."), 8)
		mb.custom_minimum_size = Vector2(46, 24)
		mb.disabled = Campaign.viewer or lines == 0
	# what research designed for the whole unit (vests, helmets, the fighters): made once, then everyone has it
	for uid in Campaign.UPGRADES:
		if not Campaign.researched(uid) or Campaign.built(uid):
			continue
		n += 1
		var ukey: String = uid
		var u: Dictionary = Campaign.UPGRADES[uid]
		var urow := HBoxContainer.new()
		urow.add_theme_constant_override("separation", 2)
		grid.add_child(urow)
		var up := ["%d kr" % Campaign.upgrade_price(uid)]
		if u.has("al"): up.append("%d sl." % int(u["al"]))
		if u.has("mk"): up.append("%d g" % int(u["mk"]))
		var ub := _btn(urow, "%s\n%s, %s%s" % [u["name"], " + ".join(up), _span(float(u["days"]) * Campaign.time_k() / maxf(Campaign.workshop_rate(), 1.0)),
			", vyrábí se" if Campaign.upgrade_coming(uid) else ""], func(): pass, 8)
		ub.custom_minimum_size = Vector2(190, 24)
		ub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiSkin.item_icon(ub, String(Campaign.RESEARCH[uid].get("icon", "")), 30)
		var umb := _btn(urow, "Vyrobit", func():
			if Campaign.make_upgrade(ukey):
				Game.play_ui(self, "money", -10)
				_show_workshop()
			else: _alert("Nelze vyrobit\nChybí kredity, slitiny nebo Moskovium 115."), 8)
		umb.custom_minimum_size = Vector2(46, 24)
		umb.disabled = Campaign.viewer or lines == 0 or Campaign.upgrade_coming(uid)
	if n == 0:
		_lbl(box, "Zatím není co vyrábět.", FRAME, 8)
	# the queue
	var q := []
	var now := float(Campaign.data["day"])
	for o in Campaign.data.get("orders", []):
		if o.get("made", false):
			var it := String(o["item"])
			var nm: String = Campaign.queue_name(it)
			q.append([float(o["at"]), "%s (%s)" % [nm, _span(float(o["at"]) - now)]])
	q.sort_custom(func(x, y): return x[0] < y[0])
	var ql := []
	for e in q:
		ql.append(e[1])
	_lbl(box, ("Ve výrobě: " + ", ".join(ql)) if not ql.is_empty() else "Dílna stojí - nic se nevyrábí.", TEXT, 8).custom_minimum_size = Vector2(480, 0)
	_btn(box, "Zpět", _show_armory)

## "5 h" / "2,5 dne"
func _span(d: float) -> String:
	var h := ceili(maxf(d, 0.0) * 24.0)
	return ("%d h" % h) if h < 24 else ("%s dne" % String.num(d, 1).replace(".", ","))

## The black market: spare gear from the armory (40 % of the price) and alien loot.
func _show_sell() -> void:
	var box := _overlay("PRODEJ", 500)
	_lbl(box, "Co se prodá, je pryč. Výbava ze skladu za 40 % ceny, mimozemská kořist na černém trhu. Kredity základny: %d." % int(Campaign.data["credits"]), FRAME, 8).custom_minimum_size = Vector2(480, 0)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	_scroll(box, 250).add_child(grid)
	var n := 0
	for id in Campaign.data["armory"]:
		if not Game.ITEMS.has(id) or int(Campaign.data["armory"][id]) <= 0:
			continue
		var key: String = id
		var b := _btn(grid, "%s (%dx) - prodat za %d kr" % [Game.ITEMS[id]["short"], int(Campaign.data["armory"][id]), Campaign.sell_price(id)], func():
			if Campaign.sell(key): Game.play_ui(self, "money", -10); _show_sell(), 8)
		b.custom_minimum_size = Vector2(235, 22)
		b.disabled = Campaign.viewer
		n += 1
	var found: Dictionary = Campaign.data.get("found", {})
	for k in Campaign.LOOT_SELL:
		if int(found.get(k, 0)) <= 0:
			continue
		var key2: String = k
		var b2 := _btn(grid, "%s (%dx) - prodat za %d kr" % [Campaign.loot_name(k).replace("tělo: ", ""), int(found[k]), Campaign.loot_sell_price(k)], func():
			if Campaign.sell_loot(key2): Game.play_ui(self, "money", -10); _show_sell(), 8)
		b2.custom_minimum_size = Vector2(235, 22)
		b2.disabled = Campaign.viewer
		n += 1
	if n == 0:
		_lbl(box, "Není co prodat.", FRAME, 9)
	_btn(box, "Zpět", _show_armory)

## 0.57: the base screen of its own - the plan from above, the rooms, building, the hangar.
func _show_base(select := -1) -> void:
	_close_popup()
	BaseScreen.open(self, select)

func _build_menu(idx: int) -> void:
	_show_base(idx)

# ---- tests -----------------------------------------------------------------------------------------
func _ui_check(tag: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	Game.ui_audit(self, tag)
	# the side panel clips what does not fit (so the audit cannot see it): measure it here
	var need := side.get_combined_minimum_size().y
	var have := (side.get_parent() as Control).size.y - 8.0
	if need > have:
		print("[UI] %s: postranní panel přetéká o %.0f px (potřebuje %.0f, má %.0f)" % [tag, need - have, need, have])
	if DisplayServer.get_name() != "headless":
		get_viewport().get_texture().get_image().save_png("user://ui_%s.png" % tag)

func _autotest() -> void:
	if Game.autotest() == "readyhost":
		# (0.7x) the host's start waits for the client's PŘIPRAVEN
		await get_tree().create_timer(1.0).timeout
		var ran := [false]
		_gate("Výsadek: test", func(): ran[0] = true)
		await get_tree().create_timer(3.0).timeout
		var early: bool = ran[0]
		var shown := popup != null and popup.has_meta("ready_wait")
		await _ui_check("ready_host")
		var t0 := Time.get_ticks_msec()
		while not ran[0] and Time.get_ticks_msec() - t0 < 20000:
			await get_tree().create_timer(0.1).timeout
		print("RESULT readyhost early %s window %s ran %s wait '%s'" % [early, shown, ran[0], Net.ready_wait])
		await get_tree().create_timer(1.0).timeout
		get_tree().quit()
		return
	if Game.autotest() == "readyclient":
		var t1 := Time.get_ticks_msec()
		while Net.ready_wait == "" and Time.get_ticks_msec() - t1 < 15000:
			await get_tree().create_timer(0.1).timeout
		var saw := Net.ready_wait
		await get_tree().create_timer(4.0).timeout     # (the host checks meanwhile that nothing started)
		var lbl := _ready_lbl.text.replace("\n", " / ")
		await _ui_check("ready_client")
		Net.set_ready(true)
		var t2 := Time.get_ticks_msec()
		while Net.ready_wait != "" and Time.get_ticks_msec() - t2 < 10000:
			await get_tree().create_timer(0.1).timeout
		print("RESULT readyclient saw '%s' panel '%s' me %s done %s" % [saw, lbl, Net.is_ready(Net.my_id()), Net.ready_wait == ""])
		get_tree().quit()
		return
	if Game.autotest() == "hbhost":
		# back up from the own base: a drop now pulls the client out of wherever he is
		await get_tree().create_timer(2.0).timeout
		print("[HB] host on the globe again, starts a drop")
		Net.start_mission({"type": "crash", "biome": "farm", "night": false, "hour": 14.0, "place": "Test", "type_name": "Test", "id": -1})
		return
	if Game.autotest() == "hbclient":
		# the host is down in his base meanwhile: our globe must stay ours and the clock go on
		var t0 := Time.get_ticks_msec()
		while not Net.in_own_base() and Time.get_ticks_msec() - t0 < 4000:
			await get_tree().create_timer(0.2).timeout
		var d0 := float(Campaign.data["day"])
		await get_tree().create_timer(5.0).timeout
		print("RESULT hbclient globe %s day +%.4f speed %.4f" % [get_tree().current_scene == self, float(Campaign.data["day"]) - d0, Net.geo_speed])
		return
	if Game.autotest() == "geolivehost":
		await get_tree().create_timer(14.0).timeout
		get_tree().quit()
		return
	if Game.autotest() == "geoliveclient":
		while Campaign.crafts().is_empty():
			await get_tree().create_timer(0.2).timeout
		await get_tree().create_timer(2.0).timeout
		var d0 := float(Campaign.data["day"])
		var c0: Dictionary = Campaign.crafts()[0].duplicate()
		var mk0: Vector3 = markers[900000 + int(c0["id"])].position if markers.has(900000 + int(c0["id"])) else Vector3.ZERO
		await get_tree().create_timer(5.0).timeout
		var c1: Dictionary = Campaign.crafts()[0] if not Campaign.crafts().is_empty() else c0
		var mk1: Vector3 = markers[900000 + int(c0["id"])].position if markers.has(900000 + int(c0["id"])) else Vector3.ZERO
		var moved := Vector2(float(c1["lat"]) - float(c0["lat"]), float(c1["lon"]) - float(c0["lon"])).length()
		print("RESULT geolive day +%.4f craft moved %.3f deg marker moved %.4f speed %.4f" % [float(Campaign.data["day"]) - d0, moved, mk0.distance_to(mk1), Net.geo_speed])
		get_tree().quit()
		return
	if Game.autotest() == "econhost":
		await get_tree().create_timer(30.0).timeout
		print("[ECON-HOST] credits=%d rifles=%d wallets=%s" % [int(Campaign.data["credits"]), int(Campaign.data["armory"].get("rifle", 0)), Net.wallets])
		get_tree().quit()
		return
	if Game.autotest() == "econclient":
		await get_tree().create_timer(3.0).timeout
		await _ui_check("econ_geo")
		_show_armory()
		await _ui_check("econ_armory")
		_show_research()
		await _ui_check("econ_research")
		get_tree().quit()
		return
	if Game.autotest() == "striketest":
		# 0.57: the Bitevní loď comes for the base: no core = the base is gone; the core = it never finds us
		var res := []
		for core in [false, true]:
			Campaign.data["lost"] = false
			Campaign.data["month"] = 4
			Campaign.data["next_strike"] = float(Campaign.data["day"])
			Campaign.data["flights"] = []
			Campaign.data["missions"] = []
			Campaign.data["next_raid"] = 9999.0
			Campaign.data["next_mission"] = 9999.0
			for i in Campaign.data["base"].size():
				if String(Campaign.data["base"][i]["type"]) == "maskovani":
					Campaign.data["base"][i] = {"type": "", "days": 0.0}
			if core:
				Campaign.data["base"][3] = {"type": "maskovani", "days": 0.0}
			var seen := false
			for k in 40:
				Campaign.data["next_mission"] = 9999.0
				Campaign.advance(0.05)
				for f in Campaign.data["flights"]:
					if f.get("strike", false):
						seen = true
				if Campaign.data["lost"]:
					break
			res.append("core %s strike %s lost %s" % [core, seen, Campaign.data["lost"]])
		# Výslech zajatce: a captured Šedivák gives the base away only now and then (15 %)
		var told := 0
		for gi in 400:
			Campaign.data["missions"] = []
			Campaign._grey_talks()
			if Campaign.data["missions"].any(func(mm): return mm["type"] == "alienbase"):
				told += 1
		res.append("grey %s" % ("ok" if told > 35 and told < 85 else "BAD %d" % told))
		print("RESULT striketest " + " | ".join(res))
		get_tree().quit()
		return
	if Game.autotest() == "encyshot":
		# pictures of one encyclopedia entry, scrolled page by page (--ency=autopsy_ohnivec)
		Campaign.data["seen_races"] = Campaign.RACE_INFO.keys()
		for rid in Campaign.RESEARCH:
			if not rid in Campaign.data["research"]["done"]:
				Campaign.data["research"]["done"].append(rid)
		for u in Campaign.UFO_NAMES:
			if not Campaign.data.has("found"): Campaign.data["found"] = {}
			Campaign.data["found"]["vrak_" + u] = 1
		await get_tree().create_timer(0.5).timeout
		var id := Game.cmd_arg("ency", "autopsy_ohnivec")
		var en := Encyclopedia.open(self, id)
		await get_tree().create_timer(1.5).timeout
		var sc := en.text_lbl.get_parent() as ScrollContainer
		for page in int(Game.cmd_arg("pages", "3")):
			sc.scroll_vertical = int(page * sc.size.y * 0.9)
			await get_tree().create_timer(0.4).timeout
			get_viewport().get_texture().get_image().save_png("user://ency_%s_%d.png" % [id, page])
		print("RESULT encyshot ", id)
		get_tree().quit()
		return
	if Game.autotest() == "basepick":
		# 0.69: the host picks the first base (blocs of 1990); snapshots basepick_N.png
		var want := {"Vysočina": "east", "Bavorsko": "west", "Sasko": "east", "Polsko": "east", "Slovensko": "east", "Rakousko": "west",
			"Maďarsko": "east", "Normandie": "west", "Skotsko": "west", "Finsko": "west", "Pobaltí": "ussr", "Ukrajina": "ussr",
			"Rumunsko": "east", "Balkán": "east", "Itálie": "west", "Španělsko": "west", "Maroko": "africa", "Egypt": "me", "Sahara": "africa",
			"Kongo": "africa", "Keňa": "africa", "Jižní Afrika": "africa", "Turecko": "me", "Írán": "me", "Ural": "ussr", "Sibiř": "ussr",
			"Kazachstán": "ussr", "Mongolsko": "asia", "Čína": "asia", "Japonsko": "pacific", "Indie": "asia", "Indočína": "asia",
			"Indonésie": "asia", "Austrálie": "pacific", "Nový Zéland": "pacific", "Aljaška": "na", "Kanada": "na", "Texas": "na",
			"Mexiko": "latam", "Amazonie": "latam", "Patagonie": "latam", "Grónsko": "na", "Skandinávie": "west"}
		var bad := []
		for pl in Campaign.PLACES:
			if want.has(pl[0]) and Campaign.bloc_at(float(pl[1]), float(pl[2])) != want[pl[0]]:
				bad.append("%s=%s" % [pl[0], Campaign.bloc_at(float(pl[1]), float(pl[2]))])
		var t0 := Time.get_ticks_msec()
		_region_tex = null
		region_texture(true)
		_region_tex.get_image().save_png("user://blocs_1990.png")
		print("[PICK] region map %d ms, wrong places: %s" % [Time.get_ticks_msec() - t0, bad])
		var picking := pick_panel != null
		var c0 := int(Campaign.data["credits"])
		var d0 := float(Campaign.data["day"])
		speed = 3
		await get_tree().create_timer(1.0).timeout
		var frozen := float(Campaign.data["day"]) == d0
		_pick_hover = Vector2(50.0, 15.0)
		await get_tree().create_timer(0.5).timeout
		if DisplayServer.get_name() != "headless":
			get_viewport().get_texture().get_image().save_png("user://basepick_0.png")
		# every bloc's text in the panel (the panel clips, so the audit looks with the clip off)
		var pbad := 0
		for bid in Campaign.BLOC_ORDER:
			var pl := Vector2(BLOC_VIEW[bid][0], BLOC_VIEW[bid][1])
			_pick_info_for(bid, pl)
			await get_tree().process_frame
			await get_tree().process_frame
			pick_panel.clip_contents = false
			var bx: Control = pick_panel.get_child(0)
			var need := bx.get_combined_minimum_size().y
			if need > pick_panel.size.y - 8.0:
				print("[UI] pick_%s: panel volby základny přetéká o %.0f px" % [bid, need - pick_panel.size.y + 8.0])
				pbad += 1
			var sc: ScrollContainer = _pick_info.get_parent()
			if _pick_info.get_combined_minimum_size().y > sc.size.y + 1.0:
				print("[UI] pick_%s: text bloku se nevejde (%.0f > %.0f px), posouvá se" % [bid, _pick_info.get_combined_minimum_size().y, sc.size.y])
			pbad += Game.ui_audit(pick_panel, "pick_" + bid)
			pick_panel.clip_contents = true
		print("[PICK] panel bad %d" % pbad)
		_pick_hover = Vector2(50.0, 15.0)
		_focus_bloc("na")
		_pick_hover = Vector2.INF
		_pick_at_ll = Vector2(31.0, -99.0)
		await get_tree().create_timer(0.6).timeout
		if DisplayServer.get_name() != "headless":
			get_viewport().get_texture().get_image().save_png("user://basepick_1.png")
		_pick_confirm()
		_close_popup()
		await get_tree().create_timer(0.3).timeout
		var near := 0
		for i in 40:
			var m := Campaign.generate_mission()
			if Campaign.arc_deg(Campaign.base_lat(), Campaign.base_lon(), float(m["lat"]), float(m["lon"])) < 35.0:
				near += 1
		speed = 3
		await get_tree().create_timer(1.0).timeout
		_close_popup()
		if DisplayServer.get_name() != "headless":
			get_viewport().get_texture().get_image().save_png("user://basepick_2.png")
		print("RESULT basepick picking %s frozen %s bloc %s place %s credits %d->%d near %d/40 running %s" % [picking, frozen, Campaign.base_bloc(),
			Campaign.base_place(), c0, int(Campaign.data["credits"]), near, float(Campaign.data["day"]) > d0])
		get_tree().quit()
		return
	if Game.autotest() == "geomodels":
		# 0.69: the 3D ships over the globe (snapshots geo_models_N.png)
		Campaign.data["missions"] = []
		Campaign.data["flights"] = []
		Campaign.data["next_mission"] = 9999.0
		Campaign.data["next_raid"] = 9999.0
		var kinds := ["scout", "raider", "harvester", "supply", "battleship"]
		for i in kinds.size():
			var f := Campaign.generate_flight()
			f["kind"] = kinds[i]
			f["lat"] = Campaign.BASE_LAT + 12.0 - i * 6.0
			f["lon"] = Campaign.BASE_LON + 4.0 + (i % 2) * 14.0
			f["heading"] = 40.0 * i
			f["until"] = float(Campaign.data["day"]) + 5.0
			Campaign.data["flights"].append(f)
		var fl: Array = Campaign.data["flights"]
		for ck in ["jet", "heli", "kondor"]:
			var c := Campaign.launch_craft(ck, fl[["jet", "heli", "kondor"].find(ck)], "flight")
			c.erase("ambush_at")
		_close_popup()
		speed = 1
		await get_tree().create_timer(6.0).timeout
		speed = 0
		_close_popup()
		yaw = -deg_to_rad(Campaign.BASE_LON + 8.0)
		tilt = deg_to_rad(Campaign.BASE_LAT)
		var shots := [[3.2, -1], [2.3, -1], [1.6, int(fl[2]["id"])]]
		for i in shots.size():
			zoom = shots[i][0]
			selected = shots[i][1]
			await get_tree().create_timer(0.8).timeout
			if DisplayServer.get_name() != "headless":
				get_viewport().get_texture().get_image().save_png("user://geo_models_%d.png" % i)
		var n3d := 0
		for id in markers:
			if markers[id].has_meta("craft"):
				n3d += 1
		print("RESULT geomodels ships %d crafts %d models %d" % [fl.size(), Campaign.crafts().size(), n3d])
		get_tree().quit()
		return
	if Game.autotest() == "uigeo":
		for i in 6:
			Campaign.data["missions"].append(Campaign.generate_mission())
		Campaign.data["flights"].append(Campaign.generate_flight())
		Campaign.data["seen_races"] = Campaign.RACE_INFO.keys()
		# 0.57: the defences built, so the plan and the build list show them
		for ci in [[4, "silo"], [10, "laser_vez"], [15, "plazma_vez"], [16, "maskovani"]]:
			if ci[0] < Campaign.data["base"].size() and String(Campaign.data["base"][ci[0]]["type"]) == "":
				Campaign.data["base"][ci[0]] = {"type": ci[1], "days": 0.0}
		for rid in ["jestrab", "vzduch_laser", "vzduch_laser_delo", "pvo_silo", "pvo_laser", "pvo_plazma", "maskovani"]:      # the hangar's new buttons in the base screen
			if not rid in Campaign.data["research"]["done"]:
				Campaign.data["research"]["done"].append(rid)
		Campaign.data["built"] = ["vzduch_laser"]      # (one fitted, one still only a design: the workshop list shows it)
		for i in 30:
			Campaign._log("Zkušební záznam do hlášení číslo %d s trochu delším textem, aby bylo vidět zalamování." % i)
		await get_tree().create_timer(0.5).timeout
		_close_popup()
		selected = int(Campaign.data["missions"][0]["id"])
		await _ui_check("geo_mission")
		selected = int(Campaign.data["flights"][0]["id"])
		_focus(Campaign.data["flights"][0])
		await get_tree().create_timer(0.6).timeout
		await _ui_check("geo_flight")
		for e in [["geo_research", _show_research], ["geo_base", _show_base], ["geo_armory", _show_armory], ["geo_workshop", func():
					for rid in ["laser", "laser_puska", "rozbor_plazma", "slitiny", "vesta", "tezke", "zenijni"]:
						if not rid in Campaign.data["research"]["done"]: Campaign.data["research"]["done"].append(rid)
					var fd: Dictionary = Campaign.data.get("found", {})
					fd["slitiny"] = int(fd.get("slitiny", 0)) + 14
					Campaign.data["found"] = fd
					Campaign.data["credits"] = int(Campaign.data["credits"]) + 4000
					Campaign.make("pancir"); Campaign.make("laser_rifle"); Campaign.make("mine")
					_show_workshop()],
				["geo_archive", _show_archive], ["geo_log", _show_log], ["geo_build", func(): _build_menu(2)], ["geo_hangar", func(): _show_base(1)], ["geo_jets", _show_hangar],
				["geo_menu", _game_menu], ["geo_menu_viewer", func(): Campaign.viewer = true; _game_menu(); Campaign.viewer = false],
				["geo_alert", func(): _alert("VELMI DLOUHÉ HLÁŠENÍ\n" + "Tohle je velmi dlouhý text upozornění, který by se měl zalomit. ".repeat(8))]]:
			e[1].call()
			if String(e[0]) in ["geo_base", "geo_build", "geo_hangar"]:
				await get_tree().create_timer(2.5).timeout      # (the plan is built and photographed first)
			await _ui_check(e[0])
			_close_popup()
			for c in get_children():
				if c is ResearchScreen or c is Encyclopedia or c is BaseScreen:
					c.queue_free()
			await get_tree().process_frame
		# (0.69) a busy sky: every craft in the air and research going - the status lines grow,
		# the side panel must still fit (its buttons at the bottom)
		var fl0 := Campaign.generate_flight()
		fl0["until"] = float(Campaign.data["day"]) + 5.0
		Campaign.data["flights"].append(fl0)
		for ck in ["jet", "jet", "heli", "kondor"]:
			var cc := Campaign.launch_craft(ck, fl0, "flight")
			cc.erase("ambush_at")
		Campaign.data["research"]["current"] = "vzduch_laser_delo"
		selected = int(fl0["id"])
		await get_tree().create_timer(0.4).timeout
		_close_popup()
		await _ui_check("geo_busy")
		# the tree half done, the encyclopedia on an autopsy and a weapon
		Campaign.data["research"]["done"] = ["pitva", "medicina", "pitva_levit", "zenijni", "tezke", "rozbor_plazma", "vesta", "slitiny", "vyslech"]
		Campaign.data["research"]["current"] = "laser"
		Campaign.data["research"]["progress"] = 2.0
		Campaign.data["found"] = {"corpse_grey": 3, "corpse_levit": 1, "a_pistol": 2, "slitiny": 10}
		for e2 in [["geo_tree", func(): _show_research()], ["geo_ency_autopsy", func(): _show_archive("autopsy_levit")],
				["geo_ency_race", func(): _show_archive("race_bijec_velitel")], ["geo_ency_item", func(): _show_archive("item_a_pistol")], ["geo_ency_weapon", func(): _show_archive("item_autocannon")],
				["geo_ency_craft", func(): _show_archive("ufo_scout")], ["geo_ency_grey", func(): _show_archive("autopsy_grey")]]:
			e2[1].call()
			await get_tree().create_timer(0.6).timeout
			await _ui_check(e2[0])
			for c in get_children():
				if c is ResearchScreen or c is Encyclopedia:
					c.queue_free()
			await get_tree().process_frame
		get_tree().quit()
		return
	if Game.autotest() == "campair":
		if Game.test_phase == 0:
			Game.test_phase = 1
			var f := Campaign.generate_flight()
			f["kind"] = "raider"
			Campaign.data["flights"].append(f)
			selected = int(f["id"])
			await get_tree().create_timer(1.0).timeout
			get_viewport().get_texture().get_image().save_png("user://26_flight.png")
			_launch()
			_go_jets(f)
			speed = 2
			var c0: Dictionary = Campaign.crafts()[-1]
			while c0.get("state", "") == "out":
				if popup:
					_close_popup()
				speed = 2
				await get_tree().process_frame
			print("[CAMPAIR] craft state=%s at %.1f,%.1f day=%.3f" % [c0["state"], float(c0["lat"]), float(c0["lon"]), float(Campaign.data["day"])])
			if c0["state"] == "arrived":
				_close_popup()
				_start_air(c0, Campaign._target_of(c0))
			else:
				get_tree().quit()
		else:
			await get_tree().create_timer(1.0).timeout
			get_viewport().get_texture().get_image().save_png("user://27_after_air.png")
			print("[CAMPAIR] back. missions=%d flights=%d log: %s" % [Campaign.data["missions"].size(), Campaign.data["flights"].size(), Campaign.data["log"][-1]])
			get_tree().quit()
		return
	if Game.autotest() == "campaign":
		if Game.test_phase == 0:
			Game.test_phase = 1
			speed = 3
			await get_tree().create_timer(3.0).timeout
			_close_popup()
			if Campaign.data["missions"].is_empty():
				Campaign.data["missions"].append(Campaign.generate_mission())
			if not Campaign.data["missions"].is_empty():
				selected = int(Campaign.data["missions"][0]["id"])
				var m0: Dictionary = Campaign.data["missions"][0]
				m0["expires"] = float(Campaign.data["day"]) + 3.0
				print("[CAMP] launching ", m0["type"], " ", m0["biome"], " transport=", Campaign.transport(), " eta=%.1f h" % Campaign.eta_hours(Campaign.transport(), float(m0["lat"]), float(m0["lon"])))
				_launch()
				_go_transport(m0, Campaign.transport())
				speed = 2
				var c1: Dictionary = Campaign.crafts()[-1]
				if Game.cmd_arg("ambush", "") != "":
					c1["ambush_at"] = 0.2
					c1["dist0"] = Campaign.arc_deg(Campaign.BASE_LAT, Campaign.BASE_LON, float(m0["lat"]), float(m0["lon"]))
				while c1.get("state", "") == "out":
					if popup and c1.get("state", "") == "out":
						_close_popup()
					speed = 2
					await get_tree().process_frame
				print("[CAMP] craft state=%s day=%.3f" % [c1["state"], float(Campaign.data["day"])])
				if c1["state"] == "ambush":
					get_viewport().get_texture().get_image().save_png("user://24_ambush.png")
					print("[CAMP] ambush popup ok")
					get_tree().quit()
					return
				_close_popup()
				_begin_landed(c1, m0)
		else:
			await get_tree().create_timer(1.0).timeout
			if DisplayServer.get_name() != "headless":
				get_viewport().get_texture().get_image().save_png("user://25_return.png")
			print("[CAMP] back on globe. credits=%d trust=%d missions=%d log: %s" % [Campaign.data["credits"], Campaign.data["trust"], Campaign.data["stats"]["missions"], Campaign.data["log"][-1]])
			get_tree().quit()
		return
	if Game.autotest() != "geo":
		return
	speed = 3
	await get_tree().create_timer(4.0).timeout
	if Campaign.data["missions"].is_empty():
		Campaign.data["missions"].append(Campaign.generate_mission())
		Campaign.data["missions"].append(Campaign.generate_mission())
		Campaign.data["flights"].append(Campaign.generate_flight())
	get_viewport().get_texture().get_image().save_png("user://20_geoscape.png")
	if not Campaign.data["missions"].is_empty():
		selected = int(Campaign.data["missions"][0]["id"])
		_focus(Campaign.data["missions"][0])
	_close_popup()
	speed = 0
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png("user://21_mission.png")
	# click test: rotate a bit, then click where the marker is drawn
	if not Campaign.data["missions"].is_empty():
		var m0: Dictionary = Campaign.data["missions"][0]
		yaw += 0.4
		await get_tree().process_frame
		await get_tree().process_frame
		selected = -1
		var wp := globe.global_transform * latlon_to_local(float(m0["lat"]), float(m0["lon"]), 1.012)
		var vpos := cam.unproject_position(wp) / Vector2(vp.size) * view.size   # view-local (layout units)
		var win := get_viewport().get_final_transform() * (view.get_global_transform() * vpos)
		Input.warp_mouse(win)
		var mv := InputEventMouseMotion.new()
		mv.position = win
		Input.parse_input_event(mv)
		await get_tree().process_frame
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		ev.position = win
		Input.parse_input_event(ev)
		await get_tree().process_frame
		var up := ev.duplicate()
		up.pressed = false
		Input.parse_input_event(up)
		await get_tree().process_frame
		print("[GEO] click test: marker at %s -> selected=%d (want %d) hover=%d" % [vpos, selected, int(m0["id"]), hover])
		await get_tree().create_timer(0.3).timeout
		get_viewport().get_texture().get_image().save_png("user://21b_click.png")
	_show_research()
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png("user://22_research.png")
	_show_base()
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png("user://23_base.png")
	_show_armory()
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png("user://24_armory.png")
	_close_popup()
	print("[GEO] missions=%d credits=%d day=%.2f" % [Campaign.data["missions"].size(), Campaign.data["credits"], Campaign.data["day"]])
	if Game.cmd_arg("launch", "") == "1" and not Campaign.data["missions"].is_empty():
		selected = int(Campaign.data["missions"][0]["id"])
		_launch()
		return
	get_tree().quit()
