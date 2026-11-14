"""Independent Python geometry model, NOT execution of GDScript or engine QA."""
from pathlib import Path
import json,math,heapq
import sys
layout=json.loads(Path(sys.argv[1]).read_text())
obs=[((o['position'][0],o['position'][2]),(o['half'][0],o['half'][2])) for o in layout['obstacles']]
def clear(a,b,r):
 if any(abs(v)>13-r for v in b):return False
 for c,h in obs:
  en,le=0.,1.
  for k in (0,1):
   low,high=c[k]-h[k]-r,c[k]+h[k]+r;dx=b[k]-a[k]
   if abs(dx)<1e-6:
    if a[k]<=low or a[k]>=high:le=-1;break
   else:
    t=sorted(((low-a[k])/dx,(high-a[k])/dx));en=max(en,t[0]);le=min(le,t[1])
  if en<=le and le>1e-6 and en<1:return False
 return True
def route(a,b,r):
 nodes=[a,b]
 for c,h in obs:
  for sx in (-1,1):
   for sy in (-1,1):
    p=(c[0]+sx*(h[0]+r+.22),c[1]+sy*(h[1]+r+.22))
    if any(abs(v)>13-r for v in p):continue
    if any(abs(p[0]-c1[0])<h1[0]+r and abs(p[1]-c1[1])<h1[1]+r for c1,h1 in obs):continue
    nodes.append(p)
 goal=-1
 d=[math.inf]*len(nodes);parents=[-1]*len(nodes);d[0]=0;q=[(0,0)]
 while q:
  cost,i=heapq.heappop(q)
  if cost!=d[i]:continue
  if i!=0 and clear(nodes[i],b,.17):goal=i;break
  for j,p in enumerate(nodes):
   n=cost+math.dist(nodes[i],p)
   if n<d[j] and clear(nodes[i],p,r):d[j]=n;parents[j]=i;heapq.heappush(q,(n,j))
 assert goal>=0,(a,b,r)
 path=[];i=goal
 while i: path.insert(0,nodes[i]);i=parents[i]
 return path
results=[]
for radius in (.45,.48):
 for a,b in [((-6,-6),(-1,-11)),((6,-6),(1,-11)),((-6,-6),(1,-11)),((-1,-11),(-6,-6))]:
  assert not clear(a,b,.14)
  path=route(a,b,radius);prev=a
  for p in path:assert clear(prev,p,radius);prev=p
  results.append({'radius':radius,'origin':a,'target':b,'waypoints':path})
 assert clear((0,7),(0,0),.17)
obs=[((0,0),(1,1))]
for radius in (.45,.48):
 path=route((-3,0),(1.42,0),radius)
 assert clear(path[-1],(1.42,0),.17)
 assert not clear(path[-1],(1.42,0),radius)
 results.append({'radius':radius,'close_wall_hero':True,'waypoints':path})
print(json.dumps({'passed':True,'cases':results,'scope':'Independent geometry mirror only; GDScript fixture NOT RUN'},indent=2))
