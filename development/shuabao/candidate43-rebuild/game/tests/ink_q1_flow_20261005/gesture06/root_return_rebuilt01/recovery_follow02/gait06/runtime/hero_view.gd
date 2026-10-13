extends "res://tests/ink_q1_flow_20261005/gesture06/root_return_rebuilt01/recovery_follow02/side_carry04/runtime/hero_view.gd"
## Seven-field gait overlay; existing Q1/carry compositor and foot solver inherit.
const GAIT_ROOT:="res://tests/ink_q1_flow_20261005/gesture06/root_return_rebuilt01/recovery_follow02/gait06/runtime/"
const GAIT_ASSET:=GAIT_ROOT+"assets/yanguizhou_gait06.glb"
const GAIT_BINDING:=GAIT_ROOT+"asset_binding.json"
const GAIT_ASSET_SHA:="1aec676cb4f145e39c38ed4ca49e6f134fea866574c021cd16ace129c10ba2b5"
const GAIT_BINDING_SHA:="7cf8f33ace6a268c4e21c674f1f11ef762eccfe86e82b04bc46dbeafa9372c80"
const GAIT_BASE_SHA:="a95932dd0fe3fd5c485f6c6b74b4e3e3ab5d66a4e5964dfeb345dc1ce9c53d63"
const GAIT_CLIPS:={"walk":"gait06_walk_lower","walk_back":"gait06_walk_back_lower","strafe_left":"gait06_strafe_left_lower","strafe_right":"gait06_strafe_right_lower"}
const GAIT_LEGS:=["thigh_L","shin_L","foot_L","thigh_R","shin_R","foot_R"]
const GAIT_BONES:=["pelvis","thigh_L","shin_L","foot_L","thigh_R","shin_R","foot_R"]
const GaitReport=preload("res://tests/ink_q1_flow_20261005/gesture06/root_return_rebuilt01/recovery_follow02/gait06/runtime/gait_report.gd")
const GaitPhase=preload("res://tests/ink_q1_flow_20261005/gesture06/root_return_rebuilt01/recovery_follow02/gait06/runtime/phase.gd")
const GaitLower=preload("res://tests/ink_q1_flow_20261005/gesture06/root_return_rebuilt01/recovery_follow02/gait06/runtime/walking_lower.gd")
var gait_phase_readback: Dictionary={}
var gait_indices: Array[int]=[]
var gait_base_samples: Dictionary={}
var gait_ready: bool=false
var gait_binding: Dictionary={}

func _ready() -> void:
 super._ready()
 if proof.status == "HOLD": return
 if FileAccess.get_sha256(GAIT_BINDING)!=GAIT_BINDING_SHA:
  proof.errors.append("Q1_gait_asset_not_authored_and_bound"); proof.status="HOLD"; return
 var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(GAIT_BINDING))
 if not data is Dictionary or data.get("schema","") != "ink-gait06-asset-binding-1":
  proof.errors.append("Q1_gait_asset_binding_invalid"); proof.status="HOLD"; return
 gait_binding=data
 if gait_binding.get("asset_sha256","")!=GAIT_ASSET_SHA or FileAccess.get_sha256(GAIT_ASSET) != str(gait_binding.get("asset_sha256","")) or gait_binding.get("base_asset_sha256","") != GAIT_BASE_SHA:
  proof.errors.append("Q1_gait_exact_asset_mismatch"); proof.status="HOLD"; return
 var authority_path: String=GAIT_ROOT+"source_boundaries.json"
 if FileAccess.get_sha256(authority_path) != str(gait_binding.get("boundaries_sha256","")):
  proof.errors.append("Q1_gait_boundary_mismatch"); proof.status="HOLD"; return
 var authority: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(authority_path))
 if authority.get("asset_sha256","")!=gait_binding.get("asset_sha256","") or gait_binding.get("gait_runtime_copy_bones",[])!=GAIT_BONES:
  proof.errors.append("Q1_gait_authority_mismatch"); proof.status="HOLD"; return
 for bone: String in GAIT_BONES:
  var bone_index: int=skeleton.find_bone(bone)
  if bone_index<0:proof.errors.append("Q1_gait_copy_bone_missing:"+bone)
  else:gait_indices.append(bone_index)
 var settings:=ConfigFile.new()
 if settings.load(GAIT_ASSET+".import") != OK or int(settings.get_value("params","animation/fps",-1)) != 30 or settings.get_value("params","animation/remove_immutable_tracks",null) != true:
  proof.errors.append("Q1_gait_import_settings_mismatch"); proof.status="HOLD"; return
 if not ResourceLoader.exists(GAIT_ASSET):
  proof.errors.append("Q1_gait_asset_unimported"); proof.status="HOLD"; return
 var packed: PackedScene=load(GAIT_ASSET)
 if packed==null:
  proof.errors.append("Q1_gait_packed_scene_missing"); proof.status="HOLD"; return
 var temporary: Node=packed.instantiate()
 var incoming: AnimationPlayer=_flow_find_type(temporary,"AnimationPlayer")
 var incoming_skeleton: Skeleton3D=_flow_find_type(temporary,"Skeleton3D")
 if incoming == null or incoming_skeleton == null or incoming_skeleton.get_bone_count() != skeleton.get_bone_count():
  proof.errors.append("Q1_gait_imported_rig_missing"); temporary.free(); proof.status="HOLD"; return
 for index in range(skeleton.get_bone_count()):
  if incoming_skeleton.get_bone_name(index) != skeleton.get_bone_name(index) or incoming_skeleton.get_bone_parent(index) != skeleton.get_bone_parent(index) or incoming_skeleton.get_bone_rest(index) != skeleton.get_bone_rest(index):
   proof.errors.append("Q1_gait_rest_rig_changed:"+str(index))
 var library:=AnimationLibrary.new()
 player.add_animation_library("gait06_seven_fields",library)
 var animation_root: Node=player.get_node_or_null(player.root_node)
 var evidence: Dictionary={}
 for base_alias: String in GAIT_CLIPS:
  var source_name: String=GAIT_CLIPS[base_alias]
  var alias: String=source_name
  var found: StringName=&""
  for full_name: StringName in incoming.get_animation_list():
   if str(full_name).get_file() == source_name: found=full_name; break
  if found == &"": proof.errors.append("Q1_gait_clip_missing:"+source_name); continue
  var raw: Animation=incoming.get_animation(found)
  var local: Animation=raw.duplicate(true)
  var raw_rows: Array=[]
  var retained: Array=[]
  for track in range(raw.get_track_count()-1,-1,-1):
   var row: Dictionary=Filter.track_evidence(raw,track)
   raw_rows.push_front(row)
   var path: NodePath=raw.track_get_path(track)
   var bone: String=str(row.bone)
   var index: int=skeleton.find_bone(bone)
   var target: Node=animation_root.get_node_or_null(NodePath(path.get_concatenated_names()))
   if target != skeleton or index < 0: proof.errors.append("Q1_gait_target_mismatch:"+str(path)); continue
   var expected_kind: String="translation" if bone=="pelvis" else "rotation"
   var permitted: bool=(bone=="pelvis" and int(row.type)==Animation.TYPE_POSITION_3D) or (bone in GAIT_LEGS and int(row.type)==Animation.TYPE_ROTATION_3D)
   if permitted:
    if not authority.clips[source_name].tracks.has(bone+":"+expected_kind) or int(row.key_count)<1 or raw.track_get_key_time(track,0)!=0.0:
     proof.errors.append("Q1_gait_missing_authored_rotation:"+bone)
    retained.push_front(row)
    continue
   var rest: Transform3D=skeleton.get_bone_rest(index)
   var expected: Variant=rest.origin if int(row.type)==Animation.TYPE_POSITION_3D else rest.basis.get_rotation_quaternion() if int(row.type)==Animation.TYPE_ROTATION_3D else rest.basis.get_scale() if int(row.type)==Animation.TYPE_SCALE_3D else null
   if int(row.key_count)!=1 or not Filter.exact_rest_value(raw.track_get_key_value(track,0),expected):
    proof.errors.append("Q1_gait_nonupper_authority:"+str(path)); continue
   local.remove_track(track)
  for key: String in authority.clips[source_name].tracks:
   if bool(authority.clips[source_name].tracks[key].all_values_identical): continue
   var bone: String=str(authority.clips[source_name].tracks[key].bone)
   if not retained.any(func(row): return str(row.bone)==bone): proof.errors.append("Q1_gait_dynamic_rotation_dropped:"+bone)
  var inspected: Dictionary=AuthoredZero.inspect(local,authority.clips[source_name],skeleton,animation_root)
  for error: String in inspected.errors: proof.errors.append(source_name+":"+error)
  library.add_animation(source_name,local)
  clip_names[alias]=StringName("gait06_seven_fields/"+source_name)
  key_windows[alias]=key_window(local)
  if not key_windows[alias].valid:proof.errors.append("Q1_gait_invalid_window:"+alias)
  evidence[alias]={"source_clip":source_name,"retained_seven_fields":retained.size(),"authored_zero":inspected,"key_window":key_windows[alias]}
 temporary.free()
 skeleton.reset_bone_poses()
 gait_ready=proof.errors.is_empty()
 if not gait_ready: proof.status="HOLD"
 proof["gait06"]={"asset_sha256":gait_binding.asset_sha256,"mesh_asset_unchanged":Q3_MODEL_SHA,"clips":evidence,"base_copy_bones":GAIT_BONES,"cycle_seconds":.50,"original_foot_lock_algorithm_unchanged":true,"contact_seconds":4.0/30.0,"art_accepted":false}

 if gait_ready:lower_motion=GaitLower.new()

func _sample_directional_base(_legacy_phase: float,weights: Dictionary) -> Array[Transform3D]:
 var phase: float=GaitPhase.view_phase(gait_time)
 var base_at: float=GaitPhase.base_phase(phase)
 gait_phase_readback={"displacement_elapsed":gait_time,"new_clip_phase":phase,"original_base_phase":base_at,"normalized_phase":phase/GaitPhase.CYCLE,"new_cycle":GaitPhase.CYCLE,"original_base_cycle":GaitPhase.OLD_CYCLE,"carry_uses_whole_original_cycle":true}
 return super._sample_directional_base(base_at,weights)

func _sample(clip: String,at: float) -> Array[Transform3D]:
 var result: Array[Transform3D]=super._sample(clip,at)
 if not gait_ready or not GAIT_CLIPS.has(clip):return result
 var aux: String=GAIT_CLIPS[clip]
 var base_phase: float=clampf(at-float(key_windows[clip].first),0.0,GaitPhase.OLD_CYCLE)
 var phase: float=GaitPhase.gait_phase_from_base(base_phase)
 var overlay: Array[Transform3D]=super._sample(aux,phase)
 result[pelvis_index].origin=overlay[pelvis_index].origin
 for bone: String in GAIT_LEGS:
  var index: int=skeleton.find_bone(bone)
  result[index].basis=Basis(overlay[index].basis.get_rotation_quaternion()).scaled(result[index].basis.get_scale())
 gait_base_samples[clip]={"base_time":at,"new_clip_phase":phase,"original_base_phase":base_phase,"aux_alias":aux,"copied":"pelvis.origin + six leg rotations","other_fields_from_inherited_side_carry04":true}
 return result
func present(ink: Dictionary) -> void:
 super.present(ink)
 sample_report["gait06"]=GaitReport.capture(self)
 sample_report["gait06_phase"]=gait_phase_readback.duplicate(true)
func _reset_instance_view7() -> void:
 super._reset_instance_view7()
 gait_base_samples.clear()
 gait_phase_readback.clear()
