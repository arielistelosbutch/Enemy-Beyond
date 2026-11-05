class_name Mocap
## Motion capture from Mixamo (FBX) onto the merc's own 15 bones (0.54, a trial first).
## The FBX is read at run time (FBXDocument), so the files can stay in a folder the game never
## imports or ships (animace/Maximo has a .gdignore): only the converted movement goes into the
## game, as an ordinary clip the Animace editor can change further.
##
## Facing: Mixamo stands facing +Z; our rig faces -Z with its ".R" arm on the anatomical left and
## the game shows it mirrored (scale x -1), so the source is first mirrored front to back (z -> -z):
## mirrored twice it comes out as the Mixamo man turned round, the gun in the right hand.
## How: both skeletons then stand alike. For each of our bones the same turn as the
## matching Mixamo bone (relative to its rest pose), corrected once for the different rest pose
## (Mixamo stands in a T, ours with the arms down), then aimed so the bone points exactly where
## the Mixamo limb points (the three Mixamo spine bones become our one trunk, the feet and fingers
## are dropped). The hips' movement scaled to our size goes to "root@pos".

## our bone: [Mixamo bone it turns with, Mixamo joint it starts at, Mixamo joint it points to]
const MAP := {
	"hips": ["Hips", "Hips", "Spine"],
	"spine": ["Spine2", "Spine", "Neck"],
	"neck": ["Neck", "Neck", "Head"],
	"head": ["Head", "Head", "HeadTop_End"],
	"upperarm.L": ["LeftArm", "LeftArm", "LeftForeArm"],
	"forearm.L": ["LeftForeArm", "LeftForeArm", "LeftHand"],
	"hand.L": ["LeftHand", "LeftHand", "LeftHandMiddle1"],
	"upperarm.R": ["RightArm", "RightArm", "RightForeArm"],
	"forearm.R": ["RightForeArm", "RightForeArm", "RightHand"],
	"hand.R": ["RightHand", "RightHand", "RightHandMiddle1"],
	"thigh.L": ["LeftUpLeg", "LeftUpLeg", "LeftLeg"],
	"shin.L": ["LeftLeg", "LeftLeg", "LeftFoot"],
	"thigh.R": ["RightUpLeg", "RightUpLeg", "RightLeg"],
	"shin.R": ["RightLeg", "RightLeg", "RightFoot"],
}
## our bones in the order they hang on each other (a parent before its children)
const ORDER := ["hips", "spine", "neck", "head", "upperarm.L", "forearm.L", "hand.L", "upperarm.R", "forearm.R", "hand.R",
	"thigh.L", "shin.L", "thigh.R", "shin.R"]
## where our bone points at rest when it has no bone after it
const LEAF_DIR := {"head": Vector3.UP, "shin.L": Vector3.DOWN, "shin.R": Vector3.DOWN}
## the arms only (left as the game poses them while something is held)
const ARMS := ["upperarm.L", "forearm.L", "hand.L", "upperarm.R", "forearm.R", "hand.R"]

## Reads an FBX into a scene in the tree of @a parent (freed by the caller). null when it cannot.
static func load_fbx(path: String, parent: Node) -> Node:
	var doc := FBXDocument.new()
	var st := FBXState.new()
	if doc.append_from_file(path, st) != OK:
		return null
	var sc: Node = doc.generate_scene(st)
	if sc == null:
		return null
	parent.add_child(sc)
	return sc

static func _skel(n: Node) -> Skeleton3D:
	var s := n.find_children("*", "Skeleton3D", true, false)
	return s[0] if not s.is_empty() else null

static func _player(n: Node) -> AnimationPlayer:
	var a := n.find_children("*", "AnimationPlayer", true, false)
	return a[0] if not a.is_empty() else null

## The movement in the file: the one with the most tracks (files with the body also carry a stub "Take 001").
static func main_anim(ap: AnimationPlayer) -> String:
	var best := ""
	var bn := -1
	for an in ap.get_animation_list():
		var c := ap.get_animation(an).get_track_count()
		if c > bn:
			bn = c
			best = an
	return best

## Mixamo bone names come as "mixamorig:Hips", "mixamorig_Hips" or "mixamorig1:Hips".
static func _find(sk: Skeleton3D, short: String) -> int:
	for i in sk.get_bone_count():
		var n := sk.get_bone_name(i)
		if n == short or n.ends_with(":" + short) or n.ends_with("_" + short):
			return i
	return -1

## Converts the first animation of a loaded Mixamo scene into a clip for our merc (@a target: its
## Skeleton3D, at rest). @a in_place: the walk's travel taken out (the game moves the man itself);
## @a fps: samples per second (thinned out afterwards).
static func convert(src_scene: Node, target: Skeleton3D, name: String, in_place := true, fps := 30.0) -> Dictionary:
	var ss := _skel(src_scene)
	var ap := _player(src_scene)
	if ss == null or ap == null or ap.get_animation_list().is_empty():
		return {}
	var anim_name := main_anim(ap)
	var anim := ap.get_animation(anim_name)
	var si := {}
	for b in MAP:
		for k in 3:
			var sn: String = MAP[b][k]
			if not si.has(sn):
				si[sn] = _find(ss, sn)
	var hips_i: int = si["Hips"]
	if hips_i < 0:
		return {}
	# rest poses (global, in each skeleton's space)
	var s_rest := {}
	for sn in si:
		if si[sn] >= 0:
			s_rest[sn] = _refl(ss.get_bone_global_rest(si[sn]))
	var t_rest := {}
	var t_dir := {}        # our bone's rest direction (global)
	for b in ORDER:
		t_rest[b] = target.get_bone_global_rest(target.find_bone(b))
	for b in ORDER:
		var child := ""
		for c in ORDER:
			if target.get_bone_parent(target.find_bone(c)) == target.find_bone(b) and c != "upperarm.L" and c != "upperarm.R" and c != "thigh.L" and c != "thigh.R":
				child = c
		if b == "hips":
			t_dir[b] = ((t_rest["spine"] as Transform3D).origin - (t_rest["hips"] as Transform3D).origin).normalized()
		elif child != "":
			t_dir[b] = ((t_rest[child] as Transform3D).origin - (t_rest[b] as Transform3D).origin).normalized()
		elif b.begins_with("hand"):
			t_dir[b] = t_dir["forearm" + b.substr(4)]
		else:
			t_dir[b] = LEAF_DIR.get(b, Vector3.UP)
	# the once-only correction for the different rest pose: Mixamo's rest direction onto ours
	var corr := {}
	for b in ORDER:
		var m: Array = MAP[b]
		var a0: int = si[m[1]]
		var a1: int = si[m[2]]
		if a0 < 0 or a1 < 0:
			corr[b] = Quaternion()
			continue
		var sd: Vector3 = ((s_rest[m[2]] as Transform3D).origin - (s_rest[m[1]] as Transform3D).origin).normalized()
		corr[b] = _arc(sd, t_dir[b])
	var scale: float = (t_rest["hips"] as Transform3D).origin.y / maxf(0.01, (s_rest["Hips"] as Transform3D).origin.y)
	var hips0: Vector3 = (s_rest["Hips"] as Transform3D).origin
	# sample
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	ap.play(anim_name)
	var n := maxi(2, int(ceil(anim.length * fps)) + 1)
	var times := []
	var rows := {}          # bone -> [[x,y,z] deg ...]
	var pos := []
	for b in ORDER:
		rows[b] = []
	for f in n:
		var t := minf(anim.length, f / fps)
		ap.seek(t, true)
		times.append(t)
		var g := {}          # our bone -> global rotation now
		for b in ORDER:
			var m: Array = MAP[b]
			var tw: int = si[m[0]]
			var rest_q := (t_rest[b] as Transform3D).basis.get_rotation_quaternion()
			if tw < 0:
				g[b] = rest_q
				continue
			var now_q := _refl(ss.get_bone_global_pose(tw)).basis.get_rotation_quaternion()
			var rs := now_q * (s_rest[m[0]] as Transform3D).basis.get_rotation_quaternion().inverse()
			var q: Quaternion = rs * (corr[b] as Quaternion).inverse() * rest_q
			# aim it exactly where the Mixamo limb points (the trunk: from the first spine bone to the neck)
			var a0: int = si[m[1]]
			var a1: int = si[m[2]]
			if a0 >= 0 and a1 >= 0 and b != "hips":
				var want := _refl(ss.get_bone_global_pose(a1)).origin - _refl(ss.get_bone_global_pose(a0)).origin
				if want.length() > 1e-5:
					var local_dir: Vector3 = rest_q.inverse() * (t_dir[b] as Vector3)
					var cur: Vector3 = q * local_dir
					q = _arc(cur, want.normalized()) * q
			g[b] = q.normalized()
		for b in ORDER:
			var bi := target.find_bone(b)
			var pi := target.get_bone_parent(bi)
			var parent_q := Quaternion()
			if pi >= 0:
				var pn := target.get_bone_name(pi)
				parent_q = g[pn] if g.has(pn) else target.get_bone_global_rest(pi).basis.get_rotation_quaternion()
			var local: Quaternion = parent_q.inverse() * (g[b] as Quaternion)
			var off := Basis(target.get_bone_rest(bi).basis.get_rotation_quaternion().inverse() * local).get_euler() * (180.0 / PI)
			var prev: Array = rows[b][-1] if not rows[b].is_empty() else []
			if not prev.is_empty():
				for j in 3:
					off[j] = float(prev[j]) + wrapf(off[j] - float(prev[j]), -180.0, 180.0)
			rows[b].append([off.x, off.y, off.z])
		var hp := _refl(ss.get_bone_global_pose(hips_i)).origin
		var d := (hp - hips0) * scale
		pos.append([d.x, d.y, d.z])
	var travel := 0.0
	if pos.size() > 1:
		travel = Vector2(float(pos[-1][0]) - float(pos[0][0]), float(pos[-1][2]) - float(pos[0][2])).length()
	if in_place and pos.size() > 1:
		# the travel taken out, the sway kept: a straight line from the first to the last place removed
		var p0: Array = pos[0]
		var p1: Array = pos[-1]
		for f in pos.size():
			var k := float(f) / float(pos.size() - 1)
			pos[f][0] = float(pos[f][0]) - lerpf(float(p0[0]), float(p1[0]), k)
			pos[f][2] = float(pos[f][2]) - lerpf(float(p0[2]), float(p1[2]), k)
	var c := AnimClips.new_clip("tp", name)
	c["delka"] = snappedf(anim.length, 0.01)
	c["zdroj"] = "Mixamo"
	if in_place and travel > 0.05 and anim.length > 0.05:
		c["rychlost"] = snappedf(travel / anim.length, 0.01)      # m/s the man would go: the game plays it faster or slower to match
	c["vlastni_poloha"] = true      # it lies down / falls by itself: the game does not tip the model over too
	for b in ORDER:
		_write(c, b, times, rows[b], 1.0, 0.1)
	_write(c, "root@pos", times, pos, 0.004, 0.001)
	return c

## Only a part of a movement (from @a a to @b b seconds), starting at 0.
static func trim(c: Dictionary, a: float, b: float) -> void:
	b = minf(b, float(c.get("delka", b)))
	for tr in c.get("stopy", {}).keys():
		var keys: Array = c["stopy"][tr]
		var out := [{"t": 0.0, "v": AnimClips.sample(c, tr, a), "prechod": "rovnomerne"}]
		for k in keys:
			var kt := float(k["t"])
			if kt > a + 0.02 and kt < b - 0.02:
				var nk: Dictionary = k.duplicate(true)
				nk["t"] = snappedf(kt - a, 0.01)
				out.append(nk)
		out.append({"t": snappedf(b - a, 0.01), "v": AnimClips.sample(c, tr, b), "prechod": "rovnomerne"})
		c["stopy"][tr] = out
	c["delka"] = snappedf(b - a, 0.01)

## Writes a sampled track with only the keys that matter (straight lines in between).
static func _write(c: Dictionary, row: String, times: Array, vals: Array, tol: float, snap: float) -> void:
	if times.is_empty():
		return
	var keep := {0: true, times.size() - 1: true}
	_reduce(times, vals, 0, times.size() - 1, tol, keep)
	var ks := keep.keys()
	ks.sort()
	for i in ks:
		var v: Array = vals[i]
		AnimClips.set_key(c, row, float(times[i]), [snappedf(float(v[0]), snap), snappedf(float(v[1]), snap), snappedf(float(v[2]), snap)])
	for key in AnimClips.track(c, row):
		key["prechod"] = "rovnomerne"

static func _reduce(times: Array, vals: Array, a: int, b: int, tol: float, keep: Dictionary) -> void:
	if b - a < 2:
		return
	var worst := -1
	var wd := tol
	var ta := float(times[a])
	var tb := float(times[b])
	for i in range(a + 1, b):
		var k := (float(times[i]) - ta) / maxf(0.0001, tb - ta)
		for j in 3:
			var dd := absf(float(vals[i][j]) - lerpf(float(vals[a][j]), float(vals[b][j]), k))
			if dd > wd:
				wd = dd
				worst = i
	if worst < 0:
		return
	keep[worst] = true
	_reduce(times, vals, a, worst, tol, keep)
	_reduce(times, vals, worst, b, tol, keep)

## The source mirrored front to back (z -> -z): a place flips its z, a turn keeps only its z axis part.
static func _refl(t: Transform3D) -> Transform3D:
	var q := t.basis.get_rotation_quaternion()
	return Transform3D(Basis(Quaternion(-q.x, -q.y, q.z, q.w)), Vector3(t.origin.x, t.origin.y, -t.origin.z))

## The shortest turn taking direction @a from onto @a to.
static func _arc(from: Vector3, to: Vector3) -> Quaternion:
	var a := from.normalized()
	var b := to.normalized()
	var d := a.dot(b)
	if d > 0.99999:
		return Quaternion()
	if d < -0.99999:
		var ax := a.cross(Vector3.RIGHT)
		if ax.length() < 1e-4:
			ax = a.cross(Vector3.UP)
		return Quaternion(ax.normalized(), PI)
	return Quaternion(a.cross(b).normalized(), acos(clampf(d, -1.0, 1.0)))
