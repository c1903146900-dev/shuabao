extends SceneTree
## Four bounded cross-component groups. No independent 610/316/215/237 rerun.
const Sim = preload("res://tests/ink_r2_ordinary_20261006/candidate01/sim.gd")
const Host = preload("res://tests/ink_r2_ordinary_20261006/candidate01/finite_host.gd")
const Session = preload("res://tests/ink_r2_ordinary_20261006/candidate01/floor_session.gd")
const Binding = preload("res://tests/ink_r2_ordinary_20261006/candidate01/live_binding.gd")
const Catalog = preload("res://tests/ink_r2_ordinary_20261006/candidate01/catalog.gd")
const HudProjection = preload("res://tests/ink_r2_ordinary_20261006/candidate01/hud_projection.gd")
const ECard = preload("res://tests/ink_r2_ordinary_20261006/candidate01/e_hud.gd")
const RCard = preload("res://tests/ink_r2_ordinary_20261006/candidate01/r_hud.gd")
const OldBinding = preload("res://tests/ink_ordinary_composed_20261006/candidate01/live_binding.gd")
const Audio = preload("res://tests/ink_style_specimen_20261004/audio_output.gd")
const HUD = preload("res://tests/ink_style_specimen_20261004/revision10_hud/hud.gd")
const PeaksView = preload("res://tests/ink_r2_ordinary_20261006/candidate01/peaks_view.gd")
const PeakValues = preload("res://tests/ink_r2_peaks_20261006/candidate01/tuning.gd")
const T = preload("res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_tuning.gd")
const TEST_BINDING_PATH := "res://tests/ink_r2_ordinary_20261006/candidate01/source_binding.json"
const HOME := "res://tests/ink_first_floor_user_route_20261005/runtime01/"
const LEAF := "res://tests/ink_r2_ordinary_20261006/candidate01/"
const REQUIRED_GROUPS: Array = ["r2_token_reentry_and_world_lifetime", "r2_with_p2_e1_pending_admission", "r2_p1_immunity_and_scope_retirement", "r2_ordinary_growth_input_view_and_rest"]
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
  if arg.begins_with("--r2-ordinary-result="): output_path = arg.trim_prefix("--r2-ordinary-result=")
 run.call_deferred()

func check(ok: bool, label: String) -> bool:
 checks += 1; group_checks[active_group] = int(group_checks.get(active_group,0))+1
 if not ok: failures.append(active_group+": "+label); push_error(active_group+": "+label)
 return ok

func near(a: float, b: float, label: String) -> void:
 check(is_finite(a) and absf(a-b)<0.0001,label+" actual="+str(a)+" expected="+str(b))

func done_group(name: String) -> void:
 check(name not in groups and int(group_checks.get(name,0))>0,"nonempty group completes once")
 groups.append(name); print("INK_R2_ORDINARY_GROUP ",name)

func fresh(passive: String = "p2"):
 serial += 1
 var sim = Sim.new(); root.add_child(sim)
 sim.auto_finish = false; sim.ai_enabled = false; sim.arena_half_extent = 30.0; sim.obstacles = []
 sim.hero.loadout.q = "q1"; sim.hero.ranks.q = 1
 sim.hero.loadout.e = "e1"; sim.hero.ranks.e = 1
 sim.hero.loadout.r = "r2"; sim.hero.ranks.r = 1
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
 check(sim.request_action("r",Vector3.ZERO).accepted,"real R2 enters independent presentation")
 check(sim.hero_damage_immune() and not sim.r1_active and sim._presentation.is_empty(),"presentation is separate from legacy whole-field immunity")

func rain(sim, count: int = 2) -> Dictionary:
 var enemies: Array = []
 for point: Vector3 in [Vector3(0.3,0,0),Vector3(0.3,0,1.5)].slice(0,count):
  var enemy: Dictionary = sim.spawn_enemy("minion",point,10000.0)
  enemy.state = "chase"; enemy.defence = 0.0; enemy.radius = 0.25
  enemies.append(enemy)
 var entry: Dictionary = sim.request_action("ink_e_down")
 check(entry.accepted,"real E1 entry during own R2 window")
 var state: Dictionary = sim.ink_rain
 sim.move_during_hitstop(0.02,Vector3.RIGHT)
 sim.hero.move_intent = Vector3.ZERO
 check(state.marks.has(enemies[0].actor_id) and (count == 1 or not state.marks.has(enemies[1].actor_id)),"actual normal-rate movement retains exact rain mark membership")
 return {"state":state,"id":entry.cast_id,"enemies":enemies,"world":sim.hero_time,"real":sim.clock.domain.snapshot().active_real_time,"advances":sim.clock.advances}

func clock_clean(sim, label: String) -> void:
 check(sim.presentation_errors.is_empty(),label+" has no clock admission error")
 check(sim.clock.advances == sim.ink_core_steps,label+" keeps one authority advance per core slice")

func p2_e1_clock() -> void:
 active_group = REQUIRED_GROUPS[1]
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
 sim.free(); done_group(REQUIRED_GROUPS[1])

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


func close_room(room) -> void:
 var sim = room.sim
 session.close_run(); sim.combat_event.disconnect(on_event); sim.encounter_finished.disconnect(on_terminal)
 room.free(); session = null

func mouse(down: bool = true, button: int = MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
 var out := InputEventMouseButton.new(); out.button_index = button; out.pressed = down; return out

func token_and_world() -> void:
 active_group = REQUIRED_GROUPS[0]
 var sim = fresh(); fill(sim)
 var target: Dictionary = sim.spawn_enemy("minion",Vector3.ZERO,100000.0)
 target.state = "chase"; target.defence = 0.0
 var second: Dictionary = sim.spawn_enemy("minion",Vector3(0.5,0,0),100000.0)
 second.state = "chase"; second.defence = 0.0
 var marker: Dictionary = {"created":false,"warning":false,"queued":false,"damage_hits":0}
 sim.combat_event.connect(func(event: Dictionary):
  if event.kind == "ink_r2_created":
   marker.created = true
   check(sim._r2_current(sim.ink_peaks) and sim.hero_damage_immune(),"R2 domain and immunity exist before outward created callback")
   check(sim._current_show.context.cast_id == event.cast_id and sim._current_show.token.ability_id == "yanguizhou_r2","token uses actual accepted R2 identity")
   near(float(sim._current_show.end)-float(sim._current_show.start),1.2,"R2 authoring uses exact 1.2 real-second short window")
  elif event.kind == "ink_r2_peak_warning" and not marker.warning:
   marker.warning = true
   var before: Dictionary = sim.clock.domain.snapshot()
   var core_before: int = sim.ink_core_steps
   sim.step(0.04)
   marker.queued = true
   check(sim.clock.domain.snapshot() == before and sim.ink_core_steps == core_before,"initial warning reentrant step returns without advancing authority or core")
   near(sim.hero_time,0.0,"warning reentry cannot advance world inside source event stack")
   near(sim.real_accumulator,0.04,"warning callback retains real request once in same accumulator")
   sim.paused = true
  elif event.kind == "damage" and event.get("source","") == "r2" and int(marker.damage_hits) < 2:
   marker.damage_hits = int(marker.damage_hits)+1; sim.paused = true)
 check(sim.r2_preview(Vector3.ZERO).accepted and sim._current_show.is_empty(),"read-only R2 preview has no token or domain")
 check(not sim.request_action("r",Vector3(13,0,0)).accepted and sim._current_show.is_empty(),"failed R2 placement cannot start presentation")
 cast_r(sim)
 check(marker.created and marker.queued and sim.paused and sim.ink_peaks.warnings == 1,"initial accepted warning pauses after safely queued reentry")
 var paused_state: Dictionary = sim.clock.domain.snapshot()
 sim.step(0.4); check(sim.clock.domain.snapshot() == paused_state,"held pause consumes neither queued nor incoming time")
 sim.paused = false; sim.step(0.02)
 near(sim.clock.domain.snapshot().active_real_time,0.06,"queued 0.04 plus next 0.02 admitted exactly once")
 near(sim.hero_time,0.015,"same domain applies quarter-speed world to accepted time")
 check(sim.clock.get_script().resource_path == Binding.CLOCK_PATH,"R2 uses original facade resource")
 sim.step(0.94)
 check(sim.paused and marker.damage_hits == 1 and sim.ink_r2_receipts.size() == 1,"first actual R2 HP packet pauses its original two-target batch")
 near(sim.hero_time,0.24,"first peak hit occurs on source world schedule inside presentation")
 near(sim.clock.domain.snapshot().active_real_time,0.96,"already consumed first-hit slice is recorded once")
 sim.paused = false; sim.step(0.02)
 check(sim.paused and marker.damage_hits == 2 and sim.ink_r2_receipts.size() == 2,"resumed original R2 batch commits second target exactly once")
 near(sim.hero_time,0.24,"second HP callback pause happens before any new core slice")
 near(sim.clock.domain.snapshot().active_real_time,0.96,"R2 pre-core pending callback cannot advance presentation")
 near(sim.real_accumulator,0.06,"unconsumed remainder and next request are retained once")
 sim.paused = false; sim.step(0.02)
 near(sim.clock.domain.snapshot().active_real_time,1.04,"R2 batch resumes accumulated 0.08 seconds exactly once")
 check(not sim.ink_r2_receipts.is_empty() and sim.p2.stacks == 3 and sim.ink_p2_claims.is_empty(),"real R2 positive damage cannot consume ready P2")
 check(sim.ink_p1_receipts.is_empty() and sim.p2.use_serial == 4,"R2 cannot create Q/E use or P1 receipt")
 sim.step(0.16)
 near(sim.clock.domain.snapshot().active_real_time,1.2,"short window reaches authored real deadline")
 near(sim.hero_time,0.3,"R2 field uses world time while presentation runs")
 check(sim.presentation_ends.size() == 1 and sim.presentation_ends[0].ability_id == "yanguizhou_r2" and not sim.hero_damage_immune(),"short window ends once with R2 identity and immunity stops")
 check(sim._r2_current(sim.ink_peaks) and sim.ink_peaks.expires_at == 5.0,"field stays current after presentation ends")
 near(sim.hero.cooldowns.r,145.0-0.3,"original cooldown ages on world time")
 sim.step(4.72)
 check(sim.ink_peaks.is_empty() and sim.ink_r2_finished.size() == 1,"normal source deadline finishes field without extending presentation")
 var finished: Dictionary = sim.ink_r2_finished[0]
 check(finished.peak_count == 7 and finished.warnings == 7 and finished.hits == 7 and finished.rollups == 1,"accepted rank1 retains seven original ordinals and one rollup")
 check(sim.ink_r2_receipts.size() == 16 and sim.ink_p2_claims.is_empty() and sim.ink_p1_receipts.is_empty(),"original R2 packets all settle without passive entitlement")
 for rank: int in range(1,5):
  var values: Dictionary = PeakValues.values(rank)
  check(int(values.peak_count) == [7,9,13,20][rank-1] and float(values.cooldown) == [145.0,136.0,121.0,101.0][rank-1],"frozen original R2 count and cooldown rank "+str(rank))
 clock_clean(sim,"R2 full field")
 observations.r2_lifetime = {"finished":finished,"ends":sim.presentation_ends.duplicate(true),"world":sim.hero_time,"active_real":sim.clock.domain.snapshot().active_real_time,"receipts":sim.ink_r2_receipts.size()}
 sim.free()
 var r1 = fresh(); r1.hero.loadout.r = "r1"
 check(r1.request_action("r",Vector3.ZERO).accepted,"same leaf still accepts actual R1")
 near(float(r1._current_show.end)-float(r1._current_show.start),1.0,"R1 keeps own one-second authoring in same domain")
 r1.step(1.0)
 check(r1.presentation_ends.size() == 1 and r1.presentation_ends[0].ability_id == "yanguizhou_r1" and r1._r1_current(r1.ink_snow),"R1 end identity and original ongoing field survive generalization")
 clock_clean(r1,"retained R1"); r1.free(); done_group(REQUIRED_GROUPS[0])

func p1_immunity_and_retirement() -> void:
 active_group = REQUIRED_GROUPS[2]
 var sim = fresh("p1"); cast_r(sim)
 var setup: Dictionary = rain(sim,1)
 var pause: Dictionary = {"original":false,"p1":false}
 sim.combat_event.connect(func(event: Dictionary):
  if event.kind == "damage" and event.get("source","") == "e1" and not pause.original:
   pause.original = true; sim.paused = true
  elif event.kind == "ink_p1_settled" and not pause.p1:
   pause.p1 = true; sim.paused = true)
 check(sim.request_action("ink_e_up").accepted and sim.paused,"R2 window retains real E1 original callback pause")
 check(sim.ink_p1_receipts.is_empty(),"P1 waits complete original E1 packets")
 sim.paused = false; sim.step(0.02)
 check(pause.p1 and sim.paused and sim.ink_e1_finished.size() == 1 and sim.ink_p1_receipts.size() == 1,"whole E1 finishes before P1 settlement callback")
 near(sim.hero_time,setup.world,"P1 callback pause precedes world-clock admission")
 near(sim.clock.domain.snapshot().active_real_time,setup.real,"P1 callback pause precedes actor-clock admission")
 sim.paused = false; sim.step(0.02)
 near(sim.hero_time,float(setup.world)+0.01,"P1 resumes both retained real budgets once")
 check(sim.ink_p2_claims.is_empty() and sim._e1_reform_pending.is_empty(),"P1 path leaves no P2 or E1 remainder")
 var hp: float = sim.hero.hp
 sim.damage_hero(100.0,Vector3.RIGHT,0.2,true,true)
 near(sim.hero.hp,hp,"R2 short window blocks actual incoming HP damage")
 check(not sim._ink_action_controlled("e"),"R2 short window blocks control")
 sim.step(1.2)
 check(not sim.hero_damage_immune() and sim._r2_current(sim.ink_peaks),"R2 field remaining does not extend immunity")
 sim.hero.cooldowns.e = 0.0
 check(sim.request_action("ink_e_down").accepted,"E1 form enters after short presentation")
 hp = sim.hero.hp; sim.damage_hero(100.0,Vector3.RIGHT,0.2,false,true)
 near(sim.hero.hp,hp-30.0,"outside presentation original E1 seventy-percent reduction remains")
 check(sim._ink_action_controlled("e"),"outside presentation E1 retains ordinary control vulnerability")
 check(sim.ink_p1_receipts.size() == 1 and sim.ink_r2_receipts.size() > 0,"R2 actual hits cannot manufacture additional P1 settlement")
 clock_clean(sim,"R2 P1 and immunity"); sim.free()
 var retired = fresh(); var saved: Dictionary = {}
 retired.combat_event.connect(func(event: Dictionary):
  if event.kind == "ink_r2_created":
   saved.token = retired._current_show.token.duplicate(true)
   saved.domain = retired.ink_peaks
   retired.end_encounter("r2-created-callback-retirement")
   check(retired.phase != "combat","real created callback retires encounter")
   check(retired.clock.domain.snapshot().presentations.is_empty(),"created callback clears current presentation authority"))
 var result: Dictionary = retired.request_action("r",Vector3.ZERO)
 check(result.accepted and result.cancelled_during_callback,"accepted original cast reports callback retirement")
 check(retired.begin_encounter("r2-new-scope",[]).accepted,"new scope begins after real action transaction unwinds")
 check(saved.domain.retired and retired.ink_peaks.is_empty() and retired._presentation_r2_cast_frames.is_empty(),"retired actual context cannot leave old R2 work")
 check(not retired.clock.domain.is_invulnerable(saved.token) and retired.clock.domain.snapshot().presentations.is_empty(),"old token cannot carry immunity to new scope")
 retired.step(0.04)
 check(retired.ink_r2_receipts.is_empty() and retired.presentation_errors.is_empty(),"new scope never settles retired R2 work")
 near(retired.clock.domain.snapshot().active_real_time,0.04,"new room admits only new requested time")
 retired.free(); done_group(REQUIRED_GROUPS[2])

func finish_fixture_combat(room) -> void:
 var sim = room.sim
 for _i in range(80): sim.step(0.02); session.update_after_source_step()
 for enemy: Dictionary in sim.living().duplicate():
  sim.damage_enemy(enemy,1000000.0,"r2_ordinary_route_fixture",0,true,false,{"direct":false,"no_reactions":true})
 sim.step(0.02); session.update_after_source_step(); choices(room)
 if sim.phase == "combat" and sim.living().is_empty():
  var deadline: float = sim.hero_time
  var sources: Array = []
  if sim._r2_current(sim.ink_peaks):
   deadline = maxf(deadline,float(sim.ink_peaks.expires_at))
   sources.append({"kind":"r2","born":sim.ink_peaks.born_at,"expires":sim.ink_peaks.expires_at})
  for vortex: Dictionary in sim.ink_vortices:
   check(sim.effect_is_current(vortex),"H02 terminal barrier belongs to actual room")
   deadline = maxf(deadline,float(vortex.expires_at))
   sources.append({"kind":"h02","born":vortex.born_at,"expires":vortex.expires_at})
  check(not sources.is_empty() and sim.hero_time < deadline and sim._hero_victory_pending(),"accepted world effects keep victory pending before source expiry")
  var rejected: Dictionary = session.select_node(2,"r02a")
  check(not rejected.accepted and rejected.reason == "floor_not_selectable","unfinished world effects keep next route unavailable")
  var show_remaining: float = maxf(0.0,float(sim._current_show.get("end",0.0))-float(sim.clock.domain.snapshot().active_real_time))
  var real_budget: float = maxf(0.0,deadline-sim.hero_time)+show_remaining*(1.0-sim.clock.scale_factor())
  var limit: int = ceili(real_budget/sim.FIXED_TICK)+2
  var steps: int = 0
  for _wait in range(limit):
   if sim.phase != "combat": break
   if not check(not sim.paused,"terminal wait preserves actual pause guard"): break
   sim.step(sim.FIXED_TICK); session.update_after_source_step(); steps += 1
  observations["terminal_wait_"+sim.room_id] = {"sources":sources,"deadline":deadline,"step_budget":limit,"actual_steps":steps,"terminal_world":sim.hero_time,"label":"declared high-damage fixture, authentic source expiry; no natural clear claim"}
  check(sim.phase == "victory" and session.status == "between_rooms","source deadlines release actual terminal and reward authority")
 check(session.status == "between_rooms" and event_errors.is_empty(),"route fixture settles through original Session")

func ordinary_route() -> void:
 active_group = REQUIRED_GROUPS[3]
 var room = await open_room()
 if room == null: return
 var sim = room.sim; var model = session.ledger.model
 var owner: int = session.ledger.get_instance_id(); var facade: int = sim.clock.get_instance_id(); var director: int = sim.enemy_director.get_instance_id()
 check(Binding.read_capabilities(sim,true).accepted and not OldBinding.read_capabilities(sim,true).accepted,"new R2 exact binding admits only its new leaf")
 check(Catalog.FIRST_SLICE_ALLOWED_CANDIDATES == ["Q1","Q2","Q3","E1","E2","E3","P1","P2","R1","R2"] and Catalog.FIRST_SLICE_HEX_HOOKS.size() == 10,"only R2 added; original ten Hex hooks retained")
 check(not "hex.final_design.yanguizhou_h15.v1" in Catalog.FIRST_SLICE_HEX_HOOKS and not "hex.final_design.yanguizhou_h16.v1" in Catalog.FIRST_SLICE_HEX_HOOKS,"H15/H16 remain locked")
 room.initial_hud.r2_choice.pressed.emit()
 check(not room.initial_controller.last_result.accepted and room.initial_controller.last_result.reason == "level_gate" and model.state.points == 1,"actual R2 first purchase retains Lv6 gate")
 room.initial_hud.p2_choice.pressed.emit()
 check(room.initial_controller.last_result.accepted and model.state.points == 0 and sim.hero.loadout.passive == "p2","P2 uses original one SP before explicit progression fixture")
 # Explicit Lv6/nine-SP integration fixture. It is not a production grant or
 # a natural progression claim; total R cost remains seven points for four ranks.
 model.state.level = 6; model.state.points = 9; model.state.granted_level_ids = [1,2,3,4,5,6]; model.state.revision += 1
 room.initial_controller.refresh(); choices(room)
 room.initial_hud.r2_choice.pressed.emit()
 check(room.initial_controller.last_result.accepted and model.state.points == 8 and sim.hero.loadout.r == "r2" and sim.hero.ranks.r == 1,"actual first R2 purchase spends one point")
 check(room.initial_hud.r1_choice.get_parent() == room.initial_hud.r2_choice.get_parent() and room.initial_hud.r1_choice.disabled,"both choices share one R row and R2 blocks R1")
 room.initial_hud.adapter.request("learn",{"slot_id":"R","candidate_id":"R1","expected_rank":1})
 check(not room.initial_controller.last_result.accepted and room.initial_controller.last_result.reason == "training_required" and model.state.points == 8,"original Model rejects same-slot R1 replacement")
 room.initial_hud.adapter.request("learn",{"slot_id":"Q","candidate_id":"Q1","expected_rank":0})
 check(room.initial_controller.last_result.accepted,"same controller learns original Q1")
 room.initial_hud.e3_choice.pressed.emit()
 check(room.initial_controller.last_result.accepted and model.state.points == 6,"E3 remains available through current ordinary controls")
 if not enter(room,1,"r01a"): close_room(room); return
 sim.hero.position = Vector3.ZERO
 for enemy: Dictionary in sim.enemies: enemy.position = Vector3(30,0,30); enemy.state = "chase"
 var router = room.input_router
 check(router.handle_event(key(KEY_R),Vector3.ZERO).accepted and sim.ink_peaks.is_empty() and sim._current_show.is_empty(),"actual R-down only arms R2 preview")
 router.handle_event(key(KEY_R,false),Vector3.ZERO)
 var preview: Dictionary = router.r1_preview_for_view(Vector3.ZERO)
 check(preview.accepted and preview.candidate == "r2" and preview.armed_identity.rank == 1,"preview reads selected R2 and actual rank")
 check(not router.handle_event(mouse(false),Vector3.ZERO).accepted and not router.r1_aim.is_empty(),"stray mouse-up cannot commit armed R2")
 room.initial_hud.r2_choice.pressed.emit()
 check(room.initial_controller.last_result.accepted and sim.hero.ranks.r == 2 and model.state.points == 4,"live second R2 purchase spends original two points")
 router.synchronize_preview()
 check(router.r1_aim.is_empty() and sim.ink_peaks.is_empty(),"live rank change retires old preview without casting")
 check(not router.handle_event(mouse(),Vector3.ZERO).accepted and sim.ink_peaks.is_empty(),"retired old-rank click cannot become R or BASIC")
 router.handle_event(mouse(false),Vector3.ZERO)
 for rank: int in [3,4]:
  room.initial_hud.r2_choice.pressed.emit()
  check(room.initial_controller.last_result.accepted and sim.hero.ranks.r == rank and model.state.points == 2*(4-rank),"R2 later rank has original two-SP cost "+str(rank))
 check(room.initial_hud.r2_choice.disabled and model.state.points == 0,"four-rank cap and exact seven total R points retained")
 check(router.handle_event(key(KEY_R),Vector3.ZERO).accepted,"fresh R2 preview after actual rank upgrade")
 router.handle_event(key(KEY_R,false),Vector3.ZERO)
 var cancelled: Dictionary = router.handle_event(mouse(true,MOUSE_BUTTON_RIGHT),Vector3.ZERO)
 check(cancelled.accepted and router.r1_aim.is_empty() and sim.ink_peaks.is_empty(),"right-click cancels only R2 preview")
 router.handle_event(mouse(),Vector3.ZERO); router.handle_event(mouse(false),Vector3.ZERO)
 check(router.handle_event(key(KEY_R),Vector3.ZERO).accepted,"new R-down re-arms after cancellation")
 router.handle_event(key(KEY_R,false),Vector3.ZERO)
 var committed: Dictionary = router.handle_event(mouse(),Vector3.ZERO)
 check(committed.accepted and sim._r2_current(sim.ink_peaks) and int(sim.ink_peaks.values.peak_count) == 20,"fresh click commits selected rank4 R2 domain")
 router.handle_event(mouse(false),Vector3.ZERO)
 var domain_id: String = sim.ink_peaks.domain_id; var token: Dictionary = sim._current_show.token.duplicate(true)
 check(not router.handle_event(key(KEY_R),Vector3.ZERO).accepted and sim.ink_peaks.domain_id == domain_id,"repeated R cannot recreate existing field")
 router.handle_event(key(KEY_R,false),Vector3.ZERO)
 var view = PeaksView.new(); room.add_child(view)
 var before_view: Dictionary = sim.ink_presenter_snapshot().duplicate(true)
 var before_clock: Dictionary = sim.clock.domain.snapshot()
 view.present_source(before_view,{})
 check(view.domain_sample.domain_id == domain_id and view.peak_samples.size() == 1 and view.peak_samples[0].phase == "warning","temporary R2 view shows real domain and current warning snapshot")
 view.present_source(before_view,{})
 check(sim.ink_presenter_snapshot() == before_view and sim.clock.domain.snapshot() == before_clock,"repeated functional view cannot mutate gameplay or clock")
 var selected_r: Dictionary = RCard.apply_to(room.hud,sim)
 check(selected_r.accepted and selected_r.candidate == "r2" and selected_r.rank == 4 and selected_r.active,"current R slot reads actual R2 rank and lifetime")
 check(selected_r.tooltip.contains("20簇") and selected_r.tooltip.contains("1.2秒") and selected_r.tooltip.contains("H15/H16") and selected_r.tooltip.contains("临时调试"),"card explains accepted counts/window/closed Hex and temporary art")
 check(HudProjection.apply_p_to(room.hud,sim).candidate == "p2" and HudProjection.apply_to(room.hud,sim).candidate == "q1" and ECard.apply_to(room.hud,sim).candidate == "e3","new exact Q/P/E consumers retain current selections")
 room.frontdoor_suspend(); var frozen: Dictionary = sim.clock.domain.snapshot(); sim.step(0.3)
 check(sim.clock.domain.snapshot() == frozen and sim.ink_peaks.domain_id == domain_id,"ordinary menu freezes window and keeps accepted R2 field")
 room.frontdoor_resume()
 finish_fixture_combat(room)
 check(sim.ink_r2_finished.size() == 1 and sim.ink_r2_finished[0].warnings == 20 and sim.ink_r2_finished[0].rollups == 1,"rank4 ordinary field completes original twenty ordinals and one rollup")
 check(not sim.clock.domain.is_invulnerable(token) and sim.ink_peaks.is_empty() and sim._p2_pending.is_empty() and sim._e1_reform_pending.is_empty(),"actual victory retires complete R2/P2/E1 scope")
 if enter(room,2,"r02a"):
  check(sim.clock.domain.snapshot().scope.room_id == sim.room_id and sim.clock.domain.snapshot().active_real_time == 0.0,"same facade binds new actual room")
  finish_fixture_combat(room)
  sim.hero.hp = 123.0; sim.observe_pending_health(); sim.hero.cooldowns.r = 9.0
  var flasks: int = model.state.shop_visit.flask_charges; var gold: int = model.state.gold; var points: int = model.state.points
  if enter(room,3,"r03a"):
   check(sim.hero.hp == sim.hero.stats.max_hp and sim.hero.cooldowns.r == 0.0 and session.rest_service.snapshot().size() == 1,"real rest restores original HP and cooldown")
   check(model.state.shop_visit.flask_charges == flasks and model.state.gold == gold and model.state.points == points,"rest grants no bottle/gold/SP")
   check(session.ledger.get_instance_id() == owner and sim.clock.get_instance_id() == facade and sim.enemy_director.get_instance_id() == director and session._owner_intact(),"route and rest retain one Session/facade/director")
   check(sim.clock.domain.snapshot().presentations.is_empty() and sim.ink_peaks.is_empty(),"rest keeps R2 token/domain retired")
 observations.ordinary = {"R2_rank":sim.hero.ranks.r,"explicit_fixture_level":6,"explicit_fixture_SP":9,"owner":owner,"facade":facade,"director":director,"natural_clear":false}
 close_room(room); done_group(REQUIRED_GROUPS[3])

func run() -> void:
 token_and_world()
 p2_e1_clock()
 p1_immunity_and_retirement()
 await ordinary_route()
 active_group = "integrity"
 for group: String in REQUIRED_GROUPS: check(groups.count(group) == 1,"required group reached once: "+group)
 var report: Dictionary = {"schema":"ink-r2-ordinary-finite-1","passed":failures.is_empty() and groups == REQUIRED_GROUPS,"checks":checks,"failures":failures,"completed":groups,"group_checks":group_checks,"event_errors":event_errors,"observations":observations,"source_binding_sha256":FileAccess.get_sha256(Binding.BINDING_PATH),"native_input":false,"natural_progression":false,"full_floor":false,"old_full_matrices_rerun":false,"new_hex_admission":false,"final_presentation_animation":false,"real_multiplayer":false,"explicit_level6_fixture":true}
 if not output_path.is_empty():
  var file := FileAccess.open(output_path,FileAccess.WRITE)
  if file == null: push_error("R2 ordinary report write failed"); quit(2); return
  file.store_string(JSON.stringify(report," ")+"\n")
 print("INK_R2_ORDINARY_REPORT ",JSON.stringify(report))
 quit(0 if report.passed else 1)
