extends GdUnitTestSuite
## Valid real no-listener HOST activation first; object-binding negative probes.
## This does not prove a remote ENet disconnect or positive transport caching.
const Helper = preload("res://tests/harvest/TreeOwnerCompletion012Test.gd")
var helper
func before() -> void:
	helper = Helper.new()
	add_child(helper)
	helper.before()
func after_test() -> void:
	helper.after_test()
func after() -> void:
	helper.after()
	helper.free()
func test_real_activated_host_certificate_rejects_object_epoch_roster_replacement() -> void:
	var context: Dictionary = await helper._active_host()
	if context.is_empty(): return
	var owner: Node = context["owner"]
	var frame: RefCounted = context["frame"]
	assert_bool(owner._tree_live_certificate_matches()).is_true()
	var peer: Variant = owner._peer
	owner._peer = ENetMultiplayerPeer.new()
	assert_bool(owner._tree_live_certificate_matches()).is_false()
	owner._peer = peer
	assert_bool(owner._tree_live_certificate_matches()).is_true()
	var api: Variant = owner._actor_scene_api
	owner._actor_scene_api = SceneMultiplayer.new()
	assert_bool(owner._tree_live_certificate_matches()).is_false()
	owner._actor_scene_api = api
	assert_bool(owner._tree_live_certificate_matches()).is_true()
	var lease: RefCounted = frame._source_lease
	frame._source_lease = RefCounted.new()
	assert_bool(owner._tree_live_certificate_matches()).is_false()
	frame._source_lease = lease
	assert_bool(owner._tree_live_certificate_matches()).is_true()
	var generation: int = owner._live_input_roster[1]["input_generation"]
	owner._live_input_roster[1]["input_generation"] = generation + 1
	assert_bool(owner._tree_live_certificate_matches()).is_false()
	owner._live_input_roster[1]["input_generation"] = generation
	assert_bool(owner._tree_live_certificate_matches()).is_true()
	var certificate: Dictionary = owner._tree_live_certificate
	owner._tree_live_certificate = certificate.duplicate(false)
	assert_bool(owner._tree_live_certificate_matches()).is_false()
	owner._tree_live_certificate = certificate
	assert_bool(owner._live_binding_check().get("ok", false)).is_true()
	assert_bool(owner._freeze_tree_disconnected_transport(1)).is_false()
	assert_bool(owner._tree_disconnect_transports.is_empty()).is_true()
	assert_int(owner._live_input_cutoff).is_equal(-1)
	# SourceLease guard is permanently invalidated by an epoch mismatch.
	var epoch: String = owner._authority.server_epoch
	owner._authority.server_epoch = "session_ffffffffffffffffffffffffffffffff"
	assert_bool(owner._tree_live_certificate_matches()).is_false()
	owner._authority.server_epoch = epoch
	assert_bool(owner._tree_live_certificate_matches()).is_false()
	assert_str(lease.guard().get("code", "")).is_equal("SOURCE_LEASE_INVALID_OR_RELEASED")
	assert_bool(owner._live_binding_check().get("fatal", false)).is_true()
	assert_bool(owner._commit_confirmed_save("normal_shutdown").get("ok", false)).is_false()
	print("TREE_REAL_HOST_CERTIFICATE_BINDING_COMPLETE remote_disconnect=false")
