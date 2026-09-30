extends Node3D
## Replace Visual children with assets/fengli; simulation never reads animation pose.
var visual: Node3D
var animation_player: AnimationPlayer
var ring: MeshInstance3D
var blade: MeshInstance3D
var health_label: Label3D
var material: StandardMaterial3D
var actor_kind: String = "hero"
var flash_left: float = 0.0
var swing_left: float = 0.0
var body_color: Color
var dead_seen: bool = false
var imported_art: bool = false
var previous_position: Vector3 = Vector3.ZERO
var warning: MeshInstance3D

func setup(kind: String) -> void:
 actor_kind = kind
 body_color = {"hero":Color("35dfca"),"minion":Color("ef935c"),"elite":Color("e4bc60"),"boss":Color("cd5368")}[kind]
 visual = Node3D.new()
 visual.name = "Visual"
 add_child(visual)
 animation_player = AnimationPlayer.new()
 animation_player.name = "AnimationPlayer"
 visual.add_child(animation_player)
 material = make_material(body_color)
 var scale_value: float = {"hero":1.0,"minion":0.9,"elite":1.3,"boss":1.9}[kind]
 var body = CapsuleMesh.new()
 body.radius = 0.31 * scale_value
 body.height = 1.25 * scale_value
 var torso = mesh_node(body, material, visual)
 torso.position.y = body.height * 0.5
 var head = SphereMesh.new()
 head.radius = 0.25 * scale_value
 head.height = 0.5 * scale_value
 var head_node = mesh_node(head, make_material(body_color.lightened(0.3)), visual)
 head_node.position.y = body.height + 0.05
 # A fixed shoulder silhouette and long sword communicate facing at a glance.
 var shoulders = BoxMesh.new()
 shoulders.size = Vector3(0.88,0.18,0.32) * scale_value
 var shoulder_node = mesh_node(shoulders, material, visual)
 shoulder_node.position.y = body.height * 0.85
 var sword = BoxMesh.new()
 sword.size = Vector3(0.10,0.12,1.85 if kind == "hero" else 1.25) * scale_value
 blade = mesh_node(sword, make_material(Color("d5fff6") if kind == "hero" else Color("60433d")), visual)
 blade.position = Vector3(0.45,0.75,-0.95) * scale_value
 var torus = TorusMesh.new()
 torus.inner_radius = 0.46 * scale_value
 torus.outer_radius = 0.52 * scale_value
 torus.rings = 32
 torus.ring_segments = 8
 ring = mesh_node(torus, make_material(body_color, true), self)
 ring.position.y = 0.035
 health_label = Label3D.new()
 health_label.font_size = 36
 health_label.pixel_size = 0.011
 health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
 health_label.no_depth_test = true
 health_label.position.y = body.height + 0.68
 health_label.outline_size = 8
 add_child(health_label)
 warning = MeshInstance3D.new()
 warning.name = "AttackWarning"
 warning.visible = false
 add_child(warning)

func sync(state: Dictionary, dt: float) -> void:
 var moving: bool = previous_position.distance_squared_to(state.position) > 0.00001
 position = state.position
 previous_position = position
 var facing: Vector3 = state.get("facing", state.get("aim", Vector3.FORWARD))
 if facing.length_squared() > 0.001: rotation.y = atan2(-facing.x, -facing.z)
 flash_left = maxf(0.0, flash_left - dt)
 swing_left = maxf(0.0, swing_left - dt)
 material.albedo_color = Color.WHITE if flash_left > 0 else body_color
 var dead: bool = state.get("dead", false)
 if not imported_art:
  visual.rotation.z = lerpf(visual.rotation.z, 1.5 if dead else 0.0, minf(1.0, dt * 12.0))
  visual.position.y = -0.2 if dead else sin(Time.get_ticks_msec() * 0.004) * 0.025
 if is_instance_valid(blade): blade.rotation.y = sin(swing_left * 20.0) * 1.3 if swing_left > 0 else 0.0
 ring.visible = not dead
 health_label.visible = not dead
 var role: String = {"hero":"风厉","minion":"","elite":"精英","boss":"试炼守卫"}[actor_kind]
 health_label.text = "%s  %d / %d" % [role, ceili(state.hp), ceili(state.max_hp)]
 health_label.modulate = Color("8ffff0") if actor_kind == "hero" else Color("ffcc9b")
 if is_instance_valid(animation_player):
  if dead and not dead_seen and animation_player.has_animation("death"): animation_player.play("death")
  if not dead and dead_seen and animation_player.has_animation("idle"): animation_player.play("idle")
  if not dead and (not animation_player.is_playing() or animation_player.current_animation in ["idle","run"]):
   var locomotion: String = "run" if moving else "idle"
   if animation_player.has_animation(locomotion) and animation_player.current_animation != locomotion: animation_player.play(locomotion)
 dead_seen = dead
 if actor_kind != "hero": _sync_warning(state)
 elif state.get("overload_left",0) > 0:
  ring.scale = Vector3.ONE * (1.3 + sin(Time.get_ticks_msec() * 0.01) * 0.1)
 else: ring.scale = Vector3.ONE

func _sync_warning(state: Dictionary) -> void:
 warning.visible = state.state == "warning" and not state.dead
 if not warning.visible: return
 var range_value: float = {"minion":1.8,"elite":2.8,"boss":4.2}[actor_kind]
 var progress: float = state.warning_progress
 var color = Color(1.0,0.22 + (1.0-progress)*0.35,0.12,0.22 + progress*0.4)
 warning.material_override = make_material(color, true)
 warning.global_rotation = Vector3.ZERO
 if state.attack_shape == "cone":
  var mesh = ImmediateMesh.new()
  mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
  var half_angle: float = acos(0.45)
  for index in range(24):
   var a: float = -half_angle + 2.0*half_angle*index/24.0
   var b: float = -half_angle + 2.0*half_angle*(index+1)/24.0
   mesh.surface_add_vertex(Vector3.ZERO)
   mesh.surface_add_vertex(state.aim.rotated(Vector3.UP,a)*range_value)
   mesh.surface_add_vertex(state.aim.rotated(Vector3.UP,b)*range_value)
  mesh.surface_end()
  warning.mesh = mesh
  warning.global_position = state.position + Vector3(0,0.04,0)
 else:
  var circle = CylinderMesh.new()
  circle.top_radius = range_value * 0.65
  circle.bottom_radius = circle.top_radius
  circle.height = 0.025
  warning.mesh = circle
  warning.global_position = state.target_point + Vector3(0,0.045,0)

func play_event(event: Dictionary) -> void:
 if event.kind in ["damage","hero_damaged"]: flash_left = 0.12
 if event.kind == "attack_started": swing_left = 0.28
 var animation: String = {"attack_started":"attack","dash":"dash","q1":"thrust","q2_hit":"thrust","q3_wave":"attack","e2_spin":"attack","r2_throw":"ultimate","overload_started":"overload","ultimate_started":"ultimate","hero_damaged":"hit","kill":"death"}.get(event.kind, "")
 if not animation.is_empty() and is_instance_valid(animation_player) and animation_player.has_animation(animation):
  var duration: float = {"attack_started":0.28,"dash":0.16,"q1":0.20,"ultimate_started":1.1}.get(event.kind,0.0)
  var speed: float = animation_player.get_animation(animation).length / duration if duration > 0 else 1.0
  animation_player.play(animation,-1,speed)

static func make_material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
 var result = StandardMaterial3D.new()
 result.albedo_color = color
 result.roughness = 0.8
 result.cull_mode = BaseMaterial3D.CULL_DISABLED
 if color.a < 1: result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 if unshaded:
  result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 return result

static func mesh_node(mesh: Mesh, mat: Material, parent: Node3D) -> MeshInstance3D:
 var result = MeshInstance3D.new()
 result.mesh = mesh
 result.material_override = mat
 parent.add_child(result)
 return result

func set_visual_scene(scene: PackedScene) -> void:
 # Optional integration boundary: art owns scene/rig, this adapter owns playback only.
 imported_art = true
 visual.rotation = Vector3.ZERO
 visual.position = Vector3.ZERO
 for child in visual.get_children():
  visual.remove_child(child)
  child.queue_free()
 var instance: Node = scene.instantiate()
 visual.add_child(instance)
 animation_player = _find_animation_player(instance)
 blade = null
 if animation_player:
  for clip in ["idle","run"]:
   if animation_player.has_animation(clip): animation_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR

func _find_animation_player(node: Node) -> AnimationPlayer:
 if node is AnimationPlayer: return node
 for child in node.get_children():
  var result: AnimationPlayer = _find_animation_player(child)
  if result: return result
 return null
