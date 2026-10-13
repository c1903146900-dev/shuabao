extends RefCounted
## Exact new ordinary identity. Never ask the old binding to accept a new Sim.
const Catalog = preload("res://tests/ink_r1_ordinary_20261005/candidate01/ordinary01/catalog.gd")
const Prior = preload("res://tests/ink_q3_input_growth_20261004/live_binding.gd")
const SIM_PATH := "res://tests/ink_r1_ordinary_20261005/candidate01/sim.gd"
const DIRECTOR_PATH := "res://tests/ink_r1_ordinary_20261005/candidate01/enemy_director.gd"
const BINDING_PATH := "res://tests/ink_r1_ordinary_20261005/candidate01/ordinary01/source_binding.json"
const E1_PARENT := "res://tests/ink_e1_ordinary_20261005/candidate01/source_binding.json"
const E1_SHA := "1b89127da1767a4c57fe790edd8b29be1d624096cd3d4f16fef486753bce88a0"
const CORE_PARENT := "res://tests/ink_r1_ordinary_20261005/candidate01/source_binding.json"
const CORE_SHA := "56dac25470e45f9de8bd3c62667c1160a8af3aad02a2d59e14bf6ae220fb5456"
const REPLACEABLE := ["res://scripts/integration/yanguizhou_first_floor.gd", "res://scripts/ui/hero_chooser.gd"]

static func read_capabilities(sim: Node, include_source_adapter_hooks: bool = false) -> Dictionary:
 if not is_instance_valid(sim) or sim.get_script() == null or sim.get_script().resource_path != SIM_PATH: return _deny("exact_r1_e1_ordinary_sim_required")
 if sim.enemy_director.get_script().resource_path != DIRECTOR_PATH: return _deny("exact_r1_navigation_director_required")
 if FileAccess.get_sha256(E1_PARENT) != E1_SHA or FileAccess.get_sha256(CORE_PARENT) != CORE_SHA: return _deny("frozen_parent_manifest_changed")
 var overlay: Variant = JSON.parse_string(FileAccess.get_file_as_string(BINDING_PATH))
 var e1: Variant = JSON.parse_string(FileAccess.get_file_as_string(E1_PARENT))
 var core: Variant = JSON.parse_string(FileAccess.get_file_as_string(CORE_PARENT))
 if not overlay is Dictionary or overlay.get("schema","") != "ink-r1-ordinary-overlay-1": return _deny("r1_ordinary_binding_missing")
 if not e1 is Dictionary or not core is Dictionary: return _deny("parent_manifest_invalid")
 if overlay.get("runtime_candidates",[]) != Catalog.FIRST_SLICE_ALLOWED_CANDIDATES or overlay.get("supported_hex_hooks",[]) != Catalog.FIRST_SLICE_HEX_HOOKS: return _deny("r1_scope_changed")
 if not overlay.get("runtime_map") is Dictionary or overlay.runtime_map.is_empty(): return _deny("r1_runtime_pins_missing")
 for path: String in overlay.runtime_map:
  if not _valid(path) or FileAccess.get_sha256(path) != str(overlay.runtime_map[path]): return _deny("r1_runtime_pin:"+path)
 for name: String in core.candidate_files:
  var path: String = "res://tests/ink_r1_ordinary_20261005/candidate01/"+name
  if not _valid(path) or FileAccess.get_sha256(path) != str(core.candidate_files[name]): return _deny("r1_core_changed:"+path)
 for path: String in e1.runtime_map:
  var expected: String = str(e1.runtime_map[path])
  var replacement: Dictionary = overlay.get("ancestor_pin_replacements",{}).get(path,{})
  if not replacement.is_empty():
   if path not in REPLACEABLE or replacement.get("before","") != expected or replacement.get("after","") != overlay.runtime_map.get(path,""): return _deny("unapproved_e1_parent_replacement")
   expected = str(replacement.after)
  if not _valid(path) or FileAccess.get_sha256(path) != expected: return _deny("e1_parent_changed:"+path)
 # All pre-existing source-to-target maps remain fixed. Runtime checks use the
 # staged canonical targets, just as the verified E1 parent does.
 for path: String in e1.parent_runtime_maps:
  if not _valid(path) or FileAccess.get_sha256(path) != str(e1.parent_runtime_maps[path]): return _deny("parent_runtime_map_changed:"+path)
  var map: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
  if not map is Dictionary or not map.get("runtime_map") is Dictionary: return _deny("parent_runtime_map_invalid")
  for relative: String in map.runtime_map:
   var target: String = "res://"+relative
   if not _valid(target) or FileAccess.get_sha256(target) != str(map.runtime_map[relative].sha256): return _deny("parent_dependency_changed:"+target)
 var q2_path := "res://tests/ink_q2_ordinary_20261005/candidate01/source_binding.json"
 if FileAccess.get_sha256(q2_path) != "c702df4e5b10b2a424f0ca3f0b860fd2d0b7171208965e696c8be72db1bc6cd3": return _deny("q2_parent_manifest_changed")
 var q2: Variant = JSON.parse_string(FileAccess.get_file_as_string(q2_path))
 for path: String in q2.runtime_map:
  var expected: String = str(q2.runtime_map[path])
  var e1_replacement: Dictionary = e1.get("ancestor_pin_replacements",{}).get(path,{})
  if not e1_replacement.is_empty():
   if path not in REPLACEABLE or e1_replacement.get("before","") != expected or e1_replacement.get("after","") != e1.runtime_map.get(path,""): return _deny("e1_replacement_chain_invalid")
   expected = str(e1_replacement.after)
  var replacement: Dictionary = overlay.get("ancestor_pin_replacements",{}).get(path,{})
  if not replacement.is_empty():
   if path not in REPLACEABLE or replacement.get("before","") != expected or replacement.get("after","") != overlay.runtime_map.get(path,""): return _deny("r1_replacement_chain_invalid")
   expected = str(replacement.after)
  if not _valid(path) or FileAccess.get_sha256(path) != expected: return _deny("q2_parent_dependency_changed:"+path)
 var hooks: Array = Catalog.FIRST_SLICE_HEX_HOOKS.duplicate()
 if include_source_adapter_hooks: hooks.append_array(Prior.ADAPTER_HOOKS)
 return {"accepted":true,"reason":"","capabilities":{"schema_version":1,"hero_id":"yanguizhou","source_binding_id":FileAccess.get_sha256(BINDING_PATH),"runtime_candidates":Catalog.FIRST_SLICE_ALLOWED_CANDIDATES.duplicate(),"supported_hooks":hooks,"ordinary_entry_ready":false,"scope":"Q1/Q2/Q3/E1 plus base R1; original ten hooks; functional circle only; ordinary composition/native gates pending"}}

static func _valid(path: String) -> bool:
 return path.begins_with("res://") and ".." not in path.trim_prefix("res://").split("/") and FileAccess.file_exists(path)
static func _deny(reason: String) -> Dictionary: return {"accepted":false,"reason":reason}
