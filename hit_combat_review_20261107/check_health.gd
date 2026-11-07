extends SceneTree
var checks:int=0
class Source extends Node:
 var hero:Dictionary={"hp":80.0,"stats":{"max_hp":100.0},"dead":false}
 var phase:String="combat"
 var room_id:String="test"
 var encounter_generation:int=1
 var real_time:float=10.0
 var event_log:Array=[]
func check(ok:bool)->void:
 checks+=1
 if not ok:push_error("PLAYER_HEALTH_CHECK_FAILED %d"%checks);quit(9)
func event(sim:Node,seq:int=1)->Dictionary:
 return {"kind":"damage","target":"fengli","amount":20.0,"real_time":sim.real_time,"sequence":seq,"room_id":sim.room_id,"generation":sim.encounter_generation}
func _initialize()->void:
 root.add_child(load("res://boot.tscn").instantiate());call_deferred("run")
func run()->void:
 var helper=load("res://fengli_route_20261024/player_health_cue.gd").new()
 check(load("res://fengli_route_20261024/presentation.gd").can_instantiate())
 var sim=Source.new();root.add_child(sim)
 var e:Dictionary=event(sim);sim.event_log=[e.duplicate(true)]
 check(helper.accept(e,sim));check(not helper.accept(e,sim))
 var v:Dictionary=helper.sample(sim);check(v.hp==80 and v.maximum==100);check(v.ratio==.8 and v.tail_ratio==1)
 for i in range(101):
  sim.real_time=10+float(i)/50
  v=helper.sample(sim);check(not v.is_empty());check(v.tail_ratio>=v.ratio and v.tail_ratio<=1)
 sim.real_time=12.01;check(helper.sample(sim).is_empty())
 sim.real_time=20;e=event(sim,2);sim.event_log=[e.duplicate(true)];check(helper.accept(e,sim))
 sim.hero.hp=95;v=helper.sample(sim);check(v.hp==95 and v.tail_ratio>=v.ratio)
 sim.hero.dead=true;check(helper.sample(sim).is_empty());sim.hero.dead=false
 sim.phase="victory";check(helper.sample(sim).is_empty());sim.phase="combat"
 sim.encounter_generation+=1;check(helper.sample(sim).is_empty())
 for patch in [{"amount":0},{"amount":-2},{"amount":NAN},{"amount":INF},{"target":"enemy_1"},{"kind":"attack_impact"},{"replay":true},{"stale_generation":true},{"generation":-1},{"room_id":"old"},{"sequence":1.5},{"real_time":-10},{"real_time":NAN}]:
  helper.clear();e=event(sim);e.merge(patch,true);sim.event_log=[e.duplicate(true)];check(not helper.accept(e,sim));check(helper.sample(sim).is_empty())
 helper.clear();e=event(sim);sim.event_log=[];check(not helper.accept(e,sim))
 sim.event_log=[e.duplicate(true)];e.amount=30;check(not helper.accept(e,sim))
 helper.clear();e=event(sim);sim.event_log=[e.duplicate(true)];sim.hero.stats.max_hp=0;check(not helper.accept(e,sim));check(helper.sample(sim).is_empty())
 sim.hero.stats.max_hp=100
 for direction in [Vector3.RIGHT,Vector3.LEFT,Vector3.ZERO,Vector3(INF,0,0),"invalid"]:
  helper.clear();sim.real_time=30;e=event(sim,99);e.direction=direction;sim.event_log=[e.duplicate(true)];check(helper.accept(e,sim))
  v=helper.sample(sim);check(v.recoil==1.0)
  check(v.damage_direction==(direction if direction is Vector3 and direction.is_finite() else Vector3.ZERO))
  sim.real_time=30.24;v=helper.sample(sim);check(v.recoil<.000001)
  helper.clear();check(helper.damage_direction==Vector3.ZERO)
 print("PLAYER_HEALTH_CHECKS_PASS ",checks);quit()
