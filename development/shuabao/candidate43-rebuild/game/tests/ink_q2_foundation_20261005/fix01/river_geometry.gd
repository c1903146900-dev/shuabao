extends RefCounted
## Pure XZ capsule-union river geometry. No targeting or world state.
const Base = preload("res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_geometry.gd")
const EPS: float = 0.0000001
static func entry(origin: Vector3, destination: Vector3, radius: float, path: Array, width: float) -> float:
 var result: float = INF
 var r: float = maxf(0.0, width) * 0.5 + maxf(0.0, radius)
 for i in range(1, path.size()):
  var a: Vector3 = Base.ground(path[i - 1])
  var delta: Vector3 = Base.ground(Vector3(path[i]) - a)
  var length: float = delta.length()
  if length <= EPS: continue
  var axis: Vector3 = delta / length
  var side: Vector3 = Vector3(-axis.z, 0.0, axis.x)
  var relative: Vector3 = Base.ground(origin - a)
  var motion: Vector3 = Base.ground(destination - origin)
  var point: Vector2 = Vector2(relative.dot(axis), relative.dot(side))
  var velocity: Vector2 = Vector2(motion.dot(axis), motion.dot(side))
  var hit: float = Base._box_entry(point - Vector2(length * 0.5, 0.0), velocity, Vector2(length * 0.5, r))
  hit = minf(hit, Base._circle_entry(point, velocity, Vector2.ZERO, r))
  hit = minf(hit, Base._circle_entry(point, velocity, Vector2(length, 0.0), r))
  result = minf(result, hit)
 return result
static func overlaps(at: Vector3, radius: float, path: Array, width: float) -> bool:
 return is_finite(entry(at, at, radius, path, width))

static func closest_point(at: Vector3, path: Array) -> Vector3:
 var best: Vector3 = path[0]
 var distance: float = INF
 for i in range(1, path.size()):
  var a: Vector3 = Base.ground(path[i - 1])
  var delta: Vector3 = Base.ground(Vector3(path[i]) - a)
  var u: float = clampf(Base.ground(at - a).dot(delta) / maxf(EPS * EPS, delta.length_squared()), 0.0, 1.0)
  var candidate: Vector3 = a + delta * u
  var squared: float = candidate.distance_squared_to(Base.ground(at))
  if squared < distance: best = candidate; distance = squared
 return best
