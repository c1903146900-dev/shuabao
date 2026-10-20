extends RefCounted
const Palette = preload("res://yan_skin_bake_20261020/cloth_palette.gdshader")
const BODY: Array[String]=["pelvis","spine","chest","skirt_front_L","skirt_front_R","skirt_back_L","skirt_back_R","sash_L","sash_R"]
const CLOTH: Array[String]=["pelvis","spine","chest","skirt_front_L","skirt_front_R","skirt_back_L","skirt_back_R","sash_L","sash_R","upper_arm_L","upper_arm_R","sleeve_L","sleeve_R","forearm_L","forearm_R"]
const PAINT_MESH: Array[int]=[0,1,2,6,8]

static func _root(parents: PackedInt32Array, i: int) -> int:
 while parents[i]!=i: i=parents[i]
 return i

static func classify(mesh: ArrayMesh, skin: Skin, rig: Skeleton3D, mesh_index: int) -> Dictionary:
 if mesh.get_surface_count()!=1: return {"ok":false,"reason":"expected_one_surface"}
 var arrays: Array=mesh.surface_get_arrays(0)
 var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
 var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
 if mesh.surface_get_format(0)!=34359745559 or vertices.is_empty() or indices.size()%3!=0 or bones.size()!=vertices.size()*4 or weights.size()!=bones.size(): return {"ok":false,"reason":"unsupported_original_layout"}
 var names: Array[String]=[]
 for i in range(skin.get_bind_count()):
  var name: String=str(skin.get_bind_name(i))
  if name.is_empty():
   var bone: int=skin.get_bind_bone(i)
   if bone<0 or bone>=rig.get_bone_count(): return {"ok":false,"reason":"invalid_bind"}
   name=rig.get_bone_name(bone)
  if rig.find_bone(name)<0: return {"ok":false,"reason":"invalid_named_bind"}
  names.append(name)
 var parents: PackedInt32Array=[]
 for i in range(vertices.size()): parents.append(i)
 for ti in range(0,indices.size(),3):
  for k in range(3):
   if indices[ti+k]<0 or indices[ti+k]>=vertices.size(): return {"ok":false,"reason":"index_out_of_range"}
  for k in [1,2]: parents[_root(parents,indices[ti+k])]=_root(parents,indices[ti])
 var components: Dictionary={}
 for vi in range(vertices.size()):
  var root: int=_root(parents,vi)
  if not components.has(root): components[root]={"vertices":[],"bones":{},"cloth":true,"body":true}
  components[root].vertices.append(vi)
  for wi in range(4):
   if weights[vi*4+wi]<=0.0: continue
   var bind: int=bones[vi*4+wi]
   if bind<0 or bind>=names.size(): return {"ok":false,"reason":"invalid_vertex_bind"}
   var name: String=names[bind]
   components[root].bones[name]=true
   if not name in CLOTH: components[root].cloth=false
   if not name in BODY: components[root].body=false
 var paint: PackedByteArray=[]
 var body: PackedByteArray=[]
 var colors: PackedColorArray=[]
 paint.resize(vertices.size());body.resize(vertices.size());colors.resize(vertices.size())
 var component_report: Array=[]
 for key: Variant in components:
  var component: Dictionary=components[key]
  var eligible: bool=bool(component.cloth) and mesh_index in PAINT_MESH
  var skirt: bool=false
  var sash: bool=false
  for name: String in component.bones:
   if name.begins_with("skirt_"): skirt=true
   if name.begins_with("sash_"): sash=true
  # Broad robe, inner-cloth and muted lining blocks; no texture noise on cloth.
  var color: Color=Color("28575b").srgb_to_linear()
  var role: String="deep_teal_robe"
  if mesh_index==1 or skirt:
   color=Color("e3dec9").srgb_to_linear();role="warm_ivory_inner_skirt"
  if sash:
   color=Color("527777").srgb_to_linear();role="muted_teal_sash"
  color.a=1.0
  for vi: int in component.vertices:
   colors[vi]=color if eligible else Color(0,0,0,0)
   paint[vi]=1 if eligible else 0
   body[vi]=1 if eligible and component.body else 0
  component_report.append({"vertices":component.vertices.size(),"bones":component.bones.keys(),"paint":eligible,"body":eligible and component.body,"role":role if eligible else "original_texture_preserved"})
 return {"ok":true,"paint":paint,"body":body,"colors":colors,"components":component_report}

static func deformation(p: Vector3) -> Dictionary:
 var t: float=clampf((p.y-0.35)/0.25,0.0,1.0)
 var u: float=clampf((1.67-p.y)/0.22,0.0,1.0)
 var a: float=t*t*(3.0-2.0*t)
 var b: float=u*u*(3.0-2.0*u)
 var da: float=6.0*t*(1.0-t)/0.25 if t>0.0 and t<1.0 else 0.0
 var db: float=-6.0*u*(1.0-u)/0.22 if u>0.0 and u<1.0 else 0.0
 var f: float=a*b
 var slope: float=da*b+a*db
 return {"position":Vector3(p.x*(1.0+0.12*f),p.y,p.z*(1.0+0.10*f)),"jacobian":Basis(Vector3(1.0+0.12*f,0,0),Vector3(0.12*p.x*slope,1,0.10*p.z*slope),Vector3(0,0,1.0+0.10*f)),"amount":f}

static func bake(mesh: ArrayMesh, mask: Dictionary, use_geometry: bool) -> Dictionary:
 var stored: Array=mesh.get("_surfaces")
 var before: Dictionary=stored[0]
 var arrays: Array=mesh.surface_get_arrays(0)
 var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var moved: PackedVector3Array=vertices.duplicate()
 var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL].duplicate()
 var tangents: PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT].duplicate()
 var paint_count: int=0
 var selected: PackedInt32Array=[]
 for vi in range(vertices.size()):
  paint_count+=int(mask.paint[vi])
  if not use_geometry or mask.body[vi]==0: continue
  var transformed: Dictionary=deformation(vertices[vi])
  if float(transformed.amount)<=0.0: continue
  selected.append(vi)
  var jac: Basis=transformed.jacobian
  moved[vi]=transformed.position
  normals[vi]=(jac.inverse().transposed()*normals[vi]).normalized()
  var tangent: Vector3=jac*Vector3(tangents[vi*4],tangents[vi*4+1],tangents[vi*4+2])
  tangent=(tangent-normals[vi]*normals[vi].dot(tangent)).normalized()
  tangents[vi*4]=tangent.x;tangents[vi*4+1]=tangent.y;tangents[vi*4+2]=tangent.z
 if paint_count==0 and selected.is_empty(): return {"ok":true,"painted":0,"body_moved":0,"unchanged_mesh":true}
 var format: int=mesh.surface_get_format(0) | Mesh.ARRAY_FORMAT_COLOR
 var encode: Array=arrays.duplicate(true)
 encode[Mesh.ARRAY_VERTEX]=moved;encode[Mesh.ARRAY_NORMAL]=normals;encode[Mesh.ARRAY_TANGENT]=tangents;encode[Mesh.ARRAY_COLOR]=mask.colors
 var temporary:=ArrayMesh.new()
 temporary.add_surface_from_arrays(mesh.surface_get_primitive_type(0),encode,[],{},format)
 if temporary.get_surface_count()!=1 or temporary.surface_get_format(0)!=format: return {"ok":false,"reason":"palette_encoder_format"}
 var encoded: Array=temporary.get("_surfaces")
 var final: Dictionary=before.duplicate(true)
 var vertex_bytes: PackedByteArray=before.vertex_data.duplicate()
 var encoded_vertices: PackedByteArray=encoded[0].vertex_data
 if vertex_bytes.size()!=encoded_vertices.size() or vertex_bytes.size()!=vertices.size()*20: return {"ok":false,"reason":"vertex_buffer_layout"}
 for vi: int in selected:
  for k in range(12): vertex_bytes[vi*12+k]=encoded_vertices[vi*12+k]
  for k in range(8): vertex_bytes[vertices.size()*12+vi*8+k]=encoded_vertices[vertices.size()*12+vi*8+k]
 var old_attributes: PackedByteArray=before.attribute_data
 var new_attributes: PackedByteArray=encoded[0].attribute_data.duplicate()
 if old_attributes.size()!=vertices.size()*8 or new_attributes.size()!=vertices.size()*12: return {"ok":false,"reason":"attribute_buffer_layout"}
 # Add COLOR, preserving original TEX_UV bytes verbatim at the new offset.
 for vi in range(vertices.size()):
  for k in range(8): new_attributes[vi*12+4+k]=old_attributes[vi*8+k]
 final.format=format;final.vertex_data=vertex_bytes;final.attribute_data=new_attributes
 if not selected.is_empty():
  final.aabb=encoded[0].aabb
  final.bone_aabbs=encoded[0].bone_aabbs
 var old_material: StandardMaterial3D=mesh.surface_get_material(0) as StandardMaterial3D
 if old_material==null or old_material.albedo_texture==null: return {"ok":false,"reason":"unsupported_original_material"}
 var contract: Dictionary=_material_contract(old_material)
 if not contract.ok: return contract
 var material:=ShaderMaterial.new()
 material.shader=Palette
 material.set_shader_parameter("source_albedo",old_material.albedo_texture)
 material.set_shader_parameter("source_tint",old_material.albedo_color)
 material.set_shader_parameter("source_roughness",old_material.roughness)
 material.set_shader_parameter("source_metallic",old_material.metallic)
 material.set_shader_parameter("source_specular",old_material.metallic_specular)
 final.material=material
 mesh.set("_surfaces",[final])
 if not selected.is_empty(): mesh.shadow_mesh=null
 var after: Array=mesh.get("_surfaces")
 var result_arrays: Array=mesh.surface_get_arrays(0)
 for key: Variant in before:
  if key in ["format","vertex_data","attribute_data","aabb","bone_aabbs","material"]: continue
  if not after[0].has(key) or var_to_bytes(before[key])!=var_to_bytes(after[0][key]): return {"ok":false,"reason":"invariant_stored_field:"+str(key)}
 for ai in range(Mesh.ARRAY_MAX):
  if ai in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TANGENT,Mesh.ARRAY_COLOR]: continue
  if var_to_bytes(arrays[ai])!=var_to_bytes(result_arrays[ai]): return {"ok":false,"reason":"invariant_decoded_array:"+str(ai)}
 var chosen: Dictionary={}
 for vi: int in selected: chosen[vi]=true
 var actual_bytes: PackedByteArray=after[0].vertex_data
 for vi in range(vertices.size()):
  if chosen.has(vi): continue
  for k in range(12):
   if actual_bytes[vi*12+k]!=before.vertex_data[vi*12+k]: return {"ok":false,"reason":"unselected_position_bytes"}
  for k in range(8):
   if actual_bytes[vertices.size()*12+vi*8+k]!=before.vertex_data[vertices.size()*12+vi*8+k]: return {"ok":false,"reason":"unselected_normal_tangent_bytes"}
 return {"ok":true,"painted":paint_count,"body_moved":selected.size(),"old_bounds":before.aabb,"new_bounds":after[0].aabb,"invariant_uv_skin_index_lods":true,"unselected_vertex_bytes_equal":true,"source_face_hand_pen_texture_preserved":true,"material_contract":contract}


static func _material_contract(material: StandardMaterial3D) -> Dictionary:
 # Fail closed on every stored rendering property beyond explicitly reproduced inputs.
 # Resource bookkeeping is not rendering state. No unknown material is approximated.
 var expected:=StandardMaterial3D.new()
 expected.cull_mode=BaseMaterial3D.CULL_DISABLED
 var reproduced: Array[String]=["albedo_texture","albedo_color","roughness","metallic","metallic_specular"]
 var actual: Dictionary={}
 var checked: int=0
 for info: Dictionary in material.get_property_list():
  if (int(info.usage)&PROPERTY_USAGE_STORAGE)==0: continue
  var key: String=str(info.name)
  if key.begins_with("resource_") or key.begins_with("metadata/"): continue
  actual[key]=str(material.get(key))
  if key in reproduced: continue
  checked+=1
  if material.get(key)!=expected.get(key):
   return {"ok":false,"reason":"unsupported_material_property:"+key,"actual":str(material.get(key)),"expected":str(expected.get(key))}
 return {"ok":true,"checked_default_properties":checked,"actual_stored_properties":actual,"opaque_alpha_ignored_as_in_source":true,"noncloth_rendering_equivalence":"contract_checked_not_pixel_verified"}
