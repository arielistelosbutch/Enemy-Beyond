"""Ohnivec (0.50) after Ari's picture: a low, long mound of grey heat-proof membranes stretched in webs and
ridged fins over chambers of orange-yellow fire; at the front a great glowing furnace-core; amber crystal
rods jutting out of it. Rigid pieces: Rock (the membranes), Magma (the fire, the core and the crystals -
the game makes it pulse, and glow up before the heat discharge).
Run: python3 tools/blender/ohnivec.py out.glb [--preview - 0 out.png angle]"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
from common import *
from common import _finish

OUT = [a for a in sys.argv if a.endswith(".glb")]
OUT = OUT[0] if OUT else "ohnivec.glb"
reset()

def mat2(name, rgb, rough=0.6, emit=0.0):
    return mat(name, rgb, emit=emit, rough=rough)

memb = mat2("OhnMemb", (0.17, 0.155, 0.15), rough=0.15)
memb2 = mat2("OhnMemb2", (0.2, 0.07, 0.07), rough=0.2)
rock = mat2("OhnRock", (0.14, 0.12, 0.11), rough=0.6)
fire = mat("OhnLava", (1.0, 0.38, 0.05), emit=3.0)
core = mat("OhnCore", (1.0, 0.7, 0.2), emit=5.0)
amber = mat("OhnCrystal", (1.0, 0.65, 0.1), emit=3.5)

def smooth(o):
    for p in o.data.polygons:
        p.use_smooth = True
    return o

def S(material, loc, r, scale=(1, 1, 1), seg=14, rings=10, rot=(0, 0, 0)):
    return smooth(sphere(material, loc, r, seg=seg, rings=rings, scale=scale, rot=rot))

def L(material, a, b, r1, r2, verts=8, sm=True):
    a = Vector(a); b = Vector(b)
    d = b - a
    o = cyl(material, (0, 0, 0), r1, max(d.length, 0.001), verts=verts, r2=r2)
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    for v in o.data.vertices:
        v.co = q @ v.co + (a + b) / 2
    return smooth(o) if sm else o

rr = random.Random(9)
LEN = 0.75                                     # half length along Y (front = +Y)

def hull(y, side, up):
    """A point on the mound: y along, side -1..1 across, up 0..1."""
    w = 0.55 * math.sqrt(max(0.0, 1.0 - (y / LEN) ** 2)) + 0.05
    h = 0.5 * math.sqrt(max(0.0, 1.0 - (y / (LEN * 1.05)) ** 2)) + 0.05
    a = side * math.pi / 2 * (1 - up)
    return Vector((math.sin(a) * w, y, 0.05 + math.cos(a) * h * (0.4 + 0.6 * up) if up > 0 else 0.05 + math.cos(a) * h * 0.4))

# ---- the fire inside -------------------------------------------------------------------------------------------------
M = []
M.append(S(fire, (0, -0.05, 0.25), 0.5, (0.95, 1.4, 0.48), 20, 12))
for i in range(9):
    M.append(S(fire, (rr.uniform(-0.3, 0.3), rr.uniform(-0.55, 0.35), rr.uniform(0.2, 0.4)), rr.uniform(0.12, 0.2)))
M.append(S(core, (0.12, 0.55, 0.25), 0.25, (1.0, 0.85, 0.9), 20, 14))            # the furnace-core at the front
for i in range(7):                                                                 # amber crystal rods
    y = rr.uniform(-0.55, 0.45)
    side = 1 if i % 2 else -1
    base = Vector((side * rr.uniform(0.25, 0.4), y, rr.uniform(0.3, 0.5)))
    tip = base + Vector((side * rr.uniform(0.35, 0.5), rr.uniform(-0.15, 0.15), rr.uniform(0.0, 0.25)))
    o = L(amber, tuple(base), tuple(tip), 0.045, 0.04, 6, sm=False)
    M.append(o)
    M.append(L(amber, tuple(tip), tuple(tip + (tip - base).normalized() * 0.06), 0.04, 0.0, 6, sm=False))
magmao = join(M, "Magma")

# ---- the membranes: ridged fins and stretched webs over the fire -----------------------------------------------------
R = []
for k in range(9):                                                                 # ribs arching over it
    y = -0.62 + k * 0.15
    w = 0.55 * math.sqrt(max(0.0, 1.0 - (y / 0.8) ** 2)) + 0.08
    h = 0.48 * math.sqrt(max(0.0, 1.0 - (y / 0.84) ** 2)) + 0.1
    pts = []
    for j in range(9):
        a = -math.pi / 2 + j / 8 * math.pi
        pts.append(Vector((math.sin(a) * w, y + math.sin(a * 2) * 0.03, 0.03 + math.cos(a) * h)))
    for j in range(8):
        R.append(L(memb if k % 2 else memb2, tuple(pts[j]), tuple(pts[j + 1]), 0.05, 0.05, 8))
    # the fin: a ridge rising from the top of the rib, swept back
    top = pts[4]
    fin = L(memb, tuple(top), tuple(top + Vector((rr.uniform(-0.05, 0.05), -0.2, 0.1 + 0.05 * math.sin(k)))), 0.08, 0.0, 6, sm=False)
    for v in fin.data.vertices:
        v.co.x = top.x + (v.co.x - top.x) * 0.35                                   # flattened into a blade
    R.append(fin)
for i in range(24):                                                                # webs stretched between the ribs
    y0 = rr.uniform(-0.6, 0.5)
    a0 = rr.uniform(-1.0, 1.0)
    def at(y, a):
        w = 0.55 * math.sqrt(max(0.0, 1.0 - (y / 0.8) ** 2)) + 0.08
        h = 0.48 * math.sqrt(max(0.0, 1.0 - (y / 0.84) ** 2)) + 0.1
        return Vector((math.sin(a) * w, y, 0.03 + math.cos(a) * h))
    p0 = at(y0, a0)
    p1 = at(y0 + rr.uniform(0.1, 0.2), a0 + rr.uniform(-0.4, 0.4))
    R.append(L(memb, tuple(p0 * 1.01), tuple(p1 * 1.01), rr.uniform(0.01, 0.018), rr.uniform(0.005, 0.01), 5))
for i in range(22):                                                                # flaps of membrane lying over parts of it
    y = rr.uniform(-0.55, 0.45)
    a = rr.uniform(-1.2, 1.2)
    w = 0.55 * math.sqrt(max(0.0, 1.0 - (y / 0.8) ** 2)) + 0.08
    h = 0.48 * math.sqrt(max(0.0, 1.0 - (y / 0.84) ** 2)) + 0.1
    c = Vector((math.sin(a) * w, y, 0.03 + math.cos(a) * h))
    R.append(S(memb if i % 4 else memb2, tuple(c), rr.uniform(0.11, 0.17), (1.0, 1.3, 0.22), 12, 6, rot=(0, a, 0)))
# the rear: a lump of grey rock-like hide; the skirt dripping onto the ground
R.append(S(rock, (0, -0.72, 0.16), 0.22, (1.3, 0.8, 0.7)))
R.append(S(memb, (0, -0.6, 0.3), 0.26, (1.3, 0.7, 0.7)))
for i in range(14):
    a = i / 14 * math.tau
    R.append(S(memb2 if i % 3 == 0 else memb, (math.sin(a) * 0.55, math.cos(a) * 0.75, 0.05), 0.09, (1.2, 1.2, 0.5), 10, 6))
rocko = join(R, "Rock")
for o in (magmao,):
    bpy.context.scene.cursor.location = (0, 0, 0.25)
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')

if "--preview" in sys.argv:
    i = sys.argv.index("--preview")
    preview(sys.argv[i + 3], target=(0, 0, 0.3), dist=2.8, angle=float(sys.argv[i + 4]), height=0.5, res=(640, 420))
else:
    export_glb(OUT, [rocko, magmao])
    print("written", OUT)
