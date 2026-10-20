extends RefCounted
## Definitions are not implementation. Runtime readiness is injected from the bound Ink Sim.
const Design = preload("res://data/final_design/catalog.gd")
const ShopTable = preload("res://tests/ink_first_floor_flow_20261004/shop_table.gd")
const R2Values = preload("res://tests/ink_r2_peaks_20261006/candidate01/tuning.gd")
const HERO_ID = "yanguizhou"
const FIRST_SLICE_ALLOWED_CANDIDATES = ["Q1", "Q2", "Q3", "E1", "E2", "E3", "P1", "P2", "P3", "R1", "R2"]
const FIRST_SLICE_HEX_HOOKS = ["hex.final_design.yanguizhou_h01.v1", "hex.final_design.yanguizhou_h02.v1", "hex.final_design.yanguizhou_h03.v1", "hex.final_design.yanguizhou_h04.v1", "hex.final_design.yanguizhou_h05.v1", "hex.final_design.yanguizhou_h06.v1", "hex.final_design.common_g01.v1", "hex.final_design.common_g05.v1", "hex.final_design.common_g06.v1", "hex.final_design.common_g15.v1", "hex.final_design.common_g24.v1", "hex.final_design.common_g30.v1", "hex.final_design.yanguizhou_h09.v1", "hex.final_design.yanguizhou_h10.v1"]
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
 definitions.version = str(definitions.version) + "|ink-boat-h09-h10-successor-v1"
 definitions["initial_hex_scope"] = "Lv1_Lv4_Lv7_fourteen_source_effects_eight_personal_admission_pending"
 definitions.runtime_candidates = capabilities.runtime_candidates.duplicate()
 definitions.runtime_source_binding = capabilities.source_binding_id
 definitions["q2_limitations"] = "Q2基础两段；H03河曲、H04落日熔金进入可选池。H03最多2折点，输入说明随实际选择显示；H04按源4秒缩圈/半秒拍显示。临时功能显示，最终美术/音频未完成"
 definitions["e1_limitations"] = "基础E1接线；H07/H08未开放；形态类别穿行未验；临时文字显示，无美术/音频验收"
 definitions["e2_limitations"] = "基础E2：E朝鼠标发舟，松开后再E登舟；触及房间边界停留，仍按原时间消散，可穿过墙体；落点站不下时拒绝登舟并保留原船。H09回帆、H10不尽按正式规则接入；临时功能显示，最终美术与音效未完成"
 definitions["e3_limitations"] = "基础E3：鼠标落点按E放A，松开后在5秒内再E放B；首A不开始CD，到期先消标再开始CD，合法B完成开始CD。普通/精英敌人交换，Boss/队友不交换；单侧空仍可移送，只有实际移动者受近高远低伤害。允许隔墙，但任一必需落点墙内或界外则整次拒绝并保留原窗口。菜单只清输入并暂停原窗口。H11/H12不开放；临时功能显示，最终美术与音效未完成"
 definitions["r1_limitations"] = "基础R1普通接线与独立施放窗口；自身移动/Shift正常速率，世界减速，窗口内免疫伤害/控制；领域和冷却仍随世界时间。H13/H14未开放；临时功能圈，没有最终演出动画或真联机验收"
 definitions["p1_limitations"] = "基础P1：Q2含H03全折段与H04全部原伤；一次完整Q/E伤害阶段结束后仅命中过一敌时补最终增伤，并返当时剩余冷却一次；不提前击杀、不含R伤害；P1/P2/P3同栏互斥；未接Hex未开放"
 definitions["p2_limitations"] = "P2四阶，与P1同一被动栏，每阶1SP。第一次完整Q/E只记上招，交替加墨至3层并刷新5秒；满层后的新成功施法首个正伤害耗尽并产生普通浓墨。E3在成功B才计使用，保留A原伤快照。过期/消耗保上招，升级保层与期限，休息/换房/死亡/换被动全清。H03/H04沿完整Q2归属；H07至H16及其他未接强化仍未开放；原生、全首层与最终美术未验"
 definitions["r2_limitations"] = "基础R2墨峰：R预瞄后新左键确认固定领域；每次预警选取最密集候选点并锁定，结束收卷。H15/H16关闭；临时调试圈与阶段标记，墨峰正式美术、音频及短演出动画未完成。"
 definitions.skill_descriptions["R2"] = []
 for rank: int in range(1,5): definitions.skill_descriptions["R2"].append(r2_description(rank))
 definitions.runtime_validation = {"engine":"NOT_RUN", "normal_input":"NOT_RUN", "first_floor":"NOT_CONFIGURED", "production_cutover":false}
 return {"accepted":true, "reason":"", "definitions":definitions, "hooks":capabilities.supported_hooks.duplicate()}

static func r2_description(rank: int) -> String:
 var values: Dictionary = R2Values.values(rank)
 if values.is_empty(): return "R2来源未通过"
 return "R2 · 千里江山 · %d阶\n12米内选点生成固定半径%.2f米领域，持续%.1f秒；依次生成%d簇墨峰，每簇预警锁点，峰体0.3秒。每峰%.0f + %.0f%% AP伤害，领域结束收卷%.0f + %.0f%% AP；CD %.0f秒。\n预警按敌方身体密集度选点，Boss不加权；伤害限定在领域内，未锁到目标的峰不伤害。领域成功即生，全程按世界时间推进。独立施放窗口仅1.2秒，自身移动/Shift正常，世界减速且窗口内免伤免控；领域持续不延长该窗口。\nR1/R2同栏择一，首次英雄6级学习1SP，随后三阶各2SP，无额外等级门。R伤害不触发P1/P2。H15/H16未开放。临时调试显示；最终墨峰美术、音频与短演出动画未完成。" % [rank,values.domain_radius,values.duration,values.peak_count,values.peak_flat,100.0*float(values.peak_ap_fraction),values.rollup_flat,values.rollup_ap_percent,values.cooldown]
