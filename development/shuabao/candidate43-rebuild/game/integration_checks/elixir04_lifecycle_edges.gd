extends "res://integration_checks/elixir04_source_gate.gd"
## Death/closed-run boundaries keep original Session guards. A terminal receipt
## replay is tested separately at the original Model receipt layer, not UI access.
var edge_partition: String = "death"
func _initialize() -> void:
 output_path="user://elixir04_edges.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--elixir-result="):output_path=arg.trim_prefix("--elixir-result=")
  if arg.begins_with("--elixir-edge="):edge_partition=arg.trim_prefix("--elixir-edge=")
 if edge_partition not in ["death","terminal","completed_terminal","service_pending"]:quit(2);return
 run.call_deferred()
func hunter_death() -> void:
 current_group="death"
 var f: Dictionary=funded_shop(current_group)
 if f.is_empty():return
 var model=f.session.ledger.model
 if not buy(f,HUNTER) or not check(shop_command(f,"consume",{"uid":hunter_uid(f)}).accepted,"prepare actual elixir before death fixture") or not check(f.session.close_panel().accepted,"close shop") or not enter(f,1):dispose(f);return
 check(model.hunter_elixir_status().active,"death test starts with real active elixir")
 f.sim.damage_hero(1000000.0,Vector3.ZERO,0.0,true,true,{"source":"explicit_hunter_death_fixture","no_reactions":true})
 f.session.update_after_source_step()
 check(f.sim.hero.dead and f.session.status=="defeated","original lethal hero packet commits actual death")
 check(model.state.shop_visit.active_elixir.is_empty() and not model.hunter_elixir_status().active,"death end_encounter clears original elixir and active status")
 near_number(float(model.equipment_effects().stats.get("penetration",0.0)),float(f.baseline.equipment.stats.get("penetration",0.0)),"death leaves no elixir penetration in aggregate")
 near_number(float(model.hunter_elixir_multiplier({"rank_category":"boss"})),1.0,"dead owner has no elixir multiplier")
 hunter_note(f,"actual source death");dispose(f);hunter_done.append(current_group)
func hunter_complete_a_route(f: Dictionary) -> bool:
 for row in range(1,13):
  var node: String="r12boss" if row==12 else "r%02da"%row
  if not g06_enter_original(f,row,node):return false
  if f.session.status=="service":
   if not check(f.session.complete_service().accepted,"original a-route service "+node):return false
   continue
  if not spawn_ready_survivors(f):return false
  var expected_count: int=f.session.expected_enemies.size()
  if not check(expected_count>0 and expected_count<=MAX_ROOM_ACTORS and f.sim.living().size()==expected_count,"original nonempty bounded entered roster "+node):return false
  for enemy: Dictionary in f.sim.living().duplicate():lethal_enemy_fixture(f,enemy,"explicit a-route settlement "+node)
  for tick in range(MAX_TERMINAL_TICKS):
   if f.session.status!="combat":break
   step(f)
  var expected_status: String="completed" if row==12 else "between_rooms"
  if not check(f.sim.phase=="victory" and f.session.status==expected_status and f.session.fault.is_empty() and f.event_errors.is_empty() and f.session.terminal_pending.is_empty(),"original a-route terminal "+node):return false
  if not check(f.session.kill_receipts.size()==expected_count,"one original kill receipt per actual a-route actor "+node):return false
 return true
func hunter_terminal() -> void:
 current_group=edge_partition
 var f: Dictionary=funded_shop(current_group)
 if f.is_empty():return
 var model=f.session.ledger.model
 if not buy(f,HUNTER):dispose(f);return
 serial+=1
 var old_id: String="hunter-before-close-"+str(serial)
 var old_args: Dictionary=model.commerce_token();old_args.uid=hunter_uid(f)
 var committed: Dictionary=f.session.submit(old_id,"consume",old_args)
 if not check(committed.accepted,"consume before closing run accepted"):dispose(f);return
 if not buy(f,HUNTER):dispose(f);return
 var uid: int=hunter_uid(f)
 if edge_partition=="completed_terminal":
  if not check(f.session.close_panel().accepted,"close pre-route shop") or not hunter_complete_a_route(f) or not choose_required_hexes(f):dispose(f);return
  check(f.session.status=="completed" and f.sim.phase=="victory","all original twelve rows settle through source fixture")
  check(f.session.open_panel().accepted,"original completed victory shop remains accessible")
 else:
  var closed: Dictionary=f.session.close_run()
  check(closed.get("accepted",false) and f.session.status=="aborted","original close_run reaches terminal status")
 var state: Dictionary=model.state.duplicate(true)
 var retry: Dictionary=model.commerce_authority(f.session,old_id,"consume",old_args)
 check(retry.accepted and retry.get("replayed",false) and model.state==state,"Model exact old success receipt replays without a new terminal consume")
 var next_args: Dictionary=model.commerce_token();next_args.uid=uid
 var rejected: Dictionary=model.commerce_authority(f.session,"hunter-new-after-close","consume",next_args)
 check(not rejected.accepted and rejected.reason=="elixir_run_finished" and model.state==state,"new terminal Model consume rejects without consuming stored uid")
 check(not f.session.submit("hunter-terminal-session","consume",next_args).accepted and model.state==state,"original Session request refuses terminal consume without state change")
 check(not model.hunter_elixir_use_status(uid).accepted,"use button query reflects terminal refusal")
 if edge_partition=="completed_terminal":
  var stored_gold: int=model.state.gold
  var stored_count: int=model.state.inventory.size()
  if not buy(f,HUNTER):dispose(f);return
  check(model.state.gold==stored_gold-700 and model.state.inventory.size()==stored_count+1 and model.state.shop_visit.active_elixir.is_empty(),"completed shop with free slot stores hunter bottle for700 without effect")
  for i in range(6-model.state.inventory.size()):
   if not buy(f,"base:B01"):dispose(f);return
  check(model.state.inventory.size()==6,"completed shop can still legally store equipment")
  state=model.state.duplicate(true)
  var quote: Dictionary=model.commerce_quote(HUNTER)
  check(not quote.accepted and quote.reason=="elixir_run_finished","completed full-slot quote rejects automatic drink")
  var purchase: Dictionary=shop_command(f,"buy",{"item":HUNTER})
  check(not purchase.accepted and purchase.reason=="elixir_run_finished" and model.state==state,"completed automatic consumption cannot spend700")
 hunter_note(f,"terminal old Model receipt versus new request");dispose(f);hunter_done.append(current_group)
func hunter_service_pending() -> void:
 current_group="service_pending"
 var f: Dictionary=funded_shop(current_group)
 if f.is_empty():return
 if not check(f.session.close_panel().accepted,"close initial shop"):dispose(f);return
 for row in [1,2]:
  if not g06_enter_original(f,row,"r%02da"%row) or not settle_fixture_combat(f):dispose(f);return
 if not check(f.session.open_panel().accepted,"original second victory shop opens") or not buy(f,HUNTER) or not check(shop_command(f,"consume",{"uid":hunter_uid(f)}).accepted,"drink after second real source victory"):dispose(f);return
 var model=f.session.ledger.model
 var pending: Dictionary=model.state.shop_visit.active_elixir.duplicate(true)
 if not check(f.session.close_panel().accepted,"close pending shop") or not g06_enter_original(f,3,"r03a"):dispose(f);return
 check(model.state.shop_visit.active_elixir==pending and model.hunter_elixir_status().pending and not model.hunter_elixir_status().active,"original rest service neither binds nor erases next-battle elixir")
 if not check(f.session.complete_service().accepted,"complete original rest") or not g06_enter_original(f,4,"r04a"):dispose(f);return
 check(model.state.shop_visit.active_elixir==pending,"training service preserves original pending effect")
 if not check(f.session.complete_service().accepted,"complete original training without purchase") or not g06_enter_original(f,5,"r05a"):dispose(f);return
 check(model.hunter_elixir_status().active and model.state.shop_visit.active_elixir.battle_id==model.state.shop_visit.battle_id,"next actual elite battle consumes pending lifetime after both noncombat rooms")
 hunter_note(f,"pending crosses two original services");dispose(f);hunter_done.append(current_group)
func run() -> void:
 g03_reset_evidence()
 if edge_partition=="death":hunter_death()
 elif edge_partition in ["terminal","completed_terminal"]:hunter_terminal()
 else:hunter_service_pending()
 await process_frame
 check(hunter_done==[edge_partition],"requested elixir edge completed")
 var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"check_records":check_records,"failures":failures,"groups":hunter_done,"records":hunter_records,"wallet_fixture":true,"source_damage_fixture":true,"terminal_replay_layer":"Model receipt only; Session retains actual position refusal","natural_play":false,"source_binding_sha256":FileAccess.get_sha256("res://visual_rework_20261009/binding/source_binding.json")}
 var file: FileAccess=FileAccess.open(output_path,FileAccess.WRITE)
 if file==null:quit(2);return
 file.store_string(JSON.stringify(report,"  "));var error: Error=file.get_error();file.close()
 quit(0 if report.passed and error==OK else 2)
