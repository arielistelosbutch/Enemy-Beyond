"""Props: dairy cow and the mercenaries' dropship ("Kondor"). Own designs."""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from common import *

OUTDIR = sys.argv[-1]
PREV = "--preview" in sys.argv

def cow():
    reset()
    hide = mat("CowHide", (0.78, 0.75, 0.70))
    spot = mat("CowSpot", (0.07, 0.06, 0.055))
    nose = mat("CowNose", (0.55, 0.38, 0.36))
    horn = mat("CowHorn", (0.75, 0.70, 0.55))
    hoof = mat("CowHoof", (0.1, 0.09, 0.08))
    p = []
    b = sphere(hide, (0, 0, 0.98), 0.4, seg=10, rings=6, scale=(0.78, 1.9, 0.95))
    p.append(b)
    p.append(sphere(spot, (0.12, 0.2, 1.1), 0.24, seg=8, rings=5, scale=(1.25, 1.2, 0.9)))
    p.append(sphere(spot, (-0.15, -0.35, 1.0), 0.22, seg=8, rings=5, scale=(1.3, 1.3, 1.1)))
    p.append(cyl(hide, (0, 0.78, 1.12), 0.14, 0.28, verts=8, rot=(1.1, 0, 0), r2=0.11))        # neck
    p.append(box(hide, (0, 0.98, 1.18), (0.24, 0.34, 0.26), rot=(0.35, 0, 0)))               # head
    p.append(box(spot, (0, 0.95, 1.29), (0.25, 0.2, 0.08), rot=(0.35, 0, 0)))
    p.append(box(nose, (0, 1.15, 1.1), (0.2, 0.08, 0.14), rot=(0.35, 0, 0)))
    for x in (1, -1):
        p.append(box(hide, (0.16 * x, 0.92, 1.3), (0.12, 0.05, 0.06), rot=(0, 0, 0.3 * x)))  # ears
        p.append(cyl(horn, (0.09 * x, 0.92, 1.35), 0.02, 0.1, verts=5, r2=0.005, rot=(0, 0.6 * x, 0)))
        for y in (0.45, -0.5):
            p.append(cyl(hide, (0.17 * x, y, 0.42), 0.07, 0.62, verts=6, r2=0.055))
            p.append(cyl(hoof, (0.17 * x, y, 0.06), 0.06, 0.1, verts=6))
    p.append(sphere(nose, (0, -0.25, 0.62), 0.12, seg=6, rings=4, scale=(1, 1.2, 0.7)))      # udder
    p.append(cyl(hide, (0, -0.78, 0.8), 0.02, 0.6, verts=4, rot=(0.25, 0, 0)))               # tail
    p.append(sphere(spot, (0, -0.86, 0.5), 0.04, seg=5, rings=3, scale=(1, 1, 2)))
    o = join(p, "Cow")
    export_glb(os.path.join(OUTDIR, "cow.glb"), [o])
    if PREV:
        preview(os.path.join(OUTDIR, "cow_prev.png"), target=(0, 0, 0.7), dist=3.2, angle=0.9, height=0.4)

def dropship():
    """Interior matches the collision boxes in map_gen: walls at x=±1.6, roof 2.8,
    length 8 (nose +Y = Godot -Z), rear ramp open at -Y."""
    reset()
    hull = mat("ShipHull", (0.32, 0.34, 0.30), rough=0.7)
    hull2 = mat("ShipHullDark", (0.17, 0.18, 0.17), rough=0.7)
    inner = mat("ShipInner", (0.24, 0.23, 0.20))
    floor = mat("ShipFloor", (0.14, 0.14, 0.15), rough=0.5)
    glass = mat("ShipGlass", (0.05, 0.08, 0.1), rough=0.1)
    lamp = mat("ShipLamp", (1.0, 0.75, 0.45), emit=3.0)
    red = mat("NavRed", (1.0, 0.1, 0.05), emit=6.0)
    grn = mat("NavGreen", (0.1, 1.0, 0.2), emit=6.0)
    eng = mat("EngineGlow", (1.0, 0.45, 0.15), emit=2.5)
    stripe = mat("Stripe", (0.6, 0.45, 0.1))
    p = []
    L = 8.0
    # side walls (outer shell slightly bigger than the collision walls)
    for x in (1, -1):
        p.append(box(hull, (1.72 * x, 0, 1.45), (0.25, L, 2.9)))
        p.append(box(stripe, (1.86 * x, 0.5, 1.9), (0.02, 5.0, 0.18)))
        for i in range(3):   # small windows
            p.append(box(glass, (1.86 * x, -1.5 + i * 1.5, 2.15), (0.02, 0.5, 0.3)))
        # interior bench and lamps
        p.append(box(inner, (1.35 * x, -0.4, 0.45), (0.4, 5.5, 0.08)))
        p.append(box(inner, (1.52 * x, -0.4, 0.95), (0.06, 5.5, 0.9)))
        for i in range(4):
            p.append(box(hull2, (1.35 * x, -2.7 + i * 1.6, 0.22), (0.05, 0.05, 0.42)))
    p.append(box(hull, (0, 0, 3.0), (3.7, L, 0.35)))                 # roof
    p.append(box(hull2, (0, 0.3, 3.25), (2.2, 5.5, 0.25)))            # spine
    p.append(box(floor, (0, 0, 0.1), (3.2, L, 0.2)))
    for i in range(8):
        p.append(box(hull2, (0, -3.5 + i, 0.205), (3.0, 0.04, 0.01)))
    for i in range(3):
        p.append(box(lamp, (0, -2.0 + i * 2.0, 2.78), (0.5, 0.12, 0.04)))
    # front bulkhead with a door to the cockpit
    p.append(box(inner, (1.0, 4.0, 1.4), (1.2, 0.3, 2.8)))
    p.append(box(inner, (-1.0, 4.0, 1.4), (1.2, 0.3, 2.8)))
    p.append(box(inner, (0, 4.0, 2.55), (0.8, 0.3, 0.5)))
    # cockpit nose: tapered block with a dark canopy
    p.append(box(hull, (0, 5.0, 1.5), (3.2, 2.0, 2.4)))
    p.append(box(hull, (0, 6.2, 1.2), (2.6, 1.0, 1.6)))
    p.append(box(glass, (0, 5.9, 2.25), (2.4, 1.4, 0.5), rot=(-0.55, 0, 0)))
    p.append(box(hull2, (0, 6.75, 0.8), (2.0, 0.3, 0.8)))
    p.append(box(red, (0, 6.92, 1.0), (0.1, 0.03, 0.1)))
    # stub wings with engine pods
    for x, nav in ((1, grn), (-1, red)):
        p.append(box(hull2, (3.6 * x, 1.0, 2.0), (3.8, 2.6, 0.22)))
        p.append(cyl(hull, (5.3 * x, 1.0, 2.0), 0.7, 3.2, verts=10, rot=(math.pi / 2, 0, 0)))
        p.append(cyl(hull2, (5.3 * x, -0.7, 2.0), 0.55, 0.3, verts=10, rot=(math.pi / 2, 0, 0)))
        p.append(cyl(eng, (5.3 * x, -0.86, 2.0), 0.45, 0.04, verts=10, rot=(math.pi / 2, 0, 0)))
        p.append(box(stripe, (5.3 * x, 1.8, 2.72), (0.5, 0.6, 0.02)))
        p.append(box(nav, (5.45 * x + 0.5 * x, 1.0, 2.0), (0.06, 0.15, 0.06)))
        # landing struts
        p.append(cyl(hull2, (1.4 * x, 2.5, -0.15), 0.07, 0.5, verts=6))
        p.append(box(hull2, (1.4 * x, 2.5, -0.38), (0.3, 0.5, 0.06)))
        p.append(cyl(hull2, (1.4 * x, -2.8, -0.15), 0.07, 0.5, verts=6))
        p.append(box(hull2, (1.4 * x, -2.8, -0.38), (0.3, 0.5, 0.06)))
    # tail fin over the ramp
    p.append(box(hull, (0, -3.0, 3.75), (0.22, 1.6, 1.3), rot=(-0.45, 0, 0)))
    p.append(box(red, (0, -3.6, 4.6), (0.08, 0.08, 0.08)))
    # rear ramp, lowered (pivot at the floor's back edge)
    r = box(floor, (0, -5.15, -0.08), (3.0, 2.4, 0.15), rot=(0.17, 0, 0))
    p.append(r)
    for i in range(5):
        p.append(box(hull2, (0, -4.3 - i * 0.42, 0.0 - i * 0.07), (2.8, 0.05, 0.03), rot=(0.17, 0, 0)))
    o = join(p, "Dropship")
    export_glb(os.path.join(OUTDIR, "dropship.glb"), [o])
    if PREV:
        preview(os.path.join(OUTDIR, "ship_prev.png"), target=(0, 0, 1.5), dist=13.0, angle=2.5, height=3.0)

cow()
dropship()
