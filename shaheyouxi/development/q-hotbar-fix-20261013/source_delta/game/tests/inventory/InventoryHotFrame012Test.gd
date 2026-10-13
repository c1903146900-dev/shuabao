extends GdUnitTestSuite
## Actual Frame ownership and original full Store boundaries, no sockets/UI.
const Fixture = preload("res://tests/inventory/InventoryGroundFrame012Test.gd")
const Hot = preload("res://scripts/inventory/inventory_hot_boundary012.gd")
var fixture
func before() -> void:
	fixture = Fixture.new()
	add_child(fixture)
	fixture.before()
func after_test() -> void: fixture.after_test()
func after() -> void:
	fixture.after()
	fixture.free()
func _advance(owner: Node, delta: float) -> Dictionary:
	var frame = owner._bootstrap_frame
	var issued: Dictionary = frame.submit(delta,[])
	assert_bool(issued.get("pending",false)).is_true()
	if not issued.get("pending",false): return issued
	await get_tree().physics_frame
	var confirmed: Dictionary = frame.confirm(issued["ticket"])
	assert_bool(confirmed.get("confirmed",false)).is_true()
	if not confirmed.get("confirmed",false): return confirmed
	return frame.advance_confirmed_ground(owner)
func _probe(service: RefCounted) -> RefCounted:
	var probe := Hot.new()
	probe._cache = service._hot_boundary._cache
	probe._cache_ready = true
	return probe
func test_actual_frame_hot_transactions_invalidations_and_full_save() -> void:
	var state: Dictionary = fixture._fixture_state()
	var profile: String = state["inventory_component"]["players"].keys()[0]
	var gun: Dictionary = state["inventory_component"]["players"][profile]["carry"].duplicate(true)
	# Q's fixture source is a hotbar slot; retain the original wood quantity.
	state["inventory_component"]["players"][profile]["hotbar"][0] = state["inventory_component"]["players"][profile]["bag"][0]
	state["inventory_component"]["players"][profile]["bag"][0] = null
	var owner: Node = fixture._owner()
	assert_bool(fixture._open(owner).get("new_world",false)).is_true()
	assert_bool(owner._restore_authority_state(state)["ok"]).is_true()
	await fixture._runtime(owner)
	await fixture._presence(owner,fixture._hello(owner,profile))
	var frame = owner._bootstrap_frame
	var service = owner._inventory_owner
	var context := {"frame":frame,"lease":frame._source_lease}
	var drop: Dictionary = frame.apply_confirmed_inventory_drop(owner,profile,"carry_all",{},service.revision(),20,Vector2.RIGHT)
	assert_bool(drop.get("ok",false)).is_true()
	if not drop.get("ok",false):
		fixture._fixtures._dispose_owner(owner)
		return
	assert_int(service.snapshot()["ground"].size()).is_equal(1)
	assert_bool(var_to_bytes(service.snapshot()["ground"].values()[0]["stack"]) == var_to_bytes(gun)).is_true()
	assert_int(service._hot_boundary.statistics()["full_checks"]).is_equal(1)
	var stale_token: String = service.boundary_token()
	var stale_candidate: RefCounted = service._copy_core()
	for index in range(3): assert_bool((await _advance(owner,1.0/60.0)).get("ok",false)).is_true()
	assert_int(service._hot_boundary.statistics()["full_checks"]).is_equal(1)
	var current_token: String = service.boundary_token()
	var base: Dictionary = frame._inventory_transaction_base(owner)["state"]
	assert_str(service._publish_checked(base,stale_candidate,{"ok":true,"source_token":stale_token},context).get("code","")).is_equal("INVENTORY_WHOLE_STATE_STALE")
	assert_str(service.boundary_token()).is_equal(current_token)
	assert_bool(frame.apply_confirmed_inventory_drop(owner,profile,"carry_all",{},service.revision(),20,Vector2.RIGHT).get("ok",false)).is_false()
	# Every dynamic candidate is revalidated, even after the static proof is cached.
	var valid: Dictionary = service.snapshot()
	var broken: Dictionary = valid.duplicate(true)
	broken["ground_clock"] += 1.0
	assert_bool(_probe(service).validate(base,broken,service,context).get("ok",false)).is_false()
	broken = valid.duplicate(true)
	broken["ground"].values()[0]["lots"][0]["quantity"] = 9223372036854775807
	assert_bool(_probe(service).validate(base,broken,service,context).get("ok",false)).is_false()
	broken = valid.duplicate(true)
	broken["players"][profile]["bag"][2] = gun.duplicate(true)
	assert_bool(_probe(service).validate(base,broken,service,context).get("ok",false)).is_false()
	broken = valid.duplicate(true)
	broken["players"].erase(profile)
	assert_bool(_probe(service).validate(base,broken,service,context).get("ok",false)).is_false()
	var replaced: Dictionary = base.duplicate(false)
	replaced["world_component"] = base["world_component"].duplicate(true)
	replaced["world_component"].make_read_only()
	assert_bool(_probe(service).validate(replaced,valid,service,context).get("ok",false)).is_false()
	replaced = base.duplicate(false)
	replaced["world_seconds"] += 0.25
	assert_bool(_probe(service).validate(replaced,valid,service,context).get("ok",false)).is_false()
	# Config/ref replacements must reject before parsing the wrong codec shape.
	var original_store: RefCounted = service._contract._budget_store
	original_store._exact_scalars = false
	assert_str(_probe(service).validate(base,valid,service,context).get("code","")).is_equal("INVENTORY_HOT_BUDGET_BINDING_CHANGED")
	original_store._exact_scalars = true
	service._contract._budget_store = Fixture.Combined.SaveStore.new("",1,1,service._catalogue_hash,service._protocol,Callable(),5,Fixture.Combined.MAX_BYTES,true)
	assert_str(_probe(service).validate(base,valid,service,context).get("code","")).is_equal("INVENTORY_HOT_CACHE_BINDING_CHANGED")
	service._contract._budget_store = original_store
	assert_str(service.boundary_token()).is_equal(current_token)
	# Real protected cohort becomes eligible and is picked up exactly once.
	assert_bool((await _advance(owner,2.0)).get("ok",false)).is_true()
	assert_int(service.snapshot()["ground"].size()).is_equal(0)
	var found := 0
	for stack in service.snapshot()["players"][profile]["bag"] + service.snapshot()["players"][profile]["hotbar"]:
		if stack != null and stack.get("item_instance_id","") == gun["item_instance_id"]:
			found += 1
			assert_bool(var_to_bytes(stack) == var_to_bytes(gun)).is_true()
	assert_int(found).is_equal(1)
	assert_int(service._hot_boundary.statistics()["full_checks"]).is_equal(1)
	# Lifetime removal is a separate transaction class from pickup removal.
	var wood_before: int = service.snapshot()["players"][profile]["hotbar"][0]["quantity"]
	var q_before: PackedByteArray = var_to_bytes(service.snapshot())
	var invalid_q: Dictionary = frame.apply_confirmed_inventory_drop(owner,profile,"q_one",{"container":"bag","owner":profile,"slot":0},service.revision(),21,Vector2.RIGHT)
	assert_bool(invalid_q.get("ok",false)).is_false()
	assert_str(invalid_q.get("code","")).is_equal("DROP_Q_HOTBAR_REQUIRED")
	assert_bool(var_to_bytes(service.snapshot()) == q_before).is_true()
	assert_bool(frame.apply_confirmed_inventory_drop(owner,profile,"q_one",{"container":"hotbar","owner":profile,"slot":0},service.revision(),21,Vector2.RIGHT).get("ok",false)).is_true()
	assert_int(service.snapshot()["ground"].size()).is_equal(1)
	assert_bool((await _advance(owner,301.0)).get("ok",false)).is_true()
	assert_int(service.snapshot()["ground"].size()).is_equal(0)
	assert_int(service.snapshot()["players"][profile]["hotbar"][0]["quantity"]).is_equal(wood_before-1)
	assert_int(service._hot_boundary.statistics()["full_checks"]).is_equal(1)
	# The original complete save path remains active and cold restore stays exact.
	var expected: Dictionary = service.snapshot()
	fixture._assert_receipt(owner,owner._commit_confirmed_save("normal_shutdown"))
	var path: String = owner._save_directory
	# Epoch change invalidates the real lease after durable evidence was captured.
	var final_base: Dictionary = frame._inventory_transaction_base(owner)["state"]
	owner._authority.server_epoch = "session_" + "f".repeat(32)
	var epoch_probe := _probe(service)
	assert_bool(epoch_probe.validate(final_base,expected,service,context).get("ok",false)).is_false()
	assert_bool(epoch_probe.statistics()["invalidated"]).is_true()
	assert_bool(epoch_probe.validate(final_base,expected,service,context).get("ok",false)).is_false()
	fixture._fixtures._dispose_owner(owner)
	var restored: Node = fixture._owner(5,path)
	var loaded: Dictionary = fixture._open(restored)
	assert_bool(loaded.get("ok",false)).is_true()
	assert_bool(restored._restore_authority_state(loaded["state"]).get("ok",false)).is_true()
	assert_bool(var_to_bytes(expected) == var_to_bytes(restored._inventory_owner.snapshot())).is_true()
	fixture._fixtures._dispose_owner(restored)
