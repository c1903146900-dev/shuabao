extends "res://tests/harvest/TreeFrameCompletion012Test.gd"
## Each method is a separate real-owner gate, using the verified complete Store
## fixture. No socket/GUI, direct private completion, or automatic harvesting.
const GroundCore = preload("res://scripts/inventory/inventory_core012.gd")

func _ground_runtime() -> Dictionary:
	assert_bool(not OS.get_environment("TREE_ATOMIC_FIXTURE_INPUT").is_empty()).is_true()
	if OS.get_environment("TREE_ATOMIC_FIXTURE_INPUT").is_empty(): return {}
	var f: Dictionary = await _opened_alive_frame()
	if f.is_empty(): return {}
	var frame: RefCounted = f["frame"]
	var result: Dictionary = frame.advance_confirmed_ground(f["owner"])
	assert_bool(result.get("ok", false)).is_true()
	if not result.get("ok", false): return {}
	assert_int(frame._ground_full_checks).is_equal(1)
	assert_int(frame._ground_hot_checks).is_equal(0)
	assert_bool(frame._ground_pending.is_empty() and frame._ground_provisional.is_empty()).is_true()
	assert_bool(not frame._ground_certificate.is_empty()).is_true()
	assert_bool(frame._ground_hot.certificate_matches(frame, frame._ground_certificate)).is_true()
	assert_bool(is_same(frame._ground_certificate["published_bundle"], f["owner"]._inventory_owner._bundle)).is_true()
	return f

func test_actual_frame_tick_reuses_proven_roots_for_pre_drop_schema1() -> void:
	var f: Dictionary = await _ground_runtime()
	if f.is_empty(): return
	var frame: RefCounted = f["frame"]
	var server: Node = f["owner"]
	var service: RefCounted = server._inventory_owner
	assert_int(service.snapshot()["schema_version"]).is_equal(1)
	assert_bool(service.snapshot().has("ground_clock")).is_false()
	var original_inventory: PackedByteArray = var_to_bytes(service.snapshot())
	var original_trees: PackedByteArray = var_to_bytes(service.tree_snapshot())
	var clock: float = server._authority.world_seconds
	var metrics: Dictionary = frame._ground_certificate["metrics"]
	var tick: Dictionary = frame.submit(0.125, [])
	assert_bool(tick.get("pending", false)).is_true()
	if not tick.get("pending", false): return
	await get_tree().physics_frame
	assert_bool(frame.confirm(tick["ticket"]).get("confirmed", false)).is_true()
	assert_float(server._authority.world_seconds).is_equal(clock + 0.125)
	var started: int = Time.get_ticks_usec()
	var advanced: Dictionary = frame.advance_confirmed_ground(server)
	var hot_elapsed: int = Time.get_ticks_usec() - started
	assert_bool(advanced.get("ok", false)).is_true()
	assert_int(frame._ground_full_checks).is_equal(1)
	assert_int(frame._ground_hot_checks).is_equal(1)
	assert_bool(is_same(metrics, frame._ground_certificate["metrics"])).is_true()
	assert_bool(var_to_bytes(service.snapshot()) == original_inventory).is_true()
	assert_bool(service.snapshot().has("ground_clock")).is_false()
	assert_bool(var_to_bytes(service.tree_snapshot()) == original_trees).is_true()
	assert_bool(frame._ground_pending.is_empty() and frame._ground_provisional.is_empty() and not service._busy).is_true()
	# Independent original full admission still judges the actual published root.
	var base: Dictionary = frame._inventory_transaction_base(server)["state"]
	var full_started: int = Time.get_ticks_usec()
	assert_bool(service.combine_for_save(base).get("ok", false)).is_true()
	var full_elapsed: int = Time.get_ticks_usec() - full_started
	print("TREE_GROUND_REAL_FRAME_HIT ", JSON.stringify({"hot_calls": frame._ground_hot_checks, "full_calls": frame._ground_full_checks, "hot_elapsed_usec": hot_elapsed, "full_recheck_usec": full_elapsed, "normal_save": false, "pre_drop_schema1": true, "schema3_ground_clock_tested": false}))

func test_unknown_ticket_direct_service_call_cannot_publish_or_leave_busy() -> void:
	var f: Dictionary = await _ground_runtime()
	if f.is_empty(): return
	var frame: RefCounted = f["frame"]
	var server: Node = f["owner"]
	var service: RefCounted = server._inventory_owner
	var token: String = service.boundary_token()
	var base: Dictionary = frame._inventory_transaction_base(server)["state"]
	var fake := RefCounted.new()
	var result: Dictionary = service.advance_ground(base, server._authority.world_seconds, server._actor_inputs.parameter("pickup_range_cells"), server._actor_inputs.parameter("pickup_attraction_speed_cells_per_second"), {"frame": frame, "lease": frame._source_lease, "ground_ticket": fake})
	assert_bool(result.get("ok", false)).is_false()
	assert_str(result.get("code", "")).is_equal("TREE_GROUND_TICKET_OR_PHASE")
	assert_str(service.boundary_token()).is_equal(token)
	assert_bool(not service._busy and frame._ground_pending.is_empty()).is_true()
	assert_bool(frame.advance_confirmed_ground(server).get("ok", false)).is_true()
	assert_int(frame._ground_hot_checks).is_equal(1)

func test_unilateral_certificate_clear_is_sticky_identity_failure() -> void:
	var f: Dictionary = await _ground_runtime()
	if f.is_empty(): return
	var frame: RefCounted = f["frame"]
	var server: Node = f["owner"]
	var token: String = server._inventory_owner.boundary_token()
	var proof: Dictionary = frame._ground_certificate
	var bundle: Dictionary = frame._ground_cached_bundle
	frame._ground_certificate = {} # Technical corruption, not a supported API.
	var rejected: Dictionary = frame.advance_confirmed_ground(server)
	assert_str(rejected.get("code", "")).is_equal("TREE_GROUND_CERTIFICATE_ASSOCIATION_CHANGED")
	assert_bool(frame._ground_invalidated).is_true()
	assert_bool(frame._ground_certificate.is_empty() and frame._ground_pending.is_empty()).is_true()
	frame._ground_certificate = proof
	frame._ground_cached_bundle = bundle
	assert_bool(frame._ground_hot.bind_certificate(frame, proof)).is_true()
	assert_str(frame.advance_confirmed_ground(server).get("code", "")).is_equal("TREE_GROUND_RUNTIME_INVALIDATED")
	assert_str(server._inventory_owner.boundary_token()).is_equal(token)

func test_unilateral_last_bundle_clear_cannot_impersonate_other_business() -> void:
	var f: Dictionary = await _ground_runtime()
	if f.is_empty(): return
	var frame: RefCounted = f["frame"]
	var token: String = f["owner"]._inventory_owner.boundary_token()
	frame._ground_cached_bundle = {}
	var rejected: Dictionary = frame.advance_confirmed_ground(f["owner"])
	assert_str(rejected.get("code", "")).is_equal("TREE_GROUND_CERTIFICATE_ASSOCIATION_CHANGED")
	assert_bool(frame._ground_invalidated and frame._ground_pending.is_empty()).is_true()
	assert_str(f["owner"]._inventory_owner.boundary_token()).is_equal(token)

func test_encoder_configuration_failure_retires_ticket_and_cannot_self_repair() -> void:
	var f: Dictionary = await _ground_runtime()
	if f.is_empty(): return
	var frame: RefCounted = f["frame"]
	var service: RefCounted = f["owner"]._inventory_owner
	var token: String = service.boundary_token()
	var encoder: RefCounted = service._contract._budget_store
	encoder._schema_version = 7
	var rejected: Dictionary = frame.advance_confirmed_ground(f["owner"])
	assert_bool(rejected.get("ok", false)).is_false()
	assert_bool(frame._ground_pending.is_empty() and frame._ground_provisional.is_empty() and not service._busy).is_true()
	assert_bool(frame._ground_invalidated).is_true()
	encoder._schema_version = 5
	assert_str(frame.advance_confirmed_ground(f["owner"]).get("code", "")).is_equal("TREE_GROUND_RUNTIME_INVALIDATED")
	assert_str(service.boundary_token()).is_equal(token)
