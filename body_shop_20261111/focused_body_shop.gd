extends RefCounted
## Isolated paid-training regression. Invoke .new().run() only after the original
## authenticated Boot loads the candidate. This file never changes runtime code.
## Real fresh Session/Bridge/Model/Sim bindings and real Session.submit are used.
## EXPLICIT FIXTURES: grant 2700 gold; select initial Hex programmatically; isolated
## stat/cap cases inject body records, clear selected Hexes, or set stat fixtures.
## Source begin/end/clock cases are not claims of selected-map or natural combat.
## Physical UI/natural money/full-floor acceptance belongs to the separate run.

var checks:Array=[]
var failures:Array=[]
var observations:Array=[]
var serial:int=0
const NAMES={"AD":"ad","AP":"ap","attack_speed":"attack_speed","crit_chance":"crit_chance","cooldown_reduction":"cdr","max_hp":"max_hp","defense":"defence","move_speed":"move_speed","lifesteal":"lifesteal","tenacity":"tenacity","penetration":"penetration","hp_regen":"regen"}

func check(label:String,ok:bool,detail:Variant=null)->void:
 var row:Dictionary={"check":label,"passed":ok,"detail":detail}
 checks.append(row)
 if not ok:failures.append(row)

func suspend_fixture(_reason:String)->void:pass

func fresh()->Dictionary:
 serial+=1
 var sim=load("res://fengli_route_20261024/sim.gd").new()
 var session=load("res://fengli_route_20261024/session.gd").new()
 var path:String="res://__clean_fengli/machine_templates.bin"
 var configured:Dictionary=session.configure_reward_table(path,path,path,true)
 check("real_reward_configuration",configured.get("accepted",false),configured.get("reason",""))
 var route:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(session.DEFAULT_DEFINITION))
 var initialized:Dictionary=session.initialize_floor(sim,route,"focused-body-"+str(serial),true)
 check("real_Session_Bridge_bindings",initialized.get("accepted",false),initialized.get("reason",""))
 if not initialized.get("accepted",false):sim.free();return {}
 session.bind_input_suspender(suspend_fixture)
 var model:RefCounted=session.ledger.model
 var opened:Dictionary=model.command("fixture-initial-hex-open","hex_open",{"milestone":1})
 check("real_initial_Hex_open",opened.accepted,opened.reason)
 var selected:Dictionary=model.command("fixture-initial-hex-select","hex_select",{"milestone":1,"slot":0})
 check("real_initial_Hex_select",selected.accepted,selected.reason)
 session.ledger.refresh_runtime()
 model.state.gold=2700 # Explicit fixture funding, not a claimed earned reward.
 return {"sim":sim,"session":session,"model":model,"ledger":session.ledger}

func discard(f:Dictionary)->void:
 if not f.is_empty() and is_instance_valid(f.sim):f.sim.free()

func signature(f:Dictionary)->Dictionary:
 return {"gold":int(f.model.state.gold),"rng":int(f.model.state.rng),"body":f.model.state.body.duplicate(true),"inventory":f.model.state.inventory.duplicate(true),"points":int(f.model.state.points),"stats":f.sim.hero.stats.duplicate(true)}

func token(f:Dictionary)->Dictionary:return f.model.commerce_token().duplicate(true)

func choose_args(f:Dictionary,purchase:Dictionary,outcome:String)->Dictionary:
 var args:Dictionary=token(f)
 args.merge({"purchase_id":int(purchase.purchase_id),"outcome":outcome})
 return args

func run()->Dictionary:
 checks.clear();failures.clear();observations.clear()
 lifecycle_case()
 numeric_and_regen_case()
 effective_cap_case()
 var result:Dictionary={"status":"FAIL" if not failures.is_empty() else "FIXTURE_PASS_NOT_GAMEPLAY_ACCEPTANCE","checks":checks,"failures":failures,"observations":observations,"scope":{"real_fresh_Session_and_Bridge":true,"real_Session_submit":true,"fixture_gold":2700,"numeric_selected_records_fixture":true,"cap_stats_fixture":true,"initial_Hex_programmatic":true,"physical_UI":"NOT_RUN_BY_THIS_TEST","natural_money":"NOT_RUN_BY_THIS_TEST","actual_map_training_and_rest_service":"NOT_RUN","natural_full_floor":"NOT_RUN_BY_THIS_TEST","regen_unit":"existing_20261008_developer_mapping_1.5_per_5_actor_combat_seconds_not_DOCX_unit_quote","engine_executed_by_author":false}}
 print("FOCUSED_BODY_SHOP ",JSON.stringify(result))
 return result

func lifecycle_case()->void:
 var f:Dictionary=fresh()
 if f.is_empty():return
 var opened:Dictionary=f.session.open_panel()
 check("shop_opens_after_initial_Hex",opened.accepted,opened.reason)
 var view:Dictionary=f.session.body_shop_view()
 check("formal12_available_fixed900",view.can_buy and view.cost==900 and view.outcomes.size()==12,view.reason)
 var before:Dictionary=signature(f)
 var paid_args:Dictionary=token(f)
 var paid:Dictionary=f.session.submit("body-pay-1","buy_body",paid_args)
 var pending:Dictionary=f.model.snapshot().body_pending.duplicate(true)
 check("real_pay_single900_debit_three_distinct",paid.accepted and f.model.state.gold==1800 and pending.candidates.size()==3 and pending.candidates[0]!=pending.candidates[1] and pending.candidates[1]!=pending.candidates[2] and pending.candidates[0]!=pending.candidates[2],{"result":paid,"pending":pending})
 if not paid.accepted or pending.get("candidates",[]).size()!=3:discard(f);return
 check("pay_no_slots_no_skill_points_no_shop_undo",f.model.state.inventory==before.inventory and f.model.state.points==before.points and f.model.state.shop_visit.undo.is_empty())
 var after_pay:Dictionary=signature(f)
 var replay:Dictionary=f.session.submit("body-pay-1","buy_body",paid_args)
 check("payment_replay_no_debit_RNG_or_growth",replay.accepted and not replay.get("changed",true) and signature(f)==after_pay,replay)
 var second_while_pending:Dictionary=f.session.submit("body-pay-pending","buy_body",token(f))
 check("pending_blocks_second_payment_atomically",not second_while_pending.accepted and second_while_pending.reason=="body_choice_pending" and signature(f)==after_pay,second_while_pending)
 check("pending_blocks_next_room_boundary",f.session._safe_boundary_reason()=="body_choice_pending",f.session._safe_boundary_reason())
 var closed:Dictionary=f.session.close_panel()
 var reopened:Dictionary=f.session.open_panel()
 check("pending_close_reopen_not_softlocked",closed.accepted and reopened.accepted and f.model.snapshot().body_pending==pending and signature(f)==after_pay,{"close":closed.reason,"reopen":reopened.reason})
 var invalid:Dictionary=f.session.submit("body-choice-invalid","select_body",choose_args(f,pending,"outside-this-offer"))
 check("invalid_choice_does_not_change_economy_or_stats",not invalid.accepted and invalid.reason=="invalid_body_choice" and signature(f)==after_pay,invalid)
 var chosen:String=str(pending.candidates[0])
 var option:Dictionary=f.model.config.body.outcomes[chosen]
 var select_args:Dictionary=choose_args(f,pending,chosen)
 var selected:Dictionary=f.session.submit("body-choice-1","select_body",select_args)
 var after_choice:Dictionary=signature(f)
 var runtime_stat:String=str(option.runtime_stat)
 check("choice_commits_original_body_record_without_charge",selected.accepted and f.model.snapshot().body_pending.is_empty() and f.model.state.body[0].selected==chosen and f.model.state.gold==1800,selected)
 check("choice_projects_real_actor_stat",float(f.sim.hero.stats[NAMES[runtime_stat]])>float(after_pay.stats[NAMES[runtime_stat]]),{"option":chosen,"before":after_pay.stats[NAMES[runtime_stat]],"after":f.sim.hero.stats[NAMES[runtime_stat]]})
 check("choice_uses_authored_amount",is_equal_approx(float(f.model.body_effects()[runtime_stat]),float(option.runtime_value)),option)
 var replay_choice:Dictionary=f.session.submit("body-choice-1","select_body",select_args)
 check("selection_replay_no_duplicate_stat",replay_choice.accepted and not replay_choice.get("changed",true) and signature(f)==after_choice,replay_choice)
 var conflict_args:Dictionary=select_args.duplicate(true);conflict_args.outcome=str(pending.candidates[1])
 var conflict:Dictionary=f.session.submit("body-choice-1","select_body",conflict_args)
 check("selection_ID_conflict_no_new_choice",not conflict.accepted and conflict.reason=="command_id_conflict" and signature(f)==after_choice,conflict)
 var undo:Dictionary=f.session.submit("body-cannot-refund","undo",token(f))
 check("body_has_no_refundable_shop_transaction",not undo.accepted and undo.reason=="undo_boundary" and signature(f)==after_choice,undo)
 var stale:Dictionary=f.session.submit("body-stale-new-ID","buy_body",paid_args)
 check("stale_payment_no_debit_no_RNG",not stale.accepted and stale.reason=="stale_revision" and signature(f)==after_choice,stale)
 var extra:Dictionary=token(f);extra["task_effects"]=[]
 var injected:Dictionary=f.session.submit("body-no-client-authority","buy_body",extra)
 check("client_cannot_supply_task_or_trusted_facts",not injected.accepted and injected.reason=="unsupported_training_argument" and signature(f)==after_choice,injected)
 var raw:Dictionary=token(f);raw["purchase_id"]="untrusted-body"
 var unauthorized:Dictionary=f.model.commerce_command("body-raw-untrusted","pay_body",raw)
 check("raw_untrusted_pay_body_still_denied",not unauthorized.accepted and unauthorized.reason=="authority_required" and signature(f)==after_choice,unauthorized)
 var repeat:Dictionary=f.session.submit("body-pay-2","buy_body",token(f))
 check("repeat_purchase_price_stays900",repeat.accepted and f.model.state.gold==900 and f.model.state.body.size()==2,repeat)
 if not repeat.accepted:discard(f);return
 var pending2:Dictionary=f.model.snapshot().body_pending
 f.session.submit("body-choice-2","select_body",choose_args(f,pending2,str(pending2.candidates[0])))
 var permanent_records:Array=f.model.state.body.duplicate(true)
 f.session.close_panel()
 # Training-context fixture, not a claimed physical map training-node entry.
 f.ledger.set_training_node(true)
 var respec:Dictionary=f.sim.reset_at_training()
 f.ledger.refresh_runtime()
 check("training_respec_cannot_remove_body_growth",respec.get("ok",false) and f.model.state.body==permanent_records and f.model.state.gold==900,respec)
 f.ledger.set_training_node(false)
 var outside:Dictionary=f.session.submit("body-closed-shop","buy_body",token(f))
 check("closed_shop_payment_denied",not outside.accepted and outside.reason=="shop_panel_not_open" and f.model.state.gold==900,outside)
 observations.append({"case":"real_Session_transaction_lifecycle","first_offer":pending,"first_choice":chosen,"second_offer":pending2,"final_gold":f.model.state.gold,"body_records":permanent_records})
 discard(f)

func numeric_and_regen_case()->void:
 var f:Dictionary=fresh()
 if f.is_empty():return
 # Isolated projection fixtures only: remove initial random Hex and install one
 # selected record at a time. Purchase/choice lifecycle is tested separately above.
 f.model.state.selected_hex=[]
 f.model.state.body=[]
 f.ledger.refresh_runtime()
 var base:Dictionary=f.sim.hero.stats.duplicate(true)
 for id:String in f.model.config.body.outcomes:
  var option:Dictionary=f.model.config.body.outcomes[id]
  f.model.state.body=[{"purchase_id":1,"cost":900,"definition_version":f.model.config.version,"candidates":[id],"selected":id}]
  var before_hp:float=f.sim.hero.hp
  var projected:Dictionary=f.ledger.refresh_runtime()
  var stat:String=str(option.runtime_stat)
  var actor_key:String=str(NAMES[stat])
  var amount:float=float(option.runtime_value)
  var expected:float=float(base[actor_key])+amount
  if f.model.config.stat_units[stat]=="base_fraction":expected=float(base[actor_key])*(1.0+amount)
  check(id+"_authored_stat_projects_once",projected.accepted and is_equal_approx(float(f.sim.hero.stats[actor_key]),expected),{"source_value":option.source_value,"runtime_value":amount,"expected":expected,"actual":f.sim.hero.stats[actor_key]})
  if stat=="max_hp":check("maxHP_training_does_not_heal",is_equal_approx(f.sim.hero.hp,before_hp),{"before":before_hp,"after":f.sim.hero.hp})
  var once:Dictionary=f.sim.hero.stats.duplicate(true)
  f.ledger.refresh_runtime()
  check(id+"_repeat_projection_no_accumulation",f.sim.hero.stats==once)
 var regen:Dictionary=f.model.config.body.outcomes["training:12"]
 check("regen_source1_5_is_existing0_3_per_second",float(regen.source_value)==1.5 and is_equal_approx(float(regen.runtime_value),0.3) and str(regen.regen_mapping.rule_provenance)=="developer_balance_regen_per5_combat_seconds_20261008",regen.regen_mapping)
 # The final fixture record is training:12. Exercise the original actor clock
 # and regeneration hook in an empty source encounter, not a fake public kill.
 f.model.state.body=[{"purchase_id":1,"cost":900,"definition_version":f.model.config.version,"candidates":["training:12"],"selected":"training:12"}]
 f.ledger.refresh_runtime()
 f.sim.hero.hp-=50.0 # Explicit damage fixture, not gameplay damage evidence.
 var room:String=f.model.state.shop_visit.room_id
 var entered_level:Dictionary=f.ledger.command("enter_level",{"combat_level_id":room})
 var began:Dictionary=f.sim.begin_encounter(room,[])
 check("regen_source_encounter_started",entered_level.get("ok",false) and began.get("accepted",false),began)
 var hp:float=f.sim.hero.hp
 var rate:float=f.sim.hero.stats.regen
 f.sim.step(5.0)
 check("regen_real_actor_clock_5seconds",is_equal_approx(f.sim.hero.hp-hp,5.0*rate),{"gain":f.sim.hero.hp-hp,"rate":rate,"source_training_gain_per5":1.5})
 f.sim.end_encounter("victory")
 var safe_hp:float=f.sim.hero.hp
 f.sim.step(5.0)
 check("regen_does_not_tick_safe_phase",is_equal_approx(f.sim.hero.hp,safe_hp))
 discard(f)

func effective_cap_case()->void:
 var f:Dictionary=fresh()
 if f.is_empty():return
 var source_before:Dictionary=signature(f)
 var at_caps:Dictionary={"attack_speed":2.5,"cdr":0.65,"tenacity":1.0,"crit_chance":1.0}
 var eligibility:Dictionary=f.model.training_eligibility_for_stats(at_caps)
 check("cap_readonly_filter_excludes_exact_four",eligibility.accepted and eligibility.eligible_ids.size()==8 and eligibility.excluded_ids.size()==4 and eligibility.excluded_ids.has("training:03") and eligibility.excluded_ids.has("training:04") and eligibility.excluded_ids.has("training:05") and eligibility.excluded_ids.has("training:10"),eligibility)
 check("cap_readonly_inspection_does_not_mutate",signature(f)==source_before)
 var nearly:Dictionary={"attack_speed":2.49,"cdr":0.649,"tenacity":0.99,"crit_chance":0.99}
 var partial:Dictionary=f.model.training_eligibility_for_stats(nearly)
 check("partially_effective_options_remain_in_pool",partial.accepted and partial.eligible_ids.size()==12,partial)
 var unavailable:Dictionary=f.model.training_eligibility_for_stats({})
 check("missing_effective_stats_fail_closed",not unavailable.accepted and unavailable.reason=="training_effective_stats_unavailable",unavailable)
 # Adversarial cap fixture checks the authoritative paid draw uses final source
 # values, rather than trusting a caller-provided eligibility list.
 f.session.open_panel()
 f.sim.hero.stats.attack_speed=2.5;f.sim.hero.stats.cdr=0.65;f.sim.hero.stats.tenacity=1.0;f.sim.hero.stats.crit_chance=1.0
 var pay:Dictionary=f.session.submit("cap-paid-offer","buy_body",token(f))
 var pending:Dictionary=f.model.snapshot().body_pending
 var only_effective:bool=pay.get("accepted",false) and pending.get("candidates",[]).size()==3
 for id in pending.get("candidates",[]):only_effective=only_effective and id not in ["training:03","training:04","training:05","training:10"]
 check("actual_paid_draw_excludes_capped_options",only_effective,{"result":pay,"pending":pending})
 f.ledger.refresh_runtime()
 check("changing_effective_stats_never_rerolls_paid_offer",f.model.snapshot().body_pending==pending)
 discard(f)
