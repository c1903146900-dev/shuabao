extends SceneTree
var elapsed:float=0
var invoked:bool=false
func _initialize()->void:root.add_child(load("res://boot.tscn").instantiate())
func _process(dt:float)->bool:
 elapsed+=dt
 if invoked:return false
 var boot=root.get_node_or_null("Boot")
 if boot==null or boot.get_child_count()==0:
  if elapsed>20:print("FOCUSED_BODY_BOOT_TIMEOUT");quit(2)
  return false
 for child in boot.get_children():
  if child.get("screen")!=null:
   invoked=true
   var probe=load("res://focused.gd").new()
   var result:Dictionary=probe.run()
   var g02_result:Dictionary=load("res://g02.gd").new().run()
   print("G02_FOCUSED_RESULT "+JSON.stringify(g02_result))
   result["g02"]=g02_result
   var regression:Dictionary=load("res://regression.gd").new().run()
   print("BODY_FOCUSED_RESULT "+JSON.stringify(result))
   print("P3_REGRESSION_RESULT "+JSON.stringify(regression))
   result["p3_regression"]=regression
   var f=FileAccess.open("user://focused_body.json",FileAccess.WRITE)
   f.store_string(JSON.stringify(result));f.close()
   quit(0 if result.failures.is_empty() and regression.failures.is_empty() and g02_result.failures.is_empty() else 3)
   return false
 return false
