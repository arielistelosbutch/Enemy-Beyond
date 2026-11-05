"""Enemy Beyond 0.52 - models of the items that have no model in the game (only a picture in the
inventory, the research tree and the encyclopedia): the plate-carrier vest "vesta", the alien-alloy
armour "pancir", the alien backpack "a_pack" and the plasma cell "plasma_cell". Own designs.
They are written to tools/icon_models/ (not assets/models, so nothing in the game changes): tools/icons.gd
renders their icons from them. Front = +Y (Godot -Z), origin in the middle.
Run: python3 tools/blender/icon_items.py <outdir> [--gallery out.png]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from kit import *

ARGS = [a for a in sys.argv[1:] if not a.startswith("--") and not a.endswith(".png")]
OUTDIR = ARGS[0] if ARGS else os.path.join(os.path.dirname(__file__), "..", "icon_models")

def save(parts, name, fname):
    o = join(parts, name)
    export_glb(os.path.join(OUTDIR, fname + ".glb"), [o])

def vesta():
    """A plate carrier: front and back plate bags, padded shoulder straps, a cummerbund, webbing rows,
    three magazine pouches, a radio pouch, a name tape."""
    reset(); p = []
    ol = mat2("VestOlive", (0.2, 0.23, 0.15), 0.9)
    ol2 = mat2("VestOliveDark", (0.13, 0.15, 0.1), 0.9)
    web = mat2("VestWebbing", (0.16, 0.18, 0.12), 0.95)
    blk = mat2("VestBlack", (0.04, 0.04, 0.04), 0.8)
    tape = mat2("VestTape", (0.55, 0.52, 0.42), 0.9)
    p.append(bx(ol, (0, 0.04, 0.0), (0.3, 0.06, 0.36), 0.025, seg=2))           # front plate bag
    p.append(bx(ol, (0, -0.1, 0.02), (0.3, 0.05, 0.38), 0.025, seg=2))          # back plate bag
    for sx in (1, -1):
        p.append(bx(ol2, (0.1 * sx, -0.03, 0.22), (0.07, 0.16, 0.05), 0.02, seg=2))   # shoulder straps
        p.append(bx(ol2, (0.17 * sx, -0.03, -0.1), (0.05, 0.14, 0.14), 0.02))        # cummerbund sides
    for k in range(4):                                                         # webbing rows on the front
        p.append(box(web, (0, 0.072, 0.1 - k * 0.04), (0.28, 0.006, 0.018)))
    for k in range(3):                                                         # magazine pouches
        x = -0.09 + k * 0.09
        p.append(bx(ol2, (x, 0.1, -0.08), (0.075, 0.05, 0.14), 0.01, seg=2))
        p.append(bx(ol, (x, 0.103, -0.02), (0.08, 0.055, 0.04), 0.01))
        p.append(bx(blk, (x, 0.13, -0.04), (0.02, 0.008, 0.03), 0.003))
    p.append(bx(ol2, (0.12, 0.09, 0.08), (0.06, 0.05, 0.12), 0.01))            # radio pouch
    p.append(tb(blk, (0.13, 0.09, 0.14), (0.13, 0.09, 0.3), 0.005, 6))
    p.append(bx(tape, (-0.06, 0.075, 0.14), (0.12, 0.005, 0.03), 0.002))       # name tape
    p.append(bx(blk, (0, 0.04, 0.19), (0.12, 0.05, 0.02), 0.005))             # drag handle
    save(p, "Vesta", "vesta")

def pancir():
    """Armour of alien alloy: a moulded breastplate in dark violet-grey alloy, a segmented belly,
    shoulder guards, a raised collar, violet seams where the plates meet."""
    reset(); p = []
    al = mat2("AlloyPlate", (0.26, 0.24, 0.3), 0.35, 0.7)
    al2 = mat2("AlloyPlateDark", (0.12, 0.11, 0.14), 0.4, 0.6)
    glow = mat2("AlloySeam", (0.8, 0.3, 1.0), emit=3.0)
    blk = mat2("AlloyUnder", (0.05, 0.05, 0.06), 0.8)
    p.append(bx(blk, (0, -0.03, 0.0), (0.32, 0.16, 0.42), 0.03, seg=2))       # the padded suit under it
    for sx in (1, -1):                                                        # two moulded chest plates
        p.append(bx(al, (0.075 * sx, 0.06, 0.08), (0.15, 0.05, 0.2), 0.02, rot=(0.1, 0, -0.25 * sx), seg=3))
        p.append(beam(glow, (0.005 * sx, 0.09, 0.17), (0.005 * sx, 0.09, -0.02), 0.004, 0.004))
    p.append(bx(al2, (0, 0.085, 0.07), (0.03, 0.03, 0.22), 0.008))            # the ridge between them
    p.append(bx(al, (0, -0.11, 0.03), (0.3, 0.04, 0.38), 0.02, seg=2))        # back plate
    for k in range(3):                                                         # the belly segments
        z = -0.07 - k * 0.055
        p.append(bx(al if k % 2 == 0 else al2, (0, 0.035, z), (0.27 - k * 0.02, 0.06, 0.05), 0.012, seg=2))
        p.append(box(glow, (0, 0.066, z + 0.027), (0.2 - k * 0.02, 0.004, 0.004)))
    for sx in (1, -1):
        p.append(ball(al, (0.17 * sx, -0.02, 0.19), 0.06, (1.15, 1.25, 0.55)))   # shoulder guards
        p.append(ball(al2, (0.2 * sx, -0.02, 0.155), 0.05, (1.0, 1.15, 0.5)))
    p.append(lathe(al2, [(0.07, 0.2), (0.09, 0.2), (0.085, 0.24), (0.065, 0.25)], 20, cy=-0.02))   # collar
    p.append(ball(glow, (0, 0.105, 0.06), 0.012))
    save(p, "Pancir", "pancir")

def a_pack():
    """The alien backpack: a ribbed carapace of dark violet alloy with bone-pale ridges, a green cell
    glowing in a cradle, tubes running into the shell."""
    reset(); p = []
    sh = mat2("APackShell", (0.17, 0.14, 0.2), 0.35, 0.7)
    dk = mat2("APackDark", (0.07, 0.06, 0.09), 0.4, 0.6)
    bone = mat2("APackBone", (0.55, 0.52, 0.46), 0.4)
    green = mat2("APackCore", (0.35, 1.0, 0.5), emit=4.0)
    glow = mat2("APackGlow", (0.75, 0.3, 1.0), emit=3.0)
    p.append(ball(sh, (0, -0.02, 0.0), 0.15, (1.0, 0.7, 1.25), seg=24, rings=14))
    for k in range(5):                                                        # ribs over the back
        z = -0.1 + k * 0.05
        rib = torus(bone, (0, 0, 0), 0.152 * math.sqrt(max(0.05, 1 - (z / 0.19) ** 2)), 0.006, seg=24)
        for v in rib.data.vertices:              # follow the oval shell
            v.co.y = v.co.y * 0.7 - 0.02
            v.co.z += z
        p.append(rib)
    p.append(ball(dk, (0, -0.1, 0.02), 0.07, (1.4, 0.6, 1.4)))
    p.append(tb(dk, (0, -0.13, -0.06), (0, -0.13, 0.08), 0.035, 16))          # the cradle
    p.append(tb(green, (0, -0.13, -0.05), (0, -0.13, 0.07), 0.025, 14))
    for sx in (1, -1):
        p.append(tb(dk, (0.045 * sx, -0.13, 0.08), (0.1 * sx, -0.05, 0.14), 0.01, 8))   # tubes
        p.append(tb(dk, (0.1 * sx, -0.05, 0.14), (0.12 * sx, 0.02, 0.1), 0.01, 8))
        p.append(beam(glow, (0.13 * sx, 0.0, -0.1), (0.13 * sx, 0.0, 0.1), 0.006, 0.006))
        p.append(tb(dk, (0.08 * sx, 0.08, 0.15), (0.09 * sx, 0.09, -0.12), 0.012, 8))    # strap hooks
    save(p, "APack", "a_pack")

def plasma_cell():
    """A plasma cell: a dark alloy canister with windows on the green core, ribbed end caps, contacts."""
    reset(); p = []
    al = mat2("CellAlloy", (0.2, 0.21, 0.23), 0.35, 0.75)
    dk = mat2("CellDark", (0.07, 0.07, 0.08), 0.5, 0.6)
    green = mat2("CellCore", (0.25, 0.9, 0.4), emit=1.2)
    brass = mat2("CellContact", (0.62, 0.47, 0.2), 0.3, 1.0)
    p.append(tb(green, (0, -0.045, 0), (0, 0.045, 0), 0.019, 16))
    for k in range(4):                                                        # four bars round the core
        a = TAU * k / 4 + 0.785
        p.append(bx(al, (math.cos(a) * 0.021, 0, math.sin(a) * 0.021), (0.012, 0.09, 0.012), 0.002, rot=(0, -a, 0)))
    for s in (1, -1):
        p.append(tb(al, (0, s * 0.045, 0), (0, s * 0.06, 0), 0.026, 18))
        p.append(tb(dk, (0, s * 0.06, 0), (0, s * 0.066, 0), 0.022, 18))
        for k in range(3):
            p.append(torus(dk, (0, s * (0.048 + k * 0.005), 0), 0.026, 0.0015, rot=(PI2, 0, 0), seg=20))
    p.append(tb(brass, (0, 0.066, 0), (0, 0.072, 0), 0.007, 10))
    p.append(tb(brass, (0, -0.066, 0), (0, -0.07, 0), 0.01, 10))
    p.append(bx(green, (0, 0.0, 0.0195), (0.004, 0.06, 0.002), 0.0005))
    save(p, "PlasmaCell", "plasma_cell")

os.makedirs(OUTDIR, exist_ok=True)
vesta(); pancir(); a_pack(); plasma_cell()
print("built icon items")
if "--gallery" in sys.argv:
    gallery(sys.argv[sys.argv.index("--gallery") + 1], [os.path.join(OUTDIR, n + ".glb") for n in ("vesta", "pancir", "a_pack", "plasma_cell")],
            cols=4, spacing=0.5, dist=2.6, height=0.5, target_z=0.0, angle=0.3, res=(1400, 500))
