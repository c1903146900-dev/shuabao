extends RefCounted
## Source-candidate-only exact identity. No inheritance of old engine acceptance.
const SIM_PATH = "res://tests/ink_q2_foundation_20261005/fix01/ink_q2_sim.gd"
const MANIFEST_PATH = "res://tests/ink_q2_foundation_20261005/fix01/capabilities.json"
const RUNTIME_PATH = "res://tests/ink_q2_foundation_20261005/fix01/runtime_binding.json"
const Catalog = preload("res://tests/ink_q2_foundation_20261005/fix01/ink_q2_catalog.gd")
const Prior = preload("res://tests/ink_intermediate_stats_20261004/live_binding.gd")
static func read_capabilities(sim: Node) -> Dictionary:
 if not is_instance_valid(sim) or sim.get_script() == null or sim.get_script().resource_path != SIM_PATH: return {"accepted":false, "reason":"exact_q2_sim_required"}
 var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
 var binding: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUNTIME_PATH))
 if not manifest is Dictionary or not binding is Dictionary: return {"accepted":false, "reason":"candidate_manifest_missing"}
 if FileAccess.get_sha256(RUNTIME_PATH) != manifest.get("runtime_binding_sha256", ""): return {"accepted":false, "reason":"runtime_binding_changed"}
 if manifest.get("runtime_candidates", []) != Catalog.FIRST_SLICE_ALLOWED_CANDIDATES or manifest.get("source_implemented_hooks", []) != Catalog.FIRST_SLICE_HEX_HOOKS: return {"accepted":false, "reason":"candidate_scope_mismatch"}
 if manifest.get("ordinary_entry_ready", true) or manifest.get("runtime_verified_hooks", []) != []: return {"accepted":false, "reason":"source_candidate_cannot_self_promote"}
 if not binding.get("runtime_map") is Dictionary or binding.runtime_map.is_empty(): return {"accepted":false, "reason":"runtime_map_missing"}
 for relative in binding.runtime_map:
  if not relative is String or relative.begins_with("/") or ".." in relative.split("/"): return {"accepted":false, "reason":"invalid_binding_path"}
  if FileAccess.get_sha256("res://" + relative) != binding.runtime_map[relative].sha256: return {"accepted":false, "reason":"runtime_dependency_changed:" + relative}
 var hooks: Array = manifest.source_implemented_hooks.duplicate()
 hooks.append_array(Prior.ADAPTER_HOOKS)
 return {"accepted":true, "reason":"", "capabilities":{"schema_version":1, "hero_id":"yanguizhou", "source_binding_id":manifest.runtime_binding_sha256, "runtime_candidates":manifest.runtime_candidates.duplicate(), "supported_hooks":hooks, "ordinary_entry_ready":false, "scope":"isolated_source_candidate_unverified_Q2"}}
