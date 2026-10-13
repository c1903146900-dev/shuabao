extends "res://integration_checks/equipment40_source_gate.gd"
## Exact original Session notification reentry plus original rest/new-run edges.
## No extra actors, fake owner, direct Model fallback, or state-field setup.
var reentry_completed: bool=false
var reentry_evidence: Dictionary={}

func _initialize() -> void:
 output_path="user://equipment40_b02_reentry_gate.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--equipment-result="):output_path=arg.trim_prefix("--equipment-result=")
 run.call_deferred()

func on_event(event: Dictionary,f: Dictionary) -> void:
 if f.get("b02_reentry_armed",false) and event.get("kind","")=="kill" and event.get("target","")==f.get("b02_reentry_target",""):
  f.b02_reentry_armed=false
  var before: Dictionary=b02_raw(f)
  var receipts: int=b02_receipts(f).size()
  f.b02_synthetic=true;f.g02_synthetic=true
  f.sim.emit_event("kill",event.duplicate(true))
  f.g02_synthetic=false;f.b02_synthetic=false
  check(b02_raw(f)==before and b02_receipts(f).size()==receipts,"same callback public kill copy cannot borrow outer dynamic witness or refresh B02")
  f["outer_original_event"]=event.duplicate(true)
  var inner: Dictionary=f.b02_reentry_inner
  f.sim.damage_enemy(inner,float(inner.hp)+100000.0,str(event.source),int(event.cast_id),true,false,{"fixture":true,"direct":true,"active_skill":true,"no_reactions":true,"generation":f.sim.encounter_generation,"room_id":f.sim.room_id})
  check(inner.dead,"nested real packet actually kills a distinct original admitted actor")
  f["after_inner_before_outer"]=b02_raw(f)
 super.on_event(event,f)

func actual_reentry() -> void:
 current_group="original_nested_death_rest_replay_newrun"
 var f: Dictionary=b02_start(current_group,2)
 if f.is_empty():return
 var actors: Array=f.sim.enemies.duplicate()
 f["b02_reentry_target"]=str(actors[0].actor_id)
 f["b02_reentry_inner"]=actors[1]
 f["b02_reentry_armed"]=true
 var context: Dictionary=f.sim.new_cast("q","b02_original_nested_death_fixture")
 f.sim.start_skill_cooldown("q",10.0)
 var gold: int=f.session.ledger.model.state.gold
 var r0: Dictionary=f.session.ledger.model.reward_for_kind(str(actors[0].kind))
 var r1: Dictionary=f.session.ledger.model.reward_for_kind(str(actors[1].kind))
 f.sim.damage_enemy(actors[0],float(actors[0].hp)+100000.0,"q1",int(context.cast_id),true,false,{"fixture":true,"direct":true,"active_skill":true,"no_reactions":true,"generation":f.sim.encounter_generation,"room_id":f.sim.room_id})
 if not check(not f.b02_reentry_armed and actors[0].dead and actors[1].dead,"actual original outer and nested source deaths both committed"):dispose(f);return
 var real: Array=[]
 for record: Dictionary in f.b02_kills:
  if not record.synthetic and not record.witness.is_empty():real.append(record)
 check(real.size()==2 and b02_receipts(f).size()==2,"two original death witnesses produce two distinct B02 command receipts")
 check(f.session.kill_receipts.size()==2 and f.session.ledger.model.state.gold==gold+int(r0.gold)+int(r1.gold),"original nested and outer Session rewards each pay once")
 check(f.session.ledger.model.state.b02_death_claims.by_target.size()==2,"same-cast distinct original targets retain independent B02 claims")
 check(real.size()==2 and int(real[0].event.sequence)>int(real[1].event.sequence),"newer nested notification may settle before older valid outer notification")
 near_number(float(b02_raw(f).expires_at),b02_now(f)+4.0,"same-clock nested deaths retain one four-second effect")
 check(b02_raw(f).last_death_commit_id!=f.after_inner_before_outer.last_death_commit_id,"outer genuine death remains eligible after nested original claim")
 b02_projected(f,"original nested death projection")
 var old_event: Dictionary=f.outer_original_event.duplicate(true)
 if not b04_settle_row(f,1) or not enter(f,2) or not b04_settle_row(f,2):dispose(f);return
 var before_rest: Dictionary=b02_raw(f)
 var receipts: Array=b02_receipts(f)
 if not enter(f,3) or not check(f.session.complete_service().get("accepted",false),"actual rest settles before historical command replay"):dispose(f);return
 check(not f.sim.hero.cast_state.has(B02_KEY),"actual rest removes the current real effect")
 var model=f.session.ledger.model
 var state_before: PackedByteArray=var_to_bytes(model.state)
 for receipt: Dictionary in receipts:
  var replay: Dictionary=model.command(receipt.id,receipt.request.action,receipt.request.args)
  check(replay.get("accepted",false) and replay.get("replayed",false),"original historical B02 command returns its idempotent receipt")
 check(not f.sim.hero.cast_state.has(B02_KEY) and var_to_bytes(model.state)==state_before,"all prior accepted command receipts cannot rehydrate rested buff or rewrite claims")
 if not enter(f,4) or not spawn_ready(f):dispose(f);return
 var before_old: Dictionary=b02_raw(f)
 var rejected: Dictionary=f.session.observe_event(f.sim,old_event)
 check(not rejected.get("accepted",false) and b02_raw(f)==before_old,"old-room event is rejected by actual Session without a Model fallback")
 if b02_kill(f,f.sim.living()[0]).is_empty():dispose(f);return
 check(b02_view(f).active and b02_raw(f).origin_scope.room_id==f.sim.room_id,"fresh original death after rest grants only current-room entitlement")
 var issued: Dictionary=b02_raw(f)
 var old_owner: int=f.sim.hero.get_instance_id()
 var old_model: int=model.get_instance_id()
 f.sim.damage_hero(float(f.sim.hero.hp)+100000.0,Vector3.ZERO,0.0,true,true,{"source":"b02_original_death_fixture","fixture":true})
 f.session.update_after_source_step()
 check(f.sim.hero.dead and not b02_view(f).active,"original true death disables prior issued effect")
 reentry_evidence={"real_nested_deaths":real,"prior_to_rest":before_rest,"old_scope_denial":rejected,"after_rest_real_grant":issued,"original_owner_death":true,"old_buff_raw_after_death":b02_raw(f),"source_API_fixture":true,"direct_Model_after_Session_denial":false}
 dispose(f)
 var restarted: Dictionary=funded_shop("original fresh run after actual B02 owner death")
 if restarted.is_empty():return
 check(restarted.sim.hero.get_instance_id()!=old_owner and restarted.session.ledger.model.get_instance_id()!=old_model,"official fresh Host factories construct new source owner and Model")
 check(b02_raw(restarted).is_empty() and not b02_view(restarted).active and restarted.session.ledger.model.state.get("b02_death_claims",{}).is_empty(),"new original run starts without prior buff or death claims")
 dispose(restarted);reentry_completed=true

func run() -> void:
 evidence={"wallet_fixtures":[],"inputs":[],"cooldown_fixtures":[],"completions":[],"aborts":[],"victory":[],"postcompletion":[],"lifecycle":[],"isolated_common":[],"movement":[],"g02_deaths":[],"pre_damage":[],"inputs_g02":[],"p1_g02":{},"route_g02":{},"extra_actor_g02":{}}
 actual_reentry();check(reentry_completed,"original nested/rest/replay/newrun boundaries completed")
 var report: Dictionary={"suite":"equipment40_B02_original_reentry_rest_newrun","passed":failures.is_empty() and reentry_completed,"checks":checks,"failures":failures,"check_records":check_records,"evidence":evidence,"reentry":reentry_evidence,"b02_deaths":b02_records,"productionSession":true,"original_Host_factories":true,"extra_actors":false,"source_API_packet_fixture":true,"direct_Model_after_Session_denial":false,"actor_stat_or_buff_fields_written":false,"native_GUI":false,"natural_play":false,"production_ready":false}
 var file: FileAccess=FileAccess.open(output_path,FileAccess.WRITE)
 if file==null:push_error("Unable to write B02 reentry result");quit(2);return
 file.store_string(JSON.stringify(report,"  "));var error: Error=file.get_error();file.close()
 print("B02_ORIGINAL_REENTRY ",JSON.stringify({"passed":report.passed,"checks":checks,"failures":failures,"result":output_path}))
 quit(2 if error!=OK else (0 if report.passed else 1))
