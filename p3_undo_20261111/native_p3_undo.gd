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
var reopen_checked:bool=false
var native_ready:bool=false
var proceed:bool=false
var observed_gains:int=0
var last_growth:int=-1
var hold_for_undo:bool=false
var undo_ready:bool=false
var manual_done:bool=false
class NativeAudit extends Node:
 var tree
 func _input(event:InputEvent)->void:
  if event is InputEventKey and event.pressed and event.physical_keycode==KEY_F7:
   if tree.hold_for_undo:
    tree.hold_for_undo=false;tree.manual_done=true;print("P3_NATIVE_UNDO_CHECK_DONE_CONTINUE_NORMAL_COMBAT");return
   if tree.host.shop_session.ledger.model.state.skills.P.candidate=="P3" and tree.host.shop_session.ledger.model.state.skills.P.rank==1:
    tree.proceed=true;print("P3_NATIVE_LEARN_CONFIRMED ",JSON.stringify(tree.host.shop_session.ledger.model.state.skills.P))
  if event is InputEventKey and event.pressed and event.physical_keycode==KEY_F8:
   tree.host.frontdoor_close_run("p3_manual_stop");tree.quit()
  if event is InputEventMouseButton:
   print("P3_NATIVE_POINTER ",event.as_text())
   tree.audit_state.call_deferred()
func audit_state()->void:
 print("P3_NATIVE_TRANSACTION_STATE ",JSON.stringify({"skills":host.shop_session.ledger.model.state.skills,"points":host.shop_session.ledger.model.state.points,"allocations":host.shop_session.ledger.model.state.allocations,"growth":host.sim.hero.permanent_ad,"progress":host.sim.hero.p3_progress,"credited":host.sim.hero.credited_kills,"phase":host.shop_session.ledger.model.state.phase}))
func watch(event:Dictionary)->void:
 if str(event.get("kind",""))=="permanent_attack_gained":
  observed_gains+=1;print("P3_ACTUAL_GAIN ",JSON.stringify(event)," ad=",host.sim.hero.ad()," base=",host.sim.hero.stats.ad)

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
 if not manual_done and int(s.skills.E.rank)>0:return # Reserve natural SP for manual P3 upgrade at nine kills.
 if int(s.level)>=7 and int(s.skills.R.rank)==0:choices.append(["R","R2"])
 if int(s.skills.E.rank)==0:choices.append(["E","E2"])
 if int(s.skills.Q.rank)==0:choices.append(["Q","Q1"])
 if int(s.skills.P.rank)==0:choices.append(["P","P3"])
 choices.append_array([["P","P3"],["E","E2"],["Q","Q1"]])
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
 if not host.floor_error.is_empty() or not host.startup_session_error.is_empty():fail("host_fault");return false
 var s=host.shop_session;var sim=host.sim
 if s.status in ["faulted","defeated"]:fail(s.status);return false
 if s.status=="completed":
  if observed_gains<1 or sim.hero.permanent_ad<=0:fail("no_P3_combat_growth");return false
  print("P3_FINAL_GROWTH ",JSON.stringify(sim.hero.snapshot()))
  release();print("FINAL NATURAL_PASS time=",elapsed," rows=",s.node_index," HP=",sim.hero.hp," gold=",s.ledger.model.state.gold," purchased=",purchases," used=",used," route=",route);host.frontdoor_close_run("natural_rebuild");quit();return false
 if elapsed-logged>5:logged=elapsed;print("PROGRESS ",elapsed," ",s.active_node_room," HP=",sim.hero.hp," enemies=",sim.living().size())
 if s.initial_modal_open:
  release()
  if host.initial_hud.hex_draft.visible:host.initial_hud.hex_draft.selected.emit(0)
  return false
 if not native_ready:
  native_ready=true;var audit:=NativeAudit.new();audit.tree=self;root.add_child(audit);sim.combat_event.connect(watch)
  print("P3_NATIVE_READY click passive learn and P3, then F7 for script-assisted actual combat")
 if not proceed:return false
 if int(sim.hero.permanent_ad)!=last_growth:
  last_growth=int(sim.hero.permanent_ad);print("P3_GROWTH_STATE ",s.active_node_room," ",JSON.stringify(sim.hero.snapshot()))
 if not undo_ready and int(sim.hero.credited_kills)==9 and sim.phase=="victory":
  release();hold_for_undo=true;undo_ready=true
  print("P3_NINE_KILLS_NATIVE_READY");audit_state()
 if hold_for_undo:return false
 learn()
 if s.status=="service":release();shop();host.service_continue.pressed.emit();return false
 if s.exit_map_open:
  release()
  if not reopen_checked:
   var before:Vector3=sim.hero.position
   var event:=InputEventKey.new();event.physical_keycode=KEY_M;event.keycode=KEY_M;event.pressed=true
   host._input(event)
   if s.exit_map_open:fail("M_close_failed");return false
   host._input(event)
   if not s.exit_map_open or sim.hero.position!=before:fail("M_reopen_not_stationary");return false
   reopen_checked=true;print("EXIT_REOPEN_REGRESSION_PASS same_position_and_scope")
  var choices:Array=s.available_choices()
  if choices.is_empty():fail("no_choices");return false
  var id:String=str(choices[0].node_id)
  for c in choices:
   if str(c.node_id).ends_with("a") or str(c.node_id)=="r12boss":id=str(c.node_id)
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
