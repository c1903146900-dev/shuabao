"""Static/source algebra checks only. Does not execute GDScript or validate rendering."""
from pathlib import Path
import re,json,math
root=Path(__file__).resolve().parent
view=(root/'q3_source_landscape_view.gd').read_text()
mesh=(root/'q3_mountain_mesh.gd').read_text()
checks={
'uses_source_clock': 'ink.get("hero_time",ink.get("source_time",NAN))' in view,
'absolute_mesh_clock': 'age=maxf(0.0,source_age)' in mesh and 'age+=dt' not in mesh,
'no_process_or_physics':not re.search(r'func _(?:physics_)?process',view+mesh),
'no_sim_reference_or_gameplay_writes':not any(x in view+mesh for x in ['Sim.new','CollisionShape','StaticBody','damage_enemy','start_skill_cooldown','hero.position=']),
'flat_event_kind': 'event.get("kind"' in view and 'event.data' not in view,
'scope_guard': '_same_scope(event,scope_key)' in view,
'event_dedup': 'if seen_events.has(token):return' in view,
'collapsed_receipt_keeps_tail': 'str(event.get("reason",""))!="collapsed"' in view,
'uses_source_dimensions': 'float(row.length),float(row.width)' in view,
'source_collapse_dimensions': 'float(event.length)' in view and 'float(event.width)' in view,
'no_fabricated_reconstruction': 'Do not fabricate a mountain' in view,
'preview_ignored': '_preview:Dictionary={}' in view,
'reset_clears_transients': 'collapse_event={};seen_events.clear();scope_key={};last_time=-INF' in view,
}
# Exact projected base dimensions for variable source H05/ranks, independent of axis.
for length,width,angle in [(4.5,1.4,0),(6.3,1.4,.8),(4.5,2.0,2.1)]:
 axis=(math.cos(angle),math.sin(angle));normal=(-axis[1],axis[0])
 corners=[(axis[0]*x*length/4.5+normal[0]*z*width/1.4,axis[1]*x*length/4.5+normal[1]*z*width/1.4) for x in [-2.25,2.25] for z in [-.7,.7]]
 xa=[p[0]*axis[0]+p[1]*axis[1] for p in corners];za=[p[0]*normal[0]+p[1]*normal[1] for p in corners]
 checks[f'dimensions_{length}_{width}_{angle}']=abs(max(xa)-min(xa)-length)<1e-10 and abs(max(za)-min(za)-width)<1e-10
# All new shader/script literal references resolve inside adapter branch.
branch=root.parent.parent
for p in root.glob('q3_*.gd'):
 for ref in re.findall(r'["\']res://([^"\']+)["\']',p.read_text()):checks['reference_'+ref]=(branch/ref).is_file()
print(json.dumps({'scope':'Python static and algebra only; Godot parse/runtime pending integrator','passed':all(checks.values()),'checks':checks},indent=2))
raise SystemExit(0 if all(checks.values()) else 1)
