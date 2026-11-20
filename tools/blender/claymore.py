"""Enemy Beyond (0.80): directional mine MC-18 (Claymore type), own design; replaces
the old pressure mine as assets/models/mine.glb (item id "mine" stays). Front of the mine = Blender +Y
(= Godot -Z after export), origin on the ground under its middle.
Run: python3 claymore.py <out dir>   (then zfight_glb.py --fix on the outputs)"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from common import *

OUTDIR = sys.argv[-1]

def M():
    return dict(
        olive=mat("OliveDrab", (0.20, 0.23, 0.14), rough=0.8),
        olive2=mat("OliveDark", (0.13, 0.15, 0.09), rough=0.85),
        dark=mat("Blackened", (0.06, 0.06, 0.065), rough=0.6),
        steel=mat("Steel", (0.20, 0.21, 0.22), rough=0.45),
        warn=mat("WarnYellow", (0.75, 0.6, 0.1)),
        green=mat("LedGreen", (0.15, 1.0, 0.3), emit=4.0),
    )

def claymore():
    reset(); m = M(); p = []
    # curved body: 5 segments on an arc, convex to the front (+Y), 22 x 4 x 8.5 cm
    n, w, R = 5, 0.22, 0.30
    for i in range(n):
        a = (i - (n - 1) / 2) * (w / n) / R
        x = math.sin(a) * R
        y = math.cos(a) * R - R
        p.append(box(m["olive"], (x, y, 0.085), (w / n + 0.004, 0.036, 0.085), rot=(0, 0, -a)))
    # yellow stripe and a raised front face plate
    for i in range(n):
        a = (i - (n - 1) / 2) * (w / n) / R
        x = math.sin(a) * (R + 0.019); y = math.cos(a) * (R + 0.019) - R
        p.append(box(m["olive2"], (x, y, 0.085), (w / n - 0.004, 0.004, 0.07), rot=(0, 0, -a)))
    p.append(box(m["warn"], (0, -0.019, 0.122), (0.05, 0.003, 0.01)))
    # sight on top, detonator wells
    p.append(box(m["dark"], (0, 0, 0.133), (0.012, 0.03, 0.008)))
    for sx in (-0.06, 0.06):
        p.append(cyl(m["dark"], (sx, -0.004, 0.135), 0.008, 0.012, verts=8))
    # four scissor legs
    for sx in (-0.085, 0.085):
        for sy in (-0.016, 0.016):
            p.append(box(m["steel"], (sx * 1.08, sy * 1.6, 0.025), (0.005, 0.005, 0.055),
                         rot=(0.3 if sy > 0 else -0.3, -0.2 if sx > 0 else 0.2, 0)))
    o = join(p, "Claymore")
    export_glb(os.path.join(OUTDIR, "mine.glb"), [o])

claymore()
