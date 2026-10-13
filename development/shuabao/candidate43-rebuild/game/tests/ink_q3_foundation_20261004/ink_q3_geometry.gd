extends RefCounted
## Exact XZ circle versus oriented rectangle, including rounded corner sweeps.
## No actor, damage, cooldown, engine loop, or targeting policy lives here.
const Base=preload("res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_geometry.gd")
const EPS:float=0.0000001
static func local_point(at:Vector3,center:Vector3,axis:Vector3)->Vector2:
 var offset:Vector3=Base.ground(at-center)
 return Vector2(offset.dot(axis),offset.dot(Vector3(-axis.z,0.0,axis.x)))
static func overlaps(at:Vector3,radius:float,center:Vector3,axis:Vector3,length:float,width:float)->bool:
 var point:Vector2=local_point(at,center,axis)
 var distance:Vector2=Vector2(maxf(0.0,absf(point.x)-length*.5),maxf(0.0,absf(point.y)-width*.5))
 return distance.length_squared()<=maxf(0.0,radius)*maxf(0.0,radius)+EPS
static func entry(origin:Vector3,destination:Vector3,radius:float,center:Vector3,axis:Vector3,length:float,width:float)->float:
 var point:Vector2=local_point(origin,center,axis)
 var velocity:Vector2=local_point(destination,center,axis)-point
 var half:Vector2=Vector2(maxf(0.0,length)*.5,maxf(0.0,width)*.5)
 var r:float=maxf(0.0,radius)
 # Minkowski sum = two expanded strips and four corner discs. Unlike an
 # expanded AABB this does not fabricate square-corner circle contacts.
 var result:float=Base._box_entry(point,velocity,Vector2(half.x+r,half.y))
 result=minf(result,Base._box_entry(point,velocity,Vector2(half.x,half.y+r)))
 for sx in [-1.0,1.0]:
  for sy in [-1.0,1.0]:result=minf(result,Base._circle_entry(point,velocity,Vector2(sx*half.x,sy*half.y),r))
 return result
static func penetration(at:Vector3,radius:float,center:Vector3,axis:Vector3,length:float,width:float)->float:
 var point:Vector2=local_point(at,center,axis).abs()
 var half:Vector2=Vector2(length*.5,width*.5)
 var outer:Vector2=Vector2(maxf(0.0,point.x-half.x),maxf(0.0,point.y-half.y))
 if outer.length_squared()>EPS*EPS:return maxf(0.0,radius-outer.length())
 return minf(half.x-point.x,half.y-point.y)+radius
static func escaping_overlap(origin:Vector3,destination:Vector3,center:Vector3,axis:Vector3,length:float,width:float)->bool:
 var point:Vector2=local_point(origin,center,axis)
 var velocity:Vector2=local_point(destination,center,axis)-point
 var half:Vector2=Vector2(length*.5,width*.5)
 var closest:Vector2=Vector2(clampf(point.x,-half.x,half.x),clampf(point.y,-half.y,half.y))
 var outer:Vector2=point-closest
 if outer.length_squared()>EPS*EPS:return outer.dot(velocity)>EPS
 var depth:Vector2=half-point.abs()
 var minimum:float=minf(depth.x,depth.y)
 for i in range(2):
  if depth[i]>minimum+EPS:continue
  if absf(point[i])<=EPS:
   if absf(velocity[i])>EPS:return true
  elif signf(point[i])*velocity[i]>EPS:return true
 return false
