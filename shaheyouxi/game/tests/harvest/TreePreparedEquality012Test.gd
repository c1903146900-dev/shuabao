extends GdUnitTestSuite
## Pure prepared-equality tests. No Owner, Frame, world generation, physics,
## resource loading, publication, or save operation is instantiated here.
## These small structural values are equality fixtures, NOT valid full worlds.
## The production caller must independently full-validate its recomputed left
## operand. Passing these tests does not certify that caller or gameplay rules.
const Equality = preload("res://scripts/harvest/tree_prepared_equality012.gd")
const Codec = preload("res://scripts/save/exact_scalar_codec.gd")

const CLOSED_PATHS := [[],["request"],["plan"],["plan","request"],["plan","source_tokens"],["tree_plan"],["tree_plan","outputs",0],["base"],["plan","state"],["tree_plan","state"],["plan","state","tree_component"]]
const CANONICAL_PATHS := [[],["request"],["plan"],["plan","request"],["plan","source_tokens"],["tree_plan"],["tree_plan","outputs",0]]
const WHOLE_ROOT_PATHS := [["base"],["plan","state"],["tree_plan","state"],["plan","state","tree_component"]]

func _ledger() -> Dictionary:
	return {"schema_version":1,"contract":"sandbox012-isolated-tree-ledger-v1","world_id":"world_equality","seed_decimal":"7","revision":1,"fixture_only":true,"trees":{"tree_equality":{"status":"felled","cell":[0,0]}},"completions":{"harvest_equality":{"outputs":[{"content_id":"mucai","quantity":1}]}}}

func _root() -> Dictionary:
	return {"world_id":"world_equality","world_seconds":1.0,"revision":1,"next_auto_due_world_seconds":2.0,"profiles":{"player_equality":{"position":[0.0,0.0]}},"world_component":{"rows":[{"kind":"surface","cell":[0,0]}]},"actor_component":{"actors":{"actor_equality":{"position":[0.0,0.0]}}},"terrain_component":{"cells":[{"height":0.0}]}}

func _fixture() -> Dictionary:
	var base := _root()
	var state := base.duplicate(true)
	state["inventory_contract"] = "inventory-equality-fixture"
	state["inventory_component"] = {"revision":1,"ground_drops":{"drop_equality":{"content_id":"mucai","quantity":1}}}
	state["tree_contract"] = "tree-equality-fixture"
	state["tree_component"] = _ledger()
	var plan := {"ok":true,"state":state,"source_tokens":{"tree":"tree-source","inventory":"inventory-source","boundary":"boundary-source"},"request":{"tree_id":"tree_equality","completion_id":"harvest_equality","profile_id":"player_equality"},"replay":false,"created_drop_ids":["drop_equality"],"published":false,"durable":false,"fixture_only":true}
	# Ledger._plan builds its first six fields, then merges completion metadata.
	var tree_plan := {"ok":true,"state":_ledger(),"source_token":"tree-source","fixture_only":true,"published":false,"durable":false,"tree_id":"tree_equality","completion_id":"harvest_equality","outputs":[{"content_id":"mucai","quantity":1}],"replay":false,"must_not_create_drops":false}
	return {"ok":true,"bundle_token":"bundle-source","base":base,"request":{"tree_id":"tree_equality","event_id":"harvest_equality","profile":"player_equality"},"plan":plan,"tree_plan":tree_plan,"fixture_only":true}

func _at(value: Variant, path: Array) -> Variant:
	var cursor: Variant = value
	for key in path:
		cursor = cursor[key]
	return cursor

func _set_path(value: Dictionary, path: Array, replacement: Variant) -> void:
	var cursor: Variant = value
	for index in range(path.size() - 1):
		cursor = cursor[path[index]]
	cursor[path.back()] = replacement

func _reordered(value: Dictionary) -> Dictionary:
	var keys: Array = value.keys()
	keys.reverse()
	var result: Dictionary = {}
	for key in keys:
		result[key] = value[key]
	return result

func _replace_dictionary(value: Dictionary, path: Array, replacement: Dictionary) -> Dictionary:
	if path.is_empty():
		return replacement
	_set_path(value,path,replacement)
	return value

func _reject_either(left: Variant, right: Variant, label: String = "") -> void:
	assert_bool(Equality.matches_recomputed(left,right)).override_failure_message("Left/right must reject: " + label).is_false()
	assert_bool(Equality.matches_recomputed(right,left)).override_failure_message("Right/left must reject: " + label).is_false()

func _reject_identical(value: Variant, label: String = "") -> void:
	assert_bool(Equality.matches_recomputed(value,value)).override_failure_message("Identical invalid operands must reject: " + label).is_false()

func _old_unchecked_exact(value: Variant) -> String:
	# Exact original failure-sentinel mechanism, without preloading the heavy Core.
	return JSON.stringify(Codec.encode(value).get("value"),"",true,true)

func _node_count(value: Variant) -> int:
	var count := 1
	if value is Dictionary:
		for key in value:
			count += _node_count(value[key])
	elif value is Array:
		for item in value:
			count += _node_count(item)
	return count

func _leaf_paths(value: Variant, path: Array = []) -> Array:
	var result: Array = []
	if value is Dictionary:
		for key in value:
			result.append_array(_leaf_paths(value[key],path + [key]))
	elif value is Array:
		for index in value.size():
			result.append_array(_leaf_paths(value[index],path + [index]))
	else:
		result.append(path)
	return result

func _payload_path(field: String) -> Array:
	match field:
		"base": return ["base","world_component","budget"]
		"plan": return ["plan","state","world_component","budget"]
		"tree_plan": return ["tree_plan","state","trees","budget"]
	return []

func _with_nodes(field: String, total: int) -> Dictionary:
	var value := _fixture()
	var payload: Array = []
	_set_path(value,_payload_path(field),payload)
	# Keys are not nodes. The singleton wrapper and all original root metadata
	# ARE nodes; only this fresh payload is sized to reach the requested total.
	payload.resize(total - _node_count({field:value[field]}))
	return value

func _with_depth(field: String, depth: int) -> Dictionary:
	var value := _fixture()
	var path := _payload_path(field)
	var payload: Variant = null
	for ignored in range(depth - path.size()):
		payload = [payload]
	_set_path(value,path,payload)
	return value

func _assert_node_boundary(field: String) -> void:
	var at_limit := _with_nodes(field,Codec.MAX_NODES)
	assert_int(_node_count({field:at_limit[field]})).is_equal(100000)
	assert_bool(Codec.encode({field:at_limit[field]}).get("ok",false)).is_true()
	assert_bool(Equality.matches_recomputed(at_limit,at_limit.duplicate(true))).is_true()
	var over_limit := _with_nodes(field,Codec.MAX_NODES + 1)
	assert_int(_node_count({field:over_limit[field]})).is_equal(100001)
	assert_str(Codec.encode({field:over_limit[field]}).get("code","")).is_equal("EXACT_SCALAR_NODE_LIMIT")
	# Omitting the singleton would wrongly admit this same 100000-node root.
	assert_bool(Codec.encode(over_limit[field]).get("ok",false)).is_true()
	if field in ["plan","tree_plan"]:
		# The state alone still fits. Splitting this oversized plan into its
		# descendants would evade the required whole-plan rejection.
		assert_bool(Codec.encode(over_limit[field]["state"]).get("ok",false)).is_true()
	_reject_identical(over_limit,field + " singleton node overflow")
	_reject_either(at_limit,over_limit,field + " one-sided node overflow")

func _assert_depth_boundary(field: String) -> void:
	var at_limit := _with_depth(field,Codec.MAX_DEPTH)
	assert_bool(Codec.encode({field:at_limit[field]}).get("ok",false)).is_true()
	assert_bool(Equality.matches_recomputed(at_limit,at_limit.duplicate(true))).is_true()
	var over_limit := _with_depth(field,Codec.MAX_DEPTH + 1)
	assert_str(Codec.encode({field:over_limit[field]}).get("code","")).is_equal("EXACT_SCALAR_DEPTH_LIMIT")
	# Root-only encoding loses one original edge and would incorrectly succeed.
	assert_bool(Codec.encode(over_limit[field]).get("ok",false)).is_true()
	_reject_identical(over_limit,field + " singleton depth overflow")
	_reject_either(at_limit,over_limit,field + " one-sided depth overflow")

func test_equal_small_detached_prepared_preserves_old_successful_encoding() -> void:
	var left := _fixture()
	var right := left.duplicate(true)
	assert_bool(is_same(left,right)).is_false()
	assert_bool(Codec.encode(left).get("ok",false)).is_true()
	assert_str(_old_unchecked_exact(left)).is_equal(_old_unchecked_exact(right))
	assert_bool(Equality.matches_recomputed(left,right)).is_true()
	assert_bool(Equality.matches_recomputed(right,left)).is_true()

func test_equal_replay_metadata_is_supported_without_publication() -> void:
	var value := _fixture()
	value["plan"]["replay"] = true
	value["plan"]["created_drop_ids"] = []
	value["tree_plan"]["replay"] = true
	value["tree_plan"]["must_not_create_drops"] = true
	assert_bool(Equality.matches_recomputed(value,value.duplicate(true))).is_true()

func test_every_prepared_field_mutation_is_detected() -> void:
	for field in Equality.FIELDS:
		var left := _fixture()
		var right := left.duplicate(true)
		match field:
			"ok", "fixture_only": right[field] = false
			"bundle_token": right[field] = "another-bundle"
			"base": right[field]["world_seconds"] = 3.0
			"request": right[field]["profile"] = "player_other"
			"plan": right[field]["source_tokens"]["inventory"] = "changed"
			"tree_plan": right[field]["outputs"][0]["quantity"] = 2
		_reject_either(left,right,field)

func test_every_plan_field_mutation_is_detected() -> void:
	for field in Equality.PLAN_FIELDS:
		var left := _fixture()
		var right := left.duplicate(true)
		var plan: Dictionary = right["plan"]
		match field:
			"ok", "fixture_only": plan[field] = false
			"published", "durable", "replay": plan[field] = true
			"state": plan[field]["world_seconds"] = 3.0
			"source_tokens": plan[field]["inventory"] = "changed"
			"request": plan[field]["profile_id"] = "player_other"
			"created_drop_ids": plan[field][0] = "drop_other"
		_reject_either(left,right,"plan." + field)

func test_every_tree_completion_plan_field_mutation_is_detected() -> void:
	for field in Equality.TREE_PLAN_FIELDS:
		var left := _fixture()
		var right := left.duplicate(true)
		var plan: Dictionary = right["tree_plan"]
		match field:
			"ok", "fixture_only": plan[field] = false
			"published", "durable", "replay", "must_not_create_drops": plan[field] = true
			"state": plan[field]["revision"] = 2
			"source_token", "tree_id", "completion_id": plan[field] = "changed"
			"outputs": plan[field][0]["content_id"] = "seed_shumu"
		_reject_either(left,right,"tree_plan." + field)

func test_every_request_token_and_output_field_mutation_is_detected() -> void:
	for path in [["request"],["plan","request"],["plan","source_tokens"],["tree_plan","outputs",0]]:
		var left := _fixture()
		var original: Dictionary = _at(left,path)
		for key in original:
			var right := left.duplicate(true)
			var changed: Dictionary = _at(right,path)
			changed[key] = 2 if key == "quantity" else "changed"
			_reject_either(left,right,str(path) + "." + key)

func test_each_whole_state_root_field_mutation_is_detected() -> void:
	for path in WHOLE_ROOT_PATHS:
		var left := _fixture()
		var root: Dictionary = _at(left,path)
		for key in root:
			var right := left.duplicate(true)
			var changed: Dictionary = _at(right,path)
			match typeof(changed[key]):
				TYPE_STRING: changed[key] = "changed"
				TYPE_INT: changed[key] += 1
				TYPE_FLOAT: changed[key] += 1.0
				TYPE_BOOL: changed[key] = not changed[key]
				TYPE_DICTIONARY: changed[key] = {}
			_reject_either(left,right,str(path) + "." + key)

func test_nested_state_dictionary_array_and_scalar_mutations_are_detected() -> void:
	var changes := [
		[["base","profiles","player_equality","position",0],1.0],
		[["base","world_component","rows",0,"kind"],"changed"],
		[["base","world_component","rows",0,"cell",1],1],
		[["base","actor_component","actors","actor_equality","position",1],1.0],
		[["base","terrain_component","cells",0,"height"],1.0],
		[["plan","state","inventory_component","ground_drops","drop_equality","quantity"],2],
		[["plan","state","tree_component","trees","tree_equality","status"],"alive"],
		[["tree_plan","state","completions","harvest_equality","outputs",0,"quantity"],2]
	]
	for change in changes:
		var left := _fixture()
		var right := left.duplicate(true)
		_set_path(right,change[0],change[1])
		_reject_either(left,right,str(change[0]))

func test_every_scalar_leaf_in_each_synthetic_whole_state_is_compared() -> void:
	var left := _fixture()
	for root_path in WHOLE_ROOT_PATHS:
		for path in _leaf_paths(_at(left,root_path),root_path):
			var right := left.duplicate(true)
			var original: Variant = _at(left,path)
			match typeof(original):
				TYPE_STRING: _set_path(right,path,original + "-changed")
				TYPE_INT: _set_path(right,path,original + 1)
				TYPE_FLOAT: _set_path(right,path,original + 1.0)
				TYPE_BOOL: _set_path(right,path,not original)
				TYPE_NIL: _set_path(right,path,0)
			assert_str(_old_unchecked_exact(left)).is_not_equal(_old_unchecked_exact(right))
			_reject_either(left,right,"synthetic state leaf " + str(path))

func test_each_closed_dictionary_missing_field_rejects_even_on_both_sides() -> void:
	for path in CLOSED_PATHS:
		var clean := _fixture()
		var original: Dictionary = _at(clean,path)
		for key in original:
			var changed := clean.duplicate(true)
			var target: Dictionary = _at(changed,path)
			target.erase(key)
			_reject_either(clean,changed,str(path) + " missing " + str(key))
			_reject_identical(changed,str(path) + " missing " + str(key))

func test_each_closed_dictionary_unknown_or_non_string_key_rejects() -> void:
	for path in CLOSED_PATHS:
		for key in ["unknown",7]:
			var clean := _fixture()
			var changed := clean.duplicate(true)
			var target: Dictionary = _at(changed,path)
			target[key] = true
			_reject_either(clean,changed,str(path) + " extra " + str(key))
			_reject_identical(changed,str(path) + " extra " + str(key))

func test_same_count_non_string_keys_cannot_replace_a_closed_field() -> void:
	for path in CLOSED_PATHS:
		var clean := _fixture()
		var original: Dictionary = _at(clean,path)
		for replacement in [17,StringName(original.keys()[0])]:
			var rebuilt: Dictionary = {}
			var first := true
			for key in original:
				rebuilt[replacement if first else key] = original[key]
				first = false
			assert_bool(typeof(rebuilt.keys()[0]) != TYPE_STRING).is_true()
			var changed := _replace_dictionary(clean.duplicate(true),path,rebuilt)
			_reject_either(clean,changed,str(path) + " replaced key")
			_reject_identical(changed,str(path) + " replaced key")

func test_all_closed_dictionary_one_sided_reordering_is_detected() -> void:
	for path in CLOSED_PATHS:
		var clean := _fixture()
		var original: Dictionary = _at(clean,path)
		var changed := _replace_dictionary(clean.duplicate(true),path,_reordered(original))
		_reject_either(clean,changed,str(path) + " reordered")

func test_canonical_metadata_reordering_rejects_even_when_both_sides_match() -> void:
	for path in CANONICAL_PATHS:
		var value := _fixture()
		var original: Dictionary = _at(value,path)
		value = _replace_dictionary(value,path,_reordered(original))
		_reject_identical(value,str(path) + " noncanonical metadata")

func test_whole_state_key_order_remains_exact_without_a_new_canonical_order() -> void:
	for path in WHOLE_ROOT_PATHS:
		var value := _fixture()
		var original: Dictionary = _at(value,path)
		value = _replace_dictionary(value,path,_reordered(original))
		assert_bool(Equality.matches_recomputed(value,value.duplicate(true))).is_true()

func test_non_dictionary_prepared_values_reject_without_encoding_fallback() -> void:
	for value in [null,false,0,0.0,"",[],RefCounted.new(),Callable()]:
		_reject_either(_fixture(),value,"wrong prepared type")
		_reject_identical(value,"wrong prepared type")

func test_closed_dictionary_and_array_slots_enforce_exact_container_types() -> void:
	var dictionary_paths: Array = CLOSED_PATHS.duplicate()
	dictionary_paths.remove_at(0)
	dictionary_paths.append_array([["base","profiles"],["base","world_component"],["base","actor_component"],["base","terrain_component"],["plan","state","profiles"],["plan","state","world_component"],["plan","state","actor_component"],["plan","state","terrain_component"],["plan","state","inventory_component"],["plan","state","tree_component","trees"],["plan","state","tree_component","completions"],["tree_plan","state","trees"],["tree_plan","state","completions"]])
	for path in dictionary_paths:
		for replacement in [null,false,1,1.0,"dictionary",[]]:
			var changed := _fixture()
			_set_path(changed,path,replacement)
			_reject_identical(changed,str(path) + " Dictionary type")
	for path in [["plan","created_drop_ids"],["tree_plan","outputs"]]:
		for replacement in [null,false,1,1.0,"array",{},PackedStringArray()]:
			var changed := _fixture()
			_set_path(changed,path,replacement)
			_reject_identical(changed,str(path) + " Array type")

func test_required_text_fields_reject_empty_non_string_and_stringname_values() -> void:
	var paths := [["bundle_token"],["request","tree_id"],["request","event_id"],["request","profile"],["plan","request","tree_id"],["plan","request","completion_id"],["plan","request","profile_id"],["plan","source_tokens","tree"],["plan","source_tokens","inventory"],["plan","source_tokens","boundary"],["plan","created_drop_ids",0],["tree_plan","source_token"],["tree_plan","tree_id"],["tree_plan","completion_id"],["tree_plan","outputs",0,"content_id"],["base","world_id"],["plan","state","world_id"],["plan","state","inventory_contract"],["plan","state","tree_contract"]]
	for ledger_path in [["tree_plan","state"],["plan","state","tree_component"]]:
		for key in ["contract","world_id","seed_decimal"]:
			paths.append(ledger_path + [key])
	for path in paths:
		for replacement in ["",null,false,1,1.0,[],{},StringName("text")]:
			var changed := _fixture()
			_set_path(changed,path,replacement)
			_reject_identical(changed,str(path) + " String type/nonempty")

func test_metadata_boolean_fields_reject_equal_numeric_or_inverted_flags() -> void:
	var true_paths := [["ok"],["fixture_only"],["plan","ok"],["plan","fixture_only"],["tree_plan","ok"],["tree_plan","fixture_only"],["tree_plan","state","fixture_only"],["plan","state","tree_component","fixture_only"]]
	var false_paths := [["plan","published"],["plan","durable"],["tree_plan","published"],["tree_plan","durable"]]
	for path in true_paths + false_paths:
		for replacement in [null,0,1,0.0,1.0,"true",[],{}]:
			var changed := _fixture()
			_set_path(changed,path,replacement)
			_reject_identical(changed,str(path) + " bool type")
		var inverted := _fixture()
		_set_path(inverted,path,not _at(inverted,path))
		_reject_identical(inverted,str(path) + " flag value")
	for path in [["plan","replay"],["tree_plan","replay"],["tree_plan","must_not_create_drops"]]:
		for replacement in [null,0,1,0.0,1.0,"false",[],{}]:
			var changed := _fixture()
			_set_path(changed,path,replacement)
			_reject_identical(changed,str(path) + " replay bool type")

func test_ledger_and_output_integer_slots_reject_float_bool_and_other_types() -> void:
	var paths := [["tree_plan","outputs",0,"quantity"],["tree_plan","state","schema_version"],["tree_plan","state","revision"],["plan","state","tree_component","schema_version"],["plan","state","tree_component","revision"]]
	for path in paths:
		for replacement in [null,false,true,1.0,"1",[],{}]:
			var changed := _fixture()
			_set_path(changed,path,replacement)
			_reject_identical(changed,str(path) + " int type")

func test_root_numeric_slots_preserve_original_int_float_acceptance_and_exactness() -> void:
	for root_path in [["base"],["plan","state"]]:
		for key in ["world_seconds","revision","next_auto_due_world_seconds"]:
			var path: Array = root_path + [key]
			var integer := _fixture()
			var floating := _fixture()
			_set_path(integer,path,1)
			_set_path(floating,path,1.0)
			assert_bool(Equality.matches_recomputed(integer,integer.duplicate(true))).is_true()
			assert_bool(Equality.matches_recomputed(floating,floating.duplicate(true))).is_true()
			_reject_either(integer,floating,str(path) + " int versus float")
			for replacement in [null,false,true,"1",[],{}]:
				var invalid := _fixture()
				_set_path(invalid,path,replacement)
				_reject_identical(invalid,str(path) + " numeric type")

func test_matching_but_self_inconsistent_requests_tokens_and_replays_reject() -> void:
	var paths := [["request","tree_id"],["request","event_id"],["request","profile"],["plan","request","tree_id"],["plan","request","completion_id"],["plan","request","profile_id"],["plan","source_tokens","tree"],["tree_plan","source_token"],["tree_plan","tree_id"],["tree_plan","completion_id"]]
	for path in paths:
		var changed := _fixture()
		_set_path(changed,path,"changed")
		_reject_identical(changed,str(path) + " cross-field disagreement")
	for path in [["plan","replay"],["tree_plan","replay"],["tree_plan","must_not_create_drops"]]:
		var changed := _fixture()
		_set_path(changed,path,true)
		_reject_identical(changed,str(path) + " replay disagreement")

func test_fixture_registration_plan_is_not_a_completion_plan() -> void:
	var changed := _fixture()
	changed["tree_plan"].erase("completion_id")
	changed["tree_plan"].erase("must_not_create_drops")
	assert_int(changed["tree_plan"].size()).is_equal(9)
	_reject_identical(changed,"nine-field fixture registration branch")

func test_actual_ieee_negative_zero_differs_from_positive_zero() -> void:
	var bytes := PackedByteArray([0,0,0,0,0,0,0,128])
	var negative: float = bytes.decode_double(0)
	assert_str(Codec.encode(negative)["value"][1]).is_equal("0000000000000080")
	assert_str(Codec.encode(0.0)["value"][1]).is_equal("0000000000000000")
	for path in [["base","world_seconds"],["plan","state","world_seconds"],["base","terrain_component","cells",0,"height"]]:
		var left := _fixture()
		var right := _fixture()
		_set_path(left,path,0.0)
		_set_path(right,path,negative)
		assert_bool(_at(left,path) == _at(right,path)).is_true()
		assert_str(_old_unchecked_exact(left)).is_not_equal(_old_unchecked_exact(right))
		_reject_either(left,right,str(path) + " signed zero bits")
		assert_bool(Equality.matches_recomputed(right,right.duplicate(true))).is_true()

func test_finite_nested_scalar_types_are_not_coerced_by_value_equality() -> void:
	for replacement in [1.0,true,"1"]:
		var left := _fixture()
		var right := _fixture()
		left["base"]["world_component"]["scalar"] = 1
		right["base"]["world_component"]["scalar"] = replacement
		assert_bool(Codec.encode(left).get("ok",false)).is_true()
		assert_bool(Codec.encode(right).get("ok",false)).is_true()
		_reject_either(left,right,"nested int versus " + str(typeof(replacement)))

func test_unicode_escaped_text_and_nested_insertion_order_are_exact() -> void:
	var left := _fixture()
	left["base"]["world_component"]["text"] = "中文🙂\"\\\n/"
	left["base"]["world_component"]["ordered"] = {"first":1,"second":2}
	assert_bool(Equality.matches_recomputed(left,left.duplicate(true))).is_true()
	var right := left.duplicate(true)
	right["base"]["world_component"]["ordered"] = {"second":2,"first":1}
	_reject_either(left,right,"nested insertion order")
	right = left.duplicate(true)
	right["base"]["world_component"]["text"] += "!"
	_reject_either(left,right,"escaped text changed")

func test_one_sided_unsupported_leaf_rejects_in_each_whole_block() -> void:
	for field in ["base","plan","tree_plan"]:
		for unsupported in [RefCounted.new(),Callable(),Vector2.ZERO,PackedByteArray([1]),StringName("name")]:
			var clean := _fixture()
			var changed := clean.duplicate(true)
			_set_path(changed,_payload_path(field),unsupported)
			assert_str(Codec.encode({field:changed[field]}).get("code","")).is_equal("EXACT_SCALAR_UNSUPPORTED_TYPE")
			_reject_either(clean,changed,field + " unsupported leaf")
			_reject_identical(changed,field + " paired unsupported leaf")

func test_two_different_objects_cannot_match_via_shared_null_failure_sentinel() -> void:
	var left := _fixture()
	var right := _fixture()
	left["base"]["world_component"]["object"] = RefCounted.new()
	right["base"]["world_component"]["object"] = RefCounted.new()
	assert_bool(is_same(left["base"]["world_component"]["object"],right["base"]["world_component"]["object"])).is_false()
	assert_str(Codec.encode(left).get("code","")).is_equal("EXACT_SCALAR_UNSUPPORTED_TYPE")
	assert_str(Codec.encode(right).get("code","")).is_equal("EXACT_SCALAR_UNSUPPORTED_TYPE")
	assert_str(_old_unchecked_exact(left)).is_equal("null")
	assert_str(_old_unchecked_exact(right)).is_equal("null")
	_reject_either(left,right,"two distinct Object failures")

func test_nonfinite_values_reject_on_one_or_both_sides() -> void:
	for field in ["base","plan","tree_plan"]:
		for number in [INF,-INF,NAN]:
			var clean := _fixture()
			var changed := clean.duplicate(true)
			_set_path(changed,_payload_path(field),number)
			assert_str(Codec.encode({field:changed[field]}).get("code","")).is_equal("EXACT_SCALAR_NONFINITE")
			_reject_either(clean,changed,field + " nonfinite")
			_reject_identical(changed,field + " paired nonfinite")

func test_non_string_nested_keys_reject_even_with_identical_operands() -> void:
	for field in ["base","plan","tree_plan"]:
		var changed := _fixture()
		_set_path(changed,_payload_path(field),{1:"non-String key"})
		assert_str(Codec.encode({field:changed[field]}).get("code","")).is_equal("EXACT_SCALAR_DICTIONARY_KEY_INVALID")
		_reject_identical(changed,field + " invalid nested key")

func test_created_drop_ids_over_100000_reject_before_metadata_iteration() -> void:
	var value := _fixture()
	var ids: Array = []
	ids.resize(Codec.MAX_NODES + 1)
	ids.fill("drop_equality")
	value["plan"]["created_drop_ids"] = ids
	assert_str(Codec.encode({"plan":value["plan"]}).get("code","")).is_equal("EXACT_SCALAR_NODE_LIMIT")
	_reject_identical(value,"oversized created_drop_ids")
	_reject_either(_fixture(),value,"one-sided oversized created_drop_ids")

func test_outputs_over_100000_reject_before_metadata_iteration() -> void:
	var value := _fixture()
	var outputs: Array = []
	outputs.resize(Codec.MAX_NODES + 1)
	outputs.fill({"content_id":"mucai","quantity":1})
	value["tree_plan"]["outputs"] = outputs
	assert_str(Codec.encode({"tree_plan":value["tree_plan"]}).get("code","")).is_equal("EXACT_SCALAR_NODE_LIMIT")
	_reject_identical(value,"oversized outputs")
	_reject_either(_fixture(),value,"one-sided oversized outputs")

func test_base_singleton_node_100000_accepts_and_100001_rejects() -> void:
	_assert_node_boundary("base")

func test_plan_singleton_node_100000_accepts_and_100001_rejects() -> void:
	_assert_node_boundary("plan")

func test_tree_plan_singleton_node_100000_accepts_and_100001_rejects() -> void:
	_assert_node_boundary("tree_plan")

func test_base_singleton_depth_64_accepts_and_65_rejects() -> void:
	_assert_depth_boundary("base")

func test_plan_singleton_depth_64_accepts_and_65_rejects() -> void:
	_assert_depth_boundary("plan")

func test_tree_plan_singleton_depth_64_accepts_and_65_rejects() -> void:
	_assert_depth_boundary("tree_plan")

func test_different_depth_failures_cannot_match_via_null_sentinel() -> void:
	var left := _with_depth("base",65)
	var right := _with_depth("base",66)
	assert_str(_old_unchecked_exact(left)).is_equal("null")
	assert_str(_old_unchecked_exact(right)).is_equal("null")
	_reject_either(left,right,"two depth-limit failures")

func test_different_node_failures_cannot_match_via_null_sentinel() -> void:
	var left := _with_nodes("base",100001)
	var right := _with_nodes("base",100002)
	assert_str(_old_unchecked_exact(left)).is_equal("null")
	assert_str(_old_unchecked_exact(right)).is_equal("null")
	_reject_either(left,right,"two node-limit failures")

func test_composite_overflow_accepts_only_when_each_original_whole_block_encodes() -> void:
	var left := _with_nodes("base",50000)
	var other := _with_nodes("plan",50001)
	left["plan"] = other["plan"]
	var right := left.duplicate(true)
	assert_str(Codec.encode(left).get("code","")).is_equal("EXACT_SCALAR_NODE_LIMIT")
	assert_str(Codec.encode(right).get("code","")).is_equal("EXACT_SCALAR_NODE_LIMIT")
	assert_str(_old_unchecked_exact(left)).is_equal("null")
	assert_str(_old_unchecked_exact(right)).is_equal("null")
	for field in Equality.FIELDS:
		assert_bool(Codec.encode({field:left[field]}).get("ok",false)).is_true()
	assert_bool(Equality.matches_recomputed(left,right)).is_true()
	# The old failed whole encodings still match after a genuine nested change.
	right["plan"]["state"]["world_component"]["budget"][0] = "changed"
	assert_str(_old_unchecked_exact(right)).is_equal("null")
	_reject_either(left,right,"large composite nested mutation")
	# No whole-root legal-world claim is made by this synthetic equality case.
