extends Node3D
## Independent Fengli route host draft. Never starts the old arena reward path.
const FlowGuidance = preload("res://fengli_route_20261024/flow_guidance.gd")
const StartupGate = preload("res://fengli_route_20261024/startup_gate.gd")
const STARTUP_ROOTS = {"hero_id":"fengli","scene":"res://fengli_route_20261024/room.tscn","host":"res://fengli_route_20261024/host.gd","sim":"res://fengli_route_20261024/sim.gd","session":"res://fengli_route_20261024/session.gd","router":"res://fengli_route_20261024/input_router.gd","presentation":"res://fengli_route_20261024/presentation.gd","catalog":"res://fengli_route_20261024/catalog.gd","binding":"res://fengli_route_20261024/binding.gd"}
const Sim = preload("res://fengli_route_20261024/sim.gd")
const Session = preload("res://fengli_route_20261024/session.gd")
const Router = preload("res://fengli_route_20261024/input_router.gd")
const AudioOutput = preload("res://fengli_route_20261024/audio_output.gd")
const OverloadProjection = preload("res://fengli_route_20261024/overload_projection.gd")
const GrowthHUD = preload("res://fengli_route_20261024/growth_hud.gd")
const Controller = preload("res://tests/ink_q3_input_growth_20261004/controller.gd")
const RouteMap = preload("res://route_map_visual_refresh_20261026/route_map.gd")
const ShopPanel = preload("res://fengli_route_20261024/shop_theme.gd")
const RoomLayout = preload("res://tests/ink_first_floor_room_art_20261004/room_layout.gd")
const PotionControls = preload("res://fengli_route_20261024/potion_controls.gd")
const Presentation = preload("res://fengli_route_20261024/presentation.gd")
const TerminalProjection = preload("res://yan_trial_ui_20261018/result_summary.gd")
const FRONTDOOR_EXTRA_KEYS = [KEY_M,KEY_F10]
const REWARD_ROOT = "res://__clean_fengli/machine_templates.bin"
var sim: Node
var shop_session: RefCounted
var input_router: RefCounted
var initial_hud: Control
var initial_controller: RefCounted
var route_map: Control
var shop_panel: Control
var camera: Camera3D
var camera_target:Vector3=Vector3.ZERO
var map_done: Button
var service_continue: Button
var objective_label: Label
var status_label: Label
var startup_session_error: String = ""
var floor_error: String = ""
var events: Array = []
var inputs: Array = []
var hitstop_left: float = 0.0
var last_hitstop_cast: int = -1
var finished: bool = false
var manual_paused: bool = false
var _presentation_ready: bool = false
var _run_id: String = ""
var _frontdoor_suspended: bool = false
var route_audio: Node
var presentation: Node2D
var terminal_panel: PanelContainer
var terminal_label: Label
var ordinary_potion_controls:Control
var terminal_projection: Dictionary = {}
func _ready()->void:
 var admission:Dictionary=StartupGate.verify(STARTUP_ROOTS)
 if not admission.accepted:
  startup_session_error=str(admission.reason);set_process(false);return
 _run_id="fengli-route-%d"%Time.get_ticks_usec()
 camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=18.0
 add_child(camera);camera.current=true
 sim=Sim.new();add_child(sim)
 sim.hero.position=Session.ROOM_ENTRY_POSITION
 _follow_camera(sim.hero.position,1.0)
 RoomLayout.bind_to_sim(sim)
 sim.ai_enabled=true;sim.auto_finish=false
 input_router=Router.new();input_router.bind(sim)
 shop_session=Session.new()
 var loaded:Dictionary=Session.MixedSchema.load_definition(Session.DEFAULT_DEFINITION,true)
 var initialized:Dictionary=shop_session.configure_reward_table(REWARD_ROOT,REWARD_ROOT,REWARD_ROOT,true)
 if initialized.accepted and loaded.accepted:initialized=shop_session.initialize_floor(sim,loaded.definition,_run_id,true)
 elif not loaded.accepted:initialized=loaded
 if not initialized.accepted:
  startup_session_error=str(initialized.reason);set_process(false);return
 shop_session.bind_input_suspender(input_router.suspend_input)
 route_audio=AudioOutput.new();add_child(route_audio)
 route_audio.bind_source(sim)
 sim.combat_event.connect(_combat_event)
 sim.encounter_finished.connect(func(actual:Dictionary):shop_session.queue_terminal(sim,actual))
 _build_ui()
 var view_layer:=CanvasLayer.new();view_layer.layer=10;add_child(view_layer)
 presentation=Presentation.new();view_layer.add_child(presentation)
 presentation.presentation_fault.connect(func(reason:String):
  if floor_error.is_empty():floor_error="presentation:"+reason
  input_router.suspend_input("presentation_fault");_sync_pause())
 var view_bound:Dictionary=presentation.bind(self)
 _presentation_ready=bool(view_bound.get("accepted",false))
 if not _presentation_ready:floor_error=str(view_bound.get("reason","presentation_binding_failed"))
 sim.paused=true
 _refresh()
func _build_ui()->void:
 var layer:=CanvasLayer.new();layer.layer=100;add_child(layer)
 var controls:=Control.new();controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);controls.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(controls)
 route_map=RouteMap.new();route_map.neon_palette_enabled=true;controls.add_child(route_map);route_map.position=Vector2(24,130);route_map.size=Vector2(650,480)
 route_map.bind_route(shop_session.route);route_map.bind_reward_preview(shop_session.preview_node_rewards)
 route_map.node_chosen.connect(_select_row)
 map_done=Button.new();map_done.text="返回房间";map_done.position=Vector2(700,85);controls.add_child(map_done)
 map_done.pressed.connect(func():shop_session.close_exit_map();_refresh())
 var shop:=Button.new();shop.text="商店 · P";shop.position=Vector2(24,22);controls.add_child(shop)
 shop.pressed.connect(func():_shop(not shop_session.panel_open))
 service_continue=Button.new();service_continue.text="继续前进 · Enter";service_continue.position=Vector2(500,120);controls.add_child(service_continue)
 service_continue.pressed.connect(func():_transition("complete_service",shop_session.complete_service()))
 status_label=Label.new();status_label.position=Vector2(24,64);controls.add_child(status_label)
 objective_label=Label.new();objective_label.position=Vector2(24,92);objective_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;objective_label.add_theme_color_override("font_color",Color("8ce9df"));controls.add_child(objective_label)
 terminal_panel=PanelContainer.new();terminal_panel.position=Vector2(360,18);terminal_panel.custom_minimum_size=Vector2(640,100);terminal_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;controls.add_child(terminal_panel);terminal_panel.hide()
 var terminal_style:=StyleBoxFlat.new();terminal_style.bg_color=Color("141a30");terminal_style.border_color=Color("42e4d1");terminal_style.set_border_width_all(1)
 terminal_style.content_margin_left=16;terminal_style.content_margin_right=16;terminal_style.content_margin_top=12;terminal_style.content_margin_bottom=12
 terminal_panel.add_theme_stylebox_override("panel",terminal_style)
 terminal_label=Label.new();terminal_label.add_theme_font_size_override("font_size",24);terminal_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;terminal_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;terminal_panel.add_child(terminal_label);terminal_label.hide()
 shop_panel=ShopPanel.new();layer.add_child(shop_panel);shop_panel.bind_session(shop_session)
 shop_panel.close_requested.connect(func():_shop(false))
 shop_panel.transaction_requested.connect(func(id:String,action:String,args:Dictionary):_transition(action,shop_session.submit(id,action,args)))
 var growth_layer:=CanvasLayer.new();growth_layer.layer=110;add_child(growth_layer)
 initial_hud=GrowthHUD.new();growth_layer.add_child(initial_hud)
 initial_controller=Controller.new()
 initial_controller.gameplay_block_changed.connect(_modal_changed)
 initial_controller.bind_session(shop_session,initial_hud)
 initial_controller.command_completed.connect(func(_request:Dictionary,_result:Dictionary):_refresh())
 ordinary_potion_controls=PotionControls.new();growth_layer.add_child(ordinary_potion_controls);ordinary_potion_controls.bind_session(shop_session);ordinary_potion_controls.route_host=self
 initial_hud.training_requested.connect(func():_transition("training_respec",shop_session.reset_training()))
func _modal_changed(blocked:bool)->void:
 input_router.suspend_input("modal_changed")
 var result:Dictionary=shop_session.set_modal_blocked(blocked)
 if not result.accepted:floor_error=str(result.reason)
 _sync_pause()
func _sync_pause()->void:
 if sim==null:return
 sim.paused=_frontdoor_suspended or manual_paused or not _presentation_ready or not floor_error.is_empty() or shop_session.panel_open or shop_session.initial_modal_open
 if route_audio!=null:route_audio.sync_lifecycle(sim.paused,finished)
func _shop(open:bool)->void:
 input_router.suspend_input("shop")
 _transition("shop_open" if open else "shop_close",shop_session.open_panel() if open else shop_session.close_panel())
 _sync_pause()
func _transition(_action:String,_result:Dictionary)->void:
 shop_session.update_after_source_step()
 initial_controller.refresh()
 _refresh()
func _select_row(row:int,node_id:String)->void:
 var selected:Dictionary=shop_session.select_node(row,node_id)
 if not selected.accepted:_transition("select_node",selected);return
 var entered:Dictionary=shop_session.enter_selected_node()
 if entered.accepted:input_router.suspend_input("room_entered");hitstop_left=0.0;last_hitstop_cast=-1;_follow_camera(sim.hero.position,1.0)
 _transition("enter_selected_node",entered)
func _process(dt:float)->void:
 if finished or sim==null or shop_session==null or shop_session.ledger==null:return
 initial_controller.ensure_auto_hex()
 _sync_pause()
 if presentation!=null and not presentation.visual_errors.is_empty():
  if floor_error.is_empty():floor_error="presentation:"+str(presentation.visual_errors[0])
  input_router.suspend_input("presentation_fault");_sync_pause()
 if not sim.paused:
  var stopping:bool=hitstop_left>0.0
  hitstop_left=maxf(0.0,hitstop_left-dt)
  if sim.phase=="combat":
   if stopping:sim.move_during_hitstop(dt,input_router.movement())
   else:
    input_router.update_held_basic(_basic_aim(),_pointer_over_ui())
    sim.step(dt)
  elif sim.phase in ["preparation","victory"]:sim.free_move(dt,input_router.movement())
 _follow_camera(sim.hero.position,dt)
 shop_session.update_after_source_step()
 shop_session.update_room_exit()
 _refresh()
func _follow_camera(target:Vector3,dt:float)->void:
 # Same actual follow projection as the existing route stage; no simulation position writes.
 camera_target=camera_target.lerp(Vector3(clampf(target.x,-8,8),0,clampf(target.z,-7,7)),minf(1,dt*6))
 camera.position=camera_target+Vector3(0,24.0*tan(deg_to_rad(40.0)),24.0)
 camera.look_at(camera_target)
func _combat_event(event:Dictionary)->void:
 if route_audio!=null:route_audio.consume(event)
 # Exactly one route observer. No arena _credit_kill or second wallet.
 var observed:Dictionary=shop_session.observe_event(sim,event)
 if str(event.get("kind","")) in ["damage","kill"] and not observed.accepted:shop_session.last_receipt=observed
 events.append(event.duplicate(true))
 if events.size()>512:events.pop_front()
 if str(event.get("kind",""))=="damage" and (float(event.get("amount",0))>0.0 or float(event.get("absorbed",0))>0.0):
  if str(event.get("target",""))=="fengli" and float(event.get("amount",0))>0.0:hitstop_left=maxf(hitstop_left,0.025)
  elif str(event.get("source","")) in ["attack","dash_attack","q1","e1_pierce"] and int(event.get("cast_id",-1))!=last_hitstop_cast:
   last_hitstop_cast=int(event.get("cast_id",-1))
   hitstop_left=maxf(hitstop_left,0.025) # Original Wind presentation hitstop, not Xuanlei combo tuning.
func _refresh()->void:
 if initial_controller==null:return
 var overload:Dictionary=OverloadProjection.read(sim)
 var combat_stats:Dictionary=sim.hero.stats.duplicate(true)
 if overload.has("effective"):combat_stats.merge(overload.effective,true)
 initial_controller.present_combat({"hp":sim.hero.hp,"hp_max":sim.hero.stats.max_hp,"stats":combat_stats,"phase":sim.phase,"room_id":sim.room_id})
 initial_hud.present_source_vitals(sim.hero.hp,sim.hero.stats.max_hp,sim.hero.cooldowns)
 # Read existing core state without snapshot(): that method synchronizes charges.
 # The HUD neither starts recovery nor advances a second clock.
 var q3_projection:Dictionary={}
 if sim.hero.loadout.q=="q3" and int(sim.hero.ranks.q)>0:
  var recoveries:Array=sim._q3_recoveries.duplicate()
  q3_projection={"available":sim._q3_available(),"capacity":sim._q3_capacity(),"recoveries":recoveries,"next_recovery":float(recoveries.min()) if not recoveries.is_empty() else 0.0}
 initial_hud.present_q3_charges(q3_projection)
 initial_hud.present_overload(overload)
 initial_hud.present_r2(preload("res://fengli_route_20261024/r2_projection.gd").read(sim))
 initial_hud.present_e2(preload("res://fengli_route_20261024/e2_projection.gd").read(sim))
 var map_visible:bool=shop_session.exit_map_open and not shop_session.panel_open and not shop_session.initial_modal_open
 # Hidden map has no presentation work; each visible frame still uses the full source projection.
 route_map.visible=map_visible
 if map_visible:route_map.present(shop_session.available_choices(),shop_session.row_state.snapshot(),shop_session.panel_open or shop_session.initial_modal_open)
 map_done.visible=route_map.visible
 service_continue.visible=shop_session.status=="service" and not shop_session._service_ready and not map_visible and not shop_session.panel_open and not shop_session.initial_modal_open
 service_continue.disabled=shop_session._service_ready or sim.paused
 # Preserve the original complete refresh while open and once when closing.
 # Direct force/rebind/category paths in ShopPanel are unchanged.
 if shop_session.panel_open or shop_panel.visible:shop_panel.refresh(false)
 else:shop_panel.hide()
 initial_hud.bottom_bar.visible=not route_map.visible and not shop_session.panel_open
 if route_map.visible or shop_session.panel_open or shop_session.initial_modal_open:
  initial_hud.bottom_open_slot=""
  initial_hud.bottom_popup.hide()
 var status_text:String={"preparation":"准备出发","combat":"清除敌人","between_rooms":"房间已清理 · 前往上方出口","service":"休整服务","completed":"首层完成","defeated":"本局结束","aborted":"本局已结束"}.get(str(shop_session.status),"等待房间状态")
 status_label.text="风厉 · 第1层 · 已完成 %d / 12 · "%shop_session.node_index+status_text
 objective_label.text=FlowGuidance.text_for({"status":shop_session.status,"paused":manual_paused,"map":route_map.visible,"training":shop_session._entered_service("training"),"enemies":sim.living().size(),"fault":floor_error,"points":shop_session.ledger.model.state.points,"unlearned":int(sim.hero.ranks.q)==0 and int(sim.hero.ranks.e)==0})
 terminal_projection=TerminalProjection.project(shop_session.snapshot(),shop_session.ledger.model.state,shop_session.ledger.model.receipts)
 terminal_label.visible=shop_session.status in ["completed","defeated"] and bool(terminal_projection.get("ready",false)) and not shop_session.initial_modal_open
 terminal_panel.visible=terminal_label.visible
 if terminal_label.visible:terminal_label.text=("本局结束" if shop_session.status=="defeated" else "首层完成")+"\nLv.%d · 金币 %d · 已完成 %d 行"%[terminal_projection.level,terminal_projection.gold_balance,terminal_projection.completed_nodes]
 if not _presentation_ready:status_label.text+=" · 新展示尚未绑定，游戏保持暂停"
func _basic_aim()->Vector3:
 # Wind body-plane calibration awaits its own art; preserve source ground aim.
 return _ground()
func _ground()->Vector3:
 var point:Vector2=get_viewport().get_mouse_position()
 var hit:Variant=Plane(Vector3.UP,0.0).intersects_ray(camera.project_ray_origin(point),camera.project_ray_normal(point))
 return hit if hit is Vector3 else Vector3.INF
func _pointer_over_ui()->bool:
 return get_viewport().gui_get_hovered_control()!=null
func _blocked()->bool:
 return finished or sim==null or sim.paused or shop_session.exit_map_open or shop_session.panel_open or shop_session.initial_modal_open or not _presentation_ready
func _input(event:InputEvent)->void:
 if input_router==null:return
 # Releases and blocked physical downs are observed before GUI consumption.
 if (event is InputEventMouseButton and not event.pressed) or (event is InputEventKey and not event.pressed):
  input_router.handle_event(event,Vector3.INF,_blocked());return
 if _blocked() or (event is InputEventMouseButton and event.pressed and _pointer_over_ui()):input_router.handle_event(event,Vector3.INF,true)
 if event is InputEventKey and event.pressed and not event.echo:
  var key:int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
  if key==KEY_F10:
   if frontdoor_close_run("F10"):get_tree().quit()
   get_viewport().set_input_as_handled()
  elif key==KEY_P:_shop(not shop_session.panel_open);get_viewport().set_input_as_handled()
  elif key==KEY_M and shop_session.exit_map_open:shop_session.close_exit_map();_refresh();get_viewport().set_input_as_handled()
  elif key in [KEY_ENTER,KEY_KP_ENTER] and service_continue.visible and not service_continue.disabled:
   _transition("complete_service",shop_session.complete_service());get_viewport().set_input_as_handled()
  elif key==KEY_ESCAPE:
   if shop_session.panel_open:_shop(false)
   elif shop_session.exit_map_open:shop_session.close_exit_map();_refresh()
   elif not shop_session.initial_modal_open:
    manual_paused=not manual_paused;input_router.suspend_input("pause");_sync_pause()
   get_viewport().set_input_as_handled()
  elif key==KEY_SPACE:
   manual_paused=not manual_paused;input_router.suspend_input("pause");_sync_pause();get_viewport().set_input_as_handled()
func _unhandled_input(event:InputEvent)->void:
 if _blocked():return
 if (event is InputEventMouseButton and not event.pressed) or (event is InputEventKey and not event.pressed):return
 var aim_point:Vector3=_ground()
 # A fresh dash click remains source dash_direction, not mouse-redirection.
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and sim.hero.dash_left<=0.0:aim_point=_basic_aim()
 var result:Dictionary=input_router.handle_event(event,aim_point,event is InputEventMouse and _pointer_over_ui())
 if result.get("reason","")!="unmapped_input":
  inputs.append({"event":event.as_text(),"result":result.duplicate(true),"room_id":sim.room_id,"generation":sim.encounter_generation,"world_time":sim.clock.world_time,"real_time":sim.real_time})
  if inputs.size()>512:inputs.pop_front()
func _notification(what:int)->void:
 if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT and input_router!=null:input_router.focus_lost()

func frontdoor_can_suspend()->bool:
 return sim!=null and shop_session!=null and not sim.transaction_active and not shop_session._transitioning
func frontdoor_clear_input()->void:
 if input_router!=null:input_router.suspend_input("frontdoor")
func frontdoor_suspend()->void:
 frontdoor_clear_input();_frontdoor_suspended=true;_sync_pause()
func frontdoor_resume()->void:
 frontdoor_clear_input();_frontdoor_suspended=false;_sync_pause()
func frontdoor_stop_audio()->void:
 if route_audio!=null:route_audio.stop_all()
func frontdoor_close_run(reason:String)->bool:
 if finished:return true
 if not frontdoor_can_suspend():return false
 frontdoor_clear_input()
 var result:Dictionary=shop_session.close_run()
 if not result.get("accepted",false):return false
 sim.retire_route_potions()
 shop_session.update_after_source_step();finished=true
 if route_audio!=null:route_audio.sync_lifecycle(true,true)
 var directory:String="user://fengli_route/"+_run_id
 DirAccess.make_dir_recursive_absolute(directory)
 var file:=FileAccess.open(directory+"/session_result.json",FileAccess.WRITE)
 if file!=null:file.store_string(JSON.stringify({"reason":reason,"flow":shop_session.snapshot(),"ledger":shop_session.ledger.model.snapshot(),"receipts":shop_session.ledger.model.receipts,"events":events,"inputs":inputs,"presentation":presentation.receipt if presentation!=null else {}},"  "))
 return true

func frontdoor_shop_modal_open()->bool:
 return shop_session!=null and shop_session.panel_open
