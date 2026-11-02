"""Šedák - the grey crew member. Low-poly, rigid-skinned (PS1 style), with
animations: idle, walk, run, lurk, aim."""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from common import *

OUT = sys.argv[-1] if sys.argv[-1].endswith(".glb") else "grey.glb"
reset()
skin = mat("GreySkin", (0.50, 0.53, 0.54), rough=0.6)
suit = mat("GreySuit", (0.10, 0.12, 0.115))
plate = mat("GreyPlate", (0.22, 0.24, 0.26), rough=0.5)
eye = mat("GreyEye", (0.005, 0.005, 0.008), rough=0.05)
gun = mat("PlasmaBody", (0.30, 0.33, 0.30), rough=0.4)
glow = mat("PlasmaGlow", (0.35, 1.0, 0.45), emit=4.0)

# ---- skeleton (Blender Z-up, facing +Y) -----------------------------------------
B = {
    "root": ((0, 0, 0), (0, 0, 0.25), None),
    "hips": ((0, 0, 0.62), (0, 0, 0.72), "root"),
    "spine": ((0, 0, 0.72), (0, 0, 0.95), "hips"),
    "neck": ((0, 0, 0.95), (0, 0, 1.06), "spine"),
    "head": ((0, 0, 1.06), (0, 0, 1.45), "neck"),
}
for s, x in (("L", 1), ("R", -1)):
    B["thigh." + s] = ((0.09 * x, 0, 0.62), (0.09 * x, 0, 0.34), "hips")
    B["shin." + s] = ((0.09 * x, 0, 0.34), (0.09 * x, 0, 0.06), "thigh." + s)
    B["upperarm." + s] = ((0.17 * x, 0, 0.92), (0.21 * x, 0, 0.66), "spine")
    B["forearm." + s] = ((0.21 * x, 0, 0.66), (0.23 * x, 0, 0.40), "upperarm." + s)
    B["hand." + s] = ((0.23 * x, 0, 0.40), (0.235 * x, 0, 0.30), "forearm." + s)

arm_data = bpy.data.armatures.new("GreyRig")
rig = bpy.data.objects.new("GreyRig", arm_data)
bpy.context.scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
for name, (h, t, parent) in B.items():
    eb = arm_data.edit_bones.new(name)
    eb.head, eb.tail = h, t
    eb.roll = 0
for name, (h, t, parent) in B.items():
    if parent:
        arm_data.edit_bones[name].parent = arm_data.edit_bones[parent]
        arm_data.edit_bones[name].use_connect = False
bpy.ops.object.mode_set(mode='OBJECT')

# ---- body parts, each rigidly bound to one bone ----------------------------------
parts = []
# head: tall egg, narrow chin
h = sphere(skin, (0, 0.02, 1.25), 0.2, seg=10, rings=8, scale=(1.0, 1.05, 1.28), group="head")
for v in h.data.vertices:
    if v.co.z < 1.2:
        k = max(0.45, 1.0 - (1.2 - v.co.z) * 2.6)
        v.co.x *= k
        v.co.y = 0.02 + (v.co.y - 0.02) * k
parts.append(h)
for x in (1, -1):
    parts.append(sphere(eye, (0.068 * x, 0.195, 1.22), 0.07, seg=8, rings=6, scale=(1.55, 0.5, 0.8), rot=(0, 0.5 * x, 0.35 * x), group="head"))
parts.append(cyl(skin, (0, 0, 1.0), 0.035, 0.14, verts=6, group="neck"))
# torso: thin, tapered, a chest plate
parts.append(cyl(suit, (0, 0, 0.84), 0.1, 0.26, verts=8, r2=0.14, group="spine"))
parts.append(box(plate, (0, 0.11, 0.86), (0.18, 0.04, 0.14), group="spine"))
parts.append(cyl(suit, (0, 0, 0.66), 0.12, 0.12, verts=8, r2=0.1, group="hips"))
for s, x in (("L", 1), ("R", -1)):
    parts.append(sphere(suit, (0.16 * x, 0, 0.92), 0.05, seg=6, rings=4, group="upperarm." + s))
    parts.append(cyl(skin, (0.19 * x, 0, 0.79), 0.028, 0.26, verts=6, r2=0.022, group="upperarm." + s))
    parts.append(cyl(skin, (0.22 * x, 0, 0.53), 0.022, 0.26, verts=6, r2=0.018, group="forearm." + s))
    # three long fingers
    for f in (-1, 0, 1):
        parts.append(cyl(skin, (0.232 * x + f * 0.012, 0.01 * f, 0.33), 0.008, 0.13, verts=4, r2=0.004, rot=(0.15 * f, 0, 0), group="hand." + s))
    parts.append(sphere(skin, (0.23 * x, 0, 0.395), 0.03, seg=6, rings=4, scale=(1, 0.6, 1), group="hand." + s))
    parts.append(cyl(suit, (0.09 * x, 0, 0.48), 0.045, 0.28, verts=6, r2=0.035, group="thigh." + s))
    parts.append(cyl(suit, (0.09 * x, 0, 0.2), 0.032, 0.28, verts=6, r2=0.026, group="shin." + s))
    parts.append(box(suit, (0.09 * x, 0.04, 0.025), (0.07, 0.16, 0.05), group="shin." + s))
# plasma pistol in the right hand, pointing forward (+Y)
pg = "hand.R"
parts.append(box(gun, (-0.235, 0.06, 0.33), (0.04, 0.14, 0.05), group=pg))
parts.append(cyl(gun, (-0.235, 0.15, 0.335), 0.022, 0.08, verts=6, rot=(math.pi / 2, 0, 0), r2=0.012, group=pg))
parts.append(sphere(glow, (-0.235, 0.05, 0.36), 0.018, seg=6, rings=4, group=pg))
parts.append(box(glow, (-0.235, 0.12, 0.355), (0.01, 0.06, 0.008), group=pg))

body = join(parts, "Grey")
mod = body.modifiers.new("Armature", 'ARMATURE')
mod.object = rig
body.parent = rig

# ---- animations -------------------------------------------------------------------
pb = rig.pose.bones
for b in pb:
    b.rotation_mode = 'XYZ'

def pose(frame, rots, hips_z=0.0):
    for b in pb:
        b.rotation_euler = (0, 0, 0)
        b.location = (0, 0, 0)
    for name, r in rots.items():
        pb[name].rotation_euler = r
    pb["hips"].location = (0, 0, 0)
    pb["root"].location = (0, hips_z, 0)   # root bone points up: its local Y is world Z
    for b in pb:
        b.keyframe_insert("rotation_euler", frame=frame)
        b.keyframe_insert("location", frame=frame)

def action(name, frames):
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = act
    for f, rots, hz in frames:
        pose(f, rots, hz)
    for fc in getattr(act, "fcurves", []):
        for k in fc.keyframe_points:
            k.interpolation = 'LINEAR'
    rig.animation_data.action = None
    return act

# rotations below: +X swings a limb forward / tilts the spine forward
def walk_frames(n, amp, arm, bob):
    out = []
    for i in range(5):
        f = 1 + i * n // 4
        ph = i / 4 * 2 * math.pi
        sw = math.sin(ph)
        out.append((f, {
            "thigh.L": (-sw * amp, 0, 0), "thigh.R": (sw * amp, 0, 0),
            "shin.L": (-max(0, -sw) * amp * 1.2, 0, 0), "shin.R": (-max(0, sw) * amp * 1.2, 0, 0),
            "upperarm.L": (sw * arm, 0, 0.05), "upperarm.R": (-sw * arm, 0, -0.05),
            "forearm.L": (0.25, 0, 0), "forearm.R": (0.25, 0, 0),
            "spine": (-0.12, 0, sw * 0.08), "head": (0.08, sw * 0.05, 0),
        }, -abs(math.cos(ph)) * bob))
    return out

action("idle", [
    (1, {"head": (0, 0, 0.0), "spine": (-0.03, 0, 0), "forearm.L": (0.1, 0, 0), "forearm.R": (0.1, 0, 0)}, 0),
    (25, {"head": (0.06, 0.12, 0.18), "spine": (-0.06, 0, 0), "forearm.L": (0.15, 0, 0), "forearm.R": (0.15, 0, 0)}, -0.01),
    (49, {"head": (0, 0, 0.0), "spine": (-0.03, 0, 0), "forearm.L": (0.1, 0, 0), "forearm.R": (0.1, 0, 0)}, 0),
])
action("walk", walk_frames(32, 0.45, 0.3, 0.02))
action("run", walk_frames(18, 0.8, 0.0, 0.05))
lurk = {"thigh.L": (1.1, 0, 0.1), "thigh.R": (1.1, 0, -0.1), "shin.L": (-1.9, 0, 0), "shin.R": (-1.9, 0, 0),
        "spine": (-0.6, 0, 0), "neck": (0.25, 0, 0), "head": (0.35, 0, 0),
        "upperarm.L": (0.6, 0, 0.2), "upperarm.R": (0.6, 0, -0.2), "forearm.L": (0.7, 0, 0), "forearm.R": (0.7, 0, 0)}
lurk2 = dict(lurk, head=(0.3, 0.15, 0.25), spine=(-0.65, 0, 0))
action("lurk", [(1, lurk, -0.3), (21, lurk2, -0.31), (41, lurk, -0.3)])
aim = {"upperarm.R": (1.45, 0, 0.1), "forearm.R": (0.1, 0, 0), "spine": (-0.05, 0, -0.15), "head": (0, 0, -0.1),
       "upperarm.L": (-0.1, 0, 0.1), "forearm.L": (0.3, 0, 0), "thigh.L": (0.25, 0, 0), "thigh.R": (-0.2, 0, 0), "shin.L": (-0.3, 0, 0)}
action("aim", [(1, aim, -0.02), (13, dict(aim, spine=(-0.08, 0, -0.18)), -0.03), (25, aim, -0.02)])

if "--preview" in sys.argv:
    rig.animation_data.action = bpy.data.actions[sys.argv[sys.argv.index("--preview") + 1]]
    bpy.context.scene.frame_set(int(sys.argv[sys.argv.index("--preview") + 2]))
    preview(sys.argv[sys.argv.index("--preview") + 3], target=(0, 0, 0.75), dist=2.6, angle=float(sys.argv[sys.argv.index("--preview") + 4]))
else:
    export_glb(OUT, [rig, body], animations=True)
