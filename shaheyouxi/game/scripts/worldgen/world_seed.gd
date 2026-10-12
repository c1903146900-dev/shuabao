extends RefCounted
## Integer seed contract. Canonical decimal persistence avoids JSON float loss.
const POSITIVE_LIMIT := "9223372036854775807"
const NEGATIVE_MAGNITUDE_LIMIT := "9223372036854775808"

static func from_integer(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_INT:
		return {"ok": false, "code": "SEED_MUST_BE_EXPLICIT_INTEGER"}
	return {"ok": true, "value": value, "decimal": str(value)}

static func from_decimal(value: Variant) -> Dictionary:
	if not value is String or value.is_empty():
		return {"ok": false, "code": "INVALID_SAVED_SEED"}
	var negative: bool = value.begins_with("-")
	var digits: String = value.substr(1) if negative else value
	if digits.is_empty() or digits.length() > 19 or (digits.length() > 1 and digits.begins_with("0")) or (negative and digits == "0"):
		return {"ok": false, "code": "INVALID_SAVED_SEED"}
	for character in digits:
		if character not in "0123456789":
			return {"ok": false, "code": "INVALID_SAVED_SEED"}
	var limit: String = NEGATIVE_MAGNITUDE_LIMIT if negative else POSITIVE_LIMIT
	if digits.length() == 19 and digits > limit:
		return {"ok": false, "code": "SEED_OUT_OF_INT64_RANGE"}
	# Conversion is only attempted after lexical overflow validation.
	return from_integer(value.to_int())

static func choose_for_server_creation(requested: Variant, test_entry: bool, random_provider: Callable) -> Dictionary:
	if requested != null:
		return from_integer(requested)
	if test_entry:
		return {"ok": false, "code": "TEST_ENTRY_REQUIRES_SEED"}
	if not random_provider.is_valid():
		return {"ok": false, "code": "SERVER_RANDOM_SOURCE_MISSING"}
	# Exactly one call. Failed input/randomness never retries to pick a nicer world.
	return from_integer(random_provider.call())

static func server_random_integer() -> Variant:
	var bytes := Crypto.new().generate_random_bytes(8)
	if bytes.size() != 8:
		return null
	return bytes.decode_s64(0)
