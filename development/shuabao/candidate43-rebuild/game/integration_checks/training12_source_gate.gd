extends "res://integration_checks/training12_e03_regression_gate.gd"
## Prepared source gate only. Parent owns every engine invocation.
## Original Host, Session, one wallet, ledger, RNG, actors and health path.
const Training12Adapter = preload("res://formal_training_20261009/adapter.gd")
const Training12Prior = preload("res://equipment_regeneration_20261009/adapter.gd")
const TRAINING12_GROUPS := ["definitions", "commerce", "cap_projection", "guards_pending", "permanence_regen", "panel_signals", "consumers"]
const TRAINING12_VALUES := {
 "training:01":{"AD":8.0}, "training:02":{"AP":14.0},
 "training:03":{"attack_speed":0.08}, "training:04":{"crit_chance":0.05},
 "training:05":{"cooldown_reduction":0.04}, "training:06":{"max_hp":90.0},
 "training:07":{"defense":7.0}, "training:08":{"move_speed":0.03},
 "training:09":{"lifesteal":0.02}, "training:10":{"tenacity":0.06},
 "training:11":{"penetration":5.0}, "training:12":{"hp_regen":0.3}}
const TRAINING12_CONSUMER_FIELDS := {"AD":"ad","AP":"ap","attack_speed":"attack_speed","crit_chance":"crit_chance","cooldown_reduction":"cdr","max_hp":"max_hp","defense":"defence","move_speed":"move_speed","lifesteal":"lifesteal","tenacity":"tenacity","penetration":"penetration","hp_regen":"regen"}
const TRAINING12_AUTHORITY_HASHES := {
 "res://docs/equipment_source_20261004/correction_0959/equipment_system_extracted.json": "fc8cd1fc1a739ff1cd6704f8c80bec210f0daddf4c84a8a6fdd2509543a79c76",
 "res://tests/equipment_editable_tables_20261004/outputs/equipment_tables/converted/equipment_numeric_config.json": "cf43d853b5a1cf4f1739c4812ecacffb14edfe796c3b8b1a5e02aa04bab3d86f",
 "res://data/progression/prototype/catalog.json": "e97f35712c5437912f02e78f6342ee5a895c9db3a86c8b1131d9e08073fe7e28",
 "res://scripts/progression/catalog_model.gd": "a7fa622cfd77a79fd0f8bf4e0199491a95616d4f6bb9ad4a52d52419c43bea64",
 "res://tests/ink_initial_hex_runtime_20261004/ink_initial_stat_consumer.gd": "524471c5ef2742025d9876a40406f84b03c8f93ceccba6a65371ea6da8f2318e",
 "res://scripts/combat/common_hex_runtime.gd": "df1ab138c5c3dec7ccf0e0e548e10881d5fa9b9300f9b0778cdab50f5361ac4c",
 "res://scripts/combat/common_hex_bridge.gd": "3bf945cf040051295e496617cef7c52bec35c7c0ae5fab73d9234961c75b88dd",
 "res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_sim.gd": "42e4429b87742fb9e508efe9284fad71171cfcc276012990f5fa6ee4c4ed70d2",
 "res://tests/ink_shop_ui_host_20261004/shop_session.gd": "820f74ecb5cb14066126c8486f60092315148552d86a27c7fc36d54b43c3e2e5",
 "res://tests/ink_shop_ui_host_20261004/shop_panel.gd": "fb38b49456864976e966483d76363b8b41a123940e2ca000ce0ea512edbae0c4",
 "res://tests/ink_first_floor_user_route_20261005/runtime01/bootstrap_session.gd": "e928d08b268ee4ba828073c685e7588aeafabcff6461c0d87a8bbac9830541f3",
 "res://tests/ink_first_floor_user_route_20261005/runtime01/floor_session.gd": "bf3784501df0da9ff6006fda87d780e7a288052084aa2150fc9d696a97bf4e1b",
 "res://tests/ink_intermediate_shop_ui_20261004/fix02/shop_panel.gd": "9d32dbd9fe2c3efe2c44ce4c6113397387b6e98028934fe6ca9acbb31632e2c1",
 "res://tests/ink_shop_ledger_bridge_20261004/fix01/ink_shop_run_model.gd": "9e4a06c7915bfcc842402c4c9b6e26f4efa88e45582a678dd7bd6304828c7ff7",
 "res://tests/equipment_shop_transactions_20261004/shop_visit_model.gd": "81cd336a76fb2436742300c0fb81951f394ae7711bb3e855523ccfec513b2a52",
 "res://tests/ink_equipment_regen_20261008/candidate01/regen_units.gd": "eb98906bd0846f3c41fc8e44615f11cb04c375b4f5169129c9329b2b59389a47",
 "res://equipment_regeneration_20261009/common_bridge.gd": "89b2679a3e842285cdf2dbcdf966fa7ef283826e0b9c36b0d7fe381ca7bf6f5b"
}
var training12_required: Array = TRAINING12_GROUPS.duplicate()
var training12_done: Array = []
var training12_partition: String = "all"
var training12_records: Array = []
var training12_fixtures: Array = []

func _initialize() -> void:
 output_path="user://training12_source_gate.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--equipment-result="):output_path=arg.trim_prefix("--equipment-result=")
  if arg.begins_with("--training12-group="):training12_partition=arg.trim_prefix("--training12-group=")
 if training12_partition!="all":
  if training12_partition not in TRAINING12_GROUPS:push_error("Unknown training12 source group");quit(2);return
  training12_required=[training12_partition]
 run.call_deferred()

func training12_args(f: Dictionary, extra: Dictionary = {}) -> Dictionary:
 var args: Dictionary=f.session.ledger.model.commerce_token().duplicate(true)
 args.merge(extra,true)
 return args

func training12_submit(f: Dictionary, action: String, extra: Dictionary = {}) -> Dictionary:
 serial+=1
 var result: Dictionary=f.session.submit("training12-ui-"+str(serial),action,training12_args(f,extra))
 f.session.update_after_source_step()
 return result

func training12_protected(f: Dictionary) -> Dictionary:
 var model=f.session.ledger.model
 return {"gold":model.state.gold,"body":model.state.body.duplicate(true),"rng":model.state.rng,"inventory":model.state.inventory.duplicate(true),"body_effects":model.body_effects().duplicate(true),"hp":f.sim.hero.hp,"stats":f.sim.hero.stats.duplicate(true),"visit":model.state.shop_visit.duplicate(true),"revision":model.state.revision}

func training12_paid(f: Dictionary) -> Dictionary:
 var model=f.session.ledger.model
 var gold: int=model.state.gold
 var count: int=model.state.body.size()
 var eligibility: Dictionary=model.training_eligibility()
 var rng: int=model.state.rng
 var expected_rng: int=rng
 for _draw: int in range(3):expected_rng=(expected_rng*48271)%2147483647
 var result: Dictionary=training12_submit(f,"training_pay")
 if not check(result.get("accepted",false),"legal Session training_pay accepted: "+str(result.get("reason",""))):return {}
 var pending: Dictionary=model.snapshot().body_pending.duplicate(true)
 if not check(pending.get("candidates",[]).size()==3,"paid actual pool draws three choices"):return {}
 var unique: Dictionary={}
 for id: String in pending.candidates:
  unique[id]=true
  check(id in eligibility.eligible_ids,"each real drawn option was effective before payment: "+id)
 check(unique.size()==3,"real draw contains three different formal outcomes")
 check(model.state.gold==gold-900 and model.state.body.size()==count+1,"one real ledger purchase spends fixed900 exactlyonce")
 check(int(pending.cost)==900 and int(model.state.rng)==expected_rng,"original cost and exactlythree original LCG advances preserved")
 training12_records.append({"kind":"real_paid_draw","receipt":result.duplicate(true),"pending":pending.duplicate(true),"before_rng":rng,"after_rng":model.state.rng,"before_gold":gold,"after_gold":model.state.gold,"eligibility":eligibility.duplicate(true)})
 return pending

func training12_choose(f: Dictionary, pending: Dictionary, choice: String) -> bool:
 var model=f.session.ledger.model
 var before: Dictionary=model.body_effects().duplicate(true)
 var gold: int=model.state.gold
 var hp: float=f.sim.hero.hp
 var inventory: Array=model.state.inventory.duplicate(true)
 serial+=1
 var request_id: String="training12-choice-"+str(serial)
 var request_args: Dictionary=training12_args(f,{"purchase_id":pending.purchase_id,"outcome":choice})
 var selected: Dictionary=f.session.submit(request_id,"training_select",request_args)
 f.session.update_after_source_step()
 f["training12_last_select_id"]=request_id
 f["training12_last_select_args"]=request_args.duplicate(true)
 if not check(selected.get("accepted",false),"legal Session selects actual offered "+choice+": "+str(selected.get("reason",""))):return false
 check(model.snapshot().body_pending.is_empty() and model.state.gold==gold and model.state.inventory==inventory,"select clears only pending, costs no second900 and occupies no equipment slot")
 var after: Dictionary=model.body_effects()
 var delta: Dictionary=TRAINING12_VALUES[choice]
 for id: String in TRAINING12_VALUES:
  for key: String in TRAINING12_VALUES[id]:
   e03_near(float(after.get(key,0.0))-float(before.get(key,0.0)),float(delta.get(key,0.0)),"actual permanent body aggregate delta "+key)
 e03_near(float(f.sim.hero.hp),hp,"pure stat choice never restores current HP, including maxHP")
 training12_records.append({"kind":"real_selected_outcome","purchase_id":pending.purchase_id,"choice":choice,"before":before,"after":after.duplicate(true),"receipt":selected.duplicate(true),"hp_before":hp,"hp_after":f.sim.hero.hp})
 return true

func training12_definitions() -> void:
 current_group=TRAINING12_GROUPS[0]
 var f: Dictionary=funded_shop(current_group)
 if f.is_empty():return
 var model=f.session.ledger.model
 for path: String in TRAINING12_AUTHORITY_HASHES:check(FileAccess.get_sha256(path)==TRAINING12_AUTHORITY_HASHES[path],"unchanged original authority/recipe/economic source "+path)
 var numeric: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(B01_NUMERIC))
 var original_numeric: PackedByteArray=var_to_bytes(numeric)
 var built: Dictionary=Training12Adapter.build(numeric)
 if not check(built.get("accepted",false),"formal adapter accepts unchanged original numeric authority"):dispose(f);return
 check(var_to_bytes(numeric)==original_numeric,"formal adapter doesnot mutate authority numeric/recipes")
 check(model.config.body.outcomes.size()==12 and built.body.outcomes.size()==12,"fresh bound ordinary model has formal twelve outcomes")
 check(model.config.body.get("formal_training_pool",false) and int(model.config.body.cost)==900 and int(model.commerce_definitions.body_price)==900,"same formal900 authority reaches body and original commerce")
 var expected_ids: Array=TRAINING12_VALUES.keys();expected_ids.sort()
 var actual_ids: Array=model.config.body.outcomes.keys();actual_ids.sort()
 check(actual_ids==expected_ids,"formal training01..12 replace prototype7 only in bound definitions")
 for id: String in TRAINING12_VALUES:
  var actual: Dictionary=model.config.body.outcomes.get(id,{})
  var expected: Dictionary=TRAINING12_VALUES[id]
  check(actual.get("stats",{}).size()==1 and actual.get("stats",{}).keys()==expected.keys(),"one authored pure stat for "+id)
  for key: String in expected:e03_near(float(actual.get("stats",{}).get(key,-99.0)),float(expected[key]),"formal source increment "+id+"/"+key)
  check(model.support(actual).get("supported",false),"existing actual stat hooks support "+id)
 var prior: Dictionary=Training12Prior.build(numeric)
 if check(prior.get("accepted",false),"equipment43 adapter still accepts source"):
  check(model.runtime_stat_definitions.size()==prior.definitions.size(),"formal training adds no equipment or passive admission")
  for id: String in prior.definitions:check(var_to_bytes(prior.definitions[id])==var_to_bytes(model.runtime_stat_definitions.get(id,{})),"equipment43 definition unchanged "+id)
 check(model.snapshot().content_profile=="ordinary_equipment43_potions3","equipment profile remains truthful43")
 check(not model.equipment_runtime_status("final:G05").get("runtime_complete",false),"G05 remains outside supported equipment slice")
 var status: Dictionary=model.training_status()
 check(int(status.price)==900 and int(status.completed_count)==0 and status.pending.is_empty() and not status.free_available,"fresh training has fixed900, no purchases or invented freecredits")
 var prototype: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/progression/prototype/catalog.json"))
 check(prototype.body.outcomes.size()==7 and prototype.body.outcomes.has("sharp") and not prototype.body.outcomes.has("training:12"),"prototype authority file remains preserved as history")
 e03_near(float(model.config.body.outcomes["training:12"].stats.hp_regen),1.5/5.0,"formal regeneration1.5per5 maps to0.3 per actorcombatsecond")
 b04_integrity(f,current_group);dispose(f);training12_done.append(current_group)

func training12_commerce() -> void:
 current_group=TRAINING12_GROUPS[1]
 var f: Dictionary=funded_shop(current_group)
 if f.is_empty():return
 var model=f.session.ledger.model
 for item: String in ["base:B01","base:B02","base:B03","base:B04","base:B05","base:B06"]:
  if not buy(f,item):dispose(f);return
 if not check(model.state.inventory.size()==6,"six real purchased equipment occupy full sixslots"):dispose(f);return
 var inventory: Array=model.state.inventory.duplicate(true)
 var initial_gold: int=model.state.gold
 var original_undo_count: int=model.state.shop_visit.undo.size()
 var protected: Dictionary={}
 for index: int in range(24):
  var pending: Dictionary=training12_paid(f)
  if pending.is_empty():dispose(f);return
  protected=training12_protected(f)
  var extra_pay: Dictionary=training12_submit(f,"training_pay")
  check(not extra_pay.get("accepted",false) and training12_protected(f)==protected,"pending actualchoice rejects secondpayment without debit/RNG advance")
  if not training12_choose(f,pending,str(pending.candidates[0])):dispose(f);return
  check(model.state.gold==initial_gold-900*(index+1) and model.state.inventory==inventory,"fixed900 beyond20 purchases doesnot consume six equipment slots")
  check(int(model.training_status().completed_count)==index+1,"actual completedcount grows without taskstage cap")
 protected=training12_protected(f)
 serial+=1
 var request_id: String="training12-replay-pay-"+str(serial)
 var args: Dictionary=training12_args(f)
 var paid: Dictionary=f.session.submit(request_id,"training_pay",args)
 f.session.update_after_source_step()
 if not check(paid.get("accepted",false),"explicit replay setup pays through legal Session"):dispose(f);return
 var committed: Dictionary=training12_protected(f)
 var replay: Dictionary=f.session.submit(request_id,"training_pay",args)
 f.session.update_after_source_step()
 check(training12_protected(f)==committed,"same ID and stale originaltoken never doubledebit or redraw")
 var pending: Dictionary=model.snapshot().body_pending.duplicate(true)
 var invalid: Dictionary=training12_submit(f,"training_select",{"purchase_id":pending.purchase_id,"outcome":"not_an_offered_outcome"})
 check(not invalid.get("accepted",false) and training12_protected(f)==committed,"invalid offeredID cannot spend or select")
 if not training12_choose(f,pending,str(pending.candidates[0])):dispose(f);return
 protected=training12_protected(f)
 var selection_id: String=str(f.training12_last_select_id)
 var selection_args: Dictionary=f.training12_last_select_args.duplicate(true)
 var selected_replay: Dictionary=f.session.submit(selection_id,"training_select",selection_args)
 f.session.update_after_source_step()
 check(selected_replay.get("accepted",false) and selected_replay.get("replayed",false) and not selected_replay.get("changed",true) and selected_replay.get("events",[]).is_empty() and training12_protected(f)==protected,"same successfulselection ID and originalpayload replays its originalreceipt without secondgain")
 serial+=1
 var new_id_old_token: Dictionary=f.session.submit("training12-expired-selection-"+str(serial),"training_select",selection_args)
 check(not new_id_old_token.get("accepted",false) and new_id_old_token.get("reason")=="stale_revision" and training12_protected(f)==protected,"new selectionID with oldtoken is rejected rather than borrowing receipt")
 var conflict_args: Dictionary=selection_args.duplicate(true)
 conflict_args.outcome=str(pending.candidates[1])
 var changed_payload: Dictionary=f.session.submit(selection_id,"training_select",conflict_args)
 check(not changed_payload.get("accepted",false) and changed_payload.get("reason")=="command_id_conflict" and training12_protected(f)==protected,"same selectionID with another offered outcome conflicts even with originaltoken")
 var select_id_as_pay: Dictionary=f.session.submit(selection_id,"training_pay",training12_args(f))
 check(not select_id_as_pay.get("accepted",false) and select_id_as_pay.get("reason")=="command_id_conflict" and training12_protected(f)==protected,"successful selectionID cannot be reused across action for payment")
 var pay_id_as_select: Dictionary=f.session.submit(request_id,"training_select",selection_args)
 check(not pay_id_as_select.get("accepted",false) and pay_id_as_select.get("reason")=="command_id_conflict" and training12_protected(f)==protected,"successful paymentID cannot be reused across action for selection")
 training12_records.append({"kind":"original_selection_command_receipt","id":selection_id,"args":selection_args,"replay":selected_replay,"new_id_old_token":new_id_old_token,"changed_payload":changed_payload,"selection_id_as_payment":select_id_as_pay,"payment_id_as_selection":pay_id_as_select})
 var duplicate: Dictionary=training12_submit(f,"training_select",{"purchase_id":pending.purchase_id,"outcome":str(pending.candidates[0])})
 check(not duplicate.get("accepted",false) and training12_protected(f)==protected,"selected purchase cannot be selected twice")
 var body: Array=model.state.body.duplicate(true)
 var effects: Dictionary=model.body_effects().duplicate(true)
 var undone: Dictionary=shop_command(f,"undo")
 check(model.state.body==body and model.body_effects()==effects,"original equipment undo cannot reverse permanent training")
 check(model.state.shop_visit.undo.size()<=original_undo_count,"training creates no undo transaction; only original equipment entries can be undone")
 training12_records.append({"kind":"replay_and_undo","pay":paid,"replay":replay,"undo":undone,"completed_count":model.training_status().completed_count,"full_six_slots":true})
 b04_integrity(f,current_group);dispose(f);training12_done.append(current_group)

func training12_caps() -> void:
 current_group=TRAINING12_GROUPS[2]
 var f: Dictionary=funded_shop(current_group)
 if f.is_empty():return
 var model=f.session.ledger.model
 var protected: Dictionary=training12_protected(f)
 var cases: Array=[["training:03","attack_speed",2.5,0.001],["training:05","cdr",0.65,0.0001],["training:10","tenacity",1.0,0.0001],["training:04","crit_chance",1.0,0.0001]]
 for row: Array in cases:
  for offset: float in [-float(row[3]),0.0,float(row[3])]:
   var input: Dictionary={"attack_speed":0.7,"cdr":0.0,"tenacity":0.0,"crit_chance":0.0}
   input[row[1]]=float(row[2])+offset
   var before: Dictionary=input.duplicate(true)
   var result: Dictionary=model.training_eligibility_for_stats(input)
   check(result.get("accepted",false),"pure effectivecap projection accepts finite fixture "+str(row[1]))
   check((str(row[0]) in result.eligible_ids)==(offset<0.0),"partiallyeffective option retained; exact/above cap excluded "+str(row[1])+" offset="+str(offset))
   check(input==before and training12_protected(f)==protected,"isolated cap projection is readonly; no source stats/RNG/body mutation")
   training12_records.append({"kind":"isolated_effective_stats_projection","case":row,"offset":offset,"input":input,"result":result.duplicate(true),"source_actor_boundary_reached":false})
 var all_capped: Dictionary=model.training_eligibility_for_stats({"attack_speed":2.5,"cdr":0.65,"tenacity":1.0,"crit_chance":1.0})
 check(all_capped.eligible_ids.size()==8 and all_capped.excluded_ids.size()==4,"allfour caps still leave eight real pure stat options")
 for id: String in ["training:01","training:02","training:06"]:check(id in all_capped.eligible_ids,"uncapped AD/AP/maxHP ensure at least3: "+id)
 check(training12_protected(f)==protected,"allcap fixture never writes actor or model state")
 b04_integrity(f,current_group);dispose(f);training12_done.append(current_group)

func training12_enter_locked_first_row(f: Dictionary) -> bool:
 # A pending-choice negative test has already selected this authored node.
 # RowState deliberately forbids every second select, even the same node.
 var selected: Dictionary=f.session.row_state.snapshot()
 var node_id: String=str(B01_ROUTE[0])
 if not check(selected.status=="selected" and selected.selected_identity.node_id==node_id and int(selected.selected_identity.row_number)==1,"resume exact previously selected original node without reselecting"):return false
 var at: float=e03_now(f)
 var entered: Dictionary=f.session.enter_selected_node()
 if not check(entered.get("accepted",false),"enter previously locked actual node "+node_id+": "+str(entered.get("reason",""))):return false
 check_owners(f,node_id)
 check(f.sim.phase=="combat" and f.session.status=="combat" and f.sim.ai_enabled and f.sim.auto_finish,"locked original node retains actual combat, AI and terminal authority")
 var expected: Array=f.session.expected_enemies.duplicate()
 check(expected.size()==int(B01_ROSTER_COUNTS[0]) and f.sim.enemies.size()==expected.size(),"locked original node has exact authored six actor roster")
 for enemy: Dictionary in f.sim.enemies:
  check(str(enemy.actor_id) in expected and int(enemy.generation)==f.sim.encounter_generation and str(enemy.room_id)==f.sim.room_id,"locked node contains only original admitted actor "+str(enemy.actor_id))
 f.e03_combat_start=at
 # No E03 is equipped in this guard case. Its passive inspector deliberately
 # reports start=-1; the retained Common owns the actual combat episode clock.
 e03_near(float(f.sim.common.e03_clock_context().combat_started_at),at,"resumed locked entry retains original Common combat clock")
 check(not e03_view(f).equipped and not e03_view(f).active and float(e03_view(f).combat_started_at)==-1.0,"unequipped E03 has no active itemcondition or published starttime")
 e03_projection(f,"resumed previously selected original combat")
 f.identities.append({"node":node_id,"row":1,"room":f.sim.room_id,"generation":f.sim.encounter_generation,"expected_enemies":expected,"identity":identity(f),"already_selected_resume":true})
 return check(f.session.fault.is_empty(),"no entry fault resuming locked node "+node_id)

func training12_guards_pending() -> void:
 current_group=TRAINING12_GROUPS[3]
 var f: Dictionary=funded_shop(current_group)
 if f.is_empty():return
 var model=f.session.ledger.model
 var protected: Dictionary=training12_protected(f)
 for forged: Dictionary in [{"free":true},{"purchase_id":"caller_owned_payment"},{"task_effects":[{"count":2}]},{"effective_stats":{"cdr":0.0}}]:
  var denied: Dictionary=training12_submit(f,"training_pay",forged)
  check(not denied.get("accepted",false) and training12_protected(f)==protected,"UI cannot supply credit/authority/purchaseID/effectiveness: "+str(forged.keys()))
 var legacy: Dictionary=training12_submit(f,"pay_body")
 check(not legacy.get("accepted",false) and training12_protected(f)==protected,"raw trusted pay_body remains outside UI allowlist")
 if not check(f.session.close_panel().get("accepted",false),"close originalshop for closedguard"):dispose(f);return
 protected=training12_protected(f)
 var closed: Dictionary=training12_submit(f,"training_pay")
 check(not closed.get("accepted",false) and closed.get("reason")=="shop_panel_not_open" and training12_protected(f)==protected,"closed panel refuses newbody payment")
 if not check(f.session.open_panel().get("accepted",false),"reopen originalshop for staleguard"):dispose(f);return
 var stale: Dictionary=training12_args(f)
 if not buy(f,"base:B01"):dispose(f);return
 protected=training12_protected(f)
 serial+=1
 var expired: Dictionary=f.session.submit("training12-stale-"+str(serial),"training_pay",stale)
 check(not expired.get("accepted",false) and expired.get("reason")=="stale_revision" and training12_protected(f)==protected,"expired paymenttoken cannot debit900 or change RNG")
 if not check(f.session.set_modal_blocked(true).get("accepted",false),"original modal blocksbody controls"):dispose(f);return
 protected=training12_protected(f)
 var modal: Dictionary=training12_submit(f,"training_pay")
 check(not modal.get("accepted",false) and modal.get("reason")=="mandatory_hex_pending" and training12_protected(f)==protected,"mandatory modal refuses trainingpayment")
 if not check(f.session.set_modal_blocked(false).get("accepted",false),"original modal resumesbody controls"):dispose(f);return
 var pending: Dictionary=training12_paid(f)
 if pending.is_empty():dispose(f);return
 var old_selection: Dictionary=training12_args(f,{"purchase_id":pending.purchase_id,"outcome":str(pending.candidates[0])})
 if not check(f.session.select_node(1,str(B01_ROUTE[0])).get("accepted",false),"actual authored nextnode selected") or not check(f.session.close_panel().get("accepted",false),"pendingbody panel canclose"):dispose(f);return
 var body: Array=model.state.body.duplicate(true)
 var gold: int=model.state.gold
 var blocked: Dictionary=f.session.next_room_preflight()
 check(not blocked.get("accepted",false) and blocked.get("reason")=="body_choice_pending","unselected realbody blocks nextroom preflight")
 var entry: Dictionary=f.session.enter_selected_node()
 check(not entry.get("accepted",false) and entry.get("reason")=="body_choice_pending" and model.state.body==body and model.state.gold==gold,"real pendingbody cannot be bypassed by nextroom entry")
 if not check(f.session.open_panel().get("accepted",false),"pendingbody shop reopens legally"):dispose(f);return
 check(model.snapshot().body_pending==pending and model.state.gold==gold,"close/reopen preserves exact paid threechoices without spending again")
 protected=training12_protected(f)
 serial+=1
 var stale_select: Dictionary=f.session.submit("training12-stale-select-"+str(serial),"training_select",old_selection)
 check(not stale_select.get("accepted",false) and stale_select.get("reason")=="stale_revision" and training12_protected(f)==protected,"old preclose selectiontoken rejected without consuming pending")
 if not training12_choose(f,pending,str(pending.candidates[0])):dispose(f);return
 var effects: Dictionary=model.body_effects().duplicate(true)
 if not check(f.session.close_panel().get("accepted",false),"completedchoice shopcloses") or not training12_enter_locked_first_row(f) or not spawn_ready(f):dispose(f);return
 check(model.body_effects()==effects and model.snapshot().body_pending.is_empty(),"same permanentbody survives real combat entry")
 protected=training12_protected(f)
 var combat: Dictionary=training12_submit(f,"training_pay")
 check(not combat.get("accepted",false) and training12_protected(f)==protected,"combat cannot submit new bodypayment")
 var combat_open: Dictionary=f.session.open_panel()
 check(not combat_open.get("accepted",false) and not f.session.panel_open,"original actualcombat location cannot openbody shop")
 var hp: float=f.sim.hero.hp
 f.sim.damage_hero(hp+float(f.sim.hero.shield_total())+1.0,Vector3.ZERO,0.0,true,true,{"source":"training12_lethal_guard_fixture","fixture":true,"direct":false,"generation":f.sim.encounter_generation,"room_id":f.sim.room_id})
 f.session.update_after_source_step()
 check(f.sim.hero.dead and f.session.status=="defeated","original sourcedeath establishes realdead guard")
 protected=training12_protected(f)
 var dead: Dictionary=training12_submit(f,"training_pay")
 var dead_open: Dictionary=f.session.open_panel()
 check(not dead.get("accepted",false) and not dead_open.get("accepted",false) and training12_protected(f)==protected,"realdead source cannot open or purchase from shop")
 training12_fixtures.append({"kind":"original_lethal_health_API","direct_HP_write":false,"pending_preserved_on_close":true,"original_roster_only":true})
 b04_integrity(f,current_group);dispose(f);training12_done.append(current_group)

func training12_permanence_regen() -> void:
 current_group=TRAINING12_GROUPS[4]
 var f: Dictionary=funded_shop(current_group)
 if f.is_empty():return
 var model=f.session.ledger.model
 if not buy(f,E03_ITEM):dispose(f);return
 var found: Dictionary={"training:06":false,"training:12":false}
 # Follow the actual finite RNG stream. Never write a candidate, seed or body.
 for attempt: int in range(40):
  if found["training:06"] and found["training:12"]:break
  var pending: Dictionary=training12_paid(f)
  if pending.is_empty():dispose(f);return
  var chosen: String=str(pending.candidates[0])
  for wanted: String in ["training:12","training:06"]:
   if not found[wanted] and wanted in pending.candidates:chosen=wanted;break
  var regen_before: float=e03_base_regen(f)
  var max_before: float=f.sim.hero.stats.max_hp
  var hp_before: float=f.sim.hero.hp
  if not training12_choose(f,pending,chosen):dispose(f);return
  if chosen in found:found[chosen]=true
  if chosen=="training:12":e03_near(e03_base_regen(f)-regen_before,0.3,"real formalregen selection adds0.3 to original projectedregen channel")
  if chosen=="training:06":
   e03_near(float(f.sim.hero.stats.max_hp)-max_before,90.0,"actual formal maxHP selection adds90 through original statconsumer")
   e03_near(float(f.sim.hero.hp),hp_before,"actual maxHP choice never heals missingHP")
 if not check(found["training:06"] and found["training:12"],"bounded real RNG stream reaches both actual maxHP and regeneration selections"):dispose(f);return
 var body: Array=model.state.body.duplicate(true)
 var effects: Dictionary=model.body_effects().duplicate(true)
 var base: float=e03_base_regen(f)
 if not check(f.session.close_panel().get("accepted",false),"real regen training shopcloses") or not e03_enter(f,1) or not spawn_ready(f):dispose(f);return
 if b04_keep_original(f).is_empty() or not e03_damage_deficit(f,150.0,"realbody regen HP deficit"):dispose(f);return
 check(model.state.body==body and model.body_effects()==effects,"actual permanentbody remains through original roomentry")
 if not e03_until(f,6.1,"actual training12 source through E03 threshold"):dispose(f);return
 e03_near(float(f.sim.hero.projected_base_stats.regen),base,"E03 never rewrites actual trained base regen")
 e03_near(float(f.sim.hero.stats.regen),base*2.0,"same original E03 multiplier includes selected training12 regen")
 for index: int in range(10):
  if not e03_tick(f,"realtraining naturalregen boosted sample"+str(index)):dispose(f);return
 training12_records.append({"kind":"actual_training12_to_E03","actual_regen_training_link":true,"native_GUI":false,"body":body.duplicate(true),"body_effects":effects.duplicate(true),"base_regen":base,"active_view":e03_view(f),"single_original_heal_path":true,"direct_body_or_HP_write":false})
 if not b04_settle_row(f,1):dispose(f);return
 check(not e03_view(f).active and model.state.body==body and model.body_effects()==effects,"real victory clears E03 condition but retains permanentbody")
 var safe_clock: float=e03_now(f)
 var safe_hp: float=f.sim.hero.hp
 step(f,12)
 check(e03_now(f)==safe_clock and f.sim.hero.hp==safe_hp,"safe area doesnot tick a new trainingregen timer")
 if not g02_open(f):dispose(f);return
 var undo_result: Dictionary=shop_command(f,"undo")
 check(model.state.body==body and model.body_effects()==effects,"nextroom boundary plus undo cannot remove training")
 if not check(f.session.close_panel().get("accepted",false),"betweenroom shopcloses") or not e03_enter(f,2) or not spawn_ready(f):dispose(f);return
 check(model.state.body==body and model.body_effects()==effects and not e03_view(f).active,"next realcombat retains body and starts fresh E03 delay")
 if not b04_settle_row(f,2) or not choose_required_hexes(f) or not enter(f,3):dispose(f);return
 check(f.session._entered_service("rest"),"actual entered authoredrest is a legalbody shoplocation")
 if not check(f.session.open_panel().get("accepted",false),"actual restshop exposesbody"):dispose(f);return
 var rest_pending: Dictionary=training12_paid(f)
 if rest_pending.is_empty() or not training12_choose(f,rest_pending,str(rest_pending.candidates[0])):dispose(f);return
 check(model.state.body.slice(0,body.size())==body,"realrest plus furtherpaid training preserves every prior permanentchoice")
 if not check(f.session.close_panel().get("accepted",false),"restshop closes") or not check(f.session.complete_service().get("accepted",false),"actual rest service completes"):dispose(f);return
 # The inherited authored B01 route is r03c rest -> r04c combat ->
 # r05b combat -> r06b training. Use every original entry/terminal receipt.
 for row: int in [4,5]:
  if not enter(f,row) or not b04_settle_row(f,row):dispose(f);return
  check(model.state.body.slice(0,body.size())==body,"permanent choices survive authentic intervening combat row"+str(row))
 if not enter(f,6):dispose(f);return
 check(f.session._entered_service("training"),"actual entered authoredtraining is legal shoplocation")
 if not check(f.session.open_panel().get("accepted",false),"actual trainingnode opens samebody shop"):dispose(f);return
 var node_pending: Dictionary=training12_paid(f)
 if node_pending.is_empty() or not training12_choose(f,node_pending,str(node_pending.candidates[0])):dispose(f);return
 var permanent: Array=model.state.body.duplicate(true)
 if not check(f.session.close_panel().get("accepted",false),"trainingnode shop closes"):dispose(f);return
 var reset: Dictionary=f.session.reset_training()
 check(reset.get("accepted",false) and model.state.body==permanent,"original skillreset cannot retract permanent bodytraining")
 training12_records.append({"kind":"original_services_and_undo","undo":undo_result,"skill_reset":reset,"body_preserved":true,"rest_and_training_actually_entered":true})
 b04_integrity(f,current_group);dispose(f);training12_done.append(current_group)

func training12_panel_signals() -> void:
 current_group="panel_signals"
 var f: Dictionary=funded_shop(current_group)
 if f.is_empty():return
 var model=f.session.ledger.model
 for item: String in ["base:B01","base:B02","base:B03","base:B04","base:B05","base:B06"]:
  if not buy(f,item):dispose(f);return
 var panel: Control=load("res://formal_training_20261009/panel.gd").new()
 root.add_child(panel)
 panel.bind_session(f.session)
 f.host.shop_session=f.session
 f.host.shop_panel=panel
 # The real source panel signal calls the retained original Host callback.
 # Headless signal emission is not a native pointer/keyboard or full GUI run.
 panel.transaction_requested.connect(f.host._submit_shop)
 panel._set_category("training")
 panel.refresh(true)
 if not check(panel.visible and panel._training_box.visible and not panel._training_pay.disabled,"actualsource panel offers900 with sixreal equipment slots"):panel.free();dispose(f);return
 check(panel._training_pay.text.contains("900") and panel._training_summary.text.contains("0"),"actual panel displays fixedprice and completedcount")
 var gold: int=model.state.gold
 var body_count: int=model.state.body.size()
 var original_pay: Button=panel._training_pay
 original_pay.pressed.emit()
 f.session.update_after_source_step()
 var pending: Dictionary=model.snapshot().body_pending.duplicate(true)
 if not check(pending.get("candidates",[]).size()==3,"actual panel pay signal reaches original Host/Session and actualdraw"):panel.free();dispose(f);return
 check(model.state.gold==gold-900 and model.state.body.size()==body_count+1 and model.state.inventory.size()==6,"actual panel spends900 once at full inventory")
 check(panel._training_pay.disabled and panel._training_choices.get_child_count()==3,"pending actualpanel disablespay and renders exactlythreebuttons")
 var protected: Dictionary=training12_protected(f)
 original_pay.pressed.emit()
 check(training12_protected(f)==protected,"actual paybutton immediate doublesignal cannotpay twice")
 var stale_button: Button=panel._training_choices.get_child(0)
 var displayed_names: Array=[]
 for option: Dictionary in model.training_status().options:displayed_names.append(str(option.name))
 for button: Button in panel._training_choices.get_children():
  var matches: int=0
  for name: String in displayed_names:
   if button.text.contains(name):matches+=1
  check(matches==1 and not button.disabled and button.tooltip_text.contains("永久"),"actual choicebutton maps to one displayed sourceoutcome and permanence")
 if not check(f.session.close_panel().get("accepted",false),"panel fixture closes using actualSession"):panel.free();dispose(f);return
 panel.refresh(true)
 check(not panel.visible and model.snapshot().body_pending==pending,"closed panel hides but keeps authoritative exactpending")
 if not check(f.session.open_panel().get("accepted",false),"panel fixture reopens using actualSession"):panel.free();dispose(f);return
 panel.refresh(true)
 check(panel.visible and panel._category=="training" and panel._training_choices.get_child_count()==3 and model.snapshot().body_pending==pending,"actual panel reopens same threechoices")
 protected=training12_protected(f)
 check(stale_button.disabled and stale_button.get_parent()==null,"signal-safe retired choicebutton is disabled and detached")
 stale_button.pressed.emit()
 check(training12_protected(f)==protected,"retired preclose buttontoken cannotselect or mutate actualstate")
 var current_button: Button=panel._training_choices.get_child(0)
 var current_choice: String=str(pending.candidates[0])
 var effects_before: Dictionary=model.body_effects().duplicate(true)
 current_button.pressed.emit()
 f.session.update_after_source_step()
 check(model.snapshot().body_pending.is_empty() and model.state.gold==gold-900,"actual currentchoice completes with no seconddebit")
 var delta: Dictionary=TRAINING12_VALUES[current_choice]
 for key: String in delta:e03_near(float(model.body_effects().get(key,0.0))-float(effects_before.get(key,0.0)),float(delta[key]),"actual renderedchoice grants original formal increment")
 protected=training12_protected(f)
 current_button.pressed.emit()
 check(training12_protected(f)==protected,"retired completedbutton immediate doubleclick cannot grant secondstat")
 check(panel._training_choices.get_child_count()==0 and not panel._training_pay.disabled and panel._training_summary.text.contains("1"),"actual panel returns to fixed900 with one completedchoice")
 training12_records.append({"kind":"actual_source_panel_signals","same_original_Host_callback":true,"same_original_Session":true,"full_six_slots":true,"pending_close_reopen":true,"stale_retired_button_rejected":true,"direct_HP_rng_body_write":false,"native_GUI":false,"full_normal_Host_controls_construction":false})
 panel.free()
 b04_integrity(f,current_group);dispose(f);training12_done.append(current_group)

func training12_consumer_expected(source: Dictionary, additions: Dictionary) -> Dictionary:
 # Independent arithmetic from the frozen original consumer contract. Never
 # call Model.project_stats or Common.project_stats to predict their output.
 var expected: Dictionary={}
 for stat: String in TRAINING12_CONSUMER_FIELDS:
  var field: String=TRAINING12_CONSUMER_FIELDS[stat]
  var value: float=float(source[field])
  var addition: float=float(additions.get(stat,0.0))
  expected[field]=value*(1.0+addition) if stat in ["attack_speed","move_speed"] else value+addition
 expected.attack_speed=minf(float(expected.attack_speed),2.5)
 expected.cdr=minf(float(expected.cdr),0.65)
 expected.tenacity=minf(float(expected.tenacity),1.0)
 return expected

func training12_consumer_sample(f: Dictionary) -> Dictionary:
 var h=f.sim.hero
 var uses_critical_getter: bool=h.has_method("critical_chance")
 # Ink's actual basic source clamps raw crit probability when no concrete
 # virtual getter exists. Common.context likewise uses a getter only if present.
 var critical: float=float(h.call("critical_chance")) if uses_critical_getter else clampf(float(h.stats.crit_chance),0.0,1.0)
 return {"base":h.base_stats.duplicate(true),"projected":h.projected_base_stats.duplicate(true),"stats":h.stats.duplicate(true),"hp":h.hp,"clock":e03_now(f),"actor_script":h.get_script().resource_path,
  "virtual":{"ad":h.ad(),"defence":h.defence(),"attack_speed":h.attack_speed(),"move_speed":h.speed(),"tenacity":h.tenacity(),"lifesteal":h.lifesteal(),"effective_crit_probability":critical},
  "uses_critical_chance_getter":uses_critical_getter,"common_effective":f.sim.common.context().hero.stats.duplicate(true)}

func training12_consumer_scope(f: Dictionary, initial_hexes: Array) -> bool:
 var model=f.session.ledger.model
 var h=f.sim.hero
 if not check(f.session.status=="preparation" and f.sim.phase=="preparation" and model.state.phase=="safe" and int(model.state.level)==1 and not h.dead,"consumer fixture stays in original living Lv1 safe preparation"):return false
 if not check(model.state.inventory.is_empty() and model.state.selected_hex==initial_hexes and str(h.loadout.passive).is_empty() and h.cast_state.is_empty() and float(h.slow_left)==0.0,"actual initial fixture has unchanged Hex, no equipment, passive, cast or slow modifier"):return false
 for id: String in ["g02","g03","g04","g05","g07","g09","g10","g15","g19","g22","g24","g30"]:
  if not check(not f.sim.common.runtime.active(id),"no active original Common statmodifier "+id+" in this genuine initial fixture"):return false
 var b02: Dictionary=model.pursuit_buff_status()
 return check(not b02.equipped and not b02.active and float(b02.attack_speed_fraction)==0.0 and float(b02.move_fraction)==0.0 and not e03_view(f).equipped,"same source has no B02/E03 overlay while checking pure training attributes")

func training12_consumer_assert(sample: Dictionary, expected: Dictionary, immutable: Dictionary, label: String) -> void:
 check(sample.base==immutable,label+": original immutable actorbase remains exact")
 for stat: String in TRAINING12_CONSUMER_FIELDS:
  var field: String=TRAINING12_CONSUMER_FIELDS[stat]
  e03_near(float(sample.projected[field]),float(expected[field]),label+": actual projected_base_stats "+field)
  var final_value: float=float(expected[field])
  if field=="cdr":final_value=clampf(final_value,0.0,0.65)
  if field=="tenacity":final_value=clampf(final_value,0.0,1.0)
  e03_near(float(sample.stats[field]),final_value,label+": actual final hero.stats "+field)
 for field: String in ["ad","defence","attack_speed","move_speed","tenacity","lifesteal"]:
  var effective: float=float(expected[field])
  if field=="attack_speed":effective=clampf(effective,0.001,2.5)
  elif field=="move_speed":effective=maxf(0.0,effective)
  elif field=="tenacity":effective=clampf(effective,0.0,1.0)
  e03_near(float(sample.virtual[field]),effective,label+": real actor virtual attribute "+field)
 var crit: float=clampf(float(expected.crit_chance),0.0,1.0)
 e03_near(float(sample.virtual.effective_crit_probability),crit,label+": actual getter or original Ink probability clamp")
 var common_crit: float=crit if sample.uses_critical_chance_getter else float(expected.crit_chance)
 e03_near(float(sample.common_effective.crit_chance),common_crit,label+": Common respects concrete critical_chance interface availability")
 e03_near(float(sample.common_effective.ad),float(sample.virtual.ad),label+": Common consumes real AD interface")
 e03_near(float(sample.common_effective.move_speed),float(sample.virtual.move_speed),label+": Common consumes real movement attribute")

func training12_consumers() -> void:
 current_group="consumers"
 var f: Dictionary=funded_shop(current_group)
 if f.is_empty():return
 var model=f.session.ledger.model
 var initial_hexes: Array=model.state.selected_hex.duplicate(true)
 if not training12_consumer_scope(f,initial_hexes):dispose(f);return
 if not check(model.state.body.is_empty(),"consumer coverage starts with zero actual body selections"):dispose(f);return
 var source: Dictionary=ORIGINAL_INK_TUNING.hero_stats()
 var immutable: Dictionary=f.sim.hero.base_stats.duplicate(true)
 for stat: String in TRAINING12_CONSUMER_FIELDS:
  var field: String=TRAINING12_CONSUMER_FIELDS[stat]
  e03_near(float(immutable[field]),float(source[field]),"same original immutable Ink base "+field)
 # Initial static Hex additions are actual existing authority. Every later
 # training addition below comes solely from this gate's frozen 12 constants.
 var additions: Dictionary=model.aggregate_effects().stats.duplicate(true)
 var initial_additions: Dictionary=additions.duplicate(true)
 var seen: Dictionary={}
 var gold: int=model.state.gold
 var budget: int=floori(float(gold)/900.0)
 var attempts: int=0
 var samples: Array=[]
 for attempt: int in range(budget):
  if seen.size()==12:break
  if not training12_consumer_scope(f,initial_hexes):dispose(f);return
  var pending: Dictionary=training12_paid(f)
  if pending.is_empty():dispose(f);return
  var chosen: String=str(pending.candidates[0])
  for id: String in pending.candidates:
   if not seen.has(id):chosen=id;break
  var before: Dictionary=training12_consumer_sample(f)
  var expected_before: Dictionary=training12_consumer_expected(source,additions)
  training12_consumer_assert(before,expected_before,immutable,"before actual choice"+str(attempt+1))
  if not training12_choose(f,pending,chosen):dispose(f);return
  for stat: String in TRAINING12_VALUES[chosen]:additions[stat]=float(additions.get(stat,0.0))+float(TRAINING12_VALUES[chosen][stat])
  var expected_after: Dictionary=training12_consumer_expected(source,additions)
  var after: Dictionary=training12_consumer_sample(f)
  training12_consumer_assert(after,expected_after,immutable,"after actual "+chosen)
  for stat: String in TRAINING12_CONSUMER_FIELDS:
   var field: String=TRAINING12_CONSUMER_FIELDS[stat]
   e03_near(float(after.projected[field])-float(before.projected[field]),float(expected_after[field])-float(expected_before[field]),"real paidselection projected delta including original caps "+chosen+"/"+field)
   e03_near(float(after.stats[field])-float(before.stats[field]),float(expected_after[field])-float(expected_before[field]),"real paidselection final actor delta "+chosen+"/"+field)
  check(after.hp==before.hp and after.clock==before.clock,"safe pureattribute selection neither heals nor advances original combatclock")
  seen[chosen]=int(seen.get(chosen,0))+1
  attempts+=1
  samples.append({"purchase_id":pending.purchase_id,"offered":pending.candidates.duplicate(),"chosen":chosen,"expected_before":expected_before,"expected_after":expected_after,"before":before,"after":after})
 var missing: Array=[]
 for id: String in TRAINING12_VALUES:
  if not seen.has(id):missing.append(id)
 training12_records.append({"kind":"actual_training12_attribute_consumers","seen_counts":seen,"missing_ids":missing,"attempts":attempts,"budget_purchases":budget,"initial_gold":gold,"final_gold":model.state.gold,"initial_static_additions":initial_additions,"independent_accumulated_additions":additions,"immutable_source":source,"samples":samples,
  "oracle":"immutable Ink source plus actual initial static Hex additions plus independently accumulated formal increments; base-fraction AS/MS, original stored caps and effective critical probability",
  "actual_cap_boundary_hits_claimed":false,"combat_behavior_coverage_claimed":false,"native_GUI":false,"no_direct_actor_stats_rng_body_write":true})
 check(model.state.gold==gold-900*attempts,"all consumer selections use only original60000 wallet and fixed900 payments")
 var complete: bool=check(missing.is_empty() and seen.size()==12,"actual paid RNG offers and selects all12 within existing wallet; missing="+str(missing))
 b04_integrity(f,current_group);dispose(f)
 if complete:training12_done.append(current_group)

func training12_report() -> void:
 check(training12_done==training12_required,"all selected training12 source groups complete")
 var report: Dictionary={"suite":"formal_training12_original_source","passed":failures.is_empty() and training12_done==training12_required,"checks":checks,"failures":failures,"check_records":check_records,"partition":training12_partition,"required_groups":training12_required,"completed_groups":training12_done,"records":training12_records,"fixtures":training12_fixtures,"evidence":evidence,"e03_records":e03_records,"productionSession":true,"original_Host_factories":true,"wallet_fixture":true,"source_API_fixtures":true,"cap_boundaries_isolated_projection":true,"direct_HP_stats_rank_position_AI_generation_clock_rng_body_writes":false,"free_credit_authority_present":false,"G05_enabled":false,"natural_play":false,"native_GUI":false,"production_ready":false}
 var file: FileAccess=FileAccess.open(output_path,FileAccess.WRITE)
 if file==null:push_error("Cannot write training12 source result");quit(2);return
 file.store_string(JSON.stringify(report,"  "));var error: Error=file.get_error();file.close()
 print("TRAINING12_ORIGINAL_SOURCE ",JSON.stringify({"passed":report.passed,"checks":checks,"failures":failures,"result":output_path}))
 quit(2 if error!=OK else (0 if report.passed else 1))

func run() -> void:
 g03_reset_evidence()
 if TRAINING12_GROUPS[0] in training12_required:training12_definitions()
 if TRAINING12_GROUPS[1] in training12_required:training12_commerce()
 if TRAINING12_GROUPS[2] in training12_required:training12_caps()
 if TRAINING12_GROUPS[3] in training12_required:training12_guards_pending()
 if TRAINING12_GROUPS[4] in training12_required:training12_permanence_regen()
 if "panel_signals" in training12_required:training12_panel_signals()
 if "consumers" in training12_required:training12_consumers()
 await process_frame # Flush inherited signal-safe queue_free after fixtures are disposed.
 training12_report()
