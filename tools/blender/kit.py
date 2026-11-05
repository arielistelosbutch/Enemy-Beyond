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
