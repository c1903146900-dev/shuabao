extends SceneTree
var checks:int=0
class Source extends Node:
 var room_id:String="test_room"
 var encounter_generation:int=1
 var real_time:float=2.0
 var phase:String="combat"
 var enemies:Array=[{"actor_id":"enemy_1","dead":false,"position":Vector3.ZERO}]
func check(ok:bool)->void:
 assert(ok);checks+=1
func event(seq:int=1)->Dictionary:
 return {"kind":"damage","sequence":seq,"generation":1,"room_id":"test_room","real_time":2.0,"target":"enemy_1","amount":10.0,"direction":Vector3(1,0,0)}
func _initialize()->void:
 root.add_child(load("res://boot.tscn").instantiate());call_deferred("run")
func run()->void:
 var production:Script=load("res://fengli_route_20261024/presentation.gd");check(production.can_instantiate())
 var script:Script=load("res://fengli_route_20261024/hit_reaction.gd");check(script.can_instantiate())
 var helper=script.new();var source=Source.new();root.add_child(source)
 var before:String=var_to_str(source.enemies)
 check(helper.accept(event(),source));check(not helper.accept(event(),source))
 check(is_equal_approx(helper.sample(source,source.enemies[0]).amount,1.0))
 check(var_to_str(source.enemies)==before)
 for i in range(101):
  source.real_time=2.0+i*.0014
  var sample:Dictionary=helper.sample(source,source.enemies[0])
  check(is_finite(sample.amount) and sample.amount>=0 and sample.amount<=1)
 source.real_time=2.2;check(helper.sample(source,source.enemies[0]).amount==0)
 for change in [{"amount":0.0},{"amount":-1},{"amount":NAN},{"generation":2},{"room_id":"old"},{"target":"fengli"},{"target":"missing"},{"real_time":1.0},{"stale_generation":true},{"replay":true},{"sequence":"fake"}]:
  helper.clear();source.real_time=2.0
  var e:Dictionary=event();e.merge(change,true)
  check(not helper.accept(e,source));check(helper.sample(source,source.enemies[0]).amount==0)
 helper.clear();source.real_time=2.0;check(helper.accept(event(),source))
 source.encounter_generation=2;check(helper.sample(source,source.enemies[0]).amount==0)
 source.encounter_generation=1;helper.clear();check(helper.accept(event(),source));source.enemies[0].dead=true
 check(helper.sample(source,source.enemies[0]).amount==0)
 print("HIT_REACTION_CHECKS_PASS ",checks)
 source.queue_free();quit()
