extends SceneTree
## PREPARED ONLY: copied into candidate10 only after its G02 binding is sealed.
## Standalone original Sim/Bridge/Model. Never constructs Host or Session.
## Explicit source API fixtures; not natural gameplay or route admission.
const Sim = preload("res://tests/ink_river_hexes_20261006/ordinary01/sim.gd")
const Bridge = preload("res://visual_rework_20261009/binding/bridge.gd")
const Binding = preload("res://visual_rework_20261009/binding/live_binding.gd")
const MODEL_CHAIN := ["res://equipment_lifeline_20261009/model.gd", "res://equipment_pursuit_20261009/model.gd", "res://equipment_training_20261009/model.gd", "res://equipment_basic_cycle_20261009/model.gd", "res://equipment_elite_damage_20261009/model.gd", "res://equipment_kill_20261009/model.gd", "res://equipment_distance_20261009/model.gd", "res://equipment_expansion_20261009/model.gd", "res://visual_rework_20261009/binding/postboss_model.gd", "res://tests/ink_equipment_live_20261008/content01/model.gd"]
const SHOP := "res://tests/ink_first_floor_flow_20261004/fixtures/provisional_shop.json"
const PRICES := "res://tests/equipment_shop_transactions_20261004/fixtures/source_prices.json"
const NUMERIC := "res://tests/equipment_editable_tables_20261004/outputs/equipment_tables/converted/equipment_numeric_config.json"
const REWARDS := "res://tests/ink_first_floor_user_route_20261005/runtime01/"
const GROUPS := ["exact500_from_real_source_deaths", "shared_b01_g06_g02_final_death"]
var output_path: String = "user://g02_threshold_source_gate.json"
var partition: String = "all"
var required: Array = GROUPS.duplicate()
var completed: Array = []
var current: String = "binding"
var serial: int = 0
var checks: int = 0
var failures: Array = []
var records: Array = []
var evidence: Dictionary = {"bindings":[], "wallet_fixtures":[], "commerce":[], "rooms":[], "deaths":[], "counterfeits":[], "thresholds":[], "finished":[]}

func _initialize() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--equipment-result="): output_path = arg.trim_prefix("--equipment-result=")
  if arg.begins_with("--g02-threshold-group="): partition = arg.trim_prefix("--g02-threshold-group=")
 if partition == "exact": required = [GROUPS[0]]
 elif partition == "shared": required = [GROUPS[1]]
 elif partition != "all": push_error("Unknown G02 threshold partition"); quit(2); return
 run.call_deferred()

func check(ok: bool, label: String) -> bool:
 checks += 1
 records.append({"group":current, "passed":ok, "label":label})
 if not ok: failures.append(label); push_error(label)
 return ok

func near(value: float, expected: float, label: String) -> bool:
 return check(is_finite(value) and absf(value - expected) <= 0.0000001, label + " actual=" + str(value) + " expected=" + str(expected))

func task(model: RefCounted) -> Dictionary:
 return model._g02_state().duplicate(true)

func task_ledger(model: RefCounted) -> Dictionary:
 return model.state.shop_visit.taskLedger.get(str(model.state.actor_id) + "|final:G02", {}).duplicate(true)

func protected(model: RefCounted) -> Dictionary:
 return {"task":task(model), "ledger":task_ledger(model), "completed":model.state.completed_equipment_tasks.duplicate(true), "awards":model.state.bonus_awards.duplicate(true), "bonus_sp":model.state.bonus_sp, "points":model.state.points}

func invoke(f: Dictionary, action: String, args: Dictionary = {}) -> Dictionary:
 serial += 1
 return f.model.command("g02-standalone-command-%d" % serial, action, args)

func commerce(f: Dictionary, action: String, extra: Dictionary = {}, trusted: bool = false) -> Dictionary:
 serial += 1
 var args: Dictionary = f.model.commerce_token()
 args.merge(extra, true)
 var result: Dictionary = f.model.commerce_authority(f.owner, "g02-standalone-commerce-%d" % serial, action, args) if trusted else f.model.commerce_command("g02-standalone-commerce-%d" % serial, action, args)
 evidence.commerce.append({"operation":action, "trusted":trusted, "result":result.duplicate(true), "productionSession":false})
 return result

func owners(f: Dictionary, label: String) -> void:
 check(is_same(f.sim.progression, f.bridge) and is_same(f.bridge.model, f.model), label + ": one original source Bridge/Model")
 check(is_same(f.model._floor_owner.get_ref(), f.owner) and is_same(f.model._commerce_owner.get_ref(), f.owner), label + ": one formally bound RefCounted owner")
 check(is_same(f.model._live_sim.get_ref(), f.sim) and is_same(f.model._health_sim.get_ref(), f.sim), label + ": one live/health source Sim")
 check(f.sim.g02_model_is_bound(f.model) and f.sim.b04_model_is_bound(f.model), label + ": both exact equipment bridges use the same owner")
 check(str(f.model._run_id) == str(f.run_id) and str(f.model.state.shop_visit.run_id) == str(f.run_id), label + ": one exact fixture run identity")

func fresh(items: Array) -> Dictionary:
 serial += 1
 var sim = Sim.new()
 root.add_child(sim)
 var bridge = Bridge.new()
 # The formal API accepts RefCounted; this owner is not a Session subclass,
 # has no Session methods, and never receives a rejected Session event.
 var owner: RefCounted = RefCounted.new()
 var run_id: String = "g02-standalone-source-%d" % serial
 var capabilities: Dictionary = Binding.read_capabilities(sim, true)
 if not check(capabilities.get("accepted", false), "standalone exact original source binding admitted"):
  sim.free(); return {}
 var configured: Dictionary = bridge.configure_reward_table(REWARDS + "reward_table.json", REWARDS + "rewards.csv", REWARDS + "validation_result.json", true)
 if not check(configured.get("accepted", false), "original reward configuration binds without creating a Session"):
  sim.free(); return {}
 var initialized: Dictionary = bridge.initialize_runtime_fixture(sim, capabilities.capabilities, SHOP, PRICES, NUMERIC, owner, run_id, true)
 if not check(initialized.get("accepted", false), "original explicit runtime-fixture API: " + str(initialized.get("reason", ""))): sim.free(); return {}
 var model: RefCounted = bridge.model
 var script: Script = model.get_script()
 for path: String in MODEL_CHAIN:
  if not check(script != null and script.resource_path == path, "exact standalone Model chain " + path): sim.free(); return {}
  script = script.get_base_script()
 if not check(model.bind_floor(owner, sim, run_id).get("accepted", false), "formal original floor binding accepts ordinary RefCounted owner"):
  sim.free(); return {}
 sim.set_progression(bridge)
 var f: Dictionary = {"sim":sim, "bridge":bridge, "model":model, "owner":owner, "run_id":run_id, "room_serial":0, "events":[], "kills":[], "errors":[], "synthetic":false, "last_event":{}, "initial_gold":60000, "productionSession":false}
 owners(f, "fresh standalone")
 check(not model.bind_floor(owner, sim, run_id).get("accepted", false), "formal floor owner cannot be rebound")
 check(not model.bind_health_sim(sim).get("accepted", false), "formal health Sim cannot be rebound")
 var snapshot: Dictionary = model.snapshot()
 check(snapshot.level == 1 and snapshot.xp == 0 and snapshot.gold == 0 and snapshot.points == 1 and snapshot.inventory.is_empty(), "standalone original fresh Lv1 authority has zero task resources")
 check(task(model).progress == 0 and not task(model).completed and model.state.bonus_sp == 0, "standalone G02 starts at zero without copied state")
 check(invoke(f, "hex_open", {"milestone":1}).get("accepted", false), "original initial Hex offer")
 check(invoke(f, "hex_select", {"milestone":1, "slot":3}).get("accepted", false), "original offered initial Hex selection")
 check(bridge.invest("Q", "Q1").get("ok", false), "original single initial SP learns Q1")
 sim.set_progression(bridge)
 evidence.wallet_fixtures.append({"run_id":run_id, "before":model.state.gold, "after":60000, "test_only":true})
 model.state.gold = 60000 # Sole direct resource fixture; no progress/stat/HP writes.
 if not check(commerce(f, "enter_room", {"next_room":run_id + "/initial-safe"}, true).get("accepted", false), "original standalone safe-room commerce commit") or not check(commerce(f, "begin_visit", {"area":run_id + "/initial-shop"}, true).get("accepted", false), "original standalone shop visit") or not check(commerce(f, "open_ui").get("accepted", false), "original standalone shop opens"):
  sim.free(); return {}
 for id: String in items:
  if not check(commerce(f, "buy", {"item":id}).get("accepted", false), "original standalone purchase " + id): sim.free(); return {}
 if not check(commerce(f, "close_ui").get("accepted", false), "original standalone shop closes"): sim.free(); return {}
 sim.refresh_passive23()
 f["baseline_points"] = int(model.state.points)
 f["baseline_gold"] = int(model.state.gold)
 f["baseline_xp"] = int(model.state.xp)
 f["callback"] = observe.bind(f)
 sim.combat_event.connect(f.callback)
 evidence.bindings.append({"run_id":run_id, "Sim":sim.get_script().resource_path, "Bridge":bridge.get_script().resource_path, "Model":model.get_script().resource_path, "formal_owner_class":owner.get_class(), "Host_created":false, "Session_created":false, "productionSession":false, "runtime_fixture_opt_in":true, "source_binding_sha256":FileAccess.get_sha256(Binding.BINDING_PATH)})
 return f

func observe(event: Dictionary, f: Dictionary) -> void:
 if str(event.get("kind", "")) not in ["damage", "kill"]: return
 var witness: Dictionary = f.sim.verify_g02_kill_attribution(f.model, event, f.run_id) if event.kind == "kill" else {}
 var before: Dictionary = protected(f.model)
 var result: Dictionary = f.model.record_battle_event(f.sim, event, f.run_id)
 if not result.get("accepted", false): f.errors.append({"event":event.duplicate(true), "result":result.duplicate(true)})
 if event.kind != "kill": return
 var target: Dictionary = f.sim.enemy_by_id(str(event.target))
 var record: Dictionary = {"event":event.duplicate(true), "synthetic":f.synthetic, "live_witness":witness.duplicate(true), "original_target_rank":target.get("rank_category", ""), "original_target_dead":target.get("dead", false), "before":before, "after":protected(f.model), "result":result.duplicate(true), "b01":f.model.snapshot().get("b01_equipment", {}).duplicate(true), "g06":f.model.snapshot().get("g06_equipment", {}).duplicate(true), "productionSession":false}
 f.kills.append(record)
 if not f.synthetic:
  f.last_event = event.duplicate(true)
  evidence.deaths.append(record)

func start_room(f: Dictionary, rows: Array) -> bool:
 f.room_serial += 1
 var room_id: String = str(f.run_id) + "/source-room-%d" % int(f.room_serial)
 if not check(f.model.state.phase == "safe" and f.sim.phase != "combat", "standalone previous source encounter actually ended"): return false
 if not check(commerce(f, "enter_room", {"next_room":room_id}, true).get("accepted", false), "original standalone room commerce commit"): return false
 if not check(f.bridge.command("enter_level", {"combat_level_id":room_id}).get("ok", false), "original standalone ledger enters committed room"): return false
 var roster: Array = []
 for index: int in range(rows.size()):
  var angle: float = TAU * float(index) / float(maxi(1, rows.size()))
  roster.append({"kind":str(rows[index].kind), "position":f.sim.hero.position + Vector3(cos(angle), 0.0, sin(angle)) * 5.0, "hp":float(rows[index].hp)})
 if not check(f.sim.begin_encounter(room_id, roster).get("accepted", false), "actual source begin_encounter, explicit standalone roster"): return false
 for _tick: int in range(100):
  var spawning: bool = false
  for enemy: Dictionary in f.sim.living():
   if enemy.state == "spawn": spawning = true
  if not spawning: break
  f.sim.step(f.sim.FIXED_TICK)
 for enemy: Dictionary in f.sim.enemies:
  if not check(not enemy.dead and enemy.state != "spawn", "standalone actor exits original spawn grace"): return false
 owners(f, "standalone source room")
 check(f.sim.ai_enabled and f.sim.auto_finish and not f.sim.hero.dead and not f.sim.paused, "original source AI/clock/auto-finish remain enabled")
 evidence.rooms.append({"room_id":room_id, "generation":f.sim.encounter_generation, "declared_roster":roster, "source_actor_ids":f.sim.enemies.map(func(enemy: Dictionary): return enemy.actor_id), "productionSession":false, "authored_floor_route":false, "hp_override_via_original_spawn_API":true})
 return true

func kill_packet(f: Dictionary, enemy: Dictionary) -> Dictionary:
 var before: Dictionary = protected(f.model)
 var count: int = f.kills.size()
 var context: Dictionary = f.sim.new_cast("q", "g02_explicit_source_packet_fixture")
 f.sim.start_skill_cooldown("q", 10.0)
 var hp: float = enemy.hp
 var killed: bool = f.sim.damage_enemy(enemy, hp + 100000.0, "q1", int(context.cast_id), true, false, {"fixture":true, "direct":true, "active_skill":true, "no_reactions":true, "generation":f.sim.encounter_generation, "room_id":f.sim.room_id})
 if not check(killed and enemy.dead and float(enemy.hp) == 0.0 and f.kills.size() == count + 1, "one real source packet commits one original death"): return {}
 var record: Dictionary = f.kills.back()
 if not check(not record.live_witness.is_empty() and record.original_target_dead and record.before == before, "one dynamic G02 source death witness before actual Model submission"): return {}
 check(str(record.event.source) == "q1" and int(record.event.cast_id) == int(context.cast_id), "actual source event retains original packet cast")
 record["fixture"] = {"original_HP_override":hp, "nominal_source_damage":hp + 100000.0, "actual_skill_input":false, "API":"new_cast + start_skill_cooldown + damage_enemy", "real_death":true}
 return record

func end_room(f: Dictionary) -> bool:
 for _tick: int in range(100):
  if f.sim.phase != "combat": break
  f.sim.step(f.sim.FIXED_TICK)
 return check(f.sim.phase == "victory" and f.model.state.phase == "safe" and f.sim.living().is_empty(), "original source naturally ends fixture room after all actors die")

func assert_task(f: Dictionary, progress: int, complete: bool, bonus: int, label: String) -> void:
 var value: Dictionary = task(f.model)
 var ledger: Dictionary = task_ledger(f.model)
 check(int(value.progress) == progress and bool(value.completed) == complete, label + ": exact G02 progression")
 check(int(ledger.get("progress", 0)) == progress, label + ": original commerce taskLedger progress")
 check(ledger.get("completed_stages", []) == (["task:G02:1"] if complete else []), label + ": one original completed stage")
 check(ledger.get("permanent_rewards", {}).size() == (1 if complete else 0), label + ": one original permanent task reward")
 check(f.model.state.completed_equipment_tasks.has("final:G02") == complete and f.model.state.bonus_awards.has("task:G02") == complete, label + ": exact task/award identities")
 if complete: check(int(f.model.state.bonus_awards["task:G02"].amount) == 1, label + ": original G02 reward is1SP")
 check(int(f.model.state.bonus_sp) == bonus and int(f.model.state.points) == int(f.baseline_points) + bonus, label + ": only declared task SP delta")
 check(int(f.model.state.gold) == int(f.baseline_gold) and int(f.model.state.xp) == int(f.baseline_xp), label + ": standalone task observer grants no Session gold/XP rewards")

func reject_replays(f: Dictionary) -> void:
 var original: Dictionary = f.last_event.duplicate(true)
 var before: Dictionary = protected(f.model)
 check(f.sim.verify_g02_kill_attribution(f.model, original, f.run_id).is_empty(), "historical actual event has no live G02 witness")
 var replay: Dictionary = f.model.record_battle_event(f.sim, original, f.run_id)
 check(protected(f.model) == before, "saved actual death cannot repeat G02 progress or reward")
 f.synthetic = true
 f.sim.emit_event("kill", original.duplicate(true))
 f.synthetic = false
 check(protected(f.model) == before and f.kills.back().live_witness.is_empty(), "public copy with a fresh sequence cannot reuse the corpse")
 var corpse: Dictionary = f.sim.enemy_by_id(str(original.target))
 var repeated: bool = f.sim.damage_enemy(corpse, 100000.0, "q1", int(original.cast_id), true, false, {"fixture":true, "active_skill":true, "direct":true})
 check(not repeated and protected(f.model) == before, "another source damage call on the dead original actor cannot kill twice")
 evidence.counterfeits.append({"original":original, "model_replay":replay, "unchanged":protected(f.model) == before, "productionSession":false})

func completed_commerce(f: Dictionary) -> bool:
 var before: Dictionary = protected(f.model)
 if not check(commerce(f, "begin_visit", {"area":str(f.sim.room_id) + "/post-source-shop"}, true).get("accepted", false), "standalone post-victory original visit") or not check(commerce(f, "open_ui").get("accepted", false), "standalone post-victory shop opens"): return false
 var copies: int = 0
 for entry: Dictionary in f.model.state.inventory:
  if entry.id == "final:G02": copies += int(entry.count)
 for _copy: int in range(copies):
  var held: Dictionary = {}
  for entry: Dictionary in f.model.state.inventory:
   if entry.id == "final:G02": held = entry; break
  if not check(not held.is_empty() and commerce(f, "sell", {"uid":held.uid}).get("accepted", false), "completed standalone G02 sale"): return false
  check(protected(f.model) == before, "completed stage/reward retained on each sale")
 for _copy: int in range(copies):
  if not check(commerce(f, "buy", {"item":"final:G02"}).get("accepted", false), "completed standalone G02 repurchase"): return false
  check(protected(f.model) == before, "repurchase never regrants completed task")
 for _undo: int in range(copies * 2):
  if not check(commerce(f, "undo").get("accepted", false), "completed standalone original commerce undo"): return false
  check(protected(f.model) == before, "commerce undo cannot rewind task completion or reward")
 return check(commerce(f, "close_ui").get("accepted", false), "standalone completed shop closes")

func dispose(f: Dictionary) -> void:
 if f.is_empty(): return
 if is_instance_valid(f.sim):
  if f.sim.combat_event.is_connected(f.callback): f.sim.combat_event.disconnect(f.callback)
  # The bound Callable retains this Dictionary, which also stores the Callable.
  # Disconnecting the signal alone does not break that fixture-owned cycle.
  f.erase("callback")
  f.sim.free()

func exact500() -> void:
 current = GROUPS[0]
 var f: Dictionary = fresh(["final:G02", "final:G02"])
 if f.is_empty(): return
 var all_rows: Array = []
 for _elite: int in range(49): all_rows.append({"kind":"elite", "hp":1.0, "weight":10})
 for _ordinary: int in range(10): all_rows.append({"kind":"armored" if _ordinary == 0 else "minion", "hp":1.0, "weight":1})
 var progress: int = 0
 var deaths: int = 0
 for start: int in range(0, all_rows.size(), 6):
  var rows: Array = all_rows.slice(start, mini(start + 6, all_rows.size()))
  if not start_room(f, rows): dispose(f); return
  var actors: Array = f.sim.enemies.duplicate()
  for index: int in range(actors.size()):
   var record: Dictionary = kill_packet(f, actors[index])
   if record.is_empty(): dispose(f); return
   deaths += 1; progress += int(rows[index].weight)
   assert_task(f, progress, progress == 500, 1 if progress == 500 else 0, "actual standalone death%d" % deaths)
   if progress in [490, 499, 500]: evidence.thresholds.append({"progress":progress, "death_number":deaths, "record":record, "productionSession":false})
  if start + rows.size() == all_rows.size(): reject_replays(f)
  if not end_room(f): dispose(f); return
 check(deaths == 59 and progress == 500, "49elite+10ordinary produce exact500 with two-copy unique task")
 if not completed_commerce(f): dispose(f); return
 # A new genuine death after completion is different from a corpse replay.
 if not start_room(f, [{"kind":"boss", "hp":1.0, "weight":25}]): dispose(f); return
 var saved: Dictionary = protected(f.model)
 if kill_packet(f, f.sim.enemies[0]).is_empty(): dispose(f); return
 check(protected(f.model) == saved, "a further real Boss death cannot regrant completed G02")
 if not end_room(f): dispose(f); return
 owners(f, "exact500 finish")
 check(f.errors.is_empty(), "all actual standalone Model events remain accepted")
 evidence.finished.append({"group":current, "task":protected(f.model), "productionSession":false, "natural":false})
 dispose(f); completed.append(current)

func shared_finish() -> void:
 current = GROUPS[1]
 var f: Dictionary = fresh(["final:G02", "final:G02", "final:B01", "final:G06", "final:B04"])
 if f.is_empty(): return
 var rows: Array = []
 for _boss: int in range(18): rows.append({"kind":"boss", "hp":5000.0, "weight":25})
 rows.append({"kind":"elite", "hp":9000.0, "weight":10})
 for _ordinary: int in range(20): rows.append({"kind":"minion", "hp":1.0, "weight":1})
 rows.append({"kind":"boss", "hp":1000.0, "weight":25})
 var progress: int = 0
 var deaths: int = 0
 var elite_loss: float = 0.0
 for start: int in range(0, rows.size(), 5):
  var batch: Array = rows.slice(start, mini(start + 5, rows.size()))
  if not start_room(f, batch): dispose(f); return
  var actors: Array = f.sim.enemies.duplicate()
  for index: int in range(actors.size()):
   if deaths == 39:
    check(progress == 480 and int(task(f.model).progress) == 480 and int(f.model.snapshot().b01_equipment.progress) == 39, "one genuine final target remains before both tasks complete")
    near(float(f.model.snapshot().g06_equipment.progress), 99000.0, "G06 also waits for last1000 real HP")
   var record: Dictionary = kill_packet(f, actors[index])
   if record.is_empty(): dispose(f); return
   deaths += 1; progress = mini(500, progress + int(batch[index].weight))
   if batch[index].kind in ["elite", "boss"]: elite_loss += float(batch[index].hp)
   assert_task(f, progress, deaths == 40, 2 if deaths == 40 else 0, "shared actual standalone death%d" % deaths)
   check(int(f.model.snapshot().b01_equipment.progress) == mini(40, deaths), "B01 independently counts each original Q source target")
   near(float(f.model.snapshot().g06_equipment.progress), elite_loss, "G06 independently counts only original elite/Boss HP loss")
   check(int(f.model.basic_cycle_status().remainder) == 0, "Q source deaths cannot impersonate B04 basics")
   if deaths == 40: evidence.thresholds.append({"same_source_final_death":record, "g02":task(f.model), "b01":f.model.snapshot().b01_equipment, "g06":f.model.snapshot().g06_equipment, "productionSession":false})
  if start + batch.size() == rows.size(): reject_replays(f)
  if not end_room(f): dispose(f); return
 check(deaths == 40 and task(f.model).completed and f.model.snapshot().b01_equipment.completed and f.model.snapshot().g06_equipment.completed, "one final actual source death completes three independent authored tasks")
 check(f.model.state.completed_equipment_tasks.has("final:B01") and f.model.state.completed_equipment_tasks.has("final:G02") and not f.model.state.completed_equipment_tasks.has("final:G06"), "only SP tasks enter completed_equipment_tasks")
 check(not f.model.state.bonus_awards.has("task:G06") and f.model.state.evolved_equipment_tasks.has("final:G06"), "G06 remains evolution-only with zeroSP")
 owners(f, "shared final finish")
 check(f.errors.is_empty(), "all shared actual standalone Model events remain accepted")
 evidence.finished.append({"group":current, "task":protected(f.model), "productionSession":false, "natural":false})
 dispose(f); completed.append(current)

func run() -> void:
 if GROUPS[0] in required: exact500()
 if GROUPS[1] in required: shared_finish()
 check(completed == required, "every selected standalone threshold group reached")
 var report: Dictionary = {"suite":"g02_standalone_real_source_threshold", "passed":failures.is_empty() and completed == required, "runtime_status":"EXECUTED", "partition":partition, "required_groups":required, "completed_groups":completed, "checks":checks, "failures":failures, "check_records":records, "evidence":evidence, "productionSession":false, "Host_created":false, "Session_created":false, "natural":false, "natural_first_floor_500":false, "authored_first_floor_maximum":79, "source_API_packet_fixture":true, "source_spawn_HP_override_fixture":true, "wallet_fixture":true, "task_progress_written":false, "native_GUI":false, "multiplayer_participation":false, "production_ready":false}
 var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
 if file == null: push_error("Unable to write G02 standalone source result"); quit(2); return
 file.store_string(JSON.stringify(report, "  "))
 var write_error: Error = file.get_error(); file.close()
 print("G02_STANDALONE_SOURCE ", JSON.stringify({"passed":report.passed, "checks":checks, "failures":failures, "result":output_path}))
 quit(2 if write_error != OK else (0 if report.passed else 1))
