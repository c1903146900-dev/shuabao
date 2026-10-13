extends SceneTree
const Sim=preload("res://tests/ink_intermediate_stats_20261004/ink_intermediate_sim.gd")
const Bridge=preload("res://tests/ink_intermediate_stats_20261004/ink_intermediate_bridge.gd")
const Catalog=preload("res://tests/ink_initial_hex_runtime_20261004/ink_initial_catalog.gd")
const SHOP="res://tests/ink_first_floor_flow_20261004/fixtures/provisional_shop.json"
const FIXTURE="res://tests/equipment_shop_transactions_20261004/fixtures/source_prices.json"
const NUMERIC="res://tests/equipment_editable_tables_20261004/outputs/equipment_tables/converted/equipment_numeric_config.json"
var checks: int=0
var failures: Array=[]
var observations: Dictionary={}
var serial: int=0
var case_status: Dictionary={}
var command_evidence: Array=[]
var kill_evidence: Array=[]
func _initialize()->void:call_deferred("run")
func check(ok: bool,label: String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func near(a: float,b: float,label: String)->void:check(is_finite(a) and absf(a-b)<.00001,"%s: %.9f / %.9f"%[label,a,b])
func caps()->Dictionary:
 var hooks: Array=Catalog.FIRST_SLICE_HEX_HOOKS.duplicate()+["stats.v1","equipment.task_completion.v1"]
 for stat in ["AD","AP","attack_speed","max_hp","defense","move_speed","crit_chance","cooldown_reduction","lifesteal","tenacity","penetration","hp_regen"]:hooks.append("stat."+stat+".v1")
 return {"schema_version":1,"hero_id":"yanguizhou","source_binding_id":FileAccess.get_sha256("res://tests/ink_intermediate_stats_20261004/source_binding.json"),"runtime_candidates":["Q1"],"supported_hooks":hooks}
func fresh(id: String)->Dictionary:
 var sim=Sim.new();root.add_child(sim)
 var bridge=Bridge.new();var owner=RefCounted.new()
 check(bridge.initialize_runtime_fixture(sim,caps(),SHOP,FIXTURE,NUMERIC,owner,"initial-sink",true).accepted,"exact new health/commerce/common combination")
 sim.set_progression(bridge);sim.common.context_values.run_id="initial-sink";sim.hero.position=Vector3.ZERO;sim.ai_enabled=false;sim.auto_finish=false
 check(bridge.model.state.level==1 and bridge.model.state.points==1 and bridge.model.state.gold==0 and bridge.model.state.inventory.is_empty() and bridge.model.state.selected_hex.is_empty(),"ordinary ungranted Lv1 0gold 1SP empty equipment/Hex")
 for skill in bridge.model.state.skills.values():check(skill.rank==0 and skill.candidate.is_empty(),"empty skill slots")
 check(bridge.command("hex_open",{"milestone":1}).ok,"real initial four-choice ledger")
 var picked: bool=false
 for refreshed in [-1,0,1,2,3]:
  if refreshed>=0:check(bridge.command("hex_refresh",{"milestone":1,"slot":refreshed}).ok,"real one-use refresh")
  var slots: Array=bridge.model.state.offers["1"].slots
  if id in slots:
   check(bridge.command("hex_select",{"milestone":1,"slot":slots.find(id)}).ok,"real selection "+id);picked=true;break
 check(picked and bridge.model.state.selected_hex==[id],"no fabricated selected_hex")
 check(bridge.model.state.points==1 and bridge.model.state.gold==0,"choice and refresh grant no points or gold")
 return {"sim":sim,"b":bridge,"owner":owner,"hex":id}
func combat(f: Dictionary,room: String="sink-room")->void:
 check(shop(f,"enter_room",{"next_room":room},true).accepted,"trusted actual room commit")
 check(f.b.command("enter_level",{"combat_level_id":room}).ok,"ledger room identity")
 check(f.b.command("context",{"phase":"combat"}).ok,"ledger combat phase")
 check(f.sim.begin_encounter(room,[]).accepted,"real source combat begins")
 f.sim.common.context_values.run_id="initial-sink"
func target(f: Dictionary,kind: String="minion",hp: float=10000,at: Vector3=Vector3(0,0,-.1))->Dictionary:
 var e: Dictionary=f.sim.spawn_enemy(kind,at,hp);e.state="chase";e.defence=0;e.speed=0
 return e
func cast_q1(f: Dictionary)->void:
 check(f.sim.request_ink_input("q_down").accepted,"manual Q arm")
 check(f.sim.request_ink_input("left_down",Vector3.ZERO).accepted,"manual first point")
 check(f.sim.request_ink_input("motion",Vector3(4,0,0)).accepted,"manual drag")
 check(f.sim.request_ink_input("left_up",Vector3(4,0,0)).accepted,"mouse release casts actual Q1")
func learn(f: Dictionary)->void:
 check(f.sim.learn_ability("Q","Q1").ok,"spend actual initial SP on Q1")
 check(f.b.model.state.points==0 and f.sim.hero.ranks.q==1,"one SP paid, actor learns")
func basic(f: Dictionary,e: Dictionary)->float:
 var before: float=e.hp
 var pre_cd: float=f.sim.hero.cooldowns.attack
 var result: Dictionary=f.sim.request_action("attack",Vector3(0,0,-9))
 command_evidence.append({"case":f.hex,"target_id":e.actor_id,"source_time":f.sim.hero_time,"pre_cd":pre_cd,"result":result.duplicate(true)})
 check(result.accepted,"manual BASIC accepted: "+str(result.get("reason","missing")))
 if not result.accepted:return NAN
 f.sim.step(.02)
 return before-float(e.hp)
func shop(f: Dictionary,operation: String,args: Dictionary={},trusted: bool=false)->Dictionary:
 serial+=1;var token: Dictionary=f.b.model.commerce_token();token.merge(args,true)
 return f.b.shop_authority(f.owner,"initial-shop:%d"%serial,operation,token) if trusted else f.b.shop_command("initial-shop:%d"%serial,operation,token)
func safe_shop(f: Dictionary,room: String)->void:
 if f.sim.phase=="combat":f.sim.end_encounter("finite_boundary")
 check(f.b.command("context",{"phase":"safe"}).ok,"safe ledger phase")
 check(shop(f,"enter_room",{"next_room":room},true).accepted,"same ledger shop room")
 check(shop(f,"begin_visit",{"area":room+"/shop"},true).accepted,"same ledger shop visit")
func earn_kill(f: Dictionary,kind: String="minion")->bool:
 # Wait the live source cooldown / source attack interval using ordinary fixed-step simulation.
 # Never zero a cooldown, mark a target dead, forge a kill or credit currency.
 var remaining: float=float(f.sim.hero.cooldowns.attack)
 var wait_seconds: float=maxf(remaining,1.0/f.sim.hero.attack_speed())+f.sim.FIXED_TICK
 var before_time: float=f.sim.hero_time
 f.sim.step(wait_seconds)
 check(f.sim.hero.cooldowns.attack<=f.sim.TIME_EPS,"actual BASIC cooldown expires before next target")
 if f.sim.hero.cooldowns.attack>f.sim.TIME_EPS:return false
 var e: Dictionary=target(f,kind,1)
 var dealt: float=basic(f,e)
 if not is_finite(dealt):return false
 check(e.dead,"actual source BASIC kill")
 var matching: Array=f.sim.event_log.filter(func(row):return row.kind=="kill" and row.target==e.actor_id)
 check(matching.size()==1,"one actual kill receipt for this target")
 if not e.dead or matching.size()!=1:
  command_evidence.append({"case":f.hex,"target_id":e.actor_id,"missing_kill":true,"enemy":e.duplicate(true),"recent_events":f.sim.event_log.slice(maxi(0,f.sim.event_log.size()-12)).duplicate(true)})
  return false
 var event: Dictionary=matching[0]
 check(event.source=="attack" and int(event.cast_id)>0,"real BASIC cast owns the kill")
 if event.source!="attack" or int(event.cast_id)<=0:return false
 var credited: Dictionary=f.b.model.observe_live_event(f.owner,f.sim,event)
 check(credited.accepted,"verified real kill into same wallet: "+str(credited.get("reason","missing")))
 if not credited.accepted:return false
 var refreshed: Dictionary=f.b.refresh_runtime()
 check(refreshed.accepted,"post-transaction common projection")
 kill_evidence.append({"case":f.hex,"target_id":e.actor_id,"kind":kind,"wait_seconds":wait_seconds,"elapsed_source_seconds":f.sim.hero_time-before_time,"damage":dealt,"event":event.duplicate(true),"credit":credited.duplicate(true),"gold_after":f.b.model.state.gold,"cooldown_groups":f.sim.common.runtime.cooldown_groups,"cooldown_elites":f.sim.common.runtime.cooldown_elites,"cooldown_bosses":f.sim.common.runtime.cooldown_bosses})
 return bool(refreshed.accepted)
func finish_case(id: String,before_failures: int)->void:
 case_status[id]={"completed":true,"passed":failures.size()==before_failures,"new_failures":failures.size()-before_failures}
func test_old_spacing_refusal()->void:
 var failed_before: int=failures.size()
 var f: Dictionary=fresh("common_g30");combat(f)
 var first: Dictionary=target(f,"minion",1)
 near(basic(f,first),1.0,"old-spacing reproduction first real kill")
 check(first.dead,"first source kill before reproducing spacing")
 # Exact old helper sequence: prior BASIC .02 then next fixed wait1.1.
 f.sim.step(1.1)
 var second: Dictionary=target(f,"minion",1)
 var before_cd: float=f.sim.hero.cooldowns.attack
 var before_sequence: int=f.sim.sequence
 var rejection: Dictionary=f.sim.request_action("attack",Vector3(0,0,-9))
 check(not rejection.accepted and rejection.reason=="cooldown","old1.1 spacing actually refused for cooldown")
 near(before_cd,1.0/.85-1.12,"source0.85 leaves actual .056470588 cooldown")
 check(second.hp==1.0 and not second.dead and f.sim.sequence==before_sequence,"rejected command produces no damage or kill event")
 f.sim.step(before_cd+f.sim.FIXED_TICK)
 var retry: Dictionary=f.sim.request_action("attack",Vector3(0,0,-9))
 check(retry.accepted and second.dead,"same valid target killed after natural source cooldown expiry")
 var events: Array=f.sim.event_log.filter(func(row):return row.kind=="kill" and row.target==second.actor_id)
 check(events.size()==1,"natural retry produces one real kill")
 observations.fixture_diagnosis={"attack_speed":f.sim.hero.attack_speed(),"old_wait":1.1,"remaining_cd":before_cd,"rejection":rejection.duplicate(true),"retry":retry.duplicate(true),"second_target_kills":events.size()}
 f.sim.free();finish_case("old_spacing_refusal",failed_before)
func run()->void:
 test_old_spacing_refusal();test_personal();test_g01();test_g05();test_g06();test_g15();test_g24();test_g30()
 var required_cases: Array=["old_spacing_refusal","personal","G01","G05","G06","G15","G24","G30"]
 for id in required_cases:check(case_status.get(id,{}).get("completed",false),"case completed through final assertion: "+id)
 var verified_hooks: Array=[]
 if case_status.get("personal",{}).get("passed",false):verified_hooks.append_array(Catalog.FIRST_SLICE_HEX_HOOKS.slice(0,2))
 for id in ["G01","G05","G06","G15","G24","G30"]:
  if case_status.get(id,{}).get("passed",false):verified_hooks.append("hex.final_design.common_"+id.to_lower()+".v1")
 var result: Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"source_binding_id":FileAccess.get_sha256("res://tests/ink_intermediate_stats_20261004/source_binding.json"),"hooks_tested":verified_hooks,"case_status":case_status,"command_evidence":command_evidence,"kill_evidence":kill_evidence,"upstream_runtime_source_binding_id":"c997eab5df81084d7ca970c76464389e4cf47954ae8271c1b18ae3a8b27cec7a","scope":"finite actual Ink consumers via ordinary Lv1 choice and paid Q1; not native UI, later milestones or full hero"}
 var file=FileAccess.open("res://tests/ink_intermediate_stats_20261004/common_regression_result.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close()
 print("INK_INITIAL_SINK_REPORT ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
func test_personal()->void:
 var failed_before: int=failures.size()
 for id in ["yanguizhou_h01","yanguizhou_h02"]:
  var f: Dictionary=fresh(id)
  check(f.b.model.snapshot().hex_status[id]=="dormant" and not f.sim.hx(id),"unlearned personal Hex dormant")
  learn(f);check(f.sim.hx(id),"paid Q1 activates selected personal")
  combat(f);cast_q1(f);f.sim.step(.2)
  if id=="yanguizhou_h02":check(f.sim.ink_vortices.size()==1,"selected H02 reaches actual endpoint")
  else:check(f.sim.ink_finished.size()==1,"selected H01 source Q1 finishes")
  f.sim.free()
 finish_case("personal",failed_before)
func test_g01()->void:
 var failed_before: int=failures.size()
 var f: Dictionary=fresh("common_g01");learn(f);combat(f)
 # Explicit boundary stat stimulus only. No Hex/offer/SP mutation.
 f.sim.set_projected_stats({"crit_chance":1.0,"crit_damage":1.75})
 var e: Dictionary=target(f,"minion",10000,Vector3(2,0,0));cast_q1(f);f.sim.step(.2)
 var actual_q1: float=10000-e.hp
 near(actual_q1,65*1.75,"G01 actual Q1 ordinary damage can crit")
 var hits: Array=f.sim.event_log.filter(func(row):return row.kind=="damage" and row.get("target","")==e.actor_id)
 check(hits.size()==1 and hits[0].critical,"G01 real damage receipt critical once")
 e=target(f);var actual_basic: float=basic(f,e);near(actual_basic,36*1.75,"BASIC existing roll not doubled")
 var rng_before: int=f.sim.common.runtime.rng.state
 e=target(f,"minion",10000,Vector3(10,0,10))
 f.sim.damage_enemy(e,100,"q1",0,true,false,{"active_skill":true})
 near(10000-e.hp,100,"true damage gains no crit eligibility")
 check(f.sim.common.runtime.rng.state==rng_before,"true damage does not roll G01")
 e=target(f,"minion",10000,Vector3(10,0,11))
 f.sim.damage_enemy(e,100,"q1",0,false,false,{"active_skill":true,"no_reactions":true})
 near(10000-e.hp,100,"no reactions excludes G01")
 observations.G01={"q1_damage":actual_q1,"basic_damage":actual_basic};f.sim.free()
 finish_case("G01",failed_before)
func test_g05()->void:
 var failed_before: int=failures.size()
 var f: Dictionary=fresh("common_g05");near(f.sim.hero.stats.cdr,.12,"G05 immediate 12 percent")
 learn(f);combat(f);cast_q1(f);near(f.sim.hero.cooldowns.q,f.sim.v("Q1-8")*.88,"actual Q1 source cooldown reduced")
 check(f.b.model.bind_floor(f.owner,f.sim,"initial-sink").accepted,"trusted kill ledger owner")
 for index in range(40):
  if not earn_kill(f):f.sim.free();return
  if index==38:near(f.sim.hero.stats.cdr,.12,"39 ordinary kills no premature increment")
 near(f.sim.hero.stats.cdr,.13,"40 actual ordinary kills add1 percent")
 var last: Dictionary=f.sim.enemies.back();f.sim.common.killed(last,"attack",0)
 near(f.sim.hero.stats.cdr,.13,"duplicate death does not grow cooldown")
 if not earn_kill(f,"elite"):f.sim.free();return
 near(f.sim.hero.stats.cdr,.15,"elite actual kill adds2 percent")
 if not earn_kill(f,"boss"):f.sim.free();return
 near(f.sim.hero.stats.cdr,.18,"Boss actual kill adds3 percent")
 var actual_cdr: float=f.sim.hero.stats.cdr
 var actual_ordinary: int=f.sim.common.runtime.cooldown_groups*40+f.sim.common.runtime.cooldown_kills
 var growth: int=f.sim.common.runtime.cooldown_groups;f.b.refresh_runtime()
 check(f.sim.common.runtime.cooldown_groups==growth,"stat refresh preserves run growth")
 f.sim.end_encounter("finite_boundary");combat(f,"sink-room-2");near(f.sim.hero.stats.cdr,.18,"same run room preserves growth")
 f.sim.set_projected_stats({"cdr":.64});near(f.sim.hero.stats.cdr,.65,"global CDR cap65")
 var actual_cap: float=f.sim.hero.stats.cdr
 f.sim.common.runtime.reset_run();f.sim.common.refresh_stats(false)
 check(f.sim.common.runtime.cooldown_groups==0 and f.sim.common.runtime.cooldown_elites==0 and f.sim.common.runtime.cooldown_bosses==0,"new run resets G05 growth")
 observations.G05={"ordinary_kills":actual_ordinary,"grown_cdr":actual_cdr,"global_cap":actual_cap};f.sim.free()
 finish_case("G05",failed_before)
func test_g06()->void:
 var failed_before: int=failures.size()
 var basic_cases: Array=[]
 for speed in [8.0,6.0,4.0,0.0]:
  var f: Dictionary=fresh("common_g06");combat(f);f.sim.set_projected_stats({"move_speed":6.0})
  var e: Dictionary=target(f);e.speed=speed
  var expected: float=36*(1+minf(.30,maxf(0,6-speed)*.05))
  var actual: float=basic(f,e)
  near(actual,expected,"G06 actual stationary BASIC speed attributes "+str(speed))
  basic_cases.append({"hero_speed":f.sim.hero.speed(),"target_speed":speed,"actual_damage":actual,"expected":expected})
  check(f.sim.hero.position==Vector3.ZERO,"zero displacement still benefits from stat speed")
  f.sim.free()
 var f: Dictionary=fresh("common_g06");combat(f);f.sim.set_projected_stats({"move_speed":6.0})
 var e: Dictionary=target(f);e.speed=6;e.slow_left=2;e.slow_amount=.5
 near(basic(f,e),36*1.15,"target slow participates")
 f.sim.free()
 f=fresh("common_g06");learn(f);combat(f);f.sim.set_projected_stats({"move_speed":10.0})
 e=target(f,"minion",10000,Vector3(2,0,0));cast_q1(f);f.sim.step(.2)
 near(10000-e.hp,65*1.30,"G06 actual Q1 cap30")
 observations.G06={"basic_cases":basic_cases,"q1_capped":10000-e.hp};f.sim.free()
 finish_case("G06",failed_before)
func test_g15()->void:
 var failed_before: int=failures.size()
 var f: Dictionary=fresh("common_g15");var base: float=f.sim.hero.speed()
 near(f.sim.hero.speed(),base,"zero CDR grants zero extra move speed")
 combat(f);f.sim.set_projected_stats({"cdr":.25})
 near(f.sim.hero.speed(),base*1.10,"G15 actual capped-CDR speed sink")
 var actual25: float=f.sim.hero.speed()/base
 f.sim.hero.move_intent=Vector3.RIGHT;var before: Vector3=f.sim.hero.position;f.sim.step(.1)
 near(f.sim.hero.position.distance_to(before),base*1.10*.1,"actual locomotion consumes G15 speed")
 f.sim.set_projected_stats({"cdr":.90});near(f.sim.hero.speed(),base*1.26,"overflow excluded above65 CDR")
 f.sim.paused=true;before=f.sim.hero.position;f.sim.step(1)
 check(f.sim.hero.position==before,"pause freezes locomotion")
 observations.G15={"cdr25_speed_multiplier":actual25,"cdr90_capped_multiplier":f.sim.hero.speed()/base};f.sim.free()
 finish_case("G15",failed_before)
func test_g24()->void:
 var failed_before: int=failures.size()
 var f: Dictionary=fresh("common_g24")
 near(f.sim.hero.stats.max_hp,360*1.24,"six empty slots capped at four for HP")
 near(f.sim.hero.hp,360,"G24 maxHP increase never heals")
 var initial_max_hp: float=f.sim.hero.stats.max_hp
 combat(f);var e: Dictionary=target(f);var initial_damage: float=basic(f,e);near(initial_damage,36*1.32,"G24 actual BASIC final damage")
 f.sim.damage_enemy(e,10000,"attack",0,true,false,{"no_reactions":true})
 check(e.dead,"retire original probe with actual source damage before distinct kill targets")
 check(f.b.model.bind_floor(f.owner,f.sim,"initial-sink").accepted,"G24 verified reward binding")
 for index in range(15):
  if not earn_kill(f,"elite"):f.sim.free();return
 safe_shop(f,"g24-safe")
 for index in range(3):check(shop(f,"buy",{"item":"base:B01"}).accepted,"source equipment purchase")
 near(f.sim.hero.stats.max_hp,360*1.18,"three empty equipment slots immediately recompute HP")
 near(f.sim.hero.stats.common_damage_multiplier,1.24,"three empty slots recompute damage")
 var after_buy: Dictionary={"slots":f.b.model.state.inventory.size(),"max_hp":f.sim.hero.stats.max_hp,"damage_multiplier":f.sim.hero.stats.common_damage_multiplier,"gold":f.b.model.state.gold}
 check(shop(f,"undo").accepted,"same journal purchase inverse")
 near(f.sim.hero.stats.max_hp,360*1.24,"undo restores fourth empty slot")
 observations.G24={"initial_max_hp":initial_max_hp,"initial_basic":initial_damage,"after_three_purchases":after_buy,"undo_max_hp":f.sim.hero.stats.max_hp};f.sim.free()
 finish_case("G24",failed_before)
func test_g30()->void:
 var failed_before: int=failures.size()
 var f: Dictionary=fresh("common_g30");var defence: float=f.sim.hero.stats.defence
 near(f.sim.hero.stats.max_hp,360,"zero gold no invented G30 bonus")
 combat(f);check(f.b.model.bind_floor(f.owner,f.sim,"initial-sink").accepted,"G30 real reward ledger binding")
 for index in range(25):
  if not earn_kill(f):f.sim.free();return
 check(f.b.model.state.gold==500,"25 real kills make actual500 gold")
 near(f.sim.hero.stats.defence,defence+4,"G30 exact defence sink")
 near(f.sim.hero.stats.max_hp,395,"G30 exact maxHP sink")
 near(f.sim.hero.hp,360,"earned maxHP never heals")
 var earned: Dictionary={"gold":f.b.model.state.gold,"defence_added":f.sim.hero.stats.defence-defence,"max_hp_added":f.sim.hero.stats.max_hp-360}
 var before: float=f.sim.hero.hp;f.sim.damage_hero(100,Vector3.ZERO,0,false,true)
 near(before-f.sim.hero.hp,100*100/(100+defence+4),"actual incoming mitigation uses G30 defence")
 safe_shop(f,"g30-safe");check(shop(f,"buy",{"item":"base:B01"}).accepted,"spend same ledger gold")
 check(f.b.model.state.gold<500,"wallet spending consumes no phantom balance")
 near(f.sim.hero.stats.defence,defence,"spending immediately removes G30 defence")
 near(f.sim.hero.stats.max_hp,360,"spending immediately removes G30 HP")
 observations.G30={"earned":earned,"gold_after_spend":f.b.model.state.gold,"defence_after_spend":f.sim.hero.stats.defence,"max_hp_after_spend":f.sim.hero.stats.max_hp};f.sim.free()
 finish_case("G30",failed_before)
