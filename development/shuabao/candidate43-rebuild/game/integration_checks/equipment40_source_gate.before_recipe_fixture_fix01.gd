extends "res://integration_checks/equipment40_g02_regression_gate.gd"
## Original Host/Session and admitted roster. Parent alone runs the engine.
const B02Prior = preload("res://equipment_training_20261009/adapter.gd")
const B02_GROUPS := ["definitions_and_commerce", "actual_birth_refresh_expiry", "sale_rebuy_unequipped", "crossroom_safe_pause_rest", "source_and_command_replays"]
const B02_KEY := "equipment_passive28"
var b02_required: Array = B02_GROUPS.duplicate()
var b02_done_groups: Array = []
var b02_partition: String = "all"
var b02_records: Array = []

func _initialize() -> void:
 output_path = "user://equipment40_source_gate.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--equipment-result="): output_path = arg.trim_prefix("--equipment-result=")
  if arg.begins_with("--b02-source-group="): b02_partition = arg.trim_prefix("--b02-source-group=")
 if b02_partition != "all":
  if b02_partition not in B02_GROUPS: push_error("Unknown B02 source group"); quit(2); return
  b02_required = [b02_partition]
 run.call_deferred()

func funded_shop(label: String) -> Dictionary:
 var f: Dictionary = super.funded_shop(label)
 if f.is_empty(): return {}
 f["b02_kills"] = []
 f["b02_synthetic"] = false
 f["b02_clock_id"] = f.sim.common.runtime.get_instance_id()
 f["b02_common_id"] = f.sim.common.get_instance_id()
 if not check(f.sim.b02_model_is_bound(f.session.ledger.model) and f.session.ledger.model.equipment_runtime_status("final:B02").get("runtime_complete", false), "B02 exact original death/common/stat/clock binding"):
  dispose(f); return {}
 var chain: Script = f.sim.common.get_script()
 for path: String in ["res://equipment_pursuit_20261009/common_bridge.gd", "res://tests/ink_p2_ordinary_20261006/mechanism01/p2_common_bridge.gd", "res://tests/ink_e3_exchange_foundation_20261005/candidate03/exchange_common_bridge.gd", "res://tests/ink_e2_boat_foundation_20261005/candidate04/boat_common_bridge.gd", "res://tests/ink_e1_rain_foundation_20261005/rain_common_bridge.gd", "res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_common_bridge.gd", "res://scripts/combat/common_hex_bridge.gd"]:
  if not check(chain != null and chain.resource_path == path, "exact unchanged Common ancestor " + path): dispose(f); return {}
  chain = chain.get_base_script()
 return f

func b02_raw(f: Dictionary) -> Dictionary:
 return f.sim.hero.cast_state.get(B02_KEY, {}).duplicate(true)

func b02_view(f: Dictionary) -> Dictionary:
 return f.session.ledger.model.pursuit_buff_status().duplicate(true)

func b02_now(f: Dictionary) -> float:
 return float(f.sim.common.runtime.actor_time)

func b02_receipts(f: Dictionary) -> Array:
 var out: Array = []
 for id: String in f.session.ledger.model.receipts:
  var receipt: Dictionary = f.session.ledger.model.receipts[id]
  if receipt.request.action == "b02_verified_death_buff" and receipt.result.get("accepted", false): out.append({"id":id, "request":receipt.request.duplicate(true), "result":receipt.result.duplicate(true)})
 return out

func on_event(event: Dictionary, f: Dictionary) -> void:
 var observation: Dictionary = {}
 if event.get("kind", "") == "kill" and f.has("b02_kills"):
  observation = {"event":event.duplicate(true), "witness":f.sim.verify_g02_kill_attribution(f.session.ledger.model,event,f.session.run_id), "before":b02_raw(f), "now":b02_now(f), "held":owned_count(f,"final:B02") > 0, "synthetic":f.b02_synthetic, "transaction_active":f.sim.transaction_active, "source_actor":f.sim.hero.actor_id, "original_roster":str(event.target) in f.session.expected_enemies, "claims_before":f.session.ledger.model.state.get("b02_death_claims",{}).duplicate(true)}
 super.on_event(event,f)
 if observation.is_empty(): return
 observation["after"] = b02_raw(f)
 observation["view"] = b02_view(f)
 observation["stats"] = f.sim.hero.stats.duplicate(true)
 observation["base"] = f.sim.hero.projected_base_stats.duplicate(true)
 observation["claims_after"] = f.session.ledger.model.state.get("b02_death_claims",{}).duplicate(true)
 var eligible: bool = observation.held and observation.original_roster and not observation.synthetic and not observation.witness.is_empty()
 if eligible:
  check(not observation.after.is_empty() and observation.view.active and observation.view.active_copies == 1, "genuine held original death publishes exactly one B02 effect synchronously")
  near_number(float(observation.after.granted_at),float(observation.now),"B02 uses original common actor time at real death")
  near_number(float(observation.after.expires_at),float(observation.now)+4.0,"real death refreshes expiry to current original actor time+4")
  near_number(float(observation.after.move_fraction),0.12,"unique original move fraction")
  near_number(float(observation.after.attack_speed_fraction),0.20,"unique original attack-speed fraction")
 else:
  check(observation.after == observation.before, "unheld/unwitnessed/counterfeit death cannot grant or refresh B02")
 f.b02_kills.append(observation)
 b02_records.append(observation)

func b02_projected(f: Dictionary, label: String) -> void:
 var base: Dictionary = f.sim.hero.projected_base_stats.duplicate(true)
 var prior: Dictionary = f.sim.common.runtime.project_stats(base,f.sim.common.context())
 var p2: Dictionary = f.sim._p2_projection()
 var view: Dictionary = b02_view(f)
 var move: float = float(prior.move_speed)+float(base.move_speed)*(float(p2.speed_fraction)+float(view.move_fraction))
 var attack: float = minf(float(prior.attack_speed)+float(base.attack_speed)*float(view.attack_speed_fraction),float(f.sim.common.context().get("attack_speed_cap",2.5)))
 near_number(float(f.sim.hero.stats.move_speed),move,label+": original projection plus one source move effect")
 near_number(float(f.sim.hero.stats.attack_speed),attack,label+": original projection plus one source attack effect and original cap")
 check(float(f.sim.hero.attack_speed()) <= 2.5,label+": original actor attack-speed cap retained")
 check(f.sim.common.runtime.get_instance_id() == f.b02_clock_id and f.sim.common.get_instance_id() == f.b02_common_id,label+": same original Common and clock objects")

func b02_complete() -> void:
 check(current_group in B02_GROUPS and current_group not in b02_done_groups,"unique B02 source group")
 b02_done_groups.append(current_group)

func b02_start(label: String, copies: int = 2) -> Dictionary:
 var f: Dictionary = funded_shop(label)
 if f.is_empty(): return {}
 for _copy: int in range(copies):
  if not buy(f,"final:B02"): dispose(f); return {}
 if not check(f.session.close_panel().get("accepted",false),"original B02 shop closes") or not enter(f,1) or not spawn_ready(f): dispose(f); return {}
 return f

func b02_clock_to(f: Dictionary, target: float) -> bool:
 for _tick: int in range(700):
  if b02_now(f) >= target - 0.00000001: break
  if f.sim.phase != "combat" or f.sim.hero.dead or f.sim.paused: break
  step(f)
 return check(b02_now(f) >= target-0.00000001 and not f.sim.hero.dead,"actual source fixed steps reach original actor-clock boundary")

func b02_kill(f: Dictionary, enemy: Dictionary) -> Dictionary:
 var count: int = f.b02_kills.size()
 lethal_enemy_fixture(f,enemy,"B02 explicit original admitted-actor source death")
 if not check(enemy.dead and f.b02_kills.size() == count+1,"one real original source death reaches the Session"): return {}
 return f.b02_kills.back()

func b02_definitions() -> void:
 current_group = B02_GROUPS[0]
 var f: Dictionary = funded_shop(current_group)
 if f.is_empty(): return
 var model = f.session.ledger.model
 var prior: Dictionary = B02Prior.build(JSON.parse_string(FileAccess.get_file_as_string(B01_NUMERIC)))
 if not check(prior.get("accepted",false),"original39 adapter accepts original source"): dispose(f); return
 check(model.runtime_stat_definitions.size() == prior.definitions.size()+1,"B02 adds exactly one runtime definition")
 for id: String in prior.definitions: check(var_to_bytes(prior.definitions[id]) == var_to_bytes(model.runtime_stat_definitions[id]),"prior39 definition byte-equivalent "+id)
 var item: Dictionary = model.equipment_runtime_status("final:B02")
 check(item.stats == {"AD":50.0,"penetration":14.0,"move_speed":0.14} and item.passive28 == {"move_bonus":12.0,"attack_speed_bonus":20.0,"duration":4.0},"exact original B02 stats and passive parameters")
 check(int(item.commerce.price)==2900 and int(item.commerce.combine_fee)==500 and int(item.commerce.component_total)==2400,"original2900 price/I04+I18+500 recipe")
 var gold: int = model.state.gold
 if not buy(f,"final:B02") or not buy(f,"final:B02"): dispose(f); return
 check(model.state.gold == gold-5800 and owned_count(f,"final:B02")==2,"original legal two-copy purchases")
 var stats: Dictionary = model.equipment_effects().stats
 near_number(float(stats.AD)-float(f.baseline.equipment.stats.get("AD",0.0)),100.0,"two static AD copies")
 near_number(float(stats.penetration)-float(f.baseline.equipment.stats.get("penetration",0.0)),28.0,"two static penetration copies")
 near_number(float(stats.move_speed)-float(f.baseline.equipment.stats.get("move_speed",0.0)),0.28,"two static move fractions")
 check(not b02_view(f).active and b02_raw(f).is_empty(),"purchase itself does not invent kill effect")
 var rejected: Dictionary = command(f,"b02_verified_death_buff",{})
 check(not rejected.get("accepted",false) and b02_raw(f).is_empty(),"external command cannot invent authenticated death")
 sell(f,"final:B02");undo(f)
 check(owned_count(f,"final:B02")==2 and b02_raw(f).is_empty(),"sale undo does not invent a buff")
 b02_projected(f,"two copies before kill")
 dispose(f);b02_complete()

func b02_birth_refresh() -> void:
 current_group = B02_GROUPS[1]
 var f: Dictionary = b02_start(current_group)
 if f.is_empty(): return
 var target: Dictionary = g02_nearest(f)
 if target.is_empty() or not g02_prepare_hp(f,target,1.0): dispose(f); return
 var release: Dictionary = g02_q1(f,target)
 if release.is_empty(): dispose(f); return
 if not check(target.dead and f.b02_kills.size()==1 and f.b02_kills[0].transaction_active,"actual Q1 birth lethal hit grants inside original transaction_active"): dispose(f); return
 var first: Dictionary = b02_raw(f)
 b02_projected(f,"immediate birth before another source step")
 var cooldown: float = f.sim.hero.cooldowns.attack
 var base: Dictionary = f.sim.hero.projected_base_stats.duplicate(true)
 for _repeat: int in range(12): f.sim.common.refresh_stats();f.sim.refresh_passive23()
 check(f.sim.hero.projected_base_stats==base and f.sim.hero.cooldowns.attack==cooldown,"repeated original projection never pollutes base or rewrites active basic cooldown")
 b02_projected(f,"repeated full projection")
 if not b02_clock_to(f,float(first.granted_at)+1.25): dispose(f); return
 target=f.sim.living()[0]
 var second: Dictionary = b02_kill(f,target)
 if second.is_empty(): dispose(f); return
 check(second.after.expires_at>first.expires_at and second.after.expires_at<float(first.expires_at)+4.0,"repeat death replaces now+4 instead of adding duration")
 b02_projected(f,"single refreshed buff")
 if not b02_clock_to(f,float(second.after.expires_at)-0.03): dispose(f); return
 check(b02_view(f).active and float(b02_view(f).remaining)>0.0,"buff remains active just before original expiry")
 if not b02_clock_to(f,float(second.after.expires_at)+0.000001): dispose(f); return
 check(not b02_view(f).active and b02_view(f).remaining==0.0,"original actor clock naturally expires the four-second effect")
 b02_projected(f,"expired effect")
 check(f.sim.ai_enabled and f.sim.auto_finish,"original AI and source terminal policies remain enabled")
 dispose(f);b02_complete()

func b02_sale() -> void:
 current_group = B02_GROUPS[2]
 var f: Dictionary = b02_start(current_group)
 if f.is_empty(): return
 if not b04_settle_row(f,1) or not g02_open(f): dispose(f); return
 var raw: Dictionary = b02_raw(f)
 var now: float = b02_now(f)
 check(b02_view(f).active,"original room completion retains issued buff into legal shop")
 sell(f,"final:B02")
 check(owned_count(f,"final:B02")==1 and b02_raw(f)==raw,"selling one keeps issued unique effect")
 b02_projected(f,"after first sale")
 sell(f,"final:B02")
 check(owned_count(f,"final:B02")==0 and b02_view(f).active and b02_raw(f)==raw,"selling last retains issued expiry while removing static gear")
 b02_projected(f,"sold empty")
 if not buy(f,"final:B02"): dispose(f); return
 check(b02_raw(f)==raw and b02_now(f)==now,"repurchase cannot refresh effect or safe source clock")
 undo(f)
 check(owned_count(f,"final:B02")==0 and b02_raw(f)==raw,"undo repurchase preserves issued buff")
 if not check(f.session.close_panel().get("accepted",false),"sold empty original shop closes") or not enter(f,2) or not spawn_ready(f): dispose(f); return
 var before: Dictionary=b02_raw(f)
 if b02_kill(f,f.sim.living()[0]).is_empty(): dispose(f); return
 check(b02_raw(f)==before and not b02_view(f).equipped,"real unequipped next-room kill cannot refresh or grant")
 if not b02_clock_to(f,float(raw.expires_at)+0.000001): dispose(f); return
 check(not b02_view(f).active,"sold issued effect finishes its original remaining combat seconds")
 dispose(f);b02_complete()

func b02_crossroom() -> void:
 current_group=B02_GROUPS[3]
 var f: Dictionary=b02_start(current_group,1)
 if f.is_empty(): return
 if not b04_settle_row(f,1): dispose(f);return
 var raw: Dictionary=b02_raw(f)
 var now: float=b02_now(f)
 var remaining: float=float(b02_view(f).remaining)
 check(b02_view(f).active and remaining<=4.0,"real terminal retains current remaining combat time")
 step(f,360)
 check(b02_now(f)==now and b02_raw(f)==raw and b02_view(f).remaining==remaining,"safe source step calls do not advance original actor clock")
 b02_projected(f,"safe active effect")
 var position: Vector3=f.sim.hero.position
 var direction: Vector3=Vector3.RIGHT
 var speed: float=f.sim.hero.speed()
 var expected: Vector3=f.sim._move_clipped(position,position+direction*speed*0.1,f.sim.hero_radius)
 f.sim.free_move(0.1,direction)
 check(f.sim.hero.position.is_equal_approx(expected) and f.sim.hero.position.distance_to(position)>0.0,"original safe free_move consumes actual buffed speed with original collision clipping")
 check(b02_now(f)==now,"safe actual movement still consumes no combat seconds")
 if not enter(f,2): dispose(f);return
 check(b02_raw(f)==raw and b02_now(f)==now,"original next-room commit preserves buff and same actor clock")
 if not spawn_ready(f): dispose(f);return
 check(b02_now(f)>now and b02_view(f).remaining<remaining and b02_raw(f)==raw,"original next-room combat advances remaining time without regrant")
 if not check(f.session.set_modal_blocked(true).get("accepted",false),"original modal pause accepted"): dispose(f);return
 var paused_at: float=b02_now(f)
 step(f,150)
 check(b02_now(f)==paused_at and b02_raw(f)==raw,"original pause freezes exact actor clock and expiry")
 if not check(f.session.set_modal_blocked(false).get("accepted",false),"original modal resume accepted") or not b04_settle_row(f,2): dispose(f);return
 var issued: Dictionary=b02_raw(f)
 check(b02_view(f).active,"last actual row2 death supplies active buff immediately before original rest")
 if not enter(f,3): dispose(f);return
 check(f.session.status=="service","original authored row3 rest entered")
 if not check(f.session.complete_service().get("accepted",false),"original rest service settles"):dispose(f);return
 check(not f.sim.hero.cast_state.has(B02_KEY) and not b02_view(f).active,"original rest clears real issued buff")
 for _repeat: int in range(5): f.sim.common.refresh_stats();f.sim.refresh_passive23()
 check(not f.sim.hero.cast_state.has(B02_KEY),"later original projection cannot rehydrate rested buff")
 b02_projected(f,"rested projection")
 evidence["b02_crossroom"]={"before":raw,"post_row2":issued,"safe_remaining":remaining,"same_clock":f.b02_clock_id,"original_rest":true,"actual_safe_move":true}
 dispose(f);b02_complete()

func b02_replays() -> void:
 current_group=B02_GROUPS[4]
 var f: Dictionary=b02_start(current_group,1)
 if f.is_empty():return
 var record: Dictionary=b02_kill(f,f.sim.living()[0])
 if record.is_empty():dispose(f);return
 var receipts: Array=b02_receipts(f)
 if not check(receipts.size()==1,"one original B02 grant command receipt"):dispose(f);return
 var raw: Dictionary=b02_raw(f)
 var task: Dictionary=g02_protected(f)
 var replay: Dictionary=f.session.observe_event(f.sim,record.event)
 f.b02_synthetic=true;f.g02_synthetic=true;f.sim.emit_event("kill",record.event.duplicate(true));f.g02_synthetic=false;f.b02_synthetic=false
 check(replay.get("accepted",false) and b02_raw(f)==raw and g02_protected(f)==task,"saved real kill and new public sequence cannot refresh effect or tasks")
 var corpse: Dictionary=f.sim.enemy_by_id(str(record.event.target))
 check(not f.sim.damage_enemy(corpse,100000.0,"q1",0,true,false,{"fixture":true,"no_reactions":true}) and b02_raw(f)==raw,"source damage on original corpse cannot grant again")
 if not b02_clock_to(f,float(raw.expires_at)+0.000001):dispose(f);return
 var receipt: Dictionary=receipts[0]
 var after_expiry: Dictionary=f.session.ledger.model.command(receipt.id,receipt.request.action,receipt.request.args)
 check(after_expiry.get("accepted",false) and after_expiry.get("replayed",false) and b02_raw(f)==raw and not b02_view(f).active,"original successful command replay cannot restore expired real buff")
 check(not f.session.ledger.model.state.shop_visit.taskLedger.has(str(f.session.ledger.model.state.actor_id)+"|final:B02") and f.session.ledger.model.state.bonus_sp==0,"B02 creates no task ledger or bonus SP")
 dispose(f);b02_complete()

func run() -> void:
 evidence={"wallet_fixtures":[],"inputs":[],"cooldown_fixtures":[],"completions":[],"aborts":[],"victory":[],"postcompletion":[],"lifecycle":[],"isolated_common":[],"movement":[],"g02_deaths":[],"pre_damage":[],"inputs_g02":[],"p1_g02":{},"route_g02":{},"extra_actor_g02":{}}
 if B02_GROUPS[0] in b02_required:b02_definitions()
 if B02_GROUPS[1] in b02_required:b02_birth_refresh()
 if B02_GROUPS[2] in b02_required:b02_sale()
 if B02_GROUPS[3] in b02_required:b02_crossroom()
 if B02_GROUPS[4] in b02_required:b02_replays()
 check(b02_done_groups==b02_required,"all selected original B02 source groups completed")
 var report: Dictionary={"suite":"equipment40_B02_original_source_session","passed":failures.is_empty() and b02_done_groups==b02_required,"checks":checks,"failures":failures,"check_records":check_records,"partition":b02_partition,"required_groups":b02_required,"completed_groups":b02_done_groups,"evidence":evidence,"b02_deaths":b02_records,"productionSession":true,"original_Host_factories":true,"extra_actors":false,"source_damage_fixture":true,"wallet_fixture":true,"actor_stat_or_buff_fields_written":false,"actual_Q1_birth_input":B02_GROUPS[1] in b02_done_groups,"attack_speed_cap_saturated":false,"native_GUI":false,"natural_play":false,"production_ready":false}
 var file: FileAccess=FileAccess.open(output_path,FileAccess.WRITE)
 if file==null:push_error("Unable to write B02 source result");quit(2);return
 file.store_string(JSON.stringify(report,"  "));var error: Error=file.get_error();file.close()
 print("EQUIPMENT40_B02_SOURCE ",JSON.stringify({"passed":report.passed,"checks":checks,"failures":failures,"result":output_path}))
 quit(2 if error!=OK else (0 if report.passed else 1))
