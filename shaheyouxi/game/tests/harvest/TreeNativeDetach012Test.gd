extends GdUnitTestSuite
## Isolated native proof only. No Owner alive admission, save, harvest or generation.
const Fixture = preload("res://tests/harvest/TreeTransaction012Test.gd")
const Native = preload("res://scripts/harvest/tree_native012.gd")
const Ledger = preload("res://scripts/harvest/tree_ledger012.gd")
const Session = preload("res://scripts/harvest/tree_world_session012.gd")
const Space = preload("res://scripts/actor/actor_terrain_space.gd")
const Definition = preload("res://scripts/harvest/tree_definition012.gd")
var fixture
var native: RefCounted
func before() -> void:
	fixture=Fixture.new()
	add_child(fixture)
func after_test() -> void:
	if native!=null: native.dispose()
	native=null
	fixture.after_test()
func after() -> void:
	fixture.free()

func test_native_detachment_physics_rollback_and_ticket_reuse_rejection() -> void:
	var f: Dictionary=fixture._joint_fixture()
	assert_bool(not f.is_empty()).is_true()
	if f.is_empty(): return
	var state: Dictionary=f["joint"].snapshot()
	var owner: Node=f["owner"]
	# This standalone native fixture restores only the existing static world.
	# Owner6's alive gate remains untouched; no gameplay Frame runs in this test.
	var base: Dictionary=Session.InventorySession.terrain_state(Session.inventory_state(state))
	var restored: Dictionary=owner._restore_authority_state(base)
	assert_bool(restored.get("ok",false)).is_true()
	if not restored.get("ok",false): return
	var space:=Space.new(owner._terrain_component,owner._terrain_store)
	owner._actor_space=space
	assert_bool(space.configure(owner._world,owner._actor_inputs)).is_true()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var world: Dictionary=state["world_component"]
	var layer: Dictionary=world["layout"]["spawn"]["layer"]
	var key:=Native.Address.key(layer)
	var scope: RefCounted=f["joint_scope"]
	var ledger:=Ledger.new(state["world_id"],state["tree_component"]["seed_decimal"])
	var regions:=Session.regions_for_layer(world,layer)
	var selected: Dictionary={}
	var definition:=Definition.new()
	for bounds in [space._spaces[key]["cell_coverage_bounds"]]:
		for y in range(bounds[1]+2,bounds[1]+bounds[3]-2):
			for x in range(bounds[0]+2,bounds[0]+bounds[2]-2):
				var site:=definition.inspect_fixture_site(layer,[x,y],regions["entries"],regions["protected"])
				if not site.get("ok",false): continue
				var rect: Array=site["collision_rect"]
				var center:=Vector2(rect[0]+rect[2]/2.0,rect[1]+rect[3]/2.0)
				if not Native._rect_covered(space,key,Rect2(rect[0],rect[1],rect[2],rect[3])) or not space.environment_clear(layer,center) or not Native._rect_is_clear(space._spaces[key]["rid"],Rect2(rect[0],rect[1],rect[2],rect[3])): continue
				selected=ledger.plan_fixture_tree(layer,[x,y],regions["entries"],regions["protected"],ledger.token())
				if selected.get("ok",false): break
			if selected.get("ok",false): break
		if selected.get("ok",false): break
	assert_bool(selected.get("ok",false)).is_true()
	if not selected.get("ok",false): return
	var complete: Dictionary=scope.combine(Session.inventory_state(state),selected["state"])
	assert_bool(complete.get("ok",false)).is_true()
	if not complete.get("ok",false): return
	state=complete["state"]
	var tree_state: Dictionary=state["tree_component"]
	var before_world:=var_to_bytes(owner._world.public_component())
	var before_terrain:=var_to_bytes(owner._terrain_component)
	var before_spaces: Dictionary=space._spaces.duplicate(true)
	var before_static_bodies: Array=space._bodies.duplicate()
	var before_static_shapes: Array=space._shapes.duplicate()
	native=Native.new()
	var configured: Dictionary=native.configure(state,scope,space)
	assert_bool(configured.get("ok",false)).is_true()
	if not configured.get("ok",false):
		print("TREE_NATIVE_CONFIG_FAILED ",JSON.stringify(configured))
		return
	assert_bool(native.validate(tree_state)["ok"]).is_false()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var confirmed: Dictionary=native.confirm_initial(tree_state)
	print("TREE_NATIVE_INITIAL ",JSON.stringify(confirmed)," cell=",selected["state"]["trees"][selected["tree_id"]]["cell"])
	assert_bool(confirmed.get("ok",false)).is_true()
	if not confirmed.get("ok",false): return

	assert_bool(ledger.trusted_restore(tree_state).get("ok",false)).is_true()
	var id: String=selected["tree_id"]
	var profile: String=state["profiles"].keys()[0]
	var plan: Dictionary=ledger.plan_completion(id,Ledger.completion_identity(id),profile,state["world_seconds"],ledger.token())
	assert_bool(plan.get("ok",false)).is_true()
	if not plan.get("ok",false): return
	var original_bytes:=var_to_bytes(tree_state)
	var record: Dictionary=native._records[id]
	var original_bodies: Array=native._bodies.duplicate()
	var started: Dictionary=native.begin_detachment(tree_state,plan)
	assert_bool(started.get("ok",false)).is_true()
	if not started.get("ok",false): return
	var ticket: RefCounted=started["ticket"]
	assert_bool(native.validate_detached(ticket,tree_state).get("ok",false)).is_false()
	assert_str(native.validate(tree_state)["code"]).is_equal("TREE_NATIVE_COMPLETION_PENDING")
	assert_bool(native.begin_detachment(tree_state,plan).get("ok",false)).is_false()
	assert_bool(native.begin_rollback(RefCounted.new(),tree_state).get("ok",false)).is_false()
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_bool(native.validate_detached(ticket,tree_state).get("ok",false)).is_true()
	assert_bool(PhysicsServer2D.body_get_space(record["body"])==RID()).is_true()
	assert_bool(native._bodies==original_bodies and var_to_bytes(tree_state)==original_bytes).is_true()
	var changed: Dictionary=plan["state"].duplicate(true)
	changed["revision"]+=1
	assert_bool(native.publication_ready(ticket,tree_state,changed).get("ok",false)).is_false()
	assert_bool(native.begin_rollback(ticket,tree_state).get("ok",false)).is_true()
	assert_bool(native.confirm_rollback(ticket,tree_state).get("ok",false)).is_false()
	assert_bool(native.validate(tree_state).get("ok",false)).is_false()
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_bool(native.confirm_rollback(ticket,tree_state).get("ok",false)).is_true()
	assert_bool(native.validate_actual_actors(tree_state).get("ok",false)).is_true()
	assert_bool(native._bodies==original_bodies and var_to_bytes(tree_state)==original_bytes).is_true()
	assert_bool(native.confirm_rollback(ticket,tree_state).get("ok",false)).is_false()
	started=native.begin_detachment(tree_state,plan)
	assert_bool(started.get("ok",false)).is_true()
	if not started.get("ok",false): return
	var next_ticket: RefCounted=started["ticket"]
	assert_bool(is_same(ticket,next_ticket)).is_false()
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_bool(native.validate_detached(ticket,tree_state).get("ok",false)).is_false()
	assert_bool(native.publication_ready(next_ticket,tree_state,plan["state"]).get("ok",false)).is_true()
	assert_bool(native.publish_detachment(next_ticket,tree_state,plan["state"]).get("ok",false)).is_true()
	assert_bool(native.validate_actual_actors(plan["state"]).get("ok",false)).is_true()
	assert_bool(native._records.is_empty() and native._bodies.size()==original_bodies.size()-1).is_true()
	assert_bool(native.publish_detachment(next_ticket,tree_state,plan["state"]).get("ok",false)).is_false()
	assert_bool(var_to_bytes(owner._world.public_component())==before_world and var_to_bytes(owner._terrain_component)==before_terrain).is_true()
	assert_bool(space._spaces==before_spaces and space._bodies==before_static_bodies and space._shapes==before_static_shapes).is_true()
	print("TREE_NATIVE_DETACH_ROLLBACK_AND_PUBLICATION_ONLY_COMPLETE")
