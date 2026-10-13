extends RefCounted
const Prior = preload("res://equipment_pursuit_20261009/adapter.gd")
const SourceAdapter = preload("source_adapter.gd")
const SOURCE := "res://docs/equipment_source_20261004/correction_0959/equipment_system_extracted.json"
static func build(numeric: Dictionary) -> Dictionary:
 var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
 if not source is Dictionary: return {"accepted":false,"reason":"d04_original_source_missing"}
 return build_from_source(numeric,source)
static func build_from_source(numeric: Dictionary, source: Dictionary) -> Dictionary:
 var prepared: Dictionary = SourceAdapter.build(numeric,source)
 if not prepared.get("accepted",false): return prepared
 var prior: Dictionary = Prior.build_from_source(numeric,source)
 if not prior.get("accepted",false): return prior
 var count: int = 0
 for prior_item: Dictionary in prior.definitions.values():
  if prior_item.get("supported",false): count += 1
 if count != 40 or prior.definitions.has("final:D04"): return {"accepted":false,"reason":"exact_40_prior_equipment_required"}
 var out: Dictionary = prior.duplicate(true)
 var item: Dictionary = prepared.prepared_definitions["final:D04"].duplicate(true)
 item.supported = true;item.reason = "";item.prepared_only = false
 item.runtime_complete = false;item.shop_admitted = false
 item["runtime_status"] = "inert_until_original_hp_commit_and_shield_bound"
 out.definitions["final:D04"] = item
 count = 0
 for definition: Dictionary in out.definitions.values():
  if definition.get("supported",false): count += 1
 if count != 41: return {"accepted":false,"reason":"exact_41_equipment_required"}
 return out
