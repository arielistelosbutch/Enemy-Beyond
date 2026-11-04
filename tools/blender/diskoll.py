"""Diskoll (0.50) after Ari's picture: an armoured scout saucer of grey worn plates, a raised dome with
one red targeting eye in front, a cyan light ring round the dome and cyan lamps along the rim, a
radio mast with a red tip, vents, the red rune on the front plate, and two heavy plasma blasters
slung under the front with green muzzles. Pieces the game moves: Hull, Ring (the rim lamps spin),
Guns. Run: python3 tools/blender/diskoll.py out.glb [--preview - 0 out.png angle dist z height]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from common import *
from common import _finish

OUT = [a for a in sys.argv if a.endswith(".glb")]
OUT = OUT[0] if OUT else "diskoll.glb"
reset()

def mat2(name, rgb, rough=0.6, metal=0.0, emit=0.0):
    m = mat(name, rgb, emit=emit, rough=rough)
    m.node_tree.nodes.get("Principled BSDF").inputs["Metallic"].default_value = metal
    return m

hull = mat2("DisHull", (0.3, 0.31, 0.32), rough=0.5, metal=0.6)
hull2 = mat2("DisHull2", (0.2, 0.21, 0.22), rough=0.45, metal=0.7)
dark = mat2("DisDark", (0.05, 0.05, 0.055), rough=0.5, metal=0.5)
cyan = mat("DisLight", (0.35, 0.95, 1.0), emit=3.5)
red = mat("TroLens", (1.0, 0.12, 0.06), emit=5.0)
rune = mat("DisRune", (0.45, 0.04, 0.04), emit=0.6)
green = mat("PlasmaGlow", (0.35, 1.0, 0.45), emit=4.0)
thr = mat("DisThrust", (0.5, 0.8, 1.0), emit=2.0)

def flat(o):
    for p in o.data.polygons:
        p.use_smooth = False
    return o

def smooth(o):
    for p in o.data.polygons:
        p.use_smooth = True
    return o

def bevel(o, w=0.01, seg=1):
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    m = o.modifiers.new("Bevel", 'BEVEL')
    m.width = w
    m.segments = seg
    bpy.ops.object.modifier_apply(modifier="Bevel")
    return o

def torus(material, loc, R, r, scale=(1, 1, 1), rot=(0, 0, 0), seg=32):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=seg, minor_segments=6)
    return smooth(_finish(bpy.context.active_object, material, loc, rot, scale))

def limb(material, a, b, r1, r2, verts=8):
    a = Vector(a); b = Vector(b)
    d = b - a
    o = cyl(material, (0, 0, 0), r1, d.length, verts=verts, r2=r2)
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    for v in o.data.vertices:
        v.co = q @ v.co + (a + b) / 2
    return o

H = []
# the saucer: two faceted cones (the plates), a lip between them
H.append(flat(cyl(hull, (0, 0, 0.03), 0.7, 0.12, verts=12, r2=0.5)))
H.append(flat(cyl(hull2, (0, 0, -0.07), 0.52, 0.08, verts=12, r2=0.7)))
H.append(flat(cyl(dark, (0, 0, -0.02), 0.715, 0.03, verts=12)))
for i in range(6):                                                     # raised armour plates on the deck
    a = i / 6 * math.tau + 0.52
    H.append(bevel(box(hull2, (math.sin(a) * 0.58, math.cos(a) * 0.58, 0.05), (0.2, 0.14, 0.02), rot=(-0.5, 0, -a)), 0.008))
# the dome: faceted, dark, with the cyan ring at its foot and the red eye in front
H.append(flat(cyl(hull2, (0, -0.03, 0.15), 0.34, 0.12, verts=8, r2=0.26)))
H.append(flat(cyl(hull, (0, -0.03, 0.25), 0.26, 0.08, verts=8, r2=0.12)))
H.append(torus(cyan, (0, -0.03, 0.095), 0.37, 0.012))
H.append(bevel(box(dark, (0, 0.24, 0.17), (0.22, 0.08, 0.1)), 0.02, 2))     # the eye socket
H.append(smooth(sphere(red, (0, 0.27, 0.17), 0.038, seg=12, rings=8, scale=(1, 0.5, 1))))
H.append(torus(red, (0, 0.285, 0.17), 0.065, 0.006, rot=(math.pi / 2, 0, 0)))
for x in (1, -1):
    H.append(box(red, (0.11 * x, 0.285, 0.17), (0.04, 0.004, 0.004)))      # reticle arms
H.append(box(red, (0, 0.285, 0.23), (0.004, 0.004, 0.035)))
# the mast with its red tip, vents, the rune
H.append(bevel(box(hull2, (0.26, -0.12, 0.17), (0.12, 0.14, 0.1), rot=(0, 0, 0.5)), 0.015))
H.append(limb(dark, (0.27, -0.13, 0.2), (0.27, -0.13, 0.62), 0.016, 0.011))
H.append(limb(red, (0.27, -0.13, 0.62), (0.27, -0.13, 0.7), 0.012, 0.012))
for x in (1, -1):
    H.append(box(dark, (0.3 * x, 0.22, 0.09), (0.12, 0.03, 0.025), rot=(0, 0, -0.6 * x)))
    for k in range(3):
        H.append(box(red if x < 0 else dark, (0.3 * x - 0.03 * x + k * 0.03 * x, 0.235, 0.105), (0.008, 0.005, 0.02), rot=(0, 0, -0.6 * x)))
for x in (1, -1):                                                      # the red rune on the front plate
    H.append(box(rune, (0.025 * x, 0.52, 0.062), (0.016, 0.1, 0.006), rot=(-0.5, 0, 0.45 * x)))
# the underside: a dark ring of mesh and the thruster glow
H.append(flat(cyl(dark, (0, 0, -0.115), 0.3, 0.02, verts=12)))
H.append(smooth(cyl(thr, (0, 0, -0.13), 0.22, 0.015, verts=16)))
hullo = join(H, "Hull")

# the rim lamps (they spin in the game)
R = []
for i in range(10):
    a = i / 10 * math.tau
    R.append(box(cyan, (math.sin(a) * 0.69, math.cos(a) * 0.69, 0.0), (0.09, 0.04, 0.035), rot=(0, 0, -a)))
ringo = join(R, "Ring")
bpy.context.scene.cursor.location = (0, 0, 0)
bpy.ops.object.select_all(action='DESELECT')
ringo.select_set(True)
bpy.context.view_layer.objects.active = ringo
bpy.ops.object.origin_set(type='ORIGIN_CURSOR')

# the blasters: heavy pods slung under the front
G = []
for x in (1, -1):
    G.append(bevel(box(hull2, (0.3 * x, 0.42, -0.12), (0.13, 0.36, 0.12)), 0.02, 2))
    G.append(limb(dark, (0.3 * x, 0.58, -0.125), (0.3 * x, 0.92, -0.125), 0.055, 0.05, verts=10))
    G.append(limb(dark, (0.3 * x, 0.9, -0.125), (0.3 * x, 0.97, -0.125), 0.062, 0.062, verts=10))
    G.append(smooth(sphere(green, (0.3 * x, 0.97, -0.125), 0.04, seg=10, rings=6, scale=(1, 0.4, 1))))
    for k in range(4):
        G.append(box(green, (0.3 * x + 0.066 * x, 0.36 + k * 0.045, -0.12), (0.006, 0.025, 0.035)))
guno = join(G, "Guns")

if "--preview" in sys.argv:
    i = sys.argv.index("--preview")
    preview(sys.argv[i + 3], target=(0, 0.1, float(sys.argv[i + 6]) if len(sys.argv) > i + 6 else 0.0),
            dist=float(sys.argv[i + 5]) if len(sys.argv) > i + 5 else 2.8, angle=float(sys.argv[i + 4]),
            height=float(sys.argv[i + 7]) if len(sys.argv) > i + 7 else 0.2, res=(640, 420))
else:
    export_glb(OUT, [hullo, ringo, guno])
    print("written", OUT)
