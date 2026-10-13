extends RefCounted
## Presentation only. The already admitted catalog is the single skill list;
## untouched source descriptions and closed candidates retain their authority.
const RuntimeCatalog = preload("res://tests/ink_ordinary_composed_20261006/candidate01/catalog.gd")
const LEGACY_UNIMPLEMENTED := "规则已确认；该技能尚未实现。"

static func candidates() -> Array:
 return RuntimeCatalog.FIRST_SLICE_ALLOWED_CANDIDATES.duplicate()

static func skill_line() -> String:
 return "当前可学习  ·  " + " / ".join(candidates()) + "；临时功能显示"

static func rest_rule() -> String:
 return "休息点回满生命、清除Buff并结束冷却；基础血瓶不补充"

static func hero_note() -> String:
 return "普通新局首层候选。可学习：" + " / ".join(candidates()) + "。P1/P2同栏互斥，每阶1技能点，最高4阶；R1在英雄6级首次学习。" + rest_rule() + "。部分技能仍使用临时功能显示，美术与音效未完成；全首层和Boss尚未实际通关。未列出的技能及未接强化仍未开放，不代表完整英雄。"

static func scope_text() -> String:
 return "晏归舟 · Lv1 / 0金币 / 0经验 / 1技能点 · 首层12行沿线选择，Boss在最后\n" + skill_line() + "；普攻与Shift可用\nE3：E放A，松开后5秒内再E放B；允许隔墙交换，任一必需落点非法则整次拒绝；H11/H12未开放\n孤帆触边停留，按原时间消散；可穿墙，登舟落点站不下则保留原船\n" + rest_rule() + "；最终美术与音效未完成"

static func p2_rules() -> String:
 return "首次完整Q/E只记上招；交替获得1层墨色，最多3层，刷新全部5秒。同技能不加层不刷新。满层后新成功使用的Q/E首个正伤害耗尽，在该敌中心产生3米普通浓墨；凑满当招和之前已成河/已发舟不消费。Q1松手、Q2/E3合法二段完成、Q3起山、E1入形、E2发舟各计一次；同招后续阶段不另计。过期或消费保留上招；升级保层及剩余时间，仅更新倍率；休息、换房、死亡或换被动全清。P1/P2互斥，每阶1SP、最高4阶。"

static func correct(candidate: String, description: String) -> String:
 var skill: String = candidate.to_upper()
 if description.contains("请在学习面板选择Q1飞流三千或Q3溪山行旅"):
  var available_q: Array = candidates().filter(func(item): return str(item).begins_with("Q"))
  description = description.replace("请在学习面板选择Q1飞流三千或Q3溪山行旅","请在学习面板选择"+" / ".join(available_q))
 if skill not in RuntimeCatalog.FIRST_SLICE_ALLOWED_CANDIDATES: return description
 if skill == "R1":
  description = description.replace("无伤害、无冻结、无治疗、无无敌","领域本体无伤害、无冻结、无治疗")
  if not description.contains("独立施放窗口"):
   description += "\n独立施放窗口：自身移动和Shift按正常速率，世界减速；窗口内免疫伤害与控制，领域、冷却和既有效果仍按世界时间推进。暂停冻结窗口。当前只有临时功能显示，未制作最终演出动画。"
 description = description.replace("P2/P3及未接强化未开放。","P1/P2同栏互斥；P3及未接强化未开放。").replace("P2/P3与未接强化未开放","P1/P2同栏互斥；P3与未接强化未开放")
 return description.replace(LEGACY_UNIMPLEMENTED,"基础" + skill + "已接入；美术与音效尚未全部完成。")

static func projection(shown: Dictionary) -> Dictionary:
 var output: Dictionary = shown.duplicate(true)
 if output.has("tooltip"):
  output.tooltip = correct(str(output.get("candidate","")),str(output.tooltip))
 return output

static func correct_hud(hud: Control) -> void:
 if not is_instance_valid(hud): return
 var cards: Dictionary = {"selected_q":"SelectedQReadOnlyProjection","selected_e":"E3OrdinaryReadOnlyTemporaryCard","selected_p":"P1ReadOnlyTemporaryCard","selected_r":"R1ReadOnlyTemporaryCard"}
 for slot: String in cards:
  var shown: Dictionary = hud.source_model.get(slot,{})
  if shown.is_empty(): continue
  shown = projection(shown)
  hud.source_model[slot] = shown
  var card: Control = hud.get_node_or_null(NodePath(cards[slot]))
  if card != null:
   card.projected = shown.duplicate(true)
   card.tooltip_text = str(shown.get("tooltip",""))
   card.queue_redraw()

static func correct_growth(view: Control) -> void:
 if not is_instance_valid(view): return
 for candidate: String in view.q_choices:
  var button: Button = view.q_choices[candidate].upgrade
  button.tooltip_text = correct(candidate,button.tooltip_text)
 for pair: Array in [["P2",view.p2_choice],["E1",view.e1_choice],["E2",view.e2_choice],["E3",view.e3_choice],["P1",view.p1_choice],["R1",view.r1_choice]]:
  var button: Button = pair[1]
  if is_instance_valid(button): button.tooltip_text = correct(pair[0],button.tooltip_text)
