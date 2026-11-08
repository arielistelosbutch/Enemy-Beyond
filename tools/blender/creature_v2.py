"""Helpers for the second-attempt creature models (0.57 pokus): organic bodies from a skin skeleton
(one continuous mesh, good for auto-rigging in afk.ai), chunky bevelled armour, and quick previews.
Same game look as the first models: plain colours, faceted plates, glowing seams, low poly.
Used by ohar_v2.py, bijec_v2.py, jestetan_v2.py."""
import bpy, bmesh, math, sys, os
from mathutils import Vector, Matrix, Euler
sys.path.insert(0, os.path.dirname(__file__))
from common import reset, mat, _finish, box, cyl, sphere, join


def mat2(name, rgb, rough=0.6, metal=0.0, emit=0.0):
    m = mat(name, rgb, emit=emit, rough=rough)
    m.node_tree.nodes.get("Principled BSDF").inputs["Metallic"].default_value = metal
    return m


def smooth(o):
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def _apply_mods(o):
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    for m in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)


def skin(material, nodes, edges, name="Body", subsurf=1, root=0):
    """nodes: list of (pos, radius) or (pos, (rx, ry)); edges: index pairs. One closed organic mesh."""
    me = bpy.data.meshes.new(name)
    me.from_pydata([n[0] for n in nodes], edges, [])
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.modifiers.new("Skin", 'SKIN')
    sv = me.skin_vertices[0].data
    for i, n in enumerate(nodes):
        r = n[1] if isinstance(n[1], (tuple, list)) else (n[1], n[1])
        sv[i].radius = r
        sv[i].use_root = (i == root)
    if subsurf:
        s = o.modifiers.new("Sub", 'SUBSURF')
        s.levels = subsurf
        s.render_levels = subsurf
    _apply_mods(o)
    o.data.materials.append(material)
    return smooth(o)


def bbox(material, loc, size, rot=(0, 0, 0), bevel=0.25, seg=1):
    """A box with chamfered edges - the faceted armour plate look."""
    o = box(material, loc, size, rot)
    m = o.modifiers.new("Bev", 'BEVEL')
    m.width = min(size) * bevel
    m.segments = seg
    m.limit_method = 'NONE'
    _apply_mods(o)
    return o


def limb(material, a, b, r1, r2, verts=8, sm=True):
    a = Vector(a); b = Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=max(d.length, 0.001))
    o = _finish(bpy.context.active_object, material, (a + b) / 2, d.to_track_quat('Z', 'Y').to_euler(), (1, 1, 1))
    return smooth(o) if sm else o


def spike(material, base, tip, r, verts=5):
    return limb(material, base, tip, r, 0.0, verts=verts, sm=False)


def band(material, a, b, t, R, r=0.012):
    a = Vector(a); b = Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=12, minor_segments=4)
    return _finish(bpy.context.active_object, material, a + d * t, d.to_track_quat('Z', 'Y').to_euler(), (1, 1, 1.6))


def tube(material, pts, r, verts=6):
    """A hose along a polyline (one mesh)."""
    out = []
    for i in range(len(pts) - 1):
        out.append(limb(material, pts[i], pts[i + 1], r, r, verts=verts))
        if i:
            out.append(smooth(sphere(material, pts[i], r, seg=verts, rings=4)))
    return out


def mirror_x(objs):
    """Duplicate objects mirrored across X (for the left/right side)."""
    out = []
    for o in objs:
        c = o.copy()
        c.data = o.data.copy()
        bpy.context.scene.collection.objects.link(c)
        for v in c.data.vertices:
            v.co.x = -v.co.x
        c.data.flip_normals()
        out.append(c)
    return out


def stats(o):
    tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    return {"verts": len(o.data.vertices), "tris": tris}


def finish_mesh(objs, name):
    o = join(objs, name)
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    return o


def export_all(o, base, extra=()):
    """base without extension: writes base.glb, base.fbx, base.obj (+ .mtl) like animace/Maximo/postavy."""
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    for e in extra:
        e.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.export_scene.gltf(filepath=base + ".glb", export_format='GLB', use_selection=True, export_yup=True,
                              export_apply=True, export_animations=False)
    bpy.ops.export_scene.fbx(filepath=base + ".fbx", use_selection=True, apply_scale_options='FBX_SCALE_ALL',
                             axis_forward='-Z', axis_up='Y', add_leaf_bones=False, bake_anim=False)
    bpy.ops.wm.obj_export(filepath=base + ".obj", export_selected_objects=True, export_materials=True,
                          forward_axis='NEGATIVE_Z', up_axis='Y')


def render(path, target, dist, angle, height=0.3, res=(560, 560), lens=50):
    s = bpy.context.scene
    cam = bpy.data.objects.get("PrevCam")
    if not cam:
        cam = bpy.data.objects.new("PrevCam", bpy.data.cameras.new("PrevCam"))
        s.collection.objects.link(cam)
        for i, (e, l) in enumerate([(3.2, (2, 3, 3)), (1.3, (-3, -1, 2)), (1.0, (0, -3, 1))]):
            ld = bpy.data.lights.new("PrevSun%d" % i, 'SUN')
            ld.energy = e
            lo = bpy.data.objects.new("PrevSun%d" % i, ld)
            s.collection.objects.link(lo)
            lo.rotation_euler = Vector(l).to_track_quat('Z', 'Y').to_euler()
        w = bpy.data.worlds.new("PrevWorld")
        w.use_nodes = True
        w.node_tree.nodes["Background"].inputs[0].default_value = (0.08, 0.09, 0.12, 1)
        s.world = w
        s.render.engine = 'CYCLES'
        s.cycles.samples = 16
        s.cycles.device = 'CPU'
    cam.data.lens = lens
    t = Vector(target)
    cam.location = t + Vector((math.sin(angle) * dist, math.cos(angle) * dist, height))
    cam.rotation_euler = (t - cam.location).to_track_quat('-Z', 'Y').to_euler()
    s.camera = cam
    s.render.resolution_x, s.render.resolution_y = res
    s.render.filepath = path
    bpy.ops.render.render(write_still=True)


def mouth(c, a, b, depth, flesh, dark, tooth, n_up=8, n_low=7, fangs_up=(1, -2), fangs_low=(2, -3),
          tooth_len=0.045, fang_len=0.08, lip=0.018, tilt=0.0, tooth_r=0.009):
    """An open mouth on a face looking +Y: a dark cavity behind an elliptic lip ring, teeth rooted on the
    rim pointing into the opening (so they always sit in the mouth). c = centre of the opening,
    a/b = half width/height of the opening, depth = how deep the cavity goes."""
    c = Vector(c)
    out = []
    cav = smooth(sphere(dark, c + Vector((0, -depth - 0.004, 0)), 1.0, seg=16, rings=10, scale=(a * 1.02, depth, b * 1.02)))
    out.append(cav)
    bpy.ops.mesh.primitive_torus_add(major_radius=1.0, minor_radius=lip / max(a, b), major_segments=24, minor_segments=6)
    t = bpy.context.active_object
    out.append(smooth(_finish(t, flesh, c + Vector((0, -lip * 0.3, 0)), (math.pi / 2, 0, 0), (a + lip * 0.5, b + lip * 0.5, a + lip * 0.5))))
    def row(n, upper, fangs):
        fi = {f % n for f in fangs}
        for i in range(n):
            ang = math.pi * (0.12 + 0.76 * (i + 0.5) / n)
            ex, ez = math.cos(ang), math.sin(ang) * (1 if upper else -1)
            base = c + Vector((a * ex * 0.97, -lip * 0.4, b * ez * 0.97))
            inward = (c + Vector((0, -lip * 0.4, 0)) - base)
            inward.z *= 1.0
            ln = fang_len if i in fi else tooth_len * (0.8 + 0.4 * math.sin(i * 2.3) ** 2)
            dirv = Vector((inward.x * 0.25, 0.0, inward.z)).normalized()
            out.append(spike(tooth, base, base + dirv * ln + Vector((0, 0.004, 0)), tooth_r * (1.35 if i in fi else 1.0), verts=6))
    row(n_up, True, fangs_up)
    row(n_low, False, fangs_low)
    if tilt:
        for o in out:
            for v in o.data.vertices:
                p = v.co - c
                v.co = c + Matrix.Rotation(tilt, 3, 'X') @ p
    return out


def closed_mouth(c, w, wrap, droop, flesh, dark, tooth, n=10, fangs=(1, -2), tooth_len=0.022, fang_len=0.045,
                 tooth_r=0.006, seam_r=0.006, lip=0.012):
    """A closed mouth on a face looking +Y: a dark seam across the face (wrapping back by `wrap`*x^2, corners
    pulled down by `droop`*x^2 for a grimace) with lips, and sharp interlocking teeth biting over the lips -
    upper ones down, lower ones up, fangs longer."""
    c = Vector(c)
    def at(x):
        return c + Vector((x, -wrap * x * x, -droop * x * x))
    out = []
    pts = [at(-w + 2 * w * i / 12) for i in range(13)]
    out += tube(dark, pts, seam_r, verts=6)
    for dz, r in ((lip * 0.9, lip), (-lip * 0.9, lip * 0.9)):                       # upper and lower lip
        out += tube(flesh, [p + Vector((0, -0.002, dz)) for p in pts[1:-1]], r, verts=6)
    fi = {f % n for f in fangs}
    for i in range(n):
        x = -w * 0.85 + 1.7 * w * (i + 0.5) / n
        p = at(x) + Vector((0, lip * 0.35, 0))
        up = (i % 2 == 0)
        ln = fang_len if i in fi else tooth_len
        s = 1 if up else -1                                                             # upper teeth hang down over the lower lip
        base = p + Vector((0, 0, s * lip * 0.2))
        out.append(spike(tooth, base, base + Vector((0, 0.004, -s * ln)), tooth_r * (1.4 if i in fi else 1.0), verts=6))
    return out
