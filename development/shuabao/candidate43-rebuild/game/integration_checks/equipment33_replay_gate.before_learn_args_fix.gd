extends "res://integration_checks/postboss_equipment33_gate.gd"
## Real ordinary P1 completion with A05; the historical filename also records
## the G18 admission boundary. G18 record/replay is explicitly NOT_RUN.
## Fixtures: row1 lethal source packets, a declared shop budget, one high-HP
## source-spawned elite in row2. Never submit the augmented room for rewards.
## No direct HP, XP, SP, skill rank, Hex, cast, P1 collector or receipt writes.
const P1Design = preload("res://data/final_design/catalog.gd")
const P1_GATE_PATH := "res://integration_checks/equipment33_replay_gate.gd"
const P1_REQUIRED_GROUPS := ["ordinary_admission_and_g18_boundary", "earned_p1_and_equipment_purchase", "real_q1_p1_final_basis_once"]
const P1_MAX_SPAWN_TICKS := 100
const P1_MAX_COMPLETION_TICKS := 100
var p1_evidence: Dictionary = {}

func _initialize() -> void:
 output_path = "user://equipment33_replay_gate.json"
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--equipment-replay-result="):
   output_path = argument.trim_prefix("--equipment-replay-result=")
 run.call_deferred()

func complete_group(name: String) -> void:
 check(name == current_group and name in P1_REQUIRED_GROUPS and name not in completed_groups, "unique equipment P1 completion marker: " + name)
 completed_groups.append(name)
 print("EQUIPMENT33_P1_GROUP ", name)

func p1_near(actual: float, expected: float, label: String) -> bool:
 return check(is_finite(actual) and is_finite(expected) and absf(actual - expected) < 0.0001, "%s: %.8f expected %.8f" % [label, actual, expected])

func p1_events(f: Dictionary, kind: String, cast_id: int, source: String = "") -> Array:
 var found: Array = []
 for event: Dictionary in f.events:
  if str(event.get("kind", "")) == kind and int(event.get("cast_id", 0)) == cast_id and (source.is_empty() or str(event.get("source", "")) == source):
   found.append(event)
 return found

func p1_receipts(f: Dictionary, cast_id: int) -> Array:
 var found: Array = []
 for receipt: Dictionary in f.sim.ink_p1_receipts:
  if int(receipt.get("cast_id", 0)) == cast_id: found.append(receipt)
 return found

func p1_admission(f: Dictionary) -> bool:
 current_group = P1_REQUIRED_GROUPS[0]
 var model = f.session.ledger.model
 var caps: Dictionary = Binding.read_capabilities(f.sim, true)
 if not check(caps.get("accepted", false), "current exact production binding still admits original factory"): return false
 check("P1" in caps.capabilities.runtime_candidates, "ordinary capability admits the original P1 family")
 var hook := "hex.final_design.common_g18.v1"
 check(hook not in caps.capabilities.supported_hooks and hook not in model.supported_hooks, "G18 remains absent from both exact binding and Model hooks")
 if not check(model.config.hexes.has("common_g18"), "original catalog retains G18 definition for truthful readiness inspection"): return false
 var support: Dictionary = model.support(model.config.hexes.common_g18)
 check(not support.get("supported", true) and hook in support.get("missing_hooks", []), "defined G18 cannot enter this ordinary offer pool")
 check(not f.sim.common.runtime.active("g18"), "original runtime has no forced G18 activation")
 p1_evidence["g18"] = {"status":"NOT_RUN_NOT_ADMITTED", "actual_record_replay":false, "reason":"ordinary_catalog_does_not_admit_common_g18", "support":support, "existing_final_packet_flags":"equipment33_source_gate separately probes replay/snapshot_final flags; those probes are not real G18 recording/replay"}
 complete_group(current_group)
 return true

func p1_prepare(f: Dictionary) -> bool:
 current_group = P1_REQUIRED_GROUPS[1]
 if not prepare_initial_choices(f) or not enter(f, 1) or not settle_fixture_combat(f): return false
 var model = f.session.ledger.model
 var earned: Dictionary = model.snapshot()
 if not check(earned.level == 2 and earned.points == 1 and f.session.row_state.snapshot().completed_rows.size() == 1, "original row1 authenticated rewards earn Lv2 and exactly one unspent SP"): return false
 var learned: Dictionary = command(f, "learn", {"slot_id":"P", "candidate_id":"P1", "expected_rank":0})
 if not check(learned.get("accepted", false), "original progression command spends earned SP to learn P1: " + str(learned.get("reason", ""))): return false
 check(model.state.points == 0 and f.sim.hero.loadout.passive == "p1" and int(f.sim.hero.ranks.passive) == 1, "same Model projects actual P1 rank1 without fixture rank assignment")
 check(f.sim.hero.loadout.q == "q1" and int(f.sim.hero.ranks.q) == 1, "initial original Q1 learning remains intact")
 p1_evidence["earned_progression"] = {"before_learning":earned, "learn_result":learned, "fixture":"row1 original roster defeated by bounded lethal source packets", "natural_acquisition":false}
 p1_evidence["wallet_fixture"] = {"before":model.state.gold, "after":20000, "purpose":"isolated A05 interaction purchase", "production_default_unchanged":true}
 model.state.gold = 20000 # Explicit test-only economy fixture, no XP/SP/rank write.
 if not check(f.session.open_panel().get("accepted", false), "safe original shop opens after real row1 settlement"): return false
 for _index: int in range(2):
  if not check(shop_command(f, "buy", {"item":"final:A05"}).get("accepted", false), "same original shop buys A05 using declared budget"): return false
 check(model.snapshot().passive18_equipment.owned_copies == 2, "two real inventory copies share one passive18 entitlement")
 if not check(f.session.close_panel().get("accepted", false), "original shop closes before real row2 combat"): return false
 check_owners(f, "earned P1 and A05")
 complete_group(current_group)
 return true

func p1_real_completion(f: Dictionary) -> bool:
 current_group = P1_REQUIRED_GROUPS[2]
 if not enter(f, 2): return false
 var authored_count: int = f.sim.enemies.size()
 if not check(authored_count > 0 and authored_count <= MAX_ROOM_ACTORS, "row2 begins with only its bounded original authored roster"): return false
 var spawn_at: Vector3 = f.sim.hero.position + Vector3(0, 0, 4)
 var target: Dictionary = f.sim.spawn_enemy("elite", spawn_at, 10000.0)
 if not check(f.sim.enemies.size() == authored_count + 1 and f.sim.enemies.size() <= MAX_ROOM_ACTORS + 1, "exactly one declared high-HP source actor added for damage observation"): return false
 p1_evidence["target_fixture"] = {"actor_id":target.actor_id, "kind":target.kind, "rank_category":target.rank_category, "requested_position":spawn_at, "max_hp":target.max_hp, "original_roster_size":authored_count, "extra_roster_size":1, "route_settlement_requested":false}
 for _tick: int in range(P1_MAX_SPAWN_TICKS):
  if target.state != "spawn" or f.sim.phase != "combat": break
  step(f)
 if not check(target.state != "spawn" and not target.dead and not f.sim.hero.dead and f.sim.phase == "combat", "original director ends target spawn grace within bounded real steps"): return false
 if not p1_near(float(target.hp), float(target.max_hp), "source target begins the actual cast at full HP"): return false
 var start: Vector3 = target.position
 var end: Vector3 = start + Vector3(0.26, 0, 0)
 check(start.distance_to(f.sim.hero.position) < float(f.sim.tuning.q1_initial_placement_range_m), "chosen genuine Q1 start lies inside original placement radius")
 for enemy: Dictionary in f.sim.living():
  if enemy.actor_id != target.actor_id:
   if not check(Vector3(enemy.position).distance_to(start) > 3.0 + float(enemy.radius), "short cast is isolated from original room actor " + str(enemy.actor_id)): return false
 check(f.sim.ink_p1_receipts.is_empty(), "fresh real row2 owns no prior P1 completion receipt")
 p1_near(float(f.sim.hero.stats.get("common_damage_multiplier", 1.0)), 1.0, "selected personal offer adds no common damage multiplier")
 check(not f.sim.common.runtime.active("g01") and not f.sim.common.runtime.active("g06"), "no unrelated common critical/speed damage modifier in this admitted run")
 var rank: int = int(f.sim.hero.ranks.q)
 var nominal: float = P1Design.parameter("yanguizhou", "Q1-1", rank) + float(f.sim.hero.stats.ap) * P1Design.fraction("yanguizhou", "Q1-2", rank)
 var defence_factor: float = 100.0 / (100.0 + maxf(float(target.defence) - float(f.sim.hero.stats.penetration), 0.0))
 var bonus: float = P1Design.fraction("yanguizhou", "P1-1", int(f.sim.hero.ranks.passive))
 var refund: float = P1Design.fraction("yanguizhou", "P1-2", int(f.sim.hero.ranks.passive))
 var hp_before: float = target.hp
 if not check(f.sim.request_ink_input("q_down").get("accepted", false), "actual Q1 input arms the original skill"): return false
 if not check(f.sim.request_ink_input("left_down", start).get("accepted", false), "actual Q1 input starts at the live target"): return false
 if not check(f.sim.request_ink_input("motion", end).get("accepted", false), "actual Q1 input draws a nonzero original path"): return false
 var released: Dictionary = f.sim.request_ink_input("left_up", end)
 if not check(released.get("accepted", false), "actual Q1 release creates source wave: " + str(released.get("reason", ""))): return false
 var releases: Array = events_of(f, "ink_q1_released")
 if not check(releases.size() == 1, "one genuine Q1 release identifies the new cast"): return false
 var cast_id: int = int(releases[0].cast_id)
 check(cast_id > 0 and f.sim.p1.roots.has(cast_id), "real learned P1 collects the input-created Q1 root")
 check(p1_receipts(f, cast_id).is_empty() and p1_events(f, "damage", cast_id, "yanguizhou_p1").is_empty(), "birth contact alone cannot pay P1 before real path completion")
 for _tick: int in range(P1_MAX_COMPLETION_TICKS):
  if not p1_receipts(f, cast_id).is_empty() or f.sim.phase != "combat": break
  step(f)
 var receipts: Array = p1_receipts(f, cast_id)
 var ordinary: Array = p1_events(f, "damage", cast_id, "q1")
 var supplements: Array = p1_events(f, "damage", cast_id, "yanguizhou_p1")
 var ended: Array = p1_events(f, "ink_q1_finished", cast_id, "q1")
 if not check(receipts.size() == 1 and ordinary.size() == 1 and supplements.size() == 1 and ended.size() == 1, "genuine Q1 endpoint produces exactly one original hit and one P1 settlement"): return false
 var receipt: Dictionary = receipts[0]
 var hit: Dictionary = ordinary[0]
 var supplement: Dictionary = supplements[0]
 check(ended[0].reason == "path_end" and receipt.qualified and int(receipt.distinct_targets) == 1 and int(receipt.ordinary_packet_count) == 1, "real path-end receipt proves the single-target entire-cast condition")
 check(str(receipt.target_id) == str(target.actor_id) and int(receipt.generation) == f.sim.encounter_generation and str(receipt.room_id) == f.sim.room_id, "P1 retains exact target and actual room/generation")
 check(str(hit.target) == str(target.actor_id) and str(supplement.target) == str(target.actor_id), "both damage events refer to the same living source actor")
 p1_near(float(hit.guard_factor), 1.0, "ordinary elite has no active guard mitigation during isolated Q1")
 var expected_original: float = nominal * 1.12 * defence_factor
 p1_near(float(hit.amount), expected_original, "two A05 copies apply exactly one source-defined 12% multiplier to genuine Q1")
 p1_near(float(receipt.final_basis), float(hit.amount), "P1 basis equals already-settled actual ordinary damage including A05")
 p1_near(float(receipt.requested_supplement), float(hit.amount) * bonus, "P1 source ratio applies to the captured final basis")
 p1_near(float(receipt.actual_supplement), float(hit.amount) * bonus, "high-HP target receives proportional supplement without a second A05 multiplier")
 p1_near(float(supplement.amount), float(receipt.actual_supplement), "source P1 damage event equals committed supplemental receipt")
 check(float(supplement.amount) > 0.0 and absf(float(supplement.amount) - float(hit.amount) * bonus * 1.12) > 0.0001, "positive P1 supplement cannot silently reapply giant-hunter multiplier")
 p1_near(hp_before - float(target.hp), float(hit.amount) + float(supplement.amount), "real HP delta contains precisely original plus supplemental actual damage")
 check(supplement.get("p1_supplement", false) and supplement.get("final_damage_already_settled", false) and supplement.get("damage_type", "") == "final_supplement", "actual P1 emits its existing settled-final provenance")
 check(not supplement.get("replay", true) and not supplement.get("hex_generated", true) and receipt.target_status == "live_original" and not receipt.supplement_killed, "P1 remains a nonlethal live-original supplement, with no replay fabrication")
 p1_near(float(receipt.cooldown_refund), float(receipt.cooldown_before) * refund, "original P1 refunds the source fraction of remaining cooldown once")
 p1_near(float(receipt.cooldown_after), float(receipt.cooldown_before) - float(receipt.cooldown_refund), "original remaining cooldown receipt balances")
 var event_position: int = f.events.find(ended[0])
 check(event_position >= 0 and f.events.find(supplement) > event_position, "supplement is observed after the authentic whole-wave terminal event")
 var hp_after: float = target.hp
 step(f, 10)
 check(p1_receipts(f, cast_id).size() == 1 and p1_events(f, "damage", cast_id, "yanguizhou_p1").size() == 1, "continued real source stepping cannot pay the completed P1 twice")
 p1_near(float(target.hp), hp_after, "completed short wave produces no later duplicate target damage")
 check(f.session.status == "combat" and f.session.row_state.snapshot().completed_rows.size() == 1 and f.session.kill_receipts.is_empty(), "augmented row2 never grants route completion or invented kill rewards")
 check(f.event_errors.is_empty() and f.scope_errors.is_empty() and f.session.fault.is_empty(), "all actual P1 and Q1 damage remains authenticated by original Session")
 check_owners(f, "actual P1 completion")
 p1_evidence["actual_p1"] = {"cast_id":cast_id, "nominal_q1":nominal, "a05_multiplier":1.12, "defence_factor":defence_factor, "source_bonus_fraction":bonus, "source_refund_fraction":refund, "original_damage":hit, "terminal":ended[0], "receipt":receipt, "supplement":supplement, "hp_before":hp_before, "hp_after":hp_after, "selected_hex":f.session.ledger.model.state.selected_hex.duplicate(), "real_q1_input":true, "real_q1_terminal":true, "manual_final_packet_flags":false}
 complete_group(current_group)
 return true

func run() -> void:
 if not check(FileAccess.get_sha256(FROZEN_PARENT) == FROZEN_PARENT_SHA, "frozen content01 binding remains exact"): finish(); return
 var f: Dictionary = fresh()
 if f.is_empty(): finish(); return
 if p1_admission(f) and p1_prepare(f): p1_real_completion(f)
 dispose(f)
 finish()

func finish() -> void:
 current_group = "report"
 check(completed_groups == P1_REQUIRED_GROUPS, "all bounded ordinary P1 groups reached completion")
 check(check_records.size() == checks, "every assertion has a recorded outcome")
 var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
 check(file != null, "equipment P1 JSON output can be written: " + output_path)
 var report: Dictionary = {"suite":"equipment33_actual_p1_and_g18_admission_boundary", "passed":failures.is_empty() and completed_groups == P1_REQUIRED_GROUPS, "checks":checks, "failures":failures, "check_records":check_records, "completed_groups":completed_groups, "required_groups":P1_REQUIRED_GROUPS, "evidence":p1_evidence, "fixture_packets":fixture_packets, "source_binding_sha256":FileAccess.get_sha256(Binding.BINDING_PATH), "gate_sha256":FileAccess.get_sha256(P1_GATE_PATH), "base_model_sha256":FileAccess.get_sha256(POSTBOSS_BASE_MODEL_PATH), "ordinary_factory_session":true, "economic_balance_fixture":true, "extra_spawned_targets_fixture":true, "lethal_row1_fixture":true, "direct_HP_XP_SP_rank_assignment":false, "real_P1_completion":"real_q1_p1_final_basis_once" in completed_groups, "actual_g18_record_replay":"NOT_RUN_NOT_ADMITTED", "natural_acquisition":false, "natural_full_floor":false, "GUI_native_input_art":false}
 if file != null:
  file.store_string(JSON.stringify(report, "  "))
  var write_error: Error = file.get_error()
  file.close()
  if write_error != OK:
   check(false, "equipment P1 JSON write completed")
   report.passed = false
 print("EQUIPMENT33_ACTUAL_P1 ", JSON.stringify(report))
 quit(0 if report.passed else 1)
