extends RefCounted
## Explicit successor admission, with the verified full parent closures flattened
## into exact runtime paths. Prior manifests remain immutable evidence; the sole
## production replacement must name its precise before/after SHA. No script
## identity is spoofed and no earlier binder rejection is suppressed.
const Catalog = preload("res://tests/ink_e2_boundary_20261006/ordinary01/catalog.gd")
const Prior = preload("res://tests/ink_q3_input_growth_20261004/live_binding.gd")
const SIM_PATH := "res://tests/ink_e2_boundary_20261006/ordinary01/sim.gd"
const DIRECTOR_PATH := "res://tests/ink_r1_ordinary_20261005/candidate01/enemy_director.gd"
const BINDING_PATH := "res://tests/ink_e2_boundary_20261006/ordinary01/source_binding.json"
const REST_PATH := "res://tests/ink_rest_service_20261006/candidate01/ordinary01/source_binding.json"
const REST_SHA := "e32a9951aa51f970ce85b84d956f4da9ca3f9f10c1997ffed9a8af89c4e971fc"
const BOUNDARY_PATH := "res://tests/ink_e2_boundary_20261006/candidate01/source_binding.json"
const BOUNDARY_SHA := "c91e4c0ba04d2c4bf50387249a1074b20d2b188b031ec7f50b4e2e9da34cbe01"
const ADAPTER := "res://scripts/integration/yanguizhou_first_floor.gd"
const ADAPTER_BEFORE := "8509e03edea0bbc5df7f063431ee637713d44673223eeac34869b63be0650801"

static func read_capabilities(sim: Node, include_source_adapter_hooks: bool = false) -> Dictionary:
 if not is_instance_valid(sim) or sim.get_script() == null or sim.get_script().resource_path != SIM_PATH: return _deny("exact_e2_p1_r1_rest_sim_required")
 if sim.enemy_director.get_script().resource_path != DIRECTOR_PATH: return _deny("retained_r1_navigation_director_required")
 if FileAccess.get_sha256(REST_PATH) != REST_SHA or FileAccess.get_sha256(BOUNDARY_PATH) != BOUNDARY_SHA: return _deny("frozen_parent_binding_changed")
 var binding: Variant = JSON.parse_string(FileAccess.get_file_as_string(BINDING_PATH))
 var rest: Variant = JSON.parse_string(FileAccess.get_file_as_string(REST_PATH))
 if not binding is Dictionary or binding.get("schema","") != "ink-e2-ordinary-composition-1" or not rest is Dictionary: return _deny("e2_ordinary_binding_missing")
 if binding.get("runtime_candidates",[]) != Catalog.FIRST_SLICE_ALLOWED_CANDIDATES or binding.get("supported_hex_hooks",[]) != Catalog.FIRST_SLICE_HEX_HOOKS: return _deny("e2_scope_changed")
 var mapped: Dictionary = binding.get("runtime_map",{})
 var replacements: Dictionary = binding.get("ancestor_pin_replacements",{})
 if mapped.is_empty() or replacements.size() != 1 or not replacements.has(ADAPTER): return _deny("e2_runtime_or_replacement_scope_invalid")
 var replacement: Dictionary = replacements[ADAPTER]
 if str(replacement.get("before","")) != ADAPTER_BEFORE or str(replacement.get("after","")) != str(mapped.get(ADAPTER,"")) or str(rest.runtime_map.get(ADAPTER,"")) != ADAPTER_BEFORE: return _deny("production_successor_chain_invalid")
 for path: String in binding.get("parent_bindings",{}):
  if not _valid(path) or FileAccess.get_sha256(path) != str(binding.parent_bindings[path]): return _deny("frozen_parent_changed:"+path)
 for path: String in mapped:
  if not _valid(path) or FileAccess.get_sha256(path) != str(mapped[path]): return _deny("exact_runtime_changed:"+path)
 var hooks: Array = Catalog.FIRST_SLICE_HEX_HOOKS.duplicate()
 if include_source_adapter_hooks: hooks.append_array(Prior.ADAPTER_HOOKS)
 return {"accepted":true,"reason":"","capabilities":{"schema_version":1,"hero_id":"yanguizhou","source_binding_id":FileAccess.get_sha256(BINDING_PATH),"runtime_candidates":Catalog.FIRST_SLICE_ALLOWED_CANDIDATES.duplicate(),"supported_hooks":hooks,"ordinary_entry_ready":false,"scope":"Q1/Q2/Q3/E1/E2/P1/base R1; exact current P1 lifesteal/rest owner; original ten Hex hooks only; composed native input and art pending"}}

static func _valid(path: String) -> bool:
 return path.begins_with("res://") and ".." not in path.trim_prefix("res://").split("/") and FileAccess.file_exists(path)

static func _deny(reason: String) -> Dictionary:
 return {"accepted":false,"reason":reason}
