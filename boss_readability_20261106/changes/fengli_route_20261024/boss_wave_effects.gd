extends RefCounted
## Read-only projection of the director's current, single-front Boss B snapshot.
## Warning rails mark the future track; only the advancing solid lip is damaging.
const EPS := 0.000001
const MAX_LENGTH := 10.0
const WIDTH := 1.6
const WARNING := 1.35
const INK := Color("191a36")
const WARNING_EDGE := Color("ffb65a")
const WARNING_ACCENT := Color("ff688f")
const FRONT := Color("f05cf4")
const FRONT_LIGHT := Color("ffe9a8")
var error: String = ""
var receipt: Dictionary = {}
var _warning_ids: Dictionary = {}
var _warning_badges:Array=[]

func draw(view: Node2D, sim: Node) -> void:
 receipt = {"warnings":[], "fronts":[], "damage_authority":false, "geometry_authority":"current_boss_wave_snapshot", "time_domain":"world"}
 _warning_ids.clear()
 _warning_badges.clear()
 if not error.is_empty() or sim.phase != "combat" or sim.hero.dead:
  return
 for enemy: Dictionary in sim.enemies:
  if enemy.dead or str(enemy.get("kind", "")) != "boss":
   continue
  var cast: Dictionary = sim.enemy_director.boss_wave.snapshot(sim, enemy)
  if cast.is_empty():
   if str(enemy.get("state", "")) == "warning" and str(enemy.get("attack_shape", "")) == "boss_wave_line":
    _fail("boss_wave_warning_snapshot_missing")
   continue
  if not _valid(sim, enemy, cast):
   return
  if bool(cast.released):
   _draw_front(view, cast)
  else:
   _draw_warning(view, enemy, cast)
   _warning_ids[str(enemy.actor_id)] = str(cast.boss_cast_id)
  if not error.is_empty():
   return

func handles_warning(enemy: Dictionary) -> bool:
 return error.is_empty() and _warning_ids.has(str(enemy.get("actor_id", "")))

func _valid(sim: Node, enemy: Dictionary, cast: Dictionary) -> bool:
 var fields: Array = ["boss_cast_id", "run_id", "source_instance_id", "hero_instance_id", "generation", "room_id", "actor_id", "move", "origin", "direction", "target_point", "target_actor_id", "geometry", "released", "distance", "front_position", "warning_duration", "warning_progress"]
 if not cast.has_all(fields) or not cast.geometry is Dictionary or not cast.released is bool:
  return _fail("boss_wave_snapshot_fields_invalid")
 if str(cast.boss_cast_id).is_empty() or str(cast.move) != "B" or str(cast.run_id).is_empty() or str(cast.run_id) != str(sim.route_run_id) or int(cast.source_instance_id) != sim.get_instance_id() or int(cast.hero_instance_id) != sim.hero.get_instance_id() or int(cast.generation) != sim.encounter_generation or str(cast.room_id) != sim.room_id:
  return _fail("boss_wave_snapshot_scope_invalid")
 if str(cast.actor_id) != str(enemy.actor_id) or not is_same(enemy, sim.enemy_by_id(str(cast.actor_id))) or str(cast.target_actor_id) != str(sim.hero.actor_id):
  return _fail("boss_wave_snapshot_actor_invalid")
 if not _point(cast.origin) or not _direction(cast.direction) or not _point(cast.target_point) or not _point(cast.front_position):
  return _fail("boss_wave_snapshot_vectors_invalid")
 var geometry: Dictionary = cast.geometry
 if not geometry.has_all(["shape", "origin", "direction", "length", "width"]) or str(geometry.shape) != "boss_wave_line" or not _point(geometry.origin) or not _direction(geometry.direction) or not _number(geometry.length, 0.0, MAX_LENGTH) or not _number(geometry.width, WIDTH, WIDTH):
  return _fail("boss_wave_snapshot_geometry_invalid")
 if Vector3(geometry.origin).distance_squared_to(cast.origin) > EPS or Vector3(geometry.direction).distance_squared_to(cast.direction) > EPS or not _number(cast.distance, 0.0, float(geometry.length)) or not _number(cast.warning_duration, WARNING, WARNING) or not _number(cast.warning_progress, 0.0, 1.0):
  return _fail("boss_wave_snapshot_geometry_mismatch")
 var expected: Vector3 = Vector3(cast.origin) + Vector3(cast.direction) * float(cast.distance)
 if expected.distance_squared_to(cast.front_position) > EPS:
  return _fail("boss_wave_front_position_mismatch")
 if not bool(cast.released) and (str(enemy.state) != "warning" or str(enemy.get("attack_shape", "")) != "boss_wave_line" or str(enemy.get("telegraph_style", "")) != "boss_wave_exact" or bool(enemy.get("ground_warning", false)) or float(cast.distance) > EPS):
  return _fail("boss_wave_warning_contract_invalid")
 return true

func _draw_warning(view: Node2D, enemy: Dictionary, cast: Dictionary) -> void:
 var geometry: Dictionary = cast.geometry
 var origin: Vector3 = geometry.origin
 var forward: Vector3 = geometry.direction
 var side := Vector3(-forward.z, 0.0, forward.x)
 var half: float = float(geometry.width) * 0.5
 var length: float = float(geometry.length)
 var progress: float = float(cast.warning_progress)
 var world_edges: Array = []
 var screen_edges: Array = []
 # Hollow, discontinuous rails are intentionally not an active filled damage lane.
 for sign_value: float in [-1.0, 1.0]:
  var edge_origin: Vector3 = origin + side * half * sign_value
  var start: float = 0.0
  while start < length - EPS:
   var finish: float = minf(length, start + 0.43)
   var a: Vector3 = edge_origin + forward * start
   var b: Vector3 = edge_origin + forward * finish
   var points: PackedVector2Array = _project(view, [a, b])
   if points.size() != 2:
    return
   view.draw_line(points[0], points[1], INK, 4.5, true)
   view.draw_line(points[0], points[1], WARNING_EDGE, 2.0, true)
   world_edges.append([a, b]); screen_edges.append([points[0], points[1]])
   start += 0.70
 var cap_world: Array = [origin + forward * length - side * half, origin + forward * length + side * half]
 var cap: PackedVector2Array = _project(view, cap_world)
 var body: PackedVector2Array = _project(view, [enemy.position, Vector3(enemy.position) + forward])
 if cap.size() != 2 or body.size() != 2:
  return
 view.draw_line(cap[0], cap[1], INK, 5.0, true)
 view.draw_line(cap[0], cap[1], WARNING_ACCENT, 2.5, true)
 var screen_direction: Vector2 = body[1] - body[0]
 if screen_direction.length_squared() < EPS:
  _fail("boss_wave_warning_projection_degenerate")
  return
 # Cache only the already-validated current snapshot for this draw call.
 # The annotation is above the body; it is not world damage geometry.
 var at:Vector2=body[0]+Vector2(0,-94)
 var viewport:Rect2=view.get_viewport_rect()
 at.x=clampf(at.x,viewport.position.x+38,viewport.end.x-38)
 at.y=maxf(at.y,viewport.position.y+19)
 _warning_badges.append({"at":at,"facing":screen_direction.normalized(),"progress":progress,"identity":_identity(cast)})
 receipt.warnings.append({"kind":"boss_b_locked_warning", "identity":_identity(cast), "geometry":geometry.duplicate(true), "warning_progress":progress, "world_edges":world_edges, "projected_edges":screen_edges, "world_cap":cap_world, "projected_cap":Array(cap), "filled_damage_region":false})

func _draw_front(view: Node2D, cast: Dictionary) -> void:
 var geometry: Dictionary = cast.geometry
 var origin: Vector3 = geometry.origin
 var forward: Vector3 = geometry.direction
 var side := Vector3(-forward.z, 0.0, forward.x)
 var distance: float = float(cast.distance)
 var half: float = float(geometry.width) * 0.5
 var front: Vector3 = cast.front_position
 var endpoints: Array = [front - side * half, front + side * half]
 var projected: PackedVector2Array = _project(view, endpoints)
 if projected.size() != 2:
  return
 var depth: float = minf(0.24, distance)
 var polygons: Array = []
 if depth > EPS:
  # Filled polygons have no centered outline extending ahead of the collision.
  # Every world vertex is inside the real width and at/before actual distance.
  polygons.append(_plate(view, origin, forward, side, distance - depth, distance, -half, half, INK))
  polygons.append(_plate(view, origin, forward, side, maxf(0.0, distance - 0.17), maxf(0.0, distance - 0.015), -half + 0.055, half - 0.055, FRONT))
  polygons.append(_plate(view, origin, forward, side, maxf(0.0, distance - 0.065), distance, -half + 0.09, half - 0.09, FRONT_LIGHT))
  # Short, angular trailing teeth retain the cartoon/graffiti silhouette.
  for index: int in range(4):
   var lateral: float = lerpf(-half + 0.17, half - 0.17, float(index) / 3.0)
   var tip: Vector3 = origin + forward * maxf(0.0, distance - 0.36) + side * lateral
   var base: Vector3 = origin + forward * maxf(0.0, distance - 0.16) + side * lateral
   if base.distance_squared_to(tip) <= EPS:
    continue
   var triangle: Array = [base - side * 0.10, base + side * 0.10, tip]
   var pixels: PackedVector2Array = _project(view, triangle)
   if pixels.size() != 3:
    return
   view.draw_colored_polygon(pixels, FRONT)
   polygons.append(triangle)
 receipt.fronts.append({"kind":"boss_b_actual_front", "identity":_identity(cast), "geometry":geometry.duplicate(true), "distance":distance, "front_position":front, "world_endpoints":endpoints, "projected_endpoints":Array(projected), "world_polygons":polygons, "future_path_rendered":false, "extrapolated":false, "leading_distance":distance, "damage_authority":false})

func _plate(view: Node2D, origin: Vector3, forward: Vector3, side: Vector3, start: float, finish: float, left: float, right: float, color: Color) -> Array:
 var world: Array = [origin + forward * start + side * left, origin + forward * finish + side * left, origin + forward * finish + side * right, origin + forward * start + side * right]
 var points: PackedVector2Array = _project(view, world)
 if points.size() == 4 and finish - start > EPS:
  view.draw_colored_polygon(points, color)
 return world

func _identity(cast: Dictionary) -> Dictionary:
 var result: Dictionary = {}
 for key: String in ["boss_cast_id", "run_id", "source_instance_id", "hero_instance_id", "generation", "room_id", "actor_id", "target_actor_id"]:
  result[key] = cast[key]
 return result

func _project(view: Node2D, world: Array) -> PackedVector2Array:
 var result := PackedVector2Array()
 for point: Vector3 in world:
  var pixel: Vector2 = view.p(point)
  if not pixel.is_finite():
   _fail("boss_wave_projection_nonfinite")
   return PackedVector2Array()
  result.append(pixel)
 return result

func _point(value: Variant) -> bool:
 return value is Vector3 and value.is_finite()

func _direction(value: Variant) -> bool:
 return _point(value) and absf(value.y) <= EPS and absf(value.length_squared() - 1.0) <= 0.0001

func _number(value: Variant, low: float, high: float) -> bool:
 return (value is int or value is float) and is_finite(float(value)) and float(value) >= low - EPS and float(value) <= high + EPS

func _fail(reason: String) -> bool:
 if error.is_empty():
  error = reason
 return false

func draw_foreground(view:Node2D)->void:
 receipt["warning_badges"]=[]
 if not error.is_empty():return
 for badge:Dictionary in _warning_badges:
  var at:Vector2=badge.at;var facing:Vector2=badge.facing
  var normal:=Vector2(-facing.y,facing.x)
  view.draw_circle(at,16.5,INK)
  view.draw_arc(at,14.0,0.0,TAU,32,Color("65404d"),3.0,true)
  if float(badge.progress)>EPS:view.draw_arc(at,14.0,-PI*.5,-PI*.5+TAU*float(badge.progress),32,WARNING_EDGE,3.0,true)
  view.draw_line(at+facing*18,at+facing*27,INK,5,true)
  view.draw_line(at+facing*18,at+facing*27,WARNING_ACCENT,2.5,true)
  for sign_value:float in [-1.0,1.0]:
   view.draw_line(at+facing*27,at+facing*22+normal*sign_value*4,INK,5,true)
   view.draw_line(at+facing*27,at+facing*22+normal*sign_value*4,WARNING_ACCENT,2.5,true)
  receipt.warning_badges.append(badge.duplicate(true))
