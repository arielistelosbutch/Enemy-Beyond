# Nádor from afk.ai: a spring-bone chain in each tentacle (tent_<i>_0..3, tip under hips), so the
# game swings them as it floats (alien._afk_springs) and lays them out when it dies.
#   python3 afk_nador.py <nador-animated.glb> <out = animace/afk_nador.glb>
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from afk_glb import *
NODE = 43       # the tentacle mesh (material NadTent)

def tentacles(P, cs, cut=-0.3, touch=0.012):
    """The tentacles are chains of small pieces: pieces below the top that touch belong together,
    the pieces at the top go to the tentacle they touch."""
    C = np.array([P[c].mean(0) for c in cs]); n = len(cs)
    par = list(range(n))
    def f(x):
        while par[x] != x: par[x] = par[par[x]]; x = par[x]
        return x
    low = [i for i in range(n) if C[i][1] < cut]
    for ia, a in enumerate(low):
        for b in low[ia + 1:]:
            if np.linalg.norm(C[a] - C[b]) > 0.2: continue
            if np.linalg.norm(P[cs[a]][:, None, :] - P[cs[b]][None, :, :], axis=2).min() < touch:
                par[f(a)] = f(b)
    groups = {}
    for i in low: groups.setdefault(f(i), []).append(i)
    gl = list(groups.values())
    for i in range(n):
        if C[i][1] >= cut:
            def dist(k):
                near = [j for j in gl[k] if np.linalg.norm(C[i] - C[j]) < 0.3]
                if not near: return 9.0
                return min(np.linalg.norm(P[cs[i]][:, None, :] - P[cs[j]][None, :, :], axis=2).min() for j in near)
            gl[min(range(len(gl)), key=dist)].append(i)
    return gl

g = GLB(sys.argv[1]); NB = 4
assert g.j['materials'][g.j['meshes'][g.j['nodes'][NODE]['mesh']]['primitives'][0]['material']]['name'] == 'NadTent'
P, cs = pieces(g, NODE)
gl = tentacles(P, cs)
gl.sort(key=lambda gs: np.arctan2(np.vstack([P[cs[i]] for i in gs])[:, 2].mean(), np.vstack([P[cs[i]] for i in gs])[:, 0].mean()))
specs = []; chains = []
for i, gs in enumerate(gl):
    vs = np.concatenate([cs[k] for k in gs]); Q = P[vs]
    ytop = Q[:, 1].max(); ybot = Q[:, 1].min(); y0 = ytop - 0.05
    pts = []
    for y in np.linspace(y0, ybot, NB + 1):
        sel = Q[np.abs(Q[:, 1] - y) < 0.04]
        if len(sel) < 3: sel = Q[np.argsort(np.abs(Q[:, 1] - y))[:20]]
        pts.append(sel.mean(0))
    names = ['tent_%d_%d' % (i, k) for k in range(NB)] + ['tent_%d_tip' % i]
    par = 'hips'
    for nm, p in zip(names, pts):
        specs.append((nm, p, par)); par = nm
    chains.append((vs, y0, ybot, names))
add_joints(g, specs, 'hips')
jn = joint_names(g, g.j['nodes'][NODE]['skin'])
jpos = {n: i for i, n in enumerate(jn)}
J, W = get_weights(g, NODE); J = J.copy(); W = W.copy()
for vs, y0, ybot, names in chains:
    for v in vs:
        y = P[v, 1]; u = (y0 - y) / (y0 - ybot)
        new = {jpos[names[k]]: w for k, w in chain_weights(min(max(u, 0), 1), NB).items()}
        b = np.clip((y0 + 0.05 - y) / 0.08, 0, 1)      # the very top keeps the body's weights
        mix = {}
        for a, w in zip(J[v], W[v]):
            if w > 0: mix[a] = mix.get(a, 0) + w * (1 - b)
        for a, w in new.items(): mix[a] = mix.get(a, 0) + w * b
        J[v], W[v] = top4(mix)
set_weights(g, NODE, J, W)
g.save(sys.argv[2])
print('tentacles', len(chains))
