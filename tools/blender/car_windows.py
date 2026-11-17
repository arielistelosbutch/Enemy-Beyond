# Windscreen and rear window of the village cars, baked into the model (Ari, 17. 11.: "na parkovišti a
# v dílcích mají zase otočená okna ven"). In the GLB both panes lean the wrong way (top out over the
# bonnet / the boot); Ari turned them in the Dílna (modely/v_car_<colour>.json, parts Auto_<Colour>:85
# and :86), so they only sat right where those edits were applied. This turns the two panes in the
# model itself by the same angles (around the pane's own centre, like ModelMods does) - vertices and
# normals, count and order unchanged - and takes the two entries out of the json (else twice).
#   python3 tools/blender/car_windows.py <repo root> red blue beige
import sys, os, json, struct, math, numpy as np
sys.path.insert(0, os.path.dirname(__file__)); import zfight_glb as g

def islands(pos, idx):
    out, cur, tris = [], set(), []
    for t in range(0, len(idx), 3):
        ks = [tuple(np.round(pos[idx[t + k]] * 10000).astype(int)) for k in range(3)]
        if not any(k in cur for k in ks) and tris:
            out.append(tris); cur = set(); tris = []
        cur.update(ks); tris += [int(idx[t]), int(idx[t + 1]), int(idx[t + 2])]
    if tris: out.append(tris)
    return out

def basis(xf):
    # Godot Basis.from_euler (YXZ order) * scale
    rx, ry, rz = [math.radians(float(v)) for v in xf[3:6]]
    X = np.array([[1, 0, 0], [0, math.cos(rx), -math.sin(rx)], [0, math.sin(rx), math.cos(rx)]])
    Y = np.array([[math.cos(ry), 0, math.sin(ry)], [0, 1, 0], [-math.sin(ry), 0, math.cos(ry)]])
    Z = np.array([[math.cos(rz), -math.sin(rz), 0], [math.sin(rz), math.cos(rz), 0], [0, 0, 1]])
    return Y @ X @ Z @ np.diag([float(v) for v in xf[6:9]])

def run(root, colour):
    path = os.path.join(root, 'assets/models/v_car_%s.glb' % colour)
    jpath = os.path.join(root, 'modely/v_car_%s.json' % colour)
    mods = json.load(open(jpath))
    piece = 'Auto_' + colour.capitalize()
    turn = {int(k.split(':')[1]): v['xf'] for k, v in mods['parts'].items() if k.split(':')[0] == piece}
    raw = bytearray(open(path, 'rb').read())
    jl = struct.unpack('<I', raw[12:16])[0]; binoff = 20 + jl + 8
    j = json.loads(bytes(raw[20:20 + jl])); bin_ = bytes(raw[binoff:])
    done = []
    for mesh in j['meshes']:
        if mesh.get('name') != piece: continue
        base = 0
        for pr in mesh['primitives']:
            pos = g.acc(j, bin_, pr['attributes']['POSITION']).astype(float).copy()
            nrm = g.acc(j, bin_, pr['attributes']['NORMAL']).astype(float).copy() if 'NORMAL' in pr['attributes'] else None
            idx = g.acc(j, bin_, pr['indices']).reshape(-1)
            isl = islands(pos, idx)
            for k, tris in enumerate(isl):
                gi = base + k
                if gi not in turn: continue
                xf = turn[gi]
                vs = sorted(set(tris)); P = pos[vs]
                c = (P.min(0) + P.max(0)) / 2
                B = basis(xf); NB = np.linalg.inv(B).T; off = np.array([float(v) for v in xf[0:3]])
                for v in vs:
                    pos[v] = c + B @ (pos[v] - c) + off
                    if nrm is not None:
                        n = NB @ nrm[v]; nrm[v] = n / np.linalg.norm(n)
                done.append(gi)
            base += len(isl)
            for key, arr in (('POSITION', pos), ('NORMAL', nrm)):
                if arr is None: continue
                a = j['accessors'][pr['attributes'][key]]; bv = j['bufferViews'][a['bufferView']]
                o = bv.get('byteOffset', 0) + a.get('byteOffset', 0); st = bv.get('byteStride', 0) or 12
                for vi in range(len(arr)):
                    struct.pack_into('<3f', raw, binoff + o + vi * st, *arr[vi])
                if key == 'POSITION':
                    a['min'] = [float(v) for v in arr.min(0)]; a['max'] = [float(v) for v in arr.max(0)]
    js = json.dumps(j, separators=(',', ':')).encode(); js += b' ' * ((4 - len(js) % 4) % 4)
    out = bytearray(raw[:12]) + struct.pack('<I', len(js)) + b'JSON' + js + bytes(raw[20 + jl:])
    struct.pack_into('<I', out, 8, len(out))
    open(path, 'wb').write(out)
    for gi in done:
        del mods['parts']['%s:%d' % (piece, gi)]
    json.dump(mods, open(jpath, 'w'), indent=2)
    print(path, 'turned islands', done)

for c in sys.argv[2:]:
    run(sys.argv[1], c)
