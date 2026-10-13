extends SceneTree
const Host=preload("res://tests/ink_first_floor_user_route_20261005/root_return_native01/follow02/host.gd")
func _initialize() -> void:
 var host_script: Script=Host
 if not host_script.can_instantiate():
  print("FOLLOW02_NATIVE_PARSE ",JSON.stringify({"passed":false,"reason":"host_not_instantiable"}));quit(1);return
 var failures: Array=[]
 for allowed: String in ["actor_script_mismatch","actor_script_sha_mismatch"]:
  if not Host.follow_allowed_ancestor_error(allowed):failures.append("missing_exact_exception:"+allowed)
 for forbidden: String in ["root_return_helper_sha_mismatch","flow_asset_sha_mismatch","actor_import_errors","recovery_follow_instance_exact_mismatch"]:
  if Host.follow_allowed_ancestor_error(forbidden):failures.append("guard_weakened:"+forbidden)
 print("FOLLOW02_NATIVE_PARSE ",JSON.stringify({"passed":failures.is_empty(),"failures":failures,"host_constructed":false,"native_input":false}))
 quit(0 if failures.is_empty() else 1)
