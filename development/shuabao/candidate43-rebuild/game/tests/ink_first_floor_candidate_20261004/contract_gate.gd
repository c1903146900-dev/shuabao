extends SceneTree
## FINITE PURE STATE GATE, PREPARED NOT RUN BY AUTHOR.
## Every receipt here is MOCK CALLER DATA. No Sim, ledger, reward or live settlement.
const Schema = preload("res://tests/ink_first_floor_candidate_20261004/route_schema.gd")
const State = preload("res://tests/ink_first_floor_candidate_20261004/row_state.gd")
const Receipt = preload("res://tests/ink_first_floor_candidate_20261004/caller_receipt.gd")
const PATH := "res://tests/ink_first_floor_candidate_20261004/content/first_floor_v0.json"
var checks := 0
var failures: Array = []

func _initialize() -> void:
 var loaded: Dictionary = Schema.load_definition(PATH, true)
 _check(loaded.accepted, "explicit proposal loads")
 if loaded.accepted:
  var definition: Dictionary = loaded.definition
  _schema_gate(definition)
  var index := 0
  for a in ["r02a", "r02b"]:
   for b in ["r07a", "r07b"]:
    index += 1
    _path_gate(definition, ["r01", a, "r03", "r04", "r05", "r06", b, "r08", "r09", "r10", "r11", "r12"], index)
  _isolation_and_abort_gate(definition)
 print(JSON.stringify({"suite":"mixed_v3_pure_row_state", "checks":checks, "failures":failures, "paths":4, "receipt_evidence":"MOCK_CALLER_ASSERTIONS", "live_gameplay":false, "ledger_or_shop_integration":false, "actual_boss_settlement":false, "performance_proved":false, "release":false}))
 quit(0 if failures.is_empty() else 1)

func _schema_gate(d: Dictionary) -> void:
 _check(not Schema.load_definition(PATH).accepted, "no default candidate admission")
 _check(Schema.validate(d, true).possible_node_count == 14, "proposal contains 14 possible nodes")
 var bad: Dictionary = d.duplicate(true)
 bad.release = true
 _check(not Schema.validate(bad, true).accepted, "release promotion denied")
 bad = d.duplicate(true); bad.content_status = "authored_candidate"
 _check(not Schema.validate(bad, true).accepted, "status relabel denied")
 bad = d.duplicate(true); bad.rows[0].nodes[0].next = ["r03"]
 _check(not Schema.validate(bad, true).accepted, "skip-row edge denied")
 bad = d.duplicate(true); bad.rows[0].nodes[0].next = ["r02a"]
 _check(not Schema.validate(bad, true).accepted, "unreachable alternate choice denied")
 bad = d.duplicate(true); bad.rows[1].nodes[0].next = ["r01"]
 _check(not Schema.validate(bad, true).accepted, "back edge denied")
 bad = d.duplicate(true); bad.rows[0].nodes[0].next = ["r02a", "r02a", "r02b"]
 _check(not Schema.validate(bad, true).accepted, "duplicate edge denied")
 bad = d.duplicate(true); bad.rows[10].nodes[0].next = []
 _check(not Schema.validate(bad, true).accepted, "pre-Boss dead end denied")
 bad = d.duplicate(true); bad.rows[11].nodes[0].next = ["r01"]
 _check(not Schema.validate(bad, true).accepted, "Boss outgoing edge denied")
 bad = d.duplicate(true); bad.rows[1].nodes[0].id = "r01"
 _check(not Schema.validate(bad, true).accepted, "duplicate identity denied")
 bad = d.duplicate(true); bad.payloads.r02b.roster[0].hp = 1
 _check(not Schema.validate(bad, true).accepted, "unselected branch HP override denied by retained roster validator")
 bad = d.duplicate(true); bad.payloads.r01.roster[0].reward = 999
 _check(not Schema.validate(bad, true).accepted, "combat reward override denied")
 bad = d.duplicate(true); bad.payloads.r01.kind = "boss"
 _check(not Schema.validate(bad, true).accepted, "early Boss denied")
 bad = d.duplicate(true); bad.payloads.r12.kind = "ordinary"
 _check(not Schema.validate(bad, true).accepted, "last row must be Boss")
 for field in ["roster", "xp", "gold", "reward", "generation", "victory"]:
  bad = d.duplicate(true); bad.payloads.r05[field] = 0
  _check(not Schema.validate(bad, true).accepted, "service rejects even zero payload: " + field)
 bad = d.duplicate(true); bad.payloads.r06.service.type = "shop"
 _check(not Schema.validate(bad, true).accepted, "explicit training type cannot become shop")
 bad = d.duplicate(true); bad.payloads.orphan = bad.payloads.r01.duplicate(true)
 _check(not Schema.validate(bad, true).accepted, "unreferenced payload denied")
 _check(not Schema.validate_path(d, ["r12"], true).accepted, "short path cannot count as floor")

func _entry_payload(state: RefCounted, serial: int, generation: int) -> Dictionary:
 var node: Dictionary = state.selected_node()
 var payload: Dictionary = node.payload
 var result := {"entry_id":"mock-entry-%d" % serial, "room_id":state.snapshot().run_id + "/first_floor/" + node.node_id, "commerce_commit_id":"mock-commit-%d" % serial}
 if payload.node_type == "combat":
  var actors: Array = []
  for index in range(payload.roster.size()): actors.append("mock-actor-%d-%d" % [serial, index])
  result.merge({"generation":generation, "encounter_id":"mock-encounter-%d" % serial, "expected_actor_ids":actors, "boss_actor_id":actors[0] if payload.kind == "boss" else ""})
 else: result.merge({"service_type":payload.kind, "area_id":payload.service.area_id})
 return result

func _completion_payload(entry: Dictionary, serial: int) -> Dictionary:
 var result := {"entry_id":entry.entry_id, "room_id":entry.room_id}
 if entry.has("generation"):
  result.merge({"generation":entry.generation, "encounter_id":entry.encounter_id, "terminal_receipt_id":"mock-terminal-%d" % serial, "defeated_actor_ids":entry.expected_actor_ids.duplicate(), "boss_actor_id":entry.boss_actor_id})
 else: result.merge({"service_type":entry.service_type, "area_id":entry.area_id, "exit_receipt_id":"mock-exit-%d" % serial})
 return result

func _assert_denied_unchanged(state: RefCounted, source: RefCounted, receipt: Receipt, entry: bool, label: String) -> void:
 var before: Dictionary = state.snapshot()
 var result: Dictionary = state.record_entry(source, receipt) if entry else state.record_completion(source, receipt)
 _check(not result.accepted and state.snapshot() == before, label)

func _path_gate(d: Dictionary, path: Array, path_index: int) -> void:
 _check(Schema.validate_path(d, path, true).accepted, "complete legal path %d" % path_index)
 var owner := RefCounted.new()
 var stranger := RefCounted.new()
 var state = State.new()
 var source: Dictionary = d.duplicate(true)
 _check(state.bind_definition(owner, source, "mock-path-%d" % path_index, true).accepted, "single caller bound")
 source.rows.clear()
 _check(state.available_choices().size() == 1, "input definition copied")
 var detached: Array = state.available_choices(); detached.clear()
 _check(state.available_choices().size() == 1, "available choices detached")
 _check(not state.select_node(stranger, 1, "r01").accepted, "wrong caller selection denied")
 _check(not state.select_node(owner, 12, "r12").accepted, "cannot jump to Boss")
 _check(not state.bind_definition(owner, d, "second-run", true).accepted, "bound state cannot restart in place")
 var generation := 0
 var previous_completion: Receipt
 for index in range(12):
  var row_number := index + 1
  _check(not state.select_node(owner, row_number + 1, path[index]).accepted, "skip ahead rejected row %d" % row_number)
  _check(state.select_node(owner, row_number, path[index]).accepted, "explicit selection row %d" % row_number)
  _check(not state.select_node(owner, row_number, path[index]).accepted, "repeat selection rejected")
  _check(state.snapshot().completed_rows.size() == index and state.snapshot().entry_receipt.is_empty(), "selection grants no entry or completion")
  var node: Dictionary = state.selected_node()
  var identity: Dictionary = state.selected_identity()
  var detached_node: Dictionary = state.selected_node(); detached_node.payload.clear()
  _check(not state.selected_node().payload.is_empty(), "selected payload getter cannot alter sealed binding")
  if node.payload.node_type == "combat": generation += 1
  var entered: Dictionary = _entry_payload(state, row_number, generation)
  var complete: Dictionary = _completion_payload(entered, row_number)
  var kind: Receipt.Kind = Receipt.Kind.COMBAT_COMPLETED if node.payload.node_type == "combat" else Receipt.Kind.SERVICE_COMPLETED
  var entry_receipt = Receipt.new(owner, Receipt.Kind.NODE_ENTERED, entered.entry_id, identity, entered)
  var completion = Receipt.new(owner, kind, "mock-completion-%d" % row_number, identity, complete)
  _assert_denied_unchanged(state, owner, completion, false, "completion before actual entry denied")
  var wrong = Receipt.new(stranger, Receipt.Kind.NODE_ENTERED, entered.entry_id, identity, entered)
  _assert_denied_unchanged(state, owner, wrong, true, "different issuer denied")
  for field in ["run_id", "row_state_instance_id", "route_binding_id", "row_number", "node_id", "selected_binding_id"]:
   var stale: Dictionary = identity.duplicate(true); stale[field] = "stale"
   wrong = Receipt.new(owner, Receipt.Kind.NODE_ENTERED, entered.entry_id, stale, entered)
   _assert_denied_unchanged(state, owner, wrong, true, "stale identity denied: " + field)
  if previous_completion != null: _assert_denied_unchanged(state, owner, previous_completion, false, "older row completion rejected")
  if node.payload.node_type == "service":
   var polluted: Dictionary = entered.duplicate(true); polluted.generation = generation
   wrong = Receipt.new(owner, Receipt.Kind.NODE_ENTERED, entered.entry_id, identity, polluted)
   _assert_denied_unchanged(state, owner, wrong, true, "service entry cannot inherit combat generation")
  if index > 0:
   var reused_commit: Dictionary = entered.duplicate(true); reused_commit.commerce_commit_id = "mock-commit-1"
   wrong = Receipt.new(owner, Receipt.Kind.NODE_ENTERED, entered.entry_id, identity, reused_commit)
   _assert_denied_unchanged(state, owner, wrong, true, "cross-row commerce commit replay rejected with fresh identity")
  var wrong_room: Dictionary = entered.duplicate(true); wrong_room.room_id += "-old"
  wrong = Receipt.new(owner, Receipt.Kind.NODE_ENTERED, entered.entry_id, identity, wrong_room)
  _assert_denied_unchanged(state, owner, wrong, true, "wrong entry room rejected")
  if node.payload.node_type == "combat" and generation > 1:
   var stale_generation: Dictionary = entered.duplicate(true); stale_generation.generation = generation - 1
   wrong = Receipt.new(owner, Receipt.Kind.NODE_ENTERED, entered.entry_id, identity, stale_generation)
   _assert_denied_unchanged(state, owner, wrong, true, "entry generation cannot repeat earlier combat")
  # Constructor input, as well as getter snapshots, must be detached.
  var input_identity: Dictionary = identity.duplicate(true)
  var input_payload: Dictionary = entered.duplicate(true)
  var detached_receipt = Receipt.new(owner, Receipt.Kind.NODE_ENTERED, entered.entry_id, input_identity, input_payload)
  input_identity.clear(); input_payload.clear()
  _check(detached_receipt.snapshot() == entry_receipt.snapshot(), "constructor input cannot mutate receipt")
  var receipt_copy: Dictionary = entry_receipt.snapshot(); receipt_copy.payload.clear()
  _check(state.record_entry(owner, entry_receipt).accepted, "typed entry accepted")
  _check(state.snapshot().completed_rows.size() == index and state.available_choices().is_empty(), "entry alone cannot unlock next row")
  _assert_denied_unchanged(state, owner, entry_receipt, true, "repeated entry denied")
  if node.payload.node_type == "combat":
   var incomplete: Dictionary = complete.duplicate(true); incomplete.defeated_actor_ids.pop_back()
   wrong = Receipt.new(owner, kind, "mock-completion-%d" % row_number, identity, incomplete)
   _assert_denied_unchanged(state, owner, wrong, false, "every bound combat actor required")
   incomplete = complete.duplicate(true); incomplete.generation += 1
   wrong = Receipt.new(owner, kind, "mock-completion-%d" % row_number, identity, incomplete)
   _assert_denied_unchanged(state, owner, wrong, false, "stale generation rejected")
  else:
   var polluted: Dictionary = complete.duplicate(true); polluted.gold = 0
   wrong = Receipt.new(owner, kind, "mock-completion-%d" % row_number, identity, polluted)
   _assert_denied_unchanged(state, owner, wrong, false, "service completion cannot carry even zero reward")
   polluted = complete.duplicate(true); polluted.service_type = "training" if entered.service_type == "shop" else "shop"
   wrong = Receipt.new(owner, kind, "mock-completion-%d" % row_number, identity, polluted)
   _assert_denied_unchanged(state, owner, wrong, false, "shop and training identities distinct")
  for malformed in [123, null, [], {}]:
   var malformed_payload: Dictionary = complete.duplicate(true)
   malformed_payload["terminal_receipt_id" if node.payload.node_type == "combat" else "exit_receipt_id"] = malformed
   wrong = Receipt.new(owner, kind, "mock-completion-%d" % row_number, identity, malformed_payload)
   _assert_denied_unchanged(state, owner, wrong, false, "raw terminal identity must be a string")
  if index > 0:
   var replayed_terminal: Dictionary = complete.duplicate(true)
   replayed_terminal["terminal_receipt_id" if node.payload.node_type == "combat" else "exit_receipt_id"] = "mock-terminal-1"
   wrong = Receipt.new(owner, kind, "fresh-replay-probe-%d" % row_number, identity, replayed_terminal)
   _assert_denied_unchanged(state, owner, wrong, false, "cross-row terminal replay rejected with fresh receipt and current identity")
  var wrong_binding: Dictionary = complete.duplicate(true); wrong_binding.entry_id += "-old"
  wrong = Receipt.new(owner, kind, "mock-completion-%d" % row_number, identity, wrong_binding)
  _assert_denied_unchanged(state, owner, wrong, false, "completion must match exact entry ID")
  wrong_binding = complete.duplicate(true); wrong_binding.room_id += "-old"
  wrong = Receipt.new(owner, kind, "mock-completion-%d" % row_number, identity, wrong_binding)
  _assert_denied_unchanged(state, owner, wrong, false, "completion must match exact room ID")
  if node.payload.node_type == "combat":
   wrong_binding = complete.duplicate(true); wrong_binding.encounter_id += "-old"
   wrong = Receipt.new(owner, kind, "mock-completion-%d" % row_number, identity, wrong_binding)
   _assert_denied_unchanged(state, owner, wrong, false, "completion must match exact encounter ID")
  var swapped: Receipt.Kind = Receipt.Kind.SERVICE_COMPLETED if kind == Receipt.Kind.COMBAT_COMPLETED else Receipt.Kind.COMBAT_COMPLETED
  wrong = Receipt.new(owner, swapped, "mock-completion-%d" % row_number, identity, complete)
  _assert_denied_unchanged(state, owner, wrong, false, "completion type cannot be swapped")
  _check(state.record_completion(owner, completion).accepted, "completion accepted exactly once")
  _assert_denied_unchanged(state, owner, completion, false, "repeat completion denied")
  _check(state.snapshot().completed_rows.size() == row_number, "exact sequential completed count")
  previous_completion = completion
 var final: Dictionary = state.snapshot()
 _check(final.status == "all_rows_recorded" and final.ready_for_owner_boss_settlement and not final.settlement_performed, "pure state stops before real floor settlement")
 _check(final.selection_receipts.size() == 12 and final.completed_rows.size() == 12 and generation == 9, "12 chosen and completed rows include nine combat assertions")
 _check(final.completed_rows[4].kind == "shop" and final.completed_rows[5].kind == "training" and final.completed_rows[10].kind == "shop", "service rows never become kills")
 _check(state.available_choices().is_empty() and not state.select_node(owner, 13, "r12").accepted, "no row after Boss")

func _isolation_and_abort_gate(d: Dictionary) -> void:
 var owner := RefCounted.new()
 var state = State.new()
 _check(not state.bind_definition(owner, d, "no-opt-in").accepted, "state also requires explicit developer opt in")
 _check(state.bind_definition(owner, d, "aborted-run", true).accepted, "abort case binds")
 _check(state.select_node(owner, 1, "r01").accepted, "abort case selects")
 var identity: Dictionary = state.selected_identity()
 var entered: Dictionary = _entry_payload(state, 1, 1)
 var receipt = Receipt.new(owner, Receipt.Kind.NODE_ENTERED, entered.entry_id, identity, entered)
 _check(state.record_entry(owner, receipt).accepted, "abort case enters")
 _check(state.abort(owner, "defeated").accepted, "defeat closes only route state")
 _check(state.snapshot().completed_rows.is_empty() and not state.snapshot().settlement_performed, "defeat cannot invent completion or penalty")
 _check(not state.bind_definition(owner, d, "fresh-run", true).accepted, "restart requires fresh RowState")
 var fresh = State.new()
 _check(fresh.bind_definition(owner, d, "fresh-run", true).accepted and fresh.select_node(owner, 1, "r01").accepted, "fresh instance starts independently")
 _assert_denied_unchanged(fresh, owner, receipt, true, "old run receipt rejected by fresh instance")
 var reused_run = State.new()
 _check(reused_run.bind_definition(owner, d, "aborted-run", true).accepted and reused_run.select_node(owner, 1, "r01").accepted, "negative test deliberately reuses run ID with same caller")
 _assert_denied_unchanged(reused_run, owner, receipt, true, "fresh RowState instance rejects old receipt even with reused run ID")
 _check(fresh.abort(owner, "host_closed").accepted, "host close supported without settlement")
 _check(not fresh.select_node(owner, 1, "r01").accepted, "aborted state remains closed")
 var tampered = State.new()
 _check(tampered.bind_definition(owner, d, "tamper-case", true).accepted and tampered.select_node(owner, 1, "r01").accepted, "tamper negative test binds")
 var p: Dictionary = _entry_payload(tampered, 1, 1)
 var r = Receipt.new(owner, Receipt.Kind.NODE_ENTERED, p.entry_id, tampered.selected_identity(), p)
 tampered._selected.payload.roster.clear() # Deliberately violates the private API.
 _check(not tampered.record_entry(owner, r).accepted, "internal selected mutation detected before entry")

func _check(condition: bool, label: String) -> void:
 checks += 1
 if not condition: failures.append(label)
