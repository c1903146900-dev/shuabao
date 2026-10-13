extends "res://tests/ink_q1_flow_20261005/gesture06/root_return_rebuilt01/recovery_follow02/recovery08/runtime_fix01/hero_view.gd"
## Independent imported-binding candidate. Only UID preflight and an instance test seam are new.
const Ultimate_ROOT := "res://tests/ink_ultimate_presentation_art_20261006/dual_v03/"
const Ultimate_ASSET := "res://tests/ink_r2_presentation_art_20261006/candidate01/variant03/yanguizhou_r2_presentation.glb"
const Ultimate_BINDING := Ultimate_ROOT+"dual_asset_binding.json"
const Ultimate_BOUNDARIES := Ultimate_ROOT+"dual_source_boundaries.json"
const Ultimate_RAW_BOUNDARIES := "res://tests/ink_ultimate_presentation_art_20261006/dual_v03/imported_gate01/raw_boundary_authority.json"
const Ultimate_RAW_BOUNDARIES_SHA := "a5404351ad8b219a6d782b21d1d5eddaedd5d67bf7f1db763cb47e65bae55efc"
const Ultimate_PARENT_SHA := "34468129542063638658e329e084d56a633905aeed45b61f87754ee71302a85b"
const Ultimate_ALIASES := {"yanguizhou_r1":"r1_presentation_upper","yanguizhou_r2":"r2_presentation_upper"}
const UltimateAdapter = preload("res://tests/ink_ultimate_presentation_art_20261006/dual_v03/presenter_adapter.gd")
const Ultimate_ENTRY_SECONDS := 0.07
const Ultimate_EXIT_SECONDS := 0.08
var ultimate_clock: RefCounted = UltimateAdapter.new()
var ultimate_ready: bool = false
var ultimate_binding: Dictionary = {}
var ultimate_report: Dictionary = {}
var _ultimate_scope: Dictionary = {}
var _ultimate_token: Dictionary = {}
var _ultimate_underlying_pose: Array[Transform3D] = []
var _ultimate_entry_pose: Array[Transform3D] = []
var _ultimate_entry_basis: Basis = Basis.IDENTITY
var _ultimate_entry_actor: float = -1.0
var _ultimate_entry_sample: float = 0.0
var _ultimate_had_visible: bool = false
var _ultimate_actor_deadline: float = -1.0
var _ultimate_exit_pose: Array[Transform3D] = []
var _ultimate_exit_basis: Basis = Basis.IDENTITY
var _ultimate_exit_actor: float = -1.0

func _ready() -> void:
 super._ready()
 proof["ultimate_presentation"] = {"status":"ASSET_NOT_BOUND", "art_accepted":false, "ordinary_identity_integrated":false}

func present(ink: Dictionary) -> void:
 if str(presentation_context.get("phase", "")) in ["preparation", "victory"]:
  _reset_ultimate_state()
 super.present(ink)

func bind_ultimate_presentation_source(source: Node) -> Dictionary:
 return ultimate_clock.bind_source(source)

func bind_ultimate_asset(expected_asset_sha: String, expected_binding_sha: String) -> Dictionary:
 if proof.status=="HOLD" or not recovery_ready:return {"accepted":false,"reason":"parent_actor_not_ready"}
 if ultimate_ready:return {"accepted":false,"reason":"already_bound"}
 if expected_asset_sha.length()!=64 or expected_binding_sha.length()!=64:return {"accepted":false,"reason":"external_hash_pins_required"}
 if FileAccess.get_sha256(Ultimate_ASSET)!=expected_asset_sha or FileAccess.get_sha256(Ultimate_BINDING)!=expected_binding_sha:return {"accepted":false,"reason":"dual_asset_binding_changed"}
 var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(Ultimate_BINDING))
 if not data is Dictionary or data.get("schema","")!="ink-dual-ultimate-asset-binding-1":return {"accepted":false,"reason":"dual_binding_invalid"}
 if data.asset_sha256!=expected_asset_sha or data.base_asset_sha256!=Ultimate_PARENT_SHA or data.upper_rotation_bones!=UPPER or int(data.old_clips)!=32 or int(data.bones)!=44:return {"accepted":false,"reason":"dual_parent_bone_contract"}
 if FileAccess.get_sha256(Ultimate_BOUNDARIES)!=data.boundaries_sha256:return {"accepted":false,"reason":"dual_boundaries_changed"}
 if FileAccess.get_sha256(Ultimate_RAW_BOUNDARIES)!=Ultimate_RAW_BOUNDARIES_SHA:return {"accepted":false,"reason":"dual_raw_boundaries_changed"}
 var authority: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Ultimate_RAW_BOUNDARIES))
 if authority.get("asset_sha256","")!=expected_asset_sha:return {"accepted":false,"reason":"dual_authority_asset_mismatch"}
 var settings:=ConfigFile.new()
 if settings.load(Ultimate_ASSET+".import")!=OK or int(settings.get_value("params","animation/fps",-1))!=30 or settings.get_value("params","animation/remove_immutable_tracks",null)!=true:return {"accepted":false,"reason":"real_standard_import_required"}
 var uid_errors: Array[String]=_ultimate_standard_import_uid_errors()
 if not uid_errors.is_empty():return {"accepted":false,"reason":"dual_uid_mapping_invalid","errors":uid_errors}
 if not ResourceLoader.exists(Ultimate_ASSET):return {"accepted":false,"reason":"not_imported"}
 var packed: PackedScene=load(Ultimate_ASSET)
 if packed==null:return {"accepted":false,"reason":"imported_scene_missing"}
 var temporary: Node=_ultimate_create_instance(packed)
 var incoming: AnimationPlayer=_flow_find_type(temporary,"AnimationPlayer")
 var rig: Skeleton3D=_flow_find_type(temporary,"Skeleton3D")
 var errors: Array[String]=[]
 if incoming==null or rig==null or rig.get_bone_count()!=skeleton.get_bone_count():temporary.free();return {"accepted":false,"reason":"imported_rig_missing"}
 for index in range(skeleton.get_bone_count()):
  if rig.get_bone_name(index)!=skeleton.get_bone_name(index) or rig.get_bone_parent(index)!=skeleton.get_bone_parent(index) or rig.get_bone_rest(index)!=skeleton.get_bone_rest(index):errors.append("original_rig_changed:"+str(index))
 var animation_root: Node=player.get_node_or_null(player.root_node)
 var prepared: Dictionary={}
 var inspected_rows: Dictionary={}
 for ability: String in Ultimate_ALIASES:
  var clip_name: String=str(data.clips[ability].clip)
  var duration: float=float(data.clips[ability].duration)
  if not ultimate_clock.durations.has(ability) or duration!=float(ultimate_clock.durations[ability]) or not authority.clips.has(clip_name):errors.append("dual_duration_or_authority:"+ability);continue
  var found: StringName=&""
  for full_name: StringName in incoming.get_animation_list():
   if str(full_name).get_file()==clip_name:found=full_name;break
  if found==&"":errors.append("dual_clip_missing:"+clip_name);continue
  var raw: Animation=incoming.get_animation(found)
  var local: Animation=raw.duplicate(true)
  var retained: Array[String]=[]
  for track in range(raw.get_track_count()-1,-1,-1):
   var row: Dictionary=Filter.track_evidence(raw,track)
   var path: NodePath=raw.track_get_path(track)
   var bone: String=str(row.bone)
   var index: int=skeleton.find_bone(bone)
   if animation_root.get_node_or_null(NodePath(path.get_concatenated_names()))!=skeleton or index<0:errors.append("dual_track_target:"+str(path));continue
   if int(row.type)==Animation.TYPE_ROTATION_3D and bone in UPPER:
    if not authority.clips[clip_name].tracks.has(bone+":rotation") or int(row.key_count)<1 or raw.track_get_key_time(track,0)!=0.0:errors.append("dual_authored_rotation_missing:"+bone)
    retained.append(bone);continue
   var rest: Transform3D=skeleton.get_bone_rest(index)
   var expected: Variant=rest.origin if int(row.type)==Animation.TYPE_POSITION_3D else rest.basis.get_rotation_quaternion() if int(row.type)==Animation.TYPE_ROTATION_3D else rest.basis.get_scale() if int(row.type)==Animation.TYPE_SCALE_3D else null
   if int(row.key_count)!=1 or not Filter.exact_rest_value(raw.track_get_key_value(track,0),expected):errors.append("dual_forbidden_track:"+str(path));continue
   local.remove_track(track)
  for key: String in authority.clips[clip_name].tracks:
   var row: Dictionary=authority.clips[clip_name].tracks[key]
   if not bool(row.all_values_identical) and str(row.bone) not in retained:errors.append("dual_dynamic_upper_dropped:"+str(row.bone))
  var inspected: Dictionary=AuthoredZero.inspect(local,authority.clips[clip_name],skeleton,animation_root)
  for error: String in inspected.errors:errors.append(error)
  var window: Dictionary=key_window(local)
  if not window.valid or absf(float(window.span)-duration)>0.00001:errors.append("dual_clip_window:"+clip_name)
  prepared[ability]={"clip_name":clip_name,"animation":local,"window":window}
  inspected_rows[ability]={"retained_upper":retained,"authored_zero":inspected,"window":window}
 temporary.free()
 if not errors.is_empty() or prepared.size()!=2:return {"accepted":false,"reason":"dual_import_consumer_failed","errors":errors}
 # Commit both clips atomically after all actual imported tracks validate.
 var library:=AnimationLibrary.new()
 for ability: String in prepared:library.add_animation(prepared[ability].clip_name,prepared[ability].animation)
 player.add_animation_library("dual_ultimate_upper",library)
 for ability: String in prepared:
  var alias: String=str(Ultimate_ALIASES[ability])
  clip_names[alias]=StringName("dual_ultimate_upper/"+str(prepared[ability].clip_name))
  key_windows[alias]=prepared[ability].window
 ultimate_binding=data;ultimate_ready=true
 proof["dual_ultimate"]={"status":"BOUND_NUMERIC_ONLY","asset_sha256":expected_asset_sha,"binding_sha256":expected_binding_sha,"clips":inspected_rows,"art_accepted":false,"ordinary_identity_integrated":false}
 return {"accepted":true,"reason":"both_imported_clips_bound_numeric_only","art_accepted":false}

func _ultimate_descriptor_uid(settings: ConfigFile) -> String:
 return str(settings.get_value("remap","uid",""))

func _ultimate_create_instance(packed: PackedScene) -> Node:
 return packed.instantiate()

func _ultimate_standard_import_uid_errors() -> Array[String]:
 # Read standard descriptors and the engine registry. Never repair or add a UID.
 var errors: Array[String]=[]
 var count: int=0
 var texture_count: int=0
 var directory: String=Ultimate_ASSET.get_base_dir()
 var source_name: String=Ultimate_ASSET.get_file()
 var image_prefix: String=source_name.get_basename()+"_"
 for filename: String in DirAccess.get_files_at(directory):
  if filename!=source_name+".import" and not (filename.begins_with(image_prefix) and filename.ends_with(".png.import")):continue
  count+=1
  var descriptor: String=directory.path_join(filename)
  var settings:=ConfigFile.new()
  if settings.load(descriptor)!=OK:errors.append("descriptor_unreadable:"+descriptor);continue
  var source: String=str(settings.get_value("deps","source_file",""))
  var expected_source: String=directory.path_join(filename.trim_suffix(".import"))
  if source!=expected_source:errors.append("descriptor_wrong_source:"+descriptor)
  var id: int=ResourceUID.text_to_id(_ultimate_descriptor_uid(settings))
  if id==ResourceUID.INVALID_ID or not ResourceUID.has_id(id) or ResourceUID.get_id_path(id)!=source:errors.append("uid_unresolved_or_wrong_source:"+source)
  var remap: String=str(settings.get_value("remap","path",""))
  if remap.is_empty() or not FileAccess.file_exists(remap) or not ResourceLoader.exists(source):errors.append("standard_resource_missing:"+source)
  if source.ends_with(".png"):texture_count+=1
 if count!=10 or texture_count!=9:errors.append("expected_one_scene_nine_texture_descriptors")
 return errors

func _reset_ultimate_state() -> void:
 _ultimate_scope.clear(); _ultimate_token.clear(); _ultimate_underlying_pose.clear(); _ultimate_entry_pose.clear()
 _ultimate_exit_pose.clear(); _ultimate_entry_actor = -1.0; _ultimate_exit_actor = -1.0; _ultimate_had_visible = false; _ultimate_actor_deadline = -1.0
 ultimate_clock.reset()
 ultimate_report.clear()

func _reset_instance_view7() -> void:
 super._reset_instance_view7()
 _reset_ultimate_state()

func _upper_rotations_into(base: Array[Transform3D], overlay: Array[Transform3D], weight: float) -> Array[Transform3D]:
 var result: Array[Transform3D] = base.duplicate()
 for index in range(result.size()):
  if str(skeleton.get_bone_name(index)) not in UPPER: continue
  var from_q: Quaternion = base[index].basis.get_rotation_quaternion()
  var to_q: Quaternion = overlay[index].basis.get_rotation_quaternion()
  result[index].basis = Basis(from_q.slerp(to_q, weight)).scaled(base[index].basis.get_scale())
 return result

func _rebase_upper(captured: Array[Transform3D], captured_basis: Basis, base: Array[Transform3D]) -> Array[Transform3D]:
 var result: Array[Transform3D] = _upper_rotations_into(base, captured, 1.0)
 var world_chest: Basis = captured_basis * _global_pose(captured, chest_index).basis
 _set_global_basis(result, chest_index, skeleton.global_basis.inverse() * world_chest)
 return result

func _ultimate_next_inherited_key(ink: Dictionary) -> String:
 # Mirrors only the inherited ownership key, not its sampling or event timing.
 var input: Dictionary = ink.get("input", {})
 var phase: String = str(input.get("phase", ""))
 if phase in ["drawing", "frozen"]:
  return ("q1_draw_upper" if phase == "drawing" else "q1_hold_upper") + ":" + str(input.get("gesture_id", ""))
 var now: float = float(ink.get("source_time", 0.0))
 if not event_action.is_empty() and event_at >= 0.0 and key_windows.has(event_action) and now - event_at < float(key_windows[event_action].span):
  return event_action + ":" + event_identity
 return ""

func _present_combat_q3(ink: Dictionary) -> void:
 var scope_changed: bool = _ultimate_scope != ink.get("scope", {})
 if scope_changed:
  _reset_ultimate_state()
  _ultimate_scope = ink.get("scope", {}).duplicate(true)
 var previous: Array[Transform3D] = []
 if not scope_changed: previous.assign(last_rendered_pose)
 var previous_basis: Basis = last_skeleton_basis
 var timing: Dictionary = ultimate_clock.read(ink)
 var next_inherited_key: String = _ultimate_next_inherited_key(ink)
 var actual_handoff: bool = not next_inherited_key.is_empty() and next_inherited_key != transition_key
 # The ordinary chest limiter must never receive last frame's R chest and then
 # have this frame's absolute R rotation added on top. Its independent history
 # stays clean. Only a new Q/basic owner gets the actual rendered entry pose.
 if not actual_handoff and _ultimate_underlying_pose.size() == last_rendered_pose.size():
  last_rendered_pose = _ultimate_underlying_pose.duplicate()
 super._present_combat_q3(ink)
 if proof.status == "HOLD" or player == null or skeleton == null or last_rendered_pose.is_empty(): return
 var inherited: Array[Transform3D] = last_rendered_pose.duplicate()
 if bool(sample_report.get("pose_cache_reused", false)) and _ultimate_underlying_pose.size() == inherited.size():
  inherited = _ultimate_underlying_pose.duplicate()
 else:
  _ultimate_underlying_pose = inherited.duplicate()
 var actor_now: float = float(timing.actor_time)
 var elapsed: float = float(timing.get("elapsed", 0.0))
 var upper: String = str(sample_report.get("upper", ""))
 var dash: bool = float(ink.get("hero", {}).get("dash_left", 0.0)) > 0.0
 var priority: String = "Shift" if dash else upper
 var live: bool = ultimate_ready and bool(timing.active)
 var visible: bool = live and priority.is_empty()
 var result: Array[Transform3D] = inherited.duplicate()
 var weight: float = 0.0
 if visible:
  var token: Dictionary = timing.token
  if token != _ultimate_token or not _ultimate_had_visible:
   _ultimate_token = token.duplicate(true)
   _ultimate_entry_pose = previous.duplicate() if previous.size() == inherited.size() else inherited.duplicate()
   _ultimate_entry_basis = previous_basis if previous.size() == inherited.size() else skeleton.global_basis
   _ultimate_entry_actor = actor_now
   _ultimate_entry_sample = elapsed
   _ultimate_actor_deadline = float(timing.actor_origin) + float(timing.duration)
   _ultimate_exit_pose.clear(); _ultimate_exit_actor = -1.0
  var selected_alias: String=str(Ultimate_ALIASES[timing.ability_id])
  var overlay: Array[Transform3D] = _sample(selected_alias, elapsed)
  # Preserve the live lower solver's chest compensation: add the authored
  # chest rotation relative to its carry endpoint over the current chest.
  var zero: Array[Transform3D] = _sample(selected_alias, _ultimate_entry_sample)
  var carry: Array[Transform3D] = _sample(selected_alias, 0.0)
  var inherited_chest: Quaternion = inherited[chest_index].basis.get_rotation_quaternion()
  var carry_chest: Quaternion = carry[chest_index].basis.get_rotation_quaternion()
  for pose: Array[Transform3D] in [overlay, zero]:
   var authored: Quaternion = pose[chest_index].basis.get_rotation_quaternion()
   pose[chest_index].basis = Basis((inherited_chest * carry_chest.inverse() * authored).normalized()).scaled(inherited[chest_index].basis.get_scale())
  var entry: Array[Transform3D] = _rebase_upper(_ultimate_entry_pose, _ultimate_entry_basis, inherited)
  var residual: float = 1.0 - smoothstep(0.0, Ultimate_ENTRY_SECONDS, maxf(0.0, actor_now - _ultimate_entry_actor))
  for index in range(overlay.size()):
   if str(skeleton.get_bone_name(index)) not in UPPER: continue
   var mismatch: Quaternion = (entry[index].basis.get_rotation_quaternion() * zero[index].basis.get_rotation_quaternion().inverse()).normalized()
   var motion: Quaternion = overlay[index].basis.get_rotation_quaternion()
   overlay[index].basis = Basis((Quaternion.IDENTITY.slerp(mismatch, residual) * motion).normalized())
  weight = 1.0 - smoothstep(0.9 * float(timing.duration), float(timing.duration), elapsed)
  result = _upper_rotations_into(inherited, overlay, weight)
 elif _ultimate_had_visible:
  _ultimate_token.clear(); _ultimate_entry_pose.clear(); _ultimate_entry_actor = -1.0
  # A new committed Q/basic already receives the actual previous pose through
  # the inherited source-aged compositor. It owns the whole upper immediately.
  # For cancel/Shift only, fade a captured pose, never keep sampling old R clip.
  if upper.is_empty() and previous.size() == inherited.size() and is_finite(actor_now) and actor_now >= 0.0 and actor_now < _ultimate_actor_deadline:
   _ultimate_exit_pose = previous.duplicate(); _ultimate_exit_basis = previous_basis; _ultimate_exit_actor = actor_now
 if not visible and not _ultimate_exit_pose.is_empty():
  if not upper.is_empty() or actor_now < _ultimate_exit_actor or not is_finite(actor_now):
   _ultimate_exit_pose.clear(); _ultimate_exit_actor = -1.0
  else:
   var remaining: float = 1.0 - smoothstep(0.0, Ultimate_EXIT_SECONDS, actor_now - _ultimate_exit_actor)
   if remaining > 0.0:
    result = _upper_rotations_into(inherited, _rebase_upper(_ultimate_exit_pose, _ultimate_exit_basis, inherited), remaining)
   else:
    _ultimate_exit_pose.clear(); _ultimate_exit_actor = -1.0
 # _sample changes the skeleton while reading animation. Always restore every
 # inherited field, including lower bones, after sampling rotation-only R.
 for index in range(result.size()): skeleton.set_bone_pose(index, result[index])
 last_rendered_pose = result.duplicate()
 last_skeleton_basis = skeleton.global_basis
 last_skeleton_transform = skeleton.global_transform
 _ultimate_had_visible = visible
 ultimate_report = {"ability_id":timing.get("ability_id",""), "clip":timing.get("clip",""), "active_token":bool(timing.active), "visible":visible, "priority_owner":priority,
  "elapsed":elapsed, "actor_time":actor_now, "actor_origin":timing.get("actor_origin", -1.0),
  "authority_elapsed":timing.get("authority_elapsed", -1.0), "token":timing.get("token", {}),
  "weight":weight, "captured_exit_active":not _ultimate_exit_pose.is_empty(), "clock_reason":timing.reason,
  "source_time_unchanged":ink.get("source_time", 0.0), "lower_fields_exact":_ultimate_lower_equal(inherited, result),
  "source_mechanics_written":false, "clean_underlying_history":true, "inherited_handoff_from_actual":actual_handoff, "art_accepted":false}
 sample_report["ultimate_presentation"] = ultimate_report.duplicate(true)
 sample_report["sampled_bones"] = bone_sample_evidence()

func _ultimate_lower_equal(a: Array[Transform3D], b: Array[Transform3D]) -> bool:
 for index in range(a.size()):
  if str(skeleton.get_bone_name(index)) not in UPPER and a[index] != b[index]: return false
  if a[index].origin != b[index].origin: return false
 return true
