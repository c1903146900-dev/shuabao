extends SceneTree
const Host=preload("res://tests/ink_first_floor_user_route_20261005/root_return_native01/host.gd")
func _initialize() -> void:
 var failures: Array=[]
 var host_script: Script=Host
 if not host_script.can_instantiate():
  failures.append("host_not_instantiable")
  print("ROOT_RETURN_NATIVE01_PARSE ",JSON.stringify({"passed":false,"failures":failures,"host_constructed":false,"native_input":false,"art_accepted":false}))
  quit(1)
  return
 for allowed: String in ["actor_script_mismatch","actor_script_sha_mismatch"]:
  if not Host.allowed_ancestor_identity_error(allowed):failures.append("missing_exact_exception:"+allowed)
 for forbidden: String in ["q3_bound_required","flow_asset_sha_mismatch","intent_consumer_accepted_required","actor_import_errors","root_return_helper_sha_mismatch"]:
  if Host.allowed_ancestor_identity_error(forbidden):failures.append("guard_weakened:"+forbidden)
 print("ROOT_RETURN_NATIVE01_PARSE ",JSON.stringify({"passed":failures.is_empty(),"failures":failures,"host_constructed":false,"native_input":false,"art_accepted":false}))
 quit(0 if failures.is_empty() else 1)
