extends SceneTree
## Seven bounded affected groups. This file is test SOURCE, not a passed run.
## Ordinary learning/B09/rest use the real Host/Session/Model. Other probes are
## explicitly labelled mechanism fixtures, including the synthetic Q2 interval.
const Sim = preload("res://tests/ink_e3_ordinary_20261006/ordinary01/sim.gd")
const FixtureHost = preload("res://tests/ink_e3_ordinary_20261006/ordinary01/finite_host.gd")
const Production = preload("res://scripts/integration/yanguizhou_first_floor.gd")
const Session = preload("res://tests/ink_e3_ordinary_20261006/ordinary01/floor_session.gd")
const Binding = preload("res://tests/ink_e3_ordinary_20261006/ordinary01/live_binding.gd")
const Catalog = preload("res://tests/ink_e3_ordinary_20261006/ordinary01/catalog.gd")
const Router = preload("res://tests/ink_e3_ordinary_20261006/ordinary01/input_adapter.gd")
const OldBinding = preload("res://tests/ink_e2_boundary_20261006/ordinary01/live_binding.gd")
const OldSim = preload("res://tests/ink_e2_boundary_20261006/ordinary01/sim.gd")
const Audio = preload("res://tests/ink_style_specimen_20261004/audio_output.gd")
const HOME := "res://tests/ink_first_floor_user_route_20261005/runtime01/"
const LEAF := "res://tests/ink_e3_ordinary_20261006/ordinary01/"
const REQUIRED_GROUPS: Array = ["atomic_landing_and_boss_exclusion", "p1_dual_pause_resume", "q2_e3_jump_and_batch_barrier", "h12_mechanics_and_catalog_ceiling", "ordinary_session_learning_input_clock", "p1_single_terminal_and_b09", "current_q1_e1_e2_r1_nav_rest"]
const REQUIRED: Array = REQUIRED_GROUPS
var checks: int = 0
var errors: Array[String] = []
var groups: Array[String] = []
var group_checks: Dictionary = {}
var active_group: String = ""
var observations: Dictionary = {}
var output_path: String = ""
var serial: int = 0
var live_session: RefCounted
var event_errors: Array = []

func _initialize() -> void:
 output_path = OS.get_environment("INK_E3_ORDINARY_REPORT")
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--e3-ordinary-result="): output_path = arg.trim_prefix("--e3-ordinary-result=")
 run.call_deferred()

func check(ok: bool, label: String) -> bool:
 checks += 1
 if not active_group.is_empty(): group_checks[active_group] = int(group_checks.get(active_group,0)) + 1
 if not ok: errors.append(active_group+": "+label); push_error(active_group+": "+label)
 return ok

func near(a: float, b: float, label: String) -> void:
 check(is_finite(a) and is_finite(b) and absf(a-b) < 0.0001,label+" actual="+str(a)+" expected="+str(b))

func point(a: Vector3, b: Vector3, label: String) -> void:
 check(a.is_finite() and a.distance_to(b) < 0.0001,label)

func done_group(name: String) -> void:
 check(name not in groups and int(group_checks.get(name,0)) > 0,"nonempty group completes once")
 groups.append(name)
 print("INK_E3_ORDINARY_GROUP ",name)

func key(code: int, down: bool = true) -> InputEventKey:
 var event := InputEventKey.new(); event.physical_keycode = code; event.pressed = down
 return event

func fresh(rank: int = 1, hexes: Array = [], extent: float = 30.0):
 serial += 1
 var sim = Sim.new(); root.add_child(sim)
 sim.auto_finish = false; sim.ai_enabled = false; sim.arena_half_extent = extent; sim.obstacles = []
 sim.hero.position = Vector3.ZERO; sim.hero.loadout.e = "e3"; sim.hero.ranks.e = 1
 sim.hero.loadout.q = "q2"; sim.hero.ranks.q = 1; sim.hero.loadout.r = "r1"; sim.hero.ranks.r = 1
 sim.hero.loadout.passive = "p1"; sim.hero.ranks.passive = rank
 sim.hero.stats.ap = 100.0; sim.hero.stats.crit_chance = 0.0; sim.hero.stats.regen = 0.0
 sim.hero.stats.lifesteal = 0.2; sim.hero.stats.cdr = 0.0; sim.hero.stats.defence = 0.0
 check(sim.begin_encounter("e3-ordinary-explicit-fixture-%d"%serial,[]).accepted,"explicit mechanism fixture starts")
 sim.set_hexes(hexes)
 return sim

func target(sim, at: Vector3, kind: String = "minion") -> Dictionary:
 var enemy: Dictionary = sim.spawn_enemy(kind,at,10000.0)
 enemy.state = "chase"; enemy.defence = 0.0; enemy.radius = 0.25; enemy.position = at
 return enemy

func first(sim, at: Vector3) -> Dictionary:
 var result: Dictionary = sim.request_e3("first",at)
 check(result.accepted,"real E3 A accepted: "+str(result)); return result

func second(sim, at: Vector3) -> Dictionary:
 var result: Dictionary = sim.request_e3("second",at)
 check(result.accepted,"real E3 B accepted: "+str(result)); return result

func river(sim, x: float) -> Dictionary:
 check(sim.request_q2("first",Vector3(x,0,-3)).accepted,"real Q2 A accepted")
 var result: Dictionary = sim.request_q2("second",Vector3(x,0,3))
 check(result.accepted,"real Q2 B accepted")
 var found: Array = sim.ink_rivers.filter(func(item): return str(item.river_id) == str(result.get("river_id","")))
 check(found.size() == 1,"one original Q2 river")
 return found[0] if found.size() == 1 else {}

func p1_receipts(sim, id: int) -> Array:
 return sim.ink_p1_receipts.filter(func(item): return int(item.cast_id) == id)

func life_receipts(sim, id: int) -> Array:
 return sim.ink_p1_lifesteal_receipts.filter(func(item): return int(item.cast_id) == id)

func damage(sim, source: String) -> Array:
 return sim.event_log.filter(func(event): return event.kind == "damage" and event.get("source","") == source)

func input_clocks_and_intents() -> void:
 active_group = REQUIRED[4]
 var sim = fresh(); target(sim,Vector3(-2,0,0))
 var router = Router.new(); router.bind(sim)
 check(router.handle_event(key(KEY_E),Vector3(-2,0,0)).accepted,"fresh ordinary E-down places A")
 var state: Dictionary = sim.ink_frames; var id: int = int(state.cast_id)
 near(sim.hero.cooldowns.e,0.0,"first A starts no CD")
 check(not router.handle_event(key(KEY_E),Vector3(2,0,0)).accepted and is_same(state,sim.ink_frames),"held E cannot place B")
 var repeat: InputEventKey = key(KEY_E); repeat.echo = true
 check(not router.handle_event(repeat,Vector3(2,0,0)).accepted,"repeated E never confirms")
 sim.paused = true; var clock_before: float = sim.hero_time
 sim.step(20.0); near(sim.hero_time,clock_before,"pause freezes A window")
 near(sim.hero.cooldowns.e,0.0,"pause invents no A cooldown")
 router.queue_owned_boundary_e_up(key(KEY_E,false)); sim.paused = false
 sim.step(5.0)
 check(sim.ink_frames.is_empty() and sim.ink_e3_receipts.is_empty() and sim.ink_e3_finished.is_empty(),"five-second expiry removes A without damage completion")
 near(sim.hero.cooldowns.e,20.0,"A deadline begins original CD")
 check(p1_receipts(sim,id).is_empty() and life_receipts(sim,id).is_empty() and not sim.p1.roots.has(id),"expired A discards unpaid P1 root")
 var cooldown_attempt: Dictionary = router.handle_event(key(KEY_E),Vector3(-2,0,0))
 check(not cooldown_attempt.accepted and cooldown_attempt.reason == "cooldown" and sim.cast_serial == id,"cooldown rejects new E root")
 router.handle_event(key(KEY_E,false)); sim.step(20.02)
 check(router.handle_event(key(KEY_E),Vector3(-2,0,0)).accepted and sim.cast_serial == id+1,"fresh E after actual CD creates exactly one new A")
 sim.free()
 sim = fresh(); router = Router.new(); router.bind(sim)
 check(router.handle_event(key(KEY_Q),Vector3(2,0,0)).accepted and not router.q2_aim.is_empty(),"actual Q2 preview owns its confirmation")
 var q_intent: Dictionary = router.q2_aim
 var denied: Dictionary = router.handle_event(key(KEY_E),Vector3(-2,0,0))
 check(not denied.accepted and denied.reason == "other_skill_preview_active" and is_same(q_intent,router.q2_aim) and sim.ink_frames.is_empty(),"E3 refuses to steal armed Q2")
 router.handle_event(key(KEY_E,false)); router.handle_event(key(KEY_ESCAPE))
 check(router.handle_event(key(KEY_R),Vector3(2,0,0)).accepted and not router.r1_aim.is_empty(),"actual R1 preview owns its confirmation")
 var r_intent: Dictionary = router.r1_aim
 denied = router.handle_event(key(KEY_E),Vector3(-2,0,0))
 check(not denied.accepted and denied.reason == "other_skill_preview_active" and is_same(r_intent,router.r1_aim) and sim.ink_frames.is_empty(),"E3 refuses to steal armed R1")
 observations.input_clock = {"expiry_source_seconds":5.0,"cooldown_source_seconds":20.0,"q_r_previews_retained":true,"physical_events_synthetic":true}
 sim.free()

func atomic_landing() -> void:
 active_group = REQUIRED[0]
 var sim = fresh(0)
 var a: Dictionary = target(sim,Vector3(-4,0,-1)); var b: Dictionary = target(sim,Vector3(-4,0,1))
 var boss: Dictionary = target(sim,Vector3(-4,0,0),"boss")
 sim.obstacles = [{"position":Vector3.ZERO,"half":Vector3(0.25,0,3)}]
 first(sim,Vector3(-4,0,0)); second(sim,Vector3(4,0,0))
 point(a.position,Vector3(4,0,-1),"legal first body crosses intervening wall")
 point(b.position,Vector3(4,0,1),"legal second body crosses intervening wall")
 point(boss.position,Vector3(-4,0,0),"Boss never exchanges")
 near(boss.hp,10000.0,"Boss receives no exchange damage")
 point(sim.hero.position,Vector3.ZERO,"base E3 never moves its owner")
 check(sim.ink_e3_receipts.size() == 2 and sim.ink_e3_finished.size() == 1,"legal batch emits two original packets and one terminal")
 near(sim.hero.cooldowns.e,20.0,"legal B starts source CD once")
 sim.free()
 sim = fresh(); a = target(sim,Vector3(-4,0,-1)); b = target(sim,Vector3(-4,0,1))
 sim.obstacles = [{"position":Vector3(4,0,1),"half":Vector3(0.25,0,0.25)}]
 first(sim,Vector3(-4,0,0)); var frame: Dictionary = sim.ink_frames
 var id: int = int(frame.cast_id); var deadline: float = frame.expires_at
 var preview: Dictionary = sim.e3_preview(Vector3(4,0,0)); var rejected: Dictionary = sim.request_e3("second",Vector3(4,0,0))
 check(not preview.accepted and not rejected.accepted and rejected.reason == "e3_required_destination_illegal" and rejected.source_gameplay_outcome,"one illegal required landing rejects complete transaction")
 point(a.position,Vector3(-4,0,-1),"legal member is not partly committed")
 point(b.position,Vector3(-4,0,1),"illegal member remains at origin")
 near(a.hp,10000.0,"rejected batch damages no first member"); near(b.hp,10000.0,"rejected batch damages no second member")
 near(sim.hero.cooldowns.e,0.0,"rejected B starts no cooldown"); near(frame.expires_at,deadline,"rejected B preserves original deadline")
 check(is_same(frame,sim.ink_frames) and frame.phase == "first" and sim.cast_serial == id,"rejected B preserves same A and root")
 check(sim.ink_e3_receipts.is_empty() and sim.ink_e3_finished.is_empty() and sim.ink_qe_discontinuities.is_empty() and p1_receipts(sim,id).is_empty(),"rejected batch emits no damage, terminal, jump or payment")
 sim.obstacles = [{"position":Vector3.ZERO,"half":Vector3(0.25,0,3)}]
 second(sim,Vector3(4,0,0)); check(sim.cast_serial == id,"legal retry consumes original A root")
 sim.free(); done_group(REQUIRED[0])

func terminal_authenticity() -> void:
 active_group = REQUIRED[5]
 var sim = fresh(); sim.hero.hp = 100.0
 target(sim,Vector3(-3,0,0)); first(sim,Vector3(-3,0,0))
 var state: Dictionary = sim.ink_frames; var id: int = int(state.cast_id)
 sim.emit_event("ink_e3_damage_finished",{"cast_id":id,"frame_id":state.frame_id,"generation":state.generation,"room_id":state.room_id,"finished_at":sim.hero_time,"damage_stages_complete":true,"release_completed":true})
 sim.finish_cast(id)
 check(p1_receipts(sim,id).is_empty() and life_receipts(sim,id).is_empty(),"forged terminal and generic finish_cast cannot authorize payment")
 check(is_same(state,sim.ink_frames) and state.phase == "first" and not state.damage_stages_complete,"forged terminal cannot complete actual frame")
 var probe: Dictionary = {"terminal":false,"paid_inside":-1,"healed_inside":-1}
 sim.combat_event.connect(func(event: Dictionary):
  if event.kind == "ink_e3_damage_finished" and not probe.terminal:
   probe.terminal = true; probe.paid_inside = p1_receipts(sim,id).size(); probe.healed_inside = life_receipts(sim,id).size())
 second(sim,Vector3(3,0,0))
 check(probe.terminal and probe.paid_inside == 0 and probe.healed_inside == 0,"real terminal callback remains inside payment barrier")
 var records: Array = p1_receipts(sim,id)
 if check(records.size() == 1,"complete real single-target E3 settles once"):
  var item: Dictionary = records[0]
  check(item.qualified and item.distinct_targets == 1 and item.ordinary_packet_count == 1,"P1 captures exactly the original E3 packet")
  if check(sim.ink_e3_receipts.size() == 1,"one real E3 receipt supplies final damage basis"):
   near(item.final_basis,sim.ink_e3_receipts[0].actual_damage,"P1 basis is actual final E3 damage")
   near(item.actual_supplement,float(item.final_basis)*0.12,"rank-one P1 adds source twelve percent")
  near(item.cooldown_after,float(item.cooldown_before)*0.95,"P1 refunds current E cooldown once")
 sim.emit_event("ink_e3_damage_finished",sim.ink_e3_finished[0].duplicate(true) if not sim.ink_e3_finished.is_empty() else {})
 sim.finish_cast(id); sim.step(0.02)
 check(p1_receipts(sim,id).size() == 1 and life_receipts(sim,id).size() == 1,"replayed terminal and finish cannot repay or reheal")
 sim.free()

func dual_pause_resume() -> void:
 active_group = REQUIRED[1]
 var sim = fresh(); target(sim,Vector3(-3,0,-0.3)); target(sim,Vector3(-3,0,0.3))
 var probe: Dictionary = {"paused":false,"resume_time":-1.0,"resume_steps":-1}
 sim.combat_event.connect(func(event: Dictionary):
  if event.kind == "damage" and event.get("source","") == "e3":
   if not probe.paused: probe.paused = true; sim.paused = true
   else: probe.resume_time = sim.hero_time; probe.resume_steps = sim.ink_core_steps)
 first(sim,Vector3(-3,0,0)); var id: int = int(sim.ink_frames.cast_id)
 second(sim,Vector3(3,0,0))
 check(sim.paused and sim.ink_frames.phase == "settling" and sim.ink_frames.damage_cursor == 1,"real first E3 damage callback pauses admitted batch")
 check(sim.ink_e3_receipts.size() == 1 and sim.ink_e3_finished.is_empty() and p1_receipts(sim,id).is_empty() and life_receipts(sim,id).is_empty(),"partial two-target batch has no terminal or early payment")
 var at: float = sim.hero_time; var steps: int = sim.ink_core_steps
 sim.step(3.0); near(sim.hero_time,at,"paused E3 batch consumes no source time")
 check(sim.ink_core_steps == steps,"paused batch adds no core step")
 sim.paused = false; sim.step(0.02)
 check(sim.ink_e3_receipts.size() == 2 and sim.ink_e3_finished.size() == 1 and sim.ink_frames.is_empty(),"resume drains exact second member then one terminal")
 near(probe.resume_time,at,"old E3 member drains before new time")
 check(probe.resume_steps == steps and sim.ink_core_steps == steps+1,"resume precedes exactly one new inherited core step")
 var records: Array = p1_receipts(sim,id)
 if check(records.size() == 1,"dual E3 produces one final negative P1 receipt"):
  check(records[0].distinct_targets == 2 and not records[0].qualified and records[0].actual_supplement == 0.0 and records[0].cooldown_refund == 0.0,"two distinct enemies refuse all P1 payment")
 check(life_receipts(sim,id).is_empty(),"dual-target E3 earns no supplemental lifesteal")
 sim.step(0.02); check(p1_receipts(sim,id).size() == 1,"resumed root never settles twice")
 observations.dual_pause = probe.duplicate(true)
 sim.free(); done_group(REQUIRED[1])

func epoch_case(final_x: float, earlier: bool) -> void:
 var sim = fresh(0); river(sim,0.0)
 var enemy: Dictionary = target(sim,Vector3(1.1,0,0)); var before: Dictionary = sim._enemy_motion_snapshot()
 first(sim,Vector3(final_x,0,0)); sim.hero.position = Vector3(-1.2,0,0)
 check(sim.request_action("attack",Vector3(10,0,0)).accepted,"epoch fixture uses real BASIC enhancement event")
 check(sim.ink_q2_receipts.is_empty(),"BASIC birth has not already consumed target river hit")
 # Explicit source-interval fixture: geometry and time surround actual public
 # BASIC/Q2/E3 commands. This does not claim natural AI or native input evidence.
 sim._qe_prepare_tick(0.0); enemy.position = Vector3(final_x,0,0)
 sim.hero_time = 0.02; sim._q2_tick_start = 0.0; sim._q2_tick_active = true
 sim._q2_motion_traces = [{"enemy":enemy,"from":Vector3(1.1,0,0),"to":enemy.position,"start":0.0,"end":0.02}]
 var predicted: Array = sim._q2_collect_contacts(before,0.0,0.02)
 if not check(predicted.size() == 1,"one actual Q2 swept-contact prediction"): sim.free(); return
 if earlier: check(float(predicted[0].time) < 0.02,"comparison contact genuinely predates exchange")
 else: near(predicted[0].time,0.02,"abandoned old endpoint has same source time as exchange")
 var probe: Dictionary = {"enhanced":false,"exchange":false}
 sim.combat_event.connect(func(event: Dictionary):
  if event.kind == "ink_q2_projectile_enhanced" and not probe.enhanced:
   probe.enhanced = true; probe.exchange = sim.request_e3("second",Vector3(final_x+6,0,0)).accepted)
 sim._settle_motion_interval(before,0.0,0.02)
 check(probe.enhanced and probe.exchange,"real enhancement callback completes real E3 jump")
 point(enemy.position,Vector3(final_x+6,0,0),"actual E3 abandons old predicted endpoint")
 check(sim.ink_q2_receipts.size() == (1 if earlier else 0),"only strictly earlier continuous river touch survives")
 check(sim._qe_queued_river_current(predicted[0]) == earlier,"same-time swept prediction invalidates at exact jump epoch")
 check(sim._q2_collect_contacts(before,0.0,0.02).is_empty(),"old trace cannot regenerate abandoned endpoint")
 if not earlier:
  sim._qe_jumps.clear(); sim.paused = true; sim._q2_dispatch_contacts(predicted)
  check(sim._q2_deferred_contacts.size() == 1,"paused stale prediction preserves original epoch")
  sim.paused = false; sim._q2_dispatch_contacts(sim._q2_collect_contacts(before,0.0,0.02))
  check(sim.ink_q2_receipts.is_empty(),"room jump history still rejects paused same-time prediction")
 sim.free()

func q2_jumps_and_barrier() -> void:
 active_group = REQUIRED[2]
 var sim = fresh(0); river(sim,0.0); var enemy: Dictionary = target(sim,Vector3(-3,0,0))
 sim.step(0.02); first(sim,enemy.position)
 sim._q2_tick_start = sim.hero_time-0.02; sim._q2_tick_active = true; sim._qe_prepare_tick(sim._q2_tick_start)
 var origin: Vector3 = enemy.position; second(sim,Vector3(3,0,0))
 sim._q2_record_motion(enemy,origin,enemy.position,sim._q2_tick_start,sim.hero_time)
 check(sim._q2_collect_contacts({},sim._q2_tick_start,sim.hero_time).is_empty() and sim.ink_q2_receipts.is_empty(),"real E3 discontinuity never sweeps intervening river")
 check(sim.ink_qe_discontinuities.size() == 1 and not sim.ink_qe_discontinuities[0].continuous_motion,"jump is recorded as a discontinuity")
 sim.free(); epoch_case(1.0,false); epoch_case(0.9,true)
 sim = fresh(); var state: Dictionary = river(sim,3.0)
 target(sim,Vector3(-3,0,-0.3)); target(sim,Vector3(-3,0,0.3))
 var stopped: Array = [false]
 sim.combat_event.connect(func(event: Dictionary):
  if event.kind == "damage" and event.get("source","") == "q2" and not stopped[0]: stopped[0] = true; sim.paused = true)
 first(sim,Vector3(-3,0,0)); var e_id: int = int(sim.ink_frames.cast_id)
 second(sim,Vector3(3,0,0))
 check(stopped[0] and sim.ink_q2_receipts.size() == 1 and sim._q2_deferred_contacts.size() == 1,"actual E3 arrival touches river and pauses before its second real arrival")
 check(sim.ink_e3_receipts.is_empty() and sim.ink_e3_finished.is_empty() and sim.ink_p1_receipts.is_empty(),"arrival pause cannot advance E3 damage or pay partial Q2/E3")
 sim.paused = false; sim.step(0.02)
 check(sim.ink_q2_receipts.size() == 2 and sim._q2_deferred_contacts.is_empty(),"original deferred arrival applies exactly once after resume")
 check(sim.ink_e3_receipts.size() == 2 and p1_receipts(sim,e_id).size() == 1,"same E3 batch survives nested actual Q2 arrival dispatch")
 if not state.is_empty():
  sim.step(maxf(0.02,float(state.expires_at)-sim.hero_time+0.025))
  var records: Array = p1_receipts(sim,int(state.cast_id))
  if check(records.size() == 1,"whole Q2 lifetime settles through preserved collector barrier"):
   check(records[0].distinct_targets == 2 and not records[0].qualified and records[0].actual_supplement == 0.0,"both real arrivals remain in Q2 target union")
  check(life_receipts(sim,int(state.cast_id)).is_empty() and life_receipts(sim,e_id).is_empty(),"neither two-target root generates supplemental heal")
 observations.q2_intervals = "Two explicit synthetic source intervals; actual Q2/BASIC/E3 APIs, real arrival queue and inherited P1 batch wrappers"
 sim.free(); done_group(REQUIRED[2])

func h12_and_catalog() -> void:
 active_group = REQUIRED[3]
 # H12 is deliberately a direct-Hex mechanism fixture, never ordinary offered.
 var sim = fresh(1,["yanguizhou_h12"]); sim.hero.hp = 100.0
 var enemy: Dictionary = target(sim,Vector3(-3,0,0)); first(sim,enemy.position)
 var id: int = int(sim.ink_frames.cast_id); second(sim,Vector3(3,0,0))
 check(sim.ink_frames.phase == "return_window" and p1_receipts(sim,id).size() == 1,"real E3 settles P1 before H12 movement window")
 var count: int = sim.cast_serial; var hp: float = enemy.hp; var owner_hp: float = sim.hero.hp; var cd: float = sim.hero.cooldowns.e
 var out: Dictionary = sim.request_e3("return")
 check(out.accepted and out.new_damage_packets == 0,"H12 returns through actual source movement API")
 point(enemy.position,Vector3(-3,0,0),"H12 restores original living member position")
 near(enemy.hp,hp,"H12 deals no new damage"); near(sim.hero.hp,owner_hp,"H12 creates no new heal"); near(sim.hero.cooldowns.e,cd,"H12 never restarts or re-refunds cooldown")
 check(sim.cast_serial == count and sim.ink_e3_receipts.size() == 1 and sim.ink_e3_finished.size() == 1 and p1_receipts(sim,id).size() == 1 and life_receipts(sim,id).size() == 1,"H12 adds no root, terminal or second P1 payment")
 check(not sim.request_e3("return").accepted,"H12 cannot return twice")
 check(Catalog.FIRST_SLICE_HEX_HOOKS.size() == 10,"ordinary Catalog retains original ten-Hex ceiling")
 for hex_id: String in ["yanguizhou_h11","yanguizhou_h12"]:
  var hook: String = "hex.final_design."+hex_id+".v1"
  check(hook not in Catalog.FIRST_SLICE_HEX_HOOKS,"ordinary Catalog never offers "+hex_id)
  var caps: Dictionary = {"schema_version":1,"hero_id":"yanguizhou","source_binding_id":"explicit-ceiling-fixture","runtime_candidates":["E3"],"supported_hooks":[hook]}
  var rejected: Dictionary = Catalog.build(caps,HOME+"shop_table.json",true)
  check(not rejected.accepted and rejected.reason == "hex_outside_verified_first_slice","Catalog rejects injected "+hex_id+" capability")
 sim.free(); done_group(REQUIRED[3])

func current_mechanism_regressions() -> void:
 active_group = REQUIRED[6]
 var sim = fresh(); sim.hero.loadout.q = "q1"
 target(sim,Vector3(0.51,0,0.2)); target(sim,Vector3(0.51,0,-0.2))
 var probe: Dictionary = {"stopped":false,"second_time":-1.0,"second_steps":-1}
 sim.combat_event.connect(func(event: Dictionary):
  if event.kind == "damage" and event.get("source","") == "q1":
   if not probe.stopped: probe.stopped = true; sim.paused = true
   else: probe.second_time = sim.hero_time; probe.second_steps = sim.ink_core_steps)
 check(sim.request_ink_input("q_down").accepted,"current Q1 arms")
 check(sim.request_ink_input("left_down",Vector3.ZERO).accepted,"current Q1 takes real drawing down")
 check(sim.request_ink_input("motion",Vector3(0.26,0,0)).accepted,"current Q1 records endpoint")
 var released: Dictionary = sim.request_ink_input("left_up",Vector3(0.26,0,0))
 check(released.accepted,"current Q1 releases original wave"); sim.step(0.02)
 check(sim.paused and damage(sim,"q1").size() == 1 and not sim._q2_motion_resume.is_empty() and sim.ink_p1_receipts.is_empty(),"current Q1 exact endpoint pauses without early P1")
 var at: float = sim.hero_time; var steps: int = sim.ink_core_steps
 sim.step(1.0); near(sim.hero_time,at,"current Q1 paused budget stays frozen")
 sim.paused = false; sim.step(0.02)
 check(damage(sim,"q1").size() == 2 and sim._q2_motion_resume.is_empty() and sim._q2_resume_from == -1.0,"current Q1 continuation completes both original contacts")
 near(probe.second_time,at,"current Q1 old contact precedes new time")
 check(probe.second_steps == steps and sim.ink_core_steps == steps+1,"current Q1 adds exactly one subsequent core step")
 if check(sim.ink_p1_receipts.size() == 1,"current Q1 has one whole-root receipt"):
  check(sim.ink_p1_receipts[0].distinct_targets == 2 and not sim.ink_p1_receipts[0].qualified,"current Q1 union still refuses two-target P1")
 sim.free()
 sim = fresh(); sim.hero.loadout.e = "e1"; var router = Router.new(); router.bind(sim)
 check(router.handle_event(key(KEY_E)).accepted,"new Router retains E1 down")
 sim.paused = true
 check(router.queue_owned_boundary_e_up(key(KEY_E,false)).accepted and sim.ink_rain.release_pending,"new Router retains true paused E1 keyup")
 sim.paused = false; sim.step(0.02)
 check(sim.ink_rain.is_empty() and sim.ink_e1_finished.size() == 1,"current E1 release settles once")
 sim.free()
 sim = fresh(); sim.hero.loadout.e = "e2"; router = Router.new(); router.bind(sim)
 check(router.handle_event(key(KEY_E),Vector3(20,0,0)).accepted,"new Router retains E2 launch")
 var boat: Dictionary = sim.ink_boat; var id: int = int(boat.cast_id)
 router.suspend_input("explicit-menu-fixture")
 check(not router.handle_event(key(KEY_E)).accepted and is_same(boat,sim.ink_boat),"menu cannot turn old E2 down into boarding")
 router.queue_owned_boundary_e_up(key(KEY_E,false))
 check(not router.e2_input_snapshot().release_required,"real E2 keyup still drains old latch")
 check(router.handle_event(key(KEY_E)).accepted and sim.ink_e2_finished.size() == 1 and sim.ink_e2_finished[0].cast_id == id,"fresh E2 boards original root once")
 sim.free()
 sim = fresh(); var director_id: int = sim.enemy_director.get_instance_id()
 var enemy: Dictionary = target(sim,Vector3(1,0,0))
 check(sim.enemy_director.get_script().resource_path == Binding.DIRECTOR_PATH,"current R1 navigation director remains selected")
 check(sim.request_action("r",Vector3.ZERO).accepted and sim.r1_enemy_rates(enemy).in_domain,"current R1 source domain remains effective")
 first(sim,Vector3(-3,0,0)); second(sim,Vector3(3,0,0))
 check(not sim.ink_snow.is_empty() and sim.enemy_director.get_instance_id() == director_id and sim.r1_enemy_rates(enemy).in_domain,"E3 preserves current R1 domain and exact director")
 observations.current_q1_pause = probe.duplicate(true)
 sim.free()

func on_event(event: Dictionary) -> void:
 var result: Dictionary = live_session.observe_event(live_session.sim,event)
 if event.get("kind","") in ["damage","kill"] and not result.accepted: event_errors.append(result)

func on_terminal(event: Dictionary) -> void:
 live_session.queue_terminal(live_session.sim,event)

func choices(room) -> void:
 for milestone in live_session.ledger.model.snapshot().pending_milestones.duplicate():
  room.initial_controller.ensure_auto_hex()
  room.initial_hud.adapter.request("hex_select",{"milestone":milestone,"slot":3})
  check(room.initial_controller.last_result.accepted,"real mandatory original Hex choice")

func route_enter(room, row: int, node_id: String) -> bool:
 choices(room)
 if not check(live_session.select_node(row,node_id).accepted,"legal selected route "+node_id): return false
 return check(live_session.enter_selected_node().accepted,"same Session commits route "+node_id)

func finish_fixture_combat(room, sim) -> void:
 for _i in range(80): sim.step(0.02); live_session.update_after_source_step()
 for enemy: Dictionary in sim.living().duplicate():
  sim.damage_enemy(enemy,1000000.0,"e3_ordinary_route_fixture",0,true,false,{"direct":false,"no_reactions":true})
 sim.step(0.02); live_session.update_after_source_step(); choices(room)
 check(live_session.status == "between_rooms" and event_errors.is_empty(),"same authority settles labelled route damage fixture")

func ordinary_route() -> void:
 active_group = REQUIRED[4]
 var room = FixtureHost.new(); root.add_child(room)
 var sim: Node = room._make_floor_sim(); room.sim = sim; room.add_child(sim); sim.ai_enabled = false
 var session: RefCounted = room._make_floor_session(); room.shop_session = session; live_session = session
 room.input_router = room._make_floor_router(); room.input_router.bind(sim)
 room.audio_output = Audio.new(); room.add_child(room.audio_output); room._mainprep_required = false; room._mainprep_pending = false
 var production_script: GDScript = Production
 check(production_script.get_base_script().resource_path == LEAF+"host.gd","production selects exact E3 ordinary host")
 check(sim.get_script().resource_path == Binding.SIM_PATH and session.get_script().resource_path == LEAF+"floor_session.gd","ordinary factory selects exact new Sim and original Session successor")
 var director_id: int = sim.enemy_director.get_instance_id()
 check(room._install_source_navigation().accepted and sim.enemy_director.get_instance_id() == director_id,"fresh navigation admission never swaps current director")
 check(not room._install_source_navigation().accepted,"navigation admits only once")
 var caps: Dictionary = Binding.read_capabilities(sim,true)
 check(caps.accepted and caps.capabilities.runtime_candidates == ["Q1","Q2","Q3","E1","E2","E3","P1","R1"],"exact capability closure adds only ordinary E3")
 check(not OldBinding.read_capabilities(sim,true).accepted,"frozen E2 binding rejects new Sim identity")
 var old = OldSim.new(); root.add_child(old)
 check(not Binding.read_capabilities(old,true).accepted,"new binding rejects frozen E2 Sim identity"); old.free()
 check(session.configure_reward_table(HOME+"reward_table.json",HOME+"rewards.csv",HOME+"validation_result.json",true).accepted,"original reward table configures")
 var definition: Dictionary = Session.MixedSchema.load_definition(Session.DEFAULT_DEFINITION,true)
 var initialized: Dictionary = session.initialize_floor(sim,definition.definition,"e3-ordinary-finite-route",true)
 if not check(initialized.accepted,"real Session and Bridge admit exact Sim: "+str(initialized.get("reason",""))): live_session = null; room.free(); return
 check(session.ledger.get_script().resource_path == LEAF+"bridge.gd" and session._owner_intact() and is_same(sim.progression,session.ledger),"one original health, stat, reward and economy owner")
 var baseline: Dictionary = session.ledger.model.snapshot()
 check(baseline.level == 1 and baseline.gold == 0 and baseline.xp == 0 and baseline.points == 1,"ordinary baseline stays Lv1, zero gold/XP, original one SP")
 session.bind_input_suspender(room.input_router.suspend_input)
 sim.combat_event.connect(on_event); sim.encounter_finished.connect(on_terminal)
 room._create_session_controls(); await process_frame; choices(room)
 room.initial_hud.e3_choice.pressed.emit()
 check(room.initial_controller.last_result.accepted and sim.hero.loadout.e == "e3" and sim.hero.ranks.e == 1 and session.ledger.model.state.points == 0,"actual E3 selector spends original one SP through real Model")
 check(room.initial_hud.e3_choice.tooltip_text.contains("H11/H12") and room.initial_hud.e3_choice.tooltip_text.contains("保留A") and room.initial_hud.e3_choice.tooltip_text.contains("临时"),"real selector declares retained A, closed Hex and temporary visuals")
 check(room.initial_hud.p1_choice.disabled and room.initial_hud.r1_choice.disabled,"original SP shortage and Lv6 R gate remain effective")
 # Only after the untouched ordinary baseline: explicit one-SP/500-gold
 # funding fixtures. The actual buttons, quote, debit and stat projection act.
 active_group = REQUIRED[5]
 var model = session.ledger.model
 model.state.points = 1; model.state.gold = 500; model.state.revision += 1
 room.initial_controller.refresh(); room.initial_hud.p1_choice.pressed.emit()
 check(room.initial_controller.last_result.accepted and sim.hero.ranks.passive == 1 and model.state.points == 0,"labelled extra one-SP fixture learns P1 through actual button")
 check(session.open_panel().accepted,"real preparation shop opens")
 var quote: Dictionary = model.commerce_quote("base:B09")
 check(quote.accepted and int(quote.charge) == 500,"actual B09 retains 500-gold price")
 var args: Dictionary = quote.get("token",{}).duplicate(true); args["item"] = "base:B09"
 var purchase: Dictionary = session.submit("e3-b09-explicit-funding-fixture","buy",args)
 check(purchase.accepted and model.state.gold == 0 and model.state.inventory.size() == 1 and model.state.inventory[0].id == "base:B09","real B09 debit and inventory receipt")
 near(sim.hero.lifesteal(),0.04,"purchased B09 projects actual four-percent lifesteal")
 check(session.close_panel().accepted,"same shop closes")
 if route_enter(room,1,"r01a"):
  var router = room.input_router
  sim.hero.position = Vector3.ZERO
  for index in range(sim.enemies.size()):
   sim.enemies[index].position = Vector3(30+index,0,30); sim.enemies[index].state = "chase"
  if not check(not sim.enemies.is_empty(),"ordinary encounter supplies actual original target"): session.close_run(); live_session = null; room.free(); return
  var enemy: Dictionary = sim.enemies[0]
  enemy.position = Vector3(-2,0,0); enemy.hp = 10000.0; enemy.defence = 0.0; enemy.radius = 0.25
  sim.hero.hp = sim.hero.stats.max_hp-100.0
  var before_hp: float = sim.hero.hp
  active_group = REQUIRED[4]
  check(router.handle_event(key(KEY_E),Vector3(-2,0,0)).accepted,"real ordinary E-down places A at current point")
  var frame: Dictionary = sim.ink_frames; var id: int = int(frame.cast_id)
  near(sim.hero.cooldowns.e,0.0,"ordinary first A starts no CD")
  room.frontdoor_suspend(); room.frontdoor_resume()
  check(not router.handle_event(key(KEY_E),Vector3(2,0,0)).accepted and is_same(frame,sim.ink_frames),"menu Continue cannot convert held E into B")
  room.frontdoor_suspend(); var echo_up: InputEventKey = key(KEY_E,false); echo_up.echo = true
  check(not room.frontdoor_observe_e1_release(echo_up).accepted and router.e3_input_snapshot().release_required,"echo keyup cannot clear actual menu latch")
  var at: float = sim.hero_time; var deadline: float = frame.expires_at
  room.frontdoor_observe_e1_release(key(KEY_E,false)); sim.step(0.5)
  check(not router.e3_input_snapshot().release_required and is_same(frame,sim.ink_frames),"actual menu keyup only releases physical ownership")
  near(sim.hero_time,at,"menu keyup leaves source time frozen"); near(frame.expires_at,deadline,"menu preserves original A deadline")
  room.frontdoor_resume()
  check(router.handle_event(key(KEY_E),Vector3(2,0,0)).accepted and sim.ink_e3_finished.size() == 1 and sim.ink_e3_finished[0].cast_id == id,"new physical E-down legally confirms B on original A root")
  point(enemy.position,Vector3(2,0,0),"ordinary E3 actually exchanges original enemy")
  router.handle_event(key(KEY_E,false)); router.suspend_input("explicit-gui-boundary")
  router.observe_blocked_e3_down(key(KEY_E))
  check(not router.handle_event(key(KEY_E),Vector3(-2,0,0)).accepted and router.e3_input_snapshot().release_required,"GUI-blocked down cannot become fresh E after modal closes")
  router.queue_owned_boundary_e_up(key(KEY_E,false))
  check(not router.e3_input_snapshot().release_required,"genuine GUI-boundary up drains held E3 latch")
  done_group(REQUIRED[4])
  active_group = REQUIRED[5]
  var records: Array = p1_receipts(sim,id); var heals: Array = life_receipts(sim,id)
  if check(records.size() == 1 and heals.size() == 1,"ordinary complete single-target E3 pays P1 and B09 heal once"):
   var item: Dictionary = records[0]; var heal: Dictionary = heals[0]
   var basis: float = 0.0
   for hit: Dictionary in sim.ink_e3_receipts:
    if int(hit.cast_id) == id: basis += float(hit.actual_damage)
   check(item.qualified and item.distinct_targets == 1,"ordinary P1 sees exact original single enemy")
   near(item.final_basis,basis,"ordinary P1 basis equals actual complete E3 damage")
   near(item.actual_supplement,basis*0.12,"ordinary P1 supplements final damage once")
   near(item.cooldown_after,float(item.cooldown_before)*0.95,"ordinary P1 refunds remaining CD once")
   near(heal.lifesteal_rate,0.04,"E3 supplement snapshots real purchased B09 rate")
   near(heal.source_factor,0.4,"E3 supplement retains original area lifesteal factor")
   near(heal.actual_heal,float(item.actual_supplement)*0.04*0.4,"B09 applies actual supplemental heal")
   near(sim.hero.hp-before_hp,(basis+float(item.actual_supplement))*0.04*0.4,"base E3 and P1 heal share original health owner")
  check(session._owner_intact() and is_same(sim.progression,session.ledger),"E3/P1/B09 preserves sole Session owner")
  observations.ordinary_b09 = {"purchase":purchase,"p1":records.duplicate(true),"lifesteal":heals.duplicate(true)}
  done_group(REQUIRED[5])
  active_group = REQUIRED[6]
  finish_fixture_combat(room,sim)
  if route_enter(room,2,"r02a"):
   finish_fixture_combat(room,sim)
   sim.hero.hp = 123.0; sim.observe_pending_health(); sim.hero.cooldowns.e = 9.0
   var owner_id: int = session.ledger.get_instance_id(); var flasks: int = model.state.shop_visit.flask_charges
   if route_enter(room,3,"r03a"):
    room._refresh_session_controls(true)
    check(sim.hero.hp == sim.hero.stats.max_hp and sim.hero.cooldowns.e == 0.0 and session.rest_service.snapshot().size() == 1,"actual committed rest restores current E3 health and cooldown")
    check(session.ledger.get_instance_id() == owner_id and session._owner_intact() and model.state.shop_visit.flask_charges == flasks,"rest retains exact owner and never refills base bottle")
    check(sim.ink_frames.is_empty() and sim._p1_e3_frames.is_empty() and sim._p1_e3_terminal_frames.is_empty() and sim._p1_e3_packet_frames.is_empty() and sim._qe_jump_history.is_empty(),"room/rest cleanup retires all E3 roots, packet frames and jump history")
    check(room.session_hint.text.contains(room.REST_SETTLED_TEXT),"actual ordinary rest control reports committed effect")
    done_group(REQUIRED[6])
 session.close_run(); sim.combat_event.disconnect(on_event); sim.encounter_finished.disconnect(on_terminal)
 live_session = null; room.free()

func run() -> void:
 input_clocks_and_intents(); atomic_landing(); terminal_authenticity(); dual_pause_resume()
 q2_jumps_and_barrier(); h12_and_catalog(); current_mechanism_regressions()
 await ordinary_route()
 active_group = "report_integrity"
 for group: String in REQUIRED: check(group in groups,"required group completed: "+group)
 check(groups.size() == 7,"exactly seven affected groups")
 check(event_errors.is_empty(),"ordinary health/reward event authority accepted all relevant events")
 check(not output_path.is_empty() and not FileAccess.file_exists(output_path),"fresh explicit report path required via argument or INK_E3_ORDINARY_REPORT")
 var report: Dictionary = {"suite":"ink_e3_ordinary_finite_20261006","passed":errors.is_empty(),"checks":checks,"check_count":checks,"groups":groups,"completed":groups,"required_groups":REQUIRED,"group_checks":group_checks,"errors":errors,"failures":errors,"event_errors":event_errors,"observations":observations,"output_path":output_path,"binding":FileAccess.get_sha256(Binding.BINDING_PATH),"source_binding_sha256":FileAccess.get_sha256(Binding.BINDING_PATH),"gate_sha256":FileAccess.get_sha256(get_script().resource_path),"native_input":false,"natural_progression":false,"full_floor":false,"historical_matrices_rerun":false,"old_full_matrices_rerun":false,"H11_H12_ordinary_enabled":false,"art_audio_accepted":false,"B09_fixture_gold":500,"extra_P1_fixture_SP":1,"synthetic_q2_intervals":true,"H12_mechanism_fixture_only":true,"H11_H12_ordinary_offered":false,"temporary_visuals_only":true,"unpassed":["native_input","natural_progression","full_floor_Boss","final_art_audio_performance","H11_H12_ordinary_admission","H04_discontinuity_sampling"]}
 if not output_path.is_empty() and not FileAccess.file_exists(output_path):
  var file := FileAccess.open(output_path,FileAccess.WRITE)
  if file == null: errors.append("result_write_failed"); report.passed = false
  else: file.store_string(JSON.stringify(report,"  ")); file.close()
 print("INK_E3_ORDINARY_REPORT ",JSON.stringify(report))
 quit(0 if report.passed else 1)
