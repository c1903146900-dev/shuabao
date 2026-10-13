extends RefCounted
## Only an inserted zero-time prefix is changed in a local duplicate. Actual
## source-first and every later imported key, including the last, stay untouched.
const Exact=preload("res://tests/ink_style_specimen_20261004/revision02/upper_rest_filter.gd")
static func source_value(row: Dictionary, type: int) -> Variant:
	var value: Array=row.first_value
	if type==Animation.TYPE_ROTATION_3D:return Quaternion(value[0],value[1],value[2],value[3])
	return Vector3(value[0],value[1],value[2])
static func match_mode(actual: Variant, expected: Variant) -> String:
	if Exact.exact_rest_value(actual,expected):return "exact_raw_first"
	if expected is Quaternion and Exact.exact_rest_value(actual,expected.normalized()):return "exact_once_normalized_raw_first"
	return "unmatched"
static func inspect_copy(animation: Animation, source: Dictionary, skeleton: Skeleton3D, animation_root: Node) -> Dictionary:
	var errors: Array=[]
	var decisions: Array=[]
	var raw: Array=[]
	var first:=float(source.first)
	var last:=float(source.last)
	if not is_finite(first) or first<=0.0 or last<=first:errors.append("invalid_positive_source_window")
	if animation.length!=last:errors.append("source_last_does_not_match_container_endpoint")
	for track in range(animation.get_track_count()):
		var evidence:=Exact.track_evidence(animation,track)
		raw.append(evidence)
		var path:=animation.track_get_path(track)
		var target: Node=animation_root.get_node_or_null(NodePath(path.get_concatenated_names())) if animation_root!=null else null
		var type:=animation.track_get_type(track)
		var kind:="translation" if type==Animation.TYPE_POSITION_3D else "rotation" if type==Animation.TYPE_ROTATION_3D else "scale" if type==Animation.TYPE_SCALE_3D else "invalid"
		var bone:=str(path.get_subname(0)) if path.get_subname_count()==1 else ""
		var source_key:=bone+":"+kind
		if target!=skeleton or skeleton.find_bone(bone)<0 or not source.tracks.has(source_key):
			errors.append("wrong_target_or_missing_source:"+str(path));continue
		var row: Dictionary=source.tracks[source_key]
		var count:=animation.track_get_key_count(track)
		if float(row.first)!=first or float(row.last)!=last or count==0:
			errors.append("track_source_window_mismatch:"+str(path));continue
		if animation.track_get_key_time(track,0)!=0.0:
			errors.append("prefix_is_not_exact_zero:"+str(path));continue
		var expected: Variant=source_value(row,type)
		var mode:=match_mode(animation.track_get_key_value(track,0),expected)
		if mode=="unmatched":errors.append("zero_value_not_source_first:"+str(path));continue
		var boundary_index:=-1
		var bad_prefix:=false
		for key in range(1,count):
			var time:=animation.track_get_key_time(track,key)
			if time<first:bad_prefix=true
			if time==first:boundary_index=key
		if bad_prefix:errors.append("intermediate_prefix_key:"+str(path));continue
		decisions.append({"track":track,"path":str(path),"source_first":first,"source_last":last,"zero_value_match":mode,"action":"remove_only_inserted_zero" if boundary_index>=0 else "move_only_inserted_zero_to_source_first","existing_boundary_match":match_mode(animation.track_get_key_value(track,boundary_index),expected) if boundary_index>=0 else "optimized_away_or_static","existing_boundary_is_preserved_even_if_importer_rounding_differs":boundary_index>=0,"source_first_value":Exact.json_value(expected),"before_prefix":evidence["keys"].slice(0,mini(3,count))})
	if not errors.is_empty():
		# Reject before constructing any candidate. Resource duplication serializes
		# transform key times through real_t and can round a synthetic double time.
		# A rejected input must not produce a usable or subtly changed animation.
		var rejected_after: Array=[]
		for track in range(animation.get_track_count()):rejected_after.append(Exact.track_evidence(animation,track))
		return {"animation":null,"candidate_constructed":false,"errors":errors,"decisions":decisions,"raw_tracks":raw,"repaired_tracks":raw.duplicate(true),"original_resource_unchanged":raw==rejected_after,"all_later_keys_and_last_unchanged":true,"policy":"rejected before duplication; no candidate Animation returned"}
	var local: Animation=animation.duplicate(true)
	if errors.is_empty():
		for row: Dictionary in decisions:
			var track:=int(row.track)
			if row.action=="remove_only_inserted_zero":local.track_remove_key(track,0)
			else:local.track_set_key_time(track,0,first)
	var after: Array=[]
	for track in range(local.get_track_count()):after.append(Exact.track_evidence(local,track))
	var raw_after: Array=[]
	for track in range(animation.get_track_count()):raw_after.append(Exact.track_evidence(animation,track))
	if raw!=raw_after:errors.append("original_resource_changed")
	var later_unchanged:=true
	if errors.is_empty():
		for track in range(raw.size()):
			# The sole edited key is index0. If it was removed, all original keys
			# 1..end remain; if it was moved, all those keys still remain verbatim.
			var before_later: Array=raw[track]["keys"].slice(1)
			var after_later: Array=after[track]["keys"].slice(0 if decisions[track].action=="remove_only_inserted_zero" else 1)
			later_unchanged=later_unchanged and before_later==after_later
		if not later_unchanged:errors.append("later_imported_keys_changed")
	return {"animation":local,"candidate_constructed":true,"errors":errors,"decisions":decisions,"raw_tracks":raw,"repaired_tracks":after,"original_resource_unchanged":raw==raw_after,"all_later_keys_and_last_unchanged":later_unchanged,"policy":"only GLB-proven inserted prefix; exact raw or single-normalization zero match; no epsilon; no interior/last-key edits"}
