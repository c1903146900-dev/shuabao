extends "res://tests/ink_q3_foundation_20261004/ink_q3_enemy_director.gd"
## Independent opt-in candidate. All movement still passes inherited real collision.
## Only static AABB navigation is planned here; Q3 collision remains authoritative.
const NAV_MARGIN := 0.22
const NAV_MAX_OBSTACLES := 24
const NAV_MAX_NODES := 102 # start + goal + 4 corners per obstacle + 4 arena corners
const NAV_REPLAN_SECONDS := 3.0 # unchanged original waypoint lifetime
const NAV_TOLERANCE_SQ := 0.00000001

func _navigate_step(sim, enemy: Dictionary, desired: Vector3, dt: float) -> Vector3:
 var origin: Vector3 = enemy.position
 var step_length: float = origin.distance_to(desired)
 enemy.nav_left = maxf(0.0,float(enemy.get("nav_left",0.0))-dt)
 var points: Array = enemy.get("nav_points",[])
 if enemy.nav_left <= 0.0 or not _nav_path_legal(sim,origin,points,enemy.radius): points = []
 # Reach a corner before dropping it. The old step-length shortcut could cut it.
 while not points.is_empty() and origin.distance_squared_to(points[0]) <= NAV_TOLERANCE_SQ:
  points.pop_front()
 enemy.nav_points = points
 if step_length <= EPS: return _clip_motion(sim,origin,desired,enemy.radius)
 if not points.is_empty():
  var waypoint: Vector3 = origin.move_toward(points[0],step_length)
  var progress: Vector3 = _clip_motion(sim,origin,waypoint,enemy.radius)
  if progress.distance_squared_to(origin) > NAV_TOLERANCE_SQ: return progress
  # Replan a persisted, now blocked route in this call; never wait out a bad point.
  points = []; enemy.nav_points = []; enemy.nav_left = 0.0
 var result: Vector3 = _clip_motion(sim,origin,desired,enemy.radius)
 if _nav_point_legal(sim,desired,enemy.radius) and result.distance_squared_to(desired) <= NAV_TOLERANCE_SQ: return result
 # Retain the small local detour, but try both sides and validate the whole chain
 # against ALL solids, boundary and inherited swept motion before accepting it.
 for obstacle: Dictionary in sim.obstacles:
  var half: Vector3 = obstacle.half+Vector3(enemy.radius,0,enemy.radius)
  var center: Vector3 = obstacle.position
  if _segment_box_entry(origin,desired,center-half,center+half) >= 1.0: continue
  for side: float in [float(enemy.flank_sign),-float(enemy.flank_sign)]:
   if absf(origin.z-center.z) >= half.z-0.02:
    var entry_side: float = 1.0 if origin.z >= center.z else -1.0
    var edge_x: float = center.x+side*(half.x+NAV_MARGIN)
    points = [Vector3(edge_x,0,origin.z),Vector3(edge_x,0,center.z-entry_side*(half.z+NAV_MARGIN))]
   else:
    var entry_side: float = 1.0 if origin.x >= center.x else -1.0
    var edge_z: float = center.z+side*(half.z+NAV_MARGIN)
    points = [Vector3(origin.x,0,edge_z),Vector3(center.x-entry_side*(half.x+NAV_MARGIN),0,edge_z)]
   if _nav_path_legal(sim,origin,points,enemy.radius):
    return _nav_accept(sim,enemy,origin,points,step_length)
 # Overlapping walls / boundary-attached solids may invalidate both local routes.
 # This finite visibility graph has no grid, navmesh, engine service or RNG calls.
 var goal: Vector3 = sim.hero.position
 var offset: Vector3 = desired-origin
 if offset.dot(goal-origin) <= 0.0:
  # Preserve a retreat / strafe request instead of converting it into a chase.
  goal = origin+offset.normalized()*3.0
  var bound: float = maxf(0.0,sim.arena_half_extent-enemy.radius)
  goal = Vector3(clampf(goal.x,-bound,bound),0,clampf(goal.z,-bound,bound))
 points = _nav_corner_path(sim,origin,goal,enemy.radius,float(enemy.flank_sign))
 if not points.is_empty(): return _nav_accept(sim,enemy,origin,points,step_length)
 # Original bounded tangent fallback; physical clipping remains the last word.
 for angle: float in [PI/3.0,-PI/3.0,PI/2.0,-PI/2.0,PI]:
  var candidate: Vector3 = origin+offset.rotated(Vector3.UP,angle*float(enemy.flank_sign))
  if _nav_leg_legal(sim,origin,candidate,enemy.radius): return _clip_motion(sim,origin,candidate,enemy.radius)
 return result

func _nav_point_legal(sim, point: Vector3, radius: float) -> bool:
 if not point.is_finite(): return false
 var bound: float = maxf(0.0,sim.arena_half_extent-radius)
 if absf(point.x) > bound or absf(point.z) > bound or absf(point.y) > EPS: return false
 for obstacle: Dictionary in sim.obstacles:
  var half: Vector3 = obstacle.half+Vector3(radius,0,radius)
  var offset: Vector3 = point-Vector3(obstacle.position)
  if absf(offset.x) < half.x and absf(offset.z) < half.z: return false
 return true

func _nav_leg_legal(sim, origin: Vector3, destination: Vector3, radius: float) -> bool:
 if not _nav_point_legal(sim,destination,radius): return false
 # The authoritative source uses the same radius, all solids and arena boundary;
 # Q3's sim override can additionally reject a leg without being bypassed.
 for obstacle: Dictionary in sim.obstacles:
  var half: Vector3 = obstacle.half+Vector3(radius,0,radius)
  var center: Vector3 = obstacle.position
  if _segment_box_entry(origin,destination,center-half,center+half) < 1.0: return false
 return _clip_motion(sim,origin,destination,radius).distance_squared_to(destination) <= NAV_TOLERANCE_SQ

func _nav_path_legal(sim, origin: Vector3, points: Array, radius: float) -> bool:
 if points.size() > NAV_MAX_NODES: return false
 var previous: Vector3 = origin
 for point: Vector3 in points:
  if not _nav_leg_legal(sim,previous,point,radius): return false
  previous = point
 return true

func _nav_accept(sim, enemy: Dictionary, origin: Vector3, points: Array, step_length: float) -> Vector3:
 enemy.nav_points = points
 enemy.nav_left = NAV_REPLAN_SECONDS
 return _clip_motion(sim,origin,origin.move_toward(points[0],step_length),enemy.radius)

func _nav_corner_path(sim, origin: Vector3, goal: Vector3, radius: float, flank_sign: float) -> Array:
 if sim.obstacles.size() > NAV_MAX_OBSTACLES or not _nav_point_legal(sim,goal,radius): return []
 var nodes: Array = [origin,goal]
 # Ordering is deterministic. Both sides are included; flank preference breaks
 # equal-cost alternatives without adding or consuming random numbers.
 for obstacle: Dictionary in sim.obstacles:
  var half: Vector3 = obstacle.half+Vector3(radius+NAV_MARGIN,0,radius+NAV_MARGIN)
  var center: Vector3 = obstacle.position
  for x_sign: float in [flank_sign,-flank_sign]:
   for z_sign: float in [flank_sign,-flank_sign]:
    _nav_append_node(sim,nodes,Vector3(center.x+x_sign*half.x,0,center.z+z_sign*half.z),radius)
 var bound: float = maxf(0.0,sim.arena_half_extent-radius-NAV_MARGIN)
 for x_sign: float in [flank_sign,-flank_sign]:
  for z_sign: float in [flank_sign,-flank_sign]:
   _nav_append_node(sim,nodes,Vector3(x_sign*bound,0,z_sign*bound),radius)
 var costs: Array = []; var previous: Array = []; var closed: Array = []
 for index: int in range(nodes.size()):
  costs.append(INF); previous.append(-1); closed.append(false)
 costs[0] = 0.0
 for iteration: int in range(nodes.size()):
  var nearest: int = -1
  for index: int in range(nodes.size()):
   if not closed[index] and (nearest < 0 or float(costs[index]) < float(costs[nearest])): nearest = index
  if nearest < 0 or not is_finite(float(costs[nearest])): break
  if nearest == 1:
   var path: Array = []; var cursor: int = 1
   for link: int in range(nodes.size()):
    if cursor == 0: return path if _nav_path_legal(sim,origin,path,radius) else []
    path.push_front(nodes[cursor]); cursor = int(previous[cursor])
    if cursor < 0: return []
   return []
  closed[nearest] = true
  for index: int in range(nodes.size()):
   if closed[index]: continue
   var cost: float = float(costs[nearest])+Vector3(nodes[nearest]).distance_to(nodes[index])
   if cost >= float(costs[index]): continue
   if not _nav_leg_legal(sim,nodes[nearest],nodes[index],radius): continue
   costs[index] = cost; previous[index] = nearest
 return []

func _nav_append_node(sim, nodes: Array, point: Vector3, radius: float) -> void:
 if nodes.size() >= NAV_MAX_NODES or not _nav_point_legal(sim,point,radius): return
 for present: Vector3 in nodes:
  if present.distance_squared_to(point) <= NAV_TOLERANCE_SQ: return
 nodes.append(point)
