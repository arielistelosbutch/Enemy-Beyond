extends SceneTree
## (0.72.5) Ari: "after every LC-01 shot an alien is heard". The laser cannon's shot and charge must use
## no creature sound and no pitch far down (the laser zap at 0.55 and the charge at 0.6 groaned).
## Also the fighters' heavy guns in the air (intercept.gd) play their sounds unpitched.
## godot --headless --path . -s tools/test/lcsound.gd
func _initialize() -> void:
	await process_frame
	var G = root.get_node("Game")
	var P = load("res://scripts/player.gd")
	var ok := true
	var all: Array = P.LC_SHOT.duplicate()
	all.append(P.LC_HUM)
	all.append([P.VENT_SOUND[0], P.VENT_SOUND[1], P.VENT_SOUND[2]])
	for s in all:
		var name := String(s[0])
		var pitch := float(s[2])
		var exists := ResourceLoader.exists("res://assets/sounds/%s.wav" % name)
		var alien: bool = name in G.ALIEN_SOUNDS or name.begins_with("core_") or name.ends_with("_hum") or name in ["roar", "hiss", "growl"]
		print("[LC] %s pitch %.2f exists %s alien %s" % [name, pitch, exists, alien])
		ok = ok and exists and not alien and pitch >= P.LC_MIN_PITCH
	# no pitched call left in the LC code (the shot goes through LC_SHOT only)
	var src := FileAccess.get_file_as_string("res://scripts/player.gd")
	var i := src.find("func _lc_fx(")
	var body := src.substr(i, src.find("\nfunc ", i + 5) - i)
	var stray := body.count("Game.play_at(mission, \"") + body.count("Game.play_cut(mission, \"")
	# and no creature voice anywhere in the player's own gun sounds
	var creature := 0
	for v in ["hiss", "roar", "growl", "groan", "alien", "skitter", "sniff", "core_hum"]:      # (swish, zap = blades, fine)
		creature += src.count("Game.play_at(self, \"%s\"" % v) + src.count("Game.play_at(mission, \"%s\"" % v)
	print("[LC] stray play_at in _lc_fx: %d, creature sounds in player.gd: %d" % [stray, creature])
	ok = ok and stray == 0 and creature == 0
	# the air fight: the laser cannon's shot and charge are plain play_ui calls, never pitched
	var isrc := FileAccess.get_file_as_string("res://scripts/intercept.gd")
	var air := isrc.contains("Game.play_ui(self, \"laser\", 0)") and isrc.contains("Game.play_ui(self, \"laser_charge\", -6)")
	print("[LC] air laser cannon sounds plain: %s" % air)
	ok = ok and air
	print("RESULT lcsound %s" % ("ok" if ok else "BAD"))
	quit()
