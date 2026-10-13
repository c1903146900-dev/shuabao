extends "res://tests/ink_style_specimen_20261004/revision19_actor05/fix07/hero_view.gd"
const C03VisualSource=preload("res://visual_rework_20261009/binding/c03_visual_source_successor.gd")
## Isolated actor-view seam. Presentation reads snapshots; never owns source time.
const Q3_MODEL_PATH := "res://tests/ink_q3_gesture_runtime_20261004/assets/yanguizhou_q3_gestures.glb"
const Q3_MODEL_SHA := "a41f04eca11416a1908caa6afc681afd2d3493b1470b402cd8ac4abd8d941bc2"
const Q3_BOUNDARIES := "res://tests/ink_q3_gesture_runtime_20261004/source_boundaries.json"
const Q3_BOUNDARIES_SHA := "a53b026fbcd18471cd2b873dd295b98b50a0c6093e01c140f733096581df780e"
const Q3_BINDING_PATH := "res://tests/ink_q3_foundation_20261004/fix02/source_binding.json"
const Q3_BINDING_SHA := "9a5f18b7249cd40efe8ef4047d5cfa8584b99e0668b0c1d437304d670b952727"
const Q3_CLIPS := ["q3_raise_press_upper","q3_collapse_cut_upper"]
var q3_event: Dictionary = {}
var q3_seen: Dictionary = {}
var q3_diagnostics: Array = []
var q3_bound := false
var q3_last_owner := ""

func _ready() -> void:
 set_process(false)
 if not ResourceLoader.exists(Q3_MODEL_PATH):
  proof.errors.append("missing_original_character_glb")
  proof.status = "HOLD"
  return
 proof.asset_sha256=FileAccess.get_sha256(Q3_MODEL_PATH)
 if proof.asset_sha256!=Q3_MODEL_SHA:
  proof.errors.append("character_bytes_changed_require_new_review");proof.status="HOLD";return
 var scene: PackedScene = load(Q3_MODEL_PATH)
 var visual := scene.instantiate()
 add_child(visual)
 _scan(visual)
 if player == null or skeleton == null:
  proof.errors.append("missing_imported_rig_or_player")
  proof.status = "HOLD"
  return
 player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 for animation_name: StringName in player.get_animation_list():
  var short_name := str(animation_name).get_slice("/",str(animation_name).get_slice_count("/")-1)
  if short_name in MODEL_CLIPS:clip_names[short_name] = animation_name
 var isolated_library:=AnimationLibrary.new()
 player.add_animation_library("specimen_filtered_layers",isolated_library)
 var animation_root: Node=player.get_node_or_null(player.root_node)
 for clip: String in MODEL_CLIPS:
  if not clip_names.has(clip):
   proof.errors.append("missing_clip:"+clip)
   continue
  var raw_name: StringName=clip_names[clip]
  var animation: Animation=player.get_animation(raw_name)
  var raw_tracks: Array=[]
  for index in range(animation.get_track_count()):raw_tracks.append(Filter.track_evidence(animation,index))
  proof.raw_import_clips[clip]={"imported_name":str(raw_name),"actual_length":animation.length,"tracks":raw_tracks}
  var tracks: Array=raw_tracks
  if clip.ends_with("_upper") or clip in DIRECTIONAL_LOWER:
   var mask: Array=LOWER05 if clip in DIRECTIONAL_LOWER else UPPER
   var result: Dictionary=Filter.inspect_copy(animation,skeleton,animation_root,mask)
   var local: Animation=result.animation
   result.erase("animation")
   proof.filter_evidence[clip]=result
   for error in result.errors:proof.errors.append(clip+":"+str(error))
   if result.errors.is_empty():
    isolated_library.add_animation(clip,local)
    clip_names[clip]=StringName("specimen_filtered_layers/"+clip)
    tracks=result.kept_tracks
    proof.removed_exact_rest_tracks+=result.removed_tracks.size()
   for row: Dictionary in tracks:
    if str(row.bone) not in mask:proof.errors.append("retained_off_whitelist:"+clip+":"+str(row.path))
  proof.clips[clip]={"imported_name":str(clip_names[clip]),"actual_length":animation.length,"tracks":tracks}
 proof.filter_policy="local copied upper/lower layer filters; single-key exact actual rest; authored-zero values unchanged"
 proof.original_asset_unchanged=FileAccess.get_sha256(Q3_MODEL_PATH)==Q3_MODEL_SHA
 proof.bone_count = skeleton.get_bone_count()
 proof.restored_before_every_sample = true
 proof.status = "import_structure_checked_not_visual_acceptance" if proof.errors.is_empty() else "HOLD"
 if proof.status=="HOLD":return
 proof["asset_path"]=Q3_MODEL_PATH
 for clip: String in MODEL_CLIPS:
  key_windows[clip]=key_window(player.get_animation(clip_names[clip]))
  if not key_windows[clip].valid:proof.errors.append("no_positive_dynamic_key_window:"+clip)
 pelvis_index=skeleton.find_bone("pelvis");chest_index=skeleton.find_bone("chest")
 if pelvis_index<0 or chest_index<0:proof.errors.append("missing_direction_layer_bones")
 if not proof.errors.is_empty():proof.status="HOLD";return
 _bind_model_boundary()
 proof["motion_revision"]="revision19_actor05_directional_candidate"
 proof["settling_policy"]={"stop_source_seconds":STOP_BLEND_SECONDS,"start_source_seconds":START_BLEND_SECONDS,"begins_previous_rendered_pose":true,"foot_lock_claim":false,"world_translation_affected":false}
 proof["bone_and_native_comparison"]="pending actor05 actual normal-input/foot-target comparison"
 proof["algorithm_reuse"]="frozen source/event/duplicate-frame behavior and strict old-six prefix algorithm; independent05 data and unchanged authored-zero new clips"

 if FileAccess.get_sha256(CONTRACT_PATH)!=CONTRACT_SHA:
  proof.errors.append("directional_contract_bytes_changed");proof.status="HOLD";return
 directional_contract=JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH))
 leg_lengths=directional_contract.actual_leg_chain_limits.duplicate(true)
 skeleton.reset_bone_poses()
 var rest: Array[Transform3D]=_capture()
 rest_pelvis_basis=_global_pose(rest,pelvis_index).basis
 proof["directional_contract_sha256"]=CONTRACT_SHA
 proof["positive_phase_only"]=true
 proof["diagonal_contact_accepted"]=false
 proof["natural_settling_accepted"]=false

 # Exact fix05/fix06 initialization after the independent asset binding.
 lower_motion=VisibleTurnLower6.new()
 rest_chest_basis5=_global_pose(rest,chest_index).basis
 proof["new_presentation_parameters"]={"root_degrees_per_source_second":720.0,"chest_degrees_per_source_second":1080.0,"chest_relative_lower_limit_degrees":65.0,"stationary_turn_start_min_degrees":5.0}
 _bind_q3_clips()

func _bind_model_boundary() -> void:
 if FileAccess.get_sha256(Q3_BOUNDARIES)!=Q3_BOUNDARIES_SHA:
  proof.errors.append("model05_boundary_authority_changed");proof.status="HOLD";return
 var authority: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Q3_BOUNDARIES))
 if authority.asset_sha256!=Q3_MODEL_SHA:
  proof.errors.append("model05_boundary_asset_mismatch");proof.status="HOLD";return
 var before:=key_windows.duplicate(true)
 var library:=AnimationLibrary.new();player.add_animation_library("specimen05_source_windows",library)
 var animation_root: Node=player.get_node_or_null(player.root_node)
 for clip: String in MODEL_CLIPS:
  var original: Animation=player.get_animation(clip_names[clip])
  if clip in DIRECTIONAL_LOWER:
   var inspected: Dictionary=AuthoredZero.inspect(original,authority.clips[clip],skeleton,animation_root)
   zero_clip_proof[clip]=inspected
   for error in inspected.errors:proof.errors.append(clip+":"+str(error))
   # Genuine zero and all other imported values remain exactly untouched.
   key_windows[clip]=key_window(original)
  else:
   var inspected: Dictionary=BoundaryRepair.inspect_copy(original,authority.clips[clip],skeleton,animation_root)
   var repaired: Animation=inspected.animation;inspected.erase("animation")
   boundary_proof[clip]=inspected
   for error in inspected.errors:proof.errors.append(clip+":"+str(error))
   if inspected.errors.is_empty():
    library.add_animation(clip,repaired);clip_names[clip]=StringName("specimen05_source_windows/"+clip)
    key_windows[clip]=key_window(repaired)
 proof["boundary_repair"]={"authority_sha256":Q3_BOUNDARIES_SHA,"source_asset_sha256":Q3_MODEL_SHA,"before_windows":before,"after_windows":key_windows.duplicate(true),"old_six":boundary_proof,"new_authored_zero":zero_clip_proof,"no_epsilon":true,"original_resources_changed":false,"new_zero_source_value_equivalence_accepted":false}
 proof["key_windows"]=key_windows.duplicate(true)
 if not proof.errors.is_empty():proof.status="HOLD"

func present(ink: Dictionary) -> void:
 var mode: String = str(presentation_context.get("phase", ""))
 var matching: bool = presentation_context.get("schema", "") == "safe-locomotion-presentation-1" and presentation_context.get("scope", {}) == ink.get("scope", {})
 var next_instance: int = int(presentation_context.get("instance_id", -1))
 if matching and _safe_instance7 >= 0 and next_instance != _safe_instance7:
  _reset_instance_view7()
 if matching:
  var context_elapsed: float = float(presentation_context.get("safe_elapsed", 0.0))
  _context_previous_elapsed7 = _context_last_elapsed7 if _context_instance7 == next_instance and _context_scope7 == ink.get("scope", {}) else context_elapsed
  _context_instance7 = next_instance; _context_scope7 = ink.get("scope", {}).duplicate(true)
  _context_last_elapsed7 = context_elapsed; _safe_instance7 = next_instance
 if matching and mode in ["preparation", "victory"]:
  q3_event.clear(); q3_last_owner = "safe_phase_retirement"
  _present_safe7(ink)
  return
 if _safe_active7:
  # Do not subtract safe presentation seconds from a combat source timestamp.
  last_time = _safe_last_source7
  lower_motion.reset(); stop_chest_started5 = -1.0; last_signature5.clear()
  _safe_active7 = false; _safe_signature7.clear()
 _present_combat_q3(ink)


func _present_combat_q3(ink: Dictionary) -> void:
 _prepare_source_clock(ink)
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
 if blend_from_pose.size()==target_pose.size() and alpha<1.0:
  # Chest is rebased against CURRENT base parents, not old pelvis/spine.
  var from_chest: Basis=skeleton.global_basis.inverse()*upper_from_world5 if upper_from_world_valid5 else _global_pose(blend_from_pose,chest_index).basis
  var rebased: Array[Transform3D]=target_pose.duplicate()
  for index in range(target_pose.size()):
   if str(skeleton.get_bone_name(index)) in UPPER:rebased[index]=blend_from_pose[index]
  _set_global_basis(rebased,chest_index,from_chest)
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

var q3_source_control: Dictionary = {}
var q3_source_instance := -1
var q3_latest_owner_sequence := -1
var q3_latest_owner_scope: Dictionary = {}

func set_source_control_state(value: Dictionary) -> void:
 if value.get("schema","") != "q3-source-control-view-1": return
 var instance: int = int(value.get("instance_id",-1))
 if instance < 0: return
 if q3_source_instance >= 0 and instance != q3_source_instance: _reset_instance_view7()
 q3_source_instance = instance
 q3_source_control = value.duplicate(true)

func _q3_control_cleanup(ink: Dictionary) -> void:
 if q3_event.is_empty(): return
 var now: float = float(ink.get("source_time",0.0))
 # A real current dash onset owns the pose only; its surviving terrain stays live.
 if float(ink.get("hero",{}).get("dash_left",0.0)) > 0.0 and last_dash_left <= 0.0:
  _retire_q3_visual("actual_dash_onset_visual_only",now); return
 # The detached read must belong to this exact instance/scope/time and be at or
 # after this accepted receipt's sequence. An old stun read cannot cancel a new
 # legal cast after recovery, even if both are delivered before one draw.
 if q3_source_control.get("instance_id",-1) != q3_source_instance or q3_source_control.get("scope",{}) != ink.get("scope",{}) or q3_source_control.get("source_time",-1.0) != now: return
 if int(q3_source_control.get("source_sequence",-1)) < int(q3_event.get("sequence",0)): return
 if float(q3_source_control.get("stun_left",0.0)) > 0.0 or bool(q3_source_control.get("dead",false)):
  _retire_q3_visual("actual_control_or_death_visual_only",now)

func _bind_q3_clips() -> void:
 if FileAccess.get_sha256(Q3_BINDING_PATH) != Q3_BINDING_SHA:
  proof.errors.append("Q3_exact_source_binding_changed")
 var binding: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Q3_BINDING_PATH))
 for path: String in binding.get("files",{}):
  var expected:String=C03VisualSource.expected_sha(path,str(binding.files[path]))
  if expected.is_empty() or FileAccess.get_sha256("res://"+path) != expected: proof.errors.append("Q3_source_file_changed:"+path)
 var settings := ConfigFile.new()
 if settings.load(Q3_MODEL_PATH+".import") != OK or int(settings.get_value("params","animation/fps",-1)) != 30 or settings.get_value("params","animation/remove_immutable_tracks",null) != true:
  proof.errors.append("Q3_import_settings_mismatch")
 var authority: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Q3_BOUNDARIES))
 var lib := AnimationLibrary.new()
 player.add_animation_library("q3_rotation_only",lib)
 var animation_root: Node = player.get_node_or_null(player.root_node)
 var evidence: Dictionary = {}
 for clip: String in Q3_CLIPS:
  var found: StringName = &""
  for full_name: StringName in player.get_animation_list():
   if str(full_name).get_file() == clip: found = full_name; break
  if found == &"": proof.errors.append("Q3_clip_missing:"+clip); continue
  var raw: Animation = player.get_animation(found)
  var local: Animation = raw.duplicate(true)
  var removed: Array = []
  var raw_rows: Array = []
  var retained: Array = []
  for track in range(raw.get_track_count()-1,-1,-1):
   var row: Dictionary = Filter.track_evidence(raw,track)
   raw_rows.push_front(row)
   var path: NodePath = raw.track_get_path(track)
   var bone: String = str(row.bone)
   var index: int = skeleton.find_bone(bone)
   var target: Node = animation_root.get_node_or_null(NodePath(path.get_concatenated_names()))
   if target != skeleton or index < 0: proof.errors.append("Q3_wrong_track_target:"+str(path)); continue
   if int(row.type) == Animation.TYPE_ROTATION_3D and bone in UPPER:
    if not authority.clips[clip].tracks.has(bone+":rotation"): proof.errors.append("Q3_rotation_without_source:"+bone)
    elif int(row.key_count) < 1 or raw.track_get_key_time(track,0) != 0.0: proof.errors.append("Q3_genuine_t0_missing:"+bone)
    retained.push_front(row)
    continue
   var rest: Transform3D = skeleton.get_bone_rest(index)
   var expected: Variant = rest.origin if int(row.type) == Animation.TYPE_POSITION_3D else rest.basis.get_rotation_quaternion() if int(row.type) == Animation.TYPE_ROTATION_3D else rest.basis.get_scale() if int(row.type) == Animation.TYPE_SCALE_3D else null
   if int(row.key_count) != 1 or not Filter.exact_rest_value(raw.track_get_key_value(track,0),expected):
    proof.errors.append("Q3_nonrotation_or_lower_authority:"+str(path)); continue
   local.remove_track(track); removed.append(row)
  for key: String in authority.clips[clip].tracks:
   if bool(authority.clips[clip].tracks[key].all_values_identical): continue
   var bone: String = str(authority.clips[clip].tracks[key].bone)
   if not retained.any(func(row): return str(row.bone)==bone): proof.errors.append("Q3_dynamic_source_channel_dropped:"+bone)
  var inspected: Dictionary = AuthoredZero.inspect(local,authority.clips[clip],skeleton,animation_root)
  for error: String in inspected.errors: proof.errors.append(clip+":"+error)
  lib.add_animation(clip,local)
  clip_names[clip] = StringName("q3_rotation_only/"+clip)
  key_windows[clip] = key_window(local)
  if local.loop_mode != Animation.LOOP_NONE: proof.errors.append("Q3_must_not_loop:"+clip)
  var after: Array = []
  for track in range(raw.get_track_count()): after.append(Filter.track_evidence(raw,track))
  if after != raw_rows: proof.errors.append("Q3_imported_resource_mutated:"+clip)
  evidence[clip] = {"source_rotation_channels":26,"raw_imported_track_count":raw.get_track_count(),"rotation_tracks_retained":retained.size(),"removed_exact_rest_fillers":removed,"immutable_source_channels_may_be_absent":true,"authored_zero":inspected,"key_window":key_windows[clip],"raw_resource_unchanged":after==raw_rows}
 q3_bound = proof.errors.is_empty()
 if not q3_bound: proof.status = "HOLD"
 proof["q3_import"] = evidence
 proof["q3_source_binding_sha256"] = Q3_BINDING_SHA
 proof["q3_art_accepted"] = false
 proof["q3_entry_blend_seconds"] = .07
 skeleton.reset_bone_poses()

func _q3_scope(event: Dictionary) -> Dictionary:
 return {"room_id":event.get("room_id",""),"generation":event.get("generation",-1)}

func _q3_receipt_matches(event: Dictionary, ink: Dictionary) -> bool:
 if _q3_scope(event) != ink.get("scope",{}): return false
 var candidates: Array = ink.get("q3_finished",[]).duplicate(true)
 if not ink.get("mountain",{}).is_empty(): candidates.append(ink.mountain)
 var collapse: bool = event.get("kind","") == "ink_q3_collapse_started"
 for row: Dictionary in candidates:
  if _q3_scope(row) != _q3_scope(event) or row.get("terrain_id") != event.get("terrain_id") or row.get("cast_id") != event.get("cast_id"): continue
  var same := true
  for key: String in ["position","axis","born_at","expires_at","collapse_length","collapse_width"]:
   if row.get(key) != event.get(key): same = false
  if collapse:
   if row.get("reason","") != "collapsed" or row.get("finished_at",-1.0) != event.get("source_time",-2.0): same = false
   if event.get("length") != row.get("collapse_length") or event.get("width") != row.get("collapse_width"): same = false
  else:
   if row.get("length") != event.get("length") or row.get("width") != event.get("width"): same = false
  if same: return true
 return false

func _retire_q3_visual(reason: String, now: float) -> void:
 if event_action in Q3_CLIPS:
  event_action = ""; event_at = -1.0; event_identity = ""; cancel_at = now
 q3_event.clear()
 last_signature5.clear()
 q3_last_owner = reason

func receive(event: Dictionary, source_time: float) -> void:
 var kind: String = str(event.get("kind",""))
 if kind in ["ink_q3_raised","ink_q3_collapse_started"]:
  if not q3_bound or not event.has("sequence") or not event.has("source_time") or float(event.source_time) != source_time: return
  if _q3_scope(event) == q3_latest_owner_scope and int(event.sequence) <= q3_latest_owner_sequence: return
  q3_latest_owner_scope = _q3_scope(event); q3_latest_owner_sequence = int(event.sequence)
  var identity: String = JSON.stringify([event.get("room_id"),event.get("generation"),event.get("terrain_id"),kind,event.get("sequence")])
  if q3_seen.has(identity): return
  q3_seen[identity] = true
  received_event_serial += 1
  received_event_kind = kind; received_event_time = source_time; received_event_scope = _q3_scope(event)
  q3_event = event.duplicate(true)
  q3_event["view_identity"] = identity
  q3_event["view_serial"] = received_event_serial
  # Source acceptance is corroborated on the next detached post-transaction snapshot.
  return
 # A Q1 preview cancellation belongs to that preview, not a surviving Q3 source.
 var saved_action: String = event_action
 var saved_at: float = event_at
 var saved_identity: String = event_identity
 super.receive(event,source_time)
 if kind == "ink_q1_preview_cancelled" and saved_action in Q3_CLIPS:
  event_action = saved_action; event_at = saved_at; event_identity = saved_identity
 if kind in ["ink_basic_released","ink_q1_released","ink_q1_preview_started"]:
  q3_latest_owner_scope = _q3_scope(event); q3_latest_owner_sequence = int(event.get("sequence",q3_latest_owner_sequence))
  q3_event.clear(); q3_last_owner = kind
  if kind == "ink_q1_preview_started" and event_action in Q3_CLIPS: _retire_q3_visual(kind,source_time)
 if kind == "ink_q3_finished" and event.get("reason","") == "cast_cancelled" and not q3_event.is_empty():
  if _q3_scope(event) == _q3_scope(q3_event) and event.get("terrain_id") == q3_event.get("terrain_id"):
   _retire_q3_visual("matching_Q3_cast_cancelled",source_time)

func _prepare_source_clock(ink: Dictionary) -> void:
 var now: float = float(ink.get("source_time",0.0))
 var old_count: int = clock_diagnostics.size()
 var fresh_q3: bool = not q3_event.is_empty() and int(q3_event.get("view_serial",-1)) > presented_event_serial and _q3_scope(q3_event) == ink.get("scope",{}) and float(q3_event.source_time) <= now
 super._prepare_source_clock(ink)
 if old_count != clock_diagnostics.size():
  q3_seen.clear()
  if not fresh_q3: _retire_q3_visual("scope_or_rewind",now)
 if q3_event.is_empty(): return
 if _q3_scope(q3_event) != ink.get("scope",{}) or float(q3_event.source_time) > now:
  _retire_q3_visual("scope_or_future_receipt",now); return
 if not _q3_receipt_matches(q3_event,ink):
  q3_diagnostics.append({"reason":"unconfirmed_post_transaction_receipt","event":q3_event.duplicate(true)})
  _retire_q3_visual("uncorroborated",now); return
 if not q3_event.get("view_started",false):
  var collapse: bool = q3_event.kind == "ink_q3_collapse_started"
  var direction: Variant = q3_event.get("direction") if collapse else q3_event.get("axis")
  if not _valid_direction(direction): _retire_q3_visual("invalid_public_direction",now); return
  var horizontal := Vector3(direction.x,0,direction.z).normalized()
  if not collapse:
   var normal := Vector3(horizontal.z,0,-horizontal.x)
   var forward := Basis(Vector3.UP,last_visual_yaw)*Vector3.BACK if last_time >= 0.0 else Vector3(ink.hero.facing)
   if normal.dot(forward) < 0.0: normal = -normal
   horizontal = normal
  event_action = "q3_collapse_cut_upper" if collapse else "q3_raise_press_upper"
  event_at = float(q3_event.source_time); event_identity = str(q3_event.view_identity); event_direction = horizontal
  q3_event["view_started"] = true; q3_event["view_forward"] = horizontal
  q3_last_owner = str(q3_event.kind)
 if str(ink.get("input",{}).get("phase","")) in ["drawing","frozen"]:
  _retire_q3_visual("live_Q1_preview_priority",now)
 _q3_control_cleanup(ink)

func _reset_instance_view7() -> void:
 super._reset_instance_view7()
 q3_event.clear(); q3_seen.clear(); q3_source_control.clear(); q3_latest_owner_scope.clear(); q3_latest_owner_sequence = -1; q3_last_owner = "instance_reset"

func q3_runtime_report() -> Dictionary:
 return {"actor_asset_sha256":Q3_MODEL_SHA,"boundary_sha256":Q3_BOUNDARIES_SHA,"source_binding_sha256":Q3_BINDING_SHA,"latest_owner":q3_last_owner,"source_event":q3_event.duplicate(true),"source_age":float(sample_report.get("source_time",0.0))-float(q3_event.get("source_time",0.0)) if not q3_event.is_empty() else -1.0,"direction_policy":"raise transverse axis sign minimizes body turn; collapse exact source direction; existing bounded root/chest; Q3 hand bridge deferred pending shaft measurement","entry_blend_seconds":.07,"source_written":false,"art_accepted":false,"diagnostics":q3_diagnostics.duplicate(true)}
