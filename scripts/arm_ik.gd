class_name ArmIK
## Two-bone arm IK: shoulder and elbow turn so the wrist lands on a point (a grip on the gun).
## Bones point along their local +Y (as exported from Blender). Works on the pose already set
## by the animation and the hold pose, so the rest of the body keeps its posture.

## Where each hand holds a weapon, in the weapon model's own space (-Z is the muzzle).
## Default: the right hand at the grip behind the middle, the left under the barrel ahead of it;
## the Workshop can move both (tweak "grip/<item>": {"r": [x,y,z], "l": [x,y,z]}).
static func grips(id: String, model: Node3D) -> Dictionary:
	var t: Dictionary = Game.tweaks.get("grip/" + id, {})
	var out := {}
	if not _boxes.has(id):
		_boxes[id] = _aabb(model)
	var box: AABB = _boxes[id]
	var cy := box.position.y + box.size.y * 0.55
	var back := box.end.z
	var front := box.position.z
	if Game.two_handed(id) or id in ["pistol", "magnum", "laser_pistol", "plasma_pistol", "a_pistol"]:
		var two := Game.two_handed(id)
		out["l"] = Game._v3(t.get("l", null), Vector3(box.get_center().x, cy - 0.01, lerpf(back, front, 0.5 if two else 0.32)))
	return out

static var _boxes := {}

## The default left-hand grip (before any Workshop change).
static func default_grip(id: String, model: Node3D) -> Vector3:
	var keep = Game.tweaks.get("grip/" + id)
	Game.tweaks.erase("grip/" + id)
	var g := grips(id, model)
	if keep != null:
		Game.tweaks["grip/" + id] = keep
	return g.get("l", Vector3.ZERO)

static func _aabb(n: Node3D) -> AABB:
	var inv := n.global_transform.affine_inverse()
	var box := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c
		var b := (inv * mi.global_transform) * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	# the model's own transform (the tweak) is part of the holder space: undo it for local space
	return box

## Turns upperarm + forearm so the hand bone's origin reaches `target` (world space).
## `pole` is a world point the elbow bends towards.
static func solve(sk: Skeleton3D, side: String, target: Vector3, pole: Vector3, weight := 1.0) -> void:
	var iu := sk.find_bone("upperarm." + side)
	var i_f := sk.find_bone("forearm." + side)
	var ih := sk.find_bone("hand." + side)
	if iu < 0 or i_f < 0 or ih < 0 or weight <= 0.0:
		return
	var inv := sk.global_transform.affine_inverse()
	var tgt: Vector3 = inv * target
	var pol: Vector3 = inv * pole
	var gu := sk.get_bone_global_pose(iu)
	var gf := sk.get_bone_global_pose(i_f)
	var gh := sk.get_bone_global_pose(ih)
	var s := gu.origin
	var l1 := s.distance_to(gf.origin)
	var l2 := gf.origin.distance_to(gh.origin)
	var to := tgt - s
	var d := clampf(to.length(), absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
	var n := to.normalized()
	var ca := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var sa := sqrt(1.0 - ca * ca)
	var bend := (pol - s)
	bend = (bend - n * bend.dot(n))
	if bend.length() < 0.0001:
		bend = Vector3.DOWN - n * Vector3.DOWN.dot(n)
	bend = bend.normalized()
	var elbow := s + n * l1 * ca + bend * l1 * sa
	var hand := s + n * d
	# upper arm: turn its +Y onto the shoulder->elbow line
	_aim(sk, iu, gu, elbow - s, weight)
	gf = sk.get_bone_global_pose(i_f)
	_aim(sk, i_f, gf, hand - gf.origin, weight)

## Rotates bone i (global pose g) so its +Y axis points along dir; writes the local pose.
static func _aim(sk: Skeleton3D, i: int, g: Transform3D, dir: Vector3, weight: float) -> void:
	if dir.length() < 0.0001:
		return
	var cur := g.basis.y.normalized()
	var want := dir.normalized()
	var q := Quaternion(cur, want) if cur.dot(want) > -0.9999 else Quaternion(g.basis.x.normalized(), PI)
	var new_basis := Basis(q) * g.basis
	var parent := sk.get_bone_parent(i)
	var pg := sk.get_bone_global_pose(parent) if parent >= 0 else Transform3D()
	var local := (pg.basis.inverse() * new_basis).get_rotation_quaternion()
	var old := sk.get_bone_pose_rotation(i)
	sk.set_bone_pose_rotation(i, old.slerp(local, weight))
