extends Control
## Temporary combat-owned HUD. Replace with a consumer of snapshot()/combat_event.
var state: Dictionary = {}
var hint: String = "靠近目标，闪避红色预警后反击"
var font: Font
func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 font = ThemeDB.fallback_font
func update_snapshot(value: Dictionary) -> void:
 state = value
 queue_redraw()
func text(at: Vector2, value: String, size_px: int = 18, color: Color = Color("d9ecea")) -> void:
 draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)
func _draw() -> void:
 if state.is_empty(): return
 var h: Dictionary = state.hero
 var w: float = size.x
 var bottom: float = size.y - 105.0
 draw_rect(Rect2(0,0,w,91),Color(0.025,0.045,0.058,0.94))
 draw_rect(Rect2(24,22,4,46),Color("3be0c6"))
 text(Vector2(42,40),"风厉 / 断风试炼",26)
 text(Vector2(42,68),"独立战斗白盒  ·  测试初值 v0.1",15,Color("769e9c"))
 text(Vector2(w*0.45,32),"生命  %d / %d" % [ceili(h.hp),ceili(h.max_hp)],17)
 draw_rect(Rect2(w*0.45,43,240,8),Color("263736"))
 draw_rect(Rect2(w*0.45,43,240*maxf(0,h.hp/h.max_hp),8),Color("4adeac"))
 text(Vector2(w*0.45,75),"AD %d   攻速 %.2f   击杀成长 %d/10" % [h.ad,h.attack_speed,h.kill_progress],15,Color("8ab5b1"))
 var alive: int = state.enemies.filter(func(e): return not e.dead).size()
 text(Vector2(w-238,36),"存活敌人  %02d" % alive,20,Color("f5be86"))
 text(Vector2(w-238,65),"世界时间 %.1f  /  ×%.2f" % [state.world_time,state.world_scale],15,Color("879f9e"))
 draw_rect(Rect2(0,bottom,w,105),Color(0.025,0.045,0.058,0.95))
 var cards: Array = [["LMB","长剑","attack"],["SHIFT","冲刺","shift"],["Q","突刺 · %d层" % h.q1_stacks,"q"],["E","超载","e"],["R","乱剑斩杀","r"]]
 var start: float = w*0.5 - 290
 for index in cards.size():
  var x: float = start+index*118
  var entry: Array = cards[index]
  var cd: float = h.cooldowns[entry[2]]
  draw_rect(Rect2(x,bottom+13,108,62),Color("152b2e"))
  draw_rect(Rect2(x,bottom+13,108,2),Color("42d4c2") if cd <= 0 else Color("627979"))
  text(Vector2(x+9,bottom+33),entry[0],15,Color("73dcca"))
  text(Vector2(x+9,bottom+58),"%.1fs" % cd if cd > 0 else entry[1],16)
  if entry[2] == "e" and h.overload_left > 0: text(Vector2(x+54,bottom+33),"%.1f" % h.overload_left,15,Color("ffd284"))
 text(Vector2(24,bottom+32),"WASD 移动",16)
 text(Vector2(24,bottom+55),"鼠标瞄准",16)
 text(Vector2(w-225,bottom+31),"F5 新测试局",15,Color("8baba8"))
 text(Vector2(w-225,bottom+55),"H 隐藏调试面板",15,Color("8baba8"))
 text(Vector2(start,bottom+95),hint,14,Color("87aaa6"))
 if state.phase != "combat":
  var rect = Rect2(w*0.5-270,size.y*0.45-55,540,125)
  draw_rect(rect,Color(0.025,0.055,0.065,0.96))
  var title: String = {"victory":"试炼完成 · 战斗状态已冻结","downed":"倒地 · 本局可自救一次","true_dead":"真死亡 · 当前经验进度扣除30%"}.get(state.phase,"战斗结束")
  text(rect.position+Vector2(25,43),title,24,Color("a4ebd7"))
  text(rect.position+Vector2(25,82),"空格自救  /  F5 开始全新测试局" if state.phase == "downed" else "生命、冷却与保留状态停止推进  /  F5 新局",16)
