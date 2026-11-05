"""Air war (0.52 rework, own designs): the interceptor "Sokol" and three flying UFO hulls -
scout (small lens), raider (a lens inside a ring on spokes), harvester (a long manta).
Same sizes as before: Sokol nose at y +5.1, nozzle at -3.6, span 8.4; scout r 4, raider r 7.8,
harvester about 33 m across. Nose / front = +Y (Godot -Z), origin in the middle.
The UFOs: dark violet-black alloy, violet light in the seams, a red eye underneath (Ari's pictures);
no blades or spikes. Mesh names are new ("Stihacka", "Lod_*") - the block-modeller edits in modely/
were made for the old part numbers.
Run: python3 air.py OUTDIR [--gallery out.png]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from kit import *

ARGS = [a for a in sys.argv[1:] if not a.startswith("--") and not a.endswith(".png")]
OUTDIR = ARGS[0] if ARGS else "."

def sokol():
    reset()
    hull = mat2("JetGrey", (0.3, 0.32, 0.34), 0.45, 0.4)
    hull2 = mat2("JetPanel", (0.24, 0.26, 0.28), 0.5, 0.4)
    dark = mat2("JetDark", (0.09, 0.1, 0.11), 0.5, 0.5)
    steel = mat2("JetSteel", (0.4, 0.4, 0.42), 0.3, 0.85)
    glass = mat2("CanopyGlass", (0.12, 0.2, 0.26), 0.05, 0.4)
    frame = mat2("JetFrame", (0.12, 0.13, 0.14), 0.5, 0.5)
    glow = mat2("Afterburn", (1.0, 0.55, 0.2), emit=4.0)
    red = mat2("NavRed", (1.0, 0.1, 0.05), emit=6.0)
    grn = mat2("NavGreen", (0.1, 1.0, 0.2), emit=6.0)
    stripe = mat2("Stripe", (0.6, 0.45, 0.1), 0.6)
    white = mat2("JetStencil", (0.75, 0.75, 0.72), 0.7)
    missile = mat2("Missile", (0.72, 0.72, 0.68), 0.5, 0.3)
    p = []
    # fuselage: a lofted body, the nose cone, the spine behind the canopy
    p.append(loft(hull, [(5.1, 0, 0.0, 0.02, 0.02), (4.6, 0, 0.0, 0.16, 0.15), (3.7, 0, 0.02, 0.36, 0.33), (2.6, 0, 0.05, 0.5, 0.45),
                         (1.2, 0, 0.05, 0.62, 0.48), (-0.5, 0, 0.05, 0.66, 0.46), (-2.4, 0, 0.05, 0.6, 0.42),
                         (-3.3, 0, 0.05, 0.5, 0.38)], verts=20))
    p.append(loft(dark, [(5.12, 0, 0.0, 0.0, 0.0), (5.1, 0, 0.0, 0.04, 0.04), (4.55, 0, 0.0, 0.17, 0.16)], verts=12))      # radome tip
    p.append(loft(hull2, [(1.9, 0, 0.35, 0.2, 0.15), (0.8, 0, 0.42, 0.34, 0.2), (-2.6, 0, 0.36, 0.3, 0.16), (-3.2, 0, 0.3, 0.2, 0.1)], verts=14))
    # the canopy: bubble glass in a frame
    p.append(loft(glass, [(3.55, 0, 0.32, 0.05, 0.05), (3.1, 0, 0.36, 0.28, 0.26), (2.3, 0, 0.4, 0.36, 0.36), (1.4, 0, 0.38, 0.33, 0.3),
                          (0.95, 0, 0.36, 0.22, 0.18)], verts=18))
    p.append(torus(frame, (0, 2.5, 0.38), 0.36, 0.025, rot=(PI2, 0, 0), seg=18))
    p.append(ball(dark, (0, 2.0, 0.42), 0.12, (1, 1.2, 1)))                                     # the pilot's helmet
    # intakes on both sides, lofted ducts
    for x in (1, -1):
        p.append(loft(hull2, [(1.9, 0.72 * x, -0.12, 0.22, 0.3), (1.0, 0.7 * x, -0.12, 0.24, 0.32), (-1.0, 0.55 * x, -0.1, 0.22, 0.3)], verts=12, cap=False))
        p.append(bx(dark, (0.72 * x, 1.91, -0.12), (0.36, 0.04, 0.5), 0.02))
        p.append(bx(hull, (0.98 * x, 1.6, -0.12), (0.04, 0.6, 0.62), 0.01, rot=(0, 0, -0.15 * x)))            # splitter plate
    # wings: swept, with leading edge flaps, a panel line and a stripe
    for x in (1, -1):
        p.append(plate(hull, [(0.45 * x, 1.4), (4.2 * x, -1.9), (4.2 * x, -2.7), (0.45 * x, -2.6)], -0.05, 0.05, b=0.02))
        p.append(plate(hull2, [(0.8 * x, 0.9), (3.8 * x, -1.75), (3.8 * x, -1.95), (0.8 * x, 0.6)], 0.05, 0.06))
        p.append(plate(stripe, [(2.0 * x, -0.6), (3.6 * x, -1.95), (3.6 * x, -2.2), (2.0 * x, -1.0)], 0.051, 0.065))
        p.append(plate(dark, [(1.0 * x, -2.35), (3.9 * x, -2.45), (3.9 * x, -2.68), (1.0 * x, -2.58)], 0.051, 0.06))   # flaperons
        p.append(tb(steel, (4.22 * x, -1.6, 0), (4.22 * x, -2.9, 0), 0.05, 8))                                   # wingtip rail
        p.append(box(red if x < 0 else grn, (4.24 * x, -2.4, 0.06), (0.06, 0.18, 0.06)))
        # a missile under each wing on a pylon, and one at the tip
        p.append(bx(dark, (2.0 * x, -0.6, -0.12), (0.06, 0.8, 0.12), 0.01))
        p.append(tb(missile, (2.0 * x, 0.45, -0.24), (2.0 * x, -1.6, -0.24), 0.08, 10))
        p.append(tb(red, (2.0 * x, 0.45, -0.24), (2.0 * x, 0.62, -0.24), 0.08, 10, r2=0.01))
        for a in range(4):
            aa = a * PI2 + 0.785
            p.append(bx(dark, (2.0 * x + math.cos(aa) * 0.12, -1.45, -0.24 + math.sin(aa) * 0.12), (0.12, 0.25, 0.01), 0.002, rot=(0, -aa, 0)))
        # the twin tails, canted
        fin = plate_v(hull, [(-1.9, 0.3), (-3.3, 0.3), (-3.45, 1.6), (-2.9, 1.6)], -0.04, 0.04, b=0.01)
        for v in fin.data.vertices:
            v.co.x += 0.9 * x + (v.co.z - 0.3) * 0.3 * x
        p.append(fin)
        p.append(box(white, (0.9 * x + 0.3 * x + 0.05 * x, -3.0, 1.1), (0.01, 0.3, 0.2)))
        # stabilisers
        p.append(plate(hull, [(0.4 * x, -2.6), (1.9 * x, -3.4), (1.9 * x, -3.8), (0.4 * x, -3.6)], -0.04, 0.04, b=0.01))
    # the engine nozzle with petals and the afterburner glow
    p.append(disc(dark, (0, -3.35, 0.05), 0.42, 0.3, 'y', verts=20, r2=0.36))
    for k in range(14):
        a = TAU * k / 14
        p.append(bx(steel, (math.cos(a) * 0.36, -3.55, 0.05 + math.sin(a) * 0.36), (0.16, 0.25, 0.025), 0.004, rot=(0, -a + PI2, 0)))
    p.append(disc(glow, (0, -3.56, 0.05), 0.3, 0.04, 'y', verts=16))
    p.append(ball(white, (0, -1.0, 0.55), 0.03))
    p.append(tb(steel, (0.3, 0.8, -0.45), (0.3, 0.8, -0.75), 0.012, 6))                      # antenna under the belly
    p.append(disc(dark, (0.45, 3.1, 0.15), 0.06, 0.4, 'y', verts=8))                          # the cannon port
    o = join(p, "Stihacka")
    export_glb(os.path.join(OUTDIR, "sokol.glb"), [o])

def ufo(kind):
    reset()
    # dark violet alloy, violet light, a red eye - as in Ari's pictures (the same palette as ufo_ground)
    hull = mat2("UfoHull", (0.2, 0.17, 0.22), 0.35, 0.7)
    rib = mat2("UfoRib", (0.13, 0.11, 0.15), 0.4, 0.7)
    dark = mat2("UfoDark", (0.07, 0.06, 0.08), 0.4, 0.6)
    glow = mat2("UfoGlow", (0.85, 0.25, 1.0), emit=5.0)
    dim = mat2("UfoGlowDim", (0.55, 0.15, 0.7), emit=1.8)
    eye = mat2("UfoEye", (1.0, 0.12, 0.06), emit=5.0)
    p = []
    def seams(r0, z0, r1, z1, n, w=0.06, phase=0.0, m=None):
        for i in range(n):
            a = TAU * (i + phase) / n
            ca, sa = math.cos(a), math.sin(a)
            p.append(beam(m or glow, (ca * r0, sa * r0, z0), (ca * r1, sa * r1, z1), w, w))
    if kind == "scout":
        p.append(lathe(hull, [(0, -0.75), (1.6, -0.72), (3.2, -0.45), (4.0, -0.08), (4.05, 0.05), (3.6, 0.32), (2.2, 0.58), (1.3, 0.62), (0, 0.62)], 40))
        p.append(lathe(rib, [(3.95, -0.12), (4.12, -0.04), (4.12, 0.07), (3.95, 0.14)], 40, sm=False))
        p.append(lathe(dark, [(0, 0.55), (1.45, 0.55), (1.35, 0.85), (0.9, 1.1), (0, 1.18)], 28))     # the dome
        seams(1.5, 0.66, 3.55, 0.36, 12)
        seams(1.0, 0.78, 1.35, 0.6, 8, 0.04, 0.5, m=dim)
        for i in range(16):                                                                      # rim lights
            a = TAU * (i + 0.5) / 16
            p.append(bx(glow if i % 2 else dim, (math.cos(a) * 4.1, math.sin(a) * 4.1, 0.0), (0.12, 0.45, 0.08), 0.02, rot=(0, 0, a)))
        for i in range(6):                                                                      # thruster pads underneath
            a = TAU * i / 6
            p.append(disc(rib, (math.cos(a) * 2.6, math.sin(a) * 2.6, -0.62), 0.38, 0.12, verts=14, b=0.03))
            p.append(disc(dim, (math.cos(a) * 2.6, math.sin(a) * 2.6, -0.69), 0.26, 0.04, verts=14))
        p.append(torus(rib, (0, 0, -0.76), 1.05, 0.08, seg=24))
        p.append(lathe(eye, [(0, -0.86), (0.8, -0.8), (0.9, -0.74), (0, -0.74)], 24))
        for k in range(3):
            p.append(torus(dark, (0, 0, 0.6 + k * 0.001), 1.45 + k * 0.85, 0.04, seg=36))
    elif kind == "raider":
        p.append(lathe(hull, [(0, -1.6), (2.2, -1.5), (4.5, -1.0), (6.0, -0.3), (6.1, 0.1), (5.2, 0.8), (3.0, 1.45), (0, 1.6)], 44))
        p.append(lathe(dark, [(0, 1.4), (2.3, 1.4), (2.1, 2.0), (1.3, 2.5), (0, 2.65)], 32))      # dome
        p.append(lathe(rib, [(7.0, -0.32), (7.9, -0.25), (8.0, 0.0), (7.9, 0.25), (7.0, 0.32), (6.9, 0.0)], 48, sm=False))  # the ring
        for i in range(8):                                                                       # spokes from hull to ring
            a = TAU * (i + 0.5) / 8
            ca, sa = math.cos(a), math.sin(a)
            p.append(beam(rib, (ca * 5.6, sa * 5.6, 0.0), (ca * 7.1, sa * 7.1, 0.0), 0.5, 0.35, bv=0.06))
            p.append(beam(glow, (ca * 5.7, sa * 5.7, 0.19), (ca * 7.05, sa * 7.05, 0.19), 0.08, 0.04))
        for i in range(24):                                                                      # ring lights
            a = TAU * i / 24
            p.append(bx(glow if i % 2 else dim, (math.cos(a) * 8.0, math.sin(a) * 8.0, 0.0), (0.12, 0.8, 0.22), 0.03, rot=(0, 0, a)))
        seams(2.4, 1.48, 5.3, 0.86, 16)
        seams(2.3, -1.45, 4.6, -0.95, 12, 0.08, 0.5, m=dim)
        for k in range(3):
            p.append(torus(dark, (0, 0, 1.25 - k * 0.38), 3.6 + k * 0.85, 0.05, seg=40))
        for i in range(10):                                                                      # slits round the dome
            a = TAU * i / 10
            p.append(bx(glow, (math.cos(a) * 1.85, math.sin(a) * 1.85, 2.05), (0.08, 0.5, 0.12), 0.02, rot=(0, 0.6, a)))
        for x in (2.5, -2.5):                                                                    # two red eyes at the front
            p.append(ball(eye, (x, 3.6, -0.75), 0.55, (1, 1, 0.45)))
        p.append(lathe(eye, [(0, -1.75), (1.4, -1.66), (1.55, -1.56), (0, -1.56)], 28))
        p.append(torus(rib, (0, 0, -1.6), 1.7, 0.12, seg=28))
    else:   # harvester: a long manta with swept wings and a dorsal hump
        p.append(loft(hull, [(11.0, 0, 0.0, 0.8, 0.4), (9.5, 0, 0.1, 4.0, 1.2), (6.0, 0, 0.2, 7.5, 2.1), (1.0, 0, 0.2, 9.2, 2.4),
                             (-4.5, 0, 0.1, 8.8, 2.0), (-8.6, 0, 0.0, 7.0, 1.3), (-9.6, 0, 0.0, 5.0, 0.8)], verts=32))
        p.append(loft(dark, [(7.5, 0, 1.4, 0.5, 0.3), (6.0, 0, 1.6, 3.0, 1.5), (2.0, 0, 1.8, 4.6, 2.0), (-1.5, 0, 1.7, 4.0, 1.7),
                             (-4.0, 0, 1.4, 2.2, 1.0)], verts=24))                                  # the hump
        for x in (1, -1):
            w = plate(hull, [(6.0 * x, 5.0), (12.0 * x, 1.0), (17.0 * x, -3.0), (16.5 * x, -5.0), (12.5 * x, -5.2), (9.0 * x, -7.0), (6.0 * x, -6.0)], -0.5, 0.5, b=0.25)
            for v in w.data.vertices:             # thinner towards the tips
                v.co.z *= max(0.35, 1.0 - (abs(v.co.x) - 6.0) / 14.0)
            p.append(w)
            p.append(plate(glow, [(15.6 * x, -2.8), (16.9 * x, -3.2), (16.5 * x, -4.8), (15.4 * x, -4.0)], -0.5, 0.5))   # wingtip lights
            p.append(plate(rib, [(8.5 * x, 3.4), (16.0 * x, -2.6), (15.8 * x, -3.2), (8.2 * x, 2.6)], 0.38, 0.48))
            p.append(plate(dim, [(9.0 * x, -6.2), (12.3 * x, -4.7), (12.3 * x, -4.95), (9.0 * x, -6.5)], 0.3, 0.42))
            for k in range(5):                                                                       # vents along the flanks
                p.append(bx(glow if k % 2 == 0 else dim, (x * (6.6 + k * 0.5), -0.5 - k * 0.9, 1.75 - k * 0.12), (0.8, 0.12, 0.1), 0.03,
                            rot=(0, 0, 0.6 * x)))
            # seams along the back, curving out to the wings
            p.append(beam(glow, (2.5 * x, 7.0, 1.4), (6.5 * x, 1.5, 2.2), 0.1, 0.1))
            p.append(beam(glow, (6.5 * x, 1.5, 2.2), (11.0 * x, -3.0, 1.5), 0.1, 0.1))
            p.append(beam(dim, (4.0 * x, -4.5, 1.9), (10.0 * x, -6.0, 1.0), 0.08, 0.08))
        for i in range(7):                                                                           # the engine row at the back
            p.append(bx(rib, (-6 + i * 2, -8.7, 0.1), (1.6, 0.8, 0.9), 0.15))
            p.append(bx(glow, (-6 + i * 2, -9.12, 0.1), (1.1, 0.06, 0.5), 0.02))
        for i in range(8):                                                                           # slits on the hump
            p.append(bx(glow, (-2.8 + i * 0.8, 6.2, 2.6), (0.12, 0.6, 0.12), 0.03, rot=(0.5, 0, 0)))
        p.append(lathe(eye, [(0, -2.6), (2.2, -2.45), (2.5, -2.25), (0, -2.25)], 32))
        p.append(torus(rib, (0, 0, -2.3), 2.7, 0.18, seg=32))
        for x in (1, -1):
            p.append(ball(eye, (1.4 * x, 9.0, 0.5), 0.45, (1.4, 1, 0.5)))
    o = join(p, "Lod_" + kind)
    export_glb(os.path.join(OUTDIR, "ufo_%s.glb" % kind), [o])

sokol()
for k in ("scout", "raider", "harvester"):
    ufo(k)
print("built air")
if "--gallery" in sys.argv:
    reset()
    for i, n in enumerate(["sokol", "ufo_scout", "ufo_raider", "ufo_harvester"]):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=os.path.join(OUTDIR, n + ".glb"))
        for o in set(bpy.data.objects) - before:
            if o.parent is None:
                o.location = ((-33, 0, 0), (-21, 0, 0), (-4, 0, 0), (25, 0, 0))[i]
    preview(sys.argv[sys.argv.index("--gallery") + 1], target=(-4, 0, 0), dist=80, angle=0.35, height=38, res=(1400, 600))
