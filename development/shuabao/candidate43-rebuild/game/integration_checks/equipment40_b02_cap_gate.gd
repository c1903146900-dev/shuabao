extends "res://integration_checks/equipment40_source_gate.gd"
## Attack-speed saturation comes only from original legal purchases and offered
## irreversible body outcomes. No actor stat, projected base or buff is written.
var cap_completed: bool=false
var training_records: Array=[]
var cap_evidence: Dictionary={}

func _initialize() -> void:
 output_path="user://equipment40_b02_cap_gate.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--equipment-result="):output_path=arg.trim_prefix("--equipment-result=")
 run.call_deferred()

func actual_cap() -> void:
 current_group="original_commerce_body_attack_speed_cap"
 var f: Dictionary=funded_shop(current_group)
 if f.is_empty():return
 if not buy(f,"final:B02"):dispose(f);return
 for _copy: int in range(5):
  if not buy(f,"intermediate:I10"):dispose(f);return
 if not check(f.session.close_panel().get("accepted",false),"original six-slot cap fixture shop closes") or not enter(f,1) or not b04_settle_row(f,1) or not g02_open(f):dispose(f);return
 var model=f.session.ledger.model
 var raw: Dictionary=b02_raw(f)
 var now: float=b02_now(f)
 check(b02_view(f).active and owned_count(f,"final:B02")==1 and owned_count(f,"intermediate:I10")==5,"real last-row1 death grants B02 with six legal item slots")
 for attempt: int in range(50):
  if float(f.sim.hero.projected_base_stats.attack_speed)*1.20>2.5:break
  if int(model.state.gold)<int(model.commerce_definitions.body_price):break
  var paid: Dictionary=f.session._authority("pay_body",{"purchase_id":"b02-original-cap-body-%d"%attempt})
  if not check(paid.get("accepted",false),"original Session commerce pays one real body offer"):dispose(f);return
  var pending: Dictionary=model.snapshot().body_pending
  if not check(not pending.is_empty() and pending.candidates.size()==3,"original deterministic body pool offers three actual choices"):dispose(f);return
  var chosen: String=str(pending.candidates[0])
  for outcome: String in pending.candidates:
   if float(model.config.body.outcomes[outcome].stats.get("attack_speed",0.0))>0.0:chosen=outcome;break
  var selected: Dictionary=command(f,"select_body",{"purchase_id":pending.purchase_id,"outcome":chosen})
  if not check(selected.get("accepted",false),"original offered permanent body outcome commits"):dispose(f);return
  training_records.append({"purchase":paid,"offer":pending,"chosen":chosen,"source_stats":model.config.body.outcomes[chosen].stats.duplicate(true),"projected_attack_speed":f.sim.hero.projected_base_stats.attack_speed,"gold_after":model.state.gold})
  check(b02_now(f)==now and b02_raw(f)==raw,"real safe commerce does not refresh existing B02")
 var base: Dictionary=f.sim.hero.projected_base_stats.duplicate(true)
 if not check(float(base.attack_speed)*1.20>2.5,"legal item/body fixture actually exceeds original attack cap before clamp"):dispose(f);return
 near_number(float(f.sim.hero.stats.attack_speed),2.5,"actual derived attack stat clamps to original2.5cap")
 near_number(float(f.sim.hero.attack_speed()),2.5,"actual original actor attack_speed is capped")
 b02_projected(f,"legally saturated source projection")
 var cooldown: float=f.sim.hero.cooldowns.attack
 var stats: Dictionary=f.sim.hero.stats.duplicate(true)
 for _repeat: int in range(40):f.sim.common.refresh_stats();f.sim.refresh_passive23()
 check(f.sim.hero.projected_base_stats==base and f.sim.hero.stats==stats and f.sim.hero.cooldowns.attack==cooldown,"forty full refreshes preserve capped stats, exact base and current basic cooldown")
 cap_evidence={"inventory":model.state.inventory.duplicate(true),"body_purchases":model.state.body.duplicate(true),"base":base,"stats":stats,"raw_buff":raw,"clock":now,"ordinary_commerce":true,"direct_stat_writes":false}
 dispose(f);cap_completed=true

func run() -> void:
 evidence={"wallet_fixtures":[],"inputs":[],"cooldown_fixtures":[],"completions":[],"aborts":[],"victory":[],"postcompletion":[],"lifecycle":[],"isolated_common":[],"movement":[],"g02_deaths":[],"pre_damage":[],"inputs_g02":[],"p1_g02":{},"route_g02":{},"extra_actor_g02":{}}
 actual_cap();check(cap_completed,"real original commerce cap fixture completed")
 var report: Dictionary={"suite":"equipment40_B02_original_commerce_attack_cap","passed":failures.is_empty() and cap_completed,"checks":checks,"failures":failures,"check_records":check_records,"evidence":evidence,"training":training_records,"cap":cap_evidence,"productionSession":true,"original_Host_factories":true,"original_offered_body_outcomes":true,"attack_speed_cap_saturated":cap_completed,"wallet_fixture":true,"direct_stat_writes":false,"extra_actors":false,"native_GUI":false,"natural_play":false,"production_ready":false}
 var file: FileAccess=FileAccess.open(output_path,FileAccess.WRITE)
 if file==null:push_error("Unable to write B02 cap result");quit(2);return
 file.store_string(JSON.stringify(report,"  "));var error: Error=file.get_error();file.close()
 print("B02_ORIGINAL_CAP ",JSON.stringify({"passed":report.passed,"checks":checks,"failures":failures,"result":output_path}))
 quit(2 if error!=OK else (0 if report.passed else 1))
