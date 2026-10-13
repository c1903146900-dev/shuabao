extends "res://tests/ink_q3_input_growth_20261004/bootstrap_session.gd"
## Opt-in mixed first floor. One inherited live ledger, never a route-owned wallet.
## Host observes combat synchronously and drains terminal callbacks OUTSIDE step().
const MixedSchema = preload("res://tests/ink_first_floor_candidate_20261004/route_schema.gd")
const RowState = preload("res://tests/ink_first_floor_candidate_20261004/row_state.gd")
const CallerReceipt = preload("res://tests/ink_first_floor_candidate_20261004/caller_receipt.gd")
const CommerceProjection = preload("res://tests/ink_shop_ledger_bridge_20261004/commerce_projection.gd")
const Director = preload("res://scripts/combat/enemy_director.gd")
const DEFAULT_DEFINITION = "res://tests/ink_first_floor_candidate_20261004/content/first_floor_v0.json"
var row_state: RefCounted
var active_node_room := ""
var fault: Dictionary = {}
var evidence_ids: Dictionary = {}
var authority_receipts: Array = []
var _active_entry: Dictionary = {}
var _active_node: Dictionary = {}
var _terminal_evidence: Dictionary = {}
var _boss_registration: Dictionary = {}
var _floor_definition_binding := ""
var _service_exit_serial := 0
var _service_present := false
var _service_ready := false

func initialize_session(_source_sim: Node, _new_run_id: String, _diagnostic: bool = false) -> Dictionary:
 return _deny("explicit_initialize_floor_definition_and_opt_in_required")

func initialize_floor(source_sim: Node, definition: Dictionary, new_run_id: String, allow_developer_proposal: bool = false) -> Dictionary:
 if status != "unbound": return _deny("fresh_session_required")
 var checked: Dictionary = MixedSchema.validate(definition, allow_developer_proposal)
 if not checked.accepted: return checked
 if not MixedSchema.valid_id(new_run_id): return _deny("opaque_fresh_run_id_required")
 if not is_instance_valid(source_sim) or source_sim.transaction_active or source_sim.phase != "preparation" or source_sim.wave != 0 or source_sim.encounter_generation != 0 or source_sim.hero.dead: return _deny("fresh_sim_required")
 var candidate = RowState.new()
 var bound: Dictionary = candidate.bind_definition(self, definition, new_run_id, allow_developer_proposal)
 if not bound.accepted: return bound
 # Exactly this parent call constructs/binds commerce and floor once. No second bind.
 var initialized: Dictionary = super.initialize_session(source_sim, new_run_id, false)
 if not initialized.accepted: return initialized
 row_state = candidate
 route = definition.duplicate(true)
 _floor_definition_binding = MixedSchema.binding_id(route)
 # complete_act checks registered real Boss + owner's completion, NOT room_count.
 # This count means selected rows. Unchosen branches are never required/entered.
 ledger.model.config.campaign_acts = {"first_floor":{"name":route.title, "completion_rule":route.completion_rule, "content_status":route.content_status, "room_count":12, "candidate_node_count":checked.possible_node_count, "selection_rule":route.selection_rule, "repeat_reward":false}}
 active_node_room = str(ledger.model.state.shop_visit.room_id)
 session_events.append({"type":"mixed_floor_bound", "route_binding_id":_floor_definition_binding, "selected_rows":12, "possible_nodes":checked.possible_node_count, "topology_approved":false, "normal_full_floor":"HOLD_LV4_POOL"})
 return _record({"accepted":true, "reason":"developer_first_floor_bound", "state":snapshot()})

func available_choices() -> Array:
 if row_state == null or status not in ["preparation", "between_rooms"]: return []
 return row_state.available_choices()

func select_node(row_number: int, node_id: String) -> Dictionary:
 if row_state == null or status not in ["preparation", "between_rooms"]: return _record(_deny("floor_not_selectable"))
 if _transitioning or sim.transaction_active or not terminal_pending.is_empty(): return _record(_deny("defer_to_outer_boundary"))
 if not _owner_intact(): return _record(_deny("wrong_floor_binding"))
 return _record(row_state.select_node(self, row_number, node_id))

func _owner_intact() -> bool:
 return ledger != null and is_instance_valid(sim) and is_same(sim.progression, ledger) and ledger.model._bound(self, sim) and ledger.model._commerce_owner != null and is_same(ledger.model._commerce_owner.get_ref(), self) and ledger.model._run_id == run_id and ledger.model.state.shop_visit.run_id == run_id

func safe_shop_reason() -> String:
 # This is the inherited generic safe-learning/commerce guard, NOT shop location.
 if ledger == null or not is_instance_valid(sim): return "session_unavailable"
 if sim.transaction_active or _transitioning: return "defer_to_outer_boundary"
 if not _owner_intact(): return "wrong_floor_binding"
 if sim.hero.dead or status in ["defeated", "aborted"]: return "not_alive"
 if status not in ["preparation", "between_rooms", "service"] or sim.phase not in ["preparation", "victory"] or ledger.model.state.phase != "safe": return "safe_node_required"
 return ""

func _safe_boundary_reason() -> String:
 var reason := safe_shop_reason()
 if not reason.is_empty(): return reason
 var state: Dictionary = ledger.model.snapshot()
 if initial_modal_open or not state.pending_milestones.is_empty(): return "mandatory_hex_pending"
 if not state.body_pending.is_empty(): return "body_choice_pending"
 if panel_open: return "close_shop_before_room_transition"
 if sim.paused: return "resume_before_room_transition"
 if not terminal_pending.is_empty(): return "terminal_settlement_pending"
 if not _input_suspender.is_valid(): return "input_suspender_missing"
 return ""

func next_room_preflight() -> Dictionary:
 var reason := _safe_boundary_reason()
 if not reason.is_empty(): return _deny(reason)
 if row_state == null or status not in ["preparation", "between_rooms"]: return _deny("complete_current_node_first")
 var rows: Dictionary = row_state.snapshot()
 if rows.status != "selected": return _deny("explicit_node_selection_required")
 if not row_state._bindings_intact() or rows.route_binding_id != _floor_definition_binding or MixedSchema.binding_id(route) != _floor_definition_binding: return _deny("immutable_binding_changed")
 var selected: Dictionary = row_state.selected_node()
 if MixedSchema.binding_id(selected) != rows.selected_identity.selected_binding_id: return _deny("selected_binding_changed")
 var state: Dictionary = ledger.model.snapshot()
 if bool(state.training) != _entered_service("training"): return _deny("training_permission_scope_mismatch")
 var next_room: String = run_id + "/first_floor/" + str(selected.node_id)
 if next_room == state.shop_visit.room_id or next_room in state.shop_visit.visited_rooms or next_room in state.visited_levels: return _deny("fresh_room_required")
 var projected: Dictionary = CommerceProjection.evaluate(state, ledger.model.commerce_definitions, "enter_room", {"next_room":next_room}, true)
 if not projected.accepted: return _deny("commerce_preflight:" + str(projected.reason))
 if selected.payload.node_type == "combat":
  if not sim.living().is_empty(): return _deny("previous_enemy_still_alive")
  var geometry: Dictionary = _roster_preflight(selected.payload)
  if not geometry.accepted: return geometry
  if selected.payload.kind == "boss":
   if rows.completed_rows.size() != 11 or int(selected.row_number) != 12: return _deny("boss_requires_previous_11_rows")
   if ledger.model.config.campaign_acts.get("first_floor", {}).get("completion_rule", "") != route.completion_rule or state.get("act_progress", {}).has("first_floor"): return _deny("fresh_authored_boss_context_required")
 else:
  if selected.payload.service.area_id.is_empty(): return _deny("service_area_missing")
 return {"accepted":true, "reason":"", "next_room":next_room, "selected_identity":rows.selected_identity.duplicate(true), "node":selected, "ledger_revision":state.revision, "source_generation":sim.encounter_generation}

func _roster_preflight(payload: Dictionary) -> Dictionary:
 # Validate the ACTUAL current hero, arena and obstacles; no teleport/reset helper.
 var at: Vector3 = sim.hero.position
 if not at.is_finite() or sim.clamp_position(at, sim.hero_radius).distance_squared_to(at) > 0.000001: return _deny("hero_entry_position_invalid")
 var occupied: Array = []
 for entry in payload.roster:
  if not Director.PROFILES.has(entry.kind): return _deny("roster_profile_missing")
  var position: Vector3 = Vector3(entry.position[0], entry.position[1], entry.position[2])
  var radius: float = float(Director.PROFILES[entry.kind][4])
  if not position.is_finite() or sim.clamp_position(position, radius).distance_squared_to(position) > 0.000001: return _deny("roster_geometry_not_clear")
  if position.distance_to(at) < maxf(Director.ESCAPE_DISTANCE, radius + sim.hero_radius): return _deny("hero_too_close_to_next_spawn")
  for prior in occupied:
   if position.distance_to(prior.position) < radius + float(prior.radius): return _deny("roster_spawns_overlap")
  occupied.append({"position":position, "radius":radius})
 return {"accepted":true, "reason":""}

func start_next_room() -> Dictionary:
 return enter_selected_node()

func start_current_node() -> Dictionary:
 # Prevent the inherited legacy direct enter_level route from bypassing commerce.
 return enter_selected_node()

func begin_new_run(_source_sim: Node, _bridge: RefCounted, _definition: Dictionary, _new_run_id: String, _allow_fixture: bool = false) -> Dictionary:
 return _deny("fresh_initialize_floor_required")

func enter_selected_node() -> Dictionary:
 var ready: Dictionary = next_room_preflight()
 if not ready.accepted: return _record(ready)
 _input_suspender.call("mixed_floor_room_release_required")
 if sim.has_method("cancel_ink_preview"): sim.cancel_ink_preview("mixed_floor_room_transition")
 # A host input callback cannot invalidate our preflight and still commit a room.
 ready = next_room_preflight()
 if not ready.accepted: return _record(ready)
 _transitioning = true
 var committed: Dictionary = _authority("enter_room", {"next_room":ready.next_room})
 if not committed.accepted:
  _transitioning = false
  return _record(committed)
 _service_present = false; _service_ready = false
 active_node_room = ready.next_room
 _active_node = ready.node.duplicate(true)
 var entry_payload: Dictionary = {"entry_id":_evidence_id("entry", {"run_id":run_id, "room_id":active_node_room, "command_id":committed.command_id}), "room_id":active_node_room, "commerce_commit_id":_evidence_id("commerce", {"command_id":committed.command_id, "request":committed.request, "result":committed.source_result})}
 if _active_node.payload.node_type == "combat":
  var started: Dictionary = _enter_combat(entry_payload)
  if not started.accepted: return started
 else:
  var serviced: Dictionary = _enter_service(entry_payload)
  if not serviced.accepted: return serviced
 var receipt = CallerReceipt.new(self, CallerReceipt.Kind.NODE_ENTERED, entry_payload.entry_id, row_state.selected_identity(), entry_payload)
 var entered: Dictionary = row_state.record_entry(self, receipt)
 if not entered.accepted: return _fault("post_commit_row_entry:" + str(entered.reason), entered)
 _active_entry = receipt.snapshot()
 _transitioning = false
 growth_dirty = true
 session_events.append({"type":"mixed_node_entered", "room_id":active_node_room, "kind":_active_node.payload.kind, "node_type":_active_node.payload.node_type, "command_id":committed.command_id, "generation":sim.encounter_generation, "wave":sim.wave})
 return _record({"accepted":true, "reason":"selected_node_entered", "entry":_active_entry.duplicate(true)})

func _enter_combat(entry_payload: Dictionary) -> Dictionary:
 var training: Dictionary = ledger.set_training_node(false)
 if not training.ok: return _fault("post_commit_training_close:" + str(training.reason), training)
 var entered: Dictionary = ledger.command("enter_level", {"combat_level_id":active_node_room})
 if not entered.ok: return _fault("post_commit_enter_level:" + str(entered.reason), entered)
 current_room_id = active_node_room
 current_generation = sim.encounter_generation + 1
 expected_enemies.clear(); kill_receipts.clear(); boss_id = ""
 _terminal_evidence.clear(); _boss_registration.clear()
 required_in_room = _active_node.payload.roster.size(); spawned_in_room = required_in_room
 sim.auto_finish = true
 status = "combat"
 var started: Dictionary = sim.begin_encounter(current_room_id, Route.roster(_active_node.payload))
 if not started.accepted: return _fault("post_commit_begin_encounter:" + str(started.reason), started)
 current_generation = sim.encounter_generation
 for enemy in sim.enemies:
  if not MixedSchema.valid_id(str(enemy.actor_id)) or str(enemy.actor_id) in expected_enemies or enemy.get("dead", false): return _fault("actual_enemy_binding_invalid", {})
  expected_enemies.append(str(enemy.actor_id))
  if enemy.get("rank_category", "") == "boss": boss_id = str(enemy.actor_id)
 if expected_enemies.size() != required_in_room or sim.combat_level_id != current_room_id or ledger.model.state.combat_level_id != current_room_id or ledger.model.state.phase != "combat": return _fault("actual_encounter_binding_invalid", {})
 if _active_node.payload.kind == "boss":
  _boss_registration = ledger.model.register_act_context(sim, "first_floor", boss_id, run_id)
  if not _boss_registration.accepted: return _fault("actual_boss_registration_failed:" + str(_boss_registration.reason), _boss_registration)
 elif not boss_id.is_empty(): return _fault("unexpected_boss_actor", {})
 entry_payload.merge({"generation":current_generation, "encounter_id":_evidence_id("encounter", {"run_id":run_id, "room_id":current_room_id, "generation":current_generation, "wave":sim.wave, "actor_ids":expected_enemies.duplicate()}), "expected_actor_ids":expected_enemies.duplicate(), "boss_actor_id":boss_id}, true)
 return {"accepted":true, "reason":""}

func _enter_service(entry_payload: Dictionary) -> Dictionary:
 # No begin_encounter/enter_level, simulated phase, wave, HP, XP or rewards here.
 var payload: Dictionary = _active_node.payload
 var permission: Dictionary = ledger.set_training_node(payload.kind == "training")
 if not permission.ok: return _fault("post_commit_service_permission:" + str(permission.reason), permission)
 if payload.kind == "shop":
  var visit: Dictionary = _authority("begin_visit", {"area":payload.service.area_id})
  if not visit.accepted: return _fault("post_commit_begin_visit:" + str(visit.reason), visit)
 entry_payload.merge({"service_type":payload.kind, "area_id":payload.service.area_id}, true)
 _service_present = true; _service_ready = false
 status = "service"
 return {"accepted":true, "reason":""}

func _entered_service(kind: String) -> bool:
 if row_state == null or not _service_present or status not in ["service", "between_rooms"] or _active_node.is_empty() or _active_entry.is_empty(): return false
 if _active_node.payload.node_type != "service" or _active_node.payload.kind != kind or active_node_room != ledger.model.state.shop_visit.room_id: return false
 var rows: Dictionary = row_state.snapshot()
 if not _service_ready:
  return rows.status == "entered" and rows.selected_identity == _active_entry.identity and rows.entry_receipt == _active_entry
 # Completing service readiness does not mean physical departure. The previous
 # entry remains authoritative while the player chooses the next row or trades.
 return not rows.completed_rows.is_empty() and rows.completed_rows.back().entry == _active_entry

func open_panel() -> Dictionary:
 if not _entered_service("shop"): return _record(_deny("entered_shop_node_required"))
 var visit: Dictionary = ledger.model.state.shop_visit
 if not visit.shop_active or visit.shop_area != _active_node.payload.service.area_id: return _record(_deny("current_shop_area_required"))
 # Existing open/close and modal release behavior, but cannot create an arbitrary shop.
 return super.open_panel()

func submit(id: String, action: String, args: Dictionary) -> Dictionary:
 if not _entered_service("shop"): return _record(_deny("entered_shop_node_required"))
 return super.submit(id, action, args)

func reset_training() -> Dictionary:
 var reason := _safe_boundary_reason()
 if not reason.is_empty(): return _record(_deny(reason))
 if not _entered_service("training") or not ledger.model.state.training: return _record(_deny("entered_training_node_required"))
 var result: Dictionary = sim.reset_at_training()
 progression_command_completed({"action":"respec", "source":"entered_training_node"}, {"accepted":result.get("ok", false), "reason":result.get("reason", "")})
 return _record({"accepted":result.get("ok", false), "reason":result.get("reason", "")})

func complete_service() -> Dictionary:
 # Mark ready to continue; actual location, shopping and training persist until
 # successful next-room entry. This is not a financial/character checkpoint.
 var reason := _safe_boundary_reason()
 if not reason.is_empty(): return _record(_deny(reason))
 if _service_ready: return _record(_deny("service_already_ready"))
 if not _entered_service("shop") and not _entered_service("training"): return _record(_deny("entered_service_required"))
 if not row_state._bindings_intact(): return _record(_deny("immutable_binding_changed"))
 _transitioning = true
 _service_exit_serial += 1
 var ready_evidence: Dictionary = {"run_id":run_id, "room_id":active_node_room, "entry_id":_active_entry.receipt_id, "explicit_readiness_serial":_service_exit_serial, "physical_departure":false, "meaning":"service_ready_to_continue_while_still_present"}
 # exit_receipt_id is RowState v3's historical field name. Its mapped evidence
 # explicitly states readiness, NOT a fictitious leave_area/enter_room receipt.
 var payload: Dictionary = {"entry_id":_active_entry.receipt_id, "room_id":active_node_room, "service_type":_active_node.payload.kind, "area_id":_active_node.payload.service.area_id, "exit_receipt_id":_evidence_id("service_readiness", ready_evidence)}
 var receipt = CallerReceipt.new(self, CallerReceipt.Kind.SERVICE_COMPLETED, _evidence_id("service_completion", payload), row_state.selected_identity(), payload)
 var completed: Dictionary = row_state.record_completion(self, receipt)
 if not completed.accepted: return _fault("service_readiness_row_completion:" + str(completed.reason), completed)
 cleared.append(active_node_room)
 node_index = row_state.snapshot().completed_rows.size()
 _service_ready = true
 status = "between_rooms"; _transitioning = false
 session_events.append({"type":"service_ready_to_continue", "room_id":active_node_room, "kind":_active_node.payload.kind, "physical_departure":false, "rewards":false})
 return _record({"accepted":true, "reason":"service_ready_still_in_same_area"})

func leave_shop_area() -> Dictionary:
 # Distinct explicit physical-area departure; closing the panel is NOT departure.
 var reason := _safe_boundary_reason()
 if not reason.is_empty(): return _record(_deny(reason))
 if row_state == null or status != "between_rooms" or _active_node.is_empty() or _active_node.payload.kind != "shop": return _record(_deny("complete_shop_interaction_first"))
 var visit: Dictionary = ledger.model.state.shop_visit
 if not visit.shop_active or visit.room_id != active_node_room or visit.shop_area != _active_node.payload.service.area_id: return _record(_deny("current_shop_area_required"))
 var left: Dictionary = _authority("leave_area")
 if left.accepted: _service_present = false
 return _record(left)

func observe_event(source_sim: Node, event: Dictionary) -> Dictionary:
 if not is_same(source_sim, sim) or not _owner_intact(): return _deny("wrong_sim_or_owner")
 if status != "combat": return _deny("floor_not_in_combat")
 if event.get("kind", "") not in ["damage", "kill"]: return {"accepted":true, "reason":"non_progression_event", "changed":false}
 if not _current_event(event): return _deny("wrong_encounter_event")
 if event.kind == "kill" and str(event.get("target", "")) not in expected_enemies: return _deny("enemy_not_in_entered_roster")
 var result: Dictionary = ledger.model.observe_live_event(self, sim, event)
 if result.accepted:
  growth_dirty = growth_dirty or bool(result.get("changed", false))
  if event.kind == "kill":
   # Preserve authenticated event even when the source ring buffer later expires it.
   var target_id: String = str(event.target)
   if not kill_receipts.has(target_id): kill_receipts[target_id] = {"sequence":event.sequence, "reward_id":result.get("reward_id", ""), "generation":current_generation, "event":event.duplicate(true), "source_result":result.duplicate(true)}
 return result

func _authentic_terminal(source_sim: Node, actual_snapshot: Dictionary) -> Dictionary:
 if not is_same(source_sim, sim) or not _owner_intact(): return _deny("wrong_sim_or_owner")
 if status != "combat" or actual_snapshot.get("phase", "") != sim.phase or not _current_event(actual_snapshot): return _deny("stale_terminal_snapshot")
 if actual_snapshot != sim.frozen_snapshot: return _deny("actual_frozen_terminal_snapshot_required")
 for event in sim.event_log:
  if event.get("kind", "") == "encounter_finished" and event.get("result", "") == sim.phase and _current_event(event) and int(event.sequence) == int(actual_snapshot.get("event_sequence", -1)):
   if int(event.sequence) <= terminal_sequence: return _deny("terminal_already_consumed")
   return {"accepted":true, "reason":"", "event":event.duplicate(true)}
 return _deny("terminal_receipt_required")

func queue_terminal(source_sim: Node, actual_snapshot: Dictionary) -> void:
 var checked: Dictionary = _authentic_terminal(source_sim, actual_snapshot)
 if not checked.accepted: return
 # Same source/terminal only. A stale callback cannot replace a pending valid one.
 if not terminal_pending.is_empty(): return
 terminal_pending = actual_snapshot.duplicate(true)
 _terminal_evidence = checked.event.duplicate(true)

func update_after_source_step() -> void:
 if not is_instance_valid(sim) or sim.transaction_active or _transitioning: return
 flush_initial_projection()
 if not terminal_pending.is_empty():
  var actual: Dictionary = terminal_pending.duplicate(true)
  terminal_pending.clear()
  _record(finish(sim, actual))
 if growth_dirty: flush_growth(consumers)
 # No inherited 23-spawn/two-room/one-AI diagnostic update or super.finish call.

func finish(source_sim: Node, actual_snapshot: Dictionary) -> Dictionary:
 if is_instance_valid(sim) and sim.transaction_active: return _deny("defer_terminal_to_outer_boundary")
 var checked: Dictionary = _authentic_terminal(source_sim, actual_snapshot)
 if not checked.accepted: return checked
 var terminal: Dictionary = checked.event
 _terminal_evidence = terminal.duplicate(true)
 if sim.phase == "host_closed":
  terminal_sequence = int(terminal.sequence)
  status = "aborted"
  row_state.abort(self, "host_closed")
  return {"accepted":true, "reason":"host_closed_without_settlement"}
 if sim.phase == "true_dead":
  if not sim.hero.dead: return _fault("death_not_authentic", {"terminal":terminal.duplicate(true)})
  var life: Dictionary = ledger.command("life_state", {"dead":true})
  if not life.ok: return _fault("death_life_state:" + str(life.reason), life)
  var death_id: String = "%s|%s|%d|death" % [run_id, current_room_id, current_generation]
  var penalty: Dictionary = ledger.model.command("ink-death:" + death_id, "death_penalty", {"event_id":death_id})
  if not penalty.accepted: return _fault("death_penalty:" + str(penalty.reason), penalty)
  terminal_sequence = int(terminal.sequence)
  status = "defeated"; row_state.abort(self, "defeated")
  settlement = _terminal_summary("defeat", terminal); growth_dirty = true
  return {"accepted":true, "reason":"defeated", "settlement":settlement.duplicate(true)}
 if sim.phase != "victory": return _fault("unsupported_terminal_state", {"terminal":terminal.duplicate(true)})
 if sim.hero.dead or expected_enemies.is_empty() or not sim.living().is_empty() or sim.enemies.size() != expected_enemies.size(): return _fault("victory_not_authentic", {"terminal":terminal.duplicate(true)})
 if _active_entry.is_empty() or _active_node.payload.node_type != "combat" or row_state.snapshot().status != "entered": return _fault("entered_combat_receipt_required", {"terminal":terminal.duplicate(true)})
 for id in expected_enemies:
  var target: Dictionary = sim.enemy_by_id(id)
  if target.is_empty() or not target.get("dead", false) or not kill_receipts.has(id): return _fault("missing_authentic_enemy_kill", {"terminal":terminal.duplicate(true)})
  var kill: Dictionary = kill_receipts[id]
  if int(kill.generation) != current_generation or not _current_event(kill.event) or kill.reward_id not in ledger.model.state.reward_ids: return _fault("kill_reward_binding_missing", {"terminal":terminal.duplicate(true)})
 for enemy in sim.enemies:
  if str(enemy.actor_id) not in expected_enemies or not enemy.get("dead", false): return _fault("unexpected_terminal_actor", {"terminal":terminal.duplicate(true)})
 if current_room_id in cleared: return _fault("room_already_cleared", {"terminal":terminal.duplicate(true)})
 var is_boss: bool = _active_node.payload.kind == "boss"
 if is_boss and (row_state.snapshot().completed_rows.size() != 11 or not _boss_registration.get("accepted", false) or boss_id.is_empty() or not kill_receipts.has(boss_id)): return _fault("registered_last_boss_required", {"terminal":terminal.duplicate(true)})
 var entered: Dictionary = _active_entry.payload
 var payload: Dictionary = {"entry_id":entered.entry_id, "room_id":current_room_id, "generation":current_generation, "encounter_id":entered.encounter_id, "terminal_receipt_id":_evidence_id("terminal", {"run_id":run_id, "event":terminal, "kills":kill_receipts.duplicate(true)}), "defeated_actor_ids":expected_enemies.duplicate(), "boss_actor_id":boss_id}
 var receipt = CallerReceipt.new(self, CallerReceipt.Kind.COMBAT_COMPLETED, _evidence_id("combat_completion", payload), row_state.selected_identity(), payload)
 var completed: Dictionary = row_state.record_completion(self, receipt)
 if not completed.accepted: return _fault("combat_row_completion:" + str(completed.reason), completed)
 terminal_sequence = int(terminal.sequence)
 cleared.append(current_room_id)
 node_index = row_state.snapshot().completed_rows.size()
 if is_boss:
  return _settle_boss_after_rows(terminal)
 status = "between_rooms"; growth_dirty = true
 return {"accepted":true, "reason":"next_row_available", "state":snapshot()}

func _settle_boss_after_rows(terminal: Dictionary) -> Dictionary:
 var act: Dictionary = ledger.model.state.get("act_progress", {}).get("first_floor", {})
 if status != "combat" or not _owner_intact() or sim.phase != "victory" or sim.hero.dead or not sim.living().is_empty(): return _fault("boss_settlement_live_context_missing", {})
 if not _current_event(terminal) or terminal.get("kind", "") != "encounter_finished" or terminal.get("result", "") != "victory" or int(terminal.get("sequence", -1)) != terminal_sequence or terminal != _terminal_evidence: return _fault("boss_settlement_terminal_missing", {})
 if not row_state.snapshot().ready_for_owner_boss_settlement or not _boss_registration.get("accepted", false) or act.get("run_id", "") != run_id or act.get("boss_actor_id", "") != boss_id or not act.get("boss_defeated", false): return _fault("boss_settlement_preconditions_missing", {})
 var completed: Dictionary = _complete_floor_authority()
 # RowState may already be ready and cannot abort. Preserve that evidence, but
 # never promote Session to completed when the real authority rejects settlement.
 if not completed.get("accepted", false): return _fault("boss_settlement_failed:" + str(completed.get("reason", "unknown")), completed)
 status = "completed"
 settlement = _terminal_summary("victory", terminal)
 settlement["major_floor_event"] = completed.major_floor_event.duplicate(true)
 growth_dirty = true
 return {"accepted":true, "reason":"first_floor_settled", "settlement":settlement.duplicate(true)}

func _complete_floor_authority() -> Dictionary:
 return ledger.model.complete_floor(self, "first_floor", run_id + "/first_floor/complete")

func _authority(action: String, extra: Dictionary = {}) -> Dictionary:
 serial += 1
 var command_id: String = "shop-session-authority:%d" % serial
 var args: Dictionary = ledger.model.commerce_token()
 args.merge(extra, true)
 var result: Dictionary = ledger.shop_authority(self, command_id, action, args)
 var proof: Dictionary = {"command_id":command_id, "action":action, "request":args.duplicate(true), "source_result":result.duplicate(true)}
 authority_receipts.append(proof)
 result["command_id"] = command_id
 result["request"] = args.duplicate(true)
 result["source_result"] = proof.source_result.duplicate(true)
 return result

func _evidence_id(kind: String, source: Dictionary) -> String:
 var id: String = kind + "-" + MixedSchema.binding_id(source)
 evidence_ids[id] = {"kind":kind, "source":source.duplicate(true)}
 return id

func _fault(reason: String, source_result: Dictionary) -> Dictionary:
 if fault.is_empty(): fault = {"reason":reason, "source_result":source_result.duplicate(true), "room_id":active_node_room, "run_id":run_id}
 status = "faulted"; _transitioning = false; _service_present = false
 if row_state != null: row_state.abort(self, "faulted")
 if ledger != null and ledger.model.state.phase == "safe" and ledger.model.state.training:
  var revoked: Dictionary = ledger.set_training_node(false)
  fault["training_revocation"] = revoked.duplicate(true)
 if is_instance_valid(sim):
  sim.paused = true
  if _input_suspender.is_valid(): _input_suspender.call("mixed_floor_fault")
 return _record(_deny(reason))

func explicit_resume() -> Dictionary:
 if status in ["faulted", "completed", "defeated", "aborted", "unbound"]: return _deny("no_live_run")
 return super.explicit_resume()

func set_modal_blocked(blocked: bool) -> Dictionary:
 if status in ["faulted", "completed", "defeated", "aborted", "unbound"]: return _deny("no_live_run")
 return super.set_modal_blocked(blocked)

func close_run() -> Dictionary:
 if status in ["completed", "defeated", "aborted", "unbound"]: return {"accepted":true, "reason":"already_terminal"}
 if sim.transaction_active or _transitioning: return _deny("defer_close_to_outer_boundary")
 var prior_status := status
 if ledger.model.state.phase == "safe" and ledger.model.state.training: ledger.set_training_node(false)
 terminal_pending.clear()
 _service_present = false
 var result: Dictionary = super.close_run()
 if row_state != null: row_state.abort(self, "host_closed")
 if prior_status == "faulted": status = "faulted"
 return result

func snapshot() -> Dictionary:
 return {"run_id":run_id, "status":status, "floor_id":route.get("floor_id", ""), "route_version":route.get("version", ""), "content_status":route.get("content_status", ""), "node_index":node_index, "node_count":12, "room_id":current_room_id, "active_node_room":active_node_room, "generation":current_generation, "cleared":cleared.duplicate(), "kill_receipts":kill_receipts.duplicate(true), "settlement":settlement.duplicate(true), "row_state":row_state.snapshot() if row_state != null else {}, "fault":fault.duplicate(true), "boss_registration":_boss_registration.duplicate(true), "service_present":_service_present, "service_ready":_service_ready, "production_ready":false, "live_lv4_pool":"HOLD", "full_normal_floor_proven":false}
