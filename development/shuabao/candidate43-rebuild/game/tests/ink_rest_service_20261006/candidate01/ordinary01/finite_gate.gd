extends SceneTree
## Narrow integration fixture only. Existing 85-check service matrix is frozen.
## Legal route entry uses explicit source-damage fixtures; not natural play.
const Production = preload("res://scripts/integration/yanguizhou_first_floor.gd")
const FixtureHost = preload("res://tests/ink_rest_service_20261006/candidate01/ordinary01/finite_host.gd")
const Session = preload("res://tests/ink_rest_service_20261006/candidate01/ordinary01/floor_session.gd")
const Binding = preload("res://tests/ink_rest_service_20261006/candidate01/ordinary01/live_binding.gd")
const OldBinding = preload("res://tests/ink_p1_ordinary_20261006/candidate01/ordinary01/live_binding.gd")
const OldSim = preload("res://tests/ink_r1_ordinary_20261005/candidate01/sim.gd")
const Audio = preload("res://tests/ink_style_specimen_20261004/audio_output.gd")
const HOME := "res://tests/ink_first_floor_user_route_20261005/runtime01/"
const LEAF := "res://tests/ink_rest_service_20261006/candidate01/ordinary01/"
const REQUIRED := ["exact_rest_production_factories_and_complete_admission","legal_rest_entry_and_actual_visible_prompt","production_menu_continue_and_service_departure_no_refill"]
var checks := 0
var failures: Array[String] = []
var groups: Array[String] = []
var output_path := "user://ink_rest_ordinary_finite.json"
var serial := 0
var live_session: RefCounted
var event_errors: Array = []
func _initialize() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--rest-ordinary-result="): output_path = arg.trim_prefix("--rest-ordinary-result=")
 run.call_deferred()
func check(ok: bool, label: String) -> bool:
 checks += 1
 if not ok: failures.append(label); push_error(label)
 return ok
func _on_event(event: Dictionary) -> void:
 var result: Dictionary = live_session.observe_event(live_session.sim,event)
 if event.get("kind","") in ["damage","kill"] and not result.accepted: event_errors.append(result)
func _on_terminal(event: Dictionary) -> void:
 live_session.queue_terminal(live_session.sim,event)
func command(action: String, args: Dictionary) -> Dictionary:
 serial += 1
 var result: Dictionary = live_session.ledger.model.command("rest-ordinary-fixture-%d"%serial,action,args)
 live_session.progression_command_completed({"action":action,"args":args},result)
 live_session.update_after_source_step()
 return result
func choices() -> void:
 for milestone in live_session.ledger.model.snapshot().pending_milestones.duplicate():
  check(command("hex_open",{"milestone":milestone}).accepted,"actual mandatory Hex offer opens")
  check(command("hex_select",{"milestone":milestone,"slot":3}).accepted,"actual mandatory Hex choice settles")
func enter(row: int, node_id: String) -> bool:
 choices()
 if not check(live_session.select_node(row,node_id).accepted,"connected route selection "+node_id): return false
 var result: Dictionary = live_session.enter_selected_node()
 return check(result.accepted,"committed entry "+node_id+": "+str(result.get("reason","")))
func finish_combat(sim: Node) -> bool:
 for _i in range(80): sim.step(.02); live_session.update_after_source_step()
 for enemy: Dictionary in sim.living().duplicate():
  sim.damage_enemy(enemy,1000000.0,"rest_ordinary_gate_fixture",0,true,false,{"direct":false,"no_reactions":true})
 sim.step(.02); live_session.update_after_source_step()
 choices()
 return check(live_session.status == "between_rooms" and sim.phase == "victory" and event_errors.is_empty(),"actual authority accepts bounded fixture combat terminal")
func resources() -> Dictionary:
 var state: Dictionary = live_session.ledger.model.snapshot()
 return {"gold":state.gold,"xp":state.xp,"points":state.points,"level":state.level,"inventory":state.inventory.duplicate(true),"body":state.body.duplicate(true),"skills":state.skills.duplicate(true),"hexes":state.selected_hex.duplicate(true),"flasks":state.shop_visit.flask_charges}
func run() -> void:
 var room = FixtureHost.new(); root.add_child(room)
 var sim: Node = room._make_floor_sim(); room.sim = sim; room.add_child(sim); sim.ai_enabled = false
 var session: RefCounted = room._make_floor_session(); room.shop_session = session; live_session = session
 room.input_router = room._make_floor_router(); room.input_router.bind(sim)
 room.audio_output = Audio.new(); room.add_child(room.audio_output)
 room._mainprep_required = false; room._mainprep_pending = false
 var production_script: GDScript = Production
 var sim_script: GDScript = sim.get_script()
 var session_script: GDScript = session.get_script()
 var router_script: GDScript = room.input_router.get_script()
 check(production_script.get_base_script().resource_path == LEAF+"host.gd","production adapter directly inherits explicit Rest ordinary host")
 check(sim_script.resource_path == Binding.SIM_PATH and session_script.resource_path == LEAF+"floor_session.gd","production factories keep exact P1 Sim and select successor Rest Session")
 check(router_script.resource_path == "res://tests/ink_r1_ordinary_20261005/candidate01/ordinary01/input_adapter.gd","original Q/E/R router retained")
 var nav_id: int = sim.enemy_director.get_instance_id()
 check(room._install_source_navigation().accepted,"ordinary startup navigation independently admits new Rest overlay")
 check(not room._install_source_navigation().accepted and sim.enemy_director.get_instance_id() == nav_id,"navigation has same director and refuses second admission")
 var caps: Dictionary = Binding.read_capabilities(sim,true)
 check(caps.accepted and caps.capabilities.runtime_candidates == ["Q1","Q2","Q3","E1","P1","R1"],"new binding verifies complete parent closure without expanding candidates")
 check(not OldBinding.read_capabilities(sim,true).accepted,"frozen P1 binder still rejects changed production bytes")
 var old = OldSim.new(); root.add_child(old)
 check(not Binding.read_capabilities(old,true).accepted,"successor keeps exact P1 Sim requirement"); old.free()
 check(session.configure_reward_table(HOME+"reward_table.json",HOME+"rewards.csv",HOME+"validation_result.json",true).accepted,"same original reward table configured")
 var definition: Dictionary = Session.MixedSchema.load_definition(Session.DEFAULT_DEFINITION,true)
 var initialized: Dictionary = session.initialize_floor(sim,definition.definition,"rest-ordinary-finite-%d"%Time.get_ticks_usec(),true)
 if check(initialized.accepted,"selected Session and Bridge both admit successor: "+str(initialized.get("reason",""))):
  var bridge_script: GDScript = session.ledger.get_script()
  check(bridge_script.resource_path == LEAF+"bridge.gd" and session._owner_intact() and is_same(sim.progression,session.ledger),"one successor Bridge remains same economy/HP/reward owner")
  var fresh: Dictionary = session.ledger.model.snapshot()
  check(fresh.level == 1 and fresh.gold == 0 and fresh.xp == 0 and fresh.points == 1 and fresh.inventory.is_empty() and fresh.selected_hex.is_empty(),"default ordinary resources stay Lv1 zero gold/XP original 1SP")
  session.bind_input_suspender(room.input_router.suspend_input)
  sim.combat_event.connect(_on_event); sim.encounter_finished.connect(_on_terminal)
  groups.append("exact_rest_production_factories_and_complete_admission")
  choices(); check(session.learn_q1().accepted,"only original SP learns Q1 in explicit route fixture")
  room._create_session_controls()
  await process_frame
  room._refresh_session_controls(true)
  check(room.session_hint.is_visible_in_tree() and room.session_hint.text.contains(room.REST_RULE_TEXT) and not room.session_hint.text.contains(room.REST_SETTLED_TEXT) and not room.session_hint.text.contains(room.OLD_REST_TEXT),"real initial control shows rule only and removes obsolete no-heal text")
  if enter(1,"r01a") and finish_combat(sim) and enter(2,"r02a") and finish_combat(sim):
   exercise_rest(room,sim)
  session.close_run()
  room._refresh_session_controls(true)
  check(not room.session_hint.text.contains(room.REST_SETTLED_TEXT),"closed run cannot display a current settled rest")
  sim.combat_event.disconnect(_on_event); sim.encounter_finished.disconnect(_on_terminal)
 live_session = null
 room.free()
 for group: String in REQUIRED: check(group in groups,"required group completed: "+group)
 var report: Dictionary = {"passed":failures.is_empty(),"checks":checks,"failures":failures,"groups":groups,"binding":FileAccess.get_sha256(Binding.BINDING_PATH),"gate_sha256":FileAccess.get_sha256(get_script().resource_path),"scope":"new production admission, real controls, committed route fixture, production suspend/resume","service_85_matrix_rerun":false,"explicit_damage_fixture":true,"native_input":false,"natural_progression":false,"full_floor":false,"flask_consumer_opened":false}
 var file := FileAccess.open(output_path,FileAccess.WRITE)
 if file == null: failures.append("result_file_write_failed"); report.passed = false
 else: file.store_string(JSON.stringify(report,"  ")); file.close()
 print("INK_REST_ORDINARY_REPORT ",JSON.stringify(report))
 quit(0 if report.passed else 1)
func exercise_rest(room: Node, sim: Node) -> void:
 var session: RefCounted = live_session
 sim.hero.hp = 123.0; sim.observe_pending_health(); sim.hero.cooldowns.r = 31.0
 sim.hero.shields["ordinary_fixture"] = {"amount":13.0,"left":7.0}
 var before: Dictionary = resources()
 check(session.select_node(3,"r03a").accepted,"real connected rest selected after two settled rows")
 room._refresh_session_controls(true)
 check(room.session_hint.text.contains(room.REST_RULE_TEXT) and session.rest_service.snapshot().is_empty() and sim.hero.hp == 123.0,"selection and real UI refresh cannot claim or apply settlement")
 sim.transaction_active = true
 check(not session.enter_selected_node().accepted,"in-flight entry is rejected before rest")
 sim.transaction_active = false
 room._refresh_session_controls(true)
 check(room.session_hint.text.contains(room.REST_RULE_TEXT) and session.rest_service.snapshot().is_empty(),"rejected entry still displays rule only")
 var entered: Dictionary = session.enter_selected_node()
 if not check(entered.accepted,"real legal rest entry uses inherited proven settlement"): return
 room._refresh_session_controls(true)
 check(room.session_hint.is_visible_in_tree() and room.session_hint.text.contains(room.REST_SETTLED_TEXT) and not room.session_hint.text.contains(room.OLD_REST_TEXT),"actual visible control confirms this committed rest")
 check(sim.hero.hp == sim.hero.stats.max_hp and sim.hero.cooldowns.r == 0.0 and sim.hero.shields.is_empty(),"new ordinary wiring reaches original proven rest service")
 check(resources() == before and session.rest_service.snapshot().size() == 1,"rest preserves ordinary resources and settles once")
 groups.append("legal_rest_entry_and_actual_visible_prompt")
 sim.hero.hp -= 17.0; sim.observe_pending_health(); sim.hero.cooldowns.q = 12.0
 var hp: float = sim.hero.hp; var revision: int = sim.equipment_health_revision
 var receipt: Array = session.rest_service.snapshot(); var ledger_id: int = session.ledger.get_instance_id()
 var after: Dictionary = resources(); var run_id: String = session.run_id
 var active_room: String = session.active_node_room; var entry: Dictionary = session._active_entry.duplicate(true)
 for _i in range(2):
  room.frontdoor_suspend(); room.frontdoor_suspend()
  check(room._frontdoor_suspended and sim.paused,"production menu suspends source exactly once")
  room._refresh_session_controls(true)
  room.frontdoor_resume(); room.frontdoor_resume()
  room._refresh_session_controls(true)
  check(not room._frontdoor_suspended and not sim.paused,"production Continue restores prior pause state")
 sim.paused = true; room.audio_output.set_paused(true)
 room.frontdoor_suspend(); room.frontdoor_resume(); room.frontdoor_resume()
 check(sim.paused and room.audio_output.router.paused and not room._frontdoor_suspended,"menu Continue preserves an already-paused run and audio")
 check(session.explicit_resume().accepted,"separate explicit gameplay Continue resumes a pre-paused run")
 room.audio_output.set_paused(false)
 room._refresh_session_controls(true)
 check(sim.hero.hp == hp and sim.hero.cooldowns.q == 12.0 and sim.equipment_health_revision == revision,"repeated actual frontdoor suspend/Continue never refills HP/CD")
 check(resources() == after and session.rest_service.snapshot() == receipt,"menu and control refresh grant no resources or new rest receipt")
 check(session.ledger.get_instance_id() == ledger_id and session.run_id == run_id and session.active_node_room == active_room and session._active_entry == entry and session._owner_intact(),"menu Continue preserves run, room, entry and single owner")
 check(room.session_hint.text.contains(room.REST_SETTLED_TEXT),"same rest area keeps truthful settled receipt display")
 check(session.complete_service().accepted,"original service readiness completes")
 room._refresh_session_controls(true)
 check(room.session_hint.text.contains(room.REST_SETTLED_TEXT),"readiness does not claim departure from rest area")
 if not enter(4,"r04a"): return
 room._refresh_session_controls(true)
 check(room.session_hint.text.contains(room.REST_RULE_TEXT) and not room.session_hint.text.contains(room.REST_SETTLED_TEXT),"actual non-rest departure returns to rule text")
 check(sim.hero.hp == hp and sim.hero.cooldowns.q == 12.0 and resources() == after and session.rest_service.snapshot() == receipt,"training entry does not repeat rest or grant bottle resources")
 groups.append("production_menu_continue_and_service_departure_no_refill")
