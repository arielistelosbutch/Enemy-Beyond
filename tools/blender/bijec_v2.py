"""Bijec v2 (0.57 pokus) after Ari's picture: a towering, impossibly muscled brute sealed in heavy dark-indigo
armour that follows every muscle, violet light in the seams, a purple face with a huge fanged open mouth and
yellow eyes under a blocky helmet, bare purple fists. No weapon, T-pose, one unrigged mesh (for afk.ai).
Commander (velitel, second picture): blood-red armour with red light, white glowing eyes, hoses into the helmet,
a wrist computer, belt pouches and a tattered cape.
Run: python bijec_v2.py [velitel] <out_base_without_ext> [--preview <dir>]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from creature_v2 import *
from creature_v2 import _apply_mods, _finish

VEL = "velitel" in sys.argv
reset()
skin_m = mat2("BijSkin", (0.36, 0.13, 0.3), rough=0.55)
skin_d = mat2("BijSkinDark", (0.22, 0.07, 0.18), rough=0.6)
if VEL:   # commander: blood-red armour, red light, white-hot eyes, a tattered cape
    armor = mat2("BijVArmor", (0.32, 0.03, 0.04), rough=0.4, metal=0.3)
    under = mat2("BijVUnder", (0.07, 0.03, 0.05), rough=0.55, metal=0.2)
    armor2 = mat2("BijVArmor2", (0.42, 0.05, 0.06), rough=0.4, metal=0.3)
    glow = mat("BijVGlow", (1.0, 0.12, 0.08), emit=3.0)
    eye = mat("BijVEye", (1.0, 0.92, 0.95), emit=7.0)
    cape_m = mat2("BijVCape", (0.25, 0.02, 0.04), rough=0.8)
    dark = mat2("BijVDark", (0.1, 0.1, 0.11), rough=0.45, metal=0.6)
else:
    armor = mat2("BijArmor", (0.075, 0.065, 0.17), rough=0.4, metal=0.3)
    under = mat2("BijUnder", (0.05, 0.04, 0.11), rough=0.55, metal=0.2)
    armor2 = mat2("BijArmor2", (0.11, 0.09, 0.23), rough=0.4, metal=0.3)
    glow = mat("BijGlow", (0.55, 0.12, 1.0), emit=2.5)
    eye = mat("BijEye", (1.0, 0.8, 0.25), emit=6.0)
mouth_m = mat2("BijMouth", (0.1, 0.01, 0.025), rough=0.4)
gum = mat2("BijGum", (0.3, 0.04, 0.08), rough=0.4)
tooth = mat2("BijTooth", (0.82, 0.76, 0.6), rough=0.35)

AY = 1.72        # arm height in T-pose
P = []
# ---- the body under the armour: one skin mesh (arms out in T) -------------------------------------------------
N = [((0, 0, 1.02), 0.25),        # 0 pelvis
     ((0, 0.02, 1.28), 0.27),     # 1 belly
     ((0, 0.0, 1.52), 0.34),      # 2 chest
     ((0, -0.02, 1.7), 0.33),     # 3 upper chest
     ((0, 0.0, 1.86), 0.19),      # 4 neck (thick trapezius)
     ((0, 0.04, 2.0), 0.15),      # 5 head
     ((0, 0.03, 2.13), 0.12)]     # 6 skull top
E = [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6)]
for x in (1, -1):
    b = len(N)
    N += [((0.42 * x, 0, AY), 0.2),       # shoulder
          ((0.66 * x, 0, AY), 0.16),      # biceps
          ((0.88 * x, 0, AY), 0.13),      # elbow
          ((1.08 * x, 0, AY), 0.12),      # forearm
          ((1.2 * x, 0, AY), 0.08),       # wrist
          ((1.29 * x, 0, AY), 0.1)]       # fist
    E += [(3, b), (b, b + 1), (b + 1, b + 2), (b + 2, b + 3), (b + 3, b + 4), (b + 4, b + 5)]
    b = len(N)
    N += [((0.18 * x, 0, 0.98), 0.2),     # hip
          ((0.2 * x, 0.01, 0.72), 0.18),  # thigh
          ((0.21 * x, 0.03, 0.5), 0.13),  # knee
          ((0.22 * x, 0.0, 0.28), 0.12),  # calf
          ((0.22 * x, -0.01, 0.1), 0.1),  # ankle
          ((0.22 * x, 0.16, 0.06), 0.09)] # toe
    E += [(0, b), (b, b + 1), (b + 1, b + 2), (b + 2, b + 3), (b + 3, b + 4), (b + 4, b + 5)]
body = skin(under, N, E, "BijBody", subsurf=2)
P.append(body)

# ---- muscle armour: pecs, abs, lats, a collar ---------------------------------------------------------------------
side = []
side.append(smooth(sphere(armor, (0.17, 0.2, 1.58), 0.2, seg=10, rings=7, scale=(1.1, 0.6, 0.75), rot=(0, 0, 0.15))))   # pec
side.append(bbox(glow, (0.17, 0.26, 1.43), (0.24, 0.02, 0.018), rot=(0, 0.12, 0)))                                       # seam under the pec
for r, z in enumerate((1.33, 1.21, 1.09)):                                                                                # abs
    side.append(bbox(armor2, (0.09, 0.24 - r * 0.005, z), (0.15, 0.08, 0.1), rot=(0.05, 0, 0), bevel=0.3))
    side.append(bbox(glow, (0.17, 0.25, z), (0.015, 0.02, 0.07)))
side.append(smooth(sphere(armor, (0.26, -0.02, 1.4), 0.2, seg=10, rings=7, scale=(0.7, 1.1, 1.2))))                       # lat / flank
side.append(bbox(glow, (0.33, 0.12, 1.38), (0.015, 0.02, 0.2), rot=(0.1, 0, 0.3)))
side.append(smooth(sphere(armor, (0.13, -0.24, 1.6), 0.2, seg=10, rings=7, scale=(1.0, 0.55, 1.0))))                      # back plate
side.append(bbox(glow, (0.2, -0.33, 1.55), (0.02, 0.015, 0.22)))
# shoulder: a stack of three curved plates (the big pauldron in the picture)
for k, (dx, dz, s) in enumerate(((0.42, 1.86, 0.26), (0.48, 1.8, 0.24), (0.54, 1.73, 0.22))):
    side.append(smooth(sphere(armor if k != 1 else armor2, (dx, 0, dz), s, seg=10, rings=6, scale=(1.0, 1.05, 0.55), rot=(0, -0.45 - k * 0.15, 0))))
side.append(bbox(glow, (0.52, 0.2, 1.8), (0.16, 0.015, 0.02), rot=(0, -0.55, 0)))
# arm: biceps plate, elbow, heavy forearm plates with a glowing slit
side.append(smooth(sphere(armor, (0.7, 0.0, AY + 0.02), 0.17, seg=10, rings=6, scale=(1.3, 0.95, 0.95))))
side.append(bbox(armor2, (0.88, 0, AY), (0.12, 0.27, 0.27), bevel=0.3))
side.append(bbox(armor, (1.05, 0, AY), (0.26, 0.3, 0.29), bevel=0.3))
side.append(bbox(glow, (1.05, 0.155, AY), (0.2, 0.012, 0.03)))
side.append(bbox(glow, (1.05, 0.0, AY + 0.15), (0.2, 0.03, 0.012)))
# the bare purple fist
side.append(smooth(sphere(skin_m, (1.29, 0.0, AY), 0.11, seg=10, rings=7, scale=(1.0, 0.95, 1.05))))
for k in range(4):
    side.append(smooth(sphere(skin_m, (1.37, 0.06 - k * 0.04, AY - 0.02), 0.035, seg=6, rings=4, scale=(1.4, 1, 1))))
side.append(smooth(sphere(skin_m, (1.29, 0.1, AY - 0.04), 0.035, seg=6, rings=4, scale=(1.4, 1, 1))))   # thumb
# hip, thigh, knee, shin, boot
side.append(bbox(armor2, (0.22, 0.08, 1.0), (0.22, 0.22, 0.2), rot=(0, 0.2, 0), bevel=0.3))
side.append(smooth(sphere(armor, (0.21, 0.05, 0.74), 0.19, seg=10, rings=7, scale=(1.0, 1.0, 1.35))))
side.append(bbox(glow, (0.21, 0.24, 0.76), (0.02, 0.012, 0.28)))
side.append(bbox(armor2, (0.21, 0.11, 0.5), (0.18, 0.12, 0.16), rot=(0.2, 0, 0), bevel=0.35))
side.append(bbox(armor, (0.22, 0.03, 0.3), (0.24, 0.26, 0.32), bevel=0.3))
side.append(bbox(glow, (0.22, 0.165, 0.3), (0.03, 0.012, 0.2)))
side.append(bbox(armor, (0.22, 0.06, 0.07), (0.25, 0.42, 0.14), bevel=0.3))                                              # boot
side.append(bbox(armor2, (0.22, 0.24, 0.1), (0.22, 0.1, 0.1), rot=(0.4, 0, 0), bevel=0.3))
P += side + mirror_x(side)
# belt and codpiece
P.append(bbox(armor2, (0, 0.0, 1.0), (0.5, 0.42, 0.1), bevel=0.3))
P.append(bbox(armor, (0, 0.2, 0.9), (0.18, 0.08, 0.2), rot=(-0.1, 0, 0), bevel=0.3))
P.append(bbox(glow, (0, 0.215, 1.0), (0.3, 0.012, 0.025)))
P.append(bbox(glow, (0, 0.0, 1.47), (0.02, 0.33, 0.012)))                                                                 # sternum seam
# ---- the head: broad purple face, heavy brow, glowing eyes, a huge open mouth with the fangs in it --------------
H = []
F = Vector((0, 0.1, 1.98))                                                                         # face centre
H.append(smooth(sphere(skin_m, F, 0.155, seg=20, rings=14, scale=(1.0, 0.92, 1.12))))                # skull / face
H.append(smooth(sphere(skin_m, F + Vector((0, 0.06, -0.12)), 0.13, seg=18, rings=12, scale=(1.12, 0.78, 0.72))))   # jowls, chin
for x in (1, -1):
    H.append(smooth(sphere(skin_m, F + Vector((0.1 * x, 0.08, -0.04)), 0.07, seg=12, rings=8, scale=(0.8, 0.7, 1.2))))  # cheeks
    H.append(smooth(sphere(skin_d, F + Vector((0.065 * x, 0.12, 0.085)), 0.07, seg=12, rings=8, scale=(1.05, 0.55, 0.4), rot=(0, -0.3 * x, 0))))  # brow
    H.append(smooth(sphere(eye, F + Vector((0.063 * x, 0.132, 0.05)), 0.022, seg=10, rings=8, scale=(1.35, 0.55, 0.7), rot=(0, -0.3 * x, 0))))
    for k in range(3):                                                                              # forehead creases
        H.append(limb(skin_d, F + Vector((0.02 * x, 0.12, 0.11 + k * 0.022)), F + Vector((0.08 * x, 0.1, 0.1 + k * 0.02)), 0.006, 0.004, verts=5))
H.append(smooth(sphere(skin_d, F + Vector((0, 0.155, 0.035)), 0.033, seg=10, rings=6, scale=(1.1, 0.8, 0.9))))       # flat nose
for x in (1, -1):
    H.append(smooth(sphere(mouth_m, F + Vector((0.015 * x, 0.175, 0.02)), 0.008, seg=6, rings=4)))
# orc jaw: a jutting lower lip with two big tusks and small teeth standing in it
M = F + Vector((0, 0.165, -0.06))
H += tube(mouth_m, [M + Vector((x, -3.0 * x * x, -1.5 * x * x)) for x in [-0.085 + 0.017 * i for i in range(11)]], 0.006)
H.append(smooth(sphere(skin_m, F + Vector((0, 0.17, -0.1)), 0.105, seg=18, rings=10, scale=(1.0, 0.42, 0.34))))   # lower lip
H.append(smooth(sphere(skin_d, F + Vector((0, 0.165, -0.125)), 0.1, seg=16, rings=8, scale=(0.95, 0.4, 0.28))))    # underjaw
for x in (1, -1):
    b0 = F + Vector((0.058 * x, 0.2, -0.08))
    b1 = b0 + Vector((0.006 * x, 0.012, 0.045))
    H.append(limb(tooth, b0, b1, 0.017, 0.013, verts=8))                                                   # tusk
    H.append(limb(tooth, b1, b1 + Vector((0.012 * x, -0.004, 0.035)), 0.013, 0.0, verts=8))
    for dx in (0.018, 0.036):
        t0 = F + Vector((dx * x, 0.207, -0.078))
        H.append(spike(tooth, t0, t0 + Vector((0, 0.002, 0.022)), 0.007, verts=6))
# helmet: a blocky shell over the crown and back of the head, cheek guards, a ridge
H.append(bbox(armor, F + Vector((0, -0.04, 0.15)), (0.34, 0.33, 0.13), bevel=0.25, seg=2))
H.append(bbox(armor2, F + Vector((0, -0.02, 0.22)), (0.14, 0.32, 0.07), bevel=0.3, seg=2))        # crest ridge
H.append(bbox(glow, F + Vector((0, 0.125, 0.135)), (0.26, 0.012, 0.016)))
for x in (1, -1):
    H.append(bbox(armor, F + Vector((0.16 * x, -0.03, 0.02)), (0.05, 0.24, 0.24), bevel=0.25, seg=2))
    H.append(bbox(armor2, F + Vector((0.19 * x, -0.03, 0.02)), (0.03, 0.1, 0.1), bevel=0.3, seg=2))   # ear disc
    H.append(bbox(glow, F + Vector((0.207 * x, -0.03, 0.02)), (0.006, 0.05, 0.05)))
H.append(bbox(armor2, F + Vector((0, -0.2, -0.05)), (0.28, 0.08, 0.32), rot=(-0.2, 0, 0), bevel=0.25, seg=2))   # nape guard
H.append(bbox(armor, (0, 0.0, 1.78), (0.44, 0.34, 0.07), bevel=0.3, seg=2))                         # collar
if VEL:
    for x in (1, -1):                                                                               # hoses from the collar into the helmet
        H += tube(dark, [(0.18 * x, -0.12, 1.82), (0.24 * x, -0.16, 1.95), (0.19 * x, -0.1, 2.05)], 0.018)
    H.append(bbox(glow, F + Vector((0, 0.13, 0.17)), (0.08, 0.012, 0.012)))
P += H
if VEL:
    V = []
    # wrist computer on the left forearm, glowing screens
    V.append(bbox(dark, (1.05, 0.0, AY), (0.2, 0.36, 0.34), bevel=0.15, seg=2))
    V.append(bbox(glow, (1.05, 0.183, AY), (0.15, 0.006, 0.12)))
    V.append(bbox(glow, (1.05, 0.0, AY + 0.172), (0.15, 0.2, 0.006)))
    # chest emblem, more light strips, belt pouches
    V.append(bbox(armor2, (0, 0.27, 1.58), (0.12, 0.03, 0.1), rot=(0, 0.785, 0), bevel=0.2))
    V.append(bbox(glow, (0, 0.287, 1.58), (0.06, 0.004, 0.05), rot=(0, 0.785, 0)))
    for x in (1, -1):
        for k in range(3):
            V.append(bbox(dark, (0.1 * x + 0.11 * x * k, 0.2 - k * 0.03, 1.0), (0.09, 0.07, 0.11), bevel=0.2))
        for z in (0.32, 0.25):
            V.append(bbox(glow, (0.22 * x, 0.165, z), (0.06, 0.006, 0.012)))
    # the cape: hangs from the shoulders down the back, tattered hem
    me = bpy.data.meshes.new("Cape")
    W, Hh, nx, nz = 0.95, 1.45, 10, 8
    verts, faces = [], []
    for j in range(nz + 1):
        for i in range(nx + 1):
            u, t = i / nx, j / nz
            x = (u - 0.5) * (0.7 + 0.5 * t)
            z = 1.82 - t * Hh
            y = -0.3 - 0.12 * t - 0.05 * math.sin(u * math.pi * 3)
            if j == nz:
                z += 0.12 * ((i * 37) % 5) / 4                                                    # tattered hem
            verts.append((x, y, z))
    for j in range(nz):
        for i in range(nx):
            a0 = j * (nx + 1) + i
            faces.append((a0, a0 + 1, a0 + nx + 2, a0 + nx + 1))
    me.from_pydata(verts, [], faces)
    cape = bpy.data.objects.new("Cape", me)
    bpy.context.scene.collection.objects.link(cape)
    sol = cape.modifiers.new("Sol", 'SOLIDIFY')
    sol.thickness = 0.02
    _apply_mods(cape)
    cape.data.materials.append(cape_m)
    V.append(smooth(cape))
    P += V

NAME = "bijec_velitel_v2" if VEL else "bijec_v2"
o = finish_mesh(P, NAME)
st = stats(o)
print("STATS", st)
ARGS = [a for a in sys.argv[1:] if a != "velitel"]
OUT = ARGS[0] if ARGS and not ARGS[0].startswith("--") else NAME
if "--preview" in sys.argv:
    d = sys.argv[sys.argv.index("--preview") + 1]
    render(os.path.join(d, NAME + "_front.png"), (0, 0, 1.2), 4.6, 0.0, 0.2)
    render(os.path.join(d, NAME + "_34.png"), (0, 0, 1.2), 4.6, 0.7, 0.4)
    render(os.path.join(d, NAME + "_head.png"), (0, 0.15, 1.95), 1.1, 0.45, 0.05)
else:
    export_all(o, OUT)
    print("written", OUT)
