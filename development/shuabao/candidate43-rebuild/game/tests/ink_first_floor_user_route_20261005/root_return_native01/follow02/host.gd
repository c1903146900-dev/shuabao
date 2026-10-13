extends "res://tests/ink_first_floor_user_route_20261005/root_return_native01/host.gd"
## Thin follow02 actor leaf; inherited normal input, compact F8, F10 and all source.
const FollowActor=preload("res://tests/ink_q1_flow_20261005/gesture06/root_return_rebuilt01/recovery_follow02/hero_view.gd")
const FollowHelper=preload("res://tests/ink_q1_flow_20261005/gesture06/root_return_rebuilt01/recovery_follow02/recovery_follow.gd")
const FOLLOW_ROOT:="res://tests/ink_first_floor_user_route_20261005/root_return_native01/follow02/"
const FOLLOW_ACTOR_PATH:="res://tests/ink_q1_flow_20261005/gesture06/root_return_rebuilt01/recovery_follow02/hero_view.gd"
const FOLLOW_HELPER_PATH:="res://tests/ink_q1_flow_20261005/gesture06/root_return_rebuilt01/recovery_follow02/recovery_follow.gd"
const FOLLOW_ACTOR_EXCEPTIONS:=["actor_script_mismatch","actor_script_sha_mismatch"]
var follow_installed: bool=false
var follow_contract: Dictionary={}
var follow_installation: Dictionary={"accepted":false,"reason":"not_attempted"}

static func follow_allowed_ancestor_error(error: String) -> bool:return error in FOLLOW_ACTOR_EXCEPTIONS
func _actor_is_composed() -> bool:
 if not follow_installed:return super._actor_is_composed()
 return is_instance_valid(hero_view) and hero_view.get_script()==FollowActor
func _follow_binding_errors() -> Array[String]:
 var errors: Array[String]=[]
 if follow_contract.get("schema","")!="q1-follow02-native-leaf-1":errors.append("follow02_contract_schema");return errors
 var files: Dictionary=follow_contract.get("files",{})
 if files.is_empty():errors.append("follow02_pins_missing")
 for path: String in files:
  if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=str(files[path]):errors.append("follow02_pin:"+path)
 if follow_contract.get("ancestor_identity_error_allowlist",[])!=FOLLOW_ACTOR_EXCEPTIONS:errors.append("follow02_allowlist_changed")
 return errors
func _start_encounter() -> void:
 var fresh: bool=shop_session==null
 super._start_encounter()
 if not fresh or sim==null or not startup_session_error.is_empty() or not floor_error.is_empty():return
 if not root_return_installed or not root_return_installation.get("accepted",false):_follow_fail("root_return_native_seal_required");return
 var ancestor: Dictionary=super._composed_warmup_identity()
 if not ancestor.get("accepted",false):_follow_fail("root_return_native_identity_required");return
 var loaded: Variant=JSON.parse_string(FileAccess.get_file_as_string(FOLLOW_ROOT+"source_binding.json"))
 if not loaded is Dictionary:_follow_fail("follow02_contract_missing");return
 follow_contract=loaded
 var binding_errors: Array[String]=_follow_binding_errors()
 if not binding_errors.is_empty():follow_installation["errors"]=binding_errors;_follow_fail("follow02_binding_HOLD");return
 if sim.hero_time!=0.0 or sim.phase!="preparation" or sim.wave!=0 or not sim.enemies.is_empty():_follow_fail("fresh_preparation_required");return
 var before: PackedByteArray=_gesture_gameplay_seal()
 var director: int=sim.enemy_director.get_instance_id()
 var removed: int=hero_view.get_instance_id()
 remove_child(hero_view);hero_view.free()
 hero_view=FollowActor.new();add_child(hero_view);follow_installed=true
 _refresh(0.0)
 var equal: bool=before==_gesture_gameplay_seal()
 var identity: Dictionary=_composed_warmup_identity()
 follow_installation={"accepted":equal and identity.accepted,"source_ledger_session_rng_and_director_equal":equal,"director_instance_unchanged":director==sim.enemy_director.get_instance_id(),"prior_actor_freed":not is_instance_id_valid(removed),"original_native01_identity_accepted":ancestor.accepted,"identity_errors":identity.errors,"new_actor_script":hero_view.get_script().resource_path,"art_accepted":false,"native_input_passed":false}
 if not follow_installation.accepted:_follow_fail("follow02_install_seal_HOLD")
func _follow_fail(reason: String) -> void:
 follow_installation["accepted"]=false;follow_installation["reason"]=reason
 floor_error=reason;_pause(true,"follow02_fail_closed")
func _composed_warmup_identity() -> Dictionary:
 if not follow_installed:return super._composed_warmup_identity()
 var inherited: Dictionary=super._composed_warmup_identity()
 var value: Dictionary=inherited.get("evidence",{}).duplicate(true)
 value["actor_script"]=hero_view.get_script().resource_path
 value["actor_script_sha"]=FileAccess.get_sha256(value.actor_script)
 value["actor_exact_script"]=_actor_is_composed()
 var helper_script: Script=FollowHelper
 value["recovery_follow_helper_path"]=helper_script.resource_path
 value["recovery_follow_helper_sha"]=FileAccess.get_sha256(FOLLOW_HELPER_PATH)
 value["recovery_follow_helper_exact"]=hero_view.RecoveryFollow==helper_script and helper_script.resource_path==FOLLOW_HELPER_PATH
 value["recovery_follow_instance_exact"]=is_instance_valid(hero_view.recovery_follow_solver) and hero_view.recovery_follow_solver.get_script()==helper_script
 var errors: Array[String]=gesture_identity_errors(value,follow_contract.get("expected_identity",{}))
 var permitted: Array[String]=[]
 for error: String in inherited.get("errors",[]):
  if follow_allowed_ancestor_error(error):permitted.append(error)
  else:errors.append("ancestor_guard:"+error)
 errors.append_array(_follow_binding_errors())
 return {"accepted":errors.is_empty(),"errors":errors,"evidence":value,"source_written":false,"drawn_warmup_accepted":false,"permitted_ancestor_identity_differences":permitted,"explicit_identity_allowlist":FOLLOW_ACTOR_EXCEPTIONS,"intent_consumer_readback":inherited.get("intent_consumer_readback",{}),"intent_consumption_scope":"full gesture06 clip, original RootReturn helper plus exact RecoveryFollow helper and instance; no art acceptance"}
func _mainprep_environment() -> Dictionary:
 var value: Dictionary=super._mainprep_environment()
 if follow_installed:
  value["follow02_actor_sha"]=FileAccess.get_sha256(FOLLOW_ACTOR_PATH)
  value["follow02_helper_sha"]=FileAccess.get_sha256(FOLLOW_HELPER_PATH)
  value["follow02_solver_id"]=hero_view.recovery_follow_solver.get_instance_id()
 return value
func _prepare_main_viewport() -> void:
 if not follow_installed or not follow_installation.get("accepted",false):_mainprep_fail_startup("follow02_identity_not_admitted");return
 super._prepare_main_viewport()
func diagnostic_logical_output(contents: Dictionary) -> Dictionary:
 var output: Dictionary=super.diagnostic_logical_output(contents)
 output["recovery_follow02_native"]={"installed":follow_installed,"installation":follow_installation,"binding_sha256":FileAccess.get_sha256(FOLLOW_ROOT+"source_binding.json"),"presentation":hero_view.sample_report.get("q1_recovery_follow",{}) if follow_installed else {},"original_RootReturn_helper_retained":true,"F8_compact_input_F10_and_normal_entry_inherited":true,"native_input_passed":false,"art_accepted":false}
 return output
