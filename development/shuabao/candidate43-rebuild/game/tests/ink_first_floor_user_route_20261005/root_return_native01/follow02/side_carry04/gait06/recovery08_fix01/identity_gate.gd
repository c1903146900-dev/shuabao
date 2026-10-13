extends SceneTree
## One ordinary constructor and one refresh; no source step or historical matrix.
const Host=preload("res://tests/ink_first_floor_user_route_20261005/root_return_native01/follow02/side_carry04/gait06/recovery08_fix01/host.gd")
var errors: Array=[]
var checks: int=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:errors.append(label);push_error(label)
func run() -> void:
 var out: String=""
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--recovery-native-out="):out=arg.trim_prefix("--recovery-native-out=")
 if out.is_empty():push_error("explicit --recovery-native-out required");quit(2);return
 var host=Host.new();root.add_child(host)
 host.set_process(false);host.set_process_input(false);host.set_process_unhandled_input(false)
 check(host.startup_session_error.is_empty() and host.floor_error.is_empty(),"ordinary_constructor_clean")
 check(host.release_installed and host.release_installation.get("accepted",false),"new_actor_installation_sealed")
 var result: Dictionary={"scope":"recovery08_fix01 native identity only; no gameplay matrix or source steps","installation":host.release_installation,"native_input":false,"art_accepted":false}
 if errors.is_empty():
  var before: PackedByteArray=host._gesture_gameplay_seal()
  var actor_id: int=host.hero_view.get_instance_id()
  var identity: Dictionary=host._composed_warmup_identity()
  check(identity.accepted and identity.errors.is_empty(),"new_warmup_identity")
  check(host.hero_view.get_script()==Host.ReleaseActor and host.hero_view.recovery_ready and host.hero_view.gait_ready and host.hero_view.carry_ready,"actual_gait_actor_and_original_carry")
  check(identity.evidence.root_return_helper_exact and identity.evidence.recovery_follow_helper_exact and identity.evidence.recovery_follow_instance_exact,"original_helpers_exact")
  check(identity.release_consumer_readback.accepted and identity.release_consumer_readback.asset_sha256==host.release_contract.expected_identity.release_asset_sha and identity.evidence.retained_carry_accepted and identity.retained_carry_aliases.size()==3 and not identity.carry_consumer_readback.accepted,"new_release_plus_three_retained_aliases_old_aggregate_false")
  check(identity.gait_consumer_readback.accepted and identity.gait_consumer_readback.asset_sha256==host.gait_contract.expected_identity.gait_asset_sha and identity.gait_consumer_readback.clips.size()==4,"new_actual_four_gait_consumers")
  check(identity.evidence.gait_phase_exact and identity.evidence.gait_lower_script_exact and identity.evidence.gait_lower_instance_exact,"actual_gait_phase_and_lower_instance")
  check(identity.evidence.current_Q1_consumer=="side_carry04_draw_hold_recovery08_fix01_release" and identity.evidence.current_locomotion_consumer=="gait06","Q1_and_locomotion_consumers_distinct")
  check(not identity.evidence.intent_consumer_accepted and not identity.intent_consumer_readback.accepted and not identity.evidence.carry_consumer_accepted and identity.superseded_release_diagnostics.size()==4 and identity.superseded_release_diagnostics.all(func(e):return e in Host.SUPERSEDED_RELEASE_DIAGNOSTICS),"old_consumers_false_and_exact_replacement_diagnostics")
  check(host.gait_installation.accepted and host.side_installation.accepted and host.follow_installation.accepted and host.root_return_installation.accepted and host.navigation_installation.accepted,"prior_seals_retained")
  check(host.sim.hero_time==0.0 and host.sim.hero.ranks.q==0 and host.shop_session.ledger.model.state.points==1 and host.shop_session.ledger.model.state.gold==0 and host.shop_session.ledger.model.state.xp==0,"ordinary_unlearned_zero_source_resources")
  for key: String in ["release_consumer_accepted","retained_carry_accepted","flow_bound","recovery_follow_instance_exact","gait_consumer_accepted","gait_lower_instance_exact"]:
   var broken: Dictionary=identity.evidence.duplicate(true);broken[key]=false
   check(not Host.release_identity_errors(broken,host.release_contract.expected_identity).is_empty(),"required_guard:"+key)
  host._refresh(0.0)
  check(before==host._gesture_gameplay_seal(),"identity_refresh_source_seal")
  check(actor_id==host.hero_view.get_instance_id() and host._actor_is_composed(),"refresh_keeps_new_actor")
  result["identity"]=identity
 result["passed"]=errors.is_empty();result["checks"]=checks;result["errors"]=errors
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
 var f:=FileAccess.open(out.path_join("identity_gate.json"),FileAccess.WRITE)
 if f!=null:f.store_string(JSON.stringify(result,"  "));f.close()
 host.free()
 print("RECOVERY08_FIX01_NATIVE_IDENTITY ",JSON.stringify({"passed":result.passed,"checks":checks,"errors":errors}))
 quit(0 if errors.is_empty() else 3)
