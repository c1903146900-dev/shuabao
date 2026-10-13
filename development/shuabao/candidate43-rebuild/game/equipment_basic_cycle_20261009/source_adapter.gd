extends RefCounted
## Preparation only. No Prior adapter, runtime binding, catalog or shop admission.
const Passive08 = preload("passive08.gd")
const ITEM_ID := "final:B04"
const COMPONENT_IDS := ["intermediate:I13", "intermediate:I11"]
const STAT_SPECS := [["AD", "attack_points", "AD", 1.0], ["cdr_pct", "percent_points", "cooldown_reduction", 0.01], ["crit_chance_pct", "percent_points", "crit_chance", 0.01]]

static func build(numeric: Dictionary, equipment_source: Dictionary) -> Dictionary:
 if not numeric.get("parameters") is Dictionary: return _deny("numeric_parameters_missing")
 var item: Dictionary = _one(equipment_source.get("equipment"), "id", ITEM_ID)
 var passive: Dictionary = _one(equipment_source.get("passives"), "id", Passive08.PASSIVE_ID)
 var component: Dictionary = _one(equipment_source.get("equipment"), "id", "intermediate:I13")
 if item.get("name") != "战术裂片" or item.get("tier") != "final" or item.get("mechanism_ids") != [Passive08.PASSIVE_ID]: return _deny("original_b04_definition_required")
 if passive.get("name") != "战技循环" or passive.get("source_effect") != "每完成5次普通攻击，使Q、E当前剩余冷却分别减少10%。": return _deny("original_passive08_required")
 if component.get("name") != "战术芯片" or component.get("mechanism_ids") != []: return _deny("i13_must_remain_attribute_only")
 if not _source_components_match(item.get("components")): return _deny("original_b04_components_required")
 var parameters: Dictionary = numeric.parameters
 var interval_key: String = Passive08.PASSIVE_ID + ".attack_interval"
 var reduction_key: String = Passive08.PASSIVE_ID + ".remaining_cooldown_reduction"
 for key: Variant in parameters:
  if str(key).begins_with(Passive08.PASSIVE_ID + ".") and key not in [interval_key, reduction_key]: return _deny("unsupported_passive08_parameter:" + str(key))
 var interval: Variant = parameters.get(interval_key)
 var reduction: Variant = parameters.get(reduction_key)
 if not _valid_entry(interval, "count") or not _whole(interval.value) or float(interval.value) <= 0.0: return _deny("invalid_attack_interval")
 if not _valid_entry(reduction, "percent_points"): return _deny("invalid_reduction_unit_or_value")
 var tuning: Dictionary = {"attack_interval":int(interval.value), "remaining_cooldown_reduction":float(reduction.value)}
 if not Passive08.valid_tuning(tuning): return _deny("invalid_passive08_bounds")
 if float(interval.source_value) != 5.0 or float(reduction.source_value) != 10.0: return _deny("original_passive08_source_values_required")
 var stats: Dictionary = {}
 var references: Array = []
 for spec: Array in STAT_SPECS:
  var key: String = ITEM_ID + ".stat." + str(spec[0])
  var entry: Variant = parameters.get(key)
  if not _valid_entry(entry, str(spec[1])): return _deny("invalid_b04_stat:" + key)
  if spec[1] == "percent_points" and float(entry.value) > 100.0: return _deny("invalid_b04_stat_bounds:" + key)
  stats[str(spec[2])] = float(entry.value) * float(spec[3])
  references.append(_reference(key, entry, float(spec[3])))
 var price: Variant = parameters.get(ITEM_ID + ".price")
 if not _valid_gold(price): return _deny("invalid_b04_price")
 var recipe: Dictionary = _recipe(numeric, item)
 if recipe.is_empty(): return _deny("exact_b04_recipe_required")
 var definition: Dictionary = {
  "supported":false, "reason":"prepared_only_source_bridge_and_lifecycle_unresolved",
  "mechanism_prepared":true, "runtime_complete":false, "shop_admitted":false,
  "name":str(item.name), "tier":"final", "stats":stats, "parameters":references,
  "passives":[Passive08.PASSIVE_ID], "actives":[], "passive08":tuning,
  "passive08_parameters":[_reference(interval_key, interval, 1.0), _reference(reduction_key, reduction, 1.0)],
  "commerce_parameters":[_reference(ITEM_ID + ".price", price, 1.0)],
  "recipe":recipe, "original_source":item.duplicate(true),
  "requires_source_bridge":["real_ink_basic_finished_terminal_witness", "current_scope_once_per_original_cast", "atomic_count_claim_and_qe_cooldowns"],
  "unresolved_lifecycle":["partial_count_across_rooms", "partial_count_after_last_copy_sale"]
 }
 # Deliberately no `definitions` result: cannot be mistaken for shop admission.
 return {"accepted":true, "reason":"prepared_only", "runtime_complete":false, "shop_admitted":false, "prepared_definitions":{ITEM_ID:definition}}

static func _recipe(numeric: Dictionary, source: Dictionary) -> Dictionary:
 if not numeric.get("recipes") is Array: return {}
 var seen: Dictionary = {}
 var components: Array = []
 var component_total: float = 0.0
 for row: Variant in numeric.recipes:
  if not row is Dictionary: return {}
  if row.get("result_id") != ITEM_ID: continue
  var id: Variant = row.get("component_id")
  if id not in COMPONENT_IDS or seen.has(id) or not _whole(row.get("quantity")) or float(row.quantity) != 1.0 or not _text(row.get("source_ref")): return {}
  if row.get("recipe_id") != ITEM_ID + "<-" + str(id): return {}
  var price: Variant = numeric.parameters.get(str(id) + ".price")
  if not _valid_gold(price): return {}
  seen[id] = true
  component_total += float(price.value)
  components.append({"item_id":id, "quantity":1, "price":int(price.value), "source_ref":row.source_ref})
 if seen.size() != 2: return {}
 var full_price: float = float(numeric.parameters[ITEM_ID + ".price"].value)
 if component_total > full_price: return {}
 var combine: float = full_price - component_total
 if not _whole(source.get("source_price")) or not _whole(source.get("source_component_total")) or not _whole(source.get("source_combine_fee")): return {}
 if float(source.source_price) != 3000.0 or float(source.source_component_total) != 2450.0 or float(source.source_combine_fee) != 550.0: return {}
 var derived: Dictionary = _one(numeric.get("derived_combine_fees"), "item_id", ITEM_ID)
 if derived.get("unit") != "gold" or not _whole(derived.get("current_total_price")) or not _whole(derived.get("current_component_total")) or not _whole(derived.get("combine_fee")): return {}
 if float(derived.current_total_price) != full_price or float(derived.current_component_total) != component_total or float(derived.combine_fee) != combine: return {}
 return {"components":components, "full_price":int(full_price), "component_total":int(component_total), "combine_fee":int(combine), "unit":"gold"}

static func _source_components_match(entries: Variant) -> bool:
 if not entries is Array or entries.size() != 2: return false
 var seen: Dictionary = {}
 for row: Variant in entries:
  if not row is Dictionary or row.get("item_id") not in COMPONENT_IDS or not _whole(row.get("quantity")) or float(row.quantity) != 1.0 or seen.has(row.item_id): return false
  seen[row.item_id] = true
 return seen.size() == 2

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
 return _valid_entry(entry, "gold") and _whole(entry.value)

static func _whole(value: Variant) -> bool:
 # JSON numbers may arrive as float; reject unsafe integer conversions.
 return _number(value) and float(value) >= 0.0 and float(value) <= 9007199254740991.0 and float(value) == floor(float(value))

static func _number(value: Variant) -> bool:
 return (value is int or value is float) and is_finite(float(value))

static func _text(value: Variant) -> bool:
 return value is String and not str(value).strip_edges().is_empty()

static func _reference(key: String, entry: Dictionary, scale: float) -> Dictionary:
 return {"parameter":key, "source_ref":entry.source_ref, "source_unit":entry.unit, "current_value":entry.value, "source_value":entry.source_value, "scale":scale}

static func _deny(reason: String) -> Dictionary:
 return {"accepted":false, "reason":reason, "runtime_complete":false, "shop_admitted":false}
