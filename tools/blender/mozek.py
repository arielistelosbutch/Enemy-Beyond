"""Velký mozek (0.50) after Ari's picture: two huge glossy pink lobes in deep folds with violet veins, a dark
monolith in the cleft between them with a glowing ring sigil, a pale glowing eye in each lobe; plugged into
the machine - steel sockets on the lobes, black corrugated cables and translucent tubes rising away, two glass
canisters of pink fluid hanging on them, crackles of violet lightning; below, the stem in a steel collar with
glowing slots and four violet light-tubes in clamps reaching down and out.
One object, "Brain" (boss.gd makes it breathe).
Run: python3 tools/blender/mozek.py out.glb [--preview - 0 out.png angle]"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
from common import *
from common import _finish

OUT = [a for a in sys.argv if a.endswith(".glb")]
OUT = OUT[0] if OUT else "mozek.glb"
reset()

def mat2(name, rgb, rough=0.6, metal=0.0, emit=0.0, alpha=1.0):
    m = mat(name, rgb, emit=emit, rough=rough)
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Metallic"].default_value = metal
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
        m.blend_method = 'BLEND' if hasattr(m, "blend_method") else None
    return m

brain = mat2("BrainPink", (0.7, 0.36, 0.42), rough=0.22)
brain2 = mat2("BrainPink2", (0.55, 0.22, 0.32), rough=0.25)
vein = mat2("BrainVein", (0.35, 0.08, 0.45), rough=0.3)
eye = mat("BrainEye", (1.0, 0.85, 0.95), emit=7.0)
dark = mat2("BrainMonolith", (0.05, 0.045, 0.06), rough=0.35, metal=0.6)
glow = mat("BrainNerve", (0.75, 0.3, 1.0), emit=4.0)
steel = mat2("BrainSteel", (0.3, 0.29, 0.32), rough=0.3, metal=0.85)
cable = mat2("BrainCable", (0.04, 0.035, 0.045), rough=0.5)
tube = mat2("BrainTube", (0.85, 0.6, 0.65), rough=0.05, alpha=0.5)
fluid = mat("BrainFluid", (1.0, 0.35, 0.6), emit=1.5)
arc = mat("BrainArc", (0.85, 0.55, 1.0), emit=8.0)
slime = mat2("BrainSlime", (0.8, 0.55, 0.65), rough=0.05)

def smooth(o):
    for p in o.data.polygons:
        p.use_smooth = True
    return o

def L(material, a, b, r1, r2, verts=10, sm=True):
    a = Vector(a); b = Vector(b)
    d = b - a
    o = cyl(material, (0, 0, 0), r1, max(d.length, 0.001), verts=verts, r2=r2)
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    for v in o.data.vertices:
        v.co = q @ v.co + (a + b) / 2
    return smooth(o) if sm else o

def curve(material, pts, r, verts=10):
    out = []
    for i in range(len(pts) - 1):
        out.append(L(material, pts[i], pts[i + 1], r, r, verts))
        if i < len(pts) - 2:
            out.append(smooth(sphere(material, tuple(pts[i + 1]), r, seg=verts, rings=5)))
    return out

def bez(a, b, c, n=8):
    a, b, c = Vector(a), Vector(b), Vector(c)
    return [tuple((1 - t) ** 2 * a + 2 * (1 - t) * t * b + t * t * c) for t in [i / n for i in range(n + 1)]]

rr = random.Random(7)
P = []
# ---- the two lobes: deep folds (gyri), glossy -------------------------------------------------------------------
LOBES = []
for sx in (-1, 1):
    c = Vector((sx * 0.58, 0, 1.35))
    lobe = sphere(brain, tuple(c), 1.0, seg=64, rings=40, scale=(0.92, 1.3, 0.82))
    for v in lobe.data.vertices:
        n = (v.co - c)
        d = n.normalized()
        # winding folds: a few crossing waves, sharpened into ridges
        w = math.sin(d.x * 13 + math.sin(d.y * 6) * 2.5) * math.sin(d.y * 11 + math.sin(d.z * 7) * 2.2) + 0.7 * math.sin(d.z * 17 + d.x * 5 + d.y * 3)
        f = 1.0 + 0.085 * (min(1.0, abs(w)) ** 0.45) - 0.06
        if sx * d.x < -0.55:
            f *= 0.97                                   # flatter where the lobes meet
        v.co = c + n * f
    P.append(smooth(lobe))
    LOBES.append(c)
    for i in range(10):                                 # veins wandering over it
        a0 = rr.uniform(-1.2, 1.2); e0 = rr.uniform(-0.2, 0.9)
        pts = []
        for k in range(6):
            a = a0 + k * 0.12 * (1 if i % 2 else -1); e = e0 - k * 0.1
            pts.append(c + Vector((math.cos(e) * math.sin(a) * 0.95 * 0.92 * sx, math.cos(e) * math.cos(a) * 1.3 * 0.97, math.sin(e) * 0.82 * 0.98)))
        P += curve(vein, pts, 0.018, 6)
    # the eye: glowing, in the front folds, with a socket of flesh
    ep = c + Vector((-sx * 0.12, 1.12, -0.05))
    P.append(smooth(sphere(brain2, tuple(ep - Vector((0, 0.05, 0))), 0.2, seg=16, rings=10, scale=(1, 0.6, 1))))
    P.append(smooth(sphere(eye, tuple(ep + Vector((0, 0.06, 0))), 0.13, seg=16, rings=10)))
    # drips of slime from the underside
    for k in range(7):
        x = c.x + rr.uniform(-0.5, 0.5); y = rr.uniform(-0.6, 0.9)
        z = 0.75 + abs(x - c.x) * 0.25
        ln = rr.uniform(0.15, 0.45)
        P.append(L(slime, (x, y, z), (x, y, z - ln), 0.025, 0.008, 6))
        P.append(smooth(sphere(slime, (x, y, z - ln), 0.018, seg=6, rings=4, scale=(1, 1, 1.4))))
# ---- the monolith in the cleft ---------------------------------------------------------------------------------------
P.append(box(dark, (0, 1.0, 1.75), (0.24, 0.22, 1.45)))
P.append(box(dark, (0, 0.3, 2.2), (0.16, 1.4, 0.3)))
P.append(box(steel, (0, 1.115, 2.35), (0.2, 0.02, 0.12)))
P.append(box(glow, (0, 1.115, 1.85), (0.014, 0.01, 0.8)))
bpy.ops.mesh.primitive_torus_add(major_radius=0.07, minor_radius=0.01, major_segments=20, minor_segments=4)
P.append(_finish(bpy.context.active_object, glow, (0, 1.115, 1.3), (math.pi / 2, 0, 0), (1, 1, 1)))
P.append(smooth(sphere(glow, (0, 1.12, 1.3), 0.02, seg=8, rings=6)))
# ---- below: the stem, the steel collar with glowing slots, the four light-tubes --------------------------------------------
P.append(L(brain2, (0, 0.1, 0.95), (0, 0.1, 0.35), 0.42, 0.3, 16))
bpy.ops.mesh.primitive_torus_add(major_radius=0.5, minor_radius=0.08, major_segments=32, minor_segments=8)
P.append(smooth(_finish(bpy.context.active_object, steel, (0, 0.1, 0.62), (0, 0, 0), (1, 1, 1.4))))
for i in range(10):
    a = i / 10 * math.tau
    P.append(box(glow, (math.sin(a) * 0.585, 0.1 + math.cos(a) * 0.585, 0.62), (0.08, 0.012, 0.03), rot=(0, 0, -a)))
P.append(L(steel, (0, 0.1, 0.45), (0, 0.1, 0.12), 0.34, 0.26, 16))
P.append(L(glow, (0, 0.1, 0.12), (0, 0.1, 0.02), 0.22, 0.2, 16))                          # the glowing foot
for i in range(4):
    a = math.pi / 4 + i * math.pi / 2
    a0 = Vector((math.sin(a) * 0.5, 0.1 + math.cos(a) * 0.5, 0.6))
    a1 = Vector((math.sin(a) * 1.6, 0.1 + math.cos(a) * 1.6, 0.05))
    P.append(L(glow, tuple(a0), tuple(a1), 0.05, 0.05, 12))
    for t in (0.25, 0.7):                                                                  # clamps
        p0 = a0.lerp(a1, t)
        P.append(L(steel, tuple(p0 - (a1 - a0).normalized() * 0.05), tuple(p0 + (a1 - a0).normalized() * 0.05), 0.075, 0.075, 12))
# ---- plugged in: sockets, cables, translucent tubes, canisters, arcs ----------------------------------------------------------
SOCKETS = []
for (sx, a, e) in ((-1, 0.7, 0.5), (-1, 1.6, 0.2), (-1, 0.2, 0.9), (1, 0.9, 0.45), (1, 1.7, 0.15), (1, 0.3, 0.85), (-1, 2.4, 0.4), (1, 2.5, 0.5)):
    c = LOBES[0 if sx < 0 else 1]
    d = Vector((math.cos(e) * math.sin(a) * sx * 0.92, math.cos(e) * math.cos(a) * 1.3, math.sin(e) * 0.82)) * 1.02
    s0 = c + d
    nrm = d.normalized()
    P.append(L(steel, tuple(s0 - nrm * 0.06), tuple(s0 + nrm * 0.08), 0.1, 0.09, 14))
    bpy.ops.mesh.primitive_torus_add(major_radius=0.11, minor_radius=0.025, major_segments=16, minor_segments=6)
    P.append(smooth(_finish(bpy.context.active_object, steel, tuple(s0), nrm.to_track_quat('Z', 'Y').to_euler(), (1, 1, 1))))
    SOCKETS.append((s0 + nrm * 0.08, nrm))
for k, (s0, nrm) in enumerate(SOCKETS):
    up = s0 + nrm * 0.8 + Vector((0, 0, 0.6))
    top = Vector((s0.x * 1.4 + rr.uniform(-0.3, 0.3), s0.y * 0.8 + rr.uniform(-0.3, 0.3), 4.2))
    pts = bez(s0, up, top, 9)
    if k % 2 == 0:
        P += curve(cable, pts, 0.055, 10)
        for t in range(1, 8, 2):                                                           # corrugation rings
            P.append(L(cable, pts[t], tuple(Vector(pts[t]) + (Vector(pts[t + 1]) - Vector(pts[t])) * 0.15), 0.068, 0.068, 10))
    else:
        P += curve(tube, pts, 0.06, 12)
        P += curve(fluid, pts[:5], 0.025, 6)
# the two canisters of pink fluid, hanging on the cables
for (x, y, z) in ((-1.9, 0.6, 2.2), (1.9, 0.5, 2.7)):
    P.append(L(steel, (x, y, z + 0.4), (x, y, z + 0.5), 0.17, 0.17, 16))
    P.append(L(steel, (x, y, z - 0.42), (x, y, z - 0.32), 0.17, 0.17, 16))
    P.append(L(tube, (x, y, z - 0.32), (x, y, z + 0.4), 0.15, 0.15, 16))
    P.append(L(fluid, (x, y, z - 0.32), (x, y, z + 0.15), 0.12, 0.12, 14))
    P += curve(cable, bez((x, y, z + 0.5), (x, y, z + 1.2), (x * 0.7, y, 4.2), 5), 0.035, 8)
    P += curve(cable, bez((x, y, z - 0.42), (x * 0.9, y, z - 0.9), (x * 0.45, y * 0.5, 1.5), 5), 0.035, 8)
# violet lightning crackling between the lobes and the sockets
for k in range(5):
    s0, nrm = SOCKETS[rr.randrange(len(SOCKETS))]
    p = s0 + nrm * 0.1
    for j in range(4):
        q = p + nrm * 0.06 + Vector((rr.uniform(-0.07, 0.07), rr.uniform(-0.07, 0.07), rr.uniform(-0.03, 0.08)))
        P.append(L(arc, tuple(p), tuple(q), 0.006, 0.006, 4, sm=False))
        p = q
o = join(P, "Brain")
bpy.context.scene.cursor.location = (0, 0, 0)
bpy.ops.object.select_all(action='DESELECT'); o.select_set(True)
bpy.context.view_layer.objects.active = o
bpy.ops.object.origin_set(type='ORIGIN_CURSOR')

if "--preview" in sys.argv:
    i = sys.argv.index("--preview")
    preview(sys.argv[i + 3], target=(0, 0, 1.5), dist=7.5, angle=float(sys.argv[i + 4]), height=0.3, res=(720, 560))
else:
    export_glb(OUT, [o])
    print("written", OUT)
