"""Enemy Beyond 0.52 - shared shape helpers for the reworked props, craft and gear (the look of
guns.py / warzone.py: chamfered plates, round tubes, screws, panel lines; materials that keep colour,
roughness, metal and emission - the game restyles them by base colour, metallic >= 0.25 gets a sheen,
a material whose name ends in "Glass" turns see-through).
Blender is Z-up, models face +Y (Godot -Z)."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
from common import *
from common import _finish
from mathutils import Vector, Matrix

TAU = math.tau
PI2 = math.pi / 2

def mat2(name, rgb, rough=0.7, metal=0.0, emit=0.0):
    m = mat(name, rgb, emit=emit, rough=rough)
    m.node_tree.nodes.get("Principled BSDF").inputs["Metallic"].default_value = metal
    return m

def _sel(o):
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o

def bev(o, w, seg=1):
    """Chamfer every sharp edge (catches the light)."""
    if w <= 0:
        return o
    _sel(o)
    m = o.modifiers.new("Bevel", 'BEVEL')
    m.width = w
    m.segments = seg
    m.limit_method = 'ANGLE'
    bpy.ops.object.modifier_apply(modifier="Bevel")
    return o

def smooth(o):
    for p in o.data.polygons:
        p.use_smooth = True
    return o

def bx(m, c, s, b=0.02, rot=(0, 0, 0), seg=1):
    """A box with chamfered edges. c = centre, s = full size."""
    o = box(m, c, s, rot=rot)
    return bev(o, min(b, min(s) * 0.3), seg)

def tb(m, a, b, r, verts=12, r2=None, sm=True):
    """A round tube from point a to point b."""
    a = Vector(a); b = Vector(b); d = b - a
    o = cyl(m, (0, 0, 0), r, max(d.length, 1e-4), verts=verts, r2=r2)
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    for v in o.data.vertices:
        v.co = q @ v.co + (a + b) / 2
    return smooth(o) if sm else o

def beam(m, a, b, w, t, bv=0.0):
    """A square beam from a to b (w across, t thick)."""
    a = Vector(a); b = Vector(b); d = b - a
    o = box(m, (0, 0, 0), (w, t, max(d.length, 1e-4)))
    q = d.normalized().to_track_quat('Z', 'Y')
    for v in o.data.vertices:
        v.co = q @ v.co + (a + b) / 2
    return bev(o, bv) if bv > 0 else o

def disc(m, c, r, h, axis='z', verts=16, r2=None, b=0.0):
    rot = {'x': (0, PI2, 0), 'y': (PI2, 0, 0), 'z': (0, 0, 0)}[axis]
    o = cyl(m, c, r, h, verts=verts, rot=rot, r2=r2)
    if b > 0:
        bev(o, b)
    return smooth(o)

def screw(m, c, r=0.01, axis='x', h=0.006):
    return disc(m, c, r, h, axis, verts=8)

def ball(m, c, r, scale=(1, 1, 1), seg=16, rings=10, rot=(0, 0, 0)):
    return smooth(sphere(m, c, r, seg=seg, rings=rings, scale=scale, rot=rot))

def torus(m, c, R, r, rot=(0, 0, 0), seg=16, mseg=6):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=seg, minor_segments=mseg)
    return smooth(_finish(bpy.context.active_object, m, c, rot, (1, 1, 1)))

def jitter(o, amt, seed):
    r = random.Random(seed)
    for v in o.data.vertices:
        v.co += Vector((r.uniform(-amt, amt), r.uniform(-amt, amt), r.uniform(-amt, amt)))
    return o

def plate(m, pts, z0, z1, b=0.0):
    """A flat extruded polygon (wings, fins): pts in XY, thickness z0..z1."""
    me = bpy.data.meshes.new("plate")
    o = bpy.data.objects.new("plate", me)
    bpy.context.scene.collection.objects.link(o)
    bm = bmesh.new()
    vb = [bm.verts.new((x, y, z0)) for x, y in pts]
    vt = [bm.verts.new((x, y, z1)) for x, y in pts]
    bm.faces.new(vb[::-1]); bm.faces.new(vt)
    n = len(pts)
    for i in range(n):
        bm.faces.new([vb[i], vb[(i + 1) % n], vt[(i + 1) % n], vt[i]])
    bm.normal_update()
    bm.to_mesh(me); bm.free()
    o.data.materials.append(m)
    return bev(o, b) if b > 0 else o

def plate_v(m, pts, x0, x1, b=0.0):
    """Like plate() but the polygon lies in YZ (side profiles: fins, fuselages); thickness along X."""
    o = plate(m, pts, x0, x1)
    for v in o.data.vertices:
        y, z, x = v.co.x, v.co.y, v.co.z
        v.co = Vector((x, y, z))
    _fix_normals(o)
    return bev(o, b) if b > 0 else o

def _fix_normals(o):
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(o.data); bm.free()

def loft(m, rings, verts=None, cap=True, sm=True):
    """A hull lofted through rings: rings = [(y, cx, cz, rx, rz)], an elliptic section at each y.
    (Fuselages, bodies, bonnets.) Optional 'verts' = number of points per ring."""
    n = verts or 16
    me = bpy.data.meshes.new("loft")
    o = bpy.data.objects.new("loft", me)
    bpy.context.scene.collection.objects.link(o)
    bm = bmesh.new()
    vr = []
    for (y, cx, cz, rx, rz) in rings:
        row = []
        for i in range(n):
            a = TAU * i / n
            row.append(bm.verts.new((cx + math.cos(a) * rx, y, cz + math.sin(a) * rz)))
        vr.append(row)
    for k in range(len(vr) - 1):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new([vr[k][i], vr[k][j], vr[k + 1][j], vr[k + 1][i]])
    if cap:
        bm.faces.new(vr[0][::-1]); bm.faces.new(vr[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me); bm.free()
    o.data.materials.append(m)
    return smooth(o) if sm else o

def lathe(m, prof, verts=32, cx=0.0, cy=0.0, sm=True, sx=1.0, sy=1.0):
    """A surface of revolution round Z: prof = [(r, z), ...] from the bottom centre to the top.
    sx / sy stretch it into an oval."""
    me = bpy.data.meshes.new("lathe")
    o = bpy.data.objects.new("lathe", me)
    bpy.context.scene.collection.objects.link(o)
    bm = bmesh.new()
    rows = []
    for (r, z) in prof:
        if r < 1e-5:
            rows.append([bm.verts.new((cx, cy, z))])
        else:
            rows.append([bm.verts.new((cx + math.cos(TAU * i / verts) * r * sx, cy + math.sin(TAU * i / verts) * r * sy, z)) for i in range(verts)])
    for k in range(len(rows) - 1):
        a, b = rows[k], rows[k + 1]
        for i in range(verts):
            j = (i + 1) % verts
            if len(a) == 1 and len(b) == 1:
                continue
            if len(a) == 1:
                bm.faces.new([a[0], b[j], b[i]])
            elif len(b) == 1:
                bm.faces.new([a[i], a[j], b[0]])
            else:
                bm.faces.new([a[i], a[j], b[j], b[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me); bm.free()
    o.data.materials.append(m)
    return smooth(o) if sm else o

def box_loft(m, rings, cap=True, b=0.0):
    """A boxy hull lofted through rectangular sections: rings = [(y, cx, cz, w, h)] (full sizes)."""
    me = bpy.data.meshes.new("bloft")
    o = bpy.data.objects.new("bloft", me)
    bpy.context.scene.collection.objects.link(o)
    bm = bmesh.new()
    vr = []
    for (y, cx, cz, w, h) in rings:
        vr.append([bm.verts.new((cx + sx * w / 2, y, cz + sz * h / 2)) for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
    for k in range(len(vr) - 1):
        for i in range(4):
            j = (i + 1) % 4
            bm.faces.new([vr[k][i], vr[k][j], vr[k + 1][j], vr[k + 1][i]])
    if cap:
        bm.faces.new(vr[0][::-1]); bm.faces.new(vr[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me); bm.free()
    o.data.materials.append(m)
    return bev(o, b) if b > 0 else o

def colbox(name, loc, size, rot=(0, 0, 0)):
    o = box(mat("Col", (1, 0, 1)), loc, size, rot=rot)
    o.name = name + "-colonly"
    return o

def origin_at(o, p):
    """Move the object's origin to p without moving the mesh."""
    p = Vector(p)
    for v in o.data.vertices:
        v.co -= p
    o.location = p

def gallery(out, files, cols=4, spacing=12.0, dist=None, height=None, target_z=1.0, res=(1600, 1000), angle=0.0,
            rot=0.0, hide_col=True, grid=None):
    """Imports the exported glbs side by side and renders one Cycles preview of them all."""
    reset()
    for i, f in enumerate(files):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=f)
        g = grid[i] if grid else ((i % cols) * spacing - (cols - 1) * spacing / 2, -(i // cols) * spacing)
        for o in set(bpy.data.objects) - before:
            if hide_col and ("colonly" in o.name or any(ms.material and ms.material.name.startswith("Col") for ms in getattr(o, "material_slots", []))):
                o.hide_render = True
            if o.parent is None:
                o.rotation_mode = 'XYZ'
                o.rotation_euler = (0, 0, rot)
                o.location = (g[0], g[1], 0)
    rows = (len(files) + cols - 1) // cols
    d = dist or spacing * (cols + 0.8)
    preview(out, target=(0, -(rows - 1) * spacing / 2, target_z), dist=d, angle=angle,
            height=height if height is not None else d * 0.45, res=res)

sel = _sel   # (public name: "from kit import *" skips underscored names)

def apply_xf(o):
    """Bake the object's location / rotation / scale into its mesh."""
    _sel(o)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return o

def gun_gallery(out, files, cols=3, dx=1.5, dz=0.45, res_w=1280):
    """Hand-held things side on (muzzle to the right), as guns.py shows the arsenal."""
    reset()
    for i, f in enumerate(files):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=f)
        for o in set(bpy.data.objects) - before:
            if o.parent is None:
                o.rotation_mode = 'XYZ'
                o.location = ((i % cols) * dx - (cols - 1) * dx / 2, 0, -(i // cols) * dz)
                o.rotation_euler = (0, 0, -PI2)
    rows = (len(files) + cols - 1) // cols
    preview(out, target=(0.0, 0, -(rows - 1) * dz / 2), dist=(0.8 + cols * dx / 2) * 1.25, angle=0.0, height=0.0,
            res=(res_w, 260 + rows * 200))

# ---- 0.72: the nature in the look of the newer models -----------------------------------------------
# Smooth, lumpy crowns built from noise (mathutils.noise, seeded by an offset), darker undersides,
# trunks with root flares and bark ridges, chiselled stones with moss on the top faces only.
from mathutils import noise as _nz

def _shade(o, ang=40.0):
    """Smooth shading, edges sharper than ang stay hard (stones, crystals)."""
    _sel(o)
    for p in o.data.polygons:
        p.use_smooth = True
    try:
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(ang))
    except Exception:
        pass
    return o

def _two_tone(o, top, under, limit=-0.25):
    """Faces looking down get the darker material (the shade under a crown)."""
    o.data.materials.clear()
    o.data.materials.append(top)
    o.data.materials.append(under)
    for p in o.data.polygons:
        p.material_index = 1 if p.normal.z < limit else 0
    return o

def lump(m, c, r, scale=(1, 1, 1), seed=0, amt=0.22, sub=3, freq=1.6, bumps=0.11, under=None):
    """A soft, cloud-like clump of leaves: an icosphere pushed out by low noise, small leafy bumps."""
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=1.0)
    o = bpy.context.active_object
    off = Vector((seed * 7.31, seed * 3.17, seed * 5.53))
    for v in o.data.vertices:
        d = v.co.normalized()
        k = 1.0 + amt * _nz.noise(d * freq + off) + bumps * _nz.noise(d * 5.5 + off * 1.7)
        v.co = Vector((d.x * scale[0], d.y * scale[1], d.z * scale[2])) * r * k
        if v.co.z < -r * scale[2] * 0.55:       # flatter underneath, like a real crown
            v.co.z = -r * scale[2] * 0.55 + (v.co.z + r * scale[2] * 0.55) * 0.35
    o = _finish(o, m, c, (0, 0, 0), (1, 1, 1))
    smooth(o)
    if under is not None:
        _two_tone(o, m, under)
    return o

def bark_tube(m, pts, radii, verts=10, seed=0, ridge=0.08, flare=0.0):
    """A tube through pts with the given radii: bark ridges along it, roots flaring at the foot."""
    me = bpy.data.meshes.new("bark")
    bm = bmesh.new()
    rows = []
    pts = [Vector(p) for p in pts]
    off = Vector((seed * 1.7, seed * 2.9, 0.0))
    for i, (p, r) in enumerate(zip(pts, radii)):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        q = Vector((0, 0, 1)).rotation_difference(d)
        row = []
        for k in range(verts):
            a = k / verts * TAU
            rr = r * (1.0 + ridge * _nz.noise(Vector((math.cos(a) * 2.0, math.sin(a) * 2.0, p.z * 1.5)) + off))
            if flare > 0 and i == 0:
                rr *= 1.0 + flare * (0.6 + 0.4 * math.cos(a * 3 + seed))     # root buttresses
            elif flare > 0 and i == 1:
                rr *= 1.0 + flare * 0.25 * (0.6 + 0.4 * math.cos(a * 3 + seed))
            row.append(bm.verts.new(p + q @ Vector((math.cos(a) * rr, math.sin(a) * rr, 0))))
        rows.append(row)
    for i in range(len(rows) - 1):
        for k in range(verts):
            bm.faces.new((rows[i][k], rows[i][(k + 1) % verts], rows[i + 1][(k + 1) % verts], rows[i + 1][k]))
    bm.faces.new(list(reversed(rows[0])))
    bm.faces.new(rows[-1])
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("bark", me)
    bpy.context.collection.objects.link(o)
    _fix_normals(o)
    o = _finish(o, m, (0, 0, 0), (0, 0, 0), (1, 1, 1))
    return smooth(o)

def _path(a, b, n, seed, bend):
    rr = random.Random(seed)
    a = Vector(a); b = Vector(b)
    side = Vector((rr.uniform(-1, 1), rr.uniform(-1, 1), 0))
    out = []
    for i in range(n + 1):
        t = i / n
        p = a.lerp(b, t) + side * bend * math.sin(t * math.pi) + Vector((rr.uniform(-1, 1), rr.uniform(-1, 1), 0)) * bend * 0.25 * t
        out.append(p)
    return out

def branch(m, a, b, r0, r1, seed=0, verts=7, n=4, bend=0.15):
    pts = _path(a, b, n, seed, bend)
    return bark_tube(m, pts, [r0 + (r1 - r0) * i / n for i in range(n + 1)], verts, seed, 0.05)

def stone(m, r, scale, seed, cuts=9, sub=3, moss=None, dark=None):
    """A chiselled boulder: a rounded lump cut by random planes into facets, soft between them,
    sunk into the ground. Moss on the faces that look up, darker in the clefts underneath."""
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=1.0)
    o = bpy.context.active_object
    rr = random.Random(seed)
    off = Vector((seed * 2.3, seed * 1.1, seed * 3.7))
    for v in o.data.vertices:
        d = v.co.normalized()
        v.co = d * (1.0 + 0.16 * _nz.noise(d * 1.3 + off) + 0.03 * _nz.noise(d * 6.0 + off))
    planes = []
    for k in range(cuts):
        n = Vector((rr.uniform(-1, 1), rr.uniform(-1, 1), rr.uniform(-0.5, 1))).normalized()
        planes.append((n, rr.uniform(0.6, 0.82)))
    for v in o.data.vertices:
        for n, dist in planes:
            e = v.co.dot(n) - dist
            if e > 0:
                v.co -= n * e
    for v in o.data.vertices:
        v.co = Vector((v.co.x * scale[0], v.co.y * scale[1], v.co.z * scale[2])) * r
        v.co.z += r * scale[2] * 0.45
        if v.co.z < -0.12:
            v.co.z = -0.12
    o = _finish(o, m, (0, 0, 0), (0, 0, 0), (1, 1, 1))
    _shade(o, 38.0)
    mats_ = [m] + ([moss] if moss else []) + ([dark] if dark else [])
    o.data.materials.clear()
    for x in mats_:
        o.data.materials.append(x)
    top_h = max(v.co.z for v in o.data.vertices)
    for p in o.data.polygons:
        if moss and p.normal.z > 0.62 and p.center.z > top_h * 0.55 and _nz.noise(p.center * 1.7 + off) > -0.15:
            p.material_index = 1
        elif dark and p.normal.z < -0.1:
            p.material_index = len(mats_) - 1
    return o

