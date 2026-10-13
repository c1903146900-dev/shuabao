extends RefCounted
## Explicitly versioned replacement boundary. No fallback if a table is absent/bad.
const Validator = preload("res://scripts/progression/catalog_validation.gd")
const SHOP_KEYS = ["items", "passives", "equipment_tasks"]

static func load_table(path: String, base: Dictionary, allow_provisional: bool = false) -> Dictionary:
 if not path.begins_with("res://") or not FileAccess.file_exists(path):
  return _denied("shop_table_missing")
 var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
 if not parsed is Dictionary: return _denied("shop_table_not_dictionary")
 if parsed.get("schema_version", 0) != 1: return _denied("shop_schema_mismatch")
 if str(parsed.get("table_version", "")).is_empty(): return _denied("shop_version_missing")
 if parsed.get("hero_id", "") != "yanguizhou": return _denied("shop_hero_mismatch")
 if not parsed.get("provisional") is bool: return _denied("shop_provisional_flag_missing")
 if parsed.provisional and not allow_provisional: return _denied("provisional_shop_not_allowed")
 var content: Dictionary = {}
 var binding: String = FileAccess.get_sha256(path)
 if parsed.get("mode", "") == "pinned_existing_fixture":
  if not parsed.provisional: return _denied("fixture_cannot_be_final")
  if not parsed.get("sources") is Array: return _denied("invalid_shop_sources")
  for source in parsed.get("sources", []):
   if not source is Dictionary: return _denied("invalid_shop_source")
   var source_path: String = str(source.get("path", ""))
   if not source_path.begins_with("res://") or not FileAccess.file_exists(source_path): return _denied("shop_source_missing")
   if FileAccess.get_sha256(source_path) != source.get("sha256", ""): return _denied("shop_source_digest_mismatch")
   binding += ":" + str(source.sha256)
  # Use the existing FINAL adapter's recovery/recipe rules unchanged, never the raw old rules.
  if parsed.get("sources", []).size() != 2: return _denied("fixture_source_count")
  if parsed.sources[0].path != "res://data/progression/prototype/catalog.json": return _denied("fixture_catalog_source")
  if parsed.sources[1].path != "res://data/final_design/equipment_tasks.json": return _denied("fixture_task_source")
  for key in SHOP_KEYS: content[key] = base.get(key, {}).duplicate(true)
 elif parsed.get("mode", "") == "replacement":
  if not parsed.get("content") is Dictionary: return _denied("shop_content_missing")
  content = parsed.content.duplicate(true)
  for key in content:
   if key not in SHOP_KEYS: return _denied("shop_unsupported_field:" + str(key))
 else:
  return _denied("shop_mode_unknown")
 var result: Dictionary = base.duplicate(true)
 for key in SHOP_KEYS:
  if not content.get(key) is Dictionary: return _denied("shop_field_missing:" + key)
  result[key] = content[key].duplicate(true)
 result.shop_table = {"table_version":parsed.table_version, "provisional":parsed.provisional, "binding":binding, "path":path}
 result.version = str(base.version) + "/shop/" + str(parsed.table_version) + "/" + binding
 var errors: Array = Validator.validate(result)
 if not errors.is_empty(): return {"accepted":false, "reason":"invalid_shop_catalog", "errors":errors}
 return {"accepted":true, "reason":"", "definitions":result, "binding":binding}

static func _denied(reason: String) -> Dictionary:
 return {"accepted":false, "reason":reason}
