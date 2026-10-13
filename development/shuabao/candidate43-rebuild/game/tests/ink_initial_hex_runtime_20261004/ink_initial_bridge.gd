extends "res://tests/ink_shop_runtime_stats_20261004/ink_stat_bridge.gd"
## Narrow startup substitution; original stat bridge and its531 result stay frozen.
const InitialCatalog=preload("res://tests/ink_initial_hex_runtime_20261004/ink_initial_catalog.gd")
const InitialConsumer=preload("res://tests/ink_initial_hex_runtime_20261004/ink_initial_stat_consumer.gd")
const HealthModel=preload("res://tests/ink_initial_hex_runtime_20261004/ink_initial_model.gd")
func initialize_runtime_fixture(sim: Node, capabilities: Dictionary, existing_table_path: String, source_fixture_path: String, numeric_path: String, owner: RefCounted, run_id: String, allow_runtime_fixture: bool = false) -> Dictionary:
 if not allow_runtime_fixture: return {"accepted":false, "reason":"runtime_fixture_opt_in_required"}
 if model != null: return {"accepted":false, "reason":"already_initialized"}
 if not is_instance_valid(sim) or sim.get_script().resource_path != "res://tests/ink_initial_hex_runtime_20261004/ink_initial_sim.gd": return {"accepted":false, "reason":"exact_ink_source_sim_required"}
 if sim.transaction_active or sim.phase != "preparation" or sim.wave != 0: return {"accepted":false, "reason":"fresh_sim_required"}
 var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string(source_fixture_path))
 var numeric: Variant = JSON.parse_string(FileAccess.get_file_as_string(numeric_path))
 if not fixture is Dictionary or not numeric is Dictionary: return {"accepted":false, "reason":"commerce_json_invalid"}
 var projected: Dictionary = NumericAdapter.build(fixture, numeric)
 if not projected.accepted: return projected
 var mapped: Dictionary = StatAdapter.build(numeric)
 if not mapped.accepted: return mapped
 readiness = InitialCatalog.build(capabilities, existing_table_path, true)
 if not readiness.accepted: return readiness.duplicate(true)
 definitions = readiness.definitions
 definitions.version = str(definitions.version) + "|initial-hex-hp-undo-fixture:" + FileAccess.get_sha256(numeric_path)
 definitions["commerce_numeric_source"] = {"path":numeric_path, "sha256":FileAccess.get_sha256(numeric_path), "scope":"base_11_runtime_unbalanced"}
 var candidate = HealthModel.new(definitions, "yanguizhou")
 candidate.set_supported_hooks(readiness.hooks)
 var bound: Dictionary = candidate.bind_commerce(owner, projected.definitions, run_id, true)
 if not bound.accepted: return bound
 bound = candidate.bind_runtime_stats(mapped.definitions)
 if not bound.accepted: return bound
 bound = candidate.bind_health_sim(sim)
 if not bound.accepted: return bound
 model = candidate
 _runtime_sim = weakref(sim)
 _stat_consumer = InitialConsumer.new()
 _stat_consumer.sync_stats(sim, model)
 return {"accepted":true, "reason":"", "state":snapshot(), "runtime_fixture_only":true}
