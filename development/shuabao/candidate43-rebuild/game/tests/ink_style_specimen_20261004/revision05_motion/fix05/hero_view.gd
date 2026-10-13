extends "res://tests/ink_style_specimen_20261004/revision09_actor04/hero_view.gd"
## Retain source-tick locomotion classification across duplicate draw samples.
## Actor04 import/boundary binding and fix04 transitions remain inherited.
var motion_scope: Dictionary={}
var has_motion_scope:=false
var previous_source_walking:=false
var last_move_intent:=Vector3.ZERO
var last_dash_left:=0.0
var clock_diagnostics: Array=[]
var received_event_serial:=0
var presented_event_serial:=0
var received_event_scope: Dictionary={}
var received_event_kind:=""
var received_event_time:=-1.0
var release_event_serial:=0
var release_event_scope: Dictionary={}
var release_event_time:=-1.0
func _ready() -> void:
	super._ready()
	proof["motion_revision"]="revision05_motion_fix05_actor04"
	proof["repeat_source_policy"]="hold lower classification/gait when source time repeats; keep event/upper evaluation active"
func receive(event: Dictionary, source_time: float) -> void:
	received_event_serial+=1
	received_event_kind=str(event.get("kind",""))
	received_event_time=source_time
	received_event_scope={"room_id":event.get("room_id",""),"generation":event.get("generation",-1)}
	if received_event_kind in ["ink_basic_released","ink_q1_released"]:
		release_event_serial=received_event_serial;release_event_scope=received_event_scope.duplicate(true);release_event_time=source_time
	super.receive(event,source_time)
func _prepare_source_clock(ink: Dictionary) -> void:
	var next_scope: Dictionary=ink.get("scope",{})
	var now:=float(ink.get("source_time",0.0))
	var reason:=""
	if has_motion_scope and next_scope!=motion_scope:reason="detached_scope_changed"
	elif last_time>=0.0 and now<last_time:reason="same_scope_source_clock_regressed"
	if not reason.is_empty():
		var keep_new_release:=release_event_serial>presented_event_serial and release_event_scope==next_scope and release_event_time<=now
		clock_diagnostics.append({"reason":reason,"old_scope":motion_scope.duplicate(true),"new_scope":next_scope.duplicate(true),"old_source_time":last_time,"new_source_time":now,"new_matching_release_retained":keep_new_release,"source_written":false})
		gait_time=0.0;gait_cursor=0.0;last_time=-1.0;last_position=Vector3.INF
		previous_source_walking=false;last_move_intent=Vector3.ZERO;last_dash_left=0.0;locomotion_mode="";lower_transition_pose.clear();lower_transition_started=now;lower_transition_duration=0.0
		root_stop_started=-1.0;root_stop_from=0.0;root_stop_target=0.0;retained_lower_world_yaw=0.0;last_visual_yaw=0.0
		active_upper="";transition_key="";transition_source_at=now;last_upper_end=-1.0;cancel_at=-1.0
		blend_from_pose.clear();last_rendered_pose.clear();previous_upper_pose.clear();previous_upper_weight=0.0
		var initial: Variant=ink.get("hero",{}).get("facing",null)
		proven_direction=Vector3(initial.x,0,initial.z).normalized() if _valid_direction(initial) else Vector3.INF
		if not keep_new_release:event_action="";event_at=-1.0;event_identity=""
		proof["source_clock_diagnostics"]=clock_diagnostics.duplicate(true)
	motion_scope=next_scope.duplicate(true);has_motion_scope=true
func present(ink: Dictionary) -> void:
	_prepare_source_clock(ink)
	if proof.status=="HOLD" or player==null or skeleton==null:return
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
	var plan:=direction_plan(move_heading,aim,directional_upper)
	if not walking and not directional_upper and last_time>=0.0:
		# A stationary action ending does not recall an old movement heading.
		plan.root_yaw=last_visual_yaw
	if not walking and locomotion_mode=="walk":
		root_stop_started=now;root_stop_from=last_visual_yaw;root_stop_target=float(plan.root_yaw)
	elif walking:root_stop_started=-1.0
	var root_alpha:=1.0
	if root_stop_started>=0.0 and now-root_stop_started<STOP_BLEND_SECONDS:
		root_alpha=clampf((now-root_stop_started)/STOP_BLEND_SECONDS,0.0,1.0)
		rotation.y=lerp_angle(root_stop_from,root_stop_target,root_alpha*root_alpha*(3.0-2.0*root_alpha))
	else:rotation.y=float(plan.root_yaw)
	plan["visual_root_yaw"]=rotation.y
	plan["stop_root_alpha"]=root_alpha
	var aim_yaw_delta:=wrapf(float(plan.root_yaw)-rotation.y,-PI,PI)
	var lower_yaw:=float(plan.pelvis_yaw)
	if walking:retained_lower_world_yaw=rotation.y+lower_yaw
	elif last_time>=0.0:lower_yaw=0.0 # target only; previous actual lower pose is retained at stop alpha0
	else:retained_lower_world_yaw=rotation.y
	plan["target_pelvis_yaw"]=lower_yaw
	plan["prior_lower_world_yaw"]=retained_lower_world_yaw
	plan["held_basic_aim"]=held_basic
	plan["committed_release_has_precedence"]=upper_active and next_upper in ["basic_upper","q1_release_upper"]
	if walking and dt>0.0:
		var authored_elapsed:=distance/AUTHORED_GAIT_REFERENCE_MPS
		gait_time+=authored_elapsed
		gait_cursor+=authored_elapsed*float(plan.travel_sign)
	var base:="walk" if walking else "idle"
	var base_window: Dictionary=key_windows[base]
	var base_time:=float(base_window.first)+fposmod(gait_cursor if walking else now,float(base_window.span))
	var target_pose: Array[Transform3D]=_sample(base,base_time)
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
		var from_chest:=_global_pose(blend_from_pose,chest_index).basis
		var rebased: Array[Transform3D]=target_pose.duplicate()
		for index in range(target_pose.size()):
			if str(skeleton.get_bone_name(index)) in UPPER:rebased[index]=blend_from_pose[index]
		_set_global_basis(rebased,chest_index,from_chest)
		for index in range(target_pose.size()):
			if str(skeleton.get_bone_name(index)) in UPPER:target_pose[index]=rebased[index].interpolate_with(target_pose[index],alpha)
	direction_evidence=_layer_direction(target_pose,lower_yaw)
	var lower_transition:=_blend_lower(target_pose,now,base)
	for index in range(target_pose.size()):skeleton.set_bone_pose(index,target_pose[index])
	last_rendered_pose=target_pose.duplicate();last_skeleton_basis=skeleton.global_basis
	previous_upper_weight=alpha if upper_active else 1.0-alpha if not blend_from_pose.is_empty() else 0.0
	active_upper=next_upper;last_position=at;last_time=now;last_visual_yaw=rotation.y
	sample_report={"motion_revision":"revision05_motion_fix05_actor04","base":base,"base_time":base_time,"base_key_first":base_window.first,"base_key_span":base_window.span,"gait_elapsed_absolute":gait_time,"gait_cursor_signed":gait_cursor,"upper":next_upper,"upper_time":upper_time,"upper_source_age":upper_age,"upper_source_started":source_started,"transition_source_started":transition_source_at,"transition_source_age":transition_age,"weight":previous_upper_weight,"blend_origin":"previous actually rendered pose; source-aged","source_time":now,"actual_displacement":distance,"source_delta":dt,"repeated_source_time":repeated_source_time,"same_time_stop_input":same_time_stop_input,"same_time_dash_started":same_time_dash_started,"source_clock_diagnostic_count":clock_diagnostics.size(),"received_event_serial":received_event_serial,"received_event_kind":received_event_kind,"observed_dash_left":float(hero.get("dash_left",0.0)),"base_reset_before_sample":true,"authored_gait_reference_mps":AUTHORED_GAIT_REFERENCE_MPS,"walk_playback_ratio":distance/maxf(.000001,dt)/AUTHORED_GAIT_REFERENCE_MPS if walking else 0.0,"direction_plan":plan,"direction_layer":direction_evidence,"directional_animation_scope":"bounded pelvis/chest layer with reverse imported gait, no authored strafe clip or planted-foot acceptance","source_motion_modified":false,"lower_transition":lower_transition,"received_view_input":received_view_input.duplicate(true),"public_release_direction_field":"front_direction","valid_release_direction_count":valid_release_direction_count,"boundary_authority_sha256":BOUNDARIES04_SHA,"actor_asset_sha256":ACTOR_SHA,"direction_diagnostic_count":direction_diagnostics.size(),"last_direction_diagnostic":direction_diagnostics.back() if not direction_diagnostics.is_empty() else {},"sampled_bones":bone_sample_evidence()}

	if next_upper in ["q1_draw_upper","q1_hold_upper"] and _valid_direction(aim):proven_direction=aim

	last_move_intent=current_intent;last_dash_left=current_dash
	presented_event_serial=received_event_serial
