extends RefCounted
## Read-only ground footprint of actual pending G12 bombardments.
## No event-spawned effect, new targeting, simulated damage or independent timer.
const SOURCE:String="res://fengli_route_20261024/sim.gd"
const IMPACT_SECONDS:float=0.20 # Visual persistence, never a gameplay delay.
var receipt:Dictionary={}
var _scope:String=""
var _impacts:Array=[]
var _last_sequence:int=-1
func clear()->void:
 receipt.clear();_impacts.clear();_scope="";_last_sequence=-1
func current(sim:Node)->bool:
 if not is_instance_valid(sim) or sim.get_script()==null or sim.get_script().resource_path!=SOURCE:clear();return false
 var next:String="%d|%s|%s|%d"%[sim.get_instance_id(),sim.route_run_id,sim.room_id,sim.encounter_generation]
 if next!=_scope:clear();_scope=next
 var live:RefCounted=sim.common.runtime
 if sim.hero.actor_id!="fengli" or sim.hero.dead or sim.phase!="combat" or not live.combat or live.room_id!=sim.room_id or live.generation!=sim.encounter_generation or not live.active("g12"):
  _impacts.clear();return false
 return true
func accept(event:Dictionary,sim:Node)->bool:
 if not current(sim) or event.get("kind","")!="common_hex_area_effect" or event.get("source","")!="common_g12":return false
 if not sim.common._draining or not bool(event.get("hex_generated",false)) or bool(event.get("replay",false)) or bool(event.get("stale_generation",false)):return false
 if event.get("run_id","")!=sim.route_run_id or event.get("room_id","")!=sim.room_id or event.get("generation",-1)!=sim.encounter_generation:return false
 if not event.get("sequence") is int or int(event.sequence)!=sim.sequence or int(event.sequence)<=_last_sequence:return false
 if sim.event_log.is_empty() or sim.event_log.back()!=event:return false
 if not event.get("position") is Vector3 or not event.position.is_finite() or not number(event.get("radius")) or float(event.radius)<=0.0:return false
 if not number(event.get("world_time")) or absf(float(event.world_time)-float(sim.clock.world_time))>0.00001:return false
 _last_sequence=int(event.sequence)
 _impacts.append({"position":event.position,"radius":float(event.radius),"world_time":float(event.world_time),"sequence":int(event.sequence)})
 if _impacts.size()>32:_impacts.pop_front()
 return true
func number(value:Variant)->bool:
 return (value is int or value is float) and is_finite(float(value))
func sample(sim:Node)->Dictionary:
 var valid:bool=current(sim)
 receipt={"marks":[],"impacts":[],"live_count":0,"impact_count":0,"gameplay_authority":false,"time_domain":"source_world"}
 if not valid:return receipt.duplicate(true)
 var live:RefCounted=sim.common.runtime
 var retained:Array=[]
 for item:Dictionary in _impacts:
  var age:float=float(sim.clock.world_time)-float(item.world_time)
  if age>=0.0 and age<IMPACT_SECONDS:
   retained.append(item);var copy:Dictionary=item.duplicate(true);copy["age"]=age;receipt.impacts.append(copy)
 _impacts=retained;receipt.impact_count=retained.size()
 if not number(live.time):return receipt.duplicate(true)
 receipt["scope"]="%d|%s|%s|%d"%[sim.get_instance_id(),sim.route_run_id,sim.room_id,sim.encounter_generation]
 for entry:Variant in live.scheduled:
  if not entry is Dictionary or entry.get("kind","")!="bombardment":continue
  if str(entry.get("run_id",live.run_id))!=live.run_id or str(entry.get("room_id",""))!=sim.room_id or int(entry.get("generation",-1))!=sim.encounter_generation:continue
  if not entry.get("position") is Vector3 or not entry.position.is_finite():continue
  if not number(entry.get("due")) or not number(entry.get("radius")) or float(entry.radius)<=0.0:continue
  var remaining:float=float(entry.due)-float(live.time)
  if remaining<=0.0:continue
  receipt.marks.append({"position":entry.position,"radius":float(entry.radius),"remaining":remaining})
 receipt.live_count=receipt.marks.size()
 return receipt.duplicate(true)
func draw_ground(view:Node2D,sim:Node)->void:
 var state:Dictionary=sample(sim)
 for mark:Dictionary in state.marks:
  var rim:=PackedVector2Array()
  for i in range(33):
   var angle:float=float(i)*TAU/32.0
   var at:Vector2=view.p(mark.position+Vector3(cos(angle),0.0,sin(angle))*float(mark.radius))
   if not at.is_finite():rim.clear();break
   rim.append(at)
  if rim.size()!=33:continue
  # Friendly warm-gold footprint, beneath actors; no opaque fill or danger text.
  view.draw_polyline(rim,Color(1.0,0.78,0.30,0.76),1.6,true)
  var center:Vector2=view.p(mark.position)
  if not center.is_finite():continue
  view.draw_line(center+Vector2(-4,0),center+Vector2(4,0),Color(1.0,0.90,0.57,0.85),1.4,true)
  view.draw_line(center+Vector2(0,-3),center+Vector2(0,3),Color(1.0,0.90,0.57,0.85),1.4,true)

 # Only an actual source area_effect can create these short ground flashes.
 for impact:Dictionary in state.impacts:
  var alpha:float=1.0-float(impact.age)/IMPACT_SECONDS
  var center:Vector2=view.p(impact.position)
  if not center.is_finite():continue
  for i in range(8):
   var angle:float=float(i)*TAU/8.0
   var axis:=Vector3(cos(angle),0.0,sin(angle))*float(impact.radius)
   var near:Vector2=view.p(impact.position+axis*0.25)
   var far:Vector2=view.p(impact.position+axis*0.85)
   if near.is_finite() and far.is_finite():view.draw_line(near,far,Color(1.0,0.88,0.48,alpha),2.5,true)
