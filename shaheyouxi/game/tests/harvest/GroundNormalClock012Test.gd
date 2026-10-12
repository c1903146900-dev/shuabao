extends GdUnitTestSuite
const Tokens = preload("res://tests/harvest/ground_normal_receipt012.gd")
const Codec = preload("res://scripts/save/exact_scalar_codec.gd")
func _exact(hex: String) -> float:
	var result: Dictionary = Codec.decode(["float64_le", hex])
	assert_bool(result.get("ok", false)).is_true()
	return result["value"]
func _bits(value: float) -> String:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, value)
	return bytes.hex_encode()
func _text(start: float, finish: float) -> String:
	return JSON.stringify({"world_seconds_start": start, "world_seconds_end": finish, "ground_world_seconds": finish, "ground_clock": finish, "step_seconds": 0.125}, "  ", true, true) + "\n"
func test_actual_clock_bits_and_raw_tokens_match_without_json_arithmetic() -> void:
	var start: float = _exact("605555555555ed3f")
	var finish: float = _exact("b0aaaaaaaaaaf03f")
	var text: String = _text(start, finish)
	var parsed: Dictionary = JSON.parse_string(text)
	assert_bool(start + 0.125 == finish).is_true()
	assert_bool(Tokens.clocks_match(text, start, finish)).is_true()
	print("TREE_CLOCK_JSON_DIAGNOSTIC exact_start=", _bits(start), " exact_end=", _bits(finish), " parsed_start=", _bits(parsed["world_seconds_start"]), " parsed_end=", _bits(parsed["world_seconds_end"]), " parsed_add=", _bits(parsed["world_seconds_start"] + 0.125))
func test_altered_and_equivalent_noncanonical_tokens_are_rejected() -> void:
	var start: float = _exact("605555555555ed3f")
	var finish: float = _exact("b0aaaaaaaaaaf03f")
	for token in ["1.041666666666668", "1.04166666666666790", '"1.0416666666666679"']:
		assert_bool(Tokens.clocks_match(_text(start, finish).replace("1.0416666666666679", token), start, finish)).is_false()
func test_nested_duplicate_or_missing_clock_metadata_is_rejected() -> void:
	var start: float = _exact("605555555555ed3f")
	var finish: float = _exact("b0aaaaaaaaaaf03f")
	var text: String = _text(start, finish)
	assert_bool(Tokens.clocks_match('{"outer": ' + text.strip_edges() + '}\n', start, finish)).is_false()
	assert_bool(Tokens.clocks_match(text + text, start, finish)).is_false()
	assert_bool(Tokens.clocks_match(text.replace('"ground_clock"', '"wrong_clock"'), start, finish)).is_false()
func test_wrong_exact_delta_and_nonfinite_input_are_rejected() -> void:
	var start: float = _exact("605555555555ed3f")
	var finish: float = _exact("b0aaaaaaaaaaf03f")
	assert_bool(Tokens.clocks_match(_text(start, finish), start, finish + 0.125)).is_false()
	assert_bool(Tokens.clocks_match(_text(start, finish), NAN, finish)).is_false()
	assert_bool(Tokens.clocks_match(_text(start, finish), start, INF)).is_false()
