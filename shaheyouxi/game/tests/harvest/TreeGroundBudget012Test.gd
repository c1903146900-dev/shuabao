extends GdUnitTestSuite
## Small arithmetic fixtures only. These hand-written states are NOT valid
## gameplay worlds, authority evidence, a SourceLease, or a hot-admission test.
const Budget = preload("res://scripts/harvest/tree_ground_budget012.gd")
const SaveStore = preload("res://scripts/save/save_store.gd")
const Codec = preload("res://scripts/save/exact_scalar_codec.gd")
const Core = preload("res://scripts/inventory/inventory_core012.gd")
const BoundedStore = preload("res://scripts/inventory/inventory_world_save_store012.gd")
const TEXT := "中文😀\"\\/\n\r\t\b\f"

class WrongEncoder:
	extends "res://scripts/save/save_store.gd"
	var encode_calls: int = 0
	func _encode(_state: Dictionary, _sequence: int, _kind: String, _reason: String, _manual_slot: int) -> String:
		encode_calls += 1
		return "forged_encoder_must_not_run"

func _store(profile: int, content: String = "measurement_content") -> RefCounted:
	return SaveStore.new("", 1, 1, content, 1, Callable(), profile, Budget.MAX_BYTES, true)

func _negative_zero() -> float:
	# A decimal -0.0 literal can be folded. Construct the actual IEEE sign bit.
	return PackedByteArray([0, 0, 0, 0, 0, 0, 0, 128]).decode_double(0)

func _reduced(profile: int) -> Dictionary:
	var result := {
		"world_id": "measurement_fixture_not_a_valid_world",
		"world_component": null, "terrain_component": null,
		"inventory_contract": "measurement_inner5",
		"inventory_component": {"opaque": {"text": TEXT, "bits": _negative_zero()}},
		"padding": "", "items": [],
	}
	if profile == 6:
		result["tree_contract"] = "measurement_outer6"
		result["tree_component"] = {"trees": [], "notes": TEXT}
	return result

func _full(reduced: Dictionary, world: Variant, terrain: Variant) -> Dictionary:
	var result := reduced.duplicate(true)
	result["world_component"] = world
	result["terrain_component"] = terrain
	return result

func _encode(store: RefCounted, state: Dictionary) -> String:
	return store._encode(state, Core.MAX_SEQUENCE, "manual", "W".repeat(BoundedStore.MAX_REASON), 63)

func _actual_payload(text: String) -> Dictionary:
	var envelope: Dictionary = JSON.parse_string(text)
	var decoded: Dictionary = Codec.decode(JSON.parse_string(envelope["payload_json"]))
	assert_bool(decoded.get("ok", false)).is_true()
	return decoded.get("value", {})

func _variant_nodes(value: Variant) -> int:
	# Independent oracle over the DECODED original Variant tree. Do not use
	# Budget's tagged-node walker to verify Budget's tagged-node walker.
	var count: int = 1
	if value is Dictionary:
		for child in value.values():
			count += _variant_nodes(child)
	elif value is Array:
		for child in value:
			count += _variant_nodes(child)
	return count

func _chain(local_depth: int) -> Variant:
	var result: Variant = "leaf"
	for ignored in range(local_depth):
		result = [result]
	return result

func _assert_full_equal(store: RefCounted, profile: int, reduced: Dictionary, world: Variant, terrain: Variant) -> void:
	var metrics := Budget.static_measure(world, terrain)
	assert_bool(metrics.get("ok", false)).is_true()
	var actual: String = _encode(store, _full(reduced, world, terrain))
	assert_bool(actual.is_empty()).is_false()
	if actual.is_empty():
		return
	var measured := Budget.measure_profile(store, profile, reduced, metrics)
	assert_bool(measured.get("ok", false)).is_true()
	assert_int(measured["envelope_bytes"]).is_equal(actual.to_utf8_buffer().size())
	assert_int(measured["codec_nodes"]).is_equal(_variant_nodes(_actual_payload(actual)))
	var reduced_text: String = _encode(store, reduced)
	assert_int(actual.to_utf8_buffer().size() - reduced_text.to_utf8_buffer().size()).is_equal(metrics["bytes_delta"])
	assert_int(_variant_nodes(_actual_payload(actual)) - _variant_nodes(_actual_payload(reduced_text))).is_equal(metrics["nodes_delta"])
	assert_bool(measured["measurement_only"]).is_true()
	assert_bool(measured.has("hot_boundary") or measured.has("state") or measured.has("ticket")).is_false()

func test_static_metrics_are_pure_values_without_authority_or_state() -> void:
	var world := {"中文😀\"\\": [TEXT, true, null, 7, _negative_zero()]}
	var terrain := {"values": [false, 9.5]}
	var before := var_to_bytes([world, terrain])
	var metrics := Budget.static_measure(world, terrain)
	assert_bool(metrics["ok"]).is_true()
	assert_bool(metrics["measurement_only"]).is_true()
	assert_bool(metrics.is_read_only()).is_true()
	assert_bool(var_to_bytes([world, terrain]) == before).is_true()
	assert_int(metrics["world"]["codec_nodes"]).is_equal(_variant_nodes(world))
	assert_int(metrics["terrain"]["codec_nodes"]).is_equal(_variant_nodes(terrain))
	assert_int(metrics["nodes_delta"]).is_equal(_variant_nodes(world) + _variant_nodes(terrain) - 2)
	assert_int(metrics["root_depth"]).is_equal(2)
	assert_bool(metrics.has("lease") or metrics.has("ticket") or metrics.has("state") or metrics.has("hot_boundary")).is_false()
	assert_bool(metrics["world"].has("value") or metrics["terrain"].has("value")).is_false()
	assert_int(Budget.MAX_SEQUENCE).is_equal(Core.MAX_SEQUENCE)

func test_empty_containers_have_signed_byte_deltas_and_null_has_one_node() -> void:
	var metrics := Budget.static_measure({}, {})
	assert_bool(metrics["ok"]).is_true()
	assert_int(metrics["bytes_delta"]).is_less(0)
	assert_int(metrics["nodes_delta"]).is_equal(0)
	var nulls := Budget.static_measure(null, null)
	assert_int(nulls["world"]["codec_nodes"]).is_equal(1)
	assert_int(nulls["terrain"]["codec_nodes"]).is_equal(1)
	assert_int(nulls["bytes_delta"]).is_equal(0)
	assert_int(nulls["nodes_delta"]).is_equal(0)
	for profile in [5, 6]:
		_assert_full_equal(_store(profile), profile, _reduced(profile), {}, {})
		_assert_full_equal(_store(profile), profile, _reduced(profile), null, null)

func test_ieee_negative_zero_bits_survive_codec_and_actual_payload() -> void:
	var negative: float = _negative_zero()
	var bits := PackedByteArray()
	bits.resize(8)
	bits.encode_double(0, negative)
	assert_int(bits[7]).is_equal(128)
	assert_str(bits.hex_encode()).is_equal("0000000000000080")
	var encoded: Dictionary = Codec.encode(negative)
	assert_str(encoded["value"][0]).is_equal("float64_le")
	assert_str(encoded["value"][1]).is_equal("0000000000000080")
	for profile in [5, 6]:
		var store := _store(profile)
		var reduced := _reduced(profile)
		var world := {"negative": negative, "text": TEXT}
		_assert_full_equal(store, profile, reduced, world, [negative, TEXT])
		var payload := _actual_payload(_encode(store, _full(reduced, world, [negative, TEXT])))
		for value in [payload["state"]["world_component"]["negative"], payload["state"]["terrain_component"][0], payload["state"]["inventory_component"]["opaque"]["bits"]]:
			bits.encode_double(0, value)
			assert_str(bits.hex_encode()).is_equal("0000000000000080")

func test_dual_unicode_escaping_uses_each_actual_encoder_and_state() -> void:
	var world := {TEXT: [TEXT, _negative_zero(), Core.MAX_SEQUENCE]}
	var terrain := {"text": TEXT, "nested": [{"key": TEXT}]}
	var metrics := Budget.static_measure(world, terrain)
	var store5 := _store(5, "inner_metadata")
	var store6 := _store(6, "不同外层😀\"\\\n".repeat(3))
	store6._network_protocol_version = 43
	var reduced5 := _reduced(5)
	var reduced6 := _reduced(6)
	reduced6["inventory_component"]["independent_dynamic_value"] = [TEXT, false, null]
	var measured := Budget.measure_dual(store5, store6, reduced5, reduced6, metrics)
	assert_bool(measured["ok"]).is_true()
	for pair in [[5, store5, reduced5], [6, store6, reduced6]]:
		var actual: String = _encode(pair[1], _full(pair[2], world, terrain))
		var result: Dictionary = measured["profile%d" % pair[0]]
		assert_int(result["envelope_bytes"]).is_equal(actual.to_utf8_buffer().size())
		assert_int(result["codec_nodes"]).is_equal(_variant_nodes(_actual_payload(actual)))
	assert_int(measured["profile6"]["envelope_bytes"]).is_greater(measured["profile5"]["envelope_bytes"])
	assert_int(measured["profile6"]["codec_nodes"]).is_greater(measured["profile5"]["codec_nodes"])

func test_each_profile_actual_four_mib_minus_one_exact_and_plus_one() -> void:
	var world := {"fixed": TEXT}
	var terrain := {"fixed": [1, 2, 3]}
	var metrics := Budget.static_measure(world, terrain)
	for profile in [5, 6]:
		var store := _store(profile)
		var reduced := _reduced(profile)
		var overhead: int = _encode(store, _full(reduced, world, terrain)).to_utf8_buffer().size()
		for offset in [-1, 0, 1]:
			reduced["padding"] = "x".repeat(Budget.MAX_BYTES - overhead + offset)
			var full: String = _encode(store, _full(reduced, world, terrain))
			# In particular the over-limit _encode result must be NONEMPTY.
			assert_bool(full.is_empty()).is_false()
			assert_int(full.to_utf8_buffer().size()).is_equal(Budget.MAX_BYTES + offset)
			var measured := Budget.measure_profile(store, profile, reduced, metrics)
			assert_int(measured["envelope_bytes"]).is_equal(full.to_utf8_buffer().size())
			assert_bool(measured["ok"]).is_equal(offset <= 0)
			assert_bool(measured["byte_limit_ok"]).is_equal(offset <= 0)
			assert_bool(measured["node_limit_ok"]).is_true()
			if offset > 0:
				assert_str(measured["code"]).is_equal("TREE_GROUND_BUDGET_FINAL_BYTES_LIMIT")

func test_outer6_overflow_is_rejected_while_inner5_still_fits() -> void:
	var world := {"fixed": TEXT}
	var terrain := {"fixed": [1, 2, 3]}
	var metrics := Budget.static_measure(world, terrain)
	var store5 := _store(5)
	var store6 := _store(6)
	var reduced5 := _reduced(5)
	var reduced6 := _reduced(6)
	var outer_overhead: int = _encode(store6, _full(reduced6, world, terrain)).to_utf8_buffer().size()
	var padding := "x".repeat(Budget.MAX_BYTES - outer_overhead + 1)
	reduced5["padding"] = padding
	reduced6["padding"] = padding
	var measured := Budget.measure_dual(store5, store6, reduced5, reduced6, metrics)
	assert_bool(measured["ok"]).is_false()
	assert_int(measured["failed_profile"]).is_equal(6)
	assert_bool(measured["profile5"]["ok"]).is_true()
	assert_bool(measured["profile6"]["ok"]).is_false()
	assert_int(measured["profile6"]["envelope_bytes"]).is_equal(Budget.MAX_BYTES + 1)
	assert_int(measured["profile5"]["envelope_bytes"]).is_less(Budget.MAX_BYTES)
	assert_int(measured["profile5"]["envelope_bytes"]).is_equal(_encode(store5, _full(reduced5, world, terrain)).to_utf8_buffer().size())
	assert_int(measured["profile6"]["envelope_bytes"]).is_equal(_encode(store6, _full(reduced6, world, terrain)).to_utf8_buffer().size())

func test_each_profile_node_edges_include_actual_metadata_root_and_state() -> void:
	var world: Array = []
	world.resize(128)
	world.fill(false)
	var terrain := {"fixed": [null, true, 1]}
	var metrics := Budget.static_measure(world, terrain)
	for profile in [5, 6]:
		var store := _store(profile)
		var reduced := _reduced(profile)
		var state := _full(reduced, world, terrain)
		var initial_payload := _actual_payload(_encode(store, state))
		var initial_nodes: int = _variant_nodes(initial_payload)
		# Current SaveStore adds 17 nodes outside state, including the payload
		# root and build_identity dictionary/values. Keys and tags add none.
		assert_int(initial_nodes - _variant_nodes(state)).is_equal(17)
		for offset in [-1, 0, 1]:
			var items: Array = []
			items.resize(Codec.MAX_NODES - initial_nodes + offset)
			items.fill(false)
			reduced["items"] = items
			var full: String = _encode(store, _full(reduced, world, terrain))
			var measured := Budget.measure_profile(store, profile, reduced, metrics)
			assert_int(measured["codec_nodes"]).is_equal(Codec.MAX_NODES + offset)
			assert_bool(measured["ok"]).is_equal(offset <= 0)
			assert_bool(measured["node_limit_ok"]).is_equal(offset <= 0)
			assert_bool(full.is_empty()).is_equal(offset > 0)
			if offset <= 0:
				assert_int(measured["codec_nodes"]).is_equal(_variant_nodes(_actual_payload(full)))
				assert_int(measured["envelope_bytes"]).is_equal(full.to_utf8_buffer().size())
			else:
				assert_str(measured["code"]).is_equal("TREE_GROUND_BUDGET_FINAL_NODE_LIMIT")

func test_outer6_node_overflow_cannot_borrow_inner5_budget() -> void:
	var world := {"fixed": [1, 2, 3, 4, 5, 6, 7, 8]}
	var terrain := {"fixed": true}
	var metrics := Budget.static_measure(world, terrain)
	var store5 := _store(5)
	var store6 := _store(6)
	var reduced5 := _reduced(5)
	var reduced6 := _reduced(6)
	var outer_initial: int = _variant_nodes(_actual_payload(_encode(store6, _full(reduced6, world, terrain))))
	var items: Array = []
	items.resize(Codec.MAX_NODES - outer_initial + 1)
	items.fill(false)
	reduced5["items"] = items
	reduced6["items"] = items
	var result := Budget.measure_dual(store5, store6, reduced5, reduced6, metrics)
	assert_bool(result["ok"]).is_false()
	assert_int(result["failed_profile"]).is_equal(6)
	assert_bool(result["profile5"]["ok"]).is_true()
	assert_int(result["profile6"]["codec_nodes"]).is_equal(Codec.MAX_NODES + 1)
	assert_bool(_encode(store5, _full(reduced5, world, terrain)).is_empty()).is_false()
	assert_bool(_encode(store6, _full(reduced6, world, terrain)).is_empty()).is_true()

func test_static_depth62_passes_and63_fails_at_real_embedding_depth2() -> void:
	for local_depth in [62, 63]:
		var component: Variant = _chain(local_depth)
		# Both succeed at Codec depth0; only depth62 fits under state at depth2.
		assert_bool(Codec.encode(component)["ok"]).is_true()
		for field in ["world_component", "terrain_component"]:
			var world: Variant = component if field == "world_component" else {}
			var terrain: Variant = component if field == "terrain_component" else {}
			var metrics := Budget.static_measure(world, terrain)
			assert_bool(metrics["ok"]).is_equal(local_depth == 62)
			if local_depth == 63:
				assert_str(metrics["code"]).is_equal("EXACT_SCALAR_DEPTH_LIMIT")
			else:
				assert_int(metrics["world" if field == "world_component" else "terrain"]["local_depth"]).is_equal(62)
			for profile in [5, 6]:
				var store := _store(profile)
				var reduced := _reduced(profile)
				var full: String = _encode(store, _full(reduced, world, terrain))
				assert_bool(full.is_empty()).is_equal(local_depth == 63)
				assert_bool(Budget.measure_profile(store, profile, reduced, metrics)["ok"]).is_equal(local_depth == 62)

func test_dynamic_depth_is_checked_by_each_real_reduced_encoder() -> void:
	var metrics := Budget.static_measure({}, {})
	for profile in [5, 6]:
		var store := _store(profile)
		for local_depth in [62, 63]:
			var reduced := _reduced(profile)
			reduced["dynamic_chain"] = _chain(local_depth)
			var actual: String = _encode(store, _full(reduced, {}, {}))
			var measured := Budget.measure_profile(store, profile, reduced, metrics)
			assert_bool(measured["ok"]).is_equal(local_depth == 62)
			assert_bool(actual.is_empty()).is_equal(local_depth == 63)
			if local_depth == 63:
				assert_str(measured["code"]).is_equal("TREE_GROUND_BUDGET_REDUCED_CODEC")

func test_reduced_codec_node_overflow_is_not_reported_as_success() -> void:
	var metrics := Budget.static_measure(null, null)
	for profile in [5, 6]:
		var store := _store(profile)
		var reduced := _reduced(profile)
		var count: int = _variant_nodes(_actual_payload(_encode(store, reduced)))
		var items: Array = []
		items.resize(Codec.MAX_NODES - count + 1)
		items.fill(false)
		reduced["items"] = items
		assert_bool(_encode(store, reduced).is_empty()).is_true()
		var measured := Budget.measure_profile(store, profile, reduced, metrics)
		assert_bool(measured["ok"]).is_false()
		assert_str(measured["code"]).is_equal("TREE_GROUND_BUDGET_REDUCED_CODEC")

func test_dual_still_measures_outer_when_inner_rejects() -> void:
	var metrics := Budget.static_measure({}, {})
	var reduced5 := _reduced(5)
	reduced5["bad_depth"] = _chain(63)
	var reduced6 := _reduced(6)
	var store6 := _store(6)
	var result := Budget.measure_dual(_store(5), store6, reduced5, reduced6, metrics)
	assert_bool(result["ok"]).is_false()
	assert_int(result["failed_profile"]).is_equal(5)
	assert_str(result["profile5"]["code"]).is_equal("TREE_GROUND_BUDGET_REDUCED_CODEC")
	assert_bool(result["profile6"]["ok"]).is_true()
	assert_int(result["profile6"]["envelope_bytes"]).is_equal(_encode(store6, _full(reduced6, {}, {})).to_utf8_buffer().size())
	reduced6["bad_depth"] = _chain(63)
	result = Budget.measure_dual(_store(5), store6, reduced5, reduced6, metrics)
	assert_int(result["failed_profile"]).is_equal(5)
	assert_bool(result["profile5"]["ok"] or result["profile6"]["ok"]).is_false()

func test_wrong_encoder_script_is_rejected_without_calling_it() -> void:
	var metrics := Budget.static_measure({}, {})
	var wrong := WrongEncoder.new("", 1, 1, "content", 1, Callable(), 5, Budget.MAX_BYTES, true)
	for store in [null, 1, {}, RefCounted.new(), wrong]:
		var result := Budget.measure_profile(store, 5, _reduced(5), metrics)
		assert_bool(result["ok"]).is_false()
		assert_str(result["code"]).is_equal("TREE_GROUND_BUDGET_STORE_BINDING")
	assert_int(wrong.encode_calls).is_equal(0)

func test_profile_schema_exact_mode_and_four_mib_configuration_are_strict() -> void:
	var metrics := Budget.static_measure({}, {})
	for profile in [null, false, "5", 5.0, 4, 7]:
		assert_str(Budget.measure_profile(_store(5), profile, _reduced(5), metrics)["code"]).is_equal("TREE_GROUND_BUDGET_PROFILE")
	for profile in [5, 6]:
		var store := _store(6 if profile == 5 else 5)
		assert_str(Budget.measure_profile(store, profile, _reduced(profile), metrics)["code"]).is_equal("TREE_GROUND_BUDGET_STORE_BINDING")
		store = _store(profile)
		store._exact_scalars = false
		assert_bool(Budget.measure_profile(store, profile, _reduced(profile), metrics)["ok"]).is_false()
		store._exact_scalars = true
		for maximum in [0, Budget.MAX_BYTES - 1, Budget.MAX_BYTES + 1]:
			store._maximum_bytes = maximum
			assert_bool(Budget.measure_profile(store, profile, _reduced(profile), metrics)["ok"]).is_false()

func test_reduced_state_requires_present_null_static_fields_and_string_world_id() -> void:
	var metrics := Budget.static_measure({}, {})
	var store := _store(5)
	for invalid in [null, [], {}, {"world_id": 1}, {"world_id": "world"}]:
		assert_str(Budget.measure_profile(store, 5, invalid, metrics)["code"]).is_equal("TREE_GROUND_BUDGET_REDUCED_STATE")
	for field in ["world_component", "terrain_component"]:
		var reduced := _reduced(5)
		reduced.erase(field)
		assert_bool(Budget.measure_profile(store, 5, reduced, metrics)["ok"]).is_false()
		for value in [{}, [], false, "", 0]:
			reduced[field] = value
			assert_str(Budget.measure_profile(store, 5, reduced, metrics)["code"]).is_equal("TREE_GROUND_BUDGET_REDUCED_STATE")

func test_malformed_metrics_reject_without_coercion_or_indexing_errors() -> void:
	var metrics := Budget.static_measure({"fixed": [1, 2]}, {})
	var invalid: Array = [null, [], {}, RefCounted.new(), {"ok": true}]
	for field in ["ok", "measurement_only", "format", "codec_format", "root_depth", "maximum_bytes", "maximum_nodes", "maximum_depth", "null_escaped_bytes", "bytes_delta", "nodes_delta", "world", "terrain"]:
		var missing := metrics.duplicate(true)
		missing.erase(field)
		invalid.append(missing)
	var mutations: Array = [
		["ok", 1], ["measurement_only", false], ["format", "old_profile5_proof"],
		["codec_format", "json"], ["root_depth", 0], ["maximum_bytes", 1],
		["maximum_nodes", 99999], ["maximum_depth", 65], ["null_escaped_bytes", 0],
		["bytes_delta", metrics["bytes_delta"] + 1], ["bytes_delta", NAN],
		["bytes_delta", 9223372036854775807], ["nodes_delta", -1],
		["nodes_delta", float(metrics["nodes_delta"])], ["world", null], ["terrain", []],
	]
	for mutation in mutations:
		var changed := metrics.duplicate(true)
		changed[mutation[0]] = mutation[1]
		invalid.append(changed)
	for name in ["world", "terrain"]:
		for mutation in [["escaped_bytes", 0], ["escaped_bytes", INF], ["codec_nodes", 0], ["codec_nodes", 100001], ["codec_nodes", "1"], ["local_depth", -1], ["local_depth", 63], ["local_depth", 0.0]]:
			var changed := metrics.duplicate(true)
			changed[name][mutation[0]] = mutation[1]
			invalid.append(changed)
	var extra := metrics.duplicate(true)
	extra["authority"] = true
	invalid.append(extra)
	for value in invalid:
		var result := Budget.measure_profile(_store(5), 5, _reduced(5), value)
		assert_bool(result["ok"]).is_false()
		assert_str(result["code"]).is_equal("TREE_GROUND_BUDGET_STATIC_METRICS")

func test_static_codec_rejects_unsupported_nonfinite_bad_keys_and_cycles() -> void:
	for value in [RefCounted.new(), Vector2.ZERO, NAN, INF, {1: "non_string_key"}]:
		assert_bool(Budget.static_measure(value, {})["ok"]).is_false()
		assert_bool(Budget.static_measure({}, value)["ok"]).is_false()
	var cycle: Array = []
	cycle.append(cycle)
	var result := Budget.static_measure(cycle, {})
	cycle.clear()
	assert_bool(result["ok"]).is_false()
	assert_str(result["code"]).is_equal("EXACT_SCALAR_DEPTH_LIMIT")

func test_measurement_does_not_modify_sources_stores_or_dynamic_input() -> void:
	var world := {"fixed": TEXT}
	var terrain := {"fixed": [_negative_zero()]}
	var metrics := Budget.static_measure(world, terrain)
	var reduced5 := _reduced(5)
	var reduced6 := _reduced(6)
	var before := var_to_bytes([world, terrain, reduced5, reduced6, metrics])
	var store5 := _store(5)
	var store6 := _store(6)
	store5.last_error = {"untouched": 5}
	store6.last_error = {"untouched": 6}
	assert_bool(Budget.measure_dual(store5, store6, reduced5, reduced6, metrics)["ok"]).is_true()
	assert_bool(var_to_bytes([world, terrain, reduced5, reduced6, metrics]) == before).is_true()
	for pair in [[5, store5], [6, store6]]:
		var store: RefCounted = pair[1]
		assert_int(store.last_sequence).is_equal(0)
		assert_bool(store._write_ready or store._lock_owned).is_false()
		assert_int(store.last_error["untouched"]).is_equal(pair[0])
	# Dynamic payloads are measured afresh, even with the same static metrics.
	for text in ["小", TEXT, "z".repeat(1024)]:
		reduced6["inventory_component"]["dynamic"] = text
		var measured := Budget.measure_profile(store6, 6, reduced6, metrics)
		assert_int(measured["envelope_bytes"]).is_equal(_encode(store6, _full(reduced6, world, terrain)).to_utf8_buffer().size())
