extends GdUnitTestSuite
const Definition = preload("res://scripts/harvest/tree_definition012.gd")
var definition: RefCounted
func before_test() -> void:
	definition = Definition.new()
	assert_bool(definition.ready).is_true()
func _layer() -> Dictionary:
	return {"world_id":"world_11111111111111111111111111111111","reference_frame":"celestial_local","body_instance_id":"body_0001","map_kind":"surface","depth":0}
func test_missing_natural_density_never_authorizes_generation() -> void:
	assert_str(definition.natural_generation_readiness()["code"]).is_equal("TREE_NATURAL_GENERATION_DESIGN_BLOCKED")
func test_fixture_collision_is_trunk_not_full_cell_wall() -> void:
	var result: Dictionary = definition.inspect_fixture_site(_layer(),[10,20],[],[])
	assert_bool(result["ok"]).is_true()
	assert_bool(result["spawn_authorized"]).is_false()
	assert_array(result["anchor"]).is_equal([10.5,20.5])
	assert_float(result["collision_rect"][0]).is_equal_approx(10.12,0.00001)
	assert_float(result["collision_rect"][1]).is_equal_approx(20.23,0.00001)
	assert_float(result["collision_rect"][2]).is_equal_approx(0.76,0.00001)
	assert_float(result["collision_rect"][3]).is_equal_approx(0.3,0.00001)
func test_seven_is_square_side_not_radius() -> void:
	var safety := [{"origin":[-3,-3],"size":[7,7]}]
	assert_bool(definition.inspect_fixture_site(_layer(),[3,3],safety,[])["ok"]).is_false()
	assert_bool(definition.inspect_fixture_site(_layer(),[4,3],safety,[])["ok"]).is_true()
	assert_bool(definition.inspect_fixture_site(_layer(),[-4,0],safety,[])["ok"]).is_true()
func test_wrong_entry_size_rejected_not_silently_interpreted_as_radius() -> void:
	assert_str(definition.inspect_fixture_site(_layer(),[20,20],[{"origin":[0,0],"size":[14,14]}],[])["code"]).is_equal("TREE_FIXTURE_ENTRY_SAFETY_SIZE")
func test_existing_poi_protection_blocks_tree() -> void:
	assert_bool(definition.inspect_fixture_site(_layer(),[12,14],[],[{"origin":[10,10],"size":[5,5]}])["ok"]).is_false()
func test_underground_and_noncelestial_layer_rejected() -> void:
	var layer := _layer(); layer["map_kind"] = "underground"; layer["depth"] = 1
	assert_bool(definition.inspect_fixture_site(layer,[0,0],[],[])["ok"]).is_false()
	layer = _layer(); layer["reference_frame"] = "ship_local"
	assert_bool(definition.inspect_fixture_site(layer,[0,0],[],[])["ok"]).is_false()
func test_malformed_cell_and_region_fail_closed() -> void:
	assert_bool(definition.inspect_fixture_site(_layer(),[1.0,2],[],[])["ok"]).is_false()
	assert_bool(definition.inspect_fixture_site(_layer(),[1,2],[],[{"origin":[0,0],"size":[-1,7]}])["ok"]).is_false()
func test_saved_seed_identity_is_repeatable_without_rng() -> void:
	var a: Dictionary = definition.fixture_instance_id(17,_layer(),[10,20])
	assert_bool(a["ok"]).is_true()
	assert_str(a["instance_id"]).is_equal(definition.fixture_instance_id(17,_layer(),[10,20])["instance_id"])
	assert_str(a["instance_id"]).is_not_equal(definition.fixture_instance_id(18,_layer(),[10,20])["instance_id"])
	assert_str(a["instance_id"]).is_not_equal(definition.fixture_instance_id(17,_layer(),[11,20])["instance_id"])
func test_identity_is_scoped_to_world_and_body() -> void:
	var a: String = definition.fixture_instance_id(17,_layer(),[10,20])["instance_id"]
	var layer := _layer(); layer["body_instance_id"] = "body_0002"
	assert_str(a).is_not_equal(definition.fixture_instance_id(17,layer,[10,20])["instance_id"])
	layer = _layer(); layer["world_id"] = "world_22222222222222222222222222222222"
	assert_str(a).is_not_equal(definition.fixture_instance_id(17,layer,[10,20])["instance_id"])
func test_noninteger_seed_is_not_rerolled_or_coerced() -> void:
	assert_bool(definition.fixture_instance_id("17",_layer(),[10,20])["ok"]).is_false()
	assert_bool(definition.fixture_instance_id(null,_layer(),[10,20])["ok"]).is_false()
func test_json_numeric_depth_is_canonical_for_identity() -> void:
	var layer := _layer(); layer["depth"] = 0.0
	assert_str(definition.fixture_instance_id(17,layer,[10,20])["instance_id"]).is_equal(definition.fixture_instance_id(17,_layer(),[10,20])["instance_id"])
