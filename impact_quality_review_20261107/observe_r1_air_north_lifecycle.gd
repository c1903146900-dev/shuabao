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
var capture_start:float=-1
var capture_at:float=0
var frames:int=0
var buffered:Array[Image]=[]
const CLOSE_AGE:float=.25
var lifecycle:int=0
var north_ready:bool=false
var closing_host:Node
var closing_sim:Node
var old_cast:int=-1
var old_run:String=""
var closed_clean:bool=false
func _closed(event:Dictionary)->void:
 if str(event.get("kind",""))!="encounter_finished":return
 closed_clean=not closing_sim.r1_active and closing_sim._presentation.is_empty() and not closing_sim.hero.cast_state.has("r1") and not closing_sim.cast_is_current(old_cast) and closing_sim.pending.is_empty() and closing_sim.wind_projectiles.is_empty() and closing_host.presentation.animation.is_empty() and closing_host.presentation.default_effects.r1_star.cast_id==-1 and closing_host.presentation.default_effects.r1_star.layout.is_empty()
 print("LIFECYCLE_OLD_CLOSED clean=",closed_clean," result=",event.get("result",""))
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
 if lifecycle>0:
  if elapsed>200:fail("lifecycle_timeout");return false
  if lifecycle==1 and entry.screen==entry.Screen.MENU:
   entry._start.pressed.emit();lifecycle=2
  elif lifecycle==2 and entry.screen==entry.Screen.CONFIRM:
   entry._confirm.pressed.emit();lifecycle=3
  elif lifecycle==3 and entry.screen==entry.Screen.RUN and entry.active_room!=null:
   var fresh:Node=entry.active_room
   var clean:bool=closed_clean and fresh.shop_session.run_id!=old_run and fresh.presentation.animation.is_empty() and fresh.sim.wind_projectiles.is_empty() and fresh.presentation.default_effects.r1_star.cast_id==-1 and fresh.presentation.default_effects.r1_star.layout.is_empty() and fresh.presentation.receipt.get("r1_star_visual",{}).is_empty()
   print("LIFECYCLE_NEW_RUN clean=",clean," closed=",closed_clean)
   fresh.frontdoor_close_run("r1_lifecycle_check")
   quit(0 if clean else 9)
  return false
 if host!=null and str(host.presentation.animation.get("kind",""))=="r1_started":
  var age:float=host.sim.real_time-float(host.presentation.animation.real_time)
  if age>=CLOSE_AGE:
   var visual:Dictionary=host.presentation.receipt.get("r1_star_visual",{})
   if not bool(visual.get("active",false)) or Vector2(visual.get("offset",Vector2.ZERO)).length()<1:fail("no_actual_displaced_star_before_close");return false
   print("STAR_BEFORE_REAL_CLOSE ",JSON.stringify(visual))
   DirAccess.make_dir_recursive_absolute("/workspace/scratch/73ebae91a474/impact_quality_review_20261107/r1_air_north_lifecycle")
   root.get_texture().get_image().save_png("/workspace/scratch/73ebae91a474/impact_quality_review_20261107/r1_air_north_lifecycle/before_close.png")
   print("R1_IMMUNITY damage=",host.sim.hero_damage_immune()," control=",host.sim.hero_control_immune())
   press(KEY_SHIFT,host.sim.hero.position+host.sim.hero.facing*5)
   print("R1_AFTER_SHIFT active=",host.sim.r1_active," animation=",host.presentation.animation.get("kind",""))
   if not host.sim.r1_active or str(host.presentation.animation.get("kind",""))!="r1_started":fail("shift_unexpectedly_cancelled_r1");return false
   closing_host=host;closing_sim=host.sim;old_cast=int(host.presentation.animation.cast_id);old_run=host.shop_session.run_id
   print("LIFECYCLE_BEFORE age=",age," current=",closing_sim.cast_is_current(old_cast)," waves=",closing_sim.wind_projectiles.size()," pending=",closing_sim.pending.size())
   closing_sim.combat_event.connect(_closed)
   entry._pause.pressed.emit();lifecycle=1
   return false
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
  fail("floor_completed_without_target_lifecycle");return false
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
   if str(c.node_id).ends_with("a") or str(c.node_id)=="r12boss":id=str(c.node_id)
  if host.route_map.buttons[id].disabled:fail("disabled_choice");return false
  host.route_map.buttons[id].pressed.emit();route.append(id);return false
 if sim.phase in ["preparation","victory"]:shop();walk(Vector3(0,0,-11));return false
 if sim.phase!="combat":return false
 if int(s.ledger.model.state.skills.R.rank)>0 and not north_ready:
  var destination:=Vector3(0,0,-10.5)
  if sim.hero.position.distance_to(destination)>.30:
   walk(destination,.20)
   return false
  release();north_ready=true
  print("NORTH_R1_ACTUAL_ORIGIN ",sim.hero.position)
  press(KEY_R,sim.hero.position+sim.hero.facing*5)
  return false
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
