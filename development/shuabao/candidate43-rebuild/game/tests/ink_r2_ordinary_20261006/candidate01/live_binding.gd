extends RefCounted
## Explicit E3 successor. Exact current ancestors remain pinned; only the
## two declared production leaves change. No old script identity is spoofed.
const Catalog = preload("res://tests/ink_r2_ordinary_20261006/candidate01/catalog.gd")
const Prior = preload("res://tests/ink_q3_input_growth_20261004/live_binding.gd")
const SIM_PATH := "res://tests/ink_r2_ordinary_20261006/candidate01/sim.gd"
const DIRECTOR_PATH := "res://tests/ink_ultimate_presentation_20261006/r1_consumer01/timed_director.gd"
const CLOCK_PATH := "res://tests/ink_ultimate_presentation_20261006/r1_consumer01/clock_facade.gd"
const BINDING_PATH := "res://tests/ink_r2_ordinary_20261006/candidate01/source_binding.json"
const PARENT_PATH := "res://tests/ink_ordinary_composed_20261006/candidate01/source_binding.json"
const PARENT_SHA := "b9f793bcf444150a170c573b70768ad888a17fe089fb8661167c14dc664f0e6e"
const E3_BOUNDARY_PATH := "res://tests/ink_e3_boundary_20261006/candidate01/source_binding.json"
const E3_BOUNDARY_SHA := "01e2a9c5763f3abd752e18e7e3ec11d4e3e0367bbfb74e501ee556ce48527745"
const ADAPTER := "res://scripts/integration/yanguizhou_first_floor.gd"
const CHOOSER := "res://scripts/ui/hero_chooser.gd"

static func read_capabilities(sim: Node, include_source_adapter_hooks: bool = false) -> Dictionary:
 if not is_instance_valid(sim) or sim.get_script().resource_path != SIM_PATH: return _deny("exact_current_composed_sim_required")
 if sim.enemy_director.get_script().resource_path != DIRECTOR_PATH: return _deny("exact_retained_r1_director_required")
 if sim.clock.get_script().resource_path != CLOCK_PATH: return _deny("exact_presentation_clock_facade_required")
 if FileAccess.get_sha256(PARENT_PATH) != PARENT_SHA: return _deny("frozen_p2_ordinary_parent_changed")
 if FileAccess.get_sha256(E3_BOUNDARY_PATH) != E3_BOUNDARY_SHA: return _deny("e3_boundary_source_changed")
 var parent: Variant = JSON.parse_string(FileAccess.get_file_as_string(PARENT_PATH))
 var binding: Variant = JSON.parse_string(FileAccess.get_file_as_string(BINDING_PATH))
 if not parent is Dictionary or not binding is Dictionary or binding.get("schema","") != "ink-r2-ordinary-candidate01": return _deny("e3_ordinary_binding_missing")
 if binding.get("runtime_candidates",[]) != Catalog.FIRST_SLICE_ALLOWED_CANDIDATES or binding.get("supported_hex_hooks",[]) != Catalog.FIRST_SLICE_HEX_HOOKS: return _deny("e3_ordinary_scope_changed")
 var mapped: Dictionary = binding.get("runtime_map",{})
 var changes: Dictionary = binding.get("ancestor_pin_replacements",{})
 if mapped.is_empty() or changes.size() != 2 or not changes.has(ADAPTER) or not changes.has(CHOOSER): return _deny("e3_replacement_scope_changed")
 for path: String in parent.runtime_map:
  var expected: String = str(parent.runtime_map[path])
  if changes.has(path):
   var change: Dictionary = changes[path]
   if path not in [ADAPTER,CHOOSER] or str(change.get("before","")) != expected or str(change.get("after","")) != str(mapped.get(path,"")): return _deny("invalid_e3_replacement:"+path)
   expected = str(change.after)
  if str(mapped.get(path,"")) != expected: return _deny("parent_runtime_pin_missing_or_changed:"+path)
 if str(mapped.get(PARENT_PATH,"")) != PARENT_SHA: return _deny("parent_manifest_pin_missing")
 for path: String in mapped:
  if not path.begins_with("res://") or ".." in path.trim_prefix("res://").split("/") or not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != str(mapped[path]): return _deny("exact_e3_runtime_changed:"+path)
 var hooks: Array = Catalog.FIRST_SLICE_HEX_HOOKS.duplicate()
 if include_source_adapter_hooks: hooks.append_array(Prior.ADAPTER_HOOKS)
 return {"accepted":true,"reason":"","capabilities":{"schema_version":1,"hero_id":"yanguizhou","source_binding_id":FileAccess.get_sha256(BINDING_PATH),"runtime_candidates":Catalog.FIRST_SLICE_ALLOWED_CANDIDATES.duplicate(),"supported_hooks":hooks,"ordinary_entry_ready":false,"scope":"R2 plus current composed ordinary; same R slot and original ten Hex hooks; shared R1/R2 presentation domain; finite pending; no final art, animation or multiplayer claim"}}

static func _deny(reason: String) -> Dictionary:
 return {"accepted":false,"reason":reason}
