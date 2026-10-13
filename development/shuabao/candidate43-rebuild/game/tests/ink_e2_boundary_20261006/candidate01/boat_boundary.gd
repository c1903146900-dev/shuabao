extends RefCounted
## Pure XZ front/room geometry. Walls and hero landing never enter this model.
## Exact closed room bounds, no tolerance expansion and no inward separation.

static func front_bounds(direction: Vector3, width: float, extent: float) -> Vector3:
 var side: Vector3 = Vector3(-direction.z,0.0,direction.x)
 return Vector3(extent-absf(side.x)*width*0.5,0.0,extent-absf(side.z)*width*0.5)

static func origin_legal(origin: Vector3, direction: Vector3, width: float, extent: float) -> bool:
 if not origin.is_finite() or not direction.is_finite() or not is_finite(width) or not is_finite(extent): return false
 if extent <= 0.0 or width < 0.0 or direction.length_squared() == 0.0: return false
 var bound: Vector3 = front_bounds(direction,width,extent)
 return bound.x >= 0.0 and bound.z >= 0.0 and absf(origin.x) <= bound.x and absf(origin.z) <= bound.z

static func plan(origin: Vector3, direction: Vector3, width: float, speed: float, born_at: float, voyage_until: float, extent: float) -> Dictionary:
 if not origin_legal(origin,direction,width,extent) or not is_finite(speed) or speed <= 0.0 or voyage_until < born_at: return {"valid":false}
 var bound: Vector3 = front_bounds(direction,width,extent)
 var first_distance: float = INF
 for axis: int in [0,2]:
  if direction[axis] > 0.0: first_distance = minf(first_distance,(bound[axis]-origin[axis])/direction[axis])
  elif direction[axis] < 0.0: first_distance = minf(first_distance,(-bound[axis]-origin[axis])/direction[axis])
 var duration: float = voyage_until-born_at
 var reaches_boundary: bool = first_distance <= speed*duration
 var distance: float = minf(first_distance,speed*duration)
 var stop: Vector3 = origin+direction*distance
 # Clamp only arithmetic round-off to the same exact front bounds. This does
 # not project an illegal initial front, slide along a wall, or inset the boat.
 stop = Vector3(clampf(stop.x,-bound.x,bound.x),0.0,clampf(stop.z,-bound.z,bound.z))
 return {"valid":true,"origin":origin,"direction":direction,"width":width,"room_half_extent":extent,"front_center_bounds":bound,"speed":speed,"born_at":born_at,"voyage_until":voyage_until,"motion_until":born_at+distance/speed,"stop_position":stop,"reaches_boundary":reaches_boundary,"travel_distance":distance}

static func position_at(route: Dictionary, at: float) -> Vector3:
 if at >= float(route.motion_until): return route.stop_position
 return Vector3(route.origin)+Vector3(route.direction)*float(route.speed)*maxf(0.0,at-float(route.born_at))
