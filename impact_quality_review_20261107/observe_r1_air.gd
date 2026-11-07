extends SceneTree
# One normal R1, learned through the original route/UI. Actual source events only.
# No production/state/clock/guard changes, replay injection, or automatic retry.
const OUTPUT_DIR="/workspace/scratch/73ebae91a474/impact_quality_review_20261107/r1_air_after"
const TOTAL_TIMEOUT:float=200.0
const MAX_PRE:int=20
const MAX_DENSE:int=13
const MAX_VICTORY:int=3
const MAX_IMAGES:int=36
const EPS:float=.00001
var pause_phase:int=0
var pause_wall:float=0
var pause_clocks:Array=[]
var pause_verified:bool=false
var terminal_frames:int=0
var pause_samples:Array=[]
var pause_capture_pending:bool=false
var elapsed:float=0.0
var tick:float=0.0
var entry:Node
var host:Node
var started:bool=false
var watching:bool=false
var failed:bool=false
var finishing:bool=false
var closing:bool=false
var observation_released:bool=false
var shops:Dictionary={}
var route:Array=[]
var purchases:int=0
var used:int=0
var logged:float=0.0
var cast_id:int=-1
var cast_elapsed:float=-1.0
var start_event:Dictionary={}
var release_event:Dictionary={}
var impact_event:Dictionary={}
var impact_elapsed:float=-1.0
var actual_hits:Dictionary={}
var seen_hits:Dictionary={}
var late_bursts_empty:bool=false
var finish_event:Dictionary={}
var victory_event:Dictionary={}
var initial_targets:Array=[]
var kills:Dictionary={}
var other_kills:Array=[]
var first_kill_elapsed:float=-1.0
var last_kill_elapsed:float=-1.0
var victory_elapsed:float=-1.0
var capture_pending:bool=false
var next_pre:float=0.0
var next_dense:float=0.0
var dense_count:int=0
var victory_count:int=0
var pre_reads:int=0
var pre_images:Array[Image]=[]
var pre_frames:Array=[]
var post_images:Array[Image]=[]
var post_frames:Array=[]
var visible_kills:Dictionary={}
var maximum_simultaneous:int=0
var victory_real:float=-1.0
var late_victory_empty:bool=false

func _initialize()->void:
 if DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)!=OK:fail("output_directory_failed");return
 root.add_child(load("res://boot.tscn").instantiate())

func current(event:Dictionary)->bool:
 return not bool(event.get("stale_generation",false)) and str(event.get("run_id",""))==str(host.shop_session.run_id) and str(event.get("room_id",""))==str(host.sim.room_id) and int(event.get("generation",-1))==int(host.sim.encounter_generation) and not host.sim.event_log.is_empty() and host.sim.event_log.back()==event

func watch(event:Dictionary)->void:
 if failed or finishing or closing or not current(event):return
 var kind:String=str(event.get("kind",""))
 if kind=="r1_started":
  if cast_id>0:fail("unexpected_second_r1_no_retry");return
  cast_id=int(event.get("cast_id",-1));start_event=event.duplicate(true);cast_elapsed=elapsed
  release();observation_released=true # Stop ordinary input synchronously at the real start event.
  initial_targets=host.sim.living().map(func(enemy):return str(enemy.actor_id))
  if cast_id<=0 or not event.has_all(["duration","contact_after","real_time"]):fail("r1_start_schema");return
  print("R1_IMPACT_STARTED ",JSON.stringify({"event":event,"initial_targets":initial_targets,"elapsed":elapsed}))
  return
 if cast_id<=0:return
 if str(event.get("run_id",""))!=str(start_event.run_id) or str(event.get("room_id",""))!=str(start_event.room_id) or int(event.get("generation",-1))!=int(start_event.generation):fail("r1_scope_changed");return
 if kind=="encounter_finished":
  if str(event.get("result",""))!="victory":fail("r1_nonvictory_terminal");return
  victory_event=event.duplicate(true);victory_elapsed=elapsed;victory_real=float(event.real_time)
  print("R1_IMPACT_VICTORY ",JSON.stringify(event));return
 if kind=="damage" and int(event.get("cast_id",-1))==cast_id and str(event.get("source",""))=="r1" and float(event.get("amount",0))>0.0:
  actual_hits[int(event.sequence)]=event.duplicate(true)
 if kind=="kill":
  if int(event.get("cast_id",-1))!=cast_id or str(event.get("source","")) not in ["r1","r1_execute"]:
   other_kills.append(event.duplicate(true));return
  var id:String=str(event.get("target",""))
  var enemy:Dictionary=host.sim.enemy_by_id(id)
  if id.is_empty() or kills.has(id) or enemy.is_empty() or not enemy.dead or float(enemy.hp)!=0.0:fail("r1_kill_not_unique_source_dead");return
  if int(event.sequence)<=int(start_event.sequence):fail("r1_kill_before_start");return
  kills[id]=event.duplicate(true);last_kill_elapsed=elapsed
  if first_kill_elapsed<0.0:first_kill_elapsed=elapsed
  print("R1_IMPACT_KILL ",JSON.stringify(event))
  queue_frame("dense")
  return
 if int(event.get("cast_id",-1))!=cast_id:return
 if kind=="r1_release":release_event=event.duplicate(true)
 elif kind=="r1_impact":
  impact_event=event.duplicate(true);impact_elapsed=elapsed;queue_frame("dense")
 elif kind=="r1_finished":finish_event=event.duplicate(true)
 elif kind=="r1_cancelled":fail("observed_r1_cancelled")

func queue_frame(mode:String)->void:
 if capture_pending or failed or finishing:return
 if pre_images.size()+post_images.size()>=MAX_IMAGES:fail("capture_limit_reached");return
 capture_pending=true
 await RenderingServer.frame_post_draw
 capture_pending=false
 if failed or finishing or cast_id<=0 or not is_instance_valid(host):return
 if str(host.sim.room_id)!=str(start_event.room_id) or int(host.sim.encounter_generation)!=int(start_event.generation):fail("capture_left_r1_room");return
 var receipt:Dictionary=host.presentation.receipt
 if not receipt.get("errors",[]).is_empty():fail("visual_receipt_error");return
 var picks:Array=host.presentation.body_pick_regions.map(func(region):return str(region.get("actor_id","")))
 var defeated:Array=receipt.get("enemy_defeat_bodies",[]).duplicate(true)
 var matched:Array=[]
 var seen_in_frame:Dictionary={}
 for id:String in kills:
  var enemy:Dictionary=host.sim.enemy_by_id(id)
  if enemy.is_empty() or not enemy.dead or float(enemy.hp)!=0.0 or id in picks:fail("r1_dead_target_live_or_pickable");return
 for body:Dictionary in defeated:
  var id:String=str(body.get("actor_id",""))
  if not kills.has(id):continue
  if seen_in_frame.has(id) or int(body.get("sequence",-1))!=int(kills[id].sequence):fail("duplicate_or_wrong_kill_remnant");return
  seen_in_frame[id]=true;visible_kills[id]=true;matched.append(body.duplicate(true))
 maximum_simultaneous=maxi(maximum_simultaneous,matched.size())
 if host.sim.phase=="victory":
  if victory_elapsed<0.0:fail("victory_without_source_terminal");return
  if absf(float(host.sim.real_time)-victory_real)>EPS:fail("source_real_advanced_after_victory");return
  if elapsed-victory_elapsed>=.30:late_victory_empty=defeated.is_empty()
 var effective:String=mode
 if mode=="pre" and not impact_event.is_empty():effective="dense"
 if effective=="terminal" and not receipt.get("r1_star_visual",{}).is_empty():fail("star_visual_not_cleared_after_finish");return
 var hit_bursts:Array=receipt.get("default_skill_effects",{}).get("bursts",[]).filter(func(b):return str(b.get("source",""))=="r1" and int(b.get("cast_id",-1))==cast_id)
 for burst:Dictionary in hit_bursts:
  if not actual_hits.has(int(burst.sequence)):fail("burst_without_actual_damage");return
  seen_hits[int(burst.sequence)]=true
 if impact_elapsed>=0.0 and elapsed-impact_elapsed>.22:late_bursts_empty=hit_bursts.is_empty()
 var sample:Dictionary={"label":effective,"elapsed":elapsed,"cast_elapsed":elapsed-cast_elapsed,"since_first_kill":elapsed-first_kill_elapsed if first_kill_elapsed>=0 else -1.0,"since_victory":elapsed-victory_elapsed if victory_elapsed>=0 else -1.0,"real_time":host.sim.real_time,"world_time":host.sim.clock.world_time,"hero_time":host.sim.hero_time,"phase":str(host.sim.phase),"cast_id":cast_id,"kills":kills.keys(),"living_ids":host.sim.living().map(func(enemy):return str(enemy.actor_id)),"pick_ids":picks,"matched_defeat_bodies":matched,"all_defeat_bodies":defeated,"hero_position":host.sim.hero.position,"r1_star_visual":receipt.get("r1_star_visual",{}),"hero_frame":receipt.get("hero_frame",{}),"gold":host.shop_session.ledger.model.state.gold,"source_injected":false,"hit_bursts":hit_bursts,"r1_ground_shapes":receipt.get("default_skill_effects",{}).get("default_skills",[]),"r1_hit_shapes":receipt.get("default_skill_effects",{}).get("r1_hit_shapes",[])}
 var image:Image=root.get_texture().get_image()
 if effective=="pre":
  pre_reads+=1
  if pre_reads>22:fail("precontact_capture_bound");return
  if pre_images.size()>=MAX_PRE:pre_images.pop_front();pre_frames.pop_front()
  pre_images.append(image);pre_frames.append(sample);next_pre=elapsed+.065
 else:
  post_images.append(image);post_frames.append(sample)
  if effective=="dense":dense_count+=1;next_dense=elapsed+.035
  elif effective=="victory":victory_count+=1
  elif effective=="terminal":terminal_frames+=1
 print("R1_IMPACT_FRAME ",JSON.stringify(sample))

func capture_pause_frame()->void:
 if pause_capture_pending or pause_samples.size()>=2:return
 pause_capture_pending=true
 await RenderingServer.frame_post_draw
 pause_capture_pending=false
 if failed or not host.sim.paused:return
 var state:Dictionary=host.presentation.receipt.get("r1_star_visual",{}).duplicate(true)
 if not bool(state.get("active",false)) or not state.has_all(["cast_id","phase","age","draw_position","offset","edge","edge_progress"]):fail("pause_visual_receipt_missing");return
 var sample:Dictionary={"visual":state,"hero_frame":host.presentation.receipt.get("hero_frame",{}).duplicate(true),"real_time":host.sim.real_time}
 if not pause_samples.is_empty():
  for field:String in ["cast_id","phase","age","animation_offset","edge","edge_progress","body_alpha"]:
   if sample.visual.get(field)!=pause_samples[0].visual.get(field):fail("visual_moved_during_normal_pause");return
  var old:Dictionary=pause_samples[0].visual
  var origin:Vector2=state.source_screen_position
  var old_origin:Vector2=old.source_screen_position
  if str(state.get("visual_reference",""))!="screen" or Vector2(state.draw_position).distance_to(Vector2(old.draw_position))>.001:fail("aerial_visual_moved_during_pause");return
  if state.ghosts.size()!=old.ghosts.size():fail("pause_ghost_count_changed");return
  for index:int in range(state.ghosts.size()):
   if Vector2(state.ghosts[index].position).distance_to(Vector2(old.ghosts[index].position))>.001 or state.ghosts[index].alpha!=old.ghosts[index].alpha:fail("aerial_ghost_moved_during_pause");return
  sample["camera_origin_drift"]=origin-old_origin
  if sample.hero_frame!=pause_samples[0].hero_frame:fail("hero_frame_changed_during_normal_pause");return
 root.get_texture().get_image().save_png(OUTPUT_DIR.path_join("pause_%02d.png"%pause_samples.size()))
 pause_samples.append(sample)

func check_normal_pause()->bool:
 if pause_phase==0 and float(host.sim.real_time)-float(start_event.real_time)>=.44:
  var event:=InputEventKey.new();event.physical_keycode=KEY_SPACE;event.keycode=KEY_SPACE;event.pressed=true
  host._input(event);event.pressed=false;host._input(event)
  if not host.sim.paused:fail("normal_pause_not_entered");return true
  pause_wall=elapsed;pause_clocks=[host.sim.real_time,host.sim.clock.world_time,host.sim.hero_time];pause_phase=1
  capture_pause_frame()
  return true
 if pause_phase==1:
  if elapsed-pause_wall>1.0:fail("bounded_pause_capture_timeout");return true
  if absf(host.sim.real_time-pause_clocks[0])>EPS or absf(host.sim.clock.world_time-pause_clocks[1])>EPS or absf(host.sim.hero_time-pause_clocks[2])>EPS:fail("source_clock_advanced_during_pause");return true
  if elapsed-pause_wall>=.25 and pause_samples.size()<2:capture_pause_frame()
  if elapsed-pause_wall>=.30 and pause_samples.size()==2 and not pause_capture_pending:
   var event:=InputEventKey.new();event.physical_keycode=KEY_SPACE;event.keycode=KEY_SPACE;event.pressed=true
   host._input(event);event.pressed=false;host._input(event)
   if host.sim.paused:fail("normal_pause_not_resumed");return true
   pause_phase=2;pause_verified=true
  return true
 return false

func observe_cast()->void:
 if not observation_released:
  release();observation_released=true
 if check_normal_pause():return
 if host.sim.hero.dead:fail("hero_dead_during_r1_observation");return
 if host.sim.paused:fail("unexpected_pause_during_r1_observation");return
 if finish_event.is_empty() and float(host.sim.real_time)-float(start_event.real_time)>float(start_event.duration)+.30:fail("source_r1_finish_missing");return
 if elapsed-cast_elapsed>float(start_event.duration)+2.0:fail("bounded_capture_tail_timeout_no_retry");return
 if impact_event.is_empty():
  if elapsed>=next_pre:queue_frame("pre")
  return
 if dense_count<MAX_DENSE:
  if elapsed>=next_dense:queue_frame("dense")
  return
 # This check observes true R1 impact quality, not a room-clear outcome.
 # End after the authored R1 finishes and real hit visuals have expired.
 if not finish_event.is_empty() and elapsed-impact_elapsed>=.55 and not capture_pending:
  if terminal_frames==0:queue_frame("terminal");return
  finish_review()

func write_evidence(status:String,reason:String)->void:
 var frames:Array=pre_frames+post_frames
 var images:Array[Image]=[]
 images.append_array(pre_images);images.append_array(post_images)
 for index:int in range(images.size()):images[index].save_png(OUTPUT_DIR.path_join("frame_%03d.png"%index))
 var all_initial:bool=true
 for id:String in initial_targets:
  if not kills.has(id):all_initial=false
 var report:Dictionary={"status":status,"reason":reason,"normal_pause_verified":pause_verified,"pause_samples":pause_samples,"terminal_frames":terminal_frames,"actual_positive_hits":actual_hits,"seen_damage_sequences":seen_hits.keys(),"late_bursts_empty":late_bursts_empty,"room_clear_required":false,"elapsed":elapsed,"route":route,"start":start_event,"release":release_event,"impact":impact_event,"r1_finished":finish_event,"victory":victory_event,"initial_targets":initial_targets,"kills":kills,"other_kills":other_kills,"all_starting_enemies_killed_by_this_r1":all_initial and not initial_targets.is_empty(),"maximum_simultaneous_remnants":maximum_simultaneous,"targets_seen_as_remnants":visible_kills.keys(),"late_victory_empty":late_victory_empty,"frames":frames,"source_injected":false,"automatic_retry":false,"full_floor":false,"OS_input":false}
 var file:=FileAccess.open(OUTPUT_DIR.path_join("receipt.json"),FileAccess.WRITE)
 if file!=null:file.store_string(JSON.stringify(report,"  "));file.close()
 print("R1_IMPACT_RESULT ",JSON.stringify(report))

func fail(reason:String)->void:
 if failed or finishing:return
 failed=true
 write_evidence("failed",reason)
 quit(9)

func finish_review()->void:
 if failed or finishing:return
 if not pause_verified:fail("normal_pause_not_verified");return
 var edges:Dictionary={};var hold_seen:bool=false
 for sample:Dictionary in pre_frames+post_frames:
  var visual:Dictionary=sample.r1_star_visual
  var age:float=float(sample.real_time)-float(start_event.real_time)
  if age<float(start_event.duration)-EPS:
   if Vector3(sample.hero_position).distance_to(Vector3(start_event.position))>EPS:fail("source_hero_position_changed");return
   if not bool(visual.get("active",false)):fail("star_inactive_during_source_cast");return
  if age<1.05 and absf((float(sample.world_time)-float(start_event.world_time))-.20*age)>.0001:fail("source_slow_world_ratio_changed");return
  if not bool(visual.get("active",false)):continue
  if absf(float(visual.age)-(float(sample.real_time)-float(start_event.real_time)))>EPS:fail("star_age_not_source_real_time");return
  if str(visual.phase)=="star_travel":
   var edge:int=int(visual.edge);edges[edge]=true
   var points:PackedVector2Array=visual.layout.vertices
   if Vector2(visual.animation_offset).distance_to(points[edge].lerp(points[edge+1],float(visual.edge_progress)))>.001:fail("visual_not_on_connected_star_edge");return
  if str(visual.phase)=="hold":
   if Vector2(visual.offset).length()>EPS or bool(visual.travelling):fail("hold_not_at_real_anchor");return
   hold_seen=true
 for edge:int in range(5):
  if not edges.has(edge):fail("missing_observed_star_edge:"+str(edge));return
 if not hold_seen:fail("missing_observed_hold");return
 if absf(float(release_event.real_time)-float(start_event.real_time)-float(start_event.contact_after))>.021:fail("real_release_timing_changed");return
 if start_event.is_empty() or release_event.is_empty() or impact_event.is_empty() or finish_event.is_empty():fail("incomplete_actual_r1_event_chain");return
 if pre_frames.is_empty() or not late_bursts_empty:fail("missing_preframes_or_unexpired_hit_bursts");return
 for id:String in kills:
  if id not in impact_event.get("target_ids",[]) or int(kills[id].sequence)<=int(release_event.sequence) or int(kills[id].sequence)>=int(impact_event.sequence):fail("kill_not_owned_by_real_r1_impact");return
  if not visible_kills.has(id):fail("actual_r1_kill_missing_rendered_remnant");return
 if seen_hits.size()!=actual_hits.size():fail("actual_damage_missing_visual_burst");return
 release();closing=true
 if not host.frontdoor_close_run("r1_impact_visual_review"):fail("normal_close_rejected");return
 finishing=true;write_evidence("passed","");quit(0)

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
 if s.status=="completed":fail("floor_ended_without_observed_r1");return
 if elapsed-logged>5:logged=elapsed;print("PROGRESS ",elapsed," ",s.active_node_room," HP=",sim.hero.hp," enemies=",sim.living().size())
 if s.initial_modal_open:
  release()
  if host.initial_hud.hex_draft.visible:host.initial_hud.hex_draft.selected.emit(0)
  return
 learn()
 if s.status=="service":release();shop();host.service_continue.pressed.emit();return
 if s.exit_map_open:
  release();var choices:Array=s.available_choices()
  if choices.is_empty():fail("no_choices");return
  var id:String=str(choices[0].node_id)
  for c in choices:
   if str(c.node_id).ends_with("a") or str(c.node_id)=="r12boss":id=str(c.node_id)
  if host.route_map.buttons[id].disabled:fail("disabled_choice");return
  host.route_map.buttons[id].pressed.emit();route.append(id);return
 if sim.phase in ["preparation","victory"]:shop();walk(Vector3(0,0,-11));return
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
 if cast_id>0:return # The real r1_started callback now owns the observation.
 var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
 if distance<2.4:host.input_router.handle_event(event,aim,false)
 event.pressed=false;host.input_router.handle_event(event,aim,false)
 return

func _process(dt:float)->bool:
 if failed or finishing:return false
 elapsed+=dt;tick+=dt
 if elapsed>TOTAL_TIMEOUT:fail("total_timeout_no_retry");return false
 if cast_id>0:observe_cast();return false
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
