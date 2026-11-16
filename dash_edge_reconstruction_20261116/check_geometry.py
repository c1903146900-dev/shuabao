"""Independent geometry model and source scope checks. Does not execute GDScript."""
import argparse,math,json,hashlib
from pathlib import Path
R=2.;H=math.radians(50)
def old(x,z,r):
 d=math.hypot(x,z)
 return d<=R+r and (d<r or (d>0 and z/d>=math.cos(H)))
def fixed(x,z,r):
 d=math.hypot(x,z)
 if d>R+r:return False
 if d<=r:return True
 if z>=d*math.cos(H):return True
 for sign in (-1,1):
  ex,ez=sign*math.sin(H),math.cos(H);t=max(0,min(R,x*ex+z*ez))
  if (x-t*ex)**2+(z-t*ez)**2<=r*r:return True
 return False
def oracle_distance(x,z):
 # Independently sample actual closed sector boundary (two finite edges + arc).
 points=[(0.,0.)]
 for i in range(2001):
  t=i/2000; a=-H+2*H*t
  points.extend(((R*math.sin(a),R*math.cos(a)),(R*t*math.sin(H),R*t*math.cos(H)),(-R*t*math.sin(H),R*t*math.cos(H))))
 if abs(math.atan2(x,z))<=H and math.hypot(x,z)<=R:return 0.
 return min(math.hypot(x-a,z-b) for a,b in points)
def main():
 p=argparse.ArgumentParser();p.add_argument('--base',required=True,type=Path);p.add_argument('--candidate',required=True,type=Path);a=p.parse_args()
 here=Path(__file__).parent;pins=json.loads((here/'SOURCE_HASHES.json').read_text());b=(a.base/'scripts/combat/fengli_sim.gd').read_bytes();c=a.candidate.read_bytes()
 assert hashlib.sha256(b).hexdigest()==pins['scripts/combat/fengli_sim.gd']
 assert hashlib.sha256(c).hexdigest()==pins['candidate']
 assert hashlib.sha256((a.base/'scripts/combat/fengli_sector_geometry.gd').read_bytes()).hexdigest()==pins['geometry']
 assert c.decode()==b.decode().replace('if not dash:shape["fengli_circle_sector"]=true','shape["fengli_circle_sector"]=true').replace('# Opt-in ordinary Fengli basic only; all shared/default cone and dash queries unchanged.','# Opt-in Fengli basic and dash attack; shared/default cone queries unchanged.')
 n=0;added=0
 for angle in (-180,-100,-65,-55,-50,-25,0,25,50,55,65,100,180):
  for d in (0,.2,1.,1.8,2.,2.2,2.6,3.):
   x,z=d*math.sin(math.radians(angle)),d*math.cos(math.radians(angle))
   for r in (0,.35,.45,.65,.85):
    got=fixed(x,z,r);distance=oracle_distance(x,z)
    if abs(distance-r)>.002:assert got==(distance<r),(angle,d,r,distance)
    assert got==fixed(-x,z,r)
    if d>R+r:assert not got
    if old(x,z,r):assert got
    if got and not old(x,z,r):added+=1
    n+=1
 # Clear side-edge overlap, separated from origin, arc and angular boundary.
 x,z=1.5*math.sin(math.radians(60)),1.5*math.cos(math.radians(60))
 assert not old(x,z,.35) and fixed(x,z,.35)
 # Existing downstream gates are untouched, not independently executed here.
 core=(a.base/'scripts/combat/hero_combat_core.gd').read_text();s=core.split('func _sweep_dash_attack(')[1].split('\nfunc ')[0]
 for token in ('target.actor_id in dash_attack.hits','_move_clipped(contact,target.position,.05)','claim_hit(dash_attack.cast_id,target.actor_id,"basic")'):assert token in s
 print(json.dumps({'geometry_cases':n,'new_body_edge_overlaps':added,'nominal_radius':R,'nominal_degrees':100,'source_scope_exact':True,'occlusion_and_claim_code_unchanged':True,'engine_run':False,'parser_run':False,'obstacle_gameplay_test':False,'single_hit_gameplay_test':False},indent=2))
if __name__=='__main__':main()
