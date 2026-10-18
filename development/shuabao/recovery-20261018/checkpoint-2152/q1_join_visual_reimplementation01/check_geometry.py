import math,json,itertools
from pathlib import Path

def sub(a,b):return (a[0]-b[0],a[1]-b[1])
def cross(a,b):return a[0]*b[1]-a[1]*b[0]
def dot(a,b):return a[0]*b[0]+a[1]*b[1]
def clean(p):
 o=[]
 for v in p:
  if not o or dot(sub(v,o[-1]),sub(v,o[-1]))>1e-18:o.append(v)
 if len(o)>1 and dot(sub(o[0],o[-1]),sub(o[0],o[-1]))<=1e-18:o.pop()
 return o
def half(p,a,b,inside):
 if not p:return []
 out=[];prev=p[-1];dp=cross(sub(b,a),sub(prev,a));pin=dp>=0 if inside else dp<=0
 for cur in p:
  dc=cross(sub(b,a),sub(cur,a));cin=dc>=0 if inside else dc<=0
  if cin!=pin and dp!=dc:
   t=max(0,min(1,dp/(dp-dc)));out.append((prev[0]+(cur[0]-prev[0])*t,prev[1]+(cur[1]-prev[1])*t))
  if cin:out.append(cur)
  prev,dp,pin=cur,dc,cin
 return clean(out)
def subtract(poly,cut):
 pieces=[];remaining=poly
 for a,b in zip(cut,cut[1:]+cut[:1]):
  outside=half(remaining,a,b,False)
  if len(outside)>=3:pieces.append(outside)
  remaining=half(remaining,a,b,True)
  if len(remaining)<3:break
 return pieces
def intersect(poly,clip):
 for a,b in zip(clip,clip[1:]+clip[:1]):poly=half(poly,a,b,True)
 return poly
def area(poly):return abs(sum(cross(a,b) for a,b in zip(poly,poly[1:]+poly[:1])))/2 if poly else 0
def build(path,width):
 rects=[];tri=[];uv=[];along=0;length=sum(math.dist(a,b) for a,b in zip(path,path[1:]))
 for a,b in zip(path,path[1:]):
  dist=math.dist(a,b)
  if dist<=0:continue
  direction=tuple(x/dist for x in sub(b,a));side=(-direction[1],direction[0]);h=tuple(x*width/2 for x in side)
  rect=[tuple(p[k]+sign*h[k] for k in (0,1)) for p,sign in [(a,-1),(b,-1),(b,1),(a,1)]]
  pieces=[rect]
  for prev in rects:pieces=[q for p in pieces for q in subtract(p,prev)]
  for p in pieces:
   for i in range(1,len(p)-1):
    t=[p[0],p[i],p[i+1]];sg=cross(sub(t[1],t[0]),sub(t[2],t[0]))
    if sg==0:continue
    if sg<0:t=[t[0],t[2],t[1]]
    tri.append(t);uv.append([((along+max(0,min(dist,dot(sub(v,a),direction))))/max(length,.001),max(0,min(1,.5+dot(sub(v,a),side)/width))) for v in t])
  rects.append(rect);along+=dist
 return rects,tri,uv
cases={'straight':[(0,0),(4,0)],'U':[(0,0),(3,0),(3,3),(0,3)],'S':[(0,0),(2,0),(3,1),(2,2),(3,3),(5,3)],'near180':[(0,0),(4,0),(.001,.003)],'reverse':[(0,0),(4,0),(0,0)],'duplicate':[(0,0),(0,0),(2,0),(2,0),(2,2)],'short':[(0,0),(.001,0),(.001,.001),(.002,.001)],'run10':[(2.120847702,2.021213531),(4.64954567,1.936611176),(6.0906353,4.897480011)]}
results=[]
for name,path in cases.items():
 for width in [1.6,.1]:
  rects,tri,uv=build(path,width);union=0
  for n in range(1,len(rects)+1):
   for group in itertools.combinations(rects,n):
    p=group[0]
    for clip in group[1:]:p=intersect(p,clip)
    union+=area(p)*(1 if n%2 else -1)
  outarea=sum(area(t) for t in tri)
  overlap=max([area(intersect(a,b)) for a,b in itertools.combinations(tri,2)]+[0])
  outside=max([area(t)-max(area(intersect(t,r)) for r in rects) for t in tri]+[0])
  positive=all(cross(sub(t[1],t[0]),sub(t[2],t[0]))>0 for t in tri)
  finite=all(math.isfinite(x) and -1e-9<=x<=1+1e-9 for row in uv for v in row for x in v)
  ok=positive and finite and abs(outarea-union)<1e-8 and overlap<1e-8 and outside<1e-8
  results.append(dict(case=name,width=width,triangles=len(tri),positive=positive,finite_uv=finite,union_area=union,mesh_area=outarea,max_triangle_overlap=overlap,outside=outside,passed=ok))
assert all(r['passed'] for r in results),results
p=Path(__file__).with_name('geometry_checks.json');p.write_text(json.dumps({'method':'Pure Python mirror; inclusion-exclusion union area, pair triangle intersections, winding, UV and corridor. No engine execution.','cases':results},indent=2)+'\n');print(len(results),'checks passed')
