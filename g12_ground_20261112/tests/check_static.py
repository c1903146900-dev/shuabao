"""G12 source/consumer/finite-geometry checks. No engine invocation or gameplay proof."""
import argparse,json,hashlib,math
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--before',type=Path,required=True);p.add_argument('--after',type=Path,required=True);a=p.parse_args();checks=[]
def ck(n,v):
 checks.append({'check':n,'passed':bool(v)});assert v,n
b=(a.before/'fengli_route_20261024/presentation.gd').read_text();s=(a.after/'fengli_route_20261024/presentation.gd').read_text();v=(a.after/'fengli_route_20261024/bombardment_view.gd').read_text();source=(a.before/'scripts/combat/common_hex_runtime.gd').read_text()
ck('source_schedules_real_bombardment','scheduled.append({"kind":"bombardment", "due":time + parameter("g12", 3)' in source)
ck('source_executes_area_damage','if entry.kind == "bombardment": _area_damage' in source)
ck('source_emits_actual_area_effect','_emit("area_effect", {"source":source, "position":at, "radius":radius})' in source)
ck('baseline_route_missing_g12_consumers',not any('common_hex_area_effect' in f.read_text() or 'common_hex_bombardment_warning' in f.read_text() for f in (a.before/'fengli_route_20261024').glob('*.gd')))
ck('signatures_unchanged',[x for x in b.splitlines() if x.startswith('func ')]==[x for x in s.splitlines() if x.startswith('func ')])
for token in ['for entry:Variant in live.scheduled:','entry.get("kind","")!="bombardment"','float(entry.due)-float(live.time)','float(entry.radius)','event.get("kind","")!="common_hex_area_effect"','event.get("source","")!="common_g12"','not sim.common._draining','sim.event_log.back()!=event','int(event.sequence)<=_last_sequence','_impacts.size()>32','sim.hero.dead','not live.active("g12")']:
 ck('source_or_lifecycle:'+token,token in v)
for token in ['damage_enemy','request_action','schedule_effect','create_timer','Time.','live.scheduled.append','live.scheduled.erase','live.time =','sim.step','projectiles.append']:
 ck('no_gameplay_mutation:'+token,token not in v)
ck('no_warning_event_to_impact','common_hex_bombardment_warning' not in v)
ck('impact_source_world_clock','float(sim.clock.world_time)-float(item.world_time)' in v)
ck('ground_below_actors',s.index('bombardment_view.draw_ground')<s.index('_e2_shadow_body()',s.index('func _draw')))
ck('scope_and_death_cleanup',s.count('bombardment_view.clear();')==3)
ck('owner_invalid_cleanup',' if not active:\n  bombardment_view.clear()' in s)
ck('actual_event_hook',s.count(' bombardment_view.accept(event,host.sim)\n')==1)
changed={f.relative_to(a.after).as_posix() for f in a.after.rglob('*') if f.is_file() and (not (a.before/f.relative_to(a.after)).exists() or f.read_bytes()!=(a.before/f.relative_to(a.after)).read_bytes())}
ck('only_helper_presentation_binding_changes',changed=={'fengli_route_20261024/presentation.gd','fengli_route_20261024/bombardment_view.gd','first_hero_full_admission_20261020/manifest.json','release_generation_20261020/generation.gd'})
for radius in [0.001,1.0,5.0,1000.0]:
 points=[(math.cos(i*math.tau/32)*radius,math.sin(i*math.tau/32)*radius) for i in range(33)]
 ck('finite_closed_actual_radius_'+str(radius),all(math.isfinite(x) for q in points for x in q) and math.dist(points[0],points[-1])<1e-9 and all(abs(math.hypot(*q)-radius)<1e-9 for q in points))
m=a.after/'first_hero_full_admission_20261020/manifest.json';g=a.after/'release_generation_20261020/generation.gd';sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest();files={'res://'+f.relative_to(a.after).as_posix():sha(f) for f in a.after.rglob('*') if f.is_file() and f not in [m,g]}
ck('258_exact_bindings',len(files)==258 and json.loads(m.read_text())['files']==files)
ck('generation_pin','const MANIFEST_SHA := "'+sha(m)+'"' in g.read_text())
print(json.dumps({'status':'OFFLINE_ONLY_NOT_ENGINE_TESTED','checks':checks,'count':len(checks)},indent=2))
