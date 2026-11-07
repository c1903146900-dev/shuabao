extends SceneTree
# PREPARED ONLY. No engine/check-only execution was used to validate this file.
# Normal Boot, real combat inputs, earned gold and visible source shop Buttons.
# Never writes actor, inventory, HP, gold, world, viewport or production state.
# Modes: --potion-dock-mode=mixed (three ordinary tiers) or =flask (one flask).
# Required: --observer-output=/absolute/local/path/private_captures/fresh_name
# Parent owns unchanged guard, launch, native clicks, and final visual acceptance.
const ROUTE_TIMEOUT:float=240.0
const NATIVE_WINDOW:float=90.0
const CAPTURE_LIMIT:int=24
const SETTLE:float=0.65
const ROUTE:Array[String]=["r01a","r02a","r03a","r04d","r05c","r06d","r07a","r08a"]
var mode:String=""
var output_dir:String=""
var output_file:FileAccess
var entry:Node
var host:Node
var elapsed:float=0.0
var tick:float=0.0
var step:String="boot"
var step_at:float=0.0
var ready_at:float=-1.0
var started:bool=false
var stopping:bool=false
var purchase_index:int=0
var purchases:Array=[]
var selected_route:Array=[]
var captures:int=0
var capture_pending:bool=false
var last_capture:float=-10.0
var pending_label:String=""
var native_signature:String=""
var native_events:int=0
var last_progress:float=0.0

class PointerAudit extends Node:
 var observer
 func _input(event:InputEvent)->void:
  observer.record_native_input(event)

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
 print("POTION_DOCK_",kind.to_upper()," ",line)

func _initialize()->void:
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--observer-output="):output_dir=arg.trim_prefix("--observer-output=").simplify_path()
  elif arg.begins_with("--potion-dock-mode="):mode=arg.trim_prefix("--potion-dock-mode=")
 if mode not in ["mixed","flask"]:
  _end("explicit_mixed_or_flask_mode_required",9);return
 if not output_dir.is_absolute_path() or not "/private_captures/" in output_dir or "://" in output_dir:
  _end("absolute_private_captures_output_required",9);return
 if FileAccess.file_exists(output_dir.path_join("observations.jsonl")):
  _end("fresh_output_required",9);return
 if DirAccess.make_dir_recursive_absolute(output_dir)!=OK:
  _end("output_directory_unwritable",9);return
 output_file=FileAccess.open(output_dir.path_join("observations.jsonl"),FileAccess.WRITE)
 if output_file==null:_end("output_file_unwritable",9);return
 _record("configuration",{"mode":mode,"route":ROUTE,"route_timeout":ROUTE_TIMEOUT,"native_window":NATIVE_WINDOW,"capture_limit":CAPTURE_LIMIT,"capture_interval_min":0.6,"state_injection":false,"native_acceptance_automatic":false,"upgrades_exercised":false})
 root.add_child(load("res://boot.tscn").instantiate())
 var audit:=PointerAudit.new();audit.observer=self;root.add_child(audit)

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

func _capture(label:String)->void:
 if stopping or capture_pending or captures>=CAPTURE_LIMIT:return
 capture_pending=true
 await RenderingServer.frame_post_draw
 if stopping or not is_instance_valid(host):capture_pending=false;return
 var controls:Array=[]
 var dock:Control=host.ordinary_potion_controls
 for child:Node in dock.get_children():
  if child is Button:controls.append(_control(child))
 var model:RefCounted=host.shop_session.ledger.model
 var image:Image=root.get_texture().get_image()
 if image==null or image.is_empty():capture_pending=false;_end("empty_completed_draw_image",9);return
 var filename:String="%02d_%s.png"%[captures,label]
 if image.save_png(output_dir.path_join(filename))!=OK:capture_pending=false;_end("screenshot_write_failed",9);return
 _record("draw",{"label":label,"index":captures,"completed_draw":true,"draw_frame":Engine.get_frames_drawn(),"image":filename,"image_size":image.get_size(),"viewport":root.get_visible_rect(),"window_size":root.size,"physical_window_size":DisplayServer.window_get_size(),"screen_transform":root.get_screen_transform(),"stretch_transform":root.get_stretch_transform(),"content_scale_size":root.content_scale_size,"room":host.shop_session.active_node_room,"status":host.shop_session.status,"phase":host.sim.phase,"paused":host.sim.paused,"hp":host.sim.hero.hp,"gold":model.state.gold,"inventory":model.state.inventory.duplicate(true),"flask_charges":model.state.shop_visit.flask_charges,"flask_entitlement":model.state.shop_visit.flask_entitlement,"last_receipt":host.shop_session.last_receipt.duplicate(true),"ordinary_recovery":model.potion_consumer.snapshot(),"flask_recovery":model.flask_consumer.snapshot(),"dock":_control(dock),"buttons":controls,"bar":_control(host.initial_hud.bottom_bar),"popup":_control(host.initial_hud.bottom_popup),"shop_open":host.shop_session.panel_open,"exit_map_open":host.shop_session.exit_map_open,"initial_modal_open":host.shop_session.initial_modal_open,"finished":host.finished,"visual_errors":host.presentation.receipt.get("errors",[])})
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
 # Deliberately no auto-consumption: all purchase budget and tier counts persist.
 if distance<7 and float(sim.hero.cooldowns.e)<=0 and not sim.hero.cast_state.has("e2_shadow"):_press(KEY_E,aim)
 if distance<9 and float(sim.hero.cooldowns.q)<=0:_press(KEY_Q,aim)
 if distance<7 and float(sim.hero.cooldowns.r)<=0:_press(KEY_R,aim)
 var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
 if distance<2.4:host.input_router.handle_event(event,aim,false)
 event.pressed=false;host.input_router.handle_event(event,aim,false)

func _next(next:String)->void:step=next;step_at=elapsed

func _items()->Array[String]:
 return ["potion:1","potion:2","potion:3"] if mode=="mixed" else ["flask:1"]

func _shop_sequence()->void:
 if elapsed-step_at<SETTLE or capture_pending:return
 var panel:Control=host.shop_panel
 var session:RefCounted=host.shop_session
 match step:
  "open_shop":
   if session.exit_map_open:_host_key(KEY_M)
   _host_key(KEY_P);_next("shop_tab")
  "shop_tab":
   if not session.panel_open:_end("normal_shop_open_failed",9);return
   _capture("shop_open_hidden_dock")
   var tab:Button=null
   for child:Node in panel._title.get_parent().get_child(1).get_children():
    if child is Button and child.text.begins_with("消耗品"):tab=child;break
   if _press_visible(tab,"consumables_tab"):_next("select_item")
  "select_item":
   var id:String=_items()[purchase_index]
   if not panel._item_buttons.has(id):_end("missing_catalog_button:"+id,9);return
   if _press_visible(panel._item_buttons[id],"select_"+id):_next("purchase")
  "purchase":
   var id:String=_items()[purchase_index]
   var before:Dictionary=session.ledger.model.state.duplicate(true)
   var quote:Dictionary=panel._quote.duplicate(true)
   if panel._selected!=id or not quote.get("accepted",false):_end("purchase_quote_unavailable:"+id,9);return
   if not _press_visible(panel._buy,"buy_"+id):return
   var after:Dictionary=session.ledger.model.state
   var held:Dictionary={}
   for item:Dictionary in after.inventory:
    if str(item.id)==id:held=item.duplicate(true);break
   if not session.last_receipt.get("accepted",false) or int(before.gold)-int(after.gold)!=int(quote.charge) or held.is_empty() or int(held.count)!=1:
    _end("real_purchase_receipt_mismatch:"+id,9);return
   purchases.append({"id":id,"gold_before":before.gold,"gold_after":after.gold,"quote":quote,"held":held,"receipt":session.last_receipt.duplicate(true)})
   _record("purchase",purchases.back());purchase_index+=1;_next("close_shop")
  "close_shop":
   if _press_visible(panel._close,"close_shop"):_next("purchased_view")
  "purchased_view":
   if session.panel_open or session.exit_map_open:_end("closed_shop_view_occluded",9);return
   var count:int=0
   for child:Node in host.ordinary_potion_controls.get_children():
    if child is Button:count+=1
   if count!=purchase_index:_end("source_button_count_mismatch",9);return
   _capture(mode+"_"+str(purchase_index)+"_safe")
   _next("after_purchased_view")
  "after_purchased_view":
   if purchase_index<_items().size():_next("open_shop")
   elif mode=="mixed":_release();_host_key(KEY_SPACE);_next("paused_ready")
   else:_next("route")
  "paused_ready":
   if not host.sim.paused:_end("normal_space_pause_failed",9);return
   _capture(mode+"_native_paused")
   ready_at=elapsed;_next("native")
   _record("native_ready",{"mode":mode,"seconds":NATIVE_WINDOW,"purchases":purchases,"instructions":"Automation is stopped. Space resumes source play; paused buttons must be disabled. Native clicks can inspect actual tier/UID consumption, skill-popup/shop/map hiding, and gaps. Flask is combat-only and limited to two uses. F10 closes normally. No automatic native acceptance."})

func record_native_input(event:InputEvent)->void:
 if stopping or step!="native" or not is_instance_valid(host):return
 if not (event is InputEventMouseButton or (event is InputEventKey and not event.echo)):return
 native_events+=1
 _record("native_input",{"event":event.as_text(),"hovered":str(root.gui_get_hovered_control()),"mouse":root.get_mouse_position(),"last_receipt_before_gui":host.shop_session.last_receipt.duplicate(true)})
 pending_label="native_input"

func _native()->void:
 var model:RefCounted=host.shop_session.ledger.model
 var signature:String=JSON.stringify([model.state.inventory,model.state.shop_visit.flask_charges,host.sim.paused,host.shop_session.panel_open,host.shop_session.exit_map_open,host.initial_hud.bottom_popup.visible,host.shop_session.status])
 if signature!=native_signature:native_signature=signature;pending_label="native_state_change"
 if not pending_label.is_empty() and elapsed-last_capture>=0.6 and not capture_pending:
  var label:String=pending_label;pending_label="";_capture(label)
 if elapsed-ready_at>=NATIVE_WINDOW:_end("bounded_observation_complete_not_native_acceptance",0)

func _end(reason:String,code:int)->void:
 if stopping:return
 stopping=true
 _record("final",{"reason":reason,"setup_attained":ready_at>=0.0,"mode":mode,"captures":captures,"native_input_events":native_events,"route":selected_route,"purchases":purchases,"native_acceptance":"parent_review_required","full_floor":false,"upgrade_coverage":"none","four_button_coexistence":"illegal_recovery_mutex"})
 if output_file!=null:output_file.close();output_file=null
 if is_instance_valid(host):host.frontdoor_close_run("potion_dock_observer")
 print("FINAL POTION_DOCK_", "OBSERVATION_COMPLETE" if code==0 else "FAIL", " ",reason)
 quit(code)

func _process(dt:float)->bool:
 if stopping:return false
 elapsed+=dt;tick+=dt
 if elapsed>ROUTE_TIMEOUT+NATIVE_WINDOW:_end("hard_observer_timeout",9);return false
 if step=="native":_native();return false
 if elapsed>ROUTE_TIMEOUT:_end("normal_route_timeout",9);return false
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
 if host.shop_session.status in ["faulted","defeated","aborted"]:_end("route_"+str(host.shop_session.status),9);return false
 if step!="route":_shop_sequence();return false
 var session:RefCounted=host.shop_session
 var sim:Node=host.sim
 if session.initial_modal_open:
  _release()
  if host.initial_hud.hex_draft.visible:host.initial_hud.hex_draft.selected.emit(0)
  return false
 if mode=="flask" and purchase_index==1 and str(session.active_node_room).ends_with("/r08a") and sim.phase=="combat":
  _release();_host_key(KEY_SPACE);_next("paused_ready");return false
 if purchase_index==0 and str(session.active_node_room).ends_with("/r05c") and sim.phase=="victory" and session.shop_location_reason().is_empty():
  _release()
  var cost:int=1320 if mode=="mixed" else 1200
  if int(session.ledger.model.state.gold)<cost:_end("earned_gold_below_required_budget",9);return false
  _next("open_shop");return false
 _learn()
 if elapsed-last_progress>=10.0:
  last_progress=elapsed;_record("route_progress",{"room":session.active_node_room,"hp":sim.hero.hp,"gold":session.ledger.model.state.gold,"living":sim.living().size()})
 if session.status=="service":
  _release();_press_visible(host.service_continue,"continue_actual_service");return false
 if session.exit_map_open:
  _release()
  if selected_route.size()>=ROUTE.size():_end("bounded_route_exhausted",9);return false
  var id:String=ROUTE[selected_route.size()]
  if not host.route_map.buttons.has(id):_end("required_adjacent_route_unavailable:"+id,9);return false
  if _press_visible(host.route_map.buttons[id],"route_"+id):selected_route.append(id)
  return false
 if sim.phase in ["preparation","victory"]:_walk(Vector3(0,0,-11));return false
 if sim.phase=="combat":_combat()
 return false
