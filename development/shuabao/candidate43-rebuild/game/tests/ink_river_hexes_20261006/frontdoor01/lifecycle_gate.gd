extends "res://tests/ink_river_hexes_20261006/ordinary01/finite_gate.gd"
const FrontdoorHost=preload("res://tests/ink_river_hexes_20261006/frontdoor01/finite_host.gd")
const FrontdoorBinding=preload("res://tests/ink_river_hexes_20261006/frontdoor01/live_binding.gd")
const ActualChooser=preload("res://scripts/ui/hero_chooser.gd")
const FRONTDOOR_GROUPS=["exact_entry_whitelist_and_same_sim", "one_frontdoor_suspend_resume_close"]
func _initialize() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--river-frontdoor-result="):output_path=arg.trim_prefix("--river-frontdoor-result=")
 run.call_deferred()

func open_room(seed: int):
 serial+=1
 var room=FrontdoorHost.new();root.add_child(room)
 var sim=room._make_floor_sim();room.sim=sim;room.add_child(sim);sim.ai_enabled=false
 session=room._make_floor_session();room.shop_session=session
 room.input_router=room._make_floor_router();room.input_router.bind(sim)
 room.audio_output=Audio.new();room.add_child(room.audio_output)
 room._mainprep_required=false;room._mainprep_pending=false
 room.hud=HUD.new();room.add_child(room.hud)
 check(room._install_source_navigation().accepted,"one current director admitted through actual Host factory")
 check(session.configure_reward_table(HOME+"reward_table.json",HOME+"rewards.csv",HOME+"validation_result.json",true).accepted,"original reward source configuration")
 var loaded: Dictionary=Session.MixedSchema.load_definition(Session.DEFAULT_DEFINITION,true)
 var result: Dictionary=session.initialize_floor(sim,loaded.definition,"river-ordinary-%d"%serial,true)
 if not check(result.accepted,"exact new Bridge/Session initializes"):
  room.free();session=null;return null
 var model=session.ledger.model
 check(model.state.level==1 and model.state.points==1 and model.state.gold==0 and model.state.xp==0 and model.state.selected_hex.is_empty(),"ordinary zero-resource start remains unchanged")
 check(session._owner_intact() and is_same(sim.progression,session.ledger),"one true wallet/health/skill owner")
 var pool: Dictionary=model.initial_pool_readiness()
 check(pool.eligible==12 and pool.personal==6 and pool.common==6,"actual initial pool contains only six personal and six retained common effects")
 # Explicit bounded allocator-seed fixture, before any offer. We never edit
 # slots, selected_hex, SP or learned skills to manufacture an owned Hex.
 model.state.rng=seed
 session.bind_input_suspender(room.input_router.suspend_input)
 sim.combat_event.connect(on_event);sim.encounter_finished.connect(on_terminal)
 room._create_session_controls();await process_frame
 room.initial_controller.ensure_auto_hex()
 return room

func run() -> void:
 var room=await open_room(1)
 if room==null:
  quit(2);return
 var sim=room.sim
 var binding: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FrontdoorBinding.BINDING_PATH))
 for path: String in FrontdoorBinding.ENTRY_PATHS:
  check(FileAccess.get_sha256(path)==str(binding.ancestor_pin_replacements[path].after),"actual staged entry matches explicit planned after bytes "+path)
 check(sim.get_script().resource_path==Binding.SIM_PATH and sim.get_script().resource_path==FrontdoorBinding.SIM_PATH,"frontdoor uses the exact already tested ordinary Sim")
 check(FrontdoorBinding.read_capabilities(sim,true).accepted,"new admission covers only the two current entry replacements")
 check(not Binding.read_capabilities(sim,true).accepted,"frozen ordinary binding does not falsely cover changed default files")
 check(session.get_script().resource_path=="res://tests/ink_river_hexes_20261006/frontdoor01/floor_session.gd","actual default entry chooses only the new admission Session leaf")
 check(is_same(sim.progression,session.ledger) and session._owner_intact(),"unchanged source Sim retains one real ledger/Session owner")
 var caps: Dictionary=FrontdoorBinding.read_capabilities(sim,true).capabilities
 check(caps.ordinary_entry_ready==false and ActualChooser.can_enter("yanguizhou"),"legacy candidate-scope field is not the chooser enter gate")
 check(caps.runtime_candidates==Catalog.FIRST_SLICE_ALLOWED_CANDIDATES and "P3" not in caps.runtime_candidates,"frontdoor cannot add P3 or another skill")
 check(Catalog.FIRST_SLICE_HEX_HOOKS.size()==12 and "hex.final_design.yanguizhou_h03.v1" in caps.supported_hooks and "hex.final_design.yanguizhou_h04.v1" in caps.supported_hooks,"same twelve-hook ordinary scope")
 check(ActualChooser.can_enter("yanguizhou") and ActualChooser.ROOMS.yanguizhou=="res://scenes/integration/yanguizhou_first_floor.tscn","actual chooser retains established Ink scene destination")
 check(ActualChooser.can_enter("xuanlei") and ActualChooser.can_enter("fengli") and not ActualChooser.can_enter("huling") and not ActualChooser.can_enter("hezi") and not ActualChooser.can_enter("miluo"),"all other hero availability branches remain unchanged")
 check(ActualChooser.hero_note("xuanlei")==ActualChooser.NOTES.xuanlei and ActualChooser.hero_note("fengli")==ActualChooser.NOTES.fengli,"other hero note branches remain unchanged")
 completed.append(FRONTDOOR_GROUPS[0]);print("INK_RIVER_FRONTDOOR_GROUP ",FRONTDOOR_GROUPS[0])
 room.initial_hud.adapter.request("hex_select",{"milestone":1,"slot":3})
 check(room.initial_controller.last_result.accepted,"real current mandatory Hex selection")
 learn_q2(room)
 if enter(room,1,"r01a"):
  var owner: int=session.ledger.get_instance_id();var clock_id: int=sim.clock.get_instance_id();var director_id: int=sim.enemy_director.get_instance_id()
  var a: Vector3=sim.hero.position+Vector3(0,0,-1)
  check(place(room,a).accepted,"real default-factory source places incomplete Q2 A")
  check(room.input_router.handle_event(key(KEY_Q),a+Vector3(0,0,-3)).accepted,"actual B preview armed before frontdoor suspension")
  room.input_router.handle_event(key(KEY_Q,false),a)
  var marker: Dictionary=sim.ink_q2_pending.duplicate(true)
  var clock_before: Dictionary=sim.clock.domain.snapshot()
  var casts: int=sim.cast_serial
  room.frontdoor_suspend();room.frontdoor_suspend();sim.step(0.1)
  check(room._frontdoor_suspended and sim.paused and room.input_router.q2_aim.is_empty(),"one unchanged frontdoor layer suspends and clears intent idempotently")
  check(sim.clock.domain.snapshot()==clock_before and sim.ink_q2_pending==marker,"frontdoor suspension freezes original marker and world authority")
  room.frontdoor_resume();room.frontdoor_resume()
  check(not room._frontdoor_suspended and not sim.paused and sim.cast_serial==casts and sim.ink_q2_pending==marker,"idempotent resume creates no cast and preserves committed A")
  check(session.ledger.get_instance_id()==owner and sim.clock.get_instance_id()==clock_id and sim.enemy_director.get_instance_id()==director_id and session._owner_intact(),"same Session/ledger/clock/director through suspend and resume")
  check(room.frontdoor_close_run("finite_frontdoor_close"),"actual default adapter closes original Session without application quit")
  check(room.finished and room.finite_close_reasons==["finite_frontdoor_close"] and room.frontdoor_last_close.evidence_only and not room.frontdoor_last_close.global_progress_saved,"close executes once with explicit diagnostic-only sink")
  check(room.frontdoor_close_run("duplicate_close") and room.finite_close_reasons.size()==1,"duplicate close cannot repeat Session/evidence side effects")
  check(sim.ink_q2_pending.is_empty() and sim.ink_rivers.is_empty() and room.input_router.q2_aim.is_empty(),"close retires pending marker and input ownership")
 completed.append(FRONTDOOR_GROUPS[1]);print("INK_RIVER_FRONTDOOR_GROUP ",FRONTDOOR_GROUPS[1])
 var report: Dictionary={"schema":"ink-river-frontdoor-lifecycle-1","passed":failures.is_empty() and completed==FRONTDOOR_GROUPS,"checks":checks,"completed":completed,"failures":failures,"source_binding_sha256":FileAccess.get_sha256(FrontdoorBinding.BINDING_PATH),"same_ordinary_sim":true,"gameplay_matrix_rerun":false,"graphics_warmup":false,"diagnostic_sink_stubbed":true,"default_click_native":false,"window_close_signal":false,"other_heroes_played":false,"production_R_changed":false,"temporary_stage_aliases":true,"full_floor":false,"art_audio_accepted":false,"real_multiplayer":false}
 sim.combat_event.disconnect(on_event);sim.encounter_finished.disconnect(on_terminal);room.free();session=null
 if not output_path.is_empty():
  var file:=FileAccess.open(output_path,FileAccess.WRITE)
  if file==null:push_error("cannot_write_frontdoor_result");quit(2);return
  file.store_string(JSON.stringify(report,"  "));file.close()
 print("INK_RIVER_FRONTDOOR_RESULT ",JSON.stringify(report));quit(0 if report.passed else 1)
