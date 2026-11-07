extends SceneTree
# ISOLATED DRAWING UNIT TEST. Recorded copies only; never resumes or edits a run.
class FixtureSim extends Node:
 var clock:Dictionary={}
 var phase:String="combat"
 var room_id:String="fixture"
 var encounter_generation:int=8
 var real_time:float=0
 var enemies:Array=[]
class FixtureSession extends Node:
 var run_id:String="isolated-drawing-fixture"
class FixtureHost extends Node:
 var sim:Node
 var shop_session:Node
var elapsed:float=0
var made:bool=false
var views:Array=[]
var checked:bool=false
func _initialize()->void:root.add_child(load("res://boot.tscn").instantiate())
func decode_vector(v:Variant)->Variant:
 if v is String and v.begins_with("(") and v.ends_with(")"):
  var a:Array=v.substr(1,v.length()-2).split(",")
  if a.size()==3:return Vector3(float(a[0]),float(a[1]),float(a[2]))
 if v is Dictionary:
  for k in v:v[k]=decode_vector(v[k])
 if v is Array:
  for i in range(v.size()):v[i]=decode_vector(v[i])
 return v
func _process(dt:float)->bool:
 elapsed+=dt
 if elapsed>30:print("FIXTURE_FAIL timeout");quit(9);return false
 if not made:
  var boot=root.get_node_or_null("Boot")
  if boot==null or boot.get_children().is_empty():return false
  var production:Script=load("res://fengli_route_20261024/presentation.gd")
  if production==null:return false
  made=true
  for child in boot.get_children():
   if child is CanvasItem:child.hide()
  var background:=ColorRect.new();background.color=Color(0.025,0.03,0.05);background.size=Vector2(1280,720);root.add_child(background)
  var data:Variant=decode_vector(JSON.parse_string(FileAccess.get_file_as_string("user://boss_motion/recorded_fixture.json")))
  var script:=GDScript.new()
  script.source_code="extends \"res://fengli_route_20261024/presentation.gd\"\nvar specimen:Dictionary={}\nvar label:String=\"\"\nfunc p(point:Vector3)->Vector2:return Vector2(100,155)+Vector2(point.x-specimen.position.x,point.z-specimen.position.z)*20\nfunc _process(_dt:float)->void:pass\nfunc _draw()->void:\n draw_rect(Rect2(0,0,200,230),Color(0.07,0.08,0.13))\n draw_string(ThemeDB.fallback_font,Vector2(10,25),label,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)\n draw_line(Vector2(35,155),Vector2(165,155),Color(0.3,0.5,0.5),1)\n receipt={};body_pick_regions.clear();_draw_enemy(specimen)\n"
  if script.reload()!=OK:print("FIXTURE_FAIL script");quit(9);return false
  for i in range(data.size()):
   var row:Dictionary=data[i]
   var host:=FixtureHost.new();var sim:=FixtureSim.new();var session:=FixtureSession.new();root.add_child(host);host.add_child(sim);host.add_child(session);host.sim=sim;host.shop_session=session
   sim.clock={"world_time":row.world_time};sim.real_time=row.real_time;sim.enemies=[row.enemy];sim.room_id=str(row.enemy.room_id)
   var view:Node2D=script.new();view.host=host;view.specimen=row.enemy;view.label=str(row.label)+" / recorded "+str(row.frame);view.position=Vector2(30+i*300,150);view.scale=Vector2(1.4,1.4)
   var img:=Image.new();img.load_png_from_buffer(FileAccess.get_file_as_bytes("res://neon_cartoon_20261021/assets/boss.png"));view.textures.boss=ImageTexture.create_from_image(img)
   var meta:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://neon_cartoon_20261021/assets/enemy_regions.json"));view.enemy_asset_meta=meta;var a:Array=meta.boss.region;view.used.boss=Rect2i(a[0],a[1],a[2],a[3]);view.active=true;view.body_pick_scope=view._current_scope()
   if not row.release.is_empty():view.boss_body_releases[str(row.enemy.actor_id)]=row.release
   root.add_child(view);views.append(view);view.queue_redraw()
  var title:=Label.new();title.text="ISOLATED DRAWING TEST - recorded copies, NOT live Boss gameplay";title.position=Vector2(30,65);root.add_child(title)
  elapsed=0;return false
 if elapsed>1 and not checked:
  checked=true
  var ok:bool=true
  for view in views:
   var hit:Vector3=view.body_aim_at(Vector2(100,120));var empty:Vector3=view.body_aim_at(Vector2(10,210))
   var good:bool=hit==view.specimen.position and empty==Vector3.INF and view.visual_errors.is_empty()
   ok=ok and good
   print("FIXTURE_ROW ",view.label," check=",good," pose=",JSON.stringify(view.receipt.get("boss_body_motion",[])))
  root.get_texture().get_image().save_png("user://boss_motion/draw_fixture.png")
  print("FIXTURE_DONE ",ok," not_live_gameplay=true");quit(0 if ok else 9)
 return false
