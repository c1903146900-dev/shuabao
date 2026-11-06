extends SceneTree
var checks:int=0
func check(ok:bool)->void:assert(ok);checks+=1
func _initialize()->void:
 root.add_child(load("res://boot.tscn").instantiate());call_deferred("run")
func run()->void:
 var policy:Script=load("res://fengli_route_20261024/audio_policy.gd")
 var output:Script=load("res://fengli_route_20261024/audio_output.gd")
 check(policy.can_instantiate());check(output.can_instantiate())
 var dash:Dictionary={"kind":"dash","cast_id":4,"dash_id":2,"duration":.25}
 var copy:Dictionary=dash.duplicate(true)
 var cue:Dictionary=policy.classify(dash)
 check(cue.cue=="dash_move");check(cue.bank=="blink_move");check(cue.claim=="4:dash:0");check(dash==copy)
 check(policy.classify(dash).claim==cue.claim)
 for delta in [{"cast_id":0},{"dash_id":0},{"dash_id":"bad"},{"duration":0},{"duration":-1},{"duration":NAN},{"duration":"bad"},{"replay":true},{"hex_generated":true}]:
  var invalid:Dictionary=dash.duplicate(true);invalid.merge(delta,true)
  check(policy.classify(invalid).is_empty())
 for id in range(1,101):
  var e:Dictionary=dash.duplicate(true);e.cast_id=id
  check(policy.classify(e).cast_id==id)
 check(policy.classify({"kind":"attack_started","cast_id":4}).claim!=cue.claim)
 check(policy.classify({"kind":"e2_blink","cast_id":4}).claim!=cue.claim)
 print("AUDIO_POLICY_CHECKS_PASS ",checks);quit()
