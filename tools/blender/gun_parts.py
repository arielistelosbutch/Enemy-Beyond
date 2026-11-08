"""Enemy Beyond 0.57 - parts a mercenary mounts on his gun (Úpravy zbraní): a 2x scope, a bayonet,
a suppressor, a front grip, a weapon light and a laser module. Same style as guns.py (bevelled
plates, round tubes), own designs.
Each part's origin is the point where it sits on the gun (the rail top, the barrel axis, the muzzle);
the game places it with Game.PART_AT. Muzzle +Y in Blender (-Z in Godot), Z up.
Run: python3 tools/blender/gun_parts.py <outdir> [--only optika,bajonet] [--preview out.png]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
_argv = sys.argv
sys.argv = [_argv[0], "/tmp", "--only", "-"]      # guns.py: only the helpers, build nothing
import guns
from guns import *
sys.argv = _argv
from mathutils import Vector

ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
OUTDIR = ARGS[0] if ARGS else "."
ONLY = sys.argv[sys.argv.index("--only") + 1].split(",") if "--only" in sys.argv else []
PI2 = math.pi / 2

def out(parts, name):
    o = join(parts, name)
    export_glb(os.path.join(OUTDIR, "part_" + name.lower() + ".glb"), [o])
    return o

def clamp_ring(m, y, z, r, w=0.012):
    """A scope ring: a band round the tube and a clamp down to the rail."""
    p = [ring(m, y, z, r + 0.003, w, verts=20)]
    p.append(bx(m, (0, y, (z - r) / 2 + 0.004), (0.014, w, z - r), 0.0015))
    p.append(bx(m, (0, y, 0.004), (0.03, w + 0.006, 0.008), 0.0015))       # the rail clamp
    p.append(screw(m, (0.016, y, 0.004)))
    return p

def htube(m, y0, y1, z, r, wall=0.0025, verts=24):
    """An open tube along +Y (you can look through it) with a wall of its own thickness."""
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=y1 - y0, end_fill_type='NOTHING')
    o = bpy.context.active_object
    o = guns.smooth(__import__("common")._finish(o, m, (0, (y0 + y1) / 2, z), (PI2, 0, 0), (1, 1, 1)))
    guns._sel(o)
    mod = o.modifiers.new("Wall", 'SOLIDIFY')
    mod.thickness = wall
    mod.offset = 1.0
    bpy.ops.object.modifier_apply(modifier="Wall")
    return o

def kolimator_t():
    """The rifle's factory red dot (was part of the rifle's mesh, now a part): the same look, but an
    open tube - the eye looks through it. Origin = the rail top under its middle; axis 0.036 up,
    lens at y +0.032 (the game draws the dot)."""
    reset(); m = M(); p = []
    z = 0.036
    p.append(bx(m["dark"], (0, 0.0, 0.006), (0.034, 0.06, 0.012), 0.002))               # mount
    p.append(bx(m["dark"], (0, 0.0, 0.0125), (0.02, 0.05, 0.004), 0.001))
    p.append(htube(m["dark"], -0.035, 0.035, z, 0.0195, 0.003))                         # body
    p.append(htube(m["black"], 0.031, 0.038, z, 0.0215, 0.0025))                        # front ring
    p.append(htube(m["black"], -0.038, -0.031, z, 0.0215, 0.0025))                      # rear ring
    p.append(htube(m["dark"], 0.035, 0.05, z, 0.02, 0.0015))                            # sun hood
    p.append(smooth(cyl(m["dark"], (0.025, 0.0, z), 0.008, 0.012, verts=12, rot=(0, PI2, 0))))   # brightness knob
    for k in range(6):
        a = k / 6 * math.tau
        p.append(bx(m["black"], (0.031, math.cos(a) * 0.007, z + math.sin(a) * 0.007), (0.002, 0.002, 0.002), 0.0004))
    p.append(smooth(cyl(m["dark"], (0, 0.0, z + 0.025), 0.007, 0.01, verts=12)))          # windage cap
    p.append(screw(m["steel"], (0.018, -0.018, 0.006)))
    p.append(screw(m["steel"], (0.018, 0.018, 0.006)))
    p.append(cyl(m["lens"], (0, 0.033, z), 0.017, 0.001, verts=24, rot=(PI2, 0, 0)))      # tinted lens
    out(p, "Kolimator_t")

def kolimator():
    """A small open red dot for a pistol slide or a shotgun receiver: a low base and a round open
    hood. Origin = the mounting face; axis 0.016 up, window front at y +0.011."""
    reset(); m = M(); p = []
    z = 0.016
    p.append(bx(m["black"], (0, 0.0, 0.003), (0.022, 0.03, 0.006), 0.0015))
    p.append(bx(m["black"], (0, -0.008, 0.008), (0.018, 0.012, 0.006), 0.0015))
    p.append(htube(m["black"], -0.011, 0.011, z, 0.0105, 0.0025, verts=20))
    p.append(smooth(cyl(m["dark"], (0.013, -0.004, 0.008), 0.003, 0.004, verts=8, rot=(0, PI2, 0))))
    p.append(cyl(m["lens"], (0, 0.009, z), 0.0095, 0.0008, verts=20, rot=(PI2, 0, 0)))
    out(p, "Kolimator")

def optika():
    """2x combat scope: rings on the rail, tube with an objective bell, turrets, rubber eyecup.
    Axis 0.045 above the rail top; eyepiece at y -0.075, objective at +0.085 (the game knows these)."""
    reset(); m = M(); p = []
    z = 0.045
    p.append(smooth(ty(m["dark"], -0.045, 0.05, z, 0.0155, verts=20)))                  # main tube
    p.append(smooth(tb(m["dark"], (0, 0.05, z), (0, 0.068, z), 0.0155, verts=20, r2=0.021)))   # bell
    p.append(smooth(ty(m["dark"], 0.068, 0.085, z, 0.021, verts=20)))                   # objective
    p.append(ring(m["black"], 0.083, z, 0.0225, 0.004, verts=20))
    p.append(smooth(tb(m["dark"], (0, -0.045, z), (0, -0.058, z), 0.0155, verts=20, r2=0.019)))
    p.append(smooth(ty(m["black"], -0.075, -0.058, z, 0.019, verts=20)))               # eyepiece
    p.append(smooth(ty(m["rubber"], -0.08, -0.07, z, 0.0195, verts=20)))               # eyecup
    for k in range(6):
        p.append(ring(m["black"], -0.066 + k * 0.0025, z, 0.0193, 0.0008, verts=20))  # grip rings
    # turrets: elevation on top, windage on the right, a little illumination knob on the left
    p.append(smooth(cyl(m["dark"], (0, 0.0, z + 0.022), 0.009, 0.014, verts=16)))
    p.append(smooth(cyl(m["black"], (0, 0.0, z + 0.03), 0.0095, 0.004, verts=16)))
    p.append(smooth(cyl(m["dark"], (0.022, 0.0, z), 0.009, 0.014, verts=16, rot=(0, PI2, 0))))
    p.append(smooth(cyl(m["black"], (0.03, 0.0, z), 0.0095, 0.004, verts=16, rot=(0, PI2, 0))))
    p.append(smooth(cyl(m["dark"], (-0.02, 0.0, z), 0.007, 0.01, verts=12, rot=(0, PI2, 0))))
    p.append(box(m["red"], (-0.0255, 0.0, z), (0.001, 0.003, 0.003)))
    p.append(bx(m["dark"], (0, 0.0, z), (0.028, 0.03, 0.026), 0.004))                   # turret housing
    p += clamp_ring(m["black"], -0.03, z, 0.0155)
    p += clamp_ring(m["black"], 0.035, z, 0.0155)
    # lenses (the game makes "...Glass" see-through)
    p.append(cyl(m["lens"], (0, 0.084, z), 0.019, 0.001, verts=20, rot=(PI2, 0, 0)))
    p.append(cyl(m["lens"], (0, -0.076, z), 0.017, 0.001, verts=20, rot=(PI2, 0, 0)))
    out(p, "Optika")

def bajonet():
    """Bayonet: a muzzle ring round the flash hider, a lug on the gas block, a 21 cm blade under
    the barrel. Origin = the barrel axis at the gas block."""
    reset(); m = M(); p = []
    p.append(ring(m["steel"], 0.125, 0.0, 0.0165, 0.012, verts=16))                    # muzzle ring
    p.append(bx(m["black"], (0, 0.0, -0.022), (0.016, 0.03, 0.012), 0.002))            # lug clamp
    hilt = bx(m["poly"], (0, 0.06, -0.026), (0.014, 0.1, 0.02), 0.004, seg=2)          # handle
    p.append(hilt)
    for k in range(5):
        p.append(bx(m["black"], (0, 0.022 + k * 0.018, -0.036), (0.0145, 0.004, 0.002), 0.0005))
    p.append(bx(m["steel"], (0, 0.112, -0.016), (0.018, 0.006, 0.042), 0.0015))       # crossguard to the ring
    # blade: flat, a clipped point, a fuller groove, a little saw on the back
    p.append(bx(m["chrome"], (0, 0.2, -0.024), (0.004, 0.17, 0.024), 0.0008))
    tip = box(m["chrome"], (0, 0.292, -0.028), (0.004, 0.024, 0.016), rot=(0.55, 0, 0))
    p.append(tip)
    p.append(box(m["steel"], (0.0021, 0.19, -0.026), (0.0004, 0.13, 0.004)))
    p.append(box(m["steel"], (-0.0021, 0.19, -0.026), (0.0004, 0.13, 0.004)))
    for k in range(7):
        p.append(box(m["chrome"], (0, 0.13 + k * 0.011, -0.0115), (0.003, 0.005, 0.004), rot=(0.7, 0, 0)))
    out(p, "Bajonet")

def tlumic():
    """Suppressor: slips over the flash hider. Origin = the end of the barrel."""
    reset(); m = M(); p = []
    p.append(smooth(ty(m["black"], -0.045, 0.15, 0.0, 0.019, verts=20)))
    p.append(ring(m["dark"], -0.04, 0.0, 0.0205, 0.012, verts=20))
    p.append(ring(m["dark"], 0.145, 0.0, 0.0205, 0.01, verts=20))
    for k in range(8):
        p.append(bx(m["dark"], (0, -0.03 + k * 0.004, 0.02), (0.003, 0.0018, 0.003), 0.0004))
    p.append(cyl(m["rubber"], (0, 0.1505, 0.0), 0.006, 0.002, verts=12, rot=(PI2, 0, 0)))
    out(p, "Tlumic")

def rukojet():
    """Vertical front grip. Origin = the underside of the handguard."""
    reset(); m = M(); p = []
    p.append(bx(m["black"], (0, 0.0, -0.004), (0.026, 0.045, 0.008), 0.0015))
    p.append(smooth(tb(m["poly"], (0, 0.0, -0.008), (0, 0.006, -0.082), 0.0135, verts=16, r2=0.012)))
    for k in range(4):
        p.append(smooth(tb(m["black"], (0, 0.001 + k * 0.0015, -0.03 - k * 0.012), (0, 0.0015 + k * 0.0015, -0.034 - k * 0.012), 0.0139, verts=16)))
    p.append(smooth(cyl(m["rubber"], (0, 0.006, -0.084), 0.0125, 0.005, verts=16)))
    out(p, "Rukojet")

def svitilna():
    """Weapon light on the left rail. Origin = the rail face."""
    reset(); m = M(); p = []
    p.append(bx(m["black"], (-0.006, 0.0, 0.0), (0.012, 0.03, 0.02), 0.002))           # mount
    p.append(smooth(ty(m["dark"], -0.045, 0.035, -0.0, 0.011, x=-0.022, verts=16)))
    p.append(smooth(tb(m["dark"], (-0.022, 0.035, 0.0), (-0.022, 0.05, 0.0), 0.011, verts=16, r2=0.0145)))
    p.append(smooth(ty(m["dark"], 0.05, 0.062, 0.0, 0.0145, x=-0.022, verts=16)))
    p.append(cyl(m["white"], (-0.022, 0.0625, 0.0), 0.0125, 0.002, verts=16, rot=(PI2, 0, 0)))
    p.append(smooth(cyl(m["rubber"], (-0.022, -0.047, 0.0), 0.008, 0.006, verts=12, rot=(PI2, 0, 0))))
    out(p, "Svitilna")

def laser():
    """Laser module on the right rail. Origin = the rail face."""
    reset(); m = M(); p = []
    p.append(bx(m["black"], (0.006, 0.0, 0.0), (0.012, 0.03, 0.02), 0.002))
    p.append(bx(m["tan"], (0.022, 0.0, 0.0), (0.022, 0.07, 0.03), 0.004, seg=2))
    p.append(smooth(cyl(m["dark"], (0.022, 0.036, 0.006), 0.005, 0.004, verts=12, rot=(PI2, 0, 0))))
    p.append(box(m["red"], (0.022, 0.0385, 0.006), (0.005, 0.001, 0.005)))
    p.append(smooth(cyl(m["dark"], (0.022, 0.036, -0.007), 0.004, 0.004, verts=12, rot=(PI2, 0, 0))))
    p.append(bx(m["black"], (0.033, -0.012, 0.0), (0.003, 0.014, 0.012), 0.001))       # switch
    out(p, "Laser")

# ---- 0.57: parts for the laser guns, in their style (light grey plates, orange coils, glowing cells) ----
def holo():
    """Laser-gun holo sight: a light open frame with a thin glass pane, the dot is drawn by the game.
    Origin = the mounting face; axis 0.024 up, pane at y +0.012."""
    reset(); L = laser_mats(); m = M(); p = []
    z = 0.024
    p.append(bx(L["body"], (0, 0.0, 0.004), (0.03, 0.044, 0.008), 0.002, seg=2))        # base
    p.append(bx(L["trim"], (0, 0.0, 0.0085), (0.024, 0.036, 0.003), 0.001))
    for x in (-0.0145, 0.0145):
        p.append(bx(L["body"], (x, 0.008, z), (0.004, 0.012, 0.03), 0.0012))            # side posts
    p.append(bx(L["body"], (0, 0.008, z + 0.0155), (0.033, 0.012, 0.004), 0.0012))     # top bar
    p.append(bx(L["body2"], (0, -0.012, 0.012), (0.024, 0.016, 0.008), 0.0015))         # emitter housing
    p.append(box(L["cell"], (0, -0.004, 0.0165), (0.006, 0.002, 0.002)))                # the emitter
    p.append(bx(L["coil"], (0.017, -0.006, 0.008), (0.004, 0.012, 0.006), 0.001))      # switch
    p.append(box(m["lens"], (0, 0.012, z + 0.001), (0.025, 0.001, 0.026)))              # glass pane
    out(p, "Holo")

def clanek():
    """High-capacity cell: a bigger power pack with glowing windows. Origin = the mounting face,
    the pack hangs down (-Z); the game turns it to a side with PART_AT."""
    reset(); L = laser_mats(); p = []
    p.append(bx(L["trim"], (0, 0.0, -0.003), (0.03, 0.06, 0.006), 0.0015))             # clamp plate
    p.append(bx(L["body"], (0, 0.0, -0.02), (0.038, 0.072, 0.028), 0.005, seg=2))       # pack
    for x in (-0.0192, 0.0192):
        p.append(box(L["cell"], (x, 0.0, -0.02), (0.001, 0.05, 0.012)))                 # glow windows
    for k in range(3):
        p.append(bx(L["coil"], (0, -0.024 + k * 0.024, -0.02), (0.04, 0.006, 0.03), 0.0015))   # bands
    p.append(bx(L["trim"], (0, 0.0, -0.035), (0.03, 0.06, 0.004), 0.0015))             # bottom plate
    p.append(box(L["lens"], (0, -0.0365, -0.02), (0.012, 0.001, 0.006)))                # charge light
    out(p, "Clanek")

def cocka():
    """Focusing lens: an emitter extension over the muzzle, coil rings and a bigger red lens.
    Origin = the muzzle face on the barrel axis."""
    reset(); L = laser_mats(); p = []
    p.append(smooth(ty(L["body2"], -0.012, 0.05, 0.0, 0.021, verts=18)))
    p.append(smooth(tb(L["trim"], (0, 0.05, 0.0), (0, 0.075, 0.0), 0.021, verts=18, r2=0.025)))
    for k in range(3):
        p.append(ring(L["coil"], 0.004 + k * 0.014, 0.0, 0.0225, 0.006, verts=18))
    p.append(ring(L["body"], 0.076, 0.0, 0.026, 0.006, verts=18))
    p.append(cyl(L["lens"], (0, 0.0795, 0.0), 0.018, 0.004, verts=18, rot=(PI2, 0, 0)))
    for k in range(4):
        a = k / 4 * math.tau + math.pi / 4
        p.append(box(L["cell"], (math.cos(a) * 0.021, 0.03, math.sin(a) * 0.021), (0.003, 0.03, 0.003)))
    out(p, "Cocka")

def chladic():
    """Cooling collar for the laser rifle's barrel: orange fins round a sleeve. Origin = the barrel
    axis at the back of the collar."""
    reset(); L = laser_mats(); p = []
    p.append(smooth(ty(L["trim"], 0.0, 0.055, 0.0, 0.025, verts=18)))
    for k in range(6):
        p.append(ring(L["coil"], 0.006 + k * 0.0085, 0.0, 0.034, 0.004, verts=18))
    p.append(bx(L["body"], (0, 0.0275, 0.034), (0.012, 0.055, 0.008), 0.002))          # top spine
    out(p, "Chladic")

# ---- 0.57 (4th step): models for the parts that had only numbers, the heavy guns and the plasma family ----
def zasobnik_r():
    """Rifle: a second magazine coupled to the first (more rounds at hand). Origin = the top of the gun's
    own magazine; the clamp and the spare sit to its right."""
    reset(); m = M(); p = []
    p += mag_curve(m["tan"], (0.034, 0.0, 0.0), n=4, size=(0.03, 0.055, 0.035), lip=m["brass"])
    for z in (-0.03, -0.075):
        p.append(bx(m["black"], (0.017, 0.012 + (-z) * 0.15, z), (0.044, 0.04, 0.012), 0.002))     # coupler clamps
        p.append(screw(m["steel"], (0.017, 0.012 + (-z) * 0.15, z + 0.0065), axis='z'))
    out(p, "Zasobnik_r")

def zasobnik_p():
    """Pistol: an extended base pad that sticks out under the grip. Origin = the bottom of the grip."""
    reset(); m = M(); p = []
    p.append(bx(m["dark"], (0, 0.004, -0.016), (0.022, 0.03, 0.032), 0.002, rot=(-0.25, 0, 0)))
    p.append(bx(m["black"], (0, 0.0, -0.034), (0.031, 0.044, 0.01), 0.002, rot=(-0.25, 0, 0)))
    for k in range(3):
        p.append(bx(m["poly"], (0.0158, 0.004 + k * 0.009, -0.017), (0.001, 0.004, 0.018), 0.0003, rot=(-0.25, 0, 0)))
    out(p, "Zasobnik_p")

def zasobnik_s():
    """Sniper: a longer box magazine - an extension under the gun's own. Origin = its bottom."""
    reset(); m = M(); p = []
    p.append(bx(m["dark"], (0, 0.0, -0.018), (0.03, 0.05, 0.036), 0.003))
    p.append(bx(m["black"], (0, 0.0, -0.038), (0.034, 0.055, 0.006), 0.002))
    p.append(bx(m["steel"], (0.0155, 0.0, -0.018), (0.001, 0.03, 0.02), 0.0003))
    out(p, "Zasobnik_s")

def zasobnik_mg():
    """Minigun: a second ammo section under the box. Origin = the bottom of the gun's ammo box."""
    reset(); m = M(); p = []
    p.append(bx(m["olive"], (0, 0.0, -0.035), (0.1, 0.18, 0.07), 0.008, seg=2))
    p.append(bx(m["olive2"], (0, 0.0, -0.003), (0.104, 0.184, 0.008), 0.002))
    p.append(bx(m["dark"], (-0.052, 0.0, -0.035), (0.006, 0.06, 0.02), 0.002))           # latch
    p.append(bx(m["warn"], (-0.0515, 0.0, -0.06), (0.002, 0.12, 0.012), 0.0005))
    out(p, "Zasobnik_mg")

def dvojnozka():
    """Bipod, legs down and a little forward. Origin = the clamp on the underside of the barrel."""
    reset(); m = M(); p = []
    p.append(bx(m["dark"], (0, 0.0, -0.008), (0.036, 0.03, 0.016), 0.003))
    p.append(smooth(cyl(m["steel"], (0, 0.0, -0.016), 0.006, 0.05, verts=10, rot=(0, PI2, 0))))
    for s in (-1, 1):
        p.append(tb(m["dark"], (0.022 * s, 0.0, -0.016), (0.06 * s, 0.05, -0.2), 0.0065, 8))
        p.append(tb(m["steel"], (0.06 * s, 0.05, -0.2), (0.068 * s, 0.058, -0.24), 0.0045, 8))
        p.append(smooth(sphere(m["rubber"], (0.069 * s, 0.059, -0.245), 0.009, seg=10, rings=6)))
    out(p, "Dvojnozka")

def brzda():
    """Muzzle brake: a block with big side ports. Origin = the end of the barrel."""
    reset(); m = M(); p = []
    p.append(bev(ty(m["dark"], 0.0, 0.085, 0.0, 0.02, verts=8), 0.003))
    for i in range(3):
        for sx in (1, -1):
            p.append(bx(m["black"], (sx * 0.0195, 0.02 + i * 0.024, 0.0), (0.006, 0.013, 0.024), 0.001))
    p.append(cyl(m["black"], (0, 0.086, 0.0), 0.008, 0.002, verts=10, rot=(PI2, 0, 0)))
    out(p, "Brzda")

def kompenzator():
    """Revolver compensator: a short sleeve with ports on top. Origin = the muzzle."""
    reset(); m = M(); p = []
    p.append(smooth(ty(m["chrome"], -0.005, 0.032, 0.0, 0.012, verts=14)))
    for i in range(3):
        p.append(bx(m["black"], (0, 0.004 + i * 0.009, 0.0115), (0.008, 0.004, 0.004), 0.0008))
    p.append(cyl(m["black"], (0, 0.0325, 0.0), 0.0055, 0.002, verts=10, rot=(PI2, 0, 0)))
    out(p, "Kompenzator")

def dalkomer():
    """Laser rangefinder: a box with two lenses, on a side rail. Origin = the rail face, the box to +X."""
    reset(); m = M(); p = []
    p.append(bx(m["black"], (0.005, 0.0, 0.0), (0.01, 0.03, 0.02), 0.002))
    p.append(bx(m["dark"], (0.024, 0.0, 0.0), (0.028, 0.06, 0.034), 0.004, seg=2))
    for z in (0.008, -0.008):
        p.append(smooth(cyl(m["black"], (0.024, 0.031, z), 0.0065, 0.004, verts=12, rot=(PI2, 0, 0))))
        p.append(cyl(m["lens"], (0.024, 0.0335, z), 0.0055, 0.001, verts=12, rot=(PI2, 0, 0)))
    p.append(box(m["red"], (0.024, -0.0305, 0.008), (0.006, 0.001, 0.004)))              # the readout
    p.append(bx(m["black"], (0.024, -0.01, 0.0175), (0.01, 0.012, 0.004), 0.001))        # button
    out(p, "Dalkomer")

def pocitac():
    """Targeting computer: a box with a small green screen facing the shooter and a cable. Origin = the
    mounting face, the box to +X."""
    reset(); m = M(); P = dict(scr=mat2("ScreenGreen", (0.3, 1.0, 0.4), emit=2.5)); p = []
    p.append(bx(m["black"], (0.005, 0.0, 0.0), (0.01, 0.04, 0.03), 0.002))
    p.append(bx(m["olive2"], (0.03, 0.0, 0.0), (0.04, 0.09, 0.05), 0.005, seg=2))
    p.append(box(P["scr"], (0.03, -0.0455, 0.004), (0.03, 0.001, 0.026)))
    p.append(bx(m["black"], (0.03, -0.047, -0.019), (0.034, 0.004, 0.006), 0.001))
    for k in range(3):
        p.append(bx(m["dark"], (0.052, -0.025 + k * 0.012, 0.012), (0.004, 0.006, 0.006), 0.001))
    p.append(tb(m["black"], (0.03, 0.045, -0.01), (0.012, 0.09, -0.03), 0.003, 6))     # the cable
    out(p, "Pocitac")

def nosic():
    """Shotgun side saddle: six shells on the left of the receiver. Origin = the receiver face, to -X."""
    reset(); m = M(); p = []
    p.append(bx(m["black"], (-0.004, 0.0, 0.0), (0.008, 0.11, 0.05), 0.002))
    for i in range(6):
        y = -0.045 + i * 0.018
        p.append(smooth(cyl(m["red"], (-0.017, y, 0.004), 0.0095, 0.05, verts=12)))
        p.append(smooth(cyl(m["brass"], (-0.017, y, -0.024), 0.0098, 0.01, verts=12)))
    p.append(bx(m["black"], (-0.01, 0.0, 0.006), (0.006, 0.112, 0.016), 0.001))
    out(p, "Nosic")

def pazba():
    """Shotgun: a thick recoil pad and a cheek riser band. Origin = the back of the factory butt pad."""
    reset(); m = M(); p = []
    p.append(bx(m["rubber"], (0, -0.014, 0.0), (0.052, 0.028, 0.12), 0.006, seg=2))
    for k in range(6):
        p.append(bx(m["black"], (0, -0.029, -0.045 + k * 0.018), (0.053, 0.002, 0.004), 0.0005))
    p.append(bx(m["poly"], (0, 0.09, 0.07), (0.05, 0.11, 0.02), 0.006, seg=2))           # cheek riser
    for y in (0.05, 0.13):
        p.append(bx(m["black"], (0, y, 0.07), (0.052, 0.008, 0.022), 0.002))
    out(p, "Pazba")

def ergo():
    """Revolver: a rubber grip sleeve with finger grooves. Origin = the middle of the grip."""
    reset(); m = M(); p = []
    g = bx(m["rubber"], (0, 0.0, 0.0), (0.033, 0.046, 0.08), 0.008, seg=2, rot=(-0.35, 0, 0))
    p.append(g)
    for k in range(3):
        p.append(bx(m["black"], (0, 0.024 - k * 0.009, 0.02 - k * 0.022), (0.034, 0.004, 0.008), 0.002, rot=(-0.35, 0, 0)))
    out(p, "Ergo")

def zamerovac():
    """Tactical sight for the heavy guns: a big rectangular window in a sturdy frame. Origin = the mount."""
    reset(); m = M(); p = []
    z = 0.035
    p.append(bx(m["dark"], (0, 0.0, 0.006), (0.04, 0.06, 0.012), 0.003))
    for x in (-0.024, 0.024):
        p.append(bx(m["dark"], (x, 0.01, z), (0.008, 0.02, 0.05), 0.002))
    p.append(bx(m["dark"], (0, 0.01, z + 0.026), (0.056, 0.02, 0.008), 0.002))
    p.append(bx(m["black"], (0, -0.016, 0.02), (0.03, 0.02, 0.018), 0.003))              # emitter box
    p.append(box(m["red"], (0, -0.005, 0.03), (0.004, 0.002, 0.004)))
    p.append(box(m["lens"], (0, 0.012, z), (0.04, 0.001, 0.044)))
    p.append(smooth(cyl(m["black"], (0.03, -0.016, 0.02), 0.006, 0.008, verts=10, rot=(0, PI2, 0))))
    out(p, "Zamerovac")

def stabilizator():
    """Electronic gyro stabiliser hanging under the gun's body. Origin = its mount, the unit hangs to -Z."""
    reset(); m = M(); p = []
    p.append(bx(m["black"], (0, 0.0, -0.005), (0.04, 0.05, 0.01), 0.002))
    p.append(smooth(cyl(m["dark"], (0, 0.0, -0.032), 0.03, 0.045, verts=18)))
    p.append(ring(m["steel"], 0.0, -0.032, 0.031, 0.006, verts=18) if False else smooth(cyl(m["steel"], (0, 0.0, -0.032), 0.031, 0.006, verts=18)))
    p.append(smooth(cyl(m["black"], (0, 0.0, -0.057), 0.024, 0.006, verts=18)))
    p.append(box(m["red"], (0.0305, 0.0, -0.02), (0.002, 0.005, 0.004)))
    p.append(tb(m["black"], (0.0, 0.03, -0.02), (0.0, 0.07, -0.004), 0.003, 6))
    out(p, "Stabilizator")

def chladic_mg():
    """Minigun cooling jacket: a perforated sleeve round the spinning barrels. Origin = the barrel axis at
    its back end."""
    reset(); m = M(); p = []
    p.append(htube(m["olive2"], 0.0, 0.12, 0.0, 0.062, 0.004, verts=18))
    for i in range(4):
        p.append(ring(m["dark"], 0.012 + i * 0.032, 0.0, 0.066, 0.008, verts=18))
    for i in range(3):
        for k in range(6):
            a = k / 6 * math.tau
            p.append(bx(m["black"], (math.cos(a) * 0.065, 0.028 + i * 0.032, math.sin(a) * 0.065), (0.003, 0.016, 0.003), 0.0005, rot=(0, -a, 0)))
    out(p, "Chladic_mg")

def tlumeni():
    """Autocannon recoil buffer: a hydraulic tube on top of the stock. Origin = the top of the stock."""
    reset(); m = M(); p = []
    p.append(bx(m["dark"], (0, 0.0, 0.006), (0.04, 0.2, 0.012), 0.003))
    p.append(smooth(ty(m["steel"], -0.09, 0.08, 0.026, 0.014, verts=14)))
    p.append(smooth(ty(m["black"], -0.02, 0.06, 0.026, 0.017, verts=14)))
    for y in (-0.07, 0.07):
        p.append(bx(m["dark"], (0, y, 0.018), (0.03, 0.016, 0.03), 0.003))
    p.append(box(m["warn"], (0, 0.02, 0.0435), (0.012, 0.03, 0.001)))
    out(p, "Tlumeni")

def nosny():
    """Carrying harness: two swivels and a padded strap sagging between them, on the gun's right side.
    Origin = the rear swivel; the front one is 0.5 m ahead (+Y)."""
    reset(); m = M(); p = []
    for y in (0.0, 0.5):
        p.append(bx(m["steel"], (0.004, y, 0.0), (0.008, 0.02, 0.012), 0.002))
        p.append(torus(m["steel"], (0.012, y, -0.008), 0.008, 0.002, (0, PI2, 0), seg=10))
    n = 14
    for k in range(n):
        t = (k + 0.5) / n
        y, z = t * 0.5, -0.016 - math.sin(t * math.pi) * 0.13
        ang = math.atan2(-math.cos(t * math.pi) * 0.13 * math.pi, 0.5)
        pad = 0.2 < t < 0.8
        p.append(bx(m["olive2"] if pad else m["black"], (0.014, y, z), (0.008 if pad else 0.004, 0.038, 0.04 if pad else 0.025), 0.002, rot=(ang, 0, 0)))
    out(p, "Nosny")

# ---- plasma (alien shell, dark alloy, green core) ----
def _pm():
    m = M()
    return m, dict(core=mat2("PlasmaCore", (0.35, 1.0, 0.45), emit=4.0), shell=mat2("AlienShell", (0.3, 0.33, 0.3), 0.3, 0.6),
                   shell2=mat2("AlienShellDark", (0.17, 0.19, 0.18), 0.3, 0.6), mag=mat2("PlasmaMag", (0.22, 0.24, 0.22), 0.35, 0.7))

def holo_pl():
    """The holo sight in the plasma family's dress: a dark alien frame, green trim. Same axis as "holo"."""
    reset(); m, P = _pm(); p = []
    z = 0.024
    p.append(bx(P["shell2"], (0, 0.0, 0.004), (0.03, 0.044, 0.008), 0.003, seg=2))
    for x in (-0.0145, 0.0145):
        p.append(bx(P["shell"], (x, 0.008, z), (0.004, 0.012, 0.03), 0.0015))
    p.append(bx(P["shell"], (0, 0.008, z + 0.0155), (0.033, 0.012, 0.004), 0.0015))
    p.append(bx(P["shell2"], (0, -0.012, 0.012), (0.024, 0.016, 0.008), 0.002))
    p.append(box(P["core"], (0, -0.004, 0.0165), (0.006, 0.002, 0.002)))
    p.append(box(P["core"], (0, 0.0, 0.0085), (0.02, 0.03, 0.001)))
    p.append(box(m["lens"], (0, 0.012, z + 0.001), (0.025, 0.001, 0.026)))
    out(p, "Holo_pl")

def fokus():
    """Magnetic focuser: a collar of alien rings round the emitter, green coils between them. Origin = the
    emitter's axis at the back of the collar."""
    reset(); m, P = _pm(); p = []
    p.append(htube(P["shell2"], 0.0, 0.07, 0.0, 0.036, 0.004, verts=18))
    for i in range(3):
        p.append(ring(P["shell"], 0.008 + i * 0.027, 0.0, 0.041, 0.01, verts=18))
        if i < 2:
            p.append(ring(P["core"], 0.0215 + i * 0.027, 0.0, 0.039, 0.004, verts=18))
    for k in range(3):
        a = k / 3 * math.tau + PI2
        p.append(bx(P["shell2"], (math.cos(a) * 0.044, 0.04, math.sin(a) * 0.044), (0.006, 0.05, 0.006), 0.001, rot=(0, -a, 0)))
    out(p, "Fokus")

def zasobnik_pl():
    """Plasma: a booster cell clipped under the PL-MAG. Origin = the bottom of the gun's cell."""
    reset(); m, P = _pm(); p = []
    p.append(bx(P["mag"], (0, 0.0, -0.016), (0.032, 0.05, 0.032), 0.004))
    p.append(bx(P["core"], (0.0165, 0.0, -0.016), (0.002, 0.03, 0.018), 0.0005))
    p.append(bx(P["core"], (-0.0165, 0.0, -0.016), (0.002, 0.03, 0.018), 0.0005))
    p.append(bx(P["shell2"], (0, 0.0, -0.035), (0.034, 0.052, 0.006), 0.001))
    out(p, "Zasobnik_pl")

def chladic_pl():
    """Plasma cooler: a collar of dark fins with a green glow between them. Origin = the axis at its back."""
    reset(); m, P = _pm(); p = []
    p.append(smooth(ty(P["shell2"], 0.0, 0.055, 0.0, 0.034, verts=18)))
    for k in range(5):
        p.append(ring(P["shell"], 0.006 + k * 0.011, 0.0, 0.045, 0.004, verts=18))
    p.append(ring(P["core"], 0.0275, 0.0, 0.036, 0.04, verts=18))
    out(p, "Chladic_pl")

ALL = dict(kolimator_t=kolimator_t, kolimator=kolimator, optika=optika, bajonet=bajonet, tlumic=tlumic, rukojet=rukojet, svitilna=svitilna, laser=laser,
           holo=holo, clanek=clanek, cocka=cocka, chladic=chladic,
           zasobnik_r=zasobnik_r, zasobnik_p=zasobnik_p, zasobnik_s=zasobnik_s, zasobnik_mg=zasobnik_mg, dvojnozka=dvojnozka,
           brzda=brzda, kompenzator=kompenzator, dalkomer=dalkomer, pocitac=pocitac, nosic=nosic, pazba=pazba, ergo=ergo,
           zamerovac=zamerovac, stabilizator=stabilizator, chladic_mg=chladic_mg, tlumeni=tlumeni, nosny=nosny,
           holo_pl=holo_pl, fokus=fokus, zasobnik_pl=zasobnik_pl, chladic_pl=chladic_pl)
for k, f in ALL.items():
    if not ONLY or k in ONLY:
        f()
        print("built part", k)

if "--preview" in sys.argv:
    # the rifle with every part on, as the game puts them (Game.PART_AT, Godot -> Blender: x, -z, y)
    at = {"kolimator_t": (0, 0.08, 0.079), "optika": (0, 0.06, 0.079), "bajonet": (0, 0.565, 0.042), "tlumic": (0, 0.725, 0.042),
          "rukojet": (0, 0.33, 0.012), "svitilna": (-0.032, 0.42, 0.042), "laser": (0.032, 0.44, 0.042)}
    reset()
    bpy.ops.import_scene.gltf(filepath=os.path.join(OUTDIR, "rifle.glb"))
    for k in ALL:
        if k not in at or k in ("tlumic", "optika"):
            continue
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=os.path.join(OUTDIR, "part_%s.glb" % k))
        for o in set(bpy.data.objects) - before:
            if o.parent is None:
                o.location = at[k]
    preview(sys.argv[sys.argv.index("--preview") + 1], target=(0, 0.25, 0.05), dist=1.1, angle=0.9, height=0.25, res=(1200, 700))
