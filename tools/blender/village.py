"""Enemy Beyond - village props (0.52 rework, own designs, Czech countryside at night).
Each prop: visual pieces joined, plus simple "*-colonly" boxes for collision (unchanged).
Front = +Y (Godot -Z). Origin on the ground in the middle. Same sizes as before.
The roof keeps the material names "VRoofTile" / "VPlaster" (map_gen swaps them on cabins).
Props that had block-modeller edits in modely/ get new mesh names (Auto_*, Kurnik, Traktor, Okno, Drevo),
so the old part-number edits do not land on the new meshes.
Run: python3 tools/blender/village.py <outdir> [--only well,tractor] [--gallery out.png]"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
from kit import *

ARGS = [a for a in sys.argv[1:] if not a.startswith("--") and not a.endswith(".png") and "," not in a]
OUTDIR = ARGS[0] if ARGS else "."
ONLY = sys.argv[sys.argv.index("--only") + 1].split(",") if "--only" in sys.argv else []

def M():
    return dict(
        wood=mat2("VWood", (0.33, 0.22, 0.12), 0.9), dwood=mat2("VDarkWood", (0.18, 0.12, 0.07), 0.9),
        gwood=mat2("VGreyWood", (0.3, 0.27, 0.23), 0.95), endg=mat2("VEndGrain", (0.55, 0.42, 0.26), 0.9),
        tile=mat2("VRoofTile", (0.42, 0.14, 0.09), 0.8), tile2=mat2("VRoofTileDark", (0.3, 0.1, 0.07), 0.85),
        plaster=mat2("VPlaster", (0.75, 0.72, 0.62), 0.95), plaster2=mat2("VPlasterDirty", (0.55, 0.52, 0.45), 0.95),
        stone=mat2("VStone", (0.4, 0.4, 0.38), 0.95), stone2=mat2("VStoneDark", (0.28, 0.28, 0.27), 0.95),
        brick=mat2("VBrick", (0.4, 0.17, 0.1), 0.9), concrete=mat2("VConcrete", (0.45, 0.44, 0.41), 0.95),
        metal=mat2("VMetal", (0.3, 0.31, 0.33), 0.45, 0.7), dmetal=mat2("VMetalDark", (0.12, 0.12, 0.13), 0.5, 0.6),
        chrome=mat2("VChrome", (0.6, 0.62, 0.64), 0.2, 1.0), rust=mat2("VRust", (0.38, 0.18, 0.08), 0.85, 0.3),
        glass=mat2("VGlass", (0.08, 0.1, 0.12), 0.08, 0.3), lit=mat2("VLitWindow", (1.0, 0.75, 0.4), emit=2.0),
        red=mat2("VRedPaint", (0.5, 0.08, 0.06), 0.55, 0.2), green=mat2("VGreenPaint", (0.18, 0.3, 0.15), 0.7),
        blue=mat2("VBluePaint", (0.15, 0.22, 0.35), 0.6), tyre=mat2("VTyre", (0.04, 0.04, 0.04), 0.9),
        white=mat2("VWhite", (0.85, 0.85, 0.8), 0.8), cloth=mat2("VCloth", (0.6, 0.58, 0.5), 0.95),
        straw=mat2("VStraw", (0.6, 0.48, 0.2), 0.95), sack=mat2("VBurlap", (0.42, 0.34, 0.22), 0.95),
        black=mat2("VBlack", (0.03, 0.03, 0.03), 0.9), soot=mat2("VSoot", (0.07, 0.06, 0.06), 0.95),
        amber=mat2("VAmberLight", (1.0, 0.55, 0.1), emit=2.0), redlight=mat2("VRedLight", (0.9, 0.08, 0.05), emit=1.5),
        candle=mat2("VCandleRed", (0.45, 0.06, 0.05), 0.5), moss=mat2("VMoss", (0.16, 0.2, 0.1), 0.95),
    )

def save(name, vis, col, fname):
    o = join(vis, name)
    export_glb(os.path.join(OUTDIR, "v_%s.glb" % fname), [o] + col)

def planks_wall(m, m2, c, w, h, axis, n=None, t=0.04, seed=0):
    """A wall of vertical boards: centre c, width w along axis ('x' or 'y'), height h."""
    r = random.Random(seed)
    n = n or max(2, int(w / 0.16))
    out = []
    for i in range(n):
        o = -w / 2 + (i + 0.5) * w / n
        hh = h * r.uniform(0.97, 1.0)
        size = (w / n * 0.94, t, hh) if axis == 'x' else (t, w / n * 0.94, hh)
        pos = (c[0] + (o if axis == 'x' else 0), c[1] + (o if axis == 'y' else 0), c[2] - (h - hh) / 2)
        out.append(bx(m if r.random() > 0.25 else m2, pos, size, 0.006))
    return out

# ==================================================================================================
def gable_roof(m, w, d, h0, pitch_h, vis, overhang=0.35, tm="tile", seed=1, holes=0):
    """A pitched roof over a w x d building whose walls end at h0, ridge along X: overlapping rows of
    tiles (a few slipped or missing), ridge caps, gable ends of boards over plaster."""
    r = random.Random(seed)
    half = d / 2 + overhang
    a = math.atan2(pitch_h + 0.1, half)
    L = math.hypot(half, pitch_h + 0.1)
    W = w + overhang * 2
    rows = max(3, int(L / 0.3))
    for s in (-1, 1):
        # the deck under the tiles
        vis.append(box(m["dwood"], (0, s * half / 2, h0 + pitch_h / 2 - 0.12), (W, L, 0.06), rot=(-s * a, 0, 0)))
        for k in range(rows):
            t = (k + 0.5) / rows
            y = s * half * (1 - t)
            z = h0 - 0.1 + (pitch_h + 0.1) * t + 0.0
            # each row: a strip of tiles, its lower edge lifted (the overlap catches the light)
            ncols = max(4, int(W / 0.5))
            for c in range(ncols):
                if holes and r.random() < 0.025 * holes:
                    continue
                x = -W / 2 + (c + 0.5) * W / ncols
                mm = m[tm] if r.random() > 0.2 else m["tile2"]
                # plain boxes (no bevel): a house has hundreds of tiles and the game builds its collision from them
                tile = box(mm, (x + r.uniform(-0.01, 0.01), y, z), (W / ncols * 0.97, L / rows * 1.25, 0.035),
                           rot=(-s * (a - 0.06), 0, r.uniform(-0.015, 0.015)))
                vis.append(tile)
    # ridge caps: half-round tiles along the top
    n = int(W / 0.4)
    for k in range(n):
        x = -W / 2 + (k + 0.5) * W / n
        vis.append(smooth(cyl(m[tm], (x, 0, h0 + pitch_h + 0.02), 0.11, W / n * 1.02, verts=10, rot=(0, PI2, 0))))
    # gable ends: plaster triangle with vertical boards in the top half
    for sx in (-1, 1):
        steps = 8
        for k in range(steps):
            t = k / steps
            vis.append(box(m["plaster"], (sx * (w / 2 - 0.12), 0, h0 + pitch_h * (t + 0.5 / steps) - 0.08), (0.2, d * (1 - t - 1.0 / steps), pitch_h / steps + 0.01)))
        for k in range(int(d / 0.25)):
            y = -d / 2 + (k + 0.5) * 0.25
            top = h0 + pitch_h * (1 - abs(y) / (d / 2)) - 0.1
            bot = h0 + pitch_h * 0.45
            if top > bot + 0.05:
                vis.append(bx(m["gwood"], (sx * (w / 2 - 0.01), y, (top + bot) / 2), (0.03, 0.22, top - bot), 0.005))
        bw = 2 * half * (1 - (pitch_h * 0.45 + 0.1) / (pitch_h + 0.1)) - 0.15     # (the roof's width at that height)
        vis.append(bx(m["dwood"], (sx * (w / 2), 0, h0 + pitch_h * 0.45), (0.06, bw, 0.08), 0.01))

def house_roof():
    """Roof for the 8 x 6 m farmhouse (the walls are built by the game): tiles, ridge caps, a brick
    chimney with soot, gutters and a downpipe, a little attic window."""
    reset(); m = M(); vis = []; col = []
    w, d = 8.0, 6.0
    gable_roof(m, w, d, 0.0, 2.2, vis, holes=1)
    # the chimney: bricks in courses, a cap, soot
    for k in range(9):
        z = 1.0 + k * 0.2
        vis.append(bx(m["brick"] if k % 3 else m["stone2"], (2.2, 0.8, z), (0.56, 0.56, 0.19), 0.01))
    vis.append(bx(m["stone"], (2.2, 0.8, 2.85), (0.7, 0.7, 0.08), 0.015))
    vis.append(bx(m["soot"], (2.2, 0.8, 2.92), (0.4, 0.4, 0.08), 0.01))
    vis.append(tb(m["soot"], (2.2, 0.8, 2.9), (2.2, 0.8, 3.15), 0.12, 10))
    # gutters (half-round, on brackets) and a downpipe at one corner
    for s in (-1, 1):
        vis.append(tb(m["metal"], (-w / 2 - 0.35, s * (d / 2 + 0.38), -0.08), (w / 2 + 0.35, s * (d / 2 + 0.38), -0.08), 0.07, 10))
        for k in range(6):
            x = -w / 2 + k * w / 5
            vis.append(box(m["dmetal"], (x, s * (d / 2 + 0.3), -0.05), (0.03, 0.2, 0.02)))
    vis.append(tb(m["metal"], (w / 2 + 0.3, d / 2 + 0.38, -0.1), (w / 2 + 0.3, d / 2 + 0.38, -2.8), 0.045, 8))
    # attic window in the gable
    vis.append(bx(m["dwood"], (-w / 2 - 0.0, 0, 0.9), (0.08, 0.8, 0.7), 0.01))
    vis.append(box(m["glass"], (-w / 2 - 0.03, 0, 0.9), (0.04, 0.6, 0.5)))
    vis.append(box(m["dwood"], (-w / 2 - 0.05, 0, 0.9), (0.04, 0.05, 0.5)))
    vis.append(box(m["dwood"], (-w / 2 - 0.05, 0, 0.9), (0.04, 0.6, 0.05)))
    col.append(colbox("Roof", (0, 0, 0.7), (w + 0.6, d + 0.6, 0.3)))
    save("House_Roof", vis, col, "house_roof")

def window():
    """A window for a wall gap: a frame of old white paint, sashes with bars, glass, a stone sill, two
    shutters - one hanging off a hinge. Thin (sits in a 0.25 wall)."""
    reset(); m = M(); vis = []
    vis.append(box(m["glass"], (0, 0, 0), (1.0, 0.03, 0.9)))
    for z in (0.47, -0.47):
        vis.append(bx(m["white"], (0, 0, z), (1.12, 0.13, 0.07), 0.01))
    for x in (0.53, -0.53):
        vis.append(bx(m["white"], (x, 0, 0), (0.07, 0.13, 1.0), 0.01))
    for sx in (1, -1):                                       # two sashes, each with a cross of bars
        cx = sx * 0.25
        vis.append(bx(m["white"], (cx + sx * 0.24, 0.02, 0), (0.04, 0.06, 0.88), 0.006))
        vis.append(bx(m["white"], (cx, 0.02, 0.42), (0.5, 0.06, 0.04), 0.006))
        vis.append(bx(m["white"], (cx, 0.02, -0.42), (0.5, 0.06, 0.04), 0.006))
        vis.append(bx(m["white"], (cx, 0.025, 0.1), (0.46, 0.04, 0.03), 0.004))
        vis.append(bx(m["white"], (cx, 0.025, 0.0), (0.03, 0.04, 0.84), 0.004))
    vis.append(bx(m["white"], (0, 0.02, 0), (0.05, 0.07, 0.9), 0.006))
    vis.append(bx(m["stone"], (0, 0.12, -0.52), (1.25, 0.26, 0.07), 0.015))       # sill
    vis.append(bx(m["dmetal"], (0.05, 0.05, 0.0), (0.02, 0.02, 0.06), 0.003))     # latch
    # shutters: louvred boards in a frame; the left one hangs crooked
    for sx in (-1, 1):
        sh = []
        sh.append(bx(m["green"], (0, 0, 0.47), (0.45, 0.04, 0.06), 0.008))
        sh.append(bx(m["green"], (0, 0, -0.47), (0.45, 0.04, 0.06), 0.008))
        sh.append(bx(m["green"], (0.2, 0, 0), (0.05, 0.04, 1.0), 0.008))
        sh.append(bx(m["green"], (-0.2, 0, 0), (0.05, 0.04, 1.0), 0.008))
        for k in range(9):
            sh.append(box(m["green"], (0, 0, -0.38 + k * 0.095), (0.36, 0.02, 0.07), rot=(0.5, 0, 0)))
        o = join(sh, "Shutter")
        ang = sx * 0.5 if sx > 0 else -0.5
        o.rotation_euler = (0, 0.18 if sx < 0 else 0, ang)
        o.location = (sx * 0.85, 0.08, -0.04 if sx < 0 else 0)
        apply_xf(o)
        vis.append(o)
        for z in (0.32, -0.32):
            vis.append(bx(m["dmetal"], (sx * 0.6, 0.07, z), (0.12, 0.02, 0.025), 0.004))   # hinges
    save("Okno", vis, [], "window")

def well():
    """A stone well: courses of rough stones, oak posts, a windlass with a crank and rope, a tiled
    roof, a bucket knocked over."""
    reset(); m = M(); vis = []; col = []
    r = random.Random(5)
    for k in range(5):                                            # stone courses
        n = 12
        for i in range(n):
            a = TAU * (i + (0.5 if k % 2 else 0)) / n
            st = bx(m["stone"] if r.random() > 0.3 else m["stone2"], (math.cos(a) * 0.66, math.sin(a) * 0.66, 0.09 + k * 0.18),
                    (0.22, 0.38, 0.17), 0.03, rot=(0, 0, a))
            vis.append(jitter(st, 0.012, r.randint(0, 999)))
    vis.append(torus(m["stone"], (0, 0, 0.92), 0.66, 0.1, seg=20))   # coping
    vis.append(disc(m["black"], (0, 0, 0.6), 0.52, 0.02, verts=20))   # the dark below
    vis.append(ball(m["moss"], (0.6, -0.3, 0.2), 0.15, (1, 1.5, 0.6)))
    for sx in (-1, 1):                                            # posts with braces
        vis.append(bx(m["dwood"], (sx * 0.7, 0, 1.25), (0.13, 0.13, 1.7), 0.015))
        vis.append(beam(m["dwood"], (sx * 0.7, 0, 1.75), (sx * 0.7, 0.3, 2.05), 0.08, 0.08))
        vis.append(beam(m["dwood"], (sx * 0.7, 0, 1.75), (sx * 0.7, -0.3, 2.05), 0.08, 0.08))
    vis.append(tb(m["wood"], (-0.64, 0, 1.6), (0.64, 0, 1.6), 0.1, 12))          # the windlass drum
    for k in range(5):
        vis.append(torus(m["sack"], (-0.2 + k * 0.06, 0, 1.6), 0.105, 0.012, rot=(0, PI2, 0), seg=12))   # rope turns
    vis.append(tb(m["sack"], (0.1, 0.1, 1.6), (0.1, 0.1, 1.1), 0.01, 6))
    vis.append(tb(m["dmetal"], (0.64, 0, 1.6), (0.86, 0, 1.6), 0.02, 8))         # crank
    vis.append(beam(m["dmetal"], (0.86, 0, 1.6), (0.86, 0.0, 1.32), 0.03, 0.03))
    vis.append(tb(m["wood"], (0.86, 0, 1.32), (0.98, 0, 1.32), 0.025, 8))
    gable_roof(m, 1.7, 1.1, 2.0, 0.5, vis, overhang=0.15, seed=3)
    # a bucket on its side
    vis.append(tb(m["rust"], (0.25, 0.42, 0.14), (0.25, 0.75, 0.12), 0.15, 14, r2=0.12))
    vis.append(torus(m["dmetal"], (0.25, 0.42, 0.14), 0.15, 0.012, rot=(PI2, 0, 0), seg=14))
    col.append(colbox("Well", (0, 0, 0.6), (1.5, 1.5, 1.2)))
    save("Well", vis, col, "well")

def woodpile():
    """Split logs stacked between end posts under a plank lean-to, a chopping block with the axe in it."""
    reset(); m = M(); vis = []; col = []
    r = random.Random(7)
    for row in range(5):
        for k in range(9):
            x = -1.0 + k * 0.25 + (0.12 if row % 2 else 0) + r.uniform(-0.02, 0.02)
            if x > 1.05:
                continue
            z = 0.12 + row * 0.21
            y0 = r.uniform(-0.05, 0.05)
            rad = r.uniform(0.09, 0.115)
            vis.append(tb(m["wood"] if (k + row) % 3 else m["dwood"], (x, y0 - 0.35, z), (x, y0 + 0.35, z), rad, 7, sm=False))
            vis.append(disc(m["endg"], (x, y0 + 0.351, z), rad * 0.85, 0.005, 'y', verts=7))
            vis.append(disc(m["endg"], (x, y0 - 0.351, z), rad * 0.85, 0.005, 'y', verts=7))
    for sx in (-1, 1):
        vis.append(bx(m["gwood"], (sx * 1.2, 0, 0.7), (0.1, 0.1, 1.4), 0.01))
        vis.append(bx(m["gwood"], (sx * 1.2, -0.45, 0.65), (0.08, 0.08, 1.3), 0.01))
    for k in range(6):                                           # the lean-to roof of planks
        vis.append(bx(m["gwood"], (-1.1 + k * 0.44, 0.0, 1.38), (0.42, 1.1, 0.03), 0.005, rot=(0.15, 0, r.uniform(-0.02, 0.02))))
    vis.append(bx(m["dwood"], (0, 0.0, 1.34), (2.6, 0.08, 0.06), 0.01))
    # chopping block, axe, a few chips
    vis.append(tb(m["wood"], (0.9, 0.7, 0.0), (0.9, 0.7, 0.55), 0.22, 12))
    vis.append(disc(m["endg"], (0.9, 0.7, 0.552), 0.2, 0.005, verts=12))
    vis.append(beam(m["wood"], (0.95, 0.7, 0.6), (1.25, 0.95, 1.05), 0.035, 0.03))
    vis.append(bx(m["dmetal"], (0.93, 0.68, 0.6), (0.04, 0.16, 0.1), 0.005, rot=(0, 0, 0.7)))
    for k in range(6):
        vis.append(box(m["endg"], (0.5 + r.uniform(0, 0.8), 0.9 + r.uniform(0, 0.4), 0.01), (0.06, 0.03, 0.01), rot=(0, 0, r.uniform(0, 3))))
    col.append(colbox("Pile", (0, 0, 0.6), (2.4, 0.8, 1.2)))
    save("Drevo", vis, col, "woodpile")

def tractor():
    """An old red tractor (own design), abandoned with the plough still down: a rounded bonnet with a
    grille, big lugged rear tyres under mudguards, a sprung seat, a steering wheel, an exhaust stack."""
    reset(); m = M(); vis = []; col = []
    red = mat2("VTractorRed", (0.5, 0.08, 0.05), 0.5, 0.25)
    vis.append(box_loft(red, [(1.55, 0, 1.0, 0.8, 0.6), (1.4, 0, 1.03, 0.88, 0.7), (-0.15, 0, 1.08, 0.9, 0.72)], b=0.1))     # bonnet
    vis.append(bx(m["dmetal"], (0, 1.57, 0.98), (0.75, 0.04, 0.52), 0.02))                     # grille
    for k in range(7):
        vis.append(box(m["chrome"], (-0.3 + k * 0.1, 1.6, 0.98), (0.025, 0.02, 0.48)))
    for sx in (1, -1):                                                                          # headlights
        vis.append(disc(m["chrome"], (0.32 * sx, 1.5, 1.32), 0.1, 0.12, 'y', verts=14))
        vis.append(disc(m["lit"], (0.32 * sx, 1.565, 1.32), 0.08, 0.02, 'y', verts=14))
        for k in range(4):
            vis.append(box(m["dmetal"], (0.46 * sx, 0.9 - k * 0.25, 1.1), (0.01, 0.12, 0.3)))  # bonnet vents
    vis.append(bx(m["dmetal"], (0, 0.6, 0.55), (0.5, 2.0, 0.35), 0.03))                      # engine block / chassis
    vis.append(bx(red, (0, -0.6, 0.95), (0.9, 1.0, 0.5), 0.05))                               # the body by the seat
    vis.append(bx(m["dmetal"], (0, -0.4, 1.22), (0.6, 0.5, 0.05), 0.01))                      # footplate
    vis.append(tb(m["dmetal"], (0, -0.85, 1.2), (0, -0.85, 1.4), 0.04, 8))
    vis.append(bx(m["tyre"], (0, -0.85, 1.45), (0.48, 0.42, 0.08), 0.03))                    # seat pan
    vis.append(bx(m["tyre"], (0, -1.05, 1.62), (0.42, 0.06, 0.3), 0.03, rot=(-0.2, 0, 0)))
    vis.append(tb(m["dmetal"], (0, -0.1, 1.2), (0, -0.4, 1.62), 0.025, 8))                    # steering column
    vis.append(torus(m["black"], (0, -0.45, 1.66), 0.2, 0.02, rot=(0.6, 0, 0), seg=18))
    vis.append(tb(m["dmetal"], (0.25, 1.05, 1.35), (0.25, 1.05, 2.0), 0.05, 10))               # exhaust stack
    vis.append(tb(m["rust"], (0.25, 1.05, 2.0), (0.25, 1.05, 2.12), 0.06, 10, r2=0.07))
    for sx in (-1, 1):
        # rear wheel: tyre with lugs, the red rim, a mudguard
        vis.append(disc(m["tyre"], (sx * 0.85, -0.7, 0.75), 0.72, 0.4, 'x', verts=24, b=0.06))
        for k in range(16):
            a = TAU * k / 16
            vis.append(bx(m["tyre"], (sx * 0.85 + sx * (0.08 if k % 2 else -0.08), -0.7 + math.cos(a) * 0.73, 0.75 + math.sin(a) * 0.73),
                          (0.22, 0.08, 0.06), 0.01, rot=(a, 0, 0)))
        vis.append(disc(red, (sx * 1.06, -0.7, 0.75), 0.42, 0.04, 'x', verts=18))
        vis.append(disc(m["dmetal"], (sx * 1.09, -0.7, 0.75), 0.13, 0.04, 'x', verts=12))
        for k in range(6):
            a = TAU * k / 6
            vis.append(screw(m["chrome"], (sx * 1.1, -0.7 + math.cos(a) * 0.09, 0.75 + math.sin(a) * 0.09), 0.015, 'x'))
        for k in range(9):                                     # the mudguard arc
            a0 = 0.1 + k * 0.33
            a1 = a0 + 0.33
            vis.append(beam(red, (sx * 0.85, -0.7 + math.cos(a0) * 0.83, 0.75 + math.sin(a0) * 0.83),
                            (sx * 0.85, -0.7 + math.cos(a1) * 0.83, 0.75 + math.sin(a1) * 0.83), 0.46, 0.03))
        # front wheel on the axle
        vis.append(disc(m["tyre"], (sx * 0.6, 1.1, 0.42), 0.41, 0.24, 'x', verts=20, b=0.04))
        vis.append(disc(red, (sx * 0.73, 1.1, 0.42), 0.22, 0.03, 'x', verts=14))
        vis.append(box(m["redlight"], (sx * 0.5, -1.13, 1.0), (0.08, 0.02, 0.06)))
    vis.append(tb(m["dmetal"], (-0.6, 1.1, 0.42), (0.6, 1.1, 0.42), 0.05, 8))
    # the plough: a frame and three rusty shares in the dirt
    vis.append(beam(m["dmetal"], (0, -1.2, 0.6), (0, -2.2, 0.4), 0.12, 0.12))
    vis.append(bx(m["rust"], (0, -2.1, 0.45), (1.5, 0.12, 0.12), 0.02))
    for k in range(3):
        x = -0.55 + k * 0.55
        vis.append(beam(m["rust"], (x, -2.1, 0.45), (x, -2.25, 0.1), 0.06, 0.06))
        vis.append(bx(m["rust"], (x, -2.15, 0.08), (0.2, 0.4, 0.04), 0.01, rot=(0.4, 0.4, 0)))
    col.append(colbox("Tractor", (0, 0, 0.9), (2.0, 3.4, 1.8)))
    save("Traktor", vis, col, "tractor")

def car(paint):
    """An old boxy hatchback: a bevelled body, a glass greenhouse on pillars, wheels with hubcaps,
    chrome bumpers, lamps, mirrors, a number plate. Same 1.6 x 3.8 footprint."""
    reset(); m = M(); vis = []; col = []
    pm = mat2("VCar%s" % paint[0], paint[1], 0.35, 0.3)
    glass = mat2("VCarGlass", (0.06, 0.08, 0.1), 0.05, 0.3)
    # the body: lower shell lofted front to back (bonnet slopes, boot drops)
    vis.append(box_loft(pm, [(1.92, 0, 0.55, 1.5, 0.4), (1.75, 0, 0.6, 1.62, 0.55), (0.75, 0, 0.66, 1.64, 0.62),
                             (-1.6, 0, 0.64, 1.64, 0.62), (-1.9, 0, 0.62, 1.55, 0.5)], b=0.06))
    # the cabin: roof, pillars and glass (windscreen and rear window raked)
    vis.append(bx(pm, (0, -0.4, 1.42), (1.38, 1.6, 0.06), 0.02))
    for sx in (1, -1):
        vis.append(beam(pm, (sx * 0.74, 0.62, 0.95), (sx * 0.69, 0.4, 1.4), 0.07, 0.06))           # A pillar
        vis.append(beam(pm, (sx * 0.75, -0.35, 0.95), (sx * 0.7, -0.35, 1.4), 0.07, 0.1))          # B pillar
        vis.append(beam(pm, (sx * 0.75, -1.45, 0.95), (sx * 0.69, -1.2, 1.4), 0.07, 0.18))         # C pillar
        vis.append(box(glass, (sx * 0.73, 0.1, 1.17), (0.02, 0.85, 0.4)))
        vis.append(box(glass, (sx * 0.73, -0.82, 1.17), (0.02, 0.8, 0.4)))
        vis.append(bx(m["chrome"], (sx * 0.83, -0.0, 0.85), (0.02, 0.18, 0.03), 0.005))           # door handles
        vis.append(bx(m["dmetal"], (sx * 0.82, 0.12, 0.62), (0.01, 0.02, 0.5), 0.002))           # door seams
        vis.append(bx(m["dmetal"], (sx * 0.82, -0.85, 0.62), (0.01, 0.02, 0.5), 0.002))
        vis.append(bx(m["black"], (sx * 0.85, 0.6, 1.0), (0.08, 0.05, 0.08), 0.01))              # mirrors
    vis.append(box(glass, (0, 0.52, 1.18), (1.36, 0.02, 0.56), rot=(-0.95, 0, 0)))
    vis.append(box(glass, (0, -1.35, 1.18), (1.36, 0.02, 0.48), rot=(0.5, 0, 0)))
    vis.append(bx(m["black"], (0, 0.86, 0.94), (1.4, 0.06, 0.04), 0.01))                       # wiper scuttle
    for sx in (1, -1):
        for sy in (1, -1):
            y = sy * 1.2 - (0.05 if sy < 0 else 0)
            vis.append(disc(m["tyre"], (sx * 0.74, y, 0.32), 0.32, 0.2, 'x', verts=20, b=0.03))
            vis.append(disc(m["chrome"], (sx * 0.85, y, 0.32), 0.17, 0.02, 'x', verts=16))
            vis.append(disc(m["dmetal"], (sx * 0.86, y, 0.32), 0.05, 0.02, 'x', verts=10))
            vis.append(beam(m["black"], (sx * 0.8, y - 0.38, 0.48), (sx * 0.8, y + 0.38, 0.48), 0.04, 0.05))   # wheel arch lip
        vis.append(bx(m["lit"] if paint[0] == "Blue" else m["white"], (sx * 0.55, 1.93, 0.72), (0.32, 0.03, 0.16), 0.01))
        vis.append(bx(m["amber"], (sx * 0.74, 1.9, 0.6), (0.08, 0.03, 0.06), 0.005))
        vis.append(bx(m["redlight"], (sx * 0.6, -1.92, 0.78), (0.26, 0.03, 0.14), 0.01))
    vis.append(bx(m["dmetal"], (0, 1.94, 0.6), (0.7, 0.02, 0.16), 0.005))                       # grille
    for k in range(5):
        vis.append(box(m["chrome"], (0, 1.955, 0.54 + k * 0.03), (0.66, 0.01, 0.006)))
    vis.append(bx(m["chrome"], (0, 1.98, 0.4), (1.62, 0.08, 0.12), 0.02))                       # bumpers
    vis.append(bx(m["chrome"], (0, -1.98, 0.42), (1.62, 0.08, 0.12), 0.02))
    vis.append(bx(m["white"], (0, -1.95, 0.6), (0.4, 0.02, 0.1), 0.005))                        # number plate
    vis.append(bx(m["black"], (0, -1.952, 0.6), (0.34, 0.02, 0.05), 0.002))
    vis.append(tb(m["dmetal"], (0.4, -1.85, 0.28), (0.4, -2.05, 0.28), 0.03, 8))               # exhaust
    col.append(colbox("Car", (0, 0, 0.75), (1.6, 3.9, 1.5)))
    save("Auto_%s" % paint[0], vis, col, "car_%s" % paint[0].lower())

def pole():
    """A creosoted telegraph pole: crossarm with braces, glass insulators on pins, a warning plate,
    climbing spikes. The wires are added by the game."""
    reset(); m = M(); vis = []; col = []
    pw = mat2("VPoleWood", (0.16, 0.11, 0.07), 0.9)
    vis.append(tb(pw, (0, 0, 0), (0, 0, 7.0), 0.13, 12, r2=0.095))
    vis.append(disc(pw, (0, 0, 7.02), 0.1, 0.05, verts=12, r2=0.05))
    vis.append(bx(pw, (0, 0, 6.6), (1.7, 0.12, 0.12), 0.015))
    for sx in (-1, 1):
        vis.append(beam(m["dmetal"], (0, 0.07, 6.2), (sx * 0.5, 0.07, 6.56), 0.04, 0.01))
    for x in (-0.75, -0.25, 0.25, 0.75):
        vis.append(tb(m["dmetal"], (x, 0, 6.66), (x, 0, 6.75), 0.012, 6))
        ins = mat2("VInsulatorGlass", (0.25, 0.4, 0.35), 0.05, 0.2)
        vis.append(tb(ins, (x, 0, 6.75), (x, 0, 6.88), 0.05, 10, r2=0.03))
        vis.append(torus(ins, (x, 0, 6.79), 0.05, 0.012, seg=10))
    vis.append(bx(m["white"], (0, 0.14, 2.6), (0.22, 0.02, 0.3), 0.005))                      # warning plate
    vis.append(bx(m["red"], (0, 0.152, 2.62), (0.06, 0.005, 0.16), 0.002, rot=(0, 0.4, 0)))
    for k in range(10):                                                                       # climbing steps
        z = 2.0 + k * 0.42
        sx = 1 if k % 2 else -1
        vis.append(tb(m["dmetal"], (0, 0, z), (sx * 0.28, 0, z), 0.012, 6))
    vis.append(tb(m["dmetal"], (0, 0, 0.6), (0, 0, 7.0), 0.008, 4))                           # earth wire
    col.append(colbox("Pole", (0, 0, 3.5), (0.25, 0.25, 7.0)))
    save("Pole", vis, col, "pole")

def wayside_cross():
    """A stone wayside cross: a stepped base, a pillar with a little niche, an iron cross with a
    ring, a dead candle and dry flowers."""
    reset(); m = M(); vis = []; col = []
    vis.append(jitter(bx(m["stone2"], (0, 0, 0.12), (1.1, 1.1, 0.24), 0.03), 0.01, 1))
    vis.append(jitter(bx(m["stone"], (0, 0, 0.42), (0.85, 0.85, 0.36), 0.04), 0.01, 2))
    vis.append(bx(m["stone"], (0, 0, 1.25), (0.4, 0.4, 1.3), 0.04))
    vis.append(bx(m["stone"], (0, 0, 1.95), (0.5, 0.5, 0.12), 0.03))
    vis.append(bx(m["stone2"], (0, 0, 0.67), (0.5, 0.5, 0.12), 0.03))
    vis.append(bx(m["black"], (0, 0.19, 1.4), (0.22, 0.04, 0.3), 0.01))                     # the niche
    vis.append(bx(m["dmetal"], (0, 0.18, 1.33), (0.12, 0.02, 0.15), 0.005))
    vis.append(ball(m["moss"], (0.3, 0.3, 0.5), 0.12, (1.5, 1, 0.5)))
    # the iron cross with a ring and curled ends
    vis.append(bx(m["dmetal"], (0, 0, 2.5), (0.06, 0.06, 1.0), 0.01))
    vis.append(bx(m["dmetal"], (0, 0, 2.7), (0.6, 0.06, 0.06), 0.01))
    vis.append(torus(m["dmetal"], (0, 0, 2.7), 0.16, 0.015, rot=(PI2, 0, 0), seg=16))
    for (x, z) in ((0.3, 2.7), (-0.3, 2.7), (0, 3.0)):
        vis.append(ball(m["dmetal"], (x, 0, z), 0.045))
    vis.append(bx(m["rust"], (0, 0, 2.08), (0.18, 0.18, 0.06), 0.01))
    # a dead candle in a red glass, dry flowers
    vis.append(tb(m["candle"], (0.25, 0.42, 0.6), (0.25, 0.42, 0.74), 0.05, 10))
    vis.append(tb(m["black"], (0.25, 0.42, 0.74), (0.25, 0.42, 0.76), 0.012, 6))
    for k in range(5):
        vis.append(tb(m["straw"], (-0.2, 0.4, 0.6), (-0.2 + (k - 2) * 0.05, 0.45, 0.85), 0.006, 4))
        vis.append(ball(m["soot"], (-0.2 + (k - 2) * 0.05, 0.45, 0.86), 0.02))
    col.append(colbox("Cross", (0, 0, 1.0), (1.0, 1.0, 2.0)))
    save("Cross", vis, col, "cross")

def chapel():
    """A small village chapel (kaplička): white walls on a stone plinth, corner pilasters, a round-
    arched locked door, arched windows, a tiled roof, a little bell tower with louvres and a cross."""
    reset(); m = M(); vis = []; col = []
    w, d, h = 3.2, 4.0, 3.2
    vis.append(bx(m["white"], (0, 0, h / 2 + 0.2), (w, d, h - 0.4), 0.02))
    vis.append(bx(m["stone2"], (0, 0, 0.2), (w + 0.1, d + 0.1, 0.4), 0.03))
    vis.append(bx(m["plaster2"], (0, 0, h - 0.08), (w + 0.12, d + 0.12, 0.16), 0.03))           # cornice
    for sx in (-1, 1):
        for sy in (-1, 1):
            vis.append(bx(m["plaster2"], (sx * (w / 2 - 0.05), sy * (d / 2 - 0.05), h / 2), (0.22, 0.22, h - 0.1), 0.02))
        # an arched window on each side
        vis.append(bx(m["glass"], (sx * (w / 2 + 0.005), 0, 1.9), (0.04, 0.6, 0.9), 0.005))
        vis.append(disc(m["glass"], (sx * (w / 2 + 0.005), 0, 2.35), 0.3, 0.04, 'x', verts=16))
        vis.append(bx(m["dmetal"], (sx * (w / 2 + 0.03), 0, 2.0), (0.02, 0.03, 1.1), 0.003))
        vis.append(bx(m["dmetal"], (sx * (w / 2 + 0.03), 0, 1.9), (0.02, 0.6, 0.03), 0.003))
        vis.append(bx(m["stone"], (sx * (w / 2 + 0.06), 0, 1.42), (0.12, 0.75, 0.06), 0.01))
    # door: planks, an arch over it, iron bands, a padlock
    vis.extend(planks_wall(m["dwood"], m["wood"], (0, d / 2 + 0.03, 1.0), 1.0, 1.6, 'x', n=6, t=0.06, seed=3))
    half_disc = disc(m["dwood"], (0, d / 2 + 0.03, 1.8), 0.5, 0.06, 'y', verts=16)
    for v in half_disc.data.vertices:
        v.co.z = max(v.co.z, 1.8)
    vis.append(half_disc)
    for k in range(9):                                                                          # the stone arch
        a0, a1 = math.pi * k / 9, math.pi * (k + 1) / 9
        vis.append(beam(m["stone"], (math.cos(a0) * 0.58, d / 2 + 0.07, 1.8 + math.sin(a0) * 0.58),
                        (math.cos(a1) * 0.58, d / 2 + 0.07, 1.8 + math.sin(a1) * 0.58), 0.16, 0.08))
    for z in (0.5, 1.4):
        vis.append(bx(m["dmetal"], (0, d / 2 + 0.07, z), (1.0, 0.02, 0.06), 0.004))
    vis.append(bx(m["dmetal"], (0.15, d / 2 + 0.09, 1.0), (0.08, 0.04, 0.1), 0.01))
    for k in range(2):                                                                          # steps
        vis.append(bx(m["stone"], (0, d / 2 + 0.25 + k * 0.2, 0.15 - k * 0.07), (1.4, 0.4, 0.15), 0.02))
    # the roof along Y (ridge along Y): tile rows on two slopes, ridge caps
    pitch, over = 1.4, 0.25
    half = w / 2 + over
    a = math.atan2(pitch, half)
    L = math.hypot(half, pitch)
    rr = random.Random(9)
    for s in (-1, 1):
        rows = int(L / 0.28)
        for k in range(rows):
            t = (k + 0.5) / rows
            x = s * half * (1 - t)
            z = h + pitch * t
            for c in range(9):
                y = -d / 2 - over + (c + 0.5) * (d + 2 * over) / 9
                vis.append(bx(m["tile"] if rr.random() > 0.2 else m["tile2"], (x, y, z), (L / rows * 1.25, (d + 2 * over) / 9 * 0.97, 0.035), 0.008,
                              rot=(0, s * (a - 0.06), 0)))
    for c in range(10):
        y = -d / 2 - over + (c + 0.5) * (d + 2 * over) / 10
        vis.append(smooth(cyl(m["tile"], (0, y, h + pitch + 0.02), 0.1, (d + 2 * over) / 10, verts=10, rot=(PI2, 0, 0))))
    for sy in (-1, 1):                                                                          # gable triangles
        for k in range(7):
            t = k / 7
            vis.append(box(m["white"], (0, sy * (d / 2 - 0.05), h + pitch * (t + 1 / 14) - 0.04), (w * (1 - t - 1 / 7) + 0.05, 0.1, pitch / 7 + 0.01)))
    # the bell tower over the front gable
    ty = d / 2 - 0.6
    vis.append(bx(m["white"], (0, ty, h + 1.8), (0.9, 0.9, 1.2), 0.02))
    vis.append(bx(m["plaster2"], (0, ty, h + 2.42), (1.0, 1.0, 0.08), 0.01))
    for sx, sy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        for k in range(4):
            vis.append(box(m["dwood"], (sx * 0.455, ty + sy * 0.455, h + 1.9 + k * 0.1), (0.02 if sx else 0.5, 0.5 if sx else 0.02, 0.05), rot=(0.4 * sy, -0.4 * sx, 0)))
    vis.append(cyl(m["tile2"], (0, ty, h + 2.95), 0.68, 1.0, verts=4, r2=0.02, rot=(0, 0, math.pi / 4)))
    vis.append(ball(m["rust"], (0, ty, h + 3.5), 0.06))
    vis.append(bx(m["dmetal"], (0, ty, h + 3.75), (0.04, 0.04, 0.5), 0.005))
    vis.append(bx(m["dmetal"], (0, ty, h + 3.85), (0.28, 0.04, 0.04), 0.005))
    vis.append(lathe(m["rust"], [(0, h + 1.45), (0.2, h + 1.45), (0.18, h + 1.6), (0.12, h + 1.85), (0, h + 1.9)], 14))   # bell
    col.append(colbox("Chapel", (0, 0, h / 2), (w, d, h)))
    save("Chapel", vis, col, "chapel")

def bus_stop():
    """A concrete bus shelter: panelled walls, a slab roof with a drip edge, a plank bench, a sign on
    a pole, a torn timetable, a litter bin."""
    reset(); m = M(); vis = []; col = []
    for k in range(3):                                                                           # back wall of panels
        vis.append(bx(m["concrete"], (-1.0 + k * 1.0, 0, 1.1), (0.98, 0.15, 2.2), 0.02))
    for sx in (-1, 1):
        vis.append(bx(m["concrete"], (sx * 1.45, 0.6, 1.1), (0.12, 1.2, 2.2), 0.02))
        vis.append(bx(m["stone2"], (sx * 1.45, 1.15, 1.1), (0.14, 0.1, 2.2), 0.01))
    vis.append(bx(m["concrete"], (0, 0.55, 2.27), (3.25, 1.45, 0.14), 0.03))
    vis.append(bx(m["stone2"], (0, 1.27, 2.2), (3.25, 0.05, 0.08), 0.01))
    vis.append(ball(m["moss"], (-1.2, 0.5, 2.36), 0.25, (1.5, 1, 0.3)))
    # the bench: three planks on iron brackets
    for k in range(3):
        vis.append(bx(m["wood"], (0, 0.22 + k * 0.13, 0.46), (2.4, 0.11, 0.04), 0.008))
    for x in (-1.0, 0.0, 1.0):
        vis.append(bx(m["dmetal"], (x, 0.35, 0.3), (0.04, 0.4, 0.32), 0.005))
    vis.append(bx(m["wood"], (0, 0.1, 0.78), (2.4, 0.04, 0.16), 0.008))
    # sign on a pole
    vis.append(tb(m["metal"], (1.9, 0.9, 0), (1.9, 0.9, 2.6), 0.03, 8))
    vis.append(bx(m["white"], (1.9, 0.9, 2.45), (0.5, 0.03, 0.4), 0.01))
    vis.append(bx(m["blue"], (1.9, 0.915, 2.45), (0.4, 0.01, 0.3), 0.005))
    vis.append(disc(m["white"], (1.9, 0.925, 2.47), 0.09, 0.01, 'y', verts=12))
    vis.append(bx(m["white"], (-0.6, 0.085, 1.4), (0.55, 0.01, 0.75), 0.002))                  # timetable (torn)
    vis.append(bx(m["glass"], (-0.6, 0.09, 1.4), (0.6, 0.01, 0.8), 0.002))
    vis.append(bx(m["cloth"], (-0.45, 0.095, 1.15), (0.25, 0.01, 0.3), 0.002, rot=(0, 0.3, 0)))
    vis.append(tb(m["green"], (-1.75, 0.6, 0.0), (-1.75, 0.6, 0.6), 0.16, 12, r2=0.18))         # litter bin
    vis.append(torus(m["dmetal"], (-1.75, 0.6, 0.6), 0.18, 0.015, seg=12))
    col.append(colbox("Stop", (0, 0.1, 1.1), (3.0, 0.4, 2.2)))
    col.append(colbox("SideL", (-1.45, 0.6, 1.1), (0.15, 1.2, 2.2)))
    col.append(colbox("SideR", (1.45, 0.6, 1.1), (0.15, 1.2, 2.2)))
    save("Bus_Stop", vis, col, "bus_stop")

def coop():
    """Chicken coop of grey boards on four legs, a tiled lean-to roof, the little door hanging open,
    the ramp down. Inside: feathers. No chickens."""
    reset(); m = M(); vis = []; col = []
    vis.append(bx(m["dwood"], (0, 0, 0.3), (2.0, 1.4, 0.08), 0.01))                             # floor
    vis.extend(planks_wall(m["gwood"], m["wood"], (0, -0.68, 0.85), 2.0, 1.1, 'x', seed=1))
    vis.extend(planks_wall(m["gwood"], m["wood"], (0, 0.68, 0.8), 2.0, 1.0, 'x', seed=2))
    vis.extend(planks_wall(m["gwood"], m["wood"], (0.98, 0, 0.82), 1.32, 1.04, 'y', seed=3))
    vis.extend(planks_wall(m["gwood"], m["wood"], (-0.98, 0, 0.82), 1.32, 1.04, 'y', seed=4))
    for sx in (-1, 1):
        for sy in (-1, 1):
            vis.append(bx(m["dwood"], (sx * 0.95, sy * 0.65, 0.68), (0.09, 0.09, 1.36), 0.01))
    vis.append(bx(m["black"], (0.5, 0.71, 0.72), (0.34, 0.02, 0.4), 0.003))                   # the hole
    door = bx(m["gwood"], (0.5, 0.72, 0.72), (0.34, 0.03, 0.4), 0.005)
    origin_at(door, (0.33, 0.72, 0.72))
    door.rotation_euler = (0, 0, -1.9)
    apply_xf(door)
    vis.append(door)
    vis.append(bx(m["wood"], (0.5, 0.98, 0.35), (0.3, 0.62, 0.03), 0.005, rot=(0.75, 0, 0)))   # ramp with slats
    for k in range(4):
        vis.append(box(m["dwood"], (0.5, 0.82 + k * 0.12, 0.5 - k * 0.11), (0.3, 0.02, 0.02)))
    # the lean-to roof: tile rows
    for k in range(6):
        y = -0.85 + k * 0.32
        vis.append(bx(m["tile"] if k % 2 else m["tile2"], (0, y, 1.45 - y * 0.25), (2.3, 0.42, 0.04), 0.008, rot=(-0.25, 0, 0)))
    for k in range(6):
        vis.append(box(m["white"], (0.6 + (k % 3) * 0.3, 1.4 + (k // 3) * 0.4, 0.02), (0.08, 0.03, 0.01), rot=(0, 0, k)))
        vis.append(box(m["white"], (-0.6 + (k % 3) * 0.25, 0.1 * k - 0.2, 0.345), (0.07, 0.025, 0.01), rot=(0, 0, k * 1.3)))
    col.append(colbox("Coop", (0, 0, 0.8), (2.0, 1.4, 1.6)))
    save("Kurnik", vis, col, "coop")

def scarecrow():
    """A scarecrow in the field: a pole and crossbar, an old coat with rags, a burlap head with a
    stitched face under a felt hat. The head hangs too far to one side."""
    reset(); m = M(); vis = []; col = []
    coat = mat2("VCoat", (0.24, 0.2, 0.15), 0.95)
    vis.append(bx(m["dwood"], (0, 0, 1.1), (0.1, 0.1, 2.2), 0.01))
    vis.append(bx(m["dwood"], (0, 0, 1.7), (1.6, 0.08, 0.08), 0.01))
    vis.append(bx(coat, (0, 0, 1.4), (0.62, 0.32, 0.72), 0.06))
    vis.append(bx(coat, (0, 0, 0.95), (0.66, 0.34, 0.3), 0.05))
    for k in range(7):                                                                          # torn hem strips
        vis.append(bx(coat, (-0.27 + k * 0.09, 0.0, 0.72 - (k % 3) * 0.05), (0.07, 0.3, 0.2), 0.01, rot=(0, (k - 3) * 0.05, 0)))
    for sx in (-1, 1):                                                                          # sleeves on the crossbar
        vis.append(tb(coat, (sx * 0.28, 0, 1.68), (sx * 0.75, 0, 1.66), 0.085, 10, r2=0.07))
        for k in range(4):
            vis.append(tb(m["straw"], (sx * 0.75, 0, 1.66), (sx * (0.83 + k * 0.02), (k - 1.5) * 0.03, 1.55 - k * 0.03), 0.012, 4))
        vis.append(bx(m["sack"], (sx * 0.12, 0.17, 1.55), (0.12, 0.02, 0.14), 0.01))             # patches
    vis.append(bx(m["blue"], (0, 0, 1.18), (0.5, 0.33, 0.06), 0.01))                           # a rope belt (blue cord)
    vis.append(tb(m["straw"], (0, 0, 1.78), (0.06, 0.02, 1.9), 0.06, 8))                       # straw neck
    # the head: burlap sack tied at the neck, cross-stitched eyes, a stitched mouth; tilted hard
    head = [ball(m["sack"], (0, 0, 0), 0.22, (1, 0.95, 1.15), seg=14, rings=10)]
    for x in (0.08, -0.08):
        head.append(box(m["black"], (x, 0.2, 0.05), (0.07, 0.02, 0.015), rot=(0, 0.785, 0)))
        head.append(box(m["black"], (x, 0.2, 0.05), (0.07, 0.02, 0.015), rot=(0, -0.785, 0)))
    head.append(box(m["black"], (0, 0.205, -0.08), (0.16, 0.02, 0.012)))
    for k in range(5):
        head.append(box(m["black"], (-0.06 + k * 0.03, 0.205, -0.08), (0.008, 0.02, 0.04)))
    head.append(torus(m["straw"], (0, 0, -0.2), 0.1, 0.025, seg=12))
    head.append(disc(m["soot"], (0, 0, 0.22), 0.36, 0.03, verts=18))                           # hat brim
    head.append(disc(m["soot"], (0, 0, 0.32), 0.18, 0.2, verts=16, r2=0.15))
    head.append(disc(m["candle"], (0, 0, 0.25), 0.185, 0.04, verts=16))
    ho = join(head, "Head")
    ho.rotation_euler = (0.25, 0.75, 0.2)
    ho.location = (0.12, 0.04, 2.0)
    apply_xf(ho)
    vis.append(ho)
    col.append(colbox("Scare", (0, 0, 1.1), (0.3, 0.3, 2.2)))
    save("Scarecrow", vis, col, "scarecrow")

def sheet(mt, x0, x1, top, h, seed, sway=0.04):
    """A hanging sheet: a subdivided plane with soft folds and a sagging hem."""
    r = random.Random(seed)
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=10, y_subdivisions=6, size=1)
    o = bpy.context.active_object
    for v in o.data.vertices:
        u = v.co.x + 0.5; t = v.co.y + 0.5            # u across, t up (0 = hem)
        x = x0 + (x1 - x0) * u
        z = top - h * (1 - t)
        y = math.sin(u * 9 + seed) * 0.03 * (1 - t) + sway * (1 - t) ** 2
        z -= 0.04 * math.sin(u * math.pi) * (1 - t)
        v.co = Vector((x, y, z))
    o.data.materials.append(mt)
    o2 = o.copy(); o2.data = o.data.copy(); bpy.context.scene.collection.objects.link(o2)
    for v in o2.data.vertices:
        v.co.y += 0.004
    o2.data.flip_normals()
    return [smooth(o), smooth(o2)]

def laundry():
    """A laundry line between two T-posts, sheets and a shirt hanging still, wooden pegs."""
    reset(); m = M(); vis = []; col = []
    for sx in (-1, 1):
        vis.append(bx(m["gwood"], (sx * 2.5, 0, 0.9), (0.08, 0.08, 1.8), 0.01))
        vis.append(bx(m["gwood"], (sx * 2.5, 0, 1.76), (0.07, 0.6, 0.07), 0.01))
        vis.append(beam(m["gwood"], (sx * 2.5, 0, 1.45), (sx * 2.5, 0.25, 1.74), 0.04, 0.04))
        vis.append(beam(m["gwood"], (sx * 2.5, 0, 1.45), (sx * 2.5, -0.25, 1.74), 0.04, 0.04))
        col.append(colbox("Post%d" % (sx + 1), (sx * 2.5, 0, 0.9), (0.1, 0.1, 1.8)))
    # the line sags a little (a few segments)
    pts = [(-2.5 + k * 0.5, 0, 1.78 - 0.08 * math.sin(k / 10 * math.pi)) for k in range(11)]
    for a, b in zip(pts, pts[1:]):
        vis.append(tb(m["white"], a, b, 0.008, 4))
    def sag(x):
        return 1.78 - 0.08 * math.sin((x + 2.5) / 5 * math.pi)
    for k, (x, w, c, hh) in enumerate(((-1.6, 1.2, "white", 1.1), (-0.2, 0.9, "cloth", 0.7), (1.2, 1.3, "white", 1.05))):
        vis.extend(sheet(m[c], x - w / 2, x + w / 2, sag(x) - 0.01, hh, k))
        for px in (x - w / 2 + 0.05, x + w / 2 - 0.05):
            vis.append(bx(m["wood"], (px, 0, sag(px) - 0.02), (0.02, 0.015, 0.08), 0.003))
    save("Laundry", vis, col, "laundry")

def trough():
    """A hollowed stone trough with dark still water, a rusty hand pump at one end."""
    reset(); m = M(); vis = []; col = []
    vis.append(jitter(bx(m["stone"], (0, 0, 0.1), (2.2, 0.7, 0.2), 0.04), 0.008, 1))
    for sy in (-1, 1):
        vis.append(jitter(bx(m["stone"], (0, sy * 0.3, 0.42), (2.2, 0.1, 0.5), 0.03), 0.006, 2 + sy))
    for sx in (-1, 1):
        vis.append(jitter(bx(m["stone"], (sx * 1.05, 0, 0.42), (0.1, 0.5, 0.5), 0.03), 0.006, 5 + sx))
    vis.append(box(mat2("VWater", (0.05, 0.07, 0.08), 0.05), (0, 0, 0.58), (2.0, 0.5, 0.02)))
    vis.append(ball(m["moss"], (0.9, 0.33, 0.2), 0.12, (2, 0.5, 1)))
    vis.append(ball(m["moss"], (-0.6, -0.33, 0.3), 0.1, (2.5, 0.5, 1)))
    # the pump on the end wall
    vis.append(tb(m["rust"], (0.92, 0, 0.67), (0.92, 0, 1.25), 0.05, 10))
    vis.append(tb(m["rust"], (0.92, 0, 1.15), (0.75, 0, 1.08), 0.025, 8))
    vis.append(disc(m["dmetal"], (0.92, 0, 1.27), 0.06, 0.04, verts=10))
    vis.append(beam(m["dmetal"], (0.92, 0, 1.27), (1.05, 0, 1.6), 0.025, 0.025))
    col.append(colbox("Trough", (0, 0, 0.35), (2.2, 0.7, 0.7)))
    save("Trough", vis, col, "trough")

ALL = dict(house_roof=house_roof, window=window, well=well, woodpile=woodpile, tractor=tractor, pole=pole,
           cross=wayside_cross, chapel=chapel, bus_stop=bus_stop, coop=coop, scarecrow=scarecrow, laundry=laundry, trough=trough,
           car_blue=lambda: car(("Blue", (0.15, 0.25, 0.45))), car_red=lambda: car(("Red", (0.45, 0.1, 0.08))),
           car_beige=lambda: car(("Beige", (0.6, 0.55, 0.42))))
for k, f in ALL.items():
    if not ONLY or k in ONLY:
        f()
        print("built", k)

if "--gallery" in sys.argv:
    out = sys.argv[sys.argv.index("--gallery") + 1]
    names = [k for k in ALL if not ONLY or k in ONLY]
    gallery(out, [os.path.join(OUTDIR, "v_%s.glb" % n) for n in names], cols=4, spacing=9.0, target_z=1.2,
            dist=46, height=18, angle=0.35, res=(1600, 1200))
