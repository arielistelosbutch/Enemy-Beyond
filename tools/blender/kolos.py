"""Kolos (0.50) after Ari's picture: a huge armoured spider of a war machine - an angular carapace of dark
alien alloy with violet light in its seams and vents, a ridge of blade-like spikes, one red eye in the
front plate, two rotary plasma guns slung under the head, a long heavy plasma cannon on top, and eight long
armoured legs with violet-lit plates, high knees and pointed feet.
Pieces the game moves: Hull, Turret (the cannon turns to the target), Leg0..Leg7 (each turns at its hip).
Run: python3 tools/blender/kolos.py out.glb [--preview - 0 out.png angle dist]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from common import *
from common import _finish

OUT = [a for a in sys.argv if a.endswith(".glb")]
OUT = OUT[0] if OUT else "kolos.glb"
reset()

def mat2(name, rgb, rough=0.6, metal=0.0, emit=0.0):
    m = mat(name, rgb, emit=emit, rough=rough)
    m.node_tree.nodes.get("Principled BSDF").inputs["Metallic"].default_value = metal
    return m

hull = mat2("TroHull", (0.2, 0.17, 0.2), rough=0.35, metal=0.7)
hull2 = mat2("TroHull2", (0.12, 0.1, 0.13), rough=0.4, metal=0.7)
dark = mat2("TroDark", (0.05, 0.045, 0.055), rough=0.4, metal=0.5)
glow = mat("KolGlow", (0.85, 0.25, 1.0), emit=4.0)
lens = mat("TroLens", (1.0, 0.12, 0.06), emit=6.0)

def smooth(o):
    for p in o.data.polygons:
        p.use_smooth = True
    return o

def chamf(o, w=0.03):
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    m = o.modifiers.new("Bevel", 'BEVEL')
    m.width = w
    m.segments = 1
    bpy.ops.object.modifier_apply(modifier="Bevel")
    return o

def L(material, a, b, r1, r2, verts=10, sm=True):
    a = Vector(a); b = Vector(b)
    d = b - a
    o = cyl(material, (0, 0, 0), r1, max(d.length, 0.001), verts=verts, r2=r2)
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    for v in o.data.vertices:
        v.co = q @ v.co + (a + b) / 2
    return smooth(o) if sm else o

def slab(material, a, b, w, d, taper=1.0, up=Vector((0, 0, 1))):
    """An armour plate along a segment a->b, w wide and d deep, narrowing to taper at b."""
    a = Vector(a); b = Vector(b)
    o = box(material, (0, 0, 0), (w, d, (b - a).length))
    for v in o.data.vertices:
        if v.co.z > 0:
            v.co.x *= taper; v.co.y *= taper
    q = Vector((0, 0, 1)).rotation_difference((b - a).normalized())
    for v in o.data.vertices:
        v.co = q @ v.co + (a + b) / 2
    return chamf(o, 0.02)

def spike(a, b, r):
    o = L(hull, a, b, r, 0.0, 4, sm=False)
    return o

H = 2.0
# ---- the hull: an angular carapace, the head plate with the red eye, the guns underneath ----------------------------
h = []
c = box(hull, (0, 0.0, H), (1.5, 1.9, 0.7))
for v in c.data.vertices:                                       # a wedge: narrow and low at the back, high at the front
    if v.co.y < 0:
        v.co.x *= 0.75; v.co.z = H + (v.co.z - H) * 0.7
    if v.co.z > H:
        v.co.x *= 0.7
h.append(chamf(c, 0.12))
h.append(chamf(box(hull2, (0, -0.95, H - 0.05), (1.0, 0.7, 0.5)), 0.1))                  # the abdomen
head = box(hull, (0, 1.05, H - 0.05), (1.0, 0.5, 0.65))
for v in head.data.vertices:
    if v.co.y > 1.1:
        v.co.x *= 0.6; v.co.z = H - 0.05 + (v.co.z - (H - 0.05)) * 0.7
h.append(chamf(head, 0.08))
h.append(smooth(sphere(dark, (0, 1.3, H + 0.02), 0.13, seg=14, rings=10)))
h.append(smooth(sphere(lens, (0, 1.38, H + 0.02), 0.09, seg=14, rings=10)))
bpy.ops.mesh.primitive_torus_add(major_radius=0.14, minor_radius=0.025, major_segments=20, minor_segments=6)
h.append(smooth(_finish(bpy.context.active_object, hull2, (0, 1.36, H + 0.02), (math.pi / 2, 0, 0), (1, 1, 1))))
for x in (1, -1):                                               # brow plates sweeping back from the eye
    h.append(chamf(box(hull2, (0.2 * x, 1.18, H + 0.25), (0.35, 0.5, 0.08), rot=(0.25, 0, -0.35 * x)), 0.03))
    for k in range(4):                                          # violet vents along the flanks
        h.append(box(glow, (0.62 * x, 0.35 - k * 0.28, H + 0.08), (0.02, 0.16, 0.05)))
    for k in range(3):
        h.append(box(glow, (0.38 * x, -0.95 - k * 0.1, H + 0.18), (0.12, 0.03, 0.02)))
for k in range(6):                                              # the ridge of blade spikes
    y = 0.75 - k * 0.32
    hgt = 0.45 - abs(k - 2) * 0.06
    for x in ((-0.25, 0.25) if k % 2 == 0 else (0.0,)):
        sp = spike((x, y, H + 0.32), (x * 1.3, y - 0.25, H + 0.32 + hgt), 0.09)
        for v in sp.data.vertices:
            v.co.x = x + (v.co.x - x) * 0.4
        h.append(sp)
# under the head: the two rotary plasma guns (the game fires them from (±0.3, 1.72, front 1.1))
for x in (1, -1):
    h.append(L(dark, (0.3 * x, 0.6, 1.72), (0.3 * x, 0.85, 1.72), 0.13, 0.13, 12))
    h.append(L(hull2, (0.3 * x, 0.85, 1.72), (0.3 * x, 0.92, 1.72), 0.15, 0.15, 12))
    for k in range(6):
        a = k / 6 * math.tau
        bx, bz = 0.3 * x + math.sin(a) * 0.065, 1.72 + math.cos(a) * 0.065
        h.append(L(dark, (bx, 0.9, bz), (bx, 1.18, bz), 0.025, 0.025, 6))
        h.append(smooth(sphere(glow, (bx, 1.18, bz), 0.02, seg=6, rings=4)))
    h.append(L(hull2, (0.3 * x, 1.1, 1.72), (0.3 * x, 1.13, 1.72), 0.11, 0.11, 12))
    h.append(L(dark, (0.3 * x, 0.6, 1.8), (0.2 * x, 0.55, H - 0.25), 0.05, 0.05, 8))    # mount
# hoses with violet light underneath
for x in (1, -1):
    for k in range(3):
        a = Vector((0.4 * x, 0.4 - k * 0.4, H - 0.33))
        b = Vector((0.15 * x, 0.2 - k * 0.4, H - 0.45))
        h.append(L(glow if k == 1 else dark, tuple(a), tuple(b), 0.035, 0.035, 8))
hullo = join(h, "Hull")
bpy.context.scene.cursor.location = (0, 0, H)
bpy.ops.object.select_all(action='DESELECT'); hullo.select_set(True)
bpy.context.view_layer.objects.active = hullo
bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
hullo.scale = (1.3, 1.3, 1.3)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

# ---- the turret: the heavy cannon on top ---------------------------------------------------------------------------
t = [smooth(cyl(hull2, (0, 0.1, H + 0.42), 0.38, 0.22, verts=16)),
     chamf(box(hull, (0, 0.2, H + 0.6), (0.5, 0.8, 0.3)), 0.06),
     L(dark, (0, 0.5, H + 0.62), (0, 2.4, H + 0.82), 0.12, 0.1, 16),
     L(hull, (0, 0.5, H + 0.62), (0, 1.3, H + 0.7), 0.16, 0.15, 16)]
for k in range(4):                                              # glowing coil rings along the barrel
    p0 = Vector((0, 1.4 + k * 0.22, H + 0.71 + k * 0.023))
    t.append(L(glow, tuple(p0), tuple(p0 + Vector((0, 0.06, 0.006))), 0.13, 0.13, 16))
t.append(L(hull2, (0, 2.3, H + 0.81), (0, 2.5, H + 0.83), 0.15, 0.15, 16))
t.append(smooth(sphere(glow, (0, 2.5, H + 0.83), 0.1, seg=14, rings=8, scale=(1, 0.4, 1))))
turreto = join(t, "Turret")
bpy.context.scene.cursor.location = (0, 0, H + 0.3)
bpy.ops.object.select_all(action='DESELECT'); turreto.select_set(True)
bpy.context.view_layer.objects.active = turreto
bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
turreto.scale = (1.3, 1.3, 1.3)
turreto.location.z += 0.12
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

# ---- eight legs: high knees, armour plates with violet light, pointed feet --------------------------------------------
legs = []
ANG = (35, 72, 108, 145)
for i, (deg, sx) in enumerate([(a, s) for a in ANG for s in (1, -1)]):
    a = math.radians(deg) * sx
    dirv = Vector((math.sin(a), math.cos(a), 0))
    hip = Vector((0, 0.1, H)) + dirv * Vector((0.62, 0.8, 0)).length * 0.75
    hip = Vector((dirv.x * 0.8, 0.1 + dirv.y * 1.1, H - 0.05))
    knee = hip + dirv * 0.9 + Vector((0, 0, 0.95))
    foot = hip + dirv * 1.85
    foot.z = 0.0
    lp = [smooth(sphere(dark, tuple(hip), 0.2, seg=12, rings=8)),
          L(dark, tuple(hip), tuple(knee), 0.1, 0.09, 10),
          slab(hull, tuple(hip + dirv * 0.05), tuple(knee), 0.34, 0.24, 0.7),
          smooth(sphere(hull2, tuple(knee), 0.17, seg=12, rings=8)),
          L(dark, tuple(knee), tuple(foot), 0.07, 0.04, 10),
          slab(hull, tuple(knee), tuple(foot + (knee - foot) * 0.15), 0.28, 0.2, 0.4),
          spike(tuple(knee), tuple(knee + dirv * 0.15 + Vector((0, 0, 0.45))), 0.07)]
    m1 = hip.lerp(knee, 0.55); m2 = knee.lerp(foot, 0.4)
    side = dirv.cross(Vector((0, 0, 1))).normalized()
    for m, nrm in ((m1, (knee - hip).normalized()), (m2, (foot - knee).normalized())):
        out = (side.cross(nrm)).normalized()
        if out.z < 0:
            out = -out
        lp.append(L(glow, tuple(m + out * 0.1 - nrm * 0.12), tuple(m + out * 0.1 + nrm * 0.12), 0.018, 0.018, 6))
    lp.append(L(hull2, tuple(foot + Vector((0, 0, 0.25))), tuple(foot), 0.07, 0.0, 6, sm=False))   # the pointed foot
    lo = join(lp, "Leg%d" % i)
    bpy.context.scene.cursor.location = tuple(hip)
    bpy.ops.object.select_all(action='DESELECT'); lo.select_set(True)
    bpy.context.view_layer.objects.active = lo
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    legs.append(lo)

if "--preview" in sys.argv:
    i = sys.argv.index("--preview")
    preview(sys.argv[i + 3], target=(0, 0.3, 1.4), dist=float(sys.argv[i + 5]) if len(sys.argv) > i + 5 else 7.0,
            angle=float(sys.argv[i + 4]), height=0.35, res=(720, 480))
else:
    export_glb(OUT, [hullo, turreto] + legs)
    print("written", OUT)
