extends SceneTree
## (0.7x nové mise) Kampaň: Štěnice na lodi a Radarová stanice bez hraní mise.
## godot --headless --path . -s tools/test/missiontypes.gd   (zálohuje a vrátí campaign.cfg)
const FILES := ["user://campaign.cfg"]
var bak := {}

func _initialize() -> void:
	await process_frame
	for f in FILES:
		bak[f] = FileAccess.get_file_as_bytes(f) if FileAccess.file_exists(f) else null
	var ok := true
	var C = root.get_node("Campaign")
	C.new_campaign("normal")
	C.data["base_pick"] = false
	C.data["day"] = 8.0
	# 1. a landed ship is now and then a bug mission (only while their base is unknown)
	var t1: bool = C._bug_ok("raider") and not C._bug_ok("battleship")
	var m: Dictionary = C.generate_mission(Vector2(49.4, 15.6), "bug")
	m["crew_of"] = "raider"
	C.data["missions"].append(m)
	var fl0: int = C.data.get("flights", []).size()
	C.mission_done(int(m["id"]), true, 0, 0, 0, 0, 0, [], {"bug_tag": 1})
	var has_base := false
	for mm in C.data["missions"]:
		if mm["type"] == "alienbase":
			has_base = true
	t1 = t1 and has_base and not C._bug_ok("raider")
	print("[TYPES] bug tagged -> their base: %s" % t1)
	# 2. no tracker: the ship is in the air for the interceptors, less trust lost
	var m2: Dictionary = C.generate_mission(Vector2(49.4, 15.6), "bug")
	m2["crew_of"] = "scout"
	C.data["missions"].append(m2)
	var tr0: int = int(C.data["trust"])
	C.mission_done(int(m2["id"]), false, 0, 0, 0)
	var fl: Array = C.data.get("flights", [])
	var t2: bool = fl.size() == fl0 + 1 and String(fl[-1]["kind"]) == "scout" and int(C.data["trust"]) - tr0 == -2
	print("[TYPES] bug missed -> ship in flight %s trust %+d: %s" % [fl.size() - fl0, int(C.data["trust"]) - tr0, t2])
	# 3. the radar station: a good job widens the area's radar time, a bad one shortens it
	var r1: Dictionary = C.generate_mission(Vector2(48.0, 11.0), "radar")
	C.data["missions"].append(r1)
	C.mission_done(int(r1["id"]), true, 0, 0, 0)
	var good: float = C.radar_cover(48.0, 11.0)
	var r2: Dictionary = C.generate_mission(Vector2(-23.0, -46.0), "radar")
	C.data["missions"].append(r2)
	C.mission_done(int(r2["id"]), false, 0, 0, 0)
	var bad: float = C.radar_cover(-23.0, -46.0)
	var t3: bool = good > 1.0 and bad < 1.0
	print("[TYPES] radar cover good %.2f bad %.2f: %s" % [good, bad, t3])
	# 4. the convoy and the pilot are found as other missions
	var t4 := true
	for t in ["convoy", "pilot", "radar", "bug"]:
		var mm: Dictionary = C.generate_mission(Vector2(50.0, 14.0), t)
		t4 = t4 and String(mm["type"]) == t and float(mm["expires"]) > float(C.data["day"])
	print("[TYPES] generate convoy/pilot/radar/bug: %s" % t4)
	ok = t1 and t2 and t3 and t4
	print("RESULT missiontypes %s" % ("ok" if ok else "FAIL"))
	for f in FILES:
		if bak[f] == null:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
		else:
			var fa := FileAccess.open(f, FileAccess.WRITE)
			fa.store_buffer(bak[f])
	quit()
