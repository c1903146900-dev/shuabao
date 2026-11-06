extends RefCounted
static func text_for(v:Dictionary)->String:
 if not str(v.get("fault","")).is_empty():return "房间载入异常，请返回菜单重试"
 if v.get("paused",false):return "已暂停 · 可点技能上方 + 学习；Esc / 空格继续" if int(v.get("points",0))>0 else "已暂停 · Esc / 空格继续"
 if v.get("map",false):return "点击当前亮起的相邻节点前进 · Esc 返回房间"
 if v.get("reenter",false):return "地图已关闭：向下离开出口，再向上走入即可重新选路"
 if v.get("unlearned",false) and int(v.get("points",0))>0 and str(v.get("status",""))=="preparation":return "出发前先点 Q / E 上方 + 学习技能，再走上方青色出口"
 match str(v.get("status","")):
  "service":return "训练区：可先调整技能；按 Enter / 继续前进结束" if v.get("training",false) else "休息区：补给已结算；按 Enter / 继续前进结束"
  "completed":return "首层 12 / 12 完成 · Boss 已击败"
  "defeated":return "角色已倒下 · 返回菜单可重新挑战"
  "combat":
   if v.get("unlearned",false) and int(v.get("points",0))>0:return "有技能点：先 Esc 暂停，再点 Q / E 上方 + 学习技能"
   return "剩余 %d 名敌人 · Esc / 空格暂停"%int(v.get("enemies",0))
  "between_rooms","preparation":return "↑ 沿中间通道走到上方青色出口，选择下一房间"
 return "先完成当前选择，再继续探索"

static func reason_text(reason:String)->String:
 return str({"shop_requires_noncombat_or_settled_victory":"战斗中不能购物：清除本房敌人后再按 P", "shop_after_real_battle_only":"战斗中不能购物：清除本房敌人后再按 P", "safe_node_required":"当前仍在战斗，请先清除敌人", "walk_to_upper_exit":"先走到上方青色出口再选择路线", "complete_current_node_first":"先完成当前房间；休息 / 训练区按 Enter 继续", "resume_before_room_transition":"先按 Esc / 空格恢复游戏", "close_shop_before_room_transition":"先按 P / Esc 关闭商店", "mandatory_hex_pending":"先完成海克斯强化选择", "body_choice_pending":"先完成当前成长选择", "terminal_settlement_pending":"战斗正在结算，请稍后再试"}.get(reason,"操作未完成，请稍后重试"))
