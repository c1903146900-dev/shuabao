extends GdUnitTestSuite
## Real concrete Owner/Frame/Store, no sockets or GUI. Natural density remains off.
const Fixture = preload("res://tests/harvest/TreeTransaction012Test.gd")
const Owner = preload("res://scripts/actor/actor_terrain_network_main.gd")
const TreeOwner = preload("res://scripts/harvest/tree_inventory_owner012.gd")
const Profiles = preload("res://scripts/inventory/inventory_save_profiles012.gd")
const Codec = preload("res://scripts/save/exact_scalar_codec.gd")
const SessionIdentity = preload("res://tests/support/session_identity.gd")
var fixture
func before() -> void:
	fixture=Fixture.new()
	add_child(fixture)
func after_test() -> void:
	fixture.after_test()
func after() -> void:
	fixture.free()
func _state(completed: bool) -> Dictionary:
	var f: Dictionary=fixture._joint_fixture()
	assert_bool(not f.is_empty()).is_true()
	if f.is_empty(): return {}
	var model: RefCounted=f["joint"]
	if completed:
		var planned: Dictionary=model.plan_completion(f["tree_id"],f["event"],f["profile"],model.tokens())
		assert_bool(planned.get("ok",false)).is_true()
		if not planned.get("ok",false): return {}
		var published: Dictionary=model.commit(planned)
		assert_bool(published.get("ok",false)).is_true()
		if not published.get("ok",false): return {}
	var result: Dictionary=model.snapshot()
	fixture._dispose_owner(f["owner"])
	return result
func _owner(path: String="") -> Node:
	var owner: Node=fixture._empty_owner()
	owner._arguments["save_profile"]="6"
	owner._arguments["tree_fixture_profile"]="isolated"
	owner._save_settings["automatic_backup_count"]=2
	owner._save_settings["manual_slot_count"]=2
	owner._authority=SandboxServerAuthority.new(int(owner._settings["max_players"]),int(owner._settings["network_protocol_version"]),owner._catalogue.source_sha256,float(owner._save_settings["automatic_interval_seconds"]))
	if not path.is_empty(): owner._save_directory=path
	assert_bool(owner.get_script()==Owner and not owner.is_inside_tree()).is_true()
	owner._save_store=owner._make_save_store()
	assert_object(owner._save_store).is_not_null()
	return owner if owner._save_store!=null else null
func _open(owner: Node) -> Dictionary:
	var acquired: Dictionary=owner._save_store.acquire()
	assert_bool(acquired.get("ok",false)).is_true()
	return owner._save_store.load_latest() if acquired.get("ok",false) else acquired
func test_real_owner6_alive_tree_rejected_before_any_world_restore() -> void:
	var state:=_state(false)
	if state.is_empty(): return
	var owner:=_owner()
	if owner==null: return
	assert_bool(_open(owner).get("new_world",false)).is_true()
	# The actual Store's validator accepts complete data; only runtime admission
	# refuses unsupported native H1. No silent deletion or corpse substitution.
	assert_bool(owner._inventory_registry._tree_cold.validate_combined_state(state)["ok"]).is_true()
	var before_authority:=var_to_bytes(owner._authority.persistent_state())
	var before_world:=var_to_bytes(owner._world.public_component())
	var before_terrain:=var_to_bytes(owner._terrain_component)
	var result: Dictionary=owner._restore_authority_state(state)
	assert_str(result["code"]).is_equal("TREE_NATIVE_COLLISION_UNSUPPORTED")
	assert_bool(var_to_bytes(owner._authority.persistent_state())==before_authority).is_true()
	assert_bool(var_to_bytes(owner._world.public_component())==before_world).is_true()
	assert_bool(var_to_bytes(owner._terrain_component)==before_terrain and owner._inventory_owner==null).is_true()
	assert_int(owner._terrain_restore_count).is_equal(0)
func test_real_owner6_completed_tree_cold_restore_and_out_of_frame_mutation_guard() -> void:
	var state:=_state(true)
	if state.is_empty(): return
	var owner:=_owner()
	if owner==null: return
	assert_bool(_open(owner).get("new_world",false)).is_true()
	var restored: Dictionary=owner._restore_authority_state(state)
	assert_bool(restored.get("ok",false)).is_true()
	if not restored.get("ok",false): return
	assert_bool(owner._inventory_owner.get_script()==TreeOwner).is_true()
	assert_bool(var_to_bytes(owner._inventory_owner.snapshot())==var_to_bytes(state["inventory_component"])).is_true()
	assert_bool(var_to_bytes(owner._inventory_owner.tree_snapshot())==var_to_bytes(state["tree_component"])).is_true()
	assert_bool(owner._authority.active_peer_ids().is_empty()).is_true()
	assert_int(owner._terrain_generation_count).is_equal(0)
	# Internal RefCounted access is not a write capability: tampering invalidates
	# the service bundle instead of making a new certified publication root.
	var changed: Dictionary=owner._inventory_owner._core.snapshot()
	changed["revision"]+=1
	assert_bool(owner._inventory_owner._core.trusted_restore(changed)["ok"]).is_true()
	assert_bool(owner._inventory_service_ready()).is_false()
func test_real_owner6_frame_tick_complete_save_and_fresh_owner_cold_restore() -> void:
	if not _require_test_identity(): return
	var state:=_state(true)
	if state.is_empty(): return
	var profile: String=state["profiles"].keys()[0]
	# Isolated fixture credential, matching the existing real Frame resume test.
	state["profiles"][profile]["secret_hash"]=resume_secret().sha256_text()
	var owner:=_owner()
	if owner==null: return
	assert_bool(_open(owner).get("new_world",false)).is_true()
	var restored: Dictionary=owner._restore_authority_state(state)
	assert_bool(restored.get("ok",false)).is_true()
	if not restored.get("ok",false): return
	var runtime: bool=await owner._prepare_runtime_before_listen()
	assert_bool(runtime).is_true()
	if not runtime: return
	var frame: RefCounted=owner._bootstrap_frame
	var hello: Dictionary={"network_protocol_version":owner._authority.protocol_version,"catalogue_sha256":owner._authority.catalogue_hash,"display_name":state["profiles"][profile]["display_name"],"resume_profile_id":profile,"resume_secret":resume_secret()}
	var prepared: Dictionary=frame.prepare_bootstrap_presence(11,hello,false)
	print("TREE_OWNER_PHASE presence_prepare ",JSON.stringify({"ok":prepared.get("ok"),"code":prepared.get("code","")}))
	assert_bool(prepared.get("ok",false) and prepared.get("prepared",false)).is_true()
	if not prepared.get("ok",false): return
	var committed: Dictionary=frame.commit_bootstrap_presence(prepared["ticket"])
	assert_bool(committed.get("pending",false) and committed.get("committed",false)).is_true()
	if not committed.get("pending",false): return
	await get_tree().physics_frame
	var presence: Dictionary=frame.confirm_bootstrap_presence(prepared["ticket"])
	assert_bool(presence.get("ok",false) and presence.get("confirmed",false)).is_true()
	if not presence.get("ok",false): return
	assert_int(owner._actor_model.active_actor_ids().size()).is_equal(1)
	var retired_core: RefCounted=owner._inventory_owner._core
	for tick in range(2):
		var submitted: Dictionary=frame.submit(0.125,[])
		print("TREE_OWNER_PHASE submit ",tick," ",JSON.stringify({"pending":submitted.get("pending"),"code":submitted.get("code","")}))
		assert_bool(submitted.get("pending",false)).is_true()
		if not submitted.get("pending",false): return
		await get_tree().physics_frame
		var confirmed: Dictionary=frame.confirm(submitted["ticket"])
		assert_bool(confirmed.get("confirmed",false)).is_true()
		if not confirmed.get("confirmed",false): return
		var advanced: Dictionary=frame.advance_confirmed_ground(owner)
		print("TREE_OWNER_PHASE advanced ",tick," ",JSON.stringify({"ok":advanced.get("ok"),"code":advanced.get("code","")}))
		assert_bool(advanced.get("ok",false)).is_true()
		if not advanced.get("ok",false): return
	assert_bool(retired_core!=owner._inventory_owner._core).is_true()
	var before_retired_mutation: String=owner._inventory_owner.boundary_token()
	# A retired object is no longer the publication root. Changing its private
	# data cannot affect current inventory, current validator rules or receipts.
	retired_core._rules["item_rules"]["mucai"]["max_stack"]=1000
	var retired: Dictionary=retired_core.snapshot()
	retired["revision"]+=1
	assert_bool(retired_core.trusted_restore(retired)["ok"]).is_true()
	assert_str(owner._inventory_owner.boundary_token()).is_equal(before_retired_mutation)
	assert_bool(owner._inventory_service_ready()).is_true()
	var inventory: Dictionary=owner._inventory_owner.snapshot()
	var trees: Dictionary=owner._inventory_owner.tree_snapshot()
	assert_float(inventory["ground_clock"]).is_equal(owner._authority.world_seconds)
	for drop in inventory["ground"].values():
		for lot in drop["lots"]:
			assert_float(lot["remaining_delay"]).is_equal(0.25)
			assert_float(lot["remaining_lifetime"]).is_equal(299.75)
	var saved: Dictionary=owner._commit_confirmed_save("normal_shutdown")
	print("TREE_OWNER_PHASE saved ",JSON.stringify({"ok":saved.get("ok"),"code":saved.get("code",""),"main_committed":saved.get("main_committed",false)}))
	assert_bool(saved.get("ok",false) and saved.get("main_committed",false)).is_true()
	if not saved.get("ok",false): return
	var path: String=owner._save_directory
	var bytes:=FileAccess.get_file_as_bytes(path.path_join("main.json"))
	var envelope: Dictionary=JSON.parse_string(bytes.get_string_from_utf8())
	var payload: Dictionary=Codec.decode(JSON.parse_string(envelope["payload_json"]))["value"]
	assert_int(payload["save_schema_version"]).is_equal(6)
	var encoded: Dictionary=Codec.encode(payload["state"])
	assert_str(saved["save_receipt"]["state_sha256"]).is_equal(JSON.stringify(encoded["value"],"",true,true).sha256_text())
	fixture._dispose_owner(owner)
	var cold:=_owner(path)
	if cold==null: return
	var loaded:=_open(cold)
	assert_bool(loaded.get("ok",false)).is_true()
	if not loaded.get("ok",false): return
	var applied: Dictionary=cold._restore_authority_state(loaded["state"])
	print("TREE_OWNER_PHASE cold_restored ",JSON.stringify({"ok":applied.get("ok"),"code":applied.get("code","")}))
	assert_bool(applied.get("ok",false)).is_true()
	if not applied.get("ok",false): return
	assert_bool(var_to_bytes(cold._inventory_owner.snapshot())==var_to_bytes(inventory)).is_true()
	assert_bool(var_to_bytes(cold._inventory_owner.tree_snapshot())==var_to_bytes(trees)).is_true()
	assert_int(cold._terrain_generation_count).is_equal(0)
	assert_bool(cold._authority.active_peer_ids().is_empty()).is_true()
	assert_bool(FileAccess.get_file_as_bytes(path.path_join("main.json"))==bytes).is_true()
func test_profile6_requires_explicit_fixture_opt_in_and_old_profiles_stay_closed() -> void:
	var plain: Node=fixture._empty_owner()
	plain._arguments["save_profile"]="6"
	assert_str(plain._freeze_save_profile()["code"]).is_equal("TREE_RUNTIME_FIXTURE_OPT_IN_REQUIRED")
	assert_bool(plain._save_profile_binding.is_empty()).is_true()
	assert_bool(Profiles._known_profile(4) and Profiles._known_profile(5) and Profiles._known_profile(6)).is_true()
	assert_bool(Profiles._known_profile(7) or Profiles._known_profile("6")).is_false()

func test_real_owner6_current_rule_tampering_invalidates_service_certificate() -> void:
	var state:=_state(true)
	if state.is_empty(): return
	var owner:=_owner()
	if owner==null: return
	assert_bool(_open(owner).get("new_world",false)).is_true()
	var restored: Dictionary=owner._restore_authority_state(state)
	assert_bool(restored.get("ok",false)).is_true()
	if not restored.get("ok",false): return
	owner._inventory_owner._core._rules["item_rules"]["mucai"]["max_stack"]=1000
	assert_bool(owner._inventory_service_ready()).is_false()

static func resume_secret() -> String:
	return SessionIdentity.read_resume_secret()

func _require_test_identity() -> bool:
	var available: bool = not resume_secret().is_empty()
	assert_bool(available).is_true()
	return available
