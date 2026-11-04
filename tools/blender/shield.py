"""Enemy Beyond - the Balistic shield (own design): three slightly angled alloy panels,
a dark view slit, a rim, a strap and a grip at the back. Origin at the left-hand grip;
the face looks along +Y (the muzzle direction of the guns)."""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from common import *
import arsenal_parts as ap

OUTDIR = sys.argv[-1]

def shield():
    reset(); p = []
    alloy = mat("ShieldAlloy", (0.26, 0.27, 0.3), rough=0.35)
    rim = mat("ShieldRim", (0.1, 0.1, 0.11), rough=0.5)
    slit = mat("ShieldSlit", (0.05, 0.08, 0.1), rough=0.05)
    paint = mat("ShieldPaint", (0.75, 0.62, 0.12))
    glass = mat("ShieldGlass", (0.55, 0.7, 0.75), rough=0.05)               # see-through in the game
    # three angled panels; across all of them, at eye height, a band of ballistic glass
    # (0.50: you can see through the shield)
    for k, (x, a) in enumerate(((-0.19, 0.35), (0.0, 0.0), (0.19, -0.35))):
        y = 0.08 - abs(x) * 0.35
        p.append(box(alloy, (x, y, -0.115), (0.2, 0.025, 0.62), rot=(0, 0, a)))     # below the window
        p.append(box(alloy, (x, y, 0.5), (0.2, 0.025, 0.05), rot=(0, 0, a)))       # above it
        p.append(box(glass, (x, y, 0.335), (0.2, 0.012, 0.28), rot=(0, 0, a)))     # the window
        p.append(box(rim, (x, y - 0.005, 0.19), (0.21, 0.04, 0.025), rot=(0, 0, a)))
        p.append(box(rim, (x, y - 0.005, 0.48), (0.21, 0.04, 0.025), rot=(0, 0, a)))
    for x in (-0.095, 0.095):
        p.append(box(rim, (x, 0.075, 0.335), (0.02, 0.04, 0.3)))
    p.append(box(rim, (0, 0.06, 0.53), (0.56, 0.04, 0.03)))                   # top rim
    p.append(box(rim, (0, 0.06, -0.43), (0.56, 0.04, 0.03)))                  # bottom rim
    p.append(box(paint, (0, 0.095, -0.15), (0.3, 0.005, 0.05)))               # yellow stripe
    p.append(box(rim, (0, 0.0, 0.0), (0.03, 0.12, 0.12)))                     # grip
    p.append(box(rim, (0, 0.03, 0.25), (0.1, 0.05, 0.03)))                    # forearm strap
    ap.save(p, "Stit")

if __name__ == "__main__":
    shield()
