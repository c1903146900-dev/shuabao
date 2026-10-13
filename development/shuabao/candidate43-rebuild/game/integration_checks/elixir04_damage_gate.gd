extends "res://integration_checks/elixir04_source_gate.gd"
## Original damage API with declared non-route, nonlethal spawn targets.
## Nominal packets and HP override are isolated fixtures, not natural skill play.
var damage_partition: String="single"
func _initialize() -> void:
 output_path="user://elixir04_damage.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--elixir-result="):output_path=arg.trim_prefix("--elixir-result=")
  if arg.begins_with("--elixir-damage="):damage_partition=arg.trim_prefix("--elixir-damage=")
 if damage_partition not in ["single","combined"]:quit(2);return
 run.call_deferred()
func hunter_damage() -> void:
 current_group="damage_"+damage_partition
 var f: Dictionary=funded_shop(current_group)
 if f.is_empty():return
 var model=f.session.ledger.model
 if damage_partition=="combined":
  if not buy(f,"final:A05") or not buy(f,"final:C06"):dispose(f);return
 if not buy(f,HUNTER) or not check(shop_command(f,"consume",{"uid":hunter_uid(f)}).accepted,"original pending elixir committed") or not check(f.session.close_panel().accepted,"original close") or not enter(f,1):dispose(f);return
 var targets: Array=[]
 for kind: String in ["minion","elite","boss"]:
  targets.append(f.sim.spawn_enemy(kind,f.sim.hero.position+Vector3(0,0,-9.0),10000.0))
 for tick in range(80):
  var spawning: bool=false
  for enemy: Dictionary in targets:spawning=spawning or enemy.state=="spawn"
  if not spawning:break
  step(f)
 var expected_pen: float=float(f.baseline.current_sim_stats.penetration)+20.0+(30.0 if damage_partition=="combined" else 0.0)
 near_number(float(f.sim.hero.stats.penetration),expected_pen,"actual original projected penetration includes elixir and constant C06 once")
 for enemy: Dictionary in targets:
  check(enemy.state!="spawn" and not enemy.dead,"original target birth complete "+str(enemy.kind))
  var distance: float=f.sim.hero.position.distance_to(enemy.position)
  var final_factor: float=1.0
  if enemy.kind in ["elite","boss"]:final_factor*=1.10*(1.12 if damage_partition=="combined" else 1.0)
  if damage_partition=="combined" and distance>=9.0:final_factor*=1.15
  var before: float=enemy.hp
  var meta: Dictionary={"fixture":true,"no_reactions":true,"generation":f.sim.encounter_generation,"room_id":f.sim.room_id}
  f.sim.damage_enemy(enemy,10.0,"hunter_elixir_original_damage_fixture",0,false,false,meta)
  var expected: float=10.0*final_factor*100.0/(100.0+maxf(0.0,float(enemy.defence)-expected_pen))
  near_number(before-float(enemy.hp),expected,"original nontrue packet matches mitigation and exactlyone final factor "+str(enemy.kind))
  hunter_records.append({"kind":enemy.kind,"distance":distance,"source_defence":enemy.defence,"expected_penetration":expected_pen,"expected_factor":final_factor,"actual":before-float(enemy.hp),"expected":expected,"fixture_target_not_route_reward_eligible":true})
  for flag: String in ["snapshot_final","replay"]:
   before=enemy.hp
   var finalized: Dictionary=meta.duplicate(true);finalized[flag]=true
   if flag=="replay":finalized.saved_stats={"penetration":expected_pen}
   f.sim.damage_enemy(enemy,10.0,"hunter_elixir_finalized_fixture",0,true,false,finalized)
   near_number(before-float(enemy.hp),10.0,"finalized true packet is not multiplied again: "+str(enemy.kind)+" "+flag)
 check(f.sim.ai_enabled and f.sim.auto_finish and not f.sim.hero.dead,"original AI/terminal retained during finite fixture")
 dispose(f);hunter_done.append(current_group)
func run() -> void:
 g03_reset_evidence();hunter_damage();await process_frame
 check(hunter_done==["damage_"+damage_partition],"requested source damage group complete")
 var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"check_records":check_records,"failures":failures,"records":hunter_records,"wallet_fixture":true,"extra_spawn_HP_and_nominal_damage_fixture":true,"real_G18_admitted":false,"actual_P1_covered_by_this_gate":false,"natural_play":false,"source_binding_sha256":FileAccess.get_sha256("res://visual_rework_20261009/binding/source_binding.json")}
 var file: FileAccess=FileAccess.open(output_path,FileAccess.WRITE)
 if file==null:quit(2);return
 file.store_string(JSON.stringify(report,"  "));var error: Error=file.get_error();file.close();quit(0 if report.passed and error==OK else 2)
