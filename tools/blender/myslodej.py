"""Mysloděj (0.50) after Ari's picture: a floating figure in a long, torn violet robe and a deep hood. Inside
the hood no face - only darkness cracked with violet light and one vertical glowing eye. A clasp at the
collar and a gold-traced band with a ring sigil down the front; short black clawed hands; the hem in long
ragged points glowing at the tips. A heavy energy pistol floats beside it.
Pieces as before: Robe (sways), Weapon (orbits, turns to the target).
Run: python3 tools/blender/myslodej.py out.glb [--preview - 0 out.png angle]"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
from common import *
from common import _finish

OUT = [a for a in sys.argv if a.endswith(".glb")]
OUT = OUT[0] if OUT else "myslodej.glb"
reset()

def mat2(name, rgb, rough=0.6, metal=0.0, emit=0.0):
    m = mat(name, rgb, emit=emit, rough=rough)
    m.node_tree.nodes.get("Principled BSDF").inputs["Metallic"].default_value = metal
    return m

robe = mat2("MysRobe", (0.22, 0.06, 0.3), rough=0.85)
robe2 = mat2("MysRobe2", (0.13, 0.03, 0.19), rough=0.85)
void = mat2("MysVoid", (0.01, 0.0, 0.015), rough=1.0)
crack = mat("MysCrack", (0.75, 0.25, 1.0), emit=3.0)
eye = mat("MysEye", (1.0, 0.75, 1.0), emit=8.0)
gold = mat2("MysTrim", (0.6, 0.45, 0.2), rough=0.35, metal=0.8)
claw = mat2("MysHand", (0.02, 0.02, 0.025), rough=0.4)
glow = mat("MysGlow", (0.8, 0.3, 1.0), emit=4.0)
gunm = mat2("MysGun", (0.12, 0.11, 0.14), rough=0.35, metal=0.6)

def smooth(o):
    for p in o.data.polygons:
        p.use_smooth = True
    return o

def L(material, a, b, r1, r2, verts=8, sm=True):
    a = Vector(a); b = Vector(b)
    d = b - a
    o = cyl(material, (0, 0, 0), r1, max(d.length, 0.001), verts=verts, r2=r2)
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    for v in o.data.vertices:
        v.co = q @ v.co + (a + b) / 2
    return smooth(o) if sm else o

rr = random.Random(4)
R = []
# ---- the robe: a long cone of cloth, wider below, the hem torn into long points ---------------------------------
bpy.ops.mesh.primitive_cone_add(vertices=32, radius1=0.5, radius2=0.2, depth=1.25, end_fill_type='NOTHING')
body = _finish(bpy.context.active_object, robe, (0, 0, 0.8), (0, 0, 0), (1, 0.85, 1))
bpy.ops.object.select_all(action='DESELECT'); body.select_set(True); bpy.context.view_layer.objects.active = body
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.subdivide(number_cuts=4); bpy.ops.object.mode_set(mode='OBJECT')
for v in body.data.vertices:                                             # folds in the cloth
    a = math.atan2(v.co.x, v.co.y)
    k = 1.0 + 0.06 * math.sin(a * 9) * (1.4 - v.co.z)
    v.co.x *= k; v.co.y *= k
m = body.modifiers.new("Solid", 'SOLIDIFY'); m.thickness = 0.02
bpy.ops.object.modifier_apply(modifier="Solid")
R.append(smooth(body))
for i in range(22):                                                      # the torn points, glowing at the tips
    a = i / 22 * math.tau + rr.uniform(-0.05, 0.05)
    ln = rr.uniform(0.25, 0.55)
    top = Vector((math.sin(a) * 0.49, math.cos(a) * 0.42, 0.2))
    tip = Vector((math.sin(a) * (0.52 + ln * 0.15), math.cos(a) * (0.45 + ln * 0.12), 0.2 - ln))
    o = L(robe if i % 2 else robe2, tuple(top), tuple(tip), 0.075, 0.0, 4, sm=False)
    R.append(o)
    R.append(L(crack, tuple(tip + (top - tip) * 0.18), tuple(tip), 0.016, 0.0, 4, sm=False))
# shoulders and the wide sleeves reaching forward, short black clawed hands
R.append(smooth(sphere(robe, (0, 0, 1.38), 0.26, seg=16, rings=10, scale=(1.25, 0.9, 0.55))))
for x in (1, -1):
    R.append(L(robe, (0.22 * x, 0.0, 1.36), (0.36 * x, 0.18, 1.05), 0.1, 0.13, 10))
    R.append(L(robe2, (0.36 * x, 0.18, 1.05), (0.4 * x, 0.22, 0.98), 0.13, 0.14, 10))      # the cuff, wide open
    R.append(smooth(sphere(claw, (0.4 * x, 0.25, 0.97), 0.035, seg=8, rings=6)))
    for f in range(4):
        R.append(L(claw, (0.4 * x + (f - 1.5) * 0.018, 0.27, 0.96), (0.42 * x + (f - 1.5) * 0.03, 0.34, 0.9), 0.008, 0.0, 5))
    for k in range(3):                                                    # ragged sleeve ends
        R.append(L(robe2, (0.36 * x + (k - 1) * 0.05, 0.2, 0.97), (0.38 * x + (k - 1) * 0.07, 0.24, 0.84), 0.03, 0.0, 4, sm=False))
# the collar clasp and the gold-traced band with the ring sigil
R.append(smooth(sphere(robe2, (0, 0.12, 1.32), 0.13, seg=12, rings=8, scale=(1.3, 0.6, 0.5))))
R.append(box(gold, (0, 0.2, 1.32), (0.05, 0.02, 0.06), rot=(0, 0.785, 0)))
R.append(box(robe2, (0, 0.285, 0.9), (0.13, 0.02, 0.8), rot=(0.2, 0, 0)))
for x in (-0.035, 0.035):
    R.append(box(gold, (x, 0.3, 0.9), (0.008, 0.015, 0.76), rot=(0.2, 0, 0)))
bpy.ops.mesh.primitive_torus_add(major_radius=0.05, minor_radius=0.006, major_segments=20, minor_segments=4)
R.append(_finish(bpy.context.active_object, gold, (0, 0.315, 0.78), (math.pi / 2 - 0.2, 0, 0), (1, 1, 1)))
# the hood: deep, pointed, darkness inside, cracks of violet light and one vertical eye
R.append(smooth(sphere(robe, (0, -0.08, 1.62), 0.2, seg=16, rings=12, scale=(1.0, 1.05, 1.25))))
R.append(L(robe, (0, -0.12, 1.75), (0, -0.22, 1.92), 0.1, 0.0, 10))      # the point of the hood
bpy.ops.mesh.primitive_torus_add(major_radius=0.13, minor_radius=0.04, major_segments=24, minor_segments=8)
R.append(smooth(_finish(bpy.context.active_object, robe2, (0, 0.13, 1.6), (math.pi / 2, 0, 0), (1.0, 1.35, 1.0))))   # the rim
R.append(smooth(sphere(void, (0, 0.1, 1.6), 0.14, seg=14, rings=10, scale=(0.95, 0.5, 1.25))))   # darkness inside
R.append(smooth(sphere(eye, (0, 0.17, 1.62), 0.024, seg=10, rings=8, scale=(0.6, 0.4, 1.6))))
for k in range(8):                                                        # cracks of light in the dark
    a = k / 8 * math.tau
    p0 = Vector((math.sin(a) * 0.03, 0.165, 1.62 + math.cos(a) * 0.05))
    p1 = Vector((math.sin(a) * 0.085, 0.15, 1.62 + math.cos(a) * 0.12))
    R.append(L(crack, tuple(p0), tuple(p1), 0.004, 0.002, 4))
robeo = join(R, "Robe")

# ---- the floating weapon ------------------------------------------------------------------------------------------
W = [box(gunm, (0, 0.0, 0.0), (0.09, 0.42, 0.11)),
     box(gunm, (0, -0.08, -0.1), (0.07, 0.1, 0.14), rot=(0.3, 0, 0)),
     box(glow, (0.048, 0.02, 0.02), (0.008, 0.3, 0.025)),
     L(gunm, (0, 0.2, 0.0), (0, 0.28, 0.0), 0.04, 0.04, 10)]
W.append(smooth(sphere(glow, (0, 0.285, 0.0), 0.025, seg=8, rings=6, scale=(1, 0.4, 1))))
weapono = join(W, "Weapon")
bpy.context.scene.cursor.location = (0, 0, 0)
bpy.ops.object.select_all(action='DESELECT'); weapono.select_set(True)
bpy.context.view_layer.objects.active = weapono
bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
weapono.location = (0.55, 0.15, 1.05)

if "--preview" in sys.argv:
    i = sys.argv.index("--preview")
    preview(sys.argv[i + 3], target=(0, 0, 0.9), dist=3.2, angle=float(sys.argv[i + 4]), height=0.3, res=(480, 600))
else:
    export_glb(OUT, [robeo, weapono])
    print("written", OUT)
