extends "res://tests/harvest/TreeWorldSession012Test.gd"
const Transaction = preload("res://scripts/harvest/tree_transaction012.gd")
func _joint_fixture() -> Dictionary:
	var base:=_reference_state()
	var f: Dictionary={"owner":_empty_owner(),"profile":base["profiles"].keys()[0]}
	# Explicit empty inventory for a NEW isolated v2 fixture. No old save is
	# rewritten or upgraded, and no existing v1 item is silently reclassified.
	var core:=Core.new(WORLD,"v2_tree_seed")
	for profile in base["profiles"]: assert_bool(core.trusted_create_player(profile)["ok"]).is_true()
	var contract:=Combined.new(f["owner"]._terrain_session,core,f["owner"]._authority)
	var inventory: Dictionary=contract.combine(base,core.snapshot())
	assert_bool(inventory["ok"]).is_true()
	var seed: String=base["world_component"]["layout"]["seed_decimal"]
	var ledger:=TreeLedger.new(WORLD,seed)
	var scope:=TreeSession.new(contract,f["owner"]._authority,seed)
	var world: Dictionary=inventory["state"]["world_component"]
	var layer: Dictionary=world["layout"]["spawn"]["layer"]
	var regions:=TreeSession.regions_for_layer(world,layer)
	var added: Dictionary={}
	for x in range(-30,31):
		var plan: Dictionary=ledger.plan_fixture_tree(layer,[x,30],regions["entries"],regions["protected"],ledger.token())
		if plan.get("ok",false):
			added=plan
			break
	assert_bool(added.is_empty()).is_false()
	if added.is_empty(): return {}
	var whole: Dictionary=scope.combine(inventory["state"],added["state"])
	assert_bool(whole["ok"]).is_true()
	f.merge({"tree_id":added["tree_id"],"event":TreeLedger.completion_identity(added["tree_id"]),"joint_scope":scope,"joint":Transaction.new(scope,whole["state"]),"joint_core":core,"joint_contract":contract},true)
	assert_bool(f["joint"].ready).is_true()
	return f
func test_joint_completion_is_one_root_swap_and_replay_is_exactly_noncreating() -> void:
	var f:=_joint_fixture()
	if f.is_empty(): return
	var joint: RefCounted=f["joint"]
	var before: Dictionary=joint.snapshot()
	var plan: Dictionary=joint.plan_completion(f["tree_id"],f["event"],f["profile"],joint.tokens())
	assert_bool(plan["ok"]).is_true()
	assert_bool(var_to_bytes(joint.snapshot())==var_to_bytes(before)).is_true()
	var result: Dictionary=joint.commit(plan)
	assert_bool(result["ok"] and result["published"] and not result["durable"]).is_true()
	var after: Dictionary=joint.snapshot()
	assert_str(after["tree_component"]["trees"][f["tree_id"]]["status"]).is_equal("felled")
	assert_bool(after["inventory_component"]["ground"].size()>0).is_true()
	assert_bool(joint.commit(plan)["ok"]).is_false() # Original two source tokens stale.
	var replay: Dictionary=joint.plan_completion(f["tree_id"],f["event"],f["profile"],joint.tokens())
	assert_bool(replay["ok"] and replay["replay"]).is_true()
	assert_bool(joint.commit(replay)["ok"]).is_true()
	assert_bool(var_to_bytes(joint.snapshot())==var_to_bytes(after)).is_true()
func test_joint_tampered_candidate_and_each_stale_token_fail_without_half_publish() -> void:
	var f:=_joint_fixture()
	if f.is_empty(): return
	var joint: RefCounted=f["joint"]
	var before:=var_to_bytes(joint.snapshot())
	for field in ["tree","inventory","boundary"]:
		var wrong: Dictionary=joint.tokens()
		wrong[field]="stale"
		assert_bool(joint.plan_completion(f["tree_id"],f["event"],f["profile"],wrong)["ok"]).is_false()
	var plan: Dictionary=joint.plan_completion(f["tree_id"],f["event"],f["profile"],joint.tokens())
	plan["state"]["inventory_component"]["ground"].clear()
	assert_str(joint.commit(plan)["code"]).is_equal("TREE_TRANSACTION_PLAN_CHANGED")
	assert_bool(var_to_bytes(joint.snapshot())==before).is_true()
func test_joint_completed_world_actual_store_fresh_cold_restore_and_retry_exact() -> void:
	var f:=_joint_fixture()
	if f.is_empty(): return
	var joint: RefCounted=f["joint"]
	assert_bool(joint.commit(joint.plan_completion(f["tree_id"],f["event"],f["profile"],joint.tokens()))["ok"]).is_true()
	var completed: Dictionary=joint.snapshot()
	var store: RefCounted=f["joint_scope"].make_store(f["owner"]._save_directory,2,2)
	_stores.append(store)
	assert_bool(store.acquire()["ok"] and store.load_latest().get("new_world",false)).is_true()
	assert_bool(store.save_main(completed,"tree_completed_fixture")["ok"]).is_true()
	var path: String=f["owner"]._save_directory.path_join("main.json")
	var bytes:=FileAccess.get_file_as_bytes(path)
	store.close()
	var fresh_owner:=_empty_owner()
	var fresh_core:=Core.new(WORLD,"v2_tree_seed")
	var fresh_inner:=Combined.new(fresh_owner._terrain_session,fresh_core,fresh_owner._authority)
	var fresh_scope:=TreeSession.new(fresh_inner,fresh_owner._authority,completed["tree_component"]["seed_decimal"])
	var reader: RefCounted=fresh_scope.make_store(f["owner"]._save_directory,2,2)
	_stores.append(reader)
	assert_bool(reader.acquire()["ok"]).is_true()
	var loaded: Dictionary=reader.load_latest()
	assert_bool(loaded["ok"]).is_true()
	assert_bool(var_to_bytes(loaded["state"])==var_to_bytes(completed)).is_true()
	var restored:=Transaction.new(fresh_scope,loaded["state"])
	assert_bool(restored.ready).is_true()
	var replay: Dictionary=restored.plan_completion(f["tree_id"],f["event"],f["profile"],restored.tokens())
	assert_bool(replay["ok"] and replay["replay"]).is_true()
	assert_bool(restored.commit(replay)["ok"]).is_true()
	assert_bool(var_to_bytes(restored.snapshot())==var_to_bytes(completed)).is_true()
	assert_bool(FileAccess.get_file_as_bytes(path)==bytes).is_true()
func _write_boundary_fixture(fail_backup: bool) -> void:
	var f:=_joint_fixture()
	if f.is_empty(): return
	var joint: RefCounted=f["joint"]
	var before: Dictionary=joint.snapshot()
	var store: RefCounted=f["joint_scope"].make_store(f["owner"]._save_directory,2,2)
	_stores.append(store)
	assert_bool(store.acquire()["ok"] and store.load_latest().get("new_world",false)).is_true()
	assert_bool(store.save_main(before,"tree_before_completion")["ok"]).is_true()
	assert_bool(joint.commit(joint.plan_completion(f["tree_id"],f["event"],f["profile"],joint.tokens()))["ok"]).is_true()
	var completed: Dictionary=joint.snapshot()
	var directory: String=f["owner"]._save_directory
	var obstruction: String="auto/auto_02.json.tmp" if fail_backup else "main.json.tmp"
	assert_int(DirAccess.make_dir_absolute(directory.path_join(obstruction))).is_equal(OK)
	var receipt: Dictionary=store.save_main(completed,"tree_write_fault_fixture")
	assert_bool(receipt["ok"]).is_false()
	assert_bool(receipt.get("main_committed",false)).is_equal(fail_backup)
	if fail_backup: assert_str(receipt["code"]).is_equal("MAIN_SAVED_BACKUP_FAILED")
	store.close()
	var fresh: RefCounted=f["joint_scope"].make_store(directory,2,2)
	_stores.append(fresh)
	assert_bool(fresh.acquire()["ok"]).is_true()
	var loaded: Dictionary=fresh.load_latest()
	assert_bool(loaded["ok"]).is_true()
	var expected: Dictionary=completed if fail_backup else before
	assert_bool(var_to_bytes(loaded["state"])==var_to_bytes(expected)).is_true()
	var restored:=Transaction.new(f["joint_scope"],loaded["state"])
	var retry: Dictionary=restored.plan_completion(f["tree_id"],f["event"],f["profile"],restored.tokens())
	assert_bool(retry["ok"]).is_true()
	assert_bool(retry["replay"]).is_equal(fail_backup)
	assert_bool(restored.commit(retry)["ok"]).is_true()
	assert_bool(var_to_bytes(restored.snapshot())==var_to_bytes(completed)).is_true()
func test_joint_actual_main_write_fault_restores_old_complete_root() -> void:
	_write_boundary_fixture(false)
func test_joint_actual_backup_fault_restores_committed_complete_root_without_extra_drop() -> void:
	_write_boundary_fixture(true)
func test_joint_natural_timers_cannot_be_shortened_or_renewed_and_multitick_is_exact() -> void:
	var f:=_joint_fixture()
	if f.is_empty(): return
	var joint: RefCounted=f["joint"]
	assert_bool(joint.commit(joint.plan_completion(f["tree_id"],f["event"],f["profile"],joint.tokens()))["ok"]).is_true()
	var complete: Dictionary=joint.snapshot()
	var id: String=complete["inventory_component"]["ground"].keys()[0]
	for change in [["remaining_delay",0.0],["remaining_lifetime",299.0]]:
		var invalid: Dictionary=complete.duplicate(true)
		invalid["inventory_component"]["ground"][id]["lots"][0][change[0]]=change[1]
		assert_str(f["joint_scope"].validate_combined_state(invalid)["code"]).is_equal("TREE_GROUND_SOURCE_TIMER_MISMATCH")
	var core:=Core.new(WORLD,"v2_tree_seed")
	assert_bool(core.trusted_restore(complete["inventory_component"])["ok"]).is_true()
	var ground_script=load("res://scripts/inventory/inventory_ground012.gd")
	for index in range(1,31):
		var advanced: Dictionary=ground_script.advance(core,float(index)/60.0)
		assert_bool(advanced["ok"]).is_true()
		assert_bool(core.trusted_restore(advanced["state"])["ok"]).is_true()
	complete["inventory_component"]=core.snapshot()
	complete["world_seconds"]=0.5
	complete["actor_component"]["clock"]=0.5
	assert_bool(f["joint_scope"].validate_combined_state(complete)["ok"]).is_true()
	complete["inventory_component"]["ground"][id]["lots"][0]["remaining_delay"]=0.1
	assert_str(f["joint_scope"].validate_combined_state(complete)["code"]).is_equal("TREE_GROUND_SOURCE_TIMER_MISMATCH")
