extends SceneTree
# Synthetic deterministic fixture: positions, walls and hero target are explicitly set.
# Not normal campaign acquisition or whole-floor acceptance.
var started:bool=false
var elapsed:float=0.0
var failures:Array=[]
var checks:int=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label)
func _initialize()->void:root.add_child(load("res://boot.tscn").instantiate())
func _process(dt:float)->bool:
 elapsed+=dt
 if elapsed>15:quit(8);return false
 if started:return false
 var boot:Node=root.get_node_or_null("Boot")
 if boot!=null:
  for child in boot.get_children():
   if child.get("screen")!=null:started=true;call_deferred("run");break
 return false
func run()->void:
 var Sim:Script=load("res://fengli_route_20261024/sim.gd")
 var Layout:Script=load("res://tests/ink_first_floor_room_art_20261004/room_layout.gd")
 for kind in ["ranged","support"]:
  for scenario in [0,1,2]:
   var moving:bool=scenario==1
   var sim:Node=Sim.new();root.add_child(sim)
   sim.route_run_id="standalone";sim.auto_finish=false;sim.phase="combat";sim.ai_enabled=true
   Layout.bind_to_sim(sim)
   sim.hero.position=Vector3(-1,0,-11)
   if scenario==2:
    sim.obstacles=[{"position":Vector3.ZERO,"half":Vector3(1,0,1)}]
    sim.hero.position=Vector3(1.42,0,0)
   var d=sim.enemy_director
   var enemy:Dictionary=d.make_enemy(kind,Vector3(-6,0,-6),-1,1,1)
   if scenario==2:enemy.position=Vector3(-3,0,0)
   enemy.state="chase";enemy.timer=0.0;sim.enemies=[enemy]
   check(not d._clear_shot(sim,enemy,enemy.position),kind+"_wall_occluded")
   check(not d._in_position(sim,enemy),kind+"_wall_not_ready")
   d.step_enemy(sim,enemy,0.016)
   check(enemy.state=="chase" and d.commits==0 and d.active_threat_weight(sim)==0,kind+"_blocked_no_commit")
   var escaped:bool=false
   for tick in range(900):
    if moving and tick==15:sim.hero.position=Vector3(1,0,-11)
    if d._clear_shot(sim,enemy,enemy.position):escaped=true;break
    var old:Vector3=enemy.position
    d._move_role(sim,enemy,0.016)
    check(d._sight_leg(sim,old,enemy.position,enemy.radius),kind+"_step_safe")
   check(escaped,kind+"_corner_escape_"+str(moving))
   check(d.commits==0 and d.active_threat_weight(sim)==0,kind+"_route_no_threat")
   sim.obstacles=[]
   sim.hero.position=Vector3(0,0,0);enemy.position=Vector3(0,0,7)
   check(d._clear_shot(sim,enemy,enemy.position) and d._in_position(sim,enemy),kind+"_clear_lane_ready")
   sim.free()
 var sim:Node=Sim.new();root.add_child(sim);sim.route_run_id="standalone";Layout.bind_to_sim(sim)
 sim.hero.position=Vector3(-1,0,-11)
 var pitcher:Dictionary=sim.enemy_director.make_enemy("pitcher",Vector3(-6,0,-6),-1,1,1)
 check(sim.enemy_director._in_position(sim,pitcher),"pitcher_still_lobs_over_wall")
 sim.free()
 print("SIGHT_FIXTURE ",JSON.stringify({"checks":checks,"failures":failures}))
 quit(0 if failures.is_empty() else 7)
