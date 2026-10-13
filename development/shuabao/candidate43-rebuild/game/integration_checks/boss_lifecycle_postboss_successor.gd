extends SceneTree
## PREPARED ONLY: run after explicit application of the reviewed live02 patch.
## Real ordinary Host factories, Session, source actors and authenticated events.
## Lethal source packets are bounded fixtures, never a natural-play claim.
const Host = preload("res://visual_rework_20261009/runtime_host.gd")
const Session = preload("res://tests/ink_river_hexes_20261006/frontdoor01/floor_session.gd")
const Binding = preload("res://visual_rework_20261009/binding/live_binding.gd")
const Room = preload("res://tests/ink_first_floor_room_art_20261004/room_layout.gd")
const HOME := "res://tests/ink_first_floor_user_route_20261005/runtime01/"
const SIM_PATH := "res://tests/ink_river_hexes_20261006/ordinary01/sim.gd"
const SESSION_PATH := "res://tests/ink_river_hexes_20261006/frontdoor01/floor_session.gd"
const MODEL_PATH := "res://visual_rework_20261009/binding/postboss_model.gd"
const POSTBOSS_BASE_MODEL_PATH := "res://tests/ink_equipment_live_20261008/content01/model.gd"
const POSTBOSS_BASE_MODEL_SHA := "af679ebb5a07f5896e69f8a5708d518b341e5eef86118fd47e5048f419a3cb37"
const BRIDGE_PATH := "res://visual_rework_20261009/binding/bridge.gd"
const DIRECTOR_PATH := "res://tests/ink_first_floor_boss_20261008/source01/enemy_director.gd"
const PARENT_DIRECTOR_PATH := "res://tests/ink_ultimate_presentation_20261006/r1_consumer01/timed_director.gd"
const CLOCK_PATH := "res://tests/ink_ultimate_presentation_20261006/r1_consumer01/clock_facade.gd"
const FROZEN_PARENT := "res://tests/ink_equipment_live_20261008/content01/source_binding.json"
const FROZEN_PARENT_SHA := "6883687b1149125ea70e92302d111c85aa5d925617c3ae835a9b00c657df3498"
const GATE_PATH := "res://integration_checks/boss_lifecycle_postboss_successor.gd"
const ROUTE := ["r01a", "r02a", "r03a", "r04a", "r05a", "r06a", "r07a", "r08a", "r09a", "r10a", "r11a", "r12boss"]
const REQUIRED_GROUPS = ["factory_zero_start_and_single_owners", "initial_row_and_ordinary_delegation", "authentic_room_end_and_next_room_cleanup", "authored_boss_scope_and_owner_death", "authored_boss_close_and_new_run_isolation", "authored_boss_hero_death"]
const MAX_TERMINAL_TICKS := 1000
const MAX_WARNING_TICKS := 1000
const MAX_ROOM_ACTORS := 6
var checks: int = 0
var failures: Array[String] = []
var completed_groups: Array[String] = []
var check_records: Array[Dictionary] = []
var observations: Dictionary = {}
var current_group: String = "admission"
var output_path: String = "user://first_floor_boss_lifecycle.json"
var serial: int = 0
var fixture_packets: Array[Dictionary] = []

func _initialize() -> void:
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--boss-lifecycle-result="):
   output_path = argument.trim_prefix("--boss-lifecycle-result=")
 run.call_deferred()

func check(ok: bool, label: String) -> bool:
 checks += 1
 check_records.append({"group":current_group, "passed":ok, "label":label})
 if not ok:
  failures.append(label)
  push_error(label)
 return ok

func complete_group(name: String) -> void:
 check(name == current_group and name in REQUIRED_GROUPS and name not in completed_groups, "unique expected completion marker: " + name)
 completed_groups.append(name)
 print("FIRST_FLOOR_BOSS_LIFECYCLE_GROUP ", name)

func identity(f: Dictionary) -> Dictionary:
 return {"sim":f.sim.get_instance_id(), "session":f.session.get_instance_id(), "ledger":f.session.ledger.get_instance_id(), "model":f.session.ledger.model.get_instance_id(), "hero":f.sim.hero.get_instance_id(), "clock":f.sim.clock.get_instance_id(), "director":f.sim.enemy_director.get_instance_id()}

func check_owners(f: Dictionary, label: String) -> void:
 var model = f.session.ledger.model
 check(identity(f) == f.identity, label + ": original seven identities retained")
 check(f.session._owner_intact() and is_same(f.sim.progression, f.session.ledger), label + ": one Session/progression owner")
 check(f.sim._equipment_health_owner != null and is_same(f.sim._equipment_health_owner.get_ref(), model), label + ": same equipment health observer")
 check(f.sim._ordinary_passive23_owner != null and is_same(f.sim._ordinary_passive23_owner.get_ref(), model), label + ": same passive23 model")
 check(f.sim._ordinary_potion_model != null and is_same(f.sim._ordinary_potion_model.get_ref(), model), label + ": same potion model")
 check(f.sim.clock._owner != null and is_same(f.sim.clock._owner.get_ref(), f.sim), label + ": clock owned by actual ordinary Sim")

func fresh() -> Dictionary:
 serial += 1
 var host = Host.new() # Factory only. Never add the GUI Host to the SceneTree.
 var sim = host._make_floor_sim()
 root.add_child(sim)
 host.sim = sim
 var session = host._make_floor_session()
 if not check(sim.get_script().resource_path == SIM_PATH and session.get_script().resource_path == SESSION_PATH, "actual ordinary Host factories preserve exact Sim/Session resource paths"):
  sim.free(); host.free(); return {}
 var admitted: Dictionary = Binding.read_capabilities(sim, true)
 if not check(admitted.get("accepted", false), "reviewed live binding admits actual factory: " + str(admitted.get("reason", ""))):
  sim.free(); host.free(); return {}
 var director_id: int = sim.enemy_director.get_instance_id()
 var navigation: Dictionary = host._install_source_navigation()
 if not check(navigation.get("accepted", false), "actual frontdoor navigation admission: " + str(navigation.get("reason", ""))):
  sim.free(); host.free(); return {}
 check(sim.enemy_director.get_instance_id() == director_id and not navigation.get("director_replaced", true), "navigation retains constructor-installed Boss Director")
 check(not host._install_source_navigation().get("accepted", false), "second navigation admission rejected")
 Room.bind_to_sim(sim)
 var configured: Dictionary = session.configure_reward_table(HOME + "reward_table.json", HOME + "rewards.csv", HOME + "validation_result.json", true)
 var loaded: Dictionary = Session.MixedSchema.load_definition(Session.DEFAULT_DEFINITION, true)
 if not check(configured.get("accepted", false) and loaded.get("accepted", false), "unchanged reward table and authored route load"):
  sim.free(); host.free(); return {}
 var initialized: Dictionary = session.initialize_floor(sim, loaded.definition, "boss-lifecycle-%d" % serial, true)
 if not check(initialized.get("accepted", false), "actual Session initializes once: " + str(initialized.get("reason", ""))):
  sim.free(); host.free(); return {}
 var router = host._make_floor_router()
 router.bind(sim)
 session.bind_input_suspender(router.suspend_input)
 var f: Dictionary = {"host":host, "sim":sim, "session":session, "router":router, "events":[], "terminals":[], "event_errors":[], "scope_errors":[], "identities":[]}
 f.identity = identity(f)
 f.event_callback = on_event.bind(f)
 f.terminal_callback = on_terminal.bind(f)
 sim.combat_event.connect(f.event_callback)
 sim.encounter_finished.connect(f.terminal_callback)
 var model = session.ledger.model
 var startup: Dictionary = model.snapshot()
 check(startup.level == 1 and startup.gold == 0 and startup.xp == 0 and startup.points == 1, "existing Lv1/0gold/0XP/1SP startup")
 check(startup.inventory.is_empty() and startup.selected_hex.is_empty() and startup.pending_milestones == [1], "no equipment or automatic initial Hex")
 for skill: Dictionary in startup.skills.values():
  check(int(skill.rank) == 0 and str(skill.candidate).is_empty(), "no automatically learned skill")
 check(sim.phase == "preparation" and sim.wave == 0 and sim.encounter_generation == 0 and sim.enemies.is_empty(), "factory remains before first combat")
 check(model.get_script().resource_path == MODEL_PATH and session.ledger.get_script().resource_path == BRIDGE_PATH, "new binding bridge retains exact equipment content model")
 check(model.get_script().get_base_script() != null and model.get_script().get_base_script().resource_path == POSTBOSS_BASE_MODEL_PATH, "postboss Model is exactly one inheritance layer over original content01 Model")
 check(FileAccess.get_sha256(POSTBOSS_BASE_MODEL_PATH) == POSTBOSS_BASE_MODEL_SHA, "original content01 Model SHA is unchanged")
 check(sim.clock.get_script().resource_path == CLOCK_PATH and sim.enemy_director.get_script().resource_path == DIRECTOR_PATH, "one retained clock with source01 Boss Director")
 check(sim.enemy_director.get_script().get_base_script().resource_path == PARENT_DIRECTOR_PATH, "Boss Director delegates through exact previous timed Director")
 check(admitted.capabilities.source_binding_id == FileAccess.get_sha256(Binding.BINDING_PATH), "one verified source binding identity")
 check_owners(f, "startup")
 check(not session.initialize_floor(sim, loaded.definition, "second-binding-forbidden", true).get("accepted", false), "same Session cannot initialize a second run")
 check(not sim.bind_potion_model(model).get("accepted", false), "same Sim refuses a second potion owner binding")
 f.startup = startup.duplicate(true)
 return f

func on_event(event: Dictionary, f: Dictionary) -> void:
 f.events.append(event.duplicate(true))
 var observed: Dictionary = f.session.observe_event(f.sim, event)
 if event.get("kind", "") in ["damage", "kill"] and not observed.get("accepted", false):
  f.event_errors.append({"event":event.duplicate(true), "result":observed.duplicate(true)})
 if str(event.get("boss_cast_id", "")).is_empty(): return
 if event.get("run_id", "") != f.session.run_id or int(event.get("source_instance_id", -1)) != f.sim.get_instance_id() or event.get("room_id", "") != f.sim.room_id or int(event.get("generation", -1)) != f.sim.encounter_generation:
  # Legacy enemy_attack_cancelled intentionally carries only its established
  # subset. The dedicated boss_cast_cancelled event is the full-scope evidence.
  if event.get("kind", "") != "enemy_attack_cancelled": f.scope_errors.append(event.duplicate(true))

func on_terminal(snapshot: Dictionary, f: Dictionary) -> void:
 f.terminals.append(snapshot.duplicate(true))
 f.session.queue_terminal(f.sim, snapshot)

func events_of(f: Dictionary, kind: String, cast_id: String = "") -> Array:
 var found: Array = []
 for event: Dictionary in f.events:
  if event.get("kind", "") == kind and (cast_id.is_empty() or event.get("boss_cast_id", "") == cast_id): found.append(event)
 return found

func step(f: Dictionary, count: int = 1) -> void:
 for _tick: int in range(count):
  f.sim.step(f.sim.FIXED_TICK)
  f.session.update_after_source_step()

func command(f: Dictionary, action: String, args: Dictionary) -> Dictionary:
 serial += 1
 var result: Dictionary = f.session.ledger.model.command("boss-lifecycle-command-%d" % serial, action, args)
 f.session.progression_command_completed({"action":action, "args":args}, result)
 f.session.update_after_source_step()
 return result

func choose_required_hexes(f: Dictionary) -> bool:
 var pending: Array = f.session.ledger.model.snapshot().pending_milestones.duplicate()
 if not check(pending.size() <= 4, "bounded existing milestone choices"): return false
 for milestone in pending:
  if not check(command(f, "hex_open", {"milestone":milestone}).get("accepted", false), "open actual milestone " + str(milestone)): return false
  if not check(command(f, "hex_select", {"milestone":milestone, "slot":3}).get("accepted", false), "select actual offered personal Hex " + str(milestone)): return false
 return true

func prepare_initial_choices(f: Dictionary) -> bool:
 check(not f.session.open_panel().get("accepted", false), "initial mandatory Hex still blocks shop")
 check(not f.session.select_node(12, "r12boss").get("accepted", false), "Session refuses a Boss shortcut before row1")
 if not choose_required_hexes(f): return false
 if not check(f.session.learn_q1().get("accepted", false), "learn Q1 through existing Session using original one SP"): return false
 f.session.update_after_source_step()
 check(f.session.ledger.model.state.points == 0 and f.sim.hero.loadout.q == "q1", "real initial choice projected by existing owner")
 return true

func enter(f: Dictionary, row: int) -> bool:
 if not choose_required_hexes(f): return false
 var node_id: String = ROUTE[row - 1]
 if not check(f.session.select_node(row, node_id).get("accepted", false), "select connected authored row " + node_id): return false
 var result: Dictionary = f.session.enter_selected_node()
 if not check(result.get("accepted", false), "enter through actual Session " + node_id + ": " + str(result.get("reason", ""))): return false
 check(f.session.fault.is_empty(), "no Session fault entering " + node_id)
 check_owners(f, "row " + str(row))
 f.identities.append({"row":row, "room_id":f.session.active_node_room, "generation":f.sim.encounter_generation, "identity":identity(f)})
 return true

func lethal_enemy_fixture(f: Dictionary, enemy: Dictionary, purpose: String) -> void:
 # Explicit bounded fixture, through real source damage. Never assign HP/dead,
 # rewards, XP, levels, row completion, generation or terminal snapshots.
 var amount: float = float(enemy.hp) + 100000.0
 fixture_packets.append({"target":"enemy", "actor_id":enemy.actor_id, "run_id":f.session.run_id, "room_id":f.sim.room_id, "generation":f.sim.encounter_generation, "amount":amount, "purpose":purpose})
 f.sim.damage_enemy(enemy, amount, "boss_lifecycle_lethal_fixture", 0, true, false, {"direct":false, "no_reactions":true, "fixture":true})

func settle_fixture_combat(f: Dictionary) -> bool:
 # Real source damage rejects actors during spawn grace. Let the existing AI
 # advance its own state first; never force a damageable state on the actors.
 for _tick: int in range(100):
  var spawning: bool = false
  for enemy: Dictionary in f.sim.living():
   if enemy.state == "spawn": spawning = true
  if not spawning or f.sim.phase != "combat": break
  step(f)
 var actors: Array = f.sim.living().duplicate()
 if not check(not actors.is_empty() and actors.size() <= MAX_ROOM_ACTORS, "fixture damage bounded to actual authored roster"): return false
 for enemy: Dictionary in actors:
  if not check(enemy.state != "spawn", "actual spawn grace ends before lethal fixture"): return false
 for enemy: Dictionary in actors: lethal_enemy_fixture(f, enemy, "advance authored route without natural-combat claim")
 for _tick: int in range(MAX_TERMINAL_TICKS):
  if f.session.status != "combat": break
  step(f)
 if not check(f.sim.phase == "victory" and f.session.status == "between_rooms", "authentic source terminal settles fixture room within budget"): return false
 check(f.session.kill_receipts.size() == actors.size(), "one authenticated kill receipt per entered actor")
 check(f.event_errors.is_empty(), "all actual damage and kill events authenticated")
 check(f.session.terminal_pending.is_empty() and f.session.fault.is_empty(), "outer Session boundary drains terminal without fault")
 return true

func traverse_to_boss(f: Dictionary, first_row: int) -> bool:
 # All twelve rows remain real; only combat damage is a labelled fixture.
 for row: int in range(first_row, 13):
  if not enter(f, row): return false
  if row == 12: break
  if f.session.status == "service":
   if not check(f.session.complete_service().get("accepted", false), "complete actual service row " + str(row)): return false
  elif not settle_fixture_combat(f): return false
 if not check(f.session.status == "combat" and f.session.row_state.snapshot().completed_rows.size() == 11, "Boss entered only after eleven authentic row completions"): return false
 if not check(f.sim.enemies.size() == 1 and f.sim.enemies[0].kind == "boss", "authored final roster is exactly the real Boss"): return false
 f.boss = f.sim.enemies[0]
 check(f.session.boss_id == f.boss.actor_id and f.session._boss_registration.get("accepted", false), "original Session registers actual Boss with reward owner")
 return true

func wait_for_boss_warning(f: Dictionary) -> Dictionary:
 for _tick: int in range(MAX_WARNING_TICKS):
  if f.boss.has("boss_runtime") and not f.boss.boss_runtime.cast.is_empty(): break
  if f.sim.phase != "combat" or f.sim.hero.dead: break
  step(f)
 var snapshot: Dictionary = f.sim.enemy_director.snapshot(f.sim, f.boss)
 var cast: Dictionary = snapshot.get("cast", {})
 if not check(not cast.is_empty() and f.boss.state == "warning", "real Boss AI naturally arms warning within bounded source steps"): return {}
 check(snapshot.current and cast.run_id == f.session.run_id and cast.source_instance_id == f.sim.get_instance_id(), "Boss cast has actual run and source owner")
 check(cast.room_id == f.session.current_room_id and cast.generation == f.session.current_generation and cast.generation == f.sim.encounter_generation, "Boss cast has actual room and generation")
 check(cast.target_actor_id == f.sim.hero.actor_id, "Boss targets actual retained hero")
 var warnings: Array = events_of(f, "enemy_warning", str(cast.boss_cast_id))
 check(warnings.size() == 1 and warnings[0].get("boss_move", "") == cast.move, "one actual Boss warning event identifies committed move")
 check(f.scope_errors.is_empty(), "actual Boss event scopes match run/room/generation")
 return cast.duplicate(true)

func first_row_case(f: Dictionary) -> bool:
 current_group = REQUIRED_GROUPS[1]
 if not prepare_initial_choices(f) or not enter(f, 1): return false
 check(f.sim.ai_enabled and f.sim.auto_finish and f.sim.living().size() == 4, "row1 retains four ordinary AI and original terminal ownership")
 check(not f.session.open_panel().get("accepted", false), "combat still rejects shop")
 for _tick: int in range(MAX_WARNING_TICKS):
  if not events_of(f, "enemy_warning").is_empty() or f.sim.phase != "combat": break
  step(f)
 var warnings: Array = events_of(f, "enemy_warning")
 if not check(not warnings.is_empty(), "ordinary actor produces inherited warning using real source steps"): return false
 for event: Dictionary in warnings:
  check(str(event.get("boss_cast_id", "")).is_empty() and event.get("actor_id", "") in f.session.expected_enemies, "ordinary warning retains entered actor and no Boss cast")
 for enemy: Dictionary in f.sim.enemies:
  check(enemy.kind == "minion" and not enemy.has("boss_runtime"), "ordinary actor remains outside Boss controller state")
 check(f.sim.enemy_director.commits > 0 and f.sim.clock.advances > 0, "ordinary Director and inherited clock actually advanced")
 check_owners(f, "ordinary delegation")
 complete_group(current_group)
 current_group = REQUIRED_GROUPS[2]
 var old_room: String = f.sim.room_id
 var old_generation: int = f.sim.encounter_generation
 var old_ids: Array = f.session.expected_enemies.duplicate()
 if not settle_fixture_combat(f): return false
 check(f.session.row_state.snapshot().completed_rows.size() == 1 and old_room in f.session.cleared, "actual row1 completion recorded once")
 var first_terminal: Dictionary = f.terminals.back().duplicate(true)
 var before: PackedByteArray = var_to_bytes(f.session.ledger.model.state)
 f.session.queue_terminal(f.sim, first_terminal)
 f.session.update_after_source_step()
 check(before == var_to_bytes(f.session.ledger.model.state) and f.session.row_state.snapshot().completed_rows.size() == 1, "repeated authentic terminal cannot duplicate settlement")
 check(f.sim.pending.is_empty() and f.sim.projectiles.is_empty() and f.sim.zones.is_empty(), "room terminal leaves no pending ordinary delivery")
 if not enter(f, 2): return false
 check(f.sim.room_id != old_room and f.sim.encounter_generation == old_generation + 1, "actual next combat changes room and increments generation once")
 for actor_id in old_ids: check(f.sim.enemy_by_id(str(actor_id)).is_empty(), "next room removes old actor " + str(actor_id))
 check(f.sim.pending.is_empty() and f.sim.projectiles.is_empty() and f.sim.zones.is_empty(), "next room begins without old delivery queues")
 before = var_to_bytes(f.session.ledger.model.state)
 f.session.queue_terminal(f.sim, first_terminal)
 check(f.session.terminal_pending.is_empty() and before == var_to_bytes(f.session.ledger.model.state), "old room terminal cannot cross actual room/generation boundary")
 if not settle_fixture_combat(f): return false
 observations["ordinary_room_transition"] = {"old_room":old_room, "old_generation":old_generation, "new_room":f.sim.room_id, "new_generation":f.sim.encounter_generation, "ordinary_warning_count":warnings.size(), "lethal_fixture":true}
 complete_group(current_group)
 return true

func owner_death_case(f: Dictionary) -> void:
 current_group = REQUIRED_GROUPS[3]
 if not traverse_to_boss(f, 3): return
 var cast: Dictionary = wait_for_boss_warning(f)
 if cast.is_empty(): return
 var id: String = cast.boss_cast_id
 # Pause through the existing modal API; the sole world clock must freeze.
 var clock_at: float = f.sim.clock.world_time
 var before_cast: PackedByteArray = var_to_bytes(f.boss.boss_runtime.cast)
 if not check(f.session.set_modal_blocked(true).get("accepted", false), "existing modal API pauses Boss warning"): return
 step(f, 100)
 check(f.sim.clock.world_time == clock_at and var_to_bytes(f.boss.boss_runtime.cast) == before_cast, "pause freezes same Boss cast and world clock")
 if not check(f.session.set_modal_blocked(false).get("accepted", false), "existing modal API resumes Boss warning"): return
 lethal_enemy_fixture(f, f.boss, "cancel real authored Boss warning on owner death")
 check(f.boss.dead and f.boss.boss_runtime.cast.is_empty(), "actual source death immediately retires Boss cast")
 var cancellations: Array = events_of(f, "boss_cast_cancelled", id)
 check(cancellations.size() == 1 and cancellations[0].get("reason", "") == "owner_died", "one source cancellation identifies owner death")
 var kills: Array = events_of(f, "kill")
 var boss_kills: Array = kills.filter(func(event: Dictionary): return event.get("target", "") == f.boss.actor_id)
 check(boss_kills.size() == 1 and not cancellations.is_empty() and int(cancellations[0].sequence) < int(boss_kills[0].sequence), "cast is retired before authentic Boss kill notification")
 for _tick: int in range(MAX_TERMINAL_TICKS):
  if f.session.status != "combat": break
  step(f)
 if not check(f.sim.phase == "victory" and f.session.status == "completed", "original owner settles lethal-fixture authored Boss completion"): return
 check(f.session.kill_receipts.has(f.boss.actor_id) and f.session.settlement.has("major_floor_event"), "existing reward/act completion chain uses authentic Boss kill")
 check(f.event_errors.is_empty() and f.scope_errors.is_empty(), "Boss lifecycle introduces no rejected source events or scope mismatch")
 var before: PackedByteArray = var_to_bytes(f.session.ledger.model.state)
 if not boss_kills.is_empty():
  var replay: Dictionary = f.session.ledger.model.observe_live_event(f.session, f.sim, boss_kills[0])
  check(not replay.get("changed", false) and before == var_to_bytes(f.session.ledger.model.state), "authentic Boss kill replay cannot mint a second reward")
 var hp: float = f.sim.hero.hp
 step(f, 150)
 check(f.sim.hero.hp == hp and events_of(f, "boss_attack_released", id).is_empty() and events_of(f, "boss_hit_receipt", id).is_empty(), "retired Boss warning never releases or hits after victory")
 check_owners(f, "Boss owner death")
 observations["owner_death"] = {"cast":cast, "cancellations":cancellations, "boss_kills":boss_kills, "session_status":f.session.status, "fixture_route_settled":true, "natural_full_floor":false}
 complete_group(current_group)

func close_and_new_run_case() -> void:
 current_group = REQUIRED_GROUPS[4]
 var f: Dictionary = fresh()
 if f.is_empty(): return
 if not prepare_initial_choices(f) or not traverse_to_boss(f, 1): dispose(f); return
 var cast: Dictionary = wait_for_boss_warning(f)
 if cast.is_empty(): dispose(f); return
 var id: String = cast.boss_cast_id
 if not check(f.session.close_run().get("accepted", false), "actual Session close accepts active Boss warning"): dispose(f); return
 f.session.update_after_source_step()
 check(f.session.status == "aborted" and f.sim.phase == "host_closed", "Session and actual source reach closed terminal")
 check(not f.boss.dead and f.boss.boss_runtime.cast.is_empty(), "close retires living Boss cast without a fake kill")
 var cancellations: Array = events_of(f, "boss_cast_cancelled", id)
 check(cancellations.size() == 1 and cancellations[0].get("reason", "") == "room_or_terminal", "one real close cancellation")
 check(not f.session.settlement.has("major_floor_event") and f.session.kill_receipts.is_empty(), "closing Boss cannot grant Boss or floor settlement")
 # Closure legitimately changes combat/safe context; compare reward evidence.
 check(f.session.ledger.model.state.reward_ids.size() == f.events.filter(func(event: Dictionary): return event.get("kind", "") == "kill").size(), "close adds no unauthenticated reward")
 var before: PackedByteArray = var_to_bytes(f.session.ledger.model.state)
 f.session.close_run(); step(f, 150)
 check(before == var_to_bytes(f.session.ledger.model.state) and events_of(f, "boss_cast_cancelled", id).size() == 1, "repeat close and later steps are idempotent")
 check(events_of(f, "boss_attack_released", id).is_empty() and events_of(f, "boss_hit_receipt", id).is_empty(), "closed warning never delivers")
 var next: Dictionary = fresh()
 if next.is_empty(): dispose(f); return
 if not prepare_initial_choices(next) or not traverse_to_boss(next, 1): dispose(next); dispose(f); return
 var next_cast: Dictionary = wait_for_boss_warning(next)
 if next_cast.is_empty(): dispose(next); dispose(f); return
 check(next.session.run_id != f.session.run_id and next.sim.get_instance_id() != f.sim.get_instance_id(), "new actual run owns a distinct Session source")
 check(next.boss.actor_id == f.boss.actor_id and next.sim.encounter_generation == f.sim.encounter_generation, "fixture deliberately reaches reusable actor serial/generation in new run")
 check(next_cast.boss_cast_id != id and next_cast.run_id != cast.run_id and next_cast.room_id != cast.room_id, "new Boss cast remains distinct despite reused actor serial/generation")
 before = var_to_bytes(next.boss.boss_runtime.cast)
 var next_hp: float = next.sim.hero.hp
 var next_count: int = next.events.size()
 # Explicit stale-callback probe using the REAL retained prior actor, never a
 # forged dictionary or altered run/room/generation on either source.
 var stale: Dictionary = next.sim.enemy_director.snapshot(next.sim, f.boss)
 check(not stale.current, "new ordinary source rejects actual old Boss owner")
 var rejected: Dictionary = next.sim.enemy_director.boss_controller.commit_for_test(next.sim, f.boss, "B")
 next.sim.enemy_director.step_enemy(next.sim, f.boss, next.sim.FIXED_TICK)
 check(not rejected.get("accepted", false) and rejected.get("reason", "") == "inactive_scope", "old actual Boss cannot commit inside new run")
 check(next.sim.hero.hp == next_hp and next.events.size() == next_count and before == var_to_bytes(next.boss.boss_runtime.cast), "stale real actor cannot mutate current cast, HP or events")
 check_owners(next, "new-run isolation")
 observations["close_and_new_run"] = {"closed_cast":cast, "cancellations":cancellations, "new_cast":next_cast, "stale_rejection":rejected, "actual_prior_actor_probe":true}
 dispose(next); dispose(f)
 complete_group(current_group)

func hero_death_case() -> void:
 current_group = REQUIRED_GROUPS[5]
 var f: Dictionary = fresh()
 if f.is_empty(): return
 if not prepare_initial_choices(f) or not traverse_to_boss(f, 1): dispose(f); return
 var cast: Dictionary = wait_for_boss_warning(f)
 if cast.is_empty(): dispose(f); return
 var id: String = cast.boss_cast_id
 var amount: float = float(f.sim.hero.hp) + 100000.0
 fixture_packets.append({"target":"hero", "actor_id":f.sim.hero.actor_id, "run_id":f.session.run_id, "room_id":f.sim.room_id, "generation":f.sim.encounter_generation, "amount":amount, "purpose":"one mandatory true source packet to exercise authentic hero death"})
 f.sim.damage_hero(amount, Vector3.ZERO, 0.0, true, true, {"fixture":true, "direct":false, "damage_provenance":"boss_lifecycle_hero_death_fixture"})
 f.session.update_after_source_step()
 if not check(f.sim.hero.dead and f.sim.phase == "true_dead" and f.session.status == "defeated", "actual lethal source packet reaches real hero death and Session defeat"): dispose(f); return
 check(not f.boss.dead and f.boss.boss_runtime.cast.is_empty(), "hero death retires living Boss warning")
 var cancellations: Array = events_of(f, "boss_cast_cancelled", id)
 check(cancellations.size() == 1 and cancellations[0].get("reason", "") == "room_or_terminal", "hero terminal emits one real Boss cancellation")
 check(f.session.kill_receipts.is_empty() and not f.session.settlement.has("major_floor_event"), "hero defeat grants no Boss/floor victory")
 check(f.event_errors.is_empty() and f.scope_errors.is_empty() and f.session.fault.is_empty(), "hero death source and scope remain authenticated")
 var before: PackedByteArray = var_to_bytes(f.session.ledger.model.state)
 var hp: float = f.sim.hero.hp
 step(f, 150)
 check(f.sim.hero.hp == hp and before == var_to_bytes(f.session.ledger.model.state), "post-death steps cannot deliver damage or repeat death settlement")
 check(events_of(f, "boss_attack_released", id).is_empty() and events_of(f, "boss_hit_receipt", id).is_empty(), "hero-death-cancelled warning never releases or hits")
 check_owners(f, "hero death")
 observations["hero_death"] = {"cast":cast, "cancellations":cancellations, "session_status":f.session.status, "explicit_lethal_hero_fixture":true}
 dispose(f)
 complete_group(current_group)

func dispose(f: Dictionary) -> void:
 if f.is_empty(): return
 if is_instance_valid(f.sim):
  if f.session.status not in ["unbound", "completed", "defeated", "aborted"]: f.session.close_run()
  if f.sim.combat_event.is_connected(f.event_callback): f.sim.combat_event.disconnect(f.event_callback)
  if f.sim.encounter_finished.is_connected(f.terminal_callback): f.sim.encounter_finished.disconnect(f.terminal_callback)
  f.sim.free()
 if is_instance_valid(f.host):
  f.host.sim = null
  f.host.free()
 f.clear()

func run() -> void:
 current_group = REQUIRED_GROUPS[0]
 if not check(FileAccess.get_sha256(FROZEN_PARENT) == FROZEN_PARENT_SHA, "frozen equipment content01 parent untouched"):
  finish(); return
 var f: Dictionary = fresh()
 if f.is_empty(): finish(); return
 observations["startup"] = {"state":f.startup, "identity":f.identity, "source_binding_sha256":FileAccess.get_sha256(Binding.BINDING_PATH)}
 complete_group(current_group)
 if first_row_case(f): owner_death_case(f)
 dispose(f)
 close_and_new_run_case()
 hero_death_case()
 finish()

func finish() -> void:
 current_group = "report"
 check(completed_groups == REQUIRED_GROUPS, "all six required groups reached exact completion markers")
 check(check_records.size() == checks, "every check has a recorded outcome")
 check(not output_path.is_empty(), "explicit result path is nonempty")
 var file: FileAccess = null
 if not output_path.is_empty(): file = FileAccess.open(output_path, FileAccess.WRITE)
 check(file != null, "lifecycle JSON output can be written: " + output_path)
 var report: Dictionary = {"suite":"first_floor_boss_actual_ordinary_lifecycle_live01", "passed":failures.is_empty() and completed_groups == REQUIRED_GROUPS, "checks":checks, "failures":failures, "completed_groups":completed_groups, "required_groups":REQUIRED_GROUPS, "check_records":check_records, "source_binding_sha256":FileAccess.get_sha256(Binding.BINDING_PATH), "gate_sha256":FileAccess.get_sha256(GATE_PATH), "frozen_parent_sha256":FileAccess.get_sha256(FROZEN_PARENT), "runtime_status":"EXECUTED", "observations":observations, "fixture_packets":fixture_packets, "ordinary_factory_session":true, "normal_run_modified":false, "real_source_events":true, "explicit_lethal_packets":true, "art_accepted":false, "art_audio_accepted":false, "native_input":false, "native_input_verified":false, "natural_leveling":false, "natural_full_floor":false, "full_floor":false, "full_floor_verified":false, "gui_host_ready_executed":false}
 if file != null:
  file.store_string(JSON.stringify(report, "  "))
  var write_error: Error = file.get_error()
  file.close()
  if write_error != OK:
   check(false, "lifecycle JSON write completed")
   report.checks = checks; report.failures = failures; report.check_records = check_records; report.passed = false
 print("FIRST_FLOOR_BOSS_LIFECYCLE ", JSON.stringify(report))
 quit(0 if report.passed else 1)
