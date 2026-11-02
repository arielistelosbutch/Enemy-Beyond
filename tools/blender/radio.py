"""Handheld radio (walkie-talkie), own design. Same axes as the arsenal: +Y forward
(antenna up the hand), origin at the grip.   python radio.py OUTDIR"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from common import *
OUTDIR = sys.argv[-1]
reset()
body = mat("RadioBody", (0.09, 0.1, 0.085), rough=0.7)
grille = mat("RadioGrille", (0.03, 0.03, 0.03), rough=0.8)
knob = mat("Steel", (0.20, 0.21, 0.22), rough=0.45)
led = mat("RadioLed", (1.0, 0.5, 0.1), emit=4.0)
screen = mat("RadioScreen", (0.55, 0.75, 0.3), emit=1.2)
p = [box(body, (0, 0.04, 0.0), (0.06, 0.15, 0.035)),
     box(grille, (0, 0.0, 0.0185), (0.045, 0.05, 0.003)),
     box(screen, (0, 0.075, 0.0185), (0.04, 0.025, 0.002)),
     box(grille, (-0.031, 0.04, 0.0), (0.004, 0.03, 0.02)),
     cyl(grille, (0.018, 0.21, 0.0), 0.006, 0.22, verts=6, r2=0.004, rot=(math.pi / 2, 0, 0)),
     cyl(knob, (-0.015, 0.125, 0.0), 0.008, 0.02, verts=8, rot=(math.pi / 2, 0, 0)),
     sphere(led, (0.005, 0.12, 0.006), 0.004, seg=6, rings=4)]
o = join(p, "Radio")
export_glb(os.path.join(OUTDIR, "radio.glb"), [o])
