extends RefCounted
## View-owned lower-world transfer, source-clock contacts and actual foot target
## application. No source actor position/input/clock is written.
const Settle=preload("res://tests/ink_style_specimen_20261004/revision19_actor05/foot_settle.gd")
const FeetPose=preload("res://tests/ink_style_specimen_20261004/revision19_actor05/fix02/pose_feet.gd")
const TRANSFER_SECONDS:=.08
const SIDES:=["L","R"]
var settle: RefCounted=Settle.new()
var last_walking:=false
var mode_key:=""
var mode_start:=0.0
var mode_from: Array[Transform3D]=[]
var mode_basis:=Basis.IDENTITY
var mode_feet: Dictionary={}
var mode_orientations: Dictionary={}
var start_transfer:=false
var anchors: Dictionary={}
var anchor_orientations: Dictionary={}
var releases: Dictionary={}
var settling:=false
var settle_blocked:=false
var stop_from: Array[Transform3D]=[]
var stop_basis:=Basis.IDENTITY
var stop_yaw:=0.0
var stop_orientations: Dictionary={}
var stop_neutral: Dictionary={}
var idle_orientations: Dictionary={}
var last_targets: Dictionary={}
var diagnostics: Array=[]
func reset() -> void:
	settle.cancel();last_walking=false;mode_key="";mode_from.clear();mode_feet.clear();mode_orientations.clear();anchors.clear();anchor_orientations.clear();releases.clear();settling=false;settle_blocked=false;stop_from.clear();last_targets.clear();diagnostics.clear()
func _foot_data(actor: Node3D, poses: Array[Transform3D], world: Transform3D) -> Dictionary:
	var positions: Dictionary={};var bases: Dictionary={}
	for side: String in SIDES:
		var index: int=actor.skeleton.find_bone("foot_"+side)
		var pose: Transform3D=world*actor._global_pose(poses,index)
		positions[side]=pose.origin;bases[side]=pose.basis
	return {"positions":positions,"orientations":bases}
func _copy_lower(actor: Node3D, target: Array[Transform3D], previous: Array[Transform3D], previous_world: Basis, weight: float) -> Array[Transform3D]:
	var result: Array[Transform3D]=target.duplicate()
	if previous.size()!=target.size():return result
	var chest: Basis=actor._global_pose(target,actor.chest_index).basis
	var prior: Array[Transform3D]=previous.duplicate()
	var pelvis: Basis=actor._global_pose(prior,actor.pelvis_index).basis
	actor._set_global_basis(prior,actor.pelvis_index,actor.skeleton.global_basis.inverse()*previous_world*pelvis)
	for index in range(result.size()):
		if str(actor.skeleton.get_bone_name(index)) in actor.LOWER05:result[index]=prior[index].interpolate_with(target[index],weight)
	actor._set_global_basis(result,actor.chest_index,chest)
	return result
func _logical_yaw(actor: Node3D, poses: Array[Transform3D], world: Basis) -> float:
	var logical: Basis=world*actor._global_pose(poses,actor.pelvis_index).basis*actor.rest_pelvis_basis.inverse()
	var direction:=logical*Vector3.BACK
	return atan2(direction.x,direction.z)
func _restore_chest(actor: Node3D, poses: Array[Transform3D], desired: Basis) -> void:
	actor._set_global_basis(poses,actor.chest_index,desired)
func _result(poses: Array[Transform3D], report: Dictionary) -> Dictionary:return {"poses":poses,"report":report}
func apply(actor: Node3D, target: Array[Transform3D], idle: Array[Transform3D], walking: bool, now: float, phase: float, next_mode: String, dash_active: bool=false, transfer_source_at: float=-1.0) -> Dictionary:
	var report: Dictionary={"walking":walking,"phase_s":phase,"foot_contact_accepted":false,"natural_settle_accepted":false,"stepped_turn_implemented":false,"diagnostic_count":diagnostics.size()}
	if dash_active:
		reset();report.status="dash_source_translation_no_directional_foot_claim"
		return _result(target,report)
	var chest: Basis=actor._global_pose(target,actor.chest_index).basis
	var previous: Array[Transform3D]=actor.last_rendered_pose
	var previous_world: Transform3D=actor.last_skeleton_transform
	if walking:
		if settling:settle.cancel();settling=false;settle_blocked=false
		var changed:=not last_walking or next_mode!=mode_key
		if changed:
			start_transfer=not last_walking;mode_key=next_mode
			mode_start=maxf(actor.last_time,transfer_source_at) if actor.last_time>=0.0 else now
			mode_start=minf(mode_start,now)
			mode_from=previous.duplicate();mode_basis=previous_world.basis
			if not previous.is_empty():
				var captured:=_foot_data(actor,previous,previous_world)
				mode_feet=captured.positions;mode_orientations=captured.orientations
			if start_transfer:anchors.clear();anchor_orientations.clear();releases.clear()
		var fraction:=clampf((now-mode_start)/TRANSFER_SECONDS,0.0,1.0)
		var smooth:=fraction*fraction*(3.0-2.0*fraction)
		var raw_feet:=_foot_data(actor,target,actor.skeleton.global_transform)
		var mixed: Array[Transform3D]=_copy_lower(actor,target,mode_from,mode_basis,smooth)
		var targets: Dictionary={};var orientations: Dictionary={};var contacts: Dictionary={}
		for side: String in SIDES:
			var contact:=phase<=1.0/6.0 if side=="L" else phase>=.3 and phase<=.3+1.0/6.0
			contacts[side]=contact
			var wanted: Vector3=raw_feet.positions[side]
			var wanted_basis: Basis=raw_feet.orientations[side]
			if fraction<1.0 and mode_feet.has(side) and (start_transfer or not anchors.has(side)):
				var start_point: Vector3=mode_feet[side]
				wanted=start_point.lerp(wanted,smooth)
				wanted.y+=.03*16.0*fraction*fraction*(1.0-fraction)*(1.0-fraction)
				var start_basis: Basis=mode_orientations[side]
				wanted_basis=start_basis.slerp(wanted_basis,smooth)
			elif contact:
				if not anchors.has(side):
					var point: Vector3=wanted # Current phase sample; not reconstructed historical physics.
					point.y=actor.position.y+.14
					anchors[side]=point;anchor_orientations[side]=wanted_basis
				wanted=anchors[side];wanted_basis=anchor_orientations[side];releases.erase(side)
			else:
				if anchors.has(side):
					releases[side]={"point":anchors[side],"basis":anchor_orientations[side],"toe_off_phase":1.0/6.0 if side=="L" else .3+1.0/6.0}
					anchors.erase(side);anchor_orientations.erase(side)
				if releases.has(side):
					var release: Dictionary=releases[side]
					var gait_age:=fposmod(phase-float(release.toe_off_phase),.6)
					var t:=clampf(gait_age/TRANSFER_SECONDS,0.0,1.0)
					var e:=t*t*(3.0-2.0*t)
					var release_point: Vector3=release.point
					wanted=release_point.lerp(wanted,e);wanted.y+=.03*16.0*t*t*(1.0-t)*(1.0-t)
					var release_basis: Basis=release.basis
					wanted_basis=release_basis.slerp(wanted_basis,e)
					if t>=1.0:releases.erase(side)
			targets[side]=wanted;orientations[side]=wanted_basis
		var solved: Dictionary=FeetPose.apply(actor,mixed,targets,orientations,actor.leg_lengths,.16)
		last_walking=true;actor.locomotion_mode="walk"
		report.merge({"status":"walking_targets_applied" if solved.accepted else "walking_target_HOLD","mode":mode_key,"mode_changed":changed,"transfer_alpha":fraction,"targets":targets,"authored_contacts":contacts,"world_anchor_feet":anchors.keys(),"anchor_scope":"current displayed authored-phase target, not reconstructed source physical history","release_progress_clock":"forward displacement-owned gait phase","solver":_solver_report(solved)},true)
		if solved.accepted:
			var pose: Array[Transform3D]=solved.poses;_restore_chest(actor,pose,chest);last_targets=targets.duplicate(true)
			return _result(pose,report)
		diagnostics.append({"source_time":now,"reason":"walking_target_unreachable","solver":_solver_report(solved)})
		# Preserve the actual lower pose orientation; never move source root or
		# silently stretch/clamp a foot to turn a reach failure into acceptance.
		return _result(_copy_lower(actor,target,previous,previous_world.basis,0.0),report)
	if last_walking and not previous.is_empty():
		settling=true;settle_blocked=false;stop_from=previous.duplicate();stop_basis=previous_world.basis
		stop_yaw=_logical_yaw(actor,previous,previous_world.basis)
		var captured:=_foot_data(actor,previous,previous_world);stop_orientations=captured.orientations
		var idle_target: Array[Transform3D]=idle.duplicate()
		actor._layer_direction(idle_target,wrapf(stop_yaw-actor.rotation.y,-PI,PI))
		var neutral:=_foot_data(actor,idle_target,actor.skeleton.global_transform)
		for side: String in SIDES:
			var point: Vector3=neutral.positions[side];point.y=actor.position.y+.14;neutral.positions[side]=point
		idle_orientations=neutral.orientations;stop_neutral=neutral.positions.duplicate(true)
		var admission: Dictionary=settle.begin(now,captured.positions,neutral.positions,"L" if phase<.3 else "R")
		last_targets=captured.positions.duplicate(true);anchors.clear();anchor_orientations.clear();releases.clear()
		settle_blocked=not admission.accepted
		last_walking=false;actor.locomotion_mode="idle"
		report.merge({"status":"stop_capture_exact" if admission.accepted else "stop_admission_HOLD","settle":admission,"captured_lower_yaw":stop_yaw},true)
		return _result(_copy_lower(actor,target,stop_from,stop_basis,0.0),report)
	last_walking=false;actor.locomotion_mode="idle"
	if not settling:return _result(target,report.merged({"status":"idle_no_settle"},true))
	if settle_blocked:
		report.status="settle_reach_HOLD_requires_new_motion"
		return _result(_copy_lower(actor,target,previous,previous_world.basis,0.0),report)
	var planned: Dictionary=settle.sample(now)
	var idle_target: Array[Transform3D]=idle.duplicate()
	actor._layer_direction(idle_target,wrapf(stop_yaw-actor.rotation.y,-PI,PI))
	_restore_chest(actor,idle_target,chest)
	var base: Array[Transform3D]=_copy_lower(actor,idle_target,stop_from,stop_basis,float(planned.get("body_idle_weight",0.0)))
	var orientations: Dictionary={}
	for side: String in SIDES:
		# Feet turn only while their target is the free recovering foot. Anchored
		# foot orientation remains captured; final meaningful body turn is pending.
		orientations[side]=stop_orientations[side]
		if planned.feet[side]==stop_neutral[side] and str(planned.moving_side)!=side:orientations[side]=idle_orientations[side]
		elif str(planned.phase)=="recovery" and str(planned.moving_side)==side:
			var t:=float(planned.phase_fraction)
			var old_basis: Basis=stop_orientations[side];var neutral_basis: Basis=idle_orientations[side]
			orientations[side]=old_basis.slerp(neutral_basis,t*t*(3.0-2.0*t))
	var solved: Dictionary=FeetPose.apply(actor,base,planned.feet,orientations,actor.leg_lengths,.22) if planned.accepted else {"accepted":false,"reason":planned.reason}
	report.merge({"status":"settle_targets_applied" if solved.accepted else "settle_target_HOLD","settle":planned,"targets":planned.feet,"captured_lower_yaw":stop_yaw,"remaining_idle_yaw":wrapf(actor.rotation.y-stop_yaw,-PI,PI),"solver":_solver_report(solved)},true)
	if solved.accepted:
		var pose: Array[Transform3D]=solved.poses;_restore_chest(actor,pose,chest);last_targets=planned.feet.duplicate(true)
		# A completed plan may keep this stance; no two planted feet are spun.
		return _result(pose,report)
	settle_blocked=true;diagnostics.append({"source_time":now,"reason":"settle_target_unreachable","solver":_solver_report(solved)})
	return _result(_copy_lower(actor,target,previous,previous_world.basis,0.0),report)
func _solver_report(result: Dictionary) -> Dictionary:
	var report:=result.duplicate(true);report.erase("poses")
	return report
