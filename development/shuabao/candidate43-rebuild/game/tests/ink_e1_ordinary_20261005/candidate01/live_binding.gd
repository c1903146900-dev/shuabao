extends RefCounted
## Exact new composition identity, with unchanged parent source maps verified.
## No dummy parent instance, script impersonation, or inherited acceptance.
const Catalog = preload("res://tests/ink_e1_ordinary_20261005/candidate01/catalog.gd")
const Prior = preload("res://tests/ink_q3_input_growth_20261004/live_binding.gd")
const SIM_PATH := "res://tests/ink_e1_ordinary_20261005/candidate01/sim.gd"
const BINDING_PATH := "res://tests/ink_e1_ordinary_20261005/candidate01/source_binding.json"
const PARENT_RUNTIME_MAPS := {"res://tests/ink_e1_rain_foundation_20261005/fix01/runtime_binding.json": "462117c2a7922167a95d2c6fca667e972cfa8590265f0d73960d5b3eb646bf37", "res://tests/ink_q2_foundation_20261005/fix01/runtime_binding.json": "76a75bb928f5c9aefd4377a54e03d6ec4fffdeee8aaac76ae9847c4fa0b98ef9", "res://tests/ink_q3_input_growth_20261004/runtime_binding.json": "ba92830cf08fb056a23e831e1b86f1ab398feb81e5f36680d7cf97aa90c06504"}
const Q2_PARENT := "res://tests/ink_q2_ordinary_20261005/candidate01/source_binding.json"
const Q2_PARENT_SHA := "c702df4e5b10b2a424f0ca3f0b860fd2d0b7171208965e696c8be72db1bc6cd3"
const E1_PARENT := "res://tests/ink_e1_rain_foundation_20261005/fix01/source_binding.json"
const E1_PARENT_SHA := "7a0da1f04790c8e2c6d71036a42dccdb8222393f8721cc8e1d26972a3c9db9ab"

static func read_capabilities(sim: Node, include_source_adapter_hooks: bool = false) -> Dictionary:
 if not is_instance_valid(sim) or sim.get_script() == null or sim.get_script().resource_path != SIM_PATH: return _deny("exact_e1_q2_composition_required")
 if FileAccess.get_sha256(Q2_PARENT) != Q2_PARENT_SHA or FileAccess.get_sha256(E1_PARENT) != E1_PARENT_SHA: return _deny("frozen_parent_manifest_changed")
 var overlay: Variant = JSON.parse_string(FileAccess.get_file_as_string(BINDING_PATH))
 if not overlay is Dictionary or overlay.get("schema","") != "ink-e1-q2-ordinary-overlay-1": return _deny("e1_overlay_missing")
 if overlay.get("runtime_candidates",[]) != Catalog.FIRST_SLICE_ALLOWED_CANDIDATES or overlay.get("supported_hex_hooks",[]) != Catalog.FIRST_SLICE_HEX_HOOKS: return _deny("e1_scope_changed")
 if not overlay.get("runtime_map") is Dictionary or overlay.runtime_map.is_empty(): return _deny("e1_overlay_pins_missing")
 if overlay.get("parent_runtime_maps",{}) != PARENT_RUNTIME_MAPS: return _deny("exact_parent_runtime_maps_required")
 for path: String in overlay.runtime_map:
  if not _valid_path(path) or FileAccess.get_sha256(path) != str(overlay.runtime_map[path]): return _deny("e1_overlay_pin:"+path)
 for binding_path: String in overlay.get("parent_runtime_maps",{}):
  if not _valid_path(binding_path) or FileAccess.get_sha256(binding_path) != str(overlay.parent_runtime_maps[binding_path]): return _deny("parent_runtime_binding_changed:"+binding_path)
  var bound: Variant = JSON.parse_string(FileAccess.get_file_as_string(binding_path))
  if not bound is Dictionary or not bound.get("runtime_map") is Dictionary: return _deny("parent_runtime_map_missing")
  for relative: String in bound.runtime_map:
   var path: String = "res://"+relative
   if not _valid_path(path) or FileAccess.get_sha256(path) != str(bound.runtime_map[relative].sha256): return _deny("parent_dependency_changed:"+path)
 var parent: Variant = JSON.parse_string(FileAccess.get_file_as_string(Q2_PARENT))
 if not parent is Dictionary: return _deny("q2_parent_missing")
 for path: String in parent.runtime_map:
  var expected: String = str(parent.runtime_map[path])
  var replacement: Dictionary = overlay.get("ancestor_pin_replacements",{}).get(path,{})
  if not replacement.is_empty():
   if path not in ["res://scripts/integration/yanguizhou_first_floor.gd","res://scripts/ui/hero_chooser.gd"] or replacement.get("before","") != expected or replacement.get("after","") != overlay.runtime_map.get(path,""): return _deny("invalid_explicit_parent_replacement")
   expected = str(replacement.after)
  if FileAccess.get_sha256(path) != expected: return _deny("q2_parent_dependency_changed:"+path)
 var hooks: Array = Catalog.FIRST_SLICE_HEX_HOOKS.duplicate()
 if include_source_adapter_hooks: hooks.append_array(Prior.ADAPTER_HOOKS)
 return {"accepted":true,"reason":"","capabilities":{"schema_version":1,"hero_id":"yanguizhou","source_binding_id":FileAccess.get_sha256(BINDING_PATH),"runtime_candidates":Catalog.FIRST_SLICE_ALLOWED_CANDIDATES.duplicate(),"supported_hooks":hooks,"ordinary_entry_ready":false,"scope":"Q1/Q2/Q3 and base E1 source composition; original ten hooks; H07/H08 unavailable; new engine/native and art acceptance pending"}}

static func _valid_path(path: String) -> bool:
 return path.begins_with("res://") and ".." not in path.trim_prefix("res://").split("/") and FileAccess.file_exists(path)
static func _deny(reason: String) -> Dictionary:
 return {"accepted":false,"reason":reason}
