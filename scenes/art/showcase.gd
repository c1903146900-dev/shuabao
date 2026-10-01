extends Node3D
## Art-only review harness. No combat, UI, or autoload dependencies.
var models: Array[Node] = []
var players: Array[AnimationPlayer] = []
var names: Array[String] = ["idle", "run", "attack", "dash", "thrust", "overload", "ultimate", "hit", "death"]
var elapsed := 0.0
var current_clip := "idle"
func _ready() -> void:
 var env := WorldEnvironment.new()
 var e := Environment.new()
 e.background_mode = Environment.BG_COLOR
 e.background_color = Color(0.12,0.17,0.20)
 e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 e.ambient_light_color = Color(0.76,0.86,0.92)
 e.ambient_light_energy = 0.35
 e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
 env.environment = e
 add_child(env)
 var sun := DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-72,-25,0)
 sun.light_energy = 0.65
 sun.name = "ArtSun"
 sun.shadow_blur = .2
 sun.shadow_enabled = true
 sun.shadow_bias = 0.0
 sun.shadow_normal_bias = 0.0
 sun.directional_shadow_max_distance = 25.0
 sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
 add_child(sun)
 var camera := Camera3D.new()
 camera.name = "ReviewCamera"
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 11.8
 camera.position = Vector3(6,9,-9)
 add_child(camera)
 camera.look_at(Vector3(0,0.4,0))
 camera.current = true
 for x in range(-1,2):
  for z in range(-1,2):
   var tile: Node3D = load("res://assets/arena/training_tile.glb").instantiate()
   add_child(tile)
   tile.position = Vector3(x*4,0,z*4)
   for mesh in tile.find_children("*","MeshInstance3D",true,false):
    mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var hero: Node3D = load("res://assets/fengli/fengli.glb").instantiate()
 hero.name = "FengliVisual"
 add_child(hero)
 hero.position = Vector3(-1,0,0)
 models.append(hero)
 var contact := preload("res://scenes/art/foot_contact.gd").new()
 contact.name = "FootContact"
 add_child(contact)
 contact.setup(hero)
 var ap := hero.find_child("AnimationPlayer",true,false) as AnimationPlayer
 if ap:
  players.append(ap)
  print("ART_IMPORT_OK clips=",ap.get_animation_list())
  for clip in names:
   assert(ap.has_animation(clip),"Missing imported animation: "+clip)
   print("ART_CLIP ",clip," length=",ap.get_animation(clip).length," tracks=",ap.get_animation(clip).get_track_count())
  ap.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
  ap.get_animation("run").loop_mode = Animation.LOOP_LINEAR
  play_clip("idle")
 for i in range(2):
  var enemy: Node3D = load("res://assets/arena/enemies/"+("minion" if i==0 else "elite")+".glb").instantiate()
  add_child(enemy)
  enemy.position = Vector3(2.1,0,(-1.5 if i==0 else 1.2))
  enemy.rotation.y = -0.5
  var enemy_ap := enemy.find_child("AnimationPlayer",true,false) as AnimationPlayer
  enemy_ap.play("idle")
  enemy_ap.seek(0,true)
  enemy_ap.pause()
  var enemy_contact := preload("res://scenes/art/foot_contact.gd").new()
  add_child(enemy_contact)
  enemy_contact.setup(enemy,[.15,.18][i],[.13,.16][i])
 for x in [-5.3,5.3]:
  for z in [-5.3,5.3]:
   var pier: Node3D = load("res://assets/arena/ruin_pier.glb").instantiate()
   add_child(pier)
   pier.position = Vector3(x,.01,z)
 for x in [-3.5,3.5]:
  var marker: Node3D = load("res://assets/arena/ruin_marker.glb").instantiate()
  add_child(marker)
  marker.position = Vector3(x,.01,5.4)
 # restrained telegraph sample remains visible around the elite
 var ring := MeshInstance3D.new()
 var torus := TorusMesh.new()
 torus.inner_radius = .88
 torus.outer_radius = .94
 torus.rings = 48
 torus.ring_segments = 6
 ring.mesh = torus
 var ink := StandardMaterial3D.new()
 ink.albedo_color = Color(.9,.29,.08)
 ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 ring.material_override = ink
 ring.position = Vector3(2.1,.045,1.2)
 ring.scale.y = .2
 add_child(ring)
func play_clip(clip: String) -> String:
 current_clip = clip
 for ap in players:
  ap.play(clip)
 return current_clip
func sample_clip(clip: String, t: float) -> String:
 for ap in players:
  ap.play(clip)
  ap.seek(t,true)
  ap.pause()
 return clip+" @ "+str(t)
func inspect_art() -> Dictionary:
 var result := {}
 for ap in players:
  for clip in names:
   result[clip] = {"duration":ap.get_animation(clip).length,"tracks":ap.get_animation(clip).get_track_count()}
 return result
func _process(delta: float) -> void:
 elapsed += delta
 # Review reel: independent clips with reset between actions.
 var index := int(elapsed / 3.0) % names.size()
 if current_clip != names[index]: play_clip(names[index])
 for ap in players:
  if not ap.is_playing() and current_clip in ["idle","run"]: ap.play(current_clip)

func closeup() -> void:
 var camera := get_node("ReviewCamera") as Camera3D
 camera.size = 4.8
 camera.position = Vector3(3,3.0,-5)
 camera.look_at(Vector3(-1,.9,0))
func pose_evidence() -> Dictionary:
 var ap := players[0]
 var skeleton := models[0].find_child("Skeleton3D",true,false) as Skeleton3D
 var result := {"clip":ap.current_animation,"time":ap.current_animation_position,"playing":ap.is_playing(),"bones":{}}
 for bone in ["chest","upper1","fore1","thigh1","shin1","weapon"]:
  result.bones[bone] = str(skeleton.get_bone_pose_rotation(skeleton.find_bone(bone)))
 return result

func foot_mesh_evidence() -> Dictionary:
 var result := {}
 for mesh in models[0].find_children("*","MeshInstance3D",true,false):
  if "Toe" in mesh.name:
   var baked: ArrayMesh = mesh.bake_mesh_from_current_skeleton_pose()
   var bounds := baked.get_aabb()
   var low := 100.0
   for i in range(8): low = minf(low,(mesh.global_transform * bounds.get_endpoint(i)).y)
   result[mesh.name] = low
 return result

func runtime_sole_probe() -> Dictionary:
 var result := {}
 for node in models[0].find_children("*","MeshInstance3D",true,false):
  if "boot" in node.name.to_lower() or "sabaton" in node.name.to_lower():
   var baked: ArrayMesh = node.bake_mesh_from_current_skeleton_pose()
   var low := 100.0
   for surface in range(baked.get_surface_count()):
    var vertices: PackedVector3Array = baked.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
    for vertex in vertices:low=minf(low,(node.global_transform*vertex).y)
   result[str(node.name)]=low
 return result
