extends RefCounted
## Prepared successor only. Deployment also requires the exact source Sim
## bridge, Model, dependency binding and real-engine acceptance gates.
const Prior = preload("res://equipment_elite_damage_20261009/adapter.gd")
const SourceAdapter = preload("source_adapter.gd")
const SOURCE := "res://docs/equipment_source_20261004/correction_0959/equipment_system_extracted.json"

static func build(numeric: Dictionary) -> Dictionary:
 var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
 if not source is Dictionary: return {"accepted":false,"reason":"b04_original_source_required"}
 return build_from_source(numeric,source)

static func build_from_source(numeric: Dictionary, source: Dictionary) -> Dictionary:
 var prepared: Dictionary = SourceAdapter.build(numeric,source)
 if not prepared.get("accepted",false): return prepared
 var prior: Dictionary = Prior.build(numeric)
 if not prior.get("accepted",false): return prior
 var count: int = 0
 for definition: Dictionary in prior.definitions.values():
  if definition.get("supported",false): count += 1
 if count != 37 or prior.definitions.has("final:B04"): return {"accepted":false,"reason":"exact_37_prior_equipment_required"}
 var out: Dictionary = prior.duplicate(true)
 var item: Dictionary = prepared.prepared_definitions["final:B04"].duplicate(true)
 item.supported = true
 item.reason = ""
 item.runtime_status = "inert_until_source_bridge_connected"
 item.runtime_complete = false
 item.shop_admitted = false
 item.erase("unresolved_lifecycle")
 item["passive08_lifecycle"] = {"scope":"player_passive_name_run","retained_across_rooms":true,"retained_when_sold":true,"accumulates_unequipped":false,"reset_on_new_run":true,"zero_cd_consumes_group":true,"approval":"2026-10-09T13:24 user approved B04 recommendations; no D04 implication"}
 out.definitions["final:B04"] = item
 count = 0
 for definition: Dictionary in out.definitions.values():
  if definition.get("supported",false): count += 1
 if count != 38: return {"accepted":false,"reason":"exact_38_equipment_required"}
 return out
