extends "res://integration_checks/war_elixir_source_gate.gd"
## Only original paid inventory/training outcomes build the base AS. The wallet
## and the one source-lethal roster packet are explicit bounded fixtures.
var cap_records: Array=[]
var offers: Array=[]
func _initialize() -> void:
 output_path="user://war_b02_cap.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--elixir-result="):output_path=arg.trim_prefix("--elixir-result=")
 run.call_deferred()
func cap_case() -> void:
 var f: Dictionary=funded_shop("war_b02_cap")
 if f.is_empty():return
 var model=f.session.ledger.model
 if not buy(f,"final:B02"):dispose(f);return
 for i in range(5):
  if not buy(f,"intermediate:I10"):dispose(f);return
 for attempt in range(50):
  if float(f.sim.hero.projected_base_stats.attack_speed)*1.30>2.5:break
  if int(model.state.gold)<900:break
  var paid: Dictionary=f.session._authority("pay_body",{"purchase_id":"war-cap-training-%d"%attempt})
  if not check(paid.accepted,"original900 training offer paid"):dispose(f);return
  var pending: Dictionary=model.snapshot().body_pending
  if not check(not pending.is_empty() and pending.candidates.size()==3,"real training12 offer has three choices"):dispose(f);return
  var chosen: String=str(pending.candidates[0])
  for id: String in pending.candidates:
   if float(model.config.body.outcomes[id].stats.get("attack_speed",0.0))>0.0:chosen=id;break
  var selected: Dictionary=command(f,"select_body",{"purchase_id":pending.purchase_id,"outcome":chosen})
  if not check(selected.accepted,"one actual offered outcome selected"):dispose(f);return
  offers.append({"pending":pending,"chosen":chosen,"source_stats":model.config.body.outcomes[chosen].stats.duplicate(true),"gold":model.state.gold,"base":f.sim.hero.projected_base_stats.duplicate(true)})
 if not check(float(f.sim.hero.projected_base_stats.attack_speed)*1.30>2.5,"legal purchase/training actually reaches combined cap range"):dispose(f);return
 if not buy(f,WAR):dispose(f);return
 check(model.state.inventory.size()==6 and model.war_elixir_status().pending,"full six equipment slots auto-drink war without replacing items")
 if not check(f.session.close_panel().accepted,"original shop closes") or not enter(f,1) or not spawn_ready(f):dispose(f);return
 lethal_enemy_fixture(f,f.sim.living()[0],"war+B02 real admitted-roster kill fixture")
 var war: Dictionary=model.war_buff_effect(f.sim)
 var b02: Dictionary=model.b02_buff_effect(f.sim)
 if not check(war.get("active",false) and b02.get("active",false),"one authenticated death grants separate war and equipped B02"):dispose(f);return
 near_number(float(war.attack_speed_fraction),0.10,"war only10percent")
 near_number(float(b02.attack_speed_fraction),0.20,"B02 remains20percent")
 var base: Dictionary=f.sim.hero.projected_base_stats.duplicate(true)
 var inherited: Dictionary=f.sim.common.runtime.project_stats(base,f.sim.common.context())
 var expected: float=minf(float(inherited.attack_speed)+float(base.attack_speed)*0.30,2.5)
 near_number(float(f.sim.hero.stats.attack_speed),expected,"two independent original-base fractions and originalcap")
 near_number(float(f.sim.hero.attack_speed()),2.5,"actual actor speed consumer capped at2.5")
 var stats: Dictionary=f.sim.hero.stats.duplicate(true)
 var cooldown: float=f.sim.hero.cooldowns.attack
 for i in range(30):f.sim.common.refresh_stats();f.sim.refresh_passive23()
 check(f.sim.hero.projected_base_stats==base and f.sim.hero.stats==stats and f.sim.hero.cooldowns.attack==cooldown,"repeated projection keeps base and current basic cooldown")
 cap_records.append({"war":war,"b02":b02,"base":base,"stats":stats,"expected":expected,"inventory":model.state.inventory.duplicate(true)})
 dispose(f)
func run() -> void:
 g03_reset_evidence();cap_case();await process_frame
 check(cap_records.size()==1,"combined actual cap fixture completed")
 var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"check_records":check_records,"failures":failures,"offers":offers,"records":cap_records,"economic_fixture":true,"source_lethal_fixture":true,"direct_stats_written":false,"natural_play":false,"source_binding_sha256":FileAccess.get_sha256("res://visual_rework_20261009/binding/source_binding.json")}
 var file: FileAccess=FileAccess.open(output_path,FileAccess.WRITE)
 if file==null:quit(2);return
 file.store_string(JSON.stringify(report,"  "));var err: Error=file.get_error();file.close();quit(0 if report.passed and err==OK else 2)
