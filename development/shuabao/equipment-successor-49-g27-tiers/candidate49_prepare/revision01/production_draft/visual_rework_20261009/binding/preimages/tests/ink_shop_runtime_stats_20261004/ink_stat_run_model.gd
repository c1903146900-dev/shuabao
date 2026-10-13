extends "res://tests/ink_shop_ledger_bridge_20261004/fix01/ink_shop_run_model.gd"
## Same transaction authority; only equipment availability and derived effects are added.
var runtime_stat_definitions: Dictionary = {}
func bind_runtime_stats(definitions: Dictionary) -> Dictionary:
 if not runtime_stat_definitions.is_empty() or state.revision != 0 or commerce_definitions.is_empty(): return _deny("fresh_stat_binding_required")
 runtime_stat_definitions = definitions.duplicate(true)
 return {"accepted":true, "reason":""}
func equipment_runtime_status(id: String) -> Dictionary:
 if not commerce_definitions.items.has(id): return {"supported":false, "reason":"unknown_item"}
 if commerce_definitions.items[id].kind != "equipment": return {"supported":false, "reason":"consumable_effect_consumer_not_connected"}
 if not runtime_stat_definitions.has(id): return {"supported":false, "reason":"outside_base_equipment_slice"}
 return runtime_stat_definitions[id].duplicate(true)
func commerce_quote(item_id: String) -> Dictionary:
 var status: Dictionary = equipment_runtime_status(item_id)
 if not status.supported: return _deny("equipment_runtime_hold:" + item_id + ":" + str(status.reason))
 var result: Dictionary = super.commerce_quote(item_id)
 result["equipment_runtime"] = status
 return result
func _apply_commerce(envelope: Dictionary) -> String:
 # Refuse inert purchases before the frozen economic evaluator or any debit.
 # Other intents, reverse patches and dependency sealing are inherited unchanged.
 if str(envelope.get("operation", "")) in ["buy", "craft"]:
  var id: String = str(envelope.get("arguments", {}).get("item", ""))
  var status: Dictionary = equipment_runtime_status(id)
  if not status.supported: return "equipment_runtime_hold:" + id + ":" + str(status.reason)
 return super._apply_commerce(envelope)
func equipment_effects() -> Dictionary:
 if runtime_stat_definitions.is_empty(): return super.equipment_effects()
 var result: Dictionary = {"stats":{}, "passives":[], "actives":[], "status":"base_equipment_runtime_candidate", "holds":[]}
 for entry in state.inventory:
  var status: Dictionary = equipment_runtime_status(str(entry.id))
  if not status.supported:
   result.holds.append({"id":entry.id, "uid":entry.uid, "reason":status.reason})
   continue
  var item_stats: Dictionary = status.stats.duplicate(true)
  # Preserve the existing catalog order: per-UID G21, outer held component G27,
  # then sum plain stats by actual count. No passive is inferred from a stat name.
  var multiplier: float = 1.0 + float(state.get("g21_item_bonuses", {}).get(str(entry.uid), {}).get("base_fraction", 0.0))
  if _selected_hex_active("common_g27"): multiplier *= 1.0 + hex_parameter("common_g27", "G27-1") / 100.0
  for key in item_stats: item_stats[key] *= multiplier
  _add_stats(result.stats, item_stats, int(entry.count))
 return result
func snapshot() -> Dictionary:
 var out: Dictionary = super.snapshot()
 out["content_profile"] = "base_equipment_runtime_candidate"
 out["equipment_runtime"] = equipment_effects()
 out["content_warnings"] = [{"reason":"base_11_only_regen_consumables_intermediates_final_effects_hold"}]
 return out
func shop_catalog() -> Dictionary:
 var out: Dictionary = super.shop_catalog()
 for id in out.items: out.items[id]["equipment_runtime"] = equipment_runtime_status(id)
 return out
