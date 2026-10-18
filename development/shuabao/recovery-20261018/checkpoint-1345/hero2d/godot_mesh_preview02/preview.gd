extends Node2D
# Detached artwork phase replay. No Sim, damage, abilities, or game source is loaded.
const OLD_ARM = [Vector2(0,225),Vector2(95,225),Vector2(119,248),Vector2(140,280),Vector2(142,310),Vector2(120,350),Vector2(98,400),Vector2(86,485),Vector2(0,485)]
const RELEASE_SECONDS = 0.6000000238418579
const MAX_RAW_BYTES = 64 * 1024 * 1024
var textures: Dictionary = {}
var groups: Array = []
var rows: Array = []
var captures: Array = []
var raw_bytes: int = 0
var output_dir: String = ""
var output_created: bool = false
var start_usec: int = 0
var stopped: bool = false
var finishing: bool = false
var first_error: String = ""
var minimum_area: float = INF
var label: Label
var background: ColorRect
var body_shader: Shader
var sleeve_shader: Shader
var draw_serial: int = 0

func _ready() -> void:
 start_usec = Time.get_ticks_usec()
 get_tree().create_timer(15.0,true,false,true).timeout.connect(_hard_timeout,CONNECT_ONE_SHOT)
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):
   output_dir = arg.trim_prefix("--output=")
 if DisplayServer.get_name() == "headless" or not output_dir.is_absolute_path() or FileAccess.file_exists(output_dir) or DirAccess.dir_exists_absolute(output_dir):
  fail("normal_window_and_fresh_absolute_output_required")
  return
 if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
  fail("output_directory_failed")
  return
 output_created = true
 for key in ["upper", "lower", "parts"]:
  var path: String = {"upper":"upper_q1_eight_original.png", "lower":"lower_idle_walk_nine_original.png", "parts":"neutral_parts_original.png"}[key]
  var image: Image = Image.new()
  if image.load("res://" + path) != OK or image.is_empty():
   fail("asset_load_failed:" + key)
   return
  textures[key] = ImageTexture.create_from_image(image)
 background = ColorRect.new()
 background.size = Vector2(1100,700)
 background.color = Color("19232b")
 add_child(background)
 label = Label.new()
 label.position = Vector2(15,10)
 label.text = "Detached continuous mesh replay; shoulder art still unaccepted"
 add_child(label)
 body_shader = Shader.new()
 body_shader.code = """shader_type canvas_item;
uniform vec2 atlas_size;
uniform vec2 removed[9];
bool inside(vec2 p){bool yes=false;int j=8;for(int i=0;i<9;i++){vec2 a=removed[i];vec2 b=removed[j];if((a.y>p.y)!=(b.y>p.y)){if(p.x<(b.x-a.x)*(p.y-a.y)/(b.y-a.y)+a.x){yes=!yes;}}j=i;}return yes;}
void fragment(){vec2 raw=UV*atlas_size;if(inside(raw)){discard;}COLOR=texture(TEXTURE,UV);}
"""
 sleeve_shader = Shader.new()
 sleeve_shader.code = """shader_type canvas_item;
uniform vec2 atlas_size;
void fragment(){vec2 raw=UV*atlas_size;vec2 d=vec2(-435.0,360.0);float t=dot(raw-vec2(1435.0,150.0),d)/dot(d,d);if(t<0.30){discard;}COLOR=texture(TEXTURE,UV);}
"""
 for spec in [[Vector2(230,400),240.0,false],[Vector2(600,400),240.0,true],[Vector2(900,450),60.0,true]]:
  groups.append(make_group(spec[0],spec[1],spec[2]))
 await run_preview()

func _hard_timeout() -> void:
 # No coroutine/finalizer dependency, including if a script error interrupted finish.
 if first_error.is_empty(): first_error="internal_wall_deadline"
 stopped=true
 print("FRONT_MESH_PREVIEW accepted=false IO_OK=false reason=",first_error)
 get_tree().quit(4)

func _process(_delta: float) -> void:
 # Independent of the ready coroutine or a pending frame_post_draw signal.
 if start_usec > 0 and not finishing and not stopped and Time.get_ticks_usec()-start_usec > 15000000:
  fail("internal_wall_deadline")

func deadline_ok() -> bool:
 if Time.get_ticks_usec()-start_usec <= 15000000: return true
 if first_error.is_empty(): first_error="internal_wall_deadline"
 stopped=true
 return false

func make_mesh(parent: Node, texture: Texture2D, material: Material = null) -> MeshInstance2D:
 var node: MeshInstance2D = MeshInstance2D.new()
 node.texture = texture
 node.material = material
 parent.add_child(node)
 return node

func make_group(anchor: Vector2, height: float, moving: bool) -> Dictionary:
 var root: Node2D = Node2D.new()
 root.position = anchor - Vector2(210,324) * height / 582.0
 root.scale = Vector2.ONE * height / 582.0
 add_child(root)
 var body_material: ShaderMaterial = ShaderMaterial.new()
 body_material.shader = body_shader
 body_material.set_shader_parameter("atlas_size", textures.upper.get_size())
 body_material.set_shader_parameter("removed", PackedVector2Array(OLD_ARM))
 var distal_material: ShaderMaterial = ShaderMaterial.new()
 distal_material.shader = sleeve_shader
 distal_material.set_shader_parameter("atlas_size", textures.parts.get_size())
 var g: Dictionary = {"root":root,"moving":moving}
 g.legs = make_mesh(root,textures.lower)
 g.sleeve_back = make_mesh(root,textures.parts)
 g.patch = make_mesh(root,textures.parts)
 g.body = make_mesh(root,textures.upper,body_material)
 g.head = make_mesh(root,textures.upper,body_material)
 g.sleeve_front = make_mesh(root,textures.parts,distal_material)
 g.hand = make_mesh(root,textures.parts)
 return g

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
 if phase == "draw":
  return interpolate_pose(n,d,p)
 if phase == "release":
  if p < 0.25: return interpolate_pose(d,s,p/0.25)
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
 var shoulder: Vector2 = body_point(Vector2(145,245),p)
 var wrist: Vector2 = p.w
 var d: Vector2 = wrist-shoulder
 var length: float = d.length()
 var base: Vector2 = shoulder+d*t+Vector2(-d.y,d.x)/length*lateral*0.18
 var delta: float = wrapf(Vector2(-110,60).angle()+p.angle-d.angle(),-PI,PI)
 var relative: Vector2 = base-wrist
 return wrist+relative.rotated(delta*(1.0-smooth(relative.length()/length)))

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
 arrays[Mesh.ARRAY_VERTEX] = vertices
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

func present(phase: String,progress: float,motion_time: float) -> bool:
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
 var legs: Array = []
 for g in groups:
  legs.append(grid(Rect2(224,0,256,320),28,28,func(v: Vector2) -> Vector2: return leg_point(v,motion_time*6.0,g.moving),textures.lower))
 if body == null or head == null or sleeve == null or hand == null or patch == null or legs.has(null):
  fail("mesh_geometry_invalid")
  return false
 for i in range(groups.size()):
  var g: Dictionary = groups[i]
  g.body.mesh=body; g.head.mesh=head; g.sleeve_back.mesh=sleeve; g.sleeve_front.mesh=sleeve; g.patch.mesh=patch; g.hand.mesh=hand; g.legs.mesh=legs[i]
 label.text = "Detached mesh replay | %s %.3f | no Sim | shoulder art unaccepted" % [phase,progress]
 return true

func next_draw(phase: String,progress: float,motion_time: float) -> bool:
 if stopped: return false
 if Time.get_ticks_usec()-start_usec > 15000000:
  fail("internal_wall_deadline")
  return false
 if not present(phase,progress,motion_time): return false
 await RenderingServer.frame_post_draw
 if not deadline_ok():
  call_deferred("finish")
  return false
 if stopped: return false
 draw_serial += 1
 rows.append({"serial":draw_serial,"process":Engine.get_process_frames(),"frames_drawn":Engine.get_frames_drawn(),"phase":phase,"progress":progress,"replay_seconds":motion_time,"minimum_triangle_area":minimum_area})
 if rows.size() > 1600:
  fail("trace_capacity")
  return false
 return true

func capture(name: String) -> bool:
 var image: Image = get_viewport().get_texture().get_image()
 if image == null or image.is_empty():
  fail("viewport_readback_failed")
  return false
 raw_bytes += image.get_data_size()
 if raw_bytes > MAX_RAW_BYTES:
  fail("raw_image_budget")
  return false
 captures.append({"name":name,"image":image,"serial":draw_serial})
 return true

func run_preview() -> void:
 var samples: Array = [["idle",0.0],["draw",1.0],["release",0.25],["release",0.5],["release",0.75],["release",1.0]]
 for i in range(samples.size()):
  var sample: Array = samples[i]
  background.color = Color("f9f9f9") if i == 4 else Color("19232b")
  for k in range(3):
   if not await next_draw(sample[0],sample[1],float(i)*0.2): return
  if not capture("key_%02d"%i): return
 background.color = Color("19232b")
 var replay_start: int = Time.get_ticks_usec()
 var next_capture: float = 0.6
 while not stopped:
  var t: float = float(Time.get_ticks_usec()-replay_start)/1000000.0
  if t >= 7.6: break
  var cycle: float = fmod(t,3.8)
  var phase: String = "idle"
  var progress: float = 0.0
  if cycle >= 0.7 and cycle < 1.5:
   phase="draw"; progress=(cycle-0.7)/0.8
  elif cycle >= 1.5 and cycle < 2.0:
   phase="draw"; progress=1.0
  elif cycle >= 2.0 and cycle < 2.0+RELEASE_SECONDS:
   phase="release"; progress=(cycle-2.0)/RELEASE_SECONDS
  if not await next_draw(phase,progress,t): return
  if t >= next_capture and captures.size()<12:
   if not capture("replay_%02d"%captures.size()): return
   next_capture += 1.2
 finish()

func fail(reason: String) -> void:
 if stopped: return
 first_error=reason
 stopped=true
 call_deferred("finish")

func finish() -> void:
 if finishing: return
 finishing=true
 stopped=true
 deadline_ok()
 var io_ok: bool = output_created and DirAccess.dir_exists_absolute(output_dir)
 if io_ok:
  for item in captures:
   if not deadline_ok():
    io_ok=false
    break
   if item.image.save_png(output_dir.path_join(item.name+".png")) != OK: io_ok=false
   if not deadline_ok(): io_ok=false
 var report: Dictionary = {"accepted":first_error.is_empty() and io_ok,"scope":"detached_asset_mesh_preview_only","gameplay_or_art_acceptance":false,"failure":first_error,"draws":rows,"images":captures.size(),"raw_bytes":raw_bytes,"minimum_area":minimum_area if is_finite(minimum_area) else null,"backend":RenderingServer.get_current_rendering_method(),"elapsed_seconds":float(Time.get_ticks_usec()-start_usec)/1000000.0}
 var data: PackedByteArray = JSON.stringify(report,"  ").to_utf8_buffer()
 if io_ok and deadline_ok():
  var path: String = output_dir.path_join("report.json")
  var file: FileAccess = FileAccess.open(path,FileAccess.WRITE)
  if not deadline_ok(): io_ok=false
  if file == null: io_ok=false
  else:
   file.store_buffer(data)
   if not deadline_ok(): io_ok=false
   file.flush()
   if not deadline_ok(): io_ok=false
   if file.get_error()!=OK: io_ok=false
   file.close()
   if not deadline_ok(): io_ok=false
   if FileAccess.get_file_as_bytes(path)!=data: io_ok=false
   if not deadline_ok(): io_ok=false
 if not deadline_ok(): io_ok=false
 print("FRONT_MESH_PREVIEW accepted=",first_error.is_empty() and io_ok," IO_OK=",io_ok," reason=",first_error)
 get_tree().quit(0 if first_error.is_empty() and io_ok else 4)
