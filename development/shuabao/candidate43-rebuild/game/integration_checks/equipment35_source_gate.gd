extends "res://integration_checks/postboss_equipment33_gate.gd"
## Source integration fixture only. Use the original Host factories, admitted
## Session, ledger commands, actor creation, spawn grace and damage/healing path.
## The sole direct economic write is the explicitly reported testwallet below.
## Never set inventory, combat stats, HP, position, AI, Hexes or damage claims.
const DISTANCE_MODEL_PATH := "res://equipment_distance_20261009/model.gd"
const ORIGINAL_INK_TUNING = preload("res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_tuning.gd")
const DISTANCES := [3.0, 4.499, 4.5, 4.501, 6.0, 8.999, 9.0, 9.001, 11.0]
const SOURCE_STAT_NAMES := {"AD":"ad", "AP":"ap", "max_hp":"max_hp", "cooldown_reduction":"cdr", "lifesteal":"lifesteal", "penetration":"penetration", "move_speed":"move_speed"}
const MAX_SPAWN_TICKS := 80
const TARGET_HP := 10000.0
var evidence: Dictionary = {"wallet_fixtures":[], "commerce":[], "damage_cases":[]}

func _initialize() -> void:
 output_path = "user://equipment35_source_gate.json"
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--equipment-result="): output_path = argument.trim_prefix("--equipment-result=")
 run.call_deferred()

func check_model_successor(f: Dictionary, label: String) -> void:
 # The inherited fresh() still runs exact Sim/Session/Bridge, binding admission,
 # original-zero-start and all seven owner checks. Only the added Model layer
 # changes; every prior layer and the frozen original SHA remain mandatory.
 var script: Script = f.session.ledger.model.get_script()
 for expected_path: String in [DISTANCE_MODEL_PATH, POSTBOSS_MODEL_PATH, POSTBOSS_PRIOR_MODEL_PATH, POSTBOSS_BASE_MODEL_PATH]:
  if not check(script != null and script.resource_path == expected_path, label + ": exact Model ancestor " + expected_path): return
  script = script.get_base_script()
 check(FileAccess.get_sha256(POSTBOSS_BASE_MODEL_PATH) == POSTBOSS_BASE_MODEL_SHA, label + ": frozen original content01 Model SHA unchanged")

func near_number(actual: float, expected: float, label: String) -> bool:
 return check(is_equal_approx(actual, expected), label + " actual=" + str(actual) + " expected=" + str(expected))

func authority(f: Dictionary) -> Dictionary:
 var model = f.session.ledger.model
 return {"equipment":model.equipment_effects().duplicate(true), "aggregate":model.aggregate_effects().duplicate(true), "current_sim_stats":f.sim.hero.stats.duplicate(true)}

func funded_shop(label: String) -> Dictionary:
 var f: Dictionary = fresh()
 if f.is_empty(): return {}
 if not prepare_initial_choices(f): dispose(f); return {}
 var model = f.session.ledger.model
 f.baseline = authority(f)
 evidence.wallet_fixtures.append({"case":label, "run_id":f.session.run_id, "before":model.state.gold, "after":60000, "test_only":true, "production_default_unchanged":true})
 model.state.gold = 60000 # Explicit testwallet; no inventory/stat/HP fixture writes.
 if not check(f.session.open_panel().get("accepted", false), label + ": original safe shop opens"):
  dispose(f); return {}
 return f

func buy(f: Dictionary, item_id: String) -> bool:
 var result: Dictionary = shop_command(f, "buy", {"item":item_id})
 return check(result.get("accepted", false), "original purchase " + item_id + ": " + str(result.get("reason", "")))

func sell(f: Dictionary, item_id: String) -> bool:
 var held: Dictionary = held_item(f, item_id)
 if not check(not held.is_empty(), "original sell has owned UID for " + item_id): return false
 var result: Dictionary = shop_command(f, "sell", {"uid":held.uid})
 return check(result.get("accepted", false), "original sale " + item_id + ": " + str(result.get("reason", "")))

func undo(f: Dictionary) -> bool:
 var result: Dictionary = shop_command(f, "undo")
 return check(result.get("accepted", false), "original transaction undo: " + str(result.get("reason", "")))

func owned_count(f: Dictionary, item_id: String) -> int:
 var total: int = 0
 for entry: Dictionary in f.session.ledger.model.state.inventory:
  if str(entry.id) == item_id: total += int(entry.count)
 return total

func expected_additions(f: Dictionary, b_copies: int, c_copies: int, a_copies: int = 0) -> Dictionary:
 var result: Dictionary = {"AD":45.0 * b_copies, "AP":90.0 * c_copies, "max_hp":320.0 * b_copies, "cooldown_reduction":0.12 * b_copies, "lifesteal":0.05 if b_copies > 0 else 0.0, "penetration":18.0 * c_copies + (12.0 if c_copies > 0 else 0.0), "move_speed":0.10 * c_copies}
 if a_copies > 0:
  # A05 keeps its original admitted base stats; distance expectations above are
  # frozen constants independent of the implementation under test.
  var prior: Dictionary = f.session.ledger.model.equipment_runtime_status("final:A05").stats
  near_number(float(prior.AD), 55.0, "retained A05 original base AD")
  for key: String in result: result[key] += float(prior.get(key, 0.0)) * a_copies
 return result

func assert_authority(f: Dictionary, b_copies: int, c_copies: int, label: String, a_copies: int = 0) -> Dictionary:
 var current: Dictionary = authority(f)
 var additions: Dictionary = expected_additions(f, b_copies, c_copies, a_copies)
 for key: String in SOURCE_STAT_NAMES:
  var sim_key: String = SOURCE_STAT_NAMES[key]
  var addition: float = additions[key]
  near_number(float(current.equipment.stats.get(key, 0.0)) - float(f.baseline.equipment.stats.get(key, 0.0)), addition, label + ": authoritative equipment " + key)
  near_number(float(current.aggregate.stats.get(key, 0.0)) - float(f.baseline.aggregate.stats.get(key, 0.0)), addition, label + ": authoritative aggregate " + key)
  var expected: float = float(f.baseline.current_sim_stats[sim_key]) + addition
  if key == "move_speed": expected = float(f.baseline.current_sim_stats[sim_key]) + float(ORIGINAL_INK_TUNING.hero_stats().move_speed) * addition
  if key == "cooldown_reduction": expected = minf(0.65, expected)
  near_number(float(current.current_sim_stats[sim_key]), expected, label + ": current Sim " + sim_key)
 var selected: Dictionary = current.equipment.get("distance_passives", {})
 check(not selected.is_empty(), label + ": selection belongs to the authoritative equipment result")
 var passives: Dictionary = selected.get("passives", {})
 check(bool(selected.get("equipped", false)) == (b_copies > 0 or c_copies > 0), label + ": exact equipped state")
 for row: Array in [["passive:14", b_copies, "lifesteal", 0.05], ["passive:15", c_copies, "penetration", 12.0]]:
  var passive_id: String = row[0]
  var count: int = int(row[1])
  check(passives.has(passive_id) == (count > 0), label + ": passive presence " + passive_id)
  if count > 0: check(int(passives[passive_id].owned_copies) == count, label + ": authentic owned copies " + passive_id)
  near_number(float(selected.get("constant_stats", {}).get(row[2], 0.0)), float(row[3]) if count > 0 else 0.0, label + ": unique constant " + str(row[2]))
  check(current.equipment.passives.count(passive_id) == (1 if count > 0 else 0), label + ": one passive identity " + passive_id)
 check(owned_count(f, "final:B03") == b_copies and owned_count(f, "final:C06") == c_copies, label + ": original ledger owns exact copies")
 return current

func definitions_and_scope(f: Dictionary) -> void:
 var model = f.session.ledger.model
 check(model.snapshot().content_profile == "ordinary_equipment35_potions3", "truthful supported content profile is 35 equipment")
 var supported: int = 0
 for definition: Dictionary in model.runtime_stat_definitions.values():
  if definition.get("supported", false): supported += 1
 check(supported == 35, "exactly 35 equipment definitions admitted")
 for row: Array in [["final:B03", {"AD":45.0, "max_hp":320.0, "cooldown_reduction":0.12}, {"range_threshold":4.5, "damage_bonus":12.0, "lifesteal":5.0}], ["final:C06", {"AP":90.0, "penetration":18.0, "move_speed":0.10}, {"range_threshold":9.0, "damage_bonus":15.0, "penetration":12.0}]]:
  var definition: Dictionary = model.equipment_runtime_status(str(row[0]))
  check(definition.get("supported", false), "admitted source definition " + str(row[0]))
  for key: String in row[1]: near_number(float(definition.get("stats", {}).get(key, -1.0)), float(row[1][key]), "frozen base stat " + str(row[0]) + "/" + key)
  for key: String in row[2]: near_number(float(definition.get("distance_passive", {}).get(key, -1.0)), float(row[2][key]), "frozen unique passive " + str(row[0]) + "/" + key)
 var admitted: Dictionary = Binding.read_capabilities(f.sim, true)
 check(admitted.get("accepted", false), "actual factory binding remains verified")
 check("hex.final_design.common_g18.v1" not in admitted.get("capabilities", {}).get("supported_hooks", []), "G18 capability remains outside the admitted slice")
 check(model.config.hexes.has("common_g18") and not model.support(model.config.hexes.common_g18).supported, "real model still refuses unsupported G18")
 check("common_g18" not in model.state.selected_hex and "common_g18" not in f.sim.hero.hexes, "no injected G18 selection or Sim Hex")
 evidence["g18"] = {"admitted":false, "actual_g18_runtime_exercised":false, "scope":"Only ordinary damage-pipeline finalized/replay metadata exclusions; no G18 enablement or G18 acceptance claim."}

func commerce_case() -> void:
 current_group = "equipment35_authoritative_commerce"
 var f: Dictionary = funded_shop(current_group)
 if f.is_empty(): return
 definitions_and_scope(f)
 assert_authority(f, 0, 0, "empty baseline")
 buy(f, "final:B03"); assert_authority(f, 1, 0, "one B03")
 buy(f, "final:B03"); assert_authority(f, 2, 0, "two B03 base stacks, one constant")
 buy(f, "final:C06"); assert_authority(f, 2, 1, "one C06 penetration 18 plus unique 12")
 buy(f, "final:C06"); assert_authority(f, 2, 2, "two C06 penetration 36 plus unique 12")
 var stable: Dictionary = authority(f)
 var held_before: PackedByteArray = var_to_bytes(f.session.ledger.model.state.inventory)
 for _repeat: int in range(5):
  f.sim.refresh_passive23() # Existing projection owner only; no test stat writes.
  f.session.update_after_source_step()
 check(stable == authority(f), "repeated real stat synchronization does not accumulate unique constants")
 check(held_before == var_to_bytes(f.session.ledger.model.state.inventory), "stat synchronization leaves original inventory unchanged")
 evidence.commerce.append({"stage":"two_each", "authority":stable})
 sell(f, "final:B03"); assert_authority(f, 1, 2, "sell one B03 retains constant")
 sell(f, "final:B03"); assert_authority(f, 0, 2, "sell last B03 clears constant")
 undo(f); assert_authority(f, 1, 2, "undo last B03 sale restores constant once")
 undo(f); assert_authority(f, 2, 2, "undo first B03 sale restores only base stack")
 sell(f, "final:C06"); assert_authority(f, 2, 1, "sell one C06 retains extra penetration")
 sell(f, "final:C06"); assert_authority(f, 2, 0, "sell last C06 clears extra penetration")
 undo(f); assert_authority(f, 2, 1, "undo last C06 sale restores extra penetration once")
 undo(f); assert_authority(f, 2, 2, "undo first C06 sale restores only base stack")
 undo(f); assert_authority(f, 2, 1, "undo second C06 purchase")
 undo(f); assert_authority(f, 2, 0, "undo first C06 purchase clears passive")
 undo(f); assert_authority(f, 1, 0, "undo second B03 purchase")
 undo(f); assert_authority(f, 0, 0, "undo first B03 purchase clears passive")
 evidence.commerce.append({"stage":"all_purchases_undone", "authority":authority(f)})
 check_owners(f, "commerce retains original ownership")
 dispose(f)

func distance_factor(distance: float, b_copies: int, c_copies: int) -> float:
 var factor: float = 1.0
 if b_copies > 0 and distance <= 4.5: factor *= 1.12
 if c_copies > 0 and distance >= 9.0: factor *= 1.15
 return factor

func expected_factor(enemy: Dictionary, distance: float, b_copies: int, c_copies: int, a_copies: int) -> float:
 var factor: float = distance_factor(distance, b_copies, c_copies)
 if a_copies > 0 and str(enemy.rank_category) in ["elite", "boss"]:
  var lost_percent: float = (float(enemy.max_hp) - float(enemy.hp)) / float(enemy.max_hp) * 100.0
  factor *= 1.0 + minf(20.0, 12.0 + floor(lost_percent / 25.0) * 2.0) / 100.0
 return factor

func source_hit(f: Dictionary, enemy: Dictionary, nominal: float, extra: Dictionary = {}, is_true: bool = true) -> Dictionary:
 var metadata: Dictionary = {"fixture":true, "direct":false, "no_reactions":true, "generation":f.sim.encounter_generation, "room_id":f.sim.room_id}
 metadata.merge(extra, true)
 var hp_before: float = enemy.hp
 var hero_hp_before: float = f.sim.hero.hp
 var start_event: int = f.events.size()
 f.sim.damage_enemy(enemy, nominal, "equipment35_source_fixture", 0, is_true, false, metadata)
 var damages: Array = []
 for index: int in range(start_event, f.events.size()):
  var event: Dictionary = f.events[index]
  if event.get("kind", "") == "damage" and event.get("target", "") == enemy.actor_id and event.get("source", "") == "equipment35_source_fixture": damages.append(event.duplicate(true))
 return {"actual":hp_before - float(enemy.hp), "hero_healed":float(f.sim.hero.hp) - hero_hp_before, "damage_events":damages, "nominal":nominal, "true_damage":is_true, "distance_at_contact":Vector3(f.sim.hero.position).distance_to(enemy.position), "target_id":enemy.actor_id, "target_kind":enemy.kind, "metadata":metadata}

func check_packet(packet: Dictionary, expected: float, label: String) -> void:
 near_number(float(packet.actual), expected, label + ": real target HP loss")
 check(packet.damage_events.size() == (0 if expected == 0.0 else 1), label + ": exact source damage event count")
 if not packet.damage_events.is_empty(): near_number(float(packet.damage_events[0].amount), expected, label + ": source event agrees with HP loss")

func make_contact_targets(f: Dictionary) -> Array:
 var targets: Array = []
 var origin: Vector3 = f.sim.hero.position
 # All spawn in the real open central corridor. Cardinal offsets make the
 # inclusive 4.5 and 9.0 boundaries exact. No dictionary/actor position writes.
 for distance: float in DISTANCES:
  var enemy: Dictionary = f.sim.spawn_enemy("minion", origin + Vector3(0.0, 0.0, -distance), TARGET_HP)
  targets.append({"enemy":enemy, "distance":distance, "spawn_position":enemy.position})
 for kind: String in ["elite", "boss"]:
  for distance: float in [4.5, 6.0, 9.0]:
   var enemy: Dictionary = f.sim.spawn_enemy(kind, origin + Vector3(0.0, 0.0, -distance), TARGET_HP)
   targets.append({"enemy":enemy, "distance":distance, "spawn_position":enemy.position})
 check(targets.size() == 15, "exactly fifteen declared source-spawned contact targets")
 check(f.sim.ai_enabled and not f.sim.paused, "spawn grace uses enabled original AI and running source clock")
 for _tick: int in range(MAX_SPAWN_TICKS):
  var waiting: bool = false
  for entry: Dictionary in targets:
   if entry.enemy.state == "spawn": waiting = true
  if not waiting: break
  step(f)
 for entry: Dictionary in targets:
  check(entry.enemy.state != "spawn" and not entry.enemy.dead, "real spawn grace completed for " + str(entry.enemy.actor_id))
  check(entry.enemy.position == entry.spawn_position and f.sim.hero.position == origin, "first available contact precedes AI movement; no fixture teleports")
  check(absf(Vector3(f.sim.hero.position).distance_to(entry.enemy.position) - float(entry.distance)) < 0.000001, "actual unclipped contact distance " + str(entry.distance))
 return targets

func ordinary_mitigation_and_healing(f: Dictionary, targets: Array, b_copies: int, c_copies: int, a_copies: int) -> Array:
 var records: Array = []
 var expected_penetration: float = float(f.baseline.current_sim_stats.penetration) + float(expected_additions(f, b_copies, c_copies, a_copies).penetration)
 var expected_lifesteal: float = float(f.baseline.current_sim_stats.lifesteal) + (0.05 if b_copies > 0 else 0.0)
 # Actual nontrue damage against the unchanged source Boss defence of 38 makes
 # C06's 18+12 distinguishable from either 18 alone or an erroneous second +12.
 for entry: Dictionary in targets:
  var enemy: Dictionary = entry.enemy
  if enemy.kind != "boss": continue
  near_number(float(enemy.defence), 38.0, "original Boss defence retained")
  var expected: float = 100.0 * expected_factor(enemy, float(entry.distance), b_copies, c_copies, a_copies) * 100.0 / (100.0 + maxf(0.0, 38.0 - expected_penetration))
  var packet: Dictionary = source_hit(f, enemy, 100.0, {}, false)
  check_packet(packet, expected, "real mitigation at " + str(entry.distance) + "m")
  records.append(packet)
 # Use real damage_hero followed immediately by reaction-enabled basic-shaped
 # packets. No tick elapses, so source regeneration cannot fake lifesteal.
 var hero_before: float = f.sim.hero.hp
 f.sim.damage_hero(40.0, Vector3.ZERO, 0.0, true, true, {"fixture":true, "direct":false, "damage_provenance":"equipment35_lifesteal_observation"})
 near_number(hero_before - float(f.sim.hero.hp), 40.0, "real nonlethal damage creates observed healing room")
 for entry: Dictionary in targets:
  var enemy: Dictionary = entry.enemy
  if enemy.kind != "minion" or float(entry.distance) not in [4.5, 6.0, 9.0]: continue
  var expected: float = 100.0 * distance_factor(float(entry.distance), b_copies, c_copies)
  var packet: Dictionary = source_hit(f, enemy, 100.0, {"no_reactions":false, "direct":true, "basic_attack":true, "area":false, "active_skill":false, "crit_rolled":true}, false)
  check_packet(packet, expected, "reaction-enabled ordinary contact at " + str(entry.distance) + "m")
  near_number(float(packet.hero_healed), expected * expected_lifesteal, "actual unique lifesteal remains constant at " + str(entry.distance) + "m")
  packet["expected_lifesteal_rate"] = expected_lifesteal
  records.append(packet)
 return records

func damage_case(label: String, b_initial: int, c_initial: int, a_copies: int = 0, removal: String = "") -> void:
 current_group = "equipment35_source_" + label
 var f: Dictionary = funded_shop(label)
 if f.is_empty(): return
 for _copy: int in range(b_initial): buy(f, "final:B03")
 for _copy: int in range(c_initial): buy(f, "final:C06")
 for _copy: int in range(a_copies): buy(f, "final:A05")
 var b_copies: int = b_initial
 var c_copies: int = c_initial
 if removal in ["sale", "sale_undo"]:
  for _copy: int in range(b_initial): sell(f, "final:B03")
  for _copy: int in range(c_initial): sell(f, "final:C06")
  b_copies = 0; c_copies = 0
  assert_authority(f, 0, 0, label + " removed", a_copies)
  if removal == "sale_undo":
   for _copy: int in range(b_initial + c_initial): undo(f)
   b_copies = b_initial; c_copies = c_initial
 elif removal == "buy_undo":
  for _copy: int in range(b_initial + c_initial): undo(f)
  b_copies = 0; c_copies = 0
 var shop_authority: Dictionary = assert_authority(f, b_copies, c_copies, label + " precombat", a_copies)
 if a_copies > 0:
  check(int(f.session.ledger.model.snapshot().passive18_equipment.owned_copies) == a_copies, "retained A05 authentic duplicate inventory")
 if not check(f.session.close_panel().get("accepted", false), label + ": original shop closes") or not enter(f, 1):
  dispose(f); return
 var targets: Array = make_contact_targets(f)
 var combat_authority: Dictionary = assert_authority(f, b_copies, c_copies, label + " real combat", a_copies)
 var packets: Array = []
 for entry: Dictionary in targets:
  var enemy: Dictionary = entry.enemy
  var expected: float = 100.0 * expected_factor(enemy, float(entry.distance), b_copies, c_copies, a_copies)
  var packet: Dictionary = source_hit(f, enemy, 100.0)
  check_packet(packet, expected, label + " " + str(enemy.kind) + " " + str(entry.distance) + "m")
  packet["expected"] = expected
  packets.append(packet)
  check(authority(f) == combat_authority, "near/middle/far contact never changes authoritative constant stats")
 # A single effect ID may hit distinct targets once each. A same-target retry
 # must neither damage nor emit a second receipt, including across distances.
 var close: Dictionary = targets[2].enemy
 var far: Dictionary = targets[6].enemy
 var effect_id: String = label + ":one-shared-effect"
 var first: Dictionary = source_hit(f, close, 20.0, {"effect_id":effect_id})
 var second_target: Dictionary = source_hit(f, far, 20.0, {"effect_id":effect_id})
 var retry: Dictionary = source_hit(f, close, 20.0, {"effect_id":effect_id})
 check_packet(first, 20.0 * distance_factor(4.5, b_copies, c_copies), "shared effect first close target")
 check_packet(second_target, 20.0 * distance_factor(9.0, b_copies, c_copies), "shared effect independently samples far target")
 check_packet(retry, 0.0, "same effect and same target retry is idempotent")
 var finalized: Array = []
 for entry: Dictionary in targets:
  if entry.enemy.kind != "boss" or float(entry.distance) not in [4.5, 9.0]: continue
  for flags: Dictionary in [{"snapshot_final":true}, {"replay":true}, {"snapshot_final":true, "replay":true}]:
   var packet: Dictionary = source_hit(f, entry.enemy, 137.0, flags)
   check_packet(packet, 137.0, "already-final source packet skips A05 and distance multipliers")
   finalized.append(packet)
 var mechanics: Array = ordinary_mitigation_and_healing(f, targets, b_copies, c_copies, a_copies)
 assert_authority(f, b_copies, c_copies, label + " after real damage and healing", a_copies)
 check(f.sim.ai_enabled and not f.sim.hero.dead and f.sim.phase == "combat", "source fixture leaves live original combat and AI intact")
 check(f.event_errors.is_empty() and f.scope_errors.is_empty() and f.session.fault.is_empty(), "authentic damage events keep original Session scope")
 check_owners(f, label + " final")
 evidence.damage_cases.append({"case":label, "initial_copies":{"B03":b_initial, "C06":c_initial, "A05":a_copies}, "final_copies":{"B03":b_copies, "C06":c_copies, "A05":a_copies}, "commerce_removal":removal, "shop_authority":shop_authority, "combat_authority":combat_authority, "target_count":targets.size(), "contacts":packets, "dedupe":[first, second_target, retry], "finalized_metadata_packets":finalized, "ordinary_damage_and_healing":mechanics, "route_rewards_submitted":false})
 # Augmented targets are deliberately never settled for route rewards.
 dispose(f)

func run() -> void:
 commerce_case()
 for row: Array in [["b03_one", 1, 0], ["b03_two", 2, 0], ["c06_one", 0, 1], ["c06_two", 0, 2], ["both_one", 1, 1], ["both_two", 2, 2]]:
  damage_case(str(row[0]), int(row[1]), int(row[2]))
 damage_case("a05_preserved_with_both_two", 2, 2, 2)
 damage_case("last_sales_clear_before_combat", 1, 1, 0, "sale")
 damage_case("purchase_undo_clears_before_combat", 1, 1, 0, "buy_undo")
 damage_case("sale_undo_restores_before_combat", 1, 1, 0, "sale_undo")
 check(evidence.damage_cases.size() == 10, "all ten independent source cases completed")
 finish()

func finish() -> void:
 var result: Dictionary = {"passed":failures.is_empty(), "checks":checks, "failures":failures, "check_records":check_records, "evidence":evidence, "testwallet_fixture":true, "economic_balance_fixture":true, "extra_spawned_targets_fixture":true, "real_source_damage":true, "real_source_mitigation":true, "real_source_lifesteal":true, "original_factory_session":true, "actual_g18_runtime_exercised":false, "replay_scope":"finalized metadata pipeline exclusion only", "natural_play":false, "gui_native_input_covered":false, "source_binding_sha256":FileAccess.get_sha256(Binding.BINDING_PATH)}
 var file = FileAccess.open(output_path, FileAccess.WRITE)
 if file == null: quit(2); return
 file.store_string(JSON.stringify(result, "  ")); file.close()
 print("EQUIPMENT35_SOURCE ", JSON.stringify(result))
 quit(0 if result.passed else 1)
