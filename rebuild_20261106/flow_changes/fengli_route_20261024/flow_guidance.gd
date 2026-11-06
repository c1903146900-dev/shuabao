extends RefCounted
static func text_for(v:Dictionary)->String:
 if not str(v.get("fault","")).is_empty():return "房间载入异常，请返回菜单重试"
 if v.get("paused",false):return "已暂停 · Esc / 空格继续"
 if v.get("map",false):return "点击当前亮起的相邻节点前进 · Esc 返回房间"
 match str(v.get("status","")):
  "service":return "训练区：可先调整技能；按 Enter / 继续前进结束" if v.get("training",false) else "休息区：补给已结算；按 Enter / 继续前进结束"
  "completed":return "首层 12 / 12 完成 · Boss 已击败"
  "defeated":return "角色已倒下 · 返回菜单可重新挑战"
  "combat":
   if v.get("unlearned",false) and int(v.get("points",0))>0:return "有技能点：点击 Q / E 上方 + 学习技能 · Esc 暂停"
   return "剩余 %d 名敌人 · Esc / 空格暂停"%int(v.get("enemies",0))
  "between_rooms","preparation":return "↑ 沿中间通道走到上方青色出口，选择下一房间"
 return "先完成当前选择，再继续探索"
