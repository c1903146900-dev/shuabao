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
const EXPECT_CONTINUITY:bool=false
var prep_checked:bool=false
var combat_stage:int=0
var held_start:float=0
var hold_duration:float=0
var held_origin:=Vector3.ZERO
var attack_count:int=0
func shop_key()->void:
 for on in [true,false]:
  var e:=InputEventKey.new();e.physical_keycode=KEY_P;e.keycode=KEY_P;e.pressed=on;host._input(e)
func control_snapshot()->Dictionary:
 return {"movement":host.input_router.movement(),"held":host.input_router._left_physical,"suppressed":host.input_router._held_suppressed,"pending":host.input_router.pending.duplicate(true)}
func watch(event:Dictionary)->void:
 var k:String=str(event.get("kind",""))
 if k=="attack_started":attack_count+=1
 if k.begins_with("q3_"):
  counts[k]=int(counts.get(k,0))+1
  print("Q3_EVENT ",JSON.stringify(event))
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
 if int(s.level)>=7 and int(s.skills.R.rank)==0:choices.append(["R","R2"])
 if int(s.skills.E.rank)==0:choices.append(["E","E1"])
 if int(s.skills.Q.rank)==0:choices.append(["Q","Q3"])
 if int(s.skills.P.rank)==0:choices.append(["P","P2"])
 choices.append_array([["E","E1"],["Q","Q3"],["P","P2"]])
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
 if not watching:host.sim.combat_event.connect(watch);watching=true
 if not host.floor_error.is_empty() or not host.startup_session_error.is_empty():fail("host_fault");return false
 var s=host.shop_session;var sim=host.sim
 if s.status in ["faulted","defeated"]:fail(s.status);return false
 if s.status=="completed":
  release();print("Q3_COUNTS ",JSON.stringify(counts));print("FINAL NATURAL_PASS time=",elapsed," rows=",s.node_index," HP=",sim.hero.hp," gold=",s.ledger.model.state.gold," purchased=",purchases," used=",used," route=",route);host.frontdoor_close_run("natural_rebuild");quit();return false
 if elapsed-logged>5:logged=elapsed;print("PROGRESS ",elapsed," ",s.active_node_room," HP=",sim.hero.hp," enemies=",sim.living().size())
 if s.initial_modal_open:
  release()
  if host.initial_hud.hex_draft.visible:host.initial_hud.hex_draft.selected.emit(0)
  return false
 if not prep_checked and sim.phase=="preparation":
  key(KEY_D,true)
  if host.input_router.movement()==Vector3.ZERO:fail("preparation_movement_not_held");return false
  shop_key()
  if not s.panel_open or not sim.paused or host.input_router.movement()!=Vector3.ZERO or not host.input_router._held_suppressed:fail("accepted_shop_failed_to_suspend");return false
  shop_key()
  if s.panel_open or sim.paused or host.input_router.movement()!=Vector3.ZERO or not host.input_router._held_suppressed:fail("shop_close_failed_release_boundary");return false
  key(KEY_D,false);prep_checked=true
  print("SHOP_ACCEPTED_BOUNDARIES_PASS")
 if sim.phase=="combat":
  if combat_stage==0:
   release();attack_count=0;held_origin=sim.hero.position;held_start=sim.clock.world_time;hold_duration=maxf(1.2,1.0/sim.hero.attack_speed()+.35)
   key(KEY_D,true)
   var mouse:=InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=true;host.input_router.handle_event(mouse,Vector3(0,0,-5),false)
   var before:Dictionary=control_snapshot();shop_key();var after:Dictionary=control_snapshot()
   var preserved:bool=before==after
   print("SHOP_DENIED_CONTINUITY ",JSON.stringify({"before":before,"after":after,"preserved":preserved,"panel_open":s.panel_open,"paused":sim.paused,"notice":host.notice}))
   if s.panel_open or sim.paused or preserved!=EXPECT_CONTINUITY:fail("denial_continuity_mismatch");return false
   combat_stage=1;return false
  if sim.clock.world_time-held_start<hold_duration:return false
  var distance:float=held_origin.distance_to(sim.hero.position)
  print("SHOP_HELD_RESULT distance=",distance," attacks=",attack_count," duration=",hold_duration," control=",JSON.stringify(control_snapshot()))
  if EXPECT_CONTINUITY and (distance<2.0 or attack_count<2):fail("held_actions_not_continued");return false
  if not EXPECT_CONTINUITY and (distance>.2 or attack_count>1):fail("baseline_loss_not_reproduced");return false
  # A real pause remains an input boundary after the rejected shop.
  var pause:=InputEventKey.new();pause.physical_keycode=KEY_SPACE;pause.keycode=KEY_SPACE;pause.pressed=true;host._input(pause)
  if not sim.paused or host.input_router.movement()!=Vector3.ZERO or not host.input_router._held_suppressed:fail("pause_boundary_lost");return false
  print("SHOP_CONTROLS_PASS expected_continuity=",EXPECT_CONTINUITY)
  host.frontdoor_close_run("shop_control_regression");quit();return false
 learn()
 if s.status=="service":release();shop();host.service_continue.pressed.emit();return false
 if s.exit_map_open:
  release();var choices:Array=s.available_choices()
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
