"""Levit (0.50) after Ari's picture: a stitched, scarred grey torso with a skull of a face - red
glowing eyes, a gaping mouth full of long fangs, an implant plate bolted to the skull - hoses running
from a glowing red tank on the back into the neck and shoulders, an armoured chest harness with red
light strips, thin arms holding a heavy laser rifle. Below, the pulsing magenta anti-gravity organ in
a net of veins, and long hanging tentacles.
Rigid pieces as before: Body (with the rifle), Organ (pulses).
Run: python3 tools/blender/levit.py [velitel] out.glb [--preview - 0 out.png angle dist z height]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from common import *
from common import _finish

VEL = "velitel" in sys.argv
OUT = [a for a in sys.argv if a.endswith(".glb")]
OUT = OUT[0] if OUT else "levit.glb"
reset()

def mat2(name, rgb, rough=0.6, metal=0.0, emit=0.0):
    m = mat(name, rgb, emit=emit, rough=rough)
    m.node_tree.nodes.get("Principled BSDF").inputs["Metallic"].default_value = metal
    return m

skin = mat2("LevSkin", (0.44, 0.33, 0.33), rough=0.45)
skin2 = mat2("LevSkin2", (0.3, 0.22, 0.23), rough=0.55)
scar = mat2("LevScar", (0.16, 0.06, 0.07), rough=0.6)
mouth = mat2("LevMouth", (0.08, 0.01, 0.015), rough=0.4)
tooth = mat2("LihTooth", (0.66, 0.6, 0.5), rough=0.35)
eye = mat("LevEye", (1.0, 0.12, 0.08), emit=5.0)
metal = mat2("LevMetal", (0.24, 0.24, 0.25), rough=0.4, metal=0.8)
hose = mat2("LevHose", (0.05, 0.05, 0.055), rough=0.5)
red = mat("LevRed", (1.0, 0.1, 0.06), emit=4.0)
organ = mat("LevOrgan", (0.95, 0.2, 0.6), emit=2.6)
vein = mat2("LevVein", (0.28, 0.04, 0.08), rough=0.35)
tent = mat2("LevTent", (0.35, 0.12, 0.14), rough=0.35)
gun = mat2("LevGun", (0.3, 0.3, 0.31), rough=0.4, metal=0.7)
if VEL:
    # Levit Mírotvůrce: violet glow everywhere, purpler flesh
    skin = mat2("MirSkin", (0.4, 0.27, 0.36), rough=0.45)
    skin2 = mat2("MirSkin2", (0.27, 0.16, 0.24), rough=0.55)
    eye = mat("MirEye", (0.8, 0.3, 1.0), emit=6.0)
    red = mat("MirGlow", (0.72, 0.22, 1.0), emit=3.0)
    organ = mat("MirOrgan", (0.62, 0.16, 0.95), emit=2.2)
    vein = mat2("MirVein", (0.24, 0.05, 0.22), rough=0.35)
    tent = mat2("MirTent", (0.3, 0.12, 0.26), rough=0.3)
    gun = mat2("MirGun", (0.22, 0.22, 0.24), rough=0.4, metal=0.75)
    glass = mat("MirGlass", (0.65, 0.25, 1.0), emit=2.0)

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

def limb(material, a, b, r1, r2, verts=8, sm=True):
    a = Vector(a); b = Vector(b)
    d = b - a
    o = cyl(material, (0, 0, 0), r1, max(d.length, 0.001), verts=verts, r2=r2)
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    for v in o.data.vertices:
        v.co = q @ v.co + (a + b) / 2
    return smooth(o) if sm else o

def chain(material, pts, r1, r2, verts=8):
    """A bent tube through points, getting thinner (hoses, tentacles)."""
    out = []
    n = len(pts) - 1
    for i in range(n):
        ra = r1 + (r2 - r1) * i / n
        rb = r1 + (r2 - r1) * (i + 1) / n
        out.append(limb(material, pts[i], pts[i + 1], ra, rb, verts=verts))
        if i < n - 1:
            out.append(smooth(sphere(material, pts[i + 1], rb, seg=verts, rings=4)))
    return out

B = []
# ---- the skull of a face ---------------------------------------------------------------------------------
hz = 0.66
h = sphere(skin, (0, 0.0, hz), 0.11, seg=20, rings=14, scale=(0.86, 1.0, 1.08))
for v in h.data.vertices:
    c = v.co
    if c.z < hz - 0.02 and c.y > 0:            # hollow cheeks, a jutting jaw
        c.x *= 0.82
    if c.z > hz + 0.05:                         # a high, bald, stitched dome
        c.y -= 0.01
B.append(smooth(h))
B.append(smooth(sphere(mouth, (0, 0.075, hz - 0.055), 0.05, seg=14, rings=10, scale=(1.0, 0.6, 1.25))))     # the gaping mouth
jaw = sphere(skin2, (0, 0.06, hz - 0.12), 0.06, seg=14, rings=8, scale=(1.0, 0.95, 0.55))
B.append(smooth(jaw))
for i in range(8):                                                                       # long fangs, top and bottom
    xx = -0.042 + i * 0.012
    ln = 0.05 if i in (1, 6) else 0.032
    B.append(limb(tooth, (xx, 0.092, hz - 0.03), (xx, 0.1, hz - 0.03 - ln), 0.0055, 0.0005, verts=5))
    B.append(limb(tooth, (xx + 0.006, 0.09, hz - 0.11), (xx + 0.006, 0.098, hz - 0.11 + ln * 0.8), 0.005, 0.0005, verts=5))
for x in (1, -1):
    B.append(smooth(sphere(mouth, (0.038 * x, 0.075, hz + 0.02), 0.026, seg=10, rings=8, scale=(1.1, 0.6, 0.9))))   # deep sockets
    B.append(smooth(sphere(eye, (0.038 * x, 0.088, hz + 0.02), 0.013, seg=10, rings=8)))
    B.append(box(scar, (0.012 * x, 0.098, hz - 0.005), (0.006, 0.01, 0.02)))                              # the nose holes
for k in range(3):                                                                       # stitches over the skull
    B.append(box(scar, (0.02 * (k - 1), 0.01 - k * 0.03, hz + 0.1), (0.008, 0.07, 0.006), rot=(0.3 * (k - 1), 0, 0.3)))
    for s in range(4):
        B.append(box(scar, (0.02 * (k - 1) - 0.012, 0.035 - k * 0.03 - s * 0.017, hz + 0.1), (0.024, 0.003, 0.004)))
B.append(bevel(box(metal, (0.085, -0.01, hz + 0.03), (0.03, 0.08, 0.07)), 0.008))       # the implant plate
for k in range(3):
    B.append(smooth(sphere(red if k == 1 else metal, (0.1, -0.03 + k * 0.025, hz + 0.03), 0.008, seg=6, rings=4)))
# ---- neck, chest, harness ----------------------------------------------------------------------------------------
for x in (-0.025, 0.0, 0.025):
    B.append(limb(skin2, (x, 0.0, 0.46), (x * 0.6, 0.01, hz - 0.08), 0.022, 0.016))      # tendons
B.append(smooth(sphere(skin, (0, 0, 0.32), 0.19, seg=16, rings=10, scale=(1.15, 0.8, 1.0))))   # the chest
for k in range(4):                                                                         # ribs under the skin
    B.append(smooth(limb(skin2, (-0.11, 0.115, 0.4 - k * 0.055), (0.11, 0.115, 0.4 - k * 0.055), 0.012, 0.012, verts=6)))
B.append(bevel(box(metal, (0, 0.13, 0.28), (0.24, 0.05, 0.2)), 0.015, 2))                 # chest plate
for x in (1, -1):
    B.append(box(red, (0.085 * x, 0.158, 0.28), (0.014, 0.008, 0.15)))                     # red light strips
    B.append(bevel(box(metal, (0.06 * x, 0.12, 0.42), (0.02, 0.04, 0.16), rot=(0.3, 0, 0.2 * x)), 0.004))   # straps
    B.append(smooth(sphere(metal, (0.2 * x, -0.01, 0.44), 0.075, seg=12, rings=8, scale=(1.1, 1.0, 0.75))))  # shoulder armour
    B.append(smooth(sphere(red, (0.24 * x, 0.04, 0.44), 0.012, seg=6, rings=4)))
B.append(bevel(box(hose, (0, 0, 0.16), (0.34, 0.27, 0.08)), 0.012, 2))                     # the belt where flesh begins
# the tank on the back and its hoses
B.append(smooth(cyl(metal, (0.1, -0.2, 0.44), 0.05, 0.16, verts=14)))
B.append(smooth(cyl(red, (0.1, -0.2, 0.44), 0.042, 0.11, verts=14)))
B.append(smooth(cyl(metal, (-0.1, -0.18, 0.4), 0.04, 0.12, verts=12)))
for pts in ([(0.1, -0.2, 0.53), (0.1, -0.14, 0.64), (0.05, -0.05, 0.6), (0.03, 0.0, 0.52)],
            [(0.1, -0.2, 0.36), (0.22, -0.16, 0.3), (0.24, -0.02, 0.22), (0.2, 0.08, 0.18)],
            [(-0.1, -0.18, 0.47), (-0.14, -0.1, 0.56), (-0.06, -0.03, 0.55)],
            [(-0.1, -0.18, 0.33), (-0.22, -0.1, 0.25), (-0.18, 0.05, 0.12)]):
    B += chain(hose, pts, 0.016, 0.013)
# ---- arms and the laser rifle --------------------------------------------------------------------------------------
for x in (1, -1):
    B.append(limb(skin, (0.2 * x, 0, 0.42), (0.24 * x, 0.12, 0.22), 0.04, 0.03))
    B.append(smooth(sphere(skin2, (0.24 * x, 0.12, 0.22), 0.03, seg=8, rings=6)))
    B.append(limb(skin, (0.24 * x, 0.12, 0.22), (0.1 * x, 0.32, 0.2), 0.03, 0.026))
    B.append(smooth(sphere(skin, (0.1 * x, 0.33, 0.2), 0.03, seg=8, rings=6, scale=(1, 1.3, 0.8))))
    for f in range(4):                                                                     # bony fingers round the gun
        B.append(limb(skin2, (0.1 * x + (f - 1.5) * 0.008, 0.35, 0.2), (0.08 * x + (f - 1.5) * 0.01, 0.37, 0.25), 0.006, 0.004, verts=5))
B.append(bevel(box(gun, (0.0, 0.42, 0.21), (0.09, 0.56, 0.1)), 0.012, 2))
B.append(bevel(box(gun, (0.0, 0.36, 0.27), (0.07, 0.24, 0.04)), 0.008))
B.append(box(red, (0.047, 0.48, 0.21), (0.006, 0.26, 0.02)))
B.append(box(red, (-0.047, 0.48, 0.21), (0.006, 0.26, 0.02)))
B.append(limb(gun, (0, 0.7, 0.21), (0, 0.8, 0.21), 0.034, 0.03, verts=10))
B.append(smooth(sphere(red, (0, 0.8, 0.21), 0.026, seg=10, rings=8)))
if VEL:
    # the face torn by hooks and fixing implants
    for x in (1, -1):
        for k, (yy, zz) in enumerate(((0.07, hz - 0.03), (0.06, hz - 0.09), (0.03, hz + 0.06))):
            a = (0.09 * x, yy, zz)
            b = (0.2 * x, yy - 0.06, zz + 0.04 - k * 0.02)
            B.append(limb(metal, a, b, 0.006, 0.006, verts=6))
            B.append(limb(metal, b, (0.21 * x, yy - 0.09, zz + 0.09 - k * 0.02), 0.006, 0.004, verts=6))   # the hook bends back
            B.append(smooth(sphere(metal, a, 0.011, seg=6, rings=4)))
    B.append(limb(metal, (-0.1, 0.06, hz + 0.0), (0.1, 0.06, hz + 0.0), 0.005, 0.005, verts=6))          # a rod through the cheeks
    # violet canisters on the shoulders, arcs of hoses rising behind them
    for x in (1, -1):
        B.append(smooth(cyl(metal, (0.26 * x, -0.06, 0.55), 0.05, 0.17, verts=14)))
        B.append(smooth(cyl(glass, (0.26 * x, -0.06, 0.55), 0.042, 0.12, verts=14)))
        B.append(smooth(cyl(metal, (0.26 * x, -0.06, 0.645), 0.03, 0.03, verts=10)))
        pts = []
        for k in range(9):                    # a hoop: up from the shoulder blade, out, and over towards the head
            th = math.radians(-80 + k * 25)
            pts.append((0.17 * x + 0.2 * x * math.cos(th), -0.2, 0.6 + 0.26 * math.sin(th)))
        B += chain(hose, pts, 0.024, 0.02, verts=8)
        for k in (2, 4, 6):
            B.append(limb(red, pts[k], pts[k + 1], 0.03, 0.03, verts=10))
        for pts2 in ([(0.26 * x, -0.06, 0.66), (0.2 * x, 0.0, 0.72), (0.06 * x, 0.04, 0.6)],
                     [(0.26 * x, -0.06, 0.45), (0.32 * x, 0.04, 0.32), (0.22 * x, 0.12, 0.12)]):
            B += chain(red, pts2, 0.008, 0.007, verts=6)
    # the heavy plasma rifle over the laser one: a thicker body, a violet coil, a wide muzzle
    B.append(bevel(box(gun, (0.0, 0.5, 0.21), (0.13, 0.5, 0.13)), 0.015, 2))
    B.append(smooth(limb(glass, (0, 0.5, 0.21), (0, 0.9, 0.21), 0.05, 0.05, verts=12)))
    for k in range(5):
        B.append(smooth(limb(metal, (0, 0.52 + k * 0.08, 0.21), (0, 0.54 + k * 0.08, 0.21), 0.062, 0.062, verts=12)))
    B.append(smooth(limb(gun, (0, 0.9, 0.21), (0, 0.98, 0.21), 0.07, 0.07, verts=12)))
    B.append(smooth(sphere(red, (0, 0.98, 0.21), 0.05, seg=12, rings=8, scale=(1, 0.4, 1))))
bodyo = join(B, "Body")

# ---- the organ: a pulsing sac in a net of veins, and the tentacles ------------------------------------------------
O = [smooth(sphere(organ, (0, 0, 0.0), 0.17, seg=18, rings=12, scale=(1.05, 1.0, 0.9) if not VEL else (1.3, 1.25, 1.2)))]
if VEL:
    # the mechanical cradle that holds the bigger organ: bands, clamps, glass tubes
    bpy.ops.mesh.primitive_torus_add(major_radius=0.215, minor_radius=0.016, major_segments=28, minor_segments=6)
    O.append(smooth(_finish(bpy.context.active_object, metal, (0, 0, 0.03), (0, 0, 0), (1, 1, 1))))
    for i in range(4):                        # four clamps arching over the sac
        a = i / 4 * math.tau + 0.4
        pts = [(math.sin(a) * 0.12 * k2 / 1.0 if False else math.sin(a) * r2, math.cos(a) * r2, z2) for r2, z2 in ((0.1, 0.2), (0.2, 0.13), (0.23, 0.0), (0.19, -0.14), (0.1, -0.2))]
        O += chain(metal, pts, 0.014, 0.014, verts=6)
        O.append(bevel(box(metal, (math.sin(a) * 0.235, math.cos(a) * 0.235, 0.03), (0.05, 0.04, 0.07), rot=(0, 0, -a)), 0.008))
    for i in range(3):                        # glass tubes feeding it
        a = i / 3 * math.tau + 1.2
        O += chain(glass, [(math.sin(a) * 0.12, math.cos(a) * 0.12, 0.24), (math.sin(a) * 0.27, math.cos(a) * 0.27, 0.1), (math.sin(a) * 0.25, math.cos(a) * 0.25, -0.1)], 0.018, 0.016, verts=8)
NT = 15 if VEL else 11
for i in range(NT):                                                                          # tentacles, long and curling
    a = i / NT * math.tau + 0.2
    ln = (0.75 + (i % 3) * 0.18) * (1.15 if VEL else 1.0)
    r0 = 0.12 if not VEL else 0.17
    pts = []
    for k in range(6):
        t = k / 5
        sway = math.sin(t * 3.0 + i * 1.7) * 0.07 * t
        rr = r0 + 0.32 * math.sin(t * 2.2) * (0.7 + 0.3 * (i % 2)) + sway       # out from the sac, then hanging down
        tw = 0.9 * t * (1 if i % 2 else -1)
        pts.append((math.sin(a + tw) * rr, math.cos(a + tw) * rr, -0.05 - t * ln + 0.12 * math.sin(t * 3.1)))
    O += chain(tent, pts, 0.03 if not VEL else 0.036, 0.004, verts=7)
organo = join(O, "Organ")
bpy.context.scene.cursor.location = (0, 0, 0)
bpy.ops.object.select_all(action='DESELECT')
organo.select_set(True)
bpy.context.view_layer.objects.active = organo
bpy.ops.object.origin_set(type='ORIGIN_CURSOR')

if "--preview" in sys.argv:
    i = sys.argv.index("--preview")
    preview(sys.argv[i + 3], target=(0, 0.1, float(sys.argv[i + 6]) if len(sys.argv) > i + 6 else 0.0),
            dist=float(sys.argv[i + 5]) if len(sys.argv) > i + 5 else 2.4, angle=float(sys.argv[i + 4]),
            height=float(sys.argv[i + 7]) if len(sys.argv) > i + 7 else 0.2, res=(480, 600))
else:
    export_glb(OUT, [bodyo, organo])
    print("written", OUT)
