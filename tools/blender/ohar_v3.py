"""Ohař v3 (0.57) after Ari's picture, built for afk.ai auto-rigging: a heavy, muscular flayed hound - deep chest,
thick shoulders and thighs, head carried low and forward, long jaw a little open full of fangs, a long steel blade
bolted along the snout, violet eyes. Armoured spine of steel plates with violet light between them and curved spikes,
hose loops over the back, a glowing violet canister on the neck, violet light between the ribs, steel clamps on the
legs, big hooked steel claws, a tail.

For the rigger the whole thing is ONE closed watertight mesh: every part is overlapped into the body and the lot is
voxel-remeshed (no loose pieces, no internal faces), then decimated back to a game budget. Colours are put back
afterwards from the nearest original part, so it keeps the plain-colour look (hide, raw muscle, steel, violet glow).
Standing pose, legs straight under the body, tail back, mouth slightly open. No weapon (it is a beast).
Run: python ohar_v3.py <out_base_without_ext> [--preview <dir>] [--tris N]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from creature_v2 import *
from creature_v2 import _apply_mods, _finish
from mathutils.bvhtree import BVHTree

NAME = "ohar_v3"
VOXEL = 0.0065
LIFT = 0.12
TRIS = int(sys.argv[sys.argv.index("--tris") + 1]) if "--tris" in sys.argv else 24000
reset()
hide = mat2("OhaHide", (0.3, 0.165, 0.16), rough=0.45)
hide2 = mat2("OhaHide2", (0.19, 0.09, 0.1), rough=0.5)
raw = mat2("OhaRaw", (0.38, 0.035, 0.055), rough=0.3)
mouth_m = mat2("OhaMouth", (0.1, 0.01, 0.02), rough=0.4)
tooth = mat2("OhaTooth", (0.78, 0.72, 0.6), rough=0.35)
steel = mat2("OhaSteel", (0.3, 0.29, 0.31), rough=0.35, metal=0.85)
blade_m = mat2("OhaBlade", (0.66, 0.64, 0.66), rough=0.2, metal=0.95)
blood = mat2("OhaBlood", (0.32, 0.015, 0.03), rough=0.3)
hose = mat2("OhaHose", (0.14, 0.08, 0.17), rough=0.5)
glow = mat("OhaGlow", (0.62, 0.1, 1.0), emit=2.0)
eye = mat("OhaEye", (0.75, 0.2, 1.0), emit=3.0)
FLAT = {"OhaSteel", "OhaBlade", "OhaGlow", "OhaTooth"}          # faceted parts; flesh stays smooth

# ---- skeleton of the body (skin modifier) ---------------------------------------------------------------------------
SPINE = [((0, -0.64, 0.88), 0.17), ((0, -0.42, 0.87), 0.15), ((0, -0.2, 0.9), 0.17), ((0, 0.04, 0.94), 0.21),
         ((0, 0.27, 0.98), 0.24), ((0, 0.47, 1.0), 0.22), ((0, 0.66, 0.97), 0.17), ((0, 0.8, 0.94), 0.15),
         ((0, 0.92, 0.93), 0.13)]
TAIL = [((0, -0.82, 0.86), 0.085), ((0, -1.0, 0.8), 0.062), ((0, -1.18, 0.7), 0.045), ((0, -1.34, 0.58), 0.032),
        ((0, -1.47, 0.47), 0.02)]
KEEL = [((0, 0.14, 0.76), 0.17), ((0, 0.34, 0.78), 0.16)]
FRONT = [((0.15, 0.45, 0.92), 0.14), ((0.2, 0.36, 0.62), 0.105), ((0.21, 0.38, 0.4), 0.085), ((0.21, 0.42, 0.2), 0.075),
         ((0.21, 0.47, 0.075), 0.082), ((0.21, 0.56, 0.055), 0.062)]
HIND = [((0.15, -0.6, 0.84), 0.16), ((0.19, -0.44, 0.56), 0.12), ((0.2, -0.56, 0.42), 0.09), ((0.2, -0.66, 0.26), 0.075),
        ((0.2, -0.62, 0.075), 0.075), ((0.2, -0.53, 0.055), 0.06)]


def chain(nodes, parent=None, mirror=1, name="OhaBody"):
    """One clean tube per chain (a branch-free skin is always manifold); starts inside its parent node."""
    pts = ([parent] if parent else []) + [((p[0] * mirror, p[1], p[2]), r) for p, r in nodes]
    return skin(hide, pts, [(i, i + 1) for i in range(len(pts) - 1)], name, subsurf=2)


BODY = [chain(SPINE), chain(TAIL, parent=SPINE[0]), chain(KEEL, parent=SPINE[3])]
for m in (1, -1):
    BODY.append(chain(FRONT, parent=SPINE[5], mirror=m))
    BODY.append(chain(HIND, parent=SPINE[0], mirror=m))


def spine_at(y):
    """(centre z, radius) of the trunk at y."""
    for (a, ra), (b, rb) in zip(SPINE, SPINE[1:]):
        if a[1] <= y <= b[1]:
            t = (y - a[1]) / (b[1] - a[1])
            return a[2] + (b[2] - a[2]) * t, (ra + (rb - ra) * t) * 0.92
    (a, r) = SPINE[0] if y < SPINE[0][0][1] else SPINE[-1]
    return a[2], r * 0.92


def leg_at(L, t):
    f = t * (len(L) - 1)
    i = min(int(f), len(L) - 2)
    u = f - i
    p = Vector(L[i][0]).lerp(Vector(L[i + 1][0]), u)
    return p, (L[i][1] + (L[i + 1][1] - L[i][1]) * u) * 0.92


def horn(material, base, d1, d2, r):
    """A curved spike/claw in two pieces: base -> base+d1 -> +d2."""
    b = Vector(base); m = b + Vector(d1); t = m + Vector(d2)
    return [limb(material, b, m, r, r * 0.62, verts=6, sm=False), spike(material, m, t, r * 0.66, verts=6)]


A = list(BODY)
side = []
# ---- muscle masses and flayed patches ---------------------------------------------------------------------------------
side.append(smooth(sphere(hide, (0.15, 0.42, 0.86), 0.15, seg=18, rings=12, scale=(0.62, 1.0, 1.25), rot=(0.3, 0, 0))))   # shoulder
side.append(smooth(sphere(hide, (0.17, 0.37, 0.58), 0.1, seg=14, rings=10, scale=(0.75, 0.95, 1.5), rot=(0.1, 0, 0))))     # forearm
side.append(smooth(sphere(hide, (0.14, -0.52, 0.72), 0.15, seg=18, rings=12, scale=(0.6, 1.0, 1.4), rot=(-0.4, 0, 0))))  # thigh
side.append(smooth(sphere(raw, (0.205, -0.5, 0.72), 0.11, seg=14, rings=10, scale=(0.45, 0.9, 1.25), rot=(-0.4, 0, 0))))   # flayed thigh
side.append(smooth(sphere(raw, (0.215, 0.38, 0.6), 0.07, seg=12, rings=8, scale=(0.45, 0.8, 1.6), rot=(0.1, 0, 0))))      # flayed forearm
side.append(smooth(sphere(raw, (0.2, 0.44, 0.84), 0.08, seg=12, rings=8, scale=(0.45, 0.9, 1.3), rot=(0.3, 0, 0))))       # flayed shoulder
zc, r = spine_at(-0.25)
side.append(smooth(sphere(raw, (r * 0.86, -0.25, zc - 0.03), 0.07, seg=12, rings=8, scale=(0.45, 2.0, 0.9))))           # flank wound
for k in range(5):
    side.append(bbox(blood, (r * 0.97, -0.33 + k * 0.04, zc + 0.025 - k * 0.012), (0.03, 0.014, 0.014)))     # stitches
# ribs: dark bars over the chest with violet light glowing out between them
for k in range(5):
    y = 0.33 - k * 0.095
    zc, r = spine_at(y)
    pts = [Vector((r * math.sin(a) * 0.97, y - (a - 0.6) * 0.03, zc + r * math.cos(a) * 0.97)) for a in (0.75, 1.25, 1.75, 2.25)]
    side += tube(hide2, pts, 0.026, verts=8)
    if k < 4:
        yg = y - 0.048
        zg, rg = spine_at(yg)
        side += tube(glow, [Vector((rg * math.sin(a) * 0.93, yg - (a - 0.6) * 0.03, zg + rg * math.cos(a) * 0.93))
                            for a in (0.85, 1.3, 1.75, 2.15)], 0.02, verts=8)
# leg clamps
for L, ts in ((FRONT, (0.42, 0.62)), (HIND, (0.3, 0.6))):
    for t in ts:
        a, ra = leg_at(L, t - 0.04)
        b, rb = leg_at(L, t + 0.04)
        side.append(band(steel, a, b, 0.5, (ra + rb) / 2 * 1.0, 0.018))
side.append(bbox(steel, (0.21, 0.42, 1.0), (0.1, 0.24, 0.1), rot=(0.25, -0.55, 0), bevel=0.3, seg=2))      # shoulder plate
side.append(bbox(steel, (0.2, -0.58, 0.92), (0.1, 0.22, 0.09), rot=(-0.25, -0.55, 0), bevel=0.3, seg=2))   # hip plate
# paws: three big hooked steel claws + a back claw, rooted deep in the paw
for L in (FRONT, HIND):
    paw = Vector(L[-2][0])
    for c in (-1, 0, 1):
        b0 = paw + Vector((c * 0.04, 0.02, 0.0))
        side += horn(steel, b0, (c * 0.02, 0.1, 0.0), (c * 0.01, 0.06, -0.06), 0.022)
    side += horn(steel, paw + Vector((0, -0.02, 0.03)), (0, -0.07, -0.01), (0, -0.04, -0.04), 0.018)
# hose along the outside of the front leg, lying on it
pts = [Vector((0.25, 0.47, 0.92)), Vector((0.28, 0.37, 0.7)), Vector((0.27, 0.36, 0.52)), Vector((0.26, 0.4, 0.34))]
side += tube(hose, pts, 0.02, verts=8)
A += side + mirror_x(side)
# ---- the armoured spine: plates, violet slots, curved spikes, hose loops ------------------------------------------------
PLATES = [-0.62 + k * 0.14 for k in range(9)]                       # -0.62 ... 0.5
for k, y in enumerate(PLATES):
    zc, r = spine_at(y)
    z = zc + r - 0.01
    w = 0.26 - abs(k - 5) * 0.012
    A.append(bbox(steel, (0, y, z), (w, 0.12, 0.075), rot=(0.08, 0, 0), bevel=0.3, seg=2))
    for x in (1, -1):
        A.append(bbox(steel, (0.12 * x, y, z - 0.05), (0.1, 0.11, 0.05), rot=(0.08, 0.8 * x, 0), bevel=0.3, seg=2))
    if k < len(PLATES) - 1:
        A.append(bbox(glow, (0, y + 0.07, z + 0.005), (w * 0.8, 0.028, 0.06)))
    if k >= 1:
        hgt = 0.09 + min(k, 6) * 0.03                                 # tallest over the shoulders
        A += horn(steel, (0, y + 0.02, z + 0.02), (0, -0.015, hgt * 0.6), (0, -0.07, hgt * 0.5), 0.038)
for k, (p, rr) in enumerate(TAIL[:4]):                                # tail hooks
    p = Vector(p)
    A += horn(steel, p + Vector((0, 0.02, rr * 0.5)), (0, -0.02, 0.05 - k * 0.006), (0, -0.05, 0.02), 0.018 - k * 0.002)
for x in (1, -1):                                                      # hose loops arching over the back
    for y0, y1, up in ((-0.5, -0.2, 0.14), (-0.08, 0.2, 0.17)):
        za, ra = spine_at(y0); zb, rb = spine_at(y1)
        P0 = Vector((0.13 * x, y0, za + ra * 0.85)); P1 = Vector((0.13 * x, y1, zb + rb * 0.85))
        pts = []
        for i in range(7):
            t = i / 6
            q = P0.lerp(P1, t)
            q.z += up * math.sin(math.pi * t); q.x += 0.06 * x * math.sin(math.pi * t)
            pts.append(q)
        A += tube(hose, pts, 0.022, verts=8)
# ---- neck canister in a steel cage, neck clamps -------------------------------------------------------------------------
na, nb = Vector(SPINE[5][0]), Vector(SPINE[7][0])
cdir = (nb - na).normalized()
crot = cdir.to_track_quat('Z', 'Y').to_euler()
cax = na.lerp(nb, 0.55) + Vector((0, 0, 0.17))
A.append(smooth(cyl(glow, cax, 0.06, 0.26, verts=16, rot=crot)))
for dy in (-0.14, 0.14):
    A.append(smooth(cyl(steel, cax + cdir * dy, 0.072, 0.05, verts=16, rot=crot)))
for a in (0.0, 1.57, 3.14, 4.71):
    off = Vector((math.sin(a) * 0.066, 0, math.cos(a) * 0.066))
    A.append(limb(steel, cax - cdir * 0.14 + off, cax + cdir * 0.14 + off, 0.011, 0.011, verts=6))
A.append(bbox(steel, cax + Vector((0, 0, -0.085)), (0.1, 0.24, 0.07), rot=crot, bevel=0.3))
for t in (0.35, 0.8):
    p = na.lerp(nb, t + 0.15)
    A.append(band(steel, p - cdir * 0.03, p + cdir * 0.03, 0.5, spine_at(min(p.y, 0.92))[1] * 0.98, 0.02))
for x in (1, -1):
    pts = [cax - cdir * 0.14 + Vector((0.04 * x, 0, 0)), Vector((0.1 * x, 0.5, 1.15)), Vector((0.16 * x, 0.46, 1.06))]
    A += tube(hose, pts, 0.019, verts=8)
# ---- the head: long wedge skull carried low, eyes, brow, jaw a little open full of fangs, blade on the snout ----------
H = []
H.append(smooth(sphere(hide, (0, 0.97, 0.96), 0.13, seg=20, rings=14, scale=(0.95, 1.1, 0.85))))          # cranium
UP_EDGE = lambda y: 0.905 - (y - 0.98) * 0.12                                                          # upper gum line z
sn = box(hide, (0, 1.15, 0.95), (1, 1, 1))                                                             # angular upper snout
for v in sn.data.vertices:
    front = v.co.y > 1.15
    yy = 1.33 if front else 0.95
    v.co.y = yy
    v.co.x = (0.045 if front else 0.085) * (1 if v.co.x > 0 else -1)
    v.co.z = (0.95 if front else 1.02) if v.co.z > 0.95 else UP_EDGE(yy) + 0.012
m_ = sn.modifiers.new("Bev", 'BEVEL'); m_.width = 0.02; m_.segments = 2; m_.limit_method = 'NONE'
_apply_mods(sn)
H.append(sn)
for x in (1, -1):
    H.append(smooth(sphere(hide, (0.07 * x, 0.9, 0.89), 0.06, seg=14, rings=10, scale=(0.6, 1.3, 1.0))))  # jaw muscle
HG = Vector((0, 0.93, 0.86)); JA = -0.33                                                               # jaw hinge / angle
JD = Vector((0, math.cos(JA), math.sin(JA))); JN = Vector((0, -math.sin(JA), math.cos(JA)))
H.append(smooth(sphere(hide2, HG + JD * 0.17, 0.07, seg=18, rings=12, scale=(0.9, 2.5, 0.5), rot=(JA, 0, 0))))  # lower jaw
UP_EDGE = lambda y: 0.905 - (y - 0.98) * 0.12                                                          # upper gum line z
# dark mouth wedge filling the gap between the jaws (reads as an open, dark mouth)
mw = box(mouth_m, (0, 1.1, 0.86), (0.1, 0.3, 0.1))
for v in mw.data.vertices:
    yy = v.co.y; t = (yy - 0.95) / 0.3
    if v.co.z > 0.86:
        v.co.z = UP_EDGE(yy) + 0.01
    else:
        v.co.z = (HG + JD * ((yy - HG.y) / JD.y)).z + 0.035
    v.co.x *= (1 - 0.35 * t)
H.append(mw)
for x in (1, -1):
    H.append(smooth(sphere(eye, (0.088 * x, 1.035, 0.975), 0.03, seg=12, rings=8, scale=(0.75, 1.25, 0.8))))
    H.append(bbox(hide2, (0.075 * x, 0.99, 1.02), (0.05, 0.1, 0.03), rot=(-0.15, 0, 0.35 * x), bevel=0.3))   # brow ridge
    for i in range(7):                                                                                   # upper fangs
        y = 0.99 + i * 0.042
        w = 0.06 * (1 - i * 0.08)
        ln = 0.075 if i in (1, 4) else 0.042
        z0 = UP_EDGE(y) + 0.02
        H.append(spike(tooth, (w * x, y, z0), (w * x * 0.95, y + 0.012, z0 - 0.02 - ln), 0.013 if ln < 0.05 else 0.017, verts=6))
    for i in range(6):                                                                                   # lower fangs
        sj = 0.08 + i * 0.045
        w = 0.052 * (1 - i * 0.09)
        bse = HG + JD * sj + JN * 0.012 + Vector((w * x, 0, 0))
        ln = 0.07 if i in (1, 4) else 0.04
        H.append(spike(tooth, bse, bse + JN * ln + JD * 0.01, 0.013 if ln < 0.05 else 0.017, verts=6))
# the blade: a long wedge bolted along the top of the snout, reaching far past the nose, blood on it
bl = box(blade_m, (0, 1.36, 1.0), (1, 1, 1))
for v in bl.data.vertices:
    t = 1.0 if v.co.y > 1.36 else 0.0
    v.co.y = 0.95 + t * 0.85
    v.co.x = (0.042 * (1 - t) + 0.008 * t) * (1 if v.co.x > 0 else -1)
    v.co.z = (1.08 - t * 0.2) if v.co.z > 1.0 else (0.93 - t * 0.06)
H.append(bl)
for y, w, zz in ((1.03, 0.15, 1.02), (1.2, 0.11, 0.98)):
    H.append(bbox(steel, (0, y, zz), (w, 0.045, 0.1), bevel=0.25))
    for x in (1, -1):
        H.append(smooth(sphere(steel, (w * 0.5 * x, y, zz + 0.03), 0.016, seg=8, rings=6)))               # bolts
M = Matrix.Translation((0, 0.86, 0.93)) @ Matrix.Scale(1.2, 4) @ Matrix.Translation((0, -0.86, -0.93))
for h in H:                                                      # a bigger, meaner head
    h.data.transform(M)
A += H

# ---- one watertight mesh: join, voxel remesh, colour back from the nearest original part, decimate ------------------
src = join(A, "OhaSrc")
for v in src.data.vertices:                                      # longer legs: lift the body, stretch everything below it
    z = v.co.z
    v.co.z = z + LIFT * min(1.0, z / 0.75)
src.data.update()
deps = bpy.context.evaluated_depsgraph_get()
bvh = BVHTree.FromObject(src, deps)
src_mat = [p.material_index for p in src.data.polygons]
mats = [m for m in src.data.materials]

o = src.copy()
o.data = src.data.copy()
o.name = NAME
o.data.name = NAME
bpy.context.scene.collection.objects.link(o)
bpy.ops.object.select_all(action='DESELECT')
o.select_set(True)
bpy.context.view_layer.objects.active = o
o.data.remesh_voxel_size = VOXEL
o.data.use_remesh_fix_poles = True
bpy.ops.object.voxel_remesh()
for m in mats:
    if m.name not in [x.name for x in o.data.materials if x]:
        o.data.materials.append(m)
for p in o.data.polygons:
    loc, nrm, fi, d = bvh.find_nearest(p.center)
    p.material_index = src_mat[fi] if fi is not None else 0
bpy.data.objects.remove(src)
bi, bl_i = mats.index(blade_m), mats.index(blood)
for p in o.data.polygons:                                       # blood smeared on the blade's lower edge
    c = p.center
    edge = 0.93 + 0.042 + LIFT - (c.y - 0.968) / 1.02 * 0.09               # blade's lower edge (after head scale + lift)
    if p.material_index == bi and c.z < edge + 0.02 and (1.52 < c.y < 1.6 or 1.78 < c.y < 1.82):
        p.material_index = bl_i
bm = bmesh.new()
bm.from_mesh(o.data)
bm.verts.ensure_lookup_table()
seen, keep = set(), None
for v in bm.verts:                                               # keep only the biggest piece
    if v.index in seen:
        continue
    st, comp = [v], []
    seen.add(v.index)
    while st:
        x = st.pop(); comp.append(x)
        for e in x.link_edges:
            w = e.other_vert(x)
            if w.index not in seen:
                seen.add(w.index); st.append(w)
    if keep is None or len(comp) > len(keep):
        keep = comp
kset = set(keep)
bmesh.ops.delete(bm, geom=[v for v in bm.verts if v not in kset], context='VERTS')
bm.to_mesh(o.data)
bm.free()

tris0 = sum(len(p.vertices) - 2 for p in o.data.polygons)
dm = o.modifiers.new("Dec", 'DECIMATE')
dm.ratio = min(1.0, TRIS / max(tris0, 1))
dm.use_collapse_triangulate = True
_apply_mods(o)
for p in o.data.polygons:
    p.use_smooth = o.data.materials[p.material_index].name not in FLAT
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.normals_make_consistent(inside=False)
bpy.ops.object.mode_set(mode='OBJECT')

bm = bmesh.new()
bm.from_mesh(o.data)
seen, isl = set(), []
for v in bm.verts:
    if v.index in seen:
        continue
    st, n = [v], 0
    seen.add(v.index)
    while st:
        x = st.pop(); n += 1
        for e in x.link_edges:
            w = e.other_vert(x)
            if w.index not in seen:
                seen.add(w.index); st.append(w)
    isl.append(n)
nm = sum(1 for e in bm.edges if not e.is_manifold)
bm.free()
used = sorted({o.data.materials[p.material_index].name for p in o.data.polygons})
print("STATS", stats(o), "remesh tris", tris0, "islands", sorted(isl, reverse=True)[:6], "count", len(isl),
      "non-manifold edges", nm, "materials", used)

ARGS = sys.argv[1:]
OUT = ARGS[0] if ARGS and not ARGS[0].startswith("--") else NAME
if "--preview" in sys.argv:
    d = sys.argv[sys.argv.index("--preview") + 1]
    render(os.path.join(d, NAME + "_side.png"), (0, 0.05, 0.7), 4.3, 1.5708, 0.25)
    render(os.path.join(d, NAME + "_34.png"), (0, 0.1, 0.7), 4.0, 0.7, 1.1)
    render(os.path.join(d, NAME + "_head.png"), (0, 1.1, 0.95), 1.5, 0.9, 0.25)
    render(os.path.join(d, NAME + "_back.png"), (0, -0.2, 0.75), 4.0, 2.5, 1.2)
else:
    export_all(o, OUT)
    print("written", OUT)
