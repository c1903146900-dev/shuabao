extends SceneTree
## Main-owned NARROW gate. Actual initial resources, one real original-AI fight,
## then one genuinely connected training room. No mocked row or Boss completion.
## Separate funded commerce-kernel fixture below is explicitly NOT natural play.
const Sim = preload("res://tests/ink_q3_foundation_20261004/fix02/ink_q3_sim.gd")
const Session = preload("res://tests/ink_first_floor_user_route_20261005/runtime01/floor_session.gd")
const Router = preload("res://tests/ink_q3_input_growth_20261004/input_adapter.gd")
const Room = preload("res://tests/ink_first_floor_room_art_20261004/room_layout.gd")
const Map = preload("res://tests/ink_first_floor_user_route_20261005/runtime01/route_map.gd")
const Kernel = preload("res://tests/equipment_shop_transactions_20261004/shop_visit_model.gd")
const Numeric = preload("res://tests/equipment_shop_transactions_20261004/numeric_table_adapter.gd")
const HOME := "res://tests/ink_first_floor_user_route_20261005/runtime01/"
var failures: Array = []
var observations: Dictionary = {}
var cases: Array = []
var checks := 0
var serial := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> bool:
 checks += 1
 if not value: failures.append(label)
 return value
func complete(name: String) -> void:
 cases.append(name); print("INK_USER_ROUTE_CASE ",name)
func run() -> void:
 var loaded: Dictionary = Session.MixedSchema.load_definition(Session.DEFAULT_DEFINITION,true)
 if not check(loaded.accepted,"new runtime route admits"): finish(); return
 var definition: Dictionary = loaded.definition
 var checked: Dictionary = Session.MixedSchema.validate(definition,true)
 check(checked.get("complete_path_count",0) == 300 and checked.possible_node_count == 30,"all300 paths validated by runtime schema")
 var wrong: Dictionary = definition.duplicate(true)
 wrong.rows[0].nodes[0].next = ["r12boss"]
 check(not Session.MixedSchema.validate(wrong,true).accepted,"runtime rejects skipping eleven rows")
 wrong = definition.duplicate(true); wrong.payloads.rest.kind = "training"; wrong.payloads.rest.service.type = "training"
 check(not Session.MixedSchema.validate(wrong,true).accepted,"runtime rejects a graph whose every rest became training")
 wrong = definition.duplicate(true); wrong.payloads.rest.kind = "shop"; wrong.payloads.rest.service.type = "shop"
 check(not Session.MixedSchema.validate(wrong,true).accepted,"runtime rejects shop node")
 complete("runtime_graph_and_quota_guards")
 var map := Map.new(); root.add_child(map); map.size = Vector2(430,506); map.bind_route(definition)
 var state := {"completed_rows":[],"selected_identity":{},"status":"awaiting_selection"}
 var choices: Array = []
 for node: Dictionary in definition.rows[0].nodes: choices.append({"node_id":node.id})
 map.present(choices,state,false)
 var enabled := 0
 for button: Button in map.buttons.values():
  if not button.disabled: enabled += 1
 check(map.buttons.size() == 30 and enabled == 3,"actual map Control enables only three first-row nodes")
 check(map.centers.r12boss.y < map.centers.r01a.y,"map displays twelve horizontal rows bottom to top")
 map.present([],state,true)
 for button: Button in map.buttons.values(): check(button.disabled,"blocked map never leaves clickable path")
 map.free()
 complete("real_map_control_scope")
 var f: Dictionary = make_session(definition)
 if not f.is_empty():
  live_room_case(f)
  f.s.close_run(); f.sim.free()
 commerce_fixture_case()
 finish()
func make_session(definition: Dictionary) -> Dictionary:
 var sim := Sim.new(); root.add_child(sim); sim.hero.position = Vector3(0,0,4)
 Room.bind_to_sim(sim)
 var session := Session.new()
 var configured: Dictionary = session.configure_reward_table(HOME+"reward_table.json",HOME+"rewards.csv",HOME+"validation_result.json",true)
 if not check(configured.accepted,"independent XP trial bound to new route"): sim.free(); return {}
 if not check(session.initialize_floor(sim,definition,"user-route-narrow-%d" % Time.get_ticks_usec(),true).accepted,"single fresh real Session initializes"): sim.free(); return {}
 var router := Router.new(); router.bind(sim); session.bind_input_suspender(router.suspend_input)
 var f: Dictionary = {"sim":sim,"s":session,"router":router,"kills":[],"terminals":[],"event_failures":[]}
 sim.combat_event.connect(func(event: Dictionary):
  var result: Dictionary = session.observe_event(sim,event)
  if event.get("kind","") in ["damage","kill"] and not result.accepted: f.event_failures.append(result)
  if event.get("kind","") == "kill": f.kills.append(event.duplicate(true)))
 sim.encounter_finished.connect(func(event: Dictionary): f.terminals.append(event.duplicate(true)); session.queue_terminal(sim,event))
 return f
func command(f: Dictionary, action: String, args: Dictionary) -> Dictionary:
 serial += 1
 var result: Dictionary = f.s.ledger.model.command("route-model-%d" % serial,action,args)
 f.s.progression_command_completed({"action":action,"args":args},result); f.s.update_after_source_step()
 return result
func live_room_case(f: Dictionary) -> void:
 var initial: Dictionary = f.s.ledger.model.snapshot()
 check(initial.gold == 0 and initial.xp == 0 and initial.level == 1 and initial.points == 1,"no diagnostic resources")
 check(not f.s.open_panel().accepted,"mandatory initial choice blocks shop")
 if not check(command(f,"hex_open",{"milestone":1}).accepted,"real initial offer opens"): return
 if not check(command(f,"hex_select",{"milestone":1,"slot":3}).accepted,"real personal choice selected"): return
 if not check(f.s.learn_q1().accepted,"learn Q1 with original point"): return
 f.s.update_after_source_step()
 check(f.s.open_panel().accepted,"initial noncombat area allows P shop API")
 var visit: Dictionary = f.s.ledger.model.state.shop_visit.duplicate(true)
 check(f.s.close_panel().accepted and f.s.open_panel().accepted,"same-room shop closes and reopens")
 check(f.s.ledger.model.state.shop_visit.epoch == visit.epoch,"reopening cannot manufacture new visit")
 f.s.close_panel()
 var before: Dictionary = f.s.ledger.model.snapshot()
 check(not f.s.select_node(12,"r12boss").accepted and not f.s.select_node(2,"r02b").accepted,"Session refuses arbitrary jumps before row1")
 check(before == f.s.ledger.model.snapshot(),"jump refusal has no economic mutation")
 if not check(f.s.select_node(1,"r01a").accepted and f.s.enter_selected_node().accepted,"actual original four-AI first room starts"): return
 check(f.sim.ai_enabled and f.sim.living().size() == 4,"source AI and original enemies active")
 check(not f.s.open_panel().accepted,"combat refuses shop")
 var steps := 0
 while f.s.status == "combat" and steps < 7200:
  drive_actual_combat(f,steps); f.sim.step(1.0/60.0); f.s.update_after_source_step(); steps += 1
 f.sim.hero.move_intent = Vector3.ZERO
 observations["first_combat"] = {"steps":steps,"actual_kills":f.kills.size(),"status":f.s.status,"phase":f.sim.phase,"gold":f.s.ledger.model.state.gold,"xp":f.s.ledger.model.state.xp,"event_failures":f.event_failures}
 if not check(f.s.status == "between_rooms" and f.sim.phase == "victory" and f.kills.size() == 4,"real first combat settles inside finite budget"): return
 check(f.event_failures.is_empty(),"live events authenticated")
 check(f.s.ledger.model.state.gold == 180 and f.s.ledger.model.state.xp == 108,"only four actual-kill rewards")
 check(f.s.open_panel().accepted,"settled battle allows shop without shop node")
 f.s.close_panel()
 check(not f.s.select_node(2,"r02c").accepted,"same next row unconnected node refused")
 if not check(f.s.select_node(2,"r02b").accepted and f.s.enter_selected_node().accepted,"actual connected training service enters"): return
 var gold: int = int(f.s.ledger.model.state.gold)
 var xp: int = int(f.s.ledger.model.state.xp)
 check(f.s.open_panel().accepted,"all actual noncombat training nodes allow shop")
 f.s.close_panel()
 check(f.s.complete_service().accepted and f.s.open_panel().accepted,"completed service still allows same-room shop before departure")
 check(f.s.ledger.model.state.gold == gold and f.s.ledger.model.state.xp == xp,"service creates no combat rewards")
 f.s.close_panel()
 check(not f.s.settlement.has("major_floor_event") and f.s.status != "completed","no synthetic Boss or full-floor completion")
 complete("real_first_combat_and_connected_training_shop")
func drive_actual_combat(f: Dictionary, tick: int) -> void:
 if f.sim.paused or f.sim.hero.dead or f.sim.phase != "combat": return
 var living: Array = f.sim.living()
 if living.is_empty(): return
 var target: Dictionary = living[0]
 var distance: float = f.sim.hero.position.distance_to(target.position)
 for enemy: Dictionary in living:
  var other: float = f.sim.hero.position.distance_to(enemy.position)
  if other < distance: target = enemy; distance = other
 var offset: Vector3 = target.position-f.sim.hero.position
 f.sim.hero.move_intent = -offset.normalized() if distance < 4.0 else (offset.normalized() if distance > 8.0 else Vector3.ZERO)
 if target.state == "spawn": return
 if tick % 30 == 0:
  var armed: Dictionary = f.sim.request_ink_input("q_down")
  if armed.accepted:
   var anchored: Dictionary = f.sim.request_ink_input("left_down",f.sim.hero.position)
   if anchored.accepted:
    var end: Vector3 = f.sim.hero.position+offset.normalized()*8.0
    f.sim.request_ink_input("motion",end); f.sim.request_ink_input("left_up",end)
   else: f.sim.cancel_ink_preview("finite_gate_rejected_anchor")
 f.sim.request_action("attack",target.position)
func fixture_call(kernel: RefCounted, owner: RefCounted, action: String, extra: Dictionary = {}, trusted: bool = false) -> Dictionary:
 serial += 1
 var args: Dictionary = kernel.token(); args.merge(extra,true)
 return kernel.authority_command(owner,"isolated-funded-%d" % serial,action,args) if trusted else kernel.command("isolated-funded-%d" % serial,action,args)
func commerce_fixture_case() -> void:
 var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Session.FIXTURE))
 var numeric: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Session.NUMERIC))
 var projected: Dictionary = Numeric.build(source,numeric)
 if not check(projected.accepted,"isolated commerce source definitions build"): return
 var owner := RefCounted.new()
 var kernel := Kernel.new(projected.definitions,owner,"ISOLATED_FUNDED_COMMERCE_NOT_LIVE")
 # Explicit isolated evaluator funding, never placed in Sim/Session/Bridge.
 kernel.state.gold = 3000
 fixture_call(kernel,owner,"enter_room",{"next_room":"test-victory"},true)
 fixture_call(kernel,owner,"begin_visit",{"area":"test-victory/safe-shop"},true)
 fixture_call(kernel,owner,"open_ui")
 check(fixture_call(kernel,owner,"buy",{"item":"base:B02"}).accepted,"funded fixture purchase")
 var purchased: Dictionary = kernel.snapshot()
 fixture_call(kernel,owner,"close_ui"); fixture_call(kernel,owner,"open_ui")
 check(kernel.state.undo == purchased.undo and kernel.state.inventory == purchased.inventory and kernel.state.gold == purchased.gold,"close/reopen retains identical transactions")
 check(fixture_call(kernel,owner,"undo").accepted and kernel.state.gold == 3000,"same-room fixture transaction remains reversible")
 fixture_call(kernel,owner,"buy",{"item":"base:B02"})
 fixture_call(kernel,owner,"close_ui")
 check(fixture_call(kernel,owner,"enter_room",{"next_room":"test-rest"},true).accepted and kernel.state.undo.is_empty(),"noncombat next-room commits old transactions")
 fixture_call(kernel,owner,"begin_visit",{"area":"test-rest/safe-shop"},true); fixture_call(kernel,owner,"open_ui")
 check(not fixture_call(kernel,owner,"undo").accepted,"new noncombat shop cannot undo previous room")
 check(fixture_call(kernel,owner,"pay_body",{"purchase_id":"irreversible-body-fixture"},true).accepted,"isolated actual kernel body payment")
 var body: Dictionary = kernel.snapshot()
 check(not fixture_call(kernel,owner,"undo").accepted and kernel.state.gold == body.gold and kernel.state.body_receipts == body.body_receipts,"body payment has no reversible entry")
 fixture_call(kernel,owner,"buy",{"item":"base:B02"}); fixture_call(kernel,owner,"close_ui")
 check(fixture_call(kernel,owner,"enter_room",{"next_room":"test-combat"},true).accepted and kernel.state.undo.is_empty(),"combat next-room commits old transactions")
 fixture_call(kernel,owner,"battle_begin",{"battle_id":"actual-kernel-test-phase"},true)
 check(not fixture_call(kernel,owner,"undo").accepted,"combat refuses transaction undo")
 observations["commerce"] = {"scope":"isolated kernel with explicit3000 test gold; not live Session/natural earnings","body_payment_receipt":body.body_receipts,"final_gold":kernel.state.gold}
 complete("isolated_room_commit_and_irreversible_body_kernel")
func finish() -> void:
 var expected: Array = ["runtime_graph_and_quota_guards","real_map_control_scope","real_first_combat_and_connected_training_shop","isolated_room_commit_and_irreversible_body_kernel"]
 check(cases == expected,"all four narrow cases complete")
 var result := {"suite":"ink_user_route_narrow_v1","checks":checks,"failures":failures,"cases":cases,"observations":observations,"passed":failures.is_empty(),"full_floor":false,"boss_executed":false,"native_input":false,"art_accepted":false,"source_binding_sha256":FileAccess.get_sha256(HOME+"source_binding.json")}
 print("INK_USER_ROUTE_RESULT ",JSON.stringify(result))
 quit(0 if failures.is_empty() else 1)
