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
var trace:Array=[]
const View=preload("res://visual_rework_20261009/views/q1_view.gd")
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
 # Keep original enemies, AI, collisions and automatic lifecycle unchanged.
 return {"sim":sim,"session":session,"router":router}
func route(f:Dictionary,event:InputEvent,ground:Vector3)->Dictionary:
 var out:Dictionary=f.router.handle_event(event,ground)
 trace.append({"event_class":event.get_class(),"ground":ground,"result":out.duplicate(true),"source_time":f.sim.hero_time,"hero_position":f.sim.hero.position,"input":f.sim.ink_input.duplicate(true)})
 return out
func key(f:Dictionary,code:Key,pressed:bool,ground:Vector3)->Dictionary:
 var event=InputEventKey.new();event.physical_keycode=code;event.pressed=pressed
 return route(f,event,ground)
func mouse(f:Dictionary,pressed:bool,ground:Vector3)->Dictionary:
 var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
 return route(f,event,ground)
func motion(f:Dictionary,ground:Vector3)->Dictionary:
 return route(f,InputEventMouseMotion.new(),ground)
func advance(f:Dictionary,seconds:float)->void:
 f.sim.step(seconds)
 f.session.update_after_source_step()
func view_sample(f:Dictionary,view:Node3D,label:String)->void:
 var ink:Dictionary=f.sim.ink_presenter_snapshot()
 view.present_source(ink)
 var materials:Array=[]
 for wave_id in view._drawn:
  for node:MeshInstance3D in view._drawn[wave_id]:
   materials.append({"wave_id":wave_id,"age":node.material_override.get_shader_parameter("age"),"front_distance":node.material_override.get_shader_parameter("front_distance"),"path_length":node.material_override.get_shader_parameter("path_length"),"layer":node.material_override.get_shader_parameter("layer")})
 observations[label]={"source_time":f.sim.hero_time,"hero_position":f.sim.hero.position,"waves":ink.get("waves",[]),"finished":ink.get("finished",[]),"materials":materials}
 check(materials.size()==3,label+" actual-source wave has three visual layers")
func run()->void:
 var f:Dictionary=fresh()
 if not f.is_empty():
  var sim=f.sim
  var view=View.new();root.add_child(view)
  var a:Vector3=sim.hero.position
  var start_hero:Vector3=sim.hero.position
  check(key(f,KEY_D,true,a).accepted,"original router accepts simultaneous movement")
  check(key(f,KEY_Q,true,a).accepted,"original Q down")
  key(f,KEY_Q,false,a)
  check(mouse(f,true,a).accepted,"original left down fixes legal A")
  var started:float=sim.hero_time
  # A 2m-radius U arc, 16 original router motions over .32 source seconds.
  # These are synthetic InputEvents; no native OS gesture or authored wave injection.
  var endpoint:Vector3=a
  for index:int in range(1,17):
   var angle:float=PI*float(index)/16.0
   endpoint=a+Vector3(2.0*sin(angle),0,2.0*(1.0-cos(angle)))
   check(motion(f,endpoint).accepted,"arc motion %d"%index)
   advance(f,.02)
  var path:Array=sim.ink_input.path.duplicate(true)
  check(path.size()>=16,"dense non-H01 curved path retained")
  check(sim.hero.position.distance_to(start_hero)>.01,"movement actually advances while drawing")
  check(sim.ink_input.start==a and path[0]==a,"A remains fixed in world while hero moves")
  check(sim.hero_time-started<.75,"curve delivered inside original draw time")
  var released_at:float=sim.hero_time
  check(mouse(f,false,endpoint).accepted,"router mouse up commits original Q1")
  check(sim.hero_time==released_at and sim.ink_waves.size()==1,"wave created in original release call")
  if not sim.ink_waves.is_empty():
   var wave:Dictionary=sim.ink_waves.back()
   check(wave.path==path and wave.path[0]==a and wave.path.back()==endpoint,"render endpoints use exact source path")
   check(float(wave.width)==1.6 and float(wave.speed)==24.0,"original corridor width and front speed")
  advance(f,.08);view_sample(f,view,"age_early")
  advance(f,.12);view_sample(f,view,"age_later")
  check(sim.hero.position.distance_to(start_hero)>.01,"movement remains allowed during release")
  key(f,KEY_D,false,endpoint)
  observations["source_path"]=path
  view.reset_visuals();view.free();f.session.close_run();sim.free()
 var report:Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"trace":trace,"observations":observations,"input_mode":"synthetic InputEvents through original Router and real Session/Sim; no injected wave/path","native_input":false,"visual_pixel_acceptance":false,"collision_rules_modified":false,"boundary_scope":"legal world A and exact source outlet; source 0.75/11m unchanged"}
 var output:String=OS.get_environment("Q1_ARC_PROBE_REPORT")
 if not output.is_empty():
  var file=FileAccess.open(output,FileAccess.WRITE)
  if file!=null:file.store_string(JSON.stringify(report,"  "));file.close()
 print("Q1_ROUTER_ARC_PROBE ",JSON.stringify(report))
 quit(0 if failures.is_empty() else 1)
