extends RefCounted
## Formal source definitions only. The prototype and old catalogs remain frozen.
const SOURCE := "res://docs/equipment_source_20261004/correction_0959/equipment_system_extracted.json"
const RegenUnits = preload("res://tests/ink_equipment_regen_20261008/candidate01/regen_units.gd")
const SPECS := [
 ["training:01","攻击锻体","AD",8.0,"attack_points","AD",1.0,"攻击力"],
 ["training:02","秘法锻体","AP",14.0,"ability_points","AP",1.0,"法术强度"],
 ["training:03","极速锻体","attack_speed_pct",8.0,"percent_points","attack_speed",0.01,"攻击速度"],
 ["training:04","锐眼锻体","crit_chance_pct",5.0,"percent_points","crit_chance",0.01,"暴击率"],
 ["training:05","冷凝锻体","cdr_pct",4.0,"percent_points","cooldown_reduction",0.01,"冷却缩减"],
 ["training:06","生命锻体","max_health",90.0,"health_points","max_hp",1.0,"最大生命"],
 ["training:07","装甲锻体","defense",7.0,"defense_points","defense",1.0,"防御力"],
 ["training:08","疾行锻体","move_speed_pct",3.0,"percent_points","move_speed",0.01,"移动速度"],
 ["training:09","血疗锻体","lifesteal_pct",2.0,"percent_points","lifesteal",0.01,"吸血"],
 ["training:10","定心锻体","tenacity_pct",6.0,"percent_points","tenacity",0.01,"韧性"],
 ["training:11","破甲锻体","penetration",5.0,"penetration_points","penetration",1.0,"穿甲"],
 ["training:12","再生锻体","health_regen",1.5,"health_regen_source_units","hp_regen",0.2,"基础生命恢复"]
]

static func build(numeric: Dictionary) -> Dictionary:
 var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
 if not source is Dictionary: return _deny("training_original_source_missing")
 return build_from_source(numeric,source)

static func build_from_source(numeric: Dictionary, source: Dictionary) -> Dictionary:
 if not numeric.get("parameters") is Dictionary: return _deny("numeric_parameters_missing")
 if not source.get("training_options") is Array or source.training_options.size() != 12: return _deny("exact_original_training12_required")
 var parameters: Dictionary = numeric.parameters
 var price: Variant = parameters.get("training:global.price")
 if not _entry(price,"gold",900.0) or float(price.value) != 900.0: return _deny("fixed_training_900_required")
 var allowed: Array = ["training:global.price"]
 for spec: Array in SPECS: allowed.append(str(spec[0])+".value")
 for key: Variant in parameters:
  if str(key).begins_with("training:") and key not in allowed: return _deny("unsupported_training_parameter:"+str(key))
 var rule: Dictionary = _one(numeric.get("source_rules"),"rule_id","paragraph:072")
 if rule.get("source_text") != "锻体为商店中的即时成长项目，不占装备格或药品栏。每次锻体固定价格900金币，价格永不递增，购买次数没有上限。每次随机展示3个不同的纯属性选项，选择1个永久获得；达到属性硬上限后不再出现无效选项。": return _deny("original_training_rule_required")
 var regen: Dictionary = RegenUnits.build(numeric)
 if not regen.get("accepted",false): return regen
 var outcomes: Dictionary = {}
 for spec: Array in SPECS:
  var id: String = str(spec[0])
  var original: Dictionary = _one(source.training_options,"id",id)
  if original.get("name") != spec[1] or original.get("stat") != spec[2] or original.get("source_value") != spec[3] or original.get("source_price") != 900: return _deny("exact_original_training_required:"+id)
  var catalog: Dictionary = _one(numeric.get("catalog"),"owner_id",id)
  if catalog.get("name") != original.name or catalog.get("kind") != "training" or catalog.get("mechanism_ids") != "" or not _text(catalog.get("source_ref")): return _deny("training_catalog_source_mismatch:"+id)
  var entry: Variant = parameters.get(id+".value")
  if not _entry(entry,str(spec[4]),float(spec[3])): return _deny("invalid_training_value:"+id)
  if entry.unit == "percent_points" and float(entry.value)>100.0: return _deny("invalid_training_fraction:"+id)
  var amount: float = float(entry.value)*float(spec[6])
  if id == "training:12": amount = float(regen.parameters[id+".value"].runtime_value)
  var label: String = "%s +%s%s" % [str(spec[7]),str(entry.value),"%" if entry.unit == "percent_points" else ""]
  if id == "training:12": label = RegenUnits.label(float(entry.value))
  var outcome: Dictionary = _metadata(str(original.name),str(entry.source_ref))
  outcome.merge({"id":id,"formal_training":true,"stats":{str(spec[5]):amount},"weight":100,"required_hooks":["stats.v1","stat."+str(spec[5])+".v1"],
   "label":label,"source_stat":original.stat,"source_value":entry.source_value,"current_value":entry.value,"source_unit":entry.unit,
   "runtime_stat":str(spec[5]),"runtime_value":amount,"original_source":original.duplicate(true),"parameter":id+".value"},true)
  if id == "training:12": outcome["regen_mapping"] = regen.parameters[id+".value"].duplicate(true)
  outcomes[id] = outcome
 var body: Dictionary = _metadata("锻体·三选一",str(price.source_ref))
 body.merge({"mode":"choose_three","cost":900,"required_hooks":["stats.v1"],"outcomes":outcomes,"formal_training_pool":true,
  "purchase_count_cap":null,"equipment_slots_used":0,"potion_slots_used":0,"source_rule":rule.duplicate(true),"free_credit_authority":"not_connected"},true)
 return {"accepted":true,"reason":"","body":body}

static func _metadata(name: String, source_ref: String) -> Dictionary:
 return {"name":name,"status":"source_final","provenance":"equipment_source_20261004_formal_training12","source_ref":source_ref,
  "design_notice":"正式12项来源；等权沿用原抽取实现；恢复沿用每5秒单位映射","unresolved":[],"release_ready":false}

static func _entry(value: Variant, unit: String, source_value: float) -> bool:
 return value is Dictionary and value.get("unit") == unit and _positive(value.get("value")) and _positive(value.get("source_value")) and float(value.source_value) == source_value and _text(value.get("source_ref"))

static func _positive(value: Variant) -> bool:
 return (value is int or value is float) and is_finite(float(value)) and float(value)>0.0

static func _text(value: Variant) -> bool:
 return value is String and not str(value).strip_edges().is_empty()

static func _one(rows: Variant, key: String, id: String) -> Dictionary:
 if not rows is Array: return {}
 var found: Dictionary = {}
 for row: Variant in rows:
  if row is Dictionary and row.get(key) == id:
   if not found.is_empty(): return {}
   found = row
 return found

static func _deny(reason: String) -> Dictionary:
 return {"accepted":false,"reason":reason}
