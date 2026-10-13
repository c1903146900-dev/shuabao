extends RefCounted
## F9-only CPU skin reference bounds. No pose, root scale, camera, collider or sim writes.
## Projected geometry hull is NOT a visible pixel mask or an art acceptance verdict.
static func collect(actor: Node3D, camera: Camera3D, raster_size: Vector2i) -> Dictionary:
	var mesh_nodes: Array[MeshInstance3D]=[]
	_scan(actor,mesh_nodes)
	var world_min:=Vector3.INF
	var world_max:=-Vector3.INF
	var body_min:=Vector3.INF
	var body_max:=-Vector3.INF
	var pixels_min:=Vector2.INF
	var pixels_max:=-Vector2.INF
	var body_pixels_min:=Vector2.INF
	var body_pixels_max:=-Vector2.INF
	var vertex_count:=0
	var body_vertex_count:=0
	var errors: Array=[]
	var transforms: Array=[]
	var logical_size: Vector2=camera.get_viewport().get_visible_rect().size
	var ratio:=Vector2(float(raster_size.x)/logical_size.x,float(raster_size.y)/logical_size.y)
	for node: MeshInstance3D in mesh_nodes:
		transforms.append({"name":str(node.name),"local_scale":_v3(node.scale),"world_scale":_v3(node.global_basis.get_scale()),"world_origin":_v3(node.global_position)})
		var skeleton: Skeleton3D=node.get_node_or_null(node.skeleton) as Skeleton3D
		var skin: Skin=node.skin
		var bind_transforms: Array[Transform3D]=[]
		var bind_names: Array[String]=[]
		if skeleton!=null and skin!=null:
			skeleton.force_update_all_bone_transforms()
			for bind_index in range(skin.get_bind_count()):
				var bone_index:=skin.get_bind_bone(bind_index)
				if bone_index<0:bone_index=skeleton.find_bone(str(skin.get_bind_name(bind_index)))
				if bone_index<0 or bone_index>=skeleton.get_bone_count():
					errors.append("invalid_skin_bind:"+str(node.name)+":"+str(bind_index))
					bind_transforms.append(Transform3D.IDENTITY);bind_names.append("invalid")
				else:
					bind_transforms.append(skeleton.global_transform*skeleton.get_bone_global_pose(bone_index)*skin.get_bind_pose(bind_index))
					bind_names.append(str(skeleton.get_bone_name(bone_index)))
		for surface in range(node.mesh.get_surface_count()):
			var arrays:=node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var bones: Variant=arrays[Mesh.ARRAY_BONES]
			var weights: Variant=arrays[Mesh.ARRAY_WEIGHTS]
			var skinned: bool=bones!=null and weights!=null and skeleton!=null and skin!=null and not bind_transforms.is_empty()
			var influences: int=int(bones.size()/maxi(1,vertices.size())) if skinned else 0
			for vertex_index in range(vertices.size()):
				var world: Vector3=node.global_transform*vertices[vertex_index]
				var brush_weight:=0.0
				if skinned:
					world=Vector3.ZERO
					var total:=0.0
					for influence in range(influences):
						var index: int=vertex_index*influences+influence
						var weight: float=float(weights[index])
						var bind: int=int(bones[index])
						if weight<=0.0:continue
						if bind<0 or bind>=bind_transforms.size():errors.append("out_of_range_skin_index");continue
						world+=(bind_transforms[bind]*vertices[vertex_index])*weight
						total+=weight
						if bind_names[bind]=="brush":brush_weight+=weight
					if absf(total-1.0)>.0001:errors.append("skin_weight_sum_not_one")
				if not world.is_finite():errors.append("nonfinite_skinned_vertex");continue
				vertex_count+=1;world_min=world_min.min(world);world_max=world_max.max(world)
				var body: bool=brush_weight<.5
				if body:body_vertex_count+=1;body_min=body_min.min(world);body_max=body_max.max(world)
				if not camera.is_position_behind(world):
					var point: Vector2=camera.unproject_position(world)*ratio
					pixels_min=pixels_min.min(point);pixels_max=pixels_max.max(point)
					if body:body_pixels_min=body_pixels_min.min(point);body_pixels_max=body_pixels_max.max(point)
	var elevation:=rad_to_deg(asin(clampf(camera.global_basis.z.normalized().y,-1.0,1.0)))
	return {"status":"measured_geometry_reference_not_pixel_mask" if errors.is_empty() and body_vertex_count>0 else "HOLD_geometry_reference","errors":errors,"method":"actual imported vertices, skin bind matrices and current skeleton poses; brush-dominant vertices excluded from body hull","actor_local_scale":_v3(actor.scale),"actor_world_scale":_v3(actor.global_basis.get_scale()),"mesh_transforms":transforms,"vertex_count":vertex_count,"body_vertex_count":body_vertex_count,"world_bounds":_bounds(world_min,world_max),"body_world_bounds":_bounds(body_min,body_max),"projected_raster_bounds":_rect(pixels_min,pixels_max),"body_projected_raster_bounds":_rect(body_pixels_min,body_pixels_max),"logical_viewport":_v2(logical_size),"actual_raster_size":[raster_size.x,raster_size.y],"projection_scale_logical_to_raster":_v2(ratio),"camera_size":camera.size,"camera_elevation_degrees":elevation,"camera_position":_v3(camera.global_position),"body_height_artistic_trial_target_at_720h":[60,80],"actual_height_normalized_to_720":(body_pixels_max.y-body_pixels_min.y)*720.0/maxi(1,raster_size.y),"target_is_not_automatic_acceptance":true,"collider_speed_range_modified":false}
static func _scan(node: Node, meshes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and node.skin!=null:meshes.append(node)
	for child in node.get_children():_scan(child,meshes)
static func _v3(value: Vector3) -> Array:return [value.x,value.y,value.z] if value.is_finite() else []
static func _v2(value: Vector2) -> Array:return [value.x,value.y] if value.is_finite() else []
static func _bounds(lo: Vector3,hi: Vector3) -> Dictionary:return {"min":_v3(lo),"max":_v3(hi),"size":_v3(hi-lo)}
static func _rect(lo: Vector2,hi: Vector2) -> Dictionary:return {"min":_v2(lo),"max":_v2(hi),"size":_v2(hi-lo)}
