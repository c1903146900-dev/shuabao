extends "res://tests/ink_shop_ui_host_20261004/shop_session.gd"
## Ordinary zero-gold startup and an explicit one-original-AI diagnostic.
## No auto-learning, skipped Hex, funding, state restore, or reward fabrication.
const InitialBridge = preload("res://tests/ink_initial_hex_runtime_20261004/ink_initial_bridge.gd")
const InitialBinding = preload("res://tests/ink_initial_hex_runtime_20261004/live_binding.gd")
const InitialConsumer = preload("res://tests/ink_initial_hex_runtime_20261004/ink_initial_stat_consumer.gd")
var initial_flow_diagnostic: bool = false
var initial_modal_open: bool = false
var initial_focus_pause: bool = false
var _initial_prior_pause: bool = false
var runtime_projection_pending: bool = false
var runtime_projection_receipts: Array = []

func initialize_session(source_sim: Node, new_run_id: String, diagnostic: bool = false) -> Dictionary:
 if status != "unbound" or not is_instance_valid(source_sim) or new_run_id.is_empty(): return _deny("fresh_session_required")
 var admission: Dictionary = InitialBinding.read_capabilities(source_sim, true)
 if not admission.accepted: return admission
 var candidate = InitialBridge.new()
 var initialized: Dictionary = candidate.initialize_runtime_fixture(source_sim, admission.capabilities, SHOP, FIXTURE, NUMERIC, self, new_run_id, true)
 if not initialized.accepted: return initialized
 var fresh: Dictionary = candidate.model.snapshot()
 if fresh.level != 1 or fresh.gold != 0 or fresh.xp != 0 or fresh.points != 1 or not fresh.inventory.is_empty() or not fresh.selected_hex.is_empty(): return _deny("fresh_zero_gold_authority_required")
 for skill in fresh.skills.values():
  if skill.rank != 0 or not str(skill.candidate).is_empty(): return _deny("fresh_unlearned_authority_required")
 var bound: Dictionary = candidate.model.bind_floor(self, source_sim, new_run_id)
 if not bound.accepted: return bound
 sim = source_sim; ledger = candidate; run_id = new_run_id
 initial_flow_diagnostic = diagnostic
 diagnostic_run = false # Never use the ancestor's Hex-skipping 23-kill branch.
 consumers = InitialConsumer.new()
 sim.set_progression(ledger); sim.auto_finish = false
 route = {"floor_id":"initial_hex_one_ai_diagnostic" if diagnostic else "ordinary_first_floor_pending", "version":"initial-hex-ui-01", "content_status":"explicit_one_ai_after_actual_initial_choice" if diagnostic else "pending_authoring", "nodes":[{"id":"one_original_ai", "kind":"ordinary", "training_after":false}] if diagnostic else []}
 status = "preparation"; growth_dirty = true
 var entered: Dictionary = _authority("enter_room", {"next_room":run_id + "/initial-safe"})
 if not entered.accepted: return entered
 session_events.append({"type":"initialized", "initial_flow_diagnostic":diagnostic, "level":fresh.level, "gold":fresh.gold, "xp":fresh.xp, "points":fresh.points, "initial_hex_skipped":false, "automatic_learning":false})
 return {"accepted":true, "reason":"", "initial_flow_diagnostic":diagnostic}

func progression_command_completed(request: Dictionary, result: Dictionary) -> void:
 session_events.append({"type":"progression_command", "request":request.duplicate(true), "result":result.duplicate(true)})
 if result.get("accepted", false):
  runtime_projection_pending = true
  growth_dirty = true
 flush_initial_projection()

func flush_initial_projection() -> Dictionary:
 if not runtime_projection_pending: return {"accepted":true, "reason":"unchanged"}
 if sim.transaction_active: return _deny("defer_growth_to_outer_boundary")
 # Controller calls Model.command directly. Explicit bridge projection is required.
 sim._sync_loadout_from_ledger()
 var projected: Dictionary = ledger.refresh_runtime()
 runtime_projection_receipts.append({"revision":ledger.model.state.revision, "accepted":projected.accepted, "reason":projected.reason, "outside_transaction":not sim.transaction_active})
 if projected.accepted: runtime_projection_pending = false
 return projected

func update_after_source_step() -> void:
 if not is_instance_valid(sim) or sim.transaction_active: return
 flush_initial_projection()
 super.update_after_source_step()
 if initial_flow_diagnostic and status == "between_rooms" and node_index >= 1: status = "diagnostic_complete"

func set_modal_blocked(blocked: bool) -> Dictionary:
 if not is_instance_valid(sim) or sim.transaction_active: return _deny("defer_modal_to_outer_boundary")
 if blocked == initial_modal_open: return {"accepted":true, "reason":"unchanged"}
 if not _input_suspender.is_valid(): return _deny("input_suspender_missing")
 if blocked: _initial_prior_pause = sim.paused
 _input_suspender.call("initial_hex_open" if blocked else "initial_hex_close_release_required")
 sim.hero.move_intent = Vector3.ZERO
 initial_modal_open = blocked
 sim.paused = true if blocked else (_initial_prior_pause or initial_focus_pause)
 return {"accepted":true, "reason":"", "paused":sim.paused}

func focus_lost() -> void:
 initial_focus_pause = true
 if initial_modal_open: _initial_prior_pause = true
 super.focus_lost()

func explicit_resume() -> Dictionary:
 if initial_modal_open or panel_open or sim.transaction_active: return _deny("close_modal_before_resume")
 if _input_suspender.is_valid(): _input_suspender.call("explicit_resume_release_required")
 initial_focus_pause = false; sim.paused = false
 return {"accepted":true, "reason":""}

func open_panel() -> Dictionary:
 if initial_modal_open or not ledger.model.snapshot().pending_milestones.is_empty(): return _record(_deny("mandatory_hex_pending"))
 return super.open_panel()

func learn_q1() -> Dictionary:
 if not ledger.model.snapshot().pending_milestones.is_empty(): return _record(_deny("mandatory_hex_pending"))
 return super.learn_q1()

func next_room_preflight() -> Dictionary:
 var reason: String = safe_shop_reason()
 if not reason.is_empty(): return _deny(reason)
 var state: Dictionary = ledger.model.snapshot()
 if initial_modal_open or not state.pending_milestones.is_empty(): return _deny("mandatory_hex_pending")
 if not initial_flow_diagnostic: return _deny("ordinary_12_row_content_unconfigured")
 if node_index >= 1 or status == "diagnostic_complete": return _deny("diagnostic_segment_complete")
 if panel_open: return _deny("close_shop_before_room_transition")
 if sim.paused: return _deny("resume_before_room_transition")
 if not terminal_pending.is_empty(): return _deny("terminal_settlement_pending")
 if not state.body_pending.is_empty(): return _deny("body_choice_pending")
 if not _input_suspender.is_valid(): return _deny("input_suspender_missing")
 var next_room: String = run_id + "/one-original-ai"
 if next_room in state.visited_levels or next_room == str(state.shop_visit.room_id): return _deny("fresh_room_required")
 return {"accepted":true, "reason":"", "next_room":next_room, "diagnostic_only":true}

func start_next_room() -> Dictionary:
 var ready: Dictionary = next_room_preflight()
 if not ready.accepted: return _record(ready)
 _transitioning = true
 var committed: Dictionary = _authority("enter_room", {"next_room":ready.next_room})
 if not committed.accepted: _transitioning = false; return _record(committed)
 var entered: Dictionary = ledger.command("enter_level", {"combat_level_id":ready.next_room})
 if not entered.ok:
  status = "faulted"; _transitioning = false
  return _record(_deny("unexpected_post_commit_enter_level_failure:" + str(entered.reason)))
 _input_suspender.call("initial_flow_room_release_required")
 current_room_id = ready.next_room; current_generation = sim.encounter_generation + 1
 required_in_room = 1; spawned_in_room = 1
 kill_receipts.clear(); expected_enemies.clear(); boss_id = ""
 sim.auto_finish = true; status = "combat"
 var started: Dictionary = sim.begin_encounter(current_room_id, [{"kind":"minion", "position":Vector3(0,0,-5)}])
 if not started.accepted:
  status = "faulted"; _transitioning = false
  return _record(_deny("unexpected_post_commit_sim_start_failure:" + str(started.reason)))
 current_generation = sim.encounter_generation
 for enemy in sim.enemies: expected_enemies.append(str(enemy.actor_id))
 growth_dirty = true; _transitioning = false
 session_events.append({"type":"room_committed", "room":current_room_id, "generation":current_generation, "required_actual_minions":1, "gold":ledger.model.state.gold, "initial_hex_skipped":false})
 return _record({"accepted":true, "reason":"actual_one_ai_after_initial_hex_started"})
