extends Control
class_name EmoteWheel
## 0.57 (Ari): the emote wheel - hold J, move the mouse towards an emote, let go. A ring of plates
## in the menus' look (gunmetal, cyan glow); the mouse only picks a direction (it stays captured,
## the view does not turn while the wheel is open). Tap J alone: a quick salute (the player's).

var names: Array = []          # the labels round the ring, clockwise from the top
var pick := -1
var _aim := Vector2.ZERO
const R_IN := 52.0
const R_OUT := 150.0

func _init(labels: Array) -> void:
	names = labels
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_aim += (event as InputEventMouseMotion).screen_relative * 0.5
		if _aim.length() > 90.0:
			_aim = _aim.normalized() * 90.0
		pick = -1
		if _aim.length() > 18.0 and not names.is_empty():
			var a := fposmod(atan2(_aim.x, -_aim.y), TAU)      # 0 at the top, clockwise
			pick = int(floor(a / TAU * names.size() + 0.5)) % names.size()
		queue_redraw()
		get_viewport().set_input_as_handled()

func _draw() -> void:
	var c := get_viewport_rect().size / 2.0
	var n := maxi(1, names.size())
	var step := TAU / n
	draw_circle(c, R_OUT + 8.0, Color(0.02, 0.03, 0.035, 0.55))
	for i in n:
		var a0 := -PI / 2 + (i - 0.5) * step
		var pts := PackedVector2Array()
		for k in 9:
			var a := a0 + step * k / 8.0
			pts.append(c + Vector2(cos(a), sin(a)) * R_OUT)
		for k in 9:
			var a := a0 + step * (8 - k) / 8.0
			pts.append(c + Vector2(cos(a), sin(a)) * R_IN)
		var on := i == pick
		draw_colored_polygon(pts, Color(0.10, 0.20, 0.23, 0.92) if on else Color(0.12, 0.135, 0.15, 0.86))
		var edge := pts.duplicate()
		edge.append(pts[0])
		draw_polyline(edge, Color(UiSkin.GLOW, 0.95) if on else Color(0.30, 0.35, 0.38, 0.9), 1.0)
	var f := UiSkin.font(true)
	for i in n:
		var a := -PI / 2 + i * step
		var r := (R_IN + R_OUT) / 2.0 + (16.0 if i % 2 == 0 else -16.0) * (1.0 if n > 12 else 0.0)
		var txt := String(names[i])
		var fs := 8
		var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p := c + Vector2(cos(a), sin(a)) * r - Vector2(w / 2.0, -3.0)
		draw_string(f, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiSkin.AMBER if i == pick else UiSkin.TEXT)
	# the middle: what will be done, and where the mouse points
	draw_circle(c, R_IN - 4.0, Color(0.05, 0.06, 0.07, 0.92))
	var mid := String(names[pick]) if pick >= 0 else "Emoce"
	var mw := f.get_string_size(mid, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	draw_string(f, c + Vector2(-mw / 2.0, 3.0), mid, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UiSkin.AMBER if pick >= 0 else UiSkin.DIM)
	if _aim.length() > 4.0:
		draw_line(c, c + _aim.normalized() * (R_IN - 6.0), Color(UiSkin.GLOW, 0.8), 1.0)
