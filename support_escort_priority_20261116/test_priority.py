"""Independent branch model plus optional source invariance, never GDScript."""
import argparse,hashlib,itertools,json
from pathlib import Path
ap=argparse.ArgumentParser();ap.add_argument('--before',type=Path);ap.add_argument('--after',type=Path);a=ap.parse_args()
checks=0;changed=0
for kind,guard,distance,clear in itertools.product(['support','ranged','pitcher','minion'],[False,True],[0.,4.999,5.,5.001,10.],[False,True]):
 escort=kind=='support' and guard and distance>5.0
 before=kind in ['ranged','support'] and not clear
 after=kind in ['ranged','support'] and not escort and not clear
 if escort and not clear:assert before and not after;changed+=1
 else:assert before==after
 checks+=1
source=False
if a.before or a.after:
 assert a.before and a.after,'Supply both source paths'
 b=a.before.read_bytes();c=a.after.read_bytes()
 assert hashlib.sha256(b).hexdigest()=='bf6d7226cb3984b04cb2a452011886c1a3fe8f9aa5049a6184413893f5d8e27f'
 assert hashlib.sha256(c).hexdigest()=='324271748dc05975ea5a4e114bef79905bd33db48c8624c900e4dd05ec22da4b'
 def fn(s,n):return s.split('func '+n+'(',1)[1].split('\nfunc ',1)[0]
 for n in ['_in_position','_closest_guard','_clear_shot','_firing_waypoint','_firing_path']:
  assert fn(b.decode(),n)==fn(c.decode(),n),n
 assert 'enemy.erase("sight_path");enemy.erase("sight_target");enemy.erase("sight_left")' in c.decode()
 source=True
print(json.dumps({'branch_cases':checks,'changed_cases':changed,'source_invariance_checked':source,'engine_run':False}))
