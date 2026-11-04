"""Šedivák (0.50) - the grey scout after Ari's picture: a big pale skull swelling backwards, huge black
almond eyes, a thin neck in a metal collar with lights, a frail body in a dark biomechanical suit
(ribbed knees, segmented belly), a rusty breastplate of an unknown alloy, long thin arms with four
clawed fingers, a wrist device glowing on the left arm, heavy boots.
Same skeleton and animations as before (the game and the Dílna poses keep working).
Run: python3 tools/blender/sedivak.py [velitel] out.glb [--preview action frame out.png angle]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from common import *
from common import _finish
import bmesh

VEL = "velitel" in sys.argv
OUT = [a for a in sys.argv if a.endswith(".glb")]
OUT = OUT[0] if OUT else ("grey_velitel.glb" if VEL else "grey.glb")
reset()

def mat2(name, rgb, rough=0.6, metal=0.0, emit=0.0):
    m = mat(name, rgb, emit=emit, rough=rough)
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Metallic"].default_value = metal
    return m

skin = mat2("SedSkin", (0.56, 0.58, 0.6), rough=0.5)
skin_d = mat2("SedSkinDark", (0.38, 0.4, 0.42), rough=0.55)
# the commander: a blood-red suit (rank, more power in it), dark bronze armour, red lights
suit = mat2("SedSuit", (0.055, 0.06, 0.065), rough=0.65) if not VEL else mat2("SedSuitVel", (0.3, 0.035, 0.05), rough=0.5)
suit2 = mat2("SedSuit2", (0.1, 0.105, 0.115), rough=0.55) if not VEL else mat2("SedSuit2Vel", (0.18, 0.025, 0.035), rough=0.45)
plate = mat2("SedPlate", (0.34, 0.22, 0.14), rough=0.55, metal=0.6) if not VEL else mat2("SedPlateVel", (0.2, 0.17, 0.14), rough=0.45, metal=0.8)
metal = mat2("SedMetal", (0.2, 0.21, 0.22), rough=0.35, metal=0.8)
eye = mat2("GreyEye", (0.004, 0.004, 0.006), rough=0.04)
dark = mat2("SedDark", (0.02, 0.02, 0.02), rough=0.8)
claw = mat2("SedClaw", (0.14, 0.13, 0.12), rough=0.4)
light = mat2("SedLight", (0.7, 0.95, 1.0), emit=3.5) if not VEL else mat2("SedLightVel", (1.0, 0.12, 0.1), emit=4.0)
gun = mat2("PlasmaBody", (0.3, 0.33, 0.3), rough=0.4, metal=0.4)
glow = mat("PlasmaGlow", (0.35, 1.0, 0.45), emit=4.0)

# ---- skeleton: the same bones as the old grey (Blender Z-up, facing +Y) ------------------------------
S = 1.04 if VEL else 1.0
B = {
    "root": ((0, 0, 0), (0, 0, 0.25), None),
    "hips": ((0, 0, 0.62 * S), (0, 0, 0.72 * S), "root"),
    "spine": ((0, 0, 0.72 * S), (0, 0, 0.95 * S), "hips"),
    "neck": ((0, 0, 0.95 * S), (0, 0, 1.06 * S), "spine"),
    "head": ((0, 0, 1.06 * S), (0, 0, 1.45 * S), "neck"),
}
for s, x in (("L", 1), ("R", -1)):
    B["thigh." + s] = ((0.09 * x, 0, 0.62 * S), (0.09 * x, 0, 0.34 * S), "hips")
    B["shin." + s] = ((0.09 * x, 0, 0.34 * S), (0.09 * x, 0, 0.06), "thigh." + s)
    B["upperarm." + s] = ((0.17 * x, 0, 0.92 * S), (0.2 * x, 0, 0.66 * S), "spine")
    B["forearm." + s] = ((0.2 * x, 0, 0.66 * S), (0.22 * x, 0, 0.4 * S), "upperarm." + s)
    B["hand." + s] = ((0.22 * x, 0, 0.4 * S), (0.225 * x, 0, 0.3 * S), "forearm." + s)

arm_data = bpy.data.armatures.new("GreyRig")
rig = bpy.data.objects.new("GreyRig", arm_data)
bpy.context.scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
for name, (h, t, parent) in B.items():
    e = arm_data.edit_bones.new(name)
    e.head, e.tail = h, t
    e.roll = 0
for name, (h, t, parent) in B.items():
    if parent:
        arm_data.edit_bones[name].parent = arm_data.edit_bones[parent]
        arm_data.edit_bones[name].use_connect = False
bpy.ops.object.mode_set(mode='OBJECT')

# ---- helpers ------------------------------------------------------------------------------------------
def smooth(o):
    for p in o.data.polygons:
        p.use_smooth = True
    return o

def bevel(o, w=0.01, seg=2):
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    m = o.modifiers.new("Bevel", 'BEVEL')
    m.width = w
    m.segments = seg
    bpy.ops.object.modifier_apply(modifier="Bevel")
    return o

def limb(material, a, b, r1, r2, verts=8, group=None, sm=True):
    a = Vector(a); b = Vector(b)
    d = b - a
    o = cyl(material, (0, 0, 0), r1, d.length, verts=verts, r2=r2, group=group)
    # the cone stands on Z: turn it along a->b and put it in the middle
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    o.data.transform(Matrix.Translation((0, 0, 0)))
    for v in o.data.vertices:
        v.co = q @ v.co + (a + b) / 2
    return smooth(o) if sm else o

def ring(material, z, r, h, verts=16, group=None, y=0.0, x=0.0):
    return smooth(cyl(material, (x, y, z), r, h, verts=verts, group=group))

P = []
z = lambda v: v * S
# ---- head -------------------------------------------------------------------------------------------------
h = sphere(skin, (0, 0, z(1.27)), 0.2, seg=24, rings=16, scale=(1.0, 1.12, 1.22), group="head")
for v in h.data.vertices:
    c = v.co
    if c.y < 0.0:                       # the skull swells backwards
        c.y *= 1.28
        c.z += -c.y * 0.12
    if c.z > z(1.3):                    # a high dome
        c.x *= 1.06
    if c.z < z(1.18):                   # the face narrows to a small chin
        k = max(0.26, 1.0 - (z(1.18) - c.z) * 4.0)
        c.x *= k
        c.y = 0.07 + (c.y - 0.07) * k
P.append(smooth(h))
for x in (1, -1):
    e = sphere(eye, (0.076 * x, 0.18, z(1.262)), 0.07, seg=18, rings=12, scale=(1.35, 0.5, 0.78), rot=(0, -0.45 * x, 0.4 * x), group="head")
    P.append(smooth(e))
    P.append(box(dark, (0.008 * x, 0.212, z(1.175)), (0.004, 0.006, 0.014), group="head"))          # nostril slits
P.append(box(dark, (0, 0.196, z(1.128)), (0.032, 0.006, 0.004), group="head"))                     # thin mouth
if VEL:
    # the psionic circlet: a metal band round the skull, a red jewel on the brow, a disc over each ear
    bpy.ops.mesh.primitive_torus_add(major_radius=1.0, minor_radius=0.075, major_segments=40, minor_segments=8)
    t = bpy.context.active_object
    t.scale = (0.214, 0.244, 0.32)
    t.rotation_euler = (-0.22, 0, 0)                       # lower at the back of the long skull
    t.location = (0, -0.01, z(1.345))
    P.append(smooth(_finish(t, metal, (0, -0.005, z(1.36)), (0.25, 0, 0), (0.212, 0.246, 0.32), "head")))
    P.append(bevel(box(metal, (0, 0.243, z(1.42)), (0.045, 0.02, 0.045), rot=(0.25, math.pi / 4, 0), group="head"), 0.006, 1))
    P.append(box(light, (0, 0.254, z(1.42)), (0.02, 0.012, 0.02), rot=(0.25, math.pi / 4, 0), group="head"))
    for x in (1, -1):
        P.append(smooth(cyl(metal, (0.208 * x, 0.0, z(1.34)), 0.04, 0.03, verts=14, rot=(0, math.pi / 2, 0), group="head")))
        P.append(smooth(cyl(light, (0.225 * x, 0.0, z(1.34)), 0.022, 0.008, verts=14, rot=(0, math.pi / 2, 0), group="head")))
        P.append(box(skin_d, (0.04 * x, 0.2, z(1.31)), (0.06, 0.02, 0.012), rot=(0, 0.3 * x, 0), group="head"))   # a hard brow over the eyes
# ---- neck and collar --------------------------------------------------------------------------------------
P.append(limb(skin, (0, 0.01, z(0.95)), (0, 0.03, z(1.13)), 0.03, 0.026, verts=10, group="neck"))
P.append(ring(metal, z(0.965), 0.078, 0.05, group="spine"))
P.append(ring(suit2, z(0.995), 0.062, 0.02, group="spine"))
for i in range(6):
    a = i / 6 * math.tau + 0.3
    P.append(box(light, (math.sin(a) * 0.079, math.cos(a) * 0.079, z(0.965)), (0.012, 0.012, 0.012), group="spine"))
# ---- torso ---------------------------------------------------------------------------------------------------
P.append(limb(suit, (0, 0, z(0.7)), (0, 0, z(0.97)), 0.1, 0.13, verts=14, group="spine"))
for i in range(3):                                                                       # segmented belly
    P.append(ring(suit2, z(0.705 + i * 0.032), 0.104 + i * 0.004, 0.012, group="spine"))
pl = bevel(box(plate, (0, 0.085, z(0.865)), (0.21, 0.06, 0.17), group="spine"), 0.016, 2)
P.append(pl)
P.append(bevel(box(plate, (0, 0.11, z(0.865)), (0.03, 0.02, 0.15), group="spine"), 0.006, 1))     # a ridge down the plate
for x in (1, -1):
    P.append(box(light, (0.07 * x, 0.118, z(0.9)), (0.012, 0.01, 0.012), group="spine"))
    P.append(bevel(box(plate, (0.05 * x, 0.075, z(0.79)), (0.08, 0.05, 0.05), group="spine"), 0.01, 1))
if VEL:
    # segmented pauldrons, a high armoured collar, the rune on the plate, the tabard hanging from the belt
    for x in (1, -1):
        for i in range(3):
            P.append(bevel(box(plate, (0.165 * x, 0.0, z(0.965) - i * 0.03), (0.11 - i * 0.012, 0.11, 0.035), rot=(0, 0.35 * x + i * 0.12 * x, 0), group="upperarm." + ("L" if x > 0 else "R")), 0.01, 1))
        P.append(box(light, (0.085 * x, 0.05, z(1.0)), (0.012, 0.012, 0.012), group="spine"))
    P.append(bevel(box(plate, (0, 0.0, z(1.0)), (0.16, 0.14, 0.05), group="spine"), 0.012, 1))
    P.append(box(light, (0, 0.118, z(0.88)), (0.006, 0.004, 0.06), group="spine"))
    P.append(box(light, (0, 0.118, z(0.865)), (0.04, 0.004, 0.006), group="spine"))
    P.append(bevel(box(suit2, (0, 0.1, z(0.55)), (0.09, 0.012, 0.2), group="hips"), 0.004, 1))
    P.append(box(light, (0, 0.108, z(0.56)), (0.004, 0.003, 0.05), group="hips"))
    P.append(bevel(box(suit2, (0, -0.09, z(0.57)), (0.11, 0.012, 0.16), group="hips"), 0.004, 1))
# ---- hips, belt -----------------------------------------------------------------------------------------------
P.append(limb(suit, (0, 0, z(0.6)), (0, 0, z(0.72)), 0.105, 0.1, verts=14, group="hips"))
P.append(ring(dark, z(0.685), 0.112, 0.03, group="hips"))
P.append(bevel(box(metal, (0, 0.11, z(0.685)), (0.04, 0.012, 0.03), group="hips"), 0.004, 1))
for x in (1, -1):
    P.append(bevel(box(suit2, (0.095 * x, 0.06, z(0.67)), (0.04, 0.03, 0.05), group="hips"), 0.006, 1))  # pouches
# ---- arms --------------------------------------------------------------------------------------------------------
for s, x in (("L", 1), ("R", -1)):
    ua, el, wr = (0.165 * x, 0, z(0.92)), (0.2 * x, 0, z(0.66)), (0.22 * x, 0, z(0.42))
    P.append(smooth(sphere(plate, (0.17 * x, 0.0, z(0.93)), 0.05, seg=12, rings=8, scale=(1.1, 1.0, 0.8), group="upperarm." + s)))
    P.append(limb(suit, ua, el, 0.03, 0.024, verts=10, group="upperarm." + s))
    P.append(smooth(sphere(suit2, el, 0.027, seg=10, rings=6, group="forearm." + s)))
    P.append(limb(suit, el, wr, 0.024, 0.019, verts=10, group="forearm." + s))
    P.append(bevel(box(plate if s == "R" else metal, (0.212 * x, 0.0, z(0.5)), (0.045, 0.048, 0.1), group="forearm." + s), 0.008, 1))
    if s == "L":
        P.append(box(light, (0.235, 0.0, z(0.5)), (0.008, 0.03, 0.05), group="forearm.L"))      # the wrist device
        if VEL:
            P.append(bevel(box(metal, (0.232, 0.03, z(0.33)), (0.03, 0.05, 0.09), group="hand.L"), 0.006, 1))   # the command device
            P.append(box(light, (0.232, 0.056, z(0.33)), (0.02, 0.004, 0.06), group="hand.L"))
    # hand: a thin palm, four long fingers with claws, a thumb
    hz = z(0.385)
    P.append(smooth(sphere(skin, (0.224 * x, 0.0, hz), 0.026, seg=10, rings=6, scale=(0.6, 1.0, 1.1), group="hand." + s)))
    for i, f in enumerate((-1.5, -0.5, 0.5, 1.5)):
        a = (0.224 * x, f * 0.011, hz - 0.02)
        b = (0.226 * x, f * 0.016, hz - 0.13 - (0.01 if abs(f) < 1 else 0))
        P.append(limb(skin, a, b, 0.0065, 0.0045, verts=6, group="hand." + s))
        P.append(limb(claw, b, (b[0], b[1] + 0.008, b[2] - 0.025), 0.004, 0.0005, verts=5, group="hand." + s))
    P.append(limb(skin, (0.224 * x, 0.02, hz), (0.218 * x, 0.045, hz - 0.06), 0.006, 0.004, verts=6, group="hand." + s))
# ---- legs -------------------------------------------------------------------------------------------------------------
for s, x in (("L", 1), ("R", -1)):
    hp, kn, an = (0.09 * x, 0, z(0.62)), (0.09 * x, 0, z(0.34)), (0.09 * x, 0, 0.08)
    P.append(limb(suit, hp, kn, 0.046, 0.034, verts=12, group="thigh." + s))
    for i in range(4):                                                                      # ribbed knee
        P.append(ring(suit2, z(0.3) + i * 0.024, 0.04 - abs(i - 1.5) * 0.003, 0.014, x=0.09 * x, y=0.006, group="shin." + s))
    P.append(limb(suit, kn, an, 0.033, 0.026, verts=12, group="shin." + s))
    P.append(bevel(box(dark, (0.09 * x, 0.025, 0.045), (0.08, 0.17, 0.09), group="shin." + s), 0.018, 2))   # boots
    P.append(bevel(box(metal, (0.09 * x, 0.025, 0.006), (0.085, 0.18, 0.016), group="shin." + s), 0.004, 1))
    P.append(bevel(box(dark, (0.09 * x, 0.0, 0.11), (0.07, 0.08, 0.06), group="shin." + s), 0.012, 1))
if True:
    P.append(bevel(box(dark, (-0.135, 0.0, z(0.5)), (0.03, 0.05, 0.1), group="thigh.R"), 0.006, 1))   # holster
# ---- plasma pistol in the right hand (forward = +Y) ---------------------------------------------------------
g = "hand.R"
P.append(bevel(box(gun, (-0.225, 0.07, z(0.33)), (0.035, 0.15, 0.045), group=g), 0.008, 1))
P.append(limb(gun, (-0.225, 0.14, z(0.336)), (-0.225, 0.2, z(0.336)), 0.017, 0.012, verts=10, group=g))
P.append(box(glow, (-0.225, 0.11, z(0.36)), (0.008, 0.07, 0.006), group=g))
P.append(smooth(sphere(glow, (-0.225, 0.05, z(0.36)), 0.014, seg=8, rings=6, group=g)))

body = join(P, "GreyVelitel" if VEL else "Grey")
mod = body.modifiers.new("Armature", 'ARMATURE')
mod.object = rig
body.parent = rig

# ---- animations (as the old grey) ---------------------------------------------------------------------
pb = rig.pose.bones
for b in pb:
    b.rotation_mode = 'XYZ'

def pose(frame, rots, hips_z=0.0):
    for b in pb:
        b.rotation_euler = (0, 0, 0)
        b.location = (0, 0, 0)
    for name, r in rots.items():
        pb[name].rotation_euler = r
    pb["root"].location = (0, hips_z, 0)
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
    rig.animation_data.action = None
    return act

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
# lurking as in Ari's picture: bent forward, knees bent, one long arm hanging, the head pushed out
lurk = {"thigh.L": (1.0, 0, 0.12), "thigh.R": (0.75, 0, -0.1), "shin.L": (-1.6, 0, 0), "shin.R": (-1.4, 0, 0),
        "spine": (-0.55, 0, 0.08), "neck": (0.3, 0, 0), "head": (0.35, 0, 0),
        "upperarm.L": (0.35, 0, 0.15), "upperarm.R": (0.7, 0, -0.2), "forearm.L": (0.25, 0, 0), "forearm.R": (0.8, 0, 0),
        "hand.L": (0.2, 0, 0)}
lurk2 = dict(lurk, head=(0.3, 0.18, 0.28), spine=(-0.6, 0, 0.05), **{"upperarm.L": (0.42, 0, 0.18)})
action("lurk", [(1, lurk, -0.24), (21, lurk2, -0.25), (41, lurk, -0.24)])
aim = {"upperarm.R": (1.45, 0, 0.1), "forearm.R": (0.1, 0, 0), "spine": (-0.05, 0, -0.15), "head": (0, 0, -0.1),
       "upperarm.L": (-0.1, 0, 0.1), "forearm.L": (0.3, 0, 0), "thigh.L": (0.25, 0, 0), "thigh.R": (-0.2, 0, 0), "shin.L": (-0.3, 0, 0)}
action("aim", [(1, aim, -0.02), (13, dict(aim, spine=(-0.08, 0, -0.18)), -0.03), (25, aim, -0.02)])
if VEL:
    action("attack", [(1, aim, -0.02), (7, dict(aim, **{"upperarm.R": (1.6, 0, 0)}), -0.04), (13, aim, -0.02)])
    psi_pose = {"upperarm.L": (1.3, 0, -0.5), "forearm.L": (1.3, 0, 0), "head": (-0.15, 0, 0)}
    action("psi", [(1, psi_pose, 0.0), (7, dict(psi_pose, **{"upperarm.L": (1.7, 0, -0.2), "forearm.L": (0.3, 0, 0)}), 0.0), (13, psi_pose, 0.0)])

if "--preview" in sys.argv:
    i = sys.argv.index("--preview")
    act = sys.argv[i + 1]
    if act != "-":
        rig.animation_data_create()
        rig.animation_data.action = bpy.data.actions[act]
        bpy.context.scene.frame_set(int(sys.argv[i + 2]))
    preview(sys.argv[i + 3], target=(0, 0, float(sys.argv[i + 6]) if len(sys.argv) > i + 6 else 0.78), dist=float(sys.argv[i + 5]) if len(sys.argv) > i + 5 else 2.4, angle=float(sys.argv[i + 4]), res=(420, 560), height=float(sys.argv[i + 7]) if len(sys.argv) > i + 7 else 0.4)
else:
    export_glb(OUT, [rig, body], animations=True)
    print("written", OUT)
