"""Enemy Beyond 0.50 - the war comes to the map (after Ari's mood pictures: burnt farms, a ruined town,
a snowed-in cabin, a jungle station, a desert outpost - and everywhere the violet glow of the invaders).
Own designs. Each prop: visual pieces joined + "*-colonly" boxes for collision.
Front = +Y (Godot -Z). Origin on the ground in the middle.
Run: python3 tools/blender/warzone.py <outdir> [--only a,b] [--gallery out.png]"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
from common import *
from common import _finish
from mathutils import Vector

ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
OUTDIR = ARGS[0] if ARGS else "."
ONLY = sys.argv[sys.argv.index("--only") + 1].split(",") if "--only" in sys.argv else []
TAU = math.tau
PI2 = math.pi / 2

def mat2(name, rgb, rough=0.8, metal=0.0, emit=0.0):
    m = mat(name, rgb, emit=emit, rough=rough)
    m.node_tree.nodes.get("Principled BSDF").inputs["Metallic"].default_value = metal
    return m

def M():
    return dict(
        soot=mat2("WSoot", (0.06, 0.055, 0.05), 0.95), char=mat2("WCharred", (0.13, 0.1, 0.08), 0.9),
        rust=mat2("WRust", (0.36, 0.17, 0.08), 0.85, 0.3), rust2=mat2("WRustDark", (0.22, 0.11, 0.06), 0.9, 0.3),
        steel=mat2("WSteel", (0.32, 0.33, 0.35), 0.45, 0.8), dsteel=mat2("WSteelDark", (0.14, 0.15, 0.16), 0.5, 0.7),
        concrete=mat2("WConcrete", (0.46, 0.45, 0.42), 0.95), concrete2=mat2("WConcreteDark", (0.3, 0.29, 0.27), 0.95),
        olive=mat2("WOlive", (0.24, 0.26, 0.16), 0.8), olive2=mat2("WOliveDark", (0.15, 0.17, 0.11), 0.8),
        sand=mat2("WSandPaint", (0.55, 0.47, 0.32), 0.85), tyre=mat2("WTyre", (0.035, 0.035, 0.035), 0.95),
        ember=mat2("WEmber", (1.0, 0.38, 0.08), emit=3.0), red=mat2("WRedLight", (1.0, 0.1, 0.05), emit=5.0),
        white=mat2("WWhitePaint", (0.78, 0.78, 0.74), 0.8), wood=mat2("WOldWood", (0.3, 0.21, 0.13), 0.9),
        blue=mat2("WSignBlue", (0.12, 0.2, 0.42), 0.6), yellow=mat2("WSignYellow", (0.7, 0.55, 0.1), 0.7),
        glass=mat2("WGlass", (0.08, 0.1, 0.12), 0.1, 0.3),
        # the invaders: dark alloy with violet light in its seams
        alloy=mat2("WAlienAlloy", (0.16, 0.12, 0.17), 0.35, 0.7), alloy2=mat2("WAlienAlloyDark", (0.08, 0.06, 0.09), 0.4, 0.7),
        violet=mat2("WVioletGlow", (0.85, 0.25, 1.0), emit=4.0), violet2=mat2("WVioletDim", (0.55, 0.15, 0.7), emit=1.6),
        flesh=mat2("WAlienGrowth", (0.22, 0.1, 0.2), 0.6),
    )

def colbox(name, loc, size, rot=(0, 0, 0)):
    o = box(mat("Col", (1, 0, 1)), loc, size, rot=rot)
    o.name = name + "-colonly"
    return o

def _sel(o):
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True)
    bpy.context.view_layer.objects.active = o

def bev(o, w, seg=1):
    _sel(o)
    m = o.modifiers.new("Bevel", 'BEVEL'); m.width = w; m.segments = seg; m.limit_method = 'ANGLE'
    bpy.ops.object.modifier_apply(modifier="Bevel")
    return o

def smooth(o):
    for p in o.data.polygons:
        p.use_smooth = True
    return o

def bx(m, c, s, b=0.02, rot=(0, 0, 0)):
    return bev(box(m, c, s, rot=rot), min(b, min(s) * 0.3))

def tb(m, a, b, r, verts=8, r2=None, sm=True):
    a = Vector(a); b = Vector(b); d = b - a
    o = cyl(m, (0, 0, 0), r, max(d.length, 1e-4), verts=verts, r2=r2)
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    for v in o.data.vertices:
        v.co = q @ v.co + (a + b) / 2
    return smooth(o) if sm else o

def jitter(o, amt, seed):
    r = random.Random(seed)
    for v in o.data.vertices:
        v.co += Vector((r.uniform(-amt, amt), r.uniform(-amt, amt), r.uniform(-amt, amt)))
    return o

def save(name, vis, col):
    o = join(vis, name)
    export_glb(os.path.join(OUTDIR, "v_%s.glb" % name.lower()), [o] + col)

# ==================================================================================================
def car_burnt():
    """A burnt-out hatchback: charred shell, no glass, bare rims, rust bleeding through, a few embers."""
    reset(); m = M(); v = []
    body = box(m["char"], (0, 0, 0.62), (1.66, 3.9, 0.62))
    for vt in body.data.vertices:
        if vt.co.y > 1.5:
            vt.co.z -= 0.12 if vt.co.z > 0.62 else 0.0        # bonnet slopes
    v.append(bev(body, 0.06))
    v.append(jitter(bx(m["rust"], (0, 1.75, 0.66), (1.6, 0.5, 0.36), 0.03), 0.03, 1))          # crumpled bonnet
    # cabin: four pillars and a sagging roof, no glass
    for x in (-0.72, 0.72):
        for y, lean in ((1.05, -0.45), (-1.3, 0.25), (-0.15, 0.0)):
            v.append(tb(m["soot"], (x, y, 0.92), (x * 0.92, y + lean * 0.4, 1.42), 0.045, 6))
    roof = box(m["rust2"], (0, -0.2, 1.44), (1.42, 1.9, 0.05))
    for vt in roof.data.vertices:
        vt.co.z -= 0.08 * math.cos(vt.co.y * 1.4) + (0.06 if vt.co.x > 0 else 0)
    v.append(roof)
    v.append(bx(m["soot"], (0, -0.2, 0.95), (1.3, 1.6, 0.08), 0.01))                            # what is left of the seats
    for x in (-0.42, 0.42):
        v.append(bx(m["soot"], (x, -0.55, 1.1), (0.45, 0.12, 0.4), 0.02, rot=(0.25, 0, 0)))
    v.append(bx(m["dsteel"], (0, 1.97, 0.45), (1.7, 0.14, 0.18), 0.03))                          # bumpers
    v.append(bx(m["dsteel"], (0, -1.97, 0.45), (1.7, 0.14, 0.18), 0.03))
    for x in (-0.82, 0.82):                                                                      # bare rims on the ground
        for y in (1.25, -1.2):
            rim = cyl(m["dsteel"], (x, y, 0.27), 0.27, 0.16, verts=12, rot=(0, PI2, 0))
            v.append(smooth(rim))
            v.append(smooth(cyl(m["soot"], (x * 1.01, y, 0.27), 0.12, 0.17, verts=8, rot=(0, PI2, 0))))
    for k, (x, y) in enumerate(((0.3, 0.2), (-0.4, -0.6), (0.1, -1.4))):                       # embers in the cabin
        v.append(jitter(box(m["ember"], (x, y, 1.0), (0.18, 0.14, 0.05)), 0.02, k))
    v.append(bx(m["rust"], (0.84, 0.2, 0.62), (0.03, 2.6, 0.4), 0.01))                          # rusted flanks
    v.append(bx(m["rust"], (-0.84, -0.3, 0.6), (0.03, 2.2, 0.35), 0.01))
    save("Car_burnt", v, [colbox("car", (0, 0, 0.75), (1.7, 4.0, 1.5))])

def humvee_wreck():
    """A military truck sunk in sand to the axles: sand paint gone to rust, shattered windows, a crate."""
    reset(); m = M(); v = []
    v.append(bx(m["sand"], (0, 0.2, 0.85), (2.2, 4.6, 0.8), 0.08))
    hood = box(m["sand"], (0, 1.7, 1.25), (2.0, 1.5, 0.12))
    v.append(bev(hood, 0.03))
    v.append(bx(m["sand"], (0, -0.4, 1.65), (2.1, 2.2, 0.85), 0.06))                            # cabin
    v.append(bx(m["dsteel"], (0, 0.73, 1.65), (1.9, 0.06, 0.6), 0.01, rot=(-0.3, 0, 0)))         # windscreen frame
    v.append(jitter(bx(m["glass"], (0.45, 0.75, 1.67), (0.8, 0.03, 0.45), 0.005, rot=(-0.3, 0, 0)), 0.02, 3))
    for k in range(5):                                                                           # grille
        v.append(bx(m["dsteel"], (-0.7 + k * 0.35, 2.47, 0.95), (0.12, 0.06, 0.5), 0.01))
    v.append(bx(m["dsteel"], (0, 2.5, 0.6), (2.2, 0.2, 0.2), 0.03))
    for x in (-1.0, 1.0):
        for y in (1.6, -1.4):
            v.append(smooth(cyl(m["tyre"], (x, y, 0.3), 0.5, 0.42, verts=14, rot=(0, PI2, 0))))
    v.append(jitter(bx(m["rust"], (0.8, -0.4, 1.3), (0.6, 1.8, 0.5), 0.03), 0.04, 5))           # rust patches
    v.append(jitter(bx(m["rust2"], (-0.6, 1.6, 1.32), (0.7, 0.8, 0.1), 0.02), 0.03, 6))
    v.append(bx(m["olive2"], (0.4, -1.8, 1.45), (0.9, 0.6, 0.45), 0.03))                        # a crate on the back
    v.append(bx(m["white"], (0.4, -2.11, 1.45), (0.4, 0.01, 0.1), 0.003))
    v.append(tb(m["dsteel"], (-0.9, -1.0, 2.05), (-0.9, -1.0, 3.2), 0.02, 6))                   # whip antenna
    # sand piled against it
    for k, (x, y, s) in enumerate(((1.4, 0.5, 1.6), (-1.3, -0.5, 1.4), (0.2, 2.8, 1.2))):
        d = smooth(sphere(m["sand"], (x, y, 0.0), s, seg=12, rings=6, scale=(0.6, 1.4, 0.35)))
        d.data.materials.clear(); d.data.materials.append(mat2("WSandDrift", (0.62, 0.45, 0.3), 0.95))
        v.append(d)
    save("Humvee_wreck", v, [colbox("hum", (0, 0.2, 1.0), (2.3, 5.0, 2.0))])

def radar_dish():
    """A tracking dish on a concrete plinth: pylon, yoke, the dish with a feed horn - one panel torn out."""
    reset(); m = M(); v = []
    v.append(bx(m["concrete"], (0, 0, 0.6), (3.0, 3.0, 1.2), 0.08))
    v.append(bx(m["concrete2"], (0, 0, 1.25), (2.2, 2.2, 0.1), 0.03))
    v.append(smooth(cyl(m["steel"], (0, 0, 2.4), 0.45, 2.2, verts=14)))
    v.append(smooth(cyl(m["dsteel"], (0, 0, 3.6), 0.7, 0.3, verts=16)))
    for x in (-0.65, 0.65):
        v.append(bx(m["steel"], (x, 0, 4.4), (0.18, 0.5, 1.5), 0.04))
    # the dish (a shallow bowl), tipped back toward the sky
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=3.0)
    d = bpy.context.active_object
    for vt in d.data.vertices:
        if vt.co.z > -2.2:
            vt.co.z = -2.2 + (vt.co.z + 2.2) * 0.05
    _finish(d, m["white"], (0, 0, 0), (0, 0, 0), (1, 1, 1))
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.object.mode_set(mode='OBJECT')
    for vt in d.data.vertices:
        vt.co.z += 2.2
    smooth(d)
    dish = [d]
    for k in range(8):
        a = k / 8 * TAU
        dish.append(tb(m["steel"], (math.cos(a) * 2.9, math.sin(a) * 2.9, 0.82), (0, 0, 2.1), 0.03, 5))
    dish.append(tb(m["dsteel"], (0, 0, 0.0), (0, 0, 2.2), 0.12, 10))
    dish.append(smooth(cyl(m["dsteel"], (0, 0, 2.3), 0.2, 0.25, verts=10)))
    dish.append(box(m["red"], (0, 0, 2.45), (0.08, 0.08, 0.06)))
    dobj = join(dish, "DishPart")
    for vt in dobj.data.vertices:          # cut a ragged hole in one side (a torn panel)
        if vt.co.x > 1.6 and vt.co.y > 0.4 and vt.co.y < 1.8 and vt.co.z < 1.0:
            vt.co.z += 0.5
    dobj.scale = (0.7, 0.7, 0.7)
    dobj.rotation_euler = (-0.75, 0, 0.4)
    dobj.location = (0, 0, 4.6)
    _sel(dobj); bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    v.append(dobj)
    v.append(bx(m["dsteel"], (1.55, 0, 0.9), (0.06, 0.8, 0.6), 0.01))                          # a cabinet
    v.append(box(m["violet2"], (1.585, 0.2, 1.0), (0.01, 0.12, 0.08)))
    save("Radar_dish", v, [colbox("base", (0, 0, 0.6), (3.0, 3.0, 1.2)), colbox("pylon", (0, 0, 2.6), (0.9, 0.9, 2.8))])

def radio_tower():
    """A lattice radio mast, 14 m, with a blinking red light and a few dishes; one leg bent."""
    reset(); m = M(); v = []
    H = 14.0
    def at(k, z):
        w = 1.3 * (1 - z / H * 0.7)
        a = k / 3 * TAU + 0.5
        return Vector((math.cos(a) * w, math.sin(a) * w, z))
    for k in range(3):
        v.append(tb(m["rust"], tuple(at(k, 0)), tuple(at(k, H)), 0.06, 6))
    n = 10
    for i in range(n):
        z0, z1 = H * i / n, H * (i + 1) / n
        for k in range(3):
            a0, b0 = at(k, z0), at((k + 1) % 3, z0)
            a1, b1 = at(k, z1), at((k + 1) % 3, z1)
            v.append(tb(m["steel"], tuple(a0), tuple(b1), 0.025, 4, sm=False))
            v.append(tb(m["steel"], tuple(a0), tuple(b0), 0.025, 4, sm=False))
    for k in range(3):
        v.append(bx(m["concrete"], tuple(at(k, 0.2)), (0.6, 0.6, 0.4), 0.04))
    v.append(tb(m["dsteel"], (0, 0, H), (0, 0, H + 2.0), 0.05, 6))
    v.append(smooth(sphere(m["red"], (0, 0, H + 2.05), 0.12, seg=10, rings=6)))
    for z, a in ((9.0, 0.3), (11.5, 2.4)):
        w = 1.3 * (1 - z / H * 0.7) * 0.5 + 0.15
        c = Vector((math.cos(a) * w, math.sin(a) * w, z))
        bpy.ops.mesh.primitive_uv_sphere_add(segments=14, ring_count=8, radius=0.6)
        d = bpy.context.active_object
        for vt in d.data.vertices:
            if vt.co.x > -0.45:
                vt.co.x = -0.45 + (vt.co.x + 0.45) * 0.08
        _finish(d, m["white"], tuple(c), (0, 0, a + math.pi), (1, 1, 1))
        v.append(smooth(d))
    for k in range(3):                                                                           # panel antennas
        c = at(k, 12.6)
        v.append(bx(m["white"], tuple(c * 1.1 + Vector((0, 0, 0)) * 0), (0.25, 0.12, 1.2), 0.02, rot=(0, 0, k / 3 * TAU)))
    v.append(box(m["violet"], tuple(at(1, 6.0)), (0.12, 0.12, 0.25)))                           # something of theirs on it
    save("Radio_tower", v, [colbox("t", (0, 0, 3.0), (1.6, 1.6, 6.0))])

def alien_spike():
    """A cluster of their crystal-metal blades bursting from the ground, violet light in the seams."""
    reset(); m = M(); v = []
    r = random.Random(7)
    blades = [(0, 0, 4.2, 0.0, 0.0), (0.9, 0.3, 2.8, 0.35, 0.6), (-0.8, 0.5, 3.2, -0.3, 2.2), (0.2, -0.9, 2.2, 0.25, 4.0), (-0.5, -0.6, 1.6, -0.4, 5.0)]
    for i, (x, y, h, lean, yaw) in enumerate(blades):
        o = cyl(m["alloy"], (0, 0, h / 2), 0.45 * (h / 4.2) ** 0.5, h, verts=5, r2=0.0)
        for vt in o.data.vertices:
            vt.co.x *= 0.55
        o.rotation_euler = (lean, 0.0, yaw)
        o.location = (x, y, -0.2)
        _sel(o); bpy.ops.object.transform_apply(location=True, rotation=True)
        v.append(o)
        s = cyl(m["violet"], (0, 0.0, h * 0.4), 0.06, h * 0.7, verts=4, r2=0.0)                 # the glowing seam
        for vt in s.data.vertices:
            vt.co.x = vt.co.x * 0.3 + 0.255 * (h / 4.2) ** 0.5 * (1 - (vt.co.z) / (h * 0.8))
        s.rotation_euler = (lean, 0.0, yaw); s.location = (x, y, -0.2)
        _sel(s); bpy.ops.object.transform_apply(location=True, rotation=True)
        v.append(s)
    for k in range(9):                                                                           # broken ground around it
        a = k / 9 * TAU + r.uniform(0, 0.4)
        rr = r.uniform(1.2, 2.0)
        v.append(jitter(bx(m["concrete2"], (math.cos(a) * rr, math.sin(a) * rr, 0.08), (r.uniform(0.4, 0.8), r.uniform(0.3, 0.6), 0.25), 0.04, rot=(r.uniform(-0.4, 0.4), r.uniform(-0.4, 0.4), a)), 0.05, k))
    for k in range(4):
        a = k / 4 * TAU + 0.4
        v.append(box(m["violet2"], (math.cos(a) * 1.6, math.sin(a) * 1.6, 0.02), (1.8, 0.06, 0.02), rot=(0, 0, a)))
    save("Alien_spike", v, [colbox("s", (0, 0, 1.6), (1.6, 1.6, 3.2))])

def alien_pod():
    """One of their pods: a ribbed egg of dark alloy, cracked open, violet light inside, roots in the ground."""
    reset(); m = M(); v = []
    egg = sphere(m["alloy"], (0, 0, 1.2), 1.0, seg=20, rings=14, scale=(0.75, 0.75, 1.3))
    smooth(egg)
    v.append(egg)
    for k in range(8):                                                                           # ribs
        a = k / 8 * TAU
        rib = cyl(m["alloy2"], (0, 0, 1.2), 0.08, 2.4, verts=6)
        for vt in rib.data.vertices:
            t = (vt.co.z - 1.2) / 1.2
            rr = 0.8 * math.sqrt(max(0.0, 1 - t * t)) + 0.02
            vt.co.x += math.cos(a) * rr
            vt.co.y += math.sin(a) * rr
        v.append(smooth(rib))
    for k in range(3):                                                                           # glowing slits
        a = k / 3 * TAU + 0.3
        s = box(m["violet"], (math.cos(a) * 0.77, math.sin(a) * 0.77, 1.25), (0.05, 0.12, 1.3), rot=(0, 0, a))
        v.append(s)
    v.append(smooth(sphere(m["violet2"], (0, 0, 2.55), 0.18, seg=10, rings=6)))
    r = random.Random(11)
    for k in range(7):                                                                           # roots
        a = k / 7 * TAU + r.uniform(0, 0.5)
        p0 = Vector((math.cos(a) * 0.5, math.sin(a) * 0.5, 0.35))
        p1 = Vector((math.cos(a) * 1.7, math.sin(a) * 1.7, 0.02))
        v.append(tb(m["flesh"], tuple(p0), tuple(p1), 0.12, 6, r2=0.03))
        v.append(box(m["violet2"], tuple((p0 + p1) / 2 + Vector((0, 0, 0.1))), (0.04, 0.4, 0.03), rot=(0, 0, a + PI2)))
    save("Alien_pod", v, [colbox("p", (0, 0, 1.2), (1.4, 1.4, 2.6))])

def alien_veins():
    """Violet veins spreading over the ground from where they landed (flat, no collision)."""
    reset(); m = M(); v = []
    r = random.Random(3)
    def branch(p, a, length, w, depth):
        if depth > 3 or length < 0.4:
            return
        n = 4
        for i in range(n):
            a += r.uniform(-0.45, 0.45)
            q = p + Vector((math.cos(a), math.sin(a), 0)) * (length / n)
            mtl = m["violet"] if depth < 2 else m["violet2"]
            v.append(tb(mtl, (p.x, p.y, 0.03), (q.x, q.y, 0.03), w, 4, sm=False))
            p = q
            if r.random() < 0.45:
                branch(p, a + r.choice((-1, 1)) * r.uniform(0.5, 1.1), length * 0.55, w * 0.65, depth + 1)
    for k in range(5):
        branch(Vector((0, 0, 0)), k / 5 * TAU + r.uniform(0, 0.6), r.uniform(3.0, 4.5), 0.05, 0)
    v.append(smooth(sphere(m["flesh"], (0, 0, 0.0), 0.6, seg=12, rings=6, scale=(1, 1, 0.3))))
    save("Alien_veins", v, [])

def barbed_fence():
    """4 m of wire fence: angle-iron posts, sagging strands, coils of barbed wire on top, one post bent."""
    reset(); m = M(); v = []
    for i, x in enumerate((-2.0, 0.0, 2.0)):
        lean = 0.25 if i == 2 else 0.0
        v.append(tb(m["rust"], (x, 0, 0), (x + lean * 0.5, lean * 0.4, 1.8), 0.035, 4, sm=False))
        v.append(tb(m["rust"], (x + lean * 0.5, lean * 0.4, 1.8), (x + lean * 0.5, -0.25, 2.05), 0.025, 4, sm=False))
    for z in (0.4, 0.8, 1.2, 1.6):
        pts = [Vector((-2.0 + k * 0.5, 0, z - 0.08 * math.sin(k / 8 * math.pi * 2) ** 2)) for k in range(9)]
        for a, b in zip(pts, pts[1:]):
            v.append(tb(m["dsteel"], tuple(a), tuple(b), 0.006, 3, sm=False))
    for k in range(36):                                                                          # coil
        t = k / 36
        a = t * 16 * math.pi
        p = Vector((-2.0 + t * 4.0, -0.12 + math.sin(a) * 0.18, 2.05 + math.cos(a) * 0.18))
        q = Vector((-2.0 + (t + 1 / 36) * 4.0, -0.12 + math.sin(a + 16 * math.pi / 36) * 0.18, 2.05 + math.cos(a + 16 * math.pi / 36) * 0.18))
        v.append(tb(m["steel"], tuple(p), tuple(q), 0.008, 3, sm=False))
    save("Barbed_fence", v, [colbox("f", (0, 0, 1.0), (4.0, 0.1, 2.0))])

def mil_crates():
    """An abandoned supply dump: olive ammo crates, a fuel drum, a tarp."""
    reset(); m = M(); v = []
    for (x, y, z, w, d, h, yaw) in ((0, 0, 0.3, 1.2, 0.6, 0.6, 0.0), (0.05, 0.0, 0.9, 1.2, 0.6, 0.6, 0.1),
                                    (1.25, 0.1, 0.3, 1.2, 0.6, 0.6, -0.05), (0.6, 0.9, 0.25, 0.8, 0.5, 0.5, 0.6)):
        v.append(bx(m["olive"], (x, y, z), (w, d, h), 0.03, rot=(0, 0, yaw)))
        v.append(bx(m["olive2"], (x, y, z + h / 2 - 0.02), (w * 1.02, d * 1.02, 0.06), 0.01, rot=(0, 0, yaw)))
        v.append(box(m["yellow"], (x + math.sin(yaw) * 0.0, y - d / 2 - 0.006, z), (w * 0.4, 0.01, 0.08)))
        for sx in (-1, 1):
            v.append(bx(m["dsteel"], (x + sx * w / 2.02 * math.cos(yaw), y + sx * w / 2.02 * math.sin(yaw), z), (0.04, 0.1, 0.05), 0.01, rot=(0, 0, yaw)))
    for k, (x, y) in enumerate(((-1.0, 0.4), (-1.2, -0.4))):
        dr = cyl(m["rust"] if k else m["olive2"], (x, y, 0.45), 0.3, 0.9, verts=16)
        v.append(smooth(dr))
        for z in (0.2, 0.7):
            v.append(smooth(cyl(m["dsteel"], (x, y, z), 0.31, 0.04, verts=16)))
    tarp = box(mat2("WTarp", (0.2, 0.24, 0.17), 0.95), (0.3, 0.0, 1.25), (1.6, 1.0, 0.04))
    _sel(tarp)
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.subdivide(number_cuts=6); bpy.ops.object.mode_set(mode='OBJECT')
    for vt in tarp.data.vertices:
        e = max(abs(vt.co.x - 0.3) / 0.8, abs(vt.co.y) / 0.5)
        if e > 0.75:
            vt.co.z -= (e - 0.75) * 1.2
    v.append(smooth(tarp))
    save("Mil_crates", v, [colbox("c", (0.2, 0.2, 0.6), (2.6, 1.4, 1.2))])

def rubble():
    """A heap of broken concrete with rebar sticking out (ruined towns)."""
    reset(); m = M(); v = []
    r = random.Random(5)
    for k in range(18):
        a = r.uniform(0, TAU); d = r.uniform(0, 1.8)
        z = max(0.1, 0.9 - d * 0.45) * r.uniform(0.5, 1.0)
        s = (r.uniform(0.4, 1.2), r.uniform(0.3, 0.9), r.uniform(0.15, 0.4))
        o = bx(m["concrete"] if k % 3 else m["concrete2"], (math.cos(a) * d, math.sin(a) * d, z), s, 0.03,
               rot=(r.uniform(-0.6, 0.6), r.uniform(-0.6, 0.6), r.uniform(0, TAU)))
        v.append(jitter(o, 0.05, k))
    for k in range(7):
        a = r.uniform(0, TAU); d = r.uniform(0, 1.2)
        p = Vector((math.cos(a) * d, math.sin(a) * d, 0.5))
        q = p + Vector((r.uniform(-0.7, 0.7), r.uniform(-0.7, 0.7), r.uniform(0.4, 1.0)))
        v.append(tb(m["rust"], tuple(p), tuple(q), 0.015, 4, sm=False))
        v.append(tb(m["rust"], tuple(q), tuple(q + Vector((r.uniform(-0.3, 0.3), r.uniform(-0.3, 0.3), -0.2))), 0.015, 4, sm=False))
    v.append(bx(m["white"], (0.9, -0.3, 0.35), (1.0, 0.08, 0.6), 0.01, rot=(0.9, 0.2, 0.5)))   # a bit of painted wall
    save("Rubble", v, [colbox("r", (0, 0, 0.45), (2.6, 2.6, 0.9))])

def silo():
    """A farm grain silo: corrugated steel, a domed cap, a cage ladder - scorched up one side."""
    reset(); m = M(); v = []
    R, H = 2.4, 8.5
    v.append(smooth(cyl(m["steel"], (0, 0, H / 2), R, H, verts=28)))
    for k in range(10):
        v.append(smooth(cyl(m["dsteel"], (0, 0, 0.4 + k * 0.85), R + 0.03, 0.06, verts=28)))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=28, ring_count=10, radius=R + 0.05)
    d = bpy.context.active_object
    for vt in d.data.vertices:
        vt.co.z = max(vt.co.z, 0.0) * 0.45
    _finish(d, m["steel"], (0, 0, H), (0, 0, 0), (1, 1, 1))
    v.append(smooth(d))
    v.append(smooth(cyl(m["dsteel"], (0, 0, H + 1.15), 0.35, 0.3, verts=12)))
    v.append(bx(m["concrete"], (0, 0, 0.15), (R * 2.3, R * 2.3, 0.3), 0.05))
    for x in (-0.25, 0.25):                                                                     # ladder
        v.append(tb(m["dsteel"], (x, -R - 0.15, 0.3), (x, -R - 0.15, H + 0.3), 0.03, 5))
    for k in range(28):
        v.append(tb(m["dsteel"], (-0.25, -R - 0.15, 0.6 + k * 0.3), (0.25, -R - 0.15, 0.6 + k * 0.3), 0.02, 4, sm=False))
    for k in range(9):
        a = k / 9 * math.pi
        v.append(tb(m["dsteel"], (math.cos(a) * 0.4, -R - 0.15 - math.sin(a) * 0.4, 3.0), (math.cos(a) * 0.4, -R - 0.15 - math.sin(a) * 0.4, H), 0.015, 4, sm=False))
    sc = cyl(m["soot"], (0, 0, H * 0.45), R + 0.02, H * 0.9, verts=28)                        # scorch up one side
    for vt in sc.data.vertices:
        if vt.co.x < 0.6 or vt.co.y > 0.3:
            vt.co *= 0.98
    v.append(sc)
    v.append(jitter(bx(m["rust"], (R * 0.7, R * 0.65, 2.0), (0.6, 0.6, 1.8), 0.02, rot=(0, 0, 0.8)), 0.04, 2))
    save("Silo", v, [colbox("s", (0, 0, H / 2), (R * 1.9, R * 1.9, H))])

def snowmobile_wreck():
    reset(); m = M(); v = []
    v.append(bx(m["red"].copy() if False else mat2("WSledRed", (0.5, 0.08, 0.06), 0.6), (0, 0.2, 0.5), (0.9, 1.6, 0.45), 0.08))
    v.append(bx(m["soot"], (0, -0.6, 0.65), (0.75, 1.0, 0.25), 0.06))
    v.append(bx(mat2("WSledRed", (0.5, 0.08, 0.06), 0.6), (0, 0.95, 0.75), (0.8, 0.4, 0.3), 0.08, rot=(0.5, 0, 0)))
    v.append(jitter(bx(m["glass"], (0, 0.75, 1.0), (0.6, 0.05, 0.3), 0.01, rot=(-0.5, 0, 0.3)), 0.02, 1))
    v.append(tb(m["dsteel"], (-0.45, 0.55, 1.0), (0.45, 0.55, 1.0), 0.025, 6))
    for x in (-0.45, 0.45):                                                                     # skis
        v.append(bx(m["dsteel"], (x, 1.0, 0.08), (0.14, 1.0, 0.04), 0.01))
        v.append(bx(m["dsteel"], (x, 1.55, 0.15), (0.14, 0.2, 0.04), 0.01, rot=(0.6, 0, 0)))
    v.append(bx(m["tyre"], (0, -0.3, 0.2), (0.55, 1.5, 0.35), 0.06))
    save("Snowmobile_wreck", v, [colbox("s", (0, 0.2, 0.5), (1.1, 2.6, 1.0))])

def fallen_signal():
    """A toppled traffic light still glowing red, and a bent road sign (town streets)."""
    reset(); m = M(); v = []
    v.append(tb(m["dsteel"], (0, 0, 0.1), (3.6, 0.6, 0.25), 0.07, 8))
    v.append(bx(m["dsteel"], (3.9, 0.65, 0.3), (0.35, 0.3, 0.9), 0.04, rot=(0, PI2 - 0.1, 0.15)))
    for k, mm in enumerate((m["red"], m["soot"], m["soot"])):
        v.append(smooth(cyl(mm, (3.62 + k * 0.28, 0.48, 0.32), 0.09, 0.03, verts=12, rot=(PI2, 0, 0.15))))
    v.append(bx(m["concrete2"], (0, 0, 0.1), (0.5, 0.5, 0.2), 0.03))
    v.append(tb(m["dsteel"], (-1.5, 1.2, 0.0), (-1.4, 1.1, 1.3), 0.035, 6))
    v.append(tb(m["dsteel"], (-1.4, 1.1, 1.3), (-0.9, 1.4, 1.8), 0.035, 6))
    v.append(bx(m["blue"], (-0.75, 1.5, 1.95), (0.7, 0.04, 0.55), 0.01, rot=(0.1, 0.4, 0.3)))
    v.append(bx(m["white"], (-0.75, 1.475, 1.95), (0.08, 0.01, 0.35), 0.003, rot=(0.1, 0.4, 0.3)))
    save("Fallen_signal", v, [colbox("t", (1.8, 0.3, 0.3), (3.8, 0.8, 0.6))])

def crater():
    """A shell crater: a scorched dish with a thrown-up rim of earth and stones (flat, walkable)."""
    reset(); m = M(); v = []
    earth = mat2("WEarth", (0.24, 0.18, 0.12), 0.95)
    r = random.Random(9)
    bpy.ops.mesh.primitive_circle_add(vertices=28, radius=2.6, fill_type='TRIFAN')
    d = bpy.context.active_object
    _sel(d); bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.subdivide(number_cuts=3); bpy.ops.object.mode_set(mode='OBJECT')
    for vt in d.data.vertices:
        rr = Vector((vt.co.x, vt.co.y)).length / 2.6
        vt.co.z = -0.55 * max(0.0, 1 - rr * 1.4) ** 1.5 + 0.28 * math.exp(-((rr - 0.82) / 0.13) ** 2) + r.uniform(-0.03, 0.03)
    _finish(d, earth, (0, 0, 0.02), (0, 0, 0), (1, 1, 1))
    v.append(smooth(d))
    sc = smooth(sphere(m["soot"], (0, 0, -0.42), 1.1, seg=16, rings=6, scale=(1, 1, 0.12)))
    v.append(sc)
    for k in range(10):
        a = r.uniform(0, TAU); rr = r.uniform(2.1, 2.9)
        v.append(jitter(bx(m["concrete2"] if k % 2 else earth, (math.cos(a) * rr, math.sin(a) * rr, 0.12), (r.uniform(0.15, 0.4),) * 3, 0.03), 0.04, k))
    save("Crater", v, [])

def debris():
    """Smashed planks, a broken door, shingles and a bucket - what is left round a wrecked house."""
    reset(); m = M(); v = []
    r = random.Random(4)
    for k in range(14):
        a = r.uniform(0, TAU); d = r.uniform(0, 2.2)
        L = r.uniform(0.8, 2.4)
        v.append(bx(m["wood"] if k % 3 else m["char"], (math.cos(a) * d, math.sin(a) * d, 0.04 + r.uniform(0, 0.2)), (0.12, L, 0.035), 0.01,
                    rot=(r.uniform(-0.25, 0.25), r.uniform(-0.2, 0.2), r.uniform(0, TAU))))
    v.append(bx(m["wood"], (0.6, -0.4, 0.06), (0.85, 1.9, 0.05), 0.01, rot=(0.05, 0.08, 0.4)))      # a door
    v.append(bx(m["dsteel"], (0.75, -0.1, 0.1), (0.05, 0.12, 0.03), 0.005, rot=(0, 0, 0.4)))
    for k in range(8):
        v.append(bx(mat2("WShingle", (0.4, 0.15, 0.1), 0.85), (r.uniform(-1.5, 1.5), r.uniform(-1.5, 1.5), 0.03), (0.3, 0.2, 0.025), 0.005, rot=(0, 0, r.uniform(0, TAU))))
    v.append(smooth(cyl(m["dsteel"], (-1.2, 0.9, 0.15), 0.15, 0.3, verts=12, r2=0.12, rot=(PI2 * 0.95, 0, 0.6))))
    save("Debris", v, [])

def dead_tree():
    """A dead, blasted tree: bare trunk split at the top, twisted branches, roots clawing the ground."""
    reset(); m = M(); v = []
    bark = mat2("WDeadBark", (0.2, 0.16, 0.12), 0.95)
    r = random.Random(21)
    def limb(p, d, L, w, depth):
        q = p + d * L
        v.append(tb(bark, tuple(p), tuple(q), w, 6, r2=w * 0.7))
        if depth >= 3 or w < 0.025:
            return
        for k in range(r.choice((2, 2, 3))):
            nd = (d + Vector((r.uniform(-0.9, 0.9), r.uniform(-0.9, 0.9), r.uniform(-0.1, 0.5)))).normalized()
            limb(q, nd, L * r.uniform(0.55, 0.75), w * 0.6, depth + 1)
    limb(Vector((0, 0, 0)), Vector((0.05, 0.02, 1)).normalized(), 3.2, 0.28, 0)
    for k in range(6):
        a = k / 6 * TAU + r.uniform(0, 0.5)
        v.append(tb(bark, (0, 0, 0.35), (math.cos(a) * 1.3, math.sin(a) * 1.3, -0.1), 0.15, 6, r2=0.03))
    v.append(jitter(smooth(cyl(m["char"], (0.1, 0.05, 1.6), 0.2, 1.0, verts=8)), 0.03, 2))      # a burnt scar
    save("Dead_tree", v, [colbox("t", (0, 0, 1.6), (0.6, 0.6, 3.2))])

def broken_fence():
    """A wooden ranch fence, half of it knocked flat."""
    reset(); m = M(); v = []
    r = random.Random(8)
    for i, x in enumerate((-2.0, 0.0, 2.0)):
        lean = (0.0, 0.35, 1.2)[i]
        v.append(tb(m["wood"], (x, 0, -0.1), (x, -math.sin(lean) * 1.3, math.cos(lean) * 1.3), 0.07, 6))
    for z in (0.5, 1.0):
        v.append(bx(m["wood"], (-1.0, 0, z), (2.1, 0.06, 0.14), 0.01))
        v.append(bx(m["wood"], (1.0, -0.6 * z, z * 0.55), (2.1, 0.06, 0.14), 0.01, rot=(0.9 * z, 0.1, 0.05)))
    v.append(bx(m["char"], (1.4, -1.0, 0.04), (1.2, 0.06, 0.12), 0.01, rot=(0, 0, 0.5)))
    save("Broken_fence", v, [colbox("f", (-1.0, 0, 0.6), (2.1, 0.1, 1.2))])

def truck_wreck():
    """A burnt-out flatbed truck, cab torched, a load of crates spilled behind it."""
    reset(); m = M(); v = []
    v.append(bx(m["char"], (0, 2.3, 1.3), (2.2, 1.9, 1.7), 0.08))                                # cab
    v.append(bx(m["rust"], (0, 3.45, 0.95), (2.1, 0.6, 0.9), 0.06))                              # bonnet
    v.append(bx(m["soot"], (0, 3.0, 1.75), (1.9, 0.05, 0.7), 0.01, rot=(-0.25, 0, 0)))           # empty windscreen frame
    v.append(bx(m["dsteel"], (0, -0.9, 0.85), (2.3, 4.6, 0.18), 0.03))                           # flatbed
    for y in (-3.1, 1.25):
        v.append(bx(m["rust2"], (0, y, 1.3), (2.3, 0.1, 0.9), 0.02))
    v.append(bx(m["rust2"], (1.12, -0.9, 1.15), (0.08, 4.6, 0.45), 0.02, rot=(0.0, 0.5, 0.0)))  # side flap hanging open
    for x in (-1.0, 1.0):
        for y in (2.6, -0.4, -1.9):
            v.append(smooth(cyl(m["dsteel"] if y > 0 else m["tyre"], (x, y, 0.48), 0.48, 0.35, verts=14, rot=(0, PI2, 0))))
    for k, (x, y, z, yaw) in enumerate(((0.4, -1.5, 1.25, 0.2), (-0.5, -0.2, 1.25, -0.1), (1.9, -3.6, 0.3, 0.9), (2.4, -2.6, 0.3, 0.3))):
        v.append(bx(m["olive"] if k % 2 else m["wood"], (x, y, z), (1.0, 0.7, 0.6), 0.03, rot=(0, 0, yaw)))
    for k in range(3):
        v.append(jitter(box(m["ember"], (r_ := (-0.3 + k * 0.3), 2.3, 0.6), (0.25, 0.25, 0.06)), 0.03, k))
    save("Truck_wreck", v, [colbox("cab", (0, 2.6, 1.3), (2.3, 2.7, 2.2)), colbox("bed", (0, -0.9, 0.9), (2.3, 4.6, 0.9))])

ALL = dict(car_burnt=car_burnt, humvee_wreck=humvee_wreck, radar_dish=radar_dish, radio_tower=radio_tower,
           alien_spike=alien_spike, alien_pod=alien_pod, alien_veins=alien_veins, barbed_fence=barbed_fence,
           mil_crates=mil_crates, rubble=rubble, silo=silo, snowmobile_wreck=snowmobile_wreck, fallen_signal=fallen_signal,
           crater=crater, debris=debris, dead_tree=dead_tree, broken_fence=broken_fence, truck_wreck=truck_wreck)
for k, f in ALL.items():
    if not ONLY or k in ONLY:
        f()
        print("built", k)

if "--gallery" in sys.argv:
    out = sys.argv[sys.argv.index("--gallery") + 1]
    names = [k for k in ALL if not ONLY or k in ONLY]
    reset()
    cols = 5
    for i, n in enumerate(names):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=os.path.join(OUTDIR, "v_%s.glb" % n))
        for o in set(bpy.data.objects) - before:
            if "colonly" in o.name or "Col" in [ms.material.name for ms in getattr(o, "material_slots", []) if ms.material]:
                o.hide_render = True
            if o.parent is None:
                o.location = ((i % cols) * 12 - 18 - 6, -(i // cols) * 13, 0)
    rows = (len(names) + cols - 1) // cols
    preview(out, target=(0, -(rows - 1) * 6.5, 1.5), dist=58, angle=0.0, height=26.0, res=(1600, 1000))
