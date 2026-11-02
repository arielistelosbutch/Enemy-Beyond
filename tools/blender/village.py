"""Enemy Beyond - village props (own designs, Czech countryside at night).
Each prop: visual pieces joined, plus simple "*-colonly" boxes for collision.
Front = +Y (Godot -Z). Origin on the ground in the middle."""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from common import *
from mathutils import Vector

OUTDIR = sys.argv[-1]
TAU = math.tau

def M():
    return dict(
        wood=mat("VWood", (0.33, 0.22, 0.12), rough=0.9), dwood=mat("VDarkWood", (0.18, 0.12, 0.07), rough=0.9),
        tile=mat("VRoofTile", (0.42, 0.14, 0.09), rough=0.8), plaster=mat("VPlaster", (0.75, 0.72, 0.62), rough=0.95),
        stone=mat("VStone", (0.4, 0.4, 0.38), rough=0.95), metal=mat("VMetal", (0.3, 0.31, 0.33), rough=0.5),
        rust=mat("VRust", (0.38, 0.18, 0.08), rough=0.8), glass=mat("VGlass", (0.08, 0.1, 0.12), rough=0.1),
        lit=mat("VLitWindow", (1.0, 0.75, 0.4), emit=2.0), red=mat("VRedPaint", (0.5, 0.08, 0.06), rough=0.6),
        green=mat("VGreenPaint", (0.18, 0.3, 0.15), rough=0.7), blue=mat("VBluePaint", (0.15, 0.22, 0.35), rough=0.6),
        tyre=mat("VTyre", (0.04, 0.04, 0.04), rough=0.9), white=mat("VWhite", (0.85, 0.85, 0.8), rough=0.8),
        cloth=mat("VCloth", (0.6, 0.58, 0.5), rough=0.95), straw=mat("VStraw", (0.6, 0.48, 0.2), rough=0.95),
    )

def colbox(name, loc, size, rot=(0, 0, 0)):
    o = box(mat("Col", (1, 0, 1)), loc, size, rot=rot)
    o.name = name + "-colonly"
    return o

def beam(mtl, p0, p1, w, t):
    p0 = Vector(p0); p1 = Vector(p1); d = p1 - p0
    o = box(mtl, (0, 0, 0), (w, t, d.length))
    o.rotation_mode = 'QUATERNION'
    o.rotation_quaternion = d.normalized().to_track_quat('Z', 'Y')
    o.location = (p0 + p1) / 2
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=True, rotation=True)
    return o

def save(name, vis, col):
    o = join(vis, name)
    export_glb(os.path.join(OUTDIR, "v_%s.glb" % name.lower()), [o] + col)

def gable_roof(m, w, d, h0, pitch_h, vis, overhang=0.35):
    """A pitched tile roof over a w x d house whose walls end at h0, ridge along X."""
    half = d / 2 + overhang
    for s in (-1, 1):
        p0 = (0, s * half, h0 - 0.1)
        p1 = (0, 0, h0 + pitch_h)
        L = (Vector(p1) - Vector(p0)).length
        a = math.atan2(pitch_h + 0.1, half)
        vis.append(box(m["tile"], (0, s * half / 2, h0 + pitch_h / 2 - 0.05), (w + overhang * 2, L, 0.12), rot=(-s * a, 0, 0)))
        for k in range(int(L / 0.35)):      # tile rows
            t = (k + 0.5) / int(L / 0.35)
            y = s * half * (1 - t); z = h0 - 0.1 + (pitch_h + 0.1) * t + 0.07
            vis.append(box(m["dwood"], (0, y, z), (w + overhang * 2, 0.03, 0.025), rot=(-s * a, 0, 0)))
    vis.append(box(m["dwood"], (0, 0, h0 + pitch_h + 0.04), (w + overhang * 2 + 0.05, 0.22, 0.12)))     # ridge
    # gable ends (triangles approximated by stacked boards)
    for sx in (-1, 1):
        for k in range(6):
            t = k / 6
            vis.append(box(m["plaster"], (sx * (w / 2 - 0.12), 0, h0 + pitch_h * (t + 1 / 12)), (0.25, (d) * (1 - t), pitch_h / 6 + 0.01)))

def house_roof():
    """Roof for the 8 x 6 m farmhouse (the walls are built by the game): tiles, chimney,
    gutters, a little attic window and a porch lamp bracket."""
    reset(); m = M(); vis = []; col = []
    w, d, h = 8.0, 6.0, 3.0
    gable_roof(m, w, d, 0.0, 2.2, vis)
    vis.append(box(m["stone"], (2.2, 0.8, 1.6), (0.55, 0.55, 2.0)))       # chimney
    vis.append(box(m["dwood"], (2.2, 0.8, 2.65), (0.65, 0.65, 0.1)))
    for s in (-1, 1):
        vis.append(beam(m["metal"], (-w / 2 - 0.35, s * (d / 2 + 0.38), -0.05), (w / 2 + 0.35, s * (d / 2 + 0.38), -0.05), 0.1, 0.1))
    vis.append(box(m["glass"], (-w / 2 + 0.1, 0, 0.9), (0.06, 0.6, 0.5)))      # attic window
    vis.append(box(m["dwood"], (-w / 2 + 0.08, 0, 0.9), (0.04, 0.75, 0.65)))
    col.append(colbox("Roof", (0, 0, 0.7), (w + 0.6, d + 0.6, 0.3)))
    save("House_Roof", vis, col)

def window():
    """A window for a wall gap: frame, cross, glass, shutters, sill. Thin (sits in a 0.25 wall)."""
    reset(); m = M(); vis = []
    vis.append(box(m["glass"], (0, 0, 0), (1.0, 0.04, 0.9)))
    vis.append(box(m["white"], (0, 0, 0.47), (1.1, 0.12, 0.06))); vis.append(box(m["white"], (0, 0, -0.47), (1.1, 0.12, 0.06)))
    vis.append(box(m["white"], (0.53, 0, 0), (0.06, 0.12, 1.0))); vis.append(box(m["white"], (-0.53, 0, 0), (0.06, 0.12, 1.0)))
    vis.append(box(m["white"], (0, 0, 0), (0.05, 0.08, 0.9))); vis.append(box(m["white"], (0, 0, 0.1), (1.0, 0.08, 0.05)))
    vis.append(box(m["stone"], (0, 0.12, -0.52), (1.25, 0.25, 0.08)))       # sill
    for sx in (-1, 1):
        vis.append(box(m["green"], (sx * 0.85, 0.08, 0), (0.45, 0.04, 1.0), rot=(0, 0, sx * 0.5)))
    save("Window", vis, [])

def well():
    reset(); m = M(); vis = []; col = []
    vis.append(cyl(m["stone"], (0, 0, 0.45), 0.75, 0.9, verts=10))
    vis.append(cyl(m["tyre"], (0, 0, 0.91), 0.55, 0.02, verts=10))
    for sx in (-1, 1):
        vis.append(box(m["dwood"], (sx * 0.7, 0, 1.25), (0.12, 0.12, 1.6)))
    vis.append(cyl(m["wood"], (0, 0, 1.6), 0.1, 1.5, verts=8, rot=(0, math.pi / 2, 0)))
    vis.append(box(m["metal"], (0.85, 0, 1.6), (0.05, 0.3, 0.05)))
    gable_roof(m, 1.7, 1.1, 2.0, 0.5, vis, overhang=0.15)
    vis.append(cyl(m["rust"], (0.2, 0.3, 0.12), 0.15, 0.25, verts=8))       # a bucket, fallen
    col.append(colbox("Well", (0, 0, 0.6), (1.5, 1.5, 1.2)))
    save("Well", vis, col)

def woodpile():
    reset(); m = M(); vis = []; col = []
    for row in range(5):
        for k in range(9):
            vis.append(cyl(m["wood"] if (k + row) % 3 else m["dwood"], (-1.0 + k * 0.25, 0, 0.12 + row * 0.22), 0.11, 0.7, verts=6, rot=(math.pi / 2, 0, 0)))
    vis.append(box(m["dwood"], (0, 0, 1.3), (2.6, 1.0, 0.06), rot=(0.15, 0, 0)))
    vis.append(box(m["wood"], (0.9, 0.7, 0.3), (0.3, 0.3, 0.6)))            # chopping block
    vis.append(beam(m["metal"], (0.95, 0.7, 0.6), (1.3, 0.9, 1.1), 0.04, 0.04))   # axe handle
    col.append(colbox("Pile", (0, 0, 0.6), (2.4, 0.8, 1.2)))
    save("Woodpile", vis, col)

def tractor():
    """An old red tractor, abandoned with the plough still down."""
    reset(); m = M(); vis = []; col = []
    vis.append(box(m["red"], (0, 0.6, 1.0), (0.9, 1.8, 0.7)))               # bonnet
    vis.append(box(m["metal"], (0, 1.52, 0.95), (0.85, 0.06, 0.6)))           # grille
    vis.append(cyl(m["metal"], (0.25, 1.1, 1.65), 0.05, 0.6, verts=6))        # exhaust
    vis.append(box(m["red"], (0, -0.6, 1.0), (1.2, 1.0, 0.5)))
    vis.append(box(m["tyre"], (0, -0.7, 1.45), (0.5, 0.4, 0.1)))              # seat
    vis.append(cyl(m["tyre"], (0, -0.3, 1.6), 0.2, 0.05, verts=10, rot=(0.6, 0, 0)))   # wheel
    for sx in (-1, 1):
        vis.append(cyl(m["tyre"], (sx * 0.85, -0.7, 0.75), 0.75, 0.4, verts=12, rot=(0, math.pi / 2, 0)))
        vis.append(cyl(m["red"], (sx * 0.86, -0.7, 0.75), 0.4, 0.42, verts=10, rot=(0, math.pi / 2, 0)))
        vis.append(cyl(m["tyre"], (sx * 0.6, 1.1, 0.42), 0.42, 0.25, verts=10, rot=(0, math.pi / 2, 0)))
    vis.append(box(m["rust"], (0, -2.0, 0.35), (1.6, 0.6, 0.15), rot=(0.4, 0, 0)))   # plough
    vis.append(box(m["lit"], (0.3, 1.55, 1.2), (0.15, 0.04, 0.12))); vis.append(box(m["lit"], (-0.3, 1.55, 1.2), (0.15, 0.04, 0.12)))
    col.append(colbox("Tractor", (0, 0, 0.9), (2.0, 3.4, 1.8)))
    save("Tractor", vis, col)

def car(paint):
    """A boxy old hatchback (generic)."""
    reset(); m = M(); vis = []; col = []
    pm = mat("VCar%s" % paint[0], paint[1], rough=0.4)
    vis.append(box(pm, (0, 0, 0.6), (1.6, 3.8, 0.6)))
    vis.append(box(pm, (0, -0.35, 1.15), (1.5, 2.0, 0.55)))
    vis.append(box(m["glass"], (0, 0.68, 1.12), (1.4, 0.04, 0.45), rot=(-0.6, 0, 0)))
    vis.append(box(m["glass"], (0, -1.36, 1.15), (1.4, 0.04, 0.45), rot=(0.3, 0, 0)))
    for sx in (-1, 1):
        vis.append(box(m["glass"], (sx * 0.76, -0.35, 1.18), (0.03, 1.8, 0.38)))
        for sy in (-1, 1):
            vis.append(cyl(m["tyre"], (sx * 0.75, sy * 1.2, 0.32), 0.32, 0.2, verts=10, rot=(0, math.pi / 2, 0)))
        vis.append(box(m["lit"] if paint[0] == "Blue" else m["white"], (sx * 0.55, 1.91, 0.7), (0.3, 0.03, 0.15)))
        vis.append(box(m["red"], (sx * 0.6, -1.91, 0.75), (0.25, 0.03, 0.12)))
    vis.append(box(m["metal"], (0, 1.93, 0.4), (1.6, 0.08, 0.12))); vis.append(box(m["metal"], (0, -1.93, 0.4), (1.6, 0.08, 0.12)))
    col.append(colbox("Car", (0, 0, 0.75), (1.6, 3.9, 1.5)))
    save("Car_%s" % paint[0], vis, col)

def pole():
    """Telegraph pole with crossbar and white insulators; wires are added by the game."""
    reset(); m = M(); vis = []; col = []
    vis.append(cyl(m["dwood"], (0, 0, 3.5), 0.12, 7.0, verts=8, r2=0.09))
    vis.append(box(m["dwood"], (0, 0, 6.6), (1.6, 0.12, 0.12)))
    for x in (-0.7, -0.25, 0.25, 0.7):
        vis.append(cyl(m["white"], (x, 0, 6.75), 0.05, 0.18, verts=6))
    vis.append(box(m["metal"], (0, 0.15, 2.5), (0.2, 0.05, 0.3)))
    col.append(colbox("Pole", (0, 0, 3.5), (0.25, 0.25, 7.0)))
    save("Pole", vis, col)

def wayside_cross():
    """A stone wayside cross at the crossroads, with a dead candle."""
    reset(); m = M(); vis = []; col = []
    vis.append(box(m["stone"], (0, 0, 0.3), (1.0, 1.0, 0.6)))
    vis.append(box(m["stone"], (0, 0, 1.3), (0.4, 0.4, 1.4)))
    vis.append(box(m["metal"], (0, 0, 2.5), (0.08, 0.08, 1.0)))
    vis.append(box(m["metal"], (0, 0, 2.7), (0.6, 0.08, 0.08)))
    vis.append(cyl(m["red"], (0.25, 0.42, 0.66), 0.06, 0.12, verts=8))
    col.append(colbox("Cross", (0, 0, 1.0), (1.0, 1.0, 2.0)))
    save("Cross", vis, col)

def chapel():
    """A small village chapel (kaplička): white walls, a little bell tower, a locked door."""
    reset(); m = M(); vis = []; col = []
    w, d, h = 3.2, 4.0, 3.2
    vis.append(box(m["white"], (0, 0, h / 2), (w, d, h)))
    vis.append(box(m["dwood"], (0, d / 2 + 0.02, 1.0), (1.0, 0.06, 2.0)))
    vis.append(cyl(m["dwood"], (0, d / 2 + 0.02, 2.0), 0.5, 0.06, verts=10, rot=(math.pi / 2, 0, 0)))
    for sx in (-1, 1):
        vis.append(box(m["glass"], (sx * (w / 2 + 0.01), 0, 2.0), (0.04, 0.6, 1.0)))
    for k in range(7):    # the roof along Y
        t = k / 7
        vis.append(box(m["tile"], (0, 0, h + 0.15 + t * 1.4), (w * (1 - t) + 0.4, d + 0.4, 0.22)))
    vis.append(box(m["white"], (0, d / 2 - 0.6, h + 1.8), (0.9, 0.9, 1.2)))      # bell tower
    vis.append(cyl(m["tile"], (0, d / 2 - 0.6, h + 2.75), 0.7, 0.7, verts=4, r2=0.02, rot=(0, 0, math.pi / 4)))
    vis.append(box(m["metal"], (0, d / 2 - 0.6, h + 3.4), (0.05, 0.05, 0.5)))
    vis.append(box(m["metal"], (0, d / 2 - 0.6, h + 3.5), (0.3, 0.05, 0.05)))
    vis.append(cyl(m["rust"], (0, d / 2 - 0.6, h + 1.7), 0.2, 0.3, verts=8, r2=0.12))  # bell
    col.append(colbox("Chapel", (0, 0, h / 2), (w, d, h)))
    save("Chapel", vis, col)

def bus_stop():
    reset(); m = M(); vis = []; col = []
    vis.append(box(m["stone"], (0, 0, 1.1), (3.0, 0.15, 2.2)))
    for sx in (-1, 1):
        vis.append(box(m["stone"], (sx * 1.45, 0.6, 1.1), (0.12, 1.2, 2.2)))
    vis.append(box(m["stone"], (0, 0.55, 2.25), (3.2, 1.4, 0.12)))
    vis.append(box(m["wood"], (0, 0.35, 0.45), (2.4, 0.4, 0.06)))
    vis.append(box(m["metal"], (1.9, 0.9, 1.3), (0.06, 0.06, 2.6)))
    vis.append(box(m["white"], (1.9, 0.9, 2.5), (0.5, 0.04, 0.4)))
    vis.append(box(m["white"], (-0.6, 0.09, 1.4), (0.6, 0.02, 0.8)))      # timetable (torn)
    col.append(colbox("Stop", (0, 0.1, 1.1), (3.0, 0.4, 2.2)))
    col.append(colbox("SideL", (-1.45, 0.6, 1.1), (0.15, 1.2, 2.2)))
    col.append(colbox("SideR", (1.45, 0.6, 1.1), (0.15, 1.2, 2.2)))
    save("Bus_Stop", vis, col)

def coop():
    """Chicken coop - its little door open. Inside: feathers. No chickens."""
    reset(); m = M(); vis = []; col = []
    vis.append(box(m["wood"], (0, 0, 0.8), (2.0, 1.4, 1.2)))
    vis.append(box(m["tile"], (0, 0, 1.5), (2.3, 1.7, 0.1), rot=(0.25, 0, 0)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            vis.append(box(m["dwood"], (sx * 0.9, sy * 0.6, 0.15), (0.1, 0.1, 0.3)))
    vis.append(box(m["dtile"] if False else m["tyre"], (0.5, 0.71, 0.75), (0.35, 0.02, 0.4)))
    vis.append(box(m["wood"], (0.5, 0.95, 0.35), (0.3, 0.6, 0.04), rot=(0.7, 0, 0)))   # ramp
    for k in range(6):
        vis.append(box(m["white"], (0.6 + (k % 3) * 0.3, 1.4 + (k // 3) * 0.4, 0.02), (0.08, 0.03, 0.01), rot=(0, 0, k)))
    col.append(colbox("Coop", (0, 0, 0.8), (2.0, 1.4, 1.6)))
    save("Coop", vis, col)

def scarecrow():
    """A scarecrow in the field. Something about its head is wrong."""
    reset(); m = M(); vis = []; col = []
    vis.append(box(m["dwood"], (0, 0, 1.1), (0.1, 0.1, 2.2)))
    vis.append(box(m["dwood"], (0, 0, 1.7), (1.6, 0.08, 0.08)))
    vis.append(box(m["cloth"], (0, 0, 1.45), (0.6, 0.3, 0.7)))
    vis.append(box(m["blue"], (0, 0, 1.0), (0.5, 0.28, 0.3)))
    vis.append(sphere(m["straw"], (0, 0, 2.05), 0.22, seg=8, rings=5, scale=(1, 1, 1.2)))
    vis.append(cyl(m["dwood"], (0, 0, 2.3), 0.35, 0.05, verts=10)); vis.append(cyl(m["dwood"], (0, 0, 2.4), 0.18, 0.2, verts=10))
    for sx in (-1, 1):
        vis.append(box(m["straw"], (sx * 0.85, 0, 1.65), (0.12, 0.1, 0.25)))
        vis.append(box(m["tyre"], (sx * 0.08, 0.2, 2.1), (0.05, 0.02, 0.05)))
    col.append(colbox("Scare", (0, 0, 1.1), (0.3, 0.3, 2.2)))
    save("Scarecrow", vis, col)

def laundry():
    """A laundry line between two posts, sheets hanging still in the wind."""
    reset(); m = M(); vis = []; col = []
    for sx in (-1, 1):
        vis.append(box(m["dwood"], (sx * 2.5, 0, 0.9), (0.08, 0.08, 1.8)))
        col.append(colbox("Post%d" % (sx + 1), (sx * 2.5, 0, 0.9), (0.1, 0.1, 1.8)))
    vis.append(beam(m["white"], (-2.5, 0, 1.75), (2.5, 0, 1.75), 0.015, 0.015))
    for k, (x, w, c) in enumerate(((-1.6, 1.2, "white"), (-0.2, 0.9, "cloth"), (1.2, 1.3, "white"))):
        vis.append(box(m[c], (x, 0, 1.2), (w, 0.02, 1.1), rot=(0.05 * (k - 1), 0, 0)))
    save("Laundry", vis, col)

def trough():
    reset(); m = M(); vis = []; col = []
    vis.append(box(m["stone"], (0, 0, 0.35), (2.2, 0.7, 0.7)))
    vis.append(box(mat("VWater", (0.05, 0.07, 0.08), rough=0.05), (0, 0, 0.62), (2.0, 0.5, 0.02)))
    col.append(colbox("Trough", (0, 0, 0.35), (2.2, 0.7, 0.7)))
    save("Trough", vis, col)

for f in (house_roof, window, well, woodpile, tractor, pole, wayside_cross, chapel, bus_stop, coop, scarecrow, laundry, trough):
    f()
for paint in (("Blue", (0.15, 0.25, 0.45)), ("Red", (0.45, 0.1, 0.08)), ("Beige", (0.6, 0.55, 0.42))):
    car(paint)
