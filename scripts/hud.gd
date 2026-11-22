extends CanvasLayer
## Everything drawn over the 3D view: crosshair, health, ammo, motion scanner,
## messages, the UFO-style inventory screen, pause and the mission result.

const PANEL := Color(0.10, 0.115, 0.13, 0.94)
const FRAME := Color(0.67, 0.70, 0.74)   # 0.72: neutral secondary text (was cyan)
const TEXT := UiSkin.TEXT
const ACCENT := UiSkin.ACC
const RED := Color(0.9, 0.2, 0.15)

var inventory_open := false
var paused := false

var canvas: Control
var msg_label: Label
var msg_time := 0.0
var hit_t := 0.0
var flash_t := 0.0
var flash_dir := 0.0
var inv_panel: PanelContainer
var inv_buttons := {}
var inv_info: Label
var held_slot := ""          # item picked up with the mouse in the inventory
var pause_panel: PanelContainer
var result_panel: PanelContainer
var _last_pos := {}           # alien name -> last position (for the scanner)
var _blips := []              # [{pos, t}]
var _scan_t := 0.0
var _scan_sweep := 0.0
var _f1_down := false

func _ready() -> void:
	layer = 5
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_hud)
	add_child(canvas)
	msg_label = Label.new()
	msg_label.position = Vector2(20, 62)      # (0.66) messages top centre, under the compass and the objective
	msg_label.size = Vector2(600, 60)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	msg_label.add_theme_font_size_override("font_size", 10)
	msg_label.add_theme_color_override("font_color", ACCENT)
	msg_label.add_theme_color_override("font_outline_color", Color.BLACK)
	msg_label.add_theme_constant_override("outline_size", 3)
	add_child(msg_label)
	_build_inventory()
	_build_pause()

func mission() -> Node:
	return get_parent()

func me() -> Node:
	return mission().local_player()

# ---- API used by player / mission -------------------------------------------------
func message(text: String, secs := 3.0) -> void:
	msg_label.text = Game.shipify(text)
	msg_time = secs

func hitmarker() -> void:
	hit_t = 0.18

# ---- voice / radio indicators ------------------------------------------------------------------
var _talk_lbl: Label
var _radio_lbl: Label
var _radio_t := 0.0

func _voice_ui(delta: float) -> void:
	if _talk_lbl == null:
		_talk_lbl = Label.new()
		_talk_lbl.position = Vector2(10, 300)
		_talk_lbl.add_theme_font_size_override("font_size", 8)
		add_child(_talk_lbl)
		_radio_lbl = Label.new()
		_radio_lbl.position = Vector2(10, 288)
		_radio_lbl.add_theme_font_size_override("font_size", 8)
		_radio_lbl.add_theme_color_override("font_color", Color(0.75, 0.9, 0.6))
		add_child(_radio_lbl)
	var v: Node = mission().voice if mission() else null
	if v and v.talking:
		_talk_lbl.text = "● VYSÍLÁŠ (vysílačka)" if v.on_radio else "● MLUVÍŠ"
		_talk_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3) if v.on_radio else Color(0.9, 0.9, 0.9))
	else:
		_talk_lbl.text = ""
	if v and not v.speakers.is_empty() and _radio_t <= 0:
		_radio_lbl.text = "Mluví: " + ", ".join(v.speakers.keys())
		_radio_lbl.visible = true
	else:
		_radio_t -= delta
		_radio_lbl.visible = _radio_t > 0
	if window_up():
		_radio_lbl.visible = false

## Somebody's voice came over the radio.
func radio_from(who: String) -> void:
	if _radio_lbl:
		_radio_lbl.text = "[Vysílačka] " + who
	_radio_t = 2.5

## Kněz's touch: the screen floods violet and slowly clears.
func psi_flash() -> void:
	var r := ColorRect.new()
	r.color = Color(0.45, 0.1, 0.6, 0.55)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	var tw := create_tween()
	tw.tween_property(r, "color:a", 0.0, 2.5).set_ease(Tween.EASE_IN)
	tw.tween_callback(r.queue_free)

## Under a grey officer's illusion: a violet haze at the edges that will not go away until it ends.
func psi_haze(secs: float) -> void:
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float k = 1.0;
void fragment() {
	vec2 c = UV - vec2(0.5);
	float v = smoothstep(0.25, 0.75, length(c) * 1.2);
	float p = 0.75 + 0.25 * sin(TIME * 2.3 + UV.y * 6.0);
	COLOR = vec4(0.5, 0.12, 0.7, v * 0.6 * p * k + 0.06 * k);
}"""
	sm.shader = sh
	r.material = sm
	add_child(r)
	psi_flash()
	var tw := create_tween()
	tw.tween_interval(maxf(0.5, secs - 1.5))
	tw.tween_method(func(x: float): sm.set_shader_parameter("k", x), 1.0, 0.0, 1.5)
	tw.tween_callback(r.queue_free)

## Knocked out: almost black, until somebody brings you round.
var _ko_rect: ColorRect
func ko_dark(on: bool) -> void:
	if on:
		if _ko_rect == null:
			_ko_rect = ColorRect.new()
			_ko_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			_ko_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(_ko_rect)
			move_child(_ko_rect, 0)      # under the messages
		_ko_rect.color = Color(0, 0, 0, 0)
		create_tween().tween_property(_ko_rect, "color:a", 0.93, 0.8)
	elif _ko_rect:
		var r := _ko_rect
		_ko_rect = null
		var tw := create_tween()
		tw.tween_property(r, "color:a", 0.0, 1.5)
		tw.tween_callback(r.queue_free)

## The night-vision tube overloads: pale green, the protection pulls the gain down, it comes back.
func nvg_overload(k: float) -> void:
	var r := ColorRect.new()
	r.color = Color(0.75, 1.0, 0.75, clampf(k, 0.0, 1.0) * 0.95)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	move_child(r, 0)
	var tw := create_tween()
	tw.tween_interval(0.25 + k * 0.6)
	tw.tween_property(r, "color:a", 0.0, 1.0 + k * 1.2).set_ease(Tween.EASE_IN)
	tw.tween_callback(r.queue_free)

## Behind a battered shield: the window is cracked, the more the worse.
var _visor: Control
var _visor_k := 0.0
func visor(k: float) -> void:
	if k <= 0.01:
		if _visor:
			_visor.visible = false
		return
	if _visor == null:
		_visor = Control.new()
		_visor.set_anchors_preset(Control.PRESET_FULL_RECT)
		_visor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_visor)
		move_child(_visor, 0)
		_visor.draw.connect(_draw_visor)
	_visor.visible = true
	if absf(k - _visor_k) > 0.03:
		_visor_k = k
		_visor.queue_redraw()

func _draw_visor() -> void:
	var sz := _visor.size
	var rng := RandomNumberGenerator.new()
	rng.seed = 5701
	_visor.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.75, 0.8, 0.8, 0.12 * _visor_k))
	var n := int(3 + 16 * _visor_k)
	for i in n:
		var p := Vector2(rng.randf_range(0.15, 0.85) * sz.x, rng.randf_range(0.15, 0.85) * sz.y)
		var col := Color(0.92, 0.95, 0.95, rng.randf_range(0.25, 0.5) * (0.6 + 0.4 * _visor_k))
		# a star of cracks from each impact
		for arm in rng.randi_range(3, 6):
			var a := rng.randf() * TAU
			var q := p
			for seg in rng.randi_range(3, 6):
				a += rng.randf_range(-0.6, 0.6)
				var q2 := q + Vector2(cos(a), sin(a)) * rng.randf_range(12.0, 38.0) * sz.y / 720.0
				_visor.draw_line(q, q2, col, rng.randf_range(1.0, 2.0))
				q = q2
		_visor.draw_circle(p, 3.0 * sz.y / 720.0, col)

## A flare burns out next to you: the eyes lag behind the dark for a few seconds.
var _nblind_rect: ColorRect
var _nblind_tw: Tween
func night_blind() -> void:
	if _nblind_rect == null or not is_instance_valid(_nblind_rect):
		_nblind_rect = ColorRect.new()
		_nblind_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_nblind_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_nblind_rect)
		move_child(_nblind_rect, 0)
	if _nblind_tw and _nblind_tw.is_valid():
		_nblind_tw.kill()      # (one veil, never darker than one burnt-out flare)
	_nblind_rect.color = Color(0, 0, 0, 0.6)
	_nblind_tw = create_tween()
	_nblind_tw.tween_property(_nblind_rect, "color:a", 0.0, 4.5).set_ease(Tween.EASE_IN)

## Ještěřan's flash trap: the world goes white, then slowly comes back.
## LC-01's shot: a short white flash.
func shot_flash() -> void:
	var r := ColorRect.new()
	r.color = Color(1.0, 0.92, 0.88, 0.45)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	var tw := create_tween()
	tw.tween_property(r, "color:a", 0.0, 0.18)
	tw.tween_callback(r.queue_free)

## (2026-11-17) flashes never pile up into a white wall: one veil, the stronger flash wins, and
## eyes that were just dazzled take the next one at half strength (BLIND_ADAPT s).
const BLIND_ADAPT := 10.0
var _blind_rect: ColorRect
var _blind_tw: Tween
var _blind_last := -99.0
func blind_flash(k: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _blind_last < BLIND_ADAPT:
		k *= 0.5
	_blind_last = now
	k = clampf(k, 0.0, 1.0)
	if _blind_rect == null or not is_instance_valid(_blind_rect):
		_blind_rect = ColorRect.new()
		_blind_rect.color = Color(1.0, 0.98, 0.93, 0.0)
		_blind_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_blind_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_blind_rect)
	k = maxf(k, _blind_rect.color.a)
	if _blind_tw and _blind_tw.is_valid():
		_blind_tw.kill()
	_blind_rect.color.a = k
	_blind_tw = create_tween()
	_blind_tw.tween_interval(0.6 + k * 1.4)
	_blind_tw.tween_property(_blind_rect, "color:a", 0.0, 2.5 + k * 2.5).set_ease(Tween.EASE_IN)

## How white the screen is now (autotest).
func blind_level() -> float:
	return _blind_rect.color.a if _blind_rect and is_instance_valid(_blind_rect) else 0.0

func damage_flash(from: Vector3) -> void:
	flash_t = 0.6
	var p := me()
	if p:
		var d: Vector3 = (from - p.global_position)
		var local: Vector3 = p.global_transform.basis.inverse() * d
		flash_dir = atan2(local.x, -local.z)

# ---- briefing: black screen, typewriter text, then the night fades in --------------------
var _brief_bg: ColorRect
var _brief_lbl: Label
var _brief_t := -1.0
var _brief_len := 0

func briefing(text: String) -> void:
	_brief_bg = ColorRect.new()
	_brief_bg.color = Color(0, 0, 0, 1)
	_brief_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_brief_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_brief_bg)
	var back := TextureRect.new()
	back.texture = UiSkin.backdrop()
	back.stretch_mode = TextureRect.STRETCH_SCALE
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.modulate = Color(0.55, 0.55, 0.55)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brief_bg.add_child(back)
	# 0.72 (návrh A): the report split up - where and when on top, the story typed out, the task
	# in a gold box, the facts as a table, the place on the map on the right
	var parts := _brief_parts(Game.shipify(text))
	var v := VBoxContainer.new()
	v.position = Vector2.ZERO
	v.size = Vector2(640, 360)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 0)
	_brief_bg.add_child(v)
	var mg := MarginContainer.new()
	mg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in [["left", 34], ["right", 28], ["top", 26], ["bottom", 8]]:
		mg.add_theme_constant_override("margin_" + k[0], k[1])
	v.add_child(mg)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 22)
	cols.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mg.add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	left.custom_minimum_size = Vector2(360, 0)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cols.add_child(left)
	var mp: Dictionary = Net.mission_params
	var eb_parts: Array = ["Hlášení z velínu", String(mp.get("type_name", "mise"))]
	if String(parts["time"]) != "":
		eb_parts.append(String(parts["time"]))
	var eb := _lbl(left, " · ".join(eb_parts), UiSkin.ACC, 7)
	UiSkin.eyebrow(eb, UiSkin.ACC, 7)
	var hl := _lbl(left, String(parts["place"]) if String(parts["place"]) != "" else String(mp.get("type_name", "Mise")), TEXT, 18)
	UiSkin.headline(hl, 18)
	hl.custom_minimum_size = Vector2(360, 0)
	_brief_lbl = _lbl(left, String(parts["story"]), Color(0.80, 0.83, 0.86), 9)
	_brief_lbl.custom_minimum_size = Vector2(360, 0)
	_brief_lbl.visible_characters = 0
	if String(parts["task"]) != "":
		var tp := PanelContainer.new()
		tp.add_theme_stylebox_override("panel", UiBox.make(Color(UiSkin.ACC.r, UiSkin.ACC.g, UiSkin.ACC.b, 0.08), Color(0, 0, 0, 0), 0, Vector4(8, 3, 6, 3)).with_bar(UiSkin.ACC, 0, 2.0))
		left.add_child(tp)
		var tl := _lbl(tp, String(parts["task"]), TEXT, 8)
		tl.custom_minimum_size = Vector2(340, 0)
	for kv in parts["facts"]:
		_kv_row(left, kv[0], kv[1])
	# the map: the place on the day side of the earth, a gold ring around it
	if mp.has("lat") and mp.has("lon"):
		var right := VBoxContainer.new()
		right.mouse_filter = Control.MOUSE_FILTER_IGNORE
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cols.add_child(right)
		var ml := _lbl(right, "Místo zásahu", UiSkin.DIM, 7)
		UiSkin.eyebrow(ml, UiSkin.DIM, 7)
		right.add_child(_brief_map(float(mp["lat"]), float(mp["lon"])))
	v.add_child(UiSkin.key_bar([["Mezerník", "přeskočit"], ["Enter", "v lodi: připraven"]]))
	_brief_len = String(parts["story"]).length()
	_brief_t = 0.0
	var mt: String = Net.mission_params.get("type", "")
	Game.play_music("final_mission" if mt == "mars" else ("terror_briefing" if mt == "terror" else "briefing"), mt == "mars")
	inventory_open = true     # blocks the mercenary while the screen is black

## The briefing text cut into its parts (the mission builds it as one text): the place and time,
## the story, the task and the facts (map, terrain, weather, camouflage, difficulty).
static func _brief_parts(text: String) -> Dictionary:
	var out := {"place": "", "time": "", "story": "", "task": "", "facts": []}
	var story := []
	var task := []
	for para in text.split("\n\n"):
		var keep := []
		for ln in para.split("\n"):
			var l := ln.strip_edges()
			if l == "":
				continue
			if l.begins_with("Oblast: "):
				var rest := l.substr(8)
				var i := rest.find(", místní čas ")
				if i >= 0:
					out["place"] = rest.substr(0, i)
					var t := rest.substr(i + 13)
					var j := t.find(", mapa ")
					if j >= 0:
						out["facts"].append(["Mapa", t.substr(j + 7)])
						t = t.substr(0, j)
					out["time"] = t.replace("(", "").replace(")", "")
				else:
					out["place"] = rest
				continue
			if l.begins_with("Terén: "):
				out["facts"].append(["Terén", l.substr(7).trim_suffix(".")])
				continue
			if l.begins_with("Počasí: "):
				out["facts"].append(["Počasí", l.substr(8).trim_suffix(".")])
				continue
			if l.begins_with("Maskáče: "):
				out["facts"].append(["Maskáče", l.substr(9).trim_suffix(".")])
				continue
			if l == l.to_upper() and l.length() < 40 and story.is_empty() and task.is_empty() and keep.is_empty():
				continue        # the mission type in capitals: it is in the eyebrow
			if l.begins_with("ÚKOL:"):
				task.append(l.substr(5).strip_edges())
				continue
			if not task.is_empty() and keep.is_empty() and story.size() > 0:
				task.append(l)
				continue
			keep.append(l)
		if not keep.is_empty():
			story.append("\n".join(keep))
	out["story"] = "\n\n".join(story)
	out["task"] = "\n".join(task)
	if out["task"] != "":
		out["task"] = "Úkol: " + out["task"]
	if not out["facts"].is_empty() or out["place"] != "":
		out["facts"].append(["Obtížnost", String(Game.DIFF_NAMES.get(Game.difficulty, Game.difficulty))])
	return out

func _brief_map(lat: float, lon: float) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(196, 196)
	box.clip_contents = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex: Texture2D = load("res://assets/textures/earth_day.png")
	if tex:
		var at := AtlasTexture.new()
		at.atlas = tex
		var w := float(tex.get_width())
		var h := float(tex.get_height())
		var span := 60.0          # degrees of longitude in view
		var px := span / 360.0 * w
		var cx := (lon + 180.0) / 360.0 * w
		var cy := (90.0 - lat) / 180.0 * h
		var rx := clampf(cx - px * 0.5, 0.0, w - px)
		var ry := clampf(cy - px * 0.5, 0.0, h - px)
		at.region = Rect2(rx, ry, px, px)
		var tr := TextureRect.new()
		tr.texture = at
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.size = Vector2(196, 196)
		tr.modulate = Color(0.55, 0.6, 0.66)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(tr)
		var dot := Vector2((cx - rx) / px, (cy - ry) / px) * 196.0
		var mark := Control.new()
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.size = Vector2(196, 196)
		mark.draw.connect(func():
			mark.draw_arc(dot, 9.0, 0.0, TAU, 32, UiSkin.ACC, 1.0)
			mark.draw_circle(dot, 2.0, UiSkin.ACC)
			mark.draw_line(Vector2(dot.x, 0), Vector2(dot.x, dot.y - 12), Color(UiSkin.ACC, 0.35), 1.0)
			mark.draw_line(Vector2(0, dot.y), Vector2(dot.x - 12, dot.y), Color(UiSkin.ACC, 0.35), 1.0))
		box.add_child(mark)
	var fr := Panel.new()
	fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fr.size = Vector2(196, 196)
	fr.add_theme_stylebox_override("panel", UiBox.make(Color(0, 0, 0, 0), UiSkin.LINE, 15))
	box.add_child(fr)
	return box

var _ready_lbl: Label
var _ready_sent := false
var _brief_fade := -1.0

func _brief_tick(delta: float) -> void:
	if _brief_t < 0:
		return
	if Game.loading_busy():
		return          # 0.66: the loading screen still covers it - the typing waits
	_brief_t += delta
	var typed := int(_brief_t * 40.0)
	var hold := float(_brief_len) / 40.0 + 1.0
	var key := Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("fire") or Input.is_key_pressed(KEY_ENTER)
	if key and _brief_t < hold:
		_brief_t = hold
		key = false
	if typed <= _brief_len and _brief_lbl.visible_characters != typed:
		_brief_lbl.visible_characters = typed
		if typed % 3 == 0 and _brief_lbl.text.substr(typed - 1, 1) != " ":
			Game.play_ui(mission(), "type", -14)
	# the briefing is over: into the ship (Enter there = ready, the ramp opens when all are)
	if _brief_t >= hold and _brief_fade < 0 and (key or _brief_t > hold + 2.5 or Game.autotest() != ""):
		_brief_lbl.visible_characters = -1
		_brief_fade = 0.0
		mission().brief_done()
	if _brief_fade >= 0:
		_brief_fade += delta
		var a := 1.0 - _brief_fade / 2.5
		_brief_bg.modulate.a = maxf(a, 0.0)
		if _ready_lbl:
			_ready_lbl.modulate.a = a
		if a <= 0:
			_brief_bg.queue_free()
			_brief_t = -1.0
		if a < 0.6 and not paused and inv_panel and not inv_panel.visible:
			inventory_open = false

## Host's count of ready players (shown while the team waits in the ship).
var ready_n := 0
var ready_total := 1
func ready_count(n: int, total: int) -> void:
	ready_n = n
	ready_total = total

func brief_go() -> void:
	if Net.mission_params.get("type", "") == "mars":
		Game.play_music("final_mission")      # the last mission keeps its own music
	else:
		Game.play_music("tactical" if Game.tactical_music else "")

func show_result(title: String, text: String, info := {}) -> void:
	Game.play_music("debriefing", false)
	Game.play_ui(self, "mission_complete" if title.begins_with("MISE SPLN") else "mission_failed", -2)
	_close_inventory()
	pause_panel.visible = false
	# 0.72 (návrh A): a full screen - the team's numbers on the left, the report on the right
	result_panel = PanelContainer.new()
	result_panel.name = "Result"
	result_panel.add_theme_stylebox_override("panel", UiSkin.full(Vector4.ZERO))
	result_panel.position = Vector2.ZERO
	result_panel.size = Vector2(640, 360)
	result_panel.custom_minimum_size = Vector2(640, 360)
	add_child(result_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	result_panel.add_child(v)
	var mg := MarginContainer.new()
	mg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for k in [["left", 30], ["right", 24], ["top", 22], ["bottom", 8]]:
		mg.add_theme_constant_override("margin_" + k[0], k[1])
	v.add_child(mg)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 22)
	mg.add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 3)
	left.custom_minimum_size = Vector2(300, 0)
	cols.add_child(left)
	var eb := _lbl(left, "Cesta domů · " + String(Net.mission_params.get("type_name", "mise")), UiSkin.ACC, 7)
	UiSkin.eyebrow(eb, UiSkin.ACC, 7)
	var won := title.begins_with("MISE SPLN")
	var hl := _lbl(left, title.substr(0, 1) + title.substr(1).to_lower(), TEXT, 18)
	UiSkin.headline(hl, 18)
	if not won:
		hl.add_theme_color_override("font_color", UiSkin.BAD)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 3)
	cols.add_child(right)
	if info.is_empty():
		# no numbers given: the whole text in the report
		var sc0 := _result_scroll(right)
		var l0 := _lbl(sc0, text, TEXT, 8)
		l0.custom_minimum_size = Vector2(220, 0)
	else:
		var lead := _lbl(left, String(info.get("why", "")), UiSkin.DIM, 8)
		lead.custom_minimum_size = Vector2(300, 0)
		# the big numbers
		var big := HBoxContainer.new()
		big.add_theme_constant_override("separation", 18)
		left.add_child(big)
		var nums := [[info.get("kills", 0), "zabití"], [info.get("caps", 0), "zajatí"]]
		var cv: Array = info.get("civ", [])
		if cv.size() == 2:
			nums.append([cv[0], "civilistů zachráněno"])
			nums.append([cv[1], "civilistů mrtvých"])
		for n in nums:
			var one := VBoxContainer.new()
			one.add_theme_constant_override("separation", -2)
			big.add_child(one)
			var nl := _lbl(one, str(n[0]), TEXT, 20)
			UiSkin.headline(nl, 20)
			nl.autowrap_mode = TextServer.AUTOWRAP_OFF
			var tl := _lbl(one, n[1], UiSkin.DIM, 6)
			UiSkin.eyebrow(tl, UiSkin.DIM, 6)
			tl.autowrap_mode = TextServer.AUTOWRAP_OFF
		# the team table
		var th := _lbl(left, "Tým", UiSkin.DIM, 7)
		UiSkin.eyebrow(th, UiSkin.DIM, 7)
		var hdr := HBoxContainer.new()
		left.add_child(hdr)
		for c in [["Voják", 136], ["Zabití", 44], ["Zajato", 44], ["Stav", 70]]:
			var cl := _lbl(hdr, c[0], UiSkin.DIM, 6)
			UiSkin.eyebrow(cl, UiSkin.DIM, 6)
			cl.autowrap_mode = TextServer.AUTOWRAP_OFF
			cl.custom_minimum_size = Vector2(c[1], 0)
		for r in info.get("team", []):
			var row := PanelContainer.new()
			row.add_theme_stylebox_override("panel", UiBox.make(Color(0, 0, 0, 0), UiSkin.LINE, 8, Vector4(0, 1, 0, 1)))
			left.add_child(row)
			var hb := HBoxContainer.new()
			row.add_child(hb)
			var bad: bool = String(r[3]) in ["mrtev", "v bezvědomí"]
			for c in [[String(r[0]), 136, TEXT], [str(r[1]), 44, TEXT], [str(r[2]), 44, TEXT], [String(r[3]), 70, UiSkin.BAD if bad else UiSkin.OK]]:
				var cl := _lbl(hb, c[0], c[2], 8)
				cl.autowrap_mode = TextServer.AUTOWRAP_OFF
				cl.clip_text = true
				cl.custom_minimum_size = Vector2(c[1], 0)
		if String(info.get("quality", "")) != "":
			_kv_row(left, "Hodnocení mise", String(info["quality"]))
		var rt := _lbl(right, "Tvůj voják", UiSkin.DIM, 7)
		UiSkin.eyebrow(rt, UiSkin.DIM, 7)
		var sc := _result_scroll(right)
		var fl := _lbl(sc, String(info.get("fate", "")).substr(0, 1).to_upper() + String(info.get("fate", "")).substr(1), TEXT, 8)
		fl.custom_minimum_size = Vector2(220, 0)
		if String(info.get("more", "")) != "":
			var ml := _lbl(sc, String(info["more"]), UiSkin.DIM, 8)
			ml.custom_minimum_size = Vector2(220, 0)
		if String(info.get("camp", "")) != "":
			var sp := Control.new()
			sp.custom_minimum_size = Vector2(0, 6)
			sc.add_child(sp)
			var ht := _lbl(sc, "Hlášení", UiSkin.DIM, 7)
			UiSkin.eyebrow(ht, UiSkin.DIM, 7)
			var cl2 := _lbl(sc, String(info["camp"]), TEXT, 8)
			cl2.custom_minimum_size = Vector2(220, 0)
	var keys := [["", "Návrat na základnu za chvíli..."]]
	v.add_child(UiSkin.key_bar(keys + [["kolečko", "posouvat hlášení"]]))

func _result_scroll(parent: Node) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(220, 60)
	parent.add_child(sc)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 3)
	sc.add_child(box)
	return box

func _kv_row(parent: Node, k: String, val: String, col := TEXT) -> void:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", UiBox.make(Color(0, 0, 0, 0), UiSkin.LINE, 8, Vector4(0, 1, 0, 1)))
	parent.add_child(row)
	var hb := HBoxContainer.new()
	row.add_child(hb)
	var kl := _lbl(hb, k, UiSkin.DIM, 8)
	kl.autowrap_mode = TextServer.AUTOWRAP_OFF
	kl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vl := _lbl(hb, val, col, 8)
	vl.autowrap_mode = TextServer.AUTOWRAP_OFF

## 0.72: a window is open over the game (pause, inventory, the result) - the HUD steps aside.
func window_up() -> bool:
	return paused or inventory_open or (result_panel != null and is_instance_valid(result_panel) and result_panel.visible)

# ---- frame -------------------------------------------------------------------------------
func _process(delta: float) -> void:
	msg_time -= delta
	msg_label.visible = msg_time > 0 and not window_up()
	_brief_tick(delta)
	_voice_ui(delta)
	hit_t -= delta
	flash_t -= delta
	_scanner_update(delta)
	if mission().finished:
		canvas.queue_redraw()
		return
	if is_instance_valid(_screen):
		canvas.queue_redraw()
		return
	if Input.is_action_just_pressed("inventory") and not paused:
		if inventory_open: _close_inventory()
		elif me() and not me().downed and not me().dead: _open_inventory()
	if Input.is_key_pressed(KEY_F1) != _f1_down:
		_f1_down = not _f1_down
		if _f1_down:
			Game.hud_hidden = not Game.hud_hidden
			message("HUD skrytý (F1)" if Game.hud_hidden else "HUD zpět (F1)", 1.5)
	if Input.is_action_just_pressed("pause") and not Game.binding_key:
		if inventory_open: _close_inventory()
		elif paused: _resume()
		else: _pause()
	if inventory_open:
		_refresh_inventory()
	canvas.queue_redraw()

func _draw_hud() -> void:
	var c := canvas
	var p := me()
	var sz := c.size
	var mid := sz / 2
	_prompts.clear()
	# red vignette when hurt
	if flash_t > 0:
		var a := clampf(flash_t, 0, 0.6) * 0.6
		c.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.6, 0, 0, a * 0.4))
		var dir := Vector2(sin(flash_dir), -cos(flash_dir))
		c.draw_circle(mid + dir * 70, 12, Color(1, 0.1, 0.1, a))
	if p == null:
		return
	if p.dead:
		var sp: Node = p.get("spectator")
		if sp != null and is_instance_valid(sp) and sp.active():
			_spectator_hud(c, sz, sp)
			return
		c.draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, 0.7))
		_text(c, Vector2(mid.x - 60, mid.y), "JSI MRTVÝ", RED, 16)
		return
	if p.downed:
		c.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.25, 0, 0, 0.35 + 0.1 * sin(Time.get_ticks_msec() / 300.0)))
		_text(c, Vector2(mid.x - 110, mid.y - 30), "V BEZVĚDOMÍ - vykrvácíš za %d s" % int(p.bleed_left), RED, 12)
		var who := ""
		if p.carried_by > 0:
			who = "Někdo tě táhne do bezpečí."
		elif p.carried_by < 0:
			who = "NĚCO TĚ TÁHNE DO TMY! Volej o pomoc!"
		_text(c, Vector2(mid.x - 110, mid.y - 12), who if who != "" else "Plazíš se (WASD). Spoluhráč musí přijít s lékárničkou.", TEXT, 9)
		if p.healed_t > 0:
			_text(c, Vector2(mid.x - 110, mid.y + 8), "%s TĚ OŠETŘUJE - nehýbej se, krvácení se zastavilo" % p.healed_by, Color(0.5, 1.0, 0.5), 10)
			c.draw_rect(Rect2(mid.x - 60, mid.y + 16, 120, 5), Color(0, 0, 0, 0.6))
			c.draw_rect(Rect2(mid.x - 60, mid.y + 16, 120 * (1.0 - p.healed_t / maxf(p.healed_total, 0.1)), 5), Color(0.4, 1.0, 0.4))
	elif not inventory_open and not paused and (p.aiming or p.bracing or hit_t > 0 or (not Game.two_handed(p.item_in("rh").get("id", "")) and not p.weapon().is_empty() and not p.sprinting)):
		# crosshair only when aiming down the sights: gap grows with the spread
		var sm: String = p.sight_mode()
		if sm == "scope":
			_scope_picture(c, mid, p)
			_lens_fx(c, mid, p, p.scope_r)
		elif sm == "dot":
			# (2026-11-17) rain on the glass, a cold lens fogging up indoors - under the dot (it shines through)
			var sg: Dictionary = Game.sight_of(p.item_in("rh").get("id", ""), p.merc)
			if p.cam and sg.has("relief"):
				_lens_fx(c, mid, p, 0.021 / float(sg["relief"]) / tan(deg_to_rad(p.cam.fov) * 0.5) * sz.y * 0.5)
			# (0.57) the red dot of the sight, where the bullet goes (the window around it is the model's)
			c.draw_circle(mid, 3.2, Color(1, 0.15, 0.08, 0.18))
			c.draw_circle(mid, 1.4, Color(1, 0.22, 0.12, 0.95))
		elif sm == "iron" or (p.aiming and p.has_sight_line()):
			pass      # iron sights are the crosshair (or the gun is still coming up to the eye)
		elif p.scoped():
			# rifle scope: round view, black around, thin cross with mil dots, breathing sway shows
			var r := sz.y * 0.46
			c.draw_arc(mid, r + 400.0, 0, TAU, 72, Color(0, 0, 0), 800.0)
			c.draw_arc(mid, r, 0, TAU, 72, Color(0.05, 0.05, 0.05), 6.0)
			var cc := Color(0.02, 0.02, 0.02, 0.9)
			c.draw_line(mid - Vector2(r, 0), mid - Vector2(6, 0), cc, 1.5)
			c.draw_line(mid + Vector2(6, 0), mid + Vector2(r, 0), cc, 1.5)
			c.draw_line(mid - Vector2(0, r), mid - Vector2(0, 6), cc, 1.5)
			c.draw_line(mid + Vector2(0, 6), mid + Vector2(0, r), cc, 1.5)
			for i in range(1, 5):
				c.draw_circle(mid + Vector2(0, i * 14), 1.2, cc)
				c.draw_circle(mid + Vector2(i * 14, 0), 1.2, cc)
				c.draw_circle(mid - Vector2(i * 14, 0), 1.2, cc)
			c.draw_circle(mid, 1.0, Color(0.9, 0.15, 0.1))
		else:
			var gap: float = 3.0 + p.current_spread() * 4.0
			var col := Color(1, 1, 1, 0.8) if hit_t <= 0 else Color(1, 0.3, 0.2)
			for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				c.draw_line(mid + d * gap, mid + d * (gap + 5), col, 1.0)
			if hit_t > 0:
				for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
					c.draw_line(mid + d * 4, mid + d * 8, Color(1, 0.3, 0.2), 1.0)
	if Game.hud_hidden:
		return          # (0.66) F1: only the crosshair / sight and what happens to you
	if window_up():
		return          # 0.72: one thing at a time - the window, not the HUD under it
	if msg_label.visible and msg_label.text != "":
		_msg_plate(c)
	# bars, bottom left (veteran: no numbers - you feel it: blood, breath, limping)
	# 0.57: on a plate of the menus' metal, with the mercenary's own figure for the stance
	_plate(c, Rect2(6, sz.y - 44, 222, 40))
	var base := Vector2(10, sz.y - 41)      # (0.66) the three rows sit inside the plate
	if Game.veteran():
		_blood(c, sz, p)
		_bar(c, base + Vector2(0, 22), "VÝDRŽ", p.stamina / 100.0, Color(0.92, 0.94, 0.96))
	else:
		_bar(c, base, "ZDRAVÍ", p.hp / p.max_hp, UiSkin.BAD)
		_bar(c, base + Vector2(0, 11), "VÝDRŽ", p.stamina / 100.0, Color(0.92, 0.94, 0.96))
		_bar(c, base + Vector2(0, 22), "STRACH", p.stress / 100.0, ACCENT)
	# a teammate who needs help: what E will do
	if not p.downed and p.busy <= 0 and not inventory_open:
		var ht: Node = p.heal_target()
		if ht:
			var t2 := ""
			var in_hand: bool = p.item_in("lh").get("id", "") == "medkit" or p.item_in("rh").get("id", "") == "medkit"
			if in_hand:
				t2 = ("X - OŠETŘIT %s" if ht.downed else "X - obvázat %s") % ht.display_name
			elif p.has_medkit():
				t2 = "X - vzít lékárničku do ruky (pak X ošetří %s)" % ht.display_name
			elif ht.downed:
				t2 = "nemáš lékárničku"
			if ht.downed:
				t2 += "    F - táhnout"
			_prompt(t2, Color(0.5, 1.0, 0.5) if in_hand else ACCENT)
	if p.busy > 0 and p.busy_total > 0 and (p.busy_text.begins_with("Ošetřuji") or p.busy_text.begins_with("Obvazuji") or p.busy_text.begins_with("Vyřezávám")):
		c.draw_rect(Rect2(mid.x - 60, mid.y + 42, 120, 5), Color(0, 0, 0, 0.6))
		c.draw_rect(Rect2(mid.x - 60, mid.y + 42, 120 * (1.0 - p.busy / p.busy_total), 5), Color(0.4, 1.0, 0.4))
	if not p.downed and p.busy <= 0 and mission().sentry_near(p.global_position):
		var st: Node = mission().sentry_near(p.global_position)
		var am := ("  %d/%d" % [st.ammo, st.ammo_max()])
		_prompt(("F - doplnit věž" if p.sentry_action(st) == "reload" else "F - složit věž") + am, TEXT)
	if not p.downed and not mission().nearest_pickup(p.global_position).is_empty():
		var it: Dictionary = mission().nearest_pickup(p.global_position)["item"]
		_prompt("F - sebrat: " + Game.ITEMS[it["id"]]["name"], TEXT)
	if p.bleeding > 0:
		_text(c, base + Vector2(0, -12), "KRVÁCÍŠ (-%.1f zdraví/s) - X lékárnička (do ruky, pak X)" % p.bleeding, RED, 9)
	# hands, bottom: left hand on the left, right hand on the right
	var right := Vector2(sz.x - 160, sz.y - 30)
	_plate(c, Rect2(sz.x - 166, sz.y - 62, 160, 56))
	var held_id: String = p.item_in("rh").get("id", "")
	var ico := UiSkin.icon(held_id) if held_id != "" else null
	if ico:
		c.draw_texture_rect(ico, Rect2(sz.x - 62, sz.y - 60, 56, 28), false, Color(1, 1, 1, 0.9))
	if p.item_in("lh").size() > 0:
		_plate(c, Rect2(sz.x - 166, sz.y - 98, 160, 26))
	_hand_text(c, p, "rh", right)
	var rid: String = p.item_in("rh").get("id", "")
	if p.item_in("lh").size() > 0:
		_hand_text(c, p, "lh", Vector2(sz.x - 160, sz.y - 96))
	_belt_bar(c, p, sz)
	var holst := []
	for hs in [["back", "1"], ["side", "2"]]:
		if p.item_in(hs[0]).size() > 0:
			holst.append("%s %s" % [hs[1], Game.ITEMS[p.inv[hs[0]]["id"]]["short"]])
	if not holst.is_empty():
		_text(c, right + Vector2(0, -24), "   ".join(holst), FRAME, 8)
	if p.spin > 0.05 and rid in ["minigun", "laser_minigun", "plasma_minigun"]:
		c.draw_rect(Rect2(mid.x - 20, mid.y + 14, 40 * p.spin, 3), Color(1, 0.6, 0.2))
	_stance_icon(c, Vector2(146, sz.y - 40), p)
	if Game.easy() or Game.has_talent(p.merc, "sesty_smysl"):
		_eye_icon(c, Vector2(132, sz.y - 86), p)    # only on easy: on normal and hardcore you never know who is watching
	if Game.mic_live:
		_text(c, Vector2(10, sz.y - 62), "MIKROFON ZAPNUTÝ (%s)" % Game.key_name("mic_toggle"), Color(0.5, 1.0, 0.5), 8)
	if p.radio_up:
		_text(c, Vector2(10, sz.y - 72), "VYSÍLAČKA (%s)" % Game.key_name("radio_talk"), ACCENT, 8)
	if not p.light_on:
		_text(c, right + Vector2(0, -12), "Svítilna vypnutá (L)", FRAME, 9)
	# busy (reloading, healing...)
	if p.busy > 0:
		_prompt(p.busy_text + "...", ACCENT, true)
	# evac
	var ev: Vector3 = mission().map["evac"]
	if p.global_position.distance_to(ev) < 3.5 and not p.dead and mission().started():
		_prompt(("ENTER - připraven k odletu (musí všichni živí, i ranění)" if not p.wants_evac else "Připraven k odletu - čekáme na ostatní (Enter = ještě ne)"), ACCENT)
		_prompt("Pokud posádka UFO žije, mise nebude splněna.", FRAME)
	# the objective of this mission, top centre; the beacon's direction for a rescue
	# (0.66) the compass on top; the objective and the end banner under it, on plates
	var marks := []
	marks.append([ev, Color(0.5, 1.0, 0.55), "výsadek"])
	var v: Node = mission().vip()
	if v and not v.dead and not v.saved and v.st != v.C.FOLLOW and mission().mtype() == "rescue":
		marks.append([v.global_position, ACCENT, "maják ~%d m" % int(snappedf(v.global_position.distance_to(p.global_position), 5.0))])
	var la: float = (Time.get_ticks_msec() - Game.loud_ms) / 1000.0
	if la < LOUD_SECS and Game.loud_at.distance_to(p.global_position) > 6.0:
		marks.append([Game.loud_at, Color(1.0, 0.45, 0.2, 1.0 - la / LOUD_SECS), "hluk"])
	_compass(c, Rect2(mid.x - 110, 2, 220, 17), p, marks)
	var ty := 30.0
	var ot: String = Game.shipify(mission().objective_text())
	if ot != "":
		_line_plate(c, Vector2(mid.x, ty), ot, ACCENT, 9)
		ty += 15.0
	if mission().done_banner:
		_line_plate(c, Vector2(mid.x, ty), Game.shipify("MISE SPLNĚNA - Enter kdekoli = odlet (transport vyzvedne všechny)"), Color(0.5, 1.0, 0.55), 10)
	if p.plant_hold > 0.0:
		c.draw_rect(Rect2(mid.x - 40, mid.y + 20, 80, 4), Color(0, 0, 0, 0.6))
		c.draw_rect(Rect2(mid.x - 40, mid.y + 20, 80 * p.plant_hold / 3.0, 4), RED)
	elif mission().beacon_near(p.global_position) >= 0:
		_prompt(("Drž F 3 s - zapnout radar" if mission().beacons[mission().beacon_near(p.global_position)].get("console", false) else "Drž F 3 s - obnovit proud") if mission().mtype() == "radar" else ("Drž F 3 s - připevnit štěnici" if mission().mtype() == "bug" else "Drž F 3 s - položit nálož"), ACCENT)
	_cards(c, p)
	if p.has_scanner():
		_plate(c, Rect2(sz.x - 92, 12, 82, 92))
		_draw_scanner(c, Vector2(sz.x - 51, 50), 38.0, p)
	_draw_prompts(c, mid)

## Veteran health display: the edges of the view fill with blood.
func _blood(c: Control, sz: Vector2, p: Node) -> void:
	var lost := 1.0 - clampf(p.hp / p.max_hp, 0.0, 1.0)
	if lost < 0.15:
		return
	var a := lost * 0.5 + 0.06 * sin(Time.get_ticks_msec() / 450.0)
	var e := 14.0 + lost * 70.0
	# many thin translucent layers: dense at the edge, fading inwards
	var n := 12
	var col := Color(0.28, 0.0, 0.0, a / float(n) * 2.2)
	for i in n:
		var w := e * (1.0 - float(i) / n)
		c.draw_rect(Rect2(0, 0, w, sz.y), col)
		c.draw_rect(Rect2(sz.x - w, 0, w, sz.y), col)
		c.draw_rect(Rect2(0, 0, sz.x, w * 0.6), col)
		c.draw_rect(Rect2(0, sz.y - w * 0.6, sz.x, w * 0.6), col)

var _breath_t := 0.0
func _breath(delta: float, p: Node) -> void:
	_breath_t -= delta
	if p.downed or p.dead or p.hp > p.max_hp * 0.5 or _breath_t > 0:
		return
	_breath_t = lerpf(1.6, 3.2, p.hp / (p.max_hp * 0.5))
	Game.play_ui(mission(), "breath", -10)

## (0.66) The quick slots at a glance: 1 back, 2 side, 3-6 belt, as icons like in the inventory,
## and how many throwables / medkits are at hand (G grenade, X smoke... the keys that throw them).
const QUICK := [["back", "1"], ["side", "2"], ["b0", "3"], ["b1", "4"], ["b2", "5"], ["b3", "6"]]
func _belt_bar(c: Control, p: Node, sz: Vector2) -> void:
	if inventory_open or p.downed:
		return
	var o := Vector2(226, sz.y - 30)
	_plate(c, Rect2(o + Vector2(2, 2), Vector2(238, 22)))
	for i in QUICK.size():
		var it: Dictionary = p.item_in(QUICK[i][0])
		var box := Rect2(o + Vector2(4 + i * 31, 3), Vector2(29, 20))
		c.draw_rect(box, Color(0, 0, 0, 0.25))
		_hair(c, box.position + Vector2(0, box.size.y), box.end, Color(1, 1, 1, 0.55) if not it.is_empty() else Color(1, 1, 1, 0.2))
		if not it.is_empty():
			var ico := UiSkin.icon(it["id"])
			if ico:
				c.draw_texture_rect(ico, box.grow(-1.0), false, Color(1, 1, 1, 0.9))
			else:
				_text(c, box.position + Vector2(2, 17), String(Game.ITEMS[it["id"]]["short"]).left(5), TEXT, 6)
		_text(c, box.position + Vector2(2, 7), QUICK[i][1], Color(1, 1, 1, 0.75), 7)
	var n := func(id: String) -> int:
		var k := 0
		for s in p.inv:
			if p.inv[s]["id"] == id:
				k += 1
		return k
	_text(c, o + Vector2(194, 11), "G %d  X %d" % [n.call("grenade"), n.call("smoke_grenade")], FRAME, 7)
	_text(c, o + Vector2(194, 21), "7 %d  H %d" % [n.call("flare"), n.call("medkit")], FRAME, 7)
	if Game.easy():
		_text(c, o + Vector2(4, -3), "I = výstroj", FRAME, 7)

## (0.66) The compass: S V J Z and the degrees, the landing site, the beacon of a rescue and where
## the last loud sound came from (a shot, a blast, a roar - what the soldier's ears heard, nothing more).
const LOUD_SECS := 8.0
func _compass(c: Control, r: Rect2, p: Node, marks: Array) -> void:
	_hair(c, Vector2(r.position.x, r.position.y + 12.5), Vector2(r.end.x, r.position.y + 12.5), Color(1, 1, 1, 0.35))
	var fwd: Vector3 = -p.global_transform.basis.z
	var head := atan2(fwd.x, -fwd.z)                 # 0 = north (-Z), clockwise
	var half := deg_to_rad(60.0)                     # the strip shows 120 degrees
	var cx := r.position.x + r.size.x / 2.0
	var px := (r.size.x / 2.0 - 6.0) / half
	var names := {0: "S", 90: "V", 180: "J", 270: "Z"}
	for d in range(0, 360, 15):
		var a := wrapf(deg_to_rad(d) - head, -PI, PI)
		if absf(a) > half:
			continue
		var x := cx + a * px
		if names.has(d):
			var s: String = names[d]
			_text(c, Vector2(x - 3, r.position.y + 12), s, ACCENT if d == 0 else TEXT, 9)
		else:
			_hair(c, Vector2(x, r.position.y + (6 if d % 45 == 0 else 9)), Vector2(x, r.position.y + 12.5), Color(1, 1, 1, 0.6))
	c.draw_line(Vector2(cx, r.position.y + 13), Vector2(cx, r.position.y + 17), ACCENT, 1.0)
	for m in marks:
		var to: Vector3 = m[0] - p.global_position
		var a := wrapf(atan2(to.x, -to.z) - head, -PI, PI)
		var x := cx + clampf(a, -half, half) * px
		var col: Color = m[1]
		var tip := Vector2(x, r.position.y + r.size.y - 1)
		c.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-3, -5), tip + Vector2(3, -5)]), col)
		if absf(a) < deg_to_rad(8.0):
			_text(c, Vector2(x - ThemeDB.fallback_font.get_string_size(m[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x / 2.0, r.end.y + 8), m[2], col, 7)

## One centred line of text on a plate (the objective, the end of the mission).
func _line_plate(c: Control, at: Vector2, s: String, col: Color, size := 9) -> void:
	var w := ThemeDB.fallback_font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	w = minf(w, c.size.x - 24.0)
	_plate(c, Rect2(at.x - w / 2.0 - 6, at.y - size - 2, w + 12, size + 7))
	var f := ThemeDB.fallback_font
	c.draw_string_outline(f, Vector2(at.x - w / 2.0, at.y), s, HORIZONTAL_ALIGNMENT_LEFT, w, size, 3, Color(0, 0, 0, 0.8))
	c.draw_string(f, Vector2(at.x - w / 2.0, at.y), s, HORIZONTAL_ALIGNMENT_LEFT, w, size, col)

## (0.66) "F - ..." and the like: all on the same plate, stacked under the crosshair.
var _prompts := []
func _prompt(s: String, col: Color, busy := false) -> void:
	if busy:
		_prompts.push_front([s, col])
	else:
		_prompts.append([s, col])

func _draw_prompts(c: Control, mid: Vector2) -> void:
	var y := mid.y + 46.0
	for pr in _prompts:
		_prompt_line(c, Vector2(mid.x, y), String(pr[0]), pr[1])
		y += 15.0

## A prompt "F - sebrat: Puška" drawn as [F] sebrat: Puška (several "key - action" parts on one line,
## split by four spaces, each get their key box).
func _prompt_line(c: Control, at: Vector2, s: String, col: Color) -> void:
	var f := ThemeDB.fallback_font
	var parts := []
	for chunk in s.split("    ", false):
		var k := ""
		var t := String(chunk)
		var i := t.find(" - ")
		if i > 0 and i <= 8 and not t.left(i).contains(" ") or (i > 0 and t.left(i).begins_with("Drž ")):
			k = t.left(i)
			t = t.substr(i + 3)
		parts.append([k, t])
	var w := 0.0
	for pt in parts:
		if pt[0] != "":
			w += f.get_string_size(pt[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 10.0
		w += f.get_string_size(pt[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 12.0
	w = minf(w - 12.0, c.size.x - 24.0)
	var x := at.x - w / 2.0
	_plate(c, Rect2(x - 4, at.y - 11, w + 8, 15))
	for pt in parts:
		if pt[0] != "":
			x += _key_chip(c, Vector2(x, at.y), pt[0], 8) + 4.0
		_text(c, Vector2(x, at.y), pt[1], col, 9)
		x += f.get_string_size(pt[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 12.0

## The message (msg_label) gets the same plate under it.
func _msg_plate(c: Control) -> void:
	var f := ThemeDB.fallback_font
	var sz := f.get_multiline_string_size(msg_label.text, HORIZONTAL_ALIGNMENT_CENTER, msg_label.size.x, 10)
	var w := minf(sz.x, msg_label.size.x)
	var lines := maxi(1, msg_label.get_line_count())
	var h := float(lines) * msg_label.get_line_height() + 4.0
	var cx := msg_label.position.x + msg_label.size.x / 2.0
	_plate(c, Rect2(cx - w / 2.0 - 8, msg_label.position.y - 2, w + 16, h))

## (0.66) Cards of the teammates top left: name, health, what is wrong. Hardcore: only who has
## fallen (as before, no health). Solo: the card of Strážce (the drone) - what it is doing.
func _cards(c: Control, p: Node) -> void:
	var y := 4.0
	var gd: Node = mission().guard_drone
	if gd != null and is_instance_valid(gd):
		_plate(c, Rect2(8, y + 2, 116, 18))
		_text(c, Vector2(10, y + 10), "Strážce", FRAME, 8)
		var st := "čeká, až se vzdálí" if gd._waiting else ("oživuje!" if gd._rescue_t > 0.0 else "hlídá")
		_text(c, Vector2(56, y + 10), st, ACCENT if gd._rescue_t > 0.0 else TEXT, 8)
		_text(c, Vector2(10, y + 19), "stimulant: %s" % ("připraven" if gd.charge > 0 else "spotřebován"), Color(0.5, 1.0, 0.55) if gd.charge > 0 else FRAME, 7)
		y += 25.0
	for o in mission().players():
		if o == p:
			continue
		if Game.veteran() and not (o.downed or o.dead):
			continue
		var bad: bool = o.downed or o.dead
		var st: String = "MRTEV" if o.dead else ("ODVLEČEN! %d s" % int(o.bleed_left) if o.downed and o.carried_by < 0 else ("PADL! %d s" % int(o.bleed_left) if o.downed else ("krvácí" if o.bleeding > 0 else "%d m" % int(p.global_position.distance_to(o.global_position)))))
		if Game.veteran():
			st = st.split(" ")[0]
		_plate(c, Rect2(8, y + 2, 116, 18))
		var nm: String = "Někdo z týmu" if Game.veteran() else String(o.display_name)
		_text(c, Vector2(10, y + 10), nm.left(16), RED if bad else TEXT, 8)
		_text(c, Vector2(122 - ThemeDB.fallback_font.get_string_size(st, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x, y + 10), st, UiSkin.BAD if bad else (ACCENT if st == "krvácí" else FRAME), 8)
		if not Game.veteran():
			var hb := Rect2(10, y + 15, 112, 2)
			c.draw_rect(hb, Color(1, 1, 1, 0.18))
			var hk := clampf(o.hp / o.max_hp, 0.0, 1.0)
			c.draw_rect(Rect2(hb.position, Vector2(hb.size.x * hk, hb.size.y)), UiSkin.BAD if bad or hk < 0.35 else (ACCENT if hk < 0.7 else Color(0.92, 0.94, 0.96)))
		y += 25.0
		if y > 120.0:
			break

## (0.66) Minimal HUD: the ammunition only as a guess, the way you feel the weight of the magazine.
static func ammo_guess(n: int, cap: int) -> String:
	if n <= 0:
		return "prázdný"
	var k := float(n) / maxf(1.0, float(cap))
	return "plný" if k >= 0.85 else ("víc než půl" if k >= 0.5 else ("pod půl" if k >= 0.2 else "skoro prázdný"))

func _hand_text(c: Control, p: Node, slot: String, at: Vector2) -> void:
	var it: Dictionary = p.item_in(slot)
	var label := "" if slot == "rh" else "Štít: "
	if it.is_empty():
		_text(c, at + Vector2(0, 12), label + "prázdné ruce", FRAME, 9)
		return
	var rule: Dictionary = Game.ITEMS[it["id"]]
	var mode := ("  ·  1×" if p.semi else "  ·  dávka") if rule.get("modes", false) else ""
	if rule.has("bursts"):
		mode = "  ·  %s" % p.burst_name(it)
	if rule.has("pulses"):
		mode = "  ·  %s" % ("dávka" if it.get("pulse", false) else "1×")
	if rule.has("ammo_alt"):
		mode = "  ·  %s" % Game.ITEMS[String(it.get("sel", rule["ammo"]))]["short"]
	_text(c, at, label + ((rule["short"] + " (neznámá)") if Game.alien_unknown(it["id"]) else rule["name"]) + mode, Color(0.80, 0.83, 0.86), 9)
	if rule["type"] == "weapon":
		var spare := 0
		for s in p.inv:
			if p.inv[s]["id"] == String(it.get("sel", rule["ammo"])):
				spare += int(p.inv[s].get("left", Game.ITEMS[p.inv[s]["id"]]["rounds"]))
		if rule.get("alien", false):
			_text(c, at + Vector2(0, 12), ("zásobník %s" % ammo_guess(int(it.get("loaded", 0)), Game.mag_size(it["id"]))) if Game.hud_min else "%d / %d   články %d" % [int(it.get("loaded", 0)), Game.mag_size(it["id"]), int(it.get("cells", 0))], ACCENT, 10)
		elif rule.get("laser", false):
			# the cell's readiness light (X-WEP-001): ready, or charging
			var cap := Game.mag_size(it["id"])
			if cap <= 1:
				var ready := int(it.get("loaded", 0)) >= 1
				_text(c, at + Vector2(0, 12), "článek připraven" if ready else "článek se nabíjí", ACCENT if ready else FRAME, 10)
				if not ready:
					# (0.57) the bar under the text, inside the panel (before, it ran out past its edge)
					c.draw_rect(Rect2(at + Vector2(0, 16), Vector2(90.0, 3)), Color(FRAME, 0.25))
					c.draw_rect(Rect2(at + Vector2(0, 16), Vector2(90.0 * clampf(float(it.get("charge", 0.0)), 0.0, 1.0), 3)), FRAME)
			else:
				_text(c, at + Vector2(0, 12), ("pulzy %s" % ammo_guess(int(it.get("loaded", 0)), cap)) if Game.hud_min else "%d / %d pulzů%s" % [int(it.get("loaded", 0)), cap, "   nabíjí se doplna" if it.get("drained", false) else ""], ACCENT, 10)
		else:
			if Game.hud_min:
				_text(c, at + Vector2(0, 12), "zásobník %s" % ammo_guess(int(it.get("loaded", 0)), Game.mag_size(it["id"])), ACCENT, 10)
			else:
				_ammo_big(c, at + Vector2(0, 14), int(it.get("loaded", 0)), Game.mag_size(it["id"]), spare)
	elif it.has("uses"):
		_text(c, at + Vector2(0, 12), "%dx" % int(it["uses"]), ACCENT, 10)
	elif it["id"] == "energo_nuz":
		# EN-01's small indicator light: the edge's charge, or that it is charging / switched off
		var e := int(it.get("edge", 3))
		_text(c, at + Vector2(0, 12), ("ostří nabíjí" if e <= 0 else ("ostří vypnuto" if it.get("edge_off", false) else "ostří aktivní " + "▮".repeat(e))), ACCENT if e > 0 and not it.get("edge_off", false) else FRAME, 10)
	elif it["id"] == "stun_baton" and Game.has_mod("stun_baton", "diagnostika", p.merc):
		_text(c, at + Vector2(0, 12), "energie %d / %d" % [int(it.get("energy", p.baton_cap())), p.baton_cap()], ACCENT, 10)

## 0.72: the rounds in the gun as one big number, the magazine and the spare ones small beside it.
func _ammo_big(c: Control, at: Vector2, n: int, cap: int, spare: int) -> void:
	var f := ThemeDB.fallback_font
	var big := str(n)
	var col := Color(1, 1, 1) if n > cap / 4 else (UiSkin.BAD if n == 0 else ACCENT)
	c.draw_string_outline(f, at + Vector2(0, 6), big, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 3, Color(0, 0, 0, 0.6))
	c.draw_string(f, at + Vector2(0, 6), big, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, col)
	var bw := f.get_string_size(big, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	_text(c, at + Vector2(bw + 3, 6), "/ %d" % cap, Color(0.80, 0.83, 0.86), 10)
	_text(c, at + Vector2(bw + 3, -4), "+%d" % spare, FRAME, 8)

# ---- motion scanner ----------------------------------------------------------------------
## Like a real motion tracker it shows only "something moves" - teammates too (until the
## helmet display, see scan_movers) -
## and a frightened mercenary sees things that are not there.
var SCAN_RANGE := 25.0
var _ping_t := 0.0
var _sting_cd := 20.0

func _scanner_update(delta: float) -> void:
	SCAN_RANGE = 35.0 if Game.has_research("detektor") else 25.0
	_scan_t -= delta
	_ping_t -= delta
	_sting_cd -= delta
	_scan_sweep = fmod(_scan_sweep + delta * 1.2, 1.0)
	for b in _blips:
		b["t"] -= delta
	_blips = _blips.filter(func(b): return b["t"] > 0)
	var p := me()
	if p == null:
		return
	_sting_check(p)
	if Game.veteran():
		_breath(delta, p)
	if not p.has_scanner():
		return
	# beep faster the closer the nearest movement is
	var near := 99.0
	for b in _blips:
		near = min(near, Vector2(b["pos"].x - p.global_position.x, b["pos"].z - p.global_position.z).length())
	_scan_near = near
	if near < SCAN_RANGE and _ping_t <= 0:
		_ping_t = lerpf(0.22, 1.4, near / SCAN_RANGE)
		if Game.scan_muted and not p.drone_radar():
			# (0.80 Ari) ztlumený: nepípá a nic neslyší ani okolí
			_beep_noise_cd = 2.0
		else:
			Game.play_ui(mission(), "scanner_close", -16 + (SCAN_RANGE - near) / 2.5)
		# (0.57, MD-01's entry) the beeping carries a few metres: what hunts by ear may hear it
		# (0.66: the drone's radar in solo is quiet - it sits in the drone, not in the hand)
		_beep_noise_cd -= _ping_t
		if _beep_noise_cd <= 0.0 and not p.drone_radar() and not Game.scan_muted:
			_beep_noise_cd = 2.0
			mission().noise(p.global_position, 6.0)
	if _scan_t > 0:
		return
	_scan_t = 0.5
	for a in scan_movers(p):
		var pos: Vector3 = a.global_position
		var last: Vector3 = _last_pos.get(a.name, pos)
		_last_pos[a.name] = pos
		if pos.distance_to(last) > 0.25 and pos.distance_to(p.global_position) < SCAN_RANGE:
			_blips.append({"pos": pos.snapped(Vector3(2.5, 1, 2.5)), "t": 1.4})
	# false echoes: wind in the wheat, animals - and fear; metal all round (works, their base) adds more
	var metal := 2.0 if String(Net.mission_params.get("biome", "")) == "industrial" or String(Net.mission_params.get("type", "")) in ["alienbase", "mars"] else 1.0
	if randf() < (0.015 if Game.has_research("detektor") else 0.03) * metal + p.stress / 100.0 * 0.2:
		var ang := randf() * TAU
		_blips.append({"pos": p.global_position + Vector3(cos(ang), 0, sin(ang)) * randf_range(6.0, SCAN_RANGE), "t": 1.0})

## What the detector reacts to. (2026-11-22 Ari) With the helmet display (research
## `detektor_opasek`) it is paired with the squad's own detectors and leaves them out:
## only civilians and aliens move on it. Without it, teammates too (MD-01 can't tell).
## The research comes from the mission's parameters, so in co-op it is the same for everyone.
func scan_movers(p: Node) -> Array:
	var m := mission()
	var out: Array = m.aliens() + m.civilians()
	if not scan_skips_allies():
		out += m.players()
	return out.filter(func(a): return a != p and not a.dead)

static func scan_skips_allies() -> bool:
	return Game.has_research("detektor_opasek")

## A musical sting the first time in a while you actually see one of them.
func _sting_check(p: Node) -> void:
	if _sting_cd > 0 or p.cam == null:
		return
	for a in mission().aliens():
		if a.dead: continue
		var to: Vector3 = a.global_position + Vector3(0, 0.9, 0)
		if to.distance_to(p.cam.global_position) > 26.0 or not p.cam.is_position_in_frustum(to):
			continue
		var q := PhysicsRayQueryParameters3D.create(p.cam.global_position, to, Game.WORLD)
		if p.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			_sting_cd = 45.0
			Game.play_ui(mission(), "sting", -4)
			return

var _scan_near := 99.0
var _beep_noise_cd := 0.0
func _draw_scanner(c: Control, center: Vector2, r: float, p: Node) -> void:
	c.draw_circle(center, r, Color(0, 0, 0, 0.42))
	c.draw_arc(center, r, 0, TAU, 48, Color(1, 1, 1, 0.45), -1.0)
	c.draw_arc(center, r * 0.66, 0, TAU, 40, Color(1, 1, 1, 0.14), -1.0)
	c.draw_arc(center, r * 0.33, 0, TAU, 28, Color(1, 1, 1, 0.14), -1.0)
	_hair(c, center, center + Vector2(0, -r), Color(1, 1, 1, 0.15))
	# the sweep line going round, a fading wake behind it (MD-01's green screen)
	var ang := _scan_sweep * TAU - PI / 2
	for k in 6:
		var a2 := ang - k * 0.09
		c.draw_line(center, center + Vector2(cos(a2), sin(a2)) * r, Color(ACCENT, 0.5 * (1.0 - k / 6.0)), -1.0)
	var inv_basis: Basis = p.global_transform.basis.inverse()
	for b in _blips:
		var local: Vector3 = inv_basis * (b["pos"] - p.global_position)
		var v := Vector2(local.x, local.z) / SCAN_RANGE * r
		if v.length() > r: continue
		c.draw_circle(center + v, 2.3, Color(UiSkin.ACC_HI, clampf(b["t"], 0, 1)))
	c.draw_circle(center, 1.5, Color(1, 1, 1))
	_text(c, center + Vector2(-r, r + 10), ("STRÁŽCE  " if p.drone_radar() else ("DETEKTOR (TICHO)  " if Game.scan_muted else "DETEKTOR  ")) + (("%d m" % int(snappedf(_scan_near, 2.0))) if _scan_near < SCAN_RANGE else "--"), FRAME, 8)

# ---- drawing helpers ---------------------------------------------------------------------
## (0.70+) Dead, watching a living teammate (scripts/spectator.gd): only who it is and the keys -
## nothing of his HUD, no aliens marked (hardcore).
func _spectator_hud(c: Control, sz: Vector2, sp: Node) -> void:
	if Game.hud_hidden:
		return
	var f := ThemeDB.fallback_font
	c.draw_rect(Rect2(0, 0, sz.x, 34), Color(0, 0, 0, 0.45))
	var t: Node = sp.target
	var st := "MRTEV" if t.dead else ("PADL" if t.downed else "")
	var who: String = "Sleduješ: %s%s" % [t.display_name, (" - " + st) if st != "" else ""]
	var a := "JSI MRTVÝ"
	_text(c, Vector2((sz.x - f.get_string_size(a, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x) / 2.0, 14), a, RED, 12)
	_text(c, Vector2((sz.x - f.get_string_size(who, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x) / 2.0, 28), who, ACCENT if st == "" else RED, 10)
	var n: int = Spectator.living(mission(), me()).size()
	var keys := ("LTM / PTM další (%d) · " % n if n > 1 else "") + ("Mezerník: za zády" if sp.eyes else "Mezerník: z očí · myš otáčí · kolečko blíž/dál")
	_text(c, Vector2((sz.x - f.get_string_size(keys, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x) / 2.0, sz.y - 8), keys, TEXT, 8)

func _text(c: Control, pos: Vector2, s: String, col: Color, size := 10) -> void:
	var f := ThemeDB.fallback_font
	c.draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color(0, 0, 0, 0.8))
	c.draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

## A small figure next to the bars: standing / crouched / prone / sprinting (or out of breath).
## Stealth eye: how open it is = how far you can be seen (stance, flashlight);
## its colour = how close the aliens are to spotting you.
func _eye_icon(c: Control, o: Vector2, p: Node) -> void:
	var box := Rect2(o, Vector2(34, 28))
	c.draw_rect(box, Color(0, 0, 0, 0.3))
	var w: float = p.watched
	var col := Color(0.45, 0.8, 0.5)
	var word := "NEVIDÍ TĚ"
	if w >= 1.0:
		col = RED
		word = "VIDÍ TĚ!"
	elif w >= 0.5:
		col = Color(1.0, 0.55, 0.15)
		word = "HLEDAJÍ TĚ"
	elif w > 0.05:
		col = ACCENT
		word = "NĚCO TUŠÍ"
	var open := clampf(p.visibility_range() / 40.0, 0.12, 1.0)
	var ctr := o + Vector2(17, 14)
	var pts := PackedVector2Array()
	for i in 17:
		var a := PI * i / 16.0
		pts.append(ctr + Vector2(-cos(a) * 13.0, -sin(a) * 9.0 * open))
	for i in 17:
		var a := PI * i / 16.0
		pts.append(ctr + Vector2(cos(a) * 13.0, sin(a) * 9.0 * open))
	c.draw_polyline(pts, col, 1.4)
	c.draw_circle(ctr, 3.5 * maxf(open, 0.4), col)
	_text(c, o + Vector2(38, 12), word, col, 8)
	c.draw_rect(Rect2(o.x + 38, o.y + 17, 50, 3), Color(0, 0, 0, 0.6))
	c.draw_rect(Rect2(o.x + 38, o.y + 17, 50 * clampf(w, 0.0, 1.0), 3), col)

## A plate of the menus' dark metal behind a group of the HUD (UiSkin's inset panel).
## (2026-11-17) Drops and mist on the sight's glass (Mission.wx: only what the eye would see there).
func _lens_fx(c: CanvasItem, mid: Vector2, p: Node, r: float) -> void:
	var m := get_parent()
	if m and "wx" in m and m.wx and p == m.local_player():
		m.wx.draw_lens(c, mid, r)

## (0.57) Over the scope's picture (the player draws it, under the night-vision filter): a dark
## rim, thin crosshairs with a chevron at the centre.
func _scope_picture(c: CanvasItem, mid: Vector2, p: Node) -> void:
	var r: float = p.scope_r
	if p.scope_texture() == null or r < 4.0:
		return
	c.draw_arc(mid, r - 1.5, 0, TAU, 48, Color(0, 0, 0, 0.85), 3.0)
	c.draw_arc(mid, r * 0.93, 0, TAU, 48, Color(0, 0, 0, 0.25), r * 0.1)
	var cc := Color(0.02, 0.02, 0.02, 0.9)
	c.draw_line(mid - Vector2(r, 0), mid - Vector2(r * 0.18, 0), cc, 1.0)
	c.draw_line(mid + Vector2(r * 0.18, 0), mid + Vector2(r, 0), cc, 1.0)
	c.draw_line(mid + Vector2(0, r * 0.18), mid + Vector2(0, r), cc, 1.0)
	c.draw_line(mid + Vector2(-3, 3), mid, Color(0.9, 0.2, 0.1), 1.0)
	c.draw_line(mid + Vector2(3, 3), mid, Color(0.9, 0.2, 0.1), 1.0)

## 0.72 (Čistý taktický): no plate - a soft dark shade behind a group, fading out at its edges,
## so the text reads over a bright sky and nothing looks like a box.
static var _shade: StyleBoxTexture
func _plate(c: Control, rect: Rect2) -> void:
	if _shade == null:
		var n := 48
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var d := minf(minf(x, n - 1 - x), minf(y, n - 1 - y)) / 16.0      # 0 at the edge, 1 inside
				var a := clampf(d, 0.0, 1.0)
				img.set_pixel(x, y, Color(0, 0, 0, a * a * (3.0 - 2.0 * a) * 0.42))
		_shade = StyleBoxTexture.new()
		_shade.texture = ImageTexture.create_from_image(img)
		_shade.set_texture_margin_all(16)
	_shade.draw(c.get_canvas_item(), rect.grow(7.0))

## One screen pixel thick line (the canvas is 640x360 stretched up).
func _hair(c: Control, a: Vector2, b: Vector2, col: Color) -> void:
	c.draw_line(a, b, col, -1.0)

## A key in a thin box, then what it does: [F] táhnout Míšu.
func _key_chip(c: Control, at: Vector2, key: String, size := 8) -> float:
	var f := ThemeDB.fallback_font
	var kw := f.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 6.0
	var r := Rect2(at + Vector2(0, -size - 1), Vector2(kw, size + 4))
	c.draw_rect(r, Color(0, 0, 0, 0.45))
	c.draw_rect(r, Color(1, 1, 1, 0.7), false, -1.0)
	c.draw_string(f, at + Vector2(3, 0), key, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 1, 1))
	return kw

## 0.57: our mercenary's own figure (tools/stance_icons.gd: merc.glb in the game's movements, white).
const STANCE_TEX := {"stand": "stance_stand", "crouch": "stance_crouch", "prone": "stance_prone", "sprint": "stance_sprint",
	"downed": "stance_downed", "winded": "stance_winded"}
func _stance_icon(c: Control, o: Vector2, p: Node) -> void:
	var box := Rect2(o, Vector2(34, 34))
	var key := "stand"
	if p.downed:
		key = "downed"
	elif p.prone:
		key = "prone"
	elif p.crouching:
		key = "crouch"
	elif p.sprinting:
		key = "sprint"
	elif p._winded:
		key = "winded"
	var tex := UiSkin.icon(STANCE_TEX[key])
	if tex:
		var col2 := TEXT
		if p.sprinting:
			col2 = ACCENT
		if p._winded:
			col2 = Color(0.55, 0.65, 0.9)
		if p.downed:
			col2 = RED
		c.draw_texture_rect(tex, Rect2(o + Vector2(1, 1), Vector2(32, 32)), false, col2)
		var w2 := "STOJÍŠ"
		match key:
			"downed": w2 = "PADL JSI"
			"prone": w2 = "LEŽÍŠ"
			"crouch": w2 = "KLEČÍŠ"
			"sprint": w2 = "SPRINT"
			"winded": w2 = "BEZ DECHU"
		_text(c, o + Vector2(38, 30), w2, col2, 8)
		return
	var col := TEXT
	var word := "STOJÍŠ"
	if p.prone:
		word = "LEŽÍŠ"
	elif p.crouching:
		word = "KLEČÍŠ"
	elif p.sprinting:
		word = "SPRINT"
		col = ACCENT
	if p._winded:
		col = Color(0.55, 0.65, 0.9)
		if not p.prone and not p.crouching:
			word = "BEZ DECHU"
	var w := 1.6
	if p.prone:
		# lying flat, head to the right, rifle forward
		var y := o.y + 26
		c.draw_circle(Vector2(o.x + 27, y - 3), 3.0, col)
		c.draw_line(Vector2(o.x + 6, y), Vector2(o.x + 24, y - 1), col, w + 0.6)
		c.draw_line(Vector2(o.x + 6, y), Vector2(o.x + 2, y + 2), col, w)
		c.draw_line(Vector2(o.x + 20, y), Vector2(o.x + 31, y + 2), col, w)
	elif p.crouching:
		# kneeling: one knee down
		var hx := o.x + 17
		c.draw_circle(Vector2(hx + 1, o.y + 9), 3.0, col)
		c.draw_line(Vector2(hx, o.y + 12), Vector2(hx - 1, o.y + 21), col, w + 0.6)        # torso
		c.draw_line(Vector2(hx - 1, o.y + 21), Vector2(hx + 6, o.y + 22), col, w)          # thigh forward
		c.draw_line(Vector2(hx + 6, o.y + 22), Vector2(hx + 6, o.y + 29), col, w)          # shin down
		c.draw_line(Vector2(hx - 1, o.y + 21), Vector2(hx - 5, o.y + 29), col, w)          # knee down
		c.draw_line(Vector2(hx - 5, o.y + 29), Vector2(hx - 10, o.y + 29), col, w)
		c.draw_line(Vector2(hx, o.y + 14), Vector2(hx + 8, o.y + 15), col, w)              # arms forward
	elif p.sprinting:
		var hx2 := o.x + 18
		c.draw_circle(Vector2(hx2 + 3, o.y + 7), 3.0, col)
		c.draw_line(Vector2(hx2 + 2, o.y + 10), Vector2(hx2 - 2, o.y + 19), col, w + 0.6)
		c.draw_line(Vector2(hx2 - 2, o.y + 19), Vector2(hx2 + 6, o.y + 24), col, w)
		c.draw_line(Vector2(hx2 + 6, o.y + 24), Vector2(hx2 + 4, o.y + 30), col, w)
		c.draw_line(Vector2(hx2 - 2, o.y + 19), Vector2(hx2 - 8, o.y + 25), col, w)
		c.draw_line(Vector2(hx2 - 8, o.y + 25), Vector2(hx2 - 12, o.y + 23), col, w)
		c.draw_line(Vector2(hx2 + 1, o.y + 12), Vector2(hx2 + 7, o.y + 16), col, w)
		c.draw_line(Vector2(hx2 + 1, o.y + 12), Vector2(hx2 - 6, o.y + 15), col, w)
	else:
		var hx3 := o.x + 17
		c.draw_circle(Vector2(hx3, o.y + 6), 3.0, col)
		c.draw_line(Vector2(hx3, o.y + 9), Vector2(hx3, o.y + 19), col, w + 0.6)
		c.draw_line(Vector2(hx3, o.y + 19), Vector2(hx3 - 3, o.y + 30), col, w)
		c.draw_line(Vector2(hx3, o.y + 19), Vector2(hx3 + 3, o.y + 30), col, w)
		c.draw_line(Vector2(hx3, o.y + 11), Vector2(hx3 + 7, o.y + 14), col, w)
		c.draw_line(Vector2(hx3, o.y + 11), Vector2(hx3 - 4, o.y + 17), col, w)
	_text(c, o + Vector2(38, 30), word, col, 8)

func _bar(c: Control, pos: Vector2, label: String, v: float, col: Color) -> void:
	_text(c, pos + Vector2(0, 8), label.capitalize() if label == label.to_upper() else label, Color(0.80, 0.83, 0.86), 8)
	var r := Rect2(pos + Vector2(42, 4), Vector2(70, 2))
	c.draw_rect(r, Color(1, 1, 1, 0.18))
	c.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(v, 0, 1), r.size.y)), col)
	if not Game.hud_min:
		var n := str(int(round(clampf(v, 0, 1) * 100.0)))
		_text(c, pos + Vector2(128 - ThemeDB.fallback_font.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x, 8), n, Color(0.80, 0.83, 0.86), 8)

func _panel(title: String, pos: Vector2, min_size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiSkin.panel(8))
	p.position = pos
	p.custom_minimum_size = min_size
	add_child(p)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	p.add_child(box)
	var t := _lbl(box, title, ACCENT, 14)
	UiSkin.title(t, 13)
	return p

func _lbl(parent: Node, s: String, col := TEXT, size := 10) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	parent.add_child(l)
	return l

func _btn(parent: Node, s: String, cb: Callable, min_size := Vector2.ZERO) -> Button:
	var b := Button.new()
	b.text = s
	b.custom_minimum_size = min_size
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 9)
	UiSkin.auto(b)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

# ---- inventory (UFO style: hands, belt, backpack) -----------------------------------------
var inv_keys: Label
const SLOT_KEY := {"rh": "LTM", "lh": "štít", "back": "1", "side": "2", "b0": "3", "b1": "4", "b2": "5", "b3": "6"}
func _build_inventory() -> void:
	# 0.72 (návrh A): a full screen - hands, weapons and belt left, the backpack and the keys right
	inv_panel = PanelContainer.new()
	inv_panel.name = "Inventory"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UiSkin.BG.r, UiSkin.BG.g, UiSkin.BG.b, 0.84)
	inv_panel.add_theme_stylebox_override("panel", sb)
	inv_panel.position = Vector2.ZERO
	inv_panel.size = Vector2(640, 360)
	inv_panel.custom_minimum_size = Vector2(640, 360)
	add_child(inv_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	inv_panel.add_child(v)
	var cm := MarginContainer.new()
	for k in [["left", 14], ["right", 14], ["top", 8], ["bottom", 6]]:
		cm.add_theme_constant_override("margin_" + k[0], k[1])
	v.add_child(cm)
	var nm := "voják"
	if me():
		nm = String(me().display_name)
	var cb := UiSkin.crumb(["Výstroj", nm], "")
	_inv_status = cb.get_node("Status")
	_inv_crumb = cb.get_node("Crumb")
	cm.add_child(cb)
	var mg := MarginContainer.new()
	mg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for k in [["left", 14], ["right", 14], ["top", 2], ["bottom", 6]]:
		mg.add_theme_constant_override("margin_" + k[0], k[1])
	v.add_child(mg)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	mg.add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 3)
	left.custom_minimum_size = Vector2(296, 0)
	cols.add_child(left)
	_inv_left = left
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 3)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	_inv_right = right
	var groups := [[left, "V rukou · LTM použít, PTM mířit", ["rh", "lh"], 2, Vector2(146, 46)],
		[left, "Zbraně · kolečko přepíná", ["back", "side"], 2, Vector2(146, 36)],
		[left, "Opasek · rychle (3 4 5 6)", ["b0", "b1", "b2", "b3"], 4, Vector2(71, 32)],
		[right, "Batoh · pomalu, stojíš a hrabeš se", Game.pack_slots(), 3, Vector2(97, 30)]]
	var names := {"rh": "v rukou - jedna věc, zbraň oběma rukama", "lh": "štít (jen s jednoruční zbraní)", "back": "primární zbraň (klávesa 1)", "side": "sekundární zbraň - pistole, revolver, nůž (klávesa 2)"}
	for g in groups:
		var gl := _lbl(g[0], g[1], UiSkin.ACC if g[0] == left else UiSkin.DIM, 7)
		UiSkin.eyebrow(gl, UiSkin.DIM, 7)
		gl.autowrap_mode = TextServer.AUTOWRAP_OFF
		var row := GridContainer.new()
		row.columns = g[3]
		row.add_theme_constant_override("h_separation", 4)
		row.add_theme_constant_override("v_separation", 4)
		g[0].add_child(row)
		for sl in g[2]:
			var slot: String = sl
			inv_buttons[slot] = _btn(row, "", func(): _slot_clicked(slot), g[4] if g[2].size() < 9 else Vector2(97, 26))
			inv_buttons[slot].tooltip_text = names.get(slot, "")
		if g[0] == left:
			var sp := Control.new()
			sp.custom_minimum_size = Vector2(0, 3)
			left.add_child(sp)
	inv_info = _lbl(left, "", TEXT, 8)
	inv_info.custom_minimum_size = Vector2(296, 0)
	var db := _btn(left, "Zahodit věc z ruky", func():
		var pp := me()
		if pp and held_slot != "":
			pp.drop_slot(held_slot)
			held_slot = "", Vector2(120, 16))
	UiSkin.ghost(db)
	db.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	# the weight under the backpack
	var wr := HBoxContainer.new()
	wr.add_theme_constant_override("separation", 6)
	right.add_child(wr)
	var wl := _lbl(wr, "Váha", UiSkin.DIM, 7)
	UiSkin.eyebrow(wl, UiSkin.DIM, 7)
	wl.autowrap_mode = TextServer.AUTOWRAP_OFF
	_inv_wbar = ProgressBar.new()
	_inv_wbar.show_percentage = false
	_inv_wbar.custom_minimum_size = Vector2(0, 3)
	_inv_wbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inv_wbar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.08)
	_inv_wbar.add_theme_stylebox_override("background", bg)
	wr.add_child(_inv_wbar)
	_inv_wnum = _lbl(wr, "", UiSkin.DIM, 7)
	_inv_wnum.autowrap_mode = TextServer.AUTOWRAP_OFF
	var hint := _lbl(right, "Přetáhni věc (nebo klikni na ni a pak na místo), kam ji dát. Puštěná mimo políčka spadne před tebe. Z batohu to trvá a stojíš.", UiSkin.DIM, 7)
	hint.custom_minimum_size = Vector2(290, 0)
	# right: every key and what it does with what you carry right now
	var kh := _lbl(right, "Klávesy", UiSkin.DIM, 7)
	UiSkin.eyebrow(kh, UiSkin.DIM, 7)
	var ks := ScrollContainer.new()
	ks.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ks.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ks.custom_minimum_size = Vector2(0, 40)
	right.add_child(ks)
	inv_keys = _lbl(ks, "", Color(0.80, 0.83, 0.86), 7)
	inv_keys.custom_minimum_size = Vector2(286, 0)
	v.add_child(UiSkin.key_bar([["I", "zavřít"], ["Backspace", "zahodit z ruky"], ["LTM", "vzít / položit"]]))
	inv_panel.visible = false

var _inv_status: Label
var _inv_crumb: RichTextLabel
var _inv_left: Control
var _inv_right: Control
var _inv_wbar: ProgressBar
var _inv_wnum: Label

## The key list: what each key does with the current gear (and where the thing is).
func _keys_text(p: Node) -> String:
	var where := func(id: String) -> String:
		var sl: String = p.find_item(func(it): return it["id"] == id)
		if sl == "":
			return "nemáš"
		var n := 0
		for s2 in p.inv:
			if p.inv[s2]["id"] == id:
				n += 1
		return ("%dx, " % n if n > 1 else "") + ("v rukou" if sl in ["rh", "lh"] else ("opasek" if sl.begins_with("b") else ("pouzdro" if sl in ["back", "side"] else "batoh - pomalu")))
	var hand := func(sl: String) -> String:
		var it: Dictionary = p.item_in(sl)
		return "-" if it.is_empty() else Game.ITEMS[it["id"]]["short"]
	var melee: String = p.find_item(func(it): return it["id"] in ["knife", "energo_nuz"])
	if melee == "":
		melee = p.find_item(func(it): return Game.ITEMS[it["id"]]["type"] == "melee")
	# 0.72: the keys as the player set them (Nastavení > Ovládání)
	var k := func(a: String) -> String: return Game.key_name(a)
	var lines := [
		"LTM  použít / střílet: %s" % hand.call("rh"),
		"PTM  mířit (zbraň oběma rukama)",
		k.call("reload") + "    nabít zbraň / zapnout ostří energo nože",
		k.call("primary") + "    primární zbraň (%s)" % hand.call("back") if p.item_in("rh").get("home", "") != "back" else k.call("primary") + "    primární zbraň - znovu ji uklidí",
		k.call("secondary") + "    sekundární zbraň (%s)" % hand.call("side") if p.item_in("rh").get("home", "") != "side" else k.call("secondary") + "    sekundární zbraň - znovu ji uklidí",
		"Kolečko  primární do rukou / znovu: zpět, co jsi držel",
		"%s %s %s %s  věc z opasku do rukou / nabít" % [k.call("belt1"), k.call("belt2"), k.call("belt3"), k.call("belt4")],
		"%s granát z opasku (%d výbušné)   %s kouřový %d   %s Claymore %d   %s světlice %d" % [k.call("grenade"), p.inv.values().filter(func(it): return it["id"] == "grenade").size(), k.call("smoke"), p.inv.values().filter(func(it): return it["id"] == "smoke_grenade").size(), k.call("mine"), p.inv.values().filter(func(it): return it["id"] == "mine").size(), k.call("flare"), p.inv.values().filter(func(it): return it["id"] == "flare").size()],
		k.call("drop") + "  zahodit, co máš v ruce",
		k.call("heal") + "    lékárnička - do rukou, pak ošetří (%s)" % where.call("medkit"),
		k.call("use") + "    táhnout padlého / sebrat / civilista / dveře",
		k.call("ready") + "  v lodi: připraven (start mise i odlet)",
		k.call("melee") + "    rána zblízka (%s)" % ("pažbou zbraně" if melee == "" else Game.ITEMS[p.inv[melee]["id"]]["short"]),
		k.call("flashlight") + "    svítilna (na helmě, zapnutá od začátku)",
		k.call("nvg") + "    noktovizor / přísvit (%s)" % where.call("nvg"),
		k.call("firemode") + "    dávky / jednotlivé rány, délka dávky, druh nábojů",
		k.call("talk") + "    držet = mluvit (nahlas, kdo je blízko)",
		k.call("mic_toggle") + "    mikrofon stále zapnutý / vypnout (%s)" % ("ZAPNUTO" if Game.mic_live else "vypnuto"),
		"" if p.drone_radar() else k.call("radio_talk") + "  držet = vysílačka (%s)" % ("helma" if Game.has_research("vysilacky") else where.call("radio")),
		"%s  kleknout   %s  lehnout   %s  sprint   %s / %s  držet = náklon za roh" % [k.call("crouch"), k.call("prone"), k.call("sprint"), k.call("lean_left"), k.call("lean_right")],
	]
	return "\n".join(lines.filter(func(x): return x != ""))

func _open_inventory() -> void:
	inventory_open = true
	held_slot = ""
	inv_panel.visible = true
	if _inv_crumb and me():
		var tmp := UiSkin.crumb(["Výstroj", String(me().display_name)])
		_inv_crumb.text = (tmp.get_node("Crumb") as RichTextLabel).text
		tmp.free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_inventory()

## Back from a menu into the game: the click that closed it must not fire the gun
## (the player waits until the button is let go, and a moment more).
var fire_block_until := 0
func _back_to_game() -> void:
	fire_block_until = Time.get_ticks_msec() + 350

func _close_inventory() -> void:
	_back_to_game()
	inventory_open = false
	held_slot = ""
	inv_panel.visible = false
	if not paused and not mission().finished:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _slot_clicked(slot: String) -> void:
	var p := me()
	if p == null: return
	if _dragged:
		_dragged = false
		return
	if held_slot == "":
		if p.inv.has(slot):
			held_slot = slot
		return
	if held_slot != slot and p.busy <= 0:
		p.timed_move(held_slot, slot)
	held_slot = ""

## Drag and drop in the inventory: press on a thing, let go over another place - or outside
## the window, and the thing lands on the ground in front of you.
var _drag_from := ""
var _drag_start := Vector2.ZERO
var _dragged := false
func _input(event: InputEvent) -> void:
	# the window lost the mouse (alt-tab...): a click only takes it back, it does not shoot
	if event is InputEventMouseButton and event.pressed and not inventory_open and not paused and not is_instance_valid(_screen) \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not mission().finished and Game.autotest() == "":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_back_to_game()
		return
	if not inventory_open or not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var p := me()
	if p == null:
		return
	var mp: Vector2 = event.position
	if event.pressed:
		_drag_from = ""
		for sl in inv_buttons:
			if (inv_buttons[sl] as Control).get_global_rect().has_point(mp) and p.inv.has(sl):
				_drag_from = sl
				_drag_start = mp
		return
	if _drag_from == "" or mp.distance_to(_drag_start) < 10.0:
		_drag_from = ""
		return
	var target := ""
	for sl in inv_buttons:
		if (inv_buttons[sl] as Control).get_global_rect().has_point(mp):
			target = sl
	if target != "" and target != _drag_from and p.busy <= 0:
		p.timed_move(_drag_from, target)
		_dragged = true
	elif target == "" and not _inv_left.get_global_rect().has_point(mp) and not _inv_right.get_global_rect().has_point(mp):
		p.drop_slot(_drag_from)
	held_slot = ""
	_drag_from = ""

func _refresh_inventory() -> void:
	var p := me()
	if p == null: return
	for s in inv_buttons:
		var b: Button = inv_buttons[s]
		var it: Dictionary = p.item_in(s)
		var key: String = SLOT_KEY.get(s, "")
		var two_h := Game.two_handed(p.item_in("rh").get("id", ""))
		if s == "rh": key = "LTM"
		var cnt := ""
		if not it.is_empty():
			if it.has("loaded"): cnt = "%d/%d" % [int(it["loaded"]), Game.mag_size(it["id"])]
			elif it.has("uses"): cnt = "%dx" % int(it["uses"])
		UiSkin.item_tile(b, it.get("id", ""), "(prázdné)" if it.is_empty() else Game.ITEMS[it["id"]]["short"], key, cnt)
		b.modulate = Color(1.6, 1.4, 0.6) if s == held_slot else Color(1, 1, 1)
	var w: int = p.carried_weight()
	var cap := int(p.merc.get("strength", 30))
	inv_info.text = "PŘETÍŽEN - pomalejší pohyb" if w > cap else ""
	if held_slot != "":
		inv_info.text += ("   " if inv_info.text != "" else "") + "Vybráno: " + Game.ITEMS[p.inv[held_slot]["id"]]["name"]
	inv_info.add_theme_color_override("font_color", RED if w > cap else TEXT)
	if _inv_status:
		_inv_status.text = ("Váha %d / %d kg" % [w, cap]).to_upper()
		_inv_status.add_theme_color_override("font_color", UiSkin.BAD if w > cap else UiSkin.DIM)
		_inv_wbar.max_value = maxf(cap, 1)
		_inv_wbar.value = mini(w, cap)
		var fs := StyleBoxFlat.new()
		fs.bg_color = UiSkin.BAD if w > cap else TEXT
		_inv_wbar.add_theme_stylebox_override("fill", fs)
		_inv_wnum.text = "%d / %d" % [w, cap]
	if inv_keys:
		inv_keys.text = _keys_text(p)

# ---- pause -----------------------------------------------------------------------------------
func _build_pause() -> void:
	# 0.72 (návrh A): celá obrazovka - hra ztmavená za ní, vlevo seznam, vpravo mise a tým / nastavení
	pause_panel = PanelContainer.new()
	pause_panel.name = "Pause"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UiSkin.BG.r, UiSkin.BG.g, UiSkin.BG.b, 0.78)
	pause_panel.add_theme_stylebox_override("panel", sb)
	pause_panel.position = Vector2.ZERO
	pause_panel.size = Vector2(640, 360)
	pause_panel.custom_minimum_size = Vector2(640, 360)
	add_child(pause_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	pause_panel.add_child(v)
	var mg := MarginContainer.new()
	mg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for k in [["left", 40], ["right", 30], ["top", 50], ["bottom", 10]]:
		mg.add_theme_constant_override("margin_" + k[0], k[1])
	v.add_child(mg)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 28)
	mg.add_child(cols)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(140, 0)
	left.add_theme_constant_override("separation", 2)
	cols.add_child(left)
	var t := _lbl(left, "Pauza", TEXT, 20)
	UiSkin.headline(t, 20)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	var e := _lbl(left, "Hra běží dál", UiSkin.ACC, 7)
	UiSkin.eyebrow(e, UiSkin.ACC, 7)
	e.autowrap_mode = TextServer.AUTOWRAP_OFF
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 16)
	left.add_child(gap)
	_pause_rows = {}
	_pause_row(left, "go", "Pokračovat", _resume)
	_pause_row(left, "set", "Nastavení", func(): _pause_page("set"))
	_pause_row(left, "keys", "Ovládání", func(): _pause_page("keys"))
	_pause_row(left, "voice", "Hlas a mikrofon", func(): _pause_page("voice"))
	# (0.7x) down in one's own base, co-op: the host may be waiting for the team on the globe
	if mission().local() and Net.is_online():
		_ready_pbtn = _pause_row(left, "ready", "", func():
			Net.set_ready(not Net.is_ready(Net.my_id()))
			_ready_ptext.call_deferred())
		Net.ready_changed.connect(_ready_ptext)
		_ready_ptext()
	_leave_btn = _pause_row(left, "leave", _leave_text(), _leave_pressed)
	_leave_btn.add_theme_color_override("font_color", UiSkin.BAD)
	_leave_btn.add_theme_color_override("font_hover_color", UiSkin.BAD.lightened(0.2))
	# (0.57) hardcore: walking out of a real mission is its failure - the first press only warns
	_leave_warn = _lbl(left, "", RED, 7)
	_leave_warn.custom_minimum_size = Vector2(140, 0)
	_leave_warn.visible = false
	_pause_right = VBoxContainer.new()
	_pause_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pause_right.add_theme_constant_override("separation", 3)
	cols.add_child(_pause_right)
	v.add_child(UiSkin.key_bar([["Esc", "pokračovat"], ["LTM", "vybrat"]]))
	pause_panel.visible = false

var _pause_rows := {}
var _pause_right: VBoxContainer
var _pause_on := "info"
func _pause_row(parent: Node, key: String, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	b.custom_minimum_size = Vector2(140, 18)
	b.add_theme_font_size_override("font_size", 9)
	UiSkin.row(b, key == "go")
	b.pressed.connect(cb)
	parent.add_child(b)
	_pause_rows[key] = b
	return b

## The right half of the pause: what goes on and who is where (info), or one page of the settings.
func _pause_page(page: String) -> void:
	_pause_on = page
	for k in _pause_rows:
		var b: Button = _pause_rows[k]
		var col = b.get_theme_color("font_color") if b.has_theme_color_override("font_color") else null
		UiSkin.row(b, k == page or (page == "info" and k == "go"))
		if col != null:
			b.add_theme_color_override("font_color", col)
	for c in _pause_right.get_children():
		_pause_right.remove_child(c)
		c.queue_free()
	if page == "info":
		var mp: Dictionary = Net.mission_params
		var m := mission()
		var parts: Array = [String(mp.get("type_name", "Mise"))]
		if String(mp.get("place", "")) != "":
			parts.append(String(mp["place"]))
		if mp.has("hour"):
			var h := float(mp["hour"])
			parts.append("%02d:%02d" % [int(h), int(fmod(h, 1.0) * 60)])
		var eb := _lbl(_pause_right, " · ".join(parts), UiSkin.ACC, 7)
		UiSkin.eyebrow(eb, UiSkin.ACC, 7)
		var hl := _lbl(_pause_right, "Na základně" if m and m.home() else "Vetřelci nečekají", TEXT, 14)
		UiSkin.headline(hl, 14)
		var tx := _lbl(_pause_right, "Pauza hru nezastaví. Tvůj voják zůstává na místě a dál ho mohou trefit." if not (m and m.home()) else "Pauza hru nezastaví. Na základně je klid.", UiSkin.DIM, 8)
		tx.custom_minimum_size = Vector2(300, 0)
		var me_p := me()
		var mates := []
		if m:
			for o in m.players():
				if o != me_p:
					mates.append(o)
		if not mates.is_empty():
			var sp := Control.new()
			sp.custom_minimum_size = Vector2(0, 8)
			_pause_right.add_child(sp)
			var th := _lbl(_pause_right, "Tým", UiSkin.DIM, 7)
			UiSkin.eyebrow(th, UiSkin.DIM, 7)
			for o in mates:
				var bad: bool = o.downed or o.dead
				if Game.veteran() and not bad:
					continue
				var st: String = "mrtev" if o.dead else ("padl %d s" % int(o.bleed_left) if o.downed else ("krvácí" if o.bleeding > 0 else ("%d m" % int(me_p.global_position.distance_to(o.global_position)) if me_p else "")))
				if Game.veteran():
					st = st.split(" ")[0]
				var row := PanelContainer.new()
				row.add_theme_stylebox_override("panel", UiBox.make(Color(1, 1, 1, 0.025), UiSkin.LINE, 8, Vector4(6, 2, 6, 2)))
				_pause_right.add_child(row)
				var hb := HBoxContainer.new()
				row.add_child(hb)
				var n := _lbl(hb, "Někdo z týmu" if Game.veteran() else String(o.display_name), TEXT, 8)
				n.autowrap_mode = TextServer.AUTOWRAP_OFF
				n.clip_text = true
				n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var sl := _lbl(hb, st, UiSkin.BAD if bad else (UiSkin.ACC if st == "krvácí" else UiSkin.OK), 8)
				sl.autowrap_mode = TextServer.AUTOWRAP_OFF
		return
	var hl2 := _lbl(_pause_right, {"set": "Nastavení", "keys": "Ovládání", "voice": "Hlas a mikrofon"}[page], TEXT, 14)
	UiSkin.headline(hl2, 14)
	settings_tab = {"set": settings_tab if settings_tab in ["ctl", "snd", "gfx"] else "ctl", "keys": "keys", "voice": "voice"}[page]
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, 240)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pause_right.add_child(sc)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(box)
	settings_ui(box)

var _ready_pbtn: Button
func _ready_ptext() -> void:
	if _ready_pbtn:
		var on := Net.is_ready(Net.my_id())
		_ready_pbtn.text = ("[X] PŘIPRAVEN" if on else "[  ] PŘIPRAVEN") + (" - hostitel čeká: " + Net.ready_wait if Net.ready_wait != "" else "")

## (0.7x) The walk round the base is no mission: the button just takes the lift up.
func _leave_text() -> String:
	var m := mission()
	return "Zpět na glóbus" if m and (m.home() or m.local()) else "Opustit misi"

var _leave_btn: Button
var _leave_warn: Label
var _leave_armed := false
func _leave_pressed() -> void:
	var m := mission()
	if _leave_armed or m.finished or m.home() or m.local():
		m.leave_from_menu()
		return
	_leave_armed = true
	var glob := " a zmizí z globu" if Net.mission_params.has("cid") else ""
	if multiplayer.is_server() and m.players().size() > 1:
		_leave_warn.text = "Jsi hostitel: mise skončí NEÚSPĚCHEM pro celý tým%s. Kdo nestojí u místa výsadku, zůstane na místě (nezvěstný)." % glob
	elif multiplayer.is_server():
		_leave_warn.text = "Mise skončí NEÚSPĚCHEM%s. Pokud nestojíš u místa výsadku, voják zůstane na místě (nezvěstný)." % glob
	else:
		_leave_warn.text = "Odejdeš z mise sám, tým pokračuje. Pokud nestojíš u místa výsadku, tvůj voják zůstane na místě (nezvěstný)."
	_leave_warn.visible = true
	_leave_btn.text = "Opravdu opustit misi"

## Mouse sensitivity, invert, field of view - shared by the pause menu and main menu.
## 0.72: the settings in tabs (Ovládání, Klávesy, Zvuk, Hlas, Grafika) instead of one long list.
## The last tab stays chosen for the next time (menu, pause, globe).
static var settings_tab := "ctl"
const SETTINGS_TABS := [["ctl", "Ovládání"], ["keys", "Klávesy"], ["snd", "Zvuk"], ["voice", "Hlas"], ["gfx", "Grafika"]]
static func _settings_pages(box: Control) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	box.add_child(row)
	var pages := {}
	var tabs := {}
	var show := func(k: String) -> void:
		settings_tab = k
		for kk in pages:
			(pages[kk] as Control).visible = kk == k
			UiSkin.row(tabs[kk], kk == k)
			(tabs[kk] as Button).alignment = HORIZONTAL_ALIGNMENT_CENTER
	for t in SETTINGS_TABS:
		var k: String = t[0]
		var b := Button.new()
		b.text = t[1]
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 9)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
		tabs[k] = b
		var v := VBoxContainer.new()
		v.name = "Tab_" + k
		v.add_theme_constant_override("separation", 3)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(v)
		pages[k] = v
	for k in tabs:
		var kk: String = k
		(tabs[k] as Button).pressed.connect(func(): show.call(kk))
	show.call(settings_tab if pages.has(settings_tab) else "ctl")
	return pages

static func settings_ui(box: Control) -> void:
	var pg := _settings_pages(box)
	var mk := func(into: Control, text: String, mn: float, mx: float, step: float, val: float, cb: Callable) -> void:
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 9)
		l.add_theme_color_override("font_color", Color(0.80, 0.83, 0.86))
		into.add_child(l)
		var sl := HSlider.new()
		sl.min_value = mn; sl.max_value = mx; sl.step = step; sl.value = val
		sl.custom_minimum_size = Vector2(180, 12)
		sl.focus_mode = Control.FOCUS_NONE
		into.add_child(sl)
		var upd := func(v: float) -> void:
			l.text = text % v
			cb.call(v)
		upd.call(val)
		sl.value_changed.connect(func(v): upd.call(v); Game.save_settings())
	mk.call(pg["ctl"], "Citlivost myši: %.2f", 0.1, 4.0, 0.05, Game.mouse_sens, func(v): Game.mouse_sens = v)
	mk.call(pg["ctl"], "Zorné pole (FOV): %.0f", 60.0, 100.0, 1.0, Game.fov, func(v): Game.fov = v)
	mk.call(pg["ctl"], "Pohupování kamery: %.0f %%", 0.0, 150.0, 10.0, Game.cam_bob * 100.0, func(v): Game.cam_bob = v / 100.0)
	# sound: one slider per bus (music, effects, wind, ambience, teammates)
	for b in Game.BUS_NAMES:
		var bl := Label.new()
		bl.add_theme_font_size_override("font_size", 9)
		var bname: String = Game.BUS_NAMES[b]
		bl.text = "%s: %d %%" % [bname, int(Game.get_volume(b) * 100)]
		pg["snd"].add_child(bl)
		var bs := HSlider.new()
		bs.min_value = 0.0
		bs.max_value = 1.0
		bs.step = 0.05
		bs.value = Game.get_volume(b)
		bs.focus_mode = Control.FOCUS_NONE
		bs.custom_minimum_size = Vector2(200, 12)
		bs.value_changed.connect(func(v): Game.set_volume(b, v); bl.text = "%s: %d %%" % [bname, int(v * 100)]; Game.save_settings())
		pg["snd"].add_child(bs)
	var mhint := Label.new()
	mhint.add_theme_font_size_override("font_size", 8)
	mhint.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	mhint.text = "Hudba se bere ze složky hudba vedle hry."
	pg["snd"].add_child(mhint)
	var tm := CheckBox.new()
	tm.text = "Hudba i během mise (jinak jen vítr a ticho)"
	tm.button_pressed = Game.tactical_music
	tm.focus_mode = Control.FOCUS_NONE
	tm.add_theme_font_size_override("font_size", 9)
	tm.toggled.connect(func(on): Game.tactical_music = on; Game.save_settings())
	pg["snd"].add_child(tm)
	var inv := CheckBox.new()
	inv.text = "Obrátit osu Y"
	inv.button_pressed = Game.invert_y
	inv.focus_mode = Control.FOCUS_NONE
	inv.add_theme_font_size_override("font_size", 9)
	inv.toggled.connect(func(on): Game.invert_y = on; Game.save_settings())
	pg["ctl"].add_child(inv)
	var vol := CheckBox.new()
	vol.text = "Objemová mlha (náročnější, od příští mise)"
	vol.button_pressed = Game.volumetric
	vol.focus_mode = Control.FOCUS_NONE
	vol.add_theme_font_size_override("font_size", 9)
	vol.toggled.connect(func(on): Game.volumetric = on; Game.save_settings())
	pg["gfx"].add_child(vol)
	var gr := CheckBox.new()
	gr.text = "Tráva ve větru (od příští mise)"
	gr.button_pressed = Game.grass
	gr.focus_mode = Control.FOCUS_NONE
	gr.add_theme_font_size_override("font_size", 9)
	gr.toggled.connect(func(on): Game.grass = on; Game.save_settings())
	pg["gfx"].add_child(gr)
	var fs := CheckBox.new()
	fs.text = "Celá obrazovka"
	fs.button_pressed = Game.fullscreen
	fs.focus_mode = Control.FOCUS_NONE
	fs.add_theme_font_size_override("font_size", 9)
	fs.toggled.connect(func(on): Game.fullscreen = on; Game.apply_video(); Game.save_settings())
	pg["gfx"].add_child(fs)
	var vm := OptionButton.new()
	vm.focus_mode = Control.FOCUS_NONE
	vm.add_theme_font_size_override("font_size", 9)
	var modes := ["ptt", "open", "off"]
	for i in modes.size():
		vm.add_item(["Mikrofon: při stisku (%s nahlas, %s vysílačka)" % [Game.key_name("talk"), Game.key_name("radio_talk")], "Mikrofon: stále zapnutý (podle hlasitosti)", "Mikrofon: vypnutý"][i])
		if Game.voice_mode == modes[i]:
			vm.select(i)
	vm.item_selected.connect(func(i): Game.voice_mode = modes[i]; Game.save_settings())
	pg["voice"].add_child(vm)
	var mim := CheckBox.new()
	mim.text = "Vetřelci smí napodobit můj hlas (jen během mise, nikam se neukládá)"
	mim.button_pressed = Game.mimic_ok
	mim.focus_mode = Control.FOCUS_NONE
	mim.add_theme_font_size_override("font_size", 9)
	mim.toggled.connect(func(on): Game.mimic_ok = on; Game.save_settings())
	pg["voice"].add_child(mim)
	var ff := CheckBox.new()
	ff.text = "Palba do vlastních (platí, když hostuješ)"
	ff.button_pressed = Game.friendly_fire
	ff.focus_mode = Control.FOCUS_NONE
	ff.add_theme_font_size_override("font_size", 9)
	ff.toggled.connect(func(on): Game.friendly_fire = on; Game.save_settings())
	pg["ctl"].add_child(ff)
	# own microphone: loudness, live level, test (you hear yourself half a second later)
	var gl := Label.new()
	gl.add_theme_font_size_override("font_size", 9)
	gl.text = "Zesílení mého mikrofonu: %d %%" % roundi(Game.mic_gain * 100.0)
	pg["voice"].add_child(gl)
	var gs := HSlider.new()
	gs.min_value = 0.25
	gs.max_value = 4.0
	gs.step = 0.05
	gs.value = Game.mic_gain
	gs.focus_mode = Control.FOCUS_NONE
	gs.custom_minimum_size = Vector2(200, 12)
	gs.value_changed.connect(func(v): Game.mic_gain = v; gl.text = "Zesílení mého mikrofonu: %d %%" % roundi(v * 100.0); Game.save_settings())
	pg["voice"].add_child(gs)
	# (0.62) room noise pulled down between words; how easily "always on" opens
	var cl := CheckBox.new()
	cl.text = "Potlačit šum místnosti (větrák, klávesnice) mezi slovy"
	cl.button_pressed = Game.mic_clean
	cl.focus_mode = Control.FOCUS_NONE
	cl.add_theme_font_size_override("font_size", 9)
	cl.toggled.connect(func(on): Game.mic_clean = on; Game.save_settings())
	pg["voice"].add_child(cl)
	var sl := Label.new()
	sl.add_theme_font_size_override("font_size", 9)
	var sens := func(): return clampf((0.09 - Game.mic_gate) / 0.08, 0.0, 1.0)
	sl.text = "Citlivost hlasové aktivace: %d %%" % int(sens.call() * 100)
	pg["voice"].add_child(sl)
	var ss := HSlider.new()
	ss.min_value = 0.0
	ss.max_value = 1.0
	ss.step = 0.05
	ss.value = sens.call()
	ss.focus_mode = Control.FOCUS_NONE
	ss.custom_minimum_size = Vector2(200, 12)
	ss.value_changed.connect(func(v): Game.mic_gate = 0.09 - 0.08 * v; sl.text = "Citlivost hlasové aktivace: %d %%" % int(v * 100); Game.save_settings())
	pg["voice"].add_child(ss)
	var meter := ProgressBar.new()
	meter.show_percentage = false
	meter.max_value = 1.0
	meter.custom_minimum_size = Vector2(200, 6)
	meter.add_theme_stylebox_override("fill", _meter_fill())
	pg["voice"].add_child(meter)
	var lv: Node = Net.get_node_or_null("LobbyVoice")
	# which microphone (Windows sometimes picks a wrong or disabled default)
	var dev := OptionButton.new()
	dev.focus_mode = Control.FOCUS_NONE
	dev.add_theme_font_size_override("font_size", 9)
	dev.clip_text = true
	dev.custom_minimum_size = Vector2(200, 0)
	var devs: Array = ["Default"] + Array(AudioServer.get_input_device_list()).filter(func(d): return d != "Default")
	for i in devs.size():
		dev.add_item(("Mikrofon: výchozí ve Windows" if devs[i] == "Default" else "Mikrofon: " + String(devs[i])))
		if (Game.mic_device == "" and devs[i] == "Default") or devs[i] == Game.mic_device:
			dev.select(i)
	dev.item_selected.connect(func(i):
		Game.mic_device = "" if devs[i] == "Default" else String(devs[i])
		Game.save_settings()
		if lv: lv.reopen())
	pg["voice"].add_child(dev)
	var diag := Label.new()
	diag.add_theme_font_size_override("font_size", 8)
	diag.autowrap_mode = TextServer.AUTOWRAP_WORD
	diag.custom_minimum_size = Vector2(200, 0)
	pg["voice"].add_child(diag)
	var tick := Timer.new()
	tick.wait_time = 0.05
	tick.autostart = true
	tick.timeout.connect(func():
		meter.value = clampf(Game.mic_level * 6.0, 0.0, 1.0)
		if lv:
			var state := "mikrofon zavřený (otevře se v co-op hře nebo testem)"
			if lv.mic:
				if lv.frames_in == 0 and Time.get_ticks_msec() - lv.opened_at > 1500:
					state = "MIKROFON NEPOSÍLÁ ZVUK - Windows: Nastavení > Soukromí > Mikrofon > povolit desktopovým aplikacím; nebo vyber jiné zařízení výše"
				else:
					state = "mikrofon běží (%d vzorků/s)%s" % [lv.frames_in, "  -  HLAS ZACHYCEN" if Time.get_ticks_msec() - lv.dsp.voiced_ms < 400 else ""]
			diag.text = "%s\nOdesláno balíčků: %d, přijato: %d" % [state, lv.sent, lv.received])
	meter.add_child(tick)
	var tb := Button.new()
	tb.add_theme_font_size_override("font_size", 9)
	tb.focus_mode = Control.FOCUS_NONE
	tb.toggle_mode = true
	tb.text = "Test mikrofonu (uslyšíš se se zpožděním)"
	tb.toggled.connect(func(on):
		if lv:
			if on: lv.testing = true
			else: lv.stop_test())
	tb.tree_exiting.connect(func(): if lv: lv.stop_test())
	pg["voice"].add_child(tb)
	# how loud I hear each teammate
	for id in Net.roster:
		var nm: String = Net.roster[id]["name"]
		if id == Net.my_id():
			continue
		var vl := Label.new()
		vl.add_theme_font_size_override("font_size", 9)
		vl.text = "Hlasitost: %s %d %%" % [nm, int(Game.peer_volume(nm) * 100)]
		pg["voice"].add_child(vl)
		var vs := HSlider.new()
		vs.min_value = 0.0
		vs.max_value = 2.0
		vs.step = 0.05
		vs.value = Game.peer_volume(nm)
		vs.focus_mode = Control.FOCUS_NONE
		vs.custom_minimum_size = Vector2(200, 12)
		vs.value_changed.connect(func(v): Game.voice_volumes[nm] = v; vl.text = "Hlasitost: %s %d %%" % [nm, int(v * 100)]; Game.save_settings())
		pg["voice"].add_child(vs)
	var rs := OptionButton.new()
	rs.focus_mode = Control.FOCUS_NONE
	rs.add_theme_font_size_override("font_size", 9)
	var scales := [1.0, 0.75, 0.5]
	for i in scales.size():
		rs.add_item(["Rozlišení 3D: plné (ostré)", "Rozlišení 3D: 75 % (rychlejší)", "Rozlišení 3D: 50 % (slabý počítač)"][i])
		if absf(Game.render_scale - scales[i]) < 0.01:
			rs.select(i)
	rs.item_selected.connect(func(i): Game.render_scale = scales[i]; Game.apply_video(); Game.save_settings())
	pg["gfx"].add_child(rs)
	var shq := OptionButton.new()
	shq.focus_mode = Control.FOCUS_NONE
	shq.add_theme_font_size_override("font_size", 9)
	for i in 3:
		shq.add_item(["Stíny: nízké (slabý počítač)", "Stíny: střední", "Stíny: vysoké (náročné)"][i])
	shq.select(clampi(Game.shadows, 0, 2))
	shq.item_selected.connect(func(i): Game.shadows = i; Game.save_settings())
	shq.tooltip_text = "Od příští mise."
	pg["gfx"].add_child(shq)
	var dtq := OptionButton.new()
	dtq.focus_mode = Control.FOCUS_NONE
	dtq.add_theme_font_size_override("font_size", 9)
	for i in 3:
		dtq.add_item(["Detaily v dálce: blízko (slabý počítač)", "Detaily v dálce: střední", "Detaily v dálce: daleko"][i])
	dtq.select(clampi(Game.detail, 0, 2))
	dtq.item_selected.connect(func(i): Game.detail = i; Game.save_settings())
	dtq.tooltip_text = "Drobnosti a tráva se kreslí jen do určité vzdálenosti. Od příští mise."
	pg["gfx"].add_child(dtq)
	var hq := OptionButton.new()
	hq.focus_mode = Control.FOCUS_NONE
	hq.add_theme_font_size_override("font_size", 9)
	hq.add_item("HUD: plný")
	hq.add_item("HUD: minimální (munice jen odhadem)")
	hq.select(1 if Game.hud_min else 0)
	hq.item_selected.connect(func(i): Game.hud_min = i == 1; Game.save_settings())
	hq.tooltip_text = "F1 ve hře skryje celý HUD (zůstane jen zaměřovač)."
	pg["gfx"].add_child(hq)
	# (Ari 22. 11.) záznamník výkonu: záseky do souboru, jen o hře, nic neposílá
	var pl := CheckBox.new()
	pl.focus_mode = Control.FOCUS_NONE
	pl.add_theme_font_size_override("font_size", 9)
	pl.text = "Záznam výkonu do souboru (F9, F8 = označit zásek)"
	pl.button_pressed = Game.perf_log
	pl.tooltip_text = "Když se hra sekne, zapíše do složky logs (vykon_*.txt), co se v tu chvíli dělo. Nic neposílá."
	pl.toggled.connect(func(v): Game.set_perf_log(v))
	pg["gfx"].add_child(pl)
	_keys_ui(pg["keys"])

## 0.72 (Ari): everyone's own keys. Click a key and press the new one (Esc = keep the old one),
## right click clears it. Two keys per action; a key taken from another action leaves it there.
static var keys_group := 0
static func _keys_ui(box: Control) -> void:
	var hint := Label.new()
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", UiSkin.DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.custom_minimum_size = Vector2(200, 0)
	hint.text = "Klikni na klávesu a stiskni novou (Esc = nechat). Pravé tlačítko = smazat. Klávesa vzatá jiné akci se u ní smaže. Esc, myš a kolečko zůstávají."
	box.add_child(hint)
	var btns: Array = []
	var refresh := func() -> void:
		for b in btns:
			var ks: Array = Game.keys_of(b[0])
			var bt: Button = b[2]
			bt.text = Game.key_label(int(ks[b[1]])) if b[1] < ks.size() else "-"
			bt.add_theme_color_override("font_color", UiSkin.BAD if ks.is_empty() else UiSkin.TEXT)
	# 0.72 (návrh A): the groups as small tabs over the table (Pohyb / Boj / Věci / Hlas / Stíhačka)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 2)
	box.add_child(tabs)
	var groups: Array = []
	var tab_btns: Array = []
	var show_group := func(k: int) -> void:
		keys_group = k
		for g in groups.size():
			(groups[g] as Control).visible = g == k
			UiSkin.row(tab_btns[g], g == k)
			(tab_btns[g] as Button).alignment = HORIZONTAL_ALIGNMENT_CENTER
	var grp: VBoxContainer = null
	for row in Game.KEY_ROWS:
		if String(row[0]) == "" or grp == null:
			grp = VBoxContainer.new()
			grp.name = "Keys_%d" % groups.size()
			grp.add_theme_constant_override("separation", 1)
			box.add_child(grp)
			groups.append(grp)
			var tb := Button.new()
			var nm := String(row[1]) if String(row[0]) == "" else "Klávesy"
			tb.text = nm.capitalize() if nm != "VĚCI A AKCE" else "Věci a akce"
			tb.add_theme_font_size_override("font_size", 8)
			tb.custom_minimum_size = Vector2(0, 14)
			tb.focus_mode = Control.FOCUS_NONE
			tabs.add_child(tb)
			tab_btns.append(tb)
			var gi := tab_btns.size() - 1
			tb.pressed.connect(func(): show_group.call(gi))
			if String(row[0]) == "":
				continue
		var action: String = row[0]
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 3)
		grp.add_child(hb)
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 8)
		l.text = String(row[1])
		l.clip_text = true
		l.custom_minimum_size = Vector2(120, 0)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(l)
		for i in 2:
			var bt := Button.new()
			bt.add_theme_font_size_override("font_size", 8)
			bt.custom_minimum_size = Vector2(64, 0)
			bt.clip_text = true
			bt.focus_mode = Control.FOCUS_ALL
			hb.add_child(bt)
			btns.append([action, i, bt])
			bt.pressed.connect(func():
				bt.set_meta("wait", true)
				Game.binding_key = true
				bt.text = "stiskni..."
				bt.grab_focus())
			bt.gui_input.connect(func(ev: InputEvent):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
					bt.accept_event()
					Game.rebind(action, i, 0)
					refresh.call()
					return
				if not bt.has_meta("wait") or not ev is InputEventKey or not ev.pressed or ev.echo:
					return
				bt.accept_event()
				bt.remove_meta("wait")
				var key: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
				if key != KEY_ESCAPE:
					Game.rebind(action, i, key)
				# the same key must not also pause the game or toggle the microphone this frame
				bt.get_tree().create_timer(0.2).timeout.connect(func(): Game.binding_key = false)
				bt.release_focus()
				refresh.call())
			bt.focus_exited.connect(func():
				if bt.has_meta("wait"):
					bt.remove_meta("wait")
					Game.binding_key = false
					refresh.call())
	var rb := Button.new()
	rb.add_theme_font_size_override("font_size", 9)
	rb.focus_mode = Control.FOCUS_NONE
	rb.text = "Výchozí klávesy"
	rb.pressed.connect(func(): Game.reset_keys(); refresh.call())
	UiSkin.ghost(rb)
	box.add_child(rb)
	refresh.call()
	show_group.call(clampi(keys_group, 0, groups.size() - 1))

static func _meter_fill() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.3, 0.9, 0.4)
	return sb

## A full screen from a terminal (research, encyclopedia): blocks the mercenary, frees the mouse.
var _screen: Control
func open_screen(c: Control) -> void:
	_screen = c
	paused = true
	inventory_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	c.set("on_close", func():
		_back_to_game()
		paused = false
		inventory_open = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)

func _pause() -> void:
	_ready_ptext()
	_pause_page("info")
	paused = true
	inventory_open = true   # blocks player input the same way
	pause_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _resume() -> void:
	if _leave_armed:
		_leave_armed = false
		_leave_warn.visible = false
		_leave_btn.text = _leave_text()
	_back_to_game()
	paused = false
	inventory_open = false
	pause_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
