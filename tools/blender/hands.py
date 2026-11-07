"""Enemy Beyond 0.56 - the mercenary's hands as you see them (first person), for every gun and the single
hands that hold small things. Same grip points as before (the guns kept theirs): the right hand round the
pistol grip with the index finger along the frame by the trigger, the left one under the handguard
(or round the right hand on a pistol). Gloves with knuckle pads and finger seams, a cuff, the wrist, the
sleeve (material "Sleeve": the game paints the camouflage on it), a watch on the left wrist.
Muzzle +Y, origin at the right-hand grip (as the guns).
Run: python3 tools/blender/hands.py <outdir> [--only rifle,pistol] [--preview out.png]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from kit import *
from mathutils import Vector, Matrix

ARGS = [a for a in sys.argv[1:] if not a.startswith("--") and not a.endswith(".png") and "," not in a]
OUTDIR = ARGS[0] if ARGS else "."
ONLY = sys.argv[sys.argv.index("--only") + 1].split(",") if "--only" in sys.argv else []

# id: (right grip pos, left support pos or None) - the same points as the old hands
GRIPS = {
    "rifle": ((0, -0.01, -0.04), (0, 0.36, -0.005)),
    "pistol": ((0, -0.005, -0.04), (-0.035, 0.0, -0.06)),
    "shotgun": ((0, -0.02, -0.04), (0, 0.42, -0.02)),
    "magnum": ((0, -0.01, -0.035), (-0.035, 0.0, -0.055)),
    "autocannon": ((0, -0.005, -0.06), (0, 0.42, -0.06)),
    "minigun": ((0, -0.02, -0.06), (0, 0.0, 0.17)),
    "rocket_launcher": ((0, 0.0, -0.03), (0, 0.3, -0.03)),
    "plasma_rifle": ((0, -0.01, -0.04), (0, 0.33, 0.0)),
    "sniper": ((0, -0.015, -0.05), (0, 0.4, 0.0)),
    "laser_rifle": ((0, -0.01, -0.045), (0, 0.3, -0.04)),
    "laser_cannon": ((0, 0.0, -0.07), (0, 0.42, -0.07)),
    "laser_pistol": ((0, -0.005, -0.04), (-0.035, 0.0, -0.06)),
    "laser_minigun": ((0, -0.02, -0.06), (0, 0.0, 0.17)),
    "plasma_minigun": ((0, -0.02, -0.06), (0, 0.0, 0.17)),
    "plasma_pistol": ((0, -0.005, -0.04), (-0.035, 0.0, -0.06)),
    "plasma_cannon": ((0, 0.0, -0.07), (0, 0.42, -0.07)),
}
PISTOLS = ("pistol", "magnum", "laser_pistol", "plasma_pistol")

def M():
    return dict(
        glove=mat2("Glove", (0.07, 0.07, 0.065), 0.8), pad=mat2("GlovePad", (0.13, 0.13, 0.12), 0.7),
        seam=mat2("GloveSeam", (0.03, 0.03, 0.03), 0.9), cuff=mat2("GloveCuff", (0.1, 0.1, 0.095), 0.75),
        skin=mat2("Wrist", (0.62, 0.47, 0.38), 0.7), sleeve=mat2("Sleeve", (0.2, 0.22, 0.15), 0.9),
        sleeve2=mat2("SleeveCuff", (0.16, 0.18, 0.12), 0.9), watch=mat2("Watch", (0.15, 0.15, 0.16), 0.3, 0.6),
        dial=mat2("WatchDial", (0.3, 0.9, 0.5), emit=1.5),
    )

def xf(pts, origin, rot):
    """Points from a hand's own frame (origin, Euler XYZ) into the gun's."""
    R = Matrix.Rotation(rot[0], 3, 'X') @ Matrix.Rotation(rot[1], 3, 'Y') @ Matrix.Rotation(rot[2], 3, 'Z')
    return [Vector(origin) + R @ Vector(p) for p in pts]

def finger(m, pts, w, t, out):
    """A finger as a chain of short blocks through pts (knuckle to tip)."""
    for a, b in zip(pts[:-1], pts[1:]):
        out.append(beam(m, a, b, w, t))
    out.append(ball(m, pts[-1], w * 0.55, seg=6, rings=4))

def fist(m, at, rot, out, side=1, trigger=True):
    """A gloved hand round a grip: the grip runs along the hand's local z, its front strap is +y.
    side = 1 right hand (back of the hand on +x), -1 a left hand (mirrored)."""
    s = side
    P = lambda pts: xf([(x * s, y, z) for (x, y, z) in pts], at, rot)
    # the back of the hand and the palm round the back strap
    back = P([(0.024, -0.006, 0.0)])[0]
    o = bx(m["glove"], (0, 0, 0), (0.022, 0.075, 0.088), 0.006)
    o.rotation_euler = rot
    o.location = back
    apply_xf(o)
    out.append(o)
    palm = bx(m["glove"], (0, 0, 0), (0.045, 0.026, 0.085), 0.006)
    palm.rotation_euler = rot
    palm.location = P([(0.004, -0.03, -0.004)])[0]
    apply_xf(palm)
    out.append(palm)
    # the knuckle pad and a seam across the back
    kp = bx(m["pad"], (0, 0, 0), (0.008, 0.03, 0.075), 0.003)
    kp.rotation_euler = rot
    kp.location = P([(0.036, 0.018, -0.002)])[0]
    apply_xf(kp)
    out.append(kp)
    sm = bx(m["seam"], (0, 0, 0), (0.002, 0.05, 0.003), 0.0)
    sm.rotation_euler = rot
    sm.location = P([(0.0355, -0.01, 0.018)])[0]
    apply_xf(sm)
    out.append(sm)
    # three (or four) fingers wrapped round the front strap, one under the other
    rows = (0.0, -0.023, -0.046) if trigger else (0.022, 0.0, -0.023, -0.046)
    for k, z in enumerate(rows):
        r0 = 0.017 - k * 0.001
        finger(m["glove"], P([(0.03, 0.012, z), (0.026, 0.034, z - 0.002), (0.0, 0.044, z - 0.004), (-0.022, 0.03, z - 0.004), (-0.026, 0.012, z - 0.003)]),
               r0, r0, out)
    if trigger:
        # the index finger along the frame, its tip by the trigger guard
        finger(m["glove"], P([(0.03, 0.012, 0.024), (0.024, 0.04, 0.032), (0.02, 0.068, 0.034), (0.016, 0.088, 0.032)]), 0.016, 0.015, out)
    # the thumb over the top, along the other side
    finger(m["glove"], P([(0.012, -0.028, 0.03), (-0.008, -0.01, 0.042), (-0.024, 0.014, 0.044), (-0.026, 0.036, 0.04)]), 0.019, 0.017, out)

def support(m, at, out, rot=(0, 0, 0)):
    """The left hand under a handguard (running along +y): palm below, fingers up the right side,
    the thumb along the left side."""
    P = lambda pts: xf(pts, at, rot)
    o = bx(m["glove"], (0, 0, 0), (0.06, 0.085, 0.022), 0.006)
    o.location = P([(0.0, 0.0, -0.03)])[0]
    o.rotation_euler = rot
    apply_xf(o)
    out.append(o)
    kp = bx(m["pad"], (0, 0, 0), (0.03, 0.08, 0.008), 0.003)
    kp.location = P([(0.0, 0.0, -0.044)])[0]
    apply_xf(kp)
    out.append(kp)
    for k, y in enumerate((-0.03, -0.01, 0.01, 0.03)):
        finger(m["glove"], P([(0.028, y, -0.028), (0.036, y + 0.002, -0.006), (0.032, y + 0.003, 0.014), (0.018, y + 0.003, 0.026)]), 0.016, 0.016, out)
    finger(m["glove"], P([(-0.028, -0.032, -0.026), (-0.036, -0.005, -0.008), (-0.032, 0.022, 0.008), (-0.024, 0.04, 0.016)]), 0.019, 0.017, out)

def arm(m, wrist, elbow, out, watch=False):
    """The cuff of the glove, a strip of wrist, the sleeve with its rolled cuff, back towards the elbow."""
    wrist = Vector(wrist); elbow = Vector(elbow)
    d = (elbow - wrist).normalized()
    c0 = wrist
    c1 = wrist + d * 0.035
    out.append(tb(m["cuff"], c0 - d * 0.012, c1, 0.036, 10))
    s0 = c1 + d * 0.025
    out.append(tb(m["skin"], c1, s0, 0.032, 10))
    if watch:
        out.append(tb(m["watch"], c1 + d * 0.004, c1 + d * 0.02, 0.035, 10))
        side = d.cross(Vector((0, 0, 1))).normalized()
        out.append(disc(m["dial"], c1 + d * 0.012 + side * 0.033, 0.012, 0.004, axis='x', verts=10))
    out.append(tb(m["sleeve2"], s0, s0 + d * 0.05, 0.05, 10))          # the rolled cuff
    out.append(tb(m["sleeve"], s0 + d * 0.045, elbow, 0.046, 10, r2=0.056))
    # a fold or two in the sleeve
    for t in (0.35, 0.65):
        p = s0.lerp(elbow, t)
        out.append(tb(m["sleeve2"], p, p + d * 0.012, 0.051 + 0.006 * t, 10))

def hands(kind):
    reset(); m = M(); p = []
    r, l = GRIPS[kind]
    r = Vector(r)
    fist(m, r, (-0.3, 0, 0), p, 1, True)
    arm(m, r + Vector((0.022, -0.045, -0.035)), r + Vector((0.1, -0.42, -0.22)), p)
    if l is not None:
        l = Vector(l)
        if kind in PISTOLS:
            # the left hand round the right one (a pistol held in both hands)
            fist(m, l + Vector((0.0, 0.0, 0.005)), (-0.25, 0, 0.3), p, -1, False)
            arm(m, l + Vector((-0.03, -0.045, -0.04)), l + Vector((-0.25, -0.38, -0.24)), p, watch=True)
        else:
            support(m, l, p)
            arm(m, l + Vector((-0.012, -0.045, -0.04)), l + Vector((-0.24, -0.4, -0.22)), p, watch=True)
    o = join(p, "Hands_" + kind)
    export_glb(os.path.join(OUTDIR, "hands_%s.glb" % kind), [o])

def single_hand(side):
    """One gloved hand + forearm holding something at the origin (a radio, a grenade, a knife)."""
    reset(); m = M(); p = []
    s = 1 if side == "r" else -1
    fist(m, Vector((0, -0.005, -0.02)), (-0.3, 0, 0), p, s, False)
    arm(m, Vector((0.022 * s, -0.05, -0.05)), Vector((0.12 * s, -0.42, -0.22)), p, watch=(side == "l"))
    o = join(p, "Hand_" + side)
    export_glb(os.path.join(OUTDIR, "hand_%s.glb" % side), [o])

for k in GRIPS:
    if not ONLY or k in ONLY:
        hands(k)
        print("built", k)
for sd in ("r", "l"):
    if not ONLY or ("hand_" + sd) in ONLY:
        single_hand(sd)
        print("built hand_" + sd)

if "--preview" in sys.argv:
    out = sys.argv[sys.argv.index("--preview") + 1]
    k = ONLY[0] if ONLY else "rifle"
    reset()
    bpy.ops.import_scene.gltf(filepath=os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models", "%s.glb" % k))
    bpy.ops.import_scene.gltf(filepath=os.path.join(OUTDIR, "hands_%s.glb" % k))
    preview(out, target=(0, 0.15, 0.0), dist=0.75, angle=3.5, height=0.25, res=(900, 700))
