extends "res://tests/ink_style_specimen_20261004/revision19_actor05/fix04/hero_view.gd"
## Isolated presentation candidate. Source clocks, actions and positions are read only.
const Heading5=preload("res://tests/ink_style_specimen_20261004/revision19_actor05/fix05/heading_turn.gd")
const TurnLower5=preload("res://tests/ink_style_specimen_20261004/revision19_actor05/fix05/turn_lower.gd")
const STOP_CHEST_SECONDS5:=.12
const NIB_FORWARD_DOT5:=.35
var desired_visual_yaw:=0.0
var visual_aim_requested:=false
var rest_chest_basis5:=Basis.IDENTITY
var upper_from_world5:=Basis.IDENTITY
var upper_from_world_valid5:=false
var stop_chest_started5:=-1.0
var stop_chest_from_world5:=Basis.IDENTITY
var last_signature5: Dictionary={}
func _ready() -> void:
	super._ready()
	if proof.status=="HOLD":return
	lower_motion=TurnLower5.new()
	var rest: Array[Transform3D]=_capture()
	rest_chest_basis5=_global_pose(rest,chest_index).basis
	proof["motion_revision"]="revision19_actor05_fix05_bounded_turn"
	proof["new_presentation_parameters"]={"root_degrees_per_source_second":720.0,"chest_degrees_per_source_second":1080.0,"chest_relative_lower_limit_degrees":65.0,"stop_chest_seconds":.12,"stationary_turn_seconds":.25,"free_foot_height_m":.06,"bridge_joint_yaw_limits_degrees":[70.0,45.0,25.0],"bridge_nib_forward_dot":NIB_FORWARD_DOT5,"gameplay_changed":false,"native_visual_acceptance":false}
func _prepare_source_clock(ink: Dictionary) -> void:
	var before5:=clock_diagnostics.size()
	super._prepare_source_clock(ink)
	if before5!=clock_diagnostics.size():
		last_signature5.clear();upper_from_world_valid5=false;stop_chest_started5=-1.0;visual_aim_requested=false;desired_visual_yaw=0.0
func _chest_finish5(poses: Array[Transform3D], previous_world: Basis, has_previous: bool, now: float, dt: float, walking: bool, aiming: bool, aim: Vector3) -> Dictionary:
	var result: Array[Transform3D]=poses.duplicate()
	var world: Basis=skeleton.global_basis
	var desired: Basis=world*_global_pose(result,chest_index).basis
	var stop_alpha:=1.0
	if not walking and not aiming and stop_chest_started5>=0.0:
		stop_alpha=clampf((now-stop_chest_started5)/STOP_CHEST_SECONDS5,0.0,1.0)
		if stop_alpha<=0.0:desired=stop_chest_from_world5
		elif stop_alpha<1.0:desired=stop_chest_from_world5.slerp(desired,stop_alpha*stop_alpha*(3.0-2.0*stop_alpha))
	var lower_yaw:=Heading5.logical_yaw(world*_global_pose(result,pelvis_index).basis,rest_pelvis_basis)
	var requested:=Heading5.logical_yaw(desired,rest_chest_basis5)
	var relative:=wrapf(requested-lower_yaw,-PI,PI)
	var target:=lower_yaw+clampf(relative,-Heading5.TORSO_LIMIT_RADIANS,Heading5.TORSO_LIMIT_RADIANS)
	var previous_yaw:=Heading5.logical_yaw(previous_world,rest_chest_basis5) if has_previous else target
	var turn: Dictionary=Heading5.advance(previous_yaw,target,dt,Heading5.CHEST_RADIANS_PER_SECOND) if has_previous else {"yaw":target,"rate_limited":false,"applied_radians":0.0}
	var rate_yaw:=float(turn.yaw)
	var final_relative:=clampf(wrapf(rate_yaw-lower_yaw,-PI,PI),-Heading5.TORSO_LIMIT_RADIANS,Heading5.TORSO_LIMIT_RADIANS)
	var final_yaw:=lower_yaw+final_relative
	var safety_projection:=wrapf(final_yaw-rate_yaw,-PI,PI)
	var correction:=wrapf(final_yaw-requested,-PI,PI)
	if correction!=0.0:desired=Basis(Vector3.UP,correction)*desired
	_set_global_basis(result,chest_index,world.inverse()*desired)
	var actual_world: Basis=world*_global_pose(result,chest_index).basis
	var actual_yaw:=Heading5.logical_yaw(actual_world,rest_chest_basis5)
	var limit_used:=absf(relative)>Heading5.TORSO_LIMIT_RADIANS or bool(turn.rate_limited) or safety_projection!=0.0
	var report: Dictionary={"limited":limit_used,"requested_world_yaw":requested,"actual_world_yaw":actual_yaw,"actual_lower_world_yaw":lower_yaw,"actual_relative_lower_yaw":wrapf(actual_yaw-lower_yaw,-PI,PI),"source_aim_yaw":atan2(aim.x,aim.z),"source_aim_residual":wrapf(atan2(aim.x,aim.z)-actual_yaw,-PI,PI),"stop_alpha":stop_alpha,"source_delta":dt,"previous_actual_world_yaw":previous_yaw,"yaw_rate":turn,"safety_projection_radians":safety_projection,"current_chest_origin_preserved":result[chest_index].origin==poses[chest_index].origin,"source_direction_modified":false,"all_turns_accepted":false}
	return {"poses":result,"report":report}
func _cast_hand_bridge5(poses: Array[Transform3D], aim: Vector3, released: bool, heading_limited: bool) -> Dictionary:
	var result: Array[Transform3D]=poses.duplicate()
	var report: Dictionary={"active_release":released,"applied":false,"source_changed":false,"grip_local_hierarchy_retained":true,"visual_acceptance":false}
	if not released or not _valid_direction(aim):return {"poses":result,"report":report}
	var brush_index:=skeleton.find_bone("brush")
	var world:=skeleton.global_basis
	var nib: Vector3=-(world*_global_pose(result,brush_index).basis).y
	var horizontal:=Vector3(nib.x,0,nib.z)
	if horizontal.length_squared()==0.0:return {"poses":result,"report":report.merged({"HOLD":"vertical_nib_horizontal_heading_unproven"})}
	var front:=Vector3(aim.x,0,aim.z).normalized()
	var before_dot:=horizontal.normalized().dot(front)
	report["nib_forward_dot_before"]=before_dot
	if (heading_limited or before_dot<0.0) and before_dot<NIB_FORWARD_DOT5:
		var nib_yaw:=atan2(nib.x,nib.z)
		var error:=wrapf(atan2(front.x,front.z)-nib_yaw,-PI,PI)
		var correction:=error-signf(error)*acos(NIB_FORWARD_DOT5)
		var parts: Array=[]
		for row: Array in [["upper_arm_R",.55,70.0],["forearm_R",.30,45.0],["hand_R",.15,25.0]]:
			var index:=skeleton.find_bone(str(row[0]));var requested: float=correction*float(row[1])
			var applied:=clampf(requested,-deg_to_rad(float(row[2])),deg_to_rad(float(row[2])))
			var prior: Basis=world*_global_pose(result,index).basis
			_set_global_basis(result,index,world.inverse()*Basis(Vector3.UP,applied)*prior)
			parts.append({"bone":row[0],"applied_world_yaw":applied,"limit_degrees":row[2]})
		report["applied"]=true;report["parts"]=parts
	var after_nib: Vector3=-(world*_global_pose(result,brush_index).basis).y
	var after_horizontal:=Vector3(after_nib.x,0,after_nib.z)
	report["nib_forward_dot_after"]=after_horizontal.normalized().dot(front) if after_horizontal.length_squared()>0.0 else -1.0
	report["nib_is_in_forward_hemisphere"]=float(report.nib_forward_dot_after)>=0.0
	report["all_local_origins_unchanged"]=true
	for index in range(result.size()):
		if result[index].origin!=poses[index].origin:report.all_local_origins_unchanged=false
	return {"poses":result,"report":report}

func present(ink: Dictionary) -> void:
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
	sample_report={"motion_revision":"revision19_actor05_fix05_bounded_turn","base":base,"base_time":base_time,"base_key_first":base_window.first,"base_key_span":base_window.span,"gait_elapsed_absolute":gait_time,"gait_cursor_signed":gait_cursor,"upper":next_upper,"upper_time":upper_time,"upper_source_age":upper_age,"upper_source_started":source_started,"transition_source_started":transition_source_at,"transition_source_age":transition_age,"weight":previous_upper_weight,"blend_origin":"previous actually rendered pose; source-aged","source_time":now,"actual_displacement":distance,"source_delta":dt,"repeated_source_time":repeated_source_time,"same_time_stop_input":same_time_stop_input,"same_time_dash_started":same_time_dash_started,"source_clock_diagnostic_count":clock_diagnostics.size(),"received_event_serial":received_event_serial,"received_event_kind":received_event_kind,"observed_dash_left":float(hero.get("dash_left",0.0)),"base_reset_before_sample":true,"authored_gait_reference_mps":AUTHORED_GAIT_REFERENCE_MPS,"walk_playback_ratio":distance/maxf(.000001,dt)/AUTHORED_GAIT_REFERENCE_MPS if walking else 0.0,"direction_plan":plan,"direction_layer":direction_evidence,"directional_animation_scope":"bounded visual heading, supported stationary turn and emergency cast bridge candidate; no turn/diagonal art acceptance","consumed_direction_samples":consumed_direction_samples.duplicate(true),"source_motion_modified":false,"lower_transition":lower_transition,"received_view_input":received_view_input.duplicate(true),"public_release_direction_field":"front_direction","valid_release_direction_count":valid_release_direction_count,"boundary_authority_sha256":BOUNDARIES05_SHA,"actor_asset_sha256":MODEL_SHA,"direction_diagnostic_count":direction_diagnostics.size(),"last_direction_diagnostic":direction_diagnostics.back() if not direction_diagnostics.is_empty() else {},"sampled_bones":bone_sample_evidence()}

	if next_upper in ["q1_draw_upper","q1_hold_upper"] and _valid_direction(aim):proven_direction=aim

	last_move_intent=current_intent;last_dash_left=current_dash
	presented_event_serial=received_event_serial
	last_signature5=signature.duplicate(true)
	sample_report["pose_cache_reused"]=false
