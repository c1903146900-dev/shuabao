extends "res://tests/ink_q1_flow_20261005/gesture06/root_return_rebuilt01/recovery_follow02/hero_view.gd"
## Authored Q1 recovery and shared carry; frozen compositor/foot solver inherited.
const CARRY_ROOT:="res://tests/ink_q1_flow_20261005/gesture06/root_return_rebuilt01/recovery_follow02/side_carry04/runtime/"
const CARRY_ASSET:=CARRY_ROOT+"assets/yanguizhou_q1_carry.glb"
const CARRY_BINDING:=CARRY_ROOT+"asset_binding.json"
const CARRY_BASE_SHA:="8637ff7ba8e7e22130ca4c5ad1c1d3073fe88cb6b12c1f08f06ec39620d97352"
const CARRY_ALIASES:={"q1_draw_upper":"q1_carry_draw_upper","q1_hold_upper":"q1_carry_hold_upper","q1_release_upper":"q1_carry_release_upper","brush_carry_upper":"brush_carry_upper"}
const CARRY_ASSET_SHA:="06b2f5bb05bef2d3035c151df709c5c60671122bb7cdf3851449199fb0d99049"
const CARRY_BINDING_SHA:="4356fe80c7887254db9299b934aa5f8ccd67150053e4233c38f8c127e6612a03"
const CARRY_BONES:=["clavicle_R","upper_arm_R","forearm_R","hand_R","sleeve_R","clavicle_L","upper_arm_L","forearm_L","hand_L","sleeve_L"]
const CARRY_BASES:=["idle","walk","walk_back","strafe_left","strafe_right"]
const CarryReport=preload("res://tests/ink_q1_flow_20261005/gesture06/root_return_rebuilt01/recovery_follow02/side_carry04/runtime/carry_report.gd")
var carry_indices: Array[int]=[]
var carry_base_samples: Dictionary={}
var carry_ready: bool=false
var carry_binding: Dictionary={}

func _ready() -> void:
 super._ready()
 if proof.status == "HOLD": return
 if FileAccess.get_sha256(CARRY_BINDING)!=CARRY_BINDING_SHA:
  proof.errors.append("Q1_carry_asset_not_authored_and_bound"); proof.status="HOLD"; return
 var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CARRY_BINDING))
 if not data is Dictionary or data.get("schema","") != "ink-q1-carry-asset-binding-1":
  proof.errors.append("Q1_carry_asset_binding_invalid"); proof.status="HOLD"; return
 carry_binding=data
 if carry_binding.get("asset_sha256","")!=CARRY_ASSET_SHA or FileAccess.get_sha256(CARRY_ASSET) != str(carry_binding.get("asset_sha256","")) or carry_binding.get("base_asset_sha256","") != CARRY_BASE_SHA:
  proof.errors.append("Q1_carry_exact_asset_mismatch"); proof.status="HOLD"; return
 var authority_path: String=CARRY_ROOT+"source_boundaries.json"
 if FileAccess.get_sha256(authority_path) != str(carry_binding.get("boundaries_sha256","")):
  proof.errors.append("Q1_carry_boundary_mismatch"); proof.status="HOLD"; return
 var authority: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(authority_path))
 if authority.get("asset_sha256","")!=CARRY_ASSET_SHA or carry_binding.get("carry_runtime_copy_bones",[])!=CARRY_BONES:
  proof.errors.append("Q1_carry_authority_mismatch"); proof.status="HOLD"; return
 for bone: String in CARRY_BONES:
  var bone_index: int=skeleton.find_bone(bone)
  if bone_index<0:proof.errors.append("Q1_carry_copy_bone_missing:"+bone)
  else:carry_indices.append(bone_index)
 var settings:=ConfigFile.new()
 if settings.load(CARRY_ASSET+".import") != OK or int(settings.get_value("params","animation/fps",-1)) != 30 or settings.get_value("params","animation/remove_immutable_tracks",null) != true:
  proof.errors.append("Q1_carry_import_settings_mismatch"); proof.status="HOLD"; return
 if not ResourceLoader.exists(CARRY_ASSET):
  proof.errors.append("Q1_carry_asset_unimported"); proof.status="HOLD"; return
 var packed: PackedScene=load(CARRY_ASSET)
 if packed==null:
  proof.errors.append("Q1_carry_packed_scene_missing"); proof.status="HOLD"; return
 var temporary: Node=packed.instantiate()
 var incoming: AnimationPlayer=_flow_find_type(temporary,"AnimationPlayer")
 var incoming_skeleton: Skeleton3D=_flow_find_type(temporary,"Skeleton3D")
 if incoming == null or incoming_skeleton == null or incoming_skeleton.get_bone_count() != skeleton.get_bone_count():
  proof.errors.append("Q1_carry_imported_rig_missing"); temporary.free(); proof.status="HOLD"; return
 for index in range(skeleton.get_bone_count()):
  if incoming_skeleton.get_bone_name(index) != skeleton.get_bone_name(index) or incoming_skeleton.get_bone_parent(index) != skeleton.get_bone_parent(index) or incoming_skeleton.get_bone_rest(index) != skeleton.get_bone_rest(index):
   proof.errors.append("Q1_carry_rest_rig_changed:"+str(index))
 var library:=AnimationLibrary.new()
 player.add_animation_library("q1_carry_rotation_only",library)
 var animation_root: Node=player.get_node_or_null(player.root_node)
 var evidence: Dictionary={}
 for alias: String in CARRY_ALIASES:
  var source_name: String=CARRY_ALIASES[alias]
  var found: StringName=&""
  for full_name: StringName in incoming.get_animation_list():
   if str(full_name).get_file() == source_name: found=full_name; break
  if found == &"": proof.errors.append("Q1_carry_clip_missing:"+source_name); continue
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
   if target != skeleton or index < 0: proof.errors.append("Q1_carry_target_mismatch:"+str(path)); continue
   if int(row.type)==Animation.TYPE_ROTATION_3D and bone in UPPER:
    if not authority.clips[source_name].tracks.has(bone+":rotation") or int(row.key_count)<1 or raw.track_get_key_time(track,0)!=0.0:
     proof.errors.append("Q1_carry_missing_authored_rotation:"+bone)
    retained.push_front(row)
    continue
   var rest: Transform3D=skeleton.get_bone_rest(index)
   var expected: Variant=rest.origin if int(row.type)==Animation.TYPE_POSITION_3D else rest.basis.get_rotation_quaternion() if int(row.type)==Animation.TYPE_ROTATION_3D else rest.basis.get_scale() if int(row.type)==Animation.TYPE_SCALE_3D else null
   if int(row.key_count)!=1 or not Filter.exact_rest_value(raw.track_get_key_value(track,0),expected):
    proof.errors.append("Q1_carry_nonupper_authority:"+str(path)); continue
   local.remove_track(track)
  for key: String in authority.clips[source_name].tracks:
   if bool(authority.clips[source_name].tracks[key].all_values_identical): continue
   var bone: String=str(authority.clips[source_name].tracks[key].bone)
   if not retained.any(func(row): return str(row.bone)==bone): proof.errors.append("Q1_carry_dynamic_rotation_dropped:"+bone)
  var inspected: Dictionary=AuthoredZero.inspect(local,authority.clips[source_name],skeleton,animation_root)
  for error: String in inspected.errors: proof.errors.append(source_name+":"+error)
  library.add_animation(source_name,local)
  clip_names[alias]=StringName("q1_carry_rotation_only/"+source_name)
  key_windows[alias]=key_window(local)
  if not key_windows[alias].valid:proof.errors.append("Q1_carry_invalid_window:"+alias)
  evidence[alias]={"source_clip":source_name,"retained_upper_rotations":retained.size(),"authored_zero":inspected,"key_window":key_windows[alias]}
 temporary.free()
 skeleton.reset_bone_poses()
 carry_ready=proof.errors.is_empty()
 if not carry_ready: proof.status="HOLD"
 proof["q1_carry"]={"asset_sha256":carry_binding.asset_sha256,"mesh_asset_unchanged":Q3_MODEL_SHA,"new_rotation_clips_only":true,"base_copy_bones":CARRY_BONES,"base_copy_aliases":CARRY_BASES,"full_release_seconds":.60,"clips":evidence,"art_accepted":false}


func _sample(clip: String, at: float) -> Array[Transform3D]:
 var result: Array[Transform3D]=super._sample(clip,at)
 if not carry_ready or clip not in CARRY_BASES:return result
 # All locomotion timing still comes from the original source-driven gait.
 # Idle shares release's authored endpoint; walk uses its existing cycle phase.
 var window: Dictionary=key_windows.brush_carry_upper
 var phase: float=0.0 if clip=="idle" else fposmod(at-float(key_windows[clip].first),float(directional_contract.cycle_seconds))/float(directional_contract.cycle_seconds)
 var carry_at: float=float(window.first)+phase*float(window.span)
 var carry_pose: Array[Transform3D]=super._sample("brush_carry_upper",carry_at)
 for index: int in carry_indices:
  var original: Transform3D=result[index]
  original.basis=Basis(carry_pose[index].basis.get_rotation_quaternion()).scaled(original.basis.get_scale())
  result[index]=original
 carry_base_samples[clip]={"base_time":at,"gait_phase_fraction":phase,"carry_time":carry_at,"rotation_bones":CARRY_BONES,"positions_and_scales_from_base":true,"other_34_bones_from_base":true}
 return result

func present(ink: Dictionary) -> void:
 super.present(ink)
 sample_report["q1_carry"]=CarryReport.capture(self)
 # Old proofs remain explicit ancestry, not evidence for the current aliases.
 if sample_report.has("q1_flow"):
  sample_report.q1_flow.clip_aliases={"q1_draw_upper":CARRY_ALIASES.q1_draw_upper,"q1_hold_upper":CARRY_ALIASES.q1_hold_upper,"q1_release_upper":CARRY_ALIASES.q1_release_upper}
  sample_report.q1_flow["active_consumer"]="q1_carry"
 if sample_report.has("q1_intent"):
  sample_report.q1_intent["provenance_only"]=true
  sample_report.q1_intent["active_consumer"]=false

func _reset_instance_view7() -> void:
 super._reset_instance_view7()
 carry_base_samples.clear()
