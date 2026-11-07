class_name EditorTabs
## One editor for the whole game (only in the Godot editor, never in a released build): the tabs
## along the top switch between its parts, the line along the bottom says what the mouse and the
## keys do right now (as in the Svitky Světlenu editor).

const TABS := [["models", "Modely", "res://scenes/Modeler.tscn"], ["hands", "Zbraně v rukou", "res://scenes/Workshop.tscn"],
	["tiles", "Mapové díly", "res://scenes/TileEditor.tscn"]]      # (0.57: no Animace tab - the movements come from Mixamo)

## The tab bar along the top; @a active is the part that is open now.
static func add(parent: Control, active: String) -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.position = Vector2(6, 2)
	bar.size = Vector2(628, 16)
	bar.add_theme_constant_override("separation", 3)
	parent.add_child(bar)
	var t := Label.new()
	t.text = "EDITOR"
	UiSkin.title(t, 10)
	t.custom_minimum_size = Vector2(56, 0)
	bar.add_child(t)
	for tab in TABS:
		var b := Button.new()
		b.text = tab[1]
		b.add_theme_font_size_override("font_size", 8)
		b.custom_minimum_size = Vector2(96, 15)
		b.focus_mode = Control.FOCUS_NONE
		UiSkin.button(b)
		if not ResourceLoader.exists(tab[2]):
			b.disabled = true
			b.tooltip_text = "Připravuje se"
			b.text = tab[1] + " (brzy)"
		elif tab[0] == active:
			b.disabled = true
			b.add_theme_color_override("font_disabled_color", UiSkin.AMBER)
		else:
			var path: String = tab[2]
			b.pressed.connect(func(): parent.get_tree().change_scene_to_file(path))
		bar.add_child(b)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(sp)
	var back := Button.new()
	back.text = "Do menu"
	back.add_theme_font_size_override("font_size", 8)
	back.custom_minimum_size = Vector2(60, 15)
	back.focus_mode = Control.FOCUS_NONE
	UiSkin.button(back)
	back.pressed.connect(func(): parent.get_tree().change_scene_to_file("res://scenes/Main.tscn"))
	bar.add_child(back)
	return bar

## The help line along the bottom.
static func hint(parent: Control) -> Label:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiSkin.inset(2))
	p.position = Vector2(6, 336)
	p.size = Vector2(628, 22)
	parent.add_child(p)
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 7)
	l.add_theme_color_override("font_color", UiSkin.DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(620, 0)
	p.add_child(l)
	return l
