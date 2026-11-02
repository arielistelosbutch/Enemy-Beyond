"""Enemy Beyond alien roster + civilians. Own designs (inspired only by the
roles in the old game, nothing copied). Rigid-skinned, low-poly, PS1 style.

    python aliens.py <creature> out.glb [--preview <action> <frame> <png> <angle>]

creatures: lihnoun, hlidac, knez, civ_a, civ_b, zombie, ohar, trojnozec, meduza
Humanoids get the actions idle, walk, run, lurk, aim, attack (civilians: cower).
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from common import *
from common import _finish

KIND = sys.argv[1] if len(sys.argv) > 1 else "lihnoun"
OUT = sys.argv[-1] if sys.argv[-1].endswith(".glb") else KIND + ".glb"
reset()

# ---------------------------------------------------------------------------------------
# generic humanoid rig
def humanoid_bones(hip, chest, neck, head, sx, hx, knee, ankle, elbow, wrist, lean=0.0):
    B = {
        "root": ((0, 0, 0), (0, 0, 0.25), None),
        "hips": ((0, 0, hip), (0, 0, hip + 0.1), "root"),
        "spine": ((0, 0, hip + 0.1), (0, lean, chest), "hips"),
        "neck": ((0, lean, chest), (0, lean * 1.4, neck), "spine"),
        "head": ((0, lean * 1.4, neck), (0, lean * 1.6, head), "neck"),
    }
    for s, x in (("L", 1), ("R", -1)):
        B["thigh." + s] = ((hx * x, 0, hip), (hx * x, 0, knee), "hips")
        B["shin." + s] = ((hx * x, 0, knee), (hx * x, 0, ankle), "thigh." + s)
        B["upperarm." + s] = ((sx * x, lean, chest - 0.04), (sx * 1.08 * x, lean, elbow), "spine")
        B["forearm." + s] = ((sx * 1.08 * x, lean, elbow), (sx * 1.12 * x, lean, wrist), "upperarm." + s)
        B["hand." + s] = ((sx * 1.12 * x, lean, wrist), (sx * 1.12 * x, lean, wrist - 0.1), "forearm." + s)
    return B

def make_rig(name, B):
    arm_data = bpy.data.armatures.new(name + "Rig")
    rig = bpy.data.objects.new(name + "Rig", arm_data)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='EDIT')
    for n, (h, t, parent) in B.items():
        eb = arm_data.edit_bones.new(n)
        eb.head, eb.tail = h, t
        eb.roll = 0
    for n, (h, t, parent) in B.items():
        if parent:
            arm_data.edit_bones[n].parent = arm_data.edit_bones[parent]
            arm_data.edit_bones[n].use_connect = False
    bpy.ops.object.mode_set(mode='OBJECT')
    for b in rig.pose.bones:
        b.rotation_mode = 'XYZ'
    return rig

def bind(rig, parts, name):
    body = join(parts, name)
    mod = body.modifiers.new("Armature", 'ARMATURE')
    mod.object = rig
    body.parent = rig
    return body

def action(rig, name, frames):
    pb = rig.pose.bones
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = act
    for f, rots, hz in frames:
        for b in pb:
            b.rotation_euler = (0, 0, 0)
            b.location = (0, 0, 0)
        for n, r in rots.items():
            if n in pb:
                pb[n].rotation_euler = r
        pb["root"].location = (0, hz, 0)  # root points up: local Y = world Z
        for b in pb:
            b.keyframe_insert("rotation_euler", frame=f)
            b.keyframe_insert("location", frame=f)
    for fc in getattr(act, "fcurves", []):
        for k in fc.keyframe_points:
            k.interpolation = 'LINEAR'
    rig.animation_data.action = None
    return act

# limbs pointing down: +X swings forward. spine/neck/head point up: -X bends forward.
def walk_frames(n, amp, arm, bob, base=None, spine=-0.12, knee=1.2, arm_base=(0.25, 0.25)):
    out = []
    for i in range(5):
        f = 1 + i * n // 4
        ph = i / 4 * 2 * math.pi
        sw = math.sin(ph)
        r = {
            "thigh.L": (-sw * amp, 0, 0), "thigh.R": (sw * amp, 0, 0),
            "shin.L": (-max(0, -sw) * amp * knee, 0, 0), "shin.R": (-max(0, sw) * amp * knee, 0, 0),
            "upperarm.L": (sw * arm, 0, 0.05), "upperarm.R": (-sw * arm, 0, -0.05),
            "forearm.L": (arm_base[0], 0, 0), "forearm.R": (arm_base[1], 0, 0),
            "spine": (spine, 0, sw * 0.08), "head": (-spine * 0.6, sw * 0.05, 0),
        }
        if base:
            for k, v in base.items():
                if k in r and k.startswith(("thigh", "shin")):
                    r[k] = (r[k][0] + v[0], r[k][1] + v[1], r[k][2] + v[2])
                elif k not in r or not k.startswith(("thigh", "shin")):
                    r[k] = v
        out.append((f, r, -abs(math.cos(ph)) * bob))
    return out

def finish(objs, rig=None, target=(0, 0, 0.8), dist=3.0):
    if "--preview" in sys.argv:
        i = sys.argv.index("--preview")
        if rig is not None and sys.argv[i + 1] != "-":
            rig.animation_data_create()
            rig.animation_data.action = bpy.data.actions[sys.argv[i + 1]]
            bpy.context.scene.frame_set(int(sys.argv[i + 2]))
        preview(sys.argv[i + 3], target=target, dist=dist, angle=float(sys.argv[i + 4]))
    else:
        export_glb(OUT, objs, animations=rig is not None)

# ---------------------------------------------------------------------------------------
def limb(material, a, b, r1, r2, verts=7, group=None):
    """A tapered cylinder from point a to point b (radius r1 at a, r2 at b)."""
    a = Vector(a); b = Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=d.length)
    o = bpy.context.active_object
    rot = d.to_track_quat('Z', 'Y').to_euler()
    return _finish(o, material, (a + b) / 2, rot, (1, 1, 1), group)

def lihnoun():
    """Líhnoun - a heavy, near-black predator. Deep chest under overlapping
    plates and spines, digitigrade legs that coil like springs, long arms that
    end in two hooked claws, a long skull split by a mouth full of needles.
    When it runs, it runs on all fours."""
    chit = mat("LihChitin", (0.055, 0.05, 0.065), rough=0.3)
    plate = mat("LihPlate", (0.11, 0.1, 0.12), rough=0.25)
    flesh = mat("LihFlesh", (0.09, 0.012, 0.02), rough=0.6)
    tooth = mat("LihTooth", (0.62, 0.58, 0.5), rough=0.4)
    eye = mat("LihEye", (0.55, 0.05, 0.03), emit=0.7)
    B = humanoid_bones(hip=0.95, chest=1.5, neck=1.62, head=1.9, sx=0.24, hx=0.15, knee=0.52, ankle=0.06, elbow=1.12, wrist=0.84, lean=0.12)
    rig = make_rig("Lih", B)
    p = []
    # --- pelvis, belly, tail
    p.append(sphere(chit, (0, -0.02, 0.95), 0.17, seg=10, rings=7, scale=(1.25, 1.0, 0.8), group="hips"))
    p.append(limb(chit, (0, -0.15, 0.95), (0, -0.55, 0.82), 0.1, 0.06, group="hips"))
    p.append(limb(chit, (0, -0.55, 0.82), (0, -0.9, 0.55), 0.06, 0.035, group="hips"))
    p.append(limb(plate, (0, -0.9, 0.55), (0, -1.08, 0.5), 0.035, 0.0, verts=4, group="hips"))
    for i in range(3):
        p.append(limb(plate, (0, -0.2 - i * 0.18, 1.0 - i * 0.07), (0, -0.28 - i * 0.18, 1.12 - i * 0.07), 0.035, 0.0, verts=4, group="hips"))
    # --- chest: a deep keel, ribs and armour plates, a ridge of spines
    p.append(limb(chit, (0, 0.0, 1.0), (0, 0.06, 1.18), 0.13, 0.17, verts=8, group="spine"))
    p.append(sphere(chit, (0, 0.1, 1.33), 0.24, seg=10, rings=8, scale=(1.05, 0.95, 1.2), group="spine"))
    p.append(limb(plate, (0, 0.26, 1.12), (0, 0.32, 1.45), 0.05, 0.09, verts=5, group="spine"))
    for i in range(4):
        z = 1.16 + i * 0.09
        p.append(box(plate, (0, -0.06, z), (0.46 - i * 0.03, 0.22, 0.07), rot=(0.25, 0, 0), group="spine"))
        for x in (1, -1):
            p.append(limb(flesh, (0.2 * x, 0.12, z - 0.02), (0.13 * x, 0.27, z - 0.06), 0.02, 0.015, verts=4, group="spine"))
    for i in range(6):
        z = 1.08 + i * 0.09
        h = 0.14 + (0.16 if 2 <= i <= 4 else 0.06)
        p.append(limb(plate, (0, -0.14 + i * 0.01, z), (0, -0.2 - h * 0.9, z + h * 0.5), 0.04, 0.0, verts=4, group="spine"))
    # --- neck: thick, low, armoured
    p.append(limb(chit, (0, 0.14, 1.48), (0, 0.24, 1.68), 0.12, 0.09, verts=8, group="neck"))
    p.append(limb(plate, (0, 0.06, 1.56), (0, -0.12, 1.74), 0.035, 0.0, verts=4, group="neck"))
    # --- head: a long skull, jaws slightly open, a crown of swept horns
    sk = sphere(chit, (0, 0.42, 1.76), 0.15, seg=10, rings=8, scale=(0.78, 1.75, 0.72), group="head")
    p.append(sk)
    p.append(box(plate, (0, 0.38, 1.85), (0.2, 0.36, 0.06), rot=(-0.12, 0, 0), group="head"))
    for x in (1, -1):
        p.append(limb(plate, (0.07 * x, 0.25, 1.86), (0.16 * x, -0.12, 2.0), 0.035, 0.0, verts=4, group="head"))
        p.append(limb(plate, (0.04 * x, 0.3, 1.88), (0.07 * x, 0.0, 2.08), 0.03, 0.0, verts=4, group="head"))
        for k in range(2):
            p.append(sphere(eye, (0.1 * x, 0.5 - k * 0.07, 1.8 - k * 0.015), 0.018 - k * 0.004, seg=6, rings=4, group="head"))
    # lower jaw, hanging a little open
    p.append(box(chit, (0, 0.47, 1.57), (0.17, 0.4, 0.06), rot=(0.38, 0, 0), group="head"))
    p.append(box(flesh, (0, 0.44, 1.67), (0.14, 0.36, 0.05), rot=(0.1, 0, 0), group="head"))
    for i in range(7):
        y = 0.3 + i * 0.05
        for x in (1, -1):
            p.append(limb(tooth, (0.065 * x, y, 1.72), (0.06 * x, y + 0.015, 1.63), 0.012, 0.0, verts=3, group="head"))
            p.append(limb(tooth, (0.06 * x, y + 0.02, 1.58 - (y - 0.3) * 0.12), (0.058 * x, y + 0.03, 1.65 - (y - 0.3) * 0.1), 0.011, 0.0, verts=3, group="head"))
    p.append(limb(tooth, (0.02, 0.63, 1.71), (0.0, 0.66, 1.63), 0.014, 0.0, verts=3, group="head"))
    p.append(limb(tooth, (-0.02, 0.63, 1.71), (0.0, 0.66, 1.63), 0.014, 0.0, verts=3, group="head"))
    for sd, x in (("L", 1), ("R", -1)):
        # --- arms: heavy shoulders, long forearms, two hooked claws
        p.append(sphere(plate, (0.25 * x, 0.12, 1.46), 0.11, seg=8, rings=6, scale=(1.1, 1.2, 0.9), group="upperarm." + sd))
        p.append(limb(chit, (0.25 * x, 0.12, 1.46), (0.26 * x, 0.12, 1.12), 0.085, 0.06, group="upperarm." + sd))
        p.append(sphere(chit, (0.26 * x, 0.12, 1.12), 0.065, seg=7, rings=5, group="forearm." + sd))
        p.append(limb(chit, (0.26 * x, 0.12, 1.12), (0.27 * x, 0.12, 0.84), 0.06, 0.045, group="forearm." + sd))
        p.append(limb(plate, (0.27 * x, 0.06, 1.1), (0.28 * x, -0.12, 1.24), 0.03, 0.0, verts=4, group="forearm." + sd))
        p.append(sphere(chit, (0.27 * x, 0.12, 0.84), 0.05, seg=7, rings=5, group="hand." + sd))
        for c in (-1, 1):
            cx = 0.27 * x + c * 0.035
            p.append(limb(plate, (cx, 0.13, 0.82), (cx, 0.2, 0.58), 0.03, 0.02, verts=5, group="hand." + sd))
            p.append(limb(tooth, (cx, 0.2, 0.58), (cx, 0.36, 0.5), 0.02, 0.0, verts=4, group="hand." + sd))
        # --- legs: thick thighs, a long backward hock, splayed clawed feet
        p.append(sphere(chit, (0.15 * x, 0.0, 0.93), 0.11, seg=8, rings=6, group="thigh." + sd))
        p.append(limb(chit, (0.15 * x, 0.0, 0.93), (0.16 * x, 0.1, 0.52), 0.11, 0.07, group="thigh." + sd))
        p.append(sphere(plate, (0.16 * x, 0.12, 0.52), 0.075, seg=7, rings=5, group="shin." + sd))
        p.append(limb(chit, (0.16 * x, 0.1, 0.52), (0.16 * x, -0.12, 0.22), 0.065, 0.045, group="shin." + sd))
        p.append(sphere(chit, (0.16 * x, -0.12, 0.22), 0.045, seg=6, rings=4, group="shin." + sd))
        p.append(limb(chit, (0.16 * x, -0.12, 0.22), (0.16 * x, 0.02, 0.05), 0.045, 0.04, group="shin." + sd))
        p.append(limb(plate, (0.16 * x, -0.12, 0.22), (0.16 * x, -0.24, 0.3), 0.025, 0.0, verts=4, group="shin." + sd))
        for c in (-1, 0, 1):
            p.append(limb(plate, (0.16 * x, 0.02, 0.05), (0.16 * x + c * 0.08, 0.22, 0.02), 0.03, 0.0, verts=4, group="shin." + sd))
        p.append(limb(plate, (0.16 * x, 0.0, 0.05), (0.16 * x, -0.12, 0.01), 0.022, 0.0, verts=4, group="shin." + sd))
    body = bind(rig, p, "Lihnoun")
    # --- animation: a predator, not a puppet. Weight low, head level, claws ready.
    stance = {"spine": (-0.6, 0, 0), "neck": (0.25, 0, 0), "head": (0.45, 0, 0),
              "thigh.L": (0.75, 0, 0.12), "thigh.R": (0.75, 0, -0.12), "shin.L": (-0.95, 0, 0), "shin.R": (-0.95, 0, 0),
              "upperarm.L": (0.85, 0, 0.18), "upperarm.R": (0.85, 0, -0.18), "forearm.L": (0.75, 0, 0), "forearm.R": (0.75, 0, 0),
              "hand.L": (-0.2, 0, 0), "hand.R": (-0.2, 0, 0)}
    def var(d, **kw):
        o = dict(d)
        for k, v in kw.items():
            o[k.replace("_", ".")] = v
        return o
    breath_in = var(stance, spine=(-0.56, 0, 0), head=(0.42, 0, 0))
    look = var(stance, head=(0.5, 0.25, 0.55), neck=(0.3, 0, 0.15))
    twitch = var(stance, hand_L=(-0.6, 0, 0), forearm_L=(1.0, 0, 0))
    action(rig, "idle", [(1, stance, -0.2), (17, breath_in, -0.18), (33, stance, -0.2), (39, look, -0.2), (45, look, -0.2),
                         (49, twitch, -0.2), (53, stance, -0.2), (69, breath_in, -0.18), (85, stance, -0.2)])
    # walk: a slow stalk, shoulders rolling, head steady
    def stalk(n):
        out = []
        for i in range(5):
            f = 1 + i * n // 4
            ph = i / 4 * 2 * math.pi
            sw = math.sin(ph)
            r = dict(stance)
            r["thigh.L"] = (0.75 - sw * 0.45, 0, 0.12); r["thigh.R"] = (0.75 + sw * 0.45, 0, -0.12)
            r["shin.L"] = (-0.95 - max(0, sw) * 0.5, 0, 0); r["shin.R"] = (-0.95 - max(0, -sw) * 0.5, 0, 0)
            r["upperarm.L"] = (0.85 + sw * 0.35, 0, 0.18); r["upperarm.R"] = (0.85 - sw * 0.35, 0, -0.18)
            r["spine"] = (-0.62, 0, sw * 0.12); r["head"] = (0.47, 0, -sw * 0.1)
            out.append((f, r, -0.2 - abs(math.cos(ph)) * 0.03))
        return out
    action(rig, "walk", stalk(28))
    # run: on all fours. Arms reach and pull like front legs, back arches and stretches
    def gallop(n):
        out = []
        for i in range(5):
            f = 1 + i * n // 4
            ph = i / 4 * 2 * math.pi
            sw = math.sin(ph); cw = math.cos(ph)
            r = {"spine": (-1.25 + sw * 0.12, 0, 0), "neck": (0.45, 0, 0), "head": (0.75 - sw * 0.1, 0, 0),
                 "thigh.L": (0.9 - sw * 0.75, 0, 0.1), "thigh.R": (0.9 - sw * 0.65, 0, -0.1),
                 "shin.L": (-1.0 - max(0, sw) * 0.7, 0, 0), "shin.R": (-1.0 - max(0, sw) * 0.6, 0, 0),
                 "upperarm.L": (1.0 + sw * 0.8, 0, 0.15), "upperarm.R": (1.0 + sw * 0.7, 0, -0.15),
                 "forearm.L": (0.2 + max(0, -sw) * 0.9, 0, 0), "forearm.R": (0.2 + max(0, -sw) * 0.8, 0, 0),
                 "hand.L": (0.4, 0, 0), "hand.R": (0.4, 0, 0)}
            out.append((f, r, -0.42 + cw * 0.07))
        return out
    action(rig, "run", gallop(12))
    # lurk: flattened to the ground, head low, utterly still but for a breath
    lurk = {"spine": (-1.2, 0, 0), "neck": (0.5, 0, 0), "head": (0.75, 0, 0),
            "thigh.L": (1.45, 0, 0.35), "thigh.R": (1.45, 0, -0.35), "shin.L": (-1.85, 0, 0), "shin.R": (-1.85, 0, 0),
            "upperarm.L": (1.35, 0, 0.3), "upperarm.R": (1.35, 0, -0.3), "forearm.L": (1.2, 0, 0), "forearm.R": (1.2, 0, 0),
            "hand.L": (-0.5, 0, 0), "hand.R": (-0.5, 0, 0)}
    action(rig, "lurk", [(1, lurk, -0.52), (25, var(lurk, spine=(-1.16, 0, 0)), -0.51), (49, lurk, -0.52)])
    # attack: rear up, both claws high, slam down and rake
    rear = var(stance, spine=(-0.15, 0, 0), neck=(0.0, 0, 0), head=(0.1, 0, 0),
               upperarm_L=(2.7, 0, 0.35), upperarm_R=(2.7, 0, -0.35), forearm_L=(0.7, 0, 0), forearm_R=(0.7, 0, 0),
               hand_L=(-0.7, 0, 0), hand_R=(-0.7, 0, 0))
    slam = var(stance, spine=(-1.05, 0, 0), head=(0.8, 0, 0), neck=(0.4, 0, 0),
               upperarm_L=(1.1, 0, 0.05), upperarm_R=(1.1, 0, -0.05), forearm_L=(0.05, 0, 0), forearm_R=(0.05, 0, 0),
               hand_L=(0.6, 0, 0), hand_R=(0.6, 0, 0))
    action(rig, "attack", [(1, stance, -0.2), (5, rear, -0.05), (8, slam, -0.32), (12, var(slam, upperarm_L=(0.6, 0, 0.1)), -0.3), (17, stance, -0.2)])
    action(rig, "aim", [(1, rear, -0.05), (13, var(rear, head=(0.2, 0.2, 0.25)), -0.06), (25, rear, -0.05)])
    finish([rig, body], rig, target=(0, 0.2, 0.8), dist=3.0)

# ---------------------------------------------------------------------------------------
def soldier_anims(rig, two_handed=True, scale=1.0):
    walk = walk_frames(32, 0.42, 0.25, 0.025 * scale)
    action(rig, "idle", [
        (1, {"spine": (-0.03, 0, 0), "forearm.L": (0.3, 0, 0), "forearm.R": (0.6, 0, 0), "upperarm.R": (0.4, 0, 0)}, 0),
        (25, {"spine": (-0.06, 0, 0.05), "head": (0, 0.1, 0.2), "forearm.L": (0.35, 0, 0), "forearm.R": (0.6, 0, 0), "upperarm.R": (0.42, 0, 0)}, -0.01 * scale),
        (49, {"spine": (-0.03, 0, 0), "forearm.L": (0.3, 0, 0), "forearm.R": (0.6, 0, 0), "upperarm.R": (0.4, 0, 0)}, 0)])
    action(rig, "walk", walk)
    action(rig, "run", walk_frames(18, 0.75, 0.0, 0.05 * scale, base={"upperarm.R": (0.5, 0, 0), "forearm.R": (0.9, 0, 0), "upperarm.L": (0.5, 0, 0.3), "forearm.L": (1.0, 0, 0)}, spine=-0.25))
    lurk = {"thigh.L": (1.2, 0, 0.1), "thigh.R": (0.4, 0, -0.1), "shin.L": (-1.6, 0, 0), "shin.R": (-1.9, 0, 0),
            "spine": (-0.35, 0, 0), "head": (0.25, 0, 0), "upperarm.R": (0.7, 0, 0), "forearm.R": (0.7, 0, 0), "upperarm.L": (0.7, 0, 0.3), "forearm.L": (0.8, 0, 0)}
    action(rig, "lurk", [(1, lurk, -0.3 * scale), (21, dict(lurk, head=(0.2, 0.2, 0.2)), -0.31 * scale), (41, lurk, -0.3 * scale)])
    aim = {"upperarm.R": (1.45, 0, 0.1), "forearm.R": (0.1, 0, 0), "spine": (-0.05, 0, -0.15), "head": (0, 0, -0.1),
           "upperarm.L": (1.3, 0, -0.45) if two_handed else (-0.1, 0, 0.1), "forearm.L": (0.35, 0, 0) if two_handed else (0.3, 0, 0),
           "thigh.L": (0.25, 0, 0), "thigh.R": (-0.2, 0, 0), "shin.L": (-0.3, 0, 0)}
    action(rig, "aim", [(1, aim, -0.02), (13, dict(aim, spine=(-0.08, 0, -0.18)), -0.03), (25, aim, -0.02)])
    action(rig, "attack", [(1, aim, -0.02), (7, dict(aim, **{"upperarm.R": (1.6, 0, 0)}), -0.04), (13, aim, -0.02)])

def hlidac():
    """Hlídač - the heavy guard of the bigger ships. Broad, armoured, slow to
    die. A heavy plasma carbine in both hands."""
    armor = mat("HliArmor", (0.16, 0.19, 0.12), rough=0.5)
    armor2 = mat("HliArmor2", (0.09, 0.1, 0.08), rough=0.5)
    skin = mat("HliSkin", (0.26, 0.3, 0.2), rough=0.7)
    visor = mat("HliVisor", (1.0, 0.45, 0.1), emit=2.5)
    gun = mat("HliGun", (0.2, 0.21, 0.19), rough=0.4)
    glow = mat("PlasmaGlow", (0.35, 1.0, 0.45), emit=4.0)
    B = humanoid_bones(hip=1.05, chest=1.62, neck=1.72, head=2.0, sx=0.36, hx=0.15, knee=0.58, ankle=0.1, elbow=1.3, wrist=1.02)
    rig = make_rig("Hli", B)
    p = []
    p.append(sphere(skin, (0, 0.02, 1.86), 0.15, seg=8, rings=6, scale=(1.0, 1.05, 1.0), group="head"))
    p.append(box(armor, (0, 0.0, 1.9), (0.3, 0.32, 0.22), group="head"))
    p.append(box(visor, (0, 0.165, 1.86), (0.24, 0.02, 0.04), group="head"))
    p.append(box(armor2, (0, 0.13, 1.76), (0.16, 0.08, 0.1), group="head"))
    p.append(cyl(skin, (0, 0, 1.68), 0.09, 0.12, verts=6, group="neck"))
    p.append(box(armor, (0, 0.02, 1.42), (0.56, 0.36, 0.44), group="spine"))
    p.append(box(armor2, (0, 0.2, 1.4), (0.36, 0.06, 0.32), group="spine"))
    p.append(box(armor2, (0, -0.2, 1.48), (0.4, 0.1, 0.36), group="spine"))
    p.append(box(armor2, (0, 0, 1.12), (0.4, 0.28, 0.18), group="hips"))
    for sd, x in (("L", 1), ("R", -1)):
        p.append(sphere(armor, (0.36 * x, 0, 1.6), 0.13, seg=6, rings=4, scale=(1.1, 1, 0.8), group="upperarm." + sd))
        p.append(cyl(skin, (0.38 * x, 0, 1.44), 0.08, 0.3, verts=6, r2=0.07, group="upperarm." + sd))
        p.append(cyl(armor, (0.395 * x, 0, 1.16), 0.085, 0.28, verts=6, r2=0.07, group="forearm." + sd))
        p.append(box(skin, (0.4 * x, 0.02, 0.98), (0.1, 0.12, 0.12), group="hand." + sd))
        p.append(cyl(armor, (0.15 * x, 0, 0.82), 0.12, 0.46, verts=6, r2=0.1, group="thigh." + sd))
        p.append(cyl(armor2, (0.15 * x, 0, 0.36), 0.09, 0.48, verts=6, r2=0.08, group="shin." + sd))
        p.append(box(armor, (0.15 * x, 0.06, 0.05), (0.16, 0.3, 0.1), group="shin." + sd))
    g = "hand.R"
    # the carbine lies along the hand (pointing down the arm), so a raised arm aims it
    p.append(box(gun, (-0.4, 0.04, 0.7), (0.1, 0.12, 0.56), group=g))
    p.append(cyl(gun, (-0.4, 0.04, 0.36), 0.04, 0.16, verts=6, group=g))
    p.append(box(glow, (-0.4, 0.11, 0.66), (0.03, 0.02, 0.3), group=g))
    p.append(box(gun, (-0.4, -0.06, 0.92), (0.06, 0.12, 0.08), group=g))
    body = bind(rig, p, "Hlidac")
    soldier_anims(rig, True, 1.3)
    finish([rig, body], rig, target=(0, 0, 1.0), dist=3.6)

def knez():
    """Kněz - the leader. Tall, robed, a crown-like crest of bone. It does not
    need a gun: it reaches into the minds of the mercenaries."""
    robe = mat("KneRobe", (0.07, 0.05, 0.09), rough=0.9)
    robe2 = mat("KneRobe2", (0.18, 0.12, 0.22), rough=0.8)
    skin = mat("KneSkin", (0.62, 0.62, 0.66), rough=0.5)
    gem = mat("KneGem", (0.75, 0.3, 1.0), emit=3.0)
    eye = mat("KneEye", (0.01, 0.01, 0.015), rough=0.05)
    B = humanoid_bones(hip=0.95, chest=1.5, neck=1.62, head=2.0, sx=0.2, hx=0.1, knee=0.52, ankle=0.08, elbow=1.22, wrist=0.95)
    rig = make_rig("Kne", B)
    p = []
    h = sphere(skin, (0, 0.03, 1.8), 0.17, seg=10, rings=8, scale=(0.95, 1.0, 1.35), group="head")
    p.append(h)
    for i, a in enumerate((-0.6, -0.3, 0, 0.3, 0.6)):
        p.append(cyl(skin, (math.sin(a) * 0.12, -0.03 + abs(a) * 0.05, 2.0 - abs(a) * 0.08), 0.03, 0.22 - abs(a) * 0.1, verts=4, r2=0.0, rot=(-0.4, a * 0.8, 0), group="head"))
    p.append(sphere(gem, (0, 0.17, 1.9), 0.025, seg=6, rings=4, group="head"))
    for x in (1, -1):
        p.append(sphere(eye, (0.062 * x, 0.15, 1.78), 0.055, seg=8, rings=6, scale=(1.5, 0.5, 0.75), rot=(0, 0.5 * x, 0.3 * x), group="head"))
    p.append(cyl(skin, (0, 0, 1.58), 0.04, 0.12, verts=6, group="neck"))
    # robe: shoulders cape + long skirt hiding the legs
    p.append(cyl(robe2, (0, 0, 1.45), 0.26, 0.16, verts=8, r2=0.1, group="spine"))
    p.append(cyl(robe, (0, 0, 1.2), 0.15, 0.5, verts=8, r2=0.2, group="spine"))
    p.append(box(gem, (0, 0.16, 1.3), (0.04, 0.02, 0.1), group="spine"))
    p.append(cyl(robe, (0, 0, 0.62), 0.33, 0.66, verts=8, r2=0.18, group="hips"))
    p.append(cyl(robe2, (0, 0, 0.3), 0.36, 0.06, verts=8, group="hips"))
    for sd, x in (("L", 1), ("R", -1)):
        p.append(cyl(robe, (0.21 * x, 0, 1.35), 0.07, 0.3, verts=6, r2=0.06, group="upperarm." + sd))
        p.append(cyl(robe2, (0.225 * x, 0, 1.08), 0.08, 0.28, verts=6, r2=0.05, group="forearm." + sd))
        for f in (-1, 0, 1):
            p.append(cyl(skin, (0.235 * x + f * 0.014, 0.01 * f, 0.86), 0.01, 0.16, verts=4, r2=0.004, rot=(0.15 * f, 0, 0), group="hand." + sd))
        p.append(cyl(robe, (0.1 * x, 0, 0.2), 0.05, 0.3, verts=5, group="shin." + sd))
    body = bind(rig, p, "Knez")
    soldier_anims(rig, False, 1.0)
    psi = {"upperarm.L": (1.2, 0, -0.6), "upperarm.R": (1.2, 0, 0.6), "forearm.L": (1.2, 0, 0), "forearm.R": (1.2, 0, 0),
           "head": (-0.15, 0, 0), "spine": (0.1, 0, 0)}
    action(rig, "aim", [(1, psi, 0.0), (13, dict(psi, head=(-0.25, 0, 0.1)), 0.02), (25, psi, 0.0)])
    action(rig, "attack", [(1, psi, 0.0), (7, dict(psi, **{"upperarm.L": (1.6, 0, -0.2), "upperarm.R": (1.6, 0, 0.2), "forearm.L": (0.2, 0, 0), "forearm.R": (0.2, 0, 0)}), 0.03), (13, psi, 0.0)])
    finish([rig, body], rig, target=(0, 0, 1.0), dist=3.4)

# ---------------------------------------------------------------------------------------
def civilian(kind):
    """A farmer / townsperson. Plain clothes. kind civ_a: work jacket and cap,
    civ_b: long coat, hair. zombie: what the hunter leaves behind."""
    zomb = kind == "zombie"
    skin = mat("CivSkin", (0.42, 0.42, 0.38) if zomb else (0.66, 0.5, 0.4), rough=0.7)
    if kind == "civ_b":
        top = mat("CivTop", (0.38, 0.2, 0.14))
        legs = mat("CivLegs", (0.12, 0.12, 0.16))
        hair = mat("CivHair", (0.22, 0.14, 0.08))
    else:
        top = mat("CivTop", (0.18, 0.12, 0.08) if zomb else (0.2, 0.28, 0.4))
        legs = mat("CivLegs", (0.1, 0.11, 0.14) if zomb else (0.16, 0.2, 0.3))
        hair = mat("CivHair", (0.3, 0.06, 0.05) if zomb else (0.32, 0.12, 0.08))
    shoe = mat("CivShoe", (0.08, 0.06, 0.05))
    growth = mat("ZombGrowth", (0.05, 0.04, 0.06), rough=0.3)
    vein = mat("ZombVein", (0.45, 0.06, 0.08), emit=0.6)
    B = humanoid_bones(hip=0.93, chest=1.4, neck=1.52, head=1.78, sx=0.2, hx=0.1, knee=0.5, ankle=0.08, elbow=1.12, wrist=0.86)
    rig = make_rig("Civ", B)
    p = []
    p.append(sphere(skin, (0, 0.01, 1.64), 0.12, seg=8, rings=6, scale=(0.9, 1.0, 1.15), group="head"))
    p.append(box(skin, (0, 0.12, 1.62), (0.04, 0.04, 0.05), group="head"))
    if kind == "civ_b":
        p.append(sphere(hair, (0, -0.03, 1.66), 0.13, seg=8, rings=6, scale=(1.0, 1.0, 1.15), group="head"))
        p.append(box(hair, (0, -0.1, 1.5), (0.2, 0.06, 0.26), group="head"))
    elif zomb:
        p.append(box(vein, (0.04, 0.115, 1.66), (0.06, 0.01, 0.1), rot=(0, 0, 0.4), group="head"))
    else:
        p.append(cyl(hair, (0, 0.0, 1.74), 0.13, 0.07, verts=8, group="head"))
        p.append(box(hair, (0, 0.13, 1.72), (0.2, 0.12, 0.02), group="head"))
    p.append(cyl(skin, (0, 0, 1.5), 0.05, 0.1, verts=6, group="neck"))
    p.append(cyl(top, (0, 0, 1.2), 0.17, 0.46, verts=8, r2=0.19, group="spine"))
    if kind == "civ_b":
        p.append(cyl(top, (0, 0, 0.78), 0.2, 0.5, verts=8, r2=0.17, group="hips"))
    else:
        p.append(cyl(legs, (0, 0, 0.94), 0.17, 0.16, verts=8, group="hips"))
    if zomb:
        # the thing growing in the back
        p.append(sphere(growth, (0, -0.2, 1.25), 0.16, seg=7, rings=5, scale=(1.2, 0.9, 1.3), group="spine"))
        for i in range(4):
            p.append(box(vein, (-0.1 + i * 0.07, -0.13, 1.1 + i * 0.07), (0.015, 0.03, 0.2), rot=(0, 0.3 * (i - 1.5), 0), group="spine"))
    for sd, x in (("L", 1), ("R", -1)):
        p.append(cyl(top, (0.2 * x, 0, 1.24), 0.055, 0.3, verts=6, r2=0.05, group="upperarm." + sd))
        p.append(cyl(skin if zomb else top, (0.215 * x, 0, 0.98), 0.045, 0.27, verts=6, r2=0.035, group="forearm." + sd))
        p.append(box(skin, (0.225 * x, 0.0, 0.81), (0.06, 0.04, 0.1), group="hand." + sd))
        p.append(cyl(legs, (0.1 * x, 0, 0.72), 0.075, 0.44, verts=6, r2=0.06, group="thigh." + sd))
        p.append(cyl(legs, (0.1 * x, 0, 0.3), 0.055, 0.44, verts=6, r2=0.045, group="shin." + sd))
        p.append(box(shoe, (0.1 * x, 0.04, 0.04), (0.1, 0.24, 0.08), group="shin." + sd))
    body = bind(rig, p, "Zombie" if zomb else "Civilian")
    if zomb:
        sh = {"spine": (-0.35, 0, 0.15), "head": (0.5, 0.2, 0.4), "upperarm.L": (1.2, 0, 0.1), "upperarm.R": (0.3, 0, -0.1),
              "forearm.L": (0.2, 0, 0), "forearm.R": (0.1, 0, 0)}
        action(rig, "idle", [(1, sh, -0.04), (25, dict(sh, head=(0.6, -0.1, 0.6), spine=(-0.4, 0, 0.2)), -0.05), (49, sh, -0.04)])
        w = walk_frames(36, 0.3, 0.05, 0.05, base=sh, spine=-0.35, knee=0.6)
        action(rig, "walk", w)
        action(rig, "run", walk_frames(24, 0.4, 0.05, 0.06, base=sh, spine=-0.4, knee=0.6))
        action(rig, "lurk", [(1, sh, -0.04), (49, sh, -0.04)])
        grab = dict(sh, **{"upperarm.L": (1.5, 0, -0.2), "upperarm.R": (1.5, 0, 0.2), "forearm.L": (0.1, 0, 0), "forearm.R": (0.1, 0, 0), "spine": (-0.2, 0, 0), "head": (0.2, 0, 0)})
        action(rig, "attack", [(1, sh, -0.04), (7, grab, -0.02), (11, dict(grab, spine=(-0.6, 0, 0)), -0.08), (19, sh, -0.04)])
        action(rig, "aim", [(1, grab, -0.02), (25, grab, -0.02)])
    else:
        action(rig, "idle", [(1, {"forearm.L": (0.1, 0, 0), "forearm.R": (0.1, 0, 0)}, 0), (25, {"head": (0, 0.2, 0.3), "forearm.L": (0.15, 0, 0), "forearm.R": (0.15, 0, 0)}, -0.01), (49, {"forearm.L": (0.1, 0, 0), "forearm.R": (0.1, 0, 0)}, 0)])
        action(rig, "walk", walk_frames(30, 0.4, 0.35, 0.02))
        action(rig, "run", walk_frames(16, 0.8, 0.7, 0.05, spine=-0.2, arm_base=(1.0, 1.0)))
        cower = {"thigh.L": (1.6, 0, 0.2), "thigh.R": (1.6, 0, -0.2), "shin.L": (-2.4, 0, 0), "shin.R": (-2.4, 0, 0),
                 "spine": (-0.7, 0, 0), "head": (-0.3, 0, 0), "upperarm.L": (2.3, 0, -0.5), "upperarm.R": (2.3, 0, 0.5),
                 "forearm.L": (1.9, 0, 0), "forearm.R": (1.9, 0, 0)}
        action(rig, "lurk", [(1, cower, -0.55), (5, dict(cower, spine=(-0.75, 0, 0.05)), -0.56), (9, cower, -0.55), (49, cower, -0.55)])
        wave = {"upperarm.R": (2.8, 0, 0.3), "forearm.R": (0.4, 0, 0)}
        action(rig, "aim", [(1, wave, 0), (9, dict(wave, **{"forearm.R": (0.8, 0, 0)}), 0), (17, wave, 0)])
        action(rig, "attack", [(1, wave, 0), (17, wave, 0)])
    finish([rig, body], rig)

# ---------------------------------------------------------------------------------------
def ohar():
    """Ohař - a blind four-legged beast with a skull split into a huge maw.
    Charges straight at whatever it hears."""
    hide = mat("OhaHide", (0.2, 0.08, 0.06), rough=0.8)
    hide2 = mat("OhaHide2", (0.1, 0.04, 0.035), rough=0.8)
    bone = mat("OhaBone", (0.6, 0.55, 0.45), rough=0.5)
    mouth = mat("OhaMouth", (0.45, 0.05, 0.05), rough=0.4)
    B = {
        "root": ((0, 0, 0), (0, 0, 0.25), None),
        "hips": ((0, -0.5, 0.9), (0, -0.4, 1.0), "root"),
        "spine": ((0, -0.4, 1.0), (0, 0.45, 1.1), "hips"),
        "neck": ((0, 0.45, 1.1), (0, 0.75, 1.0), "spine"),
        "head": ((0, 0.75, 1.0), (0, 1.15, 0.92), "neck"),
        "jaw": ((0, 0.78, 0.86), (0, 1.12, 0.74), "head"),
        "tail": ((0, -0.55, 0.95), (0, -1.2, 0.8), "hips"),
    }
    for sd, x in (("L", 1), ("R", -1)):
        B["thigh." + sd] = ((0.22 * x, -0.45, 0.9), (0.22 * x, -0.4, 0.48), "hips")
        B["shin." + sd] = ((0.22 * x, -0.4, 0.48), (0.22 * x, -0.5, 0.05), "thigh." + sd)
        B["upperarm." + sd] = ((0.26 * x, 0.38, 1.0), (0.28 * x, 0.42, 0.52), "spine")
        B["forearm." + sd] = ((0.28 * x, 0.42, 0.52), (0.28 * x, 0.45, 0.05), "upperarm." + sd)
    rig = make_rig("Oha", B)
    p = []
    p.append(sphere(hide, (0, 0.05, 1.02), 0.38, seg=8, rings=6, scale=(0.85, 1.55, 0.75), group="spine"))
    for i in range(6):
        p.append(cyl(bone, (0, -0.35 + i * 0.14, 1.28 - abs(i - 2.5) * 0.02), 0.04, 0.18, verts=4, r2=0.0, rot=(-0.4, 0, 0), group="spine"))
    p.append(sphere(hide2, (0, -0.48, 0.92), 0.27, seg=8, rings=5, scale=(0.9, 1.0, 0.85), group="hips"))
    p.append(cyl(hide2, (0, -0.85, 0.88), 0.07, 0.6, verts=5, r2=0.01, rot=(1.8, 0, 0), group="tail"))
    p.append(cyl(hide, (0, 0.6, 1.06), 0.17, 0.4, verts=6, r2=0.14, rot=(-1.9, 0, 0), group="neck"))
    p.append(sphere(bone, (0, 0.95, 0.98), 0.17, seg=7, rings=5, scale=(1.0, 1.4, 0.7), group="head"))
    p.append(box(mouth, (0, 0.95, 0.88), (0.24, 0.32, 0.06), group="head"))
    p.append(box(bone, (0, 0.97, 0.79), (0.24, 0.34, 0.07), group="jaw"))
    for i in range(6):
        for x in (1, -1):
            p.append(cyl(bone, (0.09 * x, 0.84 + i * 0.045, 0.85), 0.012, 0.07, verts=3, r2=0.0, rot=(math.pi, 0, 0), group="head"))
            p.append(cyl(bone, (0.09 * x, 0.84 + i * 0.045, 0.83), 0.012, 0.07, verts=3, r2=0.0, group="jaw"))
    for sd, x in (("L", 1), ("R", -1)):
        p.append(cyl(hide, (0.22 * x, -0.42, 0.7), 0.12, 0.44, verts=6, r2=0.08, group="thigh." + sd))
        p.append(cyl(hide2, (0.22 * x, -0.45, 0.27), 0.06, 0.44, verts=5, r2=0.04, group="shin." + sd))
        p.append(cyl(hide, (0.27 * x, 0.4, 0.76), 0.11, 0.46, verts=6, r2=0.08, group="upperarm." + sd))
        p.append(cyl(hide2, (0.28 * x, 0.44, 0.28), 0.06, 0.46, verts=5, r2=0.045, group="forearm." + sd))
        for c in (-1, 1):
            p.append(cyl(bone, (0.28 * x + c * 0.04, 0.52, 0.04), 0.015, 0.12, verts=3, r2=0.0, rot=(1.4, 0, 0), group="forearm." + sd))
    body = bind(rig, p, "Ohar")
    def gait(n, amp, bob, lunge=0.0):
        out = []
        for i in range(5):
            f = 1 + i * n // 4
            ph = i / 4 * 2 * math.pi
            sw = math.sin(ph)
            out.append((f, {"thigh.L": (-sw * amp, 0, 0), "thigh.R": (sw * amp, 0, 0),
                            "upperarm.L": (sw * amp, 0, 0), "upperarm.R": (-sw * amp, 0, 0),
                            "forearm.L": (-max(0, sw) * amp * 0.8, 0, 0), "forearm.R": (-max(0, -sw) * amp * 0.8, 0, 0),
                            "shin.L": (max(0, -sw) * amp * 0.7, 0, 0), "shin.R": (max(0, sw) * amp * 0.7, 0, 0),
                            "spine": (sw * lunge, 0, 0), "neck": (0.1, 0, 0), "tail": (0, 0, sw * 0.3)},
                        -abs(math.cos(ph)) * bob))
        return out
    action(rig, "idle", [(1, {"neck": (0.15, 0, 0), "jaw": (0.1, 0, 0), "tail": (0, 0, 0.2)}, 0),
                         (25, {"neck": (0.05, 0, 0.25), "jaw": (0.25, 0, 0), "tail": (0, 0, -0.2)}, -0.02),
                         (49, {"neck": (0.15, 0, 0), "jaw": (0.1, 0, 0), "tail": (0, 0, 0.2)}, 0)])
    action(rig, "walk", gait(30, 0.35, 0.03))
    action(rig, "run", gait(12, 0.75, 0.08, 0.12))
    action(rig, "lurk", [(1, {"thigh.L": (0.6, 0, 0), "thigh.R": (0.6, 0, 0), "shin.L": (-1.0, 0, 0), "shin.R": (-1.0, 0, 0), "upperarm.L": (-0.4, 0, 0), "upperarm.R": (-0.4, 0, 0), "forearm.L": (0.8, 0, 0), "forearm.R": (0.8, 0, 0), "neck": (0.4, 0, 0)}, -0.25),
                         (41, {"thigh.L": (0.6, 0, 0), "thigh.R": (0.6, 0, 0), "shin.L": (-1.0, 0, 0), "shin.R": (-1.0, 0, 0), "upperarm.L": (-0.4, 0, 0), "upperarm.R": (-0.4, 0, 0), "forearm.L": (0.8, 0, 0), "forearm.R": (0.8, 0, 0), "neck": (0.5, 0, 0.2)}, -0.26)])
    bite_open = {"neck": (-0.3, 0, 0), "head": (-0.3, 0, 0), "jaw": (0.9, 0, 0), "upperarm.L": (-0.3, 0, 0), "upperarm.R": (-0.3, 0, 0)}
    bite = {"neck": (0.35, 0, 0), "head": (0.2, 0, 0), "jaw": (0.0, 0, 0), "upperarm.L": (0.4, 0, 0), "upperarm.R": (0.4, 0, 0), "spine": (0.1, 0, 0)}
    action(rig, "attack", [(1, {}, 0), (6, bite_open, 0.02), (10, bite, -0.06), (18, {}, 0)])
    action(rig, "aim", [(1, bite_open, 0.02), (25, dict(bite_open, jaw=(0.6, 0, 0)), 0.02)])
    finish([rig, body], rig, target=(0, 0, 0.7), dist=3.6)

# ---------------------------------------------------------------------------------------
def trojnozec():
    """Trojnožec - a hovering machine: a thick three-lobed ring around a single
    red lens, three jointed legs hanging under it. No skeleton - the game
    bobs and turns it. Pieces named Lens / Legs so the game can animate."""
    hull = mat("TroHull", (0.28, 0.3, 0.32), rough=0.35)
    dark = mat("TroDark", (0.08, 0.085, 0.09), rough=0.4)
    lens = mat("TroLens", (1.0, 0.15, 0.08), emit=4.0)
    glow = mat("TroGlow", (0.3, 0.9, 1.0), emit=3.0)
    parts = []
    parts.append(cyl(hull, (0, 0, 0), 0.62, 0.22, verts=12, r2=0.5))
    parts.append(cyl(dark, (0, 0, 0.14), 0.42, 0.1, verts=12, r2=0.3))
    parts.append(cyl(dark, (0, 0, -0.14), 0.4, 0.08, verts=12, r2=0.26))
    for i in range(3):
        a = i * 2 * math.pi / 3
        parts.append(sphere(hull, (math.sin(a) * 0.62, math.cos(a) * 0.62, 0), 0.2, seg=8, rings=5, scale=(1, 1, 0.7)))
        parts.append(box(glow, (math.sin(a) * 0.76, math.cos(a) * 0.76, 0), (0.06, 0.06, 0.06)))
    hullo = join(parts, "Hull")
    lp = [sphere(dark, (0, 0.52, 0), 0.17, seg=10, rings=8), cyl(dark, (0, 0.62, 0), 0.13, 0.08, verts=10, rot=(math.pi / 2, 0, 0)),
          sphere(lens, (0, 0.67, 0), 0.09, seg=10, rings=8, scale=(1, 0.5, 1))]
    lenso = join(lp, "Lens")
    legs = []
    for i in range(3):
        a = i * 2 * math.pi / 3 + math.pi / 3
        x, y = math.sin(a) * 0.35, math.cos(a) * 0.35
        legs.append(cyl(dark, (x, y, -0.4), 0.04, 0.55, verts=5, r2=0.03, rot=(math.cos(a) * 0.3, -math.sin(a) * 0.3, 0)))
        legs.append(sphere(hull, (x * 1.25, y * 1.25, -0.68), 0.05, seg=6, rings=4))
        legs.append(cyl(dark, (x * 1.3, y * 1.3, -0.98), 0.03, 0.6, verts=4, r2=0.005, rot=(-math.cos(a) * 0.15, math.sin(a) * 0.15, 0)))
    legso = join(legs, "Legs")
    finish([hullo, lenso, legso], None, target=(0, 0, -0.2), dist=3.0)

def meduza():
    """Medúza - a floating creature: a pale translucent bell with a hunched
    torso and thin arms under it, a plasma pistol, a fringe of tendrils.
    Rigid pieces (Bell, Body, Tendrils); the game makes it hover and pulse."""
    bellm = mat("MedBell", (0.45, 0.42, 0.55), rough=0.3)
    bell2 = mat("MedBell2", (0.6, 0.3, 0.55), emit=0.8)
    skin = mat("MedSkin", (0.35, 0.33, 0.4), rough=0.6)
    tend = mat("MedTend", (0.25, 0.18, 0.3), rough=0.6)
    gun = mat("PlasmaBody", (0.30, 0.33, 0.30), rough=0.4)
    glow = mat("PlasmaGlow", (0.35, 1.0, 0.45), emit=4.0)
    eye = mat("GreyEye", (0.005, 0.005, 0.008), rough=0.05)
    b = sphere(bellm, (0, 0, 0.55), 0.42, seg=12, rings=8, scale=(1, 1, 0.75))
    for v in b.data.vertices:
        if v.co.z < 0.45:
            v.co.z = 0.45 - (0.45 - v.co.z) * 0.25
    bp = [b]
    for i in range(8):
        a = i * math.pi / 4
        bp.append(box(bell2, (math.sin(a) * 0.3, math.cos(a) * 0.3, 0.72), (0.03, 0.03, 0.14), rot=(math.cos(a) * 0.6, -math.sin(a) * 0.6, 0)))
    bello = join(bp, "Bell")
    bd = [cyl(skin, (0, 0.05, 0.2), 0.14, 0.4, verts=8, r2=0.18), sphere(skin, (0, 0.2, 0.25), 0.11, seg=8, rings=6, scale=(0.9, 1.1, 1.0))]
    for x in (1, -1):
        bd.append(sphere(eye, (0.05 * x, 0.3, 0.28), 0.04, seg=6, rings=4, scale=(1.4, 0.5, 0.8)))
        bd.append(cyl(skin, (0.17 * x, 0.12, 0.12), 0.03, 0.3, verts=5, rot=(0.9, 0, 0.2 * x)))
    bd.append(box(gun, (-0.17, 0.3, 0.02), (0.05, 0.16, 0.05)))
    bd.append(box(glow, (-0.17, 0.32, 0.055), (0.012, 0.08, 0.008)))
    bodyo = join(bd, "Body")
    tp = []
    for i in range(10):
        a = i * math.pi / 5
        tp.append(cyl(tend, (math.sin(a) * 0.3, math.cos(a) * 0.3, 0.05), 0.025, 0.8, verts=4, r2=0.005, rot=(math.cos(a) * 0.15, -math.sin(a) * 0.15, 0)))
    tendo = join(tp, "Tendrils")
    finish([bello, bodyo, tendo], None, target=(0, 0, 0.3), dist=2.8)


# =======================================================================================
# Roster v2 (user's designs): Šeďák velitel, Kolos, Ještěřan, Levit, Diskoll, Trhač,
# Nádor, Ohnivec, Mysloděj, Trojnožec (walker)
# =======================================================================================
def origin_at(o, point):
    """Moves an object's origin (its pivot in the game) to @a point."""
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.context.scene.cursor.location = point
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    return o

def plasma_rifle_parts(gunm, glow, x, y0, z, length=0.55, group=None):
    """A plasma long gun lying along the hand, pointing down the arm (-Z): a raised
    arm aims it forward."""
    p = [box(gunm, (x, y0 + 0.03, z - length * 0.45), (0.08, 0.1, length), group=group),
         limb(gunm, (x, y0 + 0.03, z - length * 0.9), (x, y0 + 0.03, z - length * 1.08), 0.035, 0.03, group=group),
         box(glow, (x, y0 + 0.09, z - length * 0.5), (0.025, 0.02, length * 0.55), group=group),
         box(gunm, (x, y0 - 0.06, z - 0.06), (0.05, 0.1, 0.1), group=group)]
    return p

def grey_velitel():
    """Šeďák velitel: the grey in a fitted officer's tunic, high collar, a pale
    plate on the chest. Plasma pistol. Psionic."""
    skin = mat("GreySkin", (0.50, 0.53, 0.54), rough=0.6)
    tunic = mat("VelTunic", (0.42, 0.07, 0.07), rough=0.6)
    black = mat("VelBlack", (0.05, 0.05, 0.06), rough=0.5)
    gold = mat("VelGold", (0.75, 0.55, 0.15), rough=0.3)
    eye = mat("GreyEye", (0.005, 0.005, 0.008), rough=0.05)
    gunm = mat("PlasmaBody", (0.30, 0.33, 0.30), rough=0.4)
    glow = mat("PlasmaGlow", (0.35, 1.0, 0.45), emit=4.0)
    psi = mat("VelPsi", (0.7, 0.35, 1.0), emit=2.0)
    B = humanoid_bones(hip=0.64, chest=0.98, neck=1.08, head=1.5, sx=0.17, hx=0.09, knee=0.35, ankle=0.05, elbow=0.69, wrist=0.43)
    rig = make_rig("Vel", B)
    p = []
    h = sphere(skin, (0, 0.02, 1.29), 0.21, seg=10, rings=8, scale=(1.0, 1.05, 1.3), group="head")
    for v in h.data.vertices:
        if v.co.z < 1.24:
            k = max(0.45, 1.0 - (1.24 - v.co.z) * 2.6)
            v.co.x *= k
            v.co.y = 0.02 + (v.co.y - 0.02) * k
    p.append(h)
    for x in (1, -1):
        p.append(sphere(eye, (0.07 * x, 0.2, 1.26), 0.075, seg=8, rings=6, scale=(1.55, 0.5, 0.8), rot=(0, 0.5 * x, 0.35 * x), group="head"))
    p.append(sphere(psi, (0, 0.17, 1.42), 0.022, seg=6, rings=4, group="head"))
    p.append(cyl(black, (0, 0, 1.04), 0.06, 0.1, verts=8, group="neck"))       # high collar
    p.append(limb(tunic, (0, 0, 0.7), (0, 0, 1.0), 0.13, 0.15, verts=8, group="spine"))
    p.append(box(black, (0, 0, 0.98), (0.34, 0.16, 0.06), group="spine"))      # dark shoulders
    p.append(box(gold, (0.06, 0.13, 0.9), (0.04, 0.01, 0.05), group="spine"))  # insignia
    p.append(box(gold, (0, 0.12, 0.72), (0.2, 0.02, 0.02), group="spine"))     # belt line
    p.append(limb(black, (0, 0, 0.6), (0, 0, 0.72), 0.12, 0.13, verts=8, group="hips"))
    for sd, x in (("L", 1), ("R", -1)):
        p.append(limb(tunic, (0.17 * x, 0, 0.95), (0.18 * x, 0, 0.69), 0.04, 0.032, verts=6, group="upperarm." + sd))
        p.append(limb(black, (0.18 * x, 0, 0.69), (0.19 * x, 0, 0.45), 0.03, 0.025, verts=6, group="forearm." + sd))
        for f in (-1, 0, 1):
            p.append(limb(skin, (0.19 * x + f * 0.012, 0.0, 0.43), (0.19 * x + f * 0.014, 0.012 * f, 0.31), 0.008, 0.004, verts=4, group="hand." + sd))
        p.append(limb(black, (0.09 * x, 0, 0.62), (0.09 * x, 0, 0.35), 0.05, 0.035, verts=6, group="thigh." + sd))
        p.append(limb(black, (0.09 * x, 0, 0.35), (0.09 * x, 0, 0.06), 0.035, 0.028, verts=6, group="shin." + sd))
        p.append(box(black, (0.09 * x, 0.04, 0.025), (0.07, 0.16, 0.05), group="shin." + sd))
    g = "hand.R"
    p.append(box(gunm, (-0.19, 0.03, 0.33), (0.045, 0.06, 0.14), group=g))
    p.append(box(glow, (-0.19, 0.065, 0.32), (0.012, 0.01, 0.07), group=g))
    body = bind(rig, p, "GreyVelitel")
    soldier_anims(rig, False, 0.8)
    psi_pose = {"upperarm.L": (1.3, 0, -0.5), "forearm.L": (1.3, 0, 0), "head": (-0.15, 0, 0)}
    action(rig, "attack", [(1, psi_pose, 0.0), (7, dict(psi_pose, **{"upperarm.L": (1.7, 0, -0.2), "forearm.L": (0.3, 0, 0)}), 0.0), (13, psi_pose, 0.0)])
    finish([rig, body], rig, target=(0, 0, 0.75), dist=2.4)

def kolos(red=False):
    """Kolos: a tall mutated humanoid that is nothing but muscle, sealed in a
    dark-blue organic suit that clings like a second skin. Dark purple face,
    heavy brow, a lipless grimace. Commander: blood-red suit."""
    suit = mat("KolSuitR" if red else "KolSuit", (0.42, 0.04, 0.04) if red else (0.05, 0.07, 0.2), rough=0.35)
    suit2 = mat("KolSuit2R" if red else "KolSuit2", (0.28, 0.02, 0.03) if red else (0.03, 0.04, 0.12), rough=0.4)
    face = mat("KolFace", (0.2, 0.06, 0.24), rough=0.6)
    eye = mat("KolEye", (0.9, 0.85, 0.3), emit=1.5)
    tooth = mat("LihTooth", (0.62, 0.58, 0.5), rough=0.4)
    gunm = mat("KolGun", (0.18, 0.2, 0.17), rough=0.4)
    glow = mat("PlasmaGlow", (0.35, 1.0, 0.45), emit=4.0)
    B = humanoid_bones(hip=1.08, chest=1.7, neck=1.82, head=2.12, sx=0.4, hx=0.17, knee=0.6, ankle=0.08, elbow=1.36, wrist=1.06)
    rig = make_rig("Kol", B)
    p = []
    # head: small for the body, low on the shoulders, heavy brow, open grimace
    p.append(sphere(face, (0, 0.03, 1.95), 0.15, seg=9, rings=7, scale=(0.95, 1.05, 1.15), group="head"))
    p.append(box(face, (0, 0.13, 2.0), (0.25, 0.08, 0.06), rot=(0.2, 0, 0), group="head"))     # brow ridge
    p.append(box(suit2, (0, -0.02, 2.06), (0.22, 0.24, 0.12), group="head"))                  # suit hood
    for x in (1, -1):
        p.append(sphere(eye, (0.06 * x, 0.15, 1.96), 0.018, seg=6, rings=4, group="head"))
    p.append(box(mat("KolMouth", (0.08, 0.01, 0.02)), (0, 0.14, 1.86), (0.12, 0.04, 0.05), group="head"))
    for i in range(5):
        p.append(limb(tooth, (-0.04 + i * 0.02, 0.155, 1.885), (-0.04 + i * 0.02, 0.16, 1.85), 0.009, 0.0, verts=3, group="head"))
    # trapezius rising into the neck
    p.append(limb(suit, (0, -0.03, 1.66), (0, 0.0, 1.86), 0.2, 0.11, verts=8, group="neck"))
    # torso: barrel chest, pecs, abdominal plates of muscle
    p.append(sphere(suit, (0, 0.0, 1.5), 0.33, seg=10, rings=8, scale=(1.15, 0.8, 0.9), group="spine"))
    for x in (1, -1):
        p.append(sphere(suit, (0.14 * x, 0.18, 1.52), 0.16, seg=8, rings=6, scale=(1.0, 0.6, 0.8), group="spine"))
        p.append(sphere(suit2, (0.24 * x, -0.12, 1.5), 0.17, seg=8, rings=6, scale=(0.8, 0.7, 1.1), group="spine"))   # lats
    for r_ in range(3):
        for x in (1, -1):
            p.append(sphere(suit2, (0.06 * x, 0.2, 1.33 - r_ * 0.1), 0.06, seg=6, rings=4, scale=(1.1, 0.6, 0.8), group="spine"))
    p.append(limb(suit, (0, 0, 1.12), (0, 0.02, 1.32), 0.2, 0.24, verts=8, group="spine"))
    p.append(sphere(suit2, (0, 0, 1.08), 0.22, seg=8, rings=6, scale=(1.1, 0.85, 0.7), group="hips"))
    for sd, x in (("L", 1), ("R", -1)):
        p.append(sphere(suit, (0.38 * x, 0, 1.66), 0.15, seg=8, rings=6, scale=(1.0, 1.0, 0.9), group="upperarm." + sd))   # deltoid
        p.append(limb(suit, (0.4 * x, 0, 1.62), (0.43 * x, 0, 1.36), 0.12, 0.09, group="upperarm." + sd))
        p.append(sphere(suit2, (0.42 * x, 0.06, 1.5), 0.085, seg=6, rings=5, scale=(1, 1, 1.4), group="upperarm." + sd))  # biceps
        p.append(limb(suit, (0.43 * x, 0, 1.36), (0.45 * x, 0, 1.08), 0.1, 0.07, group="forearm." + sd))
        p.append(sphere(face, (0.45 * x, 0.02, 1.02), 0.065, seg=6, rings=5, scale=(1, 1.1, 1.2), group="hand." + sd))
        p.append(limb(suit, (0.17 * x, 0, 1.06), (0.17 * x, 0.03, 0.6), 0.15, 0.1, group="thigh." + sd))
        p.append(sphere(suit2, (0.17 * x, 0.08, 0.86), 0.1, seg=7, rings=5, scale=(1, 1, 1.5), group="thigh." + sd))       # quads
        p.append(limb(suit, (0.17 * x, 0.03, 0.6), (0.17 * x, 0, 0.1), 0.1, 0.065, group="shin." + sd))
        p.append(sphere(suit2, (0.17 * x, -0.06, 0.45), 0.08, seg=6, rings=5, scale=(1, 1, 1.4), group="shin." + sd))      # calf
        p.append(box(suit2, (0.17 * x, 0.06, 0.05), (0.16, 0.3, 0.1), group="shin." + sd))
    p += plasma_rifle_parts(gunm, glow, -0.45, 0.04, 0.98, 0.6, group="hand.R")
    body = bind(rig, p, "KolosVelitel" if red else "Kolos")
    soldier_anims(rig, True, 1.4)
    finish([rig, body], rig, target=(0, 0, 1.1), dist=4.0)

def jestetan(armored=False):
    """Ještěřan: a tall lizard-like soldier. Long neck carrying a narrow snouted
    head with a frill, a heavy tail, digitigrade legs. Slow and very tough.
    Soldier: a chest cuirass. Officer (armored): plate over the whole body."""
    scale_ = mat("JesScale", (0.16, 0.22, 0.1), rough=0.55)
    scale2 = mat("JesScale2", (0.09, 0.13, 0.06), rough=0.55)
    belly = mat("JesBelly", (0.42, 0.4, 0.26), rough=0.7)
    frill = mat("JesFrill", (0.45, 0.12, 0.08), rough=0.6)
    eye = mat("JesEye", (1.0, 0.75, 0.1), emit=1.6)
    tooth = mat("LihTooth", (0.62, 0.58, 0.5), rough=0.4)
    plate = mat("JesPlate", (0.22, 0.2, 0.17), rough=0.35)
    trim = mat("VelGold", (0.75, 0.55, 0.15), rough=0.3)
    gunm = mat("KolGun", (0.18, 0.2, 0.17), rough=0.4)
    glow = mat("PlasmaGlow", (0.35, 1.0, 0.45), emit=4.0)
    B = humanoid_bones(hip=1.05, chest=1.62, neck=1.85, head=2.1, sx=0.26, hx=0.15, knee=0.6, ankle=0.06, elbow=1.3, wrist=1.0, lean=0.1)
    rig = make_rig("Jes", B)
    p = []
    # head: snout forward, jaw, frill behind, slit eyes
    p.append(sphere(scale_, (0, 0.2, 2.0), 0.13, seg=9, rings=7, scale=(0.85, 1.4, 0.75), group="head"))
    p.append(limb(scale_, (0, 0.3, 1.99), (0, 0.5, 1.96), 0.08, 0.04, verts=6, group="head"))
    p.append(limb(belly, (0, 0.28, 1.92), (0, 0.48, 1.9), 0.06, 0.03, verts=6, group="head"))
    for i in range(5):
        for x in (1, -1):
            p.append(limb(tooth, (0.035 * x, 0.32 + i * 0.035, 1.945), (0.033 * x, 0.33 + i * 0.035, 1.915), 0.008, 0.0, verts=3, group="head"))
    for x in (1, -1):
        p.append(sphere(eye, (0.075 * x, 0.25, 2.04), 0.022, seg=6, rings=4, scale=(1, 1, 0.6), group="head"))
        for k in range(3):
            p.append(limb(frill, (0.06 * x, 0.08, 2.0 + k * 0.04), (0.2 * x, -0.06, 2.0 + k * 0.08), 0.03, 0.0, verts=3, group="head"))
    for k in range(4):
        p.append(limb(scale2, (0, 0.1 - k * 0.05, 2.08 - k * 0.03), (0, 0.03 - k * 0.05, 2.18 - k * 0.04), 0.025, 0.0, verts=3, group="head"))
    # long neck
    p.append(limb(scale_, (0, 0.1, 1.6), (0, 0.18, 1.95), 0.11, 0.08, verts=8, group="neck"))
    p.append(limb(belly, (0, 0.17, 1.62), (0, 0.24, 1.92), 0.07, 0.05, verts=6, group="neck"))
    # torso
    p.append(sphere(scale_, (0, 0.05, 1.4), 0.25, seg=9, rings=7, scale=(1.0, 0.85, 1.25), group="spine"))
    p.append(sphere(belly, (0, 0.15, 1.35), 0.17, seg=8, rings=6, scale=(1.0, 0.7, 1.4), group="spine"))
    if armored:
        p.append(box(plate, (0, 0.06, 1.42), (0.5, 0.42, 0.5), group="spine"))
        p.append(box(trim, (0, 0.28, 1.42), (0.08, 0.02, 0.4), group="spine"))
        p.append(box(plate, (0, 0.24, 2.04), (0.24, 0.4, 0.12), group="head"))      # helmet over the skull
        p.append(box(plate, (0, 0.06, 1.75), (0.22, 0.3, 0.12), group="neck"))
    else:
        p.append(box(plate, (0, 0.17, 1.42), (0.44, 0.1, 0.4), group="spine"))      # cuirass front only
        p.append(box(plate, (0, -0.08, 1.45), (0.4, 0.08, 0.36), group="spine"))
    for k in range(5):
        p.append(limb(scale2, (0, -0.15, 1.25 + k * 0.08), (0, -0.28, 1.3 + k * 0.08), 0.03, 0.0, verts=3, group="spine"))
    # hips and heavy tail
    p.append(sphere(scale_, (0, 0, 1.05), 0.2, seg=8, rings=6, scale=(1.1, 1.0, 0.8), group="hips"))
    p.append(limb(scale_, (0, -0.15, 1.0), (0, -0.6, 0.65), 0.15, 0.08, verts=7, group="hips"))
    p.append(limb(scale2, (0, -0.6, 0.65), (0, -1.05, 0.15), 0.08, 0.02, verts=6, group="hips"))
    for sd, x in (("L", 1), ("R", -1)):
        p.append(sphere(plate if armored else scale_, (0.27 * x, 0.1, 1.58), 0.11, seg=7, rings=5, scale=(1.2, 1.1, 0.8), group="upperarm." + sd))
        p.append(limb(scale_, (0.27 * x, 0.1, 1.56), (0.28 * x, 0.1, 1.3), 0.07, 0.055, group="upperarm." + sd))
        p.append(limb(plate if armored else scale_, (0.28 * x, 0.1, 1.3), (0.29 * x, 0.1, 1.02), 0.06, 0.045, group="forearm." + sd))
        for c in (-1, 0, 1):
            p.append(limb(scale2, (0.29 * x + c * 0.02, 0.1, 1.0), (0.29 * x + c * 0.025, 0.14, 0.9), 0.014, 0.0, verts=3, group="hand." + sd))
        p.append(limb(plate if armored else scale_, (0.15 * x, 0, 1.03), (0.16 * x, 0.12, 0.6), 0.12, 0.08, group="thigh." + sd))
        p.append(limb(scale_, (0.16 * x, 0.12, 0.6), (0.16 * x, -0.1, 0.25), 0.07, 0.05, group="shin." + sd))
        p.append(limb(plate if armored else scale2, (0.16 * x, -0.1, 0.25), (0.16 * x, 0.04, 0.04), 0.05, 0.04, group="shin." + sd))
        for c in (-1, 0, 1):
            p.append(limb(scale2, (0.16 * x, 0.04, 0.04), (0.16 * x + c * 0.07, 0.24, 0.02), 0.025, 0.0, verts=3, group="shin." + sd))
    p += plasma_rifle_parts(gunm, glow, -0.29, 0.12, 0.98, 0.55, group="hand.R")
    body = bind(rig, p, "JestetanVelitel" if armored else "Jestetan")
    soldier_anims(rig, True, 1.4)
    finish([rig, body], rig, target=(0, 0.1, 1.1), dist=4.2)

def scary_face(skin, flesh, tooth, eye, c, s=1.0, group=None):
    """A human-like face gone wrong: no lips, a too-wide mouth full of teeth,
    a hole for a nose, deep dark sockets with tiny pupils. c = face centre."""
    x0, y0, z0 = c
    p = []
    p.append(box(flesh, (x0, y0 + 0.01 * s, z0 - 0.06 * s), (0.13 * s, 0.03 * s, 0.05 * s), group=group))
    for i in range(7):
        xx = x0 - 0.054 * s + i * 0.018 * s
        p.append(limb(tooth, (xx, y0 + 0.025 * s, z0 - 0.035 * s), (xx, y0 + 0.03 * s, z0 - 0.06 * s), 0.008 * s, 0.0, verts=3, group=group))
        p.append(limb(tooth, (xx + 0.009 * s, y0 + 0.025 * s, z0 - 0.085 * s), (xx + 0.009 * s, y0 + 0.03 * s, z0 - 0.06 * s), 0.007 * s, 0.0, verts=3, group=group))
    p.append(box(flesh, (x0, y0 + 0.02 * s, z0 + 0.01 * s), (0.03 * s, 0.02 * s, 0.03 * s), group=group))
    for x in (1, -1):
        p.append(sphere(flesh, (x0 + 0.045 * x * s, y0 + 0.005 * s, z0 + 0.05 * s), 0.03 * s, seg=6, rings=4, scale=(1.2, 0.5, 1.0), group=group))
        p.append(sphere(eye, (x0 + 0.045 * x * s, y0 + 0.02 * s, z0 + 0.05 * s), 0.008 * s, seg=5, rings=3, group=group))
    return p

def levit():
    """Levit: a floating mutant, human above the waist, a ruined face. Below,
    a pulsing organ that keeps it in the air and a fringe of dead flesh.
    Rigid pieces: Body (with a plasma rifle), Organ (pulses)."""
    skin = mat("LevSkin", (0.42, 0.4, 0.38), rough=0.6)
    skin2 = mat("LevSkin2", (0.3, 0.27, 0.27), rough=0.6)
    flesh = mat("LevFlesh", (0.1, 0.015, 0.02), rough=0.5)
    tooth = mat("LihTooth", (0.62, 0.58, 0.5), rough=0.4)
    eye = mat("LevEye", (0.9, 0.2, 0.1), emit=1.2)
    harness = mat("LevHarness", (0.1, 0.1, 0.11), rough=0.4)
    organ = mat("LevOrgan", (0.6, 0.2, 0.55), emit=1.0)
    gunm = mat("PlasmaBody", (0.30, 0.33, 0.30), rough=0.4)
    glow = mat("PlasmaGlow", (0.35, 1.0, 0.45), emit=4.0)
    b = []
    b.append(sphere(skin, (0, 0.0, 0.62), 0.12, seg=9, rings=7, scale=(0.9, 1.0, 1.15)))
    b += scary_face(skin2, flesh, tooth, eye, (0, 0.11, 0.6), 1.0)
    b.append(limb(skin2, (0, 0, 0.42), (0, 0, 0.53), 0.06, 0.05))
    b.append(sphere(skin, (0, 0, 0.3), 0.19, seg=8, rings=6, scale=(1.15, 0.8, 1.0)))       # chest
    for k in range(4):
        b.append(box(skin2, (0, 0.12, 0.38 - k * 0.06), (0.22, 0.02, 0.015)))            # ribs showing
    b.append(box(harness, (0, 0, 0.18), (0.36, 0.3, 0.08)))
    for x in (1, -1):
        b.append(limb(harness, (0.12 * x, 0.12, 0.25), (0.06 * x, 0.14, 0.42), 0.015, 0.015, verts=4))
        b.append(limb(skin, (0.2 * x, 0, 0.42), (0.24 * x, 0.12, 0.22), 0.045, 0.035))
        b.append(limb(skin, (0.24 * x, 0.12, 0.22), (0.1 * x, 0.32, 0.2), 0.035, 0.03))
    b += [box(gunm, (0.0, 0.42, 0.2), (0.07, 0.5, 0.08)), box(glow, (0.0, 0.42, 0.25), (0.02, 0.28, 0.015)),
          limb(gunm, (0, 0.67, 0.2), (0, 0.78, 0.2), 0.03, 0.025)]
    bodyo = join(b, "Body")
    o = [sphere(organ, (0, 0, 0.0), 0.15, seg=10, rings=8, scale=(1.1, 1.1, 0.8))]
    for i in range(9):
        a = i * 2 * math.pi / 9
        o.append(limb(flesh, (math.sin(a) * 0.12, math.cos(a) * 0.12, 0.05), (math.sin(a) * 0.18, math.cos(a) * 0.18, -0.35 - (i % 3) * 0.08), 0.03, 0.005, verts=4))
    organo = join(o, "Organ")
    origin_at(organo, (0, 0, 0))
    finish([bodyo, organo], None, target=(0, 0, 0.3), dist=2.0)

def diskoll():
    """Diskoll: a fast escort drone. A flat armoured disc with a dark dome, a ring
    of lights that spins, two short gun pods in front, thruster glow below.
    Pieces: Hull, Ring (spins), Guns."""
    hull = mat("DisHull", (0.3, 0.32, 0.34), rough=0.3)
    dark = mat("TroDark", (0.08, 0.085, 0.09), rough=0.4)
    light = mat("DisLight", (0.3, 0.9, 1.0), emit=3.0)
    red = mat("TroLens", (1.0, 0.15, 0.08), emit=4.0)
    thr = mat("DisThrust", (0.5, 0.8, 1.0), emit=2.0)
    h = [cyl(hull, (0, 0, 0), 0.7, 0.14, verts=16, r2=0.55), cyl(hull, (0, 0, -0.1), 0.55, 0.08, verts=16, r2=0.68),
         sphere(dark, (0, 0, 0.09), 0.3, seg=12, rings=6, scale=(1, 1, 0.55)), sphere(red, (0, 0.24, 0.1), 0.05, seg=8, rings=6),
         cyl(thr, (0, 0, -0.15), 0.25, 0.02, verts=12)]
    hullo = join(h, "Hull")
    r = []
    for i in range(12):
        a = i * math.pi / 6
        r.append(box(light, (math.sin(a) * 0.66, math.cos(a) * 0.66, 0.0), (0.05, 0.05, 0.03), rot=(0, 0, -a)))
    ringo = join(r, "Ring")
    origin_at(ringo, (0, 0, 0))
    g = []
    for x in (1, -1):
        g.append(limb(dark, (0.22 * x, 0.45, -0.08), (0.22 * x, 0.85, -0.08), 0.05, 0.035, verts=6))
        g.append(sphere(mat("PlasmaGlow", (0.35, 1.0, 0.45), emit=4.0), (0.22 * x, 0.86, -0.08), 0.025, seg=6, rings=4))
    guno = join(g, "Guns")
    finish([hullo, ringo, guno], None, target=(0, 0, 0), dist=2.8)

def trhac():
    """Trhač: a mutated four-legged wolf. The snout is gone - a long bone blade
    grows from the face. Armour plates grafted onto shoulders and back, raw
    flesh between them. Fast and stupid."""
    hide = mat("TrhHide", (0.17, 0.14, 0.12), rough=0.85)
    raw = mat("TrhRaw", (0.4, 0.06, 0.07), rough=0.5)
    bone = mat("OhaBone", (0.6, 0.55, 0.45), rough=0.5)
    plate = mat("TrhPlate", (0.2, 0.21, 0.22), rough=0.35)
    eye = mat("TrhEye", (1.0, 0.85, 0.2), emit=1.5)
    B = {
        "root": ((0, 0, 0), (0, 0, 0.25), None),
        "hips": ((0, -0.5, 0.85), (0, -0.4, 0.95), "root"),
        "spine": ((0, -0.4, 0.95), (0, 0.42, 1.05), "hips"),
        "neck": ((0, 0.42, 1.05), (0, 0.72, 1.0), "spine"),
        "head": ((0, 0.72, 1.0), (0, 1.1, 0.95), "neck"),
        "jaw": ((0, 0.75, 0.9), (0, 1.0, 0.8), "head"),
        "tail": ((0, -0.55, 0.9), (0, -1.15, 0.8), "hips"),
    }
    for sd, x in (("L", 1), ("R", -1)):
        B["thigh." + sd] = ((0.2 * x, -0.45, 0.85), (0.2 * x, -0.32, 0.45), "hips")
        B["shin." + sd] = ((0.2 * x, -0.32, 0.45), (0.2 * x, -0.5, 0.05), "thigh." + sd)
        B["upperarm." + sd] = ((0.24 * x, 0.36, 0.95), (0.25 * x, 0.42, 0.5), "spine")
        B["forearm." + sd] = ((0.25 * x, 0.42, 0.5), (0.25 * x, 0.45, 0.05), "upperarm." + sd)
    rig = make_rig("Trh", B)
    p = []
    p.append(sphere(hide, (0, 0.05, 0.98), 0.32, seg=9, rings=7, scale=(0.8, 1.55, 0.72), group="spine"))
    for i in range(4):
        p.append(limb(raw, (0.24, -0.25 + i * 0.2, 0.92), (0.22, -0.2 + i * 0.2, 1.0), 0.02, 0.02, verts=4, group="spine"))
        p.append(limb(raw, (-0.24, -0.25 + i * 0.2, 0.92), (-0.22, -0.2 + i * 0.2, 1.0), 0.02, 0.02, verts=4, group="spine"))
    p.append(box(plate, (0, 0.28, 1.2), (0.42, 0.34, 0.08), rot=(0.1, 0, 0), group="spine"))
    p.append(box(plate, (0, -0.12, 1.2), (0.34, 0.3, 0.07), rot=(-0.05, 0, 0), group="spine"))
    for i in range(5):
        p.append(limb(bone, (0, -0.35 + i * 0.12, 1.22), (0, -0.4 + i * 0.12, 1.36), 0.025, 0.0, verts=3, group="spine"))
    p.append(sphere(hide, (0, -0.48, 0.88), 0.24, seg=8, rings=5, scale=(0.95, 1.0, 0.85), group="hips"))
    p.append(limb(hide, (0, -0.6, 0.9), (0, -1.15, 0.72), 0.07, 0.015, verts=5, group="tail"))
    p.append(limb(hide, (0, 0.38, 1.02), (0, 0.72, 1.0), 0.16, 0.12, verts=7, group="neck"))
    p.append(box(plate, (0, 0.55, 1.13), (0.26, 0.26, 0.06), group="neck"))
    # head: short skull, two small eyes, the blade
    p.append(sphere(hide, (0, 0.82, 0.98), 0.14, seg=8, rings=6, scale=(1.0, 1.1, 0.85), group="head"))
    for x in (1, -1):
        p.append(sphere(eye, (0.08 * x, 0.9, 1.02), 0.018, seg=6, rings=4, group="head"))
    blade = limb(bone, (0, 0.9, 0.98), (0, 1.55, 0.86), 0.07, 0.0, verts=4, group="head")
    for v in blade.data.vertices:
        v.co.x *= 0.3
    p.append(blade)
    p.append(limb(raw, (0, 0.88, 0.9), (0, 1.0, 0.86), 0.06, 0.03, verts=5, group="head"))
    p.append(box(raw, (0, 0.88, 0.84), (0.14, 0.2, 0.04), group="jaw"))
    for i in range(4):
        for x in (1, -1):
            p.append(limb(bone, (0.05 * x, 0.82 + i * 0.04, 0.85), (0.05 * x, 0.82 + i * 0.04, 0.9), 0.01, 0.0, verts=3, group="jaw"))
    for sd, x in (("L", 1), ("R", -1)):
        p.append(limb(hide, (0.2 * x, -0.45, 0.85), (0.2 * x, -0.32, 0.45), 0.12, 0.07, group="thigh." + sd))
        p.append(limb(hide, (0.2 * x, -0.32, 0.45), (0.2 * x, -0.5, 0.05), 0.06, 0.04, group="shin." + sd))
        p.append(limb(hide, (0.24 * x, 0.36, 0.95), (0.25 * x, 0.42, 0.5), 0.1, 0.07, group="upperarm." + sd))
        p.append(box(plate, (0.27 * x, 0.38, 0.8), (0.08, 0.2, 0.22), group="upperarm." + sd))
        p.append(limb(hide, (0.25 * x, 0.42, 0.5), (0.25 * x, 0.45, 0.05), 0.06, 0.04, group="forearm." + sd))
        for c in (-1, 1):
            p.append(limb(bone, (0.25 * x + c * 0.03, 0.47, 0.06), (0.25 * x + c * 0.04, 0.6, 0.02), 0.015, 0.0, verts=3, group="forearm." + sd))
    body = bind(rig, p, "Trhac")
    def gait(n, amp, bob, lunge=0.0):
        out = []
        for i in range(5):
            f = 1 + i * n // 4
            ph = i / 4 * 2 * math.pi
            sw = math.sin(ph)
            out.append((f, {"thigh.L": (-sw * amp, 0, 0), "thigh.R": (sw * amp, 0, 0),
                            "upperarm.L": (sw * amp, 0, 0), "upperarm.R": (-sw * amp, 0, 0),
                            "forearm.L": (-max(0, sw) * amp * 0.8, 0, 0), "forearm.R": (-max(0, -sw) * amp * 0.8, 0, 0),
                            "shin.L": (max(0, -sw) * amp * 0.7, 0, 0), "shin.R": (max(0, sw) * amp * 0.7, 0, 0),
                            "spine": (sw * lunge, 0, 0), "neck": (0.15, 0, 0), "tail": (0, 0, sw * 0.4)},
                        -abs(math.cos(ph)) * bob))
        return out
    action(rig, "idle", [(1, {"neck": (0.2, 0, 0), "tail": (0, 0, 0.2)}, 0), (25, {"neck": (0.1, 0, 0.3), "jaw": (0.3, 0, 0), "tail": (0, 0, -0.2)}, -0.02),
                         (49, {"neck": (0.2, 0, 0), "tail": (0, 0, 0.2)}, 0)])
    action(rig, "walk", gait(26, 0.38, 0.03))
    action(rig, "run", gait(10, 0.85, 0.09, 0.14))
    crouch = {"thigh.L": (0.6, 0, 0), "thigh.R": (0.6, 0, 0), "shin.L": (-1.0, 0, 0), "shin.R": (-1.0, 0, 0), "upperarm.L": (-0.4, 0, 0), "upperarm.R": (-0.4, 0, 0), "forearm.L": (0.8, 0, 0), "forearm.R": (0.8, 0, 0), "neck": (0.45, 0, 0)}
    action(rig, "lurk", [(1, crouch, -0.25), (41, dict(crouch, neck=(0.5, 0, 0.2)), -0.26)])
    rear = {"neck": (-0.45, 0, 0), "head": (-0.35, 0, 0), "jaw": (0.7, 0, 0), "upperarm.L": (-0.4, 0, 0), "upperarm.R": (-0.4, 0, 0), "spine": (-0.15, 0, 0)}
    stab = {"neck": (0.45, 0, 0), "head": (0.35, 0, 0), "jaw": (0.0, 0, 0), "upperarm.L": (0.5, 0, 0), "upperarm.R": (0.5, 0, 0), "spine": (0.15, 0, 0)}
    action(rig, "attack", [(1, {}, 0), (6, rear, 0.03), (9, stab, -0.08), (17, {}, 0)])
    action(rig, "aim", [(1, rear, 0.02), (25, dict(rear, jaw=(0.4, 0, 0)), 0.02)])
    finish([rig, body], rig, target=(0, 0.2, 0.7), dist=3.8)

def nador():
    """Nádor: a floating tumour of grey-pink flesh, lumpy and veined, a ring of
    small dead eyes and one wet orifice that spits acid. Rigid: Body (pulses)."""
    flesh = mat("NadFlesh", (0.36, 0.17, 0.2), rough=0.35)
    flesh2 = mat("NadFlesh2", (0.22, 0.07, 0.11), rough=0.4)
    vein = mat("NadVein", (0.25, 0.05, 0.15), rough=0.5)
    acid = mat("NadAcid", (0.6, 0.9, 0.15), emit=1.5)
    eye = mat("NadEye", (0.8, 0.78, 0.6), rough=0.2)
    b = [sphere(flesh, (0, 0, 0), 0.38, seg=12, rings=9, scale=(1.0, 1.0, 0.9))]
    import random
    rr = random.Random(5)
    for i in range(14):
        a = rr.uniform(0, 2 * math.pi); e = rr.uniform(-0.8, 1.0)
        c = (math.cos(e) * math.sin(a) * 0.33, math.cos(e) * math.cos(a) * 0.33, math.sin(e) * 0.3)
        b.append(sphere(flesh2 if i % 3 else flesh, c, rr.uniform(0.08, 0.16), seg=7, rings=5))
    for i in range(10):
        a = rr.uniform(0, 2 * math.pi)
        b.append(limb(vein, (math.sin(a) * 0.3, math.cos(a) * 0.3, -0.25), (math.sin(a + 0.4) * 0.36, math.cos(a + 0.4) * 0.36, 0.25), 0.012, 0.012, verts=4))
    for i in range(5):
        a = -0.6 + i * 0.3
        b.append(sphere(eye, (math.sin(a) * 0.33, math.cos(a) * 0.33, 0.12), 0.03, seg=6, rings=4))
    b.append(sphere(vein, (0, 0.36, -0.05), 0.09, seg=8, rings=6, scale=(1, 0.5, 1)))
    b.append(sphere(acid, (0, 0.39, -0.05), 0.05, seg=6, rings=4, scale=(1, 0.5, 1)))
    for i in range(6):
        a = i * math.pi / 3
        b.append(limb(flesh2, (math.sin(a) * 0.2, math.cos(a) * 0.2, -0.3), (math.sin(a) * 0.25, math.cos(a) * 0.25, -0.7), 0.04, 0.005, verts=4))
    bodyo = join(b, "Body")
    origin_at(bodyo, (0, 0, 0))
    finish([bodyo], None, target=(0, 0, 0), dist=2.2)

def ohnivec():
    """Ohnivec: a crawling mound of black rock with molten seams, a glowing maw.
    Rigid: Rock, Magma (glows, pulses)."""
    rock = mat("OhnRock", (0.08, 0.07, 0.07), rough=0.9)
    rock2 = mat("OhnRock2", (0.14, 0.11, 0.1), rough=0.9)
    lava = mat("OhnLava", (1.0, 0.35, 0.05), emit=4.0)
    import random
    rr = random.Random(9)
    r = []
    for i in range(16):
        a = rr.uniform(0, 2 * math.pi); d = rr.uniform(0.0, 0.5)
        r.append(box(rock if i % 2 else rock2, (math.sin(a) * d, math.cos(a) * d, rr.uniform(0.12, 0.42) * (1 - d)),
                     (rr.uniform(0.2, 0.38), rr.uniform(0.2, 0.38), rr.uniform(0.15, 0.3)), rot=(rr.uniform(-0.5, 0.5), rr.uniform(-0.5, 0.5), rr.uniform(0, 3))))
    r.append(sphere(rock, (0, 0, 0.2), 0.45, seg=9, rings=6, scale=(1.1, 1.2, 0.6)))
    rocko = join(r, "Rock")
    m = [sphere(lava, (0, 0, 0.15), 0.42, seg=10, rings=6, scale=(1.05, 1.15, 0.45)),
         sphere(lava, (0, 0.55, 0.22), 0.11, seg=8, rings=6, scale=(1.3, 0.6, 0.8))]
    for i in range(8):
        a = i * math.pi / 4
        m.append(box(lava, (math.sin(a) * 0.35, math.cos(a) * 0.35, 0.35), (0.04, 0.3, 0.03), rot=(0, 0, -a)))
    magmao = join(m, "Magma")
    origin_at(magmao, (0, 0, 0.15))
    finish([rocko, magmao], None, target=(0, 0, 0.3), dist=2.6)

def myslodej():
    """Mysloděj: a floating violet shroud, the hood empty and dark - only two pale
    points deep inside. No limbs. A plasma rifle hangs in the air beside it.
    Pieces: Robe (sways), Weapon (orbits)."""
    robe = mat("MysRobe", (0.24, 0.07, 0.32), rough=0.75)
    robe2 = mat("MysRobe2", (0.14, 0.03, 0.2), rough=0.8)
    void = mat("MysVoid", (0.0, 0.0, 0.0), rough=1.0)
    eye = mat("MysEye", (0.85, 0.8, 1.0), emit=2.5)
    trim = mat("MysTrim", (0.6, 0.5, 0.25), rough=0.3)
    r = [cyl(robe, (0, 0, 0.75), 0.42, 1.3, verts=12, r2=0.14),
         sphere(robe, (0, 0, 1.5), 0.2, seg=10, rings=8, scale=(1.0, 1.1, 1.2)),
         cyl(robe2, (0, 0, 1.38), 0.28, 0.12, verts=12, r2=0.16)]
    hood_in = sphere(void, (0, 0.1, 1.5), 0.14, seg=8, rings=6, scale=(0.9, 0.6, 1.1))
    r.append(hood_in)
    for x in (1, -1):
        r.append(sphere(eye, (0.04 * x, 0.18, 1.52), 0.012, seg=5, rings=3))
    for i in range(14):
        a = i * 2 * math.pi / 14
        r.append(limb(robe2, (math.sin(a) * 0.38, math.cos(a) * 0.38, 0.2), (math.sin(a) * 0.44, math.cos(a) * 0.44, -0.05 - (i % 3) * 0.06), 0.06, 0.0, verts=3))
    r.append(box(trim, (0, 0.17, 1.0), (0.04, 0.02, 0.6)))
    for x in (1, -1):
        r.append(limb(robe, (0.2 * x, 0, 1.3), (0.35 * x, 0.1, 0.9), 0.09, 0.07, verts=8))        # empty sleeves
        r.append(sphere(void, (0.35 * x, 0.11, 0.88), 0.06, seg=6, rings=4))
    robeo = join(r, "Robe")
    w = plasma_rifle_parts(mat("PlasmaBody", (0.30, 0.33, 0.30), rough=0.4), mat("PlasmaGlow", (0.35, 1.0, 0.45), emit=4.0), 0, 0, 0.3, 0.6)
    weapono = join(w, "Weapon")
    weapono.rotation_euler = (math.pi / 2, 0, 0)     # lying level, pointing forward
    bpy.ops.object.select_all(action='DESELECT'); weapono.select_set(True)
    bpy.context.view_layer.objects.active = weapono
    bpy.ops.object.transform_apply(rotation=True)
    origin_at(weapono, (0, 0, 0))
    weapono.location = (0.55, 0.15, 1.05)
    finish([robeo, weapono], None, target=(0, 0, 0.9), dist=3.2)

def trojnozec_walker():
    """Trojnožec: a walking war machine on three legs. A heavy wedge hull, two
    plasma heads in front, a plasma cannon turret on the roof. Pieces: Hull,
    Turret, Leg0..2 (pivots at the hips, the game swings them)."""
    hull = mat("TroHull", (0.24, 0.25, 0.27), rough=0.35)
    dark = mat("TroDark", (0.08, 0.085, 0.09), rough=0.4)
    lens = mat("TroLens", (1.0, 0.15, 0.08), emit=4.0)
    glow = mat("PlasmaGlow", (0.35, 1.0, 0.45), emit=4.0)
    H = 2.0
    h = [box(hull, (0, 0.05, H), (0.9, 1.2, 0.45)),
         box(hull, (0, 0.6, H - 0.05), (0.7, 0.3, 0.35), rot=(0.3, 0, 0)),
         box(dark, (0, -0.1, H - 0.3), (0.7, 0.8, 0.2)),
         sphere(lens, (0, 0.78, H + 0.05), 0.07, seg=8, rings=6)]
    for x in (1, -1):
        h.append(limb(dark, (0.3 * x, 0.6, H - 0.25), (0.3 * x, 1.05, H - 0.28), 0.09, 0.07, verts=8))
        h.append(sphere(glow, (0.3 * x, 1.06, H - 0.28), 0.05, seg=6, rings=4))
        h.append(box(hull, (0.3 * x, 0.6, H - 0.25), (0.22, 0.3, 0.22)))
    hullo = join(h, "Hull")
    t = [cyl(dark, (0, 0, H + 0.3), 0.25, 0.18, verts=10), box(hull, (0, 0.05, H + 0.42), (0.36, 0.5, 0.2)),
         limb(dark, (0, 0.25, H + 0.45), (0, 1.0, H + 0.45), 0.07, 0.06, verts=8),
         sphere(glow, (0, 1.01, H + 0.45), 0.045, seg=6, rings=4)]
    turreto = join(t, "Turret")
    origin_at(turreto, (0, 0, H + 0.3))
    legs = []
    for i, a in enumerate((math.pi / 3, -math.pi / 3, math.pi)):
        hip = (math.sin(a) * 0.4, math.cos(a) * 0.4, H - 0.15)
        knee = (math.sin(a) * 0.95, math.cos(a) * 0.95, H + 0.15)
        foot = (math.sin(a) * 1.1, math.cos(a) * 1.1, 0.05)
        lp = [sphere(dark, hip, 0.13, seg=8, rings=6), limb(hull, hip, knee, 0.1, 0.08, verts=6),
              sphere(dark, knee, 0.1, seg=8, rings=6), limb(hull, knee, foot, 0.08, 0.05, verts=6),
              cyl(dark, foot, 0.14, 0.08, verts=8)]
        lo = join(lp, "Leg%d" % i)
        origin_at(lo, hip)
        legs.append(lo)
    finish([hullo, turreto] + legs, None, target=(0, 0, 1.2), dist=5.0)

CREATURES = {"lihnoun": lihnoun, "civ_a": lambda: civilian("civ_a"), "civ_b": lambda: civilian("civ_b"),
             "zombie": lambda: civilian("zombie"),
             "grey_velitel": grey_velitel, "bijec": kolos, "bijec_velitel": lambda: kolos(True),
             "jestetan": jestetan, "jestetan_velitel": lambda: jestetan(True), "levit": levit, "diskoll": diskoll,
             "ohar": trhac, "nador": nador, "ohnivec": ohnivec, "myslodej": myslodej, "kolos": trojnozec_walker,
             # first roster (no longer used in the game)
             "hlidac": hlidac, "knez": knez, "meduza": meduza, "ohar_old": ohar, "trojnozec_old": trojnozec}
CREATURES[KIND]()
