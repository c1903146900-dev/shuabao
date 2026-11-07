extends RefCounted
## Inert visual remnants of source-confirmed kills. Never retains a live actor,
## delays death/rewards, registers picking, or changes any simulation clock.
const LIFE:float=.22
const EPS:float=.00001
const MAX_BODIES:int=32
var scope:String=""
var sequence:int=-1
var last_real:float=-INF
var terminal_elapsed:float=0.0
var frames:Dictionary={}
var bodies:Dictionary={}
var seen:Dictionary={}

func clear()->void:
 scope="";sequence=-1;last_real=-INF;terminal_elapsed=0.0
 frames.clear();bodies.clear();seen.clear()

func _sync(sim:Node,run_id:String)->bool:
 var current:String="%d|%s|%s|%s|%d"%[sim.get_instance_id(),run_id,str(sim.room_id),str(sim.combat_level_id),int(sim.encounter_generation)]
 if current!=scope:clear();scope=current
 var now:float=float(sim.real_time)
 if not is_finite(now) or now<0 or now<last_real-EPS:
  clear();return false
 last_real=now
 return true

func begin_frame(sim:Node,run_id:String)->void:
 if not _sync(sim,run_id):return
 # Only the most recent actual body drawing can supply an existing-art remnant.
 frames.clear()

func remember(sim:Node,run_id:String,key:String,destination:Rect2,source:Rect2,context:Dictionary)->void:
 if not _sync(sim,run_id) or sim.phase!="combat" or sim.hero.dead:return
 if not context.get("transform") is Transform2D:return
 var transform:Transform2D=context.transform
 if not transform.is_finite() or not destination.is_finite() or not source.is_finite():return
 var id:String=str(context.get("actor_id",""))
 var enemy:Dictionary=sim.enemy_by_id(id)
 if enemy.is_empty() or enemy.dead or not enemy.position is Vector3 or not enemy.position.is_finite():return
 if frames.size()>=256 and not frames.has(id):return
 frames[id]={"key":key,"destination":destination,"source":source,"transform":transform,"real_time":sim.real_time}

func accept(event:Dictionary,sim:Node,run_id:String)->bool:
 if not _sync(sim,run_id) or sim.phase!="combat" or sim.hero.dead:return false
 if str(event.get("kind",""))!="kill" or bool(event.get("stale_generation",false)) or bool(event.get("replay",false)):return false
 if str(event.get("run_id",""))!=run_id or str(event.get("room_id",""))!=str(sim.room_id) or str(event.get("combat_level_id",""))!=str(sim.combat_level_id) or int(event.get("generation",-1))!=int(sim.encounter_generation):return false
 if not event.get("sequence") is int or int(event.sequence)<=sequence:return false
 var when:Variant=event.get("real_time")
 if not (when is int or when is float) or not is_finite(float(when)) or absf(float(when)-float(sim.real_time))>EPS:return false
 # Synchronous current source emission, not a manually replayed dictionary.
 if sim.event_log.is_empty() or sim.event_log.back()!=event:return false
 var id:String=str(event.get("target",""))
 var enemy:Dictionary=sim.enemy_by_id(id)
 if enemy.is_empty() or not enemy.dead or str(enemy.state)!="dead" or not is_finite(float(enemy.hp)) or float(enemy.hp)!=0.0:return false
 if not event.get("position") is Vector3 or not event.position.is_finite() or event.position!=enemy.position or str(event.get("enemy_kind",""))!=str(enemy.kind):return false
 sequence=int(event.sequence)
 if seen.has(id):return false
 seen[id]=true
 var frame:Dictionary=frames.get(id,{})
 if frame.is_empty() or float(when)-float(frame.real_time)>.25 or float(when)<float(frame.real_time)-EPS:return false
 var direction:=Vector3.ZERO
 # Direction is optional visual data from this kill's actual damage, never an
 # assumed attacker position or a new knockback request. Replay damage may kill;
 # its real kill is valid, while a forged/replayed kill emission is not.
 for index in range(sim.event_log.size()-2,-1,-1):
  var hit:Dictionary=sim.event_log[index]
  if float(hit.get("real_time",-1.0))<float(when)-EPS:break
  if str(hit.get("kind",""))!="damage" or str(hit.get("target",""))!=id or int(hit.get("cast_id",-1))!=int(event.get("cast_id",-2)):continue
  var value:Variant=hit.get("direction")
  if value is Vector3 and value.is_finite() and value.length_squared()>EPS:direction=value.normalized()
  break
 if bodies.size()>=MAX_BODIES:bodies.erase(bodies.keys()[0])
 bodies[id]={"actor_id":id,"kind":str(enemy.kind),"position":event.position,"direction":direction,"real_time":float(when),"sequence":event.sequence,"frame":frame.duplicate(true)}
 frames.erase(id)
 return true

func step(sim:Node,run_id:String,delta:float,shown:bool)->void:
 if not _sync(sim,run_id):return
 if not shown or sim.hero.dead or str(sim.phase) not in ["combat","victory"]:
  clear();return
 # Source real_time also advances in hit-stop, but stops at victory. Finish only
 # this bounded visual remainder in victory, without extending source lifetime.
 if sim.phase=="victory" and not sim.paused and is_finite(delta) and delta>0.0:
  terminal_elapsed=minf(LIFE,terminal_elapsed+delta)
 for id in bodies.keys():
  var age:float=float(sim.real_time)-float(bodies[id].real_time)+terminal_elapsed
  if not is_finite(age) or age<0.0 or age>=LIFE:bodies.erase(id)

func sample(sim:Node,run_id:String)->Array:
 if not _sync(sim,run_id) or sim.hero.dead or str(sim.phase) not in ["combat","victory"]:return []
 var result:Array=[]
 for id in bodies:
  var body:Dictionary=bodies[id]
  var age:float=float(sim.real_time)-float(body.real_time)+terminal_elapsed
  if age<0.0 or age>=LIFE:continue
  result.append(body.merged({"age":age,"progress":age/LIFE},true))
 return result
