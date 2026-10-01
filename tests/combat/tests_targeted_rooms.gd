extends RefCounted
const Sim = preload("res://scripts/combat/combat_sim.gd")
var checks := 0
var failures := []
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok: failures.append(label)
func fresh(preset := {"q":"q2","e":"e1","r":"r2","passive":"p3"}):
 var s = Sim.new()
 s.configure_test_loadout(preset)
 s.ai_enabled = false
 s.hero.position = Vector3.ZERO
 s.hero.stats.regen = 0
 return s
func run() -> Dictionary:
 checks = 0
 failures.clear()
 for ultimate in ["r1","r2"]:
  for passive in ["p1","p2","p3"]:
   var s = fresh({"q":"q2","e":"e1","r":ultimate,"passive":passive})
   var target: Dictionary = s.spawn_enemy("minion",Vector3(0,0,-1))
   check(s.request_action("attack",target.position).accepted,"ordinary attack accepted "+ultimate+passive)
   s.step(.11)
   check(target.hp == 32,"default 64 HP reduced to 32 by real attack")
   check(s.request_action("e",target.position).accepted and s.request_action("q",target.position).accepted,"E1 then Q2 accepted")
   s.step(.2)
   check(s.phase == "victory","E1 naturally closes room")
   check(not s.hero.cast_state.has("q2") and not s.hero.untargetable and s.hero.cooldowns.q > 0,"closed Q2 cancelled and CD committed")
   check(s.begin_encounter("next-room",[{"kind":"minion","position":Vector3(0,0,-2),"hp":1000}]).accepted,"next room admitted")
   s.step(.5)
   check(s.enemies[0].hp == 1000,"QA009 zero new input causes zero new-room damage "+ultimate+passive)
   s.free()
 for result in ["victory","downed","true_dead"]:
  var s = fresh()
  s.auto_finish = false
  s.spawn_enemy("minion",Vector3(0,0,-1),1000)
  s.request_action("q",Vector3.FORWARD)
  s.end_encounter(result) # Lifecycle fixture, not damage through Q2 immunity.
  var closed: Dictionary = s.snapshot()
  s.extensions._step_q2()
  s.step(60)
  check(s.snapshot() == closed,"closed direct Q2 step and long wait inert: "+result)
  check(not s.hero.cast_state.has("q2"),"terminal chain removed: "+result)
  if result == "downed":
   s.hero.dead = true
   s.hero.death_state = "downed"
   check(s.self_rescue(),"same-room rescue fixture resumes")
   s.step(.3)
   check(s.enemies[0].hp == 1000,"rescue cannot resurrect cancelled Q2")
  s.free()
 for key in ["encounter_id","encounter_generation","simulation_instance"]:
  var s = fresh()
  s.auto_finish = false
  s.spawn_enemy("minion",Vector3(0,0,-1),1000)
  s.request_action("q",Vector3.FORWARD)
  s.hero.cast_state.q2[key] = "wrong-room" if key == "encounter_id" else -1
  s.step(.3)
  check(s.enemies[0].hp == 1000 and not s.hero.cast_state.has("q2"),"Q2 rejects mismatched "+key)
  s.free()
 # End during the Q2 hit event: no post-close target selection/state writes.
 var s = fresh()
 s.auto_finish = false
 s.spawn_enemy("minion",Vector3(0,0,-1),1000)
 s.spawn_enemy("minion",Vector3(0,0,-2),1000)
 s.combat_event.connect(func(e):
  if e.kind == "q2_hit": s.end_encounter("victory"))
 s.request_action("q",Vector3.FORWARD)
 s.step(.25)
 check(s.phase == "victory" and not s.hero.cast_state.has("q2"),"reentrant terminal hit leaves no next chain")
 s.begin_encounter("after-reentry",[{"kind":"minion","position":Vector3.FORWARD,"hp":1000}])
 s.step(.5)
 check(s.enemies[0].hp == 1000,"reentrant Q2 closure cannot hit next room")
 s.free()
 # E1 is bound to its target and room; same-room freeze survives, replacement does not.
 s = fresh()
 s.auto_finish = false
 s.spawn_enemy("minion",Vector3(0,0,-10),1000)
 s.request_action("e",Vector3(0,0,-10))
 var old: Dictionary = s.hero.cast_state.e1.duplicate(true)
 s.end_encounter("victory")
 check(s.hero.cast_state.has("e1"),"E1 same-room freeze retained until room replacement")
 s.begin_encounter("other",[{"kind":"minion","position":Vector3.FORWARD,"hp":1000}])
 check(not s.hero.cast_state.has("e1") and s.hero.cooldowns.e > 0,"replacement cancels old E1 target and commits CD")
 old.target = s.enemies[0].actor_id # Simulate recycled target ID in a stale serialized context.
 s.hero.cast_state.e1 = old
 s.extensions._step_e1(.2)
 check(s.enemies[0].hp == 1000 and not s.hero.cast_state.has("e1"),"E1 stale context cannot damage recycled target")
 s.free()
 # E2 blink and E3 buff are deliberately retained, with no queued new-room strike.
 for ability in ["e2","e3"]:
  s = fresh({"e":ability})
  s.auto_finish = false
  s.spawn_enemy("minion",Vector3.FORWARD,1000)
  s.request_action("e",Vector3.FORWARD)
  s.end_encounter("victory")
  check(s.hero.cast_state.has("e2") if ability == "e2" else s.hero.overload_left > 0,"existing retained policy: "+ability)
  s.begin_encounter("continued",[{"kind":"minion","position":Vector3.FORWARD,"hp":1000}])
  s.step(.5)
  check(s.enemies[0].hp == 1000,"retained "+ability+" produces no automatic new-room damage")
  s.free()
 s = fresh({"r":"r2"})
 s.auto_finish = false
 s.spawn_enemy("minion",Vector3.FORWARD,1000)
 s.request_action("r",Vector3.FORWARD)
 var old_receipt := {"cast_id":500,"encounter_id":s.combat_level_id,"encounter_generation":s.encounter_generation,"simulation_instance":s.get_instance_id()}
 s.end_encounter("victory")
 check(s.hero.cast_state.r2.round == 1,"R2 unused throws retained")
 s.begin_encounter("r2-next",[{"kind":"minion","position":Vector3.FORWARD,"hp":1000}])
 s.step(.3)
 check(s.enemies[0].hp == 1000,"R2 retained state needs new input for damage")
 s.extensions.on_basic_attack_completed(old_receipt)
 check(s.hero.cast_state.r2.attacks == 0,"old-room attack callback cannot grow retained R2 count")
 var current_receipt: Dictionary = old_receipt.duplicate()
 current_receipt.encounter_id = s.combat_level_id
 current_receipt.encounter_generation = s.encounter_generation
 s.extensions.on_basic_attack_completed(current_receipt)
 check(s.hero.cast_state.r2.attacks == 1,"current-room attack callback still counts")
 s.extensions.on_basic_attack_completed(current_receipt)
 check(s.hero.cast_state.r2.attacks == 1,"current-room callback replay remains idempotent")
 check(s.request_action("r",Vector3.FORWARD).accepted and s.enemies[0].hp < 1000,"legitimate next-room R2 recast still works")
 s.free()
 return {"suite":"qa009_targeted_room_actions","checks":checks,"failures":failures,"passed":failures.is_empty(),"scope":"simulation fixtures, not OS reproduction"}
