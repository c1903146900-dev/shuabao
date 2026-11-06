extends RefCounted
## Visual-only, actor-specific response to current positive enemy damage.
## No knockback, stagger, hit-stop, actor position or combat state writes.
const LIFE:float=.14
var hits:Dictionary={}
var scope:String=""
var sequence:int=-1
func clear()->void:
 hits.clear();scope="";sequence=-1
func _sync(sim:Node)->void:
 var current:String="%d|%s|%d"%[sim.get_instance_id(),str(sim.room_id),int(sim.encounter_generation)]
 if current!=scope:clear();scope=current
 for id in hits.keys():
  if float(sim.real_time)-float(hits[id].time)>LIFE:hits.erase(id)
func accept(event:Dictionary,sim:Node)->bool:
 _sync(sim)
 if str(event.get("kind",""))!="damage" or bool(event.get("replay",false)) or bool(event.get("stale_generation",false)):return false
 if int(event.get("generation",-1))!=int(sim.encounter_generation) or str(event.get("room_id",""))!=str(sim.room_id):return false
 if not event.get("sequence") is int or int(event.sequence)<=sequence:return false
 sequence=int(event.sequence)
 var amount:Variant=event.get("amount")
 if not (amount is float or amount is int) or not is_finite(float(amount)) or float(amount)<=0:return false
 var time:Variant=event.get("real_time")
 if not (time is float or time is int) or not is_finite(float(time)) or absf(float(time)-float(sim.real_time))>.00001:return false
 var target:String=str(event.get("target",""));var found:bool=false
 for enemy:Dictionary in sim.enemies:
  if str(enemy.actor_id)==target:found=true;break
 if not found:return false
 var direction:Vector3=event.get("direction",Vector3.ZERO) if event.get("direction",Vector3.ZERO) is Vector3 else Vector3.ZERO
 if not direction.is_finite():direction=Vector3.ZERO
 if hits.has(target) and float(time)-float(hits[target].time)<.055:return false
 hits[target]={"time":float(time),"direction":direction.normalized(),"sequence":sequence}
 return true
func sample(sim:Node,enemy:Dictionary)->Dictionary:
 _sync(sim)
 var base:Dictionary={"amount":0.0,"direction":Vector3.ZERO,"sequence":-1}
 if bool(enemy.get("dead",false)) or sim.phase!="combat":return base
 var hit:Dictionary=hits.get(str(enemy.actor_id),{})
 if hit.is_empty():return base
 var age:float=float(sim.real_time)-float(hit.time)
 if age<0 or age>LIFE:return base
 var phase:float=age/LIFE
 # Fast impact, damped release. Repeated hits cannot accumulate displacement.
 var pulse:float=(1-phase)*(1-phase)
 return {"amount":pulse,"direction":hit.direction,"sequence":hit.sequence,"age":age}
