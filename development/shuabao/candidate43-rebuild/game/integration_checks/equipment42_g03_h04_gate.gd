extends "res://integration_checks/equipment42_h04_regression_gate.gd"
## Full original H04/B01 assertions are inherited. Only two real G03 purchases
## and original incoming/healing APIs establish the separate low-health task.
var g03_h04_packets: Array=[]
var g03_h04_setup: Array=[]
var g03_h04_source_log: Array=[]

func _initialize() -> void:
 output_path="user://equipment42_g03_h04_gate.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--equipment-result="):output_path=arg.trim_prefix("--equipment-result=")
 run.call_deferred()

func funded_shop(label: String) -> Dictionary:
 var f: Dictionary=super.funded_shop(label)
 if f.is_empty():return {}
 if not buy(f,"final:G03") or not buy(f,"final:G03"):dispose(f);return {}
 f.baseline=authority(f) # Actual paid G03 baseline precedes inherited B01 buys.
 f["g03_h04_holder"]=true
 check(f.sim.g03_model_is_bound(f.session.ledger.model),"H04 uses the same exact bound G03 Model")
 return f

func h04_place(f: Dictionary, point: Vector3, label: String) -> Dictionary:
 if label=="Q2 A":
  var maximum: float=float(f.sim.hero.stats.max_hp)
  f.sim.heal(maximum,false,{"fixture":true,"source":"g03_h04_owner_setup"})
  var before: float=float(f.sim.hero.hp)
  f.sim.damage_hero(before-maximum*0.25+float(f.sim.hero.shield_total()),Vector3.ZERO,0.0,true,true,{"fixture":true,"source":"g03_h04_owner_setup","direct":false})
  near_number(float(f.sim.hero.hp),maximum*0.25,"original HP consumers establish actual low-health H04 owner")
  g03_h04_setup.append({"before":before,"after":f.sim.hero.hp,"max_hp":maximum,"direct_HP_write":false})
 return super.h04_place(f,point,label)

func on_event(event: Dictionary, f: Dictionary) -> void:
 var record: Dictionary={}
 if f.get("g03_h04_holder",false) and event.get("kind")=="damage" and event.get("source")==H04_SOURCE:
  var model=f.session.ledger.model
  record={"event":event.duplicate(true),"witness":f.sim.verify_g03_damage_attribution(model,event,f.session.run_id),"before":model._g03_state(),"hp":f.sim.hero.hp,"max_hp":f.sim.hero.stats.max_hp,"original_roster":str(event.target) in f.session.expected_enemies}
 super.on_event(event,f)
 if record.is_empty():return
 record["after"]=f.session.ledger.model._g03_state()
 check(not record.witness.is_empty() and record.witness.witness.proof=="original_damage_hp_commit" and record.original_roster,"original H04 actual damage owns independent G03 HP commit")
 check(float(record.hp)/float(record.max_hp)<0.35,"actual H04 owner remains below35 at source commit")
 near_number(float(record.after.progress)-float(record.before.progress),float(event.amount)/float(record.max_hp),"H04 actual capped damage contributes once despite two held G03 copies")
 check(not record.after.completed,"original two H04 hits do not claim500 threshold")
 g03_h04_packets.append(record)

func dispose(f: Dictionary) -> void:
 if not f.is_empty() and f.get("g03_h04_holder",false) and is_instance_valid(f.sim):
  # Read the original source event log independently before inherited cleanup.
  # Nonlethal H04 damage is part of the task even when only two actors die.
  for event: Dictionary in f.sim.event_log:
   if event.get("kind")=="damage" and event.get("source")==H04_SOURCE and float(event.get("amount",0.0))>0.0:g03_h04_source_log.append(event.duplicate(true))
 super.dispose(f)

func finish() -> void:
 check(h04_completed==H04_GROUPS,"all original H04 source groups and assertions retained")
 check(evidence.get("h04_kills",[]).size()==2 and evidence.get("refunds",[]).size()==1,"original H04 retains exactly two kills and one same-cast B01 refund")
 var observed: Dictionary={}
 var nonlethal: int=0
 for packet: Dictionary in g03_h04_packets:
  var sequence: int=int(packet.event.sequence)
  check(not observed.has(sequence),"each G03 H04 sequence appears exactly once")
  observed[sequence]=packet.event
  if float(packet.witness.get("commit",{}).get("target_hp_after",-1.0))>0.0:nonlethal+=1
 var source_sequences: Dictionary={}
 var exact_bijection: bool=g03_h04_source_log.size()==g03_h04_packets.size()
 for event: Dictionary in g03_h04_source_log:
  var sequence: int=int(event.sequence)
  if source_sequences.has(sequence) or not observed.has(sequence) or observed[sequence]!=event:exact_bijection=false
  source_sequences[sequence]=true
 check(exact_bijection and not g03_h04_source_log.is_empty(),"every positive original H04 source-log damage matches one exact G03 event/sequence")
 check(nonlethal>0,"G03 also counts the actual nonlethal H04 packet alongside original lethal packets")
 check(check_records.size()==checks,"each inherited H04 assertion remains accounted")
 var report: Dictionary={"suite":"equipment42_G03_original_Q2_H04_with_B01","passed":failures.is_empty() and h04_completed==H04_GROUPS and exact_bijection and nonlethal>0,"checks":checks,"failures":failures,"check_records":check_records,"required_groups":H04_GROUPS,"completed_groups":h04_completed,"evidence":evidence,"g03_H04_packets":g03_h04_packets,"original_positive_H04_damage_log":g03_h04_source_log,"nonlethal_H04_damage_packets":nonlethal,"original_HP_setup":g03_h04_setup,"productionSession":true,"actual_Q2_H04_input":true,"all_prior_H04_assertions_inherited":true,"default_seed_original_Hex_commands":true,"wallet_fixture":true,"extra_actors":false,"task_progress_HP_rank_Hex_position_written":false,"native_GUI":false,"natural_play":false,"threshold500_tested_here":false,"production_ready":false}
 var file: FileAccess=FileAccess.open(output_path,FileAccess.WRITE)
 if file==null:push_error("Cannot write G03 H04 result");quit(2);return
 file.store_string(JSON.stringify(report,"  "));var error: Error=file.get_error();file.close()
 print("G03_ORIGINAL_H04 ",JSON.stringify({"passed":report.passed,"checks":checks,"failures":failures,"result":output_path}))
 quit(2 if error!=OK else (0 if report.passed else 1))
