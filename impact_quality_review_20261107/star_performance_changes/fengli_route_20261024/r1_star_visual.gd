extends RefCounted
## Screen-space choreography only. No simulated position, collision, target,
## input, damage, immunity, cooldown, or clock mutation. Never a damage boundary.
const ENTER_END: float = 0.10
const STAR_END: float = 0.80
const RETURN_END: float = 0.90
const MIN_STAGE: Vector2 = Vector2(340, 240)
var cast_id: int = -1
var identity: String = ""
var layout: Dictionary = {}

func clear() -> void:
 cast_id = -1
 identity = ""
 layout.clear()

func _bounds(points: PackedVector2Array) -> Rect2:
 var result := Rect2(points[0], Vector2.ZERO)
 for point: Vector2 in points:
  result = result.expand(point)
 return result

func _project_box(view: Node2D, position: Vector3, half: Vector3) -> Rect2:
 return _bounds(PackedVector2Array([view.p(position + Vector3(-half.x,0,-half.z)), view.p(position + Vector3(half.x,0,-half.z)), view.p(position + Vector3(half.x,0,half.z)), view.p(position + Vector3(-half.x,0,half.z))]))

func _keep_rect(result: Array, rect: Rect2, origin: Vector2) -> void:
 if rect.size.x > 1.0 and rect.size.y > 1.0 and rect.grow(0.01).has_point(origin):
  result.append(rect)

func _make_layout(view: Node2D, sim: Node, origin: Vector2) -> Dictionary:
 var viewport: Vector2 = view.get_viewport_rect().size
 var bottom: float = viewport.y - 194.0
 if is_instance_valid(view.host.initial_hud) and is_instance_valid(view.host.initial_hud.bottom_bar):
  bottom = minf(bottom, view.host.initial_hud.bottom_bar.get_global_rect().position.y - 12.0)
 # Foot-space margins include the full original dash art, not just its feet.
 var safe := Rect2(Vector2(58,72), Vector2(maxf(0,viewport.x-116),maxf(0,bottom-72)))
 var arena: Rect2 = _project_box(view, Vector3.ZERO, Vector3(sim.arena_half_extent,0,sim.arena_half_extent))
 safe = safe.intersection(arena.grow(-12.0))
 var spaces: Array = [safe]
 var blocked: Array = []
 for obstacle: Dictionary in sim.obstacles:
  var box: Rect2 = _project_box(view, obstacle.position, obstacle.half)
  # A foot below a platform needs extra room for the upward-extending sprite.
  box = Rect2(box.position-Vector2(52,12),box.size+Vector2(104,76))
  blocked.append(box)
  var next: Array = []
  for area: Rect2 in spaces:
   if not area.intersects(box):
    _keep_rect(next,area,origin)
    continue
   _keep_rect(next,Rect2(area.position,Vector2(box.position.x-area.position.x,area.size.y)),origin)
   _keep_rect(next,Rect2(Vector2(box.end.x,area.position.y),Vector2(area.end.x-box.end.x,area.size.y)),origin)
   _keep_rect(next,Rect2(area.position,Vector2(area.size.x,box.position.y-area.position.y)),origin)
   _keep_rect(next,Rect2(Vector2(area.position.x,box.end.y),Vector2(area.size.x,area.end.y-box.end.y)),origin)
  spaces = []
  for index: int in range(next.size()):
   var enclosed: bool = false
   for other: int in range(next.size()):
    if other != index and Rect2(next[other]).encloses(Rect2(next[index])) and (next[other] != next[index] or other < index):
     enclosed = true
     break
   if not enclosed:
    spaces.append(next[index])
  if spaces.size() > 64:
   return {"available":false,"reason":"bounded_stage_split_limit","viewport":viewport}
 var best := Rect2()
 var best_score: float = -1.0
 for area: Rect2 in spaces:
  var score: float = area.size.x * area.size.y
  if area.size.x >= MIN_STAGE.x and area.size.y >= MIN_STAGE.y and score > best_score:
   best = area
   best_score = score
 if best_score < 0.0:
  return {"available":false,"reason":"insufficient_complete_star_space","viewport":viewport,"safe":safe,"candidate_rectangles":spaces,"minimum_stage":MIN_STAGE}
 var center: Vector2 = best.get_center()
 var half := Vector2(minf(best.size.x*0.44,viewport.x*0.24),minf(best.size.y*0.42,viewport.y*0.24))
 var vertices := PackedVector2Array()
 for step: int in range(6):
  var angle: float = -PI*0.5 + TAU*float((step*2)%5)/5.0
  vertices.append(center-origin+Vector2(cos(angle)*half.x,sin(angle)*half.y))
 return {"available":true,"viewport":viewport,"origin_at_layout":origin,"stage_rect":best,"center_offset":center-origin,"vertices":vertices,"star_size":Vector2(half.x*1.902113,half.y*1.809017),"source_obstacles":blocked.size(),"layout_authority":"once_per_cast_actual_camera_hud_and_obstacles","damage_radius_authority":false}

func _pose_at(age: float) -> Dictionary:
 var points: PackedVector2Array = layout.vertices
 if age < ENTER_END:
  var t: float = clampf(age/ENTER_END,0,1)
  var ease: float = t*t*(3.0-2.0*t)
  return {"offset":points[0]*ease,"tangent":points[0].normalized(),"phase":"enter","travelling":true,"edge":-1,"edge_progress":t}
 if age < STAR_END:
  var progress: float = (age-ENTER_END)/(STAR_END-ENTER_END)*5.0
  var edge: int = mini(4,int(floor(progress)))
  var t: float = progress-float(edge)
  return {"offset":points[edge].lerp(points[edge+1],t),"tangent":(points[edge+1]-points[edge]).normalized(),"phase":"star_travel","travelling":true,"edge":edge,"edge_progress":t}
 if age < RETURN_END:
  var t: float = clampf((age-STAR_END)/(RETURN_END-STAR_END),0,1)
  var ease: float = t*t*(3.0-2.0*t)
  return {"offset":points[5]*(1.0-ease),"tangent":(-points[5]).normalized(),"phase":"return","travelling":true,"edge":5,"edge_progress":t}
 return {"offset":Vector2.ZERO,"tangent":Vector2.ZERO,"phase":"hold","travelling":false,"edge":5,"edge_progress":1.0}

func sample(view: Node2D, sim: Node, id: int, cast_identity: String, age: float, impact_age: float) -> Dictionary:
 var origin: Vector2 = view.p(sim.hero.position)
 if cast_id != id or identity != cast_identity:
  clear()
  cast_id = id
  identity = cast_identity
  layout = _make_layout(view,sim,origin)
 if not bool(layout.get("available",false)):
  return {"active":false,"cast_id":id,"cast_identity":identity,"age":age,"layout_available":false,"layout":layout.duplicate(true),"source_position":sim.hero.position,"source_mutations":false}
 if Vector2(layout.viewport) != view.get_viewport_rect().size:
  return {"active":false,"cast_id":id,"cast_identity":identity,"age":age,"layout_available":false,"reason":"viewport_changed_during_fixed_layout","source_mutations":false}
 var pose: Dictionary = _pose_at(age)
 if impact_age >= 0.0:
  pose.phase = "impact" if impact_age < 0.10 else "recover"
  pose.offset = Vector2.ZERO
  pose.travelling = false
 elif age >= 1.1:
  pose.phase = "await_source_impact"
 var ghosts: Array = []
 if bool(pose.travelling):
  for delay: float in [0.052,0.026]:
   if age >= delay:
    var prior: Dictionary = _pose_at(age-delay)
    ghosts.append({"position":origin+Vector2(prior.offset),"tangent":prior.tangent,"alpha":0.07 if delay>0.04 else 0.14})
 return pose.merged({"active":true,"cast_id":id,"cast_identity":identity,"age":age,"time_domain":"real","impact_seen":impact_age>=0.0,"impact_age":impact_age,"draw_position":origin+Vector2(pose.offset),"visual_foot":origin+Vector2(pose.offset),"origin":origin,"source_screen_position":origin,"source_position":sim.hero.position,"ghosts":ghosts,"ghost_count":ghosts.size(),"layout_available":true,"layout":layout.duplicate(true),"body_and_weapon_together":true,"world_position_mutated":false,"ghosts_pickable":false,"damage_authority":false,"source_mutations":false},true)

func _stroke(view: Node2D, a: Vector2, b: Vector2, alpha: float, core: bool) -> void:
 if alpha <= 0.00001 or a.distance_squared_to(b) < 0.001:
  return
 view.draw_line(a,b,Color(0.025,0.08,0.16,alpha*0.8),5.0,true)
 view.draw_line(a,b,Color(0.12,0.90,0.98,alpha),2.6,true)
 if core:
  view.draw_line(a,b,Color(0.94,1.0,0.84,alpha*0.8),0.95,true)

func draw_travel(view: Node2D, value: Dictionary) -> void:
 if not bool(value.get("active",false)) or bool(value.impact_seen):
  return
 var age: float = value.age
 var origin: Vector2 = value.source_screen_position
 var points: PackedVector2Array = layout.vertices
 if age < ENTER_END:
  _stroke(view,origin,value.draw_position,0.38,true)
 var progress: float = clampf((age-ENTER_END)/(STAR_END-ENTER_END)*5.0,0,5)
 for edge: int in range(5):
  var fraction: float = clampf(progress-float(edge),0,1)
  if fraction <= 0.0:
   continue
  var alpha: float = 0.26 if fraction>=1.0 else 0.78
  if age >= RETURN_END:
   alpha = lerpf(0.28,0.50,clampf((age-RETURN_END)/0.20,0,1))
  _stroke(view,origin+points[edge],origin+points[edge].lerp(points[edge+1],fraction),alpha,fraction<1.0 or age>=RETURN_END)
 if str(value.phase)=="return":
  _stroke(view,origin+points[5],value.draw_position,0.24,false)

func draw_release(view: Node2D, event: Dictionary, age: float) -> Dictionary:
 if int(event.cast_id)!=cast_id or not bool(layout.get("available",false)) or age<0.0 or age>=0.16:
  return {}
 var origin: Vector2 = view.p(event.position)
 var points: PackedVector2Array = layout.vertices
 var center: Vector2 = layout.center_offset
 var t: float = clampf(age/0.16,0,1)
 var alpha: float = 0.68*(1.0-t)*(1.0-t)
 # The completed moving trace breaks outward only on the accepted impact.
 # Open fragments avoid a filled star, full-screen flash, or false hit area.
 for edge: int in range(5):
  var radial: Vector2 = ((points[edge]+points[edge+1])*0.5-center).normalized()
  var displacement: Vector2 = radial*(4.0+14.0*t)
  for interval: Vector2 in [Vector2(0.06,0.43),Vector2(0.57,0.94)]:
   var a: Vector2 = origin+points[edge].lerp(points[edge+1],interval.x)+displacement
   var b: Vector2 = origin+points[edge].lerp(points[edge+1],interval.y)+displacement
   _stroke(view,a,b,alpha,true)
 return {"event_sequence":event.sequence,"cast_id":event.cast_id,"age":age,"time_domain":"real","alpha":alpha,"fragments":10,"position_authority":"actual_r1_impact","damage_authority":false,"filled_area":false}
