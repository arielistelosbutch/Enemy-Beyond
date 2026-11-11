#!/usr/bin/env python3
# 0.61: z-fighting in models. Two faces of DIFFERENT materials lying in one plane (a trim strip flush
# with a car's side, roof tiles, ribs on a UFO hull...) flicker in the game. This finds them in GLB
# files and, with --fix, pushes the smaller part (by total area) out along the face normal by
# 0.4 promile of the model's size (0.6 mm to 10 mm). Only vertex positions change - their count and
# order stay, so Ari's modely/<x>.json edits keep working. Skinned meshes and collision parts are skipped.
#   python3 tools/blender/zfight_glb.py assets/models/*.glb          (report)
#   python3 tools/blender/zfight_glb.py --fix assets/models/v_car_red.glb ...
# Run it again on every GLB a Blender script regenerates (the scripts themselves still build flush parts).
import json, struct, sys, os, numpy as np
from collections import defaultdict
SKINNED=False   # --skinned: skinned meshes too (bind pose; weights and bones stay). Not for merc.glb: its Look_* variants overlap on purpose
CT={5120:np.int8,5121:np.uint8,5122:np.int16,5123:np.uint16,5125:np.uint32,5126:np.float32}
NC={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
def load(path):
    b=open(path,'rb').read()
    jl=struct.unpack('<I',b[12:16])[0]; j=json.loads(b[20:20+jl]); off=20+jl
    bin_=b[off+8:] if len(b)>off else b''
    return j,bin_
def acc(j,bin_,i):
    a=j['accessors'][i]; bv=j['bufferViews'][a['bufferView']]
    dt=CT[a['componentType']]; n=NC[a['type']]
    st=bv.get('byteStride',0); o=bv.get('byteOffset',0)+a.get('byteOffset',0)
    isz=np.dtype(dt).itemsize*n
    if st and st!=isz:
        raw=np.frombuffer(bin_,np.uint8,a['count']*st,o).reshape(a['count'],st)[:,:isz].copy()
        arr=raw.view(dt).reshape(a['count'],n)
    else:
        arr=np.frombuffer(bin_,dt,a['count']*n,o).reshape(a['count'],n)
    return arr
def mat_of(n):
    if 'matrix' in n: return np.array(n['matrix']).reshape(4,4).T
    t=np.array(n.get('translation',[0,0,0])); r=n.get('rotation',[0,0,0,1]); s=np.array(n.get('scale',[1,1,1]))
    x,y,z,w=r
    R=np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])
    M=np.eye(4); M[:3,:3]=R*s; M[:3,3]=t; return M
def tris(path):
    j,bin_=load(path); return tris_raw(j,bin_),j
def tris_raw(j,bin_):
    out=[]  # (tri world verts (3,3), matkey, prim id, node, primidx, vert indices)
    def walk(ni,P):
        n=j['nodes'][ni]; M=P@mat_of(n)
        if 'skin' in n: M=np.eye(4)      # skinned: vertices are in bind pose
        if 'mesh' in n and ('skin' not in n or SKINNED):
            for pi,p in enumerate(j['meshes'][n['mesh']]['primitives']):
                if p.get('mode',4)!=4: continue
                pos=acc(j,bin_,p['attributes']['POSITION']).astype(float)
                idx=acc(j,bin_,p['indices']).reshape(-1) if 'indices' in p else np.arange(len(pos))
                W=(M[:3,:3]@pos.T).T+M[:3,3]
                out.append((W,idx.reshape(-1,3),p.get('material',-1),(n['mesh'],pi),ni))
        for c in n.get('children',[]): walk(c,M)
    for s in j.get('scenes',[{}])[j.get('scene',0)].get('nodes',[]): walk(s,np.eye(4))
    return out
def clip(poly,a,b):
    # keep left of edge a->b (2D)
    res=[]
    def side(p): return (b[0]-a[0])*(p[1]-a[1])-(b[1]-a[1])*(p[0]-a[0])
    for i in range(len(poly)):
        P=poly[i];Q=poly[(i+1)%len(poly)]; sp=side(P); sq=side(Q)
        if sp>=0: res.append(P)
        if (sp>=0)!=(sq>=0):
            t=sp/(sp-sq); res.append((P[0]+t*(Q[0]-P[0]),P[1]+t*(Q[1]-P[1])))
    return res
def area(poly):
    if len(poly)<3: return 0.0
    s=0
    for i in range(len(poly)):
        x1,y1=poly[i];x2,y2=poly[(i+1)%len(poly)]; s+=x1*y2-x2*y1
    return s/2
def ccw(t):
    return t if area(t)>0 else t[::-1]
def inter(t1,t2):
    t1=ccw(t1); t2=ccw(t2); poly=list(t1)
    for i in range(3):
        poly=clip(poly,t2[i],t2[(i+1)%3])
        if not poly: return 0
    return abs(area(poly))
def step_of(prims):
    ext=np.ptp(np.concatenate([p[0] for p in prims]),axis=0).max()
    return min(0.01,max(0.0006,ext*0.0004))
def analyze(path,E=None,MIN=2e-5):
    j,bin_=load(path)
    pr=tris_raw(j,bin_)
    if not pr: return [],j,{}
    if E is None: E=step_of(pr)*0.6
    prims,j,lst=analyze_raw(j,bin_,E,MIN)
    hits=defaultdict(float)
    for (pa,ta,pb,tb,n,ar) in lst: hits[(min(pa,pb),max(pa,pb))]+=ar
    return prims,j,hits
def analyze_raw(j,bin_,E=0.0015,MIN=2e-5):
    prims=tris_raw(j,bin_)
    buckets=defaultdict(list)
    T=[]
    for pid,(W,F,mat,key,ni) in enumerate(prims):
        v=W[F]; nrm=np.cross(v[:,1]-v[:,0],v[:,2]-v[:,0]); ln=np.linalg.norm(nrm,axis=1)
        ok=ln>1e-9
        for ti in np.nonzero(ok)[0]:
            n=nrm[ti]/ln[ti]; d=float(n@v[ti,0])
            T.append((pid,ti,n,d))
            kn=tuple(np.round(n*50).astype(int)); buckets[(kn,int(round(d/E)))].append(len(T)-1)
    hits=[]
    mats=j.get('materials',[])
    skip=set(i for i,pr in enumerate(prims) if 'col' in j['nodes'][pr[4]].get('name','').lower() or (pr[2]>=0 and mats[pr[2]].get('name','') in ('Col','Collision')))
    for k,lst in buckets.items():
        nb=lst+buckets.get((k[0],k[1]+1),[])
        if len(nb)<2: continue
        for ii,a in enumerate(lst):
            pa,ta,na,da=T[a]
            for b in nb[ii+1:] if True else []:
                pb,tb,nbv,db=T[b]
                if pa==pb or prims[pa][2]==prims[pb][2] or pa in skip or pb in skip: continue
                if na@nbv<0.9995 or abs(da-db)>E: continue
                # project to plane
                u=np.cross(na,[0,0,1] if abs(na[2])<0.9 else [1,0,0]); u/=np.linalg.norm(u); w=np.cross(na,u)
                A=prims[pa][0][prims[pa][1][ta]]; B=prims[pb][0][prims[pb][1][tb]]
                A2=[(float(p@u),float(p@w)) for p in A]; B2=[(float(p@u),float(p@w)) for p in B]
                ar=inter(A2,B2)
                if ar>MIN: hits.append((pa,ta,pb,tb,na,ar))
    return prims,j,hits
def main():
    global SKINNED
    if sys.argv[1]=='--skinned':
        SKINNED=True; sys.argv.pop(1)
    if sys.argv[1]=='--fix':
        for path in sys.argv[2:]:
            n=fix(path); _,_,h=analyze(path); print(os.path.basename(path),'moved',n,'left',len(h))
        return
    for path in sys.argv[1:]:
        try:
            prims,j,h=analyze(path)
        except Exception as e:
            print(os.path.basename(path),'ERR',e); continue
        if h:
            tot=sum(h.values())
            mats=j.get('materials',[])
            desc=[]
            for (a,b),ar in sorted(h.items(),key=lambda x:-x[1])[:4]:
                ma=mats[prims[a][2]]['name'] if prims[a][2]>=0 else '-'; mb=mats[prims[b][2]]['name'] if prims[b][2]>=0 else '-'
                desc.append(f"{ma}/{mb} {ar*1e4:.0f}cm2")
            print(f"{os.path.basename(path)}: {len(h)} pairs {tot*1e4:.0f} cm2 :: "+"; ".join(desc))

def fix(path,outpath=None,rounds=5):
    """Pushes the smaller of two coplanar overlapping faces (different materials) out along its normal.
    Only vertex positions change: count and order stay (Ari's modely/<x>.json keep working)."""
    raw=bytearray(open(path,'rb').read())
    jl=struct.unpack('<I',raw[12:16])[0]; binoff=20+jl+8
    moved_total=0
    for r in range(rounds):
        j=json.loads(bytes(raw[20:20+jl])); bin_=bytes(raw[binoff:])
        delta=step_of(tris_raw(j,bin_))
        prims,_,hits=analyze_raw(j,bin_,E=delta*0.6)
        if not hits: break
        # world move per (prim, vertex)
        mv=defaultdict(lambda: None)
        parea=[sum(tri_area(W[f]) for f in F) for (W,F,_m,_k,_n) in prims]   # the smaller part (decoration) steps out
        for (pa,ta,pb,tb,n,_ar) in hits:
            Aa=parea[pa]; Ab=parea[pb]
            p,t=(pa,ta) if (Aa<Ab or (Aa==Ab and pa>pb)) else (pb,tb)
            W=prims[p][0]
            for vi in prims[p][1][t]:
                key=(p,tuple(np.round(W[vi],5)))
                cur=mv[key]
                d=n*delta
                if cur is None: cur=np.zeros(3)
                short=delta-float(cur@n)
                if short>1e-9: cur=cur+n*short       # at least delta along every face it must leave
                mv[key]=cur
        # apply to every vertex at that position in that primitive
        acc_new={}
        for p,(W,F,mat,(mi,pi),ni) in enumerate(prims):
            keys={k[1]:v for k,v in mv.items() if k[0]==p and v is not None}
            if not keys: continue
            M=np.eye(4) if 'skin' in j['nodes'][ni] else world_of(j,ni); Rinv=np.linalg.inv(M[:3,:3])
            ai=j['meshes'][mi]['primitives'][pi]['attributes']['POSITION']
            a=j['accessors'][ai]; bv=j['bufferViews'][a['bufferView']]
            o=bv.get('byteOffset',0)+a.get('byteOffset',0); st=bv.get('byteStride',0) or 12
            pos=acc(j,bin_,ai).astype(np.float64)
            R=np.round(W,5)
            for vi in range(len(W)):
                d=keys.get(tuple(R[vi]))
                if d is not None:
                    pos[vi]+=Rinv@d; moved_total+=1
            for vi in range(len(pos)):
                struct.pack_into('<3f',raw,binoff+o+vi*st,*pos[vi])
            a['min']=[float(x) for x in pos.min(0)]; a['max']=[float(x) for x in pos.max(0)]
        js=json.dumps(j,separators=(',',':')).encode()
        js+=b' '*((4-len(js)%4)%4)
        if len(js)!=jl:
            # json size changed (min/max): rebuild the file
            body=bytes(raw[20+jl:])
            raw=bytearray(raw[:12])+struct.pack('<I',len(js))+b'JSON'+js+body
            jl=len(js); binoff=20+jl+8
            struct.pack_into('<I',raw,8,len(raw))
        else:
            raw[20:20+jl]=js
    open(outpath or path,'wb').write(raw)
    return moved_total

def tri_area(v): return float(np.linalg.norm(np.cross(v[1]-v[0],v[2]-v[0])))/2
def world_of(j,target):
    parent={}
    for i,n in enumerate(j['nodes']):
        for c in n.get('children',[]): parent[c]=i
    M=np.eye(4); n=target; chain=[]
    while n is not None: chain.append(n); n=parent.get(n)
    for n in reversed(chain): M=M@mat_of(j['nodes'][n])
    return M

if __name__=='__main__':
    main()
