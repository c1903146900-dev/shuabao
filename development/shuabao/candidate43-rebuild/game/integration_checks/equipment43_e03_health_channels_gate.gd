extends "res://integration_checks/equipment43_source_gate.gd"
## Separate supplement: each positive case uses original Session/commerce/source.
const E03_HEALTH_GROUPS := ["actual_basic_lifesteal", "original_potion", "original_body_contract", "death_new_run"]
var e03_health_required: Array = E03_HEALTH_GROUPS.duplicate()
var e03_health_done: Array = []
var e03_health_partition: String = "all"

func _initialize() -> void:
 output_path="user://equipment43_e03_health_channels.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--equipment-result="):output_path=arg.trim_prefix("--equipment-result=")
  if arg.begins_with("--e03-health-group="):e03_health_partition=arg.trim_prefix("--e03-health-group=")
 if e03_health_partition!="all":
  if e03_health_partition not in E03_HEALTH_GROUPS:push_error("Unknown E03 health group");quit(2);return
  e03_health_required=[e03_health_partition]
 run.call_deferred()

func e03_health_start(label: String, extras: Array) -> Dictionary:
 var f: Dictionary=funded_shop(label)
 if f.is_empty():return {}
 if not buy(f,E03_ITEM) or not buy(f,"base:B12"):dispose(f);return {}
 for item: String in extras:
  if not buy(f,item):dispose(f);return {}
 if not check(f.session.close_panel().get("accepted",false),"health channel shopcloses") or not e03_enter(f,1) or not spawn_ready(f):dispose(f);return {}
 if not e03_damage_deficit(f,300.0,"health channel deficit") or not e03_until(f,6.05,"health channel activation"):dispose(f);return {}
 return f

func e03_health_before(f: Dictionary) -> Dictionary:
 return {"hp":f.sim.hero.hp,"clock":e03_now(f),"events":f.events.size(),"revision":f.sim.equipment_health_revision,"base":e03_base_regen(f),"max_hp":f.sim.hero.stats.max_hp,"lifesteal":f.sim.hero.lifesteal()}

func e03_channel_delta(f: Dictionary, before: Dictionary, expected_other: float, label: String) -> Dictionary:
 var incoming: float=0.0
 var outgoing: float=0.0
 var hit_events: Array=[]
 for event: Dictionary in f.events.slice(int(before.events)):
  if event.get("kind")!="damage":continue
  if event.get("target")==f.sim.hero.actor_id:incoming+=float(event.amount)
  elif event.get("source")=="attack":outgoing+=float(event.amount);hit_events.append(event.duplicate(true))
 var natural: float=float(before.base)*2.0*(e03_now(f)-float(before.clock))
 var leech: float=outgoing*float(before.lifesteal)
 var expected: float=natural+leech+expected_other
 check(float(before.max_hp)-float(before.hp)>expected,label+": original missingHP doesnotcap this independent channel sample")
 var actual: float=float(f.sim.hero.hp)-float(before.hp)+incoming
 e03_near(actual,expected,label+": naturalregen doubles while other original healing retains its amount")
 var result: Dictionary={"label":label,"before":before,"after_hp":f.sim.hero.hp,"after_clock":e03_now(f),"incoming":incoming,"natural_regen":natural,"basic_actual_damage":outgoing,"lifesteal_rate":before.lifesteal,"expected_lifesteal":leech,"other_expected":expected_other,"inferred_healing":actual,"source_hits":hit_events}
 e03_records.append(result)
 return result

func e03_lifesteal_case() -> void:
 current_group=E03_HEALTH_GROUPS[0]
 var f: Dictionary=e03_health_start(current_group,["base:B09"])
 if f.is_empty():return
 var target: Dictionary=g02_nearest(f)
 if not check(not target.is_empty(),"real LMB target belongs to original roster") or not b04_approach(f,target,float(target.radius)*0.9) or not b04_ready(f) or not e03_damage_deficit(f,300.0,"real lifesteal deficit"):dispose(f);return
 e03_near(float(f.sim.hero.lifesteal()),0.04,"original purchased bloodpump supplies fourpercent lifesteal")
 var before: Dictionary=e03_health_before(f)
 var launched: Dictionary=b04_launch(f,target.position)
 if launched.is_empty():dispose(f);return
 var observed: Dictionary=e03_channel_delta(f,before,0.0,"realLMB birth")
 var hits: Array=observed.source_hits.duplicate(true)
 for _tick: int in range(180):
  if not hits.is_empty():break
  before=e03_health_before(f);step(f)
  observed=e03_channel_delta(f,before,0.0,"realLMB flight")
  hits.append_array(observed.source_hits)
 if not check(not hits.is_empty(),"actual ordinary LMB reaches original damage and lifesteal"):dispose(f);return
 check(float(observed.expected_lifesteal)>0.0,"real attack has positive unchanged original lifesteal")
 e03_projection(f,"afterrealLMB")
 # Publicly choosing the natural-regeneration source label grants no bonus.
 var hp: float=f.sim.hero.hp
 var actual: float=f.sim.heal(3.0,false,{"source":"regeneration","fixture":"explicit_public_heal_not_original_tick"})
 e03_near(actual,3.0,"public source label alone cannot turn a directheal into doubled naturalregen")
 e03_near(float(f.sim.hero.hp)-hp,3.0,"same original heal commits only requestedthree")
 b04_integrity(f,current_group);dispose(f);e03_health_done.append(current_group)

func e03_potion_case() -> void:
 current_group=E03_HEALTH_GROUPS[1]
 var f: Dictionary=e03_health_start(current_group,["potion:1"])
 if f.is_empty():return
 if not e03_damage_deficit(f,300.0,"original potion deficit"):dispose(f);return
 var model=f.session.ledger.model
 var held: Dictionary=held_item(f,"potion:1")
 if not check(not held.is_empty(),"original commerce potion UID is present"):dispose(f);return
 serial+=1
 var request: String="equipment43-original-potion-"+str(serial)
 var used: Dictionary=model.use_potion(f.session,request,int(held.uid))
 var state: Dictionary=model.potion_consumer.snapshot()
 if not check(used.get("accepted",false) and state.active.size()==1,"original Model consumes one potion into originalconsumer"):dispose(f);return
 var rate: float=float(f.sim.hero.stats.max_hp)*0.20/4.0
 e03_near(float(state.active[0].rate),rate,"original potion keeps20percentmaxHP over4seconds")
 for index: int in range(12):
  var before: Dictionary=e03_health_before(f)
  var previous: Dictionary=model.potion_consumer.snapshot().active[0].duplicate(true)
  step(f)
  var after: Dictionary=model.potion_consumer.snapshot().active[0].duplicate(true)
  var elapsed: float=e03_now(f)-float(before.clock)
  e03_near(float(after.actual)-float(previous.actual),rate*elapsed,"E03 doesnot multiply original potionconsumer actualheal")
  e03_channel_delta(f,before,rate*elapsed,"potionplusregen tick"+str(index))
 var protected: Dictionary=model.potion_consumer.snapshot()
 var count: int=owned_count(f,"potion:1")
 var replay: Dictionary=model.use_potion(f.session,request,int(held.uid))
 check(replay.get("accepted",false) and model.potion_consumer.snapshot()==protected and owned_count(f,"potion:1")==count,"original potion command replay doesnot create secondhealing effect")
 b04_integrity(f,current_group);dispose(f);e03_health_done.append(current_group)

func e03_body_case() -> void:
 current_group=E03_HEALTH_GROUPS[2]
 var f: Dictionary=funded_shop(current_group)
 if f.is_empty():return
 if not buy(f,E03_ITEM) or not buy(f,"base:B12"):dispose(f);return
 var model=f.session.ledger.model
 var component_inventory: Array=model.state.inventory.duplicate(true)
 var component_gold: int=model.state.gold
 var i12_purchase: Dictionary=shop_command(f,"buy",{"item":"intermediate:I12"})
 if not check(i12_purchase.get("accepted",false),"original purchase intermediate:I12: "+str(i12_purchase.get("reason",""))):dispose(f);return
 check(owned_count(f,E03_ITEM)==1 and owned_count(f,"base:B12")==0 and owned_count(f,"intermediate:I12")==1,"original I12 purchase consumes held B12 recipe material")
 check(int(i12_purchase.get("credit",-1))==400 and int(i12_purchase.get("charge",-1))==650 and model.state.gold==component_gold-650,"original I12 receipt credits consumed B12 once and debits remaining650")
 e03_records.append({"kind":"original_I12_material_consumption","before_inventory":component_inventory,"after_inventory":model.state.inventory.duplicate(true),"purchase_receipt":i12_purchase.duplicate(true),"expected_credit":400,"expected_charge":650})
 var body_before: Dictionary=model.body_effects().duplicate(true)
 var before_gold: int=model.state.gold
 var before_purchases: Array=model.state.body.duplicate(true)
 # This original UI does not expose pay_body. Preserve that rejection;
 # source-authority fixture below is explicitly NOT an available GUI action.
 serial+=1
 var rejected: Dictionary=shop_command(f,"pay_body",{"purchase_id":"equipment43-unsupported-body-ui-"+str(serial)})
 check(not rejected.get("accepted",false) and rejected.get("reason")=="ui_operation_not_supported","original shop UI keeps pay_body outside its operation whitelist")
 check(model.state.gold==before_gold and model.state.body==before_purchases,"rejected public UI body intent changes neither gold nor body")
 var expected_ids: Array=["sharp","swift","iron","pierce","firm","arcane","precise"]
 var actual_ids: Array=model.config.body.outcomes.keys()
 expected_ids.sort();actual_ids.sort()
 check(actual_ids==expected_ids,"original currently bound sevenchoice prototype body pool is preserved")
 var regen_outcomes: Array=[]
 for id: String in model.config.body.outcomes:
  if float(model.config.body.outcomes[id].stats.get("hp_regen",0.0))>0.0:regen_outcomes.append(id)
 check(regen_outcomes.is_empty(),"training12 regeneration is source-defined but absent from current original runtime body pool")
 serial+=1
 var purchase_id: String="equipment43-original-authority-body-"+str(serial)
 var paid: Dictionary=f.session._authority("pay_body",{"purchase_id":purchase_id})
 e03_source_fixtures.append({"kind":"original_bound_Session_body_authority_fixture","UI_rejection":rejected,"actual_authority_result":paid.duplicate(true),"API":"same Session._authority(pay_body)","native_GUI_reachable":false,"existing_precedent":"tests/ink_rest_service_20261006/candidate01/finite_gate.gd:130"})
 if not check(paid.get("accepted",false),"same bound original Session authority commits paidbody: "+str(paid.get("reason",""))):dispose(f);return
 var pending: Dictionary=model.snapshot().body_pending
 if not check(pending.get("candidates",[]).size()==3,"original body authority exposes actualthreechoices"):dispose(f);return
 check(model.state.gold==before_gold-900 and model.state.body.size()==before_purchases.size()+1,"original bodypayment debits900 exactlyonce")
 check(int(paid.get("ledger_purchase_id",-1))==int(pending.purchase_id),"original external body receipt names actual selectable purchase")
 var choice: String=str(pending.candidates[0])
 var selected: Dictionary=command(f,"select_body",{"purchase_id":pending.purchase_id,"outcome":choice})
 if not check(selected.get("accepted",false),"select actuallyoffered original body outcome"):dispose(f);return
 e03_near(float(model.body_effects().get("hp_regen",0.0)),float(body_before.get("hp_regen",0.0)),"current nonregen body pool cannot silently inject training12 regeneration")
 var base: float=e03_base_regen(f)
 e03_near(base,float(ORIGINAL_INK_TUNING.hero_stats().regen)+1.6*owned_count(f,E03_ITEM)+0.6*owned_count(f,"base:B12")+1.0*owned_count(f,"intermediate:I12"),"original source plus actuallyheld E03/B12/I12 regen excludes consumed material")
 e03_records.append({"kind":"body_runtime_boundary","actual_offered":pending.candidates,"selected":choice,"body_effects":model.body_effects().duplicate(true),"runtime_regen_outcomes":regen_outcomes,"training12_to_E03_source_covered":false,"actual_regen_training_link":false,"blocked_reason":"training12_not_in_original_bound_body_pool","native_body_UI_covered":false})
 if not check(f.session.close_panel().get("accepted",false),"bodyfixture shopcloses") or not e03_enter(f,1) or not spawn_ready(f):dispose(f);return
 if b04_keep_original(f).is_empty() or not e03_damage_deficit(f,200.0,"afterbody originalregen deficit") or not e03_until(f,6.05,"afterbody E03 activation"):dispose(f);return
 e03_near(float(f.sim.hero.stats.regen),base*2.0,"one E03 passive doubles actual source and equipmentregen after original bodyselection")
 b04_integrity(f,current_group);dispose(f);e03_health_done.append(current_group)

func e03_death_case() -> void:
 current_group=E03_HEALTH_GROUPS[3]
 var f: Dictionary=e03_start(current_group)
 if f.is_empty():return
 if not e03_until(f,6.05,"death activation"):dispose(f);return
 f.sim.damage_hero(float(f.sim.hero.hp)+float(f.sim.hero.shield_total())+1.0,Vector3.ZERO,0.0,true,true,{"source":"equipment43_lethal_incoming_fixture","fixture":true,"direct":false,"generation":f.sim.encounter_generation,"room_id":f.sim.room_id})
 f.session.update_after_source_step()
 check(f.sim.hero.dead and not e03_view(f).active and f.session.status=="defeated","original realdeath closes continuouscombatregen")
 var hp: float=f.sim.hero.hp
 step(f,12)
 check(f.sim.hero.hp==hp and not e03_view(f).active,"original defeated source cannot heal or reactivate")
 var next: Dictionary=funded_shop("newrun_after_E03_death")
 if next.is_empty():dispose(f);return
 check(next.session.run_id!=f.session.run_id and not e03_view(next).equipped and not e03_view(next).active,"fresh original run has no prior E03 item or activecondition")
 buy(next,E03_ITEM)
 if check(next.session.close_panel().get("accepted",false),"newrun shopcloses") and e03_enter(next,1):
  check(not e03_view(next).active and float(e03_view(next).elapsed)==0.0,"newrun bought E03 begins from actualfreshcombat zero")
 b04_integrity(f,current_group);b04_integrity(next,"newrun");dispose(next);dispose(f);e03_health_done.append(current_group)

func run() -> void:
 g03_reset_evidence()
 if E03_HEALTH_GROUPS[0] in e03_health_required:e03_lifesteal_case()
 if E03_HEALTH_GROUPS[1] in e03_health_required:e03_potion_case()
 if E03_HEALTH_GROUPS[2] in e03_health_required:e03_body_case()
 if E03_HEALTH_GROUPS[3] in e03_health_required:e03_death_case()
 e03_required=e03_health_required;e03_completed=e03_health_done;e03_partition=e03_health_partition
 e03_report()
