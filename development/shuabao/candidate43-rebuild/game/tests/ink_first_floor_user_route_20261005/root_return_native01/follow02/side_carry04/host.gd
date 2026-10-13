extends "res://tests/ink_first_floor_user_route_20261005/root_return_native01/follow02/host.gd"
## Actor-only opt-in leaf. Original source/input/compact F8/pause/F10 inherit.
const SideActor=preload("res://tests/ink_q1_flow_20261005/gesture06/root_return_rebuilt01/recovery_follow02/side_carry04/runtime/hero_view.gd")
const SideReporter=preload("res://tests/ink_q1_flow_20261005/gesture06/root_return_rebuilt01/recovery_follow02/side_carry04/runtime/carry_report.gd")
const SIDE_ROOT:="res://tests/ink_first_floor_user_route_20261005/root_return_native01/follow02/side_carry04/"
const SIDE_ACTOR_PATH:="res://tests/ink_q1_flow_20261005/gesture06/root_return_rebuilt01/recovery_follow02/side_carry04/runtime/hero_view.gd"
const SIDE_REPORT_PATH:="res://tests/ink_q1_flow_20261005/gesture06/root_return_rebuilt01/recovery_follow02/side_carry04/runtime/carry_report.gd"
# Exactly two actor identities and three copies of the old active-clip check.
# No suffix/prefix blanket exemption: every other inherited error fails closed.
const SIDE_EXCEPTIONS:=["actor_script_mismatch","actor_script_sha_mismatch","intent_consumer_accepted_required","ancestor_guard:intent_consumer_accepted_required","ancestor_guard:ancestor_guard:intent_consumer_accepted_required"]
var side_installed: bool=false
var side_contract: Dictionary={}
var side_installation: Dictionary={"accepted":false,"reason":"not_attempted"}
static func side_allowed_error(error: String) -> bool:return error in SIDE_EXCEPTIONS
static func side_identity_errors(value: Dictionary,expected: Dictionary) -> Array[String]:
 var errors: Array[String]=gesture_identity_errors(value,expected)
 # The evidence remains false for old intent aliases. A separately pinned,
 # actually selected carry consumer must be true in the new expected identity.
 errors.erase("intent_consumer_accepted_required")
 for required: String in ["carry_ready","carry_report_exact","carry_consumer_accepted"]:
  if value.get(required,false)!=true:errors.append(required+"_required")
 return errors
func _actor_is_composed() -> bool:
 if not side_installed:return super._actor_is_composed()
 return is_instance_valid(hero_view) and hero_view.get_script()==SideActor
func _side_binding_errors() -> Array[String]:
 var errors: Array[String]=[]
 if side_contract.get("schema","")!="q1-side-carry04-native-leaf-1":errors.append("side_contract_schema");return errors
 var files: Dictionary=side_contract.get("files",{})
 if files.is_empty():errors.append("side_pins_missing")
 for path: String in files:
  if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=str(files[path]):errors.append("side_pin:"+path)
 if side_contract.get("ancestor_identity_error_allowlist",[])!=SIDE_EXCEPTIONS:errors.append("side_allowlist_changed")
 return errors
func _start_encounter() -> void:
 var fresh: bool=shop_session==null
 super._start_encounter()
 if not fresh or sim==null or not startup_session_error.is_empty() or not floor_error.is_empty():return
 if not follow_installed or not follow_installation.get("accepted",false):_side_fail("follow02_ancestor_seal_required");return
 var ancestor: Dictionary=super._composed_warmup_identity()
 if not ancestor.get("accepted",false):_side_fail("follow02_ancestor_identity_required");return
 var loaded: Variant=JSON.parse_string(FileAccess.get_file_as_string(SIDE_ROOT+"source_binding.json"))
 if not loaded is Dictionary:_side_fail("side_contract_missing");return
 side_contract=loaded
 var errors: Array[String]=_side_binding_errors()
 if not errors.is_empty():side_installation["errors"]=errors;_side_fail("side_binding_HOLD");return
 if sim.hero_time!=0.0 or sim.phase!="preparation" or sim.wave!=0 or not sim.enemies.is_empty():_side_fail("fresh_preparation_required");return
 var before: PackedByteArray=_gesture_gameplay_seal()
 var director: int=sim.enemy_director.get_instance_id()
 var removed: int=hero_view.get_instance_id()
 remove_child(hero_view);hero_view.free()
 hero_view=SideActor.new();add_child(hero_view);side_installed=true
 _refresh(0.0)
 var equal: bool=before==_gesture_gameplay_seal()
 var identity: Dictionary=_composed_warmup_identity()
 side_installation={"accepted":equal and identity.accepted,"source_ledger_session_rng_and_director_equal":equal,"director_instance_unchanged":director==sim.enemy_director.get_instance_id(),"prior_actor_freed":not is_instance_id_valid(removed),"follow02_ancestor_identity_accepted":ancestor.accepted,"identity_errors":identity.errors,"new_actor_script":hero_view.get_script().resource_path,"art_accepted":false,"native_input_passed":false}
 if not side_installation.accepted:_side_fail("side_install_seal_HOLD")
func _side_fail(reason: String) -> void:
 side_installation["accepted"]=false;side_installation["reason"]=reason
 floor_error=reason;_pause(true,"side_carry04_fail_closed")
func _composed_warmup_identity() -> Dictionary:
 if not side_installed:return super._composed_warmup_identity()
 var inherited: Dictionary=super._composed_warmup_identity()
 var value: Dictionary=inherited.get("evidence",{}).duplicate(true)
 value["actor_script"]=hero_view.get_script().resource_path
 value["actor_script_sha"]=FileAccess.get_sha256(value.actor_script)
 value["actor_exact_script"]=_actor_is_composed()
 value["carry_asset"]=hero_view.CARRY_ASSET
 value["carry_asset_sha"]=FileAccess.get_sha256(hero_view.CARRY_ASSET)
 value["carry_binding_sha"]=FileAccess.get_sha256(hero_view.CARRY_BINDING)
 value["carry_boundaries_sha"]=FileAccess.get_sha256(hero_view.CARRY_ROOT+"source_boundaries.json")
 value["carry_ready"]=hero_view.carry_ready
 var reporter_script: Script=SideReporter
 value["carry_report_script"]=reporter_script.resource_path
 value["carry_report_sha"]=FileAccess.get_sha256(SIDE_REPORT_PATH)
 value["carry_report_exact"]=reporter_script.resource_path==SIDE_REPORT_PATH and hero_view.CarryReport==reporter_script
 var consumer: Dictionary=SideReporter.capture(hero_view)
 value["carry_consumer_accepted"]=consumer.get("accepted",false)
 value["current_Q1_consumer"]="side_carry04"
 var errors: Array[String]=side_identity_errors(value,side_contract.get("expected_identity",{}))
 var permitted: Array[String]=[]
 for error: String in inherited.get("errors",[]):
  if side_allowed_error(error):permitted.append(error)
  else:errors.append("ancestor_guard:"+error)
 errors.append_array(_side_binding_errors())
 return {"accepted":errors.is_empty(),"errors":errors,"evidence":value,"source_written":false,"drawn_warmup_accepted":false,"permitted_ancestor_identity_differences":permitted,"explicit_identity_allowlist":SIDE_EXCEPTIONS,"intent_consumer_readback":inherited.get("intent_consumer_readback",{}),"intent_consumption_scope":"retained ancestor asset/report; its old aliases are not current consumers","carry_consumer_readback":consumer,"current_consumption_scope":"exact side_carry04 asset/private aliases; original RootReturn and RecoveryFollow remain exact"}
func _mainprep_environment() -> Dictionary:
 var value: Dictionary=super._mainprep_environment()
 if side_installed:
  value["side_carry_actor_sha"]=FileAccess.get_sha256(SIDE_ACTOR_PATH)
  value["side_carry_binding_sha"]=FileAccess.get_sha256(hero_view.CARRY_BINDING)
  value["side_carry_asset_sha"]=FileAccess.get_sha256(hero_view.CARRY_ASSET)
  value["side_carry_report_sha"]=FileAccess.get_sha256(SIDE_REPORT_PATH)
  var ids: Dictionary={}
  for alias: String in hero_view.CARRY_ALIASES:ids[alias]=hero_view.player.get_animation(hero_view.clip_names[alias]).get_instance_id()
  value["side_carry_private_clip_ids"]=ids
 return value
func _prepare_main_viewport() -> void:
 if not side_installed or not side_installation.get("accepted",false):_mainprep_fail_startup("side_carry04_identity_not_admitted");return
 super._prepare_main_viewport()
func gesture_host_report() -> Dictionary:
 var report: Dictionary=super.gesture_host_report()
 if side_installed:
  report["intent_consumption_scope"]="ancestor_dependency_only; actual old intent consumer remains false"
  report["current_Q1_consumer"]="side_carry04"
  report["carry_consumer"]=SideReporter.capture(hero_view)
 return report
func diagnostic_logical_output(contents: Dictionary) -> Dictionary:
 var value: Dictionary=super.diagnostic_logical_output(contents)
 value["side_carry04_native"]={"installed":side_installed,"installation":side_installation,"binding_sha256":FileAccess.get_sha256(SIDE_ROOT+"source_binding.json"),"consumer":SideReporter.capture(hero_view) if side_installed else {},"source_input_F8_pause_F10_inherited":true,"native_input_passed":false,"art_accepted":false}
 return value
