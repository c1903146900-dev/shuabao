extends SceneTree
# Normal source combat and UI actions, script-assisted navigation. No game-state
# injection. NOT human/OS full-floor or Windows acceptance.
class PointerEvidence extends Node:
 var host:Node
 var entry:Node
 var armed:bool=false
 var auto_resume:bool=false
 func _input(event:InputEvent)->void:
  if event is InputEventKey and event.physical_keycode==KEY_F7 and event.pressed:
   armed=true;auto_resume=true;print("MENU_HOLD_ARMED");return
  if event is InputEventKey and event.physical_keycode==KEY_F8 and event.pressed:
   armed=true;print("MENU_BOUNDARY_ARMED");return
  if armed and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
   armed=false
   get_tree().create_timer(.25).timeout.connect(func():
    print("MENU_BOUNDARY_OPEN left=",host.input_router._left_physical);entry._pause.pressed.emit()
    if auto_resume:
     auto_resume=false
     get_tree().create_timer(.30).timeout.connect(func():entry._resume.pressed.emit();print("MENU_HOLD_RESUMED")))
  if event is InputEventKey and event.physical_keycode==KEY_F9 and event.pressed:
   print("HANDPLAY_CLOSED");host.frontdoor_close_run("native_first_room_observation");get_tree().quit();return
  if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and host!=null:
   var point:Vector2=event.position
   var body:Vector3=host.presentation.body_aim_at(point)
   var ground:Vector3=host._ground_at(point)
   var origin:Vector3=host.sim.hero.position
   print("NATIVE_EVENT_POINT ",JSON.stringify({"point":point,"body":body,"ground":ground,"origin":origin,"expected":(host._basic_aim_at(point)-origin).normalized(),"hero_occludes":host.presentation.body_pick_regions.filter(func(r):return r.has("hero_triangles") and host.presentation._hero_pixel_hit(r,point)).size(),"ground_direction":(ground-origin).normalized(),"enemies":host.sim.living().map(func(e):return {"id":e.actor_id,"position":e.position,"hp":e.hp})}))
var pointer_evidence:PointerEvidence
var elapsed:float=0
var tick:float=0
var entry:Node
var host:Node
var started:bool=false
var shops:Dictionary={}
var route:Array=[]
var purchases:int=0
var used:int=0
var logged:float=0
var watching:bool=false
var counts:Dictionary={}
var initial_paused:bool=false
var native_seen:int=0
var click_count:int=0
var last_click_at:float=-1
var ready_close:bool=false
var ready_empty:bool=false
var close_target:String=""
func watch(event:Dictionary)->void:
 if str(event.get("kind",""))=="attack_started":
  var point:Vector2=host.get_viewport().get_mouse_position()
  var body:Vector3=host.presentation.body_aim_at(point)
  var ground:Vector3=host._ground_at(point)
  print("HELD_AIM_SAMPLE ",JSON.stringify({"cast_id":event.cast_id,"point":point,"body":body,"ground":ground,"origin":event.origin,"direction":event.direction,"expected":(host._basic_aim_at(point)-event.origin).normalized()}))
 if str(event.get("kind","")) in ["attack_started","dash_attack_started","damage","dash","e1_started","e1_marked","e1_pierce_started","e1_pierce_finished","enemy_warning","enemy_attack_cancelled"]:print("NATIVE_COMBAT ",JSON.stringify(event))
func observe_native()->void:
 if host==null:return
 while native_seen<host.inputs.size():
  var record:Dictionary=host.inputs[native_seen];native_seen+=1
  print("NATIVE_INPUT ",JSON.stringify(record))
  var mouse:Vector2=host.get_viewport().get_mouse_position()
  print("NATIVE_PICK ",JSON.stringify({"point":mouse,"ground":host._ground_at(mouse),"body":host.presentation.body_aim_at(mouse),"hero":host.sim.hero.position,"alive":host.sim.living().map(func(e):return {"id":e.actor_id,"kind":e.kind,"position":e.position,"hp":e.hp})}))
  if str(record.event).contains("Mouse Button") or str(record.event).contains("MouseButton"):
   click_count+=1;last_click_at=elapsed
func fail(reason:String)->void:print("FINAL NATURAL_FAIL ",reason," time=",elapsed," route=",route);quit(9)
func key(k:int,on:bool,aim:Vector3=Vector3.INF)->void:
 var e:=InputEventKey.new();e.physical_keycode=k;e.keycode=k;e.pressed=on;host.input_router.handle_event(e,aim,host._blocked())
func press(k:int,aim:Vector3)->void:key(k,true,aim);key(k,false,aim)
func release()->void:
 for k in [KEY_W,KEY_A,KEY_S,KEY_D]:key(k,false)
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=false;host.input_router.handle_event(e)
func walk(target:Vector3,stop:float=.15)->void:
 var p:Vector3=host.sim.hero.position
 if p.distance_to(target)<stop:
  for k in [KEY_W,KEY_A,KEY_S,KEY_D]:key(k,false)
  return
 var best:=Vector3.ZERO;var score:float=-INF
 for v in [Vector3(0,0,-1),Vector3(1,0,-1).normalized(),Vector3(1,0,0),Vector3(1,0,1).normalized(),Vector3(0,0,1),Vector3(-1,0,1).normalized(),Vector3(-1,0,0),Vector3(-1,0,-1).normalized()]:
  var at:Vector3=host.sim._move_clipped(p,p+v*.7,host.sim.hero_radius)
  var value:float=p.distance_to(target)-at.distance_to(target)
  if at.distance_to(p)<.05:value-=10
  if value>score:score=value;best=v
 key(KEY_W,best.z<-.2,target);key(KEY_S,best.z>.2,target);key(KEY_A,best.x<-.2,target);key(KEY_D,best.x>.2,target)
func learn()->void:
 var s:Dictionary=host.shop_session.ledger.model.state
 if int(s.points)<=0:return
 var choices:Array=[]
 if int(s.level)>=7 and int(s.skills.R.rank)==0:choices.append(["R","R1"])
 if int(s.skills.E.rank)==0:choices.append(["E","E1"])
 if int(s.skills.Q.rank)==0:choices.append(["Q","Q2"])
 if int(s.skills.P.rank)==0:choices.append(["P","P2"])
 choices.append_array([["E","E1"],["Q","Q2"],["P","P2"]])
 for c in choices:
  var rank:int=s.skills[c[0]].rank
  host.initial_hud.adapter.request("learn",{"slot_id":c[0],"candidate_id":c[1],"expected_rank":rank})
  if int(host.shop_session.ledger.model.state.skills[c[0]].rank)>rank:print("LEARN ",c);break
func shop()->void:
 var s=host.shop_session
 if shops.has(s.active_node_room) or s.shop_location_reason()!="":return
 shops[s.active_node_room]=true
 if int(s.ledger.model.state.gold)<200:return
 release();host._shop(true)
 if not s.panel_open:return
 host.shop_panel._select("potion:1")
 for n in range(2):
  if host.shop_panel._buy.disabled:break
  host.shop_panel._buy.pressed.emit();purchases+=1
 host._shop(false)
func _initialize()->void:root.add_child(load("res://boot.tscn").instantiate())
func _process(dt:float)->bool:
 elapsed+=dt;tick+=dt
 observe_native()
 if elapsed>180:fail("timeout");return false
 if tick<.12:return false
 tick=0
 if entry==null:
  var boot=root.get_node_or_null("Boot")
  if boot!=null:
   for c in boot.get_children():
    if c.get("screen")!=null:entry=c
  return false
 if not started:started=true;entry._start.pressed.emit();return false
 host=entry.active_room
 if host==null:return false
 if not watching:
  host.sim.combat_event.connect(watch);watching=true
  pointer_evidence=PointerEvidence.new();pointer_evidence.host=host;pointer_evidence.entry=entry;root.add_child(pointer_evidence)
 if not host.floor_error.is_empty() or not host.startup_session_error.is_empty():fail("host_fault");return false
 var s=host.shop_session;var sim=host.sim
 if s.status in ["faulted","defeated"]:fail(s.status);return false
 if s.status=="completed":
  release();print("MOTION_COUNTS ",JSON.stringify(counts));print("FINAL NATURAL_PASS time=",elapsed," rows=",s.node_index," HP=",sim.hero.hp," gold=",s.ledger.model.state.gold," purchased=",purchases," used=",used," route=",route);host.frontdoor_close_run("natural_rebuild");quit();return false
 if elapsed-logged>5:logged=elapsed;print("PROGRESS ",elapsed," ",s.active_node_room," HP=",sim.hero.hp," enemies=",sim.living().size())
 if s.initial_modal_open:
  release()
  if host.initial_hud.hex_draft.visible:host.initial_hud.hex_draft.selected.emit(0)
  return false
 learn()
 if s.status=="service":release();shop();host.service_continue.pressed.emit();return false
 if s.exit_map_open:
  release();var choices:Array=s.available_choices()
  if choices.is_empty():fail("no_choices");return false
  var id:String=str(choices[0].node_id)
  for c in choices:
   if str(c.node_id).ends_with("c") or str(c.node_id)=="r12boss":id=str(c.node_id)
  if host.route_map.buttons[id].disabled:fail("disabled_choice");return false
  host.route_map.buttons[id].pressed.emit();route.append(id);return false
 if sim.phase in ["preparation","victory"]:shop();walk(Vector3(0,0,-11));return false
 if sim.phase!="combat":return false
 if not initial_paused:
  release();initial_paused=true
  var pause:=InputEventKey.new();pause.physical_keycode=KEY_SPACE;pause.keycode=KEY_SPACE;pause.pressed=true;host._input(pause)
  print("NATIVE_MANUAL_READY")
 return false
