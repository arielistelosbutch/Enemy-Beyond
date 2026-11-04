"""Ohař (0.50) after Ari's picture: a long, lean, flayed hound - stitched pink-brown hide over raw
muscle, steel clamps round the legs, a segmented armour spine with violet light between the plates and
steel spikes on top, hoses arcing over the back, a glowing violet canister on the neck, purple eyes,
a gaping jaw full of fangs and a long steel blade bolted along the snout. Hooked steel claws, a tail.
Same rig and action names as before (idle, walk, run, lurk, attack, aim), so the game moves it as before.
Run: python3 tools/blender/ohar.py out.glb [--preview <action|-> <frame> out.png angle dist]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from common import *
from common import _finish

OUT = [a for a in sys.argv if a.endswith(".glb")]
OUT = OUT[0] if OUT else "ohar.glb"
reset()

def mat2(name, rgb, rough=0.6, metal=0.0, emit=0.0):
    m = mat(name, rgb, emit=emit, rough=rough)
    m.node_tree.nodes.get("Principled BSDF").inputs["Metallic"].default_value = metal
    return m

hide = mat2("OhaHide", (0.42, 0.27, 0.27), rough=0.45)
hide2 = mat2("OhaHide2", (0.3, 0.17, 0.19), rough=0.5)
raw = mat2("OhaRaw", (0.38, 0.05, 0.07), rough=0.35)
mouth = mat2("OhaMouth", (0.12, 0.01, 0.02), rough=0.4)
tooth = mat2("OhaTooth", (0.72, 0.66, 0.55), rough=0.35)
steel = mat2("OhaSteel", (0.3, 0.29, 0.3), rough=0.35, metal=0.85)
blade_m = mat2("OhaBlade", (0.62, 0.6, 0.62), rough=0.2, metal=0.95)
blood = mat2("OhaBlood", (0.3, 0.02, 0.03), rough=0.3)
hose = mat2("OhaHose", (0.12, 0.08, 0.14), rough=0.5)
glow = mat("OhaGlow", (0.7, 0.2, 1.0), emit=3.0)
eye = mat("OhaEye", (0.85, 0.35, 1.0), emit=8.0)

def smooth(o):
    for p in o.data.polygons:
        p.use_smooth = True
    return o

def limb(material, a, b, r1, r2, verts=8, group=None, sm=True):
    a = Vector(a); b = Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=max(d.length, 0.001))
    o = _finish(bpy.context.active_object, material, (a + b) / 2, d.to_track_quat('Z', 'Y').to_euler(), (1, 1, 1), group)
    return smooth(o) if sm else o

def band(material, a, b, t, R, r=0.012, group=None):
    """A steel clamp round a limb from a to b, at fraction t."""
    a = Vector(a); b = Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=12, minor_segments=4)
    return _finish(bpy.context.active_object, material, a + d * t, d.to_track_quat('Z', 'Y').to_euler(), (1, 1, 1.6), group)

def chain(material, pts, r1, r2, verts=7, group=None):
    out = []
    n = len(pts) - 1
    for i in range(n):
        out.append(limb(material, pts[i], pts[i + 1], r1 + (r2 - r1) * i / n, r1 + (r2 - r1) * (i + 1) / n, verts=verts, group=group))
        if i < n - 1:
            out.append(smooth(sphere(material, pts[i + 1], r1 + (r2 - r1) * (i + 1) / n, seg=verts, rings=4, group=group)))
    return out

# ---- the rig (as the old Trhač: the game knows these bones) ----------------------------------------------
B = {
    "root": ((0, 0, 0), (0, 0, 0.25), None),
    "hips": ((0, -0.5, 0.85), (0, -0.4, 0.95), "root"),
    "spine": ((0, -0.4, 0.95), (0, 0.42, 1.05), "hips"),
    "neck": ((0, 0.42, 1.05), (0, 0.72, 1.0), "spine"),
    "head": ((0, 0.72, 1.0), (0, 1.1, 0.95), "neck"),
    "jaw": ((0, 0.75, 0.9), (0, 1.0, 0.8), "head"),
    "tail": ((0, -0.55, 0.9), (0, -1.15, 0.8), "hips"),
}
for sd, x in (("L", 1), ("R", -1)):
    B["thigh." + sd] = ((0.2 * x, -0.45, 0.85), (0.2 * x, -0.32, 0.45), "hips")
    B["shin." + sd] = ((0.2 * x, -0.32, 0.45), (0.2 * x, -0.5, 0.05), "thigh." + sd)
    B["upperarm." + sd] = ((0.24 * x, 0.36, 0.95), (0.25 * x, 0.42, 0.5), "spine")
    B["forearm." + sd] = ((0.25 * x, 0.42, 0.5), (0.25 * x, 0.45, 0.05), "upperarm." + sd)

arm_data = bpy.data.armatures.new("TrhRig")
rig = bpy.data.objects.new("TrhRig", arm_data)
bpy.context.scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
for n, (h, t, parent) in B.items():
    eb = arm_data.edit_bones.new(n)
    eb.head, eb.tail = h, t
for n, (h, t, parent) in B.items():
    if parent:
        arm_data.edit_bones[n].parent = arm_data.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')
for b in rig.pose.bones:
    b.rotation_mode = 'XYZ'

P = []
S = "spine"
# ---- the body: a deep chest, a starved waist, ribs with violet light between them ----------------------------
P.append(smooth(sphere(hide, (0, 0.24, 1.0), 0.25, seg=16, rings=10, scale=(0.78, 1.2, 0.95), group=S)))
P.append(smooth(sphere(hide2, (0, -0.12, 0.98), 0.19, seg=14, rings=8, scale=(0.72, 1.4, 0.8), group=S)))
P.append(smooth(sphere(hide, (0, -0.44, 0.92), 0.16, seg=14, rings=8, scale=(0.95, 1.15, 0.85), group="hips")))
for x in (1, -1):
    for k in range(5):
        y = 0.38 - k * 0.11
        P.append(limb(hide, (0.1 * x, y, 1.18), (0.2 * x, y - 0.02, 0.98), 0.022, 0.02, verts=6, group=S))
        P.append(limb(hide, (0.2 * x, y - 0.02, 0.98), (0.12 * x, y - 0.03, 0.8), 0.02, 0.014, verts=6, group=S))
        if k < 4:
            P.append(box(glow, (0.17 * x, y - 0.055, 0.99), (0.012, 0.05, 0.16), rot=(0, 0.35 * x, 0), group=S))
    P.append(smooth(sphere(raw, (0.12 * x, -0.14, 0.93), 0.08, seg=10, rings=6, scale=(0.5, 2.0, 0.9), group=S)))   # flayed flank
    for k in range(6):                                                                  # stitches
        P.append(box(blood, (0.14 * x, -0.25 + k * 0.05, 1.03), (0.03, 0.006, 0.006), group=S))
# ---- the armoured spine: plates, violet slots, steel spikes, hoses over the back ------------------------------
for k in range(8):
    y = -0.5 + k * 0.13
    z = 1.13 + 0.06 * math.sin(k / 7 * math.pi)
    g = "hips" if k < 1 else S
    P.append(box(steel, (0, y, z), (0.24 - abs(k - 4) * 0.01, 0.1, 0.05), rot=(0.12, 0, 0), group=g))
    P.append(box(glow, (0, y + 0.06, z - 0.01), (0.16, 0.02, 0.035), group=g))
    if k >= 2:
        hgt = 0.1 + (k - 2) * 0.025
        P.append(limb(steel, (0, y, z + 0.02), (0, y - 0.07, z + 0.02 + hgt), 0.03, 0.0, verts=4, group=g, sm=False))
for x in (1, -1):
    for y0 in (-0.25, 0.05, 0.3):
        P += chain(hose, [(0.08 * x, y0, 1.16), (0.17 * x, y0 + 0.04, 1.22), (0.24 * x, y0 + 0.08, 1.1), (0.2 * x, y0 + 0.1, 0.98)], 0.014, 0.012, group=S)
# ---- tail with hooks ----------------------------------------------------------------------------------------------
P.append(limb(hide, (0, -0.6, 0.92), (0, -0.95, 0.82), 0.06, 0.035, group="tail"))
P.append(limb(hide2, (0, -0.95, 0.82), (0, -1.25, 0.66), 0.035, 0.008, group="tail"))
for k in range(3):
    P.append(limb(steel, (0, -0.75 - k * 0.15, 0.88 - k * 0.05), (0, -0.82 - k * 0.15, 0.97 - k * 0.05), 0.012, 0.0, verts=4, group="tail"))
# ---- neck with its canister ---------------------------------------------------------------------------------------
P.append(limb(hide, (0, 0.38, 1.04), (0, 0.76, 0.98), 0.13, 0.095, group="neck"))
for t in (0.3, 0.75):
    P.append(band(steel, (0, 0.38, 1.04), (0, 0.76, 0.98), t, 0.12 - t * 0.03, 0.014, group="neck"))
P.append(smooth(cyl(glow, (0, 0.58, 1.16), 0.05, 0.24, verts=14, rot=(math.pi / 2 - 0.1, 0, 0), group="neck")))
for dy in (-0.14, 0.14):                                                   # steel caps and a cage of rods
    P.append(smooth(cyl(steel, (0, 0.58 + dy, 1.16 - dy * 0.1), 0.06, 0.05, verts=14, rot=(math.pi / 2 - 0.1, 0, 0), group="neck")))
for a in (0.0, 2.1, 4.2):
    P.append(limb(steel, (math.sin(a) * 0.055, 0.45, 1.17 + math.cos(a) * 0.055), (math.sin(a) * 0.055, 0.71, 1.15 + math.cos(a) * 0.055), 0.008, 0.008, verts=4, group="neck"))
for x in (1, -1):
    P += chain(hose, [(0.03 * x, 0.44, 1.18), (0.09 * x, 0.36, 1.25), (0.12 * x, 0.28, 1.17)], 0.014, 0.012, group="neck")
# ---- the head: a long skull, purple eyes, the blade bolted along the snout ---------------------------------------
H = "head"
sk = sphere(hide, (0, 0.88, 0.98), 0.11, seg=16, rings=10, scale=(0.85, 1.6, 0.72), group=H)
P.append(smooth(sk))
P.append(smooth(sphere(mouth, (0, 0.96, 0.9), 0.07, seg=12, rings=8, scale=(0.9, 1.7, 0.6), group=H)))   # the throat
for x in (1, -1):
    P.append(smooth(sphere(eye, (0.068 * x, 0.88, 1.02), 0.021, seg=8, rings=6, group=H)))
    P.append(box(steel, (0.07 * x, 0.86, 1.05), (0.03, 0.06, 0.012), rot=(0, 0, 0.3 * x), group=H))     # brow clamp
    for i in range(6):                                                                                 # upper fangs
        y = 0.92 + i * 0.045
        ln = 0.07 if i in (0, 3) else 0.045
        P.append(limb(tooth, (0.05 * x * (1 - i * 0.08), y, 0.93), (0.05 * x * (1 - i * 0.08), y + 0.01, 0.93 - ln), 0.009, 0.0, verts=5, group=H))
# the blade: long, flat, steel, with blood on it
bl = box(blade_m, (0, 1.32, 1.04), (0.022, 0.7, 0.1), group=H)
for v in bl.data.vertices:
    t = (v.co.y - 0.97) / 0.7
    v.co.z -= 0.0 if v.co.z > 1.04 else 0.0
    v.co.z = 1.04 + (v.co.z - 1.04) * max(0.0, 1.0 - t ** 1.6)      # tapering to a point
    v.co.z -= t * 0.08
P.append(bl)
P.append(box(blood, (0, 1.25, 1.0), (0.024, 0.18, 0.02), rot=(0.12, 0, 0), group=H))
P.append(box(blood, (0, 1.45, 0.98), (0.024, 0.1, 0.015), rot=(0.12, 0, 0), group=H))
for y in (0.92, 1.04):
    P.append(bevel_box := box(steel, (0, y, 1.04), (0.06, 0.04, 0.12), group=H))
P.append(box(glow, (0, 1.0, 1.08), (0.03, 0.08, 0.012), group=H))
# the lower jaw (opens)
J = "jaw"
P.append(smooth(sphere(hide2, (0, 0.95, 0.84), 0.07, seg=12, rings=8, scale=(0.95, 1.9, 0.45), group=J)))
for x in (1, -1):
    for i in range(5):
        y = 0.9 + i * 0.045
        P.append(limb(tooth, (0.045 * x * (1 - i * 0.08), y, 0.86), (0.045 * x * (1 - i * 0.08), y + 0.01, 0.86 + (0.06 if i == 1 else 0.04)), 0.008, 0.0, verts=5, group=J))
    P.append(limb(raw, (0.04 * x, 1.0, 0.86), (0.035 * x, 1.0, 0.94), 0.006, 0.004, verts=4, group=J))   # dripping strings
# ---- legs: long, sinewy, clamped with steel, hooked claws -----------------------------------------------------------
for sd, x in (("L", 1), ("R", -1)):
    th = ((0.2 * x, -0.45, 0.88), (0.2 * x, -0.3, 0.45))
    sh = ((0.2 * x, -0.3, 0.45), (0.2 * x, -0.5, 0.05))
    ua = ((0.23 * x, 0.36, 1.0), (0.25 * x, 0.42, 0.5))
    fa = ((0.25 * x, 0.42, 0.5), (0.25 * x, 0.45, 0.05))
    P.append(limb(hide, th[0], th[1], 0.105, 0.06, group="thigh." + sd))
    P.append(limb(raw, (0.25 * x, -0.42, 0.8), (0.24 * x, -0.33, 0.5), 0.05, 0.03, group="thigh." + sd))
    P.append(smooth(sphere(hide2, th[1], 0.06, seg=8, rings=6, group="shin." + sd)))
    P.append(limb(hide, sh[0], sh[1], 0.055, 0.035, group="shin." + sd))
    P.append(limb(hide, ua[0], ua[1], 0.095, 0.06, group="upperarm." + sd))
    P.append(limb(raw, (0.29 * x, 0.36, 0.9), (0.28 * x, 0.42, 0.56), 0.045, 0.03, group="upperarm." + sd))
    P.append(smooth(sphere(hide2, ua[1], 0.06, seg=8, rings=6, group="forearm." + sd)))
    P.append(limb(hide, fa[0], fa[1], 0.055, 0.035, group="forearm." + sd))
    P.append(box(steel, (0.27 * x, 0.36, 0.95), (0.12, 0.2, 0.08), rot=(0.2, -0.3 * x, 0), group="upperarm." + sd))  # shoulder plate
    for seg, g, rs in ((th, "thigh." + sd, (0.085, 0.065)), (sh, "shin." + sd, (0.05, 0.04)), (ua, "upperarm." + sd, (0.08, 0.062)), (fa, "forearm." + sd, (0.05, 0.04))):
        P.append(band(steel, seg[0], seg[1], 0.35, rs[0], 0.013, group=g))
        P.append(band(steel, seg[0], seg[1], 0.75, rs[1], 0.013, group=g))
    for foot, g in ((sh[1], "shin." + sd), (fa[1], "forearm." + sd)):
        P.append(smooth(sphere(hide2, foot, 0.05, seg=8, rings=5, scale=(1.2, 1.4, 0.7), group=g)))
        for c in (-1, 0, 1):
            P.append(limb(steel, (foot[0] + c * 0.03, foot[1] + 0.04, foot[2]), (foot[0] + c * 0.045, foot[1] + 0.17, foot[2] - 0.04), 0.014, 0.0, verts=4, group=g, sm=False))
        P.append(limb(steel, (foot[0], foot[1] - 0.03, foot[2] + 0.04), (foot[0], foot[1] - 0.12, foot[2] - 0.03), 0.012, 0.0, verts=4, group=g, sm=False))

body = join(P, "Trhac")
mod = body.modifiers.new("Armature", 'ARMATURE')
mod.object = rig
body.parent = rig

# ---- the actions -------------------------------------------------------------------------------------------------------
def action(name, frames):
    pb = rig.pose.bones
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = act
    for f, rots, hz in frames:
        for b in pb:
            b.rotation_euler = (0, 0, 0)
            b.location = (0, 0, 0)
        for n, r in rots.items():
            if n in pb:
                pb[n].rotation_euler = r
        pb["root"].location = (0, hz, 0)
        for b in pb:
            b.keyframe_insert("rotation_euler", frame=f)
            b.keyframe_insert("location", frame=f)
    rig.animation_data.action = None
    return act

def gait(n, amp, bob, lunge=0.0):
    out = []
    for i in range(5):
        f = 1 + i * n // 4
        ph = i / 4 * 2 * math.pi
        sw = math.sin(ph)
        out.append((f, {"thigh.L": (-sw * amp, 0, 0), "thigh.R": (sw * amp, 0, 0),
                        "upperarm.L": (sw * amp, 0, 0), "upperarm.R": (-sw * amp, 0, 0),
                        "forearm.L": (-max(0, sw) * amp * 0.8, 0, 0), "forearm.R": (-max(0, -sw) * amp * 0.8, 0, 0),
                        "shin.L": (max(0, -sw) * amp * 0.7, 0, 0), "shin.R": (max(0, sw) * amp * 0.7, 0, 0),
                        "spine": (sw * lunge, 0, 0), "neck": (0.15, 0, 0), "jaw": (0.25, 0, 0), "tail": (0, 0, sw * 0.4)},
                    -abs(math.cos(ph)) * bob))
    return out

action("idle", [(1, {"neck": (0.2, 0, 0), "jaw": (0.2, 0, 0), "tail": (0, 0, 0.2)}, 0),
                (25, {"neck": (0.1, 0, 0.3), "jaw": (0.45, 0, 0), "tail": (0, 0, -0.2)}, -0.02),
                (49, {"neck": (0.2, 0, 0), "jaw": (0.2, 0, 0), "tail": (0, 0, 0.2)}, 0)])
action("walk", gait(26, 0.38, 0.03))
action("run", gait(10, 0.85, 0.09, 0.14))
crouch = {"thigh.L": (0.6, 0, 0), "thigh.R": (0.6, 0, 0), "shin.L": (-1.0, 0, 0), "shin.R": (-1.0, 0, 0),
          "upperarm.L": (-0.4, 0, 0), "upperarm.R": (-0.4, 0, 0), "forearm.L": (0.8, 0, 0), "forearm.R": (0.8, 0, 0), "neck": (0.45, 0, 0)}
action("lurk", [(1, crouch, -0.25), (41, dict(crouch, neck=(0.5, 0, 0.2)), -0.26)])
rear = {"neck": (-0.45, 0, 0), "head": (-0.35, 0, 0), "jaw": (0.8, 0, 0), "upperarm.L": (-0.4, 0, 0), "upperarm.R": (-0.4, 0, 0), "spine": (-0.15, 0, 0)}
stab = {"neck": (0.45, 0, 0), "head": (0.35, 0, 0), "jaw": (0.1, 0, 0), "upperarm.L": (0.5, 0, 0), "upperarm.R": (0.5, 0, 0), "spine": (0.15, 0, 0)}
action("attack", [(1, {}, 0), (6, rear, 0.03), (9, stab, -0.08), (17, {}, 0)])
action("aim", [(1, rear, 0.02), (25, dict(rear, jaw=(0.6, 0, 0)), 0.02)])

for b in rig.pose.bones:
    b.rotation_euler = (0, 0, 0)
    b.location = (0, 0, 0)
if "--preview" in sys.argv:
    i = sys.argv.index("--preview")
    if sys.argv[i + 1] != "-":
        rig.animation_data_create()
        rig.animation_data.action = bpy.data.actions[sys.argv[i + 1]]
        bpy.context.scene.frame_set(int(sys.argv[i + 2]))
    preview(sys.argv[i + 3], target=(0, 0.3, 0.75), dist=float(sys.argv[i + 5]) if len(sys.argv) > i + 5 else 3.6,
            angle=float(sys.argv[i + 4]), height=0.3, res=(640, 420))
else:
    export_glb(OUT, [rig, body], animations=True)
    print("written", OUT)
