"""Enemy Beyond 0.57 - the hybrid craft of Project X, after Ari's pictures (own models):
  jestrab  - UAI XF-01 "Jestřáb", the hybrid interceptor: an oval fuselage, a bubble canopy, swept wings,
             twin canted fins, two laser cannons in pods under the belly, violet vents, blue light strips.
             The same size and axes as the Sokol (nose +Y = Godot -Z, origin in the middle, about 9 m long).
  pelikan  - UAI XT-87 "Pelikán", the interplanetary transport: a long armoured hull with the cockpit band
             in a rounded nose, cargo modules along the sides, four engines at the back, an AI turret on top.
             Its cabin is the Kondor's (map_gen._skyranger: walls x +-1.6, floor 0.2, roof 2.9, y -4..4,
             the rear ramp down at -Y), so it stands on the same landing site.
Run: python3 tools/blender/craft2.py <outdir> [--only jestrab,pelikan] [--gallery out.png]"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
from kit import *

ARGS = [a for a in sys.argv[1:] if not a.startswith("--") and not a.endswith(".png") and "," not in a]
OUTDIR = ARGS[0] if ARGS else "."
ONLY = sys.argv[sys.argv.index("--only") + 1].split(",") if "--only" in sys.argv else []

def M():
    return dict(
        hull=mat2("UAIHull", (0.3, 0.31, 0.33), 0.45, 0.55), hull2=mat2("UAIHullDark", (0.14, 0.145, 0.16), 0.5, 0.5),
        panel=mat2("UAIPanel", (0.22, 0.23, 0.25), 0.5, 0.45), steel=mat2("UAISteel", (0.42, 0.43, 0.45), 0.3, 0.85),
        black=mat2("UAIBlack", (0.03, 0.03, 0.035), 0.8), glass=mat2("UAIGlass", (0.1, 0.16, 0.22), 0.05, 0.4),
        violet=mat2("UAIViolet", (0.6, 0.25, 1.0), emit=5.0), blue=mat2("UAIBlue", (0.35, 0.6, 1.0), emit=4.0),
        exhaust=mat2("UAIExhaust", (0.55, 0.45, 1.0), emit=6.0), red=mat2("NavRed", (1.0, 0.1, 0.05), emit=6.0),
        grn=mat2("NavGreen", (0.1, 1.0, 0.2), emit=6.0), white=mat2("StrobeWhite", (1.0, 1.0, 0.95), emit=5.0),
        stencil=mat2("UAIStencil", (0.78, 0.78, 0.75), 0.7), stripe=mat2("UAIRedStripe", (0.55, 0.08, 0.06), 0.6),
        warn=mat2("UAIHazard", (0.8, 0.62, 0.1), 0.6), inner=mat2("KondorInner", (0.3, 0.31, 0.3), 0.8),
        floor=mat2("KondorFloor", (0.12, 0.12, 0.13), 0.45, 0.5), seat=mat2("KondorSeat", (0.22, 0.2, 0.15), 0.9),
        strap=mat2("KondorStrap", (0.45, 0.12, 0.06), 0.9), lamp=mat2("KondorLamp", (1.0, 0.75, 0.45), emit=3.0),
        screen=mat2("UAIHolo", (0.3, 0.75, 1.0), emit=2.0), rubber=mat2("KondorTyre", (0.03, 0.03, 0.03), 0.95),
    )

# ==================================================================================================
def jestrab():
    reset(); m = M(); p = []
    # the fuselage: an oval body, wider and flatter than the Sokol's, a long rounded nose
    p.append(loft(m["hull"], [(5.2, 0, 0.0, 0.05, 0.04), (4.7, 0, 0.0, 0.4, 0.25), (3.8, 0, 0.05, 0.75, 0.42), (2.4, 0, 0.08, 1.0, 0.55),
                              (0.6, 0, 0.08, 1.15, 0.6), (-1.4, 0, 0.06, 1.15, 0.55), (-3.0, 0, 0.04, 0.95, 0.45), (-3.7, 0, 0.04, 0.7, 0.36)], verts=24))
    p.append(loft(m["hull2"], [(4.75, 0, -0.12, 0.3, 0.12), (3.0, 0, -0.18, 0.85, 0.22), (0.0, 0, -0.22, 1.05, 0.28), (-3.4, 0, -0.16, 0.8, 0.2)], verts=18))
    # the bubble canopy, its frame, the pilot
    p.append(loft(m["glass"], [(3.7, 0, 0.42, 0.05, 0.05), (3.1, 0, 0.5, 0.42, 0.34), (2.1, 0, 0.58, 0.52, 0.44), (1.0, 0, 0.55, 0.48, 0.38), (0.3, 0, 0.5, 0.3, 0.22)], verts=20))
    p.append(torus(m["hull2"], (0, 1.4, 0.58), 0.5, 0.03, rot=(PI2, 0, 0), seg=20))
    p.append(ball(m["hull2"], (0, 1.95, 0.72), 0.15, (1, 1.2, 1)))
    p.append(bx(m["screen"], (0, 2.45, 0.66), (0.3, 0.02, 0.18), 0.0, rot=(-0.5, 0, 0)))
    # the dorsal spine with violet vents (the gravity drive) behind the canopy
    p.append(loft(m["hull2"], [(0.4, 0, 0.55, 0.3, 0.12), (-1.0, 0, 0.62, 0.5, 0.2), (-2.8, 0, 0.5, 0.4, 0.14)], verts=14))
    for k in range(4):
        for x in (1, -1):
            p.append(bx(m["violet"], (0.38 * x, -0.6 - k * 0.42, 0.7), (0.06, 0.25, 0.04), 0.0, rot=(0, 0, 0.3 * x)))
    # side intakes with violet slats, blue light strips along the flanks
    for x in (1, -1):
        p.append(loft(m["hull2"], [(1.6, 1.05 * x, -0.05, 0.22, 0.32), (0.2, 1.1 * x, -0.05, 0.26, 0.34), (-1.6, 0.95 * x, -0.05, 0.22, 0.28)], verts=12, cap=False))
        for k in range(5):
            p.append(bx(m["violet"], (1.25 * x, 0.6 - k * 0.32, -0.1), (0.04, 0.12, 0.38), 0.0, rot=(0.25, 0, 0)))
        p.append(bx(m["blue"], (0.92 * x, 3.0, 0.02), (0.03, 1.3, 0.04), 0.0, rot=(0, 0, 0)))
        p.append(bx(m["blue"], (1.18 * x, -1.9, 0.22), (0.03, 1.1, 0.04), 0.0))
        p.append(box(m["stencil"], (1.16 * x, -0.4, 0.3), (0.01, 0.9, 0.12)))
    # the wings: swept, with blue tip lights, a stripe, flaperons
    for x, nav in ((1, m["grn"]), (-1, m["red"])):
        p.append(plate(m["hull"], [(0.95 * x, 1.2), (4.5 * x, -2.0), (4.6 * x, -2.7), (1.0 * x, -2.9)], -0.06, 0.06, b=0.02))
        p.append(plate(m["panel"], [(1.4 * x, 0.6), (4.0 * x, -1.8), (4.0 * x, -2.0), (1.4 * x, 0.35)], 0.06, 0.07))
        p.append(plate(m["hull2"], [(1.2 * x, -2.6), (4.3 * x, -2.55), (4.3 * x, -2.75), (1.2 * x, -2.85)], 0.061, 0.07))
        p.append(bx(m["blue"], (4.55 * x, -2.3, 0.0), (0.06, 0.6, 0.05), 0.0))
        p.append(box(nav, (4.62 * x, -2.6, 0.06), (0.06, 0.18, 0.06)))
        # the canted twin fins
        fin = plate_v(m["hull"], [(-2.1, 0.4), (-3.5, 0.4), (-3.75, 1.75), (-3.15, 1.75)], -0.04, 0.04, b=0.01)
        for v in fin.data.vertices:
            v.co.x += 0.75 * x + (v.co.z - 0.4) * 0.35 * x
        p.append(fin)
        p.append(plate(m["hull"], [(0.5 * x, -2.8), (2.0 * x, -3.5), (2.0 * x, -3.9), (0.5 * x, -3.7)], -0.04, 0.04, b=0.01))
        # the laser cannon in its pod under the belly: a housing, cooling rings, a violet glowing muzzle
        cx = 0.62 * x
        p.append(loft(m["hull2"], [(1.6, cx, -0.48, 0.2, 0.2), (0.4, cx, -0.48, 0.24, 0.24), (-1.0, cx, -0.45, 0.2, 0.2)], verts=14))
        p.append(tb(m["black"], (cx, 1.5, -0.48), (cx, 3.6, -0.48), 0.09, 12))
        for k in range(4):
            p.append(torus(m["steel"], (cx, 1.9 + k * 0.38, -0.48), 0.12, 0.025, rot=(PI2, 0, 0), seg=14))
            p.append(torus(m["violet"], (cx, 2.08 + k * 0.38, -0.48), 0.105, 0.012, rot=(PI2, 0, 0), seg=14))
        p.append(disc(m["violet"], (cx, 3.62, -0.48), 0.07, 0.04, 'y', verts=12))
    # the engines: two nozzles with blue-violet glow
    for x in (0.45, -0.45):
        p.append(disc(m["hull2"], (x, -3.65, 0.05), 0.38, 0.3, 'y', verts=18, r2=0.32))
        p.append(disc(m["black"], (x, -3.82, 0.05), 0.3, 0.03, 'y', verts=16))
        p.append(torus(m["exhaust"], (x, -3.84, 0.05), 0.22, 0.05, rot=(PI2, 0, 0), seg=16))
        p.append(disc(m["exhaust"], (x, -3.86, 0.05), 0.14, 0.02, 'y', verts=12))
    p.append(ball(m["white"], (0, -1.6, 0.78), 0.04))
    p.append(box(m["stencil"], (0, 0.6, 0.62), (0.4, 0.3, 0.01)))
    o = join(p, "Jestrab")
    export_glb(os.path.join(OUTDIR, "jestrab.glb"), [o])

# ==================================================================================================
def pelikan():
    reset(); m = M(); p = []
    L = 8.0
    # ---- the cabin (the Kondor's footprint): floor, lining, seats, lamps - seen from inside ---------------------
    p.append(bx(m["floor"], (0, 0, 0.1), (3.2, L, 0.2), 0.02))
    for i in range(16):
        p.append(box(m["steel"], (0, -3.75 + i * 0.5, 0.205), (2.9, 0.06, 0.012)))
    for x in (1, -1):
        p.append(box(m["inner"], (1.585 * x, 0, 1.45), (0.01, L - 0.1, 2.5)))
        p.append(bx(m["seat"], (1.3 * x, -0.4, 0.5), (0.42, 5.6, 0.07), 0.02))
        for k in range(8):
            y = -3.0 + k * 0.7
            p.append(bx(m["seat"], (1.48 * x, y, 0.95), (0.05, 0.55, 0.65), 0.015))
            p.append(box(m["strap"], (1.45 * x, y - 0.15, 1.0), (0.012, 0.05, 0.8)))
            p.append(box(m["strap"], (1.45 * x, y + 0.15, 1.0), (0.012, 0.05, 0.8)))
            p.append(tb(m["steel"], (1.15 * x, y, 0.47), (1.15 * x, y, 0.2), 0.016, 6))
        p.append(tb(m["steel"], (1.5 * x, -3.6, 1.32), (1.5 * x, 2.8, 1.32), 0.016, 6))
    for k in range(9):
        y = -3.9 + k * 0.975
        for x in (1, -1):
            p.append(bx(m["inner"], (1.55 * x, y, 1.45), (0.1, 0.09, 2.5), 0.015))
        p.append(bx(m["inner"], (0, y, 2.71), (3.0, 0.09, 0.1), 0.015))
    p.append(box(m["inner"], (0, 0, 2.8), (3.1, L - 0.1, 0.02)))
    for i in range(4):
        y = -3.0 + i * 2.0
        p.append(box(m["lamp"] if i % 2 == 0 else m["blue"], (0, y, 2.77), (0.5, 0.12, 0.02)))
    p.append(bx(m["inner"], (0, 4.0, 1.4), (3.2, 0.3, 2.8), 0.03))                                # front bulkhead
    p.append(bx(m["hull2"], (0, 3.83, 1.5), (1.2, 0.05, 0.7), 0.01))
    p.append(box(m["screen"], (0, 3.8, 1.5), (1.0, 0.01, 0.55)))                                  # holo map
    # ---- the hull round it: armoured sides, cargo modules, the long back -----------------------------------------
    for x in (1, -1):
        p.append(bx(m["hull"], (1.85 * x, 0.5, 1.5), (0.25, 9.0, 2.8), 0.04))                        # inner armour
        p.append(bx(m["hull2"], (2.45 * x, 0.2, 1.2), (1.0, 7.4, 2.1), 0.08, seg=2))                 # cargo module
        for k in range(5):
            p.append(bx(m["panel"], (2.96 * x, -2.6 + k * 1.4, 1.2), (0.03, 1.2, 1.8), 0.02))
            p.append(box(m["lamp"], (2.98 * x, -2.6 + k * 1.4, 2.1), (0.01, 0.6, 0.04)))
        for k in range(6):
            p.append(box(m["warn"] if k % 2 == 0 else m["black"], (2.98 * x, -3.35, 0.4 + k * 0.28), (0.012, 0.2, 0.26)))
        p.append(box(m["stencil"], (2.985 * x, 0.6, 1.5), (0.01, 1.4, 0.18)))
        p.append(box(m["stripe"], (1.99 * x, 2.4, 2.6), (0.01, 0.5, 0.6)))
        # the lower hull and landing skids under the modules
        p.append(bx(m["hull2"], (2.1 * x, 0.5, 0.22), (1.3, 8.0, 0.35), 0.06))
        for y in (2.6, -2.4):
            p.append(tb(m["steel"], (2.3 * x, y, 0.2), (2.3 * x, y, -0.02), 0.08, 8))
            p.append(bx(m["black"], (2.3 * x, y, 0.0), (0.4, 0.7, 0.06), 0.02))
    p.append(box_loft(m["hull"], [(-4.0, 0, 3.15, 4.4, 0.5), (0.0, 0, 3.3, 4.8, 0.8), (4.0, 0, 3.25, 4.6, 0.7)], b=0.1))   # the back
    p.append(bx(m["hull2"], (0, 0.4, 3.75), (2.0, 6.5, 0.4), 0.1, seg=2))                         # dorsal spine
    for k in range(6):
        p.append(box(m["lamp"], (1.05, -2.2 + k * 0.9, 3.72), (0.02, 0.4, 0.06)))
        p.append(box(m["lamp"], (-1.05, -2.2 + k * 0.9, 3.72), (0.02, 0.4, 0.06)))
    p.append(box(m["stripe"], (0, 1.6, 3.96), (2.0, 0.4, 0.01)))
    for x in (0.6, -0.4):
        p.append(tb(m["steel"], (x, -1.5, 3.9), (x, -1.5, 5.0), 0.02, 6))                          # antennas
    # ---- the AI turret on top: a ring, a turret body, twin barrels with blue muzzles ---------------------------
    p.append(disc(m["hull2"], (0, 1.2, 4.05), 0.9, 0.2, verts=18, b=0.03))
    p.append(bx(m["hull"], (0, 1.1, 4.45), (1.1, 1.2, 0.55), 0.12))
    p.append(box(m["stencil"], (0.56, 1.1, 4.5), (0.01, 0.3, 0.2)))
    for x in (0.25, -0.25):
        p.append(tb(m["hull2"], (x, 1.6, 4.5), (x, 3.4, 4.6), 0.07, 10))
        p.append(disc(m["blue"], (x, 3.42, 4.6), 0.05, 0.03, 'y', verts=10))
    p.append(ball(m["blue"], (0, 1.75, 4.62), 0.09))
    # ---- the nose: a rounded wedge with a band of cockpit windows, a blue light arc, the chin --------------------
    p.append(box_loft(m["hull"], [(4.0, 0, 1.75, 5.2, 3.6), (6.0, 0, 1.65, 4.6, 3.2), (7.8, 0, 1.45, 3.6, 2.5), (9.0, 0, 1.25, 2.2, 1.6),
                                  (9.6, 0, 1.15, 0.9, 0.8)], b=0.2))
    for k in range(5):
        a = (k - 2) * 0.32
        p.append(bx(m["glass"], (math.sin(a) * 1.85, 6.6 + math.cos(a) * 0.4, 2.85), (0.7, 0.25, 0.42), 0.02, rot=(-0.5, 0, -a)))
    p.append(bx(m["hull2"], (0, 6.9, 3.1), (3.8, 0.4, 0.1), 0.03, rot=(-0.4, 0, 0)))
    for x in (1, -1):
        p.append(bx(m["blue"], (1.9 * x, 7.4, 1.1), (0.04, 2.6, 0.05), 0.0, rot=(0, 0, 0.25 * x)))
        p.append(bx(m["glass"], (2.35 * x, 5.4, 2.4), (0.03, 0.9, 0.4), 0.01))
        p.append(box(m["stencil"], (2.42 * x, 5.0, 1.6), (0.01, 1.2, 0.2)))
        p.append(disc(m["blue"], (2.0 * x, 6.0, 0.55), 0.22, 0.03, 'x', verts=14))
        p.append(box(m["red"] if x < 0 else m["grn"], (2.6 * x, 4.5, 2.2), (0.06, 0.15, 0.08)))
    p.append(ball(m["hull2"], (0, 8.6, 0.4), 0.3))
    # ---- the swept stub wings and the four engines beside the ramp ---------------------------------------------
    for x in (1, -1):
        p.append(plate(m["hull2"], [(2.9 * x, 0.0), (5.4 * x, -2.6), (5.4 * x, -3.6), (2.9 * x, -3.4)], 2.0, 2.3, b=0.05))
        p.append(box(m["white"], (5.42 * x, -3.2, 2.2), (0.04, 0.1, 0.08)))
        for (ex, ez) in ((3.4, 1.0), (3.6, 2.9)):
            c = ex * x
            p.append(loft(m["hull"], [(-1.0, c, ez, 0.62, 0.62), (-2.6, c, ez, 0.72, 0.72), (-4.4, c, ez, 0.66, 0.66), (-5.0, c, ez, 0.58, 0.58)], verts=18))
            for k in range(3):
                p.append(torus(m["hull2"], (c, -2.2 - k * 0.8, ez), 0.73, 0.04, rot=(PI2, 0, 0), seg=20))
            p.append(disc(m["black"], (c, -5.05, ez), 0.5, 0.05, 'y', verts=18))
            p.append(torus(m["exhaust"], (c, -5.08, ez), 0.38, 0.08, rot=(PI2, 0, 0), seg=18))
            p.append(torus(m["violet"], (c, -4.7, ez), 0.68, 0.03, rot=(PI2, 0, 0), seg=18))
            p.append(disc(m["exhaust"], (c, -5.1, ez), 0.22, 0.02, 'y', verts=12))
        p.append(bx(m["hull2"], (3.5 * x, -2.6, 1.95), (0.5, 3.0, 1.6), 0.05))                      # the engine pylon
    # ---- the rear: the open frame round the ramp, the lowered ramp ---------------------------------------------
    for x in (1, -1):
        p.append(bx(m["hull2"], (1.75 * x, -4.0, 1.5), (0.4, 0.2, 3.0), 0.03))
        p.append(tb(m["steel"], (1.4 * x, -4.0, 1.3), (1.4 * x, -5.0, 0.15), 0.035, 8))
    p.append(bx(m["hull2"], (0, -4.0, 3.0), (3.9, 0.2, 0.4), 0.03))
    p.append(box(m["red"], (0, -3.9, 2.75), (0.3, 0.02, 0.08)))
    p.append(bx(m["floor"], (0, -5.15, -0.08), (3.0, 2.4, 0.15), 0.02, rot=(0.17, 0, 0)))
    for i in range(6):
        p.append(bx(m["steel"], (0, -4.25 - i * 0.38, 0.03 - i * 0.065), (2.7, 0.05, 0.035), 0.008, rot=(0.17, 0, 0)))
    for x in (1, -1):
        for k in range(5):
            p.append(box(m["warn"] if k % 2 == 0 else m["black"], (1.45 * x, -4.2 - k * 0.45, 0.13 - k * 0.077), (0.125, 0.42, 0.01), rot=(0.17, 0, 0)))
    o = join(p, "Pelikan")
    export_glb(os.path.join(OUTDIR, "pelikan.glb"), [o])

ALL = dict(jestrab=jestrab, pelikan=pelikan)
for k, f in ALL.items():
    if not ONLY or k in ONLY:
        f()
        print("built", k)

if "--gallery" in sys.argv:
    out = sys.argv[sys.argv.index("--gallery") + 1]
    reset()
    for f, loc in (("jestrab.glb", (-9, 4, 4)), ("pelikan.glb", (4, 0, 0))):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=os.path.join(OUTDIR, f))
        for o in set(bpy.data.objects) - before:
            if o.parent is None:
                o.location = loc
    preview(out, target=(-1.0, 1.0, 2.0), dist=30.0, angle=0.9, height=9.0, res=(1400, 800))
    preview(out.replace(".png", "_back.png"), target=(-1.0, 0.0, 2.0), dist=30.0, angle=3.9, height=7.0, res=(1400, 800))
