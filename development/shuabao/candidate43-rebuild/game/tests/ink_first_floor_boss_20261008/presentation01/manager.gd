extends Node3D
## Read-only Boss presentation attachment, called after the inherited roster pose.
## Does not replace a Sim, actor view, authority, clock or original enemy layer.
const Art = preload("res://tests/ink_first_floor_boss_20261008/art02/boss_art_consumer.gd")
var consumers: Dictionary = {}
var view_ids: Dictionary = {}
var last_report: Dictionary = {}
func _ready() -> void:
 set_process(false)
 set_physics_process(false)
func clear() -> void:
 for key: String in consumers.keys():
  if is_instance_valid(consumers[key]):
   consumers[key].clear()
   consumers[key].free()
 consumers.clear()
 view_ids.clear()
 last_report={"status":"inactive","actors":{}}
func present(source: Node, views: Dictionary, frame: Dictionary) -> Dictionary:
 if not is_instance_valid(source) or bool(frame.get("finished",false)) or bool(frame.get("loading",false)) or bool(frame.get("hero_dead",false)):
  clear()
  return last_report.duplicate(true)
 var active: Dictionary = {}
 var reports: Dictionary = {}
 for actor: Dictionary in source.enemies:
  if str(actor.get("kind",""))!="boss" or bool(actor.get("dead",false)): continue
  # snapshot() initializes missing runtime; source authority must do that first.
  if not actor.has("boss_runtime"): continue
  var key: String=str(actor.actor_id)
  if not views.has(key) or not is_instance_valid(views[key]): continue
  active[key]=true
  if consumers.has(key) and int(view_ids.get(key,-1))!=views[key].get_instance_id():
   consumers[key].clear(); consumers[key].free(); consumers.erase(key); view_ids.erase(key)
  if not consumers.has(key):
   var consumer: Node3D=Art.new()
   add_child(consumer)
   if not consumer.configure(views[key]):
    consumer.free()
    last_report={"status":"HOLD","reason":"boss_art_configure_failed","actor_id":key}
    return last_report.duplicate(true)
   consumers[key]=consumer
   view_ids[key]=views[key].get_instance_id()
  reports[key]=consumers[key].sample(source.enemy_director.snapshot(source,actor),actor,frame)
 for key: String in consumers.keys():
  if not active.has(key):
   consumers[key].clear(); consumers[key].free(); consumers.erase(key); view_ids.erase(key)
 last_report={"status":"ready","actors":reports,"source_instance_id":source.get_instance_id(),"world_time":frame.get("world_time",0.0)}
 return last_report.duplicate(true)
