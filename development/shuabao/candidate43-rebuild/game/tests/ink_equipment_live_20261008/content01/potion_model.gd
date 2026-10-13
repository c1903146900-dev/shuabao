extends "res://tests/ink_equipment_regen_20261008/candidate01/regen_model.gd"
const PotionConsumer=preload("res://tests/ink_potion_recovery_20261008/candidate01/potion_consumer.gd")
var potion_consumer=PotionConsumer.new()
var _potion_bound: bool=false
var _potion_dispatch: bool=false
var _potion_requests: Dictionary={}
func bind_commerce(owner: RefCounted, definitions: Dictionary, run_id: String, allow_economic_fixture: bool=false) -> Dictionary:
 var projected: Dictionary=definitions.duplicate(true)
 # User approval 2026-10-05 03:13:13 UTC, Sentinel_58891f6c400481918ae8be5a3771f473:
 # same-tier bottles share one of six slots, mixed tiers separate; total cap five.
 projected.potion_slot_policy="legacy_same_id_stack"
 return super.bind_commerce(owner,projected,run_id,allow_economic_fixture)
func bind_potion_sim(sim: Node) -> Dictionary:
 if _potion_bound or state.revision!=0 or _health_sim==null or not is_same(_health_sim.get_ref(),sim): return _deny("fresh_bound_health_sim_required")
 for id in PotionConsumer.TIERS:
  var definition: Dictionary=commerce_definitions.get("items",{}).get(id,{})
  var recovery: Dictionary=definition.get("recovery",{})
  if definition.get("kind","")!="potion" or float(recovery.get("heal_max_health_pct",-1))!=float(PotionConsumer.TIERS[id]) or float(recovery.get("duration_seconds",-1))!=4.0: return _deny("potion_source_parameters_mismatch")
 if int(commerce_definitions.get("potion_cap",0))!=5 or int(commerce_definitions.get("slot_limit",0))!=6: return _deny("potion_source_capacity_mismatch")
 var result: Dictionary=potion_consumer.bind(sim)
 _potion_bound=bool(result.accepted)
 return result
func equipment_runtime_status(id: String) -> Dictionary:
 if PotionConsumer.TIERS.has(id) and _potion_bound: return {"supported":true,"reason":"","stats":{},"consumer":"ordinary_potion_recovery"}
 return super.equipment_runtime_status(id)
func _apply_commerce(envelope: Dictionary) -> String:
 if str(envelope.get("operation",""))=="consume_recovery" and not _potion_dispatch: return "use_potion_consumer_required"
 return super._apply_commerce(envelope)
func use_potion(owner: RefCounted, command_id: String, uid: int) -> Dictionary:
 if not _potion_bound: return _deny("potion_consumer_unbound")
 if owner==null or _commerce_owner==null or not is_same(_commerce_owner.get_ref(),owner): return _deny("wrong_commerce_authority")
 if command_id.is_empty(): return _deny("missing_command_id")
 if _potion_requests.has(command_id):
  var prior: Dictionary=_potion_requests[command_id]
  if int(prior.uid)!=uid: return _deny("command_id_conflict")
  return commerce_authority(owner,command_id,"consume_recovery",prior.arguments)
 if receipts.has(command_id): return _deny("command_id_conflict")
 var item: String=""
 for entry in state.inventory:
  if int(entry.uid)==uid: item=str(entry.id);break
 if item.is_empty(): return _deny("missing_item")
 var reason: String=potion_consumer.preflight(item)
 if not reason.is_empty(): return _deny(reason)
 var args: Dictionary=commerce_token()
 args.merge({"uid":uid,"effect_id":"ordinary-potion:"+str(state.shop_visit.run_id)+":"+command_id,"consumer_preflight_passed":true},true)
 _potion_dispatch=true
 var result: Dictionary=commerce_authority(owner,command_id,"consume_recovery",args)
 _potion_dispatch=false
 if result.accepted:
  _potion_requests[command_id]={"uid":uid,"arguments":args.duplicate(true)}
  for event in result.get("events",[]):
   if event.get("type","")=="recovery_committed": potion_consumer.accept_committed_event(event)
 return result
func snapshot() -> Dictionary:
 var out: Dictionary=super.snapshot()
 out["ordinary_potion_recovery"]=potion_consumer.snapshot()
 return out
