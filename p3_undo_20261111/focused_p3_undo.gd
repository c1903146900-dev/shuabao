extends RefCounted
## Isolated regression source, not a production overlay or a natural-gameplay claim.
## Run .new().run() only after the existing authenticated Boot loads the candidate.
## Fixture setup grants eight SP. Kills call the actual hero hook with synthetic
## identities inside real begin/end encounter calls, not the public reward pipe.
## Training uses the real ledger context API, not physical Session service entry.
## Corruption/transaction-active tests are explicitly marked adversarial fixtures.
## This author does not launch an engine, GUI, or change the lifecycle guard.

var checks:Array=[]
var failures:Array=[]
var observations:Array=[]

func check(label:String,condition:bool,detail:Variant=null)->void:
 var row:Dictionary={"check":label,"passed":condition,"detail":detail}
 checks.append(row)
 if not condition:failures.append(row)

func state(f:Dictionary)->Dictionary:
 var h:RefCounted=f.sim.hero
 return {"candidate":str(h.loadout.passive),"rank":int(h.ranks.passive),"ledger_rank":int(f.model.state.skills.P.rank),"q_rank":int(h.ranks.q),"progress":int(h.p3_progress),"credited":int(h.credited_kills),"ad":float(h.permanent_ad),"points":int(f.model.state.points),"allocations":f.model.state.allocations.size()}

func fresh()->Dictionary:
 var cfg:Dictionary=load("res://__clean_fengli/machine_template_reader.gd").phase_config("constructor")
 if cfg.is_empty():
  check("authenticated_config",false)
  return {}
 var model=load("res://fengli_route_20261024/potion_model.gd").new(cfg,"fengli")
 check("catalog_valid",model.catalog_errors.is_empty(),model.catalog_errors)
 if not model.catalog_errors.is_empty():return {}
 model.state.points=8 # Explicit unit fixture, no XP/reward authority fabrication.
 var ledger=load("res://tests/ink_first_floor_flow_20261004/ink_ledger_bridge.gd").new()
 ledger.model=model;ledger.definitions=cfg
 var sim=load("res://fengli_route_20261024/sim.gd").new()
 sim.set_progression(ledger)
 var f:Dictionary={"model":model,"ledger":ledger,"sim":sim,"definitions":cfg}
 check("single_model_bound_to_source",sim._p3_bound_model!=null and is_same(sim._p3_bound_model.get_ref(),model))
 return f

func discard(f:Dictionary)->void:
 if not f.is_empty() and is_instance_valid(f.sim):f.sim.free()

func kill_fixture(f:Dictionary,id:String)->void:
 f.sim._hero_killed({"actor_id":id},"attack",1)

func fight(f:Dictionary,id:String,count:int)->void:
 var entered:Dictionary=f.sim.begin_encounter(id,[])
 check(id+"_real_encounter_begin",bool(entered.get("accepted",false)),entered)
 for i in range(count):kill_fixture(f,id+"-"+str(i))
 f.sim.end_encounter("victory")
 check(id+"_safe_after_end",f.model.state.phase=="safe" and f.model.state.allocations.is_empty(),state(f))

func setup_progress(count:int=19)->Dictionary:
 var f:Dictionary=fresh()
 if f.is_empty():return f
 check("setup_learn_P3",bool(f.sim.learn_ability("P","P3").get("ok",false)))
 fight(f,"fixture-initial",count)
 return f

func direct_learn(f:Dictionary,id:String,slot:String="P",candidate:String="P3")->Dictionary:
 return f.model.command(id,"learn",{"slot":slot,"candidate":candidate,"expected_rank":int(f.model.state.skills[slot].rank)})

func run()->Dictionary:
 checks.clear();failures.clear();observations.clear()
 direct_atomic_replay_case()
 sim_no_conversion_case()
 interleaved_case()
 respec_pending_case()
 committed_battle_case()
 combat_upgrade_case()
 existing_room_boundary_case()
 rejected_atomic_case()
 binding_case()
 for rank in range(1,5):threshold_case(rank,[10,9,7,4][rank-1])
 var result:Dictionary={"status":"FAIL" if not failures.is_empty() else "FIXTURE_PASS_NOT_GAMEPLAY_ACCEPTANCE","checks":checks,"failures":failures,"observations":observations,"scope":{"real_model_command":true,"real_sim_skill_APIs":true,"real_source_begin_end":true,"fixture_SP":8,"synthetic_direct_kill_hook":true,"training_context_fixture":true,"live_Session_UI":"NOT_RUN_BY_THIS_TEST","full_rest_service":"NOT_RUN","death_revival":"NOT_RUN","natural_full_floor":"NOT_RUN","old_focused_source_modified":false,"engine_executed_by_author":false}}
 print("FOCUSED_P3_UNDO ",JSON.stringify(result))
 return result

func direct_atomic_replay_case()->void:
 var f:Dictionary=setup_progress()
 if f.is_empty():return
 var before:Dictionary=state(f)
 check("historical_growth_fixture_is_1_AD_9_remainder",before.ad==1.0 and before.progress==9 and before.credited==19,before)
 var event_observations:Array=[]
 var args:Dictionary={"slot":"P","candidate":"P3","expected_rank":1}
 f.sim.combat_event.connect(func(event:Dictionary):
  if event.get("kind","")=="permanent_attack_gained" and event.get("source","")=="p3_rank_change":
   var observed:Dictionary=state(f)
   observed["receipt_ready"]=f.model.receipts.has("direct-upgrade")
   observed["journal_ready"]=not f.model.state.allocations.is_empty() and f.model.state.allocations.back().has("p3_growth")
   observed["replay"]=f.model.command("direct-upgrade","learn",args)
   event_observations.append(observed)
 )
 var learned:Dictionary=f.model.command("direct-upgrade","learn",args)
 var upgraded:Dictionary=state(f)
 check("direct_command_commits_rank_SP_AD_without_UI_sync",learned.accepted and upgraded.rank==2 and upgraded.ledger_rank==2 and upgraded.points==before.points-1 and upgraded.ad==2.0 and upgraded.progress==0 and upgraded.credited==19,upgraded)
 check("event_published_after_receipt_and_journal",event_observations.size()==1 and bool(event_observations[0].receipt_ready) and bool(event_observations[0].journal_ready) and int(event_observations[0].rank)==2 and float(event_observations[0].ad)==2.0,event_observations)
 check("event_callback_replay_does_not_reexecute",event_observations.size()==1 and bool(event_observations[0].replay.get("replayed",false)) and not bool(event_observations[0].replay.get("changed",true)))
 var journal:Dictionary=f.model.state.allocations.back().p3_growth
 check("journal_owns_only_one_conversion",journal.ad_delta==1.0 and journal.spent_progress==9 and journal.command_id=="direct-upgrade",journal)
 f.sim._sync_loadout_from_ledger();f.sim._sync_loadout_from_ledger()
 check("duplicate_UI_projection_is_noop",state(f)==upgraded,state(f))
 var replay:Dictionary=f.model.command("direct-upgrade","learn",args)
 check("duplicate_learn_receipt_is_idempotent",replay.accepted and not replay.get("changed",true) and state(f)==upgraded,replay)
 var conflict:Dictionary=f.model.command("direct-upgrade","learn",{"slot":"P","candidate":"P3","expected_rank":2})
 check("conflicting_id_does_not_touch_growth",not conflict.accepted and conflict.reason=="command_id_conflict" and state(f)==upgraded,conflict)
 var undone:Dictionary=f.model.command("direct-undo","undo_skill")
 check("direct_undo_restores_exact_before_with_historical_AD",undone.accepted and state(f)==before,{"before":before,"after":state(f),"result":undone})
 var undo_replay:Dictionary=f.model.command("direct-undo","undo_skill")
 check("duplicate_undo_does_not_restore_twice",undo_replay.accepted and not undo_replay.get("changed",true) and state(f)==before)
 f.model.command("direct-upgrade","learn",args)
 check("old_learn_replay_after_undo_does_not_reapply",state(f)==before,state(f))
 # A NEW command may redeem the restored unspent kills, then its own undo removes
 # precisely that new conversion. This is not replaying previously spent kills.
 var repeated:Dictionary=direct_learn(f,"upgrade-new-id")
 check("new_upgrade_redeems_restored_unspent_progress",repeated.accepted and state(f).ad==2.0 and state(f).progress==0,state(f))
 f.sim.undo_new_investment()
 check("new_upgrade_undo_no_free_growth",state(f)==before,state(f))
 observations.append({"case":"direct_atomic_replay","before":before,"upgraded":upgraded,"restored":state(f),"events":event_observations})
 discard(f)

func sim_no_conversion_case()->void:
 var f:Dictionary=setup_progress(18)
 if f.is_empty():return
 var before:Dictionary=state(f)
 var result:Dictionary=f.sim.learn_ability("P","P3")
 check("sim_upgrade_below_threshold_retains_remainder",result.get("ok",false) and state(f).progress==8 and state(f).ad==1.0,state(f))
 var undo:Dictionary=f.sim.undo_new_investment()
 check("sim_undo_no_conversion_exact",undo.get("ok",false) and state(f)==before,state(f))
 discard(f)

func interleaved_case()->void:
 var f:Dictionary=setup_progress()
 if f.is_empty():return
 var before:Dictionary=state(f)
 direct_learn(f,"interleave-p2")
 direct_learn(f,"interleave-q1","Q","Q1")
 direct_learn(f,"interleave-p3")
 direct_learn(f,"interleave-p4")
 check("interleaved_upgrades_have_single_growth_gain",state(f).rank==4 and state(f).q_rank==1 and state(f).ad==2.0 and state(f).allocations==4,state(f))
 f.sim.undo_new_investment()
 check("undo_p4_zero_conversion_preserves_p2_gain",state(f).rank==3 and state(f).ad==2.0 and state(f).progress==0,state(f))
 f.model.command("interleave-undo-p3","undo_skill")
 check("undo_p3_zero_conversion_preserves_p2_gain",state(f).rank==2 and state(f).ad==2.0,state(f))
 f.sim.undo_new_investment()
 check("undo_nonP3_allocation_does_not_remove_P3_growth",state(f).q_rank==0 and state(f).rank==2 and state(f).ad==2.0 and state(f).progress==0,state(f))
 f.model.command("interleave-undo-p2","undo_skill")
 check("interleaved_stack_fully_restores_original",state(f)==before,{"before":before,"after":state(f)})
 discard(f)

func respec_pending_case()->void:
 var f:Dictionary=setup_progress()
 if f.is_empty():return
 direct_learn(f,"respec-p2");direct_learn(f,"respec-q1","Q","Q1");direct_learn(f,"respec-p3")
 var pending:Dictionary=state(f)
 var denied:Dictionary=f.model.command("respec-not-training","respec")
 check("respec_training_guard_unchanged_and_atomic",not denied.accepted and denied.reason=="training_required" and state(f)==pending,denied)
 f.ledger.set_training_node(true)
 var reset:Dictionary=f.sim.reset_at_training()
 var after:Dictionary=state(f)
 check("respec_removes_only_uncommitted_upgrade_gain",reset.get("ok",false) and after.rank==0 and after.q_rank==0 and after.points==8 and after.ad==1.0 and after.progress==9 and after.credited==19 and after.allocations==0,after)
 f.sim.learn_ability("P","P1")
 check("other_passive_selection_preserves_historical_growth",state(f).candidate=="p1" and state(f).ad==1.0 and state(f).progress==9,state(f))
 f.sim.reset_at_training()
 check("second_respec_does_not_double_inverse",state(f)==after,state(f))
 f.sim.learn_ability("P","P3")
 check("relearn_P3_does_not_recredit_historical_kills",state(f).rank==1 and state(f).ad==1.0 and state(f).progress==9 and state(f).credited==19,state(f))
 f.sim.learn_ability("P","P3");f.sim.reset_at_training()
 check("relearn_upgrade_respec_still_no_free_growth",state(f)==after,state(f))
 observations.append({"case":"respec_pending","pending":pending,"after":after})
 discard(f)

func committed_battle_case()->void:
 var f:Dictionary=setup_progress()
 if f.is_empty():return
 direct_learn(f,"committed-upgrade")
 fight(f,"fixture-commit",9)
 var committed:Dictionary=state(f)
 check("battle_commits_upgrade_and_new_kill_growth",committed.ad==3.0 and committed.progress==0 and committed.credited==28 and committed.allocations==0,committed)
 var denied:Dictionary=f.sim.undo_new_investment()
 check("cross_battle_undo_boundary_unchanged",not denied.get("ok",false) and denied.reason=="undo_boundary" and state(f)==committed,denied)
 f.ledger.set_training_node(true)
 f.sim.reset_at_training()
 check("training_respec_retains_all_committed_AD",state(f).rank==0 and state(f).ad==3.0 and state(f).credited==28 and state(f).points==8,state(f))
 discard(f)

func combat_upgrade_case()->void:
 var f:Dictionary=fresh()
 if f.is_empty():return
 f.sim.learn_ability("P","P3")
 f.sim.begin_encounter("fixture-combat-upgrade",[])
 for i in range(9):kill_fixture(f,"combat-upgrade-"+str(i))
 var upgrade:Dictionary=direct_learn(f,"combat-upgrade")
 check("combat_upgrade_is_immediately_committed",upgrade.accepted and state(f).rank==2 and state(f).ad==1.0 and state(f).progress==0 and state(f).allocations==0,state(f))
 f.sim.end_encounter("victory")
 var denied:Dictionary=f.sim.undo_new_investment()
 check("combat_upgrade_not_new_safe_undo",not denied.get("ok",false) and denied.reason=="undo_boundary",denied)
 f.ledger.set_training_node(true);f.sim.reset_at_training()
 check("combat_upgrade_growth_survives_training_respec",state(f).ad==1.0 and state(f).rank==0 and state(f).credited==9,state(f))
 discard(f)

func existing_room_boundary_case()->void:
 var f:Dictionary=setup_progress()
 if f.is_empty():return
 direct_learn(f,"room-upgrade")
 # Model boundary fixture only. Does not claim to enter a real Session room.
 var entered:Dictionary=f.model.command("room-boundary","enter_level",{"combat_level_id":"fixture-new-safe-room"})
 check("existing_enter_level_boundary_commits_growth",entered.accepted and state(f).allocations==0 and state(f).ad==2.0,state(f))
 f.ledger.set_training_node(true);f.sim.reset_at_training()
 check("respec_after_existing_room_boundary_preserves_commit",state(f).ad==2.0 and state(f).progress==0,state(f))
 discard(f)

func rejected_atomic_case()->void:
 var f:Dictionary=setup_progress()
 if f.is_empty():return
 var before:Dictionary=state(f)
 var before_model:Dictionary=f.model.state.duplicate(true)
 var stale:Dictionary=f.model.command("stale-upgrade","learn",{"slot":"P","candidate":"P3","expected_rank":0})
 check("stale_rank_failure_changes_neither_source_nor_model",not stale.accepted and stale.reason=="stale_rank" and state(f)==before and f.model.state==before_model,stale)
 # Adversarial fixture: mimic the normal source's active-transaction gate.
 f.sim.transaction_active=true
 var busy:Dictionary=direct_learn(f,"busy-upgrade")
 f.sim.transaction_active=false
 check("active_transaction_denial_is_atomic",not busy.accepted and busy.reason=="transaction_in_progress" and state(f)==before,busy)
 direct_learn(f,"validated-upgrade")
 var valid:Dictionary=f.model.state.allocations.back().p3_growth.duplicate(true)
 # Adversarial fixture: a corrupt private journal is rejected, not partially undone.
 f.model.state.allocations.back().p3_growth.spent_progress=-1
 var corrupt_state:Dictionary=state(f)
 var corrupt_model:Dictionary=f.model.state.duplicate(true)
 var corrupt:Dictionary=f.model.command("corrupt-undo","undo_skill")
 check("invalid_inverse_rejected_before_any_mutation",not corrupt.accepted and corrupt.reason=="invalid_p3_growth_receipt" and state(f)==corrupt_state and f.model.state==corrupt_model,corrupt)
 f.model.state.allocations.back().p3_growth=valid
 f.sim.undo_new_investment()
 check("valid_inverse_after_corruption_fixture_restored",state(f)==before,state(f))
 discard(f)

func binding_case()->void:
 var f:Dictionary=fresh()
 if f.is_empty():return
 var same:Dictionary=f.model.bind_p3_sim(f.sim)
 check("same_binding_is_idempotent",same.accepted)
 var other=load("res://fengli_route_20261024/potion_model.gd").new(f.definitions,"fengli")
 var wrong:Dictionary=other.bind_p3_sim(f.sim)
 check("source_cannot_gain_second_authority",not wrong.accepted and wrong.reason=="p3_sim_has_other_authority",wrong)
 var unbound:Dictionary=other.command("unbound-p3","learn",{"slot":"P","candidate":"P3","expected_rank":0})
 check("unbound_direct_P3_cannot_skip_source_transaction",not unbound.accepted and unbound.reason=="p3_source_not_bound" and other.state.skills.P.rank==0,unbound)
 discard(f)
 var newrun:Dictionary=fresh()
 check("newrun_has_no_growth_or_journal",not newrun.is_empty() and state(newrun).ad==0.0 and state(newrun).progress==0 and state(newrun).credited==0 and state(newrun).allocations==0)
 discard(newrun)

func threshold_case(rank:int,threshold:int)->void:
 var f:Dictionary=fresh()
 if f.is_empty():return
 for i in range(rank):f.sim.learn_ability("P","P3")
 check("rank%d_source_threshold_unchanged"%rank,int(f.sim.v("P3-1",rank))==threshold)
 f.sim.begin_encounter("fixture-threshold-"+str(rank),[])
 for i in range(threshold-1):kill_fixture(f,"threshold-"+str(i))
 check("rank%d_below_threshold"%rank,state(f).ad==0.0 and state(f).progress==threshold-1,state(f))
 kill_fixture(f,"threshold-0")
 check("rank%d_duplicate_kill_no_credit"%rank,state(f).credited==threshold-1 and state(f).progress==threshold-1,state(f))
 kill_fixture(f,"threshold-last")
 check("rank%d_original_kill_growth_preserved"%rank,state(f).ad==1.0 and state(f).progress==0 and state(f).credited==threshold and state(f).allocations==0,state(f))
 f.sim.end_encounter("victory")
 discard(f)
