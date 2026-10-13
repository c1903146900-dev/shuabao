extends SceneTree
## Prepared real-source finite gate. Author must not execute an engine.
const Bridge = preload("res://tests/ink_shop_runtime_stats_20261004/ink_stat_bridge.gd")
const Sim = preload("res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_sim.gd")
const Adapter = preload("res://tests/ink_shop_runtime_stats_20261004/base_stat_adapter.gd")
const SHOP = "res://tests/ink_first_floor_flow_20261004/fixtures/provisional_shop.json"
const FIXTURE = "res://tests/equipment_shop_transactions_20261004/fixtures/source_prices.json"
const NUMERIC = "res://tests/equipment_editable_tables_20261004/outputs/equipment_tables/converted/equipment_numeric_config.json"
const EDITED = "res://tests/equipment_editable_tables_20261004/proof/one_value_change_converted/equipment_numeric_config.json"
var owner = RefCounted.new()
var serial: int = 0
var checks: int = 0
var failures: Array = []
var measurements: Dictionary = {}
func _initialize() -> void: call_deferred("run")
func run() -> void:
 _source_mapping()
 _projection_transactions()
 _hit_consumers()
 _hp_lifecycle()
 _manual_aim_preserved()
 _rooms_and_rewards()
 _body_dependencies()
 var report: Dictionary = {"suite":"ink_base_equipment_real_runtime", "checks":checks, "failures":failures, "measurements":measurements, "scope":"real_source_finite_fixture_no_OS_input_or_art_balance_acceptance", "passives_actives_tasks_potion_consumers":"HOLD", "production_ready":false}
 print("INK_EQUIPMENT_RUNTIME_REPORT ", JSON.stringify(report))
 var output = FileAccess.open("res://tests/ink_shop_runtime_stats_20261004/engine_result.json", FileAccess.WRITE)
 output.store_string(JSON.stringify(report, "  ")); output.close()
 quit(0 if failures.is_empty() else 1)
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok: failures.append(label); push_error(label)
func near(actual: float, expected: float, label: String) -> void:
 check(is_finite(actual) and absf(actual-expected) < 0.00001, "%s: %.8f expected %.8f" % [label, actual, expected])
func _capabilities() -> Dictionary:
 var hooks: Array = ["stats.v1", "equipment.task_completion.v1", "hex.final_design.yanguizhou_h01.v1"]
 for stat in ["AD", "AP", "attack_speed", "max_hp", "defense", "move_speed", "crit_chance", "cooldown_reduction", "lifesteal", "tenacity", "penetration", "hp_regen"]: hooks.append("stat." + stat + ".v1")
 return {"schema_version":1, "hero_id":"yanguizhou", "source_binding_id":"PINNED_REAL_INK_REVISION02_BASE_STAT_FIXTURE", "runtime_candidates":["Q1"], "supported_hooks":hooks}
func fresh(gold: int = 10000, numeric: String = NUMERIC) -> Dictionary:
 var sim = Sim.new(); root.add_child(sim)
 sim.hero.position = Vector3.ZERO; sim.ai_enabled = false; sim.auto_finish = false
 var bridge = Bridge.new()
 check(bridge.initialize_runtime_fixture(sim, _capabilities(), SHOP, FIXTURE, numeric, owner, "stat-run", true).accepted, "explicit real-source stat fixture initializes")
 # Only this test supplies money; the bridge has no funding API.
 bridge.model.state.gold = gold
 check(bridge.model.bind_floor(owner, sim, "stat-run").accepted, "one floor/run identity binds actual simulator")
 sim.set_progression(bridge)
 var bundle: Dictionary = {"sim":sim, "bridge":bridge}
 check(call_shop(bundle, "enter_room", {"next_room":"shop-1"}, true).accepted, "initial safe room commits")
 check(call_shop(bundle, "begin_visit", {"area":"shop-1/area"}, true).accepted, "same shop-area visit begins")
 return bundle
func call_shop(f: Dictionary, action: String, extra: Dictionary = {}, trusted: bool = false) -> Dictionary:
 serial += 1
 var args: Dictionary = f.bridge.model.commerce_token(); args.merge(extra, true)
 return f.bridge.shop_authority(owner, "stat-%d" % serial, action, args) if trusted else f.bridge.shop_command("stat-%d" % serial, action, args)
func buy(f: Dictionary, id: String) -> void:
 check(call_shop(f, "buy", {"item":id}).accepted, "buy actual " + id)
func combat(f: Dictionary, id: String = "combat-1") -> void:
 check(call_shop(f, "enter_room", {"next_room":id}, true).accepted, "commit before actual combat " + id)
 check(f.bridge.command("enter_level", {"combat_level_id":id}).ok, "ledger committed room enters")
 check(f.sim.begin_encounter(id, []).accepted, "actual Ink encounter begins")
 check(f.bridge.model.state.phase == "combat", "actual simulator uses same progression bridge")
func target(f: Dictionary, position: Vector3, hp: float = 10000.0, defense: float = 0.0) -> Dictionary:
 var enemy: Dictionary = f.sim.spawn_enemy("minion", position, hp)
 enemy.state = "chase"; enemy.defence = defense
 return enemy
func draw(f: Dictionary, end: Vector3 = Vector3(0,0,-8)) -> void:
 check(f.sim.request_ink_input("q_down").accepted, "real Q arm")
 check(f.sim.request_ink_input("left_down", Vector3.ZERO).accepted, "real Q anchor")
 check(f.sim.request_ink_input("motion", end).accepted, "real Q motion")
 check(f.sim.request_ink_input("left_up", end).accepted, "real Q physical-up interface releases")
func close(f: Dictionary) -> void: f.sim.free()
func _source_mapping() -> void:
 var numeric: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(NUMERIC))
 var result: Dictionary = Adapter.build(numeric)
 check(result.accepted and result.definitions.size() == 12, "all twelve original rows explicit")
 check(not result.definitions["base:B12"].supported and result.definitions["base:B12"].stats.is_empty(), "regen has no invented seconds conversion")
 for id in Adapter.MAPPING:
  var mapping: Array = Adapter.MAPPING[id]
  var key: String = id + ".stat." + str(mapping[0])
  var bad: Dictionary = numeric.duplicate(true); bad.parameters[key].unit = "invented"
  check(not Adapter.build(bad).accepted, "reject wrong source unit " + id)
  bad = numeric.duplicate(true); bad.parameters[key].value = NAN
  check(not Adapter.build(bad).accepted, "reject nonfinite source stat " + id)
 var edited = fresh(1000, EDITED)
 buy(edited, "base:B01")
 near(edited.sim.hero.ad(), 49.0, "edited current AD13 reaches real hero, not immutable prose12")
 near(edited.bridge.model.state.gold, 550, "stat edit does not change current price")
 close(edited)
func _projection_transactions() -> void:
 var rows: Array = [["B01","ad",48.0],["B02","ap",20.0],["B03","attack_speed",0.9775],["B04","crit_chance",0.1],["B05","cdr",0.08],["B06","max_hp",500.0],["B07","defence",24.0],["B08","move_speed",6.42],["B09","lifesteal",0.04],["B10","tenacity",0.15],["B11","penetration",10.0]]
 for row in rows:
  var f = fresh()
  var before: Dictionary = f.sim.hero.stats.duplicate(true)
  var immutable: Dictionary = f.sim.hero.base_stats.duplicate(true)
  var id: String = "base:" + str(row[0])
  buy(f, id)
  near(f.sim.hero.stats[row[1]], row[2], "actual projected " + id)
  for repeat in range(10): check(f.bridge.refresh_runtime().accepted, "repeat reproject " + id)
  near(f.sim.hero.stats[row[1]], row[2], "no derived drift " + id)
  check(f.sim.hero.base_stats == immutable, "immutable base preserved " + id)
  var uid: int = int(f.bridge.model.state.inventory[0].uid)
  check(call_shop(f, "sell", {"uid":uid}).accepted, "sale commits " + id)
  near(f.sim.hero.stats[row[1]], before[row[1]], "sale removes real stat " + id)
  check(call_shop(f, "undo").accepted, "same-visit sale reverse " + id)
  near(f.sim.hero.stats[row[1]], row[2], "sale undo restores real stat " + id)
  check(call_shop(f, "undo").accepted, "same-visit buy reverse " + id)
  near(f.sim.hero.stats[row[1]], before[row[1]], "buy undo restores derived baseline " + id)
  check(f.bridge.model.state.gold == 10000 and f.bridge.model.state.inventory.is_empty(), "exact gold/inventory inverse " + id)
  close(f)
 var f = fresh()
 buy(f,"base:B01"); buy(f,"base:B01")
 near(f.sim.hero.ad(),60.0,"duplicate plain attributes stack twice, no unique-stat mistake")
 check(f.bridge.model.equipment_effects().passives.is_empty() and f.bridge.model.equipment_effects().actives.is_empty(), "plain copies do not invent duplicate effect identities")
 var before: Dictionary = f.bridge.model.state.duplicate(true)
 var stats: Dictionary = f.sim.hero.stats.duplicate(true)
 for id in ["base:B12", "intermediate:I01", "final:A01", "potion:1", "elixir:01"]:
  var denied: Dictionary = call_shop(f,"craft" if id == "intermediate:I01" else "buy",{"item":id})
  check(not denied.accepted and str(denied.reason).begins_with("equipment_runtime_hold:"), "explicit runtime HOLD before debit " + id)
  check(f.bridge.model.state == before and f.sim.hero.stats == stats, "HOLD preserves ledger and actual stats " + id)
 var args: Dictionary = f.bridge.model.commerce_token(); args["item"] = "base:B02"
 var once: Dictionary = f.bridge.shop_command("same-click", "buy", args)
 before = f.bridge.model.state.duplicate(true); stats = f.sim.hero.stats.duplicate(true)
 var replay: Dictionary = f.bridge.shop_command("same-click", "buy", args)
 check(once.accepted and replay.accepted and not replay.changed and replay.events.is_empty(), "replay has no second effects or charge")
 check(f.bridge.model.state == before and f.sim.hero.stats == stats, "replay no stat accumulation")
 f.sim.transaction_active = true
 check(not call_shop(f,"sell",{"uid":f.bridge.model.state.inventory[0].uid}).accepted, "no mid-hit commerce refresh")
 check(f.bridge.model.state == before and f.sim.hero.stats == stats, "mid-hit rejection is atomic")
 f.sim.transaction_active = false
 close(f)
func _hit_consumers() -> void:
 var f = fresh(); buy(f,"base:B01"); combat(f)
 var enemy: Dictionary = target(f,Vector3(0,0,-3))
 check(f.sim.request_ink_input("left_down",Vector3(0,0,-9)).accepted,"real equipped BASIC manual release")
 f.sim.request_ink_input("left_up",Vector3(0,0,-9)); f.sim.step(0.2)
 near(10000.0-enemy.hp,48.0,"actual BASIC target HP consumes equipped AD")
 measurements["basic_AD12_damage"] = 10000.0-enemy.hp
 close(f)
 f = fresh(); buy(f,"base:B02"); check(f.sim.learn_ability("Q","Q1").ok,"Q1 learned from one real SP"); combat(f)
 enemy = target(f,Vector3(0,0,-3)); draw(f); f.sim.step(0.2)
 near(10000.0-enemy.hp,82.0,"actual Q1 target HP consumes20AP at85percent")
 measurements["q1_AP20_damage"] = 10000.0-enemy.hp
 close(f)
 f = fresh(); buy(f,"base:B03"); combat(f)
 check(f.sim.request_action("attack",Vector3(0,0,-9)).accepted,"AS equipped actual attack")
 near(f.sim.hero.cooldowns.attack,1.0/0.9775,"actual BASIC interval consumes base-fraction AS")
 close(f)
 f = fresh(); buy(f,"base:B05"); check(f.sim.learn_ability("Q","Q1").ok,"CDR fixture learns Q1"); combat(f); draw(f)
 near(f.sim.hero.cooldowns.q,6.44,"actual Q1 cooldown consumes8percent CDR")
 close(f)
 f = fresh(); buy(f,"base:B07"); combat(f)
 var hp: float = f.sim.hero.hp
 f.sim.damage_hero(100.0,Vector3.ZERO,0.0,false,true)
 near(hp-f.sim.hero.hp,10000.0/124.0,"actual incoming mitigation consumes14 defense")
 close(f)
 f = fresh(); buy(f,"base:B10"); combat(f)
 f.sim.damage_hero(0.0,Vector3.ZERO,2.0,false,true)
 near(f.sim.hero.stun_left,1.7,"actual control duration consumes15percent tenacity")
 close(f)
 f = fresh(); buy(f,"base:B08"); combat(f)
 f.sim.hero.move_intent = Vector3.RIGHT; f.sim.step(0.2)
 near(f.sim.hero.position.x,1.284,"actual locomotion consumes7percent move speed")
 close(f)
 f = fresh(); buy(f,"base:B11"); combat(f)
 enemy = target(f,Vector3(0,0,-3),10000.0,20.0)
 check(f.sim.request_action("attack",Vector3(0,0,-9)).accepted,"penetration equipped BASIC")
 f.sim.step(0.2)
 near(10000.0-enemy.hp,3600.0/110.0,"actual outgoing mitigation consumes10 penetration")
 close(f)
 # Birth-contact fixtures avoid regeneration ticks obscuring actual lifesteal HP.
 f = fresh(); buy(f,"base:B09"); combat(f); f.sim.hero.hp = 100.0
 enemy = target(f,Vector3(0,0,-0.1))
 check(f.sim.request_action("attack",Vector3(0,0,-9)).accepted,"lifesteal BASIC birth contact")
 near(10000.0-enemy.hp,36.0,"BASIC birth contact really damages target")
 near(f.sim.hero.hp,101.44,"BASIC full-efficiency4percent actual healing")
 close(f)
 f = fresh(); buy(f,"base:B09"); check(f.sim.learn_ability("Q","Q1").ok,"lifesteal Q1 learned"); combat(f); f.sim.hero.hp = 100.0
 enemy = target(f,Vector3(0,0,-0.1)); draw(f)
 near(10000.0-enemy.hp,65.0,"Q1 birth contact really damages target")
 near(f.sim.hero.hp,101.04,"existing Q1 AOE40percent efficiency, not BASIC100percent")
 near(f.sim._hero_lifesteal_factor({"direct":true,"area":false,"basic_attack":false}),0.0,"existing direct nonarea skill exclusion retained")
 near(f.sim._hero_lifesteal_factor({"direct":false,"area":true,"basic_attack":false}),0.25,"existing nondirect quarter efficiency retained")
 close(f)
 f = fresh(); buy(f,"base:B04"); combat(f)
 var probe = RandomNumberGenerator.new(); var chosen: int = 0
 for seed_value in range(1,1001):
  probe.seed = seed_value
  var candidate_state: int = probe.state
  var roll: float = probe.randf()
  if roll > 0.0 and roll < 0.1: chosen = candidate_state; break
 check(chosen != 0,"find deterministic sub10percent real RNG roll")
 f.sim.rng.state = chosen; enemy = target(f,Vector3(0,0,-0.1))
 check(f.sim.request_action("attack",Vector3(0,0,-9)).accepted,"crit actual BASIC")
 near(10000.0-enemy.hp,63.0,"10percent crit input changes actual eligible roll to1.75x BASIC")
 close(f)
func _hp_lifecycle() -> void:
 var f = fresh(); f.sim.hero.hp = 200.0
 buy(f,"base:B06")
 near(f.sim.hero.hp,200.0,"maxHP purchase does not heal missing HP")
 near(f.sim.hero.stats.max_hp,500.0,"maxHP source140 added")
 # Explicit setup represents previously healed HP, not a new recovery consumer.
 f.sim.hero.hp = 480.0
 var uid: int = int(f.bridge.model.state.inventory[0].uid)
 check(call_shop(f,"sell",{"uid":uid}).accepted,"high-HP item sale")
 near(f.sim.hero.hp,360.0,"sale clamps absolute HP down to smaller maximum")
 check(call_shop(f,"undo").accepted,"same-visit sale can be reversed")
 near(f.sim.hero.stats.max_hp,500.0,"undo restores maximum")
 near(f.sim.hero.hp,360.0,"undo does not restore HP lost to clamp")
 for repeat in range(3):
  check(call_shop(f,"sell",{"uid":uid}).accepted,"repeat maxHP sale")
  check(call_shop(f,"undo").accepted,"repeat maxHP sale undo")
  near(f.sim.hero.hp,360.0,"repeat loop cannot mint HP")
 close(f)
func _manual_aim_preserved() -> void:
 var f = fresh(); buy(f,"base:B01"); combat(f)
 var enemy: Dictionary = target(f,Vector3(0,0,-3))
 var rng: int = f.sim.rng.state
 check(not f.sim.request_action("attack").accepted,"equipment does not supply auto-target when manual aim absent")
 check(f.sim.rng.state == rng,"rejected aim consumes no crit RNG")
 check(f.sim.request_action("attack",Vector3(9,0,0)).accepted,"manual off-target aim accepted")
 f.sim.step(0.4)
 near(enemy.hp,10000.0,"equipped BASIC aimed away does not retarget enemy")
 near(f.sim.hero.facing.x,1.0,"manual direction unchanged")
 close(f)
func _rooms_and_rewards() -> void:
 var f = fresh(); buy(f,"base:B01")
 check(call_shop(f,"enter_room",{"next_room":"safe-event-room"},true).accepted,"ANY next noncombat room commits")
 check(call_shop(f,"begin_visit",{"area":"safe-event-room/shop"},true).accepted,"later safe visit")
 check(call_shop(f,"undo").reason == "undo_boundary","later shop cannot undo prior room purchase")
 near(f.sim.hero.ad(),48.0,"committed equipment stays in derived state")
 combat(f,"reward-room")
 check(not call_shop(f,"undo").accepted,"battle cannot undo equipment")
 var enemy: Dictionary = target(f,Vector3(0,0,-0.1),30.0)
 var gold: int = f.bridge.model.state.gold
 check(f.sim.request_action("attack",Vector3(0,0,-9)).accepted and enemy.dead,"actual equipped BASIC kills real minion")
 var kill: Dictionary = {}
 for event in f.sim.event_log:
  if event.kind == "kill" and event.target == enemy.actor_id: kill = event.duplicate(true)
 check(not kill.is_empty(),"actual source kill receipt exists")
 var awarded: Dictionary = f.bridge.model.observe_live_event(owner,f.sim,kill)
 check(awarded.accepted,"actual source kill admitted by existing reward authority")
 check(f.bridge.model.state.gold == gold+20,"actual minion reward paid once into same wallet")
 var again: Dictionary = f.bridge.model.observe_live_event(owner,f.sim,kill)
 check(again.accepted and not again.changed and f.bridge.model.state.gold == gold+20,"actual kill replay does not pay twice")
 near(f.sim.hero.ad(),48.0,"reward does not corrupt equipment stats")
 close(f)
func _body_dependencies() -> void:
 var f = fresh(950); buy(f,"base:B01")
 check(call_shop(f,"sell",{"uid":f.bridge.model.state.inventory[0].uid}).accepted,"real stat item sale funds spend")
 check(call_shop(f,"pay_body",{"purchase_id":"sale-funded-body"},true).accepted,"real irreversible body payment")
 check(f.bridge.model.state.gold == 5 and f.bridge.model.state.body.size() == 1,"body charged exactly once")
 var before: Dictionary = f.bridge.model.state.duplicate(true)
 check(call_shop(f,"undo").reason == "insufficient_gold","spent sale money blocks unsupported inverse")
 check(f.bridge.model.state == before,"failed inverse does not restore body/RNG/inventory")
 near(f.sim.hero.ad(),36.0,"failed sale inverse does not restore AD")
 close(f)
