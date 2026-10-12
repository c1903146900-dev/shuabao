extends GdUnitTestSuite
## Fresh actual Frame normal save after the verified technical handoff; no listener/live-stop claim.
const Disk = preload("res://scripts/save/windows_generation_store.gd") # Portable bounded directory/link helpers only.
const Helper = preload("res://tests/harvest/TreeFrameCompletion012Test.gd")
const OwnerSupport = preload("res://tests/harvest/TreeOwnerFrame012Test.gd")
const Ledger = preload("res://scripts/harvest/tree_ledger012.gd")
const Core = preload("res://scripts/inventory/inventory_core012.gd")
const Session = preload("res://scripts/harvest/tree_world_session012.gd")
var helper
func before() -> void:
	helper=Helper.new()
	add_child(helper)
	helper.before()
func after_test() -> void:
	helper.after_test()
func after() -> void:
	helper.after()
	helper.free()

func test_restored_published_tree_replay_then_actual_frame_normal_save() -> void:
	if not _require_test_identity(): return
	assert_bool(_hash(OS.get_environment("TREE_PUBLICATION_SOURCE_STAGE_SHA")) and _hash(OS.get_environment("TREE_OWNER_RUNTIME_STAGE_SHA"))).is_true()
	if not _hash(OS.get_environment("TREE_PUBLICATION_SOURCE_STAGE_SHA")) or not _hash(OS.get_environment("TREE_OWNER_RUNTIME_STAGE_SHA")): return
	var root:=OS.get_environment("TREE_PUBLICATION_HANDOFF_INPUT")
	var store_path:=OS.get_environment("TREE_PUBLICATION_REPLAY_STORE")
	assert_bool(root.is_absolute_path() and store_path.is_absolute_path() and not DirAccess.dir_exists_absolute(store_path)).is_true()
	if not root.is_absolute_path() or not store_path.is_absolute_path() or DirAccess.dir_exists_absolute(store_path): return
	var index: Variant=JSON.parse_string(FileAccess.get_file_as_string(root.path_join("handoff_index.json")))
	assert_bool(index is Dictionary).is_true()
	if not index is Dictionary: return
	assert_str(index.get("kind","")).is_equal("confirmed_tree_publication_technical_handoff_v1")
	assert_bool(index.get("normal_frame_save")==false).is_true()
	assert_str(index.get("source_stage_sha256","")).is_equal(OS.get_environment("TREE_PUBLICATION_SOURCE_STAGE_SHA"))
	var text:=FileAccess.get_file_as_string(root.path_join("snapshot.json"))
	assert_str(text.sha256_text()).is_equal(index.get("snapshot_sha256",""))
	if text.sha256_text()!=index.get("snapshot_sha256"): return
	var decoded: Dictionary=Core.Codec.decode(JSON.parse_string(text))
	assert_bool(decoded.get("ok",false)).is_true()
	if not decoded.get("ok",false) or not decoded["value"] is Dictionary: return
	var state: Dictionary=decoded["value"]
	var writer: Node=helper.support._owner(store_path)
	if writer==null: return
	var opened: Dictionary=helper.support._open(writer)
	assert_bool(opened.get("ok",false) and opened.get("new_world",false)).is_true()
	if not opened.get("ok",false) or not opened.get("new_world",false): return
	# Independent technical Store materialization. Explicitly NOT the first
	# process's Frame save; it validates the complete published snapshot anew.
	var saved: Dictionary=writer._save_store.save_main(state,"isolated_published_tree_handoff")
	assert_bool(saved.get("ok",false)).is_true()
	if not saved.get("ok",false): return
	helper.support.fixture._dispose_owner(writer)
	var main_hash:=FileAccess.get_sha256(store_path.path_join("main.json"))
	var owner: Node=helper.support._owner(store_path)
	if owner==null: return
	var loaded: Dictionary=helper.support._open(owner)
	assert_bool(loaded.get("ok",false) and loaded.get("loaded_from")=="main").is_true()
	if not loaded.get("ok",false) or not loaded.has("state"): return
	assert_bool(var_to_bytes(loaded["state"])==var_to_bytes(state)).is_true()
	var restored: Dictionary=owner._restore_authority_state(loaded["state"])
	assert_bool(restored.get("ok",false)).is_true()
	if not restored.get("ok",false): return
	assert_int(owner._terrain_generation_count).is_equal(0)
	var started: bool=await owner._prepare_runtime_before_listen()
	assert_bool(started).is_true()
	if not started: return
	var frame: RefCounted=owner._bootstrap_frame
	var profile: String=index["profile"]
	var hello: Dictionary={"network_protocol_version":owner._authority.protocol_version,"catalogue_sha256":owner._authority.catalogue_hash,"display_name":state["profiles"][profile]["display_name"],"resume_profile_id":profile,"resume_secret":OwnerSupport.resume_secret()}
	var prepared: Dictionary=frame.prepare_bootstrap_presence(11,hello,false)
	assert_bool(prepared.get("ok",false)).is_true()
	if not prepared.get("ok",false): return
	var committed: Dictionary=frame.commit_bootstrap_presence(prepared["ticket"])
	assert_bool(committed.get("pending",false)).is_true()
	if not committed.get("pending",false): return
	await get_tree().physics_frame
	var presence: Dictionary=frame.confirm_bootstrap_presence(prepared["ticket"])
	assert_bool(presence.get("confirmed",false)).is_true()
	if not presence.get("confirmed",false): return
	var service: RefCounted=owner._inventory_owner
	var before: String=service.boundary_token()
	var inventory: Dictionary=service.snapshot()
	var tree_state: Dictionary=service.tree_snapshot()
	var replay: Dictionary=frame.prepare_fixture_tree_completion(owner,11,index["tree_id"],index["completion_id"])
	assert_bool(replay.get("ok",false) and replay.get("replay",false)).is_true()
	assert_bool(replay.get("created_drop_ids",["unexpected"]).is_empty()).is_true()
	assert_bool(var_to_bytes(replay.get("completion",{}))==var_to_bytes(tree_state["completions"][index["completion_id"]])).is_true()
	assert_str(service.boundary_token()).is_equal(before)
	assert_bool(var_to_bytes(service.snapshot())==var_to_bytes(inventory) and var_to_bytes(service.tree_snapshot())==var_to_bytes(tree_state)).is_true()
	assert_bool(owner._actor_space._tree_native._records.is_empty()).is_true()
	assert_bool(frame._tree_pending.is_empty() and frame.public_snapshot().get("ok",false)).is_true()
	assert_str(FileAccess.get_sha256(store_path.path_join("main.json"))).is_equal(main_hash)
	assert_str(FileAccess.get_sha256(root.path_join("snapshot.json"))).is_equal(index["snapshot_sha256"])
	# This new process now performs the real Frame normal-shutdown save. The
	# earlier cross-process handoff remains a technical snapshot, not a receipt.
	var normal: Dictionary = owner._commit_confirmed_save("normal_shutdown")
	assert_bool(normal.get("ok", false) and normal.get("main_committed", false)).is_true()
	if not normal.get("ok", false): return
	assert_str(owner._last_save_summary["reason"]).is_equal("normal_shutdown")
	assert_bool(owner._bootstrap_last_save_receipt.get("complete", false)).is_true()
	assert_int(normal["sequence"]).is_equal(2)
	assert_bool(var_to_bytes(service.snapshot()) == var_to_bytes(inventory) and var_to_bytes(service.tree_snapshot()) == var_to_bytes(tree_state)).is_true()
	var receipt: Dictionary = owner._bootstrap_last_save_receipt.duplicate(true)
	helper.support.fixture._dispose_owner(owner)
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(store_path.path_join("main.json")))
	var saved_payload: Dictionary = Core.Codec.decode(JSON.parse_string(envelope["payload_json"]))
	assert_bool(saved_payload.get("ok", false)).is_true()
	if not saved_payload.get("ok", false): return
	var payload: Dictionary = saved_payload["value"]
	assert_str(payload["reason"]).is_equal("normal_shutdown")
	assert_int(payload["sequence"]).is_equal(2)
	var final_state: Dictionary = payload["state"]
	assert_bool(var_to_bytes(final_state["inventory_component"]) == var_to_bytes(inventory)).is_true()
	assert_bool(var_to_bytes(final_state["tree_component"]) == var_to_bytes(tree_state)).is_true()
	var encoded: Dictionary = Core.Codec.encode(final_state)
	assert_bool(encoded.get("ok", false)).is_true()
	assert_str(JSON.stringify(encoded["value"], "", true, true).sha256_text()).is_equal(receipt["state_sha256"])
	assert_bool(_closed_store(store_path)).is_true()
	if not _closed_store(store_path): return
	var files: Dictionary = {}
	for relative in ["main.json", "auto/auto_01.json", "auto/auto_02.json", "world_identity.json"]:
		assert_bool(FileAccess.file_exists(store_path.path_join(relative))).is_true()
		if not FileAccess.file_exists(store_path.path_join(relative)): return
		files[relative] = FileAccess.get_sha256(store_path.path_join(relative))
		assert_bool(_hash(files[relative])).is_true()
		if not _hash(files[relative]): return
	var proof: Dictionary = {"kind":"actual_frame_normal_tree_save_v1", "source_handoff_sha256":index["snapshot_sha256"], "source_stage_sha256":OS.get_environment("TREE_PUBLICATION_SOURCE_STAGE_SHA"), "runtime_stage_sha256":OS.get_environment("TREE_OWNER_RUNTIME_STAGE_SHA"), "normal_frame_save":true, "ordinary_live_stop":false, "reason":"normal_shutdown", "sequence":2, "receipt":receipt, "state_token":Ledger.exact_token(final_state), "profile":profile, "tree_id":index["tree_id"], "completion_id":index["completion_id"], "files":files}
	var proof_text := JSON.stringify(proof, "  ", true, true) + "\n"
	assert_bool(_write(store_path.get_base_dir().path_join("normal_save_index.json"), proof_text)).is_true()
	print("TREE_ACTUAL_FRAME_NORMAL_SAVE_COMPLETE main_sha=",files["main.json"]," index_sha=",proof_text.sha256_text()," ordinary_live_stop=false")

func _write(path: String, text: String) -> bool:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null: return false
	file.store_string(text)
	file.flush()
	var error:=file.get_error()
	file.close()
	return error==OK

func _hash(value: Variant) -> bool:
	if not value is String or value.length() != 64: return false
	for character in value:
		if character not in "0123456789abcdef": return false
	return true

func _closed_store(path: String) -> bool:
	if Disk._is_link(path): return false
	var found: Dictionary = {}
	for relative in ["", "auto", "manual"]:
		var folder := path if relative.is_empty() else path.path_join(relative)
		if not relative.is_empty() and not DirAccess.dir_exists_absolute(folder):
			if relative == "manual": continue
			return false
		if Disk._is_link(folder): return false
		var listing: Dictionary = Disk._directory_entries(folder, 16)
		if not listing.get("ok", false): return false
		for entry in listing["entries"]:
			var name: String = entry["name"]
			if Disk._is_link(folder.path_join(name)): return false
			if entry["directory"]:
				if not relative.is_empty() or name not in ["auto", "manual"]: return false
			else:
				found[name if relative.is_empty() else relative.path_join(name)] = true
	return found == {"main.json":true, "auto/auto_01.json":true, "auto/auto_02.json":true, "world_identity.json":true}

func _require_test_identity() -> bool:
	var available: bool = not OwnerSupport.resume_secret().is_empty()
	assert_bool(available).is_true()
	return available
