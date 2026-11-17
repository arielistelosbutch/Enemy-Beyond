extends SceneTree
## (0.72) The dice belong to the profile: leaving the creation screen, dismissing a soldier or making
## another does not give the rolls back; a soldier lost on a mission and a new roster slot do.
## godot --headless --path . -s tools/test/dicetest.gd   (backs up and restores merc.cfg)
const F := "user://merc.cfg"

func _initialize() -> void:
	await process_frame
	var bak = FileAccess.get_file_as_bytes(F) if FileAccess.file_exists(F) else null
	var G = root.get_node("Game")
	var ok := true
	G.mercs = [G.new_merc("Alfa")]
	G.active = 0
	G.merc = G.mercs[0]
	G.dice = {"left": G.DICE_ROLLS, "last": {}, "peak": 1}
	G.save_merc()
	# three rolls, then nothing
	var a = G.dice_roll(); var b = G.dice_roll(); var c = G.dice_roll()
	var d = G.dice_roll()
	var t1: bool = G.dice_left() == 0 and d == c
	print("[DICE] 3 rolls then none, the last stays: %s" % t1)
	# quitting the game (reload of merc.cfg) gives nothing back
	G.dice = {}
	G.load_merc()
	var t2: bool = G.dice_left() == 0 and G.dice_last() == c
	print("[DICE] saved in the profile: %s" % t2)
	# dismissing and hiring into the freed slot: no new rolls
	var i: int = G.hire_merc()          # slot 2 never used -> rolls back
	var t3: bool = i == 1 and G.dice_left() == G.DICE_ROLLS
	G.dice_roll(); G.dice_roll(); G.dice_roll()
	G.dismiss_merc(1)
	G.hire_merc()
	t3 = t3 and G.dice_left() == 0
	print("[DICE] new slot gives rolls, a freed one does not: %s" % t3)
	# a soldier lost on a mission: new rolls; not in a quick mission
	G.skirmish = true
	G.lost_merc()
	var t4: bool = G.dice_left() == 0
	G.skirmish = false
	G.lost_merc()
	t4 = t4 and G.dice_left() == G.DICE_ROLLS and G.dice_last().is_empty()
	print("[DICE] lost soldier gives rolls (not in a quick mission): %s" % t4)
	# an old profile without the dice: as many slots used as soldiers
	var cf := ConfigFile.new()
	cf.load(F)
	cf.set_value("merc", "dice", null)
	cf.save(F)
	G.load_merc()
	var t5: bool = int(G.dice["peak"]) == G.mercs.size() and G.dice_left() == G.DICE_ROLLS
	print("[DICE] old profile: %s" % t5)
	ok = t1 and t2 and t3 and t4 and t5
	if bak == null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(F))
	else:
		var f := FileAccess.open(F, FileAccess.WRITE)
		f.store_buffer(bak)
		f.close()
	print("RESULT dicetest %s" % ("ok" if ok else "FAIL"))
	quit()
