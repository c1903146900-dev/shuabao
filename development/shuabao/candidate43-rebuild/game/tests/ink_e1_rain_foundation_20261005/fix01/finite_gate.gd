extends SceneTree
## Main-owned finite mechanic gates. Authored only: NOT_RUN until main executes.
const Sim = preload("res://tests/ink_e1_rain_foundation_20261005/fix01/ink_e1_sim.gd")
const Before = preload("res://tests/ink_q3_foundation_20261004/fix02/ink_q3_sim.gd")
const Adapter = preload("res://tests/ink_e1_rain_foundation_20261005/fix01/input_adapter.gd")
const NormalCatalog = preload("res://tests/ink_q3_input_growth_20261004/catalog.gd")
const NormalBinding = preload("res://tests/ink_q3_input_growth_20261004/live_binding.gd")
const Actor = preload("res://scripts/actors/hero_model_core.gd")
var checks: int = 0
var failures: Array = []
var completed: Array = []
var observations: Dictionary = {}
const REQUIRED = ["source_all_ranks", "actor_identity", "admission", "held_release", "suspend_recovery", "h02_remainder", "h02_split_pull", "swept_marks", "radius_identity", "clocks", "damage_reduction", "h07_cleanse", "h08_damage_only", "shift_identity", "q1_preview", "six_common", "speed_layers", "bounded_inherited", "owned_callbacks"]
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok: failures.append(label); push_error(label)
func near(a: float, b: float, label: String, tolerance: float = .00001) -> void:
 check(is_finite(a) and absf(a - b) <= tolerance, "%s: %.9f expected %.9f" % [label, a, b])
func fresh(rank: int = 1, ids: Array = [], before: bool = false):
 var sim = Before.new() if before else Sim.new()
 root.add_child(sim); sim.auto_finish = false; sim.ai_enabled = false; sim.arena_half_extent = 100.0
 sim.hero.position = Vector3.ZERO; sim.hero.loadout.e = "e1"; sim.hero.ranks.e = rank
 sim.hero.loadout.q = "q1"; sim.hero.ranks.q = 1
 sim.hero.stats.ap = 100.0; sim.hero.stats.crit_chance = 0.0; sim.hero.stats.regen = 0.0; sim.hero.stats.defence = 0.0
 sim.begin_encounter("rain-finite", []); sim.set_hexes(ids)
 return sim
func target(sim, at: Vector3, kind: String = "minion", hp: float = 100000.0) -> Dictionary:
 var enemy: Dictionary = sim.spawn_enemy(kind, at, hp)
 enemy.state = "chase"; enemy.defence = 0.0; enemy.radius = .25
 return enemy
func enter(sim) -> Dictionary:
 var out: Dictionary = sim.request_action("e")
 check(out.accepted, "E1 accepted effect entry")
 return out
func events(sim, kind: String) -> Array: return sim.event_log.filter(func(e): return e.kind == kind)
func key(code: int, down: bool = true, echo: bool = false) -> InputEventKey:
 var event = InputEventKey.new(); event.physical_keycode = code; event.pressed = down; event.echo = echo
 return event
func run() -> void:
 test_source_all_ranks(); test_actor_identity(); test_admission(); test_held_release(); test_suspend_recovery(); test_h02_remainder(); test_h02_split_pull(); test_swept_marks(); test_radius_identity(); test_clocks(); test_damage_reduction(); test_h07_cleanse(); test_h08_damage_only(); test_shift_identity(); test_q1_preview(); test_six_common(); test_speed_layers(); test_bounded_inherited(); test_owned_callbacks()
 for label in REQUIRED: check(label in completed, "completed required case " + label)
 var report: Dictionary = {"suite":"ink_e1_rain_finite_mechanics", "passed":failures.is_empty(), "checks":checks, "failures":failures, "completed":completed, "observations":observations, "source_binding_id":FileAccess.get_sha256("res://tests/ink_e1_rain_foundation_20261005/fix01/source_binding.json"), "scope":"isolated mechanics only; no host, production, OS input, art or balance acceptance", "unpassed":{"ordinary_only_phasing_distinction":"PENDING_TECHNICAL_REVIEW: inherited movement has no unit collisions", "normal_host":"NOT_ENABLED", "G25_G29_replay":"OUTSIDE_CAPABILITY"}}
 var file = FileAccess.open("res://tests/ink_e1_rain_foundation_20261005/fix01/finite_result.json", FileAccess.WRITE)
 file.store_string(JSON.stringify(report, "  ")); file.close()
 print("INK_E1_FINITE_REPORT ", JSON.stringify(report)); quit(0 if failures.is_empty() else 1)

func test_source_all_ranks() -> void:
 var values: Dictionary = {"E1-1":[2.5,2.54,2.6,2.7,2.83,3.0], "E1-2":[70,71,72,74,77,80], "E1-3":[35,37,39,43,48,55], "E1-4":[1,1,1,1,1,1], "E1-5":[2.5,2.57,2.68,2.86,3.1,3.4], "E1-6":[40,53,72,104,147,200], "E1-7":[55,58,63,71,82,95], "E1-8":[20,27,38,56,80,110], "E1-9":[30,32,36,42,50,60], "E1-10":[17,16.72,16.3,15.6,14.65,13.5]}
 for rank in range(1,7):
  var sim = fresh(rank)
  for token in values: near(sim.v(token, rank), float(values[token][rank-1]), "original XLSX rank %d %s" % [rank,token])
  var enemy: Dictionary = target(sim, Vector3(.5,0,0)); var hp: float = enemy.hp
  var base_speed: float = sim.hero.speed(); var root_cast: Dictionary = enter(sim)
  near(sim.ink_rain.expires_at - sim.ink_rain.born_at, float(values["E1-1"][rank-1]), "source duration")
  near(sim.hero.cooldowns.e, float(values["E1-10"][rank-1]), "one cooldown on effect entry")
  near(sim.hero.speed(), base_speed * (1.0 + float(values["E1-3"][rank-1])*.01), "derived move speed, not base stat rewrite")
  sim.hero.move_intent = Vector3.RIGHT; sim.step(.02); sim.hero.move_intent = Vector3.ZERO
  check(sim.ink_rain.marks.has(enemy.actor_id), "actual motion creates rank mark")
  near(enemy.hp, hp, "mark itself has no damage packet")
  var cd: float = sim.hero.cooldowns.e
  var out: Dictionary = sim.request_action("e_release")
  check(out.accepted and out.cast_id == root_cast.cast_id, "release shares original E root")
  near(hp-enemy.hp, float(values["E1-6"][rank-1])+float(values["E1-7"][rank-1])+float(values["E1-8"][rank-1])+float(values["E1-9"][rank-1]), "two rank damage channels")
  near(sim.hero.cooldowns.e, cd, "release does not reset cooldown")
  near(sim.hero.speed(), base_speed, "reform removes only temporary speed")
  check(sim.ink_rain.is_empty() and sim._casts[root_cast.cast_id].finished and sim.ink_e1_receipts.size() == 2, "single completion after both segments")
  check(sim.ink_e1_receipts[0].segment_id != sim.ink_e1_receipts[1].segment_id, "base and bonus distinct dedup identities")
  check(sim.ink_e1_finished[0].hit_target_ids.size() == 1, "future whole-cast distinct targets unify both channels")
  sim.free()
 completed.append("source_all_ranks")

func actor_fields(actor, keys: Array) -> Dictionary:
 var out: Dictionary = {}
 for name in keys:
  var value: Variant = actor.get(name)
  out[name] = value.duplicate(true) if value is Dictionary or value is Array else value
 return out
func test_actor_identity() -> void:
 var baseline = Before.new(); var candidate = Sim.new()
 var keys: Array = []
 for property in baseline.hero.get_property_list():
  if (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0 and str(property.name) != "script": keys.append(str(property.name))
 check(not keys.is_empty(), "original ActorCore full field inventory found")
 check(actor_fields(baseline.hero,keys)==actor_fields(candidate.hero,keys), "constructor specialization preserves every original ActorCore state field")
 check(not is_same(baseline.hero.base_stats,candidate.hero.base_stats) and not is_same(baseline.hero.cooldowns,candidate.hero.cooldowns), "constructor values equal without sharing mutable actor state")
 check(candidate.hero.rain_speed_bonus==0.0, "only added actor field is inert at birth")
 check(baseline.common.context_values==candidate.common.context_values and baseline.common.runtime.snapshot()==candidate.common.runtime.snapshot() and baseline.common.runtime.rng.state==candidate.common.runtime.rng.state, "constructor local bridge preserves initial context/runtime/RNG")
 check(candidate.common.sim()==candidate and candidate.common.model==null and candidate._equipment_health_owner==null, "constructor before any bridge/model/health binding, live bridge resolves new actor through same Sim")
 root.add_child(baseline); root.add_child(candidate)
 for sim in [baseline,candidate]:
  sim.auto_finish=false; sim.ai_enabled=false
  sim.begin_encounter("cleanup-compare",[])
  sim.hero.stun_left=.8; sim.hero.slow_left=.5; sim.hero.slow_amount=.4
  sim.hero.lock_time=.3; sim.hero.movement_lock_left=.2
  sim.hero.dash_left=.1; sim.dash_iframe_left=.1
  sim.end_encounter("cancelled")
 check(actor_fields(baseline.hero,keys)==actor_fields(candidate.hero,keys), "cleanup preserves every original field, no independent HP/stat/control state")
 observations.actor_field_names=keys
 baseline.free(); candidate.free(); completed.append("actor_identity")

func test_admission() -> void:
 var sim = fresh(0)
 check(not sim.request_action("e").accepted and sim.cast_serial == 0, "unlearned E rejects before root")
 sim.hero.ranks.e = 1; sim.hero.stun_left = .5
 check(sim.request_action("e").reason == "controlled", "controlled base E rejected")
 sim.hero.stun_left = 0.0; sim.hero.cooldowns.e = 1.0
 check(sim.request_action("e").reason == "cooldown", "E entry cooldown respected")
 sim.hero.cooldowns.e = 0.0; sim.source_rules_hash = "invalid"
 check(sim.request_action("e").reason == "source_binding_mismatch", "E entry source mismatch")
 sim.source_rules_hash = sim.EXPECTED_RULES_HASH; sim.paused = true
 check(not sim.request_action("e").accepted, "paused entry frozen")
 sim.paused = false; enter(sim)
 for action in ["attack","q","r"]: check(sim.request_action(action, Vector3(6,0,0)).reason == "rain_form_forbids_action", "form rejects new " + action)
 var serial: int = sim.cast_serial
 check(not sim.request_action("e").accepted and sim.cast_serial == serial, "repeat E never new root")
 check(not NormalBinding.read_capabilities(sim, true).accepted, "old normal binding rejects new exact-script candidate")
 check("E1" not in NormalCatalog.FIRST_SLICE_ALLOWED_CANDIDATES, "frozen normal catalog remains Q1/Q3 only")
 for hook in ["hex.final_design.yanguizhou_h07.v1","hex.final_design.yanguizhou_h08.v1","hex.final_design.common_g25.v1","hex.final_design.common_g29.v1","hex.final_design.common_g18.v1"]: check(hook not in NormalCatalog.FIRST_SLICE_HEX_HOOKS, "not silently admitted " + hook)
 sim.free(); completed.append("admission")

func test_held_release() -> void:
 var sim = fresh(); var router = Adapter.new(); router.bind(sim)
 check(not router.handle_event(key(KEY_E,false)).accepted, "unpaired E-up cannot burst")
 check(router.handle_event(key(KEY_E)).accepted, "physical E-down enters")
 var cast_id: int = sim.ink_rain.cast_id
 check(not router.handle_event(key(KEY_E,true,true)).accepted and not router.handle_event(key(KEY_E)).accepted, "E echo and duplicate down blocked")
 sim.step(.1); check(not sim.ink_rain.is_empty() and sim.ink_e1_receipts.is_empty(), "held E does not auto-release before duration")
 sim.paused = true
 check(router.handle_event(key(KEY_E,false)).accepted and sim.ink_rain.release_pending, "actual paused E-up retained as intent")
 sim.step(.5); check(not sim.ink_rain.is_empty(), "paused intent cannot advance form or damage")
 sim.paused = false; sim.step(.02)
 check(sim.ink_rain.is_empty() and sim.ink_e1_finished.size() == 1 and sim.ink_e1_finished[0].cast_id == cast_id, "queued up settles once upon resume")
 check(not router.handle_event(key(KEY_E,false)).accepted, "repeat E-up harmless")
 sim.free(); completed.append("held_release")

func test_suspend_recovery() -> void:
 var sim=fresh(); var router=Adapter.new(); router.bind(sim)
 check(router.handle_event(key(KEY_E)).accepted,"focus fixture initial physical pair")
 var cast_id:int=sim.ink_rain.cast_id; var deadline:float=sim.ink_rain.expires_at; var at:float=sim.hero_time
 router.focus_lost()
 check(not router._e_physical and router._e_cast.cast_id==cast_id,"focus loss unlocks physical latch while retaining exact live ownership")
 check(sim.ink_rain.cast_id==cast_id and sim.ink_rain.expires_at==deadline and not sim.ink_rain.release_pending,"focus loss neither synthesizes release nor changes source timer")
 near(sim.hero_time,at,"focus loss does not advance clock")
 sim.step(18.0)
 check(sim.ink_rain.is_empty() and sim.ink_e1_finished.size()==1 and sim.cast_serial==cast_id,"lost E-up naturally expires once and never auto-recasts")
 check(router.handle_event(key(KEY_E)).accepted and sim.ink_rain.cast_id!=cast_id,"fresh physical down after lost-up/expiry/cooldown recovers")
 check(router.handle_event(key(KEY_E,false)).accepted,"recovered fresh pair releases normally")
 sim.free()
 sim=fresh(); router=Adapter.new(); router.bind(sim); router.handle_event(key(KEY_E)); cast_id=sim.ink_rain.cast_id
 sim.paused=true; router.suspend_input("modal")
 check(router.handle_event(key(KEY_E,false)).accepted and sim.ink_rain.release_pending,"genuine late E-up after suspension still queues its same live cast")
 sim.step(.5); check(not sim.ink_rain.is_empty(),"late paused E-up still cannot run paused damage")
 sim.paused=false; sim.step(.02)
 check(sim.ink_rain.is_empty() and sim.ink_e1_finished.size()==1 and sim.ink_e1_finished[0].cast_id==cast_id,"late real up settles once on resume")
 sim.free()
 sim=fresh(); router=Adapter.new(); router.bind(sim); router.handle_event(key(KEY_E)); cast_id=sim.ink_rain.cast_id; router.focus_lost()
 check(not router.handle_event(key(KEY_E)).accepted and router._e_cast.cast_id==cast_id and sim.cast_serial==cast_id,"fresh down during surviving form creates no cast and retains original ownership")
 check(router.handle_event(key(KEY_E,false)).accepted,"real up after rejected surviving-form down releases original pair")
 sim.free()
 sim=fresh(); router=Adapter.new(); router.bind(sim); router.handle_event(key(KEY_E)); router.focus_lost(); sim.end_encounter("cancelled"); sim.begin_encounter("later-room",[])
 sim.hero.cooldowns.e=0.0; enter(sim); cast_id=sim.ink_rain.cast_id
 check(not router.handle_event(key(KEY_E,false)).accepted and sim.ink_rain.cast_id==cast_id,"stale late E-up cannot release another epoch/root")
 sim.free(); completed.append("suspend_recovery")

func test_h02_remainder() -> void:
 var sim=fresh(1,["yanguizhou_h02"])
 sim.hero.position=Vector3(1,0,0)
 var enemy:Dictionary=target(sim,Vector3(1.901,0,0)); var before:Vector3=enemy.position
 check(draw(sim,Vector3(-.24,0,0),Vector3.ZERO).accepted,"real short Q1 commits before E1")
 enter(sim); var count:int=sim.ink_core_steps
 sim.step(.02)
 check(sim.ink_core_steps-count==1,"H02 observation never adds a world tick")
 check(sim.ink_vortices.size()==1 and not events(sim,"ink_h02_pull").is_empty(),"real Q1 endpoint creates and moves newborn H02 remainder")
 near(enemy.position.x,1.871,"H02 moves only source3m/s times .01s endpoint remainder")
 check(before.distance_to(sim.hero.position)>.9 and enemy.position.distance_to(sim.hero.position)<.9,"actual H02 leg crosses rain body boundary")
 check(sim.ink_rain.marks.has(enemy.actor_id) and sim.ink_e1_marks.size()==1,"newborn H02 remainder receives exactly one real rain mark")
 near(enemy.hp,100000.0,"newborn pull crossing adds no damage")
 near(sim.hero.position.x,1.0,"H02 observer does not move hero")
 sim.free(); completed.append("h02_remainder")

func test_h02_split_pull() -> void:
 var sim=fresh(1,["yanguizhou_h02"])
 check(draw(sim,Vector3(1,0,-1.24),Vector3(1,0,-1)).accepted,"bent-leg fixture creates real Q1 endpoint vortex")
 sim.step(.02)
 var enemy:Dictionary=target(sim,Vector3(-1,0,1)); enter(sim)
 var span:float=2.0/3.0
 enemy.pull_state={"origin":Vector3(-1,0,1),"destination":Vector3(1,0,1),"left":span,"duration":span,"generation":sim.encounter_generation,"room_id":sim.room_id}
 # Explicit local method fixture, not an extra world tick: one inherited pull
 # then its H02 leg. Each actual segment stays 1m from the stationary hero;
 # their false combined diagonal would intersect the hero at the origin.
 sim._h02_tick_start=sim.hero_time; sim._h02_frame_active=true; sim.hero_time+=span
 var core_steps:int=sim.ink_core_steps
 sim._step_pull(enemy,span); sim._h02_frame_active=false
 near(enemy.position.distance_to(Vector3(1,0,-1)),0.0,"inherited pull and H02 commit two bent source legs")
 check(sim.ink_e1_marks.is_empty() and sim.ink_rain.marks.is_empty(),"two legal noncrossing legs never create an aggregate-chord rain mark")
 check(sim.ink_core_steps==core_steps and sim._rain_pull_capture.is_empty(),"local observation leaves clock cadence and capture ownership intact")
 near(sim.hero.position.length(),0.0,"split pull observation never moves hero")
 sim.free(); completed.append("h02_split_pull")

func test_swept_marks() -> void:
 var sim = fresh(); var enemy: Dictionary = target(sim, Vector3(3,0,0)); var hp: float = enemy.hp
 enter(sim); sim.move_during_hitstop(.8, Vector3.RIGHT)
 check(sim.hero.position.x > 6.0 and sim.ink_rain.marks.has(enemy.actor_id), "sweep catches crossed enemy missed by both endpoints")
 near(enemy.hp, hp, "crossing deals zero damage")
 sim.move_during_hitstop(.8, Vector3.LEFT)
 check(sim.ink_e1_marks.size() == 1 and sim.ink_rain.marks[enemy.actor_id].count == 1, "retrace marks once per enemy per cast")
 sim.request_action("e_release")
 check(sim.ink_e1_finished[0].cleared_mark_target_ids.has(enemy.actor_id), "all cast marks cleared including outside final radius")
 near(enemy.hp, hp, "marked outside final radius gets no distant damage")
 sim.free()
 sim = fresh(); enemy = target(sim, Vector3(3,0,0)); enter(sim)
 sim.obstacles = [{"position":Vector3(1.8,0,0), "half":Vector3(.1,0,1)}]
 sim.move_during_hitstop(.8, Vector3.RIGHT)
 check(sim.hero.position.x < 1.06 and not sim.ink_rain.marks.has(enemy.actor_id), "real wall-clipped path cannot mark through wall")
 sim.free()
 sim=fresh(); enemy=target(sim,Vector3(3,0,0)); enter(sim)
 sim.push_enemy(enemy,Vector3.LEFT,6.0,"fixture_transport",0,0.0,.1,0.0)
 sim.step(.1)
 check(sim.ink_rain.marks.has(enemy.actor_id) and sim.ink_e1_marks.size()==1, "actual moving enemy sweeps stationary hero once under inherited phase order")
 near(sim.hero.position.length(),0,"enemy motion does not invent hero movement")
 near(enemy.hp,100000.0,"relative crossing adds no damage")
 sim.free(); completed.append("swept_marks")

func test_radius_identity() -> void:
 var sim = fresh()
 var marked: Dictionary = target(sim, Vector3(1,0,0)); var unmarked: Dictionary = target(sim, Vector3(1.5,0,1.5)); var far: Dictionary = target(sim, Vector3(5,0,0))
 enter(sim); sim.move_during_hitstop(.2,Vector3.RIGHT)
 var state: Dictionary = sim.ink_rain
 check(state.marks.has(marked.actor_id) and not state.marks.has(unmarked.actor_id), "crossed subset differs from radius batch")
 sim.request_action("e_release")
 near(100000.0-marked.hp,145.0,"marked inside base plus bonus")
 near(100000.0-unmarked.hp,95.0,"unmarked inside base only")
 near(far.hp,100000.0,"outside no damage")
 check(state.marks.is_empty(),"retired object itself retains no marks")
 sim.free()
 sim=fresh(); marked=target(sim,Vector3(.5,0,0)); enter(sim); sim.move_during_hitstop(.02,Vector3.RIGHT)
 var replacement: Dictionary = marked.duplicate(true); sim.enemies[0] = replacement
 sim.request_action("e_release")
 near(100000.0-replacement.hp,95.0,"replacement with reused ID receives base only, never stale mark bonus")
 sim.free()
 for kind in ["elite","boss"]:
  sim=fresh(); var enemy:Dictionary=target(sim,Vector3(.5,0,0),kind); enter(sim); sim.request_action("e_release")
  near(100000.0-enemy.hp,95.0,"no invented base damage exclusion for "+kind)
  sim.free()
 completed.append("radius_identity")

func test_clocks() -> void:
 var sim = fresh(5,["yanguizhou_h08"]); enter(sim)
 var deadline:float=sim.ink_rain.expires_at; var source_time:float=sim.hero_time; var cd:float=sim.hero.cooldowns.e; var core_steps:int=sim.ink_core_steps
 sim.paused=true; sim.step(.5); sim.move_during_hitstop(.5,Vector3.RIGHT)
 near(sim.hero_time,source_time,"pause freezes source clock"); near(sim.hero.position.length(),0,"pause freezes movement")
 sim.paused=false; sim.move_during_hitstop(.1,Vector3.RIGHT)
 near(sim.hero_time,source_time,"hitstop freezes form/H08 clock"); near(sim.hero.cooldowns.e,cd,"hitstop freezes E cooldown")
 check(sim._e1_guard_current() and sim.hero.position.x>0,"hitstop retains guard but permits real walking")
 sim.hero.position=Vector3.ZERO; sim.hero.move_intent=Vector3.RIGHT; sim.step(2.84)
 check(sim.ink_core_steps-core_steps==142,"one inherited fixed step per .02, no E double tick")
 check(sim.ink_rain.is_empty() and sim.ink_e1_finished.size()==1,"rank5 partial-tick deadline releases once")
 near(sim.ink_e1_finished[0].finished_at,deadline,"exact 2.83 source deadline")
 near(sim.ink_e1_finished[0].position.x,6.0*1.48*2.83,"burst anchored at exact within-tick deadline location",.0001)
 near(sim.hero.position.x,6.0*1.48*2.83+6.0*.01,"remainder walks at base speed after reformation",.0001)
 sim.free()
 sim=fresh(); enter(sim); sim.clock.enter("other",1.0); sim.step(.2)
 check(sim.hero_time<.2 and not sim.ink_rain.is_empty(),"form follows inherited slowed hero clock")
 sim.free(); completed.append("clocks")

func test_damage_reduction() -> void:
 for rank in range(1,7):
  for is_true in [false,true]:
   var sim=fresh(rank); enter(sim); var hp:float=sim.hero.hp
   sim.damage_hero(100.0,Vector3.RIGHT,0.0,is_true)
   near(hp-sim.hero.hp,100.0*(1.0-sim.v("E1-2",rank)*.01),"source final DR rank/type")
   sim.request_action("e_release"); hp=sim.hero.hp; sim.damage_hero(10.0,Vector3.RIGHT,0.0,is_true)
   near(hp-sim.hero.hp,10.0,"DR ends with form")
   sim.free()
 completed.append("damage_reduction")

func test_h07_cleanse() -> void:
 var sim=fresh(1,["yanguizhou_h07"]); sim.hero.stun_left=.8; sim.hero.slow_left=2.0; sim.hero.slow_amount=.6; sim.hero.knockback=Vector3.RIGHT
 enter(sim)
 near(sim.hero.stun_left,0,"H07 one-time existing control cleanse"); near(sim.hero.slow_left,0,"H07 clears existing slow timer"); near(sim.hero.slow_amount,0,"H07 clears existing slow value")
 check(sim.hero.knockback==Vector3.ZERO and not sim.hero_control_immune(),"H07 no persistent control immunity")
 sim.damage_hero(10,Vector3.RIGHT,.4); check(sim.hero.stun_left>.39,"new legal control applies during H07 form")
 var before:Vector3=sim.hero.position; sim.hero.move_intent=Vector3.RIGHT; sim.step(.2)
 near(sim.hero.position.distance_to(before),0,"new control blocks form walking")
 check(sim.request_action("e_release").accepted,"controlled existing form still responds to physical release")
 sim.free(); completed.append("h07_cleanse")

func test_h08_damage_only() -> void:
 for ids in [["yanguizhou_h08"],["yanguizhou_h07","yanguizhou_h08"]]:
  for is_true in [false,true]:
   var sim=fresh(1,ids); enter(sim); var hp:float=sim.hero.hp
   sim.add_shield("fixture_shield",50.0,3.0)
   sim.damage_hero(100.0,Vector3.RIGHT,.4,is_true)
   near(sim.hero.hp,hp,"H08 ordinary/true prevents HP loss"); near(sim.hero.shield_total(),50.0,"H08 before shield absorption")
   check(sim.hero.stun_left>.39 and not sim.hero_control_immune() and not sim.hero_damage_immune(),"H08 combined attack still controls, no blanket immune flag")
   near(sim.hero.invulnerable_left,0,"H08 never borrows Shift/actor iframe field")
   check(sim.request_action("e_release").accepted and sim._e1_guard_current(),"early release does not shorten entry-based H08 second")
   sim.hero.shields.clear(); sim.damage_hero(100,Vector3.RIGHT,0,is_true); near(sim.hero.hp,hp,"H08 persists after early reformation")
   sim.step(1.0); sim.damage_hero(10,Vector3.RIGHT,0,is_true); near(hp-sim.hero.hp,10.0,"H08 ends at one source second")
   sim.free()
 var sim=fresh(1,["yanguizhou_h08"]); sim.hero.stun_left=.5
 check(not sim.request_action("e").accepted and sim.hero.stun_left==.5,"H08 alone neither controlled entry nor cleanse")
 sim.free(); completed.append("h08_damage_only")

func test_shift_identity() -> void:
 var sim=fresh(1,["yanguizhou_h08"]); var rain:Dictionary=enter(sim); var expires:float=sim.ink_rain.expires_at
 var dash:Dictionary=sim.request_action("shift",Vector3(10,0,0))
 check(dash.accepted and dash.cast_id!=rain.cast_id,"Shift permitted and distinct root")
 near(sim.hero.cooldowns.shift,4.0,"source Shift CD unchanged"); near(sim.dash_iframe_left,.2,"source Shift iframe unchanged")
 check(sim.hero_control_immune(),"actual Shift independently protects control")
 sim.move_during_hitstop(.25,Vector3.ZERO)
 near(sim.hero.position.x,4.5,"Shift distance not multiplied by rain speed")
 near(sim.hero_time,0,"Shift real clock does not age rain source timer"); near(sim.ink_rain.expires_at,expires,"Shift cannot reset form deadline")
 check(sim._casts[dash.cast_id].finished and not sim._casts[rain.cast_id].finished,"Shift finishes only own root")
 near(sim.hero.shield_total(),0,"Shift adds no shield")
 check(not sim.hero_control_immune() and sim._e1_guard_current(),"H08 remains independently damage-only after Shift iframe")
 sim.request_action("e_release"); check(sim._casts[rain.cast_id].finished,"rain completes independently")
 sim.free(); completed.append("shift_identity")

func draw(sim, start:Vector3, end:Vector3)->Dictionary:
 check(sim.request_ink_input("q_down").accepted,"Q1 armed")
 check(sim.request_ink_input("left_down",start).accepted,"Q1 drawing")
 sim.request_ink_input("motion",end)
 return sim.request_ink_input("left_up",end)
func test_q1_preview() -> void:
 var sim=fresh(); sim.request_ink_input("q_down"); sim.request_ink_input("left_down",Vector3.ZERO); sim.request_ink_input("motion",Vector3(4,0,0)); enter(sim)
 check(sim.ink_input.phase=="idle" and sim.ink_waves.is_empty(),"E entry retires uncommitted Q1 preview")
 check(not sim.request_ink_input("left_up",Vector3(4,0,0)).accepted and sim.ink_waves.is_empty(),"old LMB release cannot bypass E Q gate")
 sim.free()
 sim=fresh(); target(sim,Vector3(3,0,0)); check(draw(sim,Vector3.ZERO,Vector3(5,0,0)).accepted,"Q1 accepted before form")
 enter(sim); sim.step(.3)
 check(not events(sim,"ink_q1_contact").is_empty(),"already launched Q1 continues during E1")
 sim.free(); completed.append("q1_preview")

func test_six_common() -> void:
 var six:Array=["common_g01","common_g05","common_g06","common_g15","common_g24","common_g30"]
 var sim=fresh(1,six); sim.hero.stats.crit_chance=1.0; sim.common.refresh_stats(); var e:Dictionary=target(sim,Vector3(1,0,0)); var hp:float=e.hp
 var before_base:Dictionary=sim.hero.projected_base_stats.duplicate(true); var speed:float=sim.hero.speed(); var cd:float=sim.effective_cd(sim.common.base_cooldown("e",17.0))
 enter(sim); near(sim.hero.cooldowns.e,cd,"six-common cooldown via existing service")
 near(float(sim.common.context().hero.stats.move_speed),speed*1.35,"common G06 reads the same temporary speed attribute")
 sim.common.refresh_stats(); near(sim.hero.speed(),speed*1.35,"common refresh cannot erase/double rain speed")
 check(sim.hero.projected_base_stats==before_base,"temporary speed never changes stat ownership")
 sim.move_during_hitstop(.02,Vector3.RIGHT); sim.request_action("e_release")
 check(e.hp<hp-145.0,"legal common skill crit/modifiers are not suppressed")
 var damage:Array=events(sim,"damage").filter(func(event):return event.source=="e1")
 check(damage.size()==2 and damage.all(func(event):return not event.basic_attack and event.critical),"both E segments remain skill damage with common crit, never BASIC task credit")
 check(sim.common.runtime.debt.is_empty(),"unsupported G29 not activated by E1")
 sim.free()
 sim=fresh(1,["common_g05","common_g06","common_g15"])
 sim.common.runtime.cooldown_kills=int(sim.common.runtime.parameter("g05",2))-1
 var first:Dictionary=target(sim,Vector3(1,0,0),"minion",1.0)
 var survivor:Dictionary=target(sim,Vector3(1,0,1)); var initial_speed:float=sim.hero.speed()
 var g06_factor:float=1.0+minf(sim.common.runtime.parameter("g06",3)*.01,maxf(0.0,initial_speed-float(survivor.speed))/sim.common.runtime.parameter("g06",1)*sim.common.runtime.parameter("g06",2)*.01)
 enter(sim); sim.request_action("e_release")
 check(first.dead and sim.hero.speed()>initial_speed,"first area kill triggers existing G05/G15 projection")
 near(100000.0-survivor.hp,95.0*g06_factor,"same simultaneous E1 batch retains pre-kill G06 input")
 sim.free(); completed.append("six_common")

func test_speed_layers() -> void:
 var sim=fresh(1,["common_g15"])
 # Explicit projection-boundary fixture: current one-B08 result and 10% CDR.
 # The unmodified equipment consumer/ledger was separately inherited; this is
 # not a new commerce authority or a claim of normal-host equipment admission.
 sim.set_projected_stats({"move_speed":6.42,"cooldown_reduction":.1})
 near(float(sim.hero.projected_base_stats.move_speed),6.42,"one B08 fraction already projected exactly once")
 near(float(sim.hero.stats.move_speed),6.6768,"existing G15 common layer")
 sim.hero.slow_left=10.0; sim.hero.slow_amount=.2
 near(sim.hero.speed(),5.34144,"existing slow after common projection")
 enter(sim)
 near(sim.hero.speed(),7.210944,"existing-layer convention E1 after equipment/common/slow")
 near(float(sim.common.context().hero.stats.move_speed),7.210944,"common receives same derived speed")
 for i in range(3): sim.common.refresh_stats()
 near(sim.hero.speed(),7.210944,"refreshes never reapply equipment or bank temporary factor")
 near(float(sim.hero.projected_base_stats.move_speed),6.42,"temporary factor not baked into projected base")
 sim.move_during_hitstop(.02,Vector3.RIGHT)
 near(sim.hero.position.x,7.210944*.02,"walking uses same derived speed once")
 sim.request_action("e_release"); near(sim.hero.speed(),5.34144,"cleanup retains existing gear/common/slow")
 sim.free(); completed.append("speed_layers")

func test_bounded_inherited() -> void:
 var observations_pair:Array=[]
 for old in [true,false]:
  var sim=fresh(1,[],old); var enemy:Dictionary=target(sim,Vector3(3,0,0)); var hp:float=enemy.hp
  var q:Dictionary=draw(sim,Vector3.ZERO,Vector3(5,0,0)); sim.step(.5)
  var qdamage:float=hp-enemy.hp; sim.hero.cooldowns.attack=0.0; sim.hero.position=Vector3.ZERO
  var basic:Dictionary=sim.request_action("attack",Vector3(6,0,0)); sim.step(.3)
  var dash:Dictionary=sim.request_action("shift",Vector3(0,0,9)); sim.step(.3)
  sim.hero.loadout.q="q3"; sim.hero.ranks.q=1; sim.hero.cooldowns.q=0.0
  var raised:Dictionary=sim.request_action("q",Vector3(4,0,0)); var collapse:Dictionary=sim.request_action("q",Vector3(8,0,0))
  observations_pair.append({"Q1":q.accepted,"Q1_damage":qdamage,"BASIC":basic.accepted,"Shift":dash.accepted,"Q3_raise":raised.accepted,"Q3_collapse":collapse.accepted,"hp":sim.hero.hp,"world_time":sim.clock.world_time,"hero_time":sim.hero_time,"core_steps":sim.ink_core_steps,"position":sim.hero.position,"cooldowns":sim.hero.cooldowns.duplicate(true),"rng":sim.rng.state,"common_rng":sim.common.runtime.rng.state})
  sim.free()
 check(observations_pair[0]==observations_pair[1],"bounded exact Q1/BASIC/Shift/Q3 before-after mechanics, clocks, RNG and cooldowns")
 observations.inherited=observations_pair; completed.append("bounded_inherited")

func test_owned_callbacks() -> void:
 # Four finite owned boundaries only. No unbounded callback permutations.
 for trigger in ["ink_e1_entered","ink_e1_rain_marked","ink_e1_reform_started","ink_e1_contact"]:
  var sim=fresh(1,["yanguizhou_h08"]); target(sim,Vector3(.5,0,0))
  var observed:Dictionary={"fired":false,"transaction_active":false,"begin_result":{},"queued":false}
  sim.combat_event.connect(func(event:Dictionary):
   if event.kind==trigger and not observed.fired:
    observed.fired=true; observed.transaction_active=sim.transaction_active
    sim.end_encounter("cancelled")
    observed.begin_result=sim.begin_encounter("replacement-room",[])
    observed.queued=not bool(observed.begin_result.get("accepted",false)))
  enter(sim)
  if not sim.ink_rain.is_empty(): sim.move_during_hitstop(.02,Vector3.RIGHT)
  if not sim.ink_rain.is_empty(): sim.request_action("e_release")
  check(observed.fired,"owned callback reached "+trigger)
  if trigger=="ink_e1_rain_marked":
   check(not observed.transaction_active and observed.begin_result.get("accepted",false),"nontransaction mark callback may enter replacement immediately")
  else:
   check(observed.transaction_active and not observed.begin_result.get("accepted",true) and observed.begin_result.get("reason","")=="invalid_phase","request-action callback honors begin_encounter transaction rejection "+trigger)
   check(sim.phase=="cancelled" and not sim.transaction_active,"action unwinds after synchronous end, before replacement "+trigger)
  if observed.queued:
   check(sim.begin_encounter("replacement-room",[]).accepted,"queued room begins only after transaction unwinds "+trigger)
  check(sim.room_id=="replacement-room","replacement room reached via legal boundary "+trigger)
  check(sim.ink_rain.is_empty() and sim.ink_rain_guard.is_empty() and sim.ink_e1_receipts.is_empty() and sim.ink_e1_marks.is_empty(),"old timer/marks/receipts cannot enter replacement room "+trigger)
  near(sim.hero.speed(),6.0,"no temporary speed leakage after room callback")
  sim.free()
 var sim=fresh(1,["yanguizhou_h08"]); var out:Dictionary=enter(sim); sim.cancel_cast(out.cast_id)
 check(sim.ink_rain.is_empty() and sim.ink_rain_guard.is_empty(),"explicit root cancellation retires owned form and guard")
 sim.free()
 sim=fresh(); enter(sim); sim.damage_hero(100000.0,Vector3.ZERO,0,true,true)
 check(sim.hero.dead and sim.ink_rain.is_empty() and sim.ink_rain_guard.is_empty(),"actual death retires owned form/marks/timers")
 sim.step(4.0); check(sim.ink_e1_finished.is_empty(),"death cannot later create deadline burst")
 sim.free()
 sim=fresh(1,["yanguizhou_h08"]); enter(sim)
 var old_state:Dictionary=sim.ink_rain
 var replacement=Actor.new(); replacement.actor_id="replacement-fixture"; sim.hero=replacement
 sim.step(.02)
 check(sim.ink_rain.is_empty() and sim.ink_rain_guard.is_empty() and old_state.marks.is_empty(),"actor replacement retires only stale owned E timers and marks")
 check(sim.ink_e1_finished.is_empty() and not sim.request_action("e_release").accepted,"old actor identity cannot release a burst through replacement")
 sim.free(); completed.append("owned_callbacks")
