"""Mixamo -> our alien rigs (Bijec first).

Takes a Mixamo FBX (without skin is enough) and bakes its motion onto one of our
generated rigs (root/hips/spine/neck/head/upperarm/forearm/hand/thigh/shin .L/.R).
Each of our bones is turned to point where the matching Mixamo bone points (the rest
poses differ: Mixamo stands in a T-pose, ours hang their arms), then follows its
rotation frame by frame. The hips also take the Mixamo hip movement, scaled to our
height; walks and runs are made "in place" (the game moves the alien itself).

The result is a GLB with only the rig and the actions: it goes to animace/ and into
the game package (.pck) - NOT into the public sources (Mixamo licence, see .gitignore).
In the game it replaces the clips of the same name; without it the old ones stay.

Run: python3 tools/blender/retarget_mixamo.py <our_model.glb> <mixamo_dir> <out.glb> <spec>
  spec = name=file.fbx[:inplace][:keeparms][:from-to],...   (frames in Mixamo numbering)
"""
import bpy, sys, math
from mathutils import Matrix, Vector, Quaternion

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
MODEL, MDIR, OUT, SPEC = args[:4]

# our bone <- Mixamo bone. The Mixamo body is turned to face +Y like ours, so its left side
# lies at -X - where our ".R" bones are.
MAP = {"hips": "Hips", "spine": "Spine2", "neck": "Neck", "head": "Head",
       "upperarm.R": "LeftArm", "forearm.R": "LeftForeArm", "hand.R": "LeftHand",
       "upperarm.L": "RightArm", "forearm.L": "RightForeArm", "hand.L": "RightHand",
       "thigh.R": "LeftUpLeg", "shin.R": "LeftLeg", "thigh.L": "RightUpLeg", "shin.L": "RightLeg"}
ARMS = {"upperarm.L", "forearm.L", "hand.L", "upperarm.R", "forearm.R", "hand.R"}

bpy.ops.wm.read_factory_settings(use_empty=True)
scn = bpy.context.scene
scn.render.fps = 30
bpy.ops.import_scene.gltf(filepath=MODEL)
rig = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
old = {a.name.split("|")[-1]: a for a in bpy.data.actions}
for n, a in old.items():
    a.name = "old_" + n                # the new clips take the plain names
for o in list(bpy.data.objects):
    if o.type != 'ARMATURE':
        bpy.data.objects.remove(o)
if rig.animation_data is None:
    rig.animation_data_create()
for t in list(rig.animation_data.nla_tracks):
    rig.animation_data.nla_tracks.remove(t)

def order(bones):
    out, seen = [], set()
    def add(b):
        if b.name in seen:
            return
        if b.parent:
            add(b.parent)
        seen.add(b.name)
        out.append(b)
    for b in bones:
        add(b)
    return out

TB = order(rig.data.bones)
RW = rig.matrix_world.copy()
t_rest = {b.name: RW @ b.matrix_local for b in TB}                 # rest, world
t_rel = {b.name: (b.parent.matrix_local.inverted() @ b.matrix_local) if b.parent else b.matrix_local.copy() for b in TB}
t_dir = {b.name: (RW.to_3x3() @ (b.tail_local - b.head_local)).normalized() for b in TB}
t_hip = t_rest["hips"].translation.z

def fcurves(a):
    """All F-curves of an action (old flat actions and the new layered ones)."""
    if hasattr(a, "fcurves"):
        return list(a.fcurves)
    out = []
    for ly in a.layers:
        for st in ly.strips:
            for cb in st.channelbags:
                out += list(cb.fcurves)
    return out

def sample_old(name, frame_k):
    """Local rotations of the arms in one of our old clips, at the same point of the loop."""
    a = old.get(name)
    if a is None:
        return {}
    f0, f1 = a.frame_range
    f = f0 + (f1 - f0) * frame_k
    out = {}
    fcs = {(fc.data_path, fc.array_index): fc for fc in fcurves(a)}
    for bn in ARMS:
        q = [0.0, 0.0, 0.0, 0.0]
        ok = False
        for i in range(4):
            fc = fcs.get(('pose.bones["%s"].rotation_quaternion' % bn, i))
            if fc:
                q[i] = fc.evaluate(f)
                ok = True
        if ok:
            out[bn] = Quaternion(q).normalized()
    return out

def retarget(name, fbx, inplace, keeparms, fr):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=MDIR + "/" + fbx, automatic_bone_orientation=False)
    new = [o for o in bpy.data.objects if o not in before]
    src = [o for o in new if o.type == 'ARMATURE'][0]
    sact = src.animation_data.action
    src.rotation_euler.z += math.pi           # Mixamo faces -Y, ours +Y
    f0, f1 = (int(sact.frame_range[0]), int(sact.frame_range[1])) if fr is None else fr
    pref = "mixamorig:"
    sb = {n: src.pose.bones[pref + m] for n, m in MAP.items()}
    scn.frame_set(f0)
    # rest of the source (world), with the facing turn
    bpy.context.view_layer.update()
    SW = src.matrix_world.copy()
    s_rest = {n: SW @ src.data.bones[b.name].matrix_local for n, b in sb.items()}
    s_dir = {n: (SW.to_3x3() @ (src.data.bones[b.name].tail_local - src.data.bones[b.name].head_local)).normalized() for n, b in sb.items()}
    align = {n: t_dir[n].rotation_difference(s_dir[n]) for n in MAP}
    s_hip = s_rest["hips"].translation.z
    k = t_hip / max(s_hip, 0.01)
    # hip track (world) for in-place
    hips_w = {}
    for f in range(f0, f1 + 1):
        scn.frame_set(f)
        hips_w[f] = (SW @ sb["hips"].matrix).translation.copy()
    drift = hips_w[f1] - hips_w[f0]
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    rig.animation_data.action = act
    for pb in rig.pose.bones:
        pb.rotation_mode = 'QUATERNION'
    for f in range(f0, f1 + 1):
        scn.frame_set(f)
        kf = (f - f0) / max(1, f1 - f0)
        arms = sample_old(name if name in old else "idle", kf) if keeparms else {}
        M = {}
        for b in TB:
            n = b.name
            par = M[b.parent.name] if b.parent else Matrix.Identity(4)
            base = par @ t_rel[n]                      # where the bone sits with no pose of its own
            basis = Matrix.Identity(4)
            if n in MAP and n not in arms:
                s_now = SW @ sb[n].matrix
                delta = s_now.to_quaternion() @ s_rest[n].to_quaternion().inverted()
                want_w = delta @ align[n] @ t_rest[n].to_quaternion()
                want = (RW.inverted().to_quaternion() @ want_w).to_matrix().to_4x4()
                head = base.translation.copy()
                if n == "hips":
                    off = hips_w[f] - hips_w[f0]
                    if inplace:
                        off -= drift * kf
                        off.x = off.x * 0.5               # keep a little of the sway
                    head = head + RW.inverted().to_3x3() @ (off * k)
                want.translation = head
                basis = base.inverted() @ want
            elif n in arms:
                basis = arms[n].to_matrix().to_4x4()
            pb = rig.pose.bones[n]
            pb.matrix_basis = basis
            if b.parent is None and f == f0:
                # the root at rest: our old crouches move it, and a clip without the track would leave it there
                pb.keyframe_insert("rotation_quaternion", frame=1)
                pb.keyframe_insert("location", frame=1)
            if n in MAP or n in arms:
                pb.keyframe_insert("rotation_quaternion", frame=f - f0 + 1)
                if n == "hips":
                    pb.keyframe_insert("location", frame=f - f0 + 1)
            M[n] = base @ basis
    for o in new:
        if o.name in bpy.data.objects:
            bpy.data.objects.remove(o)
    print("CLIP", name, fbx, f1 - f0 + 1, "frames, scale %.2f" % k)
    return act

made = []
for item in SPEC.split(","):
    name, rest = item.split("=")
    parts = rest.split(":")
    fr = None
    for p in parts[1:]:
        if "-" in p and p.replace("-", "").isdigit():
            a, b = p.split("-")
            fr = (int(a), int(b))
    made.append(retarget(name, parts[0], "inplace" in parts, "keeparms" in parts, fr))
for a in list(bpy.data.actions):
    if a not in made:
        bpy.data.actions.remove(a)
for a in made:
    tr = rig.animation_data.nla_tracks.new()
    tr.name = a.name
    tr.strips.new(a.name, 1, a)
rig.animation_data.action = None
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', export_animations=True,
                          export_animation_mode='NLA_TRACKS', export_force_sampling=True, export_skins=True,
                          export_optimize_animation_size=False, export_optimize_animation_keep_anim_armature=True)
print("OUT", OUT, [a.name for a in made])
