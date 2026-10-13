extends "res://integration_checks/equipment42_source_gate.gd"
## Real Q1/P1 roots in the original Session. Nested calls use original source
## step/damage APIs while the genuine notification remains on its stack.
const G03_P1_GROUPS := ["p1_nonlethal","p1_lethal","core_p1_core_nested"]
var g03_p1_required: Array=G03_P1_GROUPS.duplicate()
var g03_p1_completed: Array=[]
var g03_p1_partition: String="all"
var g03_p1_evidence: Array=[]

func _initialize() -> void:
 output_path="user://equipment42_g03_p1_gate.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--equipment-result="):output_path=arg.trim_prefix("--equipment-result=")
  if arg.begins_with("--g03-p1-group="):g03_p1_partition=arg.trim_prefix("--g03-p1-group=")
 if g03_p1_partition!="all":
  if g03_p1_partition not in G03_P1_GROUPS:push_error("Unknown G03 P1 group");quit(2);return
  g03_p1_required=[g03_p1_partition]
 run.call_deferred()

func g03_before_submission(event: Dictionary,f: Dictionary,record: Dictionary) -> void:
 # The parent observer still submits explicit counterfeit events to Session
 # and checks their empty witness/state invariance. Only genuine P1 callbacks
 # may run this positive atomic-receipt assertion or create nested fixtures.
 if f.get("g03_synthetic",false) or not f.has("g03_p1_mode"):return
 if f.g03_p1_mode=="core_p1_core_nested" and f.get("g03_outer_armed",false) and event.get("source")=="equipment42_outer_pending_p1":
  f.g03_outer_armed=false
  f["g03_outer_sequence"]=event.sequence
  # Original pending Q1 reaches its own terminal during this ordinary source
  # step. No collector.complete or fake terminal event is called by the gate.
  for _tick: int in range(140):
   if f.get("g03_p1_nested_seen",false):break
   f.sim.step(f.sim.FIXED_TICK)
  check(f.get("g03_p1_nested_seen",false),"original pending Q1 terminal pays P1 inside outer core notification")
 if event.get("source")!="yanguizhou_p1":return
 f["g03_p1_notified"]=true
 var target: Dictionary=f.sim.enemy_by_id(str(event.target))
 var receipts: Array=g06_p1_receipts(f,int(event.cast_id))
 check(receipts.size()==1 and not record.witness.is_empty() and record.witness.witness.proof=="original_p1_atomic_hp_commit","original nonlethal or lethal P1 has independent atomic HP witness")
 f["g03_p1_receipt"]=receipts[0].duplicate(true) if receipts.size()==1 else {}
 if f.g03_p1_mode=="core_p1_core_nested":
  f["g03_p1_nested_seen"]=true
  f["g03_p1_sequence"]=event.sequence
  # P1 has committed before this callback; it remains an ordinary source
  # witness even if a deeper real packet changes this same target afterward.
  var child: Dictionary=g03_packet(f,target,1.0,"nested_after_p1_commit")
  if not child.is_empty():f["g03_child_sequence"]=child.event.sequence

func p1_case(mode: String) -> void:
 current_group=mode
 var f: Dictionary=funded_shop(mode)
 if f.is_empty():return
 if not buy(f,G03_ITEM) or not buy(f,"final:G02") or not buy(f,"final:B01") or not check(f.session.close_panel().get("accepted",false),"P1 original shop closes") or not g06_enter_original(f,1,"r01a") or not settle_fixture_combat(f):dispose(f);return
 if not check(command(f,"learn",{"slot":"P","candidate":"P1","expected_rank":0}).get("accepted",false),"P1 learned with original row1 earned SP") or not g06_enter_original(f,2,"r02a") or not spawn_ready(f):dispose(f);return
 check(f.sim.hero.loadout.passive=="p1" and f.sim.hero.ranks.passive==1,"same original source owner projects P1 rank1")
 var kind: String="minion" if mode=="p1_lethal" else "armored"
 var target: Dictionary={}
 for enemy: Dictionary in f.sim.living():
  if enemy.kind==kind:target=enemy;break
 if not check(not target.is_empty(),"original P1 room has the authored "+kind):dispose(f);return
 var initial_distance: float=Vector3(target.position).distance_to(f.sim.hero.position)
 # Authored armored actors spawn about11.70m from the original hero, beyond
 # Q1 placement9m. Move using the original WASD route before HP/input setup.
 if initial_distance>=9.0 and not b04_approach(f,target,8.0):dispose(f);return
 check(Vector3(target.position).distance_to(f.sim.hero.position)<9.0,"original movement brings actual Q1 start inside unchanged9m placement range")
 g03_fixtures.append({"purpose":"P1 original target placement","target":target.actor_id,"kind":kind,"initial_distance":initial_distance,"final_distance":Vector3(target.position).distance_to(f.sim.hero.position),"original_WASD":initial_distance>=9.0,"direct_position_write":false})
 for enemy: Dictionary in f.sim.living():
  if not is_same(enemy,target):check(Vector3(enemy.position).distance_to(target.position)>3.0+float(enemy.radius),"short actual Q1 excludes original sibling")
 g03_heal_full(f,"P1 prepare target above low-health task threshold")
 var nominal: float=G06Design.parameter("yanguizhou","Q1-1",1)+float(f.sim.hero.stats.ap)*G06Design.fraction("yanguizhou","Q1-2",1)
 var nominal_bonus: float=nominal*G06Design.fraction("yanguizhou","P1-1",1)
 var left: float=minf(5.0,nominal_bonus*0.5)
 if mode=="p1_lethal":
  if not g02_prepare_hp(f,target,nominal+left):dispose(f);return
 else:
  if not check(float(target.hp)>nominal+nominal_bonus+3.0,"authored armored HP suffices for genuine nonlethal Q1/P1 and nested fixture"):dispose(f);return
 if not g03_damage_to(f,float(f.sim.hero.stats.max_hp)*0.25,"P1 original holder low-health setup"):dispose(f);return
 f["g03_p1_mode"]=mode;f["g03_p1_notified"]=false;f["g03_p1_nested_seen"]=false;f["g03_outer_armed"]=false
 var before: Dictionary=g03_protected(f)
 var before_g02: int=g02_task(f).progress
 var before_b01: int=task_state(f).progress
 var first: int=f.g03_damage.size()
 var released: Dictionary=g02_q1(f,target)
 if released.is_empty():dispose(f);return
 if mode=="core_p1_core_nested":
  if not check(not f.g03_p1_notified,"actual Q1 release leaves its real terminal pending"):dispose(f);return
  f.g03_outer_armed=true
  # Keep outer target distinct so the inner P1 target remains live and lets
  # its deeper true packet run after the atomic supplement.
  var outer: Dictionary={}
  for enemy: Dictionary in f.sim.living():
   if not is_same(enemy,target):outer=enemy;break
  if g03_packet(f,outer,1.0,"outer_pending_p1").is_empty():dispose(f);return
 else:
  for _tick: int in range(140):
   if f.g03_p1_notified:break
   step(f)
 if not check(f.g03_p1_notified,"original P1 atomic damage notification actually occurs"):dispose(f);return
 var packets: Array=[]
 var ratio: float=0.0
 var p1_packet: Dictionary={}
 for record: Dictionary in f.g03_damage.slice(first):
  if record.synthetic or record.witness.is_empty():continue
  packets.append(record)
  if record.held and float(record.owner_hp_first_observer)/float(record.owner_max_hp_first_observer)<0.35:ratio+=float(record.event.amount)/float(record.owner_max_hp_first_observer)
  if record.event.get("source")=="yanguizhou_p1" and record.event.get("cast_id")==released.cast_id:p1_packet=record
 if not check(not p1_packet.is_empty(),"genuine original P1 packet reaches the original Session and ledger"):dispose(f);return
 g03_near(float(g03_state(f).progress)-float(before.task.progress),ratio,"actual Q1/P1/nested packets each contribute one commit-time ratio")
 var receipt: Dictionary=f.g03_p1_receipt
 if mode=="p1_lethal":
  check(receipt.supplement_killed and target.dead and float(target.hp)==0.0,"P1 lethal actual supplement truncates at remaining original targetHP")
  g03_near(float(p1_packet.event.amount),left,"G03 counts actual capped P1 lethal amount, not nominal supplement")
  check(g02_task(f).progress==before_g02+1 and task_state(f).progress==before_b01+1,"same original P1 death advances original G02 and B01 once")
 else:
  check(not receipt.supplement_killed and not target.dead and float(target.hp)>0.0,"nonlethal original P1 contributes damage without a death")
  check(g02_task(f).progress==before_g02 and task_state(f).progress==before_b01,"nonlethal Q1/P1 do not create G02/B01 death credit")
 if mode=="core_p1_core_nested":
  check(not f.g03_outer_armed and f.g03_child_sequence>f.g03_p1_sequence and f.g03_p1_sequence>f.g03_outer_sequence,"core/P1/core notifications settle newest inner sequence before older parents")
  var order: Array=[]
  for packet: Dictionary in packets:
   if packet.event.sequence in [f.g03_outer_sequence,f.g03_p1_sequence,f.g03_child_sequence]:order.append(packet.event.sequence)
  check(order==[f.g03_child_sequence,f.g03_p1_sequence,f.g03_outer_sequence],"each mixed source stack frame survives reverse Model arrival order")
 var saved: Dictionary=g03_protected(f)
 f.g03_synthetic=true;f.sim.emit_event("damage",p1_packet.event.duplicate(true));f.g03_synthetic=false
 var replay: Dictionary=f.session.observe_event(f.sim,p1_packet.event)
 check(replay.get("accepted",false) and g03_protected(f)==saved,"historical P1 receipt and public damage copy cannot become another packet")
 g03_p1_evidence.append({"mode":mode,"packets":packets,"receipt":receipt,"before":before,"after":g03_protected(f),"ratio_sum":ratio,"actual_Q1_P1_inputs":true,"nested_source_API_fixture":mode=="core_p1_core_nested","original_roster":f.session.expected_enemies.duplicate(),"productionSession":true})
 b04_integrity(f,mode);dispose(f);g03_p1_completed.append(mode)

func run() -> void:
 g03_reset_evidence()
 for mode: String in g03_p1_required:p1_case(mode)
 g03_required=g03_p1_required.duplicate();g03_completed=g03_p1_completed.duplicate();g03_partition=g03_p1_partition
 evidence["g03_p1"]=g03_p1_evidence
 g03_report("equipment42_G03_actual_P1_and_mixed_nested_commits")
