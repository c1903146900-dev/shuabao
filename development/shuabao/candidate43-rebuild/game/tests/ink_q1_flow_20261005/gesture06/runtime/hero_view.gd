extends "res://tests/ink_q1_flow_20261005/runtime/fix02/parsefix01/hero_view.gd"
const INTENT_ROOT:="res://tests/ink_q1_flow_20261005/gesture06/runtime/"
const INTENT_ASSET:=INTENT_ROOT+"assets/yanguizhou_q1_intent.glb"
const INTENT_BINDING:=INTENT_ROOT+"asset_binding.json"
const INTENT_BASE_SHA:="b558f0c56aeacb1d6455b85a474e435921f82b281540c4952f3d474d9abad589"
const INTENT_ALIASES:={"q1_draw_upper":"q1_intent_draw_upper","q1_hold_upper":"q1_intent_hold_upper","q1_release_upper":"q1_intent_release_upper"}
var intent_ready: bool=false
var intent_binding: Dictionary={}

func _ready() -> void:
 super._ready()
 if proof.status == "HOLD": return
 if not FileAccess.file_exists(INTENT_BINDING):
  proof.errors.append("Q1_flow_asset_not_authored_and_bound"); proof.status="HOLD"; return
 var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(INTENT_BINDING))
 if not data is Dictionary or data.get("schema","") != "ink-q1-intent-asset-binding-1":
  proof.errors.append("Q1_flow_asset_binding_invalid"); proof.status="HOLD"; return
 intent_binding=data
 if FileAccess.get_sha256(INTENT_ASSET) != str(intent_binding.get("asset_sha256","")) or intent_binding.get("base_asset_sha256","") != INTENT_BASE_SHA:
  proof.errors.append("Q1_flow_exact_asset_mismatch"); proof.status="HOLD"; return
 var authority_path: String=INTENT_ROOT+"source_boundaries.json"
 if FileAccess.get_sha256(authority_path) != str(intent_binding.get("boundaries_sha256","")):
  proof.errors.append("Q1_flow_boundary_mismatch"); proof.status="HOLD"; return
 var authority: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(authority_path))
 var settings:=ConfigFile.new()
 if settings.load(INTENT_ASSET+".import") != OK or int(settings.get_value("params","animation/fps",-1)) != 30 or settings.get_value("params","animation/remove_immutable_tracks",null) != true:
  proof.errors.append("Q1_flow_import_settings_mismatch"); proof.status="HOLD"; return
 if not ResourceLoader.exists(INTENT_ASSET):
  proof.errors.append("Q1_flow_asset_unimported"); proof.status="HOLD"; return
 var packed: PackedScene=load(INTENT_ASSET)
 var temporary: Node=packed.instantiate()
 var incoming: AnimationPlayer=_flow_find_type(temporary,"AnimationPlayer")
 var incoming_skeleton: Skeleton3D=_flow_find_type(temporary,"Skeleton3D")
 if incoming == null or incoming_skeleton == null or incoming_skeleton.get_bone_count() != skeleton.get_bone_count():
  proof.errors.append("Q1_flow_imported_rig_missing"); temporary.free(); proof.status="HOLD"; return
 for index in range(skeleton.get_bone_count()):
  if incoming_skeleton.get_bone_name(index) != skeleton.get_bone_name(index) or incoming_skeleton.get_bone_parent(index) != skeleton.get_bone_parent(index) or incoming_skeleton.get_bone_rest(index) != skeleton.get_bone_rest(index):
   proof.errors.append("Q1_flow_rest_rig_changed:"+str(index))
 var library:=AnimationLibrary.new()
 player.add_animation_library("q1_intent_rotation_only",library)
 var animation_root: Node=player.get_node_or_null(player.root_node)
 var evidence: Dictionary={}
 for alias: String in INTENT_ALIASES:
  var source_name: String=INTENT_ALIASES[alias]
  var found: StringName=&""
  for full_name: StringName in incoming.get_animation_list():
   if str(full_name).get_file() == source_name: found=full_name; break
  if found == &"": proof.errors.append("Q1_flow_clip_missing:"+source_name); continue
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
   if target != skeleton or index < 0: proof.errors.append("Q1_flow_target_mismatch:"+str(path)); continue
   if int(row.type)==Animation.TYPE_ROTATION_3D and bone in UPPER:
    if not authority.clips[source_name].tracks.has(bone+":rotation") or int(row.key_count)<1 or raw.track_get_key_time(track,0)!=0.0:
     proof.errors.append("Q1_flow_missing_authored_rotation:"+bone)
    retained.push_front(row)
    continue
   var rest: Transform3D=skeleton.get_bone_rest(index)
   var expected: Variant=rest.origin if int(row.type)==Animation.TYPE_POSITION_3D else rest.basis.get_rotation_quaternion() if int(row.type)==Animation.TYPE_ROTATION_3D else rest.basis.get_scale() if int(row.type)==Animation.TYPE_SCALE_3D else null
   if int(row.key_count)!=1 or not Filter.exact_rest_value(raw.track_get_key_value(track,0),expected):
    proof.errors.append("Q1_flow_nonupper_authority:"+str(path)); continue
   local.remove_track(track)
  for key: String in authority.clips[source_name].tracks:
   if bool(authority.clips[source_name].tracks[key].all_values_identical): continue
   var bone: String=str(authority.clips[source_name].tracks[key].bone)
   if not retained.any(func(row): return str(row.bone)==bone): proof.errors.append("Q1_flow_dynamic_rotation_dropped:"+bone)
  var inspected: Dictionary=AuthoredZero.inspect(local,authority.clips[source_name],skeleton,animation_root)
  for error: String in inspected.errors: proof.errors.append(source_name+":"+error)
  library.add_animation(source_name,local)
  clip_names[alias]=StringName("q1_intent_rotation_only/"+source_name)
  key_windows[alias]=key_window(local)
  evidence[alias]={"source_clip":source_name,"retained_upper_rotations":retained.size(),"authored_zero":inspected,"key_window":key_windows[alias]}
 temporary.free()
 skeleton.reset_bone_poses()
 intent_ready=proof.errors.is_empty()
 if not intent_ready: proof.status="HOLD"
 proof["q1_intent"]={"asset_sha256":intent_binding.asset_sha256,"mesh_asset_unchanged":Q3_MODEL_SHA,"new_rotation_clips_only":true,"clips":evidence,"art_accepted":false}


func present(ink: Dictionary) -> void:
 super.present(ink)
 sample_report["q1_intent"]={"ready":intent_ready,"asset_sha256":intent_binding.get("asset_sha256",""),"aliases":INTENT_ALIASES,"cosmetic_release_seconds":.60,"source_release_delayed":false,"art_accepted":false}
 if sample_report.has("q1_flow"):sample_report.q1_flow.clip_aliases=INTENT_ALIASES
