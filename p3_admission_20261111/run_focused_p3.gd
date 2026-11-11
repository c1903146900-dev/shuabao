extends SceneTree
var elapsed:float=0
var invoked:bool=false
func _initialize()->void:root.add_child(load("res://boot.tscn").instantiate())
func _process(dt:float)->bool:
 elapsed+=dt
 if invoked:return false
 var boot=root.get_node_or_null("Boot")
 if boot==null or boot.get_child_count()==0:
  if elapsed>20:print("FOCUSED_P3_BOOT_TIMEOUT");quit(2)
  return false
 for child in boot.get_children():
  if child.get("screen")!=null:
   invoked=true
   var probe=load("res://focused.gd").new()
   var result:Dictionary=probe.run()
   var f=FileAccess.open("user://focused_p3.json",FileAccess.WRITE)
   f.store_string(JSON.stringify(result));f.close()
   quit(0 if result.failures.is_empty() else 3)
   return false
 return false
