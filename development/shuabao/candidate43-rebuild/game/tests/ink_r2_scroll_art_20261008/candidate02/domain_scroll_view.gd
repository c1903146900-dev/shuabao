extends Node3D
## Independent read-only field display. No Sim, timer, collision or gameplay writes.
const ATLAS_PATH: String = "res://assets/ink_generated/r2_landscape01/ink_mountain_atlas01.png"
const MESH_PATH: String = "res://tests/ink_r2_scroll_art_20261008/candidate02/domain_geometry.gd"
const SHADER_PATH: String = "res://tests/ink_r2_scroll_art_20261008/candidate02/domain_ink.gdshader"
const PRE_CLOSE_SECONDS: float = 0.72
var ink_node: MeshInstance3D
var ink_material: ShaderMaterial
var ink_mesh: ArrayMesh
var locked: Dictionary = {}
var pending_rollup: Dictionary = {}
var display_report: Dictionary = {}
var scope_key: String = ""
var closed_domain_id: String = ""
var closed_born_at: float = -INF
var frozen_brush_origin: Vector3 = Vector3.ZERO
var origin_kind: String = "none"

func _ready() -> void:
 set_as_top_level(true)
 transform = Transform3D.IDENTITY
 set_process(false)
 set_physics_process(false)
 _ensure_resources()

func _ensure_resources() -> bool:
 if ink_mesh == null:
  var mesh_script: GDScript = ResourceLoader.load(MESH_PATH,"GDScript") as GDScript
  if mesh_script == null or not mesh_script.can_instantiate():
   push_error("R2 region mesh script unavailable");return false
  var builder: RefCounted = mesh_script.new()
  ink_mesh = builder.call("build") as ArrayMesh
 if ink_material == null:
  var texture: Texture2D = ResourceLoader.load(ATLAS_PATH,"Texture2D") as Texture2D
  var shader: Shader = ResourceLoader.load(SHADER_PATH,"Shader") as Shader
  if texture == null or shader == null or texture.get_width()!=1254 or texture.get_height()!=1254:
   push_error("R2 region requires original standard imported atlas and shader");return false
  ink_material = ShaderMaterial.new();ink_material.shader=shader
  ink_material.set_shader_parameter("landscape_atlas",texture)
 if not is_instance_valid(ink_node):
  ink_node=MeshInstance3D.new();ink_node.name="R2ReadOnlyInkDomain"
  ink_node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  ink_node.visible=false;add_child(ink_node)
 return ink_mesh!=null

func _finite_number(value: Variant) -> bool:
 return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value))

func _same_scope(value: Dictionary, scope: Dictionary) -> bool:
 return int(value.get("generation",-1))==int(scope.get("generation",-2)) and str(value.get("room_id",""))==str(scope.get("room_id","?"))

func _valid_domain(domain: Dictionary, scope: Dictionary) -> bool:
 if domain.is_empty() or not _same_scope(domain,scope) or str(domain.get("domain_id","")).is_empty():return false
 if not domain.get("position",null) is Vector3 or not Vector3(domain.position).is_finite():return false
 for key: String in ["radius","born_at","expires_at","remaining"]:
  if not domain.has(key) or not _finite_number(domain[key]):return false
 return float(domain.radius)>0.0 and float(domain.expires_at)>float(domain.born_at) and float(domain.remaining)>=0.0

func receive_source(event: Dictionary) -> void:
 # This entry is wired only to actual combat_event delivery by the review host.
 # A valid packet may precede the next source snapshot; buffering never renders.
 if locked.is_empty() or str(event.get("kind",""))!="ink_r2_rollup_started":return
 if event.has("accepted") and event.accepted!=true:return
 if bool(event.get("preview_only",false)):return
 if not _same_scope(event,locked) or str(event.get("domain_id",""))!=str(locked.domain_id):return
 if not event.get("position",null) is Vector3 or event.position!=locked.position:return
 for key: String in ["radius","source_time","world_time"]:
  if not event.has(key) or not _finite_number(event[key]):return
 if float(event.radius)!=float(locked.radius) or float(event.source_time)!=float(locked.expires_at):return
 if float(event.world_time)<float(locked.born_at):return
 if pending_rollup.is_empty():pending_rollup=event.duplicate(true)

func _retire_display() -> void:
 if not is_instance_valid(ink_node):return
 ink_node.visible=false
 ink_node.mesh=null
 ink_node.material_override=null
 if ink_material!=null:ink_material.set_shader_parameter("visible_ink",0.0)

func _close(reason: String, now: float) -> void:
 if not locked.is_empty():
  closed_domain_id=str(locked.domain_id)
  closed_born_at=maxf(closed_born_at,float(locked.born_at))
 locked={};pending_rollup={};frozen_brush_origin=Vector3.ZERO;origin_kind="none";_retire_display()
 display_report={"active":false,"fixed_boundary_visible":false,"active_boundary_radius":0.0,"reason":reason,"world_time":now,"closed_domain_id":closed_domain_id,"fold_progress":1.0,"visual_tail_seconds":0.0}

func present_source(ink_snapshot: Dictionary, _preview: Dictionary = {}) -> void:
 if not _ensure_resources():reset_visuals();return
 var scope_value: Variant=ink_snapshot.get("scope",{})
 if not scope_value is Dictionary or not scope_value.has("generation") or not scope_value.has("room_id"):
  reset_visuals();return
 var scope: Dictionary=scope_value
 if not _finite_number(ink_snapshot.get("world_time",null)):reset_visuals();return
 var now: float=float(ink_snapshot.world_time)
 var next_scope: String=JSON.stringify([scope.generation,scope.room_id])
 if next_scope!=scope_key:
  reset_visuals();scope_key=next_scope
 var domain_value: Variant=ink_snapshot.get("peaks_domain",{})
 var domain: Dictionary=domain_value if domain_value is Dictionary else {}
 var admitted_rollup: bool=not pending_rollup.is_empty() and now>=float(pending_rollup.world_time)
 if not locked.is_empty() and (admitted_rollup or now>=float(locked.expires_at)):
  _close("admitted_rollup" if admitted_rollup else "actual_expiry",now);return
 if not _valid_domain(domain,scope):
  if not locked.is_empty():_close("source_removed",now)
  else:_retire_display()
  return
 if str(domain.domain_id)==closed_domain_id or float(domain.born_at)<closed_born_at:
  _retire_display();return
 if not locked.is_empty() and str(locked.domain_id)!=str(domain.domain_id):
  _close("replaced_domain",now)
 if locked.is_empty():
  locked=domain.duplicate(true)
  frozen_brush_origin=locked.position
  origin_kind="source_center_fallback"
  var hero_value: Variant=ink_snapshot.get("hero",{})
  if hero_value is Dictionary and hero_value.get("position",null) is Vector3 and Vector3(hero_value.position).is_finite():
   frozen_brush_origin=Vector3(hero_value.position)+Vector3.UP*0.65
   var facing: Variant=hero_value.get("facing",Vector3.ZERO)
   if facing is Vector3 and Vector3(facing).is_finite():
    frozen_brush_origin+=Vector3(facing).normalized()*0.55
   origin_kind="first_valid_domain_hero_brush_pose"

 if now<float(locked.born_at):
  _retire_display();display_report={"active":false,"reason":"before_birth","world_time":now};return
 if now>=float(locked.expires_at):_close("actual_expiry",now);return
 var remaining: float=float(locked.expires_at)-now
 var fold: float=clampf(1.0-remaining/PRE_CLOSE_SECONDS,0.0,1.0)
 ink_node.position=locked.position
 ink_node.scale=Vector3(float(locked.radius),1.0,float(locked.radius))
 ink_node.mesh=ink_mesh;ink_node.material_override=ink_material
 ink_material.set_shader_parameter("domain_center",locked.position)
 ink_material.set_shader_parameter("domain_radius",float(locked.radius))
 ink_material.set_shader_parameter("fold_progress",fold)
 var local_target: Vector3=frozen_brush_origin-Vector3(locked.position)
 local_target.x/=float(locked.radius);local_target.z/=float(locked.radius)
 ink_material.set_shader_parameter("gather_target",local_target)
 ink_material.set_shader_parameter("unfold_progress",clampf((now-float(locked.born_at))/0.38,0.0,1.0))
 ink_material.set_shader_parameter("visible_ink",1.0)
 ink_node.visible=true
 display_report={"active":true,"fixed_boundary_visible":true,"active_boundary_radius":float(locked.radius),"boundary_outer_radius_fraction":0.995,"interior_fold_progress":fold,"frozen_brush_origin":frozen_brush_origin,"origin_kind":origin_kind,"closing_form":"five_open_brush_ribbons","world_time":now,"domain_id":locked.domain_id,"position":locked.position,"radius":locked.radius,"born_at":locked.born_at,"expires_at":locked.expires_at,"fold_progress":fold,"preclose":fold>0.0,"unfold_progress":clampf((now-float(locked.born_at))/0.38,0.0,1.0),"preclose_seconds":PRE_CLOSE_SECONDS,"visual_tail_seconds":0.0,"art_accepted":false}

func presentation_snapshot() -> Dictionary:
 return display_report.duplicate(true)

func reset_visuals() -> void:
 _retire_display();locked={};pending_rollup={};display_report={};scope_key="";closed_domain_id="";closed_born_at=-INF;frozen_brush_origin=Vector3.ZERO;origin_kind="none"

func _exit_tree() -> void:
 reset_visuals()
