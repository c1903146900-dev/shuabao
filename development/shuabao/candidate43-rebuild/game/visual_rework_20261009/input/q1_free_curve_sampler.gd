extends RefCounted
## Geometry only. The production Sim owns validation, time, freezing and release.
static func sample(source:Array, point:Vector3, length_cap:float)->Dictionary:
 var path:Array=source.duplicate(true)
 if path.is_empty() or not point.is_finite():return {"path":path,"changed":false,"at_limit":false}
 # The production gesture starts [A,A]; remove only that zero-length sentinel.
 if path.size()==2 and Vector3(path[0]).distance_squared_to(path[1])<0.00000001:path.pop_back()
 var used:float=0.0
 for i in range(1,path.size()):used+=Vector3(path[i-1]).distance_to(path[i])
 var remaining:float=maxf(0.0,length_cap-used)
 if remaining<=0.000001:return {"path":path,"changed":false,"at_limit":true}
 var motion:Vector3=point-Vector3(path.back())
 var distance:float=motion.length()
 if distance<=0.000001:return {"path":path,"changed":false,"at_limit":false}
 path.append(Vector3(path.back())+motion*(minf(distance,remaining)/distance))
 return {"path":path,"changed":true,"at_limit":distance>=remaining,"arc_length":used+minf(distance,remaining)}
