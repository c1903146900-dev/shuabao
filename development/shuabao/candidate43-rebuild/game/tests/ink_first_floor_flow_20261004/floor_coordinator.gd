extends RefCounted
## Ordinary source-only coordinator. Never drives attacks, awards points or forces victory.
## Host owns signals and calls observe_event synchronously, finish after the actual terminal event.
const Route = preload("res://tests/ink_first_floor_flow_20261004/floor_route.gd")
var sim: Node
var ledger: RefCounted
var route: Dictionary = {}
var run_id := ""
var status := "unbound"
var node_index := 0
var current_room_id := ""
var current_generation := -1
var expected_enemies: Array = []
var kill_receipts: Dictionary = {}
var cleared: Array = []
var boss_id := ""
var settlement: Dictionary = {}
var growth_dirty := false
var terminal_sequence := -1
var retired_run_ids: Array = []
var _allow_fixture := false
var _input_suspender: Callable

func begin_new_run(source_sim: Node, bridge: RefCounted, definition: Dictionary, new_run_id: String, allow_fixture: bool = false) -> Dictionary:
 if status not in ["unbound", "completed", "defeated", "aborted"]: return _deny("run_still_active")
 if new_run_id.is_empty() or new_run_id == run_id or new_run_id in retired_run_ids: return _deny("fresh_run_id_required")
 if not is_instance_valid(source_sim) or bridge == null or bridge.model == null: return _deny("ordinary_source_missing")
 if source_sim == sim or bridge == ledger: return _deny("restart_requires_fresh_sim_and_ledger")
 var validation: Dictionary = Route.validate(definition, allow_fixture)
 if not validation.accepted: return validation
 var s: Dictionary = bridge.model.snapshot()
 if s.hero_id != "yanguizhou" or source_sim.hero.actor_id != "yanguizhou": return _deny("ink_hero_mismatch")
 if int(s.revision) != 0 or int(s.level) != 1 or int(s.xp) != 0 or int(s.gold) != 0 or int(s.points) != 1:
  return _deny("fresh_lv1_authority_required")
 if s.get("test_mode", false) or s.phase != "safe" or s.training or not s.inventory.is_empty() or not s.selected_hex.is_empty():
  return _deny("fresh_lv1_authority_required")
 for skill in s.skills.values():
  if skill.rank != 0 or not str(skill.candidate).is_empty(): return _deny("fresh_lv1_authority_required")
 if source_sim.phase != "preparation" or source_sim.wave != 0 or source_sim.encounter_generation != 0 or source_sim.hero.dead:
  return _deny("fresh_sim_required")
 var binding: Dictionary = bridge.model.bind_floor(self, source_sim, new_run_id)
 if not binding.accepted: return binding
 if not run_id.is_empty(): retired_run_ids.append(run_id)
 sim = source_sim
 ledger = bridge
 route = definition.duplicate(true)
 run_id = new_run_id
 _allow_fixture = allow_fixture
 _input_suspender = Callable()
 source_sim.set_progression(ledger)
 # This is configuration, not a level/economy/skill state mutation.
 ledger.model.config.campaign_acts = {str(route.floor_id):{"name":route.get("title", route.floor_id), "completion_rule":route.completion_rule, "content_status":route.content_status, "room_count":route.nodes.size(), "repeat_reward":false}}
 node_index = 0
 current_room_id = ""
 current_generation = -1
 expected_enemies.clear()
 kill_receipts.clear()
 cleared.clear()
 boss_id = ""
 settlement.clear()
 terminal_sequence = -1
 growth_dirty = true
 status = "preparation"
 return {"accepted":true, "reason":"", "state":snapshot()}

func start_current_node() -> Dictionary:
 if status not in ["preparation", "between_rooms"]: return _deny("floor_not_ready")
 if sim.phase not in ["preparation", "victory"] or sim.hero.dead or sim.transaction_active or sim.paused: return _deny("combat_not_ready")
 var state: Dictionary = ledger.model.snapshot()
 if state.phase != "safe": return _deny("unsafe_phase")
 if not state.pending_milestones.is_empty(): return _deny("mandatory_hex_pending")
 if not state.body_pending.is_empty(): return _deny("body_choice_pending")
 var node: Dictionary = route.nodes[node_index]
 var next_room: String = run_id + "/" + str(route.floor_id) + "/" + str(node.id)
 var entered: Dictionary = ledger.command("enter_level", {"combat_level_id":next_room})
 if not entered.ok: return _deny(entered.reason)
 var started: Dictionary = sim.begin_encounter(next_room, Route.roster(node))
 if not started.accepted: return started
 current_room_id = sim.combat_level_id
 current_generation = sim.encounter_generation
 expected_enemies.clear()
 kill_receipts.clear()
 boss_id = ""
 for enemy in sim.enemies:
  expected_enemies.append(str(enemy.actor_id))
  if enemy.get("rank_category", "") == "boss": boss_id = str(enemy.actor_id)
 if node.kind == "boss":
  var registration: Dictionary = ledger.model.register_act_context(sim, str(route.floor_id), boss_id, run_id)
  if not registration.accepted:
   status = "faulted"
   return registration
 status = "combat"
 growth_dirty = true
 return {"accepted":true, "reason":"", "state":snapshot()}

func observe_event(source_sim: Node, event: Dictionary) -> Dictionary:
 if not is_same(source_sim, sim): return _deny("wrong_sim_instance")
 if status != "combat": return _deny("floor_not_in_combat")
 if event.get("kind", "") not in ["damage", "kill"]:
  return {"accepted":true, "reason":"non_progression_event", "changed":false}
 if not _current_event(event): return _deny("wrong_encounter_event")
 var result: Dictionary = ledger.model.observe_live_event(self, sim, event)
 if result.accepted:
  growth_dirty = growth_dirty or bool(result.get("changed", false))
  if event.kind == "kill": kill_receipts[str(event.target)] = {"sequence":event.sequence, "reward_id":result.get("reward_id", ""), "generation":current_generation}
 return result

func finish(source_sim: Node, actual_snapshot: Dictionary) -> Dictionary:
 if not is_same(source_sim, sim): return _deny("wrong_sim_instance")
 if status != "combat": return _deny("floor_not_in_combat")
 if actual_snapshot.get("phase", "") != sim.phase or not _current_event(actual_snapshot): return _deny("stale_terminal_snapshot")
 var terminal: Dictionary = {}
 for event in sim.event_log:
  if event.get("kind", "") == "encounter_finished" and event.get("result", "") == sim.phase and _current_event(event): terminal = event
 if terminal.is_empty() or int(terminal.sequence) <= terminal_sequence: return _deny("terminal_receipt_required")
 terminal_sequence = int(terminal.sequence)
 if sim.phase == "host_closed":
  status = "aborted"
  return {"accepted":true, "reason":"host_closed_without_settlement", "state":snapshot()}
 if sim.phase == "true_dead":
  if not sim.hero.dead: return _deny("death_not_authentic")
  ledger.command("life_state", {"dead":true})
  var id: String = "%s|%s|%d|death" % [run_id, current_room_id, current_generation]
  var penalty: Dictionary = ledger.model.command("ink-death:" + id, "death_penalty", {"event_id":id})
  if not penalty.accepted: return penalty
  status = "defeated"
  settlement = _terminal_summary("defeat", terminal)
  growth_dirty = true
  return {"accepted":true, "reason":"defeated", "settlement":settlement.duplicate(true)}
 if sim.phase != "victory": return _deny("unsupported_terminal_state")
 if sim.hero.dead or expected_enemies.is_empty() or not sim.living().is_empty(): return _deny("victory_not_authentic")
 # An empty/forced-clear room, visual hit or missing real kill cannot settle the route.
 for id in expected_enemies:
  var target: Dictionary = sim.enemy_by_id(id)
  if target.is_empty() or not target.get("dead", false) or not kill_receipts.has(id): return _deny("missing_authentic_enemy_kill")
 for enemy in sim.enemies:
  if not enemy.get("dead", false) or not kill_receipts.has(str(enemy.actor_id)): return _deny("missing_authentic_enemy_kill")
 if current_room_id in cleared: return _deny("room_already_cleared")
 var node: Dictionary = route.nodes[node_index]
 if node.kind == "boss":
  if node_index != route.nodes.size() - 1 or cleared.size() != route.nodes.size() - 1 or not kill_receipts.has(boss_id): return _deny("floor_route_incomplete")
  var completed: Dictionary = ledger.model.complete_floor(self, str(route.floor_id), run_id + "/" + str(route.floor_id) + "/complete")
  if not completed.accepted: return completed
  cleared.append(current_room_id)
  status = "completed"
  settlement = _terminal_summary("victory", terminal)
  settlement["major_floor_event"] = completed.major_floor_event.duplicate(true)
  growth_dirty = true
  return {"accepted":true, "reason":"first_floor_settled", "settlement":settlement.duplicate(true)}
 cleared.append(current_room_id)
 node_index += 1
 status = "between_rooms"
 var training: Dictionary = ledger.set_training_node(bool(node.get("training_after", false)))
 if not training.ok: return _deny(training.reason)
 growth_dirty = true
 return {"accepted":true, "reason":"next_node_available", "state":snapshot()}

func bind_input_suspender(suspender: Callable) -> Dictionary:
 if not suspender.is_valid(): return _deny("input_suspender_missing")
 _input_suspender = suspender
 return {"accepted":true, "reason":""}

func set_modal_blocked(blocked: bool) -> Dictionary:
 if not is_instance_valid(sim) or status not in ["preparation", "combat", "between_rooms"]: return _deny("no_live_run")
 if sim.transaction_active: return _deny("defer_modal_to_outer_boundary")
 if blocked:
  if not _input_suspender.is_valid(): return _deny("input_suspender_missing")
  _input_suspender.call("ui_modal")
  sim.hero.move_intent = Vector3.ZERO
 sim.paused = blocked
 return {"accepted":true, "reason":""}

func close_run() -> Dictionary:
 if status in ["completed", "defeated", "aborted", "unbound"]: return {"accepted":true, "reason":"already_terminal"}
 if sim.transaction_active: return _deny("defer_close_to_outer_boundary")
 status = "aborted" # Set first, so synchronous end callback cannot award anything.
 if _input_suspender.is_valid(): _input_suspender.call("host_closed")
 if sim.has_method("cancel_ink_preview"): sim.cancel_ink_preview("host_closed")
 if sim.phase == "combat": sim.end_encounter("host_closed")
 return {"accepted":true, "reason":"host_closed_without_settlement", "state":snapshot()}

func flush_growth(consumers: RefCounted) -> Dictionary:
 # Call only after simulation.step returns, never from an in-flight damage callback.
 if not growth_dirty: return {"accepted":true, "reason":"unchanged", "changed":false}
 if not is_instance_valid(sim) or ledger == null or consumers == null: return _deny("growth_consumers_missing")
 if sim.transaction_active: return _deny("defer_growth_to_outer_boundary")
 sim._sync_loadout_from_ledger()
 consumers.sync_stats(sim, ledger.model)
 sim.hero.gold = ledger.model.state.gold
 sim.hero.xp_progress = ledger.model.state.xp
 growth_dirty = false
 return {"accepted":true, "reason":"", "changed":true}

func mark_growth_dirty() -> void:
 growth_dirty = true

func snapshot() -> Dictionary:
 return {"run_id":run_id, "status":status, "floor_id":route.get("floor_id", ""), "route_version":route.get("version", ""), "content_status":route.get("content_status", ""), "node_index":node_index, "node_count":route.get("nodes", []).size(), "room_id":current_room_id, "generation":current_generation, "cleared":cleared.duplicate(), "kill_receipts":kill_receipts.duplicate(true), "settlement":settlement.duplicate(true), "production_ready":false}

func _current_event(event: Dictionary) -> bool:
 return event.get("combat_level_id", "") == current_room_id and event.get("room_id", "") == current_room_id and int(event.get("generation", -1)) == current_generation and int(event.get("wave", -1)) == int(sim.wave)

func _terminal_summary(outcome: String, terminal: Dictionary) -> Dictionary:
 var state: Dictionary = ledger.model.snapshot()
 return {"outcome":outcome, "run_id":run_id, "floor_id":route.floor_id, "route_version":route.version, "route_content_status":route.content_status, "shop_table":ledger.definitions.shop_table.duplicate(true), "terminal_sequence":terminal.sequence, "boss_actor_id":boss_id, "level":state.level, "remaining_xp":state.xp, "gold":state.gold, "points":state.points, "inventory":state.inventory.duplicate(true), "cleared_rooms":cleared.duplicate(), "evidence_scope":"coordinator_receipts_not_gameplay_acceptance"}

func _deny(reason: String) -> Dictionary:
 return {"accepted":false, "reason":reason, "changed":false}
