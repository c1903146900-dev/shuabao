extends RefCounted
## Original E03 values and the established regen-unit projection; no new clock.
const Passive24 = preload("passive24.gd")
const Prior = preload("res://equipment_blood_trial_20261009/adapter.gd")
const RegenUnits = preload("res://tests/ink_equipment_regen_20261008/candidate01/regen_units.gd")
const SOURCE := "res://docs/equipment_source_20261004/correction_0959/equipment_system_extracted.json"
const ITEM_ID := "final:E03"
const COMPONENT_IDS := ["intermediate:I12", "intermediate:I05", "base:B06"]
const ORIGINAL_COMPONENT_PRICES := {"intermediate:I12":1050,"intermediate:I05":1200,"base:B06":450}
const ORIGINAL_STATS := {"max_health":420.0,"health_regen":8.0,"cdr_pct":15.0}
const STAT_SPECS := [["max_health", "health_points", "max_hp", 1.0], ["health_regen", "health_regen_source_units", "hp_regen", 0.2], ["cdr_pct", "percent_points", "cooldown_reduction", 0.01]]
const PASSIVE_SPECS := [["combat_time", "seconds"], ["regen_bonus", "percent_points"]]

static func build(numeric: Dictionary) -> Dictionary:
 var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
 if not source is Dictionary: return _deny("e03_original_source_missing")
 return build_from_source(numeric,source)

static func build_from_source(numeric: Dictionary, equipment_source: Dictionary) -> Dictionary:
 if not numeric.get("parameters") is Dictionary: return _deny("numeric_parameters_missing")
 var item: Dictionary = _one(equipment_source.get("equipment"), "id", ITEM_ID)
 var passive: Dictionary = _one(equipment_source.get("passives"), "id", Passive24.PASSIVE_ID)
 if item.get("name") != "再生装置" or item.get("tier") != "final" or item.get("mechanism_ids") != [Passive24.PASSIVE_ID]: return _deny("original_e03_required")
 if item.get("source_price") != 3100 or item.get("source_component_total") != 2700 or item.get("source_combine_fee") != 400: return _deny("exact_original_e03_prices_required")
 if not item.get("source_attributes_parsed") is Array or item.source_attributes_parsed.size() != STAT_SPECS.size(): return _deny("exact_original_e03_stats_required")
 var catalog: Dictionary = _one(numeric.get("catalog"), "owner_id", ITEM_ID)
 if catalog.get("name") != item.name or catalog.get("kind") != "final" or catalog.get("source_code") != item.get("source_code") or catalog.get("mechanism_ids") != Passive24.PASSIVE_ID or catalog.get("source_attributes") != item.get("source_attributes") or catalog.get("source_effects") != item.get("source_effects") or not _text(catalog.get("source_ref")): return _deny("numeric_catalog_source_mismatch")
 if passive.get("name") != "战斗再生": return _deny("original_passive24_required")
 var original_tuning: Dictionary = _parse_original_passive(passive.get("source_effect"))
 if original_tuning.is_empty(): return _deny("original_passive24_text_required")
 var mechanism: Dictionary = _one(numeric.get("mechanisms_original"), "owner_id", Passive24.PASSIVE_ID)
 if mechanism.get("source_text") != passive.source_effect or mechanism.get("name") != passive.name or not _text(mechanism.get("source_ref")): return _deny("mechanism_source_mismatch")
 if not _source_components_match(item.get("components")): return _deny("original_e03_components_required")
 var parameters: Dictionary = numeric.parameters
 var supported_keys: Array = [ITEM_ID + ".price"]
 for spec: Array in STAT_SPECS: supported_keys.append(ITEM_ID + ".stat." + str(spec[0]))
 for spec: Array in PASSIVE_SPECS: supported_keys.append(Passive24.PASSIVE_ID + "." + str(spec[0]))
 for key: Variant in parameters:
  if (str(key).begins_with(ITEM_ID + ".") or str(key).begins_with(Passive24.PASSIVE_ID + ".")) and key not in supported_keys: return _deny("unsupported_parameter:" + str(key))
 var tuning: Dictionary = {}
 var references: Array = []
 for spec: Array in PASSIVE_SPECS:
  var key: String = Passive24.PASSIVE_ID + "." + str(spec[0])
  var entry: Variant = parameters.get(key)
  if not _valid_entry(entry, str(spec[1])) or float(entry.source_value) != float(original_tuning[spec[0]]): return _deny("invalid_passive24_parameter:" + key)
  tuning[spec[0]] = float(entry.value)
  references.append(_reference(key, entry, 1.0))
 if not Passive24.valid_tuning(tuning): return _deny("invalid_passive24_bounds")
 var stats: Dictionary = {}
 for spec: Array in STAT_SPECS:
  var key: String = ITEM_ID + ".stat." + str(spec[0])
  var entry: Variant = parameters.get(key)
  var original: Dictionary = _one(item.get("source_attributes_parsed"), "stat", str(spec[0]))
  if original.get("value") != ORIGINAL_STATS[str(spec[0])]: return _deny("exact_original_e03_stat_required:" + str(spec[0]))
  var expected_source_unit: String = "percent_points" if spec[1] == "percent_points" else "flat"
  if not _valid_entry(entry, str(spec[1])) or original.get("unit") != expected_source_unit or not _number(original.get("value")) or float(entry.source_value) != float(original.value): return _deny("invalid_e03_stat:" + key)
  if spec[1] == "percent_points" and float(entry.value) > 100.0: return _deny("invalid_e03_stat_bounds:" + key)
  stats[spec[2]] = float(entry.value) * float(spec[3])
  references.append(_reference(key, entry, float(spec[3])))
 var price: Variant = parameters.get(ITEM_ID + ".price")
 if not _valid_gold(price) or not _whole(item.get("source_price")) or float(price.source_value) != float(item.source_price): return _deny("invalid_e03_price")
 var recipe: Dictionary = _recipe(numeric, equipment_source, item)
 if recipe.is_empty(): return _deny("exact_e03_recipe_required")
 references.append(_reference(ITEM_ID + ".price", price, 1.0))
 var regen: Dictionary = RegenUnits.build(numeric)
 if not regen.get("accepted",false): return regen
 var mapping: Dictionary = regen.parameters[ITEM_ID + ".stat.health_regen"]
 # Use the existing /5 consumer's exact arithmetic, not a separately rounded
 # multiplication by0.2 when an editable source value is fractional.
 stats.hp_regen = float(mapping.runtime_value)
 var unique: Dictionary = _one(numeric.get("source_rules"),"rule_id","paragraph:005")
 if unique.get("source_text") != "装备可以重复购买，但同名被动无论来源于多少件装备，只生效1次；同名主动同样只能生效1次。若同名效果存在不同强度版本，优先生效层级更高的版本；同层级取数值更高者。": return _deny("e03_original_unique_rule_required")
 var prior: Dictionary = Prior.build_from_source(numeric,equipment_source)
 if not prior.get("accepted",false): return prior
 var count: int = 0
 for prior_item: Dictionary in prior.definitions.values():
  if prior_item.get("supported",false): count += 1
 if count != 42 or prior.definitions.has(ITEM_ID): return _deny("exact_42_prior_equipment_required")
 var out: Dictionary = prior.duplicate(true)
 out.definitions[ITEM_ID] = {"supported":true,"reason":"","mechanism_prepared":true,"runtime_complete":false,"shop_admitted":false,"runtime_status":"inert_until_original_combat_regen_clock_bound",
  "name":item.name,"tier":"final","stats":stats,"passives":[Passive24.PASSIVE_ID],"actives":[],"passive24":tuning,"regen_mapping":mapping.duplicate(true),
  "parameters":references,"recipe":recipe,"original_source":item.duplicate(true),"original_passive":passive.duplicate(true),"source_rules":[unique.duplicate(true)],
  "base_stat_stacking":"per_legal_copy","passive_stacking":"one_same_name_effect",
  "lifecycle":{"continuous_combat_start":"original_common_actor_time","same_combat_generation_resets":false,"combat_end":"immediate_inactive","held_only":true,"independent_retained_buff":false},
  "requires_source_bridge":["original_bound_common_clock","continuous_combat_start","single_original_regeneration_heal","threshold_interval_projection"]}
 count = 0
 for definition: Dictionary in out.definitions.values():
  if definition.get("supported",false): count += 1
 if count != 43: return _deny("exact_43_equipment_required")
 return out

static func _parse_original_passive(text: Variant) -> Dictionary:
 if text != "持续处于战斗状态6秒后，基础生命恢复效果提高100%。战斗结束立即失效。": return {}
 return {"combat_time":6.0,"regen_bonus":100.0}

static func _recipe(numeric: Dictionary, source: Dictionary, item: Dictionary) -> Dictionary:
 if not numeric.get("recipes") is Array: return {}
 var seen: Dictionary = {}
 var components: Array = []
 var total: float = 0.0
 var original_total: float = 0.0
 for row: Variant in numeric.recipes:
  if not row is Dictionary: return {}
  if row.get("result_id") != ITEM_ID: continue
  var id: Variant = row.get("component_id")
  if id not in COMPONENT_IDS or seen.has(id) or not _whole(row.get("quantity")) or float(row.quantity) != 1.0 or not _text(row.get("source_ref")): return {}
  if row.get("recipe_id") != ITEM_ID + "<-" + str(id): return {}
  var entry: Variant = numeric.parameters.get(str(id) + ".price")
  var original: Dictionary = _one(source.get("equipment"), "id", id)
  if original.get("source_price") != ORIGINAL_COMPONENT_PRICES[str(id)]: return {}
  if not _valid_gold(entry) or not _whole(original.get("source_price")) or float(entry.source_value) != float(original.source_price): return {}
  seen[id] = true
  total += float(entry.value)
  original_total += float(original.source_price)
  components.append({"item_id":id, "quantity":int(row.quantity), "price":int(entry.value), "source_ref":row.source_ref})
 if seen.size() != COMPONENT_IDS.size(): return {}
 var price: float = float(numeric.parameters[ITEM_ID + ".price"].value)
 if total > price or not _whole(item.get("source_component_total")) or not _whole(item.get("source_combine_fee")): return {}
 if original_total != float(item.source_component_total) or float(item.source_price) - original_total != float(item.source_combine_fee): return {}
 var derived: Dictionary = _one(numeric.get("derived_combine_fees"), "item_id", ITEM_ID)
 if derived.get("unit") != "gold": return {}
 for key: String in ["current_total_price", "current_component_total", "combine_fee"]:
  if not _whole(derived.get(key)): return {}
 if float(derived.current_total_price) != price or float(derived.current_component_total) != total or float(derived.combine_fee) != price - total: return {}
 return {"components":components, "full_price":int(price), "component_total":int(total), "combine_fee":int(price - total), "unit":"gold"}

static func _source_components_match(entries: Variant) -> bool:
 if not entries is Array or entries.size() != COMPONENT_IDS.size(): return false
 var seen: Dictionary = {}
 for row: Variant in entries:
  if not row is Dictionary or row.get("item_id") not in COMPONENT_IDS or seen.has(row.item_id) or not _whole(row.get("quantity")) or float(row.quantity) != 1.0: return false
  seen[row.item_id] = true
 return seen.size() == COMPONENT_IDS.size()

static func _one(entries: Variant, field: String, id: String) -> Dictionary:
 if not entries is Array: return {}
 var found: Dictionary = {}
 for row: Variant in entries:
  if row is Dictionary and row.get(field) == id:
   if not found.is_empty(): return {}
   found = row
 return found

static func _valid_entry(entry: Variant, unit: String) -> bool:
 return entry is Dictionary and entry.get("unit") == unit and _number(entry.get("value")) and float(entry.value) >= 0.0 and _number(entry.get("source_value")) and float(entry.source_value) >= 0.0 and _text(entry.get("source_ref"))

static func _valid_gold(entry: Variant) -> bool:
 return _valid_entry(entry, "gold") and _whole(entry.value) and _whole(entry.source_value)

static func _whole(value: Variant) -> bool:
 return _number(value) and float(value) >= 0.0 and float(value) <= 9007199254740991.0 and float(value) == floor(float(value))

static func _number(value: Variant) -> bool:
 return (value is int or value is float) and is_finite(float(value))

static func _text(value: Variant) -> bool:
 return value is String and not str(value).strip_edges().is_empty()

static func _reference(key: String, entry: Dictionary, scale: float) -> Dictionary:
 return {"parameter":key, "source_ref":entry.source_ref, "source_unit":entry.unit, "current_value":entry.value, "source_value":entry.source_value, "scale":scale}

static func _deny(reason: String) -> Dictionary:
 return {"accepted":false, "reason":reason, "prepared_only":true, "runtime_complete":false, "shop_admitted":false}
