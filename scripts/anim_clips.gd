class_name AnimClips
## Animations made in the Dílna (Animace mode), stored as res://animace/<id>.json.
## A clip is a set of tracks, each a row of keys in time; between two keys the value
## moves smoothly ("plynule") or evenly ("rovnomerne"). Events fire at a moment (a sound,
## what the free hand holds...).
##
##  {"nazev": "...", "druh": "tp" | "fp", "delka": 1.2, "smycka": false,
##   "stopy": {"upperarm.R": [{"t": 0.0, "v": [deg, deg, deg]}, ...],     <- tp: a bone, degrees
##             "zbran": [{"t": 0.0, "v": [x, y, z, rx, ry, rz]}, ...],   <- fp: metres + degrees
##             "ruka": [...], "Mag": [...], "Slide": [...]},
##   "udalosti": [{"t": 0.4, "typ": "zvuk:pistol_slide"}, {"t": 0.2, "typ": "drzi:pistol_mag"}]}
##
## Ids: tp_<what>_<item> (tp_reload_pistol, tp_strike_knife, tp_heal, tp_dig, tp_salute...)
## and fp_<what>_<item> (fp_reload_pistol...). A clip for "_vse" fits every item.

const DIR := "res://animace"
const PRECHODY := {"": "plynule", "rovnomerne": "rovnoměrně", "skok": "skokem"}

## What can be animated, with Czech names (the editor's list).
const TP_ACTS := [["reload", "Přebíjení"], ["strike", "Úder (nůž, obušek)"], ["heal", "Ošetřování"], ["dig", "Hrabání v batohu"],
	["hold", "Držení (postoj)"], ["salute", "Pozdrav (J)"], ["atease", "Pohov (U)"], ["hips", "Ruce v bok"]]
const FP_ACTS := [["reload", "Přebíjení"], ["reload1", "Přebíjení po jednom (náboj)"]]
const EMOTES := ["salute", "atease", "hips"]

static var _cache := {}
static var _mtime := {}
static var _seen := {}        # id -> when the file was last looked at (the game asks every frame)

static func path_of(id: String) -> String:
	return DIR.path_join(id + ".json")

## A clip by id (cached; re-read when the file changes, so the editor and the game agree).
static func get_clip(id: String) -> Dictionary:
	var now := Time.get_ticks_msec()
	if _seen.has(id) and now - int(_seen[id]) < 700:
		return _cache.get(id, {})
	_seen[id] = now
	var p := path_of(id)
	if not FileAccess.file_exists(p):
		_cache.erase(id)
		return {}
	var mt := FileAccess.get_modified_time(p)
	if _cache.has(id) and _mtime.get(id, -1) == mt:
		return _cache[id]
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	if not d is Dictionary:
		return {}
	_cache[id] = d
	_mtime[id] = mt
	return d

## The clip for an action with an item: the item's own, else the one for everything.
static func find(druh: String, act: String, item: String) -> Dictionary:
	var c := get_clip("%s_%s_%s" % [druh, act, item]) if item != "" else {}
	if c.is_empty():
		c = get_clip("%s_%s_vse" % [druh, act])
	return c

static func save_clip(id: String, clip: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var f := FileAccess.open(path_of(id), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(clip, " ", false))
	f.close()
	_cache[id] = clip
	_mtime[id] = FileAccess.get_modified_time(path_of(id))
	_seen[id] = Time.get_ticks_msec()
	return true

static func delete_clip(id: String) -> void:
	if FileAccess.file_exists(path_of(id)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path_of(id)))
	_cache.erase(id)
	_seen.erase(id)

static func new_clip(druh: String, nazev: String) -> Dictionary:
	return {"nazev": nazev, "druh": druh, "delka": 1.0, "smycka": false, "stopy": {}, "udalosti": []}

# ---- keys ------------------------------------------------------------------------------------------
const SNAP := 0.02

static func track(clip: Dictionary, name: String) -> Array:
	var st: Dictionary = clip.get("stopy", {})
	return st.get(name, [])

## Writes a key (replaces one at the same moment).
static func set_key(clip: Dictionary, name: String, t: float, v: Array) -> void:
	if not clip.has("stopy"):
		clip["stopy"] = {}
	var tr: Array = clip["stopy"].get(name, [])
	t = snappedf(t, 0.01)
	for k in tr:
		if absf(float(k["t"]) - t) < SNAP:
			k["v"] = v.duplicate()
			return
	tr.append({"t": t, "v": v.duplicate()})
	tr.sort_custom(func(a, b): return float(a["t"]) < float(b["t"]))
	clip["stopy"][name] = tr

static func key_index(tr: Array, t: float) -> int:
	for i in tr.size():
		if absf(float(tr[i]["t"]) - t) < SNAP:
			return i
	return -1

static func delete_key(clip: Dictionary, name: String, t: float) -> bool:
	var tr := track(clip, name)
	var i := key_index(tr, t)
	if i < 0:
		return false
	tr.remove_at(i)
	if tr.is_empty():
		(clip["stopy"] as Dictionary).erase(name)
	return true

## Moves a key in time; returns where it ended up.
static func move_key(clip: Dictionary, name: String, from_t: float, to_t: float) -> float:
	var tr := track(clip, name)
	var i := key_index(tr, from_t)
	if i < 0:
		return from_t
	to_t = clampf(snappedf(to_t, 0.01), 0.0, float(clip.get("delka", 1.0)))
	for j in tr.size():
		if j != i and absf(float(tr[j]["t"]) - to_t) < SNAP:
			return from_t           # (another key sits there)
	tr[i]["t"] = to_t
	tr.sort_custom(func(a, b): return float(a["t"]) < float(b["t"]))
	return to_t

## The value of a track at time t (the keys around it, smoothly or evenly in between).
static func sample(clip: Dictionary, name: String, t: float) -> Array:
	var tr := track(clip, name)
	if tr.is_empty():
		return []
	if t <= float(tr[0]["t"]):
		return tr[0]["v"]
	for i in range(tr.size() - 1):
		var a: Dictionary = tr[i]
		var b: Dictionary = tr[i + 1]
		var ta := float(a["t"])
		var tb := float(b["t"])
		if t >= ta and t <= tb:
			var k := (t - ta) / maxf(0.0001, tb - ta)
			match String(a.get("prechod", "")):
				"rovnomerne": pass
				"skok": k = 0.0
				_: k = k * k * (3.0 - 2.0 * k)
			var va: Array = a["v"]
			var vb: Array = b["v"]
			var out := []
			for j in va.size():
				out.append(lerpf(float(va[j]), float(vb[j]) if j < vb.size() else float(va[j]), k))
			return out
	return tr[-1]["v"]

## The clip's time for how long the action has been going (a loop wraps, otherwise it stops at the end).
static func clip_time(clip: Dictionary, elapsed: float) -> float:
	var d := maxf(0.05, float(clip.get("delka", 1.0)))
	return fmod(elapsed, d) if clip.get("smycka", false) else minf(elapsed, d)

## tp: the pose at time t, as {bone: Vector3 radians} (only the bones that have keys).
static func pose(clip: Dictionary, t: float) -> Dictionary:
	var out := {}
	for name in clip.get("stopy", {}):
		var v := sample(clip, name, t)
		if v.size() >= 3:
			out[name] = Vector3(float(v[0]), float(v[1]), float(v[2])) * (PI / 180.0)
	return out

## fp: a track as an offset transform (metres, degrees) - Transform3D.IDENTITY when it has no keys.
static func xform(clip: Dictionary, name: String, t: float) -> Transform3D:
	var v := sample(clip, name, t)
	if v.size() < 6:
		return Transform3D.IDENTITY
	return Transform3D(Basis.from_euler(Vector3(float(v[3]), float(v[4]), float(v[5])) * (PI / 180.0)), Vector3(float(v[0]), float(v[1]), float(v[2])))

static func has_track(clip: Dictionary, name: String) -> bool:
	return not track(clip, name).is_empty()

## The last event of a kind ("drzi", "zvuk"...) at or before t: its value after the colon, or "".
static func last_event(clip: Dictionary, kind: String, t: float) -> String:
	var out := ""
	for e in clip.get("udalosti", []):
		if float(e["t"]) <= t + 0.0001 and String(e["typ"]).begins_with(kind + ":"):
			out = String(e["typ"]).substr(kind.length() + 1)
	return out

## eyes view: is the free (left) hand off the gun at t? Only when the clip moves it, and
## the events "leva:volna" / "leva:zbran" say when it lets go and takes hold again.
static func hand_free(clip: Dictionary, t: float) -> bool:
	if not has_track(clip, "ruka"):
		return false
	return last_event(clip, "leva", t) != "zbran"

## Events that fall between two moments (for sounds while playing).
static func events_between(clip: Dictionary, t0: float, t1: float) -> Array:
	var out := []
	for e in clip.get("udalosti", []):
		var te := float(e["t"])
		if te > t0 and te <= t1:
			out.append(String(e["typ"]))
	return out

## Mirrored pose (left <-> right) for a {bone: [deg x, y, z]} dictionary.
static func mirrored(p: Dictionary) -> Dictionary:
	var out := {}
	for b in p:
		var o: String = b
		if b.ends_with(".L"): o = b.trim_suffix(".L") + ".R"
		elif b.ends_with(".R"): o = b.trim_suffix(".R") + ".L"
		var v: Array = p[b]
		out[o] = [v[0], -float(v[1]), -float(v[2])]
	return out

## All saved clip ids.
static func all_ids() -> Array:
	var out := []
	var d := DirAccess.open(DIR)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".json"):
			out.append(f.trim_suffix(".json"))
	out.sort()
	return out
