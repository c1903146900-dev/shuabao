extends "res://integration_checks/boss_lifecycle_successor.gd"
## Headless contract gate. The GUI Host is used only as a genuine factory.
## Reuses authenticated source events and explicitly labelled lethal fixtures.
## No HP/gold/XP/SP/rank/room/terminal assignment or natural-play claim.
const PostbossController = preload("res://tests/ink_q3_input_growth_20261004/controller.gd")
const POSTBOSS_MODEL_PATH := "res://equipment_expansion_20261009/model.gd"
const POSTBOSS_PRIOR_MODEL_PATH := "res://visual_rework_20261009/binding/postboss_model.gd"
const POSTBOSS_BASE_MODEL_PATH := "res://tests/ink_equipment_live_20261008/content01/model.gd"
const POSTBOSS_BASE_MODEL_SHA := "af679ebb5a07f5896e69f8a5708d518b341e5eef86118fd47e5048f419a3cb37"
const POSTBOSS_GATE_PATH := "res://integration_checks/postboss_equipment33_gate.gd"
const POSTBOSS_ROUTE := ["r01a", "r02a", "r03a", "r04a", "r05a", "r06a", "r07a", "r08a", "r09a", "r10b", "r11a", "r12boss"]
const POSTBOSS_GROUPS := ["exact_factory_and_single_owner", "safe_potion_next_combat", "authentic_boss_lv7_modal", "completed_growth_and_commerce", "completed_potion_rejection_and_replay"]

func _initialize() -> void:
 output_path = "user://postboss_contract_gate.json"
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--postboss-result="):
   output_path = argument.trim_prefix("--postboss-result=")
 run.call_deferred()

func complete_group(name: String) -> void:
 check(name == current_group and name in POSTBOSS_GROUPS and name not in completed_groups, "unique post-Boss contract group: " + name)
 completed_groups.append(name)
 print("POSTBOSS_CONTRACT_GROUP ", name)

func fresh() -> Dictionary:
 # Same original factory/admission body, with an exact one-layer Model successor.
 # This replacement preserves all seven owner checks instead of relaxing them.
 serial += 1
 var host = Host.new()
 var sim = host._make_floor_sim()
 root.add_child(sim)
 host.sim = sim
 var session = host._make_floor_session()
 if not check(sim.get_script().resource_path == SIM_PATH and session.get_script().resource_path == SESSION_PATH, "actual ordinary Host factories preserve exact Sim/Session paths"):
  sim.free(); host.free(); return {}
 var admitted: Dictionary = Binding.read_capabilities(sim, true)
 if not check(admitted.get("accepted", false), "successor binding admits actual factory: " + str(admitted.get("reason", ""))):
  sim.free(); host.free(); return {}
 var director_id: int = sim.enemy_director.get_instance_id()
 var navigation: Dictionary = host._install_source_navigation()
 if not check(navigation.get("accepted", false), "actual navigation admission: " + str(navigation.get("reason", ""))):
  sim.free(); host.free(); return {}
 check(sim.enemy_director.get_instance_id() == director_id and not navigation.get("director_replaced", true), "navigation retains constructor-installed Boss Director")
 check(not host._install_source_navigation().get("accepted", false), "second navigation admission rejected")
 Room.bind_to_sim(sim)
 var configured: Dictionary = session.configure_reward_table(HOME + "reward_table.json", HOME + "rewards.csv", HOME + "validation_result.json", true)
 var loaded: Dictionary = Session.MixedSchema.load_definition(Session.DEFAULT_DEFINITION, true)
 if not check(configured.get("accepted", false) and loaded.get("accepted", false), "unchanged reward table and authored route load"):
  sim.free(); host.free(); return {}
 var initialized: Dictionary = session.initialize_floor(sim, loaded.definition, "postboss-contract-%d" % serial, true)
 if not check(initialized.get("accepted", false), "actual Session initializes once: " + str(initialized.get("reason", ""))):
  sim.free(); host.free(); return {}
 var router = host._make_floor_router()
 router.bind(sim)
 check(session.bind_input_suspender(router.suspend_input).get("accepted", false), "actual input router owns suspension")
 var f: Dictionary = {"host":host, "sim":sim, "session":session, "router":router, "events":[], "terminals":[], "event_errors":[], "scope_errors":[], "identities":[], "modal_receipts":[]}
 f.identity = identity(f)
 f.event_callback = on_event.bind(f)
 f.terminal_callback = on_terminal.bind(f)
 sim.combat_event.connect(f.event_callback)
 sim.encounter_finished.connect(f.terminal_callback)
 var model = session.ledger.model
 var startup: Dictionary = model.snapshot()
 check(startup.level == 1 and startup.gold == 0 and startup.xp == 0 and startup.points == 1, "ordinary Lv1/0gold/0XP/1SP startup")
 check(startup.inventory.is_empty() and startup.selected_hex.is_empty() and startup.pending_milestones == [1], "no equipment or automatic initial Hex")
 for skill: Dictionary in startup.skills.values():
  check(int(skill.rank) == 0 and str(skill.candidate).is_empty(), "no automatically learned skill")
 check(sim.phase == "preparation" and sim.wave == 0 and sim.encounter_generation == 0 and sim.enemies.is_empty(), "factory remains before first combat")
 check_model_successor(f, "startup")
 check(session.ledger.get_script().resource_path == BRIDGE_PATH, "exact existing successor Bridge path retained")
 check(sim.clock.get_script().resource_path == CLOCK_PATH and sim.enemy_director.get_script().resource_path == DIRECTOR_PATH, "one original clock and Boss Director")
 check(sim.enemy_director.get_script().get_base_script().resource_path == PARENT_DIRECTOR_PATH, "Boss Director retains exact prior timed parent")
 check(admitted.capabilities.source_binding_id == FileAccess.get_sha256(Binding.BINDING_PATH), "one verified binding identity")
 check_owners(f, "startup")
 check(not session.initialize_floor(sim, loaded.definition, "second-binding-forbidden", true).get("accepted", false), "same Session cannot initialize a second run")
 check(not sim.bind_potion_model(model).get("accepted", false), "same Sim refuses a second potion owner")
 f.startup = startup.duplicate(true)
 return f

func check_model_successor(f: Dictionary, label: String) -> void:
 var script: Script = f.session.ledger.model.get_script()
 var prior: Script = script.get_base_script()
 check(prior != null and prior.resource_path == POSTBOSS_PRIOR_MODEL_PATH, label + ": exact terminal boundary Model remains the direct parent")
 var parent: Script = prior.get_base_script()
 check(script.resource_path == POSTBOSS_MODEL_PATH, label + ": exact postboss Model successor required")
 check(parent != null and parent.resource_path == POSTBOSS_BASE_MODEL_PATH, label + ": exactly one layer over original content01 Model")
 check(FileAccess.get_sha256(POSTBOSS_BASE_MODEL_PATH) == POSTBOSS_BASE_MODEL_SHA, label + ": original content01 Model SHA remains exact")

func enter(f: Dictionary, row: int) -> bool:
 if not choose_required_hexes(f): return false
 var node_id: String = POSTBOSS_ROUTE[row - 1]
 if not check(f.session.select_node(row, node_id).get("accepted", false), "select connected authored row " + node_id): return false
 var result: Dictionary = f.session.enter_selected_node()
 if not check(result.get("accepted", false), "enter through actual Session " + node_id + ": " + str(result.get("reason", ""))): return false
 check(f.session.fault.is_empty(), "no Session fault entering " + node_id)
 check_owners(f, "row " + str(row))
 f.identities.append({"row":row, "room_id":f.session.active_node_room, "generation":f.sim.encounter_generation, "identity":identity(f)})
 return true

func complete_rows(f: Dictionary, first_row: int, last_row: int) -> bool:
 for row: int in range(first_row, last_row + 1):
  if not enter(f, row): return false
  if f.session.status == "service":
   if not check(f.session.complete_service().get("accepted", false), "complete actual service row " + str(row)): return false
  elif not settle_fixture_combat(f): return false
 return true

func shop_command(f: Dictionary, action: String, extra: Dictionary = {}) -> Dictionary:
 serial += 1
 var args: Dictionary = f.session.ledger.model.commerce_token()
 args.merge(extra, true)
 var result: Dictionary = f.session.submit("postboss-shop-%d" % serial, action, args)
 f.session.update_after_source_step()
 return result

func held_item(f: Dictionary, item_id: String) -> Dictionary:
 for entry: Dictionary in f.session.ledger.model.state.inventory:
  if str(entry.id) == item_id: return entry.duplicate(true)
 return {}

func protected_potion_state(f: Dictionary) -> PackedByteArray:
 return var_to_bytes([f.session.ledger.model.state, f.session.ledger.model.potion_consumer.snapshot(), f.sim.hero.hp, f.sim.hero.stats, f.sim.phase, f.session.status])

func safe_potion_case(f: Dictionary) -> bool:
 current_group = POSTBOSS_GROUPS[1]
 # Five authentic authored rows earn the money; no funded wallet fixture.
 if not prepare_initial_choices(f) or not complete_rows(f, 1, 5) or not choose_required_hexes(f): return false
 if not check(f.session.open_panel().get("accepted", false), "post-row5 safe shop opens"): return false
 for index: int in range(2):
  if not check(shop_command(f, "buy", {"item":"potion:1"}).get("accepted", false), "buy potion %d using authenticated route gold" % (index + 1)): return false
 if not check(f.session.close_panel().get("accepted", false), "safe shop closes without committing its journal"): return false
 var held: Dictionary = held_item(f, "potion:1")
 if not check(not held.is_empty() and int(held.count) == 2, "two purchased same-tier bottles share the real UID"): return false
 f.potion_uid = int(held.uid)
 serial += 1
 f.potion_command_id = "postboss-safe-potion-%d" % serial
 var before_count: int = int(held.count)
 var used: Dictionary = f.session.ledger.model.use_potion(f.session, f.potion_command_id, f.potion_uid)
 if not check(used.get("accepted", false), "existing safe pre-drink still accepted: " + str(used.get("reason", ""))): return false
 var active: Array = f.session.ledger.model.potion_consumer.snapshot().active
 if not check(active.size() == 1 and int(held_item(f, "potion:1").get("count", 0)) == before_count - 1, "safe pre-drink consumes one bottle and creates one effect"): return false
 f.potion_effect_id = str(active[0].effect_id)
 var frozen: PackedByteArray = var_to_bytes(f.session.ledger.model.potion_consumer.snapshot())
 var hp: float = f.sim.hero.hp
 step(f, 120)
 check(frozen == var_to_bytes(f.session.ledger.model.potion_consumer.snapshot()) and hp == f.sim.hero.hp, "safe time does not advance combat-clock recovery")
 if not complete_rows(f, 6, 6): return false
 check(frozen == var_to_bytes(f.session.ledger.model.potion_consumer.snapshot()), "real training transition preserves pending pre-drink")
 if not enter(f, 7): return false
 # Small authentic source damage makes healing observable. Never write HP.
 var amount: float = minf(40.0, float(f.sim.hero.hp) * 0.1)
 fixture_packets.append({"target":"hero", "actor_id":f.sim.hero.actor_id, "run_id":f.session.run_id, "room_id":f.sim.room_id, "generation":f.sim.encounter_generation, "amount":amount, "purpose":"nonlethal source packet to observe next-combat potion healing"})
 f.sim.damage_hero(amount, Vector3.ZERO, 0.0, true, true, {"fixture":true, "direct":false, "damage_provenance":"postboss_potion_nonlethal_fixture"})
 step(f, 20)
 var advanced: Array = f.session.ledger.model.potion_consumer.snapshot().active
 if not check(advanced.size() == 1, "same pre-drink effect remains active after bounded next-combat steps"): return false
 check(str(advanced[0].effect_id) == f.potion_effect_id and float(advanced[0].left) < 4.0 and float(advanced[0].actual) > 0.0, "same effect advances and truly heals in next combat")
 check(not f.sim.hero.dead and f.sim.phase == "combat", "bounded potion check preserves living authentic combat")
 observations["safe_potion"] = {"request_id":f.potion_command_id, "uid":f.potion_uid, "effect":advanced[0].duplicate(true), "safe_use_result":used.duplicate(true), "funding":"verified authored kills only", "damage_fixture":true}
 if not settle_fixture_combat(f): return false
 complete_group(current_group)
 return true

func modal_changed(blocked: bool, f: Dictionary) -> void:
 # Headless wiring uses the same production InputGuard + Controller signal and
 # public Session API. It does not claim GUI Host/audio/native-input coverage.
 f.host.initial_guard.set_blocked(blocked)
 var result: Dictionary = f.session.set_modal_blocked(blocked)
 f.modal_receipts.append({"blocked":blocked, "result":result.duplicate(true), "guard_blocked":f.host.initial_guard.blocked, "session_modal":f.session.initial_modal_open, "source_paused":f.sim.paused})

func present_controller(f: Dictionary) -> void:
 f.controller.present_combat({"hp":f.sim.hero.hp, "hp_max":f.sim.hero.stats.max_hp, "stats":f.sim.hero.stats.duplicate(true), "phase":f.sim.phase, "room":f.sim.room_id})

func boss_modal_case(f: Dictionary) -> bool:
 current_group = POSTBOSS_GROUPS[2]
 if not traverse_to_boss(f, 8): return false
 var before: Dictionary = f.session.ledger.model.snapshot()
 check(before.level == 6 and before.xp == 89 and before.pending_milestones.is_empty(), "r10b route reaches Boss at Lv6/89XP with prior choices resolved")
 if wait_for_boss_warning(f).is_empty(): return false
 lethal_enemy_fixture(f, f.boss, "authored r10b route Boss death crossing original Lv7 milestone")
 for _tick: int in range(MAX_TERMINAL_TICKS):
  if f.session.status != "combat": break
  step(f)
 if not check(f.session.status == "completed" and f.sim.phase == "victory", "authentic source terminal completes the real Boss row"): return false
 var after: Dictionary = f.session.ledger.model.snapshot()
 if not check(after.level == 7 and after.xp == 24 and after.pending_milestones == [7], "original 160 Boss XP creates pending Lv7 choice at completed"): return false
 check(f.session.row_state.snapshot().completed_rows.size() == 12 and f.session.settlement.has("major_floor_event"), "all twelve authentic row receipts and original floor settlement exist")
 f.hud = f.host._make_floor_hud()
 root.add_child(f.hud)
 f.controller = PostbossController.new()
 f.modal_callback = modal_changed.bind(f)
 f.controller.gameplay_block_changed.connect(f.modal_callback)
 f.controller.bind_session(f.session, f.hud)
 present_controller(f)
 var held_key := InputEventKey.new()
 held_key.physical_keycode = KEY_Q; held_key.pressed = true
 f.host.initial_guard.observe(held_key)
 var world_time: float = f.sim.clock.world_time
 var hero_time: float = f.sim.hero_time
 f.controller.ensure_auto_hex()
 check(f.modal_receipts.size() == 1 and f.modal_receipts[0].blocked and f.modal_receipts[0].result.get("accepted", false), "completed Lv7 modal opening is accepted")
 check(f.hud.hex_required and f.hud.hex_draft.visible and f.hud.blocks_gameplay_input(), "original growth HUD shows the mandatory Lv7 offer")
 check(f.host.initial_guard.blocked and f.session.initial_modal_open and f.sim.paused, "HUD/InputGuard/Session/source agree on open modal")
 check(f.host.initial_guard.retired_keys.has(KEY_Q), "pre-modal held Q is retired by actual InputGuard")
 var repeated: Dictionary = f.session.set_modal_blocked(true)
 check(repeated.get("accepted", false), "duplicate completed modal-open is idempotently accepted")
 step(f, 30)
 check(f.sim.clock.world_time == world_time and f.sim.hero_time == hero_time and f.sim.phase == "victory", "open terminal modal cannot restart either source clock or combat")
 f.hud.adapter.request("hex_select", {"milestone":7, "slot":3})
 check(f.controller.last_result.get("accepted", false), "real Controller/Adapter selects actual Lv7 offered personal Hex")
 check(f.modal_receipts.size() == 2 and not f.modal_receipts[1].blocked and f.modal_receipts[1].result.get("accepted", false), "completed modal closing is accepted")
 check(not f.hud.hex_required and not f.hud.hex_draft.visible and not f.host.initial_guard.blocked and not f.session.initial_modal_open, "selection clears HUD/InputGuard/Session modal together")
 check(f.session.ledger.model.snapshot().pending_milestones.is_empty(), "actual Lv7 choice is resolved in the original ledger")
 held_key.pressed = false
 check(f.host.initial_guard.observe(held_key) and not f.host.initial_guard.retired_keys.has(KEY_Q), "held Q release is drained once after modal closes")
 repeated = f.session.set_modal_blocked(false)
 check(repeated.get("accepted", false), "duplicate completed modal-close is idempotently accepted")
 check(not f.session.explicit_resume().get("accepted", false), "completed Session still rejects explicit combat resume")
 check(not f.session.next_room_preflight().get("accepted", false), "completed Session offers no invented next room")
 step(f, 30)
 check(f.sim.clock.world_time == world_time and f.sim.hero_time == hero_time and f.sim.phase == "victory" and f.session.status == "completed", "closed terminal modal still cannot advance clocks or resume combat")
 check(f.event_errors.is_empty() and f.scope_errors.is_empty() and f.session.fault.is_empty(), "Boss and progression boundaries retain authentic event scope")
 observations["boss_modal"] = {"route":POSTBOSS_ROUTE, "before_level":before.level, "before_xp":before.xp, "after_level":after.level, "after_xp":after.xp, "modal_receipts":f.modal_receipts.duplicate(true), "controller_script":f.controller.get_script().resource_path, "hud_script":f.hud.get_script().resource_path, "gui_host_ready_executed":false}
 complete_group(current_group)
 return true

func completed_growth_shop_case(f: Dictionary) -> bool:
 current_group = POSTBOSS_GROUPS[3]
 var model = f.session.ledger.model
 check(f.session.safe_shop_reason().is_empty() and f.session.shop_location_reason().is_empty(), "completed remains an authorized safe growth and shop location")
 present_controller(f)
 var prior_rank: int = int(model.state.skills.Q.rank)
 var prior_points: int = int(model.state.points)
 check(not f.hud.q_choices.Q1.upgrade.disabled, "original Q1 growth button remains enabled after completion")
 f.hud.q_choices.Q1.upgrade.emit_signal("pressed")
 if not check(f.controller.last_result.get("accepted", false), "original growth button learns through the real Controller"): return false
 check(int(model.state.skills.Q.rank) == prior_rank + 1 and int(model.state.points) == prior_points - 1 and int(f.sim.hero.ranks.q) == prior_rank + 1, "completed learning spends exactly one earned SP and projects same Sim")
 f.hud.undo_button.emit_signal("pressed")
 check(f.controller.last_result.get("accepted", false) and int(model.state.skills.Q.rank) == prior_rank and int(model.state.points) == prior_points and int(f.sim.hero.ranks.q) == prior_rank, "completed skill undo restores only the new allocation")
 if not check(f.session.open_panel().get("accepted", false), "original shop opens after Boss completion"): return false
 var before_gold: int = int(model.state.gold)
 var before_inventory: PackedByteArray = var_to_bytes(model.state.inventory)
 var before_ap: float = float(f.sim.hero.stats.ap)
 var quote: Dictionary = model.commerce_quote("base:B02")
 if not check(quote.get("accepted", false), "real completed shop quotes existing AP component"): return false
 var bought: Dictionary = shop_command(f, "buy", {"item":"base:B02"})
 if not check(bought.get("accepted", false), "completed shop buys original equipment with earned gold"): return false
 check(int(model.state.gold) < before_gold and not held_item(f, "base:B02").is_empty() and float(f.sim.hero.stats.ap) > before_ap, "purchase changes inventory/gold and actual same-Sim equipment stats")
 var undo_before_close: PackedByteArray = var_to_bytes(model.state.shop_visit.undo)
 check(f.session.close_panel().get("accepted", false) and f.session.open_panel().get("accepted", false), "completed shop close/reopen remains accepted")
 check(undo_before_close == var_to_bytes(model.state.shop_visit.undo), "completed close/reopen preserves exact transaction journal")
 var undone: Dictionary = shop_command(f, "undo")
 check(undone.get("accepted", false) and int(model.state.gold) == before_gold and before_inventory == var_to_bytes(model.state.inventory) and is_equal_approx(float(f.sim.hero.stats.ap), before_ap), "completed equipment undo restores its gold/inventory/stats")
 check(f.session.close_panel().get("accepted", false), "completed shop closes after undo")
 check(f.session.status == "completed" and f.sim.phase == "victory", "growth and commerce never resurrect the run")
 check_owners(f, "completed growth/commerce")
 observations["completed_growth_shop"] = {"earned_points_before":prior_points, "rank_before":prior_rank, "purchase_result":bought.duplicate(true), "undo_result":undone.duplicate(true)}
 complete_group(current_group)
 return true

func completed_potion_case(f: Dictionary) -> bool:
 current_group = POSTBOSS_GROUPS[4]
 var model = f.session.ledger.model
 if not check(not held_item(f, "potion:1").is_empty(), "real unconsumed bottle remains available to exercise terminal denial"): return false
 check(not f.session.panel_open and not f.session.initial_modal_open and not f.sim.paused, "terminal potion probe has no unrelated panel/modal/pause blocker")
 var before: PackedByteArray = protected_potion_state(f)
 serial += 1
 var denied_id: String = "postboss-new-terminal-potion-%d" % serial
 var denied: Dictionary = model.use_potion(f.session, denied_id, f.potion_uid)
 check(not denied.get("accepted", false) and denied.get("reason", "") == "potion_run_finished", "completed new potion request is rejected specifically by the finished-run boundary")
 check(before == protected_potion_state(f), "terminal rejection preserves inventory/effects/undo/revision/HP")
 var denied_again: Dictionary = model.use_potion(f.session, denied_id, f.potion_uid)
 check(not denied_again.get("accepted", false) and before == protected_potion_state(f), "repeated terminal request cannot consume or seal a transaction")
 var replay: Dictionary = model.use_potion(f.session, f.potion_command_id, f.potion_uid)
 check(replay.get("accepted", false) and replay.get("replayed", false) and not replay.get("changed", true) and replay.get("events", []).is_empty(), "successful safe-use command still replays idempotently after completion")
 check(before == protected_potion_state(f), "successful terminal replay creates no second debit/heal/effect or undo seal")
 var conflict: Dictionary = model.use_potion(f.session, f.potion_command_id, int(f.potion_uid) + 100000)
 check(not conflict.get("accepted", false) and conflict.get("reason", "") == "command_id_conflict" and before == protected_potion_state(f), "prior command identity cannot be reused for another UID")
 check_model_successor(f, "terminal")
 check_owners(f, "terminal potion")
 observations["completed_potion"] = {"denied":denied.duplicate(true), "repeated_denial":denied_again.duplicate(true), "successful_replay":replay.duplicate(true), "uid_conflict":conflict.duplicate(true), "protected_state_equal":before == protected_potion_state(f)}
 complete_group(current_group)
 return true

func dispose(f: Dictionary) -> void:
 if not f.is_empty() and f.has("controller") and f.has("modal_callback") and f.controller.gameplay_block_changed.is_connected(f.modal_callback):
  f.controller.gameplay_block_changed.disconnect(f.modal_callback)
 if not f.is_empty() and f.has("hud") and is_instance_valid(f.hud): f.hud.free()
 super.dispose(f)

func run() -> void:
 current_group = POSTBOSS_GROUPS[0]
 if not check(FileAccess.get_sha256(FROZEN_PARENT) == FROZEN_PARENT_SHA, "frozen equipment content01 binding remains untouched"):
  finish(); return
 var f: Dictionary = fresh()
 if f.is_empty(): finish(); return
 observations["startup"] = {"state":f.startup, "identity":f.identity}
 complete_group(current_group)
 if safe_potion_case(f) and boss_modal_case(f):
  completed_growth_shop_case(f)
  completed_potion_case(f)
 dispose(f)
 finish()

func finish() -> void:
 current_group = "report"
 check(completed_groups == POSTBOSS_GROUPS, "all five post-Boss contract groups reached completion")
 check(check_records.size() == checks, "every check has a recorded outcome")
 check(not output_path.is_empty(), "post-Boss report path is nonempty")
 var file: FileAccess = null
 if not output_path.is_empty(): file = FileAccess.open(output_path, FileAccess.WRITE)
 check(file != null, "post-Boss JSON output can be written: " + output_path)
 var report: Dictionary = {"suite":"postboss_original_progression_contract", "passed":failures.is_empty() and completed_groups == POSTBOSS_GROUPS, "checks":checks, "failures":failures, "completed_groups":completed_groups, "required_groups":POSTBOSS_GROUPS, "check_records":check_records, "observations":observations, "fixture_packets":fixture_packets, "route":POSTBOSS_ROUTE, "source_binding_sha256":FileAccess.get_sha256(Binding.BINDING_PATH), "gate_sha256":FileAccess.get_sha256(POSTBOSS_GATE_PATH), "inherited_gate_sha256":FileAccess.get_sha256(GATE_PATH), "base_model_sha256":FileAccess.get_sha256(POSTBOSS_BASE_MODEL_PATH), "runtime_status":"EXECUTED", "ordinary_factory_session":true, "explicit_lethal_packets":true, "explicit_nonlethal_hero_packet":true, "direct_progression_or_HP_assignment":false, "headless_control_signals":true, "gui_host_ready_executed":false, "native_input":false, "natural_leveling":false, "natural_full_floor":false, "full_floor_verified":false, "art_accepted":false}
 if file != null:
  file.store_string(JSON.stringify(report, "  "))
  var write_error: Error = file.get_error()
  file.close()
  if write_error != OK:
   check(false, "post-Boss JSON write completed")
   report.checks = checks; report.failures = failures; report.check_records = check_records; report.passed = false
 print("POSTBOSS_CONTRACT ", JSON.stringify(report))
 quit(0 if report.passed else 1)
