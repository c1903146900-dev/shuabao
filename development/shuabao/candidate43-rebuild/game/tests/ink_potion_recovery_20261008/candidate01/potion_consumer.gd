extends RefCounted
## Combat-clock recovery only. Economic admission/debit/receipt remain in Model.
const TIERS = {"potion:1":20.0,"potion:2":35.0,"potion:3":50.0}
var _sim: WeakRef
var _actor: WeakRef
var _effects: Array = []
var _seen: Dictionary = {}
var _advancing: bool = false
func bind(sim: Node) -> Dictionary:
 if _sim != null or not is_instance_valid(sim): return {"accepted":false,"reason":"fresh_potion_binding_required"}
 _sim=weakref(sim);_actor=weakref(sim.hero)
 return {"accepted":true,"reason":""}
func preflight(item: String) -> String:
 if not TIERS.has(item): return "ordinary_potion_only"
 if _sim==null or not is_instance_valid(_sim.get_ref()): return "potion_consumer_unbound"
 var sim: Node=_sim.get_ref()
 if not is_same(sim.hero,_actor.get_ref()) or sim.hero.dead or sim.hero.hp<=0: return "not_alive"
 if sim.transaction_active or _advancing: return "transaction_in_progress"
 if sim.paused: return "paused"
 if not is_finite(float(sim.hero.stats.max_hp)) or float(sim.hero.stats.max_hp)<=0 or not is_finite(sim.hero.hp): return "nonfinite_health_state"
 return ""
func accept_committed_event(event: Dictionary) -> void:
 # Called only synchronously by model after its own consume_recovery receipt.
 var id: String=str(event.effect_id)
 assert(event.type=="recovery_committed" and TIERS.has(event.item))
 if _seen.has(id): return
 var sim: Node=_sim.get_ref()
 _seen[id]=true
 _effects.append({"effect_id":id,"item":event.item,"left":4.0,"rate":float(sim.hero.stats.max_hp)*TIERS[event.item]*0.01/4.0,"actual":0.0})
func advance(actor_dt: float) -> void:
 if _sim==null or not is_instance_valid(_sim.get_ref()): _effects.clear();return
 var sim: Node=_sim.get_ref()
 if not is_same(sim.hero,_actor.get_ref()) or sim.hero.dead or sim.hero.hp<=0: _effects.clear();return
 if sim.phase!="combat" or sim.paused or sim.transaction_active or _advancing: return
 if not is_finite(actor_dt) or actor_dt<=0: return
 _advancing=true
 for effect in _effects.duplicate():
  if sim.phase!="combat" or sim.hero.dead: break
  var elapsed: float=minf(actor_dt,float(effect.left))
  effect.left=maxf(0.0,float(effect.left)-elapsed)
  effect.actual+=sim.heal_actor(sim.hero,float(effect.rate)*elapsed,{"source":"ordinary_potion","effect_id":effect.effect_id,"item":effect.item})
  if float(effect.left)<=0.00000001: _effects.erase(effect)
 _advancing=false
 if sim.hero.dead: _effects.clear()
func retire() -> void:
 _effects.clear()
func snapshot() -> Dictionary:
 return {"active":_effects.duplicate(true),"committed_effect_count":_seen.size(),"clock":"source_actor_combat_seconds"}
