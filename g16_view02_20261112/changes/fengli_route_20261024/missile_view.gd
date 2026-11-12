extends RefCounted
## Read-only G16 source missiles. Never spawns from notifications or simulates flight.
const SOURCE:String="res://fengli_route_20261024/sim.gd"
var receipt:Dictionary={}
func clear()->void:receipt.clear()
func sample(sim:Node)->Dictionary:
 receipt={"missiles":[],"live_count":0,"gameplay_authority":false,"time_domain":"source_world"}
 if not is_instance_valid(sim) or sim.get_script()==null or sim.get_script().resource_path!=SOURCE:return receipt.duplicate(true)
 var live:RefCounted=sim.common.runtime
 if sim.hero.actor_id!="fengli" or sim.hero.dead or sim.phase!="combat" or not live.combat or live.room_id!=sim.room_id or live.generation!=sim.encounter_generation or not live.active("g16"):return receipt.duplicate(true)
 receipt["scope"]="%d|%s|%s|%s|%d"%[sim.get_instance_id(),sim.route_run_id,sim.combat_level_id,sim.room_id,sim.encounter_generation]
 for entry:Variant in live.projectiles:
  if not entry is Dictionary or entry.get("kind","")!="missile" or entry.get("source","")!="common_g16":continue
  if not entry.get("entity_id") is String or str(entry.entity_id).is_empty() or not entry.get("target_id") is String:continue
  if not entry.get("position") is Vector3 or not entry.position.is_finite():continue
  if not (entry.get("left") is int or entry.get("left") is float) or not is_finite(float(entry.left)) or float(entry.left)<=0.0:continue
  var target:Dictionary=sim.enemy_by_id(str(entry.target_id))
  if target.is_empty() or bool(target.get("dead",true)) or not target.get("position") is Vector3 or not target.position.is_finite():continue
  # Fresh copied positions only; target selection and movement remain in the source.
  receipt.missiles.append({"entity_id":str(entry.entity_id),"position":entry.position,"target_id":str(entry.target_id),"target_position":target.position,"left":float(entry.left)})
 receipt.live_count=receipt.missiles.size()
 return receipt.duplicate(true)
func draw(view:Node2D,sim:Node)->void:
 var state:Dictionary=sample(sim)
 for missile:Dictionary in state.missiles:
  var at:Vector2=view.p(missile.position)+Vector2(0,-12)
  var target:Vector2=view.p(missile.target_position)+Vector2(0,-12)
  if not at.is_finite() or not target.is_finite():continue
  var direction:Vector2=(target-at).normalized()
  if direction.length_squared()<0.00001:direction=Vector2.RIGHT
  var side:Vector2=Vector2(-direction.y,direction.x)
  # Compact friendly bolt, not an enlarged collision body or target-range line.
  view.draw_line(at-direction*12.0,at-direction*5.0,Color(0.32,0.92,0.88,0.60),2.0,true)
  var body:=PackedVector2Array([at+direction*7.0,at-direction*5.0+side*4.0,at-direction*2.0,at-direction*5.0-side*4.0])
  view.draw_colored_polygon(body,Color(0.45,1.0,0.87,1.0))
  body.append(body[0]);view.draw_polyline(body,Color(0.04,0.12,0.17,1.0),1.5,true)
  view.draw_line(at-direction*1.0,at+direction*3.0,Color(1.0,0.94,0.66,1.0),2.0,true)
