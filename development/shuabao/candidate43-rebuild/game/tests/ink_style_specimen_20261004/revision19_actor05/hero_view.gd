extends "res://tests/ink_style_specimen_20261004/revision05_motion/fix05/hero_view.gd"
## Independent05 binding and bounded positive-phase lower/foot presentation.
const MODEL_PATH:="res://tests/ink_character_benchmark_20261004/candidate05/yanguizhou_scholar_benchmark.glb"
const MODEL_SHA:="2b7a619226c3d53450ad643dd831babede687439eba399ddb4130cc166bda103"
const MODEL_MD5:="8584b85df70f4939e9b6ab8053a2b206"
const BOUNDARIES05:="res://tests/ink_style_specimen_20261004/revision19_actor05/source_boundaries.json"
const BOUNDARIES05_SHA:="38510ca594295bf417a8e84d3b040ebd37f9d68e3dd6338ef4cc3733a189ee8d"
const CONTRACT_PATH:="res://tests/ink_character_benchmark_20261004/candidate05/directional_contract.json"
const CONTRACT_SHA:="d52a2994ba4c83cda7680c2561ac3116963515c5a8c0faa3090677c4f99d9088"
const MODEL_CLIPS:=["idle","walk","basic_upper","q1_draw_upper","q1_hold_upper","q1_release_upper","walk_back","strafe_left","strafe_right"]
const DIRECTIONAL_LOWER:=["walk_back","strafe_left","strafe_right"]
const LOWER05:=["root","pelvis","spine","thigh_L","shin_L","foot_L","toe_L","thigh_R","shin_R","foot_R","toe_R","skirt_front_L","skirt_front_R","skirt_back_L","skirt_back_R","sash_L","sash_R","inkstone"]
const AuthoredZero=preload("res://tests/ink_style_specimen_20261004/revision19_actor05/authored_zero.gd")
const Phase=preload("res://tests/ink_style_specimen_20261004/directional_interface05/directional_phase.gd")
const LowerMotion=preload("res://tests/ink_style_specimen_20261004/revision19_actor05/lower_motion.gd")
var directional_contract: Dictionary={}
var leg_lengths: Dictionary={}
var rest_pelvis_basis:=Basis.IDENTITY
var last_skeleton_transform:=Transform3D.IDENTITY
var lower_motion: RefCounted=LowerMotion.new()
var zero_clip_proof: Dictionary={}
var consumed_direction_samples: Dictionary={}
func _ready() -> void:
	set_process(false)
	if not ResourceLoader.exists(MODEL_PATH):
		proof.errors.append("missing_original_character_glb")
		proof.status = "HOLD"
		return
	proof.asset_sha256=FileAccess.get_sha256(MODEL_PATH)
	if proof.asset_sha256!=MODEL_SHA:
		proof.errors.append("character_bytes_changed_require_new_review");proof.status="HOLD";return
	var scene: PackedScene = load(MODEL_PATH)
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
	proof.original_asset_unchanged=FileAccess.get_sha256(MODEL_PATH)==MODEL_SHA
	proof.bone_count = skeleton.get_bone_count()
	proof.restored_before_every_sample = true
	proof.status = "import_structure_checked_not_visual_acceptance" if proof.errors.is_empty() else "HOLD"
	if proof.status=="HOLD":return
	proof["asset_path"]=MODEL_PATH
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

func _bind_model_boundary() -> void:
	if FileAccess.get_sha256(BOUNDARIES05)!=BOUNDARIES05_SHA:
		proof.errors.append("model05_boundary_authority_changed");proof.status="HOLD";return
	var authority: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BOUNDARIES05))
	if authority.asset_sha256!=MODEL_SHA:
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
	proof["boundary_repair"]={"authority_sha256":BOUNDARIES05_SHA,"source_asset_sha256":MODEL_SHA,"before_windows":before,"after_windows":key_windows.duplicate(true),"old_six":boundary_proof,"new_authored_zero":zero_clip_proof,"no_epsilon":true,"original_resources_changed":false,"new_zero_source_value_equivalence_accepted":false}
	proof["key_windows"]=key_windows.duplicate(true)
	if not proof.errors.is_empty():proof.status="HOLD"
func _prepare_source_clock(ink: Dictionary) -> void:
	var before:=clock_diagnostics.size()
	super._prepare_source_clock(ink)
	if clock_diagnostics.size()!=before:lower_motion.reset()
func _sample_directional_base(phase: float, weights: Dictionary) -> Array[Transform3D]:
	var forward_time:=float(key_windows.walk.first)+minf(phase,float(key_windows.walk.span))
	var result: Array[Transform3D]=_sample("walk",forward_time)
	var chest_basis:=_global_pose(result,chest_index).basis
	var mixed: Array[Transform3D]=[]
	var total:=0.0
	consumed_direction_samples.clear()
	for clip: String in ["walk","walk_back","strafe_left","strafe_right"]:
		var weight:=float(weights.get(clip,0.0))
		if weight<=0.0:continue
		var at:=float(key_windows[clip].first)+minf(phase,float(key_windows[clip].span))
		var sampled: Array[Transform3D]=result.duplicate() if clip=="walk" else _sample(clip,at)
		consumed_direction_samples[clip]={"weight":weight,"sample_time":at,"first_key":key_windows[clip].first,"phase":phase,"time_reversed":false}
		if mixed.is_empty():mixed=sampled.duplicate();total=weight
		else:
			var fraction:=weight/(total+weight)
			for index in range(mixed.size()):
				if str(skeleton.get_bone_name(index)) in LOWER05:mixed[index]=mixed[index].interpolate_with(sampled[index],fraction)
			total+=weight
	if not mixed.is_empty():
		for index in range(result.size()):
			if str(skeleton.get_bone_name(index)) in LOWER05:result[index]=mixed[index]
	_set_global_basis(result,chest_index,chest_basis)
	return result

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
	var root_yaw:=atan2(aim.x,aim.z) if directional_upper else atan2(move_heading.x,move_heading.z)
	var local_move: Vector3=Basis(Vector3.UP,-root_yaw)*move_heading
	var choice: Dictionary=Phase.weights(local_move)
	var weights: Dictionary=choice.get("weights",{"walk":1.0}) if directional_upper else {"walk":1.0}
	var dominant:="walk";var greatest:=-1.0
	for clip: String in weights:
		if float(weights[clip])>greatest:dominant=clip;greatest=float(weights[clip])
	var plan: Dictionary={"root_yaw":root_yaw,"pelvis_yaw":0.0,"travel_sign":1.0,"movement_direction":move_heading,"aim_direction":aim,"world_stride_direction":move_heading,"stride_direction_error":0.0,"direction_weights":weights,"dominant_clip":dominant,"diagonal_unverified":directional_upper and bool(choice.get("diagonal",false)),"positive_phase_only":true}
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
	direction_evidence={"pelvis_compensation_yaw":0.0,"new_directional_loops":true,"chest_global_aim_preserved":true}
	var lower: Dictionary=lower_motion.apply(self,target_pose,idle_pose,walking,now,phase05,("aim:"+dominant) if directional_upper else "move",current_dash>0.0,source_started if upper_active else last_time)
	target_pose=lower.poses
	var lower_transition: Dictionary=lower.report
	for index in range(target_pose.size()):skeleton.set_bone_pose(index,target_pose[index])
	last_rendered_pose=target_pose.duplicate();last_skeleton_basis=skeleton.global_basis;last_skeleton_transform=skeleton.global_transform
	previous_upper_weight=alpha if upper_active else 1.0-alpha if not blend_from_pose.is_empty() else 0.0
	active_upper=next_upper;last_position=at;last_time=now;last_visual_yaw=rotation.y
	sample_report={"motion_revision":"revision19_actor05_directional_candidate","base":base,"base_time":base_time,"base_key_first":base_window.first,"base_key_span":base_window.span,"gait_elapsed_absolute":gait_time,"gait_cursor_signed":gait_cursor,"upper":next_upper,"upper_time":upper_time,"upper_source_age":upper_age,"upper_source_started":source_started,"transition_source_started":transition_source_at,"transition_source_age":transition_age,"weight":previous_upper_weight,"blend_origin":"previous actually rendered pose; source-aged","source_time":now,"actual_displacement":distance,"source_delta":dt,"repeated_source_time":repeated_source_time,"same_time_stop_input":same_time_stop_input,"same_time_dash_started":same_time_dash_started,"source_clock_diagnostic_count":clock_diagnostics.size(),"received_event_serial":received_event_serial,"received_event_kind":received_event_kind,"observed_dash_left":float(hero.get("dash_left",0.0)),"base_reset_before_sample":true,"authored_gait_reference_mps":AUTHORED_GAIT_REFERENCE_MPS,"walk_playback_ratio":distance/maxf(.000001,dt)/AUTHORED_GAIT_REFERENCE_MPS if walking else 0.0,"direction_plan":plan,"direction_layer":direction_evidence,"directional_animation_scope":"positive-phase authored lower loops + bounded world-foot targets; diagonal/landing/turn art unaccepted","consumed_direction_samples":consumed_direction_samples.duplicate(true),"source_motion_modified":false,"lower_transition":lower_transition,"received_view_input":received_view_input.duplicate(true),"public_release_direction_field":"front_direction","valid_release_direction_count":valid_release_direction_count,"boundary_authority_sha256":BOUNDARIES05_SHA,"actor_asset_sha256":MODEL_SHA,"direction_diagnostic_count":direction_diagnostics.size(),"last_direction_diagnostic":direction_diagnostics.back() if not direction_diagnostics.is_empty() else {},"sampled_bones":bone_sample_evidence()}

	if next_upper in ["q1_draw_upper","q1_hold_upper"] and _valid_direction(aim):proven_direction=aim

	last_move_intent=current_intent;last_dash_left=current_dash
	presented_event_serial=received_event_serial
