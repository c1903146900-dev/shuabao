extends "res://tests/ink_first_floor_user_route_20261005/root_return_native01/follow02/side_carry04/gait06/host.gd"
## One release-consumer leaf. Original source, gait, input, compact F8 and F10 inherit.
const ReleaseActor=preload("res://tests/ink_q1_flow_20261005/gesture06/root_return_rebuilt01/recovery_follow02/recovery08/runtime_fix01/hero_view.gd")
const ReleaseReporter=preload("res://tests/ink_q1_flow_20261005/gesture06/root_return_rebuilt01/recovery_follow02/recovery08/runtime_fix01/recovery_report.gd")
const RELEASE_NATIVE_ROOT:="res://tests/ink_first_floor_user_route_20261005/root_return_native01/follow02/side_carry04/gait06/recovery08_fix01/"
const RELEASE_RUNTIME_ROOT:="res://tests/ink_q1_flow_20261005/gesture06/root_return_rebuilt01/recovery_follow02/recovery08/runtime_fix01/"
const RELEASE_EXCEPTIONS:=["actor_script_mismatch","actor_script_sha_mismatch"]
const SUPERSEDED_RELEASE_DIAGNOSTICS:=["carry_consumer_accepted_mismatch","carry_consumer_accepted_required","ancestor_guard:carry_consumer_accepted_mismatch","ancestor_guard:carry_consumer_accepted_required"]
var release_installed: bool=false
var release_contract: Dictionary={}
var release_installation: Dictionary={"accepted":false,"reason":"not_attempted"}
static func release_allowed_error(error: String) -> bool:return error in RELEASE_EXCEPTIONS
static func release_replacement_complete(value: Dictionary) -> bool:
 return value.get("carry_consumer_accepted",null)==false and value.get("retained_carry_accepted",false)==true and value.get("release_ready",false)==true and value.get("release_report_exact",false)==true and value.get("release_consumer_accepted",false)==true
static func release_identity_errors(value: Dictionary,expected: Dictionary) -> Array[String]:
 var errors: Array[String]=gait_identity_errors(value,expected)
 # Preserve actual old four-alias false. Only its requirement is replaced by
 # three individually checked retained aliases plus the exact new release.
 if release_replacement_complete(value):errors.erase("carry_consumer_accepted_required")
 for key: String in ["retained_carry_accepted","release_ready","release_report_exact","release_consumer_accepted"]:
  if value.get(key,false)!=true:errors.append(key+"_required")
 return errors
func _actor_is_composed() -> bool:
 if not release_installed:return super._actor_is_composed()
 return is_instance_valid(hero_view) and hero_view.get_script()==ReleaseActor
func _release_binding_errors() -> Array[String]:
 var errors: Array[String]=[]
 if release_contract.get("schema","")!="recovery08-fix01-native-leaf-1":errors.append("release_contract_schema");return errors
 var files: Dictionary=release_contract.get("files",{})
 if files.is_empty():errors.append("release_pins_missing")
 for path: String in files:
  if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=str(files[path]):errors.append("release_pin:"+path)
 if release_contract.get("actor_identity_error_allowlist",[])!=RELEASE_EXCEPTIONS:errors.append("release_allowlist_changed")
 if release_contract.get("superseded_release_diagnostics",[])!=SUPERSEDED_RELEASE_DIAGNOSTICS:errors.append("release_replacement_scope_changed")
 return errors
func _start_encounter() -> void:
 var fresh: bool=shop_session==null
 super._start_encounter()
 if not fresh or sim==null or not startup_session_error.is_empty() or not floor_error.is_empty():return
 if not gait_installed or not gait_installation.get("accepted",false):_release_fail("gait06_ancestor_seal_required");return
 var ancestor: Dictionary=super._composed_warmup_identity()
 if not ancestor.get("accepted",false):_release_fail("gait06_ancestor_identity_required");return
 var loaded: Variant=JSON.parse_string(FileAccess.get_file_as_string(RELEASE_NATIVE_ROOT+"source_binding.json"))
 if not loaded is Dictionary:_release_fail("release_contract_missing");return
 release_contract=loaded
 var errors: Array[String]=_release_binding_errors()
 if not errors.is_empty():release_installation["errors"]=errors;_release_fail("release_binding_HOLD");return
 if sim.hero_time!=0.0 or sim.phase!="preparation" or sim.wave!=0 or not sim.enemies.is_empty():_release_fail("fresh_preparation_required");return
 var before: PackedByteArray=_gesture_gameplay_seal()
 var director: int=sim.enemy_director.get_instance_id()
 var removed: int=hero_view.get_instance_id()
 remove_child(hero_view);hero_view.free()
 hero_view=ReleaseActor.new();add_child(hero_view);release_installed=true
 _refresh(0.0)
 var equal: bool=before==_gesture_gameplay_seal()
 var identity: Dictionary=_composed_warmup_identity()
 release_installation={"accepted":equal and identity.accepted,"source_ledger_session_rng_and_director_equal":equal,"director_instance_unchanged":director==sim.enemy_director.get_instance_id(),"prior_actor_freed":not is_instance_id_valid(removed),"gait06_ancestor_identity_accepted":ancestor.accepted,"identity_errors":identity.errors,"new_actor_script":hero_view.get_script().resource_path,"art_accepted":false,"native_input_passed":false}
 if not release_installation.accepted:_release_fail("release_install_seal_HOLD")
func _release_fail(reason: String) -> void:
 release_installation["accepted"]=false;release_installation["reason"]=reason
 floor_error=reason;_pause(true,"recovery08_fix01_fail_closed")
func _composed_warmup_identity() -> Dictionary:
 if not release_installed:return super._composed_warmup_identity()
 var inherited: Dictionary=super._composed_warmup_identity()
 var value: Dictionary=inherited.get("evidence",{}).duplicate(true)
 value["actor_script"]=hero_view.get_script().resource_path
 value["actor_script_sha"]=FileAccess.get_sha256(value.actor_script)
 value["actor_exact_script"]=_actor_is_composed()
 value["release_asset"]=hero_view.RECOVERY_ASSET
 value["release_asset_sha"]=FileAccess.get_sha256(hero_view.RECOVERY_ASSET)
 value["release_binding_sha"]=FileAccess.get_sha256(hero_view.RECOVERY_BINDING)
 value["release_boundaries_sha"]=FileAccess.get_sha256(RELEASE_RUNTIME_ROOT+"source_boundaries.json")
 value["release_ready"]=hero_view.recovery_ready
 var reporter_script: Script=ReleaseReporter
 value["release_report_script"]=reporter_script.resource_path
 value["release_report_sha"]=FileAccess.get_sha256(reporter_script.resource_path)
 value["release_report_exact"]=reporter_script.resource_path==RELEASE_RUNTIME_ROOT+"recovery_report.gd" and hero_view.RecoveryReport==reporter_script
 var consumer: Dictionary=ReleaseReporter.capture(hero_view)
 value["release_consumer_accepted"]=consumer.get("accepted",false)
 value["release_actual_library_name"]=consumer.get("actual_release_library_name","")
 var carry: Dictionary=inherited.get("carry_consumer_readback",{})
 var retained: Dictionary={}
 var retained_ok: bool=carry.get("accepted",null)==false and carry.get("aliases",{}).get("q1_release_upper",{}).get("exact_carry_consumer",true)==false
 for alias: String in ["q1_draw_upper","q1_hold_upper","brush_carry_upper"]:
  var row: Dictionary=carry.get("aliases",{}).get(alias,{})
  var exact: bool=row.get("exact_carry_consumer",false)==true and row.get("actual_player_library_name","")=="q1_carry_rotation_only/"+str(hero_view.CARRY_ALIASES[alias])
  retained[alias]={"accepted":exact,"actual_evidence":row};retained_ok=retained_ok and exact
 value["retained_carry_accepted"]=retained_ok
 value["current_Q1_consumer"]="side_carry04_draw_hold_recovery08_fix01_release"
 var errors: Array[String]=release_identity_errors(value,release_contract.get("expected_identity",{}))
 var actor_differences: Array[String]=[]
 var superseded: Array[String]=[]
 for error: String in inherited.get("errors",[]):
  if release_allowed_error(error):actor_differences.append(error)
  elif error in SUPERSEDED_RELEASE_DIAGNOSTICS and release_replacement_complete(value):superseded.append(error)
  else:errors.append("ancestor_guard:"+error)
 var exact_superseded: Array=SUPERSEDED_RELEASE_DIAGNOSTICS.duplicate();exact_superseded.sort()
 var actual_superseded: Array=superseded.duplicate();actual_superseded.sort()
 if actual_superseded!=exact_superseded:errors.append("exact_four_replaced_consumer_diagnostics_required")
 errors.append_array(_release_binding_errors())
 return {"accepted":errors.is_empty(),"errors":errors,"evidence":value,"source_written":false,"drawn_warmup_accepted":false,"explicit_identity_allowlist":RELEASE_EXCEPTIONS,"permitted_actor_identity_differences":actor_differences,"superseded_release_diagnostics":superseded,"raw_ancestor_errors":inherited.get("errors",[]).duplicate(),"intent_consumer_readback":inherited.get("intent_consumer_readback",{}),"carry_consumer_readback":carry,"retained_carry_aliases":retained,"gait_consumer_readback":inherited.get("gait_consumer_readback",{}),"release_consumer_readback":consumer,"current_consumption_scope":"old carry four-alias aggregate remains false; exact draw/hold/carry retained plus new exact release; original gait06/source guards"}
func _mainprep_environment() -> Dictionary:
 var value: Dictionary=super._mainprep_environment()
 if release_installed:
  value["recovery08_actor_sha"]=FileAccess.get_sha256(RELEASE_RUNTIME_ROOT+"hero_view.gd")
  value["recovery08_asset_sha"]=FileAccess.get_sha256(hero_view.RECOVERY_ASSET)
  value["recovery08_binding_sha"]=FileAccess.get_sha256(hero_view.RECOVERY_BINDING)
  value["recovery08_report_sha"]=FileAccess.get_sha256(RELEASE_RUNTIME_ROOT+"recovery_report.gd")
  value["recovery08_release_clip_id"]=hero_view.player.get_animation(hero_view.clip_names.q1_release_upper).get_instance_id()
 return value
func _prepare_main_viewport() -> void:
 if not release_installed or not release_installation.get("accepted",false):_mainprep_fail_startup("recovery08_identity_not_admitted");return
 super._prepare_main_viewport()
func gesture_host_report() -> Dictionary:
 var report: Dictionary=super.gesture_host_report()
 if release_installed:
  report["current_Q1_consumer"]="side_carry04_draw_hold_recovery08_fix01_release"
  report["release_consumer"]=ReleaseReporter.capture(hero_view)
 return report
func diagnostic_logical_output(contents: Dictionary) -> Dictionary:
 var value: Dictionary=super.diagnostic_logical_output(contents)
 value["recovery08_fix01_native"]={"installed":release_installed,"installation":release_installation,"binding_sha256":FileAccess.get_sha256(RELEASE_NATIVE_ROOT+"source_binding.json"),"consumer":ReleaseReporter.capture(hero_view) if release_installed else {},"source_input_F8_pause_F10_inherited":true,"F8_sparse_sampling_does_not_exclude_fast_arm_pop":true,"native_input_passed":false,"art_accepted":false}
 return value
