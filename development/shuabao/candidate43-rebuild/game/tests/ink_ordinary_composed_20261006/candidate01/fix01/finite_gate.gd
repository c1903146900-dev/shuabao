extends SceneTree
## Four bounded cross-component groups. No independent 610/316/215/237 rerun.
const Sim = preload("res://tests/ink_ordinary_composed_20261006/candidate01/sim.gd")
const Host = preload("res://tests/ink_ordinary_composed_20261006/candidate01/finite_host.gd")
const Session = preload("res://tests/ink_ordinary_composed_20261006/candidate01/floor_session.gd")
const Binding = preload("res://tests/ink_ordinary_composed_20261006/candidate01/live_binding.gd")
const Catalog = preload("res://tests/ink_ordinary_composed_20261006/candidate01/catalog.gd")
const HudProjection = preload("res://tests/ink_ordinary_composed_20261006/candidate01/hud_projection.gd")
const ECard = preload("res://tests/ink_ordinary_composed_20261006/candidate01/e_hud.gd")
const RCard = preload("res://tests/ink_ordinary_composed_20261006/candidate01/r_hud.gd")
const OldBinding = preload("res://tests/ink_p2_ordinary_20261006/ordinary01/live_binding.gd")
const Audio = preload("res://tests/ink_style_specimen_20261004/audio_output.gd")
const HUD = preload("res://tests/ink_style_specimen_20261004/revision10_hud/hud.gd")
const T = preload("res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_tuning.gd")
const TEST_BINDING_PATH := "res://tests/ink_ordinary_composed_20261006/candidate01/fix01/source_binding.json"
const HOME := "res://tests/ink_first_floor_user_route_20261005/runtime01/"
const LEAF := "res://tests/ink_ordinary_composed_20261006/candidate01/"
const REQUIRED_GROUPS: Array = ["p2_e1_remainder_before_presentation_clock", "p1_whole_reform_and_clock_admission", "rain_immunity_control_and_scope_retirement", "ordinary_owner_growth_hud_and_rest"]
var checks: int = 0
var failures: Array[String] = []
var groups: Array[String] = []
var group_checks: Dictionary = {}
var active_group: String = ""
var observations: Dictionary = {}
var event_errors: Array = []
var session: RefCounted
var serial: int = 0
var output_path: String = ""

func _initialize() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--composed-result="): output_path = arg.trim_prefix("--composed-result=")
 run.call_deferred()

func check(ok: bool, label: String) -> bool:
 checks += 1; group_checks[active_group] = int(group_checks.get(active_group,0))+1
 if not ok: failures.append(active_group+": "+label); push_error(active_group+": "+label)
 return ok

func near(a: float, b: float, label: String) -> void:
 check(is_finite(a) and absf(a-b)<0.0001,label+" actual="+str(a)+" expected="+str(b))

func done_group(name: String) -> void:
 check(name not in groups and int(group_checks.get(name,0))>0,"nonempty group completes once")
 groups.append(name); print("INK_COMPOSED_GROUP ",name)

func fresh(passive: String = "p2"):
 serial += 1
 var sim = Sim.new(); root.add_child(sim)
 sim.auto_finish = false; sim.ai_enabled = false; sim.arena_half_extent = 30.0; sim.obstacles = []
 sim.hero.loadout.q = "q1"; sim.hero.ranks.q = 1
 sim.hero.loadout.e = "e1"; sim.hero.ranks.e = 1
 sim.hero.loadout.r = "r1"; sim.hero.ranks.r = 1
 sim.hero.loadout.passive = passive; sim.hero.ranks.passive = 1
 sim.set_projected_stats({"AP":100.0,"move_speed":10.0,"defence":0.0,"crit_chance":0.0,"regen":0.0,"lifesteal":0.04,"cdr":0.0})
 check(sim.begin_encounter("composed-explicit-fixture-%d"%serial,[]).accepted,"explicit cross-component fixture begins")
 sim.set_hexes([]); sim.hero.position = Vector3.ZERO
 return sim

func packets(sim, source: String) -> Array:
 return sim.event_log.filter(func(event): return event.kind == "damage" and str(event.get("source","")) == source)

func fill(sim) -> void:
 for index: int in range(4):
  sim.hero.cooldowns.q = 0.0
  var result: Dictionary
  if index%2 == 0:
   sim.hero.loadout.q = "q1"
   check(sim.request_ink_input("q_down").accepted,"real fixture Q1 arm")
   check(sim.request_ink_input("left_down",Vector3.ZERO).accepted,"real fixture Q1 down")
   check(sim.request_ink_input("motion",Vector3(0.26,0,0)).accepted,"real fixture Q1 draw")
   result = sim.request_ink_input("left_up",Vector3(0.26,0,0))
  else:
   sim.hero.loadout.q = "q2"
   check(sim.request_q2("first",Vector3(0,0,-3)).accepted,"real fixture Q2 A")
   result = sim.request_q2("second",Vector3(0,0,3))
  check(result.accepted,"real successful alternation")
  sim.cancel_cast(int(result.cast_id))
 check(sim.p2.stacks == 3 and sim.p2.ready_epoch > 0,"real ready fixture")

func cast_r(sim) -> void:
 check(sim.request_action("r",Vector3.ZERO).accepted,"real R1 enters independent presentation")
 check(sim.hero_damage_immune() and not sim.r1_active and sim._presentation.is_empty(),"presentation is separate from legacy whole-field immunity")

func rain(sim, count: int = 2) -> Dictionary:
 var enemies: Array = []
 for point: Vector3 in [Vector3(0.3,0,0),Vector3(0.3,0,1.5)].slice(0,count):
  var enemy: Dictionary = sim.spawn_enemy("minion",point,10000.0)
  enemy.state = "chase"; enemy.defence = 0.0; enemy.radius = 0.25
  enemies.append(enemy)
 var entry: Dictionary = sim.request_action("ink_e_down")
 check(entry.accepted,"real E1 entry during own R1 window")
 var state: Dictionary = sim.ink_rain
 sim.move_during_hitstop(0.02,Vector3.RIGHT)
 sim.hero.move_intent = Vector3.ZERO
 check(state.marks.has(enemies[0].actor_id) and (count == 1 or not state.marks.has(enemies[1].actor_id)),"actual normal-rate movement retains exact rain mark membership")
 return {"state":state,"id":entry.cast_id,"enemies":enemies,"world":sim.hero_time,"real":sim.clock.domain.snapshot().active_real_time,"advances":sim.clock.advances}

func clock_clean(sim, label: String) -> void:
 check(sim.presentation_errors.is_empty(),label+" has no clock admission error")
 check(sim.clock.advances == sim.ink_core_steps,label+" keeps one authority advance per core slice")

func p2_e1_clock() -> void:
 active_group = REQUIRED_GROUPS[0]
 var sim = fresh(); fill(sim); cast_r(sim)
 var setup: Dictionary = rain(sim)
 var pause: Dictionary = {"original":false,"splash":false}
 var trace: Array = []
 sim.combat_event.connect(func(event: Dictionary):
  if event.kind in ["ink_e1_finished","ink_p2_splash_started","ink_p2_splash_finished"]: trace.append(event.kind)
  if event.kind == "damage" and event.get("source","") == "e1" and not pause.original:
   pause.original = true; sim.paused = true
  elif event.kind == "damage" and event.get("source","") == "yanguizhou_p2" and not pause.splash:
   pause.splash = true; sim.paused = true)
 check(sim.request_action("ink_e_up").accepted and sim.paused,"first original E1 packet pauses")
 check(packets(sim,"e1").size() == 1 and sim._e1_reform_pending.size() == 1 and sim.ink_e1_finished.is_empty(),"original remainder remains genuinely unfinished")
 check(sim.ink_p2_claims.size() == 1 and sim.p2.stacks == 0 and sim._p2_pending.size() == 1 and packets(sim,"yanguizhou_p2").is_empty(),"P2 atomically claimed, splash waits whole reform")
 var frozen: Dictionary = sim.clock.domain.snapshot()
 sim.step(0.2); check(sim.clock.domain.snapshot() == frozen,"pause cannot consume presentation authority")
 sim.paused = false; sim.step(0.02)
 check(pause.splash and sim.paused and sim._e1_reform_pending.is_empty() and sim.ink_e1_finished.size() == 1,"resumed originals finish before first splash pause")
 check(packets(sim,"e1").size() == 3 and packets(sim,"yanguizhou_p2").size() == 1 and sim._p2_pending.size() == 1,"real base/mark packets complete, second splash target remains")
 near(sim.hero_time,setup.world,"remainder/splash pause did not enter core")
 near(sim.clock.domain.snapshot().active_real_time,setup.real,"unconsumed clock ticket preserves presentation time")
 check(sim.clock.advances == setup.advances,"no authority advance for old packets")
 near(sim.real_accumulator,0.02,"one unadmitted budget retained once")
 sim.paused = false; sim.step(0.02)
 check(packets(sim,"e1").size() == 3 and packets(sim,"yanguizhou_p2").size() == 2 and sim.ink_p2_splashes.size() == 1,"second resume completes exactly one splash")
 near(sim.clock.domain.snapshot().active_real_time,float(setup.real)+0.04,"retained plus new request are each admitted once")
 near(sim.hero_time,float(setup.world)+0.01,"world advances by quarter-speed admitted budget")
 check(trace == ["ink_e1_finished","ink_p2_splash_started","ink_p2_splash_finished"],"P2 starts after real E1 terminal")
 check(sim.ink_p1_receipts.is_empty() and sim._p2_frames.is_empty() and sim._p2_source_frames.is_empty(),"passive exclusivity and source barriers unwind")
 clock_clean(sim,"P2+E1"); observations.p2_clock = {"trace":trace,"setup":setup.duplicate(true),"claims":sim.ink_p2_claims.duplicate(true),"active_real":sim.clock.domain.snapshot().active_real_time,"world":sim.hero_time}
 sim.free(); done_group(REQUIRED_GROUPS[0])

func p1_e1_clock() -> void:
 active_group = REQUIRED_GROUPS[1]
 for count: int in [1,2]:
  var sim = fresh("p1"); cast_r(sim); var setup: Dictionary = rain(sim,count)
  sim.hero.hp = 100.0
  var paused_once: Dictionary = {"done":false,"settled":false}
  sim.combat_event.connect(func(event: Dictionary):
   if event.kind == "damage" and event.get("source","") == "e1" and not paused_once.done:
    paused_once.done = true; sim.paused = true
   elif event.kind == "ink_p1_settled" and not paused_once.settled:
    paused_once.settled = true; sim.paused = true)
  check(sim.request_action("ink_e_up").accepted and sim.paused,"P1 E1 first original pauses")
  check(not sim.p1.roots[int(setup.id)].complete and sim.ink_p1_receipts.is_empty(),"P1 cannot settle incomplete original")
  sim.paused = false; sim.step(0.02)
  check(sim.paused and paused_once.settled and sim.ink_p1_receipts.size() == 1,"whole E1 terminal pays/denies before clock admission")
  var receipt: Dictionary = sim.ink_p1_receipts[0]
  check(receipt.distinct_targets == count and receipt.ordinary_packet_count == count+1,"P1 union includes every base and mark packet")
  check(receipt.qualified == (count == 1),"only whole single-target root qualifies")
  near(sim.hero_time,setup.world,"P1 settlement pause retains original world time")
  near(sim.clock.domain.snapshot().active_real_time,setup.real,"P1 settlement does not pre-consume presentation")
  if count == 1:
   near(receipt.actual_supplement,float(receipt.final_basis)*0.12,"original final P1 correction retained")
   check(sim.ink_p1_lifesteal_receipts.size() == 1,"correction has one normal lifesteal receipt")
   near(sim.ink_p1_lifesteal_receipts[0].actual_heal,float(receipt.actual_supplement)*0.04*0.4,"P1 correction area lifesteal preserved")
  else: near(receipt.actual_supplement,0.0,"multi-target original pays no P1 correction")
  sim.paused = false; sim.step(0.02)
  near(sim.clock.domain.snapshot().active_real_time,float(setup.real)+0.04,"P1 old and new real budgets drain once")
  check(sim.ink_p1_receipts.size() == 1 and sim.ink_p2_claims.is_empty() and sim._e1_reform_pending.is_empty(),"no duplicate P1 or dormant P2 work")
  clock_clean(sim,"P1+E1"); sim.free()
 done_group(REQUIRED_GROUPS[1])

func immunity_and_retirement() -> void:
 active_group = REQUIRED_GROUPS[2]
 var sim = fresh(); fill(sim); cast_r(sim)
 check(sim.request_action("ink_e_down").accepted,"E1 enters inside R1 window")
 var deadline: float = sim.p2.expires_at; var hp: float = sim.hero.hp
 sim.damage_hero(100.0,Vector3.ZERO,0.5)
 near(sim.hero.hp,hp,"presentation immunity precedes E1 damage reduction")
 near(sim.hero.stun_left,0.0,"presentation control immunity shares active window")
 sim.step(1.0)
 near(sim.hero_time,0.25,"P2/E1/R1 effects remain on world clock")
 near(sim.p2.expires_at,deadline,"presentation does not refresh P2 duration")
 check(sim.p2.stacks == 3 and sim._e1_form_current() and not sim.hero_damage_immune() and not sim.hero_control_immune(),"E1/P2 persist after short immunity ends")
 hp = sim.hero.hp; sim.damage_hero(100.0,Vector3.ZERO,0.5)
 near(hp-sim.hero.hp,100.0*(1.0-T.fraction("E1-2",1)),"after presentation only original E1 damage reduction applies")
 check(sim.hero.stun_left > 0.0,"E1 rain alone never acquires presentation control immunity")
 check(sim.presentation_ends.size() == 1 and not sim.ink_snow.is_empty(),"short window end keeps original R1 field")
 clock_clean(sim,"immunity boundary"); sim.free()
 sim = fresh(); fill(sim); cast_r(sim); var setup: Dictionary = rain(sim)
 var state: Dictionary = {"hits":0,"changed":false}
 var old_token: Dictionary = sim._current_show.token.duplicate(true)
 sim.combat_event.connect(func(event: Dictionary):
  if event.kind != "damage" or event.get("source","") != "e1": return
  state.hits = int(state.hits)+1
  if int(state.hits) == 1: sim.paused = true
  elif int(state.hits) == 2:
   state.changed = true; sim.end_encounter("cleared"); sim.begin_encounter("new-composed-scope",[]))
 check(sim.request_action("ink_e_up").accepted and sim.paused,"old-scope first packet pauses")
 var advances: int = sim.clock.advances
 sim.paused = false; sim.step(0.02)
 check(state.changed and sim.room_id == "new-composed-scope","actual old remainder callback changes scope")
 check(sim.clock.advances == advances and sim.clock.domain.snapshot().active_real_time == 0.0,"old armed budget never advances replacement room")
 check(not sim.clock.domain.is_invulnerable(old_token) and sim._e1_reform_pending.is_empty() and sim._p2_pending.is_empty() and sim.p2.last_family.is_empty(),"room change retires clock/E1/P2 old eligibility together")
 check(packets(sim,"yanguizhou_p2").is_empty() and sim.presentation_errors.is_empty(),"old splash and clock error do not leak into new room")
 sim.free(); done_group(REQUIRED_GROUPS[2])


func key(code: int, down: bool = true) -> InputEventKey:
 var out := InputEventKey.new(); out.physical_keycode = code; out.pressed = down; return out


func on_event(event: Dictionary) -> void:
 var result: Dictionary = session.observe_event(session.sim,event)
 if event.get("kind","") in ["damage","kill"] and not result.accepted: event_errors.append(result)


func on_terminal(event: Dictionary) -> void:
 session.queue_terminal(session.sim,event)


func choices(room) -> void:
 for milestone in session.ledger.model.snapshot().pending_milestones.duplicate():
  room.initial_controller.ensure_auto_hex()
  room.initial_hud.adapter.request("hex_select",{"milestone":milestone,"slot":3})
  check(room.initial_controller.last_result.accepted,"original mandatory Hex selection")


func open_room():
 serial += 1
 var room = Host.new(); root.add_child(room)
 var sim: Node = room._make_floor_sim(); room.sim = sim; room.add_child(sim); sim.ai_enabled = false
 session = room._make_floor_session(); room.shop_session = session
 room.input_router = room._make_floor_router(); room.input_router.bind(sim)
 room.audio_output = Audio.new(); room.add_child(room.audio_output)
 room._mainprep_required = false; room._mainprep_pending = false
 room.hud = HUD.new(); room.add_child(room.hud)
 check(sim.get_script().resource_path == Binding.SIM_PATH,"ordinary factory selects exact P2 Sim")
 check(session.get_script().resource_path == LEAF+"floor_session.gd","ordinary factory retains one explicit Session")
 var director: int = sim.enemy_director.get_instance_id()
 check(room._install_source_navigation().accepted and sim.enemy_director.get_instance_id() == director,"navigation admission retains original director")
 check(not room._install_source_navigation().accepted,"navigation installs once")
 check(session.configure_reward_table(HOME+"reward_table.json",HOME+"rewards.csv",HOME+"validation_result.json",true).accepted,"same original reward configuration")
 var definition: Dictionary = Session.MixedSchema.load_definition(Session.DEFAULT_DEFINITION,true)
 var initialized: Dictionary = session.initialize_floor(sim,definition.definition,"p2-ordinary-route-%d"%serial,true)
 if not check(initialized.accepted,"one real Session/Bridge initializes: "+str(initialized)):
  room.free(); return null
 check(session._owner_intact() and is_same(sim.progression,session.ledger),"sole original health/stat/economy owner")
 var baseline: Dictionary = session.ledger.model.snapshot()
 check(baseline.level == 1 and baseline.gold == 0 and baseline.xp == 0 and baseline.points == 1,"ordinary start is original Lv1/0gold/0XP/1SP")
 check(baseline.inventory.is_empty(),"no automatic equipment")
 session.bind_input_suspender(room.input_router.suspend_input)
 sim.combat_event.connect(on_event); sim.encounter_finished.connect(on_terminal)
 room._create_session_controls(); await process_frame; choices(room)
 return room


func enter(room, row: int, id: String) -> bool:
 choices(room)
 var selected: Dictionary = session.select_node(row,id)
 room._transition_result("select_node",selected)
 if not check(selected.accepted,"actual route selection "+id): return false
 var entered: Dictionary = session.enter_selected_node()
 # Same production lifecycle consumes the real result. It owns the Model →
 # Controller → Adapter revision publication; no fabricated request/state.
 room._transition_result("enter_selected_node",entered)
 check(int(room.initial_hud.adapter.state.revision) == int(session.ledger.model.state.revision),"actual Host transition publishes current Model revision")
 return check(entered.accepted,"actual Session entry "+id)


func finish_fixture_combat(room) -> void:
 var sim = room.sim
 for _i in range(80): sim.step(0.02); session.update_after_source_step()
 for enemy: Dictionary in sim.living().duplicate():
  sim.damage_enemy(enemy,1000000.0,"p2_ordinary_route_fixture",0,true,false,{"direct":false,"no_reactions":true})
 sim.step(0.02); session.update_after_source_step(); choices(room)
 # Actual observe02 established only the two legitimate initial-H02 vortices
 # remain after the exact original 80 steps and authenticated high-damage kills.
 # Keep that fixture; wait through the existing source deadline, never cancel.
 if sim.phase == "combat" and sim.living().is_empty() and not sim.ink_vortices.is_empty():
  var deadline: float = sim.hero_time
  var sources: Array = []
  for vortex: Dictionary in sim.ink_vortices:
   check(sim.effect_is_current(vortex) and not bool(vortex.get("retired",false)),"terminal wait belongs to a current original H02 effect")
   near(float(vortex.expires_at)-float(vortex.born_at),T.hex_parameter("H02-2"),"H02 wait preserves source duration")
   deadline = maxf(deadline,float(vortex.expires_at))
   sources.append({"cast_id":vortex.cast_id,"born_at":vortex.born_at,"expires_at":vortex.expires_at,"generation":vortex.generation,"room_id":vortex.room_id})
  check(sim.hero_time < deadline and sim._hero_victory_pending(),"before real H02 expiry the source still blocks victory")
  check(sim.ink_waves.is_empty() and sim.ink_basics.is_empty() and sim.ink_frames.is_empty() and sim._p2_pending.is_empty() and sim.ink_rivers.is_empty() and sim.ink_q2_pending.is_empty() and sim.ink_mountain.is_empty() and sim.ink_rain.is_empty() and sim.ink_boat.is_empty(),"only observed H02 remains, no foreign skill or P2 work")
  var premature: Dictionary = session.select_node(2,"r02a")
  check(not premature.accepted and premature.reason == "floor_not_selectable" and session.available_choices().is_empty(),"next row remains unselectable before legitimate terminal")
  var start: float = sim.hero_time
  var limit: int = ceili(maxf(0.0,deadline-start)/sim.FIXED_TICK)+1
  var actual_steps: int = 0
  for _wait in range(limit):
   if sim.phase != "combat": break
   if not check(not sim.paused,"natural H02 wait does not bypass pause"): break
   var before: float = sim.hero_time
   sim.step(sim.FIXED_TICK); session.update_after_source_step()
   actual_steps += 1
   if not check(sim.hero_time > before,"each bounded wait uses one progressing original step"): break
  observations["h02_terminal_wait"] = {"source":"observed original initial H02 after declared high-damage route fixture","sources":sources,"wait_start":start,"source_deadline":deadline,"step_budget":limit,"actual_steps":actual_steps,"terminal_at":sim.hero_time,"phase":sim.phase,"session_status":session.status,"effects_cancelled":false,"clock_assigned":false,"natural_combat_clear_claimed":false}
  check(sim.ink_vortices.is_empty() and sim.phase == "victory" and session.status == "between_rooms","natural original H02 expiry releases authentic terminal and route")
 check(session.status == "between_rooms" and event_errors.is_empty(),"original reward authority settles labelled route-finish fixture")


func close_room(room) -> void:
 var sim = room.sim
 session.close_run(); sim.combat_event.disconnect(on_event); sim.encounter_finished.disconnect(on_terminal)
 room.free(); session = null


func q1(room) -> Dictionary:
 var sim = room.sim
 # Cooldown reset is an explicit finite integration fixture, not free gameplay.
 sim.hero.cooldowns.q = 0.0
 check(sim.request_ink_input("q_down").accepted,"ordinary learned Q1 arms")
 check(sim.request_ink_input("left_down",Vector3(0,0,-5)).accepted,"ordinary learned Q1 starts")
 check(sim.request_ink_input("motion",Vector3(0.26,0,-5)).accepted,"ordinary learned Q1 draws")
 var result: Dictionary = sim.request_ink_input("left_up",Vector3(0.26,0,-5))
 check(result.accepted,"ordinary learned Q1 releases")
 return result


func ordinary_composition() -> void:
 active_group = REQUIRED_GROUPS[3]
 var room = await open_room()
 if room == null: return
 var sim = room.sim; var model = session.ledger.model
 var owner: int = session.ledger.get_instance_id(); var facade: int = sim.clock.get_instance_id(); var director: int = sim.enemy_director.get_instance_id()
 check(Binding.read_capabilities(sim,true).accepted and not OldBinding.read_capabilities(sim,true).accepted,"new exact combined binding admits only its leaf")
 check(sim.clock.get_script().resource_path == Binding.CLOCK_PATH and sim.enemy_director.get_script().resource_path == Binding.DIRECTOR_PATH,"ordinary owns exact previously proved clock/director")
 check(Catalog.FIRST_SLICE_ALLOWED_CANDIDATES == ["Q1","Q2","Q3","E1","E2","E3","P1","P2","R1"] and Catalog.FIRST_SLICE_HEX_HOOKS.size() == 10,"composition adds no candidate or Hex")
 room.initial_hud.r1_choice.pressed.emit()
 check(not room.initial_controller.last_result.accepted and room.initial_controller.last_result.reason == "level_gate" and model.state.points == 1,"ordinary Lv1 retains actual R1 level gate")
 room.initial_hud.p2_choice.pressed.emit()
 check(room.initial_controller.last_result.accepted and model.state.points == 0 and sim.hero.loadout.passive == "p2","actual P2 button spends original one SP")
 # Explicit progression test fixture only, matching the independently proven R1
 # setup: no natural Lv6 run, gold reward or additional production grant.
 model.state.level = 6; model.state.points = 4; model.state.granted_level_ids = [1,2,3,4,5,6]; model.state.revision += 1
 room.initial_controller.refresh(); choices(room)
 room.initial_hud.adapter.request("learn",{"slot_id":"Q","candidate_id":"Q1","expected_rank":0})
 check(room.initial_controller.last_result.accepted,"fixture point learns Q1 through original Model")
 room.initial_hud.e1_choice.pressed.emit(); check(room.initial_controller.last_result.accepted,"same E row learns E1")
 room.initial_hud.r1_choice.pressed.emit(); check(room.initial_controller.last_result.accepted and model.state.points == 1,"Lv6 fixture learns original 1SP R1")
 check(room.initial_hud.p1_choice.disabled,"P2 owns sole P slot even with available fixture SP")
 room.initial_hud.adapter.request("learn",{"slot_id":"P","candidate_id":"P1","expected_rank":1})
 check(not room.initial_controller.last_result.accepted and room.initial_controller.last_result.reason == "training_required","same-slot P1 replacement is rejected with points available")
 var pre_room_ui: Dictionary = room.initial_hud.adapter.state.duplicate(true)
 if not enter(room,1,"r01a"): close_room(room); return
 sim.hero.position = Vector3.ZERO
 for index: int in range(sim.enemies.size()): sim.enemies[index].position = Vector3(30+index,0,30); sim.enemies[index].state = "chase"
 for index: int in range(2):
  q1(room)
  sim.hero.cooldowns.e = 0.0
  check(sim.request_action("ink_e_down").accepted and sim.request_action("ink_e_up").accepted,"real empty E1 entry/reform alternates in ordinary owner")
 check(sim.p2.stacks == 3 and sim.p2.ready_epoch > 0,"ordinary composition has real ready state")
 var deadline: float = sim.p2.expires_at
 # Preserve the exact old-window rejection instead of relaxing the controller.
 # The actual observation was request revision10 versus Model14, with P2 intact.
 var stale_request: Dictionary = {"action":"learn","actor_id":pre_room_ui.actor_id,"command_id":"combined-old-window-negative","state_revision":pre_room_ui.revision,"slot_id":"P","candidate_id":"P2","expected_rank":1}
 var before_points: int = model.state.points
 var before_revision: int = model.state.revision
 check(int(stale_request.state_revision) < before_revision,"preserved pre-room request is stale before retry fixture")
 room.initial_controller.handle_request(stale_request)
 var stale_result: Dictionary = room.initial_controller.last_result.duplicate(true)
 check(not stale_result.accepted and stale_result.reason == "stale_state","old pre-room window request remains refused")
 check(model.state.points == before_points and model.state.revision == before_revision and sim.hero.ranks.passive == 1 and sim.p2.stacks == 3,"stale rejection preserves SP/rank/current three stacks")
 near(sim.p2.expires_at,deadline,"stale rejection preserves original deadline")
 room.initial_hud.p2_choice.pressed.emit()
 observations["live_p2_upgrade"] = {"stale_request":stale_request,"stale_result":stale_result,"current_result":room.initial_controller.last_result.duplicate(true),"model_revision":model.state.revision,"adapter_revision":room.initial_hud.adapter.state.revision,"points":model.state.points,"rank":sim.hero.ranks.passive,"stacks":sim.p2.stacks,"expires_at":sim.p2.expires_at,"pending_milestones":model.snapshot().pending_milestones.duplicate()}
 check(room.initial_controller.last_result.accepted and model.state.points == 0 and sim.hero.ranks.passive == 2 and sim.p2.stacks == 3,"actual live P2 upgrade retains stacks")
 near(sim.p2.expires_at,deadline,"ordinary live upgrade does not extend buff")
 cast_r(sim)
 var token: Dictionary = sim._current_show.token.duplicate(true)
 var frozen: Dictionary = sim.clock.domain.snapshot()
 room.frontdoor_suspend(); sim.step(0.5)
 check(sim.clock.domain.snapshot() == frozen,"ordinary frontdoor pause freezes new clock")
 room.frontdoor_resume()
 var selected_p: Dictionary = HudProjection.apply_p_to(room.hud,sim)
 var selected_q: Dictionary = HudProjection.apply_to(room.hud,sim)
 var selected_e: Dictionary = ECard.apply_to(room.hud,sim)
 var selected_r: Dictionary = RCard.apply_to(room.hud,sim)
 check(selected_p.accepted and selected_p.candidate == "p2" and selected_p.ready and selected_q.candidate == "q1","new exact Q/P consumers remain visible")
 check(selected_e.accepted and selected_e.candidate == "e1" and selected_r.accepted and selected_r.candidate == "r1","new exact E/R consumers remain visible")
 check(selected_r.tooltip.contains("独立施放窗口") and not selected_r.tooltip.contains("无无敌"),"R card accurately separates field from presentation immunity")
 check(room.initial_hud.e3_choice != null and room.initial_hud.p1_choice.get_parent() == room.initial_hud.p2_choice.get_parent(),"E3 controls and sole P row remain")
 sim.step(0.10)
 near(sim.hero_time,0.025,"ordinary source uses quarter-speed world")
 near(sim.p2.expires_at,deadline,"ordinary actor presentation does not age P2 on actor time")
 finish_fixture_combat(room)
 check(not sim.clock.domain.is_invulnerable(token) and sim.p2.last_family.is_empty() and sim._e1_reform_pending.is_empty() and sim._p2_pending.is_empty(),"real victory retires clock/P2/E1 scope")
 if enter(room,2,"r02a"):
  check(sim.clock.domain.snapshot().active_real_time == 0.0 and sim.clock.domain.snapshot().scope.room_id == sim.room_id,"new room binds fresh exact clock scope")
  finish_fixture_combat(room)
  sim.hero.hp = 123.0; sim.observe_pending_health(); sim.hero.cooldowns.r = 9.0
  var flasks: int = model.state.shop_visit.flask_charges; var gold: int = model.state.gold; var points: int = model.state.points
  if enter(room,3,"r03a"):
   check(sim.hero.hp == sim.hero.stats.max_hp and sim.hero.cooldowns.r == 0.0 and session.rest_service.snapshot().size() == 1,"actual rest keeps original health/cooldown behavior")
   check(model.state.shop_visit.flask_charges == flasks and model.state.gold == gold and model.state.points == points,"rest adds no bottle/gold/SP")
   check(session.ledger.get_instance_id() == owner and sim.clock.get_instance_id() == facade and sim.enemy_director.get_instance_id() == director and session._owner_intact(),"lifecycle preserves one Session/facade/director")
   check(sim.clock.scale_factor() == 1.0 and sim.clock.domain.snapshot().presentations.is_empty() and sim._e1_reform_pending.is_empty() and sim._p2_pending.is_empty(),"rest leaves no timed actor or damage work")
 check(event_errors.is_empty(),"ordinary health/reward authority accepts combined events")
 observations.ordinary = {"owner":owner,"facade":facade,"director":director,"P2_rank":sim.hero.ranks.passive,"R1_rank":sim.hero.ranks.r,"fixture_level":6,"additional_fixture_SP":4,"natural_clear":false}
 close_room(room); done_group(REQUIRED_GROUPS[3])

func run() -> void:
 p2_e1_clock()
 p1_e1_clock()
 immunity_and_retirement()
 await ordinary_composition()
 active_group = "integrity"
 for group: String in REQUIRED_GROUPS: check(groups.count(group) == 1,"required group reached once: "+group)
 var report: Dictionary = {"schema":"ink-ordinary-composed-finite-1","passed":failures.is_empty() and groups == REQUIRED_GROUPS,"checks":checks,"failures":failures,"completed":groups,"group_checks":group_checks,"event_errors":event_errors,"observations":observations,"source_binding_sha256":FileAccess.get_sha256(TEST_BINDING_PATH),"runtime_source_binding_sha256":FileAccess.get_sha256(Binding.BINDING_PATH),"native_input":false,"natural_progression":false,"full_floor":false,"old_full_matrices_rerun":false,"new_hex_admission":false,"final_presentation_animation":false,"real_multiplayer":false,"explicit_level6_fixture":true}
 if not output_path.is_empty():
  var file := FileAccess.open(output_path,FileAccess.WRITE)
  if file == null: push_error("combined report write failed"); quit(2); return
  file.store_string(JSON.stringify(report," ")+"\n")
 print("INK_COMPOSED_REPORT ",JSON.stringify(report))
 quit(0 if report.passed else 1)
