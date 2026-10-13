extends RefCounted
const Catalog=preload("res://tests/ink_river_hexes_20261006/ordinary01/catalog.gd")
const Prior=preload("res://tests/ink_q3_input_growth_20261004/live_binding.gd")
const SIM_PATH="res://tests/ink_river_hexes_20261006/ordinary01/sim.gd"
const BINDING_PATH="res://tests/ink_river_hexes_20261006/ordinary01/source_binding.json"
const PARENT_PATH="res://tests/ink_river_hexes_20261006/ownership01/fix01/source_binding.json"
const PARENT_SHA="f77466574d9631b03710f79201a2cd52b6cdbebd28be6fe607870988f4a6d9bc"
const DIRECTOR_PATH="res://tests/ink_ultimate_presentation_20261006/r1_consumer01/timed_director.gd"
const CLOCK_PATH="res://tests/ink_ultimate_presentation_20261006/r1_consumer01/clock_facade.gd"
static func read_capabilities(sim: Node, include_source_adapter_hooks: bool=false) -> Dictionary:
 if not is_instance_valid(sim) or sim.get_script().resource_path!=SIM_PATH: return _deny("exact_river_ordinary_sim_required")
 if sim.clock.get_script().resource_path!=CLOCK_PATH or sim.enemy_director.get_script().resource_path!=DIRECTOR_PATH: return _deny("current_clock_director_required")
 if FileAccess.get_sha256(PARENT_PATH)!=PARENT_SHA: return _deny("ownership_fixture_binding_changed")
 var parent: Variant=JSON.parse_string(FileAccess.get_file_as_string(PARENT_PATH))
 var binding: Variant=JSON.parse_string(FileAccess.get_file_as_string(BINDING_PATH))
 if not binding is Dictionary or binding.get("schema","")!="ink-river-ordinary01" or not parent is Dictionary: return _deny("river_ordinary_binding_missing")
 if binding.get("runtime_candidates",[])!=Catalog.FIRST_SLICE_ALLOWED_CANDIDATES or binding.get("supported_hex_hooks",[])!=Catalog.FIRST_SLICE_HEX_HOOKS: return _deny("river_ordinary_scope_changed")
 var mapped: Dictionary=binding.get("runtime_map",{})
 for path: String in parent.runtime_map:
  if mapped.get(path,"")!=parent.runtime_map[path]: return _deny("ancestor_pin_changed:"+path)
 if mapped.get(PARENT_PATH,"")!=PARENT_SHA: return _deny("ownership_parent_pin_missing")
 for path: String in mapped:
  if not path.begins_with("res://") or ".." in path.trim_prefix("res://").split("/") or not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=str(mapped[path]): return _deny("runtime_source_changed:"+path)
 var hooks: Array=Catalog.FIRST_SLICE_HEX_HOOKS.duplicate()
 if include_source_adapter_hooks: hooks.append_array(Prior.ADAPTER_HOOKS)
 return {"accepted":true,"reason":"","capabilities":{"schema_version":1,"hero_id":"yanguizhou","source_binding_id":FileAccess.get_sha256(BINDING_PATH),"runtime_candidates":Catalog.FIRST_SLICE_ALLOWED_CANDIDATES.duplicate(),"supported_hooks":hooks,"ordinary_entry_ready":false,"scope":"current R2 ordinary with H03/H04 only; one Session; pending ordinary finite gate; no native/art/full-floor/multiplayer claim"}}
static func _deny(reason: String) -> Dictionary: return {"accepted":false,"reason":reason}
