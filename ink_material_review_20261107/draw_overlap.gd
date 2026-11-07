extends SceneTree
# SYNTHETIC DRAW ROBUSTNESS FIXTURE, NOT recorded or live gameplay.
# Does not create/modify production enemies, zones, run state or damage.
# The parent launches this only after its engine guard permits it.
const OUTPUT := "/workspace/scratch/73ebae91a474/ink_material_review_20261107/overlap_fixture.png"
class FixtureSim extends Node:
 var room_id:String="synthetic-overlap-fixture"
 var encounter_generation:int=1
class FixtureSession extends Node:
 var run_id:String="synthetic-overlap-fixture"
class FixtureHost extends Node:
 var sim:Node
 var shop_session:Node
class SyntheticReader extends RefCounted:
 var error:String=""
 var zones:Array=[]
 var calls:int=0
 func current(_sim:Variant,_run_id:String)->Array:
  calls+=1
  return zones
var elapsed:float=0.0
var made:bool=false
var checked:bool=false
var views:Array=[]
var readers:Array=[]
var originals:Array=[]
func _initialize()->void:
 root.add_child(load("res://boot.tscn").instantiate())
func fail(reason:String)->void:
 print("OVERLAP_FIXTURE_FAIL ",reason)
 quit(9)
func _process(dt:float)->bool:
 elapsed+=dt
 if elapsed>30.0:fail("timeout");return false
 if not made:
  var boot:Node=root.get_node_or_null("Boot")
  if boot==null or boot.get_children().is_empty():return false
  var production:Script=load("res://fengli_route_20261024/presentation.gd")
  if production==null:return false
  made=true
  for child in boot.get_children():
   if child is CanvasItem:child.hide()
  var background:=ColorRect.new()
  background.color=Color(0.025,0.03,0.05);background.size=Vector2(1280,720)
  root.add_child(background)
  var script:=GDScript.new()
  # Override only fixture projection/frame setup. The material draw algorithm is inherited.
  script.source_code="""extends "res://fengli_route_20261024/presentation.gd"
var fixture_label:String=""
func p(point:Vector3)->Vector2:
 return Vector2(190,230)+Vector2(point.x*57.0,point.z*37.0)
func _process(_dt:float)->void:pass
func _draw()->void:
 draw_rect(Rect2(0,0,390,440),Color(0.12,0.14,0.18))
 for x:int in range(10,390,20):draw_line(Vector2(x,60),Vector2(x,400),Color(0.21,0.24,0.28),1.0)
 for y:int in range(60,401,20):draw_line(Vector2(10,y),Vector2(380,y),Color(0.21,0.24,0.28),1.0)
 # Synthetic player-ground color patch drawn BEFORE actual inherited ink drawing.
 draw_rect(Rect2(75,175,230,110),Color(0.18,0.72,0.68,0.70))
 draw_line(Vector2(75,230),Vector2(305,230),Color(0.65,1.0,0.89),3.0)
 receipt={}
 _draw_pitcher_zones()
 draw_string(ThemeDB.fallback_font,Vector2(15,30),fixture_label,HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color.WHITE)
 draw_string(ThemeDB.fallback_font,Vector2(15,425),"Grid + synthetic player-ground patch",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
"""
  if script.reload()!=OK:fail("subclass_compile");return false
  var positions:Array=[Vector3(-0.65,0,0),Vector3(0.65,0,0),Vector3(0,0,0.70)]
  for count:int in range(1,4):
   var host:=FixtureHost.new();var sim:=FixtureSim.new();var session:=FixtureSession.new()
   root.add_child(host);host.add_child(sim);host.add_child(session)
   host.sim=sim;host.shop_session=session
   var reader:=SyntheticReader.new()
   for index:int in range(count):
    reader.zones.append({"owner":"SYNTHETIC_pitcher_%d"%index,"position":Vector3.ZERO if count==1 else positions[index],"radius":1.45,"left":2.4})
   originals.append(reader.zones.duplicate(true));readers.append(reader)
   var view:Node2D=script.new()
   view.host=host;view.pitcher_zones=reader;view.fixture_label="%d synthetic source-sized pool(s)"%count
   view.position=Vector2(30+(count-1)*410,150)
   root.add_child(view);views.append(view);view.queue_redraw()
  var title:=Label.new();title.text="SYNTHETIC OVERLAP ROBUSTNESS TEST - actual inherited ink draw, NOT live gameplay"
  title.position=Vector2(30,45);root.add_child(title)
  var note:=Label.new();note.text="Normal rooms have one pitcher. This does not establish that three pools coexist in gameplay.\nFixture bypasses zone registration; lifecycle, damage, actor/warning visibility are tested separately."
  note.position=Vector2(30,80);root.add_child(note)
  elapsed=0.0;return false
 if elapsed>1.0 and not checked:
  checked=true
  var ok:bool=true
  for index:int in range(views.size()):
   var view:Node2D=views[index]
   var reader:SyntheticReader=readers[index]
   var unchanged:bool=reader.zones==originals[index]
   var good:bool=view.visual_errors.is_empty() and reader.error.is_empty() and reader.calls>0 and unchanged and view.receipt.get("hostile_zones",[]).size()==index+1
   ok=ok and good
   print("OVERLAP_FIXTURE_PANEL count=",index+1," ok=",good," sources_unchanged=",unchanged," errors=",view.visual_errors)
  var image:Image=root.get_texture().get_image()
  if image==null or image.is_empty():fail("capture_empty");return false
  var saved:Error=image.save_png(OUTPUT)
  ok=ok and saved==OK
  print("OVERLAP_FIXTURE_DONE ",ok," synthetic=true live_gameplay=false output=",OUTPUT," save_error=",saved)
  quit(0 if ok else 9)
 return false
