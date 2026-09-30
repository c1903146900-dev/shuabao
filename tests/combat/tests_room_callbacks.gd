extends RefCounted
const Sim = preload("res://scripts/combat/combat_sim.gd")
var checks := 0
var failures := []
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok: failures.append(label)
func fresh():
 var s = Sim.new()
 s.ai_enabled = false
 s.auto_finish = false
 s.hero.position = Vector3.ZERO
 s.hero.stats.regen = 0.0
 s.configure_test_loadout({"q":"q1","e":"e1","r":"r1"})
 return s
func r_event(s) -> Dictionary:
 for event in s.pending:
  if event.kind == "r1_damage": return event.duplicate(true)
 return {}
func run() -> Dictionary:
 checks = 0
 failures.clear()
 for slices in [1,20]:
  var s = fresh()
  s.auto_finish = true
  var foe: Dictionary = s.spawn_enemy("minion",Vector3(0,0,-1),1)
  s.request_action("e",foe.position)
  s.request_action("r",foe.position)
  var old := r_event(s)
  for i in range(slices): s.step(0.2/slices)
  check(s.phase == "victory","natural E1 victory before R1 impact slices=%d" % slices)
  check(r_event(s).is_empty(),"ended R1 queue cancelled slices=%d" % slices)
  check(s.hero.cooldowns.r > 0 and s.clock.scale_factor() == 1,"R1 ends cooldown and slow normally")
  check(s.begin_encounter("next-room",[{"kind":"minion","position":Vector3(0,0,-2),"hp":1000}]).accepted,"next room accepted")
  s.step(0.05)
  check(s.enemies[0].hp == 1000,"QA002 next room receives no old R1 damage slices=%d" % slices)
  var before: Dictionary = s.snapshot()
  s._resolve_pending(old)
  check(s.snapshot() == before,"detached old-room callback ignored")
  check(s.event_log.filter(func(e):return e.kind == "ultimate_impact" and e.combat_level_id == "next-room").is_empty(),"no phantom next-room impact event")
  s.free()
 for result in ["victory","downed","true_dead"]:
  var s = fresh()
  s.spawn_enemy("boss",Vector3(0,0,-1),1000)
  s.request_action("r",Vector3.FORWARD)
  var old := r_event(s)
  s.end_encounter(result) # Explicit lifecycle cancellation; R1 itself is immune to enemy damage.
  check(r_event(s).is_empty(),"lifecycle cancels R1 queue: "+result)
  var frozen: Dictionary = s.snapshot()
  s.step(60)
  s._resolve_pending(old)
  check(s.snapshot() == frozen,"closed callback and 60s wait preserve frozen snapshot: "+result)
  if result == "downed":
   s.hero.dead = true
   s.hero.death_state = "downed"
   check(s.self_rescue(),"lifecycle fixture resumes same room through self-rescue")
   s._resolve_pending(old)
   s.step(0.1)
   check(s.enemies[0].hp == 1000,"cancelled R1 cannot resurrect after same-room rescue")
  s.free()
 var old_sim = fresh()
 old_sim.spawn_enemy("boss",Vector3.FORWARD,1000)
 old_sim.request_action("r",Vector3.FORWARD)
 var stale := r_event(old_sim)
 var restarted = fresh()
 restarted.spawn_enemy("boss",Vector3.FORWARD,1000)
 restarted.request_action("r",Vector3.FORWARD)
 var current := r_event(restarted)
 var untouched: Dictionary = restarted.snapshot()
 restarted._resolve_pending(stale)
 check(restarted.snapshot() == untouched,"restart rejects old instance even with same room/cast IDs")
 var wrong_room := current.duplicate(true)
 wrong_room.encounter_id = "different-room"
 restarted._resolve_pending(wrong_room)
 check(restarted.snapshot() == untouched,"wrong room identity rejected")
 var wrong_generation := current.duplicate(true)
 wrong_generation.encounter_generation = -99
 restarted._resolve_pending(wrong_generation)
 check(restarted.snapshot() == untouched,"wrong lifecycle generation rejected")
 restarted.step(1.1)
 check(is_equal_approx(restarted.enemies[0].hp,952),"valid new R1 still hits exactly once")
 var hp: float = restarted.enemies[0].hp
 restarted._resolve_pending(current)
 check(restarted.enemies[0].hp == hp,"resolved callback cannot replay")
 restarted.hero.self_rescue_used = true
 restarted.damage_hero(99999)
 check(restarted.phase == "true_dead" and restarted.hero.dead,"actual lethal after presentation reaches true death")
 var frozen: Dictionary = restarted.snapshot()
 restarted._resolve_pending(current)
 restarted.step(60)
 check(restarted.snapshot() == frozen,"true death blocks old callback and preserves terminal state")
 restarted.free()
 old_sim.free()
 var s = fresh()
 s.spawn_enemy("minion",Vector3.FORWARD,1000)
 s.request_action("attack",Vector3.FORWARD)
 s.end_encounter("victory")
 s.begin_encounter("no-old-attack",[{"kind":"minion","position":Vector3.FORWARD,"hp":1000}])
 s.step(0.2)
 check(s.enemies[0].hp == 1000 and s.pending.is_empty(),"room replacement clears other room-targeted delayed attacks")
 s.free()
 s = fresh()
 s.hero.loadout.e = "e3"
 s.request_action("e")
 s.step(2)
 var remaining: float = s.hero.overload_left
 s.end_encounter("victory")
 s.step(60)
 check(is_equal_approx(s.hero.overload_left,remaining),"E3 retained buff freezes unchanged")
 s.begin_encounter("retained-buff",[{"kind":"minion","position":Vector3(10,0,10),"hp":1000}])
 s.step(5)
 check(s.hero.overload_left == 0 and is_equal_approx(s.hero.cooldowns.e,32),"E3 retained buff resumes and starts normal CD")
 s.free()
 s = fresh()
 s.auto_finish = true
 s.spawn_enemy("minion",Vector3.FORWARD,1)
 s.request_action("q",Vector3.FORWARD)
 check(s.phase == "victory" and s.hero.q1_stacks == 1 and s.hero.cooldowns.q == 0,"Q1 lethal grace settles before room closes")
 s.free()
 s = fresh()
 s.auto_finish = true
 var responses := []
 s.encounter_finished.connect(func(_state):responses.append(s.begin_encounter("reentrant",[{"kind":"minion","position":Vector3.FORWARD,"hp":1000}])))
 s.spawn_enemy("minion",Vector3.FORWARD,1)
 s.request_action("q",Vector3.FORWARD)
 check(responses.size() == 1 and not responses[0].accepted,"reentrant next room cannot enter lethal transaction")
 check(s.phase == "victory" and s.begin_encounter("after-transaction",[{"kind":"minion","position":Vector3.FORWARD,"hp":1000}]).accepted,"next room works after lethal transaction commits")
 s.free()
 return {"suite":"qa002_room_callbacks","checks":checks,"failures":failures.duplicate(),"passed":failures.is_empty()}
