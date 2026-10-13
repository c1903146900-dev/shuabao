extends "res://integration_checks/training12_g03_regression_gate.gd"
## Original Host/Session, roster, clock, health observer and commerce.
## Parent alone copies/seals and runs this gate. No engine execution by author.
const E03_ITEM := "final:E03"
const E03Prior = preload("res://equipment_blood_trial_20261009/adapter.gd")
const E03_GROUPS := ["definitions_commerce", "natural_regen_threshold", "combat_lifecycle"]
var e03_required: Array = E03_GROUPS.duplicate()
var e03_completed: Array = []
var e03_partition: String = "all"
var e03_records: Array = []
var e03_source_fixtures: Array = []

func _initialize() -> void:
 output_path = "user://equipment43_source_gate.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--equipment-result="): output_path = arg.trim_prefix("--equipment-result=")
  if arg.begins_with("--e03-source-group="): e03_partition = arg.trim_prefix("--e03-source-group=")
 if e03_partition != "all":
  if e03_partition not in E03_GROUPS: push_error("Unknown E03 source group");quit(2);return
  e03_required = [e03_partition]
 run.call_deferred()

func funded_shop(label: String) -> Dictionary:
 var f: Dictionary = super.funded_shop(label)
 if f.is_empty(): return {}
 f["e03_clock_id"] = f.sim.common.runtime.get_instance_id()
 f["e03_common_id"] = f.sim.common.get_instance_id()
 f["e03_combat_start"] = -1.0
 if not check(f.sim.e03_model_is_bound(f.session.ledger.model) and f.session.ledger.model.equipment_runtime_status(E03_ITEM).get("runtime_complete",false),"E03 is bound to original same Model before shop admission"):
  dispose(f);return {}
 var script: Script = f.sim.common.get_script()
 for path: String in ["res://equipment_regeneration_20261009/common_bridge.gd","res://equipment_pursuit_20261009/common_bridge.gd","res://tests/ink_p2_ordinary_20261006/mechanism01/p2_common_bridge.gd","res://tests/ink_e3_exchange_foundation_20261005/candidate03/exchange_common_bridge.gd","res://tests/ink_e2_boat_foundation_20261005/candidate04/boat_common_bridge.gd","res://tests/ink_e1_rain_foundation_20261005/rain_common_bridge.gd","res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_common_bridge.gd","res://scripts/combat/common_hex_bridge.gd"]:
  if not check(script != null and script.resource_path == path,"exact E03 Common ancestor " + path):dispose(f);return {}
  script = script.get_base_script()
 return f

func e03_view(f: Dictionary) -> Dictionary:
 return f.session.ledger.model.regeneration_status().duplicate(true)

func e03_now(f: Dictionary) -> float:
 return float(f.sim.common.runtime.actor_time)

func e03_near(actual: float, expected: float, label: String) -> bool:
 return check(is_finite(actual) and absf(actual-expected) <= 0.00000001,label+" actual="+str(actual)+" expected="+str(expected))

func e03_base_regen(f: Dictionary) -> float:
 # Independent original source + actual selected equipment/body/static-Hex
 # aggregate. Never use the E03 runtime's own factor to predict its HP commit.
 var source: Dictionary = ORIGINAL_INK_TUNING.hero_stats()
 return float(source.regen) + float(f.session.ledger.model.aggregate_effects().stats.get("hp_regen",0.0))

func e03_projection(f: Dictionary, label: String) -> void:
 var base: float = e03_base_regen(f)
 var elapsed: float = maxf(0.0,e03_now(f)-float(f.e03_combat_start)) if float(f.e03_combat_start)>=0.0 else 0.0
 var active: bool = owned_count(f,E03_ITEM)>0 and f.sim.phase=="combat" and not f.sim.hero.dead and elapsed>=6.0
 var view: Dictionary = e03_view(f)
 check(bool(view.active)==active,label+": exact current condition without EPS advance")
 e03_near(float(view.factor),2.0 if active else 1.0,label+": instantaneous factor is distinct from interval average")
 e03_near(float(f.sim.hero.projected_base_stats.regen),base,label+": original projected regen is never amplified in place")
 e03_near(float(f.sim.hero.stats.regen),base*(2.0 if active else 1.0),label+": exactly one held passive affects current natural regen")
 check(f.sim.common.runtime.get_instance_id()==f.e03_clock_id and f.sim.common.get_instance_id()==f.e03_common_id,label+": original runtime clock and bridge remain the same objects")

func e03_damage_deficit(f: Dictionary, deficit: float, label: String) -> bool:
 var max_hp: float = float(f.sim.hero.stats.max_hp)
 var target_hp: float = max_hp - deficit
 if not check(target_hp>0.0 and target_hp<max_hp,label+": explicit source HP fixture remains living"):return false
 var before: float = float(f.sim.hero.hp)
 if before>target_hp:
  f.sim.damage_hero(before-target_hp+float(f.sim.hero.shield_total()),Vector3.ZERO,0.0,true,true,{"source":"equipment43_incoming_fixture","fixture":true,"direct":false,"generation":f.sim.encounter_generation,"room_id":f.sim.room_id})
 elif before<target_hp:
  f.sim.heal(target_hp-before,false,{"source":"equipment43_explicit_heal_fixture","fixture":true})
 e03_source_fixtures.append({"label":label,"before":before,"after":f.sim.hero.hp,"target":target_hp,"original_API":"damage_hero_or_heal","direct_HP_write":false})
 return e03_near(float(f.sim.hero.hp),target_hp,label+": original source health commit")

func e03_enter(f: Dictionary, row: int) -> bool:
 var at: float = e03_now(f)
 if not enter(f,row):return false
 if not check(f.sim.phase=="combat","E03 fixture enters an original combat node"):return false
 f.e03_combat_start=at
 e03_near(float(e03_view(f).combat_started_at),at,"E03 starts from original clock at actual combat entry")
 e03_projection(f,"new original combat")
 return true

func e03_tick(f: Dictionary, label: String) -> bool:
 if not check(f.sim.phase=="combat" and not f.sim.paused and not f.sim.hero.dead,label+": same living unpaused original encounter"):return false
 var before_clock: float = e03_now(f)
 var before_hp: float = float(f.sim.hero.hp)
 var before_events: int = f.events.size()
 var before_revision: int = int(f.sim.equipment_health_revision)
 var base: float = e03_base_regen(f)
 var max_hp: float = float(f.sim.hero.stats.max_hp)
 var eligible: bool = owned_count(f,E03_ITEM)>0
 step(f)
 var after_clock: float = e03_now(f)
 var dt: float = after_clock-before_clock
 var boundary: float = float(f.e03_combat_start)+6.0
 var boosted_dt: float = maxf(0.0,after_clock-maxf(before_clock,boundary)) if eligible else 0.0
 var requested_regen: float = base*(dt+boosted_dt)
 var actual_regen: float = minf(maxf(0.0,max_hp-before_hp),requested_regen)
 var incoming: float = 0.0
 var incoming_commits: int = 0
 for event: Dictionary in f.events.slice(before_events):
  if event.get("kind")=="damage" and event.get("target")==f.sim.hero.actor_id:
   incoming+=float(event.amount)
   if float(event.amount)>0.0:incoming_commits+=1
 # This group fires no attacks, skills or potion. Its only positive health
 # source is the one original regeneration call before AI's incoming damage.
 var inferred: float = float(f.sim.hero.hp)-before_hp+incoming
 e03_near(inferred,actual_regen,label+": independent original HP loss-adjusted natural regen")
 check(int(f.sim.equipment_health_revision)-before_revision==incoming_commits+(1 if actual_regen>0.0 else 0),label+": one original effective regen commit, not a second bonus heal")
 e03_projection(f,label)
 if before_clock<boundary and after_clock>=boundary or absf(after_clock-boundary)<0.05:
  e03_records.append({"kind":"threshold_tick","label":label,"before_clock":before_clock,"after_clock":after_clock,"combat_start":f.e03_combat_start,"boundary":boundary,"base_regen":base,"boosted_dt":boosted_dt,"requested":requested_regen,"actual":inferred,"incoming":incoming,"before_hp":before_hp,"after_hp":f.sim.hero.hp,"view":e03_view(f)})
 return check(not f.sim.hero.dead and f.session.fault.is_empty(),label+": fixture remains alive and original Session accepts source")

func e03_until(f: Dictionary, elapsed_target: float, label: String) -> bool:
 for index: int in range(500):
  if e03_now(f)-float(f.e03_combat_start)>=elapsed_target:return true
  if float(f.sim.hero.hp)<float(f.sim.hero.stats.max_hp)*0.35:
   if not e03_damage_deficit(f,150.0,label+" survival fixture"):return false
  if not e03_tick(f,label+" tick"+str(index)):return false
 return check(false,label+": bounded original fixed steps reach target")

func e03_start(label: String, copies: int=1) -> Dictionary:
 var f: Dictionary=funded_shop(label)
 if f.is_empty():return {}
 for _copy: int in range(copies):
  if not buy(f,E03_ITEM):dispose(f);return {}
 if not buy(f,"base:B12") or not check(f.session.close_panel().get("accepted",false),"E03 original shop closes") or not e03_enter(f,1) or not spawn_ready(f):dispose(f);return {}
 var target: Dictionary=b04_keep_original(f)
 if target.is_empty() or not e03_damage_deficit(f,150.0,"natural regen missing HP fixture"):dispose(f);return {}
 f["e03_original_target"]=target
 return f

func e03_definitions() -> void:
 current_group=E03_GROUPS[0]
 var f: Dictionary=funded_shop(current_group)
 if f.is_empty():return
 var model=f.session.ledger.model
 var prior: Dictionary=E03Prior.build(JSON.parse_string(FileAccess.get_file_as_string(B01_NUMERIC)))
 if not check(prior.get("accepted",false),"original G03 adapter accepts unchanged authority"):dispose(f);return
 check(model.runtime_stat_definitions.size()==prior.definitions.size()+1,"E03 adds one full equipment definition to42")
 for id: String in prior.definitions:check(var_to_bytes(prior.definitions[id])==var_to_bytes(model.runtime_stat_definitions.get(id,{})),"prior42 definition byte-identical "+id)
 var count: int=0
 for definition: Dictionary in model.runtime_stat_definitions.values():
  if definition.get("supported",false):count+=1
 check(count==43 and model.snapshot().content_profile=="ordinary_equipment43_potions3","truthful43 admitted equipment")
 var status: Dictionary=model.equipment_runtime_status(E03_ITEM)
 check(status.stats=={"max_hp":420.0,"hp_regen":1.6,"cooldown_reduction":0.15} and status.passives==["passive:24"] and status.actives.is_empty(),"originalE03 HP420 regen8per5 CDR15 and onlypassive24")
 var gold: int=model.state.gold
 var hp: float=f.sim.hero.hp
 if not buy(f,E03_ITEM) or not buy(f,E03_ITEM):dispose(f);return
 check(model.state.gold==gold-6200 and owned_count(f,E03_ITEM)==2 and f.sim.hero.hp==hp,"two original3100 copies paid once; HP addition doesnotheal")
 e03_near(float(model.equipment_effects().stats.get("hp_regen",0.0))-float(f.baseline.equipment.stats.get("hp_regen",0.0)),3.2,"two static regen8per5 copies")
 e03_near(float(model.equipment_effects().stats.max_hp)-float(f.baseline.equipment.stats.get("max_hp",0.0)),840.0,"two static420HP copies")
 e03_projection(f,"safe dualcopy")
 sell(f,E03_ITEM);e03_projection(f,"safe onecopy");undo(f)
 check(owned_count(f,E03_ITEM)==2,"original saleundo restores secondcopy")
 undo(f);undo(f)
 check(owned_count(f,E03_ITEM)==0,"both purchaseundos remove E03")
 if not buy(f,"intermediate:I12") or not buy(f,"intermediate:I05") or not buy(f,"base:B06"):dispose(f);return
 gold=model.state.gold
 var crafted: Dictionary=shop_command(f,"craft",{"item":E03_ITEM})
 check(crafted.get("accepted",false) and model.state.gold==gold-400 and owned_count(f,E03_ITEM)==1 and owned_count(f,"intermediate:I12")==0 and owned_count(f,"intermediate:I05")==0 and owned_count(f,"base:B06")==0,"original I12+I05+B06 craft consumes exactcomponents and400fee")
 undo(f)
 check(owned_count(f,E03_ITEM)==0 and owned_count(f,"intermediate:I12")==1 and owned_count(f,"intermediate:I05")==1 and owned_count(f,"base:B06")==1,"original craftundo restores allthreecomponents")
 e03_projection(f,"safe noE03")
 b04_integrity(f,current_group);dispose(f);e03_completed.append(current_group)

func e03_natural() -> void:
 current_group=E03_GROUPS[1]
 var f: Dictionary=e03_start(current_group,2)
 if f.is_empty():return
 if not e03_until(f,5.9,"before6"):dispose(f);return
 var before: Dictionary={"hp":f.sim.hero.hp,"clock":e03_now(f),"view":e03_view(f),"base":f.sim.hero.projected_base_stats.duplicate(true)}
 check(f.session.set_modal_blocked(true).get("accepted",false),"original Session modal pauses combat before6")
 step(f,24)
 check(f.sim.hero.hp==before.hp and e03_now(f)==before.clock and e03_view(f)==before.view,"original pause advances neither naturalregen nor sixsecondcondition")
 check(f.session.set_modal_blocked(false).get("accepted",false),"original Session modal resumes originalcombat")
 if not e03_until(f,6.1,"cross6"):dispose(f);return
 var active: Dictionary=e03_view(f)
 var hp: float=f.sim.hero.hp
 var base: Dictionary=f.sim.hero.projected_base_stats.duplicate(true)
 for _repeat: int in range(5):f.sim.common.begin_room();f.sim.common.refresh_stats()
 check(e03_view(f)==active and f.sim.hero.hp==hp and f.sim.hero.projected_base_stats==base,"samecombat begin_room and repeatedrefresh do not restart6 or multiply projectedbase")
 e03_projection(f,"afterrepeat")
 # A generic source heal is an explicit fixture; E03 must not amplify it.
 var healed: float=f.sim.heal(7.0,false,{"source":"equipment43_direct_heal_fixture","fixture":true})
 e03_near(healed,7.0,"active E03 doesnot double explicit nonregen heal")
 e03_near(float(f.sim.hero.hp)-hp,7.0,"original genericheal changes HP by exactlyseven")
 e03_source_fixtures.append({"original_API":"heal","requested":7.0,"actual":healed,"E03_active":true,"natural_regen":false})
 if not e03_tick(f,"active nexttick"):dispose(f);return
 b04_integrity(f,current_group);dispose(f);e03_completed.append(current_group)

func e03_lifecycle() -> void:
 current_group=E03_GROUPS[2]
 var f: Dictionary=e03_start(current_group)
 if f.is_empty():return
 if not e03_until(f,6.05,"firstcombat") or not b04_settle_row(f,1):dispose(f);return
 check(not e03_view(f).active and f.sim.phase=="victory","original true terminal immediately removes E03 condition")
 e03_projection(f,"terminal")
 var now: float=e03_now(f)
 var hp: float=f.sim.hero.hp
 step(f,20)
 check(e03_now(f)==now and f.sim.hero.hp==hp,"safephase neither advances combatclock nor naturalregen")
 if not g02_open(f):dispose(f);return
 sell(f,E03_ITEM);e03_projection(f,"soldempty")
 buy(f,E03_ITEM);e03_projection(f,"reboughtsafe")
 undo(f);check(owned_count(f,E03_ITEM)==0,"repurchaseundo removes item without restoring oldcombat")
 undo(f);check(owned_count(f,E03_ITEM)==1,"saleundo restores helditem only")
 if not check(f.session.close_panel().get("accepted",false),"lifecycle shopcloses") or not e03_enter(f,2) or not spawn_ready(f):dispose(f);return
 check(e03_now(f)>6.0 and not e03_view(f).active,"new original combat waits6 despite runclock already above6")
 if not e03_damage_deficit(f,150.0,"secondcombat deficit") or not e03_tick(f,"secondcombat firstsample"):dispose(f);return
 e03_records.append({"kind":"original_shop_next_room","view":e03_view(f),"run_clock":e03_now(f),"combat_start":f.e03_combat_start,"original_roster":f.session.expected_enemies.duplicate(true)})
 b04_integrity(f,current_group);dispose(f);e03_completed.append(current_group)

func e03_report() -> void:
 check(e03_completed==e03_required,"all selected E03 originalsource groups complete")
 var report: Dictionary={"suite":"equipment43_original_source","passed":failures.is_empty() and e03_completed==e03_required,"checks":checks,"failures":failures,"check_records":check_records,"partition":e03_partition,"required_groups":e03_required,"completed_groups":e03_completed,"e03_records":e03_records,"fixtures":e03_source_fixtures,"evidence":evidence,"productionSession":true,"original_Host_factories":true,"extra_actors":false,"wallet_fixture":true,"source_API_fixtures":true,"direct_HP_stats_rank_position_AI_generation_clock_writes":false,"natural_play":false,"native_GUI":false,"production_ready":false}
 var file: FileAccess=FileAccess.open(output_path,FileAccess.WRITE)
 if file==null:push_error("Cannot write E03 source result");quit(2);return
 file.store_string(JSON.stringify(report,"  "));var error: Error=file.get_error();file.close()
 print("E03_ORIGINAL_SOURCE ",JSON.stringify({"passed":report.passed,"checks":checks,"failures":failures,"result":output_path}))
 quit(2 if error!=OK else (0 if report.passed else 1))

func run() -> void:
 g03_reset_evidence()
 if E03_GROUPS[0] in e03_required:e03_definitions()
 if E03_GROUPS[1] in e03_required:e03_natural()
 if E03_GROUPS[2] in e03_required:e03_lifecycle()
 e03_report()
