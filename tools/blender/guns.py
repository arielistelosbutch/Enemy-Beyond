"""Enemy Beyond 0.50 - the reworked arsenal (own designs, not X-COM's).
Every gun keeps the size, grip origin, muzzle point and moving pieces of the old one (the game's
animations, sights and muzzle flashes rely on them), but is built with bevelled plates, rails,
screws, vents and proper round barrels instead of a handful of boxes.
Muzzle +Y in Blender (-Z in Godot), origin = where the right hand holds the grip.
Run: python3 tools/blender/guns.py <outdir> [--only rifle,pistol] [--gallery out.png]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from common import *
from common import _finish
from mathutils import Vector

ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
OUTDIR = ARGS[0] if ARGS else "."
ONLY = []
if "--only" in sys.argv:
    ONLY = sys.argv[sys.argv.index("--only") + 1].split(",")
PI2 = math.pi / 2

# ---- materials (the game keeps the colour, and now metal and roughness too) --------------------
def mat2(name, rgb, rough=0.6, metal=0.0, emit=0.0):
    m = mat(name, rgb, emit=emit, rough=rough)
    m.node_tree.nodes.get("Principled BSDF").inputs["Metallic"].default_value = metal
    return m

def M():
    return dict(
        steel=mat2("GunSteel", (0.26, 0.27, 0.28), 0.35, 0.8),
        dark=mat2("Parkerized", (0.075, 0.075, 0.08), 0.5, 0.6),
        black=mat2("BlackPoly", (0.045, 0.045, 0.05), 0.8),
        poly=mat2("Polymer", (0.14, 0.15, 0.13), 0.85),
        tan=mat2("FdeTan", (0.42, 0.36, 0.26), 0.85),
        olive=mat2("OliveDrab", (0.21, 0.24, 0.15), 0.75),
        olive2=mat2("OliveDark", (0.15, 0.17, 0.11), 0.75),
        wood=mat2("Walnut", (0.33, 0.18, 0.08), 0.55),
        wood2=mat2("WalnutDark", (0.22, 0.11, 0.05), 0.55),
        brass=mat2("Brass", (0.62, 0.47, 0.2), 0.3, 1.0),
        chrome=mat2("Chrome", (0.62, 0.64, 0.67), 0.15, 1.0),
        rubber=mat2("Rubber", (0.03, 0.03, 0.03), 0.95),
        red=mat2("LedRed", (1.0, 0.12, 0.05), emit=5.0),
        dot=mat2("SightDot", (1.0, 0.25, 0.1), emit=3.0),
        tritium=mat2("Tritium", (0.4, 1.0, 0.45), emit=3.0),
        blue=mat2("ArcBlue", (0.35, 0.6, 1.0), emit=4.0),
        warn=mat2("WarnYellow", (0.78, 0.62, 0.12), 0.6),
        white=mat2("StencilWhite", (0.85, 0.85, 0.8), 0.7),
        grey=mat2("SmokeGrey", (0.45, 0.46, 0.44), 0.7),
        lens=mat2("LensGlass", (0.12, 0.22, 0.32), 0.05, 0.5),
    )

# ---- shape helpers -------------------------------------------------------------------------------
def _sel(o):
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o

def bev(o, w, seg=1):
    """Bevel every edge (a chamfer that catches the light)."""
    if w <= 0:
        return o
    _sel(o)
    m = o.modifiers.new("Bevel", 'BEVEL')
    m.width = w
    m.segments = seg
    m.limit_method = 'ANGLE'
    bpy.ops.object.modifier_apply(modifier="Bevel")
    return o

def smooth(o, auto=True):
    for p in o.data.polygons:
        p.use_smooth = True
    return o

def bx(m, c, s, b=0.0025, rot=(0, 0, 0), seg=1):
    """A box with chamfered edges. c = centre, s = full size."""
    o = box(m, c, s, rot=rot)
    return bev(o, min(b, min(s) * 0.3), seg)

def tb(m, a, b, r, verts=16, r2=None, sm=True):
    """A round tube from point a to point b."""
    a = Vector(a); b = Vector(b); d = b - a
    o = cyl(m, (0, 0, 0), r, max(d.length, 1e-4), verts=verts, r2=r2)
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    for v in o.data.vertices:
        v.co = q @ v.co + (a + b) / 2
    return smooth(o) if sm else o

def ty(m, y0, y1, z, r, x=0.0, verts=16, r2=None):
    """A tube along +Y (barrels)."""
    return tb(m, (x, y0, z), (x, y1, z), r, verts, r2)

def ring(m, y, z, r, w, x=0.0, verts=16):
    return ty(m, y - w / 2, y + w / 2, z, r, x, verts)

def screw(m, c, r=0.004, axis='x'):
    rot = {'x': (0, PI2, 0), 'y': (PI2, 0, 0), 'z': (0, 0, 0)}[axis]
    return smooth(cyl(m, c, r, 0.003, verts=8, rot=rot))

def rail(m, y0, y1, z, w=0.024, x=0.0, up=True, slots=None):
    """A Picatinny rail along Y on top (or under, up=False) at height z."""
    p = []
    L = y1 - y0
    s = 1 if up else -1
    p.append(bx(m, (x, (y0 + y1) / 2, z + s * 0.003), (w * 0.7, L, 0.006), 0.001))
    n = slots or max(2, int(L / 0.01))
    for i in range(n):
        y = y0 + (i + 0.5) * L / n
        p.append(bx(m, (x, y, z + s * 0.0075), (w, L / n * 0.55, 0.005), 0.0008))
    return p

def side_rail(m, y0, y1, z, x, slots=None):
    p = []
    L = y1 - y0
    sx = 1 if x > 0 else -1
    p.append(bx(m, (x, (y0 + y1) / 2, z), (0.006, L, 0.016), 0.001))
    n = slots or max(2, int(L / 0.01))
    for i in range(n):
        y = y0 + (i + 0.5) * L / n
        p.append(bx(m, (x + sx * 0.004, y, z), (0.005, L / n * 0.55, 0.022), 0.0008))
    return p

def grip(m, c, s, ang=-0.3, tex=None):
    """A pistol grip, slightly swollen in the palm, with stippled side panels."""
    p = [bx(m, c, s, 0.006, rot=(ang, 0, 0), seg=2)]
    if tex is not None:
        for sx in (1, -1):
            p.append(bx(tex, (c[0] + sx * s[0] / 2, c[1], c[2]), (0.003, s[1] * 0.7, s[2] * 0.6), 0.001, rot=(ang, 0, 0)))
    # the finger grooves on the front strap
    ca, sa = math.cos(ang), math.sin(ang)
    for k in range(3):
        dz = (k - 1) * s[2] * 0.22
        off = Vector((0, s[1] / 2 + 0.002, dz))
        off = Vector((0, off.y * ca - off.z * sa, off.y * sa + off.z * ca))
        p.append(smooth(cyl(m, (c[0], c[1] + off.y - 0.004, c[2] + off.z), s[1] * 0.09, s[0] * 0.9, verts=10, rot=(0, PI2, 0))))
    return p

def trigger(m, y, z, guard=True, l=0.05):
    """Trigger blade and the guard around it (the trigger at y, below the receiver at z)."""
    p = [bx(m, (0, y, z - 0.012), (0.006, 0.006, 0.02), 0.001, rot=(0.25, 0, 0))]
    if guard:
        p.append(bx(m, (0, y + 0.004, z - 0.026), (0.01, l, 0.005), 0.0015))
        p.append(bx(m, (0, y + l / 2 + 0.002, z - 0.015), (0.01, 0.005, 0.024), 0.0015))
    return p

def torus(m, c, R, r, rot=(0, 0, 0), seg=14):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=seg, minor_segments=6)
    return smooth(_finish(bpy.context.active_object, m, c, rot, (1, 1, 1)))

def save(parts, name, extra=None, fname=None):
    o = join(parts, name)
    export_glb(os.path.join(OUTDIR, (fname or name.lower()) + ".glb"), [o] + (extra or []))
    return o

def set_origin(o, at):
    _sel(o)
    bpy.context.scene.cursor.location = at
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.context.scene.cursor.location = (0, 0, 0)

def mag_curve(m, top, n=4, step=(0.0, 0.008, -0.032), size=(0.026, 0.05, 0.034), lip=None):
    """A curved box magazine made of slanted segments."""
    p = []
    c = Vector(top)
    for i in range(n):
        ang = 0.1 + i * 0.07
        p.append(bx(m, tuple(c), size, 0.003, rot=(ang, 0, 0)))
        if i == 0 and lip is not None:
            p.append(bx(lip, (c.x, c.y + 0.004, c.z + size[2] / 2 + 0.002), (size[0] * 0.5, size[1] * 0.55, 0.004), 0.001))
        c += Vector((step[0], step[1] + i * 0.003, step[2]))
    p.append(bx(m, tuple(c - Vector((0, 0, -0.012))), (size[0] * 1.15, size[1] * 1.1, 0.008), 0.002, rot=(0.1 + n * 0.07, 0, 0)))
    return p

# ==================================================================================================
def rifle():
    """UAI assault carbine: flat-top upper with a long rail, octagonal free-float handguard, curved
    magazine, collapsible stock on a buffer tube, compact red-dot sight."""
    reset(); m = M(); p = []
    # upper receiver
    p.append(bx(m["dark"], (0, 0.08, 0.045), (0.05, 0.26, 0.048), 0.004))
    p += rail(m["dark"], -0.04, 0.2, 0.069)
    p.append(bx(m["dark"], (0.026, 0.06, 0.042), (0.004, 0.07, 0.022), 0.001))         # ejection port cover
    p.append(bx(m["steel"], (0.027, 0.06, 0.042), (0.002, 0.05, 0.012), 0.0005))
    p.append(tb(m["dark"], (0.028, 0.0, 0.05), (0.034, 0.012, 0.05), 0.007, 10))         # forward assist
    p.append(bx(m["dark"], (0, -0.045, 0.066), (0.03, 0.02, 0.008), 0.002))             # charging handle
    p.append(bx(m["dark"], (0.017, -0.055, 0.066), (0.01, 0.012, 0.008), 0.002))
    # lower receiver and mag well
    p.append(bx(m["dark"], (0, 0.04, 0.008), (0.046, 0.2, 0.03), 0.003))
    p.append(bx(m["dark"], (0, 0.125, -0.02), (0.038, 0.06, 0.045), 0.004))
    p.append(bx(m["dark"], (0.024, 0.05, 0.012), (0.004, 0.02, 0.01), 0.001))           # selector
    for x in (0.0235, -0.0235):
        p.append(screw(m["steel"], (x, -0.02, 0.012)))
        p.append(screw(m["steel"], (x, 0.12, 0.012)))
    p += trigger(m["dark"], 0.045, 0.0)
    # handguard (eight-sided) with M-LOK slots, barrel, gas block, flash hider
    hg = cyl(m["black"], (0, 0.37, 0.042), 0.03, 0.32, verts=8, rot=(PI2, math.pi / 8, 0))   # octagon turned about its own axis (was yawed sideways)
    p.append(bev(hg, 0.002))
    for i in range(5):
        y = 0.25 + i * 0.055
        for sx in (1, -1):
            p.append(bx(m["dark"], (sx * 0.028, y, 0.04), (0.004, 0.03, 0.009), 0.001))
        p.append(bx(m["dark"], (0, y, 0.012), (0.009, 0.03, 0.004), 0.001))
    p += rail(m["black"], 0.21, 0.52, 0.07, slots=24)
    p.append(ty(m["dark"], 0.52, 0.68, 0.042, 0.0105, verts=14))
    p.append(bx(m["dark"], (0, 0.565, 0.05), (0.024, 0.022, 0.032), 0.003))              # gas block
    p.append(ty(m["steel"], 0.66, 0.725, 0.042, 0.0145, verts=12))                       # flash hider
    for k in range(4):
        a = k / 4 * math.tau + math.pi / 4
        p.append(bx(m["black"], (math.cos(a) * 0.0135, 0.705, 0.042 + math.sin(a) * 0.0135), (0.004, 0.03, 0.004), 0.0005, rot=(0, -a, 0)))
    p.append(ring(m["dark"], 0.672, 0.042, 0.016, 0.006, verts=12))
    # folding front sight (folded) and rear (folded)
    p.append(bx(m["dark"], (0, 0.49, 0.081), (0.016, 0.03, 0.008), 0.002))
    p.append(bx(m["dark"], (0, -0.025, 0.079), (0.018, 0.022, 0.008), 0.002))
    # the old front sight post the aim is set against
    p.append(bx(m["dark"], (0, 0.47, 0.072), (0.006, 0.008, 0.014), 0.001))
    # red dot: rounded body, hood, lens, the dot itself (same place as before - the aim uses it)
    p.append(bx(m["dark"], (0, 0.08, 0.087), (0.034, 0.06, 0.012), 0.002))               # mount
    body = cyl(m["dark"], (0, 0.08, 0.115), 0.022, 0.07, verts=16, rot=(PI2, 0, 0))
    p.append(smooth(bev(body, 0.003)))
    p.append(ring(m["black"], 0.115, 0.115, 0.024, 0.006))
    p.append(ring(m["black"], 0.046, 0.115, 0.024, 0.006))
    p.append(smooth(cyl(m["dark"], (0.025, 0.08, 0.115), 0.008, 0.012, verts=12, rot=(0, PI2, 0))))   # brightness knob
    p.append(smooth(cyl(m["dark"], (0, 0.08, 0.14), 0.007, 0.01, verts=12)))
    p.append(cyl(m["lens"], (0, 0.112, 0.115), 0.019, 0.002, verts=16, rot=(PI2, 0, 0)))
    p.append(box(m["dot"], (0, 0.124, 0.118), (0.006, 0.002, 0.006)))
    # pistol grip
    p += grip(m["black"], (0, -0.005, -0.045), (0.034, 0.045, 0.1), -0.3, m["poly"])
    # curved magazine (polymer, with a brass round on top)
    p += mag_curve(m["tan"], (0, 0.128, -0.06), n=4, size=(0.03, 0.055, 0.035), lip=m["brass"])
    p.append(box(m["brass"], (0, 0.125, 0.0), (0.012, 0.03, 0.01)))
    # buffer tube and collapsible stock
    p.append(ty(m["dark"], -0.26, -0.03, 0.04, 0.0145, verts=14))
    p.append(ring(m["dark"], -0.035, 0.04, 0.019, 0.01, verts=14))
    st = bx(m["black"], (0, -0.205, 0.03), (0.04, 0.12, 0.06), 0.006, seg=2)
    p.append(st)
    p.append(bx(m["black"], (0, -0.22, 0.068), (0.032, 0.09, 0.016), 0.005, seg=2))       # cheek riser
    p.append(bx(m["black"], (0, -0.255, -0.002), (0.044, 0.035, 0.11), 0.006, seg=2))
    p.append(bx(m["rubber"], (0, -0.275, -0.002), (0.046, 0.008, 0.118), 0.003))          # butt pad
    for k in range(5):
        p.append(bx(m["black"], (0, -0.279, -0.045 + k * 0.022), (0.047, 0.002, 0.004), 0.0005))
    p.append(bx(m["dark"], (0, -0.17, -0.004), (0.01, 0.012, 0.02), 0.002))                # lock lever
    # sling loops
    p.append(smooth(bev(cyl(m["steel"], (0, -0.06, -0.012), 0.01, 0.01, verts=10, rot=(0, PI2, 0)), 0.001)))
    p.append(tb(m["steel"], (0.022, 0.5, 0.03), (0.022, 0.5, 0.05), 0.003, 6))
    save(p, "Rifle")

def pistol():
    """Frame, slide and magazine are separate pieces (the reload moves them)."""
    reset(); m = M(); p = []
    p.append(bx(m["black"], (0, 0.06, 0.006), (0.028, 0.15, 0.02), 0.003))               # frame
    p += rail(m["black"], 0.075, 0.13, -0.004, w=0.022, up=False, slots=4)               # accessory rail
    p += grip(m["black"], (0, -0.005, -0.045), (0.029, 0.042, 0.1), -0.25, m["poly"])
    p.append(bx(m["black"], (0, -0.026, -0.002), (0.024, 0.02, 0.012), 0.003, rot=(0.5, 0, 0)))   # beavertail
    p += trigger(m["black"], 0.035, 0.005, l=0.04)
    p.append(bx(m["steel"], (0, -0.03, 0.04), (0.012, 0.012, 0.012), 0.002, rot=(0.4, 0, 0)))     # hammer
    p.append(bx(m["dark"], (0.015, 0.02, 0.012), (0.004, 0.02, 0.006), 0.001))           # slide stop
    p.append(bx(m["dark"], (0.015, 0.045, 0.004), (0.004, 0.008, 0.008), 0.001))         # mag release
    frame = join(p, "Pistol")
    s = [bx(m["dark"], (0, 0.06, 0.03), (0.03, 0.17, 0.035), 0.004, seg=2)]               # slide
    for i in range(6):
        for sx in (1, -1):
            s.append(bx(m["black"], (sx * 0.0152, -0.012 + i * 0.007, 0.03), (0.002, 0.0035, 0.026), 0.0005))
            s.append(bx(m["black"], (sx * 0.0152, 0.108 + i * 0.006, 0.033), (0.002, 0.003, 0.018), 0.0005))
    s.append(bx(m["steel"], (0.0, 0.07, 0.0485), (0.014, 0.035, 0.002), 0.0005))          # ejection port / barrel hood
    s.append(ty(m["steel"], 0.135, 0.148, 0.03, 0.007, verts=12))                         # muzzle
    s.append(cyl(m["black"], (0, 0.149, 0.03), 0.0045, 0.002, verts=10, rot=(PI2, 0, 0)))
    s.append(bx(m["black"], (0, 0.135, 0.05), (0.004, 0.006, 0.006), 0.001))              # sights with tritium dots
    s.append(box(m["tritium"], (0, 0.132, 0.052), (0.002, 0.001, 0.002)))
    s.append(bx(m["black"], (0, -0.015, 0.05), (0.014, 0.006, 0.006), 0.001))
    for sx in (1, -1):
        s.append(box(m["tritium"], (sx * 0.004, -0.0185, 0.051), (0.002, 0.001, 0.002)))
    slide = join(s, "Slide")
    g = [bx(m["dark"], (0, -0.009, -0.058), (0.022, 0.03, 0.1), 0.002, rot=(-0.25, 0, 0)),
         bx(m["black"], (0, -0.019, -0.099), (0.031, 0.043, 0.008), 0.002, rot=(-0.25, 0, 0)),
         box(m["brass"], (0, 0.002, -0.006), (0.008, 0.016, 0.006), rot=(-0.25, 0, 0))]
    mag = join(g, "Mag")
    export_glb(os.path.join(OUTDIR, "pistol.glb"), [frame, slide, mag])
    # a spare magazine on its own (in the reloading hand)
    reset(); m = M()
    g = [bx(m["dark"], (0, 0, 0), (0.022, 0.03, 0.1), 0.002), bx(m["black"], (0, 0, -0.054), (0.031, 0.043, 0.008), 0.002),
         box(m["brass"], (0, 0.004, 0.052), (0.008, 0.016, 0.006))]
    for k in range(3):
        g.append(cyl(m["steel"], (0.0115, 0.0, -0.03 + k * 0.025), 0.002, 0.001, verts=6, rot=(0, PI2, 0)))
    export_glb(os.path.join(OUTDIR, "pistol_mag.glb"), [join(g, "SpareMag")])

def shotgun():
    """Pump-action: steel receiver, walnut furniture, ribbed pump, ghost-ring sights."""
    reset(); m = M(); p = []
    p.append(bx(m["dark"], (0, 0.05, 0.033), (0.05, 0.22, 0.065), 0.004, seg=2))           # receiver
    p.append(bx(m["steel"], (0.026, 0.07, 0.04), (0.002, 0.06, 0.022), 0.0005))           # ejection port
    p.append(bx(m["brass"], (0.026, 0.08, 0.03), (0.003, 0.045, 0.018), 0.0008))          # a shell in it
    p.append(bx(m["dark"], (0, 0.02, 0.071), (0.02, 0.05, 0.01), 0.002))                  # ghost ring
    p.append(torus(m["dark"], (0, 0.02, 0.085), 0.008, 0.0025, (PI2, 0, 0)))
    p.append(ty(m["dark"], 0.15, 0.72, 0.052, 0.0165, verts=16))                          # barrel
    p.append(bx(m["dark"], (0, 0.44, 0.07), (0.008, 0.56, 0.004), 0.001))                 # vent rib
    for i in range(14):
        p.append(bx(m["dark"], (0, 0.18 + i * 0.038, 0.066), (0.006, 0.004, 0.006), 0.0005))
    p.append(ty(m["dark"], 0.15, 0.66, 0.017, 0.0145, verts=16))                          # magazine tube
    p.append(ty(m["dark"], 0.655, 0.67, 0.017, 0.0155, verts=16))                         # cap
    p.append(bx(m["dark"], (0, 0.66, 0.035), (0.012, 0.02, 0.03), 0.002))                 # barrel clamp
    p.append(sphere(m["chrome"], (0, 0.705, 0.074), 0.004, seg=8, rings=5))               # bead
    pump = cyl(m["wood"], (0, 0.42, 0.02), 0.026, 0.16, verts=12, rot=(PI2, 0, 0))
    for v in pump.data.vertices:
        v.co.x *= 0.95
    p.append(smooth(bev(pump, 0.003)))
    for i in range(7):
        p.append(ring(m["wood2"], 0.36 + i * 0.02, 0.02, 0.0268, 0.006, verts=12))
    p += trigger(m["dark"], 0.04, 0.0)
    p.append(bx(m["dark"], (0.026, 0.0, 0.03), (0.006, 0.012, 0.012), 0.002))             # safety
    # walnut stock with a pistol grip and a rubber pad
    p += grip(m["wood"], (0, -0.02, -0.04), (0.04, 0.05, 0.09), -0.35)
    st = box(m["wood"], (0, -0.2, -0.0), (0.045, 0.3, 0.07), rot=(0.12, 0, 0))
    for v in st.data.vertices:          # the stock grows taller towards the butt
        if v.co.y < -0.2:
            v.co.z += -0.02 if v.co.z < 0 else 0.008
    p.append(bev(st, 0.006, 2))
    p.append(bx(m["rubber"], (0, -0.355, -0.02), (0.049, 0.018, 0.115), 0.004, seg=2))
    p.append(smooth(bev(cyl(m["steel"], (0, -0.28, -0.045), 0.008, 0.01, verts=10, rot=(0, PI2, 0)), 0.001)))
    save(p, "Shotgun")

def magnum():
    """Top-break revolver: the barrel with the cylinder tips down on a hinge at the
    front of the frame (pivot = origin of "Barrel"), exposing the chambers."""
    reset(); m = M(); p = []
    p.append(bx(m["chrome"], (0, 0.012, 0.035), (0.03, 0.045, 0.04), 0.004, seg=2))        # frame (rear)
    p.append(bx(m["chrome"], (0, 0.055, 0.017), (0.026, 0.04, 0.006), 0.002))             # lower strap to the hinge
    p += grip(m["wood"], (0, -0.01, -0.035), (0.028, 0.04, 0.09), -0.35)
    p.append(bx(m["chrome"], (0, -0.022, -0.075), (0.03, 0.03, 0.008), 0.002, rot=(-0.35, 0, 0)))   # butt cap
    p.append(screw(m["chrome"], (0.0145, -0.01, -0.035)))
    p.append(bx(m["chrome"], (0, -0.02, 0.06), (0.01, 0.015, 0.015), 0.002, rot=(0.6, 0, 0)))      # hammer
    p.append(bx(m["dark"], (0, -0.026, 0.069), (0.011, 0.008, 0.004), 0.001, rot=(0.6, 0, 0)))
    p += trigger(m["chrome"], 0.03, 0.017, l=0.035)
    p.append(bx(m["chrome"], (0, 0.03, 0.06), (0.012, 0.03, 0.008), 0.002))                # top strap with the latch
    p.append(bx(m["dark"], (0, 0.038, 0.068), (0.006, 0.01, 0.004), 0.001))
    frame = join(p, "Magnum")
    cy = cyl(m["chrome"], (0, 0.06, 0.035), 0.022, 0.05, verts=12, rot=(PI2, 0, 0))
    b = [smooth(bev(cy, 0.003))]
    for i in range(6):
        a = i / 6 * math.tau + math.pi / 6
        b.append(bx(m["steel"], (math.cos(a) * 0.0215, 0.06, 0.035 + math.sin(a) * 0.0215), (0.006, 0.03, 0.006), 0.002, rot=(0, -a, 0)))   # flutes
        a = i / 6 * math.tau
        b.append(cyl(m["brass"], (math.cos(a) * 0.012, 0.034, 0.035 + math.sin(a) * 0.012), 0.0045, 0.003, verts=8, rot=(PI2, 0, 0)))
    b.append(ty(m["chrome"], 0.08, 0.27, 0.045, 0.0095, verts=14))                        # barrel
    b.append(bx(m["chrome"], (0, 0.15, 0.056), (0.012, 0.23, 0.01), 0.002))               # top rib (latch at the back)
    b.append(bx(m["chrome"], (0, 0.18, 0.03), (0.014, 0.17, 0.014), 0.003))               # ejector shroud
    b.append(cyl(m["dark"], (0, 0.271, 0.045), 0.0055, 0.002, verts=10, rot=(PI2, 0, 0)))
    b.append(bx(m["dark"], (0, 0.26, 0.064), (0.004, 0.008, 0.01), 0.001))
    b.append(box(m["red"], (0, 0.258, 0.067), (0.0045, 0.003, 0.004)))                    # red insert
    b.append(bx(m["chrome"], (0, 0.06, 0.017), (0.024, 0.05, 0.006), 0.002))              # hinge lug
    barrel = join(b, "Barrel")
    set_origin(barrel, (0, 0.078, 0.016))
    export_glb(os.path.join(OUTDIR, "magnum.glb"), [frame, barrel])
    # one round (loaded by hand, and the empties that fall out)
    reset(); m = M()
    r = [ty(m["brass"], -0.015, 0.015, 0, 0.0045, verts=10), ty(m["chrome"], 0.014, 0.02, 0, 0.0035, verts=10, r2=0.001),
         ring(m["brass"], -0.0155, 0, 0.0052, 0.002, verts=10)]
    export_glb(os.path.join(OUTDIR, "round.glb"), [join(r, "Round")])

def sniper():
    """Bolt-action precision rifle: fluted heavy barrel, big scope with turrets, chassis stock with an
    adjustable cheek piece, folded bipod."""
    reset(); m = M(); p = []
    p.append(bx(m["dark"], (0, 0.06, 0.03), (0.045, 0.26, 0.06), 0.004, seg=2))           # receiver
    p += rail(m["dark"], -0.05, 0.22, 0.06)
    p.append(ty(m["steel"], 0.18, 1.0, 0.045, 0.0145, verts=16, r2=0.012))                # barrel
    for k in range(6):                                                                   # flutes
        a = k / 6 * math.tau
        p.append(bx(m["dark"], (math.cos(a) * 0.0128, 0.55, 0.045 + math.sin(a) * 0.0128), (0.003, 0.5, 0.003), 0.0005, rot=(0, -a, 0)))
    p.append(ty(m["dark"], 0.98, 1.07, 0.045, 0.02, verts=12))                            # muzzle brake
    for i in range(3):
        for sx in (1, -1):
            p.append(bx(m["black"], (sx * 0.019, 1.0 + i * 0.025, 0.045), (0.006, 0.012, 0.022), 0.001))
    # scope
    p.append(ty(m["dark"], -0.02, 0.24, 0.115, 0.019, verts=18))
    p.append(ty(m["dark"], 0.24, 0.32, 0.115, 0.019, verts=18, r2=0.028))
    p.append(ty(m["dark"], -0.08, -0.02, 0.115, 0.025, verts=18, r2=0.019))
    p.append(ring(m["rubber"], -0.082, 0.115, 0.026, 0.01, verts=18))
    p.append(cyl(m["lens"], (0, 0.322, 0.115), 0.025, 0.004, verts=18, rot=(PI2, 0, 0)))
    p.append(smooth(cyl(m["dark"], (0, 0.1, 0.142), 0.012, 0.022, verts=14)))
    p.append(smooth(cyl(m["dark"], (0.027, 0.1, 0.115), 0.012, 0.022, verts=14, rot=(0, PI2, 0))))
    p.append(smooth(cyl(m["dark"], (-0.025, 0.1, 0.115), 0.009, 0.016, verts=12, rot=(0, PI2, 0))))  # parallax knob
    for k in range(12):
        a = k / 12 * math.tau
        p.append(bx(m["black"], (math.cos(a) * 0.012, 0.1, 0.142 + 0.0), (0.002, 0.002, 0.02), 0.0003, rot=(0, 0, a)))
    for y in (0.02, 0.19):                                                               # rings
        p.append(bx(m["dark"], (0, y, 0.075), (0.026, 0.02, 0.03), 0.003))
        p.append(ring(m["dark"], y, 0.115, 0.022, 0.02, verts=18))
    # bolt
    p.append(ty(m["steel"], -0.03, 0.02, 0.05, 0.009, verts=12))
    p.append(tb(m["steel"], (0.0, 0.0, 0.05), (0.045, -0.005, 0.045), 0.004, 8))
    p.append(sphere(m["black"], (0.05, -0.005, 0.045), 0.012, seg=12, rings=8))
    # chassis: handguard, magazine, grip, skeleton stock
    p.append(bx(m["olive"], (0, 0.32, 0.02), (0.05, 0.4, 0.05), 0.005, seg=2))
    for i in range(6):
        for sx in (1, -1):
            p.append(bx(m["olive2"], (sx * 0.025, 0.18 + i * 0.055, 0.02), (0.003, 0.03, 0.012), 0.001))
    p += rail(m["dark"], 0.38, 0.5, -0.005, up=False, slots=6)
    p.append(bx(m["dark"], (0, 0.04, -0.035), (0.03, 0.05, 0.04), 0.003))
    p.append(bx(m["black"], (0, 0.04, -0.057), (0.034, 0.055, 0.006), 0.002))
    p += trigger(m["dark"], 0.0, 0.0)
    p += grip(m["olive"], (0, -0.015, -0.05), (0.035, 0.045, 0.1), -0.3, m["olive2"])
    st = box(m["olive"], (0, -0.22, 0.015), (0.045, 0.28, 0.075))
    for v in st.data.vertices:           # the stock deepens towards the butt
        if v.co.y < -0.25 and v.co.z < 0.0:
            v.co.z -= 0.025
    p.append(bev(st, 0.006, 2))
    p.append(bx(m["olive2"], (0.0, -0.2, 0.0), (0.047, 0.12, 0.03), 0.004))              # thumbhole recess
    p.append(bx(m["olive"], (0, -0.18, 0.06), (0.03, 0.12, 0.025), 0.006, seg=2))         # cheek rest
    for y in (-0.15, -0.21):
        p.append(ty(m["steel"], y - 0.005, y + 0.005, 0.045, 0.004, verts=6))
    p.append(bx(m["rubber"], (0, -0.37, 0.0), (0.047, 0.02, 0.12), 0.004, seg=2))         # butt pad
    p.append(bx(m["olive"], (0, -0.33, -0.04), (0.02, 0.06, 0.04), 0.004))                # monopod stub
    for s in (-1, 1):                                                                    # folded bipod
        p.append(tb(m["dark"], (0.015 * s, 0.5, 0.0), (0.02 * s, 0.75, -0.005), 0.0065, 8))
        p.append(tb(m["rubber"], (0.02 * s, 0.75, -0.005), (0.021 * s, 0.77, -0.005), 0.008, 8))
    p.append(bx(m["dark"], (0, 0.5, -0.003), (0.04, 0.02, 0.012), 0.002))
    save(p, "Sniper")

def autocannon():
    """Shoulder-fired 20 mm autocannon: olive receiver with ribs, heavy barrel in a perforated jacket,
    big muzzle brake, a box magazine on the left, carry handle, bipod-less fore grip."""
    reset(); m = M(); p = []
    p.append(bx(m["olive"], (0, 0.15, 0.06), (0.11, 0.55, 0.14), 0.01, seg=2))           # body
    for i in range(6):
        p.append(bx(m["olive2"], (0.056, 0.0 + i * 0.07, 0.06), (0.004, 0.02, 0.11), 0.001))
    for x in (0.056, -0.056):
        for y in (-0.08, 0.38):
            for z in (0.0, 0.12):
                p.append(screw(m["steel"], (x, y, z), 0.005))
    p.append(ty(m["olive2"], 0.42, 0.95, 0.07, 0.04, verts=16))                          # barrel jacket
    for i in range(8):
        for k in range(6):
            a = k / 6 * math.tau
            p.append(cyl(m["black"], (math.cos(a) * 0.0395, 0.47 + i * 0.06, 0.07 + math.sin(a) * 0.0395), 0.007, 0.004, verts=8, rot=(0, PI2 - a, 0) if False else (0, 0, 0)) if False else
                     bx(m["black"], (math.cos(a) * 0.039, 0.47 + i * 0.06, 0.07 + math.sin(a) * 0.039), (0.004, 0.02, 0.004), 0.0005, rot=(0, -a, 0)))
    p.append(ty(m["dark"], 0.9, 1.12, 0.07, 0.028, verts=16))                            # barrel
    brake = ty(m["dark"], 1.1, 1.2, 0.07, 0.044, verts=8)
    p.append(bev(brake, 0.004))
    for i in range(3):
        for sx in (1, -1):
            p.append(bx(m["black"], (sx * 0.04, 1.12 + i * 0.03, 0.07), (0.01, 0.015, 0.05), 0.001))
    p.append(bx(m["dark"], (-0.09, 0.2, 0.04), (0.08, 0.18, 0.16), 0.006, seg=2))         # side box magazine
    for k in range(3):
        p.append(bx(m["black"], (-0.131, 0.15 + k * 0.05, 0.04), (0.004, 0.012, 0.13), 0.001))
    p.append(bx(m["warn"], (-0.131, 0.2, 0.1), (0.002, 0.12, 0.02), 0.0005))
    p.append(bx(m["white"], (-0.131, 0.2, -0.02), (0.002, 0.08, 0.012), 0.0005))
    p.append(bx(m["dark"], (0, 0.15, 0.17), (0.025, 0.3, 0.05), 0.006, seg=2))            # carry handle
    p.append(bx(m["dark"], (0, 0.03, 0.15), (0.025, 0.03, 0.08), 0.004))
    p.append(bx(m["dark"], (0, 0.28, 0.15), (0.025, 0.03, 0.08), 0.004))
    p.append(bx(m["dark"], (0.0, 0.15, 0.2), (0.012, 0.05, 0.016), 0.002))                # sight on the handle
    p.append(box(m["dot"], (0.0, 0.176, 0.205), (0.004, 0.002, 0.004)))
    p += grip(m["black"], (0, -0.005, -0.06), (0.04, 0.05, 0.12), -0.3, m["poly"])
    p += trigger(m["dark"], 0.04, -0.01)
    p.append(bx(m["black"], (0, 0.42, -0.04), (0.045, 0.06, 0.1), 0.008, seg=2))           # fore grip
    p.append(bx(m["olive"], (0, -0.2, 0.05), (0.06, 0.25, 0.1), 0.008, seg=2))            # stock
    p.append(bx(m["rubber"], (0, -0.33, 0.05), (0.065, 0.02, 0.14), 0.005, seg=2))
    p.append(bx(m["dark"], (0.057, 0.25, 0.1), (0.012, 0.05, 0.02), 0.002))               # cocking handle
    save(p, "Autocannon")

def minigun():
    """Rotary gun: motor housing with cooling fins, a belt from the ammo box, top handle, barrel cluster
    in clamps (the game spins it)."""
    reset(); m = M(); p = []
    hs = cyl(m["dark"], (0, 0.05, 0.05), 0.07, 0.22, verts=18, rot=(PI2, 0, 0))
    p.append(smooth(bev(hs, 0.006)))
    for i in range(6):
        p.append(ring(m["black"], -0.04 + i * 0.035, 0.05, 0.074, 0.008, verts=18))
    p.append(bx(m["olive"], (0, -0.12, 0.03), (0.12, 0.16, 0.12), 0.01, seg=2))           # rear body
    p.append(bx(m["olive2"], (0, -0.2, 0.03), (0.1, 0.012, 0.1), 0.004))
    p.append(smooth(cyl(m["dark"], (0.062, -0.12, 0.05), 0.02, 0.012, verts=14, rot=(0, PI2, 0))))   # motor cap
    p.append(bx(m["red"], (0.061, -0.15, 0.08), (0.004, 0.01, 0.006), 0.001))              # the spin light
    p.append(bx(m["dark"], (0, -0.0, 0.16), (0.03, 0.3, 0.03), 0.006, seg=2))              # top handle
    p.append(bx(m["dark"], (0, -0.12, 0.12), (0.03, 0.03, 0.08), 0.004))
    p.append(bx(m["dark"], (0, 0.12, 0.12), (0.03, 0.03, 0.08), 0.004))
    p += grip(m["black"], (0, -0.02, -0.06), (0.04, 0.05, 0.12), -0.3, m["poly"])
    p += trigger(m["dark"], 0.02, -0.01)
    p.append(bx(m["olive"], (-0.12, -0.05, -0.04), (0.1, 0.18, 0.16), 0.008, seg=2))       # ammo box
    p.append(bx(m["olive2"], (-0.12, -0.05, 0.043), (0.104, 0.184, 0.012), 0.003))
    p.append(bx(m["dark"], (-0.172, -0.05, -0.02), (0.006, 0.06, 0.02), 0.002))            # latch
    p.append(bx(m["warn"], (-0.171, -0.05, -0.07), (0.002, 0.12, 0.02), 0.0005))
    for k in range(7):                                                                    # the belt into the gun
        t = k / 6
        c = Vector((-0.09, -0.02, 0.04)).lerp(Vector((-0.02, 0.07, 0.05)), t) + Vector((0, 0, math.sin(t * math.pi) * 0.02))
        p.append(bx(m["brass"], tuple(c), (0.03, 0.008, 0.01), 0.001, rot=(0, 0, 0.8)))
    body = join(p, "Minigun")
    # spinning barrel cluster is a separate mesh (the game spins it)
    q = []
    for i in range(6):
        a = i / 6 * math.tau
        q.append(ty(m["steel"], 0.16, 0.85, 0.05 + math.sin(a) * 0.035, 0.012, x=math.cos(a) * 0.035, verts=10))
        q.append(cyl(m["black"], (math.cos(a) * 0.035, 0.851, 0.05 + math.sin(a) * 0.035), 0.0065, 0.002, verts=8, rot=(PI2, 0, 0)))
    for y, r in ((0.3, 0.055), (0.6, 0.055), (0.83, 0.052)):
        cl = cyl(m["dark"], (0, y, 0.05), r, 0.025, verts=12, rot=(PI2, 0, 0))
        q.append(smooth(bev(cl, 0.003)))
    q.append(ty(m["dark"], 0.16, 0.85, 0.05, 0.012, verts=8))
    for o in q:
        for v in o.data.vertices:
            v.co.z -= 0.05      # spin axis through the origin of this mesh
    barrels = join(q, "MinigunBarrels")
    barrels.location = (0, 0, 0.05)
    export_glb(os.path.join(OUTDIR, "minigun.glb"), [body, barrels])

def rocket():
    """Recoilless launcher: olive tube with end caps, folding sight, two grips, a warhead that pokes out."""
    reset(); m = M(); p = []
    p.append(ty(m["olive"], -0.45, 0.75, 0.07, 0.055, verts=18))
    p.append(ty(m["dark"], 0.72, 0.78, 0.07, 0.065, verts=18))
    p.append(ty(m["dark"], -0.5, -0.43, 0.07, 0.068, verts=18))
    p.append(ring(m["rubber"], -0.5, 0.07, 0.07, 0.012, verts=18))
    for y in (-0.2, 0.15, 0.5):
        p.append(ring(m["olive2"], y, 0.07, 0.058, 0.02, verts=18))
    p.append(bx(m["warn"], (0, 0.3, 0.127), (0.04, 0.3, 0.004), 0.001))
    p.append(bx(m["white"], (0.05, 0.0, 0.1), (0.003, 0.25, 0.012), 0.0005))
    p.append(bx(m["dark"], (0.07, 0.2, 0.12), (0.03, 0.1, 0.06), 0.005, seg=2))           # sight
    p.append(cyl(m["lens"], (0.07, 0.252, 0.13), 0.011, 0.002, verts=12, rot=(PI2, 0, 0)))
    p.append(bx(m["dark"], (0.055, 0.2, 0.1), (0.02, 0.04, 0.02), 0.002))
    p.append(bx(m["dark"], (0, 0.0, 0.015), (0.04, 0.12, 0.02), 0.003))                   # grip mount
    p += grip(m["black"], (0, 0.0, -0.03), (0.035, 0.045, 0.1), -0.25, m["poly"])
    p += trigger(m["dark"], 0.04, 0.012)
    p.append(bx(m["black"], (0, 0.3, -0.02), (0.035, 0.045, 0.09), 0.006, seg=2))
    p.append(bx(m["rubber"], (0, -0.15, 0.0), (0.06, 0.12, 0.03), 0.006))                 # shoulder pad
    p.append(tb(m["dark"], (0.06, -0.3, 0.07), (0.06, 0.55, 0.07), 0.003, 6))             # sling
    body = join(p, "Rocket_launcher")
    w = [ty(m["olive2"], 0.77, 0.91, 0.07, 0.045, verts=14),
         ring(m["warn"], 0.86, 0.07, 0.0455, 0.012, verts=14),
         cyl(m["dark"], (0, 0.96, 0.07), 0.045, 0.1, verts=14, r2=0.012, rot=(-PI2, 0, 0)),
         ty(m["steel"], 1.01, 1.03, 0.07, 0.008, verts=8)]
    warhead = join([smooth(o) for o in w], "Warhead")
    export_glb(os.path.join(OUTDIR, "rocket_launcher.glb"), [body, warhead])
    # the flying rocket on its own
    reset(); m = M()
    r = [ty(m["olive2"], -0.25, 0.2, 0, 0.04, verts=14),
         ring(m["warn"], 0.12, 0, 0.0405, 0.015, verts=14),
         smooth(cyl(m["dark"], (0, 0.27, 0), 0.04, 0.14, verts=14, r2=0.01, rot=(-PI2, 0, 0))),
         ty(m["steel"], 0.335, 0.36, 0, 0.007, verts=8),
         ty(m["dark"], -0.28, -0.25, 0, 0.028, verts=12, r2=0.04)]
    for i in range(4):
        a = i / 4 * math.tau
        r.append(bx(m["dark"], (math.cos(a) * 0.055, -0.22, math.sin(a) * 0.055), (0.004 + abs(math.sin(a)) * 0.05, 0.08, 0.004 + abs(math.cos(a)) * 0.05), 0.001))
    save(r, "Rocket")

def plasma_rifle():
    """Built by the base engineers from a captured plasma pistol: a human stock, grip and rail around
    an alien core that glows through the slits."""
    reset(); m = M()
    core = mat2("PlasmaCore", (0.35, 1.0, 0.45), emit=4.0)
    shell = mat2("AlienShell", (0.3, 0.33, 0.3), 0.3, 0.6)
    shell2 = mat2("AlienShellDark", (0.17, 0.19, 0.18), 0.3, 0.6)
    p = []
    p.append(bx(m["dark"], (0, 0.05, 0.03), (0.05, 0.3, 0.07), 0.005, seg=2))
    p += rail(m["dark"], -0.06, 0.17, 0.065)
    sh = cyl(shell, (0, 0.35, 0.04), 0.035, 0.36, verts=14, rot=(PI2, 0, 0), r2=0.02)
    for v in sh.data.vertices:
        v.co.z = 0.04 + (v.co.z - 0.04) * 1.15
    p.append(smooth(sh))
    for i in range(4):
        p.append(ring(shell2, 0.22 + i * 0.07, 0.04, 0.034 - i * 0.0035, 0.02, verts=14))
    for i in range(3):
        p.append(bx(core, (0, 0.24 + i * 0.09, 0.077 - i * 0.004), (0.012, 0.05, 0.006), 0.001))
        for sx in (1, -1):
            p.append(bx(core, (sx * (0.033 - i * 0.004), 0.25 + i * 0.09, 0.04), (0.004, 0.035, 0.008), 0.001))
    p.append(sphere(core, (0, 0.55, 0.04), 0.022, seg=14, rings=10))
    for k in range(3):                                                                   # emitter prongs
        a = k / 3 * math.tau + PI2
        p.append(tb(shell2, (math.cos(a) * 0.02, 0.5, 0.04 + math.sin(a) * 0.02), (math.cos(a) * 0.03, 0.6, 0.04 + math.sin(a) * 0.03), 0.005, 8, r2=0.002))
    p.append(bx(shell, (0, 0.12, 0.09), (0.03, 0.12, 0.03), 0.006, seg=2))
    p += grip(m["black"], (0, -0.005, -0.045), (0.035, 0.045, 0.1), -0.3, m["poly"])
    p += trigger(m["dark"], 0.04, 0.0)
    p.append(bx(core, (0, 0.11, -0.04), (0.03, 0.05, 0.06), 0.004))                       # cell
    p.append(bx(shell2, (0, 0.11, -0.072), (0.034, 0.054, 0.008), 0.002))
    p.append(bx(m["black"], (0, -0.19, 0.02), (0.04, 0.22, 0.06), 0.006, seg=2))
    p.append(bx(m["rubber"], (0, -0.3, 0.0), (0.045, 0.02, 0.11), 0.004, seg=2))
    save(p, "Plasma_rifle")

# ---- the laser family: pale ceramic body, dark trim, copper coils, a red lens -------------------
def laser_mats():
    return dict(
        body=mat2("LaserBody", (0.62, 0.64, 0.66), 0.3, 0.3),
        body2=mat2("LaserBody2", (0.5, 0.52, 0.55), 0.3, 0.3),
        trim=mat2("LaserTrim", (0.08, 0.09, 0.1), 0.45, 0.5),
        lens=mat2("LaserLens", (1.0, 0.18, 0.12), emit=5.0),
        coil=mat2("LaserCoil", (0.75, 0.42, 0.15), 0.25, 1.0),
        cell=mat2("LaserCell", (1.0, 0.3, 0.2), emit=2.0),
    )

def laser_pistol():
    reset(); L = laser_mats(); m = M(); p = []
    p.append(bx(L["body"], (0, 0.08, 0.03), (0.04, 0.2, 0.05), 0.008, seg=2))
    p.append(bx(L["trim"], (0, 0.08, 0.06), (0.03, 0.18, 0.012), 0.004))
    for i in range(4):
        p.append(bx(L["coil"], (0, 0.03 + i * 0.03, 0.03), (0.046, 0.008, 0.04), 0.002))
    p.append(ty(L["trim"], 0.175, 0.205, 0.03, 0.018, verts=14))
    p.append(ring(L["body2"], 0.185, 0.03, 0.0195, 0.006, verts=14))
    p.append(cyl(L["lens"], (0, 0.206, 0.03), 0.012, 0.004, verts=14, rot=(PI2, 0, 0)))
    p.append(bx(L["trim"], (0, 0.13, 0.071), (0.004, 0.008, 0.008), 0.001))
    p.append(bx(L["trim"], (0, 0.0, 0.071), (0.012, 0.008, 0.008), 0.001))
    p += grip(L["trim"], (0, -0.005, -0.035), (0.032, 0.04, 0.085), -0.25, m["rubber"])
    p += trigger(L["trim"], 0.035, 0.005, l=0.04)
    p.append(bx(L["lens"], (0, 0.0, -0.035), (0.034, 0.012, 0.02), 0.002))               # charge window
    p.append(bx(L["cell"], (0.0172, 0.06, 0.03), (0.002, 0.08, 0.008), 0.0005))
    save(p, "Laser_pistol")

def laser_rifle():
    reset(); L = laser_mats(); m = M(); p = []
    p.append(bx(L["body"], (0, 0.12, 0.03), (0.05, 0.42, 0.07), 0.01, seg=2))
    p.append(bx(L["trim"], (0, 0.12, 0.072), (0.035, 0.36, 0.014), 0.004))
    for i in range(7):
        p.append(bx(L["coil"], (0, 0.0 + i * 0.045, 0.03), (0.058, 0.012, 0.06), 0.003))  # cooling fins
    p.append(ty(L["trim"], 0.33, 0.6, 0.04, 0.022, verts=16, r2=0.017))
    for i in range(3):
        p.append(ring(L["body2"], 0.39 + i * 0.06, 0.04, 0.0225 - i * 0.0015, 0.012, verts=16))
    p.append(cyl(L["lens"], (0, 0.602, 0.04), 0.013, 0.005, verts=14, rot=(PI2, 0, 0)))
    p.append(bx(L["trim"], (0, 0.1, 0.1), (0.02, 0.12, 0.03), 0.004))                    # sight block
    p.append(box(L["lens"], (0, 0.045, 0.116), (0.006, 0.006, 0.004)))
    p.append(bx(L["trim"], (0, 0.16, 0.117), (0.014, 0.004, 0.006), 0.001))
    p += grip(L["trim"], (0, -0.005, -0.045), (0.035, 0.045, 0.1), -0.3, m["rubber"])
    p += trigger(L["trim"], 0.04, 0.0)
    p.append(bx(L["body"], (0, 0.12, -0.035), (0.04, 0.07, 0.05), 0.006))                 # power pack
    p.append(bx(L["lens"], (0.021, 0.12, -0.035), (0.002, 0.05, 0.02), 0.0005))
    p.append(bx(L["trim"], (0, 0.12, -0.062), (0.044, 0.074, 0.006), 0.002))
    p.append(bx(L["trim"], (0, -0.2, 0.02), (0.04, 0.22, 0.06), 0.008, seg=2))
    p.append(bx(L["body2"], (0, -0.2, 0.052), (0.03, 0.14, 0.008), 0.003))
    p.append(bx(L["body"], (0, -0.31, 0.0), (0.045, 0.02, 0.11), 0.006, seg=2))
    save(p, "Laser_rifle")

def laser_cannon():
    reset(); L = laser_mats(); m = M(); p = []
    p.append(bx(L["body"], (0, 0.15, 0.04), (0.09, 0.55, 0.1), 0.012, seg=2))
    for i in range(9):
        p.append(bx(L["coil"], (0, -0.05 + i * 0.05, 0.04), (0.105, 0.014, 0.115), 0.004))
    p.append(ty(L["trim"], 0.42, 0.78, 0.05, 0.04, verts=18, r2=0.03))
    for i in range(4):
        p.append(ring(L["body2"], 0.47 + i * 0.07, 0.05, 0.041 - i * 0.0028, 0.016, verts=18))
    p.append(ty(L["trim"], 0.42, 0.66, 0.0, 0.018, verts=12))
    p.append(cyl(L["lens"], (0, 0.782, 0.05), 0.024, 0.006, verts=16, rot=(PI2, 0, 0)))
    p += grip(L["trim"], (0, 0.0, -0.07), (0.04, 0.05, 0.11), -0.25, m["rubber"])
    p += trigger(L["trim"], 0.045, -0.01)
    p.append(bx(L["trim"], (0, 0.42, -0.05), (0.03, 0.04, 0.08), 0.006, seg=2))           # front grip
    p.append(bx(L["body"], (0, -0.2, 0.04), (0.08, 0.2, 0.12), 0.012, seg=2))             # power core
    p.append(bx(L["lens"], (0.041, -0.2, 0.04), (0.002, 0.14, 0.05), 0.0005))
    for i in range(4):
        p.append(bx(L["trim"], (-0.041, -0.27 + i * 0.045, 0.04), (0.004, 0.02, 0.09), 0.001))
    p.append(bx(L["trim"], (0, 0.1, 0.12), (0.025, 0.2, 0.03), 0.006, seg=2))             # carry handle
    p.append(bx(L["trim"], (0, 0.02, 0.1), (0.022, 0.02, 0.03), 0.003))
    p.append(bx(L["trim"], (0, 0.18, 0.1), (0.022, 0.02, 0.03), 0.003))
    save(p, "Laser_cannon")

# ---- melee and small things ----------------------------------------------------------------------
def baton():
    reset(); m = M(); p = []
    p.append(ty(m["rubber"], -0.06, 0.06, 0, 0.018, verts=12))
    for i in range(5):
        p.append(ring(m["black"], -0.045 + i * 0.022, 0, 0.0195, 0.006, verts=12))
    p.append(ring(m["dark"], 0.064, 0, 0.02, 0.012, verts=12))
    p.append(ty(m["dark"], 0.06, 0.42, 0, 0.013, verts=12, r2=0.011))
    p.append(bx(m["warn"], (0, 0.03, 0.02), (0.012, 0.03, 0.008), 0.002))
    p.append(bx(m["red"], (0, 0.0, 0.0195), (0.006, 0.006, 0.003), 0.001))
    for x in (-0.012, 0.012):
        p.append(bx(m["chrome"], (x, 0.45, 0), (0.005, 0.05, 0.005), 0.001))
    p.append(bx(m["blue"], (0, 0.46, 0), (0.016, 0.01, 0.01), 0.002))
    p.append(ring(m["black"], 0.425, 0, 0.016, 0.01, verts=12))
    save(p, "Stun_baton")

def knife():
    reset(); m = M(); p = []
    h = cyl(m["poly"], (0, 0.0, 0), 0.016, 0.11, verts=10, rot=(PI2, 0, 0))
    for v in h.data.vertices:
        v.co.x *= 0.75
    p.append(smooth(h))
    for i in range(6):
        p.append(ring(m["black"], -0.04 + i * 0.016, 0, 0.0165, 0.004, verts=10))
    p.append(bx(m["dark"], (0, -0.058, 0), (0.022, 0.008, 0.028), 0.003))                 # pommel
    p.append(bx(m["dark"], (0, 0.065, 0), (0.05, 0.012, 0.035), 0.003, seg=2))            # guard
    blade = box(m["chrome"], (0, 0.15, 0.003), (0.004, 0.17, 0.03))
    for v in blade.data.vertices:            # taper to a clip point
        if v.co.y > 0.2:
            v.co.z = 0.012 if v.co.z > 0.003 else -0.003
        if v.co.z < -0.005:
            v.co.x *= 0.15                   # the edge
    p.append(blade)
    p.append(bx(m["dark"], (0, 0.14, 0.02), (0.005, 0.12, 0.004), 0.001))
    for i in range(8):                                                                   # serrations on the spine
        p.append(bx(m["chrome"], (0, 0.085 + i * 0.008, 0.0185), (0.004, 0.004, 0.004), 0.0005, rot=(0.6, 0, 0)))
    save(p, "Knife")

def smoke():
    reset(); m = M()
    save([smooth(cyl(m["grey"], (0, 0, 0.06), 0.03, 0.12, verts=14)),
          smooth(cyl(m["warn"], (0, 0, 0.09), 0.031, 0.02, verts=14)),
          bx(m["white"], (0.0305, 0, 0.05), (0.002, 0.02, 0.05), 0.0005),
          smooth(cyl(m["dark"], (0, 0, 0.125), 0.016, 0.012, verts=12)),
          bx(m["dark"], (0, 0, 0.135), (0.015, 0.015, 0.02), 0.002),
          bx(m["dark"], (0.022, 0, 0.11), (0.006, 0.01, 0.05), 0.001),
          torus(m["steel"], (-0.012, 0, 0.142), 0.01, 0.0015, (PI2, 0, 0), 12)], "Smoke_grenade")

def mine():
    reset(); m = M()
    save([smooth(bev(cyl(m["olive"], (0, 0, 0.025), 0.1, 0.05, verts=18), 0.006)),
          smooth(cyl(m["olive2"], (0, 0, 0.051), 0.07, 0.004, verts=18)),
          smooth(cyl(m["dark"], (0, 0, 0.055), 0.03, 0.015, verts=14)),
          smooth(cyl(m["black"], (0, 0, 0.064), 0.012, 0.006, verts=10)),
          bx(m["white"], (0.0, -0.05, 0.053), (0.05, 0.012, 0.002), 0.0005),
          bx(m["red"], (0.05, 0, 0.052), (0.01, 0.01, 0.006), 0.001)], "Mine")

def handheld():
    """Small things that can be held in one hand."""
    reset(); m = M()
    scr = mat2("ScannerScreen", (0.2, 0.9, 0.4), emit=2.0)
    save([bx(m["poly"], (0, 0.04, 0.0), (0.07, 0.13, 0.035), 0.008, seg=2),
          bx(m["black"], (0, 0.05, 0.0175), (0.058, 0.07, 0.002), 0.001),
          box(scr, (0, 0.05, 0.018), (0.05, 0.06, 0.002)),
          bx(m["dark"], (0, -0.04, -0.01), (0.03, 0.06, 0.03), 0.006),
          bx(m["rubber"], (0.036, 0.04, 0.0), (0.004, 0.11, 0.03), 0.001),
          bx(m["rubber"], (-0.036, 0.04, 0.0), (0.004, 0.11, 0.03), 0.001),
          smooth(cyl(m["black"], (-0.02, 0.0, 0.019), 0.006, 0.004, verts=10)),
          smooth(cyl(m["black"], (0.0, 0.0, 0.019), 0.006, 0.004, verts=10)),
          box(m["red"], (0.02, 0.0, 0.018), (0.006, 0.006, 0.003)),
          ty(m["dark"], 0.1, 0.16, 0.0, 0.006, x=0.025, verts=8),
          sphere(m["dark"], (0.025, 0.162, 0.0), 0.008, seg=8, rings=5)], "Scanner")
    reset(); m = M()
    save([smooth(sphere(m["olive"], (0, 0.02, 0.0), 0.035, seg=16, rings=12, scale=(1, 1, 1.2))),
          ring(m["olive2"], 0.02, 0.0, 0.0355, 0.006, verts=16),
          smooth(cyl(m["steel"], (0, 0.02, 0.045), 0.012, 0.02, verts=12)),
          bx(m["steel"], (0, 0.02, 0.055), (0.02, 0.02, 0.012), 0.002),
          bx(m["steel"], (0.015, 0.0, 0.035), (0.006, 0.05, 0.008), 0.001, rot=(0, 0, 0)),
          torus(m["steel"], (-0.016, 0.02, 0.06), 0.011, 0.0018, (0, PI2, 0), 12)], "Grenade")
    reset(); m = M()
    save([ty(mat2("FlareRed", (0.7, 0.12, 0.08), 0.7), -0.04, 0.16, 0, 0.016, verts=12),
          ty(m["dark"], 0.155, 0.175, 0, 0.017, verts=12),
          bx(m["white"], (0.0162, 0.06, 0), (0.002, 0.08, 0.01), 0.0005),
          ty(m["black"], -0.045, -0.03, 0, 0.017, verts=12)], "Flare")
    reset(); m = M()
    wh = mat2("White", (0.9, 0.9, 0.9), 0.7)
    mr = mat2("MedRed", (0.6, 0.08, 0.06), 0.7)
    save([bx(mr, (0, 0.04, 0.0), (0.12, 0.08, 0.1), 0.01, seg=2),
          bx(mat2("MedRedDark", (0.4, 0.05, 0.04), 0.7), (0, 0.04, 0.0), (0.124, 0.084, 0.012), 0.003),
          box(wh, (0, 0.04, 0.051), (0.06, 0.015, 0.002)), box(wh, (0, 0.04, 0.051), (0.015, 0.06, 0.002)),
          bx(m["black"], (0, 0.04, -0.053), (0.06, 0.03, 0.006), 0.002),
          bx(m["black"], (0.062, 0.04, 0.02), (0.004, 0.02, 0.012), 0.001)], "Medkit")

def energo_nuz():
    """X-WEP-002 energy knife: the combat knife's shape, a grey laser-family grip with a small red cell
    window, a dark alloy blade with a glowing edge strip and an emitter at the guard."""
    reset(); L = laser_mats(); m = M(); p = []
    h = cyl(L["trim"], (0, 0.0, 0), 0.017, 0.115, verts=10, rot=(PI2, 0, 0))
    for v in h.data.vertices:
        v.co.x *= 0.75
    p.append(smooth(h))
    for i in range(4):
        p.append(ring(L["body2"], -0.04 + i * 0.022, 0, 0.0175, 0.005, verts=10))
    p.append(bx(L["cell"], (0.0125, 0.0, 0), (0.002, 0.05, 0.012), 0.0005))               # cell window
    p.append(bx(L["body"], (0, -0.062, 0), (0.024, 0.012, 0.03), 0.003))                  # pommel (cell cap)
    p.append(bx(L["body"], (0, 0.066, 0), (0.052, 0.014, 0.036), 0.003, seg=2))            # guard / emitter
    p.append(bx(L["lens"], (0, 0.074, -0.012), (0.012, 0.004, 0.006), 0.001))
    blade = box(L["trim"], (0, 0.155, 0.004), (0.005, 0.17, 0.03))
    for v in blade.data.vertices:            # the same clip point as the knife
        if v.co.y > 0.2:
            v.co.z = 0.013 if v.co.z > 0.003 else -0.002
    p.append(blade)
    edge = box(L["lens"], (0, 0.152, -0.012), (0.0025, 0.16, 0.004))                       # the hot edge
    for v in edge.data.vertices:
        if v.co.y > 0.2:
            v.co.z += 0.006
    p.append(edge)
    p.append(bx(L["coil"], (0, 0.12, 0.017), (0.006, 0.08, 0.004), 0.001))                # spine conductor
    save(p, "Energo_nuz")

def laser_minigun():
    """X-WEP-006 / LM-01: the minigun's frame (same grips, origin and muzzle height) with a power core where
    the ammo box was, a cable instead of the belt, and six emitter tubes in finned clamps - a separate mesh
    "MinigunBarrels" the game spins like the minigun's barrels (the rotor)."""
    reset(); L = laser_mats(); m = M(); p = []
    hs = cyl(L["body"], (0, 0.05, 0.05), 0.07, 0.22, verts=18, rot=(PI2, 0, 0))
    p.append(smooth(bev(hs, 0.006)))
    for i in range(6):
        p.append(ring(L["coil"], -0.04 + i * 0.035, 0.05, 0.074, 0.008, verts=18))
    p.append(bx(L["body2"], (0, -0.12, 0.03), (0.12, 0.16, 0.12), 0.01, seg=2))           # rear body
    p.append(bx(L["trim"], (0, -0.2, 0.03), (0.1, 0.012, 0.1), 0.004))
    p.append(bx(L["lens"], (0.061, -0.15, 0.08), (0.004, 0.01, 0.006), 0.001))           # reserve light
    p.append(bx(L["trim"], (0, -0.0, 0.16), (0.03, 0.3, 0.03), 0.006, seg=2))             # top handle
    p.append(bx(L["trim"], (0, -0.12, 0.12), (0.03, 0.03, 0.08), 0.004))
    p.append(bx(L["trim"], (0, 0.12, 0.12), (0.03, 0.03, 0.08), 0.004))
    p += grip(L["trim"], (0, -0.02, -0.06), (0.04, 0.05, 0.12), -0.3, m["rubber"])
    p += trigger(L["trim"], 0.02, -0.01)
    p.append(bx(L["body"], (-0.12, -0.05, -0.04), (0.1, 0.18, 0.16), 0.01, seg=2))        # power core
    p.append(bx(L["cell"], (-0.171, -0.05, -0.04), (0.002, 0.14, 0.09), 0.0005))
    for i in range(5):
        p.append(bx(L["trim"], (-0.12, -0.12 + i * 0.035, 0.043), (0.104, 0.01, 0.012), 0.002))
    for k in range(6):                                                                    # the cable into the gun
        t = k / 5
        c = Vector((-0.09, -0.02, 0.04)).lerp(Vector((-0.03, 0.07, 0.05)), t) + Vector((0, 0, math.sin(t * math.pi) * 0.02))
        p.append(bx(L["trim"], tuple(c), (0.02, 0.02, 0.02), 0.006))
    body = join(p, "Laser_minigun")
    q = []
    for i in range(6):                                                                    # six emitters on the rotor
        a = i / 6 * math.tau
        x, z = math.cos(a) * 0.035, 0.05 + math.sin(a) * 0.035
        q.append(ty(L["trim"], 0.16, 0.82, z, 0.012, x=x, verts=10))
        q.append(cyl(L["lens"], (x, 0.822, z), 0.008, 0.003, verts=10, rot=(PI2, 0, 0)))
    for y, r in ((0.3, 0.056), (0.5, 0.056), (0.7, 0.054)):                               # finned clamps
        for f in range(3):
            q.append(ring(L["coil"] if f == 1 else L["body2"], y + f * 0.014, 0.05, r - f * 0.002, 0.008, verts=16))
    q.append(ty(L["body"], 0.16, 0.8, 0.05, 0.011, verts=10))
    for o in q:
        for v in o.data.vertices:
            v.co.z -= 0.05      # spin axis through the origin of this mesh
    barrels = join(q, "MinigunBarrels")
    barrels.location = (0, 0, 0.05)
    export_glb(os.path.join(OUTDIR, "laser_minigun.glb"), [body, barrels])

def jet_laser_mg():
    """X-AIR-003 pod under a fighter's wing: 1 m long along +Y, a finned body, a red lens at the front."""
    reset(); L = laser_mats(); p = []
    p.append(smooth(ty(L["body2"], -0.5, 0.35, 0.0, 0.07, verts=16)))
    p.append(smooth(ty(L["body"], 0.35, 0.5, 0.0, 0.05, verts=16, r2=0.035)))
    for i in range(5):
        p.append(ring(L["coil"], -0.3 + i * 0.12, 0.0, 0.072, 0.015, verts=16))
    p.append(cyl(L["lens"], (0, 0.503, 0), 0.028, 0.006, verts=14, rot=(PI2, 0, 0)))
    p.append(bx(L["trim"], (0, -0.05, 0.08), (0.025, 0.5, 0.04), 0.006))                  # pylon
    save(p, "Jet_laser_mg")

def jet_laser_cannon():
    """X-AIR-002 pod: a fatter 1.4 m body with a glowing core window and a long focusing barrel."""
    reset(); L = laser_mats(); p = []
    p.append(smooth(ty(L["body"], -0.7, 0.2, 0.0, 0.12, verts=18)))
    p.append(smooth(ty(L["trim"], 0.2, 0.7, 0.0, 0.055, verts=16, r2=0.045)))
    for i in range(4):
        p.append(ring(L["body2"], 0.28 + i * 0.1, 0.0, 0.058, 0.02, verts=16))
    for i in range(6):
        p.append(ring(L["coil"], -0.55 + i * 0.12, 0.0, 0.123, 0.02, verts=18))
    p.append(bx(L["cell"], (0.12, -0.25, 0), (0.004, 0.4, 0.06), 0.001))
    p.append(bx(L["cell"], (-0.12, -0.25, 0), (0.004, 0.4, 0.06), 0.001))
    p.append(cyl(L["lens"], (0, 0.703, 0), 0.04, 0.008, verts=16, rot=(PI2, 0, 0)))
    p.append(bx(L["trim"], (0, -0.2, 0.13), (0.03, 0.6, 0.05), 0.006))                     # pylon
    save(p, "Jet_laser_cannon")

# ---- 0.57: the plasma family (X-WEP-007): human frames round their plasma tech, one PL-MAG-01 for all -----
def plasma_mats():
    m = M()
    return m, dict(core=mat2("PlasmaCore", (0.35, 1.0, 0.45), emit=4.0), shell=mat2("AlienShell", (0.3, 0.33, 0.3), 0.3, 0.6),
                   shell2=mat2("AlienShellDark", (0.17, 0.19, 0.18), 0.3, 0.6), mag=mat2("PlasmaMag", (0.22, 0.24, 0.22), 0.35, 0.7))

def plasma_mag(P, c, rot=(0, 0, 0), s=1.0):
    """PL-MAG-01: a dark alloy block with a green window and two contacts (the same on every gun)."""
    x, y, z = c
    return [bx(P["mag"], (x, y, z), (0.03 * s, 0.05 * s, 0.065 * s), 0.004, rot=rot),
            bx(P["core"], (x + 0.0155 * s, y, z), (0.002, 0.03 * s, 0.04 * s), 0.0005, rot=rot),
            bx(P["shell2"], (x, y, z - 0.035 * s), (0.032 * s, 0.052 * s, 0.006), 0.001, rot=rot)]

def plasma_pistol():
    """X-WEP-008: a human pistol frame and grip, an alien emitter tube with green slits, the PL-MAG in the grip."""
    reset(); m, P = plasma_mats(); p = []
    p.append(bx(m["dark"], (0, 0.06, 0.03), (0.034, 0.16, 0.045), 0.004, seg=2))
    sh = cyl(P["shell"], (0, 0.13, 0.035), 0.022, 0.16, verts=12, rot=(PI2, 0, 0), r2=0.015)
    p.append(smooth(sh))
    for i in range(2):
        p.append(ring(P["shell2"], 0.1 + i * 0.05, 0.035, 0.022, 0.012, verts=12))
        p.append(bx(P["core"], (0, 0.11 + i * 0.05, 0.056), (0.008, 0.025, 0.004), 0.001))
    p.append(sphere(P["core"], (0, 0.215, 0.035), 0.013, seg=10, rings=8))
    p += grip(m["black"], (0, -0.005, -0.04), (0.032, 0.04, 0.09), -0.25, m["poly"])
    p += trigger(m["dark"], 0.03, -0.005)
    p += plasma_mag(P, (0, -0.012, -0.05), rot=(-0.25, 0, 0), s=0.7)
    save(p, "Plasma_pistol")

def plasma_cannon():
    """X-WEP-011: a long armoured body over the alien core, a wide emitter mouth, shoulder pad, front grip,
    the PL-MAG in a well under the body."""
    reset(); m, P = plasma_mats(); p = []
    p.append(bx(m["dark"], (0, 0.1, 0.04), (0.1, 0.5, 0.11), 0.012, seg=2))
    sh = cyl(P["shell"], (0, 0.5, 0.05), 0.05, 0.5, verts=16, rot=(PI2, 0, 0), r2=0.04)
    p.append(smooth(sh))
    for i in range(5):
        p.append(ring(P["shell2"], 0.32 + i * 0.075, 0.05, 0.052 - i * 0.002, 0.022, verts=16))
    for i in range(4):
        p.append(bx(P["core"], (0, 0.34 + i * 0.075, 0.104), (0.018, 0.035, 0.006), 0.001))
    p.append(sphere(P["core"], (0, 0.76, 0.05), 0.035, seg=14, rings=10))
    for k in range(4):                                                                   # the mouth's prongs
        a = k / 4 * math.tau + 0.785
        p.append(tb(P["shell2"], (math.cos(a) * 0.035, 0.72, 0.05 + math.sin(a) * 0.035), (math.cos(a) * 0.05, 0.84, 0.05 + math.sin(a) * 0.05), 0.008, 8, r2=0.004))
    p += grip(m["black"], (0, 0.0, -0.07), (0.04, 0.05, 0.11), -0.25, m["poly"])
    p += trigger(m["dark"], 0.045, -0.01)
    p.append(bx(m["black"], (0, 0.432, -0.05), (0.03, 0.04, 0.08), 0.006, seg=2))          # front grip
    p.append(ring(m["dark"], 0.432, 0.05, 0.0495, 0.022, verts=16))                      # its clamp round the barrel
    p.append(bx(m["dark"], (0, 0.432, -0.004), (0.026, 0.03, 0.024), 0.003))              # clamp foot down to the grip
    p += plasma_mag(P, (0, 0.18, -0.04), s=1.0)
    p.append(bx(m["black"], (0, -0.22, 0.04), (0.08, 0.16, 0.12), 0.01, seg=2))           # rear block
    p.append(bx(m["rubber"], (0, -0.31, 0.03), (0.085, 0.02, 0.14), 0.004, seg=2))        # shoulder pad
    p.append(bx(m["dark"], (0, 0.1, 0.12), (0.025, 0.2, 0.03), 0.006, seg=2))             # carry handle
    save(p, "Plasma_cannon")

def plasma_minigun():
    """X-WEP-012: the minigun's frame and grips, two PL-MAGs in a feed block where the ammo box was, and a
    rotor of six alien emitter tubes - a separate mesh "MinigunBarrels" the game spins."""
    reset(); m, P = plasma_mats(); p = []
    hs = cyl(m["dark"], (0, 0.05, 0.05), 0.07, 0.22, verts=18, rot=(PI2, 0, 0))
    p.append(smooth(bev(hs, 0.006)))
    for i in range(6):
        p.append(ring(P["shell2"], -0.04 + i * 0.035, 0.05, 0.074, 0.008, verts=18))
    p.append(bx(m["olive"], (0, -0.12, 0.03), (0.12, 0.16, 0.12), 0.01, seg=2))
    p.append(bx(P["core"], (0.061, -0.15, 0.08), (0.004, 0.01, 0.006), 0.001))
    p.append(bx(m["dark"], (0, -0.0, 0.16), (0.03, 0.3, 0.03), 0.006, seg=2))             # top handle
    p.append(bx(m["dark"], (0, -0.12, 0.12), (0.03, 0.03, 0.08), 0.004))
    p.append(bx(m["dark"], (0, 0.12, 0.12), (0.03, 0.03, 0.08), 0.004))
    p += grip(m["black"], (0, -0.02, -0.06), (0.04, 0.05, 0.12), -0.3, m["poly"])
    p += trigger(m["dark"], 0.02, -0.01)
    p.append(bx(P["shell"], (-0.12, -0.05, -0.02), (0.1, 0.16, 0.12), 0.01, seg=2))      # feed block
    for k in range(2):
        p += plasma_mag(P, (-0.12, -0.09 + k * 0.08, -0.1), s=0.9)
    body = join(p, "Plasma_minigun")
    q = []
    for i in range(6):
        a = i / 6 * math.tau
        x, z = math.cos(a) * 0.036, 0.05 + math.sin(a) * 0.036
        q.append(ty(P["shell"], 0.16, 0.8, z, 0.013, x=x, verts=10))
        q.append(sphere(P["core"], (x, 0.805, z), 0.009, seg=8, rings=6))
    for y, r in ((0.3, 0.058), (0.55, 0.058), (0.75, 0.056)):
        q.append(ring(P["shell2"], y, 0.05, r, 0.025, verts=16))
        q.append(ring(P["core"], y + 0.014, 0.05, r + 0.001, 0.003, verts=16))
    q.append(ty(m["dark"], 0.16, 0.8, 0.05, 0.012, verts=8))
    for o in q:
        for v in o.data.vertices:
            v.co.z -= 0.05
    barrels = join(q, "MinigunBarrels")
    barrels.location = (0, 0, 0.05)
    export_glb(os.path.join(OUTDIR, "plasma_minigun.glb"), [body, barrels])

def plasma_grenade():
    """X-WEP-010: a PL-MAG-01 cell in a squat alloy casing with a ring of green windows and a pressure cap."""
    reset(); m, P = plasma_mats(); p = []
    p.append(smooth(cyl(P["mag"], (0, 0, 0.0), 0.032, 0.075, verts=16)))
    for k in range(6):
        a = k / 6 * math.tau
        p.append(bx(P["core"], (math.cos(a) * 0.031, math.sin(a) * 0.031, 0.0), (0.006, 0.006, 0.04), 0.001, rot=(0, 0, a)))
    p.append(smooth(cyl(P["shell2"], (0, 0, 0.042), 0.026, 0.012, verts=16)))
    p.append(smooth(cyl(m["dark"], (0, 0, 0.052), 0.01, 0.012, verts=10)))
    p.append(smooth(cyl(P["shell2"], (0, 0, -0.042), 0.03, 0.01, verts=16)))
    p.append(bx(m["dark"], (0.03, 0, 0.03), (0.006, 0.012, 0.03), 0.002))                 # the lever
    save(p, "Plasma_grenade")

ALL = dict(rifle=rifle, pistol=pistol, shotgun=shotgun, magnum=magnum, sniper=sniper, autocannon=autocannon,
           minigun=minigun, rocket=rocket, plasma_rifle=plasma_rifle, laser_pistol=laser_pistol,
           laser_rifle=laser_rifle, laser_cannon=laser_cannon, baton=baton, knife=knife, smoke=smoke,
           mine=mine, handheld=handheld, energo_nuz=energo_nuz, laser_minigun=laser_minigun,
           jet_laser_mg=jet_laser_mg, jet_laser_cannon=jet_laser_cannon, plasma_pistol=plasma_pistol,
           plasma_cannon=plasma_cannon, plasma_minigun=plasma_minigun, plasma_grenade=plasma_grenade)
for k, f in ALL.items():
    if not ONLY or k in ONLY:
        f()
        print("built", k)

if "--gallery" in sys.argv:
    out = sys.argv[sys.argv.index("--gallery") + 1]
    names = sys.argv[sys.argv.index("--gallery") + 2].split(",") if len(sys.argv) > sys.argv.index("--gallery") + 2 and not sys.argv[sys.argv.index("--gallery") + 2].startswith("--") else \
        ["rifle", "pistol", "shotgun", "magnum", "sniper", "autocannon", "minigun", "rocket_launcher", "plasma_rifle", "laser_pistol", "laser_rifle", "laser_cannon"]
    reset()
    cols = int(sys.argv[sys.argv.index('--cols') + 1]) if '--cols' in sys.argv else 3
    for i, n in enumerate(names):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=os.path.join(OUTDIR, n + ".glb"))
        for o in set(bpy.data.objects) - before:
            if o.parent is None:
                o.rotation_mode = 'XYZ'
                o.location = ((i % cols) * 1.5 - (cols - 1) * 0.75, 0, -(i // cols) * 0.45)
                o.rotation_euler = (0, 0, -PI2)
    rows = (len(names) + cols - 1) // cols
    preview(out, target=(0.0, 0, -(rows - 1) * 0.225), dist=(1.2 + cols * 0.75) * 1.25, angle=0.0, height=0.0, res=(1280, 260 + rows * 200))
