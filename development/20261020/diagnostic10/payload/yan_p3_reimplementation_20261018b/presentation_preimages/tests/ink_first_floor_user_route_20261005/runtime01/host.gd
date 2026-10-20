extends "res://tests/ink_intermediate_shop_ui_20261004/fix02/host.gd"
## Explicit opt-in source candidate. No production/default entry change.
const FloorSim = preload("res://tests/ink_q3_foundation_20261004/fix02/ink_q3_sim.gd")
const FloorSession = preload("res://tests/ink_first_floor_user_route_20261005/runtime01/floor_session.gd")
const FloorRouter = preload("res://tests/ink_q3_input_growth_20261004/input_adapter.gd")
const FloorController = preload("res://tests/ink_q3_input_growth_20261004/controller.gd")
const FloorHUD = preload("res://tests/ink_normal_floor_host_20261004/growth_hud.gd")
const EnemyLayer = preload("res://tests/ink_normal_floor_host_20261004/enemy_layer.gd")
const CaptureAnchor = preload("res://tests/ink_normal_floor_host_20261004/capture_anchor.gd")
const Preview = preload("res://tests/ink_normal_floor_host_20261004/preview.gd")
const MountainView = preload("res://tests/ink_q3_visual_20261004/dynamic03/ink_q3_event_presenter.gd")
const REWARD_ROOT := "res://tests/ink_first_floor_user_route_20261005/runtime01/"
const MAX_EVENT_LOG := 512
var enemy_layer: Node3D
var mountain_view: Node3D
var aim_preview: Node3D
const RouteMap = preload("res://tests/ink_first_floor_user_route_20261005/runtime01/route_map.gd")
var route_map
var map_visible_requested := true
var row_choices: HBoxContainer
var service_continue: Button
var shop_open_button: Button
var floor_error: String = ""
var q3_pending: Array = []
var _shown_revision: int = -1
var _shown_route: String = ""
var _controls_refreshing: bool = false
var dropped_history: Dictionary = {}
func _ready() -> void:
 for argument: String in OS.get_cmdline_user_args():
  if argument in ["--ink-gate","--ink-intermediate-funded-diagnostic","--ink-shop-funded-diagnostic","--ink-shop-real-diagnostic","--ink-initial-hex-flow-diagnostic"]:
   push_error("normal_floor_candidate_rejects_diagnostic_or_funding_flags"); get_tree().quit(2); return
 super._ready()
 journal_enabled = false
 if recording != null: recording.close(); recording = null
 _refresh_session_controls(true)
func _session_scope() -> String:
 return "晏归舟 · 普通Lv1 / 0金 / 0XP / 原1SP · 首层12行沿线选择/Boss最后\n300条连线路径；Q1/Q3与BASIC/Shift接线候选；全流程/原生/美术/性能尚未验收"
# Fresh-construction injection seams. Defaults preserve the frozen Q1/Q3 host.
func _make_floor_sim() -> Node:
 return FloorSim.new()
func _make_floor_router() -> RefCounted:
 return FloorRouter.new()
func _make_floor_session() -> RefCounted:
 return FloorSession.new()
func _make_floor_hud() -> Control:
 return FloorHUD.new()
func _start_encounter() -> void:
 if shop_session != null: startup_session_error = "fresh_restart_requires_exit_and_new_session"; return
 sim = _make_floor_sim(); add_child(sim)
 sim.hero.position = Vector3(0,0,4)
 sim.ai_enabled = true; sim.auto_finish = false
 room_binding_report = RoomLayout.bind_to_sim(sim); bound_room_sim_id = sim.get_instance_id()
 input_router = _make_floor_router(); input_router.bind(sim)
 hero_view = MotionView.new(); add_child(hero_view)
 enemy_view = CaptureAnchor.new(); add_child(enemy_view); enemy_view.visible = false
 enemy_layer = EnemyLayer.new(); add_child(enemy_layer)
 mountain_view = MountainView.new(); add_child(mountain_view)
 aim_preview = Preview.new(); add_child(aim_preview)
 shop_session = _make_floor_session()
 var configured: Dictionary = shop_session.configure_reward_table(REWARD_ROOT+"reward_table.json",REWARD_ROOT+"rewards.csv",REWARD_ROOT+"validation_result.json",true)
 var loaded: Dictionary = FloorSession.MixedSchema.load_definition(FloorSession.DEFAULT_DEFINITION,true)
 var initialized: Dictionary = configured
 if configured.accepted and loaded.accepted:
  initialized = shop_session.initialize_floor(sim,loaded.definition,"normal-floor-%d" % Time.get_ticks_usec(),true)
 elif not loaded.accepted: initialized = loaded
 if not initialized.accepted: startup_session_error = str(initialized.reason); floor_error = startup_session_error
 else: shop_session.bind_input_suspender(input_router.suspend_input)
 sim.combat_event.connect(_combat_event); sim.encounter_finished.connect(_session_terminal)
 enemy_layer.reader.capture(sim)
 seen_receipts.clear(); q1_view.reset_visuals(); audio_output.restart_scope(); audio_output.clear()
 _refresh(0.0)
func _create_session_controls() -> void:
 session_canvas = CanvasLayer.new(); session_canvas.layer = 100; add_child(session_canvas)
 var overlay := Control.new(); overlay.theme = preload("res://tests/ink_style_specimen_20261004/style.gd").ui_theme()
 overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE; session_canvas.add_child(overlay)
 var backing := ColorRect.new(); backing.position = Vector2(14,10); backing.size = Vector2(885,64); backing.color = Color("23333BDD"); backing.mouse_filter = Control.MOUSE_FILTER_IGNORE; overlay.add_child(backing)
 session_header = Label.new(); session_header.position = Vector2(22,14); session_header.size = Vector2(868,56); session_header.add_theme_font_size_override("font_size",14); overlay.add_child(session_header)
 row_choices = HBoxContainer.new(); row_choices.position = Vector2(22,84); row_choices.size = Vector2(420,42); overlay.add_child(row_choices); row_choices.visible = false
 route_map = RouteMap.new(); route_map.position = Vector2(14,82); route_map.size = Vector2(430,526); overlay.add_child(route_map)
 route_map.node_chosen.connect(_select_row)
 if shop_session != null and shop_session.row_state != null: route_map.bind_route(shop_session.route)
 session_next = Button.new(); session_next.position = Vector2(462,90); session_next.size = Vector2(310,36); session_next.pressed.connect(_request_next_room); overlay.add_child(session_next)
 service_continue = Button.new(); service_continue.position = Vector2(462,132); service_continue.size = Vector2(310,36); service_continue.text = "本节点完成，选择下一行"; service_continue.pressed.connect(_complete_service); overlay.add_child(service_continue)
 shop_open_button = Button.new(); shop_open_button.position = Vector2(462,174); shop_open_button.size = Vector2(310,34); shop_open_button.text = "打开商店 · P"; shop_open_button.pressed.connect(func(): _shop(true)); overlay.add_child(shop_open_button)
 session_hint = Label.new(); session_hint.position = Vector2(462,216); session_hint.size = Vector2(310,174); session_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; session_hint.add_theme_font_size_override("font_size",14); overlay.add_child(session_hint)
 session_equipment = Label.new(); session_equipment.position = Vector2(944,642); session_equipment.size = Vector2(310,65); session_equipment.add_theme_font_size_override("font_size",13); overlay.add_child(session_equipment)
 # Legacy button is not shown; both implemented Q candidates use the real HUD.
 session_learn = Button.new(); session_learn.visible = false; overlay.add_child(session_learn)
 shop_panel = SignalSafeShopPanel.new(); session_canvas.add_child(shop_panel); shop_panel.bind_session(shop_session)
 shop_panel.close_requested.connect(func(): _shop(false)); shop_panel.transaction_requested.connect(_submit_shop)
 if shop_session == null or shop_session.ledger == null: _refresh_session_controls(true); return
 var growth_layer := CanvasLayer.new(); growth_layer.layer = 110; add_child(growth_layer)
 initial_hud = _make_floor_hud(); growth_layer.add_child(initial_hud)
 initial_hud.training_requested.connect(_training)
 initial_controller = FloorController.new()
 initial_controller.gameplay_block_changed.connect(_initial_modal_changed)
 initial_controller.bind_session(shop_session,initial_hud)
 preload("res://tests/ink_normal_floor_layout_fix01_20261005/growth_hud.gd").apply_layout(initial_hud)
 # Session's authoritative projection is connected first, exactly once.
 initial_controller.command_completed.connect(_initial_command_completed)
 _refresh_session_controls(true)
func _initial_command_completed(request: Dictionary, result: Dictionary) -> void:
 initial_actions.append({"request":request.duplicate(true),"result":result.duplicate(true),"source_time":sim.hero_time})
 _record_session_action(str(request.action),result)
 _refresh_session_controls(true)
func _transition_result(action: String, result: Dictionary) -> void:
 shop_session.update_after_source_step()
 _record_session_action(action,result)
 # Session service/route APIs advance revision without Controller.command.
 # Refresh Adapter from the authoritative Model before any next UI request.
 if initial_controller != null: initial_controller.refresh()
 _refresh_session_controls(true)
func _select_row(row: int, node_id: String) -> void:
 if _mainprep_required or finished: return
 _transition_result("select_node",shop_session.select_node(row,node_id))
func _request_next_room() -> void:
 if _mainprep_required or finished or shop_session == null: return
 var checked: Dictionary = shop_session.next_room_preflight()
 if checked.accepted: checked = enemy_layer.preflight(checked.node.payload)
 if not checked.accepted: _transition_result("enter_selected_node",checked); return
 var result: Dictionary = shop_session.enter_selected_node()
 if result.accepted:
  enemy_layer.reset_scope(); enemy_layer.reader.capture(sim)
  q1_view.reset_visuals(); mountain_view.reset_visuals(); q3_pending.clear(); h02_pending.clear(); seen_receipts.clear()
  if is_instance_valid(h02_view): h02_view.reset_visuals()
  audio_output.restart_scope(); audio_output.set_paused(sim.paused)
 _transition_result("enter_selected_node",result)
 _refresh(0.0)
func _complete_service() -> void:
 if _mainprep_required or finished: return
 _transition_result("complete_service",shop_session.complete_service())
func _training() -> void:
 if _mainprep_required or finished: return
 _transition_result("training_respec",shop_session.reset_training())
func _shop(open: bool) -> void:
 if _mainprep_required or finished or shop_session == null: return
 var result: Dictionary = shop_session.open_panel() if open else shop_session.close_panel()
 audio_output.set_paused(sim.paused)
 _transition_result("shop_open" if open else "shop_close",result)
func _submit_shop(id: String, action: String, args: Dictionary) -> void:
 _transition_result(action,shop_session.submit(id,action,args))
func _refresh_session_controls(force: bool) -> void:
 if not is_instance_valid(session_header) or shop_session == null or _controls_refreshing: return
 _controls_refreshing = true
 if shop_session.ledger == null:
  session_header.text = "初始化未完成 · " + _reason(startup_session_error) + " · F10退出"
  session_next.disabled = true; service_continue.disabled = true; shop_open_button.disabled = true
  _controls_refreshing = false; return
 var state: Dictionary = shop_session.ledger.model.snapshot()
 var flow: Dictionary = shop_session.snapshot()
 var row_key: String = JSON.stringify([flow.row_state.get("status",""),flow.row_state.get("row_number",0),flow.row_state.get("selected_identity",{}),flow.node_index,flow.status])
 if force or state.revision != _shown_revision or row_key != _shown_route:
  _shown_revision = int(state.revision); _shown_route = row_key
  if initial_controller != null: initial_controller.refresh()
  route_map.present(shop_session.available_choices(),flow.row_state,_mainprep_required or shop_session.panel_open or shop_session.initial_modal_open)
  shop_panel.refresh(force)
 session_header.text = "晏归舟首层开发候选 · 已完成 %d/12 行 · %s · F10退出\nLv.%d  金币%d  XP%d  SP%d · Space暂停/继续 · Q1/Q3，其他技能未开放" % [flow.node_index,str(flow.status),state.level,state.gold,state.xp,state.points]
 var preflight: Dictionary = shop_session.next_room_preflight()
 session_next.text = "进入 %s（离区时提交交易）" % str(flow.row_state.get("selected_identity",{}).get("node_id","未选择"))
 session_next.disabled = _mainprep_required or not preflight.accepted or not floor_error.is_empty()
 service_continue.visible = shop_session._entered_service("rest") or shop_session._entered_service("training")
 service_continue.disabled = _mainprep_required or flow.service_ready or shop_session.panel_open or sim.paused
 shop_open_button.visible = shop_session.shop_location_reason().is_empty()
 shop_open_button.disabled = _mainprep_required or shop_session.panel_open
 route_map.visible = map_visible_requested and flow.status != "combat" and not shop_session.panel_open and not shop_session.initial_modal_open
 route_map.size.y = maxf(420.0,get_viewport().get_visible_rect().size.y-156.0)
 session_hint.text = "从下往上沿线选下一行；末行Boss。\n精英1–2 · 休息2–3 · 训练1–2\nM：查看/收起路线　P：安全区商店\nB旧诊断入口已停用；技能键未改变。\n休息恢复效果尚待来源定义，当前不加血。\n" + _reason(str(preflight.reason))
 if not shop_session.last_receipt.is_empty(): session_hint.text += "\n" + _reason(str(shop_session.last_receipt.get("reason","")))
 if not floor_error.is_empty(): session_hint.text += "\n暂停：" + _reason(floor_error)
 session_equipment.text = "装备 %d/6 · 基础11/一级17\n商店关开不提交；实际进入下一节点提交\n其余装备/药品/技能未开放" % state.inventory.size()
 _controls_refreshing = false
func _reason(reason: String) -> String:
 var messages: Dictionary = {"":"", "explicit_node_selection_required":"请先点击当前行的一个节点", "mandatory_hex_pending":"请先完成当前海克斯四选一", "close_shop_before_room_transition":"请关闭商店面板后再进入下一节点", "resume_before_room_transition":"当前已暂停；按Space明确继续", "complete_current_node_first":"请先完成当前战斗或服务节点", "hero_too_close_to_next_spawn":"当前位置离下一波出生点太近，请先移动", "entered_training_node_required":"洗点仅在实际进入的训练节点可用", "shop_requires_noncombat_or_settled_victory":"商店仅在非战斗区域或真实战斗结算后可用", "terminal_settlement_pending":"当前战斗正在结算", "legacy_b_shop_retired_use_p":"旧B商店入口已停用，请按P", "service_ready_still_in_same_area":"本行已完成；仍在当前服务区域，进入下一节点才离区", "service_already_ready":"当前服务已完成，请选择下一行", "candidate_roster_exceeds_six":"候选显示最多支持六名敌人，已拒绝进入", "candidate_not_implemented":"该技能或效果尚未接入", "node_selected_not_entered":"节点已选择，请点击进入", "q3_presentation_not_ready":"Q3表现资源未就绪，玩法已暂停", "living_enemy_missing_body":"敌人身体未就绪，玩法已暂停", "safe_node_required":"当前不在安全节点", "fresh_restart_requires_exit_and_new_session":"请F10退出后重新开启新局", "defer_to_outer_boundary":"当前动作尚未结束，请稍后重试"}
 return str(messages.get(reason,"操作未完成（"+reason+"）"))
func _refresh_local_text() -> void:
 if is_instance_valid(shop_panel) and is_instance_valid(shop_panel._title): shop_panel._title.text = "当前真实商店 · 基础11/一级17 · 开发候选"
func _gui_blocks_pointer_at(point: Vector2) -> bool:
 if is_instance_valid(route_map) and route_map.visible and route_map.get_global_rect().has_point(point): return true
 if initial_hud != null and _control_stops_at(initial_hud,point): return true
 return super._gui_blocks_pointer_at(point)
func _input(event: InputEvent) -> void:
 if event is InputEventKey:
  var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
  if key in [KEY_P,KEY_B,KEY_M]:
   if not _mainprep_required and not finished and shop_session != null and shop_session.ledger != null and event.pressed and not event.echo:
    if key == KEY_P: _shop(not shop_session.panel_open)
    elif key == KEY_B:
     shop_session.last_receipt = {"accepted":false,"reason":"legacy_b_shop_retired_use_p"}; _refresh_session_controls(true)
    elif not shop_session.panel_open and not shop_session.initial_modal_open:
     map_visible_requested = not map_visible_requested; _refresh_session_controls(true)
   get_viewport().set_input_as_handled(); return
 # GUI consumes presses before _unhandled_input, so retire aim here first.
 # Physical LMB-up is still observed by the inherited pre-GUI release handler.
 if not _mainprep_required and input_router != null and event is InputEventMouse:
  if _gui_blocks_pointer_at(event.position): input_router.suspend_input("pointer_over_UI")
 super._input(event)
func _unhandled_input(event: InputEvent) -> void:
 if finished or sim == null or _mainprep_required or not floor_error.is_empty(): return
 if _mainprep_drain_held(event): get_viewport().set_input_as_handled(); return
 if shop_session.panel_open or (initial_hud != null and initial_hud.blocks_gameplay_input()): return
 if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed: return
 var ground: Vector3 = _ground_for_event(event,true)
 var blocked: bool = false
 if event is InputEventMouse: blocked = not mouse_aim.accepts(event.position) or _gui_blocks_pointer_at(event.position)
 var result: Dictionary = input_router.route_event(event,stage.ground_point,_current_pointer_ground(),blocked)
 if result.get("reason","") != "unmapped_input": _record_pointer_input(event,ground,result,"current event coordinate -> audited Q1/Q3 router")
func _pause(value: bool, reason: String) -> void:
 if not floor_error.is_empty(): value = true
 super._pause(value,reason)
func _combat_event(event: Dictionary) -> void:
 if shop_session != null and shop_session.ledger != null:
  var observed: Dictionary = shop_session.observe_event(sim,event)
  if event.get("kind", "") in ["damage","kill"] and not observed.accepted: shop_session.last_receipt = observed
 enemy_layer.observe(sim,event)
 var detached: Dictionary = event.duplicate(true)
 events.append(detached)
 _queue_h02_event(detached)
 if str(event.get("kind", "")).begins_with("ink_q3_"):
  if q3_pending.size() < 128: q3_pending.append(detached)
  else: floor_error = "q3_event_buffer_overflow"
 hero_view.receive(detached,sim.hero_time)
 audio_output.consume(detached,sim.ink_presenter_snapshot())
func _refresh(delta: float) -> void:
 if sim == null: return
 if shop_session != null and shop_session.ledger != null: shop_session.update_after_source_step()
 input_router.synchronize_preview()
 if initial_started and initial_controller != null: initial_controller.ensure_auto_hex()
 if is_instance_valid(stage) and stage.get_script() != RoomView:
  stage.free(); stage = RoomView.new(); add_child(stage)
 if is_instance_valid(q1_view) and q1_view.get_script() != BrushWave:
  q1_view.free(); q1_view = BrushWave.new(); add_child(q1_view)
 if is_instance_valid(hud) and hud.get_script() != SkillHud:
  var parent_canvas: Node = hud.get_parent(); hud.free(); hud = SkillHud.new(); parent_canvas.add_child(hud)
  hud.shop_requested.connect(_shop); hud.exit_requested.connect(func(): close_sample("visible_exit")); hud.diagnostics_requested.connect(_toggle_diagnostics)
 var full: Dictionary = sim.snapshot()
 var ink: Dictionary = sim.ink_presenter_snapshot()
 hero_view.set_received_view_input(ViewInput.capture(input_router,sim.hero.position,str(sim.ink_input.phase),_current_pointer_ground(),not sim.paused and sim.phase == "combat" and not sim.hero.dead))
 hero_view.set_presentation_context(_safe_presentation_context())
 if not sim.paused: hero_view.present(ink)
 q1_view.present(ink); basic_view.present(ink)
 var fresh: Array = q3_pending; q3_pending = []
 mountain_view.present(ink,fresh)
 aim_preview.present(input_router.preview(_current_pointer_ground()))
 _present_h02(ink)
 var enemy_report: Dictionary = enemy_layer.present(sim,full,_safe_presentation_context())
 if enemy_report.get("status", "") != "ready": floor_error = str(enemy_report.get("reason","enemy_presentation_not_ready"))
 if mountain_view.get_diagnostics().get("status", "") == "HOLD": floor_error = "q3_presentation_not_ready"
 if not floor_error.is_empty() and not sim.paused: _pause(true,"presentation_fail_closed")
 stage.follow(full.hero.position,delta)
 stage.present_grounding(full.hero,[])
 stage.enemy_grounding.visible = false # Never misrepresent one enemy shadow as the roster.
 hud.present(full,ink,_brief()); hud.shop_open = shop_session != null and shop_session.panel_open; hud.shop_group.visible = false
 last_presented_full = sim.snapshot(); last_presented_ink = sim.ink_presenter_snapshot()
 if initial_controller != null and not sim.transaction_active:
  initial_controller.present_combat({"hp":sim.hero.hp,"hp_max":sim.hero.stats.max_hp,"stats":sim.hero.stats.duplicate(true),"phase":sim.phase,"room":sim.room_id})
 _refresh_session_controls(false); _refresh_local_text(); _refresh_h02_label()
func _process(delta: float) -> void:
 super._process(delta) # Existing free_move/safe clock and exactly one source step.
 for entry: Dictionary in [{"name":"inputs","list":inputs},{"name":"events","list":events},{"name":"pauses","list":pauses},{"name":"initial_actions","list":initial_actions},{"name":"process_ms","list":process_intervals_ms},{"name":"draw_ms","list":draw_intervals_ms}]:
  var list: Array = entry.list
  if list.size() > MAX_EVENT_LOG:
   var excess: int = list.size()-MAX_EVENT_LOG
   dropped_history[entry.name] = int(dropped_history.get(entry.name,0))+excess
   for index in range(excess): list.pop_front()
func _record_session_action(action: String, result: Dictionary) -> void:
 session_input_serial += 1
 inputs.append({"category":"normal_floor_ui","action":action,"receipt":result.duplicate(true),"serial":session_input_serial,"source_time":sim.hero_time})
func _journal_open() -> void:
 pass # Explicit F8/F9 and bounded callbacks only; no huge per-frame JSON stream.
func _commerce_evidence() -> Dictionary:
 return {"runtime_source_binding":FloorSession.IntermediateBinding.EXPECTED_BINDING,"source_scope":_session_scope(),"test_initial_gold":0,"initial_hex_skipped":false,"automatic_learning":false,"reward_binding":shop_session.ledger.model.reward_binding() if shop_session != null and shop_session.ledger != null else {},"recipe_projection":shop_panel.recipe_projection.duplicate(true) if is_instance_valid(shop_panel) else {},"normal_first_floor_passed":false}
func _write_json(filename: String, contents: Dictionary) -> void:
 if evidence_dir.is_empty(): return
 var output: Dictionary = contents.duplicate(true)
 output["scope"] = _session_scope()
 output["normal_floor"] = {"status":"SOURCE_CANDIDATE","binding":FileAccess.get_sha256("res://tests/ink_first_floor_user_route_20261005/runtime01/source_binding.json"),"flow":shop_session.snapshot() if shop_session != null else {},"enemies":enemy_layer.report if is_instance_valid(enemy_layer) else {},"q3":mountain_view.get_diagnostics() if is_instance_valid(mountain_view) else {},"preview":aim_preview.sample if is_instance_valid(aim_preview) else {},"dropped_history":dropped_history.duplicate(),"reward":_commerce_evidence(),"full_floor_passed":false,"native_art_performance_passed":false,"q3_gesture_imported":false,"legacy_enemy_metrics_are_empty_anchor":true}
 var file: FileAccess = FileAccess.open(evidence_dir.path_join(filename),FileAccess.WRITE)
 if file != null: file.store_string(JSON.stringify(_json_safe(output),"  ")); file.close()
