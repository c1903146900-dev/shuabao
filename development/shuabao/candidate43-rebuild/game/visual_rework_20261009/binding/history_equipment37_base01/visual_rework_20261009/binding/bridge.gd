extends "res://tests/ink_p1_ordinary_20261006/candidate01/ordinary01/bridge.gd"
## Same original startup body, catalog, consumers and wallet. The frozen parent
## initializer hard-codes its old Binding, so this leaf independently verifies
## this explicit successor before the exact same single Model construction.
const ExchangeBinding = preload("res://visual_rework_20261009/binding/live_binding.gd")
const ExchangeCatalog = preload("res://tests/ink_river_hexes_20261006/ordinary01/catalog.gd")
const ContentAdapter=preload("res://equipment_kill_20261009/adapter.gd")
const ContentModel=preload("res://equipment_kill_20261009/model.gd")
func initialize_runtime_fixture(sim: Node, capabilities: Dictionary, existing_table_path: String, source_fixture_path: String, numeric_path: String, owner: RefCounted, run_id: String, allow_runtime_fixture: bool = false) -> Dictionary:
 if not allow_runtime_fixture: return {"accepted":false, "reason":"runtime_fixture_opt_in_required"}
 if model != null: return {"accepted":false, "reason":"already_initialized"}
 if not is_instance_valid(sim) or sim.get_script().resource_path != "res://tests/ink_river_hexes_20261006/ordinary01/sim.gd": return {"accepted":false, "reason":"exact_ink_source_sim_required"}
 if sim.transaction_active or sim.phase != "preparation" or sim.wave != 0: return {"accepted":false, "reason":"fresh_sim_required"}
 var verified: Dictionary = ExchangeBinding.read_capabilities(sim, true)
 if not verified.accepted: return verified
 if capabilities != verified.capabilities: return {"accepted":false, "reason":"capability_payload_mismatch"}
 var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string(source_fixture_path))
 var numeric: Variant = JSON.parse_string(FileAccess.get_file_as_string(numeric_path))
 if not fixture is Dictionary or not numeric is Dictionary: return {"accepted":false, "reason":"commerce_json_invalid"}
 var projected: Dictionary = NumericAdapter.build(fixture, numeric)
 if not projected.accepted: return projected
 var mapped: Dictionary = ContentAdapter.build(numeric)
 if not mapped.accepted: return mapped
 readiness = ExchangeCatalog.build(capabilities, existing_table_path, true)
 if not readiness.accepted: return readiness.duplicate(true)
 definitions = readiness.definitions
 definitions.version = str(definitions.version) + "|equipment36-potions3:" + FileAccess.get_sha256(numeric_path)
 definitions["commerce_numeric_source"] = {"path":numeric_path, "sha256":FileAccess.get_sha256(numeric_path), "scope":"equipment36_potions3"}
 if reward_configuration.is_empty(): return {"accepted":false,"reason":"explicit_reward_table_required"}
 var candidate = ContentModel.new(definitions, "yanguizhou")
 var reward_bound: Dictionary = candidate.bind_reward_table(reward_configuration.table, reward_configuration.csv, reward_configuration.receipt, reward_configuration.allow)
 if not reward_bound.accepted: return reward_bound
 candidate.set_supported_hooks(readiness.hooks)
 var bound: Dictionary = candidate.bind_commerce(owner, projected.definitions, run_id, true)
 if not bound.accepted: return bound
 bound = candidate.bind_runtime_stats(mapped.definitions)
 if not bound.accepted: return bound
 bound = candidate.bind_health_sim(sim)
 if not bound.accepted: return bound
 bound = sim.bind_potion_model(candidate)
 if not bound.accepted: return bound
 model = candidate
 _runtime_sim = weakref(sim)
 _stat_consumer = InitialConsumer.new()
 _stat_consumer.sync_stats(sim, model)
 return {"accepted":true, "reason":"", "state":snapshot(), "runtime_fixture_only":true}
