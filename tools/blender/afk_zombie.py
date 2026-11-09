# Nakažený (zombie) from afk.ai: Ari's export has no strike, so the Líhavec's two strikes
# (same afk humanoid rig) are moved over onto it under their own names.
#   python3 afk_zombie.py <Lihavec_complet.glb> <zombie-animated.glb> <out = animace/afk_zombie.glb>
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from afk_glb import GLB, retarget
src = GLB(sys.argv[1]); dst = GLB(sys.argv[2])
B = ['pelvis', 'spine_01', 'spine_02', 'spine_03', 'neck_01', 'head', 'clavicle_l', 'upperarm_l', 'lowerarm_l', 'hand_l',
     'clavicle_r', 'upperarm_r', 'lowerarm_r', 'hand_r', 'thigh_l', 'calf_l', 'foot_l', 'ball_l', 'thigh_r', 'calf_r', 'foot_r', 'ball_r']
names = {n.get('name') for n in dst.j['nodes']}
BM = {b: b for b in B if b in names}
for a in ['Zombie_Scratch', 'Hook_Lead']:
    print(a, retarget(src, a, dst, BM, 'pelvis', 'pelvis', a))
dst.save(sys.argv[3])
