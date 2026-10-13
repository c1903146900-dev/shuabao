#!/usr/bin/env python3
"""Small source-only gate, exact parent maps and explicit predecessor replacements."""
import argparse, hashlib, json, re
from pathlib import Path
O=Path(__file__).resolve().parent; R=O.parents[2]; Q=R/'tests/ink_q2_ordinary_20261005/candidate01'
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p): return p.read_text()
checks=[]; failures=[]
def check(ok,label):
 checks.append(label)
 if not ok: failures.append(label)
p=argparse.ArgumentParser();p.add_argument('--freeze',action='store_true');a=p.parse_args()
pre=json.loads(read(O/'preimage_manifest.json'))
for name,item in pre.items(): check(sha(O/'preimage'/name)==item['sha256'],'exact preimage '+name)
front='scripts/integration/yanguizhou_first_floor.gd'
old=read(O/'preimage'/front)
check(read(R/front)==old.replace('extends "res://tests/ink_q2_ordinary_20261005/candidate01/host.gd"','extends "res://tests/ink_e1_ordinary_20261005/candidate01/host.gd"',1),'adapter changes only exact leaf extends')
entry='scripts/integration/hero_entry.gd';old=read(O/'preimage'/entry)
needle='func filter_session_input(event: InputEvent) -> void:\n\tif event is InputEventKey:\n\t\tvar key: int = event.physical_keycode if event.physical_keycode else event.keycode\n'
addition='\t\t# The disabled Ink room cannot receive a real release while the chooser is up.\n\t\t# Forward only this exact room\'s owned E1 release; retain every fence below.\n\t\tif key == KEY_E and not event.pressed and not event.echo and (screen != Screen.RUN or _blocked_keys.has(key)) and _is_yanguizhou_room() and active_room.has_method("frontdoor_observe_e1_release"):\n\t\t\tactive_room.frontdoor_observe_e1_release(event)\n'
check(old.count(needle)==1 and read(R/entry)==old.replace(needle,needle+addition,1),'entry only genuine owned E-up forwarding; old heroes/fence byte-retained')
chooser=json.loads(read(O/'chooser_text_changes.json'))
expected=read(O/'preimage'/chooser['file'])
for change in chooser['changes']:
 check(expected.count(change['before'])==1,'chooser unique text replacement')
 expected=expected.replace(change['before'],change['after'],1)
check(read(R/chooser['file'])==expected,'only Ink chooser strings change, prior hero branches retained')
check(sha(Q/'source_binding.json')=='c702df4e5b10b2a424f0ca3f0b860fd2d0b7171208965e696c8be72db1bc6cd3','exact c702 Q2 parent manifest unchanged')
check(sha(R/'tests/ink_e1_rain_foundation_20261005/fix01/source_binding.json')=='7a0da1f04790c8e2c6d71036a42dccdb8222393f8721cc8e1d26972a3c9db9ab','exact old E1 manifest unchanged')
parents=['tests/ink_e1_rain_foundation_20261005/fix01/runtime_binding.json','tests/ink_q2_foundation_20261005/fix01/runtime_binding.json','tests/ink_q3_input_growth_20261004/runtime_binding.json']
upstream=[]
for name in parents:
 data=json.loads(read(R/name));bad=[]
 for target,item in data['runtime_map'].items():
  source=R/item.get('source',target)
  if not source.is_file() or sha(source)!=item['sha256']: bad.append(target)
 check(not bad,'mapped parent bytes '+name);upstream.append({'binding':name,'files':len(data['runtime_map']),'mismatches':bad})
for name in ['source_binding.json']:
 data=json.loads(read(R/'tests/ink_e1_rain_foundation_20261005/fix01'/name))
 for key in ['upstream','own_files']:
  check(all((R/x).is_file() and sha(R/x)==h for x,h in data[key].items()),'old E1 '+key+' remains intact')
q2=json.loads(read(Q/'source_binding.json'))
for name,h in q2['runtime_map'].items():
 rel=name.removeprefix('res://')
 check(sha(O/'preimage'/rel)==h if rel in pre else sha(R/rel)==h,'Q2 predecessor pin '+rel)
prov=json.loads(read(O/'rebase_provenance.json'))
for name,item in prov['entries'].items():
 source=R/item['source']; check(sha(source)==item['source_sha256'],'exact E1 rebase predecessor '+name)
 expected=read(source).replace('extends "'+item['base_replacement']['before']+'"','extends "'+item['base_replacement']['after']+'"',1)
 if name=='sim.gd':
  expected=expected.replace('var _rain_pull_capture: Dictionary = {}','var _rain_pull_capture: Dictionary = {}\nvar _e1_boundary_owner: Dictionary = {}',1).replace('func _hero_clear_transients() -> void:\n _rain_pull_capture = {}','func _hero_clear_transients() -> void:\n _e1_boundary_owner = {}\n _rain_pull_capture = {}',1)
 check(read(O/name)==expected if name in ['rain_layer.gd','input_base.gd'] else read(O/name).startswith(expected),'bounded rebase preserves predecessor methods '+name)
 if a.freeze:
  item.setdefault('first_authored_sha256',item['sha256']);item['sha256']=sha(O/name)
for name in ['bridge.gd','floor_session.gd','navigation_install.gd']:
 expected=read(Q/name).replace('res://tests/ink_q2_ordinary_20261005/candidate01/','res://tests/ink_e1_ordinary_20261005/candidate01/').replace('res://tests/ink_q2_foundation_20261005/fix01/ink_q2_sim.gd','res://tests/ink_e1_ordinary_20261005/candidate01/sim.gd')
 check(read(O/name)==expected,'exact adapter-only rebase; economic/route algorithms unchanged '+name)
pattern=r'^const FIRST_SLICE_HEX_HOOKS = (.+)$'
hooks=json.loads(re.search(pattern,read(O/'catalog.gd'),re.M).group(1))
check(len(hooks)==10 and hooks==json.loads(re.search(pattern,read(Q/'catalog.gd'),re.M).group(1)),'original ten hooks, no H07/H08')
check('FIRST_SLICE_ALLOWED_CANDIDATES = ["Q1", "Q2", "Q3", "E1"]' in read(O/'catalog.gd'),'base E1 only candidate addition')
for name in ['sim.gd','rain_layer.gd','input_adapter.gd','input_base.gd','host.gd']:
 check(not re.search(r'(?:preload|extends).*ink_e[23]|(?:preload|extends).*ink_p1',read(O/name)),'no E2/E3/P1 composite '+name)
queue=read(O/'sim.gd').split('func request_e1_boundary_release',1)[1]
check('ink_rain.release_pending = true' in queue and not re.search(r'(?<!_)\bstep\s*\(|damage_enemy\(|_e1_reform\(',queue),'boundary command queues only, no extra world step or damage')
check('var scripts: Array[GDScript]' in read(O/'parse_gate.gd') and 'for script: GDScript' in read(O/'parse_gate.gd'),'Godot4.6 typed Script parse gate')
check(not any(re.search(r'^const Projection\b',read(x),re.M) for x in O.glob('*.gd')),'no forbidden built-in Projection constant name')
production=[x for x in O.glob('*.gd') if x.name not in ['finite_gate.gd','parse_gate.gd']]
runtime={'res://'+str(x.relative_to(R)):sha(x) for x in production}
runtime.update({'res://'+name:sha(R/name) for name in pre})
binding={'schema':'ink-e1-q2-ordinary-overlay-1','status':'SOURCE_COMPOSITION_ENGINE_NATIVE_NOT_RUN','runtime_candidates':['Q1','Q2','Q3','E1'],'supported_hex_hooks':hooks,'runtime_map':dict(sorted(runtime.items())),'parent_runtime_maps':{'res://'+x:sha(R/x) for x in parents},'ancestor_pin_replacements':{'res://'+name:{'before':pre[name]['sha256'],'after':sha(R/name),'scope':'exact leaf extends only' if name==front else 'Ink-only chooser string replacements'} for name in [front,chooser['file']]},'entrypoint_changes':{name:{'before':item['sha256'],'after':sha(R/name)} for name,item in pre.items()},'H07_H08_offered':False,'engine_passed':False,'native_passed':False,'art_audio_implemented':False,'ordinary_only_collision_verified':False}
if a.freeze:
 if failures: raise SystemExit(json.dumps({'passed':False,'failures':failures},ensure_ascii=False))
 (O/'rebase_provenance.json').write_text(json.dumps(prov,ensure_ascii=False,indent=2)+'\n')
 (O/'source_binding.json').write_text(json.dumps(binding,ensure_ascii=False,indent=2)+'\n')
else: check(json.loads(read(O/'source_binding.json'))==binding,'exact final overlay pins')
result={'passed':not failures,'checks':len(checks),'failures':failures,'assertions':checks,'upstream':upstream,'engine_run':False,'gdscript_parse':'NOT_RUN','native_input':'NOT_RUN','source_binding_sha256':sha(O/'source_binding.json')}
(O/'source_result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ['assertions','upstream']},ensure_ascii=False));raise SystemExit(0 if not failures else 1)
