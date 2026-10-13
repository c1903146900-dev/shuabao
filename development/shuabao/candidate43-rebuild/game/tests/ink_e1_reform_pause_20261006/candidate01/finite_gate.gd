extends SceneTree
## One affected mechanism group. Real E down/up and real swept rain marking;
## pauses/retirement are explicit synchronous-callback fixtures, not native UI.
const Sim = preload("res://tests/ink_e1_reform_pause_20261006/candidate01/sim.gd")
const Before = preload("res://tests/ink_p2_ordinary_20261006/mechanism01/sim.gd")
const Rest = preload("res://tests/ink_rest_service_20261006/candidate01/rest_service.gd")
const REQUIRED_GROUPS: Array = ["original_e1_reform_remainder"]
const BINDING := "res://tests/ink_e1_reform_pause_20261006/candidate01/source_binding.json"
var checks: int = 0
var failures: Array[String] = []
var groups: Array[String] = []
var observations: Dictionary = {}
var serial: int = 0
var output_path: String = ""

func _initialize() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--e1-reform-result="): output_path = arg.trim_prefix("--e1-reform-result=")
 run.call_deferred()

func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok: failures.append(label); push_error(label)

func near(actual: float, expected: float, label: String) -> void:
 check(is_finite(actual) and absf(actual-expected)<0.0001,label+" actual="+str(actual)+" expected="+str(expected))

func fresh(passive: String = "p1", before: bool = false):
 serial += 1
 var sim = Before.new() if before else Sim.new()
 root.add_child(sim)
 sim.auto_finish = false; sim.ai_enabled = false
 sim.arena_half_extent = 30.0; sim.obstacles = []
 sim.hero.loadout.e = "e1"; sim.hero.ranks.e = 1
 sim.hero.loadout.q = "q1"; sim.hero.ranks.q = 1
 sim.hero.loadout.passive = passive; sim.hero.ranks.passive = 1
 sim.set_projected_stats({"AP":100.0,"move_speed":10.0,"crit_chance":0.0,"regen":0.0,"lifesteal":0.0,"cdr":0.0})
 check(sim.begin_encounter("e1-reform-fixture-%d"%serial,[]).accepted,"explicit encounter starts")
 sim.hero.position = Vector3.ZERO
 return sim

func fill_p2(sim) -> void:
 for index: int in range(4):
  sim.hero.cooldowns.q = 0.0
  var result: Dictionary
  if index%2 == 0:
   sim.hero.loadout.q = "q1"
   check(sim.request_ink_input("q_down").accepted,"P2 fixture real Q1 arms")
   check(sim.request_ink_input("left_down",Vector3.ZERO).accepted,"P2 fixture real Q1 down")
   check(sim.request_ink_input("motion",Vector3(0.26,0,0)).accepted,"P2 fixture real Q1 motion")
   result = sim.request_ink_input("left_up",Vector3(0.26,0,0))
  else:
   sim.hero.loadout.q = "q2"
   check(sim.request_q2("first",Vector3(0,0,-3)).accepted,"P2 fixture real Q2 A")
   result = sim.request_q2("second",Vector3(0,0,3))
  check(result.accepted,"P2 fixture real alternating successful use")
  sim.cancel_cast(int(result.cast_id))
 check(sim.p2.stacks == 3 and sim.p2.ready_epoch > 0,"real four-use ready setup")

func setup_rain(sim, marked: bool = true, hp: float = 10000.0) -> Dictionary:
 var enemies: Array = []
 for at: Vector3 in [Vector3(0.3,0,0),Vector3(0.3,0,1.5)]:
  var enemy: Dictionary = sim.spawn_enemy("minion",at,hp)
  enemy.state = "chase"; enemy.defence = 0.0; enemy.radius = 0.25; enemy.position = at
  enemies.append(enemy)
 var entry: Dictionary = sim.request_action("ink_e_down")
 check(entry.accepted,"public E-down enters rain")
 var state: Dictionary = sim.ink_rain
 if marked:
  sim.move_during_hitstop(0.02,Vector3.RIGHT)
  check(state.marks.has(enemies[0].actor_id) and not state.marks.has(enemies[1].actor_id),"real swept motion marks only original first target")
 near(float(enemies[0].hp),hp,"marking itself has no damage")
 return {"enemies":enemies,"state":state,"id":int(entry.cast_id),"cd":float(sim.hero.cooldowns.e)}

func packets(sim, source: String) -> Array:
 return sim.event_log.filter(func(event): return event.kind == "damage" and str(event.get("source","")) == source)

func summarize(sim, setup: Dictionary) -> Dictionary:
 return {"hp":setup.enemies.map(func(enemy): return enemy.hp),"e_cd":sim.hero.cooldowns.e,"hero_time":sim.hero_time,"core_steps":sim.ink_core_steps,"original_amounts":packets(sim,"e1").map(func(event): return event.amount),"original_targets":packets(sim,"e1").map(func(event): return event.target),"contact_amounts":sim.ink_e1_receipts.map(func(receipt): return receipt.actual_damage),"contact_segments":sim.ink_e1_receipts.map(func(receipt): return receipt.segment_id),"finished":sim.ink_e1_finished.size(),"p1":sim.ink_p1_receipts.duplicate(true),"p2_claims":sim.ink_p2_claims.size(),"p2_splashes":sim.ink_p2_splashes.size()}

func compare_unpaused() -> void:
 var outcomes: Array = []
 for before: bool in [true,false]:
  var sim = fresh("p1",before)
  var setup: Dictionary = setup_rain(sim)
  check(sim.request_action("ink_e_up").accepted,"unpaused public E-up accepted")
  var outcome: Dictionary = summarize(sim,setup)
  check(outcome.original_amounts == [95.0,95.0,50.0],"unpaused original two-channel amounts preserved")
  check(outcome.original_targets == ["enemy_1","enemy_2","enemy_1"],"unpaused original target and channel order preserved")
  check(outcome.contact_amounts == outcome.original_amounts,"unpaused HP-delta receipts are original packets only")
  check(outcome.finished == 1 and outcome.p1.size() == 1 and not outcome.p1[0].qualified,"unpaused two-target P1 terminal without supplement")
  near(sim.hero.cooldowns.e,float(setup.cd),"unpaused release does not restart or refund cooldown")
  near(sim.hero_time,0.0,"unpaused release adds no world time")
  check(sim.ink_core_steps == 0,"unpaused release adds no core step")
  outcome.erase("p1")
  outcomes.append(outcome)
  sim.free()
 check(outcomes[0] == outcomes[1],"no-pause candidate equals frozen parent on observed originals/CD/order")
 observations.unpaused = outcomes

func paused_case(passive: String, pause_after: int) -> void:
 var sim = fresh(passive)
 if passive == "p2": fill_p2(sim)
 var setup: Dictionary = setup_rain(sim)
 var state: Dictionary = setup.state
 var hook: Dictionary = {"count":0,"fired":false}
 var trace: Array = []
 sim.combat_event.connect(func(event: Dictionary):
  if event.kind in ["damage","ink_e1_contact","ink_e1_finished","ink_p2_splash_started","ink_p2_splash_finished"]: trace.append(event.duplicate(true))
  if event.kind == "damage" and event.get("source","") == "e1":
   hook.count = int(hook.count)+1
   if int(hook.count) == pause_after and not hook.fired:
    hook.fired = true
    sim.paused = true)
 check(sim.request_action("ink_e_up").accepted,"callback pause public E-up accepted")
 check(hook.fired and sim.paused and packets(sim,"e1").size() == pause_after,"pause stops exactly at chosen original packet")
 check(sim._e1_reform_pending.size() == 1 and sim.ink_e1_finished.is_empty(),"paused original remains pending even when last packet committed")
 check(not sim._casts[int(setup.id)].finished,"paused original does not finish generic cast")
 check(not state.marks.is_empty(),"paused mark snapshot retained until true terminal")
 check(sim._p2_source_frames.is_empty(),"pause retains no synthetic active P2 stack frame")
 if passive == "p1":
  check(not sim.p1.roots[int(setup.id)].complete and sim.ink_p1_receipts.is_empty(),"pause never completes or settles P1 early")
 else:
  check(sim.ink_p2_claims.size() == 1 and sim.p2.stacks == 0,"first actual HP commit consumes P2 exactly once")
  check(sim._p2_pending.size() == 1 and sim.ink_p2_splashes.is_empty() and packets(sim,"yanguizhou_p2").is_empty(),"P2 whole-reform barrier retains splash across pause")
 if pause_after == 1:
  check(not state.hit_targets.has(setup.enemies[1].actor_id),"paused second original target is not pre-claimed")
  var key: String = "%d:%d:ink_e1_reform_burst:%s"%[sim.encounter_generation,int(setup.id),setup.enemies[1].actor_id]
  check(not sim._hit_claims.has(key),"paused second original hit claim is absent")
  near(float(setup.enemies[1].hp),10000.0,"second original remains untouched while paused")
 var stopped: Dictionary = summarize(sim,setup)
 sim.step(0.10)
 check(summarize(sim,setup) == stopped,"held pause freezes HP/CD/time/receipts/core")
 # Moving the saved targets beyond the release radius cannot resnapshot the
 # original membership or original impact center on resume.
 if pause_after == 1:
  setup.enemies[0].position = Vector3(12,0,0)
  setup.enemies[1].position = Vector3(13,0,0)
 sim.paused = false
 sim.step(0.02)
 var resumed: Dictionary = summarize(sim,setup)
 check(sim._e1_reform_pending.is_empty() and state.marks.is_empty(),"resume drains and clears exact original work")
 check(resumed.original_targets == ["enemy_1","enemy_2","enemy_1"],"resume neither repeats first/last nor loses mark channel")
 check(resumed.contact_segments == ["reform_burst","reform_burst","rain_mark_bonus"],"resume preserves original two-channel order")
 check(resumed.contact_amounts.size() == resumed.original_amounts.size(),"one original HP-delta receipt per committed packet")
 for index: int in range(mini(resumed.contact_amounts.size(),resumed.original_amounts.size())):
  near(float(resumed.contact_amounts[index]),float(resumed.original_amounts[index]),"P2 splash never contaminates original HP-delta receipts")
 check(resumed.finished == 1 and sim._casts[int(setup.id)].finished,"resumed original finishes exactly once")
 near(sim.hero_time,0.02,"resume advances one core tick after original remainder")
 check(sim.ink_core_steps == 1,"resume runs inherited core exactly once")
 near(sim.hero.cooldowns.e,float(setup.cd)-0.02,"resume retains entry cooldown less one tick")
 for receipt: Dictionary in sim.ink_e1_receipts:
  near(float(receipt.source_time),0.0,"remainder retains original source time")
  near(float(receipt.settled_at),0.0,"original remainder settles before core clock")
 check(sim._p2_source_frames.is_empty() and not sim._e1_reform_draining,"all source/drain wrappers unwind")
 if passive == "p1":
  check(sim.ink_p1_receipts.size() == 1 and not sim.ink_p1_receipts[0].qualified,"two original identities exclude P1 supplement")
  check(sim.ink_p1_receipts[0].distinct_targets == 2 and sim.ink_p1_receipts[0].ordinary_packet_count == 3,"P1 observes all three real packets and both identities")
  near(float(sim.ink_p1_receipts[0].actual_supplement),0.0,"two-target P1 pays no supplement")
  near(float(sim.ink_p1_receipts[0].cooldown_refund),0.0,"two-target P1 pays no cooldown refund")
  check(packets(sim,"yanguizhou_p1").is_empty(),"two-target P1 emits no generated damage")
 else:
  check(sim.ink_p2_claims.size() == 1 and sim.ink_p2_splashes.size() == 1,"resumed P2 consumes and splashes once")
  check(packets(sim,"yanguizhou_p2").size() == 2 and sim.ink_p1_receipts.is_empty(),"P2 frozen two-target splash remains independent of P1")
  var original_finished: int = -1
  var splash_started: int = -1
  for index: int in range(trace.size()):
   if trace[index].kind == "ink_e1_finished": original_finished = index
   if trace[index].kind == "ink_p2_splash_started": splash_started = index
  check(original_finished >= 0 and splash_started > original_finished,"P2 splash starts only after entire original reform terminal")
  for index: int in range(2):
   var target_id: String = str(setup.enemies[index].actor_id)
   var actual: float = 0.0
   for event: Dictionary in trace:
    if event.kind == "damage" and event.get("target","") == target_id: actual += float(event.amount)
   near(10000.0-float(setup.enemies[index].hp),actual,"final HP equals separate original plus P2 committed packets")
 var count: int = packets(sim,"e1").size()
 sim.step(0.02)
 check(packets(sim,"e1").size() == count and sim.ink_e1_finished.size() == 1,"later tick does not replay completed originals/terminal")
 observations[passive+"_pause_after_"+str(pause_after)] = {"stopped":stopped,"resumed":resumed,"trace":trace}
 sim.free()

func retire_case(retirement: String, on_resume: bool) -> void:
 var sim = fresh()
 var setup: Dictionary = setup_rain(sim)
 var hook: Dictionary = {"count":0,"retired":false}
 var originals: Array = []
 var terminals: Array = []
 sim.combat_event.connect(func(event: Dictionary):
  if event.kind == "ink_e1_finished": terminals.append(event.duplicate(true))
  if event.kind != "damage" or event.get("source","") != "e1": return
  originals.append(event.duplicate(true)); hook.count = int(hook.count)+1
  if on_resume and int(hook.count) == 1:
   sim.paused = true
   return
  if hook.retired: return
  hook.retired = true
  match retirement:
   "cancel": sim.cancel_cast(int(setup.id))
   "death": sim.damage_hero(100000.0,Vector3.ZERO,0.0,true,true)
   "room": sim.end_encounter("cleared"); sim.begin_encounter("replacement-e1-room",[])
   "rest": Rest.new(RefCounted.new())._clear_live_state(sim)
 )
 check(sim.request_action("ink_e_up").accepted,"retirement fixture public E-up accepted")
 if on_resume:
  check(sim.paused and originals.size() == 1,"retirement-on-resume starts with one committed original")
  sim.paused = false; sim.step(0.02)
 check(hook.retired and sim._e1_reform_pending.is_empty() and setup.state.marks.is_empty(),"callback "+retirement+" drops exact original remainder and marks")
 check(originals.size() == (2 if on_resume else 1),"callback "+retirement+" stops before next original/mark packet")
 check(terminals.is_empty() and sim.ink_p1_receipts.is_empty(),"callback "+retirement+" cannot synthesize terminal or P1 settlement")
 check(sim._p2_source_frames.is_empty() and not sim._e1_reform_draining,"callback "+retirement+" unwinds local barriers")
 var expected_steps: int = 1 if on_resume and retirement == "cancel" else 0
 check(sim.ink_core_steps == expected_steps,"callback "+retirement+" advances at most the sole authorized next core tick")
 var hp_after: Array = setup.enemies.map(func(enemy): return enemy.hp)
 var count: int = originals.size()
 sim.step(0.02)
 check(originals.size() == count and setup.enemies.map(func(enemy): return enemy.hp) == hp_after,"callback "+retirement+" never revives old damage later")
 observations[retirement+("_on_resume" if on_resume else "_at_first")] = {"original_count":originals.size(),"terminal_count":terminals.size(),"core_at_retirement":expected_steps,"old_hp":hp_after,"phase":sim.phase}
 sim.free()

func victory_waits_for_terminal() -> void:
 var sim = fresh()
 var setup: Dictionary = setup_rain(sim,false,90.0)
 sim.auto_finish = true
 var trace: Array = []
 var count: Dictionary = {"original":0}
 sim.combat_event.connect(func(event: Dictionary):
  if event.kind in ["ink_e1_finished","encounter_finished"]: trace.append(event.kind)
  if event.kind == "damage" and event.get("source","") == "e1":
   count.original = int(count.original)+1
   if int(count.original) == 2: sim.paused = true)
 check(sim.request_action("ink_e_up").accepted,"lethal original E-up accepted")
 check(sim.living().is_empty() and sim.phase == "combat" and sim.paused,"last lethal callback pause cannot let victory retire original work")
 check(sim.ink_e1_finished.is_empty() and not sim.p1.roots[int(setup.id)].complete,"last lethal callback pause withholds E1/P1 terminal")
 sim._check_victory()
 check(sim.phase == "combat","pending original explicitly gates victory")
 sim.paused = false; sim.step(0.02)
 check(trace == ["ink_e1_finished","encounter_finished"] and sim.phase == "victory","real terminal precedes one final victory")
 check(int(count.original) == 2 and sim.ink_core_steps == 1,"lethal resume repeats no packet and takes one inherited core tick")
 observations.victory = {"order":trace,"original_packets":count.original,"core_steps":sim.ink_core_steps}
 sim.free()

func original_identity_is_preserved() -> void:
 var sim = fresh("")
 var setup: Dictionary = setup_rain(sim)
 var stopped: Dictionary = {"done":false}
 sim.combat_event.connect(func(event: Dictionary):
  if event.kind == "damage" and event.get("source","") == "e1" and not stopped.done:
   stopped.done = true; sim.paused = true)
 check(sim.request_action("ink_e_up").accepted,"identity fixture public E-up accepted")
 var old: Dictionary = setup.enemies[1]
 var replacement: Dictionary = old.duplicate(true)
 sim.enemies[sim.enemies.find(old)] = replacement
 var newcomer: Dictionary = sim.spawn_enemy("minion",Vector3(0.3,0,0.2),10000.0)
 newcomer.state = "chase"; newcomer.defence = 0.0
 sim.paused = false; sim.step(0.02)
 near(float(old.hp),10000.0,"missing original snapshot body receives no resumed damage")
 near(float(replacement.hp),10000.0,"same actor ID replacement cannot inherit original target identity")
 near(float(newcomer.hp),10000.0,"new nearby body cannot join either original snapshot")
 near(float(setup.enemies[0].hp),9855.0,"surviving original first body receives base then mark exactly once")
 check(packets(sim,"e1").map(func(event): return event.target) == ["enemy_1","enemy_1"],"identity filtering retains the two original channels without retargeting")
 check(sim.ink_e1_finished.size() == 1 and sim.ink_core_steps == 1,"identity retirement still finishes once before one core tick")
 observations.identity = {"old_hp":old.hp,"replacement_hp":replacement.hp,"newcomer_hp":newcomer.hp,"original_targets":packets(sim,"e1").map(func(event): return event.target)}
 sim.free()

func original_e1_reform_remainder() -> void:
 compare_unpaused()
 for passive: String in ["p1","p2"]:
  for pause_after: int in [1,3]: paused_case(passive,pause_after)
 for retirement: String in ["cancel","death","room","rest"]:
  for on_resume: bool in [false,true]: retire_case(retirement,on_resume)
 original_identity_is_preserved()
 victory_waits_for_terminal()
 groups.append(REQUIRED_GROUPS[0])
 print("INK_E1_REFORM_GROUP ",REQUIRED_GROUPS[0])

func run() -> void:
 original_e1_reform_remainder()
 for group: String in REQUIRED_GROUPS: check(groups.count(group) == 1,"required affected group reached exactly once")
 var report: Dictionary = {"schema":"ink-e1-reform-remainder-finite-1","passed":failures.is_empty() and groups == REQUIRED_GROUPS,"checks":checks,"failures":failures,"completed":groups,"source_binding_sha256":FileAccess.get_sha256(BINDING),"observations":observations,"mode":"SYNCHRONOUS_CALLBACK_FIXTURE","native_input":false,"ordinary_admission":false,"production_entry_changed":false,"old_full_matrices_rerun":false}
 if not output_path.is_empty():
  var output := FileAccess.open(output_path,FileAccess.WRITE)
  if output == null: push_error("cannot write E1 reform finite report"); quit(2); return
  output.store_string(JSON.stringify(report,"  ")+"\n")
 print("INK_E1_REFORM_REPORT ",JSON.stringify(report))
 quit(0 if report.passed else 1)
