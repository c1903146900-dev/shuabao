extends RefCounted
## Exact ordinary Sim, with only two explicit entry-point pin replacements.
const Catalog=preload("res://tests/ink_river_hexes_20261006/ordinary01/catalog.gd")
const Prior=preload("res://tests/ink_q3_input_growth_20261004/live_binding.gd")
const SIM_PATH="res://tests/ink_river_hexes_20261006/ordinary01/sim.gd"
const BINDING_PATH="res://tests/ink_river_hexes_20261006/frontdoor01/source_binding.json"
const PARENT_PATH="res://tests/ink_river_hexes_20261006/ordinary01/fix01/source_binding.json"
const PARENT_SHA="83cd99cb7972b13ac88fd10a8eb028369e7e6d2c6e0786eb13e49f5860f5eefe"
const DIRECTOR_PATH="res://tests/ink_ultimate_presentation_20261006/r1_consumer01/timed_director.gd"
const CLOCK_PATH="res://tests/ink_ultimate_presentation_20261006/r1_consumer01/clock_facade.gd"
const ENTRY_PATHS=["res://scripts/integration/yanguizhou_first_floor.gd","res://scripts/ui/hero_chooser.gd"]
static func read_capabilities(sim: Node, include_source_adapter_hooks: bool=false) -> Dictionary:
 if not is_instance_valid(sim) or sim.get_script().resource_path!=SIM_PATH:return _deny("exact_unchanged_ordinary_sim_required")
 if sim.clock.get_script().resource_path!=CLOCK_PATH or sim.enemy_director.get_script().resource_path!=DIRECTOR_PATH:return _deny("current_clock_director_required")
 if FileAccess.get_sha256(PARENT_PATH)!=PARENT_SHA:return _deny("ordinary_validation_parent_changed")
 var parent: Variant=JSON.parse_string(FileAccess.get_file_as_string(PARENT_PATH))
 var binding: Variant=JSON.parse_string(FileAccess.get_file_as_string(BINDING_PATH))
 if not parent is Dictionary or not binding is Dictionary or binding.get("schema","")!="ink-river-frontdoor01":return _deny("frontdoor_binding_missing")
 if binding.get("runtime_candidates",[])!=Catalog.FIRST_SLICE_ALLOWED_CANDIDATES or binding.get("supported_hex_hooks",[])!=Catalog.FIRST_SLICE_HEX_HOOKS:return _deny("frontdoor_capability_scope_changed")
 var changes: Dictionary=binding.get("ancestor_pin_replacements",{})
 var mapped: Dictionary=binding.get("runtime_map",{})
 if changes.size()!=2 or not changes.has(ENTRY_PATHS[0]) or not changes.has(ENTRY_PATHS[1]):return _deny("only_two_entry_replacements_permitted")
 for path: String in parent.runtime_map:
  var expected: String=parent.runtime_map[path]
  if changes.has(path):
   var change: Dictionary=changes[path]
   if path not in ENTRY_PATHS or change.get("before","")!=expected or change.get("after","")!=mapped.get(path,""):return _deny("entry_replacement_not_exact:"+path)
   expected=str(change.after)
  if mapped.get(path,"")!=expected:return _deny("ancestor_pin_changed:"+path)
 if mapped.get(PARENT_PATH,"")!=PARENT_SHA:return _deny("parent_manifest_pin_missing")
 for path: String in mapped:
  if not path.begins_with("res://") or ".." in path.trim_prefix("res://").split("/") or not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=str(mapped[path]):return _deny("runtime_source_changed:"+path)
 var hooks: Array=Catalog.FIRST_SLICE_HEX_HOOKS.duplicate()
 if include_source_adapter_hooks:hooks.append_array(Prior.ADAPTER_HOOKS)
 return {"accepted":true,"reason":"","capabilities":{"schema_version":1,"hero_id":"yanguizhou","source_binding_id":FileAccess.get_sha256(BINDING_PATH),"runtime_candidates":Catalog.FIRST_SLICE_ALLOWED_CANDIDATES.duplicate(),"supported_hooks":hooks,"ordinary_entry_ready":false,"scope":"unchanged H03/H04 ordinary Sim through explicit two-entry frontdoor successor; lifecycle candidate only; default click/native NOT_RUN"}}
static func _deny(reason: String) -> Dictionary:return {"accepted":false,"reason":reason}
