extends GdUnitTestSuite
const Core = preload("res://scripts/inventory/inventory_core012.gd")
const Ledger = preload("res://scripts/harvest/tree_ledger012.gd")
const Outputs = preload("res://scripts/harvest/tree_ground012.gd")
const Ground = preload("res://scripts/inventory/inventory_ground012.gd")
const WORLD := "world_11111111111111111111111111111111"
const PLAYER := "player_11111111111111111111111111111111"
var core: RefCounted
var ledger: RefCounted
var tree_id := ""
func before_test() -> void:
	core=Core.new(WORLD,"v2_tree_seed")
	ledger=Ledger.new(WORLD,"17")
	assert_bool(core.ready and ledger.ready).is_true()
	assert_bool(core.trusted_create_player(PLAYER)["ok"]).is_true()
	var layer: Dictionary={"world_id":WORLD,"reference_frame":"celestial_local","body_instance_id":"body_0001","map_kind":"surface","depth":0}
	var tree: Dictionary=ledger.plan_fixture_tree(layer,[10,20],[],[],ledger.token())
	assert_bool(tree["ok"]).is_true()
	assert_bool(ledger.trusted_restore(tree["state"])["ok"]).is_true()
	tree_id=tree["tree_id"]
func _completion() -> Dictionary:
	return ledger.plan_completion(tree_id,Ledger.completion_identity(tree_id),PLAYER,0.0,ledger.token())
func test_semantic_rules_explicit_default_v1_unchanged_and_cross_restore_refused() -> void:
	var old:=Core.new(WORLD)
	assert_bool(old.ready).is_true()
	assert_str(old.snapshot()["rules_sha256"]).is_equal(Core.RULES_SHA256)
	assert_str(core.snapshot()["rules_sha256"]).is_equal(Core.TREE_RULES_SHA256)
	assert_bool(old.trusted_restore(core.snapshot())["ok"]).is_false()
	assert_bool(core.trusted_restore(old.snapshot())["ok"]).is_false()
	assert_bool(Core.new(WORLD,"unknown").ready).is_false()
func test_all_outputs_prepared_without_publishing_either_component() -> void:
	var before: String=Core._exact(core.snapshot())
	var tree_before: String=ledger.token()
	var completion:=_completion()
	var result: Dictionary=Outputs.prepare_outputs(core,ledger,completion,0.0)
	assert_bool(result["ok"]).is_true()
	assert_int(result["state"]["schema_version"]).is_equal(3)
	assert_int(result["created_drop_ids"].size()).is_equal(completion["outputs"].size())
	assert_str(Core._exact(core.snapshot())).is_equal(before)
	assert_str(ledger.token()).is_equal(tree_before)
	assert_bool(result["published"] or result["durable"]).is_false()
func test_natural_lot_has_common_delay_without_fabricated_player_protection() -> void:
	var result: Dictionary=Outputs.prepare_outputs(core,ledger,_completion(),0.0)
	for drop in result["state"]["ground"].values():
		var lot: Dictionary=drop["lots"][0]
		assert_bool(lot["thrower"]==null and lot["remaining_thrower_protection"]==null).is_true()
		assert_float(lot["remaining_delay"]).is_equal(0.5)
		assert_bool(Ground._eligible(lot,PLAYER)).is_false()
	assert_bool(core.trusted_restore(result["state"])["ok"]).is_true()
	var advanced: Dictionary=Ground.advance(core,0.5)
	assert_bool(advanced["ok"]).is_true()
	for drop in advanced["state"]["ground"].values():
		var lot: Dictionary=drop["lots"][0]
		assert_bool(lot["remaining_thrower_protection"]==null).is_true()
		assert_bool(Ground._eligible(lot,PLAYER)).is_true()
func test_forged_replay_flag_cannot_duplicate_persisted_output() -> void:
	var completion:=_completion()
	assert_bool(ledger.trusted_restore(completion["state"])["ok"]).is_true()
	var replay: Dictionary=ledger.plan_completion(tree_id,Ledger.completion_identity(tree_id),PLAYER,0.0,ledger.token())
	replay["replay"]=false
	replay["must_not_create_drops"]=false
	assert_str(Outputs.prepare_outputs(core,ledger,replay,0.0)["code"]).is_equal("TREE_GROUND_FORGED_OR_REPLAYED_PLAN")
func test_changed_output_batch_and_clock_reject_without_mutation() -> void:
	var before: String=Core._exact(core.snapshot())
	var completion:=_completion()
	completion["state"]["completions"][completion["completion_id"]]["outputs"][0]["quantity"]=999
	assert_bool(Outputs.prepare_outputs(core,ledger,completion,0.0)["ok"]).is_false()
	assert_bool(Outputs.prepare_outputs(core,ledger,_completion(),1.0)["ok"]).is_false()
	assert_str(Core._exact(core.snapshot())).is_equal(before)
func test_natural_cannot_fake_numeric_extra_timer_or_harvester_thrower() -> void:
	var result: Dictionary=Outputs.prepare_outputs(core,ledger,_completion(),0.0)
	var state: Dictionary=result["state"].duplicate(true)
	var id: String=result["created_drop_ids"][0]
	state["ground"][id]["lots"][0]["remaining_thrower_protection"]=0.0
	assert_bool(core.validate_snapshot(state)["ok"]).is_false()
	state=result["state"].duplicate(true)
	state["ground"][id]["lots"][0]["thrower"]=PLAYER
	assert_bool(core.validate_snapshot(state)["ok"]).is_false()
func test_seed_rules_enforce_original_stack99_and_no_unique_ids() -> void:
	var state: Dictionary=core.snapshot()
	var seed: Dictionary={"content_id":"seed_shumu","quantity":99,"item_instance_id":"","protected_instance_id":"","state":{}}
	state["players"][PLAYER]["bag"][0]=seed
	assert_bool(core.validate_snapshot(state)["ok"]).is_true()
	seed["quantity"]=100
	assert_bool(core.validate_snapshot(state)["ok"]).is_false()
