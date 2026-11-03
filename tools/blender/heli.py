"""Our own twin-rotor transport helicopter "Čáp" - the team's ride before the Kondor.
Same cabin footprint as the dropship (map_gen collision: walls x=±1.6, roof 2.8,
length 8, nose +Y = Godot -Z, rear ramp open at -Y). Two rotors are separate
objects (RotorF, RotorR) with the origin in the hub, so the game can spin them.
Run: python3 heli.py OUTDIR [--preview]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from common import *

OUTDIR = sys.argv[-1] if not sys.argv[-1].startswith("--") else sys.argv[-2]
PREV = "--preview" in sys.argv

def rotor(m, hub_m, name, loc, phase):
    parts = [cyl(hub_m, (0, 0, 0), 0.32, 0.35, verts=10)]
    for i in range(3):
        a = phase + i * math.tau / 3
        b = box(m, (math.cos(a) * 3.6, math.sin(a) * 3.6, 0.12), (7.0, 0.36, 0.05), rot=(0, 0.06, a))
        parts.append(b)
    o = join(parts, name)
    o.location = loc
    return o

def heli():
    reset()
    hull = mat("HeliHull", (0.30, 0.33, 0.20), rough=0.75)      # olive drab
    hull2 = mat("HeliDark", (0.16, 0.17, 0.12), rough=0.7)
    inner = mat("HeliInner", (0.25, 0.25, 0.21))
    floor = mat("HeliFloor", (0.14, 0.14, 0.15), rough=0.5)
    glass = mat("HeliGlass", (0.06, 0.09, 0.11), rough=0.1)
    lamp = mat("HeliLamp", (1.0, 0.8, 0.5), emit=3.0)
    red = mat("HeliNavRed", (1.0, 0.1, 0.05), emit=6.0)
    grn = mat("HeliNavGreen", (0.1, 1.0, 0.2), emit=6.0)
    hazard = mat("HeliHazard", (0.85, 0.7, 0.1))
    blade = mat("HeliBlade", (0.08, 0.08, 0.08), rough=0.6)
    p = []
    L = 8.0
    for x in (1, -1):
        # rounded hull: wall, a bulged lower sponson and a curved upper edge
        p.append(box(hull, (1.72 * x, 0, 1.45), (0.25, L, 2.9)))
        p.append(box(hull, (1.95 * x, 0.2, 0.55), (0.4, 6.4, 0.8)))            # fuel sponson
        p.append(box(hull2, (2.16 * x, 0.2, 0.55), (0.02, 6.0, 0.06)))
        for i in range(4):   # round portholes (octagons)
            p.append(cyl(glass, (1.86 * x, -2.4 + i * 1.5, 1.9), 0.3, 0.04, verts=8, rot=(0, math.pi / 2, 0)))
            p.append(cyl(hull2, (1.85 * x, -2.4 + i * 1.5, 1.9), 0.38, 0.03, verts=8, rot=(0, math.pi / 2, 0)))
        p.append(box(hazard, (1.86 * x, 1.6, 2.55), (0.02, 1.2, 0.14)))
        # benches
        p.append(box(inner, (1.35 * x, -0.4, 0.45), (0.4, 5.5, 0.08)))
        p.append(box(inner, (1.52 * x, -0.4, 0.95), (0.06, 5.5, 0.9)))
        # wheels: two front, two rear on the sponsons
        for y in (2.6, -2.4):
            p.append(cyl(hull2, (1.9 * x, y, -0.05), 0.32, 0.25, verts=10, rot=(0, math.pi / 2, 0)))
        p.append(box(x == 1 and grn or red, (2.2 * x, 3.3, 1.2), (0.05, 0.12, 0.08)))
    p.append(box(hull, (0, 0, 3.05), (2.6, L, 0.3)))                    # roof
    p.append(box(floor, (0, 0, 0.1), (3.2, L, 0.2)))
    for i in range(8):
        p.append(box(hull2, (0, -3.5 + i, 0.205), (3.0, 0.04, 0.01)))
    for i in range(3):
        p.append(box(lamp, (0, -2.0 + i * 2.0, 2.78), (0.5, 0.12, 0.04)))
    # carry handle-like engine fairing along the top, with two engine pods
    p.append(box(hull2, (0, 0, 3.35), (1.2, 5.0, 0.3)))
    for x in (1, -1):
        p.append(cyl(hull, (1.0 * x, -2.6, 3.5), 0.42, 2.2, verts=10, rot=(math.pi / 2, 0, 0)))
        p.append(cyl(hull2, (1.0 * x, -3.75, 3.5), 0.32, 0.1, verts=10, rot=(math.pi / 2, 0, 0)))
    # front rotor pylon on the nose, the tall rear pylon over the ramp
    p.append(box(hull, (0, 4.6, 3.4), (1.2, 1.4, 0.8)))
    p.append(cyl(hull2, (0, 4.6, 3.9), 0.25, 0.4, verts=8))
    p.append(box(hull, (0, -3.2, 3.9), (1.5, 2.2, 1.9)))
    p.append(box(hull, (0, -3.0, 4.95), (1.1, 1.4, 0.3)))
    p.append(cyl(hull2, (0, -3.2, 5.2), 0.25, 0.4, verts=8))
    for i in range(5):          # louvres on the rear pylon
        p.append(box(hull2, (0.76, -3.9 + i * 0.32, 4.0), (0.02, 0.18, 0.9)))
        p.append(box(hull2, (-0.76, -3.9 + i * 0.32, 4.0), (0.02, 0.18, 0.9)))
    p.append(box(red, (0, -4.3, 4.85), (0.08, 0.08, 0.08)))
    # front bulkhead with a door to the cockpit
    p.append(box(inner, (1.0, 4.0, 1.4), (1.2, 0.3, 2.8)))
    p.append(box(inner, (-1.0, 4.0, 1.4), (1.2, 0.3, 2.8)))
    p.append(box(inner, (0, 4.0, 2.55), (0.8, 0.3, 0.5)))
    # rounded cockpit nose with a big glazed front
    p.append(box(hull, (0, 5.0, 1.45), (3.2, 2.0, 2.9)))
    p.append(box(hull, (0, 6.25, 1.0), (2.9, 0.9, 1.8)))
    p.append(box(hull, (0, 6.8, 0.75), (2.4, 0.5, 1.2)))
    p.append(box(glass, (0, 6.15, 2.1), (2.7, 1.0, 0.9), rot=(-0.75, 0, 0)))
    p.append(box(glass, (1.62, 5.4, 2.05), (0.03, 1.3, 0.8)))
    p.append(box(glass, (-1.62, 5.4, 2.05), (0.03, 1.3, 0.8)))
    p.append(box(hull2, (0, 6.55, 1.62), (2.7, 0.06, 0.08)))
    p.append(box(hazard, (0.9, 6.9, 0.6), (0.4, 0.05, 0.3)))
    # rear ramp, lowered
    r = box(floor, (0, -5.15, -0.08), (3.0, 2.4, 0.15), rot=(0.17, 0, 0))
    p.append(r)
    for i in range(5):
        p.append(box(hull2, (0, -4.3 - i * 0.42, 0.0 - i * 0.07), (2.8, 0.05, 0.03), rot=(0.17, 0, 0)))
    body = join(p, "Heli")
    rf = rotor(blade, hull2, "RotorF", (0, 4.6, 4.2), 0.0)
    rr = rotor(blade, hull2, "RotorR", (0, -3.2, 5.5), math.pi / 3)
    export_glb(os.path.join(OUTDIR, "heli.glb"), [body, rf, rr])
    if PREV:
        preview(os.path.join(OUTDIR, "heli_prev.png"), target=(0, 0, 2.0), dist=16.0, angle=2.3, height=4.0)

heli()
