"""Transporty (Čáp, Kondor, Pelikán): oddělí spuštěnou zadní rampu z jedné sítě do vlastního uzlu,
aby ji hra mohla za letu zavřít a spustit až po přistání (Game.ship_ramp).
Výsledek: uzel "Ramp" (kloub = horní hrana rampy u podlahy) -> "RampMesh" (díly rampy) a uzel
"RampRams" (hydraulické písty, za letu skryté). Mění se jen indexy trojúhelníků (vrcholy, pořadí
a počet zůstávají), takže zfight opravy i modely/*.json platí dál.
Spuštění: python3 tools/blender/ramp_split.py assets/models/heli.glb [out.glb]   (bez out = na místě)
Po přegenerování heli.py / props.py / craft2.py (a zfight_glb.py --fix) spustit znovu."""
import sys, os, numpy as np
sys.path.insert(0, os.path.dirname(__file__))
from afk_glb import GLB

def islands(pos, tris):
    """Ostrůvky trojúhelníků: spojené přes společné vrcholy (i svařené podle polohy)."""
    key = {}
    weld = np.zeros(len(pos), dtype=np.int64)
    for i, p in enumerate(np.round(pos * 1e4).astype(np.int64)):
        weld[i] = key.setdefault(tuple(p), len(key))
    par = list(range(len(key)))
    def f(a):
        while par[a] != a:
            par[a] = par[par[a]]
            a = par[a]
        return a
    for t in tris:
        a, b, c = f(weld[t[0]]), f(weld[t[1]]), f(weld[t[2]])
        par[b] = a
        par[f(c)] = a
    return np.array([f(weld[t[0]]) for t in tris])

def ramp_part(lo, hi):
    """Díl rampy: celý za zadní hranou podlahy (z > 3,9), nízko (y < 0,45), uvnitř šířky otvoru."""
    return lo[2] > 3.88 and hi[1] < 0.45 and lo[1] > -0.6 and max(abs(lo[0]), abs(hi[0])) < 1.62

def ram_part(lo, hi):
    """Píst: šikmo od rámu (y ~1,3, z ~4) dolů k rampě, kousek od boku otvoru."""
    return lo[2] > 3.85 and hi[2] < 5.1 and lo[1] > 0.05 and hi[1] < 1.45 and 1.25 < abs(lo[0]) and abs(hi[0]) < 1.55 and (lo[0] > 0) == (hi[0] > 0)

def run(src, out):
    g = GLB(src)
    if any(n.get('name') == 'Ramp' for n in g.j['nodes']):
        print(src, ': rampa uz je oddelena'); return
    body = 0
    mi = g.j['nodes'][body]['mesh']
    mesh = g.j['meshes'][mi]
    keep_p, ramp_p, rams_p = [], [], []
    hinge = []
    for pr in mesh['primitives']:
        pos = g.read(pr['attributes']['POSITION'])
        tris = g.read(pr['indices']).reshape(-1, 3)
        isl = islands(pos, tris)
        cls = np.zeros(len(tris), dtype=np.int64)
        for k in np.unique(isl):
            sel = isl == k
            v = pos[np.unique(tris[sel])]
            lo, hi = v.min(0), v.max(0)
            if ramp_part(lo, hi):
                cls[sel] = 1
                if hi[0] - lo[0] > 2.8 and hi[2] - lo[2] > 2.0:
                    hinge.append(v)           # samotná deska rampy
            elif ram_part(lo, hi): cls[sel] = 2
        for c, lst in ((0, keep_p), (1, ramp_p), (2, rams_p)):
            t = tris[cls == c]
            if len(t) == 0: continue
            p2 = {k: v for k, v in pr.items() if k != 'indices'}
            p2['indices'] = g.add(t.reshape(-1), 5125, 'SCALAR', 34963)
            lst.append(p2)
    if not ramp_p:
        print(src, ': rampa nenalezena'); return
    hv = np.concatenate(hinge)
    zf = hv[:, 2].min()
    near = hv[hv[:, 2] < zf + 0.08]
    hp = [0.0, float((near[:, 1].min() + near[:, 1].max()) / 2), float(zf)]
    mesh['primitives'] = keep_p
    g.j['meshes'].append({'name': 'RampMesh', 'primitives': ramp_p})
    nodes = g.j['nodes']
    rm = len(nodes)
    nodes.append({'name': 'RampMesh', 'mesh': len(g.j['meshes']) - 1, 'translation': [-hp[0], -hp[1], -hp[2]]})
    nodes.append({'name': 'Ramp', 'translation': hp, 'children': [rm]})
    kids = [rm + 1]
    if rams_p:
        g.j['meshes'].append({'name': 'RampRams', 'primitives': rams_p})
        nodes.append({'name': 'RampRams', 'mesh': len(g.j['meshes']) - 1})
        kids.append(rm + 2)
    nodes[body].setdefault('children', []).extend(kids)
    g.save(out)
    tri = lambda ps: sum(g.j['accessors'][p['indices']]['count'] // 3 for p in ps)
    print('%s: rampa %d troj., pisty %d troj., kloub %s' % (os.path.basename(src), tri(ramp_p), tri(rams_p), [round(x, 3) for x in hp]))

if __name__ == '__main__':
    run(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else sys.argv[1])
