"""Levit v2 (0.57 pokus) after Ari's picture: a stitched, scarred torso with a skull of a face - red glowing eyes,
a gaping mouth full of long fangs, an implant plate bolted to the skull - hoses from a glowing red tank on the back
into the neck and shoulders, an armoured chest harness with red light strips, thin long arms. Below, the pulsing
magenta anti-gravity organ in a net of veins and many long hanging tentacles. No weapon, T-pose, one unrigged mesh.
Commander (velitel, the violet picture): violet light, a bigger organ, more tentacles, glowing canisters and two
steel arcs behind the shoulders, a tangle of hoses.
Run: python levit_v2.py [velitel] <out_base_without_ext> [--preview <dir>]"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
from creature_v2 import *
from creature_v2 import _apply_mods, _finish

VEL = "velitel" in sys.argv
NAME = "levit_velitel_v2" if VEL else "levit_v2"
random.seed(7)
reset()
skin_m = mat2("LevSkin", (0.42, 0.3, 0.3) if not VEL else (0.38, 0.26, 0.33), rough=0.45)
skin_d = mat2("LevSkin2", (0.27, 0.18, 0.19) if not VEL else (0.24, 0.14, 0.21), rough=0.55)
scar = mat2("LevScar", (0.15, 0.05, 0.06), rough=0.6)
bone = mat2("LevBone", (0.6, 0.54, 0.47), rough=0.45)
dark = mat2("LevMouth", (0.07, 0.01, 0.015), rough=0.4)
tooth = mat2("LevTooth", (0.74, 0.68, 0.56), rough=0.35)
metal = mat2("LevMetal", (0.24, 0.24, 0.25), rough=0.4, metal=0.8)
hose = mat2("LevHose", (0.05, 0.05, 0.055), rough=0.5)
if VEL:
    eye = mat("LevVEye", (0.85, 0.35, 1.0), emit=7.0)
    glow = mat("LevVGlow", (0.72, 0.2, 1.0), emit=3.0)
    organ = mat("LevVOrgan", (0.65, 0.15, 0.95), emit=2.4)
    vein = mat2("LevVVein", (0.24, 0.05, 0.24), rough=0.35)
    tent = mat2("LevVTent", (0.3, 0.12, 0.27), rough=0.3)
else:
    eye = mat("LevEye", (1.0, 0.12, 0.08), emit=6.0)
    glow = mat("LevGlow", (1.0, 0.1, 0.06), emit=3.5)
    organ = mat("LevOrgan", (0.95, 0.2, 0.6), emit=2.6)
    vein = mat2("LevVein", (0.3, 0.04, 0.08), rough=0.35)
    tent = mat2("LevTent", (0.36, 0.12, 0.14), rough=0.35)

AY = 1.66
P = []
# ---- torso and arms: one skin mesh -------------------------------------------------------------------------------
N = [((0, 0, 1.3), 0.1), ((0, 0.01, 1.42), 0.125), ((0, 0.01, 1.55), 0.16), ((0, 0, AY), 0.155),
     ((0, 0.02, 1.78), 0.06), ((0, 0.03, 1.86), 0.065)]
E = [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5)]
for x in (1, -1):
    b = len(N)
    N += [((0.19 * x, 0, AY), 0.07), ((0.33 * x, 0, AY), 0.055), ((0.48 * x, 0, AY), 0.04),
          ((0.62 * x, 0, AY), 0.04), ((0.75 * x, 0, AY), 0.028), ((0.8 * x, 0, AY), 0.035)]
    E += [(3, b), (b, b + 1), (b + 1, b + 2), (b + 2, b + 3), (b + 3, b + 4), (b + 4, b + 5)]
P.append(skin(skin_m, N, E, "LevBody", subsurf=2))
side = []
# ribs showing through, stitches and scars
for k in range(4):
    z = 1.42 + k * 0.055
    side.append(limb(skin_d, (0.03, 0.13 - k * 0.005, z), (0.13, 0.08, z - 0.03), 0.012, 0.009, verts=6))
for k in range(6):                                                                        # a stitched seam down the side
    z = 1.36 + k * 0.05
    side.append(bbox(scar, (0.13, 0.06, z), (0.035, 0.008, 0.007), rot=(0, 0.3, 0.6)))
side.append(limb(scar, (0.1, 0.11, 1.32), (0.15, 0.03, 1.64), 0.005, 0.005, verts=4))
# long fingers with claws
for k in range(4):
    a = Vector((0.82, 0.03 - k * 0.022, AY))
    if k == 0:
        a, b = Vector((0.79, 0.04, AY - 0.01)), Vector((0.85, 0.08, AY - 0.04))
    else:
        b = Vector((0.95, 0.03 - k * 0.025, AY - 0.02))
    side.append(limb(skin_d, a, b, 0.012, 0.009, verts=6))
    side.append(spike(bone, b, b + (b - a).normalized() * 0.03 + Vector((0, 0, -0.02)), 0.009))
for k in range(3):                                                                         # bones poking through the forearm
    side.append(spike(bone, (0.55 + k * 0.06, -0.03, AY + 0.02), (0.57 + k * 0.06, -0.05, AY + 0.05), 0.008))
# chest harness: plate, straps, red strips
side.append(bbox(metal, (0.075, 0.135, 1.6), (0.1, 0.025, 0.12), rot=(0.15, 0.25, 0.1), bevel=0.25, seg=2))
side.append(bbox(glow, (0.1, 0.15, 1.58), (0.01, 0.006, 0.08), rot=(0.15, 0.25, 0.1)))
side.append(limb(hose, (0.08, 0.12, 1.7), (0.15, 0.0, AY + 0.07), 0.016, 0.016, verts=4, sm=False))
side.append(limb(hose, (0.15, 0.0, AY + 0.07), (0.08, -0.15, 1.66), 0.016, 0.016, verts=4, sm=False))
side.append(smooth(sphere(metal, (0.2, 0.0, AY + 0.05), 0.065, seg=12, rings=8, scale=(1.0, 1.0, 0.6))))   # shoulder cap
side.append(bbox(glow, (0.2, 0.06, AY + 0.06), (0.05, 0.006, 0.012)))
P += side + mirror_x(side)
P.append(bbox(metal, (0, 0.13, 1.47), (0.1, 0.025, 0.06), bevel=0.25, seg=2))
P.append(bbox(glow, (0, 0.144, 1.47), (0.05, 0.006, 0.01)))
P.append(bbox(metal, (0, -0.13, 1.58), (0.26, 0.05, 0.22), bevel=0.2, seg=2))                 # back plate
# ---- spine hanging out under the torso, down into the organ -----------------------------------------------------------
for k in range(4):
    P.append(smooth(sphere(bone, (0, -0.02, 1.27 - k * 0.04), 0.03, seg=8, rings=6, scale=(1.3, 1.0, 0.6))))
# ---- the head: skull face, red eyes, gaping fanged mouth, implant plate, stitches ----------------------------------
F = Vector((0, 0.04, 1.97))
P.append(smooth(sphere(skin_m, F, 0.1, seg=20, rings=14, scale=(0.88, 0.95, 1.12))))
P.append(smooth(sphere(skin_d, F + Vector((0, 0.04, -0.08)), 0.07, seg=14, rings=10, scale=(0.95, 0.8, 1.0))))    # jaw
for x in (1, -1):
    P.append(smooth(sphere(skin_d, F + Vector((0.045 * x, 0.075, 0.02)), 0.026, seg=10, rings=8, scale=(1.0, 0.6, 0.9))))   # socket
    P.append(smooth(sphere(eye, F + Vector((0.044 * x, 0.088, 0.02)), 0.012, seg=10, rings=8)))
    P.append(smooth(sphere(skin_m, F + Vector((0.07 * x, 0.06, -0.02)), 0.025, seg=8, rings=6, scale=(1.0, 0.8, 1.3))))  # cheekbone
P.append(smooth(sphere(dark, F + Vector((0, 0.1, -0.025)), 0.012, seg=6, rings=4, scale=(1.3, 0.6, 1.0))))      # nose hole
P += closed_mouth(F + Vector((0, 0.094, -0.075)), 0.045, 6.5, 2.5, skin_d, dark, tooth, n=10, fangs=(1, 8, 4),
                  tooth_len=0.014, fang_len=0.03, tooth_r=0.0045, seam_r=0.004, lip=0.007)
for k in range(5):                                                                        # stitches over the crown
    P.append(bbox(scar, (-0.02 + k * 0.012, 0.06 - k * 0.03, 2.08 - abs(k - 2) * 0.006), (0.03, 0.006, 0.006), rot=(0, 0, 0.9)))
P.append(limb(scar, (0.0, 0.08, 2.07), (0.0, -0.08, 2.06), 0.004, 0.004, verts=4))
P.append(bbox(metal, F + Vector((0.075, -0.02, 0.05)), (0.035, 0.1, 0.08), rot=(0, 0.35, 0), bevel=0.2, seg=2))    # implant
for dy in (-0.04, 0.0, 0.04):
    P.append(smooth(sphere(metal, F + Vector((0.093, -0.02 + dy, 0.05 + dy * 0.3)), 0.008, seg=6, rings=4)))
P.append(bbox(glow, F + Vector((0.095, 0.0, 0.07)), (0.006, 0.04, 0.008), rot=(0, 0.35, 0)))
# ---- tank on the back and hoses into the neck and shoulders -------------------------------------------------------
tanks = [(0.0, -0.22, 1.66)] if not VEL else [(0.11, -0.22, 1.7), (-0.11, -0.22, 1.7)]
for t in tanks:
    t = Vector(t)
    P.append(smooth(cyl(glow, t, 0.05, 0.2, verts=14)))
    for dz in (-0.11, 0.11):
        P.append(smooth(cyl(metal, t + Vector((0, 0, dz)), 0.058, 0.04, verts=14)))
    P += tube(hose, [t + Vector((0, 0, 0.13)), t + Vector((0, 0.04, 0.23)), (t.x * 0.4, -0.02, 1.84), (t.x * 0.3, 0.0, 1.8)], 0.012)
    for x in (1, -1):
        P += tube(hose, [t + Vector((0.05 * x, 0, 0.08)), (0.16 * x, -0.17, 1.82), (0.2 * x, -0.06, 1.74)], 0.011)
if VEL:
    for x in (1, -1):                                                                     # steel arcs with canisters
        arc = [Vector((0.22 * x * math.sin(a), -0.24, 1.5 + 0.5 * math.cos(a) * 0.9)) for a in [i * math.pi / 8 for i in range(0, 8)]]
        arc = [Vector((p.x + 0.12 * x, p.y, p.z)) for p in arc]
        P += tube(metal, arc, 0.022, verts=6)
        for p in (arc[2], arc[5]):
            P.append(smooth(cyl(glow, p + Vector((0.06 * x, 0.04, 0)), 0.035, 0.1, verts=12)))
            for dz in (-0.058, 0.058):
                P.append(smooth(cyl(metal, p + Vector((0.06 * x, 0.04, dz)), 0.04, 0.02, verts=12)))
    for i in range(10):                                                                    # glowing loops of hose round the body
        a = i / 10 * 2 * math.pi
        r = 0.26 + 0.05 * (i % 2)
        p0 = Vector((math.cos(a) * 0.15, math.sin(a) * 0.12, 1.45 + 0.05 * (i % 3)))
        p1 = Vector((math.cos(a) * r, math.sin(a) * r, 1.32 + 0.1 * (i % 3)))
        p2 = Vector((math.cos(a) * r * 0.9, math.sin(a) * r * 0.9, 1.12))
        P += tube(glow if i % 3 == 0 else hose, [p0, p1, p2], 0.013)
# ---- the organ, its net of veins and the tentacles ------------------------------------------------------------------
OC = Vector((0, 0, 1.08))
OR = 0.21 if not VEL else 0.26
P.append(smooth(sphere(organ, OC, OR, seg=20, rings=14, scale=(1.0, 0.95, 0.9))))
for i in range(9):                                                                         # veins: meridians plus a twist
    a0 = i / 9 * 2 * math.pi
    pts = []
    for j in range(9):
        t = j / 8
        el = -math.pi / 2 + math.pi * t
        a = a0 + 0.5 * math.sin(t * 3 + i)
        pts.append(OC + Vector((math.cos(a) * math.cos(el) * OR * 1.03, math.sin(a) * math.cos(el) * OR * 0.98, math.sin(el) * OR * 0.93)))
    P += tube(vein, pts[1:-1], 0.008, verts=5)
for j in range(3):                                                                         # rings of vein
    el = -0.6 + j * 0.6
    pts = [OC + Vector((math.cos(a) * math.cos(el) * OR * 1.04, math.sin(a) * math.cos(el) * OR, math.sin(el) * OR * 0.94)) for a in [k / 14 * 2 * math.pi for k in range(15)]]
    P += tube(vein, pts, 0.007, verts=5)
# fleshy collar joining the organ to the torso
P.append(smooth(sphere(skin_d, (0, 0, 1.27), 0.11, seg=14, rings=8, scale=(1.1, 1.0, 0.5))))
NT = 12 if not VEL else 16
TENTS = []
for i in range(NT):
    a = i / NT * 2 * math.pi + random.uniform(-0.15, 0.15)
    el = random.uniform(-0.9, 0.1)
    start = OC + Vector((math.cos(a) * math.cos(el) * OR * 0.85, math.sin(a) * math.cos(el) * OR * 0.85, math.sin(el) * OR * 0.85))
    ln = random.uniform(0.75, 1.05) * (1.15 if VEL else 1.0)
    r0 = 0.04 if not VEL else 0.045
    n = 9
    curl = random.choice((1, -1))
    TN, TE = [], []
    for j in range(n):
        t = j / (n - 1)
        out = 0.12 + 0.25 * t * (1 - t) + 0.06 * t
        p = start + Vector((math.cos(a) * out, math.sin(a) * out, -ln * t))
        p += Vector((-math.sin(a), math.cos(a), 0)) * 0.08 * math.sin(t * 5 + i) * t
        if j == n - 1:                                                                    # curled tip
            p += Vector((math.cos(a) * 0.05 * curl, math.sin(a) * 0.05 * curl, 0.04))
        TN.append((p, max(0.006, r0 * (1 - t * 0.88))))
        if j:
            TE.append((j - 1, j))
    P.append(skin(tent, TN, TE, "LevTent%d" % i, subsurf=1))
    p, r = TN[2]
    if random.random() < 0.5:                                                              # dripping strings
        P.append(limb(organ if VEL else vein, p, p + Vector((0, 0, -0.08)), 0.004, 0.002, verts=4))

o = finish_mesh(P, NAME)
print("STATS", stats(o))
ARGS = [a for a in sys.argv[1:] if a != "velitel"]
OUT = ARGS[0] if ARGS and not ARGS[0].startswith("--") else NAME
if "--preview" in sys.argv:
    d = sys.argv[sys.argv.index("--preview") + 1]
    render(os.path.join(d, NAME + "_front.png"), (0, 0, 1.1), 4.2, 0.0, 0.2)
    render(os.path.join(d, NAME + "_34.png"), (0, 0, 1.1), 4.2, 0.7, 0.5)
    render(os.path.join(d, NAME + "_head.png"), (0, 0.05, 1.9), 1.0, 0.45, 0.05)
else:
    export_all(o, OUT)
    print("written", OUT)
