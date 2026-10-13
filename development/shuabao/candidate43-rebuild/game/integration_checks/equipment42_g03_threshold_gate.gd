extends "res://integration_checks/equipment42_g02_threshold_regression_gate.gd"
## Independent original Bridge/Model/Sim source fixture. No Host or Session.
## High HP is declared only through original encounter/spawn arguments.
var g03_threshold_records: Array=[]
var g03_threshold_fixtures: Array=[]
var g03_threshold_done: bool=false
var g03_threshold_required: Array=["exact500_and_completed_once","roundoff_carry_commerce"]
var g03_threshold_completed: Array=[]
var g03_threshold_partition: String="all"

func _initialize() -> void:
 output_path="user://equipment42_g03_threshold_gate.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--equipment-result="):output_path=arg.trim_prefix("--equipment-result=")
  if arg.begins_with("--g03-threshold-group="):g03_threshold_partition=arg.trim_prefix("--g03-threshold-group=")
 if g03_threshold_partition!="all":
  if g03_threshold_partition not in g03_threshold_required:push_error("Unknown G03 threshold group");quit(2);return
  g03_threshold_required=[g03_threshold_partition]
 run.call_deferred()

func g03_value(model: RefCounted) -> Dictionary:
 return model._g03_state().duplicate(true)

func g03_saved(model: RefCounted) -> Dictionary:
 return {"task":g03_value(model),"ledger":model.state.shop_visit.taskLedger.get(str(model.state.actor_id)+"|final:G03",{}).duplicate(true),"awards":model.state.bonus_awards.duplicate(true),"completed":model.state.completed_equipment_tasks.duplicate(true),"bonus_sp":model.state.bonus_sp,"points":model.state.points}

func fresh(items: Array) -> Dictionary:
 var f: Dictionary=super.fresh(items)
 if f.is_empty():return {}
 f["g03_packets"]=[]
 check(f.sim.g03_model_is_bound(f.model) and f.model.equipment_runtime_status("final:G03").get("runtime_complete",false),"independent exact source G03 owner is formally bound")
 check(g03_value(f.model).progress==0.0 and not g03_value(f.model).completed,"independent fresh G03 starts at zero without state injection")
 return f

func observe(event: Dictionary, f: Dictionary) -> void:
 var record: Dictionary={}
 if event.get("kind")=="damage" and f.has("g03_packets"):
  var witness: Dictionary=f.sim.verify_g03_damage_attribution(f.model,event,f.run_id)
  var hp: float=float(f.sim.hero.hp)
  var max_hp: float=float(f.sim.hero.stats.max_hp)
  var before: Dictionary=g03_saved(f.model)
  var held: bool=false
  for entry: Dictionary in f.model.state.inventory:
   if entry.id=="final:G03" and int(entry.count)>0:held=true
  var delta: float=0.0
  if not witness.is_empty() and held and not f.synthetic and not before.task.completed and hp/max_hp<0.35:delta=float(event.amount)/max_hp
  record={"event":event.duplicate(true),"witness":witness,"synthetic":f.synthetic,"before":before,"owner_hp":hp,"owner_max_hp":max_hp,"held":held,"expected_ratio":delta,"productionSession":false}
 super.observe(event,f) # One original Model observer; no Session exists.
 if record.is_empty():return
 record["after"]=g03_saved(f.model)
 near(float(record.after.task.progress),minf(500.0,float(record.before.task.progress)+float(record.expected_ratio)),"isolated source adds independently observed ratio exactly once")
 if not record.witness.is_empty():
  near(float(record.witness.commit.owner_hp),float(record.owner_hp),"isolated witness seals actual ownerHP at source notification")
  near(float(record.witness.commit.owner_max_hp),float(record.owner_max_hp),"isolated witness seals actual ownermaxHP at source notification")
 if record.synthetic:check(record.witness.is_empty() and record.before==record.after,"standalone public copy cannot borrow a completed packet")
 f.g03_packets.append(record);g03_threshold_records.append(record)

func g03_true_packet(f: Dictionary, enemy: Dictionary, amount: float, label: String) -> Dictionary:
 var before: float=float(enemy.hp)
 var start: int=f.g03_packets.size()
 f.sim.damage_enemy(enemy,amount,"g03_threshold_"+label,0,true,false,{"fixture":true,"direct":false,"no_reactions":true,"snapshot_final":true,"generation":f.sim.encounter_generation,"room_id":f.sim.room_id})
 var matches: Array=[]
 for record: Dictionary in f.g03_packets.slice(start):
  if record.event.get("target")==enemy.actor_id and record.event.get("source")=="g03_threshold_"+label:matches.append(record)
 if not check(matches.size()==1 and not matches[0].witness.is_empty(),"one real highHP source packet has one current commit witness"):return {}
 var record: Dictionary=matches[0]
 near(float(record.event.amount),minf(before,amount),"source highHP actor loses capped actual requested damage")
 near(before-float(enemy.hp),float(record.event.amount),"independent target HP difference equals real emitted actual")
 g03_threshold_fixtures.append({"label":label,"api":"original damage_enemy","before_target_HP":before,"after_target_HP":enemy.hp,"requested":amount,"source_spawn_HP_fixture":true,"productionSession":false,"natural":false})
 return record

func g03_assert(f: Dictionary, progress: float, complete: bool, label: String) -> void:
 var saved: Dictionary=g03_saved(f.model)
 near(float(saved.task.progress),progress,label+": exact ratio")
 check(saved.task.completed==complete,label+": exact completion")
 check(int(saved.ledger.get("progress",0))==int(floor(progress)),label+": commerce diagnostic integer does not replace fractional state")
 check(saved.ledger.get("completed_stages",[])==(["task:G03:1"] if complete else []),label+": one authored completed stage")
 check(saved.ledger.get("permanent_rewards",{}).size()==(1 if complete else 0),label+": one original task permanent reward")
 check(saved.completed.has("final:G03")==complete and saved.awards.has("task:G03")==complete,label+": exact authored reward identities")
 check(saved.bonus_sp==(1 if complete else 0) and saved.points==f.baseline_points+(1 if complete else 0),label+": exact oneSP with no other fixture rewards")
 check(f.model.state.gold==f.baseline_gold and f.model.state.xp==f.baseline_xp,label+": separate source observer adds no Session goldXP")

func exact_ratio() -> void:
 current="exact500_and_completed_once"
 var f: Dictionary=fresh(["final:G03","final:G03"])
 if f.is_empty():return
 var max_hp: float=float(f.sim.hero.stats.max_hp)
 if not start_room(f,[{"kind":"minion","hp":max_hp*600.0}]):dispose(f);return
 var target: Dictionary=f.sim.enemies[0]
 var before_hp: float=float(f.sim.hero.hp)
 var intended: float=max_hp*0.25
 if before_hp<intended:f.sim.heal(intended-before_hp,false,{"fixture":true,"source":"g03_threshold_owner_setup"})
 else:f.sim.damage_hero(before_hp-intended+float(f.sim.hero.shield_total()),Vector3.ZERO,0.0,true,true,{"fixture":true,"source":"g03_threshold_owner_setup","direct":false})
 near(float(f.sim.hero.hp),intended,"original HP APIs establish a low owner without assigning HP")
 check(f.sim.ai_enabled and f.sim.auto_finish and not f.sim.paused,"isolated fixture retains original AI clocks and terminal behavior")
 var pieces: Array=[499.75,0.125,0.125]
 var expected: float=0.0
 var first_record: Dictionary={}
 for i: int in range(pieces.size()):
  var record: Dictionary=g03_true_packet(f,target,max_hp*float(pieces[i]),"piece%d"%i)
  if record.is_empty():dispose(f);return
  if i==0:first_record=record
  expected+=float(pieces[i])
  g03_assert(f,expected,i==2,"fractional source step%d"%i)
 var complete: Dictionary=g03_saved(f.model)
 if g03_true_packet(f,target,1.0,"after_complete").is_empty():dispose(f);return
 check(g03_saved(f.model)==complete,"additional real damage after completion cannot award again")
 var replay: Dictionary=f.model.record_battle_event(f.sim,first_record.event,f.run_id)
 check(g03_saved(f.model)==complete,"saved source event outside dynamic witness cannot replay ratio")
 f.synthetic=true;f.sim.emit_event("damage",first_record.event.duplicate(true));f.synthetic=false
 check(g03_saved(f.model)==complete,"fresh-sequence public copy after completion cannot mint reward")
 var receipts: Array=[]
 for id: String in f.model.receipts:
  var receipt: Dictionary=f.model.receipts[id]
  if receipt.request.action=="g03_verified_damage":receipts.append({"id":id,"request":receipt.request.duplicate(true)})
 check(receipts.size()==3,"three eligible real fractional packets have three original command receipts")
 for receipt: Dictionary in receipts:
  var returned: Dictionary=f.model.command(receipt.id,receipt.request.action,receipt.request.args)
  check(returned.get("accepted",false) and returned.get("replayed",false) and g03_saved(f.model)==complete,"successful command receipt is idempotent and adds noSP")
 if g03_true_packet(f,target,float(target.hp)+1000.0,"finish_original_actor").is_empty() or not end_room(f):dispose(f);return
 g03_assert(f,500.0,true,"after real original source terminal")
 if not check(commerce(f,"begin_visit",{"area":str(f.sim.room_id)+"/G03-completed-shop"},true).get("accepted",false),"original completed task shop visit") or not check(commerce(f,"open_ui").get("accepted",false),"original completed task shop opens"):dispose(f);return
 for _copy: int in range(2):
  var entry: Dictionary={}
  for item: Dictionary in f.model.state.inventory:
   if item.id=="final:G03":entry=item;break
  if not check(not entry.is_empty() and commerce(f,"sell",{"uid":entry.uid}).get("accepted",false),"original completed G03 sale"):dispose(f);return
  check(g03_saved(f.model)==complete,"sale preserves ratio completed stage and exactSP")
 if not check(commerce(f,"buy",{"item":"final:G03"}).get("accepted",false),"original completed G03 repurchase"):dispose(f);return
 check(g03_saved(f.model)==complete,"repurchase retains existing one-time reward")
 if not check(commerce(f,"undo").get("accepted",false),"original completed G03 purchase undo"):dispose(f);return
 check(g03_saved(f.model)==complete,"commerce undo never rewinds task completion")
 check(commerce(f,"close_ui").get("accepted",false),"completed task shop closes")
 evidence["g03_threshold"]={"pieces":pieces,"max_hp":max_hp,"completed":complete,"original_damage_replay":replay,"productionSession":false,"natural_first_floor_500":false,"task_progress_written":false}
 dispose(f);g03_threshold_done=true;g03_threshold_completed.append(current)

func roundoff_carry() -> void:
 current="roundoff_carry_commerce"
 var f: Dictionary=fresh(["final:G03"])
 if f.is_empty():return
 var max_hp: float=float(f.sim.hero.stats.max_hp)
 # These are exact ordinary equipment/hero values, not a changed stat fixture.
 if not check(max_hp==710.0,"one original G03 produces actual710maxHP for reproducible binary boundary"):dispose(f);return
 if not start_room(f,[{"kind":"minion","hp":426000.0},{"kind":"minion","hp":0.1}]):dispose(f);return
 f.sim.damage_hero(float(f.sim.hero.hp)-max_hp*0.25+float(f.sim.hero.shield_total()),Vector3.ZERO,0.0,true,true,{"fixture":true,"source":"g03_fractional_owner_setup","direct":false})
 var big: Dictionary=f.sim.enemies[0]
 var small: Dictionary=f.sim.enemies[1]
 var first: Dictionary=g03_true_packet(f,big,354999.99999999994,"below500_adjacent_float")
 if first.is_empty():dispose(f);return
 var ratio_first: float=float(first.event.amount)/max_hp
 if not check(ratio_first==499.99999999999994 and not g03_value(f.model).completed,"real first ratio is the representable value immediately below500"):dispose(f);return
 var tiny: Dictionary=g03_true_packet(f,small,max_hp*4e-14,"positive_tiny_on_low_HP_actor")
 if tiny.is_empty():dispose(f);return
 var ratio_tiny: float=float(tiny.event.amount)/max_hp
 check(float(tiny.witness.commit.target_hp_before)>float(tiny.witness.commit.target_hp_after),"tiny packet has genuine positive source HP loss on the lowHP target")
 check(ratio_tiny==4e-14 and ratio_first+ratio_tiny==500.0,"ordinary double addition would incorrectly round this still-below sum to500")
 var retained: Dictionary=g03_saved(f.model)
 check(float(retained.task.progress_carry)!=0.0 and 500.0-float(retained.task.progress)>float(retained.task.progress_carry) and not retained.task.completed,"compensated high value and remainder represent a strictly below-threshold sum")
 check(retained.bonus_sp==0 and retained.points==f.baseline_points and not retained.awards.has("task:G03") and retained.ledger.get("completed_stages",[]).is_empty(),"strictly insufficient real sum awards noSP or stage")
 # Finish the declared actors while highHP, so original source room closure
 # cannot contribute another low-health packet before checking commerce carry.
 f.sim.heal(max_hp,false,{"fixture":true,"source":"g03_carry_freeze_before_commerce"})
 for enemy: Dictionary in f.sim.living().duplicate():
  if g03_true_packet(f,enemy,float(enemy.hp)+1.0,"high_HP_close").is_empty():dispose(f);return
 if not end_room(f):dispose(f);return
 check(g03_saved(f.model)==retained,"healed room completion preserves exact progress and carry")
 if not check(commerce(f,"begin_visit",{"area":str(f.sim.room_id)+"/G03-carry-shop"},true).get("accepted",false),"original carry shop visit") or not check(commerce(f,"open_ui").get("accepted",false),"original carry shop opens"):dispose(f);return
 var uid: int=-1
 for entry: Dictionary in f.model.state.inventory:
  if entry.id=="final:G03":uid=int(entry.uid);break
 if not check(uid>=0 and commerce(f,"sell",{"uid":uid}).get("accepted",false),"sell subthreshold G03 through original commerce"):dispose(f);return
 check(g03_saved(f.model)==retained,"sell retains exact compensation carry")
 if not check(commerce(f,"undo").get("accepted",false),"undo subthreshold G03 sale"):dispose(f);return
 check(g03_saved(f.model)==retained,"undo cannot erase or round task carry")
 uid=-1
 for entry: Dictionary in f.model.state.inventory:
  if entry.id=="final:G03":uid=int(entry.uid);break
 if not check(commerce(f,"sell",{"uid":uid}).get("accepted",false),"repeat actual sale before repurchase") or not check(commerce(f,"buy",{"item":"final:G03"}).get("accepted",false),"original subthreshold G03 repurchase"):dispose(f);return
 check(g03_saved(f.model)==retained,"repurchase preserves exact compensation carry and noSP")
 if not check(commerce(f,"close_ui").get("accepted",false),"carry shop closes"):dispose(f);return
 if not start_room(f,[{"kind":"minion","hp":0.1}]):dispose(f);return
 f.sim.damage_hero(float(f.sim.hero.hp)-max_hp*0.25+float(f.sim.hero.shield_total()),Vector3.ZERO,0.0,true,true,{"fixture":true,"source":"g03_carried_owner_setup","direct":false})
 var third: Dictionary=g03_true_packet(f,f.sim.enemies[0],max_hp*2e-14,"real_carry_crossing")
 if third.is_empty():dispose(f);return
 check(float(third.witness.commit.target_hp_before)>float(third.witness.commit.target_hp_after),"final tiny source packet also has a positive actualHP difference")
 var completed: Dictionary=g03_saved(f.model)
 check(float(third.event.amount)/max_hp==2e-14 and completed.task.completed and completed.task.progress==500.0 and completed.task.progress_carry==0.0,"third genuine packet crosses strict exact sum and clears completion carry")
 check(completed.bonus_sp==1 and completed.points==f.baseline_points+1 and completed.awards.has("task:G03"),"carried real crossing grants exactly oneSP")
 evidence["g03_roundoff"]={"first":first,"tiny":tiny,"retained_through_commerce":retained,"third":third,"completed":completed,"requested_damage":[354999.99999999994,max_hp*4e-14,max_hp*2e-14],"target_HP_scales":[426000.0,0.1,0.1],"productionSession":false,"direct_progress_or_carry_write":false}
 dispose(f);g03_threshold_completed.append(current)

func run() -> void:
 if "exact500_and_completed_once" in g03_threshold_required:exact_ratio()
 if "roundoff_carry_commerce" in g03_threshold_required:roundoff_carry()
 check(g03_threshold_completed==g03_threshold_required,"independent original G03 threshold groups complete")
 var report: Dictionary={"suite":"equipment42_G03_independent_original_ratio_threshold","passed":failures.is_empty() and g03_threshold_completed==g03_threshold_required,"checks":checks,"failures":failures,"check_records":records,"partition":g03_threshold_partition,"required_groups":g03_threshold_required,"completed_groups":g03_threshold_completed,"evidence":evidence,"g03_packets":g03_threshold_records,"source_fixtures":g03_threshold_fixtures,"productionSession":false,"Host_created":false,"Session_created":false,"formal_original_binding":true,"source_spawn_HP_override_fixture":true,"natural":false,"natural_first_floor_500":false,"task_progress_HP_stats_written":false,"native_GUI":false,"production_ready":false}
 var file: FileAccess=FileAccess.open(output_path,FileAccess.WRITE)
 if file==null:push_error("Unable to write G03 independent threshold result");quit(2);return
 file.store_string(JSON.stringify(report,"  "));var error: Error=file.get_error();file.close()
 print("G03_EXACT_THRESHOLD ",JSON.stringify({"passed":report.passed,"checks":checks,"failures":failures,"result":output_path}))
 quit(2 if error!=OK else (0 if report.passed else 1))
