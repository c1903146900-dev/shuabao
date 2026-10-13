extends "res://tests/ink_shop_ledger_bridge_20261004/ink_shop_ledger_bridge.gd"
## Explicit isolated startup. The ordinary first-floor entry is not replaced.
const StatModel = preload("res://tests/ink_shop_runtime_stats_20261004/ink_stat_run_model.gd")
const StatAdapter = preload("res://tests/ink_shop_runtime_stats_20261004/base_stat_adapter.gd")
const StatConsumer = preload("res://tests/ink_shop_runtime_stats_20261004/ink_stat_consumer.gd")
var _runtime_sim: WeakRef
var _stat_consumer = StatConsumer.new()
func initialize_economic_fixture(_capabilities: Dictionary, _existing_table_path: String, _source_fixture_path: String, _numeric_path: String, _owner: RefCounted, _run_id: String, _allow_economic_fixture: bool = false) -> Dictionary:
 return {"accepted":false, "reason":"explicit_runtime_fixture_initialization_required"}
func initialize_runtime_fixture(sim: Node, capabilities: Dictionary, existing_table_path: String, source_fixture_path: String, numeric_path: String, owner: RefCounted, run_id: String, allow_runtime_fixture: bool = false) -> Dictionary:
 if not allow_runtime_fixture: return {"accepted":false, "reason":"runtime_fixture_opt_in_required"}
 if model != null: return {"accepted":false, "reason":"already_initialized"}
 if not is_instance_valid(sim) or sim.get_script().resource_path != "res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_sim.gd": return {"accepted":false, "reason":"exact_ink_source_sim_required"}
 if sim.transaction_active or sim.phase != "preparation" or sim.wave != 0: return {"accepted":false, "reason":"fresh_sim_required"}
 var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string(source_fixture_path))
 var numeric: Variant = JSON.parse_string(FileAccess.get_file_as_string(numeric_path))
 if not fixture is Dictionary or not numeric is Dictionary: return {"accepted":false, "reason":"commerce_json_invalid"}
 var projected: Dictionary = NumericAdapter.build(fixture, numeric)
 if not projected.accepted: return projected
 var mapped: Dictionary = StatAdapter.build(numeric)
 if not mapped.accepted: return mapped
 readiness = Catalog.build(capabilities, existing_table_path, true)
 if not readiness.accepted: return readiness.duplicate(true)
 definitions = readiness.definitions
 definitions.version = str(definitions.version) + "|base-runtime-fixture:" + FileAccess.get_sha256(numeric_path)
 definitions["commerce_numeric_source"] = {"path":numeric_path, "sha256":FileAccess.get_sha256(numeric_path), "scope":"base_11_runtime_unbalanced"}
 var candidate = StatModel.new(definitions, "yanguizhou")
 candidate.set_supported_hooks(readiness.hooks)
 var bound: Dictionary = candidate.bind_commerce(owner, projected.definitions, run_id, true)
 if not bound.accepted: return bound
 bound = candidate.bind_runtime_stats(mapped.definitions)
 if not bound.accepted: return bound
 model = candidate
 _runtime_sim = weakref(sim)
 _stat_consumer.sync_stats(sim, model)
 return {"accepted":true, "reason":"", "state":snapshot(), "runtime_fixture_only":true}
func _runtime_preflight() -> String:
 if model == null or _runtime_sim == null or not is_instance_valid(_runtime_sim.get_ref()): return "runtime_binding_unavailable"
 if _runtime_sim.get_ref().transaction_active: return "transaction_in_progress"
 return ""
func refresh_runtime() -> Dictionary:
 var reason: String = _runtime_preflight()
 if not reason.is_empty(): return {"accepted":false, "reason":reason}
 _stat_consumer.sync_stats(_runtime_sim.get_ref(), model)
 return {"accepted":true, "reason":"", "equipment_runtime":model.equipment_effects()}
func _refresh_committed(result: Dictionary) -> Dictionary:
 if result.get("accepted", false) and result.get("changed", false):
  _stat_consumer.sync_stats(_runtime_sim.get_ref(), model)
 return result
func shop_command(id: String, action: String, args: Dictionary) -> Dictionary:
 var reason: String = _runtime_preflight()
 if not reason.is_empty(): return {"accepted":false, "reason":reason, "changed":false, "events":[]}
 return _refresh_committed(super.shop_command(id, action, args))
func shop_authority(owner: RefCounted, id: String, action: String, args: Dictionary) -> Dictionary:
 var reason: String = _runtime_preflight()
 if not reason.is_empty(): return {"accepted":false, "reason":reason, "changed":false, "events":[]}
 return _refresh_committed(super.shop_authority(owner, id, action, args))
func command(action: String, args: Dictionary = {}) -> Dictionary:
 var reason: String = _runtime_preflight()
 if not reason.is_empty(): return {"ok":false, "reason":reason, "state":snapshot(), "events":[]}
 var result: Dictionary = super.command(action, args)
 if result.ok: _stat_consumer.sync_stats(_runtime_sim.get_ref(), model)
 return result
