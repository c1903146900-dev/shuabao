extends SceneTree
## Real engine finite fixture; explicit test funding is confined to fresh().
## Original recipes, ledger commands, health observer, and real combat sinks.
const Sim=preload("res://tests/ink_intermediate_stats_20261004/ink_intermediate_sim.gd")
const Bridge=preload("res://tests/ink_intermediate_stats_20261004/ink_intermediate_bridge.gd")
const Adapter=preload("res://tests/ink_intermediate_stats_20261004/intermediate_stat_adapter.gd")
const Binding=preload("res://tests/ink_intermediate_stats_20261004/live_binding.gd")
const Tuning=preload("res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_tuning.gd")
const SHOP="res://tests/ink_first_floor_flow_20261004/fixtures/provisional_shop.json"
const FIXTURE="res://tests/equipment_shop_transactions_20261004/fixtures/source_prices.json"
const NUMERIC="res://tests/equipment_editable_tables_20261004/outputs/equipment_tables/converted/equipment_numeric_config.json"
const MAP="res://tests/ink_intermediate_stats_20261004/source_map.json"
const SINKS={"AD":"ad","AP":"ap","attack_speed":"attack_speed","crit_chance":"crit_chance","cooldown_reduction":"cdr","max_hp":"max_hp","defense":"defence","move_speed":"move_speed","lifesteal":"lifesteal","tenacity":"tenacity","penetration":"penetration"}
var rows: Dictionary={}
var checks: int=0
var failures: Array=[]
var serial: int=0
var completed: Array=[]
var evidence: Array=[]
func _initialize()->void:call_deferred("run")
func check(ok: bool,label: String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func near(a: float,b: float,label: String)->void:check(is_finite(a) and absf(a-b)<.00001,"%s: %.9f expected %.9f"%[label,a,b])
func shop(f: Dictionary,operation: String,args: Dictionary={},trusted: bool=false)->Dictionary:
 serial+=1
 var token: Dictionary=f.b.model.commerce_token();token.merge(args,true)
 return f.b.shop_authority(f.owner,"intermediate:%d"%serial,operation,token) if trusted else f.b.shop_command("intermediate:%d"%serial,operation,token)
func fresh(hex_id: String="",gold: int=10000)->Dictionary:
 var sim=Sim.new();root.add_child(sim)
 var admitted: Dictionary=Binding.read_capabilities(sim,true)
 check(admitted.accepted,"exact final candidate runtime digest admission")
 var b=Bridge.new();var owner=RefCounted.new()
 var initialized: Dictionary=b.initialize_runtime_fixture(sim,admitted.get("capabilities",{}),SHOP,FIXTURE,NUMERIC,owner,"intermediate-finite",true)
 check(initialized.accepted,"new exact runtime composition binds")
 check(b.model.state.gold==0 and b.model.state.points==1 and b.model.state.level==1 and b.model.state.inventory.is_empty() and b.model.state.selected_hex.is_empty(),"ordinary defaults unchanged before explicit test funding")
 var f: Dictionary={"sim":sim,"b":b,"owner":owner}
 sim.set_progression(b);sim.hero.position=Vector3.ZERO;sim.ai_enabled=false;sim.auto_finish=false
 if not hex_id.is_empty():
  check(b.command("hex_open",{"milestone":1}).ok,"real initial choice before equipment")
  var picked: bool=false
  for slot in [-1,0,1,2,3]:
   if slot>=0:check(b.command("hex_refresh",{"milestone":1,"slot":slot}).ok,"real single-use slot refresh")
   var offer: Array=b.model.state.offers["1"].slots
   if hex_id in offer:
    check(b.command("hex_select",{"milestone":1,"slot":offer.find(hex_id)}).ok,"real chosen Hex "+hex_id);picked=true;break
  check(picked and b.model.state.selected_hex==[hex_id],"selected Hex is never fabricated")
  check(b.model.state.gold==0 and b.model.state.points==1,"Hex selection grants no gold or SP")
 # Explicit finite-fixture funds, not normal earnings or a bridge capability.
 b.model.state.gold=gold
 check(b.refresh_runtime().accepted,"derive test-funding G30 from same ledger")
 check(shop(f,"enter_room",{"next_room":"safe-1"},true).accepted,"first safe room")
 check(shop(f,"begin_visit",{"area":"safe-1/shop"},true).accepted,"same visit starts")
 return f
func buy(f: Dictionary,id: String)->Dictionary:
 var result: Dictionary=shop(f,"buy",{"item":id})
 check(result.accepted,"real buy "+id+": "+str(result.get("reason","")))
 return result
func components(f: Dictionary,id: String)->void:
 for part in rows[id].components:buy(f,part)
func same_stats(f: Dictionary,stats: Dictionary,label: String)->bool:
 var before_failures: int=failures.size()
 var effects: Dictionary=f.b.model.equipment_effects()
 check(effects.holds.is_empty() and effects.passives.is_empty() and effects.actives.is_empty(),label+" only supported held stats, no invented mechanisms")
 check(effects.stats.size()==stats.size(),label+" stat-key cardinality excludes removed components")
 var base: Dictionary=Tuning.hero_stats()
 for key in SINKS:
  var addition: float=float(stats.get(key,0.0))
  near(float(effects.stats.get(key,0.0)),addition,label+" exact held contribution "+key)
  var value: float=float(base[SINKS[key]])
  value=value*(1.0+addition) if key in ["attack_speed","move_speed"] else value+addition
  if key=="attack_speed":value=minf(value,2.5)
  if key=="cooldown_reduction":value=minf(value,.65)
  if key=="tenacity":value=minf(value,1.0)
  near(float(f.sim.hero.stats[SINKS[key]]),value,label+" actual actor sink "+key)
 return failures.size()==before_failures
func sum_components(id: String)->Dictionary:
 var stats: Dictionary={}
 for part in rows[id].components:
  for key in rows[part].expected_stats:stats[key]=float(stats.get(key,0))+float(rows[part].expected_stats[key])
 return stats
func run()->void:
 var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(MAP))
 for row in source.rows:rows[row.id]=row
 test_mapping_and_holds()
 for id in rows:
  if rows[id].tier=="intermediate" and rows[id].supported:test_recipe(id)
 test_partial_and_full_slots();test_hp_inverse();test_dependencies();test_room_commit();test_g24_craft();test_g30_craft();test_combat_sinks()
 var required: Array=["mapping","partial_full","hp_inverse","dependencies","room_commit","G24","G30","combat_sinks"]
 for id in rows:
  if rows[id].tier=="intermediate" and rows[id].supported:required.append(id)
 for id in required:check(id in completed,"case reached final assertion: "+id)
 var result: Dictionary={"suite":"intermediate17_actual_ledger_craft_stats","passed":failures.is_empty(),"checks":checks,"failures":failures,"completed":completed,"evidence":evidence,"source_binding_id":FileAccess.get_sha256("res://tests/ink_intermediate_stats_20261004/source_binding.json"),"explicit_test_funding":true,"engine_invoked_by_author":false,"scope":"finite real source fixture; no native UI, balance, full floor, or production acceptance"}
 var output=FileAccess.open("res://tests/ink_intermediate_stats_20261004/intermediate_result.json",FileAccess.WRITE)
 output.store_string(JSON.stringify(result,"  "));output.close()
 print("INK_INTERMEDIATE_REPORT ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
func test_mapping_and_holds()->void:
 var numeric: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(NUMERIC))
 var built: Dictionary=Adapter.build(numeric)
 check(built.accepted and built.definitions.size()==30,"12 base and18 intermediate explicit source rows")
 var supported: int=0
 for id in built.definitions:
  var definition: Dictionary=built.definitions[id]
  if definition.supported:supported+=1
  check(definition.supported==rows[id].supported,"exact supported flag "+id)
  check(definition.stats==rows[id].expected_stats,"exact numeric formal source mapping "+id)
 check(supported==28,"exact11base+17intermediate support")
 for id in Adapter.INTERMEDIATE_MAPPING:
  for field in Adapter.INTERMEDIATE_MAPPING[id]:
   var key: String=id+".stat."+str(field[0])
   for bad_value in [-1.0,"28",null,NAN,INF,-INF]:
    var bad: Dictionary=numeric.duplicate(true);bad.parameters[key].value=bad_value
    check(not Adapter.build(bad).accepted,"reject invalid numeric "+key)
   for bad_node in [null,28,"invalid"]:
    var malformed: Dictionary=numeric.duplicate(true);malformed.parameters[key]=bad_node
    check(not Adapter.build(malformed).accepted,"malformed intermediate parameter node fails closed "+key)
   var wrong: Dictionary=numeric.duplicate(true);wrong.parameters[key].unit="invented_seconds"
   check(not Adapter.build(wrong).accepted,"unit mismatch cannot silently pass "+key)
 var malformed_base: Dictionary=numeric.duplicate(true);malformed_base.parameters["base:B01.stat.AD"]=null
 check(not Adapter.build(malformed_base).accepted,"malformed inherited base parameter denied before typed access")
 var edited: Dictionary=numeric.duplicate(true);edited.parameters["intermediate:I01.stat.AD"].value=29
 var changed: Dictionary=Adapter.build(edited)
 near(changed.definitions["intermediate:I01"].stats.AD,29,"adapter takes editable value, not stale source prose28")
 check(changed.definitions["base:B01"].stats.AD==12,"editing intermediate does not edit components")
 var f: Dictionary=fresh()
 for id in f.b.model.commerce_definitions.items:
  var status: Dictionary=f.b.model.equipment_runtime_status(id)
  check(status.supported==bool(rows.get(id,{}).get("supported",false)),"catalog-wide exact admission "+id)
  if status.supported:continue
  var before: Dictionary=f.b.model.state.duplicate(true)
  check(not f.b.model.commerce_quote(id).accepted,"unsupported quote "+id)
  for operation in ["buy","craft"]:check(not shop(f,operation,{"item":id}).accepted,"unsupported direct command "+id)
  check(f.b.model.state==before,"blocked inert item never debits or changes ledger "+id)
 check(f.b.model.equipment_runtime_status("intermediate:I12").reason=="regen_time_unit_unresolved","whole I12 withheld, including known HP")
 check(not f.b.model.restore({}),"no generic state restore introduced")
 f.sim.free();completed.append("mapping")
func test_recipe(id: String)->void:
 var f: Dictionary=fresh();components(f,id)
 check(same_stats(f,sum_components(id),id+" held components"),"nested stat helper completed all sink checks")
 var before: Dictionary=f.b.model.state.duplicate(true)
 var before_hp: float=f.sim.hero.hp
 var quote: Dictionary=f.b.model.commerce_quote(id)
 check(quote.accepted and quote.charge==rows[id].combine_fee,id+" quote credits exact components")
 var result: Dictionary=shop(f,"craft",{"item":id})
 check(result.accepted and result.charge==rows[id].combine_fee and result.credit==rows[id].price-rows[id].combine_fee,id+" actual craft fee/credit")
 check(f.b.model.state.inventory.size()==1 and f.b.model.state.inventory[0].id==id,id+" components removed from sole inventory")
 var item: Dictionary=f.b.model.state.inventory[0].duplicate(true)
 check(item.count==1 and item.invested==rows[id].price,id+" full invested value remains attributable")
 for component in before.inventory:check(component.uid!=item.uid,id+" new UID replaces component UID")
 check(item.lineage.size()==before.inventory.size()+1,id+" original component transaction lineage retained once")
 check(f.b.model.state.gold==before.gold-rows[id].combine_fee,id+" one wallet charged once")
 check(same_stats(f,rows[id].expected_stats,id+" crafted"),"nested stat helper completed all sink checks")
 near(f.sim.hero.hp,before_hp,id+" craft does not heal")
 var journal: Array=f.b.model.state.shop_visit.undo.duplicate(true)
 var epoch: int=int(f.b.model.state.shop_visit.epoch)
 check(shop(f,"close_ui").accepted and shop(f,"open_ui").accepted,id+" close/reopen same visit")
 check(f.b.model.state.shop_visit.undo==journal and f.b.model.state.shop_visit.epoch==epoch,id+" UI toggle does not commit history")
 serial+=1;var command: String="recipe-undo:%d"%serial
 var token: Dictionary=f.b.model.commerce_token()
 var inverse: Dictionary=f.b.shop_command(command,"undo",token)
 check(inverse.accepted,id+" actual inverse accepted")
 check(f.b.model.state.inventory==before.inventory and f.b.model.state.gold==before.gold,id+" inverse restores exact component UIDs/order/investment/lineage and fee")
 check(same_stats(f,sum_components(id),id+" inverse"),"nested stat helper completed all sink checks")
 check(f.b.model.state.skills==before.skills and f.b.model.state.points==before.points and f.b.model.state.rng==before.rng,id+" inverse does not restore unrelated progression")
 var after: Dictionary=f.b.model.state.duplicate(true)
 var replay: Dictionary=f.b.shop_command(command,"undo",token)
 check(replay.accepted and not replay.changed and replay.events.is_empty() and f.b.model.state==after,id+" replay cannot duplicate components or gold")
 check(shop(f,"craft",{"item":id}).accepted,id+" recraft")
 item=f.b.model.state.inventory[0].duplicate(true)
 var gold: int=int(f.b.model.state.gold)
 var sold: Dictionary=shop(f,"sell",{"uid":item.uid})
 check(sold.accepted and sold.refund==int(floor(float(rows[id].price)*.9)),id+" source sale refund")
 check(same_stats(f,{},id+" sold"),"nested stat helper completed all sink checks")
 check(shop(f,"undo").accepted,id+" reverse sale")
 check(f.b.model.state.inventory==[item] and f.b.model.state.gold==gold,id+" sale undo same exact crafted instance and gold")
 check(same_stats(f,rows[id].expected_stats,id+" restored sale"),"nested stat helper completed all sink checks")
 evidence.append({"id":id,"components":before.inventory,"crafted":item,"price":rows[id].price,"craft_fee":result.charge,"actual_stats":f.sim.hero.stats.duplicate(true)})
 f.sim.free();completed.append(id)
func test_partial_and_full_slots()->void:
 var f: Dictionary=fresh();buy(f,"base:B01")
 var partial: Dictionary=shop(f,"craft",{"item":"intermediate:I01"})
 check(partial.accepted and partial.credit==450 and partial.charge==650,"partial recipe buys only missing component plus source fee")
 check(same_stats(f,{"AD":28.0},"partial recipe"),"nested stat helper completed all sink checks")
 check(shop(f,"undo").accepted and f.b.model.state.inventory.size()==1 and f.b.model.state.inventory[0].id=="base:B01","partial inverse restores only actually owned component")
 f.sim.free();f=fresh()
 for id in ["base:B03","base:B04","base:B08","base:B01","base:B01","base:B01"]:buy(f,id)
 var before: Array=f.b.model.state.inventory.duplicate(true)
 check(before.size()==6,"one actual six-slot inventory full")
 var rejected_state: Dictionary=f.b.model.state.duplicate(true)
 check(not shop(f,"buy",{"item":"base:B02"}).accepted and f.b.model.state==rejected_state,"seventh unrelated item refused atomically")
 check(shop(f,"craft",{"item":"intermediate:I03"}).accepted,"full inventory craft consumes three slots before capacity check")
 check(f.b.model.state.inventory.size()==4,"craft creates exactly one slot")
 check(shop(f,"undo").accepted and f.b.model.state.inventory==before,"six-slot craft inverse restores exact order")
 f.sim.free();completed.append("partial_full")
func test_hp_inverse()->void:
 var f: Dictionary=fresh();components(f,"intermediate:I07");check(shop(f,"craft",{"item":"intermediate:I07"}).accepted,"HP intermediate actual craft")
 near(f.sim.hero.stats.max_hp,580,"I07 source220 reaches real max")
 near(f.sim.hero.hp,360,"craft capacity not healing")
 near(f.sim.heal(200,false,{"source":"finite_actual_heal_setup"}),200,"actual heal establishes560of580")
 var uid: int=int(f.b.model.state.inventory[0].uid)
 var sold: Dictionary=shop(f,"sell",{"uid":uid})
 near(f.sim.hero.hp,360,"intermediate sale clamps560to360")
 near(sold.health_projection.transaction_clamp,200,"only exact200 belongs to sale")
 var reversed: Dictionary=shop(f,"undo")
 check(reversed.accepted and not reversed.health_projection.healing_event_emitted,"same valid sale inverse emits no heal proc")
 near(f.sim.hero.hp,560,"intermediate sale inverse restores own200")
 for repeat in range(3):
  check(shop(f,"sell",{"uid":uid}).accepted,"repeat source sale")
  check(shop(f,"undo").accepted,"repeat same inverse")
  near(f.sim.hero.hp,560,"repeated inverse cannot mint HP")
 check(shop(f,"sell",{"uid":uid}).accepted,"new sale")
 buy(f,"intermediate:I07")
 near(f.sim.hero.hp,360,"new intermediate acquisition is not inverse healing")
 f.sim.free();completed.append("hp_inverse")
func test_dependencies()->void:
 var f: Dictionary=fresh();components(f,"intermediate:I07");check(shop(f,"craft",{"item":"intermediate:I07"}).accepted,"health-dependent craft")
 near(f.sim.heal(10,false,{"source":"actual_dependency"}),10,"actual heal uses new intermediate capacity")
 buy(f,"intermediate:I01")
 check(shop(f,"undo").accepted,"unrelated nonhealth intermediate stays reversible")
 var before: Dictionary=f.b.model.state.duplicate(true)
 check(not shop(f,"undo").accepted and f.b.model.state==before,"actual heal seals only HP-related component/craft transactions")
 near(f.sim.hero.hp,370,"rejected inverse never rewinds actual health")
 f.sim.free();f=fresh();components(f,"intermediate:I01");check(shop(f,"craft",{"item":"intermediate:I01"}).accepted,"lineage craft")
 buy(f,"base:B02")
 var paid: Dictionary=shop(f,"pay_body",{"purchase_id":"intermediate-never-undo-body"},true)
 check(paid.accepted,"real irreversible body purchase")
 var body: Array=f.b.model.state.body.duplicate(true)
 var gold: int=int(f.b.model.state.gold)
 # Explicit imported external reward receipt exercises the preserved generic
 # dependency seam. No intermediate item has a task; no reward is invented.
 var receipt: Dictionary=shop(f,"task_effect",{"equipment_id":"intermediate:I01","event_id":"finite-external-receipt","stage":"finite","progress":1,"reward_key":"verified-external-only"},true)
 check(receipt.accepted,"trusted receipt seals crafted item lineage only")
 var task_ledger: Dictionary=f.b.model.state.shop_visit.taskLedger.duplicate(true)
 check(shop(f,"undo").accepted,"unrelated AP purchase remains reversible after dependency receipt/body")
 check(f.b.model.state.gold==gold+450 and f.b.model.state.body==body,"inverse refunds AP only; body remains paid")
 check(f.b.model.state.points==1 and f.b.model.state.shop_visit.taskLedger==task_ledger,"no SP grant or reward duplication")
 before=f.b.model.state.duplicate(true)
 check(not shop(f,"undo").accepted and f.b.model.state==before,"consumed reward dependency cannot undo crafted item or component lineage")
 f.sim.free();completed.append("dependencies")
func combat(f: Dictionary,room: String="combat-1")->void:
 check(shop(f,"enter_room",{"next_room":room},true).accepted,"actual room commits all existing journal")
 check(f.b.command("enter_level",{"combat_level_id":room}).ok,"same ledger level")
 check(f.sim.begin_encounter(room,[]).accepted,"real source combat begins")
func test_room_commit()->void:
 var f: Dictionary=fresh();buy(f,"intermediate:I13")
 check(shop(f,"enter_room",{"next_room":"another-safe"},true).accepted,"ANY noncombat next room commits")
 check(shop(f,"begin_visit",{"area":"another-safe/shop"},true).accepted,"later safe visit")
 check(shop(f,"undo").reason=="undo_boundary","later visit cannot reverse previous intermediate")
 combat(f)
 var hp: float=f.sim.hero.hp
 f.sim.damage_hero(20,Vector3.ZERO,0,true,true)
 near(hp-f.sim.hero.hp,20,"actual combat source damage remains")
 check(not shop(f,"undo").accepted,"combat prohibits inverse")
 near(f.sim.hero.hp,hp-20,"failed inverse never restores actual damage")
 f.sim.free();completed.append("room_commit")
func test_g24_craft()->void:
 var f: Dictionary=fresh("common_g24")
 for id in ["base:B03","base:B04","base:B08","base:B01","base:B01","base:B01"]:buy(f,id)
 near(f.sim.hero.stats.max_hp,360,"G24 six occupied slots zero HP bonus")
 near(f.sim.hero.stats.common_damage_multiplier,1,"G24 six occupied zero damage bonus")
 var before: Dictionary=f.b.model.state.duplicate(true)
 check(shop(f,"craft",{"item":"intermediate:I03"}).accepted,"G24 actual full-slot craft")
 near(f.sim.hero.stats.max_hp,360*1.12,"G24 two empty slots after craft from same inventory")
 near(f.sim.hero.stats.common_damage_multiplier,1.16,"G24 two empty slots after craft damage multiplier")
 near(f.sim.hero.hp,360,"G24 craft projection is not heal")
 check(shop(f,"undo").accepted,"G24 inverse accepted")
 check(f.b.model.state.inventory==before.inventory and f.b.model.state.gold==before.gold,"G24 same component inverse and wallet")
 near(f.sim.hero.stats.max_hp,360,"G24 inverse removes exact slot-derived HP")
 near(f.sim.hero.stats.common_damage_multiplier,1,"G24 inverse removes slot-derived damage")
 evidence.append({"case":"G24","craft_slots":4,"inverse_slots":f.b.model.state.inventory.size(),"inverse_max_hp":f.sim.hero.stats.max_hp})
 f.sim.free();completed.append("G24")
func test_g30_craft()->void:
 var f: Dictionary=fresh("common_g30",1500);components(f,"intermediate:I01")
 check(f.b.model.state.gold==600,"G30 test funding spent once on two source components")
 near(f.sim.hero.stats.max_hp,395,"G30 remaining600 gives source35HP")
 near(f.sim.heal(35,false,{"source":"finite_g30_actual_heal"}),35,"actual healing establishes395of395")
 var before: Dictionary=f.b.model.state.duplicate(true)
 var result: Dictionary=shop(f,"craft",{"item":"intermediate:I01"})
 check(result.accepted and f.b.model.state.gold==400,"G30200 combine fee crosses500 threshold")
 near(f.sim.hero.stats.max_hp,360,"G30 actual craft debit removes35HP")
 near(f.sim.hero.stats.defence,Tuning.hero_stats().defence,"G30 actual craft debit removes4defense")
 near(result.health_projection.transaction_clamp,35,"G30 craft owns actual35HP clamp")
 var reversed: Dictionary=shop(f,"undo")
 check(reversed.accepted and f.b.model.state.inventory==before.inventory and f.b.model.state.gold==600,"G30 inverse returns exact fee and component instances")
 near(f.sim.hero.stats.max_hp,395,"G30 inverse source35 max")
 near(f.sim.hero.hp,395,"G30 inverse restores only craft clamp35")
 near(reversed.health_projection.undo_restored_own_clamp,35,"G30 receipt35 only")
 near(f.sim.hero.stats.defence,Tuning.hero_stats().defence+4,"G30 inverse real defense")
 evidence.append({"case":"G30","craft_gold":400,"undo_gold":f.b.model.state.gold,"undo_hp":f.sim.hero.hp,"undo_max_hp":f.sim.hero.stats.max_hp})
 f.sim.free();completed.append("G30")
func target(f: Dictionary,defense: float=0)->Dictionary:
 var e: Dictionary=f.sim.spawn_enemy("minion",Vector3(0,0,-.1),10000.0)
 e.state="chase";e.defence=defense;e.speed=0
 return e
func basic(f: Dictionary,e: Dictionary)->float:
 var before: float=e.hp
 check(f.sim.request_action("attack",Vector3(0,0,-9)).accepted,"real manual BASIC")
 return before-float(e.hp)
func draw(f: Dictionary)->void:
 check(f.sim.request_ink_input("q_down").accepted,"Q key arm")
 check(f.sim.request_ink_input("left_down",Vector3.ZERO).accepted,"actual first point")
 check(f.sim.request_ink_input("motion",Vector3(0,0,-8)).accepted,"actual manual drag")
 check(f.sim.request_ink_input("left_up",Vector3(0,0,-8)).accepted,"actual release casts Q1")
func test_combat_sinks()->void:
 var f: Dictionary=fresh();components(f,"intermediate:I01");check(shop(f,"craft",{"item":"intermediate:I01"}).accepted,"AD sink uses crafted item");combat(f)
 var e: Dictionary=target(f)
 check(not f.sim.request_action("attack").accepted,"crafted gear does not invent aim")
 near(basic(f,e),64,"actual BASIC consumes crafted28AD once, not extra24components")
 f.sim.free();f=fresh();components(f,"intermediate:I05");check(shop(f,"craft",{"item":"intermediate:I05"}).accepted,"AP/CDR real crafted item")
 check(f.sim.learn_ability("Q","Q1").ok,"spend actual initial1SP for Q1");combat(f);e=target(f);draw(f)
 near(10000-e.hp,65+32*.85,"actual Q1 consumes crafted32AP once")
 near(f.sim.hero.cooldowns.q,7*.9,"actual Q1 consumes crafted10percent CDR")
 f.sim.free();f=fresh();buy(f,"intermediate:I10");combat(f);f.sim.hero.hp=100;e=target(f)
 near(basic(f,e),36,"lifesteal target genuinely damaged")
 near(f.sim.hero.hp,100+36*.06,"I10 actual6percent BASIC healing")
 near(f.sim.hero.cooldowns.attack,1/(.85*1.22),"I10 actual22percent attack interval")
 f.sim.free();f=fresh();buy(f,"intermediate:I15");combat(f)
 var hp: float=f.sim.hero.hp;f.sim.damage_hero(100,Vector3.ZERO,2,false,true)
 near(hp-f.sim.hero.hp,10000/128.0,"I15 actual defense18 mitigation")
 near(f.sim.hero.stun_left,2*.78,"I15 actual22percent tenacity")
 f.sim.free();f=fresh();buy(f,"intermediate:I16");combat(f)
 f.sim.hero.move_intent=Vector3.RIGHT;f.sim.step(.2)
 near(f.sim.hero.position.x,6*1.09*.2,"I16 actual9percent locomotion")
 f.sim.free();f=fresh();buy(f,"intermediate:I04");combat(f);e=target(f,20)
 near(basic(f,e),56*100/106.0,"I04 actual20AD/14penetration outgoing damage")
 f.sim.free();f=fresh();buy(f,"intermediate:I11");combat(f)
 var rng=RandomNumberGenerator.new();var chosen: int=0
 for seed_value in range(1,1001):
  rng.seed=seed_value
  var candidate: int=rng.state;var roll: float=rng.randf()
  if roll>0 and roll<.15:chosen=candidate;break
 check(chosen!=0,"finite deterministic eligible15percent crit roll")
 f.sim.rng.state=chosen;e=target(f)
 near(basic(f,e),36*1.75,"I11 actual source15percent crit eligibility")
 f.sim.free();completed.append("combat_sinks")
