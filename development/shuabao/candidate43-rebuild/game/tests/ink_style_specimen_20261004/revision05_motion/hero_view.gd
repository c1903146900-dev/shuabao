extends "res://tests/ink_style_specimen_20261004/revision03/hero_view.gd"
## Read-only presentation candidate: exact imported key windows, directional lower
## gait and source-aged upper transitions. Imported clips and gameplay stay intact.
var key_windows: Dictionary={}
var gait_cursor:=0.0
var move_heading:=Vector3.BACK
var event_direction:=Vector3.BACK
var event_identity:=""
var last_aim_direction:=Vector3.BACK
var cancel_at:=-1.0
var transition_key:=""
var transition_source_at:=0.0
var last_upper_end:=-1.0
var blend_from_pose: Array[Transform3D]=[]
var last_rendered_pose: Array[Transform3D]=[]
var last_skeleton_basis:=Basis.IDENTITY
var pelvis_index:=-1
var chest_index:=-1
var direction_evidence: Dictionary={}

func _ready() -> void:
	super._ready()
	if proof.status=="HOLD":return
	for clip: String in CLIPS:
		var animation: Animation=player.get_animation(clip_names[clip])
		var window:=key_window(animation)
		key_windows[clip]=window
		if not window.valid:proof.errors.append("no_positive_dynamic_key_window:"+clip)
	pelvis_index=skeleton.find_bone("pelvis");chest_index=skeleton.find_bone("chest")
	if pelvis_index<0 or chest_index<0:proof.errors.append("missing_direction_layer_bones")
	proof["motion_revision"]="revision05_motion_glb03"
	proof["key_windows"]=key_windows.duplicate(true)
	proof["direction_policy"]="move-only root follows displacement; action root follows detached manual direction; pelvis yaw bounded to +/-90deg and reverse gait for rear travel; chest skeleton-global basis restored"
	proof["transition_policy"]="previous rendered upper pose to new sampled upper pose using source gesture/release age, never first-visible wall time"
	proof["bone_and_native_comparison"]="pending"
	if not proof.errors.is_empty():proof.status="HOLD"

static func key_window(animation: Animation) -> Dictionary:
	var first:=INF
	var last:=-INF
	var dynamic_tracks:=0
	for track in range(animation.get_track_count()):
		var count:=animation.track_get_key_count(track)
		# Godot's one-key rest fillers do not define the authored motion interval.
		if count<2:continue
		dynamic_tracks+=1
		first=minf(first,animation.track_get_key_time(track,0))
		last=maxf(last,animation.track_get_key_time(track,count-1))
	return {"first":first,"last":last,"span":last-first,"container_length":animation.length,"dynamic_tracks":dynamic_tracks,"valid":is_finite(first) and is_finite(last) and last>first}

static func direction_plan(movement: Vector3, aim: Vector3, upper_active: bool) -> Dictionary:
	var move:=Vector3(movement.x,0,movement.z).normalized()
	var target:=Vector3(aim.x,0,aim.z).normalized()
	if target.length_squared()<.001:target=Vector3.BACK
	if move.length_squared()<.001:move=target
	var root_yaw:=atan2(target.x,target.z) if upper_active else atan2(move.x,move.z)
	var move_yaw:=atan2(move.x,move.z)
	var lower_yaw:=wrapf(move_yaw-root_yaw,-PI,PI) if upper_active else 0.0
	var travel_sign:=1.0
	if absf(lower_yaw)>PI*.5:
		travel_sign=-1.0
		lower_yaw=wrapf(lower_yaw+PI,-PI,PI)
	var stride: Vector3=Basis(Vector3.UP,root_yaw+lower_yaw)*Vector3.BACK*travel_sign
	return {"root_yaw":root_yaw,"pelvis_yaw":lower_yaw,"travel_sign":travel_sign,"movement_direction":move,"aim_direction":target,"world_stride_direction":stride,"stride_direction_error":stride.distance_to(move)}

func receive(event: Dictionary, source_time: float) -> void:
	super.receive(event,source_time)
	var kind:=str(event.get("kind",""))
	if kind in ["ink_basic_released","ink_q1_released"]:
		event_at=float(event.get("released_at",source_time))
		event_direction=event.get("direction",Vector3.BACK)
		event_identity=str(event.get("wave_id",kind+":"+str(event_at)))
	elif kind=="ink_q1_preview_cancelled":cancel_at=source_time

func _global_pose(poses: Array[Transform3D], index: int) -> Transform3D:
	var result: Transform3D=poses[index]
	var parent:=skeleton.get_bone_parent(index)
	while parent>=0:
		result=poses[parent]*result
		parent=skeleton.get_bone_parent(parent)
	return result

func _set_global_basis(poses: Array[Transform3D], index: int, basis: Basis) -> void:
	var parent:=skeleton.get_bone_parent(index)
	var parent_basis:=_global_pose(poses,parent).basis if parent>=0 else Basis.IDENTITY
	var local: Transform3D=poses[index]
	local.basis=parent_basis.inverse()*basis
	poses[index]=local

func _layer_direction(poses: Array[Transform3D], yaw: float) -> Dictionary:
	var chest_before:=_global_pose(poses,chest_index).basis
	var pelvis_before:=_global_pose(poses,pelvis_index).basis
	# Imported local axes may differ. Conjugate world-up yaw into skeleton space.
	var world_basis: Basis=skeleton.global_basis
	var turn: Basis=world_basis.inverse()*Basis(Vector3.UP,yaw)*world_basis
	_set_global_basis(poses,pelvis_index,turn*pelvis_before)
	_set_global_basis(poses,chest_index,chest_before)
	var chest_after:=_global_pose(poses,chest_index).basis
	return {"pelvis_yaw":yaw,"chest_basis_max_error":maxf(chest_before.x.distance_to(chest_after.x),maxf(chest_before.y.distance_to(chest_after.y),chest_before.z.distance_to(chest_after.z))),"bone_lengths_changed":false,"world_up_conjugation":true}

func _preview_direction(input: Dictionary, hero_position: Vector3, fallback: Vector3) -> Vector3:
	var path: Array=input.get("path",[])
	if path.size()>1:
		var direction: Vector3=path[1]-path[0]
		if direction.length_squared()>.000001:return direction.normalized()
	var start: Vector3=input.get("start",hero_position)
	var toward_start:=start-hero_position
	return toward_start.normalized() if toward_start.length_squared()>.000001 else fallback

func present(ink: Dictionary) -> void:
	if proof.status=="HOLD" or player==null or skeleton==null:return
	var hero: Dictionary=ink.get("hero",{})
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
	if upper_active:last_aim_direction=aim
	elif has_tail:aim=last_aim_direction
	var plan:=direction_plan(move_heading,aim,upper_active or has_tail)
	rotation.y=float(plan.root_yaw)
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
	direction_evidence=_layer_direction(target_pose,float(plan.pelvis_yaw) if walking else 0.0)
	for index in range(target_pose.size()):skeleton.set_bone_pose(index,target_pose[index])
	last_rendered_pose=target_pose.duplicate();last_skeleton_basis=skeleton.global_basis
	previous_upper_weight=alpha if upper_active else 1.0-alpha if not blend_from_pose.is_empty() else 0.0
	active_upper=next_upper;last_position=at;last_time=now
	sample_report={"motion_revision":"revision05_motion_glb03","base":base,"base_time":base_time,"base_key_first":base_window.first,"base_key_span":base_window.span,"gait_elapsed_absolute":gait_time,"gait_cursor_signed":gait_cursor,"upper":next_upper,"upper_time":upper_time,"upper_source_age":upper_age,"upper_source_started":source_started,"transition_source_started":transition_source_at,"transition_source_age":transition_age,"weight":previous_upper_weight,"blend_origin":"previous actually rendered pose; source-aged","source_time":now,"actual_displacement":distance,"source_delta":dt,"base_reset_before_sample":true,"authored_gait_reference_mps":AUTHORED_GAIT_REFERENCE_MPS,"walk_playback_ratio":distance/maxf(.000001,dt)/AUTHORED_GAIT_REFERENCE_MPS if walking else 0.0,"direction_plan":plan,"direction_layer":direction_evidence,"directional_animation_scope":"bounded pelvis/chest layer with reverse imported gait, no authored strafe clip or planted-foot acceptance","source_motion_modified":false,"sampled_bones":bone_sample_evidence()}

func bone_sample_evidence() -> Dictionary:
	# A small actual-pose trace for the next native comparison, not an authored
	# clip agreement claim or per-vertex skinning/performance benchmark.
	var rows: Dictionary={}
	for name: String in ["pelvis","spine","chest","thigh_L","shin_L","foot_L","thigh_R","shin_R","foot_R","upper_arm_R","forearm_R","hand_R","brush"]:
		var index:=skeleton.find_bone(name)
		if index<0:continue
		var local: Transform3D=last_rendered_pose[index]
		var world: Transform3D=skeleton.global_transform*_global_pose(last_rendered_pose,index)
		var q:=local.basis.get_rotation_quaternion()
		rows[name]={"local_origin":[local.origin.x,local.origin.y,local.origin.z],"local_quaternion":[q.x,q.y,q.z,q.w],"world_origin":[world.origin.x,world.origin.y,world.origin.z],"world_basis":[[world.basis.x.x,world.basis.x.y,world.basis.x.z],[world.basis.y.x,world.basis.y.y,world.basis.y.z],[world.basis.z.x,world.basis.z.y,world.basis.z.z]]}
	return rows
