extends RefCounted
const Prior = preload("res://equipment_basic_cycle_20261009/adapter.gd")
const Task02 = preload("task02.gd")
const SOURCE := "res://docs/equipment_source_20261004/correction_0959/equipment_system_extracted.json"
const SPECS := [["AD","attack_points","AD",1.0,30.0],["AP","ability_points","AP",1.0,45.0],["max_health","health_points","max_hp",1.0,250.0],["cdr_pct","percent_points","cooldown_reduction",0.01,10.0]]
const TASK_VALUES := {"threshold":500,"normal_weight":1,"elite_weight":10,"boss_weight":25}
const COMPONENTS := {"intermediate:I13":1200,"intermediate:I17":1150}
const RULES := {
 "paragraph:010":"装备任务按“玩家+装备名称”记录；同一任务本局只能按规则完成一次或规定阶段数。出售后已完成阶段、任务进度、永久奖励与进化状态均保留。",
 "paragraph:055":"装备期间累计获得500个“普通敌人击杀当量”。参与击杀1名普通敌人计1；参与击杀1名精英计10；击败1名Boss计25。达到500后永久获得1技能点。本任务只能完成1次。",
 "paragraph:064":"任务规则补充：任务进度仅在装备持有期间继续累计；出售后进度与已完成阶段冻结并永久保留，重新购买后继续。所有“永久技能点”均只对当前远征生效，并受本局技能点总上限约束。"
}

static func build(numeric: Dictionary) -> Dictionary:
 var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
 if not source is Dictionary: return _deny("g02_source_missing")
 return build_from_source(numeric,source)

static func build_from_source(numeric: Dictionary, source: Dictionary) -> Dictionary:
 if not numeric.get("parameters") is Dictionary: return _deny("numeric_parameters_missing")
 var item: Dictionary = _one(source.get("equipment"),"id",Task02.ITEM_ID)
 var task_source: Dictionary = _one(source.get("tasks"),"equipment_id",Task02.ITEM_ID)
 if item.get("name") != "修业徽章" or item.get("tier") != "final" or item.get("mechanism_ids") != [] or item.get("source_price") != 2750 or item.get("source_component_total") != 2350 or item.get("source_combine_fee") != 400: return _deny("g02_original_item_required")
 if not _source_stats(item.get("source_attributes_parsed")): return _deny("g02_original_stats_required")
 if task_source.get("name") != "百战修业" or not _integer(task_source.get("stage_count")) or task_source.stage_count != 1 or task_source.get("source_task") != "G02修业徽章｜百战修业" + RULES["paragraph:055"]: return _deny("g02_original_task_required")
 var rules: Array = []
 for id: String in RULES:
  var rule: Dictionary = _one(numeric.get("source_rules"),"rule_id",id)
  if rule.get("source_text") != RULES[id] or not _text(rule.get("source_ref")): return _deny("g02_source_rule_required:" + id)
  rules.append(rule.duplicate(true))
 var stats: Dictionary = {}
 var references: Array = []
 for spec: Array in SPECS:
  var key: String = Task02.ITEM_ID + ".stat." + str(spec[0])
  var row: Variant = numeric.parameters.get(key)
  if not _entry(row,str(spec[1]),float(spec[4])) or (spec[1] == "percent_points" and float(row.value) > 100.0): return _deny("g02_invalid_stat:" + key)
  stats[str(spec[2])] = float(row.value)*float(spec[3])
  references.append(_ref(key,row,float(spec[3])))
 var tuning: Dictionary = {"stage_id":"task:G02:1","reward_skill_points":1}
 var task_references: Array = []
 var allowed: Array = []
 for field: String in TASK_VALUES:
  var key: String = Task02.TASK_ID + "." + field
  var row: Variant = numeric.parameters.get(key)
  if not _entry(row,"count",float(TASK_VALUES[field])) or not _integer(row.value) or float(row.value) <= 0.0: return _deny("g02_invalid_task_parameter:" + key)
  tuning[field] = int(row.value)
  task_references.append(_ref(key,row,1.0));allowed.append(key)
 for key: Variant in numeric.parameters:
  if str(key).begins_with(Task02.TASK_ID + ".") and key not in allowed: return _deny("g02_unsupported_task_parameter:" + str(key))
 if not Task02.valid_tuning(tuning): return _deny("g02_task_bounds")
 var stage: Dictionary = _one(numeric.get("task_stages"),"equipment_id",Task02.ITEM_ID)
 if stage.get("stage_id") != "task:G02:1" or stage.get("task_id") != Task02.TASK_ID or not _integer(stage.get("stage")) or stage.stage != 1 or stage.get("threshold_parameter_id") != "task:G02.threshold" or not _integer(stage.get("reward_skill_points")) or stage.reward_skill_points != 1 or not _text(stage.get("source_ref")): return _deny("g02_original_stage_required")
 var commerce: Dictionary = _commerce(numeric,item)
 if not commerce.get("accepted",false): return commerce
 var prior: Dictionary = Prior.build_from_source(numeric,source)
 if not prior.get("accepted",false): return prior
 var count: int = 0
 for definition: Dictionary in prior.definitions.values():
  if definition.get("supported",false): count += 1
 if count != 38 or prior.definitions.has(Task02.ITEM_ID): return _deny("exact_38_prior_equipment_required")
 var out: Dictionary = prior.duplicate(true)
 out.definitions[Task02.ITEM_ID] = {"supported":true,"reason":"","mechanism_prepared":true,"runtime_complete":false,"shop_admitted":false,"runtime_status":"inert_until_original_death_bridge_bound","name":"修业徽章","tier":"final","stats":stats,"parameters":references,"passives":[],"actives":[],"taskG02":tuning,"taskG02_parameters":task_references,"taskG02_source_stage":stage.duplicate(true),"source_rules":rules,"commerce":commerce.projection,"commerce_parameters":commerce.parameters,"taskG02_contract":{"scope":"player_equipment_name_run","held_only":true,"retained_when_sold":true,"retained_across_rooms":true,"once_per_run":true,"duplicate_copies_multiply_progress":false,"reward_skill_points":1,"participation_scope":"actual_solo_lethal_only","multiplayer_supported":false},"requires_source_bridge":["original_holder_death_frame","current_original_target_rank","first_original_kill_emission","same_bound_model_run","atomic_task_receipt_and_one_sp"]}
 count = 0
 for definition: Dictionary in out.definitions.values():
  if definition.get("supported",false): count += 1
 if count != 39: return _deny("exact_39_equipment_required")
 return out

static func _source_stats(rows: Variant) -> bool:
 if not rows is Array or rows.size() != SPECS.size(): return false
 for spec: Array in SPECS:
  var row: Dictionary = _one(rows,"stat",str(spec[0]))
  var unit: String = "percent_points" if spec[0] == "cdr_pct" else "flat"
  if not _number(row.get("value")) or float(row.value) != float(spec[4]) or row.get("unit") != unit: return false
 return true

static func _commerce(numeric: Dictionary, item: Dictionary) -> Dictionary:
 var price: Variant = numeric.parameters.get("final:G02.price")
 if not _entry(price,"gold",2750.0) or not _integer(price.value): return _deny("g02_price_invalid")
 if not item.get("components") is Array or item.components.size() != 2: return _deny("g02_source_recipe_missing")
 var found: Dictionary = {}
 for row: Variant in item.components:
  if not row is Dictionary or not COMPONENTS.has(row.get("item_id")) or found.has(row.item_id) or not _integer(row.get("quantity")) or row.quantity != 1: return _deny("g02_original_components_required")
  found[row.item_id] = true
 var recipes: Array = []
 found.clear()
 if not numeric.get("recipes") is Array: return _deny("g02_recipe_missing")
 for row: Variant in numeric.recipes:
  if not row is Dictionary: return _deny("invalid_recipe_row")
  if row.get("result_id") != Task02.ITEM_ID: continue
  var component: String = str(row.get("component_id",""))
  if not COMPONENTS.has(component) or found.has(component) or not _integer(row.get("quantity")) or row.quantity != 1 or row.get("recipe_id") != Task02.ITEM_ID + "<-" + component or not _text(row.get("source_ref")): return _deny("g02_recipe_invalid")
  found[component] = true;recipes.append(row.duplicate(true))
 if found.size() != 2: return _deny("g02_exact_recipe_required")
 var total: float = 0.0
 var refs: Array = [_ref("final:G02.price",price,1.0)]
 for component: String in COMPONENTS:
  var row: Variant = numeric.parameters.get(component + ".price")
  if not _entry(row,"gold",float(COMPONENTS[component])) or not _integer(row.value): return _deny("g02_component_price_invalid")
  total += float(row.value);refs.append(_ref(component + ".price",row,1.0))
 var fee: float = float(price.value)-total
 if not is_finite(fee) or fee < 0.0: return _deny("g02_combine_fee_invalid")
 var derived: Dictionary = _one(numeric.get("derived_combine_fees"),"item_id",Task02.ITEM_ID)
 if derived.get("unit") != "gold" or derived.get("current_total_price") != price.value or derived.get("current_component_total") != total or derived.get("combine_fee") != fee: return _deny("g02_derived_recipe_mismatch")
 return {"accepted":true,"parameters":refs,"projection":{"price":price.value,"component_total":total,"combine_fee":fee,"unit":"gold","recipe":recipes}}

static func _one(rows: Variant, field: String, id: String) -> Dictionary:
 if not rows is Array: return {}
 var found: Dictionary = {}
 for row: Variant in rows:
  if row is Dictionary and row.get(field) == id:
   if not found.is_empty(): return {}
   found = row
 return found
static func _entry(row: Variant, unit: String, original: float) -> bool:
 return row is Dictionary and row.get("unit") == unit and _number(row.get("value")) and float(row.value) >= 0.0 and _number(row.get("source_value")) and float(row.source_value) == original and _text(row.get("source_ref"))
static func _integer(v: Variant) -> bool:
 return _number(v) and float(v) >= 0.0 and float(v) <= float(Task02.MAX_EXACT) and float(v) == floor(float(v))
static func _number(v: Variant) -> bool:
 return (v is int or v is float) and is_finite(float(v))
static func _text(v: Variant) -> bool:
 return v is String and not str(v).strip_edges().is_empty()
static func _ref(key: String, row: Dictionary, scale: float) -> Dictionary:
 return {"parameter":key,"source_ref":row.source_ref,"source_unit":row.unit,"current_value":row.value,"source_value":row.source_value,"scale":scale}
static func _deny(reason: String) -> Dictionary:
 return {"accepted":false,"reason":reason}
