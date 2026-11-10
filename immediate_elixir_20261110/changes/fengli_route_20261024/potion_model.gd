extends "res://fengli_route_20261024/adapted/tests/ink_first_floor_user_route_20261005/runtime01/reward_model.gd"
const PotionConsumer=preload("res://tests/ink_potion_recovery_20261008/candidate01/potion_consumer.gd")
const FlaskConsumer=preload("res://fengli_route_20261024/flask_consumer.gd")
const ElixirConsumer=preload("res://fengli_route_20261024/elixir_consumer.gd")
var elixir_consumer=ElixirConsumer.new()
var flask_consumer=FlaskConsumer.new()
var potion_consumer=PotionConsumer.new()
var _potion_bound: bool=false
var _potion_dispatch: bool=false
var _potion_requests: Dictionary={}
var _rest_elixir_entry:Dictionary={}
var _rest_elixir_requests:Dictionary={}
func bind_commerce(owner: RefCounted, definitions: Dictionary, run_id: String, allow_economic_fixture: bool=false) -> Dictionary:
 var projected: Dictionary=definitions.duplicate(true)

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
 var flask_bound:Dictionary=flask_consumer.bind(sim,self,commerce_definitions)
 if not flask_bound.accepted:return flask_bound
 var elixir_bound:Dictionary=elixir_consumer.bind(sim,self,commerce_definitions)
 if not elixir_bound.accepted:return elixir_bound
 var result: Dictionary=potion_consumer.bind(sim)
 _potion_bound=bool(result.accepted)
 return result
func equipment_runtime_status(id: String) -> Dictionary:
 if id in ElixirConsumer.ITEMS and _potion_bound and elixir_consumer.ready():return {"supported":true,"reason":"","stats":{},"consumer":"next_battle_elixir"}
 if FlaskConsumer.ITEMS.has(id) and _potion_bound:return {"supported":true,"reason":"","stats":{},"consumer":"reusable_flask_recovery"}
 if PotionConsumer.TIERS.has(id) and _potion_bound: return {"supported":true,"reason":"","stats":{},"consumer":"ordinary_potion_recovery"}
 return super.equipment_runtime_status(id)
func _apply_commerce(envelope: Dictionary) -> String:
 var operation:String=str(envelope.get("operation",""))
 if operation=="clear_rest_elixir":return _apply_rest_elixir_clear(envelope)
 if operation in ["buy","craft"] and str(envelope.get("arguments",{}).get("item","")).begins_with("elixir:"):
  if _commerce_owner!=null and not potion_terminal_reason(_commerce_owner.get_ref()).is_empty():return "elixir_run_finished"
 if str(envelope.get("operation",""))=="consume":
  var reason:String=elixir_use_reason(int(envelope.get("arguments",{}).get("uid",-1)))
  if not reason.is_empty():return reason
 if str(envelope.get("operation",""))=="consume_recovery" and not _potion_dispatch: return "use_potion_consumer_required"
 return super._apply_commerce(envelope)
func _use_potion_original(owner: RefCounted, command_id: String, uid: int) -> Dictionary:
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
 if _potion_dispatch:return _deny("transaction_in_progress")
 var is_flask:bool=FlaskConsumer.ITEMS.has(item)
 var reason: String=flask_consumer.preflight(item) if is_flask else potion_consumer.preflight(item)
 if not reason.is_empty(): return _deny(reason)
 var args: Dictionary=commerce_token()
 args.merge({"uid":uid,"effect_id":("reusable-flask:" if is_flask else "ordinary-potion:")+str(state.shop_visit.run_id)+":"+command_id,"consumer_preflight_passed":true},true)
 _potion_dispatch=true
 var result: Dictionary=commerce_authority(owner,command_id,"consume_recovery",args)
 if result.accepted:
  _potion_requests[command_id]={"uid":uid,"arguments":args.duplicate(true)}
  for event in result.get("events",[]):
   if event.get("type","")=="recovery_committed":
    if is_flask:flask_consumer.accept_committed_event(command_id,event)
    else:potion_consumer.accept_committed_event(event)
 _potion_dispatch=false
 return result
func snapshot() -> Dictionary:
 var out: Dictionary=super.snapshot()
 out["elixir_effects"]=elixir_consumer.snapshot()
 out["ordinary_potion_recovery"]=potion_consumer.snapshot()
 out["reusable_flask_recovery"]=flask_consumer.snapshot()
 return out

func potion_terminal_reason(owner:RefCounted)->String:
 if owner==null or _commerce_owner==null or not is_same(_commerce_owner.get_ref(),owner):return "wrong_commerce_authority"
 if str(owner.get("status")) in ["completed","aborted","defeated","faulted","unbound"]:return "potion_run_finished"
 return ""
func use_potion(owner:RefCounted,command_id:String,uid:int)->Dictionary:
 # Preserve original authority validation, conflict ordering and successful retry receipts.
 if not _potion_bound or owner==null or _commerce_owner==null or not is_same(_commerce_owner.get_ref(),owner):return _use_potion_original(owner,command_id,uid)
 if command_id.is_empty() or _potion_requests.has(command_id) or receipts.has(command_id):return _use_potion_original(owner,command_id,uid)
 var reason=potion_terminal_reason(owner)
 if not reason.is_empty():return _deny(reason)
 return _use_potion_original(owner,command_id,uid)

func aggregate_effects()->Dictionary:
 var result:Dictionary=super.aggregate_effects()
 _add_stats(result.stats,elixir_consumer.static_stats())
 return result
func elixir_use_reason(uid:int)->String:
 if _commerce_owner!=null and not potion_terminal_reason(_commerce_owner.get_ref()).is_empty():return "elixir_run_finished"
 if not _potion_bound or not elixir_consumer.ready():return "elixir_consumer_unbound"
 if bool(state.get("actor_dead",false)):return "not_alive"
 var sim:Node=_health_sim.get_ref()
 if not is_instance_valid(sim) or sim.hero.dead or sim.hero.hp<=0.0:return "not_alive"
 if state.phase!="safe":return "elixir_prebattle_only"
 if not state.shop_visit.shop_active:return "shop_visit_required"
 var item:String=""
 for entry in state.inventory:
  if int(entry.uid)==uid:item=str(entry.id);break
 if item.is_empty():return "missing_item"
 if item not in ElixirConsumer.ITEMS:return "elixir_effect_not_supported"
 if state.shop_visit.active_elixir.get("item","")==item:return "same_name_elixir_active"
 return ""

# Rest is an explicit early-expiry boundary, not a fabricated battle. Route the
# small metadata change through the existing command/receipt/HP transaction.
func clear_elixir_for_rest(owner:RefCounted,entered:Dictionary)->Dictionary:
 var reason:String=_rest_elixir_reason(owner,entered)
 if not reason.is_empty():return _deny(reason)
 if not _rest_elixir_entry.is_empty():return _deny("rest_elixir_clear_in_progress")
 var command_id:String="rest-elixir:"+str(state.shop_visit.run_id)+":"+str(entered.receipt_id)
 var args:Dictionary=commerce_token()
 args["entry_id"]=str(entered.receipt_id)
 if _rest_elixir_requests.has(command_id):args=_rest_elixir_requests[command_id].duplicate(true)
 _rest_elixir_entry=entered.duplicate(true)
 var result:Dictionary=commerce_authority(owner,command_id,"clear_rest_elixir",args)
 if result.accepted:_rest_elixir_requests[command_id]=args.duplicate(true)
 _rest_elixir_entry={}
 return result

func _rest_elixir_reason(owner:RefCounted,entered:Dictionary)->String:
 if owner==null or _commerce_owner==null or not is_same(_commerce_owner.get_ref(),owner):return "wrong_commerce_authority"
 if not _potion_bound or not elixir_consumer.ready():return "elixir_consumer_unbound"
 if _health_sim==null or not is_instance_valid(_health_sim.get_ref()):return "health_binding_unavailable"
 var sim:Node=_health_sim.get_ref()
 if not is_same(owner.sim,sim) or not _bound(owner,sim) or not owner._owner_intact():return "rest_owner_unbound"
 if not owner._entered_service("rest") or owner._active_entry!=entered:return "committed_rest_entry_required"
 if sim.transaction_active or owner._transitioning:return "defer_to_outer_boundary"
 if state.phase!="safe" or not str(state.shop_visit.battle_id).is_empty():return "rest_safe_phase_required"
 if bool(state.get("actor_dead",false)) or sim.hero.dead or sim.hero.hp<=0.0:return "not_alive"
 if not owner.row_state._bindings_intact():return "immutable_binding_changed"
 var boundary:String=owner._safe_boundary_reason()
 if not boundary.is_empty():return boundary
 var payload:Dictionary=entered.get("payload",{})
 var entry_id:String=str(entered.get("receipt_id",""))
 if entry_id.is_empty() or str(payload.get("entry_id",""))!=entry_id or str(payload.get("service_type",""))!="rest":return "rest_entry_identity_mismatch"
 if str(payload.get("room_id",""))!=owner.active_node_room or owner.active_node_room!=state.shop_visit.room_id:return "rest_entry_identity_mismatch"
 if str(entered.get("identity",{}).get("run_id",""))!=owner.run_id or owner.run_id!=state.shop_visit.run_id:return "rest_entry_identity_mismatch"
 return ""

func _apply_rest_elixir_clear(envelope:Dictionary)->String:
 if _rest_elixir_entry.is_empty() or _authority_request.is_empty() or envelope!=_authority_request or not bool(envelope.get("trusted",false)):return "committed_rest_elixir_authority_required"
 var reason:String=_rest_elixir_reason(_commerce_owner.get_ref(),_rest_elixir_entry)
 if not reason.is_empty():return reason
 var args:Dictionary=envelope.get("arguments",{})
 var token:Dictionary=commerce_token()
 if args.get("epoch",-1)!=token.epoch:return "stale_epoch"
 if args.get("revision",-1)!=token.revision:return "stale_revision"
 if args.get("room_id","")!=token.room_id:return "stale_room"
 if str(args.get("entry_id",""))!=str(_rest_elixir_entry.receipt_id):return "rest_entry_identity_mismatch"
 var expired:Dictionary=state.shop_visit.active_elixir.duplicate(true)
 state.shop_visit.active_elixir.clear()
 # Keep inventory, gold, consumed receipts and sealed undo lineage untouched.
 _commerce_result={"accepted":true,"reason":"","events":[{"type":"rest_elixir_cleared","entry_id":args.entry_id,"elixir":expired}]}
 return ""
