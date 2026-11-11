extends RefCounted
## NOT EXECUTED. Load only inside the existing authenticated, guarded fixture flow.
## No SceneTree entry, engine launch, guard override, money injection or natural-run claim.
var checks: Array = []
var failures: Array = []
var pickup_event: Dictionary = {}
var samples: Array = []

func check(label: String, passed: bool, detail: Variant = null) -> void:
 var row: Dictionary = {"check":label, "passed":passed, "detail":detail}
 checks.append(row)
 if not passed: failures.append(row)

func suspend_fixture(_reason: String) -> void: pass

func protected(sim: Node) -> Dictionary:
 return {"souls":sim.common.runtime.souls.duplicate(true), "cooldowns":sim.hero.cooldowns.duplicate(true), "hp":sim.hero.hp, "stats":sim.hero.stats.duplicate(true), "world_time":sim.clock.world_time, "real_time":sim.real_time, "hero_time":sim.hero_time, "source_time":sim.common.runtime.time, "source_actor_time":sim.common.runtime.actor_time, "speed_until":sim.common.runtime.soul_speed_until, "events":sim.event_log.duplicate(true), "phase":sim.phase}

func event_received(event: Dictionary, view: RefCounted, sim: Node) -> void:
 var accepted: bool = view.accept(event, sim)
 if event.get("kind") == "common_hex_soul_pickup":
  if sim.common._draining:
   check("original_pickup_accepted_synchronously", accepted)
   pickup_event = event.duplicate(true)
  else:
   check("non_original_pickup_notification_rejected", not accepted)

func run() -> Dictionary:
 checks.clear(); failures.clear(); samples.clear(); pickup_event.clear()
 var sim: Node = load("res://fengli_route_20261024/sim.gd").new()
 var session: RefCounted = load("res://fengli_route_20261024/session.gd").new()
 var view: RefCounted = load("res://fengli_route_20261024/soul_pickup_view.gd").new()
 var path: String = "res://__clean_fengli/machine_templates.bin"
 var config: Dictionary = session.configure_reward_table(path, path, path, true)
 var route: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(session.DEFAULT_DEFINITION))
 var bound: Dictionary = session.initialize_floor(sim, route, "g10-source-fixture", true) if config.get("accepted", false) else config
 check("fresh_real_session", bound.get("accepted", false), bound.get("reason", ""))
 if not bound.get("accepted", false): sim.free(); return result()
 session.bind_input_suspender(suspend_fixture)
 var model: RefCounted = session.ledger.model
 # Explicit isolated selection/skill fixtures. No claims about natural RNG or leveling.
 model.state.selected_hex = ["common_g10"]
 session.ledger.refresh_runtime()
 sim.hero.ranks.q = 1; sim.hero.ranks.e = 1
 sim.ai_enabled = false; sim.auto_finish = false
 sim.hero.position = Vector3(0.0, 0.0, 10.0)
 sim.combat_event.connect(event_received.bind(view, sim))
 var room: String = session.run_id + "/soul-fixture"
 var commerce: Dictionary = session._authority("enter_room", {"next_room":room})
 var level: Dictionary = session.ledger.command("enter_level", {"combat_level_id":room})
 var begun: Dictionary = sim.begin_encounter(room, [{"kind":"elite", "position":Vector3(0.0, 0.0, -3.0), "hp":100.0}, {"kind":"minion", "position":Vector3(6.0, 0.0, -3.0), "hp":100.0}])
 check("real_source_encounter", commerce.get("accepted", false) and level.get("ok", false) and begun.get("accepted", false))
 if not begun.get("accepted", false): sim.free(); return result()
 sim.paused = false
 for enemy: Dictionary in sim.enemies: enemy.state = "chase" # Skip spawn windup only.
 var killed: bool = sim.damage_enemy(sim.enemies[0], 10000.0, "fixture_source_packet", 0, true, false, {"fixture":true, "direct":true})
 check("real_elite_death_creates_soul", killed and sim.common.runtime.souls.size() == 1)
 if sim.common.runtime.souls.is_empty(): sim.free(); return result()
 var before: Dictionary = protected(sim)
 var first: Dictionary = view.sample(sim)
 samples.append(first)
 view.sample(sim)
 check("view_does_not_write_gameplay", before == protected(sim))
 check("live_position_TTL_radius", first.get("live_count", 0) == 1 and first.souls[0].position == sim.common.runtime.souls[0].position and first.souls[0].left == sim.common.runtime.souls[0].left and is_equal_approx(first.souls[0].pickup_radius, model.hex_parameter("common_g10", "G10-6")))
 sim.paused = true; sim.step(0.25)
 check("paused_source_and_view_frozen", first == view.sample(sim))
 sim.paused = false
 var at: Vector3 = first.souls[0].position
 var radius: float = first.souls[0].pickup_radius
 sim.hero.position = at + Vector3(radius + 0.1, 0.0, 0.0)
 sim.step(0.05)
 check("outside_original_pickup_radius_stays_live", view.sample(sim).get("live_count", 0) == 1)
 sim.hero.cooldowns.q = 5.0; sim.hero.cooldowns.e = 5.0
 sim.hero.position = at
 sim.step(0.05)
 var picked: Dictionary = view.sample(sim)
 samples.append(picked)
 check("real_touch_removes_entity_and_flashes", picked.get("live_count", -1) == 0 and picked.get("pickup_count", 0) == 1 and not pickup_event.is_empty())
 check("original_QE_reset_preserved", sim.hero.cooldowns.q == 0.0 and sim.hero.cooldowns.e == 0.0)
 check("event_replay_rejected", not view.accept(pickup_event, sim) and view.sample(sim).get("pickup_count", 0) == 1)
 var fake: Dictionary = pickup_event.duplicate(true)
 fake.erase("kind")
 sim.emit_event("common_hex_soul_pickup", fake)
 check("public_fake_event_adds_no_flash", view.sample(sim).get("pickup_count", 0) == 1)
 sim.step(0.5)
 check("feedback_expires_on_source_world_clock", view.sample(sim).get("pickup_count", 0) == 0)
 # Source arrays and generations are explicit lifecycle fixtures, not earned drops.
 var saved_soul: Dictionary = first.souls[0].duplicate(true)
 sim.common.runtime.souls.append({"entity_id":saved_soul.entity_id, "position":saved_soul.position, "left":0.05, "last_world_at":sim.common.runtime.time})
 sim.hero.position = Vector3(0.0, 0.0, 10.0)
 check("expiry_fixture_visible", view.sample(sim).get("live_count", 0) == 1)
 sim.step(0.1)
 check("original_expiry_removes_without_flash", view.sample(sim).get("live_count", -1) == 0 and view.sample(sim).get("pickup_count", -1) == 0)
 sim.common.runtime.souls.append({"entity_id":"fixture-lifecycle", "position":at, "left":8.0, "last_world_at":sim.common.runtime.time})
 view.sample(sim)
 sim.common.runtime.souls.clear()
 check("source_clear_has_no_cached_ground_entity", view.sample(sim).get("live_count", -1) == 0)
 sim.encounter_generation += 1 # Explicit scope-mismatch fixture.
 check("new_generation_drops_previous_receipt", view.sample(sim).get("live_count", 0) == 0 and view.receipt.pickups.is_empty())
 sim.encounter_generation -= 1
 sim.hero.dead = true
 check("death_clears_view", view.sample(sim).get("live_count", 0) == 0 and view.receipt.souls.is_empty() and view.receipt.pickups.is_empty())
 sim.hero.dead = false
 sim.end_encounter("victory")
 check("battle_end_clears_view", view.sample(sim).get("live_count", 0) == 0 and view.receipt.souls.is_empty() and view.receipt.pickups.is_empty())
 sim.free()
 return result()

func result() -> Dictionary:
 return {"status":"FIXTURE_PASS_NOT_GRAPHICAL_ACCEPTANCE" if failures.is_empty() else "FAIL", "checks":checks, "failures":failures, "samples":samples, "scope":{"engine_execution":"NOT_RUN_UNTIL_GUARDED_INVOCATION", "selection":"explicit G10 fixture", "kills":"real damage method with fixture lethal packet", "lifecycle":"explicit source-array expiry fixture", "graphics":"NOT_TESTED", "natural_floor":"NOT_TESTED"}}

func observe_frame(host: Node) -> Dictionary:
 ## Optional read-only capture beside screenshots during a later guarded UI run.
 return {"phase":host.sim.phase, "paused":host.sim.paused, "run_id":host.shop_session.run_id, "room_id":host.sim.room_id, "generation":host.sim.encounter_generation, "world_time":host.sim.clock.world_time, "source_souls":host.sim.common.runtime.souls.duplicate(true), "rendered":host.presentation.receipt.get("soul_pickups", {}).duplicate(true)}
