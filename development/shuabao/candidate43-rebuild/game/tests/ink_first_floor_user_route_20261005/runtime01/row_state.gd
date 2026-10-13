extends RefCounted
## Pure route state only. No Sim, ledger, commerce, progression, reward or UI owner.
## Selection != entry != completion. Caller receipts are assertions from the bound
## owner; verifying real events and settling the floor remain that owner's job.
## Instance identity blocks old receipts even if a caller mistakenly reuses run_id.
## This is not a persistence API; the Session must still allocate fresh run IDs.
const Schema = preload("res://tests/ink_first_floor_user_route_20261005/runtime01/route_schema.gd")
const Receipt = preload("res://tests/ink_first_floor_candidate_20261004/caller_receipt.gd")
var _owner: WeakRef
var _definition: Dictionary = {}
var _route_binding_id := ""
var _run_id := ""
var _state_instance_id := ""
var _status := "unbound"
var _selected: Dictionary = {}
var _selected_binding_id := ""
var _entry: Dictionary = {}
var _selection_receipts: Array = []
var _completion_receipts: Array = []
var _used_receipt_ids: Dictionary = {}
var _used_commit_ids: Dictionary = {}
var _used_terminal_ids: Dictionary = {}
var _last_generation := 0

func bind_definition(source: RefCounted, definition: Dictionary, run_id: String, allow_developer_proposal: bool = false) -> Dictionary:
 if _status != "unbound": return Schema.deny("row_state_is_single_run")
 if source == null or not Schema.valid_id(run_id): return Schema.deny("caller_or_run_identity_missing")
 var checked: Dictionary = Schema.validate(definition, allow_developer_proposal)
 if not checked.accepted: return checked
 _owner = weakref(source)
 _definition = definition.duplicate(true)
 _route_binding_id = Schema.binding_id(_definition)
 _run_id = run_id
 _state_instance_id = "row-state-%d" % get_instance_id()
 _status = "awaiting_selection"
 return _accepted("route_bound")

func available_choices() -> Array:
 if _status != "awaiting_selection" or not _bindings_intact(): return []
 var row_number := _completion_receipts.size() + 1
 var permitted: Array = []
 if row_number > 1: permitted = _selection_receipts.back().node.next
 var result: Array = []
 for choice in _definition.rows[row_number - 1].nodes:
  if row_number == 1 or choice.id in permitted:
   var payload: Dictionary = _definition.payloads[choice.payload_ref]
   result.append({"row_number":row_number, "node_id":choice.id, "payload_ref":choice.payload_ref, "node_type":payload.node_type, "kind":payload.kind})
 return result.duplicate(true)

func select_node(source: RefCounted, row_number: int, node_id: String) -> Dictionary:
 if not _caller_matches(source): return Schema.deny("wrong_caller_identity")
 if not _bindings_intact(): return Schema.deny("immutable_binding_changed")
 if _status != "awaiting_selection": return Schema.deny("row_not_selectable")
 if row_number != _completion_receipts.size() + 1: return Schema.deny("row_selection_out_of_order")
 var allowed := false
 for choice in available_choices():
  if choice.node_id == node_id: allowed = true
 if not allowed: return Schema.deny("node_not_available")
 _selected = Schema.materialize_node(_definition, row_number, node_id)
 _selected_binding_id = Schema.binding_id(_selected)
 _selection_receipts.append({"identity":selected_identity(), "node":_selected.duplicate(true)})
 _status = "selected"
 return _accepted("node_selected_not_entered")

func selected_identity() -> Dictionary:
 if _selected.is_empty(): return {}
 return {"run_id":_run_id, "row_state_instance_id":_state_instance_id, "route_binding_id":_route_binding_id, "row_number":_selected.row_number, "node_id":_selected.node_id, "selected_binding_id":_selected_binding_id}

func selected_node() -> Dictionary:
 return _selected.duplicate(true)

func record_entry(source: RefCounted, receipt: Receipt) -> Dictionary:
 var checked: Dictionary = _receipt_preflight(source, receipt)
 if not checked.accepted: return checked
 if _status != "selected": return Schema.deny("selection_required_or_already_entered")
 var data: Dictionary = receipt.snapshot()
 if data.kind != Receipt.Kind.NODE_ENTERED: return Schema.deny("entry_receipt_type_required")
 var payload: Dictionary = data.payload
 var keys: Array = ["entry_id", "room_id", "commerce_commit_id"]
 var node_payload: Dictionary = _selected.payload
 if node_payload.node_type == "combat":
  keys.append_array(["generation", "encounter_id", "expected_actor_ids", "boss_actor_id"])
 else: keys.append_array(["service_type", "area_id"])
 if not Schema.exact_keys(payload, keys): return Schema.deny("entry_payload_shape_invalid")
 if not Schema.valid_id(payload.entry_id) or not Schema.valid_id(payload.commerce_commit_id): return Schema.deny("entry_identity_missing")
 if payload.entry_id != data.receipt_id or payload.room_id != _expected_room_id(): return Schema.deny("entry_room_or_receipt_mismatch")
 if _used_commit_ids.has(payload.commerce_commit_id): return Schema.deny("commerce_commit_replayed")
 if node_payload.node_type == "combat":
  if not Schema.whole_number(payload.generation, 1) or int(payload.generation) <= _last_generation: return Schema.deny("stale_combat_generation")
  if not Schema.valid_id(payload.encounter_id): return Schema.deny("encounter_identity_missing")
  if not _unique_ids(payload.expected_actor_ids) or payload.expected_actor_ids.size() != node_payload.roster.size(): return Schema.deny("combat_actor_binding_invalid")
  if node_payload.kind == "boss":
   if not Schema.valid_id(payload.boss_actor_id) or payload.boss_actor_id not in payload.expected_actor_ids: return Schema.deny("boss_actor_binding_missing")
   if _completion_receipts.size() != Schema.ROW_COUNT - 1: return Schema.deny("boss_requires_previous_11_rows")
  elif payload.boss_actor_id != "": return Schema.deny("early_boss_actor_forbidden")
 else:
  if payload.service_type != node_payload.kind or payload.area_id != node_payload.service.area_id: return Schema.deny("service_entry_identity_mismatch")
 # Commit only after all checks. A rejected caller assertion cannot alter the route.
 _entry = data.duplicate(true)
 _used_receipt_ids[data.receipt_id] = true
 _used_commit_ids[payload.commerce_commit_id] = true
 if node_payload.node_type == "combat": _last_generation = int(payload.generation)
 _status = "entered"
 return _accepted("node_entered_not_completed")

func record_completion(source: RefCounted, receipt: Receipt) -> Dictionary:
 var checked: Dictionary = _receipt_preflight(source, receipt)
 if not checked.accepted: return checked
 if _status != "entered": return Schema.deny("entry_required_before_completion")
 var data: Dictionary = receipt.snapshot()
 var payload: Dictionary = data.payload
 var entered: Dictionary = _entry.payload
 var node_payload: Dictionary = _selected.payload
 var terminal_id := ""
 if node_payload.node_type == "combat":
  if data.kind != Receipt.Kind.COMBAT_COMPLETED: return Schema.deny("combat_completion_type_required")
  if not Schema.exact_keys(payload, ["entry_id", "room_id", "generation", "encounter_id", "terminal_receipt_id", "defeated_actor_ids", "boss_actor_id"]): return Schema.deny("combat_completion_payload_invalid")
  if payload.generation != entered.generation or payload.encounter_id != entered.encounter_id: return Schema.deny("stale_combat_completion")
  if not _same_id_set(payload.defeated_actor_ids, entered.expected_actor_ids): return Schema.deny("all_entered_actors_require_completion")
  if payload.boss_actor_id != entered.boss_actor_id: return Schema.deny("boss_completion_identity_mismatch")
  if not Schema.valid_id(payload.terminal_receipt_id): return Schema.deny("terminal_identity_missing_or_replayed")
  terminal_id = payload.terminal_receipt_id
 else:
  if data.kind != Receipt.Kind.SERVICE_COMPLETED: return Schema.deny("service_completion_type_required")
  if not Schema.exact_keys(payload, ["entry_id", "room_id", "service_type", "area_id", "exit_receipt_id"]): return Schema.deny("service_completion_has_no_combat_or_reward_payload")
  if payload.service_type != entered.service_type or payload.area_id != entered.area_id: return Schema.deny("service_completion_identity_mismatch")
  if not Schema.valid_id(payload.exit_receipt_id): return Schema.deny("terminal_identity_missing_or_replayed")
  terminal_id = payload.exit_receipt_id
 if payload.entry_id != _entry.receipt_id or payload.room_id != entered.room_id: return Schema.deny("stale_entry_completion")
 if not Schema.valid_id(terminal_id) or _used_terminal_ids.has(terminal_id): return Schema.deny("terminal_identity_missing_or_replayed")
 if node_payload.kind == "boss" and (_selected.row_number != Schema.ROW_COUNT or _completion_receipts.size() != Schema.ROW_COUNT - 1): return Schema.deny("boss_completion_out_of_order")
 _used_receipt_ids[data.receipt_id] = true
 _used_terminal_ids[terminal_id] = true
 _completion_receipts.append({"identity":selected_identity(), "node_type":node_payload.node_type, "kind":node_payload.kind, "entry":_entry.duplicate(true), "completion":data.duplicate(true)})
 _selected = {}
 _selected_binding_id = ""
 _entry = {}
 _status = "all_rows_recorded" if _completion_receipts.size() == Schema.ROW_COUNT else "awaiting_selection"
 return _accepted("all_rows_recorded_owner_must_settle" if _status == "all_rows_recorded" else "row_completion_recorded")

func abort(source: RefCounted, reason: String) -> Dictionary:
 if not _caller_matches(source): return Schema.deny("wrong_caller_identity")
 if reason not in ["defeated", "host_closed", "faulted"]: return Schema.deny("abort_reason_invalid")
 if _status in ["unbound", "all_rows_recorded", "defeated", "host_closed", "faulted"]: return Schema.deny("row_state_terminal")
 _status = reason
 return _accepted("row_state_aborted_without_settlement")

func snapshot() -> Dictionary:
 return {"schema_version":Schema.SCHEMA_VERSION, "run_id":_run_id, "row_state_instance_id":_state_instance_id, "route_binding_id":_route_binding_id, "status":_status, "row_number":_completion_receipts.size() + 1 if _completion_receipts.size() < Schema.ROW_COUNT else Schema.ROW_COUNT, "selected_identity":selected_identity(), "selected_node":selected_node(), "entry_receipt":_entry.duplicate(true), "selection_receipts":_selection_receipts.duplicate(true), "completed_rows":_completion_receipts.duplicate(true), "ready_for_owner_boss_settlement":_status == "all_rows_recorded", "settlement_performed":false, "release":false, "receipt_evidence":"typed_caller_assertion_only"}

func _receipt_preflight(source: RefCounted, receipt: Receipt) -> Dictionary:
 if not _caller_matches(source) or receipt == null or not receipt.issued_by(source): return Schema.deny("wrong_caller_or_receipt_issuer")
 if not _bindings_intact(): return Schema.deny("immutable_binding_changed")
 if _status in ["unbound", "all_rows_recorded", "defeated", "host_closed", "faulted"]: return Schema.deny("row_state_terminal")
 var data: Dictionary = receipt.snapshot()
 if _selected.is_empty() or data.identity != selected_identity(): return Schema.deny("stale_or_foreign_selected_identity")
 if not Schema.valid_id(data.receipt_id) or _used_receipt_ids.has(data.receipt_id): return Schema.deny("receipt_identity_missing_or_replayed")
 return {"accepted":true, "reason":""}

func _bindings_intact() -> bool:
 if _definition.is_empty() or Schema.binding_id(_definition) != _route_binding_id: return false
 if not _selected.is_empty() and Schema.binding_id(_selected) != _selected_binding_id: return false
 return true

func _caller_matches(source: RefCounted) -> bool:
 return source != null and _owner != null and is_same(_owner.get_ref(), source)

func _expected_room_id() -> String:
 return _run_id + "/first_floor/" + str(_selected.node_id)

func _unique_ids(value) -> bool:
 if not value is Array or value.is_empty(): return false
 var seen: Dictionary = {}
 for id in value:
  if not Schema.valid_id(id) or seen.has(id): return false
  seen[id] = true
 return true

func _same_id_set(left, right: Array) -> bool:
 if not _unique_ids(left) or left.size() != right.size(): return false
 for id in left:
  if id not in right: return false
 return true

func _accepted(reason: String) -> Dictionary:
 return {"accepted":true, "reason":reason, "changed":true, "state":snapshot()}
