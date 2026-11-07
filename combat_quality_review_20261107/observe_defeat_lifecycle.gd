extends SceneTree
# Read-only lifecycle observation around one actual first-room minion kill.
# Uses normal route inputs and actual menu buttons. No source-state injection,
# presentation-state writes, fake kill, clock change, or guard alteration.
# Menu disables the tree: retained invisible remnants are expected, not failure.
const OUTPUT_DIR="/workspace/scratch/73ebae91a474/combat_quality_review_20261107/defeat_lifecycle"
const TOTAL_TIMEOUT:float=65.0
const LIFECYCLE_TIMEOUT:float=20.0
const MAX_CAPTURES:int=7
const EPS:float=.00001
var elapsed:float=0.0
var tick:float=0.0
var entry:Node
var host:Node
var started:bool=false
var watching:bool=false
var failed:bool=false
var finishing:bool=false
var stage:String="route"
var stage_since:float=0.0
var lifecycle_since:float=-1.0
var target_id:String=""
var kill_event:Dictionary={}
var terminal:Dictionary={}
var old_ids:Dictionary={}
var old_refs:Dictionary={}
var paused_source:Dictionary={}
var paused_body:Dictionary={}
var paused_terminal_tail:float=0.0
var paused_age:float=0.0
var menu_number:int=0
var capture_pending:bool=false
var captures:Dictionary={}
var images:Dictionary={}
var facts:Dictionary={}
var fresh_frames:int=0
var resume_attempts:int=0
var shops:Dictionary={}
var route:Array=[]
var purchases:int=0
var used:int=0
var logged:float=0.0

func _initialize()->void:
 if DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)!=OK:fail("output_directory_failed");return
 root.add_child(load("res://boot.tscn").instantiate())

func fail(reason:String)->void:
 if failed or finishing:return
 failed=true
 print("DEFEAT_LIFECYCLE_FAIL ",JSON.stringify({"reason":reason,"stage":stage,"elapsed":elapsed,"kill":kill_event,"terminal":terminal,"facts":facts,"captures":captures,"source_injected":false}))
 quit(9)

func set_stage(value:String)->void:
 stage=value;stage_since=elapsed

func identity()->Dictionary:
 return {"host":host.get_instance_id(),"sim":host.sim.get_instance_id(),"session":host.shop_session.get_instance_id(),"presentation":host.presentation.get_instance_id(),"defeat_helper":host.presentation.enemy_defeat.get_instance_id(),"run":str(host.shop_session.run_id),"room":str(host.sim.room_id),"generation":int(host.sim.encounter_generation)}

func source_state()->Dictionary:
 var target:Dictionary=host.sim.enemy_by_id(target_id)
 return {"real_time":host.sim.real_time,"world_time":host.sim.clock.world_time,"hero_time":host.sim.hero_time,"sequence":host.sim.sequence,"phase":str(host.sim.phase),"status":str(host.shop_session.status),"hero_position":host.sim.hero.position,"hero_hp":host.sim.hero.hp,"gold":host.shop_session.ledger.model.state.gold,"target_dead":target.get("dead",false),"target_hp":target.get("hp",-1.0)}

func target_receipt()->Dictionary:
 for body:Dictionary in host.presentation.receipt.get("enemy_defeat_bodies",[]):
  if str(body.get("actor_id",""))==target_id and int(body.get("sequence",-1))==int(kill_event.sequence):return body.duplicate(true)
 return {}

func save_capture(label:String,detail:Dictionary)->void:
 if captures.has(label) or captures.size()>=MAX_CAPTURES:fail("capture_bound_or_duplicate");return
 captures[label]=detail.duplicate(true);images[label]=root.get_texture().get_image()
 print("DEFEAT_LIFECYCLE_CAPTURE ",label," ",JSON.stringify(detail))

func watch(event:Dictionary)->void:
 if failed or finishing:return
 var kind:String=str(event.get("kind",""))
 if kind=="encounter_finished" and stage=="new_run_transition":
  if str(event.get("result",""))!="host_closed" or not terminal.is_empty():fail("unexpected_close_terminal");return
  terminal=event.duplicate(true)
  facts["old_status_at_close"]=str(host.shop_session.status)
  facts["old_remnant_count_at_close"]=host.presentation.enemy_defeat.bodies.size()
  # The old disabled helper may retain its inert data until actual tree free.
  # Do not misclassify that as gameplay continuation or require a fake clear.
  if str(host.shop_session.status)!="aborted":fail("close_did_not_abort_old_session")
  return
 if stage!="route" or kind!="kill" or str(event.get("enemy_kind",""))!="minion":return
 if host.sim.event_log.is_empty() or host.sim.event_log.back()!=event:return
 if bool(event.get("stale_generation",false)) or str(event.get("run_id",""))!=str(host.shop_session.run_id):return
 target_id=str(event.target);kill_event=event.duplicate(true)
 lifecycle_since=elapsed;set_stage("kill_capture")
 print("DEFEAT_LIFECYCLE_ACTUAL_KILL ",JSON.stringify(kill_event))
 capture_active(false)

func capture_active(resuming:bool)->void:
 if capture_pending or failed:return
 capture_pending=true
 await RenderingServer.frame_post_draw
 capture_pending=false
 if failed or finishing:return
 if stage!=("resume_capture" if resuming else "kill_capture"):return
 if not is_instance_valid(host) or host.sim.hero.dead or host.sim.phase!="combat":fail("active_source_not_combat");return
 var body:Dictionary=target_receipt()
 if body.is_empty():
  if resuming and resume_attempts<3:
   resume_attempts+=1;return
  fail("actual_remnant_not_visible_in_capture_window");return
 if absf(float(host.presentation.receipt.get("real_time",-1.0))-float(host.sim.real_time))>EPS:fail("stale_postdraw_receipt");return
 var enemy:Dictionary=host.sim.enemy_by_id(target_id)
 var picks:Array=host.presentation.body_pick_regions.map(func(region):return str(region.get("actor_id","")))
 if enemy.is_empty() or not enemy.dead or float(enemy.hp)!=0.0 or target_id in picks:fail("dead_target_still_live_or_pickable");return
 if not host.presentation.receipt.get("errors",[]).is_empty():fail("visual_receipt_error");return
 if float(body.age)<0.0 or float(body.age)>=.22:fail("remnant_outside_lifetime");return
 if resuming:
  if identity()!=old_ids:fail("resume_changed_run_or_owners");return
  if host.sim.paused or not host.visible or entry.screen!=entry.Screen.RUN:fail("resume_did_not_restore_run");return
  if float(host.sim.real_time)<=float(paused_source.real_time)+EPS or float(body.age)<=paused_age+EPS:
   if resume_attempts<3:resume_attempts+=1;return
   fail("same_run_clock_did_not_resume");return
  facts["same_run_resumed"]=true
 else:
  old_ids=identity()
  old_refs={"host":weakref(host),"sim":weakref(host.sim),"session":weakref(host.shop_session),"presentation":weakref(host.presentation),"defeat_helper":weakref(host.presentation.enemy_defeat)}
 save_capture("resumed_remnant" if resuming else "actual_kill_remnant",{"identity":identity(),"source":source_state(),"body":body,"pick_ids":picks,"source_dead":true,"source_injected":false})
 if failed:return
 # Suspend from the actual postdraw remnant, not a later .12s route tick.
 release();menu_number=2 if resuming else 1
 if entry.screen!=entry.Screen.RUN or not entry._pause.visible or entry._pause.disabled or not host.frontdoor_can_suspend():fail("normal_menu_button_unavailable");return
 set_stage("menu_opening");entry._pause.pressed.emit()

func pause_intact()->bool:
 if not is_instance_valid(host) or entry.active_room!=host or identity()!=old_ids:fail("menu_changed_old_owners");return false
 if not host.sim.paused or host.visible or host.process_mode!=Node.PROCESS_MODE_DISABLED:fail("menu_not_hidden_and_disabled");return false
 if host.sim.phase!="combat" or str(host.shop_session.status)!="combat":fail("menu_ended_combat");return false
 var stored:Dictionary=host.presentation.enemy_defeat.bodies.get(target_id,{})
 if stored.is_empty() or int(stored.get("sequence",-1))!=int(kill_event.sequence):fail("menu_discarded_expected_remnant");return false
 if not paused_source.is_empty():
  if source_state()!=paused_source or stored!=paused_body or float(host.presentation.enemy_defeat.terminal_elapsed)!=paused_terminal_tail:fail("disabled_tree_advanced_source_or_remnant");return false
 return true

func capture_menu()->void:
 if capture_pending:return
 capture_pending=true
 await RenderingServer.frame_post_draw
 capture_pending=false
 if failed or stage!="menu_hold" or not pause_intact():return
 save_capture("menu%d_paused"%menu_number,{"identity":identity(),"source":paused_source,"body_age":paused_age,"room_hidden":not host.visible,"tree_disabled":host.process_mode==Node.PROCESS_MODE_DISABLED,"same_kill_retained":true,"menu_pauses_not_clears":true})

func capture_confirmation()->void:
 if capture_pending:return
 capture_pending=true
 await RenderingServer.frame_post_draw
 capture_pending=false
 if failed or stage!="confirm_new_run" or entry.screen!=entry.Screen.CONFIRM or not pause_intact():return
 save_capture("new_run_confirmation",{"old_identity":identity(),"source_still_frozen":source_state()==paused_source,"same_kill_retained":host.presentation.enemy_defeat.bodies.has(target_id),"actual_start_button_used":true})

func capture_fresh()->void:
 if capture_pending:return
 capture_pending=true
 await RenderingServer.frame_post_draw
 capture_pending=false
 if failed or stage!="fresh_run":return
 var fresh:Node=entry.active_room
 if not is_instance_valid(fresh) or entry.screen!=entry.Screen.RUN:fail("fresh_run_unavailable");return
 if not str(fresh.floor_error).is_empty() or not str(fresh.startup_session_error).is_empty():fail("fresh_run_fault");return
 for name:String in old_refs:
  if old_refs[name].get_ref()!=null:fail("old_owner_or_helper_not_freed_"+name);return
 if str(fresh.shop_session.run_id)==str(old_ids.run) or fresh.get_instance_id()==int(old_ids.host):fail("new_run_reused_old_identity");return
 var helper=fresh.presentation.enemy_defeat
 if not helper.frames.is_empty() or not helper.bodies.is_empty() or not helper.seen.is_empty() or not fresh.presentation.receipt.get("enemy_defeat_bodies",[]).is_empty():fail("new_run_inherited_old_remnant_data");return
 if int(fresh.sim.encounter_generation)!=0 or fresh.sim.phase!="preparation":fail("new_run_not_initial_preparation");return
 if not fresh.presentation.receipt.get("errors",[]).is_empty():fail("fresh_visual_error");return
 fresh_frames+=1
 if fresh_frames==1 or fresh_frames==3:
  save_capture("fresh_initial" if fresh_frames==1 else "fresh_stable",{"run":str(fresh.shop_session.run_id),"host_id":fresh.get_instance_id(),"sim_id":fresh.sim.get_instance_id(),"helper_id":helper.get_instance_id(),"generation":fresh.sim.encounter_generation,"phase":fresh.sim.phase,"cache_empty":true,"old_owner_refs_released":true,"fresh_frame":fresh_frames})
 if fresh_frames>=3:finish_review(fresh)

func lifecycle_step()->void:
 if elapsed-lifecycle_since>LIFECYCLE_TIMEOUT:fail("lifecycle_timeout");return
 if entry.screen==entry.Screen.FAULT:fail("entry_fault");return
 if stage=="kill_capture":return
 if stage=="menu_opening":
  if entry.screen==entry.Screen.RUN:fail("menu_open_rejected");return
  if entry.screen==entry.Screen.MENU:
   paused_source.clear();paused_body.clear()
   if not pause_intact():return
   paused_source=source_state();paused_body=host.presentation.enemy_defeat.bodies[target_id].duplicate(true)
   paused_terminal_tail=float(host.presentation.enemy_defeat.terminal_elapsed)
   paused_age=float(host.sim.real_time)-float(paused_body.real_time)+paused_terminal_tail
   if paused_age<0.0 or paused_age>=.22:fail("remnant_expired_before_menu");return
   set_stage("menu_hold");capture_menu()
 elif stage=="menu_hold":
  if entry.screen!=entry.Screen.MENU or not pause_intact():return
  if elapsed-stage_since<.30 or not captures.has("menu%d_paused"%menu_number):return
  if menu_number==1:
   facts["pause_preserved_source_and_remnant"]=true
   if entry._resume.disabled or not entry._resume.visible:fail("resume_button_unavailable");return
   set_stage("resume_capture");entry._resume.pressed.emit()
  else:
   facts["second_pause_retained_same_kill"]=true
   if entry._start.disabled or not entry._start.visible:fail("start_button_unavailable");return
   set_stage("confirm_new_run");entry._start.pressed.emit();capture_confirmation()
 elif stage=="resume_capture":
  if entry.screen==entry.Screen.MENU:fail("resume_rejected");return
  if entry.screen==entry.Screen.RUN and not capture_pending:capture_active(true)
 elif stage=="confirm_new_run":
  if entry.screen!=entry.Screen.CONFIRM:fail("actual_confirmation_missing");return
  if not pause_intact() or not captures.has("new_run_confirmation"):return
  if entry._confirm.disabled or not entry._confirm.visible:fail("confirm_button_unavailable");return
  set_stage("new_run_transition");entry._confirm.pressed.emit()
 elif stage=="new_run_transition":
  if entry.screen==entry.Screen.MENU:fail("new_run_recovered_to_old_menu");return
  if entry.screen==entry.Screen.RUN and is_instance_valid(entry.active_room):
   if terminal.is_empty() or str(facts.get("old_status_at_close",""))!="aborted":fail("new_run_missing_old_close");return
   set_stage("fresh_run")
 elif stage=="fresh_run":capture_fresh()

func finish_review(fresh:Node)->void:
 if failed or finishing:return
 if not captures.has_all(["actual_kill_remnant","menu1_paused","resumed_remnant","menu2_paused","new_run_confirmation","fresh_initial","fresh_stable"]):fail("incomplete_capture_coverage");return
 if not fresh.frontdoor_close_run("defeat_lifecycle_review"):fail("fresh_close_rejected");return
 finishing=true
 for label:String in images:images[label].save_png(OUTPUT_DIR.path_join(label+".png"))
 var report:Dictionary={"status":"passed","kill":kill_event,"terminal":terminal,"facts":facts,"captures":captures,"same_run_pause_resume":true,"real_start_confirm_new_run":true,"fresh_postdraw_frames":fresh_frames,"source_injected":false,"full_floor":false,"OS_input":false,"expiry_tested_here":false}
 var file:=FileAccess.open(OUTPUT_DIR.path_join("receipt.json"),FileAccess.WRITE)
 if file==null:print("DEFEAT_LIFECYCLE_FAIL output_receipt_open");quit(9);return
 file.store_string(JSON.stringify(report,"  "));file.close()
 print("DEFEAT_LIFECYCLE_PASS ",JSON.stringify(report))
 quit(0)

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

func normal_route_tick()->void:
 var s=host.shop_session;var sim=host.sim
 if s.status in ["faulted","defeated"]:fail(s.status);return
 if s.status in ["completed","aborted"]:fail("unexpected_route_terminal");return
 if elapsed-logged>5:logged=elapsed;print("PROGRESS ",elapsed," ",s.active_node_room," HP=",sim.hero.hp," enemies=",sim.living().size())
 if s.initial_modal_open:
  release()
  if host.initial_hud.hex_draft.visible:host.initial_hud.hex_draft.selected.emit(0)
  return
 learn()
 if s.status=="service":fail("left_first_room_before_lifecycle");return
 if s.exit_map_open:
  # The initial preparation area must use this real map to enter room one.
  # Once an encounter has begun, the same map would leave the bounded test.
  if sim.phase!="preparation" or int(sim.encounter_generation)!=0 or not route.is_empty():fail("left_first_room_before_lifecycle");return
  release();var choices:Array=s.available_choices()
  if choices.is_empty():fail("initial_route_no_choices");return
  var id:String=str(choices[0].node_id)
  for choice:Dictionary in choices:
   if str(choice.node_id).ends_with("b"):id=str(choice.node_id)
  if not id.begins_with("r01") or not host.route_map.buttons.has(id) or host.route_map.buttons[id].disabled:fail("initial_first_room_choice_unavailable");return
  host.route_map.buttons[id].pressed.emit();route.append(id);return
 if sim.phase=="victory":fail("first_room_finished_without_lifecycle");return
 if sim.phase=="preparation":shop();walk(Vector3(0,0,-11));return
 if sim.phase!="combat":return
 var live:Array=sim.living()
 if live.is_empty():release();return
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
 return

func _process(dt:float)->bool:
 if failed or finishing:return false
 elapsed+=dt;tick+=dt
 if elapsed>TOTAL_TIMEOUT:fail("total_timeout");return false
 if lifecycle_since>=0.0:lifecycle_step();return false
 if entry==null:
  var boot:Node=root.get_node_or_null("Boot")
  if boot!=null:
   for child in boot.get_children():
    if child.get("screen")!=null:entry=child
  return false
 if not started:
  if entry.screen==entry.Screen.MENU and not entry._start.disabled:entry._start.pressed.emit();started=true
  return false
 host=entry.active_room
 if host==null:return false
 if not watching:host.sim.combat_event.connect(watch);watching=true
 if not str(host.floor_error).is_empty() or not str(host.startup_session_error).is_empty():fail("host_fault");return false
 if tick<.12:return false
 tick=0.0;normal_route_tick()
 return false
