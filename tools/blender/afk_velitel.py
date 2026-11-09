# afk Ještěřan (no tail) -> the commander on the same rig: his own armour meshes added, skinned
import sys, os, copy
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from afk_glb import *
import numpy as np
a=GLB(sys.argv[1]); v=GLB(sys.argv[2]); out=sys.argv[3]
FLIP=np.array([-1.0,1.0,-1.0])
vp=v.j['meshes'][0]['primitives']
base_n=11
# body sample (all base meshes) with weights
BP=[];BJ=[];BW=[]
for k in range(base_n):
    ni=68+k; pr=a.j['meshes'][a.j['nodes'][ni]['mesh']]['primitives'][0]
    BP.append(a.read(pr['attributes']['POSITION'])); J,W=get_weights(a,ni); BJ.append(J); BW.append(W)
BP=np.vstack(BP); BJ=np.vstack(BJ); BW=np.vstack(BW)
# check base meshes identical; copy base material colours from the commander
for k in range(base_n):
    P=v.read(vp[k]['attributes']['POSITION'])*FLIP
    Q=a.read(a.j['meshes'][a.j['nodes'][68+k]['mesh']]['primitives'][0]['attributes']['POSITION'])
    assert np.abs(P-Q).max()<1e-4
    ma=a.j['meshes'][a.j['nodes'][68+k]['mesh']]['primitives'][0]['material']
    a.j['materials'][ma]=copy.deepcopy(v.j['materials'][vp[k]['material']])
pm=parents(a.j); arm=a.j['nodes'][pm[68]] if 68 in pm else None
for k in range(base_n,len(vp)):
    pr=vp[k]; P=v.read(pr['attributes']['POSITION'])*FLIP; N=v.read(pr['attributes']['NORMAL'])*FLIP
    T=v.read(pr['attributes']['TEXCOORD_0']); I=v.read(pr['indices']).ravel()
    # pieces of this primitive
    par=np.arange(len(P))
    def f(x):
        while par[x]!=x: par[x]=par[par[x]]; x=par[x]
        return x
    for t in range(0,len(I),3):
        for q in (I[t+1],I[t+2]):
            ra,rb=f(I[t]),f(q)
            if ra!=rb: par[rb]=ra
    key={}
    for i in range(len(P)):
        kq=tuple(P[i].round(4))
        if kq in key:
            ra,rb=f(key[kq]),f(i)
            if ra!=rb: par[rb]=ra
        else: key[kq]=i
    roots={}
    for i in range(len(P)): roots.setdefault(f(i),[]).append(i)
    J=np.zeros((len(P),4),int); W=np.zeros((len(P),4))
    for c in roots.values():
        Q=P[c]; diag=np.linalg.norm(Q.max(0)-Q.min(0))
        if diag<0.45:
            kk=np.argmin(np.linalg.norm(BP-Q.mean(0),axis=1))
            J[c]=BJ[kk]; W[c]=BW[kk]
        else:
            for i in c:
                kk=np.argmin(np.linalg.norm(BP-P[i],axis=1)); J[i]=BJ[kk]; W[i]=BW[kk]
    mat=copy.deepcopy(v.j['materials'][pr['material']]); a.j['materials'].append(mat)
    attrs={'POSITION':a.add(P,5126,'VEC3',34962,minmax=True),'NORMAL':a.add(N,5126,'VEC3',34962),
        'TEXCOORD_0':a.add(T,5126,'VEC2',34962),'JOINTS_0':a.add(J,5123,'VEC4',34962),
        'WEIGHTS_0':a.add(W/np.maximum(W.sum(1,keepdims=True),1e-9),5126,'VEC4',34962)}
    idx=a.add(I.reshape(-1,1),5125,'SCALAR',34963)
    a.j['meshes'].append({'name':mat['name'],'primitives':[{'attributes':attrs,'indices':idx,'material':len(a.j['materials'])-1}]})
    a.j['nodes'].append({'name':'jestetan_velitel_'+mat['name'],'mesh':len(a.j['meshes'])-1,'skin':0})
    (arm.setdefault('children',[]) if arm is not None else a.j['scenes'][0]['nodes']).append(len(a.j['nodes'])-1)
    print(mat['name'],len(P),'pieces',len(roots))
a.save(out); print('ok')
