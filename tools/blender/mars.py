"""Enemy Beyond - the last mission on Mars (0.52 rework, own designs): the aliens' command centre
("Velín") - a ribbed dome half sunk in red rock with a long entrance tunnel; inside, on a stepped dais,
the cradle of the Great Brain, nerve cables running to the walls, bone columns; three shield pylons.
Also the pylon as a separate model (an actor), red rocks and bone spires.
The collision pieces, the empties (Brain, Pylon_*, Spawn_*, Way_*, Light_*) and all sizes are as before.
The HQ mesh is called "VelinMars" (the old "Velin" block-modeller edits in modely/ were made for the
old part numbers; the box Ari added over the tunnel mouth is now part of the model - a lintel wall).
The Great Brain itself is made by mozek.py.
Run: python3 tools/blender/mars.py <outdir> [--only hq,pylon,rocks] [--gallery out.png]"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
from kit import *
import ufo_ground as U

ARGS = [a for a in sys.argv[1:] if not a.startswith("--") and not a.endswith(".png") and "," not in a and a not in ("hq", "pylon", "rocks")]
OUTDIR = ARGS[0] if ARGS else "."

def MM():
    m = U.M()
    m.update(rock=mat2("MarsRock", (0.42, 0.18, 0.1), 0.95), rock2=mat2("MarsRockDark", (0.27, 0.11, 0.07), 0.95),
             dust=mat2("MarsDust", (0.55, 0.27, 0.15), 1.0),
             vein=mat2("MarsVein", (0.9, 0.2, 0.35), emit=2.5), bone=mat2("MarsBone", (0.55, 0.5, 0.42), 0.7),
             bone2=mat2("MarsBoneDark", (0.36, 0.32, 0.26), 0.75),
             nerve=mat2("BrainNerve", (0.6, 0.3, 1.0), emit=3.0), alloy=mat2("MarsAlloy", (0.16, 0.12, 0.17), 0.35, 0.7))
    return m

def rocky(m, c, r, scale, seed, sub=2):
    """A rough boulder: an ico sphere pushed about."""
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=r)
    o = bpy.context.active_object
    rr = random.Random(seed)
    for v in o.data.vertices:
        v.co *= rr.uniform(0.82, 1.12)
        v.co.x *= scale[0]; v.co.y *= scale[1]; v.co.z *= scale[2]
        if v.co.z < -r * 0.3 * scale[2]:
            v.co.z = -r * 0.3 * scale[2]          # flat underside, sits on the ground
        v.co += Vector(c)
    o.data.materials.append(m)
    return o

def cable(m, a, b, sag, r, n=6):
    """A sagging cable from a to b (segments of tube)."""
    a = Vector(a); b = Vector(b)
    pts = [a.lerp(b, k / n) - Vector((0, 0, sag * math.sin(math.pi * k / n))) for k in range(n + 1)]
    return [tb(m, p, q, r, 8) for p, q in zip(pts, pts[1:])]

# ==================================================================================================
def hq():
    reset(); m = MM(); vis = []; col = []
    r, h, segs = 13.0, 6.0, 24
    rnd = random.Random(11)
    # ---- the floor: plates in rings, violet seams ---------------------------------------------------------------
    vis.append(cyl(m["floor"], (0, 0, 0.06), r, 0.12, verts=segs))
    c = cyl(m["dark"], (0, 0, 0.06), r, 0.12, verts=segs); c.name = "Floor-colonly"; col.append(c)
    for rr_ in (5.2, 8.0, 10.8):
        vis.append(torus(m["glow"] if rr_ == 8.0 else m["rib"], (0, -1.0 if rr_ == 5.2 else 0, 0.125), rr_, 0.04, seg=48))
    for i in range(16):
        a = TAU * i / 16
        vis.append(beam(m["rib"], (math.cos(a) * 5.3, math.sin(a) * 5.3, 0.13), (math.cos(a) * (r - 0.3), math.sin(a) * (r - 0.3), 0.13), 0.06, 0.02))
    # ---- the wall ring (door gap at +Y), a lintel over the tunnel mouth ----------------------------------------
    U.wall_ring(m, r, h, segs, (0,), vis, col, "Wall", thick=0.6)
    w = 2.0 * r * math.tan(math.pi / segs)
    vis.append(bx(m["wall"], (0, r, 3.9 + (h + 0.12 - 3.9) / 2), (w + 0.4, 0.6, h + 0.12 - 3.9), 0.04))
    vis.append(bx(m["rib"], (0, r + 0.32, 4.0), (w + 0.6, 0.1, 0.25), 0.03))
    for k in range(segs):                                                                  # bone ribs up the inner wall
        a = TAU * k / segs + math.pi / 2
        if k == 0:
            continue
        ri = r - 0.4
        vis.append(beam(m["bone2"], (math.cos(a) * ri, math.sin(a) * ri, 0.12), (math.cos(a) * ri, math.sin(a) * ri, h), 0.22, 0.18, bv=0.04))
    # ---- the dome: a smooth shell with bone ribs on it and violet seams between --------------------------------
    prof = []
    for k in range(9):
        t = k / 8
        ang = t * math.pi / 2
        prof.append(((r + 0.3) * math.cos(ang) * (1 - 0.05 * t), h + 0.1 + 5.1 * math.sin(ang)))
    prof[-1] = (0.0, prof[-1][1])
    shell = lathe(m["alloy"], prof, 48)
    vis.append(shell)
    inner = lathe(m["dark"], [(x * 0.97, z - 0.15) for (x, z) in prof], 48)
    for p_ in inner.data.polygons:
        p_.use_smooth = True
    inner.data.flip_normals()
    vis.append(inner)
    for i in range(segs):
        a = TAU * i / segs + math.pi / 2
        ca, sa = math.cos(a), math.sin(a)
        pts = [(ca * (x + 0.25), sa * (x + 0.25), z + 0.12) for (x, z) in prof[:-1]]
        for p0, p1 in zip(pts, pts[1:]):
            vis.append(beam(m["bone"], p0, p1, 0.36, 0.28, bv=0.06))
        a2 = a + math.pi / segs
        c2, s2 = math.cos(a2), math.sin(a2)
        pts2 = [(c2 * (x + 0.06), s2 * (x + 0.06), z + 0.04) for (x, z) in prof[1:-2]]
        for p0, p1 in zip(pts2, pts2[1:]):
            vis.append(beam(m["glow"] if i % 2 == 0 else m["nerve"], p0, p1, 0.07, 0.04))
    vis.append(lathe(m["bone"], [(0, h + 5.0), (1.0, h + 5.0), (0.8, h + 5.6), (0, h + 5.8)], 16))       # apex
    vis.append(tb(m["vein"], (0, 0, h + 5.6), (0, 0, h + 7.4), 0.35, 8, r2=0.03))
    for k in range(3):
        vis.append(torus(m["bone2"], (0, 0, h + 5.8 + k * 0.45), 0.32 - k * 0.07, 0.06, seg=16))
    # ---- the rock skirt: a sloped bank and boulders heaped against the dome ------------------------------------
    vis.append(U.band(m["rock"], r + 3.5, 0.0, r + 0.3, h + 0.2, segs, skip=(0,), name="RockSkirt"))
    for i in range(40):
        a = TAU * i / 40 + rnd.uniform(-0.05, 0.05)
        if abs(math.atan2(math.sin(a - math.pi / 2), math.cos(a - math.pi / 2))) < 0.3:
            continue                                      # keep the tunnel mouth clear
        d = r + rnd.uniform(1.0, 3.6)
        z = (r + 3.5 - d) / 3.2 * (h + 0.2) * 0.8
        vis.append(rocky(m["rock"] if i % 3 else m["rock2"], (math.cos(a) * d, math.sin(a) * d, z * 0.6), rnd.uniform(0.7, 1.5),
                         (1.3, 1.0, 0.8), i))
    # ---- the entrance tunnel along +Y: walls, ribbed bone arches, a plated roof, floor strips -----------------
    L = 10.0
    for sx in (-1, 1):
        x = sx * (w / 2 + 0.3)
        vis.append(bx(m["wall"], (x, r + L / 2, 1.8), (0.6, L, 3.6), 0.04))
        c = box(m["dark"], (x, r + L / 2, 1.8), (0.6, L, 3.6)); c.name = "Tunnel%d-colonly" % (sx + 1); col.append(c)
        for k in range(5):
            vis.append(box(m["vein"], (x - sx * 0.31, r + 1 + k * 2, 2.6), (0.02, 0.6, 0.1)))
        vis.append(bx(m["rock"], (x + sx * 0.9, r + L / 2, 1.4), (1.4, L, 2.8), 0.2))         # rock banked along it
        for k in range(6):
            vis.append(rocky(m["rock2"], (x + sx * 1.4, r + 1.0 + k * 1.7, 2.6), rnd.uniform(0.5, 0.9), (1, 1.2, 0.8), 100 + k + sx * 10))
    vis.append(bx(m["rib"], (0, r + L / 2, 3.75), (w + 1.6, L, 0.3), 0.05))
    for k in range(5):
        vis.append(bx(m["alloy"], (0, r + 1.0 + k * 2.0, 3.93), (w + 1.2, 1.8, 0.06), 0.02))
    vis.append(box(m["floor"], (0, r + L / 2, 0.06), (w, L, 0.12)))
    c = box(m["dark"], (0, r + L / 2, 0.06), (w, L, 0.12)); c.name = "TunnelFloor-colonly"; col.append(c)
    for sx in (-1, 1):
        vis.append(box(m["glow"], (sx * (w / 2 - 0.25), r + L / 2, 0.125), (0.06, L - 0.3, 0.01)))
    for k in range(6):                                                                       # bone arches along the tunnel
        y = r + 0.8 + k * 1.8
        vis.append(bx(m["bone"], (0, y, 3.55), (w + 1.2, 0.3, 0.3), 0.05))
        for sx in (-1, 1):
            vis.append(bx(m["bone"], (sx * (w / 2 + 0.02), y, 1.9), (0.22, 0.3, 3.5), 0.05))
            vis.append(beam(m["bone"], (sx * (w / 2 - 0.05), y, 3.0), (sx * (w / 2 - 0.6), y, 3.45), 0.25, 0.25, bv=0.04))
    vis.append(bx(m["bone"], (0, r + L - 0.1, 3.9), (w + 2.2, 0.5, 0.5), 0.08))              # the mouth's frame
    # ---- the dais: stepped rings, a glowing groove, the cradle with claws ---------------------------------------
    vis.append(lathe(m["rib"], [(0, 0.0), (4.0, 0.0), (4.0, 0.3), (3.8, 0.32), (3.8, 0.58), (3.6, 0.6), (3.6, 0.8), (0, 0.8)], 32, sm=False))
    for o in vis[-1:]:
        for v in o.data.vertices:
            v.co.y -= 2.0
    c = cyl(m["dark"], (0, -2.0, 0.4), 4.0, 0.8, verts=16); c.name = "Dais-colonly"; col.append(c)
    vis.append(torus(m["glow"], (0, -2.0, 0.81), 3.0, 0.05, seg=40))
    vis.append(lathe(m["dark"], [(0, 0.8), (2.2, 0.8), (2.0, 1.1), (1.6, 1.4), (1.2, 1.42), (0, 1.3)], 28))
    for o in vis[-1:]:
        for v in o.data.vertices:
            v.co.y -= 2.0
    for k in range(6):                                                                      # claws of the cradle
        a = TAU * k / 6
        ca, sa = math.cos(a), math.sin(a)
        pts = [(ca * 1.8, sa * 1.8 - 2.0, 1.0), (ca * 2.1, sa * 2.1 - 2.0, 1.6), (ca * 1.7, sa * 1.7 - 2.0, 2.2), (ca * 1.2, sa * 1.2 - 2.0, 2.4)]
        for i, (p0, p1) in enumerate(zip(pts, pts[1:])):
            vis.append(tb(m["bone"], p0, p1, 0.16 - i * 0.04, 10, r2=0.12 - i * 0.04))
    # nerves from the cradle to the walls, sagging over the floor and up the walls
    for i in range(10):
        a = TAU * i / 10
        p0 = (math.cos(a) * 1.8, -2.0 + math.sin(a) * 1.8, 1.2)
        p1 = (math.cos(a) * (r - 0.6), math.sin(a) * (r - 0.6) - 1.0, 0.25 if i % 2 else h - 0.5)
        vis.extend(cable(m["nerve"], p0, p1, 0.6 if i % 2 == 0 else 0.3, 0.11, n=7))
    # stairs to the dais (front)
    for k in range(3):
        vis.append(bx(m["rib"], (0, 2.0 + 0.4 * (2 - k), 0.13 + k * 0.27), (2.4, 0.5, 0.27), 0.03))
        vis.append(box(m["glow"], (0, 2.0 + 0.4 * (2 - k) + 0.26, 0.24 + k * 0.27), (2.2, 0.02, 0.03)))
    # bone columns round the hall, ringed, veins up them
    for i in range(8):
        a = TAU * (i + 0.5) / 8 + math.pi / 2
        x, y = math.cos(a) * 8.5, math.sin(a) * 8.5
        if y > 6:
            continue
        vis.append(smooth(cyl(m["bone"], (x, y, h / 2), 0.45, h, verts=12, r2=0.3)))
        for k in range(4):
            vis.append(torus(m["bone2"], (x, y, 0.8 + k * 1.4), 0.44 - k * 0.035, 0.06, seg=14))
        vis.append(tb(m["vein"], (x + 0.38, y, 0.3), (x + 0.26, y, h - 0.3), 0.04, 6))
        vis.append(lathe(m["bone2"], [(0, h - 0.2), (0.7, h - 0.2), (0.7, h), (0, h)], 12, sm=False, cx=x, cy=y))
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
    body = join(vis, "VelinMars")
    objs = [body] + col + [o for o in bpy.context.scene.objects if o.type == 'EMPTY']
    export_glb(os.path.join(OUTDIR, "mars_hq.glb"), objs)

def pylon():
    """A shield pylon: a heavy base, three clawed bone legs meeting at the top, a glowing nerve core
    between them, a violet crown. 2.9 m tall."""
    reset(); m = MM(); p = []
    p.append(lathe(m["rib"], [(0, 0.0), (0.75, 0.0), (0.75, 0.15), (0.6, 0.3), (0.5, 0.5), (0, 0.5)], 12, sm=False))
    p.append(torus(m["glow"], (0, 0, 0.32), 0.62, 0.025, seg=24))
    for k in range(3):
        a = TAU * k / 3
        ca, sa = math.cos(a), math.sin(a)
        pts = [(ca * 0.5, sa * 0.5, 0.4), (ca * 0.55, sa * 0.55, 1.2), (ca * 0.38, sa * 0.38, 2.0), (ca * 0.15, sa * 0.15, 2.6)]
        for i, (p0, p1) in enumerate(zip(pts, pts[1:])):
            p.append(tb(m["bone"], p0, p1, 0.11 - i * 0.02, 10, r2=0.09 - i * 0.02))
            p.append(ball(m["bone2"], p1, 0.1 - i * 0.02))
        p.append(tb(m["bone2"], (ca * 0.6, sa * 0.6, 0.15), (ca * 0.85, sa * 0.85, 0.02), 0.07, 8, r2=0.02))   # claw foot
    p.append(lathe(m["nerve"], [(0, 0.5), (0.22, 0.6), (0.3, 1.2), (0.24, 1.9), (0.1, 2.5), (0, 2.6)], 16))
    for k in range(5):
        p.append(torus(m["dark"], (0, 0, 0.8 + k * 0.32), 0.3 - abs(k - 2) * 0.03, 0.02, seg=16))
    p.append(lathe(m["alloy"], [(0, 2.55), (0.3, 2.6), (0.42, 2.75), (0.3, 2.85), (0, 2.9)], 16))
    p.append(torus(m["glow"], (0, 0, 2.75), 0.42, 0.03, seg=20))
    p.append(ball(m["glow"], (0, 0, 2.92), 0.07))
    o = join(p, "Pylon")
    export_glb(os.path.join(OUTDIR, "pylon.glb"), [o])

def rocks():
    rr = random.Random(3)
    for k in range(3):
        reset(); m = MM(); p = []
        p.append(rocky(m["rock"], (0, 0, 0.55 + k * 0.1), 1.2, (1.2 + k * 0.3, 1.0, 0.7 + k * 0.2), 30 + k, sub=3))
        for j in range(4 + k):                                    # strata and smaller stones around it
            a = rr.uniform(0, TAU)
            d = rr.uniform(1.1, 1.6) + k * 0.25
            p.append(rocky(m["rock2"], (math.cos(a) * d, math.sin(a) * d * 0.8, 0.12), rr.uniform(0.15, 0.35), (1.2, 1, 0.7), 50 + j + k * 10, sub=1))
        s = join(p, "Rock")
        c = box(mat("Col", (1, 0, 1)), (0, 0, 0.6), (2.2 + k * 0.6, 1.8, 1.2 + k * 0.3)); c.name = "Rock-colonly"
        export_glb(os.path.join(OUTDIR, "mars_rock%d.glb" % k), [s, c])
    # a bone spire: a twisted horn with vein bands and a cracked tip
    reset(); m = MM(); p = []
    prof = [(0.6 * (1 - t / 10) ** 1.3 + 0.02, t * 0.6) for t in range(11)]
    sp = lathe(m["bone"], [(0, 0)] + prof + [(0, 6.05)], 20)
    for v in sp.data.vertices:
        k = 1.0 + 0.22 * math.cos(5 * math.atan2(v.co.y, v.co.x))     # five ridges ...
        tw = v.co.z * 0.35                                            # ... twisting up the horn
        x, y = v.co.x * k, v.co.y * k
        v.co.x = x * math.cos(tw) - y * math.sin(tw) + 0.05 * v.co.z * v.co.z / 6
        v.co.y = x * math.sin(tw) + y * math.cos(tw)
    p.append(sp)
    for k, z in enumerate((0.8, 2.0, 3.2)):
        rad = 0.6 * (1 - z / 6) ** 1.3 + 0.03
        p.append(torus(m["vein"], (0.05 * z * z / 6, 0, z), rad, 0.03 + 0.02 * (k == 0), seg=12))
    p.append(rocky(m["rock"], (0, 0, 0.1), 0.8, (1.2, 1.2, 0.5), 77))
    c = box(mat("Col", (1, 0, 1)), (0, 0, 2.0), (0.9, 0.9, 4.0)); c.name = "Spire-colonly"
    export_glb(os.path.join(OUTDIR, "mars_spire.glb"), [join(p, "Spire"), c])

ONLY = sys.argv[sys.argv.index("--only") + 1].split(",") if "--only" in sys.argv else []
for k, f in dict(hq=hq, pylon=pylon, rocks=rocks).items():
    if not ONLY or k in ONLY:
        f()
print("built mars")
if "--gallery" in sys.argv:
    out = sys.argv[sys.argv.index("--gallery") + 1]
    reset()
    for f, loc in (("mars_hq.glb", (0, 0, 0)), ("pylon.glb", (-6, 30, 0)), ("mars_rock0.glb", (6, 30, 0)), ("mars_rock2.glb", (11, 27, 0)),
                   ("mars_spire.glb", (-11, 27, 0))):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=os.path.join(OUTDIR, f))
        for o in set(bpy.data.objects) - before:
            if "colonly" in o.name:
                o.hide_render = True
            if o.parent is None:
                o.location = loc
    preview(out, target=(0, 6, 3.0), dist=46, angle=0.25, height=14, res=(1400, 900))
