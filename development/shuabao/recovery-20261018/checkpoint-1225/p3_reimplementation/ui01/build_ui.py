from pathlib import Path
import hashlib,json,difflib
B=Path(__file__).resolve().parents[2]/'base/game'
O=Path(__file__).resolve().parent
rows=[]
def emit(name,path,change):
 old=(B/path).read_text();new=change(old);assert new!=old
 (O/name).write_text(new)
 (O/(name+'.patch')).write_text(''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile=path,tofile=path)))
 rows.append(dict(target=path,before=hashlib.sha256(old.encode()).hexdigest(),after=hashlib.sha256(new.encode()).hexdigest(),payload=name))
def catalog(s):
 s=s.replace('"P1", "P2", "R1", "R2"]','"P1", "P2", "P3", "R1", "R2"]',1)
 return s.replace('P1/P2同栏互斥；P3及未接Hex未开放','P1/P2/P3同栏互斥；未接Hex未开放')
def growth(s):
 s=s.replace(' super.present_q_growth(state,definitions)',' super.present_q_growth(state,definitions)\n _present_p3(state,definitions)',1)
 return s+'''
# P3 stays inside the original 420px panel: 142+142+104+16 gaps+16 margins.
var p3_choice: Button
func _ready() -> void:
 super._ready()
 var row: HBoxContainer = p1_choice.get_parent()
 var title: Label = row.get_child(0)
 title.hide()
 p3_choice = Button.new()
 row.add_child(p3_choice)
 p3_choice.custom_minimum_size = Vector2(104,40)
 p3_choice.add_theme_font_size_override("font_size",12)
 p3_choice.mouse_filter = Control.MOUSE_FILTER_STOP
 p3_choice.pressed.connect(func():
  var skill: Dictionary = adapter.state.get("skills",{}).get("P",{"rank":0})
  adapter.request("learn",{"slot_id":"P","candidate_id":"P3","expected_rank":int(skill.rank)}))

func _present_p3(state: Dictionary, definitions: Dictionary) -> void:
 if not is_instance_valid(p3_choice): return
 var skill: Dictionary = state.skills.P
 var rank: int = int(skill.rank) if skill.candidate == "P3" else 0
 var same_or_empty: bool = int(skill.rank) == 0 or skill.candidate == "P3"
 p3_choice.text = "P3 学习1SP" if rank == 0 else ("P3 %d/4 升1SP" % rank if rank < 4 else "P3 4/4 满阶")
 p3_choice.disabled = bool(state.get("actor_dead",false)) or not state.pending_milestones.is_empty() or "P3" not in definitions.get("runtime_candidates",[]) or int(state.points) < 1 or rank >= 4 or not same_or_empty
 var descriptions: Array = definitions.get("skill_descriptions",{}).get("P3",[])
 var detail: String = "P3正式描述缺失"
 if descriptions.size() == 4:
  detail = str(descriptions[maxi(0,rank-1)])
  if rank > 0 and rank < 4: detail += "\\n下一阶："+str(descriptions[rank])
 p3_choice.tooltip_text = detail+"\\n"+RiverText.p3_rules()
 if not same_or_empty: p3_choice.tooltip_text = "先在训练节点洗点，才能切换同栏候选。\\n"+p3_choice.tooltip_text
'''
def runtime(s):
 s=s.replace('P1/P2同栏互斥，每阶','P1/P2/P3同栏互斥，每阶').replace('H03/H04可选，P3仍未开放','H03/H04可选，P3气韵生动可学习')
 line=' description = description.replace("P2/P3及未接强化未开放。","P1/P2同栏互斥；P3及未接强化未开放。").replace("P2/P3与未接强化未开放","P1/P2同栏互斥；P3与未接强化未开放")'
 assert line in s
 s=s.replace(line,' for legacy: String in ["P2/P3及未接强化未开放。","P2/P3与未接强化未开放","P1/P2同栏互斥；P3及未接强化未开放。","P1/P2同栏互斥；P3与未接强化未开放"]:\n  description = description.replace(legacy,"P1/P2/P3同栏互斥；未接强化未开放。")')
 return s+'''
static func p3_rules() -> String:
 return "P3气韵生动：Q/E独立计数，仅成功完整释放计一次，多段与后续登船不重复；不含R。按触发时剩余冷却比例返还。跨房与休息保留计数；死亡或换被动清零。升级保留累计，达到新门槛立即结算；冷却为零留待下一次成功释放，不溢出。P1/P2/P3同栏互斥，每阶1SP，最高4阶。"
'''
base='tests/ink_river_hexes_20261006/ordinary01/'
emit('catalog.gd',base+'catalog.gd',catalog)
emit('growth_hud.gd',base+'growth_hud.gd',growth)
emit('runtime_text.gd',base+'runtime_text.gd',runtime)
(O/'MANIFEST.json').write_text(json.dumps({'status':'WIP_UI_NOT_NATIVE_VERIFIED','files':rows,'layout':'420px nominal only; actual font minimum, viewport containment and clicking require native validation'},ensure_ascii=False,indent=2)+'\n')
for row in rows:print(row['payload'],row['after'])
