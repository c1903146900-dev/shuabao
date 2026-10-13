extends SceneTree
const Sampler=preload("res://visual_rework_20261009/input/q1_free_curve_sampler.gd")
var failed:int=0
func check(value:bool,label:String)->void:
 if not value:failed+=1;push_error(label)
 else:print("PASS "+label)
func _initialize()->void:
 var a:=Vector3(2,0,1)
 var path:Array=[a,a]
 for p:Vector3 in [Vector3(3,0,1),Vector3(3,0,2),Vector3(2,0,2),Vector3(2,0,3)]:
  path=Sampler.sample(path,p,11.0).path
 check(path.size()==5,"multiple bends baseline")
 check(path[0]==a,"fixed world anchor")
 var original:Array=path.duplicate(true)
 var stopped:Dictionary=Sampler.sample(path,Vector3(2,0,30),11.0)
 check(stopped.at_limit,"arc length cap freezes")
 check(absf(float(stopped.arc_length)-11.0)<.00001,"cap is arc length not displacement")
 check(path==original,"sampler does not mutate source")
 var cap:Dictionary=Sampler.sample(stopped.path,Vector3(100,0,100),11.0)
 check(cap.at_limit and not cap.changed and cap.path==stopped.path,"frozen-length geometry unchanged")
 var nan_point:=Vector3(NAN,0,0)
 check(not Sampler.sample(path,nan_point,11.0).changed,"invalid coordinate rejected")
 check(not Sampler.sample(path,path.back(),11.0).changed,"zero motion no duplicate")
 var longer:Dictionary=Sampler.sample([a,a],a+Vector3(30,0,0),14.3)
 check(absf(float(longer.arc_length)-14.3)<.00001,"caller H01 length preserved")
 print("Q1_SAMPLER_FAILURES=",failed)
 quit(1 if failed else 0)
