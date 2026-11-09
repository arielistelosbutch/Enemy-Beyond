extends Control
class_name BaseScreen
## 0.57 (Ari): the base screen. The base itself seen from above - the very rooms the team walks
## through (base_gen builds them in a hidden world, a camera under the ceilings takes one picture),
## each named on a small plate, the corridors between them. Click a room: what it is, what it
## does; click free ground next to a finished room: what can be dug there. The hangar holds the
## fighters. Same skin as the encyclopedia.

const TEXT := Color(0.84, 0.89, 0.92)
const DIM := Color(0.55, 0.62, 0.67)
const ACCENT := Color(1.0, 0.74, 0.32)
const CYAN := Color(0.45, 0.86, 0.96)
const PPM := 15.0            # pixels per metre of the rendered picture
const MAP_W := 358.0         # the map on screen
const MAP_H := 300.0
const BLOCK := 12.0          # one base cell (map_gen.BLOCK)

var on_close: Callable
var sel := -1
var hover := -1
var map_tex: TextureRect
var overlay: Control
var side: VBoxContainer
var credits_lbl: Label
var scale_k := 1.0           # screen px per metre
var _busy := false

static func open(parent: Node, select := -1) -> BaseScreen:
	var b := BaseScreen.new()
	parent.add_child(b)
	b.build()
	b.sel = select
	b.refresh()
	return b

func build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiSkin.theme()
	var bg := TextureRect.new()
	bg.texture = UiSkin.backdrop()
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := HBoxContainer.new()
	root.position = Vector2(6, 6)
	root.size = Vector2(628, 348)
	root.add_theme_constant_override("separation", 6)
	add_child(root)
	# left: the base from above
	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", UiSkin.panel(6))
	left.custom_minimum_size = Vector2(370, 348)
	root.add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 3)
	left.add_child(lv)
	var t := Label.new()
	t.text = "ZÁKLADNA"
	lv.add_child(t)
	UiSkin.title(t, 12)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiSkin.inset(2))
	lv.add_child(frame)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(MAP_W, MAP_H)
	frame.add_child(holder)
	map_tex = TextureRect.new()
	map_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map_tex.size = Vector2(MAP_W, MAP_H)
	map_tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	holder.add_child(map_tex)
	overlay = Control.new()
	overlay.size = Vector2(MAP_W, MAP_H)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.draw.connect(_draw_overlay)
	overlay.gui_input.connect(_map_input)
	overlay.mouse_exited.connect(func(): hover = -1; overlay.queue_redraw())
	holder.add_child(overlay)
	# right: the selected room, what to build, the hangar's fighters
	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", UiSkin.panel(6))
	right.custom_minimum_size = Vector2(252, 348)
	root.add_child(right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 3)
	right.add_child(rv)
	credits_lbl = _lbl(rv, "", DIM, 8)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(240, 298)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rv.add_child(sc)
	side = VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 3)
	sc.add_child(side)
	var close := Button.new()
	close.text = "Zavřít"
	close.add_theme_font_size_override("font_size", 9)
	UiSkin.button(close)
	close.pressed.connect(_close)
	rv.add_child(close)
	_render_map()

func _close() -> void:
	if on_close.is_valid():
		on_close.call()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_close()

func _lbl(parent: Node, s: String, col := TEXT, size := 9) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(236, 0)
	parent.add_child(l)
	return l

func _btn(parent: Node, s: String, cb: Callable, size := 8) -> Button:
	var b := Button.new()
	b.text = s
	b.add_theme_font_size_override("font_size", size)
	UiSkin.button(b)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

# ---- the picture ---------------------------------------------------------------------------------
## The rooms are built for real in a world of their own and photographed from under the ceilings.
func _render_map() -> void:
	if _busy:
		return
	_busy = true
	var gw := Campaign.GRID_W
	var gh := Campaign.GRID_H
	var wm := gw * BLOCK          # metres: the grid, plus the hangar's bay one block north
	var hm := (gh + 1) * BLOCK
	var sv := SubViewport.new()
	sv.size = Vector2i(int(wm * PPM), int(hm * PPM))
	sv.own_world_3d = true
	sv.msaa_3d = Viewport.MSAA_2X
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)
	var world := Node3D.new()
	sv.add_child(world)
	BaseGenScript.new().build(world, 7, {"base": Campaign.data["base"].duplicate(true), "grid_w": gw, "grid_h": gh,
		"transport": Campaign.transport(), "live": [], "no_nav": true})
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.06, 0.05, 0.04)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.78, 0.8)
	e.ambient_light_energy = 0.9
	env.environment = e
	sv.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-70, 30, 0)
	sun.light_energy = 0.6
	sv.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = hm
	cam.near = 0.05
	cam.far = 30.0
	sv.add_child(cam)
	cam.position = Vector3(wm / 2.0, 3.2, (gh - 1) * BLOCK / 2.0)      # under every ceiling
	cam.rotation_degrees = Vector3(-90, 0, 0)
	for f in 4:
		await RenderingServer.frame_post_draw
	if not is_instance_valid(self):
		return
	var img := sv.get_texture().get_image()
	map_tex.texture = ImageTexture.create_from_image(img)
	sv.queue_free()
	scale_k = minf(MAP_W / wm, MAP_H / hm)
	_busy = false
	overlay.queue_redraw()

const BaseGenScript := preload("res://scripts/base_gen.gd")

## Where a grid cell lies on the map (screen px inside the overlay).
func _cell_rect(i: int) -> Rect2:
	var B := BLOCK
	var wm := Campaign.GRID_W * B
	var hm := (Campaign.GRID_H + 1) * B
	var off := Vector2((MAP_W - wm * scale_k) / 2.0, (MAP_H - hm * scale_k) / 2.0)
	var gx := i % Campaign.GRID_W
	var gz := i / Campaign.GRID_W
	return Rect2(off + Vector2(gx * B, (gz + 1) * B) * scale_k, Vector2(B, B) * scale_k)

func _cell_at(p: Vector2) -> int:
	for i in Campaign.data["base"].size():
		if _cell_rect(i).has_point(p):
			return i
	# the hangar's bay north of the grid belongs to the hangar below it
	for i in Campaign.GRID_W:
		var r := _cell_rect(i)
		r.position.y -= r.size.y
		if r.has_point(p) and String(Campaign.data["base"][i]["type"]) == "hangar":
			return i
	return -1

func _draw_overlay() -> void:
	if map_tex.texture == null:
		overlay.draw_string(UiSkin.font(), Vector2(MAP_W / 2 - 40, MAP_H / 2), "Načítám plán...", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, DIM)
		return
	var f := UiSkin.font(true)
	for i in Campaign.data["base"].size():
		var c: Dictionary = Campaign.data["base"][i]
		var r := _cell_rect(i).grow(-1.0 * scale_k)          # the room itself (1 m of earth round it)
		var ty := String(c["type"])
		if ty == "":
			if Campaign.can_build_at(i):
				_dashed(r.grow(-2), Color(ACCENT, 0.55 if i != hover else 0.95))
				overlay.draw_string(f, r.get_center() + Vector2(-4, 4), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(ACCENT, 0.6 if i != hover else 1.0))
		else:
			var name: String = Campaign.FACILITIES[ty].get("short", Campaign.FACILITIES[ty]["name"])
			var building := float(c["days"]) > 0.0
			var txt := name.to_upper()
			var fs := 7
			var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var plate := Rect2(r.position.x + (r.size.x - tw) / 2.0 - 3, r.position.y + 2, tw + 6, 11)
			if ty == "hangar":
				plate.position.y = r.position.y + r.size.y - 13
			overlay.draw_rect(plate, Color(0.02, 0.03, 0.04, 0.82))
			overlay.draw_rect(plate, Color(CYAN if not building else ACCENT, 0.5), false, 1.0)
			overlay.draw_string(f, plate.position + Vector2(3, 9), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, CYAN if not building else ACCENT)
			if building:
				var bt := "STAVBA %d d" % ceili(float(c["days"]))
				var bw := f.get_string_size(bt, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
				var bp := Rect2(r.get_center().x - bw / 2.0 - 3, r.get_center().y - 6, bw + 6, 11)
				overlay.draw_rect(bp, Color(0.25, 0.15, 0.0, 0.85))
				overlay.draw_string(f, bp.position + Vector2(3, 9), bt, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, ACCENT)
		if i == hover and i != sel:
			overlay.draw_rect(_full_rect(i), Color(1, 1, 1, 0.5), false, 1.0)
	if sel >= 0:
		overlay.draw_rect(_full_rect(sel), CYAN, false, 2.0)

## The hangar's outline takes its bay too.
func _full_rect(i: int) -> Rect2:
	var r := _cell_rect(i).grow(-1.0 * scale_k)
	if String(Campaign.data["base"][i]["type"]) == "hangar" and i < Campaign.GRID_W and float(Campaign.data["base"][i]["days"]) <= 0.0:
		r.position.y -= _cell_rect(i).size.y
		r.size.y += _cell_rect(i).size.y
	return r

func _dashed(r: Rect2, col: Color) -> void:
	var pts := [r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y), r.position]
	for k in 4:
		overlay.draw_dashed_line(pts[k], pts[k + 1], col, 1.0, 4.0)

func _map_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := _cell_at(event.position)
		if h != hover:
			hover = h
			overlay.queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := _cell_at(event.position)
		if i >= 0:
			sel = i
			Game.play_ui(self, "ui_click", -9)
			refresh()

# ---- the side panel ------------------------------------------------------------------------------
func refresh() -> void:
	credits_lbl.text = "Kredity: %d   Den %d" % [int(Campaign.data["credits"]), int(Campaign.data["day"])]
	for ch in side.get_children():
		ch.queue_free()
	overlay.queue_redraw()
	if sel < 0:
		_head("PLÁN ZÁKLADNY")
		_lbl(side, "Klikni na místnost na plánu. Na volné místo vedle hotové místnosti se dá kopat dál - chodba je spojí.", TEXT, 8)
		_summary()
		return
	var c: Dictionary = Campaign.data["base"][sel]
	var ty := String(c["type"])
	if ty == "":
		if not Campaign.can_build_at(sel):
			_head("ZEMINA")
			_lbl(side, "Tady je jen hlína a skála. Stavět se dá jen vedle hotové místnosti, jinak by k ní nevedla chodba.", TEXT, 8)
			return
		_head("VOLNÉ MÍSTO")
		if Campaign.viewer:
			_lbl(side, "Stavět může jen hostitel - je to jeho základna.", DIM, 8)
			return
		_lbl(side, "Co tu vykopat a vybavit:", DIM, 8)
		for f in ["laborator", "dilna", "osetrovna", "radar", "cela", "sklad", "strelnice", "silo", "laser_vez", "plazma_vez", "maskovani", "psi_gen"]:
			if Campaign.facility_open(f):
				_build_row(f)
		return
	var fi: Dictionary = Campaign.FACILITIES[ty]
	_head(String(fi["name"]).to_upper())
	if float(c["days"]) > 0.0:
		_lbl(side, "Ve výstavbě - hotovo za %d d." % ceili(float(c["days"])), ACCENT, 8)
	else:
		_lbl(side, "V provozu.", CYAN, 8)
	_lbl(side, String(fi["desc"]), TEXT, 8)
	if ty == "hangar":
		_hangar()
	elif ty == "dilna" and float(c["days"]) <= 0.0:
		_workshop()

func _head(s: String) -> void:
	var l := _lbl(side, s, ACCENT, 10)
	l.add_theme_font_override("font", UiSkin.font(true))

## What the base has, in one glance.
func _summary() -> void:
	var counts := {}
	var building := 0
	for c in Campaign.data["base"]:
		if String(c["type"]) == "":
			continue
		if float(c["days"]) > 0.0:
			building += 1
		else:
			counts[c["type"]] = int(counts.get(c["type"], 0)) + 1
	var parts := []
	for k in counts:
		parts.append("%s %d×" % [Campaign.FACILITIES[k]["name"], counts[k]])
	_lbl(side, "Místnosti: " + ", ".join(parts) + ("   Ve výstavbě: %d" % building if building > 0 else ""), DIM, 8)
	_lbl(side, "Stíhačky: %d (připraveno %d). Transport: %s." % [Campaign.jets(), Campaign.jets_ready(), Campaign.CRAFT_NAMES.get(Campaign.transport(), Campaign.transport())], DIM, 8)

func _build_row(f: String) -> void:
	var fi: Dictionary = Campaign.FACILITIES[f]
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiSkin.inset(4))
	side.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	box.add_child(v)
	var cost := Campaign.facility_cost(f)
	var b := _btn(v, "%s  -  %d kr, %d dní" % [fi["name"], cost, int(Campaign.facility_days(f))], func():
		if Campaign.build(sel, f):
			Game.play_ui(self, "ui_click", -6)
			refresh()
			_render_map(), 8)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.disabled = int(Campaign.data["credits"]) < cost or (f in ["cela", "maskovani", "psi_gen"] and Campaign.data["base"].any(func(c): return String(c["type"]) == f))
	var d := _lbl(v, String(fi["desc"]), DIM, 7)
	d.custom_minimum_size = Vector2(226, 0)

## The workshop: what is being made, and the way to the production list.
func _workshop() -> void:
	var now := float(Campaign.data["day"])
	var q := []
	for o in Campaign.data.get("orders", []):
		if o.get("made", false):
			var it := String(o["item"])
			var nm: String = Game.ITEMS[it]["short"] if Game.ITEMS.has(it) else Campaign.queue_name(it)
			q.append("%s (%d h)" % [nm, ceili((float(o["at"]) - now) * 24.0)])
	_lbl(side, "Dílny: %d (tempo %d %%)   Slitiny: %d ks   Moskovium: %d g" % [Campaign.workshop_lines(), int(round(Campaign.workshop_rate() * 100.0)), Campaign.alloys(), Campaign.moskovium()], DIM, 8)
	_lbl(side, ("Ve výrobě: " + ", ".join(q)) if not q.is_empty() else "Nic se nevyrábí.", TEXT, 8).custom_minimum_size = Vector2(226, 0)
	var host := get_parent()
	if host and host.has_method("_show_workshop"):
		_btn(side, "Výroba...", func():
			_close()
			host.call("_show_workshop"))

## The hangar: the fighters and what they carry.
func _hangar() -> void:
	_head("STÍHAČKY")
	_lbl(side, "Ve službě: %d z %d (připraveno %d)%s." % [Campaign.jets(), Campaign.MAX_JETS, Campaign.jets_ready(),
		(", z toho Jestřábů %d" % Campaign.hawks()) if Campaign.hawks() > 0 else ""], TEXT, 8)
	var coming := []
	for k in [["sokol", "Sokol"], ["jestrab", "Jestřáb"], ["kondor", "Kondor"], ["orel", "Pelikán"]]:
		if Campaign.crafts_coming(k[0]) > 0:
			coming.append("%s %d×" % [k[1], Campaign.crafts_coming(k[0])])
	if not coming.is_empty():
		_lbl(side, "Na cestě / v dílně: " + ", ".join(coming), ACCENT, 8)
	if not Campaign.viewer and Campaign.jets() + Campaign.hulls_coming() < Campaign.MAX_JETS:
		_btn(side, "Koupit Sokol - %d kr (zítra)" % Campaign.jet_price(), func():
			if Campaign.buy_jet(): refresh()
		).disabled = int(Campaign.data["credits"]) < Campaign.jet_price()
	if not Campaign.viewer and Campaign.can_buy_hawk():
		var hm: Dictionary = Campaign.CRAFT_MAKE["jestrab"]
		_btn(side, ("Dílna: Jestřáb - %d kr, %d sl., %d g" if Campaign.hawk_new() else "Dílna: Sokol na Jestřába - %d kr, %d sl., %d g") % [Campaign.hawk_price(), int(hm["al"]), int(hm["mk"])], func():
			if Campaign.buy_hawk(): refresh()
		).disabled = not Campaign.can_make_hawk()
	if not Campaign.viewer and Campaign.researched("orel") and not Campaign.pelikan() and Campaign.crafts_coming("orel") == 0:
		var pm: Dictionary = Campaign.CRAFT_MAKE["orel"]
		_btn(side, "Dílna: Pelikán - %d kr, %d sl., %d g" % [Campaign.pelikan_price(), int(pm["al"]), int(pm["mk"])], func():
			if Campaign.make_pelikan(): refresh()
		).disabled = not Campaign.can_make_pelikan()
	if not Campaign.viewer and Campaign.researched("kondor") and Campaign.transport() != "kondor" and Campaign.crafts_coming("kondor") == 0:
		_btn(side, "Dílna: Kondor - %d kr" % Campaign.kondor_price(), func():
			if Campaign.make_kondor(): refresh()
		).disabled = not Campaign.can_make_kondor()
	_lbl(side, "Výzbroj stíhaček (klikni = další):", DIM, 8)
	var gb := _btn(side, "Kulomet: " + String(Campaign.JET_GUNS[Campaign.jet_gun()][0]), func(): Campaign.cycle_jet_weapon(false); refresh())
	var hb := _btn(side, "Těžká zbraň: " + String(Campaign.JET_HEAVY[Campaign.jet_heavy()][0]), func(): Campaign.cycle_jet_weapon(true); refresh())
	gb.disabled = Campaign.viewer
	hb.disabled = Campaign.viewer
