"""Enemy Beyond 0.56 - small things of towns, yards and the base (own designs): a sandbag wall, a park bench,
a flower bed, oil drums, a pallet, an iron railing, a wire fence panel, a workbench, a litter bin.
Low-poly with flat facets like the village props. Front = +Y (Godot -Z), origin on the ground.
Run: python3 tools/blender/street.py <outdir> [--only a,b] [--gallery out.png]"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
from kit import *
from common import _finish
from mathutils import Vector

ARGS = [a for a in sys.argv[1:] if not a.startswith("--") and not a.endswith(".png") and "," not in a]
OUTDIR = ARGS[0] if ARGS else "."
ONLY = sys.argv[sys.argv.index("--only") + 1].split(",") if "--only" in sys.argv else []

def M():
    return dict(
        sack=mat2("VBurlap", (0.42, 0.36, 0.22), 0.95), sack2=mat2("VBurlapDark", (0.33, 0.28, 0.17), 0.95),
        wood=mat2("VWood", (0.33, 0.22, 0.12), 0.9), dwood=mat2("VDarkWood", (0.18, 0.12, 0.07), 0.9),
        iron=mat2("VIron", (0.1, 0.1, 0.11), 0.6, 0.6), metal=mat2("VMetal", (0.3, 0.31, 0.33), 0.45, 0.7),
        dmetal=mat2("VMetalDark", (0.12, 0.12, 0.13), 0.5, 0.6), galv=mat2("VGalvanized", (0.5, 0.52, 0.53), 0.5, 0.6),
        red=mat2("VRedPaint", (0.45, 0.1, 0.07), 0.55, 0.2), blue=mat2("VBluePaint", (0.15, 0.22, 0.35), 0.6, 0.2),
        green=mat2("VGreenPaint", (0.16, 0.26, 0.14), 0.7), soil=mat2("VSoil", (0.2, 0.14, 0.09), 0.95),
        stone=mat2("VStone", (0.45, 0.44, 0.41), 0.95), leaf=mat2("VLeaves", (0.17, 0.27, 0.1), 0.95),
        rust=mat2("VRust", (0.38, 0.18, 0.08), 0.85, 0.3),
    )

def save(name, vis, col, fname):
    o = join(vis, name)
    export_glb(os.path.join(OUTDIR, "v_%s.glb" % fname), [o] + col)

def bag(m, c, rot_z, seed):
    """One sandbag: a stuffed pillow, sagging, the tied end."""
    o = ball(m, c, 0.5, (0.62, 0.34, 0.3), seg=10, rings=6, rot=(0, 0, rot_z))
    return jitter(o, 0.012, seed)

def sandbags():
    """A sandbag wall 3 m long and three layers high, staggered like bricks, the top layer shorter."""
    reset(); m = M(); vis = []; col = []
    rr = random.Random(1)
    for row in range(3):
        n = 5 - row
        off = (row % 2) * 0.3
        z = 0.15 + row * 0.27
        for k in range(n):
            x = -1.2 + off + k * 0.6 + row * 0.15
            vis.append(bag(m["sack"] if (k + row) % 3 else m["sack2"], (x, rr.uniform(-0.04, 0.04), z), rr.uniform(-0.08, 0.08), row * 10 + k))
            vis.append(bag(m["sack2"] if (k + row) % 2 else m["sack"], (x + 0.05, rr.uniform(-0.04, 0.04) + 0.3 * (1 if row < 2 else 0), z), rr.uniform(-0.08, 0.08), row * 10 + k + 50))
    col.append(colbox("Bags", (0, 0.15, 0.4), (3.0, 0.6, 0.8)))
    save("Sandbags", vis, col, "sandbags")

def bench():
    """A park bench: cast-iron sides, wooden slats on the seat and the back."""
    reset(); m = M(); vis = []; col = []
    for sx in (-0.72, 0.72):
        vis.append(beam(m["iron"], (sx, 0.2, 0.0), (sx, 0.18, 0.44), 0.05, 0.05))
        vis.append(beam(m["iron"], (sx, -0.18, 0.0), (sx, -0.2, 0.86), 0.05, 0.05))
        vis.append(beam(m["iron"], (sx, 0.22, 0.43), (sx, -0.2, 0.43), 0.05, 0.05))
        vis.append(beam(m["iron"], (sx, 0.22, 0.43), (sx, 0.25, 0.62), 0.04, 0.04))
    for k in range(4):
        vis.append(bx(m["wood"], (0, 0.17 - k * 0.105, 0.46), (1.6, 0.085, 0.035), 0.008))
    for k in range(3):
        vis.append(bx(m["wood"], (0, -0.21, 0.56 + k * 0.11), (1.6, 0.03, 0.08), 0.008))
    col.append(colbox("Bench", (0, 0, 0.25), (1.5, 0.45, 0.5)))
    save("Bench", vis, col, "bench")

def flower_bed():
    """A raised bed in a stone kerb, dark soil, clumps of flowers in three colours."""
    reset(); m = M(); vis = []
    for sx in (-1, 1):
        vis.append(bx(m["stone"], (sx * 1.25, 0, 0.12), (0.12, 2.6, 0.24), 0.02))
        vis.append(bx(m["stone"], (0, sx * 1.25, 0.12), (2.38, 0.12, 0.24), 0.02))
    vis.append(bx(m["soil"], (0, 0, 0.18), (2.4, 2.4, 0.08), 0.0))
    rr = random.Random(5)
    cols = [mat2("VFlowerYellow", (0.85, 0.65, 0.1), 0.8), mat2("VFlowerRed", (0.75, 0.15, 0.2), 0.8), mat2("VFlowerViolet", (0.55, 0.35, 0.75), 0.8),
            mat2("VFlowerWhite", (0.85, 0.85, 0.8), 0.8)]
    for k in range(26):
        x, y = rr.uniform(-1.0, 1.0), rr.uniform(-1.0, 1.0)
        vis.append(ball(m["leaf"], (x, y, 0.3), 0.13, (1, 1, 0.8), seg=6, rings=4))
        for j in range(3):
            vis.append(ball(cols[(k // 4) % 4], (x + rr.uniform(-0.08, 0.08), y + rr.uniform(-0.08, 0.08), 0.42), 0.045, seg=5, rings=3))
    save("FlowerBed", vis, [], "flower_bed")

def drum(fname, paint):
    """A 200 l oil drum: two rolled ribs, the lid with its bung, a few dents and rust."""
    reset(); m = M(); vis = []; col = []
    pm = m[paint]
    vis.append(disc(pm, (0, 0, 0.45), 0.29, 0.88, verts=14))
    for z in (0.3, 0.6):
        vis.append(disc(pm, (0, 0, z), 0.3, 0.03, verts=14))
    for z in (0.015, 0.885):
        vis.append(disc(m["dmetal"], (0, 0, z), 0.295, 0.03, verts=14))
    vis.append(disc(m["dmetal"], (0.15, 0.05, 0.905), 0.03, 0.02, verts=8))
    vis.append(ball(m["rust"], (0.25, -0.12, 0.12), 0.08, (1, 0.6, 1.4), seg=6, rings=4))
    col.append(colbox("Drum", (0, 0, 0.45), (0.58, 0.58, 0.9)))
    save("Drum", vis, col, fname)

def pallet():
    """A wooden pallet: three runners, top boards, a few on the bottom."""
    reset(); m = M(); vis = []
    for y in (-0.42, 0, 0.42):
        vis.append(bx(m["wood"], (0, y, 0.07), (1.15, 0.1, 0.1), 0.005))
    for k in range(5):
        vis.append(bx(m["wood"], (-0.5 + k * 0.25, 0, 0.135), (0.14, 1.0, 0.025), 0.004))
    for x in (-0.5, 0, 0.5):
        vis.append(bx(m["dwood"], (x, 0, 0.012), (0.14, 1.0, 0.022), 0.004))
    save("Pallet", vis, [], "pallet")

def railing():
    """A 2 m cast-iron railing panel: two rails, bars with spear points, a post at each end."""
    reset(); m = M(); vis = []; col = []
    for sx in (-1.0, 1.0):
        vis.append(bx(m["iron"], (sx, 0, 0.6), (0.08, 0.08, 1.2), 0.01))
        vis.append(ball(m["iron"], (sx, 0, 1.24), 0.06, seg=8, rings=5))
    for z in (0.15, 1.0):
        vis.append(bx(m["iron"], (0, 0, z), (2.0, 0.04, 0.04), 0.0))
    for k in range(13):
        x = -0.9 + k * 0.15
        vis.append(bx(m["iron"], (x, 0, 0.58), (0.022, 0.022, 1.0), 0.0))
        vis.append(cyl(m["iron"], (x, 0, 1.12), 0.03, 0.08, 4, r2=0.0))
    col.append(colbox("Railing", (0, 0, 0.6), (2.0, 0.08, 1.2)))
    save("Railing", vis, col, "railing")

def wire_fence():
    """A 2 m panel of a yard fence: galvanised posts, a frame, the diamond wire, barbed wire on top."""
    reset(); m = M(); vis = []; col = []
    for sx in (-1.0, 1.0):
        vis.append(tb(m["galv"], (sx, 0, 0), (sx, 0, 2.1), 0.035, 8))
    for z in (0.08, 1.95):
        vis.append(tb(m["galv"], (-1.0, 0, z), (1.0, 0, z), 0.02, 6))
    for k in range(14):
        x0 = -1.0 + k * 0.143
        vis.append(beam(m["galv"], (x0, 0, 0.08), (min(1.0, x0 + 0.5), 0, 1.95), 0.006, 0.006))
        vis.append(beam(m["galv"], (x0 + 0.143, 0, 0.08), (max(-1.0, x0 + 0.143 - 0.5), 0, 1.95), 0.006, 0.006))
    for z in (2.05, 2.15):
        vis.append(beam(m["dmetal"], (-1.0, 0.03, z), (1.0, 0.03, z), 0.008, 0.008))
    col.append(colbox("Fence", (0, 0, 1.0), (2.0, 0.06, 2.0)))
    save("WireFence", vis, col, "wire_fence")

def workbench():
    """A steel workbench: a thick wooden top, a vice, a tool board with spanners, a drawer block."""
    reset(); m = M(); vis = []; col = []
    vis.append(bx(m["wood"], (0, 0, 0.88), (1.8, 0.75, 0.06), 0.01))
    for sx in (-0.85, 0.85):
        for sy in (-0.33, 0.33):
            vis.append(bx(m["metal"], (sx, sy, 0.43), (0.05, 0.05, 0.86), 0.0))
    vis.append(bx(m["metal"], (0, 0, 0.18), (1.7, 0.65, 0.03), 0.0))
    vis.append(bx(m["red"], (0.55, 0, 0.6), (0.5, 0.6, 0.45), 0.01))
    for k in range(3):
        vis.append(bx(m["dmetal"], (0.55, 0.31, 0.45 + k * 0.14), (0.3, 0.01, 0.02), 0.0))
    vis.append(bx(m["dmetal"], (-0.7, 0.3, 0.97), (0.2, 0.14, 0.12), 0.01))     # the vice
    vis.append(bx(m["dwood"], (0, -0.36, 1.35), (1.7, 0.03, 0.85), 0.0))          # tool board
    rr = random.Random(3)
    for k in range(7):
        vis.append(bx(m["metal"], (-0.7 + k * 0.23, -0.34, 1.35 + rr.uniform(-0.2, 0.2)), (0.04, 0.015, rr.uniform(0.18, 0.32)), 0.0))
    col.append(colbox("Bench", (0, 0, 0.46), (1.8, 0.75, 0.92)))
    save("Workbench", vis, col, "workbench")

def litter_bin():
    reset(); m = M(); vis = []; col = []
    vis.append(tb(m["iron"], (0, 0, 0), (0, 0, 0.9), 0.04, 6))
    vis.append(disc(m["green"], (0, -0.12, 0.62), 0.2, 0.5, verts=12))
    vis.append(disc(m["dmetal"], (0, -0.12, 0.88), 0.21, 0.03, verts=12))
    save("LitterBin", vis, [], "litter_bin")

ALL = dict(sandbags=sandbags, bench=bench, flower_bed=flower_bed, drum_red=lambda: drum("drum_red", "red"),
           drum_blue=lambda: drum("drum_blue", "blue"), pallet=pallet, railing=railing, wire_fence=wire_fence,
           workbench=workbench, litter_bin=litter_bin)
for k, f in ALL.items():
    if not ONLY or k in ONLY:
        f()
        print("built", k)

if "--gallery" in sys.argv:
    out = sys.argv[sys.argv.index("--gallery") + 1]
    names = [k for k in ALL if not ONLY or k in ONLY]
    gallery(out, [os.path.join(OUTDIR, "v_%s.glb" % n) for n in names], cols=5, spacing=3.2, target_z=0.6,
            dist=16, height=7, angle=0.0, res=(1600, 900))
