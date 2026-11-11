extends RefCounted
## Fixture-only regression, after authenticated Boot. No engine launched here.
## Real fresh Session/Bridge, commerce commands, source damage/death and task API.
## EXPLICIT FIXTURES: 20000 gold, isolated selected Hex lists, HP setup, spawn HP/
## ready-state, task threshold setup. Combat uses source begin/end plus original
## owner commerce room API, NOT a selected map or naturally earned money claim.
## Parent's separate native run verifies real mouse/UI and Session.observe_event.
var checks:Array=[]
var failures:Array=[]
var observations:Array=[]
var serial:int=0
var run_serial:int=0
var commerce_case_done:bool=false
var source_case_done:bool=false
func check(label:String,ok:bool,detail:Variant=null)->void:
 var row:Dictionary={"check":label,"passed":ok,"detail":detail}
 checks.append(row)
 if not ok:failures.append(row)
func ident()->String:serial+=1;return "focused-g02-command-"+str(serial)
func suspend_fixture(_reason:String)->void:pass
func fresh()->Dictionary:
 run_serial+=1
 var sim=load("res://fengli_route_20261024/sim.gd").new()
 var session=load("res://fengli_route_20261024/session.gd").new()
 var path:String="res://__clean_fengli/machine_templates.bin"
 var conf:Dictionary=session.configure_reward_table(path,path,path,true)
 check("reward_binding",conf.accepted,conf.reason)
 var route:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(session.DEFAULT_DEFINITION))
 var init:Dictionary=session.initialize_floor(sim,route,"focused-g02-"+str(run_serial),true)
 check("real_fresh_Session",init.accepted,init.reason)
 if not init.accepted:sim.free();return {}
 session.bind_input_suspender(suspend_fixture)
 var model:RefCounted=session.ledger.model
 model.command(ident(),"hex_open",{"milestone":1})
 var selected:Dictionary=model.command(ident(),"hex_select",{"milestone":1,"slot":0})
 check("normal_initial_choice",selected.accepted,selected.reason)
 model.state.selected_hex=[] # Isolated neutral projection fixture, not UI selection.
 model.state.gold=20000 # Explicit money fixture, never earned reward evidence.
 session.ledger.refresh_runtime()
 var opened:Dictionary=session.open_panel()
 check("normal_shop_open",opened.accepted,opened.reason)
 return {"sim":sim,"session":session,"model":model,"ledger":session.ledger,"kills":[],"room":0}
func discard(f:Dictionary)->void:
 if not f.is_empty() and is_instance_valid(f.sim):f.sim.free()
func shop(f:Dictionary,action:String,extra:Dictionary={})->Dictionary:
 var args:Dictionary=f.model.commerce_token();args.merge(extra,true)
 return f.session.submit(ident(),action,args)
func protected(f:Dictionary)->Dictionary:
 return {"gold":f.model.state.gold,"inventory":f.model.state.inventory.duplicate(true),"task":f.model._g02_state(),"points":f.model.state.points,"bonus":f.model.state.bonus_sp,"awards":f.model.state.bonus_awards.duplicate(true),"taskLedger":f.model.state.shop_visit.taskLedger.duplicate(true),"stats":f.sim.hero.stats.duplicate(true),"hp":f.sim.hero.hp}
func uid(f:Dictionary,id:String)->int:
 for entry:Dictionary in f.model.state.inventory:
  if entry.id==id:return int(entry.uid)
 return -1
func quote(f:Dictionary,cost:int)->void:
 var q:Dictionary=f.model.commerce_quote("final:G02")
 check("exact_quote_"+str(cost),q.accepted and int(q.get("charge",-1))==cost,q)
func open_shop(f:Dictionary)->bool:
 var result:Dictionary=f.session.open_panel()
 check("reopen_shop",result.accepted,result.reason)
 return result.accepted
func begin_source(f:Dictionary,kinds:Array)->bool:
 f.session.close_panel()
 f.room+=1
 var room:String=f.session.run_id+"/fixture-"+str(f.room)
 var entry:Dictionary=f.session._authority("enter_room",{"next_room":room})
 var level:Dictionary=f.ledger.command("enter_level",{"combat_level_id":room})
 var roster:Array=[]
 for i in range(kinds.size()):roster.append({"kind":kinds[i],"position":Vector3(float(i)*3.0,0,-3),"hp":100.0})
 var begun:Dictionary=f.sim.begin_encounter(room,roster)
 # Ledger Bridge wraps the model receipt as `ok`; Session/source use `accepted`.
 var accepted:bool=bool(entry.get("accepted",false)) and bool(level.get("ok",false)) and bool(begun.get("accepted",false))
 check("real_room_and_source_begin",accepted and f.model.state.phase=="combat",{"room":entry.get("reason","missing_reason"),"level":level.get("reason","missing_reason"),"source":begun.get("reason","missing_reason")})
 for enemy:Dictionary in f.sim.enemies:enemy.state="chase" # Skip spawn windup fixture only.
 return accepted
func end_source(f:Dictionary)->void:f.sim.end_encounter("victory")
func observe(event:Dictionary,f:Dictionary)->void:
 if event.get("kind")!="kill":return
 var witness:Dictionary=f.sim.verify_g02_kill_attribution(f.model,event,f.session.run_id)
 var before:Dictionary=f.model._g02_state()
 var result:Dictionary=f.model.record_battle_event(f.sim,event,f.session.run_id)
 var once:Dictionary=f.model._g02_state()
 var replay:Dictionary=f.model.record_battle_event(f.sim,event,f.session.run_id)
 check("duplicate_live_event_has_no_second_task_increment",f.model._g02_state()==once,replay.reason)
 f.kills.append({"event":event.duplicate(true),"witness":witness,"before":before,"after":once,"result":result})
func packet(f:Dictionary,enemy:Dictionary,amount:float=10000.0)->bool:
 return f.sim.damage_enemy(enemy,amount,"focused_g02_source_packet",0,true,false,{"fixture":true,"direct":true,"no_reactions":true})

func run()->Dictionary:
 checks.clear();failures.clear();observations.clear()
 commerce_case_done=false;source_case_done=false
 commerce_case()
 check("commerce_case_reached_tail",commerce_case_done)
 source_task_case()
 check("source_case_reached_tail",source_case_done)
 var result:Dictionary={"status":"FAIL" if not failures.is_empty() else "FIXTURE_PASS_NOT_NATURAL_FIRST_FLOOR_COMPLETION","checks":checks,"failures":failures,"case_completion":{"commerce_case_done":commerce_case_done,"source_case_done":source_case_done},"observations":observations,"scope":{"fixture_gold":20000,"fixture_threshold_progress":499,"fixture_neutral_or_G27_or_G11_Hexes":true,"fixture_HP_and_spawn_ready":true,"real_Session_shop_commands":true,"real_source_damage_and_death":true,"task_callback":"direct normal model.record_battle_event from original source notification; map Session.observe_event covered separately","natural_income":false,"natural_task_completion":false,"GUI":"NOT_RUN","full_floor":"NOT_RUN"}}
 print("FOCUSED_G02 ",JSON.stringify(result))
 return result

func commerce_case()->void:
 var f:Dictionary=fresh()
 if f.is_empty():return
 var base:Dictionary=f.sim.hero.stats.duplicate(true)
 var hp:float=f.sim.hero.hp
 quote(f,2750)
 check("buy_I13",shop(f,"buy",{"item":"intermediate:I13"}).accepted)
 quote(f,1550)
 check("undo_I13",shop(f,"undo").accepted)
 check("buy_I17",shop(f,"buy",{"item":"intermediate:I17"}).accepted)
 quote(f,1600)
 check("buy_I13_again",shop(f,"buy",{"item":"intermediate:I13"}).accepted)
 quote(f,400)
 var components:Dictionary=protected(f)
 var args:Dictionary=f.model.commerce_token();args.item="final:G02"
 var id:String=ident()
 var crafted:Dictionary=f.session.submit(id,"buy",args)
 check("buy_dispatch_consumes_actual_components_once",crafted.accepted and f.model.state.inventory.size()==1 and uid(f,"final:G02")>=0 and f.model.state.gold==components.gold-400,crafted)
 if not crafted.accepted:discard(f);return
 check("authored_G02_four_stats",is_equal_approx(f.sim.hero.stats.ad,float(base.ad)+30.0) and is_equal_approx(f.sim.hero.stats.ap,float(base.ap)+45.0) and is_equal_approx(f.sim.hero.stats.max_hp,float(base.max_hp)+250.0) and is_equal_approx(f.sim.hero.stats.cdr,float(base.cdr)+0.1),f.sim.hero.stats)
 check("component_to_final_net_HP60_no_healing",is_equal_approx(float(f.sim.hero.stats.max_hp)-float(components.stats.max_hp),60.0) and is_equal_approx(f.sim.hero.hp,hp))
 var once:Dictionary=protected(f)
 var replay:Dictionary=f.session.submit(id,"buy",args)
 check("duplicate_buy_no_second_debit_or_stats",replay.accepted and not replay.get("changed",true) and protected(f)==once,replay)
 f.session.close_panel();open_shop(f)
 check("close_reopen_does_not_commit_undo",shop(f,"undo").accepted and f.model.state.inventory==components.inventory and f.model.state.gold==components.gold)
 f.model.state.selected_hex=["common_g27"] # Explicit projection fixture.
 f.ledger.refresh_runtime()
 f.sim.hero.hp=f.sim.hero.stats.max_hp # Explicit full-HP setup before new transaction.
 f.sim.observe_pending_health()
 var with_components:Dictionary=protected(f)
 var craft27:Dictionary=shop(f,"craft",{"item":"final:G02"})
 check("G27_components_35pct_final_no_bonus",craft27.accepted and is_equal_approx(float(with_components.stats.max_hp)-float(f.sim.hero.stats.max_hp),6.5) and is_equal_approx(float(f.sim.hero.stats.ad),float(base.ad)+30.0),craft27)
 check("craft_records_only_own_HP_clamp",is_equal_approx(float(craft27.get("health_projection",{}).get("transaction_clamp",-1)),6.5))
 var undo27:Dictionary=shop(f,"undo")
 check("undo_restores_own6_5_clamp_and_original_components",undo27.accepted and is_equal_approx(f.sim.hero.hp,float(with_components.hp)) and f.model.state.inventory==with_components.inventory and f.model.state.gold==with_components.gold,undo27)
 # Real source healing seals an HP-sensitive transaction; the prior deficit is
 # explicitly a fixture, not an invented damage or potion receipt.
 f.sim.hero.hp-=20.0;f.sim.observe_pending_health()
 check("recraft_for_health_dependency",shop(f,"craft",{"item":"final:G02"}).accepted)
 var gained:float=f.sim.heal(1.0,false,{"fixture":"real_heal_after_craft"})
 var before_denied:Dictionary=protected(f)
 var denied:Dictionary=shop(f,"undo")
 check("actual_heal_prevents_stale_HP_undo",gained>0.0 and not denied.accepted and protected(f)==before_denied,denied.reason)
 observations.append({"case":"prices_components_G27_HP_undo","base":base,"component_stats":components.stats,"with_G27":with_components.stats,"final":f.sim.hero.stats.duplicate(true)})
 discard(f)
 commerce_case_done=true

func source_task_case()->void:
 var f:Dictionary=fresh()
 if f.is_empty():return
 check("buy_first_G02",shop(f,"buy",{"item":"final:G02"}).accepted)
 check("buy_second_G02",shop(f,"buy",{"item":"final:G02"}).accepted)
 check("two_copies_stats_but_one_named_task",f.model.equipment_effects().stats.AD==60.0 and f.model._g02_state().progress==0)
 f.sim.combat_event.connect(func(event:Dictionary):observe(event,f))
 if not begin_source(f,["minion","minion"]):discard(f);return
 var live:Dictionary=f.sim.enemies[0]
 var before_fake:Dictionary=f.model._g02_state()
 f.sim.emit_event("kill",{"target":live.actor_id,"position":live.position,"source":"forged_fixture","cast_id":0,"credit":"solo_lethal","enemy_kind":live.kind})
 check("public_fake_kill_does_not_progress",f.model._g02_state()==before_fake and not live.dead)
 check("real_damage_death_counts_once_for_two_copies",packet(f,live) and f.model._g02_state().progress==1)
 var saved:Dictionary=f.kills.back().event
 var after:Dictionary=f.model._g02_state()
 var replay:Dictionary=f.model.record_battle_event(f.sim,saved,f.session.run_id)
 check("expired_notification_cannot_replay",f.sim.verify_g02_kill_attribution(f.model,saved,f.session.run_id).is_empty() and f.model._g02_state()==after,replay.reason)
 check("wrong_run_has_no_witness",f.sim.verify_g02_kill_attribution(f.model,saved,"other-run").is_empty())
 end_source(f);open_shop(f)
 check("battle_commits_prior_purchase_undo",not shop(f,"undo").accepted)
 check("sell_one_keeps_named_progress",shop(f,"sell",{"uid":uid(f,"final:G02")}).accepted and f.model._g02_state().progress==1)
 if begin_source(f,["elite"]):
  check("one_remaining_copy_elite_adds10",packet(f,f.sim.enemies[0]) and f.model._g02_state().progress==11)
 end_source(f);open_shop(f)
 check("sell_last_keeps_progress",shop(f,"sell",{"uid":uid(f,"final:G02")}).accepted and uid(f,"final:G02")==-1 and f.model._g02_state().progress==11)
 if begin_source(f,["minion"]):
  packet(f,f.sim.enemies[0])
  check("not_held_freezes_task",f.model._g02_state().progress==11)
 end_source(f);open_shop(f)
 check("rebuy_continues_saved_progress",shop(f,"buy",{"item":"final:G02"}).accepted and f.model._g02_state().progress==11)
 # G11 checks the target's pre-impact snapshot. Use a real no-reaction packet
 # to prepare HP strictly inside the actual threshold, then another nonlethal
 # direct hit to trigger the original execution queue. Never fabricate a kill.
 f.model.state.selected_hex=["common_g11"];f.ledger.refresh_runtime()
 if begin_source(f,["minion"]):
  var target:Dictionary=f.sim.enemies[0]
  var active:bool=f.sim.common.runtime.active("g11")
  var max_hp:float=float(target.max_hp)
  var initial_hp:float=float(target.hp)
  var threshold_fraction:float=float(f.sim.common.runtime.parameter("g11",1))/100.0
  var prepared_hp:float=max_hp*threshold_fraction*0.5
  var kills_before:int=f.kills.size()
  var preparation_killed:bool=f.sim.damage_enemy(target,maxf(0.0,initial_hp-prepared_hp),"focused_g02_G11_HP_preparation",0,true,false,{"fixture":true,"direct":true,"no_reactions":true})
  var trigger_before_hp:float=float(target.hp)
  var trigger_damage:float=trigger_before_hp*0.25
  var setup:Dictionary={"active":active,"initial_hp":initial_hp,"max_hp":max_hp,"threshold_fraction":threshold_fraction,"prepared_hp":trigger_before_hp,"trigger_damage":trigger_damage,"kills_before":kills_before}
  check("G11_fixture_prepares_living_target_below_actual_threshold",active and not preparation_killed and not target.dead and trigger_before_hp>0.0 and trigger_before_hp<max_hp*threshold_fraction and trigger_damage>0.0 and trigger_damage<trigger_before_hp and f.kills.size()==kills_before,setup)
  var killed:bool=f.sim.damage_enemy(target,trigger_damage,"focused_g02_G11_packet",0,true,false,{"fixture":true,"direct":true})
  var new_kill:bool=f.kills.size()==kills_before+1
  var last:Dictionary=f.kills.back() if new_kill else {}
  var original_G11:bool=new_kill and last.get("event",{}).get("source")=="common_g11" and last.get("event",{}).get("target")==target.actor_id and last.get("event",{}).get("room_id")==f.sim.room_id and last.get("event",{}).get("generation")==f.sim.encounter_generation
  var detail:Dictionary={"setup":setup,"killed":killed,"post_hp":target.hp,"post_dead":target.dead,"kills_after":f.kills.size(),"executed":f.sim.common.runtime.executed.has(str(target.actor_id)),"task":f.model._g02_state(),"new_kill":last}
  check("actual_G11_execute_counts_original_death",killed and target.dead and original_G11 and f.model._g02_state().progress==12,detail)
  check("G11_has_distinct_live_execution_proof",original_G11 and last.get("witness",{}).get("witness",{}).get("proof")=="original_common_execute_death",detail)
 end_source(f);open_shop(f)
 f.model.state.selected_hex=[];f.ledger.refresh_runtime()
 var threshold:Dictionary=f.model._g02_state();threshold.progress=499
 f.model.state.g02_equipment_progress=threshold # Explicit threshold fixture only.
 var points:int=f.model.state.points
 var bonus:int=f.model.state.bonus_sp
 if begin_source(f,["minion","minion"]):
  check("499_plus_real_normal_is500_and_one_SP",packet(f,f.sim.enemies[0]) and f.model._g02_state().progress==500 and f.model._g02_state().completed and f.model.state.points==points+1 and f.model.state.bonus_sp==bonus+1)
  packet(f,f.sim.enemies[1])
  check("later_kill_cannot_repeat_completed_reward",f.model.state.points==points+1 and f.model.state.bonus_awards.get("task:G02",{}).get("amount")==1)
 end_source(f);open_shop(f)
 check("completed_sale_preserves_SP",shop(f,"sell",{"uid":uid(f,"final:G02")}).accepted and f.model.state.points==points+1 and f.model._g02_state().completed)
 check("completed_rebuy_no_second_SP",shop(f,"buy",{"item":"final:G02"}).accepted and f.model.state.points==points+1 and f.model._g02_state().completed)
 check("G17_G21_still_unavailable",not f.model.support(f.model.config.hexes.common_g17).supported and not f.model.support(f.model.config.hexes.common_g21).supported)
 var protected_before:Dictionary=protected(f)
 var injected:Dictionary=f.model.command(ident(),"g02_verified_kill",{"proposal":{"completed":true}})
 check("public_task_command_rejected_atomically",not injected.accepted and injected.reason=="g02_verified_original_kill_required" and protected(f)==protected_before,injected.reason)
 observations.append({"case":"source_task_lifecycle","final_task":f.model._g02_state(),"awards":f.model.state.bonus_awards.duplicate(true),"original_notifications":f.kills})
 discard(f)
 source_case_done=true
