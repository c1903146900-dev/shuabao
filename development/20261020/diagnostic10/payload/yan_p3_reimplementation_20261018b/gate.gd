extends RefCounted
# Real current gameplay afters and exact predecessor preimages are distinct gates.
const MANIFEST="res://yan_p3_reimplementation_20261018b/migration.json"
const MANIFEST_SHA="9439c9cfb759cf6f095909e6c02d77e06be7c6fe9f971b4e6bfaf60ad52cc8fa"
const SOURCE="res://visual_rework_20261009/binding/source_binding.json"
const SOURCE_SHA="1b207ab660e3fba88f7890512efd9e81fd10a3a680ccc72de1c11d4039b6920e"
const SELF="res://yan_p3_reimplementation_20261018b/gate.gd"
const SELF_SHA="022db65916be433beedde2e362c083b63e536ab6333d45fd21de1197d78803e3"
const PRESENTATION_SCOPES={"res://scripts/ui/hero_chooser.gd":"source","res://visual_rework_20261009/controller.gd":"visual","res://visual_rework_20261009/views/q3_mountain_mesh.gd":"visual","res://visual_rework_20261009/views/q3_rock.gdshader":"visual","res://tests/ink_first_floor_enemy_views_20261004/fix01/roster_presenter.gd":"source","res://data/final_design/catalog.gd":"source","res://visual_rework_20261009/binding/c03_visual_source_successor.gd":"source","res://scripts/integration/hero_entry.gd":"source","res://tests/ink_style_specimen_20261004/revision03/fix01/host.gd":"source","res://tests/ink_first_floor_user_route_20261005/runtime01/host.gd":"source"}
static func deny(reason:String)->Dictionary:return {"accepted":false,"reason":"p3_migration:"+reason}
static func read(path:String)->Variant:return JSON.parse_string(FileAccess.get_file_as_string(path))
static func verify()->Dictionary:
 var own:String=FileAccess.get_file_as_string(SELF).replace(SELF_SHA,"@SELF@")
 if own.sha256_text()!=SELF_SHA:return deny("gate_changed")
 if FileAccess.get_sha256(MANIFEST)!=MANIFEST_SHA or FileAccess.get_sha256(SOURCE)!=SOURCE_SHA:return deny("manifest_or_source_changed")
 var m:Variant=read(MANIFEST)
 if not m is Dictionary or m.schema!="yan-p3-gameplay-migration-1" or m.changes.size()!=9:return deny("schema_or_exact_changes")
 if FileAccess.get_sha256(m.predecessor)!=m.predecessor_sha or FileAccess.get_sha256(m.visual_path)!=m.visual_sha:return deny("predecessor_or_visual_changed")
 var prior:Dictionary=read(m.predecessor)
 var current:Dictionary=read(SOURCE)
 if prior.runtime_map.size()!=1747 or current.runtime_map!=prior.runtime_map:return deny("historical_map_changed")
 if current.p3_gameplay_migration.path!=MANIFEST or current.p3_gameplay_migration.sha256!=MANIFEST_SHA or current.p3_gameplay_migration.runtime_candidates!=m.runtime_candidates:return deny("capability_not_bound")
 for path:String in m.changes:
  var c:Dictionary=m.changes[path]
  if prior.runtime_map.get(path,"")!=c.before:return deny("wrong_predecessor:"+path)
  if FileAccess.get_sha256(c.preimage)!=c.before:return deny("preimage_changed:"+path)
  if FileAccess.get_sha256(path)!=c.after:return deny("current_after_changed:"+path)
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
  if c.get("preimage","")!=expected_preimage or FileAccess.get_sha256(expected_preimage)!=c.before:return deny("presentation_preimage_changed:"+path)
  if FileAccess.get_sha256(path)!=c.get("after",""):return deny("presentation_after_changed:"+path)
 for path:String in m.added:
  if FileAccess.get_sha256(path)!=m.added[path]:return deny("added_resource_changed:"+path)
 return {"accepted":true}
static func verify_legacy_map(mapped:Dictionary)->Dictionary:
 var checked:Dictionary=verify()
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
  if FileAccess.get_sha256(actual)!=str(mapped[path]):return deny("legacy_source_changed:"+path)
 return {"accepted":true}
