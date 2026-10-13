extends RefCounted
## Exact P1 ordinary identity above the frozen current R1/E1/Q2 chain.
## Never call an old exact-Sim binder and silently relax its rejection.
const Catalog = preload("res://tests/ink_p1_ordinary_20261006/candidate01/ordinary01/catalog.gd")
const Prior = preload("res://tests/ink_q3_input_growth_20261004/live_binding.gd")
const SIM_PATH := "res://tests/ink_p1_ordinary_20261006/candidate01/lifesteal01/sim.gd"
const DIRECTOR_PATH := "res://tests/ink_r1_ordinary_20261005/candidate01/enemy_director.gd"
const BINDING_PATH := "res://tests/ink_p1_ordinary_20261006/candidate01/ordinary01/source_binding.json"
const E1_PARENT := "res://tests/ink_e1_ordinary_20261005/candidate01/source_binding.json"
const E1_SHA := "1b89127da1767a4c57fe790edd8b29be1d624096cd3d4f16fef486753bce88a0"
const R1_CORE := "res://tests/ink_r1_ordinary_20261005/candidate01/source_binding.json"
const R1_CORE_SHA := "56dac25470e45f9de8bd3c62667c1160a8af3aad02a2d59e14bf6ae220fb5456"
const R1_PARENT := "res://tests/ink_r1_ordinary_20261005/candidate01/ordinary01/source_binding.json"
const R1_SHA := "cc0a3ef4fa909011a73f1a5acea55dd3427cead39ec6fdbc8d87a58356ce878b"
const P1_CORE := "res://tests/ink_p1_ordinary_20261006/candidate01/source_binding.json"
const P1_CORE_SHA := "538fbbed186cee63823c81fdea57662c6a2c0a29c187921a54ca1fd66fc7ac2b"
const P1_LIFESTEAL := "res://tests/ink_p1_ordinary_20261006/candidate01/lifesteal01/source_binding.json"
const P1_LIFESTEAL_SHA := "3d8f4ac79fe83d2804010a3eca89089999eae50be2b27ad3c49b270cc402828f"
const Q2_PARENT := "res://tests/ink_q2_ordinary_20261005/candidate01/source_binding.json"
const Q2_SHA := "c702df4e5b10b2a424f0ca3f0b860fd2d0b7171208965e696c8be72db1bc6cd3"
const REPLACEABLE := ["res://scripts/integration/yanguizhou_first_floor.gd","res://scripts/ui/hero_chooser.gd"]

static func read_capabilities(sim: Node, include_source_adapter_hooks: bool = false) -> Dictionary:
 if not is_instance_valid(sim) or sim.get_script() == null or sim.get_script().resource_path != SIM_PATH: return _deny("exact_p1_r1_ordinary_sim_required")
 if sim.enemy_director.get_script().resource_path != DIRECTOR_PATH: return _deny("exact_retained_r1_navigation_director_required")
 for pin: Array in [[E1_PARENT,E1_SHA],[R1_CORE,R1_CORE_SHA],[R1_PARENT,R1_SHA],[P1_CORE,P1_CORE_SHA],[P1_LIFESTEAL,P1_LIFESTEAL_SHA],[Q2_PARENT,Q2_SHA]]:
  if not _valid(pin[0]) or FileAccess.get_sha256(pin[0]) != pin[1]: return _deny("frozen_parent_manifest_changed:"+str(pin[0]))
 var overlay: Variant = JSON.parse_string(FileAccess.get_file_as_string(BINDING_PATH))
 var e1: Variant = JSON.parse_string(FileAccess.get_file_as_string(E1_PARENT))
 var r1: Variant = JSON.parse_string(FileAccess.get_file_as_string(R1_PARENT))
 var r1_core: Variant = JSON.parse_string(FileAccess.get_file_as_string(R1_CORE))
 var p1_core: Variant = JSON.parse_string(FileAccess.get_file_as_string(P1_CORE))
 var lifesteal: Variant = JSON.parse_string(FileAccess.get_file_as_string(P1_LIFESTEAL))
 var q2: Variant = JSON.parse_string(FileAccess.get_file_as_string(Q2_PARENT))
 if not overlay is Dictionary or overlay.get("schema","") != "ink-p1-ordinary-overlay-1": return _deny("p1_ordinary_binding_missing")
 if not e1 is Dictionary or not r1 is Dictionary or not r1_core is Dictionary or not p1_core is Dictionary or not lifesteal is Dictionary or not q2 is Dictionary: return _deny("parent_manifest_invalid")
 if overlay.get("runtime_candidates",[]) != Catalog.FIRST_SLICE_ALLOWED_CANDIDATES or overlay.get("supported_hex_hooks",[]) != Catalog.FIRST_SLICE_HEX_HOOKS: return _deny("p1_scope_changed")
 if not overlay.get("runtime_map") is Dictionary or overlay.runtime_map.is_empty(): return _deny("p1_runtime_pins_missing")
 var error: String = _check_map(overlay.runtime_map,[])
 if not error.is_empty(): return _deny("p1_runtime_"+error)
 # Read the two different existing core map shapes explicitly. Neither core is
 # replaced by this UI/session overlay, and no old P1 isolated parent is used.
 for name: String in r1_core.candidate_files:
  var path: String = "res://tests/ink_r1_ordinary_20261005/candidate01/"+name
  if not _valid(path) or FileAccess.get_sha256(path) != str(r1_core.candidate_files[name]): return _deny("r1_core_changed:"+path)
 for relative: String in p1_core.candidate_files:
  var path: String = "res://"+relative
  if not _valid(path) or FileAccess.get_sha256(path) != str(p1_core.candidate_files[relative]): return _deny("p1_core_changed:"+path)
 for relative: String in p1_core.extra_reused_sources:
  var path: String = "res://"+relative
  if not _valid(path) or FileAccess.get_sha256(path) != str(p1_core.extra_reused_sources[relative]): return _deny("p1_collector_changed:"+path)
 if lifesteal.get("parent_binding_sha256","") != P1_CORE_SHA: return _deny("lifesteal_parent_changed")
 for relative: String in lifesteal.candidate_files:
  var path: String = "res://"+relative
  if not _valid(path) or FileAccess.get_sha256(path) != str(lifesteal.candidate_files[relative]): return _deny("p1_lifesteal_changed:"+path)
 for relative: String in lifesteal.frozen_parent_pins:
  var path: String = "res://"+relative
  if not _valid(path) or FileAccess.get_sha256(path) != str(lifesteal.frozen_parent_pins[relative]): return _deny("p1_lifesteal_parent_changed:"+path)
 # Only two production leaves may advance, with every prior link matched.
 error = _check_map(r1.runtime_map,[overlay])
 if not error.is_empty(): return _deny("r1_parent_"+error)
 error = _check_map(e1.runtime_map,[r1,overlay])
 if not error.is_empty(): return _deny("e1_parent_"+error)
 error = _check_map(q2.runtime_map,[e1,r1,overlay])
 if not error.is_empty(): return _deny("q2_parent_"+error)
 for path: String in e1.parent_runtime_maps:
  if not _valid(path) or FileAccess.get_sha256(path) != str(e1.parent_runtime_maps[path]): return _deny("parent_runtime_map_changed:"+path)
  var mapped: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
  if not mapped is Dictionary or not mapped.get("runtime_map") is Dictionary: return _deny("parent_runtime_map_invalid")
  for relative: String in mapped.runtime_map:
   var target: String = "res://"+relative
   if not _valid(target) or FileAccess.get_sha256(target) != str(mapped.runtime_map[relative].sha256): return _deny("parent_dependency_changed:"+target)
 var hooks: Array = Catalog.FIRST_SLICE_HEX_HOOKS.duplicate()
 if include_source_adapter_hooks: hooks.append_array(Prior.ADAPTER_HOOKS)
 return {"accepted":true,"reason":"","capabilities":{"schema_version":1,"hero_id":"yanguizhou","source_binding_id":FileAccess.get_sha256(BINDING_PATH),"runtime_candidates":Catalog.FIRST_SLICE_ALLOWED_CANDIDATES.duplicate(),"supported_hooks":hooks,"ordinary_entry_ready":false,"scope":"Q1/Q2/Q3/E1/P1/base R1; original ten hooks; exact tested P1 core; ordinary composition/native pending"}}

static func _check_map(mapped: Dictionary, successors: Array) -> String:
 for path: String in mapped:
  var expected: String = str(mapped[path])
  for successor: Dictionary in successors:
   var replacement: Dictionary = successor.get("ancestor_pin_replacements",{}).get(path,{})
   if replacement.is_empty(): continue
   if path not in REPLACEABLE or str(replacement.get("before","")) != expected or str(replacement.get("after","")) != str(successor.get("runtime_map",{}).get(path,"")): return "replacement_chain_invalid:"+path
   expected = str(replacement.after)
  if not _valid(path) or FileAccess.get_sha256(path) != expected: return "changed:"+path
 return ""
static func _valid(path: String) -> bool:
 return path.begins_with("res://") and ".." not in path.trim_prefix("res://").split("/") and FileAccess.file_exists(path)
static func _deny(reason: String) -> Dictionary: return {"accepted":false,"reason":reason}
