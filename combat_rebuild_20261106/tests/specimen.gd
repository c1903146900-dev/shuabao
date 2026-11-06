extends SceneTree
class Sheet extends Node2D:
 var rigs:Array=[]
 var textures:Dictionary={}
 var font:Font
 func _ready()->void:
  font=ThemeDB.fallback_font
  var script:Script=load("res://fengli_route_20261024/puppet_motion.gd")
  for i in range(12):rigs.append(script.new())
  for key in ["attack_recover","dash","dashattack_recover"]:
   var image:=Image.load_from_file("res://fengli_route_20261024/assets/"+key+".png")
   textures[key]=ImageTexture.create_from_image(image)
 func _draw()->void:
  draw_rect(Rect2(0,0,1180,663),Color("202632"))
  draw_string(font,Vector2(25,35),"Rebuilt source-art motion: continuous arm / planted, travel, landing",HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color.WHITE)
  for row in range(2):
   var ages:Array=[0.0,.08,.13,.19,.28,.5] if row==0 else [0.0,.05,.10,.15,.20,.25]
   var event:Dictionary={"kind":"attack_started" if row==0 else "dash","animation":{"contact_after":.2 if row==0 else 0.0,"recovery":.3 if row==0 else .25}}
   for col in range(6):
    var rig=rigs[row*6+col];var age:float=ages[col];var key:String=rig.pose_key(event,age)
    var at:=Vector2(100+col*190,245+row*295)
    draw_set_transform(at)
    rig.draw_pose(self,textures[key],key,event,age,Vector2(596,895),.13)
    draw_set_transform(Vector2.ZERO)
    draw_string(font,at+Vector2(-65,35),("Attack " if row==0 else "Dash ")+str(age),HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color.WHITE)
func _initialize()->void:
 root.add_child(load("res://boot.tscn").instantiate())
 call_deferred("run")
func run()->void:
 var production:Script=load("res://fengli_route_20261024/presentation.gd")
 assert(production.can_instantiate());print("PRODUCTION_PRESENTATION_PARSE_PASS")
 root.add_child(Sheet.new())
 await create_timer(1.0).timeout
 await RenderingServer.frame_post_draw
 var result:int=root.get_texture().get_image().save_png("user://combat_rebuild_specimen.png")
 print("SPECIMEN_SAVE ",result)
 await create_timer(.5).timeout
 quit()
