extends RefCounted
## Startup-only deformation. Only selected packed vertex records change.
const FAMILY: Array[String] = ["neck","head","hair_1","hair_2"]

static func apply(copy: ArrayMesh, skin: Skin, rig: Skeleton3D) -> Dictionary:
 if copy.get_blend_shape_count()!=0 or copy.custom_aabb!=AABB(): return {"ok":false,"reason":"unsupported_blend_or_custom_bounds"}
 var names: Array[String]=[]
 var neck: int=-1
 var head: int=-1
 for i in range(skin.get_bind_count()):
  var name: String=str(skin.get_bind_name(i))
  if name.is_empty():
   var bone: int=skin.get_bind_bone(i)
   if bone<0 or bone>=rig.get_bone_count(): return {"ok":false,"reason":"invalid_original_bind"}
   name=rig.get_bone_name(bone)
  if rig.find_bone(name)<0: return {"ok":false,"reason":"unresolved_named_bind"}
  names.append(name)
  if name=="neck": neck=i
  if name=="head": head=i
 if neck<0 or head<0: return {"ok":false,"reason":"neck_head_bind_missing"}
 var anchor: Vector3=skin.get_bind_pose(neck).affine_inverse().origin
 var head_origin: Vector3=skin.get_bind_pose(head).affine_inverse().origin
 var ramp: float=head_origin.y-anchor.y
 if not anchor.is_finite() or not head_origin.is_finite() or ramp<0.05 or ramp>0.3: return {"ok":false,"reason":"unexpected_bind_space"}
 var before: Array=copy.get("_surfaces")
 var changed: Array=before.duplicate(true)
 var evidence: Array=[]
 var selections: Array=[]
 var original_arrays: Array=[]
 var selected_total: int=0
 for si in range(copy.get_surface_count()):
  var arrays: Array=copy.surface_get_arrays(si)
  original_arrays.append(arrays)
  var positions: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var count: int=positions.size()
  var format: int=copy.surface_get_format(si)
  # Exact native19 layout, verified from imported scene. Unknown layouts fail closed.
  if format!=34359745559: return {"ok":false,"reason":"unreviewed_surface_format"}
  if (format & Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)!=0 or (format & Mesh.ARRAY_FLAG_USE_2D_VERTICES)!=0: return {"ok":false,"reason":"unsupported_compressed_or_2d_format"}
  var vs: int=RenderingServer.mesh_surface_get_format_vertex_stride(format,count)
  var ns: int=RenderingServer.mesh_surface_get_format_normal_tangent_stride(format,count)
  var vo: int=RenderingServer.mesh_surface_get_format_offset(format,count,Mesh.ARRAY_VERTEX)
  var no: int=RenderingServer.mesh_surface_get_format_offset(format,count,Mesh.ARRAY_NORMAL)
  if vs!=12 or ns!=8 or vo!=0 or no!=count*12: return {"ok":false,"reason":"unexpected_vertex_layout"}
  var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
  var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
  if count==0 or bones.size()!=count*4 or weights.size()!=count*4: return {"ok":false,"reason":"unexpected_influence_count"}
  var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL].duplicate()
  var tangents: PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT].duplicate()
  var moved: PackedVector3Array=positions.duplicate()
  var selected: PackedInt32Array=[]
  for vi in range(count):
   var family_weight: float=0.0
   var total_weight: float=0.0
   for wi in range(4):
    var bind: int=bones[vi*4+wi]
    if weights[vi*4+wi]<=0.0: continue
    if bind<0 or bind>=names.size(): return {"ok":false,"reason":"skin_index_out_of_range"}
    total_weight+=weights[vi*4+wi]
    if names[bind] in FAMILY: family_weight+=weights[vi*4+wi]
   if total_weight<=0.0: return {"ok":false,"reason":"zero_skin_weight"}
   # Normalize the selection mask only, never the stored weights.
   family_weight/=total_weight
   var p: Vector3=positions[vi]
   var t: float=clampf((p.y-anchor.y)/ramp,0.0,1.0)
   var smooth: float=t*t*(3.0-2.0*t)
   var amount: float=family_weight*smooth
   if amount<=0.0: continue
   # Native source family totals are exactly zero/one; reject unknown mixed boundary.
   if absf(family_weight-1.0)>0.00001: return {"ok":false,"reason":"unreviewed_mixed_family_boundary"}
   var d: Vector3=p-anchor
   var sx: float=1.0+0.25*amount
   var sy: float=1.0+0.10*amount
   var slope: float=family_weight*6.0*t*(1.0-t)/ramp if t>0.0 and t<1.0 else 0.0
   var jac:=Basis(Vector3(sx,0,0),Vector3(0.25*d.x*slope,sy+0.10*d.y*slope,0.25*d.z*slope),Vector3(0,0,sx))
   moved[vi]=anchor+Vector3(d.x*sx,d.y*sy,d.z*sx)
   normals[vi]=(jac.inverse().transposed()*normals[vi]).normalized()
   var tangent:=Vector3(tangents[vi*4],tangents[vi*4+1],tangents[vi*4+2])
   tangent=jac*tangent
   tangent=(tangent-normals[vi]*normals[vi].dot(tangent)).normalized()
   tangents[vi*4]=tangent.x
   tangents[vi*4+1]=tangent.y
   tangents[vi*4+2]=tangent.z
   selected.append(vi)
  selections.append(selected)
  selected_total+=selected.size()
  if selected.is_empty():
   evidence.append({"surface":si,"selected":0,"raw_storage_unchanged":true})
   continue
  var encode_arrays: Array=arrays.duplicate(true)
  encode_arrays[Mesh.ARRAY_VERTEX]=moved
  encode_arrays[Mesh.ARRAY_NORMAL]=normals
  encode_arrays[Mesh.ARRAY_TANGENT]=tangents
  var encoder:=ArrayMesh.new()
  encoder.add_surface_from_arrays(copy.surface_get_primitive_type(si),encode_arrays,[],{},format)
  if encoder.get_surface_count()!=1 or encoder.surface_get_format(0)!=format: return {"ok":false,"reason":"encoding_format_changed"}
  var encoded: Array=encoder.get("_surfaces")
  var raw: PackedByteArray=changed[si].vertex_data.duplicate()
  var encoded_raw: PackedByteArray=encoded[0].vertex_data
  if raw.size()!=encoded_raw.size(): return {"ok":false,"reason":"encoded_buffer_size_changed"}
  for vi: int in selected:
   for k in range(vs): raw[vo+vi*vs+k]=encoded_raw[vo+vi*vs+k]
   for k in range(ns): raw[no+vi*ns+k]=encoded_raw[no+vi*ns+k]
  changed[si].vertex_data=raw
  changed[si].aabb=encoded[0].aabb
  if encoded[0].has("bone_aabbs"): changed[si].bone_aabbs=encoded[0].bone_aabbs
  evidence.append({"surface":si,"selected":selected.size(),"old_bounds":before[si].aabb,"new_bounds":changed[si].aabb,"raw_unselected_records_preserved":true,"lod_storage_preserved":true})
 # This verified 4.6.3 stored property rebuilds only this independent mesh RID.
 copy.set("_surfaces",changed)
 var actual: Array=copy.get("_surfaces")
 if actual.size()!=before.size(): return {"ok":false,"reason":"surface_count_changed"}
 for si in range(actual.size()):
  var old: Dictionary=before[si]
  var now: Dictionary=actual[si]
  if old.size()!=now.size(): return {"ok":false,"reason":"surface_fields_changed"}
  for key: Variant in old:
   if not now.has(key): return {"ok":false,"reason":"surface_field_missing"}
   if key in ["vertex_data","aabb","bone_aabbs"]: continue
   if key=="material":
    if old[key]!=now[key]: return {"ok":false,"reason":"material_changed"}
   elif var_to_bytes(old[key])!=var_to_bytes(now[key]): return {"ok":false,"reason":"invariant_packed_field_changed:"+str(key)}
  var old_arrays: Array=original_arrays[si]
  var new_arrays: Array=copy.surface_get_arrays(si)
  for ai in range(Mesh.ARRAY_MAX):
   if ai in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TANGENT]: continue
   if var_to_bytes(old_arrays[ai])!=var_to_bytes(new_arrays[ai]): return {"ok":false,"reason":"invariant_decoded_array_changed"}
  var chosen: Dictionary={}
  for vi: int in selections[si]: chosen[vi]=true
  var old_vertices: PackedVector3Array=old_arrays[Mesh.ARRAY_VERTEX]
  var new_vertices: PackedVector3Array=new_arrays[Mesh.ARRAY_VERTEX]
  var old_bytes: PackedByteArray=old.vertex_data
  var new_bytes: PackedByteArray=now.vertex_data
  for vi in range(old_vertices.size()):
   if chosen.has(vi): continue
   if old_vertices[vi]!=new_vertices[vi]: return {"ok":false,"reason":"unselected_position_changed"}
   for k in range(12):
    if old_bytes[vi*12+k]!=new_bytes[vi*12+k]: return {"ok":false,"reason":"unselected_position_bytes_changed"}
   for k in range(8):
    if old_bytes[old_vertices.size()*12+vi*8+k]!=new_bytes[old_vertices.size()*12+vi*8+k]: return {"ok":false,"reason":"unselected_normal_tangent_bytes_changed"}
 if selected_total>0: copy.shadow_mesh=null
 return {"ok":true,"selected_vertices":selected_total,"neck_anchor":anchor,"head_ramp_height":ramp,"scale_above_ramp":[1.25,1.10,1.25],"surfaces":evidence,"shadow_policy":"changed_mesh_uses_main_mesh_shadow_cast_unchanged","lod_indices_and_levels_byte_equal":true,"source_never_written":true}
