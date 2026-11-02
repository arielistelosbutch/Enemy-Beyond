"""Shared helpers for Enemy Beyond model scripts (Blender 4.x/5.x, run with python -c / bpy module).
Blender is Z-up and models face +Y; the glTF exporter turns that into Godot's
Y-up with the model facing -Z (Godot forward)."""
import bpy, bmesh, math
from mathutils import Vector, Matrix, Euler

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = bpy.context.scene
    s.render.fps = 24

def mat(name, rgb, emit=0.0, rough=0.9):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Roughness"].default_value = rough
    if emit > 0:
        b.inputs["Emission Color"].default_value = (*rgb, 1)
        b.inputs["Emission Strength"].default_value = emit
    return m

def _finish(obj, material, loc, rot, scale, group=None):
    obj.location = loc
    obj.rotation_euler = Euler(rot)
    obj.scale = scale
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.data.materials.clear()
    obj.data.materials.append(material)
    if group:
        vg = obj.vertex_groups.new(name=group)
        vg.add([v.index for v in obj.data.vertices], 1.0, 'REPLACE')
    for p in obj.data.polygons:
        p.use_smooth = False
    return obj

def box(material, loc, size, rot=(0, 0, 0), group=None):
    bpy.ops.mesh.primitive_cube_add(size=1)
    o = bpy.context.active_object
    return _finish(o, material, loc, rot, size, group)

def cyl(material, loc, r, h, verts=8, rot=(0, 0, 0), r2=None, group=None):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r if r2 is None else r2, depth=h)
    o = bpy.context.active_object
    return _finish(o, material, loc, rot, (1, 1, 1), group)

def sphere(material, loc, r, seg=8, rings=6, scale=(1, 1, 1), rot=(0, 0, 0), group=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=r)
    o = bpy.context.active_object
    return _finish(o, material, loc, rot, scale, group)

def join(objs, name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = name
    o.data.name = name
    return o

def export_glb(path, objs=None, animations=False):
    bpy.ops.object.select_all(action='DESELECT')
    for o in (objs or bpy.context.scene.objects):
        o.select_set(True)
    kw = dict(filepath=path, export_format='GLB', use_selection=True, export_yup=True,
              export_apply=True, export_animations=animations)
    if animations:
        kw.update(export_animation_mode='ACTIONS', export_force_sampling=True, export_frame_step=2)
    bpy.ops.export_scene.gltf(**kw)

def preview(path, target=(0, 0, 0.7), dist=3.0, angle=0.6, height=0.4, res=(480, 480)):
    """Quick Cycles CPU render for checking the shape."""
    s = bpy.context.scene
    cam_data = bpy.data.cameras.new("PrevCam")
    cam = bpy.data.objects.new("PrevCam", cam_data)
    s.collection.objects.link(cam)
    t = Vector(target)
    cam.location = t + Vector((math.sin(angle) * dist, math.cos(angle) * dist, height + 0.3))
    d = t - cam.location
    cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    s.camera = cam
    for i, (e, l) in enumerate([(3.0, (2, 3, 3)), (1.2, (-3, -1, 2))]):
        ld = bpy.data.lights.new("PrevSun%d" % i, 'SUN')
        ld.energy = e
        lo = bpy.data.objects.new("PrevSun%d" % i, ld)
        s.collection.objects.link(lo)
        lo.rotation_euler = (Vector(l)).to_track_quat('Z', 'Y').to_euler()
    w = bpy.data.worlds.new("PrevWorld")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.08, 0.09, 0.12, 1)
    s.world = w
    s.render.engine = 'CYCLES'
    s.cycles.samples = 16
    s.cycles.device = 'CPU'
    s.render.resolution_x, s.render.resolution_y = res
    s.render.filepath = path
    bpy.ops.render.render(write_still=True)
    for n in ["PrevCam", "PrevSun0", "PrevSun1"]:
        bpy.data.objects.remove(bpy.data.objects[n])
