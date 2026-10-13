extends "res://tests/ink_style_specimen_20261004/revision19_actor05/fix06/turn_lower.gd"
## Same walking anchor/IK body; only contact windows and cycle are different.
const GaitPhase=preload("res://tests/ink_q1_flow_20261005/gesture06/root_return_rebuilt01/recovery_follow02/gait06/runtime/phase.gd")
func apply(actor: Node3D,target: Array[Transform3D],idle: Array[Transform3D],walking: bool,now: float,_legacy_phase: float,next_mode: String,dash_active: bool=false,transfer_source_at: float=-1.0) -> Dictionary:
	var phase: float=GaitPhase.view_phase(actor.gait_time)
	if not walking or dash_active:
		return super.apply(actor,target,idle,walking,now,GaitPhase.stop_phase(phase),next_mode,dash_active,transfer_source_at)
	_clear_turn();turn_stop_capture_time=-1.0
	var report: Dictionary={"walking":walking,"phase_s":phase,"foot_contact_accepted":false,"natural_settle_accepted":false,"stepped_turn_implemented":false,"diagnostic_count":diagnostics.size(),"gait06_contact_cycle":GaitPhase.CYCLE}
	var chest: Basis=actor._global_pose(target,actor.chest_index).basis
	var previous: Array[Transform3D]=actor.last_rendered_pose
	var previous_world: Transform3D=actor.last_skeleton_transform
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
		var contact:=GaitPhase.contact(phase,side)
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
				releases[side]={"point":anchors[side],"basis":anchor_orientations[side],"toe_off_phase":GaitPhase.toeoff(side)}
				anchors.erase(side);anchor_orientations.erase(side)
			if releases.has(side):
				var release: Dictionary=releases[side]
				var gait_age:=fposmod(phase-float(release.toe_off_phase),GaitPhase.CYCLE)
				var t:=clampf(gait_age/TRANSFER_SECONDS,0.0,1.0)
				if t>=1.0:
					# Consume the exact endpoint in this first call too. A later
					# same-source call must not switch from slerp(1) to raw basis.
					releases.erase(side)
				else:
					var e:=t*t*(3.0-2.0*t)
					var release_point: Vector3=release.point
					wanted=release_point.lerp(wanted,e);wanted.y+=.03*16.0*t*t*(1.0-t)*(1.0-t)
					var release_basis: Basis=release.basis
					wanted_basis=release_basis.slerp(wanted_basis,e)
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
