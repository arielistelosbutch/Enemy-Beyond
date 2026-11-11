# 0.62: movements an afk export lacks, borrowed from another export on the same afk humanoid rig
# (the bones are the same, the rest pose differs: moved over by afk_glb.retarget, under the names given).
#   python3 afk_borrow.py <src.glb> <dst.glb> <out.glb> Anim[=NewName] ...
# Used for the hit reactions of the Nakažený and the Líhavec (theirs have none), taken from the
# Ještěřan (jesteran_v2_complet.glb):
#   afk_borrow.py jesteran_v2_complet.glb animace/afk_zombie.glb animace/afk_zombie.glb Hit_Small_Front Hit_Small_Back Hit_Small_Left Hit_Small_Right
# An animation of that name already in dst is left as it is (running it twice changes nothing).
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from afk_glb import GLB, retarget
src = GLB(sys.argv[1]); dst = GLB(sys.argv[2])
B = ['pelvis', 'spine_01', 'spine_02', 'spine_03', 'neck_01', 'head', 'clavicle_l', 'upperarm_l', 'lowerarm_l', 'hand_l',
     'clavicle_r', 'upperarm_r', 'lowerarm_r', 'hand_r', 'thigh_l', 'calf_l', 'foot_l', 'ball_l', 'thigh_r', 'calf_r', 'foot_r', 'ball_r']
names = {n.get('name') for n in dst.j['nodes']}
BM = {b: b for b in B if b in names}
have = {a['name'] for a in dst.j.get('animations', [])}
for arg in sys.argv[4:]:
    a, _, new = arg.partition('=')
    new = new or a
    if new in have:
        print(new, 'already there'); continue
    print(new, retarget(src, a, dst, BM, 'pelvis', 'pelvis', new))
dst.save(sys.argv[3])
