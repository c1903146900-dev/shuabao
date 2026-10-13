extends SceneTree
## Main-owned narrow combination gate. No native input, art or full-floor claim.
const Sim = preload("res://tests/ink_e1_ordinary_20261005/candidate01/sim.gd")
const OldE1 = preload("res://tests/ink_e1_rain_foundation_20261005/fix01/ink_e1_sim.gd")
const OldQ2 = preload("res://tests/ink_q2_foundation_20261005/fix01/ink_q2_sim.gd")
const Session = preload("res://tests/ink_e1_ordinary_20261005/candidate01/floor_session.gd")
const Binding = preload("res://tests/ink_e1_ordinary_20261005/candidate01/live_binding.gd")
const Router = preload("res://tests/ink_e1_ordinary_20261005/candidate01/input_adapter.gd")
const Growth = preload("res://tests/ink_e1_ordinary_20261005/candidate01/growth_hud.gd")
const Controller = preload("res://tests/ink_q3_input_growth_20261004/controller.gd")
const Bottom = preload("res://tests/ink_style_specimen_20261004/revision10_hud/hud.gd")
const QHud = preload("res://tests/ink_e1_ordinary_20261005/candidate01/hud_projection.gd")
const EHud = preload("res://tests/ink_e1_ordinary_20261005/candidate01/e1_hud.gd")
const RiverView = preload("res://tests/ink_q2_ordinary_20261005/candidate01/river_view.gd")
const Nav = preload("res://tests/ink_e1_ordinary_20261005/candidate01/navigation_install.gd")
const Frontdoor = preload("res://scripts/integration/hero_entry.gd")
const RoomAdapter = preload("res://scripts/integration/yanguizhou_first_floor.gd")
const REWARD_ROOT := "res://tests/ink_first_floor_user_route_20261005/runtime01/"
var checks := 0
var failures: Array[String] = []
var groups: Array[String] = []
var observations: Dictionary = {}
var serial := 0
var output_path := "user://e1_ordinary_finite.json"

func _initialize() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--e1-result="): output_path = arg.trim_prefix("--e1-result=")
 run.call_deferred()
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok: failures.append(label); push_error(label)
func near(a: float, b: float, label: String, tolerance: float = .00001) -> void:
 check(is_finite(a) and absf(a-b) <= tolerance,label)
func key(code: int, down: bool = true, echo: bool = false) -> InputEventKey:
 var out := InputEventKey.new(); out.physical_keycode = code; out.pressed = down; out.echo = echo; return out
func events(sim, kind: String) -> Array:
 return sim.event_log.filter(func(event): return event.kind == kind)

func ordinary(candidate: String = "E1") -> Dictionary:
 serial += 1
 var sim = Sim.new(); root.add_child(sim); sim.ai_enabled = false
 var session = Session.new()
 var configured: Dictionary = session.configure_reward_table(REWARD_ROOT+"reward_table.json",REWARD_ROOT+"rewards.csv",REWARD_ROOT+"validation_result.json",true)
 var loaded: Dictionary = Session.MixedSchema.load_definition(Session.DEFAULT_DEFINITION,true)
 check(configured.accepted and loaded.accepted,"unchanged route/reward sources")
 var initialized: Dictionary = session.initialize_floor(sim,loaded.definition,"e1-ordinary-%d"%serial,true)
 check(initialized.accepted,"exact composed single Session initializes: "+str(initialized.reason))
 if not initialized.accepted: sim.free(); return {}
 var router = Router.new(); router.bind(sim); session.bind_input_suspender(router.suspend_input)
 var growth = Growth.new(); root.add_child(growth)
 var controller = Controller.new(); controller.bind_session(session,growth)
 controller.gameplay_block_changed.connect(session.set_modal_blocked)
 sim.combat_event.connect(func(event: Dictionary): session.observe_event(sim,event))
 sim.encounter_finished.connect(func(value: Dictionary): session.queue_terminal(sim,value))
 var state: Dictionary = session.ledger.model.snapshot()
 check(state.level == 1 and state.points == 1 and state.gold == 0 and state.xp == 0 and state.selected_hex.is_empty(),"ordinary original 1SP and zero gold/XP")
 growth.e1_choice.pressed.emit()
 check(not controller.last_result.accepted and controller.last_result.reason == "mandatory_hex_pending","E1 button cannot skip mandatory initial Hex")
 controller.ensure_auto_hex(); growth.adapter.request("hex_select",{"milestone":1,"slot":3})
 check(controller.last_result.accepted,"real original mandatory Hex selection")
 if candidate == "E1": growth.e1_choice.pressed.emit()
 else: growth.q_choices[candidate].upgrade.pressed.emit()
 check(controller.last_result.accepted and session.ledger.model.state.points == 0,"real Button->Controller->Model spends original SP for "+candidate)
 return {"sim":sim,"s":session,"router":router,"growth":growth,"c":controller}
func close_ordinary(f: Dictionary) -> void:
 if f.is_empty(): return
 f.s.close_run(); f.growth.free(); f.sim.free()
func combat(f: Dictionary) -> bool:
 var selected: Dictionary = f.s.select_node(1,"r01a")
 var entered: Dictionary = f.s.enter_selected_node()
 check(selected.accepted and entered.accepted and f.sim.phase == "combat","real connected ordinary first-room entry")
 return entered.accepted

func fixture(rank: int = 1, ids: Array = [], baseline: bool = false):
 # Explicit isolated mechanics fixture, never used by ordinary startup.
 var sim = OldE1.new() if baseline else Sim.new()
 root.add_child(sim); sim.auto_finish = false; sim.ai_enabled = false; sim.arena_half_extent = 100.0
 sim.hero.position = Vector3.ZERO; sim.hero.loadout.e = "e1"; sim.hero.ranks.e = rank
 sim.hero.loadout.q = "q1"; sim.hero.ranks.q = 1
 sim.hero.stats.ap = 100.0; sim.hero.stats.crit_chance = 0.0; sim.hero.stats.regen = 0.0; sim.hero.stats.defence = 0.0
 sim.begin_encounter("e1-combination-mechanics-fixture",[]); sim.set_hexes(ids)
 return sim
func target(sim, at: Vector3, kind: String = "minion", hp: float = 100000.0) -> Dictionary:
 var enemy: Dictionary = sim.spawn_enemy(kind,at,hp)
 enemy.state = "chase"; enemy.defence = 0.0; enemy.radius = .25; return enemy
func enter(sim) -> Dictionary:
 var out: Dictionary = sim.request_action("e")
 check(out.accepted,"E1 source entry accepted"); return out
func river(sim, x: float = 6.0) -> void:
 sim.hero.loadout.q = "q2"
 check(sim.request_q2("first",Vector3(x,0,-3)).accepted and sim.request_q2("second",Vector3(x,0,3)).accepted,"explicit fixture real Q2 two-stage river")

func run() -> void:
 admission_learning(); releases_and_frontdoor(); damage_cleanup(); q_coexistence_and_projection(); clocks_and_pending_hits(); h02_legs()
 var report: Dictionary = {"suite":"ink_e1_q2_ordinary_finite","passed":failures.is_empty(),"checks":checks,"failures":failures,"groups":groups,"observations":observations,"binding_sha256":FileAccess.get_sha256(Binding.BINDING_PATH),"gate_sha256":FileAccess.get_sha256(get_script().resource_path),"scope":"ordinary zero-resource Session/Button learning plus separately labeled mechanics fixtures and real entry-fence method routing","native_device_input":false,"full_floor":false,"ordinary_only_phasing":false,"H07_H08_offered":false,"art_audio_accepted":false}
 var file := FileAccess.open(output_path,FileAccess.WRITE)
 if file != null: file.store_string(JSON.stringify(report,"  ")); file.close()
 print("INK_E1_ORDINARY_REPORT ",JSON.stringify(report)); quit(0 if failures.is_empty() else 1)

func admission_learning() -> void:
 var old = OldQ2.new(); root.add_child(old)
 check(not Binding.read_capabilities(old,true).accepted,"new binding rejects exact old Q2 instead of impersonating it"); old.free()
 var f: Dictionary = ordinary()
 if f.is_empty(): return
 check(f.sim.hero.loadout.e == "e1" and f.sim.hero.ranks.e == 1 and f.sim.hero.ranks.q == 0,"ordinary E1 uses its own E slot and original SP")
 var e1_text: String = str(EHud.model_from(f.sim).tooltip)
 check("规则已确认；该技能尚未实现。" not in e1_text and "基础E1机制已接入候选，形态美术/音频未完成" in e1_text,"E1 tooltip replaces only the obsolete unimplemented notice")
 var caps: Dictionary = Binding.read_capabilities(f.sim,true)
 check(caps.accepted and caps.capabilities.runtime_candidates == ["Q1","Q2","Q3","E1"],"only base E1 added")
 var supported := 0
 for id: String in f.s.ledger.definitions.hexes:
  if f.s.ledger.model.support(f.s.ledger.definitions.hexes[id]).supported: supported += 1
 check(supported == 10,"original ten hook ceiling")
 for id: String in ["yanguizhou_h03","yanguizhou_h04","yanguizhou_h07","yanguizhou_h08"]:
  check(not f.s.ledger.model.support(f.s.ledger.definitions.hexes[id]).supported,"unwired Hex is unavailable: "+id)
 check(f.s._owner_intact() and is_same(f.sim.progression,f.s.ledger),"single HP/economy/reward owner")
 var before: PackedByteArray = var_to_bytes(f.s.ledger.model.snapshot())
 for candidate: String in ["E2","E3","P1","R1"]:
  f.growth.adapter.request("learn",{"slot_id":candidate.left(1),"candidate_id":candidate,"expected_rank":0})
  check(not f.c.last_result.accepted and before == var_to_bytes(f.s.ledger.model.snapshot()),"unwired skill atomically rejected: "+candidate)
 f.growth.undo_button.pressed.emit()
 check(f.c.last_result.accepted and f.sim.hero.ranks.e == 0 and f.s.ledger.model.state.points == 1,"safe E1 undo returns only original SP")
 f.growth.e1_choice.pressed.emit()
 if combat(f):
  check(f.router.handle_event(key(KEY_E)).accepted,"ordinary learned E1 reaches real input adapter")
  check(f.router.handle_event(key(KEY_E,false)).accepted,"ordinary E1 real event pair reforms")
 close_ordinary(f)
 var nav_sim = Sim.new(); root.add_child(nav_sim)
 check(Nav.apply_to_fresh_ink_sim(nav_sim).accepted,"new exact source gets same director algorithm")
 var director_id: int = nav_sim.enemy_director.get_instance_id()
 check(not Nav.apply_to_fresh_ink_sim(nav_sim).accepted and nav_sim.enemy_director.get_instance_id() == director_id,"navigation installs once")
 nav_sim.free(); groups.append("ordinary_learning_caps_single_owner")

func releases_and_frontdoor() -> void:
 var sim = fixture(); var router = Router.new(); router.bind(sim)
 check(router.handle_event(key(KEY_E)).accepted,"held E begins one form")
 var root_cast: int = sim.ink_rain.cast_id; var at: float = sim.hero_time
 var deadline: float = sim.ink_rain.expires_at; var cd: float = sim.hero.cooldowns.e
 router.suspend_input("focus_lost")
 check(not sim.ink_rain.release_pending and sim.ink_rain.expires_at == deadline,"focus does not synthesize E-up or change deadline")
 sim.paused = true
 check(router.route_event(key(KEY_E,false),Callable(),Vector3.INF,true).accepted and sim.ink_rain.release_pending,"true GUI-blocked late E-up queues while paused")
 sim.step(1.0); near(sim.hero_time,at,"paused real release does not advance source"); near(sim.hero.cooldowns.e,cd,"paused CD frozen")
 sim.paused = false; sim.step(.02)
 check(sim.ink_rain.is_empty() and sim.ink_e1_finished.size() == 1 and sim.ink_e1_finished[0].cast_id == root_cast,"resume consumes exact queued cast once")
 sim.free()
 sim = fixture(); router = Router.new(); router.bind(sim); router.handle_event(key(KEY_E))
 var room = RoomAdapter.new(); room.sim = sim; room.input_router = router; room._mainprep_required = false
 var entry = Frontdoor.new(); root.add_child(entry)
 entry.active_room = room; entry.active_hero = "yanguizhou"; entry.screen = Frontdoor.Screen.TRANSITION
 room.frontdoor_clear_input(); room.frontdoor_clear_input()
 check(router._owned_e_current(),"repeated chooser input clear retains exact live E1 ownership")
 entry._blocked_keys[KEY_E] = true
 at = sim.hero_time; cd = sim.hero.cooldowns.e; root_cast = sim.cast_serial
 entry.filter_session_input(key(KEY_E,false,true))
 check(not sim.ink_rain.release_pending,"frontdoor ignores echo up")
 entry.filter_session_input(key(KEY_E,false))
 check(sim.ink_rain.release_pending and not entry._blocked_keys.has(KEY_E),"disabled/transition room receives owned real E-up while fence drains")
 check(sim.cast_serial == root_cast and sim.ink_e1_finished.is_empty(),"frontdoor forwarding does not create cast or reform immediately")
 near(sim.hero_time,at,"frontdoor does not step source"); near(sim.hero.cooldowns.e,cd,"frontdoor does not spend/reset CD")
 room.frontdoor_clear_input(); room.frontdoor_clear_input()
 check(sim.ink_rain.release_pending and not router._owned_e_current(),"post-release clear preserves pending source intent without reusable input ownership")
 check(not router.handle_event(key(KEY_E,false)).accepted,"entry-consumed release cannot repeat through ordinary leaf router")
 sim.paused = true; sim.step(.5); check(sim.ink_e1_finished.is_empty(),"chooser remains frozen")
 entry.screen = Frontdoor.Screen.RUN; entry._blocked_keys[KEY_E] = true; entry.filter_session_input(key(KEY_E,false))
 check(not entry._blocked_keys.has(KEY_E),"return fence still drains repeated blocked E-up")
 sim.paused = false; sim.step(.02)
 check(sim.ink_e1_finished.size() == 1,"chooser queued release settles exactly once")
 entry.active_room = null; entry.free(); room.free(); sim.free()
 sim = fixture(); router = Router.new(); router.bind(sim); router.handle_event(key(KEY_E)); router.focus_lost()
 sim.step(18.0)
 check(sim.ink_rain.is_empty() and sim.ink_e1_finished.size() == 1,"lost platform key-up naturally expires without automatic recast")
 check(router.handle_event(key(KEY_E)).accepted,"fresh down recovers after lost-up expiry/CD")
 sim.end_encounter("old-room"); sim.begin_encounter("replacement-room",[])
 sim.hero.cooldowns.e = 0.0 # Explicit replacement-root fixture only.
 enter(sim)
 var replacement: int = sim.ink_rain.cast_id
 check(not router.queue_owned_boundary_e_up(key(KEY_E,false)).accepted and not sim.ink_rain.release_pending and sim.ink_rain.cast_id == replacement,"old physical ownership cannot release replacement room form")
 sim.free(); groups.append("real_release_modal_frontdoor_focus_scope")

func damage_cleanup() -> void:
 var sim = fixture(); var marked: Dictionary = target(sim,Vector3(1,0,0)); var plain: Dictionary = target(sim,Vector3(1.5,0,1.5)); var distant: Dictionary = target(sim,Vector3(5,0,0))
 enter(sim); var state: Dictionary = sim.ink_rain
 sim.move_during_hitstop(.2,Vector3.RIGHT)
 check(state.marks.has(marked.actor_id) and not state.marks.has(plain.actor_id),"actual contact marks without radius-only marking")
 near(marked.hp,100000,"rain mark itself has no damage")
 var cd: float = sim.hero.cooldowns.e
 sim.request_action("e_release")
 near(100000-marked.hp,145,"marked in-radius gets distinct base and bonus")
 near(100000-plain.hp,95,"unmarked in-radius gets base only"); near(distant.hp,100000,"outside radius remains unharmed")
 check(state.marks.is_empty() and sim.ink_e1_finished.size() == 1,"every mark cleared after complete two-channel reform")
 near(sim.hero.cooldowns.e,cd,"release does not restart entry cooldown"); sim.free()
 sim = fixture(); var far: Dictionary = target(sim,Vector3(3,0,0)); enter(sim)
 sim.move_during_hitstop(.8,Vector3.RIGHT); state = sim.ink_rain
 check(state.marks.has(far.actor_id),"sweep marks crossed enemy")
 sim.request_action("e_release"); near(far.hp,100000,"marked outside final radius receives no remote damage")
 check(state.marks.is_empty(),"outside mark is cleared too"); sim.free()
 sim = fixture(); sim.hero.stun_left = .4
 check(sim.request_action("e").reason == "controlled","base E1 has no H07 controlled-entry permission")
 sim.hero.stun_left = 0; enter(sim); var hp: float = sim.hero.hp
 sim.damage_hero(100,Vector3.ZERO,.5,true)
 near(hp-sim.hero.hp,30,"base E1 reduces damage but has no H08 immunity")
 check(sim.hero.stun_left > 0,"E1 still receives legal control")
 sim.damage_hero(10000,Vector3.ZERO,0,true,true)
 check(sim.hero.dead and sim.ink_rain.is_empty() and sim.ink_rain_guard.is_empty(),"true death clears form and guard")
 var count: int = sim.ink_e1_finished.size(); sim.step(1)
 check(sim.ink_e1_finished.size() == count,"dead source produces no late reform"); sim.free()
 groups.append("rain_damage_control_cleanup")

func q_coexistence_and_projection() -> void:
 var sim = fixture(); sim.hero.loadout.q = "q2"
 check(sim.request_q2("first",Vector3(2,0,-3)).accepted,"Q2 marker placed before E1")
 var marker: PackedByteArray = var_to_bytes(sim.ink_q2_pending); enter(sim)
 check(sim._q2_input_reason() == "rain_form_forbids_action" and not sim.request_q2("second",Vector3(2,0,3)).accepted,"new Q2 second stage blocked in form")
 check(marker == var_to_bytes(sim.ink_q2_pending) and sim.hero.cooldowns.q == 0,"E1 never removes or restarts existing marker")
 sim.step(2.5); check(sim.ink_rain.is_empty() and not sim.ink_q2_pending.is_empty(),"E1 deadline does not stop Q2 marker lifetime")
 check(sim.request_q2("second",Vector3(2,0,3)).accepted,"original marker can complete after reform")
 var view = RiverView.new(); root.add_child(view)
 var snapshot: Dictionary = sim.ink_presenter_snapshot(); var bytes: PackedByteArray = var_to_bytes([sim.snapshot(),snapshot])
 view.present_source(snapshot,{})
 check(view.river_sample.active.size() == 1 and view.river_sample.active[0].path == sim.ink_rivers[0].path,"Q2 river reads original scope/path from composite")
 check(bytes == var_to_bytes([sim.snapshot(),snapshot]),"river display read-only")
 view.free(); sim.free()
 for candidate: String in ["Q1","Q2","Q3"]:
  var f: Dictionary = ordinary(candidate)
  if f.is_empty() or not combat(f): close_ordinary(f); continue
  if candidate == "Q3": check(f.sim.request_action("q",Vector3(2,0,0)).accepted,"source Q3 mountain raised")
  var hud = Bottom.new(); root.add_child(hud); hud.present(f.sim.snapshot(),f.sim.ink_presenter_snapshot(),{})
  bytes = var_to_bytes([f.sim.snapshot(),f.s.ledger.model.snapshot()])
  var shown: Dictionary = QHud.apply_to(hud,f.sim)
  check(shown.candidate == candidate.to_lower() and shown.rank == 1,"correct selected Q context: "+candidate)
  near(float(shown.cooldown),float(f.sim.hero.cooldowns.q),"selected Q actual cooldown: "+candidate)
  if candidate == "Q3": check(shown.q3_live and shown.recast_ready,"Q3 live mountain/recast survives exact new HUD context")
  var e: Dictionary = EHud.apply_to(hud,f.sim)
  check(not e.learned and bytes == var_to_bytes([f.sim.snapshot(),f.s.ledger.model.snapshot()]),"Q/E card projections cannot grant E1 or mutate source")
  hud.free(); close_ordinary(f)
 sim = fixture(); sim.hero.loadout.q = "q3"
 check(sim.request_action("q",Vector3(2,0,0)).accepted,"fixture Q3 establishes existing mountain")
 var hud = Bottom.new(); root.add_child(hud); enter(sim)
 var shown: Dictionary = QHud.apply_to(hud,sim)
 check(shown.q3_live and not shown.recast_ready and shown.reason == "rain_form_forbids_action","rain blocks Q3 input while retaining verified live mountain card")
 sim.request_action("e_release"); shown = QHud.apply_to(hud,sim)
 check(shown.q3_live and shown.recast_ready,"Q3 recast readiness returns after E1 without rewriting mountain/CD")
 hud.free(); sim.free()
 sim = fixture(); check(draw(sim,Vector3.ZERO,Vector3(4,0,0)).accepted,"retained Q1 committed wave")
 enter(sim)
 for action: String in ["attack","q","r"]: check(sim.request_action(action,Vector3(6,0,0)).reason == "rain_form_forbids_action","rain blocks new "+action)
 var e_root: int = sim.ink_rain.cast_id
 check(sim.request_action("shift",Vector3(6,0,0)).accepted,"Shift remains independently admitted during E1")
 check(sim.ink_rain.cast_id == e_root and sim.cast_serial != e_root,"Shift does not reuse the E1 root")
 sim.step(.02)
 check(sim.ink_waves.size() == 1 and float(sim.ink_waves[0].front_distance) > 0,"existing Q1 wave still advances in E1")
 sim.free()
 groups.append("Q2_coexistence_and_full_Q_projection")

func clocks_and_pending_hits() -> void:
 var paired: Array = []
 for baseline: bool in [true,false]:
  var sim = fixture(2,[],baseline)
  if not baseline: river(sim,6.0)
  enter(sim); sim.hero.move_intent = Vector3.RIGHT
  sim.step(2.52); var active_hp: float = sim.hero.hp
  sim.damage_hero(10,Vector3.ZERO,0,true)
  var active_loss: float = active_hp-sim.hero.hp
  sim.step(.02); var after_hp: float = sim.hero.hp
  sim.damage_hero(10,Vector3.ZERO,0,true)
  paired.append({"time":sim.hero_time,"steps":sim.ink_core_steps,"position":sim.hero.position,"active_loss":active_loss,"after_loss":after_hp-sim.hero.hp,"e_cd":sim.hero.cooldowns.e,"reforms":sim.ink_e1_finished.size(),"finished_at":sim.ink_e1_finished[0].finished_at})
  sim.free()
 check(paired[0] == paired[1],"E1 baseline and Q2 combination preserve same deadline/movement/CD/core-step semantics")
 observations.deadline_pair = paired
 var sim = fixture(); river(sim,6.0); enter(sim)
 var attacker: Dictionary = target(sim,Vector3(12,0,0))
 var before_hp: float = sim.hero.hp
 # Explicit local queue fixture uses the real Q2 scheduler and damage pipeline.
 sim._q2_enemy_hits.append({"kind":"enemy_hit","enemy":attacker,"time":sim.hero_time,"amount":10.0,"direction":Vector3.ZERO,"control":.5,"is_true":true,"mandatory":false,"metadata":{},"generation":sim.encounter_generation,"room_id":sim.room_id,"impacts":[]})
 var stopped := [false]
 sim.combat_event.connect(func(event: Dictionary):
  if event.kind == "damage" and event.get("target","") == "yanguizhou" and not stopped[0]: stopped[0] = true; sim.paused = true)
 var steps: int = sim.ink_core_steps
 sim._settle_motion_interval(sim._enemy_motion_snapshot(),sim.hero_time,sim.hero_time)
 near(before_hp-sim.hero.hp,3,"Q2 queued incoming hit consumes active E1 reduction once")
 check(sim.hero.stun_left > 0 and sim.paused and not sim._q2_motion_resume.is_empty(),"queued hit preserves control and paused scheduler remainder")
 check(sim.ink_core_steps == steps,"local contact settlement does not create world tick")
 sim.paused = false; sim.step(.02)
 near(before_hp-sim.hero.hp,3,"resumed Q2 queue does not repeat committed damage")
 check(sim.ink_core_steps == steps+1 and sim._q2_motion_resume.is_empty(),"resume drains remainder then exactly one requested core tick")
 sim.free()
 # One actual source tick pauses during its first local Q2 hit; a genuine
 # delivered E-up then waits while the previous tick's contact remainder exists.
 sim = fixture(); river(sim,6.0)
 var router = Router.new(); router.bind(sim); check(router.handle_event(key(KEY_E)).accepted,"combined pending fixture has genuine E-down ownership")
 attacker = target(sim,Vector3(12,0,0)); before_hp = sim.hero.hp
 var trace: Array = []; var pause_once := [false]
 sim.combat_event.connect(func(event: Dictionary):
  if event.kind in ["damage","ink_e1_reform_started","ink_e1_finished"]:
   trace.append({"kind":event.kind,"sequence":event.sequence,"source_time":sim.hero_time,"finished_at":event.get("finished_at",-1.0),"amount":event.get("amount",0.0)})
  if event.kind == "damage" and event.get("target","") == "yanguizhou" and not pause_once[0]: pause_once[0] = true; sim.paused = true)
 for hit_at: float in [.005,.015]:
  sim._q2_enemy_hits.append({"kind":"enemy_hit","enemy":attacker,"time":hit_at,"amount":10.0,"direction":Vector3.ZERO,"control":0.0,"is_true":true,"mandatory":false,"metadata":{},"generation":sim.encounter_generation,"room_id":sim.room_id,"impacts":[]})
 sim.step(.02)
 check(sim.paused and not sim._q2_motion_resume.is_empty() and sim._q2_enemy_hits.size() == 1,"first real tick pauses with one exact Q2 hit remainder")
 check(router.handle_event(key(KEY_E,false)).accepted and sim.ink_rain.release_pending,"actual paused E-up queues beside prior Q2 remainder")
 var paused_at: float = sim.hero_time; steps = sim.ink_core_steps
 sim.step(.5); near(sim.hero_time,paused_at,"both pending channels freeze while paused")
 sim.paused = false; sim.step(.02)
 near(sim.hero_time,paused_at+.02,"combined resume advances one requested source tick")
 check(sim.ink_core_steps == steps+1,"combined pending release/resume never double-steps core")
 near(before_hp-sim.hero.hp,6,"each of two admitted prior-tick enemy hits settles once under still-active form")
 check(sim.ink_rain.is_empty() and sim.ink_e1_finished.size() == 1 and sim._q2_motion_resume.is_empty() and sim._q2_enemy_hits.is_empty(),"queued reform and both admitted hits retire exactly once")
 var kinds: Array = trace.map(func(row): return row.kind)
 check(kinds == ["damage","damage","ink_e1_reform_started","ink_e1_finished"],"existing order: old Q2 remainder first, then new core pre-step queued reform")
 near(float(sim.ink_e1_finished[0].finished_at),paused_at,"pending reform source receipt keeps resumed tick-start time")
 observations.combined_release_resume_trace = trace.duplicate(true)
 sim.free()
 # Q2 hit.time orders local contacts. It does not rewind E1's already-completed
 # hero locomotion/deadline phase when an admitted delayed hit commits later.
 sim = fixture(2); river(sim,6.0); enter(sim); attacker = target(sim,Vector3(12,0,0))
 sim.step(2.54); check(sim.ink_rain.is_empty() and sim.ink_e1_finished.size() == 1,"E1 deadline already settled in original hero phase")
 before_hp = sim.hero.hp; steps = sim.ink_core_steps
 sim._q2_enemy_hits.append({"kind":"enemy_hit","enemy":attacker,"time":2.53,"amount":10.0,"direction":Vector3.ZERO,"control":.25,"is_true":true,"mandatory":false,"metadata":{},"generation":sim.encounter_generation,"room_id":sim.room_id,"impacts":[]})
 sim._settle_motion_interval(sim._enemy_motion_snapshot(),2.52,2.54)
 near(before_hp-sim.hero.hp,10,"earlier hit.time does not restore expired E1 damage reduction at later commit")
 check(sim.hero.stun_left > 0 and sim.ink_core_steps == steps,"late commit still preserves control without world rollback/step")
 observations.delayed_hit_after_deadline = {"hit_time":2.53,"commit_source_time":sim.hero_time,"reform_finished_at":sim.ink_e1_finished[0].finished_at,"hp_loss":before_hp-sim.hero.hp,"semantics":"existing hero-phase retirement then local Q2 commit; no global source-clock rewind"}
 sim.free(); groups.append("E1_deadline_Q2_hit_pause_resume")

func h02_legs() -> void:
 test_h02_remainder(); test_h02_split_pull()
 groups.append("committed_H02_newborn_and_bent_legs")

func test_h02_remainder() -> void:
 var sim=fixture(1,["yanguizhou_h02"])
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
 sim.free()


func test_h02_split_pull() -> void:
 var sim=fixture(1,["yanguizhou_h02"])
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
 sim.free()


func draw(sim, start:Vector3, end:Vector3)->Dictionary:
 check(sim.request_ink_input("q_down").accepted,"Q1 armed")
 check(sim.request_ink_input("left_down",start).accepted,"Q1 drawing")
 sim.request_ink_input("motion",end)
 return sim.request_ink_input("left_up",end)
