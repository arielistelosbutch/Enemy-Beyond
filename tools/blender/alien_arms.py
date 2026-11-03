"""Enemy Beyond - the aliens' own guns as a mercenary picks them up (own designs):
smooth bone-white and violet shells, no stock, a glowing coil where a magazine would be,
grips made for a narrower hand. Muzzle +Y, origin at the right-hand grip."""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from common import *
import arsenal_parts as ap

PI2 = math.pi / 2

def mats():
    return dict(
        shell=mat("XenoShell", (0.62, 0.6, 0.55), rough=0.3),
        dark=mat("XenoDark", (0.16, 0.12, 0.2), rough=0.4),
        glow=mat("XenoGlow", (0.7, 0.35, 1.0), emit=5.0),
        green=mat("XenoCore", (0.35, 1.0, 0.5), emit=4.0),
    )

def a_pistol():
    reset(); m = mats(); p = []
    p.append(cyl(m["shell"], (0, 0.08, 0.04), 0.03, 0.24, verts=10, rot=(PI2, 0, 0), r2=0.018))   # tapered body
    p.append(sphere(m["dark"], (0, -0.02, 0.045), 0.04, seg=10, rings=6, scale=(0.9, 1.2, 0.9)))   # rear bulb
    for i in range(3):
        p.append(cyl(m["glow"], (0, 0.03 + i * 0.05, 0.04), 0.034 - i * 0.004, 0.012, verts=10, rot=(PI2, 0, 0)))
    p.append(sphere(m["green"], (0, 0.21, 0.04), 0.012, seg=8, rings=5))                             # emitter
    p.append(box(m["dark"], (0, -0.005, -0.04), (0.026, 0.035, 0.08), rot=(-0.45, 0, 0)))          # thin grip
    p.append(box(m["shell"], (0, 0.03, 0.0), (0.012, 0.05, 0.02)))
    ap.save(p, "A_pistol")

def a_rifle():
    reset(); m = mats(); p = []
    p.append(box(m["shell"], (0, 0.12, 0.04), (0.06, 0.42, 0.07)))
    p.append(cyl(m["shell"], (0, 0.45, 0.045), 0.03, 0.3, verts=10, rot=(PI2, 0, 0), r2=0.016))
    p.append(cyl(m["dark"], (0, 0.12, 0.08), 0.022, 0.36, verts=8, rot=(PI2, 0, 0)))                # top spine
    for i in range(4):
        p.append(cyl(m["glow"], (0, 0.02 + i * 0.07, 0.04), 0.04, 0.014, verts=10, rot=(PI2, 0, 0)))   # coil rings
    p.append(sphere(m["green"], (0, 0.61, 0.045), 0.016, seg=8, rings=5))
    p.append(box(m["dark"], (0, 0.0, -0.045), (0.03, 0.04, 0.1), rot=(-0.35, 0, 0)))
    p.append(box(m["dark"], (0, 0.3, -0.02), (0.035, 0.08, 0.05)))                                 # fore grip
    p.append(sphere(m["shell"], (0, -0.12, 0.04), 0.045, seg=10, rings=6, scale=(0.8, 1.4, 0.9)))   # rear pod
    ap.save(p, "A_rifle")

def a_heavy():
    reset(); m = mats(); p = []
    p.append(cyl(m["shell"], (0, 0.18, 0.05), 0.065, 0.6, verts=12, rot=(PI2, 0, 0), r2=0.05))
    p.append(cyl(m["dark"], (0, 0.52, 0.05), 0.05, 0.12, verts=12, rot=(PI2, 0, 0), r2=0.035))
    for i in range(5):
        p.append(cyl(m["glow"], (0, -0.04 + i * 0.1, 0.05), 0.07, 0.016, verts=12, rot=(PI2, 0, 0)))
    p.append(sphere(m["green"], (0, -0.18, 0.05), 0.06, seg=10, rings=6))                          # the core at the back
    p.append(box(m["dark"], (0, 0.0, -0.05), (0.035, 0.045, 0.1), rot=(-0.35, 0, 0)))
    p.append(box(m["dark"], (0, 0.32, -0.03), (0.04, 0.08, 0.06)))
    ap.save(p, "A_heavy")

if __name__ == "__main__":
    a_pistol(); a_rifle(); a_heavy()
