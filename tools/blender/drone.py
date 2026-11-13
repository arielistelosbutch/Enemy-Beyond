"""Enemy Beyond 0.70 facelift - Strážce, the small medic drone that flies with a lone mercenary.
Own design (no X-COM asset): a flat armoured quadcopter, four arms to the corners, each with a
motor, a guard ring and a two-blade propeller the game spins (separate objects Prop_FL/FR/BL/BR,
origin at the hub). Front sensor eye (object Eye, green glow), a white plate with a red cross on
top, a medical canister underneath, nav lights (red left, green right), an antenna.
Front +Y in Blender (-Z in Godot), origin = the centre of the body, size ~0.46 m across.
Run: python3 tools/blender/drone.py <outdir> [--preview out.png]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
_argv = sys.argv
sys.argv = [_argv[0], "/tmp", "--only", "-"]      # guns.py: only the helpers, build nothing
import guns
from guns import *
sys.argv = _argv
from mathutils import Vector

ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
OUTDIR = ARGS[0] if ARGS else "."
PI2 = math.pi / 2
ARM = 0.165          # hub distance from the centre along x and y
HUB_Z = 0.035        # propeller plane height
PROP_R = 0.078       # blade tip radius
GUARD_R = 0.088      # inner radius of the guard ring


def mats():
    return dict(
        shell=mat2("DroneShell", (0.30, 0.33, 0.30), 0.55, 0.15),     # olive-grey armour
        shell2=mat2("DroneShellDark", (0.17, 0.19, 0.17), 0.6, 0.2),
        steel=mat2("GunSteel", (0.26, 0.27, 0.28), 0.35, 0.8),
        dark=mat2("Parkerized", (0.075, 0.075, 0.08), 0.5, 0.6),
        black=mat2("BlackPoly", (0.045, 0.045, 0.05), 0.8),
        rubber=mat2("Rubber", (0.03, 0.03, 0.03), 0.95),
        white=mat2("MedicWhite", (0.86, 0.86, 0.82), 0.6),
        cross=mat2("MedicRed", (0.82, 0.08, 0.06), 0.55),
        eye=mat2("DroneEye", (0.3, 1.0, 0.5), emit=4.0),
        lens=mat2("LensGlass", (0.12, 0.22, 0.32), 0.05, 0.5),
        red=mat2("NavRed", (1.0, 0.12, 0.05), emit=5.0),
        green=mat2("NavGreen", (0.2, 1.0, 0.3), emit=5.0),
        warn=mat2("WarnYellow", (0.78, 0.62, 0.12), 0.6),
        blade=mat2("PropBlade", (0.06, 0.06, 0.065), 0.5),
        tip=mat2("PropTip", (0.85, 0.62, 0.1), 0.5),
    )


def body(m):
    p = []
    # the hull: a flat chamfered slab, a raised spine, a nose that slopes down to the eye
    p.append(bx(m["shell"], (0, 0, 0), (0.13, 0.17, 0.05), 0.012, seg=2))
    p.append(bx(m["shell2"], (0, -0.005, 0.03), (0.095, 0.12, 0.018), 0.006, seg=2))
    p.append(bx(m["shell"], (0, 0.09, -0.006), (0.1, 0.04, 0.036), 0.01, rot=(0.35, 0, 0), seg=2))
    p.append(bx(m["dark"], (0, -0.092, 0.0), (0.09, 0.022, 0.034), 0.005))            # the back: battery
    for x in (-0.03, 0.0, 0.03):                                                         # cooling slots
        p.append(bx(m["black"], (x, -0.104, 0.002), (0.012, 0.004, 0.022), 0.001))
    # side skirts with screws
    for sx in (-1, 1):
        p.append(bx(m["shell2"], (sx * 0.067, 0, -0.008), (0.008, 0.13, 0.03), 0.003))
        for y in (-0.045, 0.045):
            p.append(screw(m["steel"], (sx * 0.072, y, -0.004), 0.0035))
    # the medic plate on top: white square with a red cross
    p.append(bx(m["white"], (0, -0.005, 0.0405), (0.07, 0.07, 0.004), 0.0015))
    p.append(bx(m["cross"], (0, -0.005, 0.043), (0.052, 0.016, 0.003), 0.001))
    for sy in (-1, 1):                     # the upright in two halves (no overlap = no flicker)
        p.append(bx(m["cross"], (0, -0.005 + sy * 0.0165, 0.043), (0.016, 0.017, 0.003), 0.001))
    # antenna at the back
    p.append(tb(m["dark"], (0.03, -0.075, 0.035), (0.034, -0.085, 0.12), 0.0022, verts=6))
    p.append(sphere(m["red"], (0.034, -0.085, 0.122), 0.004, seg=8, rings=5))
    # sensor head under the nose: a dark ball housing, the eye goes in front of it
    p.append(smooth(sphere(m["dark"], (0, 0.085, -0.03), 0.026, seg=16, rings=10)))
    p.append(ty(m["dark"], 0.1, 0.112, -0.03, 0.017, verts=16))
    # the medical canister under the belly with yellow bands and a stim nozzle
    p.append(tb(m["white"], (0, -0.055, -0.042), (0, 0.04, -0.042), 0.019, verts=16))
    p.append(tb(m["white"], (0, -0.06, -0.042), (0, -0.055, -0.042), 0.015, verts=16))
    for y in (-0.035, 0.02):
        p.append(ring(m["warn"], y, -0.042, 0.0195, 0.008, verts=16))
    p.append(ring(m["cross"], -0.008, -0.042, 0.0195, 0.01, verts=16))
    p.append(tb(m["steel"], (0, 0.04, -0.042), (0, 0.055, -0.05), 0.004, verts=8))
    for sx in (-1, 1):                                                                    # its clamps
        p.append(bx(m["dark"], (sx * 0.016, -0.03, -0.028), (0.006, 0.012, 0.016), 0.0015))
        p.append(bx(m["dark"], (sx * 0.016, 0.025, -0.028), (0.006, 0.012, 0.016), 0.0015))
    # landing skids
    for sx in (-1, 1):
        for y in (-0.05, 0.05):
            p.append(tb(m["black"], (sx * 0.05, y, -0.02), (sx * 0.06, y, -0.07), 0.004, verts=6))
        p.append(tb(m["rubber"], (sx * 0.06, -0.07, -0.07), (sx * 0.06, 0.07, -0.07), 0.005, verts=8))
    return p


def arm(m, sx, sy):
    """One arm out to a corner: a tapered boom, the motor, the guard ring and its struts."""
    p = []
    hub = Vector((sx * ARM, sy * ARM, 0))
    root = Vector((sx * 0.05, sy * 0.06, 0.005))
    d = (hub - root).normalized()
    p.append(tb(m["shell2"], root, hub - d * 0.012, 0.011, verts=8, r2=0.008))
    p.append(tb(m["dark"], root + d * 0.02, root + d * 0.03, 0.0125, verts=8))            # boom clamp
    # the motor: a can with cooling ribs, a cap
    p.append(tb(m["dark"], hub + Vector((0, 0, -0.016)), hub + Vector((0, 0, 0.022)), 0.014, verts=16))
    p.append(tb(m["steel"], hub + Vector((0, 0, 0.012)), hub + Vector((0, 0, 0.024)), 0.0155, verts=16))
    p.append(tb(m["black"], hub + Vector((0, 0, -0.02)), hub + Vector((0, 0, -0.016)), 0.01, verts=12))
    # nav light under the outer end: red left, green right (as on an aircraft)
    p.append(sphere(m["red"] if sx < 0 else m["green"], hub + Vector((sx * 0.006, sy * 0.006, -0.022)), 0.0045, seg=8, rings=5))
    # the guard ring round the propeller, held by three struts
    p.append(torus(m["shell2"], (hub.x, hub.y, HUB_Z - 0.002), GUARD_R + 0.004, 0.0045, seg=28))
    p.append(torus(m["warn"], (hub.x, hub.y, HUB_Z + 0.003), GUARD_R + 0.004, 0.0022, seg=28))
    for k in range(3):
        a = math.atan2(sy, sx) + (k - 1) * 2.0
        o = hub + Vector((math.cos(a), math.sin(a), 0)) * (GUARD_R + 0.002)
        p.append(tb(m["dark"], hub + Vector((math.cos(a), math.sin(a), 0)) * 0.012 + Vector((0, 0, -0.012)),
                    o + Vector((0, 0, HUB_Z - 0.006)), 0.0028, verts=6))
    return p


def prop(m, sx, sy, name):
    """A two-blade propeller with twisted blades, origin at the hub (the game spins it about Z)."""
    p = [tb(m["steel"], (0, 0, -0.004), (0, 0, 0.006), 0.007, verts=12),
         smooth(sphere(m["steel"], (0, 0, 0.006), 0.0055, seg=10, rings=6))]
    for s in (-1, 1):
        # blade: three twisted plates, wider in the middle, a yellow tip
        for i, (r0, r1, w, tw) in enumerate([(0.006, 0.03, 0.016, 0.42), (0.03, 0.058, 0.019, 0.3), (0.058, PROP_R - 0.008, 0.014, 0.2)]):
            c = Vector((s * (r0 + r1) / 2, 0, 0))
            p.append(bx(m["blade"], c, (r1 - r0, w, 0.0028), 0.0008, rot=(s * tw, 0, 0)))
        p.append(bx(m["tip"], (s * (PROP_R - 0.004), 0, 0), (0.008, 0.013, 0.003), 0.0008, rot=(s * 0.2, 0, 0)))
    o = join(p, name)
    o.location = (sx * ARM, sy * ARM, HUB_Z)
    o.rotation_euler = (0, 0, 0.6 * sx * sy)      # not all four in line on the still picture
    return o


def build():
    reset()
    m = mats()
    parts = body(m)
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts += arm(m, sx, sy)
    parts.append(tb(m["lens"], (0, 0.112, -0.03), (0, 0.115, -0.03), 0.0135, verts=16))
    b = join(parts, "Body")
    e = smooth(sphere(m["eye"], (0, 0.113, -0.03), 0.011, seg=16, rings=10))      # alone: the game recolours it
    e.name = "Eye"
    e.data.name = "Eye"
    props = []
    for sx, sy, n in ((-1, 1, "Prop_FL"), (1, 1, "Prop_FR"), (-1, -1, "Prop_BL"), (1, -1, "Prop_BR")):
        props.append(prop(m, sx, sy, n))
    return [b, e] + props


if __name__ == "__main__":
    objs = build()
    os.makedirs(OUTDIR, exist_ok=True)
    export_glb(os.path.join(OUTDIR, "guard_drone.glb"), objs)
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs)
    print("guard_drone.glb triangles", tris)
    if "--preview" in sys.argv:
        out = sys.argv[sys.argv.index("--preview") + 1]
        preview(out, target=(0, 0, 0), dist=0.75, angle=0.7, height=0.05, res=(700, 600))
        preview(out.replace(".png", "_zpredu.png"), target=(0, 0, 0), dist=0.6, angle=0.25, height=-0.45, res=(700, 600))
