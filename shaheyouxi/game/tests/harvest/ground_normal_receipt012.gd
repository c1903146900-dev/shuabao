extends RefCounted
## Test-metadata reader for the exact JSON.stringify(index, "  ", true, true)
## producer format. It does not parse arbitrary JSON or establish live identity.
## Preserve old signed64 object IDs as decimal strings; never round via double.
static func read_tokens(text: String) -> Dictionary:
	if text.length() > 65536: return {}
	var block_pattern: RegEx = RegEx.new()
	if block_pattern.compile('(?m)^  "receipt": \\{\\n((?:    [^\\n]+\\n)+)  \\},?\\n') != OK: return {}
	var blocks: Array = block_pattern.search_all(text)
	if blocks.size() != 1 or not _root_object_prefix(text, blocks[0].get_start()): return {}
	var line_pattern: RegEx = RegEx.new()
	if line_pattern.compile('^    "([a-z_][a-z0-9_]*)": ([^,]+),?$') != OK: return {}
	var fields: Dictionary = {}
	for line in blocks[0].get_string(1).split("\n", false):
		var matched: RegExMatch = line_pattern.search(line)
		if matched == null: return {}
		var key: String = matched.get_string(1)
		if fields.has(key): return {}
		var token: String = matched.get_string(2)
		fields[key] = token
	if fields.size() != 7: return {}
	for key in ["owner_id", "generation", "store_id", "sequence", "state_sha256", "main_committed", "complete"]:
		if not fields.has(key): return {}
	if not _signed_id(fields["owner_id"]) or not _signed_id(fields["store_id"]): return {}
	return {"owner_id": fields["owner_id"], "store_id": fields["store_id"]}

static func _signed_id(token: String) -> bool:
	var negative: bool = token.begins_with("-")
	var digits: String = token.substr(1) if negative else token
	if digits.is_empty() or digits.length() > 19 or digits.begins_with("0"): return false
	for character in digits:
		if character not in "0123456789": return false
	var limit: String = "9223372036854775808" if negative else "9223372036854775807"
	return digits.length() < 19 or digits <= limit

static func _root_object_prefix(text: String, offset: int) -> bool:
	var stack: Array = []
	var quoted: bool = false
	var escaped: bool = false
	for character in text.substr(0, offset):
		if quoted:
			if escaped: escaped = false
			elif character == "\\": escaped = true
			elif character == '"': quoted = false
		elif character == '"': quoted = true
		elif character in ["{", "["]: stack.append(character)
		elif character in ["}", "]"]:
			if stack.is_empty(): return false
			var opening: String = stack.pop_back()
			if (character == "}" and opening != "{") or (character == "]" and opening != "["): return false
	return not quoted and stack == ["{"]

## Metadata clock proof for this one .125 technical tick only. Both arguments
## must come from the original ExactCodec states, never JSON.parse numbers.
static func clocks_match(text: String, exact_start: float, exact_end: float) -> bool:
	if not is_finite(exact_start) or not is_finite(exact_end) or exact_start < 0.0 or exact_end != exact_start + 0.125: return false
	var values: Dictionary = {"world_seconds_start": exact_start, "world_seconds_end": exact_end, "ground_world_seconds": exact_end, "ground_clock": exact_end, "step_seconds": 0.125}
	for key in values:
		if _root_clock_token(text, key) != JSON.stringify(values[key], "", true, true): return false
	return true

static func _root_clock_token(text: String, key: String) -> String:
	if text.length() > 65536 or key not in ["world_seconds_start", "world_seconds_end", "ground_world_seconds", "ground_clock", "step_seconds"]: return ""
	var pattern: RegEx = RegEx.new()
	if pattern.compile('(?m)^  "' + key + '": ([^,\\n]+),?$') != OK: return ""
	var matches: Array = pattern.search_all(text)
	if matches.size() != 1 or not _root_object_prefix(text, matches[0].get_start()): return ""
	return matches[0].get_string(1)
