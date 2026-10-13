extends Node3D
## Detached snapshots only. No simulation reference or collision/damage authority.
const Filter=preload("res://tests/ink_style_specimen_20261004/revision02/upper_rest_filter.gd")
const EXPECTED_ASSET_SHA:="611bedc2abc12b492807f2510e3c6e3876b4bd34354fcdf9593b95f7193506c3"
const ASSET := "res://tests/ink_character_benchmark_20261004/candidate03/yanguizhou_scholar_benchmark.glb"
const UPPER := ["chest","neck","head","clavicle_R","upper_arm_R","forearm_R","hand_R","clavicle_L","upper_arm_L","forearm_L","hand_L","sleeve_R","sleeve_L","hair_1","hair_2","brush","thumb_L","index_L","middle_L","ring_L","pinky_L","thumb_R","index_R","middle_R","ring_R","pinky_R"]
const AUTHORED_GAIT_REFERENCE_MPS := 6.0 # candidate02: 1.0 m stance travel / (5/30 s), source-authored
const CLIPS := ["idle","walk","basic_upper","q1_draw_upper","q1_hold_upper","q1_release_upper"]
var player: AnimationPlayer
var skeleton: Skeleton3D
var clip_names: Dictionary = {}
var proof: Dictionary = {"status":"not_loaded","clips":{},"raw_import_clips":{},"filter_evidence":{},"errors":[],"removed_exact_rest_tracks":0}
var gait_time := 0.0
var last_position := Vector3.INF
var last_time := -1.0
var event_action := ""
var event_at := -1.0
var active_upper := ""
var upper_began := -1.0
var previous_upper_pose: Array[Transform3D] = []
var previous_upper_weight := 0.0
var sample_report: Dictionary = {}
func _ready() -> void:
	set_process(false)
	if not ResourceLoader.exists(ASSET):
		proof.errors.append("missing_original_character_glb")
		proof.status = "HOLD"
		return
	proof.asset_sha256=FileAccess.get_sha256(ASSET)
	if proof.asset_sha256!=EXPECTED_ASSET_SHA:
		proof.errors.append("character_bytes_changed_require_new_review");proof.status="HOLD";return
	var scene: PackedScene = load(ASSET)
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
		if short_name in CLIPS:clip_names[short_name] = animation_name
	var isolated_library:=AnimationLibrary.new()
	player.add_animation_library("specimen_filtered_upper",isolated_library)
	var animation_root: Node=player.get_node_or_null(player.root_node)
	for clip: String in CLIPS:
		if not clip_names.has(clip):
			proof.errors.append("missing_clip:"+clip)
			continue
		var raw_name: StringName=clip_names[clip]
		var animation: Animation=player.get_animation(raw_name)
		var raw_tracks: Array=[]
		for index in range(animation.get_track_count()):raw_tracks.append(Filter.track_evidence(animation,index))
		proof.raw_import_clips[clip]={"imported_name":str(raw_name),"actual_length":animation.length,"tracks":raw_tracks}
		var tracks: Array=raw_tracks
		if clip.ends_with("_upper"):
			var result: Dictionary=Filter.inspect_copy(animation,skeleton,animation_root,UPPER)
			var local: Animation=result.animation
			result.erase("animation")
			proof.filter_evidence[clip]=result
			for error in result.errors:proof.errors.append(clip+":"+str(error))
			if result.errors.is_empty():
				isolated_library.add_animation(clip,local)
				clip_names[clip]=StringName("specimen_filtered_upper/"+clip)
				tracks=result.kept_tracks
				proof.removed_exact_rest_tracks+=result.removed_tracks.size()
			for row: Dictionary in tracks:
				if str(row.bone) not in UPPER:proof.errors.append("retained_off_whitelist:"+clip+":"+str(row.path))
		proof.clips[clip]={"imported_name":str(clip_names[clip]),"actual_length":animation.length,"tracks":tracks}
	proof.filter_policy="local copied upper animation only; single-key exact actual skeleton rest equality; no epsilon"
	proof.original_asset_unchanged=FileAccess.get_sha256(ASSET)==EXPECTED_ASSET_SHA
	proof.bone_count = skeleton.get_bone_count()
	proof.restored_before_every_sample = true
	proof.status = "import_structure_checked_not_visual_acceptance" if proof.errors.is_empty() else "HOLD"
func _scan(node: Node) -> void:
	if node is AnimationPlayer:player=node
	if node is Skeleton3D:skeleton=node
	for child in node.get_children():_scan(child)
func receive(event: Dictionary, source_time: float) -> void:
	match str(event.get("kind","")):
		"ink_basic_released":
			event_action="basic_upper";event_at=source_time
		"ink_q1_released":
			event_action="q1_release_upper";event_at=source_time
		"ink_q1_preview_cancelled":
			event_action="";event_at=-1.0
func _capture() -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for index in range(skeleton.get_bone_count()):result.append(skeleton.get_bone_pose(index))
	return result
func _sample(clip: String, at: float) -> Array[Transform3D]:
	# Never let a prior upper-body write become the next locomotion baseline.
	skeleton.reset_bone_poses()
	player.play(clip_names[clip])
	player.seek(at,true)
	return _capture()
func present(ink: Dictionary) -> void:
	if proof.status == "HOLD" or player == null or skeleton == null:return
	var hero: Dictionary = ink.get("hero",{})
	var now := float(ink.get("source_time",0.0))
	var at: Vector3 = hero.get("position",Vector3.ZERO)
	var distance := at.distance_to(last_position) if last_position.is_finite() else 0.0
	var dt := maxf(0.0,now-last_time) if last_time>=0 else 0.0
	position = at
	var facing: Vector3 = hero.get("facing",Vector3.FORWARD)
	if facing.length_squared()>.001:rotation.y=atan2(facing.x,facing.z)
	# Imported walk remains the base even during every upper-body action.
	var walking := distance>.0001 and dt>0.0 and float(hero.get("dash_left",0.0))<=0.0
	if walking:gait_time += distance/AUTHORED_GAIT_REFERENCE_MPS
	var base := "walk" if walking else "idle"
	var base_length: float = proof.clips[base].actual_length
	var base_time := fposmod(gait_time if walking else now,maxf(.001,base_length))
	var base_pose := _sample(base,base_time)
	var input: Dictionary = ink.get("input",{})
	var next_upper := ""
	var upper_time := 0.0
	if input.get("phase","") == "drawing":
		next_upper="q1_draw_upper"
		upper_time=float(proof.clips[next_upper].actual_length)*float(input.get("draw_fraction",0.0))
	elif input.get("phase","") == "frozen":
		next_upper="q1_hold_upper"
		upper_time=fposmod(maxf(0.0,now-float(input.get("frozen_at",now))),float(proof.clips[next_upper].actual_length))
	elif not event_action.is_empty() and event_at>=0.0 and now-event_at<float(proof.clips[event_action].actual_length):
		next_upper=event_action
		upper_time=now-event_at
	if next_upper!=active_upper:
		active_upper=next_upper
		upper_began=now
	var weight := minf(1.0,maxf(0.0,now-upper_began)/.07) if not next_upper.is_empty() else maxf(0.0,previous_upper_weight-dt/.08)
	var overlay := previous_upper_pose
	if not next_upper.is_empty():overlay=_sample(next_upper,upper_time)
	for index in range(skeleton.get_bone_count()):
		var pose: Transform3D = base_pose[index]
		if str(skeleton.get_bone_name(index)) in UPPER and overlay.size()==base_pose.size():pose=pose.interpolate_with(overlay[index],weight)
		skeleton.set_bone_pose(index,pose)
	previous_upper_pose=overlay
	previous_upper_weight=weight
	last_position=at
	last_time=now
	sample_report={"base":base,"base_time":base_time,"upper":next_upper,"upper_time":upper_time,"weight":weight,"source_time":now,"actual_displacement":distance,"source_delta":dt,"base_reset_before_sample":true,"authored_gait_reference_mps":AUTHORED_GAIT_REFERENCE_MPS,"walk_playback_ratio":distance/maxf(.000001,dt)/AUTHORED_GAIT_REFERENCE_MPS if walking else 0.0}
