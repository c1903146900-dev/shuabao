extends RefCounted
## ISOLATED FIXTURE TEST SOURCE. Not run by its author; not a production overlay.
## Invoke run() only AFTER the normal authenticated Boot has loaded the candidate.
## Uses the real route PotionModel, its real command/undo implementation and real
## Fengli Sim. The lightweight source ledger adapter has no live Session owner.
## Fixture-only: grant four test SP at construction and call the real kill hook
## with synthetic identities. No claim of natural kills or end-to-end UI routing.
## Rest below calls the exact cleanup helper, NOT an entered service settlement.
## The caller owns its existing lifecycle guard and must not relax it for this test.

var checks:Array=[]
var failures:Array=[]
var findings:Array=[]
var observations:Array=[]

func check(label:String,condition:bool,detail:Variant=null)->void:
 var record:Dictionary={"check":label,"passed":condition,"detail":detail}
 checks.append(record)
 if not condition:failures.append(record)

func state(f:Dictionary)->Dictionary:
 var h:RefCounted=f.sim.hero
 return {"candidate":str(h.loadout.passive),"rank":int(h.ranks.passive),"progress":int(h.p3_progress),"credited":int(h.credited_kills),"ad":float(h.permanent_ad),"points":int(f.model.state.points),"allocations":f.model.state.allocations.size()}

func fresh()->Dictionary:
 var machine=load("res://__clean_fengli/machine_template_reader.gd")
 var cfg:Dictionary=machine.phase_config("constructor")
 if cfg.is_empty():
  check("authenticated_machine_config_available",false)
  return {}
 var model=load("res://fengli_route_20261024/potion_model.gd").new(cfg,"fengli")
 check("real_model_catalog_valid",model.catalog_errors.is_empty(),model.catalog_errors)
 if not model.catalog_errors.is_empty():return {}
 # Explicit isolated setup only. No injected XP, reward receipt or live route.
 model.state.points=4
 var ledger=load("res://tests/ink_first_floor_flow_20261004/ink_ledger_bridge.gd").new()
 ledger.model=model;ledger.definitions=cfg
 var sim=load("res://fengli_route_20261024/sim.gd").new()
 sim.set_progression(ledger)
 return {"model":model,"ledger":ledger,"sim":sim,"definitions":cfg}

func kill_fixture(f:Dictionary,id:String)->void:
 # Unit-level direct hook call, deliberately not a forged public battle event.
 f.sim._hero_killed({"actor_id":id},"attack",1)

func discard(f:Dictionary)->void:
 if not f.is_empty() and is_instance_valid(f.sim):f.sim.free()

func run()->Dictionary:
 checks.clear();failures.clear();findings.clear();observations.clear()
 var probe:Dictionary=fresh()
 if probe.is_empty():return report()
 check("P3_admitted_in_real_config","P3" in probe.definitions.get("runtime_candidates",[]))
 var learning=load("res://scripts/ui/skill_learning_projection.gd")
 # Projection is tested with a shallow UI-only state without pending milestone.
 var view:Dictionary=probe.model.snapshot();view.pending_milestones=[]
 var choice:Dictionary=learning.choice(view,probe.definitions,"P","P3")
 check("P3_learning_projection_enabled",bool(choice.enabled),choice)
 discard(probe)
 for rank:int in range(1,5):threshold_case(rank,[10,9,7,4][rank-1])
 immediate_upgrade_and_undo_case()
 respec_and_reselection_case()
 room_rest_newrun_case()
 var result:Dictionary=report()
 print("FOCUSED_P3 ",JSON.stringify(result))
 return result

func threshold_case(rank:int,threshold:int)->void:
 var f:Dictionary=fresh()
 if f.is_empty():return
 for step:int in range(rank):
  var learned:Dictionary=f.sim.learn_ability("P","P3")
  check("rank%d_learn%d"%[rank,step+1],bool(learned.get("ok",false)),learned.get("reason",""))
 check("rank%d_source_threshold"%rank,int(f.sim.v("P3-1",rank))==threshold)
 for i:int in range(threshold-1):kill_fixture(f,"rank%d-kill%d"%[rank,i])
 check("rank%d_before_threshold"%rank,f.sim.hero.p3_progress==threshold-1 and is_zero_approx(f.sim.hero.permanent_ad),state(f))
 kill_fixture(f,"rank%d-kill0"%rank)
 check("rank%d_duplicate_kill_ignored"%rank,f.sim.hero.p3_progress==threshold-1 and f.sim.hero.credited_kills==threshold-1,state(f))
 kill_fixture(f,"rank%d-last"%rank)
 check("rank%d_threshold_awards_once"%rank,f.sim.hero.p3_progress==0 and is_equal_approx(f.sim.hero.permanent_ad,1.0) and f.sim.hero.credited_kills==threshold,state(f))
 var base:float=float(f.sim.hero.stats.ad)
 check("rank%d_growth_in_real_AD"%rank,is_equal_approx(f.sim.hero.ad(),base+1.0))
 f.sim._sync_loadout_from_ledger()
 check("rank%d_repeat_sync_no_award"%rank,is_equal_approx(f.sim.hero.permanent_ad,1.0) and f.sim.hero.p3_progress==0,state(f))
 discard(f)

func immediate_upgrade_and_undo_case()->void:
 var f:Dictionary=fresh()
 if f.is_empty():return
 f.sim.learn_ability("P","P3")
 # Seal first learning through the real model encounter context, then return safe.
 f.ledger.begin_encounter();f.ledger.end_encounter()
 for i:int in range(9):kill_fixture(f,"upgrade-kill%d"%i)
 var before:Dictionary=state(f)
 var learned:Dictionary=f.sim.learn_ability("P","P3")
 var upgraded:Dictionary=state(f)
 check("upgrade_immediate_redemption",bool(learned.get("ok",false)) and upgraded.rank==2 and upgraded.progress==0 and is_equal_approx(upgraded.ad,before.ad+1.0),{"before":before,"after":upgraded})
 var undone:Dictionary=f.sim.undo_new_investment()
 var after:Dictionary=state(f)
 var refunded_growth:bool=bool(undone.get("ok",false)) and after.rank==before.rank and after.points==before.points and float(after.ad)>float(before.ad)
 observations.append({"case":"upgrade_then_undo","before":before,"upgraded":upgraded,"undo_result":undone,"after":after})
 if refunded_growth:
  findings.append({"severity":"BLOCKER_REQUIRES_DECISION_OR_AUTHORIZED_DEPENDENCY_FIX","id":"p3_immediate_redemption_survives_skill_point_refund","detail":"Real model undo restored rank/SP but retained growth earned at the temporarily lower threshold. No automatic fix is applied; approved immediate redemption does not specify undo dependency handling."})
 # Repeating upgrade after undo must not pay again for the spent nine kills.
 var paid:float=f.sim.hero.permanent_ad
 f.sim.learn_ability("P","P3")
 check("spent_historical_kills_not_rewarded_again",is_equal_approx(f.sim.hero.permanent_ad,paid) and f.sim.hero.p3_progress==0,state(f))
 discard(f)

func respec_and_reselection_case()->void:
 var f:Dictionary=fresh()
 if f.is_empty():return
 f.sim.learn_ability("P","P3")
 for i:int in range(11):kill_fixture(f,"respec-kill%d"%i)
 var before:Dictionary=state(f)
 var denied:Dictionary=f.sim.reset_at_training()
 check("respec_requires_training_context",not bool(denied.get("ok",false)),denied.get("reason",""))
 # Exact ledger context API, not evidence of physical entry into a training node.
 f.ledger.set_training_node(true)
 var reset:Dictionary=f.sim.reset_at_training()
 var reset_state:Dictionary=state(f)
 check("respec_clears_slot_and_refunds_points",bool(reset.get("ok",false)) and reset_state.rank==0 and reset_state.points==4,reset_state)
 f.sim.learn_ability("P","P1")
 var before_other:Dictionary=state(f)
 kill_fixture(f,"while-P1")
 check("other_passive_does_not_gain_P3_credit",f.sim.hero.credited_kills==before_other.credited and f.sim.hero.p3_progress==before_other.progress,state(f))
 f.sim.reset_at_training();f.sim.learn_ability("P","P3")
 observations.append({"case":"respec_reselection_existing_behavior","before":before,"after_reset":reset_state,"after_reselection":state(f),"note":"Observe retained run growth and unredeemed remainder; do not invent a clearing rule. This bypasses only UI/service orchestration as an isolated fixture, not production checks."})
 discard(f)

func room_rest_newrun_case()->void:
 var f:Dictionary=fresh()
 if f.is_empty():return
 f.sim.learn_ability("P","P3")
 for i:int in range(11):kill_fixture(f,"room-kill%d"%i)
 var before:Dictionary=state(f)
 var entered:Dictionary=f.sim.begin_encounter("focused-p3-room-1",[])
 check("source_begin_room_accepted",bool(entered.get("accepted",false)),entered)
 check("growth_survives_room_begin",f.sim.hero.p3_progress==before.progress and is_equal_approx(f.sim.hero.permanent_ad,before.ad),state(f))
 f.sim.end_encounter("victory")
 var second:Dictionary=f.sim.begin_encounter("focused-p3-room-2",[])
 check("source_second_room_accepted",bool(second.get("accepted",false)),second)
 check("growth_survives_room_transition",f.sim.hero.p3_progress==before.progress and is_equal_approx(f.sim.hero.permanent_ad,before.ad),state(f))
 f.sim.end_encounter("victory")
 var cleanup=load("res://fengli_route_20261024/rest_service.gd").new(RefCounted.new())
 # Cleanup unit only: does not fabricate entered service/owner receipts or healing.
 cleanup._clear_live_state(f.sim)
 observations.append({"case":"exact_rest_cleanup_helper_only","before":before,"after":state(f),"full_entered_rest_settlement":"NOT_RUN"})
 check("rest_cleanup_preserves_run_growth",f.sim.hero.p3_progress==before.progress and is_equal_approx(f.sim.hero.permanent_ad,before.ad),state(f))
 discard(f)
 var newrun:Dictionary=fresh()
 if newrun.is_empty():return
 check("new_sim_starts_without_old_growth",newrun.sim.hero.p3_progress==0 and newrun.sim.hero.credited_kills==0 and is_zero_approx(newrun.sim.hero.permanent_ad),state(newrun))
 discard(newrun)

func report()->Dictionary:
 return {"status":"FAIL" if not failures.is_empty() else "BLOCKED" if not findings.is_empty() else "FIXTURE_PASS_NOT_GAMEPLAY_ACCEPTANCE","checks":checks,"failures":failures,"blocking_findings":findings,"observations":observations,"scope":{"real_source_model_and_sim":true,"injected_fixture_SP":4,"synthetic_direct_kill_hook":true,"real_public_skill_commands":true,"live_session_UI_path":false,"full_rest_service_transaction":false,"death_and_revival":"NOT_RUN","natural_full_floor":"NOT_RUN","engine_executed_by_author":false}}
