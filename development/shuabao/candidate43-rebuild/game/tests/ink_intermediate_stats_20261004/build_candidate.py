#!/usr/bin/env python3
"""Build only this isolated source candidate; never starts an engine."""
from pathlib import Path
import json,difflib
H=Path(__file__).resolve().parent;R=H.parents[1]
source=json.loads((R/'docs/equipment_source_20261004/correction_0959/equipment_system_extracted.json').read_text())
numeric=json.loads((R/'tests/equipment_editable_tables_20261004/outputs/equipment_tables/converted/equipment_numeric_config.json').read_text())
base_map={"AD":['attack_points','AD',1.0],"AP":['ability_points','AP',1.0],"attack_speed_pct":['percent_points','attack_speed',.01],"crit_chance_pct":['percent_points','crit_chance',.01],"cdr_pct":['percent_points','cooldown_reduction',.01],"max_health":['health_points','max_hp',1.0],"defense":['defense_points','defense',1.0],"move_speed_pct":['percent_points','move_speed',.01],"lifesteal_pct":['percent_points','lifesteal',.01],"tenacity_pct":['percent_points','tenacity',.01],"penetration":['penetration_points','penetration',1.0],"health_regen":['health_regen_source_units','',1.0]}
rows=[];mapping={}
for e in source['equipment']:
 if e['tier'] not in ['base','intermediate']:continue
 fields=[];stats={};params=[]
 for stat in e['source_attributes_parsed']:
  name=stat['stat'];key=e['id']+'.stat.'+name;v=numeric['parameters'][key];unit,sink,scale=base_map[name]
  assert v['unit']==unit
  fields.append([name,unit,sink,scale]);params.append({'parameter':key,**v,'runtime_stat':sink,'scale':scale})
  if sink:stats[sink]=v['value']*scale
 supported=e['id'] not in ['base:B12','intermediate:I12']
 price=numeric['parameters'][e['id']+'.price']['value']
 components=[c['item_id'] for c in e['components'] for _ in range(c['quantity'])]
 rows.append({'id':e['id'],'name':e['name'],'tier':e['tier'],'supported':supported,'hold_reason':'' if supported else 'regen_time_unit_unresolved','source_exact_compact':e['source_exact_compact'],'mechanism_ids':e['mechanism_ids'],'components':components,'price':price,'combine_fee':price-sum(numeric['parameters'][c+'.price']['value'] for c in components),'parameter_mapping':params,'expected_stats':stats if supported else {}})
 if e['tier']=='intermediate':mapping[e['id']]=fields
(H/'source_map.json').write_text(json.dumps({'schema':1,'scope':'11 base +17 intermediate exact source stat slice; I12/B12 all-or-nothing HOLD; final and consumable effects HOLD','rows':rows},ensure_ascii=False,indent=2)+'\n')
(H/'intermediate_stat_adapter.gd').write_text('''extends RefCounted
## Extend the tested base adapter only with original intermediate stat parameters.
## Fixed IDs/units/sinks; edited numeric values come from the formal parameter map.
## I12 is wholly blocked. Its known HP does not justify selling inert regen.
const BaseAdapter=preload("res://tests/ink_shop_runtime_stats_20261004/base_stat_adapter.gd")
const INTERMEDIATE_MAPPING='''+json.dumps(mapping,ensure_ascii=False,indent=1)+'''
static func build(numeric: Dictionary)->Dictionary:
 if not numeric.get("parameters") is Dictionary:return _deny("numeric_parameters_missing")
 # Validate node shapes before the inherited base adapter or typed Dictionary
 # access can fail. Serialized scalar/null parameter nodes are malformed input.
 for id in BaseAdapter.MAPPING:
  var key: String=id+".stat."+str(BaseAdapter.MAPPING[id][0])
  if not numeric.parameters.get(key) is Dictionary:return _deny("invalid_stat_entry:"+key)
 for id in INTERMEDIATE_MAPPING:
  for mapping in INTERMEDIATE_MAPPING[id]:
   var key: String=id+".stat."+str(mapping[0])
   if not numeric.parameters.get(key) is Dictionary:return _deny("invalid_stat_entry:"+key)
 var result: Dictionary=BaseAdapter.build(numeric)
 if not result.accepted:return result
 var definitions: Dictionary=result.definitions
 for id in INTERMEDIATE_MAPPING:
  var stats: Dictionary={}
  var sources: Array=[]
  var supported: bool=true
  for mapping in INTERMEDIATE_MAPPING[id]:
   var parameter: String=id+".stat."+str(mapping[0])
   var entry: Dictionary=numeric.parameters.get(parameter,{})
   var value: Variant=entry.get("value",null)
   if not (value is int or value is float) or not is_finite(float(value)) or float(value)<0.0:return _deny("invalid_stat_value:"+parameter)
   if entry.get("unit","")!=mapping[1]:return _deny("invalid_stat_unit:"+parameter)
   if str(mapping[2]).is_empty():supported=false
   else:stats[mapping[2]]=float(value)*float(mapping[3])
   sources.append({"parameter":parameter,"source_ref":entry.get("source_ref",""),"source_unit":mapping[1],"current_value":value,"source_value":entry.get("source_value",null),"runtime_stat":mapping[2],"scale":mapping[3]})
  if not supported:stats.clear()
  definitions[id]={"supported":supported,"reason":"" if supported else "regen_time_unit_unresolved","stats":stats,"parameters":sources,"passives":[],"actives":[],"tier":"intermediate","rule_provenance":"source_equipment_value_existing_runtime_projection_not_final_balance"}
 return {"accepted":true,"reason":"","definitions":definitions}
static func _deny(reason: String)->Dictionary:return {"accepted":false,"reason":reason}
''')
(H/'ink_intermediate_sim.gd').write_text('''extends "res://tests/ink_initial_hex_runtime_20261004/ink_initial_sim.gd"
## Exact composition preserves c997 H02, six common hooks, and HP dependency observer.
## No new simulation, input, reward, HP, or wallet implementation.
''')
(H/'ink_intermediate_model.gd').write_text('''extends "res://tests/ink_initial_hex_runtime_20261004/ink_initial_model.gd"
## Same ledger/kernel, component inverse patches, health journal, and selector.
## The inherited consumer sums ONLY currently held UID entries. Consumed recipe
## components remain audit lineage, never a second source of derived stats.
func equipment_runtime_status(id: String)->Dictionary:
 if not commerce_definitions.items.has(id):return {"supported":false,"reason":"unknown_item"}
 if commerce_definitions.items[id].kind!="equipment":return {"supported":false,"reason":"consumable_effect_consumer_not_connected"}
 if not runtime_stat_definitions.has(id):return {"supported":false,"reason":"outside_base11_intermediate17_slice"}
 return runtime_stat_definitions[id].duplicate(true)
func equipment_effects()->Dictionary:
 var out: Dictionary=super.equipment_effects()
 if not runtime_stat_definitions.is_empty():out.status="base11_intermediate17_runtime_candidate"
 return out
func snapshot()->Dictionary:
 var out: Dictionary=super.snapshot()
 out.content_profile="base11_intermediate17_runtime_candidate"
 out.content_warnings=[{"reason":"source_values_unbalanced_B12_I12_regen_final_and_consumable_effects_hold"}]
 return out
''')
text=(R/'tests/ink_initial_hex_runtime_20261004/ink_initial_bridge.gd').read_text()
text=text.replace('const HealthModel=preload("res://tests/ink_initial_hex_runtime_20261004/ink_initial_model.gd")','const IntermediateModel=preload("res://tests/ink_intermediate_stats_20261004/ink_intermediate_model.gd")\nconst IntermediateAdapter=preload("res://tests/ink_intermediate_stats_20261004/intermediate_stat_adapter.gd")')
text=text.replace('res://tests/ink_initial_hex_runtime_20261004/ink_initial_sim.gd','res://tests/ink_intermediate_stats_20261004/ink_intermediate_sim.gd').replace('StatAdapter.build(numeric)','IntermediateAdapter.build(numeric)').replace('HealthModel.new','IntermediateModel.new').replace('initial-hex-hp-undo-fixture','base11-intermediate17-hp-undo-fixture').replace('base_11_runtime_unbalanced','base11_intermediate17_runtime_unbalanced')
text=text.replace('## Narrow startup substitution; original stat bridge and its531 result stay frozen.','## Explicit exact-script candidate startup. No grants, hot replacement, or alternate wallet.')
(H/'ink_intermediate_bridge.gd').write_text(text)
# Keep original runtime regression assertions byte-identical except explicit new
# Sim/Bridge/Model bindings, source binding identity, and isolated result location.
regressions=[('tests/ink_initial_hex_runtime_20261004/fix01/sink_gate.gd','common_regression_gate.gd'),('tests/ink_initial_hex_runtime_20261004/hp_regression_gate.gd','hp_regression_gate.gd'),('tests/ink_initial_hex_runtime_20261004/selector_gate.gd','selector_regression_gate.gd')]
patches=[]
for path,name in regressions:
 old=(R/path).read_text();new=old
 for a,b in [('ink_initial_sim.gd','ink_intermediate_sim.gd'),('ink_initial_bridge.gd','ink_intermediate_bridge.gd'),('ink_initial_model.gd','ink_intermediate_model.gd')]:
  new=new.replace('res://tests/ink_initial_hex_runtime_20261004/'+a,'res://tests/ink_intermediate_stats_20261004/'+b)
 new=new.replace('res://tests/ink_initial_hex_runtime_20261004/fix01/source_binding.json','res://tests/ink_intermediate_stats_20261004/source_binding.json')
 new=new.replace('res://tests/ink_initial_hex_runtime_20261004/source_binding.json','res://tests/ink_intermediate_stats_20261004/source_binding.json')
 for a in ['fix01/sink_result.json','hp_result.json','selector_result.json']:
  new=new.replace('res://tests/ink_initial_hex_runtime_20261004/'+a,'res://tests/ink_intermediate_stats_20261004/'+name.replace('_gate.gd','_result.json'))
 # Preserve upstream pin as a clearly labelled ancestry claim, not this candidate.
 new=new.replace('"runtime_source_binding_id":"c997','"upstream_runtime_source_binding_id":"c997')
 new=new.replace('"suite":"ink_same_visit_exact_hp_clamp_undo"','"suite":"ink_same_visit_exact_hp_clamp_undo","source_binding_id":FileAccess.get_sha256("res://tests/ink_intermediate_stats_20261004/source_binding.json")')
 (H/name).write_text(new)
 patches.extend(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile=path,tofile=str(H.relative_to(R)/name)))
(H/'regression_rebindings.patch').write_text(''.join(patches))
(H/'.gdignore').write_text('')
print('Built isolated intermediate adapter/model/bridge/sim, source map, and three explicitly rebound regression gates')
