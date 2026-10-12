extends GdUnitTestSuite
## Detached semantic-slice unit tests, NOT full world/admission fixtures.
## No Owner, Frame, SceneTree, world generator, save/load, native peer or files
## are constructed/written. Only the original rule files are read by real Core
## and Ledger/Definition constructors. Their rules and methods are not replaced.
## The minimal world projection below is deliberately NOT a static-world proof.
## Calling the private helper here tests its semantic contract in isolation and
## never authorizes production calls without its documented prerequisites.
const TreeSession = preload("res://scripts/harvest/tree_world_session012.gd")
const InventorySession = preload("res://scripts/inventory/inventory_world_session012.gd")
const Core = preload("res://scripts/inventory/inventory_core012.gd")
const Ledger = preload("res://scripts/harvest/tree_ledger012.gd")
const Outputs = preload("res://scripts/harvest/tree_ground012.gd")
const Address = preload("res://scripts/world/spatial_address.gd")
const WORLD := "world_11111111111111111111111111111111"
const PLAYER := "player_11111111111111111111111111111111"
const OTHER := "player_22222222222222222222222222222222"
const SEED := "17"
const COMPLETED := 10.0

func _fixture(tree_body: String = "body_0001") -> Dictionary:
	var core := Core.new(WORLD,"v2_tree_seed")
	var ledger := Ledger.new(WORLD,SEED)
	assert_bool(core.ready and ledger.ready).is_true()
	assert_bool(core.trusted_create_player(PLAYER)["ok"]).is_true()
	var tree_layer: Dictionary=Address.layer(WORLD,tree_body,"surface",0)
	var tree: Dictionary=ledger.plan_fixture_tree(tree_layer,[10,20],[],[],ledger.token())
	assert_bool(tree["ok"]).is_true()
	assert_bool(ledger.trusted_restore(tree["state"])["ok"]).is_true()
	var event: String=Ledger.completion_identity(tree["tree_id"])
	var completion: Dictionary=ledger.plan_completion(tree["tree_id"],event,PLAYER,COMPLETED,ledger.token())
	assert_bool(completion["ok"]).is_true()
	var ground: Dictionary=Outputs.prepare_outputs(core,ledger,completion,COMPLETED)
	assert_bool(ground["ok"]).is_true()
	# Bind ONLY dependencies read by the semantic slice. Keep ready=false and
	# leave inner/authority/budget unset so full admission is demonstrably closed.
	var session := TreeSession.new(null,null,SEED)
	session._world_id=WORLD
	session._seed_decimal=SEED
	session._ledger=ledger
	var profiles: Dictionary={}
	profiles[PLAYER]={}
	var state: Dictionary={
		"world_id":WORLD,"world_seconds":COMPLETED,"revision":0,
		"next_auto_due_world_seconds":300.0,"profiles":profiles,
		"world_component":{
			"layout":{"seed_decimal":SEED,"body":{"radius_cells":64},
				"spawn":{"layer":Address.layer(WORLD,"body_0001","surface",0)},
				"connections":[]},"prefab_instances":[]},
		"actor_component":{},"terrain_component":{},
		"inventory_contract":InventorySession.CONTRACT,"inventory_component":ground["state"],
		"tree_contract":TreeSession.CONTRACT,"tree_component":completion["state"]}
	var wood_id := ""
	for id in state["inventory_component"]["ground"]:
		if state["inventory_component"]["ground"][id]["stack"]["content_id"]=="mucai": wood_id=id
	assert_bool(not wood_id.is_empty()).is_true()
	return {"core":core,"ledger":ledger,"session":session,"state":state,
		"tree_id":tree["tree_id"],"event":event,"wood_id":wood_id}

func _expect(f: Dictionary, code: String = "") -> void:
	var state: Dictionary=f["state"]
	# Real shape, Core and Ledger checks guard every case. These do not claim
	# that the minimal world/actor/terrain/profile projection passed inner5.
	assert_bool(Core._fields(state,InventorySession.FIELDS+TreeSession.EXTRA_FIELDS)).is_true()
	assert_bool(f["core"].validate_snapshot(state["inventory_component"])["ok"]).is_true()
	assert_bool(f["ledger"].validate_snapshot(state["tree_component"])["ok"]).is_true()
	var before := var_to_bytes(state)
	var result: Dictionary=f["session"]._validate_tree_dynamic_state(state)
	var expected: Dictionary={"ok":true,"fixture_only":true} if code.is_empty() else {"ok":false,"code":code,"recoverable_corruption":false}
	assert_bool(result==expected).is_true()
	assert_bool(var_to_bytes(state)==before).is_true()

func _wood(f: Dictionary) -> Dictionary:
	return f["state"]["inventory_component"]["ground"][f["wood_id"]]

func _completion(f: Dictionary) -> Dictionary:
	return f["state"]["tree_component"]["completions"][f["event"]]

func _elapsed(f: Dictionary, seconds: float) -> void:
	f["state"]["world_seconds"]=COMPLETED+seconds
	f["state"]["inventory_component"]["ground_clock"]=COMPLETED+seconds
	for drop in f["state"]["inventory_component"]["ground"].values():
		for lot in drop["lots"]:
			lot["remaining_lifetime"]=maxf(0.0,300.0-seconds)
			lot["remaining_delay"]=maxf(0.0,0.5-seconds)

func _entry(f: Dictionary, rectangle: Array, layer: Dictionary = {}) -> void:
	var effective: Dictionary=Address.layer(WORLD,"body_0001","surface",0) if layer.is_empty() else layer
	f["state"]["world_component"]["layout"]["connections"].append({"endpoints":[{"layer":effective}],"safety_rect":rectangle})

func _duplicate_wood(f: Dictionary, quantity: int) -> Dictionary:
	var record: Dictionary=_wood(f).duplicate(true)
	record["stack"]["quantity"]=quantity
	record["lots"][0]["quantity"]=quantity
	f["state"]["inventory_component"]["ground"]["drop_dynamic_second"]=record
	f["state"]["inventory_component"]["ground_serial"]+=1
	return record

func test_valid_real_outputs_match_exact_success_and_do_not_mutate() -> void:
	_expect(_fixture())

func test_detached_success_cannot_open_full_admission() -> void:
	var f:=_fixture()
	_expect(f)
	assert_bool(f["session"].ready).is_false()
	assert_bool(f["session"].validate_combined_state(f["state"])=={"ok":false,"code":"TREE_SESSION_BINDING_CHANGED","recoverable_corruption":false}).is_true()

func test_original_definition_and_inventory_rules_remain_intact() -> void:
	var f:=_fixture()
	assert_str(f["core"]._rules_identity).is_equal(Core.TREE_RULES_SHA256)
	assert_bool(f["ledger"]._definition.ready).is_true()
	assert_bool(f["ledger"]._definition._rules.is_read_only()).is_true()
	assert_bool(f["ledger"]._definition._rules["harvest"].is_read_only()).is_true()
	assert_int(int(f["ledger"]._definition._rules["entry_safety_square_side_cells"])).is_equal(7)
	assert_bool(f["ledger"]._definition._rules["natural_generation"]["enabled"]).is_false()
	_expect(f)

func test_world_identity_mismatch_uses_original_seed_binding_error() -> void:
	var f:=_fixture()
	f["state"]["world_id"]="world_22222222222222222222222222222222"
	_expect(f,"TREE_WORLD_SEED_BINDING")

func test_actual_world_seed_must_match_bound_seed() -> void:
	var f:=_fixture()
	f["state"]["world_component"]["layout"]["seed_decimal"]="18"
	_expect(f,"TREE_WORLD_SEED_BINDING")

func test_tree_cell_center_outside_body_rejects() -> void:
	var f:=_fixture()
	f["state"]["world_component"]["layout"]["body"]["radius_cells"]=1
	_expect(f,"TREE_OUTSIDE_WORLD_BODY")

func test_real_definition_rejects_layout_entry_safety_cell() -> void:
	var f:=_fixture()
	_entry(f,[10,20,7,7])
	_expect(f,"TREE_FIXTURE_PROTECTED_CELL")

func test_real_definition_rejects_prefab_protected_cell() -> void:
	var f:=_fixture()
	var layer: Dictionary=Address.layer(WORLD,"body_0001","surface",0)
	f["state"]["world_component"]["prefab_instances"]=[{"protected_areas":[{"layer":layer,"rect":[10,20,1,1]}],"connections":[],"anchors":[]}]
	_expect(f,"TREE_FIXTURE_PROTECTED_CELL")

func test_prefab_anchor_projects_matching_connection_safety_box() -> void:
	var f:=_fixture()
	var layer: Dictionary=Address.layer(WORLD,"body_0001","surface",0)
	f["state"]["world_component"]["prefab_instances"]=[{"protected_areas":[],"connections":[{"upper_anchor_instance_id":"anchor_upper","lower_anchor_instance_id":"anchor_lower","safety_rect":[10,20,7,7]}],"anchors":[{"instance_id":"anchor_upper","layer":layer}]}]
	_expect(f,"TREE_FIXTURE_PROTECTED_CELL")

func test_reservation_on_other_layer_does_not_block_tree() -> void:
	var f:=_fixture()
	var layer: Dictionary=Address.layer(WORLD,"body_0001","underground",1)
	_entry(f,[10,20,7,7],layer)
	f["state"]["world_component"]["prefab_instances"]=[{"protected_areas":[{"layer":layer,"rect":[10,20,1,1]}],"connections":[],"anchors":[]}]
	_expect(f)

func test_entry_safety_rect_keeps_original_half_open_edge() -> void:
	var f:=_fixture()
	_entry(f,[3,13,7,7])
	_expect(f)

func test_canonical_tree_layer_cannot_admit_unmaterialized_body() -> void:
	_expect(_fixture("body_0002"),"TREE_BODY_NOT_MATERIALIZED")

func test_completion_profile_must_exist_in_outer_profiles() -> void:
	var f:=_fixture()
	_completion(f)["profile_id"]=OTHER
	_expect(f,"TREE_COMPLETION_AUTHORITY_CONTEXT")

func test_completion_time_cannot_be_in_future() -> void:
	var f:=_fixture()
	_completion(f)["completed_world_seconds"]=COMPLETED+1.0
	_expect(f,"TREE_COMPLETION_AUTHORITY_CONTEXT")

func test_natural_lot_source_layer_must_match_tree() -> void:
	var f:=_fixture()
	_wood(f)["layer"]=Address.layer(WORLD,"body_0001","underground",1)
	_expect(f,"TREE_GROUND_SOURCE_LAYER")

func test_natural_lot_requires_persisted_completion_event() -> void:
	var f:=_fixture()
	_wood(f)["lots"][0]["completion_id"]=Ledger.completion_identity("entity_tree_absent")
	_expect(f,"TREE_GROUND_COMPLETION_MISSING")

func test_absolute_lifetime_cannot_be_shortened() -> void:
	var f:=_fixture()
	_wood(f)["lots"][0]["remaining_lifetime"]=299.0
	_expect(f,"TREE_GROUND_SOURCE_TIMER_MISMATCH")

func test_absolute_lifetime_cannot_be_renewed_after_elapsed_time() -> void:
	var f:=_fixture()
	_elapsed(f,10.0)
	_wood(f)["lots"][0]["remaining_lifetime"]=291.0
	_expect(f,"TREE_GROUND_SOURCE_TIMER_MISMATCH")

func test_absolute_delay_cannot_be_shortened() -> void:
	var f:=_fixture()
	_wood(f)["lots"][0]["remaining_delay"]=0.4
	_expect(f,"TREE_GROUND_SOURCE_TIMER_MISMATCH")

func test_absolute_delay_cannot_be_renewed_after_elapsed_time() -> void:
	var f:=_fixture()
	_elapsed(f,0.25)
	_wood(f)["lots"][0]["remaining_delay"]=0.5
	_expect(f,"TREE_GROUND_SOURCE_TIMER_MISMATCH")

func test_valid_absolute_timers_include_delay_clamp_to_zero() -> void:
	for elapsed in [0.0,0.25,0.5,10.0,299.0]:
		var f:=_fixture()
		_elapsed(f,elapsed)
		_expect(f)

func test_original_timer_tolerance_is_preserved() -> void:
	var f:=_fixture()
	_wood(f)["lots"][0]["remaining_lifetime"]=300.0-0.0000005
	_wood(f)["lots"][0]["remaining_delay"]=0.5-0.0000005
	_expect(f)

func test_timer_difference_beyond_original_tolerance_rejects() -> void:
	var f:=_fixture()
	_wood(f)["lots"][0]["remaining_lifetime"]=300.0-0.000002
	_expect(f,"TREE_GROUND_SOURCE_TIMER_MISMATCH")

func test_one_cohort_split_across_records_at_output_limit_is_valid() -> void:
	var f:=_fixture()
	var wood: Dictionary=_wood(f)
	_duplicate_wood(f,1)
	wood["stack"]["quantity"]-=1
	wood["lots"][0]["quantity"]-=1
	_expect(f)

func test_one_cohort_cannot_exceed_output_across_records() -> void:
	var f:=_fixture()
	_duplicate_wood(f,1)
	_expect(f,"TREE_GROUND_OUTPUT_DUPLICATED")

func test_one_cohort_cannot_exceed_output_across_lots() -> void:
	var f:=_fixture()
	var wood: Dictionary=_wood(f)
	var extra: Dictionary=wood["lots"][0].duplicate(true)
	extra["quantity"]=1
	wood["lots"].append(extra)
	wood["stack"]["quantity"]+=1
	_expect(f,"TREE_GROUND_OUTPUT_DUPLICATED")

func test_nonnatural_lot_remains_outside_tree_source_checks() -> void:
	var f:=_fixture()
	var lot: Dictionary=_wood(f)["lots"][0]
	lot.erase("source_kind")
	lot.erase("completion_id")
	lot["thrower"]=PLAYER
	lot["remaining_thrower_protection"]=1.5
	lot["remaining_lifetime"]=123.0
	lot["remaining_delay"]=0.25
	_expect(f)

func test_seed_error_precedes_body_and_site_error() -> void:
	var f:=_fixture()
	f["state"]["world_component"]["layout"]["seed_decimal"]="18"
	f["state"]["world_component"]["layout"]["body"]["radius_cells"]=1
	_entry(f,[10,20,7,7])
	_expect(f,"TREE_WORLD_SEED_BINDING")

func test_radius_error_precedes_site_and_materialization_error() -> void:
	var f:=_fixture("body_0002")
	f["state"]["world_component"]["layout"]["body"]["radius_cells"]=1
	_entry(f,[10,20,7,7],Address.layer(WORLD,"body_0002","surface",0))
	_expect(f,"TREE_OUTSIDE_WORLD_BODY")

func test_site_error_precedes_materialization_error() -> void:
	var f:=_fixture("body_0002")
	_entry(f,[10,20,7,7],Address.layer(WORLD,"body_0002","surface",0))
	_expect(f,"TREE_FIXTURE_PROTECTED_CELL")

func test_completion_context_error_precedes_missing_ground_event() -> void:
	var f:=_fixture()
	_completion(f)["profile_id"]=OTHER
	_wood(f)["lots"][0]["completion_id"]=Ledger.completion_identity("entity_tree_absent")
	_expect(f,"TREE_COMPLETION_AUTHORITY_CONTEXT")

func test_missing_event_error_precedes_source_layer_and_timer() -> void:
	var f:=_fixture()
	_wood(f)["lots"][0]["completion_id"]=Ledger.completion_identity("entity_tree_absent")
	_wood(f)["layer"]=Address.layer(WORLD,"body_0001","underground",1)
	_wood(f)["lots"][0]["remaining_lifetime"]=299.0
	_expect(f,"TREE_GROUND_COMPLETION_MISSING")

func test_source_layer_error_precedes_timer_error() -> void:
	var f:=_fixture()
	_wood(f)["layer"]=Address.layer(WORLD,"body_0001","underground",1)
	_wood(f)["lots"][0]["remaining_lifetime"]=299.0
	_expect(f,"TREE_GROUND_SOURCE_LAYER")

func test_timer_error_precedes_cohort_excess() -> void:
	var f:=_fixture()
	_duplicate_wood(f,1)
	_wood(f)["lots"][0]["remaining_lifetime"]=299.0
	_expect(f,"TREE_GROUND_SOURCE_TIMER_MISMATCH")
