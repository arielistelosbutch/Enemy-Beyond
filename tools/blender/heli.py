"""Our own twin-rotor transport helicopter "Čáp" (0.52 rework) - the team's ride before the Kondor.
Same cabin footprint as the Kondor (map_gen collision: walls x=+-1.6, roof 2.8, length 8, nose +Y =
Godot -Z, rear ramp open at -Y). The two rotors are separate objects (RotorF, RotorR) with the origin
in the hub (0, 4.6, 4.2) / (0, -3.2, 5.5), so the game can spin and fold them. Old olive drab, a
rounded hull with fuel sponsons, two engines on the rear pylon, a glazed nose.
The body mesh is called "Cap" (the old "Heli" block-modeller edits do not fit the new mesh).
Run: python3 heli.py OUTDIR [--gallery out.png]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from kit import *

ARGS = [a for a in sys.argv[1:] if not a.startswith("--") and not a.endswith(".png")]
OUTDIR = ARGS[0] if ARGS else "."

def rotor(m, hub_m, steel, name, loc, phase):
    """Hub with swash plate and pitch links, three long tapered blades with tip caps."""
    parts = [disc(hub_m, (0, 0, 0), 0.34, 0.3, verts=16, b=0.03), disc(steel, (0, 0, -0.25), 0.22, 0.2, verts=14),
             disc(hub_m, (0, 0, 0.22), 0.2, 0.16, verts=14, r2=0.12)]
    for i in range(3):
        a = phase + i * TAU / 3
        ca, sa = math.cos(a), math.sin(a)
        parts.append(bx(hub_m, (ca * 0.45, sa * 0.45, 0.05), (0.42, 0.2, 0.14), 0.03, rot=(0, 0, a)))      # blade grip
        parts.append(tb(steel, (ca * 0.25, sa * 0.25, -0.2), (ca * 0.4, sa * 0.4, 0.0), 0.02, 6))          # pitch link
        bl = plate(m, [(0.6, -0.2), (6.8, -0.14), (7.1, -0.06), (7.1, 0.12), (0.6, 0.2)], 0.08, 0.13)
        for v in bl.data.vertices:
            x, y, z = v.co
            z += 0.012 * x            # a little droop-up (coning)
            v.co = Vector((x * ca - y * sa, x * sa + y * ca, z))
        parts.append(bl)
        parts.append(bx(m, (ca * 6.95, sa * 6.95, 0.21), (0.3, 0.3, 0.06), 0.01, rot=(0, 0, a)))
        tip = bx(mat2("CapTip", (0.75, 0.6, 0.1), 0.6), (ca * 7.0, sa * 7.0, 0.215), (0.2, 0.31, 0.065), 0.005, rot=(0, 0, a))
        parts.append(tip)
    o = join(parts, name)
    for v in o.data.vertices:
        v.co += Vector(loc)
    origin_at(o, loc)
    return o

def heli():
    reset()
    hull = mat2("CapHull", (0.27, 0.3, 0.19), 0.75, 0.25)      # olive drab, a little metal under the paint
    hull2 = mat2("CapDark", (0.15, 0.16, 0.11), 0.7, 0.25)
    panel = mat2("CapPanel", (0.22, 0.25, 0.16), 0.75, 0.25)
    steel = mat2("CapSteel", (0.34, 0.35, 0.36), 0.4, 0.8)
    inner = mat2("CapInner", (0.3, 0.31, 0.27), 0.85)
    floor = mat2("CapFloor", (0.13, 0.13, 0.14), 0.5, 0.5)
    seat = mat2("CapSeat", (0.24, 0.21, 0.15), 0.9)
    strap = mat2("CapStrap", (0.4, 0.33, 0.12), 0.9)
    glass = mat2("CapGlass", (0.06, 0.09, 0.11), 0.05, 0.3)
    lamp = mat2("CapLamp", (1.0, 0.8, 0.5), emit=3.0)
    redl = mat2("CapRedLamp", (1.0, 0.12, 0.05), emit=2.5)
    red = mat2("CapNavRed", (1.0, 0.1, 0.05), emit=6.0)
    grn = mat2("CapNavGreen", (0.1, 1.0, 0.2), emit=6.0)
    hazard = mat2("CapHazard", (0.8, 0.65, 0.1), 0.6)
    black = mat2("CapBlack", (0.035, 0.035, 0.035), 0.8)
    blade = mat2("CapBlade", (0.07, 0.07, 0.07), 0.6)
    stencil = mat2("CapStencil", (0.7, 0.7, 0.62), 0.8)
    rubber = mat2("CapTyre", (0.03, 0.03, 0.03), 0.95)
    exhaust = mat2("CapSoot", (0.06, 0.05, 0.045), 0.9, 0.3)
    p = []
    L = 8.0
    # ---- hull: side walls, rounded upper and lower edges, sponsons --------------------------------------------------
    for x in (1, -1):
        p.append(bx(hull, (1.72 * x, 0, 1.5), (0.25, L, 2.3), 0.03))
        p.append(bx(hull, (1.55 * x, 0, 2.82), (0.55, L, 0.25), 0.03, rot=(0, 0.6 * x, 0)))   # rounded shoulder
        p.append(bx(hull, (1.33 * x, 0, 3.08), (0.45, L, 0.2), 0.03, rot=(0, 0.25 * x, 0)))
        p.append(bx(hull2, (1.62 * x, 0, 0.25), (0.5, L, 0.3), 0.03, rot=(0, -0.5 * x, 0)))
        # the fuel sponson: a long rounded pod along the lower hull
        p.append(loft(hull, [(3.3, 1.98 * x, 0.6, 0.12, 0.3), (2.9, 2.0 * x, 0.6, 0.3, 0.42), (-2.3, 2.0 * x, 0.6, 0.32, 0.44),
                             (-2.9, 1.98 * x, 0.6, 0.2, 0.36), (-3.2, 1.95 * x, 0.6, 0.08, 0.2)], verts=16))
        p.append(box(hull2, (2.3 * x, 0.2, 0.62), (0.012, 5.0, 0.03)))
        p.append(bx(panel, (2.28 * x, 0.8, 0.75), (0.03, 0.4, 0.2), 0.01))                    # fuel filler
        # panel seams, rivets
        for k in range(8):
            p.append(box(hull2, (1.85 * x, -3.6 + k * 1.03, 1.55), (0.012, 0.025, 2.1)))
        for z in (0.95, 2.45):
            p.append(box(hull2, (1.85 * x, 0, z), (0.012, L - 0.1, 0.025)))
            for k in range(24):
                p.append(screw(steel, (1.855 * x, -3.8 + k * 0.33, z + 0.06), 0.012))
        # round portholes with rubber rims
        for i in range(4):
            y = -2.4 + i * 1.5
            p.append(disc(black, (1.86 * x, y, 1.9), 0.37, 0.04, 'x', verts=20))
            p.append(disc(glass, (1.875 * x, y, 1.9), 0.3, 0.04, 'x', verts=20))
            p.append(torus(hull2, (1.88 * x, y, 1.9), 0.33, 0.03, rot=(0, PI2, 0), seg=20))
        # crew door with a slide rail, a step
        p.append(bx(panel, (1.86 * x, 3.35, 1.35), (0.04, 0.9, 1.9), 0.02))
        p.append(bx(glass, (1.885 * x, 3.35, 1.95), (0.02, 0.5, 0.42), 0.01))
        p.append(box(steel, (1.9 * x, 2.6, 2.4), (0.03, 2.0, 0.04)))
        p.append(bx(steel, (1.98 * x, 3.35, 0.25), (0.2, 0.6, 0.04), 0.01))
        p.append(box(hazard, (1.865 * x, 1.6, 2.6), (0.01, 1.2, 0.12)))
        for k in range(3):
            p.append(box(stencil, (1.865 * x, -0.5 + k * 0.17, 0.75), (0.01, 0.11, 0.24)))
        # wheels: two front on short struts, two rear on the sponsons
        for y in (2.6, -2.4):
            p.append(tb(steel, (1.9 * x, y, 0.4), (1.9 * x, y, 0.2), 0.06, 8))
            p.append(disc(rubber, (1.9 * x, y, 0.05), 0.3, 0.24, 'x', verts=18, b=0.04))
            p.append(disc(steel, (1.9 * x + 0.12 * x, y, 0.05), 0.15, 0.02, 'x', verts=12))
        p.append(box(grn if x == 1 else red, (2.22 * x, 3.3, 1.2), (0.05, 0.12, 0.08)))
    p.append(bx(hull, (0, 0, 3.12), (2.1, L, 0.25), 0.04))                                      # roof
    # ---- the cabin inside ------------------------------------------------------------------------------------------
    p.append(bx(floor, (0, 0, 0.1), (3.2, L, 0.2), 0.02))
    for i in range(16):
        p.append(box(steel, (0, -3.75 + i * 0.5, 0.205), (2.9, 0.06, 0.012)))
    for k in range(9):
        y = -3.9 + k * 0.975
        for x in (1, -1):
            p.append(bx(inner, (1.55 * x, y, 1.45), (0.1, 0.09, 2.5), 0.015))
        p.append(bx(inner, (0, y, 2.71), (3.0, 0.09, 0.1), 0.015))
    for x in (1, -1):
        p.append(box(inner, (1.585 * x, 0, 1.45), (0.01, L - 0.1, 2.5)))
        p.append(box(inner, (0, 0, 2.77), (3.1, L - 0.1, 0.01)))
        # canvas troop seats on a tube frame
        p.append(tb(steel, (1.15 * x, -3.4, 0.48), (1.15 * x, 2.8, 0.48), 0.02, 6))
        p.append(tb(steel, (1.48 * x, -3.4, 1.25), (1.48 * x, 2.8, 1.25), 0.02, 6))
        p.append(bx(seat, (1.32 * x, -0.3, 0.48), (0.36, 6.2, 0.03), 0.01))
        p.append(bx(seat, (1.5 * x, -0.3, 0.86), (0.03, 6.2, 0.75), 0.01))
        for k in range(9):
            y = -3.2 + k * 0.75
            p.append(tb(steel, (1.15 * x, y, 0.48), (1.15 * x, y, 0.2), 0.016, 6))
            p.append(box(strap, (1.47 * x, y, 0.86), (0.012, 0.05, 0.76)))
        p.append(bx(hull2, (1.1 * x, -0.4, 2.62), (0.25, 7.0, 0.08), 0.01))                   # cable trays
        p.append(tb(inner, (0.7 * x, -3.8, 2.6), (0.7 * x, 3.8, 2.6), 0.06, 10))
    for i in range(4):
        y = -3.0 + i * 2.0
        p.append(bx(hull2, (0, y, 2.71), (0.6, 0.18, 0.04), 0.01))
        p.append(box(lamp if i % 2 == 0 else redl, (0, y, 2.685), (0.5, 0.12, 0.02)))
    p.append(tb(strap, (-1.3, 3.75, 0.3), (-1.3, 3.75, 0.85), 0.07, 10))                        # extinguisher
    # front bulkhead with the door to the cockpit
    p.append(bx(inner, (1.0, 4.0, 1.4), (1.2, 0.3, 2.8), 0.03))
    p.append(bx(inner, (-1.0, 4.0, 1.4), (1.2, 0.3, 2.8), 0.03))
    p.append(bx(inner, (0, 4.0, 2.55), (0.8, 0.3, 0.5), 0.03))
    p.append(box(redl, (0, 3.83, 2.35), (0.25, 0.02, 0.08)))
    # ---- the glazed nose ---------------------------------------------------------------------------------------------
    p.append(box_loft(hull, [(4.0, 0, 1.55, 3.5, 3.0), (5.2, 0, 1.4, 3.3, 2.7), (6.2, 0, 1.05, 2.8, 1.9),
                             (6.85, 0, 0.75, 2.1, 1.1), (7.05, 0, 0.65, 1.4, 0.6)], b=0.18))
    # big windscreen panes, the lower "chin" windows, frames
    for x0, x1 in ((-1.2, -0.42), (-0.38, 0.38), (0.42, 1.2)):
        p.append(bx(glass, ((x0 + x1) / 2, 5.72, 2.42), (x1 - x0 - 0.04, 1.1, 0.04), 0.01, rot=(-0.64, 0, 0)))
    for x in (0.4, -0.4, 1.22, -1.22):
        p.append(bx(hull2, (x, 5.72, 2.43), (0.07, 1.15, 0.07), 0.01, rot=(-0.64, 0, 0)))
    p.append(bx(hull2, (0, 5.72, 2.44), (2.5, 0.06, 0.08), 0.01, rot=(-0.64, 0, 0)))
    for x in (1, -1):
        p.append(bx(glass, (0.55 * x, 6.95, 0.75), (0.75, 0.04, 0.5), 0.01, rot=(0.3, 0, 0)))
        p.append(bx(glass, (1.64 * x, 5.0, 2.0), (0.03, 1.0, 0.6), 0.01))
        p.append(tb(steel, (0.8 * x, 6.15, 2.08), (0.85 * x, 5.9, 2.3), 0.012, 6))            # wipers
    p.append(tb(steel, (0.8, 6.9, 0.9), (0.85, 7.9, 0.95), 0.025, 8, r2=0.008))                # pitot
    p.append(bx(hazard, (0.9, 6.92, 0.5), (0.4, 0.05, 0.25), 0.01))
    p.append(box(red, (0, 7.08, 0.5), (0.1, 0.03, 0.08)))
    p.append(disc(lamp, (-0.6, 7.0, 0.38), 0.1, 0.04, 'y', verts=12))                          # landing light
    # ---- the drive: a fairing along the roof, the front rotor pylon, the tall rear pylon with two engines ------
    p.append(bx(hull2, (0, 0.3, 3.35), (1.2, 5.6, 0.3), 0.06, seg=2))
    for k in range(10):
        p.append(bx(black, (0.61, -2.0 + k * 0.5, 3.36), (0.02, 0.3, 0.14), 0.005))
        p.append(bx(black, (-0.61, -2.0 + k * 0.5, 3.36), (0.02, 0.3, 0.14), 0.005))
    p.append(box_loft(hull, [(3.6, 0, 3.4, 1.4, 0.6), (4.3, 0, 3.55, 1.5, 0.9), (5.4, 0, 3.4, 1.0, 0.6), (5.8, 0, 3.25, 0.5, 0.3)], b=0.12))
    p.append(disc(hull2, (0, 4.6, 3.95), 0.3, 0.3, verts=14, r2=0.22))
    p.append(box_loft(hull, [(-1.8, 0, 3.6, 1.6, 0.6), (-2.4, 0, 4.0, 1.7, 1.6), (-4.0, 0, 4.15, 1.6, 1.9), (-4.4, 0, 4.0, 1.2, 1.4)], b=0.12))
    p.append(bx(hull, (0, -3.1, 5.0), (1.1, 1.4, 0.3), 0.06))
    p.append(disc(hull2, (0, -3.2, 5.25), 0.3, 0.3, verts=14, r2=0.22))
    for i in range(6):                                      # louvres on the rear pylon
        for x in (1, -1):
            p.append(bx(black, (0.81 * x, -3.95 + i * 0.3, 4.05), (0.02, 0.18, 0.9), 0.005))
    for x in (1, -1):
        # the engines: lofted pods with intake rings and sooty exhausts
        p.append(loft(hull, [(-1.3, 1.05 * x, 3.55, 0.3, 0.3), (-1.5, 1.05 * x, 3.55, 0.42, 0.42), (-3.4, 1.05 * x, 3.55, 0.44, 0.44),
                             (-3.85, 1.05 * x, 3.55, 0.34, 0.34)], verts=18))
        p.append(torus(steel, (1.05 * x, -1.32, 3.55), 0.3, 0.04, rot=(PI2, 0, 0), seg=18))
        p.append(disc(black, (1.05 * x, -1.31, 3.55), 0.27, 0.02, 'y', verts=16))
        p.append(disc(exhaust, (1.05 * x, -3.95, 3.55), 0.3, 0.25, 'y', verts=16, r2=0.26))
        p.append(disc(black, (1.05 * x, -4.07, 3.55), 0.22, 0.03, 'y', verts=14))
        for y in (-1.9, -2.6, -3.3):
            p.append(torus(hull2, (1.05 * x, y, 3.55), 0.44, 0.02, rot=(PI2, 0, 0), seg=18))
        p.append(bx(hull2, (0.75 * x, -2.5, 3.55), (0.3, 1.2, 0.2), 0.03))
    p.append(box(red, (0, -4.42, 4.85), (0.08, 0.08, 0.08)))
    p.append(tb(steel, (0.3, 1.0, 3.5), (0.3, 1.0, 4.1), 0.015, 6))
    # ---- rear ramp, lowered --------------------------------------------------------------------------------------------
    p.append(bx(floor, (0, -5.15, -0.08), (3.0, 2.4, 0.15), 0.02, rot=(0.17, 0, 0)))
    for i in range(6):
        p.append(bx(steel, (0, -4.25 - i * 0.38, 0.03 - i * 0.065), (2.7, 0.05, 0.035), 0.008, rot=(0.17, 0, 0)))
    for x in (1, -1):
        p.append(bx(hull2, (1.45 * x, -5.15, 0.0), (0.12, 2.4, 0.22), 0.02, rot=(0.17, 0, 0)))
        for k in range(5):
            p.append(box(hazard if k % 2 == 0 else black, (1.45 * x, -4.2 - k * 0.45, 0.13 - k * 0.077), (0.125, 0.42, 0.01), rot=(0.17, 0, 0)))
        p.append(bx(hull2, (1.66 * x, -4.0, 1.5), (0.36, 0.15, 3.0), 0.03))
    p.append(bx(hull2, (0, -4.0, 2.95), (3.6, 0.15, 0.3), 0.03))
    body = join(p, "Cap")
    rf = rotor(blade, hull2, steel, "RotorF", (0, 4.6, 4.2), 0.0)
    rr = rotor(blade, hull2, steel, "RotorR", (0, -3.2, 5.5), math.pi / 3)
    export_glb(os.path.join(OUTDIR, "heli.glb"), [body, rf, rr])

heli()
print("built heli")
if "--gallery" in sys.argv:
    out = sys.argv[sys.argv.index("--gallery") + 1]
    reset()
    bpy.ops.import_scene.gltf(filepath=os.path.join(OUTDIR, "heli.glb"))
    preview(out, target=(0, 0, 2.0), dist=19.0, angle=2.3, height=5.0, res=(1280, 800))
    preview(out.replace(".png", "_front.png"), target=(0, 1.0, 2.0), dist=17.0, angle=0.6, height=3.5, res=(1280, 800))
