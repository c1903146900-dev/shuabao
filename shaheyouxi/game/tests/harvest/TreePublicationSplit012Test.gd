extends GdUnitTestSuite
## Production-zero-change split. Handoff is a technical full snapshot, never a
## Frame normal-shutdown receipt. The original all-in-one test stays intact.
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

func test_publish_atomic_tree_and_export_exact_confirmed_snapshot() -> void:
	var context: Dictionary=await helper._opened_alive_frame()
	if context.is_empty(): return
	var f: Dictionary=context["fixture"]
	var owner: Node=context["owner"]
	var frame: RefCounted=context["frame"]
	var service: RefCounted=owner._inventory_owner
	var before: Dictionary=service.snapshot()
	var event:=Ledger.completion_identity(f["tree_id"])
	helper._phase("split_prepare_begin")
	var prepared: Dictionary=frame.prepare_fixture_tree_completion(owner,11,f["tree_id"],event)
	assert_bool(prepared.get("ok",false)).is_true()
	if not prepared.get("ok",false): return
	# Off-root candidate only; it is not a handoff until real confirmation and
	# every authoritative postcondition below have succeeded.
	var candidate: Dictionary=frame._tree_pending["prepared"]["plan"]["state"].duplicate(true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var confirmed: Dictionary=frame.confirm_fixture_tree_completion(prepared["ticket"])
	helper._phase("split_confirm_end")
	print("TREE_SPLIT_PUBLISHED ",JSON.stringify({"ok":confirmed.get("ok",false),"published":confirmed.get("published",false),"created_drop_ids":confirmed.get("created_drop_ids",[])}))
	assert_bool(confirmed.get("published",false)).is_true()
	if not confirmed.get("published",false): return
	var trees: Dictionary=service.tree_snapshot()
	var after: Dictionary=service.snapshot()
	assert_str(trees["trees"][f["tree_id"]]["status"]).is_equal("felled")
	assert_bool(not context["native"]._records.has(f["tree_id"])).is_true()
	assert_bool(frame.public_snapshot().get("ok",false)).is_true()
	assert_bool(context["space"].validate_actor_frame_boundary().get("ok",false)).is_true()
	var expected: Dictionary=service._core._totals(before)
	for output in trees["completions"][event]["outputs"]:
		service._core._count(expected,{"content_id":output["content_id"],"quantity":output["quantity"],"item_instance_id":"","protected_instance_id":"","state":{}})
	assert_bool(service._core._totals(after)==expected).is_true()
	for id in confirmed["created_drop_ids"]:
		var lot: Dictionary=after["ground"][id]["lots"][0]
		assert_bool(lot["thrower"]==null and lot["remaining_thrower_protection"]==null).is_true()
		assert_float(lot["remaining_delay"]).is_equal(0.5)
	assert_bool(frame.confirm_fixture_tree_completion(prepared["ticket"]).get("ok",false)).is_false()
	assert_bool(var_to_bytes(service.snapshot())==var_to_bytes(after)).is_true()
	assert_bool(var_to_bytes(candidate["inventory_component"])==var_to_bytes(after)).is_true()
	assert_bool(var_to_bytes(candidate["tree_component"])==var_to_bytes(trees)).is_true()
	var base:=Session.InventorySession.terrain_state(Session.inventory_state(candidate))
	assert_bool(var_to_bytes(base["terrain_component"])==var_to_bytes(owner._terrain_component)).is_true()
	base.erase("terrain_component")
	assert_bool(var_to_bytes(base)==var_to_bytes(frame._last_state)).is_true()
	var root:=OS.get_environment("TREE_PUBLICATION_HANDOFF_OUTPUT")
	var source:=OS.get_environment("TREE_ATOMIC_STAGE_SHA")
	assert_bool(root.is_absolute_path() and not DirAccess.dir_exists_absolute(root) and source.length()==64).is_true()
	if not root.is_absolute_path() or DirAccess.dir_exists_absolute(root) or source.length()!=64: return
	assert_int(DirAccess.make_dir_recursive_absolute(root)).is_equal(OK)
	var encoded: Dictionary=Core.Codec.encode(candidate)
	assert_bool(encoded.get("ok",false)).is_true()
	if not encoded.get("ok",false): return
	var text:=JSON.stringify(encoded["value"],"",true,true)
	assert_bool(_write(root.path_join("snapshot.json"),text)).is_true()
	var index: Dictionary={"kind":"confirmed_tree_publication_technical_handoff_v1","source_stage_sha256":source,"source_fixture_index_sha256":FileAccess.get_sha256(OS.get_environment("TREE_ATOMIC_FIXTURE_INPUT").path_join("fixture_index.json")),"snapshot_sha256":text.sha256_text(),"world_id":candidate["world_id"],"profile":f["profile"],"actor_id":f["actor_id"],"tree_id":f["tree_id"],"completion_id":event,"created_drop_ids":confirmed["created_drop_ids"].duplicate(),"normal_frame_save":false}
	assert_bool(_write(root.path_join("handoff_index.json"),JSON.stringify(index,"  ",true,true)+"\n")).is_true()
	assert_str(FileAccess.get_sha256(root.path_join("snapshot.json"))).is_equal(index["snapshot_sha256"])
	print("TREE_PUBLICATION_HANDOFF_COMPLETE snapshot_sha=",index["snapshot_sha256"]," index_sha=",FileAccess.get_sha256(root.path_join("handoff_index.json")))

func test_handoff_real_store_cold_owner_replay_has_no_new_drop() -> void:
	if not _require_test_identity(): return
	var root:=OS.get_environment("TREE_PUBLICATION_HANDOFF_INPUT")
	var store_path:=OS.get_environment("TREE_PUBLICATION_REPLAY_STORE")
	assert_bool(root.is_absolute_path() and store_path.is_absolute_path() and not DirAccess.dir_exists_absolute(store_path)).is_true()
	if not root.is_absolute_path() or not store_path.is_absolute_path() or DirAccess.dir_exists_absolute(store_path): return
	var index: Variant=JSON.parse_string(FileAccess.get_file_as_string(root.path_join("handoff_index.json")))
	assert_bool(index is Dictionary).is_true()
	if not index is Dictionary: return
	assert_str(index.get("kind","")).is_equal("confirmed_tree_publication_technical_handoff_v1")
	assert_bool(index.get("normal_frame_save")==false).is_true()
	assert_str(index.get("source_stage_sha256","")).is_equal(OS.get_environment("TREE_ATOMIC_STAGE_SHA"))
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
	print("TREE_PUBLICATION_HANDOFF_REPLAY_COMPLETE normal_frame_save=false store_main_sha=",main_hash)

func _write(path: String, text: String) -> bool:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null: return false
	file.store_string(text)
	file.flush()
	var error:=file.get_error()
	file.close()
	return error==OK

func _require_test_identity() -> bool:
	var available: bool = not OwnerSupport.resume_secret().is_empty()
	assert_bool(available).is_true()
	return available
