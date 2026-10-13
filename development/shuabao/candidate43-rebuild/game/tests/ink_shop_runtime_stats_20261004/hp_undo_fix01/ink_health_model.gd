extends "res://tests/ink_shop_runtime_stats_20261004/ink_stat_run_model.gd"
## One same-visit undo journal owns economics and the exact reversible HP clamp.
## No new wallet, inventory, reward authority or generic HP snapshot rollback.
const HealthConsumer=preload("res://tests/ink_shop_runtime_stats_20261004/ink_stat_consumer.gd")
var _health_sim: WeakRef
var _health_consumer=HealthConsumer.new()
var _hp_undo_record: Dictionary={}
func bind_health_sim(sim: Node) -> Dictionary:
 if _health_sim!=null or not is_instance_valid(sim) or state.revision!=0:return _deny("fresh_health_binding_required")
 var result: Dictionary=sim.bind_equipment_health(self)
 if result.accepted:_health_sim=weakref(sim)
 return result
func record_health_dependency(sim: Node, kind: String, health_revision: int, before: float, after: float) -> void:
 if _health_sim==null or not is_same(_health_sim.get_ref(),sim) or before==after:return
 var changed: bool=false
 for record in state.shop_visit.undo:
  if record.get("hp_sensitive",false) and not record.sealed:
   record.sealed=true;record.seal_reason="hp_dependency_changed"
   record["hp_dependency_seal"]={"source":kind,"health_revision":health_revision,"before_hp":before,"after_hp":after}
   changed=true
 if changed:state.revision+=1 # Quotes accepted before a real HP dependency changed expire.
func _seal_health_consumption() -> void:
 for record in state.shop_visit.undo:
  if record.get("hp_sensitive",false) and not record.sealed:
   record.sealed=true;record.seal_reason="hp_consumption_dependency"
func command(id: String, action: String, args: Dictionary={}) -> Dictionary:
 if action!="commerce" or _health_sim==null:return super.command(id,action,args)
 var sim: Node=_health_sim.get_ref()
 if not is_instance_valid(sim):return _deny("health_binding_unavailable")
 sim.observe_pending_health()
 if sim.transaction_active:return _deny("transaction_in_progress")
 if not is_finite(sim.hero.hp) or not is_finite(float(sim.hero.stats.max_hp)):return _deny("nonfinite_health_state")
 var replay: bool=receipts.has(id)
 var before_hp: float=sim.hero.hp
 var before_max: float=sim.hero.stats.max_hp
 var before_health_revision: int=sim.equipment_health_revision
 var operation: String=str(args.get("operation",""))
 _hp_undo_record={}
 # Existing command remains the unique atomic economic ledger and receipt owner.
 var result: Dictionary=super.command(id,action,args)
 if not result.accepted or replay or not result.get("changed",false):return result
 assert(sim.equipment_health_revision==before_health_revision and sim.hero.hp==before_hp)
 assert(sim.begin_equipment_projection(self))
 _health_consumer.sync_stats(sim,self)
 var projected_hp: float=sim.hero.hp
 var after_max: float=sim.hero.stats.max_hp
 var restored: float=0.0
 if operation=="undo" and not _hp_undo_record.is_empty():
  # The validated inverse restores only its own recorded clip, never intervening
  # healing/damage or a whole actor snapshot. This does not call heal/proc hooks.
  restored=float(_hp_undo_record.clamp_delta)
  assert(projected_hp+restored<=after_max)
  sim.hero.hp=projected_hp+restored
 if operation in ["buy","sell","craft"] and before_max!=after_max:
  assert(not state.shop_visit.undo.is_empty())
  var record: Dictionary=state.shop_visit.undo.back()
  record["hp_sensitive"]=true
  record["hp_clamp"]={"pre_hp":before_hp,"pre_max":before_max,"post_hp":projected_hp,"post_max":after_max,"clamp_delta":maxf(0.0,before_hp-projected_hp),"health_revision":before_health_revision,"room_id":state.shop_visit.room_id,"epoch":state.shop_visit.epoch,"generation":sim.encounter_generation,"actor_id":sim.hero.actor_id}
 sim.end_equipment_projection(self)
 result["health_projection"]={"pre_hp":before_hp,"pre_max":before_max,"post_hp":sim.hero.hp,"post_max":after_max,"transaction_clamp":maxf(0.0,before_hp-projected_hp),"undo_restored_own_clamp":restored,"source_health_revision":before_health_revision,"healing_event_emitted":false}
 if receipts.has(id):receipts[id].result=result.duplicate(true)
 _hp_undo_record={}
 return result
func _apply_commerce(envelope: Dictionary) -> String:
 var operation: String=str(envelope.get("operation",""))
 if operation=="undo":
  var sim: Node=_health_sim.get_ref()
  for index in range(state.shop_visit.undo.size()-1,-1,-1):
   var record: Dictionary=state.shop_visit.undo[index]
   if record.sealed:continue
   if record.get("hp_sensitive",false):
    var hp: Dictionary=record.get("hp_clamp",{})
    if hp.is_empty() or int(hp.health_revision)!=sim.equipment_health_revision:return "hp_dependency_version_mismatch"
    if hp.actor_id!=sim.hero.actor_id or hp.room_id!=state.shop_visit.room_id or hp.epoch!=state.shop_visit.epoch or hp.generation!=sim.encounter_generation:return "hp_dependency_scope_mismatch"
    if float(hp.post_hp)!=sim.hero.hp:return "hp_dependency_current_hp_mismatch"
    _hp_undo_record=hp.duplicate(true)
   break
 var reason: String=super._apply_commerce(envelope)
 if reason.is_empty() and operation in ["consume","consume_recovery","pay_body"]:_seal_health_consumption()
 return reason
