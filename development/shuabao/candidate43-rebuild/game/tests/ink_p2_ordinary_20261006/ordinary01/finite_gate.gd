extends SceneTree
## Five affected ordinary groups, not the prior 610-check mechanism matrix.
## Real controls/Session/Model, with separately declared SP/gold/contact fixtures.
const Host = preload("res://tests/ink_p2_ordinary_20261006/ordinary01/finite_host.gd")
const Sim = preload("res://tests/ink_p2_ordinary_20261006/ordinary01/sim.gd")
const Session = preload("res://tests/ink_p2_ordinary_20261006/ordinary01/floor_session.gd")
const Binding = preload("res://tests/ink_p2_ordinary_20261006/ordinary01/live_binding.gd")
const Catalog = preload("res://tests/ink_p2_ordinary_20261006/ordinary01/catalog.gd")
const Projection = preload("res://tests/ink_p2_ordinary_20261006/ordinary01/hud_projection.gd")
const ECard = preload("res://tests/ink_p2_ordinary_20261006/ordinary01/e_hud.gd")
const Text = preload("res://tests/ink_p2_ordinary_20261006/ordinary01/runtime_text.gd")
const OldBinding = preload("res://tests/ink_e3_ordinary_20261006/ordinary01/live_binding.gd")
const OldSim = preload("res://tests/ink_e3_ordinary_20261006/ordinary01/sim.gd")
const Audio = preload("res://tests/ink_style_specimen_20261004/audio_output.gd")
const HUD = preload("res://tests/ink_style_specimen_20261004/revision10_hud/hud.gd")
const Design = preload("res://data/final_design/catalog.gd")
const T = preload("res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_tuning.gd")
const Production = preload("res://scripts/integration/yanguizhou_first_floor.gd")
const HOME := "res://tests/ink_first_floor_user_route_20261005/runtime01/"
const LEAF := "res://tests/ink_p2_ordinary_20261006/ordinary01/"
const REQUIRED_GROUPS: Array = ["exact_binding_and_single_session", "passive_slot_growth_and_upgrade", "real_p2_e3_and_readonly_hud", "ordinary_scope_rest_and_resources", "p1_e3_b09_preserved"]
var checks: int = 0
var failures: Array[String] = []
var groups: Array[String] = []
var group_checks: Dictionary = {}
var active_group: String = ""
var observations: Dictionary = {}
var event_errors: Array = []
var session: RefCounted
var output_path: String = ""
var serial: int = 0

func _initialize() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--p2-ordinary-result="): output_path = arg.trim_prefix("--p2-ordinary-result=")
 run.call_deferred()

func check(ok: bool, label: String) -> bool:
 checks += 1; group_checks[active_group] = int(group_checks.get(active_group,0))+1
 if not ok: failures.append(active_group+": "+label); push_error(active_group+": "+label)
 return ok

func near(a: float, b: float, label: String) -> void:
 check(is_finite(a) and absf(a-b)<0.0001,label+" actual="+str(a)+" expected="+str(b))

func done_group(name: String) -> void:
 check(name not in groups and int(group_checks.get(name,0))>0,"nonempty required group completes once")
 groups.append(name); print("INK_P2_ORDINARY_GROUP ",name)

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
 if not check(session.select_node(row,id).accepted,"actual route selection "+id): return false
 return check(session.enter_selected_node().accepted,"actual Session entry "+id)

func finish_fixture_combat(room) -> void:
 var sim = room.sim
 for _i in range(80): sim.step(0.02); session.update_after_source_step()
 for enemy: Dictionary in sim.living().duplicate():
  sim.damage_enemy(enemy,1000000.0,"p2_ordinary_route_fixture",0,true,false,{"direct":false,"no_reactions":true})
 sim.step(0.02); session.update_after_source_step(); choices(room)
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

func e3(room, a: Vector3 = Vector3(-3,0,0), b: Vector3 = Vector3(3,0,0)) -> Dictionary:
 room.sim.hero.cooldowns.e = 0.0
 room.input_router.handle_event(key(KEY_E,false))
 check(room.input_router.handle_event(key(KEY_E),a).accepted,"ordinary learned E3 A via physical event adapter")
 room.input_router.handle_event(key(KEY_E,false))
 var result: Dictionary = room.input_router.handle_event(key(KEY_E),b)
 check(result.accepted,"ordinary learned E3 B via physical event adapter")
 room.input_router.handle_event(key(KEY_E,false)); return result

func ordinary_p2_route() -> void:
 active_group = REQUIRED_GROUPS[0]
 var room = await open_room()
 if room == null: return
 var sim = room.sim; var model = session.ledger.model
 var owner: int = session.ledger.get_instance_id()
 check(Production.get_base_script().resource_path == LEAF+"host.gd","reviewed staged production entry selects candidate host")
 var caps: Dictionary = Binding.read_capabilities(sim,true)
 check(caps.accepted and caps.capabilities.runtime_candidates == ["Q1","Q2","Q3","E1","E2","E3","P1","P2","R1"],"new exact capability closure adds only P2")
 check(not OldBinding.read_capabilities(sim,true).accepted,"old exact binding rejects new Sim")
 var old = OldSim.new(); root.add_child(old)
 check(not Binding.read_capabilities(old,true).accepted,"new exact binding rejects old Sim"); old.free()
 check(Catalog.FIRST_SLICE_HEX_HOOKS.size() == 10,"original ten-Hex ceiling")
 for hex_id: String in ["h03","h04","h07","h08","h09","h10","h11","h12","h13","h14","h15","h16"]:
  check("hex.final_design.yanguizhou_"+hex_id+".v1" not in Catalog.FIRST_SLICE_HEX_HOOKS,"closed Hex stays closed "+hex_id)
 check("P3" not in Catalog.FIRST_SLICE_ALLOWED_CANDIDATES and "R2" not in Catalog.FIRST_SLICE_ALLOWED_CANDIDATES,"other candidate scope unchanged")
 check(room.initial_hud.p1_choice.get_parent() == room.initial_hud.p2_choice.get_parent(),"P1/P2 share the one existing passive row")
 check(Text.candidates() == Catalog.FIRST_SLICE_ALLOWED_CANDIDATES and Text.hero_note().contains("P2") and Text.skill_line().contains("P2"),"chooser/scope use one catalog text authority")
 done_group(REQUIRED_GROUPS[0])

 active_group = REQUIRED_GROUPS[1]
 room.initial_hud.p2_choice.pressed.emit()
 check(room.initial_controller.last_result.accepted and sim.hero.loadout.passive == "p2" and sim.hero.ranks.passive == 1 and model.state.points == 0,"actual P2 button spends original sole SP")
 check(model.state.gold == 0 and model.state.level == 1 and model.state.xp == 0,"P2 learning adds no resources")
 check(room.initial_hud.p1_choice.disabled,"same passive slot excludes P1")
 check(room.initial_hud.p2_choice.tooltip_text.contains("首次") and room.initial_hud.p2_choice.tooltip_text.contains("Q2/E3") and not room.initial_hud.p2_choice.tooltip_text.contains("该技能尚未实现"),"P2 tooltip presents resolved original mechanics")
 check(room.initial_hud.e3_choice.tooltip_text.contains("H11/H12") and not room.initial_hud.e3_choice.tooltip_text.contains("该技能尚未实现"),"E3 control and corrected text retained")
 # Exactly two labelled fixture SP fund the two already implemented active slots.
 model.state.points = 2; model.state.revision += 1; room.initial_controller.refresh()
 room.initial_hud.adapter.request("learn",{"slot_id":"Q","candidate_id":"Q1","expected_rank":0})
 check(room.initial_controller.last_result.accepted,"actual ordinary Model learns Q1 from declared fixture SP")
 room.initial_hud.e3_choice.pressed.emit()
 check(room.initial_controller.last_result.accepted and model.state.points == 0,"actual E3 button learns E3 from remaining declared fixture SP")
 if not enter(room,1,"r01a"): close_room(room); return
 sim.hero.position = Vector3.ZERO
 for index: int in range(sim.enemies.size()):
  sim.enemies[index].position = Vector3(30+index,0,30); sim.enemies[index].state = "chase"
 q1(room); e3(room); q1(room); e3(room)
 check(sim.p2.use_serial == 4 and sim.p2.stacks == 3 and sim.p2.ready_epoch > 0 and sim.ink_p2_claims.is_empty(),"real learned Q1/E3 alternating completions form ready without spending")
 var deadline: float = sim.p2.expires_at; var ready: int = sim.p2.ready_epoch
 model.state.points = 3; model.state.revision += 1; room.initial_controller.refresh()
 for expected_rank: int in range(2,5):
  room.initial_hud.p2_choice.pressed.emit()
  check(room.initial_controller.last_result.accepted and int(sim.hero.ranks.passive) == expected_rank,"actual P2 button upgrades to "+str(expected_rank))
  check(sim.p2.stacks == 3 and sim.p2.ready_epoch == ready,"ordinary upgrade retains existing buff/epoch")
  near(sim.p2.expires_at,deadline,"ordinary upgrade preserves deadline")
 check(model.state.points == 0 and room.initial_hud.p2_choice.disabled,"three upgrades debit exactly three fixture SP and cap at four")
 room.initial_hud.adapter.request("learn",{"slot_id":"P","candidate_id":"P2","expected_rank":4})
 check(not room.initial_controller.last_result.accepted and sim.hero.ranks.passive == 4,"rank-five request refused")
 room.initial_hud.adapter.request("learn",{"slot_id":"P","candidate_id":"P1","expected_rank":4})
 check(not room.initial_controller.last_result.accepted and sim.hero.loadout.passive == "p2","occupied passive slot cannot silently switch to P1")
 check(session.ledger.get_instance_id() == owner and session._owner_intact(),"all learning retains sole Session owner")
 done_group(REQUIRED_GROUPS[1])

 active_group = REQUIRED_GROUPS[2]
 var before_steps: int = sim.ink_core_steps; var before_clock: float = sim.hero_time
 var shown: Dictionary = Projection.apply_p_to(room.hud,sim)
 check(shown.accepted and shown.candidate == "p2" and shown.rank == 4 and shown.stacks == 3 and shown.ready,"actual P card shows selected rank/stacks/ready")
 near(shown.remaining,5.0,"P card reports original remaining source time")
 var patch: Control = room.hud.get_node("P1ReadOnlyTemporaryCard")
 check(patch.get_script().resource_path == LEAF+"p_hud.gd" and patch.projected.candidate == "p2","same passive rectangle uses P2 renderer")
 check(sim.ink_core_steps == before_steps and sim.hero_time == before_clock,"HUD readback does not advance simulation")
 check(shown.tooltip.contains(Design.description("yanguizhou","p2",4)),"P2 tooltip preserves exact four-rank source description")
 sim.hero.cooldowns.e = 0.0
 check(room.input_router.handle_event(key(KEY_E),Vector3(-3,0,0)).accepted,"new E3 A after ready")
 var frame: Dictionary = sim.ink_frames; var saved_near: float = frame.near_damage
 room.frontdoor_suspend(); sim.step(0.5)
 near(sim.hero_time,before_clock,"menu freezes P2 and E3 source clock")
 near(sim.p2.expires_at,deadline,"menu preserves P2 deadline")
 room.frontdoor_observe_e1_release(key(KEY_E,false)); room.frontdoor_resume()
 if not check(not sim.enemies.is_empty(),"ordinary room supplies real original target"): close_room(room); return
 var enemy: Dictionary = sim.enemies[0]
 enemy.position = Vector3(-3,0,0); enemy.hp = 10000.0; enemy.defence = 0.0; enemy.radius = 0.25; enemy.state = "chase"
 var result: Dictionary = room.input_router.handle_event(key(KEY_E),Vector3(3,0,0))
 check(result.accepted and sim.ink_e3_finished.size() == 3,"ordinary retained A completes legal B after menu")
 check(sim.ink_p2_claims.size() == 1 and sim.ink_p2_splashes.size() == 1 and sim.p2.stacks == 0,"real ordinary E3 HP commit consumes and splashes once")
 near(frame.near_damage,saved_near,"E3 original A snapshot is preserved")
 if sim.ink_p2_claims.size() == 1:
  var claim: Dictionary = sim.ink_p2_claims[0]
  check(claim.family == "e3" and claim.passive_rank == 4 and claim.cast_id == result.cast_id,"real E3 B uses current ordinary P2 rank/root")
  near(claim.nominal_damage,T.parameter("P2-7",4)+float(claim.ap_before_clear)*T.fraction("P2-8",4),"ordinary splash source rank values")
 check(sim.ink_p1_receipts.is_empty() and sim.p1.roots.is_empty(),"P2 never creates P1 settlement alongside it")
 shown = Projection.apply_p_to(room.hud,sim)
 check(shown.stacks == 0 and not shown.ready and shown.last_family == "e3","P card reads consumed state and retained family")
 check(ECard.model_from(sim).accepted and ECard.model_from(sim).candidate == "e3","E3 read-only card still accepts new exact Sim")
 check(Projection.apply_to(room.hud,sim).candidate == "q1","Q1 selected projection remains attached")
 check(event_errors.is_empty(),"real P2 ordinary damage accepted by original event/health authority")
 observations.p2_claims = sim.ink_p2_claims.duplicate(true)
 done_group(REQUIRED_GROUPS[2])

 active_group = REQUIRED_GROUPS[3]
 room.input_router.handle_event(key(KEY_E,false))
 finish_fixture_combat(room)
 check(sim.p2.stacks == 0 and sim.p2.last_family.is_empty() and sim._p2_pending.is_empty(),"actual end encounter retires P2 history/queue")
 if enter(room,2,"r02a"):
  check(sim.p2.use_serial == 0 and sim.p2.stacks == 0,"next room starts without old use/ready")
  finish_fixture_combat(room)
  sim.hero.hp = 123.0; sim.observe_pending_health(); sim.hero.cooldowns.e = 9.0
  var flasks: int = model.state.shop_visit.flask_charges
  var gold: int = model.state.gold; var xp: int = model.state.xp; var points: int = model.state.points
  if enter(room,3,"r03a"):
   check(sim.hero.hp == sim.hero.stats.max_hp and sim.hero.cooldowns.e == 0.0 and session.rest_service.snapshot().size() == 1,"actual committed rest keeps full-heal/cooldown behavior")
   check(model.state.shop_visit.flask_charges == flasks,"rest never refills base bottle")
   check(model.state.gold == gold and model.state.xp == xp and model.state.points == points,"P2 rest adds no gold XP or SP")
   check(sim.hero.loadout.passive == "p2" and sim.hero.ranks.passive == 4 and sim.p2.last_family.is_empty(),"rest preserves learning and clears transient history")
   check(session.ledger.get_instance_id() == owner and session._owner_intact(),"route/rest retains original Session owner")
   var report: Dictionary = room.p2_ordinary_report()
   check(not report.e1_original_pause_remainder_fixed and report.native_input == "NOT_RUN","known E1 callback-pause and native limits remain explicit")
 done_group(REQUIRED_GROUPS[3]); close_room(room)

func p1_b09_route() -> void:
 active_group = REQUIRED_GROUPS[4]
 var room = await open_room()
 if room == null: return
 var sim = room.sim; var model = session.ledger.model
 room.initial_hud.p1_choice.pressed.emit()
 check(room.initial_controller.last_result.accepted and sim.hero.loadout.passive == "p1" and model.state.points == 0,"unchanged P1 button spends original SP")
 check(room.initial_hud.p2_choice.disabled,"P1 occupancy locks P2 on same row")
 model.state.points = 1; model.state.gold = 500; model.state.revision += 1; room.initial_controller.refresh()
 room.initial_hud.e3_choice.pressed.emit(); check(room.initial_controller.last_result.accepted,"declared one-SP fixture learns E3 beside P1")
 check(session.open_panel().accepted,"real preparation shop opens")
 var quote: Dictionary = model.commerce_quote("base:B09")
 check(quote.accepted and int(quote.charge) == 500,"actual original B09 quote")
 var args: Dictionary = quote.get("token",{}).duplicate(true); args.item = "base:B09"
 var purchase: Dictionary = session.submit("p2-ordinary-b09-funding-fixture","buy",args)
 check(purchase.accepted and model.state.gold == 0 and model.state.inventory.size() == 1 and model.state.inventory[0].id == "base:B09","actual B09 purchase uses sole wallet/inventory")
 near(sim.hero.lifesteal(),0.04,"real purchased B09 projects four percent")
 check(session.close_panel().accepted,"same shop closes")
 if enter(room,1,"r01a"):
  sim.hero.position = Vector3.ZERO
  for index: int in range(sim.enemies.size()):
   sim.enemies[index].position = Vector3(30+index,0,30); sim.enemies[index].state = "chase"
  if check(not sim.enemies.is_empty(),"ordinary P1 test has original enemy"):
   var enemy: Dictionary = sim.enemies[0]; enemy.position = Vector3(-3,0,0); enemy.hp = 10000.0; enemy.defence = 0.0; enemy.radius = 0.25
   sim.hero.hp = sim.hero.stats.max_hp-100.0
   var before: float = sim.hero.hp; e3(room)
   if check(sim.ink_p1_receipts.size() == 1 and sim.ink_p1_lifesteal_receipts.size() == 1,"new ordinary composition retains one P1 correction and its B09 heal"):
    var paid: Dictionary = sim.ink_p1_receipts[0]; var healed: Dictionary = sim.ink_p1_lifesteal_receipts[0]
    check(paid.qualified and paid.distinct_targets == 1,"whole original E3 remains single-target P1")
    near(paid.actual_supplement,float(paid.final_basis)*0.12,"P1 original rank-one final correction")
    near(healed.actual_heal,float(paid.actual_supplement)*0.04*0.4,"P1 correction keeps actual purchased B09 area lifesteal")
    near(sim.hero.hp-before,(float(paid.final_basis)+float(paid.actual_supplement))*0.04*0.4,"original and correction heal same owner once")
   check(sim.p2.use_serial == 0 and sim.ink_p2_claims.is_empty(),"P1 selected never runs P2")
   check(Projection.apply_p_to(room.hud,sim).candidate == "p1","shared passive renderer still presents P1")
 check(event_errors.is_empty(),"ordinary callback authority remains clean")
 done_group(REQUIRED_GROUPS[4]); close_room(room)

func run() -> void:
 await ordinary_p2_route()
 await p1_b09_route()
 active_group = "integrity"
 for group: String in REQUIRED_GROUPS: check(groups.count(group) == 1,"required group exactly once: "+group)
 var report: Dictionary = {"schema":"ink-p2-ordinary-finite-1","passed":failures.is_empty() and groups == REQUIRED_GROUPS,"checks":checks,"failures":failures,"completed":groups,"group_checks":group_checks,"event_errors":event_errors,"observations":observations,"source_binding_sha256":FileAccess.get_sha256(Binding.BINDING_PATH),"native_input":false,"natural_progression":false,"full_floor":false,"old_full_matrices_rerun":false,"art_audio_accepted":false,"new_hex_admission":false,"e1_original_pause_remainder_fixed":false,"explicit_fixture_SP":6,"explicit_b09_fixture_gold":500}
 if not output_path.is_empty():
  var file := FileAccess.open(output_path,FileAccess.WRITE)
  if file == null: push_error("ordinary report write failed"); quit(2); return
  file.store_string(JSON.stringify(report," ")+"\n")
 print("INK_P2_ORDINARY_REPORT ",JSON.stringify(report))
 quit(0 if report.passed else 1)
