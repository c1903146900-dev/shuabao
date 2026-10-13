extends SceneTree
## Main-owned read/execute comparison of old, preserved broken, and fixed source.
## Known bad must remain bad. No patching initialized fields or waived admission.
const Before=preload("res://tests/ink_intermediate_stats_20261004/ink_intermediate_sim.gd")
const Bad=preload("res://tests/ink_q3_foundation_20261004/ink_q3_sim.gd")
const Fixed=preload("res://tests/ink_q3_foundation_20261004/fix02/ink_q3_sim.gd")
const T=preload("res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_tuning.gd")
const INK_BRIDGE="res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_common_bridge.gd"
var checks:int=0
var failures:Array=[]
var completed:Array=[]
var evidence:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func init_evidence(sim)->Dictionary:
 return {"actor_id":sim.hero.actor_id,"hp":sim.hero.hp,"stats":sim.hero.stats.duplicate(true),"base_stats":sim.hero.base_stats.duplicate(true),"projected_base_stats":sim.hero.projected_base_stats.duplicate(true),"rules_hash":sim.source_rules_hash,"expected_rules_hash":sim.EXPECTED_RULES_HASH,"bridge_script":sim.common.get_script().resource_path,"ranged":sim.common.context_values.get("ranged",false),"director_script":sim.enemy_director.get_script().resource_path,"phase":sim.phase,"cast_serial":sim.cast_serial,"stun_left":sim.hero.stun_left,"cooldowns":sim.hero.cooldowns.duplicate(true)}
func assert_ink_init(sim,label:String)->void:
 check(sim.hero.actor_id=="yanguizhou",label+" actual Ink identity")
 check(sim.hero.hp==360 and sim.hero.stats.max_hp==360,label+" real parent initializes HP and maximum")
 check(sim.source_rules_hash==sim.EXPECTED_RULES_HASH,label+" actual expected rules digest")
 check(sim.common.get_script().resource_path==INK_BRIDGE,label+" actual Ink damage-depth bridge")
 check(sim.common.context_values.get("ranged",false),label+" ranged context preserved")
 for key in T.hero_stats():check(sim.hero.base_stats[key]==T.hero_stats()[key],label+" original base stat "+key)
func configure_room(sim,candidate:String)->Dictionary:
 root.add_child(sim);sim.auto_finish=false;sim.ai_enabled=false
 sim.hero.position=Vector3.ZERO;sim.hero.loadout.q=candidate;sim.hero.ranks.q=1
 return sim.begin_encounter("init-diagnostic",[])
func q1_input(sim)->Dictionary:
 var result:Dictionary={}
 result.arm=sim.request_ink_input("q_down")
 result.down=sim.request_ink_input("left_down",Vector3.ZERO)
 result.motion=sim.request_ink_input("motion",Vector3(4,0,0))
 result.release=sim.request_ink_input("left_up",Vector3(4,0,0))
 return result
func run()->void:
 var old=Before.new();evidence.old_a79fc_q1={"initial":init_evidence(old)}
 assert_ink_init(old,"old a79fc")
 evidence.old_a79fc_q1.room=configure_room(old,"q1")
 check(evidence.old_a79fc_q1.room.accepted,"old genuine room admitted")
 evidence.old_a79fc_q1.input=q1_input(old)
 for step in ["arm","down","motion","release"]:check(evidence.old_a79fc_q1.input[step].accepted,"old Q1 accepted "+step)
 evidence.old_a79fc_q1.final=init_evidence(old);completed.append("old_a79fc_q1")
 var bad=Bad.new();evidence.original_bad_q3={"initial":init_evidence(bad)}
 check(bad.hero.actor_id=="hero" and bad.hero.hp==1 and bad.hero.stats.max_hp==1,"preserved bad source actually skipped actor initialization")
 check(bad.source_rules_hash.is_empty(),"preserved bad source actually has empty rules hash")
 check(bad.common.get_script().resource_path!=INK_BRIDGE and not bad.common.context_values.get("ranged",false),"preserved bad source skipped complete bridge/context setup")
 evidence.original_bad_q3.room=configure_room(bad,"q3")
 check(evidence.original_bad_q3.room.accepted,"bad has otherwise accepted ordinary room")
 evidence.original_bad_q3.admission=bad.request_action("q",Vector3(4,0,0))
 check(not evidence.original_bad_q3.admission.accepted and evidence.original_bad_q3.admission.reason=="source_binding_mismatch","actual first rejection reason is source_binding_mismatch")
 check(bad.cast_serial==0 and bad.hero.cooldowns.q==0 and bad.ink_mountain.is_empty(),"original guard rejects before root/CD/terrain")
 evidence.original_bad_q3.final=init_evidence(bad);completed.append("original_bad_q3")
 var fixed_q1=Fixed.new();evidence.fixed_q1={"initial":init_evidence(fixed_q1)}
 assert_ink_init(fixed_q1,"fixed Q1")
 evidence.fixed_q1.room=configure_room(fixed_q1,"q1")
 check(evidence.fixed_q1.room.accepted,"fixed Q1 genuine room admitted")
 evidence.fixed_q1.input=q1_input(fixed_q1)
 check(evidence.fixed_q1.input==evidence.old_a79fc_q1.input,"fixed Q1 real admission replies match old a79fc")
 check(fixed_q1.event_log==old.event_log and fixed_q1.hero.snapshot()==old.hero.snapshot(),"fixed Q1 initial release exact event/actor parity")
 completed.append("fixed_q1")
 var fixed_q3=Fixed.new();evidence.fixed_q3={"initial":init_evidence(fixed_q3)}
 assert_ink_init(fixed_q3,"fixed Q3")
 evidence.fixed_q3.room=configure_room(fixed_q3,"q3")
 check(evidence.fixed_q3.room.accepted,"fixed Q3 genuine room admitted")
 evidence.fixed_q3.admission=fixed_q3.request_action("q",Vector3(4,0,0))
 check(evidence.fixed_q3.admission.accepted and evidence.fixed_q3.admission.reason=="ok","fixed real first raise accepted without weakened guard")
 check(not fixed_q3.ink_mountain.is_empty() and fixed_q3.hero.cooldowns.q==12.0 and fixed_q3.cast_serial==1,"fixed genuine mountain/CD/root exist")
 evidence.fixed_q3.final=init_evidence(fixed_q3);completed.append("fixed_q3")
 # Existing full gate already covers Shift and walking. Add only the missing
 # ordinary BASIC terrain-retention assertion, with a live walking observation.
 var terrain_before:Dictionary=fixed_q3.ink_mountain
 var expires_before:float=float(terrain_before.get("expires_at",-1.0))
 evidence.fixed_q3.basic=fixed_q3.request_action("attack",Vector3(9,0,0))
 check(evidence.fixed_q3.basic.accepted,"ordinary BASIC accepted during live mountain")
 check(not terrain_before.is_empty() and is_same(fixed_q3.ink_mountain,terrain_before),"ordinary BASIC does not cancel or replace mountain")
 var at:Vector3=fixed_q3.hero.position
 fixed_q3.hero.move_intent=Vector3.RIGHT;fixed_q3.step(.04)
 check(fixed_q3.hero.position.distance_to(at)>.0,"ordinary walking remains live after BASIC")
 check(is_same(fixed_q3.ink_mountain,terrain_before) and float(fixed_q3.ink_mountain.get("expires_at",-2.0))==expires_before,"walking/BASIC flight preserve same terrain and expiry, no cancel-active reset")
 completed.append("basic_walk_lifecycle")
 for sim in [old,bad,fixed_q1,fixed_q3]:sim.free()
 var report:Dictionary={"suite":"q3_fix01_actual_initializer_diagnostic","passed":failures.is_empty(),"checks":checks,"failures":failures,"completed":completed,"evidence":evidence,"source_binding_id":FileAccess.get_sha256("res://tests/ink_q3_foundation_20261004/fix02/source_binding.json"),"scope":"initialization and actual admission only; not full Q3 mechanics or retained gate acceptance"}
 var file=FileAccess.open("res://tests/ink_q3_foundation_20261004/fix02/diagnostic_result.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("INK_Q3_INIT_DIAGNOSTIC_REPORT ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
