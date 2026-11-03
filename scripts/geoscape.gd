extends Control
## The command screen: a turning globe with day and night, the missions the
## radar found, time controls and the base menus (research, armory, building).

const BG := Color(0.02, 0.03, 0.07)
const PANEL := Color(0.05, 0.08, 0.17, 0.95)
const FRAME := Color(0.45, 0.65, 0.95)
const TEXT := Color(0.80, 0.90, 1.0)
const ACCENT := Color(0.95, 0.75, 0.30)
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
	Game.play_music("game_over" if Campaign.data.get("lost", false) else "geoscape")
	_toast = Label.new()
	_toast.position = Vector2(8, 334)
	_toast.size = Vector2(415, 16)
	_toast.add_theme_font_size_override("font_size", 9)
	_toast.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	add_child(_toast)
	Net.note.connect(_on_note)
	Campaign.mission_found.connect(func(m): _alert("RADAR: %s\n%s\n%s" % [Campaign.MTYPES[m["type"]]["name"], m["place"], Campaign.MTYPES[m["type"]]["text"]]); selected = int(m["id"]); _focus(m))
	Campaign.flight_found.connect(func(f): _alert("RADAR: UFO V LETU\n%s nad oblastí %s.\nVyber ho na glóbu a vyšli stíhačku Sokol, než zmizí." % [Campaign.UFO_NAMES[f["kind"]], Campaign.nearest_place(float(f["lat"]), float(f["lon"]))]); selected = int(f["id"]); _focus(f))
	Campaign.research_done.connect(func(id): _alert("VÝZKUM DOKONČEN\n%s\n%s" % [Campaign.RESEARCH[id]["name"], Campaign.RESEARCH[id]["desc"]]))
	Campaign.report.connect(func(txt): _alert(txt))
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
		_alert("NÁVRAT Z MISE\n" + Net.last_result)
		Net.last_result = ""
	if Campaign.won() and not Campaign.data.get("won_shown", false):
		Campaign.data["won_shown"] = true
		Campaign.save()
		Game.play_music("victory", false)
		_alert("VÍTĚZSTVÍ\nVelký mozek je mrtvý a velín na Marsu utichl. UFO padají z nebe jako mrtví ptáci, Šeďáci v lesích jen stojí a dívají se do tmy.\nŽoldáci přežili noc, která neměla konec.\n\nENEMY BEYOND\nPocta UFO: Enemy Unknown - fanouškovská hra, ne na prodej.\nNápad a hra: Ivo Arielistelos Florek.\nKampaň můžeš hrát dál.")
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
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	cam = Camera3D.new()
	cam.fov = 40
	vp.add_child(cam)
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
	_place(base_marker, Campaign.BASE_LAT, Campaign.BASE_LON)

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

static func latlon_to_local(lat: float, lon: float, r := 1.0) -> Vector3:
	var la := deg_to_rad(lat)
	var lo := deg_to_rad(lon)
	return Vector3(cos(la) * sin(lo), sin(la), cos(la) * cos(lo)) * r

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
	gmat.set_shader_parameter("sun_dir", latlon_to_local(-18.0, sun_lon))
	# time
	if popup == null and not Campaign.viewer and not Campaign.data.get("lost", false):
		if Campaign.advance(SPEEDS[speed] * delta):
			speed = 0
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
		tag_lbl.position = sp + Vector2(8, -6)
		tag_lbl.visible = true
		if int(m["id"]) == selected:
			break

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
			markers[id] = _marker(Color(0.4, 1.0, 0.5), 0.05)
		_place(markers[id], float(f["lat"]), float(f["lon"]))
		markers[id].visible = fmod(t * 3.0, 1.0) < 0.7 or id == selected
		markers[id].scale = Vector3.ONE * (1.6 if id == selected else (1.3 if id == hover else 1.0))
	for c in Campaign.crafts():
		var cid := 900000 + int(c["id"])
		ids[cid] = true
		if not markers.has(cid):
			markers[cid] = _marker(Color(0.55, 0.85, 1.0) if c["kind"] == "jet" else Color(1, 1, 1), 0.03 if c["kind"] == "jet" else 0.04)
		_place(markers[cid], float(c["lat"]), float(c["lon"]))
		markers[cid].visible = true
	for id in markers.keys():
		if not ids.has(id):
			markers[id].queue_free()
			markers.erase(id)
			if selected == id:
				selected = -1

func _gui_input(event: InputEvent) -> void:
	pass

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
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed and inside:
			var id := _pick_at(lp)
			if id != -1 or not Input.is_key_pressed(KEY_SHIFT):
				selected = id
	elif event is InputEventMouseMotion:
		if dragging:
			yaw += event.relative.x * 0.008 * zoom / 3.2
			tilt = clamp(tilt + event.relative.y * 0.008 * zoom / 3.2, -1.4, 1.4)
		hover = _pick_at(lp) if inside else -1

## Which marker is under this point of the globe view (view-local coordinates)? -1 = none.
## Tests the marker positions projected to the screen, so it works at any resolution and zoom.
func _pick_at(lp: Vector2) -> int:
	var pos := lp / view.size * Vector2(vp.size)
	var px_scale := float(vp.size.y) / 360.0
	var best := -1
	var bd := 14.0 * px_scale
	for m in Campaign.data["missions"] + Campaign.data.get("flights", []):
		var id := int(m["id"])
		var wp := globe.global_transform * latlon_to_local(float(m["lat"]), float(m["lon"]), 1.012)
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
func _style(c: Control, bgc := PANEL) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bgc
	sb.border_color = FRAME
	sb.set_border_width_all(1)
	sb.set_content_margin_all(5)
	c.add_theme_stylebox_override("panel", sb)

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
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.10, 0.18, 0.38)
	n.border_color = FRAME
	n.set_border_width_all(1)
	n.set_content_margin_all(2)
	var h := n.duplicate()
	h.bg_color = Color(0.18, 0.30, 0.55)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_stylebox_override("focus", n)
	b.add_theme_color_override("font_color", TEXT)
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
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl = _lbl(side, "", TEXT, 8)
	var row := HBoxContainer.new()
	side.add_child(row)
	for i in (0 if Campaign.viewer else SPEEDS.size()):
		var k := i
		_btn(row, SPEED_NAMES[i], func(): speed = k, 8).custom_minimum_size = Vector2(44, 14)
	info_lbl = _lbl(side, "", TEXT, 8)
	info_lbl.custom_minimum_size = Vector2(196, 112)
	var entries := [["Základna", _show_base], ["Výzkum", _show_research], ["Zbrojnice", _show_armory],
			["Výstroj", func(): _menu_screen("loadout")], ["Žoldák", func(): _menu_screen("merc")],
			["Úpravy zbraní", func(): _menu_screen("mods")],
			["Hlášení", _show_log], ["Archiv vetřelců", _show_archive]]
	if Campaign.viewer:
		# a co-op client: the host's globe, read-only; buying with own money
		_lbl(side, "Díváš se na základnu hostitele. Misi spouští on.", FRAME, 8)
		entries += [["Peníze v týmu", func(): _menu_screen("money")], ["Zpět do lobby", func(): get_tree().change_scene_to_file("res://scenes/Main.tscn")]]
	else:
		_btn(side, "VYSLAT (tým / stíhačku)", _launch, 10)
		entries += [["Co-op / peníze týmu", func():
			if Net.is_online(): _menu_screen("money")
			else: _host()], ["Uložit a menu", _quit]]
	var grid := GridContainer.new()
	grid.columns = 2
	side.add_child(grid)
	for e in entries:
		_btn(grid, e[0], e[1], 8).custom_minimum_size = Vector2(98, 15)

func _update_text() -> void:
	var d: Dictionary = Campaign.data
	var r: Dictionary = d["research"]
	var rs := "nic"
	if r["current"] != "":
		var rr: Dictionary = Campaign.RESEARCH[r["current"]]
		rs = "%s %d %%" % [rr["name"], int(float(r["progress"]) / float(rr["days"]) * 100)]
	if not Campaign.kondor_ready():
		rs += "   Kondor za %d h" % Campaign.kondor_hours()
	var co := ""
	if Net.is_online():
		co = "\nCo-op: %d hráčů, tvoje peníze %d kr" % [Net.roster.size(), Net.my_money()] if Campaign.viewer else "\nCo-op: %d hráčů připojeno" % Net.roster.size()
	var air := []
	for c in Campaign.crafts():
		air.append("%s %s" % [("Sokol" if int(c.get("n", 1)) == 1 else "%d× Sokol" % int(c.get("n", 1))) if c["kind"] == "jet" else Campaign.CRAFT_NAMES[c["kind"]].capitalize(), "letí k cíli" if c["state"] == "out" else ("u cíle" if c["state"] in ["arrived", "ambush"] else "se vrací")])
	if not air.is_empty():
		co += "\nVe vzduchu: " + ", ".join(air)
	status_lbl.text = "%s\nRozpočet: %d kr   Mk-115: %d g   Důvěra: %d %%\nVýzkum: %s   Rychlost: %s%s" % [Campaign.date_text(), int(d["credits"]), Campaign.moskovium(), int(d["trust"]), rs, SPEED_NAMES[speed], co]
	var fl := _selected_flight()
	if not fl.is_empty():
		var left2: float = (float(fl["until"]) - float(d["day"])) * 24.0
		info_lbl.text = "UFO V LETU\n%s\nNad oblastí: %s\nZmizí z radaru asi za %d min\n\nSokol: %s\n\nPoškozené UFO spadne (mise s posádkou a kořistí). Rozstřílené na kusy nedá nic. Velká UFO střílí zpět." % [
			Campaign.UFO_NAMES[fl["kind"]], Campaign.nearest_place(float(fl["lat"]), float(fl["lon"])), int(left2 * 60),
			"připraveno %d z %d" % [Campaign.jets_ready(), Campaign.jets()]]
		return
	var m := _selected_mission()
	if m.is_empty():
		var n: int = d["missions"].size() + d.get("flights", []).size()
		info_lbl.text = "Radar hlídá oblohu.\n\n" + ("Na glóbu je %d hlášení - klikni na blikající značku." % n if n > 0 else "Pusť čas a čekej na hlášení.") + "\n\nPravé tlačítko: otáčet glóbem\nKolečko: přiblížit"
		return
	var left: float = (float(m["expires"]) - float(d["day"])) * 24.0
	var night := Campaign.is_night(float(m["lon"]))
	var lh := Campaign.local_hour(float(m["lon"]))
	var biome: String = {"farm": "venkov, farma", "forest": "lesy", "town": "městečko", "industrial": "průmyslový areál", "mountain": "hory, horská chata", "polar": "polární pustina", "base": "naše základna", "mars": "Mars"}.get(String(m["biome"]), "krajina")
	info_lbl.text = "%s\n%s  (%s)\nMístní čas %02d:%02d - %s\nVydrží ještě asi %d h\nOdhad posádky: %s\nOdměna: %d kr\n\n%s" % [
		Campaign.MTYPES[m["type"]]["name"].to_upper(), m["place"], biome, int(lh), int(fmod(lh, 1.0) * 60),
		"NOC" if night else "den", int(left), ["malá", "střední", "velká", "obrovská"][clampi(int(m["extra_aliens"]), 0, 3)],
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
	# the base and Mars: nobody has to fly anywhere first
	if m["type"] in ["base", "mars"]:
		_start_ground(m)
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
		_alert("Žádný Sokol není připraven\nStíhačky jsou v opravě nebo ve vzduchu.")
		return
	var eta := Campaign.eta_hours("jet", float(fl["lat"]), float(fl["lon"]))
	var left: float = (float(fl["until"]) - float(Campaign.data["day"])) * 24.0
	var box := _overlay("VYSLAT STÍHAČKY", 360)
	_lbl(box, "%s nad oblastí %s.\nLet k UFO asi %.1f h, z radaru zmizí asi za %.1f h.%s" % [Campaign.UFO_NAMES[fl["kind"]], Campaign.nearest_place(float(fl["lat"]), float(fl["lon"])), eta, left,
		"\nNEJSPÍŠ NESTIHNOU - UFO uletí dřív." if eta > left else ""], RED if eta > left else TEXT, 9)
	if Net.is_online():
		if _pick.is_empty():
			_pick = {1: true}
		_lbl(box, "Kdo usedne do Sokolů (připraveno %d):" % ready, ACCENT, 9)
		for id in Net.roster:
			var pid: int = id
			var on: bool = _pick.get(pid, false)
			_btn(box, ("[X] " if on else "[  ] ") + str(Net.roster[pid]["name"]), func():
				if _pick.get(pid, false):
					_pick.erase(pid)
				elif _pick.size() < ready:
					_pick[pid] = true
				_launch_jets(fl), 9)
	else:
		_lbl(box, "Letíš sám (Sokolů připraveno: %d)." % ready, ACCENT, 9)
	var row := HBoxContainer.new()
	box.add_child(row)
	_btn(row, "VZLÉTNOUT", func(): _go_jets(fl), 10)
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
	_toast_say("Sokol vzlétl. Pusť čas - na místě začne souboj.")

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
		_lbl(box, "Kdo řídí transport (ostatní letí v doprovodu, pokud je Sokol):", FRAME, 8)
		var drv: int = int(_pick.get("driver", 1))
		var dr := HBoxContainer.new()
		box.add_child(dr)
		_btn(dr, ("> " if drv == 0 else "") + "AI pilot", func(): _pick["driver"] = 0; _launch_transport(m), 8)
		for id in Net.roster:
			var pid: int = id
			_btn(dr, ("> " if drv == pid else "") + str(Net.roster[pid]["name"]), func(): _pick["driver"] = pid; _launch_transport(m), 8)
	var row := HBoxContainer.new()
	box.add_child(row)
	_btn(row, "VZLÉTNOUT", func(): _go_transport(m, tk), 10)
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
		_lbl(box, "%s má UFO na radaru. Zbraně odjištěny." % ("Sokol" if int(c.get("n", 1)) == 1 else "%d Sokoly" % int(c.get("n", 1))), TEXT, 9)
		_btn(box, "DO BOJE", func():
			_close_popup()
			_start_air(c, fl), 10)
		return
	var m := Campaign._target_of(c)
	var box2 := _overlay("PŘISTÁNÍ", 320)
	_lbl(box2, "%s dosedl u cíle: %s.\nRampa se otevře, až budete připraveni." % [Campaign.CRAFT_NAMES[c["kind"]].capitalize(), m.get("place", "?")], TEXT, 9)
	_btn(box2, "ZAČÍT MISI", func(): _begin_landed(c, m), 10)

func _begin_landed(c: Dictionary, m: Dictionary) -> void:
	_close_popup()
	if not _start_ground(m):
		Campaign.recall_craft(c, "Mise nezačala - transport se vrací.")

func _start_air(c: Dictionary, fl: Dictionary) -> void:
	if fl.is_empty():
		Campaign.recall_craft(c, "UFO zmizelo - Sokol se vrací.")
		return
	Campaign.save()
	var ip := Campaign.intercept_params(fl)
	if Net.is_online():
		ip["pilots"] = c.get("pilots", [1])
		Net.start_intercept(ip)
	else:
		Net.mission_params = ip
		get_tree().change_scene_to_file("res://scenes/Intercept.tscn")

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
	_lbl(box, "Cestou k cíli se na %s vrhla malá UFO.\n%s" % [Campaign.CRAFT_NAMES[c["kind"]], ("Doprovod %d Sokolů se otáčí k obraně." % esc) if esc > 0 else "Bez doprovodu: pilot musí uniknout."], RED, 9)
	_btn(box, "BRÁNIT TRANSPORT", func(): _begin_escort(c), 10)

func _begin_escort(c: Dictionary) -> void:
	_close_popup()
	Campaign.save()
	var ep := {"escort": true, "craft": int(c["id"]), "transport": c["kind"], "escort_n": int(c.get("escort", 0)), "pilots": c.get("pilots", []), "driver": int(c.get("driver", 0))}
	if Net.is_online():
		Net.start_escort(ep)
	else:
		Net.mission_params = ep
		get_tree().change_scene_to_file("res://scenes/Escort.tscn")

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
	var box := _overlay(parts[0], 330)
	if parts.size() > 1:
		_lbl(box, parts[1], TEXT, 9)
	_btn(box, "OK", _close_popup, 10)

func _show_log() -> void:
	var box := _overlay("HLÁŠENÍ", 460)
	var log: Array = Campaign.data["log"]
	var st: Dictionary = Campaign.data["stats"]
	_lbl(box, "Mise %d (úspěšných %d), zabito %d, zajato %d" % [st["missions"], st["won"], st["kills"], st["captures"]], ACCENT, 8)
	_lbl(box, "\n".join(log.slice(max(0, log.size() - 14))), TEXT, 8)
	_btn(box, "Zavřít", _close_popup)

func _show_archive() -> void:
	var outer := _overlay("ARCHIV VETŘELCŮ", 470)
	var box := _scroll(outer, 268)
	var seen: Array = Campaign.data.get("seen_races", [])
	if seen.is_empty():
		_lbl(box, "Zatím prázdný. Co tým potká na misích, to se tu objeví.", FRAME, 8)
	for r in Campaign.RACE_INFO:
		if not r in seen:
			continue
		_lbl(box, Campaign.RACE_INFO[r][0].to_upper(), ACCENT, 9)
		var l := _lbl(box, Campaign.RACE_INFO[r][1], TEXT, 8)
		l.custom_minimum_size = Vector2(425, 0)
	_lbl(outer, "Neznámých druhů: %d" % (Campaign.RACE_INFO.size() - seen.size()), FRAME, 8)
	_btn(outer, "Zavřít", _close_popup)

func _show_research() -> void:
	var outer := _overlay("VÝZKUM", 470)
	var r: Dictionary = Campaign.data["research"]
	_lbl(outer, "Kredity: %d. Laboratoře: %d (každá další zrychluje o polovinu). Najednou jde jen jeden projekt." % [int(Campaign.data["credits"]), Campaign.count("laborator")], FRAME, 8)
	var box := _scroll(outer, 270)
	for id in Campaign.RESEARCH:
		var rr: Dictionary = Campaign.RESEARCH[id]
		var key: String = id
		var state := ""
		if Campaign.researched(id):
			state = "HOTOVO"
		elif r["current"] == id:
			state = "probíhá %d %%" % int(float(r["progress"]) / float(rr["days"]) * 100)
		elif not Campaign.research_available(id):
			state = Campaign.needs_text(id)
		var row := HBoxContainer.new()
		box.add_child(row)
		var mk_txt := (", %d g Mk-115" % int(rr["mk"])) if rr.has("mk") else ""
		var l := _lbl(row, "%s - %d kr%s, %d dní\n%s %s" % [rr["name"], rr["cost"], mk_txt, int(rr["days"]), rr["desc"], ("[" + state + "]") if state != "" else ""], TEXT if state == "" else FRAME, 8)
		l.custom_minimum_size = Vector2(380, 0)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if state == "" and not Campaign.viewer:
			_btn(row, "Zahájit", func():
				if Campaign.start_research(key): _show_research()
				else: _alert("Nelze\nNedostatek kreditů, nebo už běží jiný výzkum."), 8)
	_btn(outer, "Zavřít", _close_popup)

func _show_armory() -> void:
	var box := _overlay("ZBROJNICE - NÁKUP", 470)
	var who := ("Platíš ze svých peněz: %d kr." % Net.my_money()) if Campaign.viewer else ("Kredity: %d." % int(Campaign.data["credits"]))
	_lbl(box, "Koupené kusy trvale zvětší výbavu, kterou si každý žoldák může vzít na misi. %s Moskovium 115: %d g" % [who, Campaign.moskovium()], FRAME, 8)
	var grid := GridContainer.new()
	grid.columns = 2
	_scroll(box, 250).add_child(grid)
	var stash := Campaign.stash()
	for id in Campaign.SHOP:
		if not Game.ITEMS.has(id):
			continue
		var key: String = id
		var ok := Campaign.unlocked(id)
		var mk := int(Campaign.SHOP_MK.get(id, 0))
		var cost := ("%d kr" % Campaign.price(id) + (" + %d g Mk" % mk if mk > 0 else "")) if ok else "zamčeno"
		var b := _btn(grid, "%s (%d) %s" % [Game.ITEMS[id]["short"], int(stash.get(id, 0)), cost], func():
			if Campaign.viewer:
				if Net.my_money() < Campaign.price(key) or Campaign.moskovium() < int(Campaign.SHOP_MK.get(key, 0)):
					_alert("Nelze koupit\nNemáš dost peněz (nebo základna nemá Moskovium 115).")
					return
				Net.buy_for_base(key)
				await get_tree().create_timer(0.5).timeout
				_show_armory()
			elif Campaign.buy(key): _show_armory()
			else: _alert("Nelze koupit\nNedostatek kreditů nebo Moskovia 115."), 8)
		b.custom_minimum_size = Vector2(225, 14)
		b.disabled = not ok
	_btn(box, "Zavřít", _close_popup)

func _show_base() -> void:
	var box := _overlay("ZÁKLADNA", 470)
	_lbl(box, "Klikni na volné místo a postav zařízení. Kredity: %d. Stíhačky Sokol: %d (připraveno %d)." % [int(Campaign.data["credits"]), Campaign.jets(), Campaign.jets_ready()], FRAME, 8)
	if not Campaign.viewer and Campaign.jets() < Campaign.MAX_JETS:
		_btn(box, "Koupit další stíhačku Sokol - %d kr (v co-op poletí víc hráčů)" % Campaign.JET_PRICE, func():
			if Campaign.buy_jet(): _show_base()
			else: _alert("Nelze koupit\nNedostatek kreditů."), 8)
	var grid := GridContainer.new()
	grid.columns = Campaign.GRID_W
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	box.add_child(grid)
	var colors := {"velin": Color(0.2, 0.35, 0.6), "hangar": Color(0.3, 0.3, 0.32), "ubikace": Color(0.3, 0.25, 0.18),
		"laborator": Color(0.15, 0.4, 0.35), "dilna": Color(0.4, 0.3, 0.15), "osetrovna": Color(0.45, 0.15, 0.15), "radar": Color(0.2, 0.45, 0.2)}
	for i in Campaign.data["base"].size():
		var cell: Dictionary = Campaign.data["base"][i]
		var idx: int = i
		var txt := "volno"
		if cell["type"] != "":
			txt = Campaign.FACILITIES[cell["type"]]["name"]
			if float(cell["days"]) > 0:
				txt += "\nstavba %d d" % ceili(float(cell["days"]))
		var b := _btn(grid, txt, func(): _build_menu(idx), 8)
		b.custom_minimum_size = Vector2(72, 40)
		if cell["type"] != "":
			var sb := StyleBoxFlat.new()
			sb.bg_color = colors.get(cell["type"], Color(0.2, 0.2, 0.2)) * (0.6 if float(cell["days"]) > 0 else 1.0)
			sb.border_color = FRAME
			sb.set_border_width_all(1)
			b.add_theme_stylebox_override("normal", sb)
			b.add_theme_stylebox_override("hover", sb)
	_btn(box, "Zavřít", _close_popup)

func _build_menu(idx: int) -> void:
	var cell: Dictionary = Campaign.data["base"][idx]
	if Campaign.viewer and cell["type"] == "":
		_alert("Stavba\nStavět může jen hostitel (je to jeho základna).")
		return
	if cell["type"] != "":
		_alert("%s\n%s" % [Campaign.FACILITIES[cell["type"]]["name"], Campaign.FACILITIES[cell["type"]]["desc"]])
		return
	var box := _overlay("STAVBA", 380)
	for f in ["laborator", "dilna", "osetrovna", "radar"]:
		var key: String = f
		var fi: Dictionary = Campaign.FACILITIES[f]
		_btn(box, "%s - %d kr, %d dní: %s" % [fi["name"], fi["cost"], int(fi["days"]), fi["desc"]], func():
			if Campaign.build(idx, key): _show_base()
			else: _alert("Nelze stavět\nNedostatek kreditů."), 8)
	_btn(box, "Zpět", _show_base)

# ---- tests -----------------------------------------------------------------------------------------
func _ui_check(tag: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	Game.ui_audit(self, tag)
	if DisplayServer.get_name() != "headless":
		get_viewport().get_texture().get_image().save_png("user://ui_%s.png" % tag)

func _autotest() -> void:
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
	if Game.autotest() == "uigeo":
		for i in 6:
			Campaign.data["missions"].append(Campaign.generate_mission())
		Campaign.data["flights"].append(Campaign.generate_flight())
		Campaign.data["seen_races"] = Campaign.RACE_INFO.keys()
		for i in 30:
			Campaign._log("Zkušební záznam do hlášení číslo %d s trochu delším textem, aby bylo vidět zalamování." % i)
		await get_tree().create_timer(0.5).timeout
		_close_popup()
		selected = int(Campaign.data["missions"][0]["id"])
		await _ui_check("geo_mission")
		selected = int(Campaign.data["flights"][0]["id"])
		await _ui_check("geo_flight")
		for e in [["geo_research", _show_research], ["geo_base", _show_base], ["geo_armory", _show_armory],
				["geo_archive", _show_archive], ["geo_log", _show_log], ["geo_build", func(): _build_menu(5)],
				["geo_alert", func(): _alert("VELMI DLOUHÉ HLÁŠENÍ\n" + "Tohle je velmi dlouhý text upozornění, který by se měl zalomit. ".repeat(8))]]:
			e[1].call()
			await _ui_check(e[0])
			_close_popup()
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
