extends SceneTree
## Main-owned finite source/Control contract. No host render, funds, kills or seeded ranks.
const Sim = preload("res://tests/ink_q3_foundation_20261004/fix02/ink_q3_sim.gd")
const Session = preload("res://tests/ink_normal_floor_host_20261004/floor_session.gd")
const Controller = preload("res://tests/ink_q3_input_growth_20261004/controller.gd")
const HUD = preload("res://tests/ink_normal_floor_host_20261004/growth_hud.gd")
const Router = preload("res://tests/ink_q3_input_growth_20261004/input_adapter.gd")
const ControlsHost = preload("res://tests/ink_normal_floor_host_20261004/controls_gate_host.gd")
const ActualAudio = preload("res://tests/ink_style_specimen_20261004/audio_output.gd")
const Enemy = preload("res://tests/ink_normal_floor_host_20261004/enemy_layer.gd")
const REWARDS := "res://tests/ink_first_floor_rewards_integration_20261004/"
var checks: int = 0
var failures: Array = []
var cases: Array = []
var observations: Dictionary = {}
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok: failures.append(label)
func key(code: int) -> InputEventKey:
 var event := InputEventKey.new(); event.physical_keycode = code; event.pressed = true; return event
func mouse(point: Vector2) -> InputEventMouseButton:
 var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = true; event.position = point; return event
func project(point: Vector2) -> Vector3: return Vector3(point.x,0,point.y)
func configure(session: RefCounted) -> Dictionary:
 return session.configure_reward_table(REWARDS+"reward_table.json",REWARDS+"rewards.csv",REWARDS+"validation_result.json",true)
func run() -> void:
 var source: Node = Sim.new(); root.add_child(source)
 var session: RefCounted = Session.new()
 var loaded: Dictionary = Session.MixedSchema.load_definition(Session.DEFAULT_DEFINITION,true)
 check(loaded.accepted,"exact route loads")
 var configured: Dictionary = configure(session)
 check(configured.accepted,"actual reward table configured once")
 check(not configure(session).accepted,"second reward configuration rejected")
 var admitted: Dictionary = session.initialize_floor(source,loaded.definition,"normal-host-contract",true)
 check(admitted.accepted,"one actual Q3 Session initializes")
 if not admitted.accepted:
  source.free(); finish(); return
 var router: RefCounted = Router.new(); router.bind(source)
 check(session.bind_input_suspender(router.suspend_input).accepted,"one input suspender bound")
 source.combat_event.connect(func(event: Dictionary): session.observe_event(source,event))
 source.encounter_finished.connect(func(snapshot: Dictionary): session.queue_terminal(source,snapshot))
 var host: Node3D = ControlsHost.new(); root.add_child(host)
 host.sim = source; host.shop_session = session; host.input_router = router
 host._mainprep_required = false; host.initial_started = true
 host.audio_output = ActualAudio.new(); host.add_child(host.audio_output)
 host._create_session_controls()
 var hud: Control = host.initial_hud
 var controller: RefCounted = host.initial_controller
 check(host.row_choices.get_child_count() == 1 and host.session_next.disabled,"real host row1 button shown; entry blocked by initial choice")
 var state: Dictionary = session.ledger.model.snapshot()
 check(state.gold == 0 and state.xp == 0 and state.points == 1 and state.level == 1,"original zero resources and1SP")
 check(session._owner_intact() and is_same(source.progression,session.ledger),"one Session/Sim/ledger authority")
 check(session.ledger.model.get_script().resource_path == "res://tests/ink_normal_floor_host_20261004/reward_model.gd","RewardModel selected at construction")
 check(session.ledger.model.reward_for_kind("minion").gold == 45 and session.ledger.model.reward_for_kind("minion").xp == 18,"bound trial values45/18 no grants")
 check(not session.enter_selected_node().accepted,"cannot enter without explicit choice")
 check(not session.open_panel().accepted and not session.reset_training().accepted,"initial safe area is neither shop nor training")
 complete("constructor_and_exact_authority")
 controller.ensure_auto_hex()
 check(hud.hex_required and hud.projection.choices.size() == 4 and source.paused,"real initial four cards and modal")
 for slot in range(4):
  hud.adapter.request("hex_refresh",{"milestone":1,"slot":slot})
  check(controller.last_result.accepted,"first real refresh slot%d" % slot)
  hud.adapter.request("hex_refresh",{"milestone":1,"slot":slot})
  check(not controller.last_result.accepted,"second refresh rejected slot%d" % slot)
 hud.adapter.request("hex_select",{"milestone":1,"slot":3})
 check(controller.last_result.accepted and not source.paused,"actual initial choice resumes original policy")
 hud.q_choices.Q3.upgrade.pressed.emit()
 check(controller.last_result.accepted and source.hero.loadout.q == "q3" and source.hero.ranks.q == 1,"Q3 actualButton consumes originalSP")
 check(session.ledger.model.state.points == 0,"no free learning")
 hud.undo_button.pressed.emit()
 check(controller.last_result.accepted and session.ledger.model.state.points == 1 and source.hero.ranks.q == 0,"safe undo projects actual source")
 hud.q_choices.Q3.upgrade.pressed.emit()
 check(controller.last_result.accepted,"safe real relearn after undo")
 hud.respec_button.pressed.emit()
 check(not session.last_receipt.accepted and session.last_receipt.reason == "entered_training_node_required","real host training signal reaches entered-node Session API")
 complete("initial_four_choice_refresh_learning_undo")
 var row_button: Button = host.row_choices.get_child(0)
 row_button.pressed.emit()
 check(session.row_state.snapshot().status == "selected","real host row1 Button explicitly selects once")
 check(not host.session_next.disabled and "r01" in host.session_next.text,"real host enter button reflects authoritative selection")
 check(row_button.get_parent() == null and row_button.disabled,"retired route Button detached and disabled during its own signal")
 check(not session.select_node(1,"r01").accepted,"same row cannot be selected twice")
 var entered: Dictionary = session.enter_selected_node()
 check(entered.accepted and source.enemies.size() == 4 and source.ai_enabled,"original four actualAI actors start once")
 # The composed host performs this after ALL public Session transitions.
 host._transition_result("gate_actual_entry",entered)
 check(int(hud.adapter.state.revision) == int(session.ledger.model.state.revision),"route transition refreshes Adapter revision")
 check(not session.enter_selected_node().accepted,"duplicate entry rejected")
 check(not session.open_panel().accepted and not session.complete_service().accepted and not session.reset_training().accepted,"combat denies all service operations")
 check(session.ledger.model.state.gold == 0 and session.ledger.model.state.xp == 0,"entry gives no reward")
 var before: PackedByteArray = var_to_bytes(source.snapshot())
 var armed: Dictionary = router.route_event(key(KEY_Q),project,Vector3(2,0,0))
 check(armed.accepted and armed.preview_only,"Q3 Q only arms")
 var shown: Dictionary = router.preview(Vector3(2,0,0))
 check(shown.accepted and var_to_bytes(source.snapshot()) == before,"source-backed preview has no source changes")
 var committed: Dictionary = router.route_event(mouse(Vector2(3,0)),project,Vector3(-9,0,-9))
 check(committed.accepted and not source.ink_mountain.is_empty() and source.ink_mountain.position.is_equal_approx(Vector3(3,0,0)),"freshLMB event coordinate raises actualterrain")
 router.suspend_input("contract_focus_loss")
 check(router.q3_aim.is_empty() and not source.ink_mountain.is_empty(),"focus cancellation preserves actualterrain")
 observations["entered_roster"] = source.enemies.size()
 observations["preview_no_mutation"] = shown.preview_only
 observations["source_time"] = source.hero_time
 complete("row_entry_revision_and_Q3_preview")
 var enemy: Node3D = Enemy.new(); root.add_child(enemy)
 var excess: Array = []
 for index in range(7): excess.append({"kind":"minion"})
 check(not enemy.preflight({"node_type":"combat","roster":excess}).accepted,"sevenactors rejected before any body import")
 enemy.hostile.actor_views = {"stale":Node3D.new()}
 var stale: Node3D = enemy.hostile.actor_views.stale
 enemy.reset_scope()
 check(enemy.hostile.actor_views.is_empty() and enemy.pending.is_empty(),"reset clears original VFX sockets and event queue")
 stale.free(); enemy.free()
 var wrong_source: Node = Sim.new(); root.add_child(wrong_source)
 var wrong: RefCounted = Session.new(); configure(wrong)
 var changed: Dictionary = loaded.definition.duplicate(true); changed.title += " changed"
 check(not wrong.initialize_floor(wrong_source,changed,"wrong-route-contract",true).accepted and wrong.ledger == null,"exact route guard rejects changed definition before binding")
 wrong_source.free()
 complete("presentation_capacity_reset_and_exact_route")
 session.close_run(); host.free(); source.free()
 await process_frame
 await process_frame
 finish()
func complete(name: String) -> void:
 cases.append(name)
 print("INK_NORMAL_FLOOR_CASE ",name)
func finish() -> void:
 var result: Dictionary = {"suite":"normal_floor_lifecycle","binding":FileAccess.get_sha256("res://tests/ink_normal_floor_host_20261004/source_binding.json"),"checks":checks,"failures":failures,"cases":cases,"observations":observations,"passed":failures.is_empty() and cases.size() == 4,"scope":"finite actual source/Control contracts only","whole_floor":false,"actual_service_visit":false,"real_device_input":false,"imports_art_performance":false}
 var file: FileAccess = FileAccess.open("res://tests/ink_normal_floor_host_20261004/lifecycle_result.json",FileAccess.WRITE)
 if file != null: file.store_string(JSON.stringify(result,"  ")); file.close()
 print("INK_NORMAL_FLOOR_LIFECYCLE ",JSON.stringify(result))
 quit(0 if result.passed else 1)
