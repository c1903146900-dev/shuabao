extends "res://tests/ink_first_floor_session_20261004/floor_session.gd"
## TEST ONLY: MOCK_CALLER_ROWS_FAULT_POSTCONDITION_NOT_GAMEPLAY.
## The mock receipts below affect only pure RowState; never the real Sim/ledger.
## This does NOT exercise genuine Boss combat or the authority preconditions.
## It probes the Session fault postcondition when RowState can no longer abort.
var contract_fault_injected := false

func _complete_floor_authority() -> Dictionary:
 return {"accepted":false, "reason":"CONTRACT_ONLY_REJECTED_AUTHORITY", "changed":false}

func contract_only_fault_with_ready_mock_rows() -> Dictionary:
 if row_state == null or row_state.snapshot().status != "awaiting_selection" or not row_state.snapshot().completed_rows.is_empty(): return _deny("contract_requires_fresh_row_state")
 var generation := 0
 for index in range(12):
  var choices: Array = row_state.available_choices()
  if choices.is_empty(): return _deny("contract_mock_choice_missing")
  var selected: Dictionary = row_state.select_node(self, index + 1, choices[0].node_id)
  if not selected.accepted: return selected
  var node: Dictionary = row_state.selected_node()
  var identity: Dictionary = row_state.selected_identity()
  var entry := {"entry_id":"mock-entry-%d" % index, "room_id":run_id + "/first_floor/" + node.node_id, "commerce_commit_id":"mock-commerce-%d" % index}
  var completion: Dictionary = {}
  var kind: CallerReceipt.Kind = CallerReceipt.Kind.SERVICE_COMPLETED
  if node.payload.node_type == "combat":
   generation += 1
   var actors: Array = []
   for actor_index in range(node.payload.roster.size()): actors.append("mock-actor-%d-%d" % [index, actor_index])
   entry.merge({"generation":generation, "encounter_id":"mock-encounter-%d" % index, "expected_actor_ids":actors, "boss_actor_id":actors[0] if node.payload.kind == "boss" else ""})
   completion = {"entry_id":entry.entry_id, "room_id":entry.room_id, "generation":generation, "encounter_id":entry.encounter_id, "terminal_receipt_id":"mock-terminal-%d" % index, "defeated_actor_ids":actors.duplicate(), "boss_actor_id":entry.boss_actor_id}
   kind = CallerReceipt.Kind.COMBAT_COMPLETED
  else:
   entry.merge({"service_type":node.payload.kind, "area_id":node.payload.service.area_id})
   completion = {"entry_id":entry.entry_id, "room_id":entry.room_id, "service_type":entry.service_type, "area_id":entry.area_id, "exit_receipt_id":"mock-exit-%d" % index}
  var entered: Dictionary = row_state.record_entry(self, CallerReceipt.new(self, CallerReceipt.Kind.NODE_ENTERED, entry.entry_id, identity, entry))
  if not entered.accepted: return entered
  var completed: Dictionary = row_state.record_completion(self, CallerReceipt.new(self, kind, "mock-completion-%d" % index, identity, completion))
  if not completed.accepted: return completed
 if not row_state.snapshot().ready_for_owner_boss_settlement: return _deny("contract_mock_rows_not_ready")
 contract_fault_injected = true
 var rejected_authority: Dictionary = _complete_floor_authority()
 return _fault("boss_settlement_failed:" + str(rejected_authority.reason), rejected_authority)
