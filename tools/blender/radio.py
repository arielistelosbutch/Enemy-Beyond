"""Handheld radio (walkie-talkie) and the NVG-01 binocular night-vision goggle (own designs).
radio: same axes as the arsenal (+Y forward = the antenna up the hand), origin at the grip, the front
(speaker, display) towards +Z; body 0.06 x 0.15 x 0.035, antenna to y 0.32.
nvg: 0.57 - two tube modules on a bridge (0.11 wide), objectives in front (+Y = Godot -Z), the IR
illuminator between them, eyepieces behind, battery and the helmet mount on top.
Run: python3 tools/blender/radio.py <outdir> [--gallery out.png]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from kit import *

ARGS = [a for a in sys.argv[1:] if not a.startswith("--") and not a.endswith(".png")]
OUTDIR = ARGS[0] if ARGS else "."

def radio():
    reset()
    body = mat2("RadioBody", (0.09, 0.1, 0.085), 0.7)
    rubber = mat2("RadioRubber", (0.035, 0.035, 0.035), 0.9)
    grille = mat2("RadioGrille", (0.02, 0.02, 0.02), 0.8)
    steel = mat2("RadioSteel", (0.32, 0.33, 0.34), 0.35, 0.8)
    led = mat2("RadioLed", (1.0, 0.5, 0.1), emit=4.0)
    screen = mat2("RadioScreen", (0.55, 0.75, 0.3), emit=1.2)
    olive = mat2("RadioOlive", (0.2, 0.23, 0.15), 0.8)
    p = []
    p.append(bx(body, (0, 0.035, 0.0), (0.06, 0.14, 0.035), 0.006, seg=2))
    p.append(bx(rubber, (0, 0.035, 0.0), (0.063, 0.12, 0.028), 0.004))                      # rubber side grips
    p.append(bx(olive, (0, 0.035, -0.019), (0.05, 0.11, 0.006), 0.003))                     # battery pack at the back
    p.append(bx(body, (0, 0.11, 0.0), (0.056, 0.02, 0.033), 0.005))                         # top plate
    # speaker grille: a recessed panel with slots
    p.append(bx(grille, (0, 0.005, 0.0175), (0.046, 0.06, 0.003), 0.001))
    for k in range(7):
        p.append(box(body, (0, -0.02 + k * 0.0085, 0.0192), (0.04, 0.003, 0.0015)))
    p.append(bx(grille, (0, 0.072, 0.0175), (0.044, 0.03, 0.003), 0.001))
    p.append(box(screen, (0, 0.072, 0.0192), (0.038, 0.022, 0.001)))
    for k in range(3):                                                                    # keypad buttons
        p.append(bx(rubber, (-0.012 + k * 0.012, 0.048, 0.019), (0.009, 0.006, 0.003), 0.001))
    p.append(bx(rubber, (-0.032, 0.05, 0.0), (0.006, 0.03, 0.018), 0.002))                # push-to-talk
    p.append(bx(rubber, (-0.032, 0.022, 0.0), (0.005, 0.01, 0.012), 0.002))
    # knobs on top, the antenna (a rubber whip on a thicker base)
    p.append(disc(steel, (-0.016, 0.124, 0.0), 0.009, 0.014, 'y', verts=14))
    for k in range(10):
        a = TAU * k / 10
        p.append(box(rubber, (-0.016 + math.cos(a) * 0.009, 0.124, math.sin(a) * 0.009), (0.002, 0.012, 0.002)))
    p.append(disc(rubber, (0.004, 0.123, 0.0), 0.005, 0.008, 'y', verts=10))
    p.append(ball(led, (0.004, 0.128, 0.0), 0.003))
    p.append(tb(rubber, (0.018, 0.115, 0.0), (0.018, 0.15, 0.0), 0.007, 10))
    p.append(tb(rubber, (0.018, 0.15, 0.0), (0.018, 0.32, 0.0), 0.0045, 8, r2=0.003))
    p.append(ball(rubber, (0.018, 0.32, 0.0), 0.004))
    p.append(bx(steel, (0, -0.012, -0.022), (0.02, 0.05, 0.003), 0.001))                  # belt clip
    o = join(p, "Radio")
    export_glb(os.path.join(OUTDIR, "radio.glb"), [o])

def nvg():
    reset()
    olive = mat2("NvgOlive", (0.2, 0.22, 0.17), 0.8)
    dark = mat2("NvgDark", (0.1, 0.11, 0.1), 0.7)
    rubber = mat2("NvgRubber", (0.03, 0.03, 0.03), 0.9)
    steel = mat2("NvgSteel", (0.3, 0.31, 0.32), 0.35, 0.8)
    lens = mat2("NvgLensGlass", (0.12, 0.35, 0.3), 0.05, 0.4)
    green = mat2("NvgGlow", (0.3, 1.0, 0.4), emit=1.2)
    p = []
    irl = mat2("NvgIrLens", (0.25, 0.06, 0.06), 0.05, 0.4)
    # NVG-01: a binocular - two tube modules joined by a bevelled bridge
    p.append(bx(olive, (0, -0.005, 0.004), (0.046, 0.05, 0.036), 0.008, seg=2))
    for x in (0.033, -0.033):
        # the tube module: body, objective barrel, the ribbed focus ring, the lens
        p.append(disc(olive, (x, -0.005, 0.0), 0.021, 0.07, 'y', verts=20))
        p.append(disc(dark, (x, 0.04, 0.0), 0.02, 0.02, 'y', verts=20))
        p.append(disc(rubber, (x, 0.058, 0.0), 0.023, 0.018, 'y', verts=22))
        for k in range(12):
            a = TAU * k / 12
            p.append(box(rubber, (x + math.cos(a) * 0.023, 0.058, math.sin(a) * 0.023), (0.003, 0.016, 0.003)))
        p.append(disc(dark, (x, 0.071, 0.0), 0.021, 0.01, 'y', verts=20))
        p.append(disc(lens, (x, 0.077, 0.0), 0.017, 0.004, 'y', verts=20))
        # the eyepiece with a rubber eye cup (a faint green glow inside)
        p.append(disc(dark, (x, -0.045, 0.0), 0.016, 0.016, 'y', verts=16))
        p.append(disc(rubber, (x, -0.061, 0.0), 0.018, 0.016, 'y', verts=18, r2=0.02))
        p.append(disc(green, (x, -0.0695, 0.0), 0.01, 0.002, 'y', verts=14))
        p.append(disc(steel, (x, -0.037, 0.0), 0.017, 0.004, 'y', verts=16))
    # the infrared illuminator under the bridge, between the objectives
    p.append(disc(dark, (0, 0.028, -0.01), 0.008, 0.02, 'y', verts=12))
    p.append(disc(irl, (0, 0.039, -0.01), 0.0065, 0.003, 'y', verts=12))
    # the switch knob, battery tube, the mount block and shoe on top
    p.append(disc(rubber, (-0.012, 0.012, 0.026), 0.007, 0.01, verts=12))
    p.append(disc(dark, (0.0, -0.01, 0.024), 0.008, 0.04, 'x', verts=14))
    p.append(disc(steel, (0.021, -0.01, 0.024), 0.0075, 0.003, 'x', verts=14))
    p.append(bx(dark, (0, 0.006, 0.033), (0.034, 0.032, 0.016), 0.004))
    p.append(bx(steel, (0, 0.004, 0.044), (0.026, 0.026, 0.007), 0.002))
    o = join(p, "Nvg")
    export_glb(os.path.join(OUTDIR, "nvg.glb"), [o])

radio()
nvg()
print("built radio nvg")
if "--gallery" in sys.argv:
    gun_gallery(sys.argv[sys.argv.index("--gallery") + 1], [os.path.join(OUTDIR, "radio.glb"), os.path.join(OUTDIR, "nvg.glb")], cols=2, dx=0.45, dz=0.2)
