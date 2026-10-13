extends "res://tests/ink_style_specimen_20261004/revision05_motion/fix04/hero_view.gd"
## Asset04-only initialization. Deliberately does NOT call parent _ready, which
## loads03. All presentation/input/context behavior remains inherited unchanged.
const ACTOR_ASSET:="res://tests/ink_character_benchmark_20261004/candidate04/yanguizhou_scholar_benchmark.glb"
const ACTOR_SHA:="bafb54fe9daed25ab3579b1e15b28c13fede66227582fdd538b528ed343c8977"
const ACTOR_SOURCE_MD5:="c75a9ce6a3e8693ed63b92ceb821f440"
const BOUNDARIES04:="res://tests/ink_style_specimen_20261004/revision09_actor04/source_boundaries.json"
const BOUNDARIES04_SHA:="60411591eedd1d79acea86be1a8a5acde871f2bb7fc0944b037f66e1188ec690"
func _ready() -> void:
	set_process(false)
	if not ResourceLoader.exists(ACTOR_ASSET):
		proof.errors.append("missing_original_character_glb")
		proof.status = "HOLD"
		return
	proof.asset_sha256=FileAccess.get_sha256(ACTOR_ASSET)
	if proof.asset_sha256!=ACTOR_SHA:
		proof.errors.append("character_bytes_changed_require_new_review");proof.status="HOLD";return
	var scene: PackedScene = load(ACTOR_ASSET)
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
	proof.original_asset_unchanged=FileAccess.get_sha256(ACTOR_ASSET)==ACTOR_SHA
	proof.bone_count = skeleton.get_bone_count()
	proof.restored_before_every_sample = true
	proof.status = "import_structure_checked_not_visual_acceptance" if proof.errors.is_empty() else "HOLD"
	if proof.status=="HOLD":return
	proof["asset_path"]=ACTOR_ASSET
	for clip: String in CLIPS:
		key_windows[clip]=key_window(player.get_animation(clip_names[clip]))
		if not key_windows[clip].valid:proof.errors.append("no_positive_dynamic_key_window:"+clip)
	pelvis_index=skeleton.find_bone("pelvis");chest_index=skeleton.find_bone("chest")
	if pelvis_index<0 or chest_index<0:proof.errors.append("missing_direction_layer_bones")
	if not proof.errors.is_empty():proof.status="HOLD";return
	_bind_actor04_boundary()
	proof["motion_revision"]="revision09_actor04_with_frozen_motion_fix04"
	proof["settling_policy"]={"stop_source_seconds":STOP_BLEND_SECONDS,"start_source_seconds":START_BLEND_SECONDS,"begins_previous_rendered_pose":true,"foot_lock_claim":false,"world_translation_affected":false}
	proof["bone_and_native_comparison"]="pending actor04 actual normal-input comparison"
	proof["algorithm_reuse"]="frozen motion05 fix04 + exact-rest filter + fail-closed prefix algorithm; no03 asset or boundary evidence reused"

func _bind_actor04_boundary() -> void:
	if FileAccess.get_sha256(BOUNDARIES04)!=BOUNDARIES04_SHA:
		proof.errors.append("boundary_authority_bytes_changed");proof.status="HOLD";return
	var authority: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BOUNDARIES04))
	if authority.asset_sha256!=ACTOR_SHA or FileAccess.get_sha256(ACTOR_ASSET)!=authority.asset_sha256:
		proof.errors.append("boundary_authority_asset_mismatch");proof.status="HOLD";return
	var before_windows:=key_windows.duplicate(true)
	var library:=AnimationLibrary.new()
	player.add_animation_library("specimen_source_boundary",library)
	var animation_root: Node=player.get_node_or_null(player.root_node)
	for clip: String in CLIPS:
		var original: Animation=player.get_animation(clip_names[clip])
		var inspected: Dictionary=BoundaryRepair.inspect_copy(original,authority.clips[clip],skeleton,animation_root)
		var repaired: Animation=inspected.animation
		inspected.erase("animation")
		boundary_proof[clip]=inspected
		for error in inspected.errors:proof.errors.append(clip+":"+str(error))
		if inspected.errors.is_empty():
			library.add_animation(clip,repaired)
			clip_names[clip]=StringName("specimen_source_boundary/"+clip)
			key_windows[clip]=key_window(repaired)
	proof["boundary_repair"]={"authority_sha256":BOUNDARIES04_SHA,"source_asset_sha256":authority.asset_sha256,"before_windows":before_windows,"after_windows":key_windows.duplicate(true),"clips":boundary_proof,"no_epsilon":true,"original_source_and_imported_resources_changed":false}
	proof["motion_revision"]="revision09_actor04_with_frozen_motion_fix04"
	proof["key_windows"]=key_windows.duplicate(true)
	if not proof.errors.is_empty():proof.status="HOLD"

func present(ink: Dictionary) -> void:
	super.present(ink)
	sample_report["motion_revision"]="revision09_actor04_with_frozen_motion_fix04"
	sample_report["boundary_authority_sha256"]=BOUNDARIES04_SHA
	sample_report["actor_asset_sha256"]=ACTOR_SHA
