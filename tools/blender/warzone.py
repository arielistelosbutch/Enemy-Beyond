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
import kit as K       # (0.72) the shapes of the newer models: lofts, bark, stones

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
def _wheel(m, c, r, w, tyre=True, rim_m=None):
    """(0.72) A wheel side-on along x: a rounded tyre with tread blocks, a dished rim with nuts."""
    out = []
    x, y, z = c
    if tyre:
        out.append(K.disc(m["tyre"], c, r, w, 'x', verts=24, b=0.04))
        for k in range(12):
            a = k / 12 * TAU
            out.append(K.bx(m["tyre"], (x, y + math.cos(a) * r * 1.005, z + math.sin(a) * r * 1.005), (w * 0.9, 0.05, 0.03), 0.005, rot=(a, 0, 0)))
    rr = r * (0.55 if tyre else 0.75)
    rm = rim_m or m["dsteel"]
    sx = 1 if x > 0 else -1
    out.append(K.disc(rm, (x + sx * w * 0.45, y, z), rr, 0.04, 'x', verts=20, b=0.01))
    out.append(K.disc(m["soot"], (x + sx * w * 0.5, y, z), rr * 0.35, 0.04, 'x', verts=12))
    for k in range(6):
        a = k / 6 * TAU
        out.append(K.disc(rm, (x + sx * w * 0.52, y + math.cos(a) * rr * 0.6, z + math.sin(a) * rr * 0.6), 0.02, 0.03, 'x', verts=6))
    return out

def car_burnt():
    """(0.72) The same old hatchback as the village cars (village.car), burnt out: charred and rusted
    shell sunk on bare rims, no glass, the roof sagging, the bonnet sprung, the seats burnt to springs,
    a few embers still glowing inside."""
    reset(); m = M(); v = []
    sunk = -0.12
    body = K.box_loft(m["char"], [(1.92, 0, 0.55 + sunk, 1.5, 0.4), (1.75, 0, 0.6 + sunk, 1.62, 0.55), (0.75, 0, 0.66 + sunk, 1.64, 0.62),
                                  (-1.6, 0, 0.64 + sunk, 1.64, 0.62), (-1.9, 0, 0.62 + sunk, 1.55, 0.5)], b=0.06)
    K._two_tone(body, m["char"], m["soot"], -0.3)
    for p_ in body.data.polygons:                       # rust bleeding through the burnt paint
        if p_.normal.z > -0.3 and K._nz.noise(p_.center * 1.6 + Vector((3, 1, 2))) > 0.18:
            p_.material_index = 0
    body.data.materials.append(m["rust"])
    for p_ in body.data.polygons:
        if abs(p_.normal.x) > 0.6 and K._nz.noise(p_.center * 2.2) > 0.12:
            p_.material_index = 2
    v.append(body)
    bon = K.bx(m["rust"], (0, 1.32, 0.86 + sunk), (1.5, 0.95, 0.04), 0.01, rot=(0.32, 0.04, 0.03))     # the bonnet sprung up
    v.append(jitter(bon, 0.015, 3))
    roof = K.bx(m["rust2"], (0, -0.4, 1.4 + sunk), (1.38, 1.6, 0.05), 0.015)
    for vt in roof.data.vertices:
        vt.co.z -= 0.09 * math.cos(vt.co.y * 1.6 + 0.6) + (0.05 if vt.co.x > 0 else 0)
    v.append(roof)
    for sx in (1, -1):
        v.append(K.beam(m["soot"], (sx * 0.74, 0.62, 0.95 + sunk), (sx * 0.69, 0.4, 1.36 + sunk), 0.07, 0.06))
        v.append(K.beam(m["soot"], (sx * 0.75, -0.35, 0.95 + sunk), (sx * 0.7, -0.35, 1.36 + sunk), 0.07, 0.1))
        v.append(K.beam(m["soot"], (sx * 0.75, -1.45, 0.95 + sunk), (sx * 0.69, -1.2, 1.36 + sunk), 0.07, 0.18))
        v.append(K.bx(m["dsteel"], (sx * 0.82, 0.12, 0.62 + sunk), (0.01, 0.02, 0.5), 0.002))
        for sy in (1, -1):
            y = sy * 1.2 - (0.05 if sy < 0 else 0)
            v.append(K.disc(m["dsteel"], (sx * 0.74, y, 0.22), 0.23, 0.16, 'x', verts=18, b=0.015))       # bare rims
            v.append(K.disc(m["soot"], (sx * 0.83, y, 0.22), 0.1, 0.03, 'x', verts=12))
            v.append(K.beam(m["rust2"], (sx * 0.8, y - 0.38, 0.48 + sunk), (sx * 0.8, y + 0.38, 0.48 + sunk), 0.04, 0.05))
    for x in (-0.38, 0.38):                                         # seats: burnt to frames and springs
        v.append(K.bx(m["soot"], (x, -0.25, 0.72 + sunk), (0.48, 0.5, 0.06), 0.01))
        for k in range(4):
            v.append(K.tb(m["dsteel"], (x - 0.22, -0.52 + k * 0.06, 0.78 + sunk + k * 0.12), (x + 0.22, -0.52 + k * 0.06, 0.78 + sunk + k * 0.12), 0.012, 5))
    v.append(K.tb(m["soot"], (-0.35, 0.35, 0.8 + sunk), (-0.35, 0.15, 1.05 + sunk), 0.02, 6))          # the steering column
    v.append(K.torus(m["soot"], (-0.35, 0.12, 1.07 + sunk), 0.17, 0.015, rot=(1.1, 0, 0), seg=16, mseg=4))
    v.append(K.bx(m["dsteel"], (0, 1.99, 0.33), (1.6, 0.08, 0.12), 0.02, rot=(0, 0.12, 0)))          # bumpers, one fallen
    v.append(K.bx(m["dsteel"], (0.2, -2.05, 0.08), (1.6, 0.08, 0.12), 0.02, rot=(0.0, 0.0, 0.25)))
    for k, (x, y) in enumerate(((0.3, 0.2), (-0.4, -0.6), (0.1, -1.4))):
        v.append(K.lump(m["ember"], (x, y, 0.82 + sunk), 0.09, (1.4, 1, 0.4), 50 + k, 0.3, 2))
    v.append(K.lump(m["soot"], (0.2, 1.4, 0.73 + sunk), 0.4, (1.6, 1.0, 0.3), 61, 0.3, 2))             # ash where the engine burnt
    save("Car_burnt", v, [colbox("car", (0, 0, 0.75), (1.7, 4.0, 1.5))])

def humvee_wreck():
    """(0.72) A military truck sunk in sand to the axles: a wide bevelled body, the sand paint gone
    to rust in patches, a cracked windscreen, a crate on the back, sand drifted against it."""
    reset(); m = M(); v = []
    body = K.box_loft(m["sand"], [(-2.05, 0, 0.85, 2.15, 0.75), (1.0, 0, 0.88, 2.2, 0.85), (2.45, 0, 0.82, 2.1, 0.7)], b=0.08)
    body.data.materials.append(m["rust"])
    for p_ in body.data.polygons:
        p_.material_index = 1 if K._nz.noise(p_.center * 1.4 + Vector((5, 2, 1))) > 0.25 else 0
    v.append(body)
    v.append(K.box_loft(m["sand"], [(0.95, 0, 1.28, 2.0, 0.08), (2.45, 0, 1.2, 1.95, 0.08)], b=0.02))        # bonnet
    v.append(K.box_loft(m["sand"], [(-1.5, 0, 1.68, 2.1, 0.85), (0.6, 0, 1.68, 2.05, 0.8), (0.8, 0, 1.6, 1.95, 0.6)], b=0.06))   # cabin
    v.append(K.bx(m["dsteel"], (0, 0.75, 1.68), (1.9, 0.06, 0.6), 0.01, rot=(-0.3, 0, 0)))                  # windscreen frame
    v.append(jitter(K.bx(m["glass"], (0.45, 0.78, 1.7), (0.8, 0.03, 0.45), 0.005, rot=(-0.3, 0, 0)), 0.015, 3))
    for k in range(6):                                                                                     # grille
        v.append(K.bx(m["dsteel"], (-0.75 + k * 0.3, 2.47, 0.95), (0.1, 0.05, 0.5), 0.01))
    v.append(K.bx(m["dsteel"], (0, 2.52, 0.6), (2.2, 0.2, 0.2), 0.03))
    for x in (-0.75, 0.75):
        v.append(K.disc(m["glass"], (x, 2.48, 1.08), 0.11, 0.05, 'y', verts=14))                            # head lamps
    for x in (-1.0, 1.0):
        for y in (1.6, -1.4):
            v += _wheel(m, (x, y, 0.3), 0.5, 0.42)
    v.append(K.bx(m["olive2"], (0.4, -1.8, 1.47), (0.9, 0.6, 0.45), 0.03))                                 # a crate on the back
    v.append(K.bx(m["olive"], (0.4, -1.8, 1.71), (0.93, 0.63, 0.05), 0.01))
    v.append(K.bx(m["white"], (0.4, -2.11, 1.45), (0.4, 0.01, 0.1), 0.003))
    v.append(K.tb(m["dsteel"], (-0.9, -1.0, 2.05), (-0.85, -1.05, 3.2), 0.015, 6))                          # whip antenna
    drift = mat2("WSandDrift", (0.62, 0.45, 0.3), 0.95)
    for k, (x, y, sc) in enumerate(((1.4, 0.5, 1.6), (-1.3, -0.5, 1.4), (0.2, 2.8, 1.2))):
        o = K.lump(drift, (x, y, 0.0), sc, (0.6, 1.4, 0.35), 90 + k, 0.12, 3, bumps=0.03)
        for vt in o.data.vertices:
            vt.co.z = max(vt.co.z, -0.05)
        v.append(o)
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
    """(0.72) A heap of broken concrete: chunks with chiselled faces, a slab of painted wall,
    bent rebar sticking out, dust in the gaps (ruined towns)."""
    reset(); m = M(); v = []
    r = random.Random(5)
    base = K.lump(m["concrete2"], (0, 0, -0.05), 1.6, (1.0, 1.0, 0.32), 5, 0.3, 3, bumps=0.08)
    for vt in base.data.vertices:
        vt.co.z = max(vt.co.z, -0.05)
    v.append(base)
    for k in range(18):
        a = r.uniform(0, TAU); d = r.uniform(0, 1.8)
        z = max(0.1, 0.8 - d * 0.42) * r.uniform(0.5, 1.0)
        s = (r.uniform(0.4, 1.1), r.uniform(0.3, 0.8), r.uniform(0.25, 0.5))
        o = K.stone(m["concrete"] if k % 3 else m["concrete2"], 0.5, s, 100 + k, 7, 2)
        o.location = (math.cos(a) * d, math.sin(a) * d, z - 0.15)
        o.rotation_euler = (r.uniform(-0.5, 0.5), r.uniform(-0.5, 0.5), r.uniform(0, TAU))
        K.apply_xf(o)
        v.append(o)
    for k in range(7):
        a = r.uniform(0, TAU); d = r.uniform(0, 1.2)
        p = Vector((math.cos(a) * d, math.sin(a) * d, 0.5))
        q = p + Vector((r.uniform(-0.7, 0.7), r.uniform(-0.7, 0.7), r.uniform(0.4, 1.0)))
        e = q + Vector((r.uniform(-0.3, 0.3), r.uniform(-0.3, 0.3), -0.2))
        v.append(K.bark_tube(m["rust"], [p, p.lerp(q, 0.5), q, q.lerp(e, 0.5), e], [0.014] * 5, 5, k, 0.0))
    wall = K.bx(m["white"], (0.9, -0.3, 0.35), (1.0, 0.1, 0.6), 0.015, rot=(0.9, 0.2, 0.5))      # a bit of painted wall
    v.append(jitter(wall, 0.02, 3))
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
    """(0.72) A crashed snowmobile: a rounded red hood, a torn seat, a cracked windscreen,
    one bent ski, the rubber track."""
    reset(); m = M(); v = []
    red = mat2("WSledRed", (0.5, 0.08, 0.06), 0.45, 0.1)
    v.append(K.loft(red, [(1.3, 0, 0.55, 0.32, 0.2), (0.9, 0, 0.62, 0.45, 0.32), (0.2, 0, 0.62, 0.47, 0.32), (-0.2, 0, 0.55, 0.45, 0.25)], verts=20))
    v.append(K.loft(m["soot"], [(-0.15, 0, 0.75, 0.32, 0.12), (-1.0, 0, 0.78, 0.33, 0.12), (-1.15, 0, 0.72, 0.3, 0.08)], verts=14))   # seat
    v.append(jitter(K.bx(m["glass"], (0, 0.45, 0.98), (0.6, 0.04, 0.3), 0.01, rot=(-0.5, 0, 0.3)), 0.015, 1))
    v.append(K.tb(m["dsteel"], (-0.4, 0.2, 0.95), (0.4, 0.2, 0.95), 0.02, 8))                                # handlebar
    for x in (-0.4, 0.4):
        v.append(K.tb(m["soot"], (x, 0.2, 0.95), (x * 1.15, 0.2, 0.95), 0.03, 8))
    for x in (-0.45, 0.45):                                                                                 # skis (one bent)
        sk = K.box_loft(m["dsteel"], [(0.5, x, 0.08, 0.14, 0.03), (1.4, x, 0.08, 0.14, 0.03), (1.6, x, 0.2, 0.12, 0.03)], b=0.008)
        if x > 0:
            for vt in sk.data.vertices:
                vt.co.x += 0.15 * max(0.0, vt.co.y - 0.8)
        v.append(sk)
        v.append(K.tb(m["dsteel"], (x, 0.9, 0.1), (x * 0.7, 0.9, 0.45), 0.02, 6))
    v.append(K.box_loft(m["tyre"], [(-1.0, 0, 0.18, 0.5, 0.3), (0.2, 0, 0.18, 0.5, 0.3), (0.45, 0, 0.3, 0.5, 0.2)], b=0.06))
    for k in range(10):
        v.append(K.bx(m["tyre"], (0, -0.95 + k * 0.12, 0.02), (0.52, 0.04, 0.03), 0.005))
    save("Snowmobile_wreck", v, [colbox("s", (0, 0.2, 0.5), (1.1, 2.6, 1.0))])

def fallen_signal():
    """(0.72) A toppled traffic light still glowing red, its pole torn off its concrete foot, and a
    bent road sign (town streets)."""
    reset(); m = M(); v = []
    v.append(K.tb(m["dsteel"], (0.1, 0.02, 0.1), (3.6, 0.6, 0.25), 0.07, 14))
    v.append(K.bx(m["dsteel"], (3.9, 0.65, 0.3), (0.35, 0.3, 0.9), 0.04, rot=(0, PI2 - 0.1, 0.15)))
    for k, mm in enumerate((m["red"], m["soot"], m["soot"])):
        v.append(K.disc(mm, (3.62 + k * 0.28, 0.48, 0.32), 0.09, 0.03, 'z', verts=16))
        v.append(K.tb(m["soot"], (3.62 + k * 0.28, 0.5, 0.32), (3.62 + k * 0.28, 0.32, 0.36), 0.11, 16, r2=0.105))   # visors
    v.append(K.bx(m["concrete2"], (0, 0, 0.1), (0.5, 0.5, 0.2), 0.03))
    stub = K.tb(m["dsteel"], (0, 0, 0.2), (0, 0, 0.42), 0.07, 14)
    for vt in stub.data.vertices:          # torn end
        if vt.co.z > 0.35:
            vt.co.z += 0.05 * math.sin(vt.co.x * 60)
    v.append(stub)
    for k in range(4):
        v.append(K.disc(m["dsteel"], (math.cos(k * PI2 + 0.7) * 0.18, math.sin(k * PI2 + 0.7) * 0.18, 0.21), 0.025, 0.04, verts=6))
    v.append(K.tb(m["dsteel"], (-1.5, 1.2, 0.0), (-1.4, 1.1, 1.3), 0.035, 10))
    v.append(K.tb(m["dsteel"], (-1.4, 1.1, 1.3), (-0.9, 1.4, 1.8), 0.035, 10))
    v.append(K.bx(m["blue"], (-0.75, 1.5, 1.95), (0.7, 0.04, 0.55), 0.01, rot=(0.1, 0.4, 0.3)))
    v.append(K.bx(m["white"], (-0.75, 1.475, 1.95), (0.62, 0.01, 0.47), 0.003, rot=(0.1, 0.4, 0.3)))
    v.append(K.bx(m["blue"], (-0.75, 1.47, 1.95), (0.08, 0.01, 0.32), 0.003, rot=(0.1, 0.4, 0.3)))
    save("Fallen_signal", v, [colbox("t", (1.8, 0.3, 0.3), (3.8, 0.8, 0.6))])

def crater():
    """(0.72) A shell crater: a scorched dish with a ragged, thrown-up rim of earth, clods and stones
    round it, a black blast in the middle (flat, walkable)."""
    reset(); m = M(); v = []
    earth = mat2("WEarth", (0.24, 0.18, 0.12), 0.95)
    r = random.Random(9)
    bpy.ops.mesh.primitive_circle_add(vertices=48, radius=2.7, fill_type='TRIFAN')
    d = bpy.context.active_object
    _sel(d); bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.subdivide(number_cuts=5); bpy.ops.object.mode_set(mode='OBJECT')
    for vt in d.data.vertices:
        rr = Vector((vt.co.x, vt.co.y)).length / 2.7
        a = math.atan2(vt.co.y, vt.co.x)
        rim = 0.82 + 0.05 * math.sin(a * 5 + 1.0) + 0.04 * K._nz.noise(Vector((vt.co.x, vt.co.y, 0)) * 1.3)
        vt.co.z = -0.55 * max(0.0, 1 - rr * 1.35) ** 1.5 + 0.3 * math.exp(-((rr - rim) / 0.13) ** 2) \
            + 0.04 * K._nz.noise(Vector((vt.co.x, vt.co.y, 0.5)) * 2.5)
        vt.co.z *= max(0.0, min(1.0, (1.0 - rr) * 6.0)) if rr > 0.9 else 1.0      # back to the ground at the edge
    _finish(d, earth, (0, 0, 0.02), (0, 0, 0), (1, 1, 1))
    smooth(d)
    d.data.materials.append(m["soot"])
    for p_ in d.data.polygons:
        if Vector((p_.center.x, p_.center.y)).length < 1.15 + 0.2 * K._nz.noise(p_.center * 1.5):
            p_.material_index = 1
    v.append(d)
    for k in range(16):
        a = r.uniform(0, TAU); rr = r.uniform(2.0, 3.1)
        if k % 2:
            o = K.stone(m["concrete2"], r.uniform(0.1, 0.22), (1.2, 1, 0.8), 70 + k, 6, 2)
        else:
            o = K.lump(earth, (0, 0, 0), r.uniform(0.12, 0.25), (1.3, 1, 0.6), 70 + k, 0.35, 2, bumps=0.15)
        o.location = (math.cos(a) * rr, math.sin(a) * rr, 0.08)
        K.apply_xf(o)
        v.append(o)
    save("Crater", v, [])

def debris():
    """(0.72) Smashed planks with splintered ends, a broken door, roof tiles, a dented bucket and
    a twisted gutter - what is left round a wrecked house."""
    reset(); m = M(); v = []
    r = random.Random(4)
    def plank(mm, c, L, w, t, rot):
        o = K.bx(mm, c, (w, L, t), 0.008, rot=rot)
        return jitter(o, 0.006, r.randint(0, 99))
    for k in range(14):
        a = r.uniform(0, TAU); d = r.uniform(0, 2.2)
        L = r.uniform(0.8, 2.4)
        o = plank(m["wood"] if k % 3 else m["char"], (math.cos(a) * d, math.sin(a) * d, 0.04 + r.uniform(0, 0.18)), L, 0.12, 0.035,
                  (r.uniform(-0.25, 0.25), r.uniform(-0.2, 0.2), r.uniform(0, TAU)))
        v.append(o)
    v.append(K.bx(m["wood"], (0.6, -0.4, 0.06), (0.85, 1.9, 0.05), 0.01, rot=(0.05, 0.08, 0.4)))      # a door with panels
    for k in range(2):
        v.append(K.bx(m["wood"], (0.6 + math.sin(0.4) * 0.0, -0.4 + (k - 0.5) * 0.9, 0.095), (0.6, 0.7, 0.02), 0.01, rot=(0.05, 0.08, 0.4)))
    v.append(K.disc(m["dsteel"], (0.82, -0.05, 0.11), 0.04, 0.03, verts=10))                            # its knob
    tile = mat2("WShingle", (0.4, 0.15, 0.1), 0.85)
    for k in range(10):
        o = K.bx(tile, (r.uniform(-1.6, 1.6), r.uniform(-1.6, 1.6), 0.03), (0.3, 0.2, 0.025), 0.006, rot=(r.uniform(-0.15, 0.15), 0, r.uniform(0, TAU)))
        for vt in o.data.vertices:          # tiles are curved
            vt.co.z += 0.02 * math.cos((vt.co.x - o.location.x) * 6)
        v.append(o)
    b = K.lathe(m["dsteel"], [(0.0, 0.0), (0.12, 0.0), (0.155, 0.3), (0.15, 0.3), (0.11, 0.015), (0.0, 0.015)], verts=16)   # bucket on its side
    for vt in b.data.vertices:
        vt.co.y, vt.co.z = vt.co.z, -vt.co.y
        vt.co.x += 0.03 * K._nz.noise(vt.co * 6)
    b.location = (-1.2, 0.9, 0.15); b.rotation_euler = (0, 0, 0.6); K.apply_xf(b)
    v.append(b)
    g = K.bark_tube(m["dsteel"], K._path((-0.4, 1.4, 0.05), (1.4, 1.9, 0.12), 5, 5, 0.25), [0.06] * 6, 8, 5, 0.0)
    v.append(g)
    save("Debris", v, [])

def dead_tree():
    """(0.72) A dead, blasted tree: a split, crooked trunk with root flares, twisted bare branches
    that thin to twigs, roots clawing the ground, a charred scar up one side."""
    reset(); m = M(); v = []
    bark = mat2("WDeadBark", (0.2, 0.16, 0.12), 0.95)
    r = random.Random(21)
    def limb(p, d, L, w, depth):
        q = p + d * L
        pts = K._path(p, q, 3, r.randint(0, 999), L * 0.08)
        v.append(K.bark_tube(bark, pts, [w, w * 0.9, w * 0.8, w * 0.68], 8 if w > 0.1 else 6, r.randint(0, 99), 0.1))
        if depth >= 3 or w < 0.025:
            return
        for k in range(r.choice((2, 2, 3))):
            nd = (d + Vector((r.uniform(-0.9, 0.9), r.uniform(-0.9, 0.9), r.uniform(-0.1, 0.5)))).normalized()
            limb(q, nd, L * r.uniform(0.55, 0.75), w * 0.6, depth + 1)
    trunk = K.bark_tube(bark, [(0, 0, -0.15), (0.02, 0, 0.35), (0.06, 0.02, 1.6), (0.12, 0.04, 3.2)], [0.42, 0.3, 0.25, 0.18], 12, 21, 0.14, 0.6)
    v.append(trunk)
    limb(Vector((0.12, 0.04, 3.1)), Vector((0.2, 0.05, 1)).normalized(), 1.6, 0.17, 1)
    limb(Vector((0.1, 0.03, 2.9)), Vector((-0.5, 0.2, 1)).normalized(), 1.5, 0.14, 1)
    limb(Vector((0.05, 0.02, 1.9)), Vector((0.3, -0.9, 0.5)).normalized(), 1.4, 0.1, 2)
    for k in range(6):
        a = k / 6 * TAU + r.uniform(0, 0.5)
        pts = K._path((math.cos(a) * 0.2, math.sin(a) * 0.2, 0.3), (math.cos(a) * 1.3, math.sin(a) * 1.3, -0.1), 3, 40 + k, 0.1)
        v.append(K.bark_tube(bark, pts, [0.14, 0.1, 0.06, 0.02], 7, 40 + k, 0.1))
    scar = K.bark_tube(m["char"], [(0.0, 0, 0.6), (0.05, 0, 1.6), (0.1, 0.03, 2.6)], [0.27, 0.25, 0.19], 12, 7, 0.14)
    for vt in scar.data.vertices:            # only the front of the trunk is burnt black
        if vt.co.y < 0.05:
            vt.co.x *= 0.9; vt.co.y = vt.co.y * 0.9
    v.append(scar)
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
    """(0.72) A burnt-out flatbed truck: a rounded cab torched black with rust coming through, the
    windscreen gone, a sprung bonnet, a flatbed with a side flap hanging open, crates spilled behind."""
    reset(); m = M(); v = []
    cab = K.box_loft(m["char"], [(1.35, 0, 1.25, 2.2, 1.6), (2.8, 0, 1.35, 2.2, 1.8), (3.1, 0, 1.25, 2.1, 1.55)], b=0.12)
    K._two_tone(cab, m["char"], m["soot"], 0.3)
    v.append(cab)
    v.append(K.box_loft(m["rust"], [(3.1, 0, 0.95, 2.1, 0.9), (3.7, 0, 0.9, 2.0, 0.8), (3.8, 0, 0.82, 1.9, 0.6)], b=0.08))
    # (0.72.3: the sprung bonnet lid is gone - tilted up over the bonnet it read as a windscreen flipped forward)
    v.append(K.bx(m["dsteel"], (0, 3.115, 1.62), (1.78, 0.03, 0.62), 0.01))                                  # the windscreen hole: a frame
    v.append(K.bx(m["soot"], (0, 3.13, 1.62), (1.62, 0.02, 0.48), 0.005))                                   # and the burnt-out dark behind it
    v.append(K.beam(m["soot"], (-0.95, 3.1, 1.6), (-0.9, 2.85, 2.15), 0.08, 0.08))                           # empty windscreen frame
    v.append(K.beam(m["soot"], (0.95, 3.1, 1.6), (0.9, 2.85, 2.15), 0.08, 0.08))
    v.append(K.beam(m["soot"], (-0.9, 2.85, 2.15), (0.9, 2.85, 2.15), 0.08, 0.08))
    for k in range(6):                                                                                       # grille
        v.append(K.bx(m["dsteel"], (-0.75 + k * 0.3, 3.82, 0.85), (0.1, 0.04, 0.45), 0.01))
    v.append(K.bx(m["dsteel"], (0, 3.9, 0.5), (2.2, 0.14, 0.2), 0.03))
    v.append(K.bx(m["dsteel"], (0, -0.9, 0.85), (2.3, 4.6, 0.16), 0.03))                                     # flatbed
    for k in range(9):
        v.append(K.bx(m["wood"] if k % 3 else m["char"], (0, -3.0 + k * 0.52, 0.95), (2.2, 0.48, 0.04), 0.008))
    for y in (-3.1, 1.25):
        v.append(K.bx(m["rust2"], (0, y, 1.3), (2.3, 0.1, 0.9), 0.02))
    v.append(K.bx(m["rust2"], (1.12, -0.9, 1.15), (0.08, 4.6, 0.45), 0.02, rot=(0.0, 0.5, 0.0)))            # side flap hanging open
    v.append(K.bx(m["dsteel"], (0, 0.9, 0.55), (0.25, 7.0, 0.2), 0.02))                                      # chassis rail
    for x in (-1.0, 1.0):
        for y in (2.6, -0.4, -1.9):
            v += _wheel(m, (x, y, 0.48), 0.48, 0.35, tyre=y < 0)
    for k, (x, y, z, yaw) in enumerate(((0.4, -1.5, 1.27, 0.2), (-0.5, -0.2, 1.27, -0.1), (1.9, -3.6, 0.3, 0.9), (2.4, -2.6, 0.3, 0.3))):
        v.append(K.bx(m["olive"] if k % 2 else m["wood"], (x, y, z), (1.0, 0.7, 0.6), 0.03, rot=(0, 0, yaw)))
        v.append(K.bx(m["olive2"] if k % 2 else m["char"], (x, y, z + 0.29), (1.03, 0.73, 0.05), 0.01, rot=(0, 0, yaw)))
    for k in range(3):
        v.append(K.lump(m["ember"], (-0.3 + k * 0.3, 2.3, 0.62), 0.12, (1.3, 1, 0.4), 80 + k, 0.3, 2))
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
