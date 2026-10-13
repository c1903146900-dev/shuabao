extends "res://integration_checks/war_elixir_source_gate.gd"
## Economic and HP-deficit fixtures are explicit. The hit itself is the original
## LMB request, motion, impact and heal consumer with original AI left enabled.
var health_samples: Array=[]
func _initialize() -> void:
 output_path="user://war_basic_lifesteal.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--elixir-result="):output_path=arg.trim_prefix("--elixir-result=")
 run.call_deferred()
func before_health(f: Dictionary) -> Dictionary:
 return {"hp":float(f.sim.hero.hp),"clock":float(f.sim.common.runtime.actor_time),"event_count":f.events.size(),"regen":float(f.sim.hero.stats.regen),"max_hp":float(f.sim.hero.stats.max_hp),"lifesteal":float(f.sim.hero.lifesteal())}
func sample_health(f: Dictionary,before: Dictionary) -> Array:
 var incoming: float=0.0
 var outgoing: float=0.0
 var hits: Array=[]
 var other_events: Array=[]
 var uncovered_damage: Array=[]
 for event: Dictionary in f.events.slice(int(before.event_count)):
  if event.get("kind","")!="damage":
   other_events.append(event.duplicate(true))
   check(event.get("kind","") not in ["potion_used","passive_rescue","heal","healed"],"unsupported non-damage health event is not accepted as lifesteal proof")
   continue
  if event.get("target","")==f.sim.hero.actor_id:incoming+=float(event.amount)
  else:
   var matches: bool=event.get("source","")=="attack" and int(event.get("cast_id",-1))==int(f.war_basic_cast_id) and event.get("basic_attack",false)==true and event.get("room_id","")==f.sim.room_id and int(event.get("generation",-1))==f.sim.encounter_generation and str(event.get("target","")) in f.session.expected_enemies and not event.get("replay",false) and not event.get("hex_generated",false)
   if matches:outgoing+=float(event.amount);hits.append(event.duplicate(true))
   else:uncovered_damage.append(event.duplicate(true));check(false,"other hero outgoing packet is uncovered; never include it in eightpercent formula")
 var dt: float=float(f.sim.common.runtime.actor_time)-float(before.clock)
 var natural: float=float(before.regen)*dt
 var leech: float=outgoing*float(before.lifesteal)
 var expected: float=natural+leech
 var observed: float=float(f.sim.hero.hp)-float(before.hp)+incoming
 check(float(before.max_hp)-float(before.hp)>expected,"no missing-HP clipping contaminates healing sample")
 check(float(f.sim.hero.stats.regen)==float(before.regen),"regen source rate unchanged across sample")
 near_number(observed,expected,"unexplained non-damage health delta rejected; original regen plus matched basic eightpercent only")
 health_samples.append({"before":before,"after_hp":f.sim.hero.hp,"dt":dt,"incoming":incoming,"natural":natural,"leech":leech,"observed":observed,"hits":hits,"other_events":other_events,"uncovered_damage":uncovered_damage,"unexplained_health_delta":observed-expected})
 return hits
func run() -> void:
 g03_reset_evidence()
 var f: Dictionary=funded_shop("war_basic_lifesteal")
 if f.is_empty():finish_war();return
 var model=f.session.ledger.model
 if not buy(f,WAR) or not check(shop_command(f,"consume",{"uid":war_uid(f)}).accepted,"actual safe drink") or not check(f.session.close_panel().accepted,"original shop closes") or not enter(f,1) or not spawn_ready(f):dispose(f);finish_war();return
 for id: String in f.sim.common.runtime.selected:
  if id.begins_with("g") and id!="g01":
   check(false,"other active Common modifier is not covered by this isolated health formula: "+id);dispose(f);finish_war();return
 check(f.sim.hero.ranks.passive==0,"no passive supplemental health/damage channel is learned in this sample")
 var target: Dictionary=g02_nearest(f)
 if target.is_empty() or not b04_approach(f,target,float(target.radius)*0.9) or not b04_ready(f):dispose(f);finish_war();return
 f.sim.damage_hero(100.0,Vector3.ZERO,0.0,true,true,{"source":"explicit_war_healing_deficit_fixture","no_reactions":true})
 f.session.update_after_source_step()
 if not check(not f.sim.hero.dead and float(f.sim.hero.hp)<float(f.sim.hero.stats.max_hp)-20.0,"real damage creates finite healing deficit"):dispose(f);finish_war();return
 near_number(float(f.sim.hero.lifesteal()),0.08,"unstacked war elixir reaches actual actor lifesteal interface")
 var before: Dictionary=before_health(f)
 var action: Dictionary=b04_launch(f,target.position)
 if action.is_empty():dispose(f);finish_war();return
 f["war_basic_cast_id"]=int(action.cast_id)
 var hits: Array=sample_health(f,before)
 for i in range(180):
  if not hits.is_empty() or f.sim.hero.dead:break
  before=before_health(f);step(f);hits.append_array(sample_health(f,before))
 check(not hits.is_empty(),"original LMB action reaches real roster damage consumer")
 var total: float=0.0
 for hit: Dictionary in hits:total+=float(hit.amount)
 check(total>0.0 and float(f.sim.hero.lifesteal())==0.08,"positive actual attack exercises eightpercent lifesteal")
 b04_integrity(f,"war original LMB and health consumer")
 dispose(f);finish_war()
func finish_war() -> void:
 var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"check_records":check_records,"failures":failures,"samples":health_samples,"wallet_fixture":true,"hero_deficit_source_damage_fixture":true,"attack_input":"original LMB source request","native_CUA":false,"source_binding_sha256":FileAccess.get_sha256("res://visual_rework_20261009/binding/source_binding.json")}
 var file: FileAccess=FileAccess.open(output_path,FileAccess.WRITE)
 if file==null:quit(2);return
 file.store_string(JSON.stringify(report,"  "));var err: Error=file.get_error();file.close();quit(0 if report.passed and err==OK else 2)
