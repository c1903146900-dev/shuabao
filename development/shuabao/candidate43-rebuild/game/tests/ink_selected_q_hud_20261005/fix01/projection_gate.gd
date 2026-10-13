extends SceneTree
## Finite pure + actual-source/Control tests. Main runs; source author never invokes apps.
const SelectedQModel = preload("res://tests/ink_selected_q_hud_20261005/projection.gd")
const Patch = preload("res://tests/ink_selected_q_hud_20261005/fix01/hud_patch.gd")
const BottomHUD = preload("res://tests/ink_style_specimen_20261004/revision10_hud/hud.gd")
const Sim = preload("res://tests/ink_q3_foundation_20261004/fix02/ink_q3_sim.gd")
const Session = preload("res://tests/ink_normal_floor_host_20261004/floor_session.gd")
const Controller = preload("res://tests/ink_q3_input_growth_20261004/controller.gd")
const GrowthHUD = preload("res://tests/ink_normal_floor_host_20261004/growth_hud.gd")
const Router = preload("res://tests/ink_q3_input_growth_20261004/input_adapter.gd")
const REWARDS := "res://tests/ink_first_floor_rewards_integration_20261004/"
var checks: int = 0
var failures: Array = []
var cases: Array = []
var observations: Dictionary = {}
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok: failures.append(label)
func complete(name: String) -> void:
 cases.append(name); print("INK_SELECTED_Q_CASE ",name)
func key(code: int) -> InputEventKey:
 var event := InputEventKey.new(); event.physical_keycode = code; event.pressed = true; return event
func mouse(pressed: bool) -> InputEventMouseButton:
 var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed; return event
func fixture(candidate: String = "q3", rank: int = 2) -> Dictionary:
 return {"generation":7,"room_id":"projection-only","hero_time":2.0,"revision":3,"phase":"combat","paused":false,"hero":{"loadout":{"q":candidate},"ranks":{"q":rank},"cooldowns":{"q":6.125,"attack":0.33,"shift":1.25},"dead":false,"dash_left":0.0}}
func fixture_context(full: Dictionary) -> Dictionary:
 return {"schema":SelectedQModel.SCHEMA,"source_instance":99,"generation":full.generation,"room_id":full.room_id,"hero_time":full.hero_time,"revision":full.revision,"candidate":full.hero.loadout.q,"rank":full.hero.ranks.q,"phase":full.phase,"paused":full.paused,"dead":full.hero.dead,"epsilon":0.00001,"rules_match":true,"controlled":false,"transaction_active":false,"lock_time":0.0,"dash_left":full.hero.dash_left,"mountain_current":true,"terrain_id":"7:projection-only:mountain:1","cast_id":4,"expires_at":4.0}
func fixture_ink(full: Dictionary) -> Dictionary:
 return {"scope":{"generation":full.generation,"room_id":full.room_id},"source_time":full.hero_time,"mountain":{"terrain_id":"7:projection-only:mountain:1","cast_id":4,"generation":full.generation,"room_id":full.room_id,"expires_at":4.0}}
func pure_cases() -> void:
 var full: Dictionary = fixture(); var ink: Dictionary = fixture_ink(full); var context: Dictionary = fixture_context(full)
 var before: PackedByteArray = var_to_bytes([full,ink,context])
 var shown: Dictionary = SelectedQModel.model_from(full,ink,context)
 check(shown.name == "溪山行旅" and shown.candidate == "q3" and shown.rank_text == "2级" and shown.learned,"Q3 actual selected rank and authoritative name")
 check(shown.q3_live and shown.recast_ready and shown.ready and shown.cooldown == 6.125,"Q3 live collapse bypass does not zero source cooldown")
 check(shown.cooldown_text == "CD 6.1s" and "起山冷却 6.125" in shown.tooltip,"compact rounded display plus exact three-decimal source detail")
 check(var_to_bytes([full,ink,context]) == before,"pure projection leaves every input byte unchanged")
 for candidate: String in ["q1","q3"]:
  for rank in [0,1,3,6]:
   var state: Dictionary = fixture(candidate,rank)
   var view: Dictionary = SelectedQModel.model_from(state,{},fixture_context(state))
   check(view.rank == rank and view.learned == (rank > 0) and view.icon == candidate,"selected rank only %s/%d" % [candidate,rank])
   check(view.name == ("飞流三千" if candidate == "q1" else "溪山行旅"),"source name %s/%d" % [candidate,rank])
 var empty: Dictionary = fixture("",0)
 shown = SelectedQModel.model_from(empty,{},fixture_context(empty))
 check(shown.name == "Q未学习" and shown.rank_text == "未学" and not shown.learned and shown.cooldown_text == "CD —" and shown.icon == "unlearned","empty Q slot never claims either candidate learned or ready")
 var unknown: Dictionary = fixture("q2",1)
 shown = SelectedQModel.model_from(unknown,{},fixture_context(unknown))
 check(not shown.learned and not shown.ready and not shown.q3_live,"unsupported candidate not projected as Q1/Q3")
 shown = SelectedQModel.model_from({}, {}, {})
 check(not shown.learned and not shown.ready and shown.cooldown_text == "CD —","missing snapshot fails closed")
 complete("selected_identity_rank_name_and_no_mutation")
 for field: String in ["generation","room_id","hero_time","revision","candidate","rank","source_instance"]:
  var stale: Dictionary = context.duplicate(true)
  if field in ["room_id","candidate"]: stale[field] = "stale"
  elif field == "source_instance": stale[field] = 0
  else: stale[field] = -99
  shown = SelectedQModel.model_from(full,ink,stale)
  check(not shown.q3_live and not shown.ready,"stale context denied "+field)
 for field: String in ["generation","room_id","cast_id","terrain_id","expires_at"]:
  var stale_ink: Dictionary = ink.duplicate(true)
  if field in ["room_id","terrain_id"]: stale_ink.mountain[field] = "stale"
  else: stale_ink.mountain[field] = -99
  shown = SelectedQModel.model_from(full,stale_ink,context)
  check(not shown.q3_live and not shown.recast_ready,"stale mountain denied "+field)
 var cancelled: Dictionary = context.duplicate(true); cancelled.mountain_current = false
 check(not SelectedQModel.model_from(full,ink,cancelled).q3_live,"cancelled source cast denies live recast")
 var expired_full: Dictionary = full.duplicate(true); expired_full.hero_time = 4.0
 var expired_ink: Dictionary = fixture_ink(expired_full)
 check(not SelectedQModel.model_from(expired_full,expired_ink,fixture_context(expired_full)).q3_live,"source expiry boundary denies recast without any wall clock")
 for field: String in ["controlled","transaction_active","rules_match","lock_time","dash_left"]:
  var blocked: Dictionary = context.duplicate(true); var blocked_full: Dictionary = full.duplicate(true)
  if field == "rules_match": blocked[field] = false
  elif field in ["lock_time","dash_left"]: blocked[field] = 1.0
  else: blocked[field] = true
  if field == "dash_left": blocked_full.hero.dash_left = 1.0
  shown = SelectedQModel.model_from(blocked_full,ink,blocked)
  check(shown.q3_live and not shown.recast_ready and not shown.ready,"live terrain with blocked readiness "+field)
 for field: String in ["paused","dead","phase"]:
  var blocked_full: Dictionary = full.duplicate(true)
  if field == "dead": blocked_full.hero.dead = true
  elif field == "phase": blocked_full.phase = "safe"
  else: blocked_full.paused = true
  var blocked: Dictionary = fixture_context(blocked_full)
  shown = SelectedQModel.model_from(blocked_full,ink,blocked)
  check(not shown.recast_ready and not shown.ready,"readiness guard "+field)
 var no_mountain: Dictionary = ink.duplicate(true); no_mountain.mountain = {}
 shown = SelectedQModel.model_from(full,no_mountain,context)
 check(not shown.q3_live and shown.reason == "cooldown" and shown.cooldown == 6.125,"retired mountain reveals unchanged underlying cooldown")
 var missing_cd: Dictionary = full.duplicate(true); missing_cd.hero.cooldowns.erase("q")
 shown = SelectedQModel.model_from(missing_cd,no_mountain,fixture_context(missing_cd))
 check(not shown.ready and shown.cooldown_text == "CD —","missing cooldown not fabricated as zero")
 complete("source_scope_expiry_and_recast_guards")

func authority_bytes(source: Node, session: RefCounted, router: RefCounted) -> PackedByteArray:
 return var_to_bytes([source.snapshot(),source.ink_presenter_snapshot(),source.ink_mountain,source._casts,source.hero.lock_time,source.hero.stun_left,source.event_log,source.transaction_active,source.cast_serial,session.ledger.model.snapshot(),session.snapshot(),router.q3_aim,router._left_physical,router._suppress_held])
func display(source: Node, hud: Control) -> Dictionary:
 var full: Dictionary = source.snapshot(); var ink: Dictionary = source.ink_presenter_snapshot()
 hud.present(full,ink,{})
 return Patch.apply_to(hud,full,ink,SelectedQModel.capture_context(source))
func run() -> void:
 pure_cases()
 var source: Node = Sim.new(); root.add_child(source)
 var session: RefCounted = Session.new()
 var configured: Dictionary = session.configure_reward_table(REWARDS+"reward_table.json",REWARDS+"rewards.csv",REWARDS+"validation_result.json",true)
 var loaded: Dictionary = Session.MixedSchema.load_definition(Session.DEFAULT_DEFINITION,true)
 check(configured.accepted and loaded.accepted,"real normal-floor setup without grants")
 var admitted: Dictionary = session.initialize_floor(source,loaded.definition,"selected-q-hud-contract",true)
 check(admitted.accepted,"fresh source and single authoritative Session")
 if not admitted.accepted: source.free(); finish(); return
 var router: RefCounted = Router.new(); router.bind(source)
 check(session.bind_input_suspender(router.suspend_input).accepted,"actual input suspender bound")
 var growth: Control = GrowthHUD.new(); root.add_child(growth)
 var controller: RefCounted = Controller.new(); controller.bind_session(session,growth)
 var hud: Control = BottomHUD.new(); root.add_child(hud)
 var initial: Dictionary = display(source,hud)
 check(not initial.learned and hud.q_rank_label.text == "未学" and session.ledger.model.state.points == 1,"normal original1SP and honest empty bottom slot")
 controller.ensure_auto_hex(); growth.adapter.request("hex_select",{"milestone":1,"slot":3})
 check(controller.last_result.accepted,"actual mandatory initial choice")
 growth.q_choices.Q1.upgrade.pressed.emit()
 check(controller.last_result.accepted and source.hero.loadout.q == "q1" and session.ledger.model.state.points == 0,"genuine Q1 button consumes original1SP")
 var q1: Dictionary = display(source,hud)
 check(q1.learned and q1.name == "飞流三千" and hud.q_rank_label.text == "1级" and q1.icon == "q1","bottom Q1 agrees with learned source")
 growth.undo_button.pressed.emit()
 check(controller.last_result.accepted and not display(source,hud).learned and session.ledger.model.state.points == 1,"actual safe undo clears bottom learned state")
 growth.q_choices.Q3.upgrade.pressed.emit()
 check(controller.last_result.accepted and source.hero.loadout.q == "q3" and source.hero.ranks.q == 1,"genuine Q3 button reuses returned original1SP")
 var q3: Dictionary = display(source,hud)
 check(q3.learned and q3.name == "溪山行旅" and hud.q_rank_label.text == "1级" and q3.icon == "q3","bottom Q3 replaces Q1 name rank and shape")
 var children: int = hud.get_child_count()
 var before: PackedByteArray = authority_bytes(source,session,router)
 for index in range(40): display(source,hud)
 check(before == authority_bytes(source,session,router),"forty actual projection passes cannot change source ledger input clocks or cast state")
 check(hud.get_child_count() == children and hud.get_script() == BottomHUD,"patch idempotent and exact frozen HUD script retained")
 var card: Control = hud.get_node(NodePath(Patch.PATCH_NAME))
 check(card.position == Patch.CARD_RECT.position and card.size == Patch.CARD_RECT.size and card.mouse_filter == Control.MOUSE_FILTER_STOP,"tooltip covers only already-blocked Q footprint")
 check(card.get_index() < hud.shop_group.get_index(),"shop modal remains above projection")
 var basic: String = hud.basic_cooldown.text; var dash: String = hud.dash_cooldown.text
 var other_before: PackedByteArray = var_to_bytes([hud.health.text,hud.dash_label.text,hud.identity_level.text,hud.footer.text])
 Patch.apply_to(hud,source.snapshot(),source.ink_presenter_snapshot(),SelectedQModel.capture_context(source))
 check(hud.basic_cooldown.text == basic and hud.dash_cooldown.text == dash and other_before == var_to_bytes([hud.health.text,hud.dash_label.text,hud.identity_level.text,hud.footer.text]),"BASIC Shift HP level and footer remain untouched")
 complete("genuine_one_sp_learning_undo_and_bottom_controls")
 check(session.select_node(1,"r01").accepted and session.enter_selected_node().accepted,"real row1 entry without reward or combat shortcuts")
 var armed: Dictionary = router.handle_event(key(KEY_Q),Vector3(2,0,0))
 check(armed.accepted and source.ink_mountain.is_empty(),"manual Q arms without raising terrain")
 check(router.handle_event(mouse(true),Vector3(2,0,0)).accepted,"fresh manual LMB raises actual Q3")
 router.handle_event(mouse(false),Vector3(2,0,0))
 var raised: Dictionary = display(source,hud)
 check(raised.q3_live and raised.cooldown > 0.0 and raised.cooldown == source.hero.cooldowns.q,"actual live Q3 retains authoritative nonzero cooldown")
 # Advance only the real source API in this test to let its action lock expire.
 for index in range(120):
  if source.hero.lock_time <= source.TIME_EPS: break
  source.step(1.0/60.0)
 var live: Dictionary = display(source,hud)
 check(live.q3_live and live.recast_ready and live.cooldown > 0.0,"actual current mountain enables collapse during raise cooldown")
 before = authority_bytes(source,session,router)
 for index in range(40): display(source,hud)
 var live_unchanged: bool = before == authority_bytes(source,session,router)
 check(live_unchanged,"live recast projection never spends cooldown advances time or mutates mountain")
 check(router.handle_event(key(KEY_Q),Vector3(3,0,0)).accepted,"manual Q rearms collapse")
 check(router.handle_event(mouse(true),Vector3(3,0,0)).accepted,"fresh manual LMB collapses the real terrain")
 router.handle_event(mouse(false),Vector3(3,0,0))
 var collapsed: Dictionary = display(source,hud)
 check(not collapsed.q3_live and not collapsed.recast_ready and collapsed.cooldown == source.hero.cooldowns.q and collapsed.cooldown > 0.0,"collapse clears recast without fabricating cooldown reset")
 observations = {"initial":initial,"q1":q1,"q3":q3,"raised":raised,"live":live,"collapsed":collapsed,"source_time":source.hero_time,"source_unchanged_by_projection":live_unchanged}
 complete("actual_q3_raise_live_recast_and_collapse")
 session.close_run(); hud.free(); growth.free(); source.free()
 await process_frame
 await process_frame
 finish()
func finish() -> void:
 var result: Dictionary = {"suite":"selected_q_projection","binding":FileAccess.get_sha256("res://tests/ink_selected_q_hud_20261005/fix01/source_binding.json"),"checks":checks,"failures":failures,"cases":cases,"observations":observations,"passed":failures.is_empty() and cases.size() == 4,"scope":"finite read-only projection and actual Q1/Q3 contract","native_pixels":false,"performance":false,"full_floor":false,"final_art":false}
 print("INK_SELECTED_Q_PROJECTION ",JSON.stringify(result))
 quit(0 if result.passed else 1)
