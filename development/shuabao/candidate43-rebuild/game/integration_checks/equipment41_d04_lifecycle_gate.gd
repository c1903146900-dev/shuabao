extends "res://integration_checks/equipment41_source_gate.gd"
## Additional original Session groups. The initial two-group gate stays frozen.
const D04_LIFECYCLE_GROUPS := ["actual_expiry_and_pause","sale_rebuy_newroom_rest","nested_shield_callback"]

func _initialize() -> void:
 output_path = "user://equipment41_d04_lifecycle_gate.json"
 d04_required = D04_LIFECYCLE_GROUPS.duplicate()
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--equipment-result="):output_path=arg.trim_prefix("--equipment-result=")
  if arg.begins_with("--d04-lifecycle-group="):d04_partition=arg.trim_prefix("--d04-lifecycle-group=")
 if d04_partition!="all":
  if d04_partition not in D04_LIFECYCLE_GROUPS:push_error("Unknown D04 lifecycle group");quit(2);return
  d04_required=[d04_partition]
 run.call_deferred()

func on_event(event: Dictionary, f: Dictionary) -> void:
 super.on_event(event,f)
 if event.get("kind")!="shield" or event.get("source")!=D04_SHIELD or not f.get("d04_nested_armed",false) or f.get("d04_nested_fired",false):return
 f.d04_nested_fired=true # Test-only callback guard, never production quota.
 var before: float=f.sim.hero.hp
 var quota: Dictionary=d04_quota(f)
 var original: Dictionary=d04_raw(f)
 var packet: Dictionary=d04_damage_to(f,before-1.0,"nested actual incoming during original shield observer")
 check(not packet.is_empty() and packet.before_hp==before and packet.after_hp==before-1.0,"nested source package samples its own actual current HP baseline")
 check(d04_raw(f).is_empty() and d04_quota(f)==quota and f.d04_shields.size()==1,"new shield absorbs nested package and already-committed room quota prevents duplicate")
 evidence["d04_nested"]={"shield_at_callback":original,"nested_packet":packet,"quota":quota}

func d04_expiry() -> void:
 current_group=D04_LIFECYCLE_GROUPS[0]
 # Six original legal copies provide a larger shield against the unchanged AI
 # during lifetime observation. No AI/position/stat/shield field is changed.
 var f: Dictionary=d04_start(current_group,6)
 if f.is_empty():return
 var target_hp: float=minf(float(f.sim.hero.hp)-1.0,float(f.sim.hero.stats.max_hp)*0.30-1.0)
 if d04_damage_to(f,target_hp,"real grant before source-clock expiry observation").is_empty():dispose(f);return
 if not check(f.d04_shields.size()==1 and not d04_raw(f).is_empty(),"six paid base copies still issue only one shield"):dispose(f);return
 var start: float=f.sim.common.runtime.actor_time
 var initial: Dictionary=d04_raw(f)
 var quota: Dictionary=d04_quota(f)
 if not check(f.session.set_modal_blocked(true).get("accepted",false),"original Session pause accepted"):dispose(f);return
 step(f,150)
 check(f.sim.common.runtime.actor_time==start and d04_raw(f)==initial,"original pause freezes shield amount and remaining source seconds")
 var hp: float=f.sim.hero.hp
 f.sim.damage_hero(1.0,Vector3.ZERO,0.0,true,true,{"source":"equipment41_paused_fixture","fixture":true})
 check(f.sim.hero.hp==hp and d04_raw(f)==initial and d04_quota(f)==quota,"even mandatory source packet respects original pause guard")
 if not check(f.session.set_modal_blocked(false).get("accepted",false),"original Session resume accepted"):dispose(f);return
 var samples: Array=[]
 var expired: bool=false
 for _tick: int in range(260):
  if not check(f.sim.phase=="combat" and not f.sim.hero.dead,"actual source lifetime remains in living original combat"):break
  step(f)
  var elapsed: float=float(f.sim.common.runtime.actor_time)-start
  var raw: Dictionary=d04_raw(f)
  samples.append({"actor_elapsed":elapsed,"remaining":raw.get("left",0.0),"amount":raw.get("amount",0.0),"actual_hp":f.sim.hero.hp})
  if elapsed<4.0-float(f.sim.TIME_EPS):
   if not check(not raw.is_empty(),"issued shield survives unchanged AI absorption until its timer boundary"):break
   near_number(float(raw.left),4.0-elapsed,"actual shield left follows original actor clock")
  else:
   check(raw.is_empty(),"original timer removes shield at four source seconds")
   check(elapsed<=4.0+float(f.sim.FIXED_TICK)+float(f.sim.TIME_EPS),"expiration occurs within one original fixed tick")
   expired=true;break
 check(expired and d04_quota(f)==quota and d04_receipts(f).size()==1,"original expiry leaves used quota and sole receipt intact")
 evidence["d04_expiry"]={"initial":initial,"samples":samples,"actual_original_actor_clock":true,"AI_enabled":f.sim.ai_enabled,"six_legal_copies":true}
 b04_integrity(f,current_group);dispose(f);d04_completed.append(current_group)

func d04_lifecycle() -> void:
 current_group=D04_LIFECYCLE_GROUPS[1]
 var f: Dictionary=d04_start(current_group)
 if f.is_empty():return
 if not spawn_ready(f):dispose(f);return
 var actors: Array=f.sim.living().duplicate()
 if not check(actors.size()>=2 and not d04_view(f).used_in_room,"actual original roster ready before lifecycle grant"):dispose(f);return
 for enemy: Dictionary in actors.slice(0,actors.size()-1):lethal_enemy_fixture(f,enemy,"D04 original roster advance before final grant")
 var threshold: float=float(f.sim.hero.stats.max_hp)*0.30
 if d04_damage_to(f,threshold-5.0,"grant immediately before original last enemy").is_empty():dispose(f);return
 var first_room: String=f.sim.room_id
 var initial: Dictionary=d04_raw(f)
 lethal_enemy_fixture(f,actors.back(),"D04 actual last enemy after grant")
 if not settle_original_row(f,1) or not g02_open(f):dispose(f);return
 var raw: Dictionary=d04_raw(f)
 var now: float=f.sim.common.runtime.actor_time
 var quota: Dictionary=d04_quota(f)
 if not check(not raw.is_empty() and raw.amount==initial.amount and float(raw.left)>0.0,"actual terminal preserves issued shield into legal safe shop"):dispose(f);return
 if not sell(f,D04_ITEM):dispose(f);return
 check(owned_count(f,D04_ITEM)==0 and d04_raw(f)==raw and d04_quota(f)==quota,"sale removes item but preserves issued shield and original room quota")
 if not buy(f,D04_ITEM):dispose(f);return
 check(owned_count(f,D04_ITEM)==1 and d04_raw(f)==raw and d04_quota(f)==quota,"actual repurchase refreshes neither shield nor once-per-room quota")
 if not undo(f) or not undo(f):dispose(f);return
 check(owned_count(f,D04_ITEM)==1 and d04_raw(f)==raw and d04_quota(f)==quota,"original undo restores sale without changing issued shield")
 step(f,200)
 check(f.sim.common.runtime.actor_time==now and d04_raw(f)==raw,"safe original source steps freeze surviving shield lifetime")
 if not check(f.session.close_panel().get("accepted",false),"original lifecycle shop closes") or not enter(f,2):dispose(f);return
 var second_room: String=f.sim.room_id
 if not check(second_room!=first_room and not d04_view(f).used_in_room and f.sim.hero.hp<float(f.sim.hero.stats.max_hp)*0.30,"different real room admits lowHP owner with unused room quota"):dispose(f);return
 var carried: Dictionary=d04_raw(f)
 check(carried==raw and f.sim.common.runtime.actor_time==now,"new original room retains exact prior shield before source steps")
 # Strong fake-notification negative: owner is actually below30% in an UNUSED
 # new room; public reported damage still cannot grant/claim without HP loss.
 var before_quota: Dictionary=d04_quota(f)
 var before_count: int=f.d04_shields.size()
 f.sim.emit_event("damage",{"target":f.sim.hero.actor_id,"source":"equipment41_public_fake_low_entry","amount":1.0,"raw":1.0,"absorbed":0.0,"position":f.sim.hero.position})
 var old: Dictionary=f.d04_original_commit
 f.sim._hero_after_incoming(float(old.hp_before),float(old.lost),f.d04_original_metadata)
 check(d04_quota(f)==before_quota and d04_raw(f)==carried and f.d04_shields.size()==before_count,"lowHP unused-room publicdamage and old-room metadata cannot mint shield")
 if d04_damage_to(f,float(f.sim.hero.hp)-1.0,"first actual new-room lowHP wound through carried shield").is_empty():dispose(f);return
 check(f.d04_shields.size()==before_count+1 and d04_view(f).used_in_room and d04_quota(f).rooms.has(first_room) and d04_quota(f).rooms.has(second_room),"first genuine new-room wound grants once and retains both room claims")
 near_number(float(d04_raw(f).left),4.0,"new-room actual trigger grants original full duration")
 if not b04_settle_row(f,2):dispose(f);return
 var before_rest: Dictionary=d04_raw(f)
 if not check(not before_rest.is_empty(),"actual issued second-room shield remains before rest"):dispose(f);return
 quota=d04_quota(f)
 if not enter(f,3) or not check(f.session.status=="service","actual authored rest node entered") or not check(f.session.complete_service().get("accepted",false),"original rest settles"):dispose(f);return
 check(d04_raw(f).is_empty() and d04_quota(f)==quota,"original rest clears actual shield and retains already-used room quotas")
 for _repeat: int in range(5):f.sim.common.refresh_stats();f.sim.refresh_passive23()
 check(d04_raw(f).is_empty() and d04_quota(f)==quota,"subsequent real stat refresh cannot reconstruct rested shield or quota")
 evidence["d04_lifecycle"]={"first_room":first_room,"second_room":second_room,"carried":carried,"before_rest":before_rest,"quota_after_rest":quota,"original_sale_rebuy_undo":true,"original_rest":true}
 b04_integrity(f,current_group);dispose(f);d04_completed.append(current_group)

func d04_nested() -> void:
 current_group=D04_LIFECYCLE_GROUPS[2]
 var f: Dictionary=d04_start(current_group)
 if f.is_empty():return
 f["d04_nested_armed"]=true;f["d04_nested_fired"]=false
 var before_serial: int=f.sim._d04_hp_serial
 var target_hp: float=float(f.sim.hero.stats.max_hp)*0.30-2.0
 var before_hp: float=f.sim.hero.hp
 var amount: float=before_hp-target_hp+float(f.sim.hero.shield_total())
 if not check(amount>0.0,"outer nested fixture has positive actual source packet"):dispose(f);return
 f.sim.damage_hero(amount,Vector3.ZERO,0.0,true,true,{"source":"equipment41_nested_outer_fixture","fixture":true,"direct":false,"generation":f.sim.encounter_generation,"room_id":f.sim.room_id})
 f.session.update_after_source_step()
 # Outer request reaches target_hp, then its actual shield callback applies an
 # additional real packet; therefore final HP is one lower than outer target.
 near_number(float(f.sim.hero.hp),target_hp-1.0,"outer plus nested actual source commits retain both HP losses")
 d04_packets.append({"label":"outer actual packet with nested callback","source_api":"original damage_hero","before_hp":before_hp,"requested":amount,"outer_commit_hp":target_hp,"final_hp_after_nested":f.sim.hero.hp,"expected_final":target_hp-1.0,"direct_HP_write":false})
 check(f.d04_nested_fired and f.d04_shields.size()==1 and d04_receipts(f).size()==1,"nested real callback emits exactly one room shield and receipt")
 check(f.sim._d04_hp_serial==before_serial+2,"outer and nested true incoming each have independent original commit serial")
 check(d04_view(f).used_in_room and d04_raw(f).is_empty(),"nested consumption leaves original used quota without a second shield")
 b04_integrity(f,current_group);dispose(f);d04_completed.append(current_group)

func run() -> void:
 evidence={"wallet_fixtures":[],"inputs":[],"cooldown_fixtures":[],"completions":[],"aborts":[],"victory":[],"postcompletion":[],"lifecycle":[],"isolated_common":[],"movement":[],"g02_deaths":[],"pre_damage":[],"inputs_g02":[],"p1_g02":{},"route_g02":{},"extra_actor_g02":{}}
 if D04_LIFECYCLE_GROUPS[0] in d04_required:d04_expiry()
 if D04_LIFECYCLE_GROUPS[1] in d04_required:d04_lifecycle()
 if D04_LIFECYCLE_GROUPS[2] in d04_required:d04_nested()
 d04_report("equipment41_D04_original_lifetime_lifecycle_and_nested")
