extends "res://scripts/combat/enemy_director.gd"
## Pre-filter exact mountain interception, then use unchanged authoritative enemy
## projectile movement/damage/landing. No mountain means byte-equivalent delegation.
func step_projectiles(sim,dt:float)->void:
 if _frozen(sim):return
 var scope:Dictionary=sim._ink_scope()
 if not sim.ink_mountain.is_empty():
  for projectile in sim.projectiles.duplicate():
   if projectile.get("team","enemy")!="enemy":continue
   var previous:Vector3=projectile.position
   var travel_dt:float=minf(dt,maxf(0.0,float(projectile.left)))
   var next:Vector3
   var lob:bool=projectile.get("type","bolt")=="lob"
   if lob:
    var progress:float=clampf(1.0-(float(projectile.left)-dt)/float(projectile.duration),0.0,1.0)
    next=Vector3(projectile.origin).lerp(projectile.target_point,progress)
   else:next=previous+Vector3(projectile.direction)*float(projectile.speed)*travel_dt
   var hit:Dictionary=sim._q3_terrain_contact(previous,next,float(projectile.get("radius",.14)),{},travel_dt/maxf(EPS,dt))
   if hit.is_empty():continue
   if not lob:
    # A player or existing static wall reached before the mountain keeps its
    # original outcome. Never let a later mountain erase an earlier hero hit.
    var clipped:Vector3=_clip_motion(sim,previous,next,float(projectile.get("radius",.14)))
    if previous.distance_squared_to(clipped)+EPS<previous.distance_squared_to(hit.position):continue
    var point:Vector2=Vector2(previous.x-sim.hero.position.x,previous.z-sim.hero.position.z)
    var delta:Vector2=Vector2(next.x-previous.x,next.z-previous.z)
    var hero_hit:float=sim.Geometry._circle_entry(point,delta,Vector2.ZERO,HERO_RADIUS+float(projectile.get("radius",.14)))
    if hero_hit<=float(hit.fraction)+EPS:continue
   sim.projectiles.erase(projectile)
   var receipt:Dictionary=hit.duplicate(true)
   receipt.merge({"source_event_id":str(hit.terrain_id)+":blocked:"+str(projectile.id),"projectile_id":projectile.id,"projectile_type":projectile.get("type","bolt"),"projectile_owner":projectile.owner,"projectile_team":projectile.get("team","enemy"),"source":"q3","origin":previous,"attempted_destination":next,"blocked_before_landing":lob},true)
   sim.emit_event("ink_q3_projectile_blocked",receipt)
   if not sim._ink_scope_current(scope):return
 super.step_projectiles(sim,dt)
