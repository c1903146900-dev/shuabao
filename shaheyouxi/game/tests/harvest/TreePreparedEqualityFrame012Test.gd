extends GdUnitTestSuite
## Technical state-corruption fixtures, not ordinary harvesting input.
const Fixture = preload("res://tests/harvest/TreeFrameCompletion012Test.gd")
var fixture
var original_files: Dictionary = {}
var source_root: String = ""
func before() -> void:
	fixture = Fixture.new()
	add_child(fixture)
	fixture.before()
func after_test() -> void:
	fixture.after_test()
	for relative in original_files:
		assert_str(FileAccess.get_sha256(source_root.path_join(relative))).is_equal(original_files[relative])
	original_files.clear()
func after() -> void:
	fixture.after()
	fixture.free()
func _opened() -> Dictionary:
	source_root = OS.get_environment("TREE_ATOMIC_FIXTURE_INPUT")
	assert_bool(not source_root.is_empty()).is_true()
	if source_root.is_empty(): return {}
	for relative in ["fixture_index.json","store/main.json","store/auto/auto_01.json","store/world_identity.json"]:
		var digest: String = FileAccess.get_sha256(source_root.path_join(relative))
		assert_int(digest.length()).is_equal(64)
		if digest.length()!=64: return {}
		original_files[relative] = digest
	return await fixture._opened_alive_frame()

func test_real_service_reserve_rejects_extra_field_before_any_reservation() -> void:
	var context: Dictionary = await _opened()
	if context.is_empty(): return
	var server: Node = context["owner"]
	var frame: RefCounted = context["frame"]
	var service: RefCounted = server._inventory_owner
	var data: Dictionary = context["fixture"]
	var before: String = service.boundary_token()
	var authority_before: PackedByteArray = var_to_bytes(server._authority.persistent_state())
	var base: Dictionary = frame._inventory_terrain_base(server)
	assert_bool(base.get("ok",false)).is_true()
	if not base.get("ok",false): return
	var plan: Dictionary = service.plan_fixture_completion(base["state"],data["tree_id"],Fixture.Ledger.completion_identity(data["tree_id"]),data["profile"],before)
	assert_bool(plan.get("ok",false)).is_true()
	if not plan.get("ok",false): return
	# Explicit test-only setup of the original preparing envelope, no Native
	# detach. This reaches the real service reservation comparison, not an RPC.
	frame._tree_pending={"ticket":RefCounted.new(),"service":service,"phase":"preparing","bundle":before,"boundary":frame._lineage.duplicate(true),"runtime":frame._authority_runtime(),"prepared":plan,"native_ticket":null}
	frame._tree_pending.make_read_only()
	var changed: Dictionary = plan.duplicate(true)
	changed["unexpected_completion_field"] = true
	var rejected: Dictionary = service.reserve_fixture_completion(frame,changed)
	assert_str(rejected.get("code","")).is_equal("TREE_OWNER_COMPLETION_PLAN_CHANGED")
	assert_bool(rejected.get("ok",false)).is_false()
	assert_bool(not service._busy and service._completion_reservation.is_empty()).is_true()
	assert_str(service.boundary_token()).is_equal(before)
	assert_bool(var_to_bytes(server._authority.persistent_state())==authority_before).is_true()
	assert_bool(context["space"].validate_actor_frame_boundary().get("ok",false)).is_true()
	frame._tree_pending={}

func test_real_frame_publish_tampered_reservation_is_fatal_without_bundle_change() -> void:
	var context: Dictionary = await _opened()
	if context.is_empty(): return
	var server: Node = context["owner"]
	var frame: RefCounted = context["frame"]
	var service: RefCounted = server._inventory_owner
	var data: Dictionary = context["fixture"]
	var before: String = service.boundary_token()
	var inventory_before: PackedByteArray = var_to_bytes(service._core.snapshot())
	var trees_before: PackedByteArray = var_to_bytes(service._trees.snapshot())
	var authority_before: PackedByteArray = var_to_bytes(server._authority.persistent_state())
	var started: Dictionary = frame.prepare_fixture_tree_completion(server,11,data["tree_id"],Fixture.Ledger.completion_identity(data["tree_id"]))
	assert_bool(started.get("pending",false)).is_true()
	if not started.get("pending",false): return
	# Corrupt the owned reservation deliberately, preserving the original exact
	# Frame/ticket and deep-readonly properties so the comparison must reject.
	var reservation: Dictionary = service._completion_reservation.duplicate(false)
	var changed: Dictionary = reservation["prepared"].duplicate(true)
	changed["unexpected_completion_field"] = true
	Fixture.Ledger.Definition._freeze(changed)
	reservation["prepared"] = changed
	reservation.make_read_only()
	service._completion_reservation = reservation
	await get_tree().physics_frame
	await get_tree().physics_frame
	var rejected: Dictionary = frame.confirm_fixture_tree_completion(started["ticket"])
	assert_bool(rejected.get("fatal",false)).is_true()
	assert_str(rejected.get("code","")).is_equal("TREE_OWNER_COMPLETION_PLAN_CHANGED")
	assert_bool(rejected.get("published",false)).is_false()
	assert_bool(rejected.get("delta_consumed",true)).is_false()
	assert_str(service.boundary_token()).is_equal(before)
	assert_bool(var_to_bytes(service._core.snapshot())==inventory_before).is_true()
	assert_bool(var_to_bytes(service._trees.snapshot())==trees_before).is_true()
	assert_bool(var_to_bytes(server._authority.persistent_state())==authority_before).is_true()
	assert_bool(context["native"]._bodies.is_empty() and context["native"]._shapes.is_empty() and context["space"]._bodies.is_empty() and context["space"]._actors.is_empty() and context["space"]._shapes.is_empty() and context["space"]._spaces.is_empty()).is_true()
	assert_bool(frame.save_confirmed_owner("normal_shutdown").get("fatal",false)).is_true()

func test_actual_frame_checked_prepare_and_original_rollback() -> void:
	var context: Dictionary = await _opened()
	if context.is_empty(): return
	var server: Node = context["owner"]
	var frame: RefCounted = context["frame"]
	var service: RefCounted = server._inventory_owner
	var before: String = service.boundary_token()
	var authority_before: PackedByteArray = var_to_bytes(server._authority.persistent_state())
	var data: Dictionary = context["fixture"]
	var started: Dictionary = frame.prepare_fixture_tree_completion(server,11,data["tree_id"],Fixture.Ledger.completion_identity(data["tree_id"]))
	assert_bool(started.get("pending",false)).is_true()
	if not started.get("pending",false): return
	await get_tree().physics_frame
	await get_tree().physics_frame
	var restoring: Dictionary = frame.begin_fixture_tree_rollback(started["ticket"])
	assert_bool(restoring.get("pending",false)).is_true()
	if not restoring.get("pending",false): return
	await get_tree().physics_frame
	await get_tree().physics_frame
	var restored: Dictionary = frame.confirm_fixture_tree_rollback(started["ticket"])
	assert_bool(restored.get("rollback_confirmed",false)).is_true()
	assert_str(service.boundary_token()).is_equal(before)
	assert_bool(var_to_bytes(server._authority.persistent_state())==authority_before).is_true()
	assert_bool(not service._busy and service._completion_reservation.is_empty() and frame._tree_pending.is_empty()).is_true()
	assert_bool(context["space"].validate_actor_frame_boundary().get("ok",false)).is_true()
