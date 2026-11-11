# Side windows of the village cars: make the panes follow the slanted A and C pillars and lean in
# with them (they were upright rectangles sticking out past the pillars). Only vertex positions change
# (islands keep their order, so modely/v_car_*.json still points at the windscreen 85 and rear window 86).
import sys, json, struct, numpy as np
sys.path.insert(0, __import__('os').path.dirname(__file__)); import zfight_glb as g
def lerp(a, b, t): return a + (b - a) * t
def run(path):
    raw = bytearray(open(path, 'rb').read())
    jl = struct.unpack('<I', raw[12:16])[0]; binoff = 20 + jl + 8
    j = json.loads(bytes(raw[20:20 + jl])); bin_ = bytes(raw[binoff:])
    mats = [m['name'] for m in j['materials']]
    prims = g.tris_raw(j, bin_)
    n = 0
    for (W, F, mat, (mi, pi), ni) in prims:
        if mats[mat] != 'VCarGlass': continue
        M = g.world_of(j, ni); Minv = np.linalg.inv(M)
        ai = j['meshes'][mi]['primitives'][pi]['attributes']['POSITION']
        a = j['accessors'][ai]; bv = j['bufferViews'][a['bufferView']]
        o = bv.get('byteOffset', 0) + a.get('byteOffset', 0); st = bv.get('byteStride', 0) or 12
        pos = g.acc(j, bin_, ai).astype(float)
        for vi, p in enumerate(W):
            x, h, z = p
            if abs(abs(x) - 0.73) > 0.02 or not (0.9 < h < 1.45): continue
            s = 1 if x > 0 else -1
            t = (h - 0.95) / 0.45
            outer = abs(x) > 0.73
            # lean in with the pillars (0.75 -> 0.70 from sill to roof), pillars sit on the outside of the glass
            nx = s * (lerp(0.735, 0.685, t) + (0.01 if outer else -0.01))
            nz = z
            if z < -0.4:                     # front pane, front edge -> along the A pillar (Godot z = -Blender y)
                nz = -lerp(0.62, 0.40, t)
            elif z > 1.1:                    # rear pane, rear edge -> along the C pillar
                nz = -lerp(-1.45, -1.20, t)
            q = np.array([nx, h, nz, 1.0]); L = Minv @ q
            pos[vi] = L[:3]; n += 1
        for vi in range(len(pos)):
            struct.pack_into('<3f', raw, binoff + o + vi * st, *pos[vi])
        a['min'] = [float(v) for v in pos.min(0)]; a['max'] = [float(v) for v in pos.max(0)]
    js = json.dumps(j, separators=(',', ':')).encode(); js += b' ' * ((4 - len(js) % 4) % 4)
    body = bytes(raw[20 + jl:])
    out = bytearray(raw[:12]) + struct.pack('<I', len(js)) + b'JSON' + js + body
    struct.pack_into('<I', out, 8, len(out))
    open(path, 'wb').write(out)
    print(path, 'moved', n)
for p in sys.argv[1:]: run(p)
