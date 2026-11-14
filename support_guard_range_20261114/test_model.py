"""Spatial-query Python model. Not game-engine execution."""
from math import floor,dist
import json
from pathlib import Path
checks=0
def actor(id,x,z,kind='armored',dead=False):return dict(actor_id=id,position=(x,z),kind=kind,dead=dead)
def cell(p):return tuple(floor(v/2.5) for v in p)
def nearest(at,actors,old=False):
 grid={}
 for a in actors:grid.setdefault(cell(a['position']),[]).append(a)
 lo=cell((at[0]-8,at[1]-8));hi=cell((at[0]+8,at[1]+8))
 if old:c=cell(at);lo=(c[0]-1,c[1]-1);hi=(c[0]+1,c[1]+1)
 found=[]
 for x in range(lo[0],hi[0]+1):
  for z in range(lo[1],hi[1]+1):found+=grid.get((x,z),[])
 if old:found=found[:12]
 best=None;distance=8.
 for a in found:
  if a['dead'] or a['kind']!='armored' or a['actor_id']=='self':continue
  d=dist(at,a['position'])
  if d<distance:best=a['actor_id'];distance=d
 return best
def check(at,actors,expected):
 global checks
 assert nearest(at,actors)==expected,(at,expected,nearest(at,actors));checks+=1
check((1,-5),[actor('guard',1,0)],'guard')
assert nearest((1,-5),[actor('guard',1,0)],True) is None
for p in [(7.999,0),(-7.999,0),(0,7.999),(0,-7.999)]:check((0,0),[actor('inside',*p)],'inside')
for p in [(8,0),(-8,0),(0,8),(0,-8),(8.001,0),(7,7)]:check((0,0),[actor('out',*p)],None)
check((-2.49,-2.49),[actor('negative',-7.49,-2.49)],'negative')
check((0,0),[actor('far',7,0),actor('near',3,0)],'near')
check((0,0),[actor('dead',1,0,dead=True),actor('alive',5,0)],'alive')
check((0,0),[actor('wrong',1,0,'minion'),actor('self',0,0)],None)
check((0,0),[actor(str(i),.01*i,.01,'minion') for i in range(20)]+[actor('guard',5,0)],'guard')
# Negative-cell and boundary coverage compared with brute force, no distance ties.
for at in [(1,-5),(-.01,-.01),(2.49,2.49),(2.5,2.5),(-2.5,-2.5)]:
 for dx in [-8.01,-7.99,-5.1,-2.51,0,2.51,5.1,7.99,8.01]:
  for dz in [-8.01,-5.1,0,5.1,8.01]:
   a=actor('g',at[0]+dx,at[1]+dz)
   check(at,[a],'g' if dist(at,a['position'])<8 else None)
result={'passed':True,'checks':checks,'original_miss_reproduced_in_model':True,'scope':'Python model with current spatial entries; NOT engine/whole-floor validation','engine_run':False}
print(json.dumps(result,indent=2))
