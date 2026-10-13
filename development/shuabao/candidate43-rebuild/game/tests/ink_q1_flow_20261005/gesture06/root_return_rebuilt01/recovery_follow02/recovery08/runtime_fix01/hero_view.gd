extends "res://tests/ink_q1_flow_20261005/gesture06/root_return_rebuilt01/recovery_follow02/gait06/runtime/hero_view.gd"
## Only the release alias is replaced; inherited gait/carry/root/lower unchanged.
const RECOVERY_ROOT:="res://tests/ink_q1_flow_20261005/gesture06/root_return_rebuilt01/recovery_follow02/recovery08/runtime_fix01/"
const RECOVERY_ASSET:=RECOVERY_ROOT+"assets/yanguizhou_recovery08.glb"
const RECOVERY_BINDING:=RECOVERY_ROOT+"asset_binding.json"
const RECOVERY_ASSET_SHA:="8101c8416dcef08bdc5f9190a9b3a6f9c4441a4eaed02707011e1c0b635bff74"
const RECOVERY_BINDING_SHA:="022ae3172e5c0873fcefb951e1e6f146225a61a6178cc9962b7a59c44b9e4116"
const RECOVERY_BASE_SHA:="ab82094e79fc2d4391034f1ff32774287dfc95de9b25a7dc893960e1116c04b1"
const RECOVERY_ALIASES:={"q1_release_upper":"q1_recovery08_release_upper"}
const RecoveryReport=preload("res://tests/ink_q1_flow_20261005/gesture06/root_return_rebuilt01/recovery_follow02/recovery08/runtime_fix01/recovery_report.gd")
var recovery_ready: bool=false
var recovery_binding: Dictionary={}
func _ready() -> void:
 super._ready()
 if proof.status == "HOLD": return
 if FileAccess.get_sha256(RECOVERY_BINDING)!=RECOVERY_BINDING_SHA:
  proof.errors.append("Q1_recovery08_asset_not_authored_and_bound"); proof.status="HOLD"; return
 var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(RECOVERY_BINDING))
 if not data is Dictionary or data.get("schema","") != "ink-q1-recovery08-asset-binding-1":
  proof.errors.append("Q1_recovery08_asset_binding_invalid"); proof.status="HOLD"; return
 recovery_binding=data
 if recovery_binding.get("asset_sha256","")!=RECOVERY_ASSET_SHA or FileAccess.get_sha256(RECOVERY_ASSET) != str(recovery_binding.get("asset_sha256","")) or recovery_binding.get("base_asset_sha256","") != RECOVERY_BASE_SHA:
  proof.errors.append("Q1_recovery08_exact_asset_mismatch"); proof.status="HOLD"; return
 var authority_path: String=RECOVERY_ROOT+"source_boundaries.json"
 if FileAccess.get_sha256(authority_path) != str(recovery_binding.get("boundaries_sha256","")):
  proof.errors.append("Q1_recovery08_boundary_mismatch"); proof.status="HOLD"; return
 var authority: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(authority_path))
 if authority.get("asset_sha256","")!=RECOVERY_ASSET_SHA or recovery_binding.get("upper_rotation_bones",[])!=UPPER:
  proof.errors.append("Q1_recovery08_authority_mismatch"); proof.status="HOLD"; return
 var settings:=ConfigFile.new()
 if settings.load(RECOVERY_ASSET+".import") != OK or int(settings.get_value("params","animation/fps",-1)) != 30 or settings.get_value("params","animation/remove_immutable_tracks",null) != true:
  proof.errors.append("Q1_recovery08_import_settings_mismatch"); proof.status="HOLD"; return
 if not ResourceLoader.exists(RECOVERY_ASSET):
  proof.errors.append("Q1_recovery08_asset_unimported"); proof.status="HOLD"; return
 var packed: PackedScene=load(RECOVERY_ASSET)
 if packed==null:
  proof.errors.append("Q1_recovery08_packed_scene_missing"); proof.status="HOLD"; return
 var temporary: Node=packed.instantiate()
 var incoming: AnimationPlayer=_flow_find_type(temporary,"AnimationPlayer")
 var incoming_skeleton: Skeleton3D=_flow_find_type(temporary,"Skeleton3D")
 if incoming == null or incoming_skeleton == null or incoming_skeleton.get_bone_count() != skeleton.get_bone_count():
  proof.errors.append("Q1_recovery08_imported_rig_missing"); temporary.free(); proof.status="HOLD"; return
 for index in range(skeleton.get_bone_count()):
  if incoming_skeleton.get_bone_name(index) != skeleton.get_bone_name(index) or incoming_skeleton.get_bone_parent(index) != skeleton.get_bone_parent(index) or incoming_skeleton.get_bone_rest(index) != skeleton.get_bone_rest(index):
   proof.errors.append("Q1_recovery08_rest_rig_changed:"+str(index))
 var library:=AnimationLibrary.new()
 player.add_animation_library("q1_recovery08_rotation_only",library)
 var animation_root: Node=player.get_node_or_null(player.root_node)
 var evidence: Dictionary={}
 for alias: String in RECOVERY_ALIASES:
  var source_name: String=RECOVERY_ALIASES[alias]
  var found: StringName=&""
  for full_name: StringName in incoming.get_animation_list():
   if str(full_name).get_file() == source_name: found=full_name; break
  if found == &"": proof.errors.append("Q1_recovery08_clip_missing:"+source_name); continue
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
   if target != skeleton or index < 0: proof.errors.append("Q1_recovery08_target_mismatch:"+str(path)); continue
   if int(row.type)==Animation.TYPE_ROTATION_3D and bone in UPPER:
    if not authority.clips[source_name].tracks.has(bone+":rotation") or int(row.key_count)<1 or raw.track_get_key_time(track,0)!=0.0:
     proof.errors.append("Q1_recovery08_missing_authored_rotation:"+bone)
    retained.push_front(row)
    continue
   var rest: Transform3D=skeleton.get_bone_rest(index)
   var expected: Variant=rest.origin if int(row.type)==Animation.TYPE_POSITION_3D else rest.basis.get_rotation_quaternion() if int(row.type)==Animation.TYPE_ROTATION_3D else rest.basis.get_scale() if int(row.type)==Animation.TYPE_SCALE_3D else null
   if int(row.key_count)!=1 or not Filter.exact_rest_value(raw.track_get_key_value(track,0),expected):
    proof.errors.append("Q1_recovery08_nonupper_authority:"+str(path)); continue
   local.remove_track(track)
  for key: String in authority.clips[source_name].tracks:
   if bool(authority.clips[source_name].tracks[key].all_values_identical): continue
   var bone: String=str(authority.clips[source_name].tracks[key].bone)
   if not retained.any(func(row): return str(row.bone)==bone): proof.errors.append("Q1_recovery08_dynamic_rotation_dropped:"+bone)
  var inspected: Dictionary=AuthoredZero.inspect(local,authority.clips[source_name],skeleton,animation_root)
  for error: String in inspected.errors: proof.errors.append(source_name+":"+error)
  library.add_animation(source_name,local)
  clip_names[alias]=StringName("q1_recovery08_rotation_only/"+source_name)
  key_windows[alias]=key_window(local)
  if not key_windows[alias].valid:proof.errors.append("Q1_recovery08_invalid_window:"+alias)
  evidence[alias]={"source_clip":source_name,"retained_upper_rotations":retained.size(),"authored_zero":inspected,"key_window":key_windows[alias]}
 temporary.free()
 skeleton.reset_bone_poses()
 recovery_ready=proof.errors.is_empty()
 if not recovery_ready: proof.status="HOLD"
 proof["recovery08"]={"asset_sha256":recovery_binding.asset_sha256,"mesh_asset_unchanged":Q3_MODEL_SHA,"clips":evidence,"full_release_seconds":.60,"protected_raw_through":8.0/30.0,"only_release_replaced":true,"walk_gait_lower_unchanged":true,"art_accepted":false}

func present(ink: Dictionary) -> void:
 super.present(ink)
 sample_report["recovery08"]=RecoveryReport.capture(self)
 if sample_report.has("q1_flow"):
  sample_report.q1_flow.clip_aliases.q1_release_upper=RECOVERY_ALIASES.q1_release_upper
  sample_report.q1_flow["active_consumer"]="side_carry04_draw_hold_and_recovery08_release"
 if sample_report.has("q1_carry"):
  sample_report.q1_carry["scope"]="draw/hold/walk-carry retained; old release is provenance only"
