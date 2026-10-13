extends "res://tests/ink_first_floor_session_20261004/floor_session.gd"
## TEST ONLY. Never preload this file from the runtime candidate or its host.
## Explicit one-time startup seed for real buy/undo/room-commit contract proof.
## Not natural earnings, ordinary play, progression, balance or full-floor evidence.
const FUNDING_LABEL := "1500 TEST金币 / SERVICE_DIAGNOSTIC_TOPOLOGY_NOT_NORMAL_PLAY"
var funded_fixture := false
var funding_receipt: Dictionary = {}

func initialize_funded_floor(source_sim: Node, definition: Dictionary, new_run_id: String, explicit_fixture: bool = false) -> Dictionary:
 if not explicit_fixture: return _deny("explicit_funded_fixture_opt_in_required")
 if status != "unbound" or funded_fixture: return _deny("fresh_funded_fixture_required")
 var initialized: Dictionary = initialize_floor(source_sim, definition, new_run_id, true)
 if not initialized.accepted: return initialized
 var s: Dictionary = ledger.model.state
 if s.gold != 0 or s.xp != 0 or s.level != 1 or s.points != 1 or not s.reward_ids.is_empty() or not s.inventory.is_empty() or not s.visited_levels.is_empty() or s.shop_visit.shop_active or not s.selected_hex.is_empty():
  return _deny("fresh_test_funding_precondition_failed")
 if not row_state.snapshot().selection_receipts.is_empty() or not row_state.snapshot().completed_rows.is_empty(): return _deny("fresh_route_required")
 for skill in s.skills.values():
  if skill.rank != 0 or not str(skill.candidate).is_empty(): return _deny("fresh_unlearned_authority_required")
 var original_revision: int = int(s.revision)
 ledger.model.state.gold = 1500
 ledger.model.state.revision = original_revision + 1
 funded_fixture = true
 growth_dirty = true
 funding_receipt = {"type":"diagnostic_initial_funding", "label":FUNDING_LABEL, "gold_before":0, "test_initial_gold":1500, "gold_after":1500, "xp_granted":0, "SP_granted":0, "reward_ids_created":0, "initial_hex_skipped":false, "automatic_learning":false, "initial_revision":original_revision, "funded_revision":ledger.model.state.revision, "ordinary_entry":false, "natural_gold_acceptance":false, "balance_acceptance":false}
 session_events.append(funding_receipt.duplicate(true))
 return {"accepted":true, "reason":"explicit_startup_fixture_initialized", "funding":funding_receipt.duplicate(true)}
