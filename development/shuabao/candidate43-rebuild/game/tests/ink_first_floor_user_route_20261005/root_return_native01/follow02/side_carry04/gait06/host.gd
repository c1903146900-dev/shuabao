extends "res://tests/ink_first_floor_user_route_20261005/root_return_native01/follow02/side_carry04/host.gd"
## Thin gait leaf. Q1 remains side_carry04; original ordinary input/F8/F10 inherit.
const GaitActor=preload("res://tests/ink_q1_flow_20261005/gesture06/root_return_rebuilt01/recovery_follow02/gait06/runtime/hero_view.gd")
const GaitReporter=preload("res://tests/ink_q1_flow_20261005/gesture06/root_return_rebuilt01/recovery_follow02/gait06/runtime/gait_report.gd")
const GaitPhase=preload("res://tests/ink_q1_flow_20261005/gesture06/root_return_rebuilt01/recovery_follow02/gait06/runtime/phase.gd")
const GaitLower=preload("res://tests/ink_q1_flow_20261005/gesture06/root_return_rebuilt01/recovery_follow02/gait06/runtime/walking_lower.gd")
const GAIT_NATIVE_ROOT:="res://tests/ink_first_floor_user_route_20261005/root_return_native01/follow02/side_carry04/gait06/"
const GAIT_RUNTIME_ROOT:="res://tests/ink_q1_flow_20261005/gesture06/root_return_rebuilt01/recovery_follow02/gait06/runtime/"
const GAIT_EXCEPTIONS:=["actor_script_mismatch","actor_script_sha_mismatch"]
var gait_installed: bool=false
var gait_contract: Dictionary={}
var gait_installation: Dictionary={"accepted":false,"reason":"not_attempted"}
static func gait_allowed_error(error: String) -> bool:return error in GAIT_EXCEPTIONS
static func gait_identity_errors(value: Dictionary,expected: Dictionary) -> Array[String]:
 var errors: Array[String]=side_identity_errors(value,expected)
 for field: String in ["gait_ready","gait_report_exact","gait_consumer_accepted","gait_phase_exact","gait_lower_script_exact","gait_lower_instance_exact"]:
  if value.get(field,false)!=true:errors.append(field+"_required")
 return errors
func _actor_is_composed() -> bool:
 if not gait_installed:return super._actor_is_composed()
 return is_instance_valid(hero_view) and hero_view.get_script()==GaitActor
func _gait_binding_errors() -> Array[String]:
 var errors: Array[String]=[]
 if gait_contract.get("schema","")!="gait06-native-leaf-1":errors.append("gait_contract_schema");return errors
 var files: Dictionary=gait_contract.get("files",{})
 if files.is_empty():errors.append("gait_pins_missing")
 for path: String in files:
  if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=str(files[path]):errors.append("gait_pin:"+path)
 if gait_contract.get("ancestor_identity_error_allowlist",[])!=GAIT_EXCEPTIONS:errors.append("gait_allowlist_changed")
 return errors
func _start_encounter() -> void:
 var fresh: bool=shop_session==null
 super._start_encounter()
 if not fresh or sim==null or not startup_session_error.is_empty() or not floor_error.is_empty():return
 if not side_installed or not side_installation.get("accepted",false):_gait_fail("side_carry_ancestor_seal_required");return
 var ancestor: Dictionary=super._composed_warmup_identity()
 if not ancestor.get("accepted",false):_gait_fail("side_carry_ancestor_identity_required");return
 var loaded: Variant=JSON.parse_string(FileAccess.get_file_as_string(GAIT_NATIVE_ROOT+"source_binding.json"))
 if not loaded is Dictionary:_gait_fail("gait_contract_missing");return
 gait_contract=loaded
 var errors: Array[String]=_gait_binding_errors()
 if not errors.is_empty():gait_installation["errors"]=errors;_gait_fail("gait_binding_HOLD");return
 if sim.hero_time!=0.0 or sim.phase!="preparation" or sim.wave!=0 or not sim.enemies.is_empty():_gait_fail("fresh_preparation_required");return
 var before: PackedByteArray=_gesture_gameplay_seal()
 var director: int=sim.enemy_director.get_instance_id()
 var removed: int=hero_view.get_instance_id()
 remove_child(hero_view);hero_view.free()
 hero_view=GaitActor.new();add_child(hero_view);gait_installed=true
 _refresh(0.0)
 var equal: bool=before==_gesture_gameplay_seal()
 var identity: Dictionary=_composed_warmup_identity()
 gait_installation={"accepted":equal and identity.accepted,"source_ledger_session_rng_and_director_equal":equal,"director_instance_unchanged":director==sim.enemy_director.get_instance_id(),"prior_actor_freed":not is_instance_id_valid(removed),"side_carry_ancestor_identity_accepted":ancestor.accepted,"identity_errors":identity.errors,"new_actor_script":hero_view.get_script().resource_path,"art_accepted":false,"native_input_passed":false}
 if not gait_installation.accepted:_gait_fail("gait_install_seal_HOLD")
func _gait_fail(reason: String) -> void:
 gait_installation["accepted"]=false;gait_installation["reason"]=reason
 floor_error=reason;_pause(true,"gait06_fail_closed")
func _composed_warmup_identity() -> Dictionary:
 if not gait_installed:return super._composed_warmup_identity()
 var inherited: Dictionary=super._composed_warmup_identity()
 var value: Dictionary=inherited.get("evidence",{}).duplicate(true)
 value["actor_script"]=hero_view.get_script().resource_path
 value["actor_script_sha"]=FileAccess.get_sha256(value.actor_script)
 value["actor_exact_script"]=_actor_is_composed()
 value["gait_asset"]=hero_view.GAIT_ASSET
 value["gait_asset_sha"]=FileAccess.get_sha256(hero_view.GAIT_ASSET)
 value["gait_binding_sha"]=FileAccess.get_sha256(hero_view.GAIT_BINDING)
 value["gait_boundaries_sha"]=FileAccess.get_sha256(GAIT_RUNTIME_ROOT+"source_boundaries.json")
 value["gait_ready"]=hero_view.gait_ready
 var reporter_script: Script=GaitReporter
 var phase_script: Script=GaitPhase
 var lower_script: Script=GaitLower
 value["gait_report_script"]=reporter_script.resource_path
 value["gait_report_sha"]=FileAccess.get_sha256(reporter_script.resource_path)
 value["gait_report_exact"]=reporter_script.resource_path==GAIT_RUNTIME_ROOT+"gait_report.gd" and hero_view.GaitReport==reporter_script
 value["gait_phase_script"]=phase_script.resource_path
 value["gait_phase_sha"]=FileAccess.get_sha256(phase_script.resource_path)
 value["gait_phase_exact"]=phase_script.resource_path==GAIT_RUNTIME_ROOT+"phase.gd" and hero_view.GaitPhase==phase_script
 value["gait_lower_script"]=lower_script.resource_path
 value["gait_lower_sha"]=FileAccess.get_sha256(lower_script.resource_path)
 value["gait_lower_script_exact"]=lower_script.resource_path==GAIT_RUNTIME_ROOT+"walking_lower.gd" and hero_view.GaitLower==lower_script
 value["gait_lower_instance_exact"]=is_instance_valid(hero_view.lower_motion) and hero_view.lower_motion.get_script()==lower_script
 var consumer: Dictionary=GaitReporter.capture(hero_view)
 value["gait_consumer_accepted"]=consumer.get("accepted",false)
 value["gait_cycle_seconds"]=GaitPhase.CYCLE
 value["gait_contact_seconds"]=GaitPhase.CONTACT
 value["gait_base_cycle_seconds"]=GaitPhase.OLD_CYCLE
 value["current_locomotion_consumer"]="gait06"
 var errors: Array[String]=gait_identity_errors(value,gait_contract.get("expected_identity",{}))
 var permitted: Array[String]=[]
 for error: String in inherited.get("errors",[]):
  if gait_allowed_error(error):permitted.append(error)
  else:errors.append("ancestor_guard:"+error)
 errors.append_array(_gait_binding_errors())
 return {"accepted":errors.is_empty(),"errors":errors,"evidence":value,"source_written":false,"drawn_warmup_accepted":false,"permitted_ancestor_identity_differences":permitted,"explicit_identity_allowlist":GAIT_EXCEPTIONS,"intent_consumer_readback":inherited.get("intent_consumer_readback",{}),"carry_consumer_readback":inherited.get("carry_consumer_readback",{}),"gait_consumer_readback":consumer,"current_consumption_scope":"Q1 side_carry04 unchanged; four gait06 seven-field clips and exact contact helper; original RootReturn/RecoveryFollow"}
func _mainprep_environment() -> Dictionary:
 var value: Dictionary=super._mainprep_environment()
 if gait_installed:
  value["gait06_actor_sha"]=FileAccess.get_sha256(GAIT_RUNTIME_ROOT+"hero_view.gd")
  value["gait06_asset_sha"]=FileAccess.get_sha256(hero_view.GAIT_ASSET)
  value["gait06_binding_sha"]=FileAccess.get_sha256(hero_view.GAIT_BINDING)
  value["gait06_report_sha"]=FileAccess.get_sha256(GAIT_RUNTIME_ROOT+"gait_report.gd")
  value["gait06_phase_sha"]=FileAccess.get_sha256(GAIT_RUNTIME_ROOT+"phase.gd")
  value["gait06_lower_sha"]=FileAccess.get_sha256(GAIT_RUNTIME_ROOT+"walking_lower.gd")
  value["gait06_lower_instance_id"]=hero_view.lower_motion.get_instance_id()
  var ids: Dictionary={}
  for alias: String in hero_view.GAIT_CLIPS.values():ids[alias]=hero_view.player.get_animation(hero_view.clip_names[alias]).get_instance_id()
  value["gait06_private_clip_ids"]=ids
 return value
func _prepare_main_viewport() -> void:
 if not gait_installed or not gait_installation.get("accepted",false):_mainprep_fail_startup("gait06_identity_not_admitted");return
 super._prepare_main_viewport()
func gesture_host_report() -> Dictionary:
 var report: Dictionary=super.gesture_host_report()
 if gait_installed:
  report["current_locomotion_consumer"]="gait06"
  report["gait_consumer"]=GaitReporter.capture(hero_view)
 return report
func diagnostic_logical_output(contents: Dictionary) -> Dictionary:
 var value: Dictionary=super.diagnostic_logical_output(contents)
 value["gait06_native"]={"installed":gait_installed,"installation":gait_installation,"binding_sha256":FileAccess.get_sha256(GAIT_NATIVE_ROOT+"source_binding.json"),"consumer":GaitReporter.capture(hero_view) if gait_installed else {},"current_Q1_consumer":"side_carry04","source_input_F8_pause_F10_inherited":true,"native_input_passed":false,"art_accepted":false}
 return value
