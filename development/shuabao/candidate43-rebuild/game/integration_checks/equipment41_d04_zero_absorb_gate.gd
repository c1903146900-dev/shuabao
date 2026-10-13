extends "res://integration_checks/equipment41_source_gate.gd"
## Source boundary fixture explicitly approved by parent: create only a test
## shield through original add_shield, then use original incoming packages.
const D04_ZERO_GROUP := "zero_and_fully_absorbed_unused_room"
const D04_TEST_SHIELD := "equipment41_full_absorb_fixture"

func _initialize() -> void:
 output_path="user://equipment41_d04_zero_absorb_gate.json"
 d04_required=[D04_ZERO_GROUP]
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--equipment-result="):output_path=arg.trim_prefix("--equipment-result=")
 run.call_deferred()

func d04_zero_absorb() -> void:
 current_group=D04_ZERO_GROUP
 var f: Dictionary=d04_start(current_group,2)
 if f.is_empty():return
 var hp: float=f.sim.hero.hp
 var max_hp: float=f.sim.hero.stats.max_hp
 var quota: Dictionary=d04_quota(f)
 var commit_serial: int=f.sim._d04_hp_serial
 if not check(hp>0.0 and hp<max_hp*0.30 and not d04_view(f).used_in_room and d04_raw(f).is_empty(),"two legal purchases leave original360HP below1260x30percent with unused D04 room quota"):dispose(f);return
 var before_events: int=f.events.size()
 f.sim.damage_hero(0.0,Vector3.ZERO,0.0,true,true,{"source":"equipment41_zero_fixture","fixture":true,"direct":false,"generation":f.sim.encounter_generation,"room_id":f.sim.room_id})
 f.session.update_after_source_step()
 check(f.sim.hero.hp==hp and d04_quota(f)==quota and d04_raw(f).is_empty() and f.sim._d04_hp_serial==commit_serial,"actual zero incoming at lowHP does not create HP witness, shield or quota")
 var zero_events: Array=f.events.slice(before_events)
 f.sim.add_shield(D04_TEST_SHIELD,50.0,4.0,{"fixture":true,"purpose":"explicit original add_shield consumer for full-absorption boundary"})
 if not check(f.sim.hero.shields.has(D04_TEST_SHIELD) and float(f.sim.hero.shields[D04_TEST_SHIELD].amount)==50.0,"explicit test shield created only through original add_shield API"):dispose(f);return
 var total_before: float=f.sim.hero.shield_total()
 var source_shields_before: Dictionary=f.sim.hero.shields.duplicate(true)
 before_events=f.events.size()
 f.sim.damage_hero(10.0,Vector3.ZERO,0.0,true,true,{"source":"equipment41_fully_absorbed_fixture","fixture":true,"direct":false,"generation":f.sim.encounter_generation,"room_id":f.sim.room_id})
 f.session.update_after_source_step()
 near_number(total_before-float(f.sim.hero.shield_total()),10.0,"actual original absorption consumes ten shield points")
 check(f.sim.hero.hp==hp and d04_quota(f)==quota and d04_raw(f).is_empty() and f.d04_shields.is_empty() and f.sim._d04_hp_serial==commit_serial,"fully absorbed actual packet leaves lowHP unused-room D04 quota untouched")
 var absorbed_events: Array=f.events.slice(before_events)
 var consumed: bool=false
 for event: Dictionary in absorbed_events:
  if event.get("kind")=="damage" and event.get("source")=="equipment41_fully_absorbed_fixture" and float(event.get("amount",-1.0))==0.0 and float(event.get("absorbed",-1.0))==10.0:consumed=true
 check(consumed,"original public damage notification truthfully records zero HP loss and ten absorbed")
 if d04_damage_to(f,hp-1.0,"first actual HP loss after original full-absorption negative").is_empty():dispose(f);return
 check(f.d04_shields.size()==1 and d04_receipts(f).size()==1 and d04_view(f).used_in_room and f.sim._d04_hp_serial==commit_serial+1,"only later genuine positive HP decrease consumes one original room quota")
 near_number(float(d04_raw(f).amount),max_hp*0.18,"genuine final wound creates source18percent finalmax shield")
 near_number(float(d04_raw(f).left),4.0,"genuine final wound uses original four-second shield")
 evidence["d04_zero_absorb"]={"initial_hp":hp,"initial_max_hp":max_hp,"original_quota":quota,"zero_events":zero_events,"fixture_shields_before_absorption":source_shields_before,"absorbed_events":absorbed_events,"explicit_add_shield_fixture":true,"direct_HP_or_shield_write":false}
 b04_integrity(f,current_group);dispose(f);d04_completed.append(current_group)

func run() -> void:
 evidence={"wallet_fixtures":[],"inputs":[],"cooldown_fixtures":[],"completions":[],"aborts":[],"victory":[],"postcompletion":[],"lifecycle":[],"isolated_common":[],"movement":[],"g02_deaths":[],"pre_damage":[],"inputs_g02":[],"p1_g02":{},"route_g02":{},"extra_actor_g02":{}}
 d04_zero_absorb()
 d04_report("equipment41_D04_actual_zero_and_full_absorption")
