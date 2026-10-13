extends SceneTree
const Layer=preload("res://tests/ink_normal_floor_host_20261004/enemy_layer.gd")
func _initialize()->void:run.call_deferred()
func run()->void:
 var layer=Layer.new();root.add_child(layer);var errors:Array=[];var results:Dictionary={}
 for role:String in ["minion","pouncer","armored","ranged","pitcher","support","elite","boss"]:
  var result=layer.preflight({"node_type":"combat","roster":[{"kind":role}]});results[role]=result
  if not result.get("accepted",false):errors.append(role)
 print("ACTUAL_ENEMY_ASSET_PREFLIGHT ",JSON.stringify({"results":results,"errors":errors}))
 layer.free();await process_frame;quit(0 if errors.is_empty() else 1)
