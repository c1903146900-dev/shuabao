extends "res://integration_checks/equipment42_source_gate.gd"
## Exact admitted Sim; no outgoing-hook subclass or Binding relaxation.
const REENTRY_GROUPS := ["history_same_payload_first_observer","owner_heal_after_commit","three_core_packets_and_public_copy"]
var reentry_required: Array=REENTRY_GROUPS.duplicate()
var reentry_completed: Array=[]
var reentry_partition: String="all"
var reentry_evidence: Array=[]

func _initialize() -> void:
 output_path="user://equipment42_g03_reentry_gate.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--equipment-result="):output_path=arg.trim_prefix("--equipment-result=")
  if arg.begins_with("--g03-reentry-group="):reentry_partition=arg.trim_prefix("--g03-reentry-group=")
 if reentry_partition!="all":
  if reentry_partition not in REENTRY_GROUPS:push_error("Unknown G03 reentry group");quit(2);return
  reentry_required=[reentry_partition]
 run.call_deferred()

func on_event(event: Dictionary,f: Dictionary) -> void:
 # Deliberately BEFORE the parent observer's first verify(current). Otherwise
 # the old free-sequence verifier bug would already be hidden by our own read.
 if f.get("g03_history_armed",false) and event.get("kind")=="damage" and event.get("source")=="equipment42_identical_payload":
  f.g03_history_armed=false
  var old: Dictionary=f.g03_history
  var current_payload: Dictionary=event.duplicate(true)
  var old_payload: Dictionary=old.duplicate(true)
  current_payload.erase("sequence");old_payload.erase("sequence")
  check(current_payload==old_payload and event.sequence!=old.sequence,"real old/new source notifications have identical payload except distinct sequence")
  var before: Dictionary=g03_protected(f)
  var result: Dictionary=f.session.observe_event(f.sim,old)
  f["g03_history_attempt"]={"before":before,"after":g03_protected(f),"old":old,"current":event.duplicate(true),"result":result.duplicate(true),"before_first_current_verifier":true}
  check(result.get("accepted",false) and g03_protected(f)==before,"earlier observer cannot attach an unclaimed historical payload to this new damage commit")
 super.on_event(event,f) # Exactly one original submission for current event.

func g03_before_submission(event: Dictionary,f: Dictionary,record: Dictionary) -> void:
 if f.get("g03_heal_armed",false) and event.get("source")=="equipment42_snapshot_heal":
  f.g03_heal_armed=false
  f.sim.heal(float(f.sim.hero.stats.max_hp),false,{"fixture":true,"source":"g03_early_observer_heal"})
  check(float(f.sim.hero.hp)/float(f.sim.hero.stats.max_hp)>=0.35 and float(record.owner_hp_first_observer)/float(record.owner_max_hp_first_observer)<0.35,"earlier callback moves current ownerHP above threshold after the committed lowHP packet")
 if not f.has("g03_nested_plan") or f.g03_synthetic:return
 var plan: Dictionary=f.g03_nested_plan
 if event.get("source")=="g03_three_outer" and not plan.outer:
  plan.outer=true
  var before: Dictionary=g03_protected(f)
  f.g03_synthetic=true;f.sim.emit_event("damage",event.duplicate(true));f.g03_synthetic=false
  check(g03_protected(f)==before,"same-stack public damage copy cannot consume or imitate outer commit")
  f.sim.damage_enemy(plan.target,2.0,"g03_three_middle",0,true,false,{"fixture":true,"direct":false,"no_reactions":true,"snapshot_final":true,"generation":f.sim.encounter_generation,"room_id":f.sim.room_id})
 elif event.get("source")=="g03_three_middle" and not plan.middle:
  plan.middle=true
  f.sim.damage_enemy(plan.target,4.0,"g03_three_inner",0,true,false,{"fixture":true,"direct":false,"no_reactions":true,"snapshot_final":true,"generation":f.sim.encounter_generation,"room_id":f.sim.room_id})

func run_reentry(mode: String) -> void:
 current_group=mode
 var f: Dictionary=g03_start(mode,2)
 if f.is_empty():return
 var target: Dictionary=g02_nearest(f)
 if not check(not target.is_empty() and float(target.hp)>10.0,"original live target can take nested nonlethal source packets"):dispose(f);return
 g03_heal_full(f,"reentry original owner setup")
 if mode=="history_same_payload_first_observer":
  var historical: Dictionary=g03_packet(f,target,1.0,"identical_payload")
  if historical.is_empty():dispose(f);return
  check(historical.expected_increment==0.0 and g03_receipts(f).is_empty(),"old identical payload was genuine but unclaimed because owner was highHP")
  if not g03_damage_to(f,float(f.sim.hero.stats.max_hp)*0.25,"same-payload new lowHP commit"):dispose(f);return
  f["g03_history"]=historical.event.duplicate(true);f["g03_history_armed"]=true
  var before: Dictionary=g03_protected(f)
  var current: Dictionary=g03_packet(f,target,1.0,"identical_payload")
  if current.is_empty():dispose(f);return
  check(not f.g03_history_armed and not current.witness.is_empty() and g03_receipts(f).size()==1,"genuine newer packet survives the older-payload theft attempt and gets exactly one claim")
  g03_near(float(g03_state(f).progress)-float(before.task.progress),1.0/float(current.owner_max_hp_first_observer),"only the new real lowHP commit contributes")
  reentry_evidence.append({"mode":mode,"attempt":f.g03_history_attempt,"genuine_new":current})
 elif mode=="owner_heal_after_commit":
  if not g03_damage_to(f,float(f.sim.hero.stats.max_hp)*0.25,"lowHP before observer heal"):dispose(f);return
  f["g03_heal_armed"]=true
  var before: Dictionary=g03_protected(f)
  var current: Dictionary=g03_packet(f,target,1.0,"snapshot_heal")
  if current.is_empty():dispose(f);return
  check(not f.g03_heal_armed and current.after.task.progress>before.task.progress,"Model uses original lowHP snapshot even after earlier observer healed above35")
  var stopped: float=g03_state(f).progress
  if g03_packet(f,target,1.0,"next_after_observer_heal").is_empty():dispose(f);return
  g03_near(float(g03_state(f).progress),stopped,"next genuine packet samples newly healed owner and pauses")
  reentry_evidence.append({"mode":mode,"record":current,"after_next":g03_protected(f)})
 else:
  if not g03_damage_to(f,float(f.sim.hero.stats.max_hp)*0.25,"three-level original damage setup"):dispose(f);return
  f["g03_nested_plan"]={"outer":false,"middle":false,"target":target}
  var before: Dictionary=g03_protected(f)
  var before_hp: float=float(target.hp)
  var first: int=f.g03_damage.size()
  f.sim.damage_enemy(target,1.0,"g03_three_outer",0,true,false,{"fixture":true,"direct":false,"no_reactions":true,"snapshot_final":true,"generation":f.sim.encounter_generation,"room_id":f.sim.room_id})
  var real: Array=[]
  for record: Dictionary in f.g03_damage.slice(first):
   if not record.synthetic and record.event.get("source") in ["g03_three_outer","g03_three_middle","g03_three_inner"]:real.append(record)
  if not check(real.size()==3 and f.g03_nested_plan.outer and f.g03_nested_plan.middle,"all three original same-target nested source calls occur"):dispose(f);return
  check(real[0].event.source=="g03_three_inner" and real[1].event.source=="g03_three_middle" and real[2].event.source=="g03_three_outer","actual Model arrivals reverse the original nested source sequence")
  check(real[0].event.sequence>real[1].event.sequence and real[1].event.sequence>real[2].event.sequence,"decreasing sequence order cannot discard legitimate older parents")
  g03_near(before_hp-float(target.hp),7.0,"three original packets remove exactly1+2+4 targetHP")
  g03_near(float(g03_state(f).progress)-float(before.task.progress),7.0/float(f.sim.hero.stats.max_hp),"each authentic same-target packet contributes once without counting nested loss twice")
  check(g03_receipts(f).size()==3,"three original packets yield three distinct claims despite counterfeit copy")
  reentry_evidence.append({"mode":mode,"records":real,"before":before,"after":g03_protected(f),"original_target_HP_before":before_hp,"original_target_HP_after":target.hp})
 b04_integrity(f,mode);dispose(f);reentry_completed.append(mode)

func run() -> void:
 g03_reset_evidence()
 for mode: String in reentry_required:run_reentry(mode)
 g03_required=reentry_required.duplicate();g03_completed=reentry_completed.duplicate();g03_partition=reentry_partition
 evidence["g03_reentry"]=reentry_evidence
 g03_report("equipment42_G03_original_early_observer_and_nested_source")
