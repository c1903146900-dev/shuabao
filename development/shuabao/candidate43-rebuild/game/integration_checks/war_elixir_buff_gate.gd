extends "res://integration_checks/war_elixir_source_gate.gd"
## Explicit original-admitted-roster source damage fixture for bounded clock and
## rejection coverage. Real basic/P1 input consumers are separate later gates.
var war_buff_observations: Array = []
func _initialize() -> void:
 output_path="user://war_buff_gate.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--elixir-result="):output_path=arg.trim_prefix("--elixir-result=")
 run.call_deferred()
func raw(f: Dictionary) -> Dictionary:
 return f.sim.hero.cast_state.get("elixir_war_on_kill",{}).duplicate(true)
func view(f: Dictionary) -> Dictionary:
 return f.session.ledger.model.war_buff_effect(f.sim)
func now(f: Dictionary) -> float:
 return float(f.sim.common.runtime.actor_time)
func clock_to(f: Dictionary,target: float) -> bool:
 for i in range(400):
  if now(f)>=target:break
  if f.sim.phase!="combat" or f.sim.hero.dead or f.sim.paused:break
  step(f)
 return check(now(f)>=target and not f.sim.hero.dead,"original fixed steps reach clock target with original AI")
func projected(f: Dictionary,label: String) -> void:
 var base: Dictionary=f.sim.hero.projected_base_stats.duplicate(true)
 var original: Dictionary=f.sim.common.runtime.project_stats(base,f.sim.common.context())
 var b02: Dictionary=f.session.ledger.model.b02_buff_effect(f.sim)
 var expected: float=minf(float(original.attack_speed)+float(base.attack_speed)*float(b02.get("attack_speed_fraction",0.0)),float(f.sim.common.context().get("attack_speed_cap",2.5)))
 expected=minf(expected+float(base.attack_speed)*float(view(f).get("attack_speed_fraction",0.0)),float(f.sim.common.context().get("attack_speed_cap",2.5)))
 near_number(float(f.sim.hero.stats.attack_speed),expected,label+": complete original projection plus one war fraction")
 war_buff_observations.append({"label":label,"clock":now(f),"raw":raw(f),"view":view(f),"stats":f.sim.hero.stats.duplicate(true),"base":base})
func run() -> void:
 g03_reset_evidence()
 var f: Dictionary=funded_shop("war_buff_clock_source_fixture")
 if f.is_empty():finish_war();return
 var model=f.session.ledger.model
 if not buy(f,WAR) or not check(shop_command(f,"consume",{"uid":war_uid(f)}).accepted,"consume genuine war bottle") or not check(f.session.close_panel().accepted,"close original shop") or not enter(f,1) or not spawn_ready(f):dispose(f);finish_war();return
 check(raw(f).is_empty() and not view(f).get("active",false),"no kill means no AS buff")
 var target: Dictionary=f.sim.living()[0]
 var t0: float=now(f)
 lethal_enemy_fixture(f,target,"War clock fixture: real original roster source death")
 var first: Dictionary=raw(f)
 if not check(target.dead and not first.is_empty(),"one authenticated original death publishes buff"):dispose(f);finish_war();return
 near_number(float(first.granted_at),t0,"buff begins at exact owner clock")
 near_number(float(first.expires_at),t0+3.0,"first expiry exactly3 actor seconds")
 near_number(float(view(f).attack_speed_fraction),0.10,"one ten-percent bonus")
 projected(f,"first real death")
 var base: Dictionary=f.sim.hero.projected_base_stats.duplicate(true)
 for i in range(12):f.sim.common.refresh_stats();f.sim.refresh_passive23()
 check(base==f.sim.hero.projected_base_stats and raw(f)==first,"refresh does not bake stats or refresh duration")
 var event: Dictionary={}
 for e: Dictionary in f.sim.event_log:
  if e.get("kind","")=="kill" and e.get("target","")==target.actor_id:event=e.duplicate(true)
 if check(not event.is_empty(),"actual original kill remains in log"):
  var saved: Dictionary=model.state.duplicate(true)
  model.record_battle_event(f.sim,event,f.session.run_id)
  check(model.state==saved and raw(f)==first,"old actual event replay outside live emission cannot refresh")
 if not clock_to(f,t0+1.0):dispose(f);finish_war();return
 target=f.sim.living()[0]
 var t1: float=now(f)
 lethal_enemy_fixture(f,target,"War second distinct admitted-roster source death")
 var second: Dictionary=raw(f)
 if not check(target.dead and second!=first,"second real death refreshes same effect"):dispose(f);finish_war();return
 near_number(float(second.expires_at),t1+3.0,"refresh is current clock+3 not added duration")
 near_number(float(view(f).attack_speed_fraction),0.10,"second kill never stacks AS")
 projected(f,"second death refreshed")
 if not clock_to(f,float(second.expires_at)-0.04):dispose(f);finish_war();return
 check(view(f).get("active",false),"strictly before expiry remains active")
 if not clock_to(f,float(second.expires_at)):dispose(f);finish_war();return
 check(not view(f).get("active",false),"at or after3seconds effect expires")
 projected(f,"expired")
 check(f.sim.ai_enabled and f.sim.auto_finish,"original AI and completion remain enabled")
 dispose(f);finish_war()
func finish_war() -> void:
 var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"check_records":check_records,"failures":failures,"war_buff_observations":war_buff_observations,"wallet_fixture":true,"source_damage_fixture":true,"actual_native_input":false,"P1_verified":false,"basic_lifesteal_verified":false,"source_binding_sha256":FileAccess.get_sha256("res://visual_rework_20261009/binding/source_binding.json")}
 var file: FileAccess=FileAccess.open(output_path,FileAccess.WRITE)
 if file==null:quit(2);return
 file.store_string(JSON.stringify(report,"  "));var err: Error=file.get_error();file.close();quit(0 if report.passed and err==OK else 2)
