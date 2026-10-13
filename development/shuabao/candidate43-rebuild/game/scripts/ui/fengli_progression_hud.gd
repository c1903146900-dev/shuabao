extends "res://scripts/ui/progression_hud.gd"
## Reuses bottom anchored upward choice columns and upgrade controls; never a second modal.
func _render_allocation()->void:
 super._render_allocation()
 var available:Array=projection.get("test_definitions",{}).get("runtime_candidates",[])
 for i in candidate_buttons.size():
  var candidate:String="%s%d"%[selected_skill_slot,i+1]
  if candidate not in available:
   candidate_buttons[i].disabled=true
   candidate_buttons[i].text="尚未实装"
   candidate_buttons[i].tooltip_text="此候选的最终机制尚未接入；不会消费技能点"

func present_progression(data:Dictionary)->void:
 super.present_progression(data)
 var definitions:Dictionary=data.get("test_definitions",{})
 var available:Array=definitions.get("runtime_candidates",[])
 if is_instance_valid(test_panel):
  var r_ready:bool="R1" in available or "R2" in available
  test_panel.skills.R.rank.editable=r_ready
  test_panel.skills.R.pick.disabled=not r_ready
  if not r_ready:test_panel.skills.R.rank.value=0
  test_panel.notice.tooltip_text="当前基础数值待实机平衡；Q2/E1墙体路径、P3升级余数、H13与延迟生命债务的同击交互尚待确认。\n相关分支的临时保护与诊断不代表最终规则。"
  for pick in test_panel.hex_slots:
   for i in range(1,pick.item_count):
    var id:String=str(pick.get_item_metadata(i))
    if id.begins_with("fengli_") and id.trim_prefix("fengli_").to_upper() not in definitions.get("runtime_hexes",[]):
     pick.set_item_disabled(i,true)
     pick.set_item_tooltip(i,"此专属机制尚未接入，不会作为正式候选")
    if id=="common_g02":pick.set_item_disabled(i,true);pick.set_item_tooltip(i,"只适用于远程英雄，风厉为近战")

func render(snapshot:Dictionary)->void:
 super.render(snapshot)
 slots.R.disabled=bool(state.get("skills",{}).get("R",{}).get("action_blocked",false))
 var stats:Dictionary=state.get("stats",{})
 var lines:Array[String]=[]
 for entry in [["攻击力","AD"],["法术强度","AP"],["防御","defense"],["攻速","attack_speed"],["移速","move_speed"],["暴击率","crit_chance"],["冷却缩减","cooldown_reduction"],["吸血","lifesteal"],["普攻吸血（含剑势）","basic_lifesteal"],["韧性","tenacity"],["穿透","penetration"],["每秒生命回复","hp_regen"]]:
  var percent:bool=entry[1] in ["crit_chance","cooldown_reduction","lifesteal","basic_lifesteal","tenacity"]
  var value:String=("%.1f%%"%(float(stats.get(entry[1],0))*100.0)) if percent else _stat(stats,entry[1])
  lines.append(str(entry[0])+"  "+value)
 stat_text.tooltip_text="当前实际属性（包含装备、海克斯与临时效果）\n"+"\n".join(lines)
 allocation.tooltip_text+="\n修业任务与G17奖励单独记账；正式成长和F8测试互不污染。"
