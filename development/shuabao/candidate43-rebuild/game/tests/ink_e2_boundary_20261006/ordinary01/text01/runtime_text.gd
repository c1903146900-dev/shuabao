extends RefCounted
## Presentation only. The already admitted catalog is the single skill list;
## untouched source descriptions and closed candidates retain their authority.
const RuntimeCatalog = preload("res://tests/ink_e2_boundary_20261006/ordinary01/catalog.gd")
const LEGACY_UNIMPLEMENTED := "规则已确认；该技能尚未实现。"

static func candidates() -> Array:
 return RuntimeCatalog.FIRST_SLICE_ALLOWED_CANDIDATES.duplicate()

static func skill_line() -> String:
 return "当前可学习  ·  " + " / ".join(candidates()) + "；临时功能显示"

static func rest_rule() -> String:
 return "休息点回满生命、清除Buff并结束冷却；基础血瓶不补充"

static func hero_note() -> String:
 return "普通新局首层候选。可学习：" + " / ".join(candidates()) + "。P1每阶1技能点，最高4阶；R1在英雄6级首次学习。" + rest_rule() + "。部分技能仍使用临时功能显示，美术与音效未完成；全首层和Boss尚未实际通关。未列出的技能及未接强化仍未开放，不代表完整英雄。"

static func scope_text() -> String:
 return "晏归舟 · Lv1 / 0金币 / 0经验 / 1技能点 · 首层12行沿线选择，Boss在最后\n" + skill_line() + "；普攻与Shift可用\n孤帆触及房间边界停留，仍按原时间消散；可穿过墙体；落点站不下时拒绝登舟，舟保留\n" + rest_rule() + "；最终美术与音效未完成"

static func correct(candidate: String, description: String) -> String:
 var skill: String = candidate.to_upper()
 if description.contains("请在学习面板选择Q1飞流三千或Q3溪山行旅"):
  var available_q: Array = candidates().filter(func(item): return str(item).begins_with("Q"))
  description = description.replace("请在学习面板选择Q1飞流三千或Q3溪山行旅","请在学习面板选择"+" / ".join(available_q))
 if skill not in RuntimeCatalog.FIRST_SLICE_ALLOWED_CANDIDATES: return description
 return description.replace(LEGACY_UNIMPLEMENTED,"基础" + skill + "已接入；美术与音效尚未全部完成。")

static func projection(shown: Dictionary) -> Dictionary:
 var output: Dictionary = shown.duplicate(true)
 if output.has("tooltip"):
  output.tooltip = correct(str(output.get("candidate","")),str(output.tooltip))
 return output

static func correct_hud(hud: Control) -> void:
 if not is_instance_valid(hud): return
 var cards: Dictionary = {"selected_q":"SelectedQReadOnlyProjection","selected_e":"E2OrdinaryReadOnlyTemporaryCard","selected_p":"P1ReadOnlyTemporaryCard","selected_r":"R1ReadOnlyTemporaryCard"}
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
 for pair: Array in [["E1",view.e1_choice],["E2",view.e2_choice],["P1",view.p1_choice],["R1",view.r1_choice]]:
  var button: Button = pair[1]
  if is_instance_valid(button): button.tooltip_text = correct(pair[0],button.tooltip_text)
