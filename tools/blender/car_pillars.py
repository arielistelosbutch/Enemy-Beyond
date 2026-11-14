# Window pillars of the village cars (v_car_red/blue/beige): they were straight slabs standing out
# past the roof - from the side and from behind the C pillars poked above and beside the roof and the
# windows looked broken (Ari, 13. 11.: "červená auta mají pořád ty okna špatná").
# The pillars (A, B, C on both sides = 12-triangle islands of the body paint) now lean in with the side
# glass (car_glass.py) so their top ends at the roof edge, and the C pillar's top no longer runs past
# the back of the roof. Only vertex positions change (count and order stay: modely/v_car_*.json still
# work). Run after car_glass.py, then zfight_glb.py --fix:
#   python3 tools/blender/car_pillars.py assets/models/v_car_red.glb assets/models/v_car_blue.glb assets/models/v_car_beige.glb
import sys, os, json, struct, numpy as np
sys.path.insert(0, os.path.dirname(__file__)); import zfight_glb as g

ROOF_X = 0.69      # half width of the roof
ROOF_END = 1.20    # back edge of the roof (Godot z, the rear is +z)
LEAN = 0.058       # how much the pillar top moves in (sill 0.95 m -> roof 1.44 m)

def islands(pos, idx):
    out, cur, tris = [], set(), []
    for t in range(0, len(idx), 3):
        ks = [tuple(np.round(pos[idx[t + k]] * 10000).astype(int)) for k in range(3)]
        if not any(k in cur for k in ks) and tris:
            out.append(tris); cur = set(); tris = []
        cur.update(ks); tris += [int(idx[t]), int(idx[t + 1]), int(idx[t + 2])]
    if tris: out.append(tris)
    return out

def run(path):
    raw = bytearray(open(path, 'rb').read())
    jl = struct.unpack('<I', raw[12:16])[0]; binoff = 20 + jl + 8
    j = json.loads(bytes(raw[20:20 + jl])); bin_ = bytes(raw[binoff:])
    mats = [m['name'] for m in j['materials']]
    n = 0
    for mesh in j['meshes']:
        for pr in mesh['primitives']:
            mat = mats[pr.get('material', 0)]
            if not mat.startswith('VCar') or mat in ('VCarGlass',):
                continue
            ai = pr['attributes']['POSITION']
            a = j['accessors'][ai]; bv = j['bufferViews'][a['bufferView']]
            o = bv.get('byteOffset', 0) + a.get('byteOffset', 0); st = bv.get('byteStride', 0) or 12
            pos = g.acc(j, bin_, ai).astype(float).copy()
            idx = g.acc(j, bin_, pr['indices']).reshape(-1)
            for tris in islands(pos, idx):
                vs = sorted(set(tris)); P = pos[vs]
                lo, hi = P.min(0), P.max(0)
                # a pillar: 12 triangles, at the side, from the sill up to the roof
                if len(tris) != 36 or hi[1] - lo[1] < 0.4 or min(abs(lo[0]), abs(hi[0])) < 0.6 or lo[1] < 0.85:
                    continue
                s = 1.0 if hi[0] > 0 else -1.0
                rear = lo[2] > 1.0
                over = (hi[2] - ROOF_END) if rear else 0.0
                for v in vs:
                    x, y, z = pos[v]
                    t = min(max((y - 0.95) / 0.49, 0.0), 1.0)
                    x = s * (abs(x) - LEAN * t)
                    if rear and over > 0 and y > 1.4:
                        # the top end stops at the back of the roof (it ran 8 cm past it)
                        z = min(z, ROOF_END)
                    pos[v] = (x, y, z)
                n += 1
            for vi in range(len(pos)):
                struct.pack_into('<3f', raw, binoff + o + vi * st, *pos[vi])
            a['min'] = [float(v) for v in pos.min(0)]; a['max'] = [float(v) for v in pos.max(0)]
    js = json.dumps(j, separators=(',', ':')).encode(); js += b' ' * ((4 - len(js) % 4) % 4)
    out = bytearray(raw[:12]) + struct.pack('<I', len(js)) + b'JSON' + js + bytes(raw[20 + jl:])
    struct.pack_into('<I', out, 8, len(out))
    open(path, 'wb').write(out)
    print(path, 'pillars', n)

for p in sys.argv[1:]:
    run(p)
