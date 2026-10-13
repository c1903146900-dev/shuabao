extends RefCounted
## Isolated source-only Q2 ceiling. No production/ordinary-entry admission.
const Design = preload("res://data/final_design/catalog.gd")
const ShopTable = preload("res://tests/ink_first_floor_flow_20261004/shop_table.gd")
const HERO_ID = "yanguizhou"
const FIRST_SLICE_ALLOWED_CANDIDATES = ["Q1", "Q2", "Q3"]
const FIRST_SLICE_HEX_HOOKS = ["hex.final_design.yanguizhou_h01.v1", "hex.final_design.yanguizhou_h02.v1", "hex.final_design.yanguizhou_h03.v1", "hex.final_design.yanguizhou_h04.v1", "hex.final_design.yanguizhou_h05.v1", "hex.final_design.yanguizhou_h06.v1", "hex.final_design.common_g01.v1", "hex.final_design.common_g05.v1", "hex.final_design.common_g06.v1", "hex.final_design.common_g15.v1", "hex.final_design.common_g24.v1", "hex.final_design.common_g30.v1"]
const CANDIDATES = ["Q1", "Q2", "Q3", "E1", "E2", "E3", "P1", "P2", "P3", "R1", "R2"]

static func build(capabilities: Dictionary, table_path: String, allow_provisional: bool = false) -> Dictionary:
 if capabilities.get("schema_version", 0) != 1 or capabilities.get("hero_id", "") != HERO_ID:
  return {"accepted":false, "reason":"ink_capability_identity_missing"}
 if str(capabilities.get("source_binding_id", "")).is_empty():
  return {"accepted":false, "reason":"ink_source_binding_missing"}
 if not capabilities.get("runtime_candidates") is Array or not capabilities.get("supported_hooks") is Array:
  return {"accepted":false, "reason":"ink_capabilities_missing"}
 for candidate in capabilities.runtime_candidates:
  if candidate not in FIRST_SLICE_ALLOWED_CANDIDATES:
   return {"accepted":false, "reason":"candidate_outside_isolated_q_family"}
 for hook in capabilities.supported_hooks:
  if not hook is String: return {"accepted":false, "reason":"invalid_capability_hook"}
  if hook.begins_with("hex.") and hook not in FIRST_SLICE_HEX_HOOKS:
   return {"accepted":false, "reason":"hex_outside_isolated_q_family"}
 # The old eight-hook ceiling remains immutable. This ceiling is fixture-only.
 var definitions: Dictionary = Design.build_progression(HERO_ID)
 if definitions.is_empty() or definitions.get("hero_id", "") != HERO_ID:
  return {"accepted":false, "reason":"ink_final_design_missing"}
 var loaded: Dictionary = ShopTable.load_table(table_path, definitions, allow_provisional)
 if not loaded.accepted: return loaded
 definitions = loaded.definitions
 definitions.version = str(definitions.version) + "|ink-q2-source-candidate-v1"
 definitions["initial_hex_scope"] = "Q_family_twelve_source_hooks_unverified_new_Q2"
 definitions.runtime_candidates = capabilities.runtime_candidates.duplicate()
 definitions.runtime_source_binding = capabilities.source_binding_id
 definitions.runtime_validation = {"engine":"NOT_RUN", "normal_input":"NOT_RUN", "first_floor":"NOT_CONFIGURED", "production_cutover":false}
 return {"accepted":true, "reason":"", "definitions":definitions, "hooks":capabilities.supported_hooks.duplicate()}
