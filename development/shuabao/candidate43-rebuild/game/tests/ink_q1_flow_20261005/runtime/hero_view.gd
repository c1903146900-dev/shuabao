extends "res://tests/ink_q3_gesture_runtime_20261004/fix01/hero_view.gd"
## Q1-only opt-in clips. Original Q3 visual meshes and lower compositor survive.
const FLOW_ROOT := "res://tests/ink_q1_flow_20261005/runtime/"
const FLOW_ASSET := FLOW_ROOT + "assets/yanguizhou_q1_flow.glb"
const FLOW_BINDING := FLOW_ROOT + "asset_binding.json"
const FLOW_ALIASES := {"q1_draw_upper":"q1_flow_draw_upper","q1_hold_upper":"q1_flow_hold_upper","q1_release_upper":"q1_flow_release_upper"}
const FLOW_RESIDUAL_SECONDS := .12
var flow_ready: bool = false
var flow_input: Dictionary = {}
var flow_binding: Dictionary = {}
var flow_diagnostics: Dictionary = {}

func _ready() -> void:
 super._ready()
 if proof.status == "HOLD": return
 if not FileAccess.file_exists(FLOW_BINDING):
  proof.errors.append("Q1_flow_asset_not_authored_and_bound"); proof.status="HOLD"; return
 var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(FLOW_BINDING))
 if not data is Dictionary or data.get("schema","") != "ink-q1-flow-asset-binding-1":
  proof.errors.append("Q1_flow_asset_binding_invalid"); proof.status="HOLD"; return
 flow_binding=data
 if FileAccess.get_sha256(FLOW_ASSET) != str(flow_binding.get("asset_sha256","")) or flow_binding.get("base_asset_sha256","") != Q3_MODEL_SHA:
  proof.errors.append("Q1_flow_exact_asset_mismatch"); proof.status="HOLD"; return
 var authority_path: String=FLOW_ROOT+"source_boundaries.json"
 if FileAccess.get_sha256(authority_path) != str(flow_binding.get("boundaries_sha256","")):
  proof.errors.append("Q1_flow_boundary_mismatch"); proof.status="HOLD"; return
 var authority: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(authority_path))
 var settings:=ConfigFile.new()
 if settings.load(FLOW_ASSET+".import") != OK or int(settings.get_value("params","animation/fps",-1)) != 30 or settings.get_value("params","animation/remove_immutable_tracks",null) != true:
  proof.errors.append("Q1_flow_import_settings_mismatch"); proof.status="HOLD"; return
 if not ResourceLoader.exists(FLOW_ASSET):
  proof.errors.append("Q1_flow_asset_unimported"); proof.status="HOLD"; return
 var packed: PackedScene=load(FLOW_ASSET)
 var temporary: Node=packed.instantiate()
 var incoming: AnimationPlayer=_flow_find_type(temporary,"AnimationPlayer")
 var incoming_skeleton: Skeleton3D=_flow_find_type(temporary,"Skeleton3D")
 if incoming == null or incoming_skeleton == null or incoming_skeleton.get_bone_count() != skeleton.get_bone_count():
  proof.errors.append("Q1_flow_imported_rig_missing"); temporary.free(); proof.status="HOLD"; return
 for index in range(skeleton.get_bone_count()):
  if incoming_skeleton.get_bone_name(index) != skeleton.get_bone_name(index) or incoming_skeleton.get_bone_parent(index) != skeleton.get_bone_parent(index) or incoming_skeleton.get_bone_rest(index) != skeleton.get_bone_rest(index):
   proof.errors.append("Q1_flow_rest_rig_changed:"+str(index))
 var library:=AnimationLibrary.new()
 player.add_animation_library("q1_flow_rotation_only",library)
 var animation_root: Node=player.get_node_or_null(player.root_node)
 var evidence: Dictionary={}
 for alias: String in FLOW_ALIASES:
  var source_name: String=FLOW_ALIASES[alias]
  var found: StringName=&""
  for full_name: StringName in incoming.get_animation_list():
   if str(full_name).get_file() == source_name: found=full_name; break
  if found == &"": proof.errors.append("Q1_flow_clip_missing:"+source_name); continue
  var raw: Animation=incoming.get_animation(found)
  var local: Animation=raw.duplicate(true)
  var raw_rows: Array=[]
  var retained: Array=[]
  for track in range(raw.get_track_count()-1,-1,-1):
   var row: Dictionary=Filter.track_evidence(raw,track)
   raw_rows.push_front(row)
   var path: NodePath=raw.track_get_path(track)
   var bone: String=str(row.bone)
   var index: int=skeleton.find_bone(bone)
   var target: Node=animation_root.get_node_or_null(NodePath(path.get_concatenated_names()))
   if target != skeleton or index < 0: proof.errors.append("Q1_flow_target_mismatch:"+str(path)); continue
   if int(row.type)==Animation.TYPE_ROTATION_3D and bone in UPPER:
    if not authority.clips[source_name].tracks.has(bone+":rotation") or int(row.key_count)<1 or raw.track_get_key_time(track,0)!=0.0:
     proof.errors.append("Q1_flow_missing_authored_rotation:"+bone)
    retained.push_front(row)
    continue
   var rest: Transform3D=skeleton.get_bone_rest(index)
   var expected: Variant=rest.origin if int(row.type)==Animation.TYPE_POSITION_3D else rest.basis.get_rotation_quaternion() if int(row.type)==Animation.TYPE_ROTATION_3D else rest.basis.get_scale() if int(row.type)==Animation.TYPE_SCALE_3D else null
   if int(row.key_count)!=1 or not Filter.exact_rest_value(raw.track_get_key_value(track,0),expected):
    proof.errors.append("Q1_flow_nonupper_authority:"+str(path)); continue
   local.remove_track(track)
  for key: String in authority.clips[source_name].tracks:
   if bool(authority.clips[source_name].tracks[key].all_values_identical): continue
   var bone: String=str(authority.clips[source_name].tracks[key].bone)
   if not retained.any(func(row): return str(row.bone)==bone): proof.errors.append("Q1_flow_dynamic_rotation_dropped:"+bone)
  var inspected: Dictionary=AuthoredZero.inspect(local,authority.clips[source_name],skeleton,animation_root)
  for error: String in inspected.errors: proof.errors.append(source_name+":"+error)
  library.add_animation(source_name,local)
  clip_names[alias]=StringName("q1_flow_rotation_only/"+source_name)
  key_windows[alias]=key_window(local)
  evidence[alias]={"source_clip":source_name,"retained_upper_rotations":retained.size(),"authored_zero":inspected,"key_window":key_windows[alias]}
 temporary.free()
 skeleton.reset_bone_poses()
 flow_ready=proof.errors.is_empty()
 if not flow_ready: proof.status="HOLD"
 proof["q1_flow"]={"asset_sha256":flow_binding.asset_sha256,"mesh_asset_unchanged":Q3_MODEL_SHA,"new_rotation_clips_only":true,"clips":evidence,"art_accepted":false}

func _flow_find_type(node: Node, type_name: String) -> Node:
 if node.is_class(type_name): return node
 for child: Node in node.get_children():
  var found: Node=_flow_find_type(child,type_name)
  if found != null: return found
 return null

func present(ink: Dictionary) -> void:
 flow_input=ink.get("input",{}).duplicate(true)
 super.present(ink)
 sample_report["q1_flow"]={"ready":flow_ready,"clip_aliases":FLOW_ALIASES,"frozen_draw_fraction":float(flow_input.get("draw_fraction",0.0)) if flow_input.get("phase","")=="frozen" else -1.0,"transition":flow_diagnostics.duplicate(true),"source_unchanged":true,"art_accepted":false}

func _sample(clip: String, at: float) -> Array[Transform3D]:
 if not flow_ready or clip != "q1_hold_upper": return super._sample(clip,at)
 # A length-frozen gesture can occur at any elapsed fraction. It keeps that
 # same authored draw pose. Only the small hold-loop delta is laid over it.
 var fraction: float=clampf(float(flow_input.get("draw_fraction",0.0)),0.0,1.0)
 var dw: Dictionary=key_windows.q1_draw_upper
 var result: Array[Transform3D]=super._sample("q1_draw_upper",float(dw.first)+float(dw.span)*fraction)
 var held_zero: Array[Transform3D]=super._sample("q1_hold_upper",0.0)
 var breathing: Array[Transform3D]=super._sample("q1_hold_upper",at)
 for index in range(result.size()):
  if str(skeleton.get_bone_name(index)) not in UPPER: continue
  var delta: Quaternion=breathing[index].basis.get_rotation_quaternion()*held_zero[index].basis.get_rotation_quaternion().inverse()
  result[index].basis=Basis(delta*result[index].basis.get_rotation_quaternion()).scaled(result[index].basis.get_scale())
 return result

func _reset_instance_view7() -> void:
 super._reset_instance_view7()
 flow_input.clear(); flow_diagnostics.clear()

func _present_combat_q3(ink: Dictionary) -> void:
 _prepare_source_clock(ink)
 flow_input=ink.get("input",{}).duplicate(true)
 if proof.status=="HOLD" or player==null or skeleton==null:return
 var signature: Dictionary={"scope":ink.get("scope",{}),"source_time":ink.get("source_time",0.0),"hero":ink.get("hero",{}),"input":ink.get("input",{}),"received":received_view_input,"event_serial":received_event_serial}
 if signature==last_signature5 and not last_rendered_pose.is_empty():
  sample_report=sample_report.duplicate(true)
  sample_report["repeated_source_time"]=true;sample_report["source_delta"]=0.0;sample_report["actual_displacement"]=0.0
  sample_report["same_time_stop_input"]=false;sample_report["same_time_dash_started"]=false;sample_report["pose_cache_reused"]=true
  if sample_report.direction_plan.has("root_turn"):
   sample_report.direction_plan.root_turn.applied_radians=0.0;sample_report.direction_plan.root_turn.source_delta=0.0
  if sample_report.direction_layer.has("chest_constraints"):
   sample_report.direction_layer.chest_constraints.source_delta=0.0
   sample_report.direction_layer.chest_constraints.yaw_rate.applied_radians=0.0
   sample_report.direction_layer.chest_constraints.yaw_rate.source_delta=0.0
  return
 var was_walking5: bool=previous_source_walking
 var prior_chest_valid5:=not last_rendered_pose.is_empty()
 var prior_chest_world5: Basis=last_skeleton_transform.basis*_global_pose(last_rendered_pose,chest_index).basis if prior_chest_valid5 else Basis.IDENTITY
 var hero: Dictionary=ink.get("hero",{})
 if not _valid_direction(proven_direction):
  var initial: Variant=hero.get("facing",null)
  if _valid_direction(initial):proven_direction=Vector3(initial.x,0,initial.z).normalized();event_direction=proven_direction
 var now:=float(ink.get("source_time",0.0))
 var at: Vector3=hero.get("position",Vector3.ZERO)
 var displacement:=at-last_position if last_position.is_finite() else Vector3.ZERO
 displacement.y=0.0
 var distance:=displacement.length()
 var dt:=maxf(0.0,now-last_time) if last_time>=0.0 else 0.0
 var repeated_source_time:=last_time>=0.0 and now==last_time
 var current_intent: Vector3=hero.get("move_intent",Vector3.ZERO)
 var current_dash:=float(hero.get("dash_left",0.0))
 var same_time_stop_input:=repeated_source_time and last_move_intent!=Vector3.ZERO and current_intent==Vector3.ZERO
 var same_time_dash_started:=repeated_source_time and last_dash_left<=0.0 and current_dash>0.0
 var walking:=previous_source_walking if repeated_source_time else distance>.0001 and dt>0.0 and current_dash<=0.0
 if same_time_stop_input or same_time_dash_started:walking=false
 if not repeated_source_time or same_time_stop_input or same_time_dash_started:previous_source_walking=walking
 if walking and dt>0.0:move_heading=displacement.normalized()
 elif last_time<0.0:move_heading=hero.get("facing",Vector3.BACK)
 position=at
 var input: Dictionary=ink.get("input",{})
 var phase:=str(input.get("phase",""))
 var next_upper:=""
 var next_key:=""
 var upper_age:=0.0
 var upper_time:=0.0
 var source_started:=now
 var aim: Vector3=hero.get("facing",move_heading)
 if phase in ["drawing","frozen"]:
  next_upper="q1_draw_upper" if phase=="drawing" else "q1_hold_upper"
  next_key=next_upper+":"+str(input.get("gesture_id",""))
  source_started=float(input.get("started_at",now)) if phase=="drawing" else float(input.get("frozen_at",now))
  upper_age=maxf(0.0,now-source_started)
  var window: Dictionary=key_windows[next_upper]
  upper_time=float(window.first)+float(window.span)*clampf(float(input.get("draw_fraction",0.0)),0.0,1.0) if phase=="drawing" else float(window.first)+fposmod(upper_age,float(window.span))
  aim=_preview_direction(input,at,aim)
  last_upper_end=now
 elif not event_action.is_empty() and event_at>=0.0 and now-event_at<float(key_windows[event_action].span):
  next_upper=event_action;next_key=event_action+":"+event_identity
  source_started=event_at;upper_age=maxf(0.0,now-event_at)
  upper_time=float(key_windows[next_upper].first)+upper_age
  aim=event_direction
  last_upper_end=event_at+float(key_windows[next_upper].span)
 var upper_active:=not next_upper.is_empty()
 # The root is not forced to travel direction while aiming; lower and upper
 # remain independent through strafe and backward travel, including clip fade.
 var has_tail:=not transition_key.is_empty() or (not blend_from_pose.is_empty() and now-transition_source_at<.08)
 var held_basic:=bool(received_view_input.get("held_basic",false))
 if upper_active:last_aim_direction=aim
 elif has_tail:aim=last_aim_direction
 elif held_basic:
  var received_aim: Variant=received_view_input.get("manual_direction",Vector3.INF)
  if _valid_direction(received_aim):proven_direction=received_aim
  if _valid_direction(proven_direction):aim=proven_direction;last_aim_direction=aim
 var directional_upper:=upper_active or has_tail or held_basic
 var target_root_yaw5:=atan2(aim.x,aim.z) if directional_upper else atan2(move_heading.x,move_heading.z)
 if not walking and not directional_upper and last_time>=0.0:target_root_yaw5=last_visual_yaw
 desired_visual_yaw=target_root_yaw5;visual_aim_requested=directional_upper
 var root_turn5: Dictionary=Heading5.advance(last_visual_yaw,target_root_yaw5,dt) if last_time>=0.0 else {"accepted":true,"yaw":target_root_yaw5,"target_yaw":target_root_yaw5,"applied_radians":0.0,"source_delta":0.0,"maximum_rate":Heading5.ROOT_RADIANS_PER_SECOND,"rate_limited":false,"remaining_radians":0.0}
 rotation.y=float(root_turn5.yaw)
 var local_move: Vector3=Basis(Vector3.UP,-rotation.y)*move_heading
 var choice: Dictionary=Phase.weights(local_move)
 var weights: Dictionary=choice.get("weights",{"walk":1.0})
 var dominant:="walk";var greatest:=-1.0
 for clip: String in weights:
  if float(weights[clip])>greatest:dominant=clip;greatest=float(weights[clip])
 var plan: Dictionary={"root_yaw":target_root_yaw5,"visual_root_yaw":rotation.y,"pelvis_yaw":0.0,"travel_sign":1.0,"movement_direction":move_heading,"aim_direction":aim,"world_stride_direction":move_heading,"stride_direction_error":0.0,"direction_weights":weights,"dominant_clip":dominant,"diagonal_unverified":bool(choice.get("diagonal",false)),"positive_phase_only":true,"weights_reference":"actual current visual root","held_basic_aim":held_basic,"committed_release_has_precedence":upper_active and next_upper in ["basic_upper","q1_release_upper"],"root_turn":root_turn5}
 var aim_yaw_delta:=wrapf(target_root_yaw5-rotation.y,-PI,PI) if directional_upper else 0.0
 if walking:stop_chest_started5=-1.0
 elif was_walking5 and prior_chest_valid5:
  stop_chest_started5=now;stop_chest_from_world5=prior_chest_world5
 if walking and dt>0.0:
  var authored_elapsed:=distance/AUTHORED_GAIT_REFERENCE_MPS
  gait_time+=authored_elapsed
  gait_cursor+=authored_elapsed
 var base:="walk" if walking else "idle"
 var base_window: Dictionary=key_windows[base]
 var base_time:=float(base_window.first)+fposmod(gait_cursor if walking else now,float(base_window.span))
 var phase05:=fposmod(gait_time,float(directional_contract.cycle_seconds))
 if walking:base_time=float(key_windows.walk.first)+minf(phase05,float(key_windows.walk.span))
 else:consumed_direction_samples.clear()
 var target_pose: Array[Transform3D]=_sample_directional_base(phase05,weights) if walking else _sample("idle",base_time)
 var idle_pose: Array[Transform3D]=_sample("idle",float(key_windows.idle.first))
 if upper_active:
  var overlay: Array[Transform3D]=_sample(next_upper,upper_time)
  for index in range(target_pose.size()):
   if str(skeleton.get_bone_name(index)) in UPPER:target_pose[index]=overlay[index]
 if absf(aim_yaw_delta)>0.0:
  # At stop alpha0 the root stays exactly on the previous rendered heading;
  # upper aim still follows the committed direction through a global basis turn.
  var aimed_chest:=_global_pose(target_pose,chest_index).basis
  var aim_turn: Basis=skeleton.global_basis.inverse()*Basis(Vector3.UP,aim_yaw_delta)*skeleton.global_basis
  _set_global_basis(target_pose,chest_index,aim_turn*aimed_chest)
 if next_key!=transition_key:
  transition_key=next_key
  transition_source_at=source_started if upper_active else maxf(cancel_at,last_upper_end)
  if transition_source_at<0.0:transition_source_at=now
  blend_from_pose=last_rendered_pose.duplicate()
  upper_from_world_valid5=prior_chest_valid5
  if prior_chest_valid5:upper_from_world5=prior_chest_world5
  if not blend_from_pose.is_empty():
   # Rebase the previous ACTUALLY rendered chest orientation into the new
   # root's coordinate frame before blending. Children keep their local pose.
   var prior_global:=_global_pose(last_rendered_pose,chest_index)
   var prior_in_current: Basis=skeleton.global_basis.inverse()*last_skeleton_basis*prior_global.basis
   _set_global_basis(blend_from_pose,chest_index,prior_in_current)
 var transition_age:=maxf(0.0,now-transition_source_at)
 var alpha:=clampf(transition_age/(.07 if upper_active else .08),0.0,1.0)
 var flow_release: bool=flow_ready and next_upper=="q1_release_upper"
 var flow_residual: float=1.0-smoothstep(0.0,FLOW_RESIDUAL_SECONDS,transition_age) if flow_release else 0.0
 if flow_release: alpha=1.0-flow_residual
 flow_diagnostics={"release":flow_release,"source_age":upper_age,"residual_weight":flow_residual,"duration":FLOW_RESIDUAL_SECONDS,"mechanic_delay":0.0}
 if blend_from_pose.size()==target_pose.size() and alpha<1.0:
  # Chest is rebased against CURRENT base parents, not old pelvis/spine.
  var from_chest: Basis=skeleton.global_basis.inverse()*upper_from_world5 if upper_from_world_valid5 else _global_pose(blend_from_pose,chest_index).basis
  var rebased: Array[Transform3D]=target_pose.duplicate()
  for index in range(target_pose.size()):
   if str(skeleton.get_bone_name(index)) in UPPER:rebased[index]=blend_from_pose[index]
  _set_global_basis(rebased,chest_index,from_chest)
  if flow_release:
   # Apply the authored motion immediately, carrying only the initial pose
   # mismatch as a fading residual. No frozen 70ms crossfade eats the press.
   var zero_overlay: Array[Transform3D]=super._sample("q1_release_upper",0.0)
   var zero_pose: Array[Transform3D]=target_pose.duplicate()
   for index in range(zero_pose.size()):
    if str(skeleton.get_bone_name(index)) in UPPER: zero_pose[index]=zero_overlay[index]
   if absf(aim_yaw_delta)>0.0:
    var zero_chest: Basis=_global_pose(zero_pose,chest_index).basis
    var zero_turn: Basis=skeleton.global_basis.inverse()*Basis(Vector3.UP,aim_yaw_delta)*skeleton.global_basis
    _set_global_basis(zero_pose,chest_index,zero_turn*zero_chest)
   for index in range(target_pose.size()):
    if str(skeleton.get_bone_name(index)) not in UPPER: continue
    var from_q: Quaternion=rebased[index].basis.get_rotation_quaternion()
    var zero_q: Quaternion=zero_pose[index].basis.get_rotation_quaternion()
    var mismatch: Quaternion=(from_q*zero_q.inverse()).normalized()
    var remaining: Quaternion=Quaternion.IDENTITY.slerp(mismatch,flow_residual)
    var current_q: Quaternion=target_pose[index].basis.get_rotation_quaternion()
    target_pose[index].basis=Basis((remaining*current_q).normalized()).scaled(target_pose[index].basis.get_scale())
  else:
   for index in range(target_pose.size()):
    if str(skeleton.get_bone_name(index)) in UPPER:target_pose[index]=rebased[index].interpolate_with(target_pose[index],alpha)
 direction_evidence={"pelvis_compensation_yaw":0.0,"new_directional_loops":true,"chest_global_aim_preserved":false}
 var lower: Dictionary=lower_motion.apply(self,target_pose,idle_pose,walking,now,phase05,("aim:" if directional_upper else "move:")+dominant,current_dash>0.0,source_started if upper_active else last_time)
 target_pose=lower.poses
 var lower_transition: Dictionary=lower.report
 var chest5: Dictionary=_chest_finish5(target_pose,prior_chest_world5,prior_chest_valid5,now,dt,walking,directional_upper,aim)
 target_pose=chest5.poses
 var hand5: Dictionary=_cast_hand_bridge5(target_pose,aim,upper_active and next_upper in ["basic_upper","q1_release_upper"],bool(chest5.report.limited) or bool(root_turn5.rate_limited))
 target_pose=hand5.poses
 direction_evidence["chest_global_aim_preserved"]=not bool(chest5.report.limited)
 direction_evidence["chest_constraints"]=chest5.report
 direction_evidence["cast_hand_bridge"]=hand5.report
 for index in range(target_pose.size()):skeleton.set_bone_pose(index,target_pose[index])
 last_rendered_pose=target_pose.duplicate();last_skeleton_basis=skeleton.global_basis;last_skeleton_transform=skeleton.global_transform
 previous_upper_weight=alpha if upper_active else 1.0-alpha if not blend_from_pose.is_empty() else 0.0
 active_upper=next_upper;last_position=at;last_time=now;last_visual_yaw=rotation.y
 sample_report={"motion_revision":"revision19_actor05_fix05_bounded_turn","base":base,"base_time":base_time,"base_key_first":base_window.first,"base_key_span":base_window.span,"gait_elapsed_absolute":gait_time,"gait_cursor_signed":gait_cursor,"upper":next_upper,"upper_time":upper_time,"upper_source_age":upper_age,"upper_source_started":source_started,"transition_source_started":transition_source_at,"transition_source_age":transition_age,"weight":previous_upper_weight,"blend_origin":"previous actually rendered pose; source-aged","source_time":now,"actual_displacement":distance,"source_delta":dt,"repeated_source_time":repeated_source_time,"same_time_stop_input":same_time_stop_input,"same_time_dash_started":same_time_dash_started,"source_clock_diagnostic_count":clock_diagnostics.size(),"received_event_serial":received_event_serial,"received_event_kind":received_event_kind,"observed_dash_left":float(hero.get("dash_left",0.0)),"base_reset_before_sample":true,"authored_gait_reference_mps":AUTHORED_GAIT_REFERENCE_MPS,"walk_playback_ratio":distance/maxf(.000001,dt)/AUTHORED_GAIT_REFERENCE_MPS if walking else 0.0,"direction_plan":plan,"direction_layer":direction_evidence,"directional_animation_scope":"bounded visual heading, supported stationary turn and emergency cast bridge candidate; no turn/diagonal art acceptance","consumed_direction_samples":consumed_direction_samples.duplicate(true),"source_motion_modified":false,"lower_transition":lower_transition,"received_view_input":received_view_input.duplicate(true),"public_release_direction_field":"front_direction","valid_release_direction_count":valid_release_direction_count,"boundary_authority_sha256":Q3_BOUNDARIES_SHA,"actor_asset_sha256":Q3_MODEL_SHA,"direction_diagnostic_count":direction_diagnostics.size(),"last_direction_diagnostic":direction_diagnostics.back() if not direction_diagnostics.is_empty() else {},"sampled_bones":bone_sample_evidence()}

 if next_upper in ["q1_draw_upper","q1_hold_upper"] and _valid_direction(aim):proven_direction=aim

 last_move_intent=current_intent;last_dash_left=current_dash
 presented_event_serial=received_event_serial
 last_signature5=signature.duplicate(true)
 sample_report["pose_cache_reused"]=false

