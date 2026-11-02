"""Mercenary weapons: assault rifle and pistol. Own designs (not X-COM's).
Muzzle points +Y in Blender (-Z in Godot). Origin = where the right hand holds the grip."""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from common import *

OUTDIR = sys.argv[-1]
steel = None

def mats():
    global steel, dark, poly, wood, sight, brass
    steel = mat("Steel", (0.20, 0.21, 0.22), rough=0.45)
    dark = mat("Blackened", (0.06, 0.06, 0.065), rough=0.6)
    poly = mat("Polymer", (0.13, 0.14, 0.12), rough=0.85)
    wood = mat("Wood", (0.30, 0.17, 0.08), rough=0.8)
    sight = mat("SightDot", (1.0, 0.25, 0.1), emit=3.0)
    brass = mat("Brass", (0.55, 0.42, 0.18), rough=0.4)

def rifle():
    reset(); mats()
    p = []
    # receiver and barrel shroud
    p.append(box(steel, (0, 0.10, 0.035), (0.055, 0.34, 0.075)))
    p.append(box(dark, (0, 0.10, 0.08), (0.04, 0.30, 0.02)))           # top rail
    for i in range(7):
        p.append(box(steel, (0, -0.02 + i * 0.04, 0.093), (0.045, 0.012, 0.008)))
    p.append(cyl(poly, (0, 0.38, 0.03), 0.026, 0.24, verts=8, rot=(math.pi / 2, 0, 0)))  # handguard
    for i in range(4):
        p.append(box(dark, (0.027, 0.30 + i * 0.05, 0.03), (0.004, 0.025, 0.012)))
        p.append(box(dark, (-0.027, 0.30 + i * 0.05, 0.03), (0.004, 0.025, 0.012)))
    p.append(cyl(dark, (0, 0.58, 0.035), 0.011, 0.22, verts=6, rot=(math.pi / 2, 0, 0)))   # barrel
    p.append(cyl(steel, (0, 0.70, 0.035), 0.017, 0.05, verts=6, rot=(math.pi / 2, 0, 0)))  # muzzle brake
    p.append(box(dark, (0, 0.47, 0.068), (0.012, 0.015, 0.035)))        # front sight post
    # optic: small box sight with a red dot
    p.append(box(dark, (0, 0.08, 0.115), (0.04, 0.09, 0.045)))
    p.append(box(sight, (0, 0.124, 0.118), (0.006, 0.002, 0.006)))
    # grip, trigger guard, magazine
    p.append(box(poly, (0, -0.005, -0.045), (0.035, 0.045, 0.1), rot=(-0.3, 0, 0)))
    p.append(box(dark, (0, 0.04, -0.012), (0.012, 0.06, 0.008)))
    p.append(box(dark, (0, 0.125, -0.07), (0.03, 0.055, 0.14), rot=(0.18, 0, 0)))
    p.append(box(brass, (0, 0.125, 0.0), (0.012, 0.03, 0.01)))
    # stock with cheek rest
    p.append(box(poly, (0, -0.16, 0.02), (0.04, 0.2, 0.06)))
    p.append(box(poly, (0, -0.25, 0.0), (0.045, 0.04, 0.12)))
    p.append(box(dark, (0, -0.272, 0.0), (0.047, 0.008, 0.125)))
    # charging handle and sling loop
    p.append(box(steel, (0.035, 0.03, 0.05), (0.02, 0.015, 0.012)))
    p.append(cyl(steel, (0, -0.06, -0.012), 0.01, 0.01, verts=6, rot=(0, math.pi / 2, 0)))
    o = join(p, "Rifle")
    export_glb(os.path.join(OUTDIR, "rifle.glb"), [o])
    if "--preview" in sys.argv:
        preview(os.path.join(OUTDIR, "..", "..", "tools", "rifle_prev.png"), target=(0, 0.2, 0.0), dist=1.2, angle=1.9, height=0.1)

def pistol():
    """Frame, slide and magazine are separate pieces (the reload moves them)."""
    reset(); mats()
    p = []
    p.append(box(dark, (0, 0.06, 0.006), (0.028, 0.15, 0.02)))           # frame
    p.append(box(poly, (0, -0.005, -0.045), (0.029, 0.04, 0.1), rot=(-0.25, 0, 0)))  # grip
    p.append(box(wood, (0.0152, -0.005, -0.045), (0.002, 0.032, 0.08), rot=(-0.25, 0, 0)))
    p.append(box(wood, (-0.0152, -0.005, -0.045), (0.002, 0.032, 0.08), rot=(-0.25, 0, 0)))
    p.append(box(dark, (0, 0.035, -0.012), (0.008, 0.04, 0.006)))        # trigger guard
    p.append(box(steel, (0, -0.03, 0.04), (0.012, 0.012, 0.012), rot=(0.4, 0, 0)))  # hammer
    frame = join(p, "Pistol")
    s = [box(steel, (0, 0.06, 0.03), (0.03, 0.17, 0.035))]               # slide
    for i in range(5):
        s.append(box(dark, (0.0155, -0.0 + i * 0.008, 0.03), (0.002, 0.004, 0.025)))
        s.append(box(dark, (-0.0155, -0.0 + i * 0.008, 0.03), (0.002, 0.004, 0.025)))
    s.append(cyl(dark, (0, 0.148, 0.032), 0.007, 0.012, verts=6, rot=(math.pi / 2, 0, 0)))
    s.append(box(dark, (0, 0.135, 0.05), (0.004, 0.006, 0.006)))         # sights
    s.append(box(dark, (0, -0.015, 0.05), (0.014, 0.006, 0.006)))
    slide = join(s, "Slide")
    m = [box(dark, (0, -0.009, -0.058), (0.022, 0.03, 0.1), rot=(-0.25, 0, 0)),     # magazine body
         box(steel, (0, -0.019, -0.099), (0.031, 0.043, 0.008), rot=(-0.25, 0, 0)),  # base plate
         box(brass, (0, 0.002, -0.006), (0.008, 0.016, 0.006), rot=(-0.25, 0, 0))]   # top round
    mag = join(m, "Mag")
    export_glb(os.path.join(OUTDIR, "pistol.glb"), [frame, slide, mag])
    # a spare magazine on its own (in the reloading hand)
    reset(); mats()
    m = [box(dark, (0, 0, 0), (0.022, 0.03, 0.1)), box(steel, (0, 0, -0.054), (0.031, 0.043, 0.008)),
         box(brass, (0, 0.004, 0.052), (0.008, 0.016, 0.006))]
    export_glb(os.path.join(OUTDIR, "pistol_mag.glb"), [join(m, "SpareMag")])

def limb(m, a, b, r1, r2, verts=6):
    """A tapered cylinder from point a to point b (forearms)."""
    a = Vector(a); b = Vector(b)
    d = b - a
    o = cyl(m, (0, 0, 0), r1, d.length, verts=verts, r2=r2)
    q = d.normalized().to_track_quat('Z', 'Y')
    o.rotation_mode = 'QUATERNION'
    o.rotation_quaternion = q
    o.location = (a + b) / 2
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return o

def hand(m, at, size=(0.07, 0.1, 0.09), rot=(0, 0, 0), fingers_dir=(0, 1, 0)):
    p = [box(m, at, size, rot=rot)]
    # thumb
    p.append(box(m, (at[0] + 0.03, at[1] + 0.03, at[2] + 0.03), (0.02, 0.05, 0.02), rot=rot))
    return p

def hands(kind):
    reset()
    glove = mat("Glove", (0.07, 0.07, 0.065), rough=0.8)
    sleeve = mat("Sleeve", (0.20, 0.22, 0.15))
    skin = mat("Wrist", (0.62, 0.47, 0.38))
    watch = mat("Watch", (0.15, 0.15, 0.16), rough=0.3)
    dial = mat("WatchDial", (0.3, 0.9, 0.5), emit=1.5)
    p = []
    if kind == "rifle":
        # right hand on the pistol grip, forearm back towards the shoulder
        p += hand(glove, (0.0, -0.01, -0.04), (0.065, 0.075, 0.1), rot=(-0.3, 0, 0))
        p.append(box(glove, (0.0, 0.03, -0.01), (0.02, 0.04, 0.02)))               # trigger finger
        p.append(limb(skin, (0.01, -0.05, -0.07), (0.03, -0.1, -0.1), 0.033, 0.035))
        p.append(limb(sleeve, (0.03, -0.1, -0.1), (0.1, -0.42, -0.24), 0.045, 0.055))
        # left hand under the handguard
        p += hand(glove, (0.0, 0.36, -0.005), (0.08, 0.1, 0.06))
        p.append(limb(skin, (-0.02, 0.32, -0.03), (-0.04, 0.27, -0.06), 0.032, 0.034))
        p.append(limb(sleeve, (-0.04, 0.27, -0.06), (-0.22, -0.05, -0.26), 0.045, 0.055))
        p.append(cyl(watch, (-0.035, 0.29, -0.045), 0.04, 0.025, verts=8, rot=(1.1, 0, 0)))
        p.append(box(dial, (-0.06, 0.295, -0.03), (0.012, 0.02, 0.02), rot=(1.1, 0, 0)))
    else:
        # two-handed pistol grip
        p += hand(glove, (0.0, -0.005, -0.04), (0.06, 0.07, 0.095), rot=(-0.25, 0, 0))
        p.append(box(glove, (0.0, 0.035, -0.012), (0.018, 0.035, 0.018)))
        p += hand(glove, (-0.035, 0.0, -0.06), (0.05, 0.08, 0.08), rot=(-0.25, 0, 0.3))
        p.append(limb(skin, (0.01, -0.04, -0.08), (0.02, -0.09, -0.11), 0.03, 0.033))
        p.append(limb(sleeve, (0.02, -0.09, -0.11), (0.1, -0.42, -0.25), 0.045, 0.055))
        p.append(limb(skin, (-0.05, -0.03, -0.09), (-0.07, -0.08, -0.12), 0.03, 0.033))
        p.append(limb(sleeve, (-0.07, -0.08, -0.12), (-0.25, -0.38, -0.26), 0.045, 0.055))
    o = join(p, "Hands_" + kind)
    export_glb(os.path.join(OUTDIR, "hands_%s.glb" % kind), [o])

rifle()
pistol()
hands("rifle")
hands("pistol")

if "--handprev" in sys.argv:
    # put a rifle and its hands together for a first-person style check
    reset()
    bpy.ops.import_scene.gltf(filepath=os.path.join(OUTDIR, "rifle.glb"))
    bpy.ops.import_scene.gltf(filepath=os.path.join(OUTDIR, "hands_rifle.glb"))
    preview(sys.argv[sys.argv.index("--handprev") + 1], target=(0, 0.25, 0.0), dist=0.9, angle=3.6, height=0.0)
