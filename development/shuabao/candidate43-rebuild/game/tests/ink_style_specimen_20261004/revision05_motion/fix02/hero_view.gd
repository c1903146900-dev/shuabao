extends "res://tests/ink_style_specimen_20261004/revision05_motion/hero_view.gd"
const BoundaryRepair=preload("res://tests/ink_style_specimen_20261004/revision05_motion/fix02/boundary_repair.gd")
const BOUNDARIES:="res://tests/ink_style_specimen_20261004/revision05_motion/fix01/source_boundaries.json"
const BOUNDARIES_SHA:="d44ce46eb1f6b8f6966d8b15612473050d40fcb6ab8d2b1c588c6c9997192e53"
var boundary_proof: Dictionary={}
func _ready() -> void:
	super._ready()
	if proof.status=="HOLD":return
	if FileAccess.get_sha256(BOUNDARIES)!=BOUNDARIES_SHA:
		proof.errors.append("boundary_authority_bytes_changed");proof.status="HOLD";return
	var authority: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BOUNDARIES))
	if authority.asset_sha256!=EXPECTED_ASSET_SHA or FileAccess.get_sha256(ASSET)!=authority.asset_sha256:
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
	proof["boundary_repair"]={"authority_sha256":BOUNDARIES_SHA,"source_asset_sha256":authority.asset_sha256,"before_windows":before_windows,"after_windows":key_windows.duplicate(true),"clips":boundary_proof,"no_epsilon":true,"original_source_and_imported_resources_changed":false}
	proof["motion_revision"]="revision05_motion_fix02_glb03"
	proof["key_windows"]=key_windows.duplicate(true)
	if not proof.errors.is_empty():proof.status="HOLD"
func present(ink: Dictionary) -> void:
	super.present(ink)
	sample_report["motion_revision"]="revision05_motion_fix02_glb03"
	sample_report["boundary_authority_sha256"]=BOUNDARIES_SHA
