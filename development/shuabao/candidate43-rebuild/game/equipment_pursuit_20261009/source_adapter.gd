extends RefCounted
## Source-only preparation. This result cannot admit B02 to a runtime catalog.
const Passive28 = preload("passive28.gd")
const ITEM_ID := "final:B02"
const COMPONENT_IDS := ["intermediate:I04", "intermediate:I18"]
const STAT_SPECS := [["AD", "attack_points", "AD", 1.0], ["penetration", "penetration_points", "penetration", 1.0], ["move_speed_pct", "percent_points", "move_speed", 0.01]]
const PASSIVE_SPECS := [["move_bonus", "percent_points"], ["attack_speed_bonus", "percent_points"], ["duration", "seconds"]]

static func build(numeric: Dictionary, equipment_source: Dictionary) -> Dictionary:
 if not numeric.get("parameters") is Dictionary: return _deny("numeric_parameters_missing")
 var item: Dictionary = _one(equipment_source.get("equipment"), "id", ITEM_ID)
 var passive: Dictionary = _one(equipment_source.get("passives"), "id", Passive28.PASSIVE_ID)
 if item.get("name") != "追猎长刃" or item.get("tier") != "final" or item.get("mechanism_ids") != [Passive28.PASSIVE_ID]: return _deny("original_b02_required")
 if not item.get("source_attributes_parsed") is Array or item.source_attributes_parsed.size() != STAT_SPECS.size(): return _deny("exact_original_b02_stats_required")
 var catalog: Dictionary = _one(numeric.get("catalog"), "owner_id", ITEM_ID)
 if catalog.get("name") != item.name or catalog.get("kind") != "final" or catalog.get("source_code") != item.get("source_code") or catalog.get("mechanism_ids") != Passive28.PASSIVE_ID or catalog.get("source_attributes") != item.get("source_attributes") or catalog.get("source_effects") != item.get("source_effects") or not _text(catalog.get("source_ref")): return _deny("numeric_catalog_source_mismatch")
 if passive.get("name") != "猎杀余势": return _deny("original_passive28_required")
 var original_tuning: Dictionary = _parse_original_passive(passive.get("source_effect"))
 if original_tuning.is_empty(): return _deny("original_passive28_text_required")
 var mechanism: Dictionary = _one(numeric.get("mechanisms_original"), "owner_id", Passive28.PASSIVE_ID)
 if mechanism.get("source_text") != passive.source_effect or mechanism.get("name") != passive.name or not _text(mechanism.get("source_ref")): return _deny("mechanism_source_mismatch")
 if not _source_components_match(item.get("components")): return _deny("original_b02_components_required")
 var parameters: Dictionary = numeric.parameters
 var supported_keys: Array = [ITEM_ID + ".price"]
 for spec: Array in STAT_SPECS: supported_keys.append(ITEM_ID + ".stat." + str(spec[0]))
 for spec: Array in PASSIVE_SPECS: supported_keys.append(Passive28.PASSIVE_ID + "." + str(spec[0]))
 for key: Variant in parameters:
  if (str(key).begins_with(ITEM_ID + ".") or str(key).begins_with(Passive28.PASSIVE_ID + ".")) and key not in supported_keys: return _deny("unsupported_parameter:" + str(key))
 var tuning: Dictionary = {}
 var references: Array = []
 for spec: Array in PASSIVE_SPECS:
  var key: String = Passive28.PASSIVE_ID + "." + str(spec[0])
  var entry: Variant = parameters.get(key)
  if not _valid_entry(entry, str(spec[1])) or float(entry.source_value) != float(original_tuning[spec[0]]): return _deny("invalid_passive28_parameter:" + key)
  tuning[spec[0]] = float(entry.value)
  references.append(_reference(key, entry, 1.0))
 if not Passive28.valid_tuning(tuning): return _deny("invalid_passive28_bounds")
 var stats: Dictionary = {}
 for spec: Array in STAT_SPECS:
  var key: String = ITEM_ID + ".stat." + str(spec[0])
  var entry: Variant = parameters.get(key)
  var original: Dictionary = _one(item.get("source_attributes_parsed"), "stat", str(spec[0]))
  var expected_source_unit: String = "percent_points" if spec[1] == "percent_points" else "flat"
  if not _valid_entry(entry, str(spec[1])) or original.get("unit") != expected_source_unit or not _number(original.get("value")) or float(entry.source_value) != float(original.value): return _deny("invalid_b02_stat:" + key)
  if spec[1] == "percent_points" and float(entry.value) > 100.0: return _deny("invalid_b02_stat_bounds:" + key)
  stats[spec[2]] = float(entry.value) * float(spec[3])
  references.append(_reference(key, entry, float(spec[3])))
 var price: Variant = parameters.get(ITEM_ID + ".price")
 if not _valid_gold(price) or not _whole(item.get("source_price")) or float(price.source_value) != float(item.source_price): return _deny("invalid_b02_price")
 var recipe: Dictionary = _recipe(numeric, equipment_source, item)
 if recipe.is_empty(): return _deny("exact_b02_recipe_required")
 references.append(_reference(ITEM_ID + ".price", price, 1.0))
 var definition: Dictionary = {"supported":false, "mechanism_prepared":true, "prepared_only":true, "runtime_complete":false, "shop_admitted":false,
  "name":item.name, "tier":"final", "stats":stats, "passives":[Passive28.PASSIVE_ID], "actives":[], "passive28":tuning,
  "parameters":references, "recipe":recipe, "original_source":item.duplicate(true), "original_passive":passive.duplicate(true),
  "base_stat_stacking":"per_legal_copy", "passive_stacking":"one_same_name_effect",
  "unresolved_lifecycle":["last_copy_sale_existing_buff", "rebuy_or_undo_after_sale", "room_transition_expiry", "death_projection_and_cleanup"],
  "requires_source_bridge":["authenticated_original_death_commit", "original_owner_clock", "atomic_claim_and_buff_commit", "real_stat_projection"]}
 return {"accepted":true, "reason":"prepared_only", "prepared_only":true, "runtime_complete":false, "shop_admitted":false, "prepared_definitions":{ITEM_ID:definition}}

static func _parse_original_passive(text: Variant) -> Dictionary:
 if not _text(text): return {}
 var regex: RegEx = RegEx.new()
 if regex.compile("^参与击杀后获得([0-9]+(?:\\.[0-9]+)?)%移动速度与([0-9]+(?:\\.[0-9]+)?)%攻击速度，持续([0-9]+(?:\\.[0-9]+)?)秒；再次参与击杀刷新时间。$") != OK: return {}
 var matched: RegExMatch = regex.search(text)
 if matched == null: return {}
 return {"move_bonus":float(matched.get_string(1)), "attack_speed_bonus":float(matched.get_string(2)), "duration":float(matched.get_string(3))}

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
