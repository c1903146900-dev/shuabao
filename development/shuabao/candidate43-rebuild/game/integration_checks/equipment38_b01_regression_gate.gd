extends "res://integration_checks/equipment35_source_gate.gd"
## PREPARED source contract gate. Run only against the reviewed candidate07 seal.
## Host factories, seven original owners, exact route actors and original rewards.
## 60000 gold is the inherited, explicit testwallet fixture. All other changes
## use original commerce/input/cast/damage APIs. No HP/rank/inventory/AI writes.
const B01_MODEL := "res://equipment_kill_20261009/model.gd"
const B01_NUMERIC := "res://tests/equipment_editable_tables_20261004/outputs/equipment_tables/converted/equipment_numeric_config.json"
const B01Prior = preload("res://equipment_distance_20261009/adapter.gd")
const B01Passive = preload("res://equipment_kill_20261009/passive13.gd")
const B01_ROUTE := ["r01c", "r02c", "r03c", "r04c", "r05b", "r06b", "r07c", "r08c", "r09b", "r10c", "r11b", "r12boss"]
const B01_ROSTER_COUNTS := [6, 4, 0, 6, 3, 0, 6, 4, 4, 6, 0, 1]
const B01_GROUPS := ["definitions_and_commerce", "unequipped", "unique_cast_and_zero_cd", "rejected_attribution", "actual_q1_input", "forty_original_enemies"]
var b01_groups: Array[String] = []

func _initialize() -> void:
 output_path = "user://equipment36_source_gate.json"
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--equipment-result="): output_path = argument.trim_prefix("--equipment-result=")
 run.call_deferred()

func check_model_successor(f: Dictionary, label: String) -> void:
 var script: Script = f.session.ledger.model.get_script()
 for path: String in ["res://equipment_basic_cycle_20261009/model.gd", "res://equipment_elite_damage_20261009/model.gd", B01_MODEL, DISTANCE_MODEL_PATH, POSTBOSS_MODEL_PATH, POSTBOSS_PRIOR_MODEL_PATH, POSTBOSS_BASE_MODEL_PATH]:
  if not check(script != null and script.resource_path == path, label + ": exact equipment36 ancestor " + path): return
  script = script.get_base_script()
 check(FileAccess.get_sha256(POSTBOSS_BASE_MODEL_PATH) == POSTBOSS_BASE_MODEL_SHA, label + ": frozen original Model SHA retained")

func funded_shop(label: String) -> Dictionary:
 var f: Dictionary = super.funded_shop(label)
 if f.is_empty(): return {}
 if not check(f.session.ledger.model.get_script().resource_path == "res://equipment_basic_cycle_20261009/model.gd" and f.sim.has_method("verify_b01_kill_attribution"), "reviewed B01 source bridge exists"):
  dispose(f); return {}
 if not check(f.session.ledger.model.equipment_runtime_status("final:B01").get("runtime_complete", false), "B01 runtime bound through real factory"):
  dispose(f); return {}
 f["live_kills"] = []
 return f

func on_event(event: Dictionary, f: Dictionary) -> void:
 # Read the witness while the original damage frame is live. Never submit a
 # hand-built positive event. The inherited observer alone calls the Session.
 var attribution: Dictionary = {}
 if event.get("kind", "") == "kill" and f.sim.has_method("verify_b01_kill_attribution"):
  attribution = f.sim.verify_b01_kill_attribution(event)
 super.on_event(event, f)
 if event.get("kind", "") == "kill" and f.has("live_kills"):
  f.live_kills.append({"event":event.duplicate(true), "live_attribution":attribution.duplicate(true), "task_after":task_state(f)})

func task_state(f: Dictionary) -> Dictionary:
 return f.session.ledger.model.snapshot().get("b01_equipment", {}).duplicate(true)

func task_ledger(f: Dictionary) -> Dictionary:
 var state: Dictionary = f.session.ledger.model.state
 return state.shop_visit.taskLedger.get(str(state.actor_id) + "|final:B01", {}).duplicate(true)

func protected_task(f: Dictionary) -> Dictionary:
 var state: Dictionary = f.session.ledger.model.state
 return {"task":task_state(f), "ledger":task_ledger(f), "points":state.points, "bonus_sp":state.bonus_sp, "awards":state.bonus_awards.duplicate(true), "completed":state.completed_equipment_tasks.duplicate(true)}

func mark_group() -> void:
 check(current_group in B01_GROUPS and current_group not in b01_groups, "unique source group " + current_group)
 b01_groups.append(current_group)

func enter(f: Dictionary, row: int) -> bool:
 if not choose_required_hexes(f): return false
 var node_id: String = B01_ROUTE[row - 1]
 if not check(f.session.select_node(row, node_id).get("accepted", false), "select original connected node " + node_id): return false
 var result: Dictionary = f.session.enter_selected_node()
 if not check(result.get("accepted", false), "enter actual node " + node_id + ": " + str(result.get("reason", ""))): return false
 check_owners(f, node_id)
 check(f.sim.ai_enabled and f.sim.auto_finish, "original AI and terminal remain enabled at " + node_id)
 if int(B01_ROSTER_COUNTS[row - 1]) == 0:
  return check(f.session.status == "service", "original service row " + node_id)
 var expected: Array = f.session.expected_enemies.duplicate()
 check(expected.size() == int(B01_ROSTER_COUNTS[row - 1]) and f.sim.enemies.size() == expected.size(), "exact original roster count at " + node_id)
 for enemy: Dictionary in f.sim.enemies:
  check(str(enemy.actor_id) in expected and int(enemy.generation) == f.sim.encounter_generation and str(enemy.room_id) == f.sim.room_id, "only entered actor " + str(enemy.actor_id))
 f.identities.append({"node":node_id, "row":row, "room":f.sim.room_id, "generation":f.sim.encounter_generation, "expected_enemies":expected, "identity":identity(f)})
 return check(f.session.fault.is_empty(), "no entry fault at " + node_id)

func spawn_ready(f: Dictionary) -> bool:
 for _tick: int in range(100):
  var pending_spawn: bool = false
  for enemy: Dictionary in f.sim.living():
   if enemy.state == "spawn": pending_spawn = true
  if not pending_spawn: break
  step(f)
 for enemy: Dictionary in f.sim.enemies:
  if not check(not enemy.dead and enemy.state != "spawn", "original spawn grace ends alive: " + str(enemy.actor_id)): return false
 return check(f.sim.phase == "combat" and not f.sim.paused and not f.sim.hero.dead, "live source combat after original spawn grace")

func combat_fixture(copies: int, label: String) -> Dictionary:
 var f: Dictionary = funded_shop(label)
 if f.is_empty(): return {}
 for _copy: int in range(copies):
  if not buy(f, "final:B01"): dispose(f); return {}
 if not check(f.session.close_panel().get("accepted", false), "original shop closes") or not enter(f, 1) or not spawn_ready(f):
  dispose(f); return {}
 return f

func fixture_cast(f: Dictionary, slot: String, base_cooldown: float = 10.0) -> Dictionary:
 # Source API packet fixture: this does not claim an actual Q1/E1 input cast.
 var context: Dictionary = f.sim.new_cast(slot, "equipment36_source_api_fixture")
 f.sim.start_skill_cooldown(slot, base_cooldown)
 evidence.cooldown_fixtures.append({"cast_id":context.cast_id, "slot":slot, "base_cooldown":base_cooldown, "actual_current_cooldown":f.sim.hero.cooldowns[slot], "method":"original start_skill_cooldown", "actual_skill_input":false})
 return context

func packet(f: Dictionary, enemy: Dictionary, context: Dictionary, source: String, flags: Dictionary = {}) -> Dictionary:
 var metadata: Dictionary = {"fixture":true, "active_skill":true, "direct":true, "no_reactions":true, "generation":f.sim.encounter_generation, "room_id":f.sim.room_id}
 metadata.merge(flags, true)
 var slot: String = str(context.slot)
 var before: Dictionary = protected_task(f)
 var cooldown: float = float(f.sim.hero.cooldowns.get(slot, 0.0))
 var hp: float = float(enemy.hp)
 var start: int = f.events.size()
 var amount: float = hp + 100000.0
 var killed: bool = f.sim.damage_enemy(enemy, amount, source, int(context.cast_id), true, false, metadata)
 var record: Dictionary = {"fixture":"source_API_packet_not_actual_skill_input", "actor_id":enemy.actor_id, "expected_roster":str(enemy.actor_id) in f.session.expected_enemies, "source":source, "cast_id":context.cast_id, "slot":slot, "amount":amount, "metadata":metadata, "killed":killed, "hp_before":hp, "hp_after":enemy.hp, "cooldown_before":cooldown, "cooldown_after":f.sim.hero.cooldowns.get(slot, 0.0), "before":before, "after":protected_task(f), "emitted":f.events.slice(start)}
 evidence.packets.append(record)
 return record

func assert_task(f: Dictionary, progress: int, completed: bool, label: String) -> void:
 var current: Dictionary = task_state(f)
 check(int(current.get("progress", -1)) == progress and bool(current.get("completed", false)) == completed, label + ": task progress/completion")
 var ledger: Dictionary = task_ledger(f)
 if progress == 0:
  check(ledger.is_empty(), label + ": no unearned task_effect receipt")
 else:
  check(int(ledger.get("progress", -1)) == progress and ledger.get("event_ids", []).size() == progress, label + ": original task_effect ledger has one event per enemy")
  check(ledger.get("completed_stages", []) == (["task:B01:1"] if completed else []), label + ": original stage recorded once")
  var rewards: Dictionary = ledger.get("permanent_rewards", {})
  check(rewards.size() == (1 if completed else 0) and (not completed or rewards.has("task:B01:permanent_sp")), label + ": unique original permanent reward receipt")
 check(int(f.session.ledger.model.state.bonus_sp) == (1 if completed else 0), label + ": permanent SP exactly once")

func assert_b01_stats(f: Dictionary, copies: int, label: String) -> void:
 var now: Dictionary = authority(f)
 for row: Array in [["AD", "ad", 60.0], ["cooldown_reduction", "cdr", 0.18], ["penetration", "penetration", 16.0]]:
  var expected: float = float(row[2]) * copies
  near_number(float(now.equipment.stats.get(row[0], 0.0)) - float(f.baseline.equipment.stats.get(row[0], 0.0)), expected, label + ": per-copy equipment " + str(row[0]))
  near_number(float(now.aggregate.stats.get(row[0], 0.0)) - float(f.baseline.aggregate.stats.get(row[0], 0.0)), expected, label + ": same authoritative aggregate " + str(row[0]))
  var total: float = float(f.baseline.current_sim_stats[row[1]]) + expected
  if row[1] == "cdr": total = minf(0.65, total)
  near_number(float(now.current_sim_stats[row[1]]), total, label + ": original stat consumer " + str(row[1]))
 var selected: Dictionary = B01Passive.select_unique(f.session.ledger.model.state.inventory, f.session.ledger.model.runtime_stat_definitions)
 check(owned_count(f, "final:B01") == copies and int(selected.owned_copies) == copies and bool(selected.equipped) == (copies > 0), label + ": original inventory selects unique passive13")

func definitions_commerce_case() -> void:
 current_group = B01_GROUPS[0]
 var f: Dictionary = funded_shop(current_group)
 if f.is_empty(): return
 var model = f.session.ledger.model
 var numeric: Variant = JSON.parse_string(FileAccess.get_file_as_string(B01_NUMERIC))
 if not check(numeric is Dictionary, "authored numeric table readable"): dispose(f); return
 var prior: Dictionary = B01Prior.build(numeric)
 if not check(prior.get("accepted", false), "original35 adapter accepts original table"): dispose(f); return
 check(model.runtime_stat_definitions.size() == prior.definitions.size() + 3, "exact B01/G06/B04 additions to prior35")
 for item_id: String in prior.definitions:
  check(var_to_bytes(prior.definitions[item_id]) == var_to_bytes(model.runtime_stat_definitions.get(item_id, {})), "original35 definition deeply unchanged: " + item_id)
 var supported: int = 0
 for definition: Dictionary in model.runtime_stat_definitions.values():
  if definition.get("supported", false): supported += 1
 check(supported == 38 and model.snapshot().content_profile == "ordinary_equipment38_potions3", "exact supported38 and truthful profile")
 var b01: Dictionary = model.equipment_runtime_status("final:B01")
 check(b01.stats == {"AD":60.0, "cooldown_reduction":0.18, "penetration":16.0}, "original B01 AD60/CDR18%/penetration16")
 check(b01.passives == ["passive:13"] and b01.passive13 == {"cooldown_refund":35.0}, "one original passive13 with 35% current-CD refund")
 check(int(b01.taskB01.threshold) == 40 and int(b01.taskB01.reward_skill_points) == 1, "original40 kills grants permanent1SP")
 check(int(model.commerce_definitions.items["final:B01"].price) == 3200, "original B01 price3200")
 assert_b01_stats(f, 0, "empty")
 var gold_before: int = int(model.state.gold)
 if not buy(f, "final:B01"): dispose(f); return
 check(int(model.state.gold) == gold_before - 3200, "original commerce charges exact3200")
 assert_b01_stats(f, 1, "one")
 buy(f, "final:B01"); assert_b01_stats(f, 2, "two")
 var stable: Dictionary = authority(f)
 for _sync: int in range(4): f.sim.refresh_passive23(); f.session.update_after_source_step()
 check(stable == authority(f), "repeated original stat synchronization is idempotent")
 sell(f, "final:B01"); sell(f, "final:B01"); assert_b01_stats(f, 0, "sold last")
 undo(f); undo(f); assert_b01_stats(f, 2, "sale undo")
 undo(f); undo(f); assert_b01_stats(f, 0, "purchase undo")
 assert_task(f, 0, false, "commerce alone")
 var denied: Dictionary = command(f, "b01_verified_kill", {"progress":40, "reward_skill_points":1})
 check(not denied.get("accepted", false) and denied.get("reason", "") == "b01_verified_live_kill_required", "public Model command cannot mint source entitlement")
 check_owners(f, current_group)
 evidence.commerce.append({"case":current_group, "final":protected_task(f)})
 dispose(f); mark_group()

func unequipped_case() -> void:
 current_group = B01_GROUPS[1]
 var f: Dictionary = combat_fixture(0, current_group)
 if f.is_empty(): return
 var context: Dictionary = fixture_cast(f, "q")
 var result: Dictionary = packet(f, f.sim.enemies[0], context, "q1")
 check(result.killed and not f.live_kills.back().live_attribution.is_empty(), "real attributed Q source kill without B01")
 near_number(result.cooldown_after, result.cooldown_before, "unequipped never refunds")
 assert_task(f, 0, false, "unequipped kill")
 check(task_state(f).get("refund_claims", {}).is_empty(), "unequipped kill never consumes B01 claim")
 check(f.event_errors.is_empty(), "unequipped original kill remains authenticated")
 dispose(f); mark_group()

func unique_cast_case() -> void:
 current_group = B01_GROUPS[2]
 var f: Dictionary = combat_fixture(2, current_group)
 if f.is_empty(): return
 var q: Dictionary = fixture_cast(f, "q")
 var first: Dictionary = packet(f, f.sim.enemies[0], q, "q1")
 near_number(first.cooldown_after, first.cooldown_before * 0.65, "two equipped copies refund current Q exactly35% once")
 var second: Dictionary = packet(f, f.sim.enemies[1], q, "q1")
 near_number(second.cooldown_after, first.cooldown_after, "same original cast second enemy has no second refund")
 assert_task(f, 2, false, "same cast two distinct enemies")
 check(task_state(f).refund_claims.size() == 1 and events_of(f, "equipment_b01_refund").size() == 1, "one Q claim and one refund event")
 var frozen: Dictionary = protected_task(f)
 packet(f, f.sim.enemies[0], q, "q1")
 check(protected_task(f) == frozen, "same dead enemy retry cannot add progress or refund")
 var e: Dictionary = fixture_cast(f, "e", 0.0)
 var zero: Dictionary = packet(f, f.sim.enemies[2], e, "e1")
 near_number(zero.cooldown_after, 0.0, "zero remaining E cooldown remains zero")
 check(task_state(f).refund_claims.size() == 2 and events_of(f, "equipment_b01_refund").size() == 2, "zero-CD E kill still consumes exactly one cast claim")
 # Re-arm only the original source cooldown API to expose any banked refund.
 f.sim.start_skill_cooldown("e", 10.0)
 var late: Dictionary = packet(f, f.sim.enemies[3], e, "e1")
 near_number(late.cooldown_after, late.cooldown_before, "same zero-CD-claimed cast cannot refund a later cooldown")
 assert_task(f, 4, false, "two copies count exactly four unique kills")
 check(events_of(f, "equipment_b01_refund").size() == 2 and f.event_errors.is_empty(), "exact Q/E refunds and authentic original kills")
 evidence.cases.append({"case":current_group, "task":protected_task(f), "live_kills":f.live_kills.duplicate(true)})
 dispose(f); mark_group()

func rejected_attribution_case() -> void:
 current_group = B01_GROUPS[3]
 var f: Dictionary = combat_fixture(2, current_group)
 if f.is_empty(): return
 var q: Dictionary = fixture_cast(f, "q")
 var target: Dictionary = f.sim.enemies[5]
 for flags: Dictionary in [{"generation":f.sim.encounter_generation + 1}, {"room_id":"not-the-current-room"}]:
  var refused: Dictionary = packet(f, target, q, "q1", flags)
  check(not refused.killed and refused.hp_before == refused.hp_after and refused.before == refused.after, "foreign packet scope rejected without mutation")
 var cancelled: Dictionary = fixture_cast(f, "q")
 f.sim.cancel_cast(int(cancelled.cast_id))
 var invalid: Dictionary = packet(f, target, cancelled, "q1")
 check(not invalid.killed and invalid.before == invalid.after and invalid.hp_before == invalid.hp_after, "cancelled source cast cannot kill or progress")
 var rows: Array = [["attack", "attack", {"basic_attack":true, "active_skill":false}], ["r", "r1", {}], ["q", "q1", {"replay":true}], ["q", "q1", {"hex_generated":true}], ["q", "q1", {"p2_generated":true}], ["q", "q1", {"active_skill":false}]]
 for index: int in range(rows.size()):
  var row: Array = rows[index]
  var context: Dictionary = fixture_cast(f, row[0])
  var result: Dictionary = packet(f, f.sim.enemies[index], context, row[1], row[2])
  check(result.killed, "negative fixture is an actual original enemy kill: " + str(row))
  near_number(result.cooldown_after, result.cooldown_before, "excluded attribution never refunds: " + str(row))
  assert_task(f, 0, false, "excluded " + str(row))
 # Public emit_event can mimic the name/ID and reuse a dead actor. It has no
 # live original damage witness, even though the source event log records it.
 var before: Dictionary = protected_task(f)
 var gold: int = int(f.session.ledger.model.state.gold)
 f.sim.emit_event("kill", {"target":f.sim.enemies[0].actor_id, "source":"q1", "cast_id":q.cast_id, "credit":"solo_lethal", "enemy_kind":f.sim.enemies[0].kind})
 check(protected_task(f) == before and int(f.session.ledger.model.state.gold) == gold, "forged public emit cannot convert prior BASIC death into Q task/refund/reward")
 check(f.live_kills.back().live_attribution.is_empty() and events_of(f, "equipment_b01_refund").is_empty(), "fake emit and all excluded sources have no B01 receipt")
 check(f.event_errors.is_empty(), "negative attribution leaves existing reward authority consistent")
 evidence.cases.append({"case":current_group, "live_kills":f.live_kills.duplicate(true), "task":protected_task(f)})
 dispose(f); mark_group()

func actual_q1_input_case() -> void:
 current_group = B01_GROUPS[4]
 var f: Dictionary = funded_shop(current_group)
 if f.is_empty(): return
 if not buy(f, "final:B01"): dispose(f); return
 for _copy: int in range(4):
  if not buy(f, "final:C06"): dispose(f); return
 if not check(f.session.close_panel().get("accepted", false), "actual-input shop closes") or not enter(f, 1) or not spawn_ready(f): dispose(f); return
 var target: Dictionary = {}
 for enemy: Dictionary in f.sim.enemies:
  if str(enemy.kind) == "minion" and Vector3(enemy.position).distance_to(f.sim.hero.position) < 9.0:
   target = enemy; break
 if not check(not target.is_empty(), "an original damageable minion is within legal Q1 placement"): dispose(f); return
 var start: Vector3 = Vector3(target.position) + Vector3(0.0, 0.0, 0.15)
 var endpoint: Vector3 = Vector3(target.position) + Vector3(0.0, 0.0, -1.5)
 var before_count: int = f.live_kills.size()
 var rank: int = int(f.sim.hero.ranks.q)
 check(rank == 1 and f.sim.hero.loadout.q == "q1", "original initial-SP Q1 rank1 retained")
 if not check(f.sim.request_ink_input("q_down").get("accepted", false), "real Q1 q_down") or not check(f.sim.request_ink_input("left_down", start).get("accepted", false), "real Q1 legal start"):
  dispose(f); return
 check(f.sim.request_ink_input("motion", endpoint).get("accepted", false), "real Q1 source motion")
 var released: Dictionary = f.sim.request_ink_input("left_up", endpoint)
 if not check(released.get("accepted", false), "real Q1 release"): dispose(f); return
 for _tick: int in range(80):
  if target.dead or f.sim.phase != "combat": break
  step(f)
 var actual: Array = []
 for observation: Dictionary in f.live_kills.slice(before_count):
  if observation.event.source == "q1": actual.append(observation)
 check(target.dead and not actual.is_empty(), "actual rank1 Q1 wave kills original enemy with purchased AP")
 var refunds: Array = events_of(f, "equipment_b01_refund")
 check(refunds.size() == 1, "actual Q1 produces exactly one source-live refund")
 if not refunds.is_empty():
  near_number(float(refunds[0].cooldown_after), float(refunds[0].cooldown_before) * 0.65, "actual Q1 samples CD in kill frame")
  check(float(refunds[0].cooldown_before) > 0.0, "actual Q1 refund is nonzero")
 for observation: Dictionary in actual:
  check(not observation.live_attribution.is_empty() and observation.live_attribution.parent_skill == "q1", "live Q1 damage frame verifies original cast")
  check(f.sim.verify_b01_kill_attribution(observation.event).is_empty(), "Q1 event outside its completed damage frame cannot replay entitlement")
 assert_task(f, actual.size(), false, "actual Q1 unique original targets")
 check(f.sim.ai_enabled and not f.sim.hero.dead and f.event_errors.is_empty(), "real input check retains enabled AI and authentic events")
 check_owners(f, current_group)
 evidence.actual_q1 = {"actual_skill_input":true, "native_gui_input":false, "testwallet_and_purchased_ap_fixture":true, "rank":rank, "ap":f.sim.hero.stats.ap, "release":released, "original_target":target.actor_id, "live_kills":actual, "refunds":refunds}
 dispose(f); mark_group()

func sale_repurchase_retention(f: Dictionary, progress: int, completed: bool) -> bool:
 if not choose_required_hexes(f) or not check(f.session.open_panel().get("accepted", false), "safe retention shop opens"): return false
 var before: Dictionary = protected_task(f)
 for _copy: int in range(2):
  if not sell(f, "final:B01"): return false
 check(owned_count(f, "final:B01") == 0 and protected_task(f) == before, "selling last copy retains all progress and permanent reward")
 for _copy: int in range(2):
  if not buy(f, "final:B01"): return false
 check(protected_task(f) == before, "rebuy never resets progress or grants another reward")
 for _copy: int in range(2):
  if not undo(f): return false
 check(owned_count(f, "final:B01") == 0 and protected_task(f) == before, "undo repurchases cannot wash task or permanent SP")
 for _copy: int in range(2):
  if not undo(f): return false
 check(owned_count(f, "final:B01") == 2 and protected_task(f) == before, "undo sales restores items while retaining original task receipts")
 assert_task(f, progress, completed, "sale/rebuy/undo retention")
 evidence.commerce.append({"case":"retention", "progress":progress, "completed":completed, "before":before, "after":protected_task(f)})
 return check(f.session.close_panel().get("accepted", false), "retention shop closes")

func settle_original_row(f: Dictionary, row: int) -> bool:
 for _tick: int in range(MAX_TERMINAL_TICKS):
  if f.session.status != "combat": break
  step(f)
 var expected_status: String = "completed" if row == 12 else "between_rooms"
 check(f.session.kill_receipts.size() == int(B01_ROSTER_COUNTS[row - 1]), "one original reward receipt for every entered actor")
 return check(f.sim.phase == "victory" and f.session.status == expected_status and f.session.fault.is_empty() and f.event_errors.is_empty(), "original terminal settles row " + str(row))

func forty_enemy_case() -> void:
 current_group = B01_GROUPS[5]
 var f: Dictionary = funded_shop(current_group)
 if f.is_empty(): return
 if not buy(f, "final:B01") or not buy(f, "final:B01"): dispose(f); return
 if not check(f.session.close_panel().get("accepted", false), "forty-enemy original shop closes"): dispose(f); return
 var count: int = 0
 var expected_gold: int = int(f.session.ledger.model.state.gold)
 var last_kill: Dictionary = {}
 for row: int in range(1, 13):
  if not enter(f, row): dispose(f); return
  if f.session.status == "service":
   if not check(f.session.complete_service().get("accepted", false), "original service completes row " + str(row)): dispose(f); return
   continue
  if not spawn_ready(f): dispose(f); return
  var context: Dictionary = fixture_cast(f, "q" if row % 2 == 1 else "e")
  var source: String = "q1" if context.slot == "q" else "e1"
  var expected_refund: float = float(f.sim.hero.cooldowns[context.slot]) * 0.65
  for enemy: Dictionary in f.sim.enemies.duplicate():
   var model = f.session.ledger.model
   var points_before: int = int(model.state.points)
   var levels_before: int = model.state.granted_level_ids.size()
   var refund_count: int = events_of(f, "equipment_b01_refund").size()
   var reward: Dictionary = model.reward_for_kind(str(enemy.kind))
   if not check(reward.get("accepted", false), "original actor has authored reward"): dispose(f); return
   if count == 39: assert_task(f, 39, false, "before final original Boss kill")
   var result: Dictionary = packet(f, enemy, context, source)
   if not check(result.killed and not f.live_kills.back().live_attribution.is_empty(), "source packet kills only original attributed actor"): dispose(f); return
   count += 1
   expected_gold += int(reward.gold)
   check(int(model.state.gold) == expected_gold, "authored reward gold plus explicitly funded wallet remains exact")
   var leveling_sp: int = model.state.granted_level_ids.size() - levels_before
   check(int(model.state.points) - points_before == leveling_sp + (1 if count == 40 else 0), "kill " + str(count) + " grants original level SP plus only threshold bonus")
   assert_task(f, count, count == 40, "original kill " + str(count))
   near_number(float(f.sim.hero.cooldowns[context.slot]), expected_refund, "same-room cast refunds only once across all original targets")
   check(events_of(f, "equipment_b01_refund").size() <= refund_count + 1, "duplicate equipment never emits multiple per-kill refunds")
   last_kill = f.live_kills.back().event.duplicate(true)
   var saved: Dictionary = protected_task(f)
   var replay: Dictionary = f.session.observe_event(f.sim, last_kill)
   check(replay.get("accepted", false) and protected_task(f) == saved and int(model.state.gold) == expected_gold, "same authentic kill replay cannot add task/SP/gold")
  if not settle_original_row(f, row): dispose(f); return
  if row == 1 and not sale_repurchase_retention(f, 6, false): dispose(f); return
 check(count == 40 and f.session.row_state.snapshot().completed_rows.size() == 12, "exact original connected twelve-row route contains40 actors")
 assert_task(f, 40, true, "original Boss reaches threshold40")
 check(f.session.ledger.model.state.completed_equipment_tasks.has("final:B01") and int(f.session.ledger.model.state.bonus_awards.get("task:B01", {}).get("amount", 0)) == 1, "single authored completion and bonus award remain in same Model")
 if not sale_repurchase_retention(f, 40, true): dispose(f); return
 var saved: Dictionary = protected_task(f)
 var terminal_replay: Dictionary = f.session.observe_event(f.sim, last_kill)
 check(not terminal_replay.get("accepted", false) and protected_task(f) == saved, "completed Session rejects kill replay without resetting reward")
 check_owners(f, current_group)
 evidence.forty_route = {"route":B01_ROUTE, "roster_counts":B01_ROSTER_COUNTS, "actual_original_kills":count, "route_receipts":f.session.row_state.snapshot(), "identities":f.identities.duplicate(true), "task":protected_task(f), "last_kill":last_kill, "post40_new_actor_spawned":false, "post40_coverage":"authentic kill replay and original sale/rebuy/undo only; floor has no remaining actor", "natural_full_floor":false}
 dispose(f); mark_group()

func run() -> void:
 evidence = {"wallet_fixtures":[], "commerce":[], "cooldown_fixtures":[], "packets":[], "cases":[], "actual_q1":{}, "forty_route":{}}
 definitions_commerce_case()
 unequipped_case()
 unique_cast_case()
 rejected_attribution_case()
 actual_q1_input_case()
 forty_enemy_case()
 finish()

func finish() -> void:
 check(b01_groups == B01_GROUPS, "all six required B01 source groups reached")
 check(check_records.size() == checks, "every assertion retained")
 var report: Dictionary = {"suite":"equipment36_b01_source_gate", "passed":failures.is_empty() and b01_groups == B01_GROUPS, "runtime_status":"EXECUTED", "checks":checks, "failures":failures, "check_records":check_records, "completed_groups":b01_groups, "required_groups":B01_GROUPS, "evidence":evidence, "source_binding_sha256":FileAccess.get_sha256(Binding.BINDING_PATH), "testwallet_fixture":true, "source_API_packet_fixture":true, "actual_q1_input_case_included":true, "original_factory_session":true, "extra_spawned_targets_fixture":false, "natural_play":false, "natural_full_floor":false, "native_gui_input":false, "p1_supplement_case_covered":false, "h04_original_packet_case_covered":false, "remaining_cases":["P1 original finished-cast supplement lethal attribution and existing P1/B01 cooldown ordering", "H04 original Q2 source witness, same original cast identity and per-enemy task counting"]}
 var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
 if file == null:
  push_error("Unable to write equipment36 result: " + output_path); quit(2); return
 file.store_string(JSON.stringify(report, "  "))
 var write_error: Error = file.get_error()
 file.close()
 print("EQUIPMENT36_SOURCE ", JSON.stringify(report))
 quit(2 if write_error != OK else (0 if report.passed else 1))
