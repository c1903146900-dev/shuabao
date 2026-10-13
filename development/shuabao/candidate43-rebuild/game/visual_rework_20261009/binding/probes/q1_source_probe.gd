extends SceneTree
## Real production Sim + Session + initial-SP learning. No substitute Sim.
const Sim=preload("res://tests/ink_river_hexes_20261006/ordinary01/sim.gd")
const Session=preload("res://tests/ink_river_hexes_20261006/frontdoor01/floor_session.gd")
const Router=preload("res://tests/ink_river_hexes_20261006/candidate01/input_adapter.gd")
const HOME="res://tests/ink_first_floor_user_route_20261005/runtime01/"
var failures:Array=[]
var checks:int=0
var serial:int=0
var observations:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->bool:
 checks+=1
 if not ok:failures.append(label);push_error(label)
 return ok
func command(session,action:String,args:Dictionary)->Dictionary:
 serial+=1
 var result:Dictionary=session.ledger.model.command("q1-input-probe-%d"%serial,action,args)
 session.progression_command_completed({"action":action,"args":args},result)
 session.update_after_source_step()
 return result
func fresh()->Dictionary:
 var sim=Sim.new();root.add_child(sim)
 var session=Session.new()
 var router=Router.new();router.bind(sim)
 var loaded:Dictionary=Session.MixedSchema.load_definition(Session.DEFAULT_DEFINITION,true)
 if not check(loaded.accepted,"original route definition"):sim.free();return {}
 var configured:Dictionary=session.configure_reward_table(HOME+"reward_table.json",HOME+"rewards.csv",HOME+"validation_result.json",true)
 if not check(configured.accepted,"original rewards configured"):sim.free();return {}
 serial+=1
 var initialized:Dictionary=session.initialize_floor(sim,loaded.definition,"q1-source-%d"%serial,true)
 if not check(initialized.accepted,"actual new binding and single Session initialize: "+str(initialized.get("reason",""))):sim.free();return {}
 check(session.bind_input_suspender(router.suspend_input).accepted,"real router suspender bound after initialization")
 if not check(command(session,"hex_open",{"milestone":1}).accepted,"original initial offer opens"):sim.free();return {}
 var slots:Array=session.ledger.model.state.offers["1"].slots
 var chosen:int=-1
 for i in range(slots.size()):
  if str(slots[i])!="yanguizhou_h01":chosen=i;break
 if not check(chosen>=0,"baseline test has non-H01 offer"):sim.free();return {}
 if not check(command(session,"hex_select",{"milestone":1,"slot":chosen}).accepted,"original initial Hex selected"):sim.free();return {}
 if not check(session.learn_q1().accepted,"Q1 learned through original one-SP API"):sim.free();return {}
 session.update_after_source_step()
 check(sim.hero.ranks.q==1 and session.ledger.model.state.points==0,"real rank1 and SP debit")
 check(not sim.hx("yanguizhou_h01"),"no H01 curve unlock in baseline test")
 if not check(session.select_node(1,"r01a").accepted,"original first room selected"):sim.free();return {}
 var entered:Dictionary=session.enter_selected_node()
 if not check(entered.accepted and sim.phase=="combat","Session starts real begin_encounter: reason="+str(entered.get("reason",""))+" phase="+str(sim.phase)):sim.free();return {}
 # Bounded input fixture: real enemies remain, but AI and automatic finish are disabled.
 sim.ai_enabled=false;sim.auto_finish=false
 return {"sim":sim,"session":session,"router":router}
func arm(sim,a:Vector3)->bool:
 return check(sim.request_ink_input("q_down").accepted,"Q1 armed") and check(sim.request_ink_input("left_down",a).accepted,"legal world A admitted")
func length(path:Array)->float:
 var total:float=0.0
 for i in range(1,path.size()):total+=Vector3(path[i-1]).distance_to(path[i])
 return total
func close(f:Dictionary)->void:
 f.session.close_run();f.sim.free()
func curve_and_release()->void:
 var f:Dictionary=fresh()
 if f.is_empty():return
 var sim=f.sim;var a:Vector3=sim.hero.position
 if arm(sim,a):
  for offset:Vector3 in [Vector3(1,0,0),Vector3(1,0,1),Vector3(2,0,1),Vector3(2,0,-1)]:
   check(sim.request_ink_input("motion",a+offset).accepted,"real pointer bend accepted")
  var path:Array=sim.ink_input.path.duplicate(true)
  check(path.size()>=5,"baseline retains multiple bends")
  var before:float=sim.hero_time
  var released:Dictionary=sim.request_ink_input("left_up",path.back())
  check(released.accepted,"release accepted without a source step")
  check(sim.ink_waves.size()==1,"wave exists in release call")
  if not sim.ink_waves.is_empty():
   var wave:Dictionary=sim.ink_waves.back()
   check(absf(float(wave.released_at)-before)<.000001 and sim.hero_time==before,"release source time has no artificial delay")
   check(wave.path==path,"released actual wave uses curved source path")
   check(absf(float(wave.width)-1.6)<.00001 and absf(float(wave.speed)-24.0)<.00001,"original width and front speed")
  observations["curve_path"]=path;observations["release"]=released
 close(f)
func fixed_start_and_time()->void:
 var f:Dictionary=fresh()
 if f.is_empty():return
 var sim=f.sim;var hero_before:Vector3=sim.hero.position;var a:Vector3=hero_before+Vector3(0,0,-1)
 if arm(sim,a):
  sim.request_ink_input("motion",a+Vector3(2,0,0))
  var started:float=sim.hero_time
  sim.hero.move_intent=Vector3.RIGHT
  sim.step(.74)
  check(sim.ink_input.phase=="drawing","before .75 preview drawing")
  sim.step(.02)
  check(sim.hero.position.distance_to(hero_before)>.01,"player actually moves during preparation")
  check(sim.ink_input.start==a and sim.ink_input.path[0]==a,"moving hero cannot drag world A")
  check(sim.ink_input.phase=="frozen" and absf(float(sim.ink_input.frozen_at)-(started+.75))<.00001,"source freezes exactly at .75")
  var frozen:Array=sim.ink_input.path.duplicate(true)
  sim.request_ink_input("motion",a+Vector3(0,0,8))
  check(sim.ink_input.path==frozen,"held pointer cannot edit time-frozen path")
  check(sim.ink_waves.is_empty(),"time limit does not auto-release")
  var before:Vector3=sim.hero.position
  check(sim.request_ink_input("left_up",a+Vector3(0,0,8)).accepted,"frozen release accepted")
  sim.step(.04)
  check(sim.hero.position.distance_to(before)>.001,"movement continues through release")
 close(f)
func arc_cap()->void:
 var f:Dictionary=fresh()
 if f.is_empty():return
 var sim=f.sim;var a:Vector3=sim.hero.position
 if arm(sim,a):
  for offset:Vector3 in [Vector3(3,0,0),Vector3(3,0,3),Vector3(0,0,3),Vector3(0,0,-3)]:sim.request_ink_input("motion",a+offset)
  var path:Array=sim.ink_input.path.duplicate(true)
  check(absf(length(path)-11.0)<.00001,"11m total arc length, not straight displacement")
  check(sim.ink_input.phase=="frozen" and sim.ink_input.freeze_reason=="length_limit","arc cap freezes preview")
  check(Vector3(path.back()).distance_to(a)<11.0,"bent end displacement below arc cap")
  sim.request_ink_input("motion",a+Vector3(9,0,9))
  check(sim.ink_input.path==path and sim.ink_waves.is_empty(),"length freeze neither follows cursor nor auto-releases")
  check(sim.request_ink_input("left_up",a).accepted,"length-frozen path releases without stepping")
  observations["arc_length"]=length(path)
 close(f)
func run()->void:
 curve_and_release();fixed_start_and_time();arc_cap()
 print("Q1_PRODUCTION_INPUT_PROBE ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"actual_sim":"res://tests/ink_river_hexes_20261006/ordinary01/sim.gd","native_input":false,"full_floor":false,"visual_acceptance":false}))
 quit(0 if failures.is_empty() else 1)
