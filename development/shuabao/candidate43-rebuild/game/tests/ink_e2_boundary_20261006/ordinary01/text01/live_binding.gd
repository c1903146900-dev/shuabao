extends RefCounted
## Presentation-only explicit successor. Exact gameplay Sim, router, director,
## catalog and all previous runtime bytes remain pinned in the parent map.
const Catalog = preload("res://tests/ink_e2_boundary_20261006/ordinary01/catalog.gd")
const Prior = preload("res://tests/ink_q3_input_growth_20261004/live_binding.gd")
const SIM_PATH := "res://tests/ink_e2_boundary_20261006/ordinary01/sim.gd"
const DIRECTOR_PATH := "res://tests/ink_r1_ordinary_20261005/candidate01/enemy_director.gd"
const BINDING_PATH := "res://tests/ink_e2_boundary_20261006/ordinary01/text01/source_binding.json"
const PARENT_PATH := "res://tests/ink_e2_boundary_20261006/ordinary01/source_binding.json"
const PARENT_SHA := "b0c0ffe609fe3e0170614b6be4bb0b441f97ea3f6ad07b6f989d4dfa7df5bdd5"
const ADAPTER := "res://scripts/integration/yanguizhou_first_floor.gd"
const CHOOSER := "res://scripts/ui/hero_chooser.gd"

static func read_capabilities(sim: Node, include_source_adapter_hooks: bool = false) -> Dictionary:
 if not is_instance_valid(sim) or sim.get_script().resource_path != SIM_PATH: return _deny("exact_retained_e2_sim_required")
 if sim.enemy_director.get_script().resource_path != DIRECTOR_PATH: return _deny("exact_retained_r1_director_required")
 if FileAccess.get_sha256(PARENT_PATH) != PARENT_SHA: return _deny("frozen_e2_parent_changed")
 var parent: Variant = JSON.parse_string(FileAccess.get_file_as_string(PARENT_PATH))
 var binding: Variant = JSON.parse_string(FileAccess.get_file_as_string(BINDING_PATH))
 if not parent is Dictionary or not binding is Dictionary or binding.get("schema","") != "ink-e2-text-successor-1": return _deny("text_binding_missing")
 if binding.get("runtime_candidates",[]) != Catalog.FIRST_SLICE_ALLOWED_CANDIDATES or binding.get("supported_hex_hooks",[]) != Catalog.FIRST_SLICE_HEX_HOOKS: return _deny("text_cannot_expand_runtime_scope")
 var mapped: Dictionary = binding.get("runtime_map",{})
 var changes: Dictionary = binding.get("ancestor_pin_replacements",{})
 if mapped.is_empty() or changes.size() != 2 or not changes.has(ADAPTER) or not changes.has(CHOOSER): return _deny("text_replacement_scope_changed")
 for path: String in parent.runtime_map:
  var expected: String = str(parent.runtime_map[path])
  if changes.has(path):
   var change: Dictionary = changes[path]
   if path not in [ADAPTER,CHOOSER] or str(change.get("before","")) != expected or str(change.get("after","")) != str(mapped.get(path,"")): return _deny("invalid_text_replacement:"+path)
   expected = str(change.after)
  if str(mapped.get(path,"")) != expected: return _deny("parent_runtime_pin_missing_or_changed:"+path)
 if str(mapped.get(PARENT_PATH,"")) != PARENT_SHA: return _deny("parent_manifest_pin_missing")
 for path: String in mapped:
  if not path.begins_with("res://") or ".." in path.trim_prefix("res://").split("/") or not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != str(mapped[path]): return _deny("exact_text_runtime_changed:"+path)
 var hooks: Array = Catalog.FIRST_SLICE_HEX_HOOKS.duplicate()
 if include_source_adapter_hooks: hooks.append_array(Prior.ADAPTER_HOOKS)
 return {"accepted":true,"reason":"","capabilities":{"schema_version":1,"hero_id":"yanguizhou","source_binding_id":FileAccess.get_sha256(BINDING_PATH),"runtime_candidates":Catalog.FIRST_SLICE_ALLOWED_CANDIDATES.duplicate(),"supported_hooks":hooks,"ordinary_entry_ready":false,"scope":"same tested E2/P1/R1/rest gameplay; presentation-only chooser and tooltip correction"}}

static func _deny(reason: String) -> Dictionary:
 return {"accepted":false,"reason":reason}
