extends RefCounted
## Reviewed same-resource-path content composition; historical manifests immutable.
const Catalog=preload("res://tests/ink_river_hexes_20261006/ordinary01/catalog.gd")
const Prior=preload("res://tests/ink_q3_input_growth_20261004/live_binding.gd")
const SIM_PATH="res://tests/ink_river_hexes_20261006/ordinary01/sim.gd"
const BINDING_PATH="res://tests/ink_first_floor_boss_20261008/live02/source_binding.json"
const PARENT_PATH="res://tests/ink_first_floor_boss_20261008/live01/source_binding.json"
const PARENT_SHA="9b0d7086fe9b200a61fc4b87f7826243c7b424c83c38ccfbe786f3aff32b02ca"
const REPLACEMENTS=["res://tests/ink_river_hexes_20261006/ordinary01/sim.gd", "res://tests/ink_river_hexes_20261006/frontdoor01/floor_session.gd", "res://tests/ink_river_hexes_20261006/frontdoor01/navigation_install.gd", "res://tests/ink_river_hexes_20261006/frontdoor01/host.gd", "res://scripts/integration/yanguizhou_first_floor.gd", "res://tests/ink_ordinary_visuals_20261007/candidate01/host.gd"]
const DIRECTOR_PATH="res://tests/ink_first_floor_boss_20261008/source01/enemy_director.gd"
const CLOCK_PATH="res://tests/ink_ultimate_presentation_20261006/r1_consumer01/clock_facade.gd"
static func read_capabilities(sim: Node, include_source_adapter_hooks: bool=false) -> Dictionary:
 if not is_instance_valid(sim) or sim.get_script().resource_path!=SIM_PATH: return _deny("exact_ordinary_sim_required")
 if sim.clock.get_script().resource_path!=CLOCK_PATH or sim.enemy_director.get_script().resource_path!=DIRECTOR_PATH: return _deny("current_clock_director_required")
 if FileAccess.get_sha256(PARENT_PATH)!=PARENT_SHA: return _deny("frozen_boss_live01_parent_changed")
 var parent: Variant=JSON.parse_string(FileAccess.get_file_as_string(PARENT_PATH))
 var binding: Variant=JSON.parse_string(FileAccess.get_file_as_string(BINDING_PATH))
 if not parent is Dictionary or not binding is Dictionary or binding.get("schema","")!="first-floor-boss-live02": return _deny("content_binding_missing")
 if binding.get("runtime_candidates",[])!=Catalog.FIRST_SLICE_ALLOWED_CANDIDATES or binding.get("supported_hex_hooks",[])!=Catalog.FIRST_SLICE_HEX_HOOKS: return _deny("content_capability_scope_changed")
 var changes: Dictionary=binding.get("ancestor_pin_replacements",{})
 var mapped: Dictionary=binding.get("runtime_map",{})
 if changes.size()!=REPLACEMENTS.size(): return _deny("exact_content_replacements_required")
 for path: String in REPLACEMENTS:
  if not changes.has(path) or not parent.runtime_map.has(path): return _deny("replacement_not_in_parent:"+path)
 for path: String in parent.runtime_map:
  var expected: String=parent.runtime_map[path]
  if changes.has(path):
   var change: Dictionary=changes[path]
   if path not in REPLACEMENTS or change.get("before","")!=expected or change.get("after","")!=mapped.get(path,""): return _deny("replacement_not_exact:"+path)
   expected=str(change.after)
  if mapped.get(path,"")!=expected: return _deny("ancestor_pin_changed:"+path)
 if mapped.get(PARENT_PATH,"")!=PARENT_SHA: return _deny("parent_pin_missing")
 for path: String in mapped:
  if not path.begins_with("res://") or ".." in path.trim_prefix("res://").split("/") or not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=str(mapped[path]): return _deny("runtime_source_changed:"+path)
 var hooks: Array=Catalog.FIRST_SLICE_HEX_HOOKS.duplicate()
 if include_source_adapter_hooks: hooks.append_array(Prior.ADAPTER_HOOKS)
 return {"accepted":true,"reason":"","capabilities":{"schema_version":1,"hero_id":"yanguizhou","source_binding_id":FileAccess.get_sha256(BINDING_PATH),"runtime_candidates":Catalog.FIRST_SLICE_ALLOWED_CANDIDATES.duplicate(),"supported_hooks":hooks,"ordinary_entry_ready":false,"scope":"same ordinary Sim/Session/clock and equipment32/potions3; source01 Boss composition; source/native/art acceptance separate"}}
static func _deny(reason: String) -> Dictionary: return {"accepted":false,"reason":reason}
