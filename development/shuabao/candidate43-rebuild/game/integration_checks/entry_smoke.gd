extends SceneTree
var entry:Node
func _initialize()->void:run.call_deferred()
func run()->void:
 var packed=load("res://visual_rework_20261009/entry.tscn")
 entry=packed.instantiate();root.add_child(entry)
 await process_frame
 entry.request_start("yanguizhou")
 for i in range(180):
  await process_frame
  if is_instance_valid(entry.active_room) and i%30==0:
   var room=entry.active_room
   print("REAL_ENTRY_STATE ",JSON.stringify({"frame":i,"script":room.get_script().resource_path,"sim":room.sim.get_script().resource_path if is_instance_valid(room.get("sim")) else "missing","mainprep":room.get("_mainprep_required"),"pending":room.get("_mainprep_pending"),"finished":room.get("finished"),"startup_error":room.get("startup_session_error"),"floor_error":room.get("floor_error"),"release":room.get("release_installation"),"ordinary_install":room.get("ordinary_visual_installation"),"dual_binding":room.get("ordinary_visual_asset_binding"),"controller":is_instance_valid(entry.visual_controller)}))
 var ok=is_instance_valid(entry.active_room) and is_instance_valid(entry.visual_controller)
 print("REAL_ENTRY_SMOKE_END accepted=",ok," (readiness/errors must be reviewed; no full combat claim)")
 entry.free()
 await process_frame
 quit(0 if ok else 1)
