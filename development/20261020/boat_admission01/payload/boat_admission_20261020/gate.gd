extends RefCounted
# Real current gameplay afters and exact predecessor preimages are distinct gates.
const MANIFEST="res://yan_p3_reimplementation_20261018b/migration.json"
const MANIFEST_SHA="4e6866b95b23fa57c3ca19db5f2cd639de03d9d1ec37ce369347ccb786ef2659"
const SOURCE="res://visual_rework_20261009/binding/source_binding.json"
const SOURCE_SHA="d427d29743011834b6d31d5492c4d0e761bb59227d122c7f3e2670c516d76e88"
const SELF="res://yan_p3_reimplementation_20261018b/gate.gd"
const SELF_SHA="41983b401bd8ae16d40e68fe2ab087fac67cf86ea719300f59bfde718a82b237"
const PRESENTATION_SCOPES={"res://scripts/ui/hero_chooser.gd":"source","res://visual_rework_20261009/controller.gd":"visual","res://visual_rework_20261009/views/q3_mountain_mesh.gd":"visual","res://visual_rework_20261009/views/q3_rock.gdshader":"visual","res://tests/ink_first_floor_enemy_views_20261004/fix01/roster_presenter.gd":"source","res://data/final_design/catalog.gd":"source","res://visual_rework_20261009/binding/c03_visual_source_successor.gd":"source","res://scripts/integration/hero_entry.gd":"source"}
static func deny(reason:String)->Dictionary:return {"accepted":false,"reason":"p3_migration:"+reason}
static func read(path:String)->Variant:return JSON.parse_string(_legacy_text(path))
static func _verify_predecessor()->Dictionary:
 var own:String=_legacy_text(SELF).replace(SELF_SHA,"@SELF@")
 if own.sha256_text()!=SELF_SHA:return deny("gate_changed")
 if _legacy_sha(MANIFEST)!=MANIFEST_SHA or _legacy_sha(SOURCE)!=SOURCE_SHA:return deny("manifest_or_source_changed")
 var m:Variant=read(MANIFEST)
 if not m is Dictionary or m.schema!="yan-p3-gameplay-migration-1" or m.changes.size()!=9:return deny("schema_or_exact_changes")
 if _legacy_sha(m.predecessor)!=m.predecessor_sha or _legacy_sha(m.visual_path)!=m.visual_sha:return deny("predecessor_or_visual_changed")
 var prior:Dictionary=read(m.predecessor)
 var current:Dictionary=read(SOURCE)
 if prior.runtime_map.size()!=1747 or current.runtime_map!=prior.runtime_map:return deny("historical_map_changed")
 if current.p3_gameplay_migration.path!=MANIFEST or current.p3_gameplay_migration.sha256!=MANIFEST_SHA or current.p3_gameplay_migration.runtime_candidates!=m.runtime_candidates:return deny("capability_not_bound")
 for path:String in m.changes:
  var c:Dictionary=m.changes[path]
  if prior.runtime_map.get(path,"")!=c.before:return deny("wrong_predecessor:"+path)
  if _legacy_sha(c.preimage)!=c.before:return deny("preimage_changed:"+path)
  if _legacy_sha(path)!=c.after:return deny("current_after_changed:"+path)
 var visual:Dictionary=read(m.visual_path)
 if visual.runtime_map.size()!=71:return deny("visual_map_size")
 var presentation:Dictionary=m.get("presentation_changes",{})
 if presentation.size()!=PRESENTATION_SCOPES.size():return deny("presentation_exact_changes")
 for path:String in PRESENTATION_SCOPES:
  if not presentation.has(path) or m.changes.has(path):return deny("presentation_path_missing_or_overlap:"+path)
  var c:Dictionary=presentation[path]
  var scope:String=str(PRESENTATION_SCOPES[path])
  if c.get("map_scope","")!=scope:return deny("presentation_scope_changed:"+path)
  var mapped:Dictionary=prior.runtime_map if scope=="source" else visual.runtime_map
  if mapped.get(path,"")!=c.get("before",""):return deny("presentation_wrong_predecessor:"+path)
  var expected_preimage:String="res://yan_p3_reimplementation_20261018b/presentation_preimages/"+path.trim_prefix("res://")
  if c.get("preimage","")!=expected_preimage or _legacy_sha(expected_preimage)!=c.before:return deny("presentation_preimage_changed:"+path)
  if _legacy_sha(path)!=c.get("after",""):return deny("presentation_after_changed:"+path)
 for path:String in m.added:
  if _legacy_sha(path)!=m.added[path]:return deny("added_resource_changed:"+path)
 return {"accepted":true}
static func _verify_predecessor_map(mapped:Dictionary)->Dictionary:
 var checked:Dictionary=_verify_predecessor()
 if not checked.accepted:return checked
 var m:Dictionary=read(MANIFEST)
 var prior:Dictionary=read(m.predecessor)
 var visual:Dictionary=read(m.visual_path)
 if visual.runtime_map.size()!=71:return deny("visual_map_size")
 if mapped!=prior.runtime_map and mapped!=visual.runtime_map:return deny("unauthorized_map")
 for path:String in mapped:
  var actual:String=path
  if m.changes.has(path):actual=m.changes[path].preimage
  elif m.presentation_changes.has(path):
   var c:Dictionary=m.presentation_changes[path]
   var expected:Dictionary=prior.runtime_map if c.map_scope=="source" else visual.runtime_map
   if mapped!=expected:return deny("presentation_map_scope_mismatch:"+path)
   actual=c.preimage
  if _legacy_sha(actual)!=str(mapped[path]):return deny("legacy_source_changed:"+path)
 return {"accepted":true}

const BOAT_MANIFEST="res://boat_admission_20261020/manifest.json"
const BOAT_MANIFEST_SHA="7c6e1464b70989c473527df0a5467fef10a9eaeaeff8cc12b97cda6cb3090e3c"
const BOAT_SELF="res://boat_admission_20261020/gate.gd"
const BOAT_SELF_SHA="cf955aa8234be9c3698d7396c0b9d180b6570d6b9298a2dbd3e8aef2ba934360"
const EXACT_CHANGED=["res://tests/ink_e2_boundary_20261006/ordinary01/e2_base.gd", "res://tests/ink_e2_boundary_20261006/ordinary01/e2_boundary.gd", "res://tests/ink_e2_boundary_20261006/ordinary01/sim.gd", "res://tests/ink_first_floor_boss_20261008/source01/enemy_director.gd", "res://visual_rework_20261009/views/e2_source_boat_view.gd", "res://tests/ink_river_hexes_20261006/frontdoor01/host.gd", "res://tests/ink_river_hexes_20261006/frontdoor01/floor_session.gd", "res://tests/ink_river_hexes_20261006/ordinary01/e_hud.gd", "res://visual_rework_20261009/binding/c03_visual_source_successor.gd"]
const PREDECESSOR_GATE_SHA="3fb342b9e1ae83c258bad0402b7cc60d45ab0088f137e633a877c788e746f180"
static func _boat_manifest() -> Dictionary:
 var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BOAT_MANIFEST))
 return parsed if parsed is Dictionary else {}
static func _legacy_path(path: String) -> String:
 # Only these exact current paths have a predecessor image. No wildcard or
 # missing-file fallback is allowed; verify() validates both images first.
 if path not in EXACT_CHANGED: return path
 return str(_boat_manifest().changes[path].preimage)
static func _legacy_sha(path: String) -> String: return FileAccess.get_sha256(_legacy_path(path))
static func _legacy_text(path: String) -> String: return FileAccess.get_file_as_string(_legacy_path(path))
static func _verify_current() -> Dictionary:
 if FileAccess.get_file_as_string(BOAT_SELF).replace(BOAT_SELF_SHA,"@SELF@").sha256_text()!=BOAT_SELF_SHA: return deny("boat_gate_changed")
 if FileAccess.get_sha256(BOAT_MANIFEST)!=BOAT_MANIFEST_SHA: return deny("boat_manifest_changed")
 if FileAccess.get_sha256(SELF)!=PREDECESSOR_GATE_SHA: return deny("boat_predecessor_validator_changed")
 var m: Dictionary = _boat_manifest()
 if m.get("schema","")!="boat-exact-source-successor-1" or m.get("changes",{}).size()!=EXACT_CHANGED.size(): return deny("boat_exact_changes_required")
 if m.get("hooks_before",[])!=["hex.final_design.yanguizhou_h01.v1", "hex.final_design.yanguizhou_h02.v1", "hex.final_design.yanguizhou_h03.v1", "hex.final_design.yanguizhou_h04.v1", "hex.final_design.yanguizhou_h05.v1", "hex.final_design.yanguizhou_h06.v1", "hex.final_design.common_g01.v1", "hex.final_design.common_g05.v1", "hex.final_design.common_g06.v1", "hex.final_design.common_g15.v1", "hex.final_design.common_g24.v1", "hex.final_design.common_g30.v1"] or m.get("hooks_after",[])!=["hex.final_design.yanguizhou_h01.v1", "hex.final_design.yanguizhou_h02.v1", "hex.final_design.yanguizhou_h03.v1", "hex.final_design.yanguizhou_h04.v1", "hex.final_design.yanguizhou_h05.v1", "hex.final_design.yanguizhou_h06.v1", "hex.final_design.common_g01.v1", "hex.final_design.common_g05.v1", "hex.final_design.common_g06.v1", "hex.final_design.common_g15.v1", "hex.final_design.common_g24.v1", "hex.final_design.common_g30.v1", "hex.final_design.yanguizhou_h09.v1", "hex.final_design.yanguizhou_h10.v1"]: return deny("boat_hook_delta_changed")
 for path: String in EXACT_CHANGED:
  if not m.changes.has(path): return deny("boat_missing_change:"+path)
  var c: Dictionary = m.changes[path]
  var exact_preimage: String = "res://boat_admission_20261020/preimages/"+path.trim_prefix("res://")
  if c.get("preimage","")!=exact_preimage or FileAccess.get_sha256(exact_preimage)!=c.get("before",""): return deny("boat_preimage_changed:"+path)
  if FileAccess.get_sha256(path)!=c.get("after",""): return deny("boat_after_changed:"+path)
 for path: String in m.added:
  if FileAccess.get_sha256(path)!=str(m.added[path]): return deny("boat_added_changed:"+path)
 for path: String in m.predecessor_authorities:
  if FileAccess.get_sha256(path)!=str(m.predecessor_authorities[path]): return deny("boat_predecessor_authority_changed:"+path)
 return {"accepted":true}
static func verify() -> Dictionary:
 var current: Dictionary = _verify_current()
 if not current.accepted: return current
 return _verify_predecessor()
static func verify_legacy_map(mapped: Dictionary) -> Dictionary:
 var current: Dictionary = _verify_current()
 if not current.accepted: return current
 return _verify_predecessor_map(mapped)
