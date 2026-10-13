extends RefCounted
## No hero/game state; exact XZ finite-width front versus moving circle.
const EPS:float=0.0000001
static func ground(value:Vector3)->Vector3:return Vector3(value.x,0.0,value.z)
static func path_length(path:Array)->float:
 var total:float=0.0
 for i in range(1,path.size()):total+=Vector3(path[i-1]).distance_to(path[i])
 return total
static func frame_at(path:Array,distance:float)->Dictionary:
 var left:float=maxf(0.0,distance)
 var last_valid:Dictionary={}
 for i in range(1,path.size()):
  var start:Vector3=path[i-1]
  var delta:Vector3=Vector3(path[i])-start
  var length:float=delta.length()
  if length<=EPS:continue
  last_valid={"position":start+delta,"direction":delta/length,"segment_index":i-1}
  if left<length-EPS or i==path.size()-1:
   return {"position":start+delta/length*minf(left,length),"direction":delta/length,"segment_index":i-1}
  left-=length
 return last_valid if not last_valid.is_empty() else {"position":path.back() if not path.is_empty() else Vector3.ZERO,"direction":Vector3.FORWARD,"segment_index":0}
static func spans(path:Array,from_distance:float,to_distance:float)->Array:
 var result:Array=[]
 var cursor:float=0.0
 for i in range(1,path.size()):
  var length:float=Vector3(path[i-1]).distance_to(path[i])
  var begin:float=maxf(from_distance,cursor)
  var end:float=minf(to_distance,cursor+length)
  if length>EPS and end>=begin-EPS and to_distance>=cursor-EPS and from_distance<=cursor+length+EPS:
   var direction:Vector3=(Vector3(path[i])-Vector3(path[i-1]))/length
   result.append({"start":Vector3(path[i-1])+direction*clampf(begin-cursor,0.0,length),"end":Vector3(path[i-1])+direction*clampf(end-cursor,0.0,length),"direction":direction,"from":begin,"to":end,"segment_index":i-1})
  cursor+=length
 return result
static func _circle_entry(point:Vector2,velocity:Vector2,center:Vector2,radius:float)->float:
 var offset:Vector2=point-center
 var c:float=offset.length_squared()-radius*radius
 if c<=EPS:return 0.0
 var a:float=velocity.length_squared()
 if a<=EPS*EPS:return INF
 var b:float=2.0*offset.dot(velocity)
 var discriminant:float=b*b-4.0*a*c
 if discriminant<0.0:return INF
 var entry:float=(-b-sqrt(maxf(0.0,discriminant)))/(2.0*a)
 return clampf(entry,0.0,1.0) if entry>=-EPS and entry<=1.0+EPS else INF
static func _box_entry(point:Vector2,velocity:Vector2,half:Vector2)->float:
 var entry:float=0.0
 var leave:float=1.0
 for axis in range(2):
  if absf(velocity[axis])<=EPS:
   if absf(point[axis])>half[axis]+EPS:return INF
  else:
   var a:float=(-half[axis]-point[axis])/velocity[axis]
   var b:float=(half[axis]-point[axis])/velocity[axis]
   entry=maxf(entry,minf(a,b));leave=minf(leave,maxf(a,b))
   if entry>leave+EPS:return INF
 return clampf(entry,0.0,1.0) if leave>=-EPS and entry<=1.0+EPS else INF
static func moving_front_contact(front_a:Vector3,front_b:Vector3,direction:Vector3,width:float,target_a:Vector3,target_b:Vector3,radius:float)->float:
 var forward:Vector3=ground(direction).normalized()
 if forward.length_squared()<=EPS:return INF
 var side:Vector3=Vector3(-forward.z,0.0,forward.x)
 var relative:Vector3=ground(target_a-front_a)
 var motion:Vector3=ground((target_b-target_a)-(front_b-front_a))
 var point:Vector2=Vector2(relative.dot(forward),relative.dot(side))
 var velocity:Vector2=Vector2(motion.dot(forward),motion.dot(side))
 var half_width:float=maxf(0.0,width)*0.5
 var r:float=maxf(0.0,radius)
 # Rectangle plus two semicircular ends is the exact Minkowski sum.
 var entry:float=_box_entry(point,velocity,Vector2(r,half_width))
 entry=minf(entry,_circle_entry(point,velocity,Vector2(0.0,half_width),r))
 return minf(entry,_circle_entry(point,velocity,Vector2(0.0,-half_width),r))
