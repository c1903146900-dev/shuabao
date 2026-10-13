extends RefCounted
## Narrow local animation copy only. Every removed off-whitelist track must resolve
## to THIS skeleton bone and every finite key must equal its actual imported rest.
## No source GLB or imported library mutation; no moving/non-rest lower track allowed.
static func json_value(value: Variant) -> Variant:
	if value is Vector3:return [value.x,value.y,value.z]
	if value is Quaternion:return [value.x,value.y,value.z,value.w]
	return str(value)
static func exact_rest_value(value: Variant, expected: Variant) -> bool:
	if value is Vector3 and expected is Vector3:
		return value.is_finite() and expected.is_finite() and value.x==expected.x and value.y==expected.y and value.z==expected.z
	if value is Quaternion and expected is Quaternion:
		for component: float in [value.x,value.y,value.z,value.w,expected.x,expected.y,expected.z,expected.w]:
			if not is_finite(component):return false
		return value.x==expected.x and value.y==expected.y and value.z==expected.z and value.w==expected.w
	return false
static func track_evidence(animation: Animation, index: int) -> Dictionary:
	var path:=animation.track_get_path(index)
	var keys: Array=[]
	for key in range(animation.track_get_key_count(index)):
		keys.append({"time":animation.track_get_key_time(index,key),"value":json_value(animation.track_get_key_value(index,key)),"transition":animation.track_get_key_transition(index,key)})
	return {"index":index,"path":str(path),"bone":str(path.get_subname(0)) if path.get_subname_count()==1 else "","type":animation.track_get_type(index),"keys":keys,"key_count":keys.size(),"interpolation":animation.track_get_interpolation_type(index)}
static func inspect_copy(animation: Animation, skeleton: Skeleton3D, animation_root: Node, upper: Array) -> Dictionary:
	var raw: Array=[]
	var removed: Array=[]
	var errors: Array=[]
	var remove_indices: Array[int]=[]
	for index in range(animation.get_track_count()):
		var row:=track_evidence(animation,index)
		raw.append(row.duplicate(true))
		var path:=animation.track_get_path(index)
		var bone_name:=str(row.bone)
		var type_id:=int(row.type)
		var target: Node=animation_root.get_node_or_null(NodePath(path.get_concatenated_names())) if animation_root!=null else null
		var bone_index:=skeleton.find_bone(bone_name)
		if target!=skeleton or bone_index<0 or path.get_subname_count()!=1:
			errors.append("unresolved_or_wrong_target:"+str(path));continue
		if type_id not in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D]:
			errors.append("unsupported_track_type:"+str(path));continue
		if bone_name in upper:continue
		var rest:=skeleton.get_bone_rest(bone_index)
		var expected: Variant=rest.origin if type_id==Animation.TYPE_POSITION_3D else rest.basis.get_rotation_quaternion() if type_id==Animation.TYPE_ROTATION_3D else rest.basis.get_scale()
		var key_count:=animation.track_get_key_count(index)
		if key_count!=1:errors.append("off_whitelist_not_one_key:"+str(path));continue
		var exact:=exact_rest_value(animation.track_get_key_value(index,0),expected)
		row["rest_value"]=json_value(expected)
		row["comparison"]="exact component equality, one key, no epsilon"
		row["constant_at_imported_rest"]=exact
		if not exact:
			errors.append("nonrest_off_whitelist_track:"+str(path));continue
		remove_indices.append(index)
		removed.append(row)
	var local: Animation=animation.duplicate(true)
	if errors.is_empty():
		remove_indices.reverse()
		for index in remove_indices:local.remove_track(index)
	var kept: Array=[]
	for index in range(local.get_track_count()):kept.append(track_evidence(local,index))
	var raw_after: Array=[]
	for index in range(animation.get_track_count()):raw_after.append(track_evidence(animation,index))
	return {"animation":local,"raw_tracks":raw,"removed_tracks":removed,"kept_tracks":kept,"errors":errors,"raw_count":animation.get_track_count(),"filtered_count":local.get_track_count(),"raw_resource_unchanged":raw_after==raw,"policy":"only one-key exact imported-rest off-whitelist transform tracks; no epsilon; all other exceptions HOLD"}
