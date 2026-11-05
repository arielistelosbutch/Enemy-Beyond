"""Enemy Beyond - the aliens' own guns as a mercenary picks them up (0.52 rework, own designs):
the same dark violet-black alloy as their ships, smooth lofted shells with bone-pale inlays, violet
light in the coils, the green glow of the Moskovium cell where a magazine would be, grips made for a
narrower hand. No stock. Same sizes and grip points as before.
Muzzle +Y, origin at the right-hand grip.
Run: python3 tools/blender/alien_arms.py <outdir> [--gallery out.png]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from kit import *

ARGS = [a for a in sys.argv[1:] if not a.startswith("--") and not a.endswith(".png")]
OUTDIR = ARGS[0] if ARGS else "."

def mats():
    return dict(
        shell=mat2("XenoShell", (0.17, 0.14, 0.2), 0.3, 0.7),
        dark=mat2("XenoDark", (0.07, 0.06, 0.09), 0.35, 0.6),
        bone=mat2("XenoBone", (0.55, 0.52, 0.46), 0.35),
        glow=mat2("XenoGlow", (0.75, 0.3, 1.0), emit=5.0),
        dim=mat2("XenoGlowDim", (0.5, 0.18, 0.7), emit=1.8),
        green=mat2("XenoCore", (0.35, 1.0, 0.5), emit=4.0),
        lens=mat2("XenoLensGlass", (0.25, 0.9, 0.5), 0.05, emit=1.0),
    )

def save(parts, name):
    o = join(parts, name)
    export_glb(os.path.join(OUTDIR, name.lower() + ".glb"), [o])

def grip(m, c, h, ang=-0.4, w=0.024, d=0.032):
    """A slim raked grip: tapered tube segments down and back from c, pale finger ridges in front."""
    out = []
    rings = []
    for k in range(5):
        t = k / 4
        z = -t * h
        y = z * math.tan(abs(ang)) * 0.6               # the bottom sits further back (a raked grip)
        rings.append((c[0], c[1] + y, c[2] + z, (w + d) / 4 * (1.05 - 0.2 * t)))
    for k in range(len(rings) - 1):
        x0, y0, z0, r0 = rings[k]
        x1, y1, z1, r1 = rings[k + 1]
        out.append(tb(m["dark"], (x0, y0, z0), (x1, y1, z1), r0, 12, r2=r1))
        out.append(ball(m["dark"], (x1, y1, z1), r1, seg=12, rings=8))
    for k in range(3):                                   # finger ridges
        x, y, z, r = rings[k + 1]
        out.append(ball(m["bone"], (x, y + r * 0.85, z + 0.004), 0.008, (1.6, 0.8, 0.8), seg=10, rings=6))
    return out

def a_pistol():
    reset(); m = mats(); p = []
    # a tapering lofted body, a bulb at the rear, three violet rings, the emitter
    p.append(loft(m["shell"], [(-0.06, 0, 0.045, 0.012, 0.012), (-0.045, 0, 0.045, 0.032, 0.036), (0.0, 0, 0.044, 0.034, 0.038),
                               (0.1, 0, 0.042, 0.028, 0.03), (0.18, 0, 0.041, 0.02, 0.021), (0.205, 0, 0.041, 0.016, 0.016)], verts=18))
    p.append(loft(m["bone"], [(-0.03, 0, 0.074, 0.008, 0.004), (0.04, 0, 0.078, 0.012, 0.006), (0.15, 0, 0.06, 0.006, 0.004)], verts=10))
    for i in range(3):
        y = 0.04 + i * 0.045
        r = 0.032 - i * 0.004
        p.append(torus(m["dark"], (0, y, 0.042), r, 0.006, rot=(PI2, 0, 0), seg=18))
        p.append(torus(m["glow"], (0, y + 0.008, 0.042), r * 0.98, 0.003, rot=(PI2, 0, 0), seg=18))
    p.append(tb(m["dark"], (0, 0.2, 0.041), (0, 0.225, 0.041), 0.012, 12))
    p.append(ball(m["green"], (0, 0.226, 0.041), 0.009))
    p.append(ball(m["green"], (0, -0.01, 0.012), 0.018, (0.8, 1.3, 0.8)))         # the cell under the body
    p.append(ball(m["dark"], (0, -0.01, 0.01), 0.021, (0.9, 1.1, 0.6)))
    p.extend(grip(m, (0, -0.012, 0.01), 0.075, -0.45))
    p.append(tb(m["bone"], (0, 0.035, 0.02), (0, 0.035, -0.008), 0.004, 8))         # a trigger "stud"
    p.append(loft(m["shell"], [(0.0, 0, -0.012, 0.006, 0.004), (0.04, 0, -0.012, 0.007, 0.004), (0.06, 0, 0.012, 0.006, 0.004)], verts=8))
    save(p, "A_pistol")

def a_rifle():
    reset(); m = mats(); p = []
    p.append(loft(m["shell"], [(-0.17, 0, 0.04, 0.012, 0.012), (-0.14, 0, 0.042, 0.036, 0.042), (-0.05, 0, 0.045, 0.034, 0.042),
                               (0.12, 0, 0.044, 0.032, 0.038), (0.3, 0, 0.044, 0.028, 0.032), (0.45, 0, 0.045, 0.022, 0.024),
                               (0.6, 0, 0.045, 0.014, 0.015)], verts=20))
    p.append(loft(m["dark"], [(-0.1, 0, 0.083, 0.008, 0.006), (0.0, 0, 0.088, 0.016, 0.01), (0.3, 0, 0.08, 0.014, 0.008),
                              (0.4, 0, 0.068, 0.006, 0.004)], verts=12))                       # top spine
    for k in range(5):
        p.append(bx(m["glow"], (0, 0.02 + k * 0.06, 0.09), (0.004, 0.02, 0.006), 0.001))      # slits on the spine
    for side in (1, -1):
        p.append(loft(m["bone"], [(-0.12, 0.034 * side, 0.045, 0.004, 0.012), (0.0, 0.036 * side, 0.046, 0.005, 0.016),
                                  (0.2, 0.032 * side, 0.045, 0.004, 0.012), (0.3, 0.029 * side, 0.045, 0.002, 0.006)], verts=8))
    for i in range(4):                                                                          # the coil rings
        y = 0.08 + i * 0.07
        r = 0.04 - i * 0.003
        p.append(torus(m["dark"], (0, y, 0.045), r, 0.007, rot=(PI2, 0, 0), seg=20))
        p.append(torus(m["glow"], (0, y + 0.009, 0.045), r * 0.97, 0.0035, rot=(PI2, 0, 0), seg=20))
    p.append(tb(m["dark"], (0, 0.59, 0.045), (0, 0.625, 0.045), 0.016, 12, r2=0.012))
    p.append(ball(m["green"], (0, 0.626, 0.045), 0.012))
    p.append(ball(m["lens"], (0, 0.18, 0.1), 0.012, (1, 2.0, 1)))                              # a sight bulb
    # the green cell in a cradle where a magazine would be
    p.append(tb(m["dark"], (0, 0.09, 0.02), (0, 0.09, -0.04), 0.024, 14))
    p.append(tb(m["green"], (0, 0.09, 0.0), (0, 0.09, -0.035), 0.017, 12))
    p.extend(grip(m, (0, 0.0, 0.01), 0.09, -0.35, w=0.026, d=0.036))
    p.append(loft(m["shell"], [(0.0, 0, -0.014, 0.006, 0.004), (0.045, 0, -0.014, 0.007, 0.004), (0.065, 0, 0.012, 0.006, 0.004)], verts=8))
    # the fore grip: a hooked fin under the barrel
    p.append(loft(m["dark"], [(0.27, 0, 0.0, 0.016, 0.01), (0.3, 0, -0.04, 0.02, 0.016), (0.33, 0, -0.05, 0.016, 0.012), (0.35, 0, -0.03, 0.012, 0.008)], verts=12))
    for k in range(3):
        p.append(ball(m["bone"], (0, 0.3 + k * 0.012, -0.045 + k * 0.005), 0.006, (1.5, 0.6, 0.6), seg=8, rings=6))
    save(p, "A_rifle")

def a_heavy():
    reset(); m = mats(); p = []
    p.append(loft(m["shell"], [(-0.17, 0, 0.05, 0.03, 0.03), (-0.12, 0, 0.05, 0.068, 0.07), (0.1, 0, 0.05, 0.066, 0.066),
                               (0.4, 0, 0.05, 0.056, 0.056), (0.5, 0, 0.05, 0.05, 0.05)], verts=24))
    p.append(loft(m["dark"], [(0.46, 0, 0.05, 0.05, 0.05), (0.52, 0, 0.05, 0.046, 0.046), (0.58, 0, 0.05, 0.03, 0.03), (0.59, 0, 0.05, 0.012, 0.012)], verts=20))
    for k in range(6):                                                                          # muzzle vents
        a = TAU * k / 6
        p.append(bx(m["glow"], (math.cos(a) * 0.044, 0.54, 0.05 + math.sin(a) * 0.044), (0.008, 0.03, 0.008), 0.002))
    for i in range(5):                                                                          # big coils
        y = -0.04 + i * 0.1
        r = 0.07 - i * 0.002
        p.append(torus(m["dark"], (0, y, 0.05), r, 0.01, rot=(PI2, 0, 0), seg=24))
        p.append(torus(m["glow"] if i % 2 == 0 else m["dim"], (0, y + 0.013, 0.05), r * 0.97, 0.005, rot=(PI2, 0, 0), seg=24))
    for side in (1, -1):                                                                        # bone ribs along the sides
        for k in range(3):
            p.append(loft(m["bone"], [(-0.1 + k * 0.17, 0.066 * side, 0.05, 0.006, 0.03), (-0.03 + k * 0.17, 0.068 * side, 0.05, 0.007, 0.034),
                                      (0.04 + k * 0.17, 0.064 * side, 0.05, 0.005, 0.026)], verts=8))
    # the core at the back: a green sphere in a cage of claws
    p.append(ball(m["green"], (0, -0.19, 0.05), 0.05, seg=18, rings=12))
    for k in range(4):
        a = TAU * k / 4 + 0.785
        p.append(tb(m["dark"], (math.cos(a) * 0.05, -0.15, 0.05 + math.sin(a) * 0.05), (math.cos(a) * 0.035, -0.24, 0.05 + math.sin(a) * 0.035), 0.008, 8, r2=0.003))
    p.append(loft(m["dark"], [(-0.05, 0, 0.12, 0.012, 0.006), (0.1, 0, 0.125, 0.025, 0.012), (0.3, 0, 0.115, 0.02, 0.01), (0.38, 0, 0.1, 0.006, 0.004)], verts=12))   # carry spine
    p.append(ball(m["lens"], (0, 0.15, 0.14), 0.016, (1, 2.0, 1)))
    p.extend(grip(m, (0, 0.0, 0.0), 0.095, -0.35, w=0.03, d=0.04))
    p.append(loft(m["shell"], [(0.0, 0, -0.016, 0.007, 0.005), (0.05, 0, -0.016, 0.008, 0.005), (0.07, 0, 0.0, 0.007, 0.005)], verts=8))
    p.append(loft(m["dark"], [(0.28, 0, 0.0, 0.02, 0.012), (0.31, 0, -0.045, 0.024, 0.018), (0.35, 0, -0.06, 0.02, 0.015), (0.37, 0, -0.03, 0.014, 0.01)], verts=12))
    save(p, "A_heavy")

if __name__ == "__main__":
    a_pistol(); a_rifle(); a_heavy()
    print("built alien arms")
    if "--gallery" in sys.argv:
        out = sys.argv[sys.argv.index("--gallery") + 1]
        gun_gallery(out, [os.path.join(OUTDIR, n + ".glb") for n in ("a_pistol", "a_rifle", "a_heavy")], cols=3, dx=0.9)
