extends "res://integration_checks/equipment36_source_gate.gd"
## PREPARED ONLY. No engine/GUI was started while authoring this dedicated gate.
## Real Host/Session/Model; original seed, legal Hex commands, paid Q2, original
## input router and original H04 ticks. Only wallet/non-QE pre-damage are fixtures.
const H04_ID := "yanguizhou_h04"
const H04_SOURCE := "hex_yanguizhou_h04"
const H04_REFRESH_ORDER := [0, 3, 1, 2]
const H04_EXPECTED_OFFERS := [
 ["common_g01", "common_g24", "yanguizhou_h01", "yanguizhou_h06"],
 ["common_g05", "common_g24", "yanguizhou_h01", "yanguizhou_h06"],
 ["common_g05", "common_g24", "yanguizhou_h01", "yanguizhou_h03"],
 ["common_g05", "common_g06", "yanguizhou_h01", "yanguizhou_h03"],
 ["common_g05", "common_g06", "yanguizhou_h04", "yanguizhou_h03"]
]
const H04_EXPECTED_RNG := [1914720637, 2078669041, 407355683, 1105902161, 854716505]
const H04_GROUPS := ["default_seed_legal_h04_and_q2", "original_q2_input_and_non_qe_pre_damage", "original_h04_two_kills_one_refund"]
var h04_completed: Array[String] = []

func _initialize() -> void:
 output_path = "user://equipment36_h04_gate.json"
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--equipment-result="): output_path = argument.trim_prefix("--equipment-result=")
 run.call_deferred()

func h04_group_done() -> void:
 check(current_group in H04_GROUPS and current_group not in h04_completed, "unique H04 group " + current_group)
 h04_completed.append(current_group)

func prepare_initial_choices(f: Dictionary) -> bool:
 # Override only the inherited Q1 choice. No Model/state constructor or seed edit.
 var model = f.session.ledger.model
 if not check(int(model.state.rng) == 1 and model.state.offers.is_empty(), "real factory default seed1 before any offer"): return false
 check(not f.session.open_panel().get("accepted", false), "original initial Hex gate blocks commerce")
 if not check(command(f, "hex_open", {"milestone":1}).get("accepted", false), "original Lv1 offer opens"): return false
 for index: int in range(H04_EXPECTED_OFFERS.size()):
  if index > 0:
   var slot: int = int(H04_REFRESH_ORDER[index - 1])
   if not check(command(f, "hex_refresh", {"milestone":1, "slot":slot}).get("accepted", false), "original once-only refresh of slot " + str(slot)): return false
  var offer: Dictionary = model.state.offers["1"].duplicate(true)
  evidence.allocator.append({"step":index, "refresh_slot":-1 if index == 0 else H04_REFRESH_ORDER[index - 1], "offer":offer, "rng":model.state.rng})
  if not check(offer.slots == H04_EXPECTED_OFFERS[index] and int(model.state.rng) == int(H04_EXPECTED_RNG[index]), "unchanged default-seed original offer sequence " + str(index)): return false
 if not check(command(f, "hex_select", {"milestone":1, "slot":2}).get("accepted", false), "select actual offered H04 in slot2"): return false
 check(model.state.selected_hex == [H04_ID] and not f.sim.hx(H04_ID), "legally selected H04 is dormant before Q2")
 var learned: Dictionary = command(f, "learn", {"slot":"Q", "candidate":"Q2", "expected_rank":0})
 if not check(learned.get("accepted", false), "original one SP legally learns Q2"): return false
 if not check(int(model.state.points) == 0 and int(model.state.skills.Q.rank) == 1 and model.state.skills.Q.candidate == "Q2", "original Model paid exactly1SP for rank1 Q2"): return false
 if not check(f.sim.hero.loadout.q == "q2" and int(f.sim.hero.ranks.q) == 1 and f.sim.hx(H04_ID), "same stat owner projects active H04 and paid rank1 Q2"): return false
 check(int(f.sim.hero.ranks.p) == 0 and model.state.selected_hex == [H04_ID], "P1/P2 and other Hex effects remain unlearned")
 evidence.initial = {"default_seed":1, "seed_fixture":false, "refresh_order":H04_REFRESH_ORDER, "selected_hex":model.state.selected_hex.duplicate(), "offer":model.state.offers["1"].duplicate(true), "skills":model.state.skills.duplicate(true), "points":model.state.points, "level":model.state.level, "xp":model.state.xp}
 h04_group_done()
 return true

func on_event(event: Dictionary, f: Dictionary) -> void:
 var record: Dictionary = {}
 if event.get("kind", "") == "kill" and event.get("source", "") == H04_SOURCE and f.has("h04_kills"):
  var frame: Dictionary = f.sim._b01_damage_frames.back() if not f.sim._b01_damage_frames.is_empty() else {}
  var source_frame: Dictionary = f.sim._river_hex_packet_frames.back() if not f.sim._river_hex_packet_frames.is_empty() else {}
  var metadata: Dictionary = frame.get("metadata", {}).duplicate(true)
  record = {"event":event.duplicate(true), "live_attribution":f.sim.verify_b01_kill_attribution(event).duplicate(true), "original_metadata":metadata, "live_original_packet_verified":f.sim._river_hex_original_packet(H04_SOURCE, int(event.cast_id), metadata), "same_source_target_identity":not frame.is_empty() and not source_frame.is_empty() and is_same(frame.enemy, source_frame.enemy), "source_frame_tick":int(source_frame.get("tick", -1)), "source_frame_time":float(source_frame.get("at", -1.0)), "before":protected_task(f), "cooldown_before":f.sim.hero.cooldowns.q, "hero_time":f.sim.hero_time}
 # The inherited observer is the only code submitting the real event to Session.
 super.on_event(event, f)
 if not record.is_empty():
  record["after"] = protected_task(f)
  record["cooldown_after"] = f.sim.hero.cooldowns.q
  record["refund_event_count_after"] = events_of(f, "equipment_b01_refund").size()
  f.h04_kills.append(record)

func h04_key(down: bool) -> InputEventKey:
 var event := InputEventKey.new()
 event.physical_keycode = KEY_Q
 event.pressed = down
 return event

func h04_mouse(down: bool) -> InputEventMouseButton:
 var event := InputEventMouseButton.new()
 event.button_index = MOUSE_BUTTON_LEFT
 event.pressed = down
 return event

func h04_place(f: Dictionary, point: Vector3, label: String) -> Dictionary:
 # Genuine factory router, synthetic InputEvents. This is not native GUI input.
 var armed: Dictionary = f.router.handle_event(h04_key(true), point)
 var key_up: Dictionary = f.router.handle_event(h04_key(false), point)
 if not check(armed.get("accepted", false), label + ": actual Q arms source preview: " + str(armed.get("reason", ""))): return {}
 var placed: Dictionary = f.router.handle_event(h04_mouse(true), point)
 var mouse_up: Dictionary = f.router.handle_event(h04_mouse(false), point)
 evidence.inputs.append({"label":label, "point":point, "q_down":armed, "q_up":key_up, "left_down":placed, "left_up":mouse_up})
 if not check(placed.get("accepted", false), label + ": fresh left-down commits actual source: " + str(placed.get("reason", ""))): return {}
 check(bool(key_up.get("consumed", false)) and bool(mouse_up.get("consumed", false)), label + ": original router drains both release edges")
 return placed

func h04_original_pair(f: Dictionary) -> Array:
 # Let the unchanged AI approach. No target movement or state assignment.
 var started_at: float = float(f.sim.hero_time)
 for _tick: int in range(400):
  if f.sim.phase != "combat" or f.sim.paused or f.sim.hero.dead: break
  var candidates: Array = []
  for enemy: Dictionary in f.sim.living():
   if enemy.kind == "minion" and enemy.state != "spawn" and Vector3(enemy.position).distance_to(f.sim.hero.position) <= 2.8:
    candidates.append(enemy)
  for first: Dictionary in candidates:
   for second: Dictionary in candidates:
    if is_same(first, second): continue
    var separation: float = Vector3(first.position).distance_to(second.position)
    if separation < 0.5 or separation > 2.0: continue
    if not f.sim.q2_preview(first.position).get("accepted", false): continue
    evidence.pair = {"wait_started_at":started_at, "selected_at":f.sim.hero_time, "hero_position":f.sim.hero.position, "first":{"actor_id":first.actor_id, "position":first.position, "hp":first.hp}, "second":{"actor_id":second.actor_id, "position":second.position, "hp":second.hp}, "separation":separation, "method":"original AI approach; no actor position or HP assignment"}
    return [first, second]
  step(f)
 check(false, "two original minions naturally enter bounded Q2/H04 geometry while hero is alive")
 evidence.pair = {"failed":true, "hero_time":f.sim.hero_time, "hero_hp":f.sim.hero.hp, "phase":f.sim.phase, "living":f.sim.living().duplicate(true)}
 return []

func h04_pre_damage(f: Dictionary, enemy: Dictionary, river: Dictionary) -> bool:
 var actor_id: String = str(enemy.actor_id)
 if not check(actor_id in f.session.expected_enemies and river.hits.has(actor_id) and not enemy.dead, "pre-damage target is original and already survived this Q2 river touch: " + actor_id): return false
 if not check(float(enemy.hp) > 1.0 and float(f.sim.hero.cooldowns.q) > 0.0, "pre-damage occurs after Q2 contact and actual cooldown start"): return false
 var before: Dictionary = protected_task(f)
 var cooldown: float = float(f.sim.hero.cooldowns.q)
 var hp: float = float(enemy.hp)
 var event_start: int = f.events.size()
 var metadata: Dictionary = {"fixture":true, "purpose":"non_QE_nonlethal_pre_damage_after_original_Q2_birth_contact", "active_skill":false, "direct":false, "no_reactions":true, "snapshot_final":true, "generation":f.sim.encounter_generation, "room_id":f.sim.room_id}
 var killed: bool = f.sim.damage_enemy(enemy, hp - 1.0, "equipment36_h04_non_qe_pre_damage_fixture", 0, true, false, metadata)
 evidence.pre_damage.append({"actor_id":actor_id, "cast_id":0, "source":"equipment36_h04_non_qe_pre_damage_fixture", "amount":hp - 1.0, "hp_before":hp, "hp_after":enemy.hp, "source_time":f.sim.hero_time, "original_q2_cast_id":river.cast_id, "original_river_touch_already_claimed":river.hits.has(actor_id), "metadata":metadata, "events":f.events.slice(event_start)})
 if not check(not killed and not enemy.dead and is_equal_approx(float(enemy.hp), 1.0), "real non-QE true packet leaves original enemy alive at1HP"): return false
 check(before == protected_task(f), "non-QE nonlethal pre-damage cannot mint B01 progress or claims")
 near_number(float(f.sim.hero.cooldowns.q), cooldown, "non-QE pre-damage cannot refund actual Q2 cooldown")
 return true

func h04_case() -> void:
 current_group = H04_GROUPS[0]
 var f: Dictionary = funded_shop("H04 default-seed actual-input fixture")
 if f.is_empty(): return
 f["h04_kills"] = []
 if not buy(f, "final:B01") or not buy(f, "final:B01"): dispose(f); return
 assert_b01_stats(f, 2, "two original purchased B01 copies")
 if not check(f.session.close_panel().get("accepted", false), "actual original shop closes") or not enter(f, 1) or not spawn_ready(f): dispose(f); return
 current_group = H04_GROUPS[1]
 var pair: Array = h04_original_pair(f)
 if pair.size() != 2: dispose(f); return
 var a: Vector3 = pair[0].position
 var b: Vector3 = pair[1].position
 var first: Dictionary = h04_place(f, a, "Q2 A")
 if first.is_empty(): dispose(f); return
 var id: int = int(first.cast_id)
 if not check(not f.sim.ink_q2_pending.is_empty() and int(f.sim.ink_q2_pending.cast_id) == id, "actual A owns original pending Q2 cast"): dispose(f); return
 near_number(float(f.sim.hero.cooldowns.q), 0.0, "A starts no Q2 cooldown")
 var second: Dictionary = h04_place(f, b, "Q2 B")
 if second.is_empty(): dispose(f); return
 if not check(int(second.cast_id) == id and f.sim.ink_q2_pending.is_empty() and f.sim.ink_rivers.size() == 1, "B completes the same original Q2 cast into exactly one river"): dispose(f); return
 var river: Dictionary = f.sim.ink_rivers[0]
 if not check(bool(river.h04_at_completion) and int(river.cast_id) == id and river.path == [a, b], "actual chosen H04 belongs to this unchanged Q2 root/path"): dispose(f); return
 check(not bool(river.h03_at_completion) and int(f.sim.hero.ranks.q) == 1 and int(f.sim.hero.ranks.p) == 0, "rank1 two-point Q2 has no H03 or passive supplement")
 if not check(f.live_kills.is_empty() and f.h04_kills.is_empty(), "Q2 birth hits have not killed any original actor"): dispose(f); return
 assert_task(f, 0, false, "actual Q2 birth before any kill")
 near_number(float(f.sim.hero.cooldowns.q), 10.5 * (1.0 - float(f.sim.hero.stats.cdr)), "original rank1 Q2 cooldown starts only at B")
 for enemy: Dictionary in pair:
  if not h04_pre_damage(f, enemy, river): dispose(f); return
 evidence.q2 = {"cast_id":id, "river_id":river.river_id, "a":a, "b":b, "born_at":river.born_at, "sunset_damage":river.sunset_damage, "sunset_expires_at":river.sunset_expires_at, "cooldown_after_pre_damage":f.sim.hero.cooldowns.q, "river_hits_after_birth":river.hits.duplicate(true), "birth_receipts":f.sim.ink_q2_receipts.duplicate(true), "expected_targets":[pair[0].actor_id, pair[1].actor_id], "expected_roster":f.session.expected_enemies.duplicate()}
 h04_group_done()
 current_group = H04_GROUPS[2]
 for _tick: int in range(210):
  if f.h04_kills.size() >= 2 or f.sim.phase != "combat" or f.sim.paused or f.sim.hero.dead: break
  step(f)
 evidence.h04_kills = f.h04_kills.duplicate(true)
 evidence.h04_samples = f.sim.h04_sample_receipts.duplicate(true)
 evidence.q2_receipts = f.sim.ink_q2_receipts.duplicate(true)
 evidence.refunds = events_of(f, "equipment_b01_refund")
 evidence.all_kills = f.live_kills.duplicate(true)
 evidence.final_task = protected_task(f)
 if not check(f.h04_kills.size() == 2 and f.live_kills.size() == 2, "two and only two original enemies die to actual source-stepped H04"): dispose(f); return
 var seen: Dictionary = {}
 for index: int in range(f.h04_kills.size()):
  var observation: Dictionary = f.h04_kills[index]
  var event: Dictionary = observation.event
  var attribution: Dictionary = observation.live_attribution
  var receipt: Dictionary = observation.original_metadata.get("q2_receipt", {})
  var target: String = str(event.target)
  check(target in evidence.q2.expected_targets and not seen.has(target) and target in f.session.expected_enemies, "H04 kills each intended original roster actor once")
  seen[target] = true
  check(str(event.source) == H04_SOURCE and int(event.cast_id) == id, "real H04 kill retains exact same Q2 cast ID")
  check(not attribution.is_empty() and attribution.get("parent_skill", "") == "q2" and bool(attribution.get("original_q2_hex_receipt_verified", false)), "B01 verifier returns original Q2/H04 entitlement inside source frame")
  check(bool(observation.live_original_packet_verified) and bool(observation.same_source_target_identity), "strict original H04 packet and exact source target identities remain live")
  check(receipt.get("kind", "") == "sunset" and str(receipt.get("river_id", "")) == str(river.river_id) and int(receipt.get("cast_id", 0)) == id and str(receipt.get("target_id", "")) == target, "original source receipt belongs to same river/cast/target")
  check(int(receipt.get("tick", -1)) == int(observation.source_frame_tick) and float(receipt.get("source_time", -1.0)) == float(observation.source_frame_time), "original sampled tick/time matches live H04 dispatch frame")
  check(int(receipt.get("generation", -1)) == f.sim.encounter_generation and str(receipt.get("room_id", "")) == f.sim.room_id, "original receipt belongs to current admitted room/generation")
  var tick: int = int(receipt.get("tick", -1))
  check(tick >= 1 and tick <= 8, "original H04 scheduled tick is within1..8")
  near_number(float(receipt.get("source_time", -1.0)), float(river.born_at) + 0.5 * tick, "original H04 source schedule")
  check(bool(observation.original_metadata.get("active_skill", false)) and bool(observation.original_metadata.get("hex_generated", false)) and bool(observation.original_metadata.get("area", false)), "original H04 source provenance is preserved")
  check(int(observation.before.task.progress) == index and int(observation.after.task.progress) == index + 1, "B01 task progresses once per original H04 enemy")
  if index == 0:
   check(float(observation.cooldown_before) > 0.0, "first H04 kill samples a positive current Q2 cooldown")
   near_number(float(observation.cooldown_after), float(observation.cooldown_before) * 0.65, "first H04 kill refunds35percent of current Q2 CD once")
  else:
   near_number(float(observation.cooldown_after), float(observation.cooldown_before), "second H04 enemy on the same Q2 cast gains no extra refund")
  check(int(observation.refund_event_count_after) == 1, "exactly one B01 refund throughout both same-cast kills")
  check(f.sim.verify_b01_kill_attribution(event).is_empty(), "saved H04 kill outside live original stack cannot replay B01 attribution")
  check(not f.sim._river_hex_original_packet(H04_SOURCE, id, observation.original_metadata), "copied authentic H04 labels outside source frame cannot forge entitlement")
  var saved_task: Dictionary = protected_task(f)
  var gold: int = int(f.session.ledger.model.state.gold)
  var replay: Dictionary = f.session.observe_event(f.sim, event)
  check(replay.get("accepted", false) and protected_task(f) == saved_task and int(f.session.ledger.model.state.gold) == gold, "authentic saved H04 event replay is reward/task/refund idempotent")
 check(events_of(f, "equipment_b01_refund").size() == 1 and task_state(f).refund_claims.size() == 1, "two B01 copies retain one original Q2 refund claim")
 assert_task(f, 2, false, "two actual H04 kills")
 check(f.sim._b01_damage_frames.is_empty() and f.sim._river_hex_packet_frames.is_empty(), "both original source witness stacks unwind")
 check(f.session.kill_receipts.size() == 2 and f.event_errors.is_empty() and f.session.fault.is_empty(), "two original reward receipts and no event authentication errors")
 check(f.sim.ai_enabled and f.sim.auto_finish and not f.sim.hero.dead, "unchanged AI/terminal authority and living hero")
 check_owners(f, "H04 complete")
 h04_group_done()
 dispose(f)

func run() -> void:
 evidence = {"wallet_fixtures":[], "commerce":[], "allocator":[], "initial":{}, "inputs":[], "pair":{}, "pre_damage":[], "q2":{}, "h04_kills":[], "h04_samples":[], "q2_receipts":[], "refunds":[], "all_kills":[], "final_task":{}}
 h04_case()
 finish()

func finish() -> void:
 check(h04_completed == H04_GROUPS, "all three dedicated H04 groups reached")
 check(check_records.size() == checks, "every dedicated H04 assertion retained")
 var passed: bool = failures.is_empty() and h04_completed == H04_GROUPS
 var report: Dictionary = {"suite":"equipment36_b01_original_h04_gate", "passed":passed, "runtime_status":"EXECUTED", "checks":checks, "failures":failures, "check_records":check_records, "completed_groups":h04_completed, "required_groups":H04_GROUPS, "evidence":evidence, "source_binding_sha256":FileAccess.get_sha256(Binding.BINDING_PATH), "original_factory_session":true, "default_seed_legal_hex_commands":true, "allocator_seed_fixture":false, "testwallet_fixture":true, "non_qe_source_pre_damage_fixture":true, "actual_q2_router_input_case_included":true, "h04_original_packet_case_covered":passed, "extra_spawned_targets_fixture":false, "direct_hp_rank_hex_inventory_position_or_ai_writes":false, "natural_play":false, "natural_full_floor":false, "native_gui_input":false, "p1_supplement_case_covered":false}
 var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
 if file == null:
  push_error("Unable to write equipment36 H04 result: " + output_path); quit(2); return
 file.store_string(JSON.stringify(report, "  "))
 var write_error: Error = file.get_error()
 file.close()
 print("EQUIPMENT36_H04_SOURCE ", JSON.stringify(report))
 quit(2 if write_error != OK else (0 if passed else 1))
