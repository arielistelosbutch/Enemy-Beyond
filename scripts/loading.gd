extends CanvasLayer
## 0.66 Facelift I (Ari): the loading screen. Pictures made in the game (soldiers and aliens shooting at
## each other) slowly cross-fade while a mission, the globe or an air fight is being built, with a short
## line under them - in the menus' own steel style (UiSkin). It hangs under Game (an autoload), so it
## outlives the scene change: Game.load_scene(path) shows it, waits until it is drawn, changes the scene,
## and when the new scene runs it keeps it a moment longer (a mission ~3 s, so a picture or two pass)
## and fades into it.
## Pictures: assets/ui/loading/*.png (made by --autotest=loadshots). Lines: tips on easy/normal; on
## hardcore only atmosphere (no hints there), never anything about how strong the aliens are.

const DIR := "res://assets/ui/loading"
const SLIDE := 4.2           # one picture stays this long...
const XFADE := 1.6           # ...and melts into the next for this long
const MIN_MISSION := 3.4     # a mission's loading screen stays at least this long (seconds in all)
const MIN_OTHER := 0.9
const FADE_IN := 0.35
const FADE_OUT := 0.7

const TIPS := [
	"Batoh je pomalý. Co budeš potřebovat hned, nos na opasku.",
	"Svítilna na helmě tě ukáže dřív, než uvidíš ty je.",
	"Přikrčený a vleže tě vidí z menší dálky. Sprint je slyšet.",
	"Raněného spolubojovníka odtáhneš klávesou F. Krvácí, nečekej.",
	"Zavřené ocelové dveře na základně je zdrží. Ne navždy.",
	"Kouřový granát kryje ústup i oživování.",
	"Před misí zkontroluj výstroj: co nevezmeš, na místě nenajdeš.",
	"Díly na zbrani mají svou váhu. Přetížený voják je pomalý.",
	"Mrtvý voják se nevrací. Nový začíná od nuly.",
	"Vysílačka v ruce: drž T a mluv s týmem na dálku.",
	"Úspěšná mise přinese kořist pro výzkum. Těla, zbraně, trosky.",
	"Strážce v singlu hlídá záda, ale za tebe bojovat nebude.",
	"Šablona vojáka a sada výstroje ušetří čas, když někdo padne.",
	"V co-opu se drž u týmu. Kdo se oddělí, toho si najdou.",
	"Nábojů není nikdy dost. Přebíjej v krytu.",
]
const MOOD := [
	"Noc je dlouhá. Ne všichni se vrátí.",
	"Velín čeká na hlášení.",
	"Někde tam venku něco poslouchá.",
	"Kondor startuje. Žádná cesta zpátky.",
	"Projekt X nemá druhou šanci.",
	"Ticho v rádiu neznamená klid.",
	"Zapiš si jména. Až se vrátíš, budeš je potřebovat.",
	"Rok 1990. Svět ještě neví, co přichází.",
]

var _root: Control
var _pics: Array[TextureRect] = []
var _tex: Array = []
var _k := 0
var _t := 0.0                # time since shown
var _slide_t := 0.0
var _fade_out := -1.0
var _done := false           # the new scene is running
var _min := MIN_OTHER
var _line: Label
var _what: Label
var _frames_after := 0

static func pictures() -> Array:
	var out := []
	var names: PackedStringArray = ResourceLoader.list_directory(DIR) if ResourceLoader.has_method("list_directory") else PackedStringArray()
	if names.is_empty():
		var d := DirAccess.open(DIR)
		if d:
			for f in d.get_files():
				names.append(f.trim_suffix(".import"))
	for f in names:
		if f.ends_with(".png") and not f in out:
			out.append(f)
	out.sort()
	return out

func setup(what: String, mission: bool) -> void:
	layer = 120
	name = "Loading"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_min = MIN_MISSION if mission else MIN_OTHER
	if Game.autotest() != "":
		_min = 0.0
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var black := ColorRect.new()
	black.color = Color(0, 0, 0)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(black)
	var files := pictures()
	files.shuffle()
	for f in files.slice(0, 6):
		var tx: Texture2D = load(DIR + "/" + f)
		if tx:
			_tex.append(tx)
	if _tex.is_empty():
		_tex.append(UiSkin.backdrop())
	for i in 2:
		var tr := TextureRect.new()
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.modulate.a = 0.0
		_root.add_child(tr)
		_pics.append(tr)
	_pics[0].texture = _tex[0]
	_pics[0].modulate.a = 1.0
	# a dark band at the bottom: what is loading (with the blinking terminal dots inside its plate), one
	# line under it. (Ari: "text občas mimo tabulku" - the dots used to blink right of the plate and the
	# line had a fixed box.) Now everything sits in containers and the band grows up to fit what it holds.
	var band := PanelContainer.new()
	band.add_theme_stylebox_override("panel", UiSkin.panel())
	band.anchor_left = 0.0
	band.anchor_right = 1.0
	band.anchor_top = 1.0
	band.anchor_bottom = 1.0
	band.offset_left = 18
	band.offset_right = -18
	band.offset_top = -12
	band.offset_bottom = -12
	band.grow_vertical = Control.GROW_DIRECTION_BEGIN
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(band)
	var mc := MarginContainer.new()
	for side in ["left", "right"]:
		mc.add_theme_constant_override("margin_" + side, 8)
	mc.add_theme_constant_override("margin_top", 3)
	mc.add_theme_constant_override("margin_bottom", 3)
	mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(mc)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mc.add_child(col)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	_what = Label.new()
	_what.set_meta("what", what.to_upper())
	UiSkin.title(_what, 11)
	_what.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_what.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(_what)
	set_what(what)
	_line = Label.new()
	_line.add_theme_font_size_override("font_size", 9)
	_line.add_theme_color_override("font_color", Color(0.80, 0.90, 1.0))
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_line.custom_minimum_size.x = 120
	col.add_child(_line)
	_line.text = line()
	_root.modulate.a = 0.0

## What is loading ("MISE", "GLÓBUS"...). The blinking dots belong to the same text, padded with
## spaces to three, so the plate keeps its width and nothing blinks outside it.
func set_what(what: String) -> void:
	_what.set_meta("what", what.to_upper())
	_what.custom_minimum_size.x = 0.0
	_set_dots(3)
	_what.custom_minimum_size.x = _what.get_minimum_size().x

func _set_dots(n: int) -> void:
	_what.text = String(_what.get_meta("what", "")) + " " + ".".repeat(n) + " ".repeat(3 - n)

## The line under the picture: a tip (easy, normal) or only the mood (hardcore - no hints there).
static func line() -> String:
	var pool: Array = MOOD if Game.veteran() else TIPS + MOOD
	return pool[randi() % pool.size()]

## The new scene is up (Game.load_scene calls it after the change): from now the clock to fade out runs.
func scene_ready() -> void:
	_done = true
	_frames_after = 0

func busy() -> bool:
	return _fade_out < 0.0 or _fade_out < FADE_OUT * 0.5

func _process(delta: float) -> void:
	delta = minf(delta, 0.1)       # (the frame that built the mission is long - do not jump the fade)
	_t += delta
	_slide_t += delta
	_set_dots(1 + int(_t * 2.5) % 3)
	if _fade_out < 0.0:
		_root.modulate.a = minf(1.0, _t / FADE_IN)
	# the next picture slowly comes over the current one
	if _tex.size() > 1 and _slide_t > SLIDE:
		var f := clampf((_slide_t - SLIDE) / XFADE, 0.0, 1.0)
		var nxt := (_k + 1) % _tex.size()
		_pics[1].texture = _tex[nxt]
		_pics[1].modulate.a = f
		if f >= 1.0:
			_k = nxt
			_pics[0].texture = _tex[_k]
			_pics[1].modulate.a = 0.0
			_slide_t = 0.0
			_line.text = line()
	if _done:
		_frames_after += 1
		if _fade_out < 0.0 and _frames_after > 3 and _t >= _min:
			_fade_out = 0.0
	if _fade_out >= 0.0:
		_fade_out += delta
		_root.modulate.a = 1.0 - clampf(_fade_out / FADE_OUT, 0.0, 1.0)
		_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _fade_out >= FADE_OUT:
			queue_free()
