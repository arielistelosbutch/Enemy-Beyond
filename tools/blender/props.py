"""Props (0.52 rework, own designs): the dairy cow and the mercenaries' VTOL transport "Kondor".
Same sizes, origins and axes as before (nose / head +Y = Godot -Z, origin on the ground).
The Kondor's cabin matches the collision boxes in map_gen._skyranger: walls at x = +-1.6, roof at 2.9,
floor 0.2, length 8 (y -4..4), wings at height 2.0 / x 1.5..6.5, the rear ramp down at -Y.
Mesh names are new ("Krava", "Kondor"): the block-modeller edits in modely/ were made for the old
meshes' part numbers and must not land on the new ones.
Run: python3 tools/blender/props.py <outdir> [--only cow,dropship] [--gallery out.png]"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
from kit import *

ARGS = [a for a in sys.argv[1:] if not a.startswith("--") and not a.endswith(".png") and "," not in a]
OUTDIR = ARGS[0] if ARGS else "."
ONLY = sys.argv[sys.argv.index("--only") + 1].split(",") if "--only" in sys.argv else []

# ==================================================================================================
def cow():
    """A Holstein: lofted barrel body, bony hips, a real head with muzzle, ears and short horns,
    jointed legs with hooves, udder, a tail with a tuft. Back top at 1.36 (the game cuts it there)."""
    reset()
    hide = mat2("CowHide", (0.74, 0.71, 0.66), 0.85)
    spot = mat2("CowSpot", (0.06, 0.055, 0.05), 0.8)
    nose = mat2("CowNose", (0.5, 0.34, 0.33), 0.5)
    horn = mat2("CowHorn", (0.72, 0.66, 0.52), 0.45)
    hoof = mat2("CowHoof", (0.08, 0.07, 0.06), 0.6)
    eye = mat2("CowEye", (0.03, 0.025, 0.02), 0.15)
    udder = mat2("CowUdder", (0.62, 0.45, 0.42), 0.6)
    p = []
    # the body: a barrel, deeper in the belly, with the spine ridge and hip bones
    body = loft(hide, [(-0.86, 0, 1.06, 0.16, 0.2), (-0.74, 0, 1.0, 0.27, 0.34), (-0.45, 0, 0.98, 0.31, 0.38),
                       (-0.1, 0, 0.96, 0.33, 0.41), (0.25, 0, 0.98, 0.32, 0.4), (0.55, 0, 1.03, 0.27, 0.34),
                       (0.72, 0, 1.1, 0.19, 0.24)], verts=18)
    p.append(body)
    for x in (1, -1):
        p.append(ball(hide, (0.17 * x, -0.62, 1.27), 0.09, (0.9, 1.2, 0.7)))          # hip bones (hook bones)
        p.append(ball(hide, (0.16 * x, 0.45, 1.2), 0.11, (0.9, 1.3, 0.9)))            # shoulders
    p.append(ball(hide, (0, -0.15, 1.33), 0.07, (1.0, 9.0, 0.45), seg=12, rings=8))     # spine ridge
    # black patches lying on the skin (flattened balls sunk into the body)
    rnd = random.Random(4)
    for (x, y, z, r) in ((0.27, 0.15, 1.1, 0.2), (-0.3, -0.35, 1.0, 0.23), (0.22, -0.5, 0.85, 0.16), (-0.25, 0.4, 1.12, 0.16),
                         (0.05, -0.1, 1.3, 0.18), (-0.1, 0.62, 1.2, 0.12), (0.3, -0.72, 1.12, 0.1)):
        s = ball(spot, (x, y, z), r, (1.0, 1.3, 1.0), seg=12, rings=8)
        n = Vector((x, 0, z - 0.98)).normalized()           # flatten it onto the skin: a patch, not a lump
        t = 1.0 / math.sqrt((n.x / 0.31) ** 2 + (n.z / 0.39) ** 2)
        c = Vector((0, y, 0.98)) + n * t                    # (the point on the body's surface)
        for v in s.data.vertices:
            d = v.co - Vector((x, y, z))
            v.co = c + d - n * (d.dot(n) * 0.7)
        jitter(s, r * 0.05, rnd.randint(0, 99))
        p.append(s)
    # neck and head (head hangs slightly, muzzle forward)
    p.append(loft(hide, [(0.6, 0, 1.12, 0.2, 0.24), (0.78, 0, 1.18, 0.15, 0.2), (0.92, 0, 1.2, 0.12, 0.16)], verts=14))
    p.append(ball(hide, (0, 0.62, 0.86), 0.12, (0.8, 1.4, 0.8)))                      # dewlap
    head = loft(hide, [(0.88, 0, 1.24, 0.11, 0.13), (0.96, 0, 1.24, 0.12, 0.14), (1.06, 0, 1.18, 0.1, 0.12),
                       (1.14, 0, 1.11, 0.085, 0.09), (1.19, 0, 1.08, 0.08, 0.075)], verts=14)
    p.append(head)
    p.append(ball(nose, (0, 1.2, 1.07), 0.08, (1.05, 0.5, 0.85)))                     # muzzle
    p.append(ball(spot, (0, 0.98, 1.32), 0.1, (1.1, 1.0, 0.45)))                       # dark poll
    for x in (1, -1):
        p.append(ball(eye, (0.1 * x, 1.0, 1.25), 0.02))
        p.append(ball(spot, (0.105 * x, 1.0, 1.255), 0.028, (0.6, 1.0, 0.7)))
        p.append(ball(nose, (0.035 * x, 1.24, 1.075), 0.015))                           # nostrils
        p.append(ball(hide, (0.17 * x, 0.94, 1.31), 0.05, (1.6, 0.35, 0.8), rot=(0, 0.35 * x, 0)))   # ears
        p.append(tb(horn, (0.07 * x, 0.94, 1.36), (0.15 * x, 0.96, 1.42), 0.022, 8, r2=0.006))
        # legs: upper leg (thick), knee, cannon bone, fetlock, hoof
        for y, front in ((0.45, True), (-0.55, False)):
            top = (0.17 * x, y, 0.95)
            knee = (0.17 * x, y + (0.02 if front else -0.06), 0.5)
            fet = (0.17 * x, y, 0.13)
            p.append(tb(hide, top, knee, 0.085 if front else 0.1, 10, r2=0.055))
            p.append(ball(hide, knee, 0.058))
            p.append(tb(hide, knee, fet, 0.045, 10, r2=0.04))
            p.append(ball(hide, fet, 0.045))
            p.append(bx(hoof, (0.17 * x, y + 0.02, 0.05), (0.1, 0.13, 0.1), 0.02))
            p.append(box(spot, (0.17 * x, y + 0.085, 0.05), (0.006, 0.01, 0.08)))       # the cleft in the hoof
    # udder with four teats
    p.append(ball(udder, (0, -0.4, 0.6), 0.13, (1.0, 1.15, 0.7)))
    for x in (1, -1):
        for y in (-0.33, -0.47):
            p.append(tb(udder, (0.05 * x, y, 0.55), (0.055 * x, y, 0.48), 0.016, 8, r2=0.012))
    # tail from the tail head down to a dark tuft
    p.append(tb(hide, (0, -0.84, 1.25), (0, -0.9, 0.95), 0.03, 8, r2=0.02))
    p.append(tb(hide, (0, -0.9, 0.95), (0, -0.88, 0.55), 0.02, 8, r2=0.016))
    p.append(ball(spot, (0, -0.88, 0.5), 0.045, (1, 1, 2.2)))
    o = join(p, "Krava")
    export_glb(os.path.join(OUTDIR, "cow.glb"), [o])

# ==================================================================================================
def dropship():
    reset()
    hull = mat2("KondorHull", (0.25, 0.27, 0.27), 0.5, 0.35)
    hull2 = mat2("KondorHullDark", (0.13, 0.14, 0.15), 0.55, 0.4)
    panel = mat2("KondorPanel", (0.2, 0.22, 0.22), 0.55, 0.35)
    steel = mat2("KondorSteel", (0.36, 0.37, 0.39), 0.35, 0.8)
    inner = mat2("KondorInner", (0.3, 0.31, 0.3), 0.8)
    floor = mat2("KondorFloor", (0.12, 0.12, 0.13), 0.45, 0.5)
    seat = mat2("KondorSeat", (0.22, 0.2, 0.15), 0.9)
    strap = mat2("KondorStrap", (0.45, 0.12, 0.06), 0.9)
    glass = mat2("KondorGlass", (0.06, 0.1, 0.13), 0.05, 0.3)
    lamp = mat2("KondorLamp", (1.0, 0.75, 0.45), emit=3.0)
    redl = mat2("KondorRedLamp", (1.0, 0.1, 0.05), emit=2.5)
    red = mat2("NavRed", (1.0, 0.1, 0.05), emit=6.0)
    grn = mat2("NavGreen", (0.1, 1.0, 0.2), emit=6.0)
    white = mat2("StrobeWhite", (1.0, 1.0, 0.95), emit=5.0)
    eng = mat2("EngineGlow", (1.0, 0.45, 0.15), emit=3.0)
    stencil = mat2("KondorStencil", (0.75, 0.75, 0.7), 0.7)
    warn = mat2("KondorWarn", (0.78, 0.6, 0.1), 0.6)
    black = mat2("KondorBlack", (0.03, 0.03, 0.035), 0.8)
    screen = mat2("KondorScreen", (0.25, 0.85, 0.5), emit=1.5)
    rubber = mat2("KondorTyre", (0.03, 0.03, 0.03), 0.95)
    p = []
    L = 8.0
    # ---- the cabin shell (slabs, so the inside shows from the cabin) ----------------------------------------------
    for x in (1, -1):
        p.append(bx(hull, (1.72 * x, 0, 1.45), (0.25, L, 2.6), 0.03))                          # side wall
        p.append(bx(hull, (1.62 * x, 0, 3.0), (0.62, L, 0.25), 0.03, rot=(0, 0.78 * x, 0)))   # chamfered roof edge
        p.append(bx(hull2, (1.6 * x, 0, 0.12), (0.62, L, 0.3), 0.03, rot=(0, -0.6 * x, 0)))   # chamfered belly edge
        # side sponson along the lower hull (gear bays, fuel)
        p.append(bx(hull2, (2.0 * x, -0.2, 0.45), (0.42, 6.2, 0.7), 0.08, seg=2))
        p.append(bx(panel, (2.22 * x, -0.2, 0.45), (0.03, 5.6, 0.42), 0.01))
        # panel lines and rivet rows on the outer skin
        for k in range(7):
            y = -3.45 + k * 1.15
            p.append(box(hull2, (1.85 * x, y, 1.5), (0.012, 0.025, 2.4)))
        for z in (0.95, 2.3):
            p.append(box(hull2, (1.85 * x, 0, z), (0.012, L - 0.1, 0.025)))
            for k in range(26):
                p.append(screw(steel, (1.855 * x, -3.9 + k * 0.31, z + 0.06), 0.012))
        # the side door (forward), with a handle and a small window
        p.append(bx(panel, (1.86 * x, 2.7, 1.25), (0.04, 1.0, 1.9), 0.02))
        p.append(bx(glass, (1.885 * x, 2.7, 1.75), (0.02, 0.45, 0.4), 0.01))
        p.append(bx(steel, (1.89 * x, 2.35, 1.2), (0.03, 0.18, 0.04), 0.008))
        # three windows behind it
        for i in range(3):
            y = -2.4 + i * 1.3
            p.append(bx(hull2, (1.86 * x, y, 2.05), (0.04, 0.62, 0.42), 0.02))
            p.append(bx(glass, (1.875 * x, y, 2.05), (0.03, 0.5, 0.3), 0.01))
        # white stencil band, unit number plate, the warning chevron by the door
        p.append(box(stencil, (1.86 * x, -0.6, 2.62), (0.01, 3.6, 0.08)))
        for k in range(4):
            p.append(box(stencil, (1.862 * x, 0.1 + k * 0.16, 0.95), (0.01, 0.1, 0.22)))
        p.append(box(warn, (1.862 * x, 3.35, 0.4), (0.01, 0.35, 0.12)))
    p.append(bx(hull, (0, 0, 3.0), (2.6, L, 0.3), 0.04))                                         # roof
    p.append(bx(hull2, (0, 0.6, 3.27), (1.6, 5.2, 0.28), 0.06, seg=2))                         # dorsal spine (engines' drive)
    for k in range(6):
        p.append(bx(black, (0.81, -1.4 + k * 0.7, 3.28), (0.02, 0.4, 0.16), 0.005))
        p.append(bx(black, (-0.81, -1.4 + k * 0.7, 3.28), (0.02, 0.4, 0.16), 0.005))
    p.append(tb(steel, (0, 2.0, 3.42), (0, 2.0, 4.2), 0.02, 6))                                 # antennas
    p.append(bx(hull2, (0.5, -1.0, 3.45), (0.05, 0.5, 0.25), 0.01, rot=(0.4, 0, 0)))
    p.append(ball(white, (0, -0.4, 3.43), 0.05))
    # ---- the cabin inside ------------------------------------------------------------------------------------------
    p.append(bx(floor, (0, 0, 0.1), (3.2, L, 0.2), 0.02))
    for i in range(16):
        p.append(box(steel, (0, -3.75 + i * 0.5, 0.205), (2.9, 0.06, 0.012)))                 # anti-slip strips
    for y in (-3.0, -1.0, 1.0, 3.0):
        for x in (0.7, -0.7):
            p.append(torus(steel, (x, y, 0.215), 0.05, 0.012, seg=10))                          # tie-down rings
    for k in range(9):                                                                          # the frames (ribs)
        y = -3.9 + k * 0.975
        for x in (1, -1):
            p.append(bx(inner, (1.55 * x, y, 1.45), (0.1, 0.09, 2.5), 0.015))
        p.append(bx(inner, (0, y, 2.71), (3.0, 0.09, 0.1), 0.015))
    for x in (1, -1):
        p.append(box(inner, (1.585 * x, 0, 1.45), (0.01, L - 0.1, 2.5)))                       # inner lining
        # fold-down seats with red webbing, the seat frame under them
        p.append(bx(seat, (1.3 * x, -0.4, 0.5), (0.42, 5.6, 0.07), 0.02))
        for k in range(8):
            y = -3.0 + k * 0.7
            p.append(bx(seat, (1.48 * x, y, 0.95), (0.05, 0.55, 0.65), 0.015))               # back pads
            p.append(box(strap, (1.45 * x, y - 0.15, 1.0), (0.012, 0.05, 0.8)))              # straps
            p.append(box(strap, (1.45 * x, y + 0.15, 1.0), (0.012, 0.05, 0.8)))
            p.append(tb(steel, (1.15 * x, y, 0.47), (1.15 * x, y, 0.2), 0.016, 6))           # legs
        p.append(tb(steel, (1.5 * x, -3.6, 1.32), (1.5 * x, 2.8, 1.32), 0.016, 6))            # grab rail
        # overhead cable tray and a duct
        p.append(bx(hull2, (1.1 * x, -0.4, 2.62), (0.25, 7.0, 0.08), 0.01))
        p.append(tb(inner, (0.7 * x, -3.8, 2.6), (0.7 * x, 3.8, 2.6), 0.07, 10))
    for i in range(4):                                                                          # lamps (warm + red night)
        y = -3.0 + i * 2.0
        p.append(bx(hull2, (0, y, 2.69), (0.6, 0.18, 0.04), 0.01))
        p.append(box(lamp if i % 2 == 0 else redl, (0, y, 2.665), (0.5, 0.12, 0.02)))
    # a weapons rack and an extinguisher at the front bulkhead
    p.append(bx(hull2, (1.0, 3.75, 1.4), (1.1, 0.12, 2.2), 0.02))
    for k in range(4):
        p.append(bx(black, (0.65 + k * 0.23, 3.67, 1.2), (0.05, 0.05, 0.85), 0.01))
    p.append(tb(strap, (-1.3, 3.75, 0.3), (-1.3, 3.75, 0.85), 0.07, 10))
    # front bulkhead with the door to the cockpit, and the crew-chief's console
    p.append(bx(inner, (1.0, 4.0, 1.4), (1.2, 0.3, 2.8), 0.03))
    p.append(bx(inner, (-1.0, 4.0, 1.4), (1.2, 0.3, 2.8), 0.03))
    p.append(bx(inner, (0, 4.0, 2.55), (0.8, 0.3, 0.5), 0.03))
    p.append(bx(hull2, (-0.85, 3.83, 1.6), (0.7, 0.05, 0.5), 0.01))
    p.append(box(screen, (-0.85, 3.8, 1.62), (0.55, 0.01, 0.35)))
    p.append(box(redl, (0, 3.83, 2.35), (0.25, 0.02, 0.08)))                                  # jump light over the door
    # ---- the cockpit nose ------------------------------------------------------------------------------------------
    p.append(box_loft(hull, [(4.0, 0, 1.5, 3.5, 2.95), (5.0, 0, 1.45, 3.4, 2.8), (5.9, 0, 1.25, 2.9, 2.2),
                             (6.6, 0, 1.0, 2.2, 1.5), (7.05, 0, 0.85, 1.3, 0.8)], b=0.12))
    # windscreen: a frame of three panes on the slope, side windows
    for x0, x1 in ((-1.25, -0.42), (-0.38, 0.38), (0.42, 1.25)):
        cx = (x0 + x1) / 2
        p.append(bx(glass, (cx, 5.9, 2.42), (x1 - x0 - 0.04, 0.9, 0.04), 0.01, rot=(-0.62, 0, 0)))
    p.append(bx(hull2, (0, 5.92, 2.44), (2.7, 0.06, 0.08), 0.01, rot=(-0.62, 0, 0)))
    for x in (0.4, -0.4, 1.27, -1.27):
        p.append(bx(hull2, (x, 5.9, 2.43), (0.06, 0.95, 0.07), 0.01, rot=(-0.62, 0, 0)))
    for x in (1, -1):
        p.append(bx(glass, (1.7 * x, 4.9, 2.1), (0.03, 0.9, 0.45), 0.01))
    p.append(bx(hull2, (0, 6.6, 1.6), (2.0, 0.6, 0.1), 0.02, rot=(-0.9, 0, 0)))               # anti-glare panel
    p.append(ball(hull2, (0, 6.55, 0.3), 0.26))                                                # chin sensor ball
    p.append(ball(glass, (0, 6.75, 0.28), 0.12, (1, 0.5, 1)))
    p.append(tb(steel, (0.6, 6.7, 1.1), (0.65, 7.8, 1.1), 0.025, 8, r2=0.008))                 # pitot probe
    p.append(box(red, (0, 7.08, 0.9), (0.1, 0.03, 0.1)))
    # ---- wings and the tilting engine nacelles -------------------------------------------------------------------
    for x, nav in ((1, grn), (-1, red)):
        p.append(plate(hull2, [(1.75 * x, 2.4), (4.7 * x, 1.85), (4.7 * x, 0.15), (1.75 * x, -0.4)], 1.9, 2.12, b=0.04))
        p.append(plate(panel, [(2.1 * x, 2.1), (4.4 * x, 1.75), (4.4 * x, 1.55), (2.1 * x, 1.9)], 2.12, 2.13))
        p.append(box(warn, (3.3 * x, 0.4, 2.13), (1.6, 0.06, 0.01)))
        # the nacelle: a lofted pod with an intake ring and fan, an exhaust nozzle
        p.append(loft(hull, [(2.65, 5.3 * x, 2.0, 0.66, 0.66), (2.2, 5.3 * x, 2.0, 0.75, 0.75), (0.8, 5.3 * x, 2.0, 0.78, 0.78),
                             (-0.4, 5.3 * x, 2.0, 0.7, 0.7), (-0.9, 5.3 * x, 2.0, 0.56, 0.56)], verts=20, cap=False))
        p.append(torus(steel, (5.3 * x, 2.66, 2.0), 0.66, 0.06, rot=(PI2, 0, 0), seg=24))
        p.append(disc(black, (5.3 * x, 2.45, 2.0), 0.63, 0.05, 'y', verts=20))
        for k in range(9):                                                                      # fan blades
            a = TAU * k / 9
            p.append(bx(hull2, (5.3 * x + math.cos(a) * 0.33, 2.5, 2.0 + math.sin(a) * 0.33), (0.08, 0.02, 0.56), 0.005,
                        rot=(0.35, -a + PI2, 0)))
        p.append(ball(steel, (5.3 * x, 2.55, 2.0), 0.16, (1, 0.8, 1)))
        p.append(disc(hull2, (5.3 * x, -1.0, 2.0), 0.56, 0.2, 'y', verts=20, r2=0.46))
        for k in range(12):                                                                     # nozzle petals
            a = TAU * k / 12
            p.append(bx(hull2, (5.3 * x + math.cos(a) * 0.47, -1.2, 2.0 + math.sin(a) * 0.47), (0.2, 0.3, 0.03), 0.005,
                        rot=(0, -a + PI2, 0)))
        p.append(disc(black, (5.3 * x, -1.1, 2.0), 0.44, 0.04, 'y', verts=20))
        p.append(torus(eng, (5.3 * x, -1.13, 2.0), 0.3, 0.05, rot=(PI2, 0, 0), seg=20))
        p.append(disc(hull2, (5.3 * x, -1.14, 2.0), 0.12, 0.08, 'y', verts=12, r2=0.04))
        for y in (1.6, 0.4, -0.5):
            p.append(torus(hull2, (5.3 * x, y, 2.0), 0.775, 0.025, rot=(PI2, 0, 0), seg=24))
        p.append(bx(hull2, (4.85 * x, 0.9, 2.0), (0.4, 1.8, 0.3), 0.04))                       # pivot housing
        p.append(disc(steel, (4.62 * x, 0.9, 2.0), 0.22, 0.08, 'x', verts=14))
        p.append(box(nav, (6.08 * x, 0.9, 2.0), (0.06, 0.2, 0.08)))
        p.append(ball(white, (5.3 * x, -0.2, 2.78), 0.04))
        p.append(box(stencil, (5.3 * x, 1.6, 2.78), (0.25, 0.5, 0.01)))
        # landing gear: struts out of the sponsons, twin wheels
        for y in (2.5, -2.8):
            p.append(tb(steel, (1.95 * x, y, 0.4), (1.95 * x, y, 0.15), 0.06, 8))
            p.append(bx(hull2, (1.95 * x, y, 0.32), (0.18, 0.3, 0.1), 0.02))
            for dy in (-0.14, 0.14):
                p.append(disc(rubber, (1.95 * x, y + dy, 0.12), 0.17, 0.12, 'x', verts=14))
                p.append(disc(steel, (1.95 * x + 0.065 * x, y + dy, 0.12), 0.09, 0.01, 'x', verts=10))
    # ---- the tail over the ramp: a raised boom with two canted fins and a stabiliser -----------------------------
    p.append(box_loft(hull, [(-1.5, 0, 3.16, 2.2, 0.02), (-2.6, 0, 3.35, 2.2, 0.4), (-4.2, 0, 3.45, 1.6, 0.5)], b=0.05))
    p.append(plate(hull2, [(-3.2, -3.0), (3.2, -3.0), (3.0, -3.9), (-3.0, -3.9)], 3.55, 3.68, b=0.03))
    for x in (1, -1):
        fin = plate_v(hull, [(-2.9, 3.6), (-4.3, 3.6), (-4.6, 5.1), (-4.0, 5.1)], -0.06, 0.06, b=0.02)
        for v in fin.data.vertices:            # cant the fin outwards
            v.co.x = v.co.x + 1.0 * x + (v.co.z - 3.6) * 0.32 * x
        p.append(fin)
        p.append(box(red if x < 0 else grn, (1.48 * x, -4.3, 5.12), (0.08, 0.1, 0.06)))
        p.append(box(stencil, (1.12 * x + 0.02 * x, -3.6, 4.3), (0.01, 0.4, 0.3)))
    p.append(ball(white, (0, -4.15, 3.72), 0.05))
    # ---- the rear ramp, lowered (hinge at the floor's back edge), hydraulic rams -------------------------------
    p.append(bx(floor, (0, -5.15, -0.08), (3.0, 2.4, 0.15), 0.02, rot=(0.17, 0, 0)))
    for i in range(6):
        p.append(bx(steel, (0, -4.25 - i * 0.38, 0.03 - i * 0.065), (2.7, 0.05, 0.035), 0.008, rot=(0.17, 0, 0)))
    for x in (1, -1):
        p.append(bx(hull2, (1.45 * x, -5.15, 0.0), (0.12, 2.4, 0.22), 0.02, rot=(0.17, 0, 0)))
        for k in range(5):
            p.append(box(warn if k % 2 == 0 else black, (1.45 * x, -4.2 - k * 0.45, 0.13 - k * 0.077), (0.125, 0.42, 0.01), rot=(0.17, 0, 0)))
        p.append(tb(steel, (1.4 * x, -4.0, 1.3), (1.4 * x, -5.0, 0.15), 0.035, 8))
        p.append(tb(hull2, (1.4 * x, -4.0, 1.3), (1.4 * x, -4.45, 0.78), 0.055, 8))
    # the open rear frame round the ramp opening
    for x in (1, -1):
        p.append(bx(hull2, (1.66 * x, -4.0, 1.45), (0.36, 0.15, 2.9), 0.03))
    p.append(bx(hull2, (0, -4.0, 2.88), (3.6, 0.15, 0.3), 0.03))
    p.append(box(redl, (0, -3.9, 2.7), (0.3, 0.02, 0.08)))
    o = join(p, "Kondor")
    export_glb(os.path.join(OUTDIR, "dropship.glb"), [o])

ALL = dict(cow=cow, dropship=dropship)
for k, f in ALL.items():
    if not ONLY or k in ONLY:
        f()
        print("built", k)

if "--gallery" in sys.argv:
    out = sys.argv[sys.argv.index("--gallery") + 1]
    reset()
    for f, loc in (("dropship.glb", (0, 0, 0)), ("cow.glb", (6.5, -5.0, 0))):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=os.path.join(OUTDIR, f))
        for o in set(bpy.data.objects) - before:
            if o.parent is None:
                o.location = loc
    preview(out, target=(1.5, -1.0, 1.6), dist=17.0, angle=2.35, height=4.5, res=(1280, 800))
    if "--front" in sys.argv:
        preview(out.replace(".png", "_front.png"), target=(1.5, 0.0, 1.4), dist=16.0, angle=0.55, height=3.0, res=(1280, 800))
