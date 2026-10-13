extends RefCounted
## Pure strings from the actual ledger/phase. No source or command authority.
static func shop_title(state: Dictionary, flow_diagnostic: bool) -> String:
 var selected: bool = not state.get("selected_hex", []).is_empty()
 var initial_pending: bool = 1 in state.get("pending_milestones", [])
 var context: String = "初始选择已完成" if selected and not initial_pending else "请先完成初始海克斯"
 context += " · 单AI诊断" if flow_diagnostic else " · 普通成长入口"
 return "安全商店 · 金币 %d · 装备 %d / 6 · %s" % [int(state.get("gold", 0)), state.get("inventory", []).size(), context]

static func preparation_status(paused: bool) -> String:
 return "状态：开局准备 · 暂停" if paused else "状态：开局准备"
