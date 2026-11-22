"""Enemy Beyond (0.80): sentry gun ST-01 "Strážce brány" - own design. A low tripod
with a pivot post (object "Base") and a turning head (object "Head", origin at the
pivot 0.62 m above the ground): receiver, barrel, ammo box on the left, motion
sensor with a red eye ("Eye") on top. Front = Blender +Y (= Godot -Z).
Run: python3 sentry.py <out dir>   (then zfight_glb.py --fix sentry.glb)"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from common import *
from mathutils import Vector

OUTDIR = sys.argv[-1]
PIV = 0.62

def tube(m, a, b, r, verts=8):
    a = Vector(a); b = Vector(b); d = b - a
    o = cyl(m, (0, 0, 0), r, d.length, verts=verts)
    o.rotation_mode = 'QUATERNION'
    o.rotation_quaternion = d.normalized().to_track_quat('Z', 'Y')
    o.location = (a + b) / 2
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return o

reset()
olive = mat("OliveDrab", (0.20, 0.23, 0.14), rough=0.8)
dark = mat("Blackened", (0.06, 0.06, 0.065), rough=0.6)
steel = mat("Steel", (0.20, 0.21, 0.22), rough=0.45)
warn = mat("WarnYellow", (0.75, 0.6, 0.1))
eye = mat("SentryEye", (1.0, 0.12, 0.05), emit=4.0)
glass = mat("LensDark", (0.02, 0.02, 0.03), rough=0.1)

# ---- base: tripod and post
b = []
for k in range(3):
    a = k * 2 * math.pi / 3 + math.pi
    foot = (math.sin(a) * 0.55, math.cos(a) * 0.55, 0.02)
    b.append(tube(steel, foot, (math.sin(a) * 0.06, math.cos(a) * 0.06, 0.42), 0.017))
    b.append(cyl(dark, foot, 0.035, 0.03, verts=8))
b.append(cyl(dark, (0, 0, 0.44), 0.07, 0.07, verts=10))          # hub
b.append(cyl(steel, (0, 0, 0.52), 0.035, 0.16, verts=10))        # post
b.append(cyl(dark, (0, 0, 0.6), 0.06, 0.03, verts=12))           # turntable
b.append(box(warn, (0, 0.06, 0.6), (0.02, 0.012, 0.031)))        # yellow index mark
base = join(b, "Base")

# ---- head (built round the pivot, then moved up)
h = []
h.append(box(olive, (0, 0.02, 0.07), (0.16, 0.42, 0.13)))       # receiver
h.append(box(dark, (0, 0.24, 0.07), (0.1, 0.04, 0.09)))          # front plate
h.append(tube(dark, (0, 0.24, 0.08), (0, 0.72, 0.08), 0.018))    # barrel
h.append(tube(dark, (0, 0.62, 0.08), (0, 0.74, 0.08), 0.026, verts=10))   # flash hider
h.append(box(olive, (-0.13, 0.02, 0.04), (0.1, 0.22, 0.16)))     # ammo box
h.append(box(warn, (-0.181, 0.02, 0.09), (0.003, 0.16, 0.012)))
h.append(tube(dark, (-0.08, 0.06, 0.1), (-0.06, 0.12, 0.1), 0.012))       # feed chute
h.append(box(dark, (0, -0.07, 0.17), (0.12, 0.14, 0.08)))       # sensor housing
h.append(cyl(glass, (0, 0.0, 0.17), 0.032, 0.012, verts=12, rot=(math.pi / 2, 0, 0)))
h.append(box(dark, (0.1, -0.12, 0.07), (0.04, 0.08, 0.1)))      # battery
h.append(tube(dark, (0.1, -0.16, 0.12), (0.1, -0.2, 0.5), 0.003, verts=6))  # whip antenna
h.append(box(steel, (0, 0, -0.01), (0.1, 0.1, 0.03)))            # yoke
head = join(h, "Head")
e = cyl(eye, (0, 0.007, 0.17), 0.018, 0.006, verts=10, rot=(math.pi / 2, 0, 0))
e.name = "Eye"; e.data.name = "Eye"
for o in (head, e):
    o.location.z += PIV
e.parent = head
e.location.z -= PIV
export_glb(os.path.join(OUTDIR, "sentry.glb"), [base, head, e])
