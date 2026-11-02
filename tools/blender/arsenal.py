"""Enemy Beyond arsenal (own designs): shotgun, magnum, autocannon, minigun,
rocket launcher, stun baton, knife, smoke grenade, proximity mine - and
first-person hands for every weapon. Muzzle +Y, origin at the right-hand grip."""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from common import *
from mathutils import Vector

OUTDIR = sys.argv[-1]
PI2 = math.pi / 2

def M():
    return dict(
        steel=mat("Steel", (0.20, 0.21, 0.22), rough=0.45),
        dark=mat("Blackened", (0.06, 0.06, 0.065), rough=0.6),
        poly=mat("Polymer", (0.13, 0.14, 0.12), rough=0.85),
        wood=mat("Wood", (0.30, 0.17, 0.08), rough=0.8),
        olive=mat("OliveDrab", (0.20, 0.23, 0.14), rough=0.8),
        brass=mat("Brass", (0.55, 0.42, 0.18), rough=0.4),
        chrome=mat("Chrome", (0.5, 0.52, 0.55), rough=0.2),
        blue=mat("ArcBlue", (0.35, 0.6, 1.0), emit=4.0),
        red=mat("LedRed", (1.0, 0.1, 0.05), emit=5.0),
        warn=mat("WarnYellow", (0.75, 0.6, 0.1)),
        grey=mat("SmokeGrey", (0.45, 0.46, 0.44)),
    )

def tube(m, a, b, r, verts=8, r2=None):
    a = Vector(a); b = Vector(b); d = b - a
    o = cyl(m, (0, 0, 0), r, d.length, verts=verts, r2=r2)
    o.rotation_mode = 'QUATERNION'
    o.rotation_quaternion = d.normalized().to_track_quat('Z', 'Y')
    o.location = (a + b) / 2
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return o

def save(parts, name, extra=None):
    o = join(parts, name)
    objs = [o] + (extra or [])
    export_glb(os.path.join(OUTDIR, name.lower() + ".glb"), objs)
    return o

def shotgun():
    reset(); m = M(); p = []
    p.append(box(m["steel"], (0, 0.05, 0.03), (0.05, 0.22, 0.07)))                # receiver
    p.append(tube(m["dark"], (0, 0.15, 0.05), (0, 0.72, 0.05), 0.016))           # barrel
    p.append(tube(m["dark"], (0, 0.15, 0.015), (0, 0.66, 0.015), 0.014))          # magazine tube
    p.append(box(m["wood"], (0, 0.42, 0.015), (0.05, 0.16, 0.05)))                # pump
    for i in range(5):
        p.append(box(m["dark"], (0, 0.36 + i * 0.03, -0.012), (0.052, 0.008, 0.005)))
    p.append(box(m["dark"], (0, 0.7, 0.07), (0.008, 0.01, 0.012)))                # bead
    p.append(box(m["wood"], (0, -0.02, -0.04), (0.04, 0.05, 0.09), rot=(-0.35, 0, 0)))
    p.append(box(m["wood"], (0, -0.2, -0.0), (0.045, 0.3, 0.07), rot=(0.12, 0, 0)))
    p.append(box(m["dark"], (0, -0.35, -0.02), (0.047, 0.015, 0.11)))
    p.append(box(m["dark"], (0, 0.04, -0.012), (0.01, 0.05, 0.008)))
    p.append(box(m["brass"], (0.026, 0.08, 0.03), (0.003, 0.05, 0.02)))           # ejection port shell
    save(p, "Shotgun")

def magnum():
    """Top-break revolver: the barrel with the cylinder tips down on a hinge at the
    front of the frame (pivot = origin of "Barrel"), exposing the chambers."""
    reset(); m = M(); p = []
    p.append(box(m["chrome"], (0, 0.012, 0.035), (0.03, 0.045, 0.04)))            # frame (rear)
    p.append(box(m["chrome"], (0, 0.055, 0.017), (0.026, 0.04, 0.006)))           # lower strap to the hinge
    p.append(box(m["wood"], (0, -0.01, -0.035), (0.028, 0.04, 0.09), rot=(-0.35, 0, 0)))
    p.append(box(m["chrome"], (0, -0.02, 0.06), (0.01, 0.015, 0.015), rot=(0.6, 0, 0)))  # hammer
    p.append(box(m["dark"], (0, 0.03, 0.002), (0.008, 0.035, 0.006)))
    frame = join(p, "Magnum")
    b = [cyl(m["chrome"], (0, 0.06, 0.035), 0.022, 0.05, verts=6, rot=(PI2, 0, 0))]   # cylinder
    for i in range(6):
        a = i / 6 * math.tau
        b.append(cyl(m["brass"], (math.cos(a) * 0.012, 0.034, 0.035 + math.sin(a) * 0.012), 0.0045, 0.003, verts=5, rot=(PI2, 0, 0)))
    b.append(tube(m["chrome"], (0, 0.08, 0.045), (0, 0.27, 0.045), 0.009))       # barrel
    b.append(box(m["chrome"], (0, 0.15, 0.056), (0.012, 0.23, 0.01)))            # top rib (latch at the back)
    b.append(box(m["dark"], (0, 0.26, 0.064), (0.004, 0.008, 0.01)))
    b.append(box(m["chrome"], (0, 0.06, 0.017), (0.024, 0.05, 0.006)))           # hinge lug
    barrel = join(b, "Barrel")
    bpy.ops.object.select_all(action='DESELECT')
    barrel.select_set(True)
    bpy.context.view_layer.objects.active = barrel
    bpy.context.scene.cursor.location = (0, 0.078, 0.016)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    export_glb(os.path.join(OUTDIR, "magnum.glb"), [frame, barrel])
    # one round (loaded by hand, and the empties that fall out)
    reset(); m = M()
    r = [cyl(m["brass"], (0, 0, 0), 0.0045, 0.03, verts=6, rot=(PI2, 0, 0)), cyl(m["chrome"], (0, 0.017, 0), 0.0035, 0.006, verts=6, rot=(PI2, 0, 0), r2=0.001)]
    export_glb(os.path.join(OUTDIR, "round.glb"), [join(r, "Round")])

def autocannon():
    reset(); m = M(); p = []
    p.append(box(m["olive"], (0, 0.15, 0.06), (0.11, 0.55, 0.14)))                # body
    p.append(tube(m["dark"], (0, 0.42, 0.07), (0, 1.15, 0.07), 0.028))            # barrel
    p.append(tube(m["dark"], (0, 1.1, 0.07), (0, 1.2, 0.07), 0.042, verts=6))      # brake
    for i in range(4):
        p.append(tube(m["olive"], (0, 0.5 + i * 0.12, 0.07), (0, 0.54 + i * 0.12, 0.07), 0.04))   # cooling rings
    p.append(box(m["dark"], (-0.09, 0.2, 0.04), (0.08, 0.18, 0.16)))              # side box magazine
    p.append(box(m["warn"], (-0.131, 0.2, 0.08), (0.002, 0.12, 0.02)))
    p.append(box(m["dark"], (0, 0.15, 0.17), (0.025, 0.3, 0.05)))                 # carry handle
    p.append(box(m["dark"], (0, 0.03, 0.16), (0.025, 0.03, 0.08)))
    p.append(box(m["dark"], (0, 0.28, 0.16), (0.025, 0.03, 0.08)))
    p.append(box(m["poly"], (0, -0.005, -0.06), (0.04, 0.05, 0.12), rot=(-0.3, 0, 0)))   # grip
    p.append(box(m["poly"], (0, 0.42, -0.04), (0.045, 0.06, 0.1)))                # fore grip
    p.append(box(m["poly"], (0, -0.2, 0.05), (0.06, 0.25, 0.1)))                  # stock
    p.append(box(m["dark"], (0, -0.33, 0.05), (0.065, 0.02, 0.14)))
    save(p, "Autocannon")

def minigun():
    reset(); m = M(); p = []
    p.append(cyl(m["dark"], (0, 0.05, 0.05), 0.07, 0.22, verts=10, rot=(PI2, 0, 0)))  # motor housing
    p.append(box(m["olive"], (0, -0.12, 0.03), (0.12, 0.16, 0.12)))               # rear body
    p.append(box(m["dark"], (0, -0.0, 0.16), (0.03, 0.3, 0.03)))                  # top handle
    p.append(box(m["dark"], (0, -0.12, 0.12), (0.03, 0.03, 0.08)))
    p.append(box(m["dark"], (0, 0.12, 0.12), (0.03, 0.03, 0.08)))
    p.append(box(m["poly"], (0, -0.02, -0.06), (0.04, 0.05, 0.12), rot=(-0.3, 0, 0)))
    p.append(box(m["olive"], (-0.12, -0.05, -0.04), (0.1, 0.18, 0.16)))           # ammo box
    p.append(tube(m["brass"], (-0.08, 0.0, 0.03), (-0.03, 0.06, 0.04), 0.012, verts=4))   # belt
    body = join(p, "Minigun")
    # spinning barrel cluster is a separate mesh (the game spins it)
    q = []
    for i in range(6):
        a = i / 6 * math.tau
        q.append(tube(m["steel"], (math.cos(a) * 0.035, 0.16, 0.05 + math.sin(a) * 0.035),
                      (math.cos(a) * 0.035, 0.85, 0.05 + math.sin(a) * 0.035), 0.012, verts=6))
    for y in (0.3, 0.6, 0.83):
        q.append(cyl(m["dark"], (0, y, 0.05), 0.055, 0.025, verts=8, rot=(PI2, 0, 0)))
    for o in q:
        for v in o.data.vertices:
            v.co.z -= 0.05      # spin axis through the origin of this mesh
    barrels = join(q, "MinigunBarrels")
    barrels.location = (0, 0, 0.05)
    export_glb(os.path.join(OUTDIR, "minigun.glb"), [body, barrels])

def rocket():
    reset(); m = M(); p = []
    p.append(tube(m["olive"], (0, -0.45, 0.07), (0, 0.75, 0.07), 0.055, verts=10))
    p.append(tube(m["dark"], (0, 0.72, 0.07), (0, 0.78, 0.07), 0.065, verts=10))
    p.append(tube(m["dark"], (0, -0.5, 0.07), (0, -0.43, 0.07), 0.068, verts=10))
    p.append(box(m["warn"], (0, 0.3, 0.127), (0.04, 0.3, 0.004)))
    p.append(box(m["dark"], (0.07, 0.2, 0.12), (0.03, 0.1, 0.06)))                # sight
    p.append(box(m["poly"], (0, 0.0, -0.03), (0.035, 0.045, 0.1), rot=(-0.25, 0, 0)))
    p.append(box(m["poly"], (0, 0.3, -0.02), (0.035, 0.045, 0.09)))
    body = join(p, "Rocket_launcher")
    w = [cyl(m["olive"], (0, 0.84, 0.07), 0.045, 0.14, verts=8, rot=(PI2, 0, 0)),
         cyl(m["dark"], (0, 0.96, 0.07), 0.045, 0.1, verts=8, r2=0.0, rot=(-PI2, 0, 0))]
    warhead = join(w, "Warhead")
    export_glb(os.path.join(OUTDIR, "rocket_launcher.glb"), [body, warhead])
    # the flying rocket on its own
    reset(); m = M()
    r = [tube(m["olive"], (0, -0.25, 0), (0, 0.2, 0), 0.04, verts=8),
         cyl(m["dark"], (0, 0.27, 0), 0.04, 0.14, verts=8, r2=0.0, rot=(-PI2, 0, 0))]
    for i in range(4):
        a = i / 4 * math.tau
        r.append(box(m["dark"], (math.cos(a) * 0.05, -0.22, math.sin(a) * 0.05), (0.004 + abs(math.sin(a)) * 0.05, 0.08, 0.004 + abs(math.cos(a)) * 0.05)))
    save(r, "Rocket")

def baton():
    reset(); m = M(); p = []
    p.append(tube(m["poly"], (0, -0.06, 0), (0, 0.06, 0), 0.018))
    p.append(tube(m["dark"], (0, 0.06, 0), (0, 0.42, 0), 0.013))
    p.append(box(m["warn"], (0, 0.03, 0.02), (0.012, 0.03, 0.008)))
    for x in (-0.012, 0.012):
        p.append(box(m["chrome"], (x, 0.45, 0), (0.005, 0.05, 0.005)))
    p.append(box(m["blue"], (0, 0.46, 0), (0.016, 0.01, 0.01)))
    save(p, "Stun_baton")

def knife():
    reset(); m = M(); p = []
    p.append(box(m["poly"], (0, 0.0, 0), (0.025, 0.11, 0.03)))
    p.append(box(m["dark"], (0, 0.065, 0), (0.05, 0.012, 0.035)))
    blade = box(m["chrome"], (0, 0.15, 0.003), (0.004, 0.17, 0.03))
    for v in blade.data.vertices:            # taper to a point
        if v.co.y > 0.2:
            v.co.z = 0.012 if v.co.z > 0.003 else -0.003
    p.append(blade)
    p.append(box(m["dark"], (0, 0.14, 0.02), (0.005, 0.12, 0.004)))
    save(p, "Knife")

def smoke():
    reset(); m = M()
    save([cyl(m["grey"], (0, 0, 0.06), 0.03, 0.12, verts=8),
          cyl(m["warn"], (0, 0, 0.09), 0.031, 0.02, verts=8),
          box(m["dark"], (0, 0, 0.13), (0.015, 0.015, 0.02)),
          box(m["dark"], (0.022, 0, 0.11), (0.006, 0.01, 0.05))], "Smoke_grenade")

def mine():
    reset(); m = M()
    save([cyl(m["olive"], (0, 0, 0.025), 0.1, 0.05, verts=10),
          cyl(m["dark"], (0, 0, 0.055), 0.03, 0.015, verts=8),
          box(m["red"], (0.05, 0, 0.052), (0.01, 0.01, 0.006))], "Mine")

def plasma_rifle():
    """Built by the base engineers from a captured plasma pistol: a human stock
    and grip around an alien core."""
    reset(); m = M()
    core = mat("PlasmaCore", (0.35, 1.0, 0.45), emit=4.0)
    shell = mat("AlienShell", (0.3, 0.33, 0.3), rough=0.35)
    p = []
    p.append(box(m["dark"], (0, 0.05, 0.03), (0.05, 0.3, 0.07)))
    p.append(cyl(shell, (0, 0.35, 0.04), 0.035, 0.36, verts=8, rot=(PI2, 0, 0), r2=0.02))
    for i in range(3):
        p.append(box(core, (0, 0.24 + i * 0.09, 0.077), (0.012, 0.05, 0.006)))
    p.append(sphere(core, (0, 0.55, 0.04), 0.022, seg=8, rings=5))
    p.append(box(shell, (0, 0.12, 0.09), (0.03, 0.12, 0.03)))
    p.append(box(m["poly"], (0, -0.005, -0.045), (0.035, 0.045, 0.1), rot=(-0.3, 0, 0)))
    p.append(box(core, (0, 0.11, -0.04), (0.03, 0.05, 0.06)))                 # cell
    p.append(box(m["poly"], (0, -0.19, 0.02), (0.04, 0.22, 0.06)))
    p.append(box(m["dark"], (0, -0.3, 0.0), (0.045, 0.02, 0.11)))
    save(p, "Plasma_rifle")

def handheld():
    """Small things that can be held in one hand."""
    reset(); m = M()
    save([box(m["poly"], (0, 0.04, 0.0), (0.07, 0.13, 0.035)),
          box(mat("ScannerScreen", (0.2, 0.9, 0.4), emit=2.0), (0, 0.05, 0.018), (0.05, 0.06, 0.002)),
          box(m["dark"], (0, -0.04, -0.01), (0.03, 0.06, 0.03)),
          cyl(m["dark"], (0.025, 0.12, 0.0), 0.006, 0.04, verts=4, rot=(PI2, 0, 0))], "Scanner")
    reset(); m = M()
    save([sphere(m["olive"], (0, 0.02, 0.0), 0.035, seg=8, rings=5, scale=(1, 1, 1.2)),
          box(m["steel"], (0, 0.02, 0.045), (0.02, 0.02, 0.03)),
          box(m["steel"], (0.015, 0.0, 0.035), (0.006, 0.05, 0.008))], "Grenade")
    reset(); m = M()
    save([cyl(mat("FlareRed", (0.7, 0.12, 0.08)), (0, 0.06, 0), 0.016, 0.2, verts=6, rot=(PI2, 0, 0)),
          cyl(m["dark"], (0, 0.165, 0), 0.017, 0.02, verts=6, rot=(PI2, 0, 0))], "Flare")
    reset(); m = M()
    wh = mat("White", (0.9, 0.9, 0.9))
    save([box(mat("MedRed", (0.6, 0.08, 0.06)), (0, 0.04, 0.0), (0.12, 0.08, 0.1)),
          box(wh, (0, 0.04, 0.051), (0.06, 0.015, 0.002)), box(wh, (0, 0.04, 0.051), (0.015, 0.06, 0.002))], "Medkit")

def single_hand(side):
    """One gloved hand + forearm holding something at the origin (right or left)."""
    reset()
    glove = mat("Glove", (0.07, 0.07, 0.065), rough=0.8)
    sleeve = mat("Sleeve", (0.20, 0.22, 0.15))
    skin = mat("Wrist", (0.62, 0.47, 0.38))
    sx = 1 if side == "r" else -1
    p = [box(glove, (0, -0.01, -0.02), (0.065, 0.08, 0.09), rot=(-0.3, 0, 0)),
         box(glove, (0.03 * sx, 0.02, 0.02), (0.02, 0.05, 0.02)),
         tube(skin, (0.01 * sx, -0.05, -0.04), (0.03 * sx, -0.1, -0.07), 0.033),
         tube(sleeve, (0.03 * sx, -0.1, -0.07), (0.12 * sx, -0.42, -0.22), 0.05)]
    o = join(p, "Hand_" + side)
    export_glb(os.path.join(OUTDIR, "hand_%s.glb" % side), [o])

# ---- hands: right hand on the grip, left hand on the support point ------------------
GRIPS = {
    # id: (right grip pos, left support pos or None, left forearm end)
    "rifle": ((0, -0.01, -0.04), (0, 0.36, -0.005)),
    "pistol": ((0, -0.005, -0.04), (-0.035, 0.0, -0.06)),
    "shotgun": ((0, -0.02, -0.04), (0, 0.42, -0.02)),
    "magnum": ((0, -0.01, -0.035), (-0.035, 0.0, -0.055)),
    "autocannon": ((0, -0.005, -0.06), (0, 0.42, -0.06)),
    "minigun": ((0, -0.02, -0.06), (0, 0.0, 0.17)),
    "rocket_launcher": ((0, 0.0, -0.03), (0, 0.3, -0.03)),
    "plasma_rifle": ((0, -0.01, -0.04), (0, 0.33, 0.0)),
    "stun_baton": ((0, 0.0, 0.0), None),
    "knife": ((0, 0.0, 0.0), None),
}

def hands(kind):
    reset()
    glove = mat("Glove", (0.07, 0.07, 0.065), rough=0.8)
    sleeve = mat("Sleeve", (0.20, 0.22, 0.15))
    skin = mat("Wrist", (0.62, 0.47, 0.38))
    r, l = GRIPS[kind]
    p = []
    r = Vector(r)
    p.append(box(glove, r, (0.065, 0.075, 0.1), rot=(-0.3, 0, 0)))
    p.append(box(glove, r + Vector((0.03, 0.03, 0.03)), (0.02, 0.05, 0.02)))
    p.append(tube(skin, r + Vector((0.01, -0.04, -0.03)), r + Vector((0.03, -0.09, -0.06)), 0.033))
    p.append(tube(sleeve, r + Vector((0.03, -0.09, -0.06)), r + Vector((0.1, -0.42, -0.2)), 0.05))
    if l is not None:
        l = Vector(l)
        p.append(box(glove, l, (0.08, 0.1, 0.065)))
        p.append(tube(skin, l + Vector((-0.02, -0.04, -0.03)), l + Vector((-0.04, -0.09, -0.06)), 0.033))
        p.append(tube(sleeve, l + Vector((-0.04, -0.09, -0.06)), l + Vector((-0.24, -0.4, -0.22)), 0.05))
    o = join(p, "Hands_" + kind)
    export_glb(os.path.join(OUTDIR, "hands_%s.glb" % kind), [o])

for f in (shotgun, magnum, autocannon, minigun, rocket, baton, knife, smoke, mine, handheld, plasma_rifle):
    f()
TWO_HANDED = ["rifle", "shotgun", "autocannon", "minigun", "rocket_launcher", "plasma_rifle"]
for k in TWO_HANDED:
    hands(k)
single_hand("r")
single_hand("l")

if "--gallery" in sys.argv:
    reset()
    names = ["shotgun", "magnum", "autocannon", "minigun", "rocket_launcher", "stun_baton", "knife", "smoke_grenade", "mine"]
    for i, n in enumerate(names):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=os.path.join(OUTDIR, n + ".glb"))
        for o in set(bpy.data.objects) - before:
            if o.parent is None:
                o.rotation_mode = 'XYZ'
                o.location = ((i % 3) * 1.5 - 1.5 - 0.4, 0, -(i // 3) * 0.55)
                o.rotation_euler = (0, 0, -PI2)
    preview(sys.argv[sys.argv.index("--gallery") + 1], target=(0, 0, -0.55), dist=4.2, angle=0.0, height=0.5, res=(960, 540))
