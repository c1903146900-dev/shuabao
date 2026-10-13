extends "res://tests/ink_first_floor_flow_20261004/ink_ledger_bridge.gd"
## Explicit TEST FIXTURE startup. This does not replace the ordinary entry point.
const ShopModel = preload("res://tests/ink_shop_ledger_bridge_20261004/ink_shop_run_model.gd")
const NumericAdapter = preload("res://tests/equipment_shop_transactions_20261004/numeric_table_adapter.gd")

func initialize(_capabilities: Dictionary, _table_path: String, _allow_provisional: bool = false) -> Dictionary:
 return {"accepted":false, "reason":"explicit_economic_fixture_initialization_required"}

func initialize_economic_fixture(capabilities: Dictionary, existing_table_path: String, source_fixture_path: String, numeric_path: String, owner: RefCounted, run_id: String, allow_economic_fixture: bool = false) -> Dictionary:
 if not allow_economic_fixture: return {"accepted":false, "reason":"economic_fixture_opt_in_required"}
 if model != null: return {"accepted":false, "reason":"already_initialized"}
 var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string(source_fixture_path))
 var numeric: Variant = JSON.parse_string(FileAccess.get_file_as_string(numeric_path))
 if not fixture is Dictionary or not numeric is Dictionary: return {"accepted":false, "reason":"commerce_json_invalid"}
 var projected: Dictionary = NumericAdapter.build(fixture, numeric)
 if not projected.accepted: return projected
 readiness = Catalog.build(capabilities, existing_table_path, true)
 if not readiness.accepted: return readiness.duplicate(true)
 definitions = readiness.definitions
 definitions.version = str(definitions.version) + "|economic-fixture:" + FileAccess.get_sha256(numeric_path)
 definitions["commerce_numeric_source"] = {"path":numeric_path, "sha256":FileAccess.get_sha256(numeric_path), "scope":"economic_fixture_unbalanced"}
 var candidate = ShopModel.new(definitions, "yanguizhou")
 candidate.set_supported_hooks(readiness.hooks)
 var bound: Dictionary = candidate.bind_commerce(owner, projected.definitions, run_id, true)
 if not bound.accepted: return bound
 model = candidate
 return {"accepted":true, "reason":"", "state":snapshot(), "economic_fixture_only":true}

func command(action: String, args: Dictionary = {}) -> Dictionary:
 if model == null: return {"ok":false, "reason":"ink_ledger_unavailable", "state":{}, "events":[]}
 serial += 1
 var result: Dictionary = model.command("ink-context-%d" % serial, action, args)
 # Original bridge discarded events. This economic fixture forwards exact lifecycle receipts.
 return {"ok":result.accepted, "reason":result.reason, "state":snapshot(), "events":result.events.duplicate(true), "receipt":result.duplicate(true), "economic_fixture_only":true}

func shop_command(id: String, action: String, args: Dictionary) -> Dictionary:
 if model == null: return {"accepted":false, "reason":"ink_ledger_unavailable"}
 return model.commerce_command(id, action, args)

func shop_authority(owner: RefCounted, id: String, action: String, args: Dictionary) -> Dictionary:
 if model == null: return {"accepted":false, "reason":"ink_ledger_unavailable"}
 return model.commerce_authority(owner, id, action, args)
