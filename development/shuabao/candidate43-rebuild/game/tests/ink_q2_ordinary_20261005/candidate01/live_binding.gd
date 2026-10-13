extends RefCounted
## Explicit new ordinary integration admission; old manifests remain historical.
const Foundation = preload("res://tests/ink_q2_foundation_20261005/fix01/live_binding.gd")
const Prior = preload("res://tests/ink_q3_input_growth_20261004/live_binding.gd")
const Catalog = preload("res://tests/ink_q2_ordinary_20261005/candidate01/catalog.gd")
const SIM_PATH := "res://tests/ink_q2_foundation_20261005/fix01/ink_q2_sim.gd"
const BINDING_PATH := "res://tests/ink_q2_ordinary_20261005/candidate01/source_binding.json"
const FOUNDATION_BINDING := "da6975313e69a66ebe55a82f4367612cb2639fc9935ed874468bc3e74a0ae7d9"
static func read_capabilities(sim: Node, include_source_adapter_hooks: bool = false) -> Dictionary:
 var frozen: Dictionary = Foundation.read_capabilities(sim)
 if not frozen.accepted: return frozen
 if FileAccess.get_sha256("res://tests/ink_q2_foundation_20261005/fix01/source_binding.json") != FOUNDATION_BINDING: return _deny("q2_foundation_binding_changed")
 var overlay: Variant = JSON.parse_string(FileAccess.get_file_as_string(BINDING_PATH))
 if not overlay is Dictionary or overlay.get("schema","") != "ink-q2-ordinary-overlay-1": return _deny("q2_overlay_missing")
 if overlay.get("runtime_candidates",[]) != Catalog.FIRST_SLICE_ALLOWED_CANDIDATES or overlay.get("supported_hex_hooks",[]) != Catalog.FIRST_SLICE_HEX_HOOKS: return _deny("q2_overlay_scope_changed")
 if not overlay.get("runtime_map") is Dictionary or overlay.runtime_map.is_empty(): return _deny("q2_overlay_pins_missing")
 for path: String in overlay.runtime_map:
  if not path.begins_with("res://") or ".." in path.split("/"): return _deny("q2_overlay_path_invalid")
  if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != str(overlay.runtime_map[path]): return _deny("q2_overlay_pin:"+path)
 var hooks: Array = Catalog.FIRST_SLICE_HEX_HOOKS.duplicate()
 if include_source_adapter_hooks: hooks.append_array(Prior.ADAPTER_HOOKS)
 return {"accepted":true,"reason":"","capabilities":{"schema_version":1,"hero_id":"yanguizhou","source_binding_id":FileAccess.get_sha256(BINDING_PATH),"runtime_candidates":Catalog.FIRST_SLICE_ALLOWED_CANDIDATES.duplicate(),"supported_hooks":hooks,"ordinary_entry_ready":false,"scope":"Q1/Q2/Q3 ordinary wiring candidate; ten original hooks; Q2 art/audio unimplemented; engine/native pending"}}
static func _deny(reason: String) -> Dictionary:
 return {"accepted":false,"reason":reason}
