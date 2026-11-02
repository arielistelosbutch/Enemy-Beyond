"""Air war (own designs): the interceptor "Sokol" and three UFO hulls -
scout (small disc), raider (medium lens with a ring), harvester (large manta).
Nose / front = +Y (Godot -Z)."""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from common import *

OUTDIR = sys.argv[-1]
PI2 = math.pi / 2

def wedge(m, pts_top, z0, z1):
    """Flat extruded polygon (for wings): pts in XY, thickness z0..z1."""
    import bmesh
    me = bpy.data.meshes.new("w")
    o = bpy.data.objects.new("w", me)
    bpy.context.scene.collection.objects.link(o)
    bm = bmesh.new()
    vb = [bm.verts.new((x, y, z0)) for x, y in pts_top]
    vt = [bm.verts.new((x, y, z1)) for x, y in pts_top]
    bm.faces.new(vb[::-1]); bm.faces.new(vt)
    n = len(pts_top)
    for i in range(n):
        bm.faces.new([vb[i], vb[(i + 1) % n], vt[(i + 1) % n], vt[i]])
    bm.to_mesh(me); bm.free()
    o.data.materials.append(m)
    return o

def sokol():
    reset()
    hull = mat("JetGrey", (0.28, 0.30, 0.32), rough=0.5)
    dark = mat("JetDark", (0.1, 0.11, 0.12), rough=0.5)
    glass = mat("Canopy", (0.15, 0.25, 0.3), rough=0.05)
    glow = mat("Afterburn", (1.0, 0.55, 0.2), emit=4.0)
    red = mat("NavRed", (1.0, 0.1, 0.05), emit=6.0)
    grn = mat("NavGreen", (0.1, 1.0, 0.2), emit=6.0)
    stripe = mat("Stripe", (0.6, 0.45, 0.1))
    p = []
    p.append(cyl(hull, (0, 0.2, 0), 0.45, 7.0, verts=8, rot=(-PI2, 0, 0), r2=0.35))          # fuselage
    p.append(cyl(hull, (0, 4.3, 0), 0.35, 1.6, verts=8, rot=(-PI2, 0, 0), r2=0.02))          # nose cone
    p.append(sphere(glass, (0, 2.5, 0.38), 0.4, seg=8, rings=5, scale=(0.75, 2.0, 0.6)))     # canopy
    p.append(wedge(hull, [(0.4, 1.2), (4.2, -2.0), (4.2, -2.8), (0.4, -2.6)], -0.06, 0.06))  # wings
    p.append(wedge(hull, [(-0.4, 1.2), (-0.4, -2.6), (-4.2, -2.8), (-4.2, -2.0)], -0.06, 0.06))
    p.append(wedge(stripe, [(2.0, -0.6), (3.6, -1.9), (3.6, -2.2), (2.0, -1.0)], 0.061, 0.07))
    p.append(wedge(stripe, [(-2.0, -0.6), (-2.0, -1.0), (-3.6, -2.2), (-3.6, -1.9)], 0.061, 0.07))
    for x in (0.9, -0.9):                                                                     # twin tails
        t = box(hull, (x, -2.9, 0.9), (0.08, 1.2, 1.4), rot=(0.4, 0, 0.25 * (1 if x > 0 else -1)))
        p.append(t)
    p.append(wedge(hull, [(0.3, -2.6), (1.9, -3.4), (1.9, -3.8), (0.3, -3.6)], -0.04, 0.04))  # stabilisers
    p.append(wedge(hull, [(-0.3, -2.6), (-0.3, -3.6), (-1.9, -3.8), (-1.9, -3.4)], -0.04, 0.04))
    for x in (0.55, -0.55):                                                                   # intakes
        p.append(box(dark, (x, 0.6, -0.15), (0.3, 1.6, 0.5)))
    p.append(cyl(dark, (0, -3.35, 0), 0.38, 0.4, verts=8, rot=(-PI2, 0, 0)))
    p.append(cyl(glow, (0, -3.56, 0), 0.3, 0.04, verts=8, rot=(-PI2, 0, 0)))
    p.append(box(red, (-4.2, -2.4, 0), (0.08, 0.2, 0.08)))
    p.append(box(grn, (4.2, -2.4, 0), (0.08, 0.2, 0.08)))
    for x in (2.0, -2.0):                                                                     # missiles under the wings
        p.append(cyl(mat("Missile", (0.75, 0.75, 0.72)), (x, -0.6, -0.22), 0.09, 2.0, verts=6, rot=(-PI2, 0, 0)))
    o = join(p, "Sokol")
    export_glb(os.path.join(OUTDIR, "sokol.glb"), [o])
    if "--preview" in sys.argv:
        preview(os.path.join(OUTDIR, "..", "..", "tools", "sokol_prev.png"), target=(0, 0, 0), dist=14, angle=2.4, height=4)

def ufo(kind):
    reset()
    hull = mat("UfoHull", (0.42, 0.44, 0.47), rough=0.3)
    dark = mat("UfoDark", (0.12, 0.12, 0.15), rough=0.3)
    glow = mat("UfoGlow", (0.6, 0.3, 1.0), emit=5.0)
    eye = mat("UfoEye", (0.3, 1.0, 0.45), emit=5.0)
    p = []
    if kind == "scout":
        p.append(cyl(hull, (0, 0, 0), 4.0, 0.9, verts=16, r2=2.0))
        p.append(cyl(hull, (0, 0, -0.7), 2.0, 0.5, verts=16, r2=4.0))
        p.append(sphere(dark, (0, 0, 0.6), 1.4, seg=12, rings=6, scale=(1, 1, 0.55)))
        for i in range(8):
            a = i / 8 * math.tau
            p.append(box(glow, (math.cos(a) * 3.3, math.sin(a) * 3.3, -0.2), (0.4, 0.4, 0.15), rot=(0, 0, a)))
        p.append(cyl(eye, (0, 0, -0.98), 0.9, 0.06, verts=12))
    elif kind == "raider":
        p.append(sphere(hull, (0, 0, 0), 6.0, seg=20, rings=8, scale=(1, 1, 0.28)))
        p.append(cyl(dark, (0, 0, 0), 7.8, 0.35, verts=24, r2=7.8))
        p.append(cyl(hull, (0, 0, 0), 7.2, 0.4, verts=24, r2=7.2))
        for i in range(12):
            a = i / 12 * math.tau
            p.append(box(glow, (math.cos(a) * 7.6, math.sin(a) * 7.6, 0), (0.6, 0.6, 0.38), rot=(0, 0, a)))
        p.append(sphere(dark, (0, 0, 1.6), 2.2, seg=12, rings=6, scale=(1, 1, 0.5)))
        for x in (2.5, -2.5):
            p.append(sphere(eye, (x, 3.5, -0.6), 0.6, seg=8, rings=5, scale=(1, 1, 0.5)))
    else:   # harvester: a long manta shape
        p.append(sphere(hull, (0, 0, 0), 9.0, seg=20, rings=8, scale=(1.5, 1.0, 0.25)))
        p.append(sphere(dark, (0, 3.0, 1.4), 3.5, seg=12, rings=6, scale=(1.3, 1.6, 0.5)))
        for x in (1, -1):
            p.append(box(hull, (x * 13.5, -2.0, 0), (6.0, 3.0, 0.6), rot=(0, 0, -0.35 * x)))
            p.append(box(glow, (x * 16.0, -3.0, 0), (1.0, 1.0, 0.7), rot=(0, 0, -0.35 * x)))
        for i in range(7):
            p.append(box(glow, (-6 + i * 2, -8.6, 0), (1.0, 0.4, 0.5)))
        p.append(cyl(eye, (0, 0, -2.2), 2.5, 0.1, verts=12))
        p.append(box(dark, (0, -9.5, 0.6), (5.0, 1.5, 1.2)))
    o = join(p, "Ufo_" + kind)
    export_glb(os.path.join(OUTDIR, "ufo_%s.glb" % kind), [o])

sokol()
for k in ("scout", "raider", "harvester"):
    ufo(k)
if "--gallery" in sys.argv:
    reset()
    for i, n in enumerate(["sokol", "ufo_scout", "ufo_raider", "ufo_harvester"]):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=os.path.join(OUTDIR, n + ".glb"))
        for o in set(bpy.data.objects) - before:
            if o.parent is None:
                o.location = (-30 + i * 20, 0, 0)
    preview(sys.argv[sys.argv.index("--gallery") + 1], target=(0, 0, 0), dist=60, angle=0.5, height=22, res=(960, 400))
