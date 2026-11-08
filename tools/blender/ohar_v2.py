"""Ohař v2 (0.57 pokus) after Ari's picture: a long, lean, flayed hound - pink-brown hide over raw muscle, steel
clamps round the legs, a segmented armour spine with violet light between the plates and steel spikes on top,
hoses arcing over the back, a glowing violet canister on the neck, violet eyes, a gaping fanged jaw and a long
steel blade bolted along the snout, hooked steel claws, a tail. No weapon (it is a beast); neutral standing pose,
one unrigged light mesh for afk.ai (instead of the 230k-vertex meshy model).
Run: python ohar_v2.py <out_base_without_ext> [--preview <dir>]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from creature_v2 import *

reset()
hide = mat2("OhaHide", (0.36, 0.2, 0.2), rough=0.45)
hide2 = mat2("OhaHide2", (0.26, 0.12, 0.14), rough=0.5)
raw = mat2("OhaRaw", (0.38, 0.05, 0.07), rough=0.35)
mouth = mat2("OhaMouth", (0.14, 0.01, 0.03), rough=0.4)
tooth = mat2("OhaTooth", (0.75, 0.69, 0.57), rough=0.35)
steel = mat2("OhaSteel", (0.3, 0.29, 0.3), rough=0.35, metal=0.85)
blade_m = mat2("OhaBlade", (0.62, 0.6, 0.62), rough=0.2, metal=0.95)
blood = mat2("OhaBlood", (0.3, 0.02, 0.03), rough=0.3)
hose = mat2("OhaHose", (0.13, 0.08, 0.15), rough=0.5)
glow = mat("OhaGlow", (0.7, 0.15, 1.0), emit=3.0)
eye = mat("OhaEye", (0.85, 0.35, 1.0), emit=8.0)

P = []
# ---- body: one skin from tail tip to the back of the skull, four long legs ---------------------------------------
N = [((0, -0.5, 0.96), 0.17),     # 0 hips
     ((0, -0.22, 0.98), 0.14),    # 1 starved waist
     ((0, 0.12, 1.03), 0.23),      # 2 chest
     ((0, 0.38, 1.06), 0.2),     # 3 shoulders
     ((0, 0.6, 1.07), 0.125),     # 4 neck
     ((0, 0.78, 1.05), 0.095),    # 5 back of the skull
     ((0, -0.72, 0.92), 0.075),   # 6 tail
     ((0, -0.98, 0.8), 0.05),
     ((0, -1.22, 0.62), 0.03),
     ((0, -1.38, 0.46), 0.012)]
E = [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (0, 6), (6, 7), (7, 8), (8, 9)]
for x in (1, -1):
    b = len(N)                                                    # front leg
    N += [((0.19 * x, 0.36, 0.96), 0.13), ((0.21 * x, 0.4, 0.74), 0.1), ((0.21 * x, 0.42, 0.56), 0.07), ((0.21 * x, 0.44, 0.18), 0.045), ((0.21 * x, 0.5, 0.05), 0.055)]
    E += [(3, b), (b, b + 1), (b + 1, b + 2), (b + 2, b + 3), (b + 3, b + 4)]
    b = len(N)                                                    # hind leg, backward hock
    N += [((0.17 * x, -0.5, 0.9), 0.16), ((0.18 * x, -0.42, 0.72), 0.13), ((0.19 * x, -0.32, 0.56), 0.085), ((0.2 * x, -0.54, 0.24), 0.05), ((0.2 * x, -0.44, 0.05), 0.055)]
    E += [(0, b), (b, b + 1), (b + 1, b + 2), (b + 2, b + 3), (b + 3, b + 4)]
P.append(skin(hide, N, E, "OhaBody", subsurf=1))
SP = [N[i] for i in (0, 1, 2, 3, 4)]                     # spine nodes, back to front


def spine_at(y):
    """(centre z, radius) of the trunk at y (shrunk a little, like the subdivided skin)."""
    for (a, ra), (b, rb) in zip(SP, SP[1:]):
        if a[1] <= y <= b[1]:
            t = (y - a[1]) / (b[1] - a[1])
            return a[2] + (b[2] - a[2]) * t, (ra + (rb - ra) * t) * 0.93
    a, r = SP[0] if y < SP[0][0][1] else SP[-1]
    return a[2], r * 0.93


def leg_r(L, t):
    """radius of a leg (list of skin nodes) at fraction t of its length."""
    f = t * (len(L) - 1)
    i = min(int(f), len(L) - 2)
    return (L[i][1] + (L[i + 1][1] - L[i][1]) * (f - i)) * 0.93
P.append(smooth(sphere(hide2, (0, 0.18, 0.92), 0.2, seg=12, rings=8, scale=(0.75, 1.3, 0.75))))     # deep chest keel

side = []
# ---- flanks: ribs with violet light between them, flayed raw muscle, stitches -------------------------------------
for k in range(6):
    y = 0.34 - k * 0.09
    zc, r = spine_at(y)
    pts = [Vector((r * math.sin(a), y - a * 0.03, zc + r * math.cos(a))) for a in (0.55, 1.2, 1.9, 2.5)]
    for p0, p1 in zip(pts, pts[1:]):
        side.append(limb(hide2, p0, p1, 0.024, 0.022, verts=6))
    if k < 5:
        side.append(bbox(glow, (r * 0.97, y - 0.06, zc - 0.02), (0.014, 0.04, r * 1.0), rot=(0, 0.1, 0)))
zc, r = spine_at(-0.25)
side.append(smooth(sphere(raw, (r * 0.8, -0.25, zc - 0.02), 0.07, seg=10, rings=6, scale=(0.55, 2.2, 0.9))))
for k in range(5):
    side.append(bbox(blood, (r * 0.86, -0.35 + k * 0.05, zc + 0.05), (0.03, 0.007, 0.007)))
# ---- legs: raw muscle strips, steel clamps, paws with hooked steel claws ------------------------------------------
FL = N[10:15]           # left front leg skin nodes
HL = N[15:20]           # left hind leg
side.append(limb(raw, (0.3, 0.36, 0.92), (0.27, 0.4, 0.66), 0.05, 0.03))
side.append(limb(raw, (0.31, -0.48, 0.85), (0.26, -0.36, 0.6), 0.055, 0.03))
side.append(bbox(steel, (0.27, 0.34, 1.05), (0.12, 0.24, 0.09), rot=(0.2, -0.5, 0)))                    # shoulder plate
for Ln in (FL, HL):
    L = [n[0] for n in Ln]
    for i, t in ((1, 0.5), (2, 0.35), (2, 0.8)):
        side.append(band(steel, L[i], L[i + 1], t, Ln[i][1] + (Ln[i + 1][1] - Ln[i][1]) * t + 0.004, 0.013))
    foot = Vector(L[-1])
    for c in (-1, 0, 1):
        b0 = foot + Vector((c * 0.03, 0.04, 0))
        side.append(spike(steel, b0, b0 + Vector((c * 0.02, 0.13, -0.045)), 0.014, verts=4))
    side.append(spike(steel, foot + Vector((0, -0.03, 0.04)), foot + Vector((0, -0.11, -0.03)), 0.012, verts=4))
# ---- hoses arcing over the back --------------------------------------------------------------------------------------
for y0 in (-0.3, 0.0, 0.26):
    side += tube(hose, [(0.07, y0, 1.16), (0.16, y0 + 0.04, 1.24), (0.23, y0 + 0.08, 1.12), (0.19, y0 + 0.1, 1.0)], 0.014)
side += tube(hose, [(0.03, 0.47, 1.22), (0.1, 0.38, 1.3), (0.13, 0.28, 1.2)], 0.014)
P += side + mirror_x(side)
# ---- the armoured spine: plates, violet slots, spikes ----------------------------------------------------------------
for k in range(8):
    y = -0.52 + k * 0.125
    zc, r = spine_at(y)
    z = zc + r + 0.015
    P.append(bbox(steel, (0, y, z), (0.27 - abs(k - 4) * 0.012, 0.11, 0.08), rot=(0.12, 0, 0)))
    for x in (1, -1):                                                                  # side flaps
        P.append(bbox(steel, (0.1 * x, y, z - 0.05), (0.09, 0.1, 0.05), rot=(0.12, 0.7 * x, 0)))
    P.append(bbox(glow, (0, y + 0.065, z - 0.005), (0.18, 0.02, 0.035)))
    if k >= 2:
        P.append(spike(steel, (0, y, z + 0.02), (0, y - 0.07, z + 0.12 + (k - 2) * 0.025), 0.03, verts=4))
for k in range(3):                                                                                  # tail hooks
    P.append(spike(steel, (0, -0.8 - k * 0.15, 0.89 - k * 0.07), (0, -0.86 - k * 0.15, 0.97 - k * 0.07), 0.012, verts=4))
# ---- neck canister in a steel cage ---------------------------------------------------------------------------------------
P.append(band(steel, (0, 0.5, 1.07), (0, 0.78, 1.05), 0.3, 0.115, 0.014))
P.append(band(steel, (0, 0.5, 1.07), (0, 0.78, 1.05), 0.75, 0.1, 0.014))
P.append(smooth(cyl(glow, (0, 0.6, 1.19), 0.05, 0.24, verts=12, rot=(math.pi / 2 - 0.05, 0, 0))))
for dy in (-0.14, 0.14):
    P.append(smooth(cyl(steel, (0, 0.6 + dy, 1.19), 0.06, 0.05, verts=12, rot=(math.pi / 2 - 0.05, 0, 0))))
for a in (0.0, 2.1, 4.2):
    P.append(limb(steel, (math.sin(a) * 0.056, 0.47, 1.19 + math.cos(a) * 0.056), (math.sin(a) * 0.056, 0.73, 1.19 + math.cos(a) * 0.056), 0.008, 0.008, verts=4))
# ---- the head: long skull, violet eyes, gaping jaw full of fangs, blade along the snout ----------------------------------
P.append(smooth(sphere(hide, (0, 0.9, 1.05), 0.125, seg=14, rings=9, scale=(0.85, 1.55, 0.75))))
P.append(smooth(sphere(hide2, (0, 1.04, 1.0), 0.07, seg=12, rings=8, scale=(0.8, 1.8, 0.55))))           # upper muzzle
P.append(smooth(sphere(mouth, (0, 0.99, 0.93), 0.075, seg=12, rings=8, scale=(0.85, 1.8, 0.5))))         # throat / palate
HG = Vector((0, 0.82, 0.96)); JA = -0.55
JD = Vector((0, math.cos(JA), math.sin(JA))); JN = Vector((0, -math.sin(JA), math.cos(JA)))
P.append(smooth(sphere(hide2, HG + JD * 0.17, 0.07, seg=12, rings=8, scale=(0.9, 2.1, 0.42), rot=(JA, 0, 0))))   # lower jaw
for x in (1, -1):
    P.append(smooth(sphere(eye, (0.07 * x, 0.92, 1.08), 0.021, seg=8, rings=6)))
    P.append(bbox(steel, (0.07 * x, 0.9, 1.11), (0.03, 0.06, 0.012), rot=(0, 0, 0.3 * x)))
    for i in range(6):                                                                                   # upper fangs
        y = 0.95 + i * 0.04
        w = 0.055 * (1 - i * 0.09)
        ln = 0.075 if i in (0, 3) else 0.045
        P.append(spike(tooth, (w * x, y, 0.975), (w * x, y + 0.01, 0.975 - ln), 0.009))
    for i in range(5):                                                                                   # lower fangs
        sj = 0.08 + i * 0.04
        w = 0.05 * (1 - i * 0.1)
        bse = HG + JD * sj + JN * 0.025 + Vector((w * x, 0, 0))
        P.append(spike(tooth, bse, bse + JN * (0.065 if i == 1 else 0.04), 0.008))
    P.append(limb(raw, (0.04 * x, 1.0, 0.96), (0.035 * x, 1.0, 0.89), 0.006, 0.004, verts=4))           # dripping strings
bl = box(blade_m, (0, 1.36, 1.1), (0.035, 0.72, 0.15))
for v in bl.data.vertices:                                                                               # tapering to a point
    t = (v.co.y - 1.0) / 0.72
    v.co.z = 1.1 + (v.co.z - 1.1) * max(0.0, 1.0 - t ** 1.6) - t * 0.08
P.append(bl)
P.append(box(blood, (0, 1.22, 1.06), (0.038, 0.16, 0.025), rot=(0.1, 0, 0)))
P.append(box(blood, (0, 1.42, 1.035), (0.038, 0.08, 0.018), rot=(0.1, 0, 0)))
for y in (0.95, 1.07):
    P.append(bbox(steel, (0, y, 1.1), (0.07, 0.04, 0.12)))
P.append(bbox(glow, (0, 1.01, 1.14), (0.03, 0.08, 0.012)))

o = finish_mesh(P, "ohar_v2")
print("STATS", stats(o))
OUT = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else "ohar_v2"
if "--preview" in sys.argv:
    d = sys.argv[sys.argv.index("--preview") + 1]
    render(os.path.join(d, "ohar_side.png"), (0, 0.1, 0.7), 4.4, 1.45, 0.3)
    render(os.path.join(d, "ohar_34.png"), (0, 0.1, 0.7), 4.0, 0.75, 1.6)
    render(os.path.join(d, "ohar_head.png"), (0, 1.0, 1.0), 1.5, 0.9, 0.15)
else:
    export_all(o, OUT)
    print("written", OUT)
