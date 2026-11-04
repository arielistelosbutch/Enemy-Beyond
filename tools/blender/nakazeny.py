"""Nakažený (0.50) after Ari's database text (own design): a gaunt, hunched man carrying a Líhavec's brood.
Grey-pale skin, a face twisted with pain, glassy eyes; a torn work shirt open over a swollen belly in
which the eggs bulge and glow faintly red through the skin; one arm always pressed over it. Torn jeans,
one bare foot. A "belly" bone makes the brood stir in every action.
Same rig as the old zombie (aliens.civilian) plus the belly bone.
Run: python3 tools/blender/nakazeny.py out.glb [--preview <action|-> <frame> out.png angle]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
import aliens as A
from common import *
from common import _finish

A.OUT = [a for a in sys.argv if a.endswith(".glb")][0] if any(a.endswith(".glb") for a in sys.argv) else "zombie.glb"

def mat2(name, rgb, rough=0.6, emit=0.0):
    return mat(name, rgb, emit=emit, rough=rough)

skin = mat2("NakSkin", (0.25, 0.26, 0.23), rough=0.55)
skin2 = mat2("NakSkin2", (0.18, 0.17, 0.16), rough=0.6)
bruise = mat2("NakBruise", (0.25, 0.12, 0.16), rough=0.5)
belly_m = mat2("NakBelly", (0.24, 0.18, 0.2), rough=0.25)
vein = mat("NakVein", (0.5, 0.06, 0.1), emit=0.8)
egg = mat("NakEgg", (0.85, 0.12, 0.16), emit=1.2)
mouth = mat2("NakMouth", (0.1, 0.03, 0.04), rough=0.5)
eye = mat("NakEye", (0.75, 0.78, 0.72), emit=0.4)
socket = mat2("NakSocket", (0.12, 0.09, 0.1), rough=0.6)
hair = mat2("NakHair", (0.1, 0.09, 0.08), rough=0.9)
shirt = mat2("NakShirt", (0.28, 0.22, 0.11), rough=0.9)       # a dirty mustard work shirt
shirt2 = mat2("NakShirt2", (0.2, 0.15, 0.07), rough=0.9)
jeans = mat2("NakJeans", (0.14, 0.17, 0.24), rough=0.9)
shoe = mat2("CivShoe", (0.08, 0.06, 0.05), rough=0.8)
blood = mat2("NakBlood", (0.25, 0.02, 0.03), rough=0.3)

def smooth(o):
    for p in o.data.polygons:
        p.use_smooth = True
    return o

def L(material, a, b, r1, r2, verts=8, group=None):
    return smooth(A.limb(material, a, b, r1, r2, verts=verts, group=group))

def S(material, loc, r, scale=(1, 1, 1), group=None, seg=12, rings=8):
    return smooth(sphere(material, loc, r, seg=seg, rings=rings, scale=scale, group=group))

B = A.humanoid_bones(hip=0.93, chest=1.4, neck=1.52, head=1.78, sx=0.2, hx=0.1, knee=0.5, ankle=0.08, elbow=1.12, wrist=0.86)
B["belly"] = ((0, -0.02, 1.1), (0, 0.1, 1.1), "spine")
rig = A.make_rig("Civ", B)
p = []
# ---- head: gaunt, twisted with pain, glassy eyes, thin hair ----------------------------------------------------------------
H = "head"
p.append(S(skin, (0, 0.0, 1.64), 0.11, (0.88, 1.0, 1.15), H, 16, 10))
p.append(S(skin2, (0, 0.05, 1.56), 0.07, (1.0, 0.9, 0.7), H))                          # the jaw
p.append(S(mouth, (0.01, 0.1, 1.565), 0.03, (1.0, 0.5, 1.3), H))                       # mouth open, twisted
for x in (1, -1):
    p.append(S(socket, (0.042 * x, 0.085, 1.665), 0.026, (1.1, 0.6, 0.9), H))         # sunken sockets
    p.append(S(eye, (0.042 * x, 0.098, 1.665), 0.012, group=H))
    p.append(S(skin2, (0.07 * x, 0.06, 1.6), 0.03, (0.8, 0.8, 1.2), H))               # hollow cheeks
p.append(L(skin, (0, 0.1, 1.64), (0, 0.125, 1.6), 0.016, 0.012, 6, H))                 # nose
for k in range(5):
    p.append(box(hair, (-0.06 + k * 0.03, -0.04 + (k % 2) * 0.03, 1.75), (0.02, 0.1, 0.01), rot=(0.3, 0, 0.2 * k), group=H))
p.append(box(blood, (0.0, 0.11, 1.53), (0.02, 0.01, 0.05), group=H))
# ---- neck and chest: ribs under the skin, the torn shirt -------------------------------------------------------------
p.append(L(skin, (0, 0, 1.44), (0, 0.02, 1.56), 0.045, 0.04, 8, "neck"))
T = "spine"
p.append(S(skin, (0, 0, 1.3), 0.15, (1.15, 0.75, 1.1), T))                               # the bony chest
for k in range(4):
    for x in (1, -1):
        p.append(L(skin2, (0.03 * x, 0.1, 1.36 - k * 0.05), (0.12 * x, 0.06, 1.33 - k * 0.06), 0.008, 0.007, 5, T))
# the shirt: back and shoulders whole, torn open in front
p.append(S(shirt, (0, -0.03, 1.3), 0.16, (1.2, 0.72, 1.12), T))
for x in (1, -1):
    sh = box(shirt2, (0.1 * x, 0.08, 1.32), (0.08, 0.04, 0.3), rot=(0, 0, -0.15 * x), group=T)
    for v in sh.data.vertices:                                                          # ragged hem
        if v.co.z < 1.2:
            v.co.z += 0.04 * ((v.index % 3) - 1)
    p.append(sh)
    p.append(box(shirt, (0.06 * x, 0.1, 1.42), (0.06, 0.03, 0.06), rot=(0.4, 0, 0.3 * x), group=T))   # collar
# ---- the belly: swollen, veined, the eggs bulging through -----------------------------------------------------------
G = "belly"
p.append(S(belly_m, (0, 0.08, 1.07), 0.2, (1.0, 1.05, 0.95), G, 18, 12))
for (ex, ey, ez, er) in ((0.08, 0.22, 1.12, 0.07), (-0.07, 0.24, 1.04, 0.075), (0.02, 0.2, 0.96, 0.06), (-0.1, 0.17, 1.15, 0.05), (0.12, 0.17, 1.0, 0.055)):
    p.append(S(belly_m, (ex, ey, ez), er, (1, 0.8, 1), G))
    p.append(S(egg, (ex, ey + er * 0.45, ez), er * 0.55, (1, 0.5, 1), G, 10, 6))         # the glow through the skin
def on_belly(a, b, lift=1.0):
    """A point on the belly's skin: a = around (0 = front), b = up/down."""
    return (math.sin(a) * math.cos(b) * 0.2 * lift, 0.08 + math.cos(a) * math.cos(b) * 0.21 * lift, 1.07 + math.sin(b) * 0.19 * lift)
for k in range(10):                                                                     # veins lying on the skin
    a0 = -1.3 + (k % 5) * 0.6
    b0 = -0.6 + (k // 5) * 0.7
    pts = [on_belly(a0 + t * 0.25, b0 + t * 0.22 * (1 if k % 2 else -1), 1.005) for t in range(4)]
    for i in range(3):
        p.append(L(vein, pts[i], pts[i + 1], 0.005, 0.004, 4, G))
p.append(S(bruise, (0.03, 0.27, 1.08), 0.03, (1.2, 0.4, 1), G))                         # the navel, stretched
# ---- hips and legs: torn jeans, one shoe, one bare foot -----------------------------------------------------------------
p.append(S(jeans, (0, -0.01, 0.92), 0.15, (1.15, 0.85, 0.6), "hips"))
for sd, x in (("L", 1), ("R", -1)):
    p.append(L(jeans, (0.1 * x, 0, 0.92), (0.1 * x, 0, 0.5), 0.075, 0.06, 8, "thigh." + sd))
    p.append(L(jeans if x > 0 else skin2, (0.1 * x, 0, 0.5), (0.1 * x, 0, 0.1), 0.055, 0.04, 8, "shin." + sd))
    if x > 0:
        p.append(box(shoe, (0.1 * x, 0.04, 0.04), (0.1, 0.24, 0.08), group="shin." + sd))
    else:
        p.append(S(skin2, (0.1 * x, 0.05, 0.035), 0.05, (0.9, 2.0, 0.6), "shin." + sd))
        p.append(box(jeans, (0.1 * x, 0, 0.3), (0.13, 0.13, 0.04), rot=(0.2, 0.3, 0), group="shin." + sd))   # rolled, torn leg
# ---- arms: thin, grey; the left one hugs the belly ---------------------------------------------------------------------
for sd, x in (("L", 1), ("R", -1)):
    p.append(L(shirt, (0.2 * x, 0, 1.36), (0.21 * x, 0, 1.15), 0.055, 0.045, 8, "upperarm." + sd))
    p.append(L(skin, (0.21 * x, 0, 1.15), (0.215 * x, 0, 1.12), 0.04, 0.04, 8, "upperarm." + sd))
    p.append(L(skin, (0.215 * x, 0, 1.12), (0.22 * x, 0, 0.88), 0.035, 0.028, 8, "forearm." + sd))
    p.append(S(skin2, (0.222 * x, 0.0, 0.84), 0.035, (0.7, 1.0, 1.3), "hand." + sd))
    for f in range(4):
        p.append(L(skin2, (0.222 * x + (f - 1.5) * 0.012, 0.015, 0.81), (0.222 * x + (f - 1.5) * 0.014, 0.03, 0.75), 0.008, 0.005, 5, "hand." + sd))
p.append(box(blood, (-0.22, 0.02, 0.83), (0.04, 0.03, 0.06), group="hand.R"))

body = A.bind(rig, p, "Zombie")
# ---- actions: hunched, one arm over the belly, the brood stirring --------------------------------------------------
hug = {"upperarm.L": (0.15, 0, 0.2), "forearm.L": (1.3, 0, 0.9), "hand.L": (0.3, 0, 0)}
sh = dict(hug, **{"spine": (-0.35, 0, 0.12), "head": (0.45, 0.25, 0.35), "upperarm.R": (0.3, 0, -0.1), "forearm.R": (0.15, 0, 0)})
def stir(f, k=1.0):
    return {"belly": (math.sin(f * 0.7) * 0.06 * k, math.cos(f * 0.9) * 0.05 * k, math.sin(f * 1.3) * 0.08 * k)}
A.action(rig, "idle", [(1, dict(sh, **stir(1)), -0.04), (13, dict(sh, **stir(13, 1.6)), -0.05),
                       (25, dict(sh, head=(0.6, -0.1, 0.6), spine=(-0.42, 0, 0.2), **stir(25)), -0.05),
                       (37, dict(sh, **stir(37, 1.8)), -0.04), (49, dict(sh, **stir(1)), -0.04)])
def lurch(n, amp, bob):
    out = []
    for f, r, hz in A.walk_frames(n, amp, 0.05, bob, base=sh, spine=-0.38, knee=0.6):
        r = dict(r)
        r.update(hug)
        r.update(stir(f, 1.3))
        out.append((f, r, hz))
    return out
A.action(rig, "walk", lurch(36, 0.3, 0.05))
A.action(rig, "run", lurch(24, 0.42, 0.07))
A.action(rig, "lurk", [(1, dict(sh, **stir(1)), -0.04), (25, dict(sh, **stir(25, 2.0)), -0.05), (49, dict(sh, **stir(1)), -0.04)])
grab = dict(sh, **{"upperarm.R": (1.5, 0, 0.2), "forearm.R": (0.1, 0, 0), "spine": (-0.2, 0, 0), "head": (0.2, 0, 0)})
A.action(rig, "attack", [(1, sh, -0.04), (7, grab, -0.02), (11, dict(grab, spine=(-0.6, 0, 0), **stir(11, 2.5)), -0.08), (19, sh, -0.04)])
A.action(rig, "aim", [(1, grab, -0.02), (25, dict(grab, **stir(25, 2.0)), -0.02)])
for b in rig.pose.bones:
    b.rotation_euler = (0, 0, 0)
    b.location = (0, 0, 0)
A.finish([rig, body], rig, target=(0, 0, 1.0), dist=3.0)
print("written", A.OUT)
