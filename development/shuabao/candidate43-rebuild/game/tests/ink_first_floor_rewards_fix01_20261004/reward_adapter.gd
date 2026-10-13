extends RefCounted
## One opt-in numeric format. No progression authority and no unknown-kind fallback.
const VERSION := "first_floor_reward_adapter_v01"
const TABLE_VERSION := "authored_trial_v01"
const ROUTE_SHA256 := "dbd1a6d49bcd574f1ccac19f1fa98bbb1dd9b6e27f120f41866d7567f01d21bd"
const KINDS := ["minion", "ranged", "pouncer", "pitcher", "support", "armored", "elite", "boss"]
const SOURCE := {"minion":{"gold":20,"xp":12},"ranged":{"gold":20,"xp":12},"pouncer":{"gold":20,"xp":12},"pitcher":{"gold":20,"xp":12},"support":{"gold":20,"xp":12},"armored":{"gold":35,"xp":20},"elite":{"gold":100,"xp":80},"boss":{"gold":300,"xp":160}}
const CSV_FIELDS := ["enemy_kind", "gold", "xp", "source_gold", "source_xp", "status"]
const EXCLUDED := ["xp_curve", "r_gate", "sp_budget", "gear_prices", "mechanics", "roster", "topology", "free_grants", "drops"]
const TABLE_FIELDS := ["adapter_version", "schema_version", "table_version", "hero_id", "floor_id", "status", "provisional", "runtime_wired", "balanced_pass", "topology_status", "topology_approved", "input_sha256", "metadata_sha256", "route_sha256", "reward_units", "unknown_kind_policy", "rewards", "original_source_rewards", "excluded_overrides", "verification_scope"]

static func _deny(reason: String) -> Dictionary:
 return {"accepted":false, "reason":reason}

static func _exact_keys(value: Dictionary, keys: Array) -> bool:
 if value.size() != keys.size(): return false
 for key in keys:
  if not value.has(key): return false
 return true

static func _integer(value: Variant) -> bool:
 if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT: return false
 return is_finite(float(value)) and float(value) >= 0 and float(value) <= 1000000 and floor(float(value)) == float(value)

static func _digest(value: Variant) -> bool:
 if not value is String or value.length() != 64: return false
 for character in value:
  if character not in "0123456789abcdef": return false
 return true

static func validate_table(value: Variant) -> Dictionary:
 if not value is Dictionary or not _exact_keys(value, TABLE_FIELDS): return _deny("reward_table_fields_invalid")
 if value.adapter_version != VERSION or value.schema_version != 2 or value.table_version != TABLE_VERSION or value.hero_id != "yanguizhou" or value.floor_id != "first_floor": return _deny("reward_table_identity_invalid")
 for flag in ["provisional", "runtime_wired", "balanced_pass", "topology_approved"]:
  if typeof(value[flag]) != TYPE_BOOL: return _deny("reward_table_boolean_required:" + flag)
 if value.status != "authored_numeric_trial" or value.provisional != true or value.runtime_wired != false or value.balanced_pass != false or value.topology_status != "developer_proposal" or value.topology_approved != false: return _deny("reward_table_scope_invalid")
 if value.unknown_kind_policy != "reject_no_fallback" or value.excluded_overrides != EXCLUDED or value.verification_scope != "static_source_and_numeric_only": return _deny("reward_table_contract_invalid")
 if value.reward_units != {"gold":"integer_gold_per_verified_kill","xp":"integer_xp_per_verified_kill"}: return _deny("reward_units_invalid")
 if value.route_sha256 != ROUTE_SHA256 or not _digest(value.input_sha256) or not _digest(value.metadata_sha256): return _deny("reward_source_identity_invalid")
 if not value.rewards is Dictionary or not _exact_keys(value.rewards, KINDS): return _deny("reward_kind_set_invalid")
 # JSON numeric values are floats. Dictionary equality is type-sensitive, so
 # validate archive values semantically without weakening integer/type checks.
 if not value.original_source_rewards is Dictionary or not _exact_keys(value.original_source_rewards, KINDS): return _deny("original_source_rewards_changed")
 for kind in KINDS:
  var archived: Variant = value.original_source_rewards[kind]
  if not archived is Dictionary or not _exact_keys(archived, ["gold", "xp"]): return _deny("original_source_rewards_changed")
  for unit in ["gold", "xp"]:
   if not _integer(archived[unit]) or int(archived[unit]) != SOURCE[kind][unit]: return _deny("original_source_rewards_changed")
 var normalized: Dictionary = {}
 for kind in KINDS:
  var row: Variant = value.rewards[kind]
  if not row is Dictionary or not _exact_keys(row, ["gold", "xp"]): return _deny("reward_row_invalid:" + kind)
  if not _integer(row.gold) or not _integer(row.xp): return _deny("reward_nonnegative_integer_required:" + kind)
  normalized[kind] = {"gold":int(row.gold), "xp":int(row.xp)}
 return {"accepted":true, "reason":"", "rewards":normalized}

static func validate_csv(path: String, rewards: Dictionary) -> Dictionary:
 var file := FileAccess.open(path, FileAccess.READ)
 if file == null: return _deny("reward_csv_missing")
 if Array(file.get_csv_line()) != CSV_FIELDS: return _deny("reward_csv_header_invalid")
 var seen: Dictionary = {}
 var integer_pattern := RegEx.new()
 integer_pattern.compile("^(0|[1-9][0-9]*)$")
 while file.get_position() < file.get_length():
  var columns: PackedStringArray = file.get_csv_line()
  if columns.size() != 6: return _deny("reward_csv_row_invalid")
  var kind: String = columns[0]
  if kind not in KINDS or seen.has(kind): return _deny("reward_csv_kind_invalid")
  if columns[5] != TABLE_VERSION: return _deny("reward_csv_status_invalid")
  for index in range(1, 5):
   if integer_pattern.search(columns[index]) == null or columns[index].length() > 7 or int(columns[index]) > 1000000: return _deny("reward_csv_integer_invalid")
  if int(columns[1]) != rewards[kind].gold or int(columns[2]) != rewards[kind].xp: return _deny("reward_csv_compilation_stale")
  if int(columns[3]) != SOURCE[kind].gold or int(columns[4]) != SOURCE[kind].xp: return _deny("reward_csv_source_changed")
  seen[kind] = true
 file.close()
 if not _exact_keys(seen, KINDS): return _deny("reward_csv_kind_missing")
 return {"accepted":true, "reason":""}

static func load_table(table_path: String, csv_path: String, receipt_path: String, allow_trial: bool = false) -> Dictionary:
 if not allow_trial: return _deny("authored_numeric_trial_opt_in_required")
 for path in [table_path, csv_path, receipt_path]:
  if path.is_empty() or not FileAccess.file_exists(path): return _deny("reward_input_missing:" + path)
 var table: Variant = JSON.parse_string(FileAccess.get_file_as_string(table_path))
 var checked: Dictionary = validate_table(table)
 if not checked.accepted: return checked
 var receipt: Variant = JSON.parse_string(FileAccess.get_file_as_string(receipt_path))
 if not receipt is Dictionary or receipt.get("numeric_validation_pass") != true or receipt.get("adapter_version", "") != VERSION or receipt.get("table_version", "") != TABLE_VERSION: return _deny("reward_validation_receipt_invalid")
 if typeof(receipt.get("numeric_validation_pass")) != TYPE_BOOL or typeof(receipt.get("numeric_targets_met")) != TYPE_BOOL or not receipt.get("pacing_warnings") is Array: return _deny("reward_validation_receipt_types")
 for warning in receipt.pacing_warnings:
  if not warning is String: return _deny("reward_validation_warning_type")
 var digest: String = FileAccess.get_sha256(table_path)
 if receipt.get("active_config_sha256", "") != digest or receipt.get("csv_sha256", "") != FileAccess.get_sha256(csv_path) or table.input_sha256 != receipt.csv_sha256 or receipt.get("metadata_sha256", "") != table.metadata_sha256: return _deny("reward_validation_digest_mismatch")
 var csv_checked: Dictionary = validate_csv(csv_path, checked.rewards)
 if not csv_checked.accepted: return csv_checked
 # Pacing warnings do not invalidate otherwise valid numeric values.
 return {"accepted":true, "reason":"", "rewards":checked.rewards, "binding":{"adapter_version":VERSION, "table_version":TABLE_VERSION, "table_sha256":digest, "csv_sha256":receipt.csv_sha256, "path":table_path, "numeric_targets_met":receipt.get("numeric_targets_met", false), "pacing_warnings":receipt.get("pacing_warnings", []).duplicate(true), "balanced_gameplay":false}}
