extends Node3D
## Test-asset review only; warning geometry mirrors combat test dimensions, never applies damage.
var kinds := ["minion","elite","boss"]
var warnings := [.85,1.0,1.35]
var recovery := [1.1,1.1,1.6]
var models: Array[Node3D] = []
var players: Array[AnimationPlayer] = []
var labels: Array[Label3D] = []
var marks: Array[MeshInstance3D] = []
var hero: Node3D
func _ready() -> void:
 var env := WorldEnvironment.new()
 var e := Environment.new()
 e.background_mode = Environment.BG_COLOR
 e.background_color = Color(.10,.14,.17)
 e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 e.ambient_light_color = Color(.80,.86,.90)
 e.ambient_light_energy = .4
 env.environment = e
 add_child(env)
 var light := DirectionalLight3D.new()
 light.rotation_degrees = Vector3(-72,-25,0)
 light.light_energy = .7
 light.name = "ArtSun"
 light.shadow_blur = .2
 light.shadow_enabled = true
 light.shadow_bias = 0.0
 light.shadow_normal_bias = 0.0
 light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
 light.directional_shadow_max_distance = 30.0
 add_child(light)
 for x in range(-2,3):
  for z in range(-1,2):
   var tile: Node3D = load("res://assets/arena/training_tile.glb").instantiate()
   add_child(tile)
   tile.position = Vector3(x*4,0,z*4)
   for mesh in tile.find_children("*","MeshInstance3D",true,false):mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 for x in [-9.2,9.2]:
  for z in [-5.2,5.2]:
   var pier: Node3D = load("res://assets/arena/ruin_pier.glb").instantiate()
   add_child(pier)
   pier.position = Vector3(x,.01,z)
 for x in [-6.0,0.0,6.0]:
  var marker: Node3D = load("res://assets/arena/ruin_marker.glb").instantiate()
  add_child(marker)
  marker.position=Vector3(x,.01,5.4)
 var camera := Camera3D.new()
 camera.name = "ReviewCamera"
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 12.5
 camera.position = Vector3(1,11,-9)
 add_child(camera)
 camera.look_at(Vector3(0,.65,0))
 camera.current = true
 for i in range(3):
  var model: Node3D = load("res://assets/arena/enemies/"+kinds[i]+".glb").instantiate()
  model.name = kinds[i]
  add_child(model)
  model.position.x = 4.0-i*4.0
  models.append(model)
  var contact := preload("res://scenes/art/foot_contact.gd").new()
  add_child(contact)
  contact.setup(model,[.15,.18,.22][i],[.12,.15,.20][i])
  var ap := model.find_child("AnimationPlayer",true,false) as AnimationPlayer
  assert(ap!=null)
  players.append(ap)
  for clip in ["idle","walk","attack","windup","release","hit","death"]:assert(ap.has_animation(clip),kinds[i]+" missing "+clip)
  assert(absf(ap.get_animation("attack").length-warnings[i]-recovery[i])<.001)
  ap.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
  ap.get_animation("walk").loop_mode = Animation.LOOP_LINEAR
  var label := Label3D.new()
  label.text = ["MINION / HOOK","ELITE / SHIELD","TEST BOSS / MAUL"][i]
  label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
  label.font_size = 32
  label.pixel_size = .009
  label.position = model.position+Vector3(0,3.4,0)
  add_child(label)
  labels.append(label)
  marks.append(make_warning(i))
 hero = load("res://assets/fengli/fengli.glb").instantiate()
 hero.name = "ScaleReferenceFengli"
 add_child(hero)
 hero.position = Vector3(0,0,-2.2)
 var hero_ap := hero.find_child("AnimationPlayer",true,false) as AnimationPlayer
 hero_ap.play("idle")
 hero_ap.seek(0,true)
 hero_ap.pause()
 hero.visible = false
 var hero_contact := preload("res://scenes/art/foot_contact.gd").new()
 add_child(hero_contact)
 hero_contact.setup(hero)
 play_all("idle")
 print("ENEMY_IMPORT_OK ",inspect_assets())
func make_warning(i: int) -> MeshInstance3D:
 var node := MeshInstance3D.new()
 var material := StandardMaterial3D.new()
 material.albedo_color = Color(1,.25,.065,.26)
 material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 material.cull_mode = BaseMaterial3D.CULL_DISABLED
 if i==2:
  var mesh := ImmediateMesh.new()
  mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
  for j in range(36):
   var a := -acos(.45)+2*acos(.45)*j/36.0
   var b := -acos(.45)+2*acos(.45)*(j+1)/36.0
   mesh.surface_add_vertex(Vector3.ZERO)
   mesh.surface_add_vertex(Vector3.FORWARD.rotated(Vector3.UP,a)*4.2)
   mesh.surface_add_vertex(Vector3.FORWARD.rotated(Vector3.UP,b)*4.2)
  mesh.surface_end()
  node.mesh = mesh
  node.position = models[i].position+Vector3(0,.04,0)
 else:
  var mesh := CylinderMesh.new()
  mesh.top_radius = [1.8,2.8][i]*.65
  mesh.bottom_radius = mesh.top_radius
  mesh.height = .016
  node.mesh = mesh
  node.position = models[i].position+Vector3(0,.04,-1.1)
 node.material_override = material
 node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(node)
 return node
func play_all(clip: String) -> void:
 for ap in players:ap.play(clip)
func sample_phase(progress: float) -> Dictionary:
 for i in range(3):
  players[i].play("attack")
  players[i].seek(warnings[i]*progress,true)
  players[i].pause()
  marks[i].visible = progress<1.0 and models[i].visible
 return pose_status()
func sample_clip(clip: String,t: float) -> Dictionary:
 for ap in players:
  ap.play(clip)
  ap.seek(minf(t,ap.get_animation(clip).length),true)
  ap.pause()
 for mark in marks:mark.visible=false
 return pose_status()
func pose_status() -> Dictionary:
 var result := {}
 for i in range(3):
  var sk := models[i].find_child("Skeleton3D",true,false) as Skeleton3D
  result[kinds[i]] = {"time":players[i].current_animation_position,"playing":players[i].is_playing(),"forearm":str(sk.get_bone_pose_rotation(sk.find_bone("fore1"))),"chest":str(sk.get_bone_pose_rotation(sk.find_bone("chest")))}
 return result
func inspect_assets() -> Dictionary:
 var result := {}
 for i in range(3):
  var clips := {}
  for clip in players[i].get_animation_list():clips[clip]=players[i].get_animation(clip).length
  result[kinds[i]]=clips
 return result
func occlusion_test(behind: bool=false) -> void:
 for i in range(2):
  models[i].visible=false
  labels[i].visible=false
  marks[i].visible=false
 models[2].position=Vector3.ZERO
 labels[2].visible=false
 marks[2].position=Vector3(0,.04,0)
 hero.visible=true
 hero.position=Vector3(-.7,0,1.9 if behind else -1.9)
 var camera := get_node("ReviewCamera") as Camera3D
 camera.size=7.5
 camera.position=Vector3(1,11,-9)
 camera.look_at(Vector3(0,.65,0))

func combat_camera() -> void:
 for i in range(3):
  models[i].visible=true
  models[i].position=Vector3(4-i*4,0,0)
  models[i].rotation.y=PI
  labels[i].visible=false
  marks[i].position=models[i].position+Vector3(0,.04,0 if i==2 else 1.1)
  marks[i].rotation.y=PI
 hero.visible=true
 hero.position=Vector3(-4.7,0,2)
 var camera:=get_node("ReviewCamera") as Camera3D
 camera.size=27.0
 camera.position=Vector3(0,27,20)
 camera.look_at(Vector3.ZERO)

func contact_status() -> Dictionary:
 var out := {}
 for node in get_children():
  if node.get_script()==preload("res://scenes/art/foot_contact.gd"):
   var values:=[]
   if node.skeleton!=null:
    for index in node.indices:
     values.append(str(node.skeleton.global_transform*node.skeleton.get_bone_global_pose(index)))
   out[str(node.target.name)]={"skeleton":str(node.skeleton),"feet":values,"patches":node.patches.size()}
 return out
