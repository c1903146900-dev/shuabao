extends RefCounted
## NOT RUN. Opt-in fixture for the existing guarded flow, not an engine entry.
## Explicit selection/lifecycle setup is fixture-only, not a natural-play claim.
var checks: Array = []
var failures: Array = []
var shot_events: Array = []

func check(label: String, passed: bool, detail: Variant = null) -> void:
 var row: Dictionary = {"check":label, "passed":passed, "detail":detail}
 checks.append(row)
 if not passed: failures.append(row)

func suspend_fixture(_reason: String) -> void: pass

func protected(sim: Node, model: RefCounted) -> Dictionary:
 return {"turrets":sim.common.runtime.turrets.duplicate(true), "projectiles":sim.common.runtime.projectiles.duplicate(true), "queue":sim.common.runtime._events.duplicate(true), "enemies":sim.enemies.duplicate(true), "cooldowns":sim.hero.cooldowns.duplicate(true), "hp":sim.hero.hp, "world_time":sim.clock.world_time, "real_time":sim.real_time, "hero_time":sim.hero_time, "source_time":sim.common.runtime.time, "source_actor_time":sim.common.runtime.actor_time, "events":sim.event_log.duplicate(true), "model":model.state.duplicate(true)}

func event_received(event: Dictionary, view: RefCounted, sim: Node) -> void:
 var accepted: bool = view.accept(event, sim)
 if event.get("kind") == "damage" and event.get("source") == "common_g28":
  if sim.common._draining and sim.common._inside_hit > 0:
   check("committed_original_shot_accepted", accepted)
   shot_events.append(event.duplicate(true))
  else:
   check("public_damage_notification_rejected", not accepted)
 elif event.get("kind") in ["common_hex_damage", "common_hex_turret_spawn"]:
  check("request_or_spawn_event_does_not_invent_shot", not accepted)

func advance(sim: Node, seconds: float) -> void:
 for index in range(int(ceil(seconds * 120.0))): sim.step(1.0 / 120.0)

func run() -> Dictionary:
 checks.clear(); failures.clear(); shot_events.clear()
 var sim: Node = load("res://fengli_route_20261024/sim.gd").new()
 var session: RefCounted = load("res://fengli_route_20261024/session.gd").new()
 var view: RefCounted = load("res://fengli_route_20261024/turret_view.gd").new()
 var path: String = "res://__clean_fengli/machine_templates.bin"
 var config: Dictionary = session.configure_reward_table(path, path, path, true)
 var route: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(session.DEFAULT_DEFINITION))
 var bound: Dictionary = session.initialize_floor(sim, route, "g28-source-fixture", true) if config.get("accepted", false) else config
 check("fresh_real_session", bound.get("accepted", false), bound.get("reason", ""))
 if not bound.get("accepted", false): sim.free(); return result()
 session.bind_input_suspender(suspend_fixture)
 var model: RefCounted = session.ledger.model
 check("G28_first_floor_support", model.support(model.config.hexes.common_g28).supported)
 model.state.selected_hex = ["common_g28"] # Selection fixture, not forced natural RNG.
 session.ledger.refresh_runtime()
 sim.ai_enabled = false; sim.auto_finish = false
 sim.hero.position = Vector3.ZERO; sim.hero.facing = Vector3.BACK
 sim.combat_event.connect(event_received.bind(view, sim))
 var room: String = session.run_id + "/turret-fixture"
 var commerce: Dictionary = session._authority("enter_room", {"next_room":room})
 var level: Dictionary = session.ledger.command("enter_level", {"combat_level_id":room})
 var begun: Dictionary = sim.begin_encounter(room, [{"kind":"minion", "position":Vector3(3.0, 0.0, 0.0), "hp":1000.0}, {"kind":"minion", "position":Vector3(-6.0, 0.0, 0.0), "hp":1000.0}])
 check("real_source_encounter", commerce.get("accepted", false) and level.get("ok", false) and begun.get("accepted", false))
 if not begun.get("accepted", false): sim.free(); return result()
 for enemy: Dictionary in sim.enemies: enemy.state = "chase" # Only skip spawn windup.
 sim.paused = false
 var origin: Vector3 = sim.hero.position
 var dashed: Dictionary = sim.request_action("shift", Vector3.INF, "g28-first-dash")
 check("real_Shift_accepted", dashed.get("accepted", false))
 check("no_turret_before_Shift_ends", view.sample(sim).live_count == 0)
 advance(sim, 0.4)
 var first: Dictionary = view.sample(sim)
 check("live_turret_uses_dash_origin", first.live_count == 1 and first.turrets[0].position == origin and first.turrets[0].cast_id == dashed.get("cast_id", -1))
 if first.live_count != 1: sim.free(); return result()
 check("source_TTL_is_not_recomputed", first.turrets[0].left == sim.common.runtime.turrets[0].left)
 var before: Dictionary = protected(sim, model)
 view.sample(sim); view.sample(sim)
 check("view_has_no_gameplay_writes", before == protected(sim, model))
 sim.paused = true; advance(sim, 0.5)
 check("pause_freezes_source_and_view", first == view.sample(sim))
 sim.paused = false
 for index in range(160):
  sim.step(1.0 / 120.0)
  if not shot_events.is_empty(): break
 var fired: Dictionary = view.sample(sim)
 check("actual_damage_creates_one_instant_trace", shot_events.size() == 1 and fired.shot_count == 1 and not fired.flight_simulated)
 if shot_events.is_empty(): sim.free(); return result()
 var shot: Dictionary = shot_events[0]
 check("trace_matches_committed_origin_target", fired.shots[0].source_position == shot.source_position and fired.shots[0].position == shot.position and fired.shots[0].amount == shot.amount)
 check("nearest_enemy_and_original_amount_still_source_owned", shot.target == sim.enemies[0].actor_id and shot.amount > 0.0)
 check("event_replay_cannot_duplicate_trace", not view.accept(shot, sim) and view.sample(sim).shot_count == 1)
 var fake: Dictionary = shot.duplicate(true); fake.erase("kind")
 sim.emit_event("damage", fake)
 check("public_fake_damage_cannot_create_trace", view.sample(sim).shot_count == 1)
 sim.paused = true; advance(sim, 0.5)
 check("pause_freezes_shot_feedback", view.sample(sim).shots == fired.shots)
 sim.paused = false; advance(sim, 0.2)
 check("feedback_expires_without_second_clock", view.sample(sim).shot_count == 0)
 advance(sim, 4.0)
 check("source_expiry_removes_body_without_resurrection", sim.common.runtime.turrets.is_empty() and view.sample(sim).live_count == 0)
 # Lifecycle fixtures use real source entries only for explicit clear/replace cases.
 var entry: Dictionary = first.turrets[0].duplicate(true)
 entry.merge({"left":4.0, "fire":0.8, "damage":1.0, "last_world_at":sim.common.runtime.time}, true)
 sim.common.runtime.turrets.append(entry)
 check("explicit_live_fixture_is_visible", view.sample(sim).live_count == 1)
 sim.common.runtime.turrets.clear()
 check("source_clear_removes_cached_body", view.sample(sim).live_count == 0)
 sim.common.runtime.turrets.append(entry.duplicate(true))
 sim.encounter_generation += 1
 check("generation_change_clears_body_and_feedback", view.sample(sim).live_count == 0 and view.receipt.shot_count == 0)
 sim.encounter_generation -= 1
 sim.hero.dead = true
 check("death_clears_body_and_feedback", view.sample(sim).live_count == 0 and view.receipt.shot_count == 0)
 sim.hero.dead = false
 sim.end_encounter("victory")
 check("combat_end_clears_body_and_feedback", view.sample(sim).live_count == 0 and view.receipt.shot_count == 0)
 sim.free()
 return result()

func result() -> Dictionary:
 return {"status":"FIXTURE_PASS_NOT_GRAPHICAL_ACCEPTANCE" if failures.is_empty() else "FAIL", "checks":checks, "failures":failures, "scope":{"engine":"NOT_RUN_UNTIL_GUARDED_INVOCATION", "selection":"explicit G28 fixture", "trigger":"real Shift action and source tick", "lifecycle":"explicit source-array fixture", "graphics":"NOT_TESTED", "natural_floor":"NOT_TESTED"}}

func observe_frame(host: Node) -> Dictionary:
 return {"phase":host.sim.phase, "paused":host.sim.paused, "source_turrets":host.sim.common.runtime.turrets.duplicate(true), "rendered":host.presentation.receipt.get("common_turrets", {}).duplicate(true)}
