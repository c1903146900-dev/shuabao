extends "res://tests/ink_style_specimen_20261004/revision05_motion/fix03/hero_view.gd"
## Bounded stop/start pose transition and read-only held-fire presentation intent.
const STOP_BLEND_SECONDS:=.16
const START_BLEND_SECONDS:=.10
var received_view_input: Dictionary={"held_basic":false,"manual_direction":Vector3.INF}
var locomotion_mode:=""
var lower_transition_started:=0.0
var lower_transition_duration:=0.0
var lower_transition_pose: Array[Transform3D]=[]
var lower_transition_world_basis:=Basis.IDENTITY
var retained_lower_world_yaw:=0.0
var last_visual_yaw:=0.0
var root_stop_started:=-1.0
var root_stop_from:=0.0
var root_stop_target:=0.0
func _ready() -> void:
	super._ready()
	proof["motion_revision"]="revision05_motion_fix04_glb03"
	proof["settling_policy"]={"stop_source_seconds":STOP_BLEND_SECONDS,"start_source_seconds":START_BLEND_SECONDS,"begins_previous_rendered_pose":true,"foot_lock_claim":false,"world_translation_affected":false}
func set_received_view_input(value: Dictionary) -> void:
	received_view_input=value.duplicate(true)
func _blend_lower(poses: Array[Transform3D], now: float, mode: String) -> Dictionary:
	var changed:=mode!=locomotion_mode
	if changed:
		locomotion_mode=mode
		lower_transition_started=now
		lower_transition_duration=STOP_BLEND_SECONDS if mode=="idle" else START_BLEND_SECONDS
		lower_transition_pose=last_rendered_pose.duplicate()
		lower_transition_world_basis=last_skeleton_basis
	var elapsed:=maxf(0.0,now-lower_transition_started)
	var alpha:=clampf(elapsed/maxf(.001,lower_transition_duration),0.0,1.0)
	var eased:=alpha*alpha*(3.0-2.0*alpha)
	if lower_transition_pose.size()==poses.size() and alpha<1.0:
		var desired_chest:=_global_pose(poses,chest_index).basis
		var prior: Array[Transform3D]=lower_transition_pose.duplicate()
		var prior_pelvis:=_global_pose(prior,pelvis_index).basis
		var rebased_pelvis: Basis=skeleton.global_basis.inverse()*lower_transition_world_basis*prior_pelvis
		_set_global_basis(prior,pelvis_index,rebased_pelvis)
		for index in range(poses.size()):
			if str(skeleton.get_bone_name(index)) not in UPPER:poses[index]=prior[index].interpolate_with(poses[index],eased)
		# Keep the upper action's committed orientation. Chest origin remains on
		# the smoothly changing lower/spine chain, rather than detaching the torso.
		_set_global_basis(poses,chest_index,desired_chest)
	return {"mode":mode,"changed":changed,"source_started":lower_transition_started,"source_elapsed":elapsed,"duration":lower_transition_duration,"alpha":alpha,"eased_alpha":eased,"from_previous_actual_rendered_pose":not lower_transition_pose.is_empty(),"root_translation_blended":false}
func present(ink: Dictionary) -> void:
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
	var walking:=distance>.0001 and dt>0.0 and float(hero.get("dash_left",0.0))<=0.0
	if walking:move_heading=displacement.normalized()
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
	if walking:
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
	sample_report={"motion_revision":"revision05_motion_fix04_glb03","base":base,"base_time":base_time,"base_key_first":base_window.first,"base_key_span":base_window.span,"gait_elapsed_absolute":gait_time,"gait_cursor_signed":gait_cursor,"upper":next_upper,"upper_time":upper_time,"upper_source_age":upper_age,"upper_source_started":source_started,"transition_source_started":transition_source_at,"transition_source_age":transition_age,"weight":previous_upper_weight,"blend_origin":"previous actually rendered pose; source-aged","source_time":now,"actual_displacement":distance,"source_delta":dt,"base_reset_before_sample":true,"authored_gait_reference_mps":AUTHORED_GAIT_REFERENCE_MPS,"walk_playback_ratio":distance/maxf(.000001,dt)/AUTHORED_GAIT_REFERENCE_MPS if walking else 0.0,"direction_plan":plan,"direction_layer":direction_evidence,"directional_animation_scope":"bounded pelvis/chest layer with reverse imported gait, no authored strafe clip or planted-foot acceptance","source_motion_modified":false,"lower_transition":lower_transition,"received_view_input":received_view_input.duplicate(true),"public_release_direction_field":"front_direction","valid_release_direction_count":valid_release_direction_count,"boundary_authority_sha256":BOUNDARIES_SHA,"direction_diagnostic_count":direction_diagnostics.size(),"last_direction_diagnostic":direction_diagnostics.back() if not direction_diagnostics.is_empty() else {},"sampled_bones":bone_sample_evidence()}

	if next_upper in ["q1_draw_upper","q1_hold_upper"] and _valid_direction(aim):proven_direction=aim
