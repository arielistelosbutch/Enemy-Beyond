"""Enemy Beyond arsenal, part 2 (own designs): sniper rifle with scope, and the
laser family (pistol, rifle, cannon) built at the base. Muzzle +Y, origin at the
right-hand grip. Also first-person hands for the two-handed ones."""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from common import *
from mathutils import Vector
import arsenal_parts as ap

OUTDIR = sys.argv[-1]
PI2 = math.pi / 2

def sniper():
    reset(); m = ap.M(); p = []
    p.append(box(m["dark"], (0, 0.06, 0.03), (0.045, 0.26, 0.06)))                 # receiver
    p.append(ap.tube(m["steel"], (0, 0.18, 0.045), (0, 1.02, 0.045), 0.014, r2=0.011))  # long barrel
    p.append(ap.tube(m["dark"], (0, 0.98, 0.045), (0, 1.07, 0.045), 0.02))         # muzzle brake
    for i in range(3):
        p.append(box(m["dark"], (0, 1.0 + i * 0.025, 0.045), (0.045, 0.006, 0.01)))
    # scope: tube with two bells and turrets
    p.append(ap.tube(m["dark"], (0, -0.02, 0.115), (0, 0.24, 0.115), 0.019))
    p.append(ap.tube(m["dark"], (0, 0.24, 0.115), (0, 0.32, 0.115), 0.019, r2=0.028))
    p.append(ap.tube(m["dark"], (0, -0.08, 0.115), (0, -0.02, 0.115), 0.025, r2=0.019))
    p.append(cyl(mat("Lens", (0.15, 0.3, 0.45), rough=0.05), (0, 0.322, 0.115), 0.025, 0.004, verts=10, rot=(PI2, 0, 0)))
    p.append(cyl(m["dark"], (0, 0.1, 0.142), 0.011, 0.02, verts=8))
    p.append(cyl(m["dark"], (0.026, 0.1, 0.115), 0.011, 0.02, verts=8, rot=(0, PI2, 0)))
    p.append(box(m["dark"], (0, 0.02, 0.075), (0.02, 0.02, 0.03)))                 # rings
    p.append(box(m["dark"], (0, 0.19, 0.075), (0.02, 0.02, 0.03)))
    p.append(box(m["steel"], (0.032, 0.0, 0.05), (0.03, 0.012, 0.012)))           # bolt handle
    p.append(sphere(m["steel"], (0.05, 0.0, 0.045), 0.012, seg=6, rings=4))
    p.append(box(m["olive"], (0, 0.32, 0.02), (0.05, 0.4, 0.05)))                  # handguard
    p.append(box(m["dark"], (0, 0.04, -0.035), (0.03, 0.05, 0.04)))                # magazine
    p.append(box(m["olive"], (0, -0.015, -0.05), (0.035, 0.045, 0.1), rot=(-0.3, 0, 0)))  # grip
    p.append(box(m["olive"], (0, -0.22, 0.015), (0.045, 0.28, 0.075)))             # stock
    p.append(box(m["olive"], (0, -0.18, 0.06), (0.03, 0.12, 0.025)))               # cheek rest
    p.append(box(m["dark"], (0, -0.37, 0.0), (0.047, 0.02, 0.12)))                 # butt pad
    for s in (-1, 1):                                                              # folded bipod
        p.append(ap.tube(m["dark"], (0.015 * s, 0.5, 0.0), (0.02 * s, 0.75, -0.005), 0.006))
    ap.save(p, "Sniper")

def laser_mats():
    return dict(
        body=mat("LaserBody", (0.62, 0.64, 0.66), rough=0.35),
        trim=mat("LaserTrim", (0.08, 0.09, 0.1), rough=0.5),
        lens=mat("LaserLens", (1.0, 0.18, 0.12), emit=5.0),
        coil=mat("LaserCoil", (0.75, 0.42, 0.15), rough=0.3),
    )

def laser_pistol():
    reset(); L = laser_mats(); p = []
    p.append(box(L["body"], (0, 0.08, 0.03), (0.04, 0.2, 0.05)))
    p.append(box(L["trim"], (0, 0.08, 0.06), (0.03, 0.18, 0.012)))
    for i in range(4):
        p.append(box(L["coil"], (0, 0.03 + i * 0.03, 0.03), (0.046, 0.008, 0.04)))
    p.append(cyl(L["trim"], (0, 0.19, 0.03), 0.018, 0.03, verts=8, rot=(PI2, 0, 0)))
    p.append(cyl(L["lens"], (0, 0.206, 0.03), 0.012, 0.004, verts=8, rot=(PI2, 0, 0)))
    p.append(box(L["trim"], (0, -0.005, -0.035), (0.032, 0.04, 0.085), rot=(-0.25, 0, 0)))
    p.append(box(L["lens"], (0, 0.0, -0.035), (0.034, 0.012, 0.02)))              # charge window
    ap.save(p, "Laser_pistol")

def laser_rifle():
    reset(); L = laser_mats(); p = []
    p.append(box(L["body"], (0, 0.12, 0.03), (0.05, 0.42, 0.07)))
    p.append(box(L["trim"], (0, 0.12, 0.072), (0.035, 0.36, 0.014)))
    for i in range(7):
        p.append(box(L["coil"], (0, 0.0 + i * 0.045, 0.03), (0.058, 0.012, 0.06)))  # cooling fins
    p.append(ap.tube(L["trim"], (0, 0.33, 0.04), (0, 0.6, 0.04), 0.022, r2=0.017))
    p.append(cyl(L["lens"], (0, 0.602, 0.04), 0.013, 0.005, verts=8, rot=(PI2, 0, 0)))
    p.append(box(L["trim"], (0, 0.1, 0.1), (0.02, 0.12, 0.03)))                    # sight block
    p.append(box(L["lens"], (0, 0.045, 0.116), (0.006, 0.006, 0.004)))
    p.append(box(L["trim"], (0, -0.005, -0.045), (0.035, 0.045, 0.1), rot=(-0.3, 0, 0)))
    p.append(box(L["body"], (0, 0.12, -0.035), (0.04, 0.07, 0.05)))                 # power pack
    p.append(box(L["lens"], (0.021, 0.12, -0.035), (0.002, 0.05, 0.02)))
    p.append(box(L["trim"], (0, -0.2, 0.02), (0.04, 0.22, 0.06)))
    p.append(box(L["body"], (0, -0.31, 0.0), (0.045, 0.02, 0.11)))
    ap.save(p, "Laser_rifle")

def laser_cannon():
    reset(); L = laser_mats(); p = []
    p.append(box(L["body"], (0, 0.15, 0.04), (0.09, 0.55, 0.1)))
    for i in range(9):
        p.append(box(L["coil"], (0, -0.05 + i * 0.05, 0.04), (0.105, 0.014, 0.115)))
    p.append(ap.tube(L["trim"], (0, 0.42, 0.05), (0, 0.78, 0.05), 0.04, r2=0.03))
    p.append(ap.tube(L["trim"], (0, 0.42, 0.0), (0, 0.66, 0.0), 0.018))
    p.append(cyl(L["lens"], (0, 0.782, 0.05), 0.024, 0.006, verts=10, rot=(PI2, 0, 0)))
    p.append(box(L["trim"], (0, 0.0, -0.07), (0.04, 0.05, 0.11), rot=(-0.25, 0, 0)))
    p.append(box(L["trim"], (0, 0.42, -0.05), (0.03, 0.04, 0.08)))                  # front grip
    p.append(box(L["body"], (0, -0.2, 0.04), (0.08, 0.2, 0.12)))                    # power core
    p.append(box(L["lens"], (0.041, -0.2, 0.04), (0.002, 0.14, 0.05)))
    p.append(box(L["trim"], (0, 0.1, 0.12), (0.025, 0.2, 0.03)))                    # carry handle
    ap.save(p, "Laser_cannon")

for f in (sniper, laser_pistol, laser_rifle, laser_cannon):
    f()
ap.GRIPS.update({
    "sniper": ((0, -0.015, -0.05), (0, 0.4, -0.0)),
    "laser_rifle": ((0, -0.01, -0.045), (0, 0.3, -0.04)),
    "laser_cannon": ((0, 0.0, -0.07), (0, 0.42, -0.07)),
})
ap.GRIPS["laser_pistol"] = ((0, -0.005, -0.04), (-0.035, 0.0, -0.06))
for k in ("sniper", "laser_rifle", "laser_cannon", "magnum", "laser_pistol"):
    ap.OUTDIR = OUTDIR
    ap.hands(k)
