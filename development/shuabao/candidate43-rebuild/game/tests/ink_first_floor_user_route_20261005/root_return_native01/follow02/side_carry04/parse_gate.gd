extends SceneTree
const Host=preload("res://tests/ink_first_floor_user_route_20261005/root_return_native01/follow02/side_carry04/host.gd")
func _initialize() -> void:
 var script: Script=Host
 if not script.can_instantiate():print("SIDE_CARRY04_NATIVE_PARSE ",JSON.stringify({"passed":false,"reason":"host_not_instantiable"}));quit(1);return
 var failures: Array=[]
 for error: String in Host.SIDE_EXCEPTIONS:
  if not Host.side_allowed_error(error):failures.append("missing_exact_exception:"+error)
 for error: String in ["flow_asset_sha_mismatch","actor_import_errors","root_return_helper_sha_mismatch","recovery_follow_instance_exact_mismatch","ancestor_guard:flow_bound_required","ancestor_guard:ancestor_guard:actor_import_errors","ancestor_guard:ancestor_guard:ancestor_guard:intent_consumer_accepted_required"]:
  if Host.side_allowed_error(error):failures.append("guard_weakened:"+error)
 print("SIDE_CARRY04_NATIVE_PARSE ",JSON.stringify({"passed":failures.is_empty(),"failures":failures,"host_constructed":false}))
 quit(0 if failures.is_empty() else 1)
