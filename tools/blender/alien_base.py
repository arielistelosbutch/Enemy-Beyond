"""Enemy Beyond 0.56 - their base on Earth (own designs): the garden growing in the violet caves
(glowing bulbs, orange trumpets, red coral, broad leaves, stalagmites) and the things in the built
halls (seats, ribbed barrels, consoles, orb lamps, crates, cage frames, the hatchery tank, the control
core's collar) and our cable lift in the shaft. Dark violet alloy and pale panels as the UFOs.
Front = +Y (Godot -Z), origin on the ground.
Run: python3 tools/blender/alien_base.py <outdir> [--only a,b] [--gallery out.png]"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
from kit import *

ARGS = [a for a in sys.argv[1:] if not a.startswith("--") and not a.endswith(".png") and "," not in a]
OUTDIR = ARGS[0] if ARGS else "."
ONLY = sys.argv[sys.argv.index("--only") + 1].split(",") if "--only" in sys.argv else []

def M():
    return dict(
        rock=mat2("ABRock", (0.2, 0.14, 0.24), 0.9), rock2=mat2("ABRockDark", (0.12, 0.08, 0.15), 0.9),
        bulb=mat2("ABBulb", (0.75, 0.4, 0.95), 0.4, emit=1.2), stem=mat2("ABStem", (0.25, 0.3, 0.2), 0.8),
        trumpet=mat2("ABTrumpet", (0.95, 0.5, 0.12), 0.6), throat=mat2("ABThroat", (1.0, 0.85, 0.3), 0.5, emit=1.2),
        coral=mat2("ABCoral", (0.6, 0.08, 0.1), 0.7), leaf=mat2("ABLeaf", (0.18, 0.5, 0.25), 0.7),
        leaf2=mat2("ABLeafVein", (0.4, 0.8, 0.45), 0.6),
        alloy=mat2("UfoHull", (0.2, 0.17, 0.22), 0.35, 0.7), dark=mat2("UfoDark", (0.07, 0.06, 0.08), 0.4, 0.6),
        panel=mat2("ABPanel", (0.75, 0.74, 0.8), 0.5, 0.2), seat=mat2("ABSeat", (0.3, 0.45, 0.82), 0.5),
        barrel=mat2("ABBarrel", (0.5, 0.34, 0.18), 0.6, 0.3), glow=mat2("UfoGlow", (0.85, 0.25, 1.0), emit=4.0),
        screen=mat2("ABScreen", (0.25, 1.0, 0.6), emit=2.5), cyan=mat2("ABCyan", (0.35, 0.9, 1.0), emit=2.0),
        red=mat2("ABOrb", (1.0, 0.18, 0.15), emit=4.0), yellow=mat2("ABCageFrame", (0.9, 0.68, 0.12), 0.5, 0.4),
        crate=mat2("ABCrate", (0.68, 0.48, 0.8), 0.6), green=mat2("ABCoreRing", (0.3, 1.0, 0.5), emit=4.0),
        steel=mat2("VMetal", (0.3, 0.31, 0.33), 0.45, 0.7), ours=mat2("VYellowPaint", (0.8, 0.62, 0.15), 0.6, 0.3),
        cable=mat2("VIron", (0.1, 0.1, 0.11), 0.6, 0.6),
    )

def save(name, vis, col, fname):
    o = join(vis, name)
    export_glb(os.path.join(OUTDIR, "v_%s.glb" % fname), [o] + col)

# ---- the garden ----------------------------------------------------------------------------------
def bulbs():
    """A clump of glowing violet bulbs on short stalks."""
    reset(); m = M(); vis = []
    rr = random.Random(2)
    for k in range(5):
        a = k * 1.3
        d = 0.0 if k == 0 else rr.uniform(0.2, 0.42)
        x, y = math.cos(a) * d, math.sin(a) * d
        h = rr.uniform(0.25, 0.7)
        r = rr.uniform(0.12, 0.24)
        vis.append(tb(m["stem"], (x, y, 0), (x * 1.1, y * 1.1, h), 0.03, 6))
        vis.append(ball(m["bulb"], (x * 1.1, y * 1.1, h + r * 0.8), r, (1, 1, 1.35), seg=10, rings=7))
    vis.append(ball(m["rock2"], (0, 0, 0), 0.4, (1.2, 1, 0.3), seg=8, rings=4))
    save("Bulbs", vis, [], "ab_bulbs")

def trumpets():
    """Orange trumpet flowers on curved stems, the throats glowing."""
    reset(); m = M(); vis = []
    rr = random.Random(5)
    for k in range(4):
        a = k * TAU / 4 + 0.4
        x, y = math.cos(a) * 0.18, math.sin(a) * 0.18
        h = rr.uniform(0.45, 0.85)
        tip = (x * 2.4, y * 2.4, h)
        vis.append(tb(m["stem"], (x, y, 0), tip, 0.025, 6))
        o = lathe(m["trumpet"], [(0.02, 0.0), (0.06, 0.12), (0.13, 0.22), (0.22, 0.27)], 10, sm=False)
        o.rotation_euler = (math.atan2(math.hypot(x, y) * 1.4, h) * 0.9, 0, a - PI2)
        o.location = tip
        apply_xf(o)
        vis.append(o)
        vis.append(ball(m["throat"], tip, 0.05, seg=6, rings=4))
    save("Trumpets", vis, [], "ab_trumpets")

def coral():
    """Red branching coral, a forked fan."""
    reset(); m = M(); vis = []
    rr = random.Random(9)
    def branch(p, d, l, w, depth):
        q = (p[0] + d[0] * l, p[1] + d[1] * l, p[2] + d[2] * l)
        vis.append(tb(m["coral"], p, q, w, 6))
        if depth > 0:
            for s in (-1, 1):
                nd = (d[0] + s * rr.uniform(0.3, 0.6), d[1] + rr.uniform(-0.3, 0.3), d[2])
                n = math.sqrt(sum(c * c for c in nd))
                branch(q, (nd[0] / n, nd[1] / n, nd[2] / n), l * 0.7, w * 0.7, depth - 1)
        else:
            vis.append(ball(m["coral"], q, w * 1.4, seg=6, rings=4))
    for k in range(3):
        a = k * TAU / 3
        branch((math.cos(a) * 0.08, math.sin(a) * 0.08, 0), (math.cos(a) * 0.3, math.sin(a) * 0.3, 0.95), 0.4, 0.045, 2)
    save("Coral", vis, [], "ab_coral")

def leaves():
    """Broad flat leaves fanned out on the floor with pale veins."""
    reset(); m = M(); vis = []
    for k in range(6):
        a = k * TAU / 6 + 0.2
        ln = 0.5 + 0.12 * (k % 3)
        pts = [(0, 0), (0.14, ln * 0.35), (0.12, ln * 0.75), (0, ln), (-0.12, ln * 0.75), (-0.14, ln * 0.35)]
        o = plate(m["leaf"], pts, 0.0, 0.015)
        o.rotation_euler = (0.35, 0, a)
        o.location = (0, 0, 0.03)
        apply_xf(o)
        vis.append(o)
        vis.append(beam(m["leaf2"], (0, 0, 0.04), (math.cos(a + PI2) * ln * 0.9, math.sin(a + PI2) * ln * 0.9, 0.04 + ln * 0.9 * math.sin(0.35)), 0.012, 0.012))
    save("Leaves", vis, [], "ab_leaves")

def stalagmite(fname, h, seed):
    """A violet rock spire, knobbly, with a smaller one at its foot (cover)."""
    reset(); m = M(); vis = []; col = []
    rr = random.Random(seed)
    prof = [(0.0, 0.0), (0.7, 0.0), (0.6, h * 0.2), (0.42, h * 0.5), (0.22, h * 0.8), (0.0, h)]
    o = lathe(m["rock"], prof, 9, sm=False)
    vis.append(jitter(o, 0.06, seed))
    o2 = lathe(m["rock2"], [(0.0, 0.0), (0.35, 0.0), (0.2, h * 0.3), (0.0, h * 0.42)], 7, 0.62, 0.25, sm=False)
    vis.append(jitter(o2, 0.04, seed + 1))
    for k in range(3):
        a = rr.uniform(0, TAU)
        vis.append(ball(m["rock2"], (math.cos(a) * 0.55, math.sin(a) * 0.55, 0.1), rr.uniform(0.15, 0.25), (1.2, 1, 0.7), seg=7, rings=4))
    col.append(colbox("Spire", (0, 0, h * 0.3), (0.9, 0.9, h * 0.6)))
    save("Stalagmite", vis, col, fname)

# ---- the halls -----------------------------------------------------------------------------------
def seat():
    """A seat of theirs: a blue bowl on a dark stem, low (they are small)."""
    reset(); m = M(); vis = []; col = []
    vis.append(disc(m["dark"], (0, 0, 0.02), 0.26, 0.04, verts=10))
    vis.append(tb(m["dark"], (0, 0, 0), (0, 0, 0.42), 0.07, 8))
    vis.append(lathe(m["seat"], [(0, 0.4), (0.22, 0.42), (0.3, 0.55), (0.32, 0.72), (0.28, 0.74), (0.2, 0.5), (0, 0.48)], 14, sm=False))
    vis.append(torus(m["glow"], (0, 0, 0.73), 0.3, 0.012, seg=16))
    col.append(colbox("Seat", (0, 0, 0.37), (0.6, 0.6, 0.74)))
    save("Seat", vis, col, "ab_seat")

def barrel():
    """Their barrel: a fat drum with ribs, a lit band and a valve on top."""
    reset(); m = M(); vis = []; col = []
    vis.append(lathe(m["barrel"], [(0, 0), (0.5, 0), (0.6, 0.15), (0.62, 0.55), (0.6, 0.95), (0.5, 1.1), (0, 1.1)], 16, sm=True))
    for z in (0.25, 0.55, 0.85):
        vis.append(torus(m["dark"], (0, 0, z), 0.62, 0.03, seg=18))
    vis.append(torus(m["glow"], (0, 0, 0.4), 0.625, 0.012, seg=18))
    vis.append(disc(m["alloy"], (0, 0, 1.13), 0.2, 0.06, verts=10))
    vis.append(tb(m["alloy"], (0.12, 0, 1.12), (0.12, 0, 1.25), 0.03, 6))
    col.append(colbox("Barrel", (0, 0, 0.55), (1.2, 1.2, 1.1)))
    save("Barrel", vis, col, "ab_barrel")

def console():
    """A console: a pink-grey pedestal leaning back, a glowing face, slits of light, a screen above."""
    reset(); m = M(); vis = []; col = []
    vis.append(lathe(m["panel"], [(0, 0), (0.55, 0), (0.5, 0.15), (0.4, 0.75), (0.5, 0.95), (0, 0.98)], 8, sm=False))
    vis.append(bx(m["dark"], (0, 0.08, 1.0), (0.85, 0.5, 0.05), 0.02, rot=(-0.35, 0, 0)))
    vis.append(bx(m["screen"], (0, 0.08, 1.03), (0.7, 0.36, 0.02), 0.0, rot=(-0.35, 0, 0)))
    for k in range(4):
        vis.append(bx(m["cyan"], (-0.25 + k * 0.17, 0.33, 0.9), (0.06, 0.02, 0.12), 0.0))
    vis.append(tb(m["dark"], (0, -0.35, 0.9), (0, -0.35, 1.5), 0.03, 6))
    vis.append(bx(m["dark"], (0, -0.33, 1.55), (0.9, 0.06, 0.55), 0.02))
    vis.append(bx(m["screen"], (0, -0.295, 1.55), (0.8, 0.01, 0.45), 0.0))
    col.append(colbox("Console", (0, 0, 0.55), (1.0, 1.0, 1.1)))
    save("Console", vis, col, "ab_console")

def orb_lamp():
    """A red orb on a thin stand with three feet."""
    reset(); m = M(); vis = []; col = []
    for k in range(3):
        a = k * TAU / 3
        vis.append(beam(m["dark"], (0, 0, 0.4), (math.cos(a) * 0.3, math.sin(a) * 0.3, 0.0), 0.04, 0.04))
    vis.append(tb(m["alloy"], (0, 0, 0.35), (0, 0, 1.2), 0.035, 6))
    vis.append(torus(m["alloy"], (0, 0, 1.22), 0.2, 0.025, seg=14))
    vis.append(ball(m["red"], (0, 0, 1.44), 0.22, seg=12, rings=8))
    col.append(colbox("Lamp", (0, 0, 0.7), (0.25, 0.25, 1.4)))
    save("OrbLamp", vis, col, "ab_orb_lamp")

def crate():
    """Their crate: a pale violet box with bevelled edges, dark corner caps and a glowing seal."""
    reset(); m = M(); vis = []; col = []
    vis.append(bx(m["crate"], (0, 0, 0.5), (1.0, 1.0, 1.0), 0.06))
    for sx in (-1, 1):
        for sy in (-1, 1):
            for z in (0.06, 0.94):
                vis.append(bx(m["dark"], (sx * 0.45, sy * 0.45, z), (0.14, 0.14, 0.14), 0.02))
    vis.append(bx(m["dark"], (0, 0.505, 0.5), (0.6, 0.02, 0.16), 0.01))
    vis.append(bx(m["glow"], (0, 0.515, 0.5), (0.4, 0.01, 0.05), 0.0))
    vis.append(bx(m["dark"], (0, 0, 1.005), (0.7, 0.7, 0.02), 0.01))
    col.append(colbox("Crate", (0, 0, 0.5), (1.0, 1.0, 1.0)))
    save("Crate", vis, col, "ab_crate")

def cage_frame():
    """The cage's frame (the glass and the colliders stay in the game): yellow posts with feet and caps,
    the roof with a lamp, bars on the front side."""
    reset(); m = M(); vis = []
    for sx in (-0.8, 0.8):
        for sy in (-0.8, 0.8):
            vis.append(bx(m["yellow"], (sx, sy, 1.1), (0.09, 0.09, 2.2), 0.01))
            vis.append(bx(m["dark"], (sx, sy, 0.04), (0.2, 0.2, 0.08), 0.01))
    vis.append(bx(m["yellow"], (0, 0, 2.22), (1.75, 1.75, 0.08), 0.02))
    vis.append(bx(m["dark"], (0, 0, 2.28), (1.2, 1.2, 0.05), 0.01))
    vis.append(disc(m["cyan"], (0, 0, 2.17), 0.25, 0.02, verts=12))
    vis.append(bx(m["dark"], (0, 0, 0.03), (1.6, 1.6, 0.06), 0.01))
    for k in range(5):
        vis.append(tb(m["steel"], (-0.56 + k * 0.28, -0.8, 0.08), (-0.56 + k * 0.28, -0.8, 2.18), 0.018, 6))
    vis.append(bx(m["steel"], (0, -0.8, 1.1), (1.6, 0.04, 0.05), 0.0))
    save("CageFrame", vis, [], "ab_cage")

def tank():
    """The hatchery tank's plinth and lid (the green liquid stays in the game): ribbed, pipes to the floor."""
    reset(); m = M(); vis = []
    vis.append(lathe(m["panel"], [(0, 0), (1.05, 0), (1.0, 0.3), (0.85, 0.32), (0, 0.32)], 16, sm=False))
    vis.append(torus(m["green"], (0, 0, 0.3), 0.86, 0.02, seg=20))
    vis.append(lathe(m["panel"], [(0, 2.3), (0.86, 2.3), (0.95, 2.45), (0.6, 2.65), (0, 2.7)], 16, sm=False))
    for k in range(4):
        a = k * TAU / 4 + 0.4
        vis.append(tb(m["dark"], (math.cos(a) * 0.82, math.sin(a) * 0.82, 0.3), (math.cos(a) * 0.82, math.sin(a) * 0.82, 2.3), 0.035, 6))
        vis.append(tb(m["dark"], (math.cos(a) * 0.7, math.sin(a) * 0.7, 2.6), (math.cos(a) * 1.4, math.sin(a) * 1.4, 0.05), 0.05, 6))
    save("Tank", vis, [], "ab_tank")

def core_collar():
    """The control core's dressing (the pillar itself is the game's breakable): a stepped base,
    fins round it, cables to the floor, a crown on top."""
    reset(); m = M(); vis = []
    vis.append(lathe(m["dark"], [(0, 0), (1.4, 0), (1.35, 0.2), (1.15, 0.25), (1.1, 0.6), (0, 0.6)], 12, sm=False))
    for k in range(6):
        a = k * TAU / 6
        vis.append(bx(m["alloy"], (math.cos(a) * 0.75, math.sin(a) * 0.75, 1.6), (0.36, 0.08, 2.0), 0.02, rot=(0, 0, a)))
        vis.append(tb(m["cable"], (math.cos(a) * 0.95, math.sin(a) * 0.95, 0.6), (math.cos(a) * 1.8, math.sin(a) * 1.8, 0.03), 0.05, 6))
    vis.append(lathe(m["alloy"], [(0.5, 3.5), (0.8, 3.55), (0.6, 3.8), (0.2, 4.0), (0, 4.05)], 12, sm=False))
    vis.append(lathe(m["green"], [(0, 4.0), (0.08, 4.0), (0.02, 4.4), (0, 4.4)], 6, sm=False))
    save("CoreCollar", vis, [], "ab_core")

def lift():
    """Our cable lift down the shaft: a steel cage platform in yellow paint, a winch frame overhead,
    cables, a work lamp (the light stays in the game)."""
    reset(); m = M(); vis = []
    vis.append(bx(m["steel"], (0, 0, 0.08), (3.0, 3.0, 0.16), 0.02))
    for k in range(6):
        vis.append(bx(m["dark"], (-1.25 + k * 0.5, 0, 0.165), (0.04, 2.9, 0.01), 0.0))
    for sx in (-1.45, 1.45):
        for sy in (-1.45, 1.45):
            vis.append(bx(m["ours"], (sx, sy, 0.65), (0.08, 0.08, 1.0), 0.0))
        vis.append(bx(m["ours"], (sx, 0, 1.1), (0.06, 2.9, 0.06), 0.0))
    vis.append(bx(m["ours"], (0, 1.45, 1.1), (2.9, 0.06, 0.06), 0.0))
    for sx in (-1.5, 1.5):
        vis.append(bx(m["ours"], (sx, 0, 2.95), (0.12, 0.12, 5.9), 0.0))
    vis.append(bx(m["ours"], (0, 0, 5.4), (3.2, 0.2, 0.2), 0.02))
    vis.append(disc(m["dark"], (0, 0, 5.4), 0.3, 0.6, axis='x', verts=12))
    for sx in (-0.2, 0.2):
        vis.append(tb(m["cable"], (sx, 0, 5.3), (sx, 0, 1.1), 0.012, 4))
    vis.append(bx(m["dark"], (1.3, 1.3, 1.4), (0.25, 0.2, 0.3), 0.02))
    vis.append(disc(m["throat"], (1.3, 1.19, 1.4), 0.08, 0.02, axis='y', verts=10))
    save("Lift", vis, [], "ab_lift")

ALL = dict(ab_bulbs=bulbs, ab_trumpets=trumpets, ab_coral=coral, ab_leaves=leaves,
           ab_spire=lambda: stalagmite("ab_spire", 2.4, 3), ab_spire_low=lambda: stalagmite("ab_spire_low", 1.3, 7),
           ab_seat=seat, ab_barrel=barrel, ab_console=console, ab_orb_lamp=orb_lamp, ab_crate=crate,
           ab_cage=cage_frame, ab_tank=tank, ab_core=core_collar, ab_lift=lift)
for k, f in ALL.items():
    if not ONLY or k in ONLY:
        f()
        print("built", k)

if "--gallery" in sys.argv:
    out = sys.argv[sys.argv.index("--gallery") + 1]
    names = [k for k in ALL if not ONLY or k in ONLY]
    gallery(out, [os.path.join(OUTDIR, "v_%s.glb" % n) for n in names], cols=5, spacing=3.6, target_z=1.0,
            dist=20, height=8, angle=0.0, res=(1600, 1000))
