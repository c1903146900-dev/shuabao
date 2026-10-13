extends SceneTree
## Bounded combination evidence. Direct-rank/AI-state fixtures below are clearly
## separated from the real ordinary Model/UI route. No historical 85/103 matrix.
const Sim = preload("res://tests/ink_e2_boundary_20261006/ordinary01/sim.gd")
const FixtureHost = preload("res://tests/ink_e2_boundary_20261006/ordinary01/finite_host.gd")
const Production = preload("res://scripts/integration/yanguizhou_first_floor.gd")
const Session = preload("res://tests/ink_e2_boundary_20261006/ordinary01/floor_session.gd")
const Binding = preload("res://tests/ink_e2_boundary_20261006/ordinary01/live_binding.gd")
const OldBinding = preload("res://tests/ink_rest_service_20261006/candidate01/ordinary01/live_binding.gd")
const OldSim = preload("res://tests/ink_p1_ordinary_20261006/candidate01/lifesteal01/sim.gd")
const Router = preload("res://tests/ink_e2_boundary_20261006/ordinary01/input_adapter.gd")
const Audio = preload("res://tests/ink_style_specimen_20261004/audio_output.gd")
const HOME := "res://tests/ink_first_floor_user_route_20261005/runtime01/"
const LEAF := "res://tests/ink_e2_boundary_20261006/ordinary01/"
const REQUIRED := ["exact_single_owner_and_real_selector","whole_boat_p1_and_existing_lifesteal","queued_boat_and_real_q2_control","e1_q2_and_r1_current_chain","menu_new_e_and_rest_owner"]
var checks: int = 0
var failures: Array[String] = []
var groups: Array[String] = []
var observations: Dictionary = {}
var output_path: String = ""
var serial: int = 0
var live_session: RefCounted
var event_errors: Array = []

func _initialize() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--e2-ordinary-result="): output_path = arg.trim_prefix("--e2-ordinary-result=")
 run.call_deferred()
func check(ok: bool, label: String) -> bool:
 checks += 1
 if not ok: failures.append(label); push_error(label)
 return ok
func near(a: float, b: float, label: String) -> void:
 check(is_finite(a) and is_finite(b) and absf(a-b) < 0.0001,label+" actual="+str(a)+" expected="+str(b))
func key(code: int, down: bool = true) -> InputEventKey:
 var event := InputEventKey.new(); event.physical_keycode = code; event.pressed = down
 return event
func fresh(rank: int = 1, extent: float = 2.0):
 serial += 1
 var sim = Sim.new(); root.add_child(sim)
 sim.auto_finish = false; sim.ai_enabled = false; sim.arena_half_extent = extent; sim.obstacles = []
 sim.hero.position = Vector3.ZERO; sim.hero.loadout.e = "e2"; sim.hero.ranks.e = 1
 sim.hero.loadout.q = "q2"; sim.hero.ranks.q = 1; sim.hero.loadout.r = "r1"; sim.hero.ranks.r = 1
 sim.hero.loadout.passive = "p1"; sim.hero.ranks.passive = rank
 sim.hero.stats.ap = 100.0; sim.hero.stats.crit_chance = 0.0; sim.hero.stats.regen = 0.0; sim.hero.stats.lifesteal = 0.2; sim.hero.stats.cdr = 0.0
 check(sim.begin_encounter("e2-ordinary-combination-%d"%serial,[]).accepted,"explicit combination fixture starts")
 sim.set_hexes([])
 return sim
func target(sim, point: Vector3) -> Dictionary:
 var enemy: Dictionary = sim.spawn_enemy("minion",point,10000.0)
 enemy.state = "chase"; enemy.defence = 0.0; enemy.radius = 0.25; enemy.position = point
 return enemy
func river(sim) -> void:
 check(sim.request_q2("first",Vector3(4,0,-2)).accepted,"real Q2 first marker")
 check(sim.request_q2("second",Vector3(4,0,2)).accepted,"real Q2 completed river")
func p1_receipts(sim, id: int) -> Array:
 return sim.ink_p1_receipts.filter(func(item): return int(item.cast_id) == id)
func life_receipts(sim, id: int) -> Array:
 return sim.ink_p1_lifesteal_receipts.filter(func(item): return int(item.cast_id) == id)
func on_event(event: Dictionary) -> void:
 var result: Dictionary = live_session.observe_event(live_session.sim,event)
 if event.get("kind","") in ["damage","kill"] and not result.accepted: event_errors.append(result)
func on_terminal(event: Dictionary) -> void: live_session.queue_terminal(live_session.sim,event)
func choices(room) -> void:
 for milestone in live_session.ledger.model.snapshot().pending_milestones.duplicate():
  room.initial_controller.ensure_auto_hex()
  room.initial_hud.adapter.request("hex_select",{"milestone":milestone,"slot":3})
  check(room.initial_controller.last_result.accepted,"real mandatory Hex choice")
func route_enter(room, row: int, node_id: String) -> bool:
 choices(room)
 if not check(live_session.select_node(row,node_id).accepted,"legal selected route "+node_id): return false
 return check(live_session.enter_selected_node().accepted,"real committed route "+node_id)
func finish_fixture_combat(room, sim) -> void:
 for _i in range(80): sim.step(0.02); live_session.update_after_source_step()
 for enemy: Dictionary in sim.living().duplicate():
  sim.damage_enemy(enemy,1000000.0,"e2_ordinary_route_fixture",0,true,false,{"direct":false,"no_reactions":true})
 sim.step(0.02); live_session.update_after_source_step(); choices(room)
 check(live_session.status == "between_rooms" and event_errors.is_empty(),"same authority settles explicit damage fixture")

func whole_boat_p1() -> void:
 for boarded: bool in [false,true]:
  for count: int in [1,2]:
   var sim = fresh(1)
   sim.hero.hp = 100.0
   var enemy: Dictionary = target(sim,Vector3(0.5,0,0))
   if count == 2: target(sim,Vector3(0.5,0,0.3))
   var launched: Dictionary = sim.request_action("e",Vector3(20,0,0))
   if not check(launched.accepted,"P1 boat accepted"): sim.free(); continue
   var id: int = int(launched.cast_id)
   sim.step(0.2)
   check(p1_receipts(sim,id).is_empty(),"outward contact never supplements before whole boat ends")
   if boarded: check(sim.request_action("e",Vector3.INF).accepted,"original E2 root boards")
   else:
    sim.step(0.8)
    check(sim.ink_boat.boundary_parked and p1_receipts(sim,id).is_empty(),"parking neither completes boat nor P1")
    sim.step(2.02)
   var records: Array = p1_receipts(sim,id)
   if check(records.size() == 1,"whole original boat produces exactly one P1 receipt"):
    var item: Dictionary = records[0]
    var basis: float = 0.0
    for hit: Dictionary in sim.ink_e2_receipts:
     if int(hit.cast_id) == id and str(hit.target_id) == str(enemy.actor_id): basis += float(hit.actual_damage)
    check(item.distinct_targets == count and bool(item.qualified) == (count == 1),"all outward/burst targets belong to one P1 root")
    if count == 1:
     near(item.final_basis,basis,"P1 uses only actual original E2 packets")
     near(item.actual_supplement,basis*0.12,"original rank1 P1 final increment")
     near(item.cooldown_after,item.cooldown_before*0.95,"P1 refunds then-current E cooldown once")
     var life: Array = life_receipts(sim,id)
     if check(life.size() == 1,"E2 supplement reaches original P1 lifesteal authority once"):
      near(life[0].requested_heal,float(item.actual_supplement)*float(life[0].lifesteal_rate)*float(life[0].source_factor),"same existing Q/E area lifesteal factor")
      near(life[0].actual_heal,life[0].requested_heal,"existing health authority receives actual supplement heal")
    else: check(item.actual_supplement == 0.0 and item.cooldown_refund == 0.0 and life_receipts(sim,id).is_empty(),"two targets get no P1 increment/refund/heal")
   var settled: int = sim.ink_p1_receipts.size(); sim.step(0.1)
   check(sim.ink_p1_receipts.size() == settled and sim.ink_e2_finished.size() == 1,"terminal cannot pay a second time")
   sim.free()
 var sim = fresh(); target(sim,Vector3(0.5,0,0)); sim.request_action("e",Vector3(20,0,0)); sim.step(0.2)
 var id: int = int(sim.ink_boat.cast_id)
 sim.emit_event("ink_e2_finished",{"cast_id":id,"damage_stages_complete":true,"reason":"unboarded"})
 check(p1_receipts(sim,id).is_empty(),"forged bare E2 terminal cannot authorize P1")
 sim.cancel_cast(id); sim.step(3.0)
 check(p1_receipts(sim,id).is_empty() and life_receipts(sim,id).is_empty(),"cancelled boat cannot settle old P1 or heal")
 sim.free()
 groups.append("whole_boat_p1_and_existing_lifesteal")

func queued_and_real_q2() -> void:
 var sim = fresh(1,30.0); river(sim)
 target(sim,Vector3(0.5,0,0.1)); target(sim,Vector3(0.5,0,-0.1))
 sim.request_action("e",Vector3(20,0,0))
 var stopped: Array = [false]
 sim.combat_event.connect(func(event: Dictionary):
  if event.kind == "damage" and event.get("source","") == "e2" and not stopped[0]: stopped[0] = true; sim.paused = true)
 sim.step(0.3)
 check(sim.paused and not sim._e2_pending_sweep.is_empty() and not sim._q2_motion_resume.is_empty(),"real boat pause retains E2 and actual Q2 scheduler remainder")
 var at: float = sim.hero_time; var steps: int = sim.ink_core_steps; var cast: int = int(sim.ink_boat.cast_id)
 sim.paused = false
 var queued: Dictionary = sim.request_action("e",Vector3.INF)
 check(queued.accepted and queued.get("queued",false),"fresh E queues only behind real admitted boat contacts")
 near(sim.hero_time,at,"queue request makes no extra time")
 sim.step(0.02)
 check(sim.ink_e2_finished.size() == 1 and sim.ink_e2_finished[0].cast_id == cast and sim.cast_serial == cast,"remainder boarding preserves exact original root")
 check(sim._e2_pending_sweep.is_empty() and sim._q2_motion_resume.is_empty() and p1_receipts(sim,cast).size() == 1,"local and Q2 remainder plus whole-boat P1 drain once")
 check(sim.ink_core_steps > steps and absf(sim.hero_time-0.32)<0.0001,"public accumulator keeps all original admitted ticks")
 observations.queued_boat = sim.e2_board_input_report()
 sim.free()
 # These incoming packets are produced by the real retained enemy director,
 # from explicit warning-state actors. No _q2_enemy_hits packet is injected.
 sim = fresh(1,30.0); sim.hero.stats.lifesteal = 0.0; river(sim)
 sim.request_action("e",Vector3(20,0,0))
 for z: float in [-0.1,0.1]:
  var attacker: Dictionary = target(sim,Vector3(-0.8,0,z))
  attacker.state = "warning"; attacker.timer = 0.005; attacker.warning_duration = 0.2; attacker.aim = attacker.position.direction_to(sim.hero.position)
 sim.ai_enabled = true
 var incoming: Array = []; var first: Array = [false]
 sim.combat_event.connect(func(event: Dictionary):
  if event.kind == "damage" and event.get("target","") == "yanguizhou":
   incoming.append({"sequence":event.sequence,"time":sim.hero_time,"stun":sim.hero.stun_left})
   if not first[0]: first[0] = true; sim.paused = true)
 sim.step(0.02)
 check(sim.paused and sim._q2_enemy_hits.size() == 1 and not sim._q2_motion_resume.is_empty() and incoming.size() == 1,"real director warning hits create exactly one old Q2 control remainder")
 check(sim.hero.stun_left > 0.0,"first real delivered hostile hit commits control")
 at = sim.hero_time; steps = sim.ink_core_steps; var boat: Dictionary = sim.ink_boat
 sim.paused = false
 var controlled: Dictionary = sim.request_action("e",Vector3.INF)
 check(not controlled.accepted and controlled.reason == "controlled" and is_same(boat,sim.ink_boat),"already committed real control rejects fresh boarding and preserves boat")
 sim.step(0.02)
 check(incoming.size() == 2 and sim._q2_enemy_hits.is_empty() and sim._q2_motion_resume.is_empty(),"remaining real hostile hit commits once through original Q2 solver")
 check(sim.ink_core_steps == steps+1 and incoming[1].time == at,"old real control drains before exactly one new core tick")
 observations.real_q2_control = incoming
 sim.free()
 groups.append("queued_boat_and_real_q2_control")

func e1_and_r1() -> void:
 var sim = fresh(1,30.0); sim.hero.loadout.e = "e1"; sim.hero.stats.lifesteal = 0.0
 river(sim)
 var router = Router.new(); router.bind(sim)
 check(router.handle_event(key(KEY_E)).accepted,"new router retains actual E1 down")
 for z: float in [-0.1,0.1]:
  var attacker: Dictionary = target(sim,Vector3(-0.8,0,z))
  attacker.state = "warning"; attacker.timer = 0.005; attacker.warning_duration = 0.2; attacker.aim = attacker.position.direction_to(sim.hero.position)
 sim.ai_enabled = true
 var trace: Array = []; var stopped: Array = [false]
 sim.combat_event.connect(func(event: Dictionary):
  if event.kind == "ink_e1_finished" or (event.kind == "damage" and event.get("target","") == "yanguizhou"): trace.append(event.kind)
  if event.kind == "damage" and event.get("target","") == "yanguizhou" and not stopped[0]: stopped[0] = true; sim.paused = true)
 sim.step(0.02)
 check(sim.paused and sim._q2_enemy_hits.size() == 1,"retained real E1/Q2 control remainder")
 check(router.handle_event(key(KEY_E,false)).accepted and sim.ink_rain.release_pending,"true paused E1 up still belongs to original form")
 var steps: int = sim.ink_core_steps
 sim.paused = false; sim.step(0.02)
 check(trace == ["damage","damage","ink_e1_finished"] and sim.ink_core_steps == steps+1,"old real Q2 damage precedes queued E1 reform without double core tick")
 check(sim.ink_rain.is_empty() and sim.ink_e1_finished.size() == 1 and sim._q2_enemy_hits.is_empty(),"E1 release and both real hostile packets settle once")
 sim.free()
 sim = fresh(1,30.0)
 var director_script: GDScript = sim.enemy_director.get_script()
 var common_script: GDScript = sim.common.get_script()
 check(director_script.resource_path == Binding.DIRECTOR_PATH,"current R1 navigation director is retained")
 check(common_script.resource_path == "res://tests/ink_e2_boat_foundation_20261005/candidate04/boat_common_bridge.gd","only E2 impact snapshot extends the current Rain common bridge")
 var enemy: Dictionary = target(sim,Vector3(1,0,0))
 check(sim.request_action("r",Vector3.ZERO).accepted and sim.r1_enemy_rates(enemy).in_domain,"current R1 domain remains effective with E2")
 sim.request_action("e",Vector3(20,0,0)); sim.step(0.1)
 check(not sim.ink_snow.is_empty() and not sim.ink_boat.is_empty() and sim.r1_enemy_rates(enemy).in_domain,"single Sim owns concurrent R1 domain and boat")
 sim.free()
 groups.append("e1_q2_and_r1_current_chain")

func ordinary_route() -> void:
 var room = FixtureHost.new(); root.add_child(room)
 var sim: Node = room._make_floor_sim(); room.sim = sim; room.add_child(sim); sim.ai_enabled = false
 var session: RefCounted = room._make_floor_session(); room.shop_session = session; live_session = session
 room.input_router = room._make_floor_router(); room.input_router.bind(sim)
 room.audio_output = Audio.new(); room.add_child(room.audio_output); room._mainprep_required = false; room._mainprep_pending = false
 var production_script: GDScript = Production
 check(production_script.get_base_script().resource_path == LEAF+"host.gd","production selects exact new E2 ordinary host")
 check(sim.get_script().resource_path == Binding.SIM_PATH and session.get_script().resource_path == LEAF+"floor_session.gd","new exact Sim and single rest Session factories")
 var director_id: int = sim.enemy_director.get_instance_id()
 check(room._install_source_navigation().accepted and sim.enemy_director.get_instance_id() == director_id,"new navigation admission never swaps current R1 director")
 check(not room._install_source_navigation().accepted,"navigation admits once only")
 var capabilities: Dictionary = Binding.read_capabilities(sim,true)
 check(capabilities.accepted and capabilities.capabilities.runtime_candidates == ["Q1","Q2","Q3","E1","E2","P1","R1"],"new exact full closure admits only base E2 addition")
 check(not OldBinding.read_capabilities(sim,true).accepted,"old binding still rejects new exact Sim")
 var old = OldSim.new(); root.add_child(old); check(not Binding.read_capabilities(old,true).accepted,"new binding rejects original P1 Sim identity"); old.free()
 check(session.configure_reward_table(HOME+"reward_table.json",HOME+"rewards.csv",HOME+"validation_result.json",true).accepted,"original rewards configured")
 var definition: Dictionary = Session.MixedSchema.load_definition(Session.DEFAULT_DEFINITION,true)
 var initialized: Dictionary = session.initialize_floor(sim,definition.definition,"e2-ordinary-route",true)
 if not check(initialized.accepted,"new Session and Bridge exact admission: "+str(initialized.get("reason",""))): live_session = null; room.free(); return
 check(session.ledger.get_script().resource_path == LEAF+"bridge.gd" and session._owner_intact() and is_same(sim.progression,session.ledger),"one original health/reward/stat/economy owner")
 var fresh_state: Dictionary = session.ledger.model.snapshot()
 check(fresh_state.level == 1 and fresh_state.gold == 0 and fresh_state.xp == 0 and fresh_state.points == 1,"ordinary Lv1 zero gold/XP original one SP")
 session.bind_input_suspender(room.input_router.suspend_input)
 sim.combat_event.connect(on_event); sim.encounter_finished.connect(on_terminal)
 room._create_session_controls(); await process_frame
 choices(room)
 room.initial_hud.e2_choice.pressed.emit()
 check(room.initial_controller.last_result.accepted and sim.hero.loadout.e == "e2" and sim.hero.ranks.e == 1 and session.ledger.model.state.points == 0,"real E2 button learns through same original one-SP Model")
 check(room.initial_hud.e2_choice.tooltip_text.contains("1.1") and room.initial_hud.e2_choice.tooltip_text.contains("保留原船") and room.initial_hud.e2_choice.tooltip_text.contains("临时"),"actual selector states parking, illegal landing and temporary visuals")
 check(room.initial_hud.p1_choice.disabled and room.initial_hud.r1_choice.disabled,"original point and Lv6 R gate remain effective")
 groups.append("exact_single_owner_and_real_selector")
 # Only after proving the untouched ordinary baseline: one explicit SP and
 # 500-gold fixture purchases B09 through the actual same Model/shop authority.
 # Never write the lifesteal stat or inventory to manufacture this evidence.
 var model = session.ledger.model
 model.state.points = 1; model.state.gold = 500; model.state.revision += 1
 room.initial_controller.refresh(); room.initial_hud.p1_choice.pressed.emit()
 check(room.initial_controller.last_result.accepted and sim.hero.ranks.passive == 1 and model.state.points == 0,"labelled one-SP fixture learns P1 with actual button")
 check(session.open_panel().accepted,"actual preparation shop opens for B09 fixture")
 var quote: Dictionary = model.commerce_quote("base:B09")
 check(quote.accepted and int(quote.charge) == 500,"actual B09 quote retains500 price")
 var purchase_args: Dictionary = quote.get("token",{}).duplicate(true); purchase_args["item"] = "base:B09"
 var purchase: Dictionary = session.submit("e2-b09-explicit-funding-fixture","buy",purchase_args)
 check(purchase.accepted and model.state.gold == 0 and model.state.inventory.size() == 1 and model.state.inventory[0].id == "base:B09","actual B09 debit and inventory receipt")
 near(sim.hero.lifesteal(),0.04,"B09 source projection supplies actual four-percent lifesteal")
 check(session.close_panel().accepted,"same shop authority closes after B09 purchase")
 if route_enter(room,1,"r01a"):
  var router = room.input_router
  sim.hero.position = Vector3.ZERO
  for index in range(sim.enemies.size()):
   sim.enemies[index].position = Vector3(30+index,0,30); sim.enemies[index].state = "chase"
  if not sim.enemies.is_empty():
   var enemy: Dictionary = sim.enemies[0]
   enemy.position = Vector3(0.5,0,0); enemy.hp = 10000.0; enemy.defence = 0.0; enemy.radius = 0.25
  sim.hero.hp = sim.hero.stats.max_hp-100.0
  var before_hp: float = sim.hero.hp
  check(router.handle_event(key(KEY_E),sim.hero.position+Vector3(20,0,0)).accepted,"real E2 key launches in ordinary encounter")
  var boat: Dictionary = sim.ink_boat; var cast: int = int(boat.cast_id)
  room.frontdoor_suspend(); room.frontdoor_resume()
  check(not router.handle_event(key(KEY_E),Vector3.INF).accepted and is_same(boat,sim.ink_boat),"menu Continue cannot turn held old E into boarding")
  room.frontdoor_suspend()
  var echo_up: InputEventKey = key(KEY_E,false); echo_up.echo = true
  check(not room.frontdoor_observe_e1_release(echo_up).accepted and router.e2_input_snapshot().release_required,"echo up cannot release menu-held E2 ownership")
  var paused_time: float = sim.hero_time; var paused_cd: float = sim.hero.cooldowns.e
  room.frontdoor_observe_e1_release(key(KEY_E,false))
  check(not router.e2_input_snapshot().release_required and is_same(boat,sim.ink_boat) and sim.hero_time == paused_time and sim.hero.cooldowns.e == paused_cd,"actual menu E-up drains only physical latch without touching boat or clock")
  room.frontdoor_resume()
  check(router.handle_event(key(KEY_E),Vector3.INF).accepted and sim.ink_e2_finished.size() == 1 and sim.ink_e2_finished[0].cast_id == cast,"actual release plus new E boards the original boat once")
  var heals: Array = life_receipts(sim,cast)
  if check(heals.size() == 1,"actual B09 purchase feeds one whole-boat P1 supplemental heal"):
   near(heals[0].lifesteal_rate,0.04,"E2 supplement snapshots actual B09 rate")
   near(heals[0].source_factor,0.4,"E2 supplement retains original area factor")
   near(heals[0].actual_heal,float(heals[0].actual_supplement)*0.04*0.4,"B09 actual supplemental heal amount")
   var original_damage: float = 0.0
   for hit: Dictionary in sim.ink_e2_receipts:
    if int(hit.cast_id) == cast: original_damage += float(hit.actual_damage)
   near(sim.hero.hp-before_hp,(original_damage+float(heals[0].actual_supplement))*0.04*0.4,"ordinary plus supplement B09 heal uses one health owner")
  check(session._owner_intact() and is_same(sim.progression,session.ledger),"B09 damage/heal preserves original Session owner")
  router.handle_event(key(KEY_E,false)); router.suspend_input("fixture_end")
  router.observe_blocked_e2_down(key(KEY_E))
  check(not router.handle_event(key(KEY_E),Vector3(20,0,0)).accepted and router.e2_input_snapshot().release_required,"GUI-blocked E-down cannot become a fresh action after modal closes")
  router.queue_owned_boundary_e_up(key(KEY_E,false))
  check(not router.e2_input_snapshot().release_required,"genuine up clears GUI-blocked E latch")
  finish_fixture_combat(room,sim)
  if route_enter(room,2,"r02a"):
   finish_fixture_combat(room,sim)
   sim.hero.hp = 123.0; sim.observe_pending_health(); sim.hero.cooldowns.e = 9.0
   var owner_id: int = session.ledger.get_instance_id(); var flasks: int = session.ledger.model.state.shop_visit.flask_charges
   if route_enter(room,3,"r03a"):
    room._refresh_session_controls(true)
    check(sim.hero.hp == sim.hero.stats.max_hp and sim.hero.cooldowns.e == 0.0 and session.rest_service.snapshot().size() == 1,"same committed rest service reaches new Sim")
    check(session.ledger.get_instance_id() == owner_id and session._owner_intact() and session.ledger.model.state.shop_visit.flask_charges == flasks,"rest preserves exact owner and never refills base bottle")
    check(sim.ink_boat.is_empty() and sim._p1_e2_boats.is_empty() and sim._e2_pending_board_input.is_empty(),"rest/room cleanup leaves no E2/P1 queued owner")
    check(room.session_hint.text.contains(room.REST_SETTLED_TEXT),"real ordinary rest control still reports committed effect")
    groups.append("menu_new_e_and_rest_owner")
 session.close_run(); sim.combat_event.disconnect(on_event); sim.encounter_finished.disconnect(on_terminal)
 live_session = null; room.free()

func run() -> void:
 whole_boat_p1(); queued_and_real_q2(); e1_and_r1()
 await ordinary_route()
 for group: String in REQUIRED: check(group in groups,"required group completed: "+group)
 if output_path.is_empty() or FileAccess.file_exists(output_path): failures.append("fresh_explicit_output_required")
 var report: Dictionary = {"passed":failures.is_empty(),"checks":checks,"groups":groups,"required_groups":REQUIRED,"failures":failures,"observations":observations,"binding":FileAccess.get_sha256(Binding.BINDING_PATH),"gate_sha256":FileAccess.get_sha256(get_script().resource_path),"native_input":false,"natural_progression":false,"full_floor":false,"historical_matrices_rerun":false,"real_enemy_director_on_explicit_warning_state":true,"injected_q2_hostile_packets":false,"B09_fixture_gold":500,"extra_P1_fixture_SP":1,"global_old_event_before_new_input_order_claimed":false,"temporary_visuals_only":true}
 if not output_path.is_empty() and not FileAccess.file_exists(output_path):
  var file := FileAccess.open(output_path,FileAccess.WRITE)
  if file == null: report.passed = false; failures.append("result_write_failed")
  else: file.store_string(JSON.stringify(report,"  ")); file.close()
 print("INK_E2_ORDINARY_REPORT ",JSON.stringify(report))
 quit(0 if report.passed else 1)
