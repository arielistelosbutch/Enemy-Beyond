class_name UiBox
extends StyleBox
## A flat box of the "Čistý taktický" look (0.72): a fill, hairline edges (one screen pixel thick
## at any window size - the canvas is 640x360 stretched, so a normal 1 px line would be 2-3 screen
## pixels) and an optional accent bar on one side (selected rows, the active tab, primary buttons).

var fill := Color(0, 0, 0, 0)
var line := Color(1, 1, 1, 0.14)
var sides := 15                     # which edges get a hairline: 1 left, 2 top, 4 right, 8 bottom
var bar := Color(0, 0, 0, 0)        # accent bar colour (alpha 0 = none)
var bar_side := 0                   # 0 left, 1 top, 2 right, 3 bottom
var bar_px := 2.0                   # bar thickness in screen pixels

static func make(f: Color, l: Color, s := 15, m := Vector4(6, 3, 6, 3)) -> UiBox:
	var b := UiBox.new()
	b.fill = f
	b.line = l
	b.sides = s
	b.content_margin_left = m.x
	b.content_margin_top = m.y
	b.content_margin_right = m.z
	b.content_margin_bottom = m.w
	return b

func with_bar(c: Color, side := 0, px := 2.0) -> UiBox:
	var b: UiBox = duplicate()
	b.bar = c
	b.bar_side = side
	b.bar_px = px
	return b

## Screen pixels per canvas unit (2 at 1280x720, 3 at 1920x1080).
static func scale() -> float:
	var ml := Engine.get_main_loop()
	if ml == null or not (ml is SceneTree):
		return 2.0
	var root: Window = (ml as SceneTree).root
	var base := Vector2(root.content_scale_size)
	if base.x <= 0 or base.y <= 0:
		return 1.0
	var s := Vector2(root.size)
	return maxf(minf(s.x / base.x, s.y / base.y) * root.content_scale_factor, 1.0)

## The thickness of a hairline in canvas units: one screen pixel (two on 4K screens).
static func hair() -> float:
	var k := scale()
	return maxf(1.0, roundf(k / 2.5)) / k

func _draw(ci: RID, r: Rect2) -> void:
	if fill.a > 0.0:
		RenderingServer.canvas_item_add_rect(ci, r, fill)
	var h := hair()
	if line.a > 0.0:
		if sides & 1: RenderingServer.canvas_item_add_rect(ci, Rect2(r.position.x, r.position.y, h, r.size.y), line)
		if sides & 4: RenderingServer.canvas_item_add_rect(ci, Rect2(r.end.x - h, r.position.y, h, r.size.y), line)
		if sides & 2: RenderingServer.canvas_item_add_rect(ci, Rect2(r.position.x, r.position.y, r.size.x, h), line)
		if sides & 8: RenderingServer.canvas_item_add_rect(ci, Rect2(r.position.x, r.end.y - h, r.size.x, h), line)
	if bar.a > 0.0:
		var t := h * bar_px
		var br: Rect2
		match bar_side:
			0: br = Rect2(r.position.x, r.position.y, t, r.size.y)
			1: br = Rect2(r.position.x, r.position.y, r.size.x, t)
			2: br = Rect2(r.end.x - t, r.position.y, t, r.size.y)
			_: br = Rect2(r.position.x, r.end.y - t, r.size.x, t)
		RenderingServer.canvas_item_add_rect(ci, br, bar)
