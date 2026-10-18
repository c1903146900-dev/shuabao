from pathlib import Path
import math,time,json
ns={};exec((Path(__file__).parent.parent/'q1_join_visual_reimplementation01/check_geometry_with_bbox.py').read_text().split('cases=')[0],ns)
sub,cross,dot,subtract=map(ns.get,['sub','cross','dot','subtract'])
def bounds(r):return(min(x for x,y in r),min(y for x,y in r),max(x for x,y in r),max(y for x,y in r))
def overlaps(a,b):return a[0]<b[2] and b[0]<a[2] and a[1]<b[3] and b[1]<a[3]
class Cache:
 def __init__(self):self.state={};self.rebuilds=0
 def get(self,path,width,guide=False):
  slot=int(guide);s=self.state.get(slot)
  if not s or s['width']!=width or path[:len(s['path'])]!=s['path']:
   s=dict(width=width,path=[],processed=1,rectangles=[],boxes=[],tri=[],uv=[],along=0.0,mesh=None)
  if s['path']==path and s['mesh'] is not None:return s['mesh']
  peak=0;clips=0
  for i in range(max(1,s['processed']),len(path)):
   a,b=path[i-1:i+1];dist=math.dist(a,b)
   if dist<=0:continue
   direction=tuple(x/dist for x in sub(b,a));side=(-direction[1],direction[0]);h=tuple(x*width/2 for x in side)
   rect=[tuple(p[k]+sign*h[k] for k in (0,1)) for p,sign in [(a,-1),(b,-1),(b,1),(a,1)]];box=bounds(rect);pieces=[rect]
   for prev,pbox in zip(s['rectangles'],s['boxes']):
    if not overlaps(box,pbox):continue
    clips+=len(pieces);pieces=[q for p in pieces for q in subtract(p,prev)];peak=max(peak,len(pieces))
    if not pieces:break
   for p in pieces:
    for j in range(1,len(p)-1):
     t=[p[0],p[j],p[j+1]];sg=cross(sub(t[1],t[0]),sub(t[2],t[0]))
     if sg==0:continue
     if sg<0:t=[t[0],t[2],t[1]]
     s['tri'].append(t);s['uv'].append([(s['along']+max(0,min(dist,dot(sub(v,a),direction))),max(0,min(1,.5+dot(sub(v,a),side)/width))) for v in t])
   s['rectangles'].append(rect);s['boxes'].append(box);s['along']+=dist
  s['processed']=len(path);s['path']=list(path);length=sum(math.dist(a,b) for a,b in zip(path,path[1:]));s['mesh']=(s['tri'].copy(),[[(u/max(length,.001),v) for u,v in row] for row in s['uv']]);self.state[slot]=s;self.rebuilds+=1
  self.last_peak=peak;self.last_clips=clips
  return s['mesh']
rows=[]
for shape in ['U','S','near180','duplicate']:
 for n in [32,128,256,512]:
  if shape=='U':p=[(2*math.sin(math.pi*i/n),2*(1-math.cos(math.pi*i/n))) for i in range(n+1)]
  elif shape=='S':p=[(4*i/n,math.sin(2*math.pi*i/n)) for i in range(n+1)]
  elif shape=='near180':p=[(6*i/n,0) if i<=n//2 else (6*(1-i/n),.002*(2*i/n-1)) for i in range(n+1)]
  else:p=[(4*(i//2)/n,math.sin(2*math.pi*(i//2)/n)) for i in range(n+1)]
  c=Cache();times=[];peak=0;clips=0
  for end in range(2,len(p)+1):
   before=time.perf_counter();m=c.get(p[:end],.1,True);times.append(time.perf_counter()-before);peak=max(peak,c.last_peak);clips+=c.last_clips
  # Source width release: first layer builds, next two are identity reuse.
  before=time.perf_counter();release=c.get(p,1.6);release_cost=time.perf_counter()-before;count=c.rebuilds
  assert c.get(p,1.6) is release and c.get(p,1.6) is release and count==c.rebuilds
  # Compare complete numeric geometry and UV against uncached algorithm for modest cases.
  if n<=128:
   for width,guide in [(1.6,False),(.1,True)]:
    a,b,u=ns['build'](p,width);t,v=c.get(p,width,guide);assert b==t and u==v,(shape,n,width)
  rows.append(dict(shape=shape,points=n+1,preview_max_ms=max(times)*1000,preview_total_ms=sum(times)*1000,release_once_ms=release_cost*1000,release_triangles=len(release[0]),preview_peak_pieces=peak,preview_clip_calls=clips,shared_layers=True))
# Width, prefix edit, rewind, duplicate, reset and retained old result independence.
c=Cache();a=c.get([(0,0),(1,0)],1.6);before=repr(a)
c.get([(0,0),(1,0),(2,1)],1.6);assert repr(a)==before
for p,w in [([(0,0),(1,1)],1.6), ([(0,0),(0,0),(1,1)],1.6), ([(0,0),(1,0)],.8)]:
 _,t,u=ns['build'](p,w);assert c.get(p,w)==(t,u)
c.state.clear();assert not c.state
out={'python_mirror_only':True,'engine_performance':'NOT_RUN','geometry_comparison':'exact uncached match for 32/128 per shape both widths','lifecycle_checks':'prefix edits/rewind/width/duplicate/reset/old-result immutability passed','measurements':rows}
Path(__file__).with_name('cache_checks.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
