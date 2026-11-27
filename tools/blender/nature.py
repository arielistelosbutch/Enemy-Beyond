"""Enemy Beyond 0.56 (0.72: smooth noise crowns, root flares, chiselled stones) - nature for the maps (own designs): trees, bushes, rocks, stumps, fallen logs,
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

from kit import _nz, _shade, _two_tone, lump, bark_tube, _path, branch, stone   # (0.72 organic helpers live in kit.py)

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
    """A tall pine: a long reddish trunk bare to two thirds, crooked boughs, flat soft clumps."""
    reset(); m = M(); vis = []; col = []
    red = mat2("VBarkRed", (0.32, 0.17, 0.1), 0.95)
    pts = [(0, 0, -0.15), (0.02, 0, 0.35), (0.08, 0.04, h * 0.35), (0.16, 0.08, h * 0.62), (0.2, 0.1, h * 0.9)]
    vis.append(bark_tube(red, pts, [0.32, 0.23, 0.2, 0.14, 0.06], 10, seed, 0.08, 0.4))
    rr = random.Random(seed)
    top = Vector((0.18, 0.09, h * 0.74))
    for k in range(5):
        ang = k / 5 * TAU + rr.uniform(-0.3, 0.3)
        a = top + Vector((0, 0, rr.uniform(-0.9, 0.6)))
        tip = a + Vector((math.cos(ang) * 1.4, math.sin(ang) * 1.4, rr.uniform(0.0, 0.6)))
        vis.append(branch(red, a, tip, 0.09, 0.04, seed + k, 6, 3, 0.15))
        vis.append(lump(m["needles"] if k % 2 else m["needles2"], tip + Vector((0, 0, 0.25)), 0.95, (1.45, 1.45, 0.55), seed * 10 + k, 0.2, 3, under=m["needles2"]))
    vis.append(lump(m["needles"], top + Vector((0, 0, 1.25)), 1.05, (1.55, 1.55, 0.62), seed * 10 + 9, 0.2, 3, under=m["needles2"]))
    col.append(colbox("Trunk", (0.1, 0.05, h * 0.4), (0.48, 0.48, h * 0.8)))
    save("Pine", vis, col, fname)

def oak(fname="tree_oak", h=6.5, seed=3, mats=("leaves", "leaves2")):
    """A broad leafy tree: a thick trunk with root flares that forks into boughs, a big soft crown."""
    reset(); m = M(); vis = []; col = []
    pts = [(0, 0, -0.15), (0.02, 0, 0.3), (0.06, 0.02, h * 0.22), (0.1, 0, h * 0.45)]
    vis.append(bark_tube(m["bark2"], pts, [0.55, 0.4, 0.34, 0.27], 12, seed, 0.12, 0.45))
    rr = random.Random(seed)
    fork = Vector((0.1, 0, h * 0.42))
    tips = []
    for k in range(4):
        ang = k / 4 * TAU + rr.uniform(-0.4, 0.4)
        tip = fork + Vector((math.cos(ang) * 1.45, math.sin(ang) * 1.45, h * rr.uniform(0.22, 0.3)))
        vis.append(branch(m["bark2"], fork - Vector((0, 0, 0.25)), tip, 0.2, 0.07, seed + k, 7, 4, 0.2))
        tips.append(tip)
    cz = h * 0.72
    under = m["leaves2"]
    vis.append(lump(m[mats[0]], (0, 0, cz), 2.0, (1.15, 1.15, 0.82), seed * 10, 0.2, 3, under=under))
    for k, tp in enumerate(tips):
        vis.append(lump(m[mats[k % 2]], (tp.x * 1.1, tp.y * 1.1, cz + rr.uniform(-0.45, 0.45)), 1.35, (1, 1, 0.82), seed * 10 + k + 1, 0.24, 3, under=under))
    vis.append(lump(m[mats[1]], (0.2, -0.1, cz + 1.35), 1.25, (1, 1, 0.8), seed * 10 + 7, 0.22, 3, under=under))
    col.append(colbox("Trunk", (0.05, 0, h * 0.3), (0.75, 0.75, h * 0.6)))
    save("Oak", vis, col, fname)

def birch(fname="tree_birch", h=7.0, seed=4):
    """A slender white birch with black marks round the trunk, a light, hanging crown."""
    reset(); m = M(); vis = []; col = []
    pts = _path((0, 0, -0.15), (0.15, 0.05, h * 0.92), 5, seed, 0.18)
    vis.append(bark_tube(m["birch"], pts, [0.22, 0.15, 0.13, 0.1, 0.07, 0.04], 9, seed, 0.04, 0.3))
    rr = random.Random(seed)
    for k in range(10):
        t = 0.06 + k * 0.075
        p = pts[0].lerp(pts[-1], t)
        r = 0.16 - 0.1 * t
        ang = rr.uniform(0, TAU)
        mk = disc(m["birchm"], (0, 0, 0), r * 1.03, rr.uniform(0.03, 0.08), verts=9)
        for v in mk.data.vertices:          # only a part of the ring is black
            a = math.atan2(v.co.y, v.co.x)
            if math.cos(a - ang) < -0.2:
                v.co.x *= 0.85; v.co.y *= 0.85
        mk.location = p
        apply_xf(mk)
        vis.append(mk)
    for k in range(4):
        z = h * (0.5 + k * 0.12)
        ang = k * 1.9 + rr.uniform(-0.3, 0.3)
        a = Vector((0.12, 0.04, z - 0.6))
        c = Vector((0.12 + math.cos(ang) * 0.75, 0.05 + math.sin(ang) * 0.75, z))
        vis.append(branch(m["birch"], a, c, 0.05, 0.02, seed + k, 5, 2, 0.1))
        vis.append(lump(m["leaves"] if k % 2 else m["leavesy"] if seed % 3 == 0 else m["leaves2"], c, 0.88, (1, 1, 1.3),
                        seed * 10 + k, 0.28, 3, bumps=0.1, under=m["leaves2"]))
    col.append(colbox("Trunk", (0.07, 0.02, h * 0.4), (0.35, 0.35, h * 0.8)))
    save("Birch", vis, col, fname)

def bush(fname="bush", seed=5, r=0.8):
    """A low bush of soft clumps over a few twigs (no collision: you can push through, it hides you)."""
    reset(); m = M(); vis = []
    rr = random.Random(seed)
    for k in range(3):
        ang = k / 3 * TAU + rr.uniform(-0.5, 0.5)
        d = r * 0.5
        vis.append(lump(m["bush"] if k % 2 else m["leaves2"], (math.cos(ang) * d, math.sin(ang) * d, r * 0.5),
                        r * rr.uniform(0.62, 0.8), (1, 1, 0.82), seed * 10 + k, 0.26, 3, bumps=0.1, under=m["leaves2"]))
    vis.append(lump(m["bush"], (0, 0, r * 0.92), r * 0.72, (1, 1, 0.82), seed * 10 + 9, 0.26, 3, bumps=0.1, under=m["leaves2"]))
    for k in range(3):
        ang = k / 3 * TAU + 0.5
        vis.append(branch(m["bark2"], (0, 0, -0.05), (math.cos(ang) * r * 0.55, math.sin(ang) * r * 0.55, r * 0.45), 0.035, 0.015, seed + k, 5, 2, 0.08))
    save("Bush", vis, [], fname)

def rock(fname, r, scale, seed, moss=True):
    """A weathered boulder, half sunk into the ground, moss on the top faces."""
    reset(); m = M(); vis = []; col = []
    rr = random.Random(seed)
    vis.append(stone(m["rock"], r, scale, seed, 13, 4 if r > 0.5 else 3, m["moss"] if moss else None, m["rock2"]))
    o = stone(m["rock2"], r * 0.42, (1.2, 1, 0.75), seed + 50, 7, 2, None, None)
    o.location = (r * scale[0] * 0.62, rr.uniform(-0.3, 0.3) * r, -r * 0.08)
    apply_xf(o)
    vis.append(o)
    col.append(colbox("Rock", (0, 0, r * scale[2] * 0.6), (r * 1.6 * scale[0], r * 1.6 * scale[1], r * 1.2 * scale[2])))
    save("Rock", vis, col, fname)

def stump(fname="stump", seed=6):
    """A sawn stump with root flares, rings on the cut, a little moss."""
    reset(); m = M(); vis = []; col = []
    vis.append(bark_tube(m["bark2"], [(0, 0, -0.1), (0, 0, 0.12), (0, 0, 0.35), (0, 0, 0.55)], [0.5, 0.42, 0.37, 0.35], 14, seed, 0.1, 0.7))
    vis.append(disc(m["wood"], (0, 0, 0.555), 0.32, 0.02, verts=14))
    for k, rr_ in enumerate((0.24, 0.16, 0.08)):
        vis.append(torus(m["bark"], (0, 0, 0.566), rr_, 0.006, seg=18, mseg=4))
    for k in range(5):
        ang = k / 5 * TAU + 0.4
        vis.append(branch(m["bark2"], (math.cos(ang) * 0.28, math.sin(ang) * 0.28, 0.18), (math.cos(ang) * 0.85, math.sin(ang) * 0.85, -0.08), 0.12, 0.04, seed + k, 7, 3, 0.05))
    vis.append(lump(m["moss"], (-0.28, 0.1, 0.32), 0.18, (1.2, 0.8, 0.9), seed + 30, 0.2, 1))
    col.append(colbox("Stump", (0, 0, 0.3), (0.8, 0.8, 0.6)))
    save("Stump", vis, col, fname)

def log(fname="log", seed=7):
    """A fallen trunk with a broken branch, moss along the top - knee-high cover."""
    reset(); m = M(); vis = []; col = []
    pts = _path((-2.2, 0, 0.32), (2.2, 0.15, 0.28), 6, seed, 0.06)
    vis.append(bark_tube(m["bark2"], pts, [0.34, 0.33, 0.31, 0.3, 0.28, 0.26, 0.24], 12, seed, 0.12))
    vis.append(disc(m["wood"], (-2.205, 0, 0.32), 0.3, 0.02, axis='x', verts=12))
    for rr_ in (0.22, 0.13):
        vis.append(torus(m["bark"], (-2.215, 0, 0.32), rr_, 0.006, rot=(0, PI2, 0), seg=16, mseg=4))
    vis.append(branch(m["bark2"], (0.6, 0.05, 0.5), (1.25, 0.55, 1.05), 0.09, 0.04, seed + 2, 6, 2, 0.05))
    vis.append(branch(m["bark2"], (-0.9, -0.1, 0.45), (-1.3, -0.7, 0.75), 0.07, 0.03, seed + 3, 6, 2, 0.05))
    vis.append(lump(m["moss"], (-0.8, 0.02, 0.6), 0.3, (2.8, 0.75, 0.22), seed + 3, 0.18, 3))
    col.append(colbox("Log", (0, 0.07, 0.3), (4.4, 0.62, 0.6)))
    save("Log", vis, col, fname)

def reeds(fname="reeds", seed=8):
    """A tuft of reeds and bulrushes for the bank of a stream: curving blades and brown spikes (no collision)."""
    reset(); m = M(); vis = []
    rr = random.Random(seed)
    for k in range(26):
        x, y = rr.uniform(-0.6, 0.6), rr.uniform(-0.5, 0.5)
        hh = rr.uniform(0.8, 1.6)
        lean = Vector((rr.uniform(-0.35, 0.35), rr.uniform(-0.35, 0.35), 0))
        pts = [Vector((x, y, -0.05)) + lean * (t * t) + Vector((0, 0, hh * t)) for t in (0, 0.35, 0.7, 1.0)]
        vis.append(bark_tube(m["reed"], pts, [0.022, 0.018, 0.012, 0.002], 4, seed + k, 0.0))
        if k % 4 == 0:
            tp = pts[-1] - Vector((0, 0, 0.05))
            vis.append(tb(m["reedtop"], tp - Vector((0, 0, 0.22)) - lean * 0.08, tp, 0.035, 8))
    save("Reeds", vis, [], fname)

def crystal(m, base, tipv, r, seed):
    """One hexagonal ice crystal from base to tip, a faceted point."""
    d = (tipv - base)
    L = d.length
    o = lathe(m, [(0.0, 0.0), (r, 0.0), (r * 0.92, L * 0.72), (0.0, L)], verts=6, sm=False)
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    for v in o.data.vertices:
        v.co = q @ v.co + base
    return o

def ice_shard(fname="ice_shard", seed=9):
    """A cluster of blue ice crystals leaning out of the snow."""
    reset(); m = M(); vis = []; col = []
    rr = random.Random(seed)
    for k in range(9):
        hh = rr.uniform(0.9, 3.6) if k < 5 else rr.uniform(0.4, 1.1)
        ang = rr.uniform(0, TAU)
        base = Vector((math.cos(ang) * rr.uniform(0, 0.6), math.sin(ang) * rr.uniform(0, 0.6), -0.15))
        tipv = base + Vector((rr.uniform(-0.6, 0.6), rr.uniform(-0.6, 0.6), hh))
        vis.append(crystal(m["ice"] if k % 2 else m["ice2"], base, tipv, rr.uniform(0.18, 0.4) * (1 if k < 5 else 0.6), seed + k))
    vis.append(stone(mat2("VIceSnow", (0.86, 0.9, 0.95), 0.8), 0.7, (1.4, 1.3, 0.35), seed + 40, 6, 2))
    col.append(colbox("Ice", (0, 0, 1.0), (1.4, 1.4, 2.0)))
    save("Ice", vis, col, fname)

def fruit_tree(fname="tree_fruit", seed=30):
    """A small old apple tree of the orchard: a short leaning trunk, a low wide soft crown, red apples."""
    reset(); m = M(); vis = []; col = []
    vis.append(bark_tube(m["bark2"], _path((0, 0, -0.12), (0.25, 0.1, 1.5), 4, seed, 0.12), [0.26, 0.2, 0.18, 0.16, 0.13], 10, seed, 0.12, 0.35))
    rr = random.Random(seed)
    for k in range(4):
        ang = k / 4 * TAU + rr.uniform(-0.4, 0.4)
        vis.append(branch(m["bark2"], (0.25, 0.1, 1.3), (0.25 + math.cos(ang) * 1.0, 0.1 + math.sin(ang) * 1.0, 2.1), 0.1, 0.04, seed + k, 6, 3, 0.15))
    under = m["leaves2"]
    vis.append(lump(m["leaves"], (0.25, 0.1, 2.4), 1.35, (1.25, 1.25, 0.78), seed, 0.2, 3, under=under))
    vis.append(lump(m["leaves2"], (0.95, 0.3, 2.2), 0.8, (1, 1, 0.8), seed + 1, 0.22, 3, under=under))
    vis.append(lump(m["leaves2"], (-0.45, -0.3, 2.3), 0.8, (1, 1, 0.8), seed + 2, 0.22, 3, under=under))
    apple = mat2("VApple", (0.55, 0.08, 0.05), 0.45)
    for k in range(12):
        ang = rr.uniform(0, TAU)
        rad = rr.uniform(1.25, 1.55)
        z = 2.35 + rr.uniform(-0.6, 0.3)
        vis.append(ball(apple, (0.25 + math.cos(ang) * rad, 0.1 + math.sin(ang) * rad, z), 0.075, seg=8, rings=6))
    for k in range(4):
        vis.append(ball(apple, (rr.uniform(-1.2, 1.2), rr.uniform(-1.2, 1.2), 0.05), 0.075, seg=8, rings=6))    # fallen ones
    col.append(colbox("Trunk", (0.12, 0.05, 0.8), (0.4, 0.4, 1.6)))
    save("FruitTree", vis, col, fname)

def hay_bale(fname="hay_bale", seed=31):
    """A round bale lying on its side, the end showing the rolled spiral, two net straps round it."""
    reset(); m = M(); vis = []; col = []
    straw = mat2("VStraw", (0.6, 0.48, 0.2), 0.95)
    straw2 = mat2("VStrawDark", (0.45, 0.35, 0.14), 0.95)
    prof = [(0.0, -0.6), (0.5, -0.605), (0.6, -0.585), (0.625, -0.53), (0.63, 0.0), (0.625, 0.53), (0.6, 0.585), (0.5, 0.605), (0.0, 0.6)]
    o = lathe(straw, prof, verts=28)
    for v in o.data.vertices:
        v.co.z, v.co.x = v.co.x, v.co.z           # lie on the side (axis along x)
        v.co.z += 0.62
        d = Vector((0, v.co.y, v.co.z - 0.62))
        if d.length > 0.3:
            v.co += d.normalized() * 0.012 * _nz.noise(v.co * 6.0 + Vector((seed, 0, 0)))
    _fix_normals(o)
    vis.append(o)
    for sx in (-1, 1):
        for k in range(4):
            r = 0.52 - k * 0.12
            t = torus(straw2, (sx * 0.603, 0, 0.62), r, 0.012, rot=(0, PI2, 0), seg=24, mseg=4)
            vis.append(t)
    strap = mat2("VStrap", (0.15, 0.2, 0.35), 0.6)
    for x in (-0.3, 0.3):
        vis.append(torus(strap, (x, 0, 0.62), 0.633, 0.012, rot=(0, PI2, 0), seg=28, mseg=4))
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


# ---- (Ari 27. 11.) hot climates: palms, acacias, jungle trees, cacti ----------------------------------
def frond(m, base, ang, length, droop, width, seed, lean=0.35):
    """A palm frond: a bent spine out from the crown, a V of leaflets along it, ragged edge, both sides."""
    rr = random.Random(seed)
    me = bpy.data.meshes.new("frond")
    bm = bmesh.new()
    base = Vector(base)
    n = 9
    d = Vector((math.cos(ang), math.sin(ang), 0))
    side = Vector((-d.y, d.x, 0))
    spine, left, right = [], [], []
    for i in range(n + 1):
        t = i / n
        p = base + d * (length * t) + Vector((0, 0, length * (lean * t - droop * t * t)))
        w = width * math.sin(math.pi * min(1.0, t * 1.15)) * (0.75 + 0.25 * rr.random())
        if i % 2 and i < n:
            w *= 0.7        # ragged
        spine.append(bm.verts.new(p))
        left.append(bm.verts.new(p + side * w + Vector((0, 0, -w * 0.35))))
        right.append(bm.verts.new(p - side * w + Vector((0, 0, -w * 0.35))))
    for i in range(n):
        for a, b in ((left, spine), (spine, right)):
            f = (a[i], a[i + 1], b[i + 1], b[i]) if a is left else (a[i], a[i + 1], b[i + 1], b[i])
            bm.faces.new(f)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("frond", me)
    bpy.context.collection.objects.link(o)
    return _finish(o, m, (0, 0, 0), (0, 0, 0), (1, 1, 1))

def palm(fname="tree_palm", h=7.5, seed=40, lean=0.9):
    """A date / coconut palm: a curved ringed trunk, a tuft of drooping fronds, a cluster of fruit."""
    reset(); m = M(); vis = []; col = []
    bark = mat2("VBarkPalm", (0.36, 0.28, 0.19), 0.95)
    rr = random.Random(seed)
    pts = []
    for i in range(7):
        t = i / 6
        pts.append((lean * t * t, 0.15 * math.sin(t * 2.0), -0.15 + h * t))
    radii = [0.3, 0.22, 0.2, 0.19, 0.18, 0.17, 0.16]
    vis.append(bark_tube(bark, pts, radii, 9, seed, 0.12, 0.25))
    top = Vector(pts[-1])
    for k in range(5):          # rings of old leaf bases
        t = 0.25 + k * 0.14
        i = int(t * 6)
        c = Vector(pts[i]).lerp(Vector(pts[min(6, i + 1)]), t * 6 - i)
        vis.append(disc(bark, c, radii[i] * 1.18, 0.09, verts=9))
    vis.append(lump(m["leaves2"], top + Vector((0, 0, 0.1)), 0.42, (1, 1, 0.8), seed, 0.2, 2))
    for k in range(9):
        ang = k / 9 * TAU + rr.uniform(-0.2, 0.2)
        vis.append(frond(m["leaves"] if k % 2 else m["leaves2"], top + Vector((0, 0, 0.15)), ang,
                         rr.uniform(2.8, 3.4), rr.uniform(1.0, 1.25), rr.uniform(0.5, 0.62), seed * 10 + k, 0.7))
    for k in range(3):          # a few up, young
        ang = k / 3 * TAU + 0.5
        vis.append(frond(m["leaves"], top + Vector((0, 0, 0.2)), ang, 1.6, 0.2, 0.25, seed * 20 + k, 0.9))
    fruit = mat2("VDates", (0.42, 0.22, 0.08), 0.8)
    for k in range(4):
        a = k / 4 * TAU
        vis.append(ball(fruit, top + Vector((math.cos(a) * 0.3, math.sin(a) * 0.3, -0.25)), 0.14, seg=8, rings=6))
    col.append(colbox("Trunk", (lean * 0.3, 0, h * 0.35), (0.5, 0.5, h * 0.7)))
    save("Palm", vis, col, fname)

def acacia(fname="tree_acacia", h=5.5, seed=42):
    """A savanna acacia: a short leaning trunk forking low into long boughs, a flat wide umbrella crown."""
    reset(); m = M(); vis = []; col = []
    pts = [(0, 0, -0.15), (0.05, 0, 0.4), (0.2, 0.05, h * 0.35)]
    vis.append(bark_tube(m["bark2"], pts, [0.32, 0.24, 0.19], 9, seed, 0.12, 0.35))
    rr = random.Random(seed)
    fork = Vector(pts[-1])
    cz = h * 0.92
    for k in range(5):
        ang = k / 5 * TAU + rr.uniform(-0.3, 0.3)
        tip = Vector((math.cos(ang) * 2.4, math.sin(ang) * 2.4, cz - 0.25))
        vis.append(branch(m["bark2"], fork, tip, 0.13, 0.05, seed + k, 6, 4, 0.3))
        vis.append(lump(m["leaves"] if k % 2 else m["leaves2"], tip + Vector((0, 0, 0.2)), 1.35, (1.3, 1.3, 0.22),
                        seed * 10 + k, 0.2, 3, under=m["leaves2"]))
    vis.append(lump(m["leaves"], (0, 0, cz + 0.15), 1.9, (1.4, 1.4, 0.2), seed * 10 + 9, 0.18, 3, under=m["leaves2"]))
    col.append(colbox("Trunk", (0.1, 0, h * 0.25), (0.55, 0.55, h * 0.5)))
    save("Acacia", vis, col, fname)

def jungle(fname="tree_jungle", h=10.0, seed=44):
    """A tall rainforest tree: buttress roots, a straight pale trunk, lianas, layered dark crown."""
    reset(); m = M(); vis = []; col = []
    pale = mat2("VBarkPale", (0.38, 0.34, 0.27), 0.95)
    pts = [(0, 0, -0.15), (0.02, 0, 0.6), (0.06, 0.02, h * 0.4), (0.1, 0, h * 0.75)]
    vis.append(bark_tube(pale, pts, [0.7, 0.4, 0.33, 0.26], 12, seed, 0.1, 0.9))
    rr = random.Random(seed)
    for k in range(4):       # buttresses: flat fins out from the foot
        a = k / 4 * TAU + rr.uniform(-0.3, 0.3)
        o = bx(pale, (math.cos(a) * 0.55, math.sin(a) * 0.55, 0.45), (1.1, 0.12, 1.0), 0.0, (0, 0, a))
        for v in o.data.vertices:
            if v.co.z > 0 and v.co.x > 0:
                v.co.z -= 0.7
        vis.append(o)
    liana = mat2("VLiana", (0.18, 0.22, 0.1), 0.95)
    for k in range(3):
        a = k / 3 * TAU + 0.4
        vis.append(branch(liana, (math.cos(a) * 1.6, math.sin(a) * 1.6, h * 0.78), (math.cos(a) * 0.9, math.sin(a) * 0.9, 0.3), 0.04, 0.03, seed + k, 5, 5, 0.25))
    cz = h * 0.8
    for k in range(5):
        ang = k / 5 * TAU + rr.uniform(-0.3, 0.3)
        tip = Vector((math.cos(ang) * 2.0, math.sin(ang) * 2.0, cz + rr.uniform(-0.5, 0.4)))
        vis.append(branch(pale, (0.1, 0, cz - 1.0), tip, 0.18, 0.07, seed + k, 6, 3, 0.2))
        vis.append(lump(m["leaves2"] if k % 2 else m["leaves"], tip, 1.6, (1.2, 1.2, 0.6), seed * 10 + k, 0.24, 3, under=m["leaves2"]))
    vis.append(lump(m["leaves2"], (0.1, 0, cz + 0.9), 2.2, (1.2, 1.2, 0.55), seed * 10 + 8, 0.2, 3, under=m["leaves2"]))
    col.append(colbox("Trunk", (0.05, 0, h * 0.35), (0.85, 0.85, h * 0.7)))
    save("Jungle", vis, col, fname)

def bush_jungle(fname="bush_jungle", seed=46):
    """A big-leaved undergrowth clump (banana-like leaves fanning out of a low heart)."""
    reset(); m = M(); vis = []
    rr = random.Random(seed)
    vis.append(lump(m["bush"], (0, 0, 0.3), 0.55, (1.2, 1.2, 0.7), seed, 0.2, 2))
    for k in range(8):
        ang = k / 8 * TAU + rr.uniform(-0.25, 0.25)
        vis.append(frond(m["leaves"] if k % 2 else m["bush"], (0, 0, 0.35), ang, rr.uniform(1.1, 1.5),
                         rr.uniform(0.6, 0.9), rr.uniform(0.28, 0.38), seed * 10 + k, 0.9))
    save("JungleBush", vis, [], fname)

def cactus(fname="cactus", h=3.2, seed=48, arms=2):
    """A saguaro-like column cactus: ribbed column, arms bending up; a pad cactus at its foot."""
    reset(); m = M(); vis = []; col = []
    green = mat2("VCactus", (0.22, 0.32, 0.16), 0.85)
    rib = mat2("VCactusRib", (0.3, 0.4, 0.22), 0.85)
    rr = random.Random(seed)
    def column(a, b, r):
        o = tb(green, a, b, r, verts=10)
        for i, v in enumerate(o.data.vertices):
            pass
        vis.append(o)
        vis.append(ball(green, b, r, seg=10, rings=6))
        for k in range(5):
            ang = k / 5 * TAU
            off = Vector((math.cos(ang) * r * 0.92, math.sin(ang) * r * 0.92, 0))
            vis.append(tb(rib, Vector(a) + off, Vector(b) + off * 0.98, r * 0.13, verts=4))
    column((0, 0, -0.1), (0, 0, h), 0.24)
    for k in range(arms):
        side = 1 if k == 0 else -1
        z = h * rr.uniform(0.35, 0.55)
        out = Vector((side * 0.62, rr.uniform(-0.1, 0.1), z + 0.15))
        vis.append(tb(green, (0, 0, z), out, 0.15, verts=8))
        vis.append(ball(green, out, 0.155, seg=8, rings=6))
        column(out, out + Vector((0, 0, rr.uniform(0.7, 1.1))), 0.15)
    pad = mat2("VCactusPad", (0.28, 0.36, 0.15), 0.85)
    for k in range(3):
        a = k * 2.1
        vis.append(ball(pad, (0.6 * math.cos(a) + 0.4, 0.6 * math.sin(a), 0.18 + 0.1 * k), 0.2, (1, 0.35, 1.2), 8, 6, (0, 0, a)))
    col.append(colbox("Trunk", (0, 0, h * 0.5), (0.5, 0.5, h)))
    save("Cactus", vis, col, fname)

ALL = dict(
    tree_spruce=lambda: spruce("tree_spruce", 7.5, 1), tree_spruce2=lambda: spruce("tree_spruce2", 5.5, 11),
    tree_pine=lambda: pine("tree_pine", 9.0, 2), tree_oak=lambda: oak("tree_oak", 6.5, 3),
    tree_oak2=lambda: oak("tree_oak2", 5.2, 13, ("leaves2", "leavesy")), tree_birch=lambda: birch("tree_birch", 7.0, 4),
    bush=lambda: bush("bush", 5, 0.8), bush2=lambda: bush("bush2", 15, 0.55),
    rock_a=lambda: rock("rock_a", 1.0, (1.3, 1.0, 0.8), 21), rock_b=lambda: rock("rock_b", 0.7, (1.0, 1.2, 1.1), 22),
    rock_c=lambda: rock("rock_c", 1.6, (1.4, 1.1, 0.95), 23), rock_d=lambda: rock("rock_d", 0.45, (1.2, 1.0, 1.15), 24, False),
    stump=stump, log=log, reeds=reeds, ice_shard=ice_shard, tree_fruit=fruit_tree, hay_bale=hay_bale, dune=dune,
    tree_palm=lambda: palm("tree_palm", 7.5, 40, 0.9), tree_palm2=lambda: palm("tree_palm2", 5.8, 41, 0.35),
    tree_acacia=lambda: acacia("tree_acacia", 5.5, 42), tree_acacia2=lambda: acacia("tree_acacia2", 4.4, 43),
    tree_jungle=lambda: jungle("tree_jungle", 10.0, 44), bush_jungle=lambda: bush_jungle("bush_jungle", 46),
    cactus=lambda: cactus("cactus", 3.2, 48, 2), cactus2=lambda: cactus("cactus2", 2.2, 49, 1),
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
