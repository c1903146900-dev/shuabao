extends GdUnitTestSuite
## Exact serializer equivalence only; separate real-Frame tests prove authority.
const Hot = preload("res://scripts/inventory/inventory_hot_boundary012.gd")
const Core = preload("res://scripts/inventory/inventory_core012.gd")
const Combined = preload("res://scripts/inventory/inventory_world_session012.gd")
const Codec = preload("res://scripts/save/exact_scalar_codec.gd")
var store: RefCounted
func before_test() -> void:
	store = Combined.SaveStore.new("",1,1,"a".repeat(64),1,Callable(),5,Combined.MAX_BYTES,true)
func _base(world: Variant = {}, terrain: Variant = {}) -> Dictionary:
	return {"world_id":"world_11111111111111111111111111111111","world_component":world,"terrain_component":terrain,"world_seconds":-0.0,"profiles":{},"actor_component":{},"revision":1,"next_auto_due_world_seconds":600.0}
func _full(base: Dictionary, inventory: Dictionary) -> String:
	var value := base.duplicate(false)
	value["inventory_contract"] = Combined.CONTRACT
	value["inventory_component"] = inventory
	return store._encode(value,Core.MAX_SEQUENCE,"manual","W".repeat(Combined.BoundedStore.MAX_REASON),63)
func _measure(base: Dictionary, inventory: Dictionary) -> Dictionary:
	var world := Hot.encoded_measure(base["world_component"])
	var terrain := Hot.encoded_measure(base["terrain_component"])
	var empty := Hot.encoded_measure(null)
	assert_bool(world["ok"] and terrain["ok"] and empty["ok"]).is_true()
	return Hot.candidate_measure(store,base,inventory,world["escaped_bytes"]+terrain["escaped_bytes"]-2*empty["escaped_bytes"],world["nodes"]+terrain["nodes"]-2)
func _assert_equal_measure(base: Dictionary, inventory: Dictionary) -> void:
	var full: String = _full(base,inventory)
	var measured := _measure(base,inventory)
	assert_bool(not full.is_empty()).is_true()
	assert_bool(measured.get("ok",false)).is_true()
	assert_int(measured["envelope_bytes"]).is_equal(full.to_utf8_buffer().size())
	var envelope: Dictionary = JSON.parse_string(full)
	assert_int(measured["codec_nodes"]).is_equal(Hot.encoded_nodes(JSON.parse_string(envelope["payload_json"])))
func test_exact_codec_null_occupies_one_original_value_node() -> void:
	assert_int(Hot.encoded_measure(null)["nodes"]).is_equal(1)
	assert_int(Hot.encoded_measure({"key":[null,true,1]})["nodes"]).is_equal(5)
func test_chinese_quotes_slashes_controls_negative_zero_exact_bytes() -> void:
	var text := "中文😀\"\\\n\r\t/"
	_assert_equal_measure(_base({"text":text,"nested":[-0.0,null,true]},[text,{"negative_zero":-0.0}]),{"opaque":{"state":text,"negative_zero":-0.0,"integer":Core.MAX_SEQUENCE}})
func test_dynamic_profile_actor_changes_remeasured_not_cached() -> void:
	var base := _base({"fixed":"world"},{"fixed":"terrain"})
	for value in ["小", "角色\"名\\换行\n", "x".repeat(1024)]:
		base["profiles"] = {"profile":{"display_name":value}}
		base["actor_component"] = {"clock":0.1,"body":{"state":value}}
		_assert_equal_measure(base,{"carry":value})
func test_exact_four_mib_boundary_and_one_byte_over() -> void:
	var base := _base({"fixed":"中文"},{"fixed":[1,2,3]})
	var overhead: int = _full(base,{"blob":""}).to_utf8_buffer().size()
	for offset in [-1,0,1]:
		var inventory := {"blob":"a".repeat(Combined.MAX_BYTES-overhead+offset)}
		var full: String = _full(base,inventory)
		var measured := _measure(base,inventory)
		assert_int(full.to_utf8_buffer().size()).is_equal(Combined.MAX_BYTES+offset)
		assert_int(measured["envelope_bytes"]).is_equal(full.to_utf8_buffer().size())
		assert_bool(measured["ok"]).is_equal(offset <= 0)
func test_total_codec_nodes_include_static_roots_and_payload_metadata() -> void:
	var world: Array = []; world.resize(50000); world.fill(false)
	var terrain: Array = []; terrain.resize(20000); terrain.fill(false)
	var base := _base(world,terrain)
	var baseline: Dictionary = JSON.parse_string(_full(base,{"items":[]}))
	var nodes: int = Hot.encoded_nodes(JSON.parse_string(baseline["payload_json"]))
	for offset in [-1,0,1]:
		var items: Array = []; items.resize(Codec.MAX_NODES-nodes+offset); items.fill(false)
		var inventory := {"items":items}
		var full: String = _full(base,inventory)
		var measured := _measure(base,inventory)
		assert_int(measured["codec_nodes"]).is_equal(Codec.MAX_NODES+offset)
		assert_bool(measured["ok"]).is_equal(offset <= 0)
		assert_bool(full.is_empty()).is_equal(offset > 0)
func test_dynamic_depth_limit_uses_same_full_payload_position() -> void:
	var base := _base({}, {})
	for depth in [59,60,61,62,63,64,65]:
		var chain: Variant = "leaf"
		for ignored in range(depth): chain = [chain]
		var inventory := {"chain":chain}
		var full: String = _full(base,inventory)
		var measured := _measure(base,inventory)
		assert_bool(measured["ok"]).is_equal(not full.is_empty())
