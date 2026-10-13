extends SceneTree
const Host=preload("res://tests/ink_river_hexes_20261006/ordinary01/finite_host.gd")
const Session=preload("res://tests/ink_river_hexes_20261006/ordinary01/floor_session.gd")
const Binding=preload("res://tests/ink_river_hexes_20261006/ordinary01/live_binding.gd")
const Catalog=preload("res://tests/ink_river_hexes_20261006/ordinary01/catalog.gd")
const QHUD=preload("res://tests/ink_river_hexes_20261006/ordinary01/hud_projection.gd")
const EHUD=preload("res://tests/ink_river_hexes_20261006/ordinary01/e_hud.gd")
const RHUD=preload("res://tests/ink_river_hexes_20261006/ordinary01/r_hud.gd")
const OldBinding=preload("res://tests/ink_r2_ordinary_20261006/candidate01/live_binding.gd")
const Audio=preload("res://tests/ink_style_specimen_20261004/audio_output.gd")
const HUD=preload("res://tests/ink_style_specimen_20261004/revision10_hud/hud.gd")
const HOME="res://tests/ink_first_floor_user_route_20261005/runtime01/"
const REQUIRED_GROUPS=["actual_hex_pool_choice_learning_undo","h03_owned_physical_input_and_menu","h04_authoritative_functional_view","single_session_room_retirement"]
var checks: int=0
var failures: Array[String]=[]
var completed: Array[String]=[]
var observations: Dictionary={}
var event_errors: Array=[]
var session: RefCounted
var serial: int=0
var output_path: String=""

func _initialize() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--river-ordinary-result="): output_path=arg.trim_prefix("--river-ordinary-result=")
 run.call_deferred()
func check(ok: bool,label: String) -> bool:
 checks+=1
 if not ok: failures.append(label); push_error(label)
 return ok
func near(a: float,b: float,label: String) -> void: check(is_finite(a) and absf(a-b)<0.0001,label+" actual="+str(a)+" expected="+str(b))
func done_group(name: String) -> void: completed.append(name); print("INK_RIVER_ORDINARY_GROUP ",name)
func key(code: int, down: bool=true) -> InputEventKey:
 var e:=InputEventKey.new();e.physical_keycode=code;e.pressed=down;return e
func mouse(down: bool=true, corner: bool=false) -> InputEventMouseButton:
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.ctrl_pressed=corner;return e
func on_event(event: Dictionary) -> void:
 var result: Dictionary=session.observe_event(session.sim,event)
 if event.get("kind","") in ["damage","kill"] and not result.accepted: event_errors.append(result)
func on_terminal(value: Dictionary) -> void: session.queue_terminal(session.sim,value)

func open_room(seed: int):
 serial+=1
 var room=Host.new();root.add_child(room)
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

func close_room(room) -> void:
 session.close_run();room.sim.combat_event.disconnect(on_event);room.sim.encounter_finished.disconnect(on_terminal)
 room.free();session=null

func chosen_room(id: String):
 for seed: int in range(1,17):
  var room=await open_room(seed)
  if room==null:return null
  for refresh: int in [-1,0,1,2,3]:
   if refresh>=0:
    room.initial_hud.adapter.request("hex_refresh",{"milestone":1,"slot":refresh})
    check(room.initial_controller.last_result.accepted,"actual one-use initial Hex refresh")
   var slots: Array=session.ledger.model.state.offers["1"].slots
   if id not in slots:continue
   room.initial_hud.adapter.request("hex_select",{"milestone":1,"slot":slots.find(id)})
   check(room.initial_controller.last_result.accepted and session.ledger.model.state.selected_hex==[id],"actual offer command owns "+id)
   check(not room.sim.hx(id),"selected Q2 Hex dormant before paid Q2")
   observations[id+"_allocator"]={"seed_fixture":seed,"offer":slots.duplicate(),"ordinary_random_claim":false}
   return room
  close_room(room)
 check(false,"bounded actual allocator found requested Hex "+id)
 return null

func learn_q2(room) -> void:
 room.initial_hud.q_choices.Q2.upgrade.pressed.emit()
 check(room.initial_controller.last_result.accepted and room.sim.hero.loadout.q=="q2" and room.sim.hero.ranks.q==1 and session.ledger.model.state.points==0,"real growth Button spends original single SP on Q2")
 room.initial_hud.close_panels()

func enter(room,row: int,id: String) -> bool:
 var selected: Dictionary=session.select_node(row,id);room._transition_result("select_node",selected)
 if not check(selected.accepted,"real route selects "+id):return false
 var entered: Dictionary=session.enter_selected_node();room._transition_result("enter_selected_node",entered)
 check(room.initial_hud.adapter.state.revision==session.ledger.model.state.revision,"Host publishes actual ledger revision after entry")
 return check(entered.accepted and room.sim.phase=="combat","actual Session enters "+id)

func place(room,point: Vector3) -> Dictionary:
 var router=room.input_router
 check(router.handle_event(key(KEY_Q),point).accepted,"fresh physical Q arms current placement")
 router.handle_event(key(KEY_Q,false),point)
 var result: Dictionary=router.handle_event(mouse(),point)
 router.handle_event(mouse(false),point)
 return result

func pool_learning() -> void:
 var room=await chosen_room("yanguizhou_h03")
 if room==null:return
 var sim=room.sim;var model=session.ledger.model
 check(Binding.read_capabilities(sim,true).accepted and not OldBinding.read_capabilities(sim,true).accepted,"new exact Sim admitted without spoofing old R2 binding")
 check(Catalog.FIRST_SLICE_HEX_HOOKS.size()==12 and Catalog.FIRST_SLICE_ALLOWED_CANDIDATES==["Q1","Q2","Q3","E1","E2","E3","P1","P2","R1","R2"],"only H03/H04 capability hooks added; P3 stays locked")
 for number: int in range(7,17):
  var id: String="yanguizhou_h%02d"%number
  check(not model.support(session.ledger.definitions.hexes[id]).supported,"unconnected Hex remains locked "+id)
 var before: Dictionary=model.snapshot()
 room.initial_hud.adapter.request("learn",{"slot_id":"P","candidate_id":"P3","expected_rank":0})
 check(not room.initial_controller.last_result.accepted and model.snapshot()==before,"actual P3 choice remains rejected without spending")
 learn_q2(room);check(sim.hx("yanguizhou_h03"),"paid Q2 activates actual chosen H03")
 check(QHUD.apply_to(room.hud,sim).h03_owned and QHUD.input_help(sim).contains("Ctrl"),"actual owned H03 supplies input help")
 room.initial_hud.undo_button.pressed.emit()
 check(room.initial_controller.last_result.accepted and sim.hero.ranks.q==0 and model.state.points==1,"safe undo uses original skill journal")
 check(not sim.hx("yanguizhou_h03") and not QHUD.input_help(sim).contains("Ctrl"),"undo restores dormant Hex and removes actionable corner help")
 learn_q2(room)
 check(EHUD.apply_to(room.hud,sim).accepted and RHUD.apply_to(room.hud,sim).accepted,"new exact identity preserves existing E/R projections")
 close_room(room);done_group(REQUIRED_GROUPS[0])

func h03_input() -> void:
 var room=await chosen_room("yanguizhou_h03")
 if room==null:return
 learn_q2(room)
 if not enter(room,1,"r01a"):close_room(room);return
 var sim=room.sim;var router=room.input_router
 var a: Vector3=sim.hero.position+Vector3(0,0,-1)
 var b: Vector3=a+Vector3(0,0,-4)
 check(place(room,a).accepted,"ordinary selected H03 casts actual A")
 check(router.handle_event(key(KEY_Q),b).accepted,"B preview armed")
 router.handle_event(key(KEY_Q,false),b)
 check(router.handle_event(mouse(true,true),a+Vector3(1,0,-1)).accepted,"owned H03 Ctrl plus fresh click adds corner")
 check(not router.handle_event(mouse(true,true),a+Vector3(1,0,-2)).accepted,"duplicate physical down cannot append another corner")
 router.handle_event(mouse(false,true),b)
 var marker: Dictionary=sim.ink_q2_pending.duplicate(true);var clock_before: Dictionary=sim.clock.domain.snapshot()
 room.frontdoor_suspend();sim.step(0.5)
 check(sim.ink_q2_pending==marker and sim.clock.domain.snapshot()==clock_before,"ordinary menu freezes original marker and world clock")
 check(router.q2_aim.is_empty(),"menu removes B intent while source marker survives")
 room.frontdoor_resume()
 check(router.handle_event(key(KEY_Q),b).accepted,"fresh Q re-arms preserved marker after menu")
 router.handle_event(key(KEY_Q,false),b)
 check(router.handle_event(mouse(true,true),a+Vector3(1,0,-3)).accepted,"second fresh corner keeps original A/root")
 router.handle_event(mouse(false,true),b)
 check(router.handle_event(mouse(),b).accepted,"unmodified fresh click completes B")
 router.handle_event(mouse(false),b)
 check(sim.ink_rivers.size()==1 and sim.ink_rivers[0].path.size()==4,"one actual river contains all three legs")
 near(sim.hero.cooldowns.q,10.5,"legal B starts source cooldown once")
 check(not sim.ink_rivers[0].h04_at_completion and sim.ink_presenter_snapshot().h04_sunsets.is_empty(),"H03 ownership cannot manufacture H04")
 room._ensure_river_view();room.q2_river_view.present_source(sim.ink_presenter_snapshot(),{})
 check(room.q2_river_view.river_sample.active[0].path.size()==4,"actual Host-selected functional view consumes all river legs")
 close_room(room);done_group(REQUIRED_GROUPS[1])

func h04_view_and_room() -> void:
 var room=await chosen_room("yanguizhou_h04")
 if room==null:return
 learn_q2(room)
 check(not QHUD.input_help(room.sim).contains("Ctrl") and not QHUD.apply_to(room.hud,room.sim).tooltip.contains("Ctrl"),"base Q2 help without owned H03 does not advertise corner input")
 if not enter(room,1,"r01a"):close_room(room);return
 var sim=room.sim;var owner: int=session.ledger.get_instance_id();var clock_id: int=sim.clock.get_instance_id();var director_id: int=sim.enemy_director.get_instance_id()
 var a: Vector3=sim.hero.position+Vector3(0,0,-1);var b: Vector3=a+Vector3(0,0,-3)
 check(place(room,a).accepted,"H04 ordinary A")
 room.input_router.handle_event(key(KEY_Q),b);room.input_router.handle_event(key(KEY_Q,false),b)
 var denied: Dictionary=room.input_router.handle_event(mouse(true,true),a+Vector3(1,0,-1))
 check(not denied.accepted and denied.reason=="requires_H03","unowned Ctrl click explicitly rejects instead of becoming B")
 room.input_router.handle_event(mouse(false,true),b)
 check(room.input_router.handle_event(mouse(),b).accepted,"ordinary B still completes after rejected corner")
 room.input_router.handle_event(mouse(false),b)
 room._ensure_river_view()
 var snapshot: Dictionary=sim.ink_presenter_snapshot()
 check(snapshot.h04_sunsets.size()==1 and snapshot.h04_sunsets[0].center==b,"authoritative H04 circle stays at actual B")
 near(snapshot.h04_sunsets[0].radius,3.5,"birth circle uses exact formal radius")
 room.q2_river_view.present_source(snapshot,{})
 check(room.q2_river_view.sunset_samples==snapshot.h04_sunsets,"actual Host view consumes exact source circle/tick fields")
 var authority: Dictionary=sim.clock.domain.snapshot();room.q2_river_view.present_source(snapshot,{})
 check(sim.ink_presenter_snapshot()==snapshot and sim.clock.domain.snapshot()==authority,"repeated view cannot change simulation or time")
 var requested_delta: float=0.25
 var source_before: Dictionary={"source_time":sim.hero_time,"world_time":sim.clock.world_time,"accumulator":sim.real_accumulator,"core_steps":sim.ink_core_steps,"clock_steps":sim.clock.advances}
 check(sim.clock.domain.snapshot().presentations.is_empty(),"clock fixture has no presentation time scale")
 sim.step(0.25);session.update_after_source_step();snapshot=sim.ink_presenter_snapshot()
 var source_after: Dictionary={"source_time":sim.hero_time,"world_time":sim.clock.world_time,"accumulator":sim.real_accumulator,"core_steps":sim.ink_core_steps,"clock_steps":sim.clock.advances}
 var admitted_steps: int=int(floor((float(source_before.accumulator)+requested_delta)/sim.FIXED_TICK))
 check(int(source_after.core_steps)-int(source_before.core_steps)==admitted_steps,"only complete fixed budgets enter core")
 check(int(source_after.clock_steps)-int(source_before.clock_steps)==admitted_steps,"one authority advance per admitted core budget")
 near(float(source_after.source_time)-float(source_before.source_time),float(admitted_steps)*sim.FIXED_TICK,"source time reflects admitted whole steps")
 near(float(source_after.world_time)-float(source_before.world_time),float(admitted_steps)*sim.FIXED_TICK,"world time reflects the same admitted whole steps")
 near(float(source_after.accumulator),float(source_before.accumulator)+requested_delta-float(admitted_steps)*sim.FIXED_TICK,"unadmitted real budget remains in original accumulator")
 check(float(source_after.accumulator)>=0.0 and float(source_after.accumulator)<sim.FIXED_TICK,"positive substep remainder is retained without an extra step")
 var sunset: Dictionary=snapshot.h04_sunsets[0]
 near(float(sunset.source_time),float(source_after.source_time),"functional snapshot uses actual accepted source time")
 var source_age: float=float(sunset.source_time)-float(sunset.born_at)
 check(source_age>=0.0 and source_age<4.0,"H04 age remains within formal four-second lifetime")
 # Independent formal arithmetic: lose 2.5 metres evenly over four source
 # seconds, and show the fractional completed half-second. No observed .24,
 # 3.35 or .48 is installed as a new expected constant.
 var expected_radius: float=3.5-(3.5-1.0)*source_age/4.0
 var half_seconds: float=source_age/0.5
 var expected_progress: float=half_seconds-floor(half_seconds)
 near(sunset.radius,expected_radius,"formal linear radius follows actual source age")
 near(sunset.tick_progress,expected_progress,"formal half-second phase follows actual source age")
 near(sunset.remaining,4.0-source_age,"remaining duration follows the same accepted source age")
 observations["first_step_timing"]={"requested_delta":requested_delta,"admitted_steps":admitted_steps,"fixed_tick":sim.FIXED_TICK,"before":source_before,"after":source_after,"source_age":source_age,"expected_radius":expected_radius,"expected_progress":expected_progress,"sunset":sunset.duplicate(true)}
 room.frontdoor_suspend();sim.step(0.3)
 var frozen: Dictionary=sim.ink_presenter_snapshot()
 near(frozen.h04_sunsets[0].radius,snapshot.h04_sunsets[0].radius,"pause freezes authoritative radius without hiding circle")
 near(frozen.h04_sunsets[0].tick_progress,snapshot.h04_sunsets[0].tick_progress,"pause freezes half-second phase")
 near(sim.real_accumulator,float(source_after.accumulator),"paused request preserves the existing unadmitted remainder")
 room.q2_river_view.present_source(frozen,{})
 check(room.q2_river_view.sunset_samples.size()==1,"paused actual circle remains visible")
 room.frontdoor_resume();sim.step(0.25);session.update_after_source_step();snapshot=sim.ink_presenter_snapshot()
 near(sim.hero_time-float(source_before.source_time),2.0*requested_delta,"resume admits original remainder and second unchanged request")
 near(sim.real_accumulator,0.0,"two unchanged requests leave no full-step remainder")
 near(snapshot.h04_sunsets[0].radius,3.1875,"first scheduled half-second radius")
 check(snapshot.h04_sunsets[0].scheduled_ticks==1,"exact first source tick observed in functional data")
 observations.h04_functional=snapshot.h04_sunsets.duplicate(true)
 done_group(REQUIRED_GROUPS[2])
 var generation: int=sim.encounter_generation
 # Declared high-damage route fixture: real damage/kill/Session settlement,
 # not a natural clear, direct dead flag or manual room-state assignment.
 for index in range(80): sim.step(0.02);session.update_after_source_step()
 for enemy: Dictionary in sim.living().duplicate():
  sim.damage_enemy(enemy,1000000.0,"river_ordinary_transition_fixture",0,true,false,{"direct":false,"no_reactions":true})
 for index in range(202):
  if sim.phase!="combat":break
  sim.step(0.02);session.update_after_source_step()
 check(sim.phase=="victory" and session.status=="between_rooms","real source lifetime and kill events release original Session terminal")
 check(sim.ink_rivers.is_empty() and sim.ink_presenter_snapshot().h04_sunsets.is_empty(),"room completion retires source river and sunset projection")
 for milestone in session.ledger.model.snapshot().pending_milestones.duplicate():
  room.initial_controller.ensure_auto_hex();room.initial_hud.adapter.request("hex_select",{"milestone":milestone,"slot":3})
  check(room.initial_controller.last_result.accepted,"real earned milestone remains mandatory")
 if enter(room,2,"r02a"):
  check(sim.encounter_generation==generation+1 and session._owner_intact(),"actual next row creates exactly one new generation")
  check(session.ledger.get_instance_id()==owner and sim.clock.get_instance_id()==clock_id and sim.enemy_director.get_instance_id()==director_id,"same Session, wallet, clock and director survive route transition")
  check(sim.ink_presenter_snapshot().h04_sunsets.is_empty() and room.input_router.q2_aim.is_empty(),"new room carries no old H04 circle or Q preview")
  check(sim.hx("yanguizhou_h04") and "yanguizhou_h04" in session.ledger.model.state.selected_hex,"actual chosen Hex persists as build ownership")
 check(event_errors.is_empty(),"original Session accepts real source damage/kill events")
 close_room(room);done_group(REQUIRED_GROUPS[3])

func run() -> void:
 await pool_learning();await h03_input();await h04_view_and_room()
 var report: Dictionary={"schema":"ink-river-ordinary-finite-1","passed":failures.is_empty() and completed==REQUIRED_GROUPS,"checks":checks,"completed":completed,"failures":failures,"observations":observations,"source_binding_sha256":FileAccess.get_sha256("res://tests/ink_river_hexes_20261006/ordinary01/fix01/source_binding.json"),"fixture_fix_only":true,"runtime_sim_and_view_unchanged":true,"new_hex_hooks":["H03","H04"],"P3_available":false,"default_cutover":false,"native_input":false,"natural_clear":false,"full_floor":false,"art_audio_accepted":false,"real_multiplayer":false}
 if not output_path.is_empty():
  var file:=FileAccess.open(output_path,FileAccess.WRITE)
  if file==null:push_error("cannot_write_river_ordinary_result");quit(2);return
  file.store_string(JSON.stringify(report,"  "));file.close()
 print("INK_RIVER_ORDINARY_RESULT ",JSON.stringify(report));quit(0 if report.passed else 1)
