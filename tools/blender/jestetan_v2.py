"""Ještěřan v2 (0.57 pokus) after Ari's picture: a towering reptile soldier - olive scales, a pale ribbed belly,
a long neck carrying a narrow crocodile skull with open jaws and yellow eyes, a red spiny crest, a light grey
chest cuirass on a harness with red light strips, muscular clawed arms, digitigrade legs with big hooked claws,
a heavy tail with back scutes. No weapon, T-pose, one unrigged mesh (for afk.ai); the tail is built as an even
chain of rings so it bends well on a bone chain (see TAIL below and --rig).
Commander (velitel, the picture with the visor): heavy dark grey plate armour with yellow stripes, a glowing visor.\nRun: python jestetan_v2.py [velitel] <out_base_without_ext> [--preview <dir>] [--rig]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from creature_v2 import *

VEL = "velitel" in sys.argv
NAME = "jestetan_velitel_v2" if VEL else "jestetan_v2"
reset()
scale_m = mat2("JesScale", (0.2, 0.23, 0.09), rough=0.5)
scale_d = mat2("JesScaleDark", (0.12, 0.14, 0.05), rough=0.55)
belly = mat2("JesBelly", (0.52, 0.48, 0.34), rough=0.55)
crest = mat2("JesCrest", (0.55, 0.06, 0.08), rough=0.45)
plate = mat2("JesPlate", (0.58, 0.56, 0.54), rough=0.35, metal=0.4)
strap = mat2("JesStrap", (0.17, 0.06, 0.06), rough=0.6)
glow = mat("JesGlow", (1.0, 0.08, 0.1), emit=3.0)
mouth = mat2("JesMouth", (0.3, 0.04, 0.05), rough=0.4)
tooth = mat2("JesTooth", (0.82, 0.78, 0.62), rough=0.35)
claw = mat2("JesClaw", (0.75, 0.72, 0.62), rough=0.35)
eye = mat("JesEye", (1.0, 0.75, 0.1), emit=6.0)

AY = 1.6
# the tail spine: ground-hugging S-curve backwards (-Y); also the bone chain for --rig
TAIL = [(0, -0.12, 0.98), (0, -0.4, 0.86), (0, -0.68, 0.68), (0, -0.95, 0.48), (0, -1.2, 0.3), (0, -1.42, 0.18), (0, -1.6, 0.12)]
TAIL_R = [0.18, 0.15, 0.12, 0.09, 0.065, 0.04, 0.015]
P = []
N = [((0, -0.03, 1.0), 0.19),     # 0 pelvis
     ((0, 0.0, 1.2), 0.2),        # 1 belly
     ((0, 0.02, 1.42), 0.28),     # 2 chest
     ((0, 0.0, AY), 0.26),        # 3 upper chest
     ((0, 0.06, 1.76), 0.14),     # 4 neck base
     ((0, 0.13, 1.92), 0.105),    # 5 neck
     ((0, 0.2, 2.04), 0.09)]      # 6 head base
E = [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6)]
prev = 0
for p, r in zip(TAIL[1:], TAIL_R[1:]):
    N.append((p, r))
    E.append((prev, len(N) - 1))
    prev = len(N) - 1
for x in (1, -1):
    b = len(N)
    N += [((0.34 * x, 0, AY), 0.13), ((0.5 * x, 0, AY), 0.1), ((0.66 * x, 0, AY), 0.075),
          ((0.8 * x, 0, AY), 0.085), ((0.93 * x, 0, AY), 0.055), ((1.0 * x, 0, AY), 0.06)]
    E += [(3, b), (b, b + 1), (b + 1, b + 2), (b + 2, b + 3), (b + 3, b + 4), (b + 4, b + 5)]
    b = len(N)
    N += [((0.16 * x, -0.03, 0.97), 0.17), ((0.19 * x, 0.06, 0.74), 0.15), ((0.2 * x, 0.13, 0.55), 0.09),
          ((0.21 * x, -0.06, 0.22), 0.065), ((0.21 * x, 0.04, 0.07), 0.065), ((0.21 * x, 0.15, 0.05), 0.05)]
    E += [(0, b), (b, b + 1), (b + 1, b + 2), (b + 2, b + 3), (b + 3, b + 4), (b + 4, b + 5)]
P.append(skin(scale_m, N, E, "JesBody", subsurf=1))

side = []
# ---- belly: pale ribbed plate ------------------------------------------------------------------------------------
P.append(smooth(sphere(belly, (0, 0.13, 1.2), 0.2, seg=12, rings=8, scale=(0.75, 0.45, 1.25))))
for k in range(5):
    P.append(limb(belly, (-0.12, 0.2 - abs(k - 2) * 0.01, 1.03 + k * 0.075), (0.12, 0.2 - abs(k - 2) * 0.01, 1.03 + k * 0.075), 0.016, 0.016, verts=6))
# ---- muscles: pecs under the cuirass, delts, biceps, forearms, thighs ----------------------------------------------
side.append(smooth(sphere(scale_m, (0.36, 0.0, AY + 0.02), 0.13, seg=10, rings=7, scale=(1.0, 1.0, 0.9))))
side.append(smooth(sphere(scale_m, (0.52, 0.01, AY + 0.02), 0.1, seg=10, rings=7, scale=(1.5, 0.95, 0.95))))
side.append(smooth(sphere(scale_m, (0.79, 0.0, AY), 0.09, seg=10, rings=7, scale=(1.6, 1.0, 1.0))))
side.append(smooth(sphere(scale_m, (0.2, 0.07, 0.76), 0.17, seg=10, rings=7, scale=(1.0, 1.05, 1.35))))
side.append(smooth(sphere(scale_d, (0.21, -0.04, 0.33), 0.07, seg=8, rings=6, scale=(0.9, 1.2, 1.6))))   # calf tendon
side.append(spike(scale_d, (0.68, -0.05, AY), (0.62, -0.13, AY), 0.03))                                    # elbow spur
# ---- hand: four clawed fingers -------------------------------------------------------------------------------------
for k in range(4):
    a = Vector((1.02, 0.045 - k * 0.03, AY))
    if k == 0:
        b = Vector((1.05, 0.11, AY - 0.04)); a = Vector((1.0, 0.05, AY - 0.02))   # thumb forward
    else:
        b = Vector((1.15, 0.05 - k * 0.035, AY - 0.02))
    side.append(limb(scale_m, a, b, 0.022, 0.016, verts=6))
    tip = b + (b - a).normalized() * 0.05 + Vector((0, 0, -0.045))
    side.append(spike(claw, b, tip, 0.016))
# ---- foot: three long toes with big hooked claws, a dew claw -------------------------------------------------------
for k, dx in enumerate((-0.05, 0.0, 0.05)):
    a = Vector((0.21 + dx * 0.6, 0.1, 0.05)); b = Vector((0.21 + dx * 1.3, 0.27 - abs(dx), 0.035))
    side.append(limb(scale_m, a, b, 0.03, 0.022, verts=6))
    side.append(spike(claw, b, b + Vector((dx * 0.2, 0.07, -0.035)), 0.022))
side.append(spike(claw, (0.21, -0.05, 0.12), (0.21, -0.13, 0.04), 0.018))
# ---- harness and cuirass ---------------------------------------------------------------------------------------------
side.append(limb(strap, (0.13, 0.2, 1.48), (0.24, 0.0, AY + 0.15), 0.025, 0.025, verts=4, sm=False))       # strap over the shoulder
side.append(limb(strap, (0.24, 0.0, AY + 0.15), (0.13, -0.2, 1.45), 0.025, 0.025, verts=4, sm=False))
side.append(bbox(glow, (0.2, 0.24, 1.6), (0.02, 0.02, 0.1), rot=(0.4, 0, 0.4)))
side.append(bbox(strap, (0.2, 0.19, 1.3), (0.06, 0.04, 0.12), bevel=0.3))                                  # pouch
side.append(bbox(glow, (0.2, 0.215, 1.3), (0.012, 0.012, 0.08)))
P += side + mirror_x(side)
cu = bbox(plate, (0, 0.22, 1.5), (0.44, 0.12, 0.36), rot=(0.12, 0, 0), bevel=0.3)
for v in cu.data.vertices:                                         # pointed bottom like the picture
    if v.co.z < 1.45:
        v.co.x *= 0.55
        v.co.z -= 0.05 * (1 - abs(v.co.x) / 0.18)
P.append(cu)
P.append(bbox(plate, (0, 0.24, 1.64), (0.26, 0.08, 0.1), rot=(0.12, 0, 0), bevel=0.3))
P.append(bbox(scale_d, (0, 0.29, 1.54), (0.08, 0.02, 0.06), bevel=0.4))                                      # dark centre stone
P.append(bbox(plate, (0, -0.21, 1.48), (0.4, 0.1, 0.34), rot=(-0.1, 0, 0), bevel=0.3))                      # back plate
P.append(bbox(glow, (0, -0.265, 1.48), (0.2, 0.012, 0.018)))
P.append(bbox(strap, (0, 0.0, 1.02), (0.4, 0.38, 0.06), bevel=0.3))                                          # belt
P.append(bbox(glow, (0.12, 0.19, 1.02), (0.06, 0.012, 0.015)))
P.append(bbox(glow, (-0.12, 0.19, 1.02), (0.06, 0.012, 0.015)))
# ---- back scutes down the spine and the tail ---------------------------------------------------------------------------
SC = []   # scutes and back spikes: fused into the body skin below, so auto-riggers (afk.ai) bend them with the tail
for k in range(5):
    z = AY - k * 0.12
    SC.append(spike(scale_d, (0, -0.2 + k * 0.01, z), (0, -0.28 + k * 0.01, z - 0.04), 0.03))
for i in range(len(TAIL) - 2):
    a, b = Vector(TAIL[i]), Vector(TAIL[i + 1])
    for t in (0.25, 0.75):
        p = a.lerp(b, t)
        r = TAIL_R[i] + (TAIL_R[i + 1] - TAIL_R[i]) * t
        SC.append(bbox(belly, p + Vector((0, 0, r * 0.8)), (0.03 + r * 0.25, 0.07, 0.04 + r * 0.25), rot=(0.4, 0, 0), bevel=0.35))
sc = join(SC, "Scutes")
bo = P[0].modifiers.new("Fuse", 'BOOLEAN')
bo.operation = 'UNION'
bo.solver = 'EXACT'
bo.object = sc
from creature_v2 import _apply_mods
_apply_mods(P[0])
bpy.data.objects.remove(sc)
# ---- the head: long crocodile skull, jaws open, yellow eyes, red spiny crest -----------------------------------------
H = []
H.append(smooth(sphere(scale_m, (0, 0.27, 2.12), 0.115, seg=12, rings=8, scale=(0.95, 1.2, 0.85))))           # cranium
H.append(smooth(sphere(scale_m, (0, 0.47, 2.11), 0.09, seg=12, rings=8, scale=(0.72, 2.3, 0.5))))              # upper jaw
H.append(smooth(sphere(mouth, (0, 0.44, 2.075), 0.075, seg=10, rings=6, scale=(0.7, 2.2, 0.3))))              # palate
HG = Vector((0, 0.27, 2.04)); JA = -0.5                                                                     # jaw hinge, opening angle
JD = Vector((0, math.cos(JA), math.sin(JA))); JN = Vector((0, -math.sin(JA), math.cos(JA)))
H.append(smooth(sphere(scale_m, HG + JD * 0.19, 0.08, seg=12, rings=8, scale=(0.7, 2.3, 0.36), rot=(JA, 0, 0))))   # lower jaw
H.append(smooth(sphere(mouth, HG + JD * 0.18 + JN * 0.02, 0.065, seg=10, rings=6, scale=(0.6, 2.2, 0.2), rot=(JA, 0, 0))))  # tongue
H.append(smooth(sphere(belly, (0, 0.2, 1.97), 0.085, seg=10, rings=6, scale=(0.9, 1.3, 0.65), rot=(0.4, 0, 0))))    # throat
for x in (1, -1):
    H.append(smooth(sphere(eye, (0.08 * x, 0.32, 2.17), 0.022, seg=8, rings=6, scale=(0.7, 1.2, 0.8))))
    H.append(smooth(sphere(scale_d, (0.075 * x, 0.32, 2.2), 0.032, seg=8, rings=5, scale=(0.9, 1.6, 0.5))))      # brow ridge
    for k in range(7):                                                                                           # upper teeth
        y = 0.33 + k * 0.045
        w = 0.058 * math.sqrt(max(0.05, 1 - ((y - 0.47) / 0.21) ** 2))
        ln = 0.045 if k in (1, 4) else 0.028
        H.append(spike(tooth, (w * x, y, 2.075), (w * x * 0.95, y + 0.006, 2.075 - ln), 0.009))
    for k in range(6):                                                                                           # lower teeth
        sj = 0.08 + k * 0.045
        w = 0.05 * math.sqrt(max(0.05, 1 - ((sj - 0.19) / 0.19) ** 2))
        bse = HG + JD * sj + JN * 0.022 + Vector((w * x, 0, 0))
        H.append(spike(tooth, bse, bse + JN * (0.045 if k == 2 else 0.028), 0.008))
# the crest: red spines fanning back from the top of the skull and down the neck
for k, (ang, ln) in enumerate(((-0.5, 0.2), (-0.15, 0.28), (0.2, 0.3), (0.55, 0.27), (0.9, 0.2), (1.2, 0.15))):
    base = Vector((0, 0.25 - k * 0.04, 2.21 - k * 0.04))
    d = Vector((0, -math.sin(ang + 0.6), math.cos(ang + 0.6)))
    H.append(spike(crest, base, base + d * ln, 0.025, verts=4))
    if k % 2 == 0:
        for x in (1, -1):
            H.append(spike(crest, base + Vector((0.035 * x, 0, -0.01)), base + d * ln * 0.7 + Vector((0.08 * x, 0, 0)), 0.018, verts=4))
for k in range(3):
    base = Vector((0, 0.08 - k * 0.05, 1.93 - k * 0.09))
    H.append(spike(crest, base, base + Vector((0, -0.16, 0.06)), 0.02, verts=4))
P += H
if VEL:   # commander (picture with the visor): heavy dark grey plate armour with yellow stripes, a glowing visor
    arm = mat2("JesVArmor", (0.1, 0.1, 0.11), rough=0.5, metal=0.5)
    arm2 = mat2("JesVArmor2", (0.15, 0.15, 0.16), rough=0.5, metal=0.5)
    yel = mat2("JesVYellow", (0.75, 0.52, 0.05), rough=0.5)
    vis = mat("JesVVisor", (0.9, 1.0, 0.35), emit=5.0)
    V = []
    V.append(bbox(arm, (0, 0.2, 1.5), (0.6, 0.18, 0.42), rot=(0.1, 0, 0), bevel=0.15, seg=2))       # breastplate
    V.append(bbox(yel, (0.06, 0.295, 1.5), (0.07, 0.012, 0.4), rot=(0.1, 0, 0)))
    V.append(bbox(arm2, (0, 0.12, 1.69), (0.44, 0.22, 0.08), bevel=0.25, seg=2))                    # collar
    V.append(bbox(arm, (0, -0.2, 1.5), (0.56, 0.14, 0.42), rot=(-0.1, 0, 0), bevel=0.15, seg=2))     # back plate
    for k in range(3):                                                                            # abdominal bands
        V.append(bbox(arm2, (0, 0.17 - k * 0.01, 1.24 - k * 0.075), (0.36 - k * 0.03, 0.12, 0.06), bevel=0.3, seg=2))
    V.append(bbox(arm, (0, 0.0, 1.03), (0.46, 0.42, 0.08), bevel=0.25, seg=2))                      # belt
    S = []
    S.append(bbox(arm, (0.37, 0.0, AY + 0.08), (0.24, 0.3, 0.16), rot=(0, -0.35, 0), bevel=0.2, seg=2))   # pauldron
    S.append(bbox(arm2, (0.44, 0.0, AY + 0.02), (0.14, 0.26, 0.1), rot=(0, -0.7, 0), bevel=0.25, seg=2))
    S.append(bbox(arm, (0.84, 0.0, AY), (0.24, 0.2, 0.2), bevel=0.2, seg=2))                         # forearm guard
    S.append(bbox(yel, (0.84, 0.0, AY + 0.103), (0.2, 0.05, 0.01)))
    S.append(bbox(arm, (0.2, 0.08, 0.78), (0.26, 0.3, 0.38), rot=(0.25, 0, 0), bevel=0.15, seg=2))    # thigh plate
    S.append(bbox(arm2, (0.2, 0.2, 0.55), (0.16, 0.1, 0.14), rot=(0.3, 0, 0), bevel=0.3, seg=2))      # knee
    S.append(bbox(arm, (0.21, -0.03, 0.33), (0.15, 0.13, 0.28), rot=(-0.5, 0, 0), bevel=0.2, seg=2))   # shin guard
    S.append(bbox(arm2, (0.2, -0.12, 1.0), (0.14, 0.2, 0.22), rot=(0, 0.2, 0), bevel=0.25, seg=2))     # hip plate
    V += S + mirror_x(S)
    V.append(bbox(arm, (0, 0.27, 2.22), (0.23, 0.26, 0.09), bevel=0.25, seg=2))                      # helmet cap
    V.append(bbox(arm2, (0, 0.33, 2.165), (0.22, 0.14, 0.075), bevel=0.25, seg=2))                   # visor housing
    V.append(bbox(vis, (0, 0.402, 2.165), (0.17, 0.008, 0.03)))
    for x in (1, -1):
        V.append(bbox(vis, (0.111 * x, 0.34, 2.165), (0.008, 0.08, 0.03)))
    P += V

o = finish_mesh(P, NAME)
print("STATS", stats(o))
ARGS = [a for a in sys.argv[1:] if a != "velitel"]
OUT = ARGS[0] if ARGS and not ARGS[0].startswith("--") else NAME


def build_rig(o):
    """Game humanoid rig (same bone names as aliens.humanoid_bones, but in T-pose) plus a tail chain
    tail.1..tail.6 for SpringBoneSimulator3D. Weights by distance to the bones (robust on joined parts)."""
    from mathutils.geometry import intersect_point_line
    B = {"root": ((0, 0, 0), (0, 0, 0.25), None),
         "hips": ((0, -0.03, 1.0), (0, 0, 1.12), "root"),
         "spine": ((0, 0, 1.12), (0, 0, AY), "hips"),
         "neck": ((0, 0, AY), (0, 0.2, 2.04), "spine"),
         "head": ((0, 0.2, 2.04), (0, 0.62, 2.1), "neck")}
    for sd, x in (("L", 1), ("R", -1)):
        B["thigh." + sd] = ((0.17 * x, -0.03, 0.97), (0.2 * x, 0.13, 0.55), "hips")
        B["shin." + sd] = ((0.2 * x, 0.13, 0.55), (0.21 * x, 0.15, 0.05), "thigh." + sd)
        B["upperarm." + sd] = ((0.2 * x, 0, AY), (0.66 * x, 0, AY), "spine")
        B["forearm." + sd] = ((0.66 * x, 0, AY), (0.93 * x, 0, AY), "upperarm." + sd)
        B["hand." + sd] = ((0.93 * x, 0, AY), (1.17 * x, 0, AY), "forearm." + sd)
    for i in range(6):
        B["tail.%d" % (i + 1)] = (TAIL[i], TAIL[i + 1], "hips" if i == 0 else "tail.%d" % i)
    ad = bpy.data.armatures.new("JesV2Rig")
    rig = bpy.data.objects.new("JesV2Rig", ad)
    bpy.context.scene.collection.objects.link(rig)
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='EDIT')
    for n, (h, t, par) in B.items():
        eb = ad.edit_bones.new(n)
        eb.head, eb.tail = h, t
        eb.roll = 0
    for n, (h, t, par) in B.items():
        if par:
            ad.edit_bones[n].parent = ad.edit_bones[par]
            ad.edit_bones[n].use_connect = n.startswith("tail.") and n != "tail.1"
    bpy.ops.object.mode_set(mode='OBJECT')
    deform = [n for n in B if n != "root"]
    groups = {n: o.vertex_groups.new(name=n) for n in deform}
    for v in o.data.vertices:
        co = v.co
        ds = []
        for n in deform:
            h, t = Vector(B[n][0]), Vector(B[n][1])
            if n.startswith("tail.") and co.y > -0.12:
                continue                                     # the tail never pulls the belly or legs
            if n.startswith("tail.") is False and n != "hips" and co.y < -0.3 and co.z > 0.25 and abs(co.x) < 0.2:
                continue                                     # tail vertices stay off the legs
            p, f = intersect_point_line(co, h, t)
            f = min(1.0, max(0.0, f))
            ds.append(((co - h.lerp(t, f)).length, n))
        ds.sort()
        (d1, n1), (d2, n2) = ds[0], ds[1]
        if d2 < d1 * 1.6 and d2 > 1e-6:
            w2 = 0.5 * (1.0 - (d2 - d1) / (0.6 * d1))      # 0.5 on the border, 0 at 1.6x the distance
            groups[n1].add([v.index], 1.0 - w2, 'REPLACE')
            groups[n2].add([v.index], w2, 'REPLACE')
        else:
            groups[n1].add([v.index], 1.0, 'REPLACE')
    mod = o.modifiers.new("Armature", 'ARMATURE')
    mod.object = rig
    o.parent = rig
    for b in rig.pose.bones:
        b.rotation_mode = 'XYZ'
    return rig

if "--preview" in sys.argv:
    d = sys.argv[sys.argv.index("--preview") + 1]
    render(os.path.join(d, NAME + "_front.png"), (0, 0, 1.15), 5.0, 0.0, 0.2)
    render(os.path.join(d, NAME + "_34.png"), (0, -0.3, 1.15), 5.0, 1.1, 0.4)
    render(os.path.join(d, NAME + "_head.png"), (0, 0.3, 2.05), 1.3, 1.0, 0.1)
elif "--rig" in sys.argv:
    rig = build_rig(o)
    if "--rigtest" in sys.argv:
        d = sys.argv[sys.argv.index("--rigtest") + 1]
        for i in range(6):
            rig.pose.bones["tail.%d" % (i + 1)].rotation_euler = (0, 0, 0.28)
        rig.pose.bones["upperarm.L"].rotation_euler = (0, 0, -1.2)
        rig.pose.bones["neck"].rotation_euler = (0.3, 0, 0)
        bpy.context.view_layer.update()
        render(os.path.join(d, "jes_rig_top.png"), (0, -0.5, 1.0), 4.6, 0.6, 3.5)
        render(os.path.join(d, "jes_rig_34.png"), (0, -0.3, 1.1), 5.0, 1.1, 0.4)
    else:
        bpy.ops.object.select_all(action='DESELECT')
        rig.select_set(True)
        o.select_set(True)
        bpy.ops.export_scene.gltf(filepath=OUT + "_rig.glb", export_format='GLB', use_selection=True, export_yup=True,
                                  export_apply=False, export_animations=False, export_skins=True)
        print("written", OUT + "_rig.glb")
else:
    export_all(o, OUT)
    print("written", OUT)
