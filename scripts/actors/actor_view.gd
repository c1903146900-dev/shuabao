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
 position = state.position
 var facing: Vector3 = state.get("facing", state.get("aim", Vector3.FORWARD))
 if facing.length_squared() > 0.001: rotation.y = atan2(-facing.x, -facing.z)
 flash_left = maxf(0.0, flash_left - dt)
 swing_left = maxf(0.0, swing_left - dt)
 material.albedo_color = Color.WHITE if flash_left > 0 else body_color
 var dead: bool = state.get("dead", false)
 visual.rotation.z = lerpf(visual.rotation.z, 1.5 if dead else 0.0, minf(1.0, dt * 12.0))
 visual.position.y = -0.2 if dead else sin(Time.get_ticks_msec() * 0.004) * 0.025
 blade.rotation.y = sin(swing_left * 20.0) * 1.3 if swing_left > 0 else 0.0
 ring.visible = not dead
 health_label.visible = not dead
 var role: String = {"hero":"风厉","minion":"","elite":"精英","boss":"试炼守卫"}[actor_kind]
 health_label.text = "%s  %d / %d" % [role, ceili(state.hp), ceili(state.max_hp)]
 health_label.modulate = Color("8ffff0") if actor_kind == "hero" else Color("ffcc9b")
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
 var animation: String = {"attack_started":"attack","dash":"dash","q1":"q1","overload_started":"e3","ultimate_started":"r1","hero_damaged":"hit","kill":"death"}.get(event.kind, "")
 if not animation.is_empty() and animation_player.has_animation(animation): animation_player.play(animation)

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
