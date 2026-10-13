extends "res://integration_checks/equipment36_source_gate.gd"
## PREPARED ONLY. The author never runs an engine or GUI. The parent must seal
## candidate08 and run this entry serially before any execution/pass claim.
## Real Host/Session/ledger source gate; explicit wallet, source-packet and
## spawn_enemy(hp_override) fixtures are reported separately from real Q1/P1.
const G06_MODEL := "res://equipment_elite_damage_20261009/model.gd"
const G06Prior = preload("res://equipment_kill_20261009/adapter.gd")
const G06Design = preload("res://data/final_design/catalog.gd")
const G06_GROUPS := ["definitions_and_commerce", "unequipped_and_a05", "actual_damage_and_reentrancy", "fractional_threshold_and_evolution", "actual_q1_p1_and_original_shop", "evolved_snapshot_commerce_fixture", "nested_source_verifier_fixtures"]
const G06_HP := 1000000.0
const G06_EPSILON := 0.0000001
var g06_groups: Array[String] = []
var g06_evolved_source: Dictionary = {}

class G06NestedSource extends "res://tests/ink_river_hexes_20261006/ordinary01/sim.gd":
 # Isolated verifier fixture only. Inject timing at the original outgoing hook;
 # all packet amounts still run through the inherited actual damage core.
 var fixture_plan: Dictionary = {}
 func _hero_outgoing_damage(enemy: Dictionary, amount: float, source: String, cast_id: int, is_true: bool, metadata: Dictionary) -> float:
  if source == "equipment37_isolated_outer" and not fixture_plan.get("outer_fired", false):
   fixture_plan.outer_fired = true
   var target: Dictionary = fixture_plan.second if fixture_plan.mode == "other_target_middle" else fixture_plan.first
   damage_enemy(target, 2.0, "equipment37_isolated_middle", 0, true, false, {"fixture":true, "direct":false, "active_skill":false, "generation":encounter_generation, "room_id":room_id})
  elif source == "equipment37_isolated_middle" and fixture_plan.mode != "middle_callback_under_outer" and not fixture_plan.get("inner_fired", false):
   fixture_plan.inner_fired = true
   damage_enemy(fixture_plan.first, 4.0, "equipment37_isolated_inner", 0, true, false, {"fixture":true, "direct":false, "no_reactions":true, "generation":encounter_generation, "room_id":room_id})
  return super._hero_outgoing_damage(enemy, amount, source, cast_id, is_true, metadata)

func _initialize() -> void:
 output_path = "user://equipment37_source_gate.json"
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--equipment-result="): output_path = argument.trim_prefix("--equipment-result=")
 run.call_deferred()

func check_model_successor(f: Dictionary, label: String) -> void:
 var script: Script = f.session.ledger.model.get_script()
 for path: String in [G06_MODEL, B01_MODEL, DISTANCE_MODEL_PATH, POSTBOSS_MODEL_PATH, POSTBOSS_PRIOR_MODEL_PATH, POSTBOSS_BASE_MODEL_PATH]:
  if not check(script != null and script.resource_path == path, label + ": exact equipment37 Model ancestor " + path): return
  script = script.get_base_script()
 check(FileAccess.get_sha256(POSTBOSS_BASE_MODEL_PATH) == POSTBOSS_BASE_MODEL_SHA, label + ": frozen original Model SHA retained")

func funded_shop(label: String) -> Dictionary:
 # equipment36.funded_shop pins B01 as the leaf; reproduce only equipment35's
 # fixture setup so every original fresh()/owner/admission check still runs.
 var f: Dictionary = fresh()
 if f.is_empty(): return {}
 if not prepare_initial_choices(f): dispose(f); return {}
 var model = f.session.ledger.model
 f.baseline = authority(f)
 f["g06_damage"] = []
 f["g06_targets"] = []
 f["g06_attack"] = {}
 f["g06_attack_records"] = []
 evidence.wallet_fixtures.append({"case":label, "run_id":f.session.run_id, "before":model.state.gold, "after":60000, "test_only":true, "production_default_unchanged":true})
 model.state.gold = 60000 # The inherited explicit wallet fixture only.
 if not check(model.get_script().resource_path == G06_MODEL and f.sim.has_method("verify_g06_damage_attribution"), "exact G06 Model/source bridge") or not check(model.equipment_runtime_status("final:G06").get("runtime_complete", false), "G06 runtime bound through original factory") or not check(f.session.open_panel().get("accepted", false), label + ": original safe shop opens"):
  dispose(f); return {}
 return f

func g06_task(f: Dictionary) -> Dictionary:
 return f.session.ledger.model.snapshot().get("g06_equipment", {}).duplicate(true)

func g06_ledger(f: Dictionary) -> Dictionary:
 var state: Dictionary = f.session.ledger.model.state
 return state.shop_visit.taskLedger.get(str(state.actor_id) + "|final:G06", {}).duplicate(true)

func g06_protected_model(model: RefCounted) -> Dictionary:
 var state: Dictionary = model.state
 return {"task":model.snapshot().get("g06_equipment", {}).duplicate(true), "ledger":state.shop_visit.taskLedger.get(str(state.actor_id) + "|final:G06", {}).duplicate(true), "evolved":state.get("evolved_equipment_tasks", {}).duplicate(true), "points":state.points, "bonus_sp":state.bonus_sp, "bonus_awards":state.bonus_awards.duplicate(true), "sp_tasks":state.completed_equipment_tasks.duplicate(true)}

func g06_protected(f: Dictionary) -> Dictionary:
 return g06_protected_model(f.session.ledger.model)

func g06_near(actual: float, expected: float, label: String) -> bool:
 # Fixed absolute tolerance: is_equal_approx around100000 could hide a whole
 # damage point and incorrectly accept a99999.x threshold implementation.
 return check(is_finite(actual) and absf(actual - expected) <= G06_EPSILON, label + " actual=" + str(actual) + " expected=" + str(expected))

func g06_group_done() -> void:
 check(current_group in G06_GROUPS and current_group not in g06_groups, "unique G06 source group " + current_group)
 g06_groups.append(current_group)

func on_event(event: Dictionary, f: Dictionary) -> void:
 var attribution: Dictionary = {}
 var before: Dictionary = {}
 if event.get("kind", "") == "damage" and f.has("g06_damage"):
  attribution = f.sim.verify_g06_damage_attribution(event)
  before = g06_protected(f)
  # This observer is deliberately earlier than the actual progression call.
  # A newer child sequence may be processed before its older outer sequence.
  var early: Dictionary = f.g06_attack
  if not early.is_empty() and early.kind == "real_nested_before_model" and not early.fired and event.get("source", "") == early.source:
   early.fired = true
   f.sim.damage_enemy(early.enemy, float(early.nominal), "equipment37_before_model_child", 0, true, false, {"fixture":true, "direct":false, "no_reactions":true, "generation":f.sim.encounter_generation, "room_id":f.sim.room_id})
   f.g06_attack_records.append({"kind":early.kind, "outer_sequence":event.sequence, "nested_sequence":f.g06_damage.back().event.sequence, "before":before, "after_child_before_outer":g06_protected(f)})
 super.on_event(event, f) # Exactly one existing Session observation per event.
 if event.get("kind", "") != "damage" or not f.has("g06_damage"): return
 f.g06_damage.append({"event":event.duplicate(true), "live_attribution":attribution.duplicate(true), "before":before, "after":g06_protected(f)})
 var attack: Dictionary = f.g06_attack
 if attack.is_empty() or attack.get("fired", false) or event.get("source", "") != attack.source: return
 attack.fired = true # Gate-local observer guard, never a production claim.
 var before_nested: Dictionary = g06_protected(f)
 if attack.kind == "forged_same_frame":
  var forged: Dictionary = event.duplicate(true)
  forged.amount = float(attack.pre_hp)
  var hp: float = float(attack.enemy.hp)
  f.sim.emit_event("damage", forged)
  f.g06_attack_records.append({"kind":attack.kind, "original_event":event.duplicate(true), "forged_amount":forged.amount, "hp_before":hp, "hp_after":attack.enemy.hp, "before":before_nested, "after":g06_protected(f)})
 elif attack.kind == "real_nested_packet":
  var hp: float = float(attack.enemy.hp)
  f.sim.damage_enemy(attack.enemy, float(attack.nominal), "equipment37_nested_real_source", 0, true, false, {"fixture":true, "direct":false, "no_reactions":true, "generation":f.sim.encounter_generation, "room_id":f.sim.room_id})
  # Re-emit the parent after a real child HP loss. It cannot borrow the child
  # delta, resurrect the parent's consumed emission, or add another task hit.
  var after_child: Dictionary = g06_protected(f)
  f.sim.emit_event("damage", event.duplicate(true))
  f.g06_attack_records.append({"kind":attack.kind, "original_event":event.duplicate(true), "actual_nested_loss":hp - float(attack.enemy.hp), "before":before_nested, "after_child":after_child, "after":g06_protected(f)})

func g06_assert_task(f: Dictionary, progress: float, completed: bool, receipt_count: int, label: String) -> void:
 var task: Dictionary = g06_task(f)
 g06_near(float(task.get("progress", -1.0)), progress, label + ": exact float task progress")
 check(bool(task.get("completed", false)) == completed, label + ": exact completion boundary")
 var state: Dictionary = f.session.ledger.model.state
 if state.has("g06_equipment_progress"):
  check(state.g06_equipment_progress == task, label + ": snapshot is the original authoritative float state")
 var receipt: Dictionary = g06_ledger(f)
 if receipt_count == 0:
  check(receipt.is_empty(), label + ": no task receipt without actual elite damage")
 else:
  check(int(receipt.get("progress", -1)) == int(floor(progress)), label + ": integer commerce receipt floors total only")
  check(receipt.get("event_ids", []).size() == receipt_count, label + ": one receipt per accepted original damage event")
  check(receipt.get("completed_stages", []) == (["task:G06:1"] if completed else []), label + ": evolution stage recorded once")
  var rewards: Dictionary = receipt.get("permanent_rewards", {})
  check(rewards.size() == (1 if completed else 0) and (not completed or rewards.has("task:G06:permanent_evolution")), label + ": only the permanent evolution reward")
 check(not state.completed_equipment_tasks.has("final:G06") and not state.bonus_awards.has("task:G06"), label + ": evolution never enters G17's SP-task dictionaries")
 check(int(state.bonus_sp) == 0, label + ": G06 never awards bonus SP")
 check(state.get("evolved_equipment_tasks", {}).has("final:G06") == completed, label + ": separate permanent evolution identity")

func g06_assert_stats(f: Dictionary, copies: int, a05_copies: int, label: String) -> void:
 var now: Dictionary = authority(f)
 for row: Array in [["AD", "ad", 45.0 * copies + 55.0 * a05_copies], ["AP", "ap", 65.0 * copies], ["penetration", "penetration", 20.0 * copies + 20.0 * a05_copies]]:
  g06_near(float(now.equipment.stats.get(row[0], 0.0)) - float(f.baseline.equipment.stats.get(row[0], 0.0)), float(row[2]), label + ": per-copy equipment " + str(row[0]))
  g06_near(float(now.aggregate.stats.get(row[0], 0.0)) - float(f.baseline.aggregate.stats.get(row[0], 0.0)), float(row[2]), label + ": same authoritative aggregate " + str(row[0]))
  g06_near(float(now.current_sim_stats[row[1]]) - float(f.baseline.current_sim_stats[row[1]]), float(row[2]), label + ": original same-Sim stat consumer " + str(row[1]))
 check(owned_count(f, "final:G06") == copies and owned_count(f, "final:A05") == a05_copies, label + ": original inventory owns exact copies")

func g06_selection(model: RefCounted, base: float, cap: float, item: String, label: String) -> void:
 var selected: Dictionary = model.snapshot().get("passive18_equipment", {})
 check(selected.get("equipped", false) and selected.get("item_id", "") == item, label + ": one winning giant-hunter item")
 g06_near(float(selected.get("tuning", {}).get("base_damage_bonus", -1.0)), base, label + ": selected base bonus")
 g06_near(float(selected.get("tuning", {}).get("damage_bonus_cap", -1.0)), cap, label + ": selected cap")
 g06_near(float(selected.get("tuning", {}).get("lost_hp_step", -1.0)), 25.0, label + ": original25% lost-HP step")
 g06_near(float(selected.get("tuning", {}).get("step_damage_bonus", -1.0)), 2.0, label + ": original+2 per step")

func g06_combat(copies: int, a05: int, label: String) -> Dictionary:
 var f: Dictionary = funded_shop(label)
 if f.is_empty(): return {}
 for _copy: int in range(copies):
  if not buy(f, "final:G06"): dispose(f); return {}
 for _copy: int in range(a05):
  if not buy(f, "final:A05"): dispose(f); return {}
 g06_assert_stats(f, copies, a05, label)
 if not check(f.session.close_panel().get("accepted", false), "original shop closes") or not enter(f, 1) or not spawn_ready(f):
  dispose(f); return {}
 return f

func g06_spawn(f: Dictionary, rows: Array) -> Array:
 var targets: Array = []
 var origin: Vector3 = f.sim.hero.position
 for row: Array in rows:
  var enemy: Dictionary = f.sim.spawn_enemy(str(row[0]), origin + Vector3(0.0, 0.0, -float(row[2])), float(row[1]))
  targets.append(enemy)
  f.g06_targets.append(str(enemy.actor_id))
  evidence.spawn_fixtures.append({"case":current_group, "api":"original spawn_enemy(kind, position, hp_override)", "target":enemy.actor_id, "kind":enemy.kind, "hp_override":float(row[1]), "original_defence":enemy.defence, "position":enemy.position, "original_entered_roster":f.session.expected_enemies.duplicate(), "route_reward_eligible":false})
 for _tick: int in range(MAX_SPAWN_TICKS):
  var waiting: bool = false
  for enemy: Dictionary in targets:
   if enemy.state == "spawn": waiting = true
  if not waiting: break
  step(f)
 for enemy: Dictionary in targets:
  check(not enemy.dead and enemy.state != "spawn", "extra source fixture ends original spawn grace: " + str(enemy.actor_id))
 check(f.sim.ai_enabled and f.sim.auto_finish and not f.sim.paused and not f.sim.hero.dead and f.sim.phase == "combat", "extra fixture retains live original AI/clock/terminal ownership")
 return targets

func g06_hit(f: Dictionary, enemy: Dictionary, nominal: float, is_true: bool = true, extra: Dictionary = {}, source: String = "equipment37_source_fixture", cast_id: int = 0) -> Dictionary:
 var metadata: Dictionary = {"fixture":true, "direct":false, "no_reactions":true, "generation":f.sim.encounter_generation, "room_id":f.sim.room_id}
 metadata.merge(extra, true)
 var hp: float = float(enemy.hp)
 var before: Dictionary = g06_protected(f)
 var start: int = f.g06_damage.size()
 var killed: bool = f.sim.damage_enemy(enemy, nominal, source, cast_id, is_true, false, metadata)
 var record: Dictionary = {"target":enemy.actor_id, "kind":enemy.kind, "source":source, "cast_id":cast_id, "nominal":nominal, "true_damage":is_true, "metadata":metadata, "hp_before":hp, "hp_after":enemy.hp, "actual_hp_loss":hp - float(enemy.hp), "killed":killed, "before":before, "after":g06_protected(f), "observations":f.g06_damage.slice(start), "actual_skill_input":false, "original_roster":str(enemy.actor_id) in f.session.expected_enemies}
 evidence.packets.append(record)
 return record

func g06_packet_check(record: Dictionary, amount: float, eligible: bool, label: String) -> void:
 g06_near(float(record.actual_hp_loss), amount, label + ": real HP loss")
 check(record.observations.size() == (1 if amount > 0.0 else 0), label + ": exact source damage event count")
 if record.observations.size() != 1: return
 var observation: Dictionary = record.observations[0]
 g06_near(float(observation.event.amount), amount, label + ": emitted amount is actual capped/mitigated loss")
 check((not observation.live_attribution.is_empty()) == eligible, label + ": source-live attribution eligibility")
 if eligible: g06_near(float(observation.live_attribution.amount), amount, label + ": live witness preserves exact float")

func g06_source_integrity(f: Dictionary, label: String) -> void:
 # An explicit low-HP extra target may die in the overkill test. Its damage is
 # legitimate, but the unchanged Session must refuse its route reward.
 for error: Dictionary in f.event_errors:
  check(error.event.get("kind", "") == "kill" and str(error.event.get("target", "")) in f.g06_targets and error.result.get("reason", "") == "enemy_not_in_entered_roster", label + ": only declared extra-target reward rejection")
 for target: String in f.g06_targets:
  check(not f.session.kill_receipts.has(target), label + ": extra target never receives route reward " + target)
 check(f.scope_errors.is_empty() and f.session.fault.is_empty(), label + ": original scope/Session remains intact")
 check_owners(f, label)

func g06_definitions_commerce() -> void:
 current_group = G06_GROUPS[0]
 var f: Dictionary = funded_shop(current_group)
 if f.is_empty(): return
 var model = f.session.ledger.model
 var numeric: Variant = JSON.parse_string(FileAccess.get_file_as_string(B01_NUMERIC))
 if not check(numeric is Dictionary, "original numeric source readable"): dispose(f); return
 var prior: Dictionary = G06Prior.build(numeric)
 if not check(prior.get("accepted", false), "original36 adapter accepts original source"): dispose(f); return
 check(model.runtime_stat_definitions.size() == prior.definitions.size() + 1, "only G06 extends prior36 definitions")
 for item_id: String in prior.definitions:
  check(var_to_bytes(prior.definitions[item_id]) == var_to_bytes(model.runtime_stat_definitions.get(item_id, {})), "prior36 definition deeply unchanged: " + item_id)
 var supported: int = 0
 for definition: Dictionary in model.runtime_stat_definitions.values():
  if definition.get("supported", false): supported += 1
 check(supported == 37 and model.snapshot().content_profile == "ordinary_equipment37_potions3", "truthful supported37 profile")
 var g06: Dictionary = model.equipment_runtime_status("final:G06")
 check(g06.stats == {"AD":45.0, "AP":65.0, "penetration":20.0} and g06.passives == ["passive:18"], "G06 authored AD45/AP65/penetration20 and giant-hunter identity")
 check(int(model.commerce_definitions.items["final:G06"].price) == 3400, "G06 original price3400")
 check(float(g06.taskG06.threshold) == 100000.0 and int(g06.taskG06.reward_skill_points) == 0, "actual100000 damage task grants zero SP")
 g06_near(float(g06.taskG06.evolved_base_bonus), 15.0, "evolved authored base15")
 g06_near(float(g06.taskG06.evolved_bonus_cap), 25.0, "evolved authored cap25")
 var gold: int = int(model.state.gold)
 if not buy(f, "final:G06"): dispose(f); return
 check(int(model.state.gold) == gold - 3400, "original commerce charges3400 exactly")
 g06_assert_stats(f, 1, 0, "one G06")
 buy(f, "final:G06"); g06_assert_stats(f, 2, 0, "two G06 base stats stack")
 buy(f, "final:A05"); g06_assert_stats(f, 2, 1, "A05 plus two G06")
 var selected: Dictionary = model.snapshot().passive18_equipment
 check(selected.tuning == prior.definitions["final:A05"].passive18, "unevolved A05/G06 select original tuning once")
 var stable: Dictionary = authority(f)
 for _sync: int in range(4): f.sim.refresh_passive23(); f.session.update_after_source_step()
 check(stable == authority(f), "repeated same-owner stat projection is idempotent")
 sell(f, "final:G06"); sell(f, "final:G06"); g06_assert_stats(f, 0, 1, "sold last G06")
 g06_selection(model, 12.0, 20.0, "final:A05", "remaining original A05")
 undo(f); undo(f); g06_assert_stats(f, 2, 1, "undo G06 sales")
 var before: Dictionary = g06_protected(f)
 var denied: Dictionary = command(f, "g06_verified_damage", {"amount":100000.0, "progress":100000.0})
 check(not denied.get("accepted", false) and denied.get("reason", "") == "g06_verified_live_damage_required" and g06_protected(f) == before, "public Model command cannot invent damage entitlement")
 g06_assert_task(f, 0.0, false, 0, "commerce alone")
 var admitted: Dictionary = Binding.read_capabilities(f.sim, true)
 check("hex.final_design.common_g18.v1" not in admitted.get("capabilities", {}).get("supported_hooks", []) and not model.support(model.config.hexes.common_g18).supported, "real G18 remains unsupported")
 evidence.commerce.append({"case":current_group, "protected":g06_protected(f), "authority":authority(f)})
 g06_source_integrity(f, current_group); dispose(f); g06_group_done()

func g06_unequipped_a05() -> void:
 current_group = G06_GROUPS[1]
 var f: Dictionary = g06_combat(0, 1, current_group)
 if f.is_empty(): return
 var targets: Array = g06_spawn(f, [["elite", G06_HP, 6.0], ["minion", G06_HP, 8.0]])
 var enemy: Dictionary = targets[0]
 var points: int = int(f.session.ledger.model.state.points)
 g06_selection(f.session.ledger.model, 12.0, 20.0, "final:A05", "A05 original unchanged")
 for tier: int in range(4):
  if tier > 0:
   var desired_loss: float = G06_HP * 0.25 * tier + 0.5 - (G06_HP - float(enemy.hp))
   g06_hit(f, enemy, desired_loss / (1.0 + (12.0 + 2.0 * (tier - 1)) / 100.0))
  var packet: Dictionary = g06_hit(f, enemy, 100.0)
  g06_packet_check(packet, 112.0 + 2.0 * tier, true, "original A05 lost-HP tier " + str(tier))
  g06_assert_task(f, 0.0, false, 0, "A05-only actual elite loss")
 g06_packet_check(g06_hit(f, targets[1], 17.25), 17.25, false, "ordinary target receives no A05 multiplier")
 check(int(f.session.ledger.model.state.points) == points, "unequipped task and packet fixtures grant no SP")
 g06_source_integrity(f, current_group); dispose(f); g06_group_done()

func g06_damage_reentrancy() -> void:
 current_group = G06_GROUPS[2]
 var f: Dictionary = g06_combat(1, 0, current_group)
 if f.is_empty(): return
 var targets: Array = g06_spawn(f, [["boss", G06_HP, 6.0], ["elite", 7.25, 8.0], ["minion", G06_HP, 10.0]])
 var boss: Dictionary = targets[0]
 var points: int = int(f.session.ledger.model.state.points)
 g06_near(float(boss.defence), 38.0, "original Boss defence38 retained")
 var mitigation: float = 112.0 * 100.0 / 118.0
 g06_packet_check(g06_hit(f, boss, 100.0, false), mitigation, true, "actual post-defence damage")
 g06_packet_check(g06_hit(f, targets[1], 999999.0), 7.25, true, "overkill caps to actual remaining7.25 HP")
 var progress: float = mitigation + 7.25
 g06_assert_task(f, progress, false, 2, "mitigation and overkill actual sums")
 var unchanged: Dictionary = g06_protected(f)
 g06_packet_check(g06_hit(f, targets[2], 500.5), 500.5, false, "ordinary500.5 loss gives no progress")
 check(g06_protected(f) == unchanged, "ordinary loss never changes G06 task or SP")
 f.g06_attack = {"kind":"forged_same_frame", "source":"equipment37_same_frame_original", "enemy":boss, "pre_hp":float(boss.hp), "fired":false}
 g06_hit(f, boss, 1.0 / 1.12, true, {}, "equipment37_same_frame_original")
 progress += 1.0
 g06_assert_task(f, progress, false, 3, "same-frame forged full-HP event cannot amplify real1 damage")
 check(f.g06_attack_records.size() == 1 and f.g06_attack_records[0].before == f.g06_attack_records[0].after, "reentrant new-sequence forged amount is inert")
 check(f.g06_damage.back().live_attribution.is_empty(), "same-frame forged emission has no borrowed witness")
 f.g06_attack = {"kind":"real_nested_packet", "source":"equipment37_nested_parent", "enemy":boss, "nominal":2.0 / 1.12, "fired":false}
 var hp_before: float = boss.hp
 g06_hit(f, boss, 3.0 / 1.12, true, {}, "equipment37_nested_parent")
 progress += 5.0
 g06_near(hp_before - float(boss.hp), 5.0, "actual nested3+2 packets each commit one HP loss")
 g06_assert_task(f, progress, false, 5, "nested source packets count individually once")
 var nested: Dictionary = f.g06_attack_records.back()
 g06_near(float(nested.actual_nested_loss), 2.0, "child original source commits2 exactly")
 check(nested.after_child == nested.after and f.g06_damage.back().live_attribution.is_empty(), "outer re-emit after child cannot borrow nested delta")
 f.g06_attack = {"kind":"real_nested_before_model", "source":"equipment37_before_model_parent", "enemy":boss, "nominal":2.0 / 1.12, "fired":false}
 g06_hit(f, boss, 3.0 / 1.12, true, {}, "equipment37_before_model_parent")
 progress += 5.0
 g06_assert_task(f, progress, false, 7, "newer nested sequence before older outer still counts both real packets")
 var early: Dictionary = f.g06_attack_records.back()
 check(int(early.nested_sequence) > int(early.outer_sequence), "actual progression observer receives newer child sequence before outer")
 g06_near(float(early.after_child_before_outer.task.progress) - float(early.before.task.progress), 2.0, "child committed2 before actual outer progression callback")
 f.g06_attack = {}
 var originals: Array = []
 for observation: Dictionary in f.g06_damage:
  if not observation.live_attribution.is_empty(): originals.append(observation.event)
 var saved: Dictionary = g06_protected(f)
 for event: Dictionary in originals:
  check(f.sim.verify_g06_damage_attribution(event).is_empty(), "old event is unverified after original emission returns")
  check(f.session.observe_event(f.sim, event).get("accepted", false), "authentic damage replay remains a valid inert observation")
  f.sim.emit_event("damage", event.duplicate(true))
  check(f.g06_damage.back().live_attribution.is_empty() and g06_protected(f) == saved, "same event or forged new sequence cannot add task progress")
 var effect: String = "equipment37:shared-source-effect"
 g06_packet_check(g06_hit(f, boss, 4.0 / 1.12, true, {"effect_id":effect}), 4.0, true, "first actual effect contact")
 progress += 4.0
 g06_packet_check(g06_hit(f, boss, 4.0 / 1.12, true, {"effect_id":effect}), 0.0, false, "same actual source effect retry has no HP loss")
 g06_assert_task(f, progress, false, 8, "source effect retry cannot progress")
 check(int(f.session.ledger.model.state.points) == points, "all damage fixtures and extra-target kill grant no SP")
 evidence.reentrancy = {"attacks":f.g06_attack_records.duplicate(true), "final":g06_protected(f), "expected_extra_kill_rejections":f.event_errors.duplicate(true)}
 g06_source_integrity(f, current_group); dispose(f); g06_group_done()

func g06_fractional_threshold() -> void:
 current_group = G06_GROUPS[3]
 var f: Dictionary = g06_combat(2, 1, current_group)
 if f.is_empty(): return
 var targets: Array = g06_spawn(f, [["elite", G06_HP, 6.0], ["boss", G06_HP, 8.0]])
 var enemy: Dictionary = targets[0]
 var points: int = int(f.session.ledger.model.state.points)
 for index: int in range(3):
  g06_packet_check(g06_hit(f, enemy, 0.375 / 1.12), 0.375, true, "fractional real packet " + str(index + 1))
  g06_assert_task(f, 0.375 * (index + 1), false, index + 1, "fractional cumulative state")
 g06_near(float(g06_task(f).progress), 1.125, "three sub-one hits accumulate1.125, never floor per packet")
 var needed: float = 99999.75 - float(g06_task(f).progress)
 g06_packet_check(g06_hit(f, enemy, needed / 1.12), needed, true, "source high-HP fixture approaches threshold")
 g06_assert_task(f, 99999.75, false, 4, "99999.75 stays incomplete although near100000")
 f["g06_prethreshold_checkpoint"] = f.session.ledger.model.save()
 var crossing: Dictionary = g06_hit(f, enemy, 1.0)
 g06_packet_check(crossing, 1.12, true, "threshold-crossing packet still uses pre-evolution12% once")
 g06_assert_task(f, 100000.0, true, 5, "threshold-crossing actual loss clamps exact100000")
 g06_selection(f.session.ledger.model, 15.0, 25.0, "final:G06", "evolved G06 defeats A05 without multiplying twice")
 var completed: Dictionary = g06_protected(f)
 g06_packet_check(g06_hit(f, enemy, 100.0), 115.0, true, "next real elite packet uses evolved15% once")
 g06_packet_check(g06_hit(f, targets[1], 100.0), 115.0, true, "next real Boss packet also uses evolved15% once")
 check(g06_protected(f) == completed, "post-completion damage cannot award a second task or reward")
 check(int(f.session.ledger.model.state.points) == points, "crossing100000 grants no SP")
 for tier: int in range(1, 4):
  var desired_loss: float = G06_HP * 0.25 * tier + 0.5 - (G06_HP - float(enemy.hp))
  g06_hit(f, enemy, desired_loss / (1.0 + (15.0 + 2.0 * (tier - 1)) / 100.0))
  g06_packet_check(g06_hit(f, enemy, 100.0), 115.0 + 2.0 * tier, true, "evolved original25%/+2 HP tier " + str(tier))
  check(g06_protected(f) == completed, "evolved tiers never replay task completion")
 evidence.threshold = {"crossing":crossing, "completed":completed, "two_equipped_G06":true, "A05_equipped":true, "SP_before":points, "SP_after":f.session.ledger.model.state.points, "actual_threshold_fixture":true, "natural_damage_accumulation":false}
 g06_source_integrity(f, current_group)
 g06_evolved_source = f # Keep the live source unchanged for the isolated clone.
 g06_group_done()

func g06_enter_original(f: Dictionary, row: int, node: String) -> bool:
 if not choose_required_hexes(f) or not check(f.session.select_node(row, node).get("accepted", false), "select original P1 route " + node): return false
 if not check(f.session.enter_selected_node().get("accepted", false), "enter original P1 route " + node): return false
 for enemy: Dictionary in f.sim.enemies:
  check(str(enemy.actor_id) in f.session.expected_enemies, "P1 route uses only original entered actor " + str(enemy.actor_id))
 check_owners(f, node)
 return check(f.sim.ai_enabled and f.sim.auto_finish and f.session.fault.is_empty(), "P1 original source owners remain enabled")

func g06_p1_events(f: Dictionary, cast_id: int, source: String) -> Array:
 var found: Array = []
 for observation: Dictionary in f.g06_damage:
  if int(observation.event.get("cast_id", 0)) == cast_id and observation.event.get("source", "") == source: found.append(observation)
 return found

func g06_p1_receipts(f: Dictionary, cast_id: int) -> Array:
 var found: Array = []
 for receipt: Dictionary in f.sim.ink_p1_receipts:
  if int(receipt.cast_id) == cast_id: found.append(receipt.duplicate(true))
 return found

func g06_original_shop_retention(f: Dictionary) -> bool:
 if not choose_required_hexes(f) or not check(f.session.open_panel().get("accepted", false), "real post-row5 shop opens"): return false
 var before: Dictionary = g06_protected(f)
 if not sell(f, "final:G06"): return false
 check(g06_protected(f) == before, "real last-G06 sale retains earned progress and task receipts")
 g06_selection(f.session.ledger.model, 12.0, 20.0, "final:A05", "real last-G06 sale leaves original A05")
 if not buy(f, "final:G06"): return false
 check(g06_protected(f) == before, "real repurchase retains progress")
 if not undo(f): return false
 check(owned_count(f, "final:G06") == 0 and g06_protected(f) == before, "real purchase undo cannot wash progress")
 if not undo(f): return false
 check(owned_count(f, "final:G06") == 1 and g06_protected(f) == before, "real sale undo restores same task-bearing item")
 evidence.commerce.append({"case":"unevolved_same_original_Session", "before":before, "after":g06_protected(f), "actual_completed_original_row":5, "safe_phase_fixture":false, "fractional_P1_snapshot_observed_before_original_elite_death":true, "sale_progress_is_total_after_original_elite_death_not_the_earlier_fractional_snapshot":true})
 return check(f.session.close_panel().get("accepted", false), "real retention shop closes")

func g06_actual_p1_and_shop() -> void:
 current_group = G06_GROUPS[4]
 var f: Dictionary = funded_shop(current_group)
 if f.is_empty(): return
 if not buy(f, "final:G06") or not buy(f, "final:A05") or not check(f.session.close_panel().get("accepted", false), "P1 route original shop closes"):
  dispose(f); return
 if not g06_enter_original(f, 1, "r01a") or not settle_fixture_combat(f): dispose(f); return
 var earned: Dictionary = f.session.ledger.model.snapshot()
 if not check(int(earned.level) == 2 and int(earned.points) == 1, "four real row1 rewards earn original Lv2/1SP"): dispose(f); return
 var learned: Dictionary = command(f, "learn", {"slot":"P", "candidate":"P1", "expected_rank":0})
 if not check(learned.get("accepted", false), "original earned SP learns P1 rank1"): dispose(f); return
 check(f.sim.hero.loadout.passive == "p1" and int(f.sim.hero.ranks.passive) == 1 and int(f.sim.hero.ranks.q) == 1 and int(f.session.ledger.model.state.points) == 0, "same original Model pays and projects real Q1/P1 rank1")
 for row: int in range(2, 5):
  if not g06_enter_original(f, row, "r%02da" % row): dispose(f); return
  if f.session.status == "service":
   if not check(f.session.complete_service().get("accepted", false), "original pre-elite service completes"): dispose(f); return
  elif not settle_fixture_combat(f): dispose(f); return
 if not g06_enter_original(f, 5, "r05a") or not spawn_ready(f): dispose(f); return
 g06_assert_task(f, 0.0, false, 0, "ordinary pre-elite route never progresses G06")
 var enemy: Dictionary = {}
 for actor: Dictionary in f.sim.enemies:
  if actor.kind == "elite": enemy = actor; break
 if not check(not enemy.is_empty(), "original row5 retains its authored elite"): dispose(f); return
 var approach: Dictionary = {"hero_before":f.sim.hero.position, "elite_before":enemy.position, "distance_before":Vector3(enemy.position).distance_to(f.sim.hero.position), "ticks":0, "method":"unchanged original AI advances on original source clock"}
 # The actual hero spawns at z=5, so the original(-4,-6) elite is initially
 # outside Q1's9m placement radius. Let its real chase close the gap; never
 # teleport the actor, widen the range, or replace the entered elite.
 for tick: int in range(400):
  if Vector3(enemy.position).distance_to(f.sim.hero.position) <= 8.5 or f.sim.phase != "combat" or f.sim.hero.dead: break
  step(f)
  approach.ticks = tick + 1
 approach["hero_after"] = f.sim.hero.position
 approach["elite_after"] = enemy.position
 approach["distance_after"] = Vector3(enemy.position).distance_to(f.sim.hero.position)
 evidence.actual_p1["approach"] = approach
 if not check(not enemy.dead and not f.sim.hero.dead and Vector3(enemy.position).distance_to(f.sim.hero.position) < 9.0, "original AI brings unchanged elite within genuine Q1 placement"): dispose(f); return
 var start: Vector3 = enemy.position
 var endpoint: Vector3 = start + Vector3(0.26, 0.0, 0.0)
 for actor: Dictionary in f.sim.living():
  if actor.actor_id != enemy.actor_id: check(Vector3(actor.position).distance_to(start) > 3.0 + float(actor.radius), "short Q1 excludes original sibling " + str(actor.actor_id))
 var hp: float = enemy.hp
 var points: int = int(f.session.ledger.model.state.points)
 var nominal: float = G06Design.parameter("yanguizhou", "Q1-1", 1) + float(f.sim.hero.stats.ap) * G06Design.fraction("yanguizhou", "Q1-2", 1)
 var expected: float = nominal * 1.12 * 100.0 / (100.0 + maxf(0.0, float(enemy.defence) - float(f.sim.hero.stats.penetration)))
 if not check(f.sim.request_ink_input("q_down").get("accepted", false), "genuine Q1 arm") or not check(f.sim.request_ink_input("left_down", start).get("accepted", false), "genuine Q1 legal start") or not check(f.sim.request_ink_input("motion", endpoint).get("accepted", false), "genuine Q1 short path"):
  dispose(f); return
 var released: Dictionary = f.sim.request_ink_input("left_up", endpoint)
 if not check(released.get("accepted", false), "genuine Q1 release"): dispose(f); return
 var releases: Array = events_of(f, "ink_q1_released")
 if not check(releases.size() == 1, "one actual input-created Q1 root"): dispose(f); return
 var cast_id: int = int(releases[0].cast_id)
 for _tick: int in range(100):
  if not g06_p1_receipts(f, cast_id).is_empty() or f.sim.phase != "combat": break
  step(f)
 var receipts: Array = g06_p1_receipts(f, cast_id)
 var ordinary: Array = g06_p1_events(f, cast_id, "q1")
 var supplements: Array = g06_p1_events(f, cast_id, "yanguizhou_p1")
 if not check(receipts.size() == 1 and ordinary.size() == 1 and supplements.size() == 1, "one real Q1 damage packet and one original P1 atomic supplement"): dispose(f); return
 var receipt: Dictionary = receipts[0]
 check(receipt.qualified and receipt.distinct_targets == 1 and receipt.ordinary_packet_count == 1 and receipt.target_status == "live_original" and not receipt.supplement_killed, "original completed single-target P1 root retains living entered elite")
 g06_near(float(ordinary[0].event.amount), expected, "real Q1 damage applies single12% then actual mitigation")
 g06_near(float(receipt.final_basis), expected, "P1 basis is committed real Q1 damage")
 g06_near(float(receipt.actual_supplement), expected * 0.12, "real P1 adds authored12% final supplement once")
 g06_near(hp - float(enemy.hp), expected * 1.12, "actual HP loss sums Q1 and P1 without reapplying giant-hunter to P1")
 check(not ordinary[0].live_attribution.is_empty() and supplements[0].live_attribution.get("witness", "") == "original_atomic_p1_receipt" and not str(supplements[0].live_attribution.get("p1_receipt_key", "")).is_empty(), "P1 actual callback uses original atomic receipt witness")
 g06_assert_task(f, expected * 1.12, false, 2, "real Q1 plus atomic P1 count each actual damage once")
 check(int(f.session.ledger.model.state.points) == points, "real Q1/P1 nonlethal damage grants no SP")
 var saved: Dictionary = g06_protected(f)
 var real_event: Dictionary = supplements[0].event
 check(f.sim.verify_g06_damage_attribution(real_event).is_empty(), "historical P1 receipt cannot verify outside real emission")
 f.session.observe_event(f.sim, real_event)
 f.sim.emit_event("damage", real_event.duplicate(true))
 check(g06_protected(f) == saved and f.g06_damage.back().live_attribution.is_empty(), "same P1 source event and fake new sequence cannot reuse atomic receipt")
 step(f, 10)
 check(g06_p1_receipts(f, cast_id).size() == 1 and g06_protected(f) == saved, "later original source steps cannot settle P1 task twice")
 evidence.actual_p1 = {"earned_Lv2":earned, "learned":learned, "approach":approach, "release":released, "cast_id":cast_id, "original_target":enemy.actor_id, "ordinary":ordinary[0], "supplement":supplements[0], "receipt":receipt, "actual_skill_input":true, "natural_acquisition":false, "extra_actor_spawned":false, "before_shop":saved}
 # Finish only the original entered roster through disclosed source packets.
 # No extra actor, roster rewrite, HP assignment, or fabricated terminal.
 if not settle_fixture_combat(f) or not g06_original_shop_retention(f): dispose(f); return
 var retained: Dictionary = g06_protected(f)
 if not g06_enter_original(f, 6, "r06a") or not check(f.session.complete_service().get("accepted", false), "original row6 service completes"): dispose(f); return
 check(g06_protected(f) == retained, "task progress persists across original next-room/service boundary")
 check(f.g06_targets.is_empty() and f.event_errors.is_empty(), "actual P1/retention route has no extra actor or rejected source event")
 g06_source_integrity(f, current_group); dispose(f); g06_group_done()

func run() -> void:
 evidence = {"wallet_fixtures":[], "commerce":[], "spawn_fixtures":[], "packets":[], "reentrancy":{}, "threshold":{}, "actual_p1":{}, "evolved_commerce":{}, "isolated_nested":[]}
 g06_definitions_commerce()
 g06_unequipped_a05()
 g06_damage_reentrancy()
 g06_fractional_threshold()
 g06_actual_p1_and_shop()
 g06_snapshot_commerce()
 g06_nested_source_fixtures()
 if not g06_evolved_source.is_empty(): dispose(g06_evolved_source)
 finish()

func g06_snapshot_commerce() -> void:
 current_group = G06_GROUPS[5]
 if not check(not g06_evolved_source.is_empty(), "real threshold source is available for a separate economic snapshot fixture"): return
 var source_model = g06_evolved_source.session.ledger.model
 var checkpoint: Dictionary = source_model.save()
 var source_bytes: PackedByteArray = var_to_bytes(checkpoint)
 var original_protected: Dictionary = g06_protected(g06_evolved_source)
 var owner: RefCounted = RefCounted.new()
 var host = Host.new()
 var sim = host._make_floor_sim()
 root.add_child(sim)
 var clone = source_model.get_script().new(source_model.config, str(source_model.state.actor_id))
 clone.set_supported_hooks(source_model.supported_hooks)
 if not check(clone.bind_commerce(owner, source_model.commerce_definitions, str(source_model.state.shop_visit.run_id), true).get("accepted", false), "separate fresh clone binds original commerce authority") or not check(clone.bind_runtime_stats(source_model.runtime_stat_definitions).get("accepted", false), "separate clone binds exact runtime definitions") or not check(clone.bind_health_sim(sim).get("accepted", false), "separate clone binds a different original factory health Sim"):
  sim.free(); host.free(); return
 var fractional_checkpoint: Dictionary = g06_evolved_source.g06_prethreshold_checkpoint
 var fresh_clone_bytes: PackedByteArray = var_to_bytes(clone.save())
 var fractional_restored: bool = clone.restore(fractional_checkpoint)
 if not check(not fractional_restored and var_to_bytes(clone.save()) == fresh_clone_bytes, "original restore refuses fractional checkpoint without changing state or receipts"):
  sim.free(); host.free(); return
 var restored: bool = clone.restore(checkpoint)
 if not check(not restored and var_to_bytes(clone.save()) == fresh_clone_bytes, "original restore refuses completed checkpoint without changing state or receipts"):
  sim.free(); host.free(); return
 evidence.evolved_commerce["restore_denial"] = {"fractional_checkpoint_accepted":fractional_restored, "completed_checkpoint_accepted":restored, "state_and_receipts_unchanged":var_to_bytes(clone.save()) == fresh_clone_bytes, "actual_save_load_supported":false, "inherited_guard":"res://tests/ink_shop_ledger_bridge_20261004/fix01/ink_shop_run_model.gd::restore always returns false"}
 # Authorized economic fixture ONLY. Copy the ENTIRE genuine captured state
 # and command receipts, with no invented progress/evolution or field patches.
 # This deliberately does not pretend to use the unsupported restore API.
 clone.state = fractional_checkpoint.state.duplicate(true)
 clone.receipts = fractional_checkpoint.receipts.duplicate(true)
 if not check(var_to_bytes(clone.save()) == var_to_bytes(fractional_checkpoint), "economic fixture copies every fractional snapshot byte without modifying values or types"):
  sim.free(); host.free(); return
 var fractional_task: Dictionary = clone.snapshot().g06_equipment
 if not check(fractional_task.progress is float and float(fractional_task.progress) == 99999.75 and not fractional_task.completed, "isolated economic copy retains actual99999.75 snapshot, without a restore claim"):
  sim.free(); host.free(); return
 clone.state = checkpoint.state.duplicate(true)
 clone.receipts = checkpoint.receipts.duplicate(true)
 if not check(var_to_bytes(clone.save()) == source_bytes and not is_same(clone.state, source_model.state) and not is_same(clone.receipts, source_model.receipts), "economic fixture deep-copies complete evolved snapshot byte-for-byte into separate state and receipts"):
  sim.free(); host.free(); return
 var protected: Dictionary = g06_protected_model(clone)
 # This is a named economic context fixture, not a Session terminal. Only the
 # clone receives context(safe); the live source run and task stay untouched.
 serial += 1
 var safe: Dictionary = clone.command("equipment37-clone-safe-%d" % serial, "context", {"phase":"safe"})
 if not check(safe.get("accepted", false) and clone.state.phase == "safe", "isolated original context command establishes safe economic fixture") or not check(g06_clone_call(clone, owner, "begin_visit", {"area":"equipment37-isolated-checkpoint-shop"}, true).get("accepted", false), "isolated original begin_visit") or not check(g06_clone_call(clone, owner, "open_ui").get("accepted", false), "isolated original shop opens"):
  sim.free(); host.free(); return
 check(g06_protected_model(clone) == protected, "safe clone initialization never changes earned progress/evolution/SP/task receipts")
 g06_selection(clone, 15.0, 25.0, "final:G06", "clone begins with the real earned evolution")
 var transactions: Array = []
 for _copy: int in range(2):
  var held: Dictionary = {}
  for entry: Dictionary in clone.state.inventory:
   if entry.id == "final:G06": held = entry; break
  if not check(not held.is_empty(), "clone sale resolves real restored item UID"): sim.free(); host.free(); return
  var sold: Dictionary = g06_clone_call(clone, owner, "sell", {"uid":held.uid})
  transactions.append(sold)
  if not check(sold.get("accepted", false), "isolated original evolved G06 sale"): sim.free(); host.free(); return
  check(g06_protected_model(clone) == protected, "each evolved sale retains progress and evolution")
 g06_selection(clone, 12.0, 20.0, "final:A05", "selling last evolved G06 falls back to original A05")
 var neutral_enemy: Dictionary = {"rank_category":"elite", "hp":100.0, "max_hp":100.0}
 g06_near(float(clone.passive18_multiplier(neutral_enemy, {})), 1.12, "isolated sold-last projection uses only A05 factor")
 for _copy: int in range(2):
  var bought: Dictionary = g06_clone_call(clone, owner, "buy", {"item":"final:G06"})
  transactions.append(bought)
  if not check(bought.get("accepted", false), "isolated original evolved G06 repurchase"): sim.free(); host.free(); return
  check(g06_protected_model(clone) == protected, "repurchase never resets evolution or creates another award")
  g06_selection(clone, 15.0, 25.0, "final:G06", "repurchased G06 immediately retains earned evolution")
 g06_near(float(clone.passive18_multiplier(neutral_enemy, {})), 1.15, "repurchased duplicate G06 plus A05 selects one highest factor")
 for _copy: int in range(2):
  var undone: Dictionary = g06_clone_call(clone, owner, "undo")
  transactions.append(undone)
  if not check(undone.get("accepted", false), "isolated original repurchase undo"): sim.free(); host.free(); return
  check(g06_protected_model(clone) == protected, "purchase undo cannot wash permanent evolution")
 g06_selection(clone, 12.0, 20.0, "final:A05", "undo both repurchases leaves original A05")
 for _copy: int in range(2):
  var undone: Dictionary = g06_clone_call(clone, owner, "undo")
  transactions.append(undone)
  if not check(undone.get("accepted", false), "isolated original sale undo"): sim.free(); host.free(); return
  check(g06_protected_model(clone) == protected, "sale undo preserves every original task/evolution receipt")
 g06_selection(clone, 15.0, 25.0, "final:G06", "undo sales restores highest evolved passive once")
 check(var_to_bytes(source_model.save()) == source_bytes, "separate economic fixture leaves real source Model byte-for-byte unchanged")
 evidence.evolved_commerce.merge({"safe_phase_commerce_fixture":true, "same_combat_Session_returned_to_shop":false, "actual_save_load_supported":false, "cross_launch_persistence_proved":false, "snapshot_capture":"original save() only", "economic_fixture_transfer":"complete genuine state/receipts deep copy with exact byte equality; no selective task edits", "context_api":"original command(context, safe) on clone only", "source_task_before":original_protected, "clone_task_after_exact_copy":protected, "clone_task_after":g06_protected_model(clone), "source_checkpoint_unchanged":var_to_bytes(source_model.save()) == source_bytes, "source_Model_script":source_model.get_script().resource_path, "clone_Model_script":clone.get_script().resource_path, "clone_health_Sim_script":sim.get_script().resource_path, "transactions":transactions}, true)
 sim.free(); host.free(); g06_group_done()

func g06_clone_call(model: RefCounted, owner: RefCounted, action: String, extra: Dictionary = {}, trusted: bool = false) -> Dictionary:
 serial += 1
 var args: Dictionary = model.commerce_token()
 args.merge(extra, true)
 var id: String = "equipment37-isolated-commerce-%d" % serial
 return model.commerce_authority(owner, id, action, args) if trusted else model.commerce_command(id, action, args)

func g06_nested_observer(event: Dictionary, sim: Node, probe: Dictionary) -> void:
 if event.get("kind", "") != "damage": return
 var attribution: Dictionary = sim.verify_g06_damage_attribution(event)
 probe.observations.append({"event":event.duplicate(true), "live_attribution":attribution})
 if not attribution.is_empty(): probe.verified_total = float(probe.verified_total) + float(attribution.amount)
 if probe.mode == "middle_callback_under_outer" and event.get("source", "") == "equipment37_isolated_middle" and not probe.callback_fired:
  probe.callback_fired = true
  sim.damage_enemy(probe.first, 4.0, "equipment37_isolated_inner", 0, true, false, {"fixture":true, "direct":false, "no_reactions":true, "generation":sim.encounter_generation, "room_id":sim.room_id})

func g06_nested_source_fixtures() -> void:
 current_group = G06_GROUPS[6]
 for mode: String in ["three_same_target", "other_target_middle", "middle_callback_under_outer"]:
  var sim = G06NestedSource.new()
  root.add_child(sim)
  check(sim.get_script().get_base_script().resource_path == SIM_PATH, "isolated subclass inherits exact original source Sim")
  serial += 1
  if not check(sim.begin_encounter("equipment37-nested-fixture-%d" % serial, []).get("accepted", false), "isolated original encounter API begins"):
   sim.free(); return
  var first: Dictionary = sim.spawn_enemy("elite", sim.hero.position + Vector3(0.0, 0.0, -6.0), G06_HP)
  var second: Dictionary = sim.spawn_enemy("elite", sim.hero.position + Vector3(0.0, 0.0, -9.0), G06_HP)
  for _tick: int in range(MAX_SPAWN_TICKS):
   if first.state != "spawn" and second.state != "spawn": break
   sim.step(sim.FIXED_TICK)
  if not check(first.state != "spawn" and second.state != "spawn" and not first.dead and not second.dead, "isolated targets complete real spawn grace"):
   sim.free(); return
  var before_first: float = first.hp
  var before_second: float = second.hp
  sim.fixture_plan = {"mode":mode, "first":first, "second":second, "outer_fired":false, "inner_fired":false}
  var probe: Dictionary = {"mode":mode, "first":first, "observations":[], "verified_total":0.0, "callback_fired":false}
  var callback: Callable = g06_nested_observer.bind(sim, probe)
  sim.combat_event.connect(callback)
  sim.damage_enemy(first, 1.0, "equipment37_isolated_outer", 0, true, false, {"fixture":true, "direct":false, "active_skill":false, "generation":sim.encounter_generation, "room_id":sim.room_id})
  check(probe.observations.size() == 3, mode + ": three actual source emissions only")
  g06_near(float(probe.verified_total), 7.0, mode + ": verifier authenticates1+2+4 once each")
  g06_near(before_first - float(first.hp), 5.0 if mode == "other_target_middle" else 7.0, mode + ": first target actual inherited HP loss")
  g06_near(before_second - float(second.hp), 2.0 if mode == "other_target_middle" else 0.0, mode + ": second target actual inherited HP loss")
  var seen: Dictionary = {}
  for observation: Dictionary in probe.observations:
   var event: Dictionary = observation.event
   check(not observation.live_attribution.is_empty(), mode + ": each real nested frame has its own live witness")
   var expected: float = 1.0 if event.source == "equipment37_isolated_outer" else (2.0 if event.source == "equipment37_isolated_middle" else 4.0)
   g06_near(float(event.amount), expected, mode + ": original packet's own amount is not a subtree delta")
   check(not seen.has(event.source), mode + ": source packet recorded once")
   seen[event.source] = true
   check(sim.verify_g06_damage_attribution(event).is_empty(), mode + ": finished frame has no replayable witness")
  check(sim.ai_enabled and sim.auto_finish and not sim.paused and not sim.hero.dead and sim.phase == "combat", mode + ": original AI/clock/terminal remain enabled")
  evidence.isolated_nested.append({"mode":mode, "isolated_source_subclass_fixture":true, "original_Host_Session_factory":false, "G06_equipment_or_Model_bound":false, "factor":1.0, "inherited_source_Sim":SIM_PATH, "override":"_hero_outgoing_damage timing only", "spawn_hp_override":G06_HP, "observations":probe.observations.duplicate(true), "actual_first_loss":before_first - float(first.hp), "actual_second_loss":before_second - float(second.hp), "verified_total":probe.verified_total})
  sim.combat_event.disconnect(callback)
  sim.free()
 g06_group_done()

func finish() -> void:
 check(g06_groups == G06_GROUPS, "all seven G06 source and declared fixture groups reached")
 check(check_records.size() == checks, "every assertion retained")
 var report: Dictionary = {"suite":"equipment37_g06_actual_elite_damage_source_gate", "passed":failures.is_empty() and g06_groups == G06_GROUPS, "runtime_status":"EXECUTED", "checks":checks, "failures":failures, "check_records":check_records, "completed_groups":g06_groups, "required_groups":G06_GROUPS, "evidence":evidence, "source_binding_sha256":FileAccess.get_sha256(Binding.BINDING_PATH), "original_factory_session":true, "testwallet_fixture":true, "source_API_packet_fixture":true, "extra_spawned_targets_fixture":true, "original_route_lethal_fixtures":fixture_packets, "actual_q1_p1_input_case_included":true, "isolated_evolved_commerce_fixture":true, "evolved_sale_in_same_combat_Session":false, "actual_g18_runtime_exercised":false, "natural_play":false, "natural_full_floor":false, "native_gui_input":false, "production_ready":false}
 var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
 if file == null:
  push_error("Unable to write equipment37 result: " + output_path); quit(2); return
 file.store_string(JSON.stringify(report, "  "))
 var write_error: Error = file.get_error()
 file.close()
 print("EQUIPMENT37_SOURCE ", JSON.stringify(report))
 quit(2 if write_error != OK else (0 if report.passed else 1))
