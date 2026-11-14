"""Enemy Beyond 0.56 - the furniture of our base (own designs): lockers, a desk with its monitor, an
office chair, a console, a bunk bed, a steel rack, the autopsy table, a sick-bay bed and its curtain,
the cargo loader in the hangar, the command table under the globe.
The sizes are those of the boxes base_gen.gd used to build (its colliders stay, hidden), so the
screens it lights (coloured per room) sit in the housings here. No colliders in these files.
Front = +Y (Godot -Z), origin on the floor. In base_gen the front of a thing is +Z at yaw 0: the
props are turned by yaw + PI.
Run: python3 tools/blender/base_props.py <outdir> [--only a,b] [--gallery out.png]"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
from kit import *

ARGS = [a for a in sys.argv[1:] if not a.startswith("--") and not a.endswith(".png") and "," not in a]
OUTDIR = ARGS[0] if ARGS else "."
ONLY = sys.argv[sys.argv.index("--only") + 1].split(",") if "--only" in sys.argv else []

def M():
    return dict(
        grey=mat2("BPLockerGrey", (0.36, 0.38, 0.41), 0.5, 0.4), blue=mat2("BPLockerBlue", (0.22, 0.36, 0.62), 0.5, 0.3),
        white=mat2("BPWhite", (0.82, 0.83, 0.85), 0.5, 0.1), dark=mat2("BPDark", (0.12, 0.12, 0.13), 0.5, 0.4),
        steel=mat2("VMetal", (0.3, 0.31, 0.33), 0.45, 0.7), chrome=mat2("BPChrome", (0.6, 0.62, 0.64), 0.25, 0.9),
        top=mat2("BPDeskTop", (0.5, 0.52, 0.55), 0.6, 0.1), beige=mat2("BPBeige", (0.78, 0.76, 0.7), 0.6),
        fabric=mat2("BPSeatBlue", (0.22, 0.32, 0.55), 0.9), black=mat2("BPPlastic", (0.06, 0.06, 0.07), 0.6),
        key=mat2("BPKeys", (0.2, 0.2, 0.22), 0.7), led_g=mat2("BPLedGreen", (0.2, 1.0, 0.3), emit=3.0),
        led_r=mat2("BPLedRed", (1.0, 0.2, 0.1), emit=3.0), led_a=mat2("BPLedAmber", (1.0, 0.65, 0.1), emit=3.0),
        yellow=mat2("VYellowPaint", (0.8, 0.62, 0.15), 0.6, 0.3), mattress=mat2("BPMattress", (0.24, 0.4, 0.72), 0.9),
        sheet=mat2("BPSheet", (0.9, 0.9, 0.88), 0.9), olive=mat2("BPBlanket", (0.27, 0.3, 0.2), 0.95),
        curtain=mat2("BPCurtain", (0.5, 0.7, 0.7), 0.9), loader=mat2("BPLoaderBlue", (0.18, 0.27, 0.62), 0.55, 0.3),
        tyre=mat2("BPTyre", (0.05, 0.05, 0.05), 0.9), glass=mat2("BPGlassDark", (0.1, 0.14, 0.18), 0.1, 0.5),
        hazard=mat2("BPHazard", (0.85, 0.7, 0.1), 0.6), panel=mat2("BPPanelViolet", (0.5, 0.45, 0.58), 0.5, 0.3),
        band=mat2("BPBandBlue", (0.25, 0.5, 1.0), emit=2.5), mug=mat2("BPMug", (0.6, 0.12, 0.1), 0.5),
        paper=mat2("BPPaper", (0.92, 0.92, 0.88), 0.9),
    )

def save(name, vis, fname):
    o = join(vis, name)
    export_glb(os.path.join(OUTDIR, "v_%s.glb" % fname), [o])

def locker(fname, paint):
    """A steel locker 0.9 x 0.6 x 2.0: two doors with vents and handles, a plinth, a plate on top."""
    reset(); m = M(); vis = []; pm = m[paint]
    vis.append(bx(pm, (0, 0, 1.03), (0.9, 0.6, 1.94), 0.015))
    vis.append(bx(m["dark"], (0, 0, 0.04), (0.86, 0.56, 0.08), 0.005))
    for sx in (-0.222, 0.222):
        vis.append(bx(pm, (sx, 0.302, 1.04), (0.43, 0.012, 1.86), 0.008))
        for k in range(5):
            vis.append(bx(m["dark"], (sx, 0.309, 1.75 + k * 0.045), (0.26, 0.004, 0.018), 0.0))
        vis.append(bx(m["dark"], (sx + (0.17 if sx < 0 else -0.17), 0.315, 1.05), (0.025, 0.02, 0.16), 0.004))
        vis.append(bx(m["paper"], (sx, 0.309, 1.45), (0.14, 0.003, 0.06), 0.0))
    vis.append(bx(m["dark"], (0, 0.305, 1.04), (0.012, 0.01, 1.86), 0.0))
    save("Locker", vis, fname)

def desk():
    """A desk 1.6 x 0.8 (top at 0.75): two side panels, a drawer block, the monitor housing at the back
    (the game puts the lit screen in its front), a keyboard, papers, a mug."""
    reset(); m = M(); vis = []
    vis.append(bx(m["top"], (0, 0, 0.75), (1.6, 0.8, 0.06), 0.01))
    for sx in (-0.7, 0.7):
        vis.append(bx(m["steel"], (sx, 0, 0.37), (0.06, 0.7, 0.74), 0.005))
    vis.append(bx(m["steel"], (0, -0.36, 0.45), (1.34, 0.03, 0.5), 0.0))
    vis.append(bx(m["grey"], (0.45, 0.05, 0.47), (0.42, 0.6, 0.5), 0.01))
    for k in range(3):
        vis.append(bx(m["dark"], (0.45, 0.355, 0.32 + k * 0.15), (0.16, 0.02, 0.025), 0.0))
    # the monitor: housing round the screen, its neck and foot
    vis.append(bx(m["beige"], (0, -0.2, 1.0), (0.55, 0.35, 0.42), 0.03))
    vis.append(bx(m["beige"], (0, -0.31, 1.0), (0.4, 0.18, 0.3), 0.04))
    vis.append(bx(m["beige"], (0, -0.2, 0.79), (0.3, 0.25, 0.02), 0.005))
    vis.append(bx(m["led_g"], (0.22, -0.02, 0.81), (0.015, 0.005, 0.01), 0.0))
    vis.append(bx(m["key"], (0, 0.18, 0.79), (0.46, 0.16, 0.025), 0.005))
    vis.append(bx(m["black"], (0.34, 0.2, 0.785), (0.06, 0.1, 0.02), 0.01))
    vis.append(bx(m["paper"], (-0.52, 0.1, 0.785), (0.21, 0.3, 0.004), 0.0, rot=(0, 0, 0.2)))
    vis.append(bx(m["paper"], (-0.5, 0.08, 0.789), (0.21, 0.3, 0.004), 0.0, rot=(0, 0, -0.1)))
    vis.append(disc(m["mug"], (-0.3, -0.2, 0.83), 0.04, 0.1, verts=10))
    save("Desk", vis, "bp_desk")

def chair():
    """An office chair: five feet on castors, the gas column, a padded seat and back on a bracket."""
    reset(); m = M(); vis = []
    for k in range(5):
        a = k * TAU / 5
        vis.append(beam(m["black"], (0, 0, 0.1), (math.cos(a) * 0.3, math.sin(a) * 0.3, 0.06), 0.05, 0.035))
        vis.append(ball(m["black"], (math.cos(a) * 0.3, math.sin(a) * 0.3, 0.03), 0.03, seg=6, rings=4))
    vis.append(tb(m["chrome"], (0, 0, 0.1), (0, 0, 0.42), 0.025, 8))
    vis.append(bx(m["fabric"], (0, 0, 0.48), (0.5, 0.5, 0.09), 0.035))
    vis.append(bx(m["black"], (0, -0.22, 0.6), (0.06, 0.04, 0.26), 0.01))
    vis.append(bx(m["fabric"], (0, -0.24, 0.85), (0.46, 0.08, 0.5), 0.035, rot=(-0.1, 0, 0)))
    save("Chair", vis, "bp_chair")

def console():
    """A console 1.4 wide: the cabinet with a slanted desk of switches, the monitor housing at the back
    (the game puts the lit screen in it), cooling grilles, status lamps."""
    reset(); m = M(); vis = []
    vis.append(bx(m["beige"], (0, -0.02, 0.45), (1.4, 0.56, 0.9), 0.015))
    vis.append(bx(m["dark"], (0, 0.03, 0.04), (1.36, 0.5, 0.08), 0.005))
    # the desk of switches slopes up towards the monitor (low front edge at the operator; 0.69: it
    # sloped the other way, the back edge sank into the cabinet - Ari: "klávesnice ve špatném sklonu")
    tilt = -0.3
    sl = bx(m["grey"], (0, 0.1, 0.99), (1.38, 0.42, 0.06), 0.01, rot=(tilt, 0, 0))
    vis.append(sl)
    rr = random.Random(4)
    for i in range(10):
        for j in range(2):
            col = [m["led_g"], m["led_r"], m["led_a"], m["key"], m["key"]][rr.randrange(5)]
            dy, dz = -0.06 + j * 0.13, 0.042           # on the slab, in its own frame
            ky = 0.1 + dy * math.cos(tilt) - dz * math.sin(tilt)
            kz = 0.99 + dy * math.sin(tilt) + dz * math.cos(tilt)
            vis.append(bx(col, (-0.55 + i * 0.12, ky, kz), (0.06, 0.06, 0.025), 0.005, rot=(tilt, 0, 0)))
    for k in range(6):
        vis.append(bx(m["dark"], (-0.4 + k * 0.16, 0.262, 0.4), (0.1, 0.005, 0.3), 0.0))
    # the monitor housing: a frame round the game's screen (1.1 x 0.6 at y -0.125)
    vis.append(bx(m["grey"], (0, -0.2, 1.45), (1.3, 0.12, 0.8), 0.02))
    vis.append(bx(m["grey"], (0, -0.27, 1.45), (1.0, 0.1, 0.55), 0.03))
    vis.append(bx(m["steel"], (0, -0.2, 1.0), (0.2, 0.08, 0.15), 0.0))
    for k in range(3):
        vis.append(bx([m["led_g"], m["led_a"], m["led_r"]][k], (0.45 + k * 0.06, -0.135, 1.1), (0.03, 0.01, 0.03), 0.0))
    save("Console", vis, "bp_console")

def bunk():
    """A bunk bed 2.0 x 0.9 along X: a yellow tube frame, blue mattresses with olive blankets, pillows,
    a ladder at the foot."""
    reset(); m = M(); vis = []
    L, W = 2.0, 0.9
    for sx in (-L / 2, L / 2):
        for sy in (-W / 2, W / 2):
            vis.append(tb(m["yellow"], (sx, sy, 0), (sx, sy, 1.8), 0.03, 8))
            vis.append(disc(m["dark"], (sx, sy, 0.01), 0.04, 0.02, verts=8))
    for z in (0.37, 1.37):
        for sy in (-W / 2, W / 2):
            vis.append(tb(m["yellow"], (-L / 2, sy, z), (L / 2, sy, z), 0.025, 8))
        for sx in (-L / 2, L / 2):
            vis.append(tb(m["yellow"], (sx, -W / 2, z), (sx, W / 2, z), 0.025, 8))
        vis.append(bx(m["mattress"], (0, 0, z + 0.08), (L - 0.06, W - 0.06, 0.15), 0.04))
        vis.append(bx(m["olive"], (0.2, 0, z + 0.16), (L - 0.5, W - 0.02, 0.03), 0.015))
        vis.append(bx(m["sheet"], (-L / 2 + 0.3, 0, z + 0.2), (0.35, 0.6, 0.1), 0.04))
    for sy in (-W / 2, W / 2):
        vis.append(tb(m["yellow"], (-L / 2, sy, 1.75), (L / 2, sy, 1.75), 0.02, 8))
    for k in range(3):
        vis.append(tb(m["yellow"], (L / 2 + 0.01, -0.15, 0.6 + k * 0.3), (L / 2 + 0.01, 0.15, 0.6 + k * 0.3), 0.018, 6))
    save("Bunk", vis, "bp_bunk")

def rack():
    """A steel rack 2.4 x 0.6 along X: perforated uprights, four shelves with lips, cross braces at the back."""
    reset(); m = M(); vis = []
    L = 2.4
    for sx in (-L / 2, L / 2):
        for sy in (-0.28, 0.28):
            vis.append(bx(m["steel"], (sx, sy, 1.1), (0.05, 0.04, 2.2), 0.0))
            for k in range(10):
                vis.append(bx(m["dark"], (sx, sy + (0.021 if sy > 0 else -0.021), 0.2 + k * 0.2), (0.02, 0.002, 0.04), 0.0))
    for z in (0.1, 0.8, 1.5, 2.1):
        vis.append(bx(m["grey"], (0, 0, z), (L, 0.6, 0.04), 0.005))
        vis.append(bx(m["blue"], (0, 0.3, z + 0.02), (L, 0.02, 0.07), 0.0))
    for a, b in (((-L / 2, -0.29, 0.2), (0, -0.29, 2.0)), ((L / 2, -0.29, 0.2), (0, -0.29, 2.0))):
        vis.append(beam(m["steel"], a, b, 0.025, 0.01))
    save("Rack", vis, "bp_rack")

def autopsy():
    """The autopsy table: a steel tray with a raised rim and a drain on a pedestal, a sheet over a shape
    that is not human, the lamp on its arm above."""
    reset(); m = M(); vis = []
    vis.append(bx(m["chrome"], (0, 0, 0.85), (2.2, 1.0, 0.08), 0.02))
    for sx in (-1.08, 1.08):
        vis.append(bx(m["chrome"], (sx, 0, 0.92), (0.04, 1.0, 0.08), 0.01))
    for sy in (-0.48, 0.48):
        vis.append(bx(m["chrome"], (0, sy, 0.92), (2.2, 0.04, 0.08), 0.01))
    vis.append(disc(m["dark"], (0.95, 0, 0.895), 0.05, 0.01, verts=10))
    vis.append(tb(m["steel"], (0, 0, 0.0), (0, 0, 0.81), 0.15, 10))
    vis.append(disc(m["steel"], (0, 0, 0.03), 0.4, 0.06, verts=14))
    # under the sheet: a big head, a thin body
    vis.append(ball(m["sheet"], (-0.55, 0, 1.0), 0.28, (1.0, 1.0, 0.55), seg=12, rings=7))
    vis.append(ball(m["sheet"], (0.2, 0, 0.97), 0.5, (1.4, 0.45, 0.2), seg=12, rings=6))
    vis.append(bx(m["sheet"], (0.15, 0, 0.92), (1.6, 0.7, 0.03), 0.012))
    # the lamp and its arm up to the ceiling
    vis.append(lathe(m["steel"], [(0, 2.72), (0.2, 2.72), (0.4, 2.5), (0.38, 2.47), (0, 2.6)], 14, sm=False))
    vis.append(disc(m["paper"], (0, 0, 2.49), 0.3, 0.02, verts=14))
    vis.append(tb(m["steel"], (0, 0, 2.72), (0.5, 0, 3.0), 0.03, 6))
    vis.append(tb(m["steel"], (0.5, 0, 3.0), (0.5, 0, 3.6), 0.03, 6))
    save("Autopsy", vis, "bp_autopsy")

def sickbed():
    """A sick-bay bed 1.0 x 2.1 along Y, the head at +Y: a frame on castors, side rails, a white mattress,
    a pillow, a folded blanket at the foot."""
    reset(); m = M(); vis = []
    vis.append(bx(m["white"], (0, 0, 0.42), (0.95, 2.05, 0.08), 0.015))
    for sx in (-0.42, 0.42):
        for sy in (-0.95, 0.95):
            vis.append(tb(m["chrome"], (sx, sy, 0.08), (sx, sy, 0.42), 0.02, 6))
            vis.append(ball(m["black"], (sx, sy, 0.05), 0.05, seg=6, rings=4))
        vis.append(tb(m["chrome"], (sx * 1.15, -0.5, 0.75), (sx * 1.15, 0.5, 0.75), 0.015, 6))
        for sy in (-0.5, 0.5):
            vis.append(tb(m["chrome"], (sx * 1.15, sy, 0.5), (sx * 1.15, sy, 0.75), 0.015, 6))
    vis.append(bx(m["sheet"], (0, 0, 0.55), (0.9, 2.0, 0.18), 0.05))
    vis.append(bx(m["sheet"], (0, 0.75, 0.68), (0.65, 0.35, 0.1), 0.04))
    vis.append(bx(m["olive"], (0, -0.75, 0.66), (0.85, 0.4, 0.06), 0.02))
    vis.append(bx(m["chrome"], (0, 1.02, 0.7), (0.95, 0.04, 0.5), 0.02))
    vis.append(bx(m["chrome"], (0, -1.02, 0.6), (0.95, 0.04, 0.35), 0.02))
    save("SickBed", vis, "bp_sickbed")

def curtain():
    """A curtain on its rail, 2.2 long along Y, hanging in folds from rings."""
    reset(); m = M(); vis = []
    vis.append(tb(m["chrome"], (0, -1.1, 2.15), (0, 1.1, 2.15), 0.015, 6))
    for k in range(12):
        y = -1.05 + k * 0.19
        vis.append(bx(m["curtain"], (0.03 * (1 if k % 2 else -1), y, 1.18), (0.03, 0.2, 1.9), 0.008))
        vis.append(torus(m["chrome"], (0, y, 2.15), 0.03, 0.006, rot=(PI2, 0, 0), seg=8, mseg=4))
    save("Curtain", vis, "bp_curtain")

def loader():
    """The cargo loader in the hangar (1.4 x 2.2 x 2.0, front +Y): a blue body, the cage over the seat,
    four fat wheels, the lifting mast with its forks, hazard stripes, a beacon."""
    reset(); m = M(); vis = []
    vis.append(bx(m["loader"], (0, -0.2, 0.55), (1.3, 1.5, 0.6), 0.04))
    vis.append(bx(m["loader"], (0, -0.75, 0.95), (1.25, 0.45, 0.5), 0.05))           # counterweight
    for sx in (-0.55, 0.55):
        for sy in (-0.65, 0.35):
            vis.append(disc(m["tyre"], (sx * 1.1, sy, 0.3), 0.3, 0.22, axis='x', verts=14, b=0.02))
            vis.append(disc(m["steel"], (sx * 1.1 + (0.12 if sx > 0 else -0.12), sy, 0.3), 0.14, 0.02, axis='x', verts=10))
    for sx in (-0.55, 0.55):
        for sy in (-0.55, 0.25):
            vis.append(bx(m["dark"], (sx, sy, 1.45), (0.06, 0.06, 1.2), 0.0))
    vis.append(bx(m["dark"], (0, -0.15, 2.04), (1.2, 0.9, 0.05), 0.0))
    vis.append(bx(m["black"], (0, -0.2, 0.95), (0.5, 0.5, 0.12), 0.03))              # the seat
    vis.append(bx(m["black"], (0, -0.42, 1.2), (0.5, 0.1, 0.45), 0.03))
    vis.append(bx(m["dark"], (0.2, 0.15, 1.15), (0.3, 0.12, 0.3), 0.02))
    for sx in (-0.4, 0.4):
        vis.append(bx(m["steel"], (sx, 0.65, 1.0), (0.1, 0.1, 2.0), 0.0))
        vis.append(bx(m["steel"], (sx * 0.8, 0.95, 0.06), (0.1, 0.6, 0.04), 0.0))
        vis.append(bx(m["steel"], (sx * 0.8, 0.7, 0.35), (0.1, 0.04, 0.6), 0.0))
    vis.append(bx(m["steel"], (0, 0.67, 1.9), (0.9, 0.08, 0.1), 0.0))
    for k in range(6):
        vis.append(bx(m["hazard"] if k % 2 == 0 else m["black"], (-0.55 + k * 0.22, -0.98, 0.95), (0.2, 0.01, 0.12), 0.0, rot=(0, 0.6, 0)))
    vis.append(disc(m["led_a"], (0.5, -0.5, 2.1), 0.07, 0.1, verts=10))
    save("Loader", vis, "bp_loader")

def command_table():
    """The round command table under the globe: a ring of panels leaning out, a lit band, the dark rim
    round the game's glowing top, the projector in the middle."""
    reset(); m = M(); vis = []
    vis.append(lathe(m["panel"], [(0, 0.0), (1.1, 0.0), (1.12, 0.1), (1.28, 0.82), (1.32, 0.9), (1.27, 0.9), (0, 0.9)], 12, sm=False))
    vis.append(lathe(m["dark"], [(1.27, 0.88), (1.33, 0.9), (1.33, 0.95), (1.24, 0.95), (1.24, 0.88)], 24, sm=False))
    vis.append(torus(m["band"], (0, 0, 0.6), 1.23, 0.015, seg=24))
    vis.append(lathe(m["dark"], [(0, 0.9), (0.25, 0.9), (0.18, 1.05), (0.1, 1.08), (0, 1.08)], 12, sm=False))
    vis.append(disc(m["band"], (0, 0, 1.085), 0.08, 0.01, verts=10))
    for k in range(12):
        a = k * TAU / 12
        vis.append(bx(m["dark"], (math.cos(a) * 1.2, math.sin(a) * 1.2, 0.45), (0.04, 0.12, 0.6), 0.0, rot=(0, 0, a)))
    vis.append(lathe(m["dark"], [(0, 0.0), (1.15, 0.0), (1.15, 0.06), (0, 0.06)], 24, sm=False))
    save("CommandTable", vis, "bp_command_table")

ALL = dict(bp_locker_grey=lambda: locker("bp_locker_grey", "grey"), bp_locker_blue=lambda: locker("bp_locker_blue", "blue"),
           bp_locker_white=lambda: locker("bp_locker_white", "white"), bp_locker_dark=lambda: locker("bp_locker_dark", "dark"),
           bp_desk=desk, bp_chair=chair, bp_console=console, bp_bunk=bunk, bp_rack=rack, bp_autopsy=autopsy,
           bp_sickbed=sickbed, bp_curtain=curtain, bp_loader=loader, bp_command_table=command_table)
for k, f in ALL.items():
    if not ONLY or k in ONLY:
        f()
        print("built", k)

if "--gallery" in sys.argv:
    out = sys.argv[sys.argv.index("--gallery") + 1]
    names = [k for k in ALL if not ONLY or k in ONLY]
    gallery(out, [os.path.join(OUTDIR, "v_%s.glb" % n) for n in names], cols=5, spacing=3.2, target_z=0.9,
            dist=16, height=7, angle=0.0, res=(1600, 1000))
