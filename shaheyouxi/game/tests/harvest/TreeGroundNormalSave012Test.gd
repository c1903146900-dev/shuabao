extends "res://tests/harvest/TreeGroundPublished012Test.gd"
## SOURCE-ONLY gate. Select only the method below and exclude the inherited
## Published test. The sole durable write is the original Owner/Frame save.
const Ledger = preload("res://scripts/harvest/tree_ledger012.gd")
const NORMAL_FILES: Array = ["main.json", "auto/auto_01.json", "auto/auto_02.json", "auto/auto_03.json", "world_identity.json"]
const NORMAL_INDEX: String = "ground_normal_save_index.json"

func test_actual_hot_ground_then_original_frame_normal_save() -> void:
	var root: String = OS.get_environment("TREE_ENET_COLD_INPUT")
	var runtime_sha: String = OS.get_environment("TREE_GROUND_RUNTIME_STAGE_SHA")
	if not _need(root.is_absolute_path() and _normal_hash(runtime_sha), "absolute original strict-copy input and frozen runtime SHA"): return
	if not _normal_root_closed(root, false): return
	var source_index_sha: String = FileAccess.get_sha256(root.path_join("cold_index.json"))
	var source_probe_sha: String = FileAccess.get_sha256(root.path_join("server_probe.json"))
	if not _need(_normal_hash(source_index_sha) and source_probe_sha == PROBE_SHA, "original metadata readable before opening"): return
	var f: Dictionary = await _opened_published_runtime()
	if f.is_empty(): return
	var server: Node = f["owner"]
	var frame: RefCounted = f["frame"]
	var service: RefCounted = f["service"]
	var space: RefCounted = f["space"]
	var store: String = f["store"]
	var source_files: Dictionary = f["index"]["files"].duplicate(true)
	var initial_inventory: Dictionary = f["state"]["inventory_component"]
	var tree_bytes: PackedByteArray = var_to_bytes(f["state"]["tree_component"])
	var clock_start: float = f["state"]["world_seconds"]
	var clock_end: float = clock_start + STEP
	if not _need(source_files.get("main.json") == MAIN_SHA and source_files.get("auto/auto_03.json") == MAIN_SHA, "original seq3 main and retained auto03"): return
	if not _need(server._save_store.last_sequence == 3 and server._save_store.automatic_count == 2 and server._save_store._last_automatic_slot == 2, "original Store loaded seq3 and next real rotation is slot1"): return
	if not _need(frame._save_serial == 0 and server._bootstrap_last_save_receipt.is_empty() and not server._live_input_activated, "presence has not saved or activated ordinary live input"): return
	if not _normal_source_metadata(root, source_index_sha, source_probe_sha): return
	if not _normal_hashes_match(store, source_files): return
	if not _need(FileAccess.get_file_as_bytes(store.path_join("main.json")) == f["main_bytes"], "native presence has not rewritten original main"): return
	var first_started: int = Time.get_ticks_usec()
	var first: Dictionary = frame.advance_confirmed_ground(server)
	var first_usec: int = Time.get_ticks_usec() - first_started
	if not _need(first.get("ok", false) and first.get("published", false) and first.get("authoritative", false) and not first.get("durable", true), "first actual full ground publication"): return
	if not _need(frame._ground_full_checks == 1 and frame._ground_hot_checks == 0, "one full check before the actual tick"): return
	if not _need(var_to_bytes(service.snapshot()) == var_to_bytes(initial_inventory), "first zero-time publication preserves exact saved inventory"): return
	if not _runtime_clean(frame, service, space, f["tree_id"]): return
	var advanced: Dictionary = await _advance_actual_tick(f, clock_end, 1)
	if advanced.is_empty(): return
	if not _need(frame._ground_full_checks == 1 and frame._ground_hot_checks == 1, "actual positive Frame confirmation followed by one hot call"): return
	if not _runtime_clean(frame, service, space, f["tree_id"]): return
	var inventory: Dictionary = service.snapshot()
	var trees: Dictionary = service.tree_snapshot()
	if not _need(inventory.get("schema_version") == 3 and inventory.get("ground_clock") == clock_end and server._authority.world_seconds == clock_end and server._actor_model.clock_seconds() == clock_end, "exact confirmed schema3 world and ground clock"): return
	if not _need(var_to_bytes(trees) == tree_bytes and _item_totals(inventory) == _item_totals(initial_inventory) and inventory["ground_serial"] == initial_inventory["ground_serial"], "hot publication conserves original items and complete tree root"): return
	if not _natural_timers(inventory, f["event"], f["completion"]["completed_world_seconds"], clock_end): return
	if not _need(server._save_store.last_sequence == 3 and frame._save_serial == 0 and server._bootstrap_last_save_receipt.is_empty(), "no intermediate technical or bootstrap save"): return
	if not _normal_hashes_match(store, source_files): return
	if not _normal_source_metadata(root, source_index_sha, source_probe_sha): return
	# Do not call save_main directly, inject state, or materialize a snapshot.
	var normal: Dictionary = server._commit_confirmed_save("normal_shutdown")
	if not _need(normal.get("ok", false) and normal.get("main_committed", false) and normal.get("sequence") == 4 and normal.get("automatic_slot") == 1, "original Owner/Frame complete normal save seq4 slot1"): return
	if not _need(normal.get("save_receipt") is Dictionary, "original Frame returned a receipt"): return
	var receipt: Dictionary = normal["save_receipt"].duplicate(true)
	if not _need(receipt.get("complete") == true and receipt.get("main_committed") == true and receipt.get("sequence") == 4 and _normal_hash(receipt.get("state_sha256")), "complete committed real Frame receipt"): return
	if not _need(receipt.get("owner_id") == frame.get_instance_id() and receipt.get("store_id") == server._save_store.get_instance_id() and receipt.get("generation") == 1 and frame._save_serial == 1, "receipt belongs to this actual Frame and Store"): return
	if not _need(receipt == server._bootstrap_last_save_receipt and server._last_save_summary.get("reason") == "normal_shutdown" and server._last_save_summary.get("ok") == true and server._save_store.last_sequence == 4 and server._save_store._last_automatic_slot == 1, "Owner agrees with actual normal receipt and rotation"): return
	if not _need(var_to_bytes(service.snapshot()) == var_to_bytes(inventory) and var_to_bytes(service.tree_snapshot()) == tree_bytes, "normal save does not change the final published roots"): return
	if not _need(frame._ground_full_checks == 1 and frame._ground_hot_checks == 1, "saving does not conceal additional ground admission"): return
	if not _runtime_clean(frame, service, space, f["tree_id"]): return
	support.fixture._dispose_owner(server)
	# All durable evidence is read after close; a leaked lock or temp is fatal.
	var files: Dictionary = _normal_file_hashes(store)
	if files.is_empty(): return
	if not _source_files_unchanged(store, {"files": files}): return
	if not _normal_root_closed(root, false): return
	if not _normal_source_metadata(root, source_index_sha, source_probe_sha): return
	var main_bytes: PackedByteArray = FileAccess.get_file_as_bytes(store.path_join("main.json"))
	if not _need(main_bytes != f["main_bytes"] and main_bytes == FileAccess.get_file_as_bytes(store.path_join("auto/auto_01.json")) and files["main.json"] == files["auto/auto_01.json"], "new seq4 main and slot1 are exactly the same new bytes"): return
	for relative in ["auto/auto_02.json", "auto/auto_03.json", "world_identity.json"]:
		if not _need(files[relative] == source_files[relative], "original retained file unchanged " + relative): return
	var payload: Dictionary = _normal_payload(main_bytes)
	if payload.is_empty(): return
	if not _need(payload.get("reason") == "normal_shutdown" and payload.get("sequence") == 4 and payload.get("kind") == "main" and payload.get("save_schema_version") == 6 and payload.get("state") is Dictionary, "actual on-disk profile6 normal seq4 payload"): return
	var saved_state: Dictionary = payload["state"]
	if not _need(saved_state.get("world_seconds") == clock_end and var_to_bytes(saved_state.get("inventory_component")) == var_to_bytes(inventory) and var_to_bytes(saved_state.get("tree_component")) == tree_bytes, "disk state exactly matches final service inventory tree and clock"): return
	if not _need(saved_state["inventory_component"]["ground_clock"] == saved_state["world_seconds"], "saved ground and world clocks agree"): return
	var encoded: Dictionary = Support.Codec.encode(saved_state)
	if not _need(encoded.get("ok", false), "original exact Codec accepts complete saved state"): return
	var state_sha: String = JSON.stringify(encoded["value"], "", true, true).sha256_text()
	var state_token: String = Ledger.exact_token(saved_state)
	if not _need(state_sha == receipt["state_sha256"] and state_token == state_sha, "entire on-disk state matches original Frame receipt and exact token"): return
	var proof: Dictionary = {
		"kind": "actual_ground_frame_normal_save_v1", "normal_frame_save": true,
		"ordinary_live_stop": false, "reason": "normal_shutdown", "sequence": 4,
		"runtime_stage_sha256": runtime_sha, "source_stage_sha256": STAGE_SHA,
		"source_main_sha256": MAIN_SHA, "source_index_sha256": source_index_sha,
		"probe_sha256": source_probe_sha, "source_sequence": 3,
		"source_files": source_files, "receipt": receipt, "state_token": state_token,
		"profile": f["profile"], "tree_id": f["tree_id"], "completion_id": f["event"],
		"files": files, "world_seconds_start": clock_start, "world_seconds_end": clock_end,
		"ground_world_seconds": clock_end, "ground_clock": clock_end, "step_seconds": STEP, "confirmed_steps": 1,
		"full_calls": 1, "hot_calls": 1, "first_advance_usec": first_usec,
		"hot_advance_usec": advanced["advance_usec"], "new_enet_run": false,
		"ordinary_harvest_input": false
	}
	var proof_text: String = JSON.stringify(proof, "  ", true, true) + "\n"
	var index_path: String = root.path_join(NORMAL_INDEX)
	if not _need(_normal_write_new(index_path, proof_text), "new normal-save index fully written flushed closed and read back"): return
	if not _normal_root_closed(root, true): return
	if not _source_files_unchanged(store, {"files": files}): return
	if not _normal_source_metadata(root, source_index_sha, source_probe_sha): return
	if not _need(FileAccess.get_file_as_bytes(store.path_join("main.json")) == main_bytes and FileAccess.get_file_as_string(index_path) == proof_text and FileAccess.get_sha256(index_path) == proof_text.sha256_text(), "final closed disk bytes and written index agree"): return
	print("TREE_GROUND_ACTUAL_NORMAL_SAVE_COMPLETE main_sha=", files["main.json"], " index_sha=", proof_text.sha256_text(), " ordinary_live_stop=false")

func _normal_source_metadata(root: String, index_sha: String, probe_sha: String) -> bool:
	return _need(FileAccess.get_sha256(root.path_join("cold_index.json")) == index_sha and FileAccess.get_sha256(root.path_join("server_probe.json")) == probe_sha, "original copied index and probe remain unchanged")

func _normal_root_closed(root: String, with_index: bool) -> bool:
	if not _need(not Disk._is_link(root), "unlinked producer root"): return false
	var expected: Dictionary = {"store": true, "cold_index.json": false, "server_probe.json": false}
	if with_index: expected[NORMAL_INDEX] = false
	var listing: Dictionary = Disk._directory_entries(root, 8)
	if not _need(listing.get("ok", false), "bounded producer root listing"): return false
	var found: Dictionary = {}
	for entry in listing["entries"]:
		var entry_name: String = entry["name"]
		if not _need(not Disk._is_link(root.path_join(entry_name)), "no producer root link"): return false
		found[entry_name] = entry["directory"]
	return _need(found == expected, "exact producer root entries with no stale success index")

func _normal_file_hashes(store: String) -> Dictionary:
	var result: Dictionary = {}
	for relative in NORMAL_FILES:
		var digest: String = FileAccess.get_sha256(store.path_join(relative))
		if not _need(_normal_hash(digest), "read actual closed Store hash " + relative): return {}
		result[relative] = digest
	return result

func _normal_hashes_match(store: String, expected: Dictionary) -> bool:
	for relative in NORMAL_FILES:
		if not _need(expected.has(relative) and _normal_hash(expected[relative]) and FileAccess.get_sha256(store.path_join(relative)) == expected[relative], "no unscheduled source file change " + relative): return false
	return true

func _normal_payload(bytes: PackedByteArray) -> Dictionary:
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not _need(parsed is Dictionary and parsed.get("payload_json") is String and parsed.get("payload_codec") == "scalar_bits_le_v1", "saved main exact envelope"): return {}
	var payload_text: String = parsed["payload_json"]
	if not _need(payload_text.sha256_text() == parsed.get("payload_sha256"), "saved main payload checksum"): return {}
	var decoded: Dictionary = Support.Codec.decode(JSON.parse_string(payload_text))
	if not _need(decoded.get("ok", false) and decoded.get("value") is Dictionary, "original Codec decodes full saved payload"): return {}
	return decoded["value"]

func _normal_write_new(path: String, text: String) -> bool:
	if Disk._exists(path): return false
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	var written: bool = file.store_string(text)
	file.flush()
	var error: int = file.get_error()
	file.close()
	return written and error == OK and FileAccess.get_file_as_string(path) == text and FileAccess.get_sha256(path) == text.sha256_text()

func _normal_hash(value: Variant) -> bool:
	if not value is String or value.length() != 64: return false
	for character in value:
		if character not in "0123456789abcdef": return false
	return true
