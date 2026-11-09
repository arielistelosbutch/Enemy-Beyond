extends Control
class_name Encyclopedia
## The encyclopedia: what the team has learned. Categories on the left, the entry on the right:
## a title, the text, and the thing itself turning slowly on a steel plate (an autopsy lies
## on the table). Opened from the command screen or from a research project.

const TEXT := Color(0.84, 0.89, 0.92)
const TITLE := Color(0.45, 0.95, 0.75)
const DIM := Color(0.45, 0.5, 0.55)
const ACCENT := Color(1.0, 0.74, 0.32)

var all: Array = []
var cat := ""
var current := -1           # index into all
var list_box: VBoxContainer
var title_lbl: Label
var text_lbl: RichTextLabel
var cat_box: HBoxContainer
var sv: SubViewport
var svc: SubViewportContainer
var holder: Node3D
var cam: Camera3D
var plate: Control
var _spin := 0.0
var _view := "stand"
var on_close: Callable

static func open(parent: Node, entry_id := "") -> Encyclopedia:
	var e := Encyclopedia.new()
	parent.add_child(e)
	e.build()
	e.show_entry(entry_id)
	return e

func build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := TextureRect.new()
	bg.texture = UiSkin.backdrop()
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	all = EncyData.entries()
	var root := HBoxContainer.new()
	root.position = Vector2(6, 6)
	root.size = Vector2(628, 348)
	root.add_theme_constant_override("separation", 6)
	add_child(root)
	# left: categories and the list
	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", UiSkin.panel(6))
	left.custom_minimum_size = Vector2(178, 348)
	root.add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 2)
	left.add_child(lv)
	var t := Label.new()
	t.text = "ENCYKLOPEDIE"
	lv.add_child(t)
	UiSkin.title(t, 12)
	var cats := GridContainer.new()
	cats.columns = 2
	lv.add_child(cats)
	for c in EncyData.CATS:
		var cc: String = c
		var b := _btn(cats, c, func(): _set_cat(cc), 7)
		b.custom_minimum_size = Vector2(80, 14)
		b.set_meta("cat", c)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 246)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lv.add_child(sc)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 1)
	sc.add_child(list_box)
	# right: the entry
	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", UiSkin.panel(8))
	right.custom_minimum_size = Vector2(444, 348)
	root.add_child(right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 4)
	right.add_child(rv)
	var nav := HBoxContainer.new()
	rv.add_child(nav)
	_btn(nav, "OK", close, 9).custom_minimum_size = Vector2(46, 16)
	_btn(nav, "<<", func(): _step(-1), 9).custom_minimum_size = Vector2(46, 16)
	_btn(nav, ">>", func(): _step(1), 9).custom_minimum_size = Vector2(46, 16)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	rv.add_child(body)
	var tv := VBoxContainer.new()
	tv.custom_minimum_size = Vector2(196, 300)
	tv.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	body.add_child(tv)
	title_lbl = Label.new()
	title_lbl.add_theme_color_override("font_color", TITLE)
	title_lbl.add_theme_font_override("font", UiSkin.font(true))
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	tv.add_child(title_lbl)
	# 0.57: rich text - the database records get their headings, fields and the closing quote set apart
	text_lbl = RichTextLabel.new()
	text_lbl.bbcode_enabled = true
	text_lbl.fit_content = true
	text_lbl.scroll_active = false
	text_lbl.add_theme_color_override("default_color", TEXT)
	for fs in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size"]:
		text_lbl.add_theme_font_size_override(fs, 9)
	text_lbl.add_theme_font_override("bold_font", UiSkin.font(true))
	var ital := FontVariation.new()
	ital.base_font = UiSkin.font()
	ital.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.2, 1), Vector2.ZERO)     # slanted Chakra Petch
	text_lbl.add_theme_font_override("italics_font", ital)
	text_lbl.add_theme_constant_override("paragraph_separation", 3)
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	text_lbl.custom_minimum_size = Vector2(186, 0)
	text_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# long database texts scroll (the panel stays the same size)
	var tsc := ScrollContainer.new()
	tsc.custom_minimum_size = Vector2(196, 262)
	tsc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tv.add_child(tsc)
	tsc.add_child(text_lbl)
	# the plate with the model
	plate = Plate.new()
	plate.custom_minimum_size = Vector2(222, 296)
	body.add_child(plate)
	var vhold := Control.new()
	vhold.position = Vector2(10, 10)
	vhold.size = Vector2(202, 276)
	vhold.clip_contents = true
	vhold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(vhold)
	svc = SubViewportContainer.new()
	svc.stretch = true
	svc.size = vhold.size
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vhold.add_child(svc)
	sv = SubViewport.new()
	sv.transparent_bg = true
	sv.own_world_3d = true
	sv.msaa_3d = Viewport.MSAA_4X
	svc.add_child(sv)
	var w := Node3D.new()
	sv.add_child(w)
	cam = Camera3D.new()
	cam.fov = 32.0
	w.add_child(cam)
	for d in [[Vector3(-40, 35, 0), 1.5], [Vector3(-20, 210, 0), 0.6], [Vector3(-80, 0, 0), 0.4]]:
		var l := DirectionalLight3D.new()
		l.rotation_degrees = d[0]
		l.light_energy = d[1]
		w.add_child(l)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.6, 0.7)
	e.ambient_light_energy = 0.8
	env.environment = e
	w.add_child(env)
	holder = Node3D.new()
	w.add_child(holder)

func _btn(parent: Node, s: String, cb: Callable, size := 9) -> Button:
	var b := Button.new()
	b.text = s
	b.add_theme_font_size_override("font_size", size)
	UiSkin.button(b)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func close() -> void:
	if on_close.is_valid():
		on_close.call()
	queue_free()

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()

func show_entry(id: String) -> void:
	var idx := -1
	for i in all.size():
		if all[i]["id"] == id and EncyData.unlocked(all[i]):
			idx = i
	if idx < 0:
		for i in all.size():
			if EncyData.unlocked(all[i]):
				idx = i
				break
	if idx < 0:
		_set_cat(EncyData.CATS[0])
		title_lbl.text = "Zatím prázdná"
		text_lbl.text = "Co tým potká, přinese domů nebo prozkoumá, to se tu objeví."
		return
	_select(idx)

func _set_cat(c: String) -> void:
	cat = c
	for b in get_tree().get_nodes_in_group("_none"):
		pass
	for ch in list_box.get_children():
		ch.queue_free()
	var unknown := 0
	for i in all.size():
		var e: Dictionary = all[i]
		if e["cat"] != c:
			continue
		if not EncyData.unlocked(e):
			unknown += 1
			continue
		var k := i
		var b := Button.new()
		b.text = String(e["title"])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 8)
		b.focus_mode = Control.FOCUS_NONE
		UiSkin.button(b)
		b.custom_minimum_size = Vector2(160, 18)
		var ic := String(e.get("icon", ""))
		if ic != "" and UiSkin.icon(ic):
			b.icon = UiSkin.icon(ic)
			b.expand_icon = true
			b.add_theme_constant_override("icon_max_width", 22)
		if k == current:
			b.add_theme_color_override("font_color", ACCENT)
		b.pressed.connect(func(): _select(k))
		list_box.add_child(b)
	if unknown > 0:
		var l := Label.new()
		l.text = "+ %d neznámých záznamů" % unknown
		l.add_theme_color_override("font_color", DIM)
		l.add_theme_font_size_override("font_size", 8)
		list_box.add_child(l)

func _select(i: int) -> void:
	current = i
	var e: Dictionary = all[i]
	if e["cat"] != cat:
		_set_cat(e["cat"])
	else:
		_set_cat(cat)
	title_lbl.text = String(e["title"])
	text_lbl.text = db_bbcode(hide_unknown(String(e["text"])))
	(text_lbl.get_parent() as ScrollContainer).scroll_vertical = 0
	Game.play_ui(self, "type", -14)
	_show_model(String(e["model"]), String(e["view"]))

func _step(d: int) -> void:
	if current < 0:
		return
	var i := current
	for n in all.size():
		i = wrapi(i + d, 0, all.size())
		if all[i]["cat"] == cat and EncyData.unlocked(all[i]):
			_select(i)
			return

func _show_model(name: String, view: String) -> void:
	for c in holder.get_children():
		c.queue_free()
	_view = view
	_spin = 0.0
	holder.rotation = Vector3.ZERO
	if name == "" or not ResourceLoader.exists("res://assets/models/%s.glb" % name):
		return
	var m: Node3D = Game.model(name)
	var pivot := Node3D.new()
	holder.add_child(pivot)
	pivot.add_child(m)
	var ap: AnimationPlayer = m.find_child("AnimationPlayer", true, false)
	if ap and ap.has_animation("idle") and view == "stand":
		ap.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
		ap.play("idle")
	elif ap:
		ap.stop()
	(plate as Plate).mode = "plate" if view == "table" else "gradient"
	plate.queue_redraw()
	await get_tree().process_frame
	if not is_instance_valid(m):
		return
	if view == "table":
		# opened on the table: the body goes see-through, the insides show
		var sb := _aabb(m)
		for g in m.find_children("*", "GeometryInstance3D", true, false):
			(g as GeometryInstance3D).transparency = 0.55
		for o in _organ_list(name, m, sb):
			var mi := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radial_segments = 10
			sm.rings = 6
			var rad: float = o[1]
			sm.radius = rad
			sm.height = rad * 2.0 * (float(o[3]) if o.size() > 3 else 1.0)
			mi.mesh = sm
			var mat := StandardMaterial3D.new()
			mat.albedo_color = o[2]
			mat.roughness = 0.35
			mat.emission_enabled = true
			mat.emission = (o[2] as Color) * 0.35
			mi.material_override = mat
			m.add_child(mi)
			mi.position = o[0]
		pivot.rotation.x = PI / 2        # lying on its back, face up
		await get_tree().process_frame
	else:
		holder.rotation.y = PI           # face first
	if view == "item":
		# weapons stand upright (muzzle up): a long gun turning on the spot stays in the tall picture
		var ib := _aabb(m)
		if ib.size.z >= ib.size.x and ib.size.z > ib.size.y * 1.3:
			m.rotation.x = PI / 2           # (muzzle up)
		elif ib.size.x > ib.size.y * 1.3:
			m.rotation.z = PI / 2
	# centre and frame it
	var box := _aabb(m)
	m.position -= pivot.basis.inverse() * box.get_center()
	var r := maxf(box.size.length() * 0.5, 0.05)
	# the view is taller than wide: the narrower (horizontal) angle decides, or a long gun
	# turning on its stand pokes out of the picture
	var vhalf := deg_to_rad(cam.fov * 0.5)
	var hhalf := atan(tan(vhalf) * (202.0 / 276.0))
	var dist := r / sin(minf(vhalf, hhalf)) * 1.05
	match view:
		"table":
			cam.position = Vector3(0, dist, 0.001)
			cam.look_at(Vector3.ZERO, Vector3.BACK)
		"craft":
			cam.position = Vector3(0, dist * 0.45, dist * 0.9)
			cam.look_at(Vector3.ZERO, Vector3.UP)
		_:
			cam.position = Vector3(0, dist * 0.12, dist)
			cam.look_at(Vector3.ZERO, Vector3.UP)
	cam.near = maxf(0.01, dist * 0.02)

## What the autopsy shows inside: [position in the body's box (0..1), size, colour, (stretch)].
func _organs(race: String) -> Array:
	var heart := Color(0.75, 0.08, 0.1)
	var lung := Color(0.9, 0.55, 0.6)
	var gut := Color(0.55, 0.3, 0.6)
	var brain := Color(0.95, 0.7, 0.75)
	var blue := Color(0.25, 0.4, 0.85)
	match race:
		"diskoll", "kolos":
			return [[Vector3(0.5, 0.5, 0.5), 0.12, Color(0.3, 1.0, 0.5)], [Vector3(0.3, 0.5, 0.45), 0.06, Color(0.3, 0.8, 1.0)],
				[Vector3(0.7, 0.5, 0.45), 0.06, Color(0.3, 0.8, 1.0)], [Vector3(0.5, 0.5, 0.25), 0.05, Color(1.0, 0.6, 0.2)]]
		"ohnivec":
			return [[Vector3(0.5, 0.5, 0.5), 0.22, Color(1.0, 0.45, 0.05)], [Vector3(0.3, 0.45, 0.4), 0.1, Color(1.0, 0.7, 0.1)], [Vector3(0.7, 0.45, 0.6), 0.1, Color(1.0, 0.7, 0.1)]]
		"nador":
			return [[Vector3(0.4, 0.6, 0.45), 0.12, heart], [Vector3(0.6, 0.55, 0.55), 0.1, heart], [Vector3(0.5, 0.75, 0.4), 0.08, Color(0.9, 0.9, 0.7)],
				[Vector3(0.45, 0.45, 0.6), 0.09, gut]]
		"ohar":
			return [[Vector3(0.5, 0.62, 0.3), 0.09, brain], [Vector3(0.5, 0.55, 0.42), 0.1, lung], [Vector3(0.5, 0.52, 0.5), 0.07, heart],
				[Vector3(0.5, 0.5, 0.65), 0.12, gut, 1.6]]
		"levit":
			return [[Vector3(0.5, 0.86, 0.45), 0.08, brain], [Vector3(0.5, 0.68, 0.45), 0.06, heart], [Vector3(0.5, 0.48, 0.5), 0.14, blue],
				[Vector3(0.43, 0.63, 0.45), 0.07, lung], [Vector3(0.57, 0.63, 0.45), 0.07, lung]]
		"myslodej":
			return [[Vector3(0.5, 0.9, 0.45), 0.18, brain], [Vector3(0.5, 0.65, 0.45), 0.06, heart]]
	# upright ones: brain, lungs, heart, guts
	return [[Vector3(0.5, 0.92, 0.45), 0.13, brain], [Vector3(0.38, 0.7, 0.45), 0.12, lung, 1.4], [Vector3(0.62, 0.7, 0.45), 0.12, lung, 1.4],
		[Vector3(0.55, 0.68, 0.4), 0.08, heart], [Vector3(0.5, 0.55, 0.45), 0.14, gut, 1.2], [Vector3(0.42, 0.6, 0.42), 0.08, Color(0.45, 0.15, 0.12)]]

## Organs in the model's own (standing) space: from the skeleton when it has one, else from its box.
func _organ_list(race: String, m: Node3D, sb: AABB) -> Array:
	var sk: Skeleton3D = m.find_child("Skeleton3D", true, false)
	var out := []
	if sk and sk.find_bone("spine") >= 0 and sk.find_bone("neck") >= 0 and sk.find_bone("head") >= 0:
		var xf := sk.global_transform
		var bp := func(n: String) -> Vector3: return xf * sk.get_bone_global_rest(sk.find_bone(n)).origin
		var hips: Vector3 = bp.call("hips") if sk.find_bone("hips") >= 0 else bp.call("spine")
		var spine: Vector3 = bp.call("spine")
		var neck: Vector3 = bp.call("neck")
		var head: Vector3 = bp.call("head")
		var L := maxf(spine.distance_to(neck), 0.1)
		var side := Vector3(1, 0, 0)
		var front := Vector3(0, 0, -1)
		var chest := spine.lerp(neck, 0.66)
		var big_head := race.begins_with("grey")
		out.append([head + (head - neck).normalized() * L * (0.85 if big_head else 0.3) + front * 0.01, L * (0.5 if big_head else 0.26), Color(0.95, 0.7, 0.75)])
		out.append([chest + side * L * 0.28, L * 0.2, Color(0.9, 0.55, 0.6), 1.3])
		out.append([chest - side * L * 0.28, L * 0.2, Color(0.9, 0.55, 0.6), 1.3])
		out.append([chest + side * L * 0.06 + front * L * 0.08 - (neck - spine).normalized() * L * 0.08, L * 0.12, Color(0.75, 0.08, 0.1)])
		out.append([spine.lerp(neck, 0.3) - side * L * 0.18 + front * L * 0.05, L * 0.13, Color(0.45, 0.15, 0.12)])
		out.append([hips.lerp(spine, 0.5).lerp(chest, 0.25) + front * L * 0.05, L * 0.24, Color(0.55, 0.3, 0.6), 1.2])
		if race == "lihnoun" or race == "jestetan":
			for k in 3:
				out.append([hips.lerp(spine, 0.4) + side * L * (k - 1) * 0.16 + front * L * 0.12, L * 0.08, Color(0.45, 0.85, 0.35)])   # eggs / seed
		return out
	for o in _organs(race):
		var fp: Vector3 = o[0]
		var p := sb.position + Vector3(sb.size.x * fp.x, sb.size.y * fp.y, sb.size.z * fp.z)
		var o2 := [p, float(o[1]) * maxf(sb.size.x, sb.size.z) * 0.55, o[2]]
		if o.size() > 3:
			o2.append(o[3])
		out.append(o2)
	return out

func _aabb(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for c in n.find_children("*", "GeometryInstance3D", true, false):
		var vi: GeometryInstance3D = c
		var b := vi.global_transform * vi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

func _process(delta: float) -> void:
	Game.sharp_view(svc)
	if holder == null:
		return
	if _view == "table":
		holder.rotation.y = sin(Time.get_ticks_msec() * 0.0004) * 0.08
	else:
		holder.rotation.y += delta * 0.5

## The steel plate behind the model (rows of rivets, like a dissection board).
class Plate extends Control:
	var mode := "plate"
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if mode == "gradient":
			# a living one: dark violet light behind it, like a portrait
			var steps := 24
			for i in steps:
				var k := float(i) / steps
				draw_rect(Rect2(0, r.size.y * k, r.size.x, r.size.y / steps + 1), Color(0.1, 0.06, 0.2).lerp(Color(0.55, 0.52, 0.66), k * k))
			draw_rect(r, Color(0.5, 0.55, 0.65), false, 1.0)
			return
		var ch := 14.0
		var pts := PackedVector2Array([Vector2(ch, 0), Vector2(r.size.x - ch, 0), Vector2(r.size.x, ch), Vector2(r.size.x, r.size.y - ch),
			Vector2(r.size.x - ch, r.size.y), Vector2(ch, r.size.y), Vector2(0, r.size.y - ch), Vector2(0, ch)])
		draw_colored_polygon(pts, Color(0.62, 0.64, 0.72))
		var inner := PackedVector2Array()
		for p in pts:
			inner.append(p.lerp(r.size / 2.0, 0.045))
		draw_colored_polygon(inner, Color(0.74, 0.76, 0.84))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.9, 0.92, 0.98), 1.5)
		for y in range(26, int(r.size.y) - 20, 26):
			for x in range(26, int(r.size.x) - 20, 30):
				draw_rect(Rect2(x - 2, y - 2, 4, 4), Color(0.45, 0.47, 0.56))

## A record as rich text. The Vojenská databáze records (Ari's): the header block one field per line,
## the CAPITAL section titles in amber, short sub-titles and "Key:" items picked out, the closing words
## in italics, the signature dimmed. Any other text just gets its brackets escaped.
## 0.57 (Ari): what a weapon does against each race stays hidden until that race's autopsy
## (or the machine's analysis) is done. The section "BOJOVÁ ÚČINNOST PROTI ..." is cut into
## blocks by the race subheadings; a block naming a race not yet researched is left out.
const RACE_STEMS := {"Šediv": "pitva", "Levit": "pitva_levit", "Ohař": "pitva_ohar", "Ještěř": "pitva_jestetan",
	"Líhav": "pitva_lihnoun", "Bij": "pitva_bijec", "Nádor": "pitva_nador", "Ohniv": "pitva_ohnivec",
	"Myslod": "pitva_myslodej", "Diskoll": "rozbor_diskoll", "Kolos": "rozbor_kolos", "Nakaž": "pitva_lihnoun", "Mozek": "pitva_mozek"}
## The ship blocks (X-MAT-002: where M-115 sits in each UFO type) open with a wreck of that type brought home.
const UFO_STEMS := {"Průzkumník": "vrak_scout", "Nájezdník": "vrak_raider", "Sklízeč": "vrak_harvester",
	"Zásobovací": "vrak_supply", "Bitevní": "vrak_battleship"}
static func _ufo_known(key: String) -> bool:
	if not Campaign.active:
		return true
	return int(Campaign.data.get("found", {}).get(key, 0)) > 0 or key in Campaign.data.get("wrecks_seen", [])

static func hide_unknown(t: String) -> String:
	var paras := t.split("\n\n")
	for pi in paras.size():
		var p: String = paras[pi]
		var ships := p.begins_with("VÝSKYT V JEDNOTLIVÝCH TYPECH UFO")
		if not (ships or p.begins_with("BOJOVÁ ÚČINNOST") or (p.begins_with("DODATEK") and p.contains("MIMOZEMSK"))):
			continue
		var out := []
		var keep := true
		var hidden := 0
		var cut := p.find(": ")
		var title := p.substr(0, cut + 2)
		var lines := p.substr(cut + 2).split("\n")
		var preamble := p.begins_with("DODATEK")      # (everything before the first race is a note for us)
		for li in lines.size():
			var ln: String = lines[li]
			if ln.begins_with("Přístup:") or ln.begins_with("Důležité:") or ln.contains("zpřístupň"):
				continue          # (a note for us, not for the reader)
			if preamble and not ln.contains(" odemkne"):
				continue
			preamble = false
			var lock := ln.find(" - odemkne")
			if lock < 0:
				lock = ln.find(" – odemkne")
			if lock > 0:
				ln = ln.substr(0, lock)
			if ln.length() < 44 and not ln.right(1) in [".", "!", "?", ":", ","] and not ln.begins_with("- "):
				# a subheading: which races does it name?
				var named := []
				for stem in (UFO_STEMS if ships else RACE_STEMS):
					if ln.contains(stem):
						named.append((UFO_STEMS if ships else RACE_STEMS)[stem])
				if not named.is_empty():
					keep = named.all(func(r): return _ufo_known(r) if ships else Game.has_research(r))
					if not keep:
						hidden += 1
			if keep:
				out.append(ln)
		if hidden > 0:
			out.append("Další údaje nejsou k dispozici.")
		paras[pi] = title + "\n".join(out)
	return "\n\n".join(paras)

static func db_bbcode(t: String) -> String:
	var amber := ACCENT.to_html(false)
	var cyan := Color(0.45, 0.78, 0.86).to_html(false)
	var dim := DIM.to_html(false)
	t = t.replace("[", "[lb]")
	var paras := t.split("\n\n")
	var out := []
	var caps := RegEx.new()
	caps.compile("^((?:\\d{1,2}\\. (?=[A-ZÁČĎÉĚÍŇÓŘŠŤÚŮÝŽ]+ \\d{4}))?[A-ZÁČĎÉĚÍŇÓŘŠŤÚŮÝŽ0-9 ,/()\\-–]{4,}):\\s*")
	var field := RegEx.new()
	field.compile("\\.\\s+(?=[A-ZÁČĎÉĚÍŇÓŘŠŤÚŮÝŽ][^:.]{2,40}:\\s)")
	var key := RegEx.new()
	key.compile("^(-\\s+|\\d+\\.\\s+)?([^:]{2,40}):\\s")
	var closing := false
	for pi in paras.size():
		var p: String = paras[pi]
		if pi == 0 and p.begins_with("VOJENSKÁ DATABÁZE"):
			var lines := p.split("\n")
			var o := "[b][color=#%s]%s[/color][/b]" % [amber, lines[0]]
			for li in range(1, lines.size()):
				var ln: String = lines[li]
				if ln == ln.to_upper():
					o += "\n[color=#%s]%s[/color]" % [dim, ln]
					continue
				for f in field.sub(ln, ".\n", true).split("\n"):
					var k := key.search(f)
					o += "\n" + (("[color=#%s]%s:[/color] %s" % [cyan, k.get_string(2), f.substr(k.get_end())]) if k else f)
			out.append(o)
			continue
		# a stamp block (every line in capitals, e.g. the command's decision after the speech): centred amber
		if pi > 0 and p == p.to_upper() and p.contains(":"):
			closing = false
			var st := []
			for ln in p.split("\n"):
				var c := ln.find(":")
				st.append(("[color=#%s]%s:[/color] [b][color=#%s]%s[/color][/b]" % [dim, ln.substr(0, c), amber, ln.substr(c + 1).strip_edges()]) if c > 0 else "[b][color=#%s]%s[/color][/b]" % [amber, ln])
			out.append("[center]%s[/center]" % "\n".join(st))
			continue
		var head := ""
		var m := caps.search(p)
		if m:
			head = m.get_string(1)
			p = p.substr(m.get_end())
			closing = head.begins_with("ZÁVĚREČN")
		var body := []
		for ln in p.split("\n"):
			var l: String = ln
			var last := l.right(1)
			if l.begins_with("— ") or l.begins_with("- Vedoucí") or (l.begins_with("- ") and closing and l.length() < 120 and pi == paras.size() - 1):
				body.append("[right][color=#%s][i]%s[/i][/color][/right]" % [dim, l])
			elif closing:
				body.append("[i]%s[/i]" % l)
			elif l.length() < 44 and not last in [".", "!", "?", ":", ",", "\"", ";"] and not l.begins_with("- ") and not l.contains(": "):
				body.append("[b][color=#%s]%s[/color][/b]" % [cyan, l])
			else:
				var k2 := key.search(l)
				if k2 and l.begins_with("- "):
					body.append("• [color=#%s]%s:[/color] %s" % [cyan, k2.get_string(2), l.substr(k2.get_end())])
				elif k2 and k2.get_string(1) != "":
					body.append("[b]%s%s:[/b] %s" % [k2.get_string(1), k2.get_string(2), l.substr(k2.get_end())])
				elif k2 and k2.get_string(2).length() <= 28 and k2.get_string(2).left(1) == k2.get_string(2).left(1).to_upper():
					# "Primární cíl: ..." - a key line inside a section
					body.append("[color=#%s]%s:[/color] %s" % [cyan, k2.get_string(2), l.substr(k2.get_end())])
				else:
					body.append(l)
		out.append(("[b][color=#%s]%s[/color][/b]\n" % [amber, head] if head != "" else "") + "\n".join(body))
	return "\n\n".join(out)
