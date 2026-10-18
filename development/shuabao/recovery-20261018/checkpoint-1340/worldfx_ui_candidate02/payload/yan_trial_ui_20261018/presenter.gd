extends RefCounted
## Display-only attachment. Call once per frame after the original Host refresh.
## Never sends commands, changes disabled states, reconnects buttons, or toggles
## map/growth requests. The shared thin Entry owns lifetime and startup admission.
const Settled = preload("res://visual_rework_20261009/settled_floor_text.gd")
const Defeated = preload("res://visual_rework_20261009/defeated_run_text.gd")
const Initial = preload("res://visual_rework_20261009/initial_status_text.gd")
const ENTRY_RUN: int = 1 # Exact original hero_entry.Screen.RUN in the pinned parent.
const Readable = preload("res://visual_rework_20261009/readable_layout.gd")
var _room_id: int = 0
var _hud_id: int = 0
var _original: Dictionary = {}
var _projected: Dictionary = {}
var _hint_backing: ColorRect
var _diagnostics: PanelContainer
var _diagnostics_text: Label
var static_label_report: Dictionary = {}

func present(room: Node, entry: Node) -> void:
 if not is_instance_valid(room) or not is_instance_valid(entry): return
 if entry.active_room != room or int(entry.screen) != ENTRY_RUN: return
 if room._mainprep_required or room._mainprep_pending or room.finished: return
 if not is_instance_valid(room.sim) or room.shop_session == null or room.shop_session.ledger == null: return
 if not is_instance_valid(room.hud) or not is_instance_valid(room.session_header) or not is_instance_valid(room.session_hint): return
 if _room_id != room.get_instance_id():
  _room_id = room.get_instance_id()
  _hud_id = 0
  _original.clear()
  _projected.clear()
  _hint_backing = null
  _diagnostics = null
  _diagnostics_text = null
 if not is_instance_valid(_diagnostics): _build_views(room)
 var raw_header: String = _raw("header", room.session_header.text)
 var raw_hint: String = _raw("hint", room.session_hint.text)
 var raw_equipment: String = _raw("equipment", room.session_equipment.text)
 var raw_footer: String = _raw("footer", room.hud.footer.text)
 var raw_buffs: String = _raw("buffs", room.hud.buffs.text)
 var raw_status: String = room.hud.status.text
 var diagnostic_text: String = room.hud.diag.text
 var debug: bool = bool(room.diagnostic)
 var modal: bool = room.shop_session.panel_open or room.shop_session.initial_modal_open
 var flow: Dictionary = {"status":str(room.shop_session.status), "node_index":int(room.shop_session.node_index)}
 if str(flow.status) in ["completed", "defeated"]: flow = room.shop_session.snapshot()
 var state: Dictionary = room.shop_session.ledger.model.state
 var receipt: Dictionary = room.shop_session.last_receipt
 var receipt_suffix: String = "" if receipt.is_empty() else "\n" + room._reason(str(receipt.get("reason", "")))
 var pause_suffix: String = "" if str(room.floor_error).is_empty() else "\n暂停：" + room._reason(str(room.floor_error))
 var intact: bool = room.shop_session._owner_intact()
 var settled: bool = Settled.eligible(flow, room.sim.phase, room.sim.hero.dead, str(state.phase), intact)
 var defeated: bool = Defeated.eligible(flow, room.sim.phase, room.sim.hero.dead, str(state.phase), intact)
 var hint: String = raw_hint
 if settled:
  hint = Settled.hint(hint, receipt, receipt_suffix, pause_suffix)
  room.session_next.text = "首层已完成（没有下一节点）"
 elif defeated:
  var preflight: Dictionary = room.shop_session.next_room_preflight()
  hint = Defeated.hint(hint, preflight, "\n" + room._reason(str(preflight.get("reason", ""))), receipt, receipt_suffix, pause_suffix)
  room.session_next.text = "本局已结束（无法继续）"
 else:
  hint = Initial.hint(hint, receipt, receipt_suffix, room.sim.phase, str(flow.status), room.sim.hero.dead)
 var outcome: String = "首层已完成" if settled else ("本局已结束" if defeated else "已完成 %d/12" % int(flow.node_index))
 var header: String = "晏归舟 · 第一层 · " + outcome + "\nLv.%d  金币%d  经验%d  技能点%d" % [int(state.level), int(state.gold), int(state.xp), int(state.points)]
 if room.sim.paused: header += " · 已暂停"
 var live: PackedStringArray = PackedStringArray()
 # Failures and explicit pause remain visible even when combat hides route help.
 if not str(room.floor_error).is_empty(): live.append("暂停：" + room._reason(str(room.floor_error)))
 if room.sim.paused: live.append("已暂停 · Space 继续")
 var lines: PackedStringArray = hint.split("\n")
 for line: String in lines:
  if line == str(room.REST_SETTLED_TEXT) and line not in live: live.append(line)
 for index: int in range(5, lines.size()):
  var line: String = lines[index].strip_edges()
  if not line.is_empty() and line not in live: live.append(line)
 if settled or defeated: live.append("再次挑战：选择英雄 → 开始 → 确认")
 var live_hint: String = "\n".join(live)
 var equipment: String = "装备 %d/6\n药水总计最多5瓶\n进入下一节点提交交易" % state.inventory.size()
 _set_text(room.session_header, "header", header)
 _set_text(room.session_hint, "hint", live_hint)
 _set_text(room.session_equipment, "equipment", equipment)
 _set_text(room.hud.footer, "footer", "WASD移动 · 左键普攻 · Q/E/R技能 · Shift闪避 · Space暂停 · M路线 · K技能")
 _set_text(room.hud.buffs, "buffs", Initial.status(raw_buffs, room.sim.phase, str(flow.status), room.sim.hero.dead, room.sim.paused))
 room.hud.footer.tooltip_text = raw_footer
 room.session_hint.tooltip_text = live_hint
 _layout(room, entry)
 var hint_height: float = minf(340.0, maxf(44.0, float(room.session_hint.get_line_count()) * 21.0 + 16.0))
 _hint_backing.size.y = hint_height
 room.session_hint.size.y = hint_height - 16.0
 var urgent: bool = not str(room.floor_error).is_empty() or bool(room.sim.paused)
 room.session_hint.visible = not modal and not debug and (room.session_hint.visible or urgent) and not live_hint.is_empty()
 _hint_backing.visible = room.session_hint.visible
 _diagnostics.visible = debug and not modal
 _diagnostics_text.text = diagnostic_text + "\n\n原顶栏\n" + raw_header + "\n\n完整流程提示\n" + raw_hint + "\n\n装备接入信息\n" + raw_equipment + "\n\n当前技能操作\n" + raw_footer + "\n\n原状态\n" + raw_buffs + "\n" + raw_status
 if is_instance_valid(room.h02_label):
  _diagnostics_text.text += "\n\n" + room.h02_label.text
  room.h02_label.get_parent().visible = false
 # F1 still owns diagnostics_visible. Only its presentation moves into one panel.
 room.hud.diag.visible = false
 entry.return_button.visible = not modal

func _raw(key: String, current: String) -> String:
 if not _projected.has(key) or current != str(_projected[key]): _original[key] = current
 return str(_original.get(key, current))

func _set_text(label: Label, key: String, text: String) -> void:
 label.text = text
 _projected[key] = text

func _build_views(room: Node) -> void:
 _hint_backing = ColorRect.new()
 _hint_backing.name = "TrialLiveHintBacking"
 _hint_backing.position = Vector2(454, 166)
 _hint_backing.size = Vector2(370, 180)
 _hint_backing.color = Color("23333BEF")
 _hint_backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
 var parent: Node = room.session_hint.get_parent()
 parent.add_child(_hint_backing)
 parent.move_child(_hint_backing, room.session_hint.get_index())
 _diagnostics = PanelContainer.new()
 _diagnostics.name = "TrialF1Diagnostics"
 _diagnostics.position = Vector2(14, 82)
 _diagnostics.size = Vector2(810, 520)
 _diagnostics.mouse_filter = Control.MOUSE_FILTER_STOP
 _diagnostics.theme = room.session_header.get_parent().theme
 var style := StyleBoxFlat.new()
 style.bg_color = Color("18252BF8")
 style.content_margin_left = 12
 style.content_margin_right = 12
 style.content_margin_top = 10
 style.content_margin_bottom = 10
 _diagnostics.add_theme_stylebox_override("panel", style)
 room.session_canvas.add_child(_diagnostics)
 var scroll := ScrollContainer.new()
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 _diagnostics.add_child(scroll)
 _diagnostics_text = Label.new()
 _diagnostics_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 _diagnostics_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 _diagnostics_text.add_theme_font_size_override("font_size", 13)
 scroll.add_child(_diagnostics_text)

func _layout(room: Node, entry: Node) -> void:
 room.session_header.position = Vector2(22, 14)
 room.session_header.size = Vector2(604, 52)
 room.session_header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 room.session_header.add_theme_font_size_override("font_size", 13)
 for child: Node in room.session_header.get_parent().get_children():
  if child is ColorRect and child.position == Vector2(14, 10): child.size = Vector2(620, 64)
 room.growth_toggle.position = Vector2(640, 18)
 room.growth_toggle.size = Vector2(134, 32)
 room.session_next.position = Vector2(14, 82)
 room.session_next.size = Vector2(430, 36)
 room.service_continue.position = Vector2(462, 82)
 room.service_continue.size = Vector2(354, 36)
 room.shop_open_button.position = Vector2(462, 126)
 room.shop_open_button.size = Vector2(354, 32)
 room.route_map.position = Vector2(14, 126)
 room.route_map.size = Vector2(430, 476)
 room.session_hint.position = Vector2(462, 174)
 room.session_hint.size = Vector2(354, 164)
 room.session_hint.add_theme_font_size_override("font_size", 14)
 room.session_equipment.position = Vector2(944, 642)
 room.session_equipment.size = Vector2(146, 56)
 room.session_equipment.add_theme_font_size_override("font_size", 11)
 room.session_equipment.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 entry.return_button.position = Vector2(1112, 18)
 entry.return_button.size = Vector2(154, 32)
 entry.return_button.add_theme_font_size_override("font_size", 14)
 for child: Node in room.hud.get_children():
  if child is Button:
   if child.text.begins_with("商店"):
    child.position = Vector2(782, 18)
    child.size = Vector2(102, 32)
    child.text = "商店 P"
   elif child.text.begins_with("诊断"):
    child.position = Vector2(892, 18)
    child.size = Vector2(102, 32)
   elif child.text.begins_with("退出"):
    child.position = Vector2(1002, 18)
    child.size = Vector2(102, 32)
    child.text = "退出"
  elif child is Label and child.position == Vector2(22, 16):
   child.visible = false # Frozen specimen title, not source health/status.
 room.hud.footer.position = Vector2(385, 608)
 room.hud.footer.size = Vector2(710, 24)
 room.hud.footer.add_theme_font_size_override("font_size", 12)
 room.hud.buffs.position = Vector2(186, 608)
 room.hud.buffs.size = Vector2(190, 20)
 room.hud.status.position = Vector2(462, 540)
 room.hud.status.size = Vector2(354, 48)
 room.hud.status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 room.hud.status.add_theme_font_size_override("font_size", 12)
 var status: String = room.hud.status.text
 room.hud.status.visible = not status.is_empty() and not status.begins_with("实机美术待验") and not status.begins_with("HUD细化候选") and not status.contains("F6") and not room.shop_session.panel_open and not room.shop_session.initial_modal_open
 if _hud_id != room.hud.get_instance_id():
  _hud_id = room.hud.get_instance_id()
  static_label_report = Readable.apply(room.hud, room.session_equipment)
