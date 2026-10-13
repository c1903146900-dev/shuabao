extends "res://tests/ink_style_specimen_20261004/revision26_safe_clock/parsefix01/host.gd"
## Same current sample presentation/loading/input; new real ledger/UI lifecycle only.
const HealthSim=preload("res://tests/ink_shop_runtime_stats_20261004/hp_undo_fix01/ink_health_sim.gd")
const ShopSession=preload("res://tests/ink_shop_ui_host_20261004/shop_session.gd")
const ShopPanel=preload("res://tests/ink_shop_ui_host_20261004/shop_panel.gd")
const SafeClock7=preload("res://tests/ink_style_specimen_20261004/revision19_actor05/fix07/presentation_clock.gd")
var safe_clock7: RefCounted=SafeClock7.new()
var safe_move_receipt7: Dictionary={}
var shop_session: RefCounted
var shop_panel: Control
var session_diagnostic: bool=false
var session_canvas: CanvasLayer
var session_header: Label
var session_hint: Label
var session_next: Button
var session_learn: Button
var session_equipment: Label
var shown_enemy_id: String=""
var startup_session_error: String=""
var session_input_serial: int=0
func _ready() -> void:
 session_diagnostic="--ink-shop-real-diagnostic" in OS.get_cmdline_user_args()
 # Enough explicit diagnostic wall budget to earn450 from real20g minion kills.
 # The ancestor still applies its original independent hard-wall/process guards.
 active_budget_seconds=360.0
 super._ready()
 _create_session_controls()
 _write_json("shop_session_start.json",{"scope":_session_scope(),"diagnostic_flag":session_diagnostic,"initial_ledger":shop_session.ledger.model.snapshot() if shop_session!=null and shop_session.ledger!=null else {},"initial_hex_skipped_for_normal":false,"diagnostic_Q1_uses_actual_SP":true,"funding":"zero initial gold; actual verified source kills only","normal_entry_ready":false,"final_balance":false})
func _session_scope() -> String:
 return "explicit real-combat shop diagnostic; skips pending initial/milestone Hex only in this named branch; not ordinary Lv1 or authored first floor" if session_diagnostic else "ordinary fresh Lv1/0gold/1SP; actual mandatory initial Hex and formal first-floor content remain HOLD"
func _start_encounter() -> void:
 # The inherited F6 diagnostic reset is intercepted. Fresh construction only.
 if shop_session!=null:
  startup_session_error="fresh_restart_requires_exit_and_new_session"
  return
 sim=HealthSim.new();add_child(sim)
 sim.hero.position=Vector3(0,0,4)
 sim.arena_half_extent=Stage.EXTENT;sim.obstacles=Stage.OBSTACLES.duplicate(true)
 sim.ai_enabled=true;sim.auto_finish=false
 input_router=InputRouter.new();input_router.bind(sim)
 hero_view=HeroView.new();add_child(hero_view)
 enemy_view=MinionView.new();add_child(enemy_view);enemy_view.visible=false
 audio_output.restart_scope()
 shop_session=ShopSession.new()
 var run_id: String="shop-ui-%d"%Time.get_ticks_usec()
 var initialized: Dictionary=shop_session.initialize_session(sim,run_id,session_diagnostic)
 if not initialized.accepted:startup_session_error=str(initialized.reason)
 else:shop_session.bind_input_suspender(input_router.suspend_input)
 sim.combat_event.connect(_combat_event)
 sim.encounter_finished.connect(_session_terminal)
 seen_receipts.clear();q1_view.reset_visuals();audio_output.clear()
 _refresh(0.0)
func _create_session_controls() -> void:
 session_canvas=CanvasLayer.new();session_canvas.layer=100;add_child(session_canvas)
 var overlay=Control.new();overlay.theme=preload("res://tests/ink_style_specimen_20261004/style.gd").ui_theme();overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;session_canvas.add_child(overlay)
 var header_bg=ColorRect.new();header_bg.position=Vector2(14,10);header_bg.size=Vector2(885,60);header_bg.color=Color("23333B");header_bg.mouse_filter=Control.MOUSE_FILTER_IGNORE;overlay.add_child(header_bg)
 session_header=Label.new();session_header.position=Vector2(22,14);session_header.size=Vector2(868,52);session_header.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;overlay.add_child(session_header)
 session_next=Button.new();session_next.position=Vector2(22,84);session_next.size=Vector2(286,34);session_next.pressed.connect(_request_next_room);overlay.add_child(session_next)
 session_learn=Button.new();session_learn.position=Vector2(22,126);session_learn.size=Vector2(286,32);session_learn.text="学习 Q1（消耗1技能点）";session_learn.pressed.connect(_learn_q1);overlay.add_child(session_learn)
 session_hint=Label.new();session_hint.position=Vector2(22,170);session_hint.size=Vector2(300,205);session_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;session_hint.add_theme_font_size_override("font_size",14);overlay.add_child(session_hint)
 var equipment_bg=ColorRect.new();equipment_bg.position=Vector2(938,638);equipment_bg.size=Vector2(153,63);equipment_bg.color=Color("293C42");equipment_bg.mouse_filter=Control.MOUSE_FILTER_STOP;overlay.add_child(equipment_bg)
 session_equipment=Label.new();session_equipment.position=Vector2(945,641);session_equipment.size=Vector2(140,58);session_equipment.add_theme_font_size_override("font_size",13);overlay.add_child(session_equipment)
 shop_panel=ShopPanel.new();session_canvas.add_child(shop_panel);shop_panel.bind_session(shop_session)
 shop_panel.close_requested.connect(func():_shop(false))
 shop_panel.transaction_requested.connect(_submit_shop)
 _refresh_session_controls(true)
func _shop(open: bool) -> void:
 if shop_session==null or _mainprep_required:return
 var result: Dictionary=shop_session.open_panel() if open else shop_session.close_panel()
 if result.accepted:
  audio_output.set_paused(sim.paused)
  hud.shop_open=shop_session.panel_open;hud.shop_group.visible=false;hud.queue_redraw()
 _record_session_action("shop_open" if open else "shop_close",result)
 _refresh_session_controls(true)
func _submit_shop(id: String,action: String,args: Dictionary) -> void:
 var result: Dictionary=shop_session.submit(id,action,args)
 shop_session.update_after_source_step()
 _record_session_action(action,result)
 _refresh_session_controls(true)
func _request_next_room() -> void:
 if shop_session==null or _mainprep_required:return
 var result: Dictionary=shop_session.start_next_room()
 if result.accepted:
  shown_enemy_id="";seen_receipts.clear();q1_view.reset_visuals();audio_output.restart_scope();audio_output.set_paused(sim.paused)
 _record_session_action("next_room",result)
 _refresh_session_controls(true)
func _learn_q1() -> void:
 if shop_session==null or _mainprep_required:return
 var result: Dictionary=shop_session.learn_q1();shop_session.update_after_source_step()
 _record_session_action("learn_Q1",result);_refresh_session_controls(true)
func _record_session_action(action: String,result: Dictionary) -> void:
 session_input_serial+=1
 inputs.append({"category":"real_shop_ui","action":action,"receipt":result.duplicate(true),"serial":session_input_serial,"wall_usec":Time.get_ticks_usec()-start_ticks,"source_time":sim.hero_time,"provenance":"received UI/button/key action; independent OS/CUA evidence still required"})
func _input(event: InputEvent) -> void:
 if _mainprep_required:
  super._input(event);return
 if event is InputEventKey and event.pressed and not event.echo:
  var key: int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
  if key==KEY_B:
   _shop(not shop_session.panel_open);get_viewport().set_input_as_handled();return
  if key==KEY_ESCAPE and shop_session.panel_open:
   _shop(false);get_viewport().set_input_as_handled();return
  if key==KEY_F6:
   shop_session.last_receipt={"accepted":false,"reason":"本宿主禁用F6清账重开；退出后可开全新局"};_refresh_session_controls(true);get_viewport().set_input_as_handled();return
  if shop_session.panel_open and key not in [KEY_F9,KEY_F10,KEY_F8]:
   get_viewport().set_input_as_handled();return
 # Inherited event-coordinate observation and physical LMB-up handling remain.
 super._input(event)
func _unhandled_input(event: InputEvent) -> void:
 if shop_session!=null and shop_session.panel_open:
  get_viewport().set_input_as_handled();return
 super._unhandled_input(event)
func _gui_blocks_pointer_at(point: Vector2) -> bool:
 if is_instance_valid(shop_panel) and shop_panel.visible:return true
 if is_instance_valid(session_canvas):
  for child in session_canvas.get_children():
   if child is Control and _control_stops_at(child,point):return true
 return super._gui_blocks_pointer_at(point)
func _focus_lost() -> void:
 super._focus_lost()
 if shop_session!=null:shop_session.focus_lost()
func _safe_clock_state7() -> Dictionary:
 if sim==null:return {"instance_id":-1,"scope":{},"phase":"","paused":true,"dead":true,"loading":true,"finished":finished,"shop_open":false}
 return {"instance_id":sim.get_instance_id(),"scope":{"room_id":sim.room_id,"generation":sim.encounter_generation},"phase":sim.phase,"paused":sim.paused,"dead":sim.hero.dead,"loading":_mainprep_required,"finished":finished,"shop_open":shop_session!=null and shop_session.panel_open}
func _safe_presentation_context() -> Dictionary:
 var result: Dictionary=safe_clock7.capture(_safe_clock_state7())
 if safe_move_receipt7.get("instance_id",-1)==result.instance_id and safe_move_receipt7.get("scope",{})==result.scope:result["last_actual_safe_move"]=safe_move_receipt7.duplicate(true)
 return result
func _process(delta: float) -> void:
 if not _mainprep_required and not finished and sim!=null and sim.phase in ["preparation","victory"] and not sim.paused:
  var before_context7: Dictionary=_safe_clock_state7()
  var before_position7: Vector3=sim.hero.position
  var before_source7: float=sim.hero_time
  sim.free_move(delta,sim.hero.move_intent) # Existing collision movement, no combat clock/healing tick.
  if safe_clock7.observe_safe_tick(delta,before_context7):
   safe_move_receipt7={"instance_id":before_context7.instance_id,"scope":before_context7.scope.duplicate(true),"phase_at_call":before_context7.phase,"before":before_position7,"after":sim.hero.position,"process_delta":delta,"source_time_before":before_source7,"source_time_after":sim.hero_time,"safe_serial":safe_clock7.safe_serial,"accepted_tick_is_not_displacement":true}
 super._process(delta)
func _combat_event(event: Dictionary) -> void:
 if shop_session!=null and shop_session.ledger!=null:
  var result: Dictionary=shop_session.observe_event(sim,event)
  if event.get("kind","") in ["damage","kill"] and not result.accepted:
   shop_session.last_receipt=result
 super._combat_event(event)
func _session_terminal(actual_snapshot: Dictionary) -> void:
 if shop_session!=null:shop_session.queue_terminal(sim,actual_snapshot)
func _refresh(delta: float) -> void:
 if shop_session!=null:shop_session.update_after_source_step()
 super._refresh(delta)
 # The unified specimen originally binds one minion at index0. This diagnostic
 # rebinds that same unchanged MinionView when the next real sequential actor arrives.
 var visible_enemy: Dictionary={}
 if sim!=null:
  var living: Array=sim.living()
  if not living.is_empty():visible_enemy=living[0]
  elif not sim.enemies.is_empty():visible_enemy=sim.enemies.back()
 if not visible_enemy.is_empty():
  var id: String=str(visible_enemy.actor_id)
  if id!=shown_enemy_id:
   enemy_view.free();enemy_view=MinionView.new();add_child(enemy_view);shown_enemy_id=id
  enemy_view.visible=true
  if not sim.paused:enemy_view.present(visible_enemy,sim.hero_time)
 else:enemy_view.visible=false
 if is_instance_valid(hud) and shop_session!=null:
  hud.shop_open=shop_session.panel_open;hud.shop_group.visible=false
 _refresh_session_controls(false)
func _refresh_session_controls(force: bool) -> void:
 if not is_instance_valid(session_header) or shop_session==null:return
 if shop_session.ledger==null:
  session_header.text="商店接线初始化失败："+startup_session_error
  session_next.disabled=true;session_learn.disabled=true;return
 var ui: Dictionary=shop_session.ui_state()
 var state: Dictionary=ui.state
 session_header.text=("真实商店接线诊断 · 非普通入口" if session_diagnostic else "普通入口接线 · 初始海克斯未就绪")+"\nLv.%d  金币%d  技能点%d  B安全商店 · P未占用 · F10退出"%[state.level,state.gold,state.points]
 session_next.text="开始真实诊断首战（23只逐个进场）" if shop_session.node_index==0 else "进入下一战（提交所有本次交易）"
 session_next.disabled=not ui.next_room.accepted or _mainprep_required
 session_learn.visible=not session_diagnostic and int(state.skills.Q.rank)==0
 session_learn.disabled=state.points<1 or not shop_session.safe_shop_reason().is_empty() or _mainprep_required
 var remaining: String="真实击杀 %d / %d，每只20金币。无送金，需击杀23只才能买450金币基础件。"%[ui.kills,ui.required] if shop_session.status=="combat" and shop_session.node_index==0 else "战后按B买卖/撤回；关闭面板不提交。点击下一战才提交。"
 if not session_diagnostic:remaining="普通入口初始四选一尚未具备真实候选，保持HOLD；不把本诊断两战当正式12行路线。"
 if shop_session.status=="diagnostic_complete":remaining="两战接线段已结束。只证明本次实际记录；非完整第一层或完整英雄。"
 session_hint.text=remaining+"\n\n"+ShopPanel.reason_text(str(ui.next_room.reason))+"\n"+ShopPanel.receipt_text(ui.last_receipt)
 session_equipment.text="装备 %d / 6   金币%d\nAD %.0f  AP %.0f\nB 查看真实装备"%[state.inventory.size(),state.gold,ui.stats.ad,ui.stats.ap]
 if is_instance_valid(shop_panel):shop_panel.refresh(force)
func _write_json(filename: String,contents: Dictionary) -> void:
 var output: Dictionary=contents.duplicate(true)
 if filename in ["session_start.json","session_result.json"]:
  output["scope"]=_session_scope();output["shop_extension"]="tests/ink_shop_ui_host_20261004";output["normal_entry_accepted"]=false
 super._write_json(filename,output)
func save_evidence(reason: String) -> void:
 if shop_session!=null and shop_session.ledger!=null:
  _write_json("shop_session_result.json",{"reason":reason,"scope":_session_scope(),"ledger":shop_session.ledger.model.snapshot(),"session_events":shop_session.session_events,"flow":shop_session.snapshot(),"source_health_dependency_revision":sim.equipment_health_revision,"normal_entry_accepted":false,"UI_native_accepted":false,"full_equipment_accepted":false})
 super.save_evidence(reason)
func close_sample(reason: String) -> void:
 if shop_session!=null and not finished:shop_session.close_run()
 super.close_sample(reason)
