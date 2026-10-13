extends SceneTree
var entry:Node
var observed_source=false
func event_seen(event:Dictionary)->void:
 var kind=str(event.get("kind",""))
 if kind.begins_with("ink_") or kind in ["damage","kill"]:print("REAL_SOURCE_EVENT ",JSON.stringify(event))
func _initialize()->void:run.call_deferred()
func run()->void:
 var packed=load("res://visual_rework_20261009/entry.tscn")
 entry=packed.instantiate();root.add_child(entry)
 await process_frame
 entry.request_start("yanguizhou")
 for i in range(2550):
  await process_frame
  if is_instance_valid(entry.active_room) and is_instance_valid(entry.active_room.get("sim")) and not observed_source:
   entry.active_room.sim.combat_event.connect(event_seen);observed_source=true
  if is_instance_valid(entry.active_room) and i%90==0:
   var room=entry.active_room
   print("REAL_ENTRY_STATE ",JSON.stringify({"frame":i,"script":room.get_script().resource_path,"sim":room.sim.get_script().resource_path if is_instance_valid(room.get("sim")) else "missing","mainprep":room.get("_mainprep_required"),"pending":room.get("_mainprep_pending"),"prep_status":room.get("_mainprep_receipt").get("status",""),"phase":room.sim.phase,"enemies":room.sim.living().size(),"input":room.sim.ink_input,"waves":room.sim.ink_waves.size(),"paused":room.sim.paused,"last_ui":room.inputs.back() if not room.inputs.is_empty() else {},"floor_error":room.get("floor_error"),"finished":room.get("finished"),"controller":is_instance_valid(entry.visual_controller),"hero_position":room.sim.hero.position if is_instance_valid(room.get("sim")) else Vector3.ZERO,"source_time":room.sim.hero_time if is_instance_valid(room.get("sim")) else -1}))
 var ok=is_instance_valid(entry.active_room) and is_instance_valid(entry.visual_controller)
 print("REAL_ENTRY_SMOKE_END accepted=",ok," (readiness/errors must be reviewed; no full combat claim)")
 entry.free()
 await process_frame
 quit(0 if ok else 1)
