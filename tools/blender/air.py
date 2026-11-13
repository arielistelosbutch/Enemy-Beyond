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

ARGS = [a for a in sys.argv[1:] if not a.startswith("--") and not a.endswith(".png") and "," not in a and a not in ("battleship", "supply", "sokol", "scout", "raider", "harvester")]
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

def sq_lathe(m, prof, n=72, hs=23.0, sm=False):
    """Like lathe() but round a rounded square (the giants' outline, as map_gen._giant_hull):
    prof = [(k, z)], k scales the squircle of half-size hs (k = 0: a single point)."""
    import bmesh
    me = bpy.data.meshes.new("sql")
    o = bpy.data.objects.new("sql", me)
    bpy.context.scene.collection.objects.link(o)
    bm = bmesh.new()
    rows = []
    for (k, z) in prof:
        if k < 1e-5:
            rows.append([bm.verts.new((0, 0, z))])
            continue
        row = []
        for i in range(n):
            a = TAU * i / n
            ca, sa = math.cos(a), math.sin(a)
            row.append(bm.verts.new((math.copysign(hs * k * abs(ca) ** 0.5, ca), math.copysign(hs * k * abs(sa) ** 0.5, sa), z)))
        rows.append(row)
    for r in range(len(rows) - 1):
        a, b = rows[r], rows[r + 1]
        for i in range(n):
            j = (i + 1) % n
            if len(a) == 1 and len(b) == 1:
                continue
            if len(a) == 1:
                bm.faces.new([a[0], b[j], b[i]])
            elif len(b) == 1:
                bm.faces.new([a[i], a[j], b[0]])
            else:
                bm.faces.new([a[i], a[j], b[j], b[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me); bm.free()
    o.data.materials.append(m)
    return smooth(o) if sm else o

def squircle_pt(a, k, hs=23.0):
    ca, sa = math.cos(a), math.sin(a)
    return (math.copysign(hs * k * abs(ca) ** 0.5, ca), math.copysign(hs * k * abs(sa) ** 0.5, sa))

def giant(kind):
    """0.56: the battleship and the supply ship in flight - the same hull you walk round on the ground
    (map_gen._giant_hull): a rounded square 46 m across, the sloped skirt, the dark rim with its lights,
    the deck with the upper halls and the hub's dome; underneath the belly, the folded legs, a red eye.
    Origin at the middle of the height (the ground ship's y 5)."""
    reset()
    supply = kind == "supply"
    hull = mat2("UfoHull", (0.2, 0.17, 0.22), 0.35, 0.7)
    rib = mat2("UfoRib", (0.13, 0.11, 0.15), 0.4, 0.7)
    dark = mat2("UfoDark", (0.07, 0.06, 0.08), 0.4, 0.6)
    glow = mat2("UfoGlow", (1.0, 0.55, 0.2) if supply else (0.85, 0.25, 1.0), emit=5.0)
    dim = mat2("UfoGlowDim", (0.7, 0.35, 0.12) if supply else (0.55, 0.15, 0.7), emit=1.8)
    eye = mat2("UfoEye", (1.0, 0.12, 0.06), emit=5.0)
    Z = -5.0            # the ground ship's y 0
    p = []
    # the belly and the skirt up to the rim (as on the ground: 0.97 at the bottom, 1.04 at the rim)
    p.append(sq_lathe(hull, [(0.0, Z - 0.6), (0.6, Z - 0.5), (0.9, Z - 0.2), (0.97, Z), (1.04, Z + 4.25)]))
    p.append(sq_lathe(dark, [(1.04, Z + 4.25), (1.02, Z + 4.75), (0.98, Z + 4.6)]))
    # 0.69 (Ari: the open deck with the halls looked like map pieces and boxes from the air):
    # a closed upper hull instead - a stepped rounded-square dome, a lit band in every step,
    # the crown on top; the halls you walk round on the ground stay in the map only.
    steps = [(0.98, 0.90, Z + 4.6, Z + 5.0, Z + 5.4), (0.90, 0.72, Z + 5.4, Z + 6.0, Z + 6.4),
             (0.72, 0.50, Z + 6.4, Z + 6.9, Z + 7.3), (0.50, 0.34, Z + 7.3, Z + 7.6, Z + 7.6)]
    for i, (k0, k1, z0, z1, z2) in enumerate(steps):
        p.append(sq_lathe(hull, [(k0, z0), (k1, z1)], sm=True))                        # the slope
        if z2 > z1:
            p.append(sq_lathe(dim if i % 2 else glow, [(k1, z1), (k1 - 0.004, z2)]))      # the lit riser
    p.append(sq_lathe(hull, [(0.34, Z + 7.6), (0.0, Z + 7.6)]))                          # the top
    # seams running down the slopes (on the surface: a hair above each slope)
    for i in range(0, 72, 9):
        a = TAU * i / 72
        for (k0, k1, z0, z1, z2) in steps[:3]:
            x0, y0 = squircle_pt(a, k0 - 0.01)
            x1, y1 = squircle_pt(a, k1 + 0.01)
            p.append(beam(rib, (x0, y0, z0 + 0.08), (x1, y1, z1 + 0.06), 0.35, 0.08))
    # the crown: a dark glass dome with lit slits, a spike of light on top
    top = Z + 7.6
    p.append(lathe(dark, [(0, top), (7.4, top), (6.8, top + 0.6), (4.0, top + 1.9), (1.2, top + 2.6), (0.0, top + 2.7)], 32))
    p.append(torus(glow, (0, 0, top + 0.12), 7.3, 0.14, seg=48))
    p.append(lathe(glow, [(0, top + 2.6), (0.25, top + 2.6), (0.05, top + 3.4), (0, top + 3.4)], 6, sm=False))
    for k in range(8):
        a = TAU * (k + 0.5) / 8
        p.append(bx(glow, (math.cos(a) * 5.0, math.sin(a) * 5.0, top + 1.25), (1.4, 0.12, 0.3), 0.02, rot=(0.0, -0.45, a)))
    if supply:
        # the cargo blisters: two long smooth humps on the flanks, lit along the top
        for sy in (-1, 1):
            p.append(ball(hull, (0, sy * 15.0, Z + 5.9), 1.0, (9.0, 3.2, 1.5), seg=32, rings=12))
            p.append(bx(glow, (0, sy * 15.0, Z + 7.35), (11.0, 0.12, 0.06), 0.0))
            for k in (-1, 1):
                p.append(ball(dim, (k * 8.6, sy * 15.0, Z + 5.9), 0.9, (0.5, 1.6, 0.9), seg=12, rings=8))
    else:
        # the battleship's guns: four turrets on the corners of the hull, barrels outward
        for k in range(4):
            a = TAU * (k + 0.5) / 4
            x, y = squircle_pt(a, 0.8)
            p.append(disc(dark, (x, y, Z + 5.75), 1.6, 0.7, verts=16, b=0.05))
            p.append(ball(hull, (x, y, Z + 6.3), 1.35, (1, 1, 0.7)))
            p.append(tb(rib, (x, y, Z + 6.5), (x * 1.13, y * 1.13, Z + 6.7), 0.24, 10))
            p.append(ball(eye, (x * 1.02, y * 1.02, Z + 6.45), 0.45, (1, 1, 0.6)))
    o = join(p, "Lod_" + kind)
    export_glb(os.path.join(OUTDIR, "ufo_%s.glb" % kind), [o])

ONLY = sys.argv[sys.argv.index("--only") + 1].split(",") if "--only" in sys.argv else []
if not ONLY or "sokol" in ONLY:
    sokol()
for k in ("scout", "raider", "harvester"):
    if not ONLY or k in ONLY:
        ufo(k)
for k in ("battleship", "supply"):
    if not ONLY or k in ONLY:
        giant(k)
print("built air")
if "--gallery" in sys.argv:
    reset()
    names = ["ufo_battleship", "ufo_supply"] if "--giants" in sys.argv else ["sokol", "ufo_scout", "ufo_raider", "ufo_harvester"]
    locs = ((-26, 0, 0), (26, 0, 0)) if "--giants" in sys.argv else ((-33, 0, 0), (-21, 0, 0), (-4, 0, 0), (25, 0, 0))
    for i, n in enumerate(names):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=os.path.join(OUTDIR, n + ".glb"))
        for o in set(bpy.data.objects) - before:
            if o.parent is None:
                o.location = locs[i]
    if "--giants" in sys.argv:
        preview(sys.argv[sys.argv.index("--gallery") + 1], target=(0, 0, -2), dist=150, angle=0.5, height=40, res=(1400, 600))
    else:
        preview(sys.argv[sys.argv.index("--gallery") + 1], target=(-4, 0, 0), dist=80, angle=0.35, height=38, res=(1400, 600))
