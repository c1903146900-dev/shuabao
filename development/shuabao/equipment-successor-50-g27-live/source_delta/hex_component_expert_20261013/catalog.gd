extends RefCounted
## One explicit ordinary capability successor. Original twelve-hook catalog and
## every allocator / Model / transaction / stat consumer remain authoritative.
const Existing = preload("res://tests/ink_river_hexes_20261006/ordinary01/catalog.gd")
const SourceAdapter = preload("res://tests/ink_q3_input_growth_20261004/live_binding.gd")
const Design = preload("res://data/final_design/catalog.gd")
const HERO_ID = Existing.HERO_ID
const FIRST_SLICE_ALLOWED_CANDIDATES = Existing.FIRST_SLICE_ALLOWED_CANDIDATES
const PARENT_HEX_HOOKS = Existing.FIRST_SLICE_HEX_HOOKS
const G27_HOOK := "hex.final_design.common_g27.v1"
const FIRST_SLICE_HEX_HOOKS = ["hex.final_design.yanguizhou_h01.v1", "hex.final_design.yanguizhou_h02.v1", "hex.final_design.yanguizhou_h03.v1", "hex.final_design.yanguizhou_h04.v1", "hex.final_design.yanguizhou_h05.v1", "hex.final_design.yanguizhou_h06.v1", "hex.final_design.common_g01.v1", "hex.final_design.common_g05.v1", "hex.final_design.common_g06.v1", "hex.final_design.common_g15.v1", "hex.final_design.common_g24.v1", "hex.final_design.common_g30.v1", "hex.final_design.common_g27.v1"]

static func build(capabilities: Dictionary, table_path: String, allow_provisional: bool = false) -> Dictionary:
 if PARENT_HEX_HOOKS.size()!=12 or FIRST_SLICE_HEX_HOOKS.slice(0,12)!=PARENT_HEX_HOOKS:return _deny("g27_exact_parent_twelve_hooks_required")
 if capabilities.get("runtime_candidates")!=FIRST_SLICE_ALLOWED_CANDIDATES:return _deny("g27_original_candidate_scope_required")
 if not capabilities.get("supported_hooks") is Array:return _deny("g27_capability_hooks_missing")
 var full: Array=FIRST_SLICE_HEX_HOOKS.duplicate()
 full.append_array(SourceAdapter.ADAPTER_HOOKS)
 var actual: Array=capabilities.supported_hooks
 # Exact order and full arrays reject duplicate, unknown, missing and promoted
 # hooks. In particular a caller supplying only the old twelve is not upgraded.
 if actual!=FIRST_SLICE_HEX_HOOKS and actual!=full:return _deny("g27_exact_thirteen_hooks_required")
 if "common_g27" not in Design.approved_proposals():return _deny("g27_formal_pool_approval_required")
 # A read-only legacy view solely reuses Existing.build's original definitions,
 # schema, hero, shop-table and readiness validation. No live Model is bound to
 # this narrower view, and any ancestor rejection is returned unchanged.
 var legacy_view: Dictionary=capabilities.duplicate(true)
 legacy_view.supported_hooks=PARENT_HEX_HOOKS.duplicate()
 if actual==full:legacy_view.supported_hooks.append_array(SourceAdapter.ADAPTER_HOOKS)
 var result: Dictionary=Existing.build(legacy_view,table_path,allow_provisional)
 if not result.get("accepted",false):return result
 if result.get("hooks")!=legacy_view.supported_hooks:return _deny("g27_original_catalog_hook_view_mismatch")
 var definition: Dictionary=result.definitions.get("hexes",{}).get("common_g27",{})
 if definition.get("required_hooks")!=[G27_HOOK] or definition.get("effect_key")!="common_g27" or definition.get("status")!="source_final" or definition.get("activation_status")!="eligible_when_implemented" or definition.get("effective_design_status")!="user_confirmed_formal":return _deny("g27_formal_definition_required")
 result.definitions.version=str(result.definitions.version)+"|g27-ordinary-capability-successor-v1"
 result.definitions.initial_hex_scope="Lv1_Lv4_Lv7_thirteen_source_effects_six_personal_seven_common"
 result.definitions["g27_runtime_scope"]="Original outer-held base/intermediate stat consumer; real supported selection required; no G21 or other new capability."
 result.hooks=actual.duplicate()
 return result

static func _deny(reason: String) -> Dictionary:
 return {"accepted":false,"reason":reason}
