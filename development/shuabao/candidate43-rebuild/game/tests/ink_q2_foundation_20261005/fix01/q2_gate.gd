extends SceneTree
## Finite main-owned actual-engine gate. Authored assertions are NOT test passes.
const Sim = preload("res://tests/ink_q2_foundation_20261005/fix01/ink_q2_sim.gd")
const Before = preload("res://tests/ink_q3_foundation_20261004/fix02/ink_q3_sim.gd")
const Geo = preload("res://tests/ink_q2_foundation_20261005/fix01/river_geometry.gd")
var checks: int = 0
var failures: Array = []
var completed: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok: failures.append(label); push_error(label)
func near(a: float, b: float, label: String, epsilon: float = .00001) -> void:
 check(is_finite(a) and absf(a - b) <= epsilon, "%s %.9f expected %.9f" % [label, a, b])
func fresh(rank: int = 1, ids: Array = []):
 var sim = Sim.new(); root.add_child(sim); sim.auto_finish = false; sim.ai_enabled = false
 sim.hero.position = Vector3.ZERO; sim.hero.loadout.q = "q2"; sim.hero.ranks.q = rank
 sim.hero.stats.ap = 100.0; sim.hero.stats.crit_chance = 0.0
 sim.begin_encounter("q2-finite", []); sim.set_hexes(ids)
 return sim
func target(sim, point: Vector3, kind: String = "minion") -> Dictionary:
 var enemy: Dictionary = sim.spawn_enemy(kind, point, 100000.0)
 enemy.state = "chase"; enemy.defence = 0.0; enemy.radius = .25
 return enemy
func make_river(sim, a: Vector3 = Vector3(2, 0, -3), b: Vector3 = Vector3(2, 0, 3)) -> Dictionary:
 var first: Dictionary = sim.request_q2("first", a)
 check(first.accepted, "first marker admitted")
 var second: Dictionary = sim.request_q2("second", b, "", first.get("cast_id", -1), sim.encounter_generation)
 check(second.accepted, "second marker admitted")
 check(first.get("cast_id") == second.get("cast_id"), "one root action for A and B")
 return second
func events(sim, kind: String) -> Array: return sim.event_log.filter(func(event): return event.kind == kind)
func run() -> void:
 test_source_ranks(); test_partial_cd(); test_input_and_h03(); test_activation_and_sweep(); test_h04(); test_projectiles(); test_lifecycle(); test_callbacks(); test_pause_and_order(); test_retained()
 var required: Array = ["source_ranks", "partial_cd", "input_h03", "activation_sweep", "h04", "projectiles", "lifecycle", "callbacks", "pause_and_order", "retained"]
 for name in required: check(name in completed, "case completed " + name)
 var result: Dictionary = {"suite":"ink_q2_foundation_finite", "passed":failures.is_empty(), "checks":checks, "failures":failures, "completed":completed, "source_binding_sha256":FileAccess.get_sha256("res://tests/ink_q2_foundation_20261005/fix01/source_binding.json"), "engine_run":true, "normal_input":false, "ordinary_entry":false, "visual_acceptance":false, "scope":"finite isolated Q2/H03/H04 and BASIC/Shift projectile mechanics only"}
 var output = FileAccess.open("res://tests/ink_q2_foundation_20261005/fix01/q2_result.json", FileAccess.WRITE)
 output.store_string(JSON.stringify(result, "  ")); output.close()
 print("INK_Q2_FOUNDATION_REPORT ", JSON.stringify(result)); quit(0 if failures.is_empty() else 1)
func test_source_ranks() -> void:
 for rank in range(1, 7):
  var sim = fresh(rank)
  var enemy: Dictionary = target(sim, Vector3(2, 0, 0))
  var hp: float = enemy.hp
  var first: Dictionary = sim.request_q2("first", Vector3(2, 0, -3))
  near(sim.hero.cooldowns.q, 0, "first marker never starts CD rank %d" % rank)
  near(enemy.hp, hp, "first marker no river damage")
  near(sim.ink_q2_pending.expires_at - sim.ink_q2_pending.born_at, sim.v("Q2-2", rank), "source recast window")
  sim.request_q2("second", Vector3(2, 0, 3), "", first.cast_id)
  var river: Dictionary = sim.ink_rivers[0]
  near(river.expires_at - river.born_at, sim.v("Q2-5", rank), "source river duration")
  near(river.width, sim.v("Q2-4", rank), "source river width")
  near(hp - enemy.hp, sim.v("Q2-6", rank) + 100 * sim.v("Q2-7", rank) * .01, "birth contact source damage")
  near(sim.hero.cooldowns.q, sim.v("Q2-10", rank), "valid completion starts source CD")
  sim.free()
 completed.append("source_ranks")
func test_partial_cd() -> void:
 var sim = fresh()
 var first: Dictionary = sim.request_q2("first", Vector3.ZERO, "unique-first")
 sim.step(4.0)
 near(sim.hero.cooldowns.q, 0, "four seconds pending no cooldown")
 check(not sim.ink_q2_pending.is_empty(), "marker alive before five seconds")
 sim.step(1.0)
 check(sim.ink_q2_pending.is_empty() and sim.ink_rivers.is_empty(), "timeout removes marker without river")
 near(sim.hero.cooldowns.q, 10.5, "expiry starts complete source cooldown")
 check(sim._casts[first.cast_id].finished, "incomplete root finished once at expiry")
 check(events(sim, "ink_q2_placement_expired").size() == 1, "one expiry event")
 sim.step(.5); near(sim.hero.cooldowns.q, 10.0, "CD ticks only after expiry")
 sim.free()
 sim = fresh(); sim.request_q2("first", Vector3.ZERO); sim.step(2.0)
 sim.request_q2("second", Vector3(3, 0, 0)); near(sim.hero.cooldowns.q, 10.5, "successful B after delay starts full CD")
 sim.free(); completed.append("partial_cd")
func test_input_and_h03() -> void:
 for choice in ["q1", "q3"]:
  var other = fresh(); other.hero.loadout.q = choice
  check(not other.request_q2("first", Vector3(4, 0, 0)).accepted, "Q2 logical command cannot become " + choice)
  check(other.cast_serial == 0 and other.ink_mountain.is_empty() and other.ink_input.phase == "idle", "wrong-candidate Q2 command has no side effects")
  other.free()
 var sim = fresh(1, ["yanguizhou_h03"])
 check(not sim.request_q2("first", Vector3.INF).accepted, "nonfinite A rejected")
 check(not sim.request_q2("first", Vector3(10.001, 0, 0)).accepted, "outside source A range rejected")
 check(sim.cast_serial == 0 and sim.hero.cooldowns.q == 0, "invalid A costs no cast/CD")
 var first: Dictionary = sim.request_q2("first", Vector3(10, 0, 0), "first")
 var replay: Dictionary = sim.request_q2("first", Vector3.ZERO, "first")
 check(replay.cast_id == first.cast_id and sim.cast_serial == first.cast_id, "duplicate command returns first receipt")
 check(not sim.request_q2("second", Vector3(11, 0, 0), "", first.cast_id + 1).accepted, "stale root rejected")
 check(not sim.request_q2("second", Vector3(11, 0, 0), "", first.cast_id, sim.encounter_generation + 1).accepted, "stale generation rejected")
 check(sim.request_q2("corner", Vector3(10, 0, 2)).accepted, "H03 corner one")
 check(sim.request_q2("corner", Vector3(12, 0, 2)).accepted, "H03 corner two")
 check(not sim.request_q2("corner", Vector3(12, 0, 3)).accepted, "H03 no third corner")
 check(not sim.request_q2("second", Vector3(21, 0, 2)).accepted, "total arc length enforced, not chord/per-leg")
 sim.hero.position = Vector3(-7, 0, 0)
 check(sim.request_q2("second", Vector3(12, 0, 5)).accepted, "B not silently restricted to A caster range")
 check(sim.ink_rivers[0].path.size() == 4 and sim.ink_rivers[0].path[0] == Vector3(10, 0, 0), "world anchors remain after caster moves")
 near(sim.ink_rivers[0].width, 1.5, "H03 no invented width increase")
 sim.free(); completed.append("input_h03")
func test_activation_and_sweep() -> void:
 near(Geo.entry(Vector3(-5, 0, 0), Vector3(5, 0, 0), .25, [Vector3(0, 0, -2), Vector3(0, 0, 2)], 1.5), .4, "swept finite-width contact")
 check(not Geo.overlaps(Vector3(1, 0, 3), 0, [Vector3(0, 0, -2), Vector3(0, 0, 2)], 1.5), "finite endpoints do not become infinite lines")
 var sim = fresh()
 for kind in ["minion", "elite", "boss"]:
  target(sim, Vector3(2, 0, 0), kind)
 make_river(sim)
 check(events(sim, "ink_q2_crossing").size() == 3, "activation touches ordinary elite and boss")
 var enemy: Dictionary = target(sim, Vector3(-4, 0, 1))
 var hp: float = enemy.hp
 var before: Dictionary = sim._enemy_motion_snapshot()
 enemy.position = Vector3(7, 0, 1)
 sim._q2_motion_traces = [{"enemy":enemy, "from":Vector3(-4, 0, 1), "to":enemy.position}]
 sim._q2_settle(before, sim.hero_time, sim.hero_time + .01)
 check(enemy.hp < hp, "fast swept entry cannot tunnel across")
 hp = enemy.hp
 sim._q2_settle(before, sim.hero_time, sim.hero_time + .01)
 near(enemy.hp, hp, "same river never hits target twice")
 sim.hero.cooldowns.q = 0 # Explicit fixture: permit second simultaneous river.
 make_river(sim, Vector3(7, 0, -3), Vector3(7, 0, 3))
 check(enemy.hp < hp, "distinct river may hit same target once")
 sim.free()
 sim = fresh(); make_river(sim, Vector3.ZERO, Vector3(0, 0, 3))
 enemy = target(sim, Vector3(2, 0, 1)); before = sim._enemy_motion_snapshot()
 enemy.position = Vector3(0, 0, 1)
 sim._q2_motion_traces = [{"enemy":enemy, "from":Vector3(2, 0, 1), "to":enemy.position, "start":.018, "end":.020}]
 sim._q2_settle(before, 0.0, .020)
 near(events(sim, "ink_q2_crossing")[0].source_time, .019, "short H02 remainder keeps actual contact source time")
 sim.free(); completed.append("activation_sweep")
func test_h04() -> void:
 var sim = fresh(1, ["yanguizhou_h04"])
 var center: Dictionary = target(sim, Vector3(2, 0, 3))
 var edge: Dictionary = target(sim, Vector3(4.5, 0, 3))
 make_river(sim)
 check(events(sim, "ink_h04_contact").is_empty(), "H04 no fabricated birth tick")
 var hp: float = center.hp; var edge_hp: float = edge.hp
 sim.step(4.0)
 var hits: Array = events(sim, "ink_h04_contact").filter(func(event): return event.target_id == center.actor_id)
 check(hits.size() == 8, "H04 exactly eight source ticks")
 near(hp - center.hp, 8 * 38.0, "H04 ordinary AP damage separate from river")
 check(edge.hp < edge_hp and edge.hp > edge_hp - 8 * 38.0, "linear shrinking sunset loses outer target")
 check(sim.ink_rivers.is_empty(), "last tick settles before river/root retirement")
 sim.free(); completed.append("h04")
func test_projectiles() -> void:
 var sim = fresh()
 make_river(sim)
 check(sim.request_action("attack", Vector3(10, 0, 0)).accepted, "real BASIC projectile born")
 var shot: Dictionary = sim.ink_basics[0]
 var speed: float = shot.speed; var length: float = shot.path_length
 # Direct local interval calls avoid adding fake world ticks and establish the
 # contact-time integral using the actual projectile state and collision code.
 var before: Dictionary = sim._enemy_motion_snapshot()
 sim._settle_motion_interval(before, 0.0, .1)
 var boundary: float = 2.0 - .75 - float(shot.width) * .5
 var contact_time: float = boundary / speed
 near(shot.front_distance, boundary + speed * 1.1 * (.1 - contact_time), "same-tick speed integration after first touch")
 near(shot.path_length, length * 1.1, "adds original total range percentage")
 near(shot.speed, speed * 1.1, "speed enhanced once")
 check(bool(shot.q2_enhanced_once), "projectile-wide lifetime eligibility consumed")
 sim.hero.cooldowns.q = 0
 make_river(sim, Vector3(3, 0, -3), Vector3(3, 0, 3))
 sim._settle_motion_interval(before, .1, .2)
 near(shot.speed, speed * 1.1, "all rivers combined only one speed increase")
 near(shot.path_length, length * 1.1, "all rivers combined only one range increase")
 check(events(sim, "ink_q2_projectile_enhanced").size() == 1, "one enhancement receipt across two rivers")
 sim.free()
 sim = fresh(); make_river(sim, Vector3(0, 0, -2), Vector3(0, 0, 2))
 check(sim.request_action("shift", Vector3(10, 0, 0)).accepted, "Shift admitted")
 check(sim.request_action("attack", Vector3(10, 0, 0)).accepted, "real Shift BASIC admitted")
 check(events(sim, "ink_q2_projectile_enhanced").size() == 1, "Shift projectile receives same birth overlap rule")
 sim.free(); completed.append("projectiles")
func test_lifecycle() -> void:
 var sim = fresh(); make_river(sim)
 var old: Dictionary = sim.ink_rivers[0]
 sim.paused = true; var at: float = sim.hero_time
 sim.step(1.0); near(sim.hero_time, at, "pause freezes source clock")
 sim.paused = false
 var steps: int = sim.ink_core_steps
 sim.step(sim.FIXED_TICK)
 check(sim.ink_core_steps == steps + 1, "one shared inherited fixed step per real tick")
 var snapshot: Dictionary = sim.ink_presenter_snapshot(); snapshot.rivers[0].path[0] = Vector3(999, 0, 999)
 check(sim.ink_rivers[0].path[0] != Vector3(999, 0, 999), "presenter snapshot immutable copy")
 sim.end_encounter("cancel")
 check(sim.ink_rivers.is_empty() and sim.ink_q2_pending.is_empty(), "room end clears river and markers")
 check(not sim.effect_is_current(old), "old river cannot cross new generation")
 sim.free(); completed.append("lifecycle")
func test_callbacks() -> void:
 var sim = fresh(); target(sim, Vector3(2, 0, 0)); target(sim, Vector3(2, 0, 1))
 var callback = func(event: Dictionary):
  if event.kind == "damage" and event.source == "q2": sim.end_encounter("callback_cancel")
 sim.combat_event.connect(callback)
 make_river(sim)
 check(events(sim, "damage").size() == 1, "synchronous first damage cancellation stops next enemy")
 check(sim.ink_rivers.is_empty(), "callback cleanup never respawns stale river")
 sim.free(); completed.append("callbacks")
func test_pause_and_order() -> void:
 var sim = fresh()
 var a: Dictionary = target(sim, Vector3(2, 0, 0))
 var b: Dictionary = target(sim, Vector3(2, 0, 1))
 var hp: float = b.hp
 var pause_birth = func(event: Dictionary):
  if event.kind == "damage" and event.source == "q2" and event.target == a.actor_id: sim.paused = true
 sim.combat_event.connect(pause_birth)
 make_river(sim)
 check(sim.paused and not sim.ink_rivers[0].hits.has(b.actor_id), "paused callback does not consume next target claim")
 near(b.hp, hp, "paused second target waits")
 sim.combat_event.disconnect(pause_birth); sim.paused = false
 sim.step(sim.FIXED_TICK)
 near(hp - b.hp, 150.0, "resume delivers deferred birth contact once")
 sim.free()
 sim = fresh(1, ["yanguizhou_h04"])
 a = target(sim, Vector3(2, 0, 3)); b = target(sim, Vector3(2, 0, 3.2))
 make_river(sim); hp = b.hp
 var pause_sunset = func(event: Dictionary):
  if event.kind == "damage" and event.source == "hex_yanguizhou_h04" and event.target == a.actor_id: sim.paused = true
 sim.combat_event.connect(pause_sunset); sim.step(.5)
 sim.combat_event.disconnect(pause_sunset); sim.paused = false; sim.step(sim.FIXED_TICK)
 near(hp - b.hp, 38.0, "resume delivers deferred H04 same tick once")
 sim.free()
 sim = fresh(); make_river(sim)
 var enemy: Dictionary = target(sim, Vector3(3.02, 0, 0))
 enemy.hp = 1.0; enemy.timer = 10.0
 check(sim.request_action("attack", Vector3(10, 0, 0)).accepted, "order regression uses real BASIC")
 sim._set_front(sim.ink_basics[0], 2.5) # Explicit real-projectile position fixture.
 sim.ai_enabled = true; sim.step(sim.FIXED_TICK)
 var damage: Array = events(sim, "damage").filter(func(event): return event.target == enemy.actor_id)
 check(not damage.is_empty() and damage[0].source == "q2", "early river crossing kills before later BASIC in one actual tick")
 check(events(sim, "ink_q2_crossing").size() == 1, "early crossing receipt survives later projectile plan")
 sim.free()
 sim = fresh(); make_river(sim, Vector3(0, 0, -3), Vector3(0, 0, 3))
 var pouncer: Dictionary = target(sim, Vector3(1.02, 0, 0), "pouncer")
 pouncer.hp = 1.0; pouncer.state = "pounce"; pouncer.aim = Vector3.LEFT; pouncer.timer = .4; pouncer.did_hit = false
 var hero_hp: float = sim.hero.hp
 sim.ai_enabled = true; sim.step(sim.FIXED_TICK)
 check(pouncer.dead, "pouncer crosses into lethal river")
 near(sim.hero.hp, hero_hp, "earlier river death suppresses later pounce hero damage")
 check(events(sim, "enemy_impact").filter(func(event): return event.actor_id == pouncer.actor_id and event.hit).is_empty(), "no false later pounce impact after earlier death")
 sim.free()
 var reference = fresh(); make_river(reference)
 reference.request_action("attack", Vector3(10, 0, 0)); reference.step(.08)
 var expected_front: float = reference.ink_basics[0].front_distance
 var expected_steps: int = reference.ink_core_steps
 sim = fresh(); make_river(sim); sim.request_action("attack", Vector3(10, 0, 0))
 sim.step(.04)
 var pause_enhance = func(event: Dictionary):
  if event.kind == "ink_q2_projectile_enhanced": sim.paused = true
 sim.combat_event.connect(pause_enhance); sim.step(.02)
 check(sim.paused, "enhancement callback actually pauses within local interval")
 sim.combat_event.disconnect(pause_enhance); sim.paused = false; sim.step(.02)
 near(sim.hero_time, reference.hero_time, "paused remainder compare uses equal source time")
 near(sim.ink_basics[0].front_distance, expected_front, "resume never loses remaining projectile movement")
 check(sim.ink_core_steps == expected_steps, "resumed remainder adds no shared AI/RNG step")
 reference.free(); sim.free(); completed.append("pause_and_order")
func test_retained() -> void:
 var after = Sim.new(); var before = Before.new()
 root.add_child(after); root.add_child(before)
 for sim in [after, before]:
  sim.auto_finish = false; sim.ai_enabled = false
  sim.hero.loadout.q = "q3"; sim.hero.ranks.q = 1; sim.begin_encounter("retained-q3", [])
  target(sim, Vector3(4, 0, 0))
  check(sim.request_action("q", Vector3(4, 0, 0)).accepted, "retained Q3 raise")
  sim.step(.1)
 near(after.enemies[0].hp, before.enemies[0].hp, "retained Q3 identical damage")
 near(after.hero.cooldowns.q, before.hero.cooldowns.q, "retained Q3 identical cooldown")
 check(after.ink_core_steps == before.ink_core_steps, "retained shared tick count unchanged")
 after.free(); before.free(); completed.append("retained")
