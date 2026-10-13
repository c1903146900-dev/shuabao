extends SceneTree
## FINITE MAIN-OWNED GATE. Source author did not launch Godot or any app.
## Normal case is fresh zero gold/XP and the actual original 1SP.
## Separate service diagnostic uses a clearly isolated startup-only 1500 TEST seed.
## No forced kills, injected damage/rewards, restoration, teleport or phase writes.
## A bounded real first-combat outcome is reported separately from contract checks.
const Sim = preload("res://tests/ink_intermediate_stats_20261004/ink_intermediate_sim.gd")
const Session = preload("res://tests/ink_first_floor_session_20261004/floor_session.gd")
const FundedFixture = preload("res://tests/ink_first_floor_session_20261004/funded_fixture_session.gd")
const FaultFixture = preload("res://tests/ink_first_floor_session_20261004/fault_session.gd")
const Schema = preload("res://tests/ink_first_floor_candidate_20261004/route_schema.gd")
const Router = preload("res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_input_adapter.gd")
const DEFINITION_PATH := "res://tests/ink_first_floor_candidate_20261004/content/first_floor_v0.json"
const RESULT_PATH := "res://tests/ink_first_floor_session_20261004/contract_result.json"
const COMBAT_STEP_LIMIT := 7200
const STEP_SECONDS := 1.0 / 60.0
var checks := 0
var failures: Array = []
var observations: Array = []
var event_failures: Array = []
var fresh_serial := 0
var command_serial := 0
var first_combat_result: Dictionary = {"status":"NOT_RUN", "completed":false}

func _initialize() -> void:
 call_deferred("run")

func check(value: bool, label: String) -> void:
 checks += 1
 if not value:
  failures.append(label)
  push_error(label)

func run() -> void:
 var loaded: Dictionary = Schema.load_definition(DEFINITION_PATH, true)
 check(loaded.accepted, "unchanged shipped developer proposal loads with explicit opt-in")
 if loaded.accepted:
  var definition: Dictionary = loaded.definition
  admission_case(definition)
  service_case(definition)
  normal_first_combat_case(definition)
  fault_postcondition_case(definition)
 check(event_failures.is_empty(), "all actual live damage/kill callbacks accepted synchronously")
 var report := {"suite":"first_floor_session_contract_and_bounded_source_combat", "passed":failures.is_empty(), "checks":checks, "failures":failures, "event_failures":event_failures, "observations":observations, "first_combat":first_combat_result, "normal_initial_gold":0, "normal_initial_xp":0, "normal_initial_SP":1, "service_funding":"ISOLATED_STARTUP_ONLY_1500_TEST", "service_topology":"SERVICE_DIAGNOSTIC_TOPOLOGY_NOT_NORMAL_PLAY", "first_floor_complete":false, "actual_boss_settlement":"NOT_RUN", "normal_full_floor":"HOLD", "live_Lv4_hex_pool":"HOLD", "native_UI_pixels_input_audio":"NOT_RUN", "performance_proved":false, "release":false}
 print("INK_FIRST_FLOOR_SESSION_REPORT ", JSON.stringify(report))
 var out := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
 if out != null:
  out.store_string(JSON.stringify(report, "  "))
  out.close()
 quit(0 if failures.is_empty() else 1)

func fresh(definition: Dictionary, funded: bool = false, fault_test: bool = false) -> Dictionary:
 fresh_serial += 1
 var sim = Sim.new()
 root.add_child(sim)
 var session: RefCounted = FundedFixture.new() if funded else (FaultFixture.new() if fault_test else Session.new())
 var run_id := "floor-session-gate-%d" % fresh_serial
 if funded:
  check(not session.initialize_funded_floor(sim, definition, run_id).accepted and session.status == "unbound", "test startup funding requires explicit fixture admission")
 var admitted: Dictionary = session.initialize_funded_floor(sim, definition, run_id, true) if funded else session.initialize_floor(sim, definition, run_id, true)
 check(admitted.get("accepted", false), "fresh exact intermediate Sim/Bridge admitted: " + str(admitted.get("reason", "")))
 if not admitted.get("accepted", false):
  observations.append({"case":"initialization_failed", "result":admitted})
  sim.free()
  return {}
 var router = Router.new()
 router.bind(sim)
 check(session.bind_input_suspender(router.suspend_input).accepted, "retained source input suspender bound")
 var f := {"sim":sim, "s":session, "router":router, "events":[], "terminals":[], "kills":[], "funded":funded}
 sim.combat_event.connect(func(event: Dictionary):
  f.events.append(event.duplicate(true))
  var result: Dictionary = session.observe_event(sim, event)
  if event.get("kind", "") in ["damage", "kill"] and not result.accepted: event_failures.append({"event":event.duplicate(true), "receipt":result.duplicate(true)})
  if event.get("kind", "") == "kill": f.kills.append(event.duplicate(true)))
 sim.encounter_finished.connect(func(actual: Dictionary):
  f.terminals.append(actual.duplicate(true))
  session.queue_terminal(sim, actual))
 return f

func close(f: Dictionary) -> void:
 if f.is_empty(): return
 f.s.close_run()
 f.sim.free()

func model_command(f: Dictionary, action: String, args: Dictionary) -> Dictionary:
 command_serial += 1
 var result: Dictionary = f.s.ledger.model.command("floor-gate-model-%d" % command_serial, action, args)
 f.s.progression_command_completed({"action":action, "args":args.duplicate(true)}, result)
 f.s.update_after_source_step()
 return result

func choose_and_learn(f: Dictionary) -> bool:
 var before: Dictionary = f.s.ledger.model.snapshot()
 check(not f.s.learn_q1().accepted, "unresolved actual initial milestone blocks Q1")
 var opened: Dictionary = model_command(f, "hex_open", {"milestone":1})
 check(opened.accepted, "actual model creates initial four-choice offer")
 if not opened.accepted: return false
 var offer: Dictionary = f.s.ledger.model.snapshot().offers["1"]
 check(offer.slots.size() == 4, "actual initial offer has exactly four choices")
 var chosen: String = str(offer.slots[3])
 check(f.s.ledger.definitions.hexes[chosen].hero == "yanguizhou", "actual right slot is the source personal Hex")
 var selected: Dictionary = model_command(f, "hex_select", {"milestone":1, "slot":3})
 check(selected.accepted, "actual initial Hex selection accepted by existing Model")
 if not selected.accepted: return false
 var state: Dictionary = f.s.ledger.model.snapshot()
 check(state.selected_hex == [chosen] and state.pending_milestones.is_empty(), "actual choice clears only the original pending milestone")
 check(state.gold == before.gold and state.xp == before.xp and state.points == 1, "initial Hex grants no gold, XP or extra SP")
 check(state.hex_status[chosen] == "dormant" and f.sim.hero.ranks.q == 0, "personal effect remains dormant before actual skill investment")
 var learned: Dictionary = f.s.learn_q1()
 f.s.update_after_source_step()
 check(learned.accepted, "generic safe Q1 learning remains available outside a shop")
 state = f.s.ledger.model.snapshot()
 check(state.points == 0 and state.skills.Q.rank == 1 and f.sim.hero.ranks.q == 1, "Q1 consumes exactly the original 1SP and projects through real Bridge")
 check(state.selected_hex == [chosen] and state.hex_status[chosen] == "active" and chosen in f.sim.hero.hexes, "actual learned Q1 activates the selected source personal Hex")
 var unchanged: Dictionary = f.s.ledger.model.state.duplicate(true)
 check(not f.s.learn_q1().accepted and f.s.ledger.model.state == unchanged, "repeat Q1 investment cannot manufacture SP")
 return learned.accepted

func admission_case(definition: Dictionary) -> void:
 check(Schema.validate(definition, true).get("possible_node_count", 0) == 14 and count_paths(definition, 0, "") == 4, "unchanged shipped proposal retains exactly 14 nodes and four paths")
 var sim = Sim.new()
 root.add_child(sim)
 var session = Session.new()
 check(not session.initialize_session(sim, "legacy-entry", false).accepted and session.status == "unbound", "legacy no-route initializer cannot silently enter a diagnostic or invent content")
 check(not session.initialize_floor(sim, definition, "no-proposal-opt-in").accepted and session.status == "unbound", "developer proposal admission requires explicit opt-in")
 check(sim.encounter_generation == 0 and sim.enemies.is_empty(), "rejected admission cannot start a source encounter")
 sim.free()
 var f: Dictionary = fresh(definition)
 if f.is_empty(): return
 var state: Dictionary = f.s.ledger.model.snapshot()
 check(state.level == 1 and state.gold == 0 and state.xp == 0 and state.points == 1, "normal candidate starts Lv1 / zero gold / zero XP / original 1SP")
 check(state.inventory.is_empty() and state.selected_hex.is_empty() and state.reward_ids.is_empty(), "normal candidate grants no equipment, Hex or reward receipt")
 for skill in state.skills.values(): check(skill.rank == 0 and str(skill.candidate).is_empty(), "every normal fresh skill is actually unlearned")
 check(not f.s.has_method("initialize_funded_floor") and not f.s.has_method("initialize_funded_session"), "runtime candidate exposes no test funding entry point")
 check(f.s.available_choices().size() == 1 and f.s.available_choices()[0].node_id == "r01", "only current row’s reachable choice is available")
 check(not f.s.select_node(12, "r12").accepted, "cannot select the terminal Boss ahead of prior rows")
 check(f.s.select_node(1, "r01").accepted, "explicit first-row selection accepted")
 var selected: Dictionary = f.s.row_state.snapshot()
 check(selected.status == "selected" and selected.completed_rows.is_empty() and selected.entry_receipt.is_empty(), "selection alone is neither entry nor completion")
 var authority_before: Dictionary = f.s.ledger.model.state.duplicate(true)
 check(not f.s.start_next_room().accepted, "mandatory initial milestone cannot be waived by selecting a combat row")
 check(f.s.ledger.model.state == authority_before and f.sim.encounter_generation == 0 and f.s.row_state.snapshot() == selected, "rejected initial preflight preserves route, ledger and source")
 check(not f.s.open_panel().accepted and not f.s.reset_training().accepted, "preparation cannot impersonate an entered shop or training area")
 observations.append({"case":"fresh_normal_admission", "level":state.level, "gold":state.gold, "xp":state.xp, "points":state.points, "candidate_nodes":14, "candidate_paths":4})
 close(f)

func count_paths(definition: Dictionary, row_index: int, node_id: String) -> int:
 if row_index == 0 and node_id.is_empty():
  var total := 0
  for node in definition.rows[0].nodes: total += count_paths(definition, 0, node.id)
  return total
 if row_index == 11: return 1
 for node in definition.rows[row_index].nodes:
  if node.id == node_id:
   var total := 0
   for target in node.next: total += count_paths(definition, row_index + 1, target)
   return total
 return 0

func service_definition(definition: Dictionary) -> Dictionary:
 var local: Dictionary = definition.duplicate(true)
 local.version = "SERVICE_DIAGNOSTIC_TOPOLOGY_NOT_NORMAL_PLAY"
 local.title = "SERVICE_DIAGNOSTIC_TOPOLOGY_NOT_NORMAL_PLAY"
 # Change only test-local first three payloads. Graph and final Boss stay explicit.
 # No earlier rows are marked completed, no combat result or source state is forged.
 for id in ["r01", "r02a", "r02b", "r03"]:
  var kind := "training" if id in ["r02a", "r02b"] else "shop"
  local.payloads[id] = {"node_type":"service", "kind":kind, "service":{"type":kind, "area_id":"diagnostic-" + id, "completion_rule":"explicit_owner_exit", "optional_actions":true}}
 return local

func submit(f: Dictionary, action: String, extra: Dictionary = {}, exact_token: Dictionary = {}) -> Dictionary:
 command_serial += 1
 var args: Dictionary = f.s.ledger.model.commerce_token() if exact_token.is_empty() else exact_token.duplicate(true)
 args.merge(extra, true)
 var result: Dictionary = f.s.submit("floor-gate-commerce-%d" % command_serial, action, args)
 f.s.update_after_source_step()
 return result

func service_case(original: Dictionary) -> void:
 var definition: Dictionary = service_definition(original)
 check(Schema.validate(definition, true).accepted, "isolated service-first diagnostic remains an explicit schema-valid developer proposal")
 var f: Dictionary = fresh(definition, true)
 if f.is_empty(): return
 var initial: Dictionary = f.s.ledger.model.snapshot()
 check(initial.gold == 1500 and initial.level == 1 and initial.xp == 0 and initial.points == 1, "only the labeled isolated startup fixture has 1500 TEST gold")
 var before: Dictionary = f.s.ledger.model.state.duplicate(true)
 check(not f.s.initialize_funded_floor(f.sim, definition, f.s.run_id, true).accepted and f.s.ledger.model.state == before, "startup fixture cannot top up a live Session")
 if not choose_and_learn(f): close(f); return
 check(not f.s.open_panel().accepted, "even funded preparation is not an entered shop")
 check(f.s.select_node(1, "r01").accepted and f.s.enter_selected_node().accepted, "actual first service row entered without fake prior completion")
 check(f.sim.encounter_generation == 0 and f.sim.enemies.is_empty() and f.s.ledger.model.state.visited_levels.is_empty(), "shop entry creates no combat generation, roster or visited battle")
 check(not f.s.reset_training().accepted and not f.s.ledger.model.state.training, "entered shop cannot grant training reset permission")
 check(f.s.open_panel().accepted, "panel can open only after actual shop entry")
 var quote: Dictionary = f.s.ledger.model.commerce_quote("base:B01")
 check(quote.accepted and quote.charge == 450, "real original-price B01 quote is accepted")
 var bought: Dictionary = submit(f, "buy", {"item":"base:B01"}, quote.token)
 check(bought.accepted and f.s.ledger.model.state.gold == 1050 and f.s.ledger.model.state.inventory.size() == 1, "real buy deducts original 450 and allocates one actual UID")
 var held: Dictionary = f.s.ledger.model.state.inventory[0].duplicate(true) if not f.s.ledger.model.state.inventory.is_empty() else {}
 var journal: Array = f.s.ledger.model.state.shop_visit.undo.duplicate(true)
 check(not held.is_empty() and held.has("uid") and not journal.is_empty(), "room-boundary proof begins with a successful nonempty reversible journal")
 before = f.s.ledger.model.state.duplicate(true)
 check(not f.s.complete_service().accepted and not f.s.next_room_preflight().accepted, "open shop cannot mark row ready or transition")
 check(f.s.ledger.model.state == before, "rejected open-panel preflight leaves exact gold, UID and inverse journal")
 check(f.s.close_panel().accepted and f.s.ledger.model.state.shop_visit.undo == journal, "panel close retains exact nonempty undo journal")
 check(f.s.open_panel().accepted and f.s.ledger.model.state.shop_visit.undo == journal, "reopening same entered shop retains that journal")
 check(submit(f, "undo").accepted and f.s.ledger.model.state.gold == 1500 and f.s.ledger.model.state.inventory.is_empty(), "same-visit actual undo refunds only the actual 450 debit")
 quote = f.s.ledger.model.commerce_quote("base:B01")
 check(submit(f, "buy", {"item":"base:B01"}, quote.token).accepted, "second actual purchase establishes the journal that will be committed")
 held = f.s.ledger.model.state.inventory[0].duplicate(true)
 journal = f.s.ledger.model.state.shop_visit.undo.duplicate(true)
 check(not journal.is_empty(), "successful second buy has a nonempty retained journal")
 check(f.s.close_panel().accepted, "shop panel closes before explicit row-ready action")
 var economy: Dictionary = economic_identity(f)
 check(f.s.complete_service().accepted, "explicit shop readiness records its service row without physical departure")
 check(economic_identity(f) == economy and f.s.ledger.model.state.shop_visit.undo == journal, "row readiness gives no reward and preserves same-area economic state and journal")
 before = f.s.ledger.model.state.duplicate(true)
 var completed_shop: Dictionary = f.s.row_state.snapshot()
 check(not f.s.complete_service().accepted and f.s.ledger.model.state == before and f.s.row_state.snapshot() == completed_shop, "duplicate shop readiness cannot record a second completion or change economy")
 check(f.s.open_panel().accepted and f.s.ledger.model.state.shop_visit.undo == journal, "completed shop row can reopen the same physical visit with the exact retained journal")
 check(not f.s.reset_training().accepted, "remaining in completed shop never grants training permission")
 check(submit(f, "undo").accepted and f.s.ledger.model.state.gold == 1500 and f.s.ledger.model.state.inventory.is_empty(), "after row readiness same-area undo still reverses the actual purchase")
 quote = f.s.ledger.model.commerce_quote("base:B01")
 check(submit(f, "buy", {"item":"base:B01"}, quote.token).accepted, "after row readiness same-area buy remains available at the real source price")
 held = f.s.ledger.model.state.inventory[0].duplicate(true)
 journal = f.s.ledger.model.state.shop_visit.undo.duplicate(true)
 check(submit(f, "sell", {"uid":held.uid}).accepted and f.s.ledger.model.state.inventory.is_empty() and f.s.ledger.model.state.gold > 1050, "after row readiness same-area sell uses the actual held UID and source refund")
 check(submit(f, "undo").accepted and f.s.ledger.model.state.inventory == [held] and f.s.ledger.model.state.gold == 1050 and f.s.ledger.model.state.shop_visit.undo == journal, "same-area sell undo restores exact UID, 1050 wallet and prior nonempty buy journal")
 check(f.s.close_panel().accepted and f.s.ledger.model.state.shop_visit.undo == journal, "close after ready-row commerce retains journal until physical departure")
 check(f.s.select_node(2, "r02a").accepted, "diagnostic explicitly selects adjacent training row")
 check(not f.s.reset_training().accepted, "selection does not grant training permission before entry")
 f.s.focus_lost()
 before = f.s.ledger.model.state.duplicate(true)
 var row_before: Dictionary = f.s.row_state.snapshot()
 check(not f.s.enter_selected_node().accepted, "focus pause rejects next-room preflight before irreversible commit")
 check(f.s.ledger.model.state == before and f.s.row_state.snapshot() == row_before and f.s.ledger.model.state.shop_visit.undo == journal, "rejected arbitrary-room transition preserves nonempty inverse journal and row identity")
 check(f.s.explicit_resume().accepted, "explicit source resume releases focus guard")
 var visits: int = f.s.ledger.model.state.shop_visit.visited_rooms.size()
 check(f.s.enter_selected_node().accepted, "actual noncombat shop-to-training room entry commits prior visit")
 check(f.s.ledger.model.state.shop_visit.visited_rooms.size() == visits + 1 and f.s.ledger.model.state.shop_visit.undo.is_empty(), "ANY-room commerce boundary commits the nonempty journal exactly once")
 check(f.s.ledger.model.state.inventory == [held] and f.s.ledger.model.state.gold == 1050, "commit keeps purchased UID and spent gold exactly unchanged")
 before = f.s.ledger.model.state.duplicate(true)
 row_before = f.s.row_state.snapshot()
 check(not f.s.enter_selected_node().accepted and f.s.ledger.model.state == before and f.s.row_state.snapshot() == row_before, "duplicate selected-node entry cannot recommit or repeat the room")
 check(f.s.ledger.model.state.training and not f.s.open_panel().accepted, "entered training has training permission and no shop permission")
 check(f.s.reset_training().accepted, "training delegates to existing real respec authority")
 f.s.update_after_source_step()
 check(f.s.ledger.model.state.points == 1 and f.s.ledger.model.state.skills.Q.rank == 0 and f.sim.hero.ranks.q == 0, "training returns only the real previously-invested 1SP")
 check(f.s.learn_q1().accepted, "safe learning still works inside training without a shop")
 f.s.update_after_source_step()
 check(f.s.ledger.model.state.points == 0 and f.sim.hero.ranks.q == 1, "training relearn spends that same original point")
 check(f.s.complete_service().accepted and f.s.ledger.model.state.training, "training row readiness retains physical training permission until actual next entry")
 before = f.s.ledger.model.state.duplicate(true)
 var completed_training: Dictionary = f.s.row_state.snapshot()
 check(not f.s.complete_service().accepted and f.s.ledger.model.state == before and f.s.row_state.snapshot() == completed_training, "duplicate training readiness cannot record another completion or mutate economy")
 check(f.s.reset_training().accepted and not f.s.open_panel().accepted, "while still physically in ready training area reset remains allowed and shop remains unavailable")
 f.s.update_after_source_step()
 check(f.s.ledger.model.state.points == 1 and f.s.ledger.model.state.skills.Q.rank == 0 and f.sim.hero.ranks.q == 0, "post-readiness reset still returns only the same actually invested point")
 check(f.s.learn_q1().accepted, "post-readiness safe relearn remains within the current training area")
 f.s.update_after_source_step()
 check(f.s.ledger.model.state.points == 0 and f.sim.hero.ranks.q == 1, "post-readiness relearn spends the original point once")
 check(f.s.select_node(3, "r03").accepted and f.s.start_next_room().accepted, "start_next_room adapter enters the explicitly selected subsequent shop")
 check(not f.s.ledger.model.state.training and f.s.open_panel().accepted and not f.s.reset_training().accepted, "actual training-to-shop entry revokes training and grants only current shop permission")
 before = f.s.ledger.model.state.duplicate(true)
 var denied: Dictionary = submit(f, "undo")
 check(not denied.accepted and denied.reason == "undo_boundary" and f.s.ledger.model.state == before, "later actual shop cannot recover the committed old-room purchase")
 check(f.sim.encounter_generation == 0 and f.sim.enemies.is_empty() and f.kills.is_empty() and f.terminals.is_empty() and f.s.ledger.model.state.reward_ids.is_empty(), "three genuine service entries fabricate no kill, terminal, gold reward or XP")
 check(f.s.ledger.model.state.level == 1 and f.s.ledger.model.state.xp == 0 and f.s.row_state.snapshot().completed_rows.size() == 2, "service traversal records exactly two explicit completions and no level progress")
 observations.append({"case":"SERVICE_DIAGNOSTIC_TOPOLOGY_NOT_NORMAL_PLAY", "funding":f.s.funding_receipt, "successful_original_price":450, "retained_uid":held.get("uid", -1), "gold_after_commit":f.s.ledger.model.state.gold, "completed_service_rows":2, "source_generations":f.sim.encounter_generation, "real_kills":0, "natural_earnings":false})
 close(f)

func economic_identity(f: Dictionary) -> Dictionary:
 var state: Dictionary = f.s.ledger.model.snapshot()
 return {"gold":state.gold, "xp":state.xp, "level":state.level, "points":state.points, "inventory":state.inventory.duplicate(true), "skills":state.skills.duplicate(true), "reward_ids":state.reward_ids.duplicate(true), "selected_hex":state.selected_hex.duplicate(true)}

func normal_first_combat_case(definition: Dictionary) -> void:
 var f: Dictionary = fresh(definition)
 if f.is_empty(): return
 if not choose_and_learn(f): close(f); return
 check(f.s.ledger.model.state.gold == 0 and f.s.ledger.model.state.xp == 0, "actual shipped-route combat starts with no test funds or XP")
 check(f.s.select_node(1, "r01").accepted, "normal run selects unchanged shipped r01")
 var economy: Dictionary = economic_identity(f)
 var entry: Dictionary = f.s.enter_selected_node()
 check(entry.accepted, "explicit selected shipped combat enters real source: " + str(entry.get("reason", "")))
 if not entry.accepted: close(f); return
 check(f.sim.ai_enabled and f.sim.phase == "combat" and f.sim.enemies.size() == 4 and f.s.expected_enemies.size() == 4, "r01 retains actual original AI and four source-authored enemies")
 check(economic_identity(f) == economy and f.s.row_state.snapshot().completed_rows.is_empty(), "combat entry grants no reward and cannot stand in for completion")
 var before: Dictionary = f.s.ledger.model.state.duplicate(true)
 check(not f.s.open_panel().accepted and not f.s.reset_training().accepted, "live combat permits neither shop nor training reset")
 check(f.s.ledger.model.state == before and not f.sim.paused, "combat permission denials cannot pause or mutate the source ledger")
 var stranger = Sim.new()
 root.add_child(stranger)
 var row_before: Dictionary = f.s.row_state.snapshot()
 var pending_before: Dictionary = f.s.terminal_pending.duplicate(true)
 check(not f.s.finish(f.sim, f.sim.snapshot()).accepted, "a current source snapshot without a genuine terminal cannot finish combat")
 f.s.queue_terminal(f.sim, f.sim.snapshot())
 check(f.s.terminal_pending == pending_before and f.s.row_state.snapshot() == row_before, "unterminated source snapshot cannot queue fabricated completion")
 check(not f.s.observe_event(stranger, f.sim.snapshot()).accepted, "foreign source instance cannot publish a callback into the live owner")
 f.s.queue_terminal(stranger, f.sim.snapshot())
 check(f.s.terminal_pending == pending_before and f.s.ledger.model.state == before and f.s.row_state.snapshot() == row_before, "foreign terminal callback is inert")
 stranger.free()
 var loops := 0
 while f.s.status == "combat" and loops < COMBAT_STEP_LIMIT:
  drive_actual_combat(f, loops)
  f.sim.step(STEP_SECONDS)
  f.s.update_after_source_step()
  loops += 1
 f.sim.hero.move_intent = Vector3.ZERO
 var won: bool = f.sim.phase == "victory" and f.s.row_state.snapshot().completed_rows.size() == 1
 first_combat_result = {"status":"ACTUAL_FIRST_COMBAT_COMPLETED" if won else "BOUNDED_DRIVER_DID_NOT_COMPLETE", "completed":won, "steps":loops, "maximum_steps":COMBAT_STEP_LIMIT, "simulated_seconds":loops * STEP_SECONDS, "source_phase":f.sim.phase, "session_status":f.s.status, "actual_kill_callbacks":f.kills.size(), "verified_kill_receipts":f.s.kill_receipts.size(), "terminal_callbacks":f.terminals.size(), "ledger_gold":f.s.ledger.model.state.gold, "ledger_xp":f.s.ledger.model.state.xp, "hero_hp":f.sim.hero.hp, "normal_full_floor":false}
 if won:
  check(f.kills.size() == 4 and f.s.kill_receipts.size() == 4 and f.terminals.size() == 1, "first row completion requires four actual unique kill receipts and one genuine terminal")
  check(f.s.ledger.model.state.reward_ids.size() == 4 and f.s.ledger.model.state.gold == 80 and f.s.ledger.model.state.xp == 48, "four unmodified actual minion deaths award source 80 gold and 48 XP once")
  check(f.s.available_choices().size() == 2 and f.s.row_state.snapshot().completed_rows.size() == 1, "only authentic completed first row unlocks its two adjacent choices")
  check(not f.s.open_panel().accepted, "a completed combat row does not become an unconfigured shop")
  before = f.s.ledger.model.state.duplicate(true)
  row_before = f.s.row_state.snapshot()
  f.s.queue_terminal(f.sim, f.terminals[0])
  f.s.update_after_source_step()
  check(f.s.ledger.model.state == before and f.s.row_state.snapshot() == row_before, "repeat genuine terminal cannot settle first row or credit its rewards twice")
 else:
  observations.append({"case":"bounded_actual_combat_not_complete", "result":first_combat_result.duplicate(true), "claim":"No firstcombat, fullfloor or Boss success inferred"})
  check(f.s.row_state.snapshot().completed_rows.is_empty(), "incomplete actual combat cannot manufacture row completion")
 if not f.kills.is_empty(): stale_callback_case(definition, f, f.kills[0], f.terminals[0] if not f.terminals.is_empty() else f.sim.snapshot())
 else: observations.append({"case":"stale_actual_kill_replay", "status":"NOT_RUN_NO_ACTUAL_KILL_AVAILABLE"})
 check(not f.s.snapshot().settlement.has("major_floor_event") and f.s.status != "completed" and not f.s.row_state.snapshot().ready_for_owner_boss_settlement, "first combat can never claim a Boss or full-floor settlement")
 close(f)

func drive_actual_combat(f: Dictionary, tick: int) -> void:
 if f.sim.paused or f.sim.hero.dead or f.sim.phase != "combat": return
 var living: Array = f.sim.living()
 if living.is_empty(): return
 var target: Dictionary = living[0]
 var distance: float = f.sim.hero.position.distance_to(target.position)
 for enemy in living:
  var candidate_distance: float = f.sim.hero.position.distance_to(enemy.position)
  if candidate_distance < distance: target = enemy; distance = candidate_distance
 var offset: Vector3 = target.position - f.sim.hero.position
 # Ordinary movement input only. Source collision, timing, cooldown and AI remain.
 f.sim.hero.move_intent = -offset.normalized() if distance < 4.0 else (offset.normalized() if distance > 8.0 else Vector3.ZERO)
 if target.state == "spawn": return
 if tick % 30 == 0:
  var armed: Dictionary = f.sim.request_ink_input("q_down")
  if armed.accepted:
   var anchored: Dictionary = f.sim.request_ink_input("left_down", f.sim.hero.position)
   if anchored.accepted:
    var end: Vector3 = f.sim.hero.position + offset.normalized() * 8.0
    f.sim.request_ink_input("motion", end)
    f.sim.request_ink_input("left_up", end)
   else: f.sim.cancel_ink_preview("finite_gate_rejected_anchor")
 f.sim.request_action("attack", target.position)

func stale_callback_case(definition: Dictionary, old: Dictionary, old_kill: Dictionary, old_terminal: Dictionary) -> void:
 var f: Dictionary = fresh(definition)
 if f.is_empty(): return
 if not choose_and_learn(f): close(f); return
 check(f.s.select_node(1, "r01").accepted and f.s.enter_selected_node().accepted, "fresh Session/run owns a separate first-room identity")
 var before: Dictionary = f.s.ledger.model.state.duplicate(true)
 var row_before: Dictionary = f.s.row_state.snapshot()
 var pending_before: Dictionary = f.s.terminal_pending.duplicate(true)
 check(not f.s.observe_event(old.sim, old_kill).accepted, "previous run’s actual Sim cannot publish into the new Session")
 check(not f.s.observe_event(f.sim, old_kill).accepted, "previous run’s actual kill cannot be relabeled as current source callback")
 f.s.queue_terminal(old.sim, old_terminal)
 f.s.queue_terminal(f.sim, old_terminal)
 f.s.update_after_source_step()
 check(f.s.terminal_pending == pending_before and f.s.ledger.model.state == before and f.s.row_state.snapshot() == row_before, "stale owner/run terminal callbacks cannot mutate the new row or authority")
 check(f.s.kill_receipts.is_empty() and f.s.ledger.model.state.reward_ids.is_empty(), "old actual kill receipt cannot credit a new run")
 observations.append({"case":"actual_stale_callback_isolation", "old_run":old.s.run_id, "fresh_run":f.s.run_id, "old_kill_sequence":old_kill.sequence, "replayed_rewards":0})
 close(f)

func fault_postcondition_case(definition: Dictionary) -> void:
 # Runtime branch source assertion plus isolated pure-state postcondition probe.
 # No Boss source state, live kill, terminal, level or monetary evidence is forged.
 var source: String = FileAccess.get_file_as_string("res://tests/ink_first_floor_session_20261004/floor_session.gd")
 check(source.contains("if not completed.get(\"accepted\", false): return _fault(\"boss_settlement_failed:"), "real settlement source routes rejected authority through the tested fault postcondition")
 var f: Dictionary = fresh(definition, false, true)
 if f.is_empty(): return
 var before: Dictionary = f.s.ledger.model.state.duplicate(true)
 var result: Dictionary = f.s.contract_only_fault_with_ready_mock_rows()
 check(f.s.contract_fault_injected and not result.accepted, "clearly isolated contract-only rejected authority reaches fault path")
 var state: Dictionary = f.s.snapshot()
 check(state.row_state.ready_for_owner_boss_settlement and state.row_state.status == "all_rows_recorded", "mock pure RowState stays ready because completed pure state cannot abort")
 check(state.status == "faulted" and not state.fault.is_empty() and state.settlement.is_empty() and f.sim.paused, "ready pure state never overrides Session fault with victory or a cleared fault")
 check(f.s.ledger.model.state == before and f.sim.encounter_generation == 0 and f.sim.enemies.is_empty() and f.kills.is_empty() and f.terminals.is_empty(), "contract-only fault proof does not alter actual source progression or fabricate gameplay")
 check(not f.s.explicit_resume().accepted and not f.s.enter_selected_node().accepted and not f.s.open_panel().accepted and not f.s.reset_training().accepted, "faulted Session blocks resume, room entry, shop and training")
 observations.append({"case":"MOCK_CALLER_ROWS_FAULT_POSTCONDITION_NOT_GAMEPLAY", "mock_pure_rows":12, "actual_boss_combat":false, "actual_boss_authority_preconditions_exercised":false, "session_status":state.status, "fault":state.fault.duplicate(true), "source_progression_unchanged":f.s.ledger.model.state == before})
 close(f)
