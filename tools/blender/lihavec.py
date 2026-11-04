"""Líhavec (0.50, formerly Líhnoun) after Ari's picture: a hunched predator of glossy wine-dark chitin -
spiked plates over slimy flesh, a spiky swept-back crest, huge jaws of long fangs with drool, red eyes,
red light glowing between the belly plates. On the back a cluster of glowing red egg sacs and curved,
spined tentacles arching over it. Long arms with great hooked claws, spiked legs, a spined tail.
Same rig and actions as the old Líhnoun (aliens.lihnoun_anims).
Run: python3 tools/blender/lihavec.py out.glb [--preview <action|-> <frame> out.png angle]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
import aliens as A
from common import *
from common import _finish

A.OUT = [a for a in sys.argv if a.endswith(".glb")][0] if any(a.endswith(".glb") for a in sys.argv) else "lihnoun.glb"

def mat2(name, rgb, rough=0.6, metal=0.0, emit=0.0):
    m = mat(name, rgb, emit=emit, rough=rough)
    m.node_tree.nodes.get("Principled BSDF").inputs["Metallic"].default_value = metal
    return m

chit = mat2("LihChitin", (0.16, 0.035, 0.06), rough=0.18, metal=0.2)
chit2 = mat2("LihPlate", (0.07, 0.018, 0.03), rough=0.15, metal=0.25)
flesh = mat2("LihFlesh", (0.32, 0.04, 0.09), rough=0.12)
mouth = mat2("LihMouth", (0.12, 0.01, 0.02), rough=0.2)
tooth = mat2("LihTooth", (0.78, 0.72, 0.62), rough=0.3)
eye = mat("LihEye", (1.0, 0.08, 0.06), emit=7.0)
glow = mat("LihGlow", (1.0, 0.1, 0.12), emit=3.0)
egg = mat2("LihEgg", (0.55, 0.04, 0.09), rough=0.1, emit=0.0)
egg_in = mat("LihEggGlow", (1.0, 0.1, 0.15), emit=2.5)

def smooth(o):
    for p in o.data.polygons:
        p.use_smooth = True
    return o

def L(material, a, b, r1, r2, verts=8, group=None, sm=True):
    o = A.limb(material, a, b, r1, r2, verts=verts, group=group)
    return smooth(o) if sm else o

def S(material, loc, r, scale=(1, 1, 1), group=None, seg=14, rings=10):
    return smooth(sphere(material, loc, r, seg=seg, rings=rings, scale=scale, group=group))

def spike(a, b, r, group):
    return L(chit2, a, b, r, 0.0, 5, group, sm=False)

def curve(material, pts, r1, r2, group, verts=8, spines=0.0):
    out = []
    n = len(pts) - 1
    for i in range(n):
        ra = r1 + (r2 - r1) * i / n
        rb = r1 + (r2 - r1) * (i + 1) / n
        out.append(L(material, pts[i], pts[i + 1], ra, rb, verts, group))
        if i < n - 1:
            out.append(S(material, pts[i + 1], rb, group=group, seg=verts, rings=5))
        if spines > 0 and i > 0:                                         # spines along the outer side
            a = Vector(pts[i]); b = Vector(pts[i + 1])
            m = (a + b) / 2
            d = (b - a).normalized()
            side = d.cross(Vector((1, 0, 0))).normalized()
            if side.z < 0:
                side = -side
            out.append(spike(tuple(m), tuple(m + side * spines * (1 - i / n) + d * 0.03), ra * 0.6, group))
    return out

B = A.humanoid_bones(hip=0.95, chest=1.5, neck=1.62, head=1.9, sx=0.24, hx=0.15, knee=0.52, ankle=0.06, elbow=1.12, wrist=0.84, lean=0.12)
rig = A.make_rig("Lih", B)
p = []
# ---- pelvis and the spined tail ----------------------------------------------------------------------------------------------
p.append(S(chit, (0, -0.02, 0.95), 0.17, (1.25, 1.0, 0.8), "hips"))
p += curve(chit, [(0, -0.15, 0.95), (0, -0.5, 0.84), (0, -0.85, 0.62), (0, -1.15, 0.42), (0, -1.38, 0.32)], 0.1, 0.01, "hips", 8, 0.12)
# ---- chest and belly: plates over slime, red light between them ---------------------------------------------------------------
T = "spine"
p.append(L(flesh, (0, 0.0, 1.0), (0, 0.06, 1.2), 0.13, 0.17, 10, T))
p.append(S(chit, (0, 0.06, 1.34), 0.24, (1.1, 0.95, 1.15), T))
for i in range(4):                                                         # belly plates and the glow between
    z = 1.04 + i * 0.09
    p.append(S(chit2, (0, 0.2 - i * 0.01, z), 0.1, (1.25 - i * 0.05, 0.5, 0.42), T, 12, 6))
    if i < 3:
        p.append(box(glow, (0, 0.24, z + 0.045), (0.12, 0.012, 0.012), group=T))
for x in (1, -1):
    for k in range(3):                                                     # ribs of flesh with glow slits
        z = 1.22 + k * 0.1
        p.append(L(flesh, (0.2 * x, 0.12, z), (0.12 * x, 0.25, z - 0.05), 0.022, 0.016, 6, T))
        p.append(box(glow, (0.2 * x, 0.15, z - 0.04), (0.012, 0.05, 0.02), rot=(0, 0, 0.6 * x), group=T))
for i in range(5):                                                         # back plates with spikes
    z = 1.12 + i * 0.1
    p.append(S(chit2, (0, -0.1, z), 0.14, (1.5 - i * 0.08, 0.7, 0.35), T, 12, 6))
    p.append(spike((0, -0.15, z + 0.03), (0, -0.33, z + 0.17), 0.04, T))
# ---- the egg sacs and the tentacles on the back -----------------------------------------------------------------------------
for (ex, ey, ez, er) in ((0.12, -0.24, 1.42, 0.09), (-0.13, -0.25, 1.38, 0.085), (0.0, -0.3, 1.25, 0.1), (0.2, -0.2, 1.24, 0.07),
                         (-0.2, -0.22, 1.2, 0.075), (0.05, -0.2, 1.56, 0.07)):
    p.append(S(egg, (ex, ey, ez), er, (1, 1, 1.1), T, 14, 10))
    p.append(S(egg_in, (ex * 1.02, ey - er * 0.55, ez + er * 0.1), er * 0.55, (1, 0.6, 1), T, 10, 6))   # the glow inside, seen through the skin
    p.append(S(chit2, (ex * 1.05, ey - 0.02, ez - er * 0.7), er * 0.7, (1, 1, 0.4), T, 10, 6))   # the cup it sits in
for k, (ang, reach, up) in enumerate(((0.5, 0.65, 0.65), (-0.5, 0.65, 0.65), (1.1, 0.6, 0.4), (-1.1, 0.6, 0.4), (0.15, 0.5, 0.8), (-0.15, 0.5, 0.8))):
    x0 = math.sin(ang) * 0.12
    base = (x0, -0.18, 1.35 + (k % 2) * 0.05)
    pts = [base]
    for i in range(1, 7):
        t = i / 6
        # up and back, then curling forward over the body like a claw
        ox = x0 + math.sin(ang) * reach * math.sin(t * 2.0) * 0.8
        oy = -0.18 - reach * 0.6 * math.sin(t * 2.6) + reach * 0.9 * t * t
        oz = base[2] + up * math.sin(t * 2.4)
        pts.append((ox, oy, oz))
    p += curve(chit, pts, 0.06, 0.008, T, 8, 0.07)
# ---- neck and the head: a spiky crest, enormous open jaws -------------------------------------------------------------------
p.append(L(chit, (0, 0.1, 1.46), (0, 0.24, 1.68), 0.12, 0.09, 10, "neck"))
for k in range(3):
    p.append(spike((0, 0.08 + k * 0.05, 1.5 + k * 0.06), (0, -0.08 + k * 0.05, 1.62 + k * 0.08), 0.035, "neck"))
H = "head"
p.append(S(chit, (0, 0.38, 1.8), 0.14, (0.8, 1.6, 0.6), H))             # the long skull
p.append(S(mouth, (0, 0.44, 1.7), 0.11, (0.7, 1.6, 0.5), H))             # the throat
p.append(S(chit2, (0, 0.44, 1.58), 0.1, (0.75, 1.65, 0.3), H))           # the dropped lower jaw
for x in (1, -1):
    p.append(S(eye, (0.085 * x, 0.42, 1.84), 0.022, (1, 1.4, 0.7), H, 8, 6))
    for k in range(6):                                                    # the crest: blades swept back
        a = k / 5
        p.append(spike((0.05 * x, 0.42 - a * 0.25, 1.86 + a * 0.02), (0.2 * x * (1 + a * 0.5), 0.1 - a * 0.35, 1.98 + a * 0.12), 0.035, H))
    for i in range(8):                                                    # fangs, long, top and bottom
        y = 0.3 + i * 0.045
        ln = 0.09 if i in (1, 5) else 0.06
        p.append(L(tooth, (0.06 * x * (1 - i * 0.05), y, 1.72), (0.055 * x * (1 - i * 0.05), y + 0.02, 1.72 - ln), 0.012, 0.0, 5, H))
        p.append(L(tooth, (0.055 * x * (1 - i * 0.05), y, 1.6), (0.05 * x * (1 - i * 0.05), y + 0.02, 1.6 + ln * 0.8), 0.011, 0.0, 5, H))
    p.append(L(flesh, (0.04 * x, 0.5, 1.7), (0.04 * x, 0.52, 1.6), 0.005, 0.003, 4, H))      # drool
p.append(spike((0, 0.42, 1.88), (0, 0.15, 2.05), 0.04, H))
# ---- arms: spiked shoulders, long forearms, great hooked claws ------------------------------------------------------------------
for sd, x in (("L", 1), ("R", -1)):
    p.append(S(chit2, (0.26 * x, 0.1, 1.48), 0.12, (1.2, 1.2, 0.9), "upperarm." + sd))
    p.append(spike((0.3 * x, 0.08, 1.54), (0.45 * x, -0.05, 1.7), 0.05, "upperarm." + sd))
    p.append(spike((0.32 * x, 0.14, 1.5), (0.44 * x, 0.2, 1.62), 0.04, "upperarm." + sd))
    p.append(L(chit, (0.25 * x, 0.12, 1.46), (0.26 * x, 0.12, 1.12), 0.08, 0.06, 8, "upperarm." + sd))
    p.append(S(chit2, (0.26 * x, 0.12, 1.12), 0.065, group="forearm." + sd))
    p.append(L(chit, (0.26 * x, 0.12, 1.12), (0.27 * x, 0.12, 0.84), 0.065, 0.045, 8, "forearm." + sd))
    p.append(spike((0.28 * x, 0.05, 1.08), (0.32 * x, -0.15, 1.2), 0.035, "forearm." + sd))
    p.append(S(chit, (0.27 * x, 0.12, 0.84), 0.055, group="hand." + sd))
    for c in (-1, 0, 1):
        cx = 0.27 * x + c * 0.035
        p.append(L(chit2, (cx, 0.13, 0.82), (cx, 0.18, 0.62), 0.025, 0.018, 6, "hand." + sd))
        p += [L(tooth, (cx, 0.18, 0.62), (cx, 0.27, 0.5), 0.02, 0.012, 5, "hand." + sd),
              L(tooth, (cx, 0.27, 0.5), (cx, 0.4, 0.47), 0.012, 0.0, 5, "hand." + sd)]
# ---- legs: spiked thighs, the backward hock, splayed claws --------------------------------------------------------------------------
for sd, x in (("L", 1), ("R", -1)):
    p.append(S(chit, (0.15 * x, 0.0, 0.93), 0.11, group="thigh." + sd))
    p.append(L(chit, (0.15 * x, 0.0, 0.93), (0.16 * x, 0.1, 0.52), 0.11, 0.07, 10, "thigh." + sd))
    p.append(spike((0.2 * x, 0.0, 0.8), (0.32 * x, -0.12, 0.88), 0.04, "thigh." + sd))
    p.append(S(chit2, (0.16 * x, 0.12, 0.52), 0.075, group="shin." + sd))
    p.append(L(chit, (0.16 * x, 0.1, 0.52), (0.16 * x, -0.12, 0.22), 0.065, 0.045, 8, "shin." + sd))
    p.append(spike((0.16 * x, 0.15, 0.5), (0.16 * x, 0.25, 0.62), 0.035, "shin." + sd))
    p.append(S(chit, (0.16 * x, -0.12, 0.22), 0.045, group="shin." + sd))
    p.append(L(chit, (0.16 * x, -0.12, 0.22), (0.16 * x, 0.02, 0.05), 0.045, 0.04, 8, "shin." + sd))
    p.append(spike((0.16 * x, -0.12, 0.22), (0.16 * x, -0.26, 0.32), 0.03, "shin." + sd))
    for c in (-1, 0, 1):
        p.append(L(tooth, (0.16 * x, 0.02, 0.05), (0.16 * x + c * 0.09, 0.25, 0.01), 0.03, 0.0, 5, "shin." + sd))
    p.append(L(tooth, (0.16 * x, 0.0, 0.05), (0.16 * x, -0.14, 0.01), 0.022, 0.0, 5, "shin." + sd))

body = A.bind(rig, p, "Lihnoun")
A.lihnoun_anims(rig)
for b in rig.pose.bones:
    b.rotation_euler = (0, 0, 0)
    b.location = (0, 0, 0)
A.finish([rig, body], rig, target=(0, 0.0, 1.0), dist=3.6)
print("written", A.OUT)
