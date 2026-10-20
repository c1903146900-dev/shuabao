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
static func _before_catalog_expected_sha(path:String,original:String)->String:
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


## One exact Catalog successor. Historical Q3 maps remain unchanged.
const CatalogRuntimeGate=preload("res://boat_admission_20261020/gate.gd")
const CATALOG_PATH="data/final_design/catalog.gd"
const CATALOG_BEFORE="c1c7ea3fa9b3dc871ee0c4fe4372a38728c7c2cb51f123438ae0300c2cfbbeb9"
const CATALOG_AFTER="196c4b1a33d78876c21bd8bc6a55a00445651d54f3b0224dbaaaeeb39ae67afc"
const CATALOG_PREIMAGE="res://yan_p3_reimplementation_20261018b/presentation_preimages/data/final_design/catalog.gd"
static func expected_sha(path:String,original:String)->String:
 if path!=CATALOG_PATH:return _before_catalog_expected_sha(path,original)
 if original!=CATALOG_BEFORE:return ""
 var verified:Dictionary=CatalogRuntimeGate.verify()
 if not verified.get("accepted",false):return ""
 var migration:Variant=CatalogRuntimeGate.read(CatalogRuntimeGate.MANIFEST)
 if not migration is Dictionary:return ""
 var presentation:Variant=migration.get("presentation_changes",{})
 if not presentation is Dictionary:return ""
 var row:Variant=presentation.get("res://"+CATALOG_PATH,{})
 if not row is Dictionary or row.size()!=4:return ""
 if row!={"map_scope":"source","before":CATALOG_BEFORE,"after":CATALOG_AFTER,"preimage":CATALOG_PREIMAGE}:return ""
 var prior:Variant=CatalogRuntimeGate.read(migration.predecessor)
 if not prior is Dictionary or prior.get("runtime_map",{}).get("res://"+CATALOG_PATH,"")!=CATALOG_BEFORE:return ""
 if FileAccess.get_sha256(CATALOG_PREIMAGE)!=CATALOG_BEFORE:return ""
 if FileAccess.get_sha256("res://"+CATALOG_PATH)!=CATALOG_AFTER:return ""
 return CATALOG_AFTER
