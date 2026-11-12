"""Offline exact-transplant and observer-scope checks. Does not launch an engine."""
from pathlib import Path
import argparse,json,hashlib
p=argparse.ArgumentParser();p.add_argument('--parent',type=Path,required=True);p.add_argument('--after',type=Path,required=True);p.add_argument('--dash',type=Path,required=True);p.add_argument('--original-observers',type=Path,required=True);a=p.parse_args();D=Path(__file__).resolve().parent;checks=[]
def ck(n,v):
 checks.append({'check':n,'passed':bool(v)});assert v,n
n='fengli_route_20261024/presentation.gd';b=(a.parent/n).read_text();s=(a.after/n).read_text();old='  if str(animation.get("kind",""))=="attack_started":';new='  if str(animation.get("kind","")) in ["attack_started","dash_attack_started"]:'
ck('one_exact_aim_site',b.count(old)==1)
ck('only_one_presentation_line_changed',s==b.replace(old,new,1))
ck('all_existing_function_signatures_preserved',[x for x in s.splitlines() if x.startswith('func ')]==[x for x in b.splitlines() if x.startswith('func ')])
for h in ['soul_pickup_view.gd','missile_view.gd']:
 ck(h+'_unchanged',(a.parent/'fengli_route_20261024'/h).read_bytes()==(a.after/'fengli_route_20261024'/h).read_bytes())
for h in ['soul_pickups','missile_view']:
 ck(h+'_cleanup_preserved',s.count(h+'.clear();')==b.count(h+'.clear();')==3)
ck('original_dash_helper_exact',(a.after/'fengli_route_20261024/puppet_motion.gd').read_bytes()==(a.dash/'fengli_route_20261024/puppet_motion.gd').read_bytes())
changed={x.relative_to(a.after).as_posix() for x in a.after.rglob('*') if x.is_file() and (not (a.parent/x.relative_to(a.after)).exists() or x.read_bytes()!=(a.parent/x.relative_to(a.after)).read_bytes())}
ck('no_gameplay_or_other_changes',changed=={n,'fengli_route_20261024/puppet_motion.gd','first_hero_full_admission_20261020/manifest.json','release_generation_20261020/generation.gd'})
for name in ['observe_dash_attack_pitch.gd','observe_dash_attack_pitch_mirror.gd']:
 before=(a.original_observers/name).read_text();after=(D/name).read_text()
 ck(name+'_two_old_sites',before.count('host.presentation.puppet_motion.receipt')==2)
 ck(name+'_only_current_frame_receipt_fix',after==before.replace('host.presentation.puppet_motion.receipt','host.presentation.receipt.get("puppet_motion",{}).duplicate(true)'))
 ck(name+'_no_stale_helper_read','host.presentation.puppet_motion.receipt' not in after)
m=a.after/'first_hero_full_admission_20261020/manifest.json';g=a.after/'release_generation_20261020/generation.gd';sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest();actual={'res://'+x.relative_to(a.after).as_posix():sha(x) for x in a.after.rglob('*') if x.is_file() and x not in [m,g]}
ck('259_exact_bindings',len(actual)==259 and json.loads(m.read_text())['files']==actual)
ck('generation_exact','const MANIFEST_SHA := "'+sha(m)+'"' in g.read_text())
print(json.dumps({'status':'OFFLINE_ONLY_NOT_ENGINE_VALIDATED','count':len(checks),'checks':checks},indent=2))
