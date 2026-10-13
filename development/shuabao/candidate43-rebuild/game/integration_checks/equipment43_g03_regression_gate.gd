extends "res://integration_checks/equipment43_g02_regression_gate.gd"
## Exact original Host/Session. Test-only wallet and original source APIs are
## declared; no direct HP/progress/stat/rank/position/AI assignments.
const G03_ITEM := "final:G03"
const G03Prior = preload("res://equipment_lifeline_20261009/adapter.gd")
const G03_GROUPS := ["definitions_commerce", "strict_threshold_lifesteal"]
var g03_required: Array = G03_GROUPS.duplicate()
var g03_completed: Array = []
var g03_partition: String = "all"
var g03_records: Array = []
var g03_fixtures: Array = []

func _initialize() -> void:
 output_path = "user://equipment42_source_gate.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--equipment-result="): output_path = arg.trim_prefix("--equipment-result=")
  if arg.begins_with("--g03-source-group="): g03_partition = arg.trim_prefix("--g03-source-group=")
 if g03_partition != "all":
  if g03_partition not in G03_GROUPS: push_error("Unknown G03 source group");quit(2);return
  g03_required = [g03_partition]
 run.call_deferred()

func funded_shop(label: String) -> Dictionary:
 var f: Dictionary = super.funded_shop(label)
 if f.is_empty(): return {}
 f["g03_damage"] = []
 f["g03_synthetic"] = false
 f["g03_before_model"] = {}
 if not check(f.sim.g03_model_is_bound(f.session.ledger.model) and f.session.ledger.model.equipment_runtime_status(G03_ITEM).get("runtime_complete",false),"G03 original source binds the exact same Model"):
  dispose(f);return {}
 return f

func g03_state(f: Dictionary) -> Dictionary:
 return f.session.ledger.model._g03_state().duplicate(true)

func g03_protected(f: Dictionary) -> Dictionary:
 var model = f.session.ledger.model
 return {"task":g03_state(f),"ledger":model.state.shop_visit.taskLedger.get(str(model.state.actor_id)+"|"+G03_ITEM,{}).duplicate(true),"completed":model.state.completed_equipment_tasks.duplicate(true),"awards":model.state.bonus_awards.duplicate(true),"bonus_sp":model.state.bonus_sp}

func g03_receipts(f: Dictionary) -> Array:
 var found: Array = []
 for id: String in f.session.ledger.model.receipts:
  var receipt: Dictionary = f.session.ledger.model.receipts[id]
  if receipt.request.action == "g03_verified_damage" and receipt.result.get("accepted",false): found.append({"id":id,"request":receipt.request.duplicate(true),"result":receipt.result.duplicate(true)})
 return found

func g03_near(actual: float, expected: float, label: String) -> bool:
 return check(is_finite(actual) and absf(actual-expected)<=0.000000001,label+" actual="+str(actual)+" expected="+str(expected))

func on_event(event: Dictionary, f: Dictionary) -> void:
 var record: Dictionary = {}
 if f.has("g03_damage") and event.get("kind")=="damage":
  var target: Dictionary = f.sim.enemy_by_id(str(event.get("target","")))
  var witness: Dictionary = f.sim.verify_g03_damage_attribution(f.session.ledger.model,event,f.session.run_id)
  var hp: float = float(f.sim.hero.hp)
  var max_hp: float = float(f.sim.hero.stats.max_hp)
  record = {"event":event.duplicate(true),"witness":witness,"owner_hp_first_observer":hp,"owner_max_hp_first_observer":max_hp,"target_hp_first_observer":target.get("hp",-1.0),"rank":target.get("rank_category",""),"original_roster":str(event.get("target","")) in f.session.expected_enemies,"synthetic":f.g03_synthetic,"held":owned_count(f,G03_ITEM)>0,"before_callbacks":g03_protected(f),"G06_before":g06_task(f),"expected_increment":0.0}
  if not witness.is_empty():
   check(record.original_roster,"every authentic G03 source packet targets an original admitted actor")
   g03_near(float(witness.commit.owner_hp),hp,"source seals original owner HP before any outward observer")
   g03_near(float(witness.commit.owner_max_hp),max_hp,"source seals current final maxHP at commit")
   g03_near(float(witness.commit.target_hp_after),float(target.hp),"original target HP commit already exists at first observer")
   g03_near(float(witness.commit.amount),float(event.amount),"source witness retains actual emitted damage")
   if record.held and not record.synthetic and hp/max_hp<0.35 and not record.before_callbacks.task.completed:
    record.expected_increment=float(event.amount)/max_hp
  g03_before_submission(event,f,record)
  record["before_submission"]=g03_protected(f)
 super.on_event(event,f) # Exactly one inherited original Session submission.
 if record.is_empty(): return
 record["after"]=g03_protected(f)
 var expected: float = minf(500.0,float(record.before_submission.task.progress)+float(record.expected_increment))
 g03_near(float(record.after.task.progress),expected,"original Session adds exactly one independently sampled packet ratio")
 if expected<500.0:check(record.after.bonus_sp==record.before_submission.bonus_sp,"subthreshold damage grants no G03 SP")
 if record.synthetic:check(record.witness.is_empty() and record.after==record.before_submission,"public copied damage cannot borrow a live outer source witness")
 f.g03_damage.append(record);g03_records.append(record)

func g03_before_submission(_event: Dictionary, _f: Dictionary, _record: Dictionary) -> void:
 pass # Additional exact-source gates override only this test observer hook.

func g03_damage_to(f: Dictionary, remaining: float, label: String) -> bool:
 var before: float = float(f.sim.hero.hp)
 var shields: float = float(f.sim.hero.shield_total())
 if not check(remaining>0.0 and remaining<=before,"source incoming fixture has positive attainable remaining HP: "+label):return false
 if remaining<before:
  f.sim.damage_hero(before-remaining+shields,Vector3.ZERO,0.0,true,true,{"source":"equipment42_incoming_fixture","fixture":true,"purpose":label,"direct":false,"generation":f.sim.encounter_generation,"room_id":f.sim.room_id})
 g03_fixtures.append({"API":"original damage_hero mandatory true","label":label,"before":before,"after":f.sim.hero.hp,"requested_remaining":remaining,"shield_before":shields,"direct_HP_write":false})
 return g03_near(float(f.sim.hero.hp),remaining,label+": exact original HP commit")

func g03_heal_full(f: Dictionary, label: String) -> void:
 var before: float = float(f.sim.hero.hp)
 var actual: float = f.sim.heal(float(f.sim.hero.stats.max_hp),false,{"source":"equipment42_heal_fixture","fixture":true,"purpose":label})
 g03_fixtures.append({"API":"original heal","label":label,"before":before,"after":f.sim.hero.hp,"actual":actual,"direct_HP_write":false})
 g03_near(float(f.sim.hero.hp),float(f.sim.hero.stats.max_hp),label+": original heal fills current maxHP")

func g03_packet(f: Dictionary, enemy: Dictionary, amount: float, label: String) -> Dictionary:
 if not check(not enemy.is_empty() and not enemy.dead and str(enemy.actor_id) in f.session.expected_enemies,"source packet uses live original roster actor"):return {}
 var hp: float = float(enemy.hp)
 var first: int = f.g03_damage.size()
 f.sim.damage_enemy(enemy,amount,"equipment42_"+label,0,true,false,{"fixture":true,"direct":false,"no_reactions":true,"snapshot_final":true,"generation":f.sim.encounter_generation,"room_id":f.sim.room_id})
 var records: Array = []
 for row: Dictionary in f.g03_damage.slice(first):
  if row.event.get("target")==enemy.actor_id and row.event.get("source")=="equipment42_"+label:records.append(row)
 if not check(records.size()==1,"one original source API packet has one actual damage notification"):return {}
 var record: Dictionary = records[0]
 g03_near(float(record.event.amount),minf(hp,maxf(0.0,amount)),"true snapshot source packet amount equals capped actual HP loss")
 g03_near(hp-float(enemy.hp),float(record.event.amount),"source packet independently changes target HP by actual amount")
 if amount>0.0:check(not record.witness.is_empty(),"positive source API packet has live G03 commit witness")
 g03_fixtures.append({"API":"original damage_enemy cast0 true snapshot_final no_reactions","label":label,"nominal":amount,"target":enemy.actor_id,"before_hp":hp,"after_hp":enemy.hp,"actual":record.event.amount,"actual_skill_input":false})
 return record

func g03_start(label: String, copies: int=1) -> Dictionary:
 var f: Dictionary = funded_shop(label)
 if f.is_empty():return {}
 for _copy: int in range(copies):
  if not buy(f,G03_ITEM):dispose(f);return {}
 if not check(f.session.close_panel().get("accepted",false),"G03 original shop closes") or not enter(f,1) or not spawn_ready(f):dispose(f);return {}
 return f

func g03_stats(f: Dictionary, copies: int) -> void:
 var current: Dictionary = authority(f)
 for row: Array in [["AD","ad",40.0],["max_hp","max_hp",350.0],["lifesteal","lifesteal",0.06]]:
  g03_near(float(current.equipment.stats.get(row[0],0.0))-float(f.baseline.equipment.stats.get(row[0],0.0)),float(row[2])*copies,"each G03 static attribute copy "+str(row[0]))
  g03_near(float(current.current_sim_stats[row[1]])-float(f.baseline.current_sim_stats[row[1]]),float(row[2])*copies,"original source stat consumer "+str(row[1]))
 check(owned_count(f,G03_ITEM)==copies,"original commerce owns exact G03 copies")

func g03_definitions() -> void:
 current_group=G03_GROUPS[0]
 var f: Dictionary=funded_shop(current_group)
 if f.is_empty():return
 var model=f.session.ledger.model
 var prior: Dictionary=G03Prior.build(JSON.parse_string(FileAccess.get_file_as_string(B01_NUMERIC)))
 if not check(prior.get("accepted",false),"original D04 adapter accepts original numeric source"):dispose(f);return
 check(model.runtime_stat_definitions.size()==prior.definitions.size()+2,"G03 E03 add exactly two definitions to original41")
 for id: String in prior.definitions:check(var_to_bytes(prior.definitions[id])==var_to_bytes(model.runtime_stat_definitions.get(id,{})),"prior41 definition byte-equivalent "+id)
 var count: int=0
 for definition: Dictionary in model.runtime_stat_definitions.values():
  if definition.get("supported",false):count+=1
 var status: Dictionary=model.equipment_runtime_status(G03_ITEM)
 check(count==43 and model.snapshot().content_profile=="ordinary_equipment43_potions3","truthful43 equipment catalog")
 check(status.stats=={"AD":40.0,"max_hp":350.0,"lifesteal":0.06} and status.passives.is_empty() and status.actives.is_empty(),"original G03 attributes and task-only effect")
 check(status.taskG03=={"threshold":500.0,"health_threshold":35.0,"stage_id":"task:G03:1","reward_skill_points":1},"original35percent and500multiples once1SP")
 check(status.commerce.price==2800 and status.commerce.component_total==2300 and status.commerce.combine_fee==500,"original2800 price and500 recipe fee")
 var saved: Dictionary=g03_protected(f)
 var hp: float=f.sim.hero.hp
 var gold: int=model.state.gold
 if not buy(f,G03_ITEM):dispose(f);return
 check(model.state.gold==gold-2800 and f.sim.hero.hp==hp,"purchase pays2800 and maxHP addition does not heal")
 g03_stats(f,1);buy(f,G03_ITEM);g03_stats(f,2)
 sell(f,G03_ITEM);g03_stats(f,1);undo(f);g03_stats(f,2)
 undo(f);undo(f);g03_stats(f,0)
 buy(f,"intermediate:I06");buy(f,"intermediate:I07")
 gold=model.state.gold
 var crafted: Dictionary=shop_command(f,"craft",{"item":G03_ITEM})
 check(crafted.get("accepted",false) and model.state.gold==gold-500 and owned_count(f,G03_ITEM)==1 and owned_count(f,"intermediate:I06")==0 and owned_count(f,"intermediate:I07")==0,"original I06+I07 craft consumes exact components and500")
 undo(f)
 check(owned_count(f,G03_ITEM)==0 and owned_count(f,"intermediate:I06")==1 and owned_count(f,"intermediate:I07")==1,"original craft undo restores both components")
 var denied: Dictionary=command(f,"g03_verified_damage",{"progress":500.0,"owner_hp":1.0,"owner_max_hp":100.0})
 check(not denied.get("accepted",false) and g03_protected(f)==saved,"public task command cannot mint progress orSP")
 b04_integrity(f,current_group);dispose(f);g03_completed.append(current_group)

func g03_threshold_lifesteal() -> void:
 current_group=G03_GROUPS[1]
 var f: Dictionary=g03_start(current_group,2)
 if f.is_empty():return
 var target: Dictionary=g02_nearest(f)
 if not check(not target.is_empty(),"original entered target exists"):dispose(f);return
 g03_heal_full(f,"strict boundary setup")
 var max_hp: float=f.sim.hero.stats.max_hp
 var threshold: float=max_hp*0.35
 if not g03_damage_to(f,threshold,"exact35percent"):dispose(f);return
 var equal: Dictionary=g03_packet(f,target,1.0,"equal35")
 if equal.is_empty():dispose(f);return
 check(equal.expected_increment==0.0 and g03_state(f).progress==0.0,"exactly35percent does not advance task")
 if not g03_damage_to(f,threshold-1.0,"strictly below35percent"):dispose(f);return
 var lower: Dictionary=g03_packet(f,target,1.0,"below35")
 if lower.is_empty():dispose(f);return
 g03_near(float(g03_state(f).progress),1.0/max_hp,"two G03 copies count one actual packet ratio")
 var retained: float=g03_state(f).progress
 g03_heal_full(f,"healing pauses existing task")
 var paused_packet: Dictionary=g03_packet(f,target,1.0,"healed")
 if paused_packet.is_empty():dispose(f);return
 g03_near(float(g03_state(f).progress),retained,"healed above35percent retains progress but adds none")
 var zero: Dictionary=g03_packet(f,target,0.0,"zero")
 if zero.is_empty():dispose(f);return
 check(zero.witness.is_empty() and g03_state(f).progress==retained,"zero effective damage has no source witness or progress")
 # Original movement approaches a contact distance; all positioning stays on
 # the input/source route. Arm after moving so timing/AI cannot alter setup.
 if not b04_approach(f,target,float(target.radius)*0.85) or not b04_ready(f):dispose(f);return
 g03_heal_full(f,"actual basic lifesteal crossing")
 if not g03_damage_to(f,float(f.sim.hero.stats.max_hp)*0.35-0.01,"just below35 before real basic"):dispose(f);return
 var first: int=f.g03_damage.size()
 var basic: Dictionary=b04_launch(f,target.position)
 if basic.is_empty():dispose(f);return
 for _tick: int in range(180):
  var found: bool=false
  for row: Dictionary in f.g03_damage.slice(first):
   if row.event.get("source")=="attack" and row.event.get("cast_id")==basic.cast_id:found=true;break
  if found:break
  step(f)
 var hits: Array=[]
 for row: Dictionary in f.g03_damage.slice(first):
  if row.event.get("source")=="attack" and row.event.get("cast_id")==basic.cast_id:hits.append(row)
 if not check(not hits.is_empty() and not hits[0].witness.is_empty(),"actual LMB creates real original basic damage"):dispose(f);return
 var hit: Dictionary=hits[0]
 check(float(hit.owner_hp_first_observer)/float(hit.owner_max_hp_first_observer)<0.35 and float(hit.expected_increment)>0.0,"basic damage uses below35 commit snapshot before its own lifesteal")
 check(float(f.sim.hero.hp)/float(f.sim.hero.stats.max_hp)>=0.35,"same original basic lifesteal crosses owner above35")
 var after_basic: float=g03_state(f).progress
 var next_target: Dictionary=g02_nearest(f)
 if not check(not next_target.is_empty(),"another original enemy remains for above-threshold followup"):dispose(f);return
 var next: Dictionary=g03_packet(f,next_target,1.0,"after_lifesteal")
 if next.is_empty():dispose(f);return
 g03_near(float(g03_state(f).progress),after_basic,"next packet samples healed owner and does not count")
 var protected: Dictionary=g03_protected(f)
 f.g03_synthetic=true;f.sim.emit_event("damage",hit.event.duplicate(true));f.g03_synthetic=false
 check(g03_protected(f)==protected,"historical genuine basic notification cannot create new ratio")
 var replay: Dictionary=f.session.observe_event(f.sim,hit.event)
 check(replay.get("accepted",false) and g03_protected(f)==protected,"original Session historical replay remains idempotent")
 b04_integrity(f,current_group);dispose(f);g03_completed.append(current_group)

func g03_report(suite: String) -> void:
 check(g03_completed==g03_required,"all selected G03 original source groups completed")
 var report: Dictionary={"suite":suite,"passed":failures.is_empty() and g03_completed==g03_required,"checks":checks,"failures":failures,"check_records":check_records,"partition":g03_partition,"required_groups":g03_required,"completed_groups":g03_completed,"evidence":evidence,"g03_packets":g03_records,"fixtures":g03_fixtures,"productionSession":true,"original_Host_factories":true,"extra_actors":false,"source_API_fixtures":true,"wallet_fixture":true,"direct_HP_progress_stats_CD_rank_position_AI_writes":false,"natural_play":false,"native_GUI":false,"production_ready":false}
 var file: FileAccess=FileAccess.open(output_path,FileAccess.WRITE)
 if file==null:push_error("Cannot write G03 source result");quit(2);return
 file.store_string(JSON.stringify(report,"  "));var error: Error=file.get_error();file.close()
 print("G03_ORIGINAL_SOURCE ",JSON.stringify({"passed":report.passed,"checks":checks,"failures":failures,"result":output_path}))
 quit(2 if error!=OK else (0 if report.passed else 1))

func g03_reset_evidence() -> void:
 evidence={"wallet_fixtures":[],"inputs":[],"cooldown_fixtures":[],"completions":[],"aborts":[],"victory":[],"postcompletion":[],"lifecycle":[],"isolated_common":[],"movement":[],"g02_deaths":[],"pre_damage":[],"inputs_g02":[],"p1_g02":{},"route_g02":{},"extra_actor_g02":{}}

func run() -> void:
 g03_reset_evidence()
 if G03_GROUPS[0] in g03_required:g03_definitions()
 if G03_GROUPS[1] in g03_required:g03_threshold_lifesteal()
 g03_report("equipment42_G03_original_commerce_and_commit_health")
