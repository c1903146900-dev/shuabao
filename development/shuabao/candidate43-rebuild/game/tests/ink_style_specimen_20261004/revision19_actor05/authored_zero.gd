extends RefCounted
## Genuinely authored zero is consumed unchanged. Source-value mismatches are
## recorded, never normalized/edited or misrepresented as exact equivalence.
const Exact=preload("res://tests/ink_style_specimen_20261004/revision02/upper_rest_filter.gd")
const Prefix=preload("res://tests/ink_style_specimen_20261004/revision05_motion/fix02/boundary_repair.gd")
static func inspect(animation: Animation, source: Dictionary, skeleton: Skeleton3D, animation_root: Node) -> Dictionary:
	var errors: Array=[];var differences: Array=[];var rows: Array=[]
	if float(source.first)!=0.0 or animation.length!=float(source.last):errors.append("authored_zero_window_mismatch")
	for track in range(animation.get_track_count()):
		var row:=Exact.track_evidence(animation,track);rows.append(row)
		var path:=animation.track_get_path(track)
		var target: Node=animation_root.get_node_or_null(NodePath(path.get_concatenated_names())) if animation_root!=null else null
		var kind:="translation" if int(row.type)==Animation.TYPE_POSITION_3D else "rotation" if int(row.type)==Animation.TYPE_ROTATION_3D else "scale" if int(row.type)==Animation.TYPE_SCALE_3D else "invalid"
		var key:=str(row.bone)+":"+kind
		if target!=skeleton or not source.tracks.has(key) or int(row.key_count)==0:
			errors.append("wrong_target_or_missing_authority:"+str(path));continue
		if animation.track_get_key_time(track,0)!=0.0:
			errors.append("genuine_zero_missing:"+str(path));continue
		var expected: Variant=Prefix.source_value(source.tracks[key],int(row.type))
		var mode:=Prefix.match_mode(animation.track_get_key_value(track,0),expected)
		if mode=="unmatched":differences.append({"path":str(path),"imported":row["keys"][0].value,"source_first":Exact.json_value(expected),"action":"kept_imported_value_unchanged","source_value_equivalence_proven":false})
	var after: Array=[]
	for track in range(animation.get_track_count()):after.append(Exact.track_evidence(animation,track))
	if after!=rows:errors.append("unchanged_resource_check_failed")
	return {"errors":errors,"raw_tracks":rows,"consumed_tracks":after,"raw_resource_unchanged":after==rows,"authored_zero_preserved":errors.is_empty(),"source_value_differences":differences,"source_value_equivalence_proven":differences.is_empty(),"prefix_edit_performed":false,"policy":"normal loading of unchanged imported values; source-value equivalence reported separately"}
