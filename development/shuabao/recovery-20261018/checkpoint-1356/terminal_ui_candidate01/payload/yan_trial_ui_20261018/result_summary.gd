extends RefCounted
## Display of an existing terminal receipt. No reward, settlement, input routing,
## progression command, pause, transition or original Button connection changes.
const OriginalProgression = preload("res://scripts/progression/model.gd")
const ENTRY_RUN: int = 1
var _room_id: int = 0
var _result_key: String = ""
var _expanded: bool = true
var _layer: CanvasLayer
var _shade: ColorRect
var _panel: Panel
var _title: Label
var _subtitle: Label
var _values: Array[Label] = []
var close_button: Button
var open_button: Button
var last_projection: Dictionary = {}

# The source has no cumulative earnings field here. Gold and remaining_xp are
# explicitly frozen settlement balances, not newly granted or total earnings.
static func project(flow: Dictionary, state: Dictionary, receipts: Dictionary) -> Dictionary:
 var settlement: Dictionary = flow.get("settlement", {})
 var run_id: String = str(flow.get("run_id", ""))
 var outcome: String = str(settlement.get("outcome", ""))
 if run_id.is_empty() or str(settlement.get("run_id", "")) != run_id or outcome not in ["victory", "defeat"]:
  return {"ready":false, "reason":"terminal_receipt_missing"}
 for key: String in ["gold", "level", "remaining_xp", "terminal_sequence"]:
  if not settlement.has(key) or not (settlement[key] is int or settlement[key] is float):
   return {"ready":false, "reason":"terminal_number_missing:" + key}
 var kills: Dictionary = credited_kills(run_id, state, receipts)
 return {"ready":true, "run_id":run_id, "outcome":outcome,
  "terminal_sequence":int(settlement.terminal_sequence), "gold_balance":int(settlement.gold),
  "level":int(settlement.level), "remaining_xp":int(settlement.remaining_xp),
  "completed_nodes":int(flow.get("node_index", 0)), "node_count":int(flow.get("node_count", 12)),
  "credited_kills":kills.get("count", 0), "kill_count_available":kills.get("available", false),
  "kill_reason":kills.get("reason", ""), "data_kind":"EXISTING_SETTLEMENT_AND_ACCEPTED_KILL_RECEIPTS"}

static func credited_kills(run_id: String, state: Dictionary, receipts: Dictionary) -> Dictionary:
 if not state.get("reward_ids") is Array: return {"available":false, "reason":"reward_ids_missing"}
 var seen: Dictionary = {}
 for value: Variant in state.reward_ids:
  var reward_id: String = str(value)
  if not reward_id.begins_with(run_id + "|"): continue
  var parts: PackedStringArray = reward_id.split("|")
  if parts.size() != 4 or not parts[1].begins_with(run_id + "/first_floor/") or parts[3].is_empty():
   return {"available":false, "reason":"kill_receipt_scope_unresolved"}
  var receipt: Dictionary = receipts.get("ink-reward:" + reward_id, {})
  var request: Dictionary = receipt.get("request", {})
  var args: Dictionary = request.get("args", {})
  if not receipt.get("result", {}).get("accepted", false) or request.get("action", "") != "reward_minion" or str(args.get("event_id", "")) != reward_id or str(args.get("room", "")) != parts[1]:
   return {"available":false, "reason":"accepted_kill_receipt_missing"}
  seen[reward_id] = true
 return {"available":true, "count":seen.size(), "reason":""}

# Read the original milestone definition and offer selection state. This does
# not open, refresh, select or acknowledge a Hex, and does not call Model.snapshot.
static func pending_hex(state: Dictionary) -> bool:
 for milestone: int in OriginalProgression.MILESTONES:
  if milestone <= int(state.get("level", 1)) and str(state.get("offers", {}).get(str(milestone), {}).get("selected", "")).is_empty(): return true
 return false

func present(room: Node, entry: Node, flow: Dictionary, settled: bool, defeated: bool) -> void:
 if not is_instance_valid(room) or not is_instance_valid(entry): return
 if entry.active_room != room or int(entry.screen) != ENTRY_RUN: return
 if _room_id != room.get_instance_id():
  if is_instance_valid(_layer): _layer.queue_free()
  _room_id = room.get_instance_id()
  _result_key = ""
  _expanded = true
  _layer = null
  last_projection = {}
 if not settled and not defeated:
  _hide()
  last_projection = {"ready":false, "reason":"original_terminal_eligibility_false"}
  return
 if not is_instance_valid(room.sim) or room.shop_session == null or room.shop_session.ledger == null:
  _hide(); return
 var model: RefCounted = room.shop_session.ledger.model
 var projection: Dictionary = project(flow, model.state, model.receipts)
 last_projection = projection.duplicate(true)
 if not projection.get("ready", false): _hide(); return
 var key: String = "%s|%s|%d" % [projection.run_id, projection.outcome, projection.terminal_sequence]
 if _result_key != key:
  _result_key = key
  _expanded = true
 if not is_instance_valid(_layer): _build(room)
 var hex_view: Control = room.initial_hud.hex_draft
 var hex_visible: bool = is_instance_valid(hex_view) and (hex_view.is_visible_in_tree() or bool(hex_view.choosing))
 # A death does not open new milestone choices. Actual open/choosing Hex always
 # wins; an already completed victory also waits for every mandatory choice.
 var blocked: bool = room.shop_session.panel_open or room.shop_session.initial_modal_open or hex_visible
 blocked = blocked or (settled and pending_hex(model.state))
 blocked = blocked or room.diagnostic or room.initial_hud.growth_panel.is_visible_in_tree()
 blocked = blocked or room.finished or not str(room.floor_error).is_empty()
 _layer.visible = not blocked
 _panel.visible = _expanded
 _shade.visible = _expanded
 open_button.visible = not _expanded
 var viewport_size: Vector2 = room.get_viewport().get_visible_rect().size
 _shade.size = viewport_size
 _panel.position = Vector2((viewport_size.x - 760.0) * 0.5, maxf(90.0, (viewport_size.y - 454.0) * 0.5))
 open_button.position = Vector2(462, 82)
 var victory: bool = str(projection.outcome) == "victory"
 _title.text = "第一层完成！" if victory else "本局结束"
 _title.add_theme_color_override("font_color", Color("246F62") if victory else Color("995647"))
 _subtitle.text = ("首领已击败" if victory else "角色已倒下") + "  ·  已完成 %d / %d 个节点" % [projection.completed_nodes, projection.node_count]
 _values[0].text = str(projection.gold_balance)
 _values[1].text = str(projection.credited_kills) if projection.kill_count_available else "未记录"
 _values[2].text = str(projection.level)
 _values[3].text = str(projection.remaining_xp)
 last_projection["blocked"] = blocked
 last_projection["expanded"] = _expanded
 last_projection["visible"] = _layer.visible and _panel.visible

func _hide() -> void:
 if is_instance_valid(_layer): _layer.hide()

# These are the only new Button callbacks. They change local display state only;
# visibility is re-evaluated against live modal/owner state at the next present.
func _set_expanded(value: bool) -> void:
 _expanded = value

func _label(parent: Control, text: String, position: Vector2, size: Vector2, font_size: int, color: Color) -> Label:
 var label := Label.new()
 label.text = text
 label.position = position
 label.size = size
 label.mouse_filter = Control.MOUSE_FILTER_IGNORE
 label.add_theme_font_size_override("font_size", font_size)
 label.add_theme_color_override("font_color", color)
 parent.add_child(label)
 return label

func _style(fill: Color, border: Color, radius: int = 14) -> StyleBoxFlat:
 var style := StyleBoxFlat.new()
 style.bg_color = fill
 style.border_color = border
 style.set_border_width_all(3)
 style.set_corner_radius_all(radius)
 return style

func _button(parent: Node, title: String, name: String) -> Button:
 var button := Button.new()
 button.name = name
 button.text = title
 button.size = Vector2(184, 40)
 button.add_theme_font_size_override("font_size", 16)
 button.add_theme_color_override("font_color", Color("233F42"))
 button.add_theme_color_override("font_hover_color", Color("233F42"))
 button.add_theme_stylebox_override("normal", _style(Color("D4E9DB"), Color("365A55")))
 button.add_theme_stylebox_override("hover", _style(Color("E7F5DF"), Color("365A55")))
 button.add_theme_stylebox_override("pressed", _style(Color("B7D9C8"), Color("365A55")))
 button.add_theme_stylebox_override("focus", _style(Color("00000000"), Color("C69231")))
 parent.add_child(button)
 return button

func _build(room: Node) -> void:
 _values.clear()
 _layer = CanvasLayer.new()
 _layer.name = "TrialResultSummaryLayer"
 _layer.layer = 105 # Below original mandatory Hex/growth110 and frontdoor200.
 _layer.visible = false
 room.add_child(_layer) # Original chooser recursively suspends/restores this layer.
 _shade = ColorRect.new()
 _shade.name = "ResultQuietBackdrop"
 _shade.color = Color("1E35395C")
 _shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
 _layer.add_child(_shade)
 _panel = Panel.new()
 _panel.name = "ResultSummaryCard"
 _panel.size = Vector2(760, 454)
 _panel.mouse_filter = Control.MOUSE_FILTER_STOP
 var paper: StyleBoxFlat = _style(Color("FFF8E8"), Color("365A55"), 22)
 paper.shadow_color = Color("132B3759")
 paper.shadow_size = 8
 paper.shadow_offset = Vector2(0, 5)
 _panel.add_theme_stylebox_override("panel", paper)
 _layer.add_child(_panel)
 _label(_panel, "晏归舟 · 本次旅程", Vector2(30, 25), Vector2(600, 28), 17, Color("708179"))
 _title = _label(_panel, "", Vector2(28, 56), Vector2(700, 54), 36, Color("246F62"))
 _subtitle = _label(_panel, "", Vector2(30, 119), Vector2(700, 30), 19, Color("405857"))
 var names: Array[String] = ["结算时金币余额", "本局已记账击杀", "结算时等级", "结算时本级经验"]
 for index: int in range(4):
  var tile := Panel.new()
  tile.position = Vector2(30 + index * 178, 170)
  tile.size = Vector2(166, 104)
  tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
  tile.add_theme_stylebox_override("panel", _style(Color("F6E5AE") if index == 0 else Color("E1EDE3"), Color("D1D9BD"), 12))
  _panel.add_child(tile)
  _label(tile, names[index], Vector2(12, 12), Vector2(148, 24), 14, Color("53685D"))
  _values.append(_label(tile, "", Vector2(12, 40), Vector2(144, 48), 30, Color("294D48")))
 var note: Label = _label(_panel, "金币为结算时的余额；经验为当前等级进度，不是累计获取。\n摘要只展示本局已有记录，不会再次发放奖励。", Vector2(30, 292), Vector2(700, 52), 14, Color("62756B"))
 note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 _label(_panel, "关闭后可再查看。右上角「选择英雄」沿用原返回流程。", Vector2(30, 359), Vector2(700, 26), 14, Color("53685D"))
 close_button = _button(_panel, "收起摘要", "CloseResultSummary")
 close_button.position = Vector2(546, 392)
 close_button.pressed.connect(_set_expanded.bind(false))
 open_button = _button(_layer, "查看本局结果", "OpenResultSummary")
 open_button.pressed.connect(_set_expanded.bind(true))
