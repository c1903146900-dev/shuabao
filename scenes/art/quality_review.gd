extends Node3D
## Side-by-side visual regression scene. V1 is retained deliberately as a reference.
var players: Array[AnimationPlayer] = []
var figures: Array[Node3D] = []
var current_clip := "idle"
func _ready() -> void:
 var env := WorldEnvironment.new()
 var e := Environment.new()
 e.background_mode = Environment.BG_COLOR
 e.background_color = Color(.09,.13,.16)
 e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 e.ambient_light_color = Color(.8,.86,.9)
 e.ambient_light_energy = .4
 env.environment = e
 add_child(env)
 var light := DirectionalLight3D.new()
 light.rotation_degrees = Vector3(-50,-25,0)
 light.light_energy = .7
 light.shadow_enabled = true
 light.shadow_bias = .02
 light.shadow_normal_bias = .1
 add_child(light)
 for x in range(-1,2):
  for z in range(-1,2):
   var tile: Node3D = load("res://assets/arena/training_tile.glb").instantiate()
   add_child(tile)
   tile.position = Vector3(x*4,0,z*4)
   for mesh in tile.find_children("*","MeshInstance3D",true,false):
    mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var camera := Camera3D.new()
 camera.name = "ReviewCamera"
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 7.3
 camera.position = Vector3(1,7,-8)
 add_child(camera)
 camera.look_at(Vector3(0,.65,0))
 camera.current = true
 for i in range(2):
  var path := "res://assets/fengli/reference/fengli_v1.glb" if i==0 else "res://assets/fengli/fengli.glb"
  var model: Node3D = load(path).instantiate()
  model.name = "Before" if i==0 else "After"
  add_child(model)
  model.position = Vector3(1.65 if i==0 else -1.65,0,0)
  figures.append(model)
  var ap := model.find_child("AnimationPlayer",true,false) as AnimationPlayer
  players.append(ap)
  for clip in ["idle","run"]:ap.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
  var label := Label3D.new()
  label.text = "V1 / BEFORE" if i==0 else "V2 / AFTER"
  label.font_size = 40
  label.pixel_size = .008
  label.position = Vector3(model.position.x,2.35,0)
  label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
  add_child(label)
 sample("idle",0)
func sample(clip: String,t: float,travel: bool=false) -> String:
 current_clip = clip
 for i in range(2):
  var ap := players[i]
  ap.play(clip)
  ap.seek(t,true)
  ap.pause()
  figures[i].position.z = -2.0*t if travel and clip=="run" else 0.0
 return clip+" @ "+str(t)+" travel="+str(travel)
func side_view() -> void:
 var camera := get_node("ReviewCamera") as Camera3D
 camera.position = Vector3(5,3,-7)
 camera.look_at(Vector3(0,.8,0))
func inspect_pose() -> Dictionary:
 var result := {}
 for i in range(2):
  var sk := figures[i].find_child("Skeleton3D",true,false) as Skeleton3D
  var bone := sk.find_bone("foot1")
  result[str(i)] = {"foot_world":str(sk.global_transform * sk.get_bone_global_pose(bone).origin),"clip":players[i].assigned_animation,"position":players[i].current_animation_position}
 return result
