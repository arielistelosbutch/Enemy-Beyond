extends Node
## Puts the chosen Mixamo movements into the game as body clips (tp_body_*) and hand clips:
## --src=<folder with the FBX files and ZIP packs> --out=<folder for the clips> [--overwrite]
## A clip that already exists is left alone unless --overwrite (Ari's own work is never replaced).

const PACK := "Rifle 8-Way Locomotion Pack.zip"
const PISTOL := "Pistol_Handgun Locomotion Pack.zip"
## clip id: [file, file inside the ZIP or "", travel taken out, loop, kind ("body" all bones / "hand" upper body),
##   optionally the part to keep [from, to] in seconds (hand actions: the game stretches it to the action's time)]
const LIST := {
	"tp_body_idle": [PACK, "idle.fbx", true, true, "body"],
	"tp_body_walk": [PACK, "walk forward.fbx", true, true, "body"],
	"tp_body_walk_back": [PACK, "walk backward.fbx", true, true, "body"],
	"tp_body_walk_left": [PACK, "walk left.fbx", true, true, "body"],
	"tp_body_walk_right": [PACK, "walk right.fbx", true, true, "body"],
	"tp_body_run": [PACK, "run forward.fbx", true, true, "body"],
	"tp_body_run_back": [PACK, "run backward.fbx", true, true, "body"],
	"tp_body_run_left": [PACK, "run left.fbx", true, true, "body"],
	"tp_body_run_right": [PACK, "run right.fbx", true, true, "body"],
	"tp_body_sprint": [PACK, "sprint forward.fbx", true, true, "body"],
	"tp_body_crouch": [PACK, "idle crouching.fbx", true, true, "body"],
	"tp_body_crouch_walk": [PACK, "walk crouching forward.fbx", true, true, "body"],
	"tp_body_crouch_walk_back": [PACK, "walk crouching backward.fbx", true, true, "body"],
	"tp_body_crouch_walk_left": [PACK, "walk crouching left.fbx", true, true, "body"],
	"tp_body_crouch_walk_right": [PACK, "walk crouching right.fbx", true, true, "body"],
	"tp_body_prone": ["Prone Forward Stop.fbx", "", true, false, "body"],
	"tp_body_prone_crawl": ["Prone Forward.fbx", "", true, true, "body"],
	"tp_body_crawl_hurt": ["Crawl Forward.fbx", "", true, true, "body"],
	"tp_body_crawl_idle": ["wounded_ground.fbx", "", true, true, "body"],
	"tp_body_dead": [PACK, "death from the front.fbx", false, false, "body"],
	"tp_body_dead_2": [PACK, "death from the back.fbx", false, false, "body"],
	"tp_body_dead_3": [PACK, "death from front headshot.fbx", false, false, "body"],
	"tp_body_dead_4": ["Death_02.fbx", "", false, false, "body"],
	"tp_body_dead_5": ["Dying.fbx", "", false, false, "body"],
	"tp_body_dead_6": ["Dying_01.fbx", "", false, false, "body"],
	"tp_throw_vse": ["toss_granade.fbx", "", true, false, "hand", 0.9, 2.2],
	"tp_reload_vse": ["Reloading.fbx", "", true, false, "hand", 0.5, 2.5],
	"tp_strike_knife": ["Stabbing.fbx", "", true, false, "hand", 0.7, 1.55],
	# 0.54: the rest Ari found
	"tp_body_jump": [PACK, "jump loop.fbx", true, true, "body", -1, -1, "noroot"],
	"tp_body_climb": ["Climbing To Top.fbx", "", true, false, "body", 0.5, 2.6, "noroot"],
	"tp_body_idle_aim": [PACK, "idle aiming.fbx", true, true, "body"],
	"tp_body_crouch_aim": [PACK, "idle crouching aiming.fbx", true, true, "body"],
	"tp_body_prone_reload": ["Prone Reloading.fbx", "", true, false, "body", 0.3, 6.0],
	"tp_body_dig": ["bag_looking.fbx", "", true, true, "body", 2.6, 10.4, "loop"],
	"tp_body_panic": ["Terrified.fbx", "", true, true, "body", 5.4, 16.3, "loop"],
	"tp_reload_crouch_vse": ["reload_duck.fbx", "", true, false, "hand", 0.4, 4.4],
	"tp_throw_crouch_vse": ["toss_granade_duck.fbx", "", true, false, "hand", 0.6, 2.4],
	"tp_strike_stun_baton": ["club_strike.fbx", "", true, false, "hand", 0.3, 1.3],
	"tp_strike_vse": ["pistol_strike.fbx", "", true, false, "hand", 0.15, 0.95],
	"tp_use_vse": ["open_door.fbx", "", true, false, "hand", 0.9, 3.0],
	"tp_hit_1_vse": ["hit_reaction.fbx", "", true, false, "upper", 0.4, 1.6],
	"tp_hit_2_vse": ["hit_reaction2.fbx", "", true, false, "upper"],
	"tp_hit_3_vse": ["hit_reaction3.fbx", "", true, false, "upper", 0.0, 1.2],
	"tp_hit_4_vse": ["hit_on_back.fbx", "", true, false, "upper", 0.0, 0.55],
}

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var src := Game.cmd_arg("src", ProjectSettings.globalize_path("res://animace/Maximo"))
	var out := Game.cmd_arg("out", "res://animace")
	var over := "--overwrite" in OS.get_cmdline_user_args()
	var only := Game.cmd_arg("only", "")
	var target: Node3D = Game.model("merc")
	add_child(target)
	var tsk: Skeleton3D = target.find_child("Skeleton3D", true, false)
	var made := 0
	var kept := 0
	for id in LIST:
		if only != "" and not id in only.split(","):
			continue
		var e: Array = LIST[id]
		var dst := out.path_join(id + ".json")
		if FileAccess.file_exists(dst) and not over:
			print("[INSTALL] %s exists - kept" % id)
			kept += 1
			continue
		var path := src.path_join(e[0])
		if String(e[1]) != "":
			var z := ZIPReader.new()
			if z.open(path) != OK:
				print("[INSTALL] %s: no %s" % [id, path])
				continue
			var bytes := z.read_file(e[1])
			z.close()
			path = OS.get_user_data_dir().path_join("mixamo_tmp.fbx")
			var f := FileAccess.open(path, FileAccess.WRITE)
			f.store_buffer(bytes)
			f.close()
		var holder := Node3D.new()
		add_child(holder)
		var sc := Mocap.load_fbx(path, holder)
		if sc == null:
			print("[INSTALL] %s: cannot read %s" % [id, path])
			holder.queue_free()
			continue
		var nm := "Mixamo: " + (String(e[1]) if String(e[1]) != "" else String(e[0])).get_basename()
		var clip := Mocap.convert(sc, tsk, nm, bool(e[2]))
		holder.queue_free()
		clip["smycka"] = bool(e[3])
		var opt: String = e[7] if e.size() > 7 else ""
		if e.size() > 6 and float(e[5]) >= 0.0:
			Mocap.trim(clip, float(e[5]), float(e[6]))
			if opt != "loop":
				clip["natahnout"] = true      # the game plays it over the action's own time (reload, blow, throw, pull-up)
		if opt == "noroot":
			# the game moves the man itself (a jump, a pull-up): only the limbs
			clip["stopy"].erase("root@pos")
			clip.erase("rychlost")
		match String(e[4]):
			"upper":
				for tr in clip["stopy"].keys():
					if not tr in ["spine", "neck", "head"]:
						clip["stopy"].erase(tr)
				clip.erase("vlastni_poloha")
			"hand":
				for tr in clip["stopy"].keys():
					if not tr in ["spine", "neck", "head"] + Mocap.ARMS:
						clip["stopy"].erase(tr)
				clip.erase("vlastni_poloha")
			"still":
				# one pose: the first moment of the movement, held
				for tr in clip["stopy"].keys():
					var v := AnimClips.sample(clip, tr, 0.0)
					clip["stopy"][tr] = [{"t": 0.0, "v": v}]
				clip["delka"] = 1.0
		var f2 := FileAccess.open(dst, FileAccess.WRITE)
		f2.store_string(JSON.stringify(clip, " ", false))
		f2.close()
		made += 1
		print("[INSTALL] %s <- %s %s" % [id, e[0], e[1]])
	print("RESULT mocapinstall made %d kept %d" % [made, kept])
	get_tree().quit()
