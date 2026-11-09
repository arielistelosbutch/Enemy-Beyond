# Adds the movements of other afk exports of the same model (same rig) to one file.
#   python3 afk_merge.py <base.glb> <out.glb> <extra.glb>:<Anim>[=<NewName>] ...
# e.g. afk_merge.py ohnivec-animated.glb afk_ohnivec.glb ohnivec-move.glb:Walk ohnivec-death.glb:Death
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from afk_glb import GLB
base = GLB(sys.argv[1]); out = sys.argv[2]
bidx = {n.get('name'): i for i, n in enumerate(base.j['nodes'])}
for spec in sys.argv[3:]:
    path, an = spec.rsplit(':', 1)
    new = an
    if '=' in an:
        an, new = an.split('=', 1)
    src = GLB(path)
    a = [x for x in src.j['animations'] if x['name'] == an][0]
    base.j['animations'] = [x for x in base.j['animations'] if x['name'] != new]
    samplers = []; channels = []
    for c in a['channels']:
        nm = src.j['nodes'][c['target']['node']].get('name')
        if nm not in bidx:
            continue
        s = a['samplers'][c['sampler']]
        acc = src.j['accessors'][s['output']]
        t = base.add(src.read(s['input']), 5126, 'SCALAR', minmax=True)
        v = base.add(src.read(s['output']), 5126, acc['type'])
        samplers.append({'input': t, 'output': v, 'interpolation': s.get('interpolation', 'LINEAR')})
        channels.append({'sampler': len(samplers) - 1, 'target': {'node': bidx[nm], 'path': c['target']['path']}})
    base.j['animations'].append({'name': new, 'channels': channels, 'samplers': samplers})
    print(new, len(channels))
base.save(out)
