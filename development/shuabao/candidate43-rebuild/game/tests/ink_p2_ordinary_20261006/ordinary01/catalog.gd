extends RefCounted
## Definitions are not implementation. Runtime readiness is injected from the bound Ink Sim.
const Design = preload("res://data/final_design/catalog.gd")
const ShopTable = preload("res://tests/ink_first_floor_flow_20261004/shop_table.gd")
const HERO_ID = "yanguizhou"
const FIRST_SLICE_ALLOWED_CANDIDATES = ["Q1", "Q2", "Q3", "E1", "E2", "E3", "P1", "P2", "R1"]
const FIRST_SLICE_HEX_HOOKS = ["hex.final_design.yanguizhou_h01.v1", "hex.final_design.yanguizhou_h02.v1", "hex.final_design.yanguizhou_h05.v1", "hex.final_design.yanguizhou_h06.v1", "hex.final_design.common_g01.v1", "hex.final_design.common_g05.v1", "hex.final_design.common_g06.v1", "hex.final_design.common_g15.v1", "hex.final_design.common_g24.v1", "hex.final_design.common_g30.v1"]
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
   return {"accepted":false, "reason":"candidate_outside_first_slice"}
 for hook in capabilities.supported_hooks:
  if not hook is String: return {"accepted":false, "reason":"invalid_capability_hook"}
  if hook.begins_with("hex.") and hook not in FIRST_SLICE_HEX_HOOKS:
   return {"accepted":false, "reason":"hex_outside_verified_first_slice"}
 # An intentional first-slice ceiling. Increase only alongside actual family runtime and gates.
 var definitions: Dictionary = Design.build_progression(HERO_ID)
 if definitions.is_empty() or definitions.get("hero_id", "") != HERO_ID:
  return {"accepted":false, "reason":"ink_final_design_missing"}
 var loaded: Dictionary = ShopTable.load_table(table_path, definitions, allow_provisional)
 if not loaded.accepted: return loaded
 definitions = loaded.definitions
 definitions.version = str(definitions.version) + "|ink-p2-current-e3-ordinary-source-candidate-v1"
 definitions["initial_hex_scope"] = "Lv1_Lv4_Lv7_ten_source_effects_four_personal_pending_composed_engine_gate"
 definitions.runtime_candidates = capabilities.runtime_candidates.duplicate()
 definitions.runtime_source_binding = capabilities.source_binding_id
 definitions["q2_limitations"] = "Q2基础两段；H03/H04未开放；临时功能显示，Q2美术/音频未实现"
 definitions["e1_limitations"] = "基础E1接线；H07/H08未开放；形态类别穿行未验；临时文字显示，无美术/音频验收"
 definitions["e2_limitations"] = "基础E2：E朝鼠标发舟，松开后再E登舟；触及房间边界停留，仍按原时间消散，可穿过墙体；落点站不下时拒绝登舟并保留原船。H09/H10关闭；临时功能显示，最终美术与音效未完成"
 definitions["e3_limitations"] = "基础E3：鼠标落点按E放A，松开后在5秒内再E放B；首A不开始CD，到期先消标再开始CD，合法B完成开始CD。普通/精英敌人交换，Boss/队友不交换；单侧空仍可移送，只有实际移动者受近高远低伤害。允许隔墙，但任一必需落点墙内或界外则整次拒绝并保留原窗口。菜单只清输入并暂停原窗口。H11/H12不开放；临时功能显示，最终美术与音效未完成"
 definitions["r1_limitations"] = "基础R1普通接线；H13/H14未开放；临时功能圈，雪景美术/音频未完成"
 definitions["p1_limitations"] = "基础P1：一次完整Q/E伤害阶段结束后仅命中过一敌时补最终增伤，并返当时剩余冷却一次；不提前击杀、不含R1；P1/P2同栏互斥；P3及未接Hex未开放"
 definitions["p2_limitations"] = "P2四阶，与P1同一被动栏，每阶1SP。第一次完整Q/E只记上招，交替加墨至3层并刷新5秒；满层后的新成功施法首个正伤害耗尽并产生普通浓墨。E3在成功B才计使用，保留A原伤快照。过期/消耗保上招，升级保层与期限，休息/换房/死亡/换被动全清。H03/H04/H07至H16及其他未接强化不因此开放；原生、全首层与最终美术未验"
 definitions.runtime_validation = {"engine":"NOT_RUN", "normal_input":"NOT_RUN", "first_floor":"NOT_CONFIGURED", "production_cutover":false}
 return {"accepted":true, "reason":"", "definitions":definitions, "hooks":capabilities.supported_hooks.duplicate()}
