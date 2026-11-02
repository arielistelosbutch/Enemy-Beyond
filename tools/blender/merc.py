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
body = []
body.append(box(cloth, (0, 0, 1.24), (0.38, 0.22, 0.38), group="spine"))           # torso
body.append(box(cloth, (0, 0, 1.0), (0.34, 0.2, 0.16), group="hips"))
body.append(cyl(skin, (0, 0, 1.49), 0.055, 0.1, verts=6, group="neck"))
body.append(box(skin, (0, 0.01, 1.66), (0.18, 0.2, 0.23), group="head"))           # head
body.append(box(skin, (0, 0.11, 1.62), (0.04, 0.03, 0.05), group="head"))          # nose
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
    body.append(box(cloth, (0.215 * x, 0, 1.28), (0.1, 0.11, 0.26), group="upperarm." + s))
    body.append(box(cloth, (0.235 * x, 0, 1.01), (0.085, 0.095, 0.25), group="forearm." + s))
    body.append(box(glove, (0.24 * x, 0.01, 0.83), (0.07, 0.08, 0.1), group="hand." + s))
    body.append(box(cloth, (0.1 * x, 0, 0.74), (0.14, 0.15, 0.42), group="thigh." + s))
    body.append(box(cloth, (0.1 * x, 0, 0.33), (0.12, 0.13, 0.36), group="shin." + s))
    body.append(box(webbing, (0.1 * x, 0.07, 0.52), (0.11, 0.04, 0.1), group="shin." + s))   # knee pad
    body.append(box(boots, (0.1 * x, 0.04, 0.07), (0.12, 0.25, 0.14), group="shin." + s))
    body.append(box(patch, (0.265 * x, 0, 1.33), (0.01, 0.06, 0.06), group="upperarm." + s))
piece("Body", body)
# plate carrier with mag pouches (always worn)
v = [box(vest, (0, 0.005, 1.25), (0.41, 0.25, 0.32), group="spine"),
     box(webbing, (0, 0.13, 1.17), (0.32, 0.03, 0.1), group="spine")]
piece("Vest", v)
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
hp("Look_Female", [box(lips, (0, 0.112, 1.597), (0.05, 0.008, 0.012), group="head"),
                   box(boots, (0.042 * 1, 0.111, 1.7), (0.044, 0.006, 0.006), group="head"),
                   box(boots, (-0.042, 0.111, 1.7), (0.044, 0.006, 0.006), group="head")])
hp("Look_Jaw", [box(skin, (0, 0.04, 1.562), (0.174, 0.16, 0.045), group="head")])   # male: a heavier jaw
# headgear variants
hm = [sphere(helmet, (0, 0.0, 1.73), 0.13, seg=8, rings=5, scale=(1.05, 1.15, 0.85), group="head"),
      box(helmet, (0, 0.0, 1.69), (0.25, 0.26, 0.04), group="head"),
      box(metal, (0, 0.13, 1.79), (0.05, 0.03, 0.04), group="head")]
piece("Gear_Helmet", hm)
cap = [box(cloth, (0, 0.0, 1.79), (0.2, 0.22, 0.07), group="head"),
       box(cloth, (0, 0.14, 1.765), (0.18, 0.1, 0.02), group="head")]
piece("Gear_Cap", cap)
# helmet torch (on the left side)
piece("Gear_Torch", [cyl(metal, (0.12, 0.05, 1.74), 0.022, 0.12, verts=6, rot=(math.pi / 2, 0, 0), group="head"),
                     cyl(lens, (0.12, 0.112, 1.74), 0.02, 0.005, verts=6, rot=(math.pi / 2, 0, 0), group="head")])
# belt pouches b0..b3
for i, xx in enumerate((0.12, 0.04, -0.04, -0.12)):
    piece("Gear_Belt%d" % i, [box(webbing, (xx, 0.12, 0.97), (0.07, 0.05, 0.09), group="hips")])
# backpack (any backpack slot used)
piece("Gear_Backpack", [box(webbing, (0, -0.2, 1.22), (0.32, 0.17, 0.38), group="spine"),
                        box(vest, (0, -0.3, 1.17), (0.26, 0.05, 0.22), group="spine"),
                        box(webbing, (0, -0.19, 1.45), (0.3, 0.12, 0.07), group="spine")])
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
piece("Gear_Vest", [box(mat("Kevlar", (0.2, 0.22, 0.18)), (0, 0.115, 1.27), (0.36, 0.06, 0.34), group="spine"),
                    box(mat("Kevlar", (0.2, 0.22, 0.18)), (0, -0.125, 1.27), (0.36, 0.05, 0.34), group="spine"),
                    box(webbing, (0.12, 0, 1.45), (0.07, 0.26, 0.04), group="spine"),
                    box(webbing, (-0.12, 0, 1.45), (0.07, 0.26, 0.04), group="spine"),
                    box(webbing, (0, 0.15, 1.2), (0.3, 0.02, 0.05), group="spine")])
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
    preview(sys.argv[i + 3], target=(0, 0, 1.0), dist=3.4, angle=float(sys.argv[i + 4]))
else:
    export_glb(OUT, [rig] + meshes, animations=True)
