extends Control
## Modelář - the block modeller. Every model in the game is built from blocks, cylinders and balls;
## here Ari clicks one, drags it where it belongs, makes it bigger or smaller, turns it, paints it,
## adds new blocks or removes them. Changes go to modely/<model>.json and the game uses them at once.

const AlienScript := preload("res://scripts/alien.gd")

const PALETTE := [[0.08, 0.08, 0.08], [0.22, 0.22, 0.23], [0.45, 0.46, 0.48], [0.75, 0.76, 0.78], [0.95, 0.95, 0.93],
	[0.22, 0.24, 0.17], [0.35, 0.38, 0.25], [0.30, 0.20, 0.12], [0.55, 0.40, 0.25], [0.62, 0.47, 0.38],
	[0.60, 0.08, 0.06], [0.85, 0.55, 0.10], [0.85, 0.75, 0.20], [0.20, 0.55, 0.25], [0.15, 0.30, 0.60], [0.45, 0.25, 0.55]]
const STEPS := [["jemně", 0.003], ["středně", 0.01], ["hrubě", 0.04]]
const NAMES := {"merc": "Žoldák", "heli": "Vrtulník Čáp", "dropship": "Kondor", "sokol": "Stíhačka Sokol", "cow": "Kráva",
	"ufo_scout": "UFO průzkumník (let)", "ufo_raider": "UFO nájezdník (let)", "ufo_harvester": "UFO sklízeč (let)",
	"ufo_g_scout": "UFO průzkumník (na zemi)", "ufo_g_raider": "UFO nájezdník (na zemi)", "ufo_g_harvester": "UFO sklízeč (na zemi)",
	"pistol_mag": "Zásobník", "round": "Náboj", "hand_l": "Levá ruka (z očí)", "hand_r": "Pravá ruka (z očí)"}

var view: SubViewport
var world: Node3D
var cam: Camera3D
var model: Node3D
var model_name := ""
var work := {}               # the mods being edited (also live in Game.model_mods)
var sel := ""                # selected part id ("Piece:n" or "new:k")
var sel_piece := ""
var step := 0.01
var yaw := PI + 0.6
var pitch := -0.25
var dist := 1.5
var target := Vector3.ZERO
var extent := 1.0
var _orbit := false
var _drag := false
var _drag_plane := Plane()
var _drag_last := Vector3.ZERO
var _undo := []
var status: Label
var info: Label
var model_opt: OptionButton
var _box_lines: MeshInstance3D
var svc: SubViewportContainer
# Svitky-style handling: several parts selected at once, arrows to drag along an axis, G/S/R modes
var sels: Array = []         # all selected part ids (sel = the active one)
var mode := "posun"          # posun / velikost / otaceni
var _gizmo: MeshInstance3D
var _hint: Label
var _redo := []
var _batch := false
var _axis_drag := -1         # dragging an arrow (0 x, 1 y, 2 z)
var _hover_axis := -1
var _pan := false
const MODE_NAMES := {"posun": "POSUN (G)", "velikost": "VELIKOST (S)", "otaceni": "OTÁČENÍ (R)"}
const AXIS_COL := [Color(0.92, 0.27, 0.24), Color(0.43, 0.82, 0.31), Color(0.31, 0.55, 0.98)]

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.texture = UiSkin.backdrop()
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiSkin.inset(3))
	frame.position = Vector2(6, 20)
	frame.size = Vector2(384, 314)
	add_child(frame)
	svc = SubViewportContainer.new()
	svc.stretch = true
	svc.gui_input.connect(_view_input)
	# a holder at the frame's size; the view inside renders at the screen's real resolution
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(378, 308)
	holder.clip_contents = true
	frame.add_child(holder)
	holder.add_child(svc)
	view = SubViewport.new()
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	svc.add_child(view)
	world = Node3D.new()
	view.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.13, 0.15, 0.17)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.62, 0.66)
	env.environment = e
	world.add_child(env)
	for d in [[Vector3(-40, 30, 0), 1.2], [Vector3(-25, 210, 0), 0.6]]:
		var l := DirectionalLight3D.new()
		l.rotation_degrees = d[0]
		l.light_energy = d[1]
		world.add_child(l)
	cam = Camera3D.new()
	cam.fov = 45.0
	world.add_child(cam)
	_box_lines = MeshInstance3D.new()
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(1.0, 0.6, 0.1)
	lm.no_depth_test = true
	_box_lines.material_override = lm
	world.add_child(_box_lines)
	_gizmo = MeshInstance3D.new()
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.vertex_color_use_as_albedo = true
	gm.no_depth_test = true
	gm.render_priority = 10
	_gizmo.material_override = gm
	world.add_child(_gizmo)
	_build_panel()
	EditorTabs.add(self, "models")
	_hint = EditorTabs.hint(self)
	_show_hint()
	if Game.autotest() == "modeler":
		_selftest.call_deferred()

# ---- the panel ------------------------------------------------------------------------------------
func _build_panel() -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiSkin.panel(6))
	p.position = Vector2(396, 20)
	p.size = Vector2(238, 314)
	add_child(p)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(sc)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 2)
	sc.add_child(box)
	var title := Label.new()
	title.text = "Modelář"
	UiSkin.title(title, 12)
	box.add_child(title)
	model_opt = OptionButton.new()
	model_opt.add_theme_font_size_override("font_size", 8)
	box.add_child(model_opt)
	for e in _model_list():
		model_opt.add_item(e[1])
		model_opt.set_item_metadata(model_opt.item_count - 1, e[0])
	model_opt.item_selected.connect(func(i): _load_model(String(model_opt.get_item_metadata(i))))
	info = _lbl(box, "Klikni na kostku v obrázku.", UiSkin.AMBER)
	var srow := HBoxContainer.new()
	box.add_child(srow)
	_lbl(srow, "Krok:", UiSkin.GLOW)
	for s in STEPS:
		var v: float = s[1]
		_btn(srow, s[0], func(): step = v * extent; status.text = "Krok: %s" % _fmt(step))
	_lbl(box, "POSUNOUT (nebo táhni kostku myší)", UiSkin.GLOW)
	var g := GridContainer.new()
	g.columns = 3
	box.add_child(g)
	for e in [["◄ vlevo", Vector3.LEFT], ["▲ nahoru", Vector3.UP], ["► vpravo", Vector3.RIGHT],
			["▼ dolů", Vector3.DOWN], ["● blíž", Vector3.BACK], ["○ dál", Vector3.FORWARD]]:
		var d: Vector3 = e[1]
		_btn(g, e[0], func(): _group(func(): _move_view(d)))
	_lbl(box, "OTOČIT", UiSkin.GLOW)
	var g2 := GridContainer.new()
	g2.columns = 3
	box.add_child(g2)
	for e in [["↺ doleva", Vector3.UP, 15.0], ["↻ doprava", Vector3.UP, -15.0], ["⤓ k sobě", Vector3.RIGHT, 15.0],
			["⤒ od sebe", Vector3.RIGHT, -15.0], ["⟲ naklonit", Vector3.FORWARD, 15.0], ["⟳ naklonit", Vector3.FORWARD, -15.0]]:
		var ax: Vector3 = e[1]
		var deg: float = e[2]
		_btn(g2, e[0], func(): _group(func(): _rotate_view(ax, deg)))
	_lbl(box, "VELIKOST", UiSkin.GLOW)
	var g3 := GridContainer.new()
	g3.columns = 4
	box.add_child(g3)
	for e in [["širší", 0, 1.1], ["užší", 0, 0.9], ["vyšší", 1, 1.1], ["nižší", 1, 0.9],
			["delší", 2, 1.1], ["kratší", 2, 0.9], ["větší", 3, 1.1], ["menší", 3, 0.9]]:
		var axis: int = e[1]
		var f: float = e[2]
		_btn(g3, e[0], func(): _group(func(): _scale(axis, f)))
	_lbl(box, "BARVA", UiSkin.GLOW)
	var g4 := GridContainer.new()
	g4.columns = 8
	box.add_child(g4)
	for c in PALETTE:
		var col: Array = c
		var b := Button.new()
		b.custom_minimum_size = Vector2(24, 14)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(col[0], col[1], col[2])
		sb.border_color = Color(0, 0, 0)
		sb.set_border_width_all(1)
		b.add_theme_stylebox_override("normal", sb)
		var sh := sb.duplicate()
		sh.border_color = UiSkin.GLOW
		b.add_theme_stylebox_override("hover", sh)
		b.add_theme_stylebox_override("pressed", sh)
		b.pressed.connect(func(): _group(func(): _paint(col)))
		g4.add_child(b)
	var r5 := HBoxContainer.new()
	box.add_child(r5)
	_btn(r5, "původní barva", func(): _group(func(): _paint(null)))
	_lbl(box, "KOSTKY", UiSkin.GLOW)
	var r6 := GridContainer.new()
	r6.columns = 3
	box.add_child(r6)
	_btn(r6, "+ kostka", func(): _add("box"))
	_btn(r6, "+ válec", func(): _add("cyl"))
	_btn(r6, "+ koule", func(): _add("ball"))
	_btn(r6, "kopie (Ctrl+D)", func(): _each(_duplicate))
	_btn(r6, "zrcadlo (M)", func(): _each(_mirror))
	_btn(r6, "smazat (Del)", func(): _each(_delete))
	_btn(r6, "vrátit kostku", func(): _each(_reset_part))
	status = _lbl(box, "", UiSkin.DIM)
	var r7 := HBoxContainer.new()
	box.add_child(r7)
	_btn(r7, "Uložit", _save)
	_btn(r7, "Krok zpět", _undo_step)
	_btn(r7, "Vše vrátit", _reset_all)
	_load_model(String(model_opt.get_item_metadata(0)))

func _btn(parent: Node, s: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = s
	b.add_theme_font_size_override("font_size", 7)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiSkin.button(b)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _lbl(parent: Node, s: String, col: Color) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_size_override("font_size", 7)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)
	return l

func _fmt(v: float) -> String:
	return ("%.0f mm" % (v * 1000.0)) if v < 0.1 else ("%.0f cm" % (v * 100.0))

func _model_list() -> Array:
	var out := []
	var seen := {}
	for id in Game.ITEMS:
		if ResourceLoader.exists("res://assets/models/%s.glb" % id):
			out.append([id, "Věc: " + String(Game.ITEMS[id]["name"])])
			seen[id] = true
	out.append(["merc", "Žoldák"])
	seen["merc"] = true
	for r in AlienScript.RACES:
		var m := String(AlienScript.RACES[r].get("model", ""))
		if m != "" and not seen.has(m) and ResourceLoader.exists("res://assets/models/%s.glb" % m):
			out.append([m, "Vetřelec: " + String(AlienScript.RACES[r]["name"])])
			seen[m] = true
	var rest := []
	for f in DirAccess.get_files_at("res://assets/models"):
		var n := f.trim_suffix(".import").trim_suffix(".glb")
		if (f.ends_with(".glb") or f.ends_with(".glb.import")) and not seen.has(n):
			seen[n] = true
			rest.append([n, NAMES.get(n, n.replace("_", " "))])
	rest.sort_custom(func(a, b): return String(a[1]) < String(b[1]))
	return out + rest

# ---- the model ------------------------------------------------------------------------------------
func _load_model(n: String) -> void:
	model_name = n
	work = Game.model_mods.get(n, {}).duplicate(true)
	if not work.has("parts"):
		work["parts"] = {}
	if not work.has("new"):
		work["new"] = []
	_undo.clear()
	sel = ""
	_rebuild()
	# frame it
	var box := _world_box()
	extent = maxf(box.size.length(), 0.05)
	target = box.get_center()
	dist = extent * 1.15 + 0.1
	step = 0.01 * extent
	info.text = "Klikni na kostku v obrázku."

func _rebuild() -> void:
	if model:
		model.queue_free()
	var path := "res://assets/models/%s.glb" % model_name
	model = (load(path) as PackedScene).instantiate()
	if model_name == "merc":
		model.scale = Vector3(-1, 1, 1)     # as in the game: the gun hand on the right
	world.add_child(model)
	var mods := work.duplicate()
	mods["_all"] = true
	ModelMods.apply(model, mods)
	Game._restyle(model)
	if model_name == "merc":
		Game.apply_look(model, Game.merc.get("look", {}))
	_show_box()

func _world_box() -> AABB:
	var box := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		if not mi.visible:
			continue
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

## Every part: [mesh instance, part dict] in the order they were built.
func _parts() -> Array:
	var out := []
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		if not mi.visible:
			continue
		for p in mi.get_meta("eb_parts", []):
			out.append([mi, p])
	return out

func _find(id: String) -> Array:
	for e in _parts():
		if e[1]["id"] == id:
			return e
	return []

# ---- editing -----------------------------------------------------------------------------------
func _push() -> void:
	if _batch:
		return
	_redo.clear()
	_undo.append(work.duplicate(true))
	if _undo.size() > 80:
		_undo.pop_front()

func _commit() -> void:
	if _batch:
		return
	Game.model_mods[model_name] = work
	_rebuild()

func _undo_step() -> void:
	if _undo.is_empty():
		status.text = "Není co vracet."
		return
	_redo.append(work.duplicate(true))
	work = _undo.pop_back()
	_commit()

func _redo_step() -> void:
	if _redo.is_empty():
		status.text = "Není co vrátit dopředu."
		return
	_undo.append(work.duplicate(true))
	work = _redo.pop_back()
	_commit()

## One change for every selected part (one step of undo).
func _group(fn: Callable) -> void:
	if sels.is_empty():
		if sel == "":
			status.text = "Nejdřív klikni na kostku."
			return
		sels = [sel]
	_push()
	_batch = true
	var active := sel
	for id in sels:
		sel = id
		fn.call()
	sel = active
	_batch = false
	_commit()

## Copy / mirror / delete / reset for every selected part (new parts become the selection).
func _each(fn: Callable) -> void:
	if sels.is_empty():
		if sel == "":
			status.text = "Nejdřív klikni na kostku."
			return
		sels = [sel]
	_push()
	_batch = true
	var ids: Array = sels.duplicate()
	# deleting new parts shifts the ones after them: go from the back
	ids.sort_custom(func(a, b): return (int(String(a).substr(4)) if String(a).begins_with("new:") else -1) > (int(String(b).substr(4)) if String(b).begins_with("new:") else -1))
	var made := []
	for id in ids:
		sel = id
		var before: int = work["new"].size()
		fn.call()
		for k in range(before, work["new"].size()):
			made.append("new:%d" % k)
	_batch = false
	sels = made if not made.is_empty() else []
	sel = made[-1] if not made.is_empty() else ""
	_commit()
	_show_box()

## The xf (pos, rot, scale) of the selected part: a reference to its entry so it can be changed.
func _entry() -> Dictionary:
	if sel.begins_with("new:"):
		var i := int(sel.substr(4))
		return work["new"][i] if i < work["new"].size() else {}
	if not work["parts"].has(sel):
		work["parts"][sel] = {}
	return work["parts"][sel]

func _xf(en: Dictionary) -> Array:
	if not en.has("xf"):
		en["xf"] = ModelMods.IDENT.duplicate()
	return en["xf"]

## World direction -> the part's own (mesh) space.
func _to_mesh(mi: MeshInstance3D, v: Vector3) -> Vector3:
	return mi.global_transform.basis.inverse() * v

func _move_view(d: Vector3) -> void:
	if sel == "":
		status.text = "Nejdřív klikni na kostku."
		return
	var e := _find(sel)
	if e.is_empty():
		return
	_push()
	var right := cam.global_transform.basis.x
	right.y = 0
	right = right.normalized()
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var w := right * d.x + Vector3.UP * d.y - fwd * d.z
	_shift(e[0], w * step)
	_commit()

func _shift(mi: MeshInstance3D, world_delta: Vector3) -> void:
	var xf := _xf(_entry())
	var m := _to_mesh(mi, world_delta)
	xf[0] = float(xf[0]) + m.x
	xf[1] = float(xf[1]) + m.y
	xf[2] = float(xf[2]) + m.z

func _rotate_view(axis: Vector3, deg: float) -> void:
	if sel == "":
		status.text = "Nejdřív klikni na kostku."
		return
	var e := _find(sel)
	if e.is_empty():
		return
	_push()
	var mi: MeshInstance3D = e[0]
	var wa: Vector3 = Vector3.UP if axis == Vector3.UP else (cam.global_transform.basis.x if axis == Vector3.RIGHT else -cam.global_transform.basis.z)
	var ma := _to_mesh(mi, wa).normalized()
	var xf := _xf(_entry())
	var r := Basis.from_euler(Vector3(float(xf[3]), float(xf[4]), float(xf[5])) * (PI / 180.0))
	r = Basis(ma, deg_to_rad(deg)) * r
	var eu := r.get_euler() * (180.0 / PI)
	xf[3] = snappedf(eu.x, 0.01)
	xf[4] = snappedf(eu.y, 0.01)
	xf[5] = snappedf(eu.z, 0.01)
	_commit()

func _scale(axis: int, f: float) -> void:
	if sel == "":
		status.text = "Nejdřív klikni na kostku."
		return
	_push()
	var xf := _xf(_entry())
	for k in ([0, 1, 2] if axis == 3 else [axis]):
		xf[6 + k] = clampf(float(xf[6 + k]) * f, 0.05, 50.0)
	_commit()

func _paint(col) -> void:
	if sel == "":
		status.text = "Nejdřív klikni na kostku."
		return
	_push()
	var en := _entry()
	if col == null:
		en.erase("color")
		if sel.begins_with("new:"):
			en["color"] = [0.5, 0.5, 0.5]
	else:
		en["color"] = col
	_commit()

func _add(shape: String) -> void:
	_push()
	var e := _find(sel) if sel != "" else []
	var mi: MeshInstance3D = e[0] if not e.is_empty() else model.find_children("*", "MeshInstance3D", true, false)[0]
	var at: Vector3 = (e[1]["center"] as Vector3) if not e.is_empty() else mi.global_transform.affine_inverse() * target
	var right := _to_mesh(mi, cam.global_transform.basis.x.normalized())
	at += right * extent * 0.06
	var s := extent * 0.06
	work["new"].append({"piece": String(mi.name), "shape": shape, "xf": [at.x, at.y, at.z, 0, 0, 0, s, s, s],
		"color": [0.5, 0.5, 0.5], "bone": String(e[1].get("bone", "")) if not e.is_empty() else ""})
	sel = "new:%d" % (work["new"].size() - 1)
	sels = [sel]
	sel_piece = String(mi.name)
	_commit()
	status.text = "Přidáno. Posuň ji tažením nebo šipkami."

func _duplicate() -> void:
	if sel == "":
		status.text = "Nejdřív klikni na kostku."
		return
	var e := _find(sel)
	if e.is_empty():
		return
	_push()
	var mi: MeshInstance3D = e[0]
	var right := _to_mesh(mi, cam.global_transform.basis.x.normalized())
	if sel.begins_with("new:"):
		var c: Dictionary = _entry().duplicate(true)
		c["xf"][0] = float(c["xf"][0]) + right.x * extent * 0.05
		c["xf"][1] = float(c["xf"][1]) + right.y * extent * 0.05
		c["xf"][2] = float(c["xf"][2]) + right.z * extent * 0.05
		work["new"].append(c)
	else:
		# an original piece is copied as a block of its size and colour
		var tris: PackedVector3Array = e[1]["tris"]
		var bb := AABB(tris[0], Vector3.ZERO)
		for p in tris:
			bb = bb.expand(p)
		var at := bb.get_center() + right * extent * 0.05
		var col: Array = _entry().get("color", _part_color(mi, e[1]))
		work["new"].append({"piece": String(mi.name), "shape": "box", "xf": [at.x, at.y, at.z, 0, 0, 0, bb.size.x, bb.size.y, bb.size.z],
			"color": col, "bone": String(e[1].get("bone", ""))})
	sel = "new:%d" % (work["new"].size() - 1)
	_commit()
	status.text = "Kopie hotová (vedle původní)."

## A mirror copy on the other side of the model (across its middle, left-right in the model's own space).
func _mirror() -> void:
	var e := _find(sel)
	if e.is_empty():
		return
	var mi: MeshInstance3D = e[0]
	var cx := (mi.global_transform.affine_inverse() * _world_box().get_center()).x
	var c := {}
	if sel.begins_with("new:"):
		c = _entry().duplicate(true)
	else:
		var tris: PackedVector3Array = e[1]["tris"]
		var bb := AABB(tris[0], Vector3.ZERO)
		for q in tris:
			bb = bb.expand(q)
		var at := bb.get_center()
		c = {"piece": String(mi.name), "shape": "box", "xf": [at.x, at.y, at.z, 0, 0, 0, bb.size.x, bb.size.y, bb.size.z],
			"color": _entry().get("color", _part_color(mi, e[1])), "bone": String(e[1].get("bone", ""))}
	var xf: Array = c["xf"]
	xf[0] = 2.0 * cx - float(xf[0])
	xf[4] = -float(xf[4])
	xf[5] = -float(xf[5])
	work["new"].append(c)

func _part_color(mi: MeshInstance3D, p: Dictionary) -> Array:
	var m := mi.get_active_material(0)
	if m is BaseMaterial3D:
		var c: Color = (m as BaseMaterial3D).albedo_color
		return [c.r, c.g, c.b]
	return [0.5, 0.5, 0.5]

func _delete() -> void:
	if sel == "":
		status.text = "Nejdřív klikni na kostku."
		return
	_push()
	if sel.begins_with("new:"):
		work["new"].remove_at(int(sel.substr(4)))
	else:
		_entry()["del"] = true
	sel = ""
	_commit()
	info.text = "Smazáno (Ctrl+Z ji vrátí)."

func _reset_part() -> void:
	if sel == "" or sel.begins_with("new:"):
		status.text = "Vrátit jde jen původní kostka."
		return
	_push()
	work["parts"].erase(sel)
	_commit()

func _reset_all() -> void:
	_push()
	work = {"parts": {}, "new": []}
	sel = ""
	_commit()
	status.text = "Model je zase původní (ulož, ať to platí)."

func _save() -> void:
	Game.model_mods[model_name] = work
	if Game.save_model_mods(model_name):
		status.text = "Uloženo do %s\nPošli tu složku Claudovi, dá to do hry natrvalo." % Game.models_dir().path_join(model_name + ".json")
		Game.play_ui(self, "ui_confirm", -6)
	else:
		status.text = "Uložení se nepovedlo (%s)." % Game.models_dir()
		Game.play_ui(self, "ui_deny", -6)

# ---- the view ------------------------------------------------------------------------------------
func _process(_d: float) -> void:
	Game.sharp_view(svc)
	var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	cam.position = target + dir * dist
	cam.look_at(target, Vector3.UP)
	cam.near = maxf(0.01, dist * 0.02)

## Orange boxes around the selected parts, the arrows at the active one.
func _show_box() -> void:
	var im := ImmediateMesh.new()
	_box_lines.mesh = im
	_gizmo.mesh = null
	if sel == "" and sels.is_empty():
		return
	if sel != "" and not sel in sels:
		sels.append(sel)
	var any := false
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for id in sels:
		var e := _find(id)
		if e.is_empty():
			continue
		var mi: MeshInstance3D = e[0]
		var bb := _part_box(e).grow(extent * 0.004)
		for a in 8:
			for b in range(a + 1, 8):
				var pa := bb.get_endpoint(a)
				var pb := bb.get_endpoint(b)
				var diff := (pa - pb).abs()
				var axes := int(diff.x > 0.00001) + int(diff.y > 0.00001) + int(diff.z > 0.00001)
				if axes == 1:
					im.surface_add_vertex(mi.global_transform * pa)
					im.surface_add_vertex(mi.global_transform * pb)
					any = true
	if not any:
		im.surface_add_vertex(Vector3.ZERO)
		im.surface_add_vertex(Vector3.ZERO)
	im.surface_end()
	var e0 := _find(sel)
	if e0.is_empty():
		sel = ""
		sels = sels.filter(func(x): return not _find(x).is_empty())
		return
	_draw_gizmo()
	var bone := String(e0[1].get("bone", ""))
	info.text = "Vybráno: %s%s%s" % [sel, (" + %d dalších" % (sels.size() - 1)) if sels.size() > 1 else "", ("  (kloub %s)" % bone) if bone != "" else ""]

func _part_box(e: Array) -> AABB:
	var tris: PackedVector3Array = e[1]["tris"]
	var bb := AABB(tris[0], Vector3.ZERO)
	for q in tris:
		bb = bb.expand(q)
	return bb

## Where the arrows start: the middle of everything selected.
func _pivot() -> Vector3:
	var c := Vector3.ZERO
	var n := 0
	for id in sels:
		var e := _find(id)
		if e.is_empty():
			continue
		c += (e[0] as MeshInstance3D).global_transform * _part_box(e).get_center()
		n += 1
	return c / maxf(1.0, n)

func _arrow_len() -> float:
	return dist * 0.22

## Three arrows (red x, green y, blue z) from the selection; the one under the mouse is brighter.
func _draw_gizmo() -> void:
	var im := ImmediateMesh.new()
	var pv := _pivot()
	var L := _arrow_len()
	var t := L * 0.035
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var ax := Vector3.ZERO
		ax[k] = 1.0
		var col: Color = AXIS_COL[k].lightened(0.45) if k == _hover_axis or k == _axis_drag else AXIS_COL[k]
		# a thin box along the axis and a fatter head (a cube) at the tip
		var side1 := Vector3.UP if k != 1 else Vector3.RIGHT
		var side2 := ax.cross(side1)
		var tip := pv + ax * L
		var head := 3.2 if mode == "posun" else (2.6 if mode == "velikost" else 2.0)
		for seg in [[pv, tip - ax * t * head, t], [tip - ax * t * head * 2.0, tip, t * head]]:
			var a: Vector3 = seg[0]
			var b: Vector3 = seg[1]
			var w: float = seg[2]
			var c := [a + (side1 + side2) * w, a + (side1 - side2) * w, a + (-side1 - side2) * w, a + (-side1 + side2) * w]
			var d := [b + (side1 + side2) * w, b + (side1 - side2) * w, b + (-side1 - side2) * w, b + (-side1 + side2) * w]
			for i in 4:
				var j := (i + 1) % 4
				for v in [c[i], c[j], d[j], c[i], d[j], d[i]]:
					im.surface_set_color(col)
					im.surface_add_vertex(v)
			for q in [c, d]:
				for v in [q[0], q[1], q[2], q[0], q[2], q[3]]:
					im.surface_set_color(col)
					im.surface_add_vertex(v)
	im.surface_end()
	_gizmo.mesh = im

## Which arrow the mouse is on (screen distance to its line), or -1.
func _axis_at(at: Vector2) -> int:
	if sel == "":
		return -1
	var pv := _pivot()
	var L := _arrow_len()
	var k_best := -1
	var d_best := 9.0
	var s := Vector2(view.size) / svc.size
	for k in 3:
		var ax := Vector3.ZERO
		ax[k] = 1.0
		if cam.is_position_behind(pv) or cam.is_position_behind(pv + ax * L):
			continue
		var a := cam.unproject_position(pv) / s
		var b := cam.unproject_position(pv + ax * L) / s
		var d := Geometry2D.get_closest_point_to_segment(at, a, b).distance_to(at)
		if d < d_best and at.distance_to(a) > 4.0:
			d_best = d
			k_best = k
	return k_best

## The arrow being dragged: how far along it the mouse moved (metres), from its screen direction.
func _axis_delta(k: int, rel: Vector2) -> float:
	var pv := _pivot()
	var L := _arrow_len()
	var ax := Vector3.ZERO
	ax[k] = 1.0
	var s := Vector2(view.size) / svc.size
	var a := cam.unproject_position(pv) / s
	var b := cam.unproject_position(pv + ax * L) / s
	var dir := b - a
	if dir.length() < 2.0:
		return 0.0
	return rel.dot(dir.normalized()) * (L / dir.length())

func _apply_axis(k: int, rel: Vector2) -> void:
	var ax := Vector3.ZERO
	ax[k] = 1.0
	var d := _axis_delta(k, rel)
	if mode == "posun":
		_group(func():
			var e := _find(sel)
			if not e.is_empty():
				_shift(e[0], ax * d))
	elif mode == "velikost":
		var f := clampf(1.0 + d / maxf(_arrow_len() * 0.5, 0.001), 0.8, 1.25)
		_group(func():
			var e := _find(sel)
			if e.is_empty():
				return
			# the part's own axis that points most along the dragged one
			var m := _to_mesh(e[0], ax).abs()
			var i := 0 if m.x >= m.y and m.x >= m.z else (1 if m.y >= m.z else 2)
			var xf := _xf(_entry())
			xf[6 + i] = clampf(float(xf[6 + i]) * f, 0.02, 50.0))
	else:
		var deg := (rel.x - rel.y) * 0.6
		_group(func():
			var e := _find(sel)
			if e.is_empty():
				return
			var ma := _to_mesh(e[0], ax).normalized()
			var xf := _xf(_entry())
			var r := Basis.from_euler(Vector3(float(xf[3]), float(xf[4]), float(xf[5])) * (PI / 180.0))
			r = Basis(ma, deg_to_rad(deg)) * r
			var eu := r.get_euler() * (180.0 / PI)
			xf[3] = snappedf(eu.x, 0.01)
			xf[4] = snappedf(eu.y, 0.01)
			xf[5] = snappedf(eu.z, 0.01))

func _set_mode(m: String) -> void:
	mode = m
	status.text = "Režim: " + MODE_NAMES[m]
	_show_box()
	_show_hint()

func _show_hint() -> void:
	if _hint:
		_hint.text = "%s · Levé: výběr (Shift = přidat), tah za šipku = %s, tah kostky = posun · Pravé: otáčet pohled · Střední: posun pohledu · Kolečko: zoom\nG / S / R: posun / velikost / otáčení · Ctrl+D: kopie · M: zrcadlo · Del: smazat · Ctrl+Z / Ctrl+Y: zpět / znovu · F: zaměřit výběr · Ctrl+S: uložit" % [MODE_NAMES[mode], {"posun": "posun po ose", "velikost": "velikost po ose", "otaceni": "otáčení kolem osy"}[mode]]

func _ray(at: Vector2) -> Array:
	var p := at * (Vector2(view.size) / svc.size)
	return [cam.project_ray_origin(p), cam.project_ray_normal(p)]

func _pick(at: Vector2) -> String:
	var r := _ray(at)
	var best := ""
	var bd := 1e9
	for e in _parts():
		var mi: MeshInstance3D = e[0]
		var tris: PackedVector3Array = e[1]["tris"]
		var xf := mi.global_transform
		for k in range(0, tris.size(), 3):
			var hit = Geometry3D.ray_intersects_triangle(r[0], r[1], xf * tris[k], xf * tris[k + 1], xf * tris[k + 2])
			if hit != null:
				var d: float = (hit - r[0]).length()
				if d < bd:
					bd = d
					best = e[1]["id"]
	return best

func _view_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			dist = maxf(extent * 0.15, dist * 0.9)
			_show_box()
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dist = minf(extent * 8.0, dist * 1.1)
			_show_box()
		elif ev.button_index == MOUSE_BUTTON_RIGHT:
			_orbit = ev.pressed
		elif ev.button_index == MOUSE_BUTTON_MIDDLE:
			_pan = ev.pressed
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				var k := _axis_at(ev.position)
				if k >= 0:
					_axis_drag = k
					_push()
					return
				var id := _pick(ev.position)
				if id != "" and id in sels and not ev.shift_pressed:
					# drag the selection across the screen
					var e := _find(id)
					sel = id
					_drag = true
					_push()
					_drag_plane = Plane(-cam.global_transform.basis.z, e[0].global_transform * (e[1]["center"] as Vector3))
					var r := _ray(ev.position)
					var hit = _drag_plane.intersects_ray(r[0], r[1])
					_drag_last = hit if hit != null else Vector3.ZERO
				elif ev.shift_pressed and id != "":
					if id in sels:
						sels.erase(id)
						sel = sels[-1] if not sels.is_empty() else ""
					else:
						sels.append(id)
						sel = id
					_show_box()
				else:
					sel = id
					sels = [id] if id != "" else []
					_show_box()
					if id == "":
						info.text = "Klikni na kostku v obrázku."
			else:
				if _axis_drag >= 0:
					_axis_drag = -1
					_show_box()
				if _drag:
					_drag = false
	elif ev is InputEventMouseMotion:
		if _orbit:
			yaw -= ev.relative.x * 0.01
			pitch = clampf(pitch + ev.relative.y * 0.01, -1.4, 1.4)
			_show_box()
		elif _pan:
			var right := cam.global_transform.basis.x
			var up := cam.global_transform.basis.y
			target += (-right * ev.relative.x + up * ev.relative.y) * dist * 0.0025
		elif _axis_drag >= 0:
			var keep := _undo.size()
			_batch = false
			_apply_axis(_axis_drag, ev.relative * (3.0 if ev.ctrl_pressed else 1.0))
			# (the whole drag is one step of undo)
			while _undo.size() > keep:
				_undo.pop_back()
		elif _drag:
			var r := _ray(ev.position)
			var hit = _drag_plane.intersects_ray(r[0], r[1])
			if hit != null:
				var delta: Vector3 = hit - _drag_last
				_drag_last = hit
				var keep2 := _undo.size()
				_group(func():
					var e := _find(sel)
					if not e.is_empty():
						_shift(e[0], delta))
				while _undo.size() > keep2:
					_undo.pop_back()
		else:
			var h := _axis_at(ev.position)
			if h != _hover_axis:
				_hover_axis = h
				if sel != "":
					_draw_gizmo()

func _input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed and not ev.echo):
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	var handled := true
	match ev.keycode:
		KEY_Z when ev.ctrl_pressed: _undo_step()
		KEY_Y when ev.ctrl_pressed: _redo_step()
		KEY_S when ev.ctrl_pressed: _save()
		KEY_D when ev.ctrl_pressed: _each(_duplicate)
		KEY_G: _set_mode("posun")
		KEY_S: _set_mode("velikost")
		KEY_R: _set_mode("otaceni")
		KEY_M: _each(_mirror)
		KEY_DELETE, KEY_X: _each(_delete)
		KEY_ESCAPE:
			sel = ""
			sels = []
			_show_box()
		KEY_F:
			if sel != "":
				target = _pivot()
				dist = maxf(extent * 0.3, dist * 0.6)
				_show_box()
		_: handled = false
	if handled:
		get_viewport().set_input_as_handled()

# ---- test: change the rifle a little, take pictures, put everything back -----------------------------
func _selftest() -> void:
	var keep := Game.model_mods.duplicate(true)
	for i in model_opt.item_count:
		if String(model_opt.get_item_metadata(i)) == "rifle":
			model_opt.select(i)
			_load_model("rifle")
	await get_tree().process_frame
	var parts := _parts()
	print("[MOD] rifle parts: %d" % parts.size())
	get_viewport().get_texture().get_image().save_png("user://mod_0_before.png")
	sel = parts[0][1]["id"]
	_show_box()
	_scale(2, 1.5)
	_paint([0.6, 0.08, 0.06])
	_move_view(Vector3.UP)
	_add("cyl")
	_move_view(Vector3.RIGHT)
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("user://mod_1_after.png")
	print("[MOD] work: %s" % JSON.stringify(work))
	# the Svitky-style tools: an arrow drag, mirror, copy, undo
	var x0: float = float(work["new"][0]["xf"][0])
	_apply_axis(0, Vector2(40, 0))
	var moved: bool = absf(float(work["new"][0]["xf"][0]) - x0) > 0.0001
	_each(_mirror)
	var after_mirror: int = work["new"].size()
	sels = ["new:0"]
	sel = "new:0"
	_each(_duplicate)
	var after_dup: int = work["new"].size()
	_undo_step()
	print("[MOD] tools: arrow moved %s, mirror -> %d new, copy -> %d new, undo -> %d new" % [moved, after_mirror, after_dup, work["new"].size()])
	model_opt.select(0)
	for i in model_opt.item_count:
		if String(model_opt.get_item_metadata(i)) == "merc":
			_load_model("merc")
	await get_tree().process_frame
	print("[MOD] merc parts: %d" % _parts().size())
	sel = _parts()[3][1]["id"]
	_show_box()
	_paint([0.85, 0.55, 0.10])
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("user://mod_2_merc.png")
	Game.model_mods = keep
	get_tree().quit()
