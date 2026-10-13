from pathlib import Path
import json,math
root=Path(__file__).resolve().parents[1]
layout=json.loads((root/'tests/ink_first_floor_room_art_20261004/room_layout.json').read_text())
def hit(a,b,o,m):
 lo=[o['position'][i]-o['half'][i]-m for i in (0,2)]
 hi=[o['position'][i]+o['half'][i]+m for i in (0,2)]
 t0,t1=0.,1.
 for k,i in enumerate((0,2)):
  delta=b[i]-a[i]
  if abs(delta)<.00001:
   if a[i]<lo[k] or a[i]>hi[k]:return False
  else:
   x,y=(lo[k]-a[i])/delta,(hi[k]-a[i])/delta
   t0=max(t0,min(x,y));t1=min(t1,max(x,y))
   if t0>t1:return False
 return True
rows=[]
for p in [(-2.25337958335876,0.,9.83424663543701),(2.2679398059845,0.,11.3591117858887)]:
 counts={}
 for m in [.75,.65]:
  clear=[]
  for dx,dz in [(0,-1),(1,-1),(1,0),(1,1),(0,1),(-1,1),(-1,0),(-1,-1)]:
   norm=math.hypot(dx,dz);b=(p[0]+dx/norm,0.,p[2]+dz/norm)
   if not any(hit(p,b,o,m) for o in layout['obstacles']):clear.append([dx,dz])
  counts[str(m)]=clear
 assert not counts['0.75'] and counts['0.65']
 rows.append({'position':p,'clear_one_meter_directions':counts})
print(json.dumps({'passed':True,'pure_geometry_only':True,'rows':rows},indent=2))
