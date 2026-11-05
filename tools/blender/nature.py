"""Enemy Beyond 0.56 - nature for the maps (own designs): trees, bushes, rocks, stumps, fallen logs,
reeds, ice shards. Low-poly with flat facets like the village props; the colours stay (the game restyles
by base colour). Material names the map uses for snow: VNeedles, VLeaves, VLeavesDark, VBush, VRock*.
Front = +Y (Godot -Z). Origin on the ground in the middle.
Run: python3 tools/blender/nature.py <outdir> [--only a,b] [--gallery out.png]"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
from kit import *
from kit import _fix_normals
from common import _finish
import bmesh
from mathutils import Vector

ARGS = [a for a in sys.argv[1:] if not a.startswith("--") and not a.endswith(".png") and "," not in a]
OUTDIR = ARGS[0] if ARGS else "."
ONLY = sys.argv[sys.argv.index("--only") + 1].split(",") if "--only" in sys.argv else []

def M():
    return dict(
        bark=mat2("VBark", (0.2, 0.15, 0.1), 0.95), bark2=mat2("VBarkGrey", (0.3, 0.28, 0.25), 0.95),
        birch=mat2("VBirch", (0.82, 0.8, 0.74), 0.9), birchm=mat2("VBirchMark", (0.08, 0.08, 0.07), 0.9),
        needles=mat2("VNeedles", (0.07, 0.16, 0.09), 0.95), needles2=mat2("VNeedlesDark", (0.05, 0.11, 0.07), 0.95),
        leaves=mat2("VLeaves", (0.17, 0.27, 0.1), 0.95), leaves2=mat2("VLeavesDark", (0.11, 0.2, 0.08), 0.95),
        leavesy=mat2("VLeavesYellow", (0.42, 0.36, 0.1), 0.95), bush=mat2("VBush", (0.12, 0.22, 0.09), 0.95),
        rock=mat2("VRock", (0.36, 0.35, 0.33), 0.95), rock2=mat2("VRockDark", (0.24, 0.24, 0.23), 0.95),
        moss=mat2("VMoss", (0.2, 0.26, 0.12), 0.95), wood=mat2("VEndGrain", (0.55, 0.42, 0.26), 0.9),
        reed=mat2("VReed", (0.36, 0.4, 0.18), 0.9), reedtop=mat2("VReedTop", (0.3, 0.2, 0.1), 0.9),
        ice=mat2("VIceGlass", (0.55, 0.75, 0.85), 0.1), ice2=mat2("VIce", (0.72, 0.85, 0.92), 0.25),
    )

def save(name, vis, col, fname):
    o = join(vis, name)
    export_glb(os.path.join(OUTDIR, "v_%s.glb" % fname), [o] + col)

def blob(m, c, r, scale=(1, 1, 1), seed=0, amt=0.18, sub=1):
    """A lumpy faceted ball (a crown of leaves, a bush, a boulder)."""
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=r)
    o = bpy.context.active_object
    rr = random.Random(seed)
    for v in o.data.vertices:
        v.co *= 1.0 + rr.uniform(-amt, amt)
    return _finish(o, m, c, (rr.uniform(0, 6), rr.uniform(0, 6), rr.uniform(0, 6)), scale)

def trunk(m, a, b, r0, r1, verts=7, seed=0, bend=0.0):
    """A tapering trunk from a to b (a little crooked)."""
    rings = []
    rr = random.Random(seed)
    a = Vector(a); b = Vector(b)
    n = 4
    for i in range(n + 1):
        t = i / n
        p = a.lerp(b, t)
        p += Vector((rr.uniform(-bend, bend), rr.uniform(-bend, bend), 0)) * math.sin(t * math.pi)
        rings.append((p, r0 + (r1 - r0) * t))
    me = bpy.data.meshes.new("trunk")
    bm = bmesh.new()
    loops = []
    for p, r in rings:
        loop = []
        for k in range(verts):
            ang = k / verts * math.tau
            loop.append(bm.verts.new(p + Vector((math.cos(ang) * r, math.sin(ang) * r, 0))))
        loops.append(loop)
    for i in range(len(loops) - 1):
        for k in range(verts):
            bm.faces.new((loops[i][k], loops[i][(k + 1) % verts], loops[i + 1][(k + 1) % verts], loops[i + 1][k]))
    bm.faces.new(list(reversed(loops[0])))
    bm.faces.new(loops[-1])
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("trunk", me)
    bpy.context.collection.objects.link(o)
    _fix_normals(o)
    return _finish(o, m, (0, 0, 0), (0, 0, 0), (1, 1, 1))

def cone_skirt(m, z, r, h, seed, verts=9, droop=0.25):
    """One layer of a spruce: a ragged cone whose rim hangs down between the branch tips."""
    me = bpy.data.meshes.new("skirt")
    bm = bmesh.new()
    rr = random.Random(seed)
    top = bm.verts.new((0, 0, z + h))
    rim = []
    for k in range(verts * 2):
        ang = k / (verts * 2) * math.tau + rr.uniform(-0.08, 0.08)
        tip = k % 2 == 0
        rk = r * (1.0 if tip else 0.62) * rr.uniform(0.9, 1.08)
        zz = z - (droop * r * 0.35 if tip else -0.05 * h)
        rim.append(bm.verts.new((math.cos(ang) * rk, math.sin(ang) * rk, zz)))
    mid = bm.verts.new((0, 0, z + 0.12 * h))
    for k in range(len(rim)):
        bm.faces.new((rim[k], rim[(k + 1) % len(rim)], top))
        bm.faces.new((rim[(k + 1) % len(rim)], rim[k], mid))
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("skirt", me)
    bpy.context.collection.objects.link(o)
    _fix_normals(o)
    return _finish(o, m, (0, 0, 0), (0, 0, 0), (1, 1, 1))

# ---- trees ---------------------------------------------------------------------------------------------
def spruce(fname="tree_spruce", h=7.5, seed=1):
    """A dark spruce: a straight trunk under layer on layer of hanging branches, narrowing to a spike."""
    reset(); m = M(); vis = []; col = []
    vis.append(trunk(m["bark"], (0, 0, -0.1), (0, 0, h * 0.85), 0.22, 0.05, 7, seed))
    layers = 7
    for i in range(layers):
        t = i / (layers - 1)
        z = 0.9 + t * (h - 1.9)
        r = 2.0 * (1.0 - t) ** 0.85 + 0.35
        vis.append(cone_skirt(m["needles"] if i % 2 else m["needles2"], z, r, 1.5 - 0.5 * t, seed * 10 + i))
    vis.append(cyl(m["needles2"], (0, 0, h - 0.35), 0.28, 1.1, 6, r2=0.0))
    col.append(colbox("Trunk", (0, 0, h * 0.4), (0.45, 0.45, h * 0.8)))
    save("Spruce", vis, col, fname)

def pine(fname="tree_pine", h=9.0, seed=2):
    """A tall pine: a long reddish trunk bare to two thirds, a flat irregular crown in clumps."""
    reset(); m = M(); vis = []; col = []
    vis.append(trunk(mat2("VBarkRed", (0.32, 0.17, 0.1), 0.95), (0, 0, -0.1), (0.2, 0.1, h * 0.9), 0.24, 0.08, 7, seed, 0.25))
    rr = random.Random(seed)
    top = Vector((0.2, 0.1, h * 0.75))
    for k in range(4):
        ang = k / 4 * math.tau + rr.uniform(-0.3, 0.3)
        tip = top + Vector((math.cos(ang) * 1.2, math.sin(ang) * 1.2, rr.uniform(-0.6, 0.4)))
        vis.append(beam(m["bark"], top + Vector((0, 0, rr.uniform(-0.8, 0.4))), tip, 0.08, 0.08))
        vis.append(blob(m["needles"] if k % 2 else m["needles2"], tip + Vector((0, 0, 0.3)), 0.95, (1.5, 1.5, 0.6), seed * 10 + k, 0.2))
    vis.append(blob(m["needles"], top + Vector((0, 0, 1.2)), 1.1, (1.6, 1.6, 0.7), seed * 10 + 9, 0.2))
    col.append(colbox("Trunk", (0.1, 0.05, h * 0.4), (0.48, 0.48, h * 0.8)))
    save("Pine", vis, col, fname)

def oak(fname="tree_oak", h=6.5, seed=3, mats=("leaves", "leaves2")):
    """A broad leafy tree: a thick crooked trunk that forks, a big round crown of lumps."""
    reset(); m = M(); vis = []; col = []
    vis.append(trunk(m["bark2"], (0, 0, -0.1), (0.1, 0, h * 0.45), 0.38, 0.26, 8, seed, 0.15))
    rr = random.Random(seed)
    fork = Vector((0.1, 0, h * 0.45))
    tips = []
    for k in range(3):
        ang = k / 3 * math.tau + rr.uniform(-0.4, 0.4)
        tip = fork + Vector((math.cos(ang) * 1.3, math.sin(ang) * 1.3, h * 0.25))
        vis.append(trunk(m["bark2"], fork - Vector((0, 0, 0.3)), tip, 0.22, 0.1, 6, seed + k))
        tips.append(tip)
    cz = h * 0.72
    vis.append(blob(m[mats[0]], (0, 0, cz), 2.0, (1.15, 1.15, 0.85), seed * 10, 0.16, 2))
    for k, tp in enumerate(tips):
        vis.append(blob(m[mats[k % 2]], (tp.x * 1.1, tp.y * 1.1, cz + rr.uniform(-0.4, 0.5)), 1.5, (1, 1, 0.85), seed * 10 + k + 1, 0.22))
    vis.append(blob(m[mats[1]], (0, 0, cz + 1.4), 1.3, (1, 1, 0.8), seed * 10 + 7, 0.22))
    col.append(colbox("Trunk", (0.05, 0, h * 0.3), (0.75, 0.75, h * 0.6)))
    save("Oak", vis, col, fname)

def birch(fname="tree_birch", h=7.0, seed=4):
    """A slender white birch with black marks, a light, loose crown."""
    reset(); m = M(); vis = []; col = []
    vis.append(trunk(m["birch"], (0, 0, -0.1), (0.15, 0.05, h * 0.92), 0.16, 0.05, 7, seed, 0.2))
    rr = random.Random(seed)
    for k in range(7):
        z = 0.6 + k * h * 0.11
        ang = rr.uniform(0, math.tau)
        vis.append(bx(m["birchm"], (math.cos(ang) * 0.13, math.sin(ang) * 0.13, z), (0.06, 0.06, rr.uniform(0.05, 0.12)), 0.0))
    for k in range(4):
        z = h * (0.55 + k * 0.12)
        ang = k * 1.9 + rr.uniform(-0.3, 0.3)
        c = (0.12 + math.cos(ang) * 0.7, 0.05 + math.sin(ang) * 0.7, z)
        vis.append(blob(m["leaves"] if k % 2 else m["leavesy"] if seed % 3 == 0 else m["leaves2"], c, 0.9, (1, 1, 1.25), seed * 10 + k, 0.25))
    col.append(colbox("Trunk", (0.07, 0.02, h * 0.4), (0.35, 0.35, h * 0.8)))
    save("Birch", vis, col, fname)

def bush(fname="bush", seed=5, r=0.8):
    """A low bush of a few lumps (no collision: you can push through, it hides you)."""
    reset(); m = M(); vis = []
    rr = random.Random(seed)
    for k in range(4):
        ang = k / 4 * math.tau + rr.uniform(-0.5, 0.5)
        d = r * 0.5
        vis.append(blob(m["bush"] if k % 2 else m["leaves2"], (math.cos(ang) * d, math.sin(ang) * d, r * 0.55), r * rr.uniform(0.7, 0.9), (1, 1, 0.8), seed * 10 + k, 0.25))
    vis.append(blob(m["bush"], (0, 0, r * 0.95), r * 0.75, (1, 1, 0.8), seed * 10 + 9, 0.25))
    save("Bush", vis, [], fname)

def rock(fname, r, scale, seed, moss=True):
    """A weathered boulder, half sunk into the ground, a patch of moss on top."""
    reset(); m = M(); vis = []; col = []
    rr = random.Random(seed)
    o = blob(m["rock"], (0, 0, r * scale[2] * 0.45), r, scale, seed, 0.28, 1)
    vis.append(o)
    vis.append(blob(m["rock2"], (r * scale[0] * 0.55, rr.uniform(-0.3, 0.3) * r, r * 0.25), r * 0.45, (1.2, 1, 0.7), seed + 50, 0.3, 1))
    if moss:
        vis.append(blob(m["moss"], (rr.uniform(-0.2, 0.2) * r, 0, r * scale[2] * 1.25), r * 0.45, (1.6, 1.3, 0.25), seed + 70, 0.2, 1))
    col.append(colbox("Rock", (0, 0, r * scale[2] * 0.6), (r * 1.6 * scale[0], r * 1.6 * scale[1], r * 1.2 * scale[2])))
    save("Rock", vis, col, fname)

def stump(fname="stump", seed=6):
    reset(); m = M(); vis = []; col = []
    vis.append(trunk(m["bark2"], (0, 0, -0.05), (0, 0, 0.55), 0.42, 0.36, 9, seed))
    vis.append(disc(m["wood"], (0, 0, 0.56), 0.34, 0.03, verts=9))
    for k in range(4):
        ang = k / 4 * math.tau + 0.4
        vis.append(beam(m["bark2"], (math.cos(ang) * 0.3, math.sin(ang) * 0.3, 0.15), (math.cos(ang) * 0.75, math.sin(ang) * 0.75, -0.05), 0.12, 0.1))
    col.append(colbox("Stump", (0, 0, 0.3), (0.8, 0.8, 0.6)))
    save("Stump", vis, col, fname)

def log(fname="log", seed=7):
    """A fallen trunk with a broken branch, moss along the top - knee-high cover."""
    reset(); m = M(); vis = []; col = []
    vis.append(trunk(m["bark2"], (-2.2, 0, 0.32), (2.2, 0.15, 0.28), 0.34, 0.24, 8, seed, 0.1))
    vis.append(disc(m["wood"], (-2.21, 0, 0.32), 0.3, 0.02, axis='x', verts=8))
    vis.append(beam(m["bark2"], (0.6, 0.05, 0.5), (1.2, 0.5, 1.0), 0.09, 0.09))
    vis.append(blob(m["moss"], (-0.8, 0, 0.62), 0.35, (2.6, 0.8, 0.25), seed + 3, 0.2))
    col.append(colbox("Log", (0, 0.07, 0.3), (4.4, 0.62, 0.6)))
    save("Log", vis, col, fname)

def reeds(fname="reeds", seed=8):
    """A tuft of reeds and bulrushes for the bank of a stream (no collision)."""
    reset(); m = M(); vis = []
    rr = random.Random(seed)
    for k in range(16):
        x, y = rr.uniform(-0.6, 0.6), rr.uniform(-0.5, 0.5)
        hh = rr.uniform(0.8, 1.6)
        lean = Vector((rr.uniform(-0.25, 0.25), rr.uniform(-0.25, 0.25), 0))
        vis.append(beam(m["reed"], (x, y, -0.05), Vector((x, y, hh)) + lean, 0.025, 0.04))
        if k % 4 == 0:
            vis.append(tb(m["reedtop"], Vector((x, y, hh - 0.25)) + lean * 0.8, Vector((x, y, hh - 0.02)) + lean, 0.035, 6))
    save("Reeds", vis, [], fname)

def ice_shard(fname="ice_shard", seed=9):
    """A cluster of blue ice crystals leaning out of the snow."""
    reset(); m = M(); vis = []; col = []
    rr = random.Random(seed)
    for k in range(5):
        hh = rr.uniform(1.4, 3.6)
        ang = rr.uniform(0, math.tau)
        base = Vector((math.cos(ang) * rr.uniform(0, 0.6), math.sin(ang) * rr.uniform(0, 0.6), -0.1))
        tipv = base + Vector((rr.uniform(-0.6, 0.6), rr.uniform(-0.6, 0.6), hh))
        o = cyl(m["ice"] if k % 2 else m["ice2"], (0, 0, 0), rr.uniform(0.2, 0.42), hh, 5, r2=0.0)
        # tilt it from base towards the tip
        d = (tipv - base).normalized()
        q = Vector((0, 0, 1)).rotation_difference(d)
        o.rotation_mode = 'QUATERNION'
        o.rotation_quaternion = q
        o.location = base + d * hh / 2
        apply_xf(o)
        vis.append(o)
    col.append(colbox("Ice", (0, 0, 1.0), (1.4, 1.4, 2.0)))
    save("Ice", vis, col, fname)

def fruit_tree(fname="tree_fruit", seed=30):
    """A small old apple tree of the orchard: a short leaning trunk, a low wide crown, red apples."""
    reset(); m = M(); vis = []; col = []
    vis.append(trunk(m["bark2"], (0, 0, -0.1), (0.25, 0.1, 1.5), 0.2, 0.13, 7, seed, 0.12))
    rr = random.Random(seed)
    for k in range(3):
        ang = k / 3 * math.tau + rr.uniform(-0.4, 0.4)
        vis.append(trunk(m["bark2"], (0.25, 0.1, 1.3), (0.25 + math.cos(ang) * 0.9, 0.1 + math.sin(ang) * 0.9, 2.1), 0.1, 0.05, 5, seed + k))
    vis.append(blob(m["leaves"], (0.25, 0.1, 2.4), 1.35, (1.25, 1.25, 0.8), seed, 0.18, 2))
    vis.append(blob(m["leaves2"], (0.9, 0.3, 2.2), 0.8, (1, 1, 0.8), seed + 1, 0.2))
    vis.append(blob(m["leaves2"], (-0.4, -0.3, 2.3), 0.8, (1, 1, 0.8), seed + 2, 0.2))
    apple = mat2("VApple", (0.55, 0.08, 0.05), 0.6)
    for k in range(9):
        ang = rr.uniform(0, math.tau)
        rad = rr.uniform(1.2, 1.55)
        z = 2.4 + rr.uniform(-0.6, 0.3)
        vis.append(ball(apple, (0.25 + math.cos(ang) * rad, 0.1 + math.sin(ang) * rad, z), 0.08, seg=6, rings=4))
    for k in range(3):
        vis.append(ball(apple, (rr.uniform(-1.2, 1.2), rr.uniform(-1.2, 1.2), 0.05), 0.08, seg=6, rings=4))    # fallen ones
    col.append(colbox("Trunk", (0.12, 0.05, 0.8), (0.4, 0.4, 1.6)))
    save("FruitTree", vis, col, fname)

def hay_bale(fname="hay_bale", seed=31):
    """A round bale lying on its side, the end showing the rolled spiral, a strap round it."""
    reset(); m = M(); vis = []; col = []
    straw = mat2("VStraw", (0.6, 0.48, 0.2), 0.95)
    straw2 = mat2("VStrawDark", (0.45, 0.35, 0.14), 0.95)
    o = disc(straw, (0, 0, 0.62), 0.62, 1.2, axis='x', verts=14)
    vis.append(jitter(o, 0.02, seed))
    for sx in (-0.61, 0.61):
        for k in range(3):
            vis.append(disc(straw2, (sx * (1.0 + 0.002 * k), 0, 0.62), 0.5 - k * 0.15, 0.012, axis='x', verts=12))
    vis.append(disc(mat2("VStrap", (0.15, 0.2, 0.35), 0.6), (0.3, 0, 0.62), 0.635, 0.05, axis='x', verts=14))
    col.append(colbox("Bale", (0, 0, 0.6), (1.2, 1.2, 1.2)))
    save("HayBale", vis, col, fname)

def dune(fname="dune", seed=32):
    """A low drift of sand, steep on the windward side; you walk round it (collision as before)."""
    reset(); m = M(); vis = []; col = []
    sand = mat2("VSand", (0.62, 0.52, 0.34), 0.95)
    o = blob(sand, (0, 0, -0.15), 1.0, (2.6, 1.3, 0.5), seed, 0.04, 2)
    smooth(o)
    for v in o.data.vertices:
        if v.co.z < -0.15:
            v.co.z = -0.15
        if v.co.y > 0:
            v.co.z = -0.15 + (v.co.z + 0.15) * 0.75
    vis.append(o)
    o2 = blob(sand, (1.7, -0.3, -0.2), 0.6, (1.6, 1.1, 0.45), seed + 1, 0.04, 2)
    smooth(o2)
    vis.append(o2)
    col.append(colbox("Dune", (0, 0, 0.15), (4.6, 1.9, 0.6)))
    save("Dune", vis, col, fname)

ALL = dict(
    tree_spruce=lambda: spruce("tree_spruce", 7.5, 1), tree_spruce2=lambda: spruce("tree_spruce2", 5.5, 11),
    tree_pine=lambda: pine("tree_pine", 9.0, 2), tree_oak=lambda: oak("tree_oak", 6.5, 3),
    tree_oak2=lambda: oak("tree_oak2", 5.2, 13, ("leaves2", "leavesy")), tree_birch=lambda: birch("tree_birch", 7.0, 4),
    bush=lambda: bush("bush", 5, 0.8), bush2=lambda: bush("bush2", 15, 0.55),
    rock_a=lambda: rock("rock_a", 1.0, (1.3, 1.0, 0.8), 21), rock_b=lambda: rock("rock_b", 0.7, (1.0, 1.2, 1.1), 22),
    rock_c=lambda: rock("rock_c", 1.6, (1.4, 1.1, 0.95), 23), rock_d=lambda: rock("rock_d", 0.45, (1.2, 1.0, 0.7), 24, False),
    stump=stump, log=log, reeds=reeds, ice_shard=ice_shard, tree_fruit=fruit_tree, hay_bale=hay_bale, dune=dune,
)
for k, f in ALL.items():
    if not ONLY or k in ONLY:
        f()
        print("built", k)

if "--gallery" in sys.argv:
    out = sys.argv[sys.argv.index("--gallery") + 1]
    names = [k for k in ALL if not ONLY or k in ONLY]
    gallery(out, [os.path.join(OUTDIR, "v_%s.glb" % n) for n in names], cols=7, spacing=6.0, target_z=2.5,
            dist=55, height=20, angle=0.0, res=(1800, 1000))
