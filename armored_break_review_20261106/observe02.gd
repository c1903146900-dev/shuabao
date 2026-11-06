extends SceneTree
# Normal source combat and UI actions, script-assisted navigation. No game-state
# injection. NOT human/OS full-floor or Windows acceptance.
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
var images:Array[Image]=[]
var sample_at:float=0
var combat_started:float=-1
var last_room:String=""
var captured_states:Dictionary={}
func watch(event:Dictionary)->void:
 var k:String=str(event.get("kind",""))
 if k in ["encounter_started","encounter_finished","enemy_warning","enemy_impact","enemy_shot","enemy_pounce_started","damage","action_rejected"]:print("BATTLE_EVENT ",JSON.stringify(event))
func sample_battle()->void:
 if host==null or host.sim==null:return
 if host.sim.phase=="combat" and combat_started<0:combat_started=elapsed
 if elapsed<sample_at:return
 sample_at=elapsed+.25
 var guards:Array=host.presentation.receipt.get("armored_body_facing",[])
 var state_parts:Array[String]=[]
 for guard:Dictionary in guards:
  state_parts.append("%s:%s:%s"%[guard.actor_id,guard.facing,float(guard.guard_broken_left)>0.0])
 state_parts.sort()
 var state_key:String=";".join(state_parts)
 if not state_key.is_empty() and not captured_states.has(state_key) and images.size()<12:
  captured_states[state_key]=true
  images.append(root.get_texture().get_image())
  print("GUARD_CAPTURE ",images.size()-1," ",JSON.stringify(guards)," pose=",JSON.stringify(host.presentation.receipt.get("armored_guard_pose",[])))
 print("BATTLE_SAMPLE ",images.size()-1," ",JSON.stringify({"elapsed":elapsed,"room":host.sim.room_id,"phase":host.sim.phase,"hero":host.sim.hero.position,"hp":host.sim.hero.hp,"enemies":host.sim.living().map(func(e):return {"id":e.actor_id,"kind":e.kind,"position":e.position,"state":e.state,"hp":e.hp,"timer":e.timer,"wait_age":e.get("wait_age",0.0),"aim":e.aim}),"visual_errors":host.presentation.receipt.get("errors",[]),"guard_facing":host.presentation.receipt.get("armored_body_facing",[])}))
func finish_review()->void:
 release()
 for i in range(images.size()):images[i].save_png("user://armored_break/capture02/frame_%03d.png"%i)
 print("BATTLE_REVIEW_DONE elapsed=",elapsed," room=",host.sim.room_id," HP=",host.sim.hero.hp)
 host.frontdoor_close_run("battle_flow_review");quit()
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
 if int(s.skills.E.rank)==0:choices.append(["E","E2"])
 if int(s.skills.Q.rank)==0:choices.append(["Q","Q2"])
 if int(s.skills.P.rank)==0:choices.append(["P","P2"])
 choices.append_array([["E","E2"],["Q","Q2"],["P","P2"]])
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
 sample_battle()
 if combat_started>=0 and elapsed-combat_started>20:
  finish_review();return false
 if elapsed>550:fail("timeout");return false
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
 if not watching:host.sim.combat_event.connect(watch);watching=true
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
   if str(c.node_id).ends_with("b") or str(c.node_id)=="r12boss":id=str(c.node_id)
  if host.route_map.buttons[id].disabled:fail("disabled_choice");return false
  host.route_map.buttons[id].pressed.emit();route.append(id);return false
 if sim.phase in ["preparation","victory"]:shop();walk(Vector3(0,0,-11));return false
 if sim.phase!="combat":return false
 var live:Array=sim.living()
 if live.is_empty():release();return false
 var target:Dictionary=live[0]
 for e in live:
  if sim.hero.position.distance_to(e.position)<sim.hero.position.distance_to(target.position):target=e
 var aim:Vector3=target.position;var distance:float=sim.hero.position.distance_to(aim);var evade:bool=false
 for threat in live:
  if str(threat.state)=="warning" and float(threat.warning_progress)>.20 and sim.hero.position.distance_to(threat.position)<float(threat.attack_range)+2:
   var side:=Vector3(-float(threat.aim.z),0,float(threat.aim.x));var a:Vector3=sim._move_clipped(sim.hero.position,sim.hero.position+side*2.2,sim.hero_radius);var b:Vector3=sim._move_clipped(sim.hero.position,sim.hero.position-side*2.2,sim.hero_radius)
   walk(a if a.distance_to(sim.hero.position)>=b.distance_to(sim.hero.position) else b)
   if float(threat.timer)<.25 and float(sim.hero.cooldowns.shift)<=0:press(KEY_SHIFT,aim)
   evade=true;break
 if not evade:walk(aim,1.45)
 if sim.hero.hp<sim.hero.stats.max_hp*.7:
  for button in host.ordinary_potion_controls.get_children():
   if button is Button and not button.disabled and host.ordinary_potion_controls.visible:
    button.pressed.emit()
    if s.last_receipt.get("accepted",false):used+=1
    break
 if distance<7 and float(sim.hero.cooldowns.e)<=0 and not sim.hero.cast_state.has("e2_shadow"):press(KEY_E,aim)
 if distance<9 and float(sim.hero.cooldowns.q)<=0:press(KEY_Q,aim)
 if distance<7 and float(sim.hero.cooldowns.r)<=0:press(KEY_R,aim)
 var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
 if distance<2.4:host.input_router.handle_event(event,aim,false)
 event.pressed=false;host.input_router.handle_event(event,aim,false)
 return false
