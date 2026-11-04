"""Nádor (0.50) after Ari's picture: a floating, lumpy mass of pale flesh in folds like a brain, swollen
crimson sacs glowing from inside, purple veins over everything, violet crystal spines growing out of it,
small pearly eggs, one yellow eye half buried in the folds, and a curtain of long, thin, wet tentacles.
Rigid as before: Body (the game makes it pulse and bob).
Run: python3 tools/blender/nador.py out.glb [--preview - 0 out.png angle]"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
from common import *
from common import _finish

OUT = [a for a in sys.argv if a.endswith(".glb")]
OUT = OUT[0] if OUT else "nador.glb"
reset()

def mat2(name, rgb, rough=0.6, emit=0.0):
    return mat(name, rgb, emit=emit, rough=rough)

flesh = mat2("NadFlesh", (0.44, 0.26, 0.28), rough=0.2)
flesh2 = mat2("NadFlesh2", (0.32, 0.12, 0.17), rough=0.18)
sac = mat2("NadSac", (0.42, 0.02, 0.07), rough=0.08)
sac_in = mat("NadSacGlow", (1.0, 0.1, 0.12), emit=1.8)
vein = mat2("NadVein", (0.3, 0.05, 0.3), rough=0.3)
crystal = mat("NadCrystal", (0.45, 0.15, 0.7), emit=0.8)
pearl = mat2("NadPearl", (0.8, 0.74, 0.68), rough=0.15)
eye = mat("NadEye", (1.0, 0.8, 0.2), emit=4.0)
tent = mat2("NadTent", (0.5, 0.1, 0.28), rough=0.15)
acid = mat("NadAcid", (0.6, 0.9, 0.15), emit=1.5)

def smooth(o):
    for p in o.data.polygons:
        p.use_smooth = True
    return o

def S(material, loc, r, scale=(1, 1, 1), seg=14, rings=10):
    return smooth(sphere(material, loc, r, seg=seg, rings=rings, scale=scale))

def L(material, a, b, r1, r2, verts=6):
    a = Vector(a); b = Vector(b)
    d = b - a
    o = cyl(material, (0, 0, 0), r1, max(d.length, 0.001), verts=verts, r2=r2)
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    for v in o.data.vertices:
        v.co = q @ v.co + (a + b) / 2
    return smooth(o)

def on(a, e, r=0.36):
    """A point on the mass: a = around (0 = front, +Y), e = up."""
    return Vector((math.cos(e) * math.sin(a) * r, math.cos(e) * math.cos(a) * r, math.sin(e) * r * 0.85))

rr = random.Random(11)
B = []
# the core and the brain-like folds of pale flesh
core = sphere(flesh, (0, 0, 0), 0.38, seg=24, rings=16, scale=(1.05, 1.0, 0.88))
for v in core.data.vertices:                                     # lumpy, folded surface
    n = v.co.normalized()
    v.co += n * (0.035 * math.sin(n.x * 11 + n.z * 7) * math.cos(n.y * 9 - n.z * 5))
B.append(smooth(core))
for i in range(22):
    a = rr.uniform(0, math.tau); e = rr.uniform(-0.5, 1.2)
    B.append(S(flesh if i % 3 else flesh2, tuple(on(a, e, 0.32)), rr.uniform(0.08, 0.15), (1.2, 1.0, 0.75)))
# the crimson sacs, clustered on one side (front right), glowing from within
for i in range(6):
    a = rr.uniform(0.1, 1.5); e = rr.uniform(-0.3, 0.55)
    r = rr.uniform(0.07, 0.12)
    c = on(a, e, 0.33)
    B.append(S(sac, tuple(c), r))
    B.append(S(sac_in, tuple(c + c.normalized() * r * 0.35), r * 0.6, (1, 1, 1), 10, 6))   # the glow inside
# purple veins running over it
for i in range(26):
    a = rr.uniform(0, math.tau); e = rr.uniform(-0.6, 1.1)
    pts = [on(a + k * 0.16, e + k * rr.uniform(-0.15, 0.2), 0.385) for k in range(5)]
    for k in range(4):
        B.append(L(vein, tuple(pts[k]), tuple(pts[k + 1]), 0.008, 0.006, 5))
# violet crystal spines
for i in range(16):
    a = rr.uniform(0, math.tau); e = rr.uniform(-0.7, 1.1)
    base = on(a, e, 0.33)
    tip = base + base.normalized() * rr.uniform(0.12, 0.26)
    o = L(crystal, tuple(base), tuple(tip), rr.uniform(0.018, 0.03), 0.0, 6)
    for p in o.data.polygons:
        p.use_smooth = False
    B.append(o)
# pearly eggs and the one yellow eye
for (a, e, r) in ((-0.3, 0.25, 0.04), (-0.15, 0.35, 0.03), (0.05, 0.3, 0.025)):
    B.append(S(pearl, tuple(on(a, e, 0.39)), r))
B.append(S(flesh2, tuple(on(0.65, -0.2, 0.37)), 0.07, (1.4, 0.6, 0.8)))      # the lid of flesh
B.append(S(eye, tuple(on(0.65, -0.2, 0.4)), 0.035, (1.3, 0.7, 0.7)))
# the acid orifice underneath, at the front
B.append(S(vein, tuple(on(0.0, -0.55, 0.37)), 0.07, (1, 0.6, 1)))
B.append(S(acid, tuple(on(0.0, -0.55, 0.4)), 0.04, (1, 0.6, 1)))
# a curtain of long, thin, curling tentacles
for i in range(18):
    a = i / 18 * math.tau + rr.uniform(-0.1, 0.1)
    r0 = rr.uniform(0.1, 0.27)
    ln = rr.uniform(0.6, 1.0)
    ph = rr.uniform(0, math.tau)
    pts = []
    for k in range(9):
        t = k / 8
        sway = math.sin(t * 4.0 + ph) * 0.07 * t
        rr_ = r0 + sway + t * 0.05
        aa = a + math.sin(t * 3.0 + ph) * 0.25 * t
        pts.append(Vector((math.sin(aa) * rr_, math.cos(aa) * rr_, -0.18 - t * ln)))
    for k in range(8):
        ra = 0.03 * (1 - k / 8) + 0.003
        rb = 0.03 * (1 - (k + 1) / 8) + 0.003
        B.append(L(tent, tuple(pts[k]), tuple(pts[k + 1]), ra, rb, 7))
        B.append(S(tent, tuple(pts[k + 1]), rb, (1, 1, 1), 7, 4))
bodyo = join(B, "Body")
bpy.context.scene.cursor.location = (0, 0, 0)
bpy.ops.object.select_all(action='DESELECT')
bodyo.select_set(True)
bpy.context.view_layer.objects.active = bodyo
bpy.ops.object.origin_set(type='ORIGIN_CURSOR')

if "--preview" in sys.argv:
    i = sys.argv.index("--preview")
    preview(sys.argv[i + 3], target=(0, 0, -0.15), dist=2.6, angle=float(sys.argv[i + 4]), height=0.2, res=(480, 560))
else:
    export_glb(OUT, [bodyo])
    print("written", OUT)
