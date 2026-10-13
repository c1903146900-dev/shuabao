extends SceneTree
## Finite mechanical fixture: explicit damage, state/funding injection and callback
## injection are labelled. Real row/commerce/health authorities are never mocked.
const Sim = preload("res://tests/ink_p1_ordinary_20261006/candidate01/lifesteal01/sim.gd")
const Session = preload("res://tests/ink_rest_service_20261006/candidate01/floor_session.gd")
const Host = preload("res://tests/ink_rest_service_20261006/candidate01/host.gd")
const Router = preload("res://tests/ink_r1_ordinary_20261005/candidate01/ordinary01/input_adapter.gd")
const Binding = preload("res://tests/ink_p1_ordinary_20261006/candidate01/ordinary01/live_binding.gd")
const CallbackFixture = preload("res://tests/ink_rest_service_20261006/candidate01/health_callback_fixture.gd")
const FlaskKernel = preload("res://tests/equipment_shop_transactions_20261004/shop_visit_model.gd")
const HOME := "res://tests/ink_first_floor_user_route_20261005/runtime01/"
var checks := 0
var failures: Array[String] = []
var groups: Array[String] = []
var serial := 0
var output_path := "user://ink_rest_finite.json"

class HealingObserver extends RefCounted:
 var source: RefCounted
 var session: RefCounted
 var invoked := 0
 var rejected: Array = []
 func record_health_dependency(sim: Node, kind: String, rev: int, before: float, after: float) -> void:
  source.record_health_dependency(sim,kind,rev,before,after)
  if not kind.begins_with("source_heal:rest_service"): return
  invoked += 1
  sim.hero.shields["callback"] = {"amount":29.0,"left":9.0}
  sim.hero.cooldowns.q = 7.0; sim.hero.slow_left = 4.0
  sim.common.runtime.dash_stacks = 3; sim.common.runtime.dash_until = 999.0
  sim.common.runtime.next_rescue = 999.0
  rejected.append(not session.rest_service.settle(session,session._active_entry).accepted)
  rejected.append(not session.enter_selected_node().accepted)
  rejected.append(not session.complete_service().accepted)
  rejected.append(not sim.request_action("q").accepted)

func _initialize() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--rest-result="): output_path = arg.trim_prefix("--rest-result=")
 run.call_deferred()
func check(ok: bool, label: String) -> bool:
 checks += 1
 if not ok: failures.append(label); push_error(label)
 return ok
func command(f: Dictionary, action: String, args: Dictionary) -> Dictionary:
 serial += 1
 var result: Dictionary = f.s.ledger.model.command("rest-fixture-%d"%serial,action,args)
 f.s.progression_command_completed({"action":action,"args":args},result)
 f.s.update_after_source_step()
 return result
func settle_choices(f: Dictionary) -> void:
 for milestone in f.s.ledger.model.snapshot().pending_milestones.duplicate():
  check(command(f,"hex_open",{"milestone":milestone}).accepted,"fixture opens actual mandatory offer")
  check(command(f,"hex_select",{"milestone":milestone,"slot":3}).accepted,"fixture selects actual offer")
func fixture() -> Dictionary:
 var sim = Sim.new(); root.add_child(sim); sim.ai_enabled = false
 var session = Session.new()
 check(session.configure_reward_table(HOME+"reward_table.json",HOME+"rewards.csv",HOME+"validation_result.json",true).accepted,"original reward table bound")
 var loaded: Dictionary = Session.MixedSchema.load_definition(Session.DEFAULT_DEFINITION,true)
 if not check(session.initialize_floor(sim,loaded.definition,"rest-finite-%d"%Time.get_ticks_usec(),true).accepted,"exact P1 Sim single Rest Session binds"): sim.free(); return {}
 var router = Router.new(); router.bind(sim); session.bind_input_suspender(router.suspend_input)
 var f: Dictionary = {"sim":sim,"s":session,"router":router,"event_errors":[]}
 sim.combat_event.connect(func(event: Dictionary):
  var result: Dictionary = session.observe_event(sim,event)
  if event.get("kind","") in ["damage","kill"] and not result.accepted: f.event_errors.append(result))
 sim.encounter_finished.connect(func(event: Dictionary): session.queue_terminal(sim,event))
 var state: Dictionary = session.ledger.model.snapshot()
 check(state.level == 1 and state.gold == 0 and state.xp == 0 and state.points == 1,"ordinary zero-resource initial authority preserved")
 settle_choices(f)
 check(session.learn_q1().accepted,"original 1SP learns Q1")
 return f
func enter(f: Dictionary, row: int, id: String) -> Dictionary:
 settle_choices(f)
 if not check(f.s.select_node(row,id).accepted,"legal row selection "+id): return {"accepted":false}
 var result: Dictionary = f.s.enter_selected_node()
 check(result.accepted,"legal row entry "+id+": "+str(result.get("reason","")))
 return result
func finish_fixture_combat(f: Dictionary) -> void:
 # Bounded source-damage fixture; not natural skill play or native input.
 for _i in range(80):
  f.sim.step(.02); f.s.update_after_source_step()
 for enemy: Dictionary in f.sim.living().duplicate():
  f.sim.damage_enemy(enemy,1000000.0,"rest_gate_fixture",0,true,false,{"direct":false,"no_reactions":true})
 f.sim.step(.02); f.s.update_after_source_step()
 check(f.s.status == "between_rooms" and f.sim.phase == "victory","real source terminal settles fixture kills")
 check(f.event_errors.is_empty(),"all fixture damage/kill receipts authenticated")
 settle_choices(f)
func run() -> void:
 var host = Host.new()
 var factory = host._make_floor_session()
 check(not factory.rest_service.settle(factory,{}).accepted,"uninitialized owner rejects rest without invalid Sim access")
 var factory_script: GDScript = factory.get_script()
 var factory_sim = host._make_floor_sim()
 var sim_script: GDScript = factory_sim.get_script()
 check(factory_script.resource_path == "res://tests/ink_rest_service_20261006/candidate01/floor_session.gd","leaf host selects one Rest Session")
 check(sim_script.resource_path == Binding.SIM_PATH,"leaf host preserves exact admitted lifesteal P1 Sim")
 factory_sim.free(); host.free()
 groups.append("exact_factory_and_single_owner")
 var f: Dictionary = fixture()
 if not f.is_empty():
  exercise(f)
  flask_economic_contract(f.s.ledger.model.commerce_definitions)
  f.s.close_run()
  check(not f.s.rest_service.settle(f.s,f.s._active_entry).accepted,"closed run rejects former rest request")
  f.sim.free()
  check(not f.s.rest_service.settle(f.s,{}).accepted,"closed owner with freed Sim rejects without invalid object access")
 for required: String in ["exact_factory_and_single_owner","real_committed_rest_hp_cleanup_callback_and_permanent_state","idempotent_refresh_continue_nonrest_and_original_flask_reset","existing_flask_entitlement_economic_reset_only"]:
  check(required in groups,"required group completed: "+required)
 var report: Dictionary = {"passed":failures.is_empty(),"checks":checks,"failures":failures,"groups":groups,"gate_sha256":FileAccess.get_sha256(get_script().resource_path),"parent_binding":FileAccess.get_sha256(Binding.BINDING_PATH),"scope":"finite real-authority rest fixture with explicit funding, damage and transient injections","native_input":false,"natural_progression":false,"full_floor":false,"art_audio_accepted":false}
 var file := FileAccess.open(output_path,FileAccess.WRITE)
 if file == null: report.passed = false; failures.append("result_file_write_failed")
 else: file.store_string(JSON.stringify(report,"  ")); file.close()
 print("INK_REST_REPORT ",JSON.stringify(report)); quit(0 if report.passed else 1)
func exercise(f: Dictionary) -> void:
 var sim: Node = f.sim
 var s: RefCounted = f.s
 check(not s.rest_service.settle(s,{}).accepted,"preparation cannot request rest directly")
 check(not s.select_node(3,"r03a").accepted,"illegal row skipping cannot obtain rest")
 if not enter(f,1,"r01a").accepted: return
 check(not s.rest_service.settle(s,{}).accepted,"combat cannot request rest")
 finish_fixture_combat(f)
 sim.hero.hp = 200.0; sim.observe_pending_health(); sim.hero.cooldowns.r = 35.0
 if not enter(f,2,"r02a").accepted: return
 check(sim.hero.hp == 200.0 and sim.hero.cooldowns.r == 35.0,"non-rest combat entry grants no rest HP/CD service")
 finish_fixture_combat(f)
 # Explicit funded equipment fixture, never host startup or a natural affordability claim.
 s.ledger.model.state.gold = 2000; s.ledger.model.state.revision += 1
 check(s.open_panel().accepted,"settled victory opens original commerce")
 var args: Dictionary = s.ledger.model.commerce_token(); args["item"] = "base:B01"
 check(s.submit("rest-fixture-buy", "buy", args).accepted,"funded fixture buys real permanent equipment")
 check(s._authority("pay_body",{"purchase_id":"rest-fixture-body"}).accepted,"funded fixture purchases original body choice")
 var body: Dictionary = s.ledger.model.snapshot().body_pending
 if check(not body.is_empty(),"original body pool exposes pending choice"):
  check(command(f,"select_body",{"purchase_id":body.purchase_id,"outcome":body.candidates[0]}).accepted,"fixture commits an actual permanent body outcome")
 check(not s.ledger.model.commerce_quote("elixir:01").accepted,"unimplemented consumable remains closed")
 s.close_panel()
 check(not s.ledger.model.state.shop_visit.undo.is_empty(),"preceding real shop journal exists")
 # Seed actual live temporary fields and depleted charges. No synthetic row receipt.
 seed_transients(sim)
 sim.hero.hp = 123.0; sim.observe_pending_health()
 s.ledger.model.state.shop_visit.flask_charges = 0
 var permanent: Dictionary = permanent_state(f)
 var wave: int = sim.wave
 var generation: int = sim.encounter_generation
 var revision: int = sim.equipment_health_revision
 check(s.select_node(3,"r03a").accepted,"real connected rest selected after two settled rooms")
 var selected: Dictionary = s.row_state.snapshot()
 sim.transaction_active = true
 check(not s.enter_selected_node().accepted and sim.hero.hp == 123.0,"transaction blocks selected rest without refill")
 sim.transaction_active = false; sim.hero.dead = true
 check(not s.enter_selected_node().accepted and sim.hero.hp == 123.0,"dead hero cannot enter rest or revive")
 sim.hero.dead = false
 check(s.row_state.snapshot() == selected,"rejected entries preserve selected RowState")
 var observer := HealingObserver.new(); observer.session = s
 var callback_service = CallbackFixture.new(s); callback_service.observer = observer
 s.rest_service = callback_service
 var entered: Dictionary = s.enter_selected_node()
 if observer.source != null: sim._equipment_health_owner = weakref(observer.source)
 if not check(entered.get("accepted",false),"complete real rest entry accepted: "+str(entered.get("reason",""))): return
 check(sim.hero.hp == sim.hero.stats.max_hp,"rest heals to final unbuffed max HP")
 check(sim.equipment_health_revision == revision+1,"one actual heal advances original health dependency exactly once")
 check(observer.invoked == 1 and observer.rejected.size() == 4 and not false in observer.rejected,"healing callback cannot reenter rest, room, service or cast")
 callback_service.observer = null; observer.session = null; observer.source = null
 assert_clear(sim)
 check(permanent_state(f) == permanent,"equipment, progression, Hex, permanent growth and flask state retained")
 check(sim.wave == wave and sim.encounter_generation == generation,"rest never starts combat or resets generation")
 check(s.ledger.model.state.shop_visit.undo.is_empty(),"successful rest entry committed previous shop journal first")
 check(is_same(sim.progression,s.ledger) and s._owner_intact(),"same Session ledger and health owner survive")
 groups.append("real_committed_rest_hp_cleanup_callback_and_permanent_state")
 var receipt: Dictionary = s._active_entry.duplicate(true)
 sim.hero.hp -= 17.0; sim.observe_pending_health(); sim.hero.cooldowns.q = 12.0
 var after_revision: int = sim.equipment_health_revision
 for _i in range(3): s.snapshot(); s.update_after_source_step()
 s.focus_lost(); check(s.explicit_resume().accepted,"same Session explicit Continue resumes")
 var replay: Dictionary = s.rest_service.settle(s,receipt)
 check(replay.accepted and replay.replayed and sim.hero.hp == sim.hero.stats.max_hp-17.0 and sim.hero.cooldowns.q == 12.0,"repeated settlement and UI/Continue do not refill HP/CD again")
 check(sim.equipment_health_revision == after_revision and s.rest_service.snapshot().size() == 1,"replay creates no health dependency or second receipt")
 check(not s.enter_selected_node().accepted,"same row cannot re-enter after entry")
 check(s.complete_service().accepted,"rest readiness uses original service completion")
 var stale: Dictionary = receipt.duplicate(true); stale.payload.entry_id = "wrong"
 check(not s.rest_service.settle(s,stale).accepted,"altered rest entry cannot obtain service")
 if not enter(f,4,"r04a").accepted: return
 check(sim.hero.hp == sim.hero.stats.max_hp-17.0 and sim.hero.cooldowns.q == 12.0,"training node grants no rest HP/CD")
 check(not s.rest_service.settle(s,receipt).accepted,"departed rest receipt rejected in training")
 check(s.ledger.model.state.shop_visit.flask_charges == 0,"rest and training keep depleted basic flask")
 check(s.complete_service().accepted,"training readiness remains original")
 if not enter(f,5,"r05a").accepted: return
 check(s.ledger.model.state.shop_visit.flask_entitlement.is_empty() and s.ledger.model.state.shop_visit.flask_charges == 0,"next combat does not grant unowned flask charges")
 check(sim.wave == wave+1 and sim.encounter_generation == generation+1,"only next combat advances generation")
 groups.append("idempotent_refresh_continue_nonrest_and_original_flask_reset")
func permanent_state(f: Dictionary) -> Dictionary:
 var m: Dictionary = f.s.ledger.model.state
 var common: RefCounted = f.sim.common.runtime
 return {"inventory":m.inventory.duplicate(true),"body":m.body.duplicate(true),"body_effects":f.s.ledger.model.body_effects().duplicate(true),"gold":m.gold,"xp":m.xp,"level":m.level,"points":m.points,"skills":m.skills.duplicate(true),"hexes":m.selected_hex.duplicate(true),"flasks":m.shop_visit.flask_charges,"hero_loadout":f.sim.hero.loadout.duplicate(true),"ranks":f.sim.hero.ranks.duplicate(true),"base":f.sim.hero.projected_base_stats.duplicate(true),"growth":common.growth,"growth_kills":common.growth_kills,"cooldown_groups":common.cooldown_groups,"cooldown_kills":common.cooldown_kills,"cooldown_elites":common.cooldown_elites,"cooldown_bosses":common.cooldown_bosses,"self_rescue_used":f.sim.hero.self_rescue_used}
func seed_transients(sim: Node) -> void:
 var h: RefCounted = sim.hero
 h.cooldowns = {"attack":2.0,"shift":3.0,"q":8.0,"e":9.0,"r":77.0,"passive":4.0,"fixture_extra":5.0}
 h.shields["fixture"] = {"amount":40.0,"left":12.0}; h.cast_state["exposed"] = {"left":8.0}
 h.slow_left = 8.0; h.slow_amount = .4; h.stun_left = 5.0; h.invulnerable_left = 3.0; h.untargetable = true
 h.lock_time = 2.0; h.movement_lock_left = 1.0; h.knockback = Vector3.ONE; h.standing_time = 8.0
 h.self_rescue_used = true
 var live: RefCounted = sim.common.runtime
 live.growth = 5; live.growth_kills = 2; live.cooldown_groups = 3; live.cooldown_kills = 1; live.cooldown_elites = 2; live.cooldown_bosses = 1
 live.dash_stacks = 3; live.dash_until = 99.0; live.final_until = 99.0; live.soul_speed_until = 99.0; live.boss_until = 99.0
 live.next_soul = 99.0; live.next_bombardment = 99.0; live.next_rescue = 99.0; live.next_turret = 99.0
 live.replay_charges = 3; live.rescue_energy = 14.0; live.debt.append({"amount":9.0}); live.shrink["fixture"] = {"until":99.0}
 live.shield_break_cooldowns["fixture"] = 99.0
 live._events.append({"kind":"fixture_pending"})
 sim.pending.append({"kind":"fixture_pending"}); sim.projectiles.append({"kind":"fixture_pending"}); sim.zones.append({"kind":"fixture_pending"})
func assert_clear(sim: Node) -> void:
 for amount in sim.hero.cooldowns.values(): check(float(amount) == 0.0,"all actual cooldown values ended")
 check(sim.hero.shields.is_empty() and sim.hero.cast_state.is_empty(),"actual shields and status dictionaries cleared")
 check(sim.hero.stun_left == 0.0 and sim.hero.slow_left == 0.0 and sim.hero.slow_amount == 0.0 and sim.hero.invulnerable_left == 0.0 and not sim.hero.untargetable,"actual control and immunity fields cleared")
 check(sim.hero.lock_time == 0.0 and sim.hero.movement_lock_left == 0.0 and sim.hero.knockback == Vector3.ZERO,"action/movement restrictions cleared")
 check(sim.pending.is_empty() and sim.projectiles.is_empty() and sim.zones.is_empty(),"queued simulation effects cleared")
 var live: RefCounted = sim.common.runtime
 check(live.dash_stacks == 0 and live.dash_until == 0.0 and live.final_until == 0.0 and live.soul_speed_until == 0.0 and live.boss_until == 0.0,"actual common timed buffs cleared after callback")
 check(live.next_soul == 0.0 and live.next_bombardment == 0.0 and live.next_rescue == 0.0 and live.next_turret == 0.0 and live.shield_break_cooldowns.is_empty(),"proc cooldowns ended")
 check(live.debt.is_empty() and live.shrink.is_empty() and live._events.is_empty() and live.replay_charges == 0 and live.rescue_energy == 0.0,"delayed debt and proc state cleared")

func flask_economic_command(kernel, owner: RefCounted, action: String, arguments: Dictionary, trusted: bool = true) -> Dictionary:
 serial += 1
 var args: Dictionary = kernel.token(); args.merge(arguments,true)
 return kernel.authority_command(owner,"rest-flask-economic-%d"%serial,action,args) if trusted else kernel.command("rest-flask-economic-%d"%serial,action,args)

func flask_economic_contract(definitions: Dictionary) -> void:
 # Separate existing economic Kernel fixture. Its consumer is NOT promoted into
 # the ordinary host. Funding/depletion are explicit, not natural gameplay.
 var owner := RefCounted.new()
 var kernel = FlaskKernel.new(definitions,owner,"rest-flask-economic-fixture")
 kernel.state.gold = 100000
 check(flask_economic_command(kernel,owner,"enter_room",{"next_room":"economic-first"}).accepted,"flask economic room identity enters")
 check(flask_economic_command(kernel,owner,"begin_visit",{"area":"economic-shop"}).accepted,"flask economic shop enters")
 check(flask_economic_command(kernel,owner,"open_ui",{},false).accepted,"flask economic shop opens")
 check(flask_economic_command(kernel,owner,"buy",{"item":"flask:1"},false).accepted,"existing economic purchase establishes actual flask entitlement")
 check(kernel.state.flask_entitlement=="flask:1" and kernel.state.inventory.size()==1,"economic fixture owns the matching flask item")
 check(flask_economic_command(kernel,owner,"battle_begin",{"battle_id":"economic-battle-1"}).accepted and kernel.state.flask_charges==2,"owned flask receives original two charges at battle begin")
 kernel.state.flask_charges = 0 # Labelled economic depletion, not a connected drink consumer.
 check(flask_economic_command(kernel,owner,"battle_end",{"battle_id":"economic-battle-1"}).accepted,"economic battle ends normally")
 check(flask_economic_command(kernel,owner,"enter_room",{"next_room":"economic-rest"}).accepted and kernel.state.flask_charges==0,"noncombat room commit alone does not refill the owned flask")
 check(flask_economic_command(kernel,owner,"enter_room",{"next_room":"economic-next"}).accepted,"economic next-room commit remains separate")
 check(flask_economic_command(kernel,owner,"battle_begin",{"battle_id":"economic-battle-2"}).accepted and kernel.state.flask_charges==2,"existing owned flask reset remains battle-only")
 groups.append("existing_flask_entitlement_economic_reset_only")
