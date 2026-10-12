extends RefCounted
## Leaf contract shared by Slots and launch Scope. No Registry/Core/Scope/runtime.
## Pure canonical decoding only; caller must own its library and reject links.
const Codec = preload("res://scripts/save/exact_scalar_codec.gd")
const TERRAIN_PROFILE := 4
const INVENTORY_PROFILE := 5
const CONTRACT := "sandbox012-world-inventory-v1"
const FILENAME := "save_profile.json"
const FIELDS := ["slot_id", "profile", "schema_version", "contract"]
const MAX_BYTES := 4096

static func make_value(slot_id: String) -> Dictionary:
	return {"slot_id": slot_id, "profile": INVENTORY_PROFILE, "schema_version": INVENTORY_PROFILE, "contract": CONTRACT}

static func validate(value: Variant, slot_id: Variant) -> Dictionary:
	if not _slot_id(slot_id) or not value is Dictionary or value.size() != FIELDS.size():
		return _bad()
	for field in FIELDS:
		if not value.has(field): return _bad()
	if not value["slot_id"] is String or value["slot_id"] != slot_id or typeof(value["profile"]) != TYPE_INT or value["profile"] != INVENTORY_PROFILE or typeof(value["schema_version"]) != TYPE_INT or value["schema_version"] != INVENTORY_PROFILE or not value["contract"] is String or value["contract"] != CONTRACT:
		return _bad()
	return {"ok": true}

static func decode_text(text: String, slot_id: Variant) -> Dictionary:
	if text.is_empty() or text.to_utf8_buffer().size() > MAX_BYTES:
		return _bad()
	var decoded: Dictionary = Codec.decode(JSON.parse_string(text))
	if not decoded.get("ok", false) or not validate(decoded.get("value"), slot_id)["ok"]:
		return _bad()
	var encoded: Dictionary = Codec.encode(decoded["value"])
	if not encoded["ok"] or text != JSON.stringify(encoded["value"], "", true, true):
		return _bad()
	return {"ok": true, "profile": INVENTORY_PROFILE, "marker_sha256": text.sha256_text()}

static func _slot_id(value: Variant) -> bool:
	if not value is String or value.length() != 32: return false
	for character in value:
		if character not in "0123456789abcdef": return false
	return true

static func _bad() -> Dictionary:
	return {"ok": false, "code": "SLOT_PROFILE_MARKER_INVALID"}
