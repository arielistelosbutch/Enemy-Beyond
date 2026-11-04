"""Ještěřan (0.50) after Ari's picture: a towering reptile soldier - olive scales, a pale ribbed belly,
a long neck carrying a narrow crocodile skull with huge open jaws and yellow eyes, a red spiny crest,
a light grey chest cuirass on a harness with red light strips, muscular clawed arms, digitigrade legs
with big hooked claws, a heavy tail with back scutes, a blocky red-glowing plasma rifle.
Officer ("velitel"): plate over the whole body, the crest burning brighter.
Same rig and actions as the old one (aliens.py: humanoid bones, soldier_anims).
Run: python3 tools/blender/jestetan.py [velitel] out.glb [--preview <action|-> <frame> out.png angle]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
import aliens as A
from common import *
from common import _finish

VEL = "velitel" in sys.argv
A.OUT = [a for a in sys.argv if a.endswith(".glb")][0] if any(a.endswith(".glb") for a in sys.argv) else "jestetan.glb"

def mat2(name, rgb, rough=0.6, metal=0.0, emit=0.0):
    m = mat(name, rgb, emit=emit, rough=rough)
    m.node_tree.nodes.get("Principled BSDF").inputs["Metallic"].default_value = metal
    return m

sc = mat2("JesScale", (0.17, 0.2, 0.08), rough=0.4)
sc2 = mat2("JesScale2", (0.1, 0.12, 0.05), rough=0.45)
belly = mat2("JesBelly", (0.5, 0.48, 0.34), rough=0.5)
crest = mat2("JesFrill", (0.55, 0.06, 0.08), rough=0.4)
mouth = mat2("JesMouth", (0.25, 0.03, 0.04), rough=0.4)
tooth = mat2("LihTooth", (0.75, 0.7, 0.58), rough=0.35)
eye = mat("JesEye", (1.0, 0.75, 0.1), emit=3.0)
plate = mat2("JesPlate", (0.55, 0.53, 0.5) if not VEL else (0.25, 0.23, 0.22), rough=0.4, metal=0.5)
strap = mat2("JesStrap", (0.12, 0.08, 0.08), rough=0.5)
gunm = mat2("JesGun", (0.12, 0.1, 0.1), rough=0.4, metal=0.6)
red = mat("JesRed", (1.0, 0.1, 0.08), emit=4.0)
claw = mat2("JesClaw", (0.7, 0.66, 0.6), rough=0.3)
yellow = mat2("JesYellow", (0.75, 0.5, 0.08), rough=0.45)
yellow_glow = mat("JesGoggle", (1.0, 0.95, 0.35), emit=5.0)
gun_glow = mat("JesGunGlow", (0.75, 1.0, 0.5), emit=4.0) if VEL else None

def smooth(o):
    for p in o.data.polygons:
        p.use_smooth = True
    return o

def L(material, a, b, r1, r2, verts=10, group=None, sm=True):
    o = A.limb(material, a, b, r1, r2, verts=verts, group=group)
    return smooth(o) if sm else o

def S(material, loc, r, scale=(1, 1, 1), group=None, seg=14, rings=10):
    return smooth(sphere(material, loc, r, seg=seg, rings=rings, scale=scale, group=group))

def chamf(o, w=0.02):
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    m = o.modifiers.new("Bevel", 'BEVEL')
    m.width = w
    m.segments = 1
    bpy.ops.object.modifier_apply(modifier="Bevel")
    return o

def slab(material, a, b, w, d, group=None, fw=0.0):
    """An armour plate along a limb from a to b (w wide, d deep, pushed fw forward)."""
    a = Vector(a); b = Vector(b)
    dv = b - a
    o = box(material, (0, 0, 0), (w, d, dv.length * 0.9), group=group)
    q = Vector((0, 0, 1)).rotation_difference(dv.normalized())
    for v in o.data.vertices:
        v.co = q @ (v.co + Vector((0, fw, 0))) + (a + b) / 2
    return chamf(o, 0.015)

B = A.humanoid_bones(hip=1.05, chest=1.62, neck=1.85, head=2.1, sx=0.26, hx=0.15, knee=0.6, ankle=0.06, elbow=1.3, wrist=1.0, lean=0.1)
rig = A.make_rig("Jes", B)
p = []
# ---- head: a long crocodile skull, jaws wide open, yellow eyes, a red spiny crest ------------------------------
H = "head"
p.append(S(sc, (0, 0.17, 2.02), 0.13, (0.85, 1.2, 0.8), H))                         # the skull
p.append(S(sc, (0, 0.38, 2.04), 0.08, (0.8, 2.2, 0.55), H))                         # the long upper snout
p.append(S(mouth, (0, 0.32, 1.97), 0.07, (0.7, 1.9, 0.45), H))                       # the open throat
p.append(S(sc2, (0, 0.35, 1.9), 0.07, (0.8, 2.1, 0.38), H))                        # lower jaw, hanging open
p.append(S(belly, (0, 0.27, 1.88), 0.06, (0.7, 1.6, 0.35), H))
for x in (1, -1):
    for i in range(7):
        y = 0.24 + i * 0.035
        ln = 0.05 if i in (1, 4) else 0.033
        p.append(L(tooth, (0.045 * x * (1 - i * 0.06), y, 2.0), (0.045 * x * (1 - i * 0.06), y + 0.008, 2.0 - ln), 0.008, 0.0, 5, H))
        p.append(L(tooth, (0.04 * x * (1 - i * 0.06), y, 1.91), (0.04 * x * (1 - i * 0.06), y + 0.008, 1.91 + ln * 0.8), 0.007, 0.0, 5, H))
    p.append(S(eye, (0.075 * x, 0.2, 2.07), 0.02, (1, 1.2, 0.7), H, 8, 6))
    p.append(L(sc2, (0.06 * x, 0.14, 2.1), (0.085 * x, 0.25, 2.09), 0.02, 0.01, 6, H))   # brow ridge
crest_n = 6
for k in range(crest_n):                                                               # the crest: red spines fanning back
    a = -0.6 + k / (crest_n - 1) * 1.2
    base = (math.sin(a) * 0.06, 0.12 - abs(math.sin(a)) * 0.02, 2.1)
    tip = (math.sin(a) * 0.2, -0.1 - math.cos(a) * 0.1, 2.16 + math.cos(a) * 0.12)
    p.append(L(crest, base, tip, 0.035, 0.0, 5, H, sm=False))
    if k < crest_n - 1:                                                                # webbing between the spines
        a2 = -0.6 + (k + 1) / (crest_n - 1) * 1.2
        p.append(L(crest, ((math.sin(a) + math.sin(a2)) * 0.035, 0.08, 2.11), ((math.sin(a) + math.sin(a2)) * 0.07, -0.08, 2.17), 0.03, 0.005, 4, H, sm=False))
# ---- neck ------------------------------------------------------------------------------------------------------------
p.append(L(sc, (0, 0.08, 1.6), (0, 0.17, 1.97), 0.12, 0.085, 12, "neck"))
p.append(L(belly, (0, 0.16, 1.62), (0, 0.24, 1.92), 0.075, 0.05, 10, "neck"))
for k in range(4):
    p.append(L(sc2, (0, 0.0 + k * 0.03, 1.66 + k * 0.08), (0, -0.07 + k * 0.03, 1.72 + k * 0.08), 0.03, 0.0, 4, "neck", sm=False))
# ---- torso: a broad scaled chest, the pale ribbed belly, the cuirass and the harness ------------------------------
T = "spine"
p.append(S(sc, (0, 0.04, 1.42), 0.27, (1.1, 0.85, 1.2), T))
p.append(S(sc, (0, 0.02, 1.62), 0.2, (1.45, 0.85, 0.6), T))                           # the shoulders' mass
p.append(S(belly, (0, 0.14, 1.28), 0.17, (0.95, 0.7, 1.3), T))
for k in range(4):
    p.append(L(sc2, (-0.1, 0.24, 1.14 + k * 0.07), (0.1, 0.24, 1.14 + k * 0.07), 0.012, 0.012, 6, T))    # belly ribs
if VEL:
    # full angular armour of an unknown alloy, a yellow stripe, yellow-glowing goggles
    p.append(chamf(box(plate, (0, 0.07, 1.47), (0.5, 0.42, 0.42), group=T)))
    p.append(chamf(box(plate, (0, 0.04, 1.68), (0.6, 0.36, 0.12), group=T)))
    p.append(box(yellow, (0.02, 0.285, 1.47), (0.07, 0.01, 0.4), group=T))
    for k in range(3):                                                                 # the segmented belly guard
        p.append(chamf(box(plate, (0, 0.17, 1.22 - k * 0.07), (0.34 - k * 0.03, 0.12, 0.06), group=T)))
    p.append(chamf(box(plate, (0, -0.22, 1.5), (0.36, 0.12, 0.36), group=T)))        # the pack on the back
    p.append(L(plate, (0, 0.06, 1.66), (0, 0.14, 1.86), 0.12, 0.1, 8, "neck", sm=False))
    p.append(chamf(box(plate, (0, 0.15, 2.12), (0.2, 0.3, 0.07), group=H)))           # the helmet
    p.append(chamf(box(plate, (0, 0.24, 2.07), (0.22, 0.1, 0.07), group=H)))
    p.append(box(yellow_glow, (0, 0.295, 2.07), (0.2, 0.012, 0.035), group=H))         # the goggles
else:
    cu = box(plate, (0, 0.2, 1.48), (0.42, 0.08, 0.34), group=T)
    for v in cu.data.vertices:                                                         # a shield-shaped cuirass
        if v.co.z < 1.4:
            v.co.x *= 0.55
    p.append(cu)
    p.append(box(plate, (0, 0.21, 1.6), (0.3, 0.06, 0.08), rot=(0.3, 0, 0), group=T))
for x in (1, -1):
    p.append(box(strap, (0.15 * x, 0.08, 1.62), (0.05, 0.4, 0.04), rot=(0.0, 0.3 * x, 0), group=T))   # harness over the shoulders
    p.append(box(red, (0.16 * x, 0.245, 1.5), (0.014, 0.01, 0.12), group=T))                         # red light strips
    p.append(box(red, (0.2 * x, 0.18, 1.63), (0.04, 0.012, 0.012), group=T))
p.append(box(strap, (0, 0.05, 1.18), (0.44, 0.4, 0.05), group=T))                                       # belt
p.append(box(red, (0, 0.255, 1.18), (0.06, 0.01, 0.02), group=T))
for k in range(6):                                                                       # back scutes
    p.append(L(sc2, (0, -0.18, 1.2 + k * 0.08), (0, -0.3, 1.24 + k * 0.08), 0.035, 0.0, 4, T, sm=False))
# ---- hips and the heavy tail -----------------------------------------------------------------------------------------
p.append(S(sc, (0, 0, 1.06), 0.21, (1.15, 1.0, 0.8), "hips"))
p.append(L(sc, (0, -0.15, 1.0), (0, -0.62, 0.62), 0.16, 0.09, 12, "hips"))
p.append(L(sc, (0, -0.62, 0.62), (0, -1.05, 0.2), 0.09, 0.035, 10, "hips"))
p.append(L(sc2, (0, -1.05, 0.2), (0, -1.35, 0.06), 0.035, 0.005, 8, "hips"))
for k in range(7):
    t = k / 7
    y = -0.25 - t * 0.95
    z = 0.98 - t * 0.85
    p.append(L(belly if k % 2 else sc2, (0, y, z + 0.1 - t * 0.04), (0, y - 0.08, z + 0.17 - t * 0.06), 0.03 - t * 0.015, 0.0, 4, "hips", sm=False))
# ---- arms: big shoulders, thick forearms, long claws ---------------------------------------------------------------------
for sd, x in (("L", 1), ("R", -1)):
    p.append(S(sc, (0.28 * x, 0.1, 1.58), 0.12, (1.15, 1.05, 0.85), "upperarm." + sd))
    p.append(L(sc, (0.28 * x, 0.1, 1.56), (0.285 * x, 0.1, 1.3), 0.085, 0.06, 10, "upperarm." + sd))
    p.append(S(sc, (0.285 * x, 0.1, 1.3), 0.065, group="forearm." + sd))
    p.append(L(sc, (0.285 * x, 0.1, 1.3), (0.29 * x, 0.1, 1.04), 0.075, 0.05, 10, "forearm." + sd))
    if VEL:
        p.append(slab(plate, (0.285 * x, 0.1, 1.3), (0.29 * x, 0.1, 1.04), 0.17, 0.17, "forearm." + sd))
        p.append(box(yellow, (0.375 * x, 0.1, 1.17), (0.012, 0.05, 0.18), group="forearm." + sd))
        p.append(chamf(box(plate, (0.31 * x, 0.08, 1.62), (0.24, 0.3, 0.14), rot=(0, 0.35 * x, 0), group="upperarm." + sd)))   # pauldrons
    p.append(S(sc2, (0.29 * x, 0.11, 1.0), 0.05, (1, 1.2, 1), "hand." + sd))
    for c in (-1, 0, 1, 2):
        p.append(L(claw, (0.29 * x + c * 0.018, 0.13, 0.98), (0.29 * x + c * 0.024, 0.2, 0.86), 0.012, 0.0, 5, "hand." + sd))
# ---- legs: thick thighs, a backward ankle, big hooked claws ---------------------------------------------------------------
for sd, x in (("L", 1), ("R", -1)):
    p.append(L(sc, (0.15 * x, 0, 1.04), (0.16 * x, 0.12, 0.6), 0.14, 0.085, 12, "thigh." + sd))
    if VEL:
        p.append(slab(plate, (0.15 * x, 0, 1.04), (0.16 * x, 0.12, 0.6), 0.24, 0.2, "thigh." + sd, 0.04))
        p.append(slab(plate, (0.16 * x, 0.12, 0.6), (0.16 * x, -0.1, 0.25), 0.16, 0.16, "shin." + sd, 0.03))
        p.append(chamf(box(plate, (0.16 * x, 0.15, 0.6), (0.14, 0.08, 0.12), group="shin." + sd)))   # knee
    p.append(S(sc, (0.16 * x, 0.12, 0.6), 0.08, group="shin." + sd))
    p.append(L(sc, (0.16 * x, 0.12, 0.6), (0.16 * x, -0.1, 0.25), 0.075, 0.055, 10, "shin." + sd))
    p.append(S(sc2, (0.16 * x, -0.1, 0.25), 0.055, group="shin." + sd))
    p.append(L(sc2, (0.16 * x, -0.1, 0.25), (0.16 * x, 0.04, 0.05), 0.05, 0.045, 10, "shin." + sd))
    p.append(S(sc2, (0.16 * x, 0.08, 0.04), 0.06, (1.1, 1.6, 0.5), "shin." + sd))
    for c in (-1, 0, 1):
        p.append(L(claw, (0.16 * x + c * 0.05, 0.13, 0.04), (0.16 * x + c * 0.08, 0.3, 0.0), 0.022, 0.0, 5, "shin." + sd))
    p.append(L(claw, (0.16 * x, -0.0, 0.08), (0.16 * x, -0.12, 0.01), 0.018, 0.0, 5, "shin." + sd))
# ---- the plasma rifle: blocky, dark, red-glowing (along the right hand, pointing down the arm) -------------------------
G = "hand.R"
gx, gy, gz = -0.29, 0.15, 0.98
p.append(box(gunm, (gx, gy + 0.03, gz - 0.25), (0.1, 0.14, 0.56), group=G))
p.append(box(gunm, (gx, gy + 0.1, gz - 0.12), (0.08, 0.08, 0.22), group=G))
p.append(L(gunm, (gx, gy + 0.03, gz - 0.5), (gx, gy + 0.03, gz - 0.62), 0.05, 0.045, 10, G))
p.append(L(gun_glow or red, (gx, gy + 0.03, gz - 0.3), (gx, gy + 0.03, gz - 0.6), 0.03, 0.03, 10, G))
for k in range(4):
    p.append(L(gunm, (gx, gy + 0.03, gz - 0.33 - k * 0.07), (gx, gy + 0.03, gz - 0.35 - k * 0.07), 0.042, 0.042, 10, G))
p.append(S(gun_glow or red, (gx, gy + 0.03, gz - 0.63), 0.03, (1, 1, 0.5), G, 10, 6))
p.append(box(gun_glow or red, (gx - 0.052, gy + 0.03, gz - 0.25), (0.01, 0.03, 0.34), group=G))
p.append(box(gunm, (gx, gy - 0.07, gz - 0.08), (0.06, 0.12, 0.12), group=G))

body = A.bind(rig, p, "JestetanVelitel" if VEL else "Jestetan")
A.soldier_anims(rig, True, 1.4)
for b in rig.pose.bones:
    b.rotation_euler = (0, 0, 0)
    b.location = (0, 0, 0)
A.finish([rig, body], rig, target=(0, 0.1, 1.15), dist=4.4)
print("written", A.OUT)
