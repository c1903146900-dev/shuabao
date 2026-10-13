extends RefCounted
## Draft successor of the stable D06 adapter. No admission before bound consumers.
const Existing = preload("res://equipment_counterattack_20261013/adapter.gd")
const SourceChecks = preload("res://equipment_scholar_20261011/adapter.gd")
const RegenUnits = preload("res://tests/ink_equipment_regen_20261008/candidate01/regen_units.gd")
const GoldTask = preload("task04.gd")
const SOURCE := "res://docs/equipment_source_20261004/correction_0959/equipment_system_extracted.json"
const POLICY := "res://data/final_design/equipment_tasks.json"
const STATS := [["move_speed_pct","percent_points","move_speed",12.0,0.01],["health_regen","health_regen_source_units","hp_regen",5.0,0.2],["cdr_pct","percent_points","cooldown_reduction",12.0,0.01]]
const COMPONENTS := {"intermediate:I09":1250,"intermediate:I12":1050}
const TASK_VALUES := {"stage1_threshold":[5000,"gold"],"stage2_threshold":[10000,"gold"],"stage3_threshold":[15000,"gold"],"move_per_stage":[2,"percent_points"],"regen_per_stage":[1,"health_regen_source_units"],"cdr_per_stage":[2,"percent_points"]}
const RULES := {
 "paragraph:010":"装备任务按“玩家+装备名称”记录；同一任务本局只能按规则完成一次或规定阶段数。出售后已完成阶段、任务进度、永久奖励与进化状态均保留。",
 "paragraph:058":"G04 远征财典｜财源滚滚",
 "paragraph:059":"装备期间累计获得金币，金币支出不降低进度。任务共3阶段：累计获得5000 / 10000 / 15000金币。每完成1阶段，装备永久获得：移动速度+2%，基础生命恢复+1，CDR+2%。初始属性为移速+12%、生命恢复+5、CDR+12%；三阶段完成后为移速+18%、生命恢复+8、CDR+18%。出售后阶段与进度保留。",
 "paragraph:064":"任务规则补充：任务进度仅在装备持有期间继续累计；出售后进度与已完成阶段冻结并永久保留，重新购买后继续。所有“永久技能点”均只对当前远征生效，并受本局技能点总上限约束。"
}

static func build(numeric: Dictionary) -> Dictionary:
 var source: Variant=JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
 var policy: Variant=JSON.parse_string(FileAccess.get_file_as_string(POLICY))
 if not source is Dictionary or not policy is Dictionary:return _deny("g04_original_source_or_policy_missing")
 return build_from_source(numeric,source,policy)

static func build_from_source(numeric: Dictionary, source: Dictionary, policy: Dictionary) -> Dictionary:
 if not numeric.get("parameters") is Dictionary:return _deny("numeric_parameters_missing")
 for field: String in ["held_item_required_for_progress","progress_persists_when_sold","completion_once_per_equipment_per_run"]:
  if policy.get("policy",{}).get(field)!=true:return _deny("g04_original_task_policy_required:"+field)
 for field: String in ["duplicate_copies_multiply_progress","test_mode_counts"]:
  if policy.get("policy",{}).get(field)!=false:return _deny("g04_original_task_policy_required:"+field)
 var item: Dictionary=SourceChecks._one(source.get("equipment"),"id",GoldTask.ITEM_ID)
 if item.get("name")!="远征财典" or item.get("tier")!="final" or item.get("mechanism_ids")!=[] or item.get("source_price")!=2800 or item.get("source_component_total")!=2300 or item.get("source_combine_fee")!=500:return _deny("g04_original_item_required")
 var catalog: Dictionary=SourceChecks._one(numeric.get("catalog"),"owner_id",GoldTask.ITEM_ID)
 if catalog.get("name")!=item.name or catalog.get("kind")!="final" or catalog.get("source_code")!="G04" or catalog.get("mechanism_ids")!="" or catalog.get("source_attributes")!=item.get("source_attributes") or catalog.get("source_effects")!=item.get("source_effects") or not SourceChecks._text(catalog.get("source_ref")):return _deny("g04_catalog_mismatch")
 if not item.get("source_attributes_parsed") is Array or item.source_attributes_parsed.size()!=STATS.size():return _deny("g04_exact_original_stats_required")
 var allowed: Array=[GoldTask.ITEM_ID+".price"]
 var stats: Dictionary={}
 var authored: Dictionary={}
 var refs: Array=[]
 for spec: Array in STATS:
  var key: String=GoldTask.ITEM_ID+".stat."+str(spec[0])
  var row: Variant=numeric.parameters.get(key)
  var original: Dictionary=SourceChecks._one(item.source_attributes_parsed,"stat",str(spec[0]))
  if original.get("value")!=spec[3] or original.get("unit")!=("percent_points" if spec[1]=="percent_points" else "flat") or not SourceChecks._entry(row,str(spec[1]),float(spec[3])):return _deny("g04_invalid_stat:"+key)
  stats[spec[2]]=float(row.value)*float(spec[4]);authored[spec[0]]=float(row.value)
  refs.append(SourceChecks._ref(key,row,float(spec[4])));allowed.append(key)
 for key: Variant in numeric.parameters:
  if str(key).begins_with(GoldTask.ITEM_ID+".") and key not in allowed:return _deny("g04_unsupported_item_parameter:"+str(key))
 var task_source: Dictionary=SourceChecks._one(source.get("tasks"),"equipment_id",GoldTask.ITEM_ID)
 if task_source.get("name")!="财源滚滚" or task_source.get("stage_count")!=3 or task_source.get("source_task")!=(RULES["paragraph:058"]+RULES["paragraph:059"]).replace(" ",""):return _deny("g04_original_task_required")
 var rules: Array=[]
 for id: String in RULES:
  var row: Dictionary=SourceChecks._one(numeric.get("source_rules"),"rule_id",id)
  if row.get("source_text")!=RULES[id] or not SourceChecks._text(row.get("source_ref")):return _deny("g04_source_rule_required:"+id)
  rules.append(row.duplicate(true))
 var tuning: Dictionary={"thresholds":[],"reward_skill_points":0}
 var task_refs: Array=[]
 allowed=[]
 for field: String in TASK_VALUES:
  var key: String=GoldTask.TASK_ID+"."+field
  var row: Variant=numeric.parameters.get(key)
  if not SourceChecks._entry(row,str(TASK_VALUES[field][1]),float(TASK_VALUES[field][0])):return _deny("g04_invalid_task_parameter:"+key)
  if field.begins_with("stage"):
   if not SourceChecks._integer(row.value) or float(row.value)<=0.0:return _deny("g04_invalid_threshold:"+key)
   tuning.thresholds.append(int(row.value))
  else:tuning[field]=float(row.value)
  task_refs.append(SourceChecks._ref(key,row,1.0));allowed.append(key)
 for key: Variant in numeric.parameters:
  if str(key).begins_with(GoldTask.TASK_ID+".") and key not in allowed:return _deny("g04_unsupported_task_parameter:"+str(key))
 if not GoldTask.valid_tuning(tuning) or authored.move_speed_pct+3.0*tuning.move_per_stage>100.0 or authored.cdr_pct+3.0*tuning.cdr_per_stage>100.0:return _deny("g04_task_bounds")
 if not is_finite(authored.health_regen+3.0*tuning.regen_per_stage):return _deny("g04_regen_bounds")
 var stages: Array=[]
 if not numeric.get("task_stages") is Array:return _deny("g04_stages_missing")
 for row: Variant in numeric.task_stages:
  if row is Dictionary and row.get("equipment_id")==GoldTask.ITEM_ID:stages.append(row)
 if stages.size()!=3:return _deny("g04_exact_three_stages_required")
 for index: int in range(1,4):
  var id: String="task:G04:"+str(index)
  var row: Dictionary=SourceChecks._one(stages,"stage_id",id)
  if row.get("task_id")!=GoldTask.TASK_ID or row.get("stage")!=index or row.get("threshold_parameter_id")!="task:G04.stage"+str(index)+"_threshold" or row.get("reward_skill_points")!=0 or not SourceChecks._text(row.get("source_ref")):return _deny("g04_original_stage_required:"+id)
 var commerce: Dictionary=_commerce(numeric,source,item)
 if not commerce.get("accepted",false):return commerce
 var regen: Dictionary=RegenUnits.build(numeric)
 if not regen.get("accepted",false):return regen
 # Use the established exact /5 operation, not a new regen clock or rounded *0.2.
 stats.hp_regen=float(regen.parameters[GoldTask.ITEM_ID+".stat.health_regen"].runtime_value)
 var prior: Dictionary=Existing.build_from_source(numeric,source)
 if not prior.get("accepted",false):return prior
 var count: int=0
 for definition: Dictionary in prior.definitions.values():
  if definition.get("supported",false):count+=1
 if count!=49 or prior.definitions.has(GoldTask.ITEM_ID):return _deny("exact_49_prior_equipment_required")
 var out: Dictionary=prior.duplicate(true)
 out.definitions[GoldTask.ITEM_ID]={"supported":true,"reason":"","mechanism_prepared":true,"runtime_complete":false,"shop_admitted":false,"runtime_status":"inert_until_original_reward_receipt_successor_bound","name":item.name,"tier":"final","stats":stats,"parameters":refs,"passives":[],"actives":[],"taskG04":tuning,"taskG04_parameters":task_refs,"taskG04_source_stages":stages.duplicate(true),"source_rules":rules,"recipe":commerce.recipe,"commerce_parameters":commerce.parameters,"g04_authored_source_stats":authored,"regen_mapping":{"base":regen.parameters[GoldTask.ITEM_ID+".stat.health_regen"].duplicate(true),"stage":regen.parameters[GoldTask.TASK_ID+".regen_per_stage"].duplicate(true)},"taskG04_contract":{"scope":"player_equipment_name_run","held_only":true,"retained_when_sold":true,"retained_across_rooms":true,"maximum_stages":3,"duplicate_copies_multiply_progress":false,"reward_skill_points":0,"gold_source_policy":"original_committed_gameplay_reward_only","exclude":["sale_proceeds","undo_refunds","spending","initial_or_diagnostic_funding"],"source_policy_authority":"Sentinel_dc79a8a31b10819186c02bca14248806","base_stat_stacking":"evolve_each_base_before_original_per_uid_multipliers"},"requires_source_bridge":["same_original_session_owner_sim_model_run","actual_original_kill_event","same_command_credited_rewards_event_amount","original_task_kernel_successor","atomic_wallet_progress_stages_receipts"]}
 count=0
 for definition: Dictionary in out.definitions.values():
  if definition.get("supported",false):count+=1
 if count!=50:return _deny("exact_50_equipment_required")
 return out

static func _commerce(numeric: Dictionary, source: Dictionary, item: Dictionary) -> Dictionary:
 var price: Variant=numeric.parameters.get(GoldTask.ITEM_ID+".price")
 if not SourceChecks._entry(price,"gold",2800.0) or not SourceChecks._integer(price.value):return _deny("g04_price_invalid")
 if not item.get("components") is Array or item.components.size()!=2 or not numeric.get("recipes") is Array:return _deny("g04_recipe_missing")
 var seen: Dictionary={}
 for row: Variant in item.components:
  if not row is Dictionary or not COMPONENTS.has(row.get("item_id")) or seen.has(row.item_id) or row.get("quantity")!=1:return _deny("g04_original_components_required")
  seen[row.item_id]=true
 var components: Array=[]
 var total: float=0.0
 var refs: Array=[SourceChecks._ref(GoldTask.ITEM_ID+".price",price,1.0)]
 seen.clear()
 for row: Variant in numeric.recipes:
  if not row is Dictionary:return _deny("g04_recipe_schema_invalid")
  if row.get("result_id")!=GoldTask.ITEM_ID:continue
  var id: Variant=row.get("component_id")
  if id not in COMPONENTS or seen.has(id) or row.get("recipe_id")!=GoldTask.ITEM_ID+"<-"+str(id) or row.get("quantity")!=1 or not SourceChecks._text(row.get("source_ref")):return _deny("g04_recipe_invalid")
  var entry: Variant=numeric.parameters.get(str(id)+".price")
  var original: Dictionary=SourceChecks._one(source.get("equipment"),"id",str(id))
  if original.get("source_price")!=COMPONENTS[id] or not SourceChecks._entry(entry,"gold",float(COMPONENTS[id])) or not SourceChecks._integer(entry.value):return _deny("g04_component_price_invalid")
  seen[id]=true;total+=float(entry.value)
  components.append({"item_id":id,"quantity":1,"price":int(entry.value),"source_ref":row.source_ref});refs.append(SourceChecks._ref(str(id)+".price",entry,1.0))
 if seen.size()!=2 or total>float(price.value):return _deny("g04_exact_recipe_required")
 var derived: Dictionary=SourceChecks._one(numeric.get("derived_combine_fees"),"item_id",GoldTask.ITEM_ID)
 if derived.get("unit")!="gold" or derived.get("current_total_price")!=price.value or derived.get("current_component_total")!=total or derived.get("combine_fee")!=float(price.value)-total:return _deny("g04_derived_recipe_mismatch")
 return {"accepted":true,"parameters":refs,"recipe":{"components":components,"full_price":int(price.value),"component_total":int(total),"combine_fee":int(float(price.value)-total),"unit":"gold"}}
static func _deny(reason: String)->Dictionary:return {"accepted":false,"reason":reason,"prepared_only":true,"runtime_complete":false,"shop_admitted":false}
