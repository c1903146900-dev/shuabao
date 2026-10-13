extends RefCounted
## Exact three-file C03 successor for the preserved original Q3 visual source map.
const PLAN_PATH="res://visual_rework_20261009/binding/equipment46_plan.json"
const PLAN_SHA="1ea8767407599d4299940ae6946c320e663e7fc56bfd351cffc0af27a13d7432"
const PATHS=["scripts/combat/hero_combat_core.gd","tests/ink_q1_foundation_20261004/revision02/scripts/ink_sim.gd","tests/ink_q3_foundation_20261004/fix02/ink_q3_sim.gd"]
const SWIFT_PLAN_PATH="res://visual_rework_20261009/binding/swift05_projection_transition.json"
const SWIFT_PLAN_SHA="a45b51aeaa9851d1a0e38270e6136e4269a1028485155dbc1b1771c5f8e0b478"
const SWIFT_COMMON="scripts/combat/common_hex_bridge.gd"
static func _previous_expected_sha(path:String,original:String)->String:
 if path==SWIFT_COMMON:return _swift_expected(original)
 if path not in PATHS:return original
 if FileAccess.get_sha256(PLAN_PATH)!=PLAN_SHA:return ""
 var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(PLAN_PATH))
 if not parsed is Dictionary:return ""
 var changes:Variant=parsed.get("changes",{})
 if not changes is Dictionary:return ""
 var row:Variant=changes.get(path,{})
 if not row is Dictionary or row.size()!=2 or not row.has("before") or not row.has("after"):return ""
 if typeof(row.before)!=TYPE_STRING or typeof(row.after)!=TYPE_STRING or row.before!=original or row.after.length()!=64:return ""
 return row.after

static func _swift_expected(original:String)->String:
 if FileAccess.get_sha256(SWIFT_PLAN_PATH)!=SWIFT_PLAN_SHA:return ""
 var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(SWIFT_PLAN_PATH))
 if not parsed is Dictionary or parsed.get("schema","")!="swift05-common-projection-visual-successor-1":return ""
 var changes:Variant=parsed.get("changes",{})
 if not changes is Dictionary or changes.size()!=1 or not changes.has(SWIFT_COMMON):return ""
 var row:Variant=changes[SWIFT_COMMON]
 if not row is Dictionary or row.size()!=2 or not row.has("before") or not row.has("after"):return ""
 if typeof(row.before)!=TYPE_STRING or typeof(row.after)!=TYPE_STRING or row.before!=original or row.after.length()!=64:return ""
 return row.after

const G01_PLAN_PATH="res://visual_rework_20261009/binding/g01_visual_source_transition.json"
const G01_PLAN_SHA="8408501ae0a52ef9a9d6391c542d1cd6ff56b8151875be80c6d9309135b248e8"
const G01_PATHS=["scripts/combat/enemy_director.gd","scripts/combat/hero_combat_core.gd","tests/ink_q1_foundation_20261004/revision02/scripts/ink_sim.gd","tests/ink_q1_h02_20261004/ink_h02_sim.gd","tests/ink_q3_foundation_20261004/ink_q3_enemy_director.gd","tests/ink_q3_foundation_20261004/fix02/ink_q3_sim.gd"]
static func _g01_expected_sha(path:String,original:String)->String:
 var previous:String=_previous_expected_sha(path,original)
 if previous.is_empty() or path not in G01_PATHS:return previous
 if FileAccess.get_sha256(G01_PLAN_PATH)!=G01_PLAN_SHA:return ""
 var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(G01_PLAN_PATH))
 if not parsed is Dictionary or parsed.get("schema","")!="g01-six-source-visual-successor-1":return ""
 var changes:Variant=parsed.get("changes")
 if not changes is Dictionary or changes.size()!=G01_PATHS.size():return ""
 for allowed:String in G01_PATHS:
  if not changes.has(allowed):return ""
 var row:Variant=changes[path]
 if not row is Dictionary or row.size()!=2 or not row.has("before") or not row.has("after"):return ""
 if typeof(row.before)!=TYPE_STRING or typeof(row.after)!=TYPE_STRING or row.before!=previous or row.after.length()!=64:return ""
 return row.after

const G01_SYNC_PATH="res://visual_rework_20261009/binding/g01_sync_visual_transition.json"
const G01_SYNC_SHA="7a060e10892d62e8afb9dc8571b2b5107bc6747d46fde791fbcd083cf6dba483"
const G01_SYNC_PATHS=["scripts/combat/hero_combat_core.gd","tests/ink_q1_foundation_20261004/revision02/scripts/ink_sim.gd"]
static func _g01_sync_expected_sha(path:String,original:String)->String:
 var previous:String=_g01_expected_sha(path,original)
 if previous.is_empty() or path not in G01_SYNC_PATHS:return previous
 if FileAccess.get_sha256(G01_SYNC_PATH)!=G01_SYNC_SHA:return ""
 var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(G01_SYNC_PATH))
 if not parsed is Dictionary or parsed.get("schema","")!="g01-sync-two-source-visual-successor-1":return ""
 var changes:Variant=parsed.get("changes")
 if not changes is Dictionary or changes.size()!=G01_SYNC_PATHS.size():return ""
 for allowed:String in G01_SYNC_PATHS:
  if not changes.has(allowed):return ""
 var row:Variant=changes[path]
 if not row is Dictionary or row.size()!=2 or not row.has("before") or not row.has("after"):return ""
 if typeof(row.before)!=TYPE_STRING or typeof(row.after)!=TYPE_STRING or row.before!=previous or row.after.length()!=64:return ""
 return row.after

## Only the three audited C02 source successors; preserve every previous stage.
const C02_PLAN_PATH="res://visual_rework_20261009/binding/c02_visual_source_transition.json"
const C02_PLAN_SHA="6f6bc82dd5f09bd491e991c53169effd8ff2bb97eb3c9d0b60af6c9c15cb163a"
const C02_PATHS=["scripts/combat/hero_combat_core.gd","tests/ink_q1_foundation_20261004/revision02/scripts/ink_sim.gd","tests/ink_q3_foundation_20261004/fix02/ink_q3_sim.gd"]
static func _c02_expected_sha(path:String,original:String)->String:
 var previous:String=_g01_sync_expected_sha(path,original)
 if previous.is_empty() or path not in C02_PATHS:return previous
 if FileAccess.get_sha256(C02_PLAN_PATH)!=C02_PLAN_SHA:return ""
 var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(C02_PLAN_PATH))
 if not parsed is Dictionary or parsed.get("schema","")!="c02-three-source-visual-successor-1":return ""
 var changes:Variant=parsed.get("changes")
 if not changes is Dictionary or changes.size()!=C02_PATHS.size():return ""
 for allowed:String in C02_PATHS:
  if not changes.has(allowed):return ""
 var row:Variant=changes[path]
 if not row is Dictionary or row.size()!=2 or not row.has("before") or not row.has("after"):return ""
 if typeof(row.before)!=TYPE_STRING or typeof(row.after)!=TYPE_STRING or row.before!=previous or row.after.length()!=64:return ""
 return row.after

# D06 append-only successor after the exact original C03/G01/Swift/C02 chain.
const D06_PLAN_PATH="res://visual_rework_20261009/binding/d06_visual_source_transition.json"
const D06_PLAN_SHA="724603a5f4f9e0ff2fa4342d8d85f09aba607a41492d2ec919fd239835e1a5a9"
const D06_PATHS=["scripts/combat/hero_combat_core.gd"]
static func _d06_expected_sha(path:String,original:String)->String:
 var previous:String=_c02_expected_sha(path,original)
 if previous.is_empty() or path not in D06_PATHS:return previous
 if FileAccess.get_sha256(D06_PLAN_PATH)!=D06_PLAN_SHA:return ""
 var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(D06_PLAN_PATH))
 if not parsed is Dictionary or parsed.get("schema","")!="d06-one-source-visual-successor-1":return ""
 var changes:Variant=parsed.get("changes")
 if not changes is Dictionary or changes.size()!=D06_PATHS.size():return ""
 for allowed:String in D06_PATHS:
  if not changes.has(allowed):return ""
 var row:Variant=changes[path]
 if not row is Dictionary or row.size()!=2 or not row.has("before") or not row.has("after"):return ""
 if typeof(row.before)!=TYPE_STRING or typeof(row.after)!=TYPE_STRING or row.before!=previous or row.after.length()!=64:return ""
 return row.after

# G04 append-only kernel-source successor after the exact existing D06 chain.
const G04_PLAN_PATH="res://visual_rework_20261009/binding/g04_visual_source_transition.json"
const G04_PLAN_SHA="d86a4b9a64862680557c998d26207c4850b6f6d3c1f75e9473a40ef8a4af8525"
const G04_PATHS=["tests/equipment_shop_transactions_20261004/shop_visit_model.gd"]
static func _g04_expected_sha(path:String,original:String)->String:
 var previous:String=_d06_expected_sha(path,original)
 if previous.is_empty() or path not in G04_PATHS:return previous
 if FileAccess.get_sha256(G04_PLAN_PATH)!=G04_PLAN_SHA:return ""
 var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(G04_PLAN_PATH))
 if not parsed is Dictionary or parsed.get("schema","")!="g04-one-kernel-visual-source-successor-1":return ""
 var changes:Variant=parsed.get("changes")
 if not changes is Dictionary or changes.size()!=G04_PATHS.size():return ""
 for allowed:String in G04_PATHS:
  if not changes.has(allowed):return ""
 var row:Variant=changes[path]
 if not row is Dictionary or row.size()!=2 or not row.has("before") or not row.has("after"):return ""
 if typeof(row.before)!=TYPE_STRING or typeof(row.after)!=TYPE_STRING or row.before!=previous or row.after.length()!=64:return ""
 return row.after

# G27 append-only single stat-consumer correction after the exact G04 chain.
const G27_PLAN_PATH="res://visual_rework_20261009/binding/g27_visual_source_transition.json"
const G27_PLAN_SHA="053da5ff9079837b0a0e6048f86bf370ba6bcdd7c53fa9f892c6dac4021273ef"
const G27_PATHS=["tests/ink_shop_runtime_stats_20261004/ink_stat_run_model.gd"]
static func expected_sha(path:String,original:String)->String:
 var previous:String=_g04_expected_sha(path,original)
 if previous.is_empty() or path not in G27_PATHS:return previous
 if FileAccess.get_sha256(G27_PLAN_PATH)!=G27_PLAN_SHA:return ""
 var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(G27_PLAN_PATH))
 if not parsed is Dictionary or parsed.get("schema","")!="g27-one-stat-consumer-visual-source-successor-1":return ""
 var changes:Variant=parsed.get("changes")
 if not changes is Dictionary or changes.size()!=G27_PATHS.size():return ""
 for allowed:String in G27_PATHS:
  if not changes.has(allowed):return ""
 var row:Variant=changes[path]
 if not row is Dictionary or row.size()!=2 or not row.has("before") or not row.has("after"):return ""
 if typeof(row.before)!=TYPE_STRING or typeof(row.after)!=TYPE_STRING or row.before!=previous or row.after.length()!=64:return ""
 return row.after
