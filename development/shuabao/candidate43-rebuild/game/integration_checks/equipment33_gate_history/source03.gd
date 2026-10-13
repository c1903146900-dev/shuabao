extends "res://integration_checks/postboss_equipment33_gate.gd"
## Explicit economic and spawned-target fixture on the original factory/Session.
## No production wallet, damage formula, enemy definition, or reward change.
var evidence: Dictionary = {}
func _initialize() -> void:
 output_path = "user://equipment33_source_gate.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--equipment-result="): output_path = arg.trim_prefix("--equipment-result=")
 run.call_deferred()
func hit(f: Dictionary, enemy: Dictionary, nominal: float, extra: Dictionary = {}) -> float:
 var hp: float = enemy.hp
 var metadata: Dictionary = {"no_reactions":true,"direct":false,"fixture":true}
 metadata.merge(extra,true)
 f.sim.damage_enemy(enemy,nominal,"equipment33_source_fixture",0,true,false,metadata)
 return hp-float(enemy.hp)
func settle_extra_targets(f: Dictionary) -> bool:
 var actors:Array=f.sim.living().duplicate()
 if not check(not actors.is_empty() and actors.size()<=MAX_ROOM_ACTORS+3,"bounded original room plus exactly three declared spawned targets"):return false
 for enemy:Dictionary in actors:
  if not check(enemy.state!="spawn","all declared targets completed real spawn grace"):return false
  lethal_enemy_fixture(f,enemy,"settle explicitly augmented equipment test room")
 for _tick in range(MAX_TERMINAL_TICKS):
  if f.session.status!="combat":break
  step(f)
 check(f.session.kill_receipts.size()==actors.size(),"one authentic source receipt per original or explicitly spawned actor")
 return check(f.sim.phase=="victory" and f.session.status=="between_rooms" and f.session.fault.is_empty(),"augmented test room settles through original Session")
func run() -> void:
 current_group="actual_equipment33_source"
 var f: Dictionary=fresh()
 if f.is_empty(): finish(); return
 if not prepare_initial_choices(f): dispose(f);finish();return
 var model=f.session.ledger.model
 evidence["wallet_fixture"]={"before":model.state.gold,"after":20000,"production_default_unchanged":true}
 model.state.gold=20000 # Declared test-only budget; never part of ordinary initialization.
 check(f.session.open_panel().get("accepted",false),"original shop opens after required initial choices")
 var base_ad:float=f.sim.hero.stats.ad
 for _i in range(2):
  check(shop_command(f,"buy",{"item":"final:A05"}).get("accepted",false),"original commerce purchases supported A05")
 check(is_equal_approx(f.sim.hero.stats.ad-base_ad,110.0),"two A05 base AD stacks by original inventory counts")
 check(model.snapshot().content_profile=="ordinary_equipment33_potions3","new profile truthfully reports 33 supported equipment")
 check(model.snapshot().passive18_equipment.owned_copies==2,"both copies visible while passive remains unique")
 check(f.session.close_panel().get("accepted",false),"shop closes before real combat")
 if not enter(f,1): dispose(f);finish();return
 var targets:Array=[]
 for kind in ["minion","elite","boss"]:
  targets.append(f.sim.spawn_enemy(kind,Vector3(6,0,float(targets.size())*2.0-2.0),10000.0))
 step(f,90)
 for enemy:Dictionary in targets:
  check(enemy.state!="spawn" and not enemy.dead,"real director leaves spawn grace: "+enemy.kind)
 var ordinary:float=hit(f,targets[0],100.0)
 var elite:float=hit(f,targets[1],100.0)
 var boss:float=hit(f,targets[2],100.0)
 check(is_equal_approx(ordinary,100.0),"ordinary enemy receives no giant-hunter bonus")
 check(is_equal_approx(elite,112.0) and is_equal_approx(boss,112.0),"two owned copies apply only one 12% final multiplier")
 var target:Dictionary=targets[1]
 var replay:float=hit(f,target,112.0,{"replay":true})
 var snap:float=hit(f,target,112.0,{"snapshot_final":true})
 check(is_equal_approx(replay,112.0) and is_equal_approx(snap,112.0),"source replay and already-settled snapshots do not multiply again")
 var steps:Array=[]
 for ratio in [0.75,0.5,0.25]:
  hit(f,target,float(target.hp)-float(target.max_hp)*ratio,{"snapshot_final":true})
  var result:float=hit(f,target,100.0)
  var expected:float=100.0*(1.12+floor((1.0-ratio)/0.25)*0.02)
  check(is_equal_approx(result,expected),"real source target-health threshold gives "+str(expected))
  steps.append({"before_ratio":ratio,"actual":result,"expected":expected})
 var first:float=hit(f,target,20.0,{"effect_id":"a05-dedupe"})
 var second:float=hit(f,target,20.0,{"effect_id":"a05-dedupe"})
 check(first>0.0 and second==0.0,"same source effect claim cannot damage twice")
 evidence["source_damage"]={"ordinary":ordinary,"elite":elite,"boss":boss,"replay":replay,"snapshot_final":snap,"thresholds":steps,"duplicate_first":first,"duplicate_second":second}
 # The augmented damage fixture is intentionally not submitted for route rewards.
 # A fresh unmodified authored encounter owns the independent commerce checks.
 dispose(f)
 f=fresh()
 if f.is_empty():finish();return
 if not prepare_initial_choices(f):dispose(f);finish();return
 model=f.session.ledger.model
 model.state.gold=20000 # Same explicit test-only economy budget, second independent run.
 check(f.session.open_panel().get("accepted",false),"fresh original shop permits commerce checks")
 for _i in range(2):
  check(shop_command(f,"buy",{"item":"final:A05"}).get("accepted",false),"real shop buys A05 for independent removal check")
 for _i in range(2):
  var held:Dictionary=held_item(f,"final:A05")
  check(not held.is_empty(),"owned A05 available for original sell")
  if not held.is_empty(): check(shop_command(f,"sell",{"uid":held.uid}).get("accepted",false),"original sell removes one A05")
 check(held_item(f,"final:A05").is_empty(),"both copies removed")
 check(not model.snapshot().passive18_equipment.equipped,"selling last A05 clears passive immediately")
 check(is_equal_approx(model.passive18_multiplier({"rank_category":"boss","hp":50.0,"max_hp":100.0},{}),1.0),"removed equipment contributes no final multiplier")
 for component in ["intermediate:I04","intermediate:I11","base:B01"]:
  check(shop_command(f,"buy",{"item":component}).get("accepted",false),"original component purchase: "+component)
 var assembled:Dictionary=shop_command(f,"craft",{"item":"final:A05"})
 check(assembled.get("accepted",false) and int(assembled.get("charge",-1))==400,"original three-component recipe charges original 400 assembly fee")
 check(not held_item(f,"final:A05").is_empty(),"original craft produces A05")
 for component in ["intermediate:I04","intermediate:I11","base:B01"]:
  check(held_item(f,component).is_empty(),"original craft consumes exactly its held component: "+component)
 var crafted:Dictionary=held_item(f,"final:A05")
 if not crafted.is_empty(): check(shop_command(f,"sell",{"uid":crafted.uid}).get("accepted",false),"crafted final item sells through original ledger")
 check(not model.snapshot().passive18_equipment.equipped,"crafted copy removal also clears unique passive")
 evidence["craft_result"]=assembled
 check(f.session.close_panel().get("accepted",false),"original shop closes after sells")
 if enter(f,1):
  var after:Dictionary=f.sim.spawn_enemy("elite",Vector3(6,0,0),10000.0)
  step(f,90)
  check(is_equal_approx(hit(f,after,100.0),100.0),"next authentic combat has no stale A05 bonus")
 check_owners(f,"equipment33 end")
 dispose(f);finish()
func finish() -> void:
 var result:Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"check_records":check_records,"evidence":evidence,"economic_balance_fixture":true,"extra_spawned_targets_fixture":true,"real_source_damage":true,"original_factory_session":true,"natural_play":false,"source_binding_sha256":FileAccess.get_sha256(Binding.BINDING_PATH)}
 var file=FileAccess.open(output_path,FileAccess.WRITE)
 if file==null: quit(2);return
 file.store_string(JSON.stringify(result,"  "));file.close()
 print("EQUIPMENT33_SOURCE ",JSON.stringify(result));quit(0 if result.passed else 1)
