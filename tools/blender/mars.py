"""Enemy Beyond - the last mission on Mars (own designs): the aliens' command centre
("Velín") - a ribbed dome half sunk in red rock with a long entrance tunnel; inside,
on a dais, the Great Brain in its cradle, guarded by three shield pylons. Also the
brain and the pylon as separate models (they are actors), and red rocks / spires."""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from common import *
import ufo_ground as U
from mathutils import Vector

OUTDIR = sys.argv[-1]
TAU = math.tau

def MM():
    m = U.M()
    m.update(rock=mat("MarsRock", (0.42, 0.18, 0.1), rough=0.95), vein=mat("MarsVein", (0.9, 0.2, 0.35), emit=2.5),
             bone=mat("MarsBone", (0.55, 0.5, 0.42), rough=0.7), brain=mat("BrainPink", (0.75, 0.42, 0.48), rough=0.6),
             nerve=mat("BrainNerve", (0.6, 0.3, 1.0), emit=3.0))
    return m

def hq():
    reset(); m = MM(); vis = []; col = []
    r, h, segs = 13.0, 6.0, 24
    # floor, walls (door gap at segment 0 = +Y), dome
    vis.append(cyl(m["floor"], (0, 0, 0.06), r, 0.12, verts=segs))
    c = cyl(m["dark"], (0, 0, 0.06), r, 0.12, verts=segs); c.name = "Floor-colonly"; col.append(c)
    U.wall_ring(m, r, h, segs, (0,), vis, col, "Wall", thick=0.6)
    vis.append(U.band(m["rib"], r + 0.3, h + 0.1, r * 0.55, h + 4.0, segs, name="DomeLow"))
    vis.append(U.band(m["hull"], r * 0.55, h + 4.0, 0.5, h + 5.2, segs, name="DomeTop"))
    vis.append(U.band(m["rock"], r + 3.5, 0.0, r + 0.3, h + 0.2, segs, skip=(0,), name="RockSkirt"))
    for i in range(segs):            # ribs over the dome, like a skeleton
        a = TAU * i / segs + math.pi / 2
        vis.append(U.beam(m["bone"], (math.cos(a) * (r + 0.4), math.sin(a) * (r + 0.4), h + 0.1), (math.cos(a) * 0.8, math.sin(a) * 0.8, h + 5.0), 0.35, 0.3))
    vis.append(cyl(m["vein"], (0, 0, h + 5.4), 0.4, 1.0, verts=8, r2=0.05))
    # entrance tunnel along +Y from the door to the outside, with a roof
    L = 10.0; w = 2.0 * r * math.tan(math.pi / segs)
    for sx in (-1, 1):
        x = sx * (w / 2 + 0.3)
        vis.append(box(m["wall"], (x, r + L / 2, 1.8), (0.6, L, 3.6)))
        c = box(m["dark"], (x, r + L / 2, 1.8), (0.6, L, 3.6)); c.name = "Tunnel%d-colonly" % (sx + 1); col.append(c)
        for k in range(5):
            vis.append(box(m["vein"], (x - sx * 0.31, r + 1 + k * 2, 2.6), (0.02, 0.6, 0.1)))
    vis.append(box(m["rib"], (0, r + L / 2, 3.75), (w + 1.6, L, 0.3)))
    vis.append(cyl(m["floor"], (0, r + L / 2, 0.06), 1, 1, verts=4))
    vis.append(box(m["floor"], (0, r + L / 2, 0.06), (w, L, 0.12)))
    c = box(m["dark"], (0, r + L / 2, 0.06), (w, L, 0.12)); c.name = "TunnelFloor-colonly"; col.append(c)
    for k in range(6):            # bone arches along the tunnel
        y = r + 0.8 + k * 1.8
        vis.append(box(m["bone"], (0, y, 3.55), (w + 1.2, 0.3, 0.3)))
    # the dais with the cradle of the Brain, nerves running to the walls
    vis.append(cyl(m["rib"], (0, -2.0, 0.4), 4.0, 0.8, verts=16, r2=3.6))
    c = cyl(m["dark"], (0, -2.0, 0.4), 4.0, 0.8, verts=16); c.name = "Dais-colonly"; col.append(c)
    vis.append(cyl(m["dark"], (0, -2.0, 1.1), 2.2, 0.6, verts=12, r2=1.6))
    for i in range(10):
        a = TAU * i / 10
        p0 = (math.cos(a) * 1.8, -2.0 + math.sin(a) * 1.8, 1.3)
        p1 = (math.cos(a) * (r - 0.6), math.sin(a) * (r - 0.6) - 1.0, 0.15 if i % 2 else h - 0.5)
        vis.append(U.beam(m["nerve"], p0, p1, 0.12, 0.12))
    # stairs to the dais (front)
    for k in range(3):
        vis.append(box(m["rib"], (0, 2.0 - k * 0.0 + 0.4 * (2 - k), 0.13 + k * 0.27), (2.4, 0.5, 0.27)))
    # columns around the hall
    for i in range(8):
        a = TAU * (i + 0.5) / 8 + math.pi / 2
        x, y = math.cos(a) * 8.5, math.sin(a) * 8.5
        if y > 6:
            continue
        vis.append(cyl(m["bone"], (x, y, h / 2), 0.45, h, verts=8, r2=0.3))
        c = cyl(m["dark"], (x, y, h / 2), 0.45, h, verts=8); c.name = "Col%d-colonly" % i; col.append(c)
    U.empty("Brain", (0, -2.0, 1.45))
    for i, a in enumerate((math.pi * 0.15, math.pi * 0.85, math.pi * 1.5)):
        U.empty("Pylon_%d" % i, (math.cos(a) * 7.0, math.sin(a) * 7.0 - 1.0, 0.12))
    for i, p in enumerate([(5, 5), (-5, 5), (8, -3), (-8, -3), (0, 8), (4, -8), (-4, -8)]):
        U.empty("Spawn_%d" % i, (p[0], p[1], 0.3))
    for i, p in enumerate([(0, r + 5), (0, r - 1.5), (6, 4), (-6, 4), (9, -4), (-9, -4), (0, -9)]):
        U.empty("Way_%d" % i, (p[0], p[1], 0.3))
    for i, p in enumerate([(0, 6), (7, -4), (-7, -4), (0, r + 5)]):
        U.empty("Light_%d" % i, (p[0], p[1], 4.0))
    body = join(vis, "Velin")
    objs = [body] + col + [o for o in bpy.context.scene.objects if o.type == 'EMPTY']
    export_glb(os.path.join(OUTDIR, "mars_hq.glb"), objs)

def brain():
    """The Great Brain: two lobes of folds, a stem into the cradle, nerves glowing."""
    reset(); m = MM(); p = []
    import random
    random.seed(7)
    for sx in (-1, 1):
        lobe = sphere(m["brain"], (sx * 0.55, 0, 1.3), 1.0, seg=24, rings=16, scale=(0.95, 1.35, 0.85))
        for v in lobe.data.vertices:            # folds
            n = v.co - Vector((sx * 0.55, 0, 1.3))
            f = 1.0 + 0.07 * math.sin(v.co.x * 11 + v.co.y * 7) * math.sin(v.co.z * 9 + v.co.y * 5) + random.uniform(-0.02, 0.02)
            v.co = Vector((sx * 0.55, 0, 1.3)) + n * f
        p.append(lobe)
    p.append(box(m["dark"], (0, 0, 1.4), (0.1, 2.4, 1.2)))         # the cleft between the lobes
    p.append(cyl(m["brain"], (0, -0.3, 0.4), 0.35, 0.9, verts=10, r2=0.5))   # stem
    for i in range(8):
        a = TAU * i / 8
        p.append(U.beam(m["nerve"], (math.cos(a) * 0.4, math.sin(a) * 0.4 - 0.3, 0.5), (math.cos(a) * 1.5, math.sin(a) * 1.5, -0.1), 0.06, 0.06))
    for sx in (-1, 1):             # two pale eyes in the front folds
        p.append(sphere(mat("BrainEye", (0.9, 0.95, 0.6), emit=2.0), (sx * 0.4, 1.25, 1.2), 0.12, seg=8, rings=6))
    o = join(p, "Brain")
    export_glb(os.path.join(OUTDIR, "mozek.glb"), [o])

def pylon():
    reset(); m = MM(); p = []
    p.append(cyl(m["rib"], (0, 0, 0.25), 0.7, 0.5, verts=6, r2=0.5))
    for k in range(3):
        a = TAU * k / 3
        p.append(U.beam(m["bone"], (math.cos(a) * 0.5, math.sin(a) * 0.5, 0.4), (math.cos(a) * 0.15, math.sin(a) * 0.15, 2.6), 0.15, 0.15))
    p.append(cyl(m["nerve"], (0, 0, 1.6), 0.28, 1.8, verts=6, r2=0.08))
    p.append(cyl(m["glow"], (0, 0, 2.8), 0.35, 0.12, verts=8))
    o = join(p, "Pylon")
    export_glb(os.path.join(OUTDIR, "pylon.glb"), [o])

def rocks():
    import random
    random.seed(3)
    for k in range(3):
        reset(); m = MM()
        s = sphere(m["rock"], (0, 0, 0.6), 1.2, seg=10, rings=7, scale=(1.2 + k * 0.3, 1.0, 0.7 + k * 0.2))
        for v in s.data.vertices:
            v.co *= random.uniform(0.82, 1.15)
        s.name = "Rock"
        c = box(mat("Col", (1, 0, 1)), (0, 0, 0.6), (2.2 + k * 0.6, 1.8, 1.2 + k * 0.3)); c.name = "Rock-colonly"
        export_glb(os.path.join(OUTDIR, "mars_rock%d.glb" % k), [s, c])
    reset(); m = MM()
    sp = cyl(m["bone"], (0, 0, 3.0), 0.6, 6.0, verts=6, r2=0.05)
    v = cyl(m["vein"], (0, 0, 2.0), 0.62, 0.15, verts=6)
    c = box(mat("Col", (1, 0, 1)), (0, 0, 2.0), (0.9, 0.9, 4.0)); c.name = "Spire-colonly"
    export_glb(os.path.join(OUTDIR, "mars_spire.glb"), [join([sp, v], "Spire"), c])

hq(); brain(); pylon(); rocks()
