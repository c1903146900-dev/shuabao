extends "res://tests/ink_first_floor_user_route_20261005/diagnostic_compact01_fix01/host.gd"
## Explicit presentation leaf. Original input, F8 compact storage and F10 inherit.
const ReturnActor=preload("res://tests/ink_q1_flow_20261005/gesture06/root_return_rebuilt01/hero_view.gd")
const ReturnHelper=preload("res://tests/ink_q1_flow_20261005/gesture06/root_return_rebuilt01/root_return.gd")
const RETURN_ROOT:="res://tests/ink_first_floor_user_route_20261005/root_return_native01/"
const RETURN_ACTOR_PATH:="res://tests/ink_q1_flow_20261005/gesture06/root_return_rebuilt01/hero_view.gd"
const RETURN_HELPER_PATH:="res://tests/ink_q1_flow_20261005/gesture06/root_return_rebuilt01/root_return.gd"
const ANCESTOR_IDENTITY_ALLOWLIST:=["actor_script_mismatch","actor_script_sha_mismatch"]
var root_return_installed: bool=false
var root_return_contract: Dictionary={}
var root_return_installation: Dictionary={"accepted":false,"reason":"not_attempted"}

static func allowed_ancestor_identity_error(error: String) -> bool:
 return error in ANCESTOR_IDENTITY_ALLOWLIST

func _actor_is_composed() -> bool:
 if not root_return_installed:return super._actor_is_composed()
 return is_instance_valid(hero_view) and hero_view.get_script()==ReturnActor

func _return_binding_errors() -> Array[String]:
 var errors: Array[String]=[]
 if root_return_contract.get("schema","")!="q1-root-return-native-leaf-1":errors.append("root_return_contract_schema");return errors
 var files: Dictionary=root_return_contract.get("files",{})
 if files.is_empty():errors.append("root_return_file_pins_missing")
 for path: String in files:
  if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=str(files[path]):errors.append("root_return_pin:"+path)
 if root_return_contract.get("ancestor_identity_error_allowlist",[])!=ANCESTOR_IDENTITY_ALLOWLIST:errors.append("root_return_allowlist_changed")
 return errors

func _start_encounter() -> void:
 var fresh: bool=shop_session==null
 super._start_encounter()
 if not fresh or sim==null or not startup_session_error.is_empty() or not floor_error.is_empty():return
 if not gesture_installed or not gesture_installation.get("accepted",false) or not flow_install_source_equal or not navigation_installation.get("accepted",false):
  _return_fail("original_gesture_flow_navigation_seals_required");return
 var ancestor: Dictionary=super._composed_warmup_identity()
 if not ancestor.get("accepted",false):_return_fail("ancestor_identity_not_admitted");return
 var loaded: Variant=JSON.parse_string(FileAccess.get_file_as_string(RETURN_ROOT+"source_binding.json"))
 if not loaded is Dictionary:_return_fail("root_return_contract_missing");return
 root_return_contract=loaded
 var binding_errors: Array[String]=_return_binding_errors()
 if not binding_errors.is_empty():root_return_installation["errors"]=binding_errors;_return_fail("root_return_binding_HOLD");return
 if sim.hero_time!=0.0 or sim.phase!="preparation" or sim.wave!=0 or not sim.enemies.is_empty():
  _return_fail("fresh_preparation_before_input_required");return
 var before: PackedByteArray=_gesture_gameplay_seal()
 var director_id: int=sim.enemy_director.get_instance_id()
 var removed_id: int=hero_view.get_instance_id()
 remove_child(hero_view);hero_view.free()
 hero_view=ReturnActor.new();add_child(hero_view)
 root_return_installed=true
 _refresh(0.0)
 var equal: bool=before==_gesture_gameplay_seal()
 var identity: Dictionary=_composed_warmup_identity()
 root_return_installation={"accepted":equal and identity.accepted,"source_ledger_session_rng_and_director_equal":equal,"director_instance_unchanged":director_id==sim.enemy_director.get_instance_id(),"prior_actor_freed":not is_instance_id_valid(removed_id),"new_actor_script":hero_view.get_script().resource_path,"original_ancestor_identity_accepted":ancestor.accepted,"identity_errors":identity.errors,"presentation_only":true,"native_input":false,"art_accepted":false}
 if not root_return_installation.accepted:_return_fail("root_return_install_seal_HOLD")

func _return_fail(reason: String) -> void:
 root_return_installation["accepted"]=false;root_return_installation["reason"]=reason
 floor_error=reason;_pause(true,"root_return_fail_closed")

func _composed_warmup_identity() -> Dictionary:
 if not root_return_installed:return super._composed_warmup_identity()
 var inherited: Dictionary=super._composed_warmup_identity()
 var value: Dictionary=inherited.get("evidence",{}).duplicate(true)
 # The parent records the legacy actor SHA as a constant. Read the actual new
 # actor path/SHA instead; never claim the new object is the old GestureActor.
 value["actor_script"]=hero_view.get_script().resource_path
 value["actor_script_sha"]=FileAccess.get_sha256(value.actor_script)
 value["actor_exact_script"]=_actor_is_composed()
 value["root_return_helper_path"]=RETURN_HELPER_PATH
 value["root_return_helper_sha"]=FileAccess.get_sha256(RETURN_HELPER_PATH)
 var helper_script: Script=ReturnHelper
 value["root_return_helper_exact"]=hero_view.RootReturn==helper_script and helper_script.resource_path==RETURN_HELPER_PATH
 var errors: Array[String]=gesture_identity_errors(value,root_return_contract.get("expected_identity",{}))
 var permitted: Array[String]=[]
 for error: String in inherited.get("errors",[]):
  if allowed_ancestor_identity_error(error):permitted.append(error)
  else:errors.append("ancestor_guard:"+error)
 errors.append_array(_return_binding_errors())
 return {"accepted":errors.is_empty(),"errors":errors,"evidence":value,"source_written":false,"drawn_warmup_accepted":false,"permitted_ancestor_identity_differences":permitted,"explicit_identity_allowlist":ANCESTOR_IDENTITY_ALLOWLIST,"intent_consumer_readback":inherited.get("intent_consumer_readback",{}),"intent_consumption_scope":"same gesture06 imported clips; separate exact root-return actor/helper identity; no art acceptance"}

func _mainprep_environment() -> Dictionary:
 var value: Dictionary=super._mainprep_environment()
 if root_return_installed:
  value["root_return_actor_id"]=hero_view.get_instance_id()
  value["root_return_actor_sha"]=FileAccess.get_sha256(RETURN_ACTOR_PATH)
  value["root_return_helper_sha"]=FileAccess.get_sha256(RETURN_HELPER_PATH)
 return value

func _prepare_main_viewport() -> void:
 if not root_return_installed or not root_return_installation.get("accepted",false):
  _mainprep_fail_startup("root_return_native_identity_not_admitted");return
 super._prepare_main_viewport()

func diagnostic_logical_output(contents: Dictionary) -> Dictionary:
 var output: Dictionary=super.diagnostic_logical_output(contents)
 output["root_return_native"]={"installed":root_return_installed,"installation":root_return_installation,"actor_script":hero_view.get_script().resource_path if is_instance_valid(hero_view) else "","binding_sha256":FileAccess.get_sha256(RETURN_ROOT+"source_binding.json"),"presentation":hero_view.sample_report.get("q1_root_return",{}) if root_return_installed else {},"effect05_retained":true,"handoff_instantiated":false,"F8_compact_and_input_and_F10_inherited":true,"historical_0756_replay":false,"native_input_passed":false,"art_accepted":false}
 return output
