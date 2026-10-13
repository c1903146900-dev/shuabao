"""No engine invoked. Patch integrity and independent geometry-model checks only."""
from pathlib import Path
import hashlib,json,subprocess,tempfile,math
root=Path(__file__).resolve().parent
manifest=json.loads((root/'q1_source_patch_manifest.json').read_text())
source=Path(manifest['source']); assert hashlib.sha256(source.read_bytes()).hexdigest()==manifest['base_sha256']
with tempfile.TemporaryDirectory() as tmp:
 target=Path(tmp)/manifest['resource'][6:];target.parent.mkdir(parents=True);target.write_bytes(source.read_bytes())
 subprocess.run(['patch','-p0','-i',str(root/'q1_free_curve_production.patch')],cwd=tmp,check=True,capture_output=True)
 patched=target.read_text(); assert hashlib.sha256(target.read_bytes()).hexdigest()==manifest['patched_sha256']
 old=source.read_text()
 for name,nextname in [('_hero_action_policy','_make_motion'),('_freeze_time_if_due','_update_preview')]:
  # Compare source segments only where delimiters exist.
  if 'func '+name in old and 'func '+nextname in old:
   assert old[old.index('func '+name):old.index('func '+nextname)]==patched[patched.index('func '+name):patched.index('func '+nextname)]
 a=old.index('func _update_preview');b=old.index('func _hero_action_policy',a)
 pa=patched.index('func _update_preview');pb=patched.index('func _hero_action_policy',pa)
 assert old[b:]==patched[pb:]
 prefix=patched[:pa].replace('const Q1FreeCurve=preload("res://visual_rework_20261009/input/q1_free_curve_sampler.gd")\n','')
 assert prefix==old[:a]
 print('PASS exact original SHA, clean patch, patched SHA, all non-preview production code unchanged')
def sample(path,p,cap):
 path=path[:]
 if len(path)==2 and math.dist(*path)<1e-8:path.pop()
 used=sum(math.dist(a,b) for a,b in zip(path,path[1:]));available=max(0,cap-used)
 if available<1e-6:return path,True
 d=math.dist(path[-1],p)
 if d<1e-6:return path,False
 path.append(tuple(a+(b-a)*min(d,available)/d for a,b in zip(path[-1],p)))
 return path,d>=available
p=[(2,1),(2,1)]
for point in [(3,1),(3,2),(2,2),(2,3)]:p,_=sample(p,point,11)
assert len(p)==5 and p[0]==(2,1)
p,limit=sample(p,(2,30),11)
assert limit and abs(sum(math.dist(a,b) for a,b in zip(p,p[1:]))-11)<1e-8
assert sample(p,(100,100),11)[0]==p
print('PASS independent curve model fixed start, multiple bends, arc cap, stopped path')
view=(root.parent/'views/q1_view.gd').read_text()
assert 'func _process' not in view and 'func _physics_process' not in view
assert 'hero_time' in view and 'front_distance' in view and 'released_at' in view
print('PASS presentation has no local process clock; source time/front/release fields consumed')
print('NOT RUN: Godot parser, actual GDScript sampler tests, gameplay input integration, visual render')
