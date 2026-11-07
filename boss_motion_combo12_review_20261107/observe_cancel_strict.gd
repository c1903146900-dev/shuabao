extends SceneTree
# Isolated observer: normal UI/input only; no production state writes or restore.
# Narrow pass: first Boss B warning cancelled by actual H08/E1 contact, then one
# actual sweep release and visual settle. NOT a full-floor win, OS-input pass,
# two-direction check, wave-release check or active-release/new-run lifecycle test.
const TOTAL_TIMEOUT:float=550.0
const BOSS_TIMEOUT:float=45.0
const CAPTURE_LIMIT:int=5
const EPS:float=.00001
var elapsed:float=0.0
var tick:float=0.0
var entry:Node
var host:Node
var started:bool=false
var watching:bool=false
var failed:bool=false
var draft_step:int=0
var h08_selected:bool=false
var shops:Dictionary={}
var route:Array=[]
var last_progress_room:String=""
var boss_start:float=-1.0
var boss_run:String=""
var boss_room:String=""
var boss_generation:int=-1
var boss_id:String=""
var boss_scope:String=""
var stage:String="route"
var chain:Dictionary={}
var expected_e:bool=false
var e_attempted:bool=false
var e_cast:int=-1
var cancel_at:float=-1.0
var neutral_last:float=-1.0
var neutral_samples:int=0
var sweep_warning:Dictionary={}
var sweep_impact:Dictionary={}
var dodge_target:Vector3=Vector3.INF
var release_samples:int=0
var release_last:float=-1.0
var capture_pending:bool=false
var captures:Dictionary={}
var capture_attempts:Dictionary={}
var output_dir:String=""
var exit_started:float=-1.0

func _initialize()->void:
 root.add_child(load("res://boot.tscn").instantiate())

func fail(reason:String)->void:
 if failed:return
 failed=true
 print("STRICT_BOSS_FAIL ",JSON.stringify({"reason":reason,"stage":stage,"elapsed":elapsed,"route":route,"e_cast":e_cast,"chain":chain,"sweep_warning":sweep_warning,"sweep_impact":sweep_impact,"neutral_samples":neutral_samples,"release_samples":release_samples,"captures":captures.keys(),"new_run_lifecycle_tested":false}))
 quit(9)

func key(code:int,on:bool,aim:Vector3=Vector3.INF)->Dictionary:
 var event:=InputEventKey.new()
 event.physical_keycode=code;event.keycode=code;event.pressed=on
 return host.input_router.handle_event(event,aim,host._blocked())

func press(code:int,aim:Vector3=Vector3.INF)->Dictionary:
 var result:Dictionary=key(code,true,aim)
 key(code,false,aim)
 return result

func release()->void:
 for code:int in [KEY_W,KEY_A,KEY_S,KEY_D]:key(code,false)
 var event:=InputEventMouseButton.new()
 event.button_index=MOUSE_BUTTON_LEFT;event.pressed=false
 host.input_router.handle_event(event)

func walk(target:Vector3,stop:float=.15)->void:
 var origin:Vector3=host.sim.hero.position
 if origin.distance_to(target)<stop:
  for code:int in [KEY_W,KEY_A,KEY_S,KEY_D]:key(code,false)
  return
 var best:=Vector3.ZERO
 var score:float=-INF
 for direction:Vector3 in [Vector3(0,0,-1),Vector3(1,0,-1).normalized(),Vector3(1,0,0),Vector3(1,0,1).normalized(),Vector3(0,0,1),Vector3(-1,0,1).normalized(),Vector3(-1,0,0),Vector3(-1,0,-1).normalized()]:
  # Read-only geometry query; all actual displacement still comes from keys.
  var clipped:Vector3=host.sim._move_clipped(origin,origin+direction*.7,host.sim.hero_radius)
  var value:float=origin.distance_to(target)-clipped.distance_to(target)
  if clipped.distance_to(origin)<.05:value-=10.0
  if value>score:score=value;best=direction
 key(KEY_W,best.z<-.2,target);key(KEY_S,best.z>.2,target)
 key(KEY_A,best.x<-.2,target);key(KEY_D,best.x>.2,target)

func compact(event:Dictionary)->Dictionary:
 var result:Dictionary={}
 for field:String in ["kind","sequence","run_id","room_id","generation","world_time","actor_id","enemy_kind","boss_cast_id","boss_scope","cast_id","target","target_id","source","amount","control","duration","reason","shape","direction","hit"]:
  if event.has(field):result[field]=event[field]
 return result

func current_event(event:Dictionary)->bool:
 return not bool(event.get("stale_generation",false)) and str(event.get("run_id",""))==boss_run and str(event.get("room_id",""))==boss_room and int(event.get("generation",-1))==boss_generation and event.has_all(["sequence","world_time"])

func remember(label:String,event:Dictionary)->void:
 if chain.has(label):fail("duplicate_evidence_"+label);return
 chain[label]=compact(event)
 print("STRICT_BOSS_EVENT ",label," ",JSON.stringify(chain[label]))

func _watch(event:Dictionary)->void:
 if failed or stage=="menu_exit" or boss_start<0.0 or not current_event(event):return
 var kind:String=str(event.get("kind",""))
 var owner:bool=str(event.get("enemy_kind",""))=="boss" and str(event.get("actor_id",""))==boss_id
 var sequence:int=int(event.sequence)
 if kind=="encounter_finished":fail("encounter_ended_before_narrow_check");return
 if owner and kind=="enemy_warning":
  if not chain.has("warning"):
   if str(event.get("shape",""))!="boss_wave_line" or str(event.get("boss_cast_id","")).is_empty():fail("first_boss_warning_not_wave");return
   remember("warning",event);stage="cancel_warning"
  elif stage in ["approach","cancel_warning","cancel_contact","cancel_neutral"]:
   fail("new_warning_before_cancel_verified")
  elif stage=="await_sweep":
   if not sweep_warning.is_empty() or str(event.get("shape",""))!="cone":fail("expected_one_authentic_sweep_warning");return
   sweep_warning=compact(event)
   print("STRICT_BOSS_EVENT sweep_warning ",JSON.stringify(sweep_warning))
   var direction:Vector3=event.get("direction",Vector3.ZERO)
   if not direction.is_finite() or direction.length_squared()<EPS:fail("invalid_sweep_direction");return
   var side:=Vector3(-direction.z,0,direction.x).normalized()
   var origin:Vector3=host.sim.hero.position
   var left:Vector3=host.sim._move_clipped(origin,origin+side*3.6,host.sim.hero_radius)
   var right:Vector3=host.sim._move_clipped(origin,origin-side*3.6,host.sim.hero_radius)
   dodge_target=left if left.distance_to(origin)>=right.distance_to(origin) else right
   stage="sweep_warning"
  else:fail("unexpected_additional_boss_warning")
  return
 if owner and kind=="boss_wave_released" and chain.has("warning") and str(event.get("boss_cast_id",""))==str(chain.warning.boss_cast_id):
  fail("cancel_target_wave_released");return
 if kind=="e1_started" and expected_e:
  if not chain.has("warning") or sequence<=int(chain.warning.sequence) or str(event.get("target_id",""))!=boss_id:fail("wrong_e1_start");return
  e_cast=int(event.get("cast_id",-1))
  if e_cast<0:fail("e1_cast_identity_missing");return
  remember("e1_started",event);return
 if kind=="damage" and str(event.get("source",""))=="e1_dagger" and str(event.get("target",""))==boss_id:
  if e_cast<0 or int(event.get("cast_id",-2))!=e_cast or sequence<=int(chain.get("e1_started",{}).get("sequence",-1)) or float(event.get("amount",0.0))<=0.0:fail("uncorrelated_dagger_damage");return
  remember("dagger_damage",event);return
 if kind=="enemy_control" and str(event.get("target",""))==boss_id and str(event.get("control",""))=="stun":
  if not chain.has("dagger_damage") or sequence<=int(chain.dagger_damage.sequence) or absf(float(event.world_time)-float(chain.dagger_damage.world_time))>EPS or float(event.get("duration",0.0))<=0.0:fail("uncorrelated_boss_stun");return
  remember("stun",event);return
 if kind=="e1_marked" and str(event.get("target_id",""))==boss_id:
  if not chain.has("stun") or int(event.get("cast_id",-2))!=e_cast or sequence<=int(chain.stun.sequence) or absf(float(event.world_time)-float(chain.stun.world_time))>EPS:fail("uncorrelated_e1_mark");return
  remember("mark",event);return
 if owner and kind=="boss_wave_cancelled":
  if not chain.has_all(["warning","e1_started","dagger_damage","stun","mark"]) or str(event.get("boss_cast_id",""))!=str(chain.warning.boss_cast_id) or str(event.get("reason",""))!="crowd_control" or sequence<=int(chain.mark.sequence) or absf(float(event.world_time)-float(chain.mark.world_time))>EPS:fail("uncorrelated_wave_cancel");return
  remember("wave_cancel",event);return
 if owner and kind=="enemy_attack_cancelled":
  if not chain.has("wave_cancel") or str(event.get("reason",""))!="crowd_control" or sequence<=int(chain.wave_cancel.sequence) or absf(float(event.world_time)-float(chain.wave_cancel.world_time))>EPS:fail("generic_cancel_is_not_proof");return
  remember("attack_cancel",event)
  cancel_at=float(event.world_time);stage="cancel_neutral"
  return
 if owner and kind=="enemy_impact":
  if stage!="sweep_warning" or sweep_warning.is_empty() or sequence<=int(sweep_warning.sequence) or str(event.get("shape",""))!="cone":fail("uncorrelated_or_early_impact");return
  sweep_impact=compact(event)
  print("STRICT_BOSS_EVENT sweep_impact ",JSON.stringify(sweep_impact))
  stage="release_settle"
  queue_capture("sweep_release","release")

func read_pose()->Dictionary:
 var receipt:Dictionary=host.presentation.receipt
 if str(receipt.get("scope",""))!=boss_scope:return {}
 var poses:Variant=receipt.get("boss_body_motion",null)
 if not poses is Array or poses.size()!=1:fail("missing_or_ambiguous_boss_pose");return {}
 var pose:Dictionary=poses[0]
 if str(pose.get("actor_id",""))!=boss_id or not pose.has_all(["stage","lean","squash"]):fail("wrong_boss_pose");return {}
 return {"source_time":float(receipt.get("source_time",-1.0)),"pose":pose.duplicate(true)}

func queue_capture(label:String,expected_stage:String)->void:
 if capture_pending or captures.has(label) or failed:return
 if captures.size()>=CAPTURE_LIMIT:fail("capture_bound_exceeded");return
 capture_attempts[label]=int(capture_attempts.get(label,0))+1
 if int(capture_attempts[label])>3:fail("postdraw_capture_unavailable_"+label);return
 capture_pending=true
 capture_after_draw(label,expected_stage)

func capture_after_draw(label:String,expected_stage:String)->void:
 await RenderingServer.frame_post_draw
 capture_pending=false
 if failed or not is_instance_valid(host) or stage=="menu_exit":return
 var sample:Dictionary=read_pose()
 if sample.is_empty() or failed:return
 if str(sample.pose.stage)!=expected_stage:
  print("STRICT_BOSS_CAPTURE_MISSED ",label," actual=",sample.pose.stage)
  return
 if label=="cancel_neutral" and float(sample.source_time)<=cancel_at:return
 if label=="sweep_release":
  if sweep_impact.is_empty():fail("release_frame_without_impact");return
  var age:float=float(sample.source_time)-float(sweep_impact.world_time)
  if age<0.0 or age>=.28:fail("release_frame_wrong_source_age");return
 var path:String=output_dir.path_join(label+".png")
 var pixels:Image=root.get_texture().get_image()
 if pixels.save_png(path)!=OK:fail("capture_write_failed");return
 captures[label]={"path":path,"source_time":sample.source_time,"pose":sample.pose}
 print("STRICT_BOSS_CAPTURE ",label," ",JSON.stringify(captures[label]))

func begin_boss()->void:
 release()
 var bosses:Array=host.sim.living().filter(func(enemy:Dictionary)->bool:return str(enemy.kind)=="boss")
 if bosses.size()!=1:fail("one_living_boss_required");return
 var model:Dictionary=host.shop_session.ledger.model.snapshot()
 if not h08_selected or "fengli_h08" not in model.selected_hex or "fengli_h08" not in host.sim.hero.hexes or str(model.skills.E.candidate)!="E1" or int(model.skills.E.rank)<1:fail("H08_E1_not_active");return
 boss_start=elapsed;boss_run=str(host.shop_session.run_id);boss_room=str(host.sim.room_id)
 boss_generation=int(host.sim.encounter_generation);boss_id=str(bosses[0].actor_id)
 boss_scope=boss_run+":"+boss_room+":"+str(boss_generation)
 output_dir=OS.get_user_data_dir().path_join("boss_cancel_strict").path_join(boss_run.validate_filename())
 if DirAccess.make_dir_recursive_absolute(output_dir)!=OK:fail("capture_directory_failed");return
 stage="approach"
 print("STRICT_BOSS_BEGIN ",JSON.stringify({"run_id":boss_run,"room_id":boss_room,"generation":boss_generation,"actor_id":boss_id,"H08_active":true,"E1_rank":model.skills.E.rank,"output":output_dir,"normal_route":route}))

func boss_step()->void:
 if boss_start<0.0:begin_boss()
 if failed:return
 if elapsed-boss_start>BOSS_TIMEOUT:fail("boss_timeout");return
 if str(host.sim.room_id)!=boss_room or int(host.sim.encounter_generation)!=boss_generation or str(host.shop_session.run_id)!=boss_run:fail("boss_scope_changed");return
 var boss:Dictionary=host.sim.enemy_by_id(boss_id)
 if boss.is_empty() or bool(boss.dead) or host.sim.hero.dead or host.sim.phase!="combat":fail("boss_or_hero_lost");return
 var distance:float=host.sim.hero.position.distance_to(boss.position)
 if stage=="cancel_neutral":
  var sample:Dictionary=read_pose()
  if failed:return
  if not sample.is_empty() and float(sample.source_time)>cancel_at and float(sample.source_time)>neutral_last:
   if str(sample.pose.stage)!="neutral" or absf(float(sample.pose.lean))+absf(float(sample.pose.squash))>EPS or host.presentation.boss_body_releases.has(boss_id):fail("false_release_after_cancel");return
   neutral_last=float(sample.source_time);neutral_samples+=1
   queue_capture("cancel_neutral","neutral")
  if host.sim.clock.world_time-cancel_at>.32:
   if neutral_samples<2 or not captures.has("cancel_neutral"):fail("cancel_neutral_not_observed");return
   stage="await_sweep"
   print("STRICT_BOSS_CANCEL_VERIFIED samples=",neutral_samples," actual_cast=",e_cast)
 if stage=="release_settle":
  var sample:Dictionary=read_pose()
  if failed:return
  if not sample.is_empty():
   var age:float=float(sample.source_time)-float(sweep_impact.world_time)
   if age>=0.0 and age<.28 and str(sample.pose.stage)=="release" and float(sample.source_time)>release_last:
    var stored:Dictionary=host.presentation.boss_body_releases.get(boss_id,{})
    if int(stored.get("sequence",-1))!=int(sweep_impact.sequence) or str(stored.get("kind",""))!="enemy_impact":fail("release_cache_not_actual_impact");return
    release_last=float(sample.source_time);release_samples+=1
    queue_capture("sweep_release","release")
   elif age>=.30:
    if str(sample.pose.stage)!="neutral" or absf(float(sample.pose.lean))+absf(float(sample.pose.squash))>EPS:fail("release_did_not_settle");return
    if release_samples<1 or not captures.has("sweep_release"):fail("actual_release_pose_not_observed");return
    queue_capture("sweep_settled","neutral")
    if captures.has("sweep_settled") and not capture_pending:
     release();stage="menu_exit";exit_started=elapsed;entry._pause.pressed.emit();return
 if tick<.10:return
 tick=0.0
 if stage=="approach":
  walk(boss.position+Vector3(0,0,5.6),.25)
 elif stage=="cancel_warning":
  if str(boss.state)!="warning" or str(boss.attack_shape)!="boss_wave_line":fail("target_warning_lost_before_E1");return
  if float(boss.warning_progress)>.40:fail("missed_first_warning_cancel_window");return
  if distance>9.95:walk(boss.position+Vector3(0,0,5.6),.25);return
  release()
  if float(boss.warning_progress)<.15:return
  queue_capture("wave_windup","windup")
  if host._blocked() or host.sim.hero.lock_time>EPS or host.sim.hero.stun_left>EPS or host.sim.hero.dash_left>EPS:return
  if float(host.sim.hero.cooldowns.e)>EPS or host.sim.hero.cast_state.has("e1"):fail("E1_not_ready_for_first_warning");return
  if e_attempted:fail("unexpected_second_cancel_request");return
  expected_e=true;e_attempted=true
  var result:Dictionary=press(KEY_E,boss.position)
  print("STRICT_BOSS_E_REQUEST ",JSON.stringify({"accepted":result.get("accepted",false),"reason":result.get("reason",""),"world_time":host.sim.clock.world_time,"distance":distance}))
  if not result.get("accepted",false) or e_cast<0:fail("E1_request_not_accepted");return
  stage="cancel_contact"
 elif stage in ["cancel_contact","cancel_neutral","release_settle"]:release()
 elif stage=="await_sweep":
  var away:Vector3=boss.position.direction_to(host.sim.hero.position)
  if away.length_squared()<EPS:away=Vector3.BACK
  walk(boss.position+away*2.8,.18)
 elif stage=="sweep_warning":
  if not dodge_target.is_finite():fail("sweep_dodge_target_missing");return
  if float(boss.warning_progress)>.45:queue_capture("sweep_windup","windup")
  walk(dodge_target,.15)

func draft_step_normal()->void:
 release()
 var draft:Node=host.initial_hud.hex_draft
 if not draft.visible or draft.choosing:return
 var ids:Array=[]
 for choice:Dictionary in draft.last_view.get("choices",[]):ids.append(str(choice.id))
 if ids.size()!=4:fail("draft_choice_count");return
 var milestone:int=int(draft.last_view.get("active_milestone",0))
 if draft_step<3:
  if milestone!=1:fail("initial_draft_milestone_changed");return
  if draft_step==0:
   if ids!=["fengli_h12","common_g29","common_g30","fengli_h16"] or draft.cards[0].refresh.disabled:fail("unexpected_initial_offer");return
   draft.cards[0].refresh.pressed.emit();draft_step=1
  elif draft_step==1:
   if ids!=["common_g13","common_g29","common_g30","fengli_h16"] or not bool(draft.last_view.choices[0].refreshed) or draft.cards[1].refresh.disabled:fail("unexpected_refresh0");return
   draft.cards[1].refresh.pressed.emit();draft_step=2
  else:
   if ids!=["common_g13","fengli_h08","common_g30","fengli_h16"] or not bool(draft.last_view.choices[1].refreshed) or draft.cards[1].select.disabled:fail("H08_not_available");return
   draft.cards[1].select.pressed.emit();draft_step=3
 elif milestone==1:
  # Never click a fallback selection while the real initial choose is completing.
  if str(host.shop_session.ledger.model.state.offers.get("1",{}).get("selected",""))!="fengli_h08":fail("initial_H08_selection_not_committed")
 else:
  if not h08_selected:fail("later_draft_before_H08_confirmation");return
  if draft.cards[0].select.disabled:fail("later_draft_choice_disabled");return
  draft.cards[0].select.pressed.emit()

func learn()->void:
 var state:Dictionary=host.shop_session.ledger.model.state
 if int(state.points)<=0:return
 var choices:Array=[]
 if int(state.level)>=7 and int(state.skills.R.rank)==0:choices.append(["R","R2"])
 if int(state.skills.E.rank)==0:choices.append(["E","E1"])
 if int(state.skills.Q.rank)==0:choices.append(["Q","Q1"])
 if int(state.skills.P.rank)==0:choices.append(["P","P2"])
 choices.append_array([["E","E1"],["Q","Q1"],["P","P2"]])
 for choice:Array in choices:
  var rank:int=state.skills[choice[0]].rank
  host.initial_hud.adapter.request("learn",{"slot_id":choice[0],"candidate_id":choice[1],"expected_rank":rank})
  if int(host.shop_session.ledger.model.state.skills[choice[0]].rank)>rank:return

func shop()->void:
 var session=host.shop_session
 if shops.has(session.active_node_room) or session.shop_location_reason()!="":return
 shops[session.active_node_room]=true
 if int(session.ledger.model.state.gold)<200:return
 release();host._shop(true)
 if not session.panel_open:return
 host.shop_panel._select("potion:1")
 for index:int in range(2):
  if host.shop_panel._buy.disabled:break
  host.shop_panel._buy.pressed.emit()
 host._shop(false)

func use_potion()->void:
 if host.sim.hero.hp>=host.sim.hero.stats.max_hp*.7:return
 for button in host.ordinary_potion_controls.get_children():
  if button is Button and not button.disabled and host.ordinary_potion_controls.visible:
   button.pressed.emit();return

func normal_route_tick()->void:
 var session=host.shop_session
 var sim=host.sim
 if session.initial_modal_open:draft_step_normal();return
 if not h08_selected:
  if draft_step!=3 or "fengli_h08" not in session.ledger.model.state.selected_hex:fail("H08_selection_unconfirmed");return
  h08_selected=true;print("STRICT_H08_SELECTED ordinary_UI=true")
 learn()
 if session.status=="service":release();shop();host.service_continue.pressed.emit();return
 if session.exit_map_open:
  release()
  var choices:Array=session.available_choices()
  if choices.is_empty():fail("route_no_choices");return
  var id:String=str(choices[0].node_id)
  for choice:Dictionary in choices:
   if str(choice.node_id).ends_with("a") or str(choice.node_id)=="r12boss":id=str(choice.node_id)
  if host.route_map.buttons[id].disabled:fail("route_choice_disabled");return
  host.route_map.buttons[id].pressed.emit();route.append(id);return
 if sim.phase in ["preparation","victory"]:shop();walk(Vector3(0,0,-11));return
 if sim.phase!="combat":return
 var live:Array=sim.living()
 if live.is_empty():release();return
 var target:Dictionary=live[0]
 for enemy:Dictionary in live:
  if sim.hero.position.distance_to(enemy.position)<sim.hero.position.distance_to(target.position):target=enemy
 var aim:Vector3=target.position
 var distance:float=sim.hero.position.distance_to(aim)
 var evading:bool=false
 for threat:Dictionary in live:
  if str(threat.state)=="warning" and float(threat.warning_progress)>.20 and sim.hero.position.distance_to(threat.position)<float(threat.attack_range)+2:
   var side:=Vector3(-float(threat.aim.z),0,float(threat.aim.x))
   var left:Vector3=sim._move_clipped(sim.hero.position,sim.hero.position+side*2.2,sim.hero_radius)
   var right:Vector3=sim._move_clipped(sim.hero.position,sim.hero.position-side*2.2,sim.hero_radius)
   walk(left if left.distance_to(sim.hero.position)>=right.distance_to(sim.hero.position) else right)
   if float(threat.timer)<.25 and float(sim.hero.cooldowns.shift)<=0:press(KEY_SHIFT,aim)
   evading=true;break
 if not evading:walk(aim,1.45)
 use_potion()
 if distance<7 and float(sim.hero.cooldowns.e)<=0:press(KEY_E,aim)
 if distance<9 and float(sim.hero.cooldowns.q)<=0:press(KEY_Q,aim)
 if distance<7 and float(sim.hero.cooldowns.r)<=0:press(KEY_R,aim)
 var click:=InputEventMouseButton.new()
 click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
 if distance<2.4:host.input_router.handle_event(click,aim,host._blocked())
 click.pressed=false;host.input_router.handle_event(click,aim,host._blocked())

func _process(dt:float)->bool:
 if failed:return false
 elapsed+=dt;tick+=dt
 if elapsed>TOTAL_TIMEOUT:fail("total_timeout");return false
 if stage=="menu_exit":
  if entry.screen==entry.Screen.MENU:
   print("STRICT_BOSS_CANCEL_AND_SWEEP_PASS ",JSON.stringify({"elapsed":elapsed,"boss_seconds":elapsed-boss_start,"cancel_chain":chain,"sweep_warning":sweep_warning,"sweep_impact":sweep_impact,"neutral_samples":neutral_samples,"release_samples":release_samples,"captures":captures,"full_floor_win":false,"wave_release_tested":false,"two_directions_tested":false,"active_release_new_run_lifecycle_tested":false,"separate_lifecycle_test_required":true}))
   quit(0)
  elif elapsed-exit_started>5.0:fail("normal_menu_exit_timeout")
  return false
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
 if not watching:host.sim.combat_event.connect(_watch);watching=true
 if not str(host.floor_error).is_empty() or not str(host.startup_session_error).is_empty():fail("host_fault");return false
 if host.shop_session.status in ["faulted","defeated","aborted","completed"]:fail("unexpected_session_terminal");return false
 if str(host.sim.room_id).ends_with("r12boss") and host.sim.phase=="combat":boss_step();return false
 if boss_start>=0.0:fail("left_boss_scope");return false
 if tick<.12:return false
 tick=0.0
 if str(host.shop_session.active_node_room)!=last_progress_room:
  last_progress_room=str(host.shop_session.active_node_room)
  print("STRICT_ROUTE_PROGRESS room=",last_progress_room," elapsed=",elapsed," HP=",host.sim.hero.hp)
 normal_route_tick()
 return false
