extends SceneTree
## Main-owned source-event/Control gate, NOT RUN by this author.
## Normal input cases spend the original 1SP. Isolated rank/selector fixtures
## below explicitly seed only fresh test authorities; runtime has no such path.
const Sim = preload("res://tests/ink_q3_foundation_20261004/fix02/ink_q3_sim.gd")
const Session = preload("res://tests/ink_q3_input_growth_20261004/floor_session.gd")
const Binding = preload("res://tests/ink_q3_input_growth_20261004/live_binding.gd")
const Controller = preload("res://tests/ink_q3_input_growth_20261004/controller.gd")
const HUD = preload("res://tests/ink_q3_input_growth_20261004/growth_hud.gd")
const Router = preload("res://tests/ink_q3_input_growth_20261004/input_adapter.gd")
const Schema = preload("res://tests/ink_first_floor_candidate_20261004/route_schema.gd")
const Catalog = preload("res://tests/ink_q3_input_growth_20261004/catalog.gd")
const Model = preload("res://tests/ink_intermediate_stats_20261004/ink_intermediate_model.gd")
var checks: int = 0
var failures: Array = []
var completed: Array = []
var serial: int = 0
var observations: Dictionary = {}
const REQUIRED = ["admission_and_normal_learning", "Q1_inherited", "Q3_event_commit", "Q3_expiry_identity", "Q3_cancel_boundaries", "training_switch", "fixture_personal_dependency", "fixture_ranks_caps", "fixture_all_prior_choices"]
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok: failures.append(label); push_error(label)
func command(model, action: String, args: Dictionary = {}) -> Dictionary:
 serial += 1
 return model.command("q3-input-growth-gate:%d" % serial, action, args)
func key(code: int, down: bool = true, echo: bool = false) -> InputEventKey:
 var event := InputEventKey.new(); event.physical_keycode = code; event.pressed = down; event.echo = echo; return event
func mouse(down: bool, at: Vector2 = Vector2(4, 0), button: int = MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
 var event := InputEventMouseButton.new(); event.button_index = button; event.pressed = down; event.position = at; return event
func project(point: Vector2) -> Vector3: return Vector3(point.x, 0, point.y)
func route(f: Dictionary, event: InputEvent, keyboard_ground: Vector3 = Vector3(4, 0, 0), blocked: bool = false) -> Dictionary:
 return f.router.route_event(event, project, keyboard_ground, blocked)
func fresh(candidate: String = "Q3", training: bool = false) -> Dictionary:
 serial += 1
 var loaded: Dictionary = Schema.load_definition(Session.DEFAULT_DEFINITION, true)
 if not loaded.accepted: check(false, "route source loads"); return {}
 var definition: Dictionary = loaded.definition
 if training:
  definition = definition.duplicate(true)
  definition.version = "TRAINING_INPUT_DIAGNOSTIC_NOT_NORMAL_FLOOR"
  definition.payloads.r01 = {"node_type":"service", "kind":"training", "service":{"type":"training", "area_id":"diagnostic-training", "completion_rule":"explicit_owner_exit", "optional_actions":true}}
 var sim = Sim.new(); root.add_child(sim)
 sim.ai_enabled = false # Explicit source-input contract fixture, not natural play.
 var session = Session.new()
 var admitted: Dictionary = session.initialize_floor(sim, definition, "q3-input-growth:%d" % serial, true)
 check(admitted.accepted, "fresh exact Q3 Sim and single floor authority admitted: " + str(admitted.reason))
 if not admitted.accepted: sim.free(); return {}
 var router = Router.new(); router.bind(sim)
 check(session.bind_input_suspender(router.suspend_input).accepted, "input suspender binds to same Session")
 var hud = HUD.new(); root.add_child(hud)
 var controller = Controller.new(); controller.bind_session(session, hud)
 controller.gameplay_block_changed.connect(session.set_modal_blocked)
 var f: Dictionary = {"sim":sim, "s":session, "router":router, "hud":hud, "c":controller, "events":[]}
 sim.combat_event.connect(func(event: Dictionary):
  f.events.append(event.duplicate(true))
  session.observe_event(sim, event))
 sim.encounter_finished.connect(func(event: Dictionary): session.queue_terminal(sim, event))
 check(is_same(sim.progression, session.ledger) and session._owner_intact(), "one ledger, exact commerce/floor owner and Sim")
 var state: Dictionary = session.ledger.model.snapshot()
 check(state.level == 1 and state.points == 1 and state.gold == 0 and state.xp == 0, "normal startup original Lv1/1SP/0gold/0XP")
 hud.adapter.request("learn", {"slot_id":"Q", "candidate_id":candidate, "expected_rank":0})
 check(not controller.last_result.accepted and controller.last_result.reason == "mandatory_hex_pending", "Controller cannot skip mandatory original choice")
 controller.ensure_auto_hex()
 check(hud.hex_required and hud.projection.choices.size() == 4 and sim.paused, "same real mandatory four-choice Control/Controller")
 hud.adapter.request("hex_select", {"milestone":1, "slot":3})
 check(controller.last_result.accepted and session.ledger.model.snapshot().pending_milestones.is_empty(), "real Model selection clears Lv1 only")
 check(not sim.paused, "modal closes with original pause policy")
 hud.q_choices[candidate].upgrade.pressed.emit()
 check(controller.last_result.accepted and sim.hero.loadout.q == candidate.to_lower() and sim.hero.ranks.q == 1, "actual candidate Button -> Adapter -> Controller -> Model -> Bridge -> Sim")
 check(session.ledger.model.state.points == 0 and session.ledger.model.state.gold == 0 and session.ledger.model.state.xp == 0, "learning spends exactly original1SP, no gold or XP grants")
 return f
func close(f: Dictionary) -> void:
 if f.is_empty(): return
 f.s.close_run(); f.hud.free(); f.sim.free()
func combat(f: Dictionary) -> bool:
 var selected: Dictionary = f.s.select_node(1, "r01")
 check(selected.accepted, "real first row explicitly selected")
 var entered: Dictionary = f.s.enter_selected_node()
 check(entered.accepted and f.sim.phase == "combat", "single-owner real source encounter started")
 return entered.accepted
func run() -> void:
 admission_and_learning()
 q1_inherited()
 q3_event_commit()
 q3_expiry_identity()
 q3_cancel_boundaries()
 training_switch()
 fixture_personal_dependency()
 fixture_ranks_caps()
 fixture_all_prior_choices()
 for name in REQUIRED: check(name in completed, "case completed: " + name)
 var report: Dictionary = {"suite":"ink_q3_input_growth_finite", "passed":failures.is_empty(), "checks":checks, "failures":failures, "completed":completed, "observations":observations, "binding":FileAccess.get_sha256(Binding.BINDING_PATH), "scope":"actual source InputEvents/Control/Controller/Model/Bridge only; explicit rank/pool fixtures separate", "native_input_pixels_audio":"NOT_RUN", "normal_first_floor":"NOT_RUN", "source_caps_unchanged":true, "runtime_free_SP_learning_funding":false, "promotion":false}
 var file := FileAccess.open("res://tests/ink_q3_input_growth_20261004/finite_result.json", FileAccess.WRITE)
 file.store_string(JSON.stringify(report, "  ")); file.close()
 print("INK_Q3_INPUT_GROWTH_REPORT ", JSON.stringify(report))
 quit(0 if failures.is_empty() else 1)
func admission_and_learning() -> void:
 var f: Dictionary = fresh()
 if f.is_empty(): return
 var caps: Dictionary = Binding.read_capabilities(f.sim, true)
 check(caps.accepted and caps.capabilities.runtime_candidates == ["Q1", "Q3"], "exact candidate ceiling only Q1/Q3")
 var count := 0
 for id in f.s.ledger.definitions.hexes:
  if f.s.ledger.model.support(f.s.ledger.definitions.hexes[id]).supported: count += 1
 check(count == 10 and f.s.ledger.model.initial_pool_readiness().accepted, "ten real hooks and existing eight/two readiness threshold")
 var state: Dictionary = f.s.ledger.model.state.duplicate(true)
 for candidate in ["Q2", "E1", "E2", "E3", "P1", "P2", "P3", "R1", "R2"]:
  f.hud.adapter.request("learn", {"slot_id":candidate.left(1), "candidate_id":candidate, "expected_rank":0})
  check(not f.c.last_result.accepted and f.c.last_result.reason == "candidate_not_implemented", "unsupported skill cannot be learned: " + candidate)
 check(f.s.ledger.model.state == state, "all unsupported requests atomic, no points or candidates written")
 f.hud.q_choices.Q3.upgrade.pressed.emit()
 check(not f.c.last_result.accepted and f.s.ledger.model.state == state, "no free rank from repeated zero-SP Button signal")
 var second = Session.new()
 check(not second.initialize_floor(f.sim, f.s.route, "attempt-second-owner", true).accepted or not second._owner_intact(), "already-bound Sim must not acquire a second authority")
 # The explicit host contract never calls a second initializer; fail closed here.
 check(is_same(f.sim.progression, f.s.ledger), "original live ledger is never replaced")
 close(f); completed.append("admission_and_normal_learning")
func q1_inherited() -> void:
 var f: Dictionary = fresh("Q1")
 if f.is_empty() or not combat(f): close(f); return
 var before: int = f.sim.cast_serial
 check(route(f, key(KEY_Q)).accepted and f.sim.ink_input.phase == "armed", "Q1 Q arms original source gesture")
 check(route(f, mouse(true, Vector2(1, 0))).accepted and f.sim.ink_input.phase == "drawing", "Q1 LMB down starts original drawing")
 check(f.sim.cast_serial == before, "Q1 down creates no early cast")
 var move := InputEventMouseMotion.new(); move.position = Vector2(4, 0)
 route(f, move)
 var result: Dictionary = route(f, mouse(false, Vector2(4, 0)))
 check(result.accepted and f.sim.cast_serial == before + 1 and f.sim.ink_input.phase == "idle", "Q1 only actual LMB-up releases preserved source wave")
 check(f.sim.ink_waves.size() == 1, "exact one Q1 effect")
 close(f); completed.append("Q1_inherited")
func q3_event_commit() -> void:
 var f: Dictionary = fresh()
 if f.is_empty() or not combat(f): close(f); return
 var before: Dictionary = f.sim.snapshot()
 check(route(f, key(KEY_Q), Vector3(2, 0, 0)).accepted, "Q3 Q only arms")
 check(f.sim.snapshot() == before and f.sim.ink_mountain.is_empty(), "Q3 preview reads without cast/CD/damage/time mutation")
 route(f, key(KEY_Q, false)); route(f, key(KEY_Q, true, true))
 check(f.sim.snapshot() == before, "key release/echo never commits Q3")
 var at: Vector3 = f.sim.hero.position
 var time_before: float = f.sim.hero_time
 route(f, key(KEY_W)); f.sim.step(.2); route(f, key(KEY_W, false))
 check(f.sim.hero_time > time_before and f.sim.hero.position != at and not f.router.q3_aim.is_empty(), "live movement/time continue during Q3 aim")
 var cast_before: int = f.sim.cast_serial
 # Contradictory keyboard/cached point must not win over THIS button position.
 var raised: Dictionary = route(f, mouse(true, Vector2(4, 0)), Vector3(-9, 0, -9))
 check(raised.accepted and f.sim.ink_mountain.position == Vector3(4, 0, 0), "fresh InputEventMouseButton.position authoritative without preceding motion")
 check(f.sim.cast_serial == cast_before + 1 and f.router.q3_aim.is_empty(), "one actual source raise after explicit down")
 var mountain: Dictionary = f.sim.ink_mountain.duplicate(true)
 var cd: float = f.sim.hero.cooldowns.q
 check(not route(f, mouse(true)).accepted, "duplicate physical down cannot collapse")
 check(not f.router.update_held_basic(Vector3(8, 0, 0)).accepted, "consumed Q3 down cannot become held BASIC")
 check(not route(f, mouse(false)).accepted and f.sim.ink_mountain == mountain, "Q3 mouse-up is inert")
 check(route(f, key(KEY_Q), Vector3(10, 0, 0)).accepted and f.router.q3_aim.phase == "collapse", "live mountain Q arms collapse identity")
 check(route(f, mouse(true, Vector2(10, 0))).accepted, "new explicit LMB down commits same mountain collapse")
 check(f.sim.ink_mountain.is_empty() and f.sim.cast_serial == cast_before + 1 and f.sim.hero.cooldowns.q == cd, "collapse shares root and spends no second cooldown")
 route(f, mouse(false))
 var raises: Array = f.events.filter(func(e): return e.get("kind", "") == "ink_q3_raised")
 var collapses: Array = f.events.filter(func(e): return e.get("kind", "") == "ink_q3_collapse_started")
 check(raises.size() == 1 and collapses.size() == 1 and raises[0].cast_id == collapses[0].cast_id, "actual kind event contract one raise/one same-root collapse")
 close(f); completed.append("Q3_event_commit")
func q3_expiry_identity() -> void:
 var f: Dictionary = fresh()
 if f.is_empty() or not combat(f): close(f); return
 route(f, key(KEY_Q)); route(f, mouse(true)); route(f, mouse(false)); route(f, key(KEY_Q))
 var identity: Dictionary = f.router.q3_aim.duplicate(true)
 var cast_before: int = f.sim.cast_serial
 var end: float = f.sim.ink_mountain.expires_at + .04
 while f.sim.hero_time < end: f.sim.step(.02)
 check(f.sim.ink_mountain.is_empty(), "actual source lifetime retires mountain while aimed")
 var result: Dictionary = route(f, mouse(true, Vector2(5, 0)))
 check(not result.accepted and f.sim.ink_mountain.is_empty() and f.sim.cast_serial == cast_before, "expired collapse click never silently becomes a new raise")
 check(f.events.filter(func(e): return e.get("kind", "") == "ink_q3_raised").size() == 1, "only original raise event after stale collapse click")
 check(identity.phase == "collapse" and not str(identity.terrain_id).is_empty(), "arming captured phase plus exact terrain identity")
 route(f, mouse(false)); close(f); completed.append("Q3_expiry_identity")
func q3_cancel_boundaries() -> void:
 for reason in ["right", "escape", "ui", "focus", "control", "room", "death", "shift"]:
  var f: Dictionary = fresh()
  if f.is_empty() or not combat(f): close(f); continue
  route(f, key(KEY_Q)); route(f, mouse(true)); route(f, mouse(false)); route(f, key(KEY_Q))
  var mountain_id: String = f.sim.ink_mountain.terrain_id
  var serial_before: int = f.sim.cast_serial
  match reason:
   "right": route(f, mouse(true, Vector2(4,0), MOUSE_BUTTON_RIGHT))
   "escape": route(f, key(KEY_ESCAPE))
   "ui": route(f, mouse(true), Vector3.ZERO, true)
   "focus": f.router.focus_lost()
   "control": f.sim.damage_hero(0, Vector3.ZERO, .2, true, true)
   "room": f.sim.end_encounter("victory")
   "death": f.sim.damage_hero(100000, Vector3.ZERO, 0, true, true)
   "shift":
    var dash: Dictionary = route(f, key(KEY_SHIFT), f.sim.hero.position + Vector3.RIGHT * 8)
    check(dash.accepted, "existing Shift admission remains live during Q3 aiming")
  if reason == "shift":
   check(not f.router.q3_aim.is_empty(), "normal Shift preserves preview until explicit cancellation or source boundary")
   route(f, key(KEY_ESCAPE))
  else: check(f.router.q3_aim.is_empty(), "preview cleared at actual boundary: " + reason)
  if reason not in ["room", "death"]:
   check(not f.sim.ink_mountain.is_empty() and f.sim.ink_mountain.terrain_id == mountain_id, "preview boundary never cancels persistent source mountain: " + reason)
  var after_boundary: int = f.sim.cast_serial
  f.router.update_held_basic(Vector3(8,0,0)); route(f, mouse(false))
  check(f.sim.cast_serial == after_boundary and after_boundary <= serial_before + 1, "held/update/release cannot auto-fire after boundary: " + reason)
  close(f)
 completed.append("Q3_cancel_boundaries")
func training_switch() -> void:
 var f: Dictionary = fresh("Q1", true)
 if f.is_empty(): return
 f.hud.adapter.request("respec")
 check(not f.c.last_result.accepted and f.sim.hero.loadout.q == "q1", "respec denied before entering actual training service")
 check(f.s.select_node(1, "r01").accepted and f.s.enter_selected_node().accepted, "diagnostic service entered through real row/owner contract")
 var selected: Array = f.s.ledger.model.state.selected_hex.duplicate()
 f.hud.respec_button.pressed.emit()
 check(f.c.last_result.accepted and f.s.ledger.model.state.points == 1 and f.sim.hero.ranks.q == 0, "real training respec refunds only original investment and projects rank0")
 f.hud.q_choices.Q3.upgrade.pressed.emit()
 check(f.c.last_result.accepted and f.sim.hero.loadout.q == "q3" and f.sim.hero.ranks.q == 1 and f.s.ledger.model.state.points == 0, "actual same-column switch uses refunded SP through Controller/Bridge")
 check(f.s.ledger.model.state.selected_hex == selected and f.s.ledger.model.state.gold == 0, "respec preserves chosen Hex and zero wallet")
 for id in selected:
  var active: bool = f.s.ledger.definitions.hexes[id].requires == "Q3"
  check((f.s.ledger.model.snapshot().hex_status[id] == "active") == active, "personal dependency dormancy updates with actual Q switch")
 close(f); completed.append("training_switch")
func fixture_personal_dependency() -> void:
 # Isolated dependency fixture. All four source hooks are supported, but only
 # the selected skill family's personal effects are projected as active.
 var f: Dictionary = fresh("Q1", true)
 if f.is_empty(): return
 check(f.s.select_node(1,"r01").accepted and f.s.enter_selected_node().accepted, "dependency fixture enters real training service")
 var model = f.s.ledger.model
 model.state.selected_hex = ["yanguizhou_h01","yanguizhou_h02","yanguizhou_h05","yanguizhou_h06"]
 model.state.revision += 1
 f.s.runtime_projection_pending = true; f.s.flush_initial_projection(); f.c.refresh()
 for id in model.state.selected_hex:
  var expected: bool = id in ["yanguizhou_h01","yanguizhou_h02"]
  check((model.snapshot().hex_status[id]=="active")==expected and (id in f.sim.hero.hexes)==expected, "TEST_PERSONAL_SET Q1 active/dormant model and source consumer: "+id)
 f.hud.respec_button.pressed.emit()
 check(f.c.last_result.accepted and f.sim.hero.ranks.q==0, "real respec retires learned source dependency")
 for id in model.state.selected_hex: check(model.snapshot().hex_status[id]=="dormant" and id not in f.sim.hero.hexes, "all four dormant while genuinely unlearned: "+id)
 f.hud.q_choices.Q3.upgrade.pressed.emit()
 for id in model.state.selected_hex:
  var expected: bool = id in ["yanguizhou_h05","yanguizhou_h06"]
  check((model.snapshot().hex_status[id]=="active")==expected and (id in f.sim.hero.hexes)==expected, "real Q3 learn flips actual Model/Bridge dependencies: "+id)
 observations["dependency_fixture"]={"explicit_test_selected_personal_set":model.state.selected_hex.duplicate(),"not_normal_offer_history":true,"runtime_free_selection_path":false}
 close(f); completed.append("fixture_personal_dependency")
func fixture_ranks_caps() -> void:
 # Clearly isolated Model fixture; never called by runtime/Session/host.
 var f: Dictionary = fresh("Q3", true)
 if f.is_empty(): return
 check(f.s.select_node(1,"r01").accepted and f.s.enter_selected_node().accepted, "rank fixture enters real training service")
 f.hud.respec_button.pressed.emit()
 var model = f.s.ledger.model
 model.state.level = 6; model.state.points = 6; model.state.granted_level_ids = [1,2,3,4,5,6]
 # Resolve actual pending milestone through actual controller, not forged offers.
 f.c.ensure_auto_hex(); f.hud.adapter.request("hex_select", {"milestone":4,"slot":3})
 for rank in range(1,7):
  f.hud.q_choices.Q3.upgrade.pressed.emit()
  check(f.c.last_result.accepted and f.sim.hero.ranks.q == rank and model.state.points == 6-rank, "TEST_LV6_AUTHORITY actual command+projection rank%d" % rank)
 var before: Dictionary = model.state.duplicate(true)
 f.hud.q_choices.Q3.upgrade.pressed.emit()
 check(not f.c.last_result.accepted and f.c.last_result.reason == "rank_cap" and model.state == before, "rank7 blocked atomically at original Q6 ceiling")
 var snapshot: Dictionary = model.snapshot()
 check(snapshot.rank_caps == {"P":4,"Q":6,"E":6,"R":4} and snapshot.leveling_sp_budget == 18, "source Q/E6 P/R4 and base18 remain exact")
 f.hud.respec_button.pressed.emit()
 check(f.c.last_result.accepted and model.state.points == 6 and f.sim.hero.ranks.q == 0, "six actual investments refunded once by real respec")
 f.hud.respec_button.pressed.emit()
 check(model.state.points == 6, "repeat respec cannot mint SP")
 observations["rank_fixture"] = {"explicit_test_level":6,"explicit_test_available_SP":6,"runtime_seed_path":false,"real_Model_Controller_Bridge_commands":true}
 close(f); completed.append("fixture_ranks_caps")
func permutations(values: Array) -> Array:
 if values.is_empty(): return [[]]
 var out: Array = []
 for value in values:
  var remaining: Array = values.duplicate(); remaining.erase(value)
  for tail in permutations(remaining): out.append([value]+tail)
 return out
func fixture_all_prior_choices() -> void:
 var sim = Sim.new(); root.add_child(sim)
 var admitted: Dictionary = Binding.read_capabilities(sim, true)
 check(admitted.accepted, "fresh exact verified capabilities for isolated selector fixtures")
 if not admitted.accepted: sim.free(); return
 var built: Dictionary = Catalog.build(admitted.capabilities, Session.SHOP, true)
 check(built.accepted, "real catalog retained for isolated selector fixtures")
 if not built.accepted: sim.free(); return
 var effects: Array = []
 var template = Model.new(built.definitions, "yanguizhou", 1)
 template.set_supported_hooks(built.hooks)
 for id in built.definitions.hexes:
  if template.support(built.definitions.hexes[id]).supported: effects.append(id)
 var priors: Array = [[]]
 for id in effects: priors.append([id])
 for i in range(effects.size()):
  for j in range(i+1,effects.size()): priors.append([effects[i],effects[j]])
 var orders: Array = permutations([0,1,2,3])
 var cases := 0
 for prior in priors:
  var milestone: int = [1,4,7][prior.size()]
  for seed_value in [1,7,29]:
   for order in orders:
    var model = Model.new(built.definitions, "yanguizhou", seed_value)
    model.set_supported_hooks(built.hooks)
    model.state.level = milestone; model.state.selected_hex = prior.duplicate()
    # Explicit TEST_ONLY prior-selection state. Exclude effects by actual Model.
    check(model.initial_pool_readiness().accepted, "all legal prior sets pass original8/2 threshold at Lv%d" % milestone)
    var result: Dictionary = command(model,"hex_open",{"milestone":milestone})
    check(result.accepted, "actual Model four-card offer opens for prior fixture")
    if not result.accepted: continue
    var key_name: String = str(milestone)
    var seen: Array = model.state.offers[key_name].slots.duplicate()
    check(seen.size()==4 and built.definitions.hexes[seen[3]].hero=="yanguizhou", "four actual slots with reserved personal right card")
    for slot in order:
     result = command(model,"hex_refresh",{"milestone":milestone,"slot":slot})
     check(result.accepted, "every source refresh permutation succeeds")
     var id: String = model.state.offers[key_name].slots[slot]
     check(id not in seen and id not in prior, "refresh never repeats current/removed/previously selected effect")
     seen.append(id)
    check(seen.size()==8, "eight distinct offered effects consumed by four single refreshes")
    cases += 1
 # Later milestones retain the identical threshold; seven remaining cannot pass.
 var later = Model.new(built.definitions,"yanguizhou",1); later.set_supported_hooks(built.hooks)
 later.state.level=10; later.state.selected_hex=effects.slice(0,3)
 check(not later.initial_pool_readiness().accepted, "Lv10 may HOLD; no lowered thresholds or repeating selected effects")
 observations["selector_fixture"]={"legal_prior_subsets":priors.size(),"refresh_orders":orders.size(),"seeds":[1,7,29],"actual_Model_cases":cases,"scope":"all legal selected sets throughLv7, finite deterministic weighted draws; separate Python category-exhaustive proof"}
 sim.free(); completed.append("fixture_all_prior_choices")
