extends RefCounted
## Front geometry derived from native06. No time or source mutation.
var front_leg_override: ArrayMesh=null
var front_pelvis_offset: Vector3=Vector3.ZERO
var textures: Dictionary = {}
var world_height: float = 1.8
var minimum_area: float = INF
var release_origin_fraction: float = 1.0

func smooth(t: float) -> float:
 t = clampf(t,0.0,1.0)
 return t*t*(3.0-2.0*t)

func interpolate_pose(a: Dictionary,b: Dictionary,t: float) -> Dictionary:
 t = smooth(t)
 return {"w":a.w.lerp(b.w,t),"angle":lerpf(a.angle,b.angle,t),"lean":lerpf(a.lean,b.lean,t)}

func pose(phase: String,p: float) -> Dictionary:
 var n: Dictionary = {"w":Vector2(92,310),"angle":0.0,"lean":0.0}
 var d: Dictionary = {"w":Vector2(94,195),"angle":-0.18,"lean":-0.3}
 var s: Dictionary = {"w":Vector2(115,325),"angle":-0.7,"lean":0.65}
 var f: Dictionary = {"w":Vector2(222,330),"angle":-1.05,"lean":0.4}
 if phase == "hold": return interpolate_pose(n,d,p)
 if phase == "basic":
  var strike: Dictionary = {"w":Vector2(145,322),"angle":-0.65,"lean":0.35}
  return interpolate_pose(n,strike,p/0.35) if p < 0.35 else interpolate_pose(strike,n,(p-0.35)/0.65)
 if phase == "draw":
  return interpolate_pose(n,d,p)
 if phase == "release":
  if p < 0.25: return interpolate_pose(interpolate_pose(n,d,release_origin_fraction),s,p/0.25)
  if p < 0.5: return interpolate_pose(s,f,(p-0.25)/0.25)
  return interpolate_pose(f,n,(p-0.5)/0.5)
 return n

func body_point(v: Vector2,p: Dictionary) -> Vector2:
 var h: Vector2 = (v-Vector2(205,240)).rotated(p.lean*0.065)+Vector2(205,240)+Vector2(20,12)*p.lean
 if v.y <= 240.0: return h
 var weight: float = 1.0-smooth((v.y-240.0)/90.0)
 var balance: float = smooth((v.x-230.0)/80.0)*smooth((v.y-225.0)/65.0)*(1.0-smooth((v.y-395.0)/60.0))
 return v+(h-v)*weight+Vector2(-18,10)*balance*p.lean

func sleeve_point(v: Vector2,p: Dictionary) -> Vector2:
 var src_s: Vector2 = Vector2(1435,150)
 var src_w: Vector2 = Vector2(1000,510)
 var axis: Vector2 = src_w-src_s
 var unit: Vector2 = axis.normalized()
 var rel: Vector2 = v-src_s
 var t: float = rel.dot(unit)/axis.length()
 var lateral: float = rel.dot(Vector2(-unit.y,unit.x))
 var shoulder: Vector2 = body_point(Vector2(135,240),p)
 var wrist: Vector2 = p.w
 var d: Vector2 = wrist-shoulder
 var length: float = d.length()
 var width: float = 0.18
 # Continuous outward/downward elbow volume when the wrist crosses the chest.
 # A shear perpendicular to the straight longitudinal axis keeps both endpoints fixed.
 var elbow: float = 30.0*smooth((wrist.x-125.0)/80.0)*sin(PI*clampf(t,0.0,1.0))
 var base: Vector2 = shoulder+d*t+Vector2(-d.y,d.x)/length*(lateral*width+elbow)
 var delta: float = wrapf(Vector2(-110,60).angle()+p.angle-d.angle(),-PI,PI)
 var relative: Vector2 = base-wrist
 return wrist+relative.rotated(delta*(1.0-smooth(relative.length()/(length*0.60))))

func leg_point(v: Vector2,t: float,moving: bool) -> Vector2:
 if not moving: return Vector2(210,324)+v-Vector2(350,20)
 var side: float = smooth((v.x-330.0)/40.0)
 var left: float = 14.0*sin(t)-6.0*maxf(0.0,cos(t))
 var right: float = 14.0*sin(t+PI)-6.0*maxf(0.0,cos(t+PI))
 return Vector2(210,324)+v-Vector2(350,20)+Vector2(0,smooth((v.y-70.0)/170.0)*lerpf(left,right,side))

func create_mesh(uv: PackedVector2Array, vertices: PackedVector2Array, indices: PackedInt32Array, texture: Texture2D) -> ArrayMesh:
 for v in vertices:
  if not v.is_finite(): return null
 for i in range(0,indices.size(),3):
  var a: Vector2 = vertices[indices[i]]
  var b: Vector2 = vertices[indices[i+1]]
  var c: Vector2 = vertices[indices[i+2]]
  var area: float = (b-a).cross(c-a)
  minimum_area = minf(minimum_area,area)
  if area <= 0.000001: return null
 var normalized: PackedVector2Array = PackedVector2Array()
 for v in uv: normalized.append(v/texture.get_size())
 var arrays: Array = []
 arrays.resize(Mesh.ARRAY_MAX)
 var world_vertices: PackedVector3Array = PackedVector3Array()
 for v in vertices: world_vertices.append(Vector3((v.x-210.0)*world_height/582.0,(612.0-v.y)*world_height/582.0,0.0)+front_pelvis_offset)
 arrays[Mesh.ARRAY_VERTEX] = world_vertices
 arrays[Mesh.ARRAY_TEX_UV] = normalized
 arrays[Mesh.ARRAY_INDEX] = indices
 var result: ArrayMesh = ArrayMesh.new()
 result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 return result

func grid(rect: Rect2,nx: int,ny: int,mapper: Callable,texture: Texture2D) -> ArrayMesh:
 var uv: PackedVector2Array = PackedVector2Array()
 var vertices: PackedVector2Array = PackedVector2Array()
 var indices: PackedInt32Array = PackedInt32Array()
 for j in range(ny+1):
  for i in range(nx+1):
   var v: Vector2 = rect.position+rect.size*Vector2(float(i)/nx,float(j)/ny)
   uv.append(v)
   vertices.append(mapper.call(v))
 for j in range(ny):
  for i in range(nx):
   var a: int = j*(nx+1)+i
   indices.append_array(PackedInt32Array([a,a+1,a+nx+2,a,a+nx+2,a+nx+1]))
 return create_mesh(uv,vertices,indices,texture)

func polygon(raw: PackedVector2Array,mapper: Callable,texture: Texture2D) -> ArrayMesh:
 var vertices: PackedVector2Array = PackedVector2Array()
 for v in raw: vertices.append(mapper.call(v))
 var indices: PackedInt32Array = Geometry2D.triangulate_polygon(raw)
 if indices.is_empty(): return null
 # Normalize source winding explicitly, retaining corresponding UVs.
 for i in range(0,indices.size(),3):
  if (raw[indices[i+1]]-raw[indices[i]]).cross(raw[indices[i+2]]-raw[indices[i]]) < 0:
   var temp: int = indices[i+1]
   indices[i+1] = indices[i+2]
   indices[i+2] = temp
 return create_mesh(raw,vertices,indices,texture)

func build(phase: String,progress: float,gait_phase: float,moving: bool) -> Dictionary:
 var p: Dictionary = pose(phase,progress)
 var body: ArrayMesh = grid(Rect2(11,240,348,270),20,20,func(v: Vector2) -> Vector2: return body_point(v,p),textures.upper)
 var head: ArrayMesh = grid(Rect2(11,29,348,211),1,1,func(v: Vector2) -> Vector2: return body_point(v,p),textures.upper)
 var sleeve: ArrayMesh = grid(Rect2(868,29,645,668),32,32,func(v: Vector2) -> Vector2: return sleeve_point(v,p),textures.parts)
 var hand_raw: PackedVector2Array = PackedVector2Array([Vector2(1612,0),Vector2(1860,0),Vector2(1860,210),Vector2(1910,250),Vector2(1885,300),Vector2(1850,350),Vector2(1870,724),Vector2(1612,724)])
 var hand: ArrayMesh = polygon(hand_raw,func(v: Vector2) -> Vector2: return p.w+(v-Vector2(1890,263)).rotated(p.angle)*0.31,textures.parts)
 var patch_outline: PackedVector2Array = PackedVector2Array([Vector2(130,275),Vector2(150,280),Vector2(152,326),Vector2(121,350),Vector2(127,313)])
 var patch_uv: PackedVector2Array = PackedVector2Array()
 for v in patch_outline: patch_uv.append(Vector2(390,225)+(v-Vector2(120,270))*Vector2(130.0/35.0,230.0/85.0))
 var patch: ArrayMesh = polygon(patch_uv,func(v: Vector2) -> Vector2: return body_point(Vector2(120,270)+(v-Vector2(390,225))*Vector2(35.0/130.0,85.0/230.0),p),textures.parts)
 var legs: ArrayMesh = front_leg_override if front_leg_override!=null else grid(Rect2(224,0,256,320),28,28,func(v: Vector2) -> Vector2: return leg_point(v,gait_phase,moving),textures.lower)
 if body == null or head == null or sleeve == null or hand == null or patch == null or legs == null:
  return {}
 return {"body":body,"head":head,"sleeve_back":sleeve,"sleeve_front":sleeve,"patch":patch,"hand":hand,"legs":legs}
