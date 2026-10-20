extends RefCounted
## External read-only postdraw observer. Caller supplies the actual entry node.
## Does not call prepare/commit/solve/process, change visibility, or issue game input.
const MAX_SAMPLES: int=128
var samples: Array[Dictionary]=[]
var prior: Dictionary={}
var failure: String=""
func _v(p: Vector3) -> Array:return [p.x,p.y,p.z]
func _reject(reason: String) -> Dictionary:
 failure=reason
 return {"accepted":false,"reason":reason,"scope":"READONLY_SOURCE06_GAIT_DIAGNOSTIC"}
func observe(entry: Node) -> Dictionary:
 if samples.size()>=MAX_SAMPLES:return _reject("sample_budget")
 if not is_instance_valid(entry):return _reject("entry_owner")
 var host: Node=entry.get("active_room") as Node
 var display: Node3D=entry.get("_front_hero") as Node3D
 if not is_instance_valid(host) or not is_instance_valid(display) or display.get_parent()!=host:return _reject("display_owner")
 var actor: Node3D=host.get("hero_view") as Node3D;var sim: Node=host.get("sim") as Node
 var renderer: Node3D=display.get("renderer") as Node3D;var camera: Camera3D=display.get("camera") as Camera3D
 if not is_instance_valid(actor) or not is_instance_valid(sim) or not is_instance_valid(renderer) or not is_instance_valid(camera):return _reject("runtime_owner")
 if not actor.get("sample_report") is Dictionary or not display.get("receipt") is Dictionary or not renderer.get("receipt") is Dictionary:return _reject("report_not_ready")
 var report: Dictionary=actor.get("sample_report")
 var receipt: Dictionary=display.get("receipt")
 var renderer_receipt: Dictionary=renderer.get("receipt")
 var mapper: Object=display.get("mapper")
 var last_plan: Dictionary=mapper.get("last_plan") if is_instance_valid(mapper) else {}
 var view: String=str(renderer_receipt.get("view",""))
 var now: float=float(sim.get("hero_time"));var draw: int=Engine.get_process_frames()
 var row: Dictionary={"sample_index":samples.size(),"draw_frame":draw,"source_time":now,"actor_report_source_time":report.get("source_time"),"controller_receipt_source_time":receipt.get("source_time"),"renderer_receipt_source_time":renderer_receipt.get("source_time"),"same_source_clock":float(report.get("source_time",-INF))==now and float(receipt.get("source_time",-INF))==now and float(renderer_receipt.get("source_time",-INF))==now,"view":view,"actor_world":_v(actor.global_position),"base":report.get("base"),"base_time":report.get("base_time"),"gait_elapsed_absolute":report.get("gait_elapsed_absolute"),"gait_cursor_signed":report.get("gait_cursor_signed"),"walk_playback_ratio":report.get("walk_playback_ratio"),"actual_displacement":report.get("actual_displacement"),"source_delta":report.get("source_delta"),"upper":report.get("upper"),"controller_fatal":display.get("fatal"),"controller_accepted":receipt.get("accepted",false),"controller_reason":receipt.get("reason",""),"renderer_accepted":renderer_receipt.get("accepted",false),"controller_visible":display.visible,"renderer_visible":renderer.visible,"plan_moving":receipt.get("moving"),"plan_gait_phase":receipt.get("gait_phase"),"plan_phase":receipt.get("phase"),"mapper_last_plan_time":last_plan.get("source_time"),"mapper_last_plan_moving":last_plan.get("moving"),"mapper_last_plan_gait_phase":last_plan.get("gait_phase"),"layers":{},"views_visible":{},"native_art_accepted":false}
 for direction: String in ["front","right","left","back"]:
  var candidate: Node3D=renderer.get(direction) as Node3D
  row.views_visible[direction]=is_instance_valid(candidate) and candidate.visible
 var selected: Node3D=(renderer.get(view) as Node3D) if view in ["front","right","left","back"] else null
 if not is_instance_valid(selected):samples.append(row);return row
 var layers: Dictionary=selected.get("layers_by_name")
 var viewport_size: Vector2=Vector2(camera.get_viewport().get_visible_rect().size)
 var pixels_per_m: float=(viewport_size.y if int(camera.keep_aspect)==Camera3D.KEEP_HEIGHT else viewport_size.x)/float(camera.size)
 row["viewport_size"]=[viewport_size.x,viewport_size.y];row["orthographic_size"]=camera.size;row["pixels_per_camera_m"]=pixels_per_m
 var prior_scope: String=str(host.get_instance_id())+"/"+str(sim.get("room_id"))+"/"+str(sim.get("encounter_generation"))+"/"+view
 var preceding: bool=not prior.is_empty() and str(prior.scope)==prior_scope and int(prior.draw_frame)==draw-1
 row["actual_adjacent_same_view"]=preceding
 row["source_dt_from_previous_observed"]=now-float(prior.get("source_time",now))
 var next_vertices: Dictionary={}
 for key: String in layers:
  var node: MeshInstance3D=layers[key] as MeshInstance3D
  if not is_instance_valid(node) or node.get_parent()!=selected:return _reject("layer_owner:"+key)
  var mesh: ArrayMesh=node.mesh as ArrayMesh
  if mesh==null or mesh.get_surface_count()!=1:return _reject("layer_surface:"+key)
  var arrays: Array=mesh.surface_get_arrays(0)
  if arrays.size()!=Mesh.ARRAY_MAX:return _reject("layer_arrays:"+key)
  var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
  if uv.size()!=vertices.size():return _reject("layer_vertex_uv_count:"+key)
  var material: ShaderMaterial=node.material_override as ShaderMaterial
  if material==null:return _reject("layer_material:"+key)
  var atlas: Texture2D=material.get_shader_parameter("atlas") as Texture2D
  if atlas==null:return _reject("layer_atlas:"+key)
  var maximum: float=0.0;var lower_maximum: float=0.0;var lower_count: int=0
  var comparable: bool=preceding and prior.vertices.has(key) and prior.vertices[key].size()==vertices.size()
  for i in range(vertices.size()):
   var low: bool=(key=="legs" and view=="front" and uv[i].y*atlas.get_height()>=70.0) or (key=="body" and view!="front" and uv[i].y*atlas.get_height()>=(555.0 if view=="back" else 535.0))
   if low:lower_count+=1
   if comparable:
    var old: Vector3=prior.vertices[key][i]
    var delta: float=Vector2(vertices[i].x-old.x,vertices[i].y-old.y).length()
    maximum=maxf(maximum,delta)
    if low:lower_maximum=maxf(lower_maximum,delta)
  row.layers[key]={"visible":node.visible,"vertices":vertices.size(),"indices":arrays[Mesh.ARRAY_INDEX].size(),"atlas_size":[atlas.get_width(),atlas.get_height()],"atlas_instance_id":atlas.get_instance_id(),"adjacent_delta_valid":comparable,"max_local_camera_xy_delta_m":maximum if comparable else null,"max_local_camera_xy_delta_pixels":maximum*pixels_per_m if comparable else null,"lower_region_vertex_count":lower_count,"max_lower_region_delta_pixels":lower_maximum*pixels_per_m if comparable else null}
  next_vertices[key]=vertices
 row["original_skin_layers"]=[]
 for binding: Dictionary in display.get("skins"):
  if not is_instance_valid(binding.node):return _reject("source_skin_owner")
  row.original_skin_layers.append({"name":binding.node.name,"layers":binding.node.layers,"display_owned":binding.owned})
 prior={"scope":prior_scope,"draw_frame":draw,"source_time":now,"vertices":next_vertices}
 samples.append(row)
 return row
