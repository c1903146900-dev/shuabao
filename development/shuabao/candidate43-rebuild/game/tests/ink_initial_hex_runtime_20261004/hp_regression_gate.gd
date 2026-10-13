extends SceneTree
const Sim=preload("res://tests/ink_initial_hex_runtime_20261004/ink_initial_sim.gd")
const Bridge=preload("res://tests/ink_initial_hex_runtime_20261004/ink_initial_bridge.gd")
const SHOP="res://tests/ink_first_floor_flow_20261004/fixtures/provisional_shop.json"
const FIXTURE="res://tests/equipment_shop_transactions_20261004/fixtures/source_prices.json"
const NUMERIC="res://tests/equipment_editable_tables_20261004/outputs/equipment_tables/converted/equipment_numeric_config.json"
var owner=RefCounted.new()
var checks: int=0
var failures: Array=[]
var serial: int=0
var observed: Array=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
 checks+=1
 if not value:failures.append(label);push_error(label)
func near(a: float,b: float,label: String) -> void:check(is_finite(a) and absf(a-b)<0.00001,"%s %.6f / %.6f"%[label,a,b])
func caps() -> Dictionary:
 var hooks: Array=["stats.v1","equipment.task_completion.v1","hex.final_design.yanguizhou_h01.v1"]
 for stat in ["AD","AP","attack_speed","max_hp","defense","move_speed","crit_chance","cooldown_reduction","lifesteal","tenacity","penetration","hp_regen"]:hooks.append("stat."+stat+".v1")
 return {"schema_version":1,"hero_id":"yanguizhou","source_binding_id":"hp-clamp-real-source-fixture","runtime_candidates":["Q1"],"supported_hooks":hooks}
func fresh() -> Dictionary:
 var sim=Sim.new();root.add_child(sim)
 var bridge=Bridge.new()
 check(bridge.initialize_runtime_fixture(sim,caps(),SHOP,FIXTURE,NUMERIC,owner,"hp-run",true).accepted,"new health observer and same ledger bind")
 # Explicit finite fixture funding, absent from runtime bridge and UI host.
 bridge.model.state.gold=10000
 sim.set_progression(bridge)
 var f: Dictionary={"sim":sim,"b":bridge}
 check(call_shop(f,"enter_room",{"next_room":"safe-1"},true).accepted,"first safe room")
 check(call_shop(f,"begin_visit",{"area":"safe-1/shop"},true).accepted,"first visit")
 return f
func call_shop(f: Dictionary,operation: String,extra: Dictionary={},trusted: bool=false,id: String="") -> Dictionary:
 serial+=1
 var args: Dictionary=f.b.model.commerce_token();args.merge(extra,true)
 var command: String=id if not id.is_empty() else "hp-gate:%d"%serial
 return f.b.shop_authority(owner,command,operation,args) if trusted else f.b.shop_command(command,operation,args)
func prepared_sale() -> Dictionary:
 var f: Dictionary=fresh()
 check(call_shop(f,"buy",{"item":"base:B06"}).accepted,"buy source HP140")
 near(f.sim.hero.hp,360,"purchase never heals")
 near(f.sim.heal(120.0,false,{"source":"explicit_finite_heal_setup"}),120.0,"actual source heal creates480 of500 setup")
 var uid: int=int(f.b.model.state.inventory[0].uid)
 var sold: Dictionary=call_shop(f,"sell",{"uid":uid})
 check(sold.accepted,"sell HP item")
 near(f.sim.hero.hp,360,"actual sale clip")
 near(sold.health_projection.transaction_clamp,120,"receipt exact120 clip")
 var record: Dictionary=f.b.model.state.shop_visit.undo.back()
 near(record.hp_clamp.pre_hp,480,"journal preHP")
 near(record.hp_clamp.pre_max,500,"journal preMax")
 near(record.hp_clamp.post_hp,360,"journal postHP")
 near(record.hp_clamp.post_max,360,"journal postMax")
 f["uid"]=uid
 return f
func run() -> void:
 _exact_restore();_unchanged_refresh();_rebuy_not_heal();_health_dependencies();_consumption_dependencies();_body_dependency();_rooms();_stats_and_aim()
 var result: Dictionary={"suite":"ink_same_visit_exact_hp_clamp_undo","checks":checks,"failures":failures,"observed":observed,"scope":"real-source finite health projection and dependency fixtures; no UI/native/final-balance pass","ordinary_consumable_healing_implemented":false,"old_531_binding_unchanged":true}
 print("INK_HP_UNDO_REPORT ",JSON.stringify(result))
 var file=FileAccess.open("res://tests/ink_initial_hex_runtime_20261004/hp_result.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(result,"  "));file.close()
 quit(0 if failures.is_empty() else 1)
func _exact_restore() -> void:
 var f: Dictionary=prepared_sale()
 var before: Dictionary=f.b.model.state.duplicate(true)
 var args: Dictionary=f.b.model.commerce_token()
 var result: Dictionary=f.b.shop_command("undo-sale-once","undo",args)
 check(result.accepted,"same uninterrupted visit exact reverse admitted")
 near(f.sim.hero.hp,480,"same transaction restores own120 clip")
 near(f.sim.hero.stats.max_hp,500,"same transaction restores max")
 near(result.health_projection.undo_restored_own_clamp,120,"receipt restores120 only")
 check(not result.health_projection.healing_event_emitted,"restoration is not a healing proc")
 check(f.b.model.state.inventory[0].uid==f.uid,"same exact item instance restored")
 check(f.b.model.state.gold==before.gold-405,"same sale405 inverse only")
 var hp_revision: int=f.sim.equipment_health_revision
 var after: Dictionary=f.b.model.state.duplicate(true)
 var repeated: Dictionary=f.b.shop_command("undo-sale-once","undo",args)
 check(repeated.accepted and not repeated.changed and repeated.events.is_empty(),"undo replay no second side effect")
 check(f.b.model.state==after and f.sim.hero.hp==480 and f.sim.equipment_health_revision==hp_revision,"replay no HP/gold/item/source event increment")
 observed.append({"case":"sale_exact_undo","before_hp":480,"sold_hp":360,"undo_hp":f.sim.hero.hp,"undo_max":f.sim.hero.stats.max_hp})
 f.sim.free()
func _unchanged_refresh() -> void:
 var f: Dictionary=prepared_sale()
 var version: int=f.sim.equipment_health_revision
 var state: Dictionary=f.b.model.state.duplicate(true)
 for repetition in range(15):check(f.b.refresh_runtime().accepted,"read-only repeated projection accepted")
 check(f.sim.equipment_health_revision==version and f.b.model.state==state,"no actual HP change means no dependency seal/revision")
 near(f.sim.heal(10.0,false,{"source":"full_health_nonconsumable_noop"}),0,"full-health nonconsumable heal makes no HP change")
 check(call_shop(f,"undo").accepted and f.sim.hero.hp==480,"zero-delta ordinary refresh/heal does not falsely seal")
 f.sim.free()
func _rebuy_not_heal() -> void:
 var f: Dictionary=prepared_sale()
 check(call_shop(f,"buy",{"item":"base:B06"}).accepted,"new purchase after sale accepted")
 near(f.sim.hero.hp,360,"reacquiring is not undo and cannot heal120")
 near(f.sim.hero.stats.max_hp,500,"reacquiring raises maximum only")
 check(call_shop(f,"undo").accepted,"undo new purchase")
 near(f.sim.hero.hp,360,"undo new purchase cannot claim old sale clip")
 check(call_shop(f,"undo").accepted,"then exact original sale inverse")
 near(f.sim.hero.hp,480,"original sale clip restored once only")
 for repeat in range(3):
  check(call_shop(f,"sell",{"uid":f.uid}).accepted,"repeat actual sale")
  check(call_shop(f,"undo").accepted,"repeat matching inverse")
  near(f.sim.hero.hp,480,"repeat inverse is neutral, no HP above original480")
 f.sim.free()
func _health_dependencies() -> void:
 var f: Dictionary=prepared_sale()
 check(call_shop(f,"buy",{"item":"base:B06"}).accepted,"reopen health capacity without heal")
 near(f.sim.heal(10.0,false,{"source":"actual_intervening_heal"}),10,"actual source healing10")
 check(call_shop(f,"buy",{"item":"base:B01"}).accepted,"unrelated AD item after health event")
 check(call_shop(f,"undo").accepted,"unrelated AD remains reversible")
 var before: Dictionary=f.b.model.state.duplicate(true)
 var denied: Dictionary=call_shop(f,"undo")
 check(not denied.accepted and denied.reason=="hp_dependency_changed","accepted actual healing seals related HP transactions")
 check(f.b.model.state==before and f.sim.hero.hp==370,"denial cannot restore old480 or undo actual heal")
 f.sim.free()
 f=prepared_sale()
 # Deliberate same-process unreported HP writer fault injection, not normal damage.
 # Real combat damage is separately exercised after the actual room commit below.
 f.sim.hero.hp-=5.0
 var rejected: Dictionary=call_shop(f,"undo")
 check(not rejected.accepted,"unreported actual HP change fails closed")
 near(f.sim.hero.hp,355,"unreported loss is never reverted by stale sale inverse")
 check(call_shop(f,"undo").reason=="hp_dependency_changed","fresh token reports sealed HP dependency")
 f.sim.free()
func _consumption_dependencies() -> void:
 var f: Dictionary=prepared_sale()
 # Existing economics consumer seam only: explicit carried-potion setup plus
 # verified external consumer receipt. No actual potion healing is claimed.
 var m: RefCounted=f.b.model
 var uid: int=m.state.next_item
 m.state.next_item+=1
 m.state.inventory.append({"uid":uid,"id":"potion:1","count":1,"invested":0,"lineage":[]})
 var consumed: Dictionary=call_shop(f,"consume_recovery",{"uid":uid,"effect_id":"full-hp-effect","consumer_preflight_passed":true},true)
 check(consumed.accepted,"accepted irreversible consumer receipt at actual full HP")
 near(f.sim.hero.hp,360,"consumer intent does not invent potion healing")
 check(call_shop(f,"undo").reason=="hp_consumption_dependency","zero-heal consumption still seals HP-dependent sale")
 check(m.state.shop_visit.effect_receipts.has("full-hp-effect"),"consumption receipt survives rejected inverse")
 f.sim.free()
func _body_dependency() -> void:
 var f: Dictionary=prepared_sale()
 var paid: Dictionary=call_shop(f,"pay_body",{"purchase_id":"irreversible-body"},true)
 check(paid.accepted,"actual existing900 body payment")
 var gold: int=f.b.model.state.gold
 check(call_shop(f,"undo").reason=="hp_consumption_dependency","accepted body spend seals HP dependencies even with no HP delta")
 check(f.b.model.state.gold==gold and f.b.model.state.body.size()==1,"HP inverse never refunds body")
 near(f.sim.hero.hp,360,"body payment did not heal")
 f.sim.free()
func _rooms() -> void:
 var f: Dictionary=prepared_sale()
 check(call_shop(f,"enter_room",{"next_room":"next-safe"},true).accepted,"ANY next room commits HP journal too")
 check(call_shop(f,"begin_visit",{"area":"next-safe/shop"},true).accepted,"later visit")
 check(call_shop(f,"undo").reason=="undo_boundary","later safe room cannot restore old clip")
 near(f.sim.hero.hp,360,"cross-room health remains360")
 check(call_shop(f,"enter_room",{"next_room":"combat-real"},true).accepted,"actual combat room commit")
 check(f.b.command("enter_level",{"combat_level_id":"combat-real"}).ok,"actual level boundary")
 check(f.sim.begin_encounter("combat-real",[]).accepted,"actual source combat lifecycle")
 f.sim.auto_finish=false
 f.sim.damage_hero(20.0,Vector3.ZERO,0.0,true,true)
 near(f.sim.hero.hp,340,"actual source true damage20 persists")
 check(not call_shop(f,"undo").accepted,"combat cannot use old health inverse")
 near(f.sim.hero.hp,340,"rejected combat undo never reverses damage")
 f.sim.free()
func _stats_and_aim() -> void:
 var f: Dictionary=fresh()
 check(call_shop(f,"buy",{"item":"base:B01"}).accepted,"AD source item with HP observer")
 near(f.sim.hero.ad(),48,"AD projection unchanged")
 check(call_shop(f,"enter_room",{"next_room":"basic-real"},true).accepted,"basic room commit")
 check(f.b.command("enter_level",{"combat_level_id":"basic-real"}).ok,"basic level")
 check(f.sim.begin_encounter("basic-real",[]).accepted,"basic actual source")
 f.sim.auto_finish=false;f.sim.ai_enabled=false;f.sim.hero.position=Vector3.ZERO
 var enemy: Dictionary=f.sim.spawn_enemy("minion",Vector3(0,0,-0.1),1000.0);enemy.state="chase";enemy.defence=0.0
 check(not f.sim.request_action("attack").accepted,"health adapter does not add auto aim")
 check(f.sim.request_action("attack",Vector3(0,0,-9)).accepted,"manual BASIC still admitted")
 near(1000.0-enemy.hp,48,"actual source BASIC still deals48")
 f.sim.free()
