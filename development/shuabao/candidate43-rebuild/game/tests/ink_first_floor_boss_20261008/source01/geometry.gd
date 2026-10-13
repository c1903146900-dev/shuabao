extends RefCounted
## The warning publishes these physical shapes; hit tests consume the SAME shape.
## Hero radius expands collision, never the rendered physical weapon/stone/front.
const EPS := 0.000001
const HERO_RADIUS := 0.65

static func segment_distance(point: Vector3, a: Vector3, b: Vector3) -> float:
 var delta: Vector3 = b-a
 return point.distance_to(a+delta*clampf((point-a).dot(delta)/maxf(EPS,delta.length_squared()),0.0,1.0))

static func cone_contains(shape: Dictionary, point: Vector3, body_radius: float = HERO_RADIUS) -> bool:
 var offset: Vector3 = point-Vector3(shape.origin)
 var reach: float = float(shape.radius)
 var direction: Vector3 = shape.direction
 var half_angle: float = deg_to_rad(float(shape.angle)*0.5)
 var distance: float = offset.length()
 if distance <= body_radius: return true
 var cosine: float = offset.normalized().dot(direction)
 if cosine >= cos(half_angle): return distance <= reach+body_radius
 var left: Vector3 = Vector3(shape.origin)+direction.rotated(Vector3.UP,half_angle)*reach
 var right: Vector3 = Vector3(shape.origin)+direction.rotated(Vector3.UP,-half_angle)*reach
 return minf(segment_distance(point,shape.origin,left),segment_distance(point,shape.origin,right)) <= body_radius

static func front_contains(line: Dictionary, start: float, finish: float, point: Vector3, width: float = 1.6, body_radius: float = HERO_RADIUS) -> bool:
 # Swept, zero-depth front is a rectangle; the target circle gives rounded corners.
 var offset: Vector3 = point-Vector3(line.origin)
 var direction: Vector3 = line.direction
 var along: float = offset.dot(direction)
 var lateral: float = offset.dot(Vector3(-direction.z,0.0,direction.x))
 var dx: float = along-clampf(along,start,finish)
 var dz: float = lateral-clampf(lateral,-width*0.5,width*0.5)
 return dx*dx+dz*dz <= body_radius*body_radius+EPS

static func contains(shape: Dictionary, point: Vector3, body_radius: float = HERO_RADIUS) -> bool:
 match str(shape.shape):
  "cone": return cone_contains(shape,point,body_radius)
  "fronts":
   for line: Dictionary in shape.lines:
    if front_contains(line,0.0,float(line.length),point,float(shape.width),body_radius): return true
  "discs":
   for center: Vector3 in shape.points:
    if point.distance_to(center) <= float(shape.radius)+body_radius: return true
 return false
