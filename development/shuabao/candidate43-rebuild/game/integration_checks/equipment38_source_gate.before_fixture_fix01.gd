extends "res://integration_checks/equipment37_source_gate.gd"
## Source gate only. The author does not launch Godot or a GUI. The parent
## seals candidate09 and runs this entry serially. No native-input/play claim.
const B04_MODEL := "res://equipment_basic_cycle_20261009/model.gd"
const B04Prior = preload("res://equipment_elite_damage_20261009/adapter.gd")
const B04_GROUPS := ["definitions_and_commerce", "real_cycles_and_replays", "cancel_clear_and_nonbasic", "birth_and_final_enemy_order", "original_route_and_shop_lifecycle", "isolated_common_finish_boundaries"]
var b04_groups: Array[String] = []

# Explicit isolated callback fixture, never returned by Host and never bound
# to a substitute Session. The full inherited common.complete_action executes
# before this timing hook, while the original finish_cast is still on stack.
class B04CommonProbe extends "res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_common_bridge.gd":
 var callback: Callable
 func _init(source) -> void:
  super(source)
 func complete_action(id: int, cancelled: bool = false, wait_for_motion: bool = false) -> void:
  super.complete_action(id, cancelled, wait_for_motion)
  if callback.is_valid(): callback.call(id, cancelled)

class B04FinishProbe extends "res://tests/ink_river_hexes_20261006/ordinary01/sim.gd":
 var fixture_matches: Array = []
 func _b04_consume_original_completion(data: Dictionary) -> Dictionary:
  var matches: bool = not _b04_terminal_frames.is_empty() and _b04_frame_matches(_b04_terminal_frames.back(), data)
  fixture_matches.append({"event":data.duplicate(true), "matches":matches, "phase":phase, "transaction_active":transaction_active})
  return super._b04_consume_original_completion(data)

func _initialize() -> void:
 output_path = "user://equipment38_source_gate.json"
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--equipment-result="): output_path = argument.trim_prefix("--equipment-result=")
 run.call_deferred()

func check_model_successor(f: Dictionary, label: String) -> void:
 var script: Script = f.session.ledger.model.get_script()
 for path: String in [B04_MODEL, G06_MODEL, B01_MODEL, DISTANCE_MODEL_PATH, POSTBOSS_MODEL_PATH, POSTBOSS_PRIOR_MODEL_PATH, POSTBOSS_BASE_MODEL_PATH]:
  if not check(script != null and script.resource_path == path, label + ": exact equipment38 Model ancestor " + path): return
  script = script.get_base_script()
 check(FileAccess.get_sha256(POSTBOSS_BASE_MODEL_PATH) == POSTBOSS_BASE_MODEL_SHA, label + ": frozen original Model SHA retained")

func funded_shop(label: String) -> Dictionary:
 # Reuse every original fresh()/factory/navigation/owner assertion. Only the
 # expected leaf changes; no superclass leaf assertion is silently disabled.
 var f: Dictionary = fresh()
 if f.is_empty(): return {}
 if not prepare_initial_choices(f): dispose(f); return {}
 var model = f.session.ledger.model
 f.baseline = authority(f)
 f["b04_completions"] = []
 f["b04_diagnostics"] = []
 f["b04_trace"] = []
 f["b04_synthetic"] = false
 f["b04_observer_action"] = ""
 f["b04_original_states"] = {}
 f["b04_release_clocks"] = {}
 # Preserve inherited observer fixtures so the parent can run prior G06/B01
 # source groups against this exact successor factory in a separate wrapper.
 f["g06_damage"] = []
 f["g06_targets"] = []
 f["g06_attack"] = {}
 f["g06_attack_records"] = []
 f["live_kills"] = []
 evidence.wallet_fixtures.append({"case":label, "run_id":f.session.run_id, "before":model.state.gold, "after":60000, "test_only":true})
 model.state.gold = 60000 # The sole explicit direct wallet fixture.
 if not check(model.get_script().resource_path == B04_MODEL and f.sim.has_method("verify_b04_basic_completion"), "exact B04 source/Model bridge") or not check(model.equipment_runtime_status("final:B04").get("runtime_complete", false), "B04 bound by original factory") or not check(f.session.open_panel().get("accepted", false), label + ": original safe shop opens"):
  dispose(f); return {}
 return f

func b04_status(f: Dictionary) -> Dictionary:
 return f.session.ledger.model.basic_cycle_status().duplicate(true)

func b04_remainder(f: Dictionary) -> int:
 return int(b04_status(f).remainder)

func b04_receipts(f: Dictionary) -> Array:
 var found: Array = []
 for id: String in f.session.ledger.model.receipts:
  var receipt: Dictionary = f.session.ledger.model.receipts[id]
  if receipt.request.action == "b04_verified_basic_completion" and receipt.result.get("accepted", false):
   found.append({"id":id, "request":receipt.request.duplicate(true), "result":receipt.result.duplicate(true)})
 return found

func b04_receipt(f: Dictionary, cast_id: int, generation: int) -> Dictionary:
 for receipt: Dictionary in b04_receipts(f):
  var proposal: Dictionary = receipt.result.get("b04_completion", {})
  if int(proposal.get("claim_to_add", {}).get("cast_id", -1)) == cast_id and int(proposal.get("scope", {}).get("generation", -1)) == generation: return receipt
 return {}

func b04_protected(f: Dictionary) -> Dictionary:
 var state: Dictionary = f.session.ledger.model.state
 return {"progress":state.get("b04_basic_cycle", {}).duplicate(true), "receipts":b04_receipts(f), "tasks":state.shop_visit.taskLedger.duplicate(true), "completed":state.completed_equipment_tasks.duplicate(true), "awards":state.bonus_awards.duplicate(true), "bonus_sp":state.bonus_sp}

func on_event(event: Dictionary, f: Dictionary) -> void:
 # The source commits B04 before ANY original event observer. Capture before
 # the single inherited Session observation, without making a positive event.
 var captured: Dictionary = {}
 var kind: String = str(event.get("kind", ""))
 if f.has("b04_completions"):
  if kind == "ink_basic_released":
   f.b04_release_clocks[str(event.generation) + ":" + str(event.cast_id)] = {"at":f.sim.hero_time, "attack":f.sim.hero.cooldowns.attack}
   for state: Dictionary in f.sim.ink_basics:
    if int(state.cast_id) == int(event.cast_id): f.b04_original_states[str(event.generation) + ":" + str(event.cast_id)] = state
  if kind in ["kill", "ink_basic_finished", "equipment_b04_cycle", "encounter_finished"]:
   f.b04_trace.append({"kind":kind, "sequence":event.sequence, "cast_id":event.get("cast_id", 0), "phase":f.sim.phase, "remainder":b04_remainder(f), "synthetic":f.b04_synthetic})
  if kind == "ink_basic_finished":
   var cast_id: int = int(event.cast_id)
   captured = {"event":event.duplicate(true), "synthetic":f.b04_synthetic, "phase":f.sim.phase, "hero_time":f.sim.hero_time, "transaction_active":f.sim.transaction_active, "status":b04_status(f), "cooldowns":f.sim.hero.cooldowns.duplicate(true), "receipt":b04_receipt(f, cast_id, int(event.generation)), "cast":f.sim._casts.get(cast_id, {}).duplicate(true), "cd_fixture":f.get("b04_cd_fixture", {}).duplicate(true), "release_clock":f.b04_release_clocks.get(str(event.generation) + ":" + str(cast_id), {}).duplicate(true)}
   f.b04_completions.append(captured)
  if kind == "equipment_b04_cycle": f.b04_diagnostics.append(event.duplicate(true))
 super.on_event(event, f)
 if captured.is_empty() or captured.synthetic or str(f.b04_observer_action).is_empty(): return
 var action: String = f.b04_observer_action
 f.b04_observer_action = ""
 if action == "cancel": f.sim.cancel_cast(int(event.cast_id))
 elif action == "close": f.session.close_run()
 elif action == "death": f.sim.damage_hero(float(f.sim.hero.hp) + 100000.0, Vector3.ZERO, 0.0, true, true, {"fixture":true, "purpose":"postcompletion observer death"})
 evidence.postcompletion.append({"action":action, "observer":captured, "after":b04_protected(f), "phase_after":f.sim.phase})

func b04_done() -> void:
 check(current_group in B04_GROUPS and current_group not in b04_groups, "unique B04 source group " + current_group)
 b04_groups.append(current_group)

func b04_stats(f: Dictionary, copies: int, label: String) -> void:
 var current: Dictionary = authority(f)
 for row: Array in [["AD", "ad", 42.0], ["cooldown_reduction", "cdr", 0.18], ["crit_chance", "crit_chance", 0.15]]:
  near_number(float(current.equipment.stats.get(row[0], 0.0)) - float(f.baseline.equipment.stats.get(row[0], 0.0)), float(row[2]) * copies, label + ": per-copy equipment " + row[0])
  near_number(float(current.current_sim_stats[row[1]]) - float(f.baseline.current_sim_stats[row[1]]), float(row[2]) * copies, label + ": original same-Sim stat consumer " + row[1])
 check(int(b04_status(f).owned_copies) == copies and int(b04_status(f).active_copies) == (1 if copies > 0 else 0), label + ": one player/passive consumer")
 check(current.equipment.passives.count("passive:08") == (1 if copies > 0 else 0), label + ": unique passive identity")

func b04_combat(copies: int, label: String) -> Dictionary:
 var f: Dictionary = funded_shop(label)
 if f.is_empty(): return {}
 for _copy: int in range(copies):
  if not buy(f, "final:B04"): dispose(f); return {}
 b04_stats(f, copies, label)
 if not check(f.session.close_panel().get("accepted", false), "original shop closes") or not enter(f, 1) or not spawn_ready(f): dispose(f); return {}
 return f

func b04_keep_original(f: Dictionary) -> Dictionary:
 # Never add an unregistered enemy that prevents an original room terminal.
 var target: Dictionary = {}
 for enemy: Dictionary in f.sim.living():
  if target.is_empty() or enemy.kind == "ranged": target = enemy
 if not check(not target.is_empty() and str(target.actor_id) in f.session.expected_enemies, "retain one actual entered enemy"): return {}
 for enemy: Dictionary in f.sim.living().duplicate():
  if not is_same(enemy, target): lethal_enemy_fixture(f, enemy, "B04 fixture retains one original route actor")
 check(f.sim.living().size() == 1 and f.sim.ai_enabled and f.sim.auto_finish, "one original live target; original AI/auto-finish remain enabled")
 return target

func b04_settle_row(f: Dictionary, row: int) -> bool:
 # Earlier setup may already have killed other entered actors. Keep the
 # original roster-wide receipt count, rather than treating survivors as the
 # whole encounter (the generic inherited fixture assumes all remain alive).
 if not spawn_ready_survivors(f): return false
 for enemy: Dictionary in f.sim.living().duplicate(): lethal_enemy_fixture(f, enemy, "B04 advance original row " + str(row))
 return settle_original_row(f, row)

func spawn_ready_survivors(f: Dictionary) -> bool:
 for _tick: int in range(100):
  var spawning: bool = false
  for enemy: Dictionary in f.sim.living():
   if enemy.state == "spawn": spawning = true
  if not spawning: return true
  step(f)
 return check(false, "remaining original roster completes spawn grace")

func b04_ready(f: Dictionary) -> bool:
 for _tick: int in range(300):
  if f.sim.phase != "combat" or f.sim.hero.dead or f.sim.paused: break
  if float(f.sim.hero.cooldowns.attack) <= f.sim.TIME_EPS and float(f.sim.hero.lock_time) <= f.sim.TIME_EPS and float(f.sim.hero.stun_left) <= f.sim.TIME_EPS: return true
  step(f)
 return check(false, "original basic input becomes ready within bounded source steps")

func b04_empty_aim(f: Dictionary) -> Vector3:
 var origin: Vector3 = f.sim.hero.position
 var length: float = float(f.sim.hero.stats.attack_range)
 var best: Vector3 = Vector3.INF
 var best_clearance: float = -INF
 for index: int in range(32):
  var angle: float = TAU * float(index) / 32.0
  var direction: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
  var destination: Vector3 = origin + direction * length
  if f.sim._move_clipped(origin, destination, float(f.sim.v("ATK-4")) * 0.5).distance_to(destination) > 0.00001: continue
  var clearance: float = INF
  for enemy: Dictionary in f.sim.living():
   var along: float = clampf(Vector3(enemy.position - origin).dot(direction), 0.0, length)
   clearance = minf(clearance, Vector3(enemy.position).distance_to(origin + direction * along) - float(enemy.radius))
  if clearance > best_clearance: best = destination; best_clearance = clearance
 check(best.is_finite() and best_clearance > float(f.sim.v("ATK-4")) * 0.5, "choose a real clear empty trajectory, without moving actors")
 return best

func b04_launch(f: Dictionary, aim: Vector3) -> Dictionary:
 if not b04_ready(f): return {}
 var down := InputEventMouseButton.new()
 down.button_index = MOUSE_BUTTON_LEFT; down.pressed = true
 var result: Dictionary = f.router.handle_event(down, aim)
 var up := InputEventMouseButton.new()
 up.button_index = MOUSE_BUTTON_LEFT; up.pressed = false
 f.router.handle_event(up, aim)
 if not check(result.get("accepted", false), "ordinary LMB routes to actual start_basic: " + str(result.get("reason", ""))): return {}
 evidence.inputs.append({"generation":f.sim.encounter_generation, "aim":aim, "result":result.duplicate(true), "route":"original router LMB pair", "native_GUI":false})
 return result

func b04_wait_finish(f: Dictionary, cast_id: int, generation: int) -> Dictionary:
 for _tick: int in range(180):
  for observation: Dictionary in f.b04_completions:
   if not observation.synthetic and int(observation.event.cast_id) == cast_id and int(observation.event.generation) == generation: return observation
  if f.sim.phase != "combat" or f.sim.hero.dead: break
  step(f)
 check(false, "actual basic reaches its original terminal within bounded source steps")
 return {}

func b04_shot(f: Dictionary) -> Dictionary:
 if not b04_ready(f): return {}
 var generation: int = f.sim.encounter_generation
 var result: Dictionary = b04_launch(f, b04_empty_aim(f))
 if result.is_empty(): return {}
 var observation: Dictionary = b04_wait_finish(f, int(result.cast_id), generation)
 if observation.is_empty(): return {}
 check(observation.event.reason == "path_end" and observation.event.hit_target_ids.is_empty(), "empty swing naturally reaches path_end and counts")
 return observation

func b04_check_completion(f: Dictionary, observation: Dictionary, before: int, after: int, triggered: bool, label: String) -> void:
 if not check(not observation.is_empty() and not observation.receipt.is_empty(), label + ": original Model receipt already exists at first completion observer"): return
 var proposal: Dictionary = observation.receipt.result.b04_completion
 check(proposal.remainder_before == before and proposal.remainder_after == after and proposal.triggered == triggered, label + ": exact count and fifth-completion boundary")
 check(int(observation.status.remainder) == after and int(observation.status.active_copies) == 1 and observation.cast.finished and not observation.cast.cancelled, label + ": observer sees committed count and original finished cast")
 for slot: String in ["q", "e"]:
  near_number(float(proposal.cooldowns_after[slot]), float(proposal.cooldowns_before[slot]) * (0.9 if triggered else 1.0), label + ": completion-time current " + slot + " × correct factor")
  near_number(float(observation.cooldowns[slot]), float(proposal.cooldowns_after[slot]), label + ": both CDs committed before original observer " + slot)
 if not observation.cd_fixture.is_empty():
  var elapsed: float = float(observation.hero_time) - float(observation.cd_fixture.at)
  for slot: String in ["r", "shift"]:
   near_number(float(observation.cooldowns[slot]), maxf(0.0, float(observation.cd_fixture.cooldowns[slot]) - elapsed), label + ": B04 leaves original " + slot + " clock unchanged")
 if not observation.release_clock.is_empty():
  near_number(float(observation.cooldowns.attack), maxf(0.0, float(observation.release_clock.attack) - float(observation.hero_time) + float(observation.release_clock.at)), label + ": B04 leaves original basic cadence unchanged")
 check(observation.phase == "combat", label + ": original completion occurs before terminal cleanup")
 check(f.session.ledger.model.state.shop_visit.taskLedger.get(str(f.session.ledger.model.state.actor_id) + "|final:B04", {}).is_empty(), label + ": B04 never creates an equipment task")
 evidence.completions.append(observation.duplicate(true))

func b04_seed(f: Dictionary, count: int) -> bool:
 for _index: int in range(count):
  var before: int = b04_remainder(f)
  var observation: Dictionary = b04_shot(f)
  if observation.is_empty(): return false
  b04_check_completion(f, observation, before, (before + 1) % 5, before == 4, "real seed")
 return true

func b04_cd_fixture(f: Dictionary, q: float, e: float) -> void:
 for row: Array in [["q", q], ["e", e], ["r", 31.0], ["shift", 17.0]]:
  f.sim.start_skill_cooldown(str(row[0]), float(row[1]))
 f["b04_cd_fixture"] = {"at":f.sim.hero_time, "cooldowns":f.sim.hero.cooldowns.duplicate(true)}
 evidence.cooldown_fixtures.append({"api":"original start_skill_cooldown", "bases":{"q":q, "e":e, "r":31.0, "shift":17.0}, "actual":f.sim.hero.cooldowns.duplicate(true), "actual_QE_input":false})

func b04_integrity(f: Dictionary, label: String) -> void:
 check(f.event_errors.is_empty() and f.scope_errors.is_empty() and f.session.fault.is_empty(), label + ": original Session authenticates every source event")
 check_owners(f, label)

func b04_definitions() -> void:
 current_group = B04_GROUPS[0]
 var f: Dictionary = funded_shop(current_group)
 if f.is_empty(): return
 var model = f.session.ledger.model
 var numeric: Variant = JSON.parse_string(FileAccess.get_file_as_string(B01_NUMERIC))
 var prior: Dictionary = B04Prior.build(numeric)
 if not check(prior.get("accepted", false), "prior37 original adapter accepts source"): dispose(f); return
 check(model.runtime_stat_definitions.size() == prior.definitions.size() + 1, "only B04 extends prior37 definitions")
 for id: String in prior.definitions:
  check(var_to_bytes(prior.definitions[id]) == var_to_bytes(model.runtime_stat_definitions.get(id, {})), "prior37 definition deeply unchanged: " + id)
 var supported: int = 0
 for definition: Dictionary in model.runtime_stat_definitions.values():
  if definition.get("supported", false): supported += 1
 var status: Dictionary = model.equipment_runtime_status("final:B04")
 check(supported == 38 and model.snapshot().content_profile == "ordinary_equipment38_potions3", "truthful supported38 profile")
 check(status.stats == {"AD":42.0, "cooldown_reduction":0.18, "crit_chance":0.15} and status.passives == ["passive:08"], "B04 authored AD42/CDR18%/crit15% and only passive08")
 check(status.passive08 == {"attack_interval":5, "remaining_cooldown_reduction":10.0}, "original five completions and10% remaining-CD reduction")
 check(int(model.commerce_definitions.items["final:B04"].price) == 3000 and int(status.recipe.combine_fee) == 550, "original3000 price and550 combine fee")
 var gold: int = model.state.gold
 buy(f, "final:B04"); b04_stats(f, 1, "one B04")
 check(int(model.state.gold) == gold - 3000, "original purchase charges3000")
 buy(f, "final:B04"); b04_stats(f, 2, "two B04")
 sell(f, "final:B04"); b04_stats(f, 1, "sell one")
 undo(f); b04_stats(f, 2, "sale undo")
 undo(f); undo(f); b04_stats(f, 0, "purchase undo")
 buy(f, "intermediate:I13"); buy(f, "intermediate:I11")
 check("passive:08" not in model.equipment_effects().passives and b04_status(f).active_copies == 0, "I13 and I11 are attribute-only")
 gold = model.state.gold
 var crafted: Dictionary = shop_command(f, "craft", {"item":"final:B04"})
 check(crafted.get("accepted", false) and int(model.state.gold) == gold - 550 and owned_count(f, "final:B04") == 1 and owned_count(f, "intermediate:I13") == 0 and owned_count(f, "intermediate:I11") == 0, "original recipe consumes I13+I11 and exactly550")
 undo(f)
 check(owned_count(f, "final:B04") == 0 and owned_count(f, "intermediate:I13") == 1 and owned_count(f, "intermediate:I11") == 1, "original craft undo restores components")
 var before: Dictionary = b04_protected(f)
 var denied: Dictionary = command(f, "b04_verified_basic_completion", {"remainder":4})
 check(not denied.get("accepted", false) and b04_protected(f) == before, "public command cannot invent B04 entitlement")
 b04_integrity(f, current_group); dispose(f); b04_done()

func b04_cycles() -> void:
 current_group = B04_GROUPS[1]
 var f: Dictionary = b04_combat(2, current_group)
 if f.is_empty(): return
 b04_keep_original(f)
 if not b04_seed(f, 4): dispose(f); return
 b04_cd_fixture(f, 50.0, 30.0)
 var fifth: Dictionary = b04_shot(f)
 b04_check_completion(f, fifth, 4, 0, true, "fifth with two copies")
 if fifth.is_empty(): dispose(f); return
 check(float(fifth.receipt.result.b04_completion.cooldowns_before.q) != float(fifth.receipt.result.b04_completion.cooldowns_before.e), "Q/E use their different live remaining values")
 check(b04_receipts(f).size() == 5, "two copies yield five receipts, not ten")
 var before: Dictionary = b04_protected(f)
 var cds: Dictionary = f.sim.hero.cooldowns.duplicate(true)
 f.b04_synthetic = true
 f.sim.emit_event("ink_basic_finished", fifth.event.duplicate(true))
 f.sim.emit_event("ink_basic_finished", fifth.event.duplicate(true))
 f.b04_synthetic = false
 check(b04_protected(f) == before and f.sim.hero.cooldowns == cds, "public completion copies cannot replay count or refund")
 var source_cast: int = int(fifth.event.cast_id)
 f.sim.finish_cast(source_cast)
 check(b04_protected(f) == before, "generic finished-cast replay cannot count")
 var retired: Dictionary = f.b04_original_states[str(fifth.event.generation) + ":" + str(source_cast)]
 f.b04_synthetic = true
 f.sim._retire_motion(retired, float(fifth.event.finished_at), str(fifth.event.reason))
 f.b04_synthetic = false
 check(b04_protected(f) == before and f.sim.hero.cooldowns == cds, "same original retired cast cannot commit twice")
 if not b04_seed(f, 4): dispose(f); return
 b04_cd_fixture(f, 0.0, 0.0)
 var tenth: Dictionary = b04_shot(f)
 b04_check_completion(f, tenth, 4, 0, true, "tenth with zero Q/E")
 check(b04_remainder(f) == 0 and b04_receipts(f).size() == 10, "zero cooldowns still consume the fifth group")
 b04_cd_fixture(f, 50.0, 30.0)
 var eleventh: Dictionary = b04_shot(f)
 b04_check_completion(f, eleventh, 0, 1, false, "zero-CD group never banks future refund")
 b04_integrity(f, current_group); dispose(f)
 var none: Dictionary = b04_combat(0, "unequipped")
 if none.is_empty(): return
 b04_keep_original(none)
 var empty: Dictionary = b04_shot(none)
 check(not empty.is_empty() and empty.receipt.is_empty() and b04_remainder(none) == 0 and b04_receipts(none).is_empty(), "real unequipped completion never accumulates")
 b04_integrity(none, "unequipped"); dispose(none); b04_done()

func b04_abort_nonbasic() -> void:
 current_group = B04_GROUPS[2]
 for mode: String in ["cancel", "close", "death"]:
  var f: Dictionary = b04_combat(1, "preterminal " + mode)
  if f.is_empty(): return
  b04_keep_original(f)
  if not b04_seed(f, 3) or not b04_ready(f): dispose(f); return
  var protected: Dictionary = b04_protected(f)
  var result: Dictionary = b04_launch(f, b04_empty_aim(f))
  if result.is_empty(): dispose(f); return
  var active: Dictionary = {}
  for motion: Dictionary in f.sim.ink_basics:
   if int(motion.cast_id) == int(result.cast_id): active = motion
  check(not active.is_empty(), mode + ": actual projectile exists before cancellation")
  if mode == "cancel": f.sim.cancel_cast(int(result.cast_id))
  elif mode == "close": check(f.session.close_run().get("accepted", false), "original Session clear closes unfinished basic")
  else: f.sim.damage_hero(float(f.sim.hero.hp) + 100000.0, Vector3.ZERO, 0.0, true, true, {"fixture":true, "purpose":"B04 preterminal death"})
  step(f, 80)
  check(b04_protected(f) == protected and b04_remainder(f) == 3, mode + ": aborted source never consumes remainder or refunds")
  if mode == "cancel":
   var accepted: Dictionary = b04_shot(f)
   b04_check_completion(f, accepted, 3, 4, false, "new basic after cancelled cast")
  if mode == "death":
   check(f.sim.hero.dead and f.sim.phase == "true_dead", "actual damage death reaches original true_dead terminal")
   var fresh_run: Dictionary = funded_shop("original new run after death")
   if not fresh_run.is_empty():
    check(fresh_run.session.run_id != f.session.run_id and b04_remainder(fresh_run) == 0 and b04_receipts(fresh_run).is_empty(), "new original Host/Session/Model resets B04 to zero")
    dispose(fresh_run)
  evidence.aborts.append({"mode":mode, "cast_id":result.cast_id, "before":protected, "after":b04_protected(f), "phase":f.sim.phase})
  b04_integrity(f, mode); dispose(f)
 var q: Dictionary = b04_combat(1, "actual Q1 exclusion")
 if q.is_empty(): return
 b04_keep_original(q)
 var before_q: Dictionary = b04_protected(q)
 var start: Vector3 = q.sim.hero.position
 var endpoint: Vector3 = start + Vector3(0, 0, 3)
 var key := InputEventKey.new(); key.physical_keycode = KEY_Q; key.pressed = true
 check(q.router.handle_event(key, start).get("accepted", false), "actual Q1 arm")
 var down := InputEventMouseButton.new(); down.button_index = MOUSE_BUTTON_LEFT; down.pressed = true
 check(q.router.handle_event(down, start).get("accepted", false), "actual Q1 start at hero, safely within9m")
 var up := InputEventMouseButton.new(); up.button_index = MOUSE_BUTTON_LEFT; up.pressed = false
 check(q.router.handle_event(up, endpoint).get("accepted", false), "actual Q1 mouse release")
 step(q, 100)
 check(not events_of(q, "ink_q1_finished").is_empty() and b04_protected(q) == before_q, "Q1 natural completion is not a basic")
 b04_integrity(q, "Q1 exclusion"); dispose(q); b04_done()

func b04_move_keys(f: Dictionary, direction: Vector3) -> void:
 for row: Array in [[KEY_A, direction.x < -0.05], [KEY_D, direction.x > 0.05], [KEY_W, direction.z < -0.05], [KEY_S, direction.z > 0.05]]:
  var key := InputEventKey.new(); key.physical_keycode = int(row[0]); key.pressed = bool(row[1])
  f.router.handle_event(key)

func b04_move_to(f: Dictionary, point: Vector3) -> bool:
 for _tick: int in range(350):
  if f.sim.phase != "combat" or f.sim.hero.dead: break
  var offset: Vector3 = point - f.sim.hero.position
  if offset.length() <= 0.16:
   b04_move_keys(f, Vector3.ZERO); return true
  b04_move_keys(f, offset.normalized()); step(f)
 b04_move_keys(f, Vector3.ZERO)
 return check(false, "ordinary WASD reaches authored obstacle approach")

func b04_approach(f: Dictionary, enemy: Dictionary, distance: float) -> bool:
 for _tick: int in range(600):
  if f.sim.phase != "combat" or f.sim.hero.dead or enemy.dead: break
  var offset: Vector3 = enemy.position - f.sim.hero.position
  if offset.length() <= distance:
   b04_move_keys(f, Vector3.ZERO); return true
  b04_move_keys(f, offset.normalized()); step(f)
 b04_move_keys(f, Vector3.ZERO)
 return check(false, "ordinary WASD reaches the original target within movement budget")

func b04_birth_victory() -> void:
 current_group = B04_GROUPS[3]
 var wall: Dictionary = b04_combat(1, "original authored wall completion")
 if wall.is_empty(): return
 b04_keep_original(wall)
 if not b04_seed(wall, 4) or not b04_move_to(wall, Vector3(7, 0, 0)): dispose(wall); return
 b04_cd_fixture(wall, 50.0, 30.0)
 var wall_generation: int = wall.sim.encounter_generation
 var wall_shot: Dictionary = b04_launch(wall, wall.sim.hero.position + Vector3(7, 0, 0))
 if wall_shot.is_empty(): dispose(wall); return
 var wall_finish: Dictionary = b04_wait_finish(wall, int(wall_shot.cast_id), wall_generation)
 b04_check_completion(wall, wall_finish, 4, 0, true, "authored obstacle fifth")
 if not wall_finish.is_empty(): check(wall_finish.event.reason == "blocked" and wall_finish.event.hit_target_ids.is_empty(), "real Host solver counts empty authored-wall terminal")
 b04_integrity(wall, "authored wall"); dispose(wall)
 for birth: bool in [false, true]:
  var f: Dictionary = b04_combat(1, "last original enemy birth=" + str(birth))
  if f.is_empty(): return
  var enemy: Dictionary = b04_keep_original(f)
  if enemy.is_empty() or not b04_seed(f, 4): dispose(f); return
  if not b04_approach(f, enemy, 0.20 if birth else 4.0) or not b04_ready(f): dispose(f); return
  # A source damage fixture leaves one HP on the original actor. The final
  # blow, original kill reward, basic retirement and victory remain authentic.
  f.sim.damage_enemy(enemy, maxf(0.0, float(enemy.hp) - 1.0), "equipment38_prepare_final_original_enemy", 0, true, false, {"fixture":true, "direct":false, "no_reactions":true})
  check(not enemy.dead and float(enemy.hp) > 0.0, "source fixture leaves original final enemy alive")
  if birth and not b04_approach(f, enemy, 0.20): dispose(f); return
  b04_cd_fixture(f, 50.0, 30.0)
  var generation: int = f.sim.encounter_generation
  var result: Dictionary = b04_launch(f, enemy.position + Vector3(0.001, 0, 0))
  if result.is_empty(): dispose(f); return
  var observation: Dictionary = b04_wait_finish(f, int(result.cast_id), generation)
  b04_check_completion(f, observation, 4, 0, true, "last original enemy")
  if observation.is_empty(): dispose(f); return
  check(observation.event.reason == "contact" and observation.event.hit_target_ids == [enemy.actor_id], "final hit retires one actual basic on original enemy")
  check(bool(observation.transaction_active) == birth, "birth completion occurs inside request transaction; travel completion outside")
  if not settle_original_row(f, 1): dispose(f); return
  var kill_sequence: int = -1; var finish_sequence: int = int(observation.event.sequence); var terminal_sequence: int = -1
  for item: Dictionary in f.b04_trace:
   if item.kind == "kill" and int(item.cast_id) == int(result.cast_id): kill_sequence = int(item.sequence)
   if item.kind == "encounter_finished": terminal_sequence = int(item.sequence)
  check(kill_sequence > 0 and kill_sequence < finish_sequence and finish_sequence < terminal_sequence, "actual final enemy order: kill then basic_finished then victory")
  var proposal: Dictionary = observation.receipt.result.b04_completion
  for slot: String in ["q", "e"]: near_number(float(f.sim.frozen_snapshot.hero.cooldowns[slot]), float(proposal.cooldowns_after[slot]), "victory snapshot retains B04 reduced " + slot)
  check(b04_remainder(f) == 0 and b04_receipts(f).size() == 5, "natural victory retains one fifth-completion claim")
  evidence.victory.append({"birth":birth, "original_enemy":enemy.actor_id, "trace":f.b04_trace.duplicate(true), "completion":observation, "frozen_cooldowns":f.sim.frozen_snapshot.hero.cooldowns.duplicate(true)})
  b04_integrity(f, "natural victory"); dispose(f)
 for action: String in ["cancel", "close", "death"]:
  var f: Dictionary = b04_combat(1, "postcompletion " + action)
  if f.is_empty(): return
  b04_keep_original(f)
  if not b04_seed(f, 4): dispose(f); return
  b04_cd_fixture(f, 50.0, 30.0)
  f.b04_observer_action = action
  var fifth: Dictionary = b04_shot(f)
  b04_check_completion(f, fifth, 4, 0, true, "already committed before observer " + action)
  check(b04_remainder(f) == 0 and b04_receipts(f).size() == 5, "observer " + action + " does not undo legitimate completion")
  check(f.b04_diagnostics.size() == 4, "observer invalidation suppresses old-scope fifth diagnostic")
  f.session.update_after_source_step()
  b04_integrity(f, "postcompletion " + action); dispose(f)
 b04_done()

func b04_lifecycle() -> void:
 current_group = B04_GROUPS[4]
 var f: Dictionary = b04_combat(2, current_group)
 if f.is_empty(): return
 b04_keep_original(f)
 if not b04_seed(f, 3) or not b04_settle_row(f, 1): dispose(f); return
 check(b04_remainder(f) == 3, "original row1 victory retains3")
 if not enter(f, 2) or not spawn_ready(f): dispose(f); return
 b04_keep_original(f)
 var fourth: Dictionary = b04_shot(f); b04_check_completion(f, fourth, 3, 4, false, "cross-room fourth")
 b04_cd_fixture(f, 50.0, 30.0)
 var fifth: Dictionary = b04_shot(f); b04_check_completion(f, fifth, 4, 0, true, "cross-room3+2 fifth")
 if not b04_seed(f, 3) or not b04_settle_row(f, 2): dispose(f); return
 if not enter(f, 3) or not check(f.session.complete_service().get("accepted", false), "original row3 service completes") or not choose_required_hexes(f): dispose(f); return
 if not check(f.session.open_panel().get("accepted", false), "original service safe shop opens"): dispose(f); return
 var protected: Dictionary = b04_protected(f)
 sell(f, "final:B04")
 check(b04_remainder(f) == 3 and b04_status(f).active_copies == 1, "sell one of two retains shared remainder")
 undo(f)
 check(owned_count(f, "final:B04") == 2 and b04_protected(f) == protected, "sale undo retains same run progress")
 sell(f, "final:B04"); sell(f, "final:B04")
 check(b04_remainder(f) == 3 and b04_status(f).active_copies == 0, "sell last freezes3")
 if not check(f.session.close_panel().get("accepted", false), "sold-empty original shop closes") or not enter(f, 4) or not spawn_ready(f): dispose(f); return
 b04_keep_original(f)
 var empty_before: Dictionary = b04_protected(f)
 for _shot: int in range(3):
  var observation: Dictionary = b04_shot(f)
  check(not observation.is_empty() and observation.receipt.is_empty(), "unequipped real completion has no B04 receipt")
 check(b04_remainder(f) == 3 and b04_protected(f) == empty_before, "three real unequipped completions do not accumulate")
 if not b04_settle_row(f, 4) or not enter(f, 5) or not b04_settle_row(f, 5) or not choose_required_hexes(f): dispose(f); return
 if not check(f.session.open_panel().get("accepted", false), "original post-row5 shop opens") or not buy(f, "final:B04"): dispose(f); return
 check(b04_remainder(f) == 3, "new purchase UID resumes frozen3")
 if not check(f.session.close_panel().get("accepted", false), "repurchase shop closes") or not enter(f, 6) or not check(f.session.complete_service().get("accepted", false), "original row6 service completes") or not enter(f, 7) or not spawn_ready(f): dispose(f); return
 b04_keep_original(f)
 fourth = b04_shot(f); b04_check_completion(f, fourth, 3, 4, false, "rebought fourth")
 b04_cd_fixture(f, 50.0, 30.0)
 fifth = b04_shot(f); b04_check_completion(f, fifth, 4, 0, true, "rebought fifth")
 check(b04_receipts(f).size() == 10 and int(f.session.ledger.model.state.bonus_sp) == 0, "same original run has exactly10 equipped completions and no B04 SP")
 evidence.lifecycle.append({"same_Host_Session":true, "route":B01_ROUTE.slice(0, 7), "identities":f.identities.duplicate(true), "status":b04_status(f), "receipts":b04_receipts(f), "extra_targets":false})
 b04_integrity(f, current_group); dispose(f); b04_done()

func b04_common_callback(id: int, cancelled: bool, sim: Node, probe: Dictionary) -> void:
 if cancelled or probe.fired: return
 if sim._b04_terminal_frames.is_empty(): return
 probe.fired = true
 var frame: Dictionary = sim._b04_terminal_frames.back()
 check(not frame.finish_returned and int(frame.finish_depth) > 0 and bool(sim._casts[id].finished), "common hook remains inside full original finish chain")
 var fake: Dictionary = sim._motion_public(frame.state)
 fake.finished_at = frame.at; fake.settled_at = sim.hero_time; fake.reason = frame.reason
 sim.emit_event("ink_basic_finished", fake)
 check(not sim.fixture_matches.back().matches, "common callback public lookalike cannot borrow incomplete terminal frame")
 if probe.mode == "cancel": sim.cancel_cast(id)
 elif probe.mode == "clear": sim.end_encounter("fixture_closed")
 elif probe.mode == "death": sim.damage_hero(float(sim.hero.hp) + 100000.0, Vector3.ZERO, 0.0, true, true, {"fixture":true, "purpose":"common finish callback death"})
 elif probe.mode == "room":
  sim.end_encounter("fixture_closed")
  probe.next_room = sim.begin_encounter("b04-isolated-next", [{"kind":"ranged", "position":Vector3(0, 0, -10), "hp":10000.0}])

func b04_isolated_common() -> void:
 current_group = B04_GROUPS[5]
 for mode: String in ["plain", "cancel", "clear", "room", "death", "blocked"]:
  var sim = B04FinishProbe.new()
  root.add_child(sim)
  var bridge = B04CommonProbe.new(sim)
  bridge.context_values["ranged"] = true
  sim.common = bridge # Explicit isolated wrapper, never an original Host claim.
  var probe: Dictionary = {"mode":mode, "fired":false}
  bridge.callback = b04_common_callback.bind(sim, probe)
  check(sim.begin_encounter("b04-isolated-" + mode, [{"kind":"ranged", "position":Vector3(0, 0, -10), "hp":10000.0}]).get("accepted", false), "isolated source begin uses original API")
  if mode == "blocked":
   # Geometry fixture only: the existing solver must itself detect obstruction.
   sim.obstacles.append({"position":sim.hero.position + Vector3(2, 0, 0), "half":Vector3(0.25, 0, 2)})
  var result: Dictionary = sim.request_action("attack", sim.hero.position + Vector3(7, 0, 0), "b04-isolated-" + mode)
  check(result.get("accepted", false), "isolated actual request_action reaches original start_basic")
  for _tick: int in range(150):
   if probe.fired: break
   sim.step(sim.FIXED_TICK)
  check(probe.fired, mode + ": actual natural retirement reaches inherited common completion")
  var genuine: Array = sim.fixture_matches.filter(func(item: Dictionary): return bool(item.matches))
  check(genuine.size() == (1 if mode in ["plain", "blocked"] else 0), mode + ": exact original terminal witness eligibility")
  if mode == "blocked" and genuine.size() == 1:
   check(genuine[0].event.reason == "blocked" and genuine[0].event.hit_target_ids.is_empty(), "existing solver produces empty blocked completion")
  if mode == "room": check(probe.get("next_room", {}).get("accepted", false) and sim.room_id == "b04-isolated-next", "common callback actual room replacement invalidates old terminal")
  evidence.isolated_common.append({"mode":mode, "original_Host_Session":false, "Model_bound":false, "full_inherited_finish_chain":true, "common_wrapper_timing_fixture":true, "source_witness_observations":sim.fixture_matches.duplicate(true), "probe":probe.duplicate(true), "no_counter_assertion_without_Model":true})
  bridge.callback = Callable()
  sim.free()
 b04_done()

func run() -> void:
 evidence = {"wallet_fixtures":[], "inputs":[], "cooldown_fixtures":[], "completions":[], "aborts":[], "victory":[], "postcompletion":[], "lifecycle":[], "isolated_common":[]}
 b04_definitions()
 b04_cycles()
 b04_abort_nonbasic()
 b04_birth_victory()
 b04_lifecycle()
 b04_isolated_common()
 finish()

func finish() -> void:
 check(b04_groups == B04_GROUPS, "all six B04 source/declared fixture groups reached")
 check(check_records.size() == checks, "every assertion retained")
 var report: Dictionary = {"suite":"equipment38_b04_real_basic_completion_source_gate", "passed":failures.is_empty() and b04_groups == B04_GROUPS, "runtime_status":"EXECUTED", "checks":checks, "failures":failures, "check_records":check_records, "completed_groups":b04_groups, "required_groups":B04_GROUPS, "evidence":evidence, "source_binding_sha256":FileAccess.get_sha256(Binding.BINDING_PATH), "original_factory_session":true, "testwallet_fixture":true, "source_cooldown_API_fixture":true, "original_route_lethal_fixtures":fixture_packets, "source_damage_before_final_basic_fixture":true, "isolated_common_wrapper_fixture":true, "common_invalidation_Model_bound":false, "extra_Host_targets":false, "nested_real_completion_tested":false, "actual_Q2_river_tested":false, "native_gui_input":false, "natural_play":false, "natural_full_floor":false, "production_ready":false}
 var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
 if file == null: push_error("Unable to write equipment38 result: " + output_path); quit(2); return
 file.store_string(JSON.stringify(report, "  "))
 var write_error: Error = file.get_error()
 file.close()
 print("EQUIPMENT38_SOURCE ", JSON.stringify({"passed":report.passed, "checks":checks, "failures":failures, "groups":b04_groups, "result":output_path}))
 quit(2 if write_error != OK else (0 if report.passed else 1))
