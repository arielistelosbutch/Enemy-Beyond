extends CanvasLayer
## Everything drawn over the 3D view: crosshair, health, ammo, motion scanner,
## messages, the UFO-style inventory screen, pause and the mission result.

const PANEL := Color(0.10, 0.115, 0.13, 0.94)
const FRAME := Color(0.45, 0.78, 0.86)
const TEXT := Color(0.84, 0.89, 0.92)
const ACCENT := Color(1.0, 0.74, 0.32)
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

func _ready() -> void:
	layer = 5
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_hud)
	add_child(canvas)
	msg_label = Label.new()
	msg_label.position = Vector2(20, 250)
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
func night_blind() -> void:
	var r := ColorRect.new()
	r.color = Color(0, 0, 0, 0.6)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	move_child(r, 0)
	var tw := create_tween()
	tw.tween_property(r, "color:a", 0.0, 4.5).set_ease(Tween.EASE_IN)
	tw.tween_callback(r.queue_free)

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

func blind_flash(k: float) -> void:
	var r := ColorRect.new()
	r.color = Color(1.0, 0.98, 0.93, clampf(k, 0.0, 1.0))
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	var tw := create_tween()
	tw.tween_interval(0.6 + k * 1.4)
	tw.tween_property(r, "color:a", 0.0, 2.5 + k * 2.5).set_ease(Tween.EASE_IN)
	tw.tween_callback(r.queue_free)

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
	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel", UiSkin.panel())
	frame.position = Vector2(40, 22)
	frame.size = Vector2(560, 306)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brief_bg.add_child(frame)
	var head := Label.new()
	head.text = "Hlášení z velínu - " + String(Net.mission_params.get("type_name", "mise"))
	UiSkin.title(head, 12)
	head.position = Vector2(52, 30)
	head.size = Vector2(536, 0)
	_brief_bg.add_child(head)
	_brief_lbl = Label.new()
	_brief_lbl.text = Game.shipify(text)
	_brief_lbl.position = Vector2(60, 70)
	_brief_lbl.size = Vector2(520, 220)
	_brief_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_brief_lbl.add_theme_font_size_override("font_size", 10)
	_brief_lbl.add_theme_color_override("font_color", Color(0.62, 0.95, 0.88))
	_brief_lbl.visible_characters = 0
	_brief_lbl.custom_minimum_size = Vector2(520, 0)
	_brief_bg.add_child(_brief_lbl)
	_brief_lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_brief_lbl.position = Vector2(60, 58)
	_brief_lbl.size = Vector2(520, 250)
	var hint := Label.new()
	hint.text = "Mezerník - přeskočit"
	hint.position = Vector2(500, 334)
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", Color(0.4, 0.45, 0.4))
	_brief_bg.add_child(hint)
	_brief_len = text.length()
	_brief_t = 0.0
	var mt: String = Net.mission_params.get("type", "")
	Game.play_music("final_mission" if mt == "mars" else ("terror_briefing" if mt == "terror" else "briefing"), mt == "mars")
	inventory_open = true     # blocks the mercenary while the screen is black

var _ready_lbl: Label
var _ready_sent := false
var _brief_fade := -1.0

func _brief_tick(delta: float) -> void:
	if _brief_t < 0:
		return
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

func show_result(title: String, text: String) -> void:
	Game.play_music("debriefing", false)
	Game.play_ui(self, "mission_complete" if title.begins_with("MISE SPLN") else "mission_failed", -2)
	_close_inventory()
	pause_panel.visible = false
	result_panel = _panel(title, Vector2(110, 12), Vector2(420, 0))
	var outer: VBoxContainer = result_panel.get_child(0)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(sc)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(box)
	var l := _lbl(box, text, TEXT, 9)
	l.custom_minimum_size = Vector2(400, 0)
	# as tall as the text, but never past the bottom of the screen
	var n_lines := 0
	for ln in text.split("\n"):
		n_lines += maxi(1, ceili(ln.length() / 72.0))
	sc.custom_minimum_size = Vector2(404, minf(n_lines * 13.0 + 8.0, 280.0))
	if Game.autotest() == "":
		_lbl(outer, "Návrat na základnu za chvíli...", FRAME, 9)

# ---- frame -------------------------------------------------------------------------------
func _process(delta: float) -> void:
	msg_time -= delta
	msg_label.visible = msg_time > 0
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
	if Input.is_action_just_pressed("pause"):
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
	# red vignette when hurt
	if flash_t > 0:
		var a := clampf(flash_t, 0, 0.6) * 0.6
		c.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.6, 0, 0, a * 0.4))
		var dir := Vector2(sin(flash_dir), -cos(flash_dir))
		c.draw_circle(mid + dir * 70, 12, Color(1, 0.1, 0.1, a))
	if p == null:
		return
	if p.dead:
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
		if p.scoped():
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
	# bars, bottom left (veteran: no numbers - you feel it: blood, breath, limping)
	# 0.57: on a plate of the menus' metal, with the mercenary's own figure for the stance
	_plate(c, Rect2(4, sz.y - 44, 218, 40))
	var base := Vector2(10, sz.y - 34)
	if Game.veteran():
		_blood(c, sz, p)
		_bar(c, base + Vector2(0, 22), "VÝDRŽ", p.stamina / 100.0, Color(0.3, 0.6, 0.9))
	else:
		_bar(c, base, "ZDRAVÍ", p.hp / p.max_hp, Color(0.8, 0.15, 0.12))
		_bar(c, base + Vector2(0, 11), "VÝDRŽ", p.stamina / 100.0, Color(0.3, 0.6, 0.9))
		_bar(c, base + Vector2(0, 22), "STRACH", p.stress / 100.0, Color(0.7, 0.4, 0.9))
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
				t2 += "    E - táhnout"
			_text(c, Vector2(mid.x - 100, mid.y + 56), t2, Color(0.5, 1.0, 0.5) if in_hand else ACCENT, 10)
	if p.busy > 0 and p.busy_total > 0 and (p.busy_text.begins_with("Ošetřuji") or p.busy_text.begins_with("Obvazuji") or p.busy_text.begins_with("Vyřezávám")):
		c.draw_rect(Rect2(mid.x - 60, mid.y + 42, 120, 5), Color(0, 0, 0, 0.6))
		c.draw_rect(Rect2(mid.x - 60, mid.y + 42, 120 * (1.0 - p.busy / p.busy_total), 5), Color(0.4, 1.0, 0.4))
	if not p.downed and not mission().nearest_pickup(p.global_position).is_empty():
		var it: Dictionary = mission().nearest_pickup(p.global_position)["item"]
		_text(c, Vector2(mid.x - 60, mid.y + 44), "E - sebrat: " + Game.ITEMS[it["id"]]["name"], TEXT, 9)
	if p.bleeding > 0:
		_text(c, base + Vector2(0, -12), "KRVÁCÍŠ (-%.1f zdraví/s) - X lékárnička (do ruky, pak X)" % p.bleeding, RED, 9)
	# hands, bottom: left hand on the left, right hand on the right
	var right := Vector2(sz.x - 160, sz.y - 30)
	_plate(c, Rect2(sz.x - 168, sz.y - 66, 164, 62))
	var held_id: String = p.item_in("rh").get("id", "")
	var ico := UiSkin.icon(held_id) if held_id != "" else null
	if ico:
		c.draw_texture_rect(ico, Rect2(sz.x - 62, sz.y - 60, 56, 28), false, Color(1, 1, 1, 0.9))
	if p.item_in("lh").size() > 0:
		_plate(c, Rect2(sz.x - 338, sz.y - 34, 164, 30))
	_hand_text(c, p, "rh", right)
	var rid: String = p.item_in("rh").get("id", "")
	if p.item_in("lh").size() > 0:
		_hand_text(c, p, "lh", Vector2(sz.x - 330, sz.y - 30))
	_belt_bar(c, p, sz)
	var holst := []
	for hs in [["back", "1"], ["side", "2"]]:
		if p.item_in(hs[0]).size() > 0:
			holst.append("%s %s" % [hs[1], Game.ITEMS[p.inv[hs[0]]["id"]]["short"]])
	if not holst.is_empty():
		_text(c, right + Vector2(0, -24), "   ".join(holst), FRAME, 8)
	if p.spin > 0.05 and rid in ["minigun", "laser_minigun", "plasma_minigun"]:
		c.draw_rect(Rect2(mid.x - 20, mid.y + 14, 40 * p.spin, 3), Color(1, 0.6, 0.2))
	_stance_icon(c, Vector2(130, sz.y - 40), p)
	if Game.easy() or Game.has_talent(p.merc, "sesty_smysl"):
		_eye_icon(c, Vector2(132, sz.y - 86), p)    # only on easy: on normal and hardcore you never know who is watching
	if Game.mic_live:
		_text(c, Vector2(10, sz.y - 62), "MIKROFON ZAPNUTÝ (Tab)", Color(0.5, 1.0, 0.5), 8)
	if p.radio_up:
		_text(c, Vector2(10, sz.y - 72), "VYSÍLAČKA (T)", ACCENT, 8)
	if not p.light_on:
		_text(c, right + Vector2(0, -12), "Svítilna vypnutá (F)", FRAME, 9)
	# busy (reloading, healing...)
	if p.busy > 0:
		_text(c, Vector2(mid.x - 60, mid.y + 30), p.busy_text + "...", ACCENT, 10)
	# evac
	var ev: Vector3 = mission().map["evac"]
	if p.global_position.distance_to(ev) < 3.5 and not p.dead and mission().started():
		_text(c, Vector2(mid.x - 120, 20), ("ENTER - připraven k odletu (musí všichni živí, i ranění)" if not p.wants_evac else "Připraven k odletu - čekáme na ostatní (Enter = ještě ne)"), ACCENT, 10)
		_text(c, Vector2(mid.x - 120, 32), "Pokud posádka UFO žije, mise nebude splněna.", FRAME, 9)
	# the objective of this mission, top centre; the beacon's direction for a rescue
	var ot: String = Game.shipify(mission().objective_text())
	if ot != "":
		_text(c, Vector2(mid.x - ot.length() * 2.4, 12), ot, ACCENT, 9)
	if mission().done_banner:
		var bt := Game.shipify("MISE SPLNĚNA - Enter kdekoli = odlet (transport vyzvedne všechny)")
		c.draw_rect(Rect2(mid.x - 160, 16, 320, 16), Color(0, 0, 0, 0.55))
		_text(c, Vector2(mid.x - bt.length() * 2.6, 28), bt, Color(0.5, 1.0, 0.55), 10)
	var v: Node = mission().vip()
	if v and not v.dead and not v.saved and v.st != v.C.FOLLOW:
		var to: Vector3 = v.global_position - p.global_position
		var ang: float = atan2(to.x, to.z) - (p.rotation.y + PI)
		var dist: float = snappedf(to.length(), 5.0)
		var cpos := Vector2(mid.x, 34)
		var dv := Vector2(sin(-ang), -cos(-ang))
		c.draw_line(cpos, cpos + dv * 9.0, ACCENT, 2.0)
		c.draw_circle(cpos + dv * 9.0, 2.0, ACCENT)
		_text(c, cpos + Vector2(14, 4), "maják ~%d m" % int(dist), ACCENT, 8)
	if p.plant_hold > 0.0:
		c.draw_rect(Rect2(mid.x - 40, mid.y + 20, 80, 4), Color(0, 0, 0, 0.6))
		c.draw_rect(Rect2(mid.x - 40, mid.y + 20, 80 * p.plant_hold / 3.0, 4), RED)
	elif mission().beacon_near(p.global_position) >= 0:
		_text(c, Vector2(mid.x - 60, mid.y + 44), "Drž E 3 s - položit nálož", ACCENT, 9)
	# teammates
	var y := 10.0
	for o in mission().players():
		if o == p: continue
		if Game.veteran() and not (o.downed or o.dead):
			continue        # hardcore: no roster on screen, only who has fallen
		var st: String = "MRTEV" if o.dead else ("ODVLEČEN! %d s" % int(o.bleed_left) if o.downed and o.carried_by < 0 else ("PADL! %d s" % int(o.bleed_left) if o.downed else "%d m" % int(p.global_position.distance_to(o.global_position))))
		_text(c, Vector2(10, y + 8), "%s  %s" % ["Někdo z týmu" if Game.veteran() else o.display_name, st if not Game.veteran() else st.split(" ")[0]], RED if o.downed or o.dead else TEXT, 9)
		y += 11
	if p.has_scanner():
		_draw_scanner(c, Vector2(sz.x - 52, 52), 40.0, p)

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

## The belt at a glance: what 1-4 call up, and how many throwables are at hand.
func _belt_bar(c: Control, p: Node, sz: Vector2) -> void:
	if inventory_open or p.downed:
		return
	var parts := []
	for i in 4:
		var it: Dictionary = p.item_in("b%d" % i)
		parts.append("%d %s" % [i + 3, "-" if it.is_empty() else Game.ITEMS[it["id"]]["short"]])
	var n := func(id: String) -> int:
		var k := 0
		for s in p.inv:
			if p.inv[s]["id"] == id:
				k += 1
		return k
	var extra := "   G %d  X %d  7 %d  H %d" % [n.call("grenade"), n.call("smoke_grenade"), n.call("flare"), n.call("medkit")]
	var line: String = "  ".join(parts) + extra + "   (I = výstroj)"
	var w := ThemeDB.fallback_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
	_plate(c, Rect2(226, sz.y - 16, w + 12, 14))
	_text(c, Vector2(232, sz.y - 6), line, FRAME, 7)

func _hand_text(c: Control, p: Node, slot: String, at: Vector2) -> void:
	var it: Dictionary = p.item_in(slot)
	var label := "" if slot == "rh" else "Štít: "
	if it.is_empty():
		_text(c, at + Vector2(0, 12), label + "prázdné ruce", FRAME, 9)
		return
	var rule: Dictionary = Game.ITEMS[it["id"]]
	var mode := ("  [1×]" if p.semi else "  [dávka]") if rule.get("modes", false) else ""
	if rule.has("bursts"):
		mode = "  [%s]" % p.burst_name(it)
	if rule.has("ammo_alt"):
		mode = "  [%s]" % Game.ITEMS[String(it.get("sel", rule["ammo"]))]["short"]
	_text(c, at, label + ((rule["short"] + " (neznámá)") if Game.alien_unknown(it["id"]) else rule["name"]) + mode, TEXT, 9)
	if rule["type"] == "weapon":
		var spare := 0
		for s in p.inv:
			if p.inv[s]["id"] == String(it.get("sel", rule["ammo"])):
				spare += int(p.inv[s].get("left", Game.ITEMS[p.inv[s]["id"]]["rounds"]))
		if rule.get("alien", false):
			_text(c, at + Vector2(0, 12), "%d / %d   články %d" % [int(it.get("loaded", 0)), Game.mag_size(it["id"]), int(it.get("cells", 0))], ACCENT, 10)
		elif rule.get("laser", false):
			# the cell's readiness light (X-WEP-001): ready, or charging
			var cap := Game.mag_size(it["id"])
			if cap <= 1:
				var ready := int(it.get("loaded", 0)) >= 1
				_text(c, at + Vector2(0, 12), "článek připraven" if ready else "článek se nabíjí", ACCENT if ready else FRAME, 10)
				if not ready:
					c.draw_rect(Rect2(at + Vector2(118, 5), Vector2(60.0 * clampf(float(it.get("charge", 0.0)), 0.0, 1.0), 6)), FRAME)
			else:
				_text(c, at + Vector2(0, 12), "%d / %d pulzů%s" % [int(it.get("loaded", 0)), cap, "   nabíjí se doplna" if it.get("drained", false) else ""], ACCENT, 10)
		else:
			_text(c, at + Vector2(0, 12), "%d / %d   náhradní %d" % [int(it.get("loaded", 0)), Game.mag_size(it["id"]), spare], ACCENT, 10)
	elif it.has("uses"):
		_text(c, at + Vector2(0, 12), "%dx" % int(it["uses"]), ACCENT, 10)
	elif it["id"] == "energo_nuz":
		# EN-01's small indicator light: the edge's charge, or that it is charging / switched off
		var e := int(it.get("edge", 3))
		_text(c, at + Vector2(0, 12), ("ostří nabíjí" if e <= 0 else ("ostří vypnuto" if it.get("edge_off", false) else "ostří aktivní " + "▮".repeat(e))), ACCENT if e > 0 and not it.get("edge_off", false) else FRAME, 10)
	elif it["id"] == "stun_baton" and Game.has_mod("stun_baton", "diagnostika", p.merc):
		_text(c, at + Vector2(0, 12), "energie %d / %d" % [int(it.get("energy", p.baton_cap())), p.baton_cap()], ACCENT, 10)

# ---- motion scanner ----------------------------------------------------------------------
## Like a real motion tracker it shows only "something moves" - teammates too -
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
		Game.play_ui(mission(), "scanner_close", -16 + (SCAN_RANGE - near) / 2.5)
		# (0.57, MD-01's entry) the beeping carries a few metres: what hunts by ear may hear it
		_beep_noise_cd -= _ping_t
		if _beep_noise_cd <= 0.0:
			_beep_noise_cd = 2.0
			mission().noise(p.global_position, 6.0)
	if _scan_t > 0:
		return
	_scan_t = 0.5
	var movers: Array = mission().aliens() + mission().players() + mission().civilians()
	for a in movers:
		if a == p or a.dead: continue
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
	c.draw_circle(center, r, Color(0.02, 0.08, 0.04, 0.8))
	c.draw_arc(center, r, 0, TAU, 24, Color(0.2, 0.8, 0.3, 0.8), 1.0)
	c.draw_arc(center, r * 0.66, 0, TAU, 20, Color(0.2, 0.8, 0.3, 0.3), 1.0)
	c.draw_arc(center, r * 0.33, 0, TAU, 14, Color(0.2, 0.8, 0.3, 0.3), 1.0)
	c.draw_line(center, center + Vector2(0, -r), Color(0.2, 0.8, 0.3, 0.2))
	# the sweep line going round, a fading wake behind it (MD-01's green screen)
	var ang := _scan_sweep * TAU - PI / 2
	for k in 6:
		var a2 := ang - k * 0.09
		c.draw_line(center, center + Vector2(cos(a2), sin(a2)) * r, Color(0.3, 1, 0.4, 0.5 * (1.0 - k / 6.0)), 1.0)
	var inv_basis: Basis = p.global_transform.basis.inverse()
	for b in _blips:
		var local: Vector3 = inv_basis * (b["pos"] - p.global_position)
		var v := Vector2(local.x, local.z) / SCAN_RANGE * r
		if v.length() > r: continue
		c.draw_circle(center + v, 2.5, Color(0.5, 1, 0.5, clampf(b["t"], 0, 1)))
	c.draw_circle(center, 1.5, Color(1, 1, 1))
	_text(c, center + Vector2(-r, r + 10), "DETEKTOR  " + (("%d m" % int(snappedf(_scan_near, 2.0))) if _scan_near < SCAN_RANGE else "--"), Color(0.3, 0.9, 0.4), 8)

# ---- drawing helpers ---------------------------------------------------------------------
func _text(c: Control, pos: Vector2, s: String, col: Color, size := 10) -> void:
	var f := ThemeDB.fallback_font
	c.draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color(0, 0, 0, 0.8))
	c.draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

## A small figure next to the bars: standing / crouched / prone / sprinting (or out of breath).
## Stealth eye: how open it is = how far you can be seen (stance, flashlight);
## its colour = how close the aliens are to spotting you.
func _eye_icon(c: Control, o: Vector2, p: Node) -> void:
	var box := Rect2(o, Vector2(34, 28))
	c.draw_rect(box, Color(0, 0, 0, 0.45))
	c.draw_rect(box, FRAME, false, 1.0)
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
func _plate(c: Control, rect: Rect2) -> void:
	UiSkin.inset(4).draw(c.get_canvas_item(), rect)

## 0.57: our mercenary's own figure (tools/stance_icons.gd: merc.glb in the game's movements, white).
const STANCE_TEX := {"stand": "stance_stand", "crouch": "stance_crouch", "prone": "stance_prone", "sprint": "stance_sprint",
	"downed": "stance_downed", "winded": "stance_winded"}
func _stance_icon(c: Control, o: Vector2, p: Node) -> void:
	var box := Rect2(o, Vector2(34, 34))
	c.draw_rect(box, Color(0.02, 0.03, 0.035, 0.7))
	c.draw_rect(box, Color(FRAME, 0.55), false, 1.0)
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
	_text(c, pos + Vector2(0, 8), label, TEXT, 8)
	var r := Rect2(pos + Vector2(42, 1), Vector2(70, 7))
	c.draw_rect(r, Color(0.01, 0.015, 0.02, 0.8))
	var fill := Rect2(r.position, Vector2(r.size.x * clampf(v, 0, 1), r.size.y))
	c.draw_rect(fill, col)
	c.draw_rect(Rect2(fill.position, Vector2(fill.size.x, 2)), col.lightened(0.35))       # a sheen on top
	for k in range(1, 10):                                                                # tenths
		c.draw_line(r.position + Vector2(r.size.x * k / 10.0, 1), r.position + Vector2(r.size.x * k / 10.0, r.size.y - 1), Color(0, 0, 0, 0.45), 1.0)
	c.draw_rect(r, Color(FRAME, 0.6), false, 1.0)

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
	UiSkin.button(b)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

# ---- inventory (UFO style: hands, belt, backpack) -----------------------------------------
var inv_keys: Label
const SLOT_KEY := {"rh": "LTM", "lh": "štít", "back": "1", "side": "2", "b0": "3", "b1": "4", "b2": "5", "b3": "6"}
func _build_inventory() -> void:
	inv_panel = _panel("VÝSTROJ", Vector2(14, 8), Vector2(612, 0))
	var box: VBoxContainer = inv_panel.get_child(0)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 10)
	box.add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 3)
	cols.add_child(left)
	var groups := [["V RUKOU a ŠTÍT  (LTM = použít / střílet, PTM = mířit)", ["rh", "lh"]],
		["ZBRANĚ - 1 primární, 2 sekundární (jednoruční); Q = primární a zpět", ["back", "side"]],
		["OPASEK - rychlý: klávesy 3 4 5 6 (do rukou, náboje nabijí)", ["b0", "b1", "b2", "b3"]],
		["BATOH - pomalý: stojíš a hrabeš se (granáty, světlice... i odtud fungují svou klávesou)", Game.pack_slots()]]
	var names := {"rh": "v rukou - jedna věc, zbraň oběma rukama", "lh": "štít (jen s jednoruční zbraní)", "back": "primární zbraň (klávesa 1)", "side": "sekundární zbraň - pistole, revolver, nůž (klávesa 2)"}
	for g in groups:
		var gl := _lbl(left, g[0], FRAME, 8)
		gl.custom_minimum_size = Vector2(360, 0)
		var row := GridContainer.new()
		row.columns = 4 if g[1].size() == 4 else (2 if g[1].size() == 2 else 3)
		row.add_theme_constant_override("h_separation", 3)
		row.add_theme_constant_override("v_separation", 3)
		left.add_child(row)
		for sl in g[1]:
			var slot: String = sl
			inv_buttons[slot] = _btn(row, "", func(): _slot_clicked(slot), Vector2(86 if g[1].size() == 4 else (176 if g[1].size() == 2 else 116), 32 if g[1].size() < 9 else 24))
			inv_buttons[slot].tooltip_text = names.get(slot, "")
	inv_info = _lbl(left, "", TEXT, 9)
	var hint := _lbl(left, "Přetáhni věc (nebo klikni na ni a pak na místo), kam ji dát. Přetažení mimo okno ji zahodí před tebe. Z batohu to trvá a stojíš. I zavře.", FRAME, 8)
	_btn(left, "Zahodit vybranou věc (Backspace = zahodit z ruky)", func():
		var pp := me()
		if pp and held_slot != "":
			pp.drop_slot(held_slot)
			held_slot = "", Vector2(360, 16))
	hint.custom_minimum_size = Vector2(360, 0)
	# right: every key and what it does with what you carry right now
	var right := VBoxContainer.new()
	cols.add_child(right)
	_lbl(right, "KLÁVESY", ACCENT, 10)
	inv_keys = _lbl(right, "", TEXT, 8)
	inv_keys.custom_minimum_size = Vector2(220, 0)
	inv_panel.visible = false

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
	var lines := [
		"LTM  použít / střílet: %s" % hand.call("rh"),
		"PTM  mířit (zbraň oběma rukama)",
		"R    nabít zbraň / zapnout ostří energo nože",
		"1    primární zbraň (%s)" % hand.call("back") if p.item_in("rh").get("home", "") != "back" else "1    primární zbraň - znovu 1 ji uklidí",
		"2    sekundární zbraň (%s)" % hand.call("side") if p.item_in("rh").get("home", "") != "side" else "2    sekundární zbraň - znovu 2 ji uklidí",
		"Q    primární do rukou / znovu Q: zpět, co jsi držel",
		"3-6  věc z opasku do rukou / nabít",
		"G granát z opasku (%d výbušné)   H kouřový %d   B mina %d   7 světlice %d" % [p.inv.values().filter(func(it): return it["id"] == "grenade").size(), p.inv.values().filter(func(it): return it["id"] == "smoke_grenade").size(), p.inv.values().filter(func(it): return it["id"] == "mine").size(), p.inv.values().filter(func(it): return it["id"] == "flare").size()],
		"Backspace  zahodit, co máš v ruce",
		"X    lékárnička - do rukou, pak ošetří (%s)" % where.call("medkit"),
		"E    táhnout padlého / sebrat / civilista",
		"Enter  v lodi: připraven (start mise i odlet)",
		"V    rána zblízka (%s)" % ("pažbou zbraně" if melee == "" else Game.ITEMS[p.inv[melee]["id"]]["short"]),
		"F    svítilna na helmě",
		"N    noktovizor / přísvit (%s)" % where.call("nvg"),
		"L    dávky / jednotlivé rány, délka dávky, druh nábojů",
		"Tab  držet = mluvit (nahlas, kdo je blízko)",
		"M    mikrofon stále zapnutý / vypnout (%s)" % ("ZAPNUTO" if Game.mic_live else "vypnuto"),
		"T    držet = vysílačka (%s)" % ("helma" if Game.has_research("vysilacky") else where.call("radio")),
		"C  kleknout   Y  lehnout   Shift  sprint",
	]
	return "\n".join(lines)

func _open_inventory() -> void:
	inventory_open = true
	held_slot = ""
	inv_panel.visible = true
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
	elif target == "" and not inv_panel.get_global_rect().has_point(mp):
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
	inv_info.text = "Váha %d / síla %d%s" % [w, cap, "   PŘETÍŽEN - pomalejší pohyb" if w > cap else ""]
	if held_slot != "":
		inv_info.text += "   V ruce: " + Game.ITEMS[p.inv[held_slot]["id"]]["name"]
	inv_info.add_theme_color_override("font_color", RED if w > cap else TEXT)
	if inv_keys:
		inv_keys.text = _keys_text(p)

# ---- pause -----------------------------------------------------------------------------------
func _build_pause() -> void:
	pause_panel = _panel("PAUZA", Vector2(150, 6), Vector2(340, 0))
	var outer: VBoxContainer = pause_panel.get_child(0)
	_btn(outer, "Pokračovat", _resume)
	# the settings scroll if they do not fit
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(330, 250)
	outer.add_child(sc)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(box)
	_lbl(box, "Hra běží dál - vetřelci nečekají.", FRAME, 9)
	settings_ui(box)
	_btn(outer, "Opustit misi", func(): Net.after_mission())
	pause_panel.visible = false

## Mouse sensitivity, invert, field of view - shared by the pause menu and main menu.
static func settings_ui(box: Control) -> void:
	var mk := func(text: String, mn: float, mx: float, step: float, val: float, cb: Callable) -> void:
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 9)
		l.add_theme_color_override("font_color", Color(0.80, 0.90, 1.0))
		box.add_child(l)
		var sl := HSlider.new()
		sl.min_value = mn; sl.max_value = mx; sl.step = step; sl.value = val
		sl.custom_minimum_size = Vector2(180, 12)
		sl.focus_mode = Control.FOCUS_NONE
		box.add_child(sl)
		var upd := func(v: float) -> void:
			l.text = text % v
			cb.call(v)
		upd.call(val)
		sl.value_changed.connect(func(v): upd.call(v); Game.save_settings())
	mk.call("Citlivost myši: %.2f", 0.1, 4.0, 0.05, Game.mouse_sens, func(v): Game.mouse_sens = v)
	mk.call("Zorné pole (FOV): %.0f", 60.0, 100.0, 1.0, Game.fov, func(v): Game.fov = v)
	# sound: one slider per bus (music, effects, wind, ambience, teammates)
	var sh := Label.new()
	sh.add_theme_font_size_override("font_size", 10)
	sh.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	sh.text = "ZVUK"
	box.add_child(sh)
	for b in Game.BUS_NAMES:
		var bl := Label.new()
		bl.add_theme_font_size_override("font_size", 9)
		var bname: String = Game.BUS_NAMES[b]
		bl.text = "%s: %d %%" % [bname, int(Game.get_volume(b) * 100)]
		box.add_child(bl)
		var bs := HSlider.new()
		bs.min_value = 0.0
		bs.max_value = 1.0
		bs.step = 0.05
		bs.value = Game.get_volume(b)
		bs.focus_mode = Control.FOCUS_NONE
		bs.custom_minimum_size = Vector2(200, 12)
		bs.value_changed.connect(func(v): Game.set_volume(b, v); bl.text = "%s: %d %%" % [bname, int(v * 100)]; Game.save_settings())
		box.add_child(bs)
	var mhint := Label.new()
	mhint.add_theme_font_size_override("font_size", 8)
	mhint.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	mhint.text = "Hudba se bere ze složky hudba vedle hry."
	box.add_child(mhint)
	var tm := CheckBox.new()
	tm.text = "Hudba i během mise (jinak jen vítr a ticho)"
	tm.button_pressed = Game.tactical_music
	tm.focus_mode = Control.FOCUS_NONE
	tm.add_theme_font_size_override("font_size", 9)
	tm.toggled.connect(func(on): Game.tactical_music = on; Game.save_settings())
	box.add_child(tm)
	var inv := CheckBox.new()
	inv.text = "Obrátit osu Y"
	inv.button_pressed = Game.invert_y
	inv.focus_mode = Control.FOCUS_NONE
	inv.add_theme_font_size_override("font_size", 9)
	inv.toggled.connect(func(on): Game.invert_y = on; Game.save_settings())
	box.add_child(inv)
	var vol := CheckBox.new()
	vol.text = "Objemová mlha (náročnější, od příští mise)"
	vol.button_pressed = Game.volumetric
	vol.focus_mode = Control.FOCUS_NONE
	vol.add_theme_font_size_override("font_size", 9)
	vol.toggled.connect(func(on): Game.volumetric = on; Game.save_settings())
	box.add_child(vol)
	var gr := CheckBox.new()
	gr.text = "Tráva ve větru (od příští mise)"
	gr.button_pressed = Game.grass
	gr.focus_mode = Control.FOCUS_NONE
	gr.add_theme_font_size_override("font_size", 9)
	gr.toggled.connect(func(on): Game.grass = on; Game.save_settings())
	box.add_child(gr)
	var fs := CheckBox.new()
	fs.text = "Celá obrazovka"
	fs.button_pressed = Game.fullscreen
	fs.focus_mode = Control.FOCUS_NONE
	fs.add_theme_font_size_override("font_size", 9)
	fs.toggled.connect(func(on): Game.fullscreen = on; Game.apply_video(); Game.save_settings())
	box.add_child(fs)
	var vm := OptionButton.new()
	vm.focus_mode = Control.FOCUS_NONE
	vm.add_theme_font_size_override("font_size", 9)
	var modes := ["ptt", "open", "off"]
	for i in modes.size():
		vm.add_item(["Mikrofon: při stisku (Tab)", "Mikrofon: stále zapnutý (podle hlasitosti)", "Mikrofon: vypnutý"][i])
		if Game.voice_mode == modes[i]:
			vm.select(i)
	vm.item_selected.connect(func(i): Game.voice_mode = modes[i]; Game.save_settings())
	box.add_child(vm)
	var mim := CheckBox.new()
	mim.text = "Vetřelci smí napodobit můj hlas (jen během mise, nikam se neukládá)"
	mim.button_pressed = Game.mimic_ok
	mim.focus_mode = Control.FOCUS_NONE
	mim.add_theme_font_size_override("font_size", 9)
	mim.toggled.connect(func(on): Game.mimic_ok = on; Game.save_settings())
	box.add_child(mim)
	var ff := CheckBox.new()
	ff.text = "Palba do vlastních (platí, když hostuješ)"
	ff.button_pressed = Game.friendly_fire
	ff.focus_mode = Control.FOCUS_NONE
	ff.add_theme_font_size_override("font_size", 9)
	ff.toggled.connect(func(on): Game.friendly_fire = on; Game.save_settings())
	box.add_child(ff)
	# own microphone: loudness, live level, test (you hear yourself half a second later)
	var gl := Label.new()
	gl.add_theme_font_size_override("font_size", 9)
	gl.text = "Síla mého mikrofonu: x%.1f" % Game.mic_gain
	box.add_child(gl)
	var gs := HSlider.new()
	gs.min_value = 0.5
	gs.max_value = 4.0
	gs.step = 0.1
	gs.value = Game.mic_gain
	gs.focus_mode = Control.FOCUS_NONE
	gs.custom_minimum_size = Vector2(200, 12)
	gs.value_changed.connect(func(v): Game.mic_gain = v; gl.text = "Síla mého mikrofonu: x%.1f" % v; Game.save_settings())
	box.add_child(gs)
	var meter := ProgressBar.new()
	meter.show_percentage = false
	meter.max_value = 1.0
	meter.custom_minimum_size = Vector2(200, 6)
	meter.add_theme_stylebox_override("fill", _meter_fill())
	box.add_child(meter)
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
	box.add_child(dev)
	var diag := Label.new()
	diag.add_theme_font_size_override("font_size", 8)
	diag.autowrap_mode = TextServer.AUTOWRAP_WORD
	diag.custom_minimum_size = Vector2(200, 0)
	box.add_child(diag)
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
					state = "mikrofon běží (%d vzorků/s)" % lv.frames_in
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
	box.add_child(tb)
	# how loud I hear each teammate
	for id in Net.roster:
		var nm: String = Net.roster[id]["name"]
		if id == Net.my_id():
			continue
		var vl := Label.new()
		vl.add_theme_font_size_override("font_size", 9)
		vl.text = "Hlasitost: %s %d %%" % [nm, int(Game.peer_volume(nm) * 100)]
		box.add_child(vl)
		var vs := HSlider.new()
		vs.min_value = 0.0
		vs.max_value = 2.0
		vs.step = 0.05
		vs.value = Game.peer_volume(nm)
		vs.focus_mode = Control.FOCUS_NONE
		vs.custom_minimum_size = Vector2(200, 12)
		vs.value_changed.connect(func(v): Game.voice_volumes[nm] = v; vl.text = "Hlasitost: %s %d %%" % [nm, int(v * 100)]; Game.save_settings())
		box.add_child(vs)
	var rs := OptionButton.new()
	rs.focus_mode = Control.FOCUS_NONE
	rs.add_theme_font_size_override("font_size", 9)
	var scales := [1.0, 0.75, 0.5]
	for i in scales.size():
		rs.add_item(["Rozlišení 3D: plné (ostré)", "Rozlišení 3D: 75 % (rychlejší)", "Rozlišení 3D: 50 % (slabý počítač)"][i])
		if absf(Game.render_scale - scales[i]) < 0.01:
			rs.select(i)
	rs.item_selected.connect(func(i): Game.render_scale = scales[i]; Game.apply_video(); Game.save_settings())
	box.add_child(rs)

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
	paused = true
	inventory_open = true   # blocks player input the same way
	pause_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _resume() -> void:
	_back_to_game()
	paused = false
	inventory_open = false
	pause_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
