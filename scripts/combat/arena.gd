extends Node3D
const Sim = preload("res://scripts/combat/combat_sim.gd")
const View = preload("res://scripts/actors/actor_view.gd")
const HUD = preload("res://scripts/combat/debug_hud.gd")
const T = preload("res://data/combat/tuning.gd")
@export var hero_visual: PackedScene
@export var minion_visual: PackedScene
@export var elite_visual: PackedScene
@export var boss_visual: PackedScene
signal actor_view_created(actor_id: String, view: Node3D)
var simulation: Node
var camera: Camera3D
var hud: Control
var views: Dictionary = {}
var held_keys: Dictionary = {}
var mouse_at: Vector2 = Vector2(640,300)
var effects: Array = []
var manual_step: bool = false
var elapsed: float = 0.0
var demonstration: bool = false
var demo_stage: int = 0
var preset_index: int = 0
const TEST_PRESETS = [
 {"q":"q1","e":"e3","r":"r1","passive":"p3"},
 {"q":"q2","e":"e1","r":"r2","passive":"p1"},
 {"q":"q3","e":"e2","r":"r1","passive":"p2"}
]
var dagger_visual: MeshInstance3D
var mark_visual: MeshInstance3D

func _ready() -> void:
 _build_arena()
 new_run()
 print("FENGLI_COMBAT_READY version=",T.VERSION)

func _build_arena() -> void:
 var environment = WorldEnvironment.new()
 var env = Environment.new()
 env.background_mode = Environment.BG_COLOR
 env.background_color = Color("071017")
 env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color = Color("8aafb3")
 env.ambient_light_energy = 0.35
 env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
 environment.environment = env
 add_child(environment)
 var light = DirectionalLight3D.new()
 light.rotation_degrees = Vector3(-55,-30,0)
 light.light_color = Color("bbebe7")
 light.light_energy = 0.8
 light.shadow_enabled = true
 add_child(light)
 camera = Camera3D.new()
 camera.name = "CombatCamera"
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 27.0
 camera.position = Vector3(0,27,20)
 add_child(camera)
 camera.look_at(Vector3.ZERO)
 camera.current = true
 var floor_mesh = BoxMesh.new()
 floor_mesh.size = Vector3(28,0.3,28)
 var floor_view = View.mesh_node(floor_mesh, View.make_material(Color("14272e")), self)
 floor_view.position.y = -0.18
 for i in range(-7,8):
  for j in range(-7,8):
   if (i+j)%2 != 0: continue
   var tile = BoxMesh.new()
   tile.size = Vector3(1.97,0.025,1.97)
   var tile_node = View.mesh_node(tile, View.make_material(Color("182e34")), self)
   tile_node.position = Vector3(i*2, -0.009, j*2)
 for pos in [Vector3(-14,0,0),Vector3(14,0,0),Vector3(0,0,-14),Vector3(0,0,14)]:
  var wall = BoxMesh.new()
  wall.size = Vector3(0.45,0.55,28.5) if pos.x != 0 else Vector3(28.5,0.55,0.45)
  var n = View.mesh_node(wall, View.make_material(Color("41625f")), self)
  n.position = pos
 for radius in [5.0,10.0]:
  var ring = TorusMesh.new()
  ring.inner_radius = radius-0.025
  ring.outer_radius = radius+0.025
  ring.ring_segments = 6
  ring.rings = 96
  var n = View.mesh_node(ring,View.make_material(Color("315452"),true),self)
  n.position.y = 0.015
 for x in [-12,12]:
  for z in [-12,12]:
   var pillar = BoxMesh.new()
   pillar.size = Vector3(0.8,2,0.8)
   var n = View.mesh_node(pillar,View.make_material(Color("496362")),self)
   n.position = Vector3(x,0.9,z)
 var layer = CanvasLayer.new()
 layer.name = "TemporaryCombatHUD"
 add_child(layer)
 hud = HUD.new()
 layer.add_child(hud)

func new_run() -> void:
 if is_instance_valid(simulation):
  remove_child(simulation)
  simulation.queue_free()
 for v in views.values(): v.queue_free()
 views.clear()
 for effect in effects: effect.node.queue_free()
 effects.clear()
 simulation = Sim.new()
 simulation.name = "CombatSimulation"
 add_child(simulation)
 simulation.combat_event.connect(_on_combat_event)
 for pos in T.TEST_MINION_POSITIONS:
  simulation.spawn_enemy("minion",pos)
 simulation.spawn_enemy("elite",Vector3(-5,0,-7))
 simulation.spawn_enemy("elite",Vector3(5,0,-8))
 simulation.spawn_enemy("boss",Vector3(0,0,-10))
 simulation.configure_test_loadout(TEST_PRESETS[preset_index])
 elapsed = 0
 demo_stage = 0
 _sync_views(0)

func _unhandled_input(event: InputEvent) -> void:
 if event is InputEventMouseMotion: mouse_at = event.position
 if event is InputEventKey:
  var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
  held_keys[key] = event.pressed
  if not event.pressed or event.echo: return
  match key:
   KEY_Q: simulation.request_action("q",_aim_point())
   KEY_E: simulation.request_action("e",_aim_point())
   KEY_R: simulation.request_action("r",_aim_point())
   KEY_SHIFT: simulation.request_action("shift",_aim_point())
   KEY_F5: new_run()
   KEY_F6:
    preset_index = (preset_index+1)%TEST_PRESETS.size()
    new_run()
   KEY_H: hud.visible = not hud.visible
   KEY_SPACE: simulation.self_rescue()
 if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
  mouse_at = event.position
  simulation.request_action("attack",_aim_point())

func _physics_process(dt: float) -> void:
 if not is_instance_valid(simulation): return
 if not manual_step and simulation.phase == "combat":
  simulation.hero.move_intent = Vector3(float(held_keys.get(KEY_D,false))-float(held_keys.get(KEY_A,false)),0,float(held_keys.get(KEY_S,false))-float(held_keys.get(KEY_W,false))).limit_length(1)
  var aim: Vector3 = _aim_point()
  if not demonstration and not simulation.r1_active and simulation.hero.lock_time <= 0:
   var direction: Vector3 = aim - simulation.hero.position
   if direction.length_squared() > 0.01: simulation.hero.facing = direction.normalized()
  if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): simulation.request_action("attack",aim)
  if demonstration: _demo(dt)
  simulation.step(dt)
 _sync_views(0.0 if manual_step else dt)
 if not manual_step: _step_effects(dt)

func _aim_point() -> Vector3:
 var origin: Vector3 = camera.project_ray_origin(mouse_at)
 var direction: Vector3 = camera.project_ray_normal(mouse_at)
 var point = Plane(Vector3.UP,0).intersects_ray(origin,direction)
 return point if point != null else simulation.hero.position+simulation.hero.facing

func _sync_views(dt: float) -> void:
 var state: Dictionary = simulation.snapshot()
 var present: Array = ["fengli"]
 for enemy in state.enemies: present.append(enemy.actor_id)
 for id in views.keys():
  if not id in present:
   views[id].queue_free()
   views.erase(id)
 if not views.has("fengli"):
  var view = View.new()
  view.name = "Fengli"
  add_child(view)
  view.setup("hero")
  if hero_visual: view.set_visual_scene(hero_visual)
  views.fengli = view
  actor_view_created.emit("fengli",view)
 views.fengli.sync(state.hero,dt)
 for enemy in state.enemies:
  if not views.has(enemy.actor_id):
   var view = View.new()
   view.name = enemy.actor_id
   add_child(view)
   view.setup(enemy.kind)
   var art: PackedScene = {"minion":minion_visual,"elite":elite_visual,"boss":boss_visual}[enemy.kind]
   if art: view.set_visual_scene(art)
   views[enemy.actor_id] = view
   actor_view_created.emit(enemy.actor_id,view)
  views[enemy.actor_id].sync(enemy,dt)
 hud.update_snapshot(state)
 _sync_skill_markers(state)

func _on_combat_event(event: Dictionary) -> void:
 var target: String = event.get("target","fengli") if event.kind in ["damage","kill"] else "fengli"
 if views.has(target): views[target].play_event(event)
 match event.kind:
  "q1", "q3_wave", "r2_throw":
   var box = BoxMesh.new()
   box.size = Vector3(event.width,0.06,event.length)
   var n = View.mesh_node(box,View.make_material(Color(0.2,1,0.86,0.65),true),self)
   n.position = event.position+event.direction*event.length*0.5+Vector3(0,0.5,0)
   n.rotation.y = atan2(-event.direction.x,-event.direction.z)
   effects.append({"node":n,"life":0.22,"total":0.22,"type":"slash"})
  "damage":
   var label = Label3D.new()
   label.text = str(ceili(event.amount)) + ("!" if event.critical else "")
   label.font_size = 54 if event.critical else 40
   label.pixel_size = 0.01
   label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
   label.modulate = Color("80ffe3") if event.damage_type == "true" else Color("fff2c6")
   label.no_depth_test = true
   label.outline_size = 10
   add_child(label)
   label.position = event.position + Vector3(randf_range(-0.3,0.3),2.0,0)
   effects.append({"node":label,"life":0.65,"total":0.65,"type":"number"})
  "ultimate_started", "ultimate_impact", "e2_spin":
   var ring = TorusMesh.new()
   ring.inner_radius = event.radius-0.12
   ring.outer_radius = event.radius+0.12
   ring.rings = 96
   ring.ring_segments = 8
   var n = View.mesh_node(ring,View.make_material(Color("92fff0"),true),self)
   n.position = event.position + Vector3(0,0.10,0)
   effects.append({"node":n,"life":1.0,"total":1.0,"type":"ultimate"})
   if event.kind == "ultimate_impact":
    for index in range(18):
     var slash = BoxMesh.new()
     slash.size = Vector3(0.045,0.08,randf_range(2,5))
     var n2 = View.mesh_node(slash,View.make_material(Color("b7fff2"),true),self)
     var angle: float = index*TAU/18
     n2.position = event.position + Vector3(sin(angle),0,cos(angle))*randf_range(1,8)+Vector3(0,0.8,0)
     n2.rotation.y = angle + 0.6
     effects.append({"node":n2,"life":0.5,"total":0.5,"type":"slash"})
  "dash", "q2_hit", "e2_blink", "e1_pierce":
   var circle = CylinderMesh.new()
   circle.top_radius = 0.5
   circle.bottom_radius = 0.5
   circle.height = 0.02
   var n = View.mesh_node(circle,View.make_material(Color(0.25,1,0.9,0.6),true),self)
   n.position = event.position+Vector3(0,0.05,0)
   effects.append({"node":n,"life":0.4,"total":0.4,"type":"slash"})

func _step_effects(dt: float) -> void:
 for effect in effects.duplicate():
  effect.life -= dt
  if effect.life <= 0:
   effect.node.queue_free()
   effects.erase(effect)
  elif effect.type == "number":
   effect.node.position.y += dt*1.3
   effect.node.modulate.a = effect.life/effect.total
  elif effect.type == "ultimate": effect.node.scale = Vector3.ONE*(1.0+0.1*(1-effect.life/effect.total))

func get_combat_snapshot() -> Dictionary:
 return simulation.snapshot()

func set_demo(enabled: bool) -> void:
 demonstration = enabled
 elapsed = 0
 demo_stage = 0

func _demo(dt: float) -> void:
 if simulation.phase != "combat": return
 elapsed += dt
 var targets: Array = simulation.living()
 if targets.is_empty(): return
 targets.sort_custom(func(a,b): return a.position.distance_to(simulation.hero.position)<b.position.distance_to(simulation.hero.position))
 var point: Vector3 = targets[0].position
 simulation.hero.facing = simulation.hero.position.direction_to(point)
 simulation.hero.move_intent = simulation.hero.facing if simulation.hero.position.distance_to(point)>2.0 else Vector3.ZERO
 simulation.request_action("attack",point)
 if elapsed>1.0: simulation.request_action("e",point)
 if elapsed>2.0: simulation.request_action("q",point)
 if elapsed>4.0 and elapsed<4.4: simulation.request_action("shift",point)
 if elapsed>6.0: simulation.request_action("r",point)

func _sync_skill_markers(state: Dictionary) -> void:
 if not is_instance_valid(dagger_visual):
  var mesh = SphereMesh.new()
  mesh.radius = 0.16
  mesh.height = 0.32
  dagger_visual = View.mesh_node(mesh,View.make_material(Color("feeb99"),true),self)
  var ring = TorusMesh.new()
  ring.inner_radius = 0.8
  ring.outer_radius = 0.9
  mark_visual = View.mesh_node(ring,View.make_material(Color("ffdf67"),true),self)
 dagger_visual.visible = false
 mark_visual.visible = false
 if state.hero.cast_state.has("e1"):
  var skill: Dictionary = state.hero.cast_state.e1
  if skill.stage == "flying":
   dagger_visual.visible = true
   dagger_visual.position = skill.position + Vector3(0,0.9,0)
  elif skill.stage == "marked":
   var target: Dictionary = simulation.enemy_by_id(skill.target)
   if not target.is_empty() and not target.dead:
    mark_visual.visible = true
    mark_visual.position = target.position + Vector3(0,0.12,0)

func _notification(what: int) -> void:
 if what == NOTIFICATION_APPLICATION_FOCUS_OUT: held_keys.clear()
