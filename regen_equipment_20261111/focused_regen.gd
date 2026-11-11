extends RefCounted
## Fixture-only regression invoked after original authenticated Boot.
## Uses real fresh Session/Bridge, Session.submit, commerce authority and source
## actor clock. Explicit fixtures: 20000 gold, neutral/G27 selected Hexes, HP
## deficit/full-HP setup, empty source encounter and paused flag. No fake reward.
## Map/UI/naturally earned funds are verified by a separate native run.
var checks:Array=[]
var failures:Array=[]
var observations:Array=[]
var serial:int=0
var run_serial:int=0
var commerce_case_done:bool=false
var health_case_done:bool=false
var source_case_done:bool=false
func check(label:String,ok:bool,detail:Variant=null)->void:
 var row:Dictionary={"check":label,"passed":ok,"detail":detail}
 checks.append(row)
 if not ok:failures.append(row)
func ident()->String:serial+=1;return "focused-regen-command-"+str(serial)
func suspend_fixture(_reason:String)->void:pass
func fresh()->Dictionary:
 run_serial+=1
 var sim=load("res://fengli_route_20261024/sim.gd").new()
 var session=load("res://fengli_route_20261024/session.gd").new()
 var path:String="res://__clean_fengli/machine_templates.bin"
 var conf:Dictionary=session.configure_reward_table(path,path,path,true)
 check("reward_binding",conf.get("accepted",false),conf.get("reason",""))
 var route:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(session.DEFAULT_DEFINITION))
 var init:Dictionary=session.initialize_floor(sim,route,"focused-regen-"+str(run_serial),true)
 check("real_fresh_Session",init.get("accepted",false),init.get("reason",""))
 if not init.get("accepted",false):sim.free();return {}
 session.bind_input_suspender(suspend_fixture)
 var model:RefCounted=session.ledger.model
 model.command(ident(),"hex_open",{"milestone":1})
 var selected:Dictionary=model.command(ident(),"hex_select",{"milestone":1,"slot":0})
 check("normal_initial_choice",selected.get("accepted",false),selected.get("reason",""))
 model.state.selected_hex=[] # Explicit neutral projection fixture.
 model.state.gold=20000 # Explicit funds, not naturally earned income.
 session.ledger.refresh_runtime()
 var opened:Dictionary=session.open_panel()
 check("normal_shop_open",opened.get("accepted",false),opened.get("reason",""))
 return {"sim":sim,"session":session,"model":model,"ledger":session.ledger,"room":0}
func discard(f:Dictionary)->void:
 if not f.is_empty() and is_instance_valid(f.sim):f.sim.free()
func shop(f:Dictionary,action:String,extra:Dictionary={})->Dictionary:
 var args:Dictionary=f.model.commerce_token();args.merge(extra,true)
 return f.session.submit(ident(),action,args)
func signature(f:Dictionary)->Dictionary:
 return {"gold":f.model.state.gold,"inventory":f.model.state.inventory.duplicate(true),"stats":f.sim.hero.stats.duplicate(true),"hp":f.sim.hero.hp}
func uid(f:Dictionary,id:String)->int:
 for entry:Dictionary in f.model.state.inventory:
  if entry.id==id:return int(entry.uid)
 return -1
func quote(f:Dictionary,id:String,cost:int)->void:
 var q:Dictionary=f.model.commerce_quote(id)
 check("exact_quote_"+id+"_"+str(cost),q.get("accepted",false) and int(q.get("charge",-1))==cost,q)
func open_shop(f:Dictionary)->bool:
 var result:Dictionary=f.session.open_panel()
 check("reopen_shop",result.get("accepted",false),result.get("reason",""))
 return result.get("accepted",false)
func begin_source(f:Dictionary)->bool:
 f.session.close_panel()
 f.room+=1
 var room:String=f.session.run_id+"/empty-source-fixture-"+str(f.room)
 var entry:Dictionary=f.session._authority("enter_room",{"next_room":room})
 var level:Dictionary=f.ledger.command("enter_level",{"combat_level_id":room})
 var begun:Dictionary=f.sim.begin_encounter(room,[])
 var accepted:bool=bool(entry.get("accepted",false)) and bool(level.get("ok",false)) and bool(begun.get("accepted",false))
 check("real_room_and_empty_source_begin",accepted and f.model.state.phase=="combat",{"room":entry,"level_ok":level.get("ok",false),"source":begun})
 return accepted
func run()->Dictionary:
 checks.clear();failures.clear();observations.clear()
 commerce_case_done=false;health_case_done=false;source_case_done=false
 commerce_case();check("commerce_case_reached_tail",commerce_case_done)
 health_case();check("health_case_reached_tail",health_case_done)
 source_case();check("source_case_reached_tail",source_case_done)
 var result:Dictionary={"status":"FAIL" if not failures.is_empty() else "FIXTURE_PASS_NOT_NATURAL_GAMEPLAY_ACCEPTANCE","checks":checks,"failures":failures,"observations":observations,"case_completion":{"commerce_case_done":commerce_case_done,"health_case_done":health_case_done,"source_case_done":source_case_done},"scope":{"real_Session_shop_commands":true,"real_source_actor_clock":true,"fixture_funds":20000,"fixture_HP":true,"fixture_selected_Hexes":true,"empty_source_encounter_fixture":true,"paused_flag_fixture":true,"natural_income":false,"physical_UI":"NOT_RUN","full_floor":"NOT_RUN","unit_provenance":"existing_20261008_developer_mapping_not_DOCX_time_unit_quote","new_undo_rule":false,"engine_executed_by_author":false}}
 print("FOCUSED_REGEN ",JSON.stringify(result))
 return result

func commerce_case()->void:
 var f:Dictionary=fresh()
 if f.is_empty():return
 var base:Dictionary=f.sim.hero.stats.duplicate(true)
 var b12:Dictionary=f.model.equipment_runtime_status("base:B12")
 var i12:Dictionary=f.model.equipment_runtime_status("intermediate:I12")
 check("B12_original3_maps_to0_6_base",b12.get("supported",false) and b12.tier=="base" and b12.current_value==3 and is_equal_approx(float(b12.stats.hp_regen),0.6) and b12.regen_mapping.scale==0.2 and b12.rule_provenance=="developer_balance_regen_per5_combat_seconds_20261008",b12)
 check("I12_original5_maps_to1_plusHP190",i12.get("supported",false) and i12.tier=="intermediate" and i12.regen_mapping.current_value==5 and is_equal_approx(float(i12.stats.hp_regen),1.0) and float(i12.stats.max_hp)==190.0,i12)
 quote(f,"base:B12",400);quote(f,"intermediate:I12",1050)
 f.sim.hero.hp-=20.0;f.sim.observe_pending_health() # Explicit HP deficit fixture.
 var before:Dictionary=signature(f)
 var args:Dictionary=f.model.commerce_token();args.item="base:B12"
 var id:String=ident()
 var bought:Dictionary=f.session.submit(id,"buy",args)
 check("B12_buy_cost400_projects_once_no_instant_heal",bought.get("accepted",false) and f.model.state.gold==before.gold-400 and is_equal_approx(f.sim.hero.stats.regen,float(base.regen)+0.6) and f.sim.hero.hp==before.hp and f.sim.hero.stats.max_hp==base.max_hp,bought)
 var once:Dictionary=signature(f)
 var replay:Dictionary=f.session.submit(id,"buy",args)
 check("B12_duplicate_buy_no_double_charge_or_regen",replay.get("accepted",false) and not replay.get("changed",true) and signature(f)==once,replay)
 var healed:float=f.sim.heal(1.0,false,{"source":"focused_unrelated_heal"})
 check("B12_unrelated_heal_does_not_add_seal",healed>0.0 and not f.model.state.shop_visit.undo.back().sealed)
 f.session.close_panel();open_shop(f)
 var undone:Dictionary=shop(f,"undo")
 check("B12_same_visit_undo_keeps_unrelated_heal",undone.get("accepted",false) and f.model.state.gold==before.gold and f.model.state.inventory==before.inventory and is_equal_approx(f.sim.hero.stats.regen,float(base.regen)) and is_equal_approx(f.sim.hero.hp,float(before.hp)+healed),undone)
 check("buy_B06",shop(f,"buy",{"item":"base:B06"}).get("accepted",false))
 quote(f,"intermediate:I12",600)
 check("buy_B12_for_recipe",shop(f,"buy",{"item":"base:B12"}).get("accepted",false))
 quote(f,"intermediate:I12",200)
 var components:Dictionary=signature(f)
 var crafted:Dictionary=shop(f,"craft",{"item":"intermediate:I12"})
 check("I12_recipe_consumes_two_components_cost200",crafted.get("accepted",false) and f.model.state.gold==components.gold-200 and f.model.state.inventory.size()==1 and uid(f,"intermediate:I12")>=0 and uid(f,"base:B06")==-1 and uid(f,"base:B12")==-1,crafted)
 check("I12_projects190HP_and1_regen_no_component_double_count",is_equal_approx(f.sim.hero.stats.max_hp,float(base.max_hp)+190.0) and is_equal_approx(f.sim.hero.stats.regen,float(base.regen)+1.0) and is_equal_approx(f.sim.hero.stats.max_hp-float(components.stats.max_hp),50.0) and f.sim.hero.hp==components.hp)
 check("I12_undo_restores_components_gold_and_rates",shop(f,"undo").get("accepted",false) and signature(f)==components)
 check("I12_recraft",shop(f,"craft",{"item":"intermediate:I12"}).get("accepted",false))
 var final_state:Dictionary=signature(f)
 var sold:Dictionary=shop(f,"sell",{"uid":uid(f,"intermediate:I12")})
 check("I12_sell_removes_only_held_stats_refund945",sold.get("accepted",false) and sold.get("refund",-1)==945 and f.model.state.gold==final_state.gold+945 and f.model.state.inventory.is_empty() and is_equal_approx(f.sim.hero.stats.regen,float(base.regen)) and is_equal_approx(f.sim.hero.stats.max_hp,float(base.max_hp)),sold)
 check("I12_undo_sale_restores_original_UID_and_stats",shop(f,"undo").get("accepted",false) and signature(f)==final_state)
 check("I12_second_undo_returns_recipe",shop(f,"undo").get("accepted",false) and signature(f)==components)
 check("undo_B12_component",shop(f,"undo").get("accepted",false))
 check("undo_B06_component",shop(f,"undo").get("accepted",false) and f.model.state.inventory.is_empty())
 f.model.state.selected_hex=["common_g27"] # Explicit isolated projection fixture.
 f.ledger.refresh_runtime()
 check("G27_buy_B06",shop(f,"buy",{"item":"base:B06"}).get("accepted",false))
 check("G27_buy_B12",shop(f,"buy",{"item":"base:B12"}).get("accepted",false))
 var g27_components:Dictionary=signature(f)
 check("G27_component_regen0_81_andHP189",is_equal_approx(f.sim.hero.stats.regen,float(base.regen)+0.81) and is_equal_approx(f.sim.hero.stats.max_hp,float(base.max_hp)+189.0),g27_components.stats)
 check("G27_I12_craft",shop(f,"craft",{"item":"intermediate:I12"}).get("accepted",false))
 check("G27_I12_regen1_35_andHP256_5",is_equal_approx(f.sim.hero.stats.regen,float(base.regen)+1.35) and is_equal_approx(f.sim.hero.stats.max_hp,float(base.max_hp)+256.5) and f.sim.hero.hp==g27_components.hp,f.sim.hero.stats)
 var projected:Dictionary=f.sim.hero.stats.duplicate(true)
 f.ledger.refresh_runtime()
 check("repeat_projection_never_accumulates_regen",f.sim.hero.stats==projected)
 check("G27_I12_undo_exact_recipe_projection",shop(f,"undo").get("accepted",false) and signature(f)==g27_components)
 observations.append({"case":"real_transactions_and_G27","base":base,"G27_components":g27_components.stats,"G27_I12":projected})
 discard(f);commerce_case_done=true

func health_case()->void:
 var f:Dictionary=fresh()
 if f.is_empty():return
 check("HP_case_buy_I12",shop(f,"buy",{"item":"intermediate:I12"}).get("accepted",false))
 f.sim.hero.hp=f.sim.hero.stats.max_hp;f.sim.observe_pending_health() # Explicit full-HP fixture.
 var full:Dictionary=signature(f)
 var sold:Dictionary=shop(f,"sell",{"uid":uid(f,"intermediate:I12")})
 check("I12_sale_clamps_only190",sold.get("accepted",false) and is_equal_approx(float(sold.get("health_projection",{}).get("transaction_clamp",-1)),190.0) and is_equal_approx(float(full.hp)-f.sim.hero.hp,190.0),sold)
 var reverse:Dictionary=shop(f,"undo")
 check("I12_sale_undo_restores_own_clamp_exactly",reverse.get("accepted",false) and signature(f)==full and is_equal_approx(float(reverse.get("health_projection",{}).get("undo_restored_own_clamp",-1)),190.0),reverse)
 check("I12_resell_for_zero_heal",shop(f,"sell",{"uid":uid(f,"intermediate:I12")}).get("accepted",false))
 var zero_heal:float=f.sim.heal(1.0,false,{"source":"focused_full_HP_heal"})
 check("no_effect_heal_does_not_seal_clamp",zero_heal==0.0 and shop(f,"undo").get("accepted",false) and signature(f)==full)
 f.sim.hero.hp=300.0;f.sim.observe_pending_health() # Explicit deficit before a new sale.
 var sale_deficit:Dictionary=shop(f,"sell",{"uid":uid(f,"intermediate:I12")})
 check("I12_deficit_sale_has_zero_clamp",sale_deficit.get("accepted",false) and float(sale_deficit.get("health_projection",{}).get("transaction_clamp",-1))==0.0,sale_deficit)
 var healed:float=f.sim.heal(1.0,false,{"source":"focused_actual_heal_after_HP_transaction"})
 var protected:Dictionary=signature(f)
 var denied:Dictionary=shop(f,"undo")
 check("I12_existing_HP_dependency_blocks_stale_undo",healed>0.0 and not denied.get("accepted",false) and signature(f)==protected,denied)
 observations.append({"case":"existing_HP_clamp_policy","full":full,"last_denial":denied})
 discard(f);health_case_done=true

func source_case()->void:
 var f:Dictionary=fresh()
 if f.is_empty():return
 var base_rate:float=f.sim.hero.stats.regen
 check("clock_buy_B12",shop(f,"buy",{"item":"base:B12"}).get("accepted",false))
 f.sim.hero.hp-=100.0;f.sim.observe_pending_health() # Explicit deficit to observe non-overheal rate.
 var safe_hp:float=f.sim.hero.hp
 f.sim.step(5.0)
 check("B12_safe_phase_has_no_regen",f.sim.hero.hp==safe_hp and not f.model.state.shop_visit.undo.is_empty())
 if not begin_source(f):discard(f);return
 check("new_room_clears_original_shop_undo",f.model.state.shop_visit.undo.is_empty())
 var start_hp:float=f.sim.hero.hp
 var actor_start:float=f.sim.hero_time
 f.sim.paused=true # Same public source pause flag as UI; no timer advance.
 f.sim.step(5.0)
 check("paused_freezes_HP_and_actor_clock",f.sim.hero.hp==start_hp and f.sim.hero_time==actor_start)
 f.sim.paused=false
 f.sim.step(5.0)
 var actor_elapsed:float=f.sim.hero_time-actor_start
 var gain:float=f.sim.hero.hp-start_hp
 check("B12_real_actor5seconds_adds3_beyond_base",is_equal_approx(actor_elapsed,5.0) and is_equal_approx(gain,(base_rate+0.6)*actor_elapsed) and is_equal_approx(gain-base_rate*actor_elapsed,3.0),{"actor_seconds":actor_elapsed,"gain":gain,"rate":f.sim.hero.stats.regen})
 f.sim.end_encounter("victory")
 var after_hp:float=f.sim.hero.hp
 var after_time:float=f.sim.hero_time
 f.sim.step(5.0)
 check("B12_postbattle_freezes_regen",f.sim.hero.hp==after_hp and f.sim.hero_time==after_time)
 open_shop(f)
 var denied:Dictionary=shop(f,"undo")
 check("prior_room_B12_purchase_cannot_be_undone",not denied.get("accepted",false),denied)
 quote(f,"intermediate:I12",650)
 check("clock_upgrade_B12_to_I12",shop(f,"craft",{"item":"intermediate:I12"}).get("accepted",false))
 if not begin_source(f):discard(f);return
 start_hp=f.sim.hero.hp;actor_start=f.sim.hero_time
 f.sim.step(5.0)
 actor_elapsed=f.sim.hero_time-actor_start;gain=f.sim.hero.hp-start_hp
 check("I12_real_actor5seconds_adds5_beyond_base",is_equal_approx(actor_elapsed,5.0) and is_equal_approx(gain,(base_rate+1.0)*actor_elapsed) and is_equal_approx(gain-base_rate*actor_elapsed,5.0),{"actor_seconds":actor_elapsed,"gain":gain,"rate":f.sim.hero.stats.regen})
 f.sim.end_encounter("victory")
 observations.append({"case":"real_source_clocks","base_rate":base_rate,"I12_gain":gain,"natural_funds":false,"empty_source_fixture":true})
 discard(f);source_case_done=true
