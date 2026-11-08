extends Node
## 0.57: Ari's own movements from afk.ai onto the soldier, in place of the Mixamo ones (the same
## clip ids, so the game takes them as before). One afk export holds all of them:
## --src=<afk GLB of the soldier>[,<another>...] --out=<folder for the clips> [--only=a,b]
## Several exports: each movement is taken from the last one that has it (a newer export wins).
## "file.glb:Pistol_" takes only the movements whose name starts so from that export (Ari's packs
## that fix the holding: -pistoles only for Pistol_*, -rifles only for Rifle_*, the heavy one only in --set=heavy).
## Only clips that came from Mixamo (or afk) are replaced - Ari's own work only with "force"
## (Ari asked for the salute and at-ease from afk; the old ones are in animace/Maximo/zaloha_mixamo).
## A movement without a gun (afk has e.g. a walk backward only empty-handed) gets the arms of a
## movement with one ("arms": the legs from one, the arms from the other), so the gun still sits.

## clip id: [afk movement, travel taken out, loop, kind ("body" / "hand" / "upper"), from, to, option, arms from]
## from/to in seconds (-1 = all); options (any of): "noroot" / "noyaw" / "mirror" / "loop" / "force"
const LIST := {
	"tp_body_idle": ["Rifle_Idle", true, true, "body"],
	# standing about: one of these each time he stops (his own legs and head, the gun in his hands)
	"tp_body_idle_2": ["Look_Around", true, true, "body", -1, -1, "", "Rifle_Idle"],
	"tp_body_idle_3": ["Idle_A", true, true, "body", -1, -1, "", "Rifle_Idle"],
	"tp_body_idle_4": ["Idle_Neutral", true, true, "body", -1, -1, "", "Rifle_Idle"],
	"tp_body_idle_5": ["Idle_Subtle", true, true, "body", -1, -1, "", "Rifle_Idle"],
	# badly hurt
	"tp_body_idle_hurt": ["Idle_Injured", true, true, "body", -1, -1, "", "Rifle_Idle"],
	"tp_body_walk_hurt": ["Injured_Walk", true, true, "body", -1, -1, "", "Rifle_Walk"],
	"tp_body_run_hurt": ["Injured_Run", true, true, "body", -1, -1, "", "Rifle_Run"],
	"tp_body_fall": ["Fall_Loop", true, true, "body", -1, -1, "noroot", "Rifle_Jump"],
	"tp_body_idle_aim": ["Rifle_Aim_Idle", true, true, "body"],
	# shooting: the gun kicks (standing, walking, running; a handgun standing)
	"tp_body_fire": ["Rifle_Fire", true, true, "body"],
	"tp_body_fire_walk": ["Rifle_Fire_Walk", true, true, "body"],
	"tp_body_fire_run": ["Rifle_Fire_Run", true, true, "body"],
	"tp_body_fire_pistol": ["Pistol_Shoot", true, true, "body"],
	"tp_body_walk": ["Rifle_Walk", true, true, "body"],
	"tp_body_walk_back": ["Walk_Backwards", true, true, "body", -1, -1, "", "Rifle_Walk"],
	"tp_body_walk_left": ["Rifle_Strafe_Left", true, true, "body"],
	"tp_body_walk_right": ["Rifle_Strafe_Right", true, true, "body"],
	"tp_body_run": ["Rifle_Run", true, true, "body"],
	"tp_body_run_back": ["Rifle_Run_Back", true, true, "body"],
	"tp_body_run_left": ["Run_Strafe_Left", true, true, "body", -1, -1, "", "Rifle_Run_Aimed"],
	"tp_body_run_right": ["Run_Strafe_Right", true, true, "body", -1, -1, "", "Rifle_Run_Aimed"],
	"tp_body_sprint": ["Sprint", true, true, "body", -1, -1, "", "Rifle_Run"],
	"tp_body_crouch": ["Rifle_Kneel_Idle", true, true, "body"],
	# on one knee: aiming, and shooting (the kick of the standing fire in the arms); afk's Rifle_Fire_Crouch
	# is shooting while going forward crouched (Ari: on the spot he seemed to walk)
	"tp_body_crouch_aim": ["Rifle_Kneel_Idle", true, true, "body", -1, -1, "", "Rifle_Aim_Idle"],
	"tp_body_crouch_fire": ["Rifle_Kneel_Idle", true, true, "body", -1, -1, "", "Rifle_Fire"],
	"tp_body_crouch_fire_walk": ["Rifle_Fire_Crouch", true, true, "body"],
	"tp_body_crouch_fire_pistol": ["Pistol_Kneel_Idle", true, true, "body", -1, -1, "", "Pistol_Shoot"],
	"tp_body_crouch_walk": ["Rifle_Crouch_Walk", true, true, "body"],
	"tp_body_crouch_walk_back": ["Crouch_Walk_Back", true, true, "body", -1, -1, "", "Rifle_Crouch_Walk"],
	"tp_body_crouch_walk_left": ["Crouch_Strafe_Left", true, true, "body", -1, -1, "", "Rifle_Crouch_Walk"],
	"tp_body_crouch_walk_right": ["Crouch_Strafe_Right", true, true, "body", -1, -1, "", "Rifle_Crouch_Walk"],
	"tp_body_prone": ["Rifle_Prone_Idle", true, true, "body"],
	"tp_body_prone_crawl": ["Prone_Crawl", true, true, "body"],
	"tp_body_crawl_idle": ["Low_Crawl", true, true, "still"],      # (Ari: he stays on his belly)
	"tp_body_crawl_hurt": ["Low_Crawl", true, true, "body"],
	"tp_body_jump": ["Rifle_Jump", true, false, "body", -1, -1, "noroot"],
	"tp_body_turn_left": ["Rifle_Turn", true, true, "body", -1, -1, "noyaw"],
	"tp_body_turn_right": ["Rifle_Turn", true, true, "body", -1, -1, "noyaw mirror"],
	"tp_body_climb": ["ClimbUp_1m_RM", true, false, "body", 0.0, 99.0, "noroot"],
	"tp_body_dig": ["Kneel_Inspect", true, true, "body"],
	"tp_body_panic": ["Terrified", true, true, "body"],
	"tp_body_dead": ["Rifle_Death", false, false, "body"],
	"tp_body_dead_2": ["Death_Backward", false, false, "body"],
	"tp_body_dead_3": ["Death_Headshot", false, false, "body"],
	"tp_body_dead_4": ["Death_Forward", false, false, "body"],
	"tp_body_dead_5": ["Death_To_Knees", false, false, "body"],
	"tp_body_dead_6": ["Death_Left", false, false, "body"],
	"tp_body_dead_7": ["Death_Right", false, false, "body"],
	"tp_body_dead_8": ["Fall_Over", false, false, "body"],
	"tp_body_dead_crouch": ["Death_Crouching", false, false, "body"],
	"tp_body_idle_pistol": ["Pistol_Idle", true, true, "body"],
	"tp_body_walk_pistol": ["Pistol_Walk", true, true, "body"],
	"tp_body_walk_back_pistol": ["Walk_Backwards", true, true, "body", -1, -1, "", "Pistol_Idle"],
	"tp_body_walk_left_pistol": ["Strafe_left", true, true, "body", -1, -1, "", "Pistol_Idle"],
	"tp_body_walk_right_pistol": ["Strafe_right", true, true, "body", -1, -1, "", "Pistol_Idle"],
	"tp_body_run_pistol": ["Pistol_Run", true, true, "body"],
	"tp_body_run_back_pistol": ["Pistol_Run_Back", true, true, "body"],
	"tp_body_crouch_pistol": ["Pistol_Kneel_Idle", true, true, "body"],
	"tp_body_crouch_aim_pistol": ["Pistol_Kneel_Idle", true, true, "body"],
	"tp_body_idle_aim_pistol": ["Pistol_Aim_Neutral", true, true, "body"],
	"tp_body_jump_pistol": ["Pistol_Jump", true, false, "body", -1, -1, "noroot"],
	"tp_body_sprint_pistol": ["Sprint", true, true, "body", -1, -1, "", "Pistol_Run"],
	"tp_body_run_left_pistol": ["Run_Strafe_Left", true, true, "body", -1, -1, "", "Pistol_Run"],
	"tp_body_run_right_pistol": ["Run_Strafe_Right", true, true, "body", -1, -1, "", "Pistol_Run"],
	"tp_body_crouch_walk_pistol": ["Rifle_Crouch_Walk", true, true, "body", -1, -1, "", "Pistol_Idle"],
	"tp_body_crouch_walk_back_pistol": ["Crouch_Walk_Back", true, true, "body", -1, -1, "", "Pistol_Idle"],
	"tp_body_crouch_walk_left_pistol": ["Crouch_Strafe_Left", true, true, "body", -1, -1, "", "Pistol_Idle"],
	"tp_body_crouch_walk_right_pistol": ["Crouch_Strafe_Right", true, true, "body", -1, -1, "", "Pistol_Idle"],
	"tp_body_turn_left_pistol": ["Rifle_Turn", true, true, "body", -1, -1, "noyaw", "Pistol_Idle"],
	"tp_body_turn_right_pistol": ["Rifle_Turn", true, true, "body", -1, -1, "noyaw mirror", "Pistol_Idle"],
	"tp_reload_vse": ["Rifle_Reload", true, false, "hand", 0.0, 99.0],
	"tp_reload_crouch_vse": ["Rifle_Reload", true, false, "hand", 0.0, 99.0],
	"tp_reload_pistol": ["Pistol_Reload", true, false, "hand", 0.0, 99.0],
	"tp_reload_magnum": ["Pistol_Reload", true, false, "hand", 0.0, 99.0],
	"tp_reload_plasma_pistol": ["Pistol_Reload", true, false, "hand", 0.0, 99.0],
	"tp_throw_vse": ["Grenade_Toss", true, false, "hand", 0.3, 2.2],
	"tp_throw_crouch_vse": ["Grenade_Toss", true, false, "hand", 0.3, 2.2],
	"tp_strike_vse": ["Rifle_Butt", true, false, "hand", 0.0, 99.0],
	"tp_strike_knife": ["Knife_Stab", true, false, "hand", 0.0, 99.0],
	"tp_strike_stun_baton": ["Sword_Attack", true, false, "hand", 0.0, 99.0],
	"tp_heal_vse": ["Fixing_Kneeling", true, true, "hand"],
	"tp_salute_vse": ["Salute", true, false, "hand", -1, -1, "force"],
	# drawing a weapon (while "Beru: ..." runs): a long gun off the back, a handgun from the hip
	"tp_draw_vse": ["Rifle_Pull_Out", true, false, "hand", 0.0, 99.0],
	"tp_drawp_vse": ["Pistol_Draw", true, false, "hand", 0.0, 99.0],
	# the emote wheel (hold J): the whole man, in place
	"tp_emote_yes": ["Yes", true, false, "body"],
	"tp_emote_no": ["No", true, false, "body"],
	"tp_emote_wave": ["Raise_Hand", true, false, "body"],
	"tp_emote_question": ["Ask_Question", true, false, "body"],
	"tp_emote_talk": ["Talk", true, true, "body"],
	"tp_emote_phone": ["Idle_TalkingPhone", true, true, "body"],
	"tp_emote_help": ["Help_Two_Arms", true, false, "body"],
	"tp_emote_fist": ["Shake_Fist", true, false, "body"],
	"tp_emote_bow": ["Bow_Casual", true, false, "body"],
	"tp_emote_stretch": ["Stretch_Arms", true, false, "body"],
	"tp_emote_eat": ["Consume Item", true, false, "body"],
	"tp_emote_cold": ["Shivering", true, true, "body"],
	"tp_emote_tired": ["Tired Hunched", true, true, "body"],
	"tp_emote_pushup": ["Pushup", true, true, "body"],
	"tp_emote_jacks": ["Jumping Jacks", true, true, "body"],
	"tp_emote_dance": ["Dance_Groove", true, true, "body"],
	"tp_emote_dance2": ["Dance Charleston", true, true, "body"],
	"tp_emote_sit_in": ["Sitting_Enter", true, false, "body"],
	"tp_emote_sit": ["Sitting_Idle", true, true, "body"],
	"tp_emote_sit_out": ["Sitting_Exit", true, false, "body"],
	"tp_atease_vse": ["Idle_FoldArms", true, true, "body", -1, -1, "noroot force"],
	"tp_use_vse": ["Interact", true, false, "hand", 0.0, 99.0],
	"tp_hit_1_vse": ["Hit_Small_Front", true, false, "upper"],
	"tp_hit_2_vse": ["Hit_Large_Front", true, false, "upper", 0.0, 1.2],
	"tp_hit_3_vse": ["Hit_Small_Left", true, false, "upper"],
	"tp_hit_4_vse": ["Hit_Small_Back", true, false, "upper"],
	"tp_hit_5_vse": ["Hit_Small_Right", true, false, "upper"],
	"tp_hit_6_vse": ["Hit_Large_Left", true, false, "upper", 0.0, 1.2],
	"tp_hit_7_vse": ["Hit_Large_Right", true, false, "upper", 0.0, 1.2],
	"tp_hit_8_vse": ["Rifle_Hit", true, false, "upper"],
}

## 0.57: --race=<race>: Ari's afk.ai movements for an alien whose game model has our merc's bones
## (grey, zombie...). The clips go to animace/al_<race>_<clip>.json and alien.gd takes them in place of
## the model's own (an officer takes his ordinary race's ones unless he has his own). The aliens are not
## shown mirrored like the merc, so every movement is mirrored here (the gun stays in the hand the model holds it in).
## clip: [afk movement, travel taken out, loop, kind, from, to, option, arms from] (as LIST)
const RACE_LISTS := {
	"grey": {
		"idle": ["Pistol_Idle", true, true, "body"],
		"walk": ["Pistol_Walk", true, true, "body"],
		"run": ["Pistol_Run", true, true, "body"],
		"aim": ["Pistol_Aim_Neutral", true, true, "body"],
		"lurk": ["Pistol_Kneel_Idle", true, true, "body"],
		"death_1": ["Death_A", false, false, "body"],
		"death_2": ["Death_B", false, false, "body"],
		"death_3": ["Death_C", false, false, "body"],
		"death_4": ["Death_D", false, false, "body"],
		"death_5": ["Death_Flying_Back", false, false, "body"],
		"death_6": ["Rifle_Death", false, false, "body"],
		"death_crouch": ["Death_Crouching", false, false, "body"],
	},
	# the officer: his psionic strike (alien._psi_fx plays "attack"; the rest he takes from "grey")
	"grey_velitel": {
		"attack": ["Spell_Simple_Idle", true, true, "body"],
	},
	# the Bijec officer keeps his own model (cape, red armour): Ari's Bijec movements put on his bones
	# (the plain Bijec is Ari's afk model itself, alien.AFK_MODELS)
	"bijec_velitel": {
		"idle": ["Rifle_Idle", true, true, "body"],
		"walk": ["Rifle_Walk", true, true, "body"],
		"run": ["Rifle_Run", true, true, "body"],
		"aim": ["Rifle_Aim_Idle", true, true, "body"],
		"lurk": ["Rifle_Kneel_Idle", true, true, "body"],
		"lurk_walk": ["Rifle_Crouch_Walk", true, true, "body"],
		"fire": ["Rifle_Fire", true, true, "body"],
		"attack": ["Rifle_Butt", true, false, "body"],
		"roar": ["Roar", true, false, "body"],
		"death_1": ["Death_B", false, false, "body"],
		"death_2": ["Death_D", false, false, "body"],
		"death_3": ["Death_Backward", false, false, "body"],
		"death_4": ["Death_Flying_Back", false, false, "body"],
		"death_5": ["Death_Headshot", false, false, "body"],
		"death_6": ["Death_Left", false, false, "body"],
		"death_7": ["Death_Right", false, false, "body"],
		"death_8": ["Death_To_Knees", false, false, "body"],
		"death_9": ["Rifle_Death", false, false, "body"],
		"death_crouch": ["Death_Crouching", false, false, "body"],
	},
}

## --set=heavy: the same movements for the heavy guns (cannons, miniguns, the rocket launcher) from
## Ari's heavy pack (give it LAST in --src: its Rifle_* movements win, the legs of the empty-handed
## ones still come from the others) - ids with "_heavy" (player.HEAVY picks them), and the hands'
## reload and butt-stroke for each heavy gun. Never mixed into the ordinary set.
const HEAVY_ITEMS := ["minigun", "laser_minigun", "plasma_minigun", "plasma_cannon", "autocannon", "a_heavy", "rocket_launcher", "laser_cannon"]
func _heavy_list(heavy_ap: AnimationPlayer) -> Dictionary:
	var out := {}
	for id: String in LIST:
		var e: Array = LIST[id]
		if not id.begins_with("tp_body_") or id.ends_with("_pistol") or id.contains("_hurt") or id.begins_with("tp_body_dead") or id.begins_with("tp_body_idle_") and id != "tp_body_idle_aim":
			continue
		var arms: String = e[7] if e.size() > 7 else ""
		if heavy_ap.has_animation(String(e[0])) and String(e[0]).begins_with("Rifle_") or (arms != "" and heavy_ap.has_animation(arms)):
			out[id + "_heavy"] = e
	for it in HEAVY_ITEMS:
		out["tp_reload_" + it] = ["Rifle_Reload", true, false, "hand", 0.0, 99.0]
		out["tp_strike_" + it] = ["Rifle_Butt", true, false, "hand", 0.0, 99.0]
	return out

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var srcs := Game.cmd_arg("src", "").split(",")
	var out := Game.cmd_arg("out", "res://animace")
	var only := Game.cmd_arg("only", "")
	var race := Game.cmd_arg("race", "")
	if race != "" and not RACE_LISTS.has(race):
		print("RESULT afkinstall no list for race %s" % race)
		get_tree().quit()
		return
	var target: Node3D = Game.model("merc" if race == "" else race)
	add_child(target)
	var tsk: Skeleton3D = target.find_child("Skeleton3D", true, false)
	var holder := Node3D.new()
	add_child(holder)
	var scenes := []
	var only_pre := []       # per export: "" or the only movements taken from it ("file.glb:Pistol_")
	for src in srcs:
		var path := src
		var pre := ""
		if src.rfind(":") > 2:          # (not the drive letter of a Windows path)
			path = src.substr(0, src.rfind(":"))
			pre = src.substr(src.rfind(":") + 1)
		var one := Mocap.load_glb(path, holder)
		if one == null:
			print("RESULT afkinstall cannot read %s" % path)
			get_tree().quit()
			return
		scenes.push_front(one)          # the newest first
		only_pre.push_front(pre)
	var pick := func(anim: String) -> Node:
		for k in scenes.size():
			var one: Node = scenes[k]
			if String(only_pre[k]) != "" and not anim.begins_with(String(only_pre[k])):
				continue
			var ap: AnimationPlayer = one.find_children("*", "AnimationPlayer", true, false)[0]
			if ap.has_animation(anim):
				return one
		return null
	var made := 0
	var kept := 0
	var cache := {}
	var list := LIST
	if race != "":
		list = {}
		for c in RACE_LISTS[race]:
			list["al_%s_%s" % [race, c]] = RACE_LISTS[race][c]
	if Game.cmd_arg("set", "") == "heavy":
		list = _heavy_list(scenes[0].find_children("*", "AnimationPlayer", true, false)[0])
	for id in list:
		if only != "" and not id in only.split(","):
			continue
		var e: Array = list[id]
		var dst := out.path_join(id + ".json")
		var opt: String = e[6] if e.size() > 6 else ""
		if race != "":
			opt += " mirror"
		if FileAccess.file_exists(dst) and not "force" in opt:
			var old := AnimClips.get_clip(id)
			if not String(old.get("zdroj", "")) in ["Mixamo", "afk"]:
				print("[AFK] %s is Ari's own - kept" % id)
				kept += 1
				continue
		var sc: Node = pick.call(String(e[0]))
		var clip := Mocap.convert(sc, tsk, "afk: " + String(e[0]), bool(e[1]), 30.0, String(e[0])) if sc else {}
		if clip.is_empty():
			print("[AFK] %s: no movement %s" % [id, e[0]])
			continue
		clip["zdroj"] = "afk"
		clip["smycka"] = bool(e[2])
		var arms_from: String = e[7] if e.size() > 7 else ""
		if arms_from != "":
			if not cache.has(arms_from):
				var asc: Node = pick.call(arms_from)
				cache[arms_from] = Mocap.convert(asc, tsk, arms_from, true, 30.0, arms_from) if asc else {}
			_arms(clip, cache[arms_from])
			clip["nazev"] = "afk: %s + ruce %s" % [e[0], arms_from]
		if e.size() > 5 and float(e[4]) >= 0.0:
			Mocap.trim(clip, float(e[4]), minf(float(e[5]), float(clip.get("delka", 1.0))))
			if opt != "loop":
				clip["natahnout"] = true
		if "noroot" in opt:
			clip["stopy"].erase("root@pos")
			clip.erase("rychlost")
		if "noyaw" in opt:
			# the body turns with the player: only the steps on the spot, not the hips' own turn
			var ht: Array = clip["stopy"].get("hips", [])
			if not ht.is_empty():
				print("[AFK] %s hips yaw %.0f -> %.0f" % [id, float(ht[0]["v"][1]), float(ht[-1]["v"][1])])
				var y0: float = float(ht[0]["v"][1])
				for key in ht:
					key["v"][1] = y0
			clip["stopy"].erase("root@pos")
		if "mirror" in opt:
			# the same movement the other way (left <-> right)
			var st := {}
			for tr in clip["stopy"]:
				var o: String = tr
				if tr.ends_with(".L"): o = tr.trim_suffix(".L") + ".R"
				elif tr.ends_with(".R"): o = tr.trim_suffix(".R") + ".L"
				for key in clip["stopy"][tr]:
					var v: Array = key["v"]
					key["v"] = [-float(v[0]), float(v[1]), float(v[2])] if tr == "root@pos" else [v[0], -float(v[1]), -float(v[2])]
				st[o] = clip["stopy"][tr]
			clip["stopy"] = st
		match String(e[3]):
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
		print("[AFK] %s <- %s" % [id, e[0]])
	holder.queue_free()
	print("RESULT afkinstall made %d kept %d" % [made, kept])
	get_tree().quit()

## The arms of @a src over @a c (stretched to its length: both loop).
func _arms(c: Dictionary, src: Dictionary) -> void:
	var lc := float(c.get("delka", 1.0))
	var ls := maxf(0.01, float(src.get("delka", 1.0)))
	for tr in Mocap.ARMS:
		var keys: Array = src.get("stopy", {}).get(tr, [])
		if keys.is_empty():
			continue
		var nk := []
		for k in keys:
			var d: Dictionary = (k as Dictionary).duplicate(true)
			d["t"] = snappedf(float(k["t"]) * lc / ls, 0.01)
			nk.append(d)
		c["stopy"][tr] = nk
