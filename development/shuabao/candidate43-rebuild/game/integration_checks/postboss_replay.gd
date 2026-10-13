extends RefCounted
## Explicit source-input replay helper. Reuses the caller's actual Host/Sim/Session.
## No automatic process loop, new Sim or rank/HP/CD/stat assignment.
## R preparation alone uses explicitly recorded lethal source damage fixtures.
## The GUI runner retains the sole normal source-step owner.
var host
var serial: int = 0
var receipts: Array[Dictionary] = []
func bind_existing(value) -> Dictionary:
 if not is_instance_valid(value) or not is_instance_valid(value.sim) or value.shop_session == null:
  return {"accepted":false,"reason":"actual_host_session_required"}
 host=value
 return {"accepted":true,"sim_id":host.sim.get_instance_id(),"session_id":host.shop_session.get_instance_id(),"input_replay":true,"native_input":false}
func _command(action: String,args: Dictionary) -> Dictionary:
 serial+=1
 var result: Dictionary=host.shop_session.ledger.model.command("visual-replay-model-%d"%serial,action,args)
 host.shop_session.progression_command_completed({"action":action,"args":args},result)
 host.shop_session.update_after_source_step()
 if is_instance_valid(host.initial_controller):
  host.initial_controller.refresh()
  host.initial_controller.ensure_auto_hex()
 host._refresh_session_controls(true)
 receipts.append({"action":action,"args":args.duplicate(true),"result":result.duplicate(true)})
 return result
func resolve_required_hexes() -> Dictionary:
 var pending: Array=host.shop_session.ledger.model.snapshot().pending_milestones.duplicate()
 for milestone in pending:
  var opened: Dictionary=_command("hex_open",{"milestone":milestone})
  if not opened.get("accepted",false):return opened
  var selected: Dictionary=_command("hex_select",{"milestone":milestone,"slot":0})
  if not selected.get("accepted",false):return selected
 return {"accepted":true}
func learn_and_enter_first_room(candidate: String) -> Dictionary:
 if candidate not in ["Q1","Q2","Q3","E2","E3"]:return {"accepted":false,"reason":"fresh_Q_or_E_only"}
 var state: Dictionary=host.shop_session.ledger.model.snapshot()
 if int(state.level)!=1 or int(state.points)!=1 or host.sim.wave!=0 or host.sim.phase!="preparation":
  return {"accepted":false,"reason":"fresh_actual_one_SP_start_required"}
 var selected: Dictionary=resolve_required_hexes()
 if not selected.get("accepted",false):return selected
 var learned: Dictionary=_command("learn",{"slot":candidate.left(1),"candidate":candidate,"expected_rank":0})
 if not learned.get("accepted",false):return learned
 var chosen: Dictionary=host.shop_session.select_node(1,"r01a")
 if not chosen.get("accepted",false):return chosen
 return host.shop_session.enter_selected_node()
func learn_R_from_earned_progression(candidate: String) -> Dictionary:
 if candidate not in ["R1","R2"]:return {"accepted":false,"reason":"R_candidate_required"}
 var state: Dictionary=host.shop_session.ledger.model.snapshot()
 if int(state.level)<6 or int(state.points)<1:return {"accepted":false,"reason":"actual_earned_Lv6_and_SP_required"}
 var selected: Dictionary=resolve_required_hexes()
 if not selected.get("accepted",false):return selected
 return _command("learn",{"slot":"R","candidate":candidate,"expected_rank":int(state.skills.R.rank)})
func source_down(slot: String,point: Vector3) -> Dictionary:
 if not point.is_finite() or slot not in ["Q","E","R"]:return {"accepted":false,"reason":"valid_source_input_required"}
 serial+=1
 var id: String="visual-replay-input-%d"%serial
 var result: Dictionary
 if slot=="R":result=host.sim.request_action("r",point,id)
 else:result=host.sim.request_ink_input(slot.to_lower()+"_down",point,id,"",host.sim.encounter_generation)
 receipts.append({"slot":slot,"point":point,"hero_time":host.sim.hero_time,"result":result.duplicate(true)})
 return result
func source_up(slot: String,point: Vector3) -> Dictionary:
 if slot not in ["Q","E"]:return {"accepted":false,"reason":"no_R_release_commit"}
 serial+=1
 return host.sim.request_ink_input(slot.to_lower()+"_up",point,"visual-replay-up-%d"%serial,"",host.sim.encounter_generation)

var R_preparation_receipt: Dictionary = {}
func _R_prepare_result(ok: bool,reason: String) -> Dictionary:
 var state: Dictionary=host.shop_session.ledger.model.snapshot()
 R_preparation_receipt["accepted"]=ok
 R_preparation_receipt["reason"]=reason
 R_preparation_receipt["end_hero_time"]=host.sim.hero_time
 R_preparation_receipt["end_world_time"]=host.sim.clock.world_time
 R_preparation_receipt["level"]=state.level
 R_preparation_receipt["SP"]=state.points
 R_preparation_receipt["session_status"]=host.shop_session.status
 receipts.append(R_preparation_receipt.duplicate(true))
 return R_preparation_receipt.duplicate(true)
func prepare_R_on_existing_host(candidate: String) -> Dictionary:
 # Preparatory lethal source packets reproduce the existing lifecycle fixture.
 # Await the real GUI Host's frame owner; never sim.step or mutate HP/ranks/CD.
 if candidate not in ["R1","R2"] or not is_instance_valid(host):
  return {"accepted":false,"reason":"existing_host_and_R_candidate_required"}
 var initial: Dictionary=host.shop_session.ledger.model.snapshot()
 R_preparation_receipt={"candidate":candidate,"fixture":"explicit_lethal_source_damage_preparation","natural_leveling":false,"natural_combat":false,"native_input":false,"normal_GUI_step_owner":true,"start_hero_time":host.sim.hero_time,"start_world_time":host.sim.clock.world_time,"initial_level":initial.level,"initial_SP":initial.points,"sim_id":host.sim.get_instance_id(),"session_id":host.shop_session.get_instance_id(),"rows":[],"damage_packets":[]}
 if int(initial.level)!=1 or int(initial.points)!=1 or host.sim.wave!=0 or host.sim.phase!="preparation":
  return _R_prepare_result(false,"fresh_actual_one_SP_start_required")
 var required: Dictionary=resolve_required_hexes()
 if not required.get("accepted",false):return _R_prepare_result(false,"initial_hex:"+str(required.get("reason","")))
 var q: Dictionary=_command("learn",{"slot":"Q","candidate":"Q1","expected_rank":0})
 if not q.get("accepted",false):return _R_prepare_result(false,"initial_Q1_learning:"+str(q.get("reason","")))
 var route: Array[String]=["r01a","r02a","r03a","r04a","r05a","r06a","r07a","r08a","r09a","r10b","r11a","r12boss"]
 for index in range(route.size()):
  if host.sim.hero.dead or not host.shop_session.fault.is_empty():return _R_prepare_result(false,"source_dead_or_session_fault")
  required=resolve_required_hexes()
  if not required.get("accepted",false):return _R_prepare_result(false,"required_hex:"+str(required.get("reason","")))
  var selected: Dictionary=host.shop_session.select_node(index+1,route[index])
  if not selected.get("accepted",false):return _R_prepare_result(false,"select:"+str(selected.get("reason","")))
  var preflight: Dictionary=host.shop_session.next_room_preflight()
  if not preflight.get("accepted",false):return _R_prepare_result(false,"next_room_preflight:"+str(preflight.get("reason","")))
  var art: Dictionary=host.enemy_layer.preflight(preflight.node.payload)
  if not art.get("accepted",false):return _R_prepare_result(false,"enemy_preflight:"+str(art.get("reason","")))
  if host._mainprep_required or host.finished:return _R_prepare_result(false,"GUI_host_not_ready")
  host._request_next_room()
  await host.get_tree().process_frame
  if host.shop_session.status not in ["combat","service"] or not host.floor_error.is_empty():return _R_prepare_result(false,"host_room_entry_failed:"+str(host.floor_error))
  R_preparation_receipt.rows.append({"row":index+1,"node":route[index],"hero_time":host.sim.hero_time,"world_time":host.sim.clock.world_time,"status":host.shop_session.status})
  if index==11:
   if host.sim.hero.loadout.r!=candidate.to_lower() or int(host.sim.hero.ranks.r)<1:return _R_prepare_result(false,"R_not_legally_learned")
   return _R_prepare_result(true,"actual_Boss_room_ready_after_labelled_preparation")
  if host.shop_session.status=="service":
   var service: Dictionary=host.shop_session.complete_service()
   if not service.get("accepted",false):return _R_prepare_result(false,"service:"+str(service.get("reason","")))
   await host.get_tree().process_frame
  else:
   var spawn_ready: bool=false
   for frame in range(180):
    if host.sim.hero.dead or host.shop_session.status!="combat":return _R_prepare_result(false,"combat_ended_during_spawn_wait")
    spawn_ready=true
    for enemy: Dictionary in host.sim.living():
     if enemy.state=="spawn":spawn_ready=false
    if spawn_ready:break
    await host.get_tree().process_frame
   if not spawn_ready:return _R_prepare_result(false,"spawn_wait_bounded_out")
   var enemies: Array=host.sim.living().duplicate()
   if enemies.is_empty() or enemies.size()>6:return _R_prepare_result(false,"authored_roster_bound_failed")
   for enemy: Dictionary in enemies:
    var amount: float=float(enemy.hp)+100000.0
    R_preparation_receipt.damage_packets.append({"row":index+1,"actor_id":enemy.actor_id,"amount":amount,"hero_time":host.sim.hero_time,"world_time":host.sim.clock.world_time,"fixture":true})
    host.sim.damage_enemy(enemy,amount,"visual_replay_preparation_lethal_fixture",0,true,false,{"direct":false,"no_reactions":true,"fixture":true})
   for frame in range(300):
    if host.shop_session.status!="combat":break
    await host.get_tree().process_frame
   if host.shop_session.status!="between_rooms" or host.sim.phase!="victory":return _R_prepare_result(false,"authentic_room_settlement_failed")
  if not host.shop_session.fault.is_empty():return _R_prepare_result(false,"session_fault_after_settlement")
  if index==9:
   var learned: Dictionary=learn_R_from_earned_progression(candidate)
   if not learned.get("accepted",false):return _R_prepare_result(false,"earned_R_learning:"+str(learned.get("reason","")))
 return _R_prepare_result(false,"route_exhausted_without_Boss")
