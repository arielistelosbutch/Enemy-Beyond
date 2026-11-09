"""0.57: spring bones for Ari's afk models (no Blender needed, just numpy).
  python3 afk_springs.py levit <afk_levit.glb> <afk_jestetan.glb (deaths source)> <out.glb>
  python3 afk_springs.py jestetan <afk_jestetan.glb> <out.glb>
Levit: a bone chain in each of the 12 tentacles (tent_<i>_0..3, tip) under hips, reweighted, plus the
Ještěřan's deaths moved onto its upper body. Ještěřan: tail chain tailx_0..3, tip under pelvis.
The game hangs SpringBoneSimulator3D on them (alien._afk_springs). Run on Ari's fresh afk export again."""
import json,struct,sys,numpy as np
CT={5125:('I',4),5126:('f',4),5123:('H',2),5121:('B',1)}
NC={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
class GLB:
    def __init__(s,p):
        b=open(p,'rb').read(); l=struct.unpack('<I',b[12:16])[0]
        s.j=json.loads(b[20:20+l]); bl=struct.unpack('<I',b[20+l:24+l])[0]
        s.bin=bytearray(b[28+l:28+l+bl])
    def read(s,ai):
        a=s.j['accessors'][ai]; bv=s.j['bufferViews'][a['bufferView']]
        n=NC[a['type']]; f,sz=CT[a['componentType']]
        off=bv.get('byteOffset',0)+a.get('byteOffset',0); st=bv.get('byteStride',sz*n)
        dt={'f':np.float32,'I':np.uint32,'H':np.uint16,'B':np.uint8}[f]
        if st==sz*n:
            return np.frombuffer(bytes(s.bin[off:off+a['count']*st]),dtype=dt).reshape(a['count'],n).astype(np.float64 if f=='f' else np.int64)
        return np.array([struct.unpack_from('<%d%s'%(n,f),s.bin,off+i*st) for i in range(a['count'])])
    def add(s,arr,ctype,typ,target=None,minmax=False):
        f={5126:np.float32,5125:np.uint32,5123:np.uint16,5121:np.uint8}[ctype]
        data=np.ascontiguousarray(arr,dtype=f).tobytes()
        while len(s.bin)%4: s.bin+=b'\0'
        bv={'buffer':0,'byteOffset':len(s.bin),'byteLength':len(data)}
        if target: bv['target']=target
        s.bin+=data; s.j['bufferViews'].append(bv)
        acc={'bufferView':len(s.j['bufferViews'])-1,'componentType':ctype,'count':len(arr),'type':typ}
        if minmax:
            a2=np.asarray(arr).reshape(len(arr),-1); acc['min']=a2.min(0).tolist(); acc['max']=a2.max(0).tolist()
        s.j['accessors'].append(acc); return len(s.j['accessors'])-1
    def save(s,p):
        while len(s.bin)%4: s.bin+=b'\0'
        s.j['buffers'][0]['byteLength']=len(s.bin)
        js=json.dumps(s.j,separators=(',',':')).encode()
        while len(js)%4: js+=b' '
        out=struct.pack('<III',0x46546C67,2,12+8+len(js)+8+len(s.bin))+struct.pack('<II',len(js),0x4E4F534A)+js+struct.pack('<II',len(s.bin),0x004E4942)+bytes(s.bin)
        open(p,'wb').write(out)
def q2m(q):
    x,y,z,w=q
    return np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])
def m2q(m):
    t=np.trace(m)
    if t>0:
        s=np.sqrt(t+1)*2; return np.array([(m[2,1]-m[1,2])/s,(m[0,2]-m[2,0])/s,(m[1,0]-m[0,1])/s,0.25*s])
    i=np.argmax([m[0,0],m[1,1],m[2,2]])
    if i==0:
        s=np.sqrt(1+m[0,0]-m[1,1]-m[2,2])*2; return np.array([0.25*s,(m[0,1]+m[1,0])/s,(m[0,2]+m[2,0])/s,(m[2,1]-m[1,2])/s])
    if i==1:
        s=np.sqrt(1+m[1,1]-m[0,0]-m[2,2])*2; return np.array([(m[0,1]+m[1,0])/s,0.25*s,(m[1,2]+m[2,1])/s,(m[0,2]-m[2,0])/s])
    s=np.sqrt(1+m[2,2]-m[0,0]-m[1,1])*2; return np.array([(m[0,2]+m[2,0])/s,(m[1,2]+m[2,1])/s,0.25*s,(m[1,0]-m[0,1])/s])
def trs(n):
    M=np.eye(4)
    if 'matrix' in n: return np.array(n['matrix']).reshape(4,4).T
    S=np.diag(n.get('scale',[1,1,1])); R=q2m(n.get('rotation',[0,0,0,1]))
    M[:3,:3]=R@S; M[:3,3]=n.get('translation',[0,0,0]); return M
def parents(j):
    p={}
    for i,n in enumerate(j['nodes']):
        for c in n.get('children',[]): p[c]=i
    return p
def gmat(j,i,par,cache=None):
    M=trs(j['nodes'][i])
    while i in par:
        i=par[i]; M=trs(j['nodes'][i])@M
    return M
def pieces(g,ni):
    j=g.j; p=j['meshes'][j['nodes'][ni]['mesh']]['primitives'][0]
    P=g.read(p['attributes']['POSITION']); I=g.read(p['indices']).ravel().astype(int)
    par=np.arange(len(P))
    def f(x):
        r=x
        while par[r]!=r: r=par[r]
        while par[x]!=r: nx=par[x]; par[x]=r; x=nx
        return r
    def u(a,b):
        a,b=f(a),f(b)
        if a!=b: par[b]=a
    for t in range(0,len(I),3): u(I[t],I[t+1]); u(I[t],I[t+2])
    key={}
    for v in range(len(P)):
        k=tuple(P[v].round(4))
        if k in key: u(key[k],v)
        else: key[k]=v
    cs={}
    for v in range(len(P)): cs.setdefault(f(v),[]).append(v)
    return P,list(cs.values())
def joint_names(g,skin=0):
    return [g.j['nodes'][i]['name'] for i in g.j['skins'][skin]['joints']]
def add_joints(g,specs,par_name):
    """specs: list of (name, global position, parent name). Adds nodes + appends to every skin."""
    j=g.j; parm=parents(j); idx={n.get('name'):i for i,n in enumerate(j['nodes'])}
    G={}
    def glob(name):
        if name in G: return G[name]
        return gmat(j,idx[name],parm)
    for name,pos,pn in specs:
        Gp=glob(pn); Gn=np.eye(4); Gn[:3,3]=pos
        L=np.linalg.inv(Gp)@Gn
        q=m2q(L[:3,:3]/np.linalg.norm(L[:3,:3],axis=0))
        node={'name':name,'translation':L[:3,3].tolist(),'rotation':q.tolist()}
        j['nodes'].append(node); ni=len(j['nodes'])-1; idx[name]=ni
        j['nodes'][idx[pn]].setdefault('children',[]).append(ni); G[name]=Gn
    for sk in j['skins']:
        ibm=g.read(sk['inverseBindMatrices']).reshape(-1,4,4)
        new=[]
        for name,pos,pn in specs:
            sk['joints'].append(idx[name]); M=np.linalg.inv(G[name]); new.append(M.T.reshape(16))
        allm=np.vstack([ibm.reshape(-1,16),np.array(new)])
        sk['inverseBindMatrices']=g.add(allm,5126,'MAT4')
    return idx
def set_weights(g,ni,J,W):
    p=g.j['meshes'][g.j['nodes'][ni]['mesh']]['primitives'][0]
    W=np.asarray(W,dtype=np.float64); W=W/np.maximum(W.sum(1,keepdims=True),1e-9)
    p['attributes']['JOINTS_0']=g.add(np.asarray(J),5123,'VEC4',34962)
    p['attributes']['WEIGHTS_0']=g.add(W,5126,'VEC4',34962)
def get_weights(g,ni):
    p=g.j['meshes'][g.j['nodes'][ni]['mesh']]['primitives'][0]
    return g.read(p['attributes']['JOINTS_0']).astype(int),g.read(p['attributes']['WEIGHTS_0'])
def top4(d):
    it=sorted(d.items(),key=lambda x:-x[1])[:4]
    while len(it)<4: it.append((0,0.0))
    return [a for a,_ in it],[b for _,b in it]
def chain_weights(u,nb):
    """u in [0,1] along chain -> dict bone k -> weight (hat functions centred mid-segment)"""
    x=u*nb; d={}
    for k in range(nb):
        w=max(0.0,1.0-abs(x-(k+0.5)))
        if k==0 and x<0.5: w=1.0
        if k==nb-1 and x>nb-0.5: w=1.0
        if w>0: d[k]=w
    return d
# ---------- retarget animations (world-space rotation deltas) ----------
def sample_anim(g,a,fps=30.0):
    j=g.j; ch={}
    tmax=0
    for c in a['channels']:
        s=a['samplers'][c['sampler']]; t=g.read(s['input']).ravel(); v=g.read(s['output'])
        ch[(c['target']['node'],c['target']['path'])]=(t,v); tmax=max(tmax,t.max())
    T=np.arange(0,tmax+1e-6,1/fps)
    if T[-1]<tmax-1e-4: T=np.append(T,tmax)
    return ch,T
def interp(t,v,T,quat):
    out=np.zeros((len(T),v.shape[1]))
    for k,tt in enumerate(T):
        i=np.searchsorted(t,tt)
        if i<=0: out[k]=v[0]; continue
        if i>=len(t): out[k]=v[-1]; continue
        a=(tt-t[i-1])/(t[i]-t[i-1]); A=v[i-1]; B=v[i]
        if quat:
            if np.dot(A,B)<0: B=-B
            q=A*(1-a)+B*a; out[k]=q/np.linalg.norm(q)
        else: out[k]=A*(1-a)+B*a
    return out
def globals_at(g,ch,T,nodes_needed):
    """global 4x4 of nodes at each time: dict node -> array (len(T),4,4)"""
    j=g.j; parm=parents(j); res={}
    def loc(n):
        node=j['nodes'][n]; R=np.tile(trs(node),(len(T),1,1))
        S=np.array(node.get('scale',[1,1,1]))
        tr=np.tile(np.array(node.get('translation',[0,0,0]),float),(len(T),1))
        q=np.tile(np.array(node.get('rotation',[0,0,0,1]),float),(len(T),1))
        if (n,'translation') in ch: tr=interp(*ch[(n,'translation')],T,False)
        if (n,'rotation') in ch: q=interp(*ch[(n,'rotation')],T,True)
        for k in range(len(T)):
            R[k,:3,:3]=q2m(q[k])@np.diag(S); R[k,:3,3]=tr[k]
        return R
    def G(n):
        if n in res: return res[n]
        L=loc(n)
        if n in parm: L=np.einsum('ij,kjl->kil',np.eye(4),np.einsum('kij,kjl->kil',G(parm[n]),L)) if False else np.einsum('kij,kjl->kil',G(parm[n]),L)
        res[n]=L; return L
    for n in nodes_needed: G(n)
    return res
def norm3(M):
    return M[:3,:3]/np.linalg.norm(M[:3,:3],axis=0)
def retarget(src,anim_name,dst,bone_map,root_src,root_dst,new_name,fps=30.0):
    sj=src.j; dj=dst.j
    a=[x for x in sj['animations'] if x['name']==anim_name][0]
    ch,T=sample_anim(src,a,fps)
    sidx={n.get('name'):i for i,n in enumerate(sj['nodes'])}
    didx={n.get('name'):i for i,n in enumerate(dj['nodes'])}
    sp=parents(sj); dp=parents(dj)
    Gs=globals_at(src,ch,T,[sidx[s] for s in bone_map.values()]+[sidx[root_src]])
    # source rest globals
    Gs0={s:gmat(sj,sidx[s],sp) for s in list(bone_map.values())+[root_src]}
    # target rest globals
    order=list(bone_map.keys())   # parents before children expected
    Gt0={t:gmat(dj,didx[t],dp) for t in order}
    k=(Gt0[root_dst][1,3]-gmat(dj,dp[didx[root_dst]],dp)[1,3])/(Gs0[root_src][1,3]-0.0)
    rot={}; glob={}
    for t in order:
        s=bone_map[t]; D=np.einsum('kij,jl->kil',Gs[sidx[s]][:,:3,:3],norm3(Gs0[s]).T)
        glob[t]=np.einsum('kij,jl->kil',D,norm3(Gt0[t]))
    channels=[];samplers=[]
    tin=dst.add(T.reshape(-1,1),5126,'SCALAR',minmax=True)
    for t in order:
        pn=dj['nodes'][dp[didx[t]]]['name']
        if pn in glob: Pr=glob[pn]
        else: Pr=np.tile(norm3(gmat(dj,dp[didx[t]],dp)),(len(T),1,1))
        L=np.einsum('kji,kjl->kil',Pr,glob[t])
        Q=np.array([m2q(m) for m in L])
        for i in range(1,len(Q)):
            if np.dot(Q[i],Q[i-1])<0: Q[i]=-Q[i]
        samplers.append({'input':tin,'output':dst.add(Q,5126,'VEC4'),'interpolation':'LINEAR'})
        channels.append({'sampler':len(samplers)-1,'target':{'node':didx[t],'path':'rotation'}})
    # root translation (hips)
    ps=Gs[sidx[root_src]][:,:3,3]; d=(ps-Gs0[root_src][:3,3])*k
    pt=Gt0[root_dst][:3,3]+d
    Pp=gmat(dj,dp[didx[root_dst]],dp)
    loc=(np.linalg.inv(Pp)@np.hstack([pt,np.ones((len(pt),1))]).T).T[:,:3]
    samplers.append({'input':tin,'output':dst.add(loc,5126,'VEC3'),'interpolation':'LINEAR'})
    channels.append({'sampler':len(samplers)-1,'target':{'node':didx[root_dst],'path':'translation'}})
    dj['animations'].append({'name':new_name,'channels':channels,'samplers':samplers})
    return T[-1]

def levit(src_p, jes_p, out_p):
    g=GLB(src_p); src=GLB(jes_p)
    NB=4
    P,cs=pieces(g,46)
    cs=[c for c in cs if len(c)>100]
    cs.sort(key=lambda c: np.arctan2(P[c][:,2].mean(),P[c][:,0].mean()))
    specs=[];chains=[]
    for i,c in enumerate(cs):
        Q=P[c]; ytop=Q[:,1].max(); ybot=Q[:,1].min()
        y0=min(ytop-0.12,0.86)
        lv=np.linspace(y0,ybot,NB+1)
        pts=[]
        for y in lv:
            sel=Q[np.abs(Q[:,1]-y)<0.04]
            if len(sel)<3: sel=Q[np.argsort(np.abs(Q[:,1]-y))[:20]]
            pts.append(sel.mean(0))
        names=['tent_%d_%d'%(i,k) for k in range(NB)]+['tent_%d_tip'%i]
        par='hips'
        for n,p in zip(names,pts):
            specs.append((n,p,par)); par=n
        chains.append((c,y0,ybot,names))
    idx=add_joints(g,specs,'hips')
    jn=joint_names(g)
    jpos={n:i for i,n in enumerate(jn)}
    J,W=get_weights(g,46); J=J.copy(); W=W.copy()
    for c,y0,ybot,names in chains:
        for v in c:
            y=P[v,1]; u=(y0-y)/(y0-ybot)
            d=chain_weights(min(max(u,0),1),NB)
            new={jpos[names[k]]:w for k,w in d.items()}
            b=np.clip((y0+0.06-y)/0.06,0,1)   # 0 above top -> original weights
            old={}
            for a,w in zip(J[v],W[v]):
                if w>0: old[a]=old.get(a,0)+w
            mix={}
            for a,w in old.items(): mix[a]=mix.get(a,0)+w*(1-b)
            for a,w in new.items(): mix[a]=mix.get(a,0)+w*b
            J[v],W[v]=top4(mix)
    set_weights(g,46,J,W)
    # small pieces on tentacle tops (node 45, 18 vertices) follow the nearest tentacle vertex
    P5,c5=pieces(g,45); J5,W5=get_weights(g,45); J5=J5.copy(); W5=W5.copy()
    allv=np.concatenate([c for c,_,_,_ in chains])
    for c in c5:
        if len(c)!=18: continue
        m=P5[c].mean(0); k=allv[np.argmin(np.linalg.norm(P[allv]-m,axis=1))]
        for v in c: J5[v]=J[k]; W5[v]=W[k]
    set_weights(g,45,J5,W5)
    # deaths from Ještěřan (afk human) – upper body
    BM={'hips':'pelvis','spine_1':'spine_01','spine_2':'spine_03','head':'head',
        'arm_1_l':'upperarm_l','arm_2_l':'lowerarm_l','hand_l':'hand_l',
        'arm_1_r':'upperarm_r','arm_2_r':'lowerarm_r','hand_r':'hand_r'}
    for a in ['Death_A','Death_B','Death_C','Death_D','Death_Flying_Back','Rifle_Death']:
        print(a,retarget(src,a,g,BM,'pelvis','hips',a))
    g.save(out_p); print('ok',len(chains),'chains')

def jestetan(src_p, out_p):
    g=GLB(src_p); NB=4
    P,_=pieces(g,68)
    Z0,Z1=-0.25,-1.62
    reg=(P[:,2]<-0.15)&(np.abs(P[:,0])<0.3)&(P[:,1]<1.2)
    pts=[]
    for z in np.linspace(Z0,Z1,NB+1):
        s=reg&(np.abs(P[:,2]-z)<0.06)
        pts.append(P[s].mean(0) if s.sum()>2 else P[reg][np.argmin(np.abs(P[reg][:,2]-z))])
    pts[-1][2]=Z1
    names=['tailx_%d'%k for k in range(NB)]+['tailx_tip']
    specs=[];par='pelvis'
    for n,p in zip(names,pts): specs.append((n,p,par)); par=n
    print([p.round(2) for p in pts])
    add_joints(g,specs,'pelvis'); jn=joint_names(g); jp={n:i for i,n in enumerate(jn)}
    J,W=get_weights(g,68); J=J.copy(); W=W.copy()
    for v in np.where(reg)[0]:
        z=P[v,2]; u=(Z0-z)/(Z0-Z1)
        d=chain_weights(min(max(u,0),1),NB); new={jp[names[k]]:w for k,w in d.items()}
        b=np.clip((-0.18-z)/0.17,0,1); b=b*b*(3-2*b)
        mix={}
        for a,w in zip(J[v],W[v]):
            if w>0: mix[a]=mix.get(a,0)+w*(1-b)
        for a,w in new.items(): mix[a]=mix.get(a,0)+w*b
        J[v],W[v]=top4(mix)
    set_weights(g,68,J,W)
    body=np.where(reg)[0]
    for ni in range(69,79):
        Q,cs=pieces(g,ni); Jn,Wn=get_weights(g,ni); Jn=Jn.copy(); Wn=Wn.copy(); ch=0
        for c in cs:
            m=Q[c].mean(0)
            if not (m[2]<-0.2 and abs(m[0])<0.35 and m[1]<1.2): continue
            k=body[np.argmin(np.linalg.norm(P[body]-m,axis=1))]
            for v in c: Jn[v]=J[k]; Wn[v]=W[k]
            ch+=1
        if ch: set_weights(g,ni,Jn,Wn); print('node',ni,'pieces',ch)
    g.save(out_p); print('ok')

if __name__ == "__main__":
    if sys.argv[1] == "levit": levit(*sys.argv[2:5])
    else: jestetan(*sys.argv[2:4])
