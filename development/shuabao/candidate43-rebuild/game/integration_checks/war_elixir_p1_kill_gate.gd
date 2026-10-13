extends "res://integration_checks/war_elixir_source_gate.gd"
## Original earned P1 and real Q1/P1 action. Earlier first-room deaths and the
## target's nonlethal HP preparation are explicit source-damage fixtures.
var p1_records: Array=[]
var war_p1_preconditions: Array=[]
func _initialize() -> void:
 output_path="user://war_p1_kill.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--elixir-result="):output_path=arg.trim_prefix("--elixir-result=")
 run.call_deferred()
func p1_case() -> void:
 var f: Dictionary=funded_shop("war_p1_kill")
 if f.is_empty():return
 var model=f.session.ledger.model
 if not check(f.session.close_panel().accepted,"original shop closes") or not g06_enter_original(f,1,"r01a") or not settle_fixture_combat(f):dispose(f);return
 if not check(command(f,"learn",{"slot":"P","candidate":"P1","expected_rank":0}).accepted,"earned first-room point learns original P1") or not check(f.session.open_panel().accepted,"original between-room shop") or not buy(f,WAR) or not check(shop_command(f,"consume",{"uid":war_uid(f)}).accepted,"war bottle binds upcoming second battle") or not check(f.session.close_panel().accepted,"close prebattle shop") or not g06_enter_original(f,2,"r02a") or not spawn_ready(f):dispose(f);return
 var target: Dictionary={}
 for enemy: Dictionary in f.sim.living():
  if enemy.kind=="minion" and enemy.position.distance_to(f.sim.hero.position)<9.0:target=enemy;break
 if not check(not target.is_empty(),"original row2 contains reachable minion"):dispose(f);return
 war_p1_preconditions.append({"rank":f.sim.hero.ranks.q,"selected_hex":model.state.selected_hex.duplicate(true),"hero_stats":f.sim.hero.stats.duplicate(true)})
 if not check(f.sim.hero.ranks.q==1,"this bounded P1 target preparation requires original rank1 Q1"):dispose(f);return
 var nominal: float=G06Design.parameter("yanguizhou","Q1-1",1)+float(f.sim.hero.stats.ap)*G06Design.fraction("yanguizhou","Q1-2",1)
 var left: float=minf(5.0,nominal*G06Design.fraction("yanguizhou","P1-1",1)*0.5)
 for enemy: Dictionary in f.sim.living():
  if not is_same(enemy,target):check(enemy.position.distance_to(target.position)>3.0+float(enemy.radius),"short original Q1 excludes sibling")
 if not g02_prepare_hp(f,target,nominal+left):dispose(f);return
 check(not f.sim.hero.cast_state.has("elixir_war_on_kill"),"HP preparation without death grants no war buff")
 var released: Dictionary=g02_q1(f,target)
 if released.is_empty():dispose(f);return
 var original_releases: Array=events_of(f,"ink_q1_released")
 if not check(original_releases.size()==1,"one original Q1 release provides cast identity before damage audit"):dispose(f);return
 var actual_q1_packets: Array=[]
 for event: Dictionary in f.sim.event_log:
  if event.get("kind","")=="damage" and event.get("source","")=="q1" and event.get("target","")==target.actor_id and int(event.get("cast_id",-1))==int(original_releases[0].cast_id) and event.get("room_id","")==f.sim.room_id and int(event.get("generation",-1))==f.sim.encounter_generation:actual_q1_packets.append(event.duplicate(true))
 war_p1_preconditions.back()["actual_q1_packets"]=actual_q1_packets
 if not check(not actual_q1_packets.is_empty(),"actual same-cast Q1 damage in current room/generation is recorded"):dispose(f);return
 war_p1_preconditions.back()["nominal_fixture"]=nominal
 war_p1_preconditions.back()["remaining_hp"]=target.hp
 if not check(not target.dead and is_equal_approx(float(target.hp),left),"actual Q1 must match the bounded nominal precondition; mismatched critical/Hex damage remains uncovered"):dispose(f);return
 for i in range(140):
  if target.dead or f.sim.phase!="combat" or f.sim.hero.dead:break
  step(f)
 var releases: Array=events_of(f,"ink_q1_released")
 if not check(releases.size()==1,"one actual original Q1 root release"):dispose(f);return
 var receipts: Array=g06_p1_receipts(f,int(releases[0].cast_id))
 var kill: Dictionary=g02_find_kill(f,str(target.actor_id),"yanguizhou_p1")
 if not check(target.dead and receipts.size()==1 and receipts[0].supplement_killed and not kill.is_empty(),"actual original P1 commits target death and one receipt"):dispose(f);return
 check(kill.witness.get("witness",{}).get("proof","")=="original_p1_atomic_death","P1 credit uses original atomic death witness")
 var buff: Dictionary=f.sim.hero.cast_state.get("elixir_war_on_kill",{}).duplicate(true)
 if check(not buff.is_empty() and model.war_buff_effect(f.sim).get("active",false),"actual P1 death activates war AS"):
  near_number(float(buff.expires_at)-float(buff.granted_at),3.0,"actual P1 war lifetime exactly3")
  near_number(float(model.war_buff_effect(f.sim).attack_speed_fraction),0.10,"actual P1 grants one AS fraction")
  check(buff.origin_scope==kill.witness.witness.scope,"war buff retains original P1 scope")
 var before: Dictionary=model.state.duplicate(true)
 model.record_battle_event(f.sim,kill.event,f.session.run_id)
 check(model.state==before and f.sim.hero.cast_state.get("elixir_war_on_kill",{})==buff,"historical P1 receipt event cannot refresh same corpse")
 p1_records.append({"release":released,"receipt":receipts,"kill":kill,"buff":buff,"actual_Q1_P1_input":true,"native_input":false})
 dispose(f)
func run() -> void:
 g03_reset_evidence();p1_case();await process_frame
 check(p1_records.size()==1,"actual P1 case completed")
 var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"check_records":check_records,"failures":failures,"records":p1_records,"preconditions":war_p1_preconditions,"economic_fixture":true,"prior_room_source_damage_fixture":true,"target_nonlethal_source_damage_fixture":true,"natural_play":false,"source_binding_sha256":FileAccess.get_sha256("res://visual_rework_20261009/binding/source_binding.json")}
 var file: FileAccess=FileAccess.open(output_path,FileAccess.WRITE)
 if file==null:quit(2);return
 file.store_string(JSON.stringify(report,"  "));var err: Error=file.get_error();file.close();quit(0 if report.passed and err==OK else 2)
