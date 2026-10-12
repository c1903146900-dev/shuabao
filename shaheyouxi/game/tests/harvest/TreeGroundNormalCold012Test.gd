extends GdUnitTestSuite
## Independent process: actual Store load and cold restore only. Never prepare
## native runtime, activate presence, generate terrain, or save a world here.
const ReceiptTokens = preload("res://tests/harvest/ground_normal_receipt012.gd")
const Support = preload("res://tests/harvest/TreeOwnerFrame012Test.gd")
const Ledger = preload("res://scripts/harvest/tree_ledger012.gd")
const Disk = preload("res://scripts/save/windows_generation_store.gd")
const SOURCE_STAGE_SHA: String = "623a73dbc39177404aeb10ec58f502ac17b4e7fd49284dcaab8e1d24353c6f71"
const SOURCE_MAIN_SHA: String = "b335888ca2ab94605db43a8b0aafb8518ef0cb096b6320d38b3650437800639c"
const SOURCE_PROBE_SHA: String = "b3afb1ffb8fd63417a35438271fa972e392a3e062e9a52990581d1b6a5b36ea5"
const FILES: Array = ["main.json", "auto/auto_01.json", "auto/auto_02.json", "auto/auto_03.json", "world_identity.json"]
const INDEX_NAME: String = "ground_normal_save_index.json"
var support: Variant

func before() -> void:
	support = Support.new()
	add_child(support)
	support.before()

func after_test() -> void:
	# The original fixture owns cleanup even when an assertion returns early.
	support.after_test()

func after() -> void:
	support.after()
	support.free()

func test_fresh_owner_restores_actual_hot_ground_normal_save() -> void:
	if not _require_test_identity(): return
	var root: String = OS.get_environment("TREE_GROUND_NORMAL_COLD_INPUT")
	var saved_stage_sha: String = OS.get_environment("TREE_GROUND_SAVED_STAGE_SHA")
	if not _need(root.is_absolute_path() and _hash(saved_stage_sha), "absolute independent cold input and frozen saved runtime SHA"): return
	if not _root_closed(root): return
	var index_sha: String = FileAccess.get_sha256(root.path_join(INDEX_NAME))
	var proof_sha: String = FileAccess.get_sha256(root.path_join("copy_proof.json"))
	if not _need(_hash(index_sha) and _hash(proof_sha), "cold metadata is readable before actual Store open"): return
	var index_text: String = FileAccess.get_file_as_string(root.path_join(INDEX_NAME))
	var parsed_index: Variant = JSON.parse_string(index_text)
	var parsed_proof: Variant = JSON.parse_string(FileAccess.get_file_as_string(root.path_join("copy_proof.json")))
	if not _need(parsed_index is Dictionary and parsed_proof is Dictionary, "independent copied index and proof dictionaries"): return
	var index: Dictionary = parsed_index
	var copy_proof: Dictionary = parsed_proof
	var receipt_ids: Dictionary = ReceiptTokens.read_tokens(index_text)
	if not _index_contract(index, saved_stage_sha, receipt_ids): return
	if not _copy_contract(copy_proof, root, index_sha, index): return
	var store: String = root.path_join("store")
	if not _store_unchanged(store, index["files"]): return
	var main_bytes: PackedByteArray = FileAccess.get_file_as_bytes(store.path_join("main.json"))
	if not _need(main_bytes == FileAccess.get_file_as_bytes(store.path_join("auto/auto_01.json")), "new main and actual slot1 exact bytes"): return
	var payload: Dictionary = _payload(main_bytes)
	if payload.is_empty(): return
	if not _need(payload.get("reason") == "normal_shutdown" and payload.get("sequence") == 4 and payload.get("kind") == "main" and payload.get("save_schema_version") == 6 and payload.get("state") is Dictionary, "cold main is exact profile6 normal seq4 save"): return
	# Both clocks are exact tagged doubles from already provenance-bound Store files.
	var previous_payload: Dictionary = _payload(FileAccess.get_file_as_bytes(store.path_join("auto/auto_03.json")))
	if previous_payload.is_empty(): return
	if not _need(previous_payload.get("sequence") == 3 and previous_payload.get("save_schema_version") == 6 and previous_payload.get("reason") == "normal_shutdown" and previous_payload.get("world_id") == payload.get("world_id") and previous_payload.get("state") is Dictionary, "fixed original seq3 exact source state"): return
	var previous_state: Dictionary = previous_payload["state"]
	var current_state: Dictionary = payload["state"]
	if not _need(typeof(previous_state.get("world_seconds")) == TYPE_FLOAT and typeof(current_state.get("world_seconds")) == TYPE_FLOAT, "original tagged double clock types"): return
	var exact_start: float = previous_state["world_seconds"]
	var exact_end: float = current_state["world_seconds"]
	if not _need(previous_state["inventory_component"]["ground_clock"] == exact_start and previous_state["actor_component"]["clock"] == exact_start and current_state["inventory_component"]["ground_clock"] == exact_end and current_state["actor_component"]["clock"] == exact_end and exact_end == exact_start + 0.125, "actual exact source and saved clocks advance once without epsilon"): return
	if not _need(ReceiptTokens.clocks_match(index_text, exact_start, exact_end), "root raw metadata clock tokens match original exact-state stringify"): return
	var server: Node = support._owner(store)
	if not _need(server != null, "fresh actual Owner allocated independently"): return
	var loaded: Dictionary = support._open(server)
	if not _need(loaded.get("ok", false) and loaded.get("loaded_from") == "main" and loaded.get("sequence") == 4 and loaded.get("state") is Dictionary and not loaded.get("new_world", false), "original Store load_latest selects main seq4 without fallback"): return
	var state: Dictionary = loaded["state"]
	if not _need(var_to_bytes(state) == var_to_bytes(payload["state"]) and Ledger.exact_token(state) == index["state_token"], "complete original Store state equals exact disk payload and saved token"): return
	var encoded: Dictionary = Support.Codec.encode(state)
	if not _need(encoded.get("ok", false), "original Codec encodes independently loaded complete state"): return
	if not _need(JSON.stringify(encoded["value"], "", true, true).sha256_text() == index["receipt"]["state_sha256"], "complete cold state matches actual producer Frame receipt"): return
	if not _need(state.get("inventory_component") is Dictionary and state.get("tree_component") is Dictionary and state.get("profiles") is Dictionary, "complete saved inventory tree and profile roots"): return
	var inventory: Dictionary = state["inventory_component"]
	var trees: Dictionary = state["tree_component"]
	var profile: String = index["profile"]
	var tree_id: String = index["tree_id"]
	var event: String = index["completion_id"]
	if not _need(inventory.get("schema_version") == 3 and inventory.get("ground_clock") == state.get("world_seconds") and state.get("world_seconds") == exact_end, "cold exact schema3 ground world and indexed clock"): return
	if not _need(trees.get("trees") is Dictionary and trees.get("completions") is Dictionary and trees["trees"].has(tree_id) and trees["completions"].has(event) and trees["completions"].size() == 1, "original tree and sole completion retained"): return
	if not _need(trees["trees"][tree_id].get("status") == "felled" and trees["trees"][tree_id].get("completion_id") == event and trees["completions"][event].get("tree_id") == tree_id and trees["completions"][event].get("profile_id") == profile, "original felled tree completion and recipient agree"): return
	if not _need(state["profiles"].has(profile) and inventory["players"].has(profile) and state["profiles"][profile].get("secret_hash") == Support.resume_secret().sha256_text(), "original unchanged saved profile and credential"): return
	if not _need(server._actor_space == null and server._bootstrap_frame == null and not server._live_input_activated and server._terrain_generation_count == 0, "cold Owner has never prepared native runtime or live input"): return
	var inventory_bytes: PackedByteArray = var_to_bytes(inventory)
	var tree_bytes: PackedByteArray = var_to_bytes(trees)
	var restored: Dictionary = server._restore_authority_state(state)
	if not _need(restored.get("ok", false), "original fresh Owner authority restore"): return
	if not _need(server._inventory_owner != null and var_to_bytes(server._inventory_owner.snapshot()) == inventory_bytes and var_to_bytes(server._inventory_owner.tree_snapshot()) == tree_bytes, "cold service restores complete inventory and tree bytes exactly"): return
	if not _need(server._authority.world_seconds == state["world_seconds"] and server._inventory_owner.snapshot()["ground_clock"] == server._authority.world_seconds, "restored authority ground and saved clocks match exactly"): return
	if not _need(server._authority.active_peer_ids().is_empty() and server._terrain_generation_count == 0 and server._actor_space == null and server._bootstrap_frame == null and not server._live_input_activated, "no active peer native runtime live input or generated terrain"): return
	if not _need(server._save_store.last_sequence == 4 and server._bootstrap_last_save_receipt.is_empty(), "cold reading has not made a new save or receipt"): return
	support.fixture._dispose_owner(server)
	if not _root_closed(root): return
	if not _store_unchanged(store, index["files"]): return
	if not _need(FileAccess.get_file_as_bytes(store.path_join("main.json")) == main_bytes, "closed cold main byte-for-byte unchanged"): return
	if not _need(FileAccess.get_sha256(root.path_join(INDEX_NAME)) == index_sha and FileAccess.get_sha256(root.path_join("copy_proof.json")) == proof_sha, "independent cold metadata unchanged after restore and close"): return
	print("TREE_GROUND_ACTUAL_NORMAL_COLD_RESTORED main_sha=", index["files"]["main.json"], " ordinary_live_stop=false")

func _index_contract(index: Dictionary, saved_stage_sha: String, receipt_ids: Dictionary) -> bool:
	var fields: Array = ["kind", "normal_frame_save", "ordinary_live_stop", "reason", "sequence", "runtime_stage_sha256", "source_stage_sha256", "source_main_sha256", "source_index_sha256", "probe_sha256", "source_sequence", "source_files", "receipt", "state_token", "profile", "tree_id", "completion_id", "files", "world_seconds_start", "world_seconds_end", "ground_world_seconds", "ground_clock", "step_seconds", "confirmed_steps", "full_calls", "hot_calls", "first_advance_usec", "hot_advance_usec", "new_enet_run", "ordinary_harvest_input"]
	if not _need(_fields(index, fields), "closed ground normal index field set"): return false
	if not _need(index["kind"] == "actual_ground_frame_normal_save_v1" and index["reason"] == "normal_shutdown" and _integer(index["sequence"], 1) and index["sequence"] == 4 and _integer(index["source_sequence"], 1) and index["source_sequence"] == 3, "actual ground normal seq4 from original seq3"): return false
	if not _need(_flag(index, "normal_frame_save", true) and _flag(index, "ordinary_live_stop", false) and _flag(index, "new_enet_run", false) and _flag(index, "ordinary_harvest_input", false), "precise bounded claim flags"): return false
	if not _need(index["runtime_stage_sha256"] == saved_stage_sha and index["source_stage_sha256"] == SOURCE_STAGE_SHA and index["source_main_sha256"] == SOURCE_MAIN_SHA and index["probe_sha256"] == SOURCE_PROBE_SHA and _hash(index["source_index_sha256"]) and _hash(index["state_token"]), "frozen runtime and original baseline source provenance"): return false
	if not _need(_hash_map(index["files"]) and _hash_map(index["source_files"]), "exact five-file new and original Store maps"): return false
	if not _need(index["source_files"]["main.json"] == SOURCE_MAIN_SHA and index["source_files"]["auto/auto_03.json"] == SOURCE_MAIN_SHA and index["files"]["main.json"] != SOURCE_MAIN_SHA and index["files"]["auto/auto_01.json"] == index["files"]["main.json"], "main and slot1 changed together from original baseline seq3"): return false
	for relative in ["auto/auto_02.json", "auto/auto_03.json", "world_identity.json"]:
		if not _need(index["files"][relative] == index["source_files"][relative], "retained original Store SHA " + relative): return false
	for key in ["profile", "tree_id", "completion_id"]:
		if not _need(index[key] is String and not index[key].is_empty(), "saved original identity " + key): return false
	var receipt: Variant = index["receipt"]
	if not _need(_fields(receipt, ["owner_id", "generation", "store_id", "sequence", "state_sha256", "main_committed", "complete"]), "exact real Frame receipt fields"): return false
	if not _need(_fields(receipt_ids, ["owner_id", "store_id"]), "exact raw signed64 receipt ID tokens without floating point conversion"): return false
	# IDs are producer-process audit labels; another process may legally reuse numbers.
	# Float comparison below checks JSON parsing only; exact labels stay raw strings.
	for key in ["owner_id", "store_id"]:
		if not _need(typeof(receipt[key]) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(receipt[key])) and float(receipt[key]) == float(receipt_ids[key]), "JSON parsed ID agrees with exact raw token " + key): return false
	for key in ["generation", "sequence"]:
		if not _need(_integer(receipt[key], 1), "valid Frame receipt integer " + key): return false
	if not _need(receipt["generation"] == 1 and receipt["sequence"] == 4 and _flag(receipt, "main_committed", true) and _flag(receipt, "complete", true) and _hash(receipt["state_sha256"]) and receipt["state_sha256"] == index["state_token"], "complete committed seq4 receipt for entire state"): return false
	for key in ["full_calls", "hot_calls", "confirmed_steps"]:
		if not _need(_integer(index[key], 1) and index[key] == 1, "exact single full admission and confirmed hot tick " + key): return false
	for key in ["first_advance_usec", "hot_advance_usec"]:
		if not _need(_integer(index[key], 0), "measured nonnegative ground timing " + key): return false
	for key in ["world_seconds_start", "world_seconds_end", "ground_world_seconds", "ground_clock", "step_seconds"]:
		if not _need(_finite_nonnegative(index[key]), "finite indexed clock " + key): return false
	# Parsed JSON values are auxiliary only. Exact clock/token binding follows
	# after both original tagged payloads are decoded, before Owner construction.
	return true

func _copy_contract(proof: Dictionary, root: String, index_sha: String, index: Dictionary) -> bool:
	if not _need(_fields(proof, ["ok", "source", "destination", "index_sha256", "files", "saved_runtime_stage_sha256", "normal_frame_save", "ordinary_live_stop", "engine_started", "source_modified"]), "closed independent strict-copy proof fields"): return false
	if not _need(_flag(proof, "ok", true) and _flag(proof, "normal_frame_save", true) and _flag(proof, "ordinary_live_stop", false) and _flag(proof, "engine_started", false) and _flag(proof, "source_modified", false), "strict copier succeeded without engine or source modification"): return false
	if not _need(proof["source"] is String and proof["source"].is_absolute_path() and proof["source"] != root and proof["destination"] is String and proof["destination"] == root, "independent copy source description and current destination"): return false
	# source is an audit label only. This process never reads that old directory.
	return _need(proof["index_sha256"] == index_sha and proof["saved_runtime_stage_sha256"] == index["runtime_stage_sha256"] and _hash_map(proof["files"]) and proof["files"] == index["files"], "strict copy binds exact index runtime and all five Store files")

func _root_closed(root: String) -> bool:
	if not _need(not Disk._is_link(root), "unlinked independent cold root"): return false
	var listing: Dictionary = Disk._directory_entries(root, 8)
	if not _need(listing.get("ok", false), "bounded cold root listing"): return false
	var found: Dictionary = {}
	for entry in listing["entries"]:
		var entry_name: String = entry["name"]
		if not _need(not Disk._is_link(root.path_join(entry_name)), "no cold root links"): return false
		found[entry_name] = entry["directory"]
	return _need(found == {"store": true, INDEX_NAME: false, "copy_proof.json": false}, "exact independent cold root entries")

func _store_unchanged(store: String, expected: Dictionary) -> bool:
	if not _need(_hash_map(expected) and not Disk._is_link(store), "unlinked Store and exact hash map"): return false
	var found: Dictionary = {}
	for relative in ["", "auto", "manual"]:
		var folder: String = store if relative.is_empty() else store.path_join(relative)
		if not relative.is_empty() and not DirAccess.dir_exists_absolute(folder):
			if relative == "manual": continue
			return _need(false, "required auto directory")
		if not _need(not Disk._is_link(folder), "no linked cold directory"): return false
		var listing: Dictionary = Disk._directory_entries(folder, 16)
		if not _need(listing.get("ok", false), "bounded complete cold Store listing"): return false
		for entry in listing["entries"]:
			var entry_name: String = entry["name"]
			if not _need(not Disk._is_link(folder.path_join(entry_name)), "no linked cold entry"): return false
			if entry["directory"]:
				if not _need(relative.is_empty() and entry_name in ["auto", "manual"], "no extra cold Store directory"): return false
			else:
				found[entry_name if relative.is_empty() else relative.path_join(entry_name)] = true
	if not _need(_fields(found, FILES), "closed five cold Store files with no lock tmp or extras"): return false
	for relative in FILES:
		if not _need(FileAccess.get_sha256(store.path_join(relative)) == expected[relative], "cold Store bytes unchanged " + relative): return false
	return true

func _payload(bytes: PackedByteArray) -> Dictionary:
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not _need(parsed is Dictionary and parsed.get("payload_json") is String and parsed.get("payload_codec") == "scalar_bits_le_v1", "cold main exact envelope"): return {}
	var payload_text: String = parsed["payload_json"]
	if not _need(payload_text.sha256_text() == parsed.get("payload_sha256"), "cold main payload checksum"): return {}
	var decoded: Dictionary = Support.Codec.decode(JSON.parse_string(payload_text))
	if not _need(decoded.get("ok", false) and decoded.get("value") is Dictionary, "original Codec decodes full cold payload"): return {}
	return decoded["value"]

func _fields(value: Variant, names: Array) -> bool:
	if not value is Dictionary or value.size() != names.size(): return false
	for field in names:
		if not value.has(field): return false
	return true

func _hash_map(value: Variant) -> bool:
	if not _fields(value, FILES): return false
	for relative in FILES:
		if not _hash(value[relative]): return false
	return true

func _hash(value: Variant) -> bool:
	if not value is String or value.length() != 64: return false
	for character in value:
		if character not in "0123456789abcdef": return false
	return true

func _flag(value: Dictionary, field: String, expected: bool) -> bool:
	return value.get(field) is bool and value[field] == expected

func _finite_nonnegative(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) >= 0.0

func _integer(value: Variant, minimum: int) -> bool:
	return _finite_nonnegative(value) and float(value) >= float(minimum) and float(value) <= 9007199254740991.0 and floor(float(value)) == float(value)

func _need(condition: bool, label: String) -> bool:
	if not condition: print("TREE_GROUND_NORMAL_COLD_ASSERTION ", label)
	assert_bool(condition).is_true()
	return condition

func _require_test_identity() -> bool:
	var available: bool = not Support.resume_secret().is_empty()
	assert_bool(available).is_true()
	return available
