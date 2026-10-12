extends GdUnitTestSuite
## Real Owner6 + Frame presence and movement; no sockets, GUI or harvesting yet.
const Support = preload("res://tests/harvest/TreeOwnerFrame012Test.gd")
const Session = preload("res://scripts/harvest/tree_world_session012.gd")
const Ledger = preload("res://scripts/harvest/tree_ledger012.gd")
const Definition = preload("res://scripts/harvest/tree_definition012.gd")
const Native = preload("res://scripts/harvest/tree_native012.gd")
const StaticSpace = preload("res://scripts/actor/actor_terrain_space.gd")
const TreeSpace = preload("res://scripts/harvest/tree_terrain_space012.gd")
const ActorState = preload("res://scripts/actor/actor_state.gd")
var support
func before() -> void:
	support=Support.new()
	add_child(support)
	support.before()
func after_test() -> void:
	support.after_test()
func after() -> void:
	support.after()
	support.free()

func _alive_state() -> Dictionary:
	if not _require_test_identity(): return {}
	var f: Dictionary=support.fixture._joint_fixture()
	if f.is_empty(): return {}
	var state: Dictionary=f["joint"].snapshot()
	var owner: Node=f["owner"]
	var base:=Session.InventorySession.terrain_state(Session.inventory_state(state))
	var restored: Dictionary=owner._restore_authority_state(base)
	assert_bool(restored.get("ok",false)).is_true()
	if not restored.get("ok",false): return {}
	var space:=StaticSpace.new(owner._terrain_component,owner._terrain_store)
	owner._actor_space=space
	assert_bool(space.configure(owner._world,owner._actor_inputs)).is_true()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var world: Dictionary=state["world_component"]
	var layer: Dictionary=world["layout"]["spawn"]["layer"]
	var key:=Native.Address.key(layer)
	var ledger:=Ledger.new(state["world_id"],state["tree_component"]["seed_decimal"])
	var scope: RefCounted=f["joint_scope"]
	var regions:=Session.regions_for_layer(world,layer)
	var definition:=Definition.new()
	var bounds: Array=space._spaces[key]["cell_coverage_bounds"]
	var selected: Dictionary={}
	var actor_position:=Vector2.ZERO
	for y in range(bounds[1]+2,bounds[1]+bounds[3]-2):
		for x in range(bounds[0]+2,bounds[0]+bounds[2]-2):
			var site:=definition.inspect_fixture_site(layer,[x,y],regions["entries"],regions["protected"])
			if not site.get("ok",false): continue
			var r: Array=site["collision_rect"]
			var rect:=Rect2(r[0],r[1],r[2],r[3])
			var position: Vector2=rect.get_center()+Vector2.DOWN*(rect.size.y/2.0+space._half+0.4)
			if not Native._rect_covered(space,key,rect) or not Native._rect_is_clear(space._spaces[key]["rid"],rect) or not space.environment_clear(layer,position) or not space._covered_sweep(key,position,Vector2.UP*2.0): continue
			selected=ledger.plan_fixture_tree(layer,[x,y],regions["entries"],regions["protected"],ledger.token())
			if selected.get("ok",false):
				actor_position=position
				break
		if selected.get("ok",false): break
	assert_bool(selected.get("ok",false)).is_true()
	if not selected.get("ok",false): return {}
	var profile: String=f["profile"]
	var actor_id: String=state["profiles"][profile]["player_instance_id"]
	state["profiles"][profile]["secret_hash"]=Support.resume_secret().sha256_text()
	# Explicit saved-position fixture, fully revalidated; not a normal spawn rule.
	state["actor_component"]["actors"][actor_id]["position"]=[float(actor_position.x),float(actor_position.y)]
	var combined: Dictionary=scope.combine(Session.inventory_state(state),selected["state"])
	assert_bool(combined.get("ok",false)).is_true()
	if not combined.get("ok",false): return {}
	var result: Dictionary={"state":combined["state"],"tree_id":selected["tree_id"],"profile":profile,"actor_id":actor_id}
	support.fixture._dispose_owner(owner)
	return result

func _opened_alive_frame(peer_id: int = 11) -> Dictionary:
	if not _require_test_identity(): return {}
	_phase("fixture_begin")
	var f: Dictionary
	var owner: Node
	if OS.get_environment("TREE_ATOMIC_FIXTURE_INPUT").is_empty():
		f=await _alive_state()
		if f.is_empty(): return {}
		owner=support._owner()
		if owner==null: return {}
		assert_bool(support._open(owner).get("new_world",false)).is_true()
	else:
		f=_read_complete_store_fixture()
		if f.is_empty(): return {}
		owner=f["owner"]
	if peer_id == 1:
		assert_str(f["state"]["profiles"][f["profile"]]["role"]).is_equal("HOST")
		if f["state"]["profiles"][f["profile"]]["role"] != "HOST": return {}
		owner._mode = "host" # Explicit no-socket host fixture before Owner context capture.
	var state: Dictionary=f["state"]
	_phase("fixture_loaded")
	var restored: Dictionary=owner._restore_authority_state(state)
	_phase("actual_owner_restored")
	assert_bool(restored.get("ok",false)).is_true()
	if not restored.get("ok",false): return {}
	assert_bool(owner._actor_space==null and owner._bootstrap_frame==null).is_true()
	var started: bool=await owner._prepare_runtime_before_listen()
	_phase("native_runtime_started")
	print("TREE_ALIVE_STARTED ",started)
	assert_bool(started).is_true()
	if not started: return {}
	assert_bool(owner._actor_space.get_script()==TreeSpace).is_true()
	var frame: RefCounted=owner._bootstrap_frame
	var space: RefCounted=owner._actor_space
	var native: RefCounted=space._tree_native
	var tree_state: Dictionary=owner._inventory_owner.tree_snapshot()
	assert_bool(space.validate_actor_frame_boundary().get("ok",false)).is_true()
	var profile: String=f["profile"]
	var hello: Dictionary={"network_protocol_version":owner._authority.protocol_version,"catalogue_sha256":owner._authority.catalogue_hash,"display_name":state["profiles"][profile]["display_name"],"resume_profile_id":profile,"resume_secret":Support.resume_secret()}
	var prepared: Dictionary=frame.prepare_bootstrap_presence(peer_id,hello,peer_id == 1)
	assert_bool(prepared.get("ok",false)).is_true()
	if not prepared.get("ok",false): return {}
	var committed: Dictionary=frame.commit_bootstrap_presence(prepared["ticket"])
	assert_bool(committed.get("pending",false)).is_true()
	if not committed.get("pending",false): return {}
	await get_tree().physics_frame
	var presence: Dictionary=frame.confirm_bootstrap_presence(prepared["ticket"])
	assert_bool(presence.get("confirmed",false)).is_true()
	if not presence.get("confirmed",false): return {}
	_phase("real_presence_confirmed")
	return {"fixture":f,"owner":owner,"frame":frame,"space":space,"native":native,"trees":tree_state}

func test_pending_blocks_frame_save_second_completion_and_rollback_restores_exact() -> void:
	var context: Dictionary=await _opened_alive_frame()
	if context.is_empty(): return
	var f: Dictionary=context["fixture"]
	var owner: Node=context["owner"]
	var frame: RefCounted=context["frame"]
	var service: RefCounted=owner._inventory_owner
	var before: String=service.boundary_token()
	var state_before:=var_to_bytes(owner._authority.persistent_state())
	var event:=Ledger.completion_identity(f["tree_id"])
	_phase("completion_prepare_begin")
	var prepared: Dictionary=frame.prepare_fixture_tree_completion(owner,11,f["tree_id"],event)
	_phase("completion_prepare_end")
	print("TREE_COMPLETION_PREPARED ",prepared.get("ok",false)," ",prepared.get("code",""))
	assert_bool(prepared.get("ok",false)).is_true()
	if not prepared.get("ok",false): return
	var ticket: RefCounted=prepared["ticket"]
	assert_bool(frame.submit(0.125,[]).get("pending",false)).is_true()
	assert_bool(frame.save_confirmed_owner("normal_shutdown").get("pending",false)).is_true()
	assert_bool(frame.prepare_fixture_tree_completion(owner,11,f["tree_id"],event).get("pending",false)).is_true()
	assert_bool(service.combine_for_save(frame._last_state).get("ok",false)).is_false()
	assert_bool(service.apply_left({},f["profile"],{},0,1).get("ok",false)).is_false()
	assert_str(service.boundary_token()).is_equal(before)
	assert_bool(var_to_bytes(owner._authority.persistent_state())==state_before).is_true()
	assert_bool(frame.confirm_fixture_tree_completion(RefCounted.new()).get("ok",false)).is_false()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var rollback: Dictionary=frame.begin_fixture_tree_rollback(ticket)
	print("TREE_COMPLETION_ROLLBACK_BEGIN ",JSON.stringify(rollback))
	assert_bool(rollback.get("pending",false)).is_true()
	if not rollback.get("pending",false): return
	assert_bool(frame.submit(0.125,[]).get("pending",false)).is_true()
	assert_bool(frame.save_confirmed_owner("normal_shutdown").get("pending",false)).is_true()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var confirmed: Dictionary=frame.confirm_fixture_tree_rollback(ticket)
	print("TREE_COMPLETION_ROLLBACK_CONFIRMED ",JSON.stringify(confirmed))
	assert_bool(confirmed.get("rollback_confirmed",false)).is_true()
	assert_str(service.boundary_token()).is_equal(before)
	assert_bool(var_to_bytes(owner._authority.persistent_state())==state_before).is_true()
	assert_bool(frame.public_snapshot().get("ok",false)).is_true()
	assert_bool(context["space"].validate_actor_frame_boundary().get("ok",false)).is_true()
	assert_bool(frame.confirm_fixture_tree_rollback(ticket).get("ok",false)).is_false()

func test_confirmed_native_deletion_single_bundle_drops_and_replay() -> void:
	var context: Dictionary=await _opened_alive_frame()
	if context.is_empty(): return
	var f: Dictionary=context["fixture"]
	var owner: Node=context["owner"]
	var frame: RefCounted=context["frame"]
	var service: RefCounted=owner._inventory_owner
	var before: Dictionary=service.snapshot()
	var event:=Ledger.completion_identity(f["tree_id"])
	_phase("completion_prepare_begin")
	var prepared: Dictionary=frame.prepare_fixture_tree_completion(owner,11,f["tree_id"],event)
	_phase("completion_prepare_end")
	assert_bool(prepared.get("ok",false)).is_true()
	if not prepared.get("ok",false): return
	await get_tree().physics_frame
	await get_tree().physics_frame
	_phase("completion_confirm_begin")
	var confirmed: Dictionary=frame.confirm_fixture_tree_completion(prepared["ticket"])
	_phase("completion_confirm_end")
	print("TREE_COMPLETION_PUBLISHED ",JSON.stringify(confirmed))
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
	var token: String=service.boundary_token()
	_phase("replay_begin")
	var replay: Dictionary=frame.prepare_fixture_tree_completion(owner,11,f["tree_id"],event)
	_phase("replay_end")
	assert_bool(replay.get("ok",false) and replay.get("replay",false)).is_true()
	assert_str(service.boundary_token()).is_equal(token)
	assert_bool(frame.confirm_fixture_tree_completion(prepared["ticket"]).get("ok",false)).is_false()
	assert_bool(var_to_bytes(service.snapshot())==var_to_bytes(after)).is_true()

func test_detached_actor_tamper_fatal_preserves_logical_root_and_cleans_native() -> void:
	await _fatal_pending_case(false)

func test_failed_native_rollback_fatal_never_reports_restored() -> void:
	await _fatal_pending_case(true)

func _fatal_pending_case(during_rollback: bool) -> void:
	var context: Dictionary=await _opened_alive_frame()
	if context.is_empty(): return
	var f: Dictionary=context["fixture"]
	var owner: Node=context["owner"]
	var frame: RefCounted=context["frame"]
	var service: RefCounted=owner._inventory_owner
	var native: RefCounted=context["native"]
	var space: RefCounted=context["space"]
	var token: String=service.boundary_token()
	var clock_before: float=owner._authority.world_seconds
	var prepared: Dictionary=frame.prepare_fixture_tree_completion(owner,11,f["tree_id"],Ledger.completion_identity(f["tree_id"]))
	assert_bool(prepared.get("ok",false)).is_true()
	if not prepared.get("ok",false): return
	assert_bool(frame.confirm_fixture_tree_completion(prepared["ticket"]).get("pending",false)).is_true()
	await get_tree().physics_frame
	await get_tree().physics_frame
	if during_rollback:
		var started: Dictionary=frame.begin_fixture_tree_rollback(prepared["ticket"])
		assert_bool(started.get("pending",false)).is_true()
		if not started.get("pending",false): return
		PhysicsServer2D.body_set_collision_layer(native._records[f["tree_id"]]["body"],0)
	else:
		PhysicsServer2D.shape_set_data(space._actors[f["actor_id"]]["circle"],space._half+0.1)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var rejected: Dictionary=frame.confirm_fixture_tree_rollback(prepared["ticket"]) if during_rollback else frame.confirm_fixture_tree_completion(prepared["ticket"])
	print("TREE_COMPLETION_FATAL ",during_rollback," ",JSON.stringify(rejected))
	assert_bool(rejected.get("fatal",false)).is_true()
	assert_bool(not rejected.get("rollback_confirmed",false) and not rejected.get("save_ready",false)).is_true()
	assert_float(owner._authority.world_seconds).is_equal(clock_before)
	assert_str(service.boundary_token()).is_equal(token)
	assert_bool(native._bodies.is_empty() and native._shapes.is_empty() and space._actors.is_empty()).is_true()
	assert_bool(frame.save_confirmed_owner("normal_shutdown").get("fatal",false)).is_true()

func _phase(label: String) -> void:
	print("TREE_ATOMIC_PHASE ",label," wall_msec=",Time.get_ticks_msec())

func _read_complete_store_fixture() -> Dictionary:
	var root:=OS.get_environment("TREE_ATOMIC_FIXTURE_INPUT")
	var source:=OS.get_environment("TREE_ATOMIC_STAGE_SHA")
	if not root.is_absolute_path() or source.length()!=64:
		assert_bool(false).is_true()
		return {}
	var index: Variant=JSON.parse_string(FileAccess.get_file_as_string(root.path_join("fixture_index.json")))
	if not index is Dictionary or index.get("kind")!="isolated_tree_completion_fixture_v1" or index.get("source_stage_sha256")!=source or not index.get("files") is Dictionary:
		assert_bool(false).is_true()
		return {}
	var path:=root.path_join("store")
	for relative in ["main.json","auto/auto_01.json","world_identity.json"]:
		if not index["files"].get(relative) is String or FileAccess.get_sha256(path.path_join(relative))!=index["files"][relative]:
			assert_bool(false).is_true()
			return {}
	var owner: Node=support._owner(path)
	if owner==null: return {}
	var loaded: Dictionary=support._open(owner)
	_phase("real_store_load_latest")
	assert_bool(loaded.get("ok",false) and not loaded.get("new_world",false)).is_true()
	if not loaded.get("ok",false) or not loaded.has("state"): return {}
	assert_str(loaded.get("loaded_from","")).is_equal("main")
	if loaded.get("loaded_from")!="main": return {}
	var envelope: Variant=JSON.parse_string(FileAccess.get_file_as_string(path.path_join("main.json")))
	if not envelope is Dictionary or not envelope.get("payload_json") is String:
		assert_bool(false).is_true()
		return {}
	var decoded: Dictionary=Support.Codec.decode(JSON.parse_string(envelope["payload_json"]))
	if not decoded.get("ok",false) or not decoded.get("value") is Dictionary:
		assert_bool(false).is_true()
		return {}
	assert_str(index.get("reason","")).is_equal("isolated_tree_completion_fixture")
	assert_str(decoded["value"].get("reason","")).is_equal(index.get("reason",""))
	assert_int(loaded.get("sequence",-1)).is_equal(1)
	assert_int(decoded["value"].get("sequence",-1)).is_equal(1)
	assert_bool(index.get("sequence") == 1).is_true()
	if decoded["value"].get("reason")!="isolated_tree_completion_fixture" or loaded.get("sequence")!=1 or decoded["value"].get("sequence")!=1 or index.get("sequence")!=1: return {}
	var state: Dictionary=loaded["state"]
	assert_str(Ledger.exact_token(state)).is_equal(index.get("state_token",""))
	if Ledger.exact_token(state)!=index.get("state_token",""): return {}
	assert_str(state["world_id"]).is_equal(index.get("world_id",""))
	if not state["profiles"].has(index.get("profile")) or not state["tree_component"]["trees"].has(index.get("tree_id")):
		assert_bool(false).is_true()
		return {}
	assert_str(state["profiles"][index["profile"]]["player_instance_id"]).is_equal(index.get("actor_id",""))
	assert_str(state["tree_component"]["trees"][index["tree_id"]]["status"]).is_equal("alive")
	for relative in ["main.json","auto/auto_01.json","world_identity.json"]:
		assert_str(FileAccess.get_sha256(path.path_join(relative))).is_equal(index["files"][relative])
	return {"state":state,"owner":owner,"tree_id":index["tree_id"],"profile":index["profile"],"actor_id":index["actor_id"]}

func _require_test_identity() -> bool:
	var available: bool = not Support.resume_secret().is_empty()
	assert_bool(available).is_true()
	return available
