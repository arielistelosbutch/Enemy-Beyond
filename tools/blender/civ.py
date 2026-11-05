"""Civilians (0.52 rework, own designs): civ_a - a farmer in a quilted work jacket, flat cap, jeans and
rubber boots; civ_b - a woman in a long belted coat with a headscarf over her hair.
Same rig, bone names and actions as before (aliens.humanoid_bones / aliens.civilian: idle, walk, run,
lurk = cowering, aim = waving, attack), but proper bodies: a face with eyes, nose and ears, hands with
fingers, collars, pockets, seams, buttons.
The mesh is called "Obcan" (the old "Civilian" block-modeller edits in modely/ do not fit it).
Run: python3 tools/blender/civ.py civ_a out.glb [--preview <action|-> <frame> out.png angle]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
import aliens as A
from common import *

KIND = "civ_b" if "civ_b" in sys.argv[1:2] else "civ_a"
A.OUT = [a for a in sys.argv if a.endswith(".glb")][0] if any(a.endswith(".glb") for a in sys.argv) else KIND + ".glb"
A.reset()

def smooth(o):
    for p in o.data.polygons:
        p.use_smooth = True
    return o

def L(material, a, b, r1, r2, verts=10, group=None):
    return smooth(A.limb(material, a, b, r1, r2, verts=verts, group=group))

def S(material, loc, r, scale=(1, 1, 1), group=None, seg=14, rings=9):
    return smooth(sphere(material, loc, r, seg=seg, rings=rings, scale=scale, group=group))

skin = mat("CivSkin", (0.62, 0.46, 0.37), rough=0.6)
skin2 = mat("CivSkinShade", (0.5, 0.35, 0.28), rough=0.6)
eye = mat("CivEye", (0.85, 0.85, 0.8), rough=0.3)
iris = mat("CivIris", (0.08, 0.06, 0.05), rough=0.2)
lips = mat("CivLips", (0.48, 0.26, 0.24), rough=0.5)
shoe = mat("CivShoe", (0.08, 0.06, 0.05), rough=0.8)
if KIND == "civ_a":
    top = mat("CivJacket", (0.2, 0.27, 0.36), rough=0.9)          # a faded blue work jacket
    top2 = mat("CivJacketSeam", (0.13, 0.18, 0.25), rough=0.9)
    shirt = mat("CivShirt", (0.42, 0.18, 0.12), rough=0.9)        # red check flannel under it
    legs = mat("CivJeans", (0.14, 0.17, 0.22), rough=0.9)
    hair = mat("CivHair", (0.3, 0.22, 0.14), rough=0.9)
    hat = mat("CivCap", (0.22, 0.2, 0.15), rough=0.9)
    boot = mat("CivBoot", (0.12, 0.16, 0.1), rough=0.6)            # green rubber boots
else:
    top = mat("CivCoat", (0.36, 0.2, 0.13), rough=0.9)            # a long rust-brown coat
    top2 = mat("CivCoatSeam", (0.25, 0.13, 0.08), rough=0.9)
    shirt = mat("CivJumper", (0.45, 0.42, 0.36), rough=0.95)
    legs = mat("CivTights", (0.1, 0.1, 0.12), rough=0.8)
    hair = mat("CivHair", (0.2, 0.12, 0.07), rough=0.9)
    hat = mat("CivScarf", (0.5, 0.38, 0.2), rough=0.95)           # an ochre headscarf
    boot = mat("CivBoot", (0.09, 0.07, 0.06), rough=0.7)
button = mat("CivButton", (0.1, 0.09, 0.08), rough=0.4)

B = A.humanoid_bones(hip=0.93, chest=1.4, neck=1.52, head=1.78, sx=0.2, hx=0.1, knee=0.5, ankle=0.08, elbow=1.12, wrist=0.86)
rig = A.make_rig("Civ", B)
p = []
H = "head"
# ---- head: skull, jaw, eyes in sockets, brows, nose, ears, lips ------------------------------------------
p.append(S(skin, (0, 0.0, 1.645), 0.105, (0.92, 1.0, 1.12), H, 18, 12))
p.append(S(skin, (0, 0.04, 1.57), 0.07, (1.0, 0.95, 0.75), H))                                     # jaw
for x in (1, -1):
    p.append(S(skin2, (0.04 * x, 0.085, 1.665), 0.024, (1.2, 0.6, 0.8), H))                         # sockets
    p.append(S(eye, (0.04 * x, 0.093, 1.665), 0.013, group=H))
    p.append(S(iris, (0.04 * x, 0.104, 1.665), 0.006, group=H, seg=8, rings=6))
    p.append(box(hair if KIND == "civ_a" else skin2, (0.042 * x, 0.098, 1.69), (0.04, 0.012, 0.01), rot=(0, 0.15 * x, 0), group=H))   # brows
    p.append(S(skin, (0.1 * x, 0.0, 1.645), 0.025, (0.5, 0.9, 1.3), H))                            # ears
    p.append(S(skin2, (0.062 * x, 0.075, 1.6), 0.025, (0.8, 0.6, 1.0), H))                        # cheeks
p.append(L(skin, (0, 0.1, 1.66), (0, 0.12, 1.615), 0.016, 0.014, 8, H))                             # nose
p.append(S(skin, (0, 0.118, 1.612), 0.016, (1.2, 0.8, 0.8), H))
p.append(box(lips, (0, 0.1, 1.575), (0.045, 0.012, 0.012), group=H))
if KIND == "civ_a":
    # short hair under a flat cap with a peak; stubble
    p.append(S(hair, (0, -0.02, 1.665), 0.108, (0.95, 1.0, 1.0), H))
    p.append(S(hat, (0, 0.0, 1.74), 0.115, (1.0, 1.05, 0.45), H))
    p.append(S(hat, (0, 0.09, 1.725), 0.07, (1.15, 0.9, 0.18), H))
    p.append(box(hat, (0, 0.0, 1.765), (0.012, 0.012, 0.01), group=H))
    p.append(S(mat("CivStubble", (0.38, 0.28, 0.22), rough=0.9), (0, 0.055, 1.56), 0.06, (1.05, 0.85, 0.6), H))
else:
    # hair parted under a headscarf tied under the chin, a few strands showing
    p.append(S(hair, (0, -0.015, 1.67), 0.11, (0.98, 1.0, 1.02), H))
    p.append(S(hat, (0, -0.02, 1.68), 0.118, (1.0, 1.0, 1.05), H))
    for x in (1, -1):
        p.append(L(hat, (0.09 * x, 0.02, 1.62), (0.03 * x, 0.07, 1.52), 0.03, 0.02, 8, H))
        p.append(L(hair, (0.06 * x, 0.08, 1.72), (0.08 * x, 0.08, 1.64), 0.012, 0.008, 6, H))
    p.append(S(hat, (0, 0.07, 1.51), 0.025, group=H))                                              # the knot
    p.append(L(hat, (0, -0.1, 1.62), (0, -0.13, 1.48), 0.05, 0.03, 8, H))                          # the tail behind
# ---- neck and torso -------------------------------------------------------------------------------------
p.append(L(skin, (0, 0.0, 1.45), (0, 0.01, 1.56), 0.045, 0.042, 10, "neck"))
T = "spine"
if KIND == "civ_a":
    p.append(S(shirt, (0, 0.03, 1.36), 0.1, (1.2, 0.8, 0.8), T))                                   # flannel at the open neck
    p.append(L(top, (0, 0, 1.0), (0, 0, 1.44), 0.175, 0.17, 14, T))                                 # the jacket
    p.append(S(top, (0, 0, 1.4), 0.17, (1.25, 0.82, 0.55), T))                                       # shoulders
    for x in (1, -1):
        p.append(box(top2, (0.05 * x, 0.13, 1.42), (0.06, 0.03, 0.08), rot=(0.3, 0, 0.5 * x), group=T))   # collar
        p.append(box(top2, (0.085 * x, 0.152, 1.1), (0.09, 0.02, 0.1), rot=(0, 0, -0.5 * x), group=T))   # pockets
        p.append(box(top2, (0.085 * x, 0.156, 1.15), (0.09, 0.02, 0.02), rot=(0, 0, -0.5 * x), group=T))
        p.append(box(top2, (0.085 * x, 0.152, 1.3), (0.07, 0.02, 0.07), rot=(0, 0, -0.5 * x), group=T))
    p.append(box(top2, (0, 0.172, 1.2), (0.012, 0.012, 0.42), group=T))                            # zip
    for k in range(4):                                                                               # quilting seams
        p.append(L(top2, (0, 0.0, 1.06 + k * 0.1), (0, 0.0, 1.065 + k * 0.1), 0.177, 0.177, 14, T))
else:
    p.append(S(shirt, (0, 0.03, 1.4), 0.09, (1.2, 0.8, 0.7), T))
    p.append(L(top, (0, 0, 1.05), (0, 0, 1.44), 0.17, 0.165, 14, T))
    p.append(S(top, (0, 0, 1.4), 0.165, (1.25, 0.82, 0.55), T))
    for x in (1, -1):
        p.append(box(top2, (0.055 * x, 0.14, 1.37), (0.06, 0.03, 0.14), rot=(0.3, 0, 0.45 * x), group=T))  # lapels
    for k in range(3):
        p.append(S(button, (0.05, 0.172, 1.32 - k * 0.11), 0.012, group=T, seg=8, rings=6))
    p.append(L(top2, (0, 0, 1.05), (0, 0, 1.09), 0.176, 0.174, 14, T))                              # the belt
    p.append(box(button, (0.0, 0.172, 1.07), (0.05, 0.01, 0.05), group=T))
# hips (and the coat skirt for civ_b)
if KIND == "civ_b":
    p.append(L(top, (0, 0, 1.03), (0, 0.0, 0.42), 0.19, 0.24, 14, "hips"))
    p.append(box(top2, (0, 0.21, 0.72), (0.012, 0.03, 0.6), group="hips"))
    for k in range(3):
        p.append(S(button, (0.05, 0.215, 0.95 - k * 0.15), 0.012, group="hips", seg=8, rings=6))
    for x in (1, -1):
        p.append(box(top2, (0.13 * x, 0.15, 0.85), (0.1, 0.03, 0.12), rot=(0, 0, -0.4 * x), group="hips"))
else:
    p.append(S(legs, (0, 0, 0.93), 0.16, (1.1, 0.8, 0.55), "hips"))
    p.append(L(mat("CivBelt", (0.18, 0.1, 0.05), rough=0.6), (0, 0, 0.97), (0, 0, 1.01), 0.168, 0.168, 14, "hips"))
# ---- legs and boots --------------------------------------------------------------------------------------------
for sd, x in (("L", 1), ("R", -1)):
    p.append(L(legs, (0.1 * x, 0, 0.93), (0.1 * x, 0, 0.5), 0.078, 0.06, 10, "thigh." + sd))
    p.append(S(legs, (0.1 * x, 0.01, 0.5), 0.058, group="thigh." + sd))
    if KIND == "civ_a":
        p.append(L(legs, (0.1 * x, 0, 0.5), (0.1 * x, 0, 0.36), 0.058, 0.055, 10, "shin." + sd))
        p.append(L(boot, (0.1 * x, 0, 0.37), (0.1 * x, 0, 0.08), 0.062, 0.055, 12, "shin." + sd))   # rubber boot
        p.append(S(boot, (0.1 * x, 0, 0.37), 0.064, (1, 1, 0.25), "shin." + sd))
    else:
        p.append(L(legs, (0.1 * x, 0, 0.5), (0.1 * x, 0, 0.25), 0.055, 0.045, 10, "shin." + sd))
        p.append(L(boot, (0.1 * x, 0, 0.27), (0.1 * x, 0, 0.08), 0.052, 0.048, 12, "shin." + sd))   # ankle boot
    p.append(S(boot, (0.1 * x, 0.05, 0.045), 0.06, (0.9, 2.0, 0.75), "shin." + sd))
    p.append(box(shoe, (0.1 * x, 0.04, 0.01), (0.11, 0.26, 0.025), group="shin." + sd))            # sole
# ---- arms and hands -----------------------------------------------------------------------------------------------
for sd, x in (("L", 1), ("R", -1)):
    p.append(S(top, (0.2 * x, 0, 1.37), 0.065, group="upperarm." + sd))
    p.append(L(top, (0.2 * x, 0, 1.37), (0.21 * x, 0, 1.13), 0.06, 0.05, 10, "upperarm." + sd))
    p.append(S(top, (0.212 * x, 0, 1.12), 0.05, group="forearm." + sd))
    p.append(L(top, (0.212 * x, 0, 1.12), (0.22 * x, 0, 0.9), 0.05, 0.042, 10, "forearm." + sd))
    p.append(L(top2, (0.22 * x, 0, 0.92), (0.221 * x, 0, 0.89), 0.046, 0.046, 10, "forearm." + sd))   # cuff
    p.append(S(skin, (0.223 * x, 0.0, 0.84), 0.034, (0.65, 1.0, 1.2), "hand." + sd))
    for f in range(4):
        p.append(L(skin, (0.223 * x + 0.0, 0.0 + (f - 1.5) * 0.014, 0.81), (0.226 * x, 0.004 + (f - 1.5) * 0.015, 0.76), 0.008, 0.006, 6, "hand." + sd))
    p.append(L(skin, (0.218 * x, 0.025, 0.84), (0.21 * x, 0.04, 0.8), 0.009, 0.007, 6, "hand." + sd))   # thumb

body = A.bind(rig, p, "Obcan")
# ---- the actions: exactly the old civilian set ------------------------------------------------------------------
A.action(rig, "idle", [(1, {"forearm.L": (0.1, 0, 0), "forearm.R": (0.1, 0, 0)}, 0), (25, {"head": (0, 0.2, 0.3), "forearm.L": (0.15, 0, 0), "forearm.R": (0.15, 0, 0)}, -0.01), (49, {"forearm.L": (0.1, 0, 0), "forearm.R": (0.1, 0, 0)}, 0)])
A.action(rig, "walk", A.walk_frames(30, 0.4, 0.35, 0.02))
A.action(rig, "run", A.walk_frames(16, 0.8, 0.7, 0.05, spine=-0.2, arm_base=(1.0, 1.0)))
cower = {"thigh.L": (1.6, 0, 0.2), "thigh.R": (1.6, 0, -0.2), "shin.L": (-2.4, 0, 0), "shin.R": (-2.4, 0, 0),
         "spine": (-0.7, 0, 0), "head": (-0.3, 0, 0), "upperarm.L": (2.3, 0, -0.5), "upperarm.R": (2.3, 0, 0.5),
         "forearm.L": (1.9, 0, 0), "forearm.R": (1.9, 0, 0)}
A.action(rig, "lurk", [(1, cower, -0.55), (5, dict(cower, spine=(-0.75, 0, 0.05)), -0.56), (9, cower, -0.55), (49, cower, -0.55)])
wave = {"upperarm.R": (2.8, 0, 0.3), "forearm.R": (0.4, 0, 0)}
A.action(rig, "aim", [(1, wave, 0), (9, dict(wave, **{"forearm.R": (0.8, 0, 0)}), 0), (17, wave, 0)])
A.action(rig, "attack", [(1, wave, 0), (17, wave, 0)])
for b in rig.pose.bones:
    b.rotation_euler = (0, 0, 0)
    b.location = (0, 0, 0)
A.finish([rig, body], rig, target=(0, 0, 1.0), dist=3.0)
print("written", A.OUT)
