"""Líhňák v2 (0.57 pokus; in the game files lihnoun / lihavec) after Ari's picture: a hunched predator of glossy
wine-dark chitin - spiked plates over slimy flesh, a spiky swept-back crest, huge jaws of long fangs with drool,
red eyes, red light between the belly plates. On the back a cluster of glowing red egg sacs and curved, spined
tentacles arching over it. Long arms with great hooked claws, spiked digitigrade legs, a spined tail.
T-pose (arms out), one unrigged mesh for afk.ai.
Run: python lihnoun_v2.py <out_base_without_ext> [--preview <dir>]"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
from creature_v2 import *
from creature_v2 import _apply_mods, _finish

NAME = "lihnoun_v2"
random.seed(3)
reset()
flesh = mat2("LihFlesh", (0.1, 0.018, 0.035), rough=0.3)
chit = mat2("LihChitin", (0.055, 0.012, 0.025), rough=0.2, metal=0.4)
chit2 = mat2("LihChitin2", (0.13, 0.03, 0.05), rough=0.22, metal=0.35)
claw = mat2("LihClaw", (0.72, 0.64, 0.56), rough=0.3)
tooth = mat2("LihTooth", (0.8, 0.74, 0.62), rough=0.3)
dark = mat2("LihMouth", (0.08, 0.0, 0.02), rough=0.4)
glow = mat("LihGlow", (1.0, 0.06, 0.08), emit=3.0)
egg = mat("LihEgg", (0.75, 0.03, 0.08), emit=2.2)
eye = mat("LihEye", (1.0, 0.1, 0.06), emit=7.0)
slime = mat2("LihSlime", (0.5, 0.35, 0.4), rough=0.1)

AY = 1.56
P = []
N = [((0, -0.05, 1.0), 0.17), ((0, 0.02, 1.2), 0.19), ((0, 0.08, 1.4), 0.23), ((0, 0.13, AY), 0.21),
     ((0, 0.27, 1.68), 0.1), ((0, 0.37, 1.73), 0.085),
     ((0, -0.27, 0.94), 0.13), ((0, -0.56, 0.8), 0.1), ((0, -0.85, 0.6), 0.07), ((0, -1.1, 0.42), 0.045), ((0, -1.32, 0.3), 0.018)]
E = [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (0, 6), (6, 7), (7, 8), (8, 9), (9, 10)]
for x in (1, -1):
    b = len(N)
    N += [((0.27 * x, 0.12, AY), 0.12), ((0.48 * x, 0.12, AY), 0.085), ((0.68 * x, 0.12, AY), 0.06),
          ((0.88 * x, 0.12, AY), 0.07), ((1.06 * x, 0.12, AY), 0.045), ((1.13 * x, 0.12, AY), 0.055)]
    E += [(3, b), (b, b + 1), (b + 1, b + 2), (b + 2, b + 3), (b + 3, b + 4), (b + 4, b + 5)]
    b = len(N)
    N += [((0.17 * x, -0.05, 0.97), 0.16), ((0.2 * x, 0.05, 0.73), 0.14), ((0.21 * x, 0.13, 0.52), 0.085),
          ((0.21 * x, -0.08, 0.22), 0.055), ((0.21 * x, 0.04, 0.07), 0.06), ((0.21 * x, 0.15, 0.05), 0.045)]
    E += [(0, b), (b, b + 1), (b + 1, b + 2), (b + 2, b + 3), (b + 3, b + 4), (b + 4, b + 5)]
P.append(skin(flesh, N, E, "LihBody", subsurf=2))


def plate(loc, size, rot=(0, 0, 0), m=None, spikes=0, sp_dir=(0, -0.3, 1), sp_len=0.08):
    out = [bbox(m or chit, loc, size, rot=rot, bevel=0.35, seg=2)]
    for k in range(spikes):
        t = (k + 0.5) / spikes - 0.5
        base = Vector(loc) + Vector((t * size[0] * 0.8, 0, size[2] * 0.4))
        out.append(spike(chit2, base, base + Vector(sp_dir).normalized() * sp_len, 0.018, verts=5))
    return out


side = []
# ---- chitin over shoulders, arms and legs, spikes at the joints -----------------------------------------------------
side += plate((0.3, 0.1, AY + 0.1), (0.22, 0.26, 0.1), rot=(0, -0.35, 0), spikes=3, sp_dir=(0.3, -0.4, 1), sp_len=0.12)
side += plate((0.36, 0.1, AY + 0.04), (0.16, 0.24, 0.08), rot=(0, -0.7, 0), m=chit2)
side += plate((0.52, 0.12, AY + 0.06), (0.2, 0.16, 0.05), rot=(0, 0, 0), spikes=2, sp_dir=(0.2, -0.5, 1), sp_len=0.07)
side.append(spike(chit2, (0.68, 0.06, AY), (0.66, -0.12, AY + 0.02), 0.03))                               # elbow spur
side += plate((0.9, 0.12, AY + 0.055), (0.26, 0.14, 0.05), spikes=3, sp_dir=(0.3, -0.6, 1), sp_len=0.06)
side += plate((0.9, 0.12, AY - 0.055), (0.24, 0.12, 0.04), m=chit2)
side += plate((0.2, 0.12, 0.76), (0.14, 0.12, 0.26), rot=(0.3, 0, 0), m=chit)
side.append(spike(chit2, (0.21, 0.2, 0.52), (0.22, 0.3, 0.58), 0.03))                                   # knee spike
side += plate((0.21, -0.02, 0.36), (0.1, 0.08, 0.2), rot=(-0.55, 0, 0), m=chit2)
for k in range(3):
    side.append(spike(chit2, (0.21, -0.07 + k * 0.03, 0.42 - k * 0.07), (0.21, -0.15 + k * 0.03, 0.42 - k * 0.07), 0.016))
# hand: three great hooked claws (curved, built in three pieces) and a thumb claw
for k, dy in enumerate((0.05, 0.0, -0.05)):
    a = Vector((1.13, 0.12 + dy, AY))
    pts = [a, a + Vector((0.09, dy * 0.4, -0.01)), a + Vector((0.17, dy * 0.6, -0.06)), a + Vector((0.2, dy * 0.6, -0.14))]
    side.append(limb(flesh, pts[0], pts[1], 0.022, 0.02, verts=7))
    side.append(limb(claw, pts[1], pts[2], 0.02, 0.013, verts=7))
    side.append(limb(claw, pts[2], pts[3], 0.013, 0.0, verts=7))
side.append(limb(claw, (1.1, 0.18, AY - 0.01), (1.15, 0.26, AY - 0.06), 0.016, 0.0, verts=6))
# foot: three toes with hooked claws, a dew claw
for dx in (-0.05, 0.0, 0.05):
    a = Vector((0.21 + dx * 0.6, 0.12, 0.05))
    b = Vector((0.21 + dx * 1.3, 0.25 - abs(dx), 0.04))
    side.append(limb(flesh, a, b, 0.03, 0.022, verts=7))
    side.append(limb(claw, b, b + Vector((dx * 0.2, 0.06, 0.0)), 0.022, 0.015, verts=6))
    side.append(limb(claw, b + Vector((dx * 0.2, 0.06, 0.0)), b + Vector((dx * 0.3, 0.1, -0.04)), 0.015, 0.0, verts=6))
side.append(spike(claw, (0.21, -0.06, 0.12), (0.21, -0.14, 0.03), 0.018))
P += side + mirror_x(side)
# ---- belly plates with red light between ---------------------------------------------------------------------------
for k in range(5):
    z = 1.05 + k * 0.09
    y = 0.2 + k * 0.025
    P += plate((0, y, z), (0.22 - abs(k - 2) * 0.02, 0.05, 0.065), rot=(0.25, 0, 0), m=chit2)
    if k < 4:
        P.append(bbox(glow, (0, y + 0.0, z + 0.045), (0.16, 0.03, 0.012), rot=(0.25, 0, 0)))
# ---- back: plates with spikes, the egg cluster, arching spined tentacles ------------------------------------------------
for k in range(5):
    z = 1.0 + k * 0.13
    y = -0.18 + k * 0.02
    P += plate((0, y, z), (0.3 - k * 0.01, 0.06, 0.11), rot=(-0.3, 0, 0), spikes=2, sp_dir=(0, -1, 0.4), sp_len=0.1)
EGGS = [(0.0, -0.3, 1.5, 0.11), (0.12, -0.27, 1.42, 0.09), (-0.12, -0.27, 1.42, 0.09), (0.07, -0.33, 1.32, 0.08),
        (-0.07, -0.33, 1.32, 0.08), (0.14, -0.22, 1.58, 0.07), (-0.14, -0.22, 1.58, 0.07), (0.0, -0.36, 1.2, 0.07)]
for ex, ey, ez, er in EGGS:
    P.append(smooth(sphere(egg, (ex, ey, ez), er, seg=16, rings=10, scale=(1.0, 0.9, 1.1))))
    P.append(smooth(sphere(chit, (ex, ey + er * 0.5, ez), er * 0.6, seg=8, rings=6)))                          # stalk into the back
TENT = [(-0.12, 0.75), (-0.05, 0.85), (0.05, 0.85), (0.12, 0.75), (-0.17, 0.6), (0.17, 0.6)]
for i, (tx, ln) in enumerate(TENT):
    root = Vector((tx, -0.18, 1.5 - (i // 4) * 0.12))
    pts = []
    for j in range(9):
        t = j / 8
        ang = -0.3 + t * 2.4                                                                 # rises then hooks forward
        pts.append(root + Vector((tx * 1.6 * t, -math.cos(ang) * ln * 0.45 + 0.06, math.sin(ang) * ln * 0.5 + t * 0.1)))
    TN = [(p, max(0.008, 0.045 * (1 - j / 9))) for j, p in enumerate(pts)]
    P.append(skin(chit, TN, [(j, j + 1) for j in range(len(TN) - 1)], "LihTent%d" % i, subsurf=1))
    for j in range(1, 8):                                                                     # spines along the outer curve
        d = (pts[j + 1] - pts[j - 1]).normalized()
        nrm = d.cross(Vector((1, 0, 0))).normalized()
        if nrm.z < 0:
            nrm = -nrm
        P.append(spike(chit2, pts[j], pts[j] + nrm * 0.05 * (1 - j / 10), 0.01, verts=4))
    P.append(spike(claw, pts[-1], pts[-1] + (pts[-1] - pts[-2]).normalized() * 0.1, 0.012, verts=5))
    P.append(limb(slime, pts[5], pts[5] + Vector((0, 0, -0.1)), 0.004, 0.002, verts=4))
# ---- tail spines ---------------------------------------------------------------------------------------------------------
for k, (p, r) in enumerate(N[6:11]):
    p = Vector(p)
    P.append(spike(chit2, p + Vector((0, 0, r * 0.8)), p + Vector((0, -0.08, r * 0.8 + 0.08 * (1 - k / 5))), 0.02 * (1 - k / 7)))
    for x in (1, -1):
        P.append(spike(chit2, p + Vector((r * 0.7 * x, 0, r * 0.3)), p + Vector((r * 0.7 * x + 0.05 * x, -0.06, r * 0.3 + 0.03)), 0.012))
# ---- the head: a long, flat wedge with a spiky crest, huge open jaws, red eyes -----------------------------------------
HG = Vector((0, 0.36, 1.73)); JA = -0.6
JD = Vector((0, math.cos(JA), math.sin(JA))); JN = Vector((0, -math.sin(JA), math.cos(JA)))
P.append(smooth(sphere(chit, (0, 0.44, 1.8), 0.1, seg=16, rings=10, scale=(1.0, 1.4, 0.75))))                  # skull
P.append(smooth(sphere(chit2, (0, 0.6, 1.79), 0.08, seg=16, rings=10, scale=(0.9, 1.9, 0.5), rot=(0.1, 0, 0))))  # snout
P.append(smooth(sphere(dark, (0, 0.55, 1.74), 0.07, seg=12, rings=8, scale=(0.85, 2.0, 0.35))))                   # palate
P.append(smooth(sphere(chit2, HG + JD * 0.2, 0.075, seg=14, rings=8, scale=(0.85, 2.3, 0.4), rot=(JA, 0, 0))))     # lower jaw
P.append(smooth(sphere(flesh, HG + JD * 0.19 + JN * 0.02, 0.06, seg=10, rings=6, scale=(0.75, 2.2, 0.25), rot=(JA, 0, 0))))
for x in (1, -1):
    P.append(smooth(sphere(eye, (0.065 * x, 0.52, 1.84), 0.018, seg=8, rings=6, scale=(0.8, 1.4, 0.7))))
    P.append(spike(chit2, (0.06 * x, 0.5, 1.86), (0.12 * x, 0.36, 1.92), 0.02))                                     # brow horn
    for k in range(8):                                                                                           # upper fangs
        y = 0.44 + k * 0.042
        w = 0.068 * (1 - k * 0.07)
        ln = 0.075 if k in (1, 5) else 0.04
        P.append(spike(tooth, (w * x, y, 1.755), (w * x * 0.95, y + 0.01, 1.755 - ln), 0.009 if ln < 0.05 else 0.012))
    for k in range(7):                                                                                           # lower fangs
        sj = 0.1 + k * 0.042
        w = 0.058 * (1 - k * 0.08)
        bse = HG + JD * sj + JN * 0.026 + Vector((w * x, 0, 0))
        ln = 0.07 if k in (1, 4) else 0.035
        P.append(spike(tooth, bse, bse + JN * ln, 0.009 if ln < 0.05 else 0.012))
    for k in range(2):                                                                                           # drool
        y = 0.5 + k * 0.1
        P.append(limb(slime, (0.04 * x, y, 1.74), (0.04 * x, y + 0.01, 1.62 - k * 0.04), 0.004, 0.002, verts=4))
# crest: swept-back blades
for k in range(7):
    base = Vector((0, 0.5 - k * 0.04, 1.86 - k * 0.012))
    ang = 0.35 + k * 0.08
    P.append(spike(chit2, base, base + Vector((0, -math.cos(ang), math.sin(ang))) * (0.2 + 0.04 * math.sin(k)), 0.03, verts=4))
    if k % 2:
        for x in (1, -1):
            P.append(spike(chit2, base + Vector((0.05 * x, 0, -0.02)), base + Vector((0.14 * x, -0.16, 0.06)), 0.02, verts=4))

o = finish_mesh(P, NAME)
print("STATS", stats(o))
ARGS = sys.argv[1:]
OUT = ARGS[0] if ARGS and not ARGS[0].startswith("--") else NAME
if "--preview" in sys.argv:
    d = sys.argv[sys.argv.index("--preview") + 1]
    render(os.path.join(d, NAME + "_front.png"), (0, 0, 1.05), 4.6, 0.0, 0.2)
    render(os.path.join(d, NAME + "_34.png"), (0, -0.2, 1.05), 4.6, 1.0, 0.5)
    render(os.path.join(d, NAME + "_head.png"), (0, 0.5, 1.75), 1.4, 0.8, 0.15)
    render(os.path.join(d, NAME + "_back.png"), (0, -0.2, 1.2), 4.0, 2.6, 0.8)
else:
    export_all(o, OUT)
    print("written", OUT)
