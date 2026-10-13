extends RefCounted
## Exact XZ circle/rectangle tests and continuous full-width sword-front clipping.
## Opt-in geometry: legacy rectangle users retain their previous query contract.
const EPS:float=0.0000001

static func circle_intersects(origin:Vector3,direction:Vector3,length:float,width:float,at:Vector3,radius:float,clipped_front:bool=false,forward_limit:float=INF)->bool:
 var forward:Vector3=direction.normalized()
 var offset:Vector3=at-origin
 var along:float=offset.dot(forward)
 if along>forward_limit+EPS or (clipped_front and along>length+EPS):return false
 var across:float=absf(offset.dot(Vector3(-forward.z,0,forward.x)))
 var dx:float=maxf(0.0,maxf(-along,along-maxf(0.0,length)))
 var dz:float=maxf(0.0,across-maxf(0.0,width)*.5)
 return dx*dx+dz*dz<=maxf(0.0,radius)*maxf(0.0,radius)+EPS

static func clip_front(origin:Vector3,direction:Vector3,distance:float,width:float,obstacles:Array,arena_half_extent:float)->Dictionary:
 var forward:Vector3=direction.normalized()
 var side:Vector3=Vector3(-forward.z,0,forward.x)
 var travel:Vector3=forward*maxf(0.0,distance)
 var half_width:float=maxf(0.0,width)*.5
 var fraction:float=1.0
 var blocked:bool=false
 var reason:String=""
 # Both ends of the actual front must stay in the arena, including diagonal fronts.
 for axis in [0,2]:
  var bound:float=maxf(0.0,arena_half_extent-absf(side[axis])*half_width)
  var entry:float=INF
  if absf(origin[axis])>bound+EPS:entry=0.0
  elif travel[axis]>EPS:entry=(bound-origin[axis])/travel[axis]
  elif travel[axis]<-EPS:entry=(-bound-origin[axis])/travel[axis]
  if entry>=-EPS and entry<=fraction+EPS:
   fraction=clampf(entry,0.0,1.0);blocked=true;reason="arena"
 for obstacle in obstacles:
  var entry:float=_moving_front_box(origin,travel,side,half_width,obstacle.position,obstacle.half)
  if entry>=-EPS and entry<=fraction+EPS:
   fraction=clampf(entry,0.0,1.0);blocked=true;reason="obstacle"
 # A microscopic separation keeps the recorded shape on the near face of cover.
 var actual:float=maxf(0.0,distance*fraction-(0.00001 if blocked else 0.0))
 return {"position":origin+forward*actual,"distance":actual,"blocked":blocked,"reason":reason}

static func _moving_front_box(origin:Vector3,travel:Vector3,side:Vector3,half_width:float,center:Vector3,half:Vector3)->float:
 # Continuous separating-axis test: moving line segment versus stationary AABB.
 # Unlike a center/edge-ray sample, this covers every point between the endpoints.
 var enter:float=0.0
 var leave:float=1.0
 var offset:Vector3=origin-center
 for axis in [Vector3.RIGHT,Vector3.BACK,Vector3(-side.z,0,side.x),side]:
  var radius:float=absf(axis.x)*half.x+absf(axis.z)*half.z+absf(axis.dot(side))*half_width
  var point:float=offset.dot(axis)
  var velocity:float=travel.dot(axis)
  if absf(velocity)<=EPS:
   if absf(point)>radius+EPS:return INF
   continue
  var a:float=(-radius-point)/velocity
  var b:float=(radius-point)/velocity
  enter=maxf(enter,minf(a,b));leave=minf(leave,maxf(a,b))
  if enter>leave+EPS:return INF
 return enter if leave>=0.0 and enter<=1.0 else INF
