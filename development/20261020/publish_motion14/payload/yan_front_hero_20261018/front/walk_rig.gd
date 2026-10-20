extends RefCounted
## Front-only candidate. Real source skeleton input, original UV, fixed two-buffer meshes.
const Calibration=preload("walk_calibration.gd")
const ROW_COUNT: int=29
const COLUMN_COUNT: int=29
var pixels:=PackedVector2Array()
var indices:=PackedInt32Array()
var meshes: Array[ArrayMesh]=[]
var active_buffer: int=-1
var staged_buffer: int=-1
var active: bool=false
var activation_time: float=-1.0
var staged_activation_time: float=-1.0
var blend_alpha: float=0.0
const TRANSITION_SOURCE_SECONDS: float=0.24
var scale: float=0.0
var measured_candidate_checks: int=0
var receipt: Dictionary={"active":false,"reason":"await_actual_front_alignment"}

static func capture(actor: Node3D,camera: Camera3D,source_time: float) -> Dictionary:
 if not is_instance_valid(actor) or not is_instance_valid(camera) or camera.projection!=Camera3D.PROJECTION_ORTHOGONAL:return {}
 var skeleton: Skeleton3D=actor.get("skeleton") as Skeleton3D
 if not is_instance_valid(skeleton) or not actor.is_ancestor_of(skeleton):return {}
 var inverse: Basis=camera.global_basis.orthonormalized().inverse()
 var forward: Vector3=actor.global_basis.z
 forward.y=0.0
 var result: Dictionary={"source_time":source_time,"bones":{},"neutral":{},"aligned":forward.length()>0.000001 and forward.normalized().dot(Vector3.BACK)>0.9998}
 for name: String in Calibration.BONES:
  var index: int=skeleton.find_bone(name)
  if index<0:return {}
  var actual: Transform3D=skeleton.global_transform*skeleton.get_bone_global_pose(index)
  var origin: Vector3=inverse*(actual.origin-actor.global_position)
  var basis: Basis=inverse*actual.basis
  var reference: Transform3D=Calibration.BONES[name]
  if not actual.is_finite():return {}
  result.bones[name]=Transform3D(basis,origin)
  result.neutral[name]=Transform3D(inverse*reference.basis,inverse*reference.origin)
 return result

func initialize(texture: Texture2D,height: float) -> bool:
 if not meshes.is_empty() or texture==null or texture.get_size()!=Vector2(1536,1024):return false
 scale=height/582.0
 var uv:=PackedVector2Array()
 var initial:=PackedVector3Array()
 for row in range(ROW_COUNT):
  var y: float=320.0*float(row)/28.0
  for column in range(COLUMN_COUNT):
   var x: float=224.0+256.0*float(column)/28.0
   var pixel:=Vector2(x,y)
   pixels.append(pixel);uv.append(pixel/texture.get_size());initial.append(_rest(pixel))
 for row in range(ROW_COUNT-1):
  for column in range(28):
   var a: int=row*29+column
   indices.append_array(PackedInt32Array([a,a+1,a+30,a,a+30,a+29]))
 var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=initial;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices
 for unused in range(2):
  var mesh:=ArrayMesh.new()
  mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
  meshes.append(mesh)
 return true

func _rest(pixel: Vector2) -> Vector3:
 return Vector3((pixel.x-350.0)*scale,(308.0-pixel.y)*scale,0.0)

func _smooth(t: float) -> float:
 t=clampf(t,0.0,1.0)
 return t*t*(3.0-2.0*t)

func pelvis_delta(frame: Dictionary) -> Vector3:
 if frame.is_empty():return Vector3.ZERO
 return frame.bones.pelvis.origin-frame.neutral.pelvis.origin

func _limb_parameters(side: String,frame: Dictionary) -> Dictionary:
 var foot: Transform3D=frame.bones["foot_"+side]
 var old_foot: Transform3D=frame.neutral["foot_"+side]
 var dh: Vector3=frame.bones["thigh_"+side].origin-frame.neutral["thigh_"+side].origin
 var df: Vector3=foot.origin-old_foot.origin
 var dk: Vector3=frame.bones["shin_"+side].origin-frame.neutral["shin_"+side].origin
 var rotation: Basis=foot.basis*old_foot.basis.inverse()
 if blend_alpha<1.0:rotation=Basis(Quaternion.IDENTITY.slerp(rotation.get_rotation_quaternion(),blend_alpha))
 var phase: float=float(frame.gait_phase)+(PI if side=="R" else 0.0)
 var old_vertical: float=(14.0*sin(phase)-6.0*maxf(0.0,cos(phase))) if bool(frame.moving) else 0.0
 return {"dh":dh,"df":df,"knee":dk-dh.lerp(df,100.0/190.0),"rotation":rotation,"anchor":_rest(Vector2(286.0 if side=="L" else 414.0,245.0)),"old_vertical":old_vertical}

func _limb(pixel: Vector2,side: String,frame: Dictionary,weight: float) -> Vector3:
 var part: Dictionary=frame._limbs[side]
 var point: Vector3=_rest(pixel)
 var relative: Vector3=point-part.anchor
 var rotation_delta: Vector3=part.rotation*relative-relative
 var t: float=clampf((pixel.y-50.0)/190.0,0.0,1.0)
 var delta: Vector3=part.dh.lerp(part.df,t)+4.0*t*(1.0-t)*weight*part.knee
 var rotation_weight: float=_smooth((t-0.65)/0.35)
 if pixel.y>=240.0:
  delta=part.df;rotation_weight=1.0
 var old_delta: Vector3=Vector3(0,-float(part.old_vertical)*scale*_smooth((pixel.y-70.0)/170.0),0)
 return point+old_delta.lerp(delta,blend_alpha)+rotation_delta*rotation_weight

func prepare(frame: Dictionary) -> Dictionary:
 # Diagnostic wall-clock only; never used for animation, selection, or source time.
 measured_candidate_checks=0
 var started_usec: int=Time.get_ticks_usec()
 var result: Dictionary=_prepare_measured(frame)
 var elapsed_usec: int=Time.get_ticks_usec()-started_usec
 result["solver_elapsed_usec"]=elapsed_usec
 result["actual_candidate_checks"]=measured_candidate_checks
 result["timing_scope"]="front_walk_prepare_cpu_including_final_upload_call"
 receipt["solver_elapsed_usec"]=elapsed_usec
 receipt["actual_candidate_checks"]=measured_candidate_checks
 receipt["timing_scope"]="front_walk_prepare_cpu_including_final_upload_call"
 return result

func _prepare_measured(frame: Dictionary) -> Dictionary:
 staged_buffer=-1
 if not frame.has("bones") or not frame.has("neutral") or not frame.has("aligned"):return {"accepted":false,"reason":"front_bones_missing"}
 if not active and not bool(frame.aligned):
  receipt={"active":false,"reason":"await_actual_front_alignment","source_time":frame.source_time}
  return {"accepted":true,"active":false}
 if not bool(frame.aligned):return {"accepted":false,"reason":"front_turn_outside_candidate_domain"}
 staged_activation_time=float(frame.source_time) if activation_time<0.0 else activation_time
 if float(frame.source_time)<staged_activation_time:return {"accepted":false,"reason":"front_transition_clock_reversed"}
 blend_alpha=_smooth((float(frame.source_time)-staged_activation_time)/TRANSITION_SOURCE_SECONDS)
 frame["_limbs"]={"L":_limb_parameters("L",frame),"R":_limb_parameters("R",frame)}
 var selected: Dictionary=_evaluate(frame,0.0)
 if not bool(selected.get("accepted",false)):return selected
 var selected_weight: float=0.0
 var upper: Dictionary=_evaluate(frame,0.25)
 var candidate_checks: int=2
 if bool(upper.get("accepted",false)):
  selected=upper;selected_weight=0.25
 else:
  var low: float=0.0;var high: float=0.25
  for step in range(8):
   var middle: float=(low+high)*0.5
   var trial: Dictionary=_evaluate(frame,middle)
   candidate_checks+=1
   if bool(trial.get("accepted",false)):
    low=middle;selected=trial;selected_weight=middle
   else:high=middle
 var vertices: PackedVector3Array=selected.vertices
 var minimum_area: float=selected.minimum_area
 var minimum_width_ratio: float=selected.minimum_width_ratio
 var depth_offset: float=selected.depth_offset
 # Dynamic uploads do not recalculate ArrayMesh's culling bound.
 var actual_bounds:=AABB(vertices[0],Vector3.ZERO)
 for point: Vector3 in vertices:actual_bounds=actual_bounds.expand(point)
 var culling_bounds: AABB=actual_bounds.grow(0.00001)
 staged_buffer=0 if active_buffer!=0 else 1
 meshes[staged_buffer].custom_aabb=culling_bounds
 meshes[staged_buffer].surface_update_vertex_region(0,0,vertices.to_byte_array())
 receipt={"actual_bounds_position":[actual_bounds.position.x,actual_bounds.position.y,actual_bounds.position.z],"actual_bounds_size":[actual_bounds.size.x,actual_bounds.size.y,actual_bounds.size.z],"culling_bounds_margin":0.00001,"bounds_buffer":staged_buffer,"active":true,"transition_complete":blend_alpha>=1.0,"transition_alpha":blend_alpha,"transition_source_started":staged_activation_time,"source_time":frame.source_time,"minimum_area":minimum_area,"common_camera_depth_offset":depth_offset,"orthographic_projection_required":true,"minimum_width_ratio":minimum_width_ratio,"vertex_count":pixels.size(),"triangle_count":indices.size()/3,"fixed_screen_left":"foot_L","fixed_screen_right":"foot_R","shoe_rotation":"full_original_relative_basis","knee_intent_weight":selected_weight,"candidate_checks":candidate_checks,"selection_area_margin":0.00001,"scope":"FRONT_ALIGNED_CANDIDATE_ONLY","native_art_accepted":false}
 return {"accepted":true,"active":true,"mesh":meshes[staged_buffer]}

func _evaluate(frame: Dictionary,weight: float) -> Dictionary:
 measured_candidate_checks+=1
 var vertices:=PackedVector3Array()
 for pixel: Vector2 in pixels:
  var side_weight: float=_smooth((pixel.x-330.0)/40.0)
  var point: Vector3=_limb(pixel,"L",frame,weight).lerp(_limb(pixel,"R",frame,weight),side_weight)
  if pixel.y<50.0:point=(_rest(pixel)+pelvis_delta(frame)*blend_alpha).lerp(point,_smooth(pixel.y/50.0))
  if not point.is_finite():return {"accepted":false,"reason":"front_nonfinite_vertex"}
  vertices.append(point)
 var maximum_depth: float=-INF
 for point: Vector3 in vertices:maximum_depth=maxf(maximum_depth,point.z)
 var depth_offset: float=minf(0.0,pelvis_delta(frame).z*blend_alpha-maximum_depth-0.0005)
 for i in range(vertices.size()):vertices[i].z+=depth_offset
 var minimum_width_ratio: float=INF
 for row in range(ROW_COUNT):
  for pair: Vector2i in [Vector2i(0,11),Vector2i(16,28)]:
   var a: int=row*29+pair.x;var b: int=row*29+pair.y
   var width: float=Vector2(vertices[b].x-vertices[a].x,vertices[b].y-vertices[a].y).length()
   var ratio: float=width/((pixels[b].x-pixels[a].x)*scale)
   minimum_width_ratio=minf(minimum_width_ratio,ratio)
   if ratio<0.8:return {"accepted":false,"reason":"front_width_invalid","width_ratio":ratio}
 var minimum_area: float=INF
 for i in range(0,indices.size(),3):
  var a: Vector3=vertices[indices[i]];var b: Vector3=vertices[indices[i+1]];var c: Vector3=vertices[indices[i+2]]
  var area: float=-Vector2(b.x-a.x,b.y-a.y).cross(Vector2(c.x-a.x,c.y-a.y))
  minimum_area=minf(minimum_area,area)
  if area<=0.00001:return {"accepted":false,"reason":"front_triangle_invalid","triangle_offset":i,"area":area}
 var boundary: Array[int]=[]
 for column in range(29):boundary.append(column)
 for row in range(1,ROW_COUNT):boundary.append(row*29+28)
 for column in range(27,-1,-1):boundary.append((ROW_COUNT-1)*29+column)
 for row in range(ROW_COUNT-2,0,-1):boundary.append(row*29)
 for i in range(boundary.size()):
  for j in range(i+1,boundary.size()):
   if j==i+1 or (i==0 and j==boundary.size()-1):continue
   var av: Vector3=vertices[boundary[i]];var bv: Vector3=vertices[boundary[(i+1)%boundary.size()]]
   var cv: Vector3=vertices[boundary[j]];var dv: Vector3=vertices[boundary[(j+1)%boundary.size()]]
   if Geometry2D.segment_intersects_segment(Vector2(av.x,av.y),Vector2(bv.x,bv.y),Vector2(cv.x,cv.y),Vector2(dv.x,dv.y))!=null:
    return {"accepted":false,"reason":"front_boundary_self_intersection","edges":[i,j]}
 return {"accepted":true,"vertices":vertices,"minimum_area":minimum_area,"minimum_width_ratio":minimum_width_ratio,"depth_offset":depth_offset}

func committed() -> void:
 if staged_buffer>=0:
  active_buffer=staged_buffer;staged_buffer=-1;active=true;activation_time=staged_activation_time
