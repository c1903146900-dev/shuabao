extends "res://tests/ink_shop_ui_host_20261004/shop_session.gd"
## Named integration fixture only; original natural-earning session is unchanged.
const FUNDING_LABEL: String="测试初始资金1000 / 非自然赚金 / 非普通入口"
var funded_fixture: bool=false
var funding_receipt: Dictionary={}
func initialize_funded_session(source_sim: Node,new_run_id: String,explicit_fixture: bool=false) -> Dictionary:
 if not explicit_fixture:return _deny("explicit_funded_fixture_opt_in_required")
 if status!="unbound" or funded_fixture:return _deny("fresh_funded_fixture_required")
 var initialized: Dictionary=super.initialize_session(source_sim,new_run_id,true)
 if not initialized.accepted:return initialized
 # Explicitly authorized test seed, exactly once during fresh initialization.
 # The commerce model forbids restore; that prohibition stays unchanged.
 # There is one authority and no reward command, checkpoint or alternate wallet.
 var s: Dictionary=ledger.model.state
 if s.gold!=0 or s.xp!=0 or s.level!=1 or s.points!=0 or not s.reward_ids.is_empty() or not s.inventory.is_empty() or not s.visited_levels.is_empty() or s.shop_visit.shop_active:
  return _deny("fresh_test_funding_precondition_failed")
 var original_revision: int=int(s.revision)
 ledger.model.state.gold=1000
 ledger.model.state.revision=original_revision+1
 funded_fixture=true;growth_dirty=true
 funding_receipt={"type":"diagnostic_initial_funding","label":FUNDING_LABEL,"gold_before":0,"test_initial_gold":1000,"gold_after":ledger.model.state.gold,"xp_granted":0,"SP_granted":0,"reward_ids_created":0,"source":"explicit single fresh diagnostic seed into the one bound ledger; no restore or reward","initial_revision":original_revision,"funded_revision":ledger.model.state.revision,"natural_gold_acceptance":false,"balance_acceptance":false,"ordinary_entry":false}
 session_events.append(funding_receipt.duplicate(true))
 return {"accepted":true,"reason":"explicit_funded_fixture_initialized","funding":funding_receipt.duplicate(true)}
func start_next_room() -> Dictionary:
 if not funded_fixture:return _deny("funded_fixture_not_initialized")
 var result: Dictionary=super.start_next_room()
 if result.accepted:
  # super commits existing owner/token/enter_level/begin_encounter synchronously.
  # The one minion is genuine; no source.step has occurred during this call.
  required_in_room=1;sim.auto_finish=true
  if not session_events.is_empty() and session_events.back().get("type","")=="room_committed":
   session_events.back()["required_actual_minions"]=1
   session_events.back()["fixture_label"]=FUNDING_LABEL
 return result
