extends SceneTree
# Independent gate authored by read-only reviewer. NOT executed by reviewer.
# Run only in main-owned serial Godot budget; results apply to the printed hashes.
const Sim = preload("res://tests/ink_q2_foundation_20261005/fix01/ink_q2_sim.gd")
var checks: int = 0
var failures: Array = []
var cases: Array = []
var evidence: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok: failures.append(label); push_error(label)
func near(a: float, b: float, label: String, eps: float = .0001) -> void:
 check(is_finite(a) and absf(a - b) <= eps, "%s: got %.9f expected %.9f" % [label, a, b])
func fresh(rank: int = 1, ids: Array = []):
 var sim = Sim.new(); root.add_child(sim)
 sim.auto_finish = false; sim.ai_enabled = false
 sim.hero.position = Vector3.ZERO; sim.hero.loadout.q = "q2"; sim.hero.ranks.q = rank
 sim.hero.stats.ap = 100.0; sim.hero.stats.crit_chance = 0.0; sim.hero.stats.cdr = 0.0
 sim.begin_encounter("q2-independent", []); sim.set_hexes(ids)
 return sim
func target(sim, position: Vector3, hp: float = 10000.0) -> Dictionary:
 var enemy: Dictionary = sim.spawn_enemy("minion", position, hp)
 enemy.radius = .25; enemy.defence = 0.0; enemy.state = "chase"; enemy.timer = 10.0
 return enemy
func river(sim, a: Vector3 = Vector3(2, 0, -3), b: Vector3 = Vector3(2, 0, 3)) -> void:
 check(sim.request_q2("first", a).accepted, "river A accepted")
 check(sim.request_q2("second", b).accepted, "river B accepted")
func matching(sim, kind: String, id: String = "") -> Array:
 return sim.event_log.filter(func(event): return event.kind == kind and (id.is_empty() or str(event.get("target_id", event.get("target", ""))) == id))
func run() -> void:
 cooldown_boundaries()
 q2_api_rejects_other_loadouts()
 real_ai_swept_entry()
 paused_birth_resume()
 paused_h04_resume()
 crossing_before_later_basic()
 river_before_later_pounce()
 pounce_before_later_river()
 h03_projectile_identity()
 paused_projectile_keeps_time_budget()
 resumed_callback_room_isolation()
 h04_source_schedule()
 var required: Array = ["cooldown_boundaries", "q2_api_rejects_other_loadouts", "real_ai_swept_entry", "paused_birth_resume", "paused_h04_resume", "crossing_before_later_basic", "river_before_later_pounce", "pounce_before_later_river", "h03_projectile_identity", "paused_projectile_keeps_time_budget", "resumed_callback_room_isolation", "h04_source_schedule"]
 for name in required: check(name in cases, "case completed: " + name)
 var result: Dictionary = {"suite":"q2-independent-20261005", "engine_run":true, "passed":failures.is_empty(), "checks":checks, "failures":failures, "cases":cases, "evidence":evidence, "sim_sha256":FileAccess.get_sha256("res://tests/ink_q2_foundation_20261005/fix01/ink_q2_sim.gd"), "gate_sha256":FileAccess.get_sha256("res://tests/ink_q2_independent_20261005/independent_gate.gd"), "normal_input":false, "ordinary_entry":false, "visual_acceptance":false}
 var file = FileAccess.open("res://tests/ink_q2_independent_20261005/independent_result.json", FileAccess.WRITE)
 if file != null: file.store_string(JSON.stringify(result, "  ")); file.close()
 print("INK_Q2_INDEPENDENT_REPORT ", JSON.stringify(result))
 quit(0 if failures.is_empty() else 1)
func cooldown_boundaries() -> void:
 var sim = fresh()
 check(sim.request_q2("first", Vector3.ZERO).accepted, "pending first")
 sim.step(4.0)
 near(sim.hero.cooldowns.q, 0.0, "first marker starts no cooldown")
 check(not sim.request_q2("second", Vector3(13, 0, 0)).accepted, "invalid B rejected")
 check(not sim.ink_q2_pending.is_empty(), "invalid B preserves marker")
 near(sim.hero.cooldowns.q, 0.0, "invalid B starts no cooldown")
 sim.step(1.0)
 check(sim.ink_q2_pending.is_empty(), "marker removed at expiry")
 near(sim.hero.cooldowns.q, 10.5, "expiry starts full cooldown")
 sim.step(.5); near(sim.hero.cooldowns.q, 10.0, "only post-expiry time decrements cooldown")
 sim.free()
 sim = fresh(6); check(sim.request_q2("first", Vector3.ZERO).accepted, "rank6 first")
 sim.step(4.0); check(sim.request_q2("second", Vector3(16, 0, 0)).accepted, "rank6 legal late B")
 near(sim.hero.cooldowns.q, 8.0, "legal B starts full rank6 cooldown")
 sim.free(); cases.append("cooldown_boundaries")
func real_ai_swept_entry() -> void:
 var sim = fresh(); river(sim)
 var enemy: Dictionary = target(sim, Vector3(3.02, 0, 0))
 var hp: float = enemy.hp
 sim.ai_enabled = true
 sim.step(sim.FIXED_TICK)
 check(enemy.position.x < 3.0, "real AI crosses river right boundary")
 near(hp - enemy.hp, 150.0, "real AI first entry deals source damage")
 sim.step(.1)
 near(hp - enemy.hp, 150.0, "same river does not repeat while inside")
 sim.free(); cases.append("real_ai_swept_entry")
func paused_birth_resume() -> void:
 var sim = fresh()
 var a: Dictionary = target(sim, Vector3(2, 0, 0))
 var b: Dictionary = target(sim, Vector3(2, 0, 1))
 var hp: float = b.hp
 var callback = func(event: Dictionary):
  if event.kind == "damage" and event.source == "q2" and event.target == a.actor_id: sim.paused = true
 sim.combat_event.connect(callback)
 river(sim)
 evidence.append({"case":"paused_birth_before_resume", "b_damage":hp - b.hp, "b_claimed":sim.ink_rivers[0].hits.has(b.actor_id), "paused":sim.paused})
 sim.combat_event.disconnect(callback); sim.paused = false
 sim.step(sim.FIXED_TICK)
 near(hp - b.hp, 150.0, "pause callback never permanently consumes undelivered birth damage")
 sim.free(); cases.append("paused_birth_resume")
func paused_h04_resume() -> void:
 var sim = fresh(1, ["yanguizhou_h04"])
 var a: Dictionary = target(sim, Vector3(2, 0, 3))
 var b: Dictionary = target(sim, Vector3(2, 0, 3.2))
 river(sim)
 var callback = func(event: Dictionary):
  if event.kind == "damage" and event.source == "hex_yanguizhou_h04" and event.target == a.actor_id: sim.paused = true
 sim.combat_event.connect(callback)
 sim.step(.5)
 sim.combat_event.disconnect(callback); sim.paused = false
 sim.step(sim.FIXED_TICK)
 var a_ticks: Array = matching(sim, "ink_h04_contact", a.actor_id)
 var b_ticks: Array = matching(sim, "ink_h04_contact", b.actor_id)
 check(a_ticks.size() == 1 and b_ticks.size() == 1, "H04 first tick reaches both actors exactly once across pause callback")
 evidence.append({"case":"paused_h04_after_resume", "a_tick_count":a_ticks.size(), "b_tick_count":b_ticks.size(), "next_tick":sim.ink_rivers[0].next_sunset_tick})
 sim.free(); cases.append("paused_h04_resume")
func crossing_before_later_basic() -> void:
 var sim = fresh(); river(sim)
 var enemy: Dictionary = target(sim, Vector3(3.02, 0, 0), 1.0)
 check(sim.request_action("attack", Vector3(10, 0, 0)).accepted, "real basic projectile instantiated")
 var shot: Dictionary = sim.ink_basics[0]
 # Explicit deterministic fixture positions an actual basic partway along its
 # path. The test then uses exactly one real fixed step, actual AI, and actual
 # collisions; it does not inject a motion trace or call _q2_settle by hand.
 sim._set_front(shot, 2.5)
 sim.ai_enabled = true
 sim.step(sim.FIXED_TICK)
 var damage: Array = matching(sim, "damage", enemy.actor_id)
 evidence.append({"case":"crossing_before_later_basic", "enemy_final_x":enemy.position.x, "damage":damage, "q2_receipts":matching(sim, "ink_q2_crossing", enemy.actor_id)})
 check(not damage.is_empty() and damage[0].source == "q2", "earlier river entry wins before later lethal basic in same real step")
 check(matching(sim, "ink_q2_crossing", enemy.actor_id).size() == 1, "earlier river contact is not erased by later basic death")
 sim.free(); cases.append("crossing_before_later_basic")
func h03_projectile_identity() -> void:
 var sim = fresh(1, ["yanguizhou_h03"])
 check(sim.request_q2("first", Vector3(2, 0, -2)).accepted, "H03 first")
 check(sim.request_q2("corner", Vector3(2, 0, 2)).accepted, "H03 corner1")
 check(sim.request_q2("corner", Vector3(4, 0, 2)).accepted, "H03 corner2")
 check(sim.request_q2("second", Vector3(4, 0, -2)).accepted, "H03 endpoint")
 sim.hero.cooldowns.q = 0.0 # Explicit second-river coexistence fixture.
 river(sim, Vector3(6, 0, -2), Vector3(6, 0, 2))
 check(sim.request_action("attack", Vector3(20, 0, 0)).accepted, "cross-leg real projectile")
 var shot: Dictionary = sim.ink_basics[0]
 var id: String = shot.wave_id
 var original_range: float = shot.path_length
 var original_speed: float = shot.speed
 sim.step(.3)
 near(shot.speed, original_speed * 1.1, "H03 legs plus another river multiply speed once total")
 near(shot.path_length, original_range * 1.1, "H03 legs plus another river add range once total")
 check(shot.wave_id == id and matching(sim, "ink_q2_projectile_enhanced").size() == 1, "bends preserve projectile identity and global one receipt")
 sim.free(); cases.append("h03_projectile_identity")
func h04_source_schedule() -> void:
 var sim = fresh(6, ["yanguizhou_h04"])
 var enemy: Dictionary = target(sim, Vector3(2, 0, 3))
 river(sim)
 var hp: float = enemy.hp
 check(matching(sim, "ink_h04_contact").is_empty(), "H04 has no birth tick")
 sim.step(4.0)
 var hits: Array = matching(sim, "ink_h04_contact", enemy.actor_id)
 check(hits.size() == 8, "H04 exactly eight ticks independently of Q2 rank")
 for i in range(hits.size()): near(hits[i].source_time, (i + 1) * .5, "H04 exact source schedule")
 near(hp - enemy.hp, 304.0, "H04 8 x 38 source damage")
 check(sim.ink_rivers.size() == 1, "rank6 river outlives H04")
 sim.step(2.0)
 near(hp - enemy.hp, 304.0, "no H04 ninth tick while rank6 river remains")
 check(sim.ink_rivers.is_empty(), "rank6 root retires after six seconds")
 sim.free(); cases.append("h04_source_schedule")

func river_before_later_pounce() -> void:
 var sim = fresh(); river(sim, Vector3(0, 0, -3), Vector3(0, 0, 3))
 var enemy: Dictionary = sim.spawn_enemy("pouncer", Vector3(1.02, 0, 0), 1.0)
 enemy.radius = .25; enemy.defence = 0.0; enemy.state = "pounce"
 enemy.aim = Vector3.LEFT; enemy.timer = 1.0; enemy.did_hit = false
 var hp: float = sim.hero.hp
 sim.ai_enabled = true
 sim.step(sim.FIXED_TICK)
 evidence.append({"case":"river_before_later_pounce", "hero_damage":hp - sim.hero.hp, "enemy_dead":enemy.dead, "q2_receipts":matching(sim, "ink_q2_crossing", enemy.actor_id)})
 check(enemy.dead, "lethal first river touch stops pouncer")
 near(sim.hero.hp, hp, "earlier lethal river touch prevents later pounce hero hit")
 sim.free(); cases.append("river_before_later_pounce")

func q2_api_rejects_other_loadouts() -> void:
 for selected in ["q1", "q3"]:
  var sim = fresh()
  sim.hero.loadout.q = selected
  var serial: int = sim.cast_serial
  var result: Dictionary = sim.request_q2("first", Vector3(4, 0, 0))
  evidence.append({"case":"q2_api_rejects_other_loadouts", "selected":selected, "result":result})
  check(not result.accepted, "Q2-specific first command rejects selected " + selected)
  check(sim.cast_serial == serial and sim.ink_mountain.is_empty() and sim.ink_input.phase == "idle", "Q2 wrong-loadout rejection has no other-skill side effect: " + selected)
  near(sim.hero.cooldowns.q, 0.0, "Q2 wrong-loadout does not start another skill cooldown")
  sim.free()
 cases.append("q2_api_rejects_other_loadouts")

func paused_projectile_keeps_time_budget() -> void:
 var paused_sim = fresh()
 var control = fresh()
 for sim in [paused_sim, control]:
  river(sim)
  check(sim.request_action("attack", Vector3(10, 0, 0)).accepted, "pause-budget actual BASIC instantiated")
 var paused_shot: Dictionary = paused_sim.ink_basics[0]
 var control_shot: Dictionary = control.ink_basics[0]
 var callback = func(event: Dictionary):
  if event.kind == "ink_q2_projectile_enhanced": paused_sim.paused = true
 paused_sim.combat_event.connect(callback)
 paused_sim.step(.04)
 paused_sim.step(paused_sim.FIXED_TICK)
 check(paused_sim.paused, "enhancement callback actually paused inside a step")
 paused_sim.combat_event.disconnect(callback)
 paused_sim.paused = false
 paused_sim.step(paused_sim.FIXED_TICK)
 control.step(.08)
 near(paused_sim.hero_time, control.hero_time, "pause-budget compare equal simulated times")
 evidence.append({"case":"paused_projectile_keeps_time_budget", "hero_time":paused_sim.hero_time, "paused_distance":paused_shot.front_distance, "control_distance":control_shot.front_distance})
 near(paused_shot.front_distance, control_shot.front_distance, "pause callback preserves in-progress projectile interval remainder")
 paused_sim.free(); control.free(); cases.append("paused_projectile_keeps_time_budget")

func pounce_before_later_river() -> void:
 var sim = fresh(); river(sim, Vector3(-.2, 0, -3), Vector3(-.2, 0, 3))
 var enemy: Dictionary = sim.spawn_enemy("pouncer", Vector3(1.02, 0, 0), 1.0)
 enemy.radius = .25; enemy.defence = 0.0; enemy.state = "pounce"
 enemy.aim = Vector3.LEFT; enemy.timer = 1.0; enemy.did_hit = false
 var hp: float = sim.hero.hp
 sim.ai_enabled = true
 sim.step(sim.FIXED_TICK)
 evidence.append({"case":"pounce_before_later_river", "hero_damage":hp - sim.hero.hp, "enemy_dead":enemy.dead})
 check(enemy.dead, "later river eventually kills pouncer")
 check(sim.hero.hp < hp, "earlier legitimate pounce damage is preserved before later river death")
 sim.free(); cases.append("pounce_before_later_river")

func resumed_callback_room_isolation() -> void:
 var sim = fresh(); river(sim)
 target(sim, Vector3(1.35, 0, 0))
 check(sim.request_action("attack", Vector3(10, 0, 0)).accepted, "resume scope actual projectile")
 var pause_callback = func(event: Dictionary):
  if event.kind == "ink_q2_projectile_enhanced": sim.paused = true
 sim.combat_event.connect(pause_callback)
 sim.step(.06)
 check(sim.paused, "resume scope paused at enhancement")
 sim.combat_event.disconnect(pause_callback)
 var observed: Dictionary = {"fired":false, "time":-1.0, "steps":-1}
 var switch_callback = func(event: Dictionary):
  if event.kind == "damage" and event.source == "attack" and not observed.fired:
   observed.fired = true
   sim.end_encounter("callback_replace")
   sim.begin_encounter("replacement-room", [])
   observed.time = sim.hero_time; observed.steps = sim.ink_core_steps
 sim.combat_event.connect(switch_callback)
 sim.paused = false
 sim.step(sim.FIXED_TICK)
 check(observed.fired and sim.room_id == "replacement-room", "resume damage callback really replaced room")
 near(sim.hero_time, observed.time, "old resume cannot advance replacement-room clock")
 check(sim.ink_core_steps == observed.steps, "old resume cannot execute an unrequested replacement-room step")
 sim.free(); cases.append("resumed_callback_room_isolation")
