extends RefCounted
## Exact three-file C03 successor for the preserved original Q3 visual source map.
const PLAN_PATH="res://visual_rework_20261009/binding/equipment46_plan.json"
const PLAN_SHA="1ea8767407599d4299940ae6946c320e663e7fc56bfd351cffc0af27a13d7432"
const PATHS=["scripts/combat/hero_combat_core.gd","tests/ink_q1_foundation_20261004/revision02/scripts/ink_sim.gd","tests/ink_q3_foundation_20261004/fix02/ink_q3_sim.gd"]
const SWIFT_PLAN_PATH="res://visual_rework_20261009/binding/swift05_projection_transition.json"
const SWIFT_PLAN_SHA="a45b51aeaa9851d1a0e38270e6136e4269a1028485155dbc1b1771c5f8e0b478"
const SWIFT_COMMON="scripts/combat/common_hex_bridge.gd"
static func expected_sha(path:String,original:String)->String:
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
