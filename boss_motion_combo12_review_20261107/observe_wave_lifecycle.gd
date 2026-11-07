extends SceneTree
# Isolated normal-input observer. Never mutate production state or guard settings.
# One normal route; at most one uncredited positioning wave/sweep, then
# wave 1 -> mandatory sweep -> opposite-horizontal wave 2.
# Menu pauses/preserves the old release. Start + Confirm must retire it and create
# fresh owners/cache. This is NOT a full-floor win or an OS-input/picking test.
const TOTAL_TIMEOUT:float=550.0
const BOSS_TIMEOUT:float=50.0
const LIFECYCLE_TIMEOUT:float=20.0
const CAPTURE_LIMIT:int=7
const EPS:float=.00001
const POSE_TOLERANCE:float=.0001
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
var waves:Array=[]
var wave_index:int=-1
var sweep_warning:Dictionary={}
var sweep_impact:Dictionary={}
var positioning_wave:Dictionary={}
var positioning_sweep_warning:Dictionary={}
var positioning_sweep_impact:Dictionary={}
var last_warning_diagnostic:Dictionary={}
var navigation_issue:Dictionary={}
var screen_axis:Vector3=Vector3.RIGHT
var entry_waypoint:Vector3=Vector3.INF
var entry_waypoint_done:bool=false
var initial_side_target:Vector3=Vector3.INF
var initial_side_done:bool=false
var escape_target:Vector3=Vector3.INF
var cross_waypoint:Vector3=Vector3.INF
var crossed:bool=false
var captures:Dictionary={}
var capture_attempts:Dictionary={}
var capture_pending:bool=false
var output_dir:String=""
var lifecycle_start:float=-1.0
var menu_seen:float=-1.0
var paused_world:float=-1.0
var old_ids:Dictionary={}
var old_refs:Dictionary={}
var terminal:Dictionary={}
var lifecycle:Dictionary={}
var fresh_frames:int=0
var fresh_frame_last:int=-1
var fresh_capture_pending:bool=false

func _initialize()->void:
 root.add_child(load("res://boot.tscn").instantiate())

func fail(reason:String)->void:
 if failed:return
 failed=true
 print("BOSS_WAVE_FAIL ",JSON.stringify({"reason":reason,"stage":stage,"elapsed":elapsed,"route":route,"waves":waves,"positioning_wave":positioning_wave,"positioning_sweep_warning":positioning_sweep_warning,"positioning_sweep_impact":positioning_sweep_impact,"last_warning_diagnostic":last_warning_diagnostic,"navigation_issue":navigation_issue,"sweep_warning":sweep_warning,"sweep_impact":sweep_impact,"lifecycle":lifecycle,"terminal":terminal,"captures":captures.keys(),"full_floor_win":false}))
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
 for field:String in ["kind","sequence","run_id","room_id","generation","world_time","actor_id","enemy_kind","boss_cast_id","reason","result","shape","direction","position","geometry","hit","previous_distance","distance","stopped"]:
  if event.has(field):result[field]=event[field]
 return result

func current_event(event:Dictionary)->bool:
 return not bool(event.get("stale_generation",false)) and str(event.get("run_id",""))==boss_run and str(event.get("room_id",""))==boss_room and int(event.get("generation",-1))==boss_generation and event.has_all(["sequence","world_time"])

func evidence(label:String,event:Dictionary)->Dictionary:
 var result:Dictionary=compact(event)
 print("BOSS_WAVE_EVENT ",label," ",JSON.stringify(result))
 return result

func projected_x(direction:Vector3)->float:
 var boss:Dictionary=host.sim.enemy_by_id(boss_id)
 return (host.presentation.p(boss.position+direction)-host.presentation.p(boss.position)).x

func record_wave_warning(event:Dictionary)->void:
 if str(event.get("shape",""))!="boss_wave_line" or str(event.get("boss_cast_id","")).is_empty():fail("expected_authentic_wave_warning");return
 var direction:Vector3=event.get("direction",Vector3.ZERO)
 if not direction.is_finite() or direction.length_squared()<EPS:fail("invalid_wave_direction");return
 var horizontal:float=projected_x(direction)
 var boss:Dictionary=host.sim.enemy_by_id(boss_id)
 last_warning_diagnostic={"event":compact(event),"stage":stage,"hero":host.sim.hero.position,"boss":boss.position,"gap":host.sim.hero.position.distance_to(boss.position),"screen_x":horizontal,"entry_waypoint_done":entry_waypoint_done,"initial_side_done":initial_side_done,"credited_waves":waves.size()}
 print("BOSS_WAVE_WARNING_DIAGNOSTIC ",JSON.stringify(last_warning_diagnostic))
 # Demand visibly horizontal source aim, not a numerical sign near zero.
 # Navigation milestones are not proof. A genuinely qualifying early warning
 # counts; one nonhorizontal early wave may position us but earns no pose credit.
 if absf(horizontal)<4.0:
  if wave_index<0 and positioning_wave.is_empty():
   positioning_wave={"warning":evidence("positioning_wave_warning_uncredited",event),"screen_x":horizontal,"mirror_credit":false}
   if not set_wave_escape(event):return
   stage="positioning_wave_warning";return
  fail("wave_direction_not_meaningfully_horizontal");return
 if wave_index<0 and not positioning_wave.is_empty() and (positioning_sweep_impact.is_empty() or int(event.sequence)<=int(positioning_sweep_impact.sequence)):fail("positioning_cycle_missing_mandatory_sweep");return
 if wave_index==0 and signf(horizontal)!=-float(waves[0].sign):fail("second_wave_not_opposite_horizontal");return
 if wave_index==0 and (sweep_impact.is_empty() or int(event.sequence)<=int(sweep_impact.sequence)):fail("second_wave_missing_intervening_sweep");return
 wave_index+=1
 waves.append({"warning":evidence("wave%d_warning"%(wave_index+1),event),"sign":signf(horizontal),"screen_x":horizontal,"windup_samples":0,"release_samples":0,"settled_samples":0,"last_windup":-1.0,"last_release":-1.0,"last_settled":-1.0})
 if not set_wave_escape(event):return
 stage="wave%d_warning"%(wave_index+1)

func set_wave_escape(event:Dictionary)->bool:
 var boss:Dictionary=host.sim.enemy_by_id(boss_id)
 var cast:Dictionary=host.sim.enemy_director.boss_wave.snapshot(host.sim,boss)
 if str(cast.get("boss_cast_id",""))!=str(event.boss_cast_id) or bool(cast.get("released",true)) or not cast.get("escape",{}).has("destination"):fail("warning_has_no_authoritative_escape");return false
 escape_target=cast.escape.destination
 if not escape_target.is_finite():fail("escape_destination_invalid");return false
 return true

func clear_goal(origin:Vector3,target:Vector3)->bool:
 if not target.is_finite():return false
 var radius:float=host.sim.hero_radius
 if host.sim.clamp_position(target,radius).distance_to(target)>.02:return false
 return host.sim._move_clipped(origin,target,radius).distance_to(target)<=.02

func walk_horizontal(boss:Dictionary,side_sign:float,distance:float)->void:
 var origin:Vector3=host.sim.hero.position
 var depth:=Vector3(-screen_axis.z,0,screen_axis.x)
 var radii:Array=[distance,distance-.4,distance-.8]
 for radius:float in radii:
  for offset:float in [0.0,1.2,-1.2,2.4,-2.4]:
   var target:Vector3=boss.position+screen_axis*side_sign*radius+depth*offset
   var gap:float=target.distance_to(boss.position)
   if distance>3.8 and gap<=4.0:continue
   if distance<=3.8 and gap>3.7:continue
   if clear_goal(origin,target):walk(target,.2);return
 navigation_issue={"stage":stage,"hero":origin,"boss":boss.position,"requested_side":side_sign,"requested_distance":distance}
 fail("no_clear_bounded_horizontal_goal")

func start_sweep(event:Dictionary,positioning:bool)->void:
 if str(event.get("shape",""))!="cone":fail("expected_mandatory_sweep_shape");return
 if positioning:
  if not positioning_sweep_warning.is_empty() or not positioning_wave.has("finish") or int(event.sequence)<=int(positioning_wave.finish.sequence):fail("uncorrelated_positioning_sweep_warning");return
  positioning_sweep_warning=evidence("positioning_sweep_warning_uncredited",event)
 else:
  if not sweep_warning.is_empty():fail("expected_one_mandatory_sweep");return
  sweep_warning=evidence("intervening_sweep_warning",event)
 var direction:Vector3=event.get("direction",Vector3.ZERO)
 if not direction.is_finite() or direction.length_squared()<EPS:fail("invalid_sweep_direction");return
 var side:=Vector3(-direction.z,0,direction.x).normalized()
 var boss:Dictionary=host.sim.enemy_by_id(boss_id)
 var origin:Vector3=host.sim.hero.position
 cross_waypoint=Vector3.INF
 for radius:float in [3.8,3.2,2.8]:
  for direction_sign:float in [1.0,-1.0]:
   var candidate:Vector3=boss.position+side*radius*direction_sign
   if clear_goal(origin,candidate):cross_waypoint=candidate;break
  if cross_waypoint.is_finite():break
 if not cross_waypoint.is_finite():
  navigation_issue={"stage":stage,"hero":origin,"boss":boss.position,"sweep_direction":direction}
  fail("no_clear_bounded_sweep_waypoint");return
 crossed=false;stage="positioning_sweep_warning" if positioning else "sweep_warning"

func watch_positioning(event:Dictionary)->bool:
 if positioning_wave.is_empty() or wave_index>=0:return false
 var kind:String=str(event.get("kind",""))
 if kind=="enemy_impact":
  if stage!="positioning_sweep_warning" or positioning_sweep_warning.is_empty() or not positioning_sweep_impact.is_empty() or str(event.get("shape",""))!="cone" or int(event.sequence)<=int(positioning_sweep_warning.sequence):fail("uncorrelated_positioning_sweep_impact");return true
  positioning_sweep_impact=evidence("positioning_sweep_impact_uncredited",event)
  stage="position_after_warmup";return true
 if not kind.begins_with("boss_wave_"):return false
 if str(event.get("boss_cast_id",""))!=str(positioning_wave.warning.boss_cast_id):fail("wrong_positioning_wave_identity");return true
 if kind=="boss_wave_released":
  if stage!="positioning_wave_warning" or positioning_wave.has("release") or int(event.sequence)<=int(positioning_wave.warning.sequence) or Vector3(event.get("direction",Vector3.ZERO)).distance_to(Vector3(positioning_wave.warning.direction))>EPS:fail("uncorrelated_positioning_wave_release");return true
  positioning_wave["release"]=evidence("positioning_wave_release_uncredited",event);stage="positioning_wave_active"
 elif kind=="boss_wave_advanced":
  if not positioning_wave.has("release") or int(event.sequence)<=int(positioning_wave.release.sequence):fail("positioning_front_without_release");return true
  if not positioning_wave.has("advance") and float(event.get("distance",0.0))>float(event.get("previous_distance",0.0))+EPS:positioning_wave["advance"]=evidence("positioning_wave_advance_uncredited",event)
 elif kind=="boss_wave_finished":
  if not positioning_wave.has_all(["release","advance"]) or positioning_wave.has("finish") or int(event.sequence)<=int(positioning_wave.advance.sequence):fail("positioning_finish_without_front");return true
  positioning_wave["finish"]=evidence("positioning_wave_finished_uncredited",event);stage="positioning_await_sweep"
 return true

func _watch(event:Dictionary)->void:
 if failed or boss_start<0.0 or not current_event(event):return
 var kind:String=str(event.get("kind",""))
 var owner:bool=str(event.get("enemy_kind",""))=="boss" and str(event.get("actor_id",""))==boss_id
 if kind=="encounter_finished":
  if stage!="new_run_transition" or str(event.get("result",""))!="host_closed" or not terminal.is_empty():fail("unexpected_old_encounter_terminal");return
  terminal=evidence("old_encounter_finished",event)
  lifecycle["old_cache_empty_at_terminal"]=host.presentation.boss_body_releases.is_empty()
  lifecycle["old_status_at_terminal"]=str(host.shop_session.status)
  if not lifecycle.old_cache_empty_at_terminal or lifecycle.old_status_at_terminal!="aborted":fail("old_release_not_retired_at_real_terminal")
  return
 if stage in ["menu_opening","menu_hold","confirm_new_run","new_run_transition","fresh_run"]:
  # Closing a released cast may emit its genuine encounter-cleared cancellation.
  if owner and kind=="boss_wave_cancelled" and stage=="new_run_transition":
   if str(event.get("boss_cast_id",""))!=str(waves[1].warning.boss_cast_id) or str(event.get("reason",""))!="encounter_cleared":fail("unexpected_lifecycle_wave_cancel");return
   lifecycle["old_wave_retired"]=evidence("old_wave_retired",event)
  elif owner and kind in ["enemy_warning","enemy_impact","boss_wave_released","boss_wave_advanced","enemy_attack_cancelled","boss_wave_cancelled"]:fail("old_combat_advanced_during_menu")
  return
 if owner and kind in ["enemy_attack_cancelled","boss_wave_cancelled"]:fail("unexpected_cancel_in_successful_release_test");return
 if owner and kind=="enemy_warning":
  if stage in ["approach_wave1","position_after_warmup"]:record_wave_warning(event)
  elif stage=="positioning_await_sweep":start_sweep(event,true)
  elif stage=="await_sweep":start_sweep(event,false)
  elif stage=="position_wave2":record_wave_warning(event)
  else:fail("unexpected_additional_warning")
  return
 if owner and watch_positioning(event):return
 if owner and kind=="enemy_impact":
  if stage!="sweep_warning" or sweep_warning.is_empty() or not sweep_impact.is_empty() or str(event.get("shape",""))!="cone" or int(event.sequence)<=int(sweep_warning.sequence):fail("uncorrelated_intervening_sweep");return
  sweep_impact=evidence("intervening_sweep_impact",event);stage="position_wave2";return
 if not owner or wave_index<0:return
 var wave:Dictionary=waves[wave_index]
 if kind.begins_with("boss_wave_") and str(event.get("boss_cast_id",""))!=str(wave.warning.boss_cast_id):fail("wrong_wave_cast_identity");return
 if kind=="boss_wave_released":
  if stage!="wave%d_warning"%(wave_index+1) or wave.has("release") or int(event.sequence)<=int(wave.warning.sequence):fail("uncorrelated_wave_release");return
  if Vector3(event.get("direction",Vector3.ZERO)).distance_to(Vector3(wave.warning.direction))>EPS:fail("release_direction_changed");return
  wave["release"]=evidence("wave%d_release"%(wave_index+1),event)
  stage="wave%d_active"%(wave_index+1)
  queue_capture("wave%d_release"%(wave_index+1),"release",wave_index)
 elif kind=="boss_wave_advanced":
  if not wave.has("release") or int(event.sequence)<=int(wave.release.sequence):fail("front_without_actual_release");return
  if not wave.has("advance") and float(event.get("distance",0.0))>float(event.get("previous_distance",0.0))+EPS:
   wave["advance"]=evidence("wave%d_first_positive_advance"%(wave_index+1),event)
 elif kind=="boss_wave_finished":
  if not wave.has_all(["release","advance"]) or wave.has("finish") or int(event.sequence)<=int(wave.advance.sequence):fail("finish_without_actual_front");return
  if wave_index==1:fail("second_wave_finished_before_active_menu_capture");return
  wave["finish"]=evidence("wave1_finished",event)

func read_pose()->Dictionary:
 var receipt:Dictionary=host.presentation.receipt
 if str(receipt.get("scope",""))!=boss_scope:return {}
 var poses:Variant=receipt.get("boss_body_motion",null)
 if not poses is Array or poses.size()!=1:fail("missing_or_ambiguous_boss_pose");return {}
 var pose:Dictionary=poses[0]
 if str(pose.get("actor_id",""))!=boss_id or not pose.has_all(["stage","lean","squash","world_time"]):fail("wrong_boss_pose");return {}
 return {"source_time":float(receipt.get("source_time",-1.0)),"pose":pose.duplicate(true),"fronts":receipt.get("boss_wave_effects",{}).get("fronts",[]).duplicate(true)}

func validate_pose(sample:Dictionary,expected_stage:String,index:int)->bool:
 if sample.is_empty() or str(sample.pose.stage)!=expected_stage:return false
 var wave:Dictionary=waves[index]
 var source_time:float=float(sample.source_time)
 if absf(float(sample.pose.world_time)-source_time)>EPS:fail("pose_source_time_mismatch");return false
 var lean:float=float(sample.pose.lean)
 var squash:float=float(sample.pose.squash)
 if expected_stage=="windup":
  if source_time<=float(wave.warning.world_time) or lean*float(wave.sign)>=-EPS or squash<=EPS:fail("wrong_signed_warning_pose");return false
  if absf(lean+float(wave.sign)*squash*(.10/.14))>POSE_TOLERANCE:fail("warning_pose_ratio_wrong");return false
 elif expected_stage=="release":
  if not wave.has("release"):fail("pose_without_release_event");return false
  var age:float=source_time-float(wave.release.world_time)
  if age<0.0 or age>=.28:return false
  var stored:Dictionary=host.presentation.boss_body_releases.get(boss_id,{})
  if str(stored.get("kind",""))!="boss_wave_released" or int(stored.get("sequence",-1))!=int(wave.release.sequence) or str(stored.get("boss_cast_id",""))!=str(wave.warning.boss_cast_id):fail("release_cache_not_matching_wave_event");return false
  var weight:float=pow(1.0-age/.28,2.0)
  if absf(lean-float(wave.sign)*.17*weight)>POSE_TOLERANCE or absf(squash+.12*weight)>POSE_TOLERANCE:fail("wrong_signed_wave_release_pose");return false
  if sample.fronts.size()!=1 or str(sample.fronts[0].get("identity",{}).get("boss_cast_id",""))!=str(wave.warning.boss_cast_id):fail("actual_wave_front_missing_from_draw");return false
  if not wave.has("advance") or float(sample.fronts[0].get("distance",0.0))<=EPS:return false
 elif expected_stage=="neutral":
  if not wave.has("release") or source_time-float(wave.release.world_time)<.30:return false
  if absf(lean)+absf(squash)>EPS:fail("wave_pose_did_not_settle");return false
 return true

func queue_capture(label:String,expected_stage:String,index:int)->void:
 if capture_pending or captures.has(label) or failed:return
 if captures.size()>=CAPTURE_LIMIT:fail("capture_bound_exceeded");return
 capture_attempts[label]=int(capture_attempts.get(label,0))+1
 if int(capture_attempts[label])>4:fail("postdraw_capture_unavailable_"+label);return
 capture_pending=true
 capture_after_draw(label,expected_stage,index)

func save_capture(label:String,data:Dictionary)->void:
 if captures.has(label):return
 if captures.size()>=CAPTURE_LIMIT:fail("capture_bound_exceeded");return
 var path:String=output_dir.path_join(label+".png")
 var pixels:Image=root.get_texture().get_image()
 if pixels.save_png(path)!=OK:fail("capture_write_failed");return
 data["path"]=path;captures[label]=data
 print("BOSS_WAVE_CAPTURE ",label," ",JSON.stringify(data))

func capture_after_draw(label:String,expected_stage:String,index:int)->void:
 await RenderingServer.frame_post_draw
 capture_pending=false
 if failed or not is_instance_valid(host) or stage.begins_with("menu") or stage in ["confirm_new_run","new_run_transition","fresh_run"]:return
 var sample:Dictionary=read_pose()
 if failed or not validate_pose(sample,expected_stage,index):return
 var counter:String="settled" if expected_stage=="neutral" else expected_stage
 var wave:Dictionary=waves[index]
 if float(sample.source_time)>float(wave["last_"+counter]):
  wave["last_"+counter]=float(sample.source_time)
  wave[counter+"_samples"]=int(wave[counter+"_samples"])+1
 save_capture(label,{"source_time":sample.source_time,"pose":sample.pose,"wave_cast_id":waves[index].warning.boss_cast_id})
 if label=="wave2_release" and not failed:open_active_menu(sample)

func begin_boss()->void:
 release()
 var bosses:Array=host.sim.living().filter(func(enemy:Dictionary)->bool:return str(enemy.kind)=="boss")
 if bosses.size()!=1:fail("one_living_boss_required");return
 var model:Dictionary=host.shop_session.ledger.model.snapshot()
 if not h08_selected or "fengli_h08" not in model.selected_hex or "fengli_h08" not in host.sim.hero.hexes or str(model.skills.E.candidate)!="E1" or int(model.skills.E.rank)<1:fail("verified_route_loadout_missing");return
 boss_start=elapsed;boss_run=str(host.shop_session.run_id);boss_room=str(host.sim.room_id)
 boss_generation=int(host.sim.encounter_generation);boss_id=str(bosses[0].actor_id)
 boss_scope=boss_run+":"+boss_room+":"+str(boss_generation)
 screen_axis=host.camera.global_basis.x;screen_axis.y=0.0;screen_axis=screen_axis.normalized()
 if screen_axis.length_squared()<.9:fail("horizontal_camera_axis_invalid");return
 # Room arrival resets the hero. The foreground parapets block a direct sideways
 # target at z=10, so leave through the clear central opening before moving aside.
 # The moving Boss may still commit early; only its actual direction earns credit.
 if host.sim.hero.position.distance_to(bosses[0].position)<14.0:fail("insufficient_initial_gap_for_side_approach");return
 entry_waypoint=host.sim.hero.position+Vector3.FORWARD*1.8
 initial_side_target=entry_waypoint+screen_axis*5.8
 var entry_clip:Vector3=host.sim._move_clipped(host.sim.hero.position,entry_waypoint,host.sim.hero_radius)
 var side_clip:Vector3=host.sim._move_clipped(entry_waypoint,initial_side_target,host.sim.hero_radius)
 if entry_clip.distance_to(entry_waypoint)>.02 or side_clip.distance_to(initial_side_target)>.02:fail("initial_positioning_path_not_clear");return
 output_dir=OS.get_user_data_dir().path_join("boss_wave_lifecycle").path_join(boss_run.validate_filename())
 if DirAccess.make_dir_recursive_absolute(output_dir)!=OK:fail("capture_directory_failed");return
 stage="approach_wave1"
 print("BOSS_WAVE_BEGIN ",JSON.stringify({"run_id":boss_run,"room_id":boss_room,"generation":boss_generation,"actor_id":boss_id,"route":route,"output":output_dir,"normal_input_only":true,"hero":host.sim.hero.position,"boss":bosses[0].position,"entry_waypoint":entry_waypoint,"side_target":initial_side_target,"path_geometry_checked":true}))

func sample_wave()->void:
 if wave_index<0:return
 var wave:Dictionary=waves[wave_index]
 var sample:Dictionary=read_pose()
 if failed or sample.is_empty():return
 var pose_stage:String=str(sample.pose.stage)
 var source_time:float=float(sample.source_time)
 if pose_stage=="windup" and source_time-float(wave.warning.world_time)>.35:
  if validate_pose(sample,"windup",wave_index) and source_time>float(wave.last_windup):
   wave.last_windup=source_time;wave.windup_samples+=1
   queue_capture("wave%d_windup"%(wave_index+1),"windup",wave_index)
 elif wave.has("release") and pose_stage=="release":
  if validate_pose(sample,"release",wave_index) and source_time>float(wave.last_release):
   wave.last_release=source_time;wave.release_samples+=1
   queue_capture("wave%d_release"%(wave_index+1),"release",wave_index)
 elif wave_index==0 and wave.has("release") and source_time-float(wave.release.world_time)>=.30:
  if not validate_pose(sample,"neutral",0):fail("first_wave_did_not_settle");return
  if source_time>float(wave.last_settled):wave.last_settled=source_time;wave.settled_samples+=1
  queue_capture("wave1_settled","neutral",0)
 if wave_index==0 and wave.has("finish"):
  if int(wave.windup_samples)<1 or int(wave.release_samples)<1 or int(wave.settled_samples)<2 or not captures.has_all(["wave1_windup","wave1_release","wave1_settled"]):fail("first_wave_evidence_incomplete");return
  stage="await_sweep"

func boss_step()->void:
 if boss_start<0.0:begin_boss()
 if failed:return
 if elapsed-boss_start>BOSS_TIMEOUT:fail("boss_timeout");return
 if str(host.sim.room_id)!=boss_room or int(host.sim.encounter_generation)!=boss_generation or str(host.shop_session.run_id)!=boss_run:fail("boss_scope_changed");return
 var boss:Dictionary=host.sim.enemy_by_id(boss_id)
 if boss.is_empty() or bool(boss.dead) or host.sim.hero.dead or host.sim.phase!="combat":fail("boss_or_hero_lost");return
 if stage.begins_with("wave"):sample_wave()
 if failed or stage.begins_with("menu") or tick<.06:return
 tick=0.0
 use_potion()
 if stage=="approach_wave1":
  if not entry_waypoint_done:
   if host.sim.hero.position.distance_to(entry_waypoint)<.3:entry_waypoint_done=true
   else:walk(entry_waypoint,.15);return
  if not initial_side_done:
   if host.sim.hero.position.distance_to(initial_side_target)<.3:
    initial_side_done=true
    print("BOSS_WAVE_SIDE_POSITIONED ",JSON.stringify({"hero":host.sim.hero.position,"boss":boss.position,"gap":host.sim.hero.position.distance_to(boss.position),"world_time":host.sim.clock.world_time}))
   else:walk(initial_side_target,.15);return
  walk_horizontal(boss,1.0,5.8)
 elif stage in ["wave1_warning","wave1_active","wave2_warning","wave2_active","positioning_wave_warning","positioning_wave_active"]:
  if not escape_target.is_finite():fail("wave_escape_missing");return
  walk(escape_target,.15)
 elif stage=="await_sweep":walk_horizontal(boss,float(waves[0].sign),2.8)
 elif stage=="positioning_await_sweep":walk_horizontal(boss,1.0,2.8)
 elif stage in ["sweep_warning","position_wave2","positioning_sweep_warning","position_after_warmup"]:
  if not crossed:
   if host.sim.hero.position.distance_to(cross_waypoint)<.35:crossed=true
   else:walk(cross_waypoint,.18);return
  var target_sign:float=1.0 if stage in ["positioning_sweep_warning","position_after_warmup"] else -float(waves[0].sign)
  walk_horizontal(boss,target_sign,6.0)

func open_active_menu(sample:Dictionary)->void:
 if stage!="wave2_active" or waves.size()!=2 or not captures.has_all(["wave1_windup","wave1_release","wave1_settled","wave2_windup","wave2_release"]):fail("active_menu_without_two_signed_waves");return
 if int(waves[1].windup_samples)<1 or int(waves[1].release_samples)<1 or not waves[1].has("advance"):fail("second_wave_evidence_incomplete");return
 if not validate_pose(sample,"release",1):fail("menu_release_not_active");return
 if entry.screen!=entry.Screen.RUN or not entry._pause.visible or entry._pause.disabled or not host.frontdoor_can_suspend():fail("normal_menu_control_unavailable");return
 old_ids={"host":host.get_instance_id(),"sim":host.sim.get_instance_id(),"session":host.shop_session.get_instance_id(),"presentation":host.presentation.get_instance_id()}
 old_refs={"host":weakref(host),"sim":weakref(host.sim),"session":weakref(host.shop_session),"presentation":weakref(host.presentation)}
 lifecycle={"old_ids":old_ids.duplicate(),"pause_release_sequence":waves[1].release.sequence,"pause_pose_time":sample.source_time,"pause_release_age":float(sample.source_time)-float(waves[1].release.world_time),"pause_from_actual_postdraw_release":true}
 release();stage="menu_opening";lifecycle_start=elapsed
 entry._pause.pressed.emit()

func old_pause_intact()->bool:
 if not is_instance_valid(host) or entry.active_room!=host or host.get_instance_id()!=int(old_ids.host):fail("menu_replaced_room_without_confirmation");return false
 if not host.sim.paused or host.visible or host.process_mode!=Node.PROCESS_MODE_DISABLED:fail("menu_did_not_suspend_and_hide_room");return false
 if host.sim.phase!="combat" or host.shop_session.status!="combat":fail("menu_incorrectly_ended_run");return false
 var stored:Dictionary=host.presentation.boss_body_releases.get(boss_id,{})
 if int(stored.get("sequence",-1))!=int(waves[1].release.sequence):fail("menu_incorrectly_discarded_live_release");return false
 var age:float=host.sim.clock.world_time-float(waves[1].release.world_time)
 if age<0.0 or age>=.28:fail("release_expired_before_menu_suspend");return false
 if paused_world>=0.0 and absf(float(host.sim.clock.world_time)-paused_world)>EPS:fail("world_advanced_while_menu_paused");return false
 return true

func menu_capture()->void:
 await RenderingServer.frame_post_draw
 if failed or stage!="menu_hold" or not old_pause_intact():return
 save_capture("menu_paused",{"old_run":boss_run,"world_time":paused_world,"cache_sequence":waves[1].release.sequence,"room_hidden":not host.visible,"menu_pauses_not_clears":true})

func check_fresh_frame()->void:
 await RenderingServer.frame_post_draw
 fresh_capture_pending=false
 if failed or stage!="fresh_run":return
 var next:Node=entry.active_room
 if not is_instance_valid(next) or entry.screen!=entry.Screen.RUN:fail("fresh_run_not_live");return
 if not str(next.floor_error).is_empty() or not str(next.startup_session_error).is_empty():fail("fresh_run_fault");return
 for key_name:String in old_refs:
  if old_refs[key_name].get_ref()!=null:fail("old_owner_not_retired_"+key_name);return
 var ids:Dictionary={"host":next.get_instance_id(),"sim":next.sim.get_instance_id(),"session":next.shop_session.get_instance_id(),"presentation":next.presentation.get_instance_id()}
 for key_name:String in ids:
  if ids[key_name]==old_ids[key_name]:fail("fresh_owner_identity_reused_"+key_name);return
 var new_run:String=str(next.shop_session.run_id)
 if new_run.is_empty() or new_run==boss_run or str(next.sim.route_run_id)!=new_run:fail("fresh_run_identity_missing");return
 if not next.presentation.boss_body_releases.is_empty():fail("old_release_leaked_to_new_cache");return
 var receipt:Dictionary=next.presentation.receipt
 var expected_scope:String=new_run+":"+str(next.sim.room_id)+":"+str(next.sim.encounter_generation)
 if str(receipt.get("scope",""))!=expected_scope:return
 if receipt.get("boss_body_motion",[]).size()!=0 or receipt.get("boss_wave_effects",{}).get("fronts",[]).size()!=0 or receipt.get("boss_wave_effects",{}).get("warnings",[]).size()!=0:fail("old_boss_visual_leaked_to_new_run");return
 if not next.shop_session.initial_modal_open or not next.initial_hud.hex_draft.visible or next.sim.phase!="preparation" or not next.sim.living().is_empty():fail("fresh_initial_UI_or_source_not_ready");return
 var frame:int=Engine.get_process_frames()
 if frame<=fresh_frame_last:return
 fresh_frame_last=frame;fresh_frames+=1
 lifecycle["new_ids"]=ids;lifecycle["new_run"]=new_run;lifecycle["new_scope"]=expected_scope;lifecycle["fresh_empty_postdraw_frames"]=fresh_frames
 if not captures.has("new_run_initial"):save_capture("new_run_initial",{"new_run":new_run,"scope":expected_scope,"new_ids":ids,"boss_cache_empty":true,"boss_poses":0,"boss_fronts":0,"initial_draft_visible":true})
 if fresh_frames>=2:
  print("BOSS_WAVE_DIRECTIONS_LIFECYCLE_PASS ",JSON.stringify({"elapsed":elapsed,"boss_seconds":lifecycle_start-boss_start,"waves":waves,"positioning_wave_uncredited":positioning_wave,"positioning_sweep_warning_uncredited":positioning_sweep_warning,"positioning_sweep_impact_uncredited":positioning_sweep_impact,"sweep_warning":sweep_warning,"sweep_impact":sweep_impact,"terminal":terminal,"lifecycle":lifecycle,"captures":captures,"successful_wave_release_tested":true,"opposite_horizontal_wave_poses_tested":true,"active_release_menu_new_run_tested":true,"full_floor_win":false,"OS_input_tested":false,"menu_resume_tested":false,"picking_tested":false}))
  quit(0)

func lifecycle_step()->void:
 if elapsed-lifecycle_start>LIFECYCLE_TIMEOUT:fail("normal_lifecycle_timeout");return
 if entry.screen==entry.Screen.FAULT:fail("entry_lifecycle_fault");return
 if stage=="menu_opening":
  if entry.screen==entry.Screen.MENU:
   if not old_pause_intact():return
   paused_world=float(host.sim.clock.world_time);menu_seen=elapsed;stage="menu_hold"
   lifecycle["menu_world_time"]=paused_world;lifecycle["paused_cache_retained"]=true
   menu_capture()
 elif stage=="menu_hold":
  if entry.screen!=entry.Screen.MENU or not old_pause_intact():return
  if elapsed-menu_seen<.15 or not captures.has("menu_paused"):return
  if entry._start.disabled or not entry._start.visible:fail("new_run_start_button_unavailable");return
  stage="confirm_new_run";entry._start.pressed.emit()
 elif stage=="confirm_new_run":
  if entry.screen!=entry.Screen.CONFIRM:fail("expected_real_new_run_confirmation");return
  if not old_pause_intact():return
  if entry._confirm.disabled or not entry._confirm.visible:fail("new_run_confirm_button_unavailable");return
  stage="new_run_transition";entry._confirm.pressed.emit()
 elif stage=="new_run_transition":
  if entry.screen==entry.Screen.MENU:fail("new_run_recovered_to_old_menu");return
  if entry.screen==entry.Screen.RUN and is_instance_valid(entry.active_room):
   if terminal.is_empty() or not bool(lifecycle.get("old_cache_empty_at_terminal",false)):fail("new_run_without_old_terminal_cleanup");return
   stage="fresh_run"
 elif stage=="fresh_run" and not fresh_capture_pending:
  fresh_capture_pending=true;check_fresh_frame()

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
  h08_selected=true;print("WAVE_H08_SELECTED ordinary_UI=true")
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
 if lifecycle_start>=0.0:lifecycle_step();return false
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
  print("WAVE_ROUTE_PROGRESS room=",last_progress_room," elapsed=",elapsed," HP=",host.sim.hero.hp)
 normal_route_tick()
 return false
