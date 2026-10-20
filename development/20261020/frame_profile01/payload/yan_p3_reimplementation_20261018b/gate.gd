extends RefCounted
# Real current gameplay afters and exact predecessor preimages are distinct gates.
const MANIFEST="res://yan_p3_reimplementation_20261018b/migration.json"
const MANIFEST_SHA="1121689d62ffa8b0f6b3d3fcec667a38a41e625d84f5a13959632a832be43892"
const SOURCE="res://visual_rework_20261009/binding/source_binding.json"
const SOURCE_SHA="9ae95247da24728efd4adfd3494204b9983e74b67095aba8036b03a23e74728e"
const SELF="res://yan_p3_reimplementation_20261018b/gate.gd"
const SELF_SHA="3a69d2d10bcec677aaa7c3d8593737b5ba09b60739199d0efa69bf319ab0b0e1"
const PRESENTATION_SCOPES={"res://scripts/ui/hero_chooser.gd":"source","res://visual_rework_20261009/controller.gd":"visual","res://visual_rework_20261009/views/q3_mountain_mesh.gd":"visual","res://visual_rework_20261009/views/q3_rock.gdshader":"visual","res://tests/ink_first_floor_enemy_views_20261004/fix01/roster_presenter.gd":"source","res://data/final_design/catalog.gd":"source","res://visual_rework_20261009/binding/c03_visual_source_successor.gd":"source","res://scripts/integration/hero_entry.gd":"source","res://tests/ink_first_floor_user_route_20261005/native_host01/flow_bridge.gd":"source","res://visual_rework_20261009/runtime_actor.gd":"visual","res://visual_rework_20261009/runtime_host.gd":"source"}
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
  if path=="res://visual_rework_20261009/runtime_host.gd" and not _exact_profile_runtime_host(c,prior,visual):return deny("exact_profile_runtime_host")
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
   if mapped!=expected and not (path=="res://visual_rework_20261009/runtime_host.gd" and _exact_profile_runtime_host(c,prior,visual)):return deny("presentation_map_scope_mismatch:"+path)
   actual=c.preimage
  if FileAccess.get_sha256(actual)!=str(mapped[path]):return deny("legacy_source_changed:"+path)
 return {"accepted":true}

static func _exact_profile_runtime_host(c: Dictionary, prior: Dictionary, visual: Dictionary) -> bool:
 const PATH = "res://visual_rework_20261009/runtime_host.gd"
 const BEFORE = "7be374962b5c7298a413355a529e8cb535961e03b72fd49efbe557e481ff8e7b"
 const AFTER = "456c42cf20cb2d3aa86f0f96b3bf7ef03d3c2d8cf42ac1028fcf804d3c5d0d40"
 const PREIMAGE = "res://yan_p3_reimplementation_20261018b/presentation_preimages/visual_rework_20261009/runtime_host.gd"
 if prior.get("runtime_map",{}).get(PATH,"") != BEFORE or visual.get("runtime_map",{}).get(PATH,"") != BEFORE: return false
 if c != {"map_scope":"source","before":BEFORE,"after":AFTER,"preimage":PREIMAGE}: return false
 if FileAccess.get_sha256(PREIMAGE) != BEFORE or FileAccess.get_sha256(PATH) != AFTER: return false
 var original: String = FileAccess.get_file_as_string(PREIMAGE)
 var old_line: String = 'const VISUAL_ACTOR_SHA := "c0ad0a2f51548126a338a9333cfc9b7bc39c0f806f86dec795e031ff86adca66"'
 var new_line: String = 'const VISUAL_ACTOR_SHA := "038f6805928d14df25b57444331c15c89a46231834554256ed742da50a05ea15"'
 return original.count(old_line) == 1 and original.replace(old_line,new_line) == FileAccess.get_file_as_string(PATH)
