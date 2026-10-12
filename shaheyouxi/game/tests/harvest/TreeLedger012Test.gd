extends GdUnitTestSuite
const Ledger = preload("res://scripts/harvest/tree_ledger012.gd")
const Codec = preload("res://scripts/save/exact_scalar_codec.gd")
const WORLD := "world_11111111111111111111111111111111"
const PLAYER := "player_11111111111111111111111111111111"
const OTHER := "player_22222222222222222222222222222222"
var ledger: RefCounted
func before_test() -> void:
	ledger=Ledger.new(WORLD,"17")
	assert_bool(ledger.ready).is_true()
func _layer() -> Dictionary:
	return {"world_id":WORLD,"reference_frame":"celestial_local","body_instance_id":"body_0001","map_kind":"surface","depth":0}
func _tree() -> String:
	var plan: Dictionary = ledger.plan_fixture_tree(_layer(),[10,20],[],[],ledger.token())
	assert_bool(plan.get("ok",false)).is_true()
	assert_bool(ledger.trusted_restore(plan["state"])["ok"]).is_true()
	return plan["tree_id"]
func test_add_is_nonpublishing_until_joint_owner_restores_candidate() -> void:
	var before: String = ledger.token()
	var plan: Dictionary = ledger.plan_fixture_tree(_layer(),[10,20],[],[],before)
	assert_bool(plan["ok"]).is_true()
	assert_bool(plan["published"] or plan["durable"]).is_false()
	assert_str(ledger.token()).is_equal(before)
	assert_int(ledger.snapshot()["trees"].size()).is_equal(0)
	assert_int(plan["state"]["trees"].size()).is_equal(1)
func test_completion_plans_tombstone_and_all_outputs_without_mutation() -> void:
	var id := _tree(); var before: String = ledger.token()
	var plan: Dictionary = ledger.plan_completion(id,Ledger.completion_identity(id),PLAYER,1.0,before)
	assert_bool(plan["ok"]).is_true()
	assert_str(ledger.token()).is_equal(before)
	assert_str(plan["state"]["trees"][id]["status"]).is_equal("felled")
	assert_int(plan["outputs"][0]["quantity"]).is_between(3,5)
	assert_int(plan["outputs"].size()).is_between(1,2)
	if plan["outputs"].size()==2: assert_int(plan["outputs"][1]["quantity"]).is_equal(1)
func test_replay_after_restore_and_exact_cold_roundtrip_does_not_create_drops() -> void:
	var id := _tree(); var event := Ledger.completion_identity(id)
	var plan: Dictionary = ledger.plan_completion(id,event,PLAYER,1.0,ledger.token())
	var encoded: Dictionary = Codec.encode(plan["state"])
	var restored: Dictionary = Codec.decode(JSON.parse_string(JSON.stringify(encoded["value"],"",true,true)))
	var cold := Ledger.new(WORLD,"17")
	assert_bool(cold.trusted_restore(restored["value"])["ok"]).is_true()
	var token: String = cold.token()
	var replay: Dictionary = cold.plan_completion(id,event,PLAYER,2.0,token)
	assert_bool(replay["ok"] and replay["replay"] and replay["must_not_create_drops"]).is_true()
	assert_str(cold.token()).is_equal(token)
	assert_bool(var_to_bytes(replay["state"])==var_to_bytes(restored["value"])).is_true()
func test_same_completion_different_player_rejects_without_mutation() -> void:
	var id := _tree();var event := Ledger.completion_identity(id)
	var plan: Dictionary = ledger.plan_completion(id,event,PLAYER,1.0,ledger.token())
	assert_bool(ledger.trusted_restore(plan["state"])["ok"]).is_true()
	var token: String = ledger.token()
	assert_str(ledger.plan_completion(id,event,OTHER,2.0,token)["code"]).is_equal("TREE_COMPLETION_REPLAY_PARAMETERS")
	assert_str(ledger.token()).is_equal(token)
func test_two_players_get_same_source_token_but_only_first_root_can_win() -> void:
	var id := _tree();var event := Ledger.completion_identity(id);var token: String = ledger.token()
	var one: Dictionary = ledger.plan_completion(id,event,PLAYER,1.0,token)
	var two: Dictionary = ledger.plan_completion(id,event,OTHER,1.0,token)
	assert_str(one["source_token"]).is_equal(two["source_token"])
	assert_bool(var_to_bytes(one["outputs"])==var_to_bytes(two["outputs"])).is_true()
	assert_bool(ledger.trusted_restore(one["state"])["ok"]).is_true()
	# This is ledger-side staleness only; joint two-component publication is separate.
	assert_bool(ledger.plan_completion(id,event,OTHER,1.0,token)["ok"]).is_false()
func test_changed_outputs_or_missing_tombstone_refused_on_load() -> void:
	var id := _tree();var event := Ledger.completion_identity(id)
	var state: Dictionary = ledger.plan_completion(id,event,PLAYER,1.0,ledger.token())["state"]
	state["completions"][event]["outputs"][0]["quantity"] = 999
	assert_bool(ledger.validate_snapshot(state)["ok"]).is_false()
	state = ledger.plan_completion(id,event,PLAYER,1.0,ledger.token())["state"]
	state["trees"][id]["status"]="alive"
	assert_bool(ledger.validate_snapshot(state)["ok"]).is_false()
func test_missing_completion_or_orphan_record_is_rejected() -> void:
	var id := _tree();var event := Ledger.completion_identity(id)
	var state: Dictionary = ledger.plan_completion(id,event,PLAYER,1.0,ledger.token())["state"]
	state["completions"].clear()
	assert_bool(ledger.validate_snapshot(state)["ok"]).is_false()
	state = ledger.plan_completion(id,event,PLAYER,1.0,ledger.token())["state"]
	state["completions"]["harvest_orphan"]=state["completions"][event].duplicate(true)
	assert_bool(ledger.validate_snapshot(state)["ok"]).is_false()
func test_identity_cannot_move_to_another_cell_or_world() -> void:
	var id := _tree();var state: Dictionary = ledger.snapshot()
	state["trees"][id]["cell"]=[11,20]
	assert_bool(ledger.validate_snapshot(state)["ok"]).is_false()
	var wrong := Ledger.new("world_22222222222222222222222222222222","17")
	assert_bool(wrong.trusted_restore(ledger.snapshot())["ok"]).is_false()
func test_malformed_or_noncanonical_saved_seed_not_rerolled() -> void:
	assert_bool(Ledger.new(WORLD,"017").ready).is_false()
	assert_bool(Ledger.new(WORLD,"-0").ready).is_false()
func test_duplicate_tree_and_protected_site_fail_without_mutation() -> void:
	_tree();var before: String = ledger.token()
	assert_bool(ledger.plan_fixture_tree(_layer(),[10,20],[],[],before)["ok"]).is_false()
	assert_bool(ledger.plan_fixture_tree(_layer(),[20,20],[],[{"origin":[20,20],"size":[1,1]}],before)["ok"]).is_false()
	assert_str(ledger.token()).is_equal(before)
func test_unready_outcome_query_fails_without_accessing_rules() -> void:
	var invalid:=Ledger.new(WORLD,"017")
	assert_bool(invalid.outcomes("entity_tree_invalid","harvest_invalid").is_empty()).is_true()
	assert_bool(ledger.outcomes("entity_tree_invalid","harvest_wrong").is_empty()).is_true()
func test_authority_rule_projection_is_deep_readonly() -> void:
	assert_bool(ledger._definition._rules.is_read_only()).is_true()
	assert_bool(ledger._definition._rules["harvest"].is_read_only()).is_true()
	assert_bool(ledger._definition._rules["harvest"]["wood_quantity_range"].is_read_only()).is_true()
