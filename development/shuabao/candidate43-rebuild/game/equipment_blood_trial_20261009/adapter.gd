extends RefCounted
const Prior = preload("res://equipment_lifeline_20261009/adapter.gd")
const Task03 = preload("task03.gd")
const SOURCE := "res://docs/equipment_source_20261004/correction_0959/equipment_system_extracted.json"
const SPECS := [["AD","attack_points","AD",1.0,40.0],["max_health","health_points","max_hp",1.0,350.0],["lifesteal_pct","percent_points","lifesteal",0.01,6.0]]
const TASK_VALUES := {"threshold":[500.0,"multiple"],"health_threshold":[35.0,"percent_points"]}
const COMPONENTS := {"intermediate:I06":1200,"intermediate:I07":1100}
const RULES := {
 "paragraph:010":"装备任务按“玩家+装备名称”记录；同一任务本局只能按规则完成一次或规定阶段数。出售后已完成阶段、任务进度、永久奖励与进化状态均保留。",
 "paragraph:057":"生命值低于35%最大生命期间造成的有效伤害计入任务。每次有效伤害按“本次有效伤害 ÷ 造成伤害时自身最大生命值”折算任务比例，累计达到500倍自身最大生命值（即50000%）后完成。生命恢复至35%及以上时进度不清零，只暂停累计。完成后永久获得1技能点。本任务只能完成1次。",
 "paragraph:064":"任务规则补充：任务进度仅在装备持有期间继续累计；出售后进度与已完成阶段冻结并永久保留，重新购买后继续。所有“永久技能点”均只对当前远征生效，并受本局技能点总上限约束。"
}

static func build(numeric: Dictionary) -> Dictionary:
 var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
 if not source is Dictionary: return _deny("g03_source_missing")
 return build_from_source(numeric,source)

static func build_from_source(numeric: Dictionary, source: Dictionary) -> Dictionary:
 if not numeric.get("parameters") is Dictionary: return _deny("numeric_parameters_missing")
 var item: Dictionary = _one(source.get("equipment"),"id",Task03.ITEM_ID)
 var task_source: Dictionary = _one(source.get("tasks"),"equipment_id",Task03.ITEM_ID)
 if item.get("name") != "战狂护腕" or item.get("tier") != "final" or item.get("mechanism_ids") != [] or item.get("source_price") != 2800 or item.get("source_component_total") != 2300 or item.get("source_combine_fee") != 500: return _deny("g03_original_item_required")
 if not _source_stats(item.get("source_attributes_parsed")): return _deny("g03_original_stats_required")
 var catalog: Dictionary = _one(numeric.get("catalog"),"owner_id",Task03.ITEM_ID)
 if catalog.get("name") != item.name or catalog.get("kind") != "final" or catalog.get("source_code") != item.source_code or catalog.get("mechanism_ids") != "" or catalog.get("source_attributes") != item.source_attributes or catalog.get("source_effects") != item.source_effects or not _text(catalog.get("source_ref")): return _deny("g03_catalog_source_mismatch")
 if task_source.get("name") != "血战修业" or not _integer(task_source.get("stage_count")) or task_source.stage_count != 1 or task_source.get("source_task") != "G03战狂护腕｜血战修业" + RULES["paragraph:057"].replace(" ÷ ","÷"): return _deny("g03_original_task_required")
 var rules: Array = []
 for id: String in RULES:
  var rule: Dictionary = _one(numeric.get("source_rules"),"rule_id",id)
  if rule.get("source_text") != RULES[id] or not _text(rule.get("source_ref")): return _deny("g03_source_rule_required:" + id)
  rules.append(rule.duplicate(true))
 var stats: Dictionary = {}
 var references: Array = []
 for spec: Array in SPECS:
  var key: String = Task03.ITEM_ID + ".stat." + str(spec[0])
  var row: Variant = numeric.parameters.get(key)
  if not _entry(row,str(spec[1]),float(spec[4])) or (spec[1] == "percent_points" and float(row.value) > 100.0): return _deny("g03_invalid_stat:" + key)
  stats[str(spec[2])] = float(row.value)*float(spec[3])
  references.append(_ref(key,row,float(spec[3])))
 var tuning: Dictionary = {"stage_id":"task:G03:1","reward_skill_points":1}
 var task_references: Array = []
 var allowed: Array = []
 for field: String in TASK_VALUES:
  var key: String = Task03.TASK_ID + "." + field
  var row: Variant = numeric.parameters.get(key)
  if not _entry(row,str(TASK_VALUES[field][1]),float(TASK_VALUES[field][0])) or float(row.value) <= 0.0: return _deny("g03_invalid_task_parameter:" + key)
  tuning[field] = float(row.value)
  task_references.append(_ref(key,row,1.0));allowed.append(key)
 for key: Variant in numeric.parameters:
  if str(key).begins_with(Task03.TASK_ID + ".") and key not in allowed: return _deny("g03_unsupported_task_parameter:" + str(key))
 if not Task03.valid_tuning(tuning): return _deny("g03_task_bounds")
 var stage: Dictionary = _one(numeric.get("task_stages"),"equipment_id",Task03.ITEM_ID)
 if stage.get("stage_id") != "task:G03:1" or stage.get("task_id") != Task03.TASK_ID or not _integer(stage.get("stage")) or stage.stage != 1 or stage.get("threshold_parameter_id") != "task:G03.threshold" or not _integer(stage.get("reward_skill_points")) or stage.reward_skill_points != 1 or not _text(stage.get("source_ref")): return _deny("g03_original_stage_required")
 var commerce: Dictionary = _commerce(numeric,item)
 if not commerce.get("accepted",false): return commerce
 var prior: Dictionary = Prior.build_from_source(numeric,source)
 if not prior.get("accepted",false): return prior
 var count: int = 0
 for definition: Dictionary in prior.definitions.values():
  if definition.get("supported",false): count += 1
 if count != 41 or prior.definitions.has(Task03.ITEM_ID): return _deny("exact_41_prior_equipment_required")
 var out: Dictionary = prior.duplicate(true)
 out.definitions[Task03.ITEM_ID] = {"supported":true,"reason":"","mechanism_prepared":true,"runtime_complete":false,"shop_admitted":false,"runtime_status":"inert_until_original_damage_and_owner_snapshot_bound","name":"战狂护腕","tier":"final","stats":stats,"parameters":references,"passives":[],"actives":[],"taskG03":tuning,"taskG03_parameters":task_references,"taskG03_source_stage":stage.duplicate(true),"source_rules":rules,"commerce":commerce.projection,"commerce_parameters":commerce.parameters,"taskG03_contract":{"scope":"player_equipment_name_run","held_only":true,"retained_when_sold":true,"retained_across_rooms":true,"once_per_run":true,"duplicate_copies_multiply_progress":false,"reward_skill_points":1,"damage_scope":"all_original_target_ranks","ratio":"sum_actual_damage_divided_by_commit_max_hp","health_threshold_strict":true,"pause_when_healed":true},"requires_source_bridge":["original_holder_damage_frame","commit_owner_hp_and_max_hp","first_original_damage_emission","atomic_p1_nonlethal_and_lethal","same_bound_model_run","atomic_task_receipt_and_one_sp"]}
 count = 0
 for definition: Dictionary in out.definitions.values():
  if definition.get("supported",false): count += 1
 if count != 42: return _deny("exact_42_equipment_required")
 return out

static func _source_stats(rows: Variant) -> bool:
 if not rows is Array or rows.size() != SPECS.size(): return false
 for spec: Array in SPECS:
  var row: Dictionary = _one(rows,"stat",str(spec[0]))
  var unit: String = "percent_points" if spec[1] == "percent_points" else "flat"
  if not _number(row.get("value")) or float(row.value) != float(spec[4]) or row.get("unit") != unit: return false
 return true

static func _commerce(numeric: Dictionary, item: Dictionary) -> Dictionary:
 var price: Variant = numeric.parameters.get("final:G03.price")
 if not _entry(price,"gold",2800.0) or not _integer(price.value): return _deny("g03_price_invalid")
 if not item.get("components") is Array or item.components.size() != 2: return _deny("g03_source_recipe_missing")
 var found: Dictionary = {}
 for row: Variant in item.components:
  if not row is Dictionary or not COMPONENTS.has(row.get("item_id")) or found.has(row.item_id) or not _integer(row.get("quantity")) or row.quantity != 1: return _deny("g03_original_components_required")
  found[row.item_id] = true
 var recipes: Array = []
 found.clear()
 if not numeric.get("recipes") is Array: return _deny("g03_recipe_missing")
 for row: Variant in numeric.recipes:
  if not row is Dictionary: return _deny("invalid_recipe_row")
  if row.get("result_id") != Task03.ITEM_ID: continue
  var component: String = str(row.get("component_id",""))
  if not COMPONENTS.has(component) or found.has(component) or not _integer(row.get("quantity")) or row.quantity != 1 or row.get("recipe_id") != Task03.ITEM_ID + "<-" + component or not _text(row.get("source_ref")): return _deny("g03_recipe_invalid")
  found[component] = true;recipes.append(row.duplicate(true))
 if found.size() != 2: return _deny("g03_exact_recipe_required")
 var total: float = 0.0
 var refs: Array = [_ref("final:G03.price",price,1.0)]
 for component: String in COMPONENTS:
  var row: Variant = numeric.parameters.get(component + ".price")
  if not _entry(row,"gold",float(COMPONENTS[component])) or not _integer(row.value): return _deny("g03_component_price_invalid")
  total += float(row.value);refs.append(_ref(component + ".price",row,1.0))
 var fee: float = float(price.value)-total
 if not is_finite(fee) or fee < 0.0: return _deny("g03_combine_fee_invalid")
 var derived: Dictionary = _one(numeric.get("derived_combine_fees"),"item_id",Task03.ITEM_ID)
 if derived.get("unit") != "gold" or derived.get("current_total_price") != price.value or derived.get("current_component_total") != total or derived.get("combine_fee") != fee: return _deny("g03_derived_recipe_mismatch")
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
 return _number(v) and float(v) >= 0.0 and float(v) <= float(Task03.MAX_EXACT) and float(v) == floor(float(v))
static func _number(v: Variant) -> bool:
 return (v is int or v is float) and is_finite(float(v))
static func _text(v: Variant) -> bool:
 return v is String and not str(v).strip_edges().is_empty()
static func _ref(key: String, row: Dictionary, scale: float) -> Dictionary:
 return {"parameter":key,"source_ref":row.source_ref,"source_unit":row.unit,"current_value":row.value,"source_value":row.source_value,"scale":scale}
static func _deny(reason: String) -> Dictionary:
 return {"accepted":false,"reason":reason}
