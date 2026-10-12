extends GdUnitTestSuite
const Tokens = preload("res://tests/harvest/ground_normal_receipt012.gd")
func _text(owner_token: String, store_token: String) -> String:
	return '{\n  "receipt": {\n    "complete": true,\n    "generation": 1,\n    "main_committed": true,\n    "owner_id": %s,\n    "sequence": 4,\n    "state_sha256": "%s",\n    "store_id": %s\n  },\n  "sequence": 4\n}\n' % [owner_token, "a".repeat(64), store_token]
func test_actual_negative_and_signed64_endpoints_preserve_decimal_strings() -> void:
	assert_that(Tokens.read_tokens(_text("-9223371841047885779", "-9223371848966731824"))).is_equal({"owner_id": "-9223371841047885779", "store_id": "-9223371848966731824"})
	assert_that(Tokens.read_tokens(_text("-9223372036854775808", "9223372036854775807"))).is_equal({"owner_id": "-9223372036854775808", "store_id": "9223372036854775807"})
	assert_that(Tokens.read_tokens(_text("9007199254740992", "9007199254740993"))).is_equal({"owner_id": "9007199254740992", "store_id": "9007199254740993"})
func test_zero_and_noncanonical_decimal_tokens_are_rejected() -> void:
	for token in ["0", "-0", "+1", "01", "-01"]:
		assert_that(Tokens.read_tokens(_text(token, "1"))).is_equal({})
func test_boolean_float_exponent_and_quoted_integer_are_rejected() -> void:
	for token in ["true", "false", "1.0", "-123.0", "1e3", '"123"']:
		assert_that(Tokens.read_tokens(_text("1", token))).is_equal({})
func test_signed64_overflow_is_rejected() -> void:
	for token in ["9223372036854775808", "-9223372036854775809", "100000000000000000000"]:
		assert_that(Tokens.read_tokens(_text(token, "1"))).is_equal({})
func test_missing_duplicate_wrong_path_and_unbounded_text_are_rejected() -> void:
	assert_that(Tokens.read_tokens(_text("1", "2").replace('"receipt"', '"other"'))).is_equal({})
	assert_that(Tokens.read_tokens(_text("1", "2") + _text("1", "2"))).is_equal({})
	assert_that(Tokens.read_tokens(_text("1", "2").replace('    "owner_id": 1,', '    "owner_id": 1,\n    "owner_id": 2,'))).is_equal({})
	assert_that(Tokens.read_tokens(_text("1", "2") + " ".repeat(65537))).is_equal({})

	# Legal JSON may indent a nested receipt like the root; depth must still reject.
	var nested: String = '{"outer": ' + _text("1", "2").strip_edges() + '}\n'
	assert_that(Tokens.read_tokens(nested)).is_equal({})
	assert_that(Tokens.read_tokens(_text("1", "2").replace('"owner_id": 1,', '"owner_id": 1,,'))).is_equal({})
