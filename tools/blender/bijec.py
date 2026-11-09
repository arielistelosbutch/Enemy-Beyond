"""Bijec (0.50) after Ari's picture: a towering, impossibly muscled humanoid sealed in heavy synthetic armour
that follows every muscle - dark indigo plates with violet light glowing in the seams - a purple face with a
huge fanged open mouth and yellow eyes under a blocky helmet crest, bare purple fists, an energy rifle with
a violet core. Commander ("velitel"): blood-red armour with red-orange light.
Same rig and actions as before (aliens.kolos: humanoid bones, soldier_anims).
Run: python3 tools/blender/bijec.py [velitel] out.glb [--preview <action|-> <frame> out.png angle]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
import aliens as A
from common import *
from common import _finish

VEL = "velitel" in sys.argv
A.OUT = [a for a in sys.argv if a.endswith(".glb")][0] if any(a.endswith(".glb") for a in sys.argv) else "bijec.glb"

def mat2(name, rgb, rough=0.6, metal=0.0, emit=0.0):
    m = mat(name, rgb, emit=emit, rough=rough)
    m.node_tree.nodes.get("Principled BSDF").inputs["Metallic"].default_value = metal
    return m

if VEL:
    arm = mat2("BijArmorR", (0.32, 0.03, 0.05), rough=0.3, metal=0.45)
    arm2 = mat2("BijArmor2R", (0.14, 0.02, 0.03), rough=0.35, metal=0.5)
    glow = mat("BijGlowR", (1.0, 0.12, 0.1), emit=4.0)
    cape_m = mat2("BijCape", (0.22, 0.02, 0.04), rough=0.8)
    screen = mat("BijScreen", (1.0, 0.25, 0.15), emit=2.5)
    dark = mat2("BijDark", (0.05, 0.04, 0.05), rough=0.4, metal=0.6)
else:
    arm = mat2("BijArmor", (0.09, 0.07, 0.2), rough=0.25, metal=0.5)
    arm2 = mat2("BijArmor2", (0.05, 0.04, 0.11), rough=0.3, metal=0.5)
    glow = mat("BijGlow", (0.7, 0.3, 1.0), emit=4.0)
skin = mat2("BijSkin", (0.28, 0.09, 0.24), rough=0.5)
skin2 = mat2("BijSkin2", (0.17, 0.05, 0.15), rough=0.55)
mouth = mat2("BijMouth", (0.12, 0.01, 0.03), rough=0.4)
tooth = mat2("LihTooth", (0.78, 0.72, 0.6), rough=0.3)
eye = mat("KolEye", (1.0, 0.85, 0.3), emit=4.0)
gunm = mat2("BijGun", (0.1, 0.08, 0.14), rough=0.35, metal=0.6)

def smooth(o):
    for p in o.data.polygons:
        p.use_smooth = True
    return o

def chamf(o, w=0.02):
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    m = o.modifiers.new("Bevel", 'BEVEL')
    m.width = w
    m.segments = 1
    bpy.ops.object.modifier_apply(modifier="Bevel")
    return o

def L(material, a, b, r1, r2, verts=12, group=None):
    return smooth(A.limb(material, a, b, r1, r2, verts=verts, group=group))

def S(material, loc, r, scale=(1, 1, 1), group=None, seg=16, rings=10, rot=(0, 0, 0)):
    return smooth(sphere(material, loc, r, seg=seg, rings=rings, scale=scale, rot=rot, group=group))

def seam(a, b, group, w=0.012):
    """A violet light line in an armour seam."""
    return smooth(A.limb(glow, a, b, w, w, verts=6, group=group))

B = A.humanoid_bones(hip=1.08, chest=1.7, neck=1.82, head=2.12, sx=0.4, hx=0.17, knee=0.6, ankle=0.08, elbow=1.36, wrist=1.06)
# the commander's cape hangs on two chains of bones (left and right half): the game swings them with
# a SpringBoneSimulator3D, so the cloth falls with gravity, trails behind and slides off the legs
CAPE_TOP, CAPE_SEG, CAPE_N = 1.64, 0.235, 4
def cape_y(x, z):
    return -0.3 + 1.1 * x * x - (1.68 - z) * 0.14
if VEL:
    for side, cx in (("L", 0.2), ("R", -0.2)):
        for k in range(CAPE_N):
            z0, z1 = CAPE_TOP - k * CAPE_SEG, CAPE_TOP - (k + 1) * CAPE_SEG
            B["cape.%s.%d" % (side, k)] = ((cx, cape_y(cx, z0) - 0.02, z0), (cx, cape_y(cx, z1) - 0.02, z1),
                                            "spine" if k == 0 else "cape.%s.%d" % (side, k - 1))
rig = A.make_rig("Kol", B)
p = []
# ---- head: purple face, huge fanged mouth, yellow eyes, the blocky crest of the helmet --------------------------------------
H = "head"
p.append(S(skin, (0, 0.04, 1.96), 0.15, (0.95, 1.0, 1.15), H))
p.append(S(skin2, (0, 0.12, 2.02), 0.08, (1.5, 0.5, 0.45), H))                         # heavy brow
p.append(S(mouth, (0, 0.13, 1.88), 0.075, (1.0, 0.55, 1.15), H))                       # the open mouth
p.append(S(skin, (0, 0.08, 1.8), 0.09, (1.1, 0.8, 0.5), H))                            # the jaw hanging low
for x in (1, -1):
    p.append(S(eye, (0.06 * x, 0.15, 1.985), 0.02, (1.2, 0.6, 0.8), H, 8, 6))
    for i in range(4):                                                                  # fangs, long, top and bottom
        xx = (0.012 + i * 0.016) * x
        ln = 0.06 if i == 2 else 0.04
        p.append(smooth(A.limb(tooth, (xx, 0.165, 1.93), (xx, 0.17, 1.93 - ln), 0.009, 0.0, verts=5, group=H)))
        p.append(smooth(A.limb(tooth, (xx, 0.16, 1.83), (xx, 0.165, 1.83 + ln * 0.8), 0.008, 0.0, verts=5, group=H)))
p.append(chamf(box(arm, (0, -0.02, 2.11), (0.26, 0.3, 0.12), group=H), 0.025))          # the helmet crest
p.append(chamf(box(arm2, (0, 0.0, 2.19), (0.16, 0.24, 0.07), group=H), 0.02))
p.append(chamf(box(arm, (0, -0.08, 1.98), (0.3, 0.16, 0.2), group=H), 0.03))            # back of the helmet
# ---- neck and the massive torso: armour shaped like muscle, light in the seams -------------------------------------------
p.append(L(arm, (0, -0.03, 1.64), (0, 0.0, 1.86), 0.21, 0.12, 12, "neck"))
T = "spine"
p.append(S(arm, (0, 0.0, 1.5), 0.34, (1.2, 0.8, 0.92), T))
for x in (1, -1):
    p.append(S(arm, (0.15 * x, 0.17, 1.55), 0.17, (1.05, 0.6, 0.8), T))                 # pecs
    p.append(seam((0.03 * x, 0.27, 1.62), (0.27 * x, 0.2, 1.48), T))
    p.append(S(arm2, (0.27 * x, -0.12, 1.5), 0.17, (0.8, 0.7, 1.1), T))                 # lats
    for r_ in range(3):
        p.append(S(arm, (0.07 * x, 0.2, 1.33 - r_ * 0.1), 0.065, (1.15, 0.6, 0.8), T, 10, 6))   # ab plates
        p.append(seam((0.02 * x, 0.25, 1.28 - r_ * 0.1), (0.12 * x, 0.23, 1.28 - r_ * 0.1), T, 0.008))
    p.append(seam((0.2 * x, 0.15, 1.3), (0.24 * x, 0.06, 1.15), T))                     # flank lights
# (no centre line: the abs read better without it)
p.append(L(arm, (0, 0, 1.12), (0, 0.02, 1.32), 0.21, 0.25, 12, T))
p.append(S(arm2, (0, 0, 1.08), 0.23, (1.1, 0.85, 0.7), "hips"))
p.append(chamf(box(arm, (0, 0.17, 1.02), (0.3, 0.08, 0.16), group="hips"), 0.02))     # the groin plate
# ---- arms: layered pauldrons, plated arms, bare purple fists ---------------------------------------------------------------
for sd, x in (("L", 1), ("R", -1)):
    U, F, HD = "upperarm." + sd, "forearm." + sd, "hand." + sd
    for k in range(3):                                                                   # layered pauldron
        p.append(S(arm if k % 2 == 0 else arm2, (0.4 * x, 0, 1.7 - k * 0.07), 0.17 - k * 0.015, (1.05, 1.0, 0.55), U, 14, 8))
        p.append(seam((0.31 * x, 0.12, 1.66 - k * 0.07), (0.52 * x, 0.06, 1.62 - k * 0.07), U, 0.008))
    p.append(L(arm, (0.4 * x, 0, 1.62), (0.43 * x, 0, 1.36), 0.13, 0.1, 12, U))
    p.append(S(arm2, (0.42 * x, 0.07, 1.5), 0.09, (1, 1, 1.4), U))                       # biceps
    p.append(L(arm, (0.43 * x, 0, 1.36), (0.45 * x, 0, 1.1), 0.11, 0.08, 12, F))
    p.append(chamf(box(arm2, (0.46 * x, 0, 1.22), (0.18, 0.2, 0.22), group=F), 0.03))    # forearm plate
    p.append(seam((0.555 * x, 0.02, 1.3), (0.555 * x, 0.02, 1.14), F))
    p.append(S(skin, (0.45 * x, 0.02, 1.01), 0.075, (1, 1.1, 1.2), HD))                  # the fist
    for f in range(4):
        p.append(S(skin2, (0.45 * x + (f - 1.5) * 0.025, 0.08, 0.98), 0.022, group=HD, seg=8, rings=5))
# ---- legs: thick, plated, knee guards, heavy boots ----------------------------------------------------------------------------
for sd, x in (("L", 1), ("R", -1)):
    TH, SH = "thigh." + sd, "shin." + sd
    p.append(L(arm, (0.17 * x, 0, 1.06), (0.17 * x, 0.03, 0.6), 0.17, 0.11, 12, TH))
    p.append(S(arm2, (0.17 * x, 0.09, 0.86), 0.11, (1, 1, 1.5), TH))
    p.append(seam((0.29 * x, 0.04, 1.0), (0.26 * x, 0.08, 0.7), TH))
    p.append(chamf(box(arm, (0.17 * x, 0.12, 0.6), (0.17, 0.08, 0.16), group=SH), 0.025))   # knee guard
    p.append(L(arm, (0.17 * x, 0.03, 0.6), (0.17 * x, 0, 0.14), 0.11, 0.08, 12, SH))
    p.append(S(arm2, (0.17 * x, -0.06, 0.45), 0.085, (1, 1, 1.4), SH))
    p.append(seam((0.17 * x, 0.12, 0.48), (0.17 * x, 0.09, 0.22), SH, 0.01))
    p.append(chamf(box(arm2, (0.17 * x, 0.05, 0.07), (0.2, 0.34, 0.14), group=SH), 0.03))   # boot
# ---- the energy rifle in the right hand ----------------------------------------------------------------------------------------
G = "hand.R"
gx, gy, gz = -0.45, 0.05, 0.98
p.append(chamf(box(gunm, (gx, gy + 0.03, gz - 0.28), (0.11, 0.15, 0.6), group=G), 0.02))
p.append(smooth(A.limb(glow, (gx, gy + 0.11, gz - 0.1), (gx, gy + 0.11, gz - 0.5), 0.028, 0.028, verts=10, group=G)))
p.append(chamf(box(gunm, (gx, gy + 0.03, gz - 0.62), (0.13, 0.17, 0.1), group=G), 0.02))
for c in (-1, 1):                                                                       # claw-like prongs at the muzzle
    p.append(smooth(A.limb(gunm, (gx + c * 0.04, gy + 0.03, gz - 0.66), (gx + c * 0.025, gy + 0.05, gz - 0.78), 0.022, 0.006, verts=6, group=G)))
p.append(S(glow, (gx, gy + 0.04, gz - 0.7), 0.03, group=G, seg=10, rings=6))

if VEL:
    # reinforced angular plates over the muscle armour, red light slots
    T = "spine"
    p.append(chamf(box(arm, (0, 0.2, 1.55), (0.5, 0.12, 0.3), group=T), 0.04))           # breastplate
    p.append(chamf(box(arm2, (0, 0.27, 1.6), (0.14, 0.02, 0.1), rot=(0, 0, 0.785), group=T), 0.01))   # the sigil
    for k in range(3):
        p.append(box(glow, (0, 0.265, 1.44 - k * 0.04), (0.12, 0.01, 0.012), group=T))
    for x in (1, -1):
        for k in range(3):
            p.append(chamf(box(arm, (0.1 * x, 0.2, 1.32 - k * 0.09), (0.14, 0.08, 0.07), group=T), 0.015))
    p.append(chamf(box(dark, (0, 0.05, 1.16), (0.66, 0.5, 0.08), group=T), 0.015))        # the belt with pouches
    for x in (-0.24, -0.08, 0.08, 0.24):
        p.append(chamf(box(arm2, (x, 0.28, 1.16), (0.1, 0.06, 0.1), group=T), 0.01))
    p.append(chamf(box(arm, (0, 0.2, 0.95), (0.2, 0.06, 0.32), group="hips"), 0.02))      # the tabard plate
    for x in (1, -1):                                                                     # big angular pauldrons
        p.append(chamf(box(arm, (0.44 * x, 0.0, 1.76), (0.36, 0.42, 0.14), rot=(0, 0.35 * x, 0), group="upperarm." + ("L" if x > 0 else "R")), 0.04))
        p.append(chamf(box(arm2, (0.5 * x, 0.0, 1.64), (0.3, 0.38, 0.1), rot=(0, 0.5 * x, 0), group="upperarm." + ("L" if x > 0 else "R")), 0.03))
        for k in range(2):
            p.append(box(glow, (0.48 * x, 0.2, 1.72 - k * 0.06), (0.1, 0.01, 0.012), rot=(0, 0.35 * x, 0), group="upperarm." + ("L" if x > 0 else "R")))
        sd = "L" if x > 0 else "R"
        p.append(chamf(box(arm, (0.17 * x, 0.14, 0.86), (0.2, 0.08, 0.3), group="thigh." + sd), 0.03))
        p.append(chamf(box(arm, (0.17 * x, 0.1, 0.35), (0.16, 0.08, 0.3), group="shin." + sd), 0.03))
        for k in range(3):
            p.append(box(glow, (0.17 * x, 0.145, 0.42 - k * 0.06), (0.06, 0.01, 0.012), group="shin." + sd))
    # hoses from the helmet into the collar
    for x in (1, -1):
        pts = [(0.12 * x, -0.08, 2.0), (0.2 * x, -0.12, 1.88), (0.22 * x, -0.06, 1.74)]
        for i in range(2):
            p.append(L(dark, pts[i], pts[i + 1], 0.022, 0.022, 8, "neck"))
    p.append(box(glow, (0, 0.1, 2.1), (0.08, 0.01, 0.015), group="head"))
    # the command module on the left forearm: a box with a red screen
    F = "forearm.L"
    p.append(chamf(box(dark, (0.47, 0.06, 1.22), (0.22, 0.24, 0.26), group=F), 0.02))
    p.append(box(screen, (0.47, 0.185, 1.22), (0.15, 0.01, 0.17), group=F))
    for k in range(3):
        p.append(box(glow, (0.585, 0.06, 1.3 - k * 0.07), (0.01, 0.12, 0.03), group=F))
    # the cape: torn, hanging from the shoulders down the back
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=14, y_subdivisions=12, size=1.0)
    cp = _finish(bpy.context.active_object, cape_m, (0, -0.3, 1.12), (math.pi / 2, 0, 0), (0.85, 1.12, 1.0))
    import random
    random.seed(7)
    for v in cp.data.vertices:
        x, z = v.co.x, v.co.z
        v.co.y = -0.3 + 1.1 * x * x - (1.68 - z) * 0.14                  # wraps round the back, flares out below
        if z > 1.62:
            v.co.y += 0.12                                               # gathered at the shoulders
        if z < 0.75:
            v.co.z += random.uniform(-0.12, 0.08)                        # a torn hem
    cp.modifiers.new("Solid", 'SOLIDIFY').thickness = 0.015
    bpy.ops.object.select_all(action='DESELECT')
    cp.select_set(True)
    bpy.context.view_layer.objects.active = cp
    bpy.ops.object.modifier_apply(modifier="Solid")
    # weights: the top stays on the back, lower down the two chains take over, blended across the middle
    vgs = {"spine": cp.vertex_groups.new(name="spine")}
    for side in ("L", "R"):
        for k in range(CAPE_N):
            n = "cape.%s.%d" % (side, k)
            vgs[n] = cp.vertex_groups.new(name=n)
    for v in cp.data.vertices:
        x, z = v.co.x, v.co.z
        u = max(0.0, (CAPE_TOP - z) / CAPE_SEG)
        sp = max(0.0, min(1.0, 1.0 - u * 1.6))                 # the shoulders: on the spine
        wl = max(0.0, min(1.0, 0.5 + x / 0.4))                  # how much the left chain has it
        i = min(int(u), CAPE_N - 1)
        f = min(1.0, u - i) if i < CAPE_N - 1 else 0.0
        if sp > 0.0:
            vgs["spine"].add([v.index], sp, 'REPLACE')
        for side, ws in (("L", wl), ("R", 1.0 - wl)):
            w = ws * (1.0 - sp)
            if w <= 0.001:
                continue
            vgs["cape.%s.%d" % (side, i)].add([v.index], w * (1.0 - f), 'REPLACE')
            if f > 0.0:
                vgs["cape.%s.%d" % (side, i + 1)].add([v.index], w * f, 'REPLACE')
    p.append(cp)
    # the heavy weapon: bigger, a red core
    G = "hand.R"
    gx, gy, gz = -0.45, 0.05, 0.98
    p.append(chamf(box(dark, (gx, gy + 0.03, gz - 0.35), (0.16, 0.2, 0.8), group=G), 0.025))
    p.append(smooth(A.limb(glow, (gx, gy + 0.135, gz - 0.12), (gx, gy + 0.135, gz - 0.7), 0.035, 0.035, verts=10, group=G)))
body = A.bind(rig, p, "KolosVelitel" if VEL else "Kolos")
A.soldier_anims(rig, True, 1.4)
for b in rig.pose.bones:
    b.rotation_euler = (0, 0, 0)
    b.location = (0, 0, 0)
A.finish([rig, body], rig, target=(0, 0, 1.15), dist=4.4)
print("written", A.OUT)
