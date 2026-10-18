extends Node3D
## Direct world meshes: no SubViewport, independent clock, or depth override.
const Geometry = preload("geometry.gd")
const ORDER: Array[String] = ["legs","sleeve_back","patch","body","head","sleeve_front","hand"]
const OLD_ARM: Array[Vector2] = [Vector2(0,225),Vector2(95,225),Vector2(119,248),Vector2(140,280),Vector2(142,310),Vector2(120,350),Vector2(98,400),Vector2(86,485),Vector2(0,485)]
var geometry = Geometry.new()
var layers_by_name: Dictionary = {}
var ready_assets: bool = false
var receipt: Dictionary = {}

func initialize(asset_paths: Dictionary, height: float) -> bool:
 if ready_assets or not is_finite(height) or height <= 0.0: return false
 visible = false
 geometry.world_height = height
 for key: String in ["upper","lower","parts"]:
  if not asset_paths.has(key): return false
  var image: Image = Image.new()
  if image.load(str(asset_paths[key])) != OK or image.is_empty(): return false
  geometry.textures[key] = ImageTexture.create_from_image(image)
 for i: int in range(ORDER.size()):
  var key: String = ORDER[i]
  var node: MeshInstance3D = MeshInstance3D.new()
  node.name = key
  node.position.z = float(i)*0.0005
  node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  var tex_key: String = "lower" if key == "legs" else ("upper" if key in ["body","head"] else "parts")
  node.material_override = _material(geometry.textures[tex_key],key)
  add_child(node)
  layers_by_name[key] = node
 ready_assets = true
 return true

func _material(texture: Texture2D, kind: String) -> ShaderMaterial:
 var shader: Shader = Shader.new()
 var mask: String = ""
 if kind in ["body","head"]:
  mask = "if(inside(UV*atlas_size)){discard;}"
 elif kind == "sleeve_front":
  mask = "vec2 d=vec2(-435.0,360.0);if(dot(UV*atlas_size-vec2(1435.0,150.0),d)/dot(d,d)<0.0){discard;}"
 shader.code = """shader_type spatial;
render_mode unshaded,cull_disabled,depth_prepass_alpha;
uniform sampler2D atlas : source_color,filter_linear;
uniform vec2 atlas_size;
uniform vec2 removed[9];
bool inside(vec2 p){bool yes=false;int j=8;for(int i=0;i<9;i++){vec2 a=removed[i];vec2 b=removed[j];if((a.y>p.y)!=(b.y>p.y)){if(p.x<(b.x-a.x)*(p.y-a.y)/(b.y-a.y)+a.x){yes=!yes;}}j=i;}return yes;}
void fragment(){MASK vec4 color=texture(atlas,UV);ALBEDO=color.rgb;ALPHA=color.a;}
""".replace("MASK",mask)
 var material: ShaderMaterial = ShaderMaterial.new()
 material.shader = shader
 material.set_shader_parameter("atlas",texture)
 material.set_shader_parameter("atlas_size",texture.get_size())
 material.set_shader_parameter("removed",PackedVector2Array(OLD_ARM))
 return material

func prepare(plan: Dictionary) -> Dictionary:
 if not ready_assets: return {}
 geometry.release_origin_fraction=float(plan.get("release_origin_fraction",1.0))
 var meshes: Dictionary = geometry.build(str(plan.phase),float(plan.progress),float(plan.gait_phase),bool(plan.moving))
 if meshes.size() != ORDER.size(): return {}
 for key: String in ORDER:
  if not is_instance_valid(layers_by_name.get(key)) or layers_by_name[key].get_parent() != self: return {}
 return meshes

func commit(meshes: Dictionary, at: Vector3, camera: Camera3D) -> bool:
 if not at.is_finite() or not is_instance_valid(camera) or not camera.global_transform.is_finite() or meshes.size() != ORDER.size(): return false
 for key: String in ORDER:
  if not meshes.get(key) is ArrayMesh or not is_instance_valid(layers_by_name.get(key)) or layers_by_name[key].get_parent() != self: return false
 global_transform = Transform3D(camera.global_basis.orthonormalized(),at)
 for key: String in ORDER: layers_by_name[key].mesh = meshes[key]
 receipt = {"accepted":true,"world_height":geometry.world_height,"minimum_area":geometry.minimum_area,"depth_test":true,"direct_world_mesh":true}
 return true

func hide_display() -> void:
 visible = false
