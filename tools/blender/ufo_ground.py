"""Enemy Beyond - landed / crashed UFOs you can walk into (own designs).
Three sizes: scout (one room), raider (entry + navigation), harvester (a core hall,
a ring of rooms and engines). A real saucer outside: lower dish, a rim with lights,
an upper hull with panel ribs, a dome; landing legs and a ramp at the door.
Collision pieces are named "*-colonly" (Godot makes static bodies of them).
Empties: Spawn_* (aliens), Way_* (paths), Light_* (violet lights), Core (power source).
Door faces +Y (Godot -Z). Floor at z=0.12."""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from common import *
from mathutils import Vector
import bmesh

OUTDIR = sys.argv[-1]
TAU = math.tau

def mat2(name, rgb, rough=0.6, metal=0.0, emit=0.0):
    m = mat(name, rgb, emit=emit, rough=rough)
    m.node_tree.nodes.get("Principled BSDF").inputs["Metallic"].default_value = metal
    return m

def M():
    # 0.50: their ships as in Ari's pictures - dark violet-black alloy, violet light in the seams, red eyes
    return dict(
        hull=mat2("UfoHull", (0.2, 0.17, 0.22), 0.35, 0.7),
        dark=mat2("UfoDark", (0.06, 0.05, 0.07), 0.45, 0.6),
        rib=mat2("UfoRib", (0.13, 0.11, 0.15), 0.4, 0.7),
        wall=mat("UfoWall", (0.16, 0.13, 0.2), rough=0.6),
        floor=mat("UfoFloorM", (0.11, 0.1, 0.13), rough=0.7),
        glow=mat("UfoGlow", (0.85, 0.25, 1.0), emit=4.0),
        core=mat("UfoCore", (0.35, 1.0, 0.45), emit=6.0),
        amber=mat("UfoAmber", (1.0, 0.15, 0.08), emit=4.0),
        screen=mat("UfoScreen", (0.2, 0.9, 0.7), emit=2.5),
        flesh=mat("UfoFlesh", (0.35, 0.18, 0.22), rough=0.8),
    )

def band(m, r1, z1, r2, z2, segs, skip=(), name="band", thick=0.0):
    """A ring band (cone frustum surface) made of segments; 'skip' leaves gaps (doors)."""
    me = bpy.data.meshes.new(name)
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    bm = bmesh.new()
    for i in range(segs):
        if i in skip:
            continue
        a0 = TAU * i / segs + math.pi / 2 - math.pi / segs
        a1 = TAU * (i + 1) / segs + math.pi / 2 - math.pi / segs
        v = [bm.verts.new((math.cos(a0) * r1, math.sin(a0) * r1, z1)), bm.verts.new((math.cos(a1) * r1, math.sin(a1) * r1, z1)),
             bm.verts.new((math.cos(a1) * r2, math.sin(a1) * r2, z2)), bm.verts.new((math.cos(a0) * r2, math.sin(a0) * r2, z2))]
        bm.faces.new(v)
        w = [bm.verts.new(x.co) for x in v]
        bm.faces.new(w[::-1])      # both sides visible
    bm.to_mesh(me); bm.free()
    o.data.materials.append(m)
    return o

def tri_plate(m, pts, name):
    me = bpy.data.meshes.new(name)
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    bm = bmesh.new()
    v = [bm.verts.new(p) for p in pts]
    bm.faces.new(v)
    w = [bm.verts.new(p) for p in pts]
    bm.faces.new(w[::-1])
    bm.to_mesh(me); bm.free()
    o.data.materials.append(m)
    return o

def disc(m, r, z, segs, name="disc"):
    return cyl(m, (0, 0, z), r, 0.04, verts=segs)

def seg_dir(i, segs):
    a = TAU * i / segs + math.pi / 2       # segment 0 faces +Y (the door)
    return a

def empty(name, loc):
    o = bpy.data.objects.new(name, None)
    o.location = loc
    bpy.context.scene.collection.objects.link(o)
    return o

def wall_ring(m, r, h, segs, skip, vis, col, prefix, thick=0.3, z0=0.12):
    """Wall made of straight segments around a circle; door gaps where skipped."""
    seg_len = 2.0 * r * math.tan(math.pi / segs) + 0.05
    for i in range(segs):
        if i in skip:
            continue
        a = seg_dir(i, segs)
        loc = (math.cos(a) * r, math.sin(a) * r, z0 + h / 2)
        w = box(m["wall"], loc, (seg_len, thick, h), rot=(0, 0, a - math.pi / 2))
        vis.append(w)
        # glowing strip and a rib on the inside face
        inner = r - thick / 2 - 0.02
        vis.append(box(m["glow"], (math.cos(a) * inner, math.sin(a) * inner, z0 + 1.55), (seg_len * 0.8, 0.03, 0.08), rot=(0, 0, a - math.pi / 2)))
        vis.append(box(m["rib"], (math.cos(a + math.pi / segs) * inner, math.sin(a + math.pi / segs) * inner, z0 + h / 2), (0.14, 0.12, h), rot=(0, 0, a - math.pi / 2)))
        c = box(m["dark"], loc, (seg_len, thick, h), rot=(0, 0, a - math.pi / 2))
        c.name = "%s%d-colonly" % (prefix, i)
        col.append(c)

def radial_wall(m, r0, r1, a, h, vis, col, name, door=False, z0=0.12):
    """A straight wall from radius r0 to r1 along angle a (with a doorway in the middle)."""
    pieces = [(r0, r1)]
    if door:
        mid = (r0 + r1) / 2
        pieces = [(r0, mid - 0.7), (mid + 0.7, r1)]
    for k, (ra, rb) in enumerate(pieces):
        if rb - ra < 0.1:
            continue
        cx = math.cos(a) * (ra + rb) / 2; cy = math.sin(a) * (ra + rb) / 2
        w = box(m["wall"], (cx, cy, z0 + h / 2), (rb - ra, 0.25, h), rot=(0, 0, a))
        vis.append(w)
        c = box(m["dark"], (cx, cy, z0 + h / 2), (rb - ra, 0.25, h), rot=(0, 0, a))
        c.name = "%s_%d-colonly" % (name, k)
        col.append(c)
    if door:
        mid = (r0 + r1) / 2
        vis.append(box(m["glow"], (math.cos(a) * mid, math.sin(a) * mid, z0 + 2.15), (1.5, 0.3, 0.1), rot=(0, 0, a)))

def console(m, loc, face, vis):
    """An alien console: a curved pedestal, a slanted screen, glowing glyph keys."""
    x, y, z = loc
    vis.append(cyl(m["rib"], (x, y, z + 0.45), 0.22, 0.9, verts=6, r2=0.32))
    vis.append(box(m["dark"], (x, y, z + 0.98), (0.75, 0.45, 0.06), rot=(0.35, 0, face)))
    vis.append(box(m["screen"], (x + math.cos(face + math.pi / 2) * 0.02, y + math.sin(face + math.pi / 2) * 0.02, z + 1.0), (0.6, 0.32, 0.01), rot=(0.35, 0, face)))
    for k in range(3):
        vis.append(box(m["amber"], (x + math.cos(face) * (k - 1) * 0.18, y + math.sin(face) * (k - 1) * 0.18, z + 0.75), (0.08, 0.04, 0.04), rot=(0, 0, face)))

def seat(m, loc, face, vis):
    x, y, z = loc
    vis.append(cyl(m["rib"], (x, y, z + 0.25), 0.08, 0.5, verts=6))
    vis.append(box(m["flesh"], (x, y, z + 0.55), (0.45, 0.45, 0.1)))
    vis.append(box(m["flesh"], (x - math.cos(face) * 0.2, y - math.sin(face) * 0.2, z + 0.9), (0.45, 0.08, 0.7), rot=(0, 0, face + math.pi / 2)))

def core(m, loc, size, vis, col):
    """The power source: a glowing crystal of Moskovium in a cage of ribs."""
    x, y, z = loc
    vis.append(cyl(m["rib"], (x, y, z + 0.2), size * 0.9, 0.4, verts=8, r2=size * 0.7))
    vis.append(cyl(m["core"], (x, y, z + 0.4 + size * 0.8), size * 0.4, size * 1.6, verts=6, r2=size * 0.15))
    for k in range(6):
        a = TAU * k / 6
        vis.append(box(m["rib"], (x + math.cos(a) * size * 0.75, y + math.sin(a) * size * 0.75, z + 0.4 + size * 0.8), (0.08, 0.08, size * 1.7), rot=(0, 0.15 * (1 if k % 2 else -1), a)))
    vis.append(cyl(m["rib"], (x, y, z + 0.5 + size * 1.7), size * 0.8, 0.15, verts=8, r2=size * 0.5))
    c = cyl(m["dark"], (x, y, z + 0.6), size * 0.9, 1.2, verts=8)
    c.name = "Core-colonly"
    col.append(c)
    empty("Core", (x, y, z + 1.0))

def beam(mtl, p0, p1, w, t):
    """A box from p0 to p1 (w wide, t thick) - ribs lying on the hull."""
    p0 = Vector(p0); p1 = Vector(p1); d = p1 - p0
    o = box(mtl, (0, 0, 0), (w, t, d.length))
    o.rotation_mode = 'QUATERNION'
    o.rotation_quaternion = d.normalized().to_track_quat('Z', 'Y')
    o.location = (p0 + p1) / 2
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=True, rotation=True)
    return o

def lens(m, prof, mats, n, door_top, vis, gap=(0, -1)):
    """A turned hull from a profile [(r, z), ...] in bands (material per band); the bands below
    door_top leave the doorway open (segments gap)."""
    g = tuple(k % n for k in gap)
    for k in range(len(prof) - 1):
        (r1, z1), (r2, z2) = prof[k], prof[k + 1]
        skip = g if min(z1, z2) < door_top else ()
        vis.append(band(m[mats[k]], r1, z1, r2, z2, n, skip=skip, name="Hull%d" % k))

def rim_lights(m, r, z, count, n_gap, vis, size=(0.12, 0.45, 0.08), door=True):
    for i in range(count):
        a = TAU * (i + 0.5) / count
        if door and abs(((a - math.pi / 2 + math.pi) % TAU) - math.pi) < 0.32:
            continue
        vis.append(box(m["glow"] if i % 2 else m["dimg"], (math.cos(a) * r, math.sin(a) * r, z), size, rot=(0, 0, a)))

def seams(m, r0, z0, r1, z1, count, vis, w=0.07, phase=0.0, mat="glow"):
    for i in range(count):
        a = TAU * (i + phase) / count
        ca, sa = math.cos(a), math.sin(a)
        vis.append(beam(m[mat], (ca * r0, sa * r0, z0), (ca * r1, sa * r1, z1), w, w))

def entry(m, r, rim, zr, n, vis):
    """The recess round the door: cheeks from the wall to the rim, a canopy over it."""
    for i in (0, n - 1):
        side = 1 if i == 0 else 0
        a = TAU * (i + side) / n + math.pi / 2 - math.pi / n
        ca, sa = math.cos(a), math.sin(a)
        vis.append(tri_plate(m["dark"], [(ca * r, sa * r, 0.12), (ca * rim, sa * rim, zr), (ca * r, sa * r, zr)], "Cheek%d" % i))
    vis.append(band(m["dark"], r, zr - 0.02, rim, zr - 0.02, n, skip=[k for k in range(n) if k not in (0, n - 1)], name="Canopy"))

def legs(m, rim, zr, vis, count=4):
    for k in range(count):
        a = TAU * (k + 0.5) / count + math.pi / 2
        top = (math.cos(a) * rim * 0.8, math.sin(a) * rim * 0.8, zr * 0.62)
        foot = (math.cos(a) * rim * 0.95, math.sin(a) * rim * 0.95, 0.06)
        vis.append(beam(m["rib"], top, foot, 0.24, 0.24))
        vis.append(cyl(m["dark"], foot, 0.5, 0.12, verts=10))

def hull2(kind, m, r, h, segs, vis):
    """0.56: the same ship as in the air (air.py): the scout's lens with its dark dome, the raider's
    lens inside a ring on spokes, the harvester's manta with swept wings - grown to fit the rooms."""
    n = segs * 2
    zr = h + 0.25                    # the rim stays above the doorway
    m["dimg"] = mat("UfoGlowDim", (0.55, 0.15, 0.7), emit=1.8)
    if kind == "scout":
        rim = r * 1.32
        prof = [(r + 0.05, 0.35), (r * 1.18, 1.4), (rim - 0.1, zr - 0.15), (rim, zr), (rim - 0.05, zr + 0.18),
                (r * 1.18, zr + 0.55), (r * 0.84, zr + 0.95), (r * 0.5, zr + 1.15)]
        lens(m, prof, ["hull", "hull", "rib", "rib", "hull", "hull", "hull"], n, zr, vis, (0, -1))
        dome = [(r * 0.5, zr + 1.15), (r * 0.46, zr + 1.6), (r * 0.32, zr + 2.0), (0.01, zr + 2.15)]
        lens(m, dome, ["dark", "dark", "dark"], n, -1, vis)
        seams(m, r * 0.52, zr + 1.17, r * 1.14, zr + 0.6, 12, vis)
        seams(m, r * 0.34, zr + 1.95, r * 0.46, zr + 1.62, 8, vis, 0.05, 0.5, "dimg")
        for k in range(3):
            vis.append(band(m["dark"], r * (0.56 + k * 0.17), zr + 1.13 - k * 0.12, r * (0.56 + k * 0.17) + 0.08, zr + 1.12 - k * 0.12, n, name="Ring%d" % k))
        rim_lights(m, rim + 0.04, zr, 16, n, vis)
        entry(m, r, rim, zr, n, vis)
        legs(m, rim, zr, vis, 3)
    elif kind == "raider":
        rim = r * 1.12
        prof = [(r + 0.05, 0.35), (r * 1.06, 1.3), (rim, zr), (rim - 0.05, zr + 0.2), (r * 0.98, zr + 0.9),
                (r * 0.62, zr + 1.45), (r * 0.36, zr + 1.6)]
        lens(m, prof, ["hull", "hull", "rib", "hull", "hull", "hull"], n, zr, vis, (0, -1))
        dome = [(r * 0.36, zr + 1.6), (r * 0.33, zr + 2.2), (r * 0.2, zr + 2.7), (0.01, zr + 2.85)]
        lens(m, dome, ["dark", "dark", "dark"], n, -1, vis)
        seams(m, r * 0.4, zr + 1.58, r * 0.9, zr + 1.0, 16, vis)
        for k in range(10):                                                    # slits round the dome
            a = TAU * k / 10
            vis.append(box(m["glow"], (math.cos(a) * r * 0.3, math.sin(a) * r * 0.3, zr + 2.3), (0.1, 0.6, 0.14), rot=(0, 0.6, a)))
        # the ring on its spokes, as in the air (high enough to walk under to the ramp)
        R0, R1 = r * 1.3, r * 1.45
        ring = [(R0, zr + 0.05), (R1 - 0.1, zr - 0.25), (R1, zr + 0.1), (R1 - 0.1, zr + 0.45), (R0, zr + 0.3), (R0, zr + 0.05)]
        lens(m, ring, ["rib", "rib", "rib", "rib", "dark"], n * 2, -1, vis)
        for i in range(8):
            a = TAU * (i + 0.5) / 8 + math.pi / 2
            ca, sa = math.cos(a), math.sin(a)
            vis.append(beam(m["rib"], (ca * (rim - 0.3), sa * (rim - 0.3), zr + 0.1), (ca * (R0 + 0.1), sa * (R0 + 0.1), zr + 0.15), 0.6, 0.4))
            vis.append(beam(m["glow"], (ca * (rim - 0.2), sa * (rim - 0.2), zr + 0.33), (ca * R0, sa * R0, zr + 0.36), 0.1, 0.05))
        for i in range(28):
            a = TAU * i / 28
            vis.append(box(m["glow"] if i % 2 else m["dimg"], (math.cos(a) * (R1 + 0.02), math.sin(a) * (R1 + 0.02), zr + 0.1), (0.14, 0.9, 0.24), rot=(0, 0, a)))
        for x in (2.6, -2.6):                                                  # the two red eyes at the front
            vis.append(sphere(m["amber"], (x, r * 1.02, 1.0), 0.5, seg=10, rings=6, scale=(1, 0.5, 0.6)))
        rim_lights(m, rim + 0.04, zr, 20, n, vis)
        entry(m, r, rim, zr, n, vis)
        legs(m, R0, zr, vis, 4)
    else:
        # the harvester: the round hall inside a manta - a broad body, swept wings, a dark hump, engines aft
        rim = r * 1.1
        prof = [(r + 0.05, 0.35), (r * 1.05, 1.4), (rim, zr), (rim - 0.05, zr + 0.2), (r * 0.95, zr + 0.8),
                (r * 0.6, zr + 1.15), (0.01, zr + 1.25)]
        lens(m, prof, ["hull", "hull", "rib", "hull", "hull", "hull"], n, zr, vis, (0, -1))
        hump = []
        for y, w, hh in ((8.0, 0.8, 0.3), (6.0, 3.2, 1.0), (2.0, 4.6, 1.5), (-2.5, 4.2, 1.4), (-6.0, 2.4, 0.9), (-8.0, 0.6, 0.3)):
            hump.append((y, w, hh))
        for (y0, w0, h0), (y1, w1, h1) in zip(hump[:-1], hump[1:]):
            vis.append(box(m["dark"], (0, (y0 + y1) / 2, zr + 1.2 + (h0 + h1) / 4), ((w0 + w1) / 2, abs(y1 - y0) + 0.05, (h0 + h1) / 2)))
        for i in range(8):                                                     # slits on the hump
            vis.append(box(m["glow"], (-2.8 + i * 0.8, 6.4, zr + 1.9), (0.14, 0.6, 0.14), rot=(0.5, 0, 0)))
        for x in (1, -1):
            pts = [(rim * 0.9 * x, 6.0), (12.2 * x, 2.0), (13.8 * x, -2.2), (13.5 * x, -4.2), (11.6 * x, -4.6), (10.0 * x, -6.6), (rim * 0.85 * x, -5.5)]
            w = plate_xy(m["hull"], pts, zr - 0.15, zr + 0.35)
            vis.append(w)
            vis.append(plate_xy(m["glow"], [(13.0 * x, -2.2), (13.9 * x, -2.4), (13.6 * x, -4.0), (12.9 * x, -3.6)], zr - 0.16, zr + 0.36))
            vis.append(plate_xy(m["rib"], [(11.0 * x, 3.4), (13.3 * x, -1.6), (13.1 * x, -2.2), (10.8 * x, 2.6)], zr + 0.34, zr + 0.42))
            for k in range(4):                                                 # vents on the wings
                vis.append(box(m["glow"] if k % 2 == 0 else m["dimg"], (x * (11.3 + k * 0.5), -1.5 - k * 0.6, zr + 0.4), (0.9, 0.12, 0.06), rot=(0, 0, 0.6 * x)))
            vis.append(beam(m["glow"], (2.5 * x, 7.5, zr + 1.3), (7.0 * x, 1.5, zr + 1.05), 0.12, 0.12))
            vis.append(beam(m["glow"], (7.0 * x, 1.5, zr + 1.05), (12.0 * x, -3.0, zr + 0.42), 0.12, 0.12))
            vis.append(sphere(m["amber"], (1.6 * x, r * 1.08, 1.6), 0.45, seg=10, rings=6, scale=(1.4, 0.5, 0.6)))
        for i in range(6):                                                     # the engine row at the back
            vis.append(box(m["rib"], (-5 + i * 2, -(rim + 0.5), zr - 0.3), (1.6, 1.2, 1.1)))
            vis.append(box(m["glow"], (-5 + i * 2, -(rim + 1.12), zr - 0.3), (1.1, 0.06, 0.6)))
        seams(m, r * 0.62, zr + 1.13, r * 0.97, zr + 0.78, 20, vis)
        rim_lights(m, rim + 0.04, zr, 24, n, vis)
        entry(m, r, rim, zr, n, vis)
        legs(m, rim, zr, vis, 4)

def plate_xy(mtl, pts, z0, z1):
    """A flat extruded polygon in XY (wings), z0..z1 thick."""
    me = bpy.data.meshes.new("plate")
    o = bpy.data.objects.new("plate", me)
    bpy.context.scene.collection.objects.link(o)
    bm = bmesh.new()
    lo = [bm.verts.new((x, y, z0)) for x, y in pts]
    hi = [bm.verts.new((x, y, z1)) for x, y in pts]
    bm.faces.new(lo[::-1])
    bm.faces.new(hi)
    for i in range(len(pts)):
        j = (i + 1) % len(pts)
        bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me); bm.free()
    o.data.materials.append(mtl)
    return o

def hull(m, r, h, segs, vis, scale_rim=1.3):
    """The saucer around the rooms: an underside sloping out to a sharp rim with lights,
    an upper hull rising back over the walls, a flat roof ring and a dome with a beacon."""
    n = segs * 2
    rim = r * scale_rim
    # the rim sits above the doorway (an earlier, lower rim cut across the door at head height)
    zr = h + 0.2
    door_gap = (0, n - 1)
    pts = [(r + 0.05, 0.4), (rim, zr), (rim + 0.06, zr + 0.22), (r + 0.15, zr + 0.85), (r * 0.55, zr + 1.15), (r * 0.32, zr + 1.7)]
    vis.append(band(m["hull"], pts[0][0], pts[0][1], pts[1][0], pts[1][1], n, skip=door_gap, name="Underside"))
    vis.append(band(m["dark"], pts[1][0], pts[1][1], pts[2][0], pts[2][1], n, skip=door_gap, name="RimEdge"))
    vis.append(band(m["hull"], pts[2][0], pts[2][1], pts[3][0], pts[3][1], n, name="UpperHull"))
    vis.append(band(m["rib"], pts[3][0], pts[3][1], pts[4][0], pts[4][1], n, name="Roof"))
    vis.append(band(m["hull"], pts[4][0], pts[4][1], pts[5][0], pts[5][1], n, name="Dome"))
    vis.append(cyl(m["rib"], (0, 0, pts[5][1] + 0.05), pts[5][0], 0.1, verts=n))
    vis.append(cyl(m["glow"], (0, 0, pts[5][1] + 0.35), 0.14, 0.55, verts=6, r2=0.03))   # beacon
    # dome windows
    for i in range(8):
        a = TAU * i / 8
        rr = (pts[4][0] + pts[5][0]) / 2
        vis.append(box(m["glow"], (math.cos(a) * rr * 1.02, math.sin(a) * rr * 1.02, (pts[4][1] + pts[5][1]) / 2), (0.5, 0.05, 0.18), rot=(0, 0, a + math.pi / 2)))
    for i in range(n):
        a = TAU * (i + 0.5) / n + math.pi / 2 - math.pi / n
        ca, sa = math.cos(a), math.sin(a)
        # rim lights all round (skipped over the door)
        if i not in door_gap:
            vis.append(box(m["glow"] if i % 2 == 0 else m["amber"], (ca * (rim + 0.09), sa * (rim + 0.09), zr + 0.11), (0.25, 0.05, 0.09), rot=(0, 0, a - math.pi / 2)))
        # ribs along the upper hull and the underside
        if i % 2 == 0:
            vis.append(beam(m["rib"], (ca * (pts[2][0] - 0.05), sa * (pts[2][0] - 0.05), pts[2][1] + 0.06), (ca * (pts[3][0] + 0.05), sa * (pts[3][0] + 0.05), pts[3][1] + 0.06), 0.14, 0.08))
            if i not in door_gap and (i + 1) % n not in door_gap and (i - 1) % n not in door_gap:
                vis.append(beam(m["dark"], (ca * (r + 0.15), sa * (r + 0.15), 0.42), (ca * (rim - 0.05), sa * (rim - 0.05), zr - 0.03), 0.12, 0.06))
    # violet seams running down the upper hull (0.52: the crown of blades is gone - Ari did not like it)
    for i in range(0, n, 2):
        a = TAU * (i + 0.5) / n + math.pi / 2 - math.pi / n
        ca, sa = math.cos(a), math.sin(a)
        vis.append(beam(m["glow"], (ca * (pts[2][0] - 0.02), sa * (pts[2][0] - 0.02), pts[2][1] + 0.12), (ca * (pts[3][0] + 0.08), sa * (pts[3][0] + 0.08), pts[3][1] + 0.12), 0.035, 0.03))
    # the entry recess: side plates from the wall out to the rim, a canopy over the door
    for i in (0, n - 1):
        side = 1 if i == 0 else 0
        a = TAU * (i + side) / n + math.pi / 2 - math.pi / n
        ca, sa = math.cos(a), math.sin(a)
        vis.append(tri_plate(m["dark"], [(ca * r, sa * r, 0.12), (ca * rim, sa * rim, zr), (ca * r, sa * r, zr)], "Cheek%d" % i))
    a0 = math.pi / 2 - math.pi / n * 2; a1 = math.pi / 2 + math.pi / n * 2
    vis.append(band(m["dark"], r, zr - 0.02, rim, zr - 0.02, n, skip=[k for k in range(n) if k not in door_gap], name="Canopy"))
    # landing legs (struts down from the underside) with pads
    for k in range(4):
        a = TAU * (k + 0.5) / 4 + math.pi / 2
        top = (math.cos(a) * rim * 0.82, math.sin(a) * rim * 0.82, zr * 0.75)
        foot = (math.cos(a) * rim * 0.98, math.sin(a) * rim * 0.98, 0.06)
        vis.append(beam(m["rib"], top, foot, 0.22, 0.22))
        vis.append(cyl(m["dark"], foot, 0.45, 0.1, verts=8))

def door(m, r, h, segs, vis, col):
    """Door frame, lintel over it, and a ramp down to the ground."""
    w = 2.0 * r * math.tan(math.pi / segs)
    vis.append(box(m["rib"], (-w / 2 - 0.1, r, 0.12 + (h + 0.1) / 2), (0.25, 0.5, h + 0.1)))
    vis.append(box(m["rib"], (w / 2 + 0.1, r, 0.12 + (h + 0.1) / 2), (0.25, 0.5, h + 0.1)))
    vis.append(box(m["rib"], (0, r, h + 0.25), (w + 0.4, 0.4, 0.15)))
    vis.append(box(m["glow"], (0, r + 0.21, h + 0.15), (w * 0.8, 0.03, 0.06)))
    # the hatch, slid up into the hull; amber threshold lights
    vis.append(box(m["hull"], (0, r - 0.05, h + 0.45), (w * 0.95, 0.08, 0.5)))
    for sx in (-1, 1):
        vis.append(box(m["amber"], (sx * w * 0.42, r + 0.05, 0.16), (0.12, 0.3, 0.04)))
    ramp_len = 2.4
    rp = box(m["hull"], (0, r + ramp_len / 2 - 0.1, 0.06), (w * 0.9, ramp_len, 0.1), rot=(-0.05, 0, 0))
    vis.append(rp)
    for k in range(5):
        vis.append(box(m["dark"], (0, r + 0.2 + k * 0.45, 0.12), (w * 0.8, 0.06, 0.02)))
    c = box(m["dark"], (0, r + ramp_len / 2 - 0.1, 0.06), (w * 0.9, ramp_len, 0.1), rot=(-0.05, 0, 0))
    c.name = "Ramp-colonly"
    col.append(c)

def floor_and_ceiling(m, r, h, segs, vis, col):
    vis.append(cyl(m["floor"], (0, 0, 0.06), r, 0.12, verts=segs))
    for k in range(segs):           # floor grooves
        a = seg_dir(k, segs)
        vis.append(box(m["dark"], (math.cos(a) * r * 0.5, math.sin(a) * r * 0.5, 0.125), (r * 0.95, 0.04, 0.01), rot=(0, 0, a)))
    vis.append(cyl(m["dark"], (0, 0, 0.145), r * 0.35, 0.01, verts=segs))
    c = cyl(m["dark"], (0, 0, 0.06), r, 0.12, verts=segs)
    c.name = "Floor-colonly"
    col.append(c)
    vis.append(cyl(m["wall"], (0, 0, h + 0.17), r, 0.1, verts=segs))           # ceiling
    vis.append(cyl(m["glow"], (0, 0, h + 0.1), r * 0.2, 0.04, verts=segs))      # ceiling light

def build(kind):
    reset(); m = M(); vis = []; col = []
    if kind == "scout":
        r, h, segs = 5.0, 2.5, 12
        hull2("scout", m, r, h, segs, vis)
        floor_and_ceiling(m, r, h, segs, vis, col)
        wall_ring(m, r, h, segs, (0,), vis, col, "Wall")
        door(m, r, h, segs, vis, col)
        core(m, (0, -1.0, 0.12), 0.7, vis, col)
        console(m, (-2.2, 0.8, 0.12), 0.6, vis); console(m, (2.2, 0.8, 0.12), -0.6, vis)
        seat(m, (-1.6, 1.4, 0.12), 0.6, vis); seat(m, (1.6, 1.4, 0.12), -0.6, vis)
        for n, p in (("Spawn_0", (1.8, -1.5)), ("Spawn_1", (-1.8, -1.2)), ("Way_0", (0, 2.5)), ("Way_1", (-2.5, -2.5)), ("Way_2", (2.5, -2.5))):
            empty(n, (p[0], p[1], 0.3))
        empty("Light_0", (0, 0, 2.0))
    elif kind == "raider":
        r, h, segs = 7.0, 2.6, 16
        hull2("raider", m, r, h, segs, vis)
        floor_and_ceiling(m, r, h, segs, vis, col)
        wall_ring(m, r, h, segs, (0,), vis, col, "Wall")
        door(m, r, h, segs, vis, col)
        # inner wall across the ship with a door: entry hall (front, +Y) and navigation (back)
        for k, (x0, x1) in enumerate(((-6.8, -0.8), (0.8, 6.8))):
            cx = (x0 + x1) / 2
            vis.append(box(m["wall"], (cx, 0.5, 0.12 + h / 2), (x1 - x0, 0.25, h)))
            c = box(m["dark"], (cx, 0.5, 0.12 + h / 2), (x1 - x0, 0.25, h)); c.name = "Inner_%d-colonly" % k; col.append(c)
        vis.append(box(m["glow"], (0, 0.5, 2.3), (1.6, 0.3, 0.1)))
        core(m, (0, -3.5, 0.12), 0.9, vis, col)
        for a in (-0.9, 0.0, 0.9):
            console(m, (math.sin(a) * 4.6, -2.4 - math.cos(a) * 1.2, 0.12), a, vis)
        seat(m, (-2.5, -1.6, 0.12), 0.4, vis); seat(m, (2.5, -1.6, 0.12), -0.4, vis)
        for x in (-4.0, 4.0):      # storage pods in the entry hall
            vis.append(cyl(m["rib"], (x, 3.2, 0.9), 0.5, 1.6, verts=8, r2=0.35))
            vis.append(cyl(m["amber"], (x, 3.2, 1.75), 0.2, 0.1, verts=8))
            c = cyl(m["dark"], (x, 3.2, 0.9), 0.5, 1.6, verts=8); c.name = "Pod_%d-colonly" % int(x); col.append(c)
        for n, p in (("Spawn_0", (2.5, -4.5)), ("Spawn_1", (-2.5, -4.5)), ("Spawn_2", (3.5, 2.5)), ("Spawn_3", (-1.5, 4.5)),
                     ("Way_0", (0, 4.0)), ("Way_1", (0, -2.0)), ("Way_2", (-4.0, -3.0)), ("Way_3", (4.0, -3.0))):
            empty(n, (p[0], p[1], 0.3))
        empty("Light_0", (0, 3.0, 2.1)); empty("Light_1", (0, -3.0, 2.1))
    else:   # harvester
        r, h, segs = 10.0, 2.8, 20
        hull2("harvester", m, r, h, segs, vis)
        floor_and_ceiling(m, r, h, segs, vis, col)
        wall_ring(m, r, h, segs, (0,), vis, col, "Wall")
        door(m, r, h, segs, vis, col)
        # the core hall in the middle, four doors
        wall_ring(m, 4.0, h, 12, (0, 3, 6, 9), vis, col, "Hall", thick=0.25)
        core(m, (0, 0, 0.12), 1.2, vis, col)
        # radial walls split the ring into rooms (each with a doorway)
        for k, a in enumerate((math.pi / 4, 3 * math.pi / 4, 5 * math.pi / 4, 7 * math.pi / 4)):
            radial_wall(m, 4.1, 9.85, a, h, vis, col, "Radial%d" % k, door=True)
        # rooms: navigation (back), engines (left / right), crew (front)
        for a in (-0.5, 0.0, 0.5):
            console(m, (math.sin(a) * 7.0, -math.cos(a) * 7.0, 0.12), a, vis)
        for sx in (-1, 1):
            for k in range(2):
                ex, ey = sx * 7.2, -1.5 + k * 3.0
                vis.append(cyl(m["rib"], (ex, ey, 1.3), 0.8, 2.4, verts=10, r2=0.6))
                vis.append(cyl(m["glow"], (ex, ey, 1.3), 0.82, 0.3, verts=10))
                c = cyl(m["dark"], (ex, ey, 1.3), 0.8, 2.4, verts=10); c.name = "Engine%d%d-colonly" % (sx + 1, k); col.append(c)
        for k in range(4):
            seat(m, (-2.0 + k * 1.3, 7.0, 0.12), math.pi / 2, vis)
        # a specimen tank in the crew room: something human-shaped floating in it
        vis.append(cyl(m["rib"], (4.5, 6.0, 0.25), 0.7, 0.3, verts=10))
        vis.append(cyl(mat("UfoTank", (0.2, 0.6, 0.4), emit=0.8, rough=0.1), (4.5, 6.0, 1.3), 0.6, 1.9, verts=10))
        vis.append(box(m["flesh"], (4.5, 6.0, 1.3), (0.35, 0.2, 1.2)))
        c = cyl(m["dark"], (4.5, 6.0, 1.2), 0.7, 2.2, verts=10); c.name = "Tank-colonly"; col.append(c)
        sp = [(0, 6.5), (6.5, 3.5), (-6.5, 3.5), (6.0, -5.0), (-6.0, -5.0), (0, -7.5), (2.0, 2.5), (-2.5, -2.0)]
        for i, p in enumerate(sp):
            empty("Spawn_%d" % i, (p[0], p[1], 0.3))
        for i, p in enumerate([(0, 8.5), (0, 3.2), (6.0, 6.0), (-6.0, 6.0), (7.5, -4.0), (-7.5, -4.0), (0, -6.5), (3.2, 0), (-3.2, 0)]):
            empty("Way_%d" % i, (p[0], p[1], 0.3))
        for i, p in enumerate([(0, 0), (0, 7), (6, -4), (-6, -4)]):
            empty("Light_%d" % i, (p[0], p[1], 2.2))
    body = join(vis, "Hull")
    objs = [body] + col + [o for o in bpy.context.scene.objects if o.type == 'EMPTY']
    export_glb(os.path.join(OUTDIR, "ufo_g_%s.glb" % kind), objs)
    if "--preview" in sys.argv:
        for c in col:
            c.hide_render = True
        preview(os.path.join(os.path.dirname(__file__), "..", "ufo_%s_prev.png" % kind), target=(0, 0, 1.5), dist=r * 3.2, angle=0.5, height=r * 0.9, res=(560, 400))
        # inside: from the doorway, lit by the violet lights
        for o in bpy.context.scene.objects:
            if o.type == 'EMPTY' and o.name.startswith("Light_"):
                ld = bpy.data.lights.new(o.name + "L", 'POINT'); ld.energy = 300; ld.color = (0.75, 0.55, 1.0)
                lo = bpy.data.objects.new(o.name + "L", ld); lo.location = o.location; bpy.context.scene.collection.objects.link(lo)
        cd = bpy.data.cameras.new("In"); cd.lens = 18
        co = bpy.data.objects.new("In", cd); bpy.context.scene.collection.objects.link(co)
        co.location = (0.3, r + 1.2, 1.6)
        co.rotation_euler = (Vector((0, -2.0, 1.0)) - Vector(co.location)).to_track_quat('-Z', 'Y').to_euler()
        sc = bpy.context.scene; sc.camera = co
        sc.render.filepath = os.path.join(os.path.dirname(__file__), "..", "ufo_%s_in.png" % kind)
        bpy.ops.render.render(write_still=True)

if __name__ == "__main__":
    for k in ("scout", "raider", "harvester"):
        build(k)
