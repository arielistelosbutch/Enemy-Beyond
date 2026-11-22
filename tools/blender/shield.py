"""Enemy Beyond - the Balistic shield (own design): three slightly angled alloy panels,
a dark view slit, a rim, a strap and a grip at the back. Origin at the left-hand grip;
the face looks along +Y (the muzzle direction of the guns)."""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from common import *
import math
import arsenal_parts as ap

OUTDIR = sys.argv[-1]

def shield(alien=False):
    """(0.72) Bevelled panels with a raised edge, bolts, a ballistic glass band with a frame,
    the UAI stripe, a padded grip and an arm strap at the back. Same size and material names.
    (0.80) alien=True: BSH-02, the same shape cut by laser from the alien alloy - dark violet
    sheen, glowing laser-cut seams between the segments, our steel frame (-> stit_x.glb;
    the game borrows BSH-01's Dílna anchors for it)."""
    reset(); p = []
    import kit as K
    if alien:
        alloy = mat("ShieldAlienAlloy", (0.2, 0.17, 0.25), rough=0.3)   # BSH-02: their hull alloy, a violet sheen
    else:
        alloy = mat("ShieldAlloy", (0.15, 0.155, 0.16), rough=0.85)      # BSH-01: matt dark grey
    rim = mat("ShieldRim", (0.1, 0.1, 0.11), rough=0.5)
    slit = mat("ShieldSlit", (0.05, 0.08, 0.1), rough=0.05)
    paint = mat("ShieldPaint", (0.55, 0.57, 0.58), rough=0.7)            # the UAI marking
    glass = mat("ShieldGlass", (0.55, 0.7, 0.75), rough=0.05)               # see-through in the game
    for k, (x, a) in enumerate(((-0.19, 0.35), (0.0, 0.0), (0.19, -0.35))):
        y = 0.08 - abs(x) * 0.35
        p.append(K.bx(alloy, (x, y, -0.115), (0.2, 0.025, 0.62), 0.006, rot=(0, 0, a), seg=2))
        p.append(K.bx(alloy, (x, y, 0.5), (0.2, 0.025, 0.05), 0.006, rot=(0, 0, a), seg=2))
        p.append(box(glass, (x, y, 0.335), (0.2, 0.012, 0.28), rot=(0, 0, a)))
        p.append(K.bx(rim, (x, y - 0.005, 0.19), (0.21, 0.04, 0.025), 0.005, rot=(0, 0, a)))
        p.append(K.bx(rim, (x, y - 0.005, 0.48), (0.21, 0.04, 0.025), 0.005, rot=(0, 0, a)))
        for z in (-0.38, 0.12):                                                  # bolts on the face
            for dx in (-0.075, 0.075):
                c = (x + dx * math.cos(a), y + 0.014 + dx * math.sin(a), z)
                p.append(K.disc(rim, c, 0.008, 0.005, 'y', verts=8))
    for x in (-0.095, 0.095):
        p.append(K.bx(rim, (x, 0.075, 0.335), (0.02, 0.04, 0.3), 0.005))
    p.append(K.bx(rim, (0, 0.06, 0.53), (0.56, 0.04, 0.03), 0.008))                   # top rim
    p.append(K.bx(rim, (0, 0.06, -0.43), (0.56, 0.04, 0.03), 0.008))                  # bottom rim
    for x in (-0.275, 0.275):                                                          # side edges
        p.append(K.bx(rim, (x, 0.0, 0.05), (0.02, 0.04, 0.96), 0.006))
    p.append(K.bx(paint, (0, 0.095, -0.15), (0.3, 0.005, 0.05), 0.002))               # the UAI marking stripe
    p.append(K.bx(rim, (0, 0.0, 0.0), (0.03, 0.12, 0.12), 0.008, seg=2))              # grip
    p.append(K.tb(mat("ShieldPad", (0.05, 0.05, 0.05), rough=0.9), (0, -0.04, -0.07), (0, -0.04, 0.07), 0.016, 12))
    p.append(K.bx(rim, (0, 0.03, 0.25), (0.1, 0.05, 0.03), 0.006))                    # forearm strap
    p.append(K.bx(mat("ShieldStrap", (0.12, 0.13, 0.1), rough=0.9), (0, -0.0, 0.25), (0.13, 0.012, 0.04), 0.003))
    if alien:
        seam = mat("ShieldSeam", (0.55, 0.35, 0.95), emit=1.6, rough=0.4)      # the laser-cut joints
        for x, a in ((-0.095, 0.17), (0.095, -0.17)):
            y = 0.08 - abs(x) * 0.35 + 0.012
            p.append(box(seam, (x, y, -0.12), (0.006, 0.006, 0.6), rot=(0, 0, a)))
        for x in (-0.19, 0.0, 0.19):                                               # a cut line across each plate
            y = 0.08 - abs(x) * 0.35 + 0.014
            a = 0.35 if x < 0 else (-0.35 if x > 0 else 0.0)
            p.append(box(seam, (x, y, -0.25), (0.16, 0.004, 0.004), rot=(0, 0, a)))
    ap.save(p, "Stit_x" if alien else "Stit")

if __name__ == "__main__":
    shield("alien" in sys.argv)
