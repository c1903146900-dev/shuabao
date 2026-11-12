"""Offline source/integration and finite glyph checks. NOT Godot execution."""
from pathlib import Path
import argparse,hashlib,json,math
p=argparse.ArgumentParser();p.add_argument('--before',type=Path,required=True);p.add_argument('--after',type=Path,required=True);a=p.parse_args();before=a.before;after=a.after
v=(after/'fengli_route_20261024/missile_view.gd').read_text();pres=(after/'fengli_route_20261024/presentation.gd').read_text();old=(before/'fengli_route_20261024/presentation.gd').read_text();checks=[]
def ck(name,ok):
 checks.append({'check':name,'passed':bool(ok)})
 assert ok,name
ck('presentation_function_signatures_unchanged',[x for x in pres.splitlines() if x.startswith('func ')]==[x for x in old.splitlines() if x.startswith('func ')])
ck('baseline_missing_common_missile_render','common.runtime.projectiles' not in old and 'MissileView' not in old)
ck('real_source_iterator','for entry:Variant in live.projectiles:' in v)
for s in ['entry.get("kind","")!="missile"','entry.get("source","")!="common_g16"','live.generation!=sim.encounter_generation','live.room_id!=sim.room_id','not live.active("g16")','sim.hero.dead','sim.phase!="combat"','float(entry.left)<=0.0','target.get("dead",true)']:
 ck('source_gate:'+s,s in v)
ck('no_gameplay_mutator',all(s not in v for s in ['request_action','damage_enemy','emit_event','create_timer','live.projectiles.append','live.projectiles.erase','sim.step','Time.','delta']))
ck('no_event_spawn_entry','func accept(' not in v)
ck('no_retained_entity_store','var receipt:Dictionary={}' in v and all(s not in v for s in ['var _missiles','var _targets']))
ck('receipt_and_draw_hook','missile_view.draw(self,host.sim)' in pres and 'receipt["common_missiles"]' in pres)
ck('scope_clear_hook',pres.count('missile_view.clear();')==3)
changes=[]
for x in before.rglob('*'):
 if x.is_file() and x.read_bytes()!=(after/x.relative_to(before)).read_bytes():changes.append(x.relative_to(before).as_posix())
ck('only_presentation_and_binding_change',set(changes)=={'fengli_route_20261024/presentation.gd','first_hero_full_admission_20261020/manifest.json','release_generation_20261020/generation.gd'})
new={x.relative_to(after).as_posix() for x in after.rglob('*') if x.is_file()}-{x.relative_to(before).as_posix() for x in before.rglob('*') if x.is_file()}
ck('only_one_new_renderer',new=={'fengli_route_20261024/missile_view.gd'})
# Same source glyph scalar constants; no screenshots or renderer acceptance.
ck('tested_geometry_matches_source',all(x in v for x in ['direction*7.0','direction*5.0+side*4.0','direction*2.0','direction*12.0']))
for i in range(16):
 ang=i*math.tau/16;d=(math.cos(ang),math.sin(ang));side=(-d[1],d[0]);pts=[(7*d[0],7*d[1]),(-5*d[0]+4*side[0],-5*d[1]+4*side[1]),(-2*d[0],-2*d[1]),(-5*d[0]-4*side[0],-5*d[1]-4*side[1])]
 ck('finite_bounded_glyph_'+str(i),all(math.isfinite(t) for q in pts for t in q) and max(math.hypot(*q) for q in pts)<=7.000001)
print(json.dumps({'status':'OFFLINE_ONLY','checks':checks,'count':len(checks),'engine_run':False},indent=2))
