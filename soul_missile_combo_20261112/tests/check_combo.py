"""Offline combined presentation scope/compatibility checks; not runtime proof."""
from pathlib import Path
import argparse,hashlib,json
p=argparse.ArgumentParser();p.add_argument('--before',type=Path,required=True);p.add_argument('--after',type=Path,required=True);p.add_argument('--g10',type=Path,required=True);p.add_argument('--g16',type=Path,required=True);a=p.parse_args();checks=[]
def ck(n,x):
 checks.append({'check':n,'passed':bool(x)});assert x,n
n='fengli_route_20261024/presentation.gd';s=(a.after/n).read_text();b=(a.before/n).read_text()
ck('all_function_signatures_unchanged',[l for l in s.splitlines() if l.startswith('func ')]==[l for l in b.splitlines() if l.startswith('func ')])
for helper,src in [('soul_pickup_view.gd',a.g10),('missile_view.gd',a.g16)]:
 ck(helper+'_exact_approved_candidate_bytes',(a.after/'fengli_route_20261024'/helper).read_bytes()==(src/'fengli_route_20261024'/helper).read_bytes())
for h in ['soul_pickups','missile_view']:
 ck(h+'_scope_and_death_cleanup',s.count(h+'.clear();')==3)
ck('owner_invalid_hides_presentation','visible=false;_visual_error("presentation_owner_or_source_invalid");return' in s)
ck('soul_ground_before_actors',s.index('soul_pickups.draw_ground')<s.index('_e2_shadow_body()',s.index('func _draw')))
ck('missile_after_enemy_projectiles',' _draw_enemy_projectiles()\n missile_view.draw(self,host.sim)' in s)
ck('soul_event_and_receipt',' soul_pickups.accept(event,host.sim)' in s and 'receipt["soul_pickups"]' in s)
changed={x.relative_to(a.after).as_posix() for x in a.after.rglob('*') if x.is_file() and (not (a.before/x.relative_to(a.after)).exists() or x.read_bytes()!=(a.before/x.relative_to(a.after)).read_bytes())}
ck('only_visual_helpers_presentation_and_reseal',changed=={n,'fengli_route_20261024/soul_pickup_view.gd','fengli_route_20261024/missile_view.gd','first_hero_full_admission_20261020/manifest.json','release_generation_20261020/generation.gd'})
m=a.after/'first_hero_full_admission_20261020/manifest.json';g=a.after/'release_generation_20261020/generation.gd';sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
ck('all_259_bindings',json.loads(m.read_text())['files']=={'res://'+x.relative_to(a.after).as_posix():sha(x) for x in a.after.rglob('*') if x.is_file() and x not in [m,g]} and len(json.loads(m.read_text())['files'])==259)
ck('generation_pin','const MANIFEST_SHA := "'+sha(m)+'"' in g.read_text())
print(json.dumps({'status':'OFFLINE_ONLY','checks':checks,'count':len(checks)},indent=2))
