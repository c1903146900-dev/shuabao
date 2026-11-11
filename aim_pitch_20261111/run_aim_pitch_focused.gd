extends SceneTree
var elapsed:float=0
var invoked:bool=false
func _initialize()->void:root.add_child(load("res://boot.tscn").instantiate())
func _process(dt:float)->bool:
 elapsed+=dt
 if invoked:return false
 var boot=root.get_node_or_null("Boot")
 if boot==null or boot.get_child_count()==0:
  if elapsed>20:print("HELD_HUD_BOOT_TIMEOUT");quit(2)
  return false
 for child in boot.get_children():
  if child.get("screen")!=null:
   invoked=true
   var result:Dictionary=load("res://focused.gd").new().run()
   var visual:Dictionary=load("res://visual.gd").new().run()
   print("AIM_PITCH_VISUAL_RESULT "+JSON.stringify(visual))
   result.failures.append_array(visual.failures)
   print("HELD_HUD_FOCUSED_RESULT "+JSON.stringify(result))
   var f=FileAccess.open("user://held_hud_focused.json",FileAccess.WRITE)
   f.store_string(JSON.stringify(result));f.close()
   quit(0 if result.get("failures",["missing"]).is_empty() else 3)
   return false
 return false
