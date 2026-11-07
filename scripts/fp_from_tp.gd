class_name FpFromTp
## "Z mocapu do očí" (0.57 trial): the eyes' view of a movement made from the movement seen from
## outside (a Mixamo clip on the soldier). Samples taken while the body plays the clip give, at
## each moment, where the gun and the free (left) hand are; they are read from the soldier's own
## eyes - but eyes fixed to the chest, so a nod of the head does not swing the camera - and written
## as an ordinary "fp" clip (tracks "zbran" and "ruka", events for the hand and the magazine) that
## the Animace editor can change further.
##
## A sample: {"ph": 0..1, "spine": Transform3D, "eye": Transform3D, "gun": Transform3D,
##            "hand": Transform3D, "mag": Vector3 (where the gun's magazine sits, world),
##            "grip": Vector3 (where our left hand holds the gun, world)}

## The gun's resting place in the eyes' view (the game's own, player.gd VM_R / low ready) and where
## the left hand normally holds it there (Animace z očí: the hand on the fore-end).
const KIND := {
	"rifle": {"vm": Vector3(0.17, -0.18, -0.4), "hand": Vector3(0.04, -0.2, -0.56), "hand_rot": Vector3(30, 0, 0), "carry": "rifle_clip",
		"mag": Vector3(0.0, -0.1, -0.12)},
	"pistol": {"vm": Vector3(0.1, -0.17, -0.38), "hand": Vector3(0.05, -0.24, -0.36), "hand_rot": Vector3(40, 0, 20), "carry": "pistol_mag",
		"mag": Vector3(0.0, -0.11, 0.03)},
}

static func build(samples: Array, kind: String, name: String, length: float, move_k := 0.7, turn_k := 0.2) -> Dictionary:
	var K: Dictionary = KIND.get(kind, KIND["rifle"])
	var clip := AnimClips.new_clip("fp", name)
	clip["delka"] = snappedf(length, 0.01)
	clip["z_mocapu"] = true
	if samples.size() < 2:
		return clip
	var s0: Dictionary = samples[0]
	var spine0: Transform3D = s0["spine"]
	var eye0: Transform3D = s0["eye"]
	var frames := []
	for s in samples:
		# the eyes ride on the chest: lean with the trunk, not with every turn of the head
		var S: Transform3D = (s["spine"] as Transform3D) * spine0.affine_inverse() * eye0
		var inv := S.affine_inverse()
		frames.append({"ph": float(s["ph"]), "gun": inv * (s["gun"] as Transform3D), "hand": inv * (s["hand"] as Transform3D),
			"mag": inv * (s["mag"] as Vector3), "grip": inv * (s["grip"] as Vector3)})
	var g0: Transform3D = frames[0]["gun"]
	var h0: Transform3D = frames[0]["hand"]
	var hand_rest: Vector3 = K["hand"]
	var hand_rot0 := Basis.from_euler(Vector3(K["hand_rot"]) * (PI / 180.0))
	# on the gun = near our own grip on it (the Mixamo man held his own rifle elsewhere)
	var on := func(f: Dictionary) -> bool: return (f["hand"] as Transform3D).origin.distance_to(f["grip"]) < 0.14
	var free_from := -1.0
	var free_to := -1.0
	for f in frames:
		if not on.call(f):
			if free_from < 0.0:
				free_from = f["ph"]
			free_to = f["ph"]
	# the magazine: the hand's closest approaches to it (local minima of the distance) - the first is
	# the old one coming out, the best one at least a fifth of the movement later the new one going in
	var t_out := -1.0
	var t_in := -1.0
	var dist := []
	for f in frames:
		dist.append((f["hand"] as Transform3D).origin.distance_to(f["mag"]))
	var mins := []
	for i in range(3, frames.size() - 3):
		var dd: float = dist[i]
		if dd <= dist[i - 3] and dd <= dist[i + 3] and dd <= dist[i - 1] and dd <= dist[i + 1]:
			mins.append(i)
	for i in mins:
		if float(frames[i]["ph"]) < 0.6:
			t_out = frames[i]["ph"]
			break
	var best := 9.0
	for i in mins:
		if t_out >= 0.0 and float(frames[i]["ph"]) > t_out + 0.2 and float(dist[i]) < best:
			best = dist[i]
			t_in = frames[i]["ph"]
	# keys every ~0.08 of the movement (the editor stays readable), the first and last always
	var step := 0.08
	var next := 0.0
	for i in frames.size():
		var f: Dictionary = frames[i]
		var ph: float = f["ph"]
		if ph < next and i != frames.size() - 1:
			continue
		next = ph + step
		var t := ph * length
		var g: Transform3D = f["gun"]
		var dp: Vector3 = (g.origin - g0.origin) * move_k
		# keep the gun in sight and out of the face
		dp = Vector3(clampf(dp.x, -0.14, 0.12), clampf(dp.y, -0.14, 0.12), clampf(dp.z, -0.08, 0.1))
		var dq := Quaternion.IDENTITY.slerp((g.basis * g0.basis.inverse()).get_rotation_quaternion(), turn_k)
		var de := Basis(dq).get_euler() * (180.0 / PI)
		de = Vector3(clampf(de.x, -15, 15), clampf(de.y, -15, 15), clampf(de.z, -25, 25))
		AnimClips.set_key(clip, "zbran", t, [snappedf(dp.x, 0.001), snappedf(dp.y, 0.001), snappedf(dp.z, 0.001),
			snappedf(de.x, 0.1), snappedf(de.y, 0.1), snappedf(de.z, 0.1)])
		# the hand: on the fore-end while it holds the gun; in between it goes where the Mixamo hand
		# goes - but measured from the magazine and pulled onto it at the moments it takes the old one
		# out and puts the new one in (the Mixamo man's rifle sat a little elsewhere in his hands)
		var h: Transform3D = f["hand"]
		var vm: Vector3 = K["vm"]
		var mag_fp: Vector3 = vm + Vector3(K["mag"]) + dp
		var gk := 1.0
		for tc in [t_out, t_in]:
			if tc >= 0.0:
				gk = minf(gk, clampf(absf(ph - tc) / 0.12, 0.0, 1.0))
		var free_k := 0.0
		if free_from >= 0.0:
			free_k = clampf(minf((ph - free_from) / 0.1, (free_to - ph) / 0.1 + 1.0), 0.0, 1.0)
		var loose: Vector3 = mag_fp + (h.origin - (f["mag"] as Vector3)) * move_k * gk
		var hp: Vector3 = (hand_rest + dp).lerp(loose, free_k)
		hp = Vector3(clampf(hp.x, -0.32, 0.3), clampf(hp.y, -0.42, -0.06), minf(hp.z, -0.3))
		var w := free_k
		var hq := Quaternion.IDENTITY.slerp((h.basis * h0.basis.inverse()).get_rotation_quaternion(), 0.35 * w)
		var he := (Basis(hq) * hand_rot0).get_euler() * (180.0 / PI)
		AnimClips.set_key(clip, "ruka", t, [snappedf(hp.x, 0.001), snappedf(hp.y, 0.001), snappedf(hp.z, 0.001),
			snappedf(he.x, 0.1), snappedf(he.y, 0.1), snappedf(he.z, 0.1)])
	var ev := [{"t": 0.0, "typ": "leva:zbran"}]
	if free_from >= 0.0:
		ev.append({"t": snappedf(free_from * length, 0.01), "typ": "leva:volna"})
		if t_out >= 0.0:
			ev.append({"t": snappedf(t_out * length, 0.01), "typ": "drzi:" + String(K["carry"])})
			ev.append({"t": snappedf(t_out * length, 0.01), "typ": "skryt:Mag"})
			ev.append({"t": snappedf(t_out * length, 0.01), "typ": "zvuk:mag_out"})
		if t_in >= 0.0:
			ev.append({"t": snappedf(t_in * length, 0.01), "typ": "ukazat:Mag"})
			ev.append({"t": snappedf(t_in * length, 0.01), "typ": "zvuk:mag_in"})
			ev.append({"t": snappedf(t_in * length + 0.02, 0.01), "typ": "drzi:"})
		ev.append({"t": snappedf(minf(free_to * length + 0.04, length), 0.01), "typ": "leva:zbran"})
	ev.sort_custom(func(a, b): return float(a["t"]) < float(b["t"]))
	clip["udalosti"] = ev
	return clip
