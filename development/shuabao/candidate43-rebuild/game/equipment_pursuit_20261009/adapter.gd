extends RefCounted
const Prior = preload("res://equipment_training_20261009/adapter.gd")
const SourceAdapter = preload("source_adapter.gd")
const SOURCE := "res://docs/equipment_source_20261004/correction_0959/equipment_system_extracted.json"

static func build(numeric: Dictionary) -> Dictionary:
 var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
 if not source is Dictionary: return {"accepted":false,"reason":"b02_original_source_missing"}
 return build_from_source(numeric,source)

static func build_from_source(numeric: Dictionary, source: Dictionary) -> Dictionary:
 var prepared: Dictionary = SourceAdapter.build(numeric,source)
 if not prepared.get("accepted",false): return prepared
 var prior: Dictionary = Prior.build_from_source(numeric,source)
 if not prior.get("accepted",false): return prior
 var count: int = 0
 for definition: Dictionary in prior.definitions.values():
  if definition.get("supported",false): count += 1
 if count != 39 or prior.definitions.has("final:B02"): return {"accepted":false,"reason":"exact_39_prior_equipment_required"}
 var out: Dictionary = prior.duplicate(true)
 var item: Dictionary = prepared.prepared_definitions["final:B02"].duplicate(true)
 item.supported = true;item.reason = "";item.prepared_only = false
 item.runtime_complete = false;item.shop_admitted = false
 item["runtime_status"] = "inert_until_original_death_clock_and_stats_bound"
 item.erase("unresolved_lifecycle")
 item["passive28_lifecycle"] = {"clock":"original_common_actor_time","sold_existing_buff":"retain_original_expiry","rebuy_refreshes":false,"ordinary_room_transition":"retain_remaining_actor_seconds","safe_clock_paused":true,"safe_move_bonus_active":true,"rest":"existing_cast_state_clear","dead_owner":"no_new_grant_or_active_projection","new_run":"fresh_owner_no_buff","repeated_kill":"replace_expiry_now_plus_duration_not_stack","multiplayer_supported":false,"approval":"B02 user lifecycle approval 2026-10-09 14:42; no D04 implication"}
 out.definitions["final:B02"] = item
 count = 0
 for definition: Dictionary in out.definitions.values():
  if definition.get("supported",false): count += 1
 if count != 40: return {"accepted":false,"reason":"exact_40_equipment_required"}
 return out
