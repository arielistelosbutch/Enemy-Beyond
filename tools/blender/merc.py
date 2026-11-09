"""Mercenary (player character). Own design: field jacket, plate carrier,
helmet or cap. Rigid-skinned like the grey. Gear pieces are separate meshes
named Gear_* so the game can show exactly what the merc carries.
Animations: idle, walk, run, crouch, crouch_walk, downed."""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from common import *

OUT = sys.argv[-1] if sys.argv[-1].endswith(".glb") else "merc.glb"
reset()
cloth = mat("Uniform", (0.22, 0.24, 0.17))          # recoloured per player in game
vest = mat("Vest", (0.16, 0.17, 0.13))
webbing = mat("Webbing", (0.11, 0.12, 0.09))
skin = mat("Skin", (0.62, 0.47, 0.38))
boots = mat("Boots", (0.07, 0.06, 0.05))
glove = mat("Glove", (0.07, 0.07, 0.065))
helmet = mat("Helmet", (0.19, 0.21, 0.16), rough=0.6)
metal = mat("GearMetal", (0.2, 0.21, 0.22), rough=0.4)
lens = mat("TorchLens", (1.0, 0.95, 0.8), emit=2.0)
medred = mat("MedRed", (0.6, 0.08, 0.06))
patch = mat("Patch", (0.85, 0.65, 0.15))           # recoloured per player in game
olive = mat("GrenadeOlive", (0.18, 0.22, 0.12))
flare = mat("FlareRed", (0.7, 0.12, 0.08))
scan = mat("ScannerBody", (0.25, 0.27, 0.24))
screen = mat("ScannerScreen", (0.2, 0.9, 0.4), emit=2.0)
plate = mat("ArmorPlate", (0.22, 0.22, 0.25), rough=0.45)         # 0.50: the UAI light armour (Ari's design)
idlight = mat("IdLight", (0.55, 0.95, 1.0), emit=3.0)
idred = mat("IdRed", (0.75, 0.08, 0.06), emit=0.6)
sole = mat("Sole", (0.03, 0.03, 0.03))
letter = mat("PatchText", (0.05, 0.05, 0.04))

def chamf(o, w=0.012):
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    m = o.modifiers.new("Bevel", 'BEVEL')
    m.width = w
    m.segments = 1
    bpy.ops.object.modifier_apply(modifier="Bevel")
    return o

def bb(m, loc, size, group, w=0.012, rot=(0, 0, 0)):
    """A box with chamfered edges (softer, reads better at a distance)."""
    return chamf(box(m, loc, size, rot=rot, group=group), w)

B = {
    "root": ((0, 0, 0), (0, 0, 0.3), None),
    "hips": ((0, 0, 0.95), (0, 0, 1.05), "root"),
    "spine": ((0, 0, 1.05), (0, 0, 1.42), "hips"),
    "neck": ((0, 0, 1.42), (0, 0, 1.55), "spine"),
    "head": ((0, 0, 1.55), (0, 0, 1.82), "neck"),
}
for s, x in (("L", 1), ("R", -1)):
    B["thigh." + s] = ((0.1 * x, 0, 0.95), (0.1 * x, 0, 0.52), "hips")
    B["shin." + s] = ((0.1 * x, 0, 0.52), (0.1 * x, 0, 0.1), "thigh." + s)
    B["upperarm." + s] = ((0.21 * x, 0, 1.4), (0.23 * x, 0, 1.13), "spine")
    B["forearm." + s] = ((0.23 * x, 0, 1.13), (0.24 * x, 0, 0.88), "upperarm." + s)
    B["hand." + s] = ((0.24 * x, 0, 0.88), (0.24 * x, 0, 0.78), "forearm." + s)

arm_data = bpy.data.armatures.new("MercRig")
rig = bpy.data.objects.new("MercRig", arm_data)
bpy.context.scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
for name, (h, t, parent) in B.items():
    eb = arm_data.edit_bones.new(name)
    eb.head, eb.tail = h, t
for name, (h, t, parent) in B.items():
    if parent:
        arm_data.edit_bones[name].parent = arm_data.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')

meshes = []
def piece(name, parts):
    o = join(parts, name)
    m = o.modifiers.new("Armature", 'ARMATURE')
    m.object = rig
    o.parent = rig
    meshes.append(o)
    return o

# ---- body --------------------------------------------------------------------------
# 0.57 facelift: the body is the bare soldier (skin torso and arms, trousers, boots, belt);
# what he wears on top comes from the Look_* pieces below, all on the same bones (rigid skin,
# so the afk movements, the weapon grips and the Workshop anchors stay exactly as they were).
# Clothes are a bit bigger than the skin under them: a jacket simply hides the bare arm (and a tattoo on it).
tee = mat("Tee", (0.13, 0.14, 0.11))
body = []
body.append(bb(skin, (0, 0, 1.24), (0.36, 0.2, 0.36), "spine", 0.03))              # bare torso (under the clothes)
body.append(bb(cloth, (0, 0, 1.0), (0.34, 0.2, 0.16), "hips", 0.02))
body.append(cyl(skin, (0, 0, 1.49), 0.055, 0.1, verts=6, group="neck"))
body.append(box(skin, (0, 0.01, 1.66), (0.18, 0.2, 0.23), group="head"))           # head
body.append(box(skin, (0, 0.11, 1.628), (0.036, 0.026, 0.042), group="head"))      # nose
# eyes (iris colour set in the game), whites, brows (hair colour)
eyes = mat("Eyes", (0.3, 0.2, 0.1), rough=0.2)
white = mat("EyeWhite", (0.85, 0.85, 0.8), rough=0.3)
hairm = mat("Hair", (0.2, 0.13, 0.07), rough=0.8)          # recoloured in game
beardm = mat("Beard", (0.2, 0.13, 0.07), rough=0.85)       # recoloured in game
lips = mat("Lips", (0.55, 0.25, 0.25), rough=0.6)
for x in (1, -1):
    body.append(box(white, (0.042 * x, 0.108, 1.69), (0.04, 0.008, 0.022), group="head"))
    body.append(box(eyes, (0.042 * x, 0.112, 1.69), (0.018, 0.006, 0.018), group="head"))
    body.append(box(hairm, (0.042 * x, 0.108, 1.712), (0.05, 0.012, 0.01), group="head"))
for s, x in (("L", 1), ("R", -1)):
    U, F, HD, T, S = "upperarm." + s, "forearm." + s, "hand." + s, "thigh." + s, "shin." + s
    body.append(bb(skin, (0.215 * x, 0, 1.28), (0.085, 0.095, 0.24), U))                  # bare arms
    body.append(bb(skin, (0.235 * x, 0, 1.01), (0.075, 0.085, 0.24), F))
    body.append(bb(glove, (0.24 * x, 0.01, 0.83), (0.075, 0.085, 0.1), HD))
    body.append(bb(webbing, (0.24 * x, 0.052, 0.845), (0.06, 0.012, 0.035), HD, 0.004))    # knuckle guard
    body.append(bb(cloth, (0.1 * x, 0, 0.74), (0.145, 0.155, 0.42), T))
    body.append(bb(cloth, (0.1 * x, 0, 0.33), (0.125, 0.135, 0.36), S))
    body.append(bb(boots, (0.1 * x, 0.04, 0.09), (0.125, 0.26, 0.16), S, 0.02))            # boot
    body.append(bb(boots, (0.1 * x, 0.0, 0.19), (0.13, 0.14, 0.08), S, 0.01))              # boot shaft
    body.append(box(sole, (0.1 * x, 0.04, 0.012), (0.13, 0.27, 0.025), group=S))
    for k in range(3):                                                                     # laces
        body.append(box(webbing, (0.1 * x, 0.105 - k * 0.015, 0.14 + k * 0.03), (0.05, 0.006, 0.008), group=S))
# the wrist unit with its little screen (left forearm)
body.append(bb(webbing, (0.245, 0.03, 0.94), (0.06, 0.07, 0.05), "forearm.L", 0.006))
body.append(box(idlight, (0.245, 0.067, 0.94), (0.04, 0.004, 0.032), group="forearm.L"))
# the belt (always worn)
body.append(bb(webbing, (0, 0.0, 0.955), (0.36, 0.22, 0.045), "hips", 0.008))
body.append(box(metal, (0, 0.112, 0.955), (0.05, 0.008, 0.03), group="hips"))                  # buckle
piece("Body", body)

# ---- tops (Game.TOPS): jacket, rolled sleeves, T-shirt, no shirt (the woman: a tank top) ----
def sleeve_patch(x, U):
    """The UAI patch on the shoulder (its colour tells the players apart)."""
    out = [box(patch, (0.268 * x, 0, 1.33), (0.008, 0.075, 0.05), group=U)]
    for (dy, dz, w, h) in ((-0.025, 0, 0.006, 0.03), (-0.012, -0.012, 0.02, 0.006), (0.0, 0, 0.006, 0.03),     # U
                           (0.008, 0, 0.006, 0.03), (0.02, 0, 0.006, 0.03), (0.014, 0.012, 0.016, 0.006), (0.014, 0.0, 0.016, 0.005),  # A
                           (0.03, 0, 0.006, 0.03)):                                                              # I
        out.append(box(letter, (0.273 * x, dy * x, 1.33 + dz), (0.003, w, h), group=U))
    return out
for s, x in (("L", 1), ("R", -1)):
    piece("Look_Patch" + s, sleeve_patch(x, "upperarm." + s))
    # with bare shoulders: an armband in the player's colour instead
    piece("Look_Armband" + s, [box(patch, (0.215 * x, 0, 1.33), (0.093, 0.103, 0.035), group="upperarm." + s)])

def torso(m):
    return bb(m, (0, 0, 1.24), (0.38, 0.22, 0.38), "spine", 0.03)
collar = lambda: bb(cloth, (0, 0.0, 1.45), (0.2, 0.17, 0.05), "spine", 0.015)
top = [torso(cloth), collar()]
for s, x in (("L", 1), ("R", -1)):
    U, F = "upperarm." + s, "forearm." + s
    top.append(bb(cloth, (0.215 * x, 0, 1.28), (0.105, 0.115, 0.26), U))
    top.append(bb(cloth, (0.235 * x, 0, 1.01), (0.09, 0.1, 0.25), F))
    top.append(bb(webbing, (0.237 * x, 0, 0.9), (0.096, 0.106, 0.035), F, 0.006))        # cuff strap
piece("Look_TopJacket", top)
top = [torso(cloth), collar()]
for s, x in (("L", 1), ("R", -1)):
    U = "upperarm." + s
    top.append(bb(cloth, (0.215 * x, 0, 1.29), (0.105, 0.115, 0.24), U))
    top.append(bb(cloth, (0.215 * x, 0, 1.175), (0.115, 0.125, 0.05), U, 0.01))          # the roll above the elbow
piece("Look_TopRolled", top)
top = [torso(tee), bb(tee, (0, 0.0, 1.435), (0.16, 0.15, 0.03), "spine", 0.01)]            # crew neck
for s, x in (("L", 1), ("R", -1)):
    top.append(bb(tee, (0.215 * x, 0, 1.345), (0.105, 0.115, 0.13), "upperarm." + s))      # short sleeves
piece("Look_TopTee", top)
piece("Look_TopTank", [torso(tee)])                    # the woman's "no shirt": a tank top

# ---- trousers (Game.PANTS): cargo pockets and the armoured knee pads are pieces of their own ----
pk, kp = [], []
for s, x in (("L", 1), ("R", -1)):
    T, S = "thigh." + s, "shin." + s
    pk.append(bb(cloth, (0.17 * x, 0.01, 0.7), (0.035, 0.11, 0.13), T, 0.008))           # cargo pocket
    pk.append(bb(webbing, (0.1 * x, 0.0, 0.62), (0.155, 0.165, 0.028), T, 0.005))        # thigh strap
    kp.append(bb(plate, (0.1 * x, 0.075, 0.5), (0.11, 0.035, 0.13), S, 0.012))           # armoured knee pad
    kp.append(bb(webbing, (0.1 * x, 0.0, 0.42), (0.13, 0.14, 0.025), S, 0.005))
piece("Look_PantsCargo", pk)
piece("Look_KneePads", kp)

# ---- vests (Game.VESTS), only looks: armour from the inventory (Gear_Vest / Gear_Plate) hides them ----
v = []
for x in (1, -1):
    v.append(bb(webbing, (0.11 * x, 0.115, 1.27), (0.045, 0.012, 0.36), "spine", 0.004))     # shoulder straps
    v.append(bb(webbing, (0.11 * x, -0.115, 1.27), (0.045, 0.012, 0.36), "spine", 0.004))
    v.append(bb(webbing, (0.11 * x, 0.0, 1.448), (0.05, 0.24, 0.012), "spine", 0.004))
piece("Look_VestHarness", v)
v = [bb(vest, (0, 0.13, 1.28), (0.33, 0.045, 0.3), "spine", 0.012),                      # the plate carrier
     bb(vest, (0, -0.13, 1.28), (0.33, 0.045, 0.3), "spine", 0.012),
     bb(webbing, (0, 0.166, 1.36), (0.14, 0.025, 0.06), "spine", 0.006)]                   # admin pouch
for x in (1, -1):
    v.append(bb(vest, (0.11 * x, 0.0, 1.44), (0.07, 0.27, 0.025), "spine", 0.006))
    v.append(bb(vest, (0.19 * x, 0.0, 1.2), (0.03, 0.24, 0.12), "spine", 0.006))           # cummerbund
for xx in (-0.075, 0.0, 0.075):
    v.append(bb(webbing, (xx, 0.168, 1.2), (0.065, 0.03, 0.1), "spine", 0.006))           # magazine pouches
    v.append(bb(webbing, (xx, 0.17, 1.245), (0.067, 0.033, 0.018), "spine", 0.004))
piece("Look_VestCarrier", v)
v = [bb(vest, (0, 0.14, 1.17), (0.32, 0.05, 0.13), "spine", 0.01)]                        # the chest rig
for xx in (-0.115, -0.04, 0.04, 0.115):
    v.append(bb(webbing, (xx, 0.172, 1.2), (0.06, 0.03, 0.1), "spine", 0.006))
for x in (1, -1):
    v.append(bb(webbing, (0.11 * x, 0.115, 1.33), (0.04, 0.012, 0.2), "spine", 0.004))
    v.append(bb(webbing, (0.11 * x, 0.0, 1.448), (0.045, 0.24, 0.012), "spine", 0.004))
    v.append(box(webbing, (0, -0.116, 1.3), (0.04, 0.012, 0.38), rot=(0, 0.6 * x, 0), group="spine"))   # X on the back
piece("Look_VestRig", v)

# ---- flag on the right shoulder (Game.FLAGS: layout + three colours set by the game) ----
F1, F2, F3 = mat("Flag1", (0.95, 0.95, 0.95)), mat("Flag2", (0.8, 0.1, 0.1)), mat("Flag3", (0.1, 0.25, 0.6))
FX, FZ, FW, FH, FT = -0.268, 1.33, 0.075, 0.05, 0.008       # (y: +front = the hoist)
FG = "upperarm.R"
def fb(m, y0, y1, z0, z1, t=FT):
    return box(m, (FX - (t - FT) / 2, (y0 + y1) / 2, FZ + (z0 + z1) / 2), (t, y1 - y0, z1 - z0), group=FG)
def fover(m, yc, zc, w, h, rot=0.0):
    """A shape laid over the flag (a cross, a disc ...)."""
    return box(m, (FX - 0.001, yc, FZ + zc), (FT + 0.0015, w, h), rot=(rot, 0, 0), group=FG)
def ftri(m, pts):
    """A flat triangle over the flag, pts = [(y, z), ...] relative to its centre."""
    me = bpy.data.meshes.new("tri")
    x0, x1 = FX - FT / 2 - 0.001, FX + FT / 2 + 0.0005
    vs = [(x0, y, FZ + z) for y, z in pts] + [(x1, y, FZ + z) for y, z in pts]
    me.from_pydata(vs, [], [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)])
    me.update()
    o = bpy.data.objects.new("tri", me)
    bpy.context.scene.collection.objects.link(o)
    bm = bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm, faces=bm.faces); bm.to_mesh(me); bm.free()
    me.materials.append(m)
    vg = o.vertex_groups.new(name=FG)
    vg.add(list(range(6)), 1.0, 'REPLACE')
    return o
W2, H2 = FW / 2, FH / 2
piece("Look_Flag_h2", [fb(F1, -W2, W2, 0, H2), fb(F2, -W2, W2, -H2, 0)])
piece("Look_Flag_h3", [fb(F1, -W2, W2, H2 / 3, H2), fb(F2, -W2, W2, -H2 / 3, H2 / 3), fb(F3, -W2, W2, -H2, -H2 / 3)])
piece("Look_Flag_v3", [fb(F1, W2 / 3, W2, -H2, H2), fb(F2, -W2 / 3, W2 / 3, -H2, H2), fb(F3, -W2, -W2 / 3, -H2, H2)])
piece("Look_Flag_cz", [fb(F1, -W2, W2, 0, H2), fb(F2, -W2, W2, -H2, 0), ftri(F3, [(W2, H2), (0.0, 0.0), (W2, -H2)])])
NY = W2 - FW * 0.36
piece("Look_Flag_nordic", [fb(F1, -W2, W2, -H2, H2), fover(F2, NY, 0, 0.011, FH), fover(F2, 0, 0, FW, 0.011)])
piece("Look_Flag_nordic3", [fb(F1, -W2, W2, -H2, H2), fover(F2, NY, 0, 0.016, FH), fover(F2, 0, 0, FW, 0.016),
                            box(F3, (FX - 0.0015, NY, FZ), (FT + 0.0025, 0.007, FH), group=FG),
                            box(F3, (FX - 0.0015, 0, FZ), (FT + 0.0025, FW, 0.007), group=FG)])
piece("Look_Flag_cross", [fb(F1, -W2, W2, -H2, H2), fover(F2, 0, 0, 0.011, FH), fover(F2, 0, 0, FW, 0.011)])
piece("Look_Flag_swiss", [fb(F1, -W2, W2, -H2, H2), fover(F2, 0, 0, 0.009, 0.032), fover(F2, 0, 0, 0.032, 0.009)])
piece("Look_Flag_jp", [fb(F1, -W2, W2, -H2, H2),
                       cyl(F2, (FX - 0.001, 0, FZ), 0.0135, FT + 0.0015, verts=12, rot=(0, math.pi / 2, 0), group=FG)])
us = []
for k in range(7):
    us.append(fb(F1 if k % 2 == 0 else F2, -W2, W2, H2 - (k + 1) * FH / 7, H2 - k * FH / 7))
us.append(box(F3, (FX - 0.001, W2 - 0.016, FZ + H2 - 0.0143), (FT + 0.0015, 0.032, 0.0286), group=FG))   # the canton
for iy in range(3):
    for iz in range(2):
        us.append(box(F2, (FX - 0.0015, W2 - 0.006 - iy * 0.01, FZ + H2 - 0.008 - iz * 0.012), (FT + 0.0025, 0.004, 0.004), group=FG))
piece("Look_Flag_us", us)
dang = math.atan2(FH, FW)
dlen = math.hypot(FW, FH) - 0.012
piece("Look_Flag_uk", [fb(F3, -W2, W2, -H2, H2),
                       fover(F1, 0, 0, dlen, 0.011, dang), fover(F1, 0, 0, dlen, 0.011, -dang),
                       box(F2, (FX - 0.0015, 0, FZ), (FT + 0.0025, dlen, 0.004), rot=(dang, 0, 0), group=FG),
                       box(F2, (FX - 0.0015, 0, FZ), (FT + 0.0025, dlen, 0.004), rot=(-dang, 0, 0), group=FG),
                       box(F1, (FX - 0.002, 0, FZ), (FT + 0.0035, 0.016, FH), group=FG), box(F1, (FX - 0.002, 0, FZ), (FT + 0.0035, FW, 0.016), group=FG),
                       box(F2, (FX - 0.0025, 0, FZ), (FT + 0.0045, 0.009, FH), group=FG), box(F2, (FX - 0.0025, 0, FZ), (FT + 0.0045, FW, 0.009), group=FG)])

# ---- face paint (Game.PAINTS): the colours follow the mission's camouflage ----
paint1 = mat("FacePaint", (0.08, 0.09, 0.06))
paint2 = mat("FacePaint2", (0.25, 0.3, 0.16))
FY = HF_FACE = 0.112
def fp(m, x0, x1, z0, z1, y=FY):
    return box(m, ((x0 + x1) / 2, y, (z0 + z1) / 2), (x1 - x0, 0.004, z1 - z0), group="head")
piece("Look_PaintEyes", [fp(paint1, 0.02, 0.066, 1.666, 1.678), fp(paint1, -0.066, -0.02, 1.666, 1.678)])
st = []
for x in (1, -1):
    for dz in (0.0, -0.024):
        st.append(box(paint1, (0.052 * x, FY, 1.648 + dz), (0.062, 0.004, 0.011), rot=(0, 0.45 * x, 0), group="head"))
    st.append(box(paint1, (0.091 * x, 0.04, 1.63), (0.004, 0.08, 0.011), rot=(0.45, 0, 0), group="head"))  # on to the side
piece("Look_PaintStripes", st)
piece("Look_PaintBand", [fp(paint1, -0.09, 0.09, 1.718, 1.734), fp(paint1, -0.09, 0.09, 1.664, 1.679),
                         fp(paint1, 0.064, 0.09, 1.679, 1.718), fp(paint1, -0.09, -0.064, 1.679, 1.718),
                         fp(paint1, -0.02, 0.02, 1.679, 1.718),
                         box(paint1, (0.091, 0.07, 1.699), (0.004, 0.08, 0.07), group="head"),
                         box(paint1, (-0.091, 0.07, 1.699), (0.004, 0.08, 0.07), group="head")])
piece("Look_PaintFull", [fp(paint2, -0.09, 0.09, 1.734, 1.775), fp(paint1, -0.05, 0.03, 1.745, 1.765, FY + 0.001),
                         fp(paint1, -0.09, 0.09, 1.664, 1.679), fp(paint1, 0.064, 0.09, 1.679, 1.718),
                         fp(paint1, -0.09, -0.064, 1.679, 1.718), fp(paint2, -0.02, 0.02, 1.679, 1.718),
                         fp(paint2, 0.02, 0.09, 1.595, 1.664), fp(paint2, -0.09, -0.02, 1.595, 1.664),
                         fp(paint1, 0.04, 0.075, 1.615, 1.645, FY + 0.001), fp(paint1, -0.07, -0.035, 1.6, 1.625, FY + 0.001),
                         box(paint2, (0.091, 0.05, 1.66), (0.004, 0.12, 0.12), group="head"),
                         box(paint2, (-0.091, 0.05, 1.66), (0.004, 0.12, 0.12), group="head"),
                         box(paint1, (0.0925, 0.06, 1.68), (0.004, 0.05, 0.03), group="head"),
                         box(paint1, (-0.0925, 0.03, 1.64), (0.004, 0.05, 0.03), group="head")])

# ---- tattoos (Game.TATTOOS) on the bare skin: a jacket covers them (they sit under the sleeve) ----
ink = mat("Tattoo", (0.07, 0.09, 0.14), rough=0.7)
PX = 0.0105
def pixels(art, x, zc, yc=0.0, group="forearm.R"):
    """Pixel art on the outer side of an arm (x = that surface), centred at (yc, zc)."""
    rows = art.strip("\n").split("\n")
    out = []
    for r, line in enumerate(rows):
        for c, ch in enumerate(line):
            if ch == "X":
                y = yc + (c - (len(line) - 1) / 2) * PX
                z = zc + ((len(rows) - 1) / 2 - r) * PX
                out.append(box(ink, (x, y, z), (0.003, PX, PX), group=group))
    return out
FO = -(0.235 + 0.0375 + 0.0012)          # the outer face of the right forearm (the gun arm in the game)
UO = -(0.215 + 0.0425 + 0.0012)
SKULL = """
.XXXXX.
XXXXXXX
X..X..X
XXXXXXX
XX.X.XX
.XXXXX.
.X.X.X.
"""
ANCHOR = """
...X...
..X.X..
...X...
.XXXXX.
...X...
...X...
X..X..X
.X.X.X.
..XXX..
"""
XMARK = """
X.....X
.X...X.
..X.X..
...X...
..X.X..
.X...X.
X.....X
"""
FLAME = """
..X....
..XX...
.XXX..X
.XXXX.X
XXXXXXX
XX.XXXX
.X..XX.
"""
def band(x, zc, group, w, d, h=0.008):
    return box(ink, (x, 0, zc), (w, d, h), group=group)
piece("Look_TatSkull", pixels(SKULL, FO, 1.03))
piece("Look_TatAnchor", pixels(ANCHOR, FO, 1.02))
piece("Look_TatX", pixels(XMARK, FO, 1.03))
tribal = [band(-0.235, 0.98, "forearm.R", 0.078, 0.088), band(-0.235, 1.08, "forearm.R", 0.078, 0.088, 0.006)]
tribal += pixels("X.X.X.X\n.X.X.X.", FO, 1.0) + pixels(".X.X.X.\nX.X.X.X", FO, 1.06)
piece("Look_TatTribal", tribal)
sl = [band(-0.235, 0.98, "forearm.R", 0.078, 0.088), band(-0.215, 1.18, "upperarm.R", 0.088, 0.098, 0.01)]
sl += pixels(FLAME, FO, 1.05) + pixels(SKULL, UO, 1.24, group="upperarm.R") + pixels("X.X.X.X.\n.X.X.X.X", UO, 1.32, group="upperarm.R")
sl += [band(0.235, 1.0, "forearm.L", 0.078, 0.088, 0.006)] + pixels(XMARK, -FO, 1.06, group="forearm.L")
piece("Look_TatSleeve", sl)

# ---- glasses, things round the neck and in the mouth (Game.GLASSES, NECKS, MOUTHS) ----
shades = mat("Shades", (0.025, 0.025, 0.03), rough=0.15)
amber = mat("LensAmber", (0.75, 0.5, 0.1), rough=0.15)
def temples():
    return [box(shades, (0.093 * x, 0.05, 1.698), (0.006, 0.13, 0.006), group="head") for x in (1, -1)]
piece("Look_GlassShades", [box(shades, (0.042, 0.117, 1.692), (0.05, 0.006, 0.028), group="head"),
                           box(shades, (-0.042, 0.117, 1.692), (0.05, 0.006, 0.028), group="head"),
                           box(shades, (0, 0.117, 1.699), (0.036, 0.006, 0.006), group="head")] + temples())
piece("Look_GlassBallistic", [box(amber, (0, 0.118, 1.692), (0.176, 0.006, 0.032), group="head"),
                              box(shades, (0, 0.119, 1.71), (0.18, 0.008, 0.007), group="head")] + temples())
scarf = mat("Scarf", (0.36, 0.33, 0.25))
scarf2 = mat("ScarfLine", (0.06, 0.06, 0.05))
piece("Look_NeckShemagh", [bb(scarf, (0, 0.01, 1.47), (0.17, 0.165, 0.07), "spine", 0.02),
                           box(scarf, (0, 0.098, 1.42), (0.09, 0.02, 0.07), rot=(0.25, 0, 0), group="spine"),
                           box(scarf2, (0, 0.0, 1.47), (0.172, 0.167, 0.008), group="spine")])
piece("Look_NeckMask", [box(scarf, (0, 0.04, 1.595), (0.2, 0.172, 0.12), group="head"),
                        box(scarf2, (0, 0.04, 1.62), (0.202, 0.174, 0.008), group="head"),
                        bb(scarf, (0, 0.005, 1.49), (0.15, 0.15, 0.08), "neck", 0.015)])
tag = mat("DogTag", (0.6, 0.6, 0.62), rough=0.35)
piece("Look_NeckTags", [box(tag, (0.035, 0.08, 1.43), (0.003, 0.06, 0.003), rot=(-0.6, 0, -0.5), group="spine"),
                        box(tag, (-0.035, 0.08, 1.43), (0.003, 0.06, 0.003), rot=(-0.6, 0, 0.5), group="spine"),
                        box(tag, (0, 0.116, 1.37), (0.02, 0.004, 0.032), group="spine"),
                        box(tag, (0.008, 0.119, 1.362), (0.02, 0.004, 0.032), rot=(0, 0.2, 0), group="spine")])
cigar = mat("Cigar", (0.3, 0.17, 0.08))
ember = mat("Ember", (1.0, 0.35, 0.05), emit=2.0)
piece("Look_MouthCigar", [cyl(cigar, (0.03, 0.135, 1.577), 0.007, 0.06, verts=6, rot=(math.pi / 2, 0, -0.3), group="head"),
                          cyl(ember, (0.0395, 0.1655, 1.577), 0.0072, 0.004, verts=6, rot=(math.pi / 2, 0, -0.3), group="head")])
piece("Look_MouthMatch", [box(mat("Match", (0.8, 0.7, 0.45)), (0.024, 0.13, 1.577), (0.003, 0.05, 0.003), rot=(0, 0, -0.35), group="head"),
                          box(mat("MatchHead", (0.6, 0.1, 0.05)), (0.0325, 0.153, 1.577), (0.005, 0.006, 0.005), rot=(0, 0, -0.35), group="head")])
# ---- looks: hair, beards, female face details (shown / hidden by the game) ----
def hp(name, parts):
    piece(name, parts)
TOP = 1.775
# the head block: x +-0.09, y -0.09 (back) .. 0.11 (face), z 1.545 .. 1.775.
# Hair and beards are shells that sit flush on it (no floating slabs).
HX, HB, HF, HZ0 = 0.09, -0.09, 0.11, 1.545
def bx(m, x0, x1, y0, y1, z0, z1):
    return box(m, ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), (x1 - x0, y1 - y0, z1 - z0), group="head")

def shell(t, side_z, back_z, fringe_z, temple_y=0.06):
    """Hair hugging the skull: crown, both sides above the ears, back, hairline."""
    return [bx(hairm, -HX - t, HX + t, HB - t, HF + 0.004, TOP - 0.004, TOP + t),        # crown
            bx(hairm, HX - 0.002, HX + t, HB - t, temple_y, side_z, TOP),                 # right side
            bx(hairm, -HX - t, -HX + 0.002, HB - t, temple_y, side_z, TOP),               # left side
            bx(hairm, -HX - t, HX + t, HB - t, HB + 0.002, back_z, TOP),                  # back
            bx(hairm, -HX, HX, HF - 0.002, HF + 0.006, fringe_z, TOP)]                    # hairline

hp("Look_HairBuzz", shell(0.006, 1.69, 1.6, 1.758))
hp("Look_HairShort", shell(0.016, 1.665, 1.585, 1.742) +
   [bx(hairm, -0.07, 0.09, HF, HF + 0.022, 1.738, TOP + 0.012)])                         # side-swept fringe
hp("Look_HairLong", shell(0.018, 1.62, 1.58, 1.745) +
   [bx(hairm, -HX - 0.022, HX + 0.022, HB - 0.03, HB + 0.004, 1.44, TOP),                # long at the back
    bx(hairm, HX - 0.002, HX + 0.022, HB, 0.085, 1.5, 1.66),                              # framing the face
    bx(hairm, -HX - 0.022, -HX + 0.002, HB, 0.085, 1.5, 1.66),
    bx(hairm, -0.08, 0.08, HF, HF + 0.016, 1.735, TOP + 0.01)])
hp("Look_HairPony", shell(0.014, 1.66, 1.6, 1.748) +
   [bx(hairm, -0.035, 0.035, HB - 0.05, HB - 0.012, 1.69, 1.745),                          # tie
    cyl(hairm, (0, -0.145, 1.6), 0.03, 0.2, verts=6, r2=0.012, rot=(-0.3, 0, 0), group="head")])
hp("Look_HairMohawk", shell(0.004, 1.7, 1.62, 1.765) +
   [bx(hairm, -0.022, 0.022, HB - 0.01, HF - 0.01, TOP, TOP + 0.075),
    bx(hairm, -0.022, 0.022, HB - 0.03, HB, 1.66, TOP + 0.05)])
hp("Look_HairBun", shell(0.014, 1.66, 1.6, 1.748) +
   [sphere(hairm, (0, -0.125, 1.75), 0.05, seg=8, rings=6, group="head")])
# beards: on the jaw (male jaw is the head width, a bit deeper at the chin)
hp("Look_Stubble", [bx(beardm, -0.075, 0.075, HF, HF + 0.006, 1.535, 1.585),
                    bx(beardm, HX - 0.002, HX + 0.005, -0.02, HF, 1.54, 1.635),
                    bx(beardm, -HX - 0.005, -HX + 0.002, -0.02, HF, 1.54, 1.635),
                    bx(beardm, -0.08, 0.08, -0.03, HF, 1.532, 1.54)])
hp("Look_Moustache", [bx(beardm, -0.045, 0.045, HF, HF + 0.016, 1.58, 1.594)])
hp("Look_Goatee", [bx(beardm, -0.04, 0.04, HF, HF + 0.016, 1.58, 1.594),
                   bx(beardm, -0.03, 0.03, HF, HF + 0.018, 1.52, 1.575)])
hp("Look_BeardFull", [bx(beardm, -HX - 0.01, HX + 0.01, -0.02, HF + 0.02, 1.515, 1.585),     # jaw and chin
                      bx(beardm, HX - 0.002, HX + 0.012, -0.03, HF, 1.585, 1.665),          # sideburns
                      bx(beardm, -HX - 0.012, -HX + 0.002, -0.03, HF, 1.585, 1.665),
                      bx(beardm, -0.05, 0.05, HF, HF + 0.02, 1.578, 1.596),                 # moustache
                      bx(beardm, -0.075, -0.045, HF, HF + 0.018, 1.585, 1.6),
                      bx(beardm, 0.045, 0.075, HF, HF + 0.018, 1.585, 1.6)])
hp("Look_Female", [box(lips, (0, 0.112, 1.574), (0.052, 0.008, 0.013), group="head"),
                   box(boots, (0.042 * 1, 0.111, 1.7), (0.044, 0.006, 0.006), group="head"),
                   box(boots, (-0.042, 0.111, 1.7), (0.044, 0.006, 0.006), group="head")])
hp("Look_Jaw", [box(skin, (0, 0.04, 1.562), (0.174, 0.16, 0.045), group="head"),   # male: a heavier jaw
                box(lips, (0, 0.1115, 1.576), (0.05, 0.006, 0.008), group="head")])  # and a thin mouth
# headgear variants
# a dome that sits ON the head (over the hair), its rim above the brows so the eyes show
hm = [sphere(helmet, (0, 0.005, 1.772), 0.132, seg=16, rings=10, scale=(1.18, 1.25, 0.78), group="head"),
      bb(helmet, (0, 0.005, 1.747), (0.318, 0.336, 0.03), "head", 0.012),               # the brim
      bb(metal, (0, 0.148, 1.79), (0.05, 0.02, 0.04), "head", 0.006),                    # the night-vision mount
      box(idlight, (0.09, 0.15, 1.765), (0.04, 0.006, 0.01), group="head"),             # the ID light
      bb(helmet, (0, -0.02, 1.86), (0.06, 0.12, 0.012), "head", 0.004)]                 # the ridge
for x in (1, -1):
    hm.append(box(webbing, (0.094 * x, 0.02, 1.62), (0.008, 0.018, 0.13), group="head"))    # chin strap
    hm.append(box(webbing, (0.06 * x, 0.09, 1.54), (0.07, 0.016, 0.012), rot=(0, 0, 0.5 * x), group="head"))
    hm.append(bb(metal, (0.152 * x, -0.01, 1.77), (0.016, 0.06, 0.04), "head", 0.004))    # comms ear cups
piece("Gear_Helmet", hm)
cap = [box(cloth, (0, 0.005, 1.797), (0.232, 0.252, 0.078), group="head"),
       box(cloth, (0, 0.158, 1.766), (0.2, 0.11, 0.02), group="head")]
piece("Gear_Cap", cap)
# 0.57 facelift: more on the head (Game.HEADGEAR 3..6): the beret, a bush hat, a bandana, a headset
beret = mat("Beret", (0.16, 0.25, 0.12), rough=0.95)          # recoloured in game (Game.BERET_COLORS)
leather = mat("Leather", (0.09, 0.06, 0.04), rough=0.6)
gold = mat("Gold", (0.8, 0.62, 0.2), rough=0.35)
br = [sphere(beret, (0.02, -0.005, 1.792), 0.13, seg=14, rings=8, scale=(1.2, 1.2, 0.42), rot=(0, 0.2, 0), group="head"),
      bb(leather, (0, 0.008, 1.762), (0.236, 0.266, 0.026), "head", 0.006),             # the leather band (over the hair)
      box(leather, (0, -0.127, 1.758), (0.006, 0.004, 0.03), group="head"),            # the ribbon at the back
      box(mat("BadgeBack", (0.12, 0.12, 0.1)), (-0.05, 0.143, 1.768), (0.032, 0.004, 0.036), group="head")]
for r in (0.75, -0.75):                                                               # the X badge
    br.append(box(gold, (-0.05, 0.146, 1.768), (0.006, 0.004, 0.032), rot=(0, r, 0), group="head"))
piece("Gear_Beret", br)
bh = [bb(cloth, (0, 0.005, 1.812), (0.218, 0.238, 0.075), "head", 0.015),
      box(cloth, (0, 0.005, 1.771), (0.34, 0.36, 0.012), group="head"),
      box(webbing, (0, 0.005, 1.786), (0.222, 0.242, 0.016), group="head")]
for x in (1, -1):
    bh.append(box(webbing, (0.112 * x, 0.0, 1.69), (0.004, 0.006, 0.15), rot=(0.25, 0, 0), group="head"))   # chin cord
piece("Gear_Boonie", bh)
bandana = mat("Bandana", (0.16, 0.25, 0.12), rough=0.95)      # same colours as the beret
piece("Gear_Bandana", [box(bandana, (0, -0.004, 1.766), (0.228, 0.24, 0.062), group="head"),
                       box(bandana, (0, -0.004, 1.799), (0.21, 0.222, 0.01), group="head"),
                       box(bandana, (0.012, -0.132, 1.745), (0.03, 0.02, 0.03), group="head"),        # the knot
                       box(bandana, (0.02, -0.14, 1.7), (0.028, 0.008, 0.07), rot=(0.25, 0.2, 0), group="head"),
                       box(bandana, (-0.005, -0.138, 1.705), (0.026, 0.008, 0.06), rot=(0.2, -0.25, 0), group="head")])
hs = [box(webbing, (0, -0.005, 1.8), (0.22, 0.026, 0.012), group="head")]
for x in (1, -1):
    hs.append(box(webbing, (0.11 * x, -0.005, 1.76), (0.012, 0.026, 0.08), group="head"))
    hs.append(bb(metal, (0.118 * x, -0.005, 1.68), (0.026, 0.065, 0.075), "head", 0.008))   # ear cups
hs.append(box(metal, (0.115, 0.055, 1.63), (0.008, 0.11, 0.008), rot=(0.45, 0, 0.2), group="head"))   # the microphone
hs.append(box(webbing, (0.1, 0.108, 1.603), (0.014, 0.016, 0.014), group="head"))
piece("Gear_Headset", hs)
# helmet torch (on the left side)
piece("Gear_Torch", [cyl(metal, (0.138, 0.05, 1.765), 0.022, 0.12, verts=6, rot=(math.pi / 2, 0, 0), group="head"),
                     cyl(lens, (0.138, 0.112, 1.765), 0.02, 0.005, verts=6, rot=(math.pi / 2, 0, 0), group="head")])
# belt pouches b0..b3
for i, xx in enumerate((0.12, 0.04, -0.04, -0.12)):
    piece("Gear_Belt%d" % i, [bb(webbing, (xx, 0.125, 0.965), (0.07, 0.055, 0.095), "hips", 0.01),
                              bb(webbing, (xx, 0.128, 1.012), (0.074, 0.06, 0.02), "hips", 0.006)])     # the flap
# backpack (any backpack slot used)
bp = [bb(webbing, (0, -0.2, 1.22), (0.32, 0.17, 0.38), "spine", 0.04),
      bb(vest, (0, -0.3, 1.16), (0.26, 0.05, 0.22), "spine", 0.02),
      bb(webbing, (0, -0.19, 1.45), (0.3, 0.12, 0.07), "spine", 0.02)]
for x in (1, -1):
    bp.append(bb(vest, (0.18 * x, -0.2, 1.18), (0.05, 0.12, 0.2), "spine", 0.015))            # side pouches
for r in (0.7, -0.7):                                                                       # the X
    bp.append(box(mat("BackX", (0.75, 0.75, 0.7)), (0, -0.327, 1.16), (0.035, 0.006, 0.19), rot=(0, r, 0), group="spine"))
piece("Gear_Backpack", bp)
# items that show on the vest
piece("Gear_Grenade", [sphere(olive, (0.13, 0.15, 1.33), 0.04, seg=6, rings=4, group="spine"),
                       box(metal, (0.13, 0.15, 1.38), (0.02, 0.02, 0.03), group="spine")])
piece("Gear_Flare", [cyl(flare, (-0.13, 0.15, 1.3), 0.018, 0.13, verts=6, group="spine")])
piece("Gear_Medkit", [box(medred, (-0.14, -0.13, 1.05), (0.12, 0.08, 0.1), group="hips"),
                      box(mat("White", (0.9, 0.9, 0.9)), (-0.14, -0.172, 1.05), (0.05, 0.005, 0.015), group="hips"),
                      box(mat("White", (0.9, 0.9, 0.9)), (-0.14, -0.172, 1.05), (0.015, 0.005, 0.05), group="hips")])
piece("Gear_Holster", [box(webbing, (-0.2, 0.0, 0.88), (0.05, 0.12, 0.16), group="thigh.R"),
                       box(metal, (-0.2, 0.02, 0.97), (0.03, 0.05, 0.04), group="thigh.R")])
# armour from research: a ballistic vest, then plates of alien alloy
gv = [bb(plate, (0, 0.13, 1.28), (0.34, 0.06, 0.32), "spine", 0.035),                 # the chest plate
      bb(plate, (0, 0.145, 1.4), (0.26, 0.05, 0.08), "spine", 0.02),
      bb(plate, (0, -0.13, 1.28), (0.34, 0.05, 0.32), "spine", 0.03),                   # back plate
      box(idlight, (0.02, 0.164, 1.31), (0.2, 0.006, 0.014), group="spine"),             # the ID light strip
      box(idred, (-0.1, 0.164, 1.31), (0.01, 0.006, 0.06), group="spine"),
      bb(metal, (0.12, 0.164, 1.31), (0.035, 0.008, 0.035), "spine", 0.006)]
for x, sd in ((1, "L"), (-1, "R")):
    gv.append(bb(plate, (0.25 * x, 0, 1.43), (0.13, 0.17, 0.08), "upperarm." + sd, 0.025))   # shoulder plates
    gv.append(bb(plate, (0.255 * x, 0, 1.37), (0.11, 0.15, 0.06), "upperarm." + sd, 0.02))
piece("Gear_Vest", gv)
alloy = mat("Alloy", (0.24, 0.23, 0.3), rough=0.3)
seam = mat("AlloyGlow", (0.3, 0.9, 0.8), emit=2.5)
piece("Gear_Plate", [box(alloy, (0, 0.13, 1.3), (0.4, 0.07, 0.36), group="spine"),
                     box(alloy, (0, -0.14, 1.3), (0.38, 0.06, 0.36), group="spine"),
                     box(seam, (0, 0.168, 1.31), (0.26, 0.006, 0.02), group="spine"),
                     box(alloy, (0, 0.12, 1.07), (0.32, 0.06, 0.15), group="hips"),
                     box(alloy, (0.25, 0, 1.43), (0.14, 0.17, 0.1), group="upperarm.L"),
                     box(alloy, (-0.25, 0, 1.43), (0.14, 0.17, 0.1), group="upperarm.R"),
                     box(alloy, (0.1, 0.09, 0.72), (0.12, 0.05, 0.2), group="thigh.L"),
                     box(alloy, (-0.1, 0.09, 0.72), (0.12, 0.05, 0.2), group="thigh.R")])
piece("Gear_Scanner", [box(scan, (0.25, 0.08, 0.82), (0.05, 0.14, 0.09), group="hand.L"),
                       box(screen, (0.25, 0.1, 0.87), (0.04, 0.08, 0.005), group="hand.L")])

# ---- animations --------------------------------------------------------------------
pb = rig.pose.bones
for b in pb:
    b.rotation_mode = 'XYZ'
# limbs (pointing down): +X swings forward. spine/neck/head (pointing up): -X leans forward.
HOLD = {"upperarm.R": (0.5, 0, -0.25), "forearm.R": (1.3, 0, 0), "upperarm.L": (0.95, 0, 0.45), "forearm.L": (0.75, 0, 0)}

def pose(frame, rots, drop=0.0):
    for b in pb:
        b.rotation_euler = (0, 0, 0)
        b.location = (0, 0, 0)
    for name, r in rots.items():
        pb[name].rotation_euler = r
    pb["root"].location = (0, drop, 0)
    for b in pb:
        b.keyframe_insert("rotation_euler", frame=frame)
        b.keyframe_insert("location", frame=frame)

def action(name, frames):
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = act
    for f, rots, d in frames:
        pose(f, rots, d)
    rig.animation_data.action = None

def walk(n, amp, bob, crouch=False):
    out = []
    for i in range(5):
        f = 1 + i * n // 4
        ph = i / 4 * 2 * math.pi
        sw = math.sin(ph)
        r = dict(HOLD)
        base_t = 0.9 if crouch else 0.0
        base_s = -1.3 if crouch else 0.0
        r.update({"thigh.L": (base_t - sw * amp, 0, 0), "thigh.R": (base_t + sw * amp, 0, 0),
                  "shin.L": (base_s - max(0, -sw) * amp * 1.3, 0, 0), "shin.R": (base_s - max(0, sw) * amp * 1.3, 0, 0),
                  "spine": (-0.35 if crouch else -0.06, 0, sw * 0.05), "head": (0.25 if crouch else 0.04, 0, 0)})
        out.append((f, r, (-0.38 if crouch else 0.0) - abs(math.cos(ph)) * bob))
    return out

idle = dict(HOLD, spine=(-0.03, 0, 0))
action("idle", [(1, idle, 0), (25, dict(idle, spine=(-0.05, 0, 0.03), head=(0.04, 0, 0.1)), -0.005), (49, idle, 0)])
action("walk", walk(30, 0.45, 0.03))
action("run", walk(18, 0.8, 0.06))
crouch = dict(HOLD, **{"thigh.L": (1.3, 0, 0.1), "thigh.R": (0.6, 0, -0.1), "shin.L": (-1.5, 0, 0), "shin.R": (-2.0, 0, 0),
                       "spine": (-0.3, 0, 0), "head": (0.25, 0, 0)})
action("crouch", [(1, crouch, -0.42), (25, dict(crouch, spine=(-0.33, 0, 0)), -0.43), (49, crouch, -0.42)])
action("crouch_walk", walk(36, 0.3, 0.02, crouch=True))
# downed: lying on the back, root rotated by the game; here limbs splay, slow breathing
down = {"thigh.L": (0.1, 0, 0.2), "thigh.R": (0.3, 0, -0.15), "shin.R": (-0.4, 0, 0),
        "upperarm.L": (0.2, 0, 0.6), "upperarm.R": (1.2, 0, -0.3), "forearm.R": (0.9, 0, 0), "head": (0.0, 0, 0.5)}
action("downed", [(1, down, 0), (30, dict(down, spine=(0.04, 0, 0)), 0), (60, down, 0)])
# wounded: on hands and knees, crawling slowly forward (the game keeps the model upright)
ALL4 = {"spine": (-1.4, 0, 0), "head": (1.1, 0, 0), "thigh.L": (0.15, 0, 0.05), "thigh.R": (0.15, 0, -0.05),
        "shin.L": (-1.6, 0, 0), "shin.R": (-1.6, 0, 0), "upperarm.L": (1.45, 0, 0.12), "upperarm.R": (1.45, 0, -0.12),
        "forearm.L": (0.15, 0, 0), "forearm.R": (0.15, 0, 0)}
def crawl_frames(n):
    out = []
    for i in range(5):
        f = 1 + i * n // 4
        sw = math.sin(i / 4 * 2 * math.pi)
        r = dict(ALL4)
        r.update({"thigh.L": (0.15 + sw * 0.28, 0, 0.05), "thigh.R": (0.15 - sw * 0.28, 0, -0.05),
                  "upperarm.L": (1.45 - sw * 0.28, 0, 0.12), "upperarm.R": (1.45 + sw * 0.28, 0, -0.12),
                  "spine": (-1.4, 0, sw * 0.06), "head": (1.1, 0, -sw * 0.08)})
        out.append((f, r, -0.47))
    return out
action("crawl_hurt", crawl_frames(48))
action("crawl_idle", [(1, ALL4, -0.47), (30, dict(ALL4, spine=(-1.2, 0, 0.03), head=(0.85, 0, 0.15)), -0.49), (60, ALL4, -0.47)])
# dead: on the back, limbs loose and close to the body (the game lays the model down)
DEAD = {"upperarm.L": (0.1, 0, 0.12), "upperarm.R": (0.1, 0, -0.12), "forearm.L": (0.35, 0, 0), "forearm.R": (0.2, 0, 0),
        "thigh.L": (0.05, 0, 0.08), "thigh.R": (0.35, 0, -0.12), "shin.R": (-0.6, 0, 0), "head": (0.1, 0, 0.7)}
action("dead", [(1, DEAD, 0), (10, DEAD, 0)])

# sprint: weapon carried diagonally across the chest, arms pumping a little
PORT = {"upperarm.R": (0.25, 0, -0.35), "forearm.R": (1.7, 0, 0.3), "upperarm.L": (0.55, 0, 0.5), "forearm.L": (1.2, 0, 0)}
def sprint_frames(n):
    out = []
    for i in range(5):
        f = 1 + i * n // 4
        ph = i / 4 * 2 * math.pi
        sw = math.sin(ph)
        r = dict(PORT)
        r.update({"thigh.L": (-sw * 0.95, 0, 0), "thigh.R": (sw * 0.95, 0, 0),
                  "shin.L": (-max(0, -sw) * 1.4, 0, 0), "shin.R": (-max(0, sw) * 1.4, 0, 0),
                  "spine": (-0.18, 0, sw * 0.1), "upperarm.R": (0.25 + sw * 0.15, 0, -0.35), "upperarm.L": (0.55 - sw * 0.15, 0, 0.5)})
        out.append((f, r, -abs(math.cos(ph)) * 0.07))
    return out
action("sprint", sprint_frames(16))
# prone: authored standing, the game tips the model 90 degrees forward.
# arms stretched "up" = forward along the ground, holding the weapon
PRONE = {"upperarm.R": (2.7, 0, -0.2), "forearm.R": (0.3, 0, 0), "upperarm.L": (2.9, 0, 0.25), "forearm.L": (0.2, 0, 0),
         "head": (0.9, 0, 0), "neck": (0.3, 0, 0), "thigh.L": (0, 0, 0.12), "thigh.R": (0, 0, -0.12)}
action("prone", [(1, PRONE, 0), (30, dict(PRONE, spine=(0.03, 0, 0)), 0), (60, PRONE, 0)])
crawl = []
for i in range(5):
    f = 1 + i * 40 // 4
    sw = math.sin(i / 4 * 2 * math.pi)
    r = dict(PRONE)
    r.update({"thigh.L": (0, 0, 0.12 + max(0, sw) * 0.6), "shin.L": (-max(0, sw) * 1.2, 0, 0),
              "thigh.R": (0, 0, -0.12 - max(0, -sw) * 0.6), "shin.R": (-max(0, -sw) * 1.2, 0, 0),
              "upperarm.L": (2.9 - sw * 0.3, 0, 0.25), "upperarm.R": (2.7 + sw * 0.3, 0, -0.2), "spine": (0, 0, sw * 0.08)})
    crawl.append((f, r, 0))
action("prone_crawl", crawl)

if "--preview" in sys.argv:
    i = sys.argv.index("--preview")
    rig.animation_data.action = bpy.data.actions[sys.argv[i + 1]]
    bpy.context.scene.frame_set(int(sys.argv[i + 2]))
    for o in meshes:
        if o.name == "Gear_Cap":
            o.hide_render = True
        if "--kit" in sys.argv and (o.name.startswith("Look_") and o.name not in ("Look_HairBuzz", "Look_Jaw") or o.name in ("Gear_Plate", "Gear_Scanner", "Gear_Flare", "Gear_Grenade")):
            o.hide_render = True
    if "--show" in sys.argv:
        want = sys.argv[sys.argv.index("--show") + 1].split(",")
        for o in meshes:
            if o.name.startswith("Look_") or o.name.startswith("Gear_"):
                o.hide_render = o.name not in want
    if "--face" in sys.argv:
        preview(sys.argv[i + 3], target=(0, 0, 1.66), dist=0.8, angle=float(sys.argv[i + 4]), height=0.0, res=(420, 420))
    elif "--head" in sys.argv:
        for o in meshes:
            if o.name.startswith("Look_") and o.name not in sys.argv[sys.argv.index("--head") + 1].split(","):
                o.hide_render = True
            if o.name in ("Gear_Cap", "Gear_Helmet"):
                o.hide_render = o.name != sys.argv[sys.argv.index("--head") + 2]
        preview(sys.argv[i + 3], target=(0, 0, 1.68), dist=0.75, angle=float(sys.argv[i + 4]), height=0.05)
    elif "--show" in sys.argv:
        preview(sys.argv[i + 3], target=(0, 0, 1.05), dist=2.4, angle=float(sys.argv[i + 4]), height=0.1, res=(400, 600))
    else:
        preview(sys.argv[i + 3], target=(0, 0, 1.0), dist=2.6 if "--kit" in sys.argv else 3.4, angle=float(sys.argv[i + 4]), height=0.25, res=(420, 560) if "--kit" in sys.argv else (480, 480))
else:
    export_glb(OUT, [rig] + meshes, animations=True)
