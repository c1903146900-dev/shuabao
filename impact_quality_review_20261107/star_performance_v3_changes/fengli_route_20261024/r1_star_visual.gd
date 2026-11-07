extends RefCounted
## One original-art wind projection, explicitly off the ground. Its screen
## stage is not terrain, a target, or a damage boundary. All clocks are source.
const ENTER_END: float = 0.10
const STAR_END: float = 0.80
const RETURN_END: float = 0.90
const MIN_STAGE: Vector2 = Vector2(340,240)
var cast_id: int = -1
var identity: String = ""
var layout: Dictionary = {}

func clear() -> void:
 cast_id = -1
 identity = ""
 layout.clear()

func _ease(value: float) -> float:
 var t: float = clampf(value,0.0,1.0)
 return t*t*(3.0-2.0*t)

func _make_layout(view: Node2D, origin: Vector2) -> Dictionary:
 var viewport: Vector2 = view.get_viewport_rect().size
 var bottom: float = viewport.y-194.0
 if is_instance_valid(view.host.initial_hud) and is_instance_valid(view.host.initial_hud.bottom_bar):
  bottom = minf(bottom,view.host.initial_hud.bottom_bar.get_global_rect().position.y-12.0)
 var safe := Rect2(Vector2(58,72),Vector2(maxf(0.0,viewport.x-116.0),maxf(0.0,bottom-72.0)))
 if safe.size.x<MIN_STAGE.x or safe.size.y<MIN_STAGE.y:
  return {"available":false,"reason":"viewport_cannot_fit_complete_aerial_stage","viewport":viewport,"safe":safe,"minimum_stage":MIN_STAGE}
 var size := Vector2(minf(560.0,safe.size.x),minf(340.0,safe.size.y))
 var stage := Rect2(safe.get_center()-size*0.5,size)
 var center: Vector2 = stage.get_center()-origin
 var half := Vector2(stage.size.x*0.44,stage.size.y*0.42)
 var vertices := PackedVector2Array()
 for step: int in range(6):
  var angle: float = -PI*0.5+TAU*float((step*2)%5)/5.0
  vertices.append(center+Vector2(cos(angle)*half.x,sin(angle)*half.y))
 return {"available":true,"viewport":viewport,"origin_at_layout":origin,"stage_rect":stage,"safe":safe,"minimum_stage":MIN_STAGE,"center_offset":center,"vertices":vertices,"star_size":Vector2(half.x*1.902113,half.y*1.809017),"layout_authority":"once_per_cast_visible_aerial_stage","terrain_path":false,"origin_inside_required":false,"damage_radius_authority":false}

func _pose_at(age: float) -> Dictionary:
 var points: PackedVector2Array = layout.vertices
 if age<ENTER_END:
  if age<0.055:
   var t: float = _ease(age/0.055)
   return {"offset":Vector2(0,-24.0*t),"tangent":Vector2.UP,"phase":"enter","connection":"source_lift","travelling":true,"edge":-1,"edge_progress":age/ENTER_END,"body_alpha":1.0-t,"body_tint":Color.WHITE.lerp(Color(0.34,0.95,1.0),t)}
  var t: float = _ease((age-0.055)/0.045)
  return {"offset":points[0],"tangent":(points[1]-points[0]).normalized(),"phase":"enter","connection":"aerial_cut_in","travelling":true,"edge":-1,"edge_progress":age/ENTER_END,"body_alpha":0.86*t,"body_tint":Color(0.42,0.96,1.0)}
 if age<STAR_END:
  var progress: float = (age-ENTER_END)/(STAR_END-ENTER_END)*5.0
  var edge: int = mini(4,int(floor(progress)))
  var t: float = progress-float(edge)
  return {"offset":points[edge].lerp(points[edge+1],t),"tangent":(points[edge+1]-points[edge]).normalized(),"phase":"star_travel","connection":"airborne_wind_projection","travelling":true,"edge":edge,"edge_progress":t,"body_alpha":0.86,"body_tint":Color(0.42,0.96,1.0)}
 if age<RETURN_END:
  if age<0.845:
   var t: float = _ease((age-STAR_END)/0.045)
   return {"offset":points[5]+Vector2(0,-10.0*t),"tangent":Vector2.UP,"phase":"return","connection":"aerial_cut_out","travelling":true,"edge":5,"edge_progress":(age-STAR_END)/(RETURN_END-STAR_END),"body_alpha":0.86*(1.0-t),"body_tint":Color(0.42,0.96,1.0)}
  var t: float = _ease((age-0.845)/0.055)
  return {"offset":Vector2(0,-24.0*(1.0-t)),"tangent":Vector2.DOWN,"phase":"return","connection":"source_land","travelling":true,"edge":5,"edge_progress":(age-STAR_END)/(RETURN_END-STAR_END),"body_alpha":t,"body_tint":Color(0.42,0.96,1.0).lerp(Color.WHITE,t)}
 return {"offset":Vector2.ZERO,"tangent":Vector2.ZERO,"phase":"hold","connection":"source_restored","travelling":false,"edge":5,"edge_progress":1.0,"body_alpha":1.0,"body_tint":Color.WHITE}

func sample(view: Node2D, sim: Node, id: int, cast_identity: String, age: float, impact_age: float) -> Dictionary:
 var origin: Vector2 = view.p(sim.hero.position)
 if cast_id!=id or identity!=cast_identity:
  clear()
  cast_id=id
  identity=cast_identity
  layout=_make_layout(view,origin)
 if not bool(layout.get("available",false)):
  return {"active":false,"cast_id":id,"cast_identity":identity,"age":age,"layout_available":false,"layout":layout.duplicate(true),"source_position":sim.hero.position,"source_mutations":false}
 if Vector2(layout.viewport)!=view.get_viewport_rect().size:
  return {"active":false,"cast_id":id,"cast_identity":identity,"age":age,"layout_available":false,"reason":"viewport_changed_during_fixed_layout","source_mutations":false}
 var pose: Dictionary = _pose_at(age)
 if impact_age>=0.0:
  pose=_pose_at(RETURN_END)
  pose.phase="impact" if impact_age<0.10 else "recover"
 elif age>=1.1:
  pose.phase="await_source_impact"
 var aerial: bool = str(pose.connection) in ["aerial_cut_in","airborne_wind_projection","aerial_cut_out"]
 var reference: Vector2 = Vector2(layout.origin_at_layout) if aerial else origin
 var animation_offset: Vector2 = pose.offset
 var draw_position: Vector2 = reference+animation_offset
 pose.offset=draw_position-origin
 var ghosts: Array = []
 # Delay samples never bridge the invisible cut or make a ground-body double.
 if str(pose.phase)=="star_travel":
  for delay: float in [0.052,0.026]:
   if age-delay<ENTER_END:
    continue
   var prior: Dictionary = _pose_at(age-delay)
   ghosts.append({"position":Vector2(layout.origin_at_layout)+Vector2(prior.offset),"tangent":prior.tangent,"alpha":0.06 if delay>0.04 else 0.12})
 return pose.merged({"active":true,"cast_id":id,"cast_identity":identity,"age":age,"time_domain":"real","impact_seen":impact_age>=0.0,"impact_age":impact_age,"draw_position":draw_position,"visual_foot":draw_position,"animation_offset":animation_offset,"visual_reference":"screen" if aerial else "source_projection","stage_origin":layout.origin_at_layout,"origin":origin,"source_screen_position":origin,"source_position":sim.hero.position,"ghosts":ghosts,"ghost_count":ghosts.size(),"layout_available":true,"layout":layout.duplicate(true),"presentation_mode":"airborne_wind_projection","visual_anchor_semantics":"projection_anchor_not_world_foot","airborne":bool(pose.travelling),"ground_shadow":not bool(pose.travelling),"body_and_weapon_together":true,"world_position_mutated":false,"ghosts_pickable":false,"projection_pickable":false,"damage_authority":false,"source_mutations":false},true)

func _blade(view: Node2D, a: Vector2, b: Vector2, alpha: float, width: float, core: bool) -> void:
 var delta: Vector2 = b-a
 var length: float = delta.length()
 if alpha<=0.00001 or length<1.0:
  return
 var along: Vector2 = delta/length
 var side := Vector2(-along.y,along.x)
 var waist: Vector2 = a+delta*0.62
 # One directional leaf of wind, with a sharp head and a trailing narrow end.
 var edge := PackedVector2Array([a,waist+side*width,b,waist-side*width*0.48,a+delta*0.20-side*width*0.20])
 view.draw_colored_polygon(edge,Color(0.10,0.78,0.97,alpha))
 if core:
  var bright := PackedVector2Array([a+delta*0.24,waist+side*width*0.28,b,waist-side*width*0.12])
  view.draw_colored_polygon(bright,Color(0.87,1.0,0.93,alpha*0.94))

func draw_travel(view: Node2D, value: Dictionary) -> void:
 if not bool(value.get("active",false)) or bool(value.impact_seen):
  return
 var age: float = value.age
 var source_origin: Vector2 = value.origin
 var origin: Vector2 = layout.origin_at_layout
 var points: PackedVector2Array = layout.vertices
 var connection: String = value.get("connection","")
 # A small upward/downward cue ties the cut to the real casting point. These
 # do not join that point to the remote stage or pretend to cross terrain.
 if connection in ["source_lift","source_land"]:
  var strength: float = sin(PI*clampf(age/0.055 if connection=="source_lift" else (age-0.845)/0.055,0.0,1.0))
  var rise := Vector2(0,-1) if connection=="source_lift" else Vector2(0,1)
  _blade(view,source_origin-Vector2(12,11)-rise*9.0,source_origin-Vector2(12,11)+rise*13.0,strength*0.52,2.6,true)
  _blade(view,source_origin+Vector2(12,-15)-rise*7.0,source_origin+Vector2(12,-15)+rise*11.0,strength*0.34,2.0,false)
 var progress: float = clampf((age-ENTER_END)/(STAR_END-ENTER_END)*5.0,0.0,5.0)
 for edge: int in range(5):
  var fraction: float = clampf(progress-float(edge),0.0,1.0)
  if fraction<=0.0:
   continue
  var a: Vector2 = origin+points[edge]
  var b: Vector2 = origin+points[edge+1]
  var head: Vector2 = a.lerp(b,fraction)
  var end_age: float = ENTER_END+(STAR_END-ENTER_END)*float(edge+1)/5.0
  var old: float = maxf(0.0,age-end_age)
  var alpha: float = 0.11+0.16*pow(clampf(1.0-old/0.68,0.0,1.0),1.4)
  var width: float = 2.3
  if fraction<1.0:
   # The moving blade has a head. Its brighter tail never spans the full edge.
   _blade(view,a,head,0.16,2.0,false)
   var tail: Vector2 = head-(b-a).normalized()*minf(122.0,a.distance_to(head))
   _blade(view,tail,head,0.68,5.4,true)
  else:
   if age>=STAR_END:
    # Contract each trace with a different edge age, instead of lighting up
    # an equal-width pentagram during the pause. All disappear on real impact.
    var gather: float = clampf((age-STAR_END)/0.30,0.0,1.0)
    var trim: float = gather*(0.13+0.035*float(4-edge))
    a=a.lerp(b,trim)
    b=(origin+points[edge+1]).lerp(origin+points[edge],trim*0.55)
    alpha*=1.0-0.78*gather
    width*=1.0-0.50*gather
   _blade(view,a,b,alpha,width,false)

# One source-centered open pressure front, not a static range ring. Clipping
# here affects paint only, never source radius, targets or collision geometry.
func _release_distance(point: Vector2, edge: int, clip: Rect2) -> float:
 match edge:
  0: return point.x-clip.position.x
  1: return clip.end.x-point.x
  2: return point.y-clip.position.y
  _: return clip.end.y-point.y

func _release_clip(vertices: Array, clip: Rect2) -> Array:
 var result: Array = vertices
 for edge: int in range(4):
  if result.is_empty():
   break
  var input: Array = result
  result=[]
  var previous: Dictionary = input[-1]
  var previous_distance: float = _release_distance(previous.point,edge,clip)
  for current: Dictionary in input:
   var distance: float = _release_distance(current.point,edge,clip)
   if (distance>=0.0)!=(previous_distance>=0.0):
    var t: float = previous_distance/(previous_distance-distance)
    result.append({"point":Vector2(previous.point).lerp(current.point,t),"color":Color(previous.color).lerp(current.color,t)})
   if distance>=0.0:
    result.append(current)
   previous=current
   previous_distance=distance
 return result

func _release_quad(view: Node2D, vertices: Array, clip: Rect2) -> bool:
 var clipped: Array = _release_clip(vertices,clip)
 if clipped.size()<3:
  return false
 var points := PackedVector2Array()
 var colors := PackedColorArray()
 for vertex: Dictionary in clipped:
  if not points.is_empty() and points[-1].distance_squared_to(vertex.point)<0.000001:
   continue
  points.append(vertex.point)
  colors.append(vertex.color)
 if points.size()>2 and points[0].distance_squared_to(points[-1])<0.000001:
  points.remove_at(points.size()-1)
  colors.remove_at(colors.size()-1)
 if points.size()<3:
  return false
 var area: float = 0.0
 for index: int in range(points.size()):
  area+=points[index].cross(points[(index+1)%points.size()])
 if absf(area)<0.01:
  return false
 view.draw_polygon(points,colors)
 return true

func draw_release(view: Node2D, event: Dictionary, age: float) -> Dictionary:
 # The call site is exclusively the validated r1_impact shape queue. No cast
 # age threshold can manufacture this effect, and it never creates a hit.
 if int(event.cast_id)!=cast_id or age<0.0 or age>=0.14:
  return {}
 var center: Vector3 = event.position
 var radius: float = float(event.radius)
 var direction: Vector3 = event.direction
 if radius<=0.0 or not is_finite(radius) or not center.is_finite() or not direction.is_finite():
  return {"available":false,"reason":"source_release_geometry_invalid","damage_authority":false}
 var viewport: Vector2 = view.get_viewport_rect().size
 var bottom: float = viewport.y-194.0
 if is_instance_valid(view.host.initial_hud) and is_instance_valid(view.host.initial_hud.bottom_bar):
  bottom=minf(bottom,view.host.initial_hud.bottom_bar.get_global_rect().position.y-12.0)
 var clip := Rect2(Vector2.ZERO,Vector2(viewport.x,maxf(0.0,bottom)))
 var progress: float = clampf(age/0.08,0.0,1.0)
 var front: float = radius*(0.18+0.82*(1.0-pow(1.0-progress,3.0)))
 var life: float = clampf(1.0-age/0.14,0.0,1.0)
 var alpha: float = 0.82*pow(life,1.2)
 var facing: float = atan2(direction.z,direction.x)
 var half_arc: float = PI*0.80
 var width: float = minf(front*0.26,maxf(0.38,radius*0.025))
 var drawn: int = 0
 # One connected 288-degree sheet, opening behind the actual casting facing.
 # The front is strongest; ends taper to zero. No closed, equally lit shield.
 for segment: int in range(48):
  var band: Array = []
  var crest: Array = []
  var outside: Array = []
  var inside: Array = []
  var crest_inside: Array = []
  for index: int in [segment,segment+1]:
   var u: float = float(index)/48.0
   var angle: float = facing-half_arc+half_arc*2.0*u
   var radial := Vector3(cos(angle),0,sin(angle))
   var feather: float = pow(maxf(0.0,sin(PI*u)),0.80)
   var local_width: float = width*(0.18+0.82*feather)
   var tip: Vector2 = view.p(center+radial*front)
   var tail: Vector2 = view.p(center+radial*maxf(0.0,front-local_width))
   var crest_tail: Vector2 = view.p(center+radial*maxf(0.0,front-local_width*0.16))
   outside.append({"point":tip,"color":Color(0.17,0.94,1.0,alpha*feather)})
   inside.append({"point":tail,"color":Color(0.08,0.42,0.78,alpha*feather*0.10)})
   crest_inside.append({"point":crest_tail,"color":Color(0.91,1.0,0.89,alpha*feather*0.92)})
  band=[outside[0],outside[1],inside[1],inside[0]]
  crest=[outside[0].merged({"color":Color(0.93,1.0,0.91,Color(outside[0].color).a*0.92)},true),outside[1].merged({"color":Color(0.93,1.0,0.91,Color(outside[1].color).a*0.92)},true),crest_inside[1],crest_inside[0]]
  if _release_quad(view,band,clip):drawn+=1
  if _release_quad(view,crest,clip):drawn+=1
 return {"available":true,"event_sequence":event.sequence,"sequence":event.sequence,"cast_id":event.cast_id,"age":age,"time_domain":"real","style":"single_source_wind_release","phase":"expand" if age<0.08 else "dissipate","position":center,"radius":radius,"source_position":center,"source_direction":direction,"source_radius":radius,"visual_front_radius":front,"visual_width":width,"visual_duration":0.14,"expand_duration":0.08,"alpha":alpha,"arc_degrees":288.0,"rear_opening_degrees":72.0,"transparent_interior":true,"pixel_clip":clip,"drawn_quads":drawn,"maximum_quads":96,"position_authority":"actual_r1_impact","damage_authority":false,"additional_contacts":false,"filled_area":false}
