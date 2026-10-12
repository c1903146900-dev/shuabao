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

func test_real_alive_owner_actor_shape_exception_and_frame_blocking() -> void:
	if not _require_test_identity(): return
	var f: Dictionary=await _alive_state()
	if f.is_empty(): return
	var state: Dictionary=f["state"]
	var owner: Node=support._owner()
	if owner==null: return
	assert_bool(support._open(owner).get("new_world",false)).is_true()
	var restored: Dictionary=owner._restore_authority_state(state)
	assert_bool(restored.get("ok",false)).is_true()
	if not restored.get("ok",false): return
	assert_bool(owner._actor_space==null and owner._bootstrap_frame==null).is_true()
	var started: bool=await owner._prepare_runtime_before_listen()
	print("TREE_ALIVE_STARTED ",started)
	assert_bool(started).is_true()
	if not started: return
	assert_bool(owner._actor_space.get_script()==TreeSpace).is_true()
	var frame: RefCounted=owner._bootstrap_frame
	var space: RefCounted=owner._actor_space
	var native: RefCounted=space._tree_native
	var tree_state: Dictionary=owner._inventory_owner.tree_snapshot()
	assert_bool(space.validate_actor_frame_boundary().get("ok",false)).is_true()
	var profile: String=f["profile"]
	var hello: Dictionary={"network_protocol_version":owner._authority.protocol_version,"catalogue_sha256":owner._authority.catalogue_hash,"display_name":state["profiles"][profile]["display_name"],"resume_profile_id":profile,"resume_secret":Support.resume_secret()}
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
	var body: RID=space._actors[f["actor_id"]]["environment_body"]
	var shape: RID=space._actors[f["actor_id"]]["circle"]
	var record: Dictionary=native._records[f["tree_id"]]
	var tree_body: RID=record["body"]
	var actors_checked: Dictionary=native.validate_actual_actors(tree_state)
	assert_bool(actors_checked.get("ok",false)).is_true()
	if not actors_checked.get("ok",false): return
	assert_int(actors_checked["actor_count"]).is_equal(1)
	PhysicsServer2D.shape_set_data(shape,space._half+0.1)
	await get_tree().physics_frame
	assert_bool(native.validate_actual_actors(tree_state).get("ok",false)).is_false()
	PhysicsServer2D.shape_set_data(shape,space._half)
	await get_tree().physics_frame
	assert_bool(space.validate_actor_frame_boundary().get("ok",false)).is_true()
	var before: Vector2=ActorState.vector(owner._actor_model.actor_record(f["actor_id"])["position"])
	var parameters:=PhysicsTestMotionParameters2D.new()
	parameters.from=Transform2D(0.0,before)
	parameters.motion=Vector2.UP*1.5
	parameters.margin=0.001
	var collision:=PhysicsTestMotionResult2D.new()
	assert_bool(PhysicsServer2D.body_test_motion(body,parameters,collision)).is_true()
	assert_bool(collision.get_collider_rid()==tree_body).is_true()
	var request: Dictionary={"kind":"actor_input","sequence":1,"move":[0,-1],"aim":[0.0,-1.0],"action":"none","phase":"none"}
	var captured: Dictionary=frame.capture_envelope(11,request)
	assert_bool(captured.get("ok",false)).is_true()
	if not captured.get("ok",false): return
	var submitted: Dictionary=frame.submit(0.25,[captured["envelope"]])
	assert_bool(submitted.get("pending",false)).is_true()
	if not submitted.get("pending",false): return
	await get_tree().physics_frame
	var confirmed: Dictionary=frame.confirm(submitted["ticket"])
	assert_bool(confirmed.get("confirmed",false)).is_true()
	if not confirmed.get("confirmed",false): return
	var position: Array=owner._actor_model.actor_record(f["actor_id"])["position"]
	print("TREE_ALIVE_REAL_FRAME ",before," -> ",position)
	assert_bool(position[1]<before.y and position[1]>record["rect"].end.y).is_true()
	assert_bool(space.environment_clear(tree_state["trees"][f["tree_id"]]["layer"],Vector2(position[0],position[1]))).is_true()
	assert_bool(var_to_bytes(owner._inventory_owner.tree_snapshot())==var_to_bytes(tree_state)).is_true()
	# Probe still passes, but a per-real-actor collision exception must stop Frame.
	PhysicsServer2D.body_add_collision_exception(body,tree_body)
	await get_tree().physics_frame
	assert_bool(native.validate(tree_state).get("ok",false)).is_true()
	assert_str(native.validate_actual_actors(tree_state)["code"]).is_equal("TREE_NATIVE_ACTOR_DIRECTION_NOT_BLOCKED")
	var clock_before: float=owner._authority.world_seconds
	var rejected: Dictionary=frame.submit(1.0/60.0,[])
	print("TREE_ALIVE_REAL_ACTOR_EXCEPTION ",JSON.stringify(rejected))
	assert_bool(not rejected.get("pending",false) and not frame.fatal_error.is_empty()).is_true()
	assert_float(owner._authority.world_seconds).is_equal(clock_before)
	# Frame._fatal already disposes native actor/space/tree RIDs. Do not issue
	# another physics call against those stale handles. Prove owned cleanup.
	assert_bool(space._actors.is_empty() and space._bodies.is_empty() and space._shapes.is_empty() and space._spaces.is_empty()).is_true()
	assert_bool(native._bodies.is_empty() and native._shapes.is_empty()).is_true()

func _require_test_identity() -> bool:
	var available: bool = not Support.resume_secret().is_empty()
	assert_bool(available).is_true()
	return available
