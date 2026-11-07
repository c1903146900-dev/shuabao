extends SceneTree
# VERSION 04: all-item source-flow observer, optional focused stop; PREPARED ONLY; freezes 01 unchanged. No engine run or check-only parse. Existing guards remain mandatory.
# UI Button signals are source UI actions, not native mouse/visual acceptance.
const EXPECTED_STATIC={"elixir:01":{"AD":35.0,"lifesteal":0.08},"elixir:02":{"AP":60.0,"cooldown_reduction":0.10},"elixir:03":{"defense":20.0,"tenacity":0.25},"elixir:04":{"penetration":20.0,"crit_chance":0.15},"elixir:05":{"attack_speed":0.15,"cooldown_reduction":0.08}}
const ROUTE_TIMEOUT:float=450.0
const MAX_TREATMENT_PURCHASES:int=3
const MAX_STOCK:int=2
const HEAL_THRESHOLD:float=0.70
const SETTLE:float=0.65
const CAPTURE_LIMIT:int=24
const ROUTE:Array[String]=["r01b","r02d","r03a","r04a","r05a","r06a","r07a","r08a","r09a","r10a","r11a","r12boss"]
var target_id:String=""
var stop_after_effect:bool=false
var output_dir:String=""
var output_file:FileAccess
var entry:Node
var host:Node
var elapsed:float=0.0
var wall_started:int=0
var tick:float=0.0
var step:String="boot"
var step_at:float=0.0
var started:bool=false
var stopping:bool=false
var treatment_purchased:int=0
var treatment_used:int=0
var uses:Array=[]
var purchases:Array=[]
var selected_route:Array=[]
var captures:int=0
var capture_pending:bool=false
var last_capture:float=-10.0
var last_progress:float=0.0
var buying_id:String=""
var bought:bool=false
var drunk:bool=false
var battle_seen:bool=false
var cleared:bool=false
var elixir_battle:String=""
var before_stats:Dictionary={}
var active_stats:Dictionary={}
var drink_uid:int=-1
var budget_record:String=""
var step_wall:int=0
var watchdog_context:String=""
var watchdog_since:int=0
var watchdog_progress:String=""
var watchdog_progress_at:int=0
var rearm_walking:bool=false

func _json_value(value:Variant)->Variant:
 if value is Resource:return {"resource_path":value.resource_path}
 if value is Object:return {"omitted_object_class":value.get_class()}
 if value is Vector2 or value is Vector2i:return [value.x,value.y]
 if value is Vector3 or value is Vector3i:return [value.x,value.y,value.z]
 if value is Rect2 or value is Rect2i:return [value.position.x,value.position.y,value.size.x,value.size.y]
 if value is Transform2D:return {"x":_json_value(value.x),"y":_json_value(value.y),"origin":_json_value(value.origin)}
 if value is Array or value is PackedVector2Array:
  var result:Array=[]
  for item:Variant in value:result.append(_json_value(item))
  return result
 if value is Dictionary:
  var result:Dictionary={}
  for key:Variant in value:result[str(key)]=_json_value(value[key])
  return result
 return value

func _record(kind:String,data:Dictionary)->void:
 var line:String=JSON.stringify(_json_value(data.merged({"record":kind,"elapsed":elapsed},true)))
 if output_file!=null:output_file.store_line(line);output_file.flush()
 print("ELIXIR_FLOW_",kind.to_upper()," ",line)

func _initialize()->void:
 wall_started=Time.get_ticks_msec()
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--observer-output="):output_dir=arg.trim_prefix("--observer-output=").simplify_path()
  elif arg.begins_with("--elixir-id="):target_id=arg.trim_prefix("--elixir-id=")
  elif arg=="--stop-after-effect":stop_after_effect=true
 if target_id not in ["elixir:01","elixir:02","elixir:03","elixir:04","elixir:05"]:_end("explicit_supported_elixir_id_required",9);return
 if not output_dir.is_absolute_path() or not "/private_captures/" in output_dir or "://" in output_dir:_end("absolute_private_captures_output_required",9);return
 if FileAccess.file_exists(output_dir.path_join("observations.jsonl")):_end("fresh_output_required",9);return
 if DirAccess.make_dir_recursive_absolute(output_dir)!=OK:_end("output_directory_unwritable",9);return
 output_file=FileAccess.open(output_dir.path_join("observations.jsonl"),FileAccess.WRITE)
 if output_file==null:_end("output_file_unwritable",9);return
 _record("configuration",{"target":target_id,"route":ROUTE,"wall_timeout":450,"treatment_cap":3,"state_injection":false,"native_acceptance":false,"prepared_unparsed":true})
 root.add_child(load("res://boot.tscn").instantiate())

func _bounds(points:Array)->Rect2:
 if points.is_empty():return Rect2()
 var rect:=Rect2(points[0],Vector2.ZERO)
 for point:Vector2 in points:rect=rect.expand(point)
 return rect

func _corners(rect:Rect2,transform:Transform2D)->Array:
 return [transform*rect.position,transform*Vector2(rect.end.x,rect.position.y),transform*rect.end,transform*Vector2(rect.position.x,rect.end.y)]

func _view_rect(control:Control)->Rect2:
 return _bounds(_corners(Rect2(Vector2.ZERO,control.size),control.get_global_transform_with_canvas()))

func _effective_rect(control:Control)->Rect2:
 var rect:Rect2=_view_rect(control).intersection(root.get_visible_rect())
 var ancestor:Node=control.get_parent()
 while ancestor!=null:
  if ancestor is Control and ancestor.clip_contents:rect=rect.intersection(_view_rect(ancestor))
  ancestor=ancestor.get_parent()
 return rect

func _control(control:Control)->Dictionary:
 var result:Dictionary={"name":str(control.name),"path":str(control.get_path()),"class":control.get_class(),"visible":control.is_visible_in_tree(),"local_visible":control.visible,"top_level":control.is_set_as_top_level(),"global_rect":control.get_global_rect(),"viewport_rect":_view_rect(control),"screen_rect":_bounds(_corners(Rect2(Vector2.ZERO,control.size),control.get_screen_transform())),"clipped_viewport_rect":_effective_rect(control),"minimum_size":control.get_combined_minimum_size(),"mouse_filter":control.mouse_filter,"clip_contents":control.clip_contents}
 if control is Button:
  var bindings:Array=[]
  for connection:Dictionary in control.pressed.get_connections():
   var callback:Callable=connection.callable
   bindings.append({"method":str(callback.get_method()),"arguments":callback.get_bound_arguments()})
  result.merge({"text":control.text,"disabled":control.disabled,"pressed_bindings":bindings,"flask_uid_meta":control.get_meta("flask_uid",-1)})
 return result

func _snapshot()->Dictionary:
 var model:RefCounted=host.shop_session.ledger.model
 return {"room":host.shop_session.active_node_room,"status":host.shop_session.status,"phase":host.sim.phase,"hp":host.sim.hero.hp,"stats":host.sim.hero.stats.duplicate(true),"actor_snapshot":host.sim.hero.snapshot(),"actual_attack_speed":host.sim.hero.attack_speed(),"actual_move_speed":host.sim.hero.speed(),"elixir_consumer":model.elixir_consumer.snapshot(),"elixir_static_stats":model.elixir_consumer.static_stats(),"actor_combat_time":host.sim.hero_time,"dash_serial":host.sim.dash_serial,"dash_left":host.sim.hero.dash_left,"gold":model.state.gold,"inventory":model.state.inventory.duplicate(true),"shop_visit":model.state.shop_visit.duplicate(true),"receipt":host.shop_session.last_receipt.duplicate(true),"recovery":model.potion_consumer.snapshot()}

func _capture(label:String)->void:
 if stopping or capture_pending or captures>=CAPTURE_LIMIT:return
 capture_pending=true
 await RenderingServer.frame_post_draw
 if stopping or not is_instance_valid(host):capture_pending=false;return
 var image:Image=root.get_texture().get_image()
 if image==null or image.is_empty():capture_pending=false;_end("empty_draw",9);return
 var dock_buttons:Array=[]
 for child:Node in host.ordinary_potion_controls.get_children():
  if child is Button:dock_buttons.append(_control(child))
 var filename:String="%02d_%s.png"%[captures,label]
 if image.save_png(output_dir.path_join(filename))!=OK:capture_pending=false;_end("capture_write_failed",9);return
 _record("draw",_snapshot().merged({"label":label,"image":filename,"completed_draw":true,"draw_frame":Engine.get_frames_drawn(),"viewport":root.get_visible_rect(),"panel":_control(host.shop_panel),"ordinary_dock":_control(host.ordinary_potion_controls),"ordinary_buttons":dock_buttons,"hud_bottom_bar":_control(host.initial_hud.bottom_bar),"hud_popup":_control(host.initial_hud.bottom_popup)}))
 captures+=1;last_capture=elapsed;capture_pending=false

func _press_visible(button:Button,label:String)->bool:
 if not is_instance_valid(button) or not button.is_visible_in_tree() or button.disabled or _effective_rect(button).get_area()<=0.0:
  _end("button_not_visible_enabled:"+label,9);return false
 _record("button_action",{"label":label,"source":"existing_Button.pressed_signal_not_OS_click","button":_control(button)})
 button.pressed.emit();return true

func _key(k:int,on:bool,aim:Vector3=Vector3.INF)->void:
 var event:=InputEventKey.new();event.physical_keycode=k;event.keycode=k;event.pressed=on
 host.input_router.handle_event(event,aim,host._blocked())

func _press(k:int,aim:Vector3)->void:_key(k,true,aim);_key(k,false,aim)

func _host_key(k:int)->void:
 var event:=InputEventKey.new();event.physical_keycode=k;event.keycode=k;event.pressed=true
 host._input(event);event.pressed=false;host._input(event)

func _release()->void:
 for k:int in [KEY_W,KEY_A,KEY_S,KEY_D]:_key(k,false)
 var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=false
 host.input_router.handle_event(event)

func _walk(target:Vector3,stop:float=0.15)->void:
 var position:Vector3=host.sim.hero.position
 if position.distance_to(target)<stop:
  for k:int in [KEY_W,KEY_A,KEY_S,KEY_D]:_key(k,false)
  return
 var best:=Vector3.ZERO;var score:float=-INF
 for direction:Vector3 in [Vector3(0,0,-1),Vector3(1,0,-1).normalized(),Vector3(1,0,0),Vector3(1,0,1).normalized(),Vector3(0,0,1),Vector3(-1,0,1).normalized(),Vector3(-1,0,0),Vector3(-1,0,-1).normalized()]:
  var at:Vector3=host.sim._move_clipped(position,position+direction*0.7,host.sim.hero_radius)
  var value:float=position.distance_to(target)-at.distance_to(target)
  if at.distance_to(position)<0.05:value-=10.0
  if value>score:score=value;best=direction
 _key(KEY_W,best.z<-.2,target);_key(KEY_S,best.z>.2,target);_key(KEY_A,best.x<-.2,target);_key(KEY_D,best.x>.2,target)

func _learn()->void:
 # Same source learning request as the existing ordinary full-floor observer.
 var state:Dictionary=host.shop_session.ledger.model.state
 if int(state.points)<=0:return
 var choices:Array=[]
 if int(state.level)>=7 and int(state.skills.R.rank)==0:choices.append(["R","R1"])
 if int(state.skills.E.rank)==0:choices.append(["E","E1"])
 if int(state.skills.Q.rank)==0:choices.append(["Q","Q3"])
 if int(state.skills.P.rank)==0:choices.append(["P","P2"])
 choices.append_array([["E","E1"],["Q","Q3"],["P","P2"]])
 for choice:Array in choices:
  var rank:int=state.skills[choice[0]].rank
  host.initial_hud.adapter.request("learn",{"slot_id":choice[0],"candidate_id":choice[1],"expected_rank":rank})
  if int(host.shop_session.ledger.model.state.skills[choice[0]].rank)>rank:break

func _combat()->void:
 var sim:Node=host.sim
 var live:Array=sim.living()
 if live.is_empty():_release();return
 var target:Dictionary=live[0]
 for enemy:Dictionary in live:
  if sim.hero.position.distance_to(enemy.position)<sim.hero.position.distance_to(target.position):target=enemy
 var aim:Vector3=target.position
 var distance:float=sim.hero.position.distance_to(aim)
 var evade:bool=false
 for threat:Dictionary in live:
  if str(threat.state)=="warning" and float(threat.warning_progress)>.20 and sim.hero.position.distance_to(threat.position)<float(threat.attack_range)+2.0:
   var side:=Vector3(-float(threat.aim.z),0,float(threat.aim.x))
   var a:Vector3=sim._move_clipped(sim.hero.position,sim.hero.position+side*2.2,sim.hero_radius)
   var b:Vector3=sim._move_clipped(sim.hero.position,sim.hero.position-side*2.2,sim.hero_radius)
   _walk(a if a.distance_to(sim.hero.position)>=b.distance_to(sim.hero.position) else b)
   if float(threat.timer)<.25 and float(sim.hero.cooldowns.shift)<=0:_press(KEY_SHIFT,aim)
   evade=true;break
 if not evade:_walk(aim,1.45)
 _try_treatment()
 if stopping:return
 if distance<7 and float(sim.hero.cooldowns.e)<=0 and not sim.hero.cast_state.has("e2_shadow"):_press(KEY_E,aim)
 if distance<9 and float(sim.hero.cooldowns.q)<=0:_press(KEY_Q,aim)
 if distance<7 and float(sim.hero.cooldowns.r)<=0:_press(KEY_R,aim)
 var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
 if distance<2.4:host.input_router.handle_event(event,aim,false)
 event.pressed=false;host.input_router.handle_event(event,aim,false)

func _next(next:String)->void:step=next;step_at=elapsed;step_wall=Time.get_ticks_msec()

func _held(id:String)->Dictionary:
 for item:Dictionary in host.shop_session.ledger.model.state.inventory:
  if str(item.id)==id:return item.duplicate(true)
 return {}

func _count(id:String)->int:
 return int(_held(id).get("count",0))

func _ordinary_entries()->Array:
 var entries:Array=[]
 for item:Dictionary in host.shop_session.ledger.model.state.inventory:
  if str(item.id) in ["potion:1","potion:2","potion:3"]:entries.append(item.duplicate(true))
 return entries

func _source_button(uid:int)->Button:
 for child:Node in host.ordinary_potion_controls.get_children():
  if not child is Button:continue
  for connection:Dictionary in child.pressed.get_connections():
   var callback:Callable=connection.callable
   var args:Array=callback.get_bound_arguments()
   if str(callback.get_method())=="_use" and args.size()==1 and int(args[0])==uid:return child
 return null

func _try_treatment()->void:
 if treatment_used>=MAX_TREATMENT_PURCHASES:return
 var sim:Node=host.sim
 var session:RefCounted=host.shop_session
 var model:RefCounted=session.ledger.model
 if sim.phase!="combat" or sim.paused or sim.transaction_active or sim.hero.dead:return
 if float(sim.hero.hp)>float(sim.hero.stats.max_hp)*HEAL_THRESHOLD:return
 # Read the original consumer's actual outstanding effects, not wall-clock time.
 # Four actor-combat seconds may span pauses/slowdowns. Never overlap doses.
 var recovery:Dictionary=model.potion_consumer.snapshot()
 if not recovery.active.is_empty():return
 var entry:Dictionary=_held("potion:1")
 if entry.is_empty():return
 var button:Button=_source_button(int(entry.uid))
 if not is_instance_valid(button) or not button.is_visible_in_tree() or button.disabled:return
 var gold_before:int=int(model.state.gold)
 var hp_before:float=float(sim.hero.hp)
 var committed_before:int=int(recovery.committed_effect_count)
 if not _press_visible(button,"real_treatment_potion_I"):return
 var receipt:Dictionary=session.last_receipt.duplicate(true)
 var after_recovery:Dictionary=model.potion_consumer.snapshot()
 var committed:bool=false
 for event:Dictionary in receipt.get("events",[]):
  if str(event.get("type",""))=="recovery_committed" and str(event.get("item",""))=="potion:1":committed=true
 if not receipt.get("accepted",false) or not committed or _count("potion:1")!=int(entry.count)-1 or int(model.state.gold)!=gold_before or int(after_recovery.committed_effect_count)!=committed_before+1:
  _end("source_treatment_receipt_mismatch",9);return
 treatment_used+=1
 var record:Dictionary={"uid":entry.uid,"count_before":entry.count,"count_after":_count("potion:1"),"hp_at_commit":hp_before,"max_hp":sim.hero.stats.max_hp,"room":session.active_node_room,"used":treatment_used,"receipt":receipt,"recovery_after":after_recovery,"actual_healing_not_claimed_at_commit":true}
 uses.append(record);_record("treatment",record)

func _active()->Dictionary:
 return host.shop_session.ledger.model.state.shop_visit.active_elixir.duplicate(true)

func _begin_purchase(id:String)->void:
 _release();buying_id=id;_next("prepare_shop_exit")

func _shop_sequence()->void:
 if elapsed-step_at<SETTLE or capture_pending:return
 var panel:Control=host.shop_panel
 var session:RefCounted=host.shop_session
 var model:RefCounted=session.ledger.model
 match step:
  "prepare_shop_exit":
   if session.panel_open:_end("unexpected_shop_before_exit_preflight",9);return
   if session.exit_map_open:
    _record("close_exit_before_shop",{"exit":session.room_exit_view(),"position":host.sim.hero.position})
    _host_key(KEY_M);_next("leave_exit_before_shop");return
   if bool(session.room_exit_view().get("reenter_required",false)):
    _next("leave_exit_before_shop");return
   _next("open_shop")
  "leave_exit_before_shop":
   if session.exit_map_open:_end("normal_exit_map_close_failed",9);return
   var gate:Dictionary=session.room_exit_view()
   if bool(gate.get("inside",false)) or bool(gate.get("reenter_required",false)):
    _walk_exit_down(gate);return
   _release()
   _record("exit_left_before_shop",{"exit":gate,"position":host.sim.hero.position})
   _next("open_shop")
  "open_shop":
   if session.exit_map_open or bool(session.room_exit_view().get("reenter_required",false)):
    _end("shop_exit_preflight_not_clear",9);return
   if session.panel_open:_end("unexpected_open_shop",9);return
   _host_key(KEY_P);_next("shop_tab")
  "shop_tab":
   if not session.panel_open:_end("normal_shop_open_failed",9);return
   var tab:Button=null
   for child:Node in panel._title.get_parent().get_child(1).get_children():
    if child is Button and child.text.begins_with("消耗品"):tab=child;break
   if _press_visible(tab,"consumables_tab"):_next("select_item")
  "select_item":
   if not panel._item_buttons.has(buying_id):_end("catalog_item_missing",9);return
   var button:Button=panel._item_buttons[buying_id]
   # Normal ScrollContainer visibility request; no viewport or state rewrite.
   var ancestor:Node=button.get_parent()
   while ancestor!=null and not ancestor is ScrollContainer:ancestor=ancestor.get_parent()
   if ancestor is ScrollContainer:ancestor.ensure_control_visible(button)
   _next("select_visible")
  "select_visible":
   if _press_visible(panel._item_buttons[buying_id],"select_"+buying_id):_next("purchase")
  "purchase":
   var quote:Dictionary=panel._quote.duplicate(true)
   if panel._selected!=buying_id or not quote.get("accepted",false):_end("source_quote_unavailable",9);return
   var gold:int=int(model.state.gold)
   var count:int=_count(buying_id)
   var stats:Dictionary=host.sim.hero.stats.duplicate(true)
   var active:Dictionary=_active()
   if not _press_visible(panel._buy,"buy_"+buying_id):return
   if not session.last_receipt.get("accepted",false) or gold-int(model.state.gold)!=int(quote.charge) or _count(buying_id)!=count+1:_end("purchase_receipt_mismatch",9);return
   purchases.append({"id":buying_id,"quote":quote,"gold_before":gold,"gold_after":model.state.gold,"receipt":session.last_receipt.duplicate(true)})
   _record("purchase",purchases.back())
   if buying_id==target_id:
    if not active.is_empty() or not _active().is_empty() or stats!=host.sim.hero.stats:_end("undrunk_purchase_changed_effects",9);return
    bought=true;before_stats=stats;drink_uid=int(_held(target_id).uid)
    _record("undrunk_inventory_no_effect",_snapshot());_capture("undrunk_inventory");_next("drink")
   else:treatment_purchased+=1;_next("close_shop")
  "drink":
   # Explicit contract supplied by UI worker. Missing contract is a stop, never a direct consume fallback.
   var buttons:Variant=panel.get("_elixir_drink_buttons")
   if not buttons is Dictionary or not buttons.has(drink_uid):_end("drink_source_button_missing",9);return
   var gold:int=int(model.state.gold)
   var count:int=_count(target_id)
   if not _press_visible(buttons[drink_uid],"drink_"+target_id):return
   if not session.last_receipt.get("accepted",false) or _count(target_id)!=count-1 or int(model.state.gold)!=gold or str(_active().get("item",""))!=target_id:_end("drink_receipt_mismatch",9);return
   if not model.elixir_consumer.static_stats().is_empty() or before_stats!=host.sim.hero.stats:_end("pending_elixir_applied_before_combat",9);return
   drunk=true;active_stats=host.sim.hero.stats.duplicate(true)
   _record("source_ui_drink",_snapshot());_capture("drunk_safe");_next("close_shop")
  "close_shop":
   if _press_visible(panel._close,"close_shop"):_next("route")

func _observe_battle()->void:
 if not drunk:return
 var session:RefCounted=host.shop_session
 var active:Dictionary=_active()
 if host.sim.phase=="combat" and not cleared:_record("elixir_combat_sample",_snapshot())
 if not battle_seen and host.sim.phase=="combat":
  if str(active.get("item",""))!=target_id or str(active.get("battle_id","" )).is_empty():_end("next_battle_elixir_not_bound",9);return
  if host.shop_session.ledger.model.elixir_consumer.static_stats()!=EXPECTED_STATIC[target_id]:_end("combat_static_projection_mismatch",9);return
  battle_seen=true;elixir_battle=str(active.battle_id)
  _record("next_actual_combat",_snapshot());_capture("elixir_actual_combat")
 if battle_seen and not cleared and (host.sim.phase=="victory" or session.status=="completed"):
  if not active.is_empty() or not host.shop_session.ledger.model.elixir_consumer.static_stats().is_empty():_end("battle_end_elixir_not_cleared",9);return
  cleared=true;_record("next_battle_end_cleared",_snapshot());_capture("elixir_cleared")
 if cleared and not active.is_empty():_end("elixir_reappeared",9)

func _end(reason:String,code:int)->void:
 if stopping:return
 stopping=true
 _record("final",{"reason":reason,"target":target_id,"bought":bought,"drunk":drunk,"actual_battle_seen":battle_seen,"battle_end_cleared":cleared,"full_floor":code==0 and reason=="normal_full_floor_complete","effect_cycle_verified":bought and drunk and battle_seen and cleared,"purchases":purchases,"treatments":uses,"route":selected_route,"captures":captures,"effect_numeric_acceptance":"pending_runtime_projection_contract","native_acceptance":false,"not_covered":["duplicate_command","full_slot_auto_drink","same_name_reject","replacement","undo","war_kill_refresh_and_3s_expiry","stride_dash_completion_and_1p5s_expiry","hunt_actual_elite_boss_final_damage"]})
 if output_file!=null:output_file.close();output_file=null
 if is_instance_valid(host):host.frontdoor_close_run("elixir_flow_observer")
 print("FINAL ELIXIR_FLOW_", "COMPLETE" if code==0 else "FAIL"," ",reason)
 quit(code)

func _walk_exit_down(gate:Dictionary)->void:
 # Leave the actual source exit bounds using ordinary movement input only.
 # Positive world-z is the existing S/down direction. No exit-state writes.
 var position:Vector3=gate.position
 var half:Vector2=gate.half
 _walk(Vector3(host.sim.hero.position.x,host.sim.hero.position.y,position.z+half.y+1.2))

func _check_stage_watchdog()->bool:
 var now:int=Time.get_ticks_msec()
 if entry==null or not started or host==null:
  if now-wall_started>15000:_end("boot_or_host_stage_timeout",9);return false
  return true
 if not host.floor_error.is_empty() or not host.startup_session_error.is_empty():
  _record("explicit_host_fault",{"floor_error":host.floor_error,"startup_session_error":host.startup_session_error})
  _end("host_fault",9);return false
 var session:RefCounted=host.shop_session
 if session.status in ["faulted","defeated","aborted"]:
  _end("route_"+str(session.status),9);return false
 if step!="route":
  if now-step_wall>12000:
   _record("stage_timeout",{"step":step,"exit":session.room_exit_view(),"position":host.sim.hero.position})
   _end("ui_stage_timeout:"+step,9);return false
  return true
 var context:String=JSON.stringify([session.active_node_room,session.status,host.sim.phase,session.initial_modal_open])
 if context!=watchdog_context:
  watchdog_context=context;watchdog_since=now;watchdog_progress_at=now;watchdog_progress=""
 var combat:bool=host.sim.phase=="combat" and not session.initial_modal_open
 var stage_limit:int=100000 if combat else 30000
 if now-watchdog_since>stage_limit:
  _record("stage_timeout",{"context":context,"exit":session.room_exit_view(),"position":host.sim.hero.position})
  _end("route_stage_timeout",9);return false
 # No-progress clock ignores actor movement and cooldown cycling during combat:
 # only real enemy HP/live-count changes count, so circling cannot keep it alive.
 var progress:Array=[]
 if combat:
  for enemy:Dictionary in host.sim.living():progress.append([enemy.get("actor_id",""),enemy.get("hp",0.0)])
 else:
  progress=[host.sim.hero.position.snapped(Vector3(0.25,0.25,0.25)),session.exit_map_open,selected_route.size()]
 var signature:String=JSON.stringify(_json_value(progress))
 if signature!=watchdog_progress:watchdog_progress=signature;watchdog_progress_at=now
 if now-watchdog_progress_at>20000:
  _record("no_progress",{"context":context,"exit":session.room_exit_view(),"position":host.sim.hero.position})
  _end("route_no_progress_timeout",9);return false
 return true

func _process(dt:float)->bool:
 if stopping:return false
 elapsed+=dt;tick+=dt
 if elapsed>=ROUTE_TIMEOUT or Time.get_ticks_msec()-wall_started>=450000:_end("hard_observer_timeout",9);return false
 if not _check_stage_watchdog():return false
 if tick<0.12:return false
 tick=0.0
 if entry==null:
  var boot:Node=root.get_node_or_null("Boot")
  if boot!=null:
   for child:Node in boot.get_children():
    if child.get("screen")!=null:entry=child
  return false
 if not started:
  started=true
  if _press_visible(entry._start,"start_normal_run"):_next("route")
  return false
 host=entry.active_room
 if host==null:return false
 if not host.floor_error.is_empty() or not host.startup_session_error.is_empty():_end("host_fault",9);return false
 var session:RefCounted=host.shop_session
 var sim:Node=host.sim
 if session.status in ["faulted","defeated","aborted"]:_end("route_"+str(session.status),9);return false
 _observe_battle()
 if stopping:return false
 if stop_after_effect and cleared and not capture_pending:
  _end("normal_effect_cycle_complete",0);return false
 if step!="route":_shop_sequence();return false
 if session.status=="completed":
  if capture_pending:return false
  if bought and drunk and battle_seen and cleared:_end("normal_full_floor_complete",0)
  else:_end("floor_complete_without_all_observations",9)
  return false
 if session.initial_modal_open:
  _release()
  if host.initial_hud.hex_draft.visible:host.initial_hud.hex_draft.selected.emit(0)
  return false
 if session.status!="service" and session.shop_location_reason().is_empty() and sim.phase in ["preparation","victory"]:
  var model:RefCounted=session.ledger.model
  if not model.commerce_definitions.items.has(target_id):_end("target_definition_missing",9);return false
  var price:int=int(model.commerce_definitions.items[target_id].price)
  var gold:int=int(model.state.gold)
  var budget:Dictionary={"room":session.active_node_room,"gold":gold,"target_price":price,"treatment_spent":treatment_purchased*200,"inventory":model.state.inventory.duplicate(true)}
  var signature:String=JSON.stringify(budget)
  if signature!=budget_record:budget_record=signature;_record("real_budget",budget)
  var next_is_combat:bool=selected_route.size()<ROUTE.size() and ROUTE[selected_route.size()] not in ["r06a","r07a","r09a","r11a"]
  var target_boundary:bool=next_is_combat
  if target_id=="elixir:04":target_boundary=selected_route.size()<ROUTE.size() and ROUTE[selected_route.size()]=="r12boss"
  if not bought and gold>=price and target_boundary:_begin_purchase(target_id);return false
  if not bought and gold<price and str(session.active_node_room).ends_with("/r10a"):_end("row10_target_budget_insufficient",9);return false
  if bought and treatment_purchased<MAX_TREATMENT_PURCHASES and _count("potion:1")<MAX_STOCK and gold>=200:
   _begin_purchase("potion:1");return false
 _learn()
 if elapsed-last_progress>=10.0:last_progress=elapsed;_record("route_progress",_snapshot())
 if session.status=="service":_release();_press_visible(host.service_continue,"continue_actual_service");return false
 if session.exit_map_open:
  _release()
  if selected_route.size()>=ROUTE.size():_end("bounded_route_exhausted",9);return false
  var id:String=ROUTE[selected_route.size()]
  if not host.route_map.buttons.has(id):_end("required_adjacent_route_unavailable:"+id,9);return false
  if _press_visible(host.route_map.buttons[id],"route_"+id):selected_route.append(id)
  return false
 if sim.phase in ["preparation","victory"]:
  var gate:Dictionary=session.room_exit_view()
  if bool(gate.get("reenter_required",false)):
   if not rearm_walking:
    rearm_walking=true;_record("exit_reenter_walk_out",{"exit":gate,"position":sim.hero.position})
   _walk_exit_down(gate);return false
  if rearm_walking:
   rearm_walking=false;_release();_record("exit_reenter_rearmed",{"exit":gate,"position":sim.hero.position})
  _walk(gate.position);return false
 if sim.phase=="combat":_combat()
 return false
