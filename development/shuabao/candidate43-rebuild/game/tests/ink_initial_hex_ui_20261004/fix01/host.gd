extends "res://tests/ink_shop_integrated28_20261004/host.gd"
## Narrow new composition: presentation/audio/death chain is inherited unchanged.
const InitialSim = preload("res://tests/ink_initial_hex_runtime_20261004/ink_initial_sim.gd")
const InitialSession = preload("res://tests/ink_initial_hex_ui_20261004/fix01/session.gd")
const InitialController = preload("res://tests/ink_initial_hex_ui_20261004/fix01/controller.gd")
const InitialHUD = preload("res://tests/ink_initial_hex_ui_20261004/hex_hud.gd")
const InitialInputGuard = preload("res://tests/ink_initial_hex_ui_20261004/input_guard.gd")
const InitialInputRouter = preload("res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_input_adapter.gd")
var initial_flow_diagnostic: bool = false
var initial_hud: Control
var initial_controller: RefCounted
var initial_guard = InitialInputGuard.new()
var initial_started: bool = false
var initial_actions: Array = []
var initial_undo: Button

func _ready() -> void:
 var arguments: PackedStringArray = OS.get_cmdline_user_args()
 if "--ink-shop-funded-diagnostic" in arguments or "--ink-shop-real-diagnostic" in arguments:
  push_error("This initial Hex host accepts ordinary startup or --ink-initial-hex-flow-diagnostic only; old skip/funding branches are not admitted")
  get_tree().quit(2); return
 initial_flow_diagnostic = "--ink-initial-hex-flow-diagnostic" in arguments
 super._ready()
 journal_enabled = true
 _journal_open()
 _write_json("initial_hex_start.json", {"scope":_session_scope(), "source_binding":InitialSession.InitialBinding.EXPECTED_BINDING, "initial_ledger":shop_session.ledger.model.snapshot() if shop_session != null and shop_session.ledger != null else {}, "initial_hex_skipped":false, "automatic_learning":false, "engine_UI_acceptance":false, "ordinary_12_rows_ready":false})

func _session_scope() -> String:
 return "Lv1/0金/0XP/1SP真实初始四选一；完成后仅可显式打一只原AI；非正式12行首层" if initial_flow_diagnostic else "普通Lv1/0金/0XP/1SP真实初始四选一；正式12行内容未配置，开战保持HOLD"

func _start_encounter() -> void:
 if shop_session != null:
  startup_session_error = "fresh_restart_requires_exit_and_new_session"; return
 sim = InitialSim.new(); add_child(sim)
 sim.hero.position = Vector3(0,0,4)
 sim.arena_half_extent = Stage.EXTENT; sim.obstacles = Stage.OBSTACLES.duplicate(true)
 sim.ai_enabled = true; sim.auto_finish = false
 input_router = InitialInputRouter.new(); input_router.bind(sim)
 hero_view = HeroView.new(); add_child(hero_view)
 enemy_view = MinionView.new(); add_child(enemy_view); enemy_view.visible = false
 audio_output.restart_scope()
 shop_session = InitialSession.new()
 var initialized: Dictionary = shop_session.initialize_session(sim, "initial-hex-%d" % Time.get_ticks_usec(), initial_flow_diagnostic)
 if not initialized.accepted: startup_session_error = str(initialized.reason)
 else: shop_session.bind_input_suspender(input_router.suspend_input)
 sim.combat_event.connect(_combat_event)
 sim.encounter_finished.connect(_session_terminal)
 seen_receipts.clear(); q1_view.reset_visuals(); audio_output.clear()
 _refresh(0.0)

func _create_session_controls() -> void:
 super._create_session_controls()
 if shop_session == null or shop_session.ledger == null: return
 var layer := CanvasLayer.new(); layer.layer = 110; add_child(layer)
 initial_hud = InitialHUD.new(); layer.add_child(initial_hud)
 initial_controller = InitialController.new()
 initial_controller.command_completed.connect(_initial_command_completed)
 initial_controller.gameplay_block_changed.connect(_initial_modal_changed)
 initial_controller.bind(shop_session.ledger.model, initial_hud, shop_session.ledger.definitions, {"source_label":"同一真实晏归舟成长账本", "content_label":"Lv1有限候选；正式首层未配置"})
 initial_undo = Button.new(); initial_undo.position = Vector2(22,164); initial_undo.size = Vector2(286,32)
 initial_undo.text = "撤销本次技能投入（安全区）"
 initial_undo.pressed.connect(_undo_initial_skill)
 session_learn.get_parent().add_child(initial_undo)
 session_hint.position.y = 210; session_hint.size.y = 235
 _refresh_session_controls(true)

func _process(delta: float) -> void:
 # The inherited preparation lifecycle owns the first resume. Open afterwards.
 if not _mainprep_required and not initial_started and initial_controller != null and not finished:
  initial_started = true
  initial_controller.ensure_auto_hex()
 super._process(delta)

func _initial_command_completed(request: Dictionary, result: Dictionary) -> void:
 shop_session.progression_command_completed(request, result)
 initial_actions.append({"request":request.duplicate(true), "result":result.duplicate(true), "source_time":sim.hero_time, "transaction_active":sim.transaction_active})
 _record_session_action(str(request.action), result)
 _refresh_session_controls(true)

func _initial_modal_changed(blocked: bool) -> void:
 initial_guard.set_blocked(blocked)
 var result: Dictionary = shop_session.set_modal_blocked(blocked)
 if not result.accepted:
  initial_hud.set_receipt("界面暂停未完成：" + str(result.reason), false)
 audio_output.set_paused(sim.paused)

func _learn_q1() -> void:
 if _mainprep_required or initial_controller == null or not initial_started: return
 if not shop_session.ledger.model.snapshot().pending_milestones.is_empty():
  initial_hud.set_receipt("请先完成当前海克斯选择", false); return
 initial_hud.adapter.request("learn", {"slot_id":"Q", "candidate_id":"Q1", "expected_rank":int(shop_session.ledger.model.state.skills.Q.rank)})

func _undo_initial_skill() -> void:
 if _mainprep_required or initial_controller == null or not initial_started: return
 if not shop_session.ledger.model.snapshot().pending_milestones.is_empty(): return
 initial_hud.adapter.request("undo_new_points")

func _refresh(delta: float) -> void:
 super._refresh(delta)
 if initial_controller != null and not sim.transaction_active:
  initial_controller.present_combat({"hp":sim.hero.hp, "hp_max":sim.hero.stats.max_hp, "stats":sim.hero.stats.duplicate(true), "phase":sim.phase, "room":"开局准备" if sim.phase == "preparation" else sim.room_id})
  if initial_started: initial_controller.ensure_auto_hex()

func _refresh_session_controls(force: bool) -> void:
 super._refresh_session_controls(force)
 if not is_instance_valid(session_header) or shop_session == null or shop_session.ledger == null: return
 var state: Dictionary = shop_session.ledger.model.snapshot()
 session_header.text = ("初始成长流程诊断 · 仅一只原AI" if initial_flow_diagnostic else "普通初始成长 · 正式首层待配置") + "\nLv.%d  金币%d  经验%d  技能点%d  Space暂停/明确继续 · F10退出" % [state.level, state.gold, state.xp, state.points]
 session_next.text = "开始一只原AI诊断（需先真实选择）" if initial_flow_diagnostic else "正式首层未配置 · HOLD"
 session_next.disabled = _mainprep_required or not shop_session.next_room_preflight().accepted
 if is_instance_valid(initial_undo):
  initial_undo.visible = not state.allocations.is_empty()
  initial_undo.disabled = _mainprep_required or not initial_started or state.phase != "safe" or not state.pending_milestones.is_empty() or state.get("actor_dead", false)
 session_learn.visible = int(state.skills.Q.rank) == 0
 session_learn.disabled = _mainprep_required or not initial_started or not state.pending_milestones.is_empty() or state.points < 1 or not shop_session.safe_shop_reason().is_empty()
 var selected: Array[String] = []
 for id in state.selected_hex:
  selected.append(str(shop_session.ledger.definitions.hexes[id].name) + (" · 生效" if state.hex_status[id] == "active" else " · 休眠，学习Q1后生效"))
 var chosen: String = "尚未选择" if selected.is_empty() else "\n".join(selected)
 var stage_text: String = "完成初始四选一后，花原有1技能点学习Q1；选择Hex不送技能点。" if not state.pending_milestones.is_empty() else "初始选择已记入真实账本。"
 session_hint.text = stage_text + "\n已获得：" + chosen + "\n" + ("本显式诊断只有一只原AI，不是正式首层。" if initial_flow_diagnostic else "正式12行路线未配置，保持HOLD。")
 if initial_hud != null and not initial_hud.receipt.is_empty(): session_hint.text += "\n" + str(initial_hud.receipt.text)
 if shop_session.initial_focus_pause: session_hint.text += "\n失焦后保持暂停；完成选择后按Space明确继续"
 if shop_session.status == "diagnostic_complete": session_hint.text += "\n一只原AI诊断已结束；没有额外关卡或奖励"

func _input(event: InputEvent) -> void:
 var retired: bool = initial_guard.observe(event)
 if _mainprep_required:
  super._input(event); return
 var modal: bool = initial_hud != null and initial_hud.blocks_gameplay_input()
 if (modal or retired) and event is InputEventMouse:
  mouse_aim.observe(event, get_viewport().get_visible_rect().size)
 if retired:
  # Clear router's original LMB physical latch; preview was already cancelled.
  if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
   input_router.suspend_input("retired_UI_release")
   input_router.handle_event(event, Vector3.INF)
  get_viewport().set_input_as_handled(); return
 if modal:
  if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
   input_router.handle_event(event, Vector3.INF)
  if event is InputEventKey:
   var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
   if key in [KEY_F8, KEY_F9, KEY_F10]: super._input(event); return
   if key == KEY_ESCAPE and event.pressed: initial_hud.close_panels()
   if key in [KEY_ESCAPE, KEY_Q, KEY_E, KEY_R, KEY_SHIFT, KEY_W, KEY_A, KEY_S, KEY_D, KEY_B, KEY_SPACE, KEY_F6]: get_viewport().set_input_as_handled()
  # Pointer/Tab/Enter remain available to the actual GUI, never the world.
  return
 super._input(event)

func _unhandled_input(event: InputEvent) -> void:
 if initial_hud != null and initial_hud.blocks_gameplay_input():
  get_viewport().set_input_as_handled(); return
 super._unhandled_input(event)

func _gui_blocks_pointer_at(point: Vector2) -> bool:
 if initial_hud != null and initial_hud.blocks_gameplay_input(): return true
 return super._gui_blocks_pointer_at(point)

func _pause(value: bool, reason: String) -> void:
 if shop_session != null and shop_session.initial_modal_open: value = true
 elif not value and reason == "manual_space" and shop_session != null:
  var resumed: Dictionary = shop_session.explicit_resume()
  if not resumed.accepted: value = true
 super._pause(value, reason)

func _focus_lost() -> void:
 initial_guard.focus_lost()
 super._focus_lost()

func _journal_scope() -> Dictionary:
 var scope: Dictionary = super._journal_scope()
 scope.branch = "initial_hex_one_ai" if initial_flow_diagnostic else "ordinary_initial_hex_HOLD"
 scope["hex_modal_open"] = shop_session.initial_modal_open
 return scope

func _journal_ledger() -> Dictionary:
 var result: Dictionary = super._journal_ledger()
 if shop_session != null and shop_session.ledger != null:
  var state: Dictionary = shop_session.ledger.model.snapshot()
  result["selected_hex"] = state.selected_hex.duplicate()
  result["hex_status"] = state.hex_status.duplicate(true)
  result["skills"] = state.skills.duplicate(true)
  result["pending_milestones"] = state.pending_milestones.duplicate()
 return result

func save_evidence(reason: String) -> void:
 if shop_session != null and shop_session.ledger != null:
  _write_json("initial_hex_result.json", {"reason":reason, "scope":_session_scope(), "ledger":shop_session.ledger.model.snapshot(), "initial_actions":initial_actions, "runtime_projection_receipts":shop_session.runtime_projection_receipts, "input_guard":{"held_keys":initial_guard.pressed_keys, "retired_keys":initial_guard.retired_keys, "retired_buttons":initial_guard.retired_buttons}, "full_first_floor":false, "eight_hook_engine_claim":false, "UI_native_accepted":false})
 super.save_evidence(reason)
